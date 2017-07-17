////////////////////////////////////////////////////////////////////////////////////////////////////
// The Contact information subsystem.
// 
////////////////////////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Returns enumeration value type of the contact information kind.
//
//  Parameters:
//    InformationKind - CatalogRef.ContactInformationTypes, Structure - data source.
//
Function TypeKindContactInformation(Val InformationKind) Export
	Result = Undefined;
	
	Type = TypeOf(InformationKind);
	If Type = Type("EnumRef.ContactInformationTypes") Then
		Result = InformationKind;
	ElsIf Type = Type("CatalogRef.ContactInformationKinds") Then
		Result = InformationKind.Type;
	ElsIf InformationKind <> Undefined Then
		Data = New Structure("Type");
		FillPropertyValues(Data, InformationKind);
		Result = Data.Type;
	EndIf;
	
	Return Result;
EndFunction

// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  Handlers - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      * Presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	// Import to countries classifier is denied.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.WorldCountries.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
EndProcedure

// Define metadata objects in the managers modules of which
// the ability to edit attributes is restricted using the GetLockedOjectAttributes export function.
//
// Parameters:
//   Objects - Map - specify the full name of the metadata
//                            object as a key connected to the Deny editing objects attributes subsystem. 
//                            As a value - empty row.
//
Procedure OnDetermineObjectsWithLockedAttributes(Objects) Export
	
	Objects.Insert(Metadata.Catalogs.ContactInformationKinds.FullName(), "");
	
EndProcedure

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.ContactInformationKinds.FullName(), "NotEditableInGroupProcessingAttributes");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region InfobaseUpdate

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable
//                                  function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	// Countries of the world separation
	If CommonUseReUse.DataSeparationEnabled() Then
		Handler = Handlers.Add();
		Handler.Version    = "2.1.4.8";
		Handler.Procedure = "ContactInformationManagementService.SeparatedCountriesReferencePreparation";
		Handler.ExclusiveMode = True;
		Handler.SharedData      = True;
		
		Handler = Handlers.Add();
		Handler.Version    = "2.1.4.8";
		Handler.Procedure = "ContactInformationManagementService.UpdateBySeparatedCountriesReference";
		Handler.ExclusiveMode = True;
		Handler.SharedData      = False;
	EndIf;
	
	Handler = Handlers.Add();
	Handler.Version    = "2.2.3.34";
	Handler.Procedure = "ContactInformationManagementService.UpdateExistingCountries";
	Handler.PerformModes = "Exclusive";
	Handler.SharedData      = False;
	Handler.InitialFilling = True;
	
EndProcedure

