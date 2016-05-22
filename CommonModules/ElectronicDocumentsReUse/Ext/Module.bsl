////////////////////////////////////////////////////////////////////////////////
// ElectronicDocumentsReUse: mechanism of electronic documents exchange.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROGRAMMING INTERFACE

// Fills out an array with actual e-document kinds.
//
// Returns:
//  Array - kinds of current ED.
//
Function GetEDActualKinds() Export
	
	EDKindsArray = New Array;
	ElectronicDocumentsOverridable.GetEDActualKinds(EDKindsArray);
	
	If ValueIsFilled(EDKindsArray) Then
		EDKindsArray.Add(Enums.EDKinds.Confirmation);
		EDKindsArray.Add(Enums.EDKinds.NotificationAboutReception);
		EDKindsArray.Add(Enums.EDKinds.NotificationAboutClarification);
		EDKindsArray.Add(Enums.EDKinds.CancellationOffer);
	EndIf;
	
	EDKindsArray.Add(Enums.EDKinds.RandomED);
	
	Return EDKindsArray;
	
EndFunction

// For internal use only
Function NameAttributeObjectExistanceInAppliedSolution(ParameterName) Export
	
	ObjectAttributesMap = New Map;
	ElectronicDocumentsOverridable.GetMapOfNamesObjectsMDAndAttributes(ObjectAttributesMap);
	
	Return ObjectAttributesMap.Get(ParameterName);
	
EndFunction

// Returns an empty reference to a catalog.
//
// Parameters:
//  CatalogName - String, catalog name.
//
// Returns:
//  Ref - empty catalog reference.
//
Function GetEmptyRef(CatalogName) Export
	
	Result = Undefined;
	
	AppliedCatalogName = GetAppliedCatalogName(CatalogName);
	If ValueIsFilled(AppliedCatalogName) Then
		Result = Catalogs[AppliedCatalogName].EmptyRef();
	EndIf;
	
	Return Result;
	
EndFunction

