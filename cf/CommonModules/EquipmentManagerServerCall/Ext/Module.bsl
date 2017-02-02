
#Region ProgramInterface

// Returns the version number of the peripherals library.
//
Function LibraryVersion() Export
	
	Return "1.1.7.2";
	
EndFunction

// The functions returns the list of activated peripherals in the catalog
//
Function GetEquipmentList(EETypes = Undefined, ID = Undefined, Workplace = Undefined) Export
	
	Return Catalogs.Peripherals.GetEquipmentList(EETypes, ID, Workplace);
	
EndFunction

// The function returns the parameters of a device by its ID
//
Function GetDeviceParameters(ID) Export
	
	Return Catalogs.Peripherals.GetDeviceParameters(ID);
	
EndFunction

// The procedure is designed for
// saving device parameters in the attribute: Parameters of storage type for value in the list item.
Function SaveDeviceParameters(ID, Parameters) Export

	Return Catalogs.Peripherals.SaveDeviceParameters(ID, Parameters);

EndFunction

// The function returns a structure with a given device
//
Function GetDeviceData(ID) Export

	Return Catalogs.Peripherals.GetDeviceData(ID);

EndFunction

// The function returns a structure with driver data
// 
Function GetDriverData(ID) Export

	Return Catalogs.HardwareDrivers.GetDriverData(ID);

EndFunction

// The function returns the driver name after the processor name.
//
Function GetInstanceDriverName(DriverHandlerDescription) Export

	Result = "";
	
	For Each EnumerationName IN Metadata.Enums.PeripheralDriverHandlers.EnumValues Do
		If DriverHandlerDescription = EnumerationName.Synonym Then
			Result = EnumerationName.Name;
			Break;
		EndIf;
	EndDo;

	Return Result;

EndFunction

// The function returns driver parameters given after the developer name.
//
Function GetDriverParametersForProcessor(DriverHandlerDescription) Export

	Result = New Structure;
	
	For Each EnumerationName IN Metadata.Enums.PeripheralDriverHandlers.EnumValues Do
		If DriverHandlerDescription = EnumerationName.Synonym Then
			Result.Insert("Name"            , EnumerationName.Name);
			Result.Insert("Description"   , EnumerationName.Synonym);
			Result.Insert("EquipmentType", Enums["PeripheralTypes"][EnumerationName.Comment]);
			Break;
		EndIf;
	EndDo;
	
	Return Result;

EndFunction

// The function returns the client computer name from the session variable.
//
Function GetClientWorkplace() Export

	SetPrivilegedMode(True);
	Return SessionParameters.ClientWorkplace;

EndFunction

