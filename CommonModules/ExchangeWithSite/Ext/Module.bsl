////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS

// Writes the changed object references to the structure by the exchange plan node.
//
// Parameters:
// ExchangePlanNode - ExchangePlan.Ref
// ReturnStructure - Structure
//
Procedure FillChangesStructureForNode(ExchangePlanNode, ReturnStructure) Export
	
	ReturnStructure.Insert("Products", New Array);
	ReturnStructure.Insert("Orders", New Array);
	ReturnStructure.Insert("Files", New Array);
	
	Query = New Query(
		"SELECT
		|	ProductsAndServicesChanges.Ref AS Ref,
		|	""Products"" AS ReferenceType
		|FROM
		|	Catalog.ProductsAndServices.Changes AS ProductsAndServicesChanges
		|WHERE
		|	ProductsAndServicesChanges.Node = &Node
		|
		|UNION ALL
		|
		|SELECT
		|	ProductsAndServicesAttachedFilesChanges.Ref,
		|	""Files""
		|FROM
		|	Catalog.ProductsAndServicesAttachedFiles.Changes AS ProductsAndServicesAttachedFilesChanges
		|WHERE
		|	ProductsAndServicesAttachedFilesChanges.Node = &Node
		|
		|UNION ALL
		|
		|SELECT
		|	OrdersChanges.Ref,
		|	""Orders""
		|FROM
		|	Document.CustomerOrder.Changes AS OrdersChanges
		|WHERE
		|	OrdersChanges.Node = &Node");
	
	Query.SetParameter("Node", ExchangePlanNode);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		ReturnStructure[Selection.ReferenceType].Add(Selection.Ref);
		
	EndDo;
	
EndProcedure

// Returns the result of the test connection to the site.
//
// Parameters:
// ExchangeNode
//
// Returns:
// Row.
//
Function PerformTestConnectionToSite(ExchangeNode, MessageText) Export
	
	ConnectionSettings = New Structure;
	ConnectionType = "catalog";
	ErrorDescription = "";
	
	If Not GetConnectionSettings(ExchangeNode, ConnectionSettings, ErrorDescription) Then
		
		MessageText = NStr("en = 'Error on receiving connection with site parameters'") + Chars.LF + ErrorDescription;
		Return False;
		
	EndIf;
	
	Join = SetConnectionWithServer(ConnectionSettings, ErrorDescription);
	If Join = Undefined Then
		
		MessageText = NStr("en = 'Error on setting connection with site.'") + Chars.LF + ErrorDescription;
		Return False;
		
	EndIf;
	
	ServerResponse = "";
	
	Successfully = PerformAuthorizationForConnection(Join, ConnectionSettings, ServerResponse, ErrorDescription, ConnectionType);
	If Successfully Then
		
		MessageText = NStr("en = 'Connection with site set successfully.'");
		
	Else
		
		MessageText = NStr("en = 'Can not set connection.'") + Chars.LF + ErrorDescription;
		
	EndIf;
	
	Return Successfully;
	
EndFunction

Function GetPrefixForOrderWithSite() Export
	
	SetPrivilegedMode(True);
	
	Prefix = Constants.PrefixForExchangeWithSite.Get();
	If Not ValueIsFilled(Prefix) Then
		Prefix = GetDefaultPrefixForOrderWithSite();
	EndIf;
	
	Return Prefix;
	
EndFunction

Function GetDefaultPrefixForOrderWithSite() Export
	
	Return "AS";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR SESSION PARAMETER CONFIGURING

// Configure session parameters. Called from the session module.
//
// Parameters:
// ParameterName				- String with the
// session parameter name SpecifiedParameters	- array of all specified session parameters.
//
Procedure SetSessionParameters(ParameterName, SpecifiedParameters) Export
	
	If Not (ParameterName = "DataExchangeWithSiteEnabled" 
		OR ParameterName = "UsedExchangeWithSiteNodes") Then
		
		Return;
		
	EndIf;
	
	UpdateSessionParameters();
	
	SpecifiedParameters.Add("DataExchangeWithSiteEnabled");
	SpecifiedParameters.Add("UsedExchangeWithSiteNodes");
	
EndProcedure

// Receives the array of the exchange nodes used in exchange settings.
//
Function GetUsedExchangeNodesWithSite()
	
	Query = New Query(
		"SELECT ALLOWED
		|	ExchangeSmallBusinessSite.Ref AS Ref
		|FROM
		|	ExchangePlan.ExchangeSmallBusinessSite AS ExchangeSmallBusinessSite
		|WHERE
		|	Not ExchangeSmallBusinessSite.DeletionMark
		|	AND ExchangeSmallBusinessSite.Ref <> &ThisNode");
		
		Query.SetParameter("ThisNode", ExchangePlans.ExchangeSmallBusinessSite.ThisNode());
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Updates the session parameter values.
//
Procedure UpdateSessionParameters() Export
	
	SetPrivilegedMode(True);
	
	UseExchangeWithSites = GetFunctionalOption("UseExchangeWithSites");
	
	UsedExchangeWithSiteNodes = New Array;
	If UseExchangeWithSites Then
		
		UsedExchangeWithSiteNodes = GetUsedExchangeNodesWithSite();
		
	EndIf;
	
	DataExchangeWithSiteEnabled = Not UsedExchangeWithSiteNodes.Count() = 0;
	
	SessionParameters.DataExchangeWithSiteEnabled = DataExchangeWithSiteEnabled;
	SessionParameters.UsedExchangeWithSiteNodes = New FixedArray(UsedExchangeWithSiteNodes);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SUBSCRIPTION HANDLERS

// ExchangeWithSiteBeforeRegisterRecording event subscription handler.
// Records changes for the site exchange plan nodes. 
//
Procedure ExchangeWithSiteBeforeWriteRegisterBeforeWrite(Source, Cancel, Replacing) Export
	
	RecordChanges(Source, Replacing);
	
EndProcedure

// ExchangeWithSiteAtCatalogRecording event subscription handler.
// Records changes for the site exchange plan nodes. 
//
Procedure ExchangeWithSiteOnObjectWriteOnWrite(Source, Cancel) Export
	
	RecordChanges(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS RECORDING CHANGES

// Selectively records changes for the site exchange plan nodes.
//
// Parameters:
// Object		- Metadata object - Replacing
// event source - record mode for the register record set.
//
Procedure RecordChanges(Object, Replacing = False)
	
	SetPrivilegedMode(True);
	
	If Not SessionParameters.DataExchangeWithSiteEnabled Then
		Return;
	EndIf;
	
	ObjectType = TypeOf(Object);
	NodesArrayProducts = GetNodesArrayForRegistration(True);
	NodesArrayOrders = GetNodesArrayForRegistration(,True);
	
	If ObjectType = Type("AccumulationRegisterRecordSet.InventoryInWarehouses")
		OR ObjectType = Type("InformationRegisterRecordSet.ProductsAndServicesPrices")
		OR ObjectType = Type("InformationRegisterRecordSet.ProductsAndServicesBarcodes") Then
		
		If Replacing Then
			
			MetadataObject = Object.Metadata();
			
			BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(MetadataObject);
			
			If BaseTypeName = CommonUse.TypeNameInformationRegisters() Then
				
				OldRecordSet = InformationRegisters[MetadataObject.Name].CreateRecordSet();
				
			ElsIf BaseTypeName = CommonUse.TypeNameAccumulationRegisters() Then
				
				OldRecordSet = AccumulationRegisters[MetadataObject.Name].CreateRecordSet();
				
			Else
				
				Return;
				
			EndIf;
			
			For Each FilterValue IN Object.Filter Do
				
				If FilterValue.Use = False Then
					Continue;
				EndIf;
				
				FilterRow = OldRecordSet.Filter.Find(FilterValue.Name);
				FilterRow.Value = FilterValue.Value;
				FilterRow.Use = True;
				
			EndDo;
			
			OldRecordSet.Read();
			
			For Each Record IN OldRecordSet Do
			
				ExchangePlans.RecordChanges(NodesArrayProducts, Record.ProductsAndServices);
			
			EndDo;
			
		EndIf;
		
		For Each Record IN Object Do
			
			ExchangePlans.RecordChanges(NodesArrayProducts, Record.ProductsAndServices);
			
		EndDo;
		
	ElsIf ObjectType = Type("AccumulationRegisterRecordSet.CustomerOrders") Then
		
		If Not Constants.UseCustomerOrderStates.Get() Then
			
			Recorder = Object.Filter.Recorder.Value;
			
			If TypeOf(Recorder) = Type("DocumentRef.CustomerOrder") Then
				
				Return;
				
			EndIf;
			
			For Each Record IN Object Do
				
				ExchangePlans.RecordChanges(NodesArrayOrders, Record.CustomerOrder);
				
			EndDo;
			
		EndIf;
		
	ElsIf ObjectType = Type("AccumulationRegisterRecordSet.InvoicesAndOrdersPayment") Then
		
		If Not Constants.UseCustomerOrderStates.Get() Then 
			
			Recorder = Object.Filter.Recorder.Value;
			
			If TypeOf(Recorder) = Type("DocumentRef.CustomerOrder") Then 
				
				Return;
				
			EndIf;
			
			For Each Record IN Object Do
				
				If TypeOf(Record.InvoiceForPayment) = Type("DocumentRef.CustomerOrder")
					AND ValueIsFilled(Record.InvoiceForPayment) Then 
					
					ExchangePlans.RecordChanges(NodesArrayOrders, Record.InvoiceForPayment);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	ElsIf ObjectType = Type("CatalogObject.ProductsAndServices") Then
		
		ExchangePlans.RecordChanges(NodesArrayProducts, Object.Ref);
		
	ElsIf ObjectType = Type("CatalogObject.ProductsAndServicesAttachedFiles") Then
		
		If Not TypeOf(Object.FileOwner) = Type("CatalogRef.ProductsAndServices") Then
			Return;
		EndIf;
		
		ExchangePlans.RecordChanges(NodesArrayProducts, Object.FileOwner);
		
		// We record all files by ProductsAndServices otherwise CMS
		// deletes the files that are absent in the exchange file in change import mode.
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	ProductsAndServicesAttachedFiles.Ref
		|FROM
		|	Catalog.ProductsAndServicesAttachedFiles AS ProductsAndServicesAttachedFiles
		|WHERE
		|	Not ProductsAndServicesAttachedFiles.DeletionMark
		|	AND ProductsAndServicesAttachedFiles.FileOwner = &FileOwner";
		
		Query.SetParameter("FileOwner", Object.FileOwner);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
		
			ExchangePlans.RecordChanges(NodesArrayProducts, Selection.Ref);
		
		EndDo; 
		
	ElsIf ObjectType = Type("CatalogObject.ProductsAndServicesCharacteristics") Then
		
		If Not GetFunctionalOption("UseCharacteristics") Then
			
			Return;
			
		EndIf;
		
		If TypeOf(Object.Owner) = Type("CatalogRef.ProductsAndServices") Then
			
			ExchangePlans.RecordChanges(NodesArrayProducts, Object.Owner);
			
		EndIf;
		
	ElsIf ObjectType = Type("DocumentObject.CustomerOrder") Then 
		
		If Not GetOrderAttributesOnSite(Object.Ref) = Undefined Then
			
			ExchangePlans.RecordChanges(NodesArrayOrders, Object.Ref);
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EXCHANGE START PROCEDURE

// Starts the exchange with the site according to the scheduled job.
//
// Parameters:
// NodeCodeExchange		- String with the exchange plan node code.
//
Procedure TaskExecuteExchange(NodeCodeExchange) Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	ExchangeNode = ExchangePlans.ExchangeSmallBusinessSite.FindByCode(NodeCodeExchange);
	
	If Not ValueIsFilled(ExchangeNode) Then
		
		WriteLogEvent("Exchange with sites",
			EventLogLevel.Error,
			ExchangeNode.Metadata(),
			ExchangeNode,
			NStr("en = 'Do not found exchange node with code'") + " " + NodeCodeExchange);
		
		Return;
		
	EndIf;
	
	If ExchangeNode.DeletionMark Then
		
		WriteLogEvent("Exchange with sites",
			EventLogLevel.Information,
			ExchangeNode.Metadata(),
			ExchangeNode,
			NStr("en = 'Exchange setting is marked for removing. The exchange has been canceled.'"));
		
		Return;
		
	EndIf;
	
	MessageText = "";
	If Not PerformTestConnectionToSite(ExchangeNode, MessageText) Then
		
		WriteLogEvent("Exchange with sites",
			EventLogLevel.Warning,
			ExchangeNode.Metadata(),
			ExchangeNode,
			MessageText + NStr("en = ' The exchange has been canceled.'"));
		
		Return;
		
	EndIf;
	
	RunExchange(ExchangeNode, NStr("en = 'Background exchange'"));
	
EndProcedure

// Starts the exchange with the site.
//
// Parameters:
// ExchangeNode		- ExchangePlanRef.ExchangeSmallBusinessSite,
// ExchangeRunMode - String, event
// name for EventLog ExportChangesOnly - Boolean, it influences on the volume of exported data.
//
Procedure RunExchange(ExchangeNode, ExchangeRunMode, ExportChangesOnly = True) Export
	
	If ExchangeNode = ExchangePlans.ExchangeSmallBusinessSite.ThisNode() Then
		Return;
	EndIf;
	
	MainParameters = GetMainExchangeParametersStructure();
	
	MainParameters.Insert("ExchangeOverWebService", False);
	MainParameters.Insert("ExchangeRunMode", ExchangeRunMode);
	MainParameters.Insert("ExportChangesOnly", ExportChangesOnly);
	
	SystemInfo = New SystemInfo;
	WindowsPlatform = SystemInfo.PlatformType = PlatformType.Windows_x86
		OR SystemInfo.PlatformType = PlatformType.Windows_x86_64;
	
	MainParameters.Insert("WindowsPlatform", WindowsPlatform);
	
	AddNodeSettingsToParameters(ExchangeNode, MainParameters);
	
	InformationTable = InformationRegisters.DataExchangeStatus.CreateRecordSet().Unload();
	InformationTable.Columns.Add("Definition", New TypeDescription("String"));
	
	InformationTableRow = InformationTable.Add();
	InformationTableRow.StartDate = CurrentDate();
	
	If MainParameters.ExportToSite Then
		
		ErrorDescription = "";
		ConnectionSettings = New Structure;
		
		If Not GetConnectionSettings(MainParameters, ConnectionSettings, ErrorDescription) Then
			
			InformationTableRow.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
			InformationTableRow.Definition = ErrorDescription;
			RunActionsAtExchangeCompletion(MainParameters, InformationTable, True);
			
			Return;
			
		EndIf;
		
		AddExchangeProtocolParametersIntoStructure(ConnectionSettings);
		
		MainParameters.Insert("ConnectionSettings", ConnectionSettings);
		
	EndIf;
	
	ExportDirectory = MainParameters.ExportDirectory;
	If IsBlankString(ExportDirectory) Then
		
		ExportDirectory = TempFilesDir();
		
	Else
		
		ExportDirectory = MainParameters.ExportDirectory;
		LastChar = Right(ExportDirectory, 1);
		
		If Not LastChar = "\" Then
			ExportDirectory = ExportDirectory + "\";
		EndIf;
		
	EndIf;
	
	ExportDirectorySafetySubDir = "webdata - " + ExchangeNode.UUID();
	DirectoryOnHardDisk = ExportDirectory + ExportDirectorySafetySubDir;
	DirectoryOnHardDisk = PreparePathForPlatform(WindowsPlatform, DirectoryOnHardDisk);
	
	Try
		
		CreateDirectory(DirectoryOnHardDisk);
		
	Except
		
		InformationTableRow.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
		InformationTableRow.Definition = ExceptionalErrorDescription();
		RunActionsAtExchangeCompletion(MainParameters, InformationTable, True);
		
		Return;
		
	EndTry;
	
	ErrorDescription = "";
	If Not ClearDirectory(DirectoryOnHardDisk, ErrorDescription) Then
		
		InformationTableRow.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
		InformationTableRow.Definition = ErrorDescription;
		RunActionsAtExchangeCompletion(MainParameters, InformationTable, True);
		
		Return;
		
	EndIf;
	
	ImportFile = MainParameters.ImportFile;
	ImportFile = PreparePathForPlatform(WindowsPlatform, ImportFile);
	MainParameters.Insert("ImportFile", ImportFile);
	
	If MainParameters.ExportChangesOnly Then
		ChangesStructure = GetAllChangesFromExchangePlan(ExchangeNode);
	EndIf;
	
	ProductsSucessfullyExported = True;
	
	MainParameters.Insert("DirectoryOnHardDisk", DirectoryOnHardDisk);
	MainParameters.Insert("FilesSubDir", "import_files");
	MainParameters.Insert("ChangesStructure", ChangesStructure);
	
	DeleteChangesRegistrationProducts = False;
	DeleteChangesRegistrationOrders = False;
	
	If MainParameters.ProductsExchange Then 
		
		InformationTableRow.ActionOnExchange = Enums.ActionsAtExchange.DataExport;
		InformationTableRow.Definition = String(CurrentDate()) + " " + NStr("en = 'Products export launch'");
		
		ProductsSucessfullyExported = ExportProductsAndServices(MainParameters, InformationTableRow);
		
		If MainParameters.ExportChangesOnly
			AND ProductsSucessfullyExported Then
			
			DeleteChangesRegistrationProducts = True;
			
		EndIf;
		
	EndIf;
	
	OrdersSucessfullyExported = True;
	
	If MainParameters.OrdersExchange Then
		
		OrderStatusInProcess = ExchangeWithSiteReUse.GetStatusInProcessOfCustomerOrders();
		MainParameters.Insert("OrderStatusInProcess", OrderStatusInProcess);
		
		If Not MainParameters.ProductsExchange Then
			InformationTable.Delete(InformationTableRow);
		EndIf;
		
		OrdersSucessfullyExported = RunOrdersExchange(MainParameters, InformationTable);
		
		If MainParameters.ExportChangesOnly
			AND OrdersSucessfullyExported Then
			
			DeleteChangesRegistrationOrders = True;
			
		EndIf;
		
	EndIf;
	
	If DeleteChangesRegistrationProducts OR DeleteChangesRegistrationOrders Then
		
		DeleteChangeRecords(ExchangeNode, ChangesStructure, DeleteChangesRegistrationProducts, DeleteChangesRegistrationOrders);
		
	EndIf;
	
	RunActionsAtExchangeCompletion(MainParameters, InformationTable);
	
	If MainParameters.PerformFullExportingCompulsorily
		AND ProductsSucessfullyExported
		AND OrdersSucessfullyExported Then
		
		NodeObject = ExchangeNode.GetObject();
		NodeObject.PerformFullExportingCompulsorily = False;
		NodeObject.Write();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS TO EXPORT PRODUCTS AND SERVICES

// Exports products and services.
//
// Parameters:
//	Parameters				- Structure containing the
//	required parameters InformationTableRow	- Values table row
//
//Return
//	value Successfully - True if exporting is completed without errors.
//
Function ExportProductsAndServices(Parameters, InformationTableRow)
	
	ExportedObjects = 0;
	
	Successfully = ExportProductsAndServicesToDirOnDisc(Parameters, InformationTableRow, ExportedObjects);
	
	If Not Successfully Then
		
		CommitProductsAndServicesExportCompletion(InformationTableRow, Enums.ExchangeExecutionResult.Error);
		Return Successfully;
		
	ElsIf ExportedObjects = 0 OR Not Parameters.ExportToSite Then
		
		CommitProductsAndServicesExportCompletion(InformationTableRow, Enums.ExchangeExecutionResult.Completed);
		Return Successfully;
		
	EndIf;
	
	Successfully = ExportOfferFolderToSite(Parameters, InformationTableRow);
	
	If Successfully Then
		CommitProductsAndServicesExportCompletion(InformationTableRow, Enums.ExchangeExecutionResult.Completed);
	Else
		CommitProductsAndServicesExportCompletion(InformationTableRow, Enums.ExchangeExecutionResult.Error);
	EndIf;
	
	Return Successfully;
	
EndFunction

// Exports products and services to xml file on the disk.
//
// Parameters:
// Parameters				- Structure,
// main InformationTableString parameters	- String of
// the ExportedObjects value table		- Number, quantity of exported objects.
//
Function ExportProductsAndServicesToDirOnDisc(Parameters, InformationTableRow, ExportedObjects)
	
	DirectoriesTable = PrepareDirectoriesTable(Parameters);
	
	ImportPriceKindsIntoArray(Parameters);
	
	PrepareProductsAndServicesChangesArray(Parameters);
	
	ExchangeFileIndex = 0;
	IndexOfFileExchangeString = "";
	
	Successfully = True;
	
	For Each DirectoriesTableRow IN DirectoriesTable Do
		
		DirectoriesTableRow.ResultStructure =
			New Structure("ProductsExported,ExportedPictures,ExportedOffers,ErrorDescription", 0, 0, 0, "");
		
		Parameters.Insert("DirectoriesTableRow", DirectoriesTableRow);
		PrepareDataForExporting(Parameters);
		
		If Parameters.ProductsAndServicesSelection.Count() = 0 Then
			// If there is no data of the products and services, do not generate XDTOobjects.
			Continue;
		EndIf;
		
		If ExchangeFileIndex > 0 Then
			IndexOfFileExchangeString = Format(ExchangeFileIndex, "NG=");
		EndIf;
		
		ExchangeFileIndex = ExchangeFileIndex + 1;
		
		DirectoryFileName = PreparePathForPlatform(Parameters.WindowsPlatform,
			Parameters.DirectoryOnHardDisk + "\import" + IndexOfFileExchangeString + ".xml");
			
		PriceFileName = PreparePathForPlatform(Parameters.WindowsPlatform,
			Parameters.DirectoryOnHardDisk + "\offers" + IndexOfFileExchangeString + ".xml");
			
		NamespaceURI = "urn:1C.ru:commerceml_205";
		CMLPackage = XDTOFactory.packages.Get(NamespaceURI);
		
		Successfully = ExportClassifierAndDirectory(Parameters, DirectoryFileName, CMLPackage);
		
		If Not Successfully Then
			Break;
		EndIf;
		
		If Parameters.SelectionOfPrice.Count() > 0 Then
			
			Successfully = ExportPackageOfOffers(Parameters, PriceFileName, CMLPackage);
			
			If Not Successfully Then
				Break;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	PrepareFinalInformationAboutGoodsExport(DirectoriesTable, InformationTableRow, ExportedObjects);
	
	Return Successfully;
	
EndFunction

// Exports the directory and offer package files to the site.
//
// Parameters:
// Parameters				- Structure,
// main InformationTableString parameters	- Value table row.
//
Function ExportOfferFolderToSite(Parameters, InformationTableRow)
	
	ArrayOfSubdirectories = New Array;
	
	If Parameters.ExportPictures Then
		
		ArrayOfSubdirectories.Add(Parameters.FilesSubDir);
		
	EndIf;
	
	ErrorDescription = "";
	Successfully = ImportToSite(Parameters, ArrayOfSubdirectories, ErrorDescription, True);
	
	If Successfully Then 
		
		InformationTableRow.Definition = 
			InformationTableRow.Definition + Chars.LF
			+ CurrentDate() + NStr("en = ' Products are successfully exported to the site.'")
			+ ?(IsBlankString(ErrorDescription), "", Chars.LF + NStr("en = 'Additional information about export:'") + Chars.LF + ErrorDescription);
		
	Else
		
		InformationTableRow.Definition = 
			InformationTableRow.Definition + Chars.LF
			+ CurrentDate() + NStr("en = ' Export on site was completed with errors.'") + Chars.LF + ErrorDescription;
		
	EndIf;
	
	Try
		
		DeleteFiles(Parameters.DirectoryOnHardDisk, "*.*");
		
	Except
		
		InformationTableRow.Definition = 
			InformationTableRow.Definition
			+ Chars.LF
			+ ExceptionalErrorDescription(NStr("en = 'Can not clear exchange directory: '")
				+ Parameters.DirectoryOnHardDisk);
		
	EndTry;
	
	Return Successfully;
	
EndFunction

Function PrepareDirectoriesTable(Parameters)
	
	DirectoriesTable = Parameters.SavedDirectoriesTable.Get();
	
	For Each FolderData IN DirectoriesTable Do
		
		ArrayDelete = New Array;
		For Each Group IN FolderData.Groups Do
			If Not ValueIsFilled(Group.Value) Then
				ArrayDelete.Add(Group);
			EndIf;
		EndDo;
		
		For Each DeleteItem IN ArrayDelete Do
			FolderData.Groups.Delete(DeleteItem);
		EndDo;
		
	EndDo;
	
	DirectoriesTable.Columns.Add("ResultStructure");
	
	Return DirectoriesTable;
	
EndFunction

Procedure ImportPriceKindsIntoArray(Parameters)
	
	Parameters.Insert("PriceKindsArray", Parameters.PriceKinds.UnloadColumn("PriceKind"));
	
EndProcedure

Procedure PrepareProductsAndServicesChangesArray(Parameters)
	
	ChangesArrayProductsAndServices = New Array;
	
	If Parameters.ExportChangesOnly
		AND Not Parameters.PerformFullExportingCompulsorily Then
		
		ChangesArrayProductsAndServices = Parameters.ChangesStructure.Products;
		
	EndIf;
	
	Parameters.Insert("ChangesArrayProductsAndServices", ChangesArrayProductsAndServices);
	
EndProcedure

// Receives the data necessary for the classifier, directory and
// offer package exporting and adds to the Parameters structure.
//
Procedure PrepareDataForExporting(Parameters)
	
	// Settings composer.
	
	SettingsComposer = GetComposerOfGoodsExportSettings(Parameters.DirectoriesTableRow.CompositionSettingsStorage);
	
	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("UseCharacteristics");
	DCSParameter.Value = Parameters.UseCharacteristics;
	DCSParameter.Use = True;
	
	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("CompanyFolderOwner");
	DCSParameter.Value = Parameters.CompanyFolderOwner;
	DCSParameter.Use = True;
	
	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("PriceKinds");
	DCSParameter.Value = Parameters.PriceKindsArray;
	DCSParameter.Use = True;
	
	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("CurrencyTransactionsAccounting");
	DCSParameter.Value = Parameters.CurrencyTransactionsAccounting;
	DCSParameter.Use = True;
	
	If Parameters.ExportPictures Then 
		DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("PermittedPictureTypes");
		DCSParameter.Value = Parameters.PermittedPictureTypes;
		DCSParameter.Use = True;
	EndIf;
	
	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("PermittedProductsAndServicesTypes");
	DCSParameter.Value = Parameters.PermittedProductsAndServicesTypes;
	DCSParameter.Use = True;
	
	// Filters.
	
	If Parameters.ExportChangesOnly
		AND Not Parameters.PerformFullExportingCompulsorily Then
		
		ChangeComposerFilter(SettingsComposer,
			Parameters.DirectoriesTableRow.Groups,
			Parameters.ChangesArrayProductsAndServices);
		
	Else
		
		ChangeComposerFilter(SettingsComposer,
			Parameters.DirectoriesTableRow.Groups);
		
	EndIf;
	
	// Query.
	
	ProductsExportScheme = ExchangePlans.ExchangeSmallBusinessSite.GetTemplate("ProductsExportScheme");
	Query = GetQueryFromCompositionTemplate(SettingsComposer, ProductsExportScheme);
	
	AddQueriesToBatch(Query.Text, Parameters);
	QueryResultArray = Query.ExecuteBatch();
	
	Parameters.Insert("SelectionOfPrice", QueryResultArray[10].Select());
	Parameters.Insert("WarehousesSelection", QueryResultArray[11].Select());
	
	BalanceTableWarehouses = QueryResultArray[12].Unload();
	BalanceTableWarehouses.Indexes.Add("ProductsAndServices, Characteristic");
	Parameters.Insert("BalanceTableWarehouses", BalanceTableWarehouses);
	
	Parameters.Insert("PriceKindsSelection", QueryResultArray[14].Select());
	
	Parameters.Insert("CharacteristicPropertiesTree", 
		QueryResultArray[15].Unload(QueryResultIteration.ByGroups));
	
	Parameters.Insert("ProductsAndServicesPropertiesSelectionForClassificator", 
		QueryResultArray[20].Select(QueryResultIteration.ByGroups));
	
	ProductsAndServicesPropertiesQueryResult = QueryResultArray[21];
	If ProductsAndServicesPropertiesQueryResult.IsEmpty() Then
		ProductsAndServicesPropertiesSelection = Undefined;
	Else
		ProductsAndServicesPropertiesSelection = ProductsAndServicesPropertiesQueryResult.Select();
		ProductsAndServicesPropertiesSelection.Next();
	EndIf;
		
	Parameters.Insert("ProductsAndServicesPropertiesSelection", ProductsAndServicesPropertiesSelection);
	
	QueryResultOfDirectoryOwnerCompanyData = QueryResultArray[24];
	If QueryResultOfDirectoryOwnerCompanyData.IsEmpty() Then
		DataSelectionOfDirectoryOwnerCompany = Undefined;
	Else
		DataSelectionOfDirectoryOwnerCompany = QueryResultOfDirectoryOwnerCompanyData.Select();
		DataSelectionOfDirectoryOwnerCompany.Next();
	EndIf;
	
	Parameters.Insert("CompanyDataOfDirectoryOwner", DataSelectionOfDirectoryOwnerCompany);
	
	Parameters.Insert("ProductsAndServicesSelection", QueryResultArray[25].Select());
	Parameters.Insert("GroupsTree", QueryResultArray[27].Unload(QueryResultIteration.ByGroupsWithHierarchy));
	
	If Parameters.ExportPictures Then
		
		FilesQueryResult = QueryResultArray[28];
		If FilesQueryResult.IsEmpty() Then
			SelectionFiles = Undefined;
		Else
			SelectionFiles = FilesQueryResult.Select();
			SelectionFiles.Next();
		EndIf;
		
	Else
		SelectionFiles = Undefined;
	EndIf;
	
	Parameters.Insert("SelectionFiles", SelectionFiles);
	
EndProcedure

// Receives the query from the template and initiates query parameters.
// 
// Parameters:
// SettingsComposer - DataCompositionSettingsComposer.
// 
// Returns:
// Query - query received from the data template.
//
Function GetQueryFromCompositionTemplate(SettingsComposer, CompositionSchema) Export
	
	Query = New Query;
	
	TemplateComposer = New DataCompositionTemplateComposer();
	DataCompositionTemplate = TemplateComposer.Execute(CompositionSchema, SettingsComposer.GetSettings(),,,Type("DataCompositionValueCollectionTemplateGenerator"));
	
	Query.Text = DataCompositionTemplate.DataSets.MainDataSet.Query;
	
	For Each Parameter IN DataCompositionTemplate.ParameterValues Do
		Query.Parameters.Insert(Parameter.Name, Parameter.Value);
	EndDo;
	
	Return Query;
	
EndFunction

// Creates a batch query to receive data required for the classifier, directory and offer package exporting.
//
Procedure AddQueriesToBatch(QueryText, Parameters)
	
	QueryText = QueryText + Chars.LF + ";" + Chars.LF
	  + "SELECT
		|	StructuralUnits.Ref AS Warehouse,
		|	StructuralUnits.Description,
		|	StructuralUnits.ContactInformation.(
		|		Ref,
		|		LineNumber,
		|		Type,
		|		Kind,
		|		Presentation,
		|		FieldsValues,
		|		Country,
		|		Region,
		|		City,
		|		EMail_Address,
		|		ServerDomainName,
		|		PhoneNumber,
		|		PhoneNumberNoCodes
		|	)
		|FROM
		|	Catalog.StructuralUnits AS StructuralUnits
		|WHERE
		|	(StructuralUnits.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
		|			OR StructuralUnits.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
		|			OR StructuralUnits.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.RetailAccrualAccounting))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	InventoryBalances.StructuralUnit AS Warehouse,
		|	InventoryBalances.ProductsAndServices,
		|	InventoryBalances.Characteristic,
		|	InventoryBalances.QuantityBalance AS QuantityInStock
		|FROM
		|	AccumulationRegister.Inventory.Balance(
		|			,
		|			CustomerOrder = VALUE(Document.CustomerOrder.EmptyRef)
		|				AND (ProductsAndServices, Characteristic) In
		|					(SELECT
		|						TemporaryTableProductsAndServicesCharacteristicsBalance.ProductsAndServices,
		|						TemporaryTableProductsAndServicesCharacteristicsBalance.Characteristic
		|					FROM
		|						TemporaryTableProductsAndServicesCharacteristicsBalance AS TemporaryTableProductsAndServicesCharacteristicsBalance)) AS InventoryBalances
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBarcodesForPrices
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TemporaryTablePriceKinds.PriceKind AS PriceKind,
		|	TemporaryTablePriceKinds.PriceCurrency AS PriceCurrency,
		|	TemporaryTablePriceKinds.PriceIncludesVAT AS PriceIncludesVAT
		|FROM
		|	TemporaryTablePriceKinds AS TemporaryTablePriceKinds
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TemporaryTablePrices.Characteristic AS Characteristic,
		|	ProductsAndServicesCharacteristicsAdditionalAttributes.Property AS Property,
		|	ProductsAndServicesCharacteristicsAdditionalAttributes.Value AS Value
		|FROM
		|	TemporaryTablePrices AS TemporaryTablePrices
		|		INNER JOIN Catalog.ProductsAndServicesCharacteristics.AdditionalAttributes AS ProductsAndServicesCharacteristicsAdditionalAttributes
		|		ON TemporaryTablePrices.Characteristic = ProductsAndServicesCharacteristicsAdditionalAttributes.Ref
		|TOTALS BY
		|	Characteristic
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTablePrices
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TemporaryTableProductsAndServicesCharacteristicsBalance.ProductsAndServices AS ProductsAndServices,
		|	TemporaryTableProductsAndServicesCharacteristicsBalance.DeletionMark AS DeletionMark,
		|	TemporaryTableProductsAndServicesCharacteristicsBalance.Parent AS Parent,
		|	TemporaryTableProductsAndServicesCharacteristicsBalance.Code AS Code,
		|	TemporaryTableProductsAndServicesCharacteristicsBalance.Description AS Description,
		|	TemporaryTableProductsAndServicesCharacteristicsBalance.SKU AS SKU,
		|	TemporaryTableProductsAndServicesCharacteristicsBalance.ProductsAndServicesKind AS ProductsAndServicesKind,
		|	TemporaryTableProductsAndServicesCharacteristicsBalance.ProductsAndServicesType AS ProductsAndServicesType,
		|	TemporaryTableProductsAndServicesCharacteristicsBalance.MeasurementUnit AS MeasurementUnit,
		|	TemporaryTableProductsAndServicesCharacteristicsBalance.MeasurementUnit.Code AS MeasurementUnitCode,
		|	TemporaryTableProductsAndServicesCharacteristicsBalance.MeasurementUnit.DescriptionFull AS MeasurementUnitDescriptionFull,
		|	TemporaryTableProductsAndServicesCharacteristicsBalance.MeasurementUnit.InternationalAbbreviation AS MeasurementUnitInternationalAbbreviation,
		|	TemporaryTableProductsAndServicesCharacteristicsBalance.VATRate AS VATRate,
		|	TemporaryTableProductsAndServicesCharacteristicsBalance.PictureFile AS PictureFile
		|INTO TemporaryTableProductsAndServices
		|FROM
		|	TemporaryTableProductsAndServicesCharacteristicsBalance AS TemporaryTableProductsAndServicesCharacteristicsBalance
		|
		|INDEX BY
		|	ProductsAndServices
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableProductsAndServicesCharacteristicsBalance
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	AdditionalAttributes.ProductsAndServices AS ProductsAndServices,
		|	AdditionalAttributes.Property AS Property,
		|	ValuesOfAdditionalAttributes.Value AS Value
		|INTO TemporaryTableProductsAndServicesProperties
		|FROM
		|	(SELECT
		|		TemporaryTableProductsAndServices.ProductsAndServices AS ProductsAndServices,
		|		SetsAdditionalDetailsAndAdditionalInformationAttributes.Property AS Property
		|	FROM
		|		TemporaryTableProductsAndServices AS TemporaryTableProductsAndServices
		|			INNER JOIN Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes AS SetsAdditionalDetailsAndAdditionalInformationAttributes
		|			ON (SetsAdditionalDetailsAndAdditionalInformationAttributes.Ref = VALUE(Catalog.AdditionalAttributesAndInformationSets.Catalog_ProductsAndServices))) AS AdditionalAttributes
		|		LEFT JOIN Catalog.ProductsAndServices.AdditionalAttributes AS ValuesOfAdditionalAttributes
		|		ON AdditionalAttributes.ProductsAndServices = ValuesOfAdditionalAttributes.Ref
		|			AND AdditionalAttributes.Property = ValuesOfAdditionalAttributes.Property
		|
		|UNION
		|
		|SELECT
		|	AdditionalInformation.ProductsAndServices,
		|	AdditionalInformation.Property,
		|	ValuesOfAdditionalInformation.Value
		|FROM
		|	(SELECT
		|		TemporaryTableProductsAndServices.ProductsAndServices AS ProductsAndServices,
		|		SetsAdditionalDetailsAndAdditionalInformationAdditionalInformation.Property AS Property
		|	FROM
		|		TemporaryTableProductsAndServices AS TemporaryTableProductsAndServices
		|			INNER JOIN Catalog.AdditionalAttributesAndInformationSets.AdditionalInformation AS SetsAdditionalDetailsAndAdditionalInformationAdditionalInformation
		|			ON (SetsAdditionalDetailsAndAdditionalInformationAdditionalInformation.Ref = VALUE(Catalog.AdditionalAttributesAndInformationSets.Catalog_ProductsAndServices))) AS AdditionalInformation
		|		LEFT JOIN InformationRegister.AdditionalInformation AS ValuesOfAdditionalInformation
		|		ON AdditionalInformation.ProductsAndServices = ValuesOfAdditionalInformation.Object
		|			AND AdditionalInformation.Property = ValuesOfAdditionalInformation.Property
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ProductsAndServicesPropertiesTable.Property AS Property,
		|	ProductsAndServicesPropertiesTable.Property.ValueType AS ValueType,
		|	ProductsAndServicesPropertiesTable.Value AS Value
		|FROM
		|	(SELECT DISTINCT
		|		TemporaryTableProductsAndServicesProperties.Property AS Property,
		|		TemporaryTableProductsAndServicesProperties.Value AS Value
		|	FROM
		|		TemporaryTableProductsAndServicesProperties AS TemporaryTableProductsAndServicesProperties) AS ProductsAndServicesPropertiesTable
		|TOTALS BY
		|	Property
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TemporaryTableProductsAndServicesProperties.ProductsAndServices AS ProductsAndServices,
		|	TemporaryTableProductsAndServicesProperties.Property AS Property,
		|	TemporaryTableProductsAndServicesProperties.Value AS Value
		|FROM
		|	TemporaryTableProductsAndServicesProperties AS TemporaryTableProductsAndServicesProperties
		|
		|ORDER BY
		|	ProductsAndServices
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableProductsAndServicesProperties
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	TemporaryTableProductsAndServices.ProductsAndServices AS ProductsAndServices,
		|	MAX(ProductsAndServicesBarcodes.Barcode) AS Barcode
		|INTO TemporaryTableBarcodesForDirectory
		|FROM
		|	TemporaryTableProductsAndServices AS TemporaryTableProductsAndServices
		|		INNER JOIN InformationRegister.ProductsAndServicesBarcodes AS ProductsAndServicesBarcodes
		|		ON TemporaryTableProductsAndServices.ProductsAndServices = ProductsAndServicesBarcodes.ProductsAndServices
		|			AND (ProductsAndServicesBarcodes.Characteristic = VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef))
		|
		|GROUP BY
		|	TemporaryTableProductsAndServices.ProductsAndServices
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	Companies.Ref AS Counterparty,
		|	Companies.Description AS Description,
		|	Companies.DescriptionFull AS DescriptionFull,
		|	Companies.LegalEntityIndividual AS LegalEntityIndividual,
		|	Companies.TIN AS TIN,
		|	Companies.KPP AS KPP,
		|	Companies.CodeByOKPO AS CodeByOKPO,
		|	Companies.ContactInformation.(
		|		Type AS Type,
		|		Kind AS Kind,
		|		Presentation AS Presentation,
		|		FieldsValues AS FieldsValues
		|	) AS ContactInformation
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.Ref = &CompanyFolderOwner
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TemporaryTableProductsAndServices.ProductsAndServices AS ProductsAndServices,
		|	TemporaryTableProductsAndServices.DeletionMark AS DeletionMark,
		|	TemporaryTableProductsAndServices.Parent AS Parent,
		|	TemporaryTableProductsAndServices.Code AS Code,
		|	TemporaryTableProductsAndServices.Description AS Description,
		|	TemporaryTableProductsAndServices.ProductsAndServices.DescriptionFull AS DescriptionFull,
		|	TemporaryTableProductsAndServices.ProductsAndServices.Comment AS Comment,
		|	TemporaryTableProductsAndServices.SKU AS SKU,
		|	TemporaryTableProductsAndServices.ProductsAndServicesKind AS ProductsAndServicesKind,
		|	TemporaryTableProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
		|	TemporaryTableProductsAndServices.MeasurementUnit AS MeasurementUnit,
		|	TemporaryTableProductsAndServices.MeasurementUnitCode AS MeasurementUnitCode,
		|	TemporaryTableProductsAndServices.MeasurementUnitDescriptionFull AS MeasurementUnitDescriptionFull,
		|	TemporaryTableProductsAndServices.MeasurementUnitInternationalAbbreviation AS MeasurementUnitInternationalAbbreviation,
		|	TemporaryTableProductsAndServices.VATRate AS VATRate,
		|	TemporaryTableProductsAndServices.PictureFile AS PictureFile,
		|	ISNULL(TemporaryTableBarcodesForDirectory.Barcode, """") AS Barcode
		|FROM
		|	TemporaryTableProductsAndServices AS TemporaryTableProductsAndServices
		|		LEFT JOIN TemporaryTableBarcodesForDirectory AS TemporaryTableBarcodesForDirectory
		|		ON TemporaryTableProductsAndServices.ProductsAndServices = TemporaryTableBarcodesForDirectory.ProductsAndServices
		|
		|ORDER BY
		|	ProductsAndServices
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBarcodesForDirectory
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TemporaryTableProductsAndServices.ProductsAndServices AS ProductsAndServices
		|FROM
		|	TemporaryTableProductsAndServices AS TemporaryTableProductsAndServices
		|TOTALS BY
		|	ProductsAndServices ONLY HIERARCHY";
		
	If Parameters.ExportPictures Then
		
		QueryText = QueryText + Chars.LF + ";" + Chars.LF
			+ "SELECT ALLOWED
			|	TemporaryTableProductsAndServices.ProductsAndServices AS ProductsAndServices,
			|	ProductsAndServicesAttachedFiles.Ref AS File,
			|	ProductsAndServicesAttachedFiles.Description AS Description,
			|	ProductsAndServicesAttachedFiles.Definition AS Definition,
			|	ProductsAndServicesAttachedFiles.Volume AS Volume,
			|	ProductsAndServicesAttachedFiles.FileStorageType AS FileStorageType,
			|	ProductsAndServicesAttachedFiles.Extension AS Extension,
			|	ProductsAndServicesAttachedFiles.PathToFile AS PathToFile,
			|	AttachedFiles.StoredFile AS StoredFile
			|FROM
			|	TemporaryTableProductsAndServices AS TemporaryTableProductsAndServices
			|		INNER JOIN Catalog.ProductsAndServicesAttachedFiles AS ProductsAndServicesAttachedFiles
			|			LEFT JOIN InformationRegister.AttachedFiles AS AttachedFiles
			|			ON ProductsAndServicesAttachedFiles.Ref = AttachedFiles.AttachedFile
			|				AND (ProductsAndServicesAttachedFiles.FileStorageType = VALUE(Enum.FileStorageTypes.InInfobase))
			|		ON (ProductsAndServicesAttachedFiles.FileOwner = TemporaryTableProductsAndServices.ProductsAndServices)
			|			AND ((NOT ProductsAndServicesAttachedFiles.DeletionMark))
			|WHERE
			|	ProductsAndServicesAttachedFiles.Extension IN(&PermittedPictureTypes)
			|
			|ORDER BY
			|	ProductsAndServices";
			
	EndIf;
	
	QueryText = QueryText + Chars.LF + ";" + Chars.LF
		+ "DELETE TemporaryTableProductsAndServices";
	
EndProcedure

Function GetComposerOfGoodsExportSettings(ExportSettingsStorage)
	
	ProductsExportScheme = ExchangePlans.ExchangeSmallBusinessSite.GetTemplate("ProductsExportScheme");
	
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(ProductsExportScheme)); 
	
	ComposerSettingsFromExchangeSetting = ExportSettingsStorage.Get();
	If ValueIsFilled(ComposerSettingsFromExchangeSetting) Then
		SettingsComposer.LoadSettings(ComposerSettingsFromExchangeSetting);
		SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	Else
		SettingsComposer.LoadSettings(ProductsExportScheme.DefaultSettings);
	EndIf;
	
	Return SettingsComposer;
	
EndFunction

Procedure ChangeComposerFilter(SettingsComposer, ListOfDirectoryGroups = Undefined, ChangesArrayProductsAndServices = Undefined) Export
	
	Filter = SettingsComposer.Settings.Filter;
	
	FilterByDirectory   = "ProgramFilterByDirectory";
	FilterByChanges = "ProgramFilterByChanges";
	
	// Delete software filters if they were set.
	
	ArrayDelete = New Array;
	For Each FilterItem IN Filter.Items Do
		
		If FilterItem.UserSettingID = FilterByDirectory
			OR FilterItem.UserSettingID = FilterByChanges Then
			
			ArrayDelete.Add(FilterItem);
		EndIf;
		
	EndDo;
	
	For Each DeleteItem IN ArrayDelete Do
		
		Filter.Items.Delete(DeleteItem);
		
	EndDo;
	
	// Add filter by directory.
	
	If ListOfDirectoryGroups <> Undefined AND ListOfDirectoryGroups.Count() > 0 Then
		
		NewItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
		NewItem.UserSettingID = FilterByDirectory;
		NewItem.LeftValue =  New DataCompositionField("ProductsAndServices");
		NewItem.ComparisonType = DataCompositionComparisonType.InListByHierarchy;
		NewItem.RightValue = ListOfDirectoryGroups;
		NewItem.Use = True;
		
	EndIf;
	
	// Add filter by changes.
	
	If ChangesArrayProductsAndServices <> Undefined Then
		
		ListOfFilterGroups = New ValueList;
		ListOfFilterGroups.LoadValues(ChangesArrayProductsAndServices);
		
		NewItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
		NewItem.UserSettingID = FilterByChanges;
		NewItem.LeftValue 	=  New DataCompositionField("ProductsAndServices");
		NewItem.ComparisonType 	= DataCompositionComparisonType.InListByHierarchy;
		NewItem.RightValue = ListOfFilterGroups;
		NewItem.Use 	= True;
		
	EndIf;
	
EndProcedure

// Exports the classifier and product catalog to the directory on the disk.
//
Function ExportClassifierAndDirectory(Parameters, DirectoryFileName, CMLPackage)
	
	ResultStructure = Parameters.DirectoriesTableRow.ResultStructure;
	
	BusinessInformationType = CMLPackage.Get("BusinessInformation");
	BusinessInformationXTDO = XDTOFactory.Create(BusinessInformationType);
	
	BusinessInformationXTDO.SchemaVersion = "2.05";
	BusinessInformationXTDO.GeneratingDate = Parameters.GeneratingDate;
	
	ClassifierType = CMLPackage.Get("Classifier");
	ClassifierXDTO = XDTOFactory.Create(ClassifierType);
	
	ClassifierXDTO.ID = Parameters.DirectoriesTableRow.DirectoryId;
	ClassifierXDTO.Description = DescriptionFormatForXDTO("Classifier (" + Parameters.DirectoriesTableRow.Directory + ")");
	
	ClassifierXDTO.Owner = GetXDTOCounterparty(Parameters.CompanyDataOfDirectoryOwner, CMLPackage);
	
	AddXDTOClassifierGroups(ClassifierXDTO, Parameters.GroupsTree.Rows, Parameters.DirectoriesTableRow.Groups, CMLPackage);
	
	AddProductsAndServicesPropertiesIntoXDTOClassifier(ClassifierXDTO, CMLPackage, Parameters.ProductsAndServicesPropertiesSelectionForClassificator);
	
	BusinessInformationXTDO.Classifier = ClassifierXDTO;
	
	DirectoryType = CMLPackage.Get("Directory");
	XDTODirectory = XDTOFactory.Create(DirectoryType);
	
	XDTODirectory.ContainsChangesOnly = Parameters.ExportChangesOnly AND Not Parameters.PerformFullExportingCompulsorily;
	XDTODirectory.ID = Parameters.DirectoriesTableRow.DirectoryId;
	XDTODirectory.ClassifierIdentifier = Parameters.DirectoriesTableRow.DirectoryId;
	XDTODirectory.Description = DescriptionFormatForXDTO(Parameters.DirectoriesTableRow.Directory);
	
	XDTODirectory.Owner = GetXDTOCounterparty(Parameters.CompanyDataOfDirectoryOwner, CMLPackage);
	
	AddProductsAndServicesInXDTODirectory(XDTODirectory, CMLPackage, Parameters);
	XDTODirectory.Validate();
	
	BusinessInformationXTDO.Directory = XDTODirectory;
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(DirectoryFileName, "UTF-8");
	XMLWriter.WriteXMLDeclaration();
	
	Try
		
		BusinessInformationXTDO.Validate();
		
		XDTOFactory.WriteXML(XMLWriter, BusinessInformationXTDO, "BusinessInformation");
		XMLWriter.Close();
		
	Except
		
		AddErrorDescriptionFull(ResultStructure.ErrorDescription,
			ExceptionalErrorDescription(NStr("en = 'Failed to record goods classifier XML-file on disc: '")
				+ DirectoryFileName + Chars.LF + ErrorDescription()));
			
		ResultStructure.ExportedPictures = 0;
		ResultStructure.ProductsExported = 0;
		
		Return False;
		
	EndTry;
	
	Return True;
	
EndFunction

Procedure AddXDTOClassifierGroups(ClassifierXDTO, GroupsTree, GroupList, CMLPackage) Export
	
	ClassifierGroupsType = GetPropertyTypeFromXDTOObjectType(CMLPackage.Get("Classifier"), "Groups");
	XDTOClassifierGroups = XDTOFactory.Create(ClassifierGroupsType);
	
	FillXDTOClassifierGroups(XDTOClassifierGroups, GroupsTree, GroupList, CMLPackage);
	
	If XDTOClassifierGroups.Group.Count() > 0 Then
		ClassifierXDTO.Groups = XDTOClassifierGroups;
	EndIf;
	
EndProcedure

Procedure FillXDTOClassifierGroups(XDTOClassifierGroups, GroupsTree, GroupList, CMLPackage, CurrentParent = Undefined)
	
	For Each TreeRow IN GroupsTree Do
		
		If Not TreeRow.ProductsAndServices.IsFolder Then
			Continue;
		EndIf;
		
		If TreeRow.ProductsAndServices = CurrentParent Then
			Continue;
		EndIf;
		
		If ThisIsUpperLevelGroup(TreeRow.ProductsAndServices, GroupList) Then
			
			If TreeRow.Rows.Count() > 0 Then
				FillXDTOClassifierGroups(XDTOClassifierGroups, TreeRow.Rows, GroupList, CMLPackage, TreeRow.ProductsAndServices);
			EndIf;
			
		Else
			
			XDTOGroup = XDTOFactory.Create(CMLPackage.Get("Group"));
			
			GroupIdentifier = ExchangeWithSiteReUse.GenerateObjectUUID(TreeRow.ProductsAndServices);
			GroupName = TreeRow.ProductsAndServices.Description;
			
			XDTOGroup.ID = GroupIdentifier;
			XDTOGroup.Description = DescriptionFormatForXDTO(GroupName);
			
			XDTOGroups = GetXDTOProductsAndServicesGroups(TreeRow.Rows, GroupList, CMLPackage, TreeRow.ProductsAndServices);
			If XDTOGroups.Group.Count() > 0 Then
				XDTOGroup.Groups = XDTOGroups;
			EndIf;
			
			XDTOClassifierGroups.Group.Add(XDTOGroup);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Recursively generates XDTO Object containing ProductsAndServices group hierarchy.
//
// Parameters:
//	GroupsTree - GroupList
//	value tree - value list, groups of
//	the CurrentParent exported directory - CatalogRef.ProductsAndServices.
//
//Returns:
//	XDTODataObject - an object containing the group hierarchy.
//
Function GetXDTOProductsAndServicesGroups(GroupsTree, GroupList, CMLPackage, CurrentParent = Undefined)
	
	GroupsType = GetPropertyTypeFromXDTOObjectType(CMLPackage.Get("Group"), "Groups");
	XDTOGroups = XDTOFactory.Create(GroupsType);
	
	For Each TreeRow IN GroupsTree Do
		
		If Not TreeRow.ProductsAndServices.IsFolder Then
			Continue;
		EndIf;
		
		If TreeRow.ProductsAndServices = CurrentParent Then
			Continue;
		EndIf;
		
		XDTOGroup = XDTOFactory.Create(CMLPackage.Get("Group"));
		
		GroupIdentifier = ExchangeWithSiteReUse.GenerateObjectUUID(TreeRow.ProductsAndServices);
		GroupName = TreeRow.ProductsAndServices.Description;
		
		XDTOGroup.ID = GroupIdentifier;
		XDTOGroup.Description = DescriptionFormatForXDTO(GroupName);
		
		If TreeRow.Rows.Count() > 0 Then
			
			GroupsXDTOObject = GetXDTOProductsAndServicesGroups(TreeRow.Rows, GroupList, CMLPackage, TreeRow.ProductsAndServices);
			
			If GroupsXDTOObject.Group.Count() > 0 Then
				XDTOGroup.Groups = GroupsXDTOObject;
			EndIf;
			
		EndIf;
		
		XDTOGroups.Group.Add(XDTOGroup);
		
	EndDo;
	
	Return XDTOGroups;
	
EndFunction

// Adds ProductAndServices attributes to the list of Classifier type XDTO object attributes.
//
// Parameters
// ClassifierXDTO - XDTO object of
// the Classifier type CMLPackage - XDTO
// package ProductsAndServicesPropertiesFilter - sample containing ProductAndServices attributes.
//
Procedure AddProductsAndServicesPropertiesIntoXDTOClassifier(ClassifierXDTO, CMLPackage, ProductsAndServicesPropertiesSelection) Export
	
	If ProductsAndServicesPropertiesSelection.Count() = 0 Then
		Return;
	EndIf;
	
	PropertiesType = ClassifierXDTO.Properties().Get("Properties").Type;
	XDTOProperties = XDTOFactory.Create(PropertiesType);
	
	While ProductsAndServicesPropertiesSelection.Next() Do
		
		XDTOProperty = XDTOFactory.Create(CMLPackage.Get("Property"));
		
		XDTOProperty.ID = String(ProductsAndServicesPropertiesSelection.Property.UUID());
		XDTOProperty.Description = DescriptionFormatForXDTO(ProductsAndServicesPropertiesSelection.Property);
		
		Types = ProductsAndServicesPropertiesSelection.ValueType.Types();
		
		XMLType = "String";
		
		If Types.Count() <> 1 Then
			
			// Per CML 2 standard.05 you can export only one value type.
			// Export String type as the generic type.
			
			XDTOProperty.ValuesType = XMLType;
			
		Else
			
			Type = Types[0];
			
			If Type = Type("Number") Then
				XMLType = "Number";
			ElsIf Type = Type("Date") Then
				XMLType = "Time";
			ElsIf ValueTypeCatalog(Type) Then
				XMLType = "Catalog";
			EndIf;
			
			XDTOProperty.ValuesType = XMLType;
			
			If XMLType = "Catalog" Then
				
				VariantsOfTypePropertyValues = CMLPackage.Get("VariantsValuesProperties");
				CatalogType = VariantsOfTypePropertyValues.Properties.Get("Catalog").Type;
				
				VariantsValuesXDTO = XDTOFactory.Create(VariantsOfTypePropertyValues);
				
				ValueVariants = GetPropertyValueVariantsByType(ProductsAndServicesPropertiesSelection, Type);
				For Each ValueVariant IN ValueVariants Do
					
					Value = Left(ValueVariant, 1000);
					If IsBlankString(Value) Then
						Continue;
					EndIf;
					
					XDTOCatalog = XDTOFactory.Create(CatalogType);
					
					XDTOCatalog.ValueIdentifier = String(ValueVariant.UUID());
					XDTOCatalog.Value = Value;
					
					VariantsValuesXDTO.Catalog.Add(XDTOCatalog);
					
				EndDo;
				
				XDTOProperty.ValueVariants = VariantsValuesXDTO;
				
			EndIf;
			
		EndIf;
		
		XDTOProperties.Property.Add(XDTOProperty);
		
	EndDo;
	
	ClassifierXDTO.Properties = XDTOProperties;
	
EndProcedure

// Fills in the product list of Directory type XDTO object
//
// Parameters
// XDTODirectory - XDTO object of
// Directory type CMLPackage - XDTO
// package Parameters - structure containing exchange parameters.
//
Procedure AddProductsAndServicesInXDTODirectory(XDTODirectory, CMLPackage, Parameters) Export
	
	ProductsType = XDTODirectory.Properties().Get("Products").Type;
	XDTOProducts = XDTOFactory.Create(ProductsType);
	
	While Parameters.ProductsAndServicesSelection.Next() Do
		
		AdditionalInformation = GetAdditionalInformationForExportingToDirectory(Parameters);
		AddXDTOProductsAndServices(XDTOProducts, CMLPackage, AdditionalInformation, Parameters);
		
	EndDo;
	
	If XDTOProducts.Product.Count() > 0 Then
		
		XDTODirectory.Products = XDTOProducts;
		
	EndIf;
	
EndProcedure

// Creates BaseUnit XDTO object and fills in the data
//
Function GetXDTOBaseUnit(CMLPackage, UnitData)
	
	BaseUnitXDTO = XDTOFactory.Create(CMLPackage.Get("BaseUnit"));
	
	If Not IsBlankString(UnitData.MeasurementUnitCode) Then
		BaseUnitXDTO.Code = Left(UnitData.MeasurementUnitCode, 3);
	EndIf;
	
	If Not IsBlankString(UnitData.MeasurementUnitDescriptionFull) Then
		BaseUnitXDTO.DescriptionFull = UnitData.MeasurementUnitDescriptionFull;
	Else
		BaseUnitXDTO.DescriptionFull = UnitData.MeasurementUnit.Description;
	EndIf;
	
	If Not IsBlankString(UnitData.MeasurementUnitInternationalAbbreviation) Then
		BaseUnitXDTO.InternationalAbbreviation = UnitData.MeasurementUnitInternationalAbbreviation;
	EndIf;
	
	Return BaseUnitXDTO;
	
EndFunction

// Adds XDTO object of the Product type to the product list of the Directory type XDTO object
//
// Parameters
// XDTOProducts - XDTO object type
// Products CMLPackage - XDTO
// package AdditionalInformation - structure containing information of the ProductsAndServices images
// and Parameters attribute values - structure containing exchange parameters.
//
Procedure AddXDTOProductsAndServices(XDTOProducts, CMLPackage, AdditionalInformation, Parameters)
	
	ProductType = CMLPackage.Get("Product");
	XDTOProduct = XDTOFactory.Create(ProductType);
	
	If Parameters.ProductsAndServicesSelection.DeletionMark Then
		
		XDTOProduct.Status = "Removed";
		
	EndIf;
	
	ID = ExchangeWithSiteReUse.GenerateObjectUUID(Parameters.ProductsAndServicesSelection.ProductsAndServices);
	XDTOProduct.ID = ID;
	
	Barcode = GetBarcodeForXDTO(Parameters.ProductsAndServicesSelection.Barcode);
	If ValueIsFilled(Barcode) Then
		
		XDTOProduct.Barcode = Barcode;
		
	EndIf;
	
	XDTOProduct.SKU = Parameters.ProductsAndServicesSelection.SKU;
	XDTOProduct.Description = DescriptionFormatForXDTO(Parameters.ProductsAndServicesSelection.Description);
	XDTOProduct.BaseUnit = GetXDTOBaseUnit(CMLPackage, Parameters.ProductsAndServicesSelection);
	
	GroupIdentifier = "";
	If ValueIsFilled(Parameters.ProductsAndServicesSelection.Parent) Then
		
		GroupIdentifier = ExchangeWithSiteReUse.GenerateObjectUUID(Parameters.ProductsAndServicesSelection.Parent);
		
	EndIf;
	
	If Not IsBlankString(GroupIdentifier) Then
		
		GroupsType = GetPropertyTypeFromXDTOObjectType(ProductType, "Groups");
		XDTOGroups = XDTOFactory.Create(GroupsType);
		
		XDTOGroups.ID.Add(GroupIdentifier);
		
		XDTOProduct.Groups = XDTOGroups;
		
	EndIf;
	
	XDTOProduct.Definition = Parameters.ProductsAndServicesSelection.Comment;
	
	FileDescriptionFulls = New Map;
	AddXDTOProductsAndServicesPictureAddresses(XDTOProduct, AdditionalInformation.FileTable, Parameters, FileDescriptionFulls);
	
	AddValuesOfXDTOProductsAndServicesProperties(XDTOProduct, AdditionalInformation.PropertyTable, Parameters, CMLPackage);
	
	VATRate = Parameters.ProductsAndServicesSelection.VATRate;
	If ValueIsFilled(VATRate) AND Not VATRate.NotTaxable Then
		
		TaxRatesType = GetPropertyTypeFromXDTOObjectType(ProductType, "TaxesRates");
		
		XDTOTaxesRates = XDTOFactory.Create(TaxRatesType);
		XDTOTaxRate = XDTOFactory.Create(CMLPackage.Get("TaxRate"));
		
		XDTOTaxRate.Description = Parameters.DescriptionTax;
		XDTOTaxRate.Rate = ExchangeWithSiteReUse.GetValueForExportingByVATRate(VATRate);
		
		XDTOTaxesRates.TaxRate.Add(XDTOTaxRate);
		
		XDTOProduct.TaxesRates = XDTOTaxesRates;
		
	EndIf;
	
	If Parameters.ExchangeOverWebService Then
		AddProductCharacteristicsXDTO(XDTOProduct, CMLPackage, Parameters.ProductsAndServicesSelection.ProductsAndServices, Parameters.CharacteristicPropertiesTree);
	EndIf;
	
	AttributesValuesType = GetPropertyTypeFromXDTOObjectType(ProductType, "AttributeValues");
	AttributeValuesXDTO = XDTOFactory.Create(AttributesValuesType);
	
	For Each FileDescription IN FileDescriptionFulls Do
		
		File = FileDescription.Key;
		Definition = FileDescription.Value;
		
		AddXDTOAttributeValue(AttributeValuesXDTO, CMLPackage, "FileDescription", File + "#" + Definition);
		
	EndDo;
	
	AddXDTOAttributeValue(AttributeValuesXDTO, CMLPackage, "ProductsAndServicesKind", Parameters.ProductsAndServicesSelection.ProductsAndServicesKind);
	AddXDTOAttributeValue(AttributeValuesXDTO, CMLPackage, "ProductsAndServicesType", Parameters.ProductsAndServicesSelection.ProductsAndServicesType);
	AddXDTOAttributeValue(AttributeValuesXDTO, CMLPackage, "Full description", Parameters.ProductsAndServicesSelection.DescriptionFull);
	
	XDTOProduct.AttributeValues = AttributeValuesXDTO;
	XDTOProducts.Product.Add(XDTOProduct);
	
	Parameters.DirectoriesTableRow.ResultStructure.ProductsExported =
		Parameters.DirectoriesTableRow.ResultStructure.ProductsExported + 1;
	
EndProcedure

// Adds path to ProductsAndServices image files into XDTO object of the Product type.
//
// Parameters
// XDTOProduct - XDTO object of
// the Product type FileTable - value table containing paths
// to Parameters files - structure containing FileDescriptions
// exchange parameters - matching which key is the path to the file and value is the attachment description.
//
Procedure AddXDTOProductsAndServicesPictureAddresses(XDTOProduct, FileTable, Parameters, FileDescriptionFulls)
	
	If Not Parameters.ExportPictures Then
		Return;
	EndIf;
	
	ResultStructure = Parameters.DirectoriesTableRow.ResultStructure;
	
	// The main image shall be imported first.
	
	FileTable.Columns.Add("Sort");
	
	MainImage = Parameters.ProductsAndServicesSelection.PictureFile;
	
	FileTable.FillValues(1, "Sort");
	
	If ValueIsFilled(MainImage) Then
		
		Found = FileTable.Find(MainImage, "File");
		If Not Found = Undefined Then
			
			MainIndexOfImages = FileTable.IndexOf(Found);
			If MainIndexOfImages > 0 Then
				
				Found.Sort = 0;
				FileTable.Sort("Sort");
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	For Each CurFile IN FileTable Do
		
		ErrorDescription = "";
		FileURL = ExportFile(CurFile, Parameters, ErrorDescription);
		
		If Not IsBlankString(ErrorDescription) Then
			
			ResultStructure.ErrorDescription = ResultStructure.ErrorDescription
				+ Chars.LF
				+ CurrentDate() + ": " + ErrorDescription;
			
		Else
			
			If ValueIsFilled(FileURL) Then
				
				ResultStructure.ExportedPictures = ResultStructure.ExportedPictures + 1;
				
				XDTOProduct.Picture.Add(FileURL);
				
				Definition = ?(IsBlankString(CurFile.Definition), CurFile.Description, CurFile.Definition);
				If Not IsBlankString(Definition) Then
					
					FileDescriptionFulls.Insert(FileURL, Definition);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Writes a file with the ProductsAndServices image to the disk and returns the file path.
//	
// Parameters
// FileData - structure containing information
// of the image Parameters - structure containing data
// of ErrorDescription exchange - String to record error information
//	
// String
// return value containing the file path.
//
Function ExportFile(FileData, Parameters, ErrorDescription) Export
	
	FileURL = "";
	
	FileExtension = Lower(FileData.Extension);
	
	If Not Parameters.ExportPictures
		OR Parameters.PermittedPictureTypes.Find(FileExtension) = Undefined Then
		
		Return FileURL;
		
	EndIf;
	
	FileInStorage = FileData.FileStorageType = Enums.FileStorageTypes.InInfobase;
	
	If FileInStorage Then
		
		If FileData.StoredFile = NULL Then
			FileBinaryData = Undefined;
		Else
			FileBinaryData = FileData.StoredFile.Get();
		EndIf;
		
		If FileBinaryData = Undefined Then
			
			AddErrorDescriptionFull(ErrorDescription, 
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'Failed to receive file data %1 of products and services %2'"),
					FileData.File,
					Parameters.ProductsAndServicesSelection.ProductsAndServices));
					
			Return FileURL;
			
		EndIf;
		
	Else
		
		FileName = PreparePathForPlatform(Parameters.WindowsPlatform,
			GetVolumePathForPlatform(Parameters.WindowsPlatform, FileData.Volume) + "\" + FileData.PathToFile);
		
		Try
			
			FileBinaryData = New BinaryData(FileName);
			
		Except
			
			AddErrorDescriptionFull(ErrorDescription, 
				ExceptionalErrorDescription(NStr("en = 'ProductsAndServices file export: '")
					+ Parameters.ProductsAndServicesSelection.ProductsAndServices));
					
			Return FileURL;
			
		EndTry;
		
	EndIf;
	
	NameByProductsAndServices = StrReplace(Parameters.ProductsAndServicesSelection.ProductsAndServices.UUID(), "-", "");
	NameByStorage    = StrReplace(FileData.File.UUID(), "-", "");
	
	FilesSubDir = Parameters.FilesSubDir;
	
	FileName = NameByProductsAndServices + "_" + NameByStorage + "." + Lower(FileExtension);
	DirectoryByName = Left(NameByProductsAndServices, 2);
	FileDir = PreparePathForPlatform(Parameters.WindowsPlatform,
		Parameters.DirectoryOnHardDisk + "\" + FilesSubDir + "\" + DirectoryByName);
	
	Try
		
		CreateDirectory(FileDir);
		
	Except
		
		AddErrorDescriptionFull(ErrorDescription, ExceptionalErrorDescription(
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Failed to create the directory %1. ProductsAndServices: %2'"),
				FileDir,
				Parameters.ProductsAndServicesSelection.ProductsAndServices))
		);
		
		Return FileURL;
		
	EndTry;
	
	FullFileName = PreparePathForPlatform(Parameters.WindowsPlatform, FileDir + "\" + FileName);
	
	Try
		
		FileBinaryData.Write(FullFileName);
		
	Except
		
		AddErrorDescriptionFull(ErrorDescription, ExceptionalErrorDescription(
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Failed to record the %1 file to the disk. ProductsAndServices: %2'"),
				FullFileName,
				Parameters.ProductsAndServicesSelection.ProductsAndServices))
		);
		
		Return FileURL;
		
	EndTry;
	
	FileURL = FilesSubDir + "/" + DirectoryByName + "/" + FileName;
	
	Return FileURL;
	
EndFunction

// Adds the values of the ProductsAndServices attributes to the list of the Product type XDTO object attribute values.
//
// Parameters
// XDTOProduct - XDTO object of
// the Product type PropertyTable - value table containing ProductsAndServices
// attribute values Parameters - structure containing exchange
// parameters CMLPackage - XDTO package.
//
Procedure AddValuesOfXDTOProductsAndServicesProperties(XDTOProduct, PropertyTable, Parameters, CMLPackage)
	
	If PropertyTable.Count() = 0 Then
		Return;
	EndIf;
	
	PropertyValuesType = XDTOProduct.Properties().Get("PropertyValues").Type;
	XDTOPropertiesValues = XDTOFactory.Create(PropertyValuesType);
	
	For Each PropertiesTableRow IN PropertyTable Do
		
		XDTOPropertyValues = XDTOFactory.Create(CMLPackage.Get("PropertyValues"));
		
		XDTOPropertyValues.ID = String(PropertiesTableRow.Property.UUID());
		
		If PropertiesTableRow.Value = NULL Then
			
			// If the attribute value is not filled, we export the empty string.
			PropertyValue = "";
			
		Else
			
			PropertyValueType = TypeOf(PropertiesTableRow.Value);
			If PropertyValueType = Type("Date") Then
				
				PropertyValue = DateFormatForXDTO(PropertiesTableRow.Value);
				
			ElsIf ValueTypeCatalog(PropertyValueType) Then
				
				PropertyValue = String(PropertiesTableRow.Value.UUID());
				
			Else
				
				PropertyValue = String(PropertiesTableRow.Value);
				
			EndIf;
			
		EndIf;
		
		XDTOPropertyValues.Value.Add(PropertyValue);
		XDTOPropertiesValues.PropertyValues.Add(XDTOPropertyValues);
		
	EndDo;
	
	XDTOProduct.PropertyValues = XDTOPropertiesValues;
	
EndProcedure

// Returns a structure containing data of images and attributes.
//
// Parameters
// Parameters - Structure - structure containing the file sample and attribute sample
//
// Return
// value Structure.
//
Function GetAdditionalInformationForExportingToDirectory(Parameters);
	
	AdditionalInformation = New Structure;
	ProductsAndServices = Parameters.ProductsAndServicesSelection.ProductsAndServices;
	
	// Images.
	
	FileTable = New ValueTable;
	FileTable.Columns.Add("File");
	FileTable.Columns.Add("Description");
	FileTable.Columns.Add("Definition");
	FileTable.Columns.Add("Volume");
	FileTable.Columns.Add("StoredFile");
	FileTable.Columns.Add("FileStorageType");
	FileTable.Columns.Add("Extension");
	FileTable.Columns.Add("PathToFile");
	
	While (NOT Parameters.SelectionFiles = Undefined)
		AND Parameters.SelectionFiles.ProductsAndServices = ProductsAndServices Do
			
			NewRow = FileTable.Add();
			FillPropertyValues(NewRow, Parameters.SelectionFiles);
			
		If Not Parameters.SelectionFiles.Next() Then
			
			// If the sample is over,
			// we end the cycle forcefully in order to avoid looping at the last sample record.
			
			Parameters.SelectionFiles = Undefined;
			
		EndIf;
		
	EndDo;
	
	AdditionalInformation.Insert("FileTable", FileTable);
	
	// Attributes.
	
	PropertyTable = New ValueTable;
	PropertyTable.Columns.Add("Property");
	PropertyTable.Columns.Add("Value");
	
	While (NOT Parameters.ProductsAndServicesPropertiesSelection = Undefined)
		AND Parameters.ProductsAndServicesPropertiesSelection.ProductsAndServices = ProductsAndServices Do
			
			NewRow = PropertyTable.Add();
			FillPropertyValues(NewRow, Parameters.ProductsAndServicesPropertiesSelection);
			
		If Not Parameters.ProductsAndServicesPropertiesSelection.Next() Then
			
			Parameters.ProductsAndServicesPropertiesSelection = Undefined;
			
		EndIf;
		
	EndDo;
	
	AdditionalInformation.Insert("PropertyTable", PropertyTable);
	
	Return AdditionalInformation;
	
EndFunction

// Exports the offer package to the directory on the disk.
//	
// Parameters
// Parameters - structure containing
// exchange data PriceFileName - String containing the path to
// the CMLPackage offer package file - XDTO package.
//	
// Return
// value is True if the XDTO object creation and record to the disk is successfully completed.
//
Function ExportPackageOfOffers(Parameters, PriceFileName, CMLPackage)
	
	ResultStructure = Parameters.DirectoriesTableRow.ResultStructure;
	
	BusinessInformationType = CMLPackage.Get("BusinessInformation");
	BusinessInformationXTDO = XDTOFactory.Create(BusinessInformationType);
	
	BusinessInformationXTDO.SchemaVersion = "2.05";
	BusinessInformationXTDO.GeneratingDate = Parameters.GeneratingDate;
	
	XDTOOffersPackage = XDTOFactory.Create(CMLPackage.Get("OffersPackage"));
	
	XDTOOffersPackage.ContainsChangesOnly = Parameters.ExportChangesOnly AND Not Parameters.PerformFullExportingCompulsorily;
	XDTOOffersPackage.ID = Parameters.DirectoriesTableRow.DirectoryId + "#";
	XDTOOffersPackage.Description = "Offer package (" + Parameters.DirectoriesTableRow.Directory + ")";
	XDTOOffersPackage.DirectoryId = Parameters.DirectoriesTableRow.DirectoryId;
	XDTOOffersPackage.ClassifierIdentifier = Parameters.DirectoriesTableRow.DirectoryId;
	
	XDTOOffersPackage.Owner = GetXDTOCounterparty(Parameters.CompanyDataOfDirectoryOwner, CMLPackage);
	
	AddPriceKindsIntoXDTOOffersPackage(XDTOOffersPackage, CMLPackage, Parameters);
	
	If Parameters.ExportBalanceForWarehouses Then
		AddWarehousesToXDTOOffersPackage(XDTOOffersPackage, CMLPackage, Parameters);
	EndIf;
	
	AddOffersIntoXDTOOffersPackage(XDTOOffersPackage, CMLPackage, Parameters);
	
	BusinessInformationXTDO.OffersPackage = XDTOOffersPackage;
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(PriceFileName, "UTF-8");
	XMLWriter.WriteXMLDeclaration();
	
	Try
		
		BusinessInformationXTDO.Validate();
		
		XDTOFactory.WriteXML(XMLWriter, BusinessInformationXTDO, "BusinessInformation");
		XMLWriter.Close();
		
	Except
		
		AddErrorDescriptionFull(ResultStructure.ErrorDescription,
			ExceptionalErrorDescription(NStr("en = 'Failed to record XML-file offers package on disc: '")
				+ PriceFileName + Chars.LF + ErrorDescription()));
			
		ResultStructure.ExportedOffers = 0;
		
		Return False;
		
	EndTry;
	
	Return True;
	
EndFunction

// Adds price kinds to XDTO object of OffersPackage type.
//
// Parameters
// XDTOOffersPackage - XDTO object of
// the OffersPackage type CMLPackage - XDTO
// package Parameters - structure containing exchange parameters.
//
Procedure AddPriceKindsIntoXDTOOffersPackage(XDTOOffersPackage, CMLPackage, Parameters) Export
	
	If Parameters.PriceKindsSelection.Count() = 0 Then
		Return;
	EndIf;
	
	PriceTypesType = GetPropertyTypeFromXDTOObjectType(CMLPackage.Get("OffersPackage"), "PriceTypes");
	XDTOPriceTypes = XDTOFactory.Create(PriceTypesType);
	
	While Parameters.PriceKindsSelection.Next() Do
		
		XDTOPriceType = XDTOFactory.Create(CMLPackage.Get("PriceType"));
		
		PriceTypeIdentifier = ExchangeWithSiteReUse.GenerateObjectUUID(Parameters.PriceKindsSelection.PriceKind);
		
		XDTOPriceType.ID = PriceTypeIdentifier;
		XDTOPriceType.Description = DescriptionFormatForXDTO(Parameters.PriceKindsSelection.PriceKind);
		XDTOPriceType.Currency = CurrencyFormatForXDTO(Parameters.PriceKindsSelection.PriceCurrency);
		
		XDTOTax = XDTOFactory.Create(CMLPackage.Get("Tax"));
		
		XDTOTax.Description = Parameters.DescriptionTax;
		XDTOTax.IncludedInAmount = Parameters.PriceKindsSelection.PriceIncludesVAT;
		
		XDTOPriceType.Tax.Add(XDTOTax);
		XDTOPriceTypes.PriceType.Add(XDTOPriceType);
		
	EndDo;
	
	XDTOOffersPackage.PriceTypes = XDTOPriceTypes;
	
EndProcedure

// Adds offers to XDTO object of OffersPackage type.
//
// Parameters
// XDTOOffersPackage - XDTO object of
// the OffersPackage type CMLPackage - XDTO
// package Parameters - structure containing exchange parameters.
//
Procedure AddOffersIntoXDTOOffersPackage(XDTOOffersPackage, CMLPackage, Parameters) Export
	
	SelectionOfPrice = Parameters.SelectionOfPrice;
	
	If SelectionOfPrice.Count() = 0 Then
		Return;
	EndIf;
	
	ResultStructure = Parameters.DirectoriesTableRow.ResultStructure;
	
	OffersType = GetPropertyTypeFromXDTOObjectType(CMLPackage.Get("OffersPackage"), "Offers");
	OfferType = GetPropertyTypeFromXDTOObjectType(OffersType, "Offer");
	
	XDTOOffers = XDTOFactory.Create(OffersType);
	
	CurProductsAndServices = Undefined;
	CurCharacteristic = Undefined;
	XDTOOffer = Undefined;
	XDTOPrices = Undefined;
	
	ThisIsFirstOffer = True;
	
	While SelectionOfPrice.Next() Do
		
		If Parameters.UseCharacteristics Then
			PriceSelectionCharacteristic = SelectionOfPrice.Characteristic;
		Else
			PriceSelectionCharacteristic = Catalogs.ProductsAndServicesCharacteristics.EmptyRef();
		EndIf;
		
		If SelectionOfPrice.ProductsAndServices = CurProductsAndServices
			AND PriceSelectionCharacteristic = CurCharacteristic Then
			
			AddXDTOPrice(XDTOPrices, CMLPackage, SelectionOfPrice, Parameters);
			
		Else
			
			If ThisIsFirstOffer Then
				
				ThisIsFirstOffer = False;
				
			Else
				
				XDTOOffer.Prices = XDTOPrices;
				XDTOOffers.Offer.Add(XDTOOffer);
				
			EndIf;
			
			XDTOOffer = XDTOFactory.Create(OfferType);
			
			PricesType = GetPropertyTypeFromXDTOObjectType(OfferType, "Prices");
			XDTOPrices = XDTOFactory.Create(PricesType);
			
			CurProductsAndServices = SelectionOfPrice.ProductsAndServices;
			CurCharacteristic = PriceSelectionCharacteristic;
			
			AddProductAttributesForXDTOOffer(XDTOOffer, CMLPackage, PriceSelectionCharacteristic, Parameters);
			
			AddXDTOPrice(XDTOPrices, CMLPackage, SelectionOfPrice, Parameters);
			
			XDTOOffer.Quantity = SelectionOfPrice.Balance;
			
			If Parameters.ExportBalanceForWarehouses Then
				WarehouseType = GetPropertyTypeFromXDTOObjectType(OfferType, "Warehouse");
				AddBalanceByXDTOWarehouses(XDTOOffer, WarehouseType, SelectionOfPrice, Parameters);
			EndIf;
			
			ResultStructure.ExportedOffers = ResultStructure.ExportedOffers + 1;
			
		EndIf;
		
	EndDo;
	
	XDTOOffer.Prices = XDTOPrices;
	XDTOOffers.Offer.Add(XDTOOffer);
	
	XDTOOffersPackage.Offers = XDTOOffers;
	
EndProcedure

Procedure AddXDTOPrice(XDTOPrices, CMLPackage, SelectionOfPrice, Parameters)
	
	XDTOPrice = XDTOFactory.Create(CMLPackage.Get("Price"));
	
	PriceTypeIdentifier = String(SelectionOfPrice.PriceKind.UUID());
	Unit = SelectionOfPrice.MeasurementUnit;
	
	PricePresentation = TrimAll(SelectionOfPrice.Price) + " " + TrimAll(SelectionOfPrice.PriceCurrency) + " for " + TrimAll(Unit);
	
	XDTOPrice.Presentation = PricePresentation;
	XDTOPrice.PriceTypeIdentifier = PriceTypeIdentifier;
	XDTOPrice.PriceForUnit = SelectionOfPrice.Price;
	XDTOPrice.Currency = CurrencyFormatForXDTO(SelectionOfPrice.PriceCurrency);
	XDTOPrice.Unit = String(Unit);
	XDTOPrice.Factor = 1;
	
	XDTOPrices.Price.Add(XDTOPrice);
	
EndProcedure


// Fills in the product attributes for XDTO object of the Offer type.
//
// Parameters
// XDTOOffer - XDTO object
// of the Offer type CMLPackage - XDTO
// package Characteristic - ProductsAndServices
// characteristic Parameters - exchange parameters.
//
Procedure AddProductAttributesForXDTOOffer(XDTOOffer, CMLPackage, Characteristic, Parameters)
	
	If Parameters.ExchangeOverWebService Then
		XDTOOffer.ID = ExchangeWithSiteReUse.GenerateObjectUUID(Parameters.SelectionOfPrice.ProductsAndServices);
	Else
		XDTOOffer.ID = ExchangeWithSiteReUse.GenerateObjectUUID(Parameters.SelectionOfPrice.ProductsAndServices, Characteristic);
	EndIf;
	
	Barcode = GetBarcodeForXDTO(Parameters.SelectionOfPrice.Barcode);
	If ValueIsFilled(Barcode) Then
		XDTOOffer.Barcode = Barcode;
	EndIf;
	
	Description = Parameters.SelectionOfPrice.Description;
	
	If Not Parameters.ExchangeOverWebService Then
		If ValueIsFilled(Characteristic) Then
			Description = Description + " (" + Characteristic + ")";
		EndIf;
	EndIf;
	
	XDTOOffer.Description = DescriptionFormatForXDTO(Description);
	XDTOOffer.BaseUnit = GetXDTOBaseUnit(CMLPackage, Parameters.SelectionOfPrice);
	
	DeletionStatus = "";
	
	If Parameters.UseCharacteristics
		AND ValueIsFilled(Characteristic) Then
		
		XDTOProductCharacteristics = Undefined;
		FoundString = Parameters.CharacteristicPropertiesTree.Rows.Find(Characteristic, "Characteristic");
		
		If FoundString <> Undefined Then
			
			ProductCharacteristicsType = XDTOOffer.Properties().Get("ProductCharacteristics").Type;
			XDTOProductCharacteristics = XDTOFactory.Create(ProductCharacteristicsType);
			
			If Not Parameters.ExchangeOverWebService Then
				
				For Each PropertyString IN FoundString.Rows Do
					
					If Not ValueIsFilled(PropertyString.Property)
						OR Not ValueIsFilled(PropertyString.Value) Then
						
						Continue;
						
					EndIf;
					
					XDTOProductCharacteristic = XDTOFactory.Create(CMLPackage.Get("ProductCharacteristic"));
					
					XDTOProductCharacteristic.Description = DescriptionFormatForXDTO(PropertyString.Property);
					XDTOProductCharacteristic.Value = DescriptionFormatForXDTO(PropertyString.Value);
					
					XDTOProductCharacteristics.ProductCharacteristic.Add(XDTOProductCharacteristic);
					
				EndDo;
				
			Else
				
				XDTOProductCharacteristic = XDTOFactory.Create(CMLPackage.Get("ProductCharacteristic"));
				
				XDTOProductCharacteristic.ID = String(Characteristic.UUID());
				XDTOProductCharacteristic.Description = DescriptionFormatForXDTO(Characteristic.Description);
				
				PropertyValuesType = XDTOProductCharacteristic.Properties().Get("PropertyValues").Type;
				XDTOPropertiesValues = XDTOFactory.Create(PropertyValuesType);
				
				For Each PropertyString IN FoundString.Rows Do
					
					If Not ValueIsFilled(PropertyString.Property)
						OR Not ValueIsFilled(PropertyString.Value) Then
						
						Continue;
						
					EndIf;
					
					XDTOPropertyValues = XDTOFactory.Create(CMLPackage.Get("PropertyValues"));
					XDTOPropertyValues.ID = String(PropertyString.Property.UUID());
					XDTOPropertyValues.Description = DescriptionFormatForXDTO(PropertyString.Description);
					
					If PropertyString.Value = NULL Then
						
						// If the attribute value is not filled, we export the empty string.
						PropertyValue = "";
						
					Else
						
						PropertyValueType = TypeOf(PropertyString.Value);
						If PropertyValueType = Type("Date") Then
							
							PropertyValue = DateFormatForXDTO(PropertyString.Value);
							
						Else
							
							PropertyValue = String(PropertyString.Value);
							
						EndIf;
						
					EndIf;
					
					XDTOPropertyValues.Value.Add(PropertyValue);
					XDTOPropertiesValues.PropertyValues.Add(XDTOPropertyValues);
					
				EndDo;
				
				If XDTOPropertiesValues.PropertyValues.Count() > 0 Then
					XDTOProductCharacteristic.PropertyValues = XDTOPropertiesValues;
				EndIf;
			EndIf;
			
			XDTOProductCharacteristics.ProductCharacteristic.Add(XDTOProductCharacteristic);
			
		EndIf;
		
		If XDTOProductCharacteristics <> Undefined Then
			XDTOOffer.ProductCharacteristics = XDTOProductCharacteristics;
		EndIf;
		
		If Parameters.SelectionOfPrice.CharacteristicDeletionMark Then
			DeletionStatus = "Removed";
		EndIf;
		
	EndIf;
	
	If Parameters.SelectionOfPrice.DeletionMark Then
		DeletionStatus = "Removed";
	EndIf;
	
	If ValueIsFilled(DeletionStatus) Then
		XDTOOffer.Status = DeletionStatus;
	EndIf;
	
EndProcedure

Procedure PrepareFinalInformationAboutGoodsExport(DirectoriesTable, InformationTableRow, ExportedObjects)
	
	ResultStructure = 
		New Structure("ProductsExported,ExportedPictures,ExportedOffers,ErrorDescription", 0, 0, 0, "");
	
	InformationTableRow.Definition = 
		InformationTableRow.Definition + Chars.LF
		+ CurrentDate() + NStr("en = ' Generating files of goods export completed'");
	
	For Each Directory IN DirectoriesTable Do
		
		ResultStructure.ProductsExported =
			ResultStructure.ProductsExported + Directory.ResultStructure.ProductsExported;
		
		ResultStructure.ExportedOffers =
			ResultStructure.ExportedOffers + Directory.ResultStructure.ExportedOffers;
		
		ResultStructure.ExportedPictures =
			ResultStructure.ExportedPictures + Directory.ResultStructure.ExportedPictures;
		
	EndDo;
	
	ExportedObjects = ResultStructure.ProductsExported
		+ ResultStructure.ExportedOffers
		+ ResultStructure.ExportedPictures;
	
	InformationTableRow.Definition = 
		InformationTableRow.Definition + Chars.LF
		+ NStr("en = 'Products exported: '") + ResultStructure.ProductsExported + Chars.LF
		+ NStr("en = 'offers: '") + ResultStructure.ExportedOffers + Chars.LF
		+ NStr("en = 'images: '") + ResultStructure.ExportedPictures + Chars.LF;
	
	For Each Directory IN DirectoriesTable Do
		
		InformationTableRow.Definition = 
			InformationTableRow.Definition + Chars.LF
			+ NStr("en = 'For the directory too '") + Directory.Directory + ":" + Chars.LF 
			+ NStr("en = 'products: '") + Directory.ResultStructure.ProductsExported + Chars.LF
			+ NStr("en = 'offers: '") + Directory.ResultStructure.ExportedOffers + Chars.LF
			+ NStr("en = 'images: '") + Directory.ResultStructure.ExportedPictures + Chars.LF;
		
		If IsBlankString(Directory.ResultStructure.ErrorDescription) Then
			Continue;
		EndIf;
		
		InformationTableRow.Definition = 
			InformationTableRow.Definition + Chars.LF
			+ NStr("en = 'Errors in exporting directory process '") + Directory.Directory + ":"
			+ Directory.ResultStructure.ErrorDescription + Chars.LF;
		
	EndDo;
	
EndProcedure

Procedure CommitProductsAndServicesExportCompletion(InformationTableRow, Result)
	
	EndDate = CurrentDate();
	
	InformationTableRow.Definition = InformationTableRow.Definition + Chars.LF
		+ EndDate + " " + NStr("en = 'Products export is completed'");
		
	InformationTableRow.ExchangeProcessResult = Result;
	InformationTableRow.EndDate = EndDate;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS ENSURING ORDER CANCELLING

// Starts the order exchange process.
// 
// Parameters:
// Parameters			- Structure,
// main InfoTable parameters	- Value table, information table of the exchange state
// 
// Return
// value Boolean				- True if success. 
//
Function RunOrdersExchange(Parameters, InformationTable)
	
	SuccessfullyImported = False;
	SuccessfullyExported = False;
	
	StatisticsStructure = New Structure;
	
	StatisticsStructure.Insert("ProcessedOnImport", 0);
	StatisticsStructure.Insert("Exported" , New Array);
	StatisticsStructure.Insert("Skipped" , New Array);
	StatisticsStructure.Insert("Updated" , New Array);
	StatisticsStructure.Insert("Created"   , New Array);
	StatisticsStructure.Insert("Exported" , New Array);
	
	If Parameters.ExportToSite Then
		
		ErrorDescription = "";
		
		StartDate = CurrentDate();
		
		SuccessfullyImported = ImportOrdersFromSite(Parameters, StatisticsStructure, ErrorDescription);
		
		WriteOrdersInformationIntoInformationTable(InformationTable,
			StartDate,
			Enums.ActionsAtExchange.DataImport,
			SuccessfullyImported,
			StatisticsStructure,
			ErrorDescription
		);
		
		ErrorDescription = "";
		
		StartDate = CurrentDate();
		
		SuccessfullyExported = ExportOrdersToSite(Parameters, StatisticsStructure, ErrorDescription);
		
		WriteOrdersInformationIntoInformationTable(InformationTable,
			StartDate,
			Enums.ActionsAtExchange.DataExport,
			SuccessfullyExported,
			StatisticsStructure,
			ErrorDescription
		);
		
	Else
		
		StartDate = CurrentDate();
		
		ErrorDescription = "";
		
		SuccessfullyImported = ImportOrdersFromFile(Parameters, StatisticsStructure, ErrorDescription);
		
		WriteOrdersInformationIntoInformationTable(InformationTable,
			StartDate,
			Enums.ActionsAtExchange.DataImport,
			SuccessfullyImported,
			StatisticsStructure,
			ErrorDescription
		);
		
		StartDate = CurrentDate();
		
		ErrorDescription = "";
		
		SuccessfullyExported = ExportOrdersIntoFile(Parameters, StatisticsStructure, ErrorDescription);
		
		WriteOrdersInformationIntoInformationTable(InformationTable,
			StartDate,
			Enums.ActionsAtExchange.DataExport,
			SuccessfullyExported,
			StatisticsStructure,
			ErrorDescription
		);
		
	EndIf;
	
	Successfully = SuccessfullyImported AND SuccessfullyExported;
	Return Successfully;
	
EndFunction

// Imports orders from the site.
//
// Parameters:
// Parameters				- Structure,
// main StatisticsStructure parameters		- Structure
// ErrorDescription			- String
//
// Return
// value Boolean				- True if success. 
//
Function ImportOrdersFromSite(Parameters, StatisticsStructure, ErrorDescription)
	
	ServerResponse = "";
	Join = Undefined;
	ConnectionType = "sale";
	
	AddressForWork = Parameters.ConnectionSettings.AddressOfScript + "?type=" + ConnectionType;
	
	ErrorDescription = "";
	If Not PerformAuthorizationForConnection(Join, Parameters.ConnectionSettings, ServerResponse, ErrorDescription, ConnectionType) Then
		
		AddErrorDescriptionFull(ErrorDescription, NStr("en = 'Orders import has not been performed.'"));
		Return False;
		
	EndIf;
	
	CookiesName				= StrGetLine(ServerResponse, 2);
	CookieValue		= StrGetLine(ServerResponse, 3);
	RequestsTitles	= "Cookie: " + CookiesName + "=" + CookieValue;
	
	ErrorDescription = "";
	ServerResponse = GetDataFromServer(
		Join,
		AddressForWork + Parameters.ConnectionSettings.HTTPQueryParameter_GetData,
		RequestsTitles,
		ErrorDescription
	);
	
	If ServerResponse = Undefined Then 
		
		AddErrorDescriptionFull(ErrorDescription, NStr("en = 'Orders import has not been performed.'"));
		Return False;
		
	EndIf;
	
	XMLString = "";
	
	If Left(ServerResponse, 2) = "PK" Then
		
		XMLString = UnpackZIPArchive(ServerResponse, ErrorDescription);
		
	Else
		
		If Left(ServerResponse, 5) = "<?xml" Then
			
			XMLString = ServerResponse;
			
		EndIf;
		
	EndIf;
	
	If IsBlankString(XMLString) Then
		
		AddErrorDescriptionFull(ErrorDescription, NStr("en = 'Failed to read data, exported from server.'"));
		Return False;
		
	EndIf;
	
	If Not ExportOrders(XMLString, StatisticsStructure, Parameters, ErrorDescription) Then 
		
		AddErrorDescriptionFull(ErrorDescription, 
			NStr("en = 'Failed to process documents, exported from server.'"));
			
		Return False;
		
	EndIf;
	
	ServerResponse = GetDataFromServer(
		Join,
		AddressForWork + Parameters.ConnectionSettings.HTTPQueryParameter_SuccessfulImportCompletion,
		RequestsTitles,
		ErrorDescription
	);
	
	If ServerResponse = Undefined Then 
		
		AddErrorDescriptionFull(ErrorDescription,
			NStr("en = 'Orders import has not been performed.'"));
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

// Imports orders from the file.
//
// Parameters:
// Parameters			- Structure,
// main StatisticsStructure parameters	- Structure
// ErrorDescription		- String
//
// Returns:
// Boolean				- True if success.
//
Function ImportOrdersFromFile(Parameters, StatisticsStructure, ErrorDescription)
	
	File = New File(Parameters.ImportFile);
	
	If Not File.Exist()
		OR File.IsDirectory() Then
		
		AddErrorDescriptionFull(ErrorDescription, NStr("en = 'Import file not found.'") + ": " + Parameters.ImportFile);
		Return False;
		
	EndIf;
	
	XMLFile = New TextDocument;
	XMLFile.Read(Parameters.ImportFile);
	XMLString = XMLFile.GetText();
	
	Return ExportOrders(XMLString, StatisticsStructure, Parameters, ErrorDescription);
	
EndFunction

// Imports orders.
//
// Parameters:
// OrdersData		- String for recording
// xml or XDTOObject StatisticsStructure	- Structure
// Parameters			- Structure,
// main ErrorDescription parameters		- String
//
// Returns:
// Boolean				- True if success.
//
Function ExportOrders(OrdersData, StatisticsStructure, Parameters, ErrorDescription) Export
	
	If TypeOf(OrdersData) = Type("XDTODataObject") Then
		XDTOOrders = OrdersData;
	Else
		XDTOOrders = GetXDTOOrders(OrdersData, Parameters, ErrorDescription);
	EndIf;
	
	If XDTOOrders = Undefined Then 
		
		Return False;
		
	ElsIf Not XDTOObjectContainsProperty(XDTOOrders, "Document") Then
		
		AddErrorDescriptionFull(ErrorDescription, NStr("en = 'No documents for processing.'"));
		Return True;
		
	EndIf;
	
	ArrayOfNumbers = New Array;
	
	XDTOOrdersArray = GetArrayOfXDTOListObjects(XDTOOrders.Document);
	For Each DocumentXDTO IN XDTOOrdersArray Do 
		ArrayOfNumbers.Add(DocumentXDTO.Number);
	EndDo;
	
	PreviouslyImportedOrders = GetPreviouslyImportedDocuments(ArrayOfNumbers);
	
	BeginTransaction();
	
	Successfully = CreateUpdateOrders(XDTOOrdersArray, PreviouslyImportedOrders, StatisticsStructure, Parameters, ErrorDescription);
	
	If Not Successfully Then
		
		RollbackTransaction();
		Return False;
		
	Else
		
		CommitTransaction();
		
	EndIf;
	
	// Set cancel status for cancelled orders.
	
	ArrayOfCanceledOrders = GetCanceledOrders(StatisticsStructure.Exported);
	If ArrayOfCanceledOrders.Count() > 0 Then
		
		For Each DocumentRef IN ArrayOfCanceledOrders Do
			
			DocumentObject = DocumentRef.GetObject();
			DocumentObject.OrderState = Parameters.OrderStatusInProcess;
			DocumentObject.Closed = True;
			
			Try
				
				WriteDocument(DocumentObject);
				
			Except
				
				AddErrorDescriptionFull(ErrorDescription,
					ExceptionalErrorDescription(NStr("en = 'Failed to cancel order: '")
						+ DocumentRef));
				
			EndTry;
			
		EndDo;
		
	EndIf;
	
	For Each DocumentRef IN StatisticsStructure.Exported Do
		
		WriteMode = DocumentWriteMode.Posting;
		
		DocumentObject = DocumentRef.GetObject();
		If DocumentObject.DeletionMark
			OR Not ValueIsFilled(DocumentObject.ShipmentDate) Then
			
			WriteMode = DocumentWriteMode.Write;
		EndIf;
		
		DocumentObject.DataExchange.Load = False;
		
		Try
			
			DocumentObject.Write(WriteMode);
			DocumentRef = DocumentObject.Ref;
			
		Except
		EndTry;
		
		If Not Parameters.ExchangeOverWebService Then
			NodesArray = GetNodesArrayForRegistration(, True);
			ExchangePlans.DeleteChangeRecords(NodesArray, DocumentRef);
		EndIf;
		
	EndDo;
		
	Return True;
	
EndFunction

// Creates based on XML object XDTO.
//
// Parameters:
// XMLString - XML object
// reading Parameters - structure
// ErrorDescription - String
//
// Returns:
// ObjectXDTO.
//
Function GetXDTOOrders(XMLString, Parameters, ErrorDescription)
	
	XMLObject = New XMLReader;
	
	Try
		
		XMLObject.SetString(XMLString);
		
	Except
		
		AddErrorDescriptionFull(ErrorDescription,
			ExceptionalErrorDescription(NStr("en = 'Failed to read XML'")));
			
		Return Undefined;
		
	EndTry;
	
	Try
		BusinessInformationXTDO = XDTOFactory.ReadXML(XMLObject);
	Except
		
		AddErrorDescriptionFull(ErrorDescription,
			ExceptionalErrorDescription(NStr("en = 'Failed to read XML'")));
			
		Return Undefined;
		
	EndTry;
	
	Return BusinessInformationXTDO;
	
EndFunction

// Receives orders previously exported from the site.
//
// Parameters:
// ArrayOfNumbers - array - Imported document numbers
//
// Return
// value Query result.
//
Function GetPreviouslyImportedDocuments(ArrayOfNumbers)
	
	Query = New Query();
	Query.SetParameter("ArrayOfNumbers", ArrayOfNumbers);
	
	Query.Text =
		"SELECT ALLOWED
		|	CustomerOrdersFromSite.CustomerOrder AS CustomerOrder,
		|	CustomerOrdersFromSite.OrderNumberOnSite AS OrderNumberOnSite
		|INTO TemporaryTableOrders
		|FROM
		|	InformationRegister.CustomerOrdersFromSite AS CustomerOrdersFromSite
		|WHERE
		|	CustomerOrdersFromSite.OrderNumberOnSite IN(&ArrayOfNumbers)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	TemporaryTableOrders.CustomerOrder AS CustomerOrder
		|INTO TemporaryTableOrdersWithRefs
		|FROM
		|	Document.CashReceipt.PaymentDetails AS CashReceiptPaymentDetails
		|		INNER JOIN TemporaryTableOrders AS TemporaryTableOrders
		|		ON CashReceiptPaymentDetails.Order = TemporaryTableOrders.CustomerOrder
		|
		|UNION ALL
		|
		|SELECT
		|	TemporaryTableOrders.CustomerOrder
		|FROM
		|	Document.InvoiceForPayment AS InvoiceForPayment
		|		INNER JOIN TemporaryTableOrders AS TemporaryTableOrders
		|		ON InvoiceForPayment.BasisDocument = TemporaryTableOrders.CustomerOrder
		|
		|UNION ALL
		|
		|SELECT
		|	TemporaryTableOrders.CustomerOrder
		|FROM
		|	Document.CustomerInvoice.Inventory AS CustomerInvoiceInventory
		|		INNER JOIN TemporaryTableOrders AS TemporaryTableOrders
		|		ON CustomerInvoiceInventory.Order = TemporaryTableOrders.CustomerOrder
		|
		|UNION
		|
		|SELECT
		|	TemporaryTableOrders.CustomerOrder
		|FROM
		|	Document.PaymentReceipt.PaymentDetails AS PaymentReceiptPaymentDetails
		|		INNER JOIN TemporaryTableOrders AS TemporaryTableOrders
		|		ON PaymentReceiptPaymentDetails.Order = TemporaryTableOrders.CustomerOrder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TemporaryTableOrders.CustomerOrder,
		|	TemporaryTableOrders.OrderNumberOnSite,
		|	CASE
		|		WHEN TemporaryTableOrdersWithRefs.CustomerOrder IS NULL 
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS AreRefs
		|FROM
		|	TemporaryTableOrders AS TemporaryTableOrders
		|		LEFT JOIN TemporaryTableOrdersWithRefs AS TemporaryTableOrdersWithRefs
		|		ON TemporaryTableOrders.CustomerOrder = TemporaryTableOrdersWithRefs.CustomerOrder";
	
	Result = Query.Execute().Unload();
	Return Result;
	
EndFunction

// Creates and fills in the customers orders.
//If there are references to the customer order in shipment or payment documents, only order attributes are updated.
//	
//Parameters
//	XDTODocuments - XDTO object
//	array PreviouslyImportedOrders - values table - data of the
//	previously exported orders StatisticsStructure - statistics
//	structure Parameters - ErrorDescription
//	parameter structure - String - contains error description
//
//Return
//	value Boolean - true if no errors occurred at order importing or attributes of already imported order is updated.
//
Function CreateUpdateOrders(XDTODocuments, PreviouslyImportedOrders, StatisticsStructure, Parameters, ErrorDescription)
	
	For Each DocumentXDTO IN XDTODocuments Do
		
		If Not XDTOObjectContainsProperty(DocumentXDTO, "BusinessTransaction")
			OR Not Lower(DocumentXDTO.BusinessTransaction) = "product order" Then
			
			AddErrorDescriptionFull(ErrorDescription,
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'Error in node value <Document>.<BusinessTransaction> of XML document (%1)'"),
					DocumentXDTO.BusinessTransaction));
			
			Return False;
			
		EndIf;
		
		If Not XDTOPropertyIsFilled(DocumentXDTO.Currency) Then
			
			AddErrorDescriptionFull(ErrorDescription,
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'Error in node value <Document>.<Currency> of XML document (%1)'"),
					DocumentXDTO.Currency));
				
			Return False;
			
		EndIf;
		
		StatisticsStructure.ProcessedOnImport = StatisticsStructure.ProcessedOnImport + 1;
		
		IsNewDocument = False;
		ReferencesOnPaymentDocumentsIsShipment = False;
		
		FounRow = PreviouslyImportedOrders.Find(DocumentXDTO.Number, "OrderNumberOnSite");
		If FounRow <> Undefined Then
			
			DocumentObject = FounRow.CustomerOrder.GetObject();
			
			If DocumentObject.Closed Then
				
				StatisticsStructure.Skipped.Add(FounRow.CustomerOrder);
				
				AddErrorDescriptionFull(ErrorDescription,
					String(DocumentObject.Ref) + NStr("en = ' skipped because of:'") + Chars.LF 
					+ NStr("en = 'Order state - Closed.'"));
				
				Continue;
				
			EndIf;
			
			ReferencesOnPaymentDocumentsIsShipment = FounRow.AreRefs;
			
		Else
			
			DocumentObject = Documents.CustomerOrder.CreateDocument();
			IsNewDocument = True;
		
		EndIf;
		
		// Receive order attributes.
		
		OrderProperties = New Map;
		
		If XDTOObjectContainsProperty(DocumentXDTO, "AttributeValues")
			AND DocumentXDTO.AttributeValues <> Undefined
			AND XDTOObjectContainsProperty(DocumentXDTO.AttributeValues, "AttributeValue") Then
			
			ValuesArrayDetailsXDTO = GetArrayOfXDTOListObjects(DocumentXDTO.AttributeValues.AttributeValue);
			
			For Each XDTOAttributeValue IN ValuesArrayDetailsXDTO Do
				
				Attribute = XDTOAttributeValue.Description;
				Value = XDTOAttributeValue.Value;
				
				If TypeOf(Value) = Type("String") Then
					OrderProperties.Insert(Attribute, Value);
				ElsIf TypeOf(Value) = Type("XDTOList")
					AND Value.Count() > 0 Then
					OrderProperties.Insert(Attribute, Value[0]);
				EndIf;
				
			EndDo;
			
		EndIf;
		
		If ReferencesOnPaymentDocumentsIsShipment Then
			
			// If there are references to payment or shipment documents in the order - update only attributes.
			
			StatisticsStructure.Skipped.Add(DocumentObject.Ref);
			
			Message = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = '%1 is ignored since exist the documents entered according to the order.'"),
				DocumentObject.Ref);
			
			AddErrorDescriptionFull(ErrorDescription, Message);
			
			If UpdateCreateAdditionalOrderInfo(DocumentObject.Ref, OrderProperties, ErrorDescription) Then
				
				Message = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'Order %1 properties updated.'"),
					DocumentObject.Ref);
				
				AddErrorDescriptionFull(ErrorDescription, Message);
				
			EndIf;
			
		Else
			
			Successfully = FillOrderWithXDTODocumentData(DocumentObject, DocumentXDTO, OrderProperties, Parameters, ErrorDescription);
			
			If Not Successfully Then
				Return False;
			EndIf;
			
			Try
				
				If Not ValueIsFilled(DocumentObject.Number)
					AND XDTOPropertyIsFilled(DocumentXDTO.Number) Then
					
					DocumentObject.Number = GetOrderNumberFromSite(DocumentXDTO.Number, DocumentObject.Company);
				EndIf;
				
				ExecuteActionsBeforeWriteOrder(DocumentObject);
				WriteDocument(DocumentObject);
				
				If IsNewDocument Then
					StatisticsStructure.Created.Add(DocumentObject.Ref);
				Else
					StatisticsStructure.Updated.Add(DocumentObject.Ref);
				EndIf;
				
			Except
				
				StatisticsStructure.Skipped.Add(DocumentObject);
				
				AddErrorDescriptionFull(ErrorDescription,
					ExceptionalErrorDescription(NStr("en = 'Failed to record order #'") + DocumentObject.Number));
				
				Return False;
				
			EndTry;
			
			UpdateCreateAdditionalOrderInfo(DocumentObject.Ref, OrderProperties, ErrorDescription);
			StatisticsStructure.Exported.Add(DocumentObject.Ref);
			
		EndIf;
		
		If IsNewDocument Then
			
			NewRecord = InformationRegisters.CustomerOrdersFromSite.CreateRecordManager();
			NewRecord.CustomerOrder = DocumentObject.Ref;
			NewRecord.OrderNumberOnSite = DocumentXDTO.Number;
			NewRecord.OrderDateOnSite = GetDateTimeFromString(DocumentXDTO.Date);
			NewRecord.Write();
			
		EndIf;
		
	EndDo;
	
	Return True;
	
EndFunction

Procedure ExecuteActionsBeforeWriteOrder(DocumentObject)
	
	DocumentObject.ShipmentDatePosition = Enums.AttributePositionOnForm.InHeader;
	
	For Each TabularSectionRow IN DocumentObject.Inventory Do
		TabularSectionRow.ShipmentDate = DocumentObject.ShipmentDate;
	EndDo;
	
	If ValueIsFilled(DocumentObject.Counterparty)
		AND Not DocumentObject.Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(DocumentObject.Contract) Then
		
		DocumentObject.Contract = DocumentObject.Counterparty.ContractByDefault;
	EndIf;
	
	DocumentObject.DocumentAmount = DocumentObject.Inventory.Total("Total") + DocumentObject.Works.Total("Total");
	
	DocumentObject.ChangeDate = CurrentDate();
	
EndProcedure

// The function determines whether there are any document movements.
//
Function DefineIfThereAreRegisterRecordsByDocument(DocumentRef)
	
	SetPrivilegedMode(True);
	
	QueryText = "";
	// to prevent from a crash of documents being posted for more than 256 tables
	Counter_tables = 0;
	
	DocumentMetadata = DocumentRef.Metadata();
	
	If DocumentMetadata.RegisterRecords.Count() = 0 Then
		Return New ValueTable;
	EndIf;
	
	For Each RegisterRecord IN DocumentMetadata.RegisterRecords Do
		// in the query we get names of the registers which have
		// at
		// least one movement, for
		// example, SELECT
		// First 1 AccumulationRegister.ProductsInWarehouses FROM AccumulationRegister.ProductsInWarehouses WHERE Recorder = &Recorder
		
		// we reduce the register name to Row(200), see below
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT TOP 1 CAST(""" + RegisterRecord.FullName() 
		+  """ AS String(200)) AS Name FROM " + RegisterRecord.FullName() 
		+ " WHERE Recorder = &Recorder";
		
		// if a query has more than 256 tables - we break it
		// into two parts (a version of the document with posting over 512 registers is considered unvital)
		Counter_tables = Counter_tables + 1;
		If Counter_tables = 256 Then
			Break;
		EndIf;
		
	EndDo;
	
	Query = New Query(QueryText);
	Query.SetParameter("Recorder", DocumentRef);
	// at exporting for the "Name" column, the type is set according to
	// the longest row from the query, at the second pass through the table, a new
	// name may not fit the space, therefore it is reduced to Row(200) already in the query
	QueryTable = Query.Execute().Unload();
	
	// if the number of tables does not exceed 256, we return the table
	If Counter_tables = DocumentMetadata.RegisterRecords.Count() Then
		Return QueryTable;			
	EndIf;
	
	// there are more than 256 tables, we make an add. query and amend the rows of the table.
	
	QueryText = "";
	For Each RegisterRecord IN DocumentMetadata.RegisterRecords Do
		
		If Counter_tables > 0 Then
			Counter_tables = Counter_tables - 1;
			Continue;
		EndIf;
		
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT TOP 1 """ + RegisterRecord.FullName() +  """ AS Name IN " 
		+ RegisterRecord.FullName() + " WHERE Recorder = &Recorder";	
		
		
	EndDo;
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		TableRow = QueryTable.Add();
		FillPropertyValues(TableRow, Selection);
	EndDo;
	
	Return QueryTable;
	
EndFunction

// The procedure clears the collection of document register records.
//
Procedure DocumentRecordsCollectionClear(DocumentObject)
		
	For Each RegisterRecord IN DocumentObject.RegisterRecords Do
		If RegisterRecord.Count() > 0 Then
			RegisterRecord.Clear();
		EndIf;
	EndDo;
	
EndProcedure // DocumentRecordsCollectionClearing()

// Procedure of removing the existing movements of the document during reposting (posting cancelation).
//
Procedure DeleteDocumentRegisterRecords(DocumentObject)
	
	RecordTableRowToProcessArray = New Array();
	
	// reception of the list of registers with existing movements
	RegisterRecordTable = DefineIfThereAreRegisterRecordsByDocument(DocumentObject.Ref);
	RegisterRecordTable.Columns.Add("RecordSet");
	RegisterRecordTable.Columns.Add("ForceDelete", New TypeDescription("Boolean"));
		
	For Each RegisterRecordRow IN RegisterRecordTable Do
		// the register name is transferred as a
		// value received using the FullName()function of register metadata
		DotPosition = Find(RegisterRecordRow.Name, ".");
		TypeRegister = Left(RegisterRecordRow.Name, DotPosition - 1);
		RegisterName = TrimR(Mid(RegisterRecordRow.Name, DotPosition + 1));

		RecordTableRowToProcessArray.Add(RegisterRecordRow);
		
		If TypeRegister = "AccumulationRegister" Then
			SetMetadata = Metadata.AccumulationRegisters[RegisterName];
			Set = AccumulationRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "AccountingRegister" Then
			SetMetadata = Metadata.AccountingRegisters[RegisterName];
			Set = AccountingRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "InformationRegister" Then
			SetMetadata = Metadata.InformationRegisters[RegisterName];
			Set = InformationRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "CalculationRegister" Then
			SetMetadata = Metadata.CalculationRegisters[RegisterName];
			Set = CalculationRegisters[RegisterName].CreateRecordSet();
			
		EndIf;
		
		If Not AccessRight("Update", Set.Metadata()) Then
			// No rights to all register table.
			Raise "Access violation: " + RegisterRecordRow.Name;
			Return;
		EndIf;

		Set.Filter.Recorder.Set(DocumentObject.Ref);

		// the set is not written immediately not to cancel
		// the transaction if it turns out later that you do not have enough rights for one of the registers.
		RegisterRecordRow.RecordSet = Set;
		
	EndDo;	
	
	For Each RegisterRecordRow IN RecordTableRowToProcessArray Do		
		Try
			RegisterRecordRow.RecordSet.Write();
		Except
			// RLS or the change disable date subsystem may be activated
			Raise "The operation failed. " + RegisterRecordRow.Name + Chars.LF + BriefErrorDescription(ErrorInfo());
		EndTry;
	EndDo;
	
	DocumentRecordsCollectionClear(DocumentObject);
	
EndProcedure

Procedure WriteDocument(DocumentObject)
	
	If Not ValueIsFilled(DocumentObject.Number) Then
		DocumentObject.SetNewNumber();
	EndIf;
	
	DocumentObject.DataExchange.Load = True;
	If Not DocumentObject.Posted Then
		DocumentObject.Write();
	Else
		// We cancel posting of the document.
		DocumentObject.Posted = False;
		DocumentObject.Write();
		DeleteDocumentRegisterRecords(DocumentObject);
	EndIf;
	
EndProcedure

// Refills customer order additional information values by the values from the OrderProperties mapping.
// Additional information failed to find is created.
//
// Parameters
// CustomerOrder - DocumentRef.CustomerOrder - order for which you
// create/reenter additional information OrderProperties - Map - properties and values
// of the exported order ErrorDescription - error information
//
// Return
// value Boolean - True if no error occurred in the process of updating/creating the additional information.
//
Function UpdateCreateAdditionalOrderInfo(CustomerOrder, OrderProperties, ErrorDescription)
	
	If OrderProperties.Count() = 0 Then
		Return False;
	EndIf;
	
	If Not ValueIsFilled(CustomerOrder) Then
		Return False;
	EndIf;
	
	PropertyTable = PropertiesManagement.GetValuesOfProperties(CustomerOrder, False, True);
	PropertyTable.Columns.Add("PropertyAsString");
	
	For Each PropertyString IN PropertyTable Do
		PropertyString.PropertyAsString = String(PropertyString.Property);
	EndDo;
	
	ArrayCreateUpdate = New Array;
	
	For Each OrderProperty IN OrderProperties Do
		
		SearchStructure = New Structure("PropertyAsString, Value", OrderProperty.Key, OrderProperty.Value);
		
		Found = PropertyTable.FindRows(SearchStructure);
		If Found.Count() = 0 Then
			
			ArrayCreateUpdate.Add(OrderProperty);
			
		EndIf;
		
	EndDo;
	
	If ArrayCreateUpdate.Count() = 0 Then
		Return False;
	EndIf;
	
	CCTQuery = New Query(
		"SELECT
		|	AdditionalAttributesAndInformation.Ref,
		|	AdditionalAttributesAndInformation.ValueType
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS AdditionalAttributesAndInformation
		|WHERE
		|	AdditionalAttributesAndInformation.ThisIsAdditionalInformation
		|	AND (NOT AdditionalAttributesAndInformation.DeletionMark)
		|	AND AdditionalAttributesAndInformation.Description = &Description");
	
	QuerySets = New Query(
		"SELECT
		|	SetsAdditionalDetailsAndAdditionalInformationAdditionalInformation.Property
		|FROM
		|	Catalog.AdditionalAttributesAndInformationSets.AdditionalInformation AS SetsAdditionalDetailsAndAdditionalInformationAdditionalInformation
		|WHERE
		|	SetsAdditionalDetailsAndAdditionalInformationAdditionalInformation.Ref = VALUE(Catalog.AdditionalAttributesAndInformationSets.Document_CustomerOrder)
		|	AND SetsAdditionalDetailsAndAdditionalInformationAdditionalInformation.Property = &Property");
	
	For Each OrderProperty IN ArrayCreateUpdate Do
		
		PropertyAsString = OrderProperty.Key;
		Value = OrderProperty.Value;
		
		CCTQuery.SetParameter("Description", PropertyAsString);
		
		Property = Undefined;
		
		Selection = CCTQuery.Execute().Select();
		While Selection.Next() Do
			
			If Selection.ValueType = New TypeDescription("String") Then
				
				Property = Selection.Ref;
				Break;
				
			EndIf;
			
		EndDo;
		
		If Property = Undefined Then
			
			PropertyObject = ChartsOfCharacteristicTypes.AdditionalAttributesAndInformation.CreateItem();
			PropertyObject.Comment = NStr("en = 'Created automatically at the order importing from the site'");
			PropertyObject.Description = PropertyAsString;
			PropertyObject.Title = PropertyAsString;
			PropertyObject.ValueType = New TypeDescription("String");
			PropertyObject.ThisIsAdditionalInformation = True;
			PropertyObject.Write();
			Property = PropertyObject.Ref;
			
		EndIf;
		
		QuerySets.SetParameter("Property", Property);
		
		If QuerySets.Execute().IsEmpty() Then
			
			WriteSet = Catalogs.AdditionalAttributesAndInformationSets.Document_CustomerOrder.GetObject();
			NewProperty = WriteSet.AdditionalInformation.Add();
			NewProperty.Property = Property;
			WriteSet.Write();
			
		EndIf;
		
		NewRecord = InformationRegisters.AdditionalInformation.CreateRecordManager();
		NewRecord.Object = CustomerOrder;
		NewRecord.Value = Value;
		NewRecord.Property = Property;
		NewRecord.Write();
		
	EndDo;
	
	Return True;
	
EndFunction

Function FillOrderWithXDTODocumentData(DocumentObject, DocumentXDTO, OrderProperties, Parameters, ErrorDescription)
	
	OperationKind = Enums.OperationKindsCustomerOrder.OrderForSale;
	PostingIsAllowed = True;
	
	SmallBusinessServer.FillDocumentHeader(
		DocumentObject,
		OperationKind,,,
		PostingIsAllowed
	);
	
	If ValueIsFilled(Parameters.CompanyToSubstituteIntoOrders) Then
		DocumentObject.Company = Parameters.CompanyToSubstituteIntoOrders;
	EndIf;
	
	DocumentObject.OperationKind = OperationKind;
	DocumentObject.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
	DocumentObject.ShipmentDatePosition = Enums.AttributePositionOnForm.InHeader;
	
	TimeString = "";
	If XDTOObjectContainsProperty(DocumentXDTO, "Time") Then
		TimeString = DocumentXDTO.Time;
	EndIf;
	
	DocumentObject.Date = GetDateTimeFromString(DocumentXDTO.Date, TimeString);
	DocumentObject.ShipmentDate = GetDateShipmentOfPropertyOrder(OrderProperties);
	DocumentObject.DocumentCurrency = ExchangeWithSiteReUse.ProcessCurrencyXML(DocumentXDTO.Currency);
	
	Filter = New Structure("Currency", DocumentObject.DocumentCurrency);
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Parameters.GeneratingDate, Filter);
	
	DocumentObject.ExchangeRate = StructureByCurrency.ExchangeRate;
	DocumentObject.Multiplicity = StructureByCurrency.Multiplicity;
	DocumentObject.PriceKind = GetKindOfPropertyPriceOrder(OrderProperties);
	
	Company = GetCompanyFromOrderAttributes(OrderProperties);
	If ValueIsFilled(Company) Then
		DocumentObject.Company = Company;
	EndIf;
	
	Warehouse = GetWarehousePropertyOrder(OrderProperties);
	If ValueIsFilled(Warehouse) Then
		DocumentObject.StructuralUnitReserve = Warehouse;
		Responsible = GetEmployeeOM(Warehouse.FRP);
		If ValueIsFilled(Responsible) Then
			DocumentObject.Responsible = Responsible;
		EndIf;
	EndIf;
	
	Division = GetDivisionOfOrderProperties(OrderProperties);
	If ValueIsFilled(Division) Then
		DocumentObject.SalesStructuralUnit = Division;
	EndIf;
	
	If ValueIsFilled(DocumentObject.Company) Then
		DocumentObject.BankAccount = DocumentObject.Company.BankAccountByDefault;
		DocumentObject.PettyCash = DocumentObject.Company.PettyCashByDefault;
	Else
		DocumentObject.PettyCash = Parameters.CompanyFolderOwner.PettyCashByDefault;
	EndIf;
	
	If Not IdentifyCounterparty(DocumentObject, DocumentXDTO, Parameters, ErrorDescription) Then
		AddErrorDescriptionFull(ErrorDescription,
			NStr("en = 'Failed  to identify the counterparty for the order number: '") + DocumentXDTO.Number);
	EndIf;
	
	If ValueIsFilled(DocumentObject.Counterparty)
		AND DocumentObject.Counterparty.DoOperationsByContracts Then
		
		CounterpartyContract = GetContractFromPropertiesOfOrder(OrderProperties, DocumentObject);
		If ValueIsFilled(CounterpartyContract) Then
			DocumentObject.Contract = CounterpartyContract;
		EndIf;
	EndIf;
	
	If Not IdentifyProductsAndServices(DocumentObject, DocumentXDTO, Parameters, ErrorDescription) Then
		Return False;
	EndIf;
	
	If Constants.UseCustomerOrderStates.Get() Then
		SetOrderStatus(DocumentObject, OrderProperties, Parameters.TableOfConformityOrderStatuses, Parameters);
	EndIf;
	
	If Not Parameters.ExchangeOverWebService Then
		Comment = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = ', % %No'"),
			DocumentXDTO.Number,
			?(Parameters.ExportToSite, Parameters.ConnectionSettings.Server, "(Site)")
		);
	Else
		Comment = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = ', % %No'"), 
			DocumentXDTO.Number, 
			"(Site)"
		);
		
	EndIf;
	
	If XDTOObjectContainsProperty(DocumentXDTO, "Comment") 
		AND TypeOf(DocumentXDTO.Comment) = Type("String") Then
		
		DocumentObject.Comment = Comment + " | " + DocumentXDTO.Comment;
	EndIf;
	
	Return True;
	
EndFunction

Function GetOrderNumberFromSite(Val NumberOnWebsite, Company)

	StringOfValidCharacters = "1234567890";
	DeleteArrayCharacters = New Array;
	
	NumberOnWebsite = TrimAll(NumberOnWebsite);
	If StrLen(NumberOnWebsite) > 0 Then
		
		For Ct = 1 to StrLen(NumberOnWebsite) Do
			
			Char = Lower(Mid(NumberOnWebsite, Ct, 1));
			If Not Find(StringOfValidCharacters, Char) Then
				DeleteArrayCharacters.Add(Char);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	For Each Char IN DeleteArrayCharacters Do
		NumberOnWebsite = StrReplace(NumberOnWebsite, Char, "");
	EndDo;
	
	SitePrefix = GetPrefixForOrderWithSite();
	StringFunctionsClientServer.SupplementString(SitePrefix, 2, "0", "Left");
	
	CompanyPrefix = "";
	
	FunctionalOptionInUse = False;
	ObjectsReprefixation.WhenDeterminingFunctionalOptionsOfCompanyPrefixes(FunctionalOptionInUse);
	If FunctionalOptionInUse = True Then
		
		CompanyPrefix = Undefined;
		ObjectsReprefixation.WhenPrefixDefinitionOrganization(Company, CompanyPrefix);
		
		// If a null reference to the company is specified.
		If CompanyPrefix = Undefined Then
			CompanyPrefix = "";
		EndIf;
		
		StringFunctionsClientServer.SupplementString(CompanyPrefix, 2, "0", "Left");
	EndIf;
	
	OrderPrefix = CompanyPrefix + SitePrefix + "-";
	NumberOrder = OrderPrefix + StringFunctionsClientServer.SupplementString(NumberOnWebsite, 6, "0", "Left");
	
	Return NumberOrder;
	
EndFunction

Function GetDateShipmentOfPropertyOrder(OrderProperties)
	
	ShipmentDate = Date(1,1,1);
	
	ShipmentDateString = OrderProperties.Get("Shipping date");
	If ShipmentDateString <> Undefined
		AND ValueIsFilled(ShipmentDateString) Then
		
		DateString = Left(ShipmentDateString, 10);
		TimeString = Mid(ShipmentDateString, 12);
		
		ShipmentDate = GetDateTimeFromString(DateString, TimeString);
		
	EndIf;
	
	Return ShipmentDate;
	
EndFunction

Function GetKindOfPropertyPriceOrder(OrderProperties)
	
	PriceKindProperty = OrderProperties.Get("Price kind");
	PriceKind = Catalogs.PriceKinds.EmptyRef();
	
	If PriceKindProperty <> Undefined
		AND TypeOf(PriceKindProperty) = Type("String")
		AND PriceKindProperty <> "" Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED TOP 1
		|	PriceKinds.Ref AS PriceKind
		|FROM
		|	Catalog.PriceKinds AS PriceKinds
		|WHERE
		|	PriceKinds.Description = &Description
		|	AND Not PriceKinds.DeletionMark";
		
		Query.SetParameter("Description", PriceKindProperty);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			PriceKind = Selection.PriceKind;
		EndIf;
		
	EndIf;
	
	Return PriceKind;
	
EndFunction

Function GetWarehousePropertyOrder(OrderProperties)
	
	WarehouseProperty = OrderProperties.Get("Warehouse");
	Warehouse = Catalogs.StructuralUnits.EmptyRef();
	
	If WarehouseProperty <> Undefined
		AND TypeOf(WarehouseProperty) = Type("String")
		AND WarehouseProperty <> "" Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED TOP 1
		|	StructuralUnits.Ref AS Warehouse
		|FROM
		|	Catalog.StructuralUnits AS StructuralUnits
		|WHERE
		|	StructuralUnits.Description = &Description
		|	AND Not StructuralUnits.DeletionMark
		|	AND StructuralUnits.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)";
		
		Query.SetParameter("Description", WarehouseProperty);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Warehouse = Selection.Warehouse;
		EndIf;
		
	EndIf;
	
	Return Warehouse;
	
EndFunction

Function GetEmployeeOM(Ind)
	
	Employee = Catalogs.Employees.EmptyRef();
	
	If Not ValueIsFilled(Ind) Then
		Return Employee;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	Employees.Ref AS Employee
	|FROM
	|	Catalog.Employees AS Employees
	|WHERE
	|	Employees.Ind = &Ind
	|	AND Not Employees.DeletionMark";
	
	Query.SetParameter("Ind", Ind);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Employee = Selection.Employee;
	EndIf;
	
	Return Employee;
	
EndFunction

Function GetCompanyFromOrderAttributes(OrderProperties)
	
	CompanyAttribute = OrderProperties.Get("Company");
	Company = Catalogs.Companies.EmptyRef();
	
	If CompanyAttribute <> Undefined
		AND TypeOf(CompanyAttribute) = Type("String")
		AND CompanyAttribute <> "" Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED TOP 1
		|	Companies.Ref AS Company
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	(Companies.Description = &Description
		|			OR Companies.TIN = &Description)
		|	AND Not Companies.DeletionMark";
		
		Query.SetParameter("Description", CompanyAttribute);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Company = Selection.Company;
		EndIf;
		
	EndIf;
	
	Return Company;
	
EndFunction

Function GetDivisionOfOrderProperties(OrderProperties)
	
	DivisionProperty = OrderProperties.Get("Division");
	Division = Catalogs.StructuralUnits.EmptyRef();
	
	If DivisionProperty <> Undefined
		AND TypeOf(DivisionProperty) = Type("String")
		AND DivisionProperty <> "" Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED TOP 1
		|	StructuralUnits.Ref AS Division
		|FROM
		|	Catalog.StructuralUnits AS StructuralUnits
		|WHERE
		|	StructuralUnits.Description = &Description
		|	AND Not StructuralUnits.DeletionMark
		|	AND StructuralUnits.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)";
		
		Query.SetParameter("Description", DivisionProperty);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Division = Selection.Division;
		EndIf;
		
	EndIf;
	
	Return Division;
	
EndFunction

Function GetContractFromPropertiesOfOrder(OrderProperties, DocumentObject)
	
	ContractProperty = OrderProperties.Get("Counterparty contract");
	Contract = Catalogs.CounterpartyContracts.EmptyRef();
	
	If ContractProperty <> Undefined
		AND TypeOf(ContractProperty) = Type("String")
		AND ContractProperty <> "" Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED TOP 1
		|	CounterpartyContracts.Ref AS Contract
		|FROM
		|	Catalog.CounterpartyContracts AS CounterpartyContracts
		|WHERE
		|	CounterpartyContracts.Description = &Description
		|	AND Not CounterpartyContracts.DeletionMark
		|	AND CounterpartyContracts.Owner = &Owner
		|	AND CounterpartyContracts.Company = &Company
		|	AND CounterpartyContracts.ContractKind = VALUE(Enum.ContractKinds.WithCustomer)";
		
		Query.SetParameter("Description", ContractProperty);
		Query.SetParameter("Owner", DocumentObject.Counterparty);
		If Not SmallBusinessReUse.CounterpartyContractsControlNeeded() Then
			Query.Text = StrReplace(Query.Text, "CounterpartyContracts.Company = &Company", "TRUE");
			Query.Text = StrReplace(Query.Text, "CounterpartyContracts.ContractKind = VALUE(Enumeration.ContractKinds.WithCustomer)", "TRUE");
		Else
			Query.SetParameter("Company", DocumentObject.Company);
		EndIf;
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Contract = Selection.Contract;
		EndIf;
		
		If Not ValueIsFilled(Contract) Then
			
			NewContract = Catalogs.CounterpartyContracts.CreateItem();
			
			NewContract.Description = ContractProperty;
			NewContract.SettlementsCurrency = DocumentObject.DocumentCurrency;
			NewContract.Company = DocumentObject.Company;
			NewContract.ContractKind = Enums.ContractKinds.WithCustomer;
			NewContract.PriceKind = DocumentObject.PriceKind;
			NewContract.Owner = DocumentObject.Counterparty;
			NewContract.VendorPaymentDueDate = Constants.VendorPaymentDueDate.Get();
			NewContract.CustomerPaymentDueDate = Constants.CustomerPaymentDueDate.Get();
			NewContract.Write();
			
			Contract = NewContract.Ref;
			
		EndIf;
	EndIf;
	
	Return Contract;
	
EndFunction

// Searches the counterparty based on the counterparty identification method specified for the exchange plan node.
// For the specified Name or TINKPP counterparty identification method the counterparty is created if it is not found.
//
// Parameters
// DocumentObject - DocumentObject.CustomerOrder - order for which a counterparty is identified.
// DocumentXDTO - XDTODataObject - information source for filling
// the counterparty data  OrderAttributes - Map - imported order attributes. For the specified PredefinedValue counterparty
// 								identification method the CounterpartyData attribute containing counterparty information is added to OrderAttributes.
// Parameters - Structure - ErrorDescription
// exchange parameters - String - error information
//
// Returns:
// Boolean - True if the counterparty was successfully identified.
//
Function IdentifyCounterparty(DocumentObject, DocumentXDTO, Parameters, ErrorDescription)
	
	If TypeOf(DocumentXDTO.Counterparties.Counterparty) = Type("XDTODataObject") Then
		XDTOCounterparty = DocumentXDTO.Counterparties.Counterparty;
	Else
		XDTOCounterparty = DocumentXDTO.Counterparties.Counterparty[0];
	EndIf;
	
	CounterpartyInformation = DocumentObject.CounterpartyInformation;
	CounterpartyInformation.Clear();
	
	If Parameters.CounterpartiesIdentificationMethod = Enums.CounterpartiesIdentificationMethods.PredefinedValue Then
		
		CounterpartyRef = Parameters.CounterpartyToSubstituteIntoOrders;
		FillCounterpartyDataOfOrder(XDTOCounterparty, CounterpartyInformation);
		
	Else
		
		LegalEntity = XDTOObjectContainsProperty(XDTOCounterparty, "OfficialName");
		
		TIN = "";
		If XDTOObjectContainsProperty(XDTOCounterparty, "TIN")
			AND TypeOf(XDTOCounterparty.TIN) = Type("String") Then
			TIN = XDTOCounterparty.TIN;
		EndIf;
		
		KPP = "";
		If XDTOObjectContainsProperty(XDTOCounterparty, "KPP")
			AND TypeOf(XDTOCounterparty.KPP) = Type("String") Then
			KPP = XDTOCounterparty.KPP;
		EndIf;
		
		Description = "";
		If XDTOObjectContainsProperty(XDTOCounterparty, "Description")
			AND TypeOf(XDTOCounterparty.Description) = Type("String") Then
			Description = XDTOCounterparty.Description;
		EndIf;
		
		Query = New Query();
		Query.Text =
		"SELECT
		|	Counterparties.Ref AS Counterparty
		|FROM
		|	Catalog.Counterparties AS Counterparties";
		
		If IsBlankString(Description) Then
			
			AddErrorDescriptionFull(ErrorDescription, 
				NStr("en = 'Counterparty name is not filled!'"));
			
			Return False;
			
		EndIf;
		
		TextOfMessageFoundFewCounterparties = "";
		
		If Parameters.CounterpartiesIdentificationMethod = Enums.CounterpartiesIdentificationMethods.Description Then
			
			TextOfMessageFoundFewCounterparties = NStr("en = ' by description: '") + Description;
			
			Query.Text = Query.Text + " WHERE Counterparties.Name = &Name ";
			
			Query.SetParameter("Description", Description);
			
		ElsIf Parameters.CounterpartiesIdentificationMethod = Enums.CounterpartiesIdentificationMethods.TINKPP Then	
			
			If IsBlankString(TIN) Then
				
				AddErrorDescriptionFull(ErrorDescription, 
					NStr("en = 'Counterparty TIN is not filled!'"));
				
				Return False;
				
			EndIf;
			
			TextOfMessageFoundFewCounterparties = 
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = ' by TIN: %1, KPP: %2'"),
					TIN, KPP);
			
			Query.Text = Query.Text + " WHERE Counterparties.TIN = &TIN AND Counterparties.KPP = &KPP ";
			
			Query.SetParameter("TIN", TIN);
			Query.SetParameter("KPP", KPP);
			
		EndIf;
		
		CounterpartyRef = Undefined;
		
		QueryResult = Query.Execute();
		If QueryResult.IsEmpty() Then
			
			CounterpartyRef = CreateCounterparty(DocumentObject, XDTOCounterparty, Parameters, ErrorDescription);
			
		Else
			
			Counterparties = QueryResult.Unload();
			CounterpartyRef = Counterparties[0].Counterparty;
			
		EndIf;
		
		If Not ValueIsFilled(CounterpartyRef) Then
			
			AddErrorDescriptionFull(ErrorDescription, 
				NStr("en = 'Failed to find or create counterparty!'"));
			
			Return False;
			
		EndIf;
		
	EndIf;
	
	DocumentObject.Counterparty = CounterpartyRef;
	
	ContractKindsList = New ValueList;
	ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
	ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(DocumentObject.Counterparty, DocumentObject.Company, ContractKindsList);
	
	DocumentObject.Contract = ContractByDefault;
	
	Return True;
	
EndFunction

// Adds and fills in the string of the CounterpartyInformation tabular section of the customer order.
//
// Parameters
// Kind - String,
// Presentation information kind - String, CounterpartyInformation
// information presentation - TablePart CustomerOrder document.
//
Procedure AddInformationStringAboutCounterparty(Kind, Presentation, CounterpartyInformation)
	
	If ValueIsFilled(Presentation) Then
		NewRow = CounterpartyInformation.Add();
		NewRow.Type = Kind;
		NewRow.Presentation = TrimAll(Presentation);
	EndIf;
	
EndProcedure

// Fills in the CounterpartyInformation tabular section of the customer order.
//
Procedure FillCounterpartyDataOfOrder(XDTOCounterparty, CounterpartyInformation)
	
	ThisIsLegalEntity = False;
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "Description") AND XDTOPropertyIsFilled(XDTOCounterparty.Description) Then
		
		AddInformationStringAboutCounterparty("Description", XDTOCounterparty.Description, CounterpartyInformation);
		
	EndIf;
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "FullDescr") AND XDTOPropertyIsFilled(XDTOCounterparty.FullDescr) Then
		
		AddInformationStringAboutCounterparty("Full description", XDTOCounterparty.FullDescr, CounterpartyInformation);
		AddInformationStringAboutCounterparty("Legal./Ind. person", "Individual", CounterpartyInformation);
		
	ElsIf XDTOObjectContainsProperty(XDTOCounterparty, "OfficialName") AND XDTOPropertyIsFilled(XDTOCounterparty.OfficialName) Then
		
		AddInformationStringAboutCounterparty("Full description", XDTOCounterparty.OfficialName, CounterpartyInformation);
		AddInformationStringAboutCounterparty("Legal./Ind. person", "Leg. person", CounterpartyInformation);
		
		ThisIsLegalEntity = True;
		
	EndIf;
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "TIN") Then
		AddInformationStringAboutCounterparty("TIN", XDTOCounterparty.TIN, CounterpartyInformation);
	EndIf;
		
	If XDTOObjectContainsProperty(XDTOCounterparty, "KPP") Then
		AddInformationStringAboutCounterparty("KPP", XDTOCounterparty.KPP, CounterpartyInformation);
	EndIf;
		
	If XDTOObjectContainsProperty(XDTOCounterparty, "OKPO") AND XDTOPropertyIsFilled(XDTOCounterparty.OKPO) Then
		AddInformationStringAboutCounterparty("OKPO", XDTOCounterparty.OKPO, CounterpartyInformation);
	EndIf;
	
	//Bank accounts.
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "BankAccounts")
		AND XDTOCounterparty.BankAccounts <> Undefined
		AND XDTOObjectContainsProperty(XDTOCounterparty.BankAccounts, "BankAccount") Then
		
		XDTOBankAccounts = XDTOCounterparty.BankAccounts.BankAccount;
		XDTOBankAccountsArray = GetArrayOfXDTOListObjects(XDTOBankAccounts);
		
		For Each XDTOBankAccount IN XDTOBankAccountsArray Do
			
			AccountNo = StrReplace(XDTOBankAccount.AccountNo, " ", "");
			
			BankXDTO = XDTOBankAccount.Bank;
			XDTOBankData = GetXDTOBankData(BankXDTO);
			
			Comment = "";
			If XDTOObjectContainsProperty(XDTOBankAccount, "Comment")
				AND XDTOPropertyIsFilled(XDTOBankAccount.Comment) Then
				
				Comment = XDTOBankAccount.Comment;
				
			EndIf;
			
			InformationOnCurrentAccount = "Account number = " + AccountNo 
				+ ?(IsBlankString(XDTOBankData.Description), "", ", Bank = " + XDTOBankData.Description)
				+ ?(IsBlankString(XDTOBankData.BIN), "", ", BIC = " + XDTOBankData.BIN)
				+ ?(IsBlankString(XDTOBankData.SWIFT), "", ", SWIFT = " + XDTOBankData.SWIFT)
				+ ?(IsBlankString(XDTOBankData.CorrAccount), "", ", CorrAccount = " + XDTOBankData.CorrAccount)
				+ ?(IsBlankString(XDTOBankData.City), "", ", City = " + XDTOBankData.City)
				+ ?(IsBlankString(XDTOBankData.Address), "", ", Address = " + XDTOBankData.Address)
				+ ?(IsBlankString(Comment), "", ", Comment = " + Comment);
				
			AddInformationStringAboutCounterparty("Bank account", InformationOnCurrentAccount, CounterpartyInformation);
			
		EndDo;
		
	EndIf;
	
	//Contact information.
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "Address") AND XDTOPropertyIsFilled(XDTOCounterparty.Address.Presentation) Then
		
		AddInformationStringAboutCounterparty("Actual address", XDTOCounterparty.Address.Presentation, CounterpartyInformation);
		
	EndIf;
	
	If ThisIsLegalEntity AND XDTOObjectContainsProperty(XDTOCounterparty, "LegalAddress")
		AND XDTOPropertyIsFilled(XDTOCounterparty.LegalAddress.Presentation) Then
		
		AddInformationStringAboutCounterparty("Legal address", XDTOCounterparty.LegalAddress.Presentation, CounterpartyInformation);
		
	ElsIf Not ThisIsLegalEntity AND XDTOObjectContainsProperty(XDTOCounterparty, "RegistrationAddress")
		AND XDTOPropertyIsFilled(XDTOCounterparty.RegistrationAddress.Presentation) Then // ind. contains the registration address
		
		AddInformationStringAboutCounterparty("Legal address", XDTOCounterparty.RegistrationAddress.Presentation, CounterpartyInformation);
		
	EndIf;
	
	//Contacts.
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "Contacts") AND XDTOCounterparty.Contacts <> Undefined Then
		
		XDTOContacts = XDTOCounterparty.Contacts.Contact;
		ArrayOfContactsXDTO = GetArrayOfXDTOListObjects(XDTOContacts);
		
		For Each XDTOContact IN ArrayOfContactsXDTO Do
			
			XDTOCIType = StrReplace(XDTOContact.Type, " ", "");
			CIStructure = GetTypeContactInformationKindByXDTOType(XDTOCIType);
			
			AddInformationStringAboutCounterparty(CIStructure.Type.Description, XDTOContact.Value, CounterpartyInformation);
			
		EndDo;
		
	EndIf;
	
	// Contact persons.
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "Representatives") AND XDTOCounterparty.Representatives <> Undefined Then
		
		XDTORepresentatives = XDTOCounterparty.Representatives.Representative;
		ArrayOfXDTO = GetArrayOfXDTOListObjects(XDTORepresentatives);
		
		If ArrayOfXDTO.Count() > 0 Then
			
			ContactPersons = "";
			
			For Each XDTORepresentative IN ArrayOfXDTO Do
				
				DescriptionCP = "";
				If XDTOObjectContainsProperty(XDTORepresentative, "Counterparty") 
					AND XDTOObjectContainsProperty(XDTORepresentative.Counterparty, "Description") Then
					
					DescriptionCP = XDTORepresentative.Counterparty.Description;
					
				EndIf;
				
				If Not IsBlankString(DescriptionCP) Then
					ContactPersons = ContactPersons + DescriptionCP + ";";
				EndIf;
				
			EndDo;
			
			ContactPersons = Mid(ContactPersons,1,StrLen(ContactPersons)-1);
			AddInformationStringAboutCounterparty("Contact persons", ContactPersons, CounterpartyInformation);
			
		EndIf;
	EndIf;
	
EndProcedure

// Creates counterparty and items of subordinate catalogs.
//
// Parameters
// DocumentObject - DocumentObject.CustomerOrder - order for which the counterparty is created.
// XDTOCounterparty - XDTODataObject - information source for filling
// the counterparty data Parameters - Structure - ErrorDescription
// exchange parameters - String - error information
//
// Returns:
// CatalogRef.Counterparties - Reference to catalog item.
//
Function CreateCounterparty(DocumentObject, XDTOCounterparty, Parameters, ErrorDescription)
	
	NewCounterparty = Catalogs.Counterparties.CreateItem();
	FillPropertyValues(NewCounterparty, XDTOCounterparty);
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "OKPO") AND XDTOPropertyIsFilled(XDTOCounterparty.OKPO) Then
		NewCounterparty.CodeByOKPO = XDTOCounterparty.OKPO;
	EndIf;
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "FullDescr") Then
		NewCounterparty.DescriptionFull = XDTOCounterparty.FullDescr;
	EndIf;
	
	NewCounterparty.Parent = Parameters.GroupForNewCounterparties;
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "OfficialName") Then
		NewCounterparty.DescriptionFull = XDTOCounterparty.OfficialName;
		NewCounterparty.LegalEntityIndividual = Enums.LegalEntityIndividual.LegalEntity;
	Else
		NewCounterparty.LegalEntityIndividual = Enums.LegalEntityIndividual.Ind;
	EndIf;
	
	SNPString = GetFromXDTOObjectStringWithSNP(XDTOCounterparty);
	If Not IsBlankString(SNPString) 
		AND SNPString <> NewCounterparty.DescriptionFull Then
		
		NewCounterparty.DescriptionFull = NewCounterparty.DescriptionFull + " [" + SNPString + "]";
		
	EndIf;
	
	NewCounterparty.DoOperationsByContracts = True;
	NewCounterparty.DoOperationsByDocuments = True;
	NewCounterparty.DoOperationsByOrders = True;
	NewCounterparty.TrackPaymentsByBills = True;
	
	// Values by default.
	
	NewCounterparty.GLAccountCustomerSettlements = ChartsOfAccounts.Managerial.AccountsReceivable;
	NewCounterparty.CustomerAdvancesGLAccount = ChartsOfAccounts.Managerial.AccountsByAdvancesReceived;
	NewCounterparty.GLAccountVendorSettlements = ChartsOfAccounts.Managerial.AccountsPayable;
	NewCounterparty.VendorAdvancesGLAccount = ChartsOfAccounts.Managerial.SettlementsByAdvancesIssued;
	
	NewCounterparty.Responsible = DocumentObject.Responsible;
	
	FillCounterpartyContactInformation(NewCounterparty, XDTOCounterparty);
	
	NewCounterparty.Write();
	FillDataOfCatalogsSubordinatedToCounterparty(DocumentObject, NewCounterparty, XDTOCounterparty, ErrorDescription);
	NewCounterparty.Write();
	
	Return NewCounterparty.Ref;
	
EndFunction

Procedure FillCounterpartyContactInformation(CounterpartyObject, XDTOCounterparty)
	
	// Addresses.
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "Address") Then
		
		AddressKind = Catalogs.ContactInformationTypes.CounterpartyFactAddress;
		AddressXDTO = XDTOCounterparty.Address;
		
		FillCounterpartyContactInformationStringFromXDTOObject(CounterpartyObject, AddressKind, AddressXDTO);
		
	EndIf;
	
	If CounterpartyObject.LegalEntityIndividual = Enums.LegalEntityIndividual.LegalEntity
		AND XDTOObjectContainsProperty(XDTOCounterparty, "LegalAddress") Then
		
		AddressKind = Catalogs.ContactInformationTypes.CounterpartyLegalAddress;
		AddressXDTO = XDTOCounterparty.LegalAddress;
		
		FillCounterpartyContactInformationStringFromXDTOObject(CounterpartyObject, AddressKind, AddressXDTO);
		
	// Individual contains the registration address.
	ElsIf CounterpartyObject.LegalEntityIndividual = Enums.LegalEntityIndividual.Ind
		AND XDTOObjectContainsProperty(XDTOCounterparty, "RegistrationAddress") Then
		
		AddressKind = Catalogs.ContactInformationTypes.CounterpartyLegalAddress;
		AddressXDTO = XDTOCounterparty.RegistrationAddress;
		
		FillCounterpartyContactInformationStringFromXDTOObject(CounterpartyObject, AddressKind, AddressXDTO);
		
	EndIf;
		
	// Contacts.
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "Contacts") Then
		
		XDTOContacts = XDTOCounterparty.Contacts.Contact;
		ArrayOfContactsXDTO = GetArrayOfXDTOListObjects(XDTOContacts);
		
		For Each XDTOContact IN ArrayOfContactsXDTO Do 
			
			XDTOCIType = StrReplace(XDTOContact.Type, " ", "");
			CIStructure = GetTypeContactInformationKindByXDTOType(XDTOCIType);
			
			CIRow = CounterpartyObject.ContactInformation.Add();
			FillPropertyValues(CIRow, CIStructure);
			CIRow.Presentation = XDTOContact.Value;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillCounterpartyContactInformationStringFromXDTOObject(CounterpartyObject, AddressKind, AddressXDTO)
	
	If Not XDTOPropertyIsFilled(AddressXDTO.Presentation) Then
		Return;
	EndIf;
	
	CIRow = CounterpartyObject.ContactInformation.Add();
	CIRow.Type = Enums.ContactInformationTypes.Address;
	CIRow.Type = AddressKind;
	CIRow.Presentation = AddressXDTO.Presentation;
	
	If XDTOObjectContainsProperty(AddressXDTO, "AddressField") Then
		
		XDTOAddressFieldsArray = GetArrayOfXDTOListObjects(AddressXDTO.AddressField);
		FieldMap = New Map;
		
		For Each XDTODataObject IN XDTOAddressFieldsArray Do
			
			FieldName = ExchangeWithSiteReUse.DefineByContactInfoFieldNameType(XDTODataObject.Type);
			FieldMap.Insert(FieldName, XDTODataObject.Value);
			
			If FieldName = "Country" Then
				CIRow.Country = XDTODataObject.Value;
			ElsIf FieldName = "Region" Then
				CIRow.Region = XDTODataObject.Value;
			ElsIf FieldName = "City" Then
				CIRow.City = XDTODataObject.Value;
			EndIf;
			
		EndDo;
		
		CIRow.FieldsValues = ConvertFieldListToString(FieldMap);
		
	EndIf;
	
EndProcedure

Procedure FillDataOfCatalogsSubordinatedToCounterparty(DocumentObject, CounterpartyObject, XDTOCounterparty, ErrorDescription)
	
	// Contact persons.
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "Representatives") AND XDTOCounterparty.Representatives <> Undefined Then
		
		XDTORepresentatives = XDTOCounterparty.Representatives.Representative;
		ArrayOfXDTO = GetArrayOfXDTOListObjects(XDTORepresentatives);
		
		For Each XDTORepresentative IN ArrayOfXDTO Do 
			
			DescriptionCP = "";
			If XDTOObjectContainsProperty(XDTORepresentative, "Counterparty") 
				AND XDTOObjectContainsProperty(XDTORepresentative.Counterparty, "Description") Then
				
				Description = XDTORepresentative.Counterparty.Description;
				
			EndIf;
			
			Item = Catalogs.ContactPersons.CreateItem();
			Item.Owner = CounterpartyObject.Ref;
			Item.Description = Description;
			Item.Comment = NStr("en = 'Created automaticly on order import from site '") + CurrentDate();
			Item.Write();
			
		EndDo;
		
	EndIf;
	
	//Banks and bank accounts.
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "BankAccounts")
		AND XDTOCounterparty.BankAccounts <> Undefined
		AND XDTOObjectContainsProperty(XDTOCounterparty.BankAccounts, "BankAccount") Then
		
		XDTOBankAccounts = XDTOCounterparty.BankAccounts.BankAccount;
		XDTOBankAccountsArray = GetArrayOfXDTOListObjects(XDTOBankAccounts);
		
		For Each XDTOBankAccount IN XDTOBankAccountsArray Do
			
			AccountNo = StrReplace(XDTOBankAccount.AccountNo, " ", "");
			
			If IsBlankString(AccountNo) Then
				Continue;
			EndIf;
			
			BankXDTO = XDTOBankAccount.Bank;
			XDTOBankData = GetXDTOBankData(BankXDTO);
			
			BIN = XDTOBankData.BIN;
			If Not XDTOPropertyIsFilled(BIN) Then
				Continue;
			EndIf;
			
			Query = New Query(
			"SELECT TOP 1
			|	Banks.Ref
			|FROM
			|	Catalog.Banks AS Banks
			|WHERE
			|	Banks.Code = &BIN");
			
			Query.SetParameter("BIN", BIN);
			
			QueryResult = Query.Execute();
			If QueryResult.IsEmpty() Then
				
				BankObject = Catalogs.Banks.CreateItem();
				BankObject.Code = BIN;
				
				FillPropertyValues(BankObject, XDTOBankData);
				
				BankObject.Write();
				BankRef = BankObject.Ref;
				
			Else
				
				BankRef = QueryResult.Unload()[0][0];
				
			EndIf;
			
			// Bank account.
			
			Query = New Query(
			"SELECT TOP 1
			|	BankAccounts.Ref
			|FROM
			|	Catalog.BankAccounts AS BankAccounts
			|WHERE
			|	BankAccounts.Owner = &Owner
			|	AND BankAccounts.AccountNo = &AccountNo
			|	AND BankAccounts.Bank = &Bank");
			
			Query.SetParameter("Owner", CounterpartyObject.Ref);
			Query.SetParameter("AccountNo", AccountNo);
			Query.SetParameter("Bank", BankRef);
			
			If Not Query.Execute().IsEmpty() Then
				Continue;
			EndIf;
			
			Currency = GetCurrencyByAccountNo(AccountNo);
			If Not ValueIsFilled(Currency) Then
				
				AddErrorDescriptionFull(ErrorDescription,
					ExceptionalErrorDescription(NStr("en = 'Failed to define bank account currency: '")
					+ AccountNo));
				
				Continue;
				
			EndIf;
			
			AccountObject = Catalogs.BankAccounts.CreateItem();
			AccountObject.Bank = BankRef;
			AccountObject.CashCurrency = Currency;
			AccountObject.Owner = CounterpartyObject.Ref;
			AccountObject.Description = BankRef.Description;
			AccountObject.AccountNo = AccountNo;
			
			AccountObject.Write();
			
		EndDo;
		
	EndIf;
	
	// Contract.
	
	If ValueIsFilled(CounterpartyObject.ContractByDefault) Then
		Contract = CounterpartyObject.ContractByDefault.GetObject();
	Else
		Contract = Catalogs.CounterpartyContracts.CreateItem();
	EndIf;
	
	Contract.Description = "Main contract";
	Contract.SettlementsCurrency = DocumentObject.DocumentCurrency;
	Contract.Company = DocumentObject.Company;
	Contract.ContractKind = Enums.ContractKinds.WithCustomer;
	Contract.PriceKind = DocumentObject.PriceKind;
	Contract.Owner = CounterpartyObject.Ref;
	Contract.VendorPaymentDueDate = Constants.VendorPaymentDueDate.Get();
	Contract.CustomerPaymentDueDate = Constants.CustomerPaymentDueDate.Get();
	Contract.Write();
	
	CounterpartyObject.ContractByDefault = Contract.Ref;
	
EndProcedure

// Searches products and services and fills in the Inventory tabular section of the customer order.
// Products and services items that are not found are created.
//
// Parameters
// DocumentObject - DocumentObject.CustomerOrder - order for which
// we identify products and services DocumentXDTO - XDTODataObject - source information for filling the
// customer order data Parameters - Structure - ErrorDescription
// exchange parameters - String - error information
//
// Returns:
// Boolean - True if no error occurred.
//
Function IdentifyProductsAndServices(DocumentObject, DocumentXDTO, Parameters, ErrorDescription)
	
	Successfully = True;
	
	If Not XDTOObjectContainsProperty(DocumentXDTO, "Products")
		OR DocumentXDTO.Products = Undefined
		OR Not XDTOObjectContainsProperty(DocumentXDTO.Products, "Product") Then
		
		Return Successfully;
		
	EndIf;
	
	DefaultVATRate = Undefined;
	
	If XDTOObjectContainsProperty(DocumentXDTO, "Taxes")
		AND DocumentXDTO.Taxes <> Undefined
		AND XDTOObjectContainsProperty(DocumentXDTO.Taxes, "Tax") Then
		
		XDTOTaxes = DocumentXDTO.Taxes.Tax;
		ArrayTaxesXDTO = GetArrayOfXDTOListObjects(XDTOTaxes);
		
		For Each XDTOTax IN ArrayTaxesXDTO Do
			
			If XDTOObjectContainsProperty(XDTOTax, "Description") AND Lower(XDTOTax.Description) = "vat" Then
				
				If XDTOObjectContainsProperty(XDTOTax, "Rate") Then
					DefaultVATRate = ExchangeWithSiteReUse.GetByValueForExportingVATRate(XDTOTax.Rate);
				EndIf;
				
				If XDTOObjectContainsProperty(XDTOTax, "IncludedInAmount") Then
					DocumentObject.AmountIncludesVAT = XDTOTax.IncludedInAmount = True OR Lower(XDTOTax.IncludedInAmount) = "true";
				EndIf;
				
				Break;
				
			EndIf;
			
		EndDo;
		
	Else
		
		// If there is no Taxes section, we believe that the document is not subject to VAT.
		DocumentObject.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT;
		
	EndIf;
	
	DocumentObject.Inventory.Clear();
	
	XDTOProducts = DocumentXDTO.Products.Product;
	XDTOProductsArray = GetArrayOfXDTOListObjects(XDTOProducts);
	
	For Each XDTOProduct IN XDTOProductsArray Do
		
		XDTOProductsAndServicesType = "";
		
		If XDTOObjectContainsProperty(XDTOProduct, "AttributeValues")
			AND XDTOProduct.AttributeValues <> Undefined
			AND XDTOObjectContainsProperty(XDTOProduct.AttributeValues, "AttributeValue") Then
			
			AttributeValuesXDTO = XDTOProduct.AttributeValues.AttributeValue;
			ValuesArrayDetailsXDTO = GetArrayOfXDTOListObjects(AttributeValuesXDTO);
			
			For Each XDTOAttributeValue IN ValuesArrayDetailsXDTO Do
				
				If XDTOAttributeValue.Description = "ProductsAndServicesType" 
					AND TypeOf(XDTOAttributeValue.Value) = Type("String") Then
					
					XDTOProductsAndServicesType = XDTOAttributeValue.Value;
					Break;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		ProductsAndServicesVATRate = Undefined;
		
		If XDTOObjectContainsProperty(XDTOProduct, "TaxesRates")
			AND XDTOProduct.TaxesRates <> Undefined
			AND XDTOObjectContainsProperty(XDTOProduct.TaxesRates, "TaxRate") Then
			
			TaxesRates = XDTOProduct.TaxesRates.TaxRate;
			XDTORatesArray = GetArrayOfXDTOListObjects(TaxesRates);
			
			For Each TaxRate IN XDTORatesArray Do
				
				If Lower(TaxRate.Description) = "vat" Then
					
					ProductsAndServicesVATRate = ExchangeWithSiteReUse.GetByValueForExportingVATRate(TaxRate.Rate);
					Break;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		If XDTOObjectContainsProperty(XDTOProduct, "Taxes")
			AND XDTOProduct.Taxes <> Undefined
			AND XDTOObjectContainsProperty(XDTOProduct.Taxes, "Tax") Then
			
			XDTOTaxes = XDTOProduct.Taxes.Tax;
			ArrayTaxesXDTO = GetArrayOfXDTOListObjects(XDTOTaxes);
			
			For Each XDTOTax IN ArrayTaxesXDTO Do
				
				If XDTOObjectContainsProperty(XDTOTax, "Description") AND Lower(XDTOTax.Description) = "vat" Then
					
					If XDTOObjectContainsProperty(XDTOTax, "Rate") Then
						
						ProductsAndServicesVATRate = ExchangeWithSiteReUse.GetByValueForExportingVATRate(XDTOTax.Rate);
						Break;
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		ProductsAndServicesVATRate = ?(ValueIsFilled(ProductsAndServicesVATRate), ProductsAndServicesVATRate, DefaultVATRate);
		If ProductsAndServicesVATRate = Undefined Then
			
			TaxValue = "Without VAT";
			ProductsAndServicesVATRate = ExchangeWithSiteReUse.GetByValueForExportingVATRate(TaxValue);
			
		EndIf;
		
		IsService = Lower(XDTOProductsAndServicesType) = "Service";
		ProductsAndServices = FindCreateProductsAndServices(XDTOProduct, IsService, Parameters, ProductsAndServicesVATRate, ErrorDescription);
		
		ProductsAndServicesCharacteristic = FindCreateProductsAndServicesDescription(
			XDTOProduct, 
			IsService, 
			ProductsAndServices, 
			Parameters, 
			ErrorDescription
		);
		
		If Not ValueIsFilled(ProductsAndServices) Then
			Continue;
		EndIf;
		
		If Not XDTOObjectContainsProperty(XDTOProduct, "Quantity") Then 
			Continue;
		EndIf;
		
		Quantity = GetNumberFromString(XDTOProduct.Quantity);
		If Quantity = 0 Then
			Continue;
		EndIf;
		
		Reserve = 0;
		If XDTOObjectContainsProperty(XDTOProduct, "Reserve") Then
			Reserve = GetNumberFromString(XDTOProduct.Reserve);
			If Reserve > Quantity Then
				Reserve = Quantity;
			EndIf;
		EndIf;
		
		PriceForUnit = 0;
		Amount = 0;
		DiscountsAmount = 0;
		
		If XDTOObjectContainsProperty(XDTOProduct, "PriceForUnit") Then
			PriceForUnit = GetNumberFromString(XDTOProduct.PriceForUnit);
		EndIf;
		
		If XDTOObjectContainsProperty(XDTOProduct, "Amount") Then
			Amount = GetNumberFromString(XDTOProduct.Amount);
		EndIf;
		
		If XDTOObjectContainsProperty(XDTOProduct, "Discounts")
			AND XDTOProduct.Discounts <> Undefined
			AND XDTOObjectContainsProperty(XDTOProduct.Discounts, "Discount") Then
			
			XDTODiscountArray = GetArrayOfXDTOListObjects(XDTOProduct.Discounts.Discount);
			For Each XDTODiscount IN XDTODiscountArray Do
				
				If Not XDTOObjectContainsProperty(XDTODiscount, "IncludedInAmount") 
					OR Lower(XDTODiscount.IncludedInAmount = "true") Then
					
					Continue;
					
				EndIf;
				
				DiscountAmount = GetNumberFromString(XDTODiscount.Amount);
				DiscountsAmount = DiscountsAmount + DiscountAmount;
				
			EndDo;
			
		EndIf;
		
		// Add a new row to the Inventory tabular section.
		
		NewRow = DocumentObject.Inventory.Add();
		
		NewRow.ProductsAndServicesTypeInventory = Not IsService;
		NewRow.ProductsAndServices = ProductsAndServices;
		NewRow.MeasurementUnit = ProductsAndServices.MeasurementUnit;
		NewRow.Characteristic = ProductsAndServicesCharacteristic;
		NewRow.Quantity = Quantity;
		NewRow.Reserve = Reserve;
		NewRow.VATRate = ProductsAndServicesVATRate;
		
		NewRow.Amount = ?(DiscountsAmount > 0, Amount - DiscountsAmount, Amount);
		NewRow.Price = ?(PriceForUnit > 0, PriceForUnit, NewRow.Amount / NewRow.Quantity);
		
		RecountTabularSectionRow(NewRow, DocumentObject);
		
	EndDo;
	
	// Discount for the document is distributed between the rows of the tabular section proportionally to the amount.
	
	If XDTOObjectContainsProperty(DocumentXDTO, "Discounts")
		AND DocumentXDTO.Discounts <> Undefined
		AND XDTOObjectContainsProperty(DocumentXDTO.Discounts, "Discount") Then
		
		XDTODiscountArray = GetArrayOfXDTOListObjects(DocumentXDTO.Discounts.Discount);
		For Each XDTODiscount IN XDTODiscountArray Do
			
			If XDTOObjectContainsProperty(XDTODiscount, "Amount") Then
				
				If XDTOObjectContainsProperty(XDTODiscount, "Description")
					AND XDTOObjectContainsProperty(XDTODiscount, "Percent") Then
					
					PercentNumber = GetNumberFromString(XDTODiscount.Percent);
					If PercentNumber <> 0 Then
						
						DocumentObject.DiscountMarkupKind = ExchangeWithSiteReUse.GetDiscountKindOnDocument(XDTODiscount.Description, XDTODiscount.Percent);
						
					EndIf;
					
				EndIf;
				
				If XDTOObjectContainsProperty(XDTODiscount, "IncludedInAmount")
					AND Not Lower(XDTODiscount.IncludedInAmount) = "true" Then
					
					DiscountAmount = GetNumberFromString(XDTODiscount.Amount);
					If DiscountAmount <> 0 Then
						
						DistributeAmountByColumn(DocumentObject, DocumentObject.Inventory, -DiscountAmount);
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	DocumentObject.DocumentAmount = DocumentObject.Inventory.Total("Total");
	
	Return Successfully;
	
EndFunction

Function FindCreateProductsAndServicesDescription(XDTOProduct, IsService, ProductsAndServices, Parameters, ErrorDescription)
	
	ProductsAndServicesCharacteristic = Catalogs.ProductsAndServicesCharacteristics.EmptyRef();
	If IsService OR Not Parameters.UseCharacteristics Then
		Return ProductsAndServicesCharacteristic;
	EndIf;
	
	XDTOProductCharacteristic = Undefined;
	IDCharacteristics = "";
	CharacteristicDescription = "";
	
	If Not Parameters.ExchangeOverWebService Then
		
		If XDTOObjectContainsProperty(XDTOProduct, "ID") AND XDTOPropertyIsFilled(XDTOProduct.ID) Then
			IDCharacteristics = GetCharacteristicIdentifier(XDTOProduct.ID);
		EndIf;
		
		If XDTOObjectContainsProperty(XDTOProduct, "Description") AND XDTOPropertyIsFilled(XDTOProduct.Description) Then
			CharacteristicDescription = GetCharacteristicDescription(XDTOProduct.Description);
		EndIf;
		
	Else
		
		If XDTOObjectContainsProperty(XDTOProduct, "ProductCharacteristics")
			AND XDTOObjectContainsProperty(XDTOProduct.ProductCharacteristics, "ProductCharacteristic") Then
			
			CharacteristicsListProductXDTO = XDTOProduct.ProductCharacteristics.ProductCharacteristic;
			If TypeOf(CharacteristicsListProductXDTO) = Type("XDTOList")
				AND CharacteristicsListProductXDTO.Count() > 0 Then
				
				XDTOProductCharacteristic = CharacteristicsListProductXDTO[0];
				If XDTOObjectContainsProperty(XDTOProductCharacteristic, "ID") AND XDTOPropertyIsFilled(XDTOProductCharacteristic.ID) Then
					IDCharacteristics = XDTOProductCharacteristic.ID;
				EndIf;
				
				If XDTOObjectContainsProperty(XDTOProductCharacteristic, "Description") AND XDTOPropertyIsFilled(XDTOProductCharacteristic.Description) Then
					CharacteristicDescription = XDTOProductCharacteristic.Description;
				EndIf;
				
			EndIf;
		EndIf;
		
	EndIf;
	
	Try
		
		If Not IsBlankString(IDCharacteristics) Then
			
			ProductsAndServicesCharacteristic = Catalogs.ProductsAndServicesCharacteristics.GetRef(New UUID(IDCharacteristics));
			If Not ProductsAndServicesCharacteristic = Catalogs.ProductsAndServicesCharacteristics.EmptyRef()
				AND ProductsAndServicesCharacteristic.GetObject() <> Undefined Then
				
				Return ProductsAndServicesCharacteristic;
			Else
				
				AddErrorDescriptionFull(ErrorDescription,
					NStr("en = 'ProductsAndServices characteristics is not found by the unique ID: '") + IDCharacteristics);
				
			EndIf;
			
		EndIf;
		
	Except
		
		AddErrorDescriptionFull(ErrorDescription,
			ExceptionalErrorDescription(NStr("en = 'Failed to search the ProductAndServices characteristic by the unique ID: '") + IDCharacteristics));
		
	EndTry;
	
	If XDTOPropertyIsFilled(CharacteristicDescription) Then
		ProductsAndServicesCharacteristic = Catalogs.ProductsAndServicesCharacteristics.FindByDescription(CharacteristicDescription, True,, ProductsAndServices);
	Else
		Return ProductsAndServicesCharacteristic;
	EndIf;
	
	If ValueIsFilled(ProductsAndServicesCharacteristic) Then
		Return ProductsAndServicesCharacteristic;
	EndIf;
	
	ProductsAndServicesCharacteristic = Catalogs.ProductsAndServicesCharacteristics.CreateItem();
	ProductsAndServicesCharacteristic.Owner = ProductsAndServices;
	ProductsAndServicesCharacteristic.Description = CharacteristicDescription;
	ProductsAndServicesCharacteristic.Write();
	
	If Parameters.ProductsExchange
		AND Parameters.ExportChangesOnly Then
		
		ExchangePlans.DeleteChangeRecords(Parameters.ExchangeNode, ProductsAndServicesCharacteristic.Ref);
		
	EndIf;
	
	Return ProductsAndServicesCharacteristic.Ref;
	
EndFunction

Function FindCreateProductsAndServices(XDTOProduct, IsService, Parameters, VATRate, ErrorDescription)
	
	ProductAndServices = Catalogs.ProductsAndServices.EmptyRef();
	
	If XDTOObjectContainsProperty(XDTOProduct, "ID") AND XDTOPropertyIsFilled(XDTOProduct.ID) Then
		
		Try
			
			ProductsAndServicesID = GetProductsAndServicesIdentifier(XDTOProduct.ID);
			ProductsAndServices = Catalogs.ProductsAndServices.GetRef(New UUID(ProductsAndServicesID));
			
			If Not ProductsAndServices = Catalogs.ProductsAndServices.EmptyRef()
				AND ProductsAndServices.GetObject() <> Undefined Then
				
				Return ProductsAndServices;
			Else
				
				AddErrorDescriptionFull(ErrorDescription,
					NStr("en = 'ProductsAndServices is not found by UUID: '") + ProductsAndServicesID);
					
			EndIf;
			
		Except
			
			AddErrorDescriptionFull(ErrorDescription,
				ExceptionalErrorDescription(NStr("en = 'Failed to execute item search by UUID: '") + XDTOProduct.ID));
			
		EndTry;
		
	EndIf;
	
	ProductsAndServicesSKU = "";
	ProductsAndServicesDescription = "";
	
	If XDTOObjectContainsProperty(XDTOProduct, "SKU") AND XDTOPropertyIsFilled(XDTOProduct.SKU) Then
		ProductsAndServicesSKU = XDTOProduct.SKU;
	EndIf;
	
	If XDTOObjectContainsProperty(XDTOProduct, "Description") AND XDTOPropertyIsFilled(XDTOProduct.Description) Then
		ProductsAndServicesDescription = GetProductsAndServicesDescription(XDTOProduct.Description);
	EndIf;
	
	ProductsAndServices = FindProductsAndServicesOnSKUName(ProductsAndServicesSKU, ProductsAndServicesDescription);
	If ValueIsFilled(ProductsAndServices) Then
		Return ProductsAndServices;
	EndIf;
	
	UnitToClassifier = GetBaseMeasurementUnitFromXDTOProduct(XDTOProduct);
	ProductsAndServicesType = ?(IsService, Enums.ProductsAndServicesTypes.Service, Enums.ProductsAndServicesTypes.InventoryItem);
	
	ProductsAndServices = Catalogs.ProductsAndServices.CreateItem();
	
	ProductsAndServices.Parent = Parameters.GroupForNewProductsAndServices;
	ProductsAndServices.ProductsAndServicesType = ProductsAndServicesType;
	ProductsAndServices.SKU = ProductsAndServicesSKU;
	ProductsAndServices.Description = ProductsAndServicesDescription;
	ProductsAndServices.DescriptionFull = ProductsAndServicesDescription;
	ProductsAndServices.ProductsAndServicesCategory = Catalogs.ProductsAndServicesCategories.MainGroup;
	
	ProductsAndServices.MeasurementUnit = UnitToClassifier;
	ProductsAndServices.VATRate = VATRate;
	ProductsAndServices.EstimationMethod = Enums.InventoryValuationMethods.ByAverage;
	ProductsAndServices.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
	ProductsAndServices.Warehouse = Catalogs.StructuralUnits.MainWarehouse;
	
	ProductsAndServices.UseCharacteristics = Parameters.UseCharacteristics;
	ProductsAndServices.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
	ProductsAndServices.ExpensesGLAccount = ChartsOfAccounts.Managerial.UnfinishedProduction;
	ProductsAndServices.InventoryGLAccount = ChartsOfAccounts.Managerial.RawMaterialsAndMaterials;
	ProductsAndServices.ReplenishmentDeadline = 1;
	ProductsAndServices.OrderCompletionDeadline = 1;
	
	ProductsAndServices.Write();
	
	If Parameters.ProductsExchange
		AND Parameters.ExportChangesOnly Then
		
		ExchangePlans.DeleteChangeRecords(Parameters.ExchangeNode, ProductsAndServices.Ref);
		
	EndIf;
	
	Return ProductsAndServices.Ref;
	
EndFunction

Function FindProductsAndServicesOnSKUName(SKU, Description)
	
	If ValueIsFilled(SKU) Then
		
		Query = New Query(
		"SELECT ALLOWED TOP 1
		|	ProductsAndServices.Ref
		|FROM
		|	Catalog.ProductsAndServices AS ProductsAndServices
		|WHERE
		|	ProductsAndServices.SKU = &SKU
		|	AND Not ProductsAndServices.IsFolder");
		
		Query.SetParameter("SKU", SKU);
		
	ElsIf ValueIsFilled(Description) Then
		
		Query = New Query(
		"SELECT ALLOWED TOP 1
		|	ProductsAndServices.Ref
		|FROM
		|	Catalog.ProductsAndServices AS ProductsAndServices
		|WHERE
		|	ProductsAndServices.Description = &Description
		|	AND Not ProductsAndServices.IsFolder");
		
		Query.SetParameter("Description", Description);
		
	Else
		Return Undefined;
	EndIf;
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Return Result.Unload()[0][0];
	
EndFunction

Function GetBaseMeasurementUnitFromXDTOProduct(XDTOProduct)
	
	UnitToClassifier = Catalogs.UOMClassifier.pcs;
	
	If XDTOObjectContainsProperty(XDTOProduct.BaseUnit, "Code") Then
		
		CodeBaseUnit = XDTOProduct.BaseUnit.Code;
		If XDTOPropertyIsFilled(CodeBaseUnit) Then
			UnitToClassifier = Catalogs.UOMClassifier.FindByCode(CodeBaseUnit);
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(UnitToClassifier) 
		AND XDTOObjectContainsProperty(XDTOProduct.BaseUnit, "DescriptionFull")
		AND XDTOPropertyIsFilled(XDTOProduct.BaseUnit.DescriptionFull) Then
		
		DescriptionBaseUnit = XDTOProduct.BaseUnit.DescriptionFull;
		UnitToClassifier = Catalogs.UOMClassifier.FindByDescription(DescriptionBaseUnit, True);
		
	EndIf;
	
	Return UnitToClassifier;
	
EndFunction

Procedure RecountTabularSectionRow(TabularSectionRow, Document)
	
	If Not ValueIsFilled(TabularSectionRow.Price)
		AND ValueIsFilled(Document.PriceKind) Then
		
		StructureData = New Structure;
		
		StructureData.Insert("ProcessingDate", Document.Date);
		StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		StructureData.Insert("DocumentCurrency", Document.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Document.AmountIncludesVAT);
		StructureData.Insert("VATRate", TabularSectionRow.VATRate);
		StructureData.Insert("PriceKind", Document.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("DiscountMarkupKind", Document.DiscountMarkupKind);
		
		Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
		TabularSectionRow.Price = Price;
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
		
	EndIf;
	
	AmountWithoutDiscount = TabularSectionRow.Price * TabularSectionRow.Quantity;
	DiscountAmount = AmountWithoutDiscount - TabularSectionRow.Amount;
	
	If DiscountAmount <> 0 Then
		TabularSectionRow.DiscountMarkupPercent = 100 * DiscountAmount / AmountWithoutDiscount;
	EndIf;
	
	CalculateOrderVATSUM(TabularSectionRow, Document);
	
EndProcedure

// Sets the customer order status by matching the order status on the site and order status in the infobase.
//
// Parameters
// DocumentObject - DocumentObject.CustomerOrder - order for which the state is specified.
// OrderProperties - Map - attributes of
// the imported order OrderStatusesConformityTable - ValueTable - table containing the
// 									 site order status matching with the order states in the infobase.
//
Procedure SetOrderStatus(DocumentObject, OrderProperties, TableOfConformityOrderStatuses, Parameters)
	
	If Not Parameters.ExchangeOverWebService Then
		
		StatusValue = OrderProperties["Order state"];
		If Not ValueIsFilled(StatusValue) Then
			Return;
		EndIf;
		
		FoundAccordance = TableOfConformityOrderStatuses.Find(StatusValue, "OrderStatusOnSite");
		If FoundAccordance <> Undefined
			AND ValueIsFilled(FoundAccordance.CustomerOrderStatus) Then
			
			DocumentObject.OrderState = FoundAccordance.CustomerOrderStatus;
			
		EndIf;
		
	Else
		
		OrderStatus = OrderProperties.Get("Order state");
		If OrderStatus <> Undefined
			AND TypeOf(OrderStatus) = Type("String")
			AND OrderStatus <> "" Then
			
			Query = New Query;
			Query.Text = 
			"SELECT ALLOWED TOP 1
			|	CustomerOrderStates.Ref AS OrderState
			|FROM
			|	Catalog.CustomerOrderStates AS CustomerOrderStates
			|WHERE
			|	CustomerOrderStates.Description = &Description
			|	AND Not CustomerOrderStates.DeletionMark";
			
			Query.SetParameter("Description", OrderStatus);
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				DocumentObject.OrderState = Selection.OrderState;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Receives customer orders having Canceled attribute with True value in additional information set.
//
// Parameters
// OrdersArray - Array containing references to orders.
//
// The
// return value is Array containing references to cancelled orders.
//
Function GetCanceledOrders(OrdersArray)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AdditionalInformation.Object AS CustomerOrder
	|FROM
	|	InformationRegister.AdditionalInformation AS AdditionalInformation
	|		INNER JOIN Catalog.AdditionalAttributesAndInformationSets.AdditionalInformation AS SetsAdditionalDetailsAndAdditionalInformationAdditionalInformation
	|		ON AdditionalInformation.Property = SetsAdditionalDetailsAndAdditionalInformationAdditionalInformation.Property
	|			AND (SetsAdditionalDetailsAndAdditionalInformationAdditionalInformation.Ref = VALUE(Catalog.AdditionalAttributesAndInformationSets.Document_CustomerOrder))
	|WHERE
	|	AdditionalInformation.Object IN(&OrdersArray)
	|	AND AdditionalInformation.Property.Description = ""Canceled""
	|	AND AdditionalInformation.Value = ""true""";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	
	Result = Query.Execute().Unload().UnloadColumn("CustomerOrder");
	
	Return Result;
	
EndFunction

// Exports the file with the orders to the site.
//
// Parameters:
// Parameters			- Structure,
// main StatisticsStructure parameters	- Structure
// ErrorDescription		- String
//
// Returns:
// Boolean				- True if success.
//
Function ExportOrdersToSite(Parameters, StatisticsStructure, ErrorDescription)
	
	If Not ClearDirectory(Parameters.DirectoryOnHardDisk, ErrorDescription) Then
		Return False;
	EndIf;
	
	If Not ExportOrdersIntoFile(Parameters, StatisticsStructure, ErrorDescription) Then
		Return False;
	EndIf;
	
	If StatisticsStructure.Exported.Count() = 0 Then
		Return True;
	EndIf;
	
	Successfully = ImportToSite(Parameters, , ErrorDescription, , "sale");
	
	If Not ClearDirectory(Parameters.DirectoryOnHardDisk, ErrorDescription) Then
		Return False;
	EndIf;
	
	Return Successfully;
	
EndFunction

// Imports customer orders to the file.
//
// Parameters:
// Parameters			- Structure,
// main StatisticsStructure parameters	- Structure
// ErrorDescription		- String
//
// Returns:
// Boolean				- True if success.
//
Function ExportOrdersIntoFile(Parameters, StatisticsStructure, ErrorDescription)
	
	ChangesArray = New Array;
	
	If Parameters.ExportChangesOnly
		AND Not Parameters.PerformFullExportingCompulsorily Then
		
		ChangesArray = Parameters.ChangesStructure.Orders;
		
		For Each Item IN StatisticsStructure.Exported Do
			ItemIndex = ChangesArray.Find(Item);
			If ItemIndex <> Undefined Then
				ChangesArray.Delete(ItemIndex);
			EndIf;
		EndDo;
		
		If ChangesArray.Count() = 0 Then
			Return True;
		EndIf;
		
	EndIf;
	
	XDTODocuments = GenerateXDTOOrders(ChangesArray, StatisticsStructure, Parameters);
	
	If StatisticsStructure.Exported.Count() = 0 Then
		Return True;
	EndIf;
	
	ExchangeFileName = "orders-" + String(New UUID) + ".xml";
	ExchangeFileFullName = PreparePathForPlatform(Parameters.WindowsPlatform, Parameters.DirectoryOnHardDisk + "\" + ExchangeFileName);
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(ExchangeFileFullName, "UTF-8");
	XMLWriter.WriteXMLDeclaration();
	
	Try
		
		XDTODocuments.Validate();
		
		XDTOFactory.WriteXML(XMLWriter, XDTODocuments, "BusinessInformation");
		XMLWriter.Close();
		
	Except
		
		AddErrorDescriptionFull(ErrorDescription,
			ExceptionalErrorDescription(NStr("en = 'Failed to record XML-file on disc: '")
				+ ExchangeFileFullName + Chars.LF + ErrorDescription()));
				
		StatisticsStructure.Exported.Clear();
		
		Return False;
		
	EndTry;
	
	Return True;
	
EndFunction

// Returns the XDTO Object of the BusinessInformation type with the completed document list.
//
// Parameters
// ChangesArray - array containing changes of
// the customer orders StatisticsStructure - structure to record statistics of
// the order exporting Parameters - structure containing exchange parameters
//
// Return
// value XDTO Object of the BusinessInformation type.
//
Function GenerateXDTOOrders(ChangesArray, StatisticsStructure, Parameters) Export
	
	ResultsArray = GetOrdersWithPaymentAndShipment(ChangesArray, StatisticsStructure.Exported, Parameters);
	
	DocumentsSelection = ResultsArray[6].Select();
	
	If DocumentsSelection.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	CharacteristicPropertiesTree = ResultsArray[7].Unload(QueryResultIteration.ByGroups);
	
	NamespaceURI = "urn:1C.ru:commerceml_205";
	CMLPackage = XDTOFactory.packages.Get(NamespaceURI);
	
	BusinessInformationType = CMLPackage.Get("BusinessInformation");
	BusinessInformationXTDO = XDTOFactory.Create(BusinessInformationType);
	
	BusinessInformationXTDO.SchemaVersion = "2.05";
	BusinessInformationXTDO.GeneratingDate = Parameters.GeneratingDate;
	
	While DocumentsSelection.Next() Do
		
		If Not ValueIsFilled(DocumentsSelection.OrderNumberOnSite)
			OR Not ValueIsFilled(DocumentsSelection.OrderDateOnSite) Then
			Continue;
		EndIf;
		
		StatisticsStructure.Exported.Add(DocumentsSelection.CustomerOrder);
		
		DocumentType = CMLPackage.Get("Document");
		DocumentXDTO = XDTOFactory.Create(DocumentType);
		
		DocumentXDTO.ID = String(DocumentsSelection.CustomerOrder.UUID());
		DocumentXDTO.Number = DocumentsSelection.OrderNumberOnSite;
		DocumentXDTO.Date = DocumentsSelection.OrderDateOnSite;
		DocumentXDTO.BusinessTransaction = "Product order";
		DocumentXDTO.Role = "Seller";
		DocumentXDTO.Currency = CurrencyFormatForXDTO(DocumentsSelection.Currency);
		DocumentXDTO.ExchangeRate = DocumentsSelection.ExchangeRate;
		DocumentXDTO.Amount = DocumentsSelection.DocumentAmount;
		DocumentXDTO.Time = DocumentsSelection.OrderDateOnSite;
		DocumentXDTO.PaymentDueDate = DocumentsSelection.PaymentDate;
		
		Comment = Left(DocumentsSelection.Comment, 3000);
		If Not IsBlankString(Comment) Then
			DocumentXDTO.Comment = Comment;
		EndIf;
		
		XDTOCounterparties = XDTOFactory.Create(GetPropertyTypeFromXDTOObjectType(DocumentType, "Counterparties"));
		
		XDTOCounterparty = GetXDTOCounterparty(DocumentsSelection, CMLPackage);
		XDTOCounterparties.Counterparty.Add(XDTOCounterparty);
		
		DocumentXDTO.Counterparties = XDTOCounterparties;
		
		AddXDTOOrderProducts(DocumentXDTO, CMLPackage, DocumentsSelection, CharacteristicPropertiesTree, Parameters);
		
		AddXDTOOrderAttributeValue(DocumentXDTO, CMLPackage, DocumentsSelection, Parameters);
		
		BusinessInformationXTDO.Document.Add(DocumentXDTO);
		
	EndDo;
	
	Return BusinessInformationXTDO;
	
EndFunction

// Creates a sample with orders for exporting.
//
// Parameters:
// ChangesArray - array with orders recorded for the
// ImportedDocumentsArray exchange plan node - array of just imported orders
//
// Returns:
// Filter from the query result
//
Function GetOrdersWithPaymentAndShipment(ChangesArray, ImportedDocumentsArray, Parameters)
	
	CompositionSchema = ExchangePlans.ExchangeSmallBusinessSite.GetTemplate("OrdersExportSchema");
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(CompositionSchema)); 
	SettingsComposer.LoadSettings(CompositionSchema.DefaultSettings);
	
	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("OrderStatusInProcess");
	DCSParameter.Value = Parameters.OrderStatusInProcess;
	DCSParameter.Use = True;
	
	If ChangesArray.Count() > 0 Then
		
		// Select only modified ones.
		AddFilterByOrders(SettingsComposer, ChangesArray, DataCompositionComparisonType.InList);
		
	EndIf;
	
	If ImportedDocumentsArray.Count() > 0 Then
		
		// Exclude only just imported ones.
		AddFilterByOrders(SettingsComposer, ImportedDocumentsArray, DataCompositionComparisonType.NotInList);
		
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer();
	DataCompositionTemplate = TemplateComposer.Execute(CompositionSchema, SettingsComposer.GetSettings(),,,Type("DataCompositionValueCollectionTemplateGenerator"));
	Query = New Query(DataCompositionTemplate.DataSets.MainDataSet.Query);
	
	For Each Parameter IN DataCompositionTemplate.ParameterValues Do
		Query.Parameters.Insert(Parameter.Name, Parameter.Value);
	EndDo;
	
	Query.Text = Query.Text + Chars.LF + ";" + Chars.LF
		+ "SELECT ALLOWED DISTINCT
		|	ProductsAndServicesCharacteristicsAdditionalAttributes.Ref AS Characteristic,
		|	ProductsAndServicesCharacteristicsAdditionalAttributes.Property AS Property,
		|	ProductsAndServicesCharacteristicsAdditionalAttributes.Property.Description AS Description,
		|	ProductsAndServicesCharacteristicsAdditionalAttributes.Value AS Value
		|FROM
		|	Catalog.ProductsAndServicesCharacteristics.AdditionalAttributes AS ProductsAndServicesCharacteristicsAdditionalAttributes
		|		INNER JOIN Document.CustomerOrder.Inventory AS CustomerOrderProducts
		|			INNER JOIN TemporaryTableOrders AS TemporaryTableOrders
		|			ON CustomerOrderProducts.Ref = TemporaryTableOrders.CustomerOrder
		|		ON ProductsAndServicesCharacteristicsAdditionalAttributes.Ref = CustomerOrderProducts.Characteristic
		|TOTALS BY
		|	Characteristic";
	
	ResultsArray = Query.ExecuteBatch();
	Return ResultsArray;
	
EndFunction

// Adds filter to the builder settings.
//
// Parameters:
// SettingsComposer - DataTemplateSettingsBuilder
// RestrictionArray - ComparisonType
// filter values - DataCompositionComparisonType.
//
Procedure AddFilterByOrders(SettingsComposer, RestrictionArray, ComparisonType)
	
	Filter = SettingsComposer.Settings.Filter;
	
	NewItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
	NewItem.LeftValue =  New DataCompositionField("CustomerOrder");
	NewItem.ComparisonType = ComparisonType;
	RestrictionValuesList = New ValueList;
	RestrictionValuesList.LoadValues(RestrictionArray);
	NewItem.RightValue = RestrictionValuesList;
	NewItem.Use = True;
	
EndProcedure

// Fills in the lists of XDTO Products and XDTO object Taxes of the Document type.
//
// Parameters
// DocumentXDTO - XDTO object of
// Document type CMLPackage - XDTO package containing
// CML types DocumentSample - sample containing customers
// order data CharacteristicPropertiesTree - value tree containing characteristic properties.
// Parameters - structure containing exchange parameters.
//
Procedure AddXDTOOrderProducts(DocumentXDTO, CMLPackage, DocumentsSelection, CharacteristicPropertiesTree, Parameters)
	
	ProductsSelection = DocumentsSelection.Products.Select();
	If ProductsSelection.Count() = 0 Then
		Return;
	EndIf;
	
	ProductsType = GetPropertyTypeFromXDTOObjectType(DocumentXDTO.Type(), "Products");
	ProductType = GetPropertyTypeFromXDTOObjectType(ProductsType, "Product");
	
	TaxesInXDTODocument = XDTOFactory.Create(GetPropertyTypeFromXDTOObjectType(DocumentXDTO.Type(), "Taxes"));
	XDTOProducts = XDTOFactory.Create(ProductsType);
	
	CountVAT = DocumentsSelection.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
	VATAmount = 0;
	
	While ProductsSelection.Next() Do
		
		XDTOProduct = XDTOFactory.Create(ProductType);
		XDTOPrice  = XDTOFactory.Create(CMLPackage.Get("Price"));
		
		XDTOBaseMeasurementUnit = XDTOFactory.Create(CMLPackage.Get("BaseUnit"));
		
		Characteristic = Undefined;
		If Parameters.UseCharacteristics Then
			Characteristic = ProductsSelection.Characteristic;
		EndIf;
		
		ProductId = ExchangeWithSiteReUse.GenerateObjectUUID(ProductsSelection.ProductsAndServices, Characteristic);
		
		XDTOProduct.ID = ProductId;
		XDTOProduct.SKU = ProductsSelection.SKU;
		XDTOProduct.Description = DescriptionFormatForXDTO(ProductsSelection.ProductsAndServices);
		XDTOProduct.BaseUnit = GetXDTOBaseUnit(CMLPackage, ProductsSelection);
		XDTOProduct.PriceForUnit = ProductsSelection.Price;
		XDTOProduct.Quantity = ProductsSelection.Quantity;
		XDTOProduct.Amount = ProductsSelection.Amount;
		
		XDTOProduct.Unit = String(ProductsSelection.MeasurementUnit);
		XDTOProduct.Factor = 1;
		
		If ProductsSelection.VATAmount > 0 Then
			
			XDTOProductTaxes = XDTOFactory.Create(GetPropertyTypeFromXDTOObjectType(ProductType, "Taxes"));
			XDTOProductTax = XDTOFactory.Create(CMLPackage.Get("TaxInDocument"));
			
			XDTOProductTax.Description = Parameters.DescriptionTax;
			XDTOProductTax.IncludedInAmount = DocumentsSelection.AmountIncludesVAT;
			XDTOProductTax.Amount = ProductsSelection.VATAmount;
			XDTOProductTax.Rate = ExchangeWithSiteReUse.GetValueForExportingByVATRate(ProductsSelection.VATRate);
			
			XDTOProductTaxes.Tax.Add(XDTOProductTax);
			XDTOProduct.Taxes = XDTOProductTaxes;
			
			If CountVAT Then
				
				VATAmount = VATAmount + ProductsSelection.VATAmount;
				
			EndIf;
			
		EndIf;
		
		DiscountMarkupPercent = ProductsSelection.DiscountMarkupPercent;
		
		If DiscountMarkupPercent <> 0 Then
			
			DiscountAmount = ProductsSelection.Quantity * ProductsSelection.Price - ProductsSelection.Amount;
			
			XDTOProductDiscounts = XDTOFactory.Create(GetPropertyTypeFromXDTOObjectType(ProductType, "Discounts"));
			XDTOProductDiscount = XDTOFactory.Create(CMLPackage.Get("Discount"));
			
			XDTOProductDiscount.Description = String(DiscountMarkupPercent);
			XDTOProductDiscount.Percent = GetNumberFromString(Format(DiscountMarkupPercent, "ND=5; NFD=2"));
			XDTOProductDiscount.Amount = GetNumberFromString(Format(DiscountAmount, "ND=15; NFD=2"));
			XDTOProductDiscount.IncludedInAmount = "true";
			
			XDTOProductDiscounts.Discount.Add(XDTOProductDiscount);
			XDTOProduct.Discounts = XDTOProductDiscounts;
			
		EndIf;
		
		If ValueIsFilled(ProductsSelection.VATRate) AND Not ProductsSelection.VATRate.NotTaxable Then
			
			XDTOTaxesRates = XDTOFactory.Create(GetPropertyTypeFromXDTOObjectType(ProductType, "TaxesRates"));
			XDTOTaxRate = XDTOfactory.Create(CMLPackage.Get("TaxRate"));
			
			XDTOTaxRate.Description = Parameters.DescriptionTax;
			XDTOTaxRate.Rate = ExchangeWithSiteReUse.GetValueForExportingByVATRate(ProductsSelection.VATRate);
			
			XDTOTaxesRates.TaxRate.Add(XDTOTaxRate);
			
			XDTOProduct.TaxesRates = XDTOTaxesRates;
			
		EndIf;
		
		AttributeValuesXDTO = XDTOFactory.Create(GetPropertyTypeFromXDTOObjectType(ProductType, "AttributeValues"));
		
		ProductsAndServicesKind = ?(ProductsSelection.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem, "Product", "Service");
		
		AddXDTOAttributeValue(AttributeValuesXDTO, CMLPackage, "ProductsAndServicesKind", ProductsAndServicesKind);
		AddXDTOAttributeValue(AttributeValuesXDTO, CMLPackage, "ProductsAndServicesType", String(ProductsSelection.ProductsAndServicesType));
		
		XDTOProduct.AttributeValues = AttributeValuesXDTO;
		
		If Parameters.UseCharacteristics Then
			ExportPropertiesCharacteristicsForProductXDTO(CMLPackage, XDTOProduct, ProductType, ProductsSelection.Characteristic, CharacteristicPropertiesTree, Parameters);
		EndIf;
		
		XDTOProducts.Product.Add(XDTOProduct);
		
	EndDo;
	
	TaxDocumentXDTO = XDTOFactory.Create(CMLPackage.Get("TaxInDocument"));
	
	TaxDocumentXDTO.Description = Parameters.DescriptionTax;
	TaxDocumentXDTO.IncludedInAmount = DocumentsSelection.AmountIncludesVAT;
	TaxDocumentXDTO.Amount = VATAmount;
	
	TaxesInXDTODocument.Tax.Add(TaxDocumentXDTO);
	
	DocumentXDTO.Taxes = TaxesInXDTODocument;
	DocumentXDTO.Products = XDTOProducts;
	
EndProcedure

// Fills in characteristic attributes for the XDTO object of the Product type.
//
// Parameters
// XDTOProduct - XDTO object of
// the Product type ProductType - XDTO object type
// Product Characteristic - products
// and services characteristic CharacteristicPropertiesTree - value tree containing characteristic properties.
//
Procedure ExportPropertiesCharacteristicsForProductXDTO(CMLPackage, XDTOProduct, ProductType, Characteristic, CharacteristicPropertiesTree, Parameters)
	
	If Not ValueIsFilled(Characteristic) Then
		Return;
	EndIf;
	
	Found = CharacteristicPropertiesTree.Rows.Find(Characteristic, "Characteristic");
	
	If Found = Undefined Then
		Return;
	EndIf;
	
	ProductCharacteristicsType = GetPropertyTypeFromXDTOObjectType(ProductType, "ProductCharacteristics");
	XDTOProductCharacteristics = XDTOFactory.Create(ProductCharacteristicsType);
	
	If Not Parameters.ExchangeOverWebService Then
		
		For Each PropertyString IN Found.Rows Do
			
			If Not ValueIsFilled(PropertyString.Value)
				OR Not ValueIsFilled(PropertyString.Property) Then
				
				Continue;
				
			EndIf;
			
			XDTOProductCharacteristic = XDTOFactory.Create(GetPropertyTypeFromXDTOObjectType(ProductCharacteristicsType, "ProductCharacteristic"));
			
			XDTOProductCharacteristic.Description = DescriptionFormatForXDTO(PropertyString.Property);
			XDTOProductCharacteristic.Value = String(PropertyString.Value);
			
			XDTOProductCharacteristics.ProductCharacteristic.Add(XDTOProductCharacteristic);
			
		EndDo;
		
	Else
		
		XDTOProductCharacteristic = XDTOFactory.Create(GetPropertyTypeFromXDTOObjectType(ProductCharacteristicsType, "ProductCharacteristic"));
		
		XDTOProductCharacteristic.ID = String(Characteristic.UUID());
		XDTOProductCharacteristic.Description = DescriptionFormatForXDTO(Characteristic.Description);
		
		PropertyValuesType = XDTOProductCharacteristic.Properties().Get("PropertyValues").Type;
		XDTOPropertiesValues = XDTOFactory.Create(PropertyValuesType);
		
		For Each PropertyString IN Found.Rows Do
			
			If Not ValueIsFilled(PropertyString.Property)
				OR Not ValueIsFilled(PropertyString.Value) Then
				
				Continue;
				
			EndIf;
			
			XDTOPropertyValues = XDTOFactory.Create(CMLPackage.Get("PropertyValues"));
			XDTOPropertyValues.ID = String(PropertyString.Property.UUID());
			XDTOPropertyValues.Description = DescriptionFormatForXDTO(PropertyString.Description);
			
			If PropertyString.Value = NULL Then
				
				// If the attribute value is not filled, we export the empty string.
				PropertyValue = "";
				
			Else
				
				PropertyValueType = TypeOf(PropertyString.Value);
				If PropertyValueType = Type("Date") Then
					
					PropertyValue = DateFormatForXDTO(PropertyString.Value);
					
				Else
					
					PropertyValue = String(PropertyString.Value);
					
				EndIf;
				
			EndIf;
			
			XDTOPropertyValues.Value.Add(PropertyValue);
			XDTOPropertiesValues.PropertyValues.Add(XDTOPropertyValues);
			
		EndDo;
		
		If XDTOPropertiesValues.PropertyValues.Count() > 0 Then
			XDTOProductCharacteristic.PropertyValues = XDTOPropertiesValues;
		EndIf;
		
		XDTOProductCharacteristics.ProductCharacteristic.Add(XDTOProductCharacteristic);
		
	EndIf;
	
	XDTOProductCharacteristics.ProductCharacteristic.Add(XDTOProductCharacteristic);
	XDTOProduct.ProductCharacteristics = XDTOProductCharacteristics;
	
EndProcedure

// Fills in additional attribute values for the XDTO object of the Document type.
//
// Parameters
// DocumentXDTO - XDTO object of Document type
// CMLPackage - XDTO package containing CML types 
// DocumentData - sample containing customer order data
// Parameters - structure containing exchange parameters.
//
Procedure AddXDTOOrderAttributeValue(DocumentXDTO, CMLPackage, DocumentData, Parameters)
	
	AttributeValuesXDTO = XDTOFactory.Create(DocumentXDTO.Properties().Get("AttributeValues").Type);
	
	AddXDTOAttributeValue(AttributeValuesXDTO, CMLPackage, "Number by 1C", DocumentData.Number);
	AddXDTOAttributeValue(AttributeValuesXDTO, CMLPackage, "Date by 1C", DateFormatForXDTO(DocumentData.Date, True, True));
	AddXDTOAttributeValue(AttributeValuesXDTO, CMLPackage, "DeletionMark", DocumentData.DeletionMark);
	AddXDTOAttributeValue(AttributeValuesXDTO, CMLPackage, "Posted", DocumentData.Posted);
	
	If DocumentData.Posted 
		AND DocumentData.OrderStatus <> Enums.OrderStatuses.Open 
		AND DocumentData.BalanceForPayment <= 0 Then
		
		AddXDTOAttributeValue(AttributeValuesXDTO, CMLPackage, "Payment number by 1C", DocumentData.PaymentNo);
		AddXDTOAttributeValue(AttributeValuesXDTO, 
			CMLPackage, "Payments date by 1C", DateFormatForXDTO(DocumentData.PayDate, True, True));
		
	EndIf;
	
	If DocumentData.Posted 
		AND DocumentData.OrderStatus <> Enums.OrderStatuses.Open
		AND DocumentData.ResidueForShipment <= 0 Then
		
		AddXDTOAttributeValue(AttributeValuesXDTO, CMLPackage, "Shipment number by 1C", DocumentData.ShipmentNo);
		AddXDTOAttributeValue(AttributeValuesXDTO, 
			CMLPackage, "Shipment date by 1C", DateFormatForXDTO(DocumentData.ShipmentDate, True, True));
		
	EndIf;
	
	If DocumentData.Closed
		AND DocumentData.OrderState = Parameters.OrderStatusInProcess Then
		
		AddXDTOAttributeValue(AttributeValuesXDTO, CMLPackage, "Canceled", "true");
		
	EndIf;
	
	DocumentXDTO.AttributeValues = AttributeValuesXDTO;
	
EndProcedure

Procedure WriteOrdersInformationIntoInformationTable(InformationTable, StartDate, Action, Success, StatisticsStructure, ErrorDescription);
	
	InformationTableRow = InformationTable.Add();
	InformationTableRow.StartDate = StartDate; 
	InformationTableRow.EndDate = CurrentDate();
	InformationTableRow.ActionOnExchange = Action;
	
	If Action = Enums.ActionsAtExchange.DataImport Then
		
		Definition = String(StartDate) + " " + NStr("en = 'Run orders import'")
			+ Chars.LF + NStr("en = 'Processed: '") + StatisticsStructure.ProcessedOnImport
			+ Chars.LF + NStr("en = 'Imported: '") + StatisticsStructure.Exported.Count();
		
		DisplayListOfDocumentsForLog(Definition, StatisticsStructure.Exported);
		
		Definition = Definition
			+ Chars.LF + NStr("en = 'Skipped: '") + StatisticsStructure.Skipped.Count();
		
		DisplayListOfDocumentsForLog(Definition, StatisticsStructure.Skipped);
		
		Definition = Definition
			+ Chars.LF + NStr("en = 'Updated: '") + StatisticsStructure.Updated.Count();
		
		DisplayListOfDocumentsForLog(Definition, StatisticsStructure.Updated);
		
		Definition = Definition
			+ Chars.LF + NStr("en = 'Created: '") + StatisticsStructure.Created.Count();
		
		DisplayListOfDocumentsForLog(Definition, StatisticsStructure.Created);
		
		Definition = Definition
			+ Chars.LF
			+ InformationTableRow.EndDate
			+ " "
			+ NStr("en = 'Orders import ended'");
			
	Else
		
		Definition = String(StartDate) + " " + NStr("en = 'Run orders export'")
			+ Chars.LF + NStr("en = 'Exported: '") + StatisticsStructure.Exported.Count();
		
		DisplayListOfDocumentsForLog(Definition, StatisticsStructure.Exported);
		
		Definition = Definition
			+ Chars.LF
			+ InformationTableRow.EndDate
			+ " "
			+ NStr("en = 'Orders export ended'");
	
	EndIf;
	
	InformationTableRow.Definition = Definition;
	
	If Success Then
		InformationTableRow.ExchangeProcessResult = Enums.ExchangeExecutionResult.Completed;
	Else
		InformationTableRow.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
	EndIf;
	
	If IsBlankString(ErrorDescription) Then
		Return;
	EndIf;
	
	InformationTableRow.Definition = InformationTableRow.Definition
		+ Chars.LF + NStr("en = 'Additional information:'") + Chars.LF + ErrorDescription;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

// Receives a structure containing the main exchange parameters.
//
Function GetMainExchangeParametersStructure() Export
	
	MainParameters = New Structure;
	
	User = Users.CurrentUser();
	MainCompany = SmallBusinessReUse.GetValueByDefaultUser(User, "MainCompany");
	
	If Not ValueIsFilled(MainCompany) Then 
		MainCompany = Catalogs.Companies.MainCompany;
	EndIf;
	
	MainParameters.Insert("CompanyFolderOwner", MainCompany);
	
	PermittedProductsAndServicesTypes = New Array;
	PermittedProductsAndServicesTypes.Add(Enums.ProductsAndServicesTypes.InventoryItem);
	PermittedProductsAndServicesTypes.Add(Enums.ProductsAndServicesTypes.Service);
	PermittedProductsAndServicesTypes.Add(Enums.ProductsAndServicesTypes.Work);
	
	MainParameters.Insert("PermittedProductsAndServicesTypes", PermittedProductsAndServicesTypes); 
	
	PermittedPictureTypes = New Array;
	PermittedPictureTypes.Add("gif");
	PermittedPictureTypes.Add("jpg");
	PermittedPictureTypes.Add("jpeg");
	PermittedPictureTypes.Add("png");
	
	MainParameters.Insert("PermittedPictureTypes", PermittedPictureTypes);
	
	GeneratingDate = CurrentDate();
	
	MainParameters.Insert("GeneratingDate", GeneratingDate);
	MainParameters.Insert("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));
	MainParameters.Insert("CurrencyTransactionsAccounting", GetFunctionalOption("CurrencyTransactionsAccounting"));
	MainParameters.Insert("DescriptionTax", NStr("en = 'VAT'"));
	
	Return MainParameters;

EndFunction // GetMainExchangeParametersStructure()

// Generates InternetProxy object by proxy settings.
//
// Parameters:
// Proxy		- Map -
// 				keys:
// 				BypassProxyOnLocal - String - 
// 				Server			- proxy
// 				server address Port			- proxy
// 				server port User	- user name for authorization on
// 				the proxy server Password			- user
// password Protocol	- String - protocol for which we specify the proxy server parameters.
// 				For example: http, https, ftp.
//
Function GenerateProxy(ProxySettings, Protocol) Export
	
	Proxy = New InternetProxy;
	
	Proxy.BypassProxyOnLocal = ProxySettings["BypassProxyOnLocal"];
	Proxy.Set(Protocol, ProxySettings["Server"], ProxySettings["Port"]);
	Proxy.User = ProxySettings["User"];
	Proxy.Password = ProxySettings["Password"];
	
	Return Proxy;
	
EndFunction

// It creates the structure of the site connection
// parameters by the exchange setting taking into account proxy parameters.
//
// Parameters:
// ExchangeNode - ExchangePlanRef.ExchangeSmallBusinessSite
// ConnectionSettings - Settings structure of connection to the site 
// ErrorDescription - String
//
// Returns:
// Boolean - True if success.
//
Function GetConnectionSettings(ExchangeNode, ConnectionSettings, ErrorDescription)
	
	ConnectionSettings.Insert("User", ExchangeNode.UserName);
	ConnectionSettings.Insert("Password", ExchangeNode.Password);
	
	ErrorDescription = "";
	If Not AnalyzeSiteAddress(ExchangeNode.SiteAddress, ConnectionSettings, ErrorDescription) Then
		Return False;
	EndIf;
	
	ProxyServerSetting = GetFilesFromInternet.ProxySettingsOnServer();
	
	If ProxyServerSetting <> Undefined
		AND ProxyServerSetting["UseProxy"] = False Then
		
		ProxyServerSetting = Undefined;
	EndIf;
	
	Protocol = ?(ConnectionSettings.SecureConnection, "https", "http");
	Proxy = ?(ProxyServerSetting = Undefined, Undefined, GenerateProxy(ProxyServerSetting, Protocol));
	
	ConnectionSettings.Insert("Proxy", Proxy);
	
	Return True;
	
EndFunction

Function SetConnectionWithServer(ConnectionParameters, ErrorDescription)
	
	Join = Undefined;
	
	Try
		
		If ConnectionParameters.SecureConnection Then
			
			ssl = New OpenSSLSecureConnection();
			
			Join = New HTTPConnection(
				ConnectionParameters.Server,
				ConnectionParameters.Port,
				ConnectionParameters.User,
				ConnectionParameters.Password,
				ConnectionParameters.Proxy,
				1800,
				ssl
			);
			
		Else
			
			Join = New HTTPConnection(
				ConnectionParameters.Server,
				ConnectionParameters.Port,
				ConnectionParameters.User,
				ConnectionParameters.Password,
				ConnectionParameters.Proxy,
				1800
			);
			
		EndIf;
		
	Except
		
		AddErrorDescriptionFull(ErrorDescription,
			ExceptionalErrorDescription(
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Failed to connect the server %1:%2. Verify the correctness of the address server, port, user name and a password.'"),
				ConnectionParameters.Server,
				ConnectionParameters.Port)
			)
		);
		
		Join = Undefined;
		
	EndTry;
	
	Return Join;
	
EndFunction

Function PerformAuthorizationForConnection(Join, ConnectionParameters, 
	
	ServerResponse, ErrorDescription, ConnectionType = "catalog")
	
	Join = SetConnectionWithServer(ConnectionParameters, ErrorDescription);
	
	If Join = Undefined Then
		
		AddErrorDescriptionFull(ErrorDescription, NStr("en = 'Authorization not executed.'"));
		Return False;
		
	EndIf;
	
	ErrorDescription = "";
	ServerResponse = GetDataFromServer(
		Join, 
		ConnectionParameters.AddressOfScript + "?type=" + ConnectionType + "&mode=checkauth",,
		ErrorDescription
	);
	
	If ServerResponse = Undefined Then 
		
		AddErrorDescriptionFull(ErrorDescription, NStr("en = 'Authorization not executed.'"));
		Return False;
		
	EndIf;
	
	If TrimAll(Lower(StrGetLine(ServerResponse, 1))) <> "success" Then
		
		AddErrorDescriptionFull(ErrorDescription, NStr("en = 'Authorization not executed.'")
			+ Chars.LF 
			+ NStr("en = 'Failed to set connection with the server. Verify user name and password.'"));
			
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

// Imports files to the site.
//
// Parameters:
// Parameters								- Structure, main parameters
// SubdirectoryArray 						- Array
// ErrorDescription							- String
// ExpectFileImportCompletionByServer	- Boolean
// ConnectionType							- String
//
// Returns:
// Boolean				- True if success.
//
Function ImportToSite(Parameters,
						ArrayOfSubdirectories = Undefined,
						ErrorDescription,
						ExpectFileImportCompletionByServer = False,
						ConnectionType = "catalog")
	
	ServerResponse = "";
	Join = Undefined;
	ConnectionSettings = Parameters.ConnectionSettings;
	
	AddressForWork = ConnectionSettings.AddressOfScript + "?type=" + ConnectionType; 
	
	ErrorDescription = "";
	Successfully = PerformAuthorizationForConnection(Join, ConnectionSettings, ServerResponse, ErrorDescription, ConnectionType);
	
	If Not Successfully Then
		AddErrorDescriptionFull(ErrorDescription, NStr("en = 'Import to site has not been performed.'"));
		Return False;
	EndIf;
	
	CookiesName				= StrGetLine(ServerResponse, 2);
	CookieValue		= StrGetLine(ServerResponse, 3);
	RequestsTitles	= "Cookie: " + CookiesName + "=" + CookieValue;
	
	ErrorDescription = "";
	ServerResponse = GetDataFromServer(
		Join,
		AddressForWork + ConnectionSettings.HTTPQueryParameter_Initialization,
		RequestsTitles,
		ErrorDescription
	);
	
	If ServerResponse = Undefined Then 
		
		AddErrorDescriptionFull(ErrorDescription, NStr("en = 'Import to site has not been performed.'"));
		Return False;
		
	EndIf;
	
	ZIPFilesAllowed = False;
	ExchangeFileFragmentSizeLimit = 0;
	
	If StrLineCount(ServerResponse) <> 2 Then
		
		AddErrorDescriptionFull(ErrorDescription, NStr("en = 'Import to site has not been performed.'") + Chars.LF + NStr("en = 'Failed to read the server reply. Exchange parameters have not been received.'"));
		Return False;
		
	EndIf;
	
	ZIPFilesAllowed = TrimAll(Lower(StrGetLine(ServerResponse, 1))) = ConnectionSettings.ServerResponse_ZIPIsAllowed;
	
	Try 
		
		ExchangeFileFragmentSizeLimit = Number(StrReplace(TrimAll(Lower(StrGetLine(ServerResponse, 2))),
			ConnectionSettings.ServerResponse_ExchangeFileFragmentSizeLimit, ""));
		
	Except
		
		AddErrorDescriptionFull(ErrorDescription,
			ExceptionalErrorDescription(NStr("en = 'Exhange parameters receiving error (file size limitation)!'")));
		
		ExchangeFileFragmentSizeLimit = -1;
		
	EndTry;
	
	SourceXMLFilesArray = FindFiles(Parameters.DirectoryOnHardDisk, "*.xml");
	FileListToSend = GetFileListToSend(Parameters.DirectoryOnHardDisk, ArrayOfSubdirectories);
	
	If ZIPFilesAllowed Then
		FileListToSend = PrepareZIPArchives(Parameters.DirectoryOnHardDisk, ErrorDescription);
		
		If FileListToSend.Count() = 0 Then
			Return False;
		EndIf;
		
	EndIf;
	
	If ExchangeFileFragmentSizeLimit > 0 Then
		
		FileListToSend = SplitFilesToFragments(FileListToSend, ExchangeFileFragmentSizeLimit);
		
	EndIf;
	
	TotalFiles = FileListToSend.Count();
	
	HasErrors = False;
	For Each CurFile IN FileListToSend Do
		
		ServerResponse = SendFileToServer(CurFile.Value,
			Join,
			AddressForWork + ConnectionSettings.HTTPQueryParameter_FileTransfer + CurFile.Presentation,
			RequestsTitles,
			ErrorDescription
		);
		
		If ServerResponse = Undefined Then
			
			AddErrorDescriptionFull(ErrorDescription, 
				NStr("en = 'Failed to receive the server reply. File is not sent.'") + " (" + CurFile.Value + ").");
				
			HasErrors = True;
			Break;
			
		EndIf;
		
		ExchangeState = TrimAll(Lower(StrGetLine(ServerResponse,1)));
		
		If ExchangeState = ConnectionSettings.ServerResponse_CurrentOperationAbnormalEnd Then
			
			AddErrorDescriptionFull(ErrorDescription,
				NStr("en = 'Error occurred on server side. File is not sent.'") + " (" + CurFile.Value + ")."
				+ Chars.LF + NStr("en = 'Server response: '") + Chars.LF + ServerResponse);
			
			HasErrors = True;
			Break;
			
		ElsIf ExchangeState = ConnectionSettings.ServerResponse_CurrentOperationSuccessfulCompletion Then
			
			If StrLineCount(ServerResponse) > 1 Then
				
				AddErrorDescriptionFull(ErrorDescription,
					NStr("en = 'Received extended status of successful session completion.'")
					+ Chars.LF + NStr("en = 'Server response: '") + Chars.LF + ServerResponse);
				
			EndIf;
			
		Else
			
			AddErrorDescriptionFull(ErrorDescription,
				NStr("en = 'Error occurred on server side. Operation completion status is not received. File is not sent.'") + " (" + CurFile.Value + ")."
				+ Chars.LF + NStr("en = 'Server response: '") + Chars.LF + ServerResponse);
			
			HasErrors = True;
			Break;
			
		EndIf;
		
	EndDo;
	
	If ZIPFilesAllowed Then
		DeleteTempFileList(FileListToSend);
	EndIf;
	
	If HasErrors Then
		Return False;
	EndIf;
	
	ImportSuccessfullyCompleted = False;
	
	If ExpectFileImportCompletionByServer Then
		
		For Each CurFile IN SourceXMLFilesArray Do
			
			ImportContinues = True;
			CurrentState = "";
			
			While ImportContinues Do
				
				ImportContinues = False;
				
				ErrorDescription = "";
				ServerResponse = GetDataFromServer(
					Join,
					AddressForWork + ConnectionSettings.HTTPQueryParameter_FileImportByServer + CurFile.Name,
					RequestsTitles,
					ErrorDescription
				);
				
				If ServerResponse = Undefined Then 
					
					Successfully = False;
					
					AddErrorDescriptionFull(ErrorDescription, CurFile.Name + ": "
						+ NStr("en = 'Failed to receive the current exchange process state. Exchange data has been sent but not imported.'"));
					
				ElsIf StrLineCount(ServerResponse) = 0 Then
					
					Successfully = False;
					AddErrorDescriptionFull(ErrorDescription, CurFile.Name + ": "
						+ NStr("en = 'Failed to read the data of the current exchange process status. Exchange data has been sent but not imported.'"));
					
				Else
					
					ExchangeState = TrimAll(Lower(StrGetLine(ServerResponse, 1)));
					
					If ExchangeState = ConnectionSettings.ServerResponse_CurrentOperationAbnormalEnd Then
						
						Successfully = False;
						AddErrorDescriptionFull(ErrorDescription, CurFile.Name + ": "
							+ NStr("en = 'Error occurred on server side.'")
							+ Chars.LF + NStr("en = 'Server response'") + ": " + Chars.LF + ServerResponse);
						
					ElsIf ExchangeState = ConnectionSettings.ServerResponse_CurrentOperationSuccessfulCompletion Then
						
						ImportSuccessfullyCompleted = True;
						
					ElsIf ExchangeState = ConnectionSettings.ServerResponse_CurrentOperationExecution Then
						
						ImportContinues = True;
						
					Else
						
						Successfully = False;
						
						AddErrorDescriptionFull(ErrorDescription, CurFile.Name + ": "
							+ NStr("en = 'Error occurred on server side. Unknown import status has been received.'")
							+ Chars.LF + NStr("en = 'Server response'") + ": " + Chars.LF + ServerResponse);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
			If Not ImportSuccessfullyCompleted Then
				
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Return Successfully;
	
EndFunction

Procedure DeleteTempFileList(FileList)

	For Each CurFile IN FileList Do
		
		Try
			DeleteFiles(CurFile.Value);
		Except
		EndTry;
		
	EndDo;

EndProcedure

// Sends the file to the server by http.
//
// Parameters:
// FullFileName - String
// Connection - HTTPConnection
// QueryParameters - String
// Headers - String
// ErrorDescription - String
//
// Returns:
// String - Server reply.
//
Function SendFileToServer(FullFileName, Join, QueryParameters="", Headers="", ErrorDescription)
	
	ServerResponse = Undefined;
	FileNameResponse = GetTempFileName();
	
	Try
		Join.Post(FullFileName, TrimAll(QueryParameters), FileNameResponse, TrimAll(Headers));
	Except
		AddErrorDescriptionFull(ErrorDescription, ExceptionalErrorDescription());
	EndTry;
	
	ResponseFile = New File(FileNameResponse);
	
	If ResponseFile.Exist() Then
		
		AnswerText = New TextDocument();
		AnswerText.Read(FileNameResponse);
		If AnswerText.LineCount()>0 Then
			ServerResponse = AnswerText.GetText();
		Else
			AddErrorDescriptionFull(ErrorDescription, NStr("en = 'Sending file to the server: Blank server response is received.'"));
		EndIf;
		
	Else
		
		AddErrorDescriptionFull(ErrorDescription, NStr("en = 'Sending file to server: Server response is not received.'")); 
		
	EndIf;
	
	Try
		DeleteFiles(TempFilesDir(), FileNameResponse);
	Except
	EndTry;
	
	Return ServerResponse;
	
EndFunction

Function SplitFilesToFragments(FileList, FragmentSizeLimit)
	
	NewFileList = New ValueList;
	For Each CurFile IN FileList Do
		
		FileOnDrive = New File(CurFile.Value);
		If FileOnDrive.Size() > FragmentSizeLimit Then
			
			FragmentArray = SplitFile(FileOnDrive.FullName, FragmentSizeLimit);
			For Each NewFile IN FragmentArray Do
				NewFileList.Add(NewFile, CurFile.Presentation);
			EndDo;
			
			DeleteFiles(FileOnDrive.FullName);
			
		Else
			NewFileList.Add(CurFile.Value, CurFile.Presentation);
		EndIf;
		
	EndDo;
	
	Return NewFileList;
	
EndFunction

Function PrepareZIPArchives(DirectoryOnHardDisk, ErrorDescription)
	
	ArchiveFileFullName = GetTempFileName("zip");
	WriteArchive = New ZipFileWriter(ArchiveFileFullName);
	
	NewFileList = New ValueList;
	
	WriteArchive.Add(DirectoryOnHardDisk + "\*.*", ZIPStorePathMode.StoreRelativePath, ZIPSubDirProcessingMode.ProcessRecursively);
	
	Try
		WriteArchive.Write();
	Except
		
		AddErrorDescriptionFull(ErrorDescription,
			ExceptionalErrorDescription(NStr("en = 'Failed to write zip-archive to disc!'")));
		Return NewFileList;
		
	EndTry;
	
	FileOfArchive = New File(ArchiveFileFullName);
	NewFileList.Add(ArchiveFileFullName, FileOfArchive.Name);
	
	Return NewFileList;
	
EndFunction

Function GetFileListToSend(DirectoryOnHardDisk, ArrayOfSubdirectories);
	
	FileList = New ValueList;
	Mask = "*.*";
	
	AllFilesForExportings = FindFiles(DirectoryOnHardDisk, Mask);
	
	If ArrayOfSubdirectories <> Undefined Then
		
		For Each Subdirectory IN ArrayOfSubdirectories Do
			
			FilesInSubdirectory = FindFiles(DirectoryOnHardDisk + "\" + Subdirectory, Mask);
			
			For Each CurFile IN FilesInSubdirectory Do
				
				If CurFile.IsDirectory() Then
					
					FilesInAdditionalSubdirectory = FindFiles(CurFile.FullName, Mask);
					
					For Each CurFileInSubdirectory IN FilesInAdditionalSubdirectory Do
						
						If Not CurFileInSubdirectory.IsDirectory() Then	
							AllFilesForExportings.Add(CurFileInSubdirectory);
						EndIf;
						
					EndDo;
					
				Else
					
					AllFilesForExportings.Add(CurFile);  
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
	For Each CurFile IN AllFilesForExportings Do
		
		If Not CurFile.IsDirectory() Then
			
			FullFileNameForServer = PrapareFileNameForServer(DirectoryOnHardDisk, CurFile);
			FileList.Add(CurFile.FullName, FullFileNameForServer);
			
		EndIf;
		
	EndDo;
	
	Return FileList;
	
EndFunction

Function PrapareFileNameForServer(DirectoryOnHardDisk, FileObject)
	
	FullFileNameForServer = "";
	
	If Find(FileObject.Name, ".xml") > 0 Then
		
		FullFileNameForServer = FileObject.Name;
		
	Else
		
		//Leave 2 directories and expand the slashes for the image.
		
		FullFileNameForServer = FileObject.FullName;
		PathForDeletion = DirectoryOnHardDisk + "\";
		FullFileNameForServer = StrReplace(FullFileNameForServer, PathForDeletion, "");
		FullFileNameForServer = StrReplace(FullFileNameForServer, "\", "/");
		
	EndIf;
	
	FullFileNameForServer = DeleteAdditionalFileExtensions(DirectoryOnHardDisk, FullFileNameForServer);
	Return FullFileNameForServer;
	
EndFunction

Function DeleteAdditionalFileExtensions(DirectoryOnHardDisk, OriginalFileName)
	
	DotPosition = Find(OriginalFileName, ".");
	
	FileName = Left(OriginalFileName, DotPosition - 1);
	
	OriginalNameRightPart = Right(OriginalFileName, StrLen(OriginalFileName) - DotPosition);
	
	DotPosition = Find(OriginalNameRightPart, ".");
	
	Extension = OriginalNameRightPart;
	
	If DotPosition > 0 Then
		Extension = Left(OriginalNameRightPart, DotPosition - 1);
	EndIf;
	
	Return FileName + "." + Extension;
	
EndFunction

Procedure AddErrorDescriptionFull(Definition, Supplement) Export
	
	If IsBlankString(Definition) Then
		Definition = Supplement;
	Else
		Definition = Definition + Chars.LF + Supplement;
	EndIf;
	
EndProcedure

Function GetDataFromServer(Join, QueryParameters = "", Headers = "", ErrorDescription)
	
	FileNameResponse = GetTempFileName();
	
	Try
		
		Join.Get(TrimAll(QueryParameters), FileNameResponse, TrimAll(Headers));
		
	Except
		
		AddErrorDescriptionFull(ErrorDescription,
			ExceptionalErrorDescription(NStr("en = 'Failed to receive data from the server. Verify the correctness of the address server, port, user name and a password.'")
				+ Chars.LF
				+ NStr("en = 'also Internet connection settings.'")));
		
	EndTry;
	
	ResponseFile = New File(FileNameResponse);
	ServerResponse = Undefined;
	
	If ResponseFile.Exist() Then
		
		AnswerText = New TextDocument();
		AnswerText.Read(FileNameResponse);
		
		If AnswerText.LineCount()>0 Then
			ServerResponse = AnswerText.GetText();
		Else
			AddErrorDescriptionFull(ErrorDescription,
				NStr("en = 'Data receiving from the server: Blank server response is received.'"));
		EndIf;
		
	Else
		
		AddErrorDescriptionFull(ErrorDescription,
			NStr("en = 'Receiving data from server: Server response is not received.'"));
			
	EndIf;
	
	Try
		DeleteFiles(TempFilesDir(), FileNameResponse);
	Except
	EndTry;
	
	Return ServerResponse;
	
EndFunction

Function PreparePathForPlatform(WindowsPlatform, Path) Export
	
	If WindowsPlatform Then
		WhatToChange = "/";
		ReplaceWith = "\";
	Else
		WhatToChange = "\";
		ReplaceWith = "/";
	EndIf;
	
	Path = StrReplace(Path, WhatToChange, ReplaceWith);
	Return Path;
	
EndFunction

// Adds exchange plan node data to Parameters structure.
//
Procedure AddNodeSettingsToParameters(ExchangeNode, Parameters)
	
	Query = New Query(
		"SELECT
		|	ExchangeSmallBusinessSite.Ref AS ExchangeNode,
		|	ExchangeSmallBusinessSite.DeletionMark AS DeletionMark,
		|	ExchangeSmallBusinessSite.PerformFullExportingCompulsorily AS PerformFullExportingCompulsorily,
		|	ExchangeSmallBusinessSite.ProductsExchange AS ProductsExchange,
		|	ExchangeSmallBusinessSite.OrdersExchange AS OrdersExchange,
		|	ExchangeSmallBusinessSite.ExportToSite AS ExportToSite,
		|	ExchangeSmallBusinessSite.ExportDirectory AS ExportDirectory,
		|	ExchangeSmallBusinessSite.SiteAddress AS SiteAddress,
		|	ExchangeSmallBusinessSite.UserName AS UserName,
		|	ExchangeSmallBusinessSite.Password AS Password,
		|	ExchangeSmallBusinessSite.UseScheduledJobs AS UseScheduledJobs,
		|	ExchangeSmallBusinessSite.ScheduledJobID AS ScheduledJobID,
		|	ExchangeSmallBusinessSite.CounterpartiesIdentificationMethod AS CounterpartiesIdentificationMethod,
		|	ExchangeSmallBusinessSite.CounterpartyToSubstituteIntoOrders AS CounterpartyToSubstituteIntoOrders,
		|	ExchangeSmallBusinessSite.CompanyToSubstituteIntoOrders AS CompanyToSubstituteIntoOrders,
		|	ExchangeSmallBusinessSite.GroupForNewCounterparties AS GroupForNewCounterparties,
		|	ExchangeSmallBusinessSite.GroupForNewProductsAndServices AS GroupForNewProductsAndServices,
		|	ExchangeSmallBusinessSite.ExportPictures AS ExportPictures,
		|	ExchangeSmallBusinessSite.SavedDirectoriesTable AS SavedDirectoriesTable,
		|	ExchangeSmallBusinessSite.ImportFile AS ImportFile,
		|	ExchangeSmallBusinessSite.ExportBalanceForWarehouses AS ExportBalanceForWarehouses,
		|	ExchangeSmallBusinessSite.OrdersStatesCorrespondence.(
		|		OrderStatusOnSite AS OrderStatusOnSite,
		|		CustomerOrderStatus AS CustomerOrderStatus
		|	) AS TableOfConformityOrderStatuses,
		|	ExchangeSmallBusinessSite.PriceKinds.(
		|		PriceKind
		|	) AS PriceKinds
		|FROM
		|	ExchangePlan.ExchangeSmallBusinessSite AS ExchangeSmallBusinessSite
		|WHERE
		|	ExchangeSmallBusinessSite.Ref = &Ref");
	
	Query.SetParameter("Ref", ExchangeNode);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		
		Return;
		
	EndIf;
	
	SettingsTable = Result.Unload();
	For Each Column IN SettingsTable.Columns Do
		
		Parameters.Insert(Column.Name, SettingsTable[0][Column.Name]);
		
	EndDo;
	
EndProcedure

Procedure AddXDTOAttributeValue(AttributeValuesXDTO, CMLPackage, Description, Value)
	
	If Not ValueIsFilled(Description) OR Not ValueIsFilled(Value) Then
		Return;
	EndIf;
	
	XDTOAttributeValue = XDTOFactory.Create(CMLPackage.Get("AttributeValue"));
	
	XDTOAttributeValue.Description = Description;
	XDTOAttributeValue.Value.Add(GetRecordStringForXML(Value));
	
	AttributeValuesXDTO.AttributeValue.Add(XDTOAttributeValue);
	
EndProcedure

// Receives the attribute type from XDTO object type.
//
// Parameters:
//	XDTOObjectType - XDTO object type used to receive the
//	AttributteName attribute type - attribute name which type shall be received
//
//Returns:
//	XDTOObjectType.
//
Function GetPropertyTypeFromXDTOObjectType(XDTOObjectType, PropertyName)
	
	PropertyType = XDTOObjectType.Properties.Get(PropertyName).Type;
	Return PropertyType;
	
EndFunction

Function GetXDTOCounterparty(CounterpartyData, CMLPackage) Export
	
	If CounterpartyData = Undefined Then
		Return Undefined;
	EndIf;
	
	ThisIsCompany = TypeOf(CounterpartyData.Counterparty) = Type("CatalogRef.Companies");
	If ThisIsCompany Then
		
		XDTOCounterparty = XDTOFactory.Create(CMLPackage.Get("Counterparty"));
		
	Else
		
		CounterpartiesType = GetPropertyTypeFromXDTOObjectType(CMLPackage.Get("Document"), "Counterparties");
		XDTOCounterparty = XDTOFactory.Create(GetPropertyTypeFromXDTOObjectType(CounterpartiesType, "Counterparty"));
		
	EndIf;
	
	XDTOCounterparty.ID = String(CounterpartyData.Counterparty.UUID());
	XDTOCounterparty.Description = CounterpartyData.Description;
	
	ThisIsLegalEntity = CounterpartyData.LegalEntityIndividual = Enums.LegalEntityIndividual.LegalEntity;
	If ThisIsLegalEntity Then
		
		If Not IsBlankString(CounterpartyData.DescriptionFull) Then
			XDTOCounterparty.OfficialName = CounterpartyData.DescriptionFull;
		EndIf;
		
		If ThisIsCompany Then
			AddXDTOCompanyLegAddress(XDTOCounterparty, CounterpartyData.ContactInformation, CMLPackage);
		EndIf;
		
	Else
		
		If Not IsBlankString(CounterpartyData.DescriptionFull) Then
			XDTOCounterparty.FullDescr = CounterpartyData.DescriptionFull;
		EndIf;
		
	EndIf;
	
	TIN = GetTINForXDTO(CounterpartyData.TIN, CounterpartyData.LegalEntityIndividual);
	If Not IsBlankString(TIN) Then
		XDTOCounterparty.TIN = TIN;
	EndIf;
	
	KPP = GetKPPForXDTO(CounterpartyData.KPP);
	If Not IsBlankString(KPP) Then
		XDTOCounterparty.KPP = KPP;
	EndIf;
	
	If ThisIsLegalEntity Then
		XDTOCounterparty.OKPO = CounterpartyData.CodeByOKPO;
	EndIf;
	
	If Not ThisIsCompany Then
		XDTOCounterparty.Role = "Customer";
	EndIf;
	
	XDTOCounterparty.Validate();
	
	Return XDTOCounterparty;
	
EndFunction

Function GetTINForXDTO(TIN, LegalEntityIndividual)
	
	If LegalEntityIndividual = Enums.LegalEntityIndividual.LegalEntity Then
		TINValue = ?(StrLen(TIN) = 10, TIN, "");
	Else
		TINValue = ?(StrLen(TIN) = 12, TIN, "");
	EndIf;
	
	Return TINValue;
	
EndFunction

Function GetKPPForXDTO(KPP)
	
	ValueKPP = ?(StrLen(KPP) = 9, KPP, "");
	
	Return ValueKPP;
	
EndFunction 

// Checks the barcode correspondence with CML205 format.
// If the barcode is not compliant with the format, it returns an empty string.
//
Function GetBarcodeForXDTO(Barcode)
	
	If StrLen(Barcode) < 8
		OR StrLen(Barcode) > 14 Then
		
		Return "";
		
	EndIf;
	
	Return Barcode;
	
EndFunction

Procedure AddXDTOCompanyLegAddress(XDTOCompany, ContactInformation, CMLPackage)
	
	CISelection = ContactInformation.Select();
	
	SearchStructure = New Structure;
	SearchStructure.Insert("Type", Enums.ContactInformationTypes.Address);
	SearchStructure.Insert("Kind", Catalogs.ContactInformationTypes.CompanyLegalAddress);
	
	If Not CISelection.FindNext(SearchStructure)
		OR IsBlankString(CISelection.Presentation) Then
		Return;
	EndIf;
	
	XDTOLegalAddress = XDTOFactory.Create(CMLPackage.Get("Address"));
	XDTOLegalAddress.Presentation = CISelection.Presentation;
	
	FieldList = ConvertStringToFieldList(CISelection.FieldsValues);
	For Each CIField IN FieldList Do
		
		If CIField.Presentation = "IndexOf" Then
			
			AddXDTOAddressField(XDTOLegalAddress, "Postal index", CIField.Value, CMLPackage);
			
		ElsIf CIField.Presentation = "Settlement" Then
			
			AddXDTOAddressField(XDTOLegalAddress, "Settlement", CIField.Value, CMLPackage);
			
		ElsIf CIField.Presentation = "Region"
			OR CIField.Presentation = "District"
			OR CIField.Presentation = "City"
			OR CIField.Presentation = "Street"
			OR CIField.Presentation = "Building"
			OR CIField.Presentation = "Section"
			OR CIField.Presentation = "Apartment"
			OR CIField.Presentation = "Country" Then
			
			AddXDTOAddressField(XDTOLegalAddress, CIField.Presentation, CIField.Value, CMLPackage);
			
		EndIf;
		
	EndDo;
	
	XDTOCompany.LegalAddress = XDTOLegalAddress;
	
EndProcedure

// Adds the address field to XDTO object.
//
// Parameters:
// AddressXDTO - XDTO object of
// the Address type FieldName - String
// Value - String
// CMLPackage - XDTO package containing CML types.
//
Procedure AddXDTOAddressField(AddressXDTO, FieldName, Value, CMLPackage)
	
	If Not ValueIsFilled(Value) Then
		Return;
	EndIf;
	
	AddressFieldXDTO = XDTOFactory.Create(CMLPackage.Get("AddressField"));
	
	AddressFieldXDTO.Type = FieldName;
	AddressFieldXDTO.Value = Value;
	
	AddressXDTO.AddressField.Add(AddressFieldXDTO);
	
EndProcedure

Function ValueTypeCatalog(Type)
	
	ValueTypeCatalog = False;
	
	Try
		ObjectByType = New(Type);
		ValueTypeCatalog = Metadata.Catalogs.Contains(ObjectByType.Metadata());
	Except
	EndTry;
	
	Return ValueTypeCatalog;
	
EndFunction

Function DescriptionFormatForXDTO(Description)
	
	Return Left(Description, 250);
	
EndFunction

Function DateFormatForXDTO(ValueData, ReturnDate = True, RedoTime = False)
	
	DateFormat = "DF=yyyy-MM-dd; DLF=D";
	TimeFormat = "DLF=T";
	DelimiterDateTime = "T";
	
	DateString = Format(ValueData, DateFormat);
	TimeString = Format(ValueData, TimeFormat);
	Result = "";
	
	If ReturnDate AND RedoTime Then
		Result = DateString + DelimiterDateTime + TimeString;
	ElsIf ReturnDate AND (NOT RedoTime) Then
		Result = DateString;
	ElsIf (NOT ReturnDate) AND RedoTime Then
		Result = TimeString;
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the currency value for exporting in XML.
// 
// Parameters:
//  Currency - CatalogRef.Currencies
// 
// Returns:
//  Row.
//
Function CurrencyFormatForXDTO(Currency) Export
	
	CurrencyText = "???";
	
	If TypeOf(Currency) = Type("CatalogRef.Currencies") Then
		CurrencyText = Currency.Description;
	EndIf;
		
	Return Left(CurrencyText, 3);
	
EndFunction

Procedure DisplayListOfDocumentsForLog(Definition, DocumentArray)
	
	If DocumentArray.Count() = 0 Then
		Return;
	EndIf;
	
	Definition = Definition + ". " + NStr("en = 'Documents list:'");
	
	For Each Doc IN DocumentArray Do
		
		OrderAttributesStructureOnSite = GetOrderAttributesOnSite(Doc.Ref);
		
		If OrderAttributesStructureOnSite = Undefined Then
			OrderNumberOnSite = "";
			OrderDateOnSite = "";
		Else
			OrderNumberOnSite = OrderAttributesStructureOnSite.OrderNumberOnSite;
			OrderDateOnSite = OrderAttributesStructureOnSite.OrderDateOnSite;
		EndIf;
		
		Definition = Definition + Chars.LF + Chars.NBSp + Chars.NBSp
			+ StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = '# %1 date %2 (# %3 date %4 on site)'"),
				Doc.Number,
				Doc.Date,
				OrderNumberOnSite,
				OrderDateOnSite);
		
	EndDo;
	
EndProcedure

Function UnpackZIPArchive(ZIPString, ErrorDescription) Export
	
	ContentString = "";
	
	FileName = GetTempFileName("zip");
	DirectoryName = TempFilesDir() + String(New UUID);
	
	Try
		
		CreateDirectory(DirectoryName);
		
	Except
		
		AddErrorDescriptionFull(ErrorDescription,
			ExceptionalErrorDescription(NStr("en = 'Failed to unpack archive with orders!'")));
			
		Return "";
		
	EndTry;
	
	StringToFile = New TextDocument;
	StringToFile.SetText(ZIPString);
	
	Try
		
		StringToFile.Write(FileName);
		
	Except
		
		AddErrorDescriptionFull(ErrorDescription,
			ExceptionalErrorDescription(NStr("en = 'Failed to write archive with orders: '")
				+ FileName));
				
		Return "";
		
	EndTry;
	
	Try
		
		ZIPReader = New ZipFileReader(FileName);
		ZIPReader.ExtractAll(DirectoryName);
		ZIPReader.Close();
		
		UnzippedFiles = FindFiles(DirectoryName, "*.xml");
		
		If UnzippedFiles.Count() = 1 Then
			
			StringFromFile = New TextDocument;
			StringFromFile.Read(UnzippedFiles[0].FullName);
			ContentString = StringFromFile.GetText();
			
		EndIf;
		
		DeleteFiles(FileName);
		DeleteFiles(DirectoryName);
		
	Except
		
		AddErrorDescriptionFull(ErrorDescription,
			ExceptionalErrorDescription(NStr("en = 'Can not unpack archive with orders: '")
				+ FileName));
				
		Return "";
		
	EndTry;
	
	Return ContentString;
	
EndFunction

//Returns a structure containing the bank data received from XDTO object of the Bank type
//
Function GetXDTOBankData(BankXDTO)
	
	BankData = New Structure;
	
	Description = "";
	If XDTOObjectContainsProperty(BankXDTO, "Description") AND XDTOPropertyIsFilled(BankXDTO.Description) Then
		Description = BankXDTO.Description;
	EndIf;
	
	BIN = "";
	If XDTOObjectContainsProperty(BankXDTO, "BIN") AND XDTOPropertyIsFilled(BankXDTO.BIN) Then
		BIN = StrReplace(BankXDTO.BIN, " ", "");
	EndIf;
	
	SWIFT = "";
	If XDTOObjectContainsProperty(BankXDTO, "SWIFT") AND XDTOPropertyIsFilled(BankXDTO.SWIFT) Then
		SWIFT = StrReplace(BankXDTO.SWIFT, " ", "");
	EndIf;
	
	CorrAccount = "";
	If XDTOObjectContainsProperty(BankXDTO, "AccountCorrespondent") AND XDTOPropertyIsFilled(BankXDTO.AccountCorrespondent) Then
		CorrAccount = StrReplace(BankXDTO.AccountCorrespondent, " ", "");
	EndIf;
	
	Address = "";
	If XDTOObjectContainsProperty(BankXDTO, "Address") AND XDTOPropertyIsFilled(BankXDTO.Address.Presentation) Then
		Address = TrimAll(BankXDTO.Address.Presentation);
	EndIf;
	
	City = GetBankCityFromXDTOAddress(BankXDTO.Address);
	
	BankData.Insert("Description", Description);
	BankData.Insert("BIN", BIN);
	BankData.Insert("SWIFT", SWIFT);
	BankData.Insert("CorrAccount", CorrAccount);
	BankData.Insert("Address", Address);
	BankData.Insert("City", City);
	
	Return BankData;
	
EndFunction

Function XDTOObjectContainsProperty(XDTODataObject, Property)
	
	If XDTODataObject = Undefined Then
		Return False;
	EndIf;
	
	IsProperty = XDTODataObject.Properties().Get(Property) <> Undefined
		AND XDTODataObject[Property] <> Undefined;
		
	Return IsProperty;
	
EndFunction

Function XDTOPropertyIsFilled(XDTOProperty)
	
	PropertyFilled = True;
	
	If TypeOf(XDTOProperty) = Type("XDTODataObject")
		OR TypeOf(XDTOProperty) = Type("XDTOList")
		OR Not ValueIsFilled(XDTOProperty) Then
		
		PropertyFilled = False;
		
	EndIf;
	
	Return PropertyFilled;
	
EndFunction

Function ConvertFieldListToString(FieldMap)
	
	Result = "";
	For Each Item IN FieldMap Do
		
		Value = Item.Value;
		If IsBlankString(Value) Then
			Continue;
		EndIf;
		
		Result = Result + ?(Result = "", "", Chars.LF) + 
			Item.Key + "=" + StrReplace(Value, Chars.LF, Chars.LF + Chars.Tab);
		
	EndDo;
	
	Return Result;
	
EndFunction

Function GetBankCityFromXDTOAddress(AddressXDTO)
	
	City = "";
	
	If XDTOObjectContainsProperty(AddressXDTO, "AddressField")
		AND TypeOf(AddressXDTO.AddressField) = Type("XDTOList") Then
		
		For Each XDTODataObject IN AddressXDTO.AddressField Do
			
			If XDTODataObject.Type = "City" Then
				
				City = XDTODataObject.Value;
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Return City;
	
EndFunction

Function GetTypeContactInformationKindByXDTOType(XDTOCIType)
	
	CIStructure = New Structure();
	
	If Lower(XDTOCIType) = "workphone"
		OR Lower(XDTOCIType) = "insidephone"
		OR Lower(XDTOCIType) = "cellphone"
		OR Lower(XDTOCIType) = "housephone" Then
		
		CIType = Enums.ContactInformationTypes.Phone;
		CIKind = Catalogs.ContactInformationTypes.CounterpartyPhone;
		
	ElsIf Lower(XDTOCIType) = "Fax" Then
		
		CIType = Enums.ContactInformationTypes.Fax;
		CIKind = Catalogs.ContactInformationTypes.CounterpartyFax;
		
	ElsIf Lower(XDTOCIType) = "mail" Then
		
		CIType = Enums.ContactInformationTypes.EmailAddress;
		CIKind = Catalogs.ContactInformationTypes.CounterpartyEmail;
		
	ElsIf Lower(XDTOCIType) = "WebSite" Then
		
		CIType = Enums.ContactInformationTypes.WebPage;
		CIKind = Catalogs.ContactInformationTypes.CounterpartyOtherInformation;
		
	Else
		
		CIType = Enums.ContactInformationTypes.Another;
		CIKind = Catalogs.ContactInformationTypes.CounterpartyOtherInformation;
		
	EndIf;
	
	CIStructure.Insert("Type", CIType);
	CIStructure.Insert("Kind", CIKind);
	
	Return CIStructure;
	
EndFunction

// Receives the currency corresponding to the bank account number.
// 6-8 digids of the bank account number represent the currency code.
// The 810 code is used for the Russian ruble.
//
// Parameters:
// AccountNo - Number - Bank account number
//
// Returns:
// CatalogRef.Currencies - Bank account currency.
//
Function GetCurrencyByAccountNo(AccountNo) Export
	
	Currency = Catalogs.Currencies.EmptyRef();
	
	CurrencyCode = Mid(AccountNo, 6, 3);
	If CurrencyCode = "810" Then
		CurrencyCode = "643";
	EndIf;
	
	Query = New Query("
	|SELECT
	|	Currencies.Ref AS Currency
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.Code = &CurrencyCode
	|");
	
	Query.SetParameter("CurrencyCode", CurrencyCode);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Currency = Selection.Currency;
	EndIf;
	
	Return Currency;
	
EndFunction

Function GetFromXDTOObjectStringWithSNP(XDTOCounterparty)
	
	CurrentRow = "";
	Surname = "";
	Name = "";
	Patronymic = "";
		
	If XDTOObjectContainsProperty(XDTOCounterparty, "Surname") AND XDTOPropertyIsFilled(XDTOCounterparty.Surname) Then
		CurrentRow = XDTOCounterparty.Surname;
	EndIf;
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "Name") AND XDTOPropertyIsFilled(XDTOCounterparty.Name) Then
		CurrentRow = TrimAll(CurrentRow + " " + XDTOCounterparty.Name);
	EndIf;
	
	If XDTOObjectContainsProperty(XDTOCounterparty, "Patronymic") AND XDTOPropertyIsFilled(XDTOCounterparty.Patronymic) Then
		CurrentRow = TrimAll(CurrentRow + " " + XDTOCounterparty.Patronymic);
	EndIf;
	
	Return CurrentRow;
	
EndFunction

// Returns an array containing XDTO Objects or XDTO object if the type of the transferred parameter is ObjectXDTO.
//
//	Parameters
//	XDTOList - XDTOList, XDTOObject - XDTO list which objects shall be received
//
//	Return
//	value Array - array of XDTO object attributes.
//
Function GetArrayOfXDTOListObjects(XDTOList)
	
	ObjectArrayXDTO = New Array;
	
	If TypeOf(XDTOList) = Type("XDTOList") Then
		
		For Each XDTODataObject IN XDTOList Do 
			ObjectArrayXDTO.Add(XDTODataObject);
		EndDo;
		
	Else
		ObjectArrayXDTO.Add(XDTOList);
	EndIf;
	
	Return ObjectArrayXDTO;
	
EndFunction

Procedure CalculateOrderVATSUM(TabularSectionRow, Document)
	
	If Document.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
		TabularSectionRow.VATAmount = ?(Document.AmountIncludesVAT,
										  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
										  TabularSectionRow.Amount * VATRate / 100);
	Else
		TabularSectionRow.VATAmount = 0;
	EndIf;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Document.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Distributes the amount in the Amount column.
//
// Parameters: 
// Products - DistributionAmount
// tabular section - number, DocumentObject
// distributable amount - DocumentObject.CustomerOrder.
//
Procedure DistributeAmountByColumn(Document, Products, DistributionAmount)
	
	ArrayOfDataColumns = Products.UnloadColumn("Amount");
	DistributionArray = DistributeProportionally(DistributionAmount, ArrayOfDataColumns);
	
	If DistributionArray = Undefined Then
		Return;
	EndIf; 
	
	IndexOf = 0;
	For Each TabularSectionRow IN Products Do
		
		TabularSectionRow.Amount = TabularSectionRow.Amount + DistributionArray[IndexOf];
		RecountTabularSectionRow(TabularSectionRow, Document);
		
		IndexOf = IndexOf + 1;
		
	EndDo;
	
EndProcedure

// Proportionally distributes an amount
// according to the specified distribution ratios.
//
// Parameters:
//	SrcAmount   - CoeffArray
//	distributable amount - distribution coefficient
//	array Precision   - rounding precision during allocation.
//
//Returns:
//	AmountArray - array with the dimension equal
//				 to the ratio array contains the amounts in accordance
//				 with the ratio weight (from the ratio array) IN case it is failed to distribute (amount = 0, number of ratios =
//				 0 or total weight factor. = 0) then Undefined value is returned.
//
Function DistributeProportionally(Val SrcAmount, CoeffArray, Val Precision = 2) Export
	
	If CoeffArray.Count() = 0 Or SrcAmount = 0 Or SrcAmount = Null Then
		Return Undefined;
	EndIf;
	
	MaxIndex = 0;
	MaxVal   = 0;
	DistribAmount = 0;
	AmountCoeff  = 0;
	
	For K = 0 To CoeffArray.Count() - 1 Do
	
		AbsNumber = ?(CoeffArray[K] > 0, CoeffArray[K], - CoeffArray[K]);
	
		If MaxVal < AbsNumber Then
			MaxVal = AbsNumber;
			MaxIndex = K;
		EndIf;
	
		AmountCoeff = AmountCoeff + CoeffArray[K];
	
	EndDo;
	
	If AmountCoeff = 0 Then
		Return Undefined;
	EndIf;
	
	AmountArray = New Array(CoeffArray.Count());
	
	For K = 0 To CoeffArray.Count() - 1 Do
		AmountArray[K] = Round(SrcAmount * CoeffArray[K] / AmountCoeff, Precision, 1);
		DistribAmount = DistribAmount + AmountArray[K];
	EndDo;
	
	// Rounding errors are assigned to ratio with the maximum weight.
	If Not DistribAmount = SrcAmount Then
		AmountArray[MaxIndex] = AmountArray[MaxIndex] + SrcAmount - DistribAmount;
	EndIf;
	
	Return AmountArray;
	
EndFunction

Function GetNumberFromString(ValueString)
	
	ValueNumber = 0;
	
	Try
		ValueNumber = Number(ValueString);
	Except
	EndTry;
	
	Return ValueNumber;
	
EndFunction

Function GetProductsAndServicesIdentifier(Val ID)
	
	SeparatorPosition = Find(ID, "#");
	If SeparatorPosition > 0 Then
		ProductsAndServicesID = Left(ID, SeparatorPosition - 1);
	Else
		ProductsAndServicesID = ID;
	EndIf;
	
	Return ProductsAndServicesID;
	
EndFunction

Function GetProductsAndServicesDescription(Val Description)
	
	SeparatorPosition = Find(Description, "#");
	If SeparatorPosition > 0 Then
		ProductsAndServicesDescription = Left(Description, SeparatorPosition - 1);
	Else
		ProductsAndServicesDescription = Description;
	EndIf;
	
	Return ProductsAndServicesDescription;
	
EndFunction

Function GetCharacteristicIdentifier(Val ID)
	
	SeparatorPosition = Find(ID, "#");
	If SeparatorPosition > 0 Then
		IDCharacteristics = Mid(ID, SeparatorPosition + 1);
	Else
		IDCharacteristics = "";
	EndIf;
	
	Return IDCharacteristics;
	
EndFunction

Function GetCharacteristicDescription(Val Description)
	
	SeparatorPosition = Find(Description, "#");
	If SeparatorPosition > 0 Then
		CharacteristicDescription = Mid(Description, SeparatorPosition + 1);
	Else
		CharacteristicDescription = "";
	EndIf;
	
	Return CharacteristicDescription;
	
EndFunction

Function GetDateTimeFromString(DateString, TimeString = "")
	
	DateTime = Date(1,1,1);
	
	Try
		
		If TypeOf(DateString) = Type("Date")
			AND TypeOf(TimeString) = Type("Date") Then
			
			DateTime = Date(Format(DateString, "DF=dd.MM.yyyy") + " " + Format(TimeString, "DLF=T"));
		EndIf;
		
		If DateTime = Date(1,1,1) Then
			
			If ValueIsFilled(TimeString) Then
				Time = StrReplace(TimeString, ":", "");
				DateTime = Date(StrReplace(DateString, "-", "") + Time);
			Else
				DateTime = Date(StrReplace(DateString, "-", "") + "000000");
			EndIf;
			
		EndIf;
		
	Except
	EndTry;
	
	Return DateTime;
	
EndFunction

Procedure AddExchangeProtocolParametersIntoStructure(ParametersStructure)
	
	ParametersStructure.Insert("HTTPRequestParameter_Initialization"			, "&mode=init");
	ParametersStructure.Insert("HTTPRequestParameter_FileTransfer"			, "&mode=file&filename=");
	ParametersStructure.Insert("HTTPRequestParameter_FileImportByServer"		, "&mode=import&filename=");
	ParametersStructure.Insert("HTTPRequestParameter_GetData"			, "&mode=query");
	ParametersStructure.Insert("HTTPRequestParameter_ImportCompletedSuccessfully", "&mode=success");
	
	ParametersStructure.Insert("ServerResponse_ZIPAllowed"								, "zip=yes");
	ParametersStructure.Insert("ServerResponse_ExchangeFileFragmentSizeRestriction"	, "file_limit=");
	ParametersStructure.Insert("ServerResponse_CurrentOperationSuccessfulCompletion"		, "success");
	ParametersStructure.Insert("ServerResponse_CurrentOperationAbnormalTermination"		, "failure");
	ParametersStructure.Insert("ServerResponse_CurrentOperationExecuting"				, "progress");
	
EndProcedure	

Function GetVolumePathForPlatform(WindowsPlatform, Volume) Export
	
	If WindowsPlatform Then
		Return Volume.FullPathWindows;
	Else
		Return Volume.FullPathLinux;
	EndIf;
	
EndFunction

Function ThisIsUpperLevelGroup(Item, GroupList)
	
	If TypeOf(GroupList) = Type("ValueList") Then 
		For Each Group IN GroupList Do
			Try
				If Group.Value.BelongsToItem(Item) Then
					Return True;
				EndIf;
			Except
			EndTry;
		EndDo;
	EndIf;
	
	Return False;
	
EndFunction

Function GetPropertyValueVariantsByType(Selection, Type)
	
	ValueVariants = New Array;
	ValuesSelection = Selection.Select();
	
	While ValuesSelection.Next() Do
		
		If TypeOf(ValuesSelection.Value) = Type Then
			
			ValueVariants.Add(ValuesSelection.Value);
			
		EndIf;
		
	EndDo;
	
	Return ValueVariants;
	
EndFunction

Function GetRecordStringForXML(Value)
	
	XMLString = String(Value);
	
	If TypeOf(Value) = Type("Number") Then
		
		XMLString = StrReplace(XMLString, Chars.NBSp, "");
		XMLString = StrReplace(XMLString, ",", ".");
		
	ElsIf TypeOf(Value) = Type("Boolean") Then
		
		If Value Then
			XMLString = "true";
		Else
			XMLString = "false";
		EndIf;
		
	EndIf;
	
	Return XMLString;
	
EndFunction

// Converts the field string to the value list.
//
Function ConvertStringToFieldList(FieldsRow)
	
	Result = New ValueList;
	LastItem = Undefined;
	
	For Ct = 1 To StrLineCount(FieldsRow) Do
		
		Str = StrGetLine(FieldsRow, Ct);
		
		If Left(Str, 1) = Chars.Tab Then
			If LastItem <> Undefined Then
				LastItem.Value = LastItem.Value + Chars.LF + Mid(Str, 2);
			EndIf;
		Else
			Pos = Find(Str, "=");
			If Pos <> 0 Then
				LastItem = Result.Add(Mid(Str, Pos+1), Left(Str, Pos-1));
			EndIf;
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Deletes the directory content.
// IN case of an error it returns the error description.
//
// Parameters:
// Directory - String, path
// to ErrorDescription directory - String, description of an error occurred
//
// Returns:
// Boolean - True if success, False - if an error occurred.
//
Function ClearDirectory(Directory, ErrorDescription)
	
	Try
		
		DeleteFiles(Directory, "*.*");
		
	Except
		
		AddErrorDescriptionFull(ErrorDescription,
			ExceptionalErrorDescription(NStr("ru = Failed to clear the exchange directory: ")
				+ " (" + Directory + ")"));
			
		Return False;
		
	EndTry;
	
	Return True;
	
EndFunction

// Creates the extended error description.
//
// Parameters:
// MessageBeginText - String
// MessageEndText - String
//
// Returns:
// String - Generated error description.
//
Function ExceptionalErrorDescription(MessageBeginText = "", MessageEndText = "") Export
	
	DetailErrorDescription = DetailErrorDescription(ErrorInfo());
	
	MessageText = NStr("en = 'Error occurred: '")
		+ MessageBeginText
		+ ?(IsBlankString(MessageEndText), "", Chars.LF + MessageEndText)
		+ ?(IsBlankString(DetailErrorDescription), "", Chars.LF + DetailErrorDescription);
		
	Return MessageText;
	
EndFunction

// Creates a structure with the references to the changed objects for exchange configuring.
//
// Parameters:
// ExchangeNode - ExchangePlanRef.ExchangeSmallBusinessSite
//
// Returns:
// Structure containing the changes recorded for the node.
//
Function GetAllChangesFromExchangePlan(ExchangeNode)
	
	ReturnStructure = New Structure;
	FillChangesStructureForNode(ExchangeNode.Ref, ReturnStructure);
	
	Return ReturnStructure;
	
EndFunction

// Generates a parameter structure for connecting the site by URL.
//
// Parameters:
// SiteAddress - String,
// URL ConnectionSettings - Settings structure of connection
// to the site ErrorDescription - String
//
// Returns:
// Boolean - True if success.
//
Function AnalyzeSiteAddress(Val SiteAddress, ConnectionSettings, ErrorDescription)
	
	SiteAddress = TrimAll(SiteAddress); 
	
	Server = ""; 
	
	Port = 0;
	
	AddressOfScript = "";
	
	SecureConnection = False;
	
	If Not IsBlankString(SiteAddress) Then
		
		SiteAddress = StrReplace(SiteAddress, "\", "/");
		SiteAddress = StrReplace(SiteAddress, " ", "");
		
		If Lower(Left(SiteAddress, 7)) = "http://" Then
			SiteAddress = Mid(SiteAddress, 8);
		ElsIf Lower(Left(SiteAddress, 8)) = "https://" Then
			SiteAddress = Mid(SiteAddress, 9);
			SecureConnection = True;
		EndIf;
		
		SlashPosition = Find(SiteAddress, "/");
		
		If SlashPosition > 0 Then
			Server = Left(SiteAddress, SlashPosition - 1);
			AddressOfScript = Right(SiteAddress, StrLen(SiteAddress) - SlashPosition);
		Else	
			Server = SiteAddress;
			AddressOfScript = "";
		EndIf;
		
		ColonPosition = Find(Server, ":");
		PortString = "0";
		If ColonPosition > 0 Then
			HostWithPort = Server;
			Server = Left(HostWithPort, ColonPosition - 1);
			PortString = Right(HostWithPort, StrLen(HostWithPort) - ColonPosition);
		EndIf;
		
		Try
			
			Port = Number(PortString);
			
		Except
			
			AddErrorDescriptionFull(ErrorDescription,
				ExceptionalErrorDescription(NStr("en = 'Can not obtain port number: '")
					+ PortString + Chars.LF
					+ NStr("en = 'Check if site address entered correctly.'")));
				
			Return False;
			
		EndTry;
		
		If Port = 0 Then
			Port = ?(SecureConnection, 443, 80);
		EndIf;
		
	EndIf;
	
	If AddressOfScript = "" Then
		AddressOfScript = "bitrix/admin/1c_exchange.php";
	EndIf;
	
	ConnectionSettings.Insert("Server", Server); 
	ConnectionSettings.Insert("Port", Port);
	ConnectionSettings.Insert("AddressOfScript", AddressOfScript);
	ConnectionSettings.Insert("SecureConnection", SecureConnection);
	
	Return True;
	
EndFunction

// Performs necessary actions at the exchange end.
//
// Parameters:
// Parameters - Basic parameter
// structure InformationTable - Value table, current exchange session
// status Error - Boolean, True if it is necessary to record the exchange completion with errors.
//
Procedure RunActionsAtExchangeCompletion(Parameters, InformationTable, Error = False)
	
	InformationTable.FillValues(Parameters.ExchangeNode, "InfobaseNode");
	
	// We record information of each action to the event log.
	
	For Each InformationTableRow IN InformationTable Do
		
		LogEvent = DataExchangeServer.GetEventLogMonitorMessageKey(Parameters.ExchangeNode, InformationTableRow.ActionOnExchange);
		
		If InformationTableRow.ExchangeProcessResult = Enums.ExchangeExecutionResult.Completed Then
			JournalLevel = EventLogLevel.Information;
		Else
			JournalLevel = EventLogLevel.Error;
		EndIf;
		
		If Error Then
			JournalLevel = EventLogLevel.Error;
		EndIf;
		
		WriteLogEvent(LogEvent,
			JournalLevel,
			Parameters.ExchangeNode.Metadata(),
			Parameters.ExchangeNode,
			Parameters.ExchangeRunMode + Chars.LF + InformationTableRow.Definition);
			
	EndDo;

	// We combine 2 exporting (products and orders) information strings into the one (DataExporting).
	
	ExportRows = InformationTable.FindRows(New Structure("ActionOnExchange", Enums.ActionsAtExchange.DataExport));
	
	If ExportRows.Count() = 2 Then
		
		If ExportRows[1].ExchangeProcessResult = Enums.ExchangeExecutionResult.Error Then
			ExportRows[0].ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
		EndIf;
		
		InformationTable.Delete(ExportRows[1]);
		
	EndIf;
	
	// Record exchange states.
	
	SetPrivilegedMode(True);
	
	For Each InformationTableRow IN InformationTable Do
		
		StatusRecord = InformationRegisters.DataExchangeStatus.CreateRecordManager();
		
		FillPropertyValues(StatusRecord, InformationTableRow);
		
		// We write the dates by the session limits for the log filter to work.
		
		StatusRecord.StartDate = Parameters.GeneratingDate;
		StatusRecord.EndDate = CurrentDate();
		
		StatusRecord.Write();
		
		If ValueIsFilled(StatusRecord.ActionOnExchange)
			AND (StatusRecord.ExchangeProcessResult = Enums.ExchangeExecutionResult.Completed
			OR StatusRecord.ExchangeProcessResult = Enums.ExchangeExecutionResult.CompletedWithWarnings) Then
			
			SuccessfulStatusRecord = InformationRegisters.SuccessfulDataExchangeStatus.CreateRecordManager();
			
			FillPropertyValues(SuccessfulStatusRecord, StatusRecord);
			
			SuccessfulStatusRecord.Write();
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetNodesArrayForRegistration(SelectProductExchangeNodes = False, SelectOrdersExchangeNodes = False)
	
	NodesArray = New Array();
	
	For Each Item IN SessionParameters.UsedExchangeWithSiteNodes Do
		
		If SelectProductExchangeNodes 
			AND Item.ProductsExchange Then
			
			NodesArray.Add(Item);
			
		ElsIf SelectOrdersExchangeNodes 
			AND Item.OrdersExchange Then
			
			NodesArray.Add(Item);
			
		EndIf;
		
	EndDo;
	
	Return NodesArray;
	
EndFunction

Procedure DeleteChangeRecords(ExchangeNode, ChangesStructure, ProductsExchange, OrdersExchange)
	
	If ProductsExchange Then
		
		For Each Data IN ChangesStructure.Products Do
			ExchangePlans.DeleteChangeRecords(ExchangeNode, Data);
		EndDo;
		
		For Each Data IN ChangesStructure.Files Do
			ExchangePlans.DeleteChangeRecords(ExchangeNode, Data);
		EndDo;
		
	EndIf;
	
	If OrdersExchange Then
		
		For Each Data IN ChangesStructure.Orders Do
			ExchangePlans.DeleteChangeRecords(ExchangeNode, Data);
		EndDo;
		
	EndIf;
	
EndProcedure

Function GetOrderAttributesOnSite(CustomerOrder)
	
	Query = New Query("SELECT
		|	CustomerOrdersFromSite.OrderNumberOnSite,
		|	CustomerOrdersFromSite.OrderDateOnSite
		|FROM
		|	InformationRegister.CustomerOrdersFromSite AS CustomerOrdersFromSite
		|WHERE
		|	CustomerOrdersFromSite.CustomerOrder = &CustomerOrder");
	
	Query.SetParameter("CustomerOrder", CustomerOrder);
	
	Result = Query.Execute();
	If Result.IsEmpty()Then
		
		Return Undefined;
		
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	
	ReturnStructure = New Structure;
	ReturnStructure.Insert("OrderNumberOnSite", Selection.OrderNumberOnSite);
	ReturnStructure.Insert("OrderDateOnSite", Selection.OrderDateOnSite);
	
	Return ReturnStructure;
	
EndFunction

// Adds characteristics to the characteristics list for XDTO object of the Product type .
//
Procedure AddProductCharacteristicsXDTO(XDTOProduct, CMLPackage, ProductsAndServices, CharacteristicPropertiesTree)
	
	If CharacteristicPropertiesTree = Undefined Then
		Return;
	EndIf;
	
	ProductCharacteristicsType = XDTOProduct.Properties().Get("ProductCharacteristics").Type;
	XDTOProductCharacteristics = XDTOFactory.Create(ProductCharacteristicsType);
	
	FoundStrings = CharacteristicPropertiesTree.Rows.FindRows(New Structure("ProductsAndServices", ProductsAndServices));
	For Each FoundString IN FoundStrings Do
		For Each StringProductsAndServicesCharacteristic IN FoundString.Rows Do
			
			If Not ValueIsFilled(StringProductsAndServicesCharacteristic.Characteristic) Then
				Continue;
			EndIf;
			
			ProductCharacteristicType = CMLPackage.Get("ProductCharacteristic");
			XDTOProductCharacteristic = XDTOFactory.Create(ProductCharacteristicType);
			
			XDTOProductCharacteristic.ID = String(StringProductsAndServicesCharacteristic.Characteristic.UUID());
			XDTOProductCharacteristic.Description = StringProductsAndServicesCharacteristic.Characteristic.Description;
			
			PropertyValuesType = XDTOProductCharacteristic.Properties().Get("PropertyValues").Type;
			XDTOPropertiesValues = XDTOFactory.Create(PropertyValuesType);
			
			For Each RowCharacteristicProperties IN StringProductsAndServicesCharacteristic.Rows Do
				
				If Not ValueIsFilled(RowCharacteristicProperties.Property) Then
					Continue;
				EndIf;
				
				XDTOPropertyValues = XDTOFactory.Create(CMLPackage.Get("PropertyValues"));
				XDTOPropertyValues.ID = String(RowCharacteristicProperties.Property.UUID());
				XDTOPropertyValues.Description = DescriptionFormatForXDTO(RowCharacteristicProperties.Description);
				
				If RowCharacteristicProperties.Value = NULL Then
					
					// If the attribute value is not filled, we export the empty string.
					PropertyValue = "";
					
				Else
					
					PropertyValueType = TypeOf(RowCharacteristicProperties.Value);
					If PropertyValueType = Type("Date") Then
						
						PropertyValue = DateFormatForXDTO(RowCharacteristicProperties.Value);
						
					Else
						
						PropertyValue = String(RowCharacteristicProperties.Value);
						
					EndIf;
					
				EndIf;
				
				XDTOPropertyValues.Value.Add(PropertyValue);
				XDTOPropertiesValues.PropertyValues.Add(XDTOPropertyValues);
				
			EndDo;
			
			If XDTOPropertiesValues.PropertyValues.Count() > 0 Then
				XDTOProductCharacteristic.PropertyValues = XDTOPropertiesValues;
			EndIf;
			
			XDTOProductCharacteristics.ProductCharacteristic.Add(XDTOProductCharacteristic);
			
		EndDo;
	EndDo;
	
	XDTOProduct.ProductCharacteristics = XDTOProductCharacteristics;
	
EndProcedure

Procedure AddWarehousesToXDTOOffersPackage(XDTOOffersPackage, CMLPackage, Parameters)

	WarehousesSelection = Parameters.WarehousesSelection;
	If WarehousesSelection.Count() = 0 Then
		Return;
	EndIf;
	
	WarehousesType = GetPropertyTypeFromXDTOObjectType(CMLPackage.Get("OffersPackage"), "Warehouses");
	XDTOWarehouses = XDTOFactory.Create(WarehousesType);
	
	WarehousesSelection.Reset();
	While WarehousesSelection.Next() Do
		
		WarehouseType = CMLPackage.Get("Warehouse");
		XDTOWarehouse = XDTOFactory.Create(WarehouseType);
		
		WarehouseId = ExchangeWithSiteReUse.GenerateObjectUUID(WarehousesSelection.Warehouse);
		
		XDTOWarehouse.ID = WarehouseId;
		XDTOWarehouse.Description = DescriptionFormatForXDTO(WarehousesSelection.Description);
		
		CISelection = WarehousesSelection.ContactInformation.Select();
		If CISelection.Count() > 0 Then
			
			//Address
			SearchStructure = New Structure;
			SearchStructure.Insert("Type", Enums.ContactInformationTypes.Address);
			SearchStructure.Insert("Kind", Catalogs.ContactInformationTypes.StructuralUnitsFactAddress);
			
			If CISelection.FindNext(SearchStructure)
				AND Not IsBlankString(CISelection.Presentation) Then
				
				XDTOStructuralUnitAddress = XDTOFactory.Create(CMLPackage.Get("Address"));
				XDTOStructuralUnitAddress.Presentation = CISelection.Presentation;
				
				FieldsValues = ContactInformationManagement.PreviousFormatContactInformationXML(CISelection.FieldsValues, True);
				FieldList = ConvertStringToFieldList(FieldsValues);
				For Each CIField IN FieldList Do
					
					If CIField.Presentation = "IndexOf" Then
						
						AddXDTOAddressField(XDTOStructuralUnitAddress, "Postal index", CIField.Value, CMLPackage);
						
					ElsIf CIField.Presentation = "Settlement" Then
						
						AddXDTOAddressField(XDTOStructuralUnitAddress, "Settlement", CIField.Value, CMLPackage);
						
					ElsIf CIField.Presentation = "Region"
						OR CIField.Presentation = "District"
						OR CIField.Presentation = "City"
						OR CIField.Presentation = "Street"
						OR CIField.Presentation = "Building"
						OR CIField.Presentation = "Section"
						OR CIField.Presentation = "Apartment"
						OR CIField.Presentation = "Country" Then
						
						AddXDTOAddressField(XDTOStructuralUnitAddress, CIField.Presentation, CIField.Value, CMLPackage);
						
					EndIf;
					
				EndDo;
				
				XDTOWarehouse.Address = XDTOStructuralUnitAddress;
				
			EndIf;
			
			//Phone
			CISelection.Reset();
			
			SearchStructure = New Structure;
			SearchStructure.Insert("Type", Enums.ContactInformationTypes.Phone);
			SearchStructure.Insert("Kind", Catalogs.ContactInformationTypes.StructuralUnitsPhone);
			
			If CISelection.FindNext(SearchStructure)
				AND Not IsBlankString(CISelection.Presentation) Then
				
				ContactsType = GetPropertyTypeFromXDTOObjectType(WarehouseType, "Contacts");
				XDTOContacts = XDTOFactory.Create(ContactsType);
				
				XDTOContact = XDTOFactory.Create(CMLPackage.Get("Contact"));
				
				XDTOContact.Type = "Work phone";
				XDTOContact.Value = CISelection.Presentation;
				
				Comment = ContactInformationManagement.ContactInformationComment(CISelection.FieldsValues);
				If Not IsBlankString(Comment) Then
					XDTOContact.Comment = Format(Comment, 3000);
				EndIf;
				
				XDTOContacts.Contact.Add(XDTOContact);
				XDTOWarehouse.Contacts = XDTOContacts;
				
			EndIf;
		EndIf;
		
		XDTOWarehouses.Warehouse.Add(XDTOWarehouse);
		
	EndDo;
	
	XDTOOffersPackage.Warehouses = XDTOWarehouses;

EndProcedure

Procedure AddBalanceByXDTOWarehouses(XDTOOffer, WarehouseType, SelectionOfPrice, Parameters)
	
	WarehousesSelection = Parameters.WarehousesSelection;
	WarehousesSelection.Reset();
	
	While WarehousesSelection.Next() Do
		
		WarehouseId = String(WarehousesSelection.Warehouse.UUID());
		QuantityInStock = 0;
		
		SearchStructure = New Structure("ProductsAndServices, Characteristic", SelectionOfPrice.ProductsAndServices, SelectionOfPrice.Characteristic);
		FoundStrings = Parameters.BalanceTableWarehouses.FindRows(SearchStructure);
		
		For Each ArrayRow IN FoundStrings Do
			If ArrayRow.Warehouse = WarehousesSelection.Warehouse Then
				QuantityInStock = ArrayRow.QuantityInStock;
				Break;
			EndIf;
		EndDo;
		
		XDTOWarehouse = XDTOFactory.Create(WarehouseType);
		XDTOWarehouse.WarehouseId = WarehouseId;
		XDTOWarehouse.QuantityInStock = QuantityInStock;
		
		XDTOOffer.Warehouse.Add(XDTOWarehouse);
		
	EndDo;

EndProcedure