// Undivided exclusive handler helps to copy countries from the null area.
// Saves a reference and data areas list - recipients.
//
Procedure PreparationStandardDividedCountriesOfWorld() Export
	
	// Base version control
	ModelRegisterName = "DeleteWorldCountries";
	If Metadata.InformationRegisters.Find(ModelRegisterName) = Undefined Then
		Return;
	EndIf;
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Request for data from the null area, create a reference accurate to reference.
	CommonUse.SetSessionSeparation(True, 0);
	Query = New Query("
		|SELECT 
		|	Catalog.Ref             AS Ref,
		|	Catalog.Code                AS Code,
		|	Catalog.Description       AS Description,
		|	Catalog.AlphaCode2          AS AlphaCode2,
		|	Catalog.AlphaCode3          AS AlphaCode3, 
		|	Catalog.DescriptionFull AS DescriptionFull
		|FROM
		|	Catalog.WorldCountries AS Catalog
		|");
	Prototype = Query.Execute().Unload();
	
	CommonUse.SetSessionSeparation(False);
	
	// Write reference
	Set = InformationRegisters[ModelRegisterName].CreateRecordSet();
	Set.Add().Value = New ValueStorage(Prototype, New Deflation(9));
	InfobaseUpdate.WriteData(Set);
	
EndProcedure

// Separated  handler to copy countries from the null area.
// Use the reference prepared in the previous step.
//
Procedure RefreshEnabledMatchesSeparatedByCountries() Export
	
	// Base version control
	ModelRegisterName = "DeleteWorldCountries";
	If Metadata.InformationRegisters.Find(ModelRegisterName) = Undefined Then
		Return;
	EndIf;
	
	// Find reference for the current area.
	Query = New Query("
		|SELECT
		|	Prototype.Value
		|FROM
		|	InformationRegister.DeleteWorldCountries AS Prototype
		|WHERE
		|	Prototype.DataArea = 0
		|");
	Result = Query.Execute().Select();
	If Not Result.Next() Then
		Return;
	EndIf;
	Prototype = Result.Value.Get();
	
	Query = New Query("
		|SELECT
		|	Data.Ref             AS Ref,
		|	Data.Code                AS Code,
		|	Data.Description       AS Description,
		|	Data.AlphaCode2          AS AlphaCode2,
		|	Data.AlphaCode3          AS AlphaCode3, 
		|	Data.DescriptionFull AS DescriptionFull
		|INTO
		|	Prototype
		|FROM
		|	&Data AS Data
		|INDEX BY
		|	Ref
		|;///////////////////////////////////////////////////////////////////
		|SELECT 
		|	Prototype.Ref             AS Ref,
		|	Prototype.Code                AS Code,
		|	Prototype.Description       AS Description,
		|	Prototype.AlphaCode2          AS AlphaCode2,
		|	Prototype.AlphaCode3          AS AlphaCode3, 
		|	Prototype.DescriptionFull AS DescriptionFull
		|FROM
		|	Prototype AS Prototype
		|LEFT JOIN
		|	Catalog.WorldCountries AS WorldCountries
		|ON
		|	WorldCountries.Ref = Prototype.Ref
		|WHERE
		|	WorldCountries.Ref IS NULL
		|");
	Query.SetParameter("Data", Prototype);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Country = Catalogs.WorldCountries.CreateItem();
		Country.SetNewObjectRef(Selection.Ref);
		FillPropertyValues(Country, Selection, , "Ref");
		InfobaseUpdate.WriteData(Country);
	EndDo;
	
EndProcedure

// Compulsorily import all countries from the classifier.
//
Procedure ImportWorldCountries() Export
	Catalogs.WorldCountries.UpdateWorldCountriesByClassifier(True);
EndProcedure

// Update only existing items of countries by a classifier.
Procedure UpdateExistingCountries() Export
	
	Catalogs.WorldCountries.UpdateWorldCountriesByClassifier();
	
EndProcedure

#EndRegion

#Region InteractionWithAddressClassifier

// Returns a list of all states of an address classifier.
//
// Returns:
//   ValueTable - contains columns.:
//      * RFTerritorialEntityCode - Number                   - State code.
//      * Identifier - UUID - State identifier.
//      * Presentation - String                  - State description and abbreviation.
//      * Imported     - Boolean                  - True if the classifier by this state is imported.
//      * VersionDate    - Date                    - UTC version of the imported data.
//   Undefined    - if there is no subsystem of an address classifier.
// 
Function AllStates() Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
		Return ModuleAddressClassifierService.InformationAboutRFTerritorialEntitiesImport();
	EndIf;
	Return Undefined;
	
EndFunction

//  Returns state name by its code.
//
//  Parameters:
//      Code - String, Number - state code.
//
// Returns:
//      String - full name of state with abbreviation.
//      Undefined - if there is no subsystem of address classifier.
// 
Function StateOfCode(Val Code)
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		Return AddressClassifierModule.StateNameByCode(Code);
	EndIf;
	
	Return Undefined;
	
EndFunction

//  Returns a state code by its full name.
//
//  Parameters:
//      StateDescription - String - full name of state with abbreviation.
//
// Returns:
//      String - state code of two digits. An empty row if it was impossible to define the name.
//      Undefined - if there is no subsystem of address classifier.
// 
Function StateCode(Val FullDescr)
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		Code = AddressClassifierModule.StateCodeByName(FullDescr);
		Return Format(Code, "ND=2; NZ=; NLZ=");
	EndIf;
	
	Return Undefined;
	
EndFunction

//  Returns address by presentation.
//
//  Parameters:
//      Text                      - String - autopick text.
//      HideObsoleteAddresses - Boolean - check box showing that non-actual addresses should not be included in the auto pick.
//      SelectRows              - Number  - restriction to results quantity.
//      RefiningStreet            - String - specific presentation of the street.
Function SettlementsOnPresentation(Val Text, Val HideObsoleteAddresses = False, Val SelectRows = 50, Val RefiningStreet = "") Export
	
	Result = New ValueList;
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		DataAnalysis = PartsOfAddressTable(Text);
		If DataAnalysis.Count() = 0 Then
			Return Result;
		EndIf;
		TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
		AddressRF = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "AddressRF"));
		ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
		AddressByLevels = ModuleAddressClassifierService.SetMatchAddressPartsToTheirLevelForLocality(DataAnalysis, AddressObjectsLevels("Settlement"));
		If AddressByLevels <> Undefined Then
			PlaceAddressToXDTO(AddressRF, AddressByLevels);
		EndIf;
		
		// If something is left, add it to the locality level.
		Filter = New Structure("Level", 0);
		RowsWithLevel0 = AddressByLevels.FindRows(Filter);
		Delimiter = "";
		Settlement = "";
		For Each ItemOfAddress In RowsWithLevel0 Do
			Settlement = Settlement + Delimiter + ItemOfAddress.Value;
			Delimiter = ", ";
		EndDo;
		If Not IsBlankString(Settlement) Then 
			Settlement = Settlement + ?(ValueIsFilled(AddressRF.Settlement), ", " +AddressRF.Settlement, "");
			InstallPropertyByXPath(AddressRF, "Settlement", Settlement);
		EndIf;
			
		Return AddressRF;
	EndIf;
	
	Return Undefined;
	
EndFunction

//  Returns the structure with the SelectionData field containing a
// list of localities variants by the junior-senior hierarchical presentation.
//
//  Parameters:
//      SettlementIdentifier - UUID - classifier code for selection restriction.
//      Text                          - Text  - autopick row.
//      HideObsoleteAddresses     - Boolean - check box showing that non-actual addresses should not be included in the auto pick.
//      SelectRows                  - Number  - restriction to results quantity.
//
// Returns:
//      Structure - data search result. Contains fields:
//         * TooMuchData - Boolean - shows that a result list is not full.
//         * SelectionData       - ValueList - data  for autopick.
//
Function StreetsReporting(SettlementIdentifier, Text, HideObsoleteAddresses = False, SelectRows = 50) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		PartsAddresses = PartsOfAddressTable(Text);
		If PartsAddresses.Count() = 0 Then
			Return Undefined;
		EndIf;
		
		ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
		ModuleAddressClassifierService.SetStreetLevelsByAddressParts(SettlementIdentifier, PartsAddresses);
		Return PartsAddresses;
	EndIf;
	
	Return Undefined;
	
EndFunction

//  Returns the classifier identifier for the object provided in the fields.
//
//  Parameters:
//      PartsAddresses          - Structure - description of address parts.
//      HideObsolete - Boolean - check box of hiding actual.
//
// Returns:
//      UUID - classifier identifier.
//
Function SettlementIdentifierByAddressParts(PartsAddresses) Export
	
	// Try to take from the address part.
	Result = ContactInformationManagementClientServer.ItemIdentifierByAddressParts(PartsAddresses);
	If Result <> Undefined Then
		Return Result;
	EndIf;
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Return Undefined;
	EndIf;
	
	// Query to classifier about identifier.
	AddressXDTO = XDTOFactory.Create(XDTOFactory.Type("http://www.v8.1c.ru/ssl/contactinfo", "AddressRF"));
	For Each KeyValue In PartsAddresses Do
		part = KeyValue.Value;
		SetXDTOObjectAttribute(AddressXDTO, part.PathXPath, part.Presentation);
	EndDo;
	
	Variants = New Array;
	Variants.Add(New Structure("Address, AddressFormat", AddressXDTO, "FIAS"));
	
	ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
	DataStructure = ModuleAddressClassifierService.AddressesCheckResultByClassifier(Variants);
	
	If Not DataStructure.Cancel Then
		For Each Item In DataStructure.Data Do
			Variants = Item.Variants;
			If Variants.Count() > 0 Then
				Return Variants[0].ID;
			EndIf;
		EndDo;
	EndIf;
	
	// Does not correspond to the classifier, or the classifier is under maintenance.
	Return Undefined;
EndFunction

//  Returns a structure describing a locality in
//  the junior-senior hierarchy for the current address classifier. Structure keys names depend
// on the classifier.
// 
//  Parameters:
//      ID - UUID - Object identifier. If it is not
// specified, then the structure is filled in with the data for this object.
//      ClassifierVariant                   - String - Required classifier kind. 
// 
// Returns:
//      Structure - description of a locality.
//
Function AttributesListSettlement(ID = Undefined, ClassifierVariant = "AC") Export
	
	Result = ContactInformationManagementClientServer.LocalityAddressPartsStructure();
	
	If ID = Undefined Then
		Return Result;
	EndIf;
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Return Undefined;
	EndIf;
	
	// Fill data by identifier.
	ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
	DataStructure = ModuleAddressClassifierService.ActualAddressInformation(ID);
	
	If Not DataStructure.Cancel Then
		Address = DataStructure.Data;
		For Each KeyValue In Result Do
			part = KeyValue.Value;
			part.Presentation = TrimAll(GetXDTOObjectAttribute(Address, part.PathXPath));
			DescriptionAbbreviation = ContactInformationManagementClientServer.DescriptionAbbreviation(part.Presentation);
			part.Description = DescriptionAbbreviation.Description;
			part.Abbr = DescriptionAbbreviation.Abbr;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

//  Returns a structure describing a locality in
//  the junior-senior hierarchy for the current address classifier. Structure keys names depend
// on the classifier.
// 
//  Parameters:
//      ID - UUID - Object identifier. If it is not
// specified, then the structure is filled in with the data for this object.
//      ClassifierVariant                   - String - Required classifier kind. 
// 
// Returns:
//      Structure - description of a locality.
//
Function StreetAttributesList(ID = Undefined, ClassifierVariant = "AC") Export
	
	Result = ContactInformationManagementClientServer.LocalityAddressPartsStructure();
	
	If ID = Undefined Then
		Return Result;
	EndIf;
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Return Undefined;
	EndIf;
	
	// Fill data by identifier.
	ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
	DataStructure = ModuleAddressClassifierService.ActualAddressInformation(ID);
	
	If Not DataStructure.Cancel Then
		Address = DataStructure.Data;
		For Each KeyValue In Result Do
			part = KeyValue.Value;
			part.Presentation = TrimAll(GetXDTOObjectAttribute(Address, part.PathXPath));
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

//  Sets values of a locality to XDTO address.
//  
//  Parameters:
//      XDTOAddress    - XDTODataObject - address RF.
//      ID - UUID - Data source for filling in.
//
Procedure SetAddressLocalityOnIdidentifier(XDTOAddress, ID) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Return;
	EndIf;
	
	ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
	DataAddresses = ModuleAddressClassifierService.ActualAddressInformation(ID);
	If DataAddresses.Cancel Then
		// Classifier is broken
		Return;
	EndIf;
	
	Prototype = DataAddresses.Data;
	
	PartsAddresses = ContactInformationManagementClientServer.LocalityAddressPartsStructure();
	For Each KeyValue In PartsAddresses Do
		If KeyValue.Value.Level < 7 Then
			Path = KeyValue.Value.PathXPath;
			SetXDTOObjectAttribute(XDTOAddress, Path, GetXDTOObjectAttribute(Prototype, Path));
		EndIf;
	EndDo;
	
EndProcedure

// Sets values of street fields.
//  
//  Parameters:
//      XDTOAddress    - XDTODataObject - address RF.
//      ID - UUID - Data source for filling in.
//
Procedure SetAddressStreetByIdentifier(XDTOAddress, ID) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Return;
	EndIf;
	
	ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
	DataAddresses = ModuleAddressClassifierService.ActualAddressInformation(ID);
	If DataAddresses.Cancel Then
		// Classifier is broken
		Return;
	EndIf;
	
	Prototype = DataAddresses.Data;
	
	PartsAddresses = ContactInformationManagementClientServer.LocalityAddressPartsStructure();
	For Each KeyValue In PartsAddresses Do
		If KeyValue.Value.Level > 6 Then
			Path = KeyValue.Value.PathXPath;
			SetXDTOObjectAttribute(XDTOAddress, Path, GetXDTOObjectAttribute(Prototype, Path));
		EndIf;
	EndDo;
	
EndProcedure

// Sets values of identifiers for address parts.
//  
//  Parameters:
//      AddressIdentifier - UUID - Data source for filling in.
//      SettlementInDetail  - Structure - address parts.
//
Procedure FillAddressPartsIDs(SettlementInDetail) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
		ModuleAddressClassifierService.SetAddressPartsIDs(SettlementInDetail);
	EndIf;
	
EndProcedure

Procedure FillSettlementIdentifiers(SettlementInDetail, SettlementIdentifier = Undefined) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
		ModuleAddressClassifierService.SetSettlementIdentifiers(SettlementInDetail, SettlementIdentifier);
	EndIf;
	
EndProcedure

// Define work mode of output forms.
// 
// Returns:
//     Boolean - True if you are working with the classifier using the web service.
//
Function ClassifierAvailableThroughWebService() Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Return False;
	EndIf;
	
	ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
	Source = ModuleAddressClassifierService.AddressClassifierDataSource();
	
	Return Not IsBlankString(Source);
EndFunction

// Check vendor availability - local base or service. Version query.
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
Function ClassifierDataProviderVersion() Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
		Return ModuleAddressClassifierService.DataProviderVersion();
	EndIf;
	
	Result = ErrorStructureAddressClassifierProvider();
	Result.Insert("Version");
	Return Result;
	
EndFunction

Procedure CheckClassifierAvailability(AddressClassifierEnabled) Export
	
	PutToTempStorage(ClassifierDataProviderVersion(), AddressClassifierEnabled);
	
EndProcedure	

Function CheckAddressInXML(AddressInXML, AddressCheckParameters = Undefined) Export
	
	CheckResult = New Structure("Result, ErrorsList");
	CheckResult.ErrorList = New ValueList;
	
	If Not ItIsXMLString(AddressInXML) Then
		CheckResult.Result = "ContainsErrors";
		CheckResult.ErrorList.Add("AddressFormat", NStr("en='Invalid address format';ru='Некорректный формат адреса'"));
		Return CheckResult;
	EndIf;
	
	Source = XMLBXDTOAddress(AddressInXML,, Enums.ContactInformationTypes.Address);
	HasErrors = False;
	
	AddressFormat = "AC";
	DomesticAddressOnly = True;
	If TypeOf(AddressCheckParameters) = Type("CatalogRef.ContactInformationKinds") Then
		CheckParameters = StructureTypeContactInformation(AddressCheckParameters);
		AddressFormat = "AC";
		DomesticAddressOnly = CheckParameters.DomesticAddressOnly;
	Else 
		CheckParameters = StructureTypeContactInformation();
		If AddressCheckParameters <> Undefined Then
			If AddressCheckParameters.Property("AddressFormat") AND ValueIsFilled(AddressCheckParameters.AddressFormat) Then
				AddressFormat = AddressCheckParameters.AddressFormat;
			EndIf;
			If AddressCheckParameters.Property("DomesticAddressOnly") AND ValueIsFilled(AddressCheckParameters.DomesticAddressOnly) Then
				DomesticAddressOnly = AddressCheckParameters.DomesticAddressOnly;
			EndIf;
		EndIf;
		CheckParameters.CheckValidity = True;
		CheckParameters.ProhibitInvalidEntry = True;
	EndIf;
	
	CheckParameters.Insert("AddressFormat", AddressFormat);
	CheckParameters.Insert("DomesticAddressOnly ", DomesticAddressOnly);
	
	Address = Source.Content;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	If Address <> Undefined AND Address.Type() = XDTOFactory.Type(TargetNamespace, "Address") Then
		ErrorList = AddressFillingErrorsXDTO(Address, CheckParameters);
	EndIf;
	
	If ErrorList.Count() = 0 Then
		CheckResult.Result = "Correct";
	Else
		If Not ErrorList[0].Check Then
			CheckResult.Result = "NotChecked";
		Else
			CheckResult.Result = "ContainsErrors";
		EndIf;
	EndIf;
	
	CheckResult.ErrorList = ErrorList;
	Return CheckResult;
	
EndFunction

// Returns classifier data by the postal code.
//
// Parameters:
//     IndexOf - String, Number - postal code for which it is required to receive data.
//
//     AdditionalParameters - Structure - Describes search settings. Consists from optional fields:
//         * HideObsolete - Boolean - Check box of removing from selection of nonactual addresses. False by default.
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
//                                           ** Outdated    - Boolean - Check box showing that data row is outdated.
//                                           ** Identifier - UUID - Classifier code to
//                                                                                        search variants by index.
//                                           ** Presentation - String - Variant presentation.
//
Function ClassifierAddressesByPostcode(Val IndexOf, Val AdditionalParameters) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		
		NumberType = New TypeDescription("Number");
		IndexNumber = NumberType.AdjustValue(IndexOf);
		
		ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
		Return ModuleAddressClassifierService.AddressesByClassifierPostalCode(IndexNumber, AdditionalParameters);
		
	EndIf;
	
	Result = ErrorStructureAddressClassifierProvider();
	Result.Insert("Data", New ValueTable);
	Return Result;
	
EndFunction

// Returns classifier data of a selection field by a level.
//
// Parameters:
//     Parent                - UUID - Parent object.
//     Level                 - Number                   - Required data level. 1-7, 90, 91 - address objects, -1
//                                                         - landmarks.
//     AdditionalParameters - Structure               - Description to search setting. Fields:
//         * HideObsolete              - Boolean - Check box of removing from selection of nonactual addresses. False
//                                                        by default.
//         * AddressFormat - String - type of a used classifier.
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
//             ** Outdated    - Boolean - Check box showing that data row is outdated.
//             ** Identifier - UUID - Classifier code to search variants by index.
//             ** Presentation - String - Variant presentation.
//
Function AddressesForInteractiveSelection(Parent, Level, AdditionalParameters) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
		Return ModuleAddressClassifierService.AddressesForInteractiveSelection(Parent, Level, AdditionalParameters);
	EndIf;
	
	Result = ErrorStructureAddressClassifierProvider();
	Result.Insert("Title");
	Result.Insert("Data", New ValueTable);
	Return Result;

EndFunction

// Returns the list for locality auto pick, search by similarity. List is limited to 20 records.
//
// Parameters:
//     Text                   - String    - Text entered in the field.
//     AddressesPartName          - String    - Identifier of processed address part.
//     PartsAddresses             - Structure - Values for other address parts.
//     AdditionalParameters - Structure - Description to search setting. Fields:
//         * HideObsolete              - Boolean      - Check box of removing from selection of nonactual addresses. False
//                                                             by default.
//         * AddressFormat - String      - Type of the used classifier.
//
// Returns:
//     Structure -  found variants. Contains fields:
//       * Denial                        - Boolean - Vendor is not available.
//       * DetailedErrorPresentation - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       * BriefErrorPresentation   - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       *Data                       - ValueList - result for autopick.
//
Function AutopickListAddressParts(Text, AddressesPartName, PartsAddresses, AdditionalParameters) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Result = New Structure("Data", New ValueList);
		Return ErrorStructureAddressClassifierProvider(Result);
	EndIf;
	
	PartAddresses = PartsAddresses[AddressesPartName];
	Parent = ContactInformationManagementClientServer.ItemAddressPartParentIdentifier(PartAddresses, PartsAddresses);
	
	Levels = New Array;
	Levels.Add(PartAddresses.Level);
	
	ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
	Result = ModuleAddressClassifierService.AutopickVariants(Text, Parent, Levels, AdditionalParameters);
	
	TabularData = Result.Data;
	
	Result.Data = New ValueList;
	If Not Result.Cancel Then
		FillAutopickFromTableList(Result.Data, TabularData, False);
	EndIf;
	
	Return Result;
	
EndFunction

//  Returns the structure with the Data field containing a list
// for auto pick of locality by the junior-senior hierarchical presentation.
//
//  Parameters:
//      Text                                - String - autopick text.
//      AdditionalParameters              - Structure - Describes search settings. Consists from optional fields:
//         * HideObsolete              - Boolean - Check box of removing from selection of nonactual addresses. False
//                                                        by default.
//         * AddressFormat - String - type of a used classifier.
//
// Returns:
//       * Denial                        - Boolean - Vendor is not available.
//       * DetailedErrorPresentation - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       * BriefErrorPresentation   - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       * PresentationCommonPart      - String - General part of address presentation.
//       *Data                       - ValueList - result for autopick.
//
Function LocalityAutofitList(Text, AdditionalParameters) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Result = New Structure("Data", New ValueList);
		Return ErrorStructureAddressClassifierProvider(Result);
	EndIf;
	
	PartsAddresses = ContactInformationManagementClientServer.LocalityAddressPartsStructure();
	
	Parent = Undefined;
	Levels   = New Array;
	For Each KeyValue In PartsAddresses Do
		If KeyValue.Value.Level < 7 Then
			Levels.Add(KeyValue.Value.Level);
		EndIf;
	EndDo;
	
	ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
	Result = ModuleAddressClassifierService.AutopickVariants(Text, Parent, Levels, AdditionalParameters);
	
	TabularData = Result.Data;
	
	Result.Data = New ValueList;
	If Not Result.Cancel Then
		FillAutopickFromTableList(Result.Data, TabularData, False);
	EndIf;
	
	Return Result;
EndFunction

//  Returns the structure with the Data field containing
//  a list for auto pick of street by the junior-senior hierarchical presentation.
//
//  Parameters:
//      Settlement         - UUID - Locality.
//      Text                   - String - Autopick text.
//      AdditionalParameters - Structure - Describes search settings. Consists from optional fields:
//         * HideObsolete              - Boolean - Check box of removing from selection of nonactual addresses. False
//                                                        by default.
//         * AddressFormat - String - Type of the used classifier.
//         * PortionSize                      - Number  - Return data quantity.
//
// Returns:
//       * Denial                        - Boolean - Vendor is not available.
//       * DetailedErrorPresentation - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       * BriefErrorPresentation   - String - Error description of vendor is unavailable. Undefined
//                                                 if Denial = False.
//       * PresentationCommonPart      - String - General part of address presentation.
//       *Data                       - ValueList - result for autopick.
//
Function StreetAutoselectionList(Settlement, Text, AdditionalParameters) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Result = New Structure("Data", New ValueList);
		Return ErrorStructureAddressClassifierProvider(Result);
	EndIf;
	
	PartsAddresses = ContactInformationManagementClientServer.LocalityAddressPartsStructure();
	
	Levels = New Array;
	For Each KeyValue In PartsAddresses Do
		If KeyValue.Value.Level > 6 Then 
			Levels.Add(KeyValue.Value.Level);
		EndIf;
	EndDo;
	
	ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
	Result = ModuleAddressClassifierService.AutopickVariants(Text, Settlement, Levels, AdditionalParameters);
	
	TabularData = Result.Data;
	
	Result.Data = New ValueList;
	If Not Result.Cancel Then
		FillAutopickFromTableList(Result.Data, TabularData, True);
	EndIf;
	
	Return Result;
EndFunction

#EndRegion

#Region CommonServiceProceduresAndFunctions

// Updates the fields of contact information from ValuesTable (for example, object of another catalog kind).
//
// Parameters:
//    Source - ValueTable - values table with contact information.
//    Receiver - ManagedForm - object form. where a contact information should be passed.
//
Procedure FillContactInformation(Source, Receiver) Export
	ContactInformationFieldsCollection = Receiver.ContactInformationAdditionalAttributeInfo;
	
	For Each ItemContactInformationFieldsCollection In ContactInformationFieldsCollection Do
		
		StringVKI = Source.Find(ItemContactInformationFieldsCollection.Type, "Kind");
		If StringVKI <> Undefined Then
			Receiver[ItemContactInformationFieldsCollection.AttributeName] = StringVKI.Presentation;
			ItemContactInformationFieldsCollection.FieldsValues          = ContactInformationManagementClientServer.ConvertStringToFieldList(StringVKI.FieldsValues);
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns en empty address structure.
//
// Returns:
//    Structure - address description, keys - fields names, field values.
//
Function GetEmptyAddressStructure() Export
	
	Return ContactInformationManagementClientServer.AddressFieldsStructure();
	
EndFunction

// Get values of an address field.
// 
// Parameters:
//    FieldValueString - String - address fields values.
//    FieldName             - String - field name. For example, Region.
// 
// Returns:
//  String - field value.
//
Function GetAddressFieldValue(FieldValueString, FieldName) Export
	
	FieldPosition = Find(FieldValueString, FieldName);
	Value = "";
	If FieldPosition <> 0 Then
		FieldsValues = Right(FieldValueString, StrLen(FieldValueString) - FieldPosition - StrLen(FieldName));
		LFPosition = Find(FieldsValues, Chars.LF);
		Value = Mid(FieldsValues, 0 ,LFPosition - 1);
	EndIf;
	Return Value;
	
EndFunction

// Receives values of an address field.
//
// Parameters:
//    FieldValueString - String - fields values row.
//    FieldName             - String - field name.
//
// Returns - String - contact information value.
//
Function GetContactInformationValue(FieldValueString, FieldName) Export
	
	FieldPosition = Find(FieldValueString, FieldName);
	Value = "";
	If FieldPosition <> 0 Then
		FieldsValues = Right(FieldValueString, StrLen(FieldValueString) - FieldPosition - StrLen(FieldName));
		LFPosition   = Find(FieldsValues, Chars.LF);
		Value    = Mid(FieldsValues, 0 , LFPosition - 1);
	EndIf;
	
	Return Value;
	
EndFunction

// Returns the values list
Function AddressesAvailableForCopying(Val FieldsForAnalysisValues, Val AddressKind) Export
	
	DomesticAddressOnly = AddressKind.DomesticAddressOnly;
	
	Result = New ValueList;
	
	For Each Address In FieldsForAnalysisValues Do
		AValidSource = True;
		
		Presentation = Address.Presentation;
		If IsBlankString(Presentation) Then
			// Not an empty presentation
			AValidSource = False;
		Else
			If DomesticAddressOnly Then
				// You can not copy a foreign address to the address restricted by Russia.
				XMLAddress = ContactInformationManagement.XMLContactInformation(Address.FieldsValue, Presentation, AddressKind);
				XDTOAddress = ContactInformationFromXML(XMLAddress, AddressKind);
				If Not ItsRussianAddress(XDTOAddress) Then
					AValidSource = False;
				EndIf;
			EndIf;
		EndIf;
		
		If AValidSource Then
			Result.Add(Address.Identifier, String(Address.AddressKind) + ": " + Presentation);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

Function EventLogMonitorEvent() Export
	
	Return NStr("en='Contact information';ru='Контактная информация'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Returns variants of houses types (by ownership trait).
Function VariantsDataHouse() Export
	
	Return New Structure("TypeOptions, CanSelectValues", 
		ContactInformationManagementClientServerReUse.NamesOfObjectsByTypeAddressing(1), False);
		
EndFunction

// Returns the variants of houses types (by construction trait).
Function VariantsDataConstruction() Export
	
	Return New Structure("TypeOptions, CanSelectValues", 
		ContactInformationManagementClientServerReUse.NamesOfObjectsByTypeAddressing(2), False);
		
EndFunction

// Returns variants of placement types.
Function VariantsOfDataPlace() Export
	
	Return New Structure("TypeOptions, CanSelectValues", 
		ContactInformationManagementClientServerReUse.NamesOfObjectsByTypeAddressing(3, False), False);
		
EndFunction

Procedure FillAutopickFromTableList(Result, TabularData, IsStreetSelection)
	
	WarningIrrelevant = NStr("en='Address ""%1"" is irrelevant.';ru='Адрес ""%1"" неактуален.'");
	IrrelevancePicture = PictureLib.ContactInformationIrrelevant;
	PictureRelevance   = Undefined;
	
	For Each String In TabularData Do
		Presentation = String.Presentation;
		
		If String.NotActual Then
			Warning = StrReplace(WarningIrrelevant, "%1", Presentation);
			Check        = True;
			Picture       = IrrelevancePicture;
		Else
			Warning = Undefined;
			Check        = False;
			Picture       = PictureRelevance;
		EndIf;
		
		ItemValue = New Structure;
		ItemValue.Insert("ID",  String.ID);
		ItemValue.Insert("Presentation",  String.Presentation);
		ItemValue.Insert("AutoComplete", True);
		ItemValue.Insert("StateImported", String.StateImported);
		If IsStreetSelection Then
			ItemValue.Insert("Street", String.Presentation);
			ItemValue.Insert("AdditionalItem", "");
			ItemValue.Insert("SubordinateItem", "");
			
		EndIf;
		
		Result.Add(
			New Structure("Warning, Value", Warning, ItemValue),
			Presentation, Check, Picture
		);
	EndDo;
	
EndProcedure

Function ErrorStructureAddressClassifierProvider(SourceStructure = Undefined)
	
	If SourceStructure = Undefined Then
		SourceStructure = New Structure;
	EndIf;
		
	SourceStructure.Insert("Cancel", False);
	SourceStructure.Insert("DetailErrorDescription");
	SourceStructure.Insert("BriefErrorDescription");

	Return SourceStructure;
EndFunction

// Converts XDTO contact information to XML.
//
//  Parameters:
//      XDTOObjectInformation - XDTODataObject - contact information.
//
// Returns:
//      String - result of converting in the XML format.
//
Function ContactInformationXDTOVXML(XDTOObjectInformation) Export
	
	Record = New XMLWriter;
	Record.SetString(New XMLWriterSettings(, , False, False, ""));
	
	If XDTOObjectInformation <> Undefined Then
		XDTOFactory.WriteXML(Record, XDTOObjectInformation);
	EndIf;
	
	Result = StrReplace(Record.Close(), Chars.LF, "&#10;");
	Result = StrReplace(Result, "<UrbDistrict/>", "");// Compatibility with AC
	
	Return Result;
	
EndFunction

// Converts XML to XDTO object of contact information.
//
//  Parameters:
//      Text            - String - XML row of a contact information.
//      ExpectedKind     - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes,
//      Structure ConversionResult - Structure - if it is specified, then the information is written to properties:
//        * ErrorText - String - reading errors description. In this case the return value
// of the function will be of a correct type but unfilled.
//
// Returns:
//      XDTODataObject - contact information corresponding to the ContactInformation XDTO-pack.
//   
Function ContactInformationFromXML(Val Text, Val ExpectedKind = Undefined, ConvertingResult = Undefined) Export
	
	ExpectedType = TypeKindContactInformation(ExpectedKind);
	
	EnumerationAddress                 = Enums.ContactInformationTypes.Address;
	EnumEmailAddress = Enums.ContactInformationTypes.EmailAddress;
	EnumerationWebPage           = Enums.ContactInformationTypes.WebPage;
	EnumerationPhone               = Enums.ContactInformationTypes.Phone;
	EnumFax                  = Enums.ContactInformationTypes.Fax;
	EnumerationAnother                = Enums.ContactInformationTypes.Other;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	If ContactInformationClientServer.IsXMLString(Text) Then
		XMLReader = New XMLReader;
		XMLReader.SetString(Text);
		
		ErrorText = Undefined;
		Try
			Result = XDTOFactory.ReadXML(XMLReader, XDTOFactory.Type(TargetNamespace, "ContactInformation"));
		Except
			// Incorrect XML format
			WriteLogEvent(EventLogMonitorEvent(),
				EventLogLevel.Error, , Text, DetailErrorDescription(ErrorInfo()));
			
			If TypeOf(ExpectedKind) = Type("CatalogRef.ContactInformationKinds") Then
				ErrorText = StrReplace(NStr("en='Incorrect XML format of contact information for ""%1"". Field values were cleared.';ru='Некорректный формат XML контактной информации для ""%1"", значения полей были очищены.'"),
					"%1", String(ExpectedKind));
			Else
				ErrorText = NStr("en='Incorrect XML format of contact information. Field values were cleared.';ru='Некорректный формат XML контактной информации, значения полей были очищены.'");
			EndIf;
		EndTry;
		
		If ErrorText = Undefined Then
			// Control types match.
			IsFoundType = ?(Result.Content = Undefined, Undefined, Result.Content.Type());
			If ExpectedType = EnumerationAddress AND IsFoundType <> XDTOFactory.Type(TargetNamespace, "Address") Then
				ErrorText = NStr("en='An error occurred when deserializing the contact information, address is expected';ru='Ошибка десериализации контактной информации, ожидается адрес'");
			ElsIf ExpectedType = EnumEmailAddress AND IsFoundType <> XDTOFactory.Type(TargetNamespace, "Email") Then
				ErrorText = NStr("en='An error occurred when deserializing the contact information, email address is expected';ru='Ошибка десериализации контактной информации, ожидается адрес электронной почты'");
			ElsIf ExpectedType = EnumerationWebPage AND IsFoundType <> XDTOFactory.Type(TargetNamespace, "WebSite") Then
				ErrorText = NStr("en='An error occurred when deserializing the contact information, web page is expected';ru='Ошибка десериализации контактной информации, ожидается веб-страница'");
			ElsIf ExpectedType = EnumerationPhone AND IsFoundType <> XDTOFactory.Type(TargetNamespace, "PhoneNumber") Then
				ErrorText = NStr("en='An error occurred when deserializing the contact information, phone number is expected';ru='Ошибка десериализации контактной информации, ожидается телефон'");
			ElsIf ExpectedType = EnumFax AND IsFoundType <> XDTOFactory.Type(TargetNamespace, "FaxNumber") Then
				ErrorText = NStr("en='An error occurred when deserializing the contact information, phone number is expected';ru='Ошибка десериализации контактной информации, ожидается телефон'");
			ElsIf ExpectedType = EnumerationAnother AND IsFoundType <> XDTOFactory.Type(TargetNamespace, "Other") Then
				ErrorText = NStr("en='Contact information deserialization error. Other data is expected.';ru='Ошибка десериализации контактной информации, ожидается ""другое""'");
			EndIf;
		EndIf;
		
		If ErrorText = Undefined Then
			// Read successfully
			Return Result;
		EndIf;
		
		// Check a mistake and return an extended information.
		If ConvertingResult = Undefined Then
			Raise ErrorText;
		ElsIf TypeOf(ConvertingResult) <> Type("Structure") Then
			ConvertingResult = New Structure;
		EndIf;
		ConvertingResult.Insert("ErrorText", ErrorText);
		
		// An empty object will be returned.
		Text = "";
	EndIf;
	
	If TypeOf(Text) = Type("ValueList") Then
		Presentation = "";
		IsNew = Text.Count() = 0;
	Else
		Presentation = String(Text);
		IsNew = IsBlankString(Text);
	EndIf;
	
	Result = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "ContactInformation"));
	
	// Parsing
	If ExpectedType = EnumerationAddress Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "Address"));
		Else
			Result = XMLBXDTOAddress(Text, Presentation, ExpectedType);
		EndIf;
		
	ElsIf ExpectedType = EnumerationPhone Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "PhoneNumber"));
		Else
			Result = DeserializationPhone(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumFax Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "FaxNumber"));
		Else
			Result = DeserializingFax(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumEmailAddress Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "Email"));
		Else
			Result = DeserializationOfOtherContactInformation(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumerationWebPage Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "WebSite"));
		Else
			Result = DeserializationOfOtherContactInformation(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumerationAnother Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "Other"));
		Else
			Result = DeserializationOfOtherContactInformation(Text, Presentation, ExpectedType)    
		EndIf;
		
	Else
		Raise NStr("en='An error occurred while deserializing contact information, the expected type is not specified';ru='Ошибка десериализации контактной информации, не указан ожидаемый тип'");
	EndIf;
	
	Return Result;
EndFunction

// Parses the KI presentation and returns XDTO.
//
//  Parameters:
//      Text        - String  - the
//      xml node ExpectedKind - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes, Structure
//
// Returns:
//      XDTODataObject - contact information.
//
Function XDTOContactInformationByPresentation(Text, ExpectedKind) Export
	
	ExpectedType = TypeKindContactInformation(ExpectedKind);
	
	If ExpectedType = Enums.ContactInformationTypes.Address Then
		Return XMLBXDTOAddress("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.EmailAddress Then
		Return DeserializationOfOtherContactInformation("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		Return DeserializationOfOtherContactInformation("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Phone Then
		Return DeserializationPhone("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Fax Then
		Return DeserializingFax("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		Return DeserializationOfOtherContactInformation("", Text, ExpectedType);
		
	EndIf;
	
	Return Undefined;
EndFunction

// Converts a row to XDTO address contact information.
//
//  Parameters:
//      FieldsValues - String - serialized information, fields values.
//      Presentation - String - junior-senior presentation used to try parsing
//                               if FieldValues is empty.
//      ExpectedType  - EnumRef.ContactInformationTypes - optional type for control.
//
//  Returns:
//      XDTODataObject  - contact information.
//
Function XMLBXDTOAddress(Val FieldsValues, Val Presentation = "", Val ExpectedType = Undefined) Export
	
	ValueType = TypeOf(FieldsValues);
	ParseOnFields = (ValueType = Type("ValueList") Or ValueType = Type("Structure") 
		Or (ValueType = Type("String") AND Not IsBlankString(FieldsValues)));
	If ParseOnFields Then
		// Disassemble from fields values.
		Return AddressDeserializationCommon(FieldsValues, Presentation, ExpectedType);
	EndIf;
	
	// Disassemble the address from its presentation by classifier.
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Return GenerateAddressByPresentation(Presentation);
	EndIf;
	
	// Empty object with a presentation.
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	Result = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "ContactInformation"));
	Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "Address"));
	Result.Presentation = Presentation;
	Return Result;
	
EndFunction


Function AddressObjectsLevels(AddressObjectType = "Full")
	Levels = New Array;
	If AddressObjectType = "Street" Then
		Levels.Add(7);
		Levels.Add(90);
		Levels.Add(91);
	ElsIf AddressObjectType = "Settlement" Then
		Levels.Add(1);
		Levels.Add(2);
		Levels.Add(3);
		Levels.Add(4);
		Levels.Add(5);
		Levels.Add(6);
	Else
		Levels.Add(1);
		Levels.Add(2);
		Levels.Add(3);
		Levels.Add(4);
		Levels.Add(5);
		Levels.Add(6);
		Levels.Add(7);
		Levels.Add(90);
		Levels.Add(91);
	EndIf;
	
	Return Levels;
EndFunction

Function GenerateAddressByPresentation(Presentation)
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	
	Result = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "ContactInformation"));
	Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "Address"));
	Result.Presentation = Presentation;
	
	Address = Result.Content;
	NameRussia = TrimAll(Catalogs.WorldCountries.Russia.Description);
	
	DataAnalysis = PartsOfAddressTable(Presentation);
	If DataAnalysis.Count() = 0 Then
		Return Result;
	EndIf;
	
	GetCountryAndIndex(DataAnalysis);
	RowOfCountry = DataAnalysis.Find(-2, "Level");
	If RowOfCountry = Undefined Then
		Address.Country = NameRussia;
	Else
		Address.Country = TrimAll(Upper(RowOfCountry.Value));
		// Check if there is a country in the Countries of the world catalog and implicitly add it if there is no country.
		WorldCountryData = Catalogs.WorldCountries.WorldCountryData(, Address.Country);
		If WorldCountryData <> Undefined AND Not ValueIsFilled(WorldCountryData.Ref) Then
			WorldCountry = Catalogs.WorldCountries.RefByClassifier(WorldCountryData);
		EndIf;
	EndIf;
	
	If Address.Country = NameRussia Then
		If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
			TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
			AddressRF = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "AddressRF"));
			ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
			AddressByLevels = ModuleAddressClassifierService.SetAddressPartToTheirLevelMatch(DataAnalysis, AddressObjectsLevels());
			If AddressByLevels <> Undefined Then
				PlaceAddressToXDTO(AddressRF, AddressByLevels);
			EndIf;
			
			If AddressByLevels.Find(0, "Level") <> Undefined Then
				// Something is left, count as an address in any format.
				AddressRF.Address_To_Document = Presentation;
			EndIf;
			Address.Content = AddressRF;
		EndIf;
	Else
		// Content without country, it is kept in the presentation.
		Position = RowOfCountry.Begin + RowOfCountry.Length;
		Length   = StrLen(Presentation);
		Separators = "," + Chars.LF;
		While Position <= Length AND Find(Separators, Mid(Presentation, Position, 1)) <= 0 Do
			Position = Position + 1;
		EndDo;
		While Position <= Length AND Find(Separators, Mid(Presentation, Position, 1)) > 0 Do
			Position = Position + 1;
		EndDo;
		Address.Content = TrimAll(Left(Presentation, RowOfCountry.Begin - 1) + " " + TrimAll(Mid(Presentation, Position)));

	EndIf;
		
	Return Result;
EndFunction

Function PartsOfAddressTable(Val Text)
	
	StringType = New TypeDescription("String", New StringQualifiers(128));
	NumberType  = New TypeDescription("Number");
	
	Result = New ValueTable;
	Columns = Result.Columns;
	Columns.Add("Level", NumberType);
	Columns.Add("Position", NumberType);
	Columns.Add("Value", StringType);
	Columns.Add("Description", StringType);
	Columns.Add("Abbr", StringType);
	Columns.Add("Begin", NumberType);
	Columns.Add("Length", NumberType);
	Columns.Add("ID", StringType);
	
	Number = 1;
	For Each part In WordsTextTable(Text, "," + Chars.LF) Do
		Value = TrimAll(part.Value);
		If IsBlankString(Value) Then
			Continue;
		EndIf;
		
		String = Result.Add();
		
		String.Level = 0;
		String.Position  = Number;
		Number = Number + 1;
		
		String.Begin = part.Begin;
		String.Length  = part.Length;
		
		Position = StrLen(Value);
		While Position > 0 Do
			Char = Mid(Value, Position, 1);
			If IsBlankString(Char) Then
				String.Description = TrimAll(Left(Value, Position-1));
				Break;
			EndIf;
			String.Abbr = Char + String.Abbr;
			Position = Position - 1;
		EndDo;
		
		If IsBlankString(String.Description) Then
			String.Description = TrimAll(String.Abbr);
			String.Abbr   = "";
		EndIf;
		String.Value = String.Description + " " + String.Abbr; // Value;
	EndDo;
	
	Return Result;
EndFunction

Procedure GetCountryAndIndex(DataAnalysis)
	
	Classifier = Catalogs.WorldCountries.ClassifierTable();
	
	Query = New Query;
	Query.Text = "SELECT
	               |	DataAddresses.Description AS Description,
	               |	DataAddresses.Value AS FullDescr,
	               |	DataAddresses.Position AS Position,
	               |	DataAddresses.Abbr AS Abbr
	               |INTO DataAddresses
	               |FROM
	               |	&DataAddresses AS DataAddresses
	               |
	               |INDEX BY
	               |	Description,
	               |	Position,
	               |	Abbr
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	DataAddresses.Description AS Description,
	               |	CASE
	               |		WHEN DataAddresses.Description LIKE ""[0-9][0-9][0-9][0-9][0-9][0-9]""
	               |			THEN -1
	               |		ELSE CASE
	               |				WHEN DataAddresses.FullDescr In (&CountriesClassifier)
	               |					THEN -2
	               |				ELSE 0
	               |			END
	               |	END AS Level,
	               |	DataAddresses.Position
	               |FROM
	               |	DataAddresses AS DataAddresses";
	
	Query.SetParameter("DataAddresses", DataAnalysis);
	Query.SetParameter("CountriesClassifier", Classifier.UnloadColumn("Description"));
	QueryResult = Query.Execute().Select();
	
	While QueryResult.Next() Do
		If QueryResult.Level <> 0 Then
			ItemOfAddress = DataAnalysis.Find(QueryResult.Position, "Position");
			ItemOfAddress.Level = QueryResult.Level;
		EndIf;
	EndDo;
	
EndProcedure

Procedure PlaceAddressToXDTO(AddressRF, AddressByLevels)
	
	BuildingsTableBuildings = New ValueTable;
	BuildingsTableBuildings.Columns.Add("Type");
	BuildingsTableBuildings.Columns.Add("Value");

	For Each ItemOfAddress In AddressByLevels Do
		// XPath
		If ItemOfAddress.Level = 1 Then
			Path = "RFTerritorialEntity";
		ElsIf ItemOfAddress.Level = 2 Then
			Path = "District";
		ElsIf ItemOfAddress.Level = 3 Then
			Path = "PrRayMO/Region";
		ElsIf ItemOfAddress.Level = 4 Then
			Path = "City";
		ElsIf ItemOfAddress.Level = 5 Then
			Path = "UrbDistrict";
		ElsIf ItemOfAddress.Level = 6 Then
			Path = "Settlement";
		ElsIf ItemOfAddress.Level = 7 Then
			Path = "Street";
		ElsIf ItemOfAddress.Level = 90 Then
			AddAdditionalAddressItems(AddressRF, ItemOfAddress.Value, 90);
		ElsIf ItemOfAddress.Level = 91 Then
			AddAdditionalAddressItems(AddressRF, ItemOfAddress.Value, 91);
		ElsIf ItemOfAddress.Level = -3 Then
			Continue;
		ElsIf ItemOfAddress.Level = -1 Then
			PostalIndexOfAddresses(AddressRF, ItemOfAddress.Description);
		Else
			// Check for an apartment or building.
			Type = TrimAll(StrReplace(ItemOfAddress.Description, "No.", ""));
			If ContactInformationManagementClientServerReUse.AddressingObjectSerializationCode(Type) <> Undefined Then
				 // Insert at the beginning as the result order is reversed.
				NewRow = BuildingsTableBuildings.Insert(0);
				NewRow.Value = TrimAll(StrReplace(ItemOfAddress.Abbr, "No.", ""));
				NewRow.Type      = Type;
				ItemOfAddress.Level = -3;
			EndIf;

			Continue;
		EndIf;
		
		If ItemOfAddress.Level > 0 AND ItemOfAddress.Level < 90 Then
			InstallPropertyByXPath(AddressRF, Path, ItemOfAddress.Value);
		EndIf;
		
	EndDo;
	
	BuildingsAndFacilities = New Structure("Buildings, Rooms", BuildingsTableBuildings, BuildingsTableBuildings);
	BuildingsAndFacilitiesAddresses(AddressRF, BuildingsAndFacilities);
	
EndProcedure

// Set an object deep property.
Procedure InstallPropertyByXPath(XDTOObject, XPath, Value) Export
	
	// Do not wait for line break to XPath.
	PropertiesString = StrReplace(StrReplace(XPath, "/", Chars.LF), Chars.LF + Chars.LF, "/");
	
	NumberOfProperties = StrLineCount(PropertiesString);
	If NumberOfProperties = 1 Then
		XDTOObject.Set(PropertiesString, Value);
		Return;
	ElsIf NumberOfProperties < 1 Then
		Return;
	EndIf;
		
	ParentObject = Undefined;
	CurrentObject      = XDTOObject;
	For IndexOf = 1 To NumberOfProperties Do
		
		CurrentName = StrGetLine(PropertiesString, IndexOf);
		If CurrentObject.IsSet(CurrentName) Then
			ParentObject = CurrentObject;
			CurrentObject = CurrentObject.GetXDTO(CurrentName);
		Else
			NewType = CurrentObject.Properties().Get(CurrentName).Type;
			TypeType = TypeOf(NewType);
			If TypeType = Type("XDTOObjectType") Then
				NewObject = XDTOFactory.Create(NewType);
				CurrentObject.Set(CurrentName, NewObject);
				ParentObject = CurrentObject;
				CurrentObject = NewObject; 
			ElsIf TypeType = Type("XDTOValueType") Then
				// Direct value
				CurrentObject.Set(CurrentName, Value);
				ParentObject = Undefined;
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If ParentObject <> Undefined Then
		ParentObject.Set(CurrentName, Value);
	EndIf;
	
EndProcedure

Function WordsTextTable(Val Text, Val Separators = Undefined)
	
	// Delete spec. from the text characters "points", "numbers"
	Text = StrReplace(Text, ".", "");
	Text = StrReplace(Text, "No.", "");
	
	WordStart = 0;
	State   = 0;
	
	StringType = New TypeDescription("String");
	NumberType  = New TypeDescription("Number");
	
	Result = New ValueTable;
	Columns = Result.Columns;
	Columns.Add("Value", StringType);
	Columns.Add("Begin",   NumberType);
	Columns.Add("Length",    NumberType);
	
	For Position = 1 To StrLen(Text) Do
		CurrentChar = Mid(Text, Position, 1);
		IsSplitter = ?(Separators = Undefined, IsBlankString(CurrentChar), Find(Separators, CurrentChar) > 0);
		
		If State = 0 AND (Not IsSplitter) Then
			WordStart = Position;
			State   = 1;
		ElsIf State = 1 AND IsSplitter Then
			String = Result.Add();
			String.Begin = WordStart;
			String.Length  = Position-WordStart;
			String.Value = Mid(Text, String.Begin, String.Length);
			State = 0;
		EndIf;
	EndDo;
	
	If State = 1 Then
		String = Result.Add();
		String.Begin = WordStart;
		String.Length  = Position-WordStart;
		String.Value = Mid(Text, String.Begin, String.Length)
	EndIf;
	
	Return Result;
EndFunction

// Converts a row to XDTO phone contact information.
//
//      FieldsValues - String - serialized information, fields values.
//      Presentation - String - junior-senior presentation used to try parsing
//                               if FieldValues is empty.
//      ExpectedType  - EnumRef.ContactInformationTypes - optional type for control.
//
//  Returns:
//      XDTODataObject  - contact information.
//
Function DeserializationPhone(FieldsValues, Presentation = "", ExpectedType = Undefined) Export
	Return DeserializationPhoneFax(FieldsValues, Presentation, ExpectedType);
EndFunction

// Converts a row to XDTO Fax contact information.
//
//      FieldsValues - String - serialized information, fields values.
//      Presentation - String - junior-senior presentation used to try parsing
//                               if FieldValues is empty.
//      ExpectedType  - EnumRef.ContactInformationTypes - optional type for control.
//
//  Returns:
//      XDTODataObject  - contact information.
//
Function DeserializingFax(FieldsValues, Presentation = "", ExpectedType = Undefined) Export
	Return DeserializationPhoneFax(FieldsValues, Presentation, ExpectedType);
EndFunction

// Converts a row to XDTO other contact information.
//
// Parameters:
//   FieldsValues - String - serialized information, fields values.
//   Presentation - String - junior-senior presentation used to try parsing if FieldValues is empty.
//   ExpectedType  - EnumRef.ContactInformationTypes - optional type for control.
//
// Returns:
//   XDTODataObject  - contact information.
//
Function DeserializationOfOtherContactInformation(FieldsValues, Presentation = "", ExpectedType = Undefined) Export
	
	If ContactInformationClientServer.IsXMLString(FieldsValues) Then
		// General format of a contact information.
		Return ContactInformationFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	Result = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "ContactInformation"));
	Result.Presentation = Presentation;
	
	If ExpectedType = Enums.ContactInformationTypes.EmailAddress Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "Email"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "WebSite"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "Other"));
		
	ElsIf ExpectedType <> Undefined Then
		Raise NStr("en='An error occurred when deserializing the contact information, another type is expected';ru='Ошибка десериализации контактной информации, ожидается другой тип'");
		
	EndIf;
	
	Result.Content.Value = Presentation;
	
	Return Result;
	
EndFunction

//  Returns the check box showing that a passed address - Russian.
//
//  Parameters:
//      XDTOAddress - XDTODataObject - Contact information or XDTO addresses.
//
//  Returns:
//      Boolean - checking result.
//
Function ItsRussianAddress(XDTOAddress) Export
	Return RussianAddress(XDTOAddress) <> Undefined;
EndFunction

//  Returns an extracted XDTO of Russian address or Undefined for a foreign address.
//
//  Parameters:
//      InformationObject - XDTODataObject - Contact information or XDTO addresses.
//
//  Returns:
//      XDTODataObject - Russian address.
//      Undefined - there is no Russian address.
//
Function RussianAddress(InformationObject) Export
	Result = Undefined;
	XDTOType   = Type("XDTODataObject");
	
	If TypeOf(InformationObject) = XDTOType Then
		TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
		
		If InformationObject.Type() = XDTOFactory.Type(TargetNamespace, "ContactInformation") Then
			Address = InformationObject.Content;
		Else
			Address = InformationObject;
		EndIf;
		
		If TypeOf(Address) = XDTOType AND Address.Type() = XDTOFactory.Type(TargetNamespace, "Address") Then
			Address = Address.Content;
		EndIf;
		
		If TypeOf(Address) = XDTOType AND Address.Type() = XDTOFactory.Type(TargetNamespace, "AddressRF") Then
			Result = Address;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

// Returns values of the 90(additional item) and 91(subordinate) levels from the address.
//
Function AdditionalItemsValues(Val XDTOAddress) Export
	
	Result = New Structure("AdditionalItem, SubordinateItem");
	
	AddressRF = RussianAddress(XDTOAddress);
	If AddressRF = Undefined Then
		Return Result;
	EndIf;
	
	
	AdditionalAddressItem = FindAdditionalAddressItem(AddressRF);

	Result.AdditionalItem = AdditionalAddressItem;
	Result.SubordinateItem = AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(91));
	
	Return Result;
	
EndFunction

//  Reads and sets address postal code.
//
//  Parameters:
//      XDTOAddress     - XDTODataObject - Contact information or XDTO addresses.
//      NewValue - String     - set value.
//
//  Returns:
//      String - postal index.
//
Function PostalIndexOfAddresses(XDTOAddress, NewValue = Undefined) Export
	
	AddressRF = RussianAddress(XDTOAddress);
	If AddressRF = Undefined Then
		Return Undefined;
	EndIf;
	
	If NewValue = Undefined Then
		// Read
		Result = AddressRF.Get( ContactInformationManagementClientServerReUse.XMailPathIndex() );
		If Result <> Undefined Then
			Result = Result.Value;
		EndIf;
		Return Result;
	EndIf;
	
	// Record
	CodeIndex = ContactInformationManagementClientServerReUse.SerializationCodePostalIndex();
	
	WriteIndex = AddressRF.Get(ContactInformationManagementClientServerReUse.XMailPathIndex());
	If WriteIndex = Undefined Then
		WriteIndex = AddressRF.AddEMailAddress.Add( XDTOFactory.Create(XDTOAddress.AddEMailAddress.OwningProperty.Type) );
		WriteIndex.TypeAdrEl = CodeIndex;
	EndIf;
	
	WriteIndex.Value = NewValue;
	Return NewValue;
EndFunction

// Reads an additional address item by its path.
//
//  Parameters:
//      XDTOAddress     - XDTODataObject - Contact information or XDTO addresses.
//      ItemXPath -  String - Path to item.
//
//  Returns:
//      String - field item.
Function AdditionalAddressItem(XDTOAddress, ItemXPath) Export
	
	AddressRF = RussianAddress(XDTOAddress);
	If AddressRF = Undefined Then
		Return Undefined;
	EndIf;
	
	Result = AddressRF.Get(ItemXPath);
	If Result <> Undefined Then
		Return Result.Value;
	EndIf;
	
	Return Result;
EndFunction

// Returns additional addresses.
//
Function FindAdditionalAddressItem(AddressRF) Export
	AdditionalAddressItem = Undefined;
	
	AdditionalAddressItem = AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(90, "SNT"));
	If AdditionalAddressItem = Undefined Then
		AdditionalAddressItem = AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(90, "GSK"));
	EndIf;
	If AdditionalAddressItem = Undefined Then
		AdditionalAddressItem = AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(90, "TER"));
	EndIf;
	If AdditionalAddressItem = Undefined Then
		AdditionalAddressItem = AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(90));
	EndIf;
	
	Return AdditionalAddressItem;

EndFunction


// Adds additional items to an address by its path.
//
Procedure AddAdditionalAddressItems(XDTOAddress, NewValue, Level) Export
	
	AddressRF = RussianAddress(XDTOAddress);
	If AddressRF = Undefined Then
		Return;
	EndIf;
	
	
	If Level = 90 Then
		DescriptionAndAbbreviation = ContactInformationManagementClientServer.DescriptionAbbreviation(NewValue);
		AdditionalAddressingObjectSerializationCode = ContactInformationManagementClientServerReUse.AdditionalAddressingObjectSerializationCode(90, DescriptionAndAbbreviation.Abbr);
	ElsIf Level = 91 Then
		AdditionalAddressingObjectSerializationCode = ContactInformationManagementClientServerReUse.AdditionalAddressingObjectSerializationCode(91);
	Else
		AdditionalAddressingObjectSerializationCode = ContactInformationManagementClientServerReUse.AdditionalAddressingObjectSerializationCode(0);
	EndIf;

	ItemXPath = "AddEMailAddress[TypeAdrEl='" + AdditionalAddressingObjectSerializationCode + "']";
	FieldValue = AddressRF.Get(ItemXPath);
	If FieldValue = Undefined Then
		FieldValue = AddressRF.AddEMailAddress.Add(XDTOFactory.Create(XDTOAddress.AddEMailAddress.OwningProperty.Type));
		FieldValue.TypeAdrEl = AdditionalAddressingObjectSerializationCode;
	EndIf;
	FieldValue.Value = NewValue;
	
EndProcedure
	
//  Returns a postal code for an address by the classifier data.
//
//  Parameters:
//      XDTOAddress - XDTODataObject - Contact information or XDTO addresses.
//
//  Returns:
//      String - postal index.
//      Undefined - index is not found or the address is foreign.
//
Function DefineIndexOfAddresses(XDTOAddress, ID = Undefined) Export
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	
	If XDTOAddress.Type() = XDTOFactory.Type(TargetNamespace, "Address") Then
		XDTOAddressRF = XDTOAddress.Content;
	Else 
		XDTOAddressRF = XDTOAddress;
	EndIf;
	
	If XDTOAddressRF = Undefined Or XDTOAddressRF.Type() <> XDTOFactory.Type(TargetNamespace, "AddressRF") Then
		Return Undefined;// Foreign or empty address.
	EndIf;
	
	IndexOf = Undefined;
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		// Call analysis and return variant index.
		ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
		IndexOf = ModuleAddressClassifierService.AddressIndexByAddressParts(XDTOAddressRF, ID);
	EndIf;
	
	Return IndexOf;
EndFunction

//  Reads and sets address region.
//
//  Parameters:
//      XDTOAddress     - XDTODataObject - Contact information or XDTO addresses.
//      NewValue - String - set value.
//
//  Returns:
//      String - new value.
//
Function RegionAddresses(XDTOAddress, NewValue = Undefined) Export
	
	If NewValue = Undefined Then
		// Read
		
		Result = Undefined;
		TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
		
		XDTOType = XDTOAddress.Type();
		If XDTOType = XDTOFactory.Type(TargetNamespace, "AddressRF") Then
			AddressRF = XDTOAddress;
		Else
			AddressRF = XDTOAddress.Content;
		EndIf;
		
		If TypeOf(AddressRF) = Type("XDTODataObject") Then
			Return GetXDTOObjectAttribute(AddressRF, ContactInformationManagementClientServerReUse.RegionXPath() );
		EndIf;
		
		Return Undefined;
	EndIf;
	
	// Record
	Record = PrRayMO(XDTOAddress);
	Record.Region = NewValue;
	Return NewValue;
EndFunction