// The function returns the list of the workplaces corresponding with a stated computer name.
//
Function FindWorkplacesById(ClientID) Export
	
	If Not EquipmentManagerServerCallOverridable.CanUseSeparatedData() Then
		Return New Array();
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query("
	|SELECT
	|	Workplaces.Ref
	|FROM
	|	Catalog.Workplaces AS Workplaces
	|WHERE
	|	Workplaces.Code = &Code
	|	AND Workplaces.DeletionMark = FALSE
	|");
	
	Query.SetParameter("Code", ClientID);
	ListOfComputers = Query.Execute().Unload().UnloadColumn("Ref");
	
	Return ListOfComputers;
	
EndFunction

// Functions sets client's computer name to the session variable
//
Procedure SetClientWorkplace(ClientWorkplace) Export

	SetPrivilegedMode(True);
	SessionParameters.ClientWorkplace = ClientWorkplace;
	RefreshReusableValues();

EndProcedure

// The function gets a driver model and saves it
// in temporary storage returning the link to this temporary storage.
Function GetTemplateFromServer(TemplateName) Export

	Refs = PutToTempStorage(GetCommonTemplate(TemplateName));
	Return Refs;

EndFunction

// The function returns a slip check template made from template name.
//
Function GetSlipReceipt(TemplateName, SlipReceiptWidth, Parameters, PINAuthorization = False) Export
	
	SlipReceipt  = "";  
	
	Document = New TextDocument();
	
	Template    = GetCommonTemplate(TemplateName);
	Area  = Template.GetArea("Receipt" + SlipReceiptWidth + ?(PINAuthorization, "Pin", ""));
	
	For Each Parameter IN Parameters Do
		Area.Parameters[Parameter.Key] = Parameter.Value;
	EndDo;
	
	If Area <> Undefined Then
		Document.Put(Area);
		
		For IndexOf = 1 To Document.LineCount() Do
			SlipReceipt = SlipReceipt + Document.GetLine(IndexOf)
			        + ?(IndexOf = Document.LineCount(), "", Char(13) + Char(10));
		EndDo;
	EndIf;
	
	Return SlipReceipt;
	
EndFunction

// The function returns the constant value.
//
Function GetConstant(ConstantName) Export
	
	Constant = Constants[ConstantName].Get();
	Return Constant;
	
EndFunction           

// It receives the predefined item reference by its full name.
//
Function PredefinedItem(Val FullPredefinedName) Export
	
	PredefinedName = Upper(FullPredefinedName);
	
	Point = Find(PredefinedName, ".");
	CollectionName = Left(PredefinedName, Point - 1);
	PredefinedName = Mid(PredefinedName, Point + 1);
	
	Point = Find(PredefinedName, ".");
	TableName = Left(PredefinedName, Point - 1);
	PredefinedName = Mid(PredefinedName, Point + 1);
	
	QueryText = "SELECT ALLOWED TOP 1 Ref FROM &FullTableName WHERE PredefinedDataName = &PredefinedName";
	QueryText = StrReplace(QueryText, "&FullTableName", CollectionName + "." + TableName);
	
	Query = New Query(QueryText);
	Query.SetParameter("PredefinedName", PredefinedName);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return Undefined;
	Else
		Return Result.Unload()[0].Ref;
	EndIf;
	
EndFunction

// The function returns availability of saving user data.
//
Function AccessRightSaveUserData() Export
	
	Return AccessRight("SaveUserData", Metadata);
	
EndFunction

// Function returns the name of Enums from its metadata.
//
Function GetEquipmentTypeName(EquipmentType) Export

	Result = Undefined;
	
	MetaObject = EquipmentType.Metadata();
	IndexOf = Enums.PeripheralTypes.IndexOf(EquipmentType);
	Result = MetaObject.EnumValues[IndexOf].Name;

	Return Result;

EndFunction

// The function returns specification by name.
//
Function GetEquipmentType(EquipmentTypeName) Export
	
	Try
		Result = Enums["PeripheralTypes"][EquipmentTypeName]; 
	Except
		Result = Enums.PeripheralTypes.EmptyRef();
	EndTry;
	
	Return Result;
	
EndFunction

// The function returns created client workplace
//
Function CreateClientWorkplace(Parameters) Export

	SetPrivilegedMode(True);
	
	Workplace = Catalogs.Workplaces.CreateItem();

	Workplace.Code           = Parameters.ClientID;
	Workplace.ComputerName = Parameters.ComputerName;


	EquipmentManagerClientServer.FillWorkplaceDescription(Workplace, InfobaseUsers.CurrentUser());

	Workplace.Write();

	SetPrivilegedMode(False);
	
	Return Workplace.Ref;

EndFunction // CreateWorkplaceClientById()

// The procedure defines the values of session parameters related to the peripherals.
//
Procedure SetPeripheralsSessionParameters(ParameterName, SpecifiedParameters) Export

	If ParameterName = "ClientWorkplace" Then
		
		// If the current session client ID refers to
		// one workplace, it will be recorded in the session parameters.
		CurrentWP           = Catalogs.Workplaces.EmptyRef();
		SystemInfo = New SystemInfo();
		
		WPList = FindWorkplacesById(Upper(SystemInfo.ClientID));
		If WPList.Count() = 0 Then
			// Will be created from client.
		Else
			CurrentWP = WPList[0];
		EndIf;
		
		SetClientWorkplace(CurrentWP);
		
		If TypeOf(SpecifiedParameters) = Type("Structure") Then
			SpecifiedParameters.Insert("ClientWorkplace");
		Else
			SpecifiedParameters.Add("ClientWorkplace");
		EndIf;
		
	EndIf;
	
EndProcedure

// Returns the list of equipment requiring components reinstallation.
//
Function GetDriversListForReinstallation(Workplace) Export
	
	SetPrivilegedMode(True);
	List = New Array;
	
	Query = New Query(
	"SELECT DISTINCT 
	|	Peripherals.HardwareDriver
	|FROM
	|	Catalog.Peripherals AS Peripherals
	|WHERE
	|	Peripherals.Workplace = &Workplace 
	|	AND Peripherals.ReinstallationRequired");
	Query.SetParameter("Workplace", Workplace);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		String = New Structure("HardwareDriver, DriverData", Selection.HardwareDriver, GetDriverData(Selection.HardwareDriver)); 
		List.Add(String);
	EndDo;
	
	Return List;
	
EndFunction

// Returns the list of equipment requiring component installation.
//
Function GetDriversListForInstallation(Workplace) Export
	
	SetPrivilegedMode(True);
	List = New Array;
	
	Query = New Query(
	"SELECT DISTINCT 
	|	Peripherals.HardwareDriver
	|FROM
	|	Catalog.Peripherals AS Peripherals
	|WHERE
	|	Peripherals.Workplace = &Workplace 
	|	AND Peripherals.InstallationIsRequired");
	Query.SetParameter("Workplace", Workplace);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		String = New Structure("HardwareDriver, DriverData", Selection.HardwareDriver, GetDriverData(Selection.HardwareDriver)); 
		List.Add(String);
	EndDo;
	
	Return List;
	
EndFunction

// Records changes in transmitted object.
// For update counters.
//
// Parameters:
//   Data                            - Arbitrary - object, set of entries or
//                                                 constant manager to record.
//   RegisterOnNodesExchangePlans    - Boolean   - enables registration on the exchange plans nodes when recording the object.
//   EnableBusinessLogic             - Boolean  - activates business logic when recording the object.
//
Procedure WriteData(Val Data, Val RegisterOnNodesExchangePlans = False, 
	Val EnableBusinessLogic = False) Export 

  Data.DataExchange.Load = Not EnableBusinessLogic;
	If Not RegisterOnNodesExchangePlans Then
		Data.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
		Data.DataExchange.Recipients.AutoFill = False;
	EndIf;
	
	Data.Write();
	
EndProcedure

// Select necessity of equipment reinstallation for connected equipment at the workplace.
//
Procedure SetReinstallSignDrivers(Workplace, HardwareDriver, SignOf) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT  
	|	Peripherals.Ref
	|FROM
	|	Catalog.Peripherals AS Peripherals
	|WHERE
	|	Peripherals.Workplace = &Workplace
	|	AND Peripherals.HardwareDriver = &HardwareDriver
	|	AND Not Peripherals.ReinstallationRequired = &ReinstallationRequired"); 
	
	Query.SetParameter("Workplace", Workplace);
	Query.SetParameter("HardwareDriver", HardwareDriver);
	Query.SetParameter("ReinstallationRequired", SignOf);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		CatalogObject = Selection.Ref.GetObject();
		CatalogObject.ReinstallationRequired = SignOf;
		WriteData(CatalogObject)
	EndDo;
	
EndProcedure

// Selects necessity of peripherals equipment reinstallation.
//
Procedure ReinstallDriversForSetSignEquipment(Peripherals, SignOf) Export
	
	SetReinstallSignDrivers(Peripherals.Workplace, Peripherals.HardwareDriver, SignOf);
	
EndProcedure

// Selects necessity of equipment installation for peripherals at worklplace.
//
Procedure SetSignOfDriverInstallation(Workplace, HardwareDriver, SignOf) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT  
	|	Peripherals.Ref
	|FROM
	|	Catalog.Peripherals AS Peripherals
	|WHERE
	|	Peripherals.Workplace = &Workplace
	|	AND Peripherals.HardwareDriver = &HardwareDriver
	|	AND Not Peripherals.InstallationIsRequired = &InstallationIsRequired"); 
	
	Query.SetParameter("Workplace", Workplace);
	Query.SetParameter("HardwareDriver", HardwareDriver);
	Query.SetParameter("InstallationIsRequired", SignOf);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		CatalogObject = Selection.Ref.GetObject();
		CatalogObject.InstallationIsRequired = SignOf;
		WriteData(CatalogObject)
	EndDo;
	
EndProcedure

// Saves user settings of peripherals.
//
Procedure SaveUserSettingsOfPeripherals(SettingsList) Export
		
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;

	For Each Item IN SettingsList Do
		CommonSettingsStorage.Save("UserSettingsOfPeripherals", Item.Key, Item.Value);
	EndDo;
		
	RefreshReusableValues();

EndProcedure

// Decomposes the magnet card track by templates
// Input:
// TracksData - array of strings. Values received from the tracks.
// TracksParameters - array of structures containing device settings parameters.
//  * Use, Boolean - track usage flag
//  * TrackNumber, number - definition number of track 1-3.
//
// Output:
// Array of structures containing decrypted data for all appropriate templates with link to them.
// * Array - templates
//   * Structure - tewmplate data.
//     - Template, CatalogRef.MagneticCardsTemplates
//     - TrackData, fields array of all tracks.
//       * Structure - field data.
//         - Field
//         - FieldValue
Function DecryptMagneticCardCode(TracksData, TracksParameters) Export
	
	If TracksData.Count() = 0
		OR TracksParameters.Count() = 0 Then
		Return Undefined; // No data
	EndIf;
	
	DataFilter = New Array;
	CounterTracks = 0;
	For Each CurParameter IN TracksParameters Do
		If CurParameter.Use Then
			Try
				DataFilter.Add(New Structure("TrackNumber, TrackLength, TrackData"
													, CurParameter.TrackNumber, StrLen(TracksData[CounterTracks]), TracksData[CounterTracks]));
			Except
				Return Undefined; // invalid template format
			EndTry;
		EndIf;
		CounterTracks = CounterTracks + 1;
	EndDo;
	
	// 1 Stage. Find templates by code length
	// a) When comparing, only available tracks matter
	// b) At least one track must be available.
	Query = New Query(
	"SELECT
	|	MagneticCardsTemplates.Ref,
	|	
	|	MagneticCardsTemplates.TrackAvailability1,
	|	MagneticCardsTemplates.Prefix1,
	|	MagneticCardsTemplates.Suffix1,
	|	MagneticCardsTemplates.CodeLength1,
	|	MagneticCardsTemplates.BlocksDelimiter1,
	|	
	|	MagneticCardsTemplates.TrackAvailability2,
	|	MagneticCardsTemplates.Prefix2,
	|	MagneticCardsTemplates.Suffix2,
	|	MagneticCardsTemplates.CodeLength2,
	|	MagneticCardsTemplates.BlocksDelimiter2,
	|	
	|	MagneticCardsTemplates.TrackAvailability3,
	|	MagneticCardsTemplates.Prefix3,
	|	MagneticCardsTemplates.Suffix3,
	|	MagneticCardsTemplates.CodeLength3,
	|	MagneticCardsTemplates.BlocksDelimiter3
	|FROM
	|	Catalog.MagneticCardsTemplates AS MagneticCardsTemplates
	|WHERE
	|	(MagneticCardsTemplates.TrackAvailability1
	|			OR MagneticCardsTemplates.TrackAvailability2
	|			OR MagneticCardsTemplates.TrackAvailability3)
	|	AND CASE
	|			WHEN MagneticCardsTemplates.TrackAvailability1
	|				THEN MagneticCardsTemplates.CodeLength1 = &CodeLength1
	|			ELSE TRUE
	|		END
	|	AND CASE
	|			WHEN MagneticCardsTemplates.TrackAvailability2
	|				THEN MagneticCardsTemplates.CodeLength2 = &CodeLength2
	|			ELSE TRUE
	|		END
	|	AND CASE
	|			WHEN MagneticCardsTemplates.TrackAvailability3
	|				THEN MagneticCardsTemplates.CodeLength3 = &CodeLength3
	|			ELSE TRUE
	|		END");
	Query.SetParameter("CodeLength1", StrLen(TracksData[0]));
	Query.SetParameter("CodeLength2", StrLen(TracksData[1]));
	Query.SetParameter("CodeLength3", StrLen(TracksData[2]));
	Selection = Query.Execute().Select();
	
	TemplatesList = New Array;
	While Selection.Next() Do
		
		// Stage 2 - Skip the templates that do not match suffix, prefix, delimiter.
		
		If Not CodeCorrespondsToMCTemplate(TracksData, Selection) Then
			Continue;
		EndIf;
		
		TrackData = New Array;
		For Each curFilter IN DataFilter Do
			For Each curField IN Selection.Ref["TrackFields"+String(curFilter.TrackNumber)] Do
				
				// Search block by number
				DataRow = curFilter.TrackData;
				Prefix = Selection["Prefix"+String(curFilter.TrackNumber)];
				If Prefix = Left(DataRow, StrLen(Prefix)) Then
					DataRow = Right(DataRow, StrLen(DataRow)-StrLen(Prefix)); // Remove prefix if any
				EndIf;
				Suffix = Selection["Suffix"+String(curFilter.TrackNumber)];
				If Suffix = Right(DataRow, StrLen(Suffix)) Then
					DataRow = Left(DataRow, StrLen(DataRow)-StrLen(Suffix)); // Remove suffix if any
				EndIf;
				
				curBlockNumber = 0;
				While curBlockNumber < curField.BlockNumber Do
					BlocksDelimiter = Selection["BlocksDelimiter"+String(curFilter.TrackNumber)];
					SeparatorPosition = Find(DataRow, BlocksDelimiter);
					If IsBlankString(BlocksDelimiter) OR SeparatorPosition = 0 Then
						Block = DataRow;
					ElsIf SeparatorPosition = 1 Then
						Block = "";
						DataRow = Right(DataRow, StrLen(DataRow)-1);
					Else
						Block = Left(DataRow, SeparatorPosition-1);
						DataRow = Right(DataRow, StrLen(DataRow)-SeparatorPosition);
					EndIf;
					curBlockNumber = curBlockNumber + 1;
				EndDo;
				
				// Search substring in the block
				FieldValue = Mid(Block, curField.FirstFieldSymbolNumber, ?(curField.FieldLenght = 0, StrLen(Block), curField.FieldLenght));
				
				FieldData = New Structure("Field, FieldValue", curField.Field, FieldValue);
				TrackData.Add(FieldData);
			EndDo;
		EndDo;
		Pattern = New Structure("Template, TracksData", Selection.Ref, TrackData);
		TemplatesList.Add(Pattern);
	EndDo;
	
	If TemplatesList.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	Return TemplatesList;
	
EndFunction

// Defines correspondence between card code and template.
// Input:
// TracksData - Array containing rows of lane code. 3 items totally.
// PatternData - a structure containing template data:
// - Suffix
// - Prefix
// - BlocksDelimiter
// - CodeLength
// Output:
// True - code corresponds to template.
Function CodeCorrespondsToMCTemplate(TracksData, PatternData)
	For Iterator = 1 To 3 Do
		If PatternData["TrackAvailability"+String(Iterator)] Then
			curRow = TracksData[Iterator - 1];
			If Right(curRow, StrLen(PatternData["Suffix"+String(Iterator)])) <> PatternData["Suffix"+String(Iterator)]
				Or Left(curRow, StrLen(PatternData["Prefix"+String(Iterator)])) <> PatternData["Prefix"+String(Iterator)]
				Or Find(curRow, PatternData["BlocksDelimiter"+String(Iterator)]) = 0
				Or StrLen(curRow) <> PatternData["CodeLength"+String(Iterator)] Then
				Return False;
			EndIf;
		EndIf;
	EndDo;
	Return True;
EndFunction

// Get a goods table from XML structure for DCT.
//
Function GetProductsTableDCT(DataExport) Export
	
	Result = New Array();
	
	If Not IsBlankString(DataExport) Then
		
		XMLReader = New XMLReader; 
		XMLReader.SetString(DataExport);
		XMLReader.MoveToContent();
		
		If XMLReader.Name = "Table" AND XMLReader.NodeType = XMLNodeType.StartElement Then  
			While XMLReader.Read() Do  
				If XMLReader.Name = "Record" AND XMLReader.NodeType = XMLNodeType.StartElement Then  
					Result.Add(XMLReader.AttributeValue("BarCode"));
					Result.Add(XMLReader.AttributeValue("Quantity"));
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Form a goods table with XML structure for DCT.
//
Function GenerateProductsTableDCT(DataExport) Export
	
	XMLWriter = New XMLWriter; 
	XMLWriter.SetString("UTF-8");
	XMLWriter.WriteXMLDeclaration();

	XMLWriter.WriteStartElement("Table");
	For Each Position IN DataExport  Do
		XMLWriter.WriteStartElement("Record");
		XMLWriter.WriteAttribute("BarCode"                      , String(Position[0].Value));
		XMLWriter.WriteAttribute("Name"                         , String(Position[1].Value));
		XMLWriter.WriteAttribute("MeasurementUnit"              , String(Position[2].Value));
		XMLWriter.WriteAttribute("CharacteristicOfNomenclature" , String(Position[3].Value));
		XMLWriter.WriteAttribute("SeriesOfNomenclature"         , String(Position[4].Value));
		XMLWriter.WriteAttribute("Quality"                      , String(Position[5].Value));
		XMLWriter.WriteAttribute("Price"                        , String(Position[6].Value));
		XMLWriter.WriteAttribute("Quantity"                     , String(Position[7].Value));
		XMLWriter.WriteEndElement();
	EndDo;
	XMLWriter.WriteEndElement();
		
	Return XMLWriter.Close();
	
EndFunction

// Form a goods table in XML for weights with printing labels.
//
Function GenerateProductsTableLabelsPrintingScales(DataExport) Export
	
	XMLWriter = New XMLWriter; 
	XMLWriter.SetString("UTF-8");
	XMLWriter.WriteXMLDeclaration();
	
	XMLWriter.WriteStartElement("Table");
	For Each Position IN DataExport  Do
		XMLWriter.WriteStartElement("Record");
		XMLWriter.WriteAttribute("PLU"         , String(Position[0].Value));
		XMLWriter.WriteAttribute("Code"        , String(Position[1].Value));
		XMLWriter.WriteAttribute("Name"        , String(Position[2].Value));
		XMLWriter.WriteAttribute("Price"       , String(Position[3].Value));
		XMLWriter.WriteAttribute("Description" , String(Position[4].Value));
		XMLWriter.WriteAttribute("ShelfLife"   , String(Position[5].Value));
		XMLWriter.WriteEndElement();
	EndDo;
	XMLWriter.WriteEndElement();
		
	Return XMLWriter.Close();
	
EndFunction

// The function determines the barcode type by code value.
// 
Function DetermineTypeOfBarcode(Barcode) Export
	
	BarCodeType = "";	
	LengthBarcode = StrLen(Barcode);
	
	If LengthBarcode = 0 Then
		Return BarCodeType;
	EndIf;
	
	Amount = 0;
	
	If LengthBarcode = 14 Then // ITF14
		
		Factor = 1; 
		For Ct = 1 To 13 Do
			CharTempCode = CharCode(Barcode, Ct);
			If CharTempCode < 48 Or CharTempCode > 57 Then
				Break;
			EndIf;
			Amount       = Amount + Factor * (CharTempCode - 48);
			Factor = 4 - Factor;
		EndDo;
		Amount = (10 - Amount % 10) % 10;
		If CharCode(Barcode, 14) = Amount + 48 Then
			BarCodeType = "ITF14";
 		EndIf;
		
	ElsIf LengthBarcode = 13 Then // EAN13
		
		EAN13 = True;
		Factor = 1;
		For Ct = 1 To 12 Do
			CharTempCode = CharCode(Barcode, Ct);
			If CharTempCode < 48 Or CharTempCode > 57 Then
				EAN13 = False;
				Break;
			EndIf;
			Amount  = Amount + Factor * (CharTempCode - 48);
			Factor = 4 - Factor;
		EndDo;
		Amount = (10 - Amount % 10) % 10;
		CheckChar = Char(Amount + 48);
		If EAN13 AND CheckChar = Right(Barcode, 1) Then
			BarCodeType = "EAN13";
		EndIf;
		
	ElsIf LengthBarcode = 8 Then // EAN8
		
		EAN8 = True;
		Factor = 3;
		For Ct = 1 To 7 Do
			CharTempCode = CharCode(Barcode, Ct);
			If CharTempCode < 48 Or CharTempCode > 57 Then
				EAN8 = False;
				Break;
			EndIf;
			Amount       = Amount + Factor * (CharTempCode - 48);
			Factor = 4 - Factor;
		EndDo;
		Amount = (10 - Amount % 10) % 10;
		If EAN8 AND (CharCode(Barcode, 8) = Amount + 48) Then
			BarCodeType = "EAN8";
		EndIf;
		
	EndIf;
	
	If BarCodeType= "" Then // CODE39
		
		CODE39 = True;
		For Ct = 1 To LengthBarcode Do
			CharTempCode = CharCode(Barcode, Ct);
			If (CharTempCode <> 32)
				AND (CharTempCode < 36 Or CharTempCode > 37)
				AND (CharTempCode <> 43)
				AND (CharTempCode < 45 Or CharTempCode > 57)
				AND (CharTempCode < 65 Or CharTempCode > 90) Then
				CODE39 = False;
				Break;
			EndIf;
		EndDo;
		
		If CODE39 Then
			BarCodeType = "CODE39";
		EndIf                                                     
		
	EndIf;
	
	If BarCodeType= ""  Then // CODE128
		// CODE128 ASCII characters 0 to 127 (figures  "0" to "9", letters "A" to "Z" and "a" to "z") and special characters;
		CODE128 = True;
		For Ct = 1 To LengthBarcode Do
			CharTempCode = CharCode(Barcode, Ct);
			If (CharTempCode > 127) Then
				CODE128 = False;
			Break;
			EndIf;
		EndDo;
		
		If CODE128 Then
			BarCodeType = "CODE128";
		EndIf                                                     
		
	EndIf;
	
	If BarCodeType= "CODE128"  Then // EAN128
		// in EAN128 code, vocabulary is regulated CODE128 but code groups regulated.
		If CharCode(Barcode, 1) = 40 Then
			BarCodeType = "EAN128";
		EndIf;
	EndIf;
	
	Return BarCodeType;
	
EndFunction

// The function forms barcode image.
// Parameters: 
//  BarcodeParameters 
// Return value: 
//   Picture - Image with formed barcode or UNDEFINED.
Function GetBarcodePicture(BarcodeParameters) Export
	
	ExternalComponent = EquipmentManagerServerReUse.ConnectBarcodePrintingExternalComponent();
	
	If ExternalComponent = Undefined Then
		Raise NStr("en='External barcode printing components connection error!';ru='Ошибка подключения внешней компоненты печати штрихкода!'");
	EndIf;
	
	// Define image size
	ExternalComponent.Width = Round(BarcodeParameters.Width);
	ExternalComponent.Height = Round(BarcodeParameters.Height);
	
	ExternalComponent.AutoType = False;
	
	If BarcodeParameters.CodeType = 99 Then
		TypeBarcodeTemp = DetermineTypeOfBarcode(BarcodeParameters.Barcode);
		If TypeBarcodeTemp = "EAN8" Then
			ExternalComponent.CodeType = 0;
		ElsIf TypeBarcodeTemp = "EAN13" Then
			ExternalComponent.CodeType = 1;
			// If the code contains a reference character, be sure to specify it.
			ExternalComponent.ContainKS = StrLen(BarcodeParameters.Barcode) = 13;
		ElsIf TypeBarcodeTemp = "EAN128" Then
			ExternalComponent.CodeType = 2;
		ElsIf TypeBarcodeTemp = "CODE39" Then
			ExternalComponent.CodeType = 3;
		ElsIf TypeBarcodeTemp = "CODE128" Then
			ExternalComponent.CodeType = 4;
		ElsIf TypeBarcodeTemp = "ITF14" Then
			ExternalComponent.CodeType = 11;
		Else
			ExternalComponent.AutoType = True;
		EndIf;
	Else
		ExternalComponent.AutoType = False;
		ExternalComponent.CodeType = BarcodeParameters.CodeType;
	EndIf;
	
	If BarcodeParameters.Property("TransparentBackground") Then
		ExternalComponent.TransparentBackground = BarcodeParameters.TransparentBackground;
	EndIf;

	ExternalComponent.ShowText = BarcodeParameters.ShowText;
	
	// Form a barcode image
	ExternalComponent.CodeValue = BarcodeParameters.Barcode;
	
	If BarcodeParameters.Property("AngleOfRotation") Then
		ExternalComponent.AngleOfRotation = BarcodeParameters.AngleOfRotation;
	Else
		ExternalComponent.AngleOfRotation = 0;
	EndIf;
	
	// If the specified width is less than minimal for this barcode.
	If ExternalComponent.Width < ExternalComponent.MinimumWidthCode Then
		ExternalComponent.Width = ExternalComponent.MinimumWidthCode;
	EndIf;
	
	// If the defined height is less than minimal for this barcode.
	If ExternalComponent.Height < ExternalComponent.MinimumHeightCode Then
		ExternalComponent.Height = ExternalComponent.MinimumHeightCode;
	EndIf;

	If BarcodeParameters.Property("SizeOfFont") AND (BarcodeParameters.SizeOfFont > 0) 
		AND (BarcodeParameters.ShowText) AND (ExternalComponent.SizeOfFont <> BarcodeParameters.SizeOfFont) Then
		ExternalComponent.SizeOfFont = BarcodeParameters.SizeOfFont;
	EndIf;
	
	// Form image
	BinaryDataImages = ExternalComponent.GetBarcode();
	
	// If image is formed.
	If BinaryDataImages <> Undefined Then
 	// Form from binary data.
		Return New Picture(BinaryDataImages);
	EndIf;
	
	Return Undefined;
	
EndFunction

#EndRegion