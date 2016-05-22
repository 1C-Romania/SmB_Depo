////////////////////////////////////////////////////////////////////////////////
// Subsystem "Information center".
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROGRAMMING INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Add the handlers of service events (subscriptions)

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ServerHandlers["StandardSubsystems.SaaS.MessageExchange\OnDefenitionMessagesFeedHandlers"].Add(
			"InformationCenterService");
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("StandardSubsystems.SaaS.SuppliedData") Then
		ServerHandlers["StandardSubsystems.SaaS.SuppliedData\OnDefenitionHandlersProvidedData"].Add(
			"InformationCenterService");
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("StandardSubsystems.SaaS") Then
		ServerHandlers[
			"StandardSubsystems.SaaS\WhenCompletingTablesOfParametersOfIB"].Add(
				"InformationCenterService");
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("StandardSubsystems.SaaS") Then
		ServerHandlers["StandardSubsystems.SaaS.MessageExchange\RegistrationOfReceivedMessageInterfaces"].Add(
			"InformationCenterService");
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("StandardSubsystems.SaaS") Then
		ServerHandlers["StandardSubsystems.BasicFunctionality\OnDefenitionSupportedVersionsOfSoftwareInterfaces"].Add(
			"InformationCenterService");
	EndIf;
	
	If CommonUseClientServer.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers[
			"ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport"].Add(
				"InformationCenterService");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Service events handlers of the SLL subsystems

// Fills the transferred array with common modules which
//  comprise the handlers of received messages interfaces
//
// Parameters:
//  ArrayOfHandlers - array
//
Procedure RegistrationOfReceivedMessageInterfaces(ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(InformationCenterMessagesInterface);
	
EndProcedure

// Fills the structure with the arrays of supported
// versions of all subsystems subject to versioning and uses subsystems names as keys.
// Provides the functionality of InterfaceVersion Web-service.
// during the implementation the body of the procedure shall be changed so it will return relevant version sets (see ex.below).
//
// Parameters:
// SupportedVersionStructure - Structure: 
// - Keys = Names of the subsystems. 
// - Values = Arrays of supported version names.
//
// Example of implementation:
//
// // FileTransferServer
// VersionsArray = New Array;
// VersionsArray.Add("1.0.1.1");	
// VersionsArray.Add("1.0.2.1"); 
// SupportedVersionsStructure.Insert("FileTransferServer", VersionsArray);
// // End FileTransferService
//
Procedure OnDefenitionSupportedVersionsOfSoftwareInterfaces(Val SupportedVersionStructure) Export
	
	VersionArray = New Array;
	VersionArray.Add("1.0.1.1");
	SupportedVersionStructure.Insert("SupportServiceData", VersionArray);
	
EndProcedure

// Generates a list of IB parameters.
//
// Parameters:
// ParameterTable - ValueTable - parameters description table.
// Description columns content - see SaaSOperations.GetIBParameterTable()
//
Procedure WhenCompletingTablesOfParametersOfIB(Val ParameterTable) Export
	
	ModuleSaaSOperations = ServiceTechnologyIntegrationWithSSL.CommonModule("SaaSOperations");
	ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "ConferenceManagementAddress");
	ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "InformationCentreConferenceUserName");
	ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "InformationCenterConferenceUserPassword");
	
	ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "SupportServiceSoftwareInterfaceAddress");
	ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "SupportServiceSoftwareInterfaceUserName");
	ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "SupportServiceSoftwareInterfaceUserPassword");
	
EndProcedure

// Gets the list of message handlers that handle library subsystems.
// 
// Parameters:
//  Handlers - ValueTable - for the field content see MessageExchange.NewMessageHandlersTable
// 
Procedure OnDefenitionMessagesFeedHandlers(Handlers) Export
	
	InformationCenterMessagesMessageHandler.GetMessageChannelHandlers(Handlers);
	
EndProcedure

// Register provided data handlers
//
// When receiving notifications of new common data availability
// the NewDataAvailable procedure of the modules registered using GetProvidedDataHandlers is called.
// Descriptor is passed to the procedure - XDTOObject Descriptor.
// 
// If NewDataAvailable sets the Import argument to the True value, the data is imported, the handle and the file path with data are passed to the ProcessNewData procedure. File will be automatically deleted after procedure completed.
// If the file was not specified in the service manager - The argument value is Undefined.
//
// Parameters: 
//   Handlers, ValueTable - The table for adding handlers. 
//       Columns:
//        DataKind, string - data kind code processed by the handler
//        HandlerCode, string(20) - will be used at dataprocessor recovery after the Handler failure,
//        CommonModule - the module that contains the following procedures:
//          AvailableNewData(Handle, Import) Export
//          ProcessNewData(Handle, PathToFile) Export 
//          DataProcessingCanceled(Handle) Export
//
Procedure OnDefenitionHandlersProvidedData(Handlers) Export
	
	RegisterProvidedDataHandlers(Handlers);
	
EndProcedure

// Fills the array of types excluded from the import and export of data.
//
// Parameters:
//  Types - Array(Types).
//
Procedure WhenFillingTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.InformationRegisters.InformationCenterViewedData);
	
EndProcedure

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
//
Procedure OnAddUpdateHandlers(Handlers) Export
	
	RegisterUpdateHandlers(Handlers);
	
EndProcedure

// Adds to the Handlers
// list update handler procedures required to this subsystem.
//
// Parameters:
//   Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler                  = Handlers.Add();
	Handler.Version          = "*";
	Handler.ExclusiveMode    = False;
	Handler.SharedData       = True;
	Handler.Procedure        = "InformationCenterService.GenerateFullyQualifiedPathsToDictionaryForms";
	
	Handler                    = Handlers.Add();
	Handler.Version            = "1.0.5.12";
	Handler.ExclusiveMode      = False;
	Handler.SharedData         = True;
	Handler.InitialFilling     = True;
	Handler.Procedure          = "InformationCenterService.FillFullPathHashToForm";
	
	Handler                     = Handlers.Add();
	Handler.Version             = "1.0.3.35";
	Handler.ExclusiveMode       = False;
	Handler.SharedData          = True;
	Handler.InitialFilling      = True;
	Handler.Procedure           = "InformationCenterService.FillEndDateOfRelevanceOfInformationLinks";
	
	If ServiceTechnologyIntegrationWithSSL.DataSeparationEnabled() Then
		Handler                  = Handlers.Add();
		Handler.Version          = "*";
		Handler.ExclusiveMode    = False;
		Handler.SharedData       = True;
		Handler.Procedure        = "InformationCenterService.UpdateInformationReferencesForFormsSaaS";
	Else
		Handler                  = Handlers.Add();
		Handler.Version          = "*";
		Handler.ExclusiveMode    = False;
		Handler.Procedure        = "InformationCenterService.UpdateInformationReferencesForFormsInLocalMode";
	EndIf;
	
EndProcedure

// Fills out catalog "FullPathsToForms" with full paths to forms.
//
Procedure GenerateFullyQualifiedPathsToDictionaryForms() Export
	
	// Create a table of full form list of configuration
	TableForms = New ValueTable;
	TableForms.Columns.Add("FullPathToForm", New TypeDescription("String"));
	
	AddFormsCatalog(TableForms, "CommonForms");
	AddFormsCatalog(TableForms, "ExchangePlans");
	AddFormsCatalog(TableForms, "Catalogs");
	AddFormsCatalog(TableForms, "Documents");
	AddFormsCatalog(TableForms, "DocumentJournals");
	AddFormsCatalog(TableForms, "Enums");
	AddFormsCatalog(TableForms, "Reports");
	AddFormsCatalog(TableForms, "DataProcessors");
	AddFormsCatalog(TableForms, "ChartsOfCharacteristicTypes");
	AddFormsCatalog(TableForms, "ChartsOfAccounts");
	AddFormsCatalog(TableForms, "ChartsOfCalculationTypes");
	AddFormsCatalog(TableForms, "InformationRegisters");
	AddFormsCatalog(TableForms, "AccumulationRegisters");
	AddFormsCatalog(TableForms, "AccountingRegisters");
	AddFormsCatalog(TableForms, "CalculationRegisters");
	AddFormsCatalog(TableForms, "BusinessProcesses");
	AddFormsCatalog(TableForms, "Tasks");
	AddFormsCatalog(TableForms, "SettingsStorages");
	AddFormsCatalog(TableForms, "FilterCriteria");
	
	// Filling catalog "FullPathsToForms"
	Query = New Query;
	Query.SetParameter("TableForms", TableForms);
	Query.Text =
	"SELECT
	|	SubString(TableForms.FullPathToForm, 1, 1000) AS FullPathToForm
	|INTO TableForms
	|FROM
	|	&TableForms AS TableForms
	|
	|INDEX BY
	|	FullPathToForm
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FullPathsToForms.Ref AS Ref,
	|	SubString(FullPathsToForms.FullPathToForm, 1, 1000) AS FullPathToForm
	|INTO ExistingFullPathsToForms
	|FROM
	|	Catalog.FullPathsToForms AS FullPathsToForms
	|
	|INDEX BY
	|	FullPathToForm
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableForms.FullPathToForm AS FullPathToForm
	|FROM
	|	TableForms AS TableForms
	|		LEFT JOIN ExistingFullPathsToForms AS ExistingFullPathsToForms
	|		ON (TableForms.FullPathToForm = ExistingFullPathsToForms.FullPathToForm)
	|WHERE
	|	ExistingFullPathsToForms.Ref IS NULL ";
	FormSelection = Query.Execute().Select();
	While FormSelection.Next() Do 
		AddFullNameInCatalog(FormSelection.FullPathToForm);
	EndDo;
	
EndProcedure

// When updating the configuration, it is required to update a list of Information references for form.
// It is performed using Service manager.
//
Procedure UpdateInformationReferencesForFormsSaaS() Export
	
	Try
		SetPrivilegedMode(True);
		ConfigurationName = Metadata.Name;
		SetPrivilegedMode(False);
		WebServicesProxy = InformationCenterServer.GetInformationCenterProxy_1_0_1_1();
		Result = WebServicesProxy.UpdateInfoReference(ConfigurationName);
		If Result Then 
			Return;
		EndIf;
		
		ErrorText = NStr("en = 'Failed to update Information references'");
		EventName = InformationCenterServer.GetEventNameForEventLogMonitor();
		WriteLogEvent(EventName, EventLogLevel.Error, , , ErrorText);
	Except
		EventName = InformationCenterServer.GetEventNameForEventLogMonitor();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// When updating the configuration, it is required to update a list of Information references for form.
// It is performed using Service manager.
//
Procedure UpdateInformationReferencesForFormsInLocalMode() Export
	
	PathToFile = GetTempFileName("xml");
	If IsBlankString(PathToFile) Then 
		Return;
	EndIf;
	
	TextDocument = GetCommonTemplate("InformationReferences");
	TextDocument.Write(PathToFile);
	Try
		ImportInformationReferences(PathToFile);
	Except
		EventName = InformationCenterServer.GetEventNameForEventLogMonitor();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Returns a string presentation of the version in a number range.
//
// Parameters:
//  Version - String - version.
//
// Returns:
//  Number - version presentation as a number.
//
Function GetVersionByNumber(Version) Export
	
	NumbersArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Version, ".");
	
	Iteration           = 1;
	VersionByNumber       = 0;
	QuantityInArray = NumbersArray.Count();
	
	If QuantityInArray = 0 Then 
		Return 0;
	EndIf;
	
	For Each VersionNumber IN NumbersArray Do 
		
		Try
			CurrentNumber = Number(VersionNumber);
			VersionByNumber = VersionByNumber + CurrentNumber * BuildNumberInPositiveDegree(1000, QuantityInArray - Iteration);
		Except
			Return 0;
		EndTry;
		
		Iteration = Iteration + 1;
		
	EndDo;
	
	Return VersionByNumber;
	
EndFunction

// Fills out items of catalog "InformationRefsForForms" whose relevance end dates are empty with date "12/31/3999".
// 
Procedure FillEndDateOfRelevanceOfInformationLinks() Export 
	
	Query = New Query;
	Query.SetParameter("ActualityEndingDate", '00010101000000');
	Query.Text =
	"SELECT
	|	InformationReferencesForForms.Ref AS InformationReference
	|FROM
	|	Catalog.InformationReferencesForForms AS InformationReferencesForForms
	|WHERE
	|	InformationReferencesForForms.ActualityEndingDate = &ActualityEndingDate
	|	AND Not InformationReferencesForForms.DeletionMark";
	Selection = Query.Execute().Select();
	While Selection.Next() Do 
		
		InformationReference = Selection.InformationReference.GetObject();
		InformationReference.Write();
		
	EndDo;
	
EndProcedure

// Fills out hash (by MD5 algorithm) of a full path to a form in catalog "FullPathsToForms"
//
Procedure FillFullPathHashToForm() Export
	
	Query = New Query(
		"SELECT
		|	FullPathsToForms.Ref
		|FROM
		|	Catalog.FullPathsToForms AS FullPathsToForms
		|WHERE
		|	FullPathsToForms.Hash = &Hash");
	Query.SetParameter("Hash", "");
	Selection = Query.Execute().Select();
	While Selection.Next() Do 
		RecordObject = Selection.Ref.GetObject();
		RecordObject.Write();
	EndDo;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// HANDLERS OF SUPPLIED DATA RECEIPT

// Registers handlers of supplied data for a day and for the whole period
//
Procedure RegisterProvidedDataHandlers(Val Handlers) Export
	
	Handler                = Handlers.Add();
	Handler.DataKind      = "InformationReferences";
	Handler.ProcessorCode = "InformationReferences";
	Handler.Handler     = InformationCenterService;
	
EndProcedure

// It is called when a notification of new data received.
// IN the body you should check whether this data is necessary for the application, and if so, - select the Import check box.
// 
// Parameters:
//   Descriptor - XDTOObject Descriptor.
//   Import     - Boolean, return
//
Procedure AvailableNewData(Val Handle, Import) Export
	
	If Handle.DataType = "InformationReferences" Then
		
		ConfigurationName = GetNameOfConfigurationDescriptor(Handle);
		If ConfigurationName = Undefined Then 
			Import = False;
			Return;
		EndIf;
		
		Import = ?(Upper(Metadata.Name) = Upper(ConfigurationName), True, False);
		
	EndIf;
	
EndProcedure

// It is called after the call AvailableNewData, allows you to parse data.
//
// Parameters:
//   Descriptor   - XDTOObject Descriptor.
//   PathToFile   - String or Undefined. The full name of the extracted file. File will be automatically
//                  deleted after procedure completed. If the file was not
//                  specified in the service manager - The argument value is Undefined.
//
Procedure ProcessNewData(Val Handle, Val PathToFile) Export
	
	If Handle.DataType = "InformationReferences" Then
		ProcessInformationalRefs(Handle, PathToFile);
	EndIf;
	
EndProcedure

// It is called when cancelling data processing in case of a failure.
//
Procedure DataProcessingCanceled(Val Handle) Export 
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

Procedure ProcessInformationalRefs(Handle, PathToFile)
	
	ImportInformationReferences(PathToFile);
	
EndProcedure

Function GetNameOfConfigurationDescriptor(Handle)
	
	For Each Characteristic IN Handle.Properties.Property Do
		If Characteristic.Code = "LocationObject" Then
			Try
				Return Characteristic.Value;
			Except
				EventName = InformationCenterServer.GetEventNameForEventLogMonitor();
				WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
				Return Undefined;
			EndTry;
			Break;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

Procedure ImportInformationReferences(PathToFile)
	
	// Creating a tag tree
	TagsTree = GetTagsTree();
	
	UpdateDate = CurrentDate(); // Project decision SSL
	
	TypeInformationReferences    = XDTOFactory.Type("http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter/InformationReferences", "reference"); 
	ReadInformationLinks = New XMLReader; 
	ReadInformationLinks.OpenFile(PathToFile); 
	
	ReadInformationLinks.MoveToContent();
	ReadInformationLinks.Read();
	
	While ReadInformationLinks.NodeType = XMLNodeType.StartElement Do 
		
		InformationReference = XDTOFactory.ReadXML(ReadInformationLinks, TypeInformationReferences);
		
		// Predefined item
		If Not IsBlankString(InformationReference.namePredifined) Then 
			Try
				WritePredefinedInfoRef(InformationReference);
			Except
				EventName = InformationCenterServer.GetEventNameForEventLogMonitor();
				WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
			EndTry;
			Continue;
		EndIf;
		
		// Ordinary item
		If TypeOf(InformationReference.context) = Type("XDTOList") Then 
			For Each Context in InformationReference.context Do 
				Try
					WriteRefByContexts(TagsTree, InformationReference, Context, UpdateDate);
				Except
					EventName = InformationCenterServer.GetEventNameForEventLogMonitor();
					WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
				EndTry;
			EndDo;
		Else
			WriteRefByContexts(TagsTree, InformationReference, InformationReference.context, UpdateDate);
		EndIf;
		
	EndDo;
	
	ReadInformationLinks.Close();
	
	ClearNotUpdatedRefs(UpdateDate);
	
EndProcedure

Procedure WritePredefinedInfoRef(ReferenceObject)
	
	Try
		CatalogItem = Catalogs.InformationReferencesForForms[ReferenceObject.namePredifined].GetObject();
	Except
		EventName = InformationCenterServer.GetEventNameForEventLogMonitor();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	CatalogItem.Address                     = ReferenceObject.address;
	CatalogItem.ActualityBeginningDate    = ReferenceObject.dateFrom;
	CatalogItem.ActualityEndingDate = ReferenceObject.dateTo;
	CatalogItem.Description              = ReferenceObject.name;
	CatalogItem.ToolTip                 = ReferenceObject.helpText;
	CatalogItem.Write();
	
EndProcedure

Procedure ClearNotUpdatedRefs(UpdateDate)
	
	SetPrivilegedMode(True);
	CatalogSelection = Catalogs.InformationReferencesForForms.Select();
	While CatalogSelection.Next() Do 
		
		If CatalogSelection.Predefined Then 
			Continue;
		EndIf;
		
		If CatalogSelection.UpdateDate = UpdateDate Then 
			Continue;
		EndIf;
		
		Object = CatalogSelection.GetObject();
		Object.DataExchange.Load = True;
		Object.Delete();
		
	EndDo;
	
EndProcedure

Procedure WriteRefByContexts(TagsTree, ReferenceObject, Context, UpdateDate)
	
	Result = CheckExistenceOfFormsTagName(Context.tag);
	If Result.ThisIsPathToForm Then 
		WriteRefByContext(ReferenceObject, Context, Result.PathToForm, UpdateDate);
		Return;
	EndIf;
	
	Tag             = Context.tag;
	FoundString = TagsTree.Rows.Find(Tag, "Name");
	If FoundString = Undefined Then 
		WriteReferenceByIdentifier(ReferenceObject, Context, UpdateDate);
		Return;
	EndIf;
	
	For Each TreeRow in FoundString.Rows Do 
		
		FormName = TreeRow.Name;
		ReferenceToPathToForm = RefsToFormInDirectory(FormName);
		If ReferenceToPathToForm.IsEmpty() Then 
			Continue;
		EndIf;
		
		WriteRefByContext(ReferenceObject, Context, ReferenceToPathToForm, UpdateDate);
		
	EndDo;
	
EndProcedure

Procedure WriteReferenceByIdentifier(ReferenceObject, Context, UpdateDate)
	
	CatalogItem = Catalogs.InformationReferencesForForms.CreateItem();
	CatalogItem.Address                     = ReferenceObject.address;
	CatalogItem.ID             = Context.tag;
	CatalogItem.Weight                       = Context.weight;
	CatalogItem.ActualityBeginningDate    = ReferenceObject.dateFrom;
	CatalogItem.ActualityEndingDate = ReferenceObject.dateTo;
	CatalogItem.Description              = ReferenceObject.name;
	CatalogItem.ToolTip                 = ReferenceObject.helpText;
	CatalogItem.ConfigurationVersionFrom      = GetVersionByNumber(Context.versionFrom);
	CatalogItem.ConfigurationVersionBefore      = GetVersionByNumber(Context.versionTo);
	CatalogItem.UpdateDate            = UpdateDate;
	CatalogItem.Write();
	
EndProcedure

Procedure WriteRefByContext(ReferenceObject, Context, ReferenceToPathToForm, UpdateDate)
	
	Ref = HavingInfoRefForCurrentForm(ReferenceObject.address, ReferenceToPathToForm);
	
	If Ref = Undefined Then 
		CatalogItem = Catalogs.InformationReferencesForForms.CreateItem();
	Else
		CatalogItem = Ref.GetObject();
	EndIf;
	
	CatalogItem.Address                     = ReferenceObject.address;
	CatalogItem.Weight                       = Context.weight;
	CatalogItem.ActualityBeginningDate    = ReferenceObject.dateFrom;
	CatalogItem.ActualityEndingDate = ReferenceObject.dateTo;
	CatalogItem.Description              = ReferenceObject.name;
	CatalogItem.ToolTip                 = ReferenceObject.helpText;
	CatalogItem.FullPathToForm          = ReferenceToPathToForm;
	CatalogItem.ConfigurationVersionFrom      = GetVersionByNumber(Context.versionFrom);
	CatalogItem.ConfigurationVersionBefore      = GetVersionByNumber(Context.versionTo);
	CatalogItem.UpdateDate            = UpdateDate;
	CatalogItem.Write();
	
EndProcedure

Function HavingInfoRefForCurrentForm(Address, ReferenceToPathToForm)
	
	Query = New Query;
	Query.SetParameter("FullPathToForm", ReferenceToPathToForm);
	Query.SetParameter("Address",            Address);
	Query.Text = "SELECT
	               |	InformationReferencesForForms.Ref AS Ref
	               |FROM
	               |	Catalog.InformationReferencesForForms AS InformationReferencesForForms
	               |WHERE
	               |	InformationReferencesForForms.FullPathToForm = &FullPathToForm
	               |	AND InformationReferencesForForms.Address LIKE &Address";
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do 
		Return Selection.Ref;
	EndDo;
	
	Return Undefined;
	
EndFunction

Function CheckExistenceOfFormsTagName(Tag)
	
	Result = New Structure("ThisIsPathToForm", False);
	
	Query = New Query;
	Query.SetParameter("FullPathToForm", Tag);
	Query.Text = 
	"SELECT
	|	FullPathsToForms.Ref AS Ref
	|FROM
	|	Catalog.FullPathsToForms AS FullPathsToForms
	|WHERE
	|	FullPathsToForms.FullPathToForm LIKE &FullPathToForm";
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then 
		Return Result;
	EndIf;
	
	Result.ThisIsPathToForm = True;
	QuerySelection = QueryResult.Select();
	While QuerySelection.Next() Do 
		Result.Insert("PathToForm", QuerySelection.Ref);
		Return Result;
	EndDo;
	
EndFunction

Function GetTagsTree()
	
	TagsTree = New ValueTree;
	TagsTree.Columns.Add("Name", New TypeDescription("String"));
	
	// Reading common template
	TemplateFileName = GetTempFileName("xml");
	GetCommonTemplate("TagConformityWithCommonForms").Write(TemplateFileName);
	
	TagsAndFormsCorrespondenceRecords = New XMLReader;
	TagsAndFormsCorrespondenceRecords.OpenFile(TemplateFileName);
	
	CurrentTagInTree = Undefined;
	While TagsAndFormsCorrespondenceRecords.Read() Do
		// Reading the current tag
		IsTag = TagsAndFormsCorrespondenceRecords.NodeType = XMLNodeType.StartElement and Upper(TrimAll(TagsAndFormsCorrespondenceRecords.Name)) = Upper("tag");
		If IsTag Then 
			While TagsAndFormsCorrespondenceRecords.ReadAttribute() Do 
				If Upper(TagsAndFormsCorrespondenceRecords.Name) = Upper("name") Then
					CurrentTagInTree     = TagsTree.Rows.Add();
					CurrentTagInTree.Name = TagsAndFormsCorrespondenceRecords.Value;
					Break;
				EndIf;
			EndDo;
		EndIf;
		// Read a form
		IsForm = TagsAndFormsCorrespondenceRecords.NodeType = XMLNodeType.StartElement and Upper(TrimAll(TagsAndFormsCorrespondenceRecords.Name)) = Upper("form");
		If IsForm Then 
			While TagsAndFormsCorrespondenceRecords.ReadAttribute() Do 
				If Upper(TagsAndFormsCorrespondenceRecords.Name) = Upper("path") Then
					If CurrentTagInTree = Undefined Then 
						Break;
					EndIf;
					CurrentTreeItem     = CurrentTagInTree.Rows.Add();
					CurrentTreeItem.Name = TagsAndFormsCorrespondenceRecords.Value;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	Return TagsTree;
	
EndFunction

Procedure AddFormsCatalog(TableForms, NameOfMetadataClass)
	
	MetadataClass     = Metadata[NameOfMetadataClass];
	ItemCount = MetadataClass.Count();
	If NameOfMetadataClass = "CommonForms" Then 
		For IterationOfElements = 0 To ItemCount - 1 Do 
			
			FullPathToForm = MetadataClass.Get(IterationOfElements).FullName();
			
			TableElement                  = TableForms.Add();
			TableElement.FullPathToForm = FullPathToForm;
			
		EndDo;
		Return;
	EndIf;
	
	For IterationOfElements = 0 To ItemCount - 1 Do 
		FormsOfMetadata = MetadataClass.Get(IterationOfElements).Forms;
		FormsQuantity        = FormsOfMetadata.Count();
		For FormIteration = 0 To FormsQuantity - 1 Do 
			
			FullPathToForm = FormsOfMetadata.Get(FormIteration).FullName();
			
			TableElement                  = TableForms.Add();
			TableElement.FullPathToForm = FullPathToForm;
			
		EndDo;
	EndDo;
	
EndProcedure

Procedure AddFullNameInCatalog(FormFullName)
	
	SetPrivilegedMode(True);
	CatalogItem = Catalogs.FullPathsToForms.CreateItem();
	CatalogItem.Description     = FormFullName;
	CatalogItem.FullPathToForm = FormFullName;
	CatalogItem.Write();
	
EndProcedure

Function RefsToFormInDirectory(FormFullName)
	
	Query = New Query;
	Query.SetParameter("FullPathToForm", FormFullName);
	Query.Text = 
	"SELECT
	|	FullPathsToForms.Ref AS Ref
	|FROM
	|	Catalog.FullPathsToForms AS FullPathsToForms
	|WHERE
	|	FullPathsToForms.FullPathToForm LIKE &FullPathToForm";
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do 
		Return Selection.Ref;
	EndDo;
	
	Return Catalogs.FullPathsToForms.EmptyRef();
	
EndFunction

// Exponentiation
//
// Parameters:
//  Number - Number - Number raised to a given power.
//  Degree - Number - power into which a number is to be raised.
//
// Returns:
//  Number - number to the exponent.
//
Function BuildNumberInPositiveDegree(Number, Degree)
	
	If Degree = 0 Then 
		Return 1;
	EndIf;
	
	If Degree = 1 Then 
		Return Number;
	EndIf;
	
	ReturnNumber = Number;
	
	For Iteration = 2 to Degree Do 
		ReturnNumber = ReturnNumber * Number;
	EndDo;
	
	Return ReturnNumber;
	
EndFunction