//  Reads and sets buildings and units of an address. 
//
//  Parameters:
//      XDTOAddress     - XDTODataObject - Contact information or XDTO addresses.
//      NewValue - Structure  - set value. Fields are expected:
//                          * Houses - ValuesTable with columns:
//                                        ** Type      - String - internal classifier type of
//                                                               the additional address objects. For example, "Block".
//                                        ** Value - String  - value of house number, apartment
//                          number etc * Premises - ValuesTable with columns similarly to the Building field.
//
//  Returns:
//      Structure - current data. Contains fields:
//          * Houses - ValuesTable with columns:
//                        ** Type        - String - internal classifier type of the additional address objects.
//                                                 For example, "Block".
//                        ** Abbreviation - String - abbreviation of the name to use it in the presentation.
//                        ** Value   - String - value of house, apartment
//                        number etc ** PathXPath  - String - value path object.
//          * Rooms - ValuesTable with columns similarly to the Building field.
//
Function BuildingsAndFacilitiesAddresses(XDTOAddress, NewValue = Undefined) Export
	
	Result = New Structure("Buildings, Units", 
		ValueTable("Type, Value, Abbreviation, PathXPath, Kind", "Type, Kind"),
		ValueTable("Type, Value, Abbreviation, PathXPath, Kind", "Type, Kind"));
	
	AddressRF = RussianAddress(XDTOAddress);
	If AddressRF = Undefined Then
		Return Result;
	EndIf;
	
	If NewValue <> Undefined Then
		// Record
		If NewValue.Property("Buildings") Then
			For Each String In NewValue.Buildings Do
				InsertBuildingUnit(XDTOAddress, String.Type, String.Value);
			EndDo;
		EndIf;
		If NewValue.Property("Units") Then
			For Each String In NewValue.Units Do
				InsertBuildingUnit(XDTOAddress, String.Type, String.Value);
			EndDo;
		EndIf;
		Return NewValue
	EndIf;
	
	// Read
	For Each AdditionalItem In AddressRF.AddEMailAddress Do
		If AdditionalItem.Number <> Undefined Then
			ObjectCode = AdditionalItem.Number.Type;
			ObjectType = ContactInformationManagementClientServerReUse.ObjectTypeSerializationCode(ObjectCode);
			If ObjectType <> Undefined Then
				Kind = ObjectType.Type;
				If Kind = 1 Or Kind = 2 Then
					NewRow = Result.Buildings.Add();
				ElsIf Kind = 3 Then
					NewRow = Result.Units.Add();
				Else
					NewRow = Undefined;
				EndIf;
				If NewRow <> Undefined Then
					NewRow.Type        = ObjectType.Description;
					NewRow.Value   = AdditionalItem.Number.Value;
					NewRow.Abbreviation = ObjectType.Abbreviation;
					NewRow.PathXPath  = ContactInformationManagementClientServerReUse.XNumberOfAdditionalObjectPathAddressing(NewRow.Type);
					NewRow.Kind = Kind;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	Result.Buildings.Sort("Kind");
	Result.Units.Sort("Kind");
	
	Return Result;
EndFunction

//  Returns the junior-senior presentation for a locality.
//
//  Parameters:
//      ObjectAddress - XDTODataObject - address RF.
//
//  Returns:
//      String - presentation.
//
Function PresentationOfSettlement(ObjectAddress) Export
	
	AddressRF = RussianAddress(ObjectAddress);
	If AddressRF = Undefined Then
		Return "";
	EndIf;
	
	If AddressRF.PrRayMO = Undefined Then
		Region = "";
	ElsIf AddressRF.PrRayMO.Region <> Undefined Then
		Region = AddressRF.PrRayMO.Region;
	ElsIf AddressRF.PrRayMO.SwMO <> Undefined Then
		Regions = New Array(AddressRF.PrRayMO.SwMO.MunObr2, AddressRF.PrRayMO.SwMO.MunEd1);
		Region = ContactInformationManagementClientServer.GenerateFullDescr(Regions);
	Else
		Region = "";;
	EndIf;
	
	Address = New Array;
	Address.Add(AddressRF.Settlement);
	Address.Add(AddressRF.UrbDistrict);
	Address.Add(AddressRF.City);
	Address.Add(Region);
	Address.Add(AddressRF.District);
	Address.Add(AddressRF.RFTerritorialEntity);
	
	Return ContactInformationManagementClientServer.GenerateFullDescr(Address);
	
EndFunction

//  Returns the junior-senior presentation for a locality.
//
//  Parameters:
//      ObjectAddress - XDTODataObject - address RF.
//
//  Returns:
//      String - presentation.
//
Function PresentationStreet(ObjectAddress) Export
	
	AddressRF = RussianAddress(ObjectAddress);
	If AddressRF = Undefined Then
		Return "";
	EndIf;
	
	Address = New Array;
	Address.Add(AddressRF.Street);
	
	AdditionalAddressItem = AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(90, "SNT"));
	If AdditionalAddressItem = Undefined Then
		AdditionalAddressItem = AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(90, "GSK"));
	EndIf;
	If AdditionalAddressItem = Undefined Then
		AdditionalAddressItem = AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(90, "TER"));
	EndIf;
	If AdditionalAddressItem = Undefined Then
		AdditionalAddressItem = AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(90));
	EndIf;

	Address.Add(AdditionalAddressItem);
	Address.Add(AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(91)));
	
	Return ContactInformationManagementClientServer.GenerateFullDescr(Address);
	
EndFunction

// Generates the presentation for address by a rule:
// 1) Country if needed.
// 2) ZipCode, RF territorial entity, district, region, city, urban district, settlement, street.
// 3) Buildings, units
//
Function AddressPresentation(Val XDTOAddress, Val InformationKind) Export
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	AddressRF          = XDTOAddress.Content;
	Country           = TrimAll(XDTOAddress.Country);
	If ItsRussianAddress(AddressRF) Then
		
		// It is Russian address, see settings.
		If Not InformationKind.IncludeCountryInPresentation Then
			Country = "";
		EndIf;
		
		// Important parts
		Address = New Array;
		Address.Add(AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.XMailPathIndex()));
		Address.Add(AddressRF.RFTerritorialEntity);
		If InformationKind.AddressFormat = "FIAS" Then
			Address.Add(AddressRF.District);
		EndIf;
		Address.Add(RegionAddresses(AddressRF));
		Address.Add(AddressRF.City);
		If InformationKind.AddressFormat = "FIAS" Then
			Address.Add(AddressRF.UrbDistrict);
		EndIf;
		Address.Add(AddressRF.Settlement);
		Address.Add(AddressRF.Street);
		
		AdditionalAddressItem = AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(90, "SNT"));
		If AdditionalAddressItem = Undefined Then
			AdditionalAddressItem = AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(90, "GSK"));
		ElsIf AdditionalAddressItem = Undefined Then
			AdditionalAddressItem = AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(90, "TER"));
		ElsIf AdditionalAddressItem = Undefined Then
			AdditionalAddressItem = AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(90));
		EndIf;
		
		Address.Add(AdditionalAddressItem);
		Address.Add(AdditionalAddressItem(AddressRF, ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(91)));
		
		Presentation = ContactInformationManagementClientServer.GenerateFullDescr(Address);
	
		// Buildings and rooms
		NumberNotShown = True;
		Data = BuildingsAndFacilitiesAddresses(AddressRF);
		For Each String In Data.Buildings Do
			Buildings = New Array;
			Buildings.Add(Presentation); 
			Buildings.Add(TrimAll(String.Abbreviation + ?(NumberNotShown, " No. ", " ") + String.Value));
			Presentation =  ContactInformationManagementClientServer.GenerateFullDescr(Buildings);
			NumberNotShown = False;
		EndDo;
		
		For Each String In Data.Units Do
			Units = New Array;
			Units.Add(Presentation);
			Units.Add(TrimAll(String.Abbreviation + " " + String.Value));
			Presentation =  ContactInformationManagementClientServer.GenerateFullDescr(Units);
		EndDo;
			
		// IF the presentation is the empty, there is no point displaying a country.
		If IsBlankString(Presentation) Then
			Country = "";
		EndIf;
	Else
		// This is a foreign address
		Presentation = TrimAll(AddressRF);
	EndIf;
	
	InsertCountries = New Array;
	InsertCountries.Add(Presentation);
	InsertCountries.Add(Country);
	Return ContactInformationManagementClientServer.GenerateFullDescr(InsertCountries);
EndFunction

//  Returns errors listing for an address.
//
// Parameters:
//     XDTOAddress         - XDTOObject, ValuesList, Row - address description.
//     InformationKind     - CatalogRef.ContactInformationTypes, Structure - ref to
//                         the corresponding contact information kind.
//     ResultByGroups - Boolean - if True is specified, then the array of errors group will be returned, otherwise, - values
//                                  list.
//
// Returns:
//     ValueList - if the ResultByGroups parameter equals to False. Inside presentation - error text, value -
//                      XPath of an erroneous field.
//     Array         - if the ResultByGroups parameter equals to True. Contains structures with fields:
//                         ** ErrorType - String - name of the error group (type). Possible values:
//                               PresentationNotCorrespondToFieldsSet
//                               MandatoryFieldsNotFilled
//                               FieldsAbbreviationsNotSpecified
//                               InvalidFieldsCharacters
//                               NotCorrespondFieldsLength
//                               ErrorsByClassifier
//                         ** Message - String - detailed error text.
//                         ** Fields      - Array - contains structures of erroneous fields descriptions. Each structure
//                                                 has attributes:
//                               *** FieldName   - String - internal identifier erroneous item Addresses.
//                               *** Message - String - detailed error text for this field.
//
Function AddressFillingErrorsXDTO(XDTOAddress, InformationKind, ResultByGroups = False) Export
	
	If TypeOf(XDTOAddress) = Type("XDTODataObject") Then
		AddressRF = XDTOAddress.Content;
	Else
		XDTOContact = XMLBXDTOAddress(XDTOAddress);
		Address = XDTOContact.Content;
		AddressRF = ?(Address = Undefined, Undefined, Address.Content);
	EndIf;
	
	// Checking check boxes
	If TypeOf(InformationKind) = Type("CatalogRef.ContactInformationKinds") Then
		CheckCheckBoxes = StructureTypeContactInformation(InformationKind);
	Else
		CheckCheckBoxes = InformationKind;
	EndIf;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	If TypeOf(AddressRF) <> Type("XDTODataObject") Or AddressRF.Type() <> XDTOFactory.Type(TargetNamespace, "AddressRF") Then
		// Address outside RF
		Result = ?(ResultByGroups, New Array, New ValueList);
		
		If CheckCheckBoxes.DomesticAddressOnly Then
			ErrorText = NStr("en='Only Russian addresses can be used.';ru='Адрес должен быть только российским.'");
			If ResultByGroups Then
				Result.Add(New Structure("Fields, ErrorTypes, Message", New Array,
					"MandatoryFieldsAreNotFilledIn", ErrorText
				)); 
			Else
				Result.Add("/", ErrorText);
			EndIf;
		EndIf;
		
		Return Result;
	EndIf;
	
	// Check an empty address separately if the filling is required.
	If Not XDTOContactInformationFilled(AddressRF) Then
		// Address is empty
		If CheckCheckBoxes.Mandatory Then
			// But must be filled in
			ErrorText = NStr("en='Address is not filled in.';ru='Адрес не заполнен.'");
			
			If ResultByGroups Then
				Result = New Array;
				Result.Add(New Structure("Fields, ErrorTypes, Message", New Array,
					"MandatoryFieldsAreNotFilledIn", ErrorText
				)); 
			Else
				Result = New ValueList;
				Result.Add("/", ErrorText);
			EndIf;
			
			Return Result
		EndIf;
		
		// Address is empty and should not be filled in - consider it correct.
		Return ?(ResultByGroups, New Array, New ValueList);
	EndIf;
	
	AllErrors = FillAddressesCommonErrorGroups(AddressRF, CheckCheckBoxes);
	CheckClassifier = True;
	
	For Each Group In AllErrors Do
		If Find("FieldsAbbreviationsNotSpecified, ProhibitedFieldsCharacters", Group.ErrorType) > 0 Then
			// There is incorrect data in the fields, there is no point checking it by the classifier.
			CheckClassifier = False;
			Break;
		EndIf
	EndDo;
	
	ErrorsClassifier = New ValueList;
	If CheckClassifier AND CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		FillAddressErrorsByClassifier(AddressRF, CheckCheckBoxes, ErrorsClassifier);
	EndIf;
		
	If ResultByGroups Then
		GroupDescriptionErrors = "ErrorsOnClassifier";
		ErrorsCount = ErrorsClassifier.Count();
		
		If ErrorsCount = 1 AND ErrorsClassifier[0].Value <> Undefined
			AND ErrorsClassifier[0].Value.PathXPath = Undefined 
		Then
			AllErrors.Add(GroupOfErrorsOfAddress(GroupDescriptionErrors, ErrorsClassifier[0].Presentation));
			
		ElsIf ErrorsCount > 0 Then
			// Errors detailed description
			AllErrors.Add(GroupOfErrorsOfAddress(GroupDescriptionErrors,
				NStr("en='Parts of the address do not correspond to the address classifier:';ru='Части адреса не соответствуют адресному классификатору:'")));
				
			ClassifierErrorGroup = AllErrors[AllErrors.UBound()];
			
			ListOfCompanies = "";
			For Each Item In ErrorsClassifier Do
				ItemErrors = Item.Value;
				If ItemErrors = Undefined Then
					// Abstract error
					AddErrorFillAddresses(ClassifierErrorGroup, "", Item.Presentation);
				Else
					AddErrorFillAddresses(ClassifierErrorGroup, ItemErrors.PathXPath, Item.Presentation);
					ListOfCompanies = ListOfCompanies + ", " + ItemErrors.FieldEssence;
				EndIf;
			EndDo;
			
			ClassifierErrorGroup.Message = ClassifierErrorGroup.Message + Mid(ListOfCompanies, 2);
		EndIf;
		
		Return AllErrors;
	EndIf;
	
	// Merge all to a list
	Result = New ValueList;
	For Each Group In AllErrors Do
		For Each Field In Group.Fields Do
			Result.Add(Field.FieldName, Field.Message);
		EndDo;
	EndDo;
	For Each ItemOfList In ErrorsClassifier Do
		Result.Add(ItemOfList.Value.PathXPath, ItemOfList.Presentation, ItemOfList.Value.AddressChecked);
	EndDo;
	
	Return Result;
EndFunction

// General checkings to address correctness.
//
//  Parameters:
//      DataAddresses  - String, ValuesList - XML, XDTO with RF address data.
//      InformationKind - CatalogRef.ContactInformationTypes - ref to the corresponding contact information kind.
//
// Returns:
//      Array - contains structures with fields:
//         * ErrorType - String - identifier groups Errors. Possible values are:
//              PresentationNotCorrespondToFieldsSet
//              MandatoryFieldsNotFilled
//              FieldsAbbreviationsNotSpecified
//              InvalidFieldsCharacters
//              NotCorrespondFieldsLength
//         * Message - String - Detailed error text.
//         * Fields - Array of structures with fields:
//             ** FieldName - internal identifier of an erroneous field.
//             ** Message - detailed error text for a field.
//
Function FillAddressesCommonErrorGroups(Val DataAddresses, Val InformationKind) Export
	Result = New Array;
	
	If TypeOf(DataAddresses) = Type("XDTODataObject") Then
		AddressRF = DataAddresses;
		
	Else
		XDTOContact = XMLBXDTOAddress(DataAddresses);
		Address = XDTOContact.Content;
		If Not ItsRussianAddress(Address) Then
			Return Result;
		EndIf;
		AddressRF = Address.Content;
		
		// C) presentation and data set match.
		Presentation = AddressPresentation(AddressRF, InformationKind);
		If XDTOContact.Presentation <> Presentation Then
			Result.Add(GroupOfErrorsOfAddress("PresentationNotCorrespondsSetOfFields",
				NStr("en='The address does not match the field set values.';ru='Адрес не соответствует значениям в наборе полей.'")));
			AddErrorFillAddresses(Result[0], "",
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Address presentation for contact information kind ""%1"" is different from address data.';ru='Представление адреса для вида контактной информации ""%1"" отличается от данных в адресе.'"),
					String(InformationKind.Description)));
		EndIf;
	EndIf;
	
	MandatoryFieldsAreNotFilledIn = GroupOfErrorsOfAddress("MandatoryFieldsAreNotFilledIn",
		NStr("en='Required fields are not entered:';ru='Не заполнены обязательные поля:'"));
	Result.Add(MandatoryFieldsAreNotFilledIn);
	
	NoReductionInFields = GroupOfErrorsOfAddress("NoReductionInFields",
		NStr("en='Abbreviations are not specified for fields:';ru='Не указано сокращение для полей:'"));
	Result.Add(NoReductionInFields);
	
	ProhibitedCharsFields = GroupOfErrorsOfAddress("ProhibitedCharsFields",
		NStr("en='Invalid characters are found in fields:';ru='Найдены недопустимые символы в полях:'"));
	Result.Add(ProhibitedCharsFields);
	
	NotCorrespondingFieldsLength = GroupOfErrorsOfAddress("NotCorrespondingFieldsLength",
		NStr("en='Field length does not match the predefined value for fields:';ru='Не соответствует установленной длина полей:'"));
	Result.Add(NotCorrespondingFieldsLength);
	
	// 2) ZipCode, State, House should be filled in.
	IndexOf = PostalIndexOfAddresses(AddressRF);
	If IsBlankString(IndexOf) Then
		AddErrorFillAddresses(MandatoryFieldsAreNotFilledIn, ContactInformationManagementClientServerReUse.XMailPathIndex(),
			NStr("en='Zip code is not specified.';ru='Не указан почтовый индекс.'"), "IndexOf");
	EndIf;
	
	State = AddressRF.RFTerritorialEntity;
	If IsBlankString(State) Then
		AddErrorFillAddresses(MandatoryFieldsAreNotFilledIn, "RFTerritorialEntity",
			NStr("en='Region is not specified.';ru='Не указан регион.'"), "State");
	EndIf;
	
	BuildingsPremises = BuildingsAndFacilitiesAddresses(AddressRF);
	If ExcludeTestHomeInAddress(AddressRF) Then
		// At least one building should be filled in.
		
		BuildingIsNotSpecified = True;
		For Each HousesData In BuildingsPremises.Buildings Do
			If Not IsBlankString(HousesData.Value) Then
				BuildingIsNotSpecified = False;
				Break;
			EndIf;
		EndDo;
		If BuildingIsNotSpecified Then
			AddErrorFillAddresses(MandatoryFieldsAreNotFilledIn, 
				ContactInformationManagementClientServerReUse.XNumberOfAdditionalObjectPathAddressing("House"),
				NStr("en='House or block is not specified.';ru='Не указан дом или корпус'"), 
				NStr("en='House';ru='дом'")
			);
		EndIf;
			
	Else
		// House (ownership etc) must be specified with a possible specification of block, construction etc.
		
		HousesData = BuildingsPremises.Buildings.Find(1, "Kind");	// 1 - Kind by ownership feature.
		If HousesData = Undefined Then
			AddErrorFillAddresses(MandatoryFieldsAreNotFilledIn, 
				ContactInformationManagementClientServerReUse.XNumberOfAdditionalObjectPathAddressing("House"),
				NStr("en='House or estate is not specified.';ru='Не указан дом или владение (домовладение).'"),
				NStr("en='House';ru='дом'")
			);
		ElsIf IsBlankString(HousesData.Value) Then
			AddErrorFillAddresses(MandatoryFieldsAreNotFilledIn, HousesData.PathXPath,
				NStr("en='Value of the house or estate is not entered.';ru='Не заполнено значение дома или владения (домовладения).'"),
				NStr("en='House';ru='дом'")
			);
		EndIf;
		
	EndIf;
	
	// 3) State, Region, City, Settlement, Street should:    
	//      - have abbreviation
	//      - not longer than 50 characters
	//      - only Cyrillic
	
	PermissibleNotCyrillic = "/,-. 0123456789_";
	
	// State
	If Not IsBlankString(State) Then
		Field = "RFTerritorialEntity";
		If IsBlankString(ContactInformationManagementClientServer.Abbr(State)) Then
			AddErrorFillAddresses(NoReductionInFields, "RFTerritorialEntity",
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Abbreviation is not specified in the name of region ""%1"".';ru='Не указано сокращение в названии региона ""%1"".'"), State
				), NStr("en='State';ru='Состояние'"));
		EndIf;
		If StrLen(State) > 50 Then
			AddErrorFillAddresses(NotCorrespondingFieldsLength, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Name of region ""%1"" should be less than 50 characters.';ru='Название региона ""%1"" должно быть короче 50 символов.'"), State
				), NStr("en='State';ru='Состояние'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(State, False, PermissibleNotCyrillic) Then
			AddErrorFillAddresses(ProhibitedCharsFields, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Region name ""%1"" contains non-latin characters.';ru='В названии региона ""%1"" есть не кириллические символы.'"), State
				), NStr("en='State';ru='Состояние'"));
		EndIf
	EndIf;
	
	// Region
	Region = RegionAddresses(AddressRF);
	If Not IsBlankString(Region) Then
		Field = ContactInformationManagementClientServerReUse.RegionXPath();
		If IsBlankString(ContactInformationManagementClientServer.Abbr(Region)) Then
			AddErrorFillAddresses(NoReductionInFields, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Abbreviation is not specified in the name of district ""%1"".';ru='Не указано сокращение в названии района ""%1"".'"), Region
				), NStr("en='Region';ru='Регион'"));
		EndIf;
		If StrLen(Region) > 50 Then
			AddErrorFillAddresses(NotCorrespondingFieldsLength, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Name of district ""%1"" should be less than 50 characters.';ru='Название района ""%1"" должно быть короче 50 символов.'"), Region
				), NStr("en='Region';ru='Регион'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(Region, False, PermissibleNotCyrillic) Then
			AddErrorFillAddresses(ProhibitedCharsFields, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='District name ""%1"" contains non-latin characters.';ru='В названии района ""%1"" есть не кириллические символы.'"), Region
				), NStr("en='Region';ru='Регион'"));
		EndIf;
	EndIf;
	
	// City
	City = AddressRF.City;
	If Not IsBlankString(City) Then
		Field = "City";
		If IsBlankString(ContactInformationManagementClientServer.Abbr(City)) Then
			AddErrorFillAddresses(NoReductionInFields, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Abbreviation is not specified in the name of city ""%1"".';ru='Не указано сокращение в названии города ""%1"".'"), City
				), NStr("en='City';ru='Город'"));
		EndIf;
		If StrLen(City) > 50 Then
			AddErrorFillAddresses(NotCorrespondingFieldsLength, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='City name ""%1"" should be less than 50 characters.';ru='Название города ""%1"" должно быть короче 50 символов.'"), City
				), NStr("en='City';ru='Город'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(City, False, PermissibleNotCyrillic) Then
			AddErrorFillAddresses(ProhibitedCharsFields, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='City name ""%1"" contains non-Latin characters.';ru='В названии города ""%1"" есть не кириллические символы.'"), City
				), NStr("en='City';ru='Город'"));
		EndIf;
	EndIf;
	
	// Settlement
	Settlement = AddressRF.Settlement;
	If Not IsBlankString(Settlement) Then
		Field = "Settlement";
		If IsBlankString(ContactInformationManagementClientServer.Abbr(Settlement)) Then
			AddErrorFillAddresses(NoReductionInFields, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Abbreviation is not specified in the settlement name ""%1"".';ru='Не указано сокращение в названии населенного пункта ""%1"".'"), Settlement
				), NStr("en='Settlement';ru='НаселПункт'"));
		EndIf;
		If StrLen(Settlement) > 50 Then
			AddErrorFillAddresses(NotCorrespondingFieldsLength, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Name of settlement ""%1"" should be less than 50 characters.';ru='Название населенного пункта ""%1"" должно быть короче 50 символов.'"), Settlement
				), NStr("en='Settlement';ru='НаселПункт'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(Settlement, False, PermissibleNotCyrillic) Then
			AddErrorFillAddresses(ProhibitedCharsFields, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Settlement name ""%1"" contains non-Latin characters.';ru='В названии населенного пункта ""%1"" есть не кириллические символы.'"), Settlement
				), NStr("en='Settlement';ru='НаселПункт'"));
		EndIf;
	EndIf;
	
	// Street
	Street = AddressRF.Street;
	If Not IsBlankString(Street) Then
		Field = "Street";
		If IsBlankString(ContactInformationManagementClientServer.Abbr(Street)) Then
			AddErrorFillAddresses(NoReductionInFields, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Abbreviation is not specified in the name of street ""%1"".';ru='Не указано сокращение в названии улицы ""%1"".'"), Street
				), NStr("en='Street';ru='Улица'"));
		EndIf;
		If StrLen(Region) > 50 Then
			AddErrorFillAddresses(NotCorrespondingFieldsLength, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Name of street ""%1"" should be less than 50 characters.';ru='Название улицы ""%1"" должно быть короче 50 символов.'"), Street
				), NStr("en='Street';ru='Улица'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(Street, False, PermissibleNotCyrillic) Then
			AddErrorFillAddresses(ProhibitedCharsFields, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Street name ""%1"" contains non-latin characters.';ru='В названии улицы ""%1"" есть не кириллические символы.'"), Street
				), NStr("en='Street';ru='Улица'"));
		EndIf;
	EndIf;
	
	// Additional item
	AdditionalItem = FindAdditionalAddressItem(AddressRF);
	If ValueIsFilled(AdditionalItem) Then
		Field = "Street";
		If IsBlankString(ContactInformationManagementClientServer.Abbr(AdditionalItem)) Then
			AddErrorFillAddresses(NoReductionInFields, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Abbreviation of additional item ""%1"" is not specified.';ru='Не указано сокращение у дополнительного элемента ""%1"".'"), AdditionalItem
				), NStr("en='Street';ru='Улица'"));
		EndIf;
		If StrLen(Region) > 50 Then
			AddErrorFillAddresses(NotCorrespondingFieldsLength, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Additional item name ""%1"" should be less than 50 characters.';ru='Название дополнительного элемента ""%1"" должно быть короче 50 символов.'"), AdditionalItem
				), NStr("en='AdditionalItem';ru='AdditionalItem'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(AdditionalItem, False, PermissibleNotCyrillic) Then
			AddErrorFillAddresses(ProhibitedCharsFields, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Additional item name ""%1"" contains non-latin characters.';ru='В названии дополнительного элемента ""%1"" есть не кириллические символы.'"), AdditionalItem
				), NStr("en='AdditionalItem';ru='AdditionalItem'"));
		EndIf;
	EndIf;
	
	// 4) Index - if there are, then 6 digits.
	If Not IsBlankString(IndexOf) Then
		Field = ContactInformationManagementClientServerReUse.XMailPathIndex();
		If StrLen(IndexOf) <> 6 Or Not StringFunctionsClientServer.OnlyNumbersInString(IndexOf) Then
			AddErrorFillAddresses(NotCorrespondingFieldsLength, Field,
				NStr("en='Zip code should contain 6 digits.';ru='Почтовый индекс должен состоять из 6 цифр.'"),
				NStr("en='Index';ru='Индекс'")
			);
		EndIf;
	EndIf;
	
	// 5) House, Block, Apartment is not longer than 10 characters.
	For Each DataBuildings In BuildingsPremises.Buildings Do
		If StrLen(DataBuildings.Value) > 10 Then
			AddErrorFillAddresses(NotCorrespondingFieldsLength, DataBuildings.PathXPath,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Value of field ""%1"" must be shorter than 10 characters.';ru='Значение поля ""%1"" должно быть короче 10 символов.'"), DataBuildings.Type
				), DataBuildings.Type);
		EndIf;
	EndDo;
	For Each DataPremises In BuildingsPremises.Units Do
		If StrLen(DataPremises.Value) > 10 Then
			AddErrorFillAddresses(NotCorrespondingFieldsLength, DataPremises.PathXPath,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en='Value of field ""%1"" must be shorter than 10 characters.';ru='Значение поля ""%1"" должно быть короче 10 символов.'"), DataPremises.Type
				), DataPremises.Type);
		EndIf;
	EndDo;
	
	// 6) The City and Settlement fields may be empty at the same time only in state - federal city.
	If IsBlankString(City) AND IsBlankString(Settlement) Then
		If CityNamesFederalValues().Find(Upper(State)) = Undefined Then
			AddErrorFillAddresses(MandatoryFieldsAreNotFilledIn, "City",
				NStr("en='You do not have to specify a city just in region - federal city.';ru='Город может быть не указан только в регионе - городе федерального значения.'"),
				NStr("en='City';ru='Город'")
			);
			AddErrorFillAddresses(MandatoryFieldsAreNotFilledIn, "Settlement",
				NStr("en='You cannot specify a settlement just in region - federal city.';ru='Населенный пункт может быть не указан только в регионе - городе федерального значения.'"),
				NStr("en='Settlement';ru='НаселПункт'")
			);
		EndIf;
	EndIf;
	
	// 7) The street can not be empty if Settlement is empty.
	If Not CheckOutStreetsInAddress(AddressRF) Then
		
		 
		If IsBlankString(Settlement) AND IsBlankString(Street) AND Not ValueIsFilled(AdditionalItem) Then
			AddErrorFillAddresses(MandatoryFieldsAreNotFilledIn, "Street",
				NStr("en='City or settlement should include a street name.';ru='Город или населенный пункт должен содержать название улицы.'"), 
				NStr("en='Street';ru='Улица'")
			);
		EndIf;
		
	EndIf;
	
	// All. Remove empty results, correct group message.
	For IndexOf = 1-Result.Count() To 0 Do
		Group = Result[-IndexOf];
		Fields = Group.Fields;
		ListOfCompanies = "";
		For FieldIndex = 1-Fields.Count() To 0 Do
			Field = Fields[-FieldIndex];
			If IsBlankString(Field.Message) Then
				Fields.Delete(-FieldIndex);
			Else
				ListOfCompanies = ", " + Field.FieldEssence + ListOfCompanies;
				Field.Delete("FieldEssence");
			EndIf;
		EndDo;
		If Fields.Count() = 0 Then
			Result.Delete(-IndexOf);
		ElsIf Not IsBlankString(ListOfCompanies) Then
			Group.Message = Group.Message + Mid(ListOfCompanies, 2);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Local exceptions during an address check.
//
Function ExcludeTestHomeInAddress(Val AddressRF)
	Result = False;
	
	// In Zelenograd a block without house/ownership can be specified.
	If Upper(TrimAll(AddressRF.RFTerritorialEntity)) = NStr("en='MOSCOW';ru='МОСКВА Г'") AND Upper(TrimAll(AddressRF.City)) = NStr("en='ZELENOGRAD';ru='ЗЕЛЕНОГРАД Г'") Then
		Result = True;
	EndIf;
		
	Return Result;
EndFunction

// Local exceptions during an address check.
//
Function CheckOutStreetsInAddress(Val AddressRF)
	Result = False;
	
	// Do not check the streets in Zelenograd.
	If Upper(TrimAll(AddressRF.RFTerritorialEntity)) = NStr("en='MOSCOW';ru='МОСКВА Г'") AND Upper(TrimAll(AddressRF.City)) = NStr("en='ZELENOGRAD';ru='ЗЕЛЕНОГРАД Г'") Then
		Result = True;
	EndIf;
	
	// Additional items of the address may be without streets.
	AdditionalItems = AdditionalItemsValues(AddressRF);
	If ValueIsFilled(AdditionalItems.AdditionalItem) Then
		Result = True;
	EndIf;
		
	Return Result;
EndFunction

//  Returns an array of states names - federal cities.
Function CityNamesFederalValues() Export
	
	Result = New Array;
	Result.Add("MOSCOW C");
	Result.Add("SAINT-PETERSBURG C");
	Result.Add("SEVASTOPOL C");
	Result.Add("BAIKONUR C");
	
	Return Result;
EndFunction

Function PresentationPhone(XDTOData) Export
	
	Return ContactInformationManagementClientServer.GeneratePhonePresentation(
		ReduceDigits(XDTOData.CountryCode), 
		XDTOData.CityCode,
		XDTOData.Number,
		XDTOData.Supplementary,
		"");
		
EndFunction

//  Returns fax presentation.
//
//  Parameters:
//      XDTOData    - XDTODataObject - contact information.
//      InformationKind - CatalogRef.ContactInformationTypes - ref to the corresponding contact information kind.
//
// Returns:
//      String - presentation.
//
Function FaxPresentation(XDTOData, InformationKind = Undefined) Export
	Return ContactInformationManagementClientServer.GeneratePhonePresentation(
		ReduceDigits(XDTOData.CountryCode), 
		XDTOData.CityCode,
		XDTOData.Number,
		XDTOData.Supplementary,
		"");
EndFunction    

// Returns the check box showing that the current user can import or clear an address classifier.
//
// Returns:
//     Boolean - checking result.
//
Function IsAbilityToChangesOfAddressClassifier() Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ObjectControl = Metadata.InformationRegisters.Find("AddressObjects");
		Return ObjectControl <> Undefined AND AccessRight("Update", ObjectControl) AND Not CommonUseReUse.DataSeparationEnabled();
	EndIf;
	
	Return False;
	
EndFunction

// Structure designer compatible by fields with catalogs of the KI kind.
//
// Parameters:
//     Source - CatalogRef.ContactInformationTypes - optional data source for filling.
//
// Returns:
//     Structure - compatible by fields with KI kinds catalogs.
//
Function StructureTypeContactInformation(Val Source = Undefined) Export
	
	AttributesMetadata = Metadata.Catalogs.ContactInformationKinds.Attributes;
	
	If TypeOf(Source) = Type("CatalogRef.ContactInformationKinds") Then
		Attributes = "Description";
		For Each AttributeMetadata In AttributesMetadata Do
			Attributes = Attributes + "," + AttributeMetadata.Name;
		EndDo;
		
		Return CommonUse.ObjectAttributesValues(Source, Attributes);
	EndIf;
	
	Result = New Structure("Description", "");
	For Each AttributeMetadata In AttributesMetadata Do
		Result.Insert(AttributeMetadata.Name, AttributeMetadata.Type.AdjustValue());
	EndDo;
	If Source <> Undefined Then
		FillPropertyValues(Result, Source);
	EndIf;
	
	Return Result;
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctionsForCompatibility

// Returns fields of a contact information.
//
// Parameters:
//   XDTOContactInformation - XDTOObject, Row - contact information or XML row.
//   FieldsOldContent        - Boolean - optional check box showing that the
//                                          fields absent in the SSL versions under 2 are removed from fields.1.3.
//
// Returns:
//   Structure - data. Contains fields:
//     * Presentation        - String - address presentation.
//     * FieldValues        - ValueList - values. Content of values for address:
//        ** Country           - String - text presentation of a country.
//        ** CountryCode        - String - country code by OKSM.
//        ** Index           - String - postal code (only for RF addresses).
//        ** State           - String - text presentation of the RF territorial entity (only for RF addresses).
//        ** StateCode       - String - RF territorial entity code (only for RF addresses).
//        ** StateAbbr - String - abbr region (if FieldsOldContent = False).
//        ** Region            - String - text presentation of a region (only for RF addresses).
//        ** RegionAbbr  - String - abbr district (if FieldsOldContent = False).
//        ** City            - String - text presentation of a city (only for RF addresses).
//        ** CityAbbreviation  - String - city abbreviation (only for RF addresses).
//        ** Settlement  - String - text presentation of the locality (only for RF addresses).
//        ** SettlementAbbreviation - abbr inhabited locality (if FieldsOldContent = False).
//        ** HouseType          - String - cm. TypesOfAddressingAddressesRF().
//        ** House              - String - text presentation of a house (only for RF addresses).
//        ** HouseType       - String - cm. TypesOfAddressingAddressesRF().
//        ** Block           - String - text presentation of a block (only for RF addresses).
//        ** ApartmentType      - String - cm. TypesOfAddressingAddressesRF().
//        ** Apartment         - String - text presentation of an apartment (only for RF addresses).
//       Content of values for phone:
//        ** CountryCode        - String - code Countries. ForExample, +7.
//        ** CityCode        - String - city code. For example, 495.
//        ** PhoneNumber    - String - phone number.
//        ** Supplementary       - String - additional phone number.
//
Function ContactInformationInOldStructure(XDTOContactInformation, FieldsOldContent = False) Export
	
	If ContactInformationClientServer.IsXMLString(XDTOContactInformation) Then
		XDTOContact = ContactInformationFromXML(XDTOContactInformation);
	Else
		XDTOContact = XDTOContactInformation
	EndIf;
	
	Result = New Structure("Presentation, FieldsValues", XDTOContact.Presentation, New ValueList);
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	Content = XDTOContact.Content;
	
	If Content = Undefined Then
		Return Result;
	EndIf;
	
	Type = Content.Type();
	If Type = XDTOFactory.Type(TargetNamespace, "Address") Then
		Result.FieldsValues = AddressInOldFieldList(Content, Not FieldsOldContent);
		Result.FieldsValues.Add(Result.Presentation, "Presentation");
		
	ElsIf Type = XDTOFactory.Type(TargetNamespace, "PhoneNumber") Then
		Result.FieldsValues = PhoneNumberInOldFieldList(Content);
		Result.FieldsValues.Add(XDTOContact.Comment, "Comment");
		
	EndIf;
	
	Return Result;
EndFunction

// Converts the XDTO format address to an old list of fields of the ValuesList type.
//
// Parameters:
//     XDTOAddress               - XDTOObject, Row - contact information or XML row.
//     ExtendedFieldContent - Boolean - optional check box showing that the fields content
//                                     will be reduced for a compatibility with SSL 2 exchange.1.2.
//
//  Returns:
//     ValueList 
//
Function AddressInOldFieldList(XDTOAddress, ExtendedFieldContent = True) Export
	List = New ValueList;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	XDTOType = XDTOAddress.Type();
	If XDTOType = XDTOFactory.Type(TargetNamespace, "Address") Then
		
		// Country with code
		AddValue(List, "Country", XDTOAddress.Country);
		If IsBlankString(XDTOAddress.Country) Then
			CountryCode = "";
		Else
			Country = Catalogs.WorldCountries.FindByDescription(XDTOAddress.Country, True);
			CountryCode = TrimAll(Country.Code);
		EndIf;
		AddValue(List, "CountryCode", CountryCode);
		
		If Not ItsRussianAddress(XDTOAddress) Then
			Return List;
		EndIf;
		
		AddressRF = XDTOAddress.Content;
		
	ElsIf XDTOType = XDTOFactory.Type(TargetNamespace, "AddressRF") Then
		AddressRF = XDTOAddress;
		
	Else
		Return List;
		
	EndIf;
	
	AddValue(List, "IndexOf", PostalIndexOfAddresses(AddressRF) );
	
	AddValue(List, "State", AddressRF.RFTerritorialEntity);
	AddValue(List, "StateCode", StateCode(AddressRF.RFTerritorialEntity) );
	If ExtendedFieldContent Then
		AddValue(List, "StateAbbr", ContactInformationManagementClientServer.Abbr(AddressRF.RFTerritorialEntity));
	EndIf;
	
	Region = RegionAddresses(AddressRF);
	AddValue(List, "Region", Region);
	If ExtendedFieldContent Then
		AddValue(List, "RegionAbbr", ContactInformationManagementClientServer.Abbr(Region));
	EndIf;
	
	AddValue(List, "City", AddressRF.City);
	If ExtendedFieldContent Then
		AddValue(List, "CityAbbr", ContactInformationManagementClientServer.Abbr(AddressRF.City));
	EndIf;
	
	AddValue(List, "Settlement", AddressRF.Settlement);
	If ExtendedFieldContent Then
		AddValue(List, "SettlementAbbr", ContactInformationManagementClientServer.Abbr(AddressRF.Settlement));
	EndIf;
	
	AddValue(List, "Street", AddressRF.Street);
	If ExtendedFieldContent Then
		AddValue(List, "StreetAbbr", ContactInformationManagementClientServer.Abbr(AddressRF.Street));
	EndIf;
	
	// House and block
	BuildingsAndFacilities = BuildingsAndFacilitiesAddresses(AddressRF);
	
	ObjectParameters = BuildingOrRoomValue(BuildingsAndFacilities.Buildings, VariantsDataHouse(), ExtendedFieldContent);
	If ObjectParameters.Count() = 0 Then
		AddValue(List, "HouseType", "");
		AddValue(List, "House",     "");
	Else
		For Each ObjectString In ObjectParameters Do
			AddValue(List, "HouseType", ObjectString.Type,      ExtendedFieldContent);
			AddValue(List, "House",     ObjectString.Value, ExtendedFieldContent);
		EndDo;
	EndIf;
	
	ObjectParameters = BuildingOrRoomValue(BuildingsAndFacilities.Buildings, VariantsDataConstruction(), ExtendedFieldContent);
	If ObjectParameters.Count() = 0 Then
			AddValue(List, "BlockType", "");
			AddValue(List, "Block",     "");
	Else
		For Each ObjectString In ObjectParameters Do
			AddValue(List, "BlockType", ObjectString.Type,      ExtendedFieldContent);
			AddValue(List, "Block",     ObjectString.Value, ExtendedFieldContent);
		EndDo;
	EndIf;
	
	ObjectParameters = BuildingOrRoomValue(BuildingsAndFacilities.Units, VariantsOfDataPlace(), ExtendedFieldContent);
	If ObjectParameters.Count() = 0 Then
		AddValue(List, "ApartmentType", "");
		AddValue(List, "Apartment",    "");
	Else
		For Each ObjectString In ObjectParameters Do	
			AddValue(List, "ApartmentType", ObjectString.Type,      ExtendedFieldContent);
			AddValue(List, "Apartment",    ObjectString.Value, ExtendedFieldContent);
		EndDo;
	EndIf;
	
	Return List;
EndFunction

Procedure AddValue(List, FieldName, Value, AllowDoubles = False)
	
	If Not AllowDoubles Then
		For Each Item In List Do
			If Item.Presentation = FieldName Then
				Item.Value = String(Value);
				Return;
			EndIf;
		EndDo;
	EndIf;
	
	List.Add(String(Value), FieldName);
EndProcedure

Function BuildingOrRoomValue(Data, Variants, AllValuesOptions)
	Result = ValueTable("Type, Value");
	
	For Each Variant In Variants.TypeOptions Do
		For Each String In Data.FindRows(New Structure("Type", Variant)) Do
			FillPropertyValues(Result.Add(), String);
			If Not AllValuesOptions Then
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
EndFunction

Function PhoneNumberInOldFieldList(XDTOPhone)
	Result = New ValueList;
	
	Result.Add(XDTOPhone.CountryCode,  "CountryCode");
	Result.Add(XDTOPhone.CityCode,  "CityCode");
	Result.Add(XDTOPhone.Number,      "PhoneNumber");
	Result.Add(XDTOPhone.Supplementary, "Supplementary");
	
	Return Result;
EndFunction

Function GroupOfErrorsOfAddress(ErrorType, Message)
	Return New Structure("ErrorType, Message, Fields", ErrorType, Message, New Array);
EndFunction

Procedure AddErrorFillAddresses(Group, FieldName = "", Message = "", FieldEssence = "")
	Group.Fields.Add(New Structure("FieldName, Message, FieldEssence", FieldName, Message, FieldEssence));
EndProcedure

Procedure FillAddressErrorsByClassifier(XDTOAddressRF, CheckCheckBoxes, Result)
	
	Addresses = New Array;
	
	If CheckCheckBoxes.CheckValidity Then
		Addresses.Add( New Structure("Address, AddressFormat", XDTOAddressRF, "AC") );
	EndIf;
	
	If Addresses.Count() = 0 Then
		Return;
	EndIf;
	
	ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
	AnalysisResults = ModuleAddressClassifierService.AddressesCheckResultByClassifier(Addresses);
	If AnalysisResults.Cancel Then
		Result.Add( New Structure("PathXPath, FieldEssence, AddressChecked", "/",, False), AnalysisResults.BriefErrorDescription);
		Return;
	EndIf;
	
	// Only unique errors - the address could be checked two times.
	Processed = New Map;
	For Each CheckResult In AnalysisResults.Data Do
		If CheckResult.AddressChecked Then
			For Each AddressError In CheckResult.Errors Do
				Key = AddressError.Key;
				If Processed[Key] = Undefined Then
					Result.Add(New Structure("PathXPath, FieldEssence, AddressChecked", Key,, CheckResult.AddressChecked), 
						TrimAll(AddressError.Text + Chars.LF + AddressError.ToolTip));
					Processed[Key] = True;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

// Values table constructor.
//
Function ValueTable(ListColumns, ListOfIndexes = "")
	ResultTable = New ValueTable;
	
	For Each KeyValue In (New Structure(ListColumns)) Do
		ResultTable.Columns.Add(KeyValue.Key);
	EndDo;
	
	RowsIndex = StrReplace(ListOfIndexes, "|", Chars.LF);
	For PostalCodeNumber = 1 To StrLineCount(RowsIndex) Do
		IndexColumns = TrimAll(StrGetLine(RowsIndex, PostalCodeNumber));
		For Each KeyValue In (New Structure(IndexColumns)) Do
			ResultTable.Indexes.Add(KeyValue.Key);
		EndDo;
	EndDo;
	
	Return ResultTable;
EndFunction

// Inner for serialization.
Function AddressDeserializationCommon(Val FieldsValues, Val Presentation, Val ExpectedType = Undefined)
	
	If ContactInformationClientServer.IsXMLString(FieldsValues) Then
		// General format of a contact information.
		Return ContactInformationFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	If ExpectedType <> Undefined Then
		If ExpectedType <> Enums.ContactInformationTypes.Address Then
			Raise NStr("en='An error occurred when deserializing the contact information, address is expected';ru='Ошибка десериализации контактной информации, ожидается адрес'");
		EndIf;
	EndIf;
	
	// An old format through rows delimiter and equality.
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	
	Result = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "ContactInformation"));
	
	Result.Comment = "";
	Result.Content      = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "Address"));
	
	AddressRussian = True;
	NameOfRussia  = Upper(Catalogs.WorldCountries.Russia.Description);
	
	ItemApartment = Undefined;
	ItemBlock   = Undefined;
	ItemHouse      = Undefined;
	
	// Russian
	AddressRF = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "AddressRF"));
	
	// Common content
	Address = Result.Content;
	
	TypeValuesFields = TypeOf(FieldsValues);
	If TypeValuesFields = Type("ValueList") Then
		FieldList = FieldsValues;
	ElsIf TypeValuesFields = Type("Structure") Then
		FieldList = ContactInformationManagementClientServer.ConvertStringToFieldList(
			ContactInformationManagementClientServer.FieldsRow(FieldsValues, False));
	Else
		// Already converted to a row
		FieldList = ContactInformationManagementClientServer.ConvertStringToFieldList(FieldsValues);
	EndIf;
	
	ApartmentTypeUndefined = True;
	BlockTypeUndefined  = True;
	HouseTypeIsNotDefined     = True;
	PresentationField      = "";
	
	For Each ItemOfList In FieldList Do
		FieldName = Upper(ItemOfList.Presentation);
		
		If FieldName="INDEX" Then
			ItemIndex = CreateItemAdditionalAddress(AddressRF);
			ItemIndex.TypeAdrEl = ContactInformationManagementClientServerReUse.SerializationCodePostalIndex();
			ItemIndex.Value = ItemOfList.Value;
			
		ElsIf FieldName = "COUNTRY" Then
			Address.Country = ItemOfList.Value;
			If Upper(ItemOfList.Value) <> NameOfRussia Then
				AddressRussian = False;
			EndIf;
			
		ElsIf FieldName = "COUNTRYCODE" Then
			;
			
		ElsIf FieldName = "StateCode" Then
			AddressRF.RFTerritorialEntity = StateOfCode(ItemOfList.Value);
			
		ElsIf FieldName = "REGION" Then
			AddressRF.RFTerritorialEntity = ItemOfList.Value;
			
		ElsIf FieldName = "district" Then
			If AddressRF.PrRayMO = Undefined Then
				AddressRF.PrRayMO = XDTOFactory.Create( AddressRF.Type().Properties.Get("PrRayMO").Type )
			EndIf;
			AddressRF.PrRayMO.Region = ItemOfList.Value;
			
		ElsIf FieldName = "CITY" Then
			AddressRF.City = ItemOfList.Value;
			
		ElsIf FieldName = "Settlement" Then
			AddressRF.Settlement = ItemOfList.Value;
			
		ElsIf FieldName = "Street" Then
			AddressRF.Street = ItemOfList.Value;
			
		ElsIf FieldName = "HOUSETYPE" Then
			If ItemHouse = Undefined Then
				ItemHouse = CreateItemAdditionalAddressNumber(AddressRF);
			EndIf;
			ItemHouse.Type = ContactInformationManagementClientServerReUse.AddressingObjectSerializationCode(ItemOfList.Value);
			HouseTypeIsNotDefined = False;
			
		ElsIf FieldName = "HOUSE" Then
			If ItemHouse = Undefined Then
				ItemHouse = CreateItemAdditionalAddressNumber(AddressRF);
			EndIf;
			ItemHouse.Value = ItemOfList.Value;
			
		ElsIf FieldName = "BLOCKTYPE" Then
			If ItemBlock = Undefined Then
				ItemBlock = CreateItemAdditionalAddressNumber(AddressRF);
			EndIf;
			ItemBlock.Type = ContactInformationManagementClientServerReUse.AddressingObjectSerializationCode(ItemOfList.Value);
			BlockTypeUndefined = False;
			
		ElsIf FieldName = "Section" Then
			If ItemBlock = Undefined Then
				ItemBlock = CreateItemAdditionalAddressNumber(AddressRF);
			EndIf;
			ItemBlock.Value = ItemOfList.Value;
			
		ElsIf FieldName = "ApartmentType" Then
			If ItemApartment = Undefined Then
				ItemApartment = CreateItemAdditionalAddressNumber(AddressRF);
			EndIf;
			ItemApartment.Type = ContactInformationManagementClientServerReUse.AddressingObjectSerializationCode(ItemOfList.Value);
			ApartmentTypeUndefined = False;
			
		ElsIf FieldName = "APARTMENT" Then
			If ItemApartment = Undefined Then
				ItemApartment = CreateItemAdditionalAddressNumber(AddressRF);
			EndIf;
			ItemApartment.Value = ItemOfList.Value;
			
		ElsIf FieldName = "PRESENTATION" Then
			PresentationField = TrimAll(ItemOfList.Value);
			
		EndIf;
		
	EndDo;
	
	// Defaults
	If HouseTypeIsNotDefined AND ItemHouse <> Undefined Then
		ItemHouse.Type = ContactInformationManagementClientServerReUse.AddressingObjectSerializationCode("House");
	EndIf;
	
	If BlockTypeUndefined AND ItemBlock <> Undefined Then
		ItemBlock.Type = ContactInformationManagementClientServerReUse.AddressingObjectSerializationCode("Block");
	EndIf;
	
	If ApartmentTypeUndefined AND ItemApartment <> Undefined Then
		ItemApartment.Type = ContactInformationManagementClientServerReUse.AddressingObjectSerializationCode("Apartment");
	EndIf;
	
	// Presentation with priorities.
	If Not IsBlankString(Presentation) Then
		Result.Presentation = Presentation;
	Else
		Result.Presentation = PresentationField;
	EndIf;
	
	Address.Content = ?(AddressRussian, AddressRF, Result.Presentation);
	
	Return Result;
EndFunction

// Returns the check box showing that passed KI object contains data.
//
// Parameters:
//     XDTOData - XDTODataObject - checked data of a contact information.
//
// Returns:
//     Boolean - data existence check box.
//
Function XDTOContactInformationFilled(Val XDTOData) Export
	
	Return HasFilledPropertiesXDTOContactInformation(XDTOData);
	
EndFunction

// Parameters: Owner - XDTOObject, Undefined
//
Function HasFilledPropertiesXDTOContactInformation(Val Owner)
	
	If Owner = Undefined Then
		Return False;
	EndIf;
	
	// List of the ignored on comparing properties of the current owner - specifications of contact information.
	Ignored = New Map;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	OwnerType     = Owner.Type();
	
	If OwnerType = XDTOFactory.Type(TargetNamespace, "Address") Then
		// Country does not affect the filling in if the remainings are empty. Ignore.
		Ignored.Insert(Owner.Properties().Get("Country"), True);
		
	ElsIf OwnerType = XDTOFactory.Type(TargetNamespace, "AddressRF") Then
		// Ignore list with empty values and possibly not empty types.
		List = Owner.GetList("AddEMailAddress");
		If List <> Undefined Then
			For Each ListProperty In List Do
				If IsBlankString(ListProperty.Value) Then
					Ignored.Insert(ListProperty, True);
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	For Each Property In Owner.Properties() Do
		
		If Not Owner.IsSet(Property) Or Ignored[Property] <> Undefined Then
			Continue;
		EndIf;
		
		If Property.UpperBound > 1 Or Property.UpperBound < 0 Then
			List = Owner.GetList(Property);
			
			If List <> Undefined Then
				For Each ItemOfList In List Do
					If Ignored[ItemOfList] = Undefined 
						AND HasFilledPropertiesXDTOContactInformation(ItemOfList) 
					Then
						Return True;
					EndIf;
				EndDo;
			EndIf;
			
			Continue;
		EndIf;
		
		Value = Owner.Get(Property);
		If TypeOf(Value) = Type("XDTODataObject") Then
			If HasFilledPropertiesXDTOContactInformation(Value) Then
				Return True;
			EndIf;
			
		ElsIf Not IsBlankString(Value) Then
			Return True;
			
		EndIf;
		
	EndDo;
		
	Return False;
EndFunction

Procedure InsertBuildingUnit(XDTOAddress, Type, Value)
	If IsBlankString(Value) Then
		Return;
	EndIf;
	
	Record = XDTOAddress.Get(ContactInformationManagementClientServerReUse.XNumberOfAdditionalObjectPathAddressing(Type) );
	If Record = Undefined Then
		Record = XDTOAddress.AddEMailAddress.Add( XDTOFactory.Create(XDTOAddress.AddEMailAddress.OwningProperty.Type) );
		Record.Number = XDTOFactory.Create(Record.Properties().Get("Number").Type);
		Record.Number.Value = Value;
		
		TypeCode = ContactInformationManagementClientServerReUse.AddressingObjectSerializationCode(Type);
		If TypeCode = Undefined Then
			TypeCode = Type;
		EndIf;
		Record.Number.Type = TypeCode
	Else        
		Record.Value = Value;
	EndIf;
	
EndProcedure

Function CreateItemAdditionalAddressNumber(AddressRF)
	AddEMailAddress = CreateItemAdditionalAddress(AddressRF);
	AddEMailAddress.Number = XDTOFactory.Create(AddEMailAddress.Type().Properties.Get("Number").Type);
	Return AddEMailAddress.Number;
EndFunction

Function CreateItemAdditionalAddress(AddressRF)
	ItemAdditionalAddressProperty = AddressRF.AddEMailAddress.OwningProperty;
	ItemAdditionalAssress = XDTOFactory.Create(ItemAdditionalAddressProperty.Type);
	AddressRF.AddEMailAddress.Add(ItemAdditionalAssress);
	Return ItemAdditionalAssress;
EndFunction

Function PrRayMO(AddressRF)
	If AddressRF.PrRayMO <> Undefined Then
		Return AddressRF.PrRayMO;
	EndIf;
	
	AddressRF.PrRayMO = XDTOFactory.Create( AddressRF.Properties().Get("PrRayMO").Type );
	Return AddressRF.PrRayMO;
EndFunction

Function DeserializationPhoneFax(FieldsValues, Presentation = "", ExpectedType = Undefined)
	
	If ContactInformationClientServer.IsXMLString(FieldsValues) Then
		// General format of a contact information.
		Return ContactInformationFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	
	If ExpectedType = Enums.ContactInformationTypes.Phone Then
		Data = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "PhoneNumber"));
		
	ElsIf ExpectedType=Enums.ContactInformationTypes.Fax Then
		Data = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "FaxNumber"));
		
	ElsIf ExpectedType=Undefined Then
		// Count as phone
		Data = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "PhoneNumber"));
		
	Else
		Raise NStr("en='An error occurred when deserializing the contact information, phone number or fax is expected';ru='Ошибка десериализации контактной информации, ожидается телефон или факс'");
	EndIf;
	
	Result = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "ContactInformation"));
	Result.Content        = Data;
	
	// From the key-value pairs
	ValueListFields = Undefined;
	If TypeOf(FieldsValues)=Type("ValueList") Then
		ValueListFields = FieldsValues;
	ElsIf Not IsBlankString(FieldsValues) Then
		ValueListFields = ContactInformationManagementClientServer.ConvertStringToFieldList(FieldsValues);
	EndIf;
	
	PresentationField = "";
	If ValueListFields <> Undefined Then
		For Each FieldValue In ValueListFields Do
			Field = Upper(FieldValue.Presentation);
			
			If Field = "COUNTRYCODE" Then
				Data.CountryCode = FieldValue.Value;
				
			ElsIf Field = "CITYCODE" Then
				Data.CityCode = FieldValue.Value;
				
			ElsIf Field = "PHONENUMBER" Then
				Data.Number = FieldValue.Value;
				
			ElsIf Field = "Supplementary" Then
				Data.Supplementary = FieldValue.Value;
				
			ElsIf Field = "PRESENTATION" Then
				PresentationField = TrimAll(FieldValue.Value);
				
			EndIf;
			
		EndDo;
		
		// Presentation with priorities.
		If Not IsBlankString(Presentation) Then
			Result.Presentation = Presentation;
		Else
			Result.Presentation = PresentationField;
		EndIf;
		
		Return Result;
	EndIf;
	
	// Disassemble from presentation.
	
	// Digits groups separated by characters - not in figures: county, city, number, extension. 
	// The additional includes nonblank characters on the left and right.
	Position = 1;
	Data.CountryCode  = FindSubstringOfDigits(Presentation, Position);
	BeginCity = Position;
	
	Data.CityCode  = FindSubstringOfDigits(Presentation, Position);
	Data.Number      = FindSubstringOfDigits(Presentation, Position, " -");
	
	Supplementary = TrimAll(Mid(Presentation, Position));
	If Left(Supplementary, 1) = "," Then
		Supplementary = TrimL(Mid(Supplementary, 2));
	EndIf;
	If Upper(Left(Supplementary, 3 ))= "EXT" Then
		Supplementary = TrimL(Mid(Supplementary, 4));
	EndIf;
	If Upper(Left(Supplementary, 1 ))= "." Then
		Supplementary = TrimL(Mid(Supplementary, 2));
	EndIf;
	Data.Supplementary = TrimAll(Supplementary);
	
	// Correct possible errors.
	If IsBlankString(Data.Number) Then
		If Left(TrimL(Presentation),1)="+" Then
			// There was an attempt to explicitly specify country code, leave the country.
			Data.CityCode  = "";
			Data.Number      = ReduceDigits(Mid(Presentation, BeginCity));
			Data.Supplementary = "";
		Else
			Data.CountryCode  = "";
			Data.CityCode  = "";
			Data.Number      = Presentation;
			Data.Supplementary = "";
		EndIf;
	EndIf;
	
	Result.Presentation = Presentation;
	Return Result;
EndFunction  

// Returns the first subrow from digits in the row. The BeginningPosition parameter is substituted for the first non-digit.
//
Function FindSubstringOfDigits(Text, BeginningPosition = Undefined, PermissibleExceptDigits = "")
	
	If BeginningPosition = Undefined Then
		BeginningPosition = 1;
	EndIf;
	
	Result = "";
	PositionEnd = StrLen(Text);
	SearchBeginning  = True;
	
	While BeginningPosition <= PositionEnd Do
		Char = Mid(Text, BeginningPosition, 1);
		IsDigit = Char >= "0" AND Char <= "9";
		
		If SearchBeginning Then
			If IsDigit Then
				Result = Result + Char;
				SearchBeginning = False;
			EndIf;
		Else
			If IsDigit Or Find(PermissibleExceptDigits, Char) > 0 Then
				Result = Result + Char;    
			Else
				Break;
			EndIf;
		EndIf;
		
		BeginningPosition = BeginningPosition + 1;
	EndDo;
	
	// Remove possible pending delimiters left.
	Return ReduceDigits(Result, PermissibleExceptDigits, False);
	
EndFunction

Function ReduceDigits(Text, PermissibleExceptDigits = "", Direction = True)
	
	Length = StrLen(Text);
	If Direction Then
		// Abbreviation left
		IndexOf = 1;
		End  = 1 + Length;
		Step    = 1;
	Else
		// Abbreviation right    
		IndexOf = Length;
		End  = 0;
		Step    = -1;
	EndIf;
	
	While IndexOf <> End Do
		Char = Mid(Text, IndexOf, 1);
		IsDigit = (Char >= "0" AND Char <= "9") Or Find(PermissibleExceptDigits, Char) = 0;
		If IsDigit Then
			Break;
		EndIf;
		IndexOf = IndexOf + Step;
	EndDo;
	
	If Direction Then
		// Abbreviation left
		Return Right(Text, Length - IndexOf + 1);
	EndIf;
	
	// Abbreviation right
	Return Left(Text, IndexOf);
	
EndFunction

// Receive deep property of an object.
//
Function GetXDTOObjectAttribute(XDTOObject, XPath) Export
	
	// Do not wait for line break to XPath.
	PropertiesString = StrReplace(StrReplace(XPath, "/", Chars.LF), Chars.LF + Chars.LF, "/");
	
	NumberOfProperties = StrLineCount(PropertiesString);
	If NumberOfProperties = 1 Then
		Result = XDTOObject.Get(PropertiesString);
		If TypeOf(Result) = Type("XDTODataObject") Then 
			Return Result.Value;
		EndIf;
		Return Result;
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

// Sets in XDTO address a value according to XPath.
//
Procedure SetXDTOObjectAttribute(XDTODataObject, PathXPath, Value) Export
	
	If Value = Undefined Then
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
		
		If Find(PathPart, "AddEMailAddress") = 0 Then
			Object[PathPart] =  Value;
		Else
			XPathPathCode = Mid(PathPart, 20, 8);
			FieldValue = Object.AddEMailAddress.Add(XDTOFactory.Create(Object.AddEMailAddress.OwningProperty.Type));
			FieldValue.TypeAdrEl = XPathPathCode;
			FieldValue.Value = Value;
		EndIf;
		
	ElsIf LeadingObject <> Undefined Then
		LeadingObject[PathPart] =  Value;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctionsBySXSLTWork

//  Returns a flag showing whether it is an XML text
//
//  Parameters:
//      Text - String - checked text.
//
// Returns:
//      Boolean - checking result.
//
Function ItIsXMLString(Text)
	
	Return TypeOf(Text) = Type("String") AND Left(TrimL(Text),1) = "<";
	
EndFunction

// Deserializer of types known to platform.
Function ValueFromXMLString(Val Text)
	
	XMLReader = New XMLReader;
	XMLReader.SetString(Text);
	Return XDTOSerializer.ReadXML(XMLReader);
	
EndFunction

// Serializer of types known to platform.
Function ValueToXMLString(Val Value)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString(New XMLWriterSettings(, , False, False, ""));
	XDTOSerializer.WriteXML(XMLWriter, Value, XMLTypeAssignment.Explicit);
	// Platform serializer helps to write a line break to the attributes value.
	Return StrReplace(XMLWriter.Close(), Chars.LF, "&#10;");
	
EndFunction

// To work with attributes containing line breaks.
//
// Parameters:
//     Text - String - Corrected XML row.
//
// Returns:
//     String - Normalized row.
//
Function MultipageXMLRow(Val Text)
	
	Return StrReplace(Text, Chars.LF, "&#10;");
	
EndFunction

// Prepares the structure to include it in the XML text removing special characters.
//
// Parameters:
//     Text - String - Corrected XML row.
//
// Returns:
//     String - Normalized row.
//
Function NormalizedXMLRow(Val Text)
	
	Result = StrReplace(Text,     """", "&quot;");
	Result = StrReplace(Result, "&",  "&amp;");
	Result = StrReplace(Result, "'",  "&apos;");
	Result = StrReplace(Result, "<",  "&lt;");
	Result = StrReplace(Result, ">",  "&gt;");
	Return MultipageXMLRow(Result);
	
EndFunction


#EndRegion

#EndRegion
