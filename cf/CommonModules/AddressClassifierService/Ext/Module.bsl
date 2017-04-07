////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Subsystem "Address classifier".
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

#Region ServiceContactInformationProgramInterface

// Check vendor availability - local base or service.
// 
// Returns:
//     Structure - state description.
//       * Denial                        - Boolean - Vendor is not available.
//       * DetailedErrorPresentation - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       * BriefErrorPresentation   - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       *Data                       - String - Vendor version description.
//
Function DataProviderVersion() Export
	
	Result = New Structure("Data");
	VendorErrorDescriptionStructure(Result);
	
	Source = AddressClassifierDataSource();
	If IsBlankString(Source) Then
		// Local, always available
		FillDataVendorVersionExt(Result)
		
	ElsIf Source = "Service1C" Then
		// 1C web service, may be under maintenance.
		Try
			FillDataProviderVersion1CService(Result);
		Except
			VendorErrorDescriptionStructure(Result, ErrorInfo());
			WriteLogEvent(EventLogMonitorEvent(), EventLogLevel.Error, , , 
				Result.DetailErrorDescription);
		EndTry;
		
	EndIf;
	
	Return Result;
EndFunction

// Fill in data for checking a version by 1C service.
// 
Procedure FillDataProviderVersion1CService(Result)
	
	LanguageCode = CurrentLocaleCode();
	Service = AddressClassifierReUse.ClassifierService1C();
	Result.Data = Service.Ping(LanguageCode, Metadata.Name);

EndProcedure

// Filling in the data for checking the version for imported data.
// 
Procedure FillDataVendorVersionExt(Result) Export
	
	Result.Data = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='SSL %1';ru='БСП %1'"), StandardSubsystemsServer.LibraryVersion()
	);
	
EndProcedure

// Returns classifier data by the postal code.
//
// Parameters:
//     IndexOf                  - Number     - Postal code for which the data should be received.
//     AdditionalParameters - Structure - Description of the search settings. Fields:
//         * AddressFormat - String - type of a used classifier.
//
// Returns:
//     Structure -  found variants. Contains fields:
//       * Denial                        - Boolean - Vendor is not available.
//       * DetailedErrorPresentation - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       * BriefErrorPresentation   - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       * PresentationCommonPart      - String - General part of address presentation.
//       *Data                       - ValueTable - Contains data for selection. Columns:
//             ** Outdated    - Boolean - Check box showing that data row is outdated.
//             ** Identifier - UUID - Classifier code to search variants by index.
//             ** Presentation - String - Variant presentation.
//
Function AddressesByClassifierPostalCode(IndexOf, AdditionalParameters) Export
	
	Result = New Structure("Data, CommonPartPresentation", DataTableForSelectionByPostalCode() );
	VendorErrorDescriptionStructure(Result);

	Variant = AdditionalParameters.AddressFormat;
	If Variant = "AC" Then
		Levels = AddressClassifierReUse.AddressClassifierLevels();
		
	ElsIf Variant = "FIAS" Then
		Levels = AddressClassifierReUse.FIASClassifierLevels();
		
	Else
		Return Result;
		
	EndIf;
	
	Source = AddressClassifierDataSource();
	If IsBlankString(Source) Then
		// Local, always correct.
		FillAddressesByClassifierPostalCodeExt(Result, IndexOf, Levels, AdditionalParameters);
		
	ElsIf Source = "Service1C" Then
		// 1C web service, may be under maintenance.
		Try
			FillAddressesByClassifierPostalCode1CService(Result, IndexOf, Levels);
		Except
			VendorErrorDescriptionStructure(Result, ErrorInfo());
			WriteLogEvent( EventLogMonitorEvent(), EventLogLevel.Error, , , Result.DetailErrorDescription);
		EndTry;
		
	EndIf;
	
	Return Result;
EndFunction

// Constructor of table - result of selection by a postal code.
// 
Function DataTableForSelectionByPostalCode() Export
	
	Data = New ValueTable;
	Columns = Data.Columns;
	Columns.Add("NotActual",    New TypeDescription("Boolean")); 
	Columns.Add("ID", New TypeDescription("UUID")); 
	Columns.Add("Presentation", New TypeDescription("String")); 
	Data.Indexes.Add("ID");
	Data.Indexes.Add("Presentation");
	
	Return Data;
EndFunction

// Fill in address by 1C service data.
// 
Procedure FillAddressesByClassifierPostalCode1CService(Result, IndexOf, Levels)
	
	Service = AddressClassifierReUse.ClassifierService1C();
	
	// Select all records
	FirstRecord = Undefined;
	PortionSize = 1000;
	LanguageCode     = CurrentLocaleCode();
	
	Data = Result.Data;
	Portion = Service.SelectByPostalCode(IndexOf, Levels, FirstRecord, "ASC", PortionSize, LanguageCode, Metadata.Name);
	List = Portion.GetList("Item");
	
	If List.Count() = 0 Then
		Return;
	EndIf;
	Result.CommonPartPresentation = Format(IndexOf, "NG=0") + ", " + Portion.Title;
	
	For Each String In List Do
		FirstRecord = String.ID;
		
		ResultRow = Data.Add();
		ResultRow.ID = New UUID(FirstRecord);
		ResultRow.Presentation = String.Presentation;
		ResultRow.NotActual = Not String.Actual;
	EndDo;

EndProcedure

// Fill in address by index from the imported data.
// 
Procedure FillAddressesByClassifierPostalCodeExt(Result, IndexOf, Levels, AdditionalParameters) Export
	
	QueryText = 