// Returns an applied catalog name by the library catalog name.
//
// Parameters:
//  CatalogName - String - catalog name from the library.
//
// Returns:
//  AppliedCatalogName - String name of the applied catalog.
//
Function GetAppliedCatalogName(CatalogName) Export
	
	AccordanceCatalogs = New Map;
	ElectronicDocumentsOverridable.GetCatalogCorrespondence(AccordanceCatalogs);
	
	AppliedCatalogName = AccordanceCatalogs.Get(CatalogName);
	If AppliedCatalogName = Undefined Then // match is not specified
		MessagePattern = NStr("en = 'In the applied solution code it is necessary to specify the correspondence for the %1 catalog.'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, CatalogName);
		ElectronicDocumentsService.WriteEventOnEDToEventLogMonitor(MessageText,
			2, EventLogLevel.Warning);
	EndIf;
	
	Return AppliedCatalogName;
	
EndFunction

// For internal use only
Function ApplicationAttributePresentation(Code) Export
	
	MapOfAttributesAndPresentationsCodes = New Map;
	ElectronicDocumentsOverridable.MapOfAttributesAndPresentationsCodes(MapOfAttributesAndPresentationsCodes);
	Return MapOfAttributesAndPresentationsCodes.Get(Code);
	
EndFunction

// It receives the enumeration value by metadata object names.
// 
// Parameters:
//  Description - String, enumeration description.
//  EnumerationPresentation - String, enumeration value description.
//
// Returns:
//  FoundValue - value of the required enumeration.
//
Function FindEnumeration(Val EnumerationName, EnumerationPresentation) Export
	
	FoundValue = Undefined;
	
	AccordanceEnum = New Map;
	ElectronicDocumentsOverridable.GetEnumerationsCorrespondence(AccordanceEnum);
	
	AppliedEnumerationName = AccordanceEnum.Get(EnumerationName);
	If AppliedEnumerationName = Undefined Then // match is not specified
		MessagePattern = NStr("en = 'In the applied solution code it is necessary to specify the matching for enumeration %1.'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, EnumerationName);
		ElectronicDocumentsService.WriteEventOnEDToEventLogMonitor(MessageText,
			2, EventLogLevel.Warning);
	ElsIf ValueIsFilled(AppliedEnumerationName) Then // a value is set
		ElectronicDocumentsOverridable.GetEnumerationValue(
			AppliedEnumerationName, EnumerationPresentation, FoundValue);
		If FoundValue = Undefined Then
			For Each EnumerationEl IN Metadata.Enums[AppliedEnumerationName].EnumValues Do
				If Upper(EnumerationEl.Synonym) = Upper(EnumerationPresentation)
					OR Upper(EnumerationEl.Name) = Upper(EnumerationPresentation) Then
					FoundValue = Enums[AppliedEnumerationName][EnumerationEl.Name];
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	Return FoundValue;
	
EndFunction

// Returns a parameter description for the applied solution.
//
// Parameters:
//  Source - ref to which a parameter refers.
//  Parameter - String, attribute name.
//
// Returns:
//  Result - String - user attribute description.
//
Function GetUserPresentation(Source, Parameter) Export
	
	Result = Parameter;
	
	FilterParameters = New Structure;
	FilterParameters.Insert("SourceType", TypeOf(Source));
	FilterParameters.Insert("Parameter", Parameter);
	
	ValueTable = GetCorrespondenceTableParametersToUserPresentations();
	
	FoundStrings = ValueTable.FindRows(FilterParameters);
	If ValueIsFilled(FoundStrings) Then
		
		UserPresentation = FoundStrings[0].Presentation;
		If ValueIsFilled(UserPresentation) Then
			Result = UserPresentation;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Gets a table with key object attributes.
// 
// Parameters 
//  ObjectName - String, configuration object name which key attributes are to be received.
//
Function GetObjectKeyAttributesTable(ObjectName) Export
	
	AttributesTable = ObjectsAttributesTableInitialization();
	
	If ObjectName = "Document.EDPackage" Then
		Return AttributesTable;
	EndIf;
	
	KeyAttributesStructure = New Structure;
	If ObjectName = "Document.RandomED" Then
		ObjectAttributesString = "Date, Number, Company, Counterparty, Text";
		KeyAttributesStructure.Insert("Header", ObjectAttributesString);
	Else
		ElectronicDocumentsOverridable.GetObjectKeyAttributesStructure(ObjectName, KeyAttributesStructure);
	EndIf;

	If Not ValueIsFilled(KeyAttributesStructure) Then
		MessagePattern = NStr("en = 'Key attributes structure is not defined for the %1 object.'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, ObjectName);
		Raise(MessageText);
	EndIf;
	
	CurOrder = -50;
	For Each CurItem IN KeyAttributesStructure Do
		NewRow                            = AttributesTable.Add();
		NewRow.Order                    = CurOrder;
		NewRow.ObjectName                 = ObjectName;
		NewRow.TabularSectionName          = ?(CurItem.Key = "Header", "", CurItem.Key);
		NewRow.ObjectAttributes           = CurItem.Value;
		NewRow.ObjectAttributesStructure = New Structure(CurItem.Value);
		CurOrder = CurOrder + 100;
	EndDo;
	
	AttributesTable.Sort("Order Asc");
	
	Return AttributesTable;
	
EndFunction

// The function returns a flag of using
// catalog "Partners" as an additional analytics of the Counterparties catalog.
//
// Returns:
//  InUseCatalogPartners - Boolean - shows that it is used in the Partners catalog library.
//
Function UseAdditionalAnalyticsOfCompaniesCatalogPartners() Export

	InUseCatalogPartners = False;
	ElectronicDocumentsOverridable.AdditionalAnalyticsOfCompaniesCatalogPartners(InUseCatalogPartners);
	
	Return InUseCatalogPartners;
	
EndFunction

// The function returns a flag of using catalog
// "Products and services characteristics" as an additional analytics of the Products and services catalog.
//
// Parameters:
//  ProductsAndServicesCharacteristicsCatalogIsUsed - Boolean - flag showing the usage in the library of catalog "Products and services characteristics".
//
Function AdditionalAnalyticsCatalogProductsAndServicesCharacteristics() Export

	ProductsAndServicesCharacteristicsCatalogIsUsed = False;
	ElectronicDocumentsOverridable.AdditionalAnalyticsCatalogProductsAndServicesCharacteristics(ProductsAndServicesCharacteristicsCatalogIsUsed);
	
	Return ProductsAndServicesCharacteristicsCatalogIsUsed;
	
EndFunction

// Returns a version of package xdto of scheme CML 2.06.
Function CML2SchemeVersion() Export
	
	Return "CML 2.08";
	
EndFunction

// Returns a version of package xdto of scheme CML 4.02.
Function CML402SchemaVersion() Export
	
	Return "CML 4.02";
	
EndFunction

// Returns a namespace of the used CML scheme
Function CMLNamespace() Export
	
	Return "urn:1C.ru:commerceml_2";
	
EndFunction

Function MappingFieldNamesAddressesFTS_CML(FieldName, CMLtoFTS = True) Export
	
	MappedName = FieldName;
	VTComparison = VTComparisonFieldsAddressesFTS_CML();
	VTRow = VTComparison.Find(FieldName, ?(CMLtoFTS, "PresentationCML", "FTSPresentation"));
	If VTRow <> Undefined Then
		MappedName = VTRow[?(CMLtoFTS, "FTSPresentation", "PresentationCML")];
	EndIf;
	
	Return MappedName;
	
EndFunction

// The function returns VAT rate value that corresponds to the passed parameter.
// If parameter PresentationBED is passed to the function, then the function returns AppliedValue of VAT rate and vice versa.
//
// Parameters:
//   PresentationBED - String - String presentation of VAT rate.
//   AppliedValue - EnumRef.VATRates, CatalogRef.VATRates - applied
//     presentation of the corresponding value of VAT rate.
//
// Returns:
//   String, EnumRef.VATRates, CatalogRef.VATRates - corresponding presentation of VAT rate.
//
Function VATRateFromCorrespondence(PresentationBED = "", AppliedValue = Undefined) Export
	
	Map = New Map;
	ElectronicDocumentsOverridable.FillVATRateMatching(Map);
	Value = Undefined;
	If ValueIsFilled(PresentationBED) Then
		Value = Map.Get(PresentationBED);
	Else
		For Each KeyAndValue IN Map Do
			If KeyAndValue.Value = AppliedValue Then
				Value = KeyAndValue.Key;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Return Value;
	
EndFunction

// The function converts a string presentation of VAT rate (BED internal presentation) to a numeric one.
//
// Parameters:
//   RowVATRate - String - String presentation of VAT rate.
//
// Returns:
//   Number - numeric presentation of VAT rate.
//
Function TaxRateVATAsNumber(RowVATRate) Export
	
	VATRate = StrReplace(RowVATRate, "\", "/");
	CharPosition = Find(VATRate, "/");
	If CharPosition > 0 Then
		RateAsNumber = Round(Eval(VATRate) * 100, 4);
	Else
		RateAsNumber = Number(VATRate);
	EndIf;
	
	Return RateAsNumber;
	
EndFunction

// The function converts from the VAT rate presentation to enumeration value.
//
// Parameters:
//  RateAsNumber - Number - numeric presentation of VAT rate;
//               - String - String presentation of VAT rate.
//
// Returns:
//   EnumRef, CatalogRef, Undefined - VAT rate value of the applied solution.
//
Function VATRateFromDisplay(VATRatePresentation) Export
	
	VATValue = Undefined;
	
	If TypeOf(VATRatePresentation) = Type("String") Then
		StrVATRate = TrimAll(VATRatePresentation);
	ElsIf TypeOf(VATRatePresentation) = Type("Number") Then
		StrVATRate = String(VATRatePresentation);
	Else // Wrong type
		StrVATRate = Undefined;
	EndIf;
	
	If StrVATRate = Undefined OR Find("WITHOUT VAT", Upper(StrVATRate)) > 0 Then
		VATValue = "Without VAT";
	Else
		StrVATRate = StrReplace(StrReplace(StrReplace(StrReplace(StrVATRate, ",", "."), "\", "/"), " ", ""), "%", "");
		// # - separator of rate presentations.
		If Find("0", StrVATRate) > 0 Then
			VATValue = "0";
		ElsIf Find("10#0.1#0.10", StrVATRate) > 0 Then
			VATValue = "10";
		ElsIf Find("18#0.18", StrVATRate) > 0 Then
			VATValue = "18";
		ElsIf Find("20#0.2#0.20", StrVATRate) > 0 Then
			VATValue = "20";
		ElsIf Find("10/110#0.0909#9.0909", StrVATRate) > 0 Then
			VATValue = "10/110";
		ElsIf Find("18/118#0.1525#15.2542", StrVATRate) > 0 Then
			VATValue = "18/118";
		ElsIf Find("20/120#0.1667#16.6667", StrVATRate) > 0 Then
			VATValue = "20/120";
		EndIf;
	EndIf;
	
	VATRate = VATRateFromCorrespondence(VATValue);
	
	Return VATRate;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Errors processor

// Returns a user message text by an error code.
//
// Parameters:
//  ErrorCode - String, error code;
//  ThirdPartyErrorDescription - String, error description passed to another system.
//
// Returns:
//  MessageText - String - overridden error description.
//
Function GetMessageAboutError(ErrorCode, ThirdPartyErrorDescription = "") Export
	
	SetPrivilegedMode(True);
	
	MessagePattern = NStr("en = 'Code of error %1. %2'");
	
	ErrorMessages = New Map;
	ErrorMessagesInitialization(ErrorMessages);
	
	ErrorInfo = ErrorMessages.Get(ErrorCode);
	If ErrorInfo = Undefined OR Not ValueIsFilled(ErrorInfo) Then
		ErrorInfo = ThirdPartyErrorDescription;
	EndIf;
	
	ElectronicDocumentsOverridable.ChangeMessageAboutError(ErrorCode, ErrorInfo);
	
	MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, ErrorCode, ErrorInfo);
	
	Return MessageText;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// Gets a parameter match table for metadata types and their user presentations.
//
// Parameters:
//  MapTable - table - parameter match for metadata types and their user presentations.
//
Function GetCorrespondenceTableParametersToUserPresentations()
	
	ValueTable = New ValueTable;
	ValueTable.Columns.Add("SourceType");
	ValueTable.Columns.Add("Parameter");
	ValueTable.Columns.Add("Presentation");
	
	ElectronicDocumentsOverridable.GetCorrespondenceTableParametersToUserPresentations(
		ValueTable);
	
	Return ValueTable;
	
EndFunction

Function ObjectsAttributesTableInitialization()
	
	AttributesTable = New ValueTable;
	
	Columns = AttributesTable.Columns;
	Columns.Add("Order",                    New TypeDescription("Number"));
	Columns.Add("ObjectName",                 New TypeDescription("String"));
	Columns.Add("TabularSectionName",          New TypeDescription("String"));
	Columns.Add("ObjectAttributes",           New TypeDescription("String"));
	Columns.Add("ObjectAttributesStructure", New TypeDescription("Structure"));
	
	AttributesTable.Indexes.Add("ObjectName");
	
	Return AttributesTable;
	
EndFunction

Procedure ErrorMessagesInitialization(ErrorMessages)
	
	// Common error codes
	ErrorMessages.Insert("001", );
	ErrorMessages.Insert("002", );
	ErrorMessages.Insert("003", );
	ErrorMessages.Insert("004", );
	ErrorMessages.Insert("005", );
	ErrorMessages.Insert("006", NStr("en = 'Cannot extract files from the archive. Path to the archive files must be up to 256 characters.
										|Possible methods
										| to fix the error: - in the operating system settings, in the environment
										| variables, change a path to temporary files; - change a place of temporary file directory in procedure ""ElectronicDocumentsOverridable.TemporaryFilesCurrentDirectory"".'"));
	// 1C code errors
	ErrorMessages.Insert("0", NStr("en = 'One of the available in the request signatures belongs to the unknown person.'"));
	ErrorMessages.Insert("2", NStr("en = 'One of signatures is incorrect'"));
	ErrorMessages.Insert("3", NStr("en = 'Two different signatures must be presented.'"));
	ErrorMessages.Insert("4", NStr("en = 'Invalid content type: binary.'"));
	ErrorMessages.Insert("5", NStr("en = 'At least one signature must be presented.'"));
	ErrorMessages.Insert("6", NStr("en = 'Not all signatures differ.'"));
	ErrorMessages.Insert("7", NStr("en = 'All the signatures do not provide the level of permissions required for the operations.'"));
	ErrorMessages.Insert("8", NStr("en = 'One of the signatories is unknown.'"));
	ErrorMessages.Insert("9", NStr("en = 'Content of transport message type is incorrect, expected: application/xml.'"));
	ErrorMessages.Insert("10", NStr("en = 'Content of business message type is incorrect, expected: application/xml.'"));
	ErrorMessages.Insert("11", NStr("en = 'Not all the signatures correspond to the same client.'"));
	ErrorMessages.Insert("12", NStr("en = 'All the available signatures in the request are not enough to get a right of access to the requested account.'"));
	ErrorMessages.Insert("13", NStr("en = 'HTTP query URL is incorrect. Only the resources requests and statuses are supported.'"));
	ErrorMessages.Insert("14", NStr("en = 'Error of transport container verification.'"));
	ErrorMessages.Insert("15", NStr("en = 'Error of the business data container verification.
	                                          |Contact bank support'"));
	ErrorMessages.Insert("16", NStr("en = 'Statement of account has too small initial date.'"));
	ErrorMessages.Insert("17", NStr("en = 'The statement has too big end date.'"));
	ErrorMessages.Insert("18", NStr("en = 'The document date is incorrect.'"));
	ErrorMessages.Insert("19", NStr("en = 'Bank account does not correspond to the BIN.'"));
	ErrorMessages.Insert("21", NStr("en = 'Not allowed instruction.'"));
	
	ErrorMessages.Insert("100", NStr("en = 'Failed to create cryptography manager on the computer.'"));
	ErrorMessages.Insert("101", NStr("en = 'Certificate is not found in the certificates storage on the computer.'"));
	ErrorMessages.Insert("102", NStr("en = 'The certificate is not valid'"));
	ErrorMessages.Insert("103", NStr("en = 'Failed to perform the encryption/decryption operations on the computer.'"));
	ErrorMessages.Insert("104", NStr("en = 'Cannot generate/verify DS on the computer.'"));
	ErrorMessages.Insert("105", NStr("en = 'No certificates available in the certificates storage on the computer.'"));
	
	ErrorMessages.Insert("110", NStr("en = 'Failed to create cryptography manager on the server.'"));
	ErrorMessages.Insert("111", NStr("en = 'Certificate has not been found in the certificate storage on the server.'"));
	ErrorMessages.Insert("112", NStr("en = 'The certificate is not valid'"));
	ErrorMessages.Insert("113", NStr("en = 'Failed to execute the encryption/decryption operations on the server.'"));
	ErrorMessages.Insert("114", NStr("en = 'Cannot generate/verify DS on the server.'"));
	ErrorMessages.Insert("115", NStr("en = 'No certificates available in the certificates storage on the server.'"));
	
	ErrorMessages.Insert("106", NStr("en = '1C platform version is lower than ''8.2.17"".'"));
	ErrorMessages.Insert("107", NStr("en = 'Failed to create the exchange directories.'"));
	
	ErrorMessages.Insert("121", NStr("en = 'Failed to connect to the FTP server.'"));
	ErrorMessages.Insert("122", NStr("en = 'Cannot create a directory as a file with the same name already exists in the FTP resource.'"));
	ErrorMessages.Insert("123", NStr("en = 'Cannot create the directory.'"));
	ErrorMessages.Insert("124", NStr("en = 'Cannot open the directory.'"));
	ErrorMessages.Insert("125", NStr("en = 'An error occurred when searching for files in the FTP resource.'"));
	ErrorMessages.Insert("126", NStr("en = 'There are differentiated the data of the recorded test file and then of the read test file in the directory.'"));
	ErrorMessages.Insert("127", NStr("en = 'Failed to record file to directory.'"));
	ErrorMessages.Insert("128", NStr("ru = ""Cannot read a file in the directory."));
	ErrorMessages.Insert("129", NStr("en = 'Failed to delete the file.'"));
	
	// Error codes of operator Taxcom
	// Method CertificateLogin: identification
	// and authorization Synchronous mode without a query to DB
	ErrorMessages.Insert("2501", ); // Vendor identifier is not specified (parameter name?) 400 0501
	ErrorMessages.Insert("3109", ); // Certificate 403 3100 is not specified
	ErrorMessages.Insert("3107", ); // Incorrect body of certificate 403 3107
	ErrorMessages.Insert("3101", ); // Certificate 403 3101 is expired
	ErrorMessages.Insert("3102", ); // Cannot build a trust chain for the specified certificate 403 3102
	
	// Synchronous mode with DB query
	ErrorMessages.Insert("1301", ); // Vendor with the specified identifier can not be authorized 401 1300
	ErrorMessages.Insert("3103", ); // The certificate is not associated with any Taxcom subscriber 403 3103
	ErrorMessages.Insert("3104", ); // The certificate is associated with multiple subscribers but the subscriber identifier (TaxcomID) is not specified 403 3104
	ErrorMessages.Insert("3105", ); // The certificate is associated with multiple subscribers but the specified subscriber identifier format (TaxcomID) is incorrect 403 3105
	ErrorMessages.Insert("3106", ); // The certificate is associated with multiple subscribers but the specified subscriber identifier (TaxcomID) is not associated with any Taxcom subscriber 403 3106
	ErrorMessages.Insert("1102", ); // Subscriber access to API 401 1100 is denied
	ErrorMessages.Insert("1101", ); // Access for this subscriber is denied 401 1101
	ErrorMessages.Insert("3108", ); // Certificate is revoked (in the future) 403 3108
	
	// Method SendMessage: loading transport
	// containers Synchronous mode without a query to DB
	ErrorMessages.Insert("1201", ); // Token expired (it is required to log on again) 401 1200
	ErrorMessages.Insert("2118", ); // Size of the container being sent is not within the allowed range between 0 and (digit) 400 0100
	ErrorMessages.Insert("2107", ); // The container being sent is not ZIP archive 400 0107
	ErrorMessages.Insert("2108", ); // IN a container file required 400 metaxml NotAvailable 0108
	ErrorMessages.Insert("2109", ); // File meta.xml is not XML file (standards?) 400 0109
	ErrorMessages.Insert("2111", ); // Structure of file meta.xml does not correspond to the approved scheme 400 0111
	ErrorMessages.Insert("2101", ); // Correct document flow identifier (DocFlowID) is not specified in file meta.xml 400 0101
	ErrorMessages.Insert("2102", ); // Files associated with more than one document flow are detected in the container being sent 400 0102
	ErrorMessages.Insert("2113", ); // Only one file can be sent in this document flow 400 0113
	ErrorMessages.Insert("2103", ); // Schedule code (ReglamentCode) is not specified in file meta.xml 400 0103
	ErrorMessages.Insert("2114", ); // Incorrect schedule code (ReglamentCode) is specified in file meta.xml 400 0114
	ErrorMessages.Insert("2104", ); // Transaction code (TransactionCode) is not specified in file meta.xml 400 0104
	ErrorMessages.Insert("2303", ); // Transaction with code <TransactionCode> can not be used in document flow < ReglamentCode > 400 0300
	ErrorMessages.Insert("3108", ); // File <attachment file name> specified in meta.xml is not found in the container being sent 400 0105
	ErrorMessages.Insert("0110", ); // File card.xml is not an XML file 400 0110
	ErrorMessages.Insert("0112", ); // Structure of file card.xml does not correspond to the approved scheme 400 0112
	ErrorMessages.Insert("0106", NStr("en = 'An incorrect format company ID is specified in the contract.'")); // Incorrect format of sender identifier (parameter name?) in file card.xml 400 0106
	ErrorMessages.Insert("0115", ); // Incorrect format of recipient ID (parameter name?) in file card.xml 400 0115
	
	// Synchronous mode with DB query
	ErrorMessages.Insert("0201", ); // Sender identifier (parameter name?) corresponds to the account 400 0201
	ErrorMessages.Insert("0401", ); // Document flow with the specified identifier is already registered (DocFlowID) 400 0401
	ErrorMessages.Insert("0402", ); // Document flow with the specified identifier is not registered (DocFlowID) 400 0402
	ErrorMessages.Insert("0301", ); // This transaction <transaction code> is already performed for the document flow < DocFlowID > 400 0301
	
	// Asynchronous mode
	ErrorMessages.Insert("0202", NStr("en = 'A counterparty ID which is not registered in Takskom is not specified in the agreement.'")); // Recipient with the specified ID is not registered 0202
	ErrorMessages.Insert("0203", ); // Recipient with the specified ID is not a sender counterparty 0203
	ErrorMessages.Insert("3200", ); // The document can not be sent due to the billing limitation 3200
	
	// Method GetMessageList: receive incoming transport
	// containers Synchronous mode without a query to DB
	ErrorMessages.Insert("0503", ); // Required parameter "time label (parameter name)" is absent 400 0503
	ErrorMessages.Insert("0504", ); // Incorrect format of time label 400 0504
	
	// Method GetMessage: export incoming transport
	// containers Synchronous mode without a query to DB
	ErrorMessages.Insert("0505", ); // Required parameter "container (document flow) identifier" is absent 400 0505
	ErrorMessages.Insert("0502", ); // wrong format of the document flow identifier 400 0502
	
	// Synchronous mode with DB query
	ErrorMessages.Insert("4100", ); // Message with this <DocFlowID> identifier of document flow is not found 404 4100
	
	// General errors of Taxcom server
	ErrorMessages.Insert("5101", ); // Internal server error 500 0000
	
EndProcedure

Function VTComparisonFieldsAddressesFTS_CML()
	
	VT = New ValueTable;
	
	VT.Columns.Add("FTSPresentation");
	VT.Columns.Add("PresentationCML");
	
	NewRow = VT.Add();
	NewRow.FTSPresentation = "IndexOf";
	NewRow.PresentationCML = "Postal index";
	
	NewRow = VT.Add();
	NewRow.FTSPresentation = "CodeState";
	NewRow.PresentationCML = "Region";
	
	NewRow = VT.Add();
	NewRow.FTSPresentation = "Settlement";
	NewRow.PresentationCML = "Settlement";
	
	NewRow = VT.Add();
	NewRow.FTSPresentation = "City";
	NewRow.PresentationCML = "City";
	
	NewRow = VT.Add();
	NewRow.FTSPresentation = "Street";
	NewRow.PresentationCML = "Street";
	
	NewRow = VT.Add();
	NewRow.FTSPresentation = "Building";
	NewRow.PresentationCML = "Building";
	
	NewRow = VT.Add();
	NewRow.FTSPresentation = "Section";
	NewRow.PresentationCML = "Section";
	
	NewRow = VT.Add();
	NewRow.FTSPresentation = "Qart";
	NewRow.PresentationCML = "Apartment";
	
	NewRow = VT.Add();
	NewRow.FTSPresentation = "StrCode";
	NewRow.PresentationCML = "Country";
	
	Return VT;
	
EndFunction

// Returns a application text and specifies a version used for the bank exchange.
Function ClientApplicationVersionForBank(CharCount = 100) Export
	
	ApplicationVersion = "1C - BED: " + InfobaseUpdateED.LibraryVersion()
						+ "; " + Metadata.Name + ": " + Metadata.Version;
						
	If CharCount > 0 Then
		ApplicationVersion = Left(ApplicationVersion, CharCount);
	EndIf;
	
	Return TrimAll(ApplicationVersion);
	
EndFunction

#Region _SSL_DigitalSignatureReUse

// Cryptography module path for the current computer.
Function CryptographyModulePath() Export
	
	ServerPlatformType = CommonUseReUse.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Windows_x86 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		Return ""; // cryptography module path is not required in Windows
	EndIf;
	
	ComputerName = ComputerName();
	ModulePath = "";
	
	SetPrivilegedMode(True);
	
	// Prepare a filter structure by dimensions
	FilterStructure = New Structure;
	FilterStructure.Insert("ComputerName", ComputerName);
	
	// Get a structure with record resources data
	StructureOfResources = InformationRegisters.PathToDigitalSignaturesAndEncryptionApplicationsOnLinuxServers.Get(FilterStructure);
	
	// Get path from the register
	ModulePath = StructureOfResources.CryptographyModulePath;
	
	Return ModulePath;
	
EndFunction

#EndRegion