#Region QueryText
		"SELECT
		|	AddressObjects.Level AS Level,
		|	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
		|	AddressObjects.DistrictCode AS DistrictCode,
		|	AddressObjects.RegionCode AS RegionCode,
		|	AddressObjects.CityCode AS CityCode,
		|	AddressObjects.UrbanDistrictCode AS UrbanDistrictCode,
		|	AddressObjects.SettlementCode AS SettlementCode,
		|	AddressObjects.StreetCode AS StreetCode,
		|	AddressObjects.AdditionalItemCode AS AdditionalItemCode,
		|	AddressObjects.SubordinateItemCode AS SubordinateItemCode,
		|	AddressObjects.ID AS ID,
		|	HousesBuildingsConstructions.PostalIndex AS PostalIndex,
		|	AddressObjects.Description AS Description,
		|	AddressObjects.Abbr AS Abbr,
		|	AddressObjects.Additionally AS Additionally,
		|	AddressObjects.ARCACode AS ARCACode,
		|	AddressObjects.Relevant AS Relevant,
		|	CASE WHEN AddressObjects.Relevant THEN FALSE ELSE TRUE END AS NotActual
		|INTO AddressesByIndex
		|FROM
		|	InformationRegister.HousesBuildingsConstructions AS HousesBuildingsConstructions
		|		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
		|		ON HousesBuildingsConstructions.AddressObject = AddressObjects.ID
		|WHERE
		|	HousesBuildingsConstructions.PostalIndex = &PostalIndex
		|	AND AddressObjects.PostalIndex = 0
		|	AND AddressObjects.Level In(&Levels) AND ( AddressObjects.Level = 7 OR AddressObjects.Level = 6)
		|
		|UNION ALL
		|
		|SELECT
		|	AddressObjects.Level,
		|	AddressObjects.RFTerritorialEntityCode,
		|	AddressObjects.DistrictCode,
		|	AddressObjects.RegionCode,
		|	AddressObjects.CityCode,
		|	AddressObjects.UrbanDistrictCode,
		|	AddressObjects.SettlementCode,
		|	AddressObjects.StreetCode,
		|	AddressObjects.AdditionalItemCode,
		|	AddressObjects.SubordinateItemCode,
		|	AddressObjects.ID,
		|	AddressObjects.PostalIndex,
		|	AddressObjects.Description,
		|	AddressObjects.Abbr,
		|	AddressObjects.Additionally,
		|	AddressObjects.ARCACode,
		|	AddressObjects.Relevant AS Relevant,
		|	CASE WHEN AddressObjects.Relevant THEN FALSE ELSE TRUE END AS NotActual
		|FROM
		|	InformationRegister.AddressObjects AS AddressObjects
		|WHERE
		|	AddressObjects.PostalIndex = &PostalIndex
		|	AND AddressObjects.Level In(&Levels) AND ( AddressObjects.Level = 7 OR AddressObjects.Level = 6)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RFTerritorialEntity.Description AS RFTerritorialEntityName,
		|	RFTerritorialEntity.Abbr AS RFTerritorialEntityAbbreviation,
		|	District.Description AS DistrictName,
		|	District.Abbr AS DistrictReduction,
		|	Region.Description AS RegionName,
		|	Region.Abbr AS RegionAbbr,
		|	City.Description AS CityName,
		|	City.Abbr AS CityAbbr,
		|	UrbanDistrict.Description AS UrbanDistrictDescpription,
		|	UrbanDistrict.Abbr AS UrbanDistrictAbbreviation,
		|	Settlement.Description AS SettlementName,
		|	Settlement.Abbr AS SettlementAbbr,
		|	Street.Description AS StreetName,
		|	Street.Abbr AS StreetAbbr,
		|	Additional.Description AS AdditionalName,
		|	Additional.Abbr AS AdditionalAbbreviation,
		|	subordinated.Description AS SubordinateName,
		|	subordinated.Abbr AS SubordinateAbbreviation,
		|	AddressObject.ID AS ID,
		|	AddressObject.Description AS Description,
		|	AddressObject.Abbr AS Abbr,
		|	AddressObject.Relevant AS Relevant,
		|	AddressObject.NotActual AS NotActual
		|FROM
		|	AddressesByIndex AS AddressObject
		|		LEFT JOIN InformationRegister.AddressObjects AS RFTerritorialEntity
		|		ON (RFTerritorialEntity.Level = 1)
		|			AND (RFTerritorialEntity.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (RFTerritorialEntity.DistrictCode = 0)
		|			AND (RFTerritorialEntity.RegionCode = 0)
		|			AND (RFTerritorialEntity.CityCode = 0)
		|			AND (RFTerritorialEntity.UrbanDistrictCode = 0)
		|			AND (RFTerritorialEntity.SettlementCode = 0)
		|			AND (RFTerritorialEntity.StreetCode = 0)
		|			AND (RFTerritorialEntity.AdditionalItemCode = 0)
		|			AND (RFTerritorialEntity.SubordinateItemCode = 0)
		|			AND (RFTerritorialEntity.ID <> AddressObject.ID)
		|		LEFT JOIN InformationRegister.AddressObjects AS District
		|		ON (District.Level = 2)
		|			AND (District.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (District.DistrictCode = AddressObject.DistrictCode)
		|			AND (District.RegionCode = 0)
		|			AND (District.CityCode = 0)
		|			AND (District.UrbanDistrictCode = 0)
		|			AND (District.SettlementCode = 0)
		|			AND (District.StreetCode = 0)
		|			AND (District.AdditionalItemCode = 0)
		|			AND (District.SubordinateItemCode = 0)
		|			AND (District.ID <> AddressObject.ID)
		|		LEFT JOIN InformationRegister.AddressObjects AS Region
		|		ON (Region.Level = 3)
		|			AND (Region.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (Region.DistrictCode = AddressObject.DistrictCode)
		|			AND (Region.RegionCode = AddressObject.RegionCode)
		|			AND (Region.CityCode = 0)
		|			AND (Region.UrbanDistrictCode = 0)
		|			AND (Region.SettlementCode = 0)
		|			AND (Region.StreetCode = 0)
		|			AND (Region.AdditionalItemCode = 0)
		|			AND (Region.SubordinateItemCode = 0)
		|			AND (Region.ID <> AddressObject.ID)
		|		LEFT JOIN InformationRegister.AddressObjects AS City
		|		ON (City.Level = 4)
		|			AND (City.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (City.DistrictCode = AddressObject.DistrictCode)
		|			AND (City.RegionCode = AddressObject.RegionCode)
		|			AND (City.CityCode = AddressObject.CityCode)
		|			AND (City.UrbanDistrictCode = 0)
		|			AND (City.SettlementCode = 0)
		|			AND (City.StreetCode = 0)
		|			AND (City.AdditionalItemCode = 0)
		|			AND (City.SubordinateItemCode = 0)
		|			AND (City.ID <> AddressObject.ID)
		|		LEFT JOIN InformationRegister.AddressObjects AS UrbanDistrict
		|		ON (UrbanDistrict.Level = 5)
		|			AND (UrbanDistrict.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (UrbanDistrict.DistrictCode = AddressObject.DistrictCode)
		|			AND (UrbanDistrict.RegionCode = AddressObject.RegionCode)
		|			AND (UrbanDistrict.CityCode = AddressObject.CityCode)
		|			AND (UrbanDistrict.UrbanDistrictCode = AddressObject.UrbanDistrictCode)
		|			AND (UrbanDistrict.SettlementCode = 0)
		|			AND (UrbanDistrict.StreetCode = 0)
		|			AND (UrbanDistrict.AdditionalItemCode = 0)
		|			AND (UrbanDistrict.SubordinateItemCode = 0)
		|			AND (UrbanDistrict.ID <> AddressObject.ID)
		|		LEFT JOIN InformationRegister.AddressObjects AS Settlement
		|		ON (Settlement.Level = 6)
		|			AND (Settlement.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (Settlement.DistrictCode = AddressObject.DistrictCode)
		|			AND (Settlement.RegionCode = AddressObject.RegionCode)
		|			AND (Settlement.CityCode = AddressObject.CityCode)
		|			AND (Settlement.UrbanDistrictCode = AddressObject.UrbanDistrictCode)
		|			AND (Settlement.SettlementCode = AddressObject.SettlementCode)
		|			AND (Settlement.StreetCode = 0)
		|			AND (Settlement.AdditionalItemCode = 0)
		|			AND (Settlement.SubordinateItemCode = 0)
		|			AND (Settlement.ID <> AddressObject.ID)
		|		LEFT JOIN InformationRegister.AddressObjects AS Street
		|		ON (Street.Level = 7)
		|			AND (Street.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (Street.DistrictCode = AddressObject.DistrictCode)
		|			AND (Street.RegionCode = AddressObject.RegionCode)
		|			AND (Street.CityCode = AddressObject.CityCode)
		|			AND (Street.UrbanDistrictCode = AddressObject.UrbanDistrictCode)
		|			AND (Street.SettlementCode = AddressObject.SettlementCode)
		|			AND (Street.StreetCode = AddressObject.StreetCode)
		|			AND (Street.AdditionalItemCode = 0)
		|			AND (Street.SubordinateItemCode = 0)
		|			AND (Street.ID <> AddressObject.ID)
		|		LEFT JOIN InformationRegister.AddressObjects AS Additional
		|		ON (Additional.Level = 90)
		|			AND (Additional.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (Additional.DistrictCode = AddressObject.DistrictCode)
		|			AND (Additional.RegionCode = AddressObject.RegionCode)
		|			AND (Additional.CityCode = AddressObject.CityCode)
		|			AND (Additional.UrbanDistrictCode = AddressObject.UrbanDistrictCode)
		|			AND (Additional.SettlementCode = AddressObject.SettlementCode)
		|			AND (Additional.StreetCode = AddressObject.StreetCode)
		|			AND (Additional.AdditionalItemCode = AddressObject.AdditionalItemCode)
		|			AND (Additional.SubordinateItemCode = 0)
		|			AND (Additional.ID <> AddressObject.ID)
		|		LEFT JOIN InformationRegister.AddressObjects AS subordinated
		|		ON (subordinated.Level = 91)
		|			AND (subordinated.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (subordinated.DistrictCode = AddressObject.DistrictCode)
		|			AND (subordinated.RegionCode = AddressObject.RegionCode)
		|			AND (subordinated.CityCode = AddressObject.CityCode)
		|			AND (subordinated.UrbanDistrictCode = AddressObject.UrbanDistrictCode)
		|			AND (subordinated.SettlementCode = AddressObject.SettlementCode)
		|			AND (subordinated.StreetCode = AddressObject.StreetCode)
		|			AND (subordinated.AdditionalItemCode = AddressObject.AdditionalItemCode)
		|			AND (subordinated.SubordinateItemCode = AddressObject.SubordinateItemCode)
		|			AND (subordinated.ID <> AddressObject.ID)
		|WHERE
		|	AddressObject.PostalIndex = &PostalIndex
		|	AND AddressObject.Level In(&Levels)
		|	AND (RFTerritorialEntity.Level IS NULL 
		|			OR RFTerritorialEntity.Level In (&Levels))
		|	AND (District.Level IS NULL 
		|			OR District.Level In (&Levels))
		|	AND (Region.Level IS NULL 
		|			OR Region.Level In (&Levels))
		|	AND (City.Level IS NULL 
		|			OR City.Level In (&Levels))
		|	AND (UrbanDistrict.Level IS NULL 
		|			OR UrbanDistrict.Level In (&Levels))
		|	AND (Settlement.Level IS NULL 
		|			OR Settlement.Level In (&Levels))
		|	AND (Street.Level IS NULL 
		|			OR Street.Level In (&Levels))
		|	AND (Additional.Level IS NULL 
		|			OR Additional.Level In (&Levels))
		|	AND (subordinated.Level IS NULL 
		|			OR subordinated.Level In (&Levels))
		|
		|ORDER BY
		|	Description
		|TOTALS
		|	COUNT(RFTerritorialEntityName),
		|	COUNT(DistrictName),
		|	COUNT(RegionName),
		|	COUNT(CityName),
		|	COUNT(UrbanDistrictDescpription),
		|	COUNT(SettlementName),
		|	COUNT(StreetName),
		|	COUNT(AdditionalName),
		|	COUNT(SubordinateName)
		|BY
		|	OVERALL";
#EndRegion

	Query = New Query(QueryText);
	Query.SetParameter("PostalIndex", IndexOf);
	Query.SetParameter("Levels",         Levels);
	QueryTree = Query.Execute().Unload(QueryResultIteration.ByGroups);
	
	TreeRows = QueryTree.Rows;
	If TreeRows.Count() = 0 Then
		// There is nothing to fill in
		Return;
	EndIf;
	
	// Define a common name by the first row - something that each row contains.
	TotalsRow    = TreeRows[0];
	DetailedRows = TotalsRow.Rows;
	FirstRow    = DetailedRows[0];
	DetailedTotally  = DetailedRows.Count();
	
	// First 18 columns describe an hierarchy, there is at least one row.
	CommonPresentation = Format(IndexOf, "ND=6; NZ=; NLZ=; NG=");
	Empty = New Structure;
	
	Position = 0;
	While Position < 18 Do
		ColumnName = QueryTree.Columns[Position].Name;
		If TotalsRow[ColumnName] = DetailedTotally Then
			// Description
			Empty.Insert(ColumnName);
			CommonPresentation = CommonPresentation + ", " + FirstRow[ColumnName];
			// Abbr
			ColumnName = QueryTree.Columns[Position + 1].Name;
			Empty.Insert(ColumnName);
			CommonPresentation = CommonPresentation + " " + FirstRow[ColumnName];
		EndIf;
		Position = Position + 2;
	EndDo;
	
	Result.CommonPartPresentation = CommonPresentation;
	Data = Result.Data;
	
	For Each String In DetailedRows Do
		// Remove common, full name will be created from the ones that are left.
		FillPropertyValues(String, Empty);
		ResultRow = Data.Add();
		ResultRow.NotActual = String.NotActual;
		ResultRow.ID = String.ID;
		
		Presentation = "";
		AddToPresentationAddressItem(Presentation, String.Description, String.Abbr);
		AddToPresentationAddressItem(Presentation, String.SubordinateName, String.SubordinateAbbreviation);
		AddToPresentationAddressItem(Presentation, String.AdditionalName, String.AdditionalAbbreviation);
		AddToPresentationAddressItem(Presentation, String.StreetName, String.StreetAbbr);
		AddToPresentationAddressItem(Presentation, String.SettlementName, String.SettlementAbbr);
		AddToPresentationAddressItem(Presentation, String.UrbanDistrictDescpription, String.UrbanDistrictAbbreviation);
		AddToPresentationAddressItem(Presentation, String.CityName, String.CityAbbr);
		AddToPresentationAddressItem(Presentation, String.RegionName, String.RegionAbbr);
		AddToPresentationAddressItem(Presentation, String.DistrictName, String.DistrictReduction);
		AddToPresentationAddressItem(Presentation, String.RFTerritorialEntityName, String.RFTerritorialEntityAbbreviation);
		ResultRow.Presentation = Presentation;
		
	EndDo;
	
	Data.Sort("Presentation");
EndProcedure

Procedure AddToPresentationAddressItem(Presentation, Val Description, Val Abbr)
	
	Description = TrimAll(Description);
	Description = ?(Description = "", "", TrimAll(Description + " " + TrimL(Abbr)));
	
	If Not IsBlankString(Description) Then
		If Not IsBlankString(Presentation) Then 
			Presentation = Presentation + ", " + Description;
		Else
			Presentation = Description;
		EndIf;
	EndIf;
	
EndProcedure

// Returns classifier data of a selection field by a level.
//
// Parameters:
//     Parent                - UUID - Parent object.
//     Level                 - Number                   - Required data level. 1-7, 90, 91 - address objects, -1
//                                                         - landmarks.
//     AdditionalParameters - Structure               - Description to search setting. Fields:
//         * AddressFormat - String  - type of a used classifier.
//
//         * PortionSize - Number                   - Optional size of the portion of returned data. If not
//                                                    specified or 0, then returns all items.
//         * FirstRecord - UUID - Item from which the data portion begins. Selection does
//                                                    not contain the item itself.
//         * Sorting   - String                  - Sorting direction for a portion.
//
// Returns:
//     Structure -  found variants. Contains fields:
//       * Denial                        - Boolean - Vendor is not available.
//       * DetailedErrorPresentation - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       * BriefErrorPresentation   - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       * Title                    - String - Row with a selection offer.
//       *Data                       - ValueTable - Contains data for selection. Columns:
//             ** Outdated     - Boolean - Check box showing that data row is outdated.
//             ** Identifier  - UUID - Classifier code to search variants by index.
//             ** Presentation  - String - Variant presentation.
//             ** StateImported - Boolean - Makes sense only for states. True if there are records.
//
Function AddressesForInteractiveSelection(Parent, Level, AdditionalParameters) Export
	
	Result = New Structure("Data, Title", DataTableForInteractiveSelection() );
	VendorErrorDescriptionStructure(Result);

	Levels = AddressClassifierReUse.FIASClassifierLevels();
	
	Source = AddressClassifierDataSource();
	If IsBlankString(Source) Then
		// Local, always correct.
		FillAddressesForInteractiveSelectionExt(Result, Levels, Parent, Level, AdditionalParameters);
		
	ElsIf Source = "Service1C" Then
		// 1C web service, may be under maintenance.
		Try
			FillAddressesForInteractiveSelection1CService(Result, Levels, Parent, Level, AdditionalParameters);
		Except
			VendorErrorDescriptionStructure(Result, ErrorInfo());
			WriteLogEvent( EventLogMonitorEvent(), EventLogLevel.Error, , , Result.DetailErrorDescription);
		EndTry;
		
	EndIf;
	
	If Level = 1 Then
		Result.Title = NStr("en='Select state';ru='Выберите регион'");
	ElsIf Level = 2 Then
		Result.Title = NStr("en='Select district';ru='Выберите округ'");
	ElsIf Level = 3 Then
		Result.Title = NStr("en='Select region';ru='Выберите район'");
	ElsIf Level = 4 Then
		Result.Title = NStr("en='Select city';ru='Выберите город'");
	ElsIf Level = 5 Then
		Result.Title = NStr("en='Select urban district';ru='Выберите внутригородской район'");
	ElsIf Level = 6 Then
		Result.Title = NStr("en='Choose the settlement';ru='Выберите населенный пункт'");
	ElsIf Level = 7 Then
		Result.Title = NStr("en='Select street';ru='Выберите улицу'");
	ElsIf Level = 90 Then
		Result.Title = NStr("en='Select additional item';ru='Выберите дополнительный элемент'");
	ElsIf Level = 91 Then
		Result.Title = NStr("en='Select subordinate item';ru='Выберите подчиненный элемент'");
	ElsIf Level = -1 Then
		Result.Title = NStr("en='Select landmark';ru='Выберите ориентир'");
	EndIf;
	
	Return Result;
EndFunction

// Constructor of table - result of selection.
// 
Function DataTableForInteractiveSelection() Export
	
	BooleanType = New TypeDescription("Boolean");
	Data    = New ValueTable;
	Columns   = Data.Columns;
	
	Columns.Add("NotActual",     BooleanType); 
	Columns.Add("ID",  New TypeDescription("UUID")); 
	Columns.Add("Presentation",  New TypeDescription("String")); 
	Columns.Add("StateImported", BooleanType); 
	
	Data.Indexes.Add("ID");
	Data.Indexes.Add("Presentation");
	
	Return Data
EndFunction

// Fill in data for selection of address by 1C service data.
// 
Procedure FillAddressesForInteractiveSelection1CService(Result, Levels, Parent, Level, AdditionalParameters);
	Service = AddressClassifierReUse.ClassifierService1C();
	
	RowParent = ?(ValueIsFilled(Parent), String(Parent), Undefined);
	LanguageCode       = CurrentLocaleCode();
	
	Data = Result.Data;
	
	// If parameter is passed - portion size, then give by portion, otherwise, - all.
	GeneratePortion = AdditionalParameters.Property("PortionSize");
	If GeneratePortion Then
		// Translate to a portion call.
		PortionSize = AdditionalParameters.PortionSize;
		FirstRecord = ?(ValueIsFilled(AdditionalParameters.FirstRecord), String(AdditionalParameters.FirstRecord), Undefined);
		Sort   = ?(ValueIsFilled(AdditionalParameters.Sort), String(AdditionalParameters.Sort), "ASC");
		
		If ValueIsFilled(FirstRecord) Then
			FirstRecordLength = StrLen(FirstRecord);
			FirstRecordRow = Left("00000000-0000-0000-0000-000000000000", 36 - FirstRecordLength) + FirstRecord;
			FirstRecord = New UUID(FirstRecordRow);
		EndIf;
		
		Portion = Service.Select(RowParent, Level, FirstRecord, Sort, PortionSize, LanguageCode, Metadata.Name);
		Result.Title = Portion.Title;
		List = Portion.GetList("Item");
		
		For Each String In List Do
			ResultRow = Data.Add();
			ResultRow.StateImported = True;
			ResultRow.ID  = New UUID(String.ID);
			ResultRow.Presentation  = String.Presentation;
			ResultRow.NotActual = Not String.Actual;
		EndDo;
		
		Return;
	EndIf;
	
	// Select all records (additional territories)
	FirstRecord = Undefined;
	PortionSize = 1000;
	
	Portion = Service.Select(RowParent, Level, Undefined, "ASC", PortionSize, LanguageCode, Metadata.Name);
	Result.Title = Portion.Title;
	List = Portion.GetList("Item");
	
	For Each String In List Do
		FirstRecord = String.ID;
		ResultRow = Data.Add();
		ResultRow.StateImported = True;
		ResultRow.ID  = New UUID(FirstRecord);
		ResultRow.Presentation  = String.Presentation;
		ResultRow.NotActual = Not String.Actual;
	EndDo;
	
EndProcedure

// Fill in data for selection of address from the imported data.
// 
Procedure FillAddressesForInteractiveSelectionExt(Result, Levels, Parent, Level, AdditionalParameters) Export
	
	ParameterFirstRecord   = Undefined;
	PortionSizeText      = "";
	PortionSortingText  = "";
	PortionOrderComparison = ">=";
	
	// If parameter is passed - portion size, then give by portion, otherwise, - all.
	PortionSize = Undefined;
	GeneratePortion = AdditionalParameters.Property("PortionSize", PortionSize) AND ValueIsFilled(PortionSize);
	
	If GeneratePortion Then
		PortionSizeText  = "TOP " + Format(PortionSize, "NZ=; NG=");
		
		If AdditionalParameters.Property("FirstRecord") AND ValueIsFilled(AdditionalParameters.FirstRecord) Then
			ParameterFirstRecord = New UUID(AdditionalParameters.FirstRecord);
		EndIf;
		
		If AdditionalParameters.Property("Sort") AND ValueIsFilled(AdditionalParameters.Sort) Then
			PortionSortingText = AdditionalParameters.Sort;
		EndIf;
		
		If PortionSortingText <> "ASC" Then
			PortionOrderComparison = "<=";
		EndIf;
	EndIf;
	
	// Special cases
	If Level = 1 Then
		// States request, ignore parent.
		QueryText = 
#Region QueryText
			"SELECT " + PortionSizeText + "
			|	State.ID                            AS ID,
			|	State.Description + "" "" + State.Abbr AS Presentation,
			|
			|	CASE WHEN 1 In (
			|		SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 2 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 3 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 4 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 5 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 6 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 7 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 90 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 91 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|	) THEN TRUE ELSE FALSE
			|	END AS StateImported
			|
			|FROM
			|	InformationRegister.AddressObjects AS State
			|
			|" + ?(ParameterFirstRecord = Undefined, "", "
			|LEFT JOIN
			|	InformationRegister.AddressObjects AS CurrentPortionOrder 
			|ON CurrentPortionOrder.Identifier = &FirstPortionItem
			|") + "
			|	
			|WHERE
			|	State.Level =
			|	1 AND State.DistrictCode = 0 AND State.RegionCode
			|	= 0 AND State.CityCode = 0
			|	AND State.UrbanDistrictCode = 0 AND State.SettlementCode
			|	= 0 AND State.StreetCode
			|	= 0 AND State.AdditionalItemCode =
			|	0 AND State.SubordinateItemCode = 0
			|	
			|" + ?(ParameterFirstRecord = Undefined, "", "
			|	AND State.Identifier <>
			|	CurrentPortionOrder.Identifier AND State.Name + """" + State.Abbreviation " + PortionOrderComparison + " CurrentPortionParameter.Name + """" + CurrentPortionParameter.Abbreviation
			|") + "
			|
			|ORDER
			|	BY Presentation " + PortionSortingText + "
			|";
#EndRegion
	ElsIf Level = -1 Then
		// Query of landmarks, parent - address object.
		QueryText = 
#Region QueryText
			"SELECT " + PortionSizeText + "
			|	ID AS ID, 
			|	Definition AS Presentation
			|FROM
			|	InformationRegister.AddressObjectsLandmarks AS Landmarks
			|
			|
			|	ID AS ID, 
			|	Definition AS Presentation
			|FROM
			|	InformationRegister.AddressObjectsLandmarks AS Landmarks
			|
			|" + ?(ParameterFirstRecord = Undefined, "", "
			|LEFT JOIN
			|	InformationRegister.AddressObjects AS CurrentPortionOrder 
			|ON CurrentPortionOrder.Identifier = &FirstPortionItem
			|") + "
			|
			|WHERE
			|	Landmarks.AddressObject = &Parent
			|
			|" + ?(ParameterFirstRecord = Undefined, "", "
			|	AND Landmarks.Identifier <>
			|	CurrentPortionOrder.Identifier AND Landmarks.Name + "" "" + Landmarks.Abbreviation " + PortionOrderComparison + " CurrentPortionParameter.Name + """" + CurrentPortionParameter.Abbreviation
			|") + "
			|
			|ORDER
			|	BY Presentation " + PortionSortingText + "
			|";
#EndRegion
	Else
		// Usual level
		QueryText = 
#Region QueryText
			"SELECT " + PortionSizeText + "
			|	AddressObject.ID AS ID,
			|	AddressObject.Description + "" "" + AddressObject.Abbr AS Presentation,
			|	TRUE AS StateImported,
			|	CASE WHEN AddressObject.Relevant THEN FALSE ELSE TRUE END AS NotActual
			|FROM
			|	InformationRegister.AddressObjects AS ParentObject
			|
			|" + ?(ParameterFirstRecord = Undefined, "", "
			|LEFT JOIN
			|	InformationRegister.AddressObjects AS CurrentPortionOrder 
			|ON CurrentPortionOrder.Identifier = &FirstPortionItem
			|") + "
			|
			|LEFT JOIN 
			|	InformationRegister.AddressObjects AS AddressObject	
			|ON AddressObject.Level = &Level 
			|	AND AddressObject.Level IN (&Levels) 
			|	AND AddressObject.RFTerritorialEntityCode = ParentObject.RFTerritorialEntityCode
			|";
		If Level = 2 Then
			// District
			QueryText = QueryText + "
				|	AND AddressObject.RegionCode = 0 
				|	AND AddressObject.CityCode = 0 
				|	AND AddressObject.UrbanDistrictCode = 0 
				|	AND AddressObject.SettlementCode = 0 
				|	AND AddressObject.StreetCode = 0 
				|	AND AddressObject.AdditionalItemCode = 0 
				|	AND AddressObject.SubordinateItemCode = 0
				|";
		ElsIf Level = 3 Then
			// Region
			QueryText = QueryText + "
				|	AND AddressObject.DistrictCode = ParentObject.DistrictCode
				|	AND AddressObject.CityCode = 0 
				|	AND AddressObject.UrbanDistrictCode = 0 
				|	AND AddressObject.SettlementCode = 0 
				|	AND AddressObject.StreetCode = 0 
				|	AND AddressObject.AdditionalItemCode = 0 
				|	AND AddressObject.SubordinateItemCode = 0
				|";
		ElsIf Level = 4 Then
			// City
			QueryText = QueryText + "
				|	AND AddressObject.DistrictCode = ParentObject.DistrictCode
				|	AND AddressObject.RegionCode = ParentObject.RegionCode
				|	AND AddressObject.UrbanDistrictCode = 0 
				|	AND AddressObject.SettlementCode = 0 
				|	AND AddressObject.StreetCode = 0 
				|	AND	AddressObject.AdditionalItemCode = 0 
				|	AND AddressObject.SubordinateItemCode = 0
				|";
		ElsIf Level = 5 Then
			// Urban district
			QueryText = QueryText + "
				|	AND AddressObject.DistrictCode = ParentObject.DistrictCode
				|	AND AddressObject.RegionCode = ParentObject.RegionCode
				|	AND AddressObject.CityCode = ParentObject.CityCode 
				|	AND AddressObject.SettlementCode = 0 
				|	AND AddressObject.StreetCode = 0 
				|	AND AddressObject.AdditionalItemCode = 0 
				|	AND AddressObject.SubordinateItemCode = 0
				|";
		ElsIf Level = 6 Then
			// Settlement
			QueryText = QueryText + "
				|	AND AddressObject.DistrictCode = ParentObject.DistrictCode
				|	AND AddressObject.RegionCode = ParentObject.RegionCode
				|	AND AddressObject.CityCode = ParentObject.CityCode 
				|	AND AddressObject.UrbanDistrictCode = ParentObject.UrbanDistrictCode 
				|	AND AddressObject.CityCode = 0 AND AddressObject.AdditionalItemCode = 0 
				|	AND AddressObject.SubordinateItemCode = 0
				|";
		ElsIf Level = 7 Then
			// Street
			QueryText = QueryText + "
				|	AND AddressObject.DistrictCode = ParentObject.DistrictCode
				|	AND AddressObject.RegionCode = ParentObject.RegionCode
				|	AND AddressObject.CityCode = ParentObject.CityCode 
				|	AND	AddressObject.UrbanDistrictCode = ParentObject.UrbanDistrictCode
				|	AND AddressObject.SettlementCode = ParentObject.SettlementCode 
				|	AND AddressObject.AdditionalItemCode = 0 
				|	AND AddressObject.SubordinateItemCode = 0
				|";
		ElsIf Level = 90 Then
			// Additional
			QueryText = QueryText + "
				|	AND AddressObject.DistrictCode = ParentObject.DistrictCode
				|	AND AddressObject.RegionCode = ParentObject.RegionCode
				|	AND AddressObject.CityCode = ParentObject.CityCode 
				|	AND AddressObject.UrbanDistrictCode	= ParentObject.UrbanDistrictCode 
				|	AND	AddressObject.SettlementCode = ParentObject.SettlementCode 
				|	AND AddressObject.StreetCode = ParentObject.StreetCode 
				|	AND AddressObject.SubordinateItemCode = 0
				|";
		ElsIf Level = 91 Then
			// subordinated
			QueryText = QueryText + "
				|	AND AddressObject.DistrictCode = ParentObject.DistrictCode
				|	AND AddressObject.RegionCode = ParentObject.RegionCode
				|	AND AddressObject.CityCode = ParentObject.CityCode 
				|	AND	AddressObject.UrbanDistrictCode = ParentObject.UrbanDistrictCode
				|	AND AddressObject.SettlementCode = ParentObject.SettlementCode 
				|	AND AddressObject.StreetCode = ParentObject.StreetCode 
				|	AND AddressObject.AdditionalItemCode = ParentObject.AdditionalItemCode
				|";
		Else
			Raise NStr("en='Query of the incorrect level of an address object';ru='Запрос некорректного уровня адресного объекта'");
		EndIf;
		
		QueryText = QueryText + "
			|WHERE
			|	ParentObject.ID =
			|	&Parent AND ParentObject.ID <> AddressObject.ID
			|
			|" + ?(ParameterFirstRecord = Undefined, "", "
			|	AND AddressObject.Identifier <>
			|	CurrentPortionOrder.Identifier AND AddressObject.Name + "" "" + AddressObject.Abbreviation " + PortionOrderComparison + " CurrentPortionParameter.Name + """" + CurrentPortionParameter.Abbreviation
			|") + "
			|
			|ORDER
			|	BY Presentation " + PortionSortingText + "
			|";
#EndRegion
	EndIf;

	Query = New Query(QueryText);
	Query.SetParameter("Level",  Level);
	Query.SetParameter("Levels",   Levels);
	Query.SetParameter("Parent", Parent);
	
	Query.SetParameter("PortionFirstItem", ParameterFirstRecord);
	
	Selection = Query.Execute().Select();
	
	Data = Result.Data;
	If Level <> -1 Then
		// Usual objects
		While Selection.Next() Do
			FillPropertyValues(Data.Add(), Selection);
		EndDo;
		Return;
	EndIf;
	
	// Landmarks. Definition - row to the storage.
	While Selection.Next() Do
		String = Data.Add();
		String.StateImported = True;
		String.ID  = Selection.ID;
		String.Presentation  = Selection.Presentation.Get();
	EndDo;
	
EndProcedure

// Returns a list for the autopick of address item, search by similarity.
//
// Parameters:
//     Text                   - String                      - Text entered in the field.
//     Parent                - UUID     - Parent object.
//     Levels                  - Array, FixedArray - Set of the required data levels. 1-7, 90, 91 - address
//                               objects, -1 - landmarks.
//     AdditionalParameters - Structure                   - Description to search setting. Fields:
//         * AddressFormat - String      - Type of the used classifier.
//
// Returns:
//     Structure -  found variants. Contains fields:
//       * Denial                        - Boolean - Vendor is not available.
//       * DetailedErrorPresentation - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       * BriefErrorPresentation   - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       *Data                       - ValueTable - Contains data for selection. Columns:
//             ** Outdated     - Boolean - Check box showing that data row is outdated.
//             ** Identifier  - UUID - Classifier code to search variants by index.
//             ** Presentation  - String - Variant presentation.
//             ** StateImported - Boolean - Makes sense only for states. True if there are records.
//
Function AutopickVariants(Text, Parent, Levels, AdditionalParameters) Export 
	
	Result = New Structure("Data", AutoPickDataTable() );
	VendorErrorDescriptionStructure(Result);
	
	Variant = AdditionalParameters.AddressFormat;
	If Variant = "AC" Then
		LevelsRestriction = AddressClassifierReUse.AddressClassifierLevels();
		
	ElsIf Variant = "FIAS" Then
		LevelsRestriction = AddressClassifierReUse.FIASClassifierLevels();
		
	Else
		Return Result;
		
	EndIf;
	
	// SearchRestriction
	QueryLevels = New Array;
	For Each Level In Levels Do
		If LevelsRestriction.Find(Level) <> Undefined Then
			QueryLevels.Add(Level);
		EndIf;
	EndDo;
	
	Source = AddressClassifierDataSource();
	If IsBlankString(Source) Then
		// Local, always correct.
		FillAddressPartAutoPickListExt(Result, Text, Parent, QueryLevels, AdditionalParameters);
		
	ElsIf Source = "Service1C" Then
		// 1C web service, may be under maintenance.
		Try
			FillAddressPartAutoPickList1CService(Result, Text, Parent, QueryLevels, AdditionalParameters);
		Except
			VendorErrorDescriptionStructure(Result, ErrorInfo());
			WriteLogEvent( EventLogMonitorEvent(), EventLogLevel.Error, , , Result.DetailErrorDescription);
		EndTry;
		
	EndIf;
	
	Return Result;
EndFunction

// Constructor of table - auto pick result.
// 
Function AutoPickDataTable() Export
	
	BooleanType = New TypeDescription("Boolean");
	Data    = New ValueTable;
	Columns   = Data.Columns;
	
	Columns.Add("NotActual",     BooleanType); 
	Columns.Add("ID",  New TypeDescription("UUID")); 
	Columns.Add("Presentation",  New TypeDescription("String")); 
	Columns.Add("StateImported", BooleanType); 
	
	Return Data
EndFunction

// Fill in data for auto pick by the 1C service data.
// 
Procedure FillAddressPartAutoPickList1CService(Result, Text, Parent, Levels, AdditionalParameters)
	
	Service = AddressClassifierReUse.ClassifierService1C();
	
	QueryLevels = ?(TypeOf(Levels) = Type("Array"), New FixedArray(Levels), Levels);
	LanguageCode      = CurrentLocaleCode();
	Data        = Result.Data;
	
	Portion = Service.Autocomplete(String(Parent), QueryLevels, Text, 20, LanguageCode, Metadata.Name);
	List = Portion.GetList("Item");
	For Each String In List Do
		ResultRow = Data.Add();
		ResultRow.StateImported = True;
		ResultRow.ID  = New UUID(String.ID);
		ResultRow.Presentation  = String.Presentation;
		ResultRow.NotActual = Not String.Actual;
	EndDo;
	
EndProcedure

// Fill in data for auto pick from the imported data.
//
Procedure FillAddressPartAutoPickListExt(Result, Text, Parent, QueryLevels, AdditionalParameters) Export
	
	FilterRecordsForAnalysis = "300";
	FilterRecordsForList = "20";
	
	SearchText = DisguiseSimilarityESCAPEs(Text);
	
	Query = New Query;
	Query.SetParameter("PhraseBegin", SearchText + "%");
	Query.SetParameter("WordStart", "% " + SearchText + "%");
	Query.SetParameter("Levels",      QueryLevels);
	
	If ValueIsFilled(Parent) Then
		Query.SetParameter("Parent", New UUID(Parent) );
		QueryTextSuitableObjects = 
#Region QueryText
			"// Parent specified clearly
			|SELECT TOP " + FilterRecordsForAnalysis + "
			|	AddressObject.Level,
			|	AddressObject.RFTerritorialEntityCode,
			|	AddressObject.DistrictCode,
			|	AddressObject.RegionCode,
			|	AddressObject.CityCode,
			|	AddressObject.UrbanDistrictCode,
			|	AddressObject.SettlementCode,
			|	AddressObject.StreetCode,
			|	AddressObject.AdditionalItemCode,
			|	AddressObject.SubordinateItemCode,
			|	AddressObject.ID,
			|	
			|	AddressObject.Description, 
			|	AddressObject.Abbr,
			|	
			|	CASE WHEN 1 In (
			|		SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 2 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 3 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 4 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 5 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 6 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 7 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 90 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 91 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|	) THEN TRUE ELSE FALSE
			|	END AS StateImported
			|INTO
			|	SuitableObjects
			|FROM
			|	InformationRegister.AddressObjects AS ParentObject
			|LEFT JOIN
			|	InformationRegister.AddressObjects AS AddressObject
			|ON
			|	AddressObject.Level In (&Levels)
			|	AND AddressObject.RFTerritorialEntityCode = ParentObject.RFTerritorialEntityCode
			|	AND AddressObject.ID <> ParentObject.ID
			|	// Similarity the name depends on the level - on street, enable search by a phrase part
			|	AND CASE 
			|		WHEN 7 In (&Levels) THEN
			|			AddressObject.Description LIKE &PhraseBegin
			|			OR AddressObject.Description LIKE &WordStart
			|		WHEN 90 In (&Levels) THEN
			|			AddressObject.Description LIKE &PhraseBegin
			|			OR AddressObject.Description LIKE &WordStart
			|		WHEN 91 In (&Levels) THEN
			|			AddressObject.Description LIKE &PhraseBegin
			|			OR AddressObject.Description LIKE &WordStart
			|		ELSE
			|			AddressObject.Description LIKE &PhraseBegin
			|	END
			|
			|	AND CASE
			|		WHEN ParentObject.Level = 2 THEN
			|			  AddressObject.DistrictCode = ParentObject.DistrictCode
			|			  
			|		WHEN ParentObject.Level = 3 THEN
			|			  AddressObject.DistrictCode = ParentObject.DistrictCode
			|			AND AddressObject.RegionCode = ParentObject.RegionCode
			|		
			|		WHEN ParentObject.Level = 4 THEN
			|			  AddressObject.DistrictCode  = ParentObject.DistrictCode
			|			AND AddressObject.RegionCode  = ParentObject.RegionCode
			|			AND AddressObject.CityCode  = ParentObject.CityCode
			|			
			|		WHEN ParentObject.Level = 5 THEN
			|			  AddressObject.DistrictCode  = ParentObject.DistrictCode
			|			AND AddressObject.RegionCode  = ParentObject.RegionCode
			|			AND AddressObject.CityCode  = ParentObject.CityCode
			|			AND AddressObject.UrbanDistrictCode  = ParentObject.UrbanDistrictCode
			|			
			|		WHEN ParentObject.Level = 6 THEN
			|			  AddressObject.DistrictCode  = ParentObject.DistrictCode
			|			AND AddressObject.RegionCode  = ParentObject.RegionCode
			|			AND AddressObject.CityCode  = ParentObject.CityCode
			|			AND AddressObject.UrbanDistrictCode  = ParentObject.UrbanDistrictCode
			|			AND AddressObject.SettlementCode       = ParentObject.SettlementCode
			|		
			|		WHEN ParentObject.Level = 7 THEN
			|			  AddressObject.DistrictCode  = ParentObject.DistrictCode
			|			AND AddressObject.RegionCode  = ParentObject.RegionCode
			|			AND AddressObject.CityCode  = ParentObject.CityCode
			|			AND AddressObject.UrbanDistrictCode  = ParentObject.UrbanDistrictCode
			|			AND AddressObject.SettlementCode       = ParentObject.SettlementCode
			|			AND AddressObject.StreetCode                   = ParentObject.StreetCode
			|	
			|		WHEN ParentObject.Level = 90 THEN
			|			  AddressObject.DistrictCode  = ParentObject.DistrictCode
			|			AND AddressObject.RegionCode  = ParentObject.RegionCode
			|			AND AddressObject.CityCode  = ParentObject.CityCode
			|			AND AddressObject.UrbanDistrictCode  = ParentObject.UrbanDistrictCode
			|			AND AddressObject.SettlementCode       = ParentObject.SettlementCode
			|			AND AddressObject.StreetCode                   = ParentObject.StreetCode
			|			AND AddressObject.AdditionalItemCode = ParentObject.AdditionalItemCode
			|		
			|		WHEN ParentObject.Level = 91 THEN
			|			  AddressObject.DistrictCode  = ParentObject.DistrictCode
			|			AND AddressObject.RegionCode  = ParentObject.RegionCode
			|			AND AddressObject.CityCode  = ParentObject.CityCode
			|			AND AddressObject.UrbanDistrictCode  = ParentObject.UrbanDistrictCode
			|			AND AddressObject.SettlementCode       = ParentObject.SettlementCode
			|			AND AddressObject.StreetCode                   = ParentObject.StreetCode
			|			AND AddressObject.AdditionalItemCode = ParentObject.AdditionalItemCode
			|			AND AddressObject.SubordinateItemCode    = ParentObject.SubordinateItemCode
			|		
			|		ELSE TRUE
			|	END
			|	
			|	AND CASE
			|		WHEN AddressObject.Level = 2 THEN	// District
			|			  AddressObject.RegionCode = 0
			|			AND AddressObject.CityCode = 0
			|			AND AddressObject.UrbanDistrictCode  = 0
			|			AND AddressObject.SettlementCode       = 0
			|			AND AddressObject.StreetCode                   = 0
			|			AND AddressObject.AdditionalItemCode = 0
			|			AND AddressObject.SubordinateItemCode    = 0
			|			
			|		WHEN AddressObject.Level = 2 THEN	// Region
			|			  AddressObject.DistrictCode = ParentObject.DistrictCode
			|			AND AddressObject.CityCode = 0
			|			AND AddressObject.UrbanDistrictCode  = 0
			|			AND AddressObject.SettlementCode       = 0
			|			AND AddressObject.StreetCode                   = 0
			|			AND AddressObject.AdditionalItemCode = 0
			|			AND AddressObject.SubordinateItemCode    = 0
			|			
			|		WHEN AddressObject.Level = 4 THEN	// City
			|			  AddressObject.DistrictCode = ParentObject.DistrictCode
			|			AND AddressObject.RegionCode = ParentObject.RegionCode
			|			AND AddressObject.UrbanDistrictCode  = 0
			|			AND AddressObject.SettlementCode       = 0
			|			AND AddressObject.StreetCode                   = 0
			|			AND AddressObject.AdditionalItemCode = 0
			|			AND AddressObject.SubordinateItemCode    = 0
			|			
			|		WHEN AddressObject.Level = 5 THEN	// Urban district
			|			  AddressObject.DistrictCode = ParentObject.DistrictCode
			|			AND AddressObject.RegionCode = ParentObject.RegionCode
			|			AND AddressObject.CityCode = ParentObject.CityCode
			|			AND AddressObject.SettlementCode       = 0
			|			AND AddressObject.StreetCode                   = 0
			|			AND AddressObject.AdditionalItemCode = 0
			|			AND AddressObject.SubordinateItemCode    = 0
			|		
			|		WHEN AddressObject.Level = 6 THEN	// Settlement
			|			  AddressObject.DistrictCode = ParentObject.DistrictCode
			|			AND AddressObject.RegionCode = ParentObject.RegionCode
			|			AND AddressObject.CityCode = ParentObject.CityCode
			|			AND AddressObject.UrbanDistrictCode  = ParentObject.UrbanDistrictCode
			|			AND AddressObject.StreetCode                   = 0
			|			AND AddressObject.AdditionalItemCode = 0
			|			AND AddressObject.SubordinateItemCode    = 0
			|			
			|		WHEN AddressObject.Level = 7 THEN	// Street
			|			  AddressObject.DistrictCode = ParentObject.DistrictCode
			|			AND AddressObject.RegionCode = ParentObject.RegionCode
			|			AND AddressObject.CityCode = ParentObject.CityCode
			|			AND AddressObject.UrbanDistrictCode  = ParentObject.UrbanDistrictCode
			|			AND AddressObject.SettlementCode       = ParentObject.SettlementCode
			|			AND AddressObject.AdditionalItemCode = 0
			|			AND AddressObject.SubordinateItemCode    = 0
			|			
			|		WHEN AddressObject.Level = 90 THEN	// Additional
			|			  AddressObject.DistrictCode = ParentObject.DistrictCode
			|			AND AddressObject.RegionCode = ParentObject.RegionCode
			|			AND AddressObject.CityCode = ParentObject.CityCode
			|			AND AddressObject.UrbanDistrictCode  = ParentObject.UrbanDistrictCode
			|			AND AddressObject.SettlementCode       = ParentObject.SettlementCode
			|			AND AddressObject.StreetCode                   = ParentObject.StreetCode
			|			AND AddressObject.SubordinateItemCode    = 0
			|			
			|		WHEN AddressObject.Level = 91 THEN	// subordinated
			|			  AddressObject.DistrictCode = ParentObject.DistrictCode
			|			AND AddressObject.RegionCode = ParentObject.RegionCode
			|			AND AddressObject.CityCode = ParentObject.CityCode
			|			AND AddressObject.UrbanDistrictCode  = ParentObject.UrbanDistrictCode
			|			AND AddressObject.SettlementCode       = ParentObject.SettlementCode
			|			AND AddressObject.StreetCode                   = ParentObject.StreetCode
			|			AND AddressObject.AdditionalItemCode = ParentObject.AdditionalItemCode
			|			
			|		ELSE TRUE
			|	END
			|
			|LEFT JOIN
			|	InformationRegister.AddressObjects AS State
			|ON 
			|	State.Level = 1
			|	AND State.RFTerritorialEntityCode              = AddressObject.RFTerritorialEntityCode
			|	AND State.DistrictCode                  = 0
			|	AND State.RegionCode                  = 0
			|	AND State.CityCode                  = 0
			|	AND State.UrbanDistrictCode  = 0
			|	AND State.SettlementCode       = 0
			|	AND State.StreetCode                   = 0
			|	AND State.AdditionalItemCode = 0
			|	AND State.SubordinateItemCode    = 0
			|WHERE 
			|	ParentObject.ID = &Parent
			|	AND Not AddressObject.ID IS NULL
			|ORDER BY
			|	AddressObject.Level
			|INDEX BY
			|	AddressObject.Level,
			|	AddressObject.RFTerritorialEntityCode,
			|	AddressObject.DistrictCode,
			|	AddressObject.RegionCode,
			|	AddressObject.CityCode,
			|	AddressObject.UrbanDistrictCode,
			|	AddressObject.SettlementCode,
			|	AddressObject.StreetCode,
			|	AddressObject.AdditionalItemCode,
			|	AddressObject.SubordinateItemCode,
			|	AddressObject.ID
			|";
#EndRegion
		
	Else
		Query.SetParameter("Parent", Undefined);
		QueryTextSuitableObjects = 
#Region QueryText
			"// Parent Not specified
			|SELECT TOP " + FilterRecordsForAnalysis + "
			|	AddressObject.Level,
			|	AddressObject.RFTerritorialEntityCode,
			|	AddressObject.DistrictCode,
			|	AddressObject.RegionCode,
			|	AddressObject.CityCode,
			|	AddressObject.UrbanDistrictCode,
			|	AddressObject.SettlementCode,
			|	AddressObject.StreetCode,
			|	AddressObject.AdditionalItemCode,
			|	AddressObject.SubordinateItemCode,
			|	AddressObject.ID,
			|	AddressObject.Description, 
			|	AddressObject.Abbr,
			|	
			|	CASE WHEN 1 In (
			|		SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 2 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 3 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 4 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 5 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 6 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 7 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 90 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
			|		WHERE Level = 91 AND RFTerritorialEntityCode = State.RFTerritorialEntityCode
			|	) THEN TRUE ELSE FALSE
			|	END AS StateImported
			|INTO
			|	SuitableObjects
			|FROM
			|	InformationRegister.AddressObjects AS AddressObject
			|LEFT JOIN
			|	InformationRegister.AddressObjects AS State
			|ON 
			|	State.Level = 1
			|	AND State.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode
			|	AND State.DistrictCode = 0
			|	AND State.RegionCode = 0
			|	AND State.CityCode = 0
			|	AND State.UrbanDistrictCode = 0
			|	AND State.SettlementCode = 0
			|	AND State.StreetCode = 0
			|	AND State.AdditionalItemCode = 0
			|	AND State.SubordinateItemCode = 0
			|WHERE 
			|	AddressObject.Description LIKE &PhraseBegin
			|	AND AddressObject.Level In (&Levels)
			|ORDER BY
			|	AddressObject.Level
			|INDEX BY
			|	AddressObject.Level,
			|	AddressObject.RFTerritorialEntityCode,
			|	AddressObject.DistrictCode,
			|	AddressObject.RegionCode,
			|	AddressObject.CityCode,
			|	AddressObject.UrbanDistrictCode,
			|	AddressObject.SettlementCode,
			|	AddressObject.StreetCode,
			|	AddressObject.AdditionalItemCode,
			|	AddressObject.SubordinateItemCode,
			|	AddressObject.ID
			|";
#EndRegion
		
	EndIf;

	QueryText = 
#Region QueryText
		QueryTextSuitableObjects + "
		|;/////////////////////////////////////////////////////////////////////////////////
		|
		|SELECT TOP " + FilterRecordsForList + "
		|	RFTerritorialEntity.Description AS RFTerritorialEntityName,
		|	RFTerritorialEntity.Abbr   AS RFTerritorialEntityAbbreviation,
		|	
		|	District.Description AS DistrictName,
		|	District.Abbr   AS DistrictReduction,
		|	
		|	Region.Description AS RegionName,
		|	Region.Abbr   AS RegionAbbr,
		|	
		|	City.Description AS CityName,
		|	City.Abbr   AS CityAbbr,
		|	
		|	UrbanDistrict.Description AS UrbanDistrictDescpription,
		|	UrbanDistrict.Abbr   AS UrbanDistrictAbbreviation,
		|	
		|	Settlement.Description AS SettlementName,
		|	Settlement.Abbr   AS SettlementAbbr,
		|	
		|	Street.Description AS StreetName,
		|	Street.Abbr   AS StreetAbbr,
		|	
		|	Additional.Description AS AdditionalName,
		|	Additional.Abbr   AS AdditionalAbbreviation,
		|	
		|	subordinated.Description AS SubordinateName,
		|	subordinated.Abbr   AS SubordinateAbbreviation,
		|	
		|	AddressObject.ID AS ID,
		|	
		|	AddressObject.Description  AS Description, 
		|	AddressObject.Abbr    AS Abbr,
		|
		|	StateImported AS StateImported
		|
		|FROM
		|	SuitableObjects AS AddressObject
		|	
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS RFTerritorialEntity
		|ON
		|	1 In (&Levels)
		|	AND RFTerritorialEntity.Level = 1
		|	AND RFTerritorialEntity.RFTerritorialEntityCode              = AddressObject.RFTerritorialEntityCode
		|	AND RFTerritorialEntity.DistrictCode                  = 0
		|	AND RFTerritorialEntity.RegionCode                  = 0
		|	AND RFTerritorialEntity.CityCode                  = 0
		|	AND RFTerritorialEntity.UrbanDistrictCode  = 0
		|	AND RFTerritorialEntity.SettlementCode       = 0
		|	AND RFTerritorialEntity.StreetCode                   = 0
		|	AND RFTerritorialEntity.AdditionalItemCode = 0
		|	AND RFTerritorialEntity.SubordinateItemCode    = 0
		|	AND RFTerritorialEntity.ID <> AddressObject.ID
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS District
		|ON
		|	2 In (&Levels)
		|	AND District.Level = 2
		|	AND District.RFTerritorialEntityCode              = AddressObject.RFTerritorialEntityCode
		|	AND District.DistrictCode                  = AddressObject.DistrictCode
		|	AND District.RegionCode                  = 0
		|	AND District.CityCode                  = 0
		|	AND District.UrbanDistrictCode  = 0
		|	AND District.SettlementCode       = 0
		|	AND District.StreetCode                   = 0
		|	AND District.AdditionalItemCode = 0
		|	AND District.SubordinateItemCode    = 0
		|	AND District.ID <> AddressObject.ID
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS Region
		|ON
		|	3 In (&Levels)
		|	AND Region.Level = 3
		|	AND Region.RFTerritorialEntityCode              = AddressObject.RFTerritorialEntityCode
		|	AND Region.DistrictCode                  = AddressObject.DistrictCode	
		|	AND Region.RegionCode                  = AddressObject.RegionCode
		|	AND Region.CityCode                  = 0
		|	AND Region.UrbanDistrictCode  = 0
		|	AND Region.SettlementCode       = 0
		|	AND Region.StreetCode                   = 0
		|	AND Region.AdditionalItemCode = 0
		|	AND Region.SubordinateItemCode    = 0
		|	AND Region.ID <> AddressObject.ID
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS City
		|ON
		|	4 In (&Levels)
		|	AND City.Level = 4
		|	AND City.RFTerritorialEntityCode              = AddressObject.RFTerritorialEntityCode
		|	AND City.DistrictCode                  = AddressObject.DistrictCode
		|	AND City.RegionCode                  = AddressObject.RegionCode
		|	AND City.CityCode                  = AddressObject.CityCode
		|	AND City.UrbanDistrictCode  = 0
		|	AND City.SettlementCode       = 0
		|	AND City.StreetCode                   = 0
		|	AND City.AdditionalItemCode = 0
		|	AND City.SubordinateItemCode    = 0
		|	AND City.ID <> AddressObject.ID
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS UrbanDistrict
		|ON
		|	5 In (&Levels)
		|	AND UrbanDistrict.Level = 5
		|	AND UrbanDistrict.RFTerritorialEntityCode              = AddressObject.RFTerritorialEntityCode
		|	AND UrbanDistrict.DistrictCode                  = AddressObject.DistrictCode
		|	AND UrbanDistrict.RegionCode                  = AddressObject.RegionCode
		|	AND UrbanDistrict.CityCode                  = AddressObject.CityCode
		|	AND UrbanDistrict.UrbanDistrictCode  = AddressObject.UrbanDistrictCode
		|	AND UrbanDistrict.SettlementCode       = 0
		|	AND UrbanDistrict.StreetCode                   = 0
		|	AND UrbanDistrict.AdditionalItemCode = 0
		|	AND UrbanDistrict.SubordinateItemCode    = 0
		|	AND UrbanDistrict.ID <> AddressObject.ID
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS Settlement
		|ON
		|	6 In (&Levels)
		|	AND Settlement.Level = 6
		|	AND Settlement.RFTerritorialEntityCode              = AddressObject.RFTerritorialEntityCode
		|	AND Settlement.DistrictCode                  = AddressObject.DistrictCode
		|	AND Settlement.RegionCode                  = AddressObject.RegionCode
		|	AND Settlement.CityCode                  = AddressObject.CityCode
		|	AND Settlement.UrbanDistrictCode  = AddressObject.UrbanDistrictCode
		|	AND Settlement.SettlementCode       = AddressObject.SettlementCode
		|	AND Settlement.StreetCode                   = 0
		|	AND Settlement.AdditionalItemCode = 0
		|	AND Settlement.SubordinateItemCode    = 0
		|	AND Settlement.ID <> AddressObject.ID
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS Street
		|ON
		|	7 In (&Levels)
		|	AND Street.Level = 7
		|	AND Street.RFTerritorialEntityCode              = AddressObject.RFTerritorialEntityCode
		|	AND Street.DistrictCode                  = AddressObject.DistrictCode
		|	AND Street.RegionCode                  = AddressObject.RegionCode
		|	AND Street.CityCode                  = AddressObject.CityCode
		|	AND Street.UrbanDistrictCode  = AddressObject.UrbanDistrictCode
		|	AND Street.SettlementCode       = AddressObject.SettlementCode
		|	AND Street.StreetCode                   = AddressObject.StreetCode
		|	AND Street.AdditionalItemCode = 0
		|	AND Street.SubordinateItemCode    = 0
		|	AND Street.ID <> AddressObject.ID
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS Additional
		|ON
		|	90 In (&Levels)
		|	AND Additional.Level = 90
		|	AND Additional.RFTerritorialEntityCode              = AddressObject.RFTerritorialEntityCode
		|	AND Additional.DistrictCode                  = AddressObject.DistrictCode
		|	AND Additional.RegionCode                  = AddressObject.RegionCode
		|	AND Additional.CityCode                  = AddressObject.CityCode
		|	AND Additional.UrbanDistrictCode  = AddressObject.UrbanDistrictCode
		|	AND Additional.SettlementCode       = AddressObject.SettlementCode
		|	AND Additional.StreetCode                   = AddressObject.StreetCode
		|	AND Additional.AdditionalItemCode = AddressObject.AdditionalItemCode
		|	AND Additional.SubordinateItemCode    = 0
		|	AND Additional.ID <> AddressObject.ID
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS subordinated
		|ON
		|	91 In (&Levels)
		|	AND subordinated.Level = 91
		|	AND subordinated.RFTerritorialEntityCode              = AddressObject.RFTerritorialEntityCode
		|	AND subordinated.DistrictCode                  = AddressObject.DistrictCode
		|	AND subordinated.RegionCode                  = AddressObject.RegionCode
		|	AND subordinated.CityCode                  = AddressObject.CityCode
		|	AND subordinated.UrbanDistrictCode  = AddressObject.UrbanDistrictCode
		|	AND subordinated.SettlementCode       = AddressObject.SettlementCode
		|	AND subordinated.StreetCode                   = AddressObject.StreetCode
		|	AND subordinated.AdditionalItemCode = AddressObject.AdditionalItemCode
		|	AND subordinated.SubordinateItemCode    = AddressObject.SubordinateItemCode
		|	AND subordinated.ID <> AddressObject.ID
		|
		|ORDER BY
		|	SubordinateName,
		|	AdditionalName,
		|	StreetName,
		|	SettlementName,
		|	UrbanDistrictDescpription,
		|	CityName,
		|	RegionName,
		|	DistrictName,
		|	RFTerritorialEntityName
		|";
#EndRegion

	Query.Text = QueryText;
	
	Data = Result.Data;
	For Each String In Query.Execute().Unload() Do
		ResultRow = Data.Add();
		
		FillPropertyValues(ResultRow, String, "Identifier, StateImported");
		
		Presentation = "";
		AddToPresentationAddressItem(Presentation, String.Description, String.Abbr);
		AddToPresentationAddressItem(Presentation, String.SubordinateName, String.SubordinateAbbreviation);
		AddToPresentationAddressItem(Presentation, String.AdditionalName, String.AdditionalAbbreviation);
		AddToPresentationAddressItem(Presentation, String.StreetName, String.StreetAbbr);
		AddToPresentationAddressItem(Presentation, String.SettlementName, String.SettlementAbbr);
		AddToPresentationAddressItem(Presentation, String.UrbanDistrictDescpription, String.UrbanDistrictAbbreviation);
		AddToPresentationAddressItem(Presentation, String.CityName, String.CityAbbr);
		AddToPresentationAddressItem(Presentation, String.RegionName, String.RegionAbbr);
		AddToPresentationAddressItem(Presentation, String.DistrictName, String.DistrictReduction);
		AddToPresentationAddressItem(Presentation, String.RFTerritorialEntityName, String.RFTerritorialEntityAbbreviation);
		ResultRow.Presentation = Presentation;
		
	EndDo;
	
EndProcedure

// Returns helper data - OKATO, OKTMO etc codes
// 
// Parameters:
//     ID - UUID - Identifier of an address object, landmark or helper data.
// 
// Returns:
//     Structure -  found variants. Contains fields:
//       * Denial                        - Boolean - Vendor is not available.
//       * DetailedErrorPresentation - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       * BriefErrorPresentation   - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       *Data                       - Structure - Data fields:
//           ** OKATO            - Digit, Undefined if the result is not found.
//           ** OKTMO            - Digit, Undefined if the result is not found.
//           ** CodeIFTSIndividual        - Digit, Undefined if the result is not found.
//           ** CodeIFTSLegEnt        - Digit, Undefined if the result is not found.
//           ** DepartmentCodeIFTSIndividual - Digit, Undefined if the result is not found.
//           ** DepartmentCodeIFTSLegalEntity - Digit, Undefined if the result is not found.
//
Function AdditionalAddressInformation(ID) Export
	
	Result = New Structure("Data", AdditionalAddressInformationStructure() );
	VendorErrorDescriptionStructure(Result);
	
	Source = AddressClassifierDataSource();
	If IsBlankString(Source) Then
		// Local, always correct.
		FillAdditionalAddressInformationExt(Result, ID);
		
	ElsIf Source = "Service1C" Then
		// 1C web service, may be under maintenance.
		Try
			FillAdditionalAddressInformation1CService(Result, ID);
		Except
			VendorErrorDescriptionStructure(Result, ErrorInfo());
			WriteLogEvent( EventLogMonitorEvent(), EventLogLevel.Error, , , Result.DetailErrorDescription);
		EndTry;
		
	EndIf;
	
	Return Result;
EndFunction

// Constructor of a structure - result.
//
Function AdditionalAddressInformationStructure() Export
	
	Return New Structure("OKATO, OKTMO, CodeIFTSIndividual, CodeIFTSLegEnt, DepartmentCodeIFTSIndividual, DepartmentCodeIFTSLegEnt");
	
EndFunction

// Fill in additional data by the 1C service data.
//
Procedure FillAdditionalAddressInformation1CService(Result, ID)
	
	Service = AddressClassifierReUse.ClassifierService1C();
	
	LanguageCode = CurrentLocaleCode();
	ServiceData = Service.GetExtraInfo(String(ID), LanguageCode, Metadata.Name);
	
	Data = Result.Data;
	Data.OKATO            = ServiceData.OKATO;
	Data.OKTMO            = ServiceData.OKTMO;
	Data.IFTSIndividualCode        = ServiceData.IFNSFL;
	Data.IFTSLegalEntityCode        = ServiceData.IFNSUL;
	Data.IFTSIndividualDepartmentCode = ServiceData.TERRIFNSFL;
	Data.IFTSLegalEntityDepartmentCode = ServiceData.TERRIFNSUL;
	
EndProcedure

// Fill in additional data from the imported data.
//
Procedure FillAdditionalAddressInformationExt(Result, ID) Export
	
	QueryText = 
#Region QueryText
		"SELECT TOP 1
		|	OKATO, 
		|	OKTMO, 
		|	IFTSIndividualCode, 
		|	IFTSLegalEntityCode, 
		|	IFTSIndividualDepartmentCode, 
		|	IFTSLegalEntityDepartmentCode
		|FROM
		|	InformationRegister.AdditionalAddressInformation
		|WHERE	
		|	ID In (
		|		// As an identifier of additional information
		|		SELECT 
		|			&ID
		|		UNION ALL
		|		// As an identifier of an address object
		|		SELECT TOP 1
		|			Additionally
		|		FROM
		|			InformationRegister.AddressObjects
		|		WHERE
		|			ID = &ID
		|		// As the identifier of a landmark
		|		UNION ALL
		|		SELECT TOP 1
		|			Additionally
		|		FROM
		|			InformationRegister.AddressObjectsLandmarks
		|		WHERE
		|			ID = &ID
		|	)
		|";
#EndRegion

	Query = New Query(QueryText);
	Query.SetParameter("ID", ID);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(Result.Data, Selection);
	EndIf;
	
EndProcedure

// Returns actual data of an address object or a landmark accurate to the subordinate (without houses).
// 
// Parameters:
//     ID - UUID - Identifier of address object or landmark.
// 
// Returns:
//     Structure -  found variants. Contains fields:
//       * Denial                        - Boolean - Vendor is not available.
//       * DetailedErrorPresentation - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       * BriefErrorPresentation   - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       *Data                       - XDTODataObject - Address, see (http://www.v8.1c.ru/ssl/contactinfo) RFAddress.
//
Function ActualAddressInformation(ID) Export
	
	Data = Undefined;
	Result = New Structure("Data", Data);
	VendorErrorDescriptionStructure(Result);
	
	Source = AddressClassifierDataSource();
	If IsBlankString(Source) Then
		// Local, always correct.
		FillRelevantAddressInformationExt(Result, ID);
		
	ElsIf Source = "Service1C" Then
		// 1C web service, may be under maintenance.
		Try
			FillRelevantAddressInformation1CService(Result, ID);
		Except
			VendorErrorDescriptionStructure(Result, ErrorInfo());
			WriteLogEvent( EventLogMonitorEvent(), EventLogLevel.Error, , , Result.DetailErrorDescription);
		EndTry;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Fill in actual data of an address object or a landmark by 1C service data.
//
Procedure FillRelevantAddressInformation1CService(Result, ID)
	
	Service = AddressClassifierReUse.ClassifierService1C();
	
	LanguageCode = CurrentLocaleCode();
	Data   = Service.GetActualInfo(String(ID), LanguageCode, Metadata.Name);
	Result.Data = Data;
	
EndProcedure

// Fill in the actual data of an address object or a landmark from the imported data.
//
Procedure FillRelevantAddressInformationExt(Result, ID) Export
	
	QueryText = 
#Region QueryText
		"SELECT
		|	RFTerritorialEntity.Description            + "" "" + RFTerritorialEntity.Abbr            AS RFTerritorialEntityPresentation,
		|	District.Description                + "" "" + District.Abbr                AS DistrictPresentation,
		|	Region.Description                + "" "" + Region.Abbr                AS RegionPresentation,
		|	City.Description                + "" "" + City.Abbr                AS CityPresentation,
		|	UrbanDistrict.Description + "" "" + UrbanDistrict.Abbr AS UrbanRegionPresentation,
		|	Settlement.Description      + "" "" + Settlement.Abbr      AS SettlementPresentation,
		|	Street.Description                + "" "" + Street.Abbr                AS StreetPresentation,
		|	Additional.Description       + "" "" + Additional.Abbr       AS AdditionalPresentation,
		|	subordinated.Description          + "" "" + subordinated.Abbr          AS SubordinatePresentation,
		|
		|	ObjectAddress.LandmarkDescription AS LandmarkDescription,
		|	
		|	ObjectAddress.PostalIndex AS PostalIndex,
		|	AdditionalInformation.OKATO  AS OKATO,
		|	AdditionalInformation.OKTMO  AS OKTMO,
		|	
		|	ServiceAddressDataIndex.Value                                                                              AS TypeAddrElPostalCode,
		|	ISNULL(ServiceAddressDataAdditional.Value, DefaultServiceAddressInformationAdditional.Value) AS TypeAddrElAdditional,
		|	ISNULL(ServiceAddressInformationSubordinate.Value, DefaultServiceAddressInformationSubordinate.Value)       AS TypeAddrElSubordinate
		|
		|FROM (
		|	SELECT
		|		RFTerritorialEntityCode              AS RFTerritorialEntityCode,
		|		DistrictCode                  AS DistrictCode,
		|		RegionCode                  AS RegionCode,
		|		CityCode                  AS CityCode,
		|		UrbanDistrictCode  AS UrbanDistrictCode,
		|		SettlementCode       AS SettlementCode,
		|		StreetCode                   AS StreetCode,
		|		AdditionalItemCode AS AdditionalItemCode,
		|		SubordinateItemCode    AS SubordinateItemCode,
		|		PostalIndex             AS PostalIndex,
		|		Additionally              AS Additionally,
		|		NULL                       AS LandmarkDescription
		|	FROM		
		|		InformationRegister.AddressObjects
		|	WHERE 
		|		ID = &ID
		|	UNION ALL 
		|	SELECT
		|		RegisterAddressObject.RFTerritorialEntityCode              AS RFTerritorialEntityCode,
		|		RegisterAddressObject.DistrictCode                  AS DistrictCode,
		|		RegisterAddressObject.RegionCode                  AS RegionCode,
		|		RegisterAddressObject.CityCode                  AS CityCode,
		|		RegisterAddressObject.UrbanDistrictCode  AS UrbanDistrictCode,
		|		RegisterAddressObject.SettlementCode       AS SettlementCode,
		|		RegisterAddressObject.StreetCode                   AS StreetCode,
		|		RegisterAddressObject.AdditionalItemCode AS AdditionalItemCode,
		|		RegisterAddressObject.SubordinateItemCode    AS SubordinateItemCode,
		|		Landmark.PostalIndex                          AS PostalIndex,
		|		Landmark.Additionally                           AS Additionally,
		|		Landmark.Definition                                AS LandmarkDescription
		|	FROM		
		|		InformationRegister.AddressObjectsLandmarks AS Landmark
		|	LEFT JOIN
		|		InformationRegister.AddressObjects AS RegisterAddressObject
		|	ON
		|		RegisterAddressObject.ID = Landmark.AddressObject
		|	WHERE 
		|		Landmark.ID = &ID
		|		
		|) AS ObjectAddress
		|	
		|// Object hierarchy
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS RFTerritorialEntity
		|ON
		|	RFTerritorialEntity.Level = 1
		|	AND RFTerritorialEntity.RFTerritorialEntityCode              = ObjectAddress.RFTerritorialEntityCode
		|	AND RFTerritorialEntity.DistrictCode                  = 0
		|	AND RFTerritorialEntity.RegionCode                  = 0
		|	AND RFTerritorialEntity.CityCode                  = 0
		|	AND RFTerritorialEntity.UrbanDistrictCode  = 0
		|	AND RFTerritorialEntity.SettlementCode       = 0
		|	AND RFTerritorialEntity.StreetCode                   = 0
		|	AND RFTerritorialEntity.AdditionalItemCode = 0
		|	AND RFTerritorialEntity.SubordinateItemCode    = 0
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS District
		|ON
		|	District.Level = 2
		|	AND District.RFTerritorialEntityCode              = ObjectAddress.RFTerritorialEntityCode
		|	AND District.DistrictCode                  = ObjectAddress.DistrictCode
		|	AND District.RegionCode                  = 0
		|	AND District.CityCode                  = 0
		|	AND District.UrbanDistrictCode  = 0
		|	AND District.SettlementCode       = 0
		|	AND District.StreetCode                   = 0
		|	AND District.AdditionalItemCode = 0
		|	AND District.SubordinateItemCode    = 0
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS Region
		|ON
		|	Region.Level = 3
		|	AND Region.RFTerritorialEntityCode              = ObjectAddress.RFTerritorialEntityCode
		|	AND Region.DistrictCode                  = ObjectAddress.DistrictCode
		|	AND Region.RegionCode                  = ObjectAddress.RegionCode
		|	AND Region.CityCode                  = 0
		|	AND Region.UrbanDistrictCode  = 0
		|	AND Region.SettlementCode       = 0
		|	AND Region.StreetCode                   = 0
		|	AND Region.AdditionalItemCode = 0
		|	AND Region.SubordinateItemCode    = 0
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS City
		|ON
		|	City.Level = 4
		|	AND City.RFTerritorialEntityCode              = ObjectAddress.RFTerritorialEntityCode
		|	AND City.DistrictCode                  = ObjectAddress.DistrictCode
		|	AND City.RegionCode                  = ObjectAddress.RegionCode
		|	AND City.CityCode                  = ObjectAddress.CityCode
		|	AND City.UrbanDistrictCode  = 0
		|	AND City.SettlementCode       = 0
		|	AND City.StreetCode                   = 0
		|	AND City.AdditionalItemCode = 0
		|	AND City.SubordinateItemCode    = 0
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS UrbanDistrict
		|ON
		|	UrbanDistrict.Level = 5
		|	AND UrbanDistrict.RFTerritorialEntityCode              = ObjectAddress.RFTerritorialEntityCode
		|	AND UrbanDistrict.DistrictCode                  = ObjectAddress.DistrictCode
		|	AND UrbanDistrict.RegionCode                  = ObjectAddress.RegionCode
		|	AND UrbanDistrict.CityCode                  = ObjectAddress.CityCode
		|	AND UrbanDistrict.UrbanDistrictCode  = ObjectAddress.UrbanDistrictCode
		|	AND UrbanDistrict.SettlementCode       = 0
		|	AND UrbanDistrict.StreetCode                   = 0
		|	AND UrbanDistrict.AdditionalItemCode = 0
		|	AND UrbanDistrict.SubordinateItemCode    = 0
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS Settlement
		|ON
		|	Settlement.Level = 6
		|	AND Settlement.RFTerritorialEntityCode              = ObjectAddress.RFTerritorialEntityCode
		|	AND Settlement.DistrictCode                  = ObjectAddress.DistrictCode
		|	AND Settlement.RegionCode                  = ObjectAddress.RegionCode
		|	AND Settlement.CityCode                  = ObjectAddress.CityCode
		|	AND Settlement.UrbanDistrictCode  = ObjectAddress.UrbanDistrictCode
		|	AND Settlement.SettlementCode       = ObjectAddress.SettlementCode
		|	AND Settlement.StreetCode                   = 0
		|	AND Settlement.AdditionalItemCode = 0
		|	AND Settlement.SubordinateItemCode    = 0
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS Street
		|ON
		|	Street.Level = 7
		|	AND Street.RFTerritorialEntityCode              = ObjectAddress.RFTerritorialEntityCode
		|	AND Street.DistrictCode                  = ObjectAddress.DistrictCode
		|	AND Street.RegionCode                  = ObjectAddress.RegionCode
		|	AND Street.CityCode                  = ObjectAddress.CityCode
		|	AND Street.UrbanDistrictCode  = ObjectAddress.UrbanDistrictCode
		|	AND Street.SettlementCode       = ObjectAddress.SettlementCode
		|	AND Street.StreetCode                   = ObjectAddress.StreetCode
		|	AND Street.AdditionalItemCode = 0
		|	AND Street.SubordinateItemCode    = 0
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS Additional
		|ON
		|	Additional.Level = 90
		|	AND Additional.RFTerritorialEntityCode              = ObjectAddress.RFTerritorialEntityCode
		|	AND Additional.DistrictCode                  = ObjectAddress.DistrictCode
		|	AND Additional.RegionCode                  = ObjectAddress.RegionCode
		|	AND Additional.CityCode                  = ObjectAddress.CityCode
		|	AND Additional.UrbanDistrictCode  = ObjectAddress.UrbanDistrictCode
		|	AND Additional.SettlementCode       = ObjectAddress.SettlementCode
		|	AND Additional.StreetCode                   = ObjectAddress.StreetCode
		|	AND Additional.AdditionalItemCode = ObjectAddress.AdditionalItemCode
		|	AND Additional.SubordinateItemCode    = 0
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS subordinated
		|ON
		|	subordinated.Level = 91
		|	AND subordinated.RFTerritorialEntityCode              = ObjectAddress.RFTerritorialEntityCode
		|	AND subordinated.DistrictCode                  = ObjectAddress.DistrictCode
		|	AND subordinated.RegionCode                  = ObjectAddress.RegionCode
		|	AND subordinated.CityCode                  = ObjectAddress.CityCode
		|	AND subordinated.UrbanDistrictCode  = ObjectAddress.UrbanDistrictCode
		|	AND subordinated.SettlementCode       = ObjectAddress.SettlementCode
		|	AND subordinated.StreetCode                   = ObjectAddress.StreetCode
		|	AND subordinated.AdditionalItemCode = ObjectAddress.AdditionalItemCode
		|	AND subordinated.SubordinateItemCode    = ObjectAddress.SubordinateItemCode
		|
		|// Additional data
		|LEFT JOIN
		|	InformationRegister.AdditionalAddressInformation AS AdditionalInformation
		|ON
		|	AdditionalInformation.ID = ObjectAddress.Additionally
		|
		|// Values of types for contact information
		|LEFT JOIN
		|	InformationRegister.ServiceAddressData AS ServiceAddressDataIndex
		|ON
		|	ServiceAddressDataIndex.Type             = ""TypeAdrEl""
		|	AND ServiceAddressDataIndex.ID = 0
		|	AND ServiceAddressDataIndex.Key          = ""PostalIndex""
		|LEFT JOIN
		|	InformationRegister.ServiceAddressData AS ServiceAddressDataAdditional
		|ON
		|	ServiceAddressDataAdditional.Type             = ""TypeAdrEl""
		|	AND ServiceAddressDataAdditional.ID = 90
		|	AND ServiceAddressDataAdditional.Key          = Additional.Abbr
		|LEFT JOIN
		|	InformationRegister.ServiceAddressData AS ServiceAddressInformationSubordinate
		|ON
		|	ServiceAddressInformationSubordinate.Type             = ""TypeAdrEl""
		|	AND ServiceAddressInformationSubordinate.ID = 91
		|	AND ServiceAddressInformationSubordinate.Key          = subordinated.Abbr
		|
		|LEFT JOIN
		|	InformationRegister.ServiceAddressData AS DefaultServiceAddressInformationAdditional
		|ON
		|	ServiceAddressDataAdditional.Type             = ""TypeAdrEl""
		|	AND ServiceAddressDataAdditional.ID = 90
		|	AND ServiceAddressDataAdditional.Key          = """"
		|LEFT JOIN
		|	InformationRegister.ServiceAddressData AS DefaultServiceAddressInformationSubordinate
		|ON
		|	ServiceAddressInformationSubordinate.Type             = ""TypeAdrEl""
		|	AND ServiceAddressInformationSubordinate.ID = 91
		|	AND ServiceAddressInformationSubordinate.Key          = """"
		|";
#EndRegion

	// Empty address
	Address = XDTOFactory.Create( XDTOFactory.Type( NamesSpaceRFAddress(), "AddressRF") );
	Result.Data = Address;
	
	Query = New Query(QueryText);
	Query.SetParameter("ID", New UUID(ID));
	Selection = Query.Execute().Select();
	If Not Selection.Next() Then
		Return;
	EndIf;
	
	SetXDTOObjectAttribute(Address, "RFTerritorialEntity",      Selection.RFTerritorialEntityPresentation);
	SetXDTOObjectAttribute(Address, "District",          Selection.RegionPresentation);
	SetXDTOObjectAttribute(Address, "PrRayMO/Region",  Selection.RegionPresentation);
	SetXDTOObjectAttribute(Address, "City",          Selection.CityPresentation);
	SetXDTOObjectAttribute(Address, "Settlement",     Selection.SettlementPresentation);
	SetXDTOObjectAttribute(Address, "UrbDistrict",   Selection.UrbanRegionPresentation);
	SetXDTOObjectAttribute(Address, "Street",          Selection.StreetPresentation);
	SetXDTOObjectAttribute(Address, "OKATO",          Selection.OKATO);
	SetXDTOObjectAttribute(Address, "OKTMO",          Selection.OKTMO);
	SetXDTOObjectAttribute(Address, "Location", Selection.LandmarkDescription);
	
	
	// Additional properties
	AddXDTOListAttribute(Address, "AddEMailAddress", New Structure("TypeAdrEl, Value", Selection.TypeAddrElPostalCode, Selection.PostalIndex));
	
	If Not IsBlankString(Selection.AdditionalPresentation) Then 
		AddXDTOListAttribute(Address, "AddEMailAddress", New Structure("TypeAdrEl, Value", AdditionalItemCode(Selection.AdditionalPresentation),
			Selection.AdditionalPresentation));
	EndIf;
	
	AddXDTOListAttribute(Address, "AddEMailAddress", New Structure("TypeAdrEl, Value", "10400000", Selection.SubordinatePresentation));
	
EndProcedure

Function AdditionalItemCode(AdditionalPresentation) 
	
	Abbr = Upper(AddressClassifierClientServer.DescriptionAndAbbreviation(AdditionalPresentation).Abbr);
	If Abbr = "GSK" Then
		Return "10600000";
	ElsIf Abbr = "SNT" Then
		Return "10300000";
	ElsIf Abbr = "TER" Then
		Return "10700000";
	EndIf;

	Return "10200000";
EndFunction

//  Sets values of identifiers for address parts.
//  
//  Parameters:
//      AddressIdentifier - UUID - Data source for filling in.
//      SettlementInDetail  - Structure - address parts.
//
Procedure SetAddressPartsIDs(PartsAddresses) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	State.ID AS IdentifierState,
		|	District.ID AS IdentifierDistrict,
		|	Region.ID AS IdentifierRegion,
		|	City.ID AS IdentifierCity,
		|	UrbDistrict.ID AS IdentifierUrbanDistrict,
		|	Settlement.ID AS IdentifierSettlement,
		|	Street.ID AS IdentifierStreet,
		|	AdditionalItem.ID AS IdentifierAdditionalItem,
		|	SubordinateItem.ID AS SubordinateItemIdentifier
		|FROM
		|	InformationRegister.AddressObjects AS AddressObject
		|		LEFT JOIN InformationRegister.AddressObjects AS State
		|		ON (State.Level = 1)
		|			AND (State.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (State.DistrictCode = 0)
		|			AND (State.RegionCode = 0)
		|			AND (State.CityCode = 0)
		|			AND (State.UrbanDistrictCode = 0)
		|			AND (State.SettlementCode = 0)
		|			AND (State.StreetCode = 0)
		|			AND (State.AdditionalItemCode = 0)
		|			AND (State.SubordinateItemCode = 0)
		|		LEFT JOIN InformationRegister.AddressObjects AS District
		|		ON (District.Level = 2)
		|			AND (District.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (District.DistrictCode = AddressObject.DistrictCode)
		|			AND (District.RegionCode = 0)
		|			AND (District.CityCode = 0)
		|			AND (District.UrbanDistrictCode = 0)
		|			AND (District.SettlementCode = 0)
		|			AND (District.StreetCode = 0)
		|			AND (District.AdditionalItemCode = 0)
		|			AND (District.SubordinateItemCode = 0)
		|		LEFT JOIN InformationRegister.AddressObjects AS Region
		|		ON (Region.Level = 3)
		|			AND (Region.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (Region.DistrictCode = AddressObject.DistrictCode)
		|			AND (Region.RegionCode = AddressObject.RegionCode)
		|			AND (Region.CityCode = 0)
		|			AND (Region.UrbanDistrictCode = 0)
		|			AND (Region.SettlementCode = 0)
		|			AND (Region.StreetCode = 0)
		|			AND (Region.AdditionalItemCode = 0)
		|			AND (Region.SubordinateItemCode = 0)
		|		LEFT JOIN InformationRegister.AddressObjects AS City
		|		ON (City.Level = 4)
		|			AND (City.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (City.DistrictCode = AddressObject.DistrictCode)
		|			AND (City.RegionCode = AddressObject.RegionCode)
		|			AND (City.CityCode = AddressObject.CityCode)
		|			AND (City.UrbanDistrictCode = 0)
		|			AND (City.SettlementCode = 0)
		|			AND (City.StreetCode = 0)
		|			AND (City.AdditionalItemCode = 0)
		|			AND (City.SubordinateItemCode = 0)
		|		LEFT JOIN InformationRegister.AddressObjects AS UrbDistrict
		|		ON (UrbDistrict.Level = 5)
		|			AND (UrbDistrict.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (UrbDistrict.DistrictCode = AddressObject.DistrictCode)
		|			AND (UrbDistrict.RegionCode = AddressObject.RegionCode)
		|			AND (UrbDistrict.CityCode = AddressObject.CityCode)
		|			AND (UrbDistrict.UrbanDistrictCode = AddressObject.UrbanDistrictCode)
		|			AND (UrbDistrict.SettlementCode = 0)
		|			AND (UrbDistrict.StreetCode = 0)
		|			AND (UrbDistrict.AdditionalItemCode = 0)
		|			AND (UrbDistrict.SubordinateItemCode = 0)
		|		LEFT JOIN InformationRegister.AddressObjects AS Settlement
		|		ON (Settlement.Level = 6)
		|			AND (Settlement.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (Settlement.DistrictCode = AddressObject.DistrictCode)
		|			AND (Settlement.RegionCode = AddressObject.RegionCode)
		|			AND (Settlement.CityCode = AddressObject.CityCode)
		|			AND (Settlement.UrbanDistrictCode = AddressObject.UrbanDistrictCode)
		|			AND (Settlement.SettlementCode = AddressObject.SettlementCode)
		|			AND (Settlement.StreetCode = 0)
		|			AND (Settlement.AdditionalItemCode = 0)
		|			AND (Settlement.SubordinateItemCode = 0)
		|		LEFT JOIN InformationRegister.AddressObjects AS Street
		|		ON (Street.Level = 7)
		|			AND (Street.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (Street.DistrictCode = AddressObject.DistrictCode)
		|			AND (Street.RegionCode = AddressObject.RegionCode)
		|			AND (Street.CityCode = AddressObject.CityCode)
		|			AND (Street.UrbanDistrictCode = AddressObject.UrbanDistrictCode)
		|			AND (Street.SettlementCode = AddressObject.SettlementCode)
		|			AND (Street.StreetCode = AddressObject.StreetCode)
		|			AND (Street.AdditionalItemCode = 0)
		|			AND (Street.SubordinateItemCode = 0)
		|		LEFT JOIN InformationRegister.AddressObjects AS AdditionalItem
		|		ON (AdditionalItem.Level = 90)
		|			AND (AdditionalItem.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (AdditionalItem.DistrictCode = AddressObject.DistrictCode)
		|			AND (AdditionalItem.RegionCode = AddressObject.RegionCode)
		|			AND (AdditionalItem.CityCode = AddressObject.CityCode)
		|			AND (AdditionalItem.UrbanDistrictCode = AddressObject.UrbanDistrictCode)
		|			AND (AdditionalItem.SettlementCode = AddressObject.SettlementCode)
		|			AND (AdditionalItem.StreetCode = AddressObject.StreetCode)
		|			AND (AdditionalItem.AdditionalItemCode = AddressObject.AdditionalItemCode)
		|			AND (AdditionalItem.SubordinateItemCode = 0)
		|		LEFT JOIN InformationRegister.AddressObjects AS SubordinateItem
		|		ON (SubordinateItem.Level = 91)
		|			AND (SubordinateItem.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (SubordinateItem.DistrictCode = AddressObject.DistrictCode)
		|			AND (SubordinateItem.RegionCode = AddressObject.RegionCode)
		|			AND (SubordinateItem.CityCode = AddressObject.CityCode)
		|			AND (SubordinateItem.UrbanDistrictCode = AddressObject.UrbanDistrictCode)
		|			AND (SubordinateItem.SettlementCode = AddressObject.SettlementCode)
		|			AND (SubordinateItem.StreetCode = AddressObject.StreetCode)
		|			AND (SubordinateItem.AdditionalItemCode = AddressObject.AdditionalItemCode)
		|			AND (SubordinateItem.SubordinateItemCode = AddressObject.SubordinateItemCode) ";
		
		Where = "";
		Delimiter = " WHERE ";
		For Each part In PartsAddresses Do
			Value = part.Value;
			If ValueIsFilled(Value.Presentation) Then
				Where = Where + Delimiter + part.Key +".Description = """ + Value.Description + """ AND " + part.Key + ".Abbr = """ + Value.Abbr + """";
				Delimiter = " AND ";
			EndIf;
		EndDo;
		Query.Text = Query.Text + Where;
		QueryResult = Query.Execute().Select();
	
		If QueryResult.Next() Then
			For Each part In PartsAddresses Do
				If ValueIsFilled(part.Value.Presentation) Then
					part.Value.ID = QueryResult["ID" + part.Key];
				EndIf;
			EndDo;
		EndIf;
	
EndProcedure

Procedure SetSettlementIdentifiers(PartsAddresses, SettlementIdentifier) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	State.ID AS IdentifierState,
		|	District.ID AS IdentifierDistrict,
		|	Region.ID AS IdentifierRegion,
		|	City.ID AS IdentifierCity,
		|	UrbDistrict.ID AS IdentifierUrbanDistrict,
		|	Settlement.ID AS IdentifierSettlement
		|FROM
		|	InformationRegister.AddressObjects AS AddressObject
		|		LEFT JOIN InformationRegister.AddressObjects AS State
		|		ON (State.Level = 1)
		|			AND (State.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (State.DistrictCode = 0)
		|			AND (State.RegionCode = 0)
		|			AND (State.CityCode = 0)
		|			AND (State.UrbanDistrictCode = 0)
		|			AND (State.SettlementCode = 0)
		|			AND (State.StreetCode = 0)
		|			AND (State.AdditionalItemCode = 0)
		|			AND (State.SubordinateItemCode = 0)
		|		LEFT JOIN InformationRegister.AddressObjects AS District
		|		ON (District.Level = 2)
		|			AND (District.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (District.DistrictCode = AddressObject.DistrictCode)
		|			AND (District.RegionCode = 0)
		|			AND (District.CityCode = 0)
		|			AND (District.UrbanDistrictCode = 0)
		|			AND (District.SettlementCode = 0)
		|			AND (District.StreetCode = 0)
		|			AND (District.AdditionalItemCode = 0)
		|			AND (District.SubordinateItemCode = 0)
		|		LEFT JOIN InformationRegister.AddressObjects AS Region
		|		ON (Region.Level = 3)
		|			AND (Region.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (Region.DistrictCode = AddressObject.DistrictCode)
		|			AND (Region.RegionCode = AddressObject.RegionCode)
		|			AND (Region.CityCode = 0)
		|			AND (Region.UrbanDistrictCode = 0)
		|			AND (Region.SettlementCode = 0)
		|			AND (Region.StreetCode = 0)
		|			AND (Region.AdditionalItemCode = 0)
		|			AND (Region.SubordinateItemCode = 0)
		|		LEFT JOIN InformationRegister.AddressObjects AS City
		|		ON (City.Level = 4)
		|			AND (City.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (City.DistrictCode = AddressObject.DistrictCode)
		|			AND (City.RegionCode = AddressObject.RegionCode)
		|			AND (City.CityCode = AddressObject.CityCode)
		|			AND (City.UrbanDistrictCode = 0)
		|			AND (City.SettlementCode = 0)
		|			AND (City.StreetCode = 0)
		|			AND (City.AdditionalItemCode = 0)
		|			AND (City.SubordinateItemCode = 0)
		|		LEFT JOIN InformationRegister.AddressObjects AS UrbDistrict
		|		ON (UrbDistrict.Level = 5)
		|			AND (UrbDistrict.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (UrbDistrict.DistrictCode = AddressObject.DistrictCode)
		|			AND (UrbDistrict.RegionCode = AddressObject.RegionCode)
		|			AND (UrbDistrict.CityCode = AddressObject.CityCode)
		|			AND (UrbDistrict.UrbanDistrictCode = AddressObject.UrbanDistrictCode)
		|			AND (UrbDistrict.SettlementCode = 0)
		|			AND (UrbDistrict.StreetCode = 0)
		|			AND (UrbDistrict.AdditionalItemCode = 0)
		|			AND (UrbDistrict.SubordinateItemCode = 0)
		|		LEFT JOIN InformationRegister.AddressObjects AS Settlement
		|		ON (Settlement.Level = 6)
		|			AND (Settlement.RFTerritorialEntityCode = AddressObject.RFTerritorialEntityCode)
		|			AND (Settlement.DistrictCode = AddressObject.DistrictCode)
		|			AND (Settlement.RegionCode = AddressObject.RegionCode)
		|			AND (Settlement.CityCode = AddressObject.CityCode)
		|			AND (Settlement.UrbanDistrictCode = AddressObject.UrbanDistrictCode)
		|			AND (Settlement.SettlementCode = AddressObject.SettlementCode)
		|			AND (Settlement.StreetCode = 0)
		|			AND (Settlement.AdditionalItemCode = 0)
		|			AND (Settlement.SubordinateItemCode = 0)";
		
		Where = "";
		Delimiter = " WHERE ";
		For Each part In PartsAddresses Do
			Value = part.Value;
			If ValueIsFilled(Value.Presentation) AND part.Value.Level < 7 Then
				Where = Where + Delimiter + part.Key +".Description = """ + Value.Description + """ AND " + part.Key + ".Abbr = """ + Value.Abbr + """";
				Delimiter = " AND ";
			EndIf;
		EndDo;
		
		Query.Text = Query.Text + Where;
		
		If ValueIsFilled(SettlementIdentifier) Then
			Query.Text = Query.Text + Delimiter + " AddressObject.ID = &Identifier";
			Query.SetParameter("Identifier", SettlementIdentifier);
		EndIf;
		
		QueryResult = Query.Execute().Select();
		
		LowerLevelWithIdentifier = 0;
		If QueryResult.Next() Then
			For Each part In PartsAddresses Do
				If ValueIsFilled(part.Value.Presentation)  AND part.Value.Level < 7 Then
					part.Value.Identifier = QueryResult["Identifier" + part.Key];
					If ValueIsFilled(part.Value.Identifier) AND LowerLevelWithIdentifier < part.Value.Level Then
						SettlementIdentifier = part.Value.Identifier;
						LowerLevelWithIdentifier = part.Value.Level;
					EndIf;
				EndIf;
			EndDo;
		EndIf;
		
		
	
EndProcedure

// Checks data for compliance with a classifier.
// 
// Parameters:
//     Addresses - Array - Checked addresses. Contains structures with fields:
//         * Address                             - XDTOObject, Row - Checked
//                                               address ((http://www.v8.1c.ru/ssl/contactinfo) RFAddress) or
//                                               its XML-serialization.
//         * AddressFormat - String - Type of the used classifier for the checking.
// 
// Returns:
//     Structure -  found variants. Contains fields:
//       * Denial                        - Boolean - Vendor is not available.
//       * DetailedErrorPresentation - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       * BriefErrorPresentation   - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       *Data                       - Array - Checking result. Result index matches to
//                                                 the Addresses parameter index.
//                                                 Each item of array - structure containing fields:
//           ** Errors   - Array     - Definition errors search in classifier. Consists in structures From fields.
//               *** Key      - String - Service identifier of an error location - path XPath in object XDTO.
//               *** Text     - String - Text Errors.
//               *** ToolTip - String - Text of a possible change of an error.
//           ** Variants - Array     - Contains description of the found variants. Each item - structure with fields:
//               *** ID    - UUID  - Code of the object classifier - variant.
//               *** IndexOf           - Number - Postal code of the object - variant.
//               *** ARCACode         - Number - Code AC nearest object.
//               *** OKATO            - Number - Data FTS.
//               *** OKTMO            - Number - Data FTS.
//               *** IFTSIndividualCode        - Number - Data FTS.
//               *** IFTSLegalEntityCode        - Number - Data FTS.
//               *** IFTSIndividualDepartmentCode - Number - Data FTS.
//               *** IFTSLegalEntityDepartmentCode - Number - FTS data.
//
Function AddressesCheckResultByClassifier(Addresses) Export
	
	Result = New Structure("Data", New Array);
	VendorErrorDescriptionStructure(Result);
	
	// Cast types
	AddressForChecking = New Array;
	StringType         = Type("String");

	For Each CheckedAddress In Addresses Do
		If CheckedAddress.AddressFormat = "FIAS" Then
			Levels = AddressClassifierReUse.FIASClassifierLevels();
		Else
			Levels = AddressClassifierReUse.AddressClassifierLevels();
		EndIf;
		
		AddressXDTO = CheckedAddress.Address;
		If TypeOf(AddressXDTO) = StringType Then
			If CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
				FullXDTOAddress = XDTOAddressDeserialization(AddressXDTO);
				AddressXDTO = FullXDTOAddress.Content.Content;
			Else 
				Result.Cancel = True;
				Result.BriefErrorDescription = NStr("en='Address can not be checked as it was not recognized.';ru='Адрес не может быть проверен, так как не распознан.'");
				Result.DetailErrorDescription = Result.BriefErrorDescription;
				Return Result;
			EndIf;
		EndIf;
		
		AddressForChecking.Add(New Structure("Address, Levels", AddressXDTO, Levels));
	EndDo;
	
	Source = AddressClassifierDataSource();
	If IsBlankString(Source) Then
		// Local, always correct.
		FillAddressCheckResultByClassifierInter(Result, AddressForChecking);
		
	ElsIf Source = "Service1C" Then
		// 1C web service, may be under maintenance.
		Try
			FillAddressCheckResultByClassifier1CService(Result, AddressForChecking);
		Except
			VendorErrorDescriptionStructure(Result, ErrorInfo());
			WriteLogEvent( EventLogMonitorEvent(), EventLogLevel.Error, , , Result.DetailErrorDescription);
		EndTry;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Filling the result of checking the address object by the service data.
//
Procedure FillAddressCheckResultByClassifier1CService(Result, AddressForChecking)
	
	Service = AddressClassifierReUse.ClassifierService1C();
	
	ListForChecking = Service.XDTOFactory.Create(Service.XDTOFactory.Type(TargetNamespace(), "AddressList"));
	AddressType = Service.XDTOFactory.Type(NamesSpaceRFAddress(), "AddressRF");
	ListPointType = ListForChecking.Properties().Get("Item").Type;
	
	For Each CheckingItem In AddressForChecking Do
		CheckedAddress =  ListForChecking.Item.Add(Service.XDTOFactory.Create(ListPointType));
		CheckedAddress.Address = CommonUse.ObjectXDTOFromXMLRow(CommonUse.ObjectXDTOInXMLString(CheckingItem.Address), Service.XDTOFactory);
		CheckedAddress.Levels  = CheckingItem.Levels;
	EndDo;
	
	LanguageCode = CurrentLocaleCode();
	
	CheckResult = Service.Analyze(ListForChecking, LanguageCode, False, Metadata.Name);
	
	// Generate the result structure.
	Data = Result.Data;
	For Each CheckingItem In CheckResult.Item Do
		DataForAddress = New Structure("Errors, Variants, AddressChecked", New Array, New Array, True);
		CheckingError = DataForAddress.Errors;
		AddressVariants = DataForAddress.Variants;
		
		For Each Error In CheckingItem.Error Do
			AddressError = New Structure("Key, Text, ToolTip", Error.Key, Error.Text, Error.Suggestion);
			CheckingError.Add(AddressError);
		EndDo;
		
		For Each Variant In CheckingItem.Variant Do
			AddressVariant = New Structure("Identifier, ZipCode, KLADRCode", Variant.ID, Variant.PostalCode, Variant.KLADRCode);
			AddressVariant.Insert("OKATO",            Variant.OKATO);
			AddressVariant.Insert("OKTMO",            Variant.OKTMO);
			AddressVariant.Insert("IFTSIndividualCode",        Variant.IFNSFL);
			AddressVariant.Insert("IFTSLegalEntityCode",        Variant.IFNSUL);
			AddressVariant.Insert("IFTSIndividualDepartmentCode", Variant.TERRIFNSFL);
			AddressVariant.Insert("IFTSLegalEntityDepartmentCode", Variant.TERRIFNSUL);
			AddressVariants.Add(AddressVariant);
		EndDo;
		
		Data.Add(DataForAddress);
	EndDo;
	
EndProcedure

// Filling in the result of checking an address object by the imported data.
//
Procedure FillAddressCheckResultByClassifierInter(Result, AddressForChecking) Export
	
	Data = Result.Data;
	For Each CheckingItem In AddressForChecking Do
		SingleChecking = OneAddressAnalysisByClassifier(CheckingItem.Address, CheckingItem.Levels);
		Data.Add(SingleChecking);
	EndDo;

EndProcedure 

// Local check of one address.
//
Function OneAddressAnalysisByClassifier(Address, Levels)
	
	Result = New Structure("Errors, Variants, AddressChecked", New Array, New Array, True);
	CheckingError = Result.Errors;
	AddressVariants = Result.Variants;

	// RF territorial entity should always present
	RFTerritorialEntity = AddressClassifierClientServer.DescriptionAndAbbreviation(Address.RFTerritorialEntity);
	If IsBlankString(RFTerritorialEntity.Description) Then
		// No territorial entity
		AddAddressCheckingErrorByClassifier(CheckingError, "RFTerritorialEntity", NStr("en='RF territorial entity of an address is not specified';ru='Не указан субъект РФ адреса'") );
		Return Result;
	ElsIf Levels.Find(1) = Undefined Then
		// Should always be specified in levels.
		Raise NStr("en='In the levels for checking address, a level of RF territorial entity is not specified.';ru='В уровнях для проверки адреса не указан уровень субъекта РФ.'");
	EndIf;
	
	StateImportedToAddressInformation = InformationAboutState(Address.RFTerritorialEntity).Imported;
	If StateImportedToAddressInformation = Undefined Then 
			AddAddressCheckingErrorByClassifier(CheckingError, "RFTerritorialEntity", StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='%1 state does not exist';ru='Регион ""%1"" не существует'"), 
				Address.RFTerritorialEntity
			));
		Result.AddressChecked = True;
		Return Result;
	ElsIf Not StateImportedToAddressInformation Then
		AddAddressCheckingErrorByClassifier(CheckingError, "RFTerritorialEntity", NStr("en='Address information by state is unavailable';ru='Отсутствуют адресные сведения по региону'") + " " + Address.RFTerritorialEntity);
		Result.AddressChecked = False;
		Return Result;
	EndIf;
	
	// Decryption of the address properties
	Query = New Query(
#Region QueryText
		"SELECT
		|	Value
		|FROM 
		|	InformationRegister.ServiceAddressData
		|WHERE	
		|	Type = ""TypeAdrEl"" AND Key = ""PostalIndex""
		|;//////////////////////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Key          AS Abbr,
		|	ID AS ID,
		|	Value      AS Value
		|FROM
		|	InformationRegister.ServiceAddressData
		|WHERE
		|	Type = ""TypeAdrEl""
		|	AND (
		|		ID = 91 OR ID = 90
		|	)
		|;//////////////////////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Details.Key     AS Value,
		|	Details.Value AS TypeAdrEl,
		|	
		|	CASE 
		|		WHEN Not OwnershipTypes.ID IS NULL THEN OwnershipTypes.ID
		|		WHEN Not ConstructionTypes.ID IS NULL THEN ConstructionTypes.ID
		|		ELSE 0
		|	END AS ID
		|	
		|FROM
		|	InformationRegister.ServiceAddressData AS Details
		|	
		|LEFT JOIN
		|	InformationRegister.ServiceAddressData AS OwnershipTypes
		|ON
		|	OwnershipTypes.Type = ""ESTSTAT""
		|	AND OwnershipTypes.Value = Details.Key
		|	
		|LEFT JOIN
		|	InformationRegister.ServiceAddressData AS ConstructionTypes
		|ON
		|	ConstructionTypes.Type = ""STRSTAT""
		|	AND ConstructionTypes.Value = Details.Key
		|	
		|WHERE
		|	Details.Type = ""AdditAddrENumber""
		|"
#EndRegion
		);
	ResultsSet = Query.ExecuteBatch();
	
	Table = ResultsSet[0].Unload();
	If Table.Count() = 0 Then
		TypeAddrElPostalCode = "";
	Else
		TypeAddrElPostalCode = Table[0].Value;
	EndIf;
	
	AdditionalAbbreviationsTable = ResultsSet[1].Unload();
	AdditionalAbbreviationsTable.Indexes.Add("Abbreviation, Value");
	
	BuildingsAbbreviationsTable = ResultsSet[2].Unload();
	BuildingsAbbreviationsTable.Indexes.Add("TypeAdrEl");
	
	PostalIndex   = 0;
	Additional   = New Structure("Description, Abbr");
	subordinated      = New Structure("Description, Abbr");
	BuildingsAndFacilities = New Map;
	
	NumberType = New TypeDescription("Number");
	For Each AdditionalItem In Address.GetList("AddEMailAddress") Do
		AddressPointType = TrimAll(AdditionalItem.TypeAdrEl);
		
		// Building or unit, postal code?
		If AddressPointType = "" Then
			NumberValue = AdditionalItem.Number;
				RowBuildings = BuildingsAbbreviationsTable.Find(NumberValue.Type, "TypeAdrEl");
				If RowBuildings <> Undefined Then
					BuildingsAndFacilities[RowBuildings.Value] = New Structure("Kind, Value", RowBuildings.ID, NumberValue.Value);;
				EndIf;
			Continue;
		ElsIf AddressPointType = TypeAddrElPostalCode Then
			PostalIndex = NumberType.AdjustValue(AdditionalItem.Value);
			Continue;
		EndIf;
		
		// Additional or subordinate?
		Variant = AddressClassifierClientServer.DescriptionAndAbbreviation(AdditionalItem.Value);
		VariantsRows = AdditionalAbbreviationsTable.FindRows( New Structure("Abbreviation, Value", Variant.Abbr, AddressPointType));
		If VariantsRows.Count() > 0 Then
			Code = VariantsRows[0].ID;
			If Code = 90 Then
				Additional = Variant;
			ElsIf Code = 91 Then
				subordinated = Variant;
			EndIf;
		EndIf;
		
	EndDo;
		
	District                = AddressClassifierClientServer.DescriptionAndAbbreviation(Address.District);
	Region                = AddressClassifierClientServer.DescriptionAndAbbreviation(GetXDTOObjectAttribute(Address, "PrRayMO/Region"));
	City                = AddressClassifierClientServer.DescriptionAndAbbreviation(Address.City);
	UrbanDistrict = AddressClassifierClientServer.DescriptionAndAbbreviation(Address.UrbDistrict);
	Settlement      = AddressClassifierClientServer.DescriptionAndAbbreviation(Address.Settlement);
	Street                = AddressClassifierClientServer.DescriptionAndAbbreviation(Address.Street);
	IndexItem        = GetXDTOObjectAttribute(Address, "AddEMailAddress[TypeAdrEl='10100000']");
	IndexOf               = ?(IndexItem <> Undefined, IndexItem.Value, "");
	
	CheckRegion                = Not IsBlankString(District.Description)                AND Levels.Find(2) <> Undefined;
	CheckRegion                = Not IsBlankString(Region.Description)                AND Levels.Find(3) <> Undefined;
	CheckCity                = Not IsBlankString(City.Description)                AND Levels.Find(4) <> Undefined;
	CheckUrbanDistrict = Not IsBlankString(UrbanDistrict.Description) AND Levels.Find(5) <> Undefined;
	CheckSettlement      = Not IsBlankString(Settlement.Description)      AND Levels.Find(6) <> Undefined;
	CheckStreet                = Not IsBlankString(Street.Description)                AND Levels.Find(7) <> Undefined;
	CheckAdditional       = Not IsBlankString(Additional.Description)       AND Levels.Find(90) <> Undefined;
	CheckSubordinate          = Not IsBlankString(subordinated.Description)          AND Levels.Find(91) <> Undefined;

	Query.Text = 
#Region QueryText
		"SELECT
		|	TRUE                                  AS RFTerritorialEntityFound,
		|	RFTerritorialEntity.ID                 AS RFTerritorialEntityIdentifier,
		|	RFTerritorialEntity.PostalIndex                AS RFTerritorialEntityPostalCode,
		|	RFTerritorialEntity.RFTerritorialEntityCode                 AS RFTerritorialEntityCode,
		|	RFTerritorialEntity.ARCACode                      AS RFTerritorialEntityKLADRCode,
		|	RFTerritorialEntity.Additionally                 AS RFTerritorialEntityAdditionally,
		|	RFTerritorialEntityAdditionally.OKATO            AS RFTerritorialEntityAdditionallyOKATO,
		|	RFTerritorialEntityAdditionally.OKTMO            AS RFTerritorialEntityAdditionallyOKTMO,
		|	RFTerritorialEntityAdditionally.IFTSIndividualCode        AS RFTerritorialEntityCodeIFTSIndividual,
		|	RFTerritorialEntityAdditionally.IFTSLegalEntityCode        AS RFTerritorialEntityAdditionallyCodeIFTSLegEnt,
		|	RFTerritorialEntityAdditionally.IFTSIndividualDepartmentCode AS RFTerritorialEntityAdditionallyDepartmentCodeIFTSIndividual,
		|	RFTerritorialEntityAdditionally.IFTSLegalEntityDepartmentCode AS RFTerritorialEntityAdditionallyDepartmentCodeIFTSLegalEntity,
		|
		|	SELECT
		|	TRUE                                  AS RFTerritorialEntityFound,
		|	RFTerritorialEntity.ID                 AS RFTerritorialEntityIdentifier,
		|	RFTerritorialEntity.PostalIndex                AS RFTerritorialEntityPostalCode,
		|	RFTerritorialEntity.RFTerritorialEntityCode                 AS RFTerritorialEntityCode,
		|	RFTerritorialEntity.ARCACode                      AS RFTerritorialEntityKLADRCode,
		|	RFTerritorialEntity.Additionally                 AS RFTerritorialEntityAdditionally,
		|	RFTerritorialEntityAdditionally.OKATO            AS RFTerritorialEntityAdditionallyOKATO,
		|	RFTerritorialEntityAdditionally.OKTMO            AS RFTerritorialEntityAdditionallyOKTMO,
		|	RFTerritorialEntityAdditionally.IFTSIndividualCode        AS RFTerritorialEntityCodeIFTSIndividual,
		|	RFTerritorialEntityAdditionally.IFTSLegalEntityCode        AS RFTerritorialEntityAdditionallyCodeIFTSLegEnt,
		|	RFTerritorialEntityAdditionally.IFTSIndividualDepartmentCode AS RFTerritorialEntityAdditionallyDepartmentCodeIFTSIndividual,
		|	RFTerritorialEntityAdditionally.IFTSLegalEntityDepartmentCode AS RFTerritorialEntityAdditionallyDepartmentCodeIFTSLegalEntity,
		|
		|	" + AddressCheckingOptionalFieldsText(CheckRegion,                "District") + "
		|	" + AddressCheckingOptionalFieldsText(CheckRegion,                "Region") + "
		|	" + AddressCheckingOptionalFieldsText(CheckCity,                "City") + "
		|	" + AddressCheckingOptionalFieldsText(CheckUrbanDistrict, "UrbanDistrict") + "
		|	" + AddressCheckingOptionalFieldsText(CheckSettlement,      "Settlement") + "
		|	" + AddressCheckingOptionalFieldsText(CheckStreet,                "Street") + "
		|	" + AddressCheckingOptionalFieldsText(CheckAdditional,       "Additional") + "
		|	" + AddressCheckingOptionalFieldsText(CheckSubordinate,          "subordinated") + "
		|
		|	HousesBuildingsConstructions.PostalCode
		|	AS HousesPostalCode, NULL AS HousesCodeKLADR,
		|	NULL AS HousesAdditionally, NULL AS HousesAdditionallyOKATO,
		|	NULL AS HousesAdditionallyOKTMO, NULL AS HousesAdditionallyCodeIFTSIndividual,
		|	NULL AS HousesAdditionallyCodeIFTSLegEnt, NULL
		|	AS HousesAdditionallyDepartmentCodeIFTSIndividual, NULL AS HousesAdditionallyDepartmentCodeIFTSLegEnt,
		|	HousesBuildingsConstructions.Constructions AS
		|	Constructions FROM // Subordinacy hierarchy InformationRegister.AddressObjects
		|	AS RFTerritorialEntity LEFT JOIN InformationRegister.AdditionalAddressInformation AS
		|
		|	RFTerritorialEntityAdditionally BY RFTerritorialEntityAdditionally.Identifier
		|
		|=
		|	RFTerritorialEntity.Additionally
		|
		|" + ?(CheckRegion, "
		|LEFT
		|	JOIN InformationRegister.AddressObjects AS
		|District
		|	BY District.Description = &DistrictName
		|	AND District.Abbreviation = &RegionAbbr
		|	AND District.Level = 2 AND District.RFTerritorialEntityCode
		|	= RFTerritorialEntity.RFTerritorialEntityCode
		|	AND District.RegionCode = 0 AND District.CityCode = 0 AND District.UrbanDistrictCode
		|	= 0 AND District.SettlementCode
		|	= 0 AND District.StreetCode
		|	= 0 AND District.AdditionalItemCode = 0 AND District.SubordinateItemCode
		|	= 0 LEFT JOIN InformationRegister.AdditionalAddressInformation
		|	AS
		|	DistrictAdditionally BY DistrictAdditionally.Identifier
		|=
		|	District.Additionally
		|", "") + "
		|
		|" + ?(CheckRegion, "
		|LEFT
		|	JOIN InformationRegister.AddressObjects AS
		|District
		|	BY District.Description = &DistrictName
		|	AND District.Abbreviation = &DistrictAbbreviation AND District.Level
		|	= 3 AND District.RFTerritorialEntityCode = RFTerritorialEntity.RFTerritorialEntityCode
		|	AND District.RegionCode
		|	= " + ?(CheckRegion, "District.DistrictCode", "0") + "
		|	AND District.CityCode = 0 District.UrbanDistrictCode
		|	= 0 AND District.SettlementCode
		|	= 0 AND District.StreetCode =
		|	0 AND District.AdditionalItemCode = 0 AND
		|	District.SubordinateItemCode = 0
		|	LEFT JOIN InformationRegister.AdditionalAddressInformation
		|AS
		|	DistrictAdditionally BY DistrictAdditionally.Identifier
		|=
		|	DistrictAdditionally
		|", "") + "
		|
		|" + ?(CheckCity, " 
		|LEFT
		|	JOIN InformationRegister.AddressObjects AS
		|City
		|	BY City.Name = &CityName
		|	AND City.Abbreviation = &CityAbbreviation AND City.Level
		|	= 4 AND City.RFTerritorialEntityCode = RFTerritorialEntity.RFTerritorialEntityCode
		|	AND City.RegionCode
		|	= " + ?(CheckRegion, "District.DistrictCode", "0") + "
		|	AND City.RegionCode = " + ?(CheckRegion, "Region.RegionCode", "0") + "
		|	AND City.UrbanDistrictCode = 0
		|	AND City.SettlementCode = 0 AND City.StreetCode
		|	= 0 AND City.AdditionalItemCode
		|	= 0 AND
		|	City.SubordinateItemCode = 0 LEFT JOIN InformationRegister.AdditionalAddressInformation
		|AS
		|	CityAdditionally BY CityAdditionally.Identifier
		|=
		|	City.Additionaly
		|", "") + "
		|
		|" + ?(CheckUrbanDistrict, "
		|LEFT
		|	JOIN InformationRegister.AddressObjects AS
		|UrbanDistrict
		|	BY UrbanDistrict.Description = &UrbanDistrictDescpription
		|	AND UrbanDistrict.Abbreviation = &UrbanDistrictAbbreviation
		|	AND UrbanDistrict.Level = 5 AND UrbanDistrict.RFTerritorialEntityCode = RFTerritorialEntity.RFTerritorialEntityCode
		|	AND UrbanDistrict.DistrictCode
		|	= " + ?(CheckRegion, "District.DistrictCode", "0") + "
		|	AND UrbanDistrict.RegionCode = " + ?(CheckRegion, "Region.RegionCode", "0") + "
		|	AND UrbanDistrict.CityCode = " + ?(CheckCity, "City.CityCode",  "0") + "
		|	AND UrbanDistrict.SettlementCode = 0 AND UrbanDistrict.StreetCode
		|	= 0 AND UrbanDistrict.AdditionalItemCode
		|	= 0 AND
		|	UrbanDistrict.SubordinateItemCode = 0 LEFT JOIN InformationRegister.AdditionalAddressInformation
		|AS
		|	UrbanDistrictAdditionally
		|By
		|	UrbanDistrictAdditionally.Identifier = UrbanDistrict.Additionally
		|", "") + "
		|
		|" + ?(CheckSettlement, "
		|LEFT
		|	JOIN InformationRegister.AddressObjects AS
		|Settlement
		|	BY Settlement.Name = &SettlementName
		|	AND Settlement.Abbreviation = &SettlementAbbreviation AND Settlement.Level
		|	= 6 AND Settlement.RFTerritorialEntityCode = RFTerritorialEntity.RFTerritorialEntityCode
		|	AND Settlement.DistrictCode
		|	= " + ?(CheckRegion, "District.DistrictCode", "0") + "
		|	AND Settlement.RegionCode = " + ?(CheckRegion, "Region.RegionCode", "0") + "
		|	AND Settlement.CityCode = " + ?(CheckCity, "City.CityCode", "0") + "
		|	AND Settlement.UrbanDistrictCode = " + ?(CheckUrbanDistrict, "UrbanDistrict.UrbanDistrictCode", "0") + "
		|	AND Settlement.StreetCode = 0 AND Settlement.AdditionalItemCode
		|	= 0 AND
		|	Settlement.SubordinateItemCode = 0 LEFT JOIN InformationRegister.AdditionalAddressInformation
		|AS
		|	SettlementAdditionally
		|BY
		|	SettlementAdditionally.Identifier = Settlement.Additionaly
		|", "") + "
		|
		|" + ?(CheckStreet, "
		|LEFT
		|	JOIN InformationRegister.AddressObjects AS
		|Street
		|	BY Street.Name = &StreetName
		|	AND Street.Abbreviation = &StreetAbbreviation AND Street.Level
		|	= 7 AND Street.RFTerritorialEntityCode = RFTerritorialEntity.RFTerritorialEntityCode
		|	AND Street.DistrictCode
		|	= " + ?(CheckRegion, "District.DistrictCode", "0") + "
		|	AND Street.RegionCode = " + ?(CheckRegion, "Region.RegionCode", "0") + "
		|	And Street.CityCode = " + ?(CheckCity, "City.CityCode", "0") + "
		|	AND Street.UrbanDistrictCode = " + ?(CheckUrbanDistrict, "UrbanDistrict.UrbanDistrictCode", "0") + "
		|	AND Street.SettlementCode = " + ?(CheckSettlement, "Settlement.SettlementCode", "0") + "
		|	AND Street.AdditionalItemCode =
		|	0 AND Street.SubordinateItemCode = 0 LEFT
		|JOIN
		|	InformationRegister.AdditionalAddressInformation AS StreetAdditionally
		|BY
		|	StreetAdditionally.Identifier = Street.Additionaly
		|", "") + "
		|	
		|" + ?(CheckAdditional, "
		|LEFT
		|	JOIN InformationRegister.AddressObjects AS
		|Additional
		|	BY Additional.Name = &AdditionalName
		|	AND Additional.Abbreviation = &AdditionalAbbreviation AND Additional.Level
		|	= 90 AND Additional.RFTerritorialEntityCode = RFTerritorialEntity.RFTerritorialEntityCode
		|	AND Additional.DistrictCode
		|	= " + ?(CheckRegion, "District.DistrictCode", "0") + "
		|	AND Additional.RegionCode = " + ?(CheckRegion, "Region.RegionCode", "0") + "
		|	AND Additional.CityCode = " + ?(CheckCity, "City.CityCode", "0") + "
		|	AND Additional.UrbanDistrictCode = " + ?(CheckUrbanDistrict, "UrbanDistrict.UrbanDistrictCode", "0") + "
		|	AND Additional.SettlementCode = " + ?(CheckSettlement, "Settlement.SettlementCode", "0") + "
		|	AND Additional.StreetCode = " + ?(CheckStreet, "Street.StreetCode", "0") + "
		|	AND Additional.SubordinateItemCode = 0
		|LEFT JOIN
		|InformationRegister.AdditionalAddressInformation AS
		|AdditionalAdditionally
		|BY AdditionalAdditionally.Identifier = Additional.Additionaly
		|", "") + "
		|	
		|" + ?(CheckSubordinate, "
		|LEFT
		|	JOIN InformationRegister.AddressObjects AS
		|Subordinate
		|	BY Subordinate.Name = &SubordinateName
		|	AND Subordinate.Abbreviation = &SubordinateAbbreviation AND Subordinate.Level
		|	= 91 AND Subordinate.RFTerritorialEntityCode = RFTerritorialEntity.RFTerritorialEntityCode
		|	AND Subordinate.DistrictCode
		|	= " + ?(CheckRegion, "District.DistrictCode", "0") + "
		|	AND Subordinate.RegionCode = " + ?(CheckRegion, "Region.RegionCode", "0") + "
		|	AND Subordinate.CityCode = " + ?(CheckCity, "City.CityCode", "0") + "
		|	AND Subordinate.UrbanDistrictCode = " + ?(CheckUrbanDistrict, "UrbanDistrict.UrbanDistrictCode", "0") + "
		|	AND Subordinate.SettlementCode " + ?(CheckSettlement, "Settlement.SettlementCode", "0") + "
		|	AND Subordinate.StreetCode = " + ?(CheckStreet, "Street.StreetCode", "0") + "
		|	And Subordinate.AdditionalItemCode = " + ?(CheckAdditional, "Additional.AdditionalItemCode", "0") + "
		|LEFT
		|	JOIN InformationRegister.AdditionalAddressInformation
		|AS
		|	SubordinateAdditionally BY SubordinateAdditionally.Identifier = SubordinateAdditionally
		|", "") + "
		|
		|// Write buildings
		|and constructions
		|LEFT JOIN InformationRegister.HousesBuildingsConstructions
		|AS
		|HousesBuildingsConstructions.AddressObject = 
		|" + ?(CheckSubordinate,          "Subordinate.Identifier", "
		|" + ?(CheckAdditional,       "Additional.Identifier", "
		|" + ?(CheckStreet,                "Street.ID", "
		|" + ?(CheckSettlement,      "Settlement.ID", "
		|" + ?(CheckUrbanDistrict, "UrbanDistrict.Identifier", "
		|" + ?(CheckCity,                "City.ID", "
		|" + ?(CheckRegion,                "Region.ID", "
		|" + ?(CheckRegion,                "District.ID", "
		|	RFTerritorialEntity.Identifier")))))))) + "
		|
		|// Condition for a state that
		|is	
		|	  always present WHERE
		|RFTerritorialEntity.Name = &RFTerritorialEntityName AND RFTerritorialEntity.Abbreviation =
		|&RFTerritorialEntityAbbreviation AND RFTerritorialEntity.Level =
		|1 AND RFTerritorialEntity.StateCode = 0 AND RFTerritorialEntity.StateCode
		|= 0 AND RFTerritorialEntity.CityCode
		|= 0 AND RFTerritorialEntity.UrbanStateCode = 0 AND RFTerritorialEntity.SettlementCode
		|= 0 AND RFTerritorialEntity.StreetCode
		|= 0 AND RFTerritorialEntity.AdditionalItemCode
		|= 0 AND RFTerritorialEntity.SubordinateItemCode
		|= 0
		|";
#EndRegion

	Query.SetParameter("RFTerritorialEntityName", RFTerritorialEntity.Description);
	Query.SetParameter("RFTerritorialEntityAbbreviation",   RFTerritorialEntity.Abbr);
	
	Query.SetParameter("DistrictName", District.Description);
	Query.SetParameter("DistrictReduction",   District.Abbr);
	
	Query.SetParameter("RegionName", Region.Description);
	Query.SetParameter("RegionAbbr",   Region.Abbr);
	
	Query.SetParameter("CityName", City.Description);
	Query.SetParameter("CityAbbr",   City.Abbr);
	
	Query.SetParameter("UrbanDistrictDescpription", UrbanDistrict.Description);
	Query.SetParameter("UrbanDistrictAbbreviation",   UrbanDistrict.Abbr);
	
	Query.SetParameter("SettlementName", Settlement.Description);
	Query.SetParameter("SettlementAbbr",   Settlement.Abbr);
	
	Query.SetParameter("StreetName", Street.Description);
	Query.SetParameter("StreetAbbr",   Street.Abbr);
	
	Query.SetParameter("AdditionalName", Additional.Description);
	Query.SetParameter("AdditionalAbbreviation",   Additional.Abbr);
	
	Query.SetParameter("SubordinateName", subordinated.Description);
	Query.SetParameter("SubordinateAbbreviation",   subordinated.Abbr);

	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		// No state
		AddAddressCheckingErrorByClassifier(CheckingError, "RFTerritorialEntity", StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='RF territorial entity (state) %1 is not found in the address classifier';ru='Субъект РФ (регион) ""%1"" не найден в адресном классификаторе'"), RFTerritorialEntity.Description + " " + RFTerritorialEntity.Abbr));
		Return Result;
		
	EndIf;
	
	// Keep only records that have all correct data.
	HousesRecords = QueryResult.Unload();
	CorrectRecords = New Array;
	
	For Each Record In HousesRecords Do;
	
		If CheckRegion AND Not Record.RegionFound Then
			AddAddressCheckingErrorByClassifier(CheckingError, "District", StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='There is no %1 county in the address classifier.';ru='Округ ""%1"" отсутствует в адресном классификаторе'"), 
				District.Description + " " + District.Abbr
			));
		EndIf;
		
		If CheckRegion AND Not Record.RegionFound Then
			AddAddressCheckingErrorByClassifier(CheckingError, "PrRayMO/Region", StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='There is no %1 region in the address classifier.';ru='Район ""%1"" отсутствует в адресном классификаторе'"), 
				Region.Description + " " + Region.Abbr
			));
		EndIf;
		
		If CheckCity AND Not Record.CityFound Then
			AddAddressCheckingErrorByClassifier(CheckingError, "City", StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='There is no %1 city in the address classifier.';ru='Город ""%1"" отсутствует в адресном классификаторе'"), 
				City.Description + " " + City.Abbr
			));
		EndIf;
		
			
		If CheckUrbanDistrict AND Not Record.UrbanRegionFound Then
			AddAddressCheckingErrorByClassifier(CheckingError, "UrbDistrict", StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='There is no %1 urban district in an address classifier';ru='Внутригородской район ""%1"" отсутствует в адресном классификаторе'"), 
				UrbanDistrict.Description + " " + UrbanDistrict.Abbr
			));
		EndIf;
			
		If CheckSettlement AND Not Record.SettlementFound Then
			AddAddressCheckingErrorByClassifier(CheckingError, "Settlement", StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='There is no settlement %1 in the address classifier.';ru='Населенный пункт ""%1"" отсутствует в адресном классификаторе'"), 
				Settlement.Description + " " + Settlement.Abbr
			));
		EndIf;
		
		If CheckStreet AND Not Record.StreetFound Then
			ObjectHistory = AddressObjectHistory(Street.Description, Street.Abbr, Record);
			If ObjectHistory.Count() > 0 Then 
				For Each RowObject In ObjectHistory Do
					AddAddressCheckingErrorByClassifier(CheckingError, "Street", StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='%1 street was renamed as %2';ru='Улица ""%1"" была переименована в ""%2""'"), 
					RowObject.Value, RowObject.Presentation
					));
				EndDo;
			Else
				AddAddressCheckingErrorByClassifier(CheckingError, "Street", StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='There is no %1 street in the address classifier.';ru='Улица ""%1"" отсутствует в адресном классификаторе'"), 
					Street.Description + " " + Street.Abbr
				));
			EndIf;
		EndIf;
			
		If CheckAdditional AND Not Record.AdditionalFound Then
			AddAddressCheckingErrorByClassifier(CheckingError, "Additional", StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='There is no %1 additional item in an address classifier';ru='Дополнительный элемент ""%1""отсутствует в адресном классификаторе'"), 
				Additional.Description + " " + Additional.Abbr
			));
		EndIf;
			
		If CheckSubordinate AND Not Record.SubordinateFound Then
			AddAddressCheckingErrorByClassifier(CheckingError, "subordinated", StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='There is no %1 subordinate item in the address classifier';ru='Подчиненный элемент ""%1"" отсутствует в адресном классификаторе'"), 
				subordinated.Description + " " + subordinated.Abbr
			));
		EndIf;
			
		If CheckingError.Count() = 0 Then
			// The whole record is correct
			CorrectRecords.Add(Record);
		EndIf;
		
	EndDo;
	
	If CorrectRecords.Count() = 0 Then
		// There is no point looking for houses and issuing variants, it is better to look in history.
		Return Result;
	EndIf;
	
	HasHousesRecords = False;
	CorrectIndex = False;
	If Not Levels.Find(90) = Undefined Then
		For Each Record In CorrectRecords Do
			// If Record.Buildings equals to Null that means that there are no houses by this address.
			If ValueIsFilled(Record.Buildings) Then
				Definition = Record.Buildings.Get();
				
				AddressVariant = New Structure;
				FillPostalIndexAndKLADRCodeByFIASHierarchy(AddressVariant, Record);
				If ValueIsFilled(IndexOf) AND Format(AddressVariant.IndexOf, "NGS=' '; NG=0") = IndexOf Then
					CorrectIndex = True;
				EndIf;
				
				If Not IsBlankString(Definition) Then
					IdentifierAdditionally = UUIDFromRow64(Left(Definition, 24));
					Definition = Mid(Definition, 25);
					If Not IsBlankString(Definition) Then
						HasHousesRecords = True;
						
						If BuildingsDescriptionFIASContainsData(Definition, BuildingsAndFacilities) Then
							FillIdentifierByHierarchyFIAS(AddressVariant, Record);
							FillAdditionalDataByFIASHierarchy(AddressVariant, Record, IdentifierAdditionally);
							AddressVariants.Add(AddressVariant);
						EndIf;
					EndIf;
				EndIf;
			EndIf;
		EndDo;
		
	EndIf;
	
	AreOptions = AddressVariants.Count() > 0;
	
	If HasHousesRecords AND Not AreOptions Then
		
		BuildingDescriptionByFIASMatching = BuildingDescriptionByFIASMatching(BuildingsAndFacilities);
		If ValueIsFilled(BuildingDescriptionByFIASMatching) Then
			AddAddressCheckingErrorByClassifier(CheckingError, "subordinated", StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='There is no %1 in the address classifier';ru='""%1"" отсутствует в адресном классификаторе'"), BuildingDescriptionByFIASMatching(BuildingsAndFacilities)
			));
		EndIf;
		
		AddressVariant = New Structure;
		FillPostalIndexAndKLADRCodeByFIASHierarchy(AddressVariant, Record);
		If ValueIsFilled(IndexOf) AND Format(AddressVariant.IndexOf, "NGS=' '; NG=0") = IndexOf Then
			CorrectIndex = True;
		EndIf;

	ElsIf Not HasHousesRecords AND Not AreOptions Then
		// Add variants, do not consider it to be an error
		For Each Record In CorrectRecords Do
			AddressVariant = New Structure;
			FillIdentifierByHierarchyFIAS(AddressVariant, Record);
			FillAdditionalDataByFIASHierarchy(AddressVariant, Record, Undefined);
			FillPostalIndexAndKLADRCodeByFIASHierarchy(AddressVariant, Record);
			AddressVariants.Add(AddressVariant);
			
			If ValueIsFilled(IndexOf) AND Format(AddressVariant.IndexOf, "NGS=' '; NG=0") = IndexOf Then
				CorrectIndex = True;
			EndIf;
		EndDo;
		
	EndIf;
	
		// Check index
	If Not CorrectIndex AND ValueIsFilled(IndexOf) Then
		AddAddressCheckingErrorByClassifier(CheckingError, "IndexOf", StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='ZipCode ""%1"" in the address classifier does not correspond to the entered address';ru='Индекс ""%1"" в адресном классификаторе не соответствует введенному адресу'"), IndexOf));
	EndIf;
	
	Return Result;
EndFunction

Function AddressObjectHistory(Description, Abbr, Record)
	
	Result = New ValueList;
	
	QueryText = "SELECT
	|	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	|	AddressObjects.DistrictCode AS DistrictCode,
	|	AddressObjects.RegionCode AS RegionCode,
	|	AddressObjects.CityCode AS CityCode,
	|	AddressObjects.UrbanDistrictCode AS UrbanDistrictCode,
	|	AddressObjects.SettlementCode AS SettlementCode
	|INTO AddressObjectTable
	|FROM
	|	InformationRegister.AddressObjects AS AddressObjects
	|WHERE
	|	AddressObjects.ID = &ID
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AddressObjectsHistory.ID AS ID,
	|	AddressObjectsHistory.CurrentRFTerritorialEntityCode AS CurrentRFTerritorialEntityCode,
	|	AddressObjectsHistory.PostalIndex AS PostalIndex,
	|	AddressObjectsHistory.Description AS Description,
	|	AddressObjectsHistory.Abbr AS Abbr,
	|	AddressObjectsHistory.Additionally AS Additionally,
	|	AddressObjectsHistory.ARCACode AS ARCACode,
	|	AddressObjectsHistory.AddressObject AS AddressObject,
	|	AddressObjectsHistory.RecordActionBegin AS RecordActionBegin,
	|	AddressObjectsHistory.RecordActionEnd AS RecordActionEnd,
	|	AddressObjectsHistory.Operation AS Operation,
	|	AddressObjectsHistory.Level AS Level,
	|	AddressObjects.Description AS CurrentName,
	|	AddressObjects.Abbr AS CurrentAbbreviation
	|FROM
	|	AddressObjectTable AS CurrentAddress
	|		LEFT JOIN InformationRegister.AddressObjectsHistory AS AddressObjectsHistory
	|		ON (AddressObjectsHistory.RFTerritorialEntityCode = CurrentAddress.RFTerritorialEntityCode)
	|			AND (AddressObjectsHistory.DistrictCode = CurrentAddress.DistrictCode)
	|			AND (AddressObjectsHistory.RegionCode = CurrentAddress.RegionCode)
	|			AND (AddressObjectsHistory.CityCode = CurrentAddress.CityCode)
	|			AND (AddressObjectsHistory.UrbanDistrictCode = CurrentAddress.UrbanDistrictCode)
	|			AND (AddressObjectsHistory.SettlementCode = CurrentAddress.SettlementCode)
	|		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	|		ON (AddressObjectsHistory.AddressObject = AddressObjects.ID)
	|WHERE
	|	AddressObjectsHistory.Description = &Description
	|	AND AddressObjectsHistory.Abbr = &Abbr";
	
	
	QuerySchema = New QuerySchema();
	QuerySchema.SetQueryText(QueryText);
	
	Variant = New Structure;
	FillIdentifierByHierarchyFIAS(Variant, Record);
	If Not ValueIsFilled(Variant.ID) Then
		Return Result;
	EndIf;
	
	Query = New Query(QuerySchema.GetQueryText());
	Query.SetParameter("Description", Description);
	Query.SetParameter("Abbr", Abbr);
	Query.SetParameter("ID", Variant.ID);
	
	QueryResult = Query.Execute();
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		Result.Add(Description + " " + Abbr, SelectionDetailRecords.CurrentName + " " + SelectionDetailRecords.CurrentAbbreviation);
	EndDo;
	
	Return Result;
	
EndFunction

// Returns the identifier of the address object by address parts.
//
// Parameters:
//  Address	 - XDTOFactory - Object address.
//  SearchByStreet - Boolean - Search by street.
// Returns:
//  UUID - identifier of an address object.
Function AddressObjectIdentifierByAddressParts(Address, SearchByStreet = False) Export
	
	If Address = Undefined Then
		Return Undefined;
	EndIf;
	
	RFTerritorialEntityCode = 0;
	RFTerritorialEntityIdentifier = Undefined;
	DistrictCode = 0;
	RegionCode = 0;
	CityCode = 0;
	UrbanDistrictCode = 0;
	SettlementCode = 0;
	StreetCode = 0;
	SettlementIdentifier = Undefined;
	
	If ValueIsFilled(Address.RFTerritorialEntity)  Then
		RFTerritorialEntity = AddressClassifierClientServer.DescriptionAndAbbreviation(Address.RFTerritorialEntity);
		Query = New Query;
		Query.Text = 
			"SELECT
			|	AddressObject.ID AS IdentifierAddressObject,
			|	AddressObject.RFTerritorialEntityCode
			|FROM
			|	InformationRegister.AddressObjects AS AddressObject
			|WHERE
			|	AddressObject.Description = &Description
			|	AND AddressObject.Level = 1
			|	AND AddressObject.DistrictCode = 0
			|	AND AddressObject.RegionCode = 0
			|	AND AddressObject.CityCode = 0
			|	AND AddressObject.UrbanDistrictCode = 0
			|	AND AddressObject.SettlementCode = 0
			|	AND AddressObject.StreetCode = 0
			|	AND AddressObject.AdditionalItemCode = 0
			|	AND AddressObject.SubordinateItemCode = 0
			|	AND AddressObject.Abbr = &Abbr";
		
		Query.SetParameter("Description", RFTerritorialEntity.Description);
		Query.SetParameter("Abbr", RFTerritorialEntity.Abbr);
		QueryResult = Query.Execute().Select();
		
		If QueryResult.Next() Then
			RFTerritorialEntityCode = QueryResult.RFTerritorialEntityCode;
			SettlementIdentifier =  QueryResult.IdentifierAddressObject;
		EndIf;
	EndIf;
	
	If ValueIsFilled(Address.District) Then
		District = AddressClassifierClientServer.DescriptionAndAbbreviation(Address.District);
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	AddressObject.ID AS IdentifierAddressObject,
			|	AddressObject.DistrictCode
			|FROM
			|	InformationRegister.AddressObjects AS AddressObject
			|WHERE
			|	AddressObject.Description = &Description
			|	AND AddressObject.Level = 2
			|	AND AddressObject.RFTerritorialEntityCode = &RFTerritorialEntityCode
			|	AND AddressObject.RegionCode = 0
			|	AND AddressObject.CityCode = 0
			|	AND AddressObject.UrbanDistrictCode = 0
			|	AND AddressObject.SettlementCode = 0
			|	AND AddressObject.StreetCode = 0
			|	AND AddressObject.AdditionalItemCode = 0
			|	AND AddressObject.SubordinateItemCode = 0
			|	AND AddressObject.Abbr = &Abbr";
		
		Query.SetParameter("RFTerritorialEntityCode", RFTerritorialEntityCode);
		Query.SetParameter("Description", District.Description);
		Query.SetParameter("Abbr", District.Abbr);
		
		QueryResult = Query.Execute().Select();
		
		If QueryResult.Next() Then
			DistrictCode = QueryResult.DistrictCode;
			SettlementIdentifier =  QueryResult.IdentifierAddressObject;
		EndIf;
	EndIf;

	If Address.PrRayMO <> Undefined AND ValueIsFilled(Address.PrRayMO.Region) Then
		
		Region = AddressClassifierClientServer.DescriptionAndAbbreviation(Address.PrRayMO.Region);
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	AddressObject.ID AS IdentifierAddressObject,
			|	AddressObject.RegionCode
			|FROM
			|	InformationRegister.AddressObjects AS AddressObject
			|WHERE
			|	AddressObject.Description = &Description
			|	AND AddressObject.Level = 3
			|	AND AddressObject.RFTerritorialEntityCode = &RFTerritorialEntityCode
			|	AND AddressObject.DistrictCode = &DistrictCode
			|	AND AddressObject.CityCode = 0
			|	AND AddressObject.UrbanDistrictCode = 0
			|	AND AddressObject.SettlementCode = 0
			|	AND AddressObject.StreetCode = 0
			|	AND AddressObject.AdditionalItemCode = 0
			|	AND AddressObject.SubordinateItemCode = 0
			|	AND AddressObject.Abbr = &Abbr";
		
		Query.SetParameter("RFTerritorialEntityCode", RFTerritorialEntityCode);
		Query.SetParameter("DistrictCode", DistrictCode);
		Query.SetParameter("Description", Region.Description);
		Query.SetParameter("Abbr", Region.Abbr);
		
		QueryResult = Query.Execute().Select();
		
		If QueryResult.Next() Then
			RegionCode = QueryResult.RegionCode;
			SettlementIdentifier =  QueryResult.IdentifierAddressObject;
		EndIf;
	EndIf;

	If ValueIsFilled(Address.City) Then
		City = AddressClassifierClientServer.DescriptionAndAbbreviation(Address.City);
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	AddressObject.ID AS IdentifierAddressObject,
			|	AddressObject.CityCode
			|FROM
			|	InformationRegister.AddressObjects AS AddressObject
			|WHERE
			|	AddressObject.Description = &Description
			|	AND AddressObject.Level = 4
			|	AND AddressObject.RFTerritorialEntityCode = &RFTerritorialEntityCode
			|	AND AddressObject.DistrictCode = &DistrictCode
			|	AND AddressObject.RegionCode = &RegionCode
			|	AND AddressObject.UrbanDistrictCode = 0
			|	AND AddressObject.SettlementCode = 0
			|	AND AddressObject.StreetCode = 0
			|	AND AddressObject.AdditionalItemCode = 0
			|	AND AddressObject.SubordinateItemCode = 0
			|	AND AddressObject.Abbr = &Abbr";
		
		Query.SetParameter("DistrictCode", DistrictCode);
		Query.SetParameter("RegionCode", RegionCode);
		Query.SetParameter("RFTerritorialEntityCode", RFTerritorialEntityCode);
		Query.SetParameter("Description", City.Description);
		Query.SetParameter("Abbr", City.Abbr);
		
		QueryResult = Query.Execute().Select();
		
		If QueryResult.Next() Then
			CityCode = QueryResult.CityCode;
			SettlementIdentifier =  QueryResult.IdentifierAddressObject;
		EndIf;
	EndIf;
	
	If ValueIsFilled(Address.UrbDistrict) Then
		UrbDistrict = AddressClassifierClientServer.DescriptionAndAbbreviation(Address.UrbDistrict);
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	AddressObject.ID AS IdentifierAddressObject,
			|	AddressObject.UrbanDistrictCode
			|FROM
			|	InformationRegister.AddressObjects AS AddressObject
			|WHERE
			|	AddressObject.Description = &Description
			|	AND AddressObject.Level = 5
			|	AND AddressObject.RFTerritorialEntityCode = &RFTerritorialEntityCode
			|	AND AddressObject.DistrictCode = &DistrictCode
			|	AND AddressObject.RegionCode = &RegionCode
			|	AND AddressObject.CityCode = &CityCode
			|	AND AddressObject.SettlementCode = 0
			|	AND AddressObject.StreetCode = 0
			|	AND AddressObject.AdditionalItemCode = 0
			|	AND AddressObject.SubordinateItemCode = 0
			|	AND AddressObject.Abbr = &Abbr";
			
		Query.SetParameter("RFTerritorialEntityCode", RFTerritorialEntityCode);
		Query.SetParameter("DistrictCode", DistrictCode);
		Query.SetParameter("RegionCode", RegionCode);
		Query.SetParameter("CityCode", CityCode);
		Query.SetParameter("Description", UrbDistrict.Description);
		Query.SetParameter("Abbr", UrbDistrict.Abbr);
		
		QueryResult = Query.Execute().Select();
		
		If QueryResult.Next() Then
			UrbanDistrictCode = QueryResult.UrbanDistrictCode;
			SettlementIdentifier =  QueryResult.IdentifierAddressObject;
		EndIf;
	EndIf;

	If ValueIsFilled(Address.Settlement) Then
		Settlement = AddressClassifierClientServer.DescriptionAndAbbreviation(Address.Settlement);
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	AddressObject.ID AS IdentifierAddressObject,
			|	AddressObject.SettlementCode
			|FROM
			|	InformationRegister.AddressObjects AS AddressObject
			|WHERE
			|	AddressObject.Description = &Description
			|	AND AddressObject.Level = 6
			|	AND AddressObject.RFTerritorialEntityCode = &RFTerritorialEntityCode
			|	AND AddressObject.DistrictCode = &DistrictCode
			|	AND AddressObject.RegionCode = &RegionCode
			|	AND AddressObject.CityCode = &CityCode
			|	AND AddressObject.UrbanDistrictCode = &UrbanDistrictCode
			|	AND AddressObject.StreetCode = 0
			|	AND AddressObject.AdditionalItemCode = 0
			|	AND AddressObject.SubordinateItemCode = 0
			|	AND AddressObject.Abbr = &Abbr";
		
		Query.SetParameter("RFTerritorialEntityCode", RFTerritorialEntityCode);
		Query.SetParameter("DistrictCode", DistrictCode);
		Query.SetParameter("RegionCode", RegionCode);
		Query.SetParameter("CityCode", CityCode);
		Query.SetParameter("UrbanDistrictCode", UrbanDistrictCode);
		Query.SetParameter("Description", Settlement.Description);
		Query.SetParameter("Abbr", Settlement.Abbr);
		QueryResult = Query.Execute().Select();
		
		If QueryResult.Next() Then
			SettlementCode = QueryResult.SettlementCode;
			SettlementIdentifier =  QueryResult.IdentifierAddressObject;
		EndIf;
	EndIf;
	
	// Street
	If ValueIsFilled(Address.Street) AND SearchByStreet Then
		Street = AddressClassifierClientServer.DescriptionAndAbbreviation(Address.Street);
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	AddressObject.ID AS IdentifierAddressObject,
			|	AddressObject.StreetCode
			|FROM
			|	InformationRegister.AddressObjects AS AddressObject
			|WHERE
			|	AddressObject.Description = &Description
			|	AND AddressObject.Level = 7
			|	AND AddressObject.RFTerritorialEntityCode = &RFTerritorialEntityCode
			|	AND AddressObject.DistrictCode = &DistrictCode
			|	AND AddressObject.RegionCode = &RegionCode
			|	AND AddressObject.CityCode = &CityCode
			|	AND AddressObject.UrbanDistrictCode = &UrbanDistrictCode
			|	AND AddressObject.SettlementCode = &SettlementCode
			|	AND AddressObject.AdditionalItemCode = 0
			|	AND AddressObject.SubordinateItemCode = 0
			|	AND AddressObject.Abbr = &Abbr";
		
		Query.SetParameter("RFTerritorialEntityCode", RFTerritorialEntityCode);
		Query.SetParameter("DistrictCode", DistrictCode);
		Query.SetParameter("RegionCode", RegionCode);
		Query.SetParameter("CityCode", CityCode);
		Query.SetParameter("UrbanDistrictCode", UrbanDistrictCode);
		Query.SetParameter("SettlementCode", SettlementCode);
		Query.SetParameter("Description", Street.Description);
		Query.SetParameter("Abbr", Street.Abbr);
		QueryResult = Query.Execute().Select();
		
		If QueryResult.Next() Then
			StreetCode = QueryResult.StreetCode;
			SettlementIdentifier =  QueryResult.IdentifierAddressObject;
		EndIf;
	EndIf;
	
	Return SettlementIdentifier;
	
EndFunction

// Defines the address index by the address parts.
//
Function AddressIndexByAddressParts(Address, ID = Undefined) Export
	
	IndexOf = 0;
	Source = AddressClassifierDataSource();
	If IsBlankString(Source) Then
		// Local
		
		If Not ValueIsFilled(ID) Then 
			ID = AddressObjectIdentifierByAddressParts(Address, True);
		EndIf;
		
		If ID <> Undefined Then
			Query = New Query;
			Query.Text = 
			"SELECT
			|	AddressObjects.PostalIndex
			|FROM
			|	InformationRegister.AddressObjects AS AddressObjects
			|WHERE
			|	AddressObjects.ID = &ID";
			
			Query.SetParameter("ID", ID);
			
			QueryResult = Query.Execute().Select();
			
			If QueryResult.Next() Then
				If QueryResult.PostalIndex = 0 Then
					
					// Decryption of the address properties
					Query = New Query(
					#Region QueryText
					"SELECT
					|	Value
					|FROM 
					|	InformationRegister.ServiceAddressData
					|WHERE	
					|	Type = ""TypeAdrEl"" AND Key = ""PostalIndex""
					|;//////////////////////////////////////////////////////////////////////////////////////////////////
					|SELECT
					|	Details.Key     AS Value,
					|	Details.Value AS TypeAdrEl,
					|	
					|	CASE 
					|		WHEN Not OwnershipTypes.ID IS NULL THEN OwnershipTypes.ID
					|		WHEN Not ConstructionTypes.ID IS NULL THEN ConstructionTypes.ID
					|		ELSE 0
					|	END AS ID
					|	
					|FROM
					|	InformationRegister.ServiceAddressData AS Details
					|	
					|LEFT JOIN
					|	InformationRegister.ServiceAddressData AS OwnershipTypes
					|ON
					|	OwnershipTypes.Type = ""ESTSTAT""
					|	AND OwnershipTypes.Value = Details.Key
					|	
					|LEFT JOIN
					|	InformationRegister.ServiceAddressData AS ConstructionTypes
					|ON
					|	ConstructionTypes.Type = ""STRSTAT""
					|	AND ConstructionTypes.Value = Details.Key
					|	
					|WHERE
					|	Details.Type = ""AdditAddrENumber""
					|"
					#EndRegion
					);
					ResultsSet = Query.ExecuteBatch();
					
					Table = ResultsSet[0].Unload();
					If Table.Count() = 0 Then
						TypeAddrElPostalCode = "";
					Else
						TypeAddrElPostalCode = Table[0].Value;
					EndIf;
					BuildingsAbbreviationsTable = ResultsSet[1].Unload();
					BuildingsAbbreviationsTable.Indexes.Add("TypeAdrEl");
					
					BuildingsAndFacilities = New Map;
					NumberType = New TypeDescription("Number");
					For Each AdditionalItem In Address.GetList("AddEMailAddress") Do
						AddressPointType = TrimAll(AdditionalItem.TypeAdrEl);
						
						// Building or unit, postal code?
						If AddressPointType = "" Then
							NumberValue = AdditionalItem.Number;
							RowBuildings = BuildingsAbbreviationsTable.Find(NumberValue.Type, "TypeAdrEl");
							If RowBuildings <> Undefined Then
								BuildingsAndFacilities[RowBuildings.Value] = New Structure("Kind, Value", RowBuildings.ID, NumberValue.Value);;
							EndIf;
							Continue;
						ElsIf AddressPointType = TypeAddrElPostalCode Then
							IndexOf = NumberType.AdjustValue(AdditionalItem.Value);
							Continue;
						EndIf;
					EndDo;
					
					Query = New Query;
					Query.Text ="SELECT
					|	HousesBuildingsConstructions.PostalIndex,
					|	HousesBuildingsConstructions.Buildings
					|FROM
					|	InformationRegister.HousesBuildingsConstructions AS HousesBuildingsConstructions
					|WHERE
					|	HousesBuildingsConstructions.AddressObject = &ID";
					Query.SetParameter("ID", ID);
					QueryResult = Query.Execute().Unload();
					
					For Each Record In QueryResult Do
						// If Record.Buildings equals to Null that means that there are no houses by this address.
						If ValueIsFilled(Record.Buildings) Then
							Definition = Record.Buildings.Get();
							
							If Not IsBlankString(Definition) Then
								IdentifierAdditionally = UUIDFromRow64(Left(Definition, 24));
								Definition = Mid(Definition, 25);
								If Not IsBlankString(Definition) Then
									HasHousesRecords = True;
									
									If BuildingsDescriptionFIASContainsData(Definition, BuildingsAndFacilities) Then
										IndexOf = Record.PostalIndex; 
									EndIf;
								EndIf;
							EndIf;
						EndIf;
					EndDo;
				Else
					IndexOf = QueryResult.PostalIndex;
				EndIf;
			EndIf;
		EndIf;
		
	ElsIf Source = "Service1C" Then
		// 1C web service, may be under maintenance.
		AddressForChecking = New Array;
		Result = New Structure("Data", New Array);
		VendorErrorDescriptionStructure(Result);
		Levels = AddressClassifierReUse.FIASClassifierLevels();
		AddressForChecking.Add(New Structure("Address, Levels", Address, Levels));
		Try
			FillAddressCheckResultByClassifier1CService(Result, AddressForChecking);
		Except
			VendorErrorDescriptionStructure(Result, ErrorInfo());
			WriteLogEvent( EventLogMonitorEvent(), EventLogLevel.Error, , , Result.DetailErrorDescription);
		EndTry;
		
		If Not Result.Cancel Then
			If Result.Data[0].Variants.Count() > 0 Then
				IndexOf = Result.Data[0].Variants[0].IndexOf;
			EndIf;
		EndIf;
	EndIf;
	
	If IndexOf = 0 Then
		Return Undefined;
	Else
		Return IndexOf;
	EndIf;
EndFunction

Procedure AddAddressCheckingErrorByClassifier(AllErrors, Key, Text, ToolTip = Undefined);
	
	Error = New Structure("Key, Text, ToolTip", Key, Text, ToolTip);
	AllErrors.Add(Error);
	
EndProcedure

Function AddressCheckingOptionalFieldsText(CheckingCheckBox, FieldName)
	
	If CheckingCheckBox Then
		Variant = "
			|	CASE WHEN [Field].ID IS NULL THEN FALSE ELSE TRUE END AS [Field]found,
			|	[Field].ID                 AS [Field]ID,
			|	[Field].PostalIndex                AS [Field]PostalIndex,
			|	[Field].ARCACode                      AS [Field]ARCACode,
			|	[Field].Additionally                 AS [Field]Additionally,
			|	[Field]Additionally.OKATO            AS [Field]OKATOAdditionally,
			|	[Field]Additionally.OKTMO            AS [Field]OKTMOAdditionally,
			|	[Field]Additionally.IFTSIndividualCode        AS [Field]AdditionallyCodeIFTSIndividual,
			|	[Field]Additionally.IFTSLegalEntityCode        AS [Field]AdditionallyCodeIFTSLegEnt,
			|	[Field]Additionally.IFTSIndividualDepartmentCode AS [Field]AdditionallyDepartmentCodeIFTSIndividual,
			|	[Field]Additionally.IFTSLegalEntityDepartmentCode AS [Field]AdditionallyDepartmentCodeIFTSLegalEntity,
			|";
	Else
		Variant = "
			|	NULL AS
			|	[Field]Found, NULL AS
			|	[Field]Identifier, NULL AS
			|	[Field]PostalCode, NULL AS
			|	[Field]KLADRCode, NULL AS
			|	[Field]Additionally, NULL AS
			|	[Field]AdditionallyOKATO, NULL AS
			|	[Field]AdditionallyOKTMO, NULL AS
			|	[Field]AdditionallyCodeIFTSIndividual, NULL AS
			|	[Field]AdditionallyCodeIFTSLegEnt, NULL AS
			|	[Field]AdditionallyDepartmentCodeIFTSIndividual, NULL AS [Field]AdditionallyDepartmentCodeIFTSLegEnt,
			|";
	EndIf;
		
	Return StrReplace(Variant, "[Field]", FieldName);
EndFunction

Function BuildingsDescriptionFIASContainsData(Definition, BuildingsAndFacilities)
	
	If BuildingsAndFacilities["House"] <> Undefined Then 
		HouseOrOwnershipNumberBuildings = Upper(TrimAll(BuildingsAndFacilities["House"].Value));
	Else 
		HouseOrOwnershipNumberBuildings = "";
	EndIf;
	
	If IsBlankString(HouseOrOwnershipNumberBuildings) AND BuildingsAndFacilities["Ownership"] <> Undefined Then
		HouseOrOwnershipNumberBuildings = Upper(TrimAll(BuildingsAndFacilities["Ownership"].Value));
	EndIf;
	If IsBlankString(HouseOrOwnershipNumberBuildings) AND BuildingsAndFacilities["Homeownership"] <> Undefined Then
		HouseOrOwnershipNumberBuildings = Upper(TrimAll(BuildingsAndFacilities["Homeownership"].Value));
	EndIf;
	
	If BuildingsAndFacilities["Block"] <> Undefined Then
		BuildingBlockNumber = Upper(TrimAll(BuildingsAndFacilities["Block"].Value));
	Else
		BuildingBlockNumber = "";
	EndIf;
	
	If BuildingsAndFacilities["Construction"] <> Undefined Then
		BuildingConstructionNumber = Upper(TrimAll(BuildingsAndFacilities["Construction"].Value));
	Else
		BuildingConstructionNumber = "";
	EndIf;
	
	If IsBlankString(BuildingConstructionNumber) AND BuildingsAndFacilities["Liter"] <> Undefined Then
		ConstructionHouseNumber = Upper(TrimAll(BuildingsAndFacilities["Liter"].Value));
	EndIf;
	
	If IsBlankString(BuildingConstructionNumber) AND BuildingsAndFacilities["Facility"] <> Undefined Then
		BuildingConstructionNumber = Upper(TrimAll(BuildingsAndFacilities["Facility"].Value));
	EndIf;
	
	If IsBlankString(BuildingConstructionNumber) AND BuildingsAndFacilities["Land"] <> Undefined Then
		BuildingConstructionNumber = Upper(TrimAll(BuildingsAndFacilities["Land"].Value));
	EndIf;
	
	DescriptionRows = StrReplace(Definition, Chars.LF, "");
	DescriptionRows = Upper(StrReplace(Definition, Chars.Tab, Chars.LF));
	
	NumberType = New TypeDescription("Number");
	Intervals = New Array;
	
	RowCount = StrLineCount(DescriptionRows);
	Position   = 1;
	
	While Position <= RowCount Do
		String = StrGetLine(DescriptionRows, Position);
		
		If String = "H" Then
			// Exact description - compare.
			OwnershipKind   = NumberType.AdjustValue(StrGetLine(DescriptionRows, Position + 1));
			OwnershipNumber = TrimAll( StrGetLine(DescriptionRows, Position + 2) );
			BlockNumber  = TrimAll( StrGetLine(DescriptionRows, Position + 3) );
			ConstructionKind   = NumberType.AdjustValue(StrGetLine(DescriptionRows, Position + 4));
			ConstructionNumber = TrimAll( StrGetLine(DescriptionRows, Position + 5) );
			
			If  OwnershipNumber = HouseOrOwnershipNumberBuildings
				AND BlockNumber  = BuildingBlockNumber
				AND ConstructionNumber = BuildingConstructionNumber
			Then
				// Exact hit
				Return True;
			EndIf;
			
			Position = Position + 5;
			
		ElsIf String = "I" Then
			// Type intervals for further check.
			Interval = New Structure;
			Interval.Insert("Kind",    NumberType.AdjustValue( StrGetLine(DescriptionRows, Position + 1) ));
			Interval.Insert("Begin", NumberType.AdjustValue( StrGetLine(DescriptionRows, Position + 2) ));
			Interval.Insert("End",  NumberType.AdjustValue( StrGetLine(DescriptionRows, Position + 3) ));
			Intervals.Add(Interval);
			
			Position = Position + 3;
		EndIf;
		
		Position = Position + 1;
	EndDo;
	
	// Continue to search in intervals - first letters.
	NumberDigit = "";
	For Position = 1 To StrLen(HouseOrOwnershipNumberBuildings) Do
		Char = Mid(HouseOrOwnershipNumberBuildings, Position, 1);
		If Find("0123456789", Char) = 0 Then
			Break;
		EndIf;
		NumberDigit = NumberDigit + Char;
	EndDo;
	
	NumberDigit = NumberType.AdjustValue(NumberDigit);
	NumberEven = NumberDigit % 2 = 0;
	
	For Each Interval In Intervals Do
		KindOfInterval = Interval.Type;
		
		If KindOfInterval = 2 Then
			If NumberEven Then
				// Even
				If  (Interval.Begin <= NumberDigit Or Interval.Begin = 0)
					AND (Interval.End >= NumberDigit Or Interval.End = 0)
				Then
					Return True;
				EndIf;
			EndIf;
			
		ElsIf KindOfInterval = 3 Then
			If Not NumberEven Then
				// Odd
				If  (Interval.Begin <= NumberDigit Or Interval.Begin = 0) 
					AND (Interval.End >= NumberDigit Or Interval.End = 0) 
				Then
					Return True;
				EndIf;
			EndIf;
			
		Else
			// Normal
			If  (Interval.Begin <= NumberDigit Or Interval.Begin = 0)
				AND (Interval.End >= NumberDigit Or Interval.End = 0)
			Then
				Return True;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

Procedure FillIdentifierByHierarchyFIAS(Variant, SourceRecord)
	
	SetFIASRecordAttributeHierarchically(Variant, "ID",  SourceRecord, "ID");

EndProcedure

Procedure FillPostalIndexAndKLADRCodeByFIASHierarchy(Variant, SourceRecord)
	
	SetFIASRecordAttributeHierarchically(Variant, "IndexOf",  SourceRecord, "PostalIndex");
	SetFIASRecordAttributeHierarchically(Variant, "ARCACode", SourceRecord, "ARCACode");

EndProcedure

Procedure FillAdditionalDataByFIASHierarchy(Variant, SourceRecord, ID)
	
	SetFIASRecordAttributeHierarchically(Variant, "OKATO",            SourceRecord, "OKATOAdditionally");
	SetFIASRecordAttributeHierarchically(Variant, "OKTMO",            SourceRecord, "OKTMOAdditionally");
	SetFIASRecordAttributeHierarchically(Variant, "IFTSIndividualCode",        SourceRecord, "AdditionallyCodeIFTSIndividual");
	SetFIASRecordAttributeHierarchically(Variant, "IFTSLegalEntityCode",        SourceRecord, "AdditionallyCodeIFTSLegEnt");
	SetFIASRecordAttributeHierarchically(Variant, "IFTSIndividualDepartmentCode", SourceRecord, "AdditionallyDepartmentCodeIFTSIndividual");
	SetFIASRecordAttributeHierarchically(Variant, "IFTSLegalEntityDepartmentCode", SourceRecord, "AdditionallyDepartmentCodeIFTSLegalEntity");

EndProcedure

Procedure SetFIASRecordAttributeHierarchically(Receiver, TargetFieldName, Source, SourceFieldName)
	
	Variants = New Array;
	If SourceFieldName <> "ID" Then
		Variants.Add("Houses");
	EndIf;
	Variants.Add("subordinated");
	Variants.Add("Additional");
	Variants.Add("Street");
	Variants.Add("Settlement");
	Variants.Add("UrbanDistrict");
	Variants.Add("City");
	Variants.Add("Region");
	Variants.Add("District");
	Variants.Add("RFTerritorialEntity");
	
	For Each VariantName In Variants Do
		Name = VariantName + SourceFieldName;
		If ValueIsFilled(Source[Name]) Then
			Receiver.Insert(TargetFieldName, Source[Name]);
			Return;
		EndIf;
	EndDo;
	
EndProcedure

Function BuildingDescriptionByFIASMatching(BuildingsAndFacilities)
	
	Result = "";
	
	For Each KeyValue In BuildingsAndFacilities Do
		Result = Result + ", " + KeyValue.Key + " " + KeyValue.Value.Value;
	EndDo;
	
	Return TrimAll(Mid(Result, 2));
EndFunction

// Deserializes an object from XML.
//
Function XDTOAddressDeserialization(String)
	XMLReader = New XMLReader;
	XMLReader.SetString(String);
	
	Type = XDTOFactory.Type(NamesSpaceRFAddress(), "AddressRF");
	Result = XDTOFactory.ReadXML(XMLReader);
	
	Return Result
EndFunction

// Space of names for XDTO operations with address.
//
Function NamesSpaceRFAddress()
	
	Return "http://www.v8.1c.ru/ssl/contactinfo";
	
EndFunction

// Sets in XDTO address a value according to XPath.
//
Procedure SetXDTOObjectAttribute(XDTODataObject, PathXPath, Value) Export
	
	If Not ValueIsFilled(Value) Then 
		Return;
	EndIf;
	
	// XPath parts
	PartsWays  = StrReplace(PathXPath, "/", Chars.LF);
	PathParts = StrLineCount(PartsWays);
	
	LeadingObject = XDTODataObject;
	Object        = XDTODataObject;
	
	For Position = 1 To PathParts Do
		PathPart = StrGetLine(PartsWays, Position);
		If PathParts = 1 Then
			Break;
		EndIf;
		
		Property = Object.Properties().Get(PathPart);
		If Not Object.IsSet(Property) Then
			Object.Set(Property, XDTOFactory.Create(Property.Type));
		EndIf;
		LeadingObject = Object;
		Object        = Object[PathPart];
	EndDo;
	
	If Object <> Undefined Then
		Object[PathPart] =  Value;
		
	ElsIf LeadingObject <> Undefined Then
		LeadingObject[PathPart] =  Value;
		
	EndIf;
	
EndProcedure

// Sets in XDTO address a value according to XPath.
//
Procedure AddXDTOListAttribute(XDTODataObject, ListPropertyName, AttributesValues, KeyName = "TypeAdrEl", AttributeName = "Value")
	
	If Not ValueIsFilled(AttributesValues[KeyName]) Then
		// No key
		Return;
	ElsIf Not ValueIsFilled(AttributesValues[AttributeName]) Then
		// No value
		Return;
	EndIf;
	
	Property = XDTODataObject.Properties().Get(ListPropertyName);
	ItemOfList = XDTODataObject.GetList(Property).Add( XDTOFactory.Create(Property.Type) );
	
	For Each KeyValue In AttributesValues Do
		ItemOfList[KeyValue.Key] = KeyValue.Value;
	EndDo;
EndProcedure

// Returns the value of an attribute from XDTO address by XPath.
//
Function GetXDTOObjectAttribute(XDTOObject, XPath) Export
	
	// Do not wait for line break to XPath.
	PropertiesString = StrReplace(StrReplace(XPath, "/", Chars.LF), Chars.LF + Chars.LF, "/");
	
	NumberOfProperties = StrLineCount(PropertiesString);
	If NumberOfProperties = 1 Then
		Return XDTOObject.Get(PropertiesString);
	EndIf;
	
	Result = ?(NumberOfProperties = 0, Undefined, XDTOObject);
	For IndexOf = 1 To NumberOfProperties Do
		Result = Result.Get(StrGetLine(PropertiesString, IndexOf));
		If Result = Undefined Then 
			Break;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Returns a row for searching in the LIKE operator.
//
Function DisguiseSimilarityESCAPEs(Text)
	Result = Text;
	
	ESCAPE = "\";
	Service  = "%_[]^" + ESCAPE;
	
	For IndexOf = 1 To StrLen(Service) Do
		Char = Mid(Service, IndexOf, 1);
		Result = StrReplace(Result, Char, ESCAPE + Char);
	EndDo;
	
	Return Result;
EndFunction

// Constructor of structure fields for description of errors.
//
Function VendorErrorDescriptionStructure(Definition = Undefined, ErrorInfo = Undefined)
	
	If Definition = Undefined Then
		Definition = New Structure;
	EndIf;
		
	Definition.Insert("Cancel", ErrorInfo <> Undefined);
	Definition.Insert("DetailErrorDescription");
	Definition.Insert("BriefErrorDescription");
	
	If ErrorInfo = Undefined Then
		Return Definition;
	EndIf;
	
	Definition.DetailErrorDescription = DetailErrorDescription(ErrorInfo);
	Text = BriefErrorDescription(ErrorInfo);
	
	If TypeOf(ErrorInfo.Cause) = Type("ErrorInfo") Then
		If ErrorInfo.Cause.Cause <> Undefined Then
			ErrorDescriptionForSearch = Upper(ErrorInfo.Cause.Cause.Definition);
			PositionStart = Find(ErrorDescriptionForSearch , "<FAULTSTRING>");
			If PositionStart > 0 Then
				PositionEnding = Find(ErrorDescriptionForSearch , "</FAULTSTRING>");
				Text = Mid(ErrorInfo.Cause.Cause.Definition, PositionStart + 13,
					PositionEnding - PositionStart - 13);
			EndIf;
		EndIf;
	EndIf;
	
	// Cut a client text
	Position = Find(Text, ": ");
	If Position > 0 Then
		Text = TrimL(Mid(Text, Position + 1));
	EndIf;
	
	// Cut server text
	While True Do
		Position = Find(Text, "}:");
		If Position = 0 Then
			Break;
		EndIf;
		Text = TrimL(Mid(Text, Position + 2));
	EndDo;
	
	Definition.BriefErrorDescription = Text;
	Return Definition;
EndFunction

Procedure ProcessAcceptedAbbreviation(AvailableLevels)

	Filter = New Structure("Level", 0);
	UnrecognizedRows = AvailableLevels.FindRows(Filter);
	For Each UnrecognizedAddressPart In UnrecognizedRows Do
		If (UPPER(UnrecognizedAddressPart.Description) = "MOSCOW" OR
			 UPPER(UnrecognizedAddressPart.Description) = "SAINT-PETERSBURG")
			 AND IsBlankString(UnrecognizedAddressPart.Abbr) Then
				UnrecognizedAddressPart.Abbr = "g";
				UnrecognizedAddressPart.Value = UnrecognizedAddressPart.Description + " " + UnrecognizedAddressPart.Abbr;
		EndIf;
		If UPPER(UnrecognizedAddressPart.Description) = "BUILD" Then
			UnrecognizedAddressPart.Description = "Block";
		EndIf;
		If UPPER(UnrecognizedAddressPart.Description) = "KV" Then
			UnrecognizedAddressPart.Description = "Apartment";
		EndIf;
		If UPPER(UnrecognizedAddressPart.Description) = "D" Then
			UnrecognizedAddressPart.Description = "House";
		EndIf;
		If UPPER(UnrecognizedAddressPart.Description) = "LITER" Then
			UnrecognizedAddressPart.Description = "Letter";
		EndIf;
	EndDo;
	
EndProcedure

Function LevelsContainingMatches(DataAnalysis, Levels)
	
	Query = New Query;
	Query.Text = "SELECT
	               |	DataAddresses.Description AS Description,
	               |	DataAddresses.Abbr AS Abbr
	               |INTO DataAddresses
	               |FROM
	               |	&DataAddresses AS DataAddresses
	               |
	               |INDEX BY
	               |	Description,
	               |	Abbr
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	CASE
	               |		WHEN Not AddressObjectsState.Level IS NULL 
	               |			THEN AddressObjectsState.Level
	               |		ELSE 0
	               |	END AS Level
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjectsState
	               |		ON (AddressObjectsState.Level In (&Levels))
	               |			AND DataAddresses.Description = AddressObjectsState.Description
	               |			AND DataAddresses.Abbr = AddressObjectsState.Abbr
	               |WHERE
	               |	CASE
	               |			WHEN Not AddressObjectsState.Level IS NULL 
	               |				THEN AddressObjectsState.Level
	               |			ELSE 0
	               |		END > 0
	               |
	               |GROUP BY
	               |	AddressObjectsState.Level
	               |
	               |ORDER BY
	               |	Level";
	
	Query.SetParameter("DataAddresses", DataAnalysis);
	Query.SetParameter("Levels", Levels);
	
	QueryResult = Query.Execute().Unload();
	AvailableLevels = QueryResult.UnloadColumn("Level");
	
	Return AvailableLevels;
EndFunction



Function SetAddressPartToTheirLevelMatch(PartsAddresses, Levels) Export
	
	ProcessAcceptedAbbreviation(PartsAddresses);
	AvailableLevels = LevelsContainingMatches(PartsAddresses, Levels);
	If AvailableLevels.Find(1) <> Undefined Then
		SetAddressLevelsByAddressParts(PartsAddresses, AvailableLevels);
	EndIf;
	
	Return PartsAddresses;
	
EndFunction

Procedure SetAddressLevelsByAddressParts(PartsAddresses, Levels) Export
	
	QueryText = "SELECT
	               |	DataAddresses.Level AS Level,
	               |	DataAddresses.Position AS Position,
	               |	DataAddresses.Value AS Value,
	               |	DataAddresses.Description AS Description,
	               |	DataAddresses.Abbr AS Abbr
	               |INTO DataAddresses
	               |FROM
	               |	&DataAddresses AS DataAddresses
	               |
	               |INDEX BY
	               |	Level,
	               |	Position,
	               |	Description,
	               |	Abbr
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode
	               |INTO RFTerritorialEntity
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 1)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	               |	AddressObjects.DistrictCode AS DistrictCode
	               |INTO District
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 2)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	               |	AddressObjects.DistrictCode AS DistrictCode,
	               |	AddressObjects.RegionCode AS RegionCode,
	               |	AddressObjects.CityCode AS CityCode
	               |INTO Region
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 3)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	               |	AddressObjects.DistrictCode AS DistrictCode,
	               |	AddressObjects.RegionCode AS RegionCode,
	               |	AddressObjects.CityCode AS CityCode
	               |INTO City
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 4)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	               |	AddressObjects.DistrictCode AS DistrictCode,
	               |	AddressObjects.RegionCode AS RegionCode,
	               |	AddressObjects.CityCode AS CityCode,
	               |	AddressObjects.UrbanDistrictCode,
	               |	AddressObjects.SettlementCode
	               |INTO UrbanDistrict
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 5)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	               |	AddressObjects.DistrictCode AS DistrictCode,
	               |	AddressObjects.RegionCode AS RegionCode,
	               |	AddressObjects.CityCode AS CityCode,
	               |	AddressObjects.UrbanDistrictCode,
	               |	AddressObjects.SettlementCode
	               |INTO Settlement
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 6)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	               |	AddressObjects.DistrictCode AS DistrictCode,
	               |	AddressObjects.RegionCode AS RegionCode,
	               |	AddressObjects.CityCode AS CityCode,
	               |	AddressObjects.UrbanDistrictCode,
	               |	AddressObjects.SettlementCode,
	               |	AddressObjects.StreetCode
	               |INTO Streets
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 7)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	               |	AddressObjects.DistrictCode AS DistrictCode,
	               |	AddressObjects.RegionCode AS RegionCode,
	               |	AddressObjects.CityCode AS CityCode,
	               |	AddressObjects.UrbanDistrictCode,
	               |	AddressObjects.SettlementCode,
	               |	AddressObjects.StreetCode,
	               |	AddressObjects.AdditionalItemCode
	               |INTO AdditionalTerritory
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 90)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	               |	AddressObjects.DistrictCode AS DistrictCode,
	               |	AddressObjects.RegionCode AS RegionCode,
	               |	AddressObjects.CityCode AS CityCode,
	               |	AddressObjects.UrbanDistrictCode,
	               |	AddressObjects.SettlementCode,
	               |	AddressObjects.StreetCode,
	               |	AddressObjects.AdditionalItemCode,
	               |	AddressObjects.SubordinateItemCode
	               |INTO AdditionalTerritoryItem
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 91)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL ;";
	
	DistrictCode = "0";
	RegionCode = "0";
	CityCode = "0";
	UrbanDistrictCode = "0";
	SettlementCode = "0";
	StreetCode = "0";
	AdditionalTerritoryCode = "0";
	ConnectionText = "";
	SelectionQueryText = "";
	FieldList = New Map();
	For Each Level In Levels Do
		If Level = 1 Then
			FieldList.Insert("RFTerritorialEntity", "RFTerritorialEntityCode");
			ConnectionText = " RFTerritorialEntity AS RFTerritorialEntity ";
		ElsIf Level = 2 Then
			FieldList.Insert("District", "DistrictCode");
			ConnectionText = ConnectionText + " LEFT JOIN District AS
				| District BY RFTerritorialEntity.RFTerritorialEntityCode AND District.RFTerritorialEntityCode =";
			DistrictCode = "District.DistrictCode";
		ElsIf Level = 3 Then
			FieldList.Insert("Region", "RegionCode");
			ConnectionText = ConnectionText + " LEFT JOIN Region AS
				| Region BY Region.RFTerritorialEntityCode =
				| RFTerritorialEntity.RFTerritorialEntityCode AND Region.DistrictCode = " + DistrictCode;
				RegionCode = "Region.RegionCode";
		ElsIf Level = 4 Then
			FieldList.Insert("City", "CityCode");
			ConnectionText = ConnectionText + " LEFT JOIN City AS
				| City BY City.RFTerritorialEntityCode =
				| RFTerritorialEntity.RFTerritorialEntityCode AND City.DistrictCode = " + DistrictCode + "
				| AND  City.RegionCode = " + RegionCode;
				CityCode = "City.CityCode";
		ElsIf Level = 5 Then
				FieldList.Insert("UrbanDistrict", "UrbanDistrictCode");
				ConnectionText = ConnectionText + " LEFT JOIN UrbanDistrict AS
					| UrbanDistrict BY UrbanDistrict.RFTerritorialEntityCode =
					| RFTerritorialEntity.RFTerritorialEntityCode AND UrbanDistrict.DistrictCode = " + DistrictCode + "
					| AND  UrbanDistrict.RegionCode = " + RegionCode + "
					| AND  UrbanDistrict.CityCode = " + CityCode;
				UrbanDistrictCode = "UrbanDistrict.UrbanDistrictCode";
		ElsIf Level = 6 Then
				FieldList.Insert("Settlement", "SettlementCode");
				ConnectionText = ConnectionText + " LEFT JOIN Settlement AS
					| Settlement BY Settlement.RFTerritorialEntityCode =
					| RFTerritorialEntity.RFTerritorialEntityCode AND Settlement.DistrictCode = " + DistrictCode + "
					| AND  Settlement.RegionCode = " + RegionCode + "
					| AND  Settlement.CityCode = " + CityCode + "
					| AND  Settlement.UrbanDistrictCode = " + UrbanDistrictCode;
				SettlementCode = "Settlement.SettlementCode";
		ElsIf Level = 7 Then
				FieldList.Insert("Streets", "StreetCode");
				ConnectionText = ConnectionText + " LEFT JOIN Streets AS
					| Streets BY Streets.RFTerritorialEntityCode =
					| RFTerritorialEntity.RFTerritorialEntityCode AND Streets.DistrictCode = " + DistrictCode + "
					| AND  Streets.RegionCode = " + RegionCode + "
					| AND  Streets.CityCode = " + CityCode + "
					| AND  Streets.UrbanDistrictCode = " + UrbanDistrictCode + "
					| AND  Streets.SettlementCode = " + SettlementCode;
				StreetCode = "Streets.StreetCode";
		EndIf;
	EndDo;
	
	Delimiter = "";
	For Each Item In FieldList Do
		SelectionQueryText = SelectionQueryText + Delimiter + " " + Item.Key +"Name + "" "" + 
		| " + Item.Key + ".Abbreviation AS "+ Item.Key + ", " + Item.Key +".Level AS " + Item.Key + "Level, " + 
		 Item.Key + "." + Item.Value + " AS " + Item.Value;
		Delimiter = ", ";
	EndDo;

	Delimiter = "";
	ConditionWhereForAdditionalTerritories = "";
	If Not IsBlankString(SelectionQueryText) Then
		
		SelectionQueryText = "SELECT " + SelectionQueryText + " IN " + ConnectionText;
		QueryText = QueryText + SelectionQueryText;
		Query = New Query(QueryText);
		
		Query.SetParameter("DataAddresses", PartsAddresses);
		
		Result = Query.Execute().Select();
		If Result.Next() Then
			For Each Item In FieldList Do
				AddressString = PartsAddresses.Find(Result[Item.Key], "Value");
				If AddressString <> Undefined Then 
					AddressString.Level = Result[Item.Key + "Level"];
					ConditionWhereForAdditionalTerritories = ConditionWhereForAdditionalTerritories + Delimiter + 
						"AddressObjects." + FieldList.Get(Item.Key) + " = " + Format(Result[Item.Value], "NGS=; NG=0");
				Else
					ConditionWhereForAdditionalTerritories = ConditionWhereForAdditionalTerritories + Delimiter + 
						"AddressObjects." + FieldList.Get(Item.Key) + " = 0";
				EndIf;
				Delimiter = " AND ";
			EndDo;
		EndIf;
	EndIf;
	
	Query = New Query;
	Query.Text =  "SELECT
	                |	DataAddresses.Level AS Level,
	                |	DataAddresses.Position AS Position,
	                |	DataAddresses.Value AS Value,
	                |	DataAddresses.Description AS Description,
	                |	DataAddresses.Abbr AS Abbr
	                |INTO DataAddresses
	                |FROM
	                |	&DataAddresses AS DataAddresses
	                |WHERE
	                |	DataAddresses.Level = 0
	                |
	                |INDEX BY
	                |	Level,
	                |	Position,
	                |	Description,
	                |	Abbr
	                |;
	                |
	                |////////////////////////////////////////////////////////////////////////////////
	                |SELECT
	                |	AddressObjects.ID AS ID,
	                |	AddressObjects.Description AS Description,
	                |	AddressObjects.Abbr AS Abbr,
	                |	AddressObjects.Level AS Level,
	                |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	                |	AddressObjects.DistrictCode AS DistrictCode,
	                |	AddressObjects.RegionCode AS RegionCode,
	                |	AddressObjects.CityCode AS CityCode,
	                |	AddressObjects.UrbanDistrictCode,
	                |	AddressObjects.SettlementCode,
	                |	AddressObjects.StreetCode,
	                |	AddressObjects.AdditionalItemCode
	                |INTO AdditionalTerritory
	                |FROM
	                |	DataAddresses AS DataAddresses
	                |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	                |		ON (AddressObjects.Level = 90)
	                |			AND DataAddresses.Description = AddressObjects.Description
	                |			AND DataAddresses.Abbr = AddressObjects.Abbr
	                |WHERE
	                |	Not AddressObjects.ID IS NULL AND " + ConditionWhereForAdditionalTerritories + "
	                |;
	                |
	                |////////////////////////////////////////////////////////////////////////////////
	                |SELECT
	                |	AddressObjects.ID AS ID,
	                |	AddressObjects.Description AS Description,
	                |	AddressObjects.Abbr AS Abbr,
	                |	AddressObjects.Level AS Level,
	                |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	                |	AddressObjects.DistrictCode AS DistrictCode,
	                |	AddressObjects.RegionCode AS RegionCode,
	                |	AddressObjects.CityCode AS CityCode,
	                |	AddressObjects.UrbanDistrictCode,
	                |	AddressObjects.SettlementCode,
	                |	AddressObjects.StreetCode,
	                |	AddressObjects.AdditionalItemCode,
	                |	AddressObjects.SubordinateItemCode
	                |INTO AdditionalTerritoryItem
	                |FROM
	                |	DataAddresses AS DataAddresses
	                |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	                |		ON (AddressObjects.Level = 91)
	                |			AND DataAddresses.Description = AddressObjects.Description
	                |			AND DataAddresses.Abbr = AddressObjects.Abbr
	                |WHERE
	                |	Not AddressObjects.ID IS NULL AND " + ConditionWhereForAdditionalTerritories + "
	                |;
	                |
	                |////////////////////////////////////////////////////////////////////////////////
	                |SELECT
	                |	AddressObjects.Description + "" "" + AddressObjects.Abbr AS AdditionalTerritory,
	                |	AddressObjects.Level AS AdditionalTerritoryLevel,
	                |	AdditionalTerritoryItem.Description + "" "" + AdditionalTerritoryItem.Abbr AS AdditionalTerritoryItem,
	                |	AdditionalTerritoryItem.Level AS AdditionalTerritoryItemLevel
	                |FROM
	                |	AdditionalTerritory AS AddressObjects
	                |		LEFT JOIN AdditionalTerritoryItem AS AdditionalTerritoryItem
	                |		ON AddressObjects.AdditionalItemCode = AdditionalTerritoryItem.AdditionalItemCode
	                |WHERE " + ConditionWhereForAdditionalTerritories;
	
	Query.SetParameter("DataAddresses", PartsAddresses);
	SelectionDetailRecords = Query.Execute().Select();
	
	If SelectionDetailRecords.Next() Then
		
		If ValueIsFilled(SelectionDetailRecords.AdditionalTerritory) Then
			AddressString = PartsAddresses.Find(SelectionDetailRecords.AdditionalTerritory, "Value");
			If AddressString <> Undefined Then 
				AddressString.Level = SelectionDetailRecords.AdditionalTerritoryLevel;
			EndIf;
		EndIf;
		If ValueIsFilled(SelectionDetailRecords.AdditionalTerritoryItem) Then
			AddressString = PartsAddresses.Find(SelectionDetailRecords.AdditionalTerritoryItem, "Value");
			If AddressString <> Undefined Then 
				AddressString.Level = SelectionDetailRecords.AdditionalTerritoryItemLevel;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure SetStreetLevelsByAddressParts(SettlementIdentifier, PartsAddresses) Export
	
	Pattern = " LEFT JOIN InformationRegister.AddressObjects AS %1
					|		ON (%1.RFTerritorialEntityCode = Settlement.RFTerritorialEntityCode)
					|			AND (%1.DistrictCode = Settlement.DistrictCode)
					|			AND (%1.RegionCode = Settlement.RegionCode)
					|			AND (%1.CityCode = Settlement.CityCode)
					|			AND (%1.UrbanDistrictCode = Settlement.UrbanDistrictCode)
					|			AND (%1.SettlementCode = Settlement.SettlementCode)
					|			AND (%1.Description = ""%2"")
					|			AND (%1.Abbr = ""%3"") ";
	RowSelect = "";
	SeparatorSelect = "";
	RowFrom = "";
	
	For IndexOf = 0 To PartsAddresses.Count() -1 Do
		PartAddresses = PartsAddresses[IndexOf];
		NameTables = "AddressObject"+ String(IndexOf);
		RowSelect = RowSelect + SeparatorSelect + NameTables + ".ID AS " + NameTables + "ID, " + 
							NameTables + ".Level AS " + NameTables + "Level " ;
		RowFrom = RowFrom + StringFunctionsClientServer.SubstituteParametersInString(Pattern, NameTables, PartAddresses.Description, PartAddresses.Abbr);
		SeparatorSelect = ", ";
	EndDo;
	
	
	QueryText = "SELECT " + RowSelect + " FROM InformationRegister.AddressObjects AS Settlement " + 
						RowFrom + " WHERE Settlement.ID = &Identifier";

	Query = New Query(QueryText);
	Query.SetParameter("Identifier", SettlementIdentifier);
		
	Result = Query.Execute().Select();
	If Result.Next() Then
		For IndexOf = 0 To PartsAddresses.Count() - 1 Do
			PartsAddresses[IndexOf].ID = Result["AddressObject"+ String(IndexOf) + "ID"];
			PartsAddresses[IndexOf].Level = Result["AddressObject"+ String(IndexOf) + "Level"];
		EndDo;
	EndIf;
	PartsAddresses.Sort("Level");
	
EndProcedure

// Recognize a settlement by parts of address.
//
Function SetMatchAddressPartsToTheirLevelForLocality(PartsAddresses, Levels) Export
	
	ProcessAcceptedAbbreviation(PartsAddresses);
	AvailableLevels = LevelsContainingMatches(PartsAddresses, Levels);
	If AvailableLevels.Find(1) <> Undefined Then
		SetAddressLevelsByAddressPartsForSettlement(AvailableLevels, PartsAddresses);
	EndIf;
	
	Return PartsAddresses;
	
EndFunction

// Set a match of a settlement by the parts of address.
//
Procedure SetAddressLevelsByAddressPartsForSettlement(Levels, PartsAddresses) Export
	
	QueryText = "SELECT
	               |	DataAddresses.Level AS Level,
	               |	DataAddresses.Position AS Position,
	               |	DataAddresses.Value AS Value,
	               |	DataAddresses.Description AS Description,
	               |	DataAddresses.Abbr AS Abbr
	               |INTO DataAddresses
	               |FROM
	               |	&DataAddresses AS DataAddresses
	               |
	               |INDEX BY
	               |	Level,
	               |	Position,
	               |	Description,
	               |	Abbr
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode
	               |INTO RFTerritorialEntity
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 1)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	               |	AddressObjects.DistrictCode AS DistrictCode
	               |INTO District
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 2)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	               |	AddressObjects.DistrictCode AS DistrictCode,
	               |	AddressObjects.RegionCode AS RegionCode,
	               |	AddressObjects.CityCode AS CityCode
	               |INTO Region
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 3)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	               |	AddressObjects.DistrictCode AS DistrictCode,
	               |	AddressObjects.RegionCode AS RegionCode,
	               |	AddressObjects.CityCode AS CityCode
	               |INTO City
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 4)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	               |	AddressObjects.DistrictCode AS DistrictCode,
	               |	AddressObjects.RegionCode AS RegionCode,
	               |	AddressObjects.CityCode AS CityCode,
	               |	AddressObjects.UrbanDistrictCode,
	               |	AddressObjects.SettlementCode
	               |INTO UrbanDistrict
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 5)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	AddressObjects.ID AS ID,
	               |	AddressObjects.Description AS Description,
	               |	AddressObjects.Abbr AS Abbr,
	               |	AddressObjects.Level AS Level,
	               |	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	               |	AddressObjects.DistrictCode AS DistrictCode,
	               |	AddressObjects.RegionCode AS RegionCode,
	               |	AddressObjects.CityCode AS CityCode,
	               |	AddressObjects.UrbanDistrictCode,
	               |	AddressObjects.SettlementCode
	               |INTO Settlement
	               |FROM
	               |	DataAddresses AS DataAddresses
	               |		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	               |		ON (AddressObjects.Level = 6)
	               |			AND DataAddresses.Description = AddressObjects.Description
	               |			AND DataAddresses.Abbr = AddressObjects.Abbr
	               |WHERE
	               |	Not AddressObjects.ID IS NULL ;";
	
	DistrictCode = "0";
	RegionCode = "0";
	CityCode = "0";
	UrbanDistrictCode = "0";
	SettlementCode = "0";
	StreetCode = "0";
	AdditionalTerritoryCode = "0";
	ConnectionText = "";
	SelectionQueryText = "";
	FieldList = New Structure();
	For Each Level In Levels Do
		If Level = 1 Then
			FieldList.Insert("RFTerritorialEntity");
			ConnectionText = ConnectionText + " RFTerritorialEntity AS RFTerritorialEntity ";
		ElsIf Level = 2 Then
			FieldList.Insert("District");
			ConnectionText = ConnectionText + " LEFT JOIN District AS
				| District BY RFTerritorialEntity.RFTerritorialEntityCode AND District.RFTerritorialEntityCode =";
			DistrictCode = "District.DistrictCode";
		ElsIf Level = 3 Then
			FieldList.Insert("Region");
			ConnectionText = ConnectionText + " LEFT JOIN Region AS
				| Region BY Region.RFTerritorialEntityCode =
				| RFTerritorialEntity.RFTerritorialEntityCode AND Region.DistrictCode = " + DistrictCode;
				RegionCode = "Region.RegionCode";
		ElsIf Level = 4 Then
			FieldList.Insert("City");
			ConnectionText = ConnectionText + " LEFT JOIN City AS
				| City BY City.RFTerritorialEntityCode =
				| RFTerritorialEntity.RFTerritorialEntityCode AND City.DistrictCode = " + DistrictCode + "
				| AND  City.RegionCode = " + RegionCode;
				CityCode = "City.CityCode";
		ElsIf Level = 5 Then
				FieldList.Insert("UrbanDistrict");
				ConnectionText = ConnectionText + " LEFT JOIN UrbanDistrict AS
					| UrbanDistrict BY UrbanDistrict.RFTerritorialEntityCode =
					| RFTerritorialEntity.RFTerritorialEntityCode AND UrbanDistrict.DistrictCode = " + DistrictCode + "
					| AND  UrbanDistrict.RegionCode = " + RegionCode + "
					| AND  UrbanDistrict.CityCode = " + CityCode;
				UrbanDistrictCode = "UrbanDistrict.UrbanDistrictCode";
		ElsIf Level = 6 Then
				FieldList.Insert("Settlement");
				ConnectionText = ConnectionText + " LEFT JOIN Settlement AS
					| Settlement BY Settlement.RFTerritorialEntityCode =
					| RFTerritorialEntity.RFTerritorialEntityCode AND Settlement.DistrictCode = " + DistrictCode + "
					| AND  Settlement.RegionCode = " + RegionCode + "
					| AND  Settlement.CityCode = " + CityCode + "
					| AND  Settlement.UrbanDistrictCode = " + UrbanDistrictCode;
				SettlementCode = "Settlement.SettlementCode";
		EndIf;
	EndDo;
	
	Delimiter = "";
	For Each Item In FieldList Do
		SelectionQueryText = SelectionQueryText + Delimiter + " " + Item.Key +"Name + "" "" + 
		| " + Item.Key + ".Abbreviation AS "+ Item.Key + ", " + Item.Key +".Level AS " + Item.Key + "Level";
		Delimiter = ", ";
	EndDo;
	
	If Not IsBlankString(SelectionQueryText) Then
		
		SelectionQueryText = "SELECT " + SelectionQueryText + " IN " + ConnectionText;
		QueryText = QueryText + SelectionQueryText;
		Query = New Query(QueryText);
		
		Query.SetParameter("DataAddresses", PartsAddresses);
		
		Result = Query.Execute().Select();
		If Result.Next() Then
			For Each Item In FieldList Do
				AddressString = PartsAddresses.Find(Result[Item.Key], "Value");
				If AddressString <> Undefined Then 
					AddressString.Level = Result[Item.Key + "Level"];
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure


// Defines a street and an additional territory, function is used for matching the data transferred from KLADR.
//
// Parameters:
//  DescriptionAndAbbreviation	 - Structure - Name and Abbreviation of the search object.
//  ID			 - UUID - Identifier settlement.
// Returns:
//  Structure -  Result of the search.
Function StreetAndAdditionalTerritory(Val DescriptionAndAbbreviation, Val ID) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AddressObjects.Level AS Level,
	|	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
	|	AddressObjects.DistrictCode AS DistrictCode,
	|	AddressObjects.RegionCode AS RegionCode,
	|	AddressObjects.CityCode AS CityCode,
	|	AddressObjects.UrbanDistrictCode AS UrbanDistrictCode,
	|	AddressObjects.SettlementCode AS SettlementCode,
	|	AddressObjects.StreetCode AS StreetCode,
	|	AddressObjects.AdditionalItemCode AS AdditionalItemCode,
	|	AddressObjects.SubordinateItemCode AS SubordinateItemCode,
	|	AddressObjects.ID AS ID,
	|	AddressObjects.PostalIndex AS PostalIndex,
	|	AddressObjects.Description AS Description,
	|	AddressObjects.Abbr AS Abbr
	|INTO Parent
	|FROM
	|	InformationRegister.AddressObjects AS AddressObjects
	|WHERE
	|	AddressObjects.ID = &ID
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT 
	|	AddressObjects.ID AS ID,
	|	AddressObjects.PostalIndex AS PostalIndex,
	|	AddressObjects.Description AS Description,
	|	AddressObjects.Abbr AS Abbr,
	|	StreetAddressObjects.Description AS StreetName,
	|	StreetAddressObjects.Abbr AS StreetAbbreviation,
	|	StreetAddressObjects.ID AS StreetIdentifier
	|FROM
	|	Parent AS Parent
	|		LEFT JOIN InformationRegister.AddressObjects AS StreetAddressObjects
	|		ON (StreetAddressObjects.Level = 7)
	|			AND (Parent.StreetCode = 0)
	|			AND Parent.RFTerritorialEntityCode = StreetAddressObjects.RFTerritorialEntityCode
	|			AND Parent.DistrictCode = StreetAddressObjects.DistrictCode
	|			AND Parent.RegionCode = StreetAddressObjects.RegionCode
	|			AND Parent.CityCode = StreetAddressObjects.CityCode
	|			AND Parent.UrbanDistrictCode = StreetAddressObjects.UrbanDistrictCode
	|			AND Parent.SettlementCode = StreetAddressObjects.SettlementCode
	|		LEFT JOIN InformationRegister.AddressObjects AS AddressObjects
	|		ON (AddressObjects.Level = 90)
	|			AND (StreetAddressObjects.DistrictCode = AddressObjects.DistrictCode)
	|			AND (StreetAddressObjects.RegionCode = AddressObjects.RegionCode)
	|			AND (StreetAddressObjects.CityCode = AddressObjects.CityCode)
	|			AND (StreetAddressObjects.UrbanDistrictCode = AddressObjects.UrbanDistrictCode)
	|			AND (StreetAddressObjects.SettlementCode = AddressObjects.SettlementCode)
	|			AND (StreetAddressObjects.StreetCode = AddressObjects.StreetCode)
	|			AND Parent.RFTerritorialEntityCode = AddressObjects.RFTerritorialEntityCode
	|WHERE
	|	AddressObjects.Description = &Description
	|	AND AddressObjects.Abbr = &Abbr";
	
	Query.SetParameter("ID", ID);
	Query.SetParameter("Description", DescriptionAndAbbreviation.Description);
	Query.SetParameter("Abbr", DescriptionAndAbbreviation.Abbr);
	
	QueryResult = Query.Execute().Select();
	
	FoundVariant = New Structure("StreetIdentifier, Identifier, Value");
	If QueryResult.Next() Then
			FoundVariant.StreetIdentifier = QueryResult.StreetIdentifier;
			FoundVariant.ID = QueryResult.ID;
			FoundVariant.Value = QueryResult.Description + " " + QueryResult.Abbr;
		Return FoundVariant;
	EndIf;
	
	Return Undefined;
	
EndFunction

#EndRegion

#Region ServiceProgramInterfaceBackgroundOperationsWithClassifier

// Handler of the background import.
//
Procedure AddressesClassifierImportBackgroundJob(Parameters, ResultAddress) Export
	
	ImportAddressClassifier(Parameters[0], Parameters[1]);
	
EndProcedure

// Handler of the background import from website.
//
Procedure BackgroundJobClassifierAddressesImportingsFromSite(Parameters, ResultAddress) Export
	
	ImportAddressClassifierFromSite(Parameters[0], Parameters[1]);
	
EndProcedure

// Handler of the background clearance
//
Procedure BackgroundJobAddressesClassifierClear(Parameters, ResultAddress) Export
	
	ClearAddressesClassifier(Parameters[0]);
	
EndProcedure

#EndRegion

#Region ServiceProgramInterfaceEventsHandlers

// See details of the same procedure in the StandardSubsystemsServer module.
//
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
		"AddressClassifierService");
		
	// RefreshEnabled
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"AddressClassifierService");
		
	// Security profiles
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources"].Add(
		"AddressClassifierService");
	
	// To-do list
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ServerHandlers["StandardSubsystems.CurrentWorks\AtFillingToDoList"].Add(
			"AddressClassifierService");
	EndIf;
		
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystems(Parameters) Export
	
	Parameters.Insert("AddressClassifierOutdated", OutdatedClassifierContainsInformation());
	
EndProcedure

// Fills out a list of queries for external permissions
// that must be provided when creating an infobase or updating a application.
//
// Parameters:
//  PermissionsQueries - Array - list of values returned by the function.
//                      WorkInSafeMode.QueryOnExternalResourcesUse().
//
Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	// Permission to check an update.
	VersionsFileAddress = CommonUseClientServer.URLStructure(
		FileURLAvailableVersionsDescription()
	);
	
	Protocol = Upper(VersionsFileAddress.Schema);
	Address    = VersionsFileAddress.Host;
	Port     = VersionsFileAddress.Port;
	Definition = NStr("en='Import the update of the address classifier.';ru='Загрузка обновлений адресного классификатора.'");
	
	permissions = New Array;
	permissions.Add( 
		WorkInSafeMode.PermissionForWebsiteUse(Protocol, Address, Port, Definition)
	);
	
	PermissionOwner = CommonUse.MetadataObjectID("InformationRegister.AddressObjects"); 
	
	PermissionsQuery = WorkInSafeMode.QueryOnExternalResourcesUse(permissions, PermissionOwner, True);
	
	PermissionsQueries.Add(PermissionsQuery);
	
EndProcedure

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//    Handlers - ValueTable - see NewUpdateHandlersTable function
// description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	// Fill in initial data.
	Handler = Handlers.Add();
	Handler.Version = "2.2.4.23";
	Handler.Procedure = "AddressClassifierService.ExecuteInitialFilling";
	Handler.InitialFilling = True;
	Handler.SharedData = True;
	Handler.PerformModes = "Exclusive";
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//     CurrentWorks - ValueTable - works description - a table of values with the following columns:
//         * Identifier - String    - To-do internal identifier used by the To-do lists mechanism.
//         * ThereIsWork      - Boolean    - If True, then to-do is output in the current works list of a user.
//         * Important        - Boolean    - If True, to-do will be highlighted in red.
//         * Presentation - String    - Presentation of a to-do output to a user.
//         * Count    - Number     - quantitative indicator of a to-do, it is dislayed in the row of a to-do header.
//         * Form         - String    - Full path to the form that needs to be
//                                       opened during clicking the hyperlink of to-do on the To-do lists panel.
//         * FormParameters- Structure - Parameters that should be opened with an indicator form.
//         * Owner      - String, MetadataObject - Row identifier of a to-do that
//                           will be an owner of the current to-do or an object of subsystem metadata.
//         * Tooltip     - String    - ToolTip text.
//
Procedure AtFillingToDoList(CurrentWorks) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return; // Service model.
	EndIf;
	
	If Not AccessRight("Update", Metadata.InformationRegisters.AddressObjects) Then
		Return; // No rights.
	EndIf;
	ModuleCurrentWorksServer = CommonUse.CommonModule("CurrentWorksServer");
	
	Sections = ModuleCurrentWorksServer.SectionsForObject("InformationRegister.AddressObjects");
	If Sections = Undefined Then
		// They were not entered to the command interface.
		SectionAdministration = Metadata.Subsystems.Find("Administration");
		If SectionAdministration = Undefined Then
			Return;	
		EndIf;
		Sections = New Array;
		Sections.Add(SectionAdministration);
	EndIf;
	
	// 1. It is required to actualize address classifier - there are no records about states in an old classifier.
	States = ObsoleteClassifierFilledStates();
	If States.Count() > 0 Then

		For Each Section In Sections Do
			Work = CurrentWorks.Add();
			Work.ID  = "ActualizeAddressClassifier";
			Work.ThereIsWork       = True;
			Work.Important         = True;
			Work.Owner       = Section;
			Work.Presentation  = NStr("en='Address classifier is outdated';ru='Адресный классификатор устарел'");
			Work.Quantity     = 0;
			Work.ToolTip      = NStr("en='Auto pick and correctness check are temporarily unavailable.';ru='Автоподбор и проверка корректности адресов временно недоступны.'");
			Work.FormParameters = New Structure;
			Work.Form          = "InformationRegister.AddressObjects.Form.UpdateOutdatedClassifier";
		EndDo;
		
		Return;
		
	EndIf;
	
	If CommonUseClientServer.ThisIsWebClient() Then
		Return; // Web client does not support work with an address classifier.
	EndIf;
	
	// 2. Need for update - always output.
	LastUpdate = LastImportDescription();
	ToolTip           = LastUpdate.Presentation;
	If LastUpdate.UpdateRequired Then
		ToolTip = ToolTip + Chars.LF + NStr("en='You need to check if there are any updates.';ru='Необходимо проверить наличие обновлений.'");
	
		For Each Section In Sections Do
			Work = CurrentWorks.Add();
			Work.ID  = "UpdateAddressClassifier";
			Work.ThereIsWork       = True;
			Work.Important         = LastUpdate.UpdateRequired;
			Work.Owner       = Section;
			Work.Presentation  = NStr("en='Address classifier is outdated';ru='Адресный классификатор устарел'");
			Work.Quantity     = 0;
			Work.ToolTip      = ToolTip;
			Work.FormParameters = New Structure("Mode", "CheckUpdate");
			Work.Form          = "InformationRegister.AddressObjects.Form.AddressClassifierExport";
		EndDo;
	EndIf;
	
EndProcedure

// Initial data filling of an address classifier during the first launch.
//
Procedure ExecuteInitialFilling() Export
	
	InformationRegisters.AddressObjects.UpdateRFTerritorialEntitiesContentByClassifier(True);

EndProcedure

#EndRegion

#Region TransformFIASDataTypes

// Converts UUID to BinaryData.
//
// Parameters:
//     ID - UUID, Row - source data.
//
// Returns:
//     BinaryData - conversion result
//
Function UUIDToBinaryData(ID) 
	
	XDTOTypeBinaryData = XDTOFactory.Type("http://www.w3.org/2001/XMLSchema", "hexBinary");
	HEXValue =  XDTOFactory.Create(XDTOTypeBinaryData, StrReplace(XMLString(ID), "-", ""));
	
	Return HEXValue.Value;
EndFunction

// Converts BinaryData to UUID.
// Executes the reverse action for the UUIDToBinaryData function.
// 
// Parameters:
//     BinaryData - source data.
//
// Returns:
//     UUID - conversion result
//
Function UUIDFromBinaryData(BinaryData) 
	
	// Binary -> hex
	XDTOTypeBinaryData = XDTOFactory.Type("http://www.w3.org/2001/XMLSchema", "hexBinary");
	HEXValue = XDTOFactory.Create(XDTOTypeBinaryData, BinaryData);
	
	// hex -> UUID
	StringAtID = HEXValue.LexicalValue;
	Return New UUID( Mid(StringAtID, 1, 8) + "-" + Mid(StringAtID, 9, 4) + "-" + Mid(StringAtID, 13, 4) + "-" + Mid(StringAtID, 17, 4) + "-" + Mid(StringAtID, 21) );
EndFunction

// Converts  UUID to the base 64 row.
//
// Parameters:
//     ID - UUID, Row - source data.
//
// Returns:
//     String - conversion result
//
Function UUIDToRow64(ID) 
	
	Return BinaryDataToRow( UUIDToBinaryData(ID) );
	
EndFunction

// Converts the base64 row to UUID.
//
// Parameters:
//    String - String - source data.
//
// Returns:
//     ID - conversion result
//
Function UUIDFromRow64(String) 
	
	Return UUIDFromBinaryData( BinaryDataFromRow(String) );
	
EndFunction

// ConvertsBinaryData
// 
// Parameters:
//     BinaryData - source data.
//
// Returns:
//     String - result of conversion to base64.
//
Function BinaryDataToRow(BinaryData) 
	
	Return XMLString(BinaryData);
	
EndFunction

// Converts a row to BinaryData.
// 
// Parameters:
//     String - source data.
//
// Returns:
//     BinaryData - conversion result
//
Function BinaryDataFromRow(String) 
	
	Return XMLValue(Type("BinaryData"), String);
	
EndFunction

#EndRegion

#Region OutdatedClassifierTransfer

// Background actualization of an address classifier.
//
Procedure BackgroundDataTransferObsoleteClassifier(ExportParameters, StorageAddress) Export
	
	States = ObsoleteClassifierFilledStates();
	If States.Count() > 0 Then
		TransferOutdatedDataClassifier(States);
	EndIf;
	
EndProcedure

Function ObsoleteClassifierFilledStates() Export
	
	// Select all states that have records about them.
	Query = New Query("
		|SELECT DISTINCT
		|	States.InCodeAddressObjectCode AS RFTerritorialEntityCode
		|FROM
		|	InformationRegister.DeleteAddressClassifier AS States
		|WHERE
		|	States.AddressPointType = 1
		|	AND 1 In (
		|		SELECT TOP 1 1 FROM InformationRegister.DeleteAddressClassifier
		|		WHERE AddressPointType = 2 AND InCodeAddressObjectCode = States.InCodeAddressObjectCode
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.DeleteAddressClassifier
		|		WHERE AddressPointType = 3 AND InCodeAddressObjectCode = States.InCodeAddressObjectCode
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.DeleteAddressClassifier
		|		WHERE AddressPointType = 4 AND InCodeAddressObjectCode = States.InCodeAddressObjectCode
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.DeleteAddressClassifier
		|		WHERE AddressPointType = 5 AND InCodeAddressObjectCode = States.InCodeAddressObjectCode
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.DeleteAddressClassifier
		|		WHERE AddressPointType = 6 AND InCodeAddressObjectCode = States.InCodeAddressObjectCode
		|	)
		|");
		
	Result = Query.Execute().Unload().UnloadColumn("RFTerritorialEntityCode");
	
	Return Result;
EndFunction

// Checks if there is at least one KLADR record (not including records about states) that needs to be transferred.
//
Function OutdatedClassifierContainsInformation()
	
	Query = New Query("
		|SELECT TOP 1
		|	States.InCodeAddressObjectCode AS RFTerritorialEntityCode
		|FROM
		|	InformationRegister.DeleteAddressClassifier AS States
		|WHERE
		|	States.AddressPointType > 1
		|");
		
	Result = Query.Execute().Select();
	
	If Result.Next() Then
		Return True;
	EndIf;
	Return False;
EndFunction
	
Procedure TransferOutdatedDataClassifier(RFTerritorialEntitiesCodes)
	
	// 1. Transfer all ordered territorial entities.
	TerritorialEntityTotally = RFTerritorialEntitiesCodes.Count();
	SerialNumber = 0;
	
	ImportDate = CurrentUniversalDate();
	VersionDate   = ImportDate;
	
	For Each RFTerritorialEntity In RFTerritorialEntitiesCodes Do
		
		SerialNumber = SerialNumber + 1;
		LongActions.TellProgress( , StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Actualization of information about state %1-%2 (%3 is left) ...';ru='Актуализация сведений о регионе ""%1 - %2"" (осталось %3) .'"), 
			RFTerritorialEntity, AddressClassifier.StateNameByCode(RFTerritorialEntity),
			Format(TerritorialEntityTotally - SerialNumber, "NZ=")));
		
		BeginTransaction();
		Try
			TransferStateFromKLADRData(RFTerritorialEntity);
			
			// Put the data version of the state import.
			SetInformationAboutVersionImport(RFTerritorialEntity, "AC", VersionDate, ImportDate);
			
			// Clear imported data in an old classifier.
			ClearOutdatedClassifierInformation(RFTerritorialEntity);

			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndDo;
	
	// 4. Update the list of RF territorial entities - make sure that you have all root records.
	InformationRegisters.AddressObjects.UpdateRFTerritorialEntitiesContentByClassifier(True);
	
	// 5. Recalculate abbreviations of addresses by actually imported data.
	// You will need this data during parsing of address from the row.
	CalculateAddressInformationReductionsLevels();
EndProcedure

Procedure TransferStateFromKLADRData(RFTerritorialEntity)
	
	AdditionalAddressInformation = InformationRegisters.AdditionalAddressInformation.CreateRecordSet();
	AddressObjects                = InformationRegisters.AddressObjects.CreateRecordSet();
	AddressObjectsHistory        = InformationRegisters.AddressObjectsHistory.CreateRecordSet();
	HousesBuildingsConstructions             = InformationRegisters.HousesBuildingsConstructions.CreateRecordSet();
	ServiceAddressData      = InformationRegisters.ServiceAddressData.CreateRecordSet();
	
	DataTables = New Structure;
	DataTables.Insert("RFTerritorialEntitiesClassifier",  InformationRegisters.AddressObjects.RFTerritorialEntitiesClassifier() );
	DataTables.Insert("ServiceAddressData", ServiceAddresInformationForKLADRDataProcessor() );
	
	DataTables.Insert("AddressObjects", AddressObjects.UnloadColumns() );
	DataTables.AddressObjects.Indexes.Add("ID");
	DataTables.AddressObjects.Indexes.Add("ARCACode");
	
	DataTables.Insert("AddressObjectsHistory", AddressObjectsHistory);
	DataTables.Insert("HousesBuildingsConstructions",      HousesBuildingsConstructions.UnloadColumns());
	DataTables.HousesBuildingsConstructions.Columns.Add("ConstructionsMap");
	DataTables.HousesBuildingsConstructions.Indexes.Add("AddressObject, PostalCode, RFTerritorialEntityCode");
	
	DataTables.Insert("AdditionalInformation",  AdditionalAddressInformation.UnloadColumns());
	DataTables.AdditionalInformation.Indexes.Add("RFTerritorialEntityCode, OKATO, OKTMO, CodeIFTSIndividual, CodeIFTSLegEnt, DepartmentCodeIFTSIndividual, DepartmentCodeIFTSLegEnt");

	DataTables.Insert("TypesOfPartsOfBuilding", KLADRBuildingPartsTypes());
	
	// 1. Addresses and additional information.
	FillKLADRRegisterAddressObjects(RFTerritorialEntity, DataTables);
	
	// 2. Houses  - by the imported relevant data.
	FillFillHousesBuildingsConstructionsKLADR(RFTerritorialEntity, DataTables);
	
	// 3. Record of the collected
	AddressObjects.Load(DataTables.AddressObjects);
	AddressObjects.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntity);
	InfobaseUpdate.WriteData(AddressObjects);
	
	// Houses with packaging
	Deflate = New Deflation(9);
	For Each String In DataTables.HousesBuildingsConstructions Do
		NewRow = HousesBuildingsConstructions.Add();
		FillPropertyValues(NewRow, String, , "Buildings");
		
		AllConstructions = "";
		For Each KeyValue In String.ConstructionsMap Do
			AllConstructions = AllConstructions + KeyValue.Value + Chars.LF;
		EndDo;
		
		NewRow.Buildings = New ValueStorage(AllConstructions, Deflate); 
	EndDo;
	HousesBuildingsConstructions.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntity);
	InfobaseUpdate.WriteData(HousesBuildingsConstructions);
	
	// All additional
	AdditionalAddressInformation.Load(DataTables.AdditionalInformation);
	AdditionalAddressInformation.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntity);
	InfobaseUpdate.WriteData(AdditionalAddressInformation);
	
	// 4. No history
	Set = InformationRegisters.AddressObjectsHistory.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntity);
	InfobaseUpdate.WriteData(Set);
	
	// 5. No landmarks
	Set = InformationRegisters.AddressObjectsLandmarks.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntity);
	InfobaseUpdate.WriteData(Set);
	
	// 6. There are no reasons for change
	Set = InformationRegisters.AddressInformationChangingReasons.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntity);
	InfobaseUpdate.WriteData(Set);
	
EndProcedure

Procedure FillKLADRRegisterAddressObjects(RFTerritorialEntity, DataTables)
	
	NumberType = New TypeDescription("Number");
	
	TableOfAddressObjects = DataTables.AddressObjects;
	AddressObjectsHistory = DataTables.AddressObjectsHistory;
	AdditionalTable   = DataTables.AdditionalInformation;
	ClassifierTable   = DataTables.RFTerritorialEntitiesClassifier;
	
	// Select levels 1 - 5, before streets, without houses.
	Query = New Query("
		|SELECT
		|	AddressPointType, InCodeAddressObjectCode, InCodeRegionCode, CityCodeInsideCode, PlaceCodeInsideCode, StreetCodeInsideCode, Code,
		|	Description, Abbr, IndexOf, ActualitySign
		|FROM
		|	InformationRegister.DeleteAddressClassifier
		|WHERE 
		|	AddressPointType = 1
		|	AND InCodeAddressObjectCode = &RFTerritorialEntityCode
		|UNION ALL SELECT
		|	AddressPointType, InCodeAddressObjectCode, InCodeRegionCode, CityCodeInsideCode, PlaceCodeInsideCode, StreetCodeInsideCode, Code,
		|	Description, Abbr, IndexOf, ActualitySign
		|FROM
		|	InformationRegister.DeleteAddressClassifier
		|WHERE 
		|	AddressPointType = 2
		|	AND InCodeAddressObjectCode = &RFTerritorialEntityCode
		|UNION ALL SELECT
		|	AddressPointType, InCodeAddressObjectCode, InCodeRegionCode, CityCodeInsideCode, PlaceCodeInsideCode, StreetCodeInsideCode, Code,
		|	Description, Abbr, IndexOf, ActualitySign
		|FROM
		|	InformationRegister.DeleteAddressClassifier
		|WHERE 
		|	AddressPointType = 3
		|	AND InCodeAddressObjectCode = &RFTerritorialEntityCode
		|UNION ALL SELECT
		|	AddressPointType, InCodeAddressObjectCode, InCodeRegionCode, CityCodeInsideCode, PlaceCodeInsideCode, StreetCodeInsideCode, Code,
		|	Description, Abbr, IndexOf, ActualitySign
		|FROM
		|	InformationRegister.DeleteAddressClassifier
		|WHERE 
		|	AddressPointType = 4
		|	AND InCodeAddressObjectCode = &RFTerritorialEntityCode
		|UNION ALL SELECT
		|	AddressPointType, InCodeAddressObjectCode, InCodeRegionCode, CityCodeInsideCode, PlaceCodeInsideCode, StreetCodeInsideCode, Code,
		|	Description, Abbr, IndexOf, ActualitySign
		|FROM
		|	InformationRegister.DeleteAddressClassifier
		|WHERE 
		|	AddressPointType = 5
		|	AND InCodeAddressObjectCode = &RFTerritorialEntityCode
		|");
		
	Query.SetParameter("RFTerritorialEntityCode", RFTerritorialEntity);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Selection.ActualitySign <> 0 Then
			// Historical record 
			NewRow = AddressObjectsHistory.Add();
			NewRow.CurrentRFTerritorialEntityCode = RFTerritorialEntity;
		Else
			// Relevant data
			NewRow = TableOfAddressObjects.Add();
			NewRow.Relevant = True;
		EndIf;
		
		NewRow.RFTerritorialEntityCode             = RFTerritorialEntity;
		NewRow.DistrictCode                 = 0;	// It is not supported in KLADR
		NewRow.RegionCode                 = Selection.InCodeRegionCode;
		NewRow.CityCode                 = Selection.CityCodeInsideCode;
		NewRow.UrbanDistrictCode = 0;	// It is not supported in KLADR
		NewRow.SettlementCode      = Selection.PlaceCodeInsideCode;
		
		NewRow.StreetCode = Selection.StreetCodeInsideCode;
		NewRow.ARCACode = Int(Selection.Code / 10000 );
		
		NewRow.AdditionalItemCode = 0;	// It is not supported in KLADR
		NewRow.SubordinateItemCode    = 0;	// It is not supported in KLADR
		
		// Level is calculated by the hierarchy codes.
		NewRow.Level = LevelByRecordHierarchicalCodes(NewRow);
		
		ID = New UUID;
		If NewRow.Level = 1 Then
			// Substitute a territorial entity identifier from the classifier.
			TerritorialEntityRow = ClassifierTable.Find(RFTerritorialEntity, "RFTerritorialEntityCode");
			If TerritorialEntityRow <> Undefined Then
				ID = TerritorialEntityRow.ID;
			EndIf;
		EndIf;
		
		NewRow.ID  = ID;
		NewRow.PostalIndex = NumberType.AdjustValue(Selection.IndexOf);
		NewRow.Description   = Selection.Description;
		NewRow.Abbr     = Selection.Abbr;
		
		NewRow.Additionally  = AdditionalInformationKLADRIdentifier(AdditionalTable, RFTerritorialEntity, 0, 0, 0);
		
	EndDo;
	
EndProcedure

Procedure FillFillHousesBuildingsConstructionsKLADR(RFTerritorialEntity, DataTables)
	
	NumberType = New TypeDescription("Number");
	
	TableOfAddressObjects = DataTables.AddressObjects;
	AddressObjectsHistory = DataTables.AddressObjectsHistory;
	AdditionalTable   = DataTables.AdditionalInformation;
	ClassifierTable   = DataTables.RFTerritorialEntitiesClassifier;
	TypesOfPartsOfBuilding        = DataTables.TypesOfPartsOfBuilding;
	
	// Select levels 6 - only houses.
	Query = New Query("
		|SELECT
		|	AddressPointType, InCodeAddressObjectCode, InCodeRegionCode, CityCodeInsideCode, PlaceCodeInsideCode, StreetCodeInsideCode, Code,
		|	Description, Abbr, IndexOf, ActualitySign
		|FROM
		|	InformationRegister.DeleteAddressClassifier
		|WHERE 
		|	AddressPointType = 6
		|	AND InCodeAddressObjectCode = &RFTerritorialEntityCode
		|");
		
	Query.SetParameter("RFTerritorialEntityCode", RFTerritorialEntity);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		AddressObjectCode = Int(Selection.Code / 10000 );
		
		AddressObjectRow = TableOfAddressObjects.Find(AddressObjectCode, "ARCACode");
		AddressObjectIdentifier = ?(AddressObjectRow = Undefined, Undefined, AddressObjectRow.ID);
		
		HasHousesRecords = True;
		While HasHousesRecords Do
			
			If AddressObjectIdentifier <> Undefined Then
				
				Definition = Selection.Description;
				
				HousesParameters = New Structure;
				HousesParameters.Insert("AddressObject", AddressObjectIdentifier);
				HousesParameters.Insert("PostalIndex", NumberType.AdjustValue(Selection.IndexOf));
				HousesParameters.Insert("RFTerritorialEntityCode",  RFTerritorialEntity);
				
				AdditionalIdentifier = AdditionalInformationKLADRIdentifier(AdditionalTable, RFTerritorialEntity, 0, 0, 0);
				
				AddHousesBuildingsConstructionsRecordsKLADR(Definition, HousesParameters, AdditionalIdentifier, DataTables);
			EndIf;
			
			HasHousesRecords = Selection.Next();
		EndDo;
		
	EndDo;
	
EndProcedure

// Min service information.
// Identifiers should be read from InformationRegister.ServiceAddressInformation but they may not be there.
//
Function ServiceAddresInformationForKLADRDataProcessor()
	
	Result = 
		// Intervals
		ServiceAddressInformationRow("INTVSTAT", 1, Undefined, "Normal",
		ServiceAddressInformationRow("INTVSTAT", 2, Undefined, "Even",
		ServiceAddressInformationRow("INTVSTAT", 3, Undefined, "Odd",
		// Houses
		ServiceAddressInformationRow("ESTSTAT", 1, Undefined, "Ownership",
		ServiceAddressInformationRow("ESTSTAT", 2, Undefined, "House",
		ServiceAddressInformationRow("ESTSTAT", 3, Undefined, "Homeownership",
		// Buildings
		ServiceAddressInformationRow("STRSTAT", 1, Undefined, "Construction",
		ServiceAddressInformationRow("STRSTAT", 2, Undefined, "Facility",
		ServiceAddressInformationRow("STRSTAT", 3, Undefined, "Letter",
		ServiceAddressInformationRow("STRSTAT", 3, Undefined, "Liter",
		InformationRegisters.ServiceAddressData.CreateRecordSet().UnloadColumns()
	))))))))));
	
	Result.Indexes.Add("Type, Value");
	Return Result;
EndFunction

Function ServiceAddressInformationRow(Type, ID, Key, Value, ServiceAddressData)
	
	String = ServiceAddressData.Add();
	String.Type           = Type;
	String.ID = ID;
	String.Key          = Key;
	String.Value      = Value;
	
	Return ServiceAddressData;
EndFunction

// Generates a table of prefixes - separators of KLADR data, jobs types.
//
// Returns:
//     ValueTable - Possible variants. Contains columns:
//         * Prefix       - String - prefix-separator
//         * Identifier - String - identifier for structure.
//         * StatusType    - String - type for searching an identifier in the statuses table.
//         * Length         - Number  - prefix length.
//
Function KLADRBuildingPartsTypes()
	
	Result = 
		KLADRBuildingPartsRow("HOUSE",        "House",          "ESTSTAT",
		KLADRBuildingPartsRow("OW",        "Ownership",     "ESTSTAT",
		KLADRBuildingPartsRow("HMOW",       "Homeownership", "ESTSTAT",
		KLADRBuildingPartsRow("Section",     "Block",       "", 
		KLADRBuildingPartsRow("K",          "Block",       "", 
		KLADRBuildingPartsRow("str",        "Construction",     "STRSTAT",
		KLADRBuildingPartsRow("Building",   "Construction",     "STRSTAT",
		KLADRBuildingPartsRow("LETTER",     "Letter",       "STRSTAT",
		KLADRBuildingPartsRow("LITER",      "Letter",       "STRSTAT",
		KLADRBuildingPartsRow("CONSTRUCTION", "Facility",   "STRSTAT",
		KLADRBuildingPartsRow("SITE",    "Land",      "STRSTAT",
		"Prefix, Identifier, StatusType, Length"
	)))))))))));
	
	Result.Sort("Length DESC, Prefix");
	Result.Indexes.Add("ID");
	
	Return Result;
EndFunction

Function KLADRBuildingPartsRow(Prefix, ID, StatusType, Table)
	
	If TypeOf(Table) = Type("String") Then
		// List of created columns
		Result = New ValueTable;
		For Each KeyValue In New Structure(Table) Do
			ColumnName = KeyValue.Key;
			Result.Columns.Add(ColumnName);
			Result.Indexes.Add(ColumnName);
		EndDo;
	Else 
		Result = Table;
	EndIf; 
	
	String = Result.Add();
	String.Prefix       = Prefix;
	String.ID = ID;
	String.StatusType    = StatusType;
	String.Length         = StrLen(Prefix);
	
	Return Result;
EndFunction

// Calculate the level of FIAS by the codes set from junior to senior.
//
Function LevelByRecordHierarchicalCodes(Record)
	
	If Record.SubordinateItemCode > 0 Then
		Return 91;
		
	ElsIf Record.AdditionalItemCode > 0 Then
		Return 90;
		
	ElsIf Record.StreetCode > 0 Then 
		Return 7;
		
	ElsIf Record.SettlementCode > 0 Then 
		Return 6;
		
	ElsIf Record.UrbanDistrictCode > 0 Then 
		Return 5;
		
	ElsIf Record.CityCode > 0 Then 
		Return 4;
		
	ElsIf Record.RegionCode > 0 Then 
		Return 3;
		
	ElsIf Record.DistrictCode > 0 Then 
		Return 2;
		
	ElsIf Record.RFTerritorialEntityCode > 0 Then 
		Return 1;
		
	EndIf;
	
	Return Undefined;
EndFunction

Function AdditionalInformationKLADRIdentifier(AdditionalTable, RFTerritorialEntity, OKATO, IFTSCode, DepartmentCode)
	
	Filter = New Structure;
	Filter.Insert("RFTerritorialEntityCode",    RFTerritorialEntity);
	Filter.Insert("OKATO",            OKATO);
	Filter.Insert("OKTMO",            0);
	Filter.Insert("IFTSIndividualCode",        IFTSCode);
	Filter.Insert("IFTSLegalEntityCode",        IFTSCode);
	Filter.Insert("IFTSIndividualDepartmentCode", DepartmentCode);
	Filter.Insert("IFTSLegalEntityDepartmentCode", DepartmentCode);
	
	RowsVariants = AdditionalTable.FindRows(Filter);
	If RowsVariants.Count() = 0 Then
		CodesRow = AdditionalTable.Add();
		FillPropertyValues(CodesRow, Filter);
		CodesRow.ID = New UUID;
	Else
		CodesRow = RowsVariants[0];
	EndIf;
	
	Return CodesRow.ID;
EndFunction

// Generates all records by one of the rows of the KLADR houses.
//
Procedure AddHousesBuildingsConstructionsRecordsKLADR(Definition, HousesParameters, AdditionalIdentifier, DataTables)
	
	AdditionalIdentifierInRow = UUIDToRow64(AdditionalIdentifier);
	HousesBuildingsConstructions                 = DataTables.HousesBuildingsConstructions;
	TypesOfPartsOfBuilding                   = DataTables.TypesOfPartsOfBuilding;
	
	// Break a description into sections.
	DescriptionVariants = Upper(StrReplace( TrimAll(StrReplace(Definition, ",", Chars.LF)), " ", ""));
	For LineNumber = 1 To StrLineCount(DescriptionVariants) Do
		SingleDescription = Upper( TrimAll( StrGetLine(DescriptionVariants, LineNumber) ));
		If IsBlankString(SingleDescription) Then 
			Continue;
		EndIf;
		
		// Search where to add
		RecordsVariants = HousesBuildingsConstructions.FindRows(HousesParameters);
		If RecordsVariants.Count() = 0 Then
			HousesRecord = HousesBuildingsConstructions.Add();
			FillPropertyValues(HousesRecord, HousesParameters);
			HousesRecord.ConstructionsMap = New Map;
		Else
			HousesRecord = RecordsVariants[0];
		EndIf;
		
		// Check for a range
		RangeDescription = KLADRRangeDescription(SingleDescription, DataTables);
		If RangeDescription <> Undefined Then
			AddConstructionsRowDescription(HousesRecord.ConstructionsMap, AdditionalIdentifierInRow, RangeDescription);
			
		Else
			// Check for house
			BuildingDescription = KLADRBuildingDescription(SingleDescription, DataTables);
			If BuildingDescription <> Undefined Then
				AddConstructionsRowDescription(HousesRecord.ConstructionsMap, AdditionalIdentifierInRow, BuildingDescription);
			EndIf;
		EndIf;
		
	EndDo;
		
EndProcedure

// Modify ConstructionDescription adding Description to a row with a required AdditionalIdentifier64.
//
Procedure AddConstructionsRowDescription(ConstructionsMap, AdditionalIdentifier64, Definition)
	Delimiter = Chars.Tab;
	
	String = ConstructionsMap[AdditionalIdentifier64];
	If String = Undefined Then
		String = AdditionalIdentifier64;
	EndIf;
	
	ConstructionsMap[AdditionalIdentifier64] = String + Delimiter + Definition;
EndProcedure

// Returns a row of range description measured in FIAS or Undefined if a row - not range.
//
Function KLADRRangeDescription(Definition, DataTables)
	
	PositionOfHyphen = Find(Definition, "-");
	Char        = Left(Definition, 1);
	
	If Char = "N" Then
		// Odd
		Range = Mid(Definition, 2);
		Filter = New Structure("Type, Value", "INTVSTAT", "Odd");
		
	ElsIf Char = "h" Then
		// Even
		Filter = New Structure("Type, Value", "INTVSTAT", "Even");
		
	ElsIf PositionOfHyphen > 0 AND IsDigit(Char) Then
		// Normal
		Filter = New Structure("Type, Value", "INTVSTAT", "Normal");
		
	Else 
		// Not range
		Return Undefined
		
	EndIf;
	
	TypesVariants = DataTables.ServiceAddressData.FindRows(Filter);
	If TypesVariants.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Error occurred during searching the type of range for %1';ru='Ошибка поиска типа диапазона для %1'"), Definition
		);
	EndIf;
	
	Delimiter = Chars.Tab;
	Result = "i" 
		+ Delimiter + Format(TypesVariants[0].ID, "NZ=; NG=")            	// Interval type
		+ Delimiter + ?(PositionOfHyphen = 0, "", Mid(Definition, 2, PositionOfHyphen - 2))	// Interval begin
		+ Delimiter + ?(PositionOfHyphen = 0, "", Mid(Definition, PositionOfHyphen + 1));  	// Interval end
		
	Return Result;
EndFunction

// Returns a row of a job description measured in FIAS or Undefined if a row - not a building
//
Function KLADRBuildingDescription(Definition, DataTables)
	
	ServiceAddressData = DataTables.ServiceAddressData;
	TypesOfPartsOfBuilding          = DataTables.TypesOfPartsOfBuilding;
	
	DescriptionStructure = KLADRBuildingDescriptionStructure(Definition, TypesOfPartsOfBuilding);
	
	OwnershipType   = 0;
	ConstructionType   = 0;
	BlockNumber  = "";
	HouseNumber     = "";
	ConstructionNumber = "";
	
	For Each KeyValue In DescriptionStructure Do
		Value = TrimAll(KeyValue.Value);
		Key     = KeyValue.Key;
		
		If IsBlankString(Value) Then
			Continue;
		EndIf;
		
		DescriptionString = TypesOfPartsOfBuilding.Find(KeyValue.Key, "ID");
		If DescriptionString = Undefined Then 
			Continue;
		EndIf;
		
		StatusType = DescriptionString.StatusType;
		If StatusType = "" Then
			// Block
			BlockNumber = Value;
			Continue;
		EndIf;
		
		TypesVariants = ServiceAddressData.FindRows( New Structure("Type, Value", StatusType, Key) );
		If TypesVariants.Count() = 0 Then
			Continue;
		EndIf;
		Variant = TypesVariants[0].Value;
		VariantType = TypesVariants[0].ID;
		If Variant = "House" Or Variant = "Ownership" Or Variant = "Homeownership" Then
			OwnershipType = VariantType;
			HouseNumber   = Value;
		Else
			ConstructionType   = VariantType;
			ConstructionNumber = Value;
		EndIf;
		
	EndDo;
	
	If HouseNumber = "" AND BlockNumber = "" AND ConstructionNumber = "" Then
		Return Undefined;
	EndIf;
	
	Delimiter = Chars.Tab;
	
	Result = "h"
		+ Delimiter + Format(OwnershipType, "NZ=; NG=")
		+ Delimiter + HouseNumber
		+ Delimiter + BlockNumber
		+ Delimiter + Format(ConstructionType, "NZ=; NG=")
		+ Delimiter + ConstructionNumber;
		
	Return Result;
EndFunction

Function IsDigit(Char)
	
	Return Find("0123456789", Char) > 0;
	
EndFunction

// Parses a row description of a separate building KLADR.
//
// Parameters:
//     Definition         - String          - Description of a single KLADR building.
//     TypesOfPartsOfBuilding - ValueTable - For parsing the abbreviations, result of the BuildingPartsTypes function. 
//
// Returns:
//     Structure    - Key - identifier, value - job number.
//                    Set of identifiers is defined by the data of the JobPartsTypes table-result.
//     Undefined - if it fails to recognize a description.
//
Function KLADRBuildingDescriptionStructure(Definition, TypesOfPartsOfBuilding)
	
	Text = Definition;
	Result = New Structure;
	
	// Default identifier for the possibly empty first key.
	ID = "House";
	Result.Insert(ID);
	
	ThereAreMoreParts = True;
	
	While ThereAreMoreParts Do
		// Type of the current part
		Position = 1;
		For Each PartType In TypesOfPartsOfBuilding Do
			If Left(Text, PartType.Length) = PartType.Prefix Then
				ID = PartType.ID;
				Position       = 1 + PartType.Length;
				Break;
			EndIf;
		EndDo;
		Text = Mid(Text, Position);
		
		// Part value
		Position = 0;
		For Each PartType In TypesOfPartsOfBuilding Do
			// Search for the nearest next type after which there must be a value.
			PositionTest = Find(Text, PartType.Prefix);
			If PositionTest > 0                                                // found
				AND (Position = 0 Or PositionTest<Position)                         // Nearest
				AND Not IsBlankString(Mid(Text, PositionTest + PartType.Length, 1)) // With value
			Then
				Position = PositionTest;
			EndIf;
		EndDo;
		
		ThereAreMoreParts = Position > 0;
		If ThereAreMoreParts Then
			Value = Left(Text, Position-1);
			Text = Mid(Text, Position);
		Else
			Value = Text;
		EndIf;
		
		Result.Insert(ID, StrReplace(Value, "_", "-"));
	EndDo; 
	
	Return Result;
EndFunction

#EndRegion

#Region OtherServiceProceduresAndFunctions

// Returns if the data source is web service.
//
// Returns:
//     Boolean - If web service is a source of address information, then it returns True.
//
Function AddressClassifierDataSourceWebService() Export
	
	Source = AddressClassifierDataSource();
	If Not IsBlankString(Source) AND Source = "Service1C" Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Returns information about the state of the regions load.
//
// Returns:
//    ValueTable - state description. Contains columns.
//      * RFTerritorialEntityCode - Number                   - State code.
//      * Identifier - UUID - State identifier.
//      * Presentation - String                  - State description and abbreviation.
//      * Imported     - Boolean                  - True if the classifier by this state is imported.
//      * VersionDate    - Date                    - UTC version of the imported data.
// 
Function InformationAboutRFTerritorialEntitiesImport() Export
	
	Classifier = InformationRegisters.AddressObjects.RFTerritorialEntitiesClassifier();
	
	// Select all possible data - both from the register and the classifier.
	// It is considered that the uniqueness is provided not by
	// an identifier (which is right) but by a territorial entity code because of the features of the platform of passing a unique identifier to the query table-parameter.
	
	Query = New Query("
		|SELECT
		|	Parameter.Description  AS Description,
		|	Parameter.Abbr    AS Abbr,
		|	Parameter.RFTerritorialEntityCode AS RFTerritorialEntityCode
		|INTO
		|	Classifier
		|FROM
		|	&Classifier AS Parameter
		|;///////////////////////////////////////////////////////////////////////////////////
		|
		|SELECT 
		|	AllAvailableStates.Description + "" "" + AllAvailableStates.Abbr AS Presentation,
		|	AllAvailableStates.RFTerritorialEntityCode                                         AS RFTerritorialEntityCode,
		|	AddressObjectsIdentifiers.ID                              AS ID,
		|	CASE 
		|		WHEN AddressObjects.RFTerritorialEntityCode IS NULL THEN FALSE
		|		ELSE TRUE
		|	END AS Exported,
		|	ISNULL(Versions.VersionDate, DATETIME(1,1,1)) AS VersionDate
		|FROM 
		|(
		|	SELECT DISTINCT
		|		AddressObjects.Description  AS Description,
		|		AddressObjects.Abbr    AS Abbr,
		|		AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode
		|	FROM
		|		InformationRegister.AddressObjects AS AddressObjects
		|	WHERE
		|		AddressObjects.Level = 1
		|		AND AddressObjects.DistrictCode                  = 0
		|		AND AddressObjects.RegionCode                  = 0
		|		AND AddressObjects.CityCode                  = 0
		|		AND AddressObjects.UrbanDistrictCode  = 0
		|		AND AddressObjects.SettlementCode       = 0
		|		AND AddressObjects.StreetCode                   = 0
		|		AND AddressObjects.AdditionalItemCode = 0
		|		AND AddressObjects.SubordinateItemCode    = 0
		|	UNION
		|	SELECT
		|		Classifier.Description,
		|		Classifier.Abbr,
		|		Classifier.RFTerritorialEntityCode
		|	FROM
		|		Classifier AS Classifier
		|) AS AllAvailableStates
		|
		|LEFT JOIN (
		|	SELECT
		|		States.RFTerritorialEntityCode AS RFTerritorialEntityCode
		|	FROM
		|		InformationRegister.AddressObjects AS States
		|	WHERE
		|		States.Level = 1
		|		AND 1 In (
		|			SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|			WHERE Level = 2 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|			UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|			WHERE Level = 3 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|			UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|			WHERE Level = 4 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|			UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|			WHERE Level = 5 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|			UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|			WHERE Level = 6 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|			UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|			WHERE Level = 7 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|			UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|			WHERE Level = 90 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|			UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|			WHERE Level = 91 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|	)
		|) AS AddressObjects
		|ON
		|	AddressObjects.RFTerritorialEntityCode = AllAvailableStates.RFTerritorialEntityCode
		|
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS AddressObjectsIdentifiers
		|ON
		|	AddressObjectsIdentifiers.RFTerritorialEntityCode                = AllAvailableStates.RFTerritorialEntityCode
		|	AND AddressObjectsIdentifiers.Level                    = 1
		|	AND AddressObjectsIdentifiers.DistrictCode                  = 0
		|	AND AddressObjectsIdentifiers.RegionCode                  = 0
		|	AND AddressObjectsIdentifiers.CityCode                  = 0
		|	AND AddressObjectsIdentifiers.UrbanDistrictCode  = 0
		|	AND AddressObjectsIdentifiers.SettlementCode       = 0
		|	AND AddressObjectsIdentifiers.StreetCode                   = 0
		|	AND AddressObjectsIdentifiers.AdditionalItemCode = 0
		|	AND AddressObjectsIdentifiers.SubordinateItemCode    = 0
		|
		|LEFT JOIN
		|	InformationRegister.AddressInformationExportedVersions AS Versions
		|ON
		|	Versions.RFTerritorialEntityCode = AllAvailableStates.RFTerritorialEntityCode
		|
		|ORDER BY
		|	AllAvailableStates.RFTerritorialEntityCode,
		|	AllAvailableStates.Description + "" "" + AllAvailableStates.Abbr
		|");
	Query.SetParameter("Classifier", Classifier);
	
	ImportedInformation = Query.Execute().Unload();
	ImportedInformation.Indexes.Add("ID");
	ImportedInformation.Indexes.Add("RFTerritorialEntityCode");
	ImportedInformation.Indexes.Add("Exported");
	
	// Correct identifiers because of the features of
	// platform of passing a unique identifier to the query table-parameter.
	For Each String In ImportedInformation Do
		If Not ValueIsFilled(String.ID) Then
			ClassifierRow = Classifier.Find(String.RFTerritorialEntityCode, "RFTerritorialEntityCode");
			If ClassifierRow <> Undefined Then
				String.ID = ClassifierRow.ID;
			EndIf;
		EndIf;
	EndDo;
	
	Return ImportedInformation;
EndFunction

// Returns brief information about the state of the regions load.
//
// Returns:
//    Structure - state description. Contains columns.
//      *StatesQuantity - Number                   - Total amount of states.
//      * ImportedStatesQuantity - Number - quantity of imported states.
Function BriefInformationAboutRFTerritorialEntitiesImport() Export
	
	Result = New Structure("StatesQuantity, ImportedStatesQuantity");
	
	Result.ImportedStatesQuantity = AddressClassifier.ImportedStatesQuantity();
	
	Classifier = InformationRegisters.AddressObjects.RFTerritorialEntitiesClassifier();
	Result.StatesQuantity = Classifier.Count();
	
	Return Result;
EndFunction

// Returns a state code and checks if there is imported address information by a state.
//
Function InformationAboutState(StateDescription) Export
	
	Result = New Structure("Imported, RFTerritorialEntityCode", Undefined, Undefined);
	InformationAboutState = AddressClassifierClientServer.DescriptionAndAbbreviation(StateDescription);
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	AddressObjects.RFTerritorialEntityCode AS RFTerritorialEntityCode,
		|	CASE
		|		WHEN Not ImportedData.ID IS NULL 
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS StateImported
		|FROM
		|	InformationRegister.AddressObjects AS AddressObjects
		|		LEFT JOIN InformationRegister.AddressObjects AS ImportedData
		|		ON (ImportedData.Level > 1)
		|			AND AddressObjects.RFTerritorialEntityCode = ImportedData.RFTerritorialEntityCode
		|WHERE
		|	AddressObjects.Description = &Description
		|	AND AddressObjects.Abbr = &Abbr
		|	AND AddressObjects.Level = 1";
	
	Query.SetParameter("Description", InformationAboutState.Description);
	Query.SetParameter("Abbr", InformationAboutState.Abbr);
	
	QueryResult = Query.Execute().Select();
	
	If QueryResult.Next() Then
		Result.Imported = QueryResult.StateImported;
		Result.RFTerritorialEntityCode = QueryResult.RFTerritorialEntityCode;
	EndIf;
	
	Return Result;
	
EndFunction

// Import all data of an address classifier.
//
// Parameters:
//    RFTerritorialEntitiesCodes - Array         - Enable check boxes next to the names of required states.
//
//    FilesDescription  - String, Array - Directory on server that has the data files. It is
//                      expected that attachment file names will be in the top register.
//                                       Array of items of the TransferredFileDescription type or structures with fields.
//                                           * Name      - String - Name or full name of the passed file.
//                                           * Storing - BinaryData, Row - Description of files storage. Row
//                                                        may be a path on the file system or an
//                                                        address in the temporary storage.
//    AlertAboutProgress - Boolean      - Check box of the progress alert (see LongActions.TellProgress).
//
Procedure ImportAddressClassifier(RFTerritorialEntitiesCodes, FilesDescription, AlertAboutProgress = True) Export
	
	ImportDate = CurrentUniversalDate();
	
	If TypeOf(FilesDescription) = Type("String") Then
		// Files are already prepared
		FileDirectory = CommonUseClientServer.AddFinalPathSeparator(FilesDescription);
		
	Else
		// Extract files
		FileDirectory = CommonUseClientServer.AddFinalPathSeparator( GetTempFileName() );
		CreateDirectory(FileDirectory);
		
		For Each FileDescription In FilesDescription Do
			File = New File(FileDescription.Name);
			FullFileName = FileDirectory + Upper(File.Name);;
			
			Data = FileDescription.Location;
			DataType = TypeOf(Data);
			
			If DataType = Type("BinaryData") Then
				Data.Write(FullFileName);
				
			ElsIf IsTempStorageURL(Data) Then
				Data = GetFromTempStorage(Data);
				Data.Write(FullFileName);
				
			Else
				FullFileName = Data;
				
			EndIf;
			
			If Upper(Right(FullFileName, 4)) = ".ZIP" Then
				archive = New ZipFileReader(FullFileName);
				archive.ExtractAll(FileDirectory, ZIPRestoreFilePathsMode.DontRestore);
				DeleteTemporaryFile(FullFileName);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	InformationKindsNotProcessed = True;
	
	// 2. All ordered territorial entities
	TerritorialEntityTotally = RFTerritorialEntitiesCodes.Count();
	SerialNumber = 0;
	
	For Each RFTerritorialEntity In RFTerritorialEntitiesCodes Do
		
		SerialNumber = SerialNumber + 1;
		If AlertAboutProgress Then
			LongActions.TellProgress( , StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Import %1 - %2 state (%3 left) ...';ru='Загрузка региона ""%1 - %2"" (осталось %3) ...'"), 
				RFTerritorialEntity, AddressClassifier.StateNameByCode(RFTerritorialEntity),
				Format(TerritorialEntityTotally - SerialNumber, "NZ=")));
		EndIf;
		
		If InformationKindsNotProcessed Then
				// General help information, you will need it later.
				ServiceAddressData = ServiceAddressData(Undefined, FileDirectory);
				// And write it at once
				Set = InformationRegisters.ServiceAddressData.CreateRecordSet();
				Set.Load(ServiceAddressData.Information);
				InfobaseUpdate.WriteData(Set); 
				
				InformationKindsNotProcessed = False;
		EndIf;
		
		BeginTransaction();
		Try
			
			RFTerritorialEntityVersion = InformationAboutVersionImport(RFTerritorialEntity).Version;
			If RFTerritorialEntityVersion <> ServiceAddressData.Version Then
				ImportAddressObjects(RFTerritorialEntity, FileDirectory, ServiceAddressData.Information);
				ImportHousesBuildingsConstructions(RFTerritorialEntity, FileDirectory, ServiceAddressData.Information);
				ImportAddressObjectsHistory(RFTerritorialEntity, FileDirectory, ServiceAddressData.Information);
				ImportAddressChangeReasons(RFTerritorialEntity, FileDirectory, ServiceAddressData.Information);
				ImportAdditionalInformation(RFTerritorialEntity, FileDirectory, ServiceAddressData.Information);
				ImportAddressLandmarks(RFTerritorialEntity, FileDirectory, ServiceAddressData.Information);
				
				// Put the data version of the state import.
				SetInformationAboutVersionImport(RFTerritorialEntity, ServiceAddressData.Version, ServiceAddressData.VersionDate, ImportDate);
				
				// Clear imported data in an old classifier.
				ClearOutdatedClassifierInformation(RFTerritorialEntity);
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndDo;
	
	// 3. Update the list of RF territorial entities - make sure that you have all root records.
	InformationRegisters.AddressObjects.UpdateRFTerritorialEntitiesContentByClassifier();
	
	// 4. Import abbreviations of addresses.
	// You will need this data during parsing of address from the row.
	AddressAbbreviations = AddressAbbreviations(FileDirectory);
	Set = InformationRegisters.AddressInformationReductionsLevels.CreateRecordSet();
	Set.Load(AddressAbbreviations.Information);
	InfobaseUpdate.WriteData(Set); // Disable all business-logic to speed up the operation.
	
	// 5. Clear a temporary directory.
	If TypeOf(FilesDescription) = Type("String") Then
		DeleteTemporaryFile(FileDirectory);
	EndIf;
	
	// 6. Deletes KLADR outdated data if any.
	ClearOutdatedKLADRAddressInformation();
	
EndProcedure

// Deletes outdated KLADR data.
//
Procedure ClearOutdatedKLADRAddressInformation()
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
		|	DeleteAddressClassifier.Code
		|FROM
		|	InformationRegister.DeleteAddressClassifier AS DeleteAddressClassifier";
	
	QueryResult = Query.Execute().Select();
	If QueryResult .Next() Then 
		WholeRegister = InformationRegisters.DeleteAddressClassifier.CreateRecordSet();
		InfobaseUpdate.WriteData(WholeRegister);
	EndIf;
	
EndProcedure


// Import of all data of the classifier addresses from the website.
//
// Parameters:
//    RFTerritorialEntitiesCodes - Array - Enable check boxes next to the names of required states. if it is not
//                               specified, then all states according to which data was ever imported will be imported.
//    Authorization - Structure - description of authorization on the 1C support website. If it is not specified, then it will be read from the base.
//        * Login  - String - Authorization data.
//        * Password - String - Authorization data.
//
Procedure ImportAddressClassifierFromSite(RFTerritorialEntitiesCodes = Undefined, SourceAuthorization = Undefined) Export
	
	If SourceAuthorization = Undefined Then
		Authorization = StandardSubsystemsServer.AuthenticationParametersOnSite();
	Else
		Authorization = SourceAuthorization;
	EndIf;
	
	If RFTerritorialEntitiesCodes = Undefined Then
		AllStates = InformationAboutRFTerritorialEntitiesImport();
		ImportedStates = AllStates.Copy(New Structure("Imported", True));
		RFTerritorialEntitiesCodes = ImportedStates.UnloadColumn("RFTerritorialEntityCode");
	EndIf;
	
	TemporaryDirectory = GetTempFileName();
	CreateDirectory(TemporaryDirectory);
	TemporaryDirectory = CommonUseClientServer.AddFinalPathSeparator(TemporaryDirectory);
	
	TerritorialEntitiesCodesForImport = New Array;
	FilesDescription           = New Array;
	
	ReceivingParameters = New Structure;
	If Authorization <> Undefined Then
		ReceivingParameters.Insert("User", Authorization.Login);
		ReceivingParameters.Insert("Password",       Authorization.Password);
	EndIf;
	
	AllVersions = AddressInformationAvailableVersions();
	For Each TerritorialEntityCode In RFTerritorialEntitiesCodes Do
		StateDescription = AllVersions.Find(TerritorialEntityCode, "RFTerritorialEntityCode");
		If StateDescription = Undefined Then
			// Possibly outdated state, not an error.
			Continue;
		EndIf;
		
		StateFile = InternetAddressIncludingPort(StateDescription.Address);
		PathForSave = TemporaryDirectory + Upper(StateFile.FileName);
		
		ReceivingParameters.Insert("PathForSave", PathForSave);
		ImportedFile = GetFilesFromInternet.ExportFileAtServer(StateDescription.Address, ReceivingParameters);
		If Not ImportedFile.Status Then
			DeleteTemporaryFile(TemporaryDirectory);
			Raise ImportedFile.ErrorInfo + Chars.LF + 
				NStr("en='Possible
		|reasons: • Login and password were entered incorrectly
		|or were not entered
		|at all • No Internet
		|Connection • The website is encountering problems • Firewall or other middleware (antiviruses etc) prevents
		|a application from connecting to the Inter• Connecting to the Internet via proxy server but its parameters are not specified in the application.';ru='Возможные
		|причины: • Некорректно введен или
		|не введен логин и
		|пароль; • Нет подключения
		|к Интернету; • На веб-узле возникли неполадки; • Брандмауэр или другое промежуточное ПО (антивирусы и
		|т.п.) блокируют попытки программы подключиться к Интернету; • Подключение к Интернету выполняется через прокси-сервер, но его параметры не заданы в программе.'");
		EndIf;
	
		TerritorialEntitiesCodesForImport.Add(TerritorialEntityCode);
		FilesDescription.Add( New Structure("Name, Storage", PathForSave, PathForSave) );
	EndDo;
	
	ImportAddressClassifier(TerritorialEntitiesCodesForImport, FilesDescription);
	DeleteTemporaryFile(TemporaryDirectory);
	
EndProcedure

// Clear data of addresses classifier.
//
// Parameters:
//    RFTerritorialEntitiesCodes - Array - Contains the numeric codes of states-territorial entities for clearing.
//
Procedure ClearAddressesClassifier(RFTerritorialEntitiesCodes) Export
	
	// All ordered territorial entities
	TerritorialEntityTotally = RFTerritorialEntitiesCodes.Count();
	SerialNumber = 0;
	
	For Each RFTerritorialEntity In RFTerritorialEntitiesCodes Do
		
		SerialNumber = SerialNumber + 1;
		LongActions.TellProgress( , StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Clear %1 - %2 state (%3 left) ...';ru='Очистка региона ""%1 - %2"" (осталось %3) ...'"), 
			RFTerritorialEntity, AddressClassifier.StateNameByCode(RFTerritorialEntity),
			Format(TerritorialEntityTotally - SerialNumber, "NZ=")
		));
		
		BeginTransaction();
		Try
			
			ClearAddressObjects(RFTerritorialEntity);
			ClearHousesBuildingsConstructions(RFTerritorialEntity);
			ClearAddressObjectsHistory(RFTerritorialEntity);
			ClearAddressChangeReasons(RFTerritorialEntity);
			ClearAdditionalInformation(RFTerritorialEntity);
			ClearAddressLandmarks(RFTerritorialEntity);
			
			ResetInformationAboutVersionImport(RFTerritorialEntity);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndDo;
	
EndProcedure

// Set of the security profile permissons for checking if there is an update on 1C website.
//
// Returns:
//     Array - required permissions.
// 
Function UpdateSecurityPermissions() Export
	
	permissions = New Array;
	
	// Update request 
	Address = CommonUseClientServer.URLStructure( FileURLAvailableVersionsDescription() );
	permissions.Add( WorkInSafeMode.PermissionForWebsiteUse(
		Upper(Address.Schema), Address.Host, Address.Port, NStr("en='Check the update of an address classifier.';ru='Проверка обновления адресного классификатора.'")
	));
	
	// Root data directory - used only for receiving permission.
	// Actual address for import is read from the update file.
	Address = CommonUseClientServer.URLStructure("http://1c-dn.com/demos/addressclassifier/");
	permissions.Add( WorkInSafeMode.PermissionForWebsiteUse(
		Upper(Address.Schema), Address.Host, Address.Port, NStr("en='Update data of an address classifier.';ru='Загрузка данных адресного классификатора.'")
	));
	
	Return permissions;
EndFunction

// Path to file on the web server containing information by versions of the address information.
//
// Returns:
//     String - path to data description file.
//
Function FileURLAvailableVersionsDescription() Export
	
	Return "http://1c-dn.com/demos/addressclassifier/versions.xml";
	
EndFunction

// Space of names for XDTO operations.
//
// Returns:
//     String
//
Function TargetNamespace() Export
	
	Return "http://www.v8.1c.ru/ssl/AddressSystem";
	
EndFunction

// Checks if there are updates of address
// classifier on the web server for those objects that were previously imported.
//
// Returns - ValueTable - Description of added and changed territorial entities. Contains Columns.
//     * RFTerritorialEntityCode      - Number                   - RF territorial entity code.
//     * Description       - String                  - Name of RF territorial entity.
//     * Abbreviation         - String                  - Abbreviation of RF territorial entity
//     * Code             - Number                   - Postal code.
//     * Identifier      - UUID - Identifier of RF territorial entity.
//     * Address              - String                  - Address for exporting the file of state data.
//     * UpdateAvailable - Boolean                  - Check box of availability of an update for the specified state.
//     * Imported          - Boolean                  - Check box showing that data was imported at least once.
//
Function AddressInformationAvailableVersions() Export
	
	Result = New ValueTable;
	
	StringType = New TypeDescription("String");
	NumberType  = New TypeDescription("Number");
	BooleanType = New TypeDescription("Boolean");
	Columns   = Result.Columns;
	
	Columns.Add("RFTerritorialEntityCode",      NumberType);
	Columns.Add("Description",       StringType);
	Columns.Add("Abbr",         StringType);
	Columns.Add("IndexOf",             NumberType);
	Columns.Add("ID",      New TypeDescription("UUID") );
	Columns.Add("Address",              StringType);
	Columns.Add("UpdateAvailable", BooleanType);
	Columns.Add("Exported",          BooleanType);
	
	Result.Indexes.Add("RFTerritorialEntityCode");
	
	DescriptionAddress = InternetAddressIncludingPort( FileURLAvailableVersionsDescription() );
	FileReceivingResult = GetFilesFromInternet.ExportFileAtServer(DescriptionAddress.Address);
	If Not FileReceivingResult.Status Then
		Raise FileReceivingResult.ErrorInfo;
	EndIf;
	
	// Zip is received with xml inside.
	DirectoryForUnpacking = GetTempFileName();
	archive = New ZipFileReader(FileReceivingResult.Path);
	archive.ExtractAll(DirectoryForUnpacking);
	DescriptionFile = CommonUseClientServer.AddFinalPathSeparator(DirectoryForUnpacking) + "version.xml";
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(DescriptionFile);
	AvailableData = XDTOFactory.ReadXML(XMLReader, XDTOFactory.Type( TargetNamespace(), "Publications") );
	
	XMLReader.Close();
	DeleteTemporaryFile(DirectoryForUnpacking);
	DeleteTemporaryFile(FileReceivingResult.Path);
	
	LastVersionDate = '00000000';
	LastPublication = Undefined;
	
	For Each Publication In AvailableData.GetList("Publication") Do
		If Publication.UpdateDate > LastVersionDate Then
			LastVersionDate = Publication.UpdateDate;
			LastPublication = Publication;
		EndIf;
	EndDo;

	If LastPublication = Undefined Then
		// There is no data at all
		Return Result;
	EndIf;
	
	// Compare the content of a register to the things you have read about.
	CurrentTerritorialEntities = InformationAboutRFTerritorialEntitiesImport();
	
	For Each StateRecord In LastPublication.GetList("Region") Do
		ID = UUIDFromBinaryData(StateRecord.AOGUID);
		CurrentTerritorialEntity = CurrentTerritorialEntities.Find(ID, "ID");
		
		StateRow = Result.Add();
		StateRow.RFTerritorialEntityCode = StateRecord.REGIONCODE;
		StateRow.Description  = StateRecord.FORMALNAME;
		StateRow.Abbr    = StateRecord.SHORTNAME;
		StateRow.IndexOf        = StateRecord.POSTALCODE;
		StateRow.ID = ID;
		StateRow.Address         = StateRecord.Url;
		StateRow.Exported     = CurrentTerritorialEntity <> Undefined AND CurrentTerritorialEntity.Exported;
		
		StateRow.UpdateAvailable = CurrentTerritorialEntity = Undefined	// New state
			Or CurrentTerritorialEntity.VersionDate < LastVersionDate         	// Updated state
			Or (                                                       	// Updated data of the existing object.
				    CurrentTerritorialEntity.RFTerritorialEntityCode <> StateRecord.REGIONCODE
				Or CurrentTerritorialEntity.Presentation <> StateRecord.FORMALNAME
				Or CurrentTerritorialEntity.Abbr    <> StateRecord.SHORTNAME
				Or CurrentTerritorialEntity.IndexOf        <> StateRecord.POSTALCODE
			);
	EndDo;
	
	Return Result;
EndFunction

// Returns the description of the last classifier import.
//
// Returns:
//     Structure - contains fields:
//         * LastImportDate              - Date   - Date of the last import (session timezone).
//         * LastImportUniversalDate - Date   - Date of the last import (UTC).
//         * DaysAgo                          - Number  - Quantity of days since the last import.
//         * Presentation                      - String - Description, for example, "Address
//                                                         classifier was imported today.";
//         * UpdateRequired               - Boolean - True if the quantity of days from
//                                                         the last import exceeds the relevance period.
//
Function LastImportDescription() Export
	
	Result = New Structure("DaysAgo, LastUpdateDate, LastImportUniversalDate, Presentation, UpdateNeeded");
	
	// Define date of the last import.
	Query = New Query("
		|SELECT TOP 1 
		|	ImportDate AS ImportDate
		|FROM
		|	InformationRegister.AddressInformationExportedVersions
		|ORDER BY
		|	ImportDate DESC
		|");
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		LastImportDate = Selection.ImportDate;
	Else
		LastImportDate = '00000000';
	EndIf;
	
	If LastImportDate = '00000000' Then
		Result.UpdateRequired = False;
		Result.Presentation        = NStr("en='Address classifier has not been imported yet.';ru='Адресный классификатор еще не загружался.'");
		Return Result;
	EndIf;
	
	Result.LastImportUniversalDate = LastImportDate;
	Result.LastImportDate              = ToLocalTime(LastImportDate, SessionTimeZone());
	
	BeginOfPeriod = BegOfDay(CurrentUniversalDate());
	EndOfPeriod  = BegOfDay(LastImportDate);
	DaysDifference = Int( (BeginOfPeriod - EndOfPeriod) / 86400 );

	If DaysDifference = 0 Then
		Presentation = NStr("en='Address classifier will be imported today.';ru='Адресный классификатор был загружен сегодня.'");
		
	ElsIf DaysDifference = 1 Then
		Presentation = NStr("en='Address classifier was imported yesterday.';ru='Адресный классификатор был загружен позавчера.'");
			
	ElsIf DaysDifference = 2 Then
		Presentation = NStr("en='Address classifier was imported yesterday.';ru='Адресный классификатор был загружен позавчера.'");
			
	Else
		Presentation = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Address classifier was imported %1 ago.';ru='Адресный классификатор был загружен %1 назад.'"), CommonUse.TimeIntervalAsString(EndOfPeriod, BeginOfPeriod)
		);
		
	EndIf;
	
	Result.UpdateRequired = DaysDifference > 30;
	Result.DaysAgo            = DaysDifference;
	Result.Presentation        = Presentation;
	
	Return Result;
EndFunction

// Checks if there are records about states in the AddressObjects information register and fills them in in case they are missing.
//
Procedure CheckInitialFilling() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	AddressObjects.Level
		|FROM
		|	InformationRegister.AddressObjects AS AddressObjects
		|WHERE
		|	AddressObjects.Level = 1";
	
	QueryResult = Query.Execute().Select();
	
	If Not QueryResult.Next() Then
		ExecuteInitialFilling();
	EndIf;;
	
EndProcedure


// Returns a setting of the current addresses data source.
//
// Returns:
//     String - source description. Blank string - data imported to the register is used.
//
Function AddressClassifierDataSource() Export
	
	Return GetFunctionalOption("AddressClassifierDataSource");
	
EndFunction

Procedure CalculateAddressInformationReductionsLevels()
	
	Query = New Query("
		|SELECT DISTINCT
		|	Level    AS Level,
		|	Abbr AS Abbr
		|FROM
		|	InformationRegister.AddressObjects
		|UNION
		|SELECT
		|	Level, Abbr
		|FROM
		|	InformationRegister.AddressObjectsHistory
		|");
	Variants = Query.Execute().Unload();
	
	Abbreviations = InformationRegisters.AddressInformationReductionsLevels.CreateRecordSet();
	Abbreviations.Load(Variants);
	InfobaseUpdate.WriteData(Abbreviations);
	
EndProcedure

// Read help information and information about version.
//
Function ServiceAddressData(RFTerritorialEntityCode, FileDirectory)
	
	Set = InformationRegisters.ServiceAddressData.CreateRecordSet();
	Information = Set.UnloadColumns("Type, ID, Key, Value");
	Information.Indexes.Add("Type, ID, Key");
	
	CurrentRecord = Undefined;
	ImportFile  = RFTerritorialEntityImportFile(RFTerritorialEntityCode, FileDirectory, "ADDRSTATUS", "AddressStatuses");
	
	While NextRFTerritorialEntityFileRecord(ImportFile, CurrentRecord) Do
		Record = Information.Add();
		
		Record.Type           = CurrentRecord.TYPE;
		Record.ID = CurrentRecord.ID;
		Record.Key          = CurrentRecord.KEY;
		Record.Value      = CurrentRecord.VALUE;
	EndDo;
	
	Result = New Structure("Information", Information);
	Result.Insert("Version",     ImportFile.Version);
	Result.Insert("VersionDate", ImportFile.VersionDate);
	
	CloseRFTerritorialEntityImportFile(ImportFile);
	
	Return Result;
EndFunction


// Read information about address abbreviations.
//
Function AddressAbbreviations(FileDirectory)
	
	Set = InformationRegisters.AddressInformationReductionsLevels.CreateRecordSet();
	Information = Set.UnloadColumns("Abbr, Level, Value");
	Information.Indexes.Add("Abbr, Level");
	
	CurrentRecord = Undefined;
	ImportFile  = RFTerritorialEntityImportFile(Undefined, FileDirectory, "SOCRBASE", "AddressStatuses");
	
	While NextRFTerritorialEntityFileRecord(ImportFile, CurrentRecord) Do
		If Upper(CurrentRecord.TYPE) = "SOCRBASE" AND ValueIsFilled(CurrentRecord.KEY) Then
			Record = Information.Add();
			Record.Level = CurrentRecord.ID;
			Record.Abbr      = CurrentRecord.KEY;
			Record.Value      = CurrentRecord.VALUE;
		EndIf;
	EndDo;
	
	Result = New Structure("Information", Information);
	Result.Insert("Version",     ImportFile.Version);
	Result.Insert("VersionDate", ImportFile.VersionDate);
	
	CloseRFTerritorialEntityImportFile(ImportFile);
	
	Return Result;
EndFunction


Procedure ImportAddressObjects(RFTerritorialEntityCode, FileDirectory, InformationKinds)
	
	Set = InformationRegisters.AddressObjects.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	
	ImportFile = RFTerritorialEntityImportFile(RFTerritorialEntityCode, FileDirectory, "ADDROBJ", "AddressObjects");
	
	CurrentRecord = Undefined;
	While NextRFTerritorialEntityFileRecord(ImportFile, CurrentRecord)Do
		Record = Set.Add();
		
		Record.RFTerritorialEntityCode              = CurrentRecord.REGIONCODE;
		Record.DistrictCode                  = CurrentRecord.AUTOCODE;
		Record.RegionCode                  = CurrentRecord.AREACODE;
		Record.CityCode                  = CurrentRecord.CITYCODE;
		Record.UrbanDistrictCode  = CurrentRecord.CTARCODE;
		Record.SettlementCode       = CurrentRecord.PLACECODE;
		Record.StreetCode                   = CurrentRecord.STREETCODE;
		Record.AdditionalItemCode = CurrentRecord.EXTRCODE;
		Record.SubordinateItemCode    = CurrentRecord.SEXTCODE;
		Record.Level                    = CurrentRecord.AOLEVEL;
		Record.ID              = UUIDFromBinaryData(CurrentRecord.AOGUID);
		Record.PostalIndex             = CurrentRecord.POSTALCODE;
		Record.Description               = CurrentRecord.FORMALNAME;
		Record.Abbr                 = CurrentRecord.SHORTNAME;
		Record.Additionally              = UUIDFromBinaryData(CurrentRecord.EXTRAGUID);
		Record.ARCACode                   = CurrentRecord.CODE;
		Record.Relevant                   = ?(CurrentRecord.CURRSTATUS = 0, True, False);
	EndDo;
	
	InfobaseUpdate.WriteData(Set);
	CloseRFTerritorialEntityImportFile(ImportFile);
	
EndProcedure

Procedure ImportHousesBuildingsConstructions(RFTerritorialEntityCode, FileDirectory, InformationKinds)
	
	Deflate = New Deflation(9);
	XMLTypeRow = XDTOFactory.Type("http://www.w3.org/2001/XMLSchema", "string");
	
	Set = InformationRegisters.HousesBuildingsConstructions.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	ImportFile = RFTerritorialEntityImportFile(RFTerritorialEntityCode, FileDirectory, "HOUSE", "Houses");
	
	KeyColumns = "RFTerritorialEntityCode, AddressObject, PostalIndex";
	Table = Set.UnloadColumns(KeyColumns);
	Table.Indexes.Add(KeyColumns);
	Filter = New Structure(KeyColumns);

	CurrentRecord = Undefined;
	While NextRFTerritorialEntityFileRecord(ImportFile, CurrentRecord) Do
		
		Filter.RFTerritorialEntityCode  = RFTerritorialEntityCode;
		Filter.AddressObject = UUIDFromBinaryData(CurrentRecord.AOGUID);
		Filter.PostalIndex = CurrentRecord.POSTALCODE;
		If Table.FindRows(Filter).Count() > 0 Then
			Continue;
		EndIf;
		
		Record = Set.Add();
		
		Record.RFTerritorialEntityCode  = RFTerritorialEntityCode;
		Record.AddressObject = UUIDFromBinaryData(CurrentRecord.AOGUID);
		Record.PostalIndex = CurrentRecord.POSTALCODE;
		
		XDTOBuildingsDescription =  CurrentRecord.GetXDTO("BUILDINGS");
		Record.Buildings = New ValueStorage(XDTOBuildingsDescription.LexicalValue, Deflate);
		
		FillPropertyValues(Table.Add(), Record);
	EndDo;
	
	InfobaseUpdate.WriteData(Set);
	CloseRFTerritorialEntityImportFile(ImportFile);
	
EndProcedure

Procedure ImportAdditionalInformation(RFTerritorialEntityCode, FileDirectory, InformationKinds)
	
	Set = InformationRegisters.AdditionalAddressInformation.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	ImportFile = RFTerritorialEntityImportFile(RFTerritorialEntityCode, FileDirectory, "EXTRAINFO", "AdditionalAddressInfo");
	
	CurrentRecord = Undefined;
	While NextRFTerritorialEntityFileRecord(ImportFile, CurrentRecord) Do
		Record = Set.Add();
		
		Record.RFTerritorialEntityCode    = RFTerritorialEntityCode;
		Record.ID    = UUIDFromBinaryData(CurrentRecord.EXTRAGUID);
		Record.OKATO            = CurrentRecord.OKATO;
		Record.OKTMO            = CurrentRecord.OKTMO;
		Record.IFTSIndividualCode        = CurrentRecord.IFNSFL;
		Record.IFTSLegalEntityCode        = CurrentRecord.IFNSUL;
		Record.IFTSIndividualDepartmentCode = CurrentRecord.TERRIFNSFL;
		Record.IFTSLegalEntityDepartmentCode = CurrentRecord.TERRIFNSUL;
	EndDo;
	
	InfobaseUpdate.WriteData(Set);
	CloseRFTerritorialEntityImportFile(ImportFile);
	
EndProcedure

Procedure ImportAddressObjectsHistory(RFTerritorialEntityCode, FileDirectory, InformationKinds)
	
	Set = InformationRegisters.AddressObjectsHistory.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	ImportFile = RFTerritorialEntityImportFile(RFTerritorialEntityCode, FileDirectory, "ARCHOBJ", "ArchiveObjects");
	
	CurrentRecord = Undefined;
	While NextRFTerritorialEntityFileRecord(ImportFile, CurrentRecord) Do
		
		Record = Set.Add();
		Record.Level                    = CurrentRecord.AOLEVEL;
		Record.RFTerritorialEntityCode              = CurrentRecord.REGIONCODE;
		Record.DistrictCode                  = CurrentRecord.AUTOCODE;
		Record.RegionCode                  = CurrentRecord.AREACODE;
		Record.CityCode                  = CurrentRecord.CITYCODE;
		Record.UrbanDistrictCode  = CurrentRecord.CTARCODE;
		Record.SettlementCode       = CurrentRecord.PLACECODE;
		Record.StreetCode                   = CurrentRecord.STREETCODE;
		Record.AdditionalItemCode = CurrentRecord.EXTRCODE;
		Record.SubordinateItemCode    = CurrentRecord.SEXTCODE;
		Record.ID              = UUIDFromBinaryData(CurrentRecord.AOID);
		Record.CurrentRFTerritorialEntityCode       = RFTerritorialEntityCode;
		
		Record.PostalIndex             = CurrentRecord.POSTALCODE;
		Record.Description               = CurrentRecord.FORMALNAME;
		Record.Abbr                 = CurrentRecord.SHORTNAME;
		Record.Additionally              = UUIDFromBinaryData(CurrentRecord.EXTRAGUID);
		Record.ARCACode                   = CurrentRecord.CODE;
		Record.AddressObject             = UUIDFromBinaryData(CurrentRecord.AOGUID);
		Record.RecordActionBegin       = CurrentRecord.STARTDATE;
		Record.RecordActionEnd    = CurrentRecord.ENDDATE;
		Record.Operation                   = CurrentRecord.OPERSTATUS
	EndDo;
	
	InfobaseUpdate.WriteData(Set);
	CloseRFTerritorialEntityImportFile(ImportFile);
	
EndProcedure

Procedure ImportAddressChangeReasons(RFTerritorialEntityCode, FileDirectory, InformationKinds)
	
	Deflate = New Deflation(9);
	
	Set = InformationRegisters.AddressInformationChangingReasons.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	ImportFile = RFTerritorialEntityImportFile(RFTerritorialEntityCode, FileDirectory, "ARCHDOCS", "RegulatoryDocs");
	
	CurrentRecord = Undefined; 
	While NextRFTerritorialEntityFileRecord(ImportFile, CurrentRecord) Do
		Record = Set.Add();
		
		Record.RFTerritorialEntityCode    = RFTerritorialEntityCode;
		Record.ID    = UUIDFromBinaryData(CurrentRecord.DOCID);
		Record.ModifiedObject = UUIDFromBinaryData(CurrentRecord.OBJID);
		Record.ContainsDescription = CurrentRecord.ISDESCR;
		Record.Definition         = New ValueStorage(CurrentRecord.DESCR, Deflate);
	EndDo;
	
	InfobaseUpdate.WriteData(Set);
	CloseRFTerritorialEntityImportFile(ImportFile);
	
EndProcedure

Procedure ImportAddressLandmarks(RFTerritorialEntityCode, FileDirectory, InformationKinds)
	
	Deflate = New Deflation(9);
	
	Set = InformationRegisters.AddressObjectsLandmarks.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	ImportFile = RFTerritorialEntityImportFile(RFTerritorialEntityCode, FileDirectory, "LANDMARKS", "Landmarks");
	
	CurrentRecord = Undefined;
	While NextRFTerritorialEntityFileRecord(ImportFile, CurrentRecord) Do
		Record = Set.Add();
		
		Record.RFTerritorialEntityCode  = RFTerritorialEntityCode;
		Record.ID  = UUIDFromBinaryData(CurrentRecord.LANDGUID);
		Record.AddressObject = UUIDFromBinaryData(CurrentRecord.AOGUID);
		Record.PostalIndex = CurrentRecord.POSTALCODE;
		Record.Additionally  = UUIDFromBinaryData(CurrentRecord.EXTRAGUID);
		Record.Definition       = New ValueStorage(CurrentRecord.LOCATION, Deflate);
	EndDo;
	
	InfobaseUpdate.WriteData(Set);
	CloseRFTerritorialEntityImportFile(ImportFile);
	
EndProcedure

Procedure SetInformationAboutVersionImport(RFTerritorialEntityCode, Version, VersionDate, ImportDate)
	
	Set = InformationRegisters.AddressInformationExportedVersions.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	
	MainRecord = Set.Add();
	MainRecord.RFTerritorialEntityCode = RFTerritorialEntityCode;
	MainRecord.Version        = Version;
	MainRecord.VersionDate    = VersionDate;
	MainRecord.ImportDate  = ImportDate;
	
	InfobaseUpdate.WriteData(Set);
	
EndProcedure

Function InformationAboutVersionImport(RFTerritorialEntityCode)
	
	BlankDate = Date(1, 1, 1, 0, 0, 0);
	InformationAboutImport = New Structure("Version, VersionDate, ImportDate", 0, BlankDate, BlankDate);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	AddressInformationExportedVersions.Version,
		|	AddressInformationExportedVersions.VersionDate,
		|	AddressInformationExportedVersions.ImportDate
		|FROM
		|	InformationRegister.AddressInformationExportedVersions AS AddressInformationExportedVersions
		|WHERE
		|	AddressInformationExportedVersions.RFTerritorialEntityCode = &RFTerritorialEntityCode";
	
	Query.SetParameter("RFTerritorialEntityCode", RFTerritorialEntityCode);
	Result = Query.Execute().Unload();
	If Result.Count() > 0 Then
		TypeDescriptionNumber = New TypeDescription("Number");
		InformationAboutImport.Version = TypeDescriptionNumber.AdjustValue(Result[0].Version);
		InformationAboutImport.VersionDate = Result[0].VersionDate;
		InformationAboutImport.ImportDate = Result[0].ImportDate;
	EndIf;
	Return InformationAboutImport;

EndFunction

Procedure ResetInformationAboutVersionImport(RFTerritorialEntityCode)
	
	Set = InformationRegisters.AddressInformationExportedVersions.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	InfobaseUpdate.WriteData(Set);
	
EndProcedure

Procedure ClearAddressObjects(RFTerritorialEntityCode)
	// Clear ignoring the record of a state.
	
	Set = InformationRegisters.AddressObjects.CreateRecordSet();
	Filter = Set.Filter;
	
	Filter.Level.Set(1);
	Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	Filter.DistrictCode.Set(0);
	Filter.RegionCode.Set(0);
	Filter.CityCode.Set(0);
	Filter.UrbanDistrictCode.Set(0);
	Filter.SettlementCode.Set(0);
	Filter.StreetCode.Set(0);
	Filter.AdditionalItemCode.Set(0);
	Filter.SubordinateItemCode.Set(0);
	Set.Read();
	
	Filter.Reset();
	Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	InfobaseUpdate.WriteData(Set);
	
EndProcedure

Procedure ClearHousesBuildingsConstructions(RFTerritorialEntityCode)
	
	Set = InformationRegisters.HousesBuildingsConstructions.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	InfobaseUpdate.WriteData(Set);
	
EndProcedure

Procedure ClearAdditionalInformation(RFTerritorialEntityCode)
	
	Set = InformationRegisters.AdditionalAddressInformation.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	InfobaseUpdate.WriteData(Set);

EndProcedure

Procedure ClearAddressObjectsHistory(RFTerritorialEntityCode)
	
	Set = InformationRegisters.AddressObjectsHistory.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	InfobaseUpdate.WriteData(Set);
	
EndProcedure

Procedure ClearAddressChangeReasons(RFTerritorialEntityCode)
	
	Set = InformationRegisters.AddressInformationChangingReasons.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	InfobaseUpdate.WriteData(Set);
	
EndProcedure

Procedure ClearAddressLandmarks(RFTerritorialEntityCode)
	
	Set = InformationRegisters.AddressObjectsLandmarks.CreateRecordSet();
	Set.Filter.RFTerritorialEntityCode.Set(RFTerritorialEntityCode);
	InfobaseUpdate.WriteData(Set);
	
EndProcedure

Procedure ClearOutdatedClassifierInformation(RFTerritorialEntityCode)
	
	Query = New Query("
		|SELECT TOP 1
		|	AddressPointType,
		|	InCodeAddressObjectCode,
		|	InCodeRegionCode,
		|	CityCodeInsideCode,
		|	PlaceCodeInsideCode,
		|	StreetCodeInsideCode,
		|	Code,
		|	Description,
		|	Abbr,
		|	IndexOf,
		|	AlternativeNames,
		|	ActualitySign
		|FROM
		|	InformationRegister.DeleteAddressClassifier
		|WHERE
		|	AddressPointType = 1
		|	AND InCodeAddressObjectCode = &RFTerritorialEntityCode
		|");
	Query.SetParameter("RFTerritorialEntityCode", RFTerritorialEntityCode);
	State = Query.Execute().Unload();
	
	Set = InformationRegisters.DeleteAddressClassifier.CreateRecordSet();
	Set.Filter.InCodeAddressObjectCode.Set(RFTerritorialEntityCode);
	
	If State.Count() > 0 Then
		FillPropertyValues(Set.Add(), State[0]);
	EndIf;
	
	InfobaseUpdate.WriteData(Set);
	
EndProcedure

// Initializes the description structure of the address information data file.
//
Function RFTerritorialEntityImportFile(RFTerritorialEntityCode, FileDirectory, KindKey, DescribingNodeName)
	
	If RFTerritorialEntityCode = Undefined Then
		SourceFileName = KindKey;
	Else
		SourceFileName = Format(RFTerritorialEntityCode, "ND=2; NZ=; NLZ=") + "_" + KindKey;
	EndIf;
	
	Result = New Structure;
	
	// As archive
	File = FindFile(FileDirectory, SourceFileName + ".ZIP");
	If File.Exist Then
		TemporaryDirectory = CommonUseClientServer.AddFinalPathSeparator( GetTempFileName() );
		
		ZipFileReader = New ZipFileReader(File.FullName);
		Item = ZipFileReader.Items[0];
		ZipFileReader.Extract(Item, TemporaryDirectory);
		
		Result.Insert("Path",      TemporaryDirectory);
		Result.Insert("FullName", TemporaryDirectory + Item.FullName);
		Result.Insert("DeletePathOnClose", True);
	Else
		// As a usual file
		Result.Insert("Path",      FileDirectory);
		Result.Insert("DeletePathOnClose", False);
		Result.Insert("FullName", FileDirectory + SourceFileName + ".FI");
	EndIf;
	
	// Title type
	TitleProperty = XDTOFactory.packages.Get(TargetNamespace()).RootProperties.Get(DescribingNodeName);
	XDTOTitleType  = TitleProperty.Type;
	
	// Record type
	Title = XDTOFactory.Create(XDTOTitleType);
	XDTORecordType = Undefined;
	For Each Property In XDTOTitleType.Properties Do
		If Title.GetList(Property.LocalName) <> Undefined Then
			XDTORecordType = Property.Type;
			Break;
		EndIf;
	EndDo;
	
	If XDTORecordType = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='The list of records in the %2 type is not found in the %1 file.';ru='В файле ""%1"" не найден список записей в типе %2'"), Result.FullName, Result.XDTOType
		);
	EndIf;
	
	Result.Insert("XDTOType",       XDTOTitleType);
	Result.Insert("XDTORecordType", XDTORecordType);
	
	Result.Insert("Version");
	Result.Insert("VersionDate");
	Result.Insert("ReadingFile", New FastInfosetReader);
	
	ReadingFile = Result.ReadingFile;
	ReadingFile.OpenFile(Result.FullName);
	
	// Go to the first node with data.
	RootFound = ReadingFile.MoveToContent() <> XMLNodeType.None;
	While RootFound Do
		If ReadingFile.NodeType = XMLNodeType.StartElement AND ReadingFile.LocalName = DescribingNodeName Then
			// Inaccurate reading with typing.
			Result.Version     = TypedAttributeXDTO(ReadingFile, XDTOTitleType, "Version");
			Result.VersionDate = TypedAttributeXDTO(ReadingFile, XDTOTitleType, "UpdateDate");
			Break;
		EndIf;
		RootFound = ReadingFile.Read();
	EndDo;
	
	If RootFound Then
		// Position yourself to the next node.
		ReadingFile.Read();
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Root node %2 is not found in %1 file';ru='В файле ""%1"" не найден корневой узел %2'"), Result.FullName, DescribingNodeName
		);
	EndIf;
	
	Result.Insert("RFTerritorialEntityCode", RFTerritorialEntityCode);
	Result.Insert("KindKey",      KindKey);
	
	Return Result;
EndFunction

// Search the first file by a mask ignoring the register (features of an operating system).
//
// Parameters:
//     Directory         - String - directory where the file is being searched.
//     FileNameMask - String - name of the search file.
//
// Returns:
//     Structure - description of a found file. Contains fields:
//         * Exists       - Boolean - check box showing that the specified file exists.
//         * Name              - String - characteristics of a found file, see description of the File type.
//         * NameWithoutExtension - String - characteristics of a found file, see description of the File type.
//         * FullName        - String - characteristics of a found file, see description of the File type.
//         * Path             - String - characteristics of a found file, see description of the File type.
//         * Extension       - String - characteristics of a found file, see description of the File type.
//
Function FindFile(Directory, FileNameMask)
	
	SystemInfo = New SystemInfo;
	Platform = SystemInfo.PlatformType;
	
	IgnoreRegister = Platform = PlatformType.Windows_x86 Or Platform = PlatformType.Windows_x86_64;
	
	If IgnoreRegister Then
		Mask = Upper(FileNameMask);
	Else
		Mask = "";
		For Position = 1 To StrLen(FileNameMask) Do
			Char = Mid(FileNameMask, Position, 1);
			TopRegister = Upper(Char);
			LowerRegister  = Lower(Char);
			If TopRegister = LowerRegister Then
				Mask = Mask + Char;
			Else
				Mask = Mask + "[" + TopRegister + LowerRegister + "]";
			EndIf;
		EndDo;
	EndIf;
	
	Result = New Structure("Exist, Name, NameWithoutExtension, FullName, Path, Extension", False); 
	Variants = FindFiles(Directory, Mask);
	If Variants.Count() > 0 Then 
		Result.Exist = True;
		FillPropertyValues(Result, Variants[0]);
	EndIf;
	
	Return Result;
EndFunction

Function TypedAttributeXDTO(ReadingFile, RecordType, AttributeName)
	
	AttributeType  = RecordType.Properties.Get(AttributeName).Type;
	XDTODataValue = XDTOFactory.Create(AttributeType, ReadingFile.GetAttribute(AttributeName));
	
	Return XDTODataValue.Value;
EndFunction

// Completes work with the data set.
//
Procedure CloseRFTerritorialEntityImportFile(FileDescription)
	
	FileDescription.ReadingFile.Close();
	FileDescription.ReadingFile = Undefined;
	
	If FileDescription.DeletePathOnClose Then
		DeleteTemporaryFile(FileDescription.Path);
	EndIf;
	
EndProcedure

// Reads the next record 
//
Function NextRFTerritorialEntityFileRecord(ImportFile, CurrentRecord) 
	Read = ImportFile.ReadingFile;
	
	If Read.NodeType <> XMLNodeType.StartElement Then
		CurrentRecord = Undefined;
		Return False;
	EndIf;
	
	CurrentRecord = XDTOFactory.ReadXML(Read, ImportFile.XDTORecordType);
	Return True;
EndFunction

// Opposition CommonUseClientServer.URIStructure
//
Function URIByStructure(URLStructure)
	Result = "";
	
	// Protocol
	If Not IsBlankString(URLStructure.Schema) Then
		Result = Result + URLStructure.Schema + "://";
	EndIf;
	
	// Authorization
	If Not IsBlankString(URLStructure.Login) Then
		Result = Result + URLStructure.Login + ":" + URLStructure.Password + "@";
	EndIf;
		
	// The rest
	Result = Result + URLStructure.Host;
	If Not IsBlankString(URLStructure.Port) Then
		Result = Result + ":" + ?(TypeOf(URLStructure.Port) = Type("Number"), Format(URLStructure.Port, ""), URLStructure.Port);
	EndIf;
	
	Result = Result + "/" + URLStructure.PathAtServer;
	Return Result;
	
EndFunction

// Port lookup to the import address for security profiles.
//
Function InternetAddressIncludingPort(Address)
	
	Result = New Structure;
	
	AddressContent = CommonUseClientServer.URLStructure(Address);
	If IsBlankString(AddressContent.Port) Then
		Protocol = Upper(AddressContent.Schema);
		If Protocol = "HTTP" Then
			AddressContent.Port = 80;
		ElsIf Protocol = "HTTPS" Then
			AddressContent.Port = 443;
		EndIf;
		
		Result.Insert("Address", URIByStructure(AddressContent) );
	Else
		Result.Insert("Address", Address);
	EndIf;
	
	FileName = AddressContent.PathAtServer;
	ParameterPosition = Find(FileName, "?");
	If ParameterPosition > 0 Then
		FileName = Left(FileName, ParameterPosition - 1);
	EndIf;
	FileName = StrReplace(FileName, Chars.LF, "");
	FileName = StrReplace(FileName, "/", Chars.LF);
	FileName = StrReplace(FileName, "\", Chars.LF);
	
	Result.Insert("FileName", TrimAll(StrGetLine(FileName, StrLineCount(FileName))));
	Return Result;
EndFunction

//  Name of the event for writing to the events log monitor.
//
Function EventLogMonitorEvent() 
	
	Return AddressClassifierClientServer.EventLogMonitorEvent();
	
EndFunction

// Deletes a temporary file. 
// If an error occurs during the deletion attempt, it is ignored - file will be deleted later.
//
Procedure DeleteTemporaryFile(FullFileName) Export
	
	If IsBlankString(FullFileName) Then
		Return;
	EndIf;
		
	Try
		DeleteFiles(FullFileName)
	Except
		WriteLogEvent(EventLogMonitorEvent(), EventLogLevel.Warning,
			,, StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Unable to delete a temporary
				|file %1 as: %2';ru='Unable to delete a temporary
				|file %1 as: %2'"), FullFileName, DetailErrorDescription(ErrorInfo())));
	EndTry
	
EndProcedure
#EndRegion

#EndRegion