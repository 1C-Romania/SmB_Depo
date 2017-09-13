////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// Procedure-handler of the OnCreateAtServer event for form of the exchange plan node.
//
// Parameters:
//  Form - ManagedForm - form from which the procedure was called.
//  Cancel - Boolean           - shows that form creation has been denied. If it is set to True, then the form will not be created.
// 
Procedure NodeFormOnCreateAtServer(Form, Cancel) Export
	
	If Form.Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Form.AutoTitle = False;
	Form.Title = StringFunctionsClientServer.SubstituteParametersInString( Form.Object.Description + " (%1)",
	                                                                           OverridableExchangePlanNodeName(Form.Object.Ref, "ExchangePlanNodeTitle"));
	
EndProcedure

// Procedure-handler of the OnCreateAtServer event for the form of exchange plan nodes setting.
//
// Parameters:
//  Form - ManagedForm - form from which the procedure was called.
//  Cancel - Boolean           - shows that form creation has been denied. If it is set to True, then the form will not be created.
// 
Procedure NodesSettingFormOnCreateAtServer(Form, Cancel) Export
	
	Parameters = Form.Parameters;
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	SettingID = "";
	
	If Form.Parameters.Property("SettingID") Then
		SettingID = Form.Parameters.SettingID;
	EndIf;
	
	SetMandatoryFormAttributes(Form, MandatoryFormAttributesNodesSettings());
	
	Form.CorrespondentVersion = Parameters.CorrespondentVersion;
	
	Context = New Structure;
	
	If Parameters.Property("GetDefaultValues") Then
		
		ExchangePlanName = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Form.FormName, ".")[1];
		
		FilterSsettingsAtNode                   = FilterSsettingsAtNode(ExchangePlanName, Parameters.CorrespondentVersion, , SettingID);
		CorrespondentInfobaseNodeFilterSetup = CorrespondentInfobaseNodeFilterSetup(ExchangePlanName, Parameters.CorrespondentVersion, , SettingID);
		ChangeTableSectionsStorageStructure(CorrespondentInfobaseNodeFilterSetup);
		
	Else
		
		FilterSsettingsAtNode = Form.Parameters.Settings.FilterSsettingsAtNode;
		CorrespondentInfobaseNodeFilterSetup = Form.Parameters.Settings.CorrespondentInfobaseNodeFilterSetup;
		
	EndIf;
	
	Context.Insert("FilterSsettingsAtNode", FilterSsettingsAtNode);
	Context.Insert("CorrespondentInfobaseNodeFilterSetup", CorrespondentInfobaseNodeFilterSetup);
	
	Form.Context = Context;
	
	FillFormData(Form);
	
	If Not Parameters.Property("FillChecking") AND Not Parameters.Property("GetDefaultValues") Then
		ExecuteFormTablesComparisonAndMerging(Form, Cancel);
	EndIf;
	
EndProcedure

// Procedure-handler of the OnCreateAtServer event for node setting form.
//
// Parameters:
//  Form          - ManagedForm - form from which the procedure was called.
//  ExchangePlanName - String           - name of the exchange plan for which the form has been created.
// 
Procedure NodeConfigurationFormOnCreateAtServer(Form, ExchangePlanName) Export
	
	If Form.Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	SettingID = "";
	
	If Form.Parameters.Property("SettingID") Then
		SettingID = Form.Parameters.SettingID;
	EndIf;
	
	ValidateRequiredFormAttributes(Form, "FilterSsettingsOnNode, CorrespondentVersion");
	
	Form.CorrespondentVersion   = Form.Parameters.CorrespondentVersion;
	Form.FilterSsettingsAtNode = FilterSsettingsAtNode(ExchangePlanName, Form.CorrespondentVersion, , SettingID);
	
	NodeSettingsFormOnCreateAtServerHandler(Form, "FilterSsettingsAtNode");
	
EndProcedure

// Procedure-handler of the OnCreateAtServer event for setting form of the correspondent base node.
//
// Parameters:
//  Form          - ManagedForm - form of the correspondent base.
//  ExchangePlanName - String           - name of the exchange plan for which the form has been created.
//  Data         - Map     - contains the list of data base tables for specifying data synchronization rules.
// 
Procedure CorrespondentInfobaseNodeSettingsFormOnCreateAtServer(Form, ExchangePlanName, Data = Undefined) Export
	
	If Form.Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	SettingID = "";
	
	If Form.Parameters.Property("SettingID") Then
		SettingID = Form.Parameters.SettingID;
	EndIf;
	
	ValidateRequiredFormAttributes(Form, "CorrespondentVersion, FilterSsettingsOnNode, ExternalConnectionParameters");
	
	Form.CorrespondentVersion        = Form.Parameters.CorrespondentVersion;
	Form.ExternalConnectionParameters = Form.Parameters.ExternalConnectionParameters;
	Form.FilterSsettingsAtNode      = CorrespondentInfobaseNodeFilterSetup(ExchangePlanName, Form.CorrespondentVersion, , SettingID);
	
	NodeSettingsFormOnCreateAtServerHandler(Form, "FilterSsettingsAtNode");
	
	If Data <> Undefined AND TypeOf(Data) = Type("Map") Then
		
		Connection = DataExchangeReUse.InstallOuterDatabaseJoin(Form.ExternalConnectionParameters);
		ErrorMessageString = Connection.DetailedErrorDescription;
		ExternalConnection       = Connection.Join;
		
		If ExternalConnection = Undefined Then
			Raise ErrorMessageString;
		EndIf;
		
		For Each Table IN Data Do
			
			If    Form.ExternalConnectionParameters.CorrespondentVersion_2_1_1_7
				OR Form.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
				
				CorrespondentInfobaseTable = CommonUse.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetTableObjects_2_0_1_6(Table.Key));
				
			Else
				
				CorrespondentInfobaseTable = ValueFromStringInternal(ExternalConnection.DataExchangeExternalConnection.GetTableObjects(Table.Key));
				
			EndIf;
			
			Data.Insert(Table.Key, ValuesTableFromValueTree(CorrespondentInfobaseTable));
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure-handler of the OnCreateAtServer event for the default values setting form.
//
// Parameters:                            
//  Form          - ManagedForm - form from which the procedure was called.
//  ExchangePlanName - String           - name of the exchange plan for which the form has been created.
// 
Procedure DefaultValuesConfigurationFormOnCreateAtServer(Form, ExchangePlanName) Export
	
	If Form.Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	SettingID = "";
	
	If Form.Parameters.Property("SettingID") Then
		SettingID = Form.Parameters.SettingID;
	EndIf;
	
	ValidateRequiredFormAttributes(Form, "DefaultValuesOnNode, CorrespondentVersion");
	
	Form.CorrespondentVersion      = Form.Parameters.CorrespondentVersion;
	Form.DefaultValuesAtNode = DefaultValuesAtNode(ExchangePlanName, Form.CorrespondentVersion, , SettingID);
	
	NodeSettingsFormOnCreateAtServerHandler(Form, "DefaultValuesAtNode");
	
EndProcedure

// Procedure-handler of the OnCreateAtServer event for the
// default values setting form via an external connection for the correspondent base.
//
// Parameters:                            
//  Form                - ManagedForm - form from which the procedure was called.
//  ExchangePlanName       - String           - name of the exchange plan for which the form has been created.
//  AdditionalInformation - Arbitrary     - for getting additional data.
// 
Procedure CorrespondentInfobaseDefaultValueSetupFormOnCreateAtServer(Form, ExchangePlanName, AdditionalInformation = Undefined) Export
	
	If Form.Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	SettingID = "";
	
	If Form.Parameters.Property("SettingID") Then
		SettingID = Form.Parameters.SettingID;
	EndIf;
	
	ValidateRequiredFormAttributes(Form, "CorrespondentVersion, DefaultValuesOnNode, ExternalConnectionParameters");
	
	Form.CorrespondentVersion        = Form.Parameters.CorrespondentVersion;
	Form.ExternalConnectionParameters = Form.Parameters.ExternalConnectionParameters;
	Form.DefaultValuesAtNode   = CorrespondentInfobaseNodeDefaultValues(ExchangePlanName, Form.CorrespondentVersion, , SettingID);
	
	NodeSettingsFormOnCreateAtServerHandler(Form, "DefaultValuesAtNode");
	
	If Form.ExternalConnectionParameters.ConnectionType = "TempStorage" Then
		
		AdditionalInformation = GetFromTempStorage(
			Form.ExternalConnectionParameters.TemporaryStorageAddress).Get().Get("{AdditionalData}");
	EndIf;
	
EndProcedure

// Deletes from the attributes list for the
// mandatory filling those attributes that are not displayed in the form.
//
// Parameters:
// CheckedAttributes - Array           - attributes list for which filling is checked.
// Items             - AllFormItems - contains collection of all items of the managed form.
//
Procedure GetAttributesToCheckDependingOnFormItemVisibleSettings(CheckedAttributes, Items) Export
	
	ReverseIndex = CheckedAttributes.Count() - 1;
	
	While ReverseIndex >= 0 Do
		
		AttributeName = CheckedAttributes[ReverseIndex];
		
		For Each Item IN Items Do
			
			If TypeOf(Item) = Type("FormField") Then
				
				If Item.DataPath = AttributeName
					AND Not Item.Visible Then
					
					CheckedAttributes.Delete(ReverseIndex);
					Break;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		ReverseIndex = ReverseIndex - 1;
		
	EndDo;
	
EndProcedure

// Defines if it is required to execute the handler of the AfterDataExport event during the exchange in DIB.
// 
// Parameters:
//  Object - ExchangePlanObject - exchange plan node for which the handler is executed.
//  Ref - ExchangePlanRef - reference to the exchange plan node for which handler is executed.
// 
//  Returns:
//   Boolean - if True, then it is required to execute the AfterDataExport handler; False - no.
//
Function NeedToExecuteHandlerAfterDataExport(Object, Ref) Export
	
	Return NeedToExecuteHandler(Object, Ref, "SentNo");
	
EndFunction

// Defines if it is required to execute the handler of the AfterDataImport event during the exchange in DIB.
// 
// Parameters:
//  Object - ExchangePlanObject - exchange plan node for which the handler is executed.
//  Ref - ExchangePlanRef - reference to the exchange plan node for which handler is executed.
// 
//  Returns:
//   Boolean - if True, then it is required to execute the AfterDataImport handler; False - no.
//
Function NeedToExecuteHandlerAfterDataImport(Object, Ref) Export
	
	Return NeedToExecuteHandler(Object, Ref, "ReceivedNo");
	
EndFunction

// Returns prefix of this infobase.
//
// Returns:
//   String
//
Function InfobasePrefix() Export
	
	Return GetFunctionalOption("InfobasePrefix");
	
EndFunction

// Returns the version of correspondent configuration.
// If version of the correspondent configuration is not defined, then returns an empty version - "0.0.0.0".
//
// Parameters:
//  Correspondent - ExchangePlanRef - exchange plan node for which it is required to receive the configuration version.
// 
// Returns:
//  String - version of the correspondent configuration.
//
// Example:
//  If CommonUseClientServer.CompareVersions(DataExchangeServer.CorrespondentVersion(Correspondent), 2.1.5.1) >= 0 Then ...
//
Function CorrespondentVersion(Val Correspondent) Export
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.InfobasesNodesCommonSettings.CorrespondentVersion(Correspondent);
EndFunction

// Sets prefix for this infobase.
//
// Parameters:
//   Prefix - String - new value of the infobase prefix.
//
Procedure SetIBPrefix(Val Prefix) Export
	
	Constants.DistributedInformationBaseNodePrefix.Set(TrimAll(Prefix));
	
	DataExchangeServerCall.ResetCacheMechanismForRegistrationOfObjects();
	
EndProcedure

// Checks whether this base is restored from backup.
// If the base is restored from the backup, then you need to synchronize
// the numbers of the sent and received messages for two bases (value of the
// message number received from the base-correspondent is assigned to the sent message number).
// If database is restored from a backup, it is recommended not to withdraw from
// the registration the changes of data on the current node as this data may not have been sent.
//
// Parameters:
//   Sender    - ExchangePlanRef - node on behalf of which exchange message was generated and sent.
//   ReceivedNo - Number            - number of the received message in the base-correspondent.
//
// Returns:
//   FixedStructure - structure properties:
//     * Sender                 - ExchangePlanRef - see above the Sender parameter.
//     * ReceivedNumber              - Number            - see above the ReceivedNumber parameter.
//     * BackupRestored - Boolean - True if the fact of the base restoration from the backup is found.
//
Function BackupCopiesParameters(Val Sender, Val ReceivedNo) Export
	
	// For the base that was found in the backup the
	// number of the sent message will be
	// lower than the number of the received
	// message in the correspondent. That means that this base will receive the number of the received message that was not sent - message from the future.
	Result = New Structure("Sender, ReceivedNo, BackupRestored");
	Result.Sender = Sender;
	Result.ReceivedNo = ReceivedNo;
	Result.BackupRestored = (ReceivedNo > CommonUse.ObjectAttributeValue(Sender, "SentNo"));
	
	Return New FixedStructure(Result);
EndFunction

// Synchronizes the numbers of the sent
// and received messages for two bases (value of the message number received from the base-correspondent
// is assigned to the sent message number).
//
// Parameters:
//   BackupCopiesParameters - FixedStructure - structure properties:
//     * Sender                 - ExchangePlanRef - node on behalf of which exchange
//                                                        message was generated and sent.
//     * ReceivedNumber              - Number            - number of the received message in the base-correspondent.
//     * BackupRestored - Boolean           - shows that this base is restored from backup.
//
Procedure WhenRestoringBackupCopies(Val BackupCopiesParameters) Export
	
	If BackupCopiesParameters.BackupRestored Then
		
		// Set the number of the received message in correspondent as a number of the sent message in this base.
		NodeObject = BackupCopiesParameters.Sender.GetObject();
		NodeObject.SentNo = BackupCopiesParameters.ReceivedNo;
		NodeObject.DataExchange.Load = True;
		NodeObject.Write();
		
	EndIf;
	
EndProcedure

// Returns the redefined exchange plan name if it is specified depending on the redefined exchange setting.
// Parameters:
//   ExchangePlanNode         - ExchangePlanRef - exchange plan node for which it
//                                                is required to receive an overridable name.
//   ParameterNameWithNodeName - Name of the parameter in the default settings from which the node name is required to be received.
//
// Returns:
//  String - Predefined name of exchange plan as it is specified in the linker.
//
Function OverridableExchangePlanNodeName(Val ExchangePlanNode, ParameterNameWithNodeName) Export
	
	ExchangePlanName                     = ExchangePlanNode.Metadata().Name;
	OverridableExchangePlanNodeName = ExchangePlanNode.Metadata().Synonym;
	
	OverridableExchangePlanNodeName = ExchangePlanSettingValue(ExchangePlanName, 
	                                                                  ParameterNameWithNodeName, 
	                                                                  SavedExchangePlanNodeSettingsVariant(ExchangePlanNode));
	
	Return OverridableExchangePlanNodeName;
	
EndFunction

// Returns the identifier of the saved exchange plan setting variant.
// Parameters:
//   ExchangePlanNode         - ExchangePlanRef - exchange plan node for which it
//                                                is required to receive an overridable name.
//
// Returns:
//  String - connected setting identifier as it is specified in the linker.
//
Function SavedExchangePlanNodeSettingsVariant(ExchangePlanNode) Export
	
	SettingVariant = "";
	
	ExchangePlanName = ExchangePlanNode.Metadata().Name;
	
	If CommonUse.IsObjectAttribute("SettingVariant", ExchangePlanNode.Metadata()) Then
		
		SettingVariant = ExchangePlanNode.SettingVariant;
		
	EndIf;
	
	Return SettingVariant;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with the monitor of data exchange issues.

// Returns the quantity of data exchange unexamined problems. Used
// to display the quantity of exchange problems in the user interface. For example, to use
// in the hyperlink header for transition to the exchange issues monitor.
//
// Parameters:
//   Nodes - Array - array of the values ExchangePlanRef.
//
// Returns:
//   Number
// 
Function CountOfPendingProblems(Nodes = Undefined) Export
	
	Return CountProblemsDataExchange(Nodes) + VersioningProblemsCount(Nodes);
	
EndFunction

// Returns the hyperlink header structure for transition to monitor of the data exchange issues.
// 
// Parameters:
//   Nodes - Array - array of the values ExchangePlanRef.
//
// Returns:
// Structure - with properties:
//   * Title - String   - title of the hyperlink.
//   * Picture  - Picture - picture for hyperlink.
//
Function HeaderStructureHyperlinkMonitorProblems(Nodes = Undefined) Export
	
	Quantity = CountOfPendingProblems(Nodes);
	
	If Quantity > 0 Then
		
		Title = NStr("en='Warnings (%1)';ru='Предупреждения (%1)'");
		Title = StringFunctionsClientServer.SubstituteParametersInString(Title, Quantity);
		Picture = PictureLib.Warning;
		
	Else
		
		Title = NStr("en='No warnings';ru='Предупреждений нет'");
		Picture = New Picture;
		
	EndIf;
	
	HeaderStructure = New Structure;
	HeaderStructure.Insert("Title", Title);
	HeaderStructure.Insert("Picture", Picture);
	
	Return HeaderStructure;
	
EndFunction

#EndRegion

#Region ServiceApplicationInterface

// Declares service events of the DataExchange subsystem:
//
// Server events:
//   DuringDataExport,
//   OnDataImport.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Used to override the standard processor of the data export.
	// Data exporting logic shall be implemented in this handler:
	// selection of data for export, data serialization to the message file or data serialization to flow.
	// After the handler execution the data exchange subsystem will send the exported data to the receiver.
	// Message format for export can be custom.
	// If errors occur while sending data, you should abort
	// execution of the handler using the CallException method with the error description.
	//
	// Parameters:
	//  StandardProcessing - Boolean - A flag of standard (system)
	//     event handler is passed to this parameter. If you set the
	//     False value for this parameter in the body of the procedure-processor, there will be no standard processing of the event.
	//     Denial from the standard processor does not stop action.
	//     Default value: True.
	//  Recipient - ExchangePlanRef - exchange plan node for which the data is exported.
	//  MessageFileName    - String - attachment file name to which it is required to export data.
	//     If this parameter is filled in, the system expects that the data will be exported to file.
	//     After exporting the system will send the data from this file.
	//     If the parameter is empty, the system expects that the data will be exported to the MessageData parameter.
	//  MessageData      - Arbitrary - If the MessageFileName parameter is empty,
	//     then the system expects that data will be exported to this parameter.
	//  ItemCountInTransaction - Number - defines the maximum quantity
	//     of data items that are placed to the message within one transaction of the data base.
	//     You should implement the setting logic of
	//     transaction locks for the exported data in the handler if needed.
	//     The parameter value is specified in the data exchange subsystem settings.
	//  EventLogMonitorEventName - String - events log monitor event name of the current data exchange session.
	//     Used to write data with the specified event
	//     name to the events log monitor (errors, alerts, information). Corresponds to
	//     the EventName parameter of the EventLogMonitorRecord global context method.
	//  SentObjectCount - Number - Counter of the sent objects.
	//     Used to define a quantity of sent objects for the subsequent record in the exchange protocol.
	//
	// Syntax:
	// Procedure
	// 						OnDataExportService(StandardDataProcessor,
	// 						Receiver,
	// 						MessageFileName,
	// 						MessageData,
	// 						ItemsQuantityInTransaction,
	// 						EventLogMonitorItemsName, SentObjectsQuantity) Export
	//
	ServerEvents.Add("StandardSubsystems.DataExchange\DuringDataDumpService");
	
	// Used to override standard processor of the data import.
	// Data importing logic shall be implemented in this handler.:
	// required checks before the data import, data serialization from the message file
	// or data serialization from the flow.
	// Message format for import can be custom.
	// If errors occur when obtaining data, interrupt the handler
	// using the Raise method with the error description.
	//
	// Parameters:
	//
	//  StandardProcessing - Boolean - 
	//     A flag of standard (system) event handler is passed to this parameter.
	//     If you set the False value for this
	//     parameter in the body of the procedure-processor, there will be no standard processing of the event. Denial from the standard processor does not stop action.
	//     Default value: True.
	//  Sender - ExchangePlanRef - exchange plan node for which the data is imported.
	//  MessageFileName - String - attachment file name from which it is required to import data.
	//     If the parameter is not filled in, then the data for import is passed via the MessageData parameter.
	//  MessageData - Arbitrary - Parameter contains data that is required to be imported.
	//     If the MessageFileName parameter is empty, then the data for import is passed via this parameter.
	//  ItemCountInTransaction - Number - Defines the maximum quantity
	//     of the data items that are read from message and written to the data base within one transaction.
	//     You should implement the logic of data record in transaction in the handler if needed.
	//     The parameter value is specified in the data exchange subsystem settings.
	//  EventLogMonitorEventName - String - events log monitor event name of the current data exchange session.
	//     Used to write data with the specified event
	//     name to the events log monitor (errors, alerts, information).
	//     Corresponds to the EventName parameter of the EventLogMonitorRecord global context method.
	//  ReceivedObjectCount - Number - counter of received objects.
	//     Used to define a
	//     quantity of imported objects for the subsequent record in the exchange protocol.
	//
	// Syntax:
	// Procedure
	// 						OnImportDataService(StandardDataProcessor,
	// 						Sender,
	// 						MessageFileName,
	// 						MessageData,
	// 						ItemsQuantityInTransaction,
	// 						EventLogMonitorItemsName, SentObjectsQuantity) Export
	//
	ServerEvents.Add("StandardSubsystems.DataExchange\WithImportingDataCall");
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\OnStart"].Add(
			"DataExchangeClient");
			
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\AfterSystemOperationStart"].Add(
			"DataExchangeClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"DataExchangeServer");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddMetadataObjectsRenaming"].Add(
		"DataExchangeServer");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnDefenitionSupportedVersionsOfSoftwareInterfaces"].Add(
		"DataExchangeServer");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsRunning"].Add(
		"DataExchangeServer");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
		"DataExchangeServer");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObligatoryExchangePlanObjects"].Add(
		"DataExchangeServer");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObjectExceptionsOfExchangePlan"].Add(
		"DataExchangeServer");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGetPrimaryImagePlanExchangeObjects"].Add(
		"DataExchangeServer");
		
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnEnableSeparationByDataAreas"].Add(
		"DataExchangeServer");
		
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddExceptionsSearchLinks"].Add(
		"DataExchangeServer");
		
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources"].Add(
		"DataExchangeServer");
		
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenRegisteringExternalModulesManagers"].Add(
		"DataExchangeServer");
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		
		ServerHandlers["StandardSubsystems.AccessManagement\WhenFillingOutProfileGroupsAccessProvided"].Add(
			"DataExchangeServer");
		
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ServerHandlers["StandardSubsystems.CurrentWorks\AtFillingToDoList"].Add(
			"DataExchangeServer");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Conditional call handlers.

// Imports metadata objects identifiers received from the main DIB node.
Procedure BeforeCheckingIdentifiersOfMetadataObjectsInSubordinateNodeDIB(Cancel = False) Export
	
	Catalogs.MetadataObjectIDs.CheckUse();
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"IgnoreExportMessagesExchangeDataBeforeRunning") Then
		Return;
	EndIf;
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"IgnoreExportMetadataObjectsBeforeRunningIds") Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	SetDataExchangeMessageImportModeBeforeStart("ImportAllowed", True);
	SetPrivilegedMode(False);
	
	Try
		
		If GetFunctionalOption("UseDataSynchronization") = False Then
			
			If CommonUseReUse.DataSeparationEnabled() Then
				
				UseDataSynchronization = Constants.UseDataSynchronization.CreateValueManager();
				UseDataSynchronization.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
				UseDataSynchronization.DataExchange.Load = True;
				UseDataSynchronization.Value = True;
				UseDataSynchronization.Write();
				
			Else
				
				If GetExchangePlansBeingUsed().Count() > 0 Then
					
					UseDataSynchronization = Constants.UseDataSynchronization.CreateValueManager();
					UseDataSynchronization.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
					UseDataSynchronization.DataExchange.Load = True;
					UseDataSynchronization.Value = True;
					UseDataSynchronization.Write();
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If GetFunctionalOption("UseDataSynchronization") = True Then
			
			InfobaseNode = MasterNode();
			
			If InfobaseNode <> Undefined Then
				
				TransportKind = InformationRegisters.ExchangeTransportSettings.ExchangeMessageTransportKindByDefault(InfobaseNode);
				
				// Import only parameters works application.
				ExecuteDataExchangeForInfobaseNode(Cancel, InfobaseNode, True, False, TransportKind,,,,,, True);
				
			EndIf;
			
		EndIf;
		
	Except
		SetPrivilegedMode(True);
		SetDataExchangeMessageImportModeBeforeStart("ImportAllowed", False);
		SetPrivilegedMode(False);
		
		EnableExchangeMessageDataExportRepetitionBeforeRunning();
		
		WriteLogEvent(
			NStr("en='Data exchange. Import the ""Metadata object IDs"" catalog';ru='Обмен данными.Загрузка справочника ""Идентификаторы объектов метаданных""'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
		
		Raise
			NStr("en='Changes of the ""Metadata object IDs"" catalog are not imported from the main node: data import error. For more information, see event log.';ru='Из главного узла не загружены изменения справочника ""Идентификаторы объектов метаданных"": ошибка загрузки данных.См. подробности в журнале регистрации.'");
	EndTry;
	SetPrivilegedMode(True);
	SetDataExchangeMessageImportModeBeforeStart("ImportAllowed", False);
	SetPrivilegedMode(False);
	
	If Cancel Then
		
		If ConfigurationChanged() Then
			Raise
				NStr("en='Application modifications received from the main node are imported.
		|Finish application work. Open the application in
		|the configurator and run the Update data base configuration (F7) command.
		|
		|After this start the application.';ru='Загружены изменения программы, полученные из главного узла.
		|Завершите работу программы. Откройте программу
		|в конфигураторе и выполните команду ""Обновить конфигурацию базы данных (F7)"".
		|
		|После этого запустите программу.'");
		EndIf;
		
		EnableExchangeMessageDataExportRepetitionBeforeRunning();
		
		Raise
			NStr("en='Changes of the ""Metadata object IDs"" catalog are not imported from the main node: data import error. For more information, see event log.';ru='Из главного узла не загружены изменения справочника ""Идентификаторы объектов метаданных"": ошибка загрузки данных.См. подробности в журнале регистрации.'");
	EndIf;
	
EndProcedure

// Sets a flag showing whether the import of metadata objects identifiers from the exchange message is required.
// Cleans exchange messages storage received from the main node DIB.
// If it is specified, throws an exception with the subsequent actions explanation.
//
Procedure WhenErrorChecksIdsMetadataObjectsInSubordinateSiteDIB(OnImport, CallingException = False) Export
	
	Catalogs.MetadataObjectIDs.CheckUse();
	
	If OnImport Then
		EnableExchangeMessageDataExportRepetitionBeforeRunning();
		
		If CallingException Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='The changes of the Metadata objects identifiers are not
		|imported from the main node: the check showed that you need to
		|import the critical changes (for details, see the evens log monitor in the Metadata objects identifiers.It is required to import critical changes event).
		|
		|If the data exchange message is not
		|available, then restart the application, set the connection parameters and repeat the synchronization.
		|If all required changes are not received from
		|the main node, then update the infobase
		|in the main node, register data for restoring
		|the subordinate DIB node and repeat data synchronization in the main and subordinate nodes.
		|
		|To update the infobase in the main node, start
		|the application once with the StartInfobaseUpdate start parameters.
		|%1
		|';ru='Из главного узла не загружены изменения справочника
		|""Идентификаторы объектов метаданных"": при проверке обнаружено, что
		|требуется загрузить критичные изменения (см. подробности в журнале регистрации в событии ""Идентификаторы объектов метаданных.Требуется загрузить критичные изменения"").
		|
		|Если недоступно сообщение обмена
		|данными, тогда перезапустите программу, настройте параметры подключения и повторите синхронизацию.
		|Если из главного узла не получены все
		|необходимые изменения, тогда в главном узле
		|выполните обновление информационной базы, зарегистрируйте
		|данные для восстановления подчиненного узла РИБ и повторите синхронизацию данных в главном и подчиненном узлах.
		|
		|Чтобы выполнить обновление информационной базы в
		|главном узле, один раз выполните запуск программы с параметром запуска ЗапуститьОбновлениеИнформационнойБазы.
		|%1
		|'"),
				?(DataExchangeReUse.ThisIsOfflineWorkplace(),
				NStr("en='To register data for restoration of DIB subordinate node, open
		|Data synchronization settings in the main node
		|in the Administration section, go to Autonomous work. Open the Changes registration form
		|on the Content of the sent data command
		|and run the Register data for restoration of DIB subordinate node (the More menu) command in this form.';ru='Чтобы зарегистрировать данные для восстановления подчиненного узла
		|РИБ, в главном узле в разделе ""Администрирование""
		|откройте ""Настройки синхронизации данных"", перейдите по ссылке ""Автономная работа"". По команде ""Состав отправляемых
		|данных"" откройте форму ""Регистрация
		|изменений"", в которой выполните команду ""Зарегистрировать данные для восстановления подчиненного узла РИБ"" (меню Еще).'"),
				NStr("en='To register data for restoration of DIB subordinate node, open
		|Data synchronization settings in the main node
		|in the Administration section, go to Data synchronization. Open the Changes registration form
		|on the Content of the sent data command
		|and run the Register data for restoration of DIB subordinate node (the More menu) command in this form.';ru='Чтобы зарегистрировать данные для восстановления подчиненного узла
		|РИБ, в главном узле в разделе ""Администрирование""
		|откройте ""Настройки синхронизации данных"", перейдите по ссылке ""Синхронизация данных"". По команде ""Состав отправляемых
		|данных"" откройте форму ""Регистрация
		|изменений"", в которой выполните команду ""Зарегистрировать данные для восстановления подчиненного узла РИБ"" (меню Еще).'")));
			
			Raise ErrorText;
		EndIf;
		
	ElsIf CallingException Then // Setting in the IB subordinate node during the first start.
			ErrorText =
				NStr("en='The Metadata objects identifiers catalog is not
		|updated in the main node: the check showed that you need to
		|execute the critical changes (for details, see the events log monitor in the Metadata objects identifiers.It is required to execute critical changes event).
		|
		|Update the infobase on the main node and try to create a subordinate node again.
		|
		|To update the infobase in the main node, start
		|the application once with the StartInfobaseUpdate start parameters.';ru='В главном узле не обновлен справочник ""Идентификаторы объектов метаданных"": при проверке обнаружено, что требуется выполнить критичные изменения (см. подробности в журнале регистрации в событии ""Идентификаторы объектов метаданных.Требуется выполнить критичные изменения"").  В главном узле выполните обновление информационной базы и повторите создание подчиненного узла.  Чтобы выполнить обновление информационной базы в главном узле, один раз выполните запуск программы с параметром запуска ЗапуститьОбновлениеИнформационнойБазы.'");
				
			Raise ErrorText;
	EndIf;
	
EndProcedure

// Imports the exchange message that
// contains configuration changes before the infobase update.
//
Procedure BeforeInformationBaseUpdating(ClientApplicationsOnStart, Restart) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;	
	EndIf;
	
	If Not InfobaseUpdate.InfobaseUpdateRequired() Then
		SynchronizeWhenNoUpdateOfInformationBase(ClientApplicationsOnStart, Restart);
	Else	
		ImportMessageBeforeInformationBaseUpdating();
	EndIf;

EndProcedure

// Exports the exchange message
// that contains configuration changes before the infobase update.
//
Procedure AfterInformationBaseUpdate() Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;	
	EndIf;
	
	ExportMessageAfterInformationBaseUpdate();
	
EndProcedure	

// Returns True if the setting of the subordinate DIB
// node is not complete and updates of application work parameters are required that do not take part in DIB.
//
Function SettingADBSlaveNode() Export
	
	SetPrivilegedMode(True);
	
	Return IsSubordinateDIBNode()
	      AND Constants.SubordinatedDIBNodeSettingsFinished.Get() = False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable
//                                  function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Priority = 1;
	Handler.SharedData = True;
	Handler.ExclusiveMode = False;
	Handler.Procedure = "DataExchangeServer.ExecuteUpdateOfDataExchangeRules";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.Procedure = "DataExchangeServer.SetInformationMatchCorrectionExecutionNecessityForAllInfobaseNodes";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.Procedure = "DataExchangeServer.SetObjectsExportModeForAllInfobaseNodes";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.UpdateDataExchangeScriptsScheduledJobs";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.2.0";
	Handler.Procedure = "DataExchangeServer.UpdateConstantDIBSubordinateNodeSettingComplete";
	
	Handler = Handlers.Add();
	Handler.Version = "2.0.1.10";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.CheckFunctionalOptionSetOnInfobaseUpdate";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.1.5";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.SetStoringPasswordFlagForExchangeViaInternet";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.12";
	Handler.Procedure = "DataExchangeServer.ResetMonitorExchangeSettings";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.21";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.CheckFunctionalOptionsSettingOnUpdate_2_1_2_21";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.4";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.SetItemsQuantityInDataImportTransaction_2_2_2_4";
	
EndProcedure

// Updates rules of object conversion/registration.
// Update is executed for all exchange plans connected to the subsystem.
// Rules are updated only for model rules.
// If the rules are imported from file for the exchange plan, then such rules are not updated.
//
Procedure ExecuteUpdateOfDataExchangeRules() Export
	
	// For the script when the exchange plan is deleted or renamed in the configuration.
	DeleteNonActualRecordsFromDataExchangeRulesRegister();
	
	ImportedFromFileExchangeRules = New Array;
	ImportedFromFileRecordRules = New Array;
	
	ExecuteCheckupOfExchangeRulesImportedFromFilePresence(ImportedFromFileExchangeRules, ImportedFromFileRecordRules);
	
	Cancel = False;
	
	//RISE Temnikov 18.11.2015 comment + <BR> //ExecuteUpdateOfTypicalRulesVersionForDataExchange(Cancel, ImportedFromFileExchangeRules, ImportedFromFileRecordRules);<BR> //RISE Temnikov 18.11.2015 -<BR>
	
	If Cancel Then
		Raise NStr("en='Errors occurred during update of data exchange rules (see the event log).';ru='При обновлении правил обмена данными возникли ошибки (см. Журнал регистрации).'");
	EndIf;
	
	DataExchangeServerCall.ResetCacheMechanismForRegistrationOfObjects();
	
EndProcedure

// Sets a flag showing that it is required to run the
// procedure of adjustment of the match information for all levels of exchange plan nodes on next data exchange.
//
Procedure SetNecessityOfExecutionOfMappingInformationCorrectionForAllInfobaseNodes() Export
	
	InformationRegisters.InfobasesNodesCommonSettings.SetNecessityOfExecutionOfMappingInformationCorrectionForAllInfobaseNodes();
	
EndProcedure

// Sets the Export by condition value for all nodes of
// the universal data exchange of the export mode attributes-checkboxes value.
//
Procedure SetObjectsExportModeForAllInfobaseNodes() Export
	
	ExchangePlanList = DataExchangeReUse.SLExchangePlanList();
	
	For Each Item IN ExchangePlanList Do
		
		ExchangePlanName = Item.Value;
		
		If Metadata.ExchangePlans[ExchangePlanName].DistributedInfobase Then
			Continue;
		EndIf;
		
		NodesArray = DataExchangeReUse.GetExchangePlanNodesArray(ExchangePlanName);
		
		For Each Node IN NodesArray Do
			
			AttributeNames = CommonUse.NamesOfAttributesByType(Node, Type("EnumRef.ExchangeObjectsExportModes"));
			
			If IsBlankString(AttributeNames) Then
				Continue;
			EndIf;
			
			AttributeNames = StrReplace(AttributeNames, " ", "");
			
			Attributes = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(AttributeNames);
			
			ObjectModified = False;
			
			NodeObject = Node.GetObject();
			
			For Each AttributeName IN Attributes Do
				
				If Not ValueIsFilled(NodeObject[AttributeName]) Then
					
					NodeObject[AttributeName] = Enums.ExchangeObjectsExportModes.ExportByCondition;
					
					ObjectModified = True;
					
				EndIf;
				
			EndDo;
			
			If ObjectModified Then
				
				NodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
				NodeObject.Write();
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Updates the data of scheduled jobs for all scripts of the data exchange except the marked for deletion ones.
//
Procedure UpdateScheduledJobsOfDataExchangeScripts() Export
	
	QueryText = "
	|SELECT
	|	DataExchangeScripts.Ref
	|FROM
	|	Catalog.DataExchangeScripts AS DataExchangeScripts
	|WHERE
	|	Not DataExchangeScripts.DeletionMark
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		Cancel = False;
		
		Object = Selection.Ref.GetObject();
		
		Catalogs.DataExchangeScripts.RefreshScheduledJobData(Cancel, Undefined, Object);
		
		If Cancel Then
			Raise NStr("en='An error occurred when updating a scheduled job for the data exchange scenario.';ru='Ошибка при обновлении регламентного задания для сценария обмена данными.'");
		EndIf;
		
		InfobaseUpdate.WriteData(Object);
		
	EndDo;
	
EndProcedure

// Sets the value of the SubordinateDIBNodeSettingsFinished constant to Truth
// for the subordinate DIB node as exchange in DIB has already been set in the base.
//
Procedure UpdateConstantOfDIBSubordinatedNodeSettingCompleted() Export
	
	If  IsSubordinateDIBNode()
		AND InformationRegisters.ExchangeTransportSettings.TransportForNodeSettingsAreSetted(MasterNode()) Then
		
		Constants.SubordinatedDIBNodeSettingsFinished.Set(True);
		
		RefreshReusableValues();
		
	EndIf;
	
EndProcedure

// Resets the value of the UseDataSynchronization constant if needed.
//
Procedure CheckFunctionalOptionsAreSetOnInfobaseUpdate() Export
	
	If Constants.UseDataSynchronization.Get() = True Then
		
		Constants.UseDataSynchronization.Set(True);
		
	EndIf;
	
EndProcedure

// Resets the value of the
// UseDataSynchronization constant if necessary. As constant became unseparated and its value is reset.
//
Procedure CheckFunctionalOptionsAreSetOnInfobaseUpdate_2_1_2_21() Export
	
	If GetFunctionalOption("UseDataSynchronization") = False Then
		
		If CommonUseReUse.DataSeparationEnabled() Then
			
			Constants.UseDataSynchronization.Set(True);
			
		Else
			
			If GetExchangePlansBeingUsed().Count() > 0 Then
				
				Constants.UseDataSynchronization.Set(True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Sets the quantity of items in transaction of data import that equals to one.
//
Procedure SetDataImportItemsInTransactionQuantity_2_2_2_4() Export
	
	SetDataImportItemsInTransactionQuantity(1);
	
EndProcedure

// Sets the value of the WSRememberPassword attribute in IR.ExchangeTransportSettings to the True value.
//
Procedure SetSignOfStoredPasswordsForExchangeOnInternet() Export
	
	QueryText =
	"SELECT
	|	ExchangeTransportSettings.Node AS Node
	|FROM
	|	InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|WHERE
	|	ExchangeTransportSettings.ExchangeMessageTransportKindByDefault = VALUE(Enum.ExchangeMessagesTransportKinds.WS)";
	
	Query = New Query;
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		// update record in IR
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", Selection.Node);
		RecordStructure.Insert("WSRememberPassword", True);
		InformationRegisters.ExchangeTransportSettings.UpdateRecord(RecordStructure);
		
	EndDo;
	
EndProcedure

// Clears the saved settings of common form DataExchanges.
//
Procedure ResetMonitorExchangeSettings() Export
	
	FormSettingsArray = New Array;
	FormSettingsArray.Add("/FormSettings");
	FormSettingsArray.Add("/WindowSettings");
	FormSettingsArray.Add("/WebClientWindowSettings");
	FormSettingsArray.Add("/CurrentData");
	
	For Each FormItem IN FormSettingsArray Do
		SystemSettingsStorage.Delete("CommonForm.DataExchanges" + FormItem, Undefined, Undefined);
	EndDo;
	
EndProcedure

//

// Defines whether exchange plan is separated by SSL.
//
// Parameters:
// ExchangePlanName - String - Name of the checked exchange plan.
//
// Returns:
// Type - Boolean
//
Function IsSeparatedExchangePlanSSL(Val ExchangePlanName) Export
	
	Return DataExchangeReUse.SeparatedSSLExchangePlans().Find(ExchangePlanName) <> Undefined;
	
EndFunction

// Generates the selection of changed data for passing to the particular exchange plan node.
// If the method is called in the active transaction, then
// exception is thrown. For the description of the ExchangePlansManager.SelectChanges() method, see syntax-assistant.
//
Function SelectChanges(Val Node, Val MessageNo, Val FilterSample = Undefined) Export
	
	If TransactionActive() Then
		Raise NStr("en='Data change selection is prohibited in an active transaction.';ru='Выборка изменений данных запрещена в активной транзакции.'");
	EndIf;
	
	Return ExchangePlans.SelectChanges(Node, MessageNo, FilterSample);
EndFunction

// Defines the default settings for the exchange plan that can
// be redefined in the module of exchange plan manager in the DefineSettings() function.
// 
// Returns:
//   Structure - contains fields:
//      * WarnAboutExchangeRulesVersionsMismatch        - Boolean - Shows that it
//                                                                         is required to check versions variance in the configuration rules.
//                                                                         Check is executed during
//                                                                         the import of the rules set and
//                                                                         during sending and receiving data.
//      * PathToRulesSetFileOnUserWebsite      - String - Contains path to file
//                                                                         of rules set as an archive
//                                                                         on the user website in the configuration section.
//      * PathToRulesSetFileInTemplatesDirectory            - String - Contains a relative path
//                                                                         to file of the rules
//                                                                         set in 1C:Enterprise templates directory.
//      * CommandTitleForNewDataExchangeCreation        - String - Contains presentation of command
//                                                                         output in the custom
//                                                                         interface while creating a new data exchange setting.
//      * ExchangeCreationAssistantTitle                      - String - Contains the presentation
//                                                                         of the form title of
//                                                                         the data exchange creation assistant in the user interface.
//      * CorrespondentConfigurationName                - String - Contains the
//                                                                         presentation of the correspondent configuration
//                                                                         name displayed in the user interface.
//      * ExchangePlanNodeTitle                              - String - Contains presentation exchange
//                                                                         plan node displayed in the user interface.
//      * ExchangeSettingsVariants                                - Array - List of possible settings of the exchange plan.
//                                                                         Used for creation
//                                                                         of prepared templates with filled
//                                                                         settings of the exchange plans.
//      * ShowFiltersSettingsOnNode                      - Boolean - Shows that filter settings on
//                                                                         node are displayed in the exchange creation assistant.
//      * ShowDefaultValuesOnNode                   - Boolean - Shows that the default values
//                                                                         are displayed in the exchange creation assistant.
//      * DisplayFiltersSettingOnCorrespondentBaseNode    - Boolean - Shows that the settings of
//                                                                         filters are displayed on
//                                                                         the node of base-correspondent in the exchange creation assistant.
//      * DisplayDefaultValuesOnCorrespondentBaseNode - Boolean - Shows that default values
//                                                                         of the base-correspondent are
//                                                                         displayed in the exchange creation assistant.
//
Function DefaultExchangePlanSettings(ExchangePlanName) Export
	
	// Receive default values for the exchange plan.
	ExchangePlanMetadata = Metadata.ExchangePlans[ExchangePlanName];
	
	AssistantFormTitle = NStr("en='Data synchronization with %Application% (configuration)';ru='Синхронизация данных с %Программа% (настройка)'");
	AssistantFormTitle = StrReplace(AssistantFormTitle, "%Application%", ExchangePlanMetadata.Synonym);
	
	Parameters = New Structure;
	
	Parameters.Insert("WarnAboutExchangeRulesVersionsMismatch",        True);
	Parameters.Insert("PathToRulesSetFileOnUsersWebsite",      "");
	Parameters.Insert("PathToRulesSetFileInTemplatesDirectory",            "");
	Parameters.Insert("CommandTitleForCreationOfNewDataExchange",        ExchangePlanMetadata.Synonym);
	Parameters.Insert("ExchangeCreationAssistantTitle",                      AssistantFormTitle);
	Parameters.Insert("CorrespondentConfigurationName",                ExchangePlanMetadata.Synonym);
	Parameters.Insert("ExchangePlanNodeTitle",                              ExchangePlanMetadata.Synonym);
	Parameters.Insert("ExchangeSettingsVariants",                                New Array());
	Parameters.Insert("ShowFiltersSettingsOnNode",                      True);
	Parameters.Insert("ShowDefaultValuesOnNode",                   True);
	Parameters.Insert("DisplayFiltersSettingOnCorrespondentBaseNode",    True);
	Parameters.Insert("DisplayDefaultValuesOnCorrespondentBaseNode", True);
	Parameters.Insert("ThisIsExchangePlanXDTO",                                     False);
	Return Parameters;
	
EndFunction

// Receives the value of exchange plan setting by its name.
// 
// Parameters:
//   ExchangePlanName         - String - Name of the exchange plan from metadata.
//   ParameterName           - String - Name of the exchange plan parameter or the list of parameters separated by commas.
//                                     For the list of valid values, see the DefaultExchangeParameters function.
//   SettingID - String - Name of a predefined setting of the exchange plan.
// 
// Returns:
// - Custom - Type of the return value depends on the type of the received setting value.
// - Structure - If the list of parameters separated by commas is passed as the ParameterName parameter.
//
Function ExchangePlanSettingValue(ExchangePlanName, ParameterName, SettingID = "") Export
	
	DefaultParameters = DefaultExchangePlanSettings(ExchangePlanName);
	ExchangePlans[ExchangePlanName].DefineSettings(DefaultParameters, SettingID);
	
	If Find(ParameterName, ",") = 0 Then
		
		ParameterValue = DefaultParameters[ParameterName];
		
	Else
		
		ParameterValue = New Structure(ParameterName);
		FillPropertyValues(ParameterValue, DefaultParameters);
		
	EndIf;
	
	Return ParameterValue;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with object FTP-connection.

Function FTPConnection(Val Settings) Export
	
	Return New FTPConnection(
		Settings.Server,
		Settings.Port,
		Settings.UserName,
		Settings.UserPassword,
		ProxyServerSettings(Settings.SecureConnection),
		Settings.PassiveConnection,
		Settings.Timeout,
		Settings.SecureConnection);
	
EndFunction

Function FTPDirectoryExist(Val Path, Val DirectoryName, Val FTPConnection) Export
	
	For Each FTPFile IN FTPConnection.FindFiles(Path) Do
		
		If FTPFile.IsDirectory() AND FTPFile.Name = DirectoryName Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

Function FTPConnectionSettings() Export
	
	Result = New Structure;
	Result.Insert("Server", "");
	Result.Insert("Port", 21);
	Result.Insert("UserName", "");
	Result.Insert("UserPassword", "");
	Result.Insert("PassiveConnection", False);
	Result.Insert("Timeout", 0);
	Result.Insert("SecureConnection", Undefined);
	
	Return Result;
EndFunction

// Returns the server name and path on FTP server received from row of connection to FTP-resource.
//
// Parameters:
//  ConnectionString - String - String of connection to FTP-resource.
// 
// Returns:
//  Structure - setting of connection to FTP-resource. Structure fields:
//              Server - String - server name.
//              Path   - String - path on server.
//
//  Example (1):
// Result = FTPServerNameAndPath("ftp://server");
// Result.Server = server;
// Result.Path = /;
//
//  Example (2):
// Result = FTPServerNameAndPath("ftp://server/saas/exchange");
// Result.Server = server;
// Result.Path = /saas/obmen/;
//
Function FTPServerNameAndPath(Val ConnectionString) Export
	
	Result = New Structure("Server, Path");
	ConnectionString = TrimAll(ConnectionString);
	
	If (Upper(Left(ConnectionString, 6)) <> "FTP://"
		AND Upper(Left(ConnectionString, 7)) <> "FTPS://")
		OR Find(ConnectionString, "@") <> 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='FTP connection string does not match the format: ""%1""';ru='Строка подключения к FTP-ресурсу не соответствует формату: ""%1""'"), ConnectionString
		);
	EndIf;
	
	ConnectionParameters = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ConnectionString, "/");
	
	If ConnectionParameters.Count() < 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Server name is not specified in FTP resource connection string: ""%1""';ru='В строке подключения к FTP-ресурсу не указано имя сервера: ""%1""'"), ConnectionString
		);
	EndIf;
	
	Result.Server = ConnectionParameters[2];
	
	ConnectionParameters.Delete(0);
	ConnectionParameters.Delete(0);
	ConnectionParameters.Delete(0);
	
	ConnectionParameters.Insert(0, "@");
	
	If Not IsBlankString(ConnectionParameters.Get(ConnectionParameters.UBound())) Then
		
		ConnectionParameters.Add("@");
		
	EndIf;
	
	Result.Path = StringFunctionsClientServer.RowFromArraySubrows(ConnectionParameters, "/");
	Result.Path = StrReplace(Result.Path, "@", "");
	
	Return Result;
EndFunction

// Receives the settings of proxy server.
//
Function ProxyServerSettings(SecureConnection)
	
	If CommonUse.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		
		ModuleGetFilesFromInternet = CommonUse.CommonModule("GetFilesFromInternet");
		ModuleGetFilesFromInternet.ProxySettingsOnServer();
		
	Else
		
		ProxyServerSetting = Undefined;
		
	EndIf;
	
	If ProxyServerSetting <> Undefined Then
		UseProxy = ProxyServerSetting.Get("UseProxy");
		UseSystemSettings = ProxyServerSetting.Get("UseSystemSettings");
		If UseProxy Then
			If UseSystemSettings Then
				// System proxy settings.
				Proxy = New InternetProxy(True);
			Else
				// Manual proxy settings.
				Proxy = New InternetProxy;
				Protocol = ?(SecureConnection = Undefined, "ftp", "ftps");
				Proxy.Set(Protocol, ProxyServerSetting["Server"], ProxyServerSetting["Port"]);
				Proxy.User = ProxyServerSetting["User"];
				Proxy.Password       = ProxyServerSetting["Password"];
				Proxy.BypassProxyOnLocal = ProxyServerSetting["BypassProxyOnLocal"];
			EndIf;
		Else
			// Do not use proxy server.
			Proxy = New InternetProxy(False);
		EndIf;
	Else
		Proxy = Undefined;
	EndIf;
	
	Return Proxy;
	
EndFunction

// For an internal use.
//
Function OpenCommunicationAssistantToConfigureSlaveNode() Export
	
	Return Not CommonUseReUse.DataSeparationEnabled()
		AND Not DataExchangeReUse.ThisIsOfflineWorkplace()
		AND IsSubordinateDIBNode()
		AND Not Constants.SubordinatedDIBNodeSettingsFinished.Get();
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

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
	VersionArray.Add("2.0.1.6");
	VersionArray.Add("2.1.1.7");
	SupportedVersionStructure.Insert("DataExchange", VersionArray);
	
EndProcedure

// Adds parameters of the client logic work for the data exchange subsystem.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystemsRunning(Parameters) Export
	
	SetPrivilegedMode(True);
	
	Parameters.Insert("DIBExchangePlanName", ?(IsSubordinateDIBNode(), MasterNode().Metadata().Name, ""));
	Parameters.Insert("MasterNode", MasterNode());
	
	If OpenCommunicationAssistantToConfigureSlaveNode() Then
		Parameters.Insert("OpenCommunicationAssistantToConfigureSlaveNode");
	EndIf;
	
	SetPrivilegedMode(False);
	
	If Not Parameters.Property("OpenCommunicationAssistantToConfigureSlaveNode")
		AND Users.RolesAvailable("DataSynchronization") Then
		
		Parameters.Insert("CheckSubordinatedNodeConfigurationUpdateNecessity");
	EndIf;
	
EndProcedure

// Fills those metadata objects renaming that
// can not be automatically found by type, but the references to
// which are to be stored in the database (for example, subsystems, roles).
//
// For more see: CommonUse.AddRenaming().
//
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	CommonUse.AddRenaming(
		Total, "2.1.2.5", "Role.ExchangeData", "Role.DataSynchronization", Library);
		
	CommonUse.AddRenaming(
		Total, "2.1.2.5", "Role.AddDataExchangeChange", "Role.DataSynchronizationSetting", Library);
	
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystems(Parameters) Export
	
	AddClientWorkParameters(Parameters);
	
EndProcedure

// Used to receive metadata objects mandatory for an exchange plan.
// If the subsystem has metadata objects that have to be included
// in the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects that should be included into the exchange plan.
// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
// True - need to receive a list of RIB exchange plan;
// False - it is required to receive a list for an exchange plan NOT RIB.
//
Procedure OnGettingObligatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
EndProcedure

// Used to receive metadata objects that should not be included into the exchange plan content.
// If the subsystem has metadata objects that should not be included in
// the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects that should not be included into the exchange plan.
// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
// True - required to get the list of the exception objects of the DIB exchange plan;
// False - it is required to receive a list for an exchange plan NOT RIB.
//
Procedure OnGettingObjectExceptionsOfExchangePlan(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Constants.RetryDataExportExchangeMessagesBeforeStart);
		Objects.Add(Metadata.Constants.ReusableValuesUpdateDateORM);
		Objects.Add(Metadata.Constants.ImportDataExchangeMessage);
		Objects.Add(Metadata.Constants.UseDataSynchronization);
		Objects.Add(Metadata.Constants.UseDataSynchronizationInLocalMode);
		Objects.Add(Metadata.Constants.UseDataSynchronizationSaaS);
		Objects.Add(Metadata.Constants.DataExchangeMessagesDirectoryForWindows);
		Objects.Add(Metadata.Constants.DataExchangeMessagesDirectoryForLinux);
		Objects.Add(Metadata.Constants.SubordinatedDIBNodeSettingsFinished);
		Objects.Add(Metadata.Constants.DistributedInformationBaseNodePrefix);
		Objects.Add(Metadata.Constants.DataExchangeMessageFromMainNode);
		
		Objects.Add(Metadata.Catalogs.DataExchangeScripts);
		
		Objects.Add(Metadata.InformationRegisters.ExchangeTransportSettings);
		Objects.Add(Metadata.InformationRegisters.InfobasesNodesCommonSettings);
		Objects.Add(Metadata.InformationRegisters.DataExchangeRules);
		Objects.Add(Metadata.InformationRegisters.DataExchangeMessages);
		Objects.Add(Metadata.InformationRegisters.InfobasesObjectsCompliance);
		Objects.Add(Metadata.InformationRegisters.DataExchangeStatus);
		Objects.Add(Metadata.InformationRegisters.SuccessfulDataExchangeStatus);
		
	EndIf;
	
EndProcedure

// Used to receive metadata objects that should be included in the
// content of the exchange plan and should NOT be included in the content of subscriptions to the events of changes registration for this plan.
// These metadata objects are used only at the time of creation
// of the initial image of the subnode and do not migrate during the exchange.
// If the subsystem has metadata objects that take part in creating an initial
// image of the subnode, the <Object> parameter needs to be added to these metadata objects.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects.
//
Procedure OnGetPrimaryImagePlanExchangeObjects(Objects) Export
	
	Objects.Add(Metadata.Constants.SubordinatedDIBNodeSetup);
	
EndProcedure

// Called up at enabling data classification into data fields.
//
Procedure OnEnableSeparationByDataAreas() Export
	
	If GetFunctionalOption("UseDataSynchronization") = False Then
		Constants.UseDataSynchronization.Set(True);
	EndIf;
	
EndProcedure

// Fills in descriptions of substituted profiles
// of the access groups and redefines the parameters of profiles and access groups update.
// For more information, see AccessManagementOverridable.OnFillingProvidedAccessGroupsProfiles.
//
Procedure WhenFillingOutProfileGroupsAccessProvided(ProfileDescriptions, UpdateParameters) Export
	
	// The Data synchronization with other applications profile.
	ProfileDescription = CommonUse.CommonModule("AccessManagement").AccessGroupProfileNewDescription();
	ProfileDescription.ID = ProfileSyncAccessDataWithOtherApplications();
	ProfileDescription.Description = NStr("en='Data synchronization with other applications';ru='Синхронизация данных с другими программами'");
	ProfileDescription.Definition = NStr("en='Assigned additionally to those users who have
		|access to tools for monitoring and data synchronization with other applications.';ru='Дополнительно назначается тем пользователям,
		|которым должны быть доступны средства для мониторинга и синхронизации данных с другими программами.'");
	
	// Main possibilities of the profile.
	ProfileRoles = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(
		ProfileRolesAccessSyncDataWithAnotherApplications());
	For Each Role IN ProfileRoles Do
		ProfileDescription.Roles.Add(TrimAll(Role));
	EndDo;
	ProfileDescriptions.Add(ProfileDescription);
	
EndProcedure

// Fills the array with the list of metadata objects names that might include
// references to different metadata objects with these references ignored in the business-specific application logic
//
// Parameters:
//  Array       - array of strings for example "InformationRegister.ObjectsVersions".
//
Procedure OnAddExceptionsSearchLinks(Array) Export
	
	Array.Add(Metadata.InformationRegisters.DataExchangeResults.FullName());
	
EndProcedure

// Fills out a list of queries for external permissions
// that must be provided when creating an infobase or updating a application.
//
// Parameters:
//  PermissionsQueries - Array - list of values returned by the function.
//                      WorkInSafeMode.QueryOnExternalResourcesUse().
//
Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	If GetFunctionalOption("UseDataSynchronization") = False Then
		Return;
	EndIf;
	
	GenerateQueriesOnExternalResourcesUse(PermissionsQueries);
	
EndProcedure

// Appears when the managers of external modules are registered.
//
// Parameters:
//  Managers - Array(CommonModule).
//
Procedure WhenRegisteringExternalModulesManagers(Managers) Export
	
	Managers.Add(DataExchangeServer);
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    * Identifier - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    * Important        - Boolean - If True, the work is marked in red.
//    * Presentation - String - a work presentation displayed to the user.
//    * Count    - Number  - a quantitative indicator of work, it is displayed in the work header string.
//    * Form         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner      - String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip     - String - The tooltip wording.
//
Procedure AtFillingToDoList(CurrentWorks) Export
	
	OnFillingToDoListForSynchronizationWarning(CurrentWorks);
	OnFillingToDoListUpdateRequired(CurrentWorks);
	OnFillCurrensTodosListCheckCompatibilityWithCurrentVersion(CurrentWorks);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls from other subsystems.

// Returns a match of session parameters and handlers parameters to initialize them.
//
Procedure OnAddSessionSettingsSetupHandler(Handlers) Export
	
	Handlers.Insert("DataExchangeMessageImportModeBeforeStart", "DataExchangeServerCall.SessionParametersSetting");
	
	Handlers.Insert("ReusableValuesUpdateDateORM",    "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("SelectiveObjectRegistrationRules",             "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("ObjectRegistrationRules",                       "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("DataSynchronizationPasswords",                        "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("ExchangeDataPriority",                         "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("VersionsDifferenceErrorOnReceivingData",        "DataExchangeServerCall.SessionParametersSetting");
	
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
	Objects.Insert(Metadata.Catalogs.DataExchangeScripts.FullName(), "NotEditableInGroupProcessingAttributes");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Defines if the group objects change is used in the configuration.
//
// Parameters:
//  Used - Boolean - True if used False - else.
//
Procedure OnDefineOfGroupObjectsChangesUsing(Used) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.GroupObjectsChange") Then
		Used = True;
	EndIf;
	
EndProcedure

// Defines if the subsystem of change denial date is used in the configuration.
//
// Parameters:
//  Used - Boolean - True if used False - else.
//
Procedure OnDefenitionOfUsageOfProhibitionDatesChange(Used) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ChangeProhibitionDates") Then
		Used = True;
	EndIf;
	
EndProcedure

// Sets the flag showing that the object version is ignored.
//
// Parameters:
// Ref - Ref to the ignored object.
// VersionNumber - Number - Number of the ignored object version.
// Ignore - Boolean Shows that the version is ignored.
//
Procedure OnObjectVersioningIgnoring(Ref, VersionNumber, Ignore) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		ObjectVersioningModule = CommonUse.CommonModule("ObjectVersioning");
		ObjectVersioningModule.IgnoreObjectVersioning(Ref, VersionNumber, Ignore);
	EndIf;
	
EndProcedure

// Handler of the transition to the object version.
//
// Parameters:
// ObjectRef - Ref - References to the object for which there is a version.
// VersionForTransitionNumber - Number - Version number to which it is required to execute transition.
// IgnoredVersionNumber - Number - Number of version that should be ignored.
// SkipChangeProhibitionCheck - Boolean - Shows that the check of import ban date is skipped.
//
Procedure OnTransitionToObjectVersioning(ObjectRef, VersionNumber) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		ObjectVersioningModule = CommonUse.CommonModule("ObjectVersioning");
		ObjectVersioningModule.OnTransitionToObjectVersioning(ObjectRef, VersionNumber);
	EndIf;
	
EndProcedure

// Handler of the UseDataSynchronization constant setting.
//
//  Parameters:
// Cancel - Boolean. Check box of enabling the data synchronization.
// If set it to the True value, then the synchronization will not be enabled.
//
Procedure OnDataSynchronizationEnabling(Cancel) Export
	
EndProcedure

// Handler to remove the UseDataSynchronization constant.
//
//  Parameters:
// Cancel - Boolean. Check box of canceling the data synchronization disabling.
// If you set True in the value, then the synchronization will not be disabled.
//
Procedure OnDataSynchronizationDisabling(Cancel) Export
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = CommonUse.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnDataSynchronizationDisabling(Cancel);
	EndIf;
	
EndProcedure

// Handler of the objects registration mechanism After defining recipients.
// Event occurs in the data record transaction in IB when the recipients of data changes are defined according to the rules of objects registration.
//
// Parameters:
//  Data. Written object representing data - document,
//          catalog item, bookkeeping account, constant record manager, register records set etc
//  Recipients     - Array - Array of the exchange plan nodes where the changes of the current data will be registered.
//  ExchangePlanName - String - Name of the exchange plan
//          as the metadata object for which objects registration rules are executed.
//
Procedure AfterGetRecipients(Data, Recipients, Val ExchangePlanName) Export
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = CommonUse.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.AfterGetRecipients(Data, Recipients, ExchangePlanName);
	EndIf;
	
EndProcedure

// Handler of skipping the change prohibition date check.
//
Procedure SkipChangeProhibitionCheck(Skip = True) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ChangeProhibitionDates") Then
		ChangeProhibitionDateModuleService = CommonUse.CommonModule("ChangeProhibitionDatesService");
		ChangeProhibitionDateModuleService.SkipChangeProhibitionCheck(Skip);
	EndIf;
	
EndProcedure

Procedure OnContinuationDIBSubordinateNodeSetting() Export
	SetPrivilegedMode(True);
	UsersService.ClearNonExistentInfobaseUserIDs();
	If CommonUse.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleWorkWithPostalMessagesService = CommonUse.CommonModule("EmailOperationsService");
		ModuleWorkWithPostalMessagesService.DisableAccountsUse();
	EndIf;
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// Data exchange execution

// Point login for perform iteration data exchange - data imports and exports for the exchange plan node.
//
// Parameters:
//  Cancel                  - Boolean - check box of denial; selected if an error occurs while executing the exchange.
//  InfobaseNode - ExchangePlanRef - exchange plan node for which data exchange is integrated.
//  PerformImport      - Boolean (optional) - check box of the data import requirement. Value
//                           by default - True.
//  PerformExport      - Boolean (optional) - check box of the data export requirement. Value
//                           by default - True.
//  ExchangeMessageTransportKind (optional) - EnumRef.ExchangeMessagesTransportKinds - kind of transport that will be used during the data exchange. 
// 							Value by default - value
// 							from IR.ExchangeTransportSettings.Resource.DefaultExchangeMessagesTransportKind; if the value is not specified
// 							in  RS, then the value is default - Enums.ExchangeMessagesTransportKinds.FILE.
// 
Procedure ExecuteDataExchangeForInfobaseNode(Cancel,
														Val InfobaseNode,
														Val PerformImport = True,
														Val PerformExport = True,
														Val ExchangeMessageTransportKind = Undefined,
														LongOperation = False,
														ActionID = "",
														FileID = "",
														Val LongOperationAllowed = False,
														Val AuthenticationParameters = Undefined,
														Val OnlyParameters = False
	) Export
	
	CheckIfExchangesPossible();
	
	CheckUseDataExchange();
	
	// Exchange via the external connection.
	If ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.COM Then
		
		ValidateExternalConnection();
		
		If PerformImport Then
			
			// UPLOAD DATA VIA OUTER JOIN
			ExecuteExchangeActionForInfobaseNodeByExternalConnection(Cancel, 
																	InfobaseNode, 
																	Enums.ActionsAtExchange.DataImport, 
																	Undefined);
			
		EndIf;
		
		If PerformExport Then
			
			// EXPORT DATA VIA OUTER JOIN
			ExecuteExchangeActionForInfobaseNodeByExternalConnection(Cancel, 
																	InfobaseNode, 
																	Enums.ActionsAtExchange.DataExport, 
																	Undefined);
			
		EndIf;
		
	ElsIf ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.WS Then // Exchange via Web service
		
		If PerformImport Then
			
			// DATA UPLOAD VIA THE WEB SERVICE
			ExecuteExchangeOverWebServiceActionForInfobaseNode(Cancel, 
																	InfobaseNode, 
																	Enums.ActionsAtExchange.DataImport, 
																	LongOperation, 
																	ActionID, 
																	FileID,
																	LongOperationAllowed,
																	AuthenticationParameters,
																	OnlyParameters);
			
		EndIf;
		
		If PerformExport Then
			
			// DATA EXPORT VIA THE WEB SERVICE
			ExecuteExchangeOverWebServiceActionForInfobaseNode(Cancel, 
																	InfobaseNode, 
																	Enums.ActionsAtExchange.DataExport, 
																	LongOperation, 
																	ActionID, 
																	FileID, 
																	LongOperationAllowed,
																	AuthenticationParameters,
																	OnlyParameters);
			
		EndIf;
		
	Else // Exchange via normal connection channels.
		
		If PerformImport Then
			
			// DATA UPLOAD
			RunExchangeActionForInfobaseNode(Cancel,
															InfobaseNode,
															Enums.ActionsAtExchange.DataImport,
															ExchangeMessageTransportKind,
															OnlyParameters);
			
		EndIf;
		
		If PerformExport Then
			
			// DATA EXPORT
			RunExchangeActionForInfobaseNode(Cancel,
															InfobaseNode,
															Enums.ActionsAtExchange.DataExport,
															ExchangeMessageTransportKind,
															OnlyParameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Exchanges data separately for each row of the exchange setting.
// Data exchange process consists of two stages:
// - exchange initialization - preparation of the exchange data subsystem to the exchange process
// - data exchange        - process of the message file reading and the subsequent import of
// this data to IB or export of changes to the message file.
// Initialization stage is executed once per session and saved in the session cache on server before the restart of session or the reset of the reused values of the data exchange subsystem.
// The reset of the reused values is executed while changing the
// data influencing the process of the data exchange (transport setings, exchange setting, filters on the exchange plan nodes setting).
//
// Exchange can be executed completely for all
// rows of the script or can be executed for the individual TS row of the exchange script.
//
// Parameters:
//  Cancel                     - Boolean - check box of denial; selected if an error occurs while executing the script.
//  ExchangeExecutionSettings - CatalogRef.DataExchangeScripts - item
//                              of the catalog by values of attributes of which the data exchange will be executed.
//  LineNumber               - Number - String number according to which the data was exchanged.
//                              If it is not specified, the data exchange will be performed for all strings.
// 
Procedure ExecuteDataExchangeByScenarioOfExchangeData(Cancel, ExchangeExecutionSettings, LineNumber = Undefined) Export
	
	CheckIfExchangesPossible();
	
	CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	QueryText = "
	|SELECT
	|	ExchangeExecutionSettingsExchangeSettings.Ref                         AS ExchangeExecutionSettings,
	|	ExchangeExecutionSettingsExchangeSettings.LineNumber                    AS LineNumber,
	|	ExchangeExecutionSettingsExchangeSettings.RunningAction            AS RunningAction,
	|	ExchangeExecutionSettingsExchangeSettings.ExchangeTransportKind            AS ExchangeTransportKind,
	|	ExchangeExecutionSettingsExchangeSettings.InfobaseNode         AS InfobaseNode,
	|
	|	CASE WHEN ExchangeExecutionSettingsExchangeSettings.ExchangeTransportKind = VALUE(Enum.ExchangeMessagesTransportKinds.COM)
	|	THEN TRUE
	|	ELSE FALSE
	|	END AS ExchangeOverExternalConnection,
	|
	|	CASE WHEN ExchangeExecutionSettingsExchangeSettings.ExchangeTransportKind = VALUE(Enum.ExchangeMessagesTransportKinds.WS)
	|	THEN TRUE
	|	ELSE FALSE
	|	END AS ExchangeOverWebService
	|FROM
	|	Catalog.DataExchangeScripts.ExchangeSettings AS ExchangeExecutionSettingsExchangeSettings
	|WHERE
	|	ExchangeExecutionSettingsExchangeSettings.Ref = &ExchangeExecutionSettings
	|	[LineNumberCondition]
	|ORDER BY
	|	ExchangeExecutionSettingsExchangeSettings.LineNumber
	|";
	
	LineNumberCondition = ?(LineNumber = Undefined, "", "And ExchangeExecutionSettingsExchangeSettings.LineNumber = &LineNumber");
	
	QueryText = StrReplace(QueryText, "[ConditionByLineNumber]", LineNumberCondition);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangeExecutionSettings", ExchangeExecutionSettings);
	Query.SetParameter("LineNumber", LineNumber);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Selection.ExchangeOverExternalConnection Then
			
			ValidateExternalConnection();
			
			ItemCountInTransaction = ItemsQuantityInExecutedActionTransaction(Selection.RunningAction);
			
			ExecuteExchangeActionForInfobaseNodeByExternalConnection(Cancel, Selection.InfobaseNode, Selection.RunningAction, ItemCountInTransaction);
			
		ElsIf Selection.ExchangeOverWebService Then
			
			ExecuteExchangeOverWebServiceActionForInfobaseNode(Cancel, Selection.InfobaseNode, Selection.RunningAction);
			
		Else
			
			// DATA EXCHANGE INITIALIZATION
			ExchangeSettingsStructure = DataExchangeReUse.GetExchangeSettingsStructure(Selection.ExchangeExecutionSettings, Selection.LineNumber);
			
			// If setting contains errors, then do not exchange; the Canceled status.
			If ExchangeSettingsStructure.Cancel Then
				
				Cancel = True;
				
				// Write the log by the data exchange to ELM.
				FixEndExchange(ExchangeSettingsStructure);
				Continue;
			EndIf;
			
			ExchangeSettingsStructure.ExchangeProcessResult = Undefined;
			ExchangeSettingsStructure.StartDate = CurrentSessionDate();
			
			// Add information about data exchange process to ELM.
			MessageString = NStr("en='Data exchange process start for setting %1';ru='Начало процесса обмена данными по настройке %1'", CommonUseClientServer.MainLanguageCode());
			MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeSettingsStructure.ExchangeExecutionSettingsDescription);
			WriteLogEventOfDataExchange(MessageString, ExchangeSettingsStructure);
			
			// Data exchange
			ExecuteDataExchangeThroughFileResource(ExchangeSettingsStructure);
			
			// Write the log by the data exchange to ELM.
			FixEndExchange(ExchangeSettingsStructure);
			
			If Not ExchangeProcessResultCompleted(ExchangeSettingsStructure.ExchangeProcessResult) Then
				
				Cancel = True;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Entry point for the data exchange execution by the scheduled job exchange script.
//
// Parameters:
//  ExchangeScenarioCode - String - code of the Scripts of data exchanges  catalog
//                               item for which the data exchange will be executed.
// 
Procedure ExecuteDataExchangeByScheduledJob(ExchangeScenarioCode) Export
	
	// Call OnBeginScheduledJobExecution
	// is not used as required actions are executed privately.
	
	CheckIfExchangesPossible();
	
	CheckUseDataExchange();
	
	If Not ValueIsFilled(ExchangeScenarioCode) Then
		Raise NStr("en='Data exchange scenario is not specified.';ru='Не задан сценарий обмена данными.'");
	EndIf;
	
	QueryText = "
	|SELECT
	|	DataExchangeScripts.Ref AS Ref
	|FROM
	|	Catalog.DataExchangeScripts AS DataExchangeScripts
	|WHERE
	|		 DataExchangeScripts.Code = &Code
	|	AND Not DataExchangeScripts.DeletionMark
	|";
	
	Query = New Query;
	Query.SetParameter("Code", ExchangeScenarioCode);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		// Perform exchange scenario.
		ExecuteDataExchangeByScenarioOfExchangeData(False, Selection.Ref);
	Else
		MessageString = NStr("en='Data exchange script with code %1 is not found.';ru='Сценарий обмена данными с кодом %1 не найден.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeScenarioCode);
		Raise MessageString;
	EndIf;
	
EndProcedure

//

// Message exchange receives a temporary directory of the user OS.
//
// Parameters:
//  Cancel                        - Boolean - check box of denial; selected in case an error occurs.
//  InfobaseNode       - ExchangePlanRef - node of the exchange plan for which
//                                                    the exchange message is received.
//  ExchangeMessageTransportKind - EnumRef.ExchangeMessagesTransportKinds - kind of transport
//                                                                                    for receiving the exchange message.
//  OutputMessages            - Boolean - if True, then the messages are displayed to the user.
//
//  Returns:
//   Structure with the following keys:
//     * ExchangeMessagesTemporaryDirectoryName - full name of the exchange directory where exchange message was exported.
//     * ExchangeMessageFileName              - full name of the exchange message file.
//     * DataPackFileIdentifier       - change date of the exchange message file.
//
Function GetExchangeMessageToTemporaryDirectory(Cancel, InfobaseNode, ExchangeMessageTransportKind, OutputMessages = True) Export
	
	// Return value of the function.
	Result = New Structure;
	Result.Insert("TemporaryExchangeMessagesDirectoryName", "");
	Result.Insert("ExchangeMessageFileName",              "");
	Result.Insert("DataPackageFileID",       Undefined);
	
	ExchangeSettingsStructure = DataExchangeReUse.GetSettingsStructureOfTransport(InfobaseNode, ExchangeMessageTransportKind);
	
	ExchangeSettingsStructure.ExchangeProcessResult = Undefined;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	// If the setting contains errors, then do not receive the exchange messages; the Canceled status.
	If ExchangeSettingsStructure.Cancel Then
		
		If OutputMessages Then
			NString = NStr("en='Errors occurred while initializing processing of exchange message transport.';ru='При инициализации обработки транспорта сообщений обмена возникли ошибки.'");
			CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		EndIf;
		
		FixEndExchange(ExchangeSettingsStructure);
		Return Result;
	EndIf;
	
	// create a temporary directory
	RunExchangeMessagesTransportBeforeProcessing(ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.ExchangeProcessResult = Undefined Then
		
		// Receive message to a temporary directory.
		RunExchangeMessagesTransportReceiving(ExchangeSettingsStructure);
		
	EndIf;
	
	If ExchangeSettingsStructure.ExchangeProcessResult <> Undefined Then
		
		If OutputMessages Then
			NString = NStr("en='Errors occurred while receiving exchange messages.';ru='При получении сообщений обмена возникли ошибки.'");
			CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		EndIf;
		
		// Delete the temporary directory and its contents.
		RunExchangeMessagesTransportAfterProcessing(ExchangeSettingsStructure);
		
		FixEndExchange(ExchangeSettingsStructure);
		Return Result;
	EndIf;
	
	Result.TemporaryExchangeMessagesDirectoryName = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageDirectoryName();
	Result.ExchangeMessageFileName              = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageFileName();
	Result.DataPackageFileID       = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageFileDate();
	
	Return Result;
EndFunction

// Receives the exchange message from the correspondent infobase to the temporary directory of OS user.
//
// Parameters:
//  Cancel                        - Boolean - check box of denial; selected in case an error occurs.
//  InfobaseNode       - ExchangePlanRef - node of the exchange plan for which
//                                                    the exchange message is received.
//  OutputMessages            - Boolean - if True, then the messages are displayed to the user.
//
//  Returns:
//   Structure with the following keys:
//     * ExchangeMessagesTemporaryDirectoryName - full name of the exchange directory where exchange message was exported.
//     * ExchangeMessageFileName              - full name of the exchange message file.
//     * DataPackFileIdentifier       - change date of the exchange message file.
//
Function GetExchangeMessageFromCorrespondentInfobaseToTempDirectory(Cancel, InfobaseNode, OutputMessages = True) Export
	
	// Return value of the function.
	Result = New Structure;
	Result.Insert("TemporaryExchangeMessagesDirectoryName", "");
	Result.Insert("ExchangeMessageFileName",              "");
	Result.Insert("DataPackageFileID",       Undefined);
	
	ExchangePlanName = DataExchangeReUse.GetExchangePlanName(InfobaseNode);
	CurrentExchangePlanNode = DataExchangeReUse.GetThisNodeOfExchangePlan(ExchangePlanName);
	CurrentExchangePlanNodeCode = CommonUse.ObjectAttributeValue(CurrentExchangePlanNode, "Code");
	
	MessageFileTemplateName = GetMessageFileTemplateName(CurrentExchangePlanNode, InfobaseNode, False);
	
	// parameters that will be defined in the function.
	ExchangeMessageFileDate = Date('00010101');
	ExchangeMessageDirectoryName = "";
	ErrorMessageString = "";
	
	Try
		ExchangeMessageDirectoryName = CreateTemporaryDirectoryOfExchangeMessages();
	Except
		If OutputMessages Then
			Message = NStr("en='Cannot exchange: %1';ru='Не удалось произвести обмен: %1'");
			Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
			CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		EndIf;
		Return Result;
	EndTry;
	
	// Receive external connection for the infobase node.
	DataConnection = DataExchangeReUse.OuterJoinForAnInformationBaseNode(InfobaseNode);
	ExternalConnection = DataConnection.Join;
	
	If ExternalConnection = Undefined Then
		
		Message = NStr("en='Cannot exchange: %1';ru='Не удалось произвести обмен: %1'");
		If OutputMessages Then
			MessageForUser = StringFunctionsClientServer.SubstituteParametersInString(Message, DataConnection.ErrorShortInfo);
			CommonUseClientServer.MessageToUser(MessageForUser,,,, Cancel);
		EndIf;
		
		// Add two records to ELM: one for data import, another for data export.
		ExchangeSettingsStructure = New Structure("EventLogMonitorMessageKey");
		ExchangeSettingsStructure.EventLogMonitorMessageKey = GetEventLogMonitorMessageKey(InfobaseNode, Enums.ActionsAtExchange.DataImport);
		
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DataConnection.DetailedErrorDescription);
		WriteLogEventOfDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndIf;
	
	ExchangeMessageFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName, MessageFileTemplateName + ".xml");
	
	ExternalConnection.DataExchangeExternalConnection.ExportForInfobaseNode(Cancel, ExchangePlanName, CurrentExchangePlanNodeCode, ExchangeMessageFileName, ErrorMessageString);
	
	If Cancel Then
		
		If OutputMessages Then
			// Output an error message.
			Message = NStr("en='Cannot export data: %1';ru='Не удалось выгрузить данные: %1'");
			Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DataConnection.ErrorShortInfo);
			CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		EndIf;
		
		Return Result;
	EndIf;
	
	FileExchangeMessages = New File(ExchangeMessageFileName);
	If FileExchangeMessages.Exist() Then
		ExchangeMessageFileDate = FileExchangeMessages.GetModificationTime();
	EndIf;
	
	Result.TemporaryExchangeMessagesDirectoryName = ExchangeMessageDirectoryName;
	Result.ExchangeMessageFileName              = ExchangeMessageFileName;
	Result.DataPackageFileID       = ExchangeMessageFileDate;
	
	Return Result;
EndFunction

// Receives the exchange message from the correspondent infobase via the web service
// to the temporary directory of the OS user.
//
// Parameters:
//  Cancel                   - Boolean - check box of denial; selected in case an error occurs.
//  InfobaseNode  - ExchangePlanRef - node of the exchange plan for which the exchange message is received.
//  FileID      - UUID - File identifier.
//  LongOperation      - Boolean - Shows that the long operation was used.
//  ActionID   - UUID - Unique identifier of a long operation.
//  AuthenticationParameters - Structure. Contains the authentication Parameters to a Web service user Password).
//
//  Returns:
//   Structure with the following keys:
//     * ExchangeMessagesTemporaryDirectoryName - full name of the exchange directory where exchange message was exported.
//     * ExchangeMessageFileName              - full name of the exchange message file.
//     * DataPackFileIdentifier       - change date of the exchange message file.
//
Function GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebService(
											Cancel,
											InfobaseNode,
											FileID,
											LongOperation,
											ActionID,
											AuthenticationParameters = Undefined
	) Export
	
	CheckIfExchangesPossible();
	
	CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	// Return value of the function.
	Result = New Structure;
	Result.Insert("TemporaryExchangeMessagesDirectoryName", "");
	Result.Insert("ExchangeMessageFileName",              "");
	Result.Insert("DataPackageFileID",       Undefined);
	
	ExchangePlanName = DataExchangeReUse.GetExchangePlanName(InfobaseNode);
	CurrentExchangePlanNode = DataExchangeReUse.GetThisNodeOfExchangePlan(ExchangePlanName);
	CurrentExchangePlanNodeCode = CommonUse.ObjectAttributeValue(CurrentExchangePlanNode, "Code");
	
	// parameters that will be defined in the function.
	ExchangeMessageDirectoryName = "";
	ExchangeMessageFileName = "";
	ExchangeMessageFileDate = Date('00010101');
	ErrorMessageString = "";
	
	// Receive the web service proxy for infobase node.
	Proxy = GetWSProxyForInfobaseNode(InfobaseNode, ErrorMessageString, AuthenticationParameters);
	
	If Proxy = Undefined Then
		
		Cancel = True;
		Message = NStr("en='An error occurred when establishing connection to the second infobase: %1';ru='Ошибка при установке подключения ко второй информационной базе: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ErrorMessageString);
		ExchangeSettingsStructure = New Structure("EventLogMonitorMessageKey");
		ExchangeSettingsStructure.EventLogMonitorMessageKey = GetEventLogMonitorMessageKey(InfobaseNode, Enums.ActionsAtExchange.DataImport);
		WriteLogEventOfDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndIf;
	
	Try
		
		Proxy.ExecuteDataExport(
			ExchangePlanName,
			CurrentExchangePlanNodeCode,
			FileID,
			LongOperation,
			ActionID,
			True);
		
	Except
		
		Cancel = True;
		Message = NStr("en='When exporting data, errors occurred in the second infobase: %1';ru='При выгрузке данных возникли ошибки во второй информационной базе: %1'", CommonUseClientServer.MainLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMonitorMessageKey");
		ExchangeSettingsStructure.EventLogMonitorMessageKey = GetEventLogMonitorMessageKey(InfobaseNode, Enums.ActionsAtExchange.DataImport);
		WriteLogEventOfDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	If LongOperation Then
		ExchangeSettingsStructure = New Structure("EventLogMonitorMessageKey");
		ExchangeSettingsStructure.EventLogMonitorMessageKey = GetEventLogMonitorMessageKey(InfobaseNode, Enums.ActionsAtExchange.DataImport);
		WriteLogEventOfDataExchange(NStr("en='Pending data from the correspondent base...';ru='Ожидание получения данных от базы-корреспондента...'",
			CommonUseClientServer.MainLanguageCode()), ExchangeSettingsStructure);
		Return Result;
	EndIf;
	
	Try
		FileTransferServiceFileName = GetFileFromStorageInService(New UUID(FileID), InfobaseNode,, AuthenticationParameters);
	Except
		
		Cancel = True;
		Message = NStr("en='Errors occurred when receiving an exchange message from file transfer service: %1';ru='Возникли ошибки при получении сообщения обмена из сервиса передачи файлов: %1'", CommonUseClientServer.MainLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMonitorMessageKey");
		ExchangeSettingsStructure.EventLogMonitorMessageKey = GetEventLogMonitorMessageKey(InfobaseNode, Enums.ActionsAtExchange.DataImport);
		WriteLogEventOfDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	Try
		ExchangeMessageDirectoryName = CreateTemporaryDirectoryOfExchangeMessages();
	Except
		Cancel = True;
		Message = NStr("en='Errors occurred while receiving exchange messages: %1';ru='При получении сообщения обмена возникли ошибки: %1'", CommonUseClientServer.MainLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMonitorMessageKey");
		ExchangeSettingsStructure.EventLogMonitorMessageKey = GetEventLogMonitorMessageKey(InfobaseNode, Enums.ActionsAtExchange.DataImport);
		WriteLogEventOfDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	MessageFileTemplateName = GetMessageFileTemplateName(CurrentExchangePlanNode, InfobaseNode, False);
	
	ExchangeMessageFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName, MessageFileTemplateName + ".xml");
	
	MoveFile(FileTransferServiceFileName, ExchangeMessageFileName);
	
	FileExchangeMessages = New File(ExchangeMessageFileName);
	If FileExchangeMessages.Exist() Then
		ExchangeMessageFileDate = FileExchangeMessages.GetModificationTime();
	EndIf;
	
	Result.TemporaryExchangeMessagesDirectoryName = ExchangeMessageDirectoryName;
	Result.ExchangeMessageFileName              = ExchangeMessageFileName;
	Result.DataPackageFileID       = ExchangeMessageFileDate;
	
	Return Result;
EndFunction

// It receives the exchange message from the correspondent database using the web service.
// It saves the received exchange message in the temporary directory.
// Used in case the message receipt is executed in the context of
// the background job in base-correspondent.
//
// Parameters:
//  Cancel                   - Boolean - check box of denial; selected in case an error occurs.
//  InfobaseNode  - ExchangePlanRef - node of the exchange plan for which the exchange message is received.
//  FileID      - UUID - File identifier.
//  AuthenticationParameters - Structure. Contains the authentication Parameters to a Web service user Password).
//
//  Returns:
//   Structure with the following keys:
//     * ExchangeMessagesTemporaryDirectoryName - full name of the exchange directory where exchange message was exported.
//     * ExchangeMessageFileName              - full name of the exchange message file.
//     * DataPackFileIdentifier       - change date of the exchange message file.
//
Function GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebServiceFinishLongOperation(
							Cancel,
							InfobaseNode,
							FileID,
							Val AuthenticationParameters = Undefined
	) Export
	
	// Return value of the function.
	Result = New Structure;
	Result.Insert("TemporaryExchangeMessagesDirectoryName", "");
	Result.Insert("ExchangeMessageFileName",              "");
	Result.Insert("DataPackageFileID",       Undefined);
	
	// parameters that will be defined in the function.
	ExchangeMessageDirectoryName = "";
	ExchangeMessageFileName = "";
	ExchangeMessageFileDate = Date('00010101');
	ErrorMessageString = "";
	
	Try
		
		FileTransferServiceFileName = GetFileFromStorageInService(New UUID(FileID), InfobaseNode,, AuthenticationParameters);
	Except
		
		Cancel = True;
		Message = NStr("en='Errors occurred when receiving an exchange message from file transfer service: %1';ru='Возникли ошибки при получении сообщения обмена из сервиса передачи файлов: %1'", CommonUseClientServer.MainLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMonitorMessageKey");
		ExchangeSettingsStructure.EventLogMonitorMessageKey = GetEventLogMonitorMessageKey(InfobaseNode, Enums.ActionsAtExchange.DataImport);
		WriteLogEventOfDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	Try
		ExchangeMessageDirectoryName = CreateTemporaryDirectoryOfExchangeMessages();
	Except
		Cancel = True;
		Message = NStr("en='Errors occurred while receiving exchange messages: %1';ru='При получении сообщения обмена возникли ошибки: %1'", CommonUseClientServer.MainLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMonitorMessageKey");
		ExchangeSettingsStructure.EventLogMonitorMessageKey = GetEventLogMonitorMessageKey(InfobaseNode, Enums.ActionsAtExchange.DataImport);
		WriteLogEventOfDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	ExchangePlanName = DataExchangeReUse.GetExchangePlanName(InfobaseNode);
	CurrentExchangePlanNode = DataExchangeReUse.GetThisNodeOfExchangePlan(ExchangePlanName);
	
	MessageFileTemplateName = GetMessageFileTemplateName(CurrentExchangePlanNode, InfobaseNode, False);
	
	ExchangeMessageFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName, MessageFileTemplateName + ".xml");
	
	MoveFile(FileTransferServiceFileName, ExchangeMessageFileName);
	
	FileExchangeMessages = New File(ExchangeMessageFileName);
	If FileExchangeMessages.Exist() Then
		ExchangeMessageFileDate = FileExchangeMessages.GetModificationTime();
	EndIf;
	
	Result.TemporaryExchangeMessagesDirectoryName = ExchangeMessageDirectoryName;
	Result.ExchangeMessageFileName              = ExchangeMessageFileName;
	Result.DataPackageFileID       = ExchangeMessageFileDate;
	
	Return Result;
EndFunction

// Receives exchange message file from the base-correspondent via the web service.
// It imports the received exchange message file to this base.
//
// Parameters:
//  Cancel                   - Boolean - check box of denial; selected in case an error occurs.
//  InfobaseNode  - ExchangePlanRef - node of the exchange plan for which the exchange message is received.
//  FileID      - UUID - File identifier.
//  OperationStartDate      - Date - Import start date.
//  AuthenticationParameters - Structure. Contains the authentication Parameters to a Web service user Password).
//
Procedure ExecuteDataExchangeForInfobaseNodeFinishLongOperation(
															Cancel,
															Val InfobaseNode,
															Val FileID,
															Val OperationStartDate,
															Val AuthenticationParameters = Undefined,
															ShowError = False
	) Export
	
	CheckIfExchangesPossible();
	
	CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	Try
		FileExchangeMessages = GetFileFromStorageInService(New UUID(FileID), InfobaseNode,, AuthenticationParameters);
	Except
		FixExchangeFinishedWithError(InfobaseNode,
			Enums.ActionsAtExchange.DataImport,
			OperationStartDate,
			DetailErrorDescription(ErrorInfo()));
		If ShowError Then
			Raise;
		Else
			Cancel = True;
		EndIf;
		Return;
	EndTry;
	
	// Import exchange message file to this base.
	Try
		ExecuteDataExchangeForInfobaseNodeOverFileOrString(
			InfobaseNode,
			FileExchangeMessages,
			Enums.ActionsAtExchange.DataImport,,,, OperationStartDate);
	Except
		FixExchangeFinishedWithError(InfobaseNode,
			Enums.ActionsAtExchange.DataImport,
			OperationStartDate,
			DetailErrorDescription(ErrorInfo()));
		If ShowError Then
			Raise;
		Else
			Cancel = True;
		EndIf;
	EndTry;
	
	Try
		DeleteFiles(FileExchangeMessages);
	Except
	EndTry;
	
EndProcedure

// Deletes files of the exchange messages that were not deleted because of errors in the system work.
// Files with posting date that exceeds 24 hours from the current universal date are subject to removal.
// IR.DataExchangeMessages and IR.DataFieldsDataExchangeMessages are being analyzed
//
// Parameters:
// No.
//
Procedure DeleteInvalidMessagesFromDataExchange() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	CheckExchangesAdministrationPossibility();
	
	SetPrivilegedMode(True);
	
	// Delete irrelevant exchange messages marked in IR.DataExchangeMessages.
	QueryText =
	"SELECT
	|	DataExchangeMessages.MessageID AS MessageID,
	|	DataExchangeMessages.MessageFileName AS FileName
	|FROM
	|	InformationRegister.DataExchangeMessages AS DataExchangeMessages
	|WHERE
	|	DataExchangeMessages.MessageSendingDate < &UpdateDate";
	
	Query = New Query;
	Query.SetParameter("UpdateDate", CurrentUniversalDate() - 60 * 60 * 24);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		MessageFileFullName = CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), Selection.FileName);
		
		MessageFile = New File(MessageFileFullName);
		
		If MessageFile.Exist() Then
			
			Try
				DeleteFiles(MessageFile.FullName);
			Except
				WriteLogEvent(EventLogMonitorMessageTextDataExchange(),
					EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
				Continue;
			EndTry;
		EndIf;
		
		// Delete information about the exchange message file from the storage.
		RecordStructure = New Structure;
		RecordStructure.Insert("MessageID", String(Selection.MessageID));
		InformationRegisters.DataExchangeMessages.DeleteRecord(RecordStructure);
		
	EndDo;
	
	// Delete irrelevant exchange messages marked in IR.DataAreasDataExchangeMessages.
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = CommonUse.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnDeleteOutdatedMessagesExchange();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For work via the external connection.

// For an internal use.
// 
Procedure ExportToTempStorageForInfobaseNode(Val ExchangePlanName, Val CodeOfInfobaseNode, Address) Export
	
	ExchangeMessageFullFileName = GetTempFileName("xml");
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(
		Undefined,
		ExchangeMessageFullFileName,
		Enums.ActionsAtExchange.DataExport,
		ExchangePlanName,
		CodeOfInfobaseNode);
	
	Address = PutToTempStorage(New BinaryData(ExchangeMessageFullFileName));
	
	DeleteFiles(ExchangeMessageFullFileName);
	
EndProcedure

// For an internal use.
// 
Procedure ExportToFileTransferServiceForInfobaseNode(Val ExchangePlanName,
	Val CodeOfInfobaseNode,
	Val FileID) Export
	
	SetPrivilegedMode(True);
	
	MessageFileName = CommonUseClientServer.GetFullFileName(
		TempFileStorageDirectory(),
		UniqueExchangeMessageFileName());
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(
		Undefined,
		MessageFileName,
		Enums.ActionsAtExchange.DataExport,
		ExchangePlanName,
		CodeOfInfobaseNode);
	
	PutFileToStorage(MessageFileName, FileID);
	
EndProcedure

// For an internal use.
// 
Procedure ExportDataForInfobaseNodeViaFile(Val ExchangePlanName,
	Val CodeOfInfobaseNode,
	Val ExchangeMessageFullFileName) Export
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(
		Undefined,
		ExchangeMessageFullFileName,
		Enums.ActionsAtExchange.DataExport,
		ExchangePlanName,
		CodeOfInfobaseNode);
	
EndProcedure

// For an internal use.
// 
Procedure ExportForInfobaseNodeViaString(Val ExchangePlanName, Val CodeOfInfobaseNode, ExchangeMessage) Export
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(Undefined,
												"",
												Enums.ActionsAtExchange.DataExport,
												ExchangePlanName,
												CodeOfInfobaseNode,
												ExchangeMessage);
	
EndProcedure

// For an internal use.
// 
Procedure ImportForInfobaseNodeViaString(Val ExchangePlanName, Val CodeOfInfobaseNode, ExchangeMessage) Export
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(Undefined,
												"",
												Enums.ActionsAtExchange.DataImport,
												ExchangePlanName,
												CodeOfInfobaseNode,
												ExchangeMessage);
	
EndProcedure

// For an internal use.
// 
Procedure ImportForInfobaseNodeFromFileTransferService(Val ExchangePlanName,
	Val CodeOfInfobaseNode,
	Val FileID) Export
	
	SetPrivilegedMode(True);
	
	TempFileName = GetFileFromStorage(FileID);
	
	Try
		ExecuteDataExchangeForInfobaseNodeOverFileOrString(
			Undefined,
			TempFileName,
			Enums.ActionsAtExchange.DataImport,
			ExchangePlanName,
			CodeOfInfobaseNode);
	Except
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		DeleteFiles(TempFileName);
		Raise ErrorPresentation;
	EndTry;
	
	DeleteFiles(TempFileName);
EndProcedure

// For an internal use.
// 
Procedure ExecuteDataExchangeForInfobaseNodeOverFileOrString(InfobaseNode = Undefined,
																			ExchangeMessageFullFileName = "",
																			ActionOnExchange,
																			ExchangePlanName = "",
																			CodeOfInfobaseNode = "",
																			ExchangeMessage = "",
																			OperationStartDate = Undefined
	) Export
	
	CheckIfExchangesPossible();
	
	CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	If InfobaseNode = Undefined Then
		
		InfobaseNode = ExchangePlans[ExchangePlanName].FindByCode(CodeOfInfobaseNode);
		
		If InfobaseNode.IsEmpty() Then
			ErrorMessageString = NStr("en='Exchange plan node %1 with code %2 is not found.';ru='Узел плана обмена %1 с кодом %2 не найден.'");
			ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, ExchangePlanName, CodeOfInfobaseNode);
			Raise ErrorMessageString;
		EndIf;
		
	EndIf;
	
	// DATA EXCHANGE INITIALIZATION
	ExchangeSettingsStructure = DataExchangeReUse.GetExchangeSettingsStructureForInfobaseNode(InfobaseNode, ActionOnExchange, Undefined, False);
	
	If ExchangeSettingsStructure.Cancel Then
		ErrorMessageString = NStr("en='An error occurred when initializing the data exchange process.';ru='Ошибка при инициализации процесса обмена данными.'");
		FixEndExchange(ExchangeSettingsStructure);
		Raise ErrorMessageString;
	EndIf;
	
	ExchangeSettingsStructure.ExchangeProcessResult = Undefined;
	ExchangeSettingsStructure.StartDate = ?(OperationStartDate = Undefined, CurrentSessionDate(), OperationStartDate);
	
	MessageString = NStr("en='Data exchange process start for node %1';ru='Начало процесса обмена данными для узла %1'", CommonUseClientServer.MainLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteLogEventOfDataExchange(MessageString, ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.DoDataImport Then
		
		TemporaryFileCreated = False;
		If ExchangeMessageFullFileName = ""
		   AND ExchangeMessage <> "" Then
			
			ExchangeMessageFullFileName = GetTempFileName(".xml");
			TextFile = New TextDocument;
			TextFile.SetText(ExchangeMessage);
			TextFile.Write(ExchangeMessageFullFileName);
			TemporaryFileCreated = True;
		EndIf;
		
		ReadMessageWithChangesForNode(ExchangeSettingsStructure, ExchangeMessageFullFileName, ExchangeMessage);
		
		// {Handler: AfterExchangeMessageReading} Begin
		StandardProcessing = True;
		
		AfterReadingMessageExchange(
					ExchangeSettingsStructure.InfobaseNode,
					ExchangeMessageFullFileName,
					ExchangeProcessResultCompleted(ExchangeSettingsStructure.ExchangeProcessResult),
					StandardProcessing);
		// {Handler: AfterExchangeMessageReading} End
		
		If TemporaryFileCreated Then
			
			Try
				DeleteFiles(ExchangeMessageFullFileName);
			Except
				WriteLogEvent(EventLogMonitorMessageTextDataExchange(),
					EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			EndTry;
		EndIf;
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		WriteMessageWithNodeChanges(ExchangeSettingsStructure, ExchangeMessageFullFileName, ExchangeMessage);
		
	EndIf;
	
	FixEndExchange(ExchangeSettingsStructure);
	
	If Not ExchangeProcessResultCompleted(ExchangeSettingsStructure.ExchangeProcessResult) Then
		Raise ExchangeSettingsStructure.ErrorMessageString;
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure AddExchangeOverExternalConnectionFinishEventLogMonitorMessage(ExchangeSettingsStructure) Export
	
	SetPrivilegedMode(True);
	
	FixEndExchange(ExchangeSettingsStructure);
	
EndProcedure

// For an internal use.
// 
Function ExchangeOverExternalConnectionSettingsStructure(Structure) Export
	
	CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	InfobaseNode = ExchangePlans[Structure.ExchangePlanName].FindByCode(Structure.CurrentExchangePlanNodeCode);
	
	ActionOnExchange = Enums.ActionsAtExchange[Structure.ExchangeActionString];
	
	ExchangeSettingsStructureExternalConnection = New Structure;
	ExchangeSettingsStructureExternalConnection.Insert("ExchangePlanName",                   Structure.ExchangePlanName);
	ExchangeSettingsStructureExternalConnection.Insert("DebugMode",                     Structure.DebugMode);
	
	ExchangeSettingsStructureExternalConnection.Insert("InfobaseNode",             InfobaseNode);
	ExchangeSettingsStructureExternalConnection.Insert("InfobaseNodeDescription", CommonUse.ObjectAttributeValue(InfobaseNode, "Description"));
	
	ExchangeSettingsStructureExternalConnection.Insert("EventLogMonitorMessageKey",  GetEventLogMonitorMessageKey(InfobaseNode, ActionOnExchange));
	
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeProcessResult",        Undefined);
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeExecutionResultString", "");
	
	ExchangeSettingsStructureExternalConnection.Insert("ActionOnExchange", ActionOnExchange);
	
	ExchangeSettingsStructureExternalConnection.Insert("DebuggingExportHandlers ", False);
	ExchangeSettingsStructureExternalConnection.Insert("DebuggingImportHandlers", False);
	ExchangeSettingsStructureExternalConnection.Insert("FileNameOfExternalDataProcessorOfExportDebugging", "");
	ExchangeSettingsStructureExternalConnection.Insert("FileNameOfExternalDataProcessorOfImportDebugging", "");
	ExchangeSettingsStructureExternalConnection.Insert("DataExchangeLoggingMode", False);
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeProtocolFileName", "");
	ExchangeSettingsStructureExternalConnection.Insert("ContinueOnError", False);
	
	SetDebuggingModeSettingsForStructure(ExchangeSettingsStructureExternalConnection, True);
	
	ExchangeSettingsStructureExternalConnection.Insert("ProcessedObjectCount", 0);
	
	ExchangeSettingsStructureExternalConnection.Insert("StartDate",    Undefined);
	ExchangeSettingsStructureExternalConnection.Insert("EndDate", Undefined);
	
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeMessage",      "");
	ExchangeSettingsStructureExternalConnection.Insert("ErrorMessageString", "");
	
	ExchangeSettingsStructureExternalConnection.Insert("ItemCountInTransaction", Structure.ItemCountInTransaction);
	
	ExchangeSettingsStructureExternalConnection.Insert("IsDIBExchange", False);
	
	Return ExchangeSettingsStructureExternalConnection;
EndFunction

// For an internal use.
// 
Function GetObjectConversionRulesViaExternalConnection(ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.DataExchangeRules.GetReadObjectConversionRules(ExchangePlanName);
	
EndFunction

// For an internal use.
// 
Procedure RunExchangeActionForInfobaseNode(
		Cancel,
		InfobaseNode,
		ActionOnExchange,
		ExchangeMessageTransportKind = Undefined,
		Val OnlyParameters = False
	) Export
	
	SetPrivilegedMode(True);
	
	// DATA EXCHANGE INITIALIZATION
	ExchangeSettingsStructure = DataExchangeReUse.GetExchangeSettingsStructureForInfobaseNode(
		InfobaseNode, ActionOnExchange, ExchangeMessageTransportKind);
	
	If ExchangeSettingsStructure.Cancel Then
		
		// If setting contains errors, then do not exchange; the Canceled status.
		FixEndExchange(ExchangeSettingsStructure);
		
		Cancel = True;
		
		Return;
	EndIf;
	
	ExchangeSettingsStructure.ExchangeProcessResult = Undefined;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	MessageString = NStr("en='Data exchange process start for node %1';ru='Начало процесса обмена данными для узла %1'", CommonUseClientServer.MainLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteLogEventOfDataExchange(MessageString, ExchangeSettingsStructure);
	
	// Data exchange
	ExecuteDataExchangeThroughFileResource(ExchangeSettingsStructure, OnlyParameters);
	
	FixEndExchange(ExchangeSettingsStructure);
	
	If Not ExchangeProcessResultCompleted(ExchangeSettingsStructure.ExchangeProcessResult) Then
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure ExecuteExchangeOverWebServiceActionForInfobaseNode(Cancel,
																		InfobaseNode,
																		ActionOnExchange,
																		LongOperation = False,
																		ActionID = "",
																		FileID = "",
																		LongOperationAllowed = False,
																		AuthenticationParameters = Undefined,
																		Val OnlyParameters = False)
	
	SetPrivilegedMode(True);
	
	// DATA EXCHANGE INITIALIZATION
	ExchangeSettingsStructure = DataExchangeReUse.GetExchangeSettingsStructureForInfobaseNode(InfobaseNode, ActionOnExchange, Enums.ExchangeMessagesTransportKinds.WS, False);
	
	If ExchangeSettingsStructure.Cancel Then
		// If setting contains errors, then do not exchange; the Canceled status.
		FixEndExchange(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndIf;
	
	ExchangeSettingsStructure.ExchangeProcessResult = Undefined;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	MessageString = NStr("en='Data exchange process start for node %1';ru='Начало процесса обмена данными для узла %1'", CommonUseClientServer.MainLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteLogEventOfDataExchange(MessageString, ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.DoDataImport Then
		
		If ExchangeSettingsStructure.UseLargeDataTransfer Then
			
			// {Handler: BeforeExchangeMessageReading} Begin
			FileExchangeMessages = "";
			StandardProcessing = True;
			
			BeforeReadingMessageExchange(ExchangeSettingsStructure.InfobaseNode, FileExchangeMessages, StandardProcessing);
			// {Handler: BeforeReadingExchangeMessage} End
			
			If StandardProcessing Then
				
				ErrorMessageString = "";
				
				// Receive the web service proxy for infobase node.
				Proxy = GetWSProxyForInfobaseNode(InfobaseNode, ErrorMessageString, AuthenticationParameters);
				
				If Proxy = Undefined Then
					
					// add record to ELM
					WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
					
					// If setting contains errors, then do not exchange; the Canceled status.
					ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Canceled;
					FixEndExchange(ExchangeSettingsStructure);
					Cancel = True;
					Return;
				EndIf;
				
				FileExchangeMessages = "";
				
				Try
					
					Proxy.ExecuteDataExport(ExchangeSettingsStructure.ExchangePlanName,
									ExchangeSettingsStructure.CurrentExchangePlanNodeCode,
									FileID,
									LongOperation,
									ActionID,
									LongOperationAllowed);
					
					If LongOperation Then
						WriteLogEventOfDataExchange(NStr("en='Pending data from the correspondent base...';ru='Ожидание получения данных от базы-корреспондента...'",
							CommonUseClientServer.MainLanguageCode()), ExchangeSettingsStructure);
						Return;
					EndIf;
					
					FileExchangeMessages = GetFileFromStorageInService(New UUID(FileID), InfobaseNode,, AuthenticationParameters);
				Except
					WriteLogEventOfDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
					ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
					Cancel = True;
				EndTry;
				
			EndIf;
			
			If Not Cancel Then
				
				ReadMessageWithChangesForNode(ExchangeSettingsStructure, FileExchangeMessages,, OnlyParameters);
				
			EndIf;
			
			// {Handler: AfterExchangeMessageReading} Begin
			StandardProcessing = True;
			
			AfterReadingMessageExchange(
						ExchangeSettingsStructure.InfobaseNode,
						FileExchangeMessages,
						ExchangeProcessResultCompleted(ExchangeSettingsStructure.ExchangeProcessResult),
						StandardProcessing,
						Not OnlyParameters);
			// {Handler: AfterExchangeMessageReading} End
			
			If StandardProcessing Then
				
				Try
					If Not IsBlankString(FileExchangeMessages) AND TypeOf(GetDataExchangeMessageFromMainNode()) <> Type("Structure") Then
						DeleteFiles(FileExchangeMessages);
					EndIf;
				Except
					WriteLogEvent(EventLogMonitorMessageTextDataExchange(),
						EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
				EndTry;
				
			EndIf;
			
		Else
			
			ErrorMessageString = "";
			
			// Receive the web service proxy for infobase node.
			Proxy = GetWSProxyForInfobaseNode(InfobaseNode, ErrorMessageString, AuthenticationParameters);
			
			If Proxy = Undefined Then
				
				// add record to ELM
				WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
				
				// If setting contains errors, then do not exchange; the Canceled status.
				ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Canceled;
				FixEndExchange(ExchangeSettingsStructure);
				Cancel = True;
				Return;
			EndIf;
			
			ExchangeMessageStorage = Undefined;
			
			Try
				Proxy.ExecuteExport(ExchangeSettingsStructure.ExchangePlanName, ExchangeSettingsStructure.CurrentExchangePlanNodeCode, ExchangeMessageStorage);
				
				ReadMessageWithChangesForNode(ExchangeSettingsStructure,, ExchangeMessageStorage.Get());
				
			Except
				WriteLogEventOfDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
				ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
			EndTry;
			
		EndIf;
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		ErrorMessageString = "";
		
		// Receive the web service proxy for infobase node.
		Proxy = GetWSProxyForInfobaseNode(InfobaseNode, ErrorMessageString, AuthenticationParameters);
		
		If Proxy = Undefined Then
			
			// add record to ELM
			WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
			
			// If setting contains errors, then do not exchange; the Canceled status.
			ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Canceled;
			FixEndExchange(ExchangeSettingsStructure);
			Cancel = True;
			Return;
		EndIf;
		
		If ExchangeSettingsStructure.UseLargeDataTransfer Then
			
			FileExchangeMessages = CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), UniqueExchangeMessageFileName());
			
			WriteMessageWithNodeChanges(ExchangeSettingsStructure, FileExchangeMessages);
			
			// Send exchange message only if data is successfully exported.
			If ExchangeProcessResultCompleted(ExchangeSettingsStructure.ExchangeProcessResult) Then
				
				Try
					
					FileIDString = String(PutFileToStorageInService(FileExchangeMessages, InfobaseNode,, AuthenticationParameters));
					
					Try
						DeleteFiles(FileExchangeMessages);
					Except
					EndTry;
					
					Proxy.ExecuteDataImport(ExchangeSettingsStructure.ExchangePlanName,
									ExchangeSettingsStructure.CurrentExchangePlanNodeCode,
									FileIDString,
									LongOperation,
									ActionID,
									LongOperationAllowed);
					
					If LongOperation Then
						WriteLogEventOfDataExchange(NStr("en='Pending data import in the correspondent base...';ru='Ожидание загрузки данных в базе-корреспонденте...'",
							CommonUseClientServer.MainLanguageCode()), ExchangeSettingsStructure);
						Return;
					EndIf;
					
				Except
					WriteLogEventOfDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
					ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
					Cancel = True;
				EndTry;
				
			EndIf;
			
			Try
				DeleteFiles(FileExchangeMessages);
			Except
			EndTry;
			
		Else
			
			ExchangeMessage = "";
			
			Try
				
				WriteMessageWithNodeChanges(ExchangeSettingsStructure,, ExchangeMessage);
				
				// Send exchange message only if data is successfully exported.
				If ExchangeProcessResultCompleted(ExchangeSettingsStructure.ExchangeProcessResult) Then
					
					Proxy.Unload(ExchangeSettingsStructure.ExchangePlanName, ExchangeSettingsStructure.CurrentExchangePlanNodeCode, New ValueStorage(ExchangeMessage, New Deflation(9)));
					
				EndIf;
				
			Except
				WriteLogEventOfDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
				ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
			EndTry;
			
		EndIf;
		
	EndIf;
	
	FixEndExchange(ExchangeSettingsStructure);
	
	If Not ExchangeProcessResultCompleted(ExchangeSettingsStructure.ExchangeProcessResult) Then
		Cancel = True;
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure ExecuteExchangeActionForInfobaseNodeByExternalConnection(Cancel, InfobaseNode,
	ActionOnExchange,
	ItemCountInTransaction)
	
	SetPrivilegedMode(True);
	
	// DATA EXCHANGE INITIALIZATION
	ExchangeSettingsStructure = GetExchangeSettingsStructureForExternalConnection(
		InfobaseNode,
		ActionOnExchange,
		ItemCountInTransaction);
	
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	WriteLogEventDataExchangeStart(ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.Cancel Then
		// If setting contains errors, then do not exchange; the Canceled status.
		ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Canceled;
		FixEndExchange(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndIf;
	
	ErrorMessageString = "";
	
	// Receive external connection for the infobase node.
	ExternalConnection = DataExchangeReUse.GetExternalConnectionForInfobaseNode(
		InfobaseNode,
		ErrorMessageString);
	
	If ExternalConnection = Undefined Then
		
		// add record to ELM
		WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		// If setting contains errors, then do not exchange; the Canceled status.
		ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Canceled;
		FixEndExchange(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndIf;
	
	// Get version of the remote base.
	SSLVersionForExternalConnection = ExternalConnection.StandardSubsystemsServer.LibraryVersion();
	SSL20Exchange = CommonUseClientServer.CompareVersions("2.1.1.10", SSLVersionForExternalConnection) > 0;
	
	// INITIALIZATION OF DATA EXCHANGE (OUTER JOIN)
	Structure = New Structure("ExchangePlanName, CurrentExchangePlanNodeCode, ItemsQuantityInTransaction");
	FillPropertyValues(Structure, ExchangeSettingsStructure);
	
	// Execute reverse of enumeration values.
	ExchangeActionString = ?(ActionOnExchange = Enums.ActionsAtExchange.DataExport,
								CommonUse.NameOfEnumValue(Enums.ActionsAtExchange.DataImport),
								CommonUse.NameOfEnumValue(Enums.ActionsAtExchange.DataExport));
	//
	
	Structure.Insert("ExchangeActionString", ExchangeActionString);
	Structure.Insert("DebugMode", False);
	Structure.Insert("ExchangeProtocolFileName", "");
	
	Try
		ExchangeSettingsStructureExternalConnection = ExternalConnection.DataExchangeExternalConnection.ExchangeSettingsStructure(Structure);
	Except
		// add record to ELM
		WriteLogEventOfDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
		
		// If setting contains errors, then do not exchange; the Canceled status.
		ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Canceled;
		FixEndExchange(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndTry;
	
	ExchangeSettingsStructure.ExchangeProcessResult = Undefined;
	ExchangeSettingsStructureExternalConnection.StartDate = ExternalConnection.CurrentSessionDate();
	
	ExternalConnection.DataExchangeExternalConnection.WriteLogEventDataExchangeStart(ExchangeSettingsStructureExternalConnection);
	
	// Data exchange
	If ExchangeSettingsStructure.DoDataImport Then
		
		// Receive the exchange rules from the second IB.
		ObjectConversionRules = ExternalConnection.DataExchangeExternalConnection.GetObjectConversionRules(ExchangeSettingsStructureExternalConnection.ExchangePlanName);
		
		If ObjectConversionRules = Undefined Then
			
			// Exchange rules should be specified.
			NString = NStr("en='Conversion rules for exchange plan %1 are not specified in the second infobase. Exchange is canceled.';ru='Не заданы правила конвертации во второй информационной базе для плана обмена %1. Обмен отменен.'",
				CommonUseClientServer.MainLanguageCode());
			ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(NString, ExchangeSettingsStructureExternalConnection.ExchangePlanName);
			WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
			SetExchangeInitEnd(ExchangeSettingsStructure);
			Return;
		EndIf;
		
		// Processor for the data import.
		DataProcessorForDataImport = ExchangeSettingsStructure.DataExchangeDataProcessor;
		DataProcessorForDataImport.ExchangeFileName = "";
		DataProcessorForDataImport.ObjectsCountForTransactions = ExchangeSettingsStructure.ItemCountInTransaction;
		DataProcessorForDataImport.UseTransactions = (DataProcessorForDataImport.ObjectsCountForTransactions <> 1);
		DataProcessorForDataImport.ExecutingDataImportViaExternalConnection = True;
		
		// Receive initialized processor for the data export.
		DataExchangeDataProcessorExternalConnection = ExternalConnection.DataProcessors.InfobaseObjectsConversion.Create();
		DataExchangeDataProcessorExternalConnection.ExchangeMode = "Export";
		DataExchangeDataProcessorExternalConnection.SavedSettings = ObjectConversionRules;
		
		Try
			DataExchangeDataProcessorExternalConnection.RestoreRulesFromInternalFormat();
		Except
			WriteLogEventOfDataExchange(
				StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred in the second infobase: %1';ru='Возникла ошибка во второй информационной базе: %1'"),
				DetailErrorDescription(ErrorInfo())), ExchangeSettingsStructure, True
			);
			
			// If setting contains errors, then do not exchange; the Canceled status.
			ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Canceled;
			FixEndExchange(ExchangeSettingsStructure);
			Cancel = True;
			Return;
		EndTry;
		
		// specify exchange nods
		DataExchangeDataProcessorExternalConnection.NodeForExchange = ExchangeSettingsStructureExternalConnection.InfobaseNode;
		DataExchangeDataProcessorExternalConnection.NodeForBackgroundExchange = Undefined;
		DataExchangeDataProcessorExternalConnection.DoNotDumpObjectsByRefs = True;
		DataExchangeDataProcessorExternalConnection.ExchangeRulesFilename = "1";
		
		DataExchangeDataProcessorExternalConnection.ExternalConnection = Undefined;
		DataExchangeDataProcessorExternalConnection.DataImportExecutedInExternalConnection = False;
		
		SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessorExternalConnection, ExchangeSettingsStructureExternalConnection, SSL20Exchange);
		
		RecipientConfigurationVersion = "";
		SourceVersionFromRules = "";
		MessageText = "";
		ExternalConnectionParameters = New Structure;
		ExternalConnectionParameters.Insert("ExternalConnection", ExternalConnection);
		ExternalConnectionParameters.Insert("SSLVersionForExternalConnection", SSLVersionForExternalConnection);
		ExternalConnectionParameters.Insert("EventLogMonitorMessageKey", ExchangeSettingsStructureExternalConnection.EventLogMonitorMessageKey);
		ExternalConnectionParameters.Insert("InfobaseNode", ExchangeSettingsStructureExternalConnection.InfobaseNode);
		
		ObjectConversionRules.Get().Conversion.Property("SourceConfigurationVersion", RecipientConfigurationVersion);
		DataProcessorForDataImport.SavedSettings.Get().Conversion.Property("SourceConfigurationVersion", SourceVersionFromRules);
		
		If CorrespondentVersionsDiffer(ExchangeSettingsStructure.ExchangePlanName, ExchangeSettingsStructure.EventLogMonitorMessageKey,
			SourceVersionFromRules, RecipientConfigurationVersion, MessageText, ExternalConnectionParameters) Then
			
			DataExchangeDataProcessorExternalConnection = Undefined;
			Return;
			
		EndIf;
		
		// EXPORT (CORRESPONDENT) - UPLOAD (THIS BASE)
		DataExchangeDataProcessorExternalConnection.ExecuteDataExport(DataProcessorForDataImport);
		
		// Write the state of exchanging data.
		ExchangeSettingsStructure.ExchangeProcessResult    = DataProcessorForDataImport.ExchangeProcessResult();
		ExchangeSettingsStructure.ProcessedObjectCount = DataProcessorForDataImport.CounterOfImportedObjects();
		ExchangeSettingsStructure.ExchangeMessage           = DataProcessorForDataImport.CommentDuringDataImport;
		ExchangeSettingsStructure.ErrorMessageString      = DataProcessorForDataImport.ErrorMessageString();
		
		// Record data exchange execution state (external connection).
		ExchangeSettingsStructureExternalConnection.ExchangeExecutionResultString = DataExchangeDataProcessorExternalConnection.ExchangeExecutionResultString();
		ExchangeSettingsStructureExternalConnection.ProcessedObjectCount     = DataExchangeDataProcessorExternalConnection.DumpedObjectsCounter();
		ExchangeSettingsStructureExternalConnection.ExchangeMessage               = DataExchangeDataProcessorExternalConnection.CommentDuringDataExport;
		ExchangeSettingsStructureExternalConnection.ErrorMessageString          = DataExchangeDataProcessorExternalConnection.ErrorMessageString();
		
		DataExchangeDataProcessorExternalConnection = Undefined;
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		// Processor for the data import.
		DataProcessorForDataImport = ExternalConnection.DataProcessors.InfobaseObjectsConversion.Create();
		DataProcessorForDataImport.ExchangeMode = "Import";
		DataProcessorForDataImport.ExchangeNodeForDataImport = ExchangeSettingsStructureExternalConnection.InfobaseNode;
		DataProcessorForDataImport.ExecutingDataImportViaExternalConnection = True;
		
		SetCommonParametersForDataExchangeProcessing(DataProcessorForDataImport, ExchangeSettingsStructureExternalConnection, SSL20Exchange);
		
		DataProcessorForDataImport.ObjectsCountForTransactions = ExchangeSettingsStructure.ItemCountInTransaction;
		DataProcessorForDataImport.UseTransactions = (DataProcessorForDataImport.ObjectsCountForTransactions <> 1);
		
		// Receive initialized processor for the data export.
		DataExchangeXMLDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
		DataExchangeXMLDataProcessor.ExchangeFileName = "";
		DataExchangeXMLDataProcessor.ExternalConnection = ExternalConnection;
		DataExchangeXMLDataProcessor.DataImportExecutedInExternalConnection = True;
		
		// EXPORT (THIS BASE) - UPLOAD (CORRESPONDENT)
		DataExchangeXMLDataProcessor.ExecuteDataExport(DataProcessorForDataImport);
		
		// Write the state of exchanging data.
		ExchangeSettingsStructure.ExchangeProcessResult    = DataExchangeXMLDataProcessor.ExchangeProcessResult();
		ExchangeSettingsStructure.ProcessedObjectCount = DataExchangeXMLDataProcessor.DumpedObjectsCounter();
		ExchangeSettingsStructure.ExchangeMessage           = DataExchangeXMLDataProcessor.CommentDuringDataExport;
		ExchangeSettingsStructure.ErrorMessageString      = DataExchangeXMLDataProcessor.ErrorMessageString();
		
		// Record data exchange execution state (external connection).
		ExchangeSettingsStructureExternalConnection.ExchangeExecutionResultString = DataProcessorForDataImport.ExchangeExecutionResultString();
		ExchangeSettingsStructureExternalConnection.ProcessedObjectCount     = DataProcessorForDataImport.CounterOfImportedObjects();
		ExchangeSettingsStructureExternalConnection.ExchangeMessage               = DataProcessorForDataImport.CommentDuringDataImport;
		ExchangeSettingsStructureExternalConnection.ErrorMessageString          = DataProcessorForDataImport.ErrorMessageString();
		
		DataProcessorForDataImport = Undefined;
		
	EndIf;
	
	FixEndExchange(ExchangeSettingsStructure);
	
	ExternalConnection.DataExchangeExternalConnection.FixEndExchange(ExchangeSettingsStructureExternalConnection);
	
	If Not ExchangeProcessResultCompleted(ExchangeSettingsStructure.ExchangeProcessResult) Then
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure ExecuteDataExchangeThroughFileResource(ExchangeSettingsStructure, Val OnlyParameters = False)
	
	If ExchangeSettingsStructure.DoDataImport Then
		
		// {Handler: BeforeExchangeMessageReading} Begin
		ExchangeMessage = "";
		StandardProcessing = True;
		
		BeforeReadingMessageExchange(ExchangeSettingsStructure.InfobaseNode, ExchangeMessage, StandardProcessing);
		// {Handler: BeforeReadingExchangeMessage} End
		
		If StandardProcessing Then
			
			RunExchangeMessagesTransportBeforeProcessing(ExchangeSettingsStructure);
			
			If ExchangeSettingsStructure.ExchangeProcessResult = Undefined Then
				
				RunExchangeMessagesTransportReceiving(ExchangeSettingsStructure);
				
				If ExchangeSettingsStructure.ExchangeProcessResult = Undefined Then
					
					ExchangeMessage = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageFileName();
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		// Data is imported only if exchange message is received successfully.
		If ExchangeSettingsStructure.ExchangeProcessResult = Undefined Then
			
			ReadMessageWithChangesForNode(ExchangeSettingsStructure, ExchangeMessage,, OnlyParameters);
			
		EndIf;
		
		// {Handler: AfterExchangeMessageReading} Begin
		StandardProcessing = True;
		
		AfterReadingMessageExchange(
					ExchangeSettingsStructure.InfobaseNode,
					ExchangeMessage,
					ExchangeProcessResultCompleted(ExchangeSettingsStructure.ExchangeProcessResult),
					StandardProcessing,
					Not OnlyParameters);
		// {Handler: AfterExchangeMessageReading} End
		
		If StandardProcessing Then
			
			RunExchangeMessagesTransportAfterProcessing(ExchangeSettingsStructure);
			
		EndIf;
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		RunExchangeMessagesTransportBeforeProcessing(ExchangeSettingsStructure);
		
		// data export
		If ExchangeSettingsStructure.ExchangeProcessResult = Undefined Then
			
			WriteMessageWithNodeChanges(ExchangeSettingsStructure, ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageFileName());
			
		EndIf;
		
		// Send exchange message only if data is successfully exported.
		If ExchangeProcessResultCompleted(ExchangeSettingsStructure.ExchangeProcessResult) Then
			
			RunExchangeMessagesTransportSend(ExchangeSettingsStructure);
			
		EndIf;
		
		RunExchangeMessagesTransportAfterProcessing(ExchangeSettingsStructure);
		
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure BeforeReadingMessageExchange(Val Recipient, ExchangeMessage, StandardProcessing)
	
	If IsSubordinateDIBNode()
		AND TypeOf(MasterNode()) = TypeOf(Recipient) Then
		
		SavedExchangeMessage = GetDataExchangeMessageFromMainNode();
		
		If TypeOf(SavedExchangeMessage) = Type("BinaryData") Then
			
			StandardProcessing = False;
			
			ExchangeMessage = GetTempFileName("xml");
			
			SavedExchangeMessage.Write(ExchangeMessage);
			
			WriteEventGetData(Recipient, NStr("en='The exchange message was received from cache.';ru='Сообщение обмена получено из кэша.'"));
			
			SetPrivilegedMode(True);
			SetDataExchangeMessageImportModeBeforeStart("MessageReceivedFromCache", True);
			SetPrivilegedMode(False);
			
		ElsIf TypeOf(SavedExchangeMessage) = Type("Structure") Then
			
			StandardProcessing = False;
			
			ExchangeMessage = SavedExchangeMessage.PathToFile;
			
			WriteEventGetData(Recipient, NStr("en='The exchange message was received from cache.';ru='Сообщение обмена получено из кэша.'"));
			
			SetPrivilegedMode(True);
			SetDataExchangeMessageImportModeBeforeStart("MessageReceivedFromCache", True);
			SetPrivilegedMode(False);
			
		Else
			SetPrivilegedMode(True);
			SetDataExchangeMessageImportModeBeforeStart("MessageReceivedFromCache", False);
			SetPrivilegedMode(False);
		EndIf;
		
	EndIf;
	
EndProcedure

// For an internal use.
Procedure AfterReadingMessageExchange(Val Recipient, Val ExchangeMessage, Val MessageIsRead, StandardProcessing, Val DeleteMessage = True)
	
	If IsSubordinateDIBNode()
		AND TypeOf(MasterNode()) = TypeOf(Recipient) Then
		
		If Not MessageIsRead
		   AND DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart("MessageReceivedFromCache") Then
			// Unable to read the message received from cache. - cache clearing is required.
			ClearDataExchangeMessageFromMainNode();
			Return;
		EndIf;
		
		RefreshCachedMessage = False;
		
		If ConfigurationChanged() Then
			
			// T.k. configuration can be
			// changed again, it is required to update
			// cache if it contains an outdated message and not only during the first import of configuration changes.
			RefreshCachedMessage = True;
			
			If Not MessageIsRead Then
				
				If Constants.ImportDataExchangeMessage.Get() = False Then
					Constants.ImportDataExchangeMessage.Set(True);
				EndIf;
				
			EndIf;
			
		Else
			
			If DeleteMessage Then
				
				ClearDataExchangeMessageFromMainNode();
				
				If Constants.ImportDataExchangeMessage.Get() = True Then
					Constants.ImportDataExchangeMessage.Set(False);
				EndIf;
				
			Else
				// T.k. reading the exchange message can be without
				// the metadata import, then you need to save the exchange
				// message after reading the parameters of the application work not to reimport it for the main reading.
				RefreshCachedMessage = True;
			EndIf;
			
		EndIf;
		
		If RefreshCachedMessage Then
			
			OldMessage = GetDataExchangeMessageFromMainNode();
			
			RefreshCache = False;
			NewMessage = New BinaryData(ExchangeMessage);
			
			StructureType = TypeOf(OldMessage) = Type("Structure");
			
			If StructureType Or TypeOf(OldMessage) = Type("BinaryData") Then
				
				If StructureType Then
					OldMessage = New BinaryData(OldMessage.PathToFile);
				EndIf;
				
				If OldMessage.Size() <> NewMessage.Size() Then
					RefreshCache = True;
				ElsIf NewMessage <> OldMessage Then
					RefreshCache = True;
				EndIf;
				
			Else
				
				RefreshCache = True;
				
			EndIf;
			
			If RefreshCache Then
				SetDataExchangeMessageFromMainNode(NewMessage, Recipient);
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

// Writes changes of the infobase node to the file in the temporary directory.
//
// Parameters:
//  ExchangeSettingsStructure - Structure - structure with all necessary data and objects for exchange.
// 
Procedure WriteMessageWithNodeChanges(ExchangeSettingsStructure, Val ExchangeMessageFileName = "", ExchangeMessage = "")
	
	If ExchangeSettingsStructure.IsDIBExchange Then // Exchange in DIB
		
		Cancel = False;
		
		// Get processor of the data exchange.
		DataExchangeDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
		
		// Set attachment file name of the exchange message that is required to be read.
		DataExchangeDataProcessor.SetExchangeMessageFileName(ExchangeMessageFileName);
		
		DataExchangeDataProcessor.ExecuteDataExport(Cancel);
		
		If Cancel Then
			
			ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
			
		EndIf;
		
	Else
		
		// {Handler: OnDataExport} Begin. Override the standard processor of data export.
		StandardProcessing = True;
		ProcessedObjectCount = 0;
		
		Try
			HandlerOnDataExportSSL(StandardProcessing,
											ExchangeSettingsStructure.InfobaseNode,
											ExchangeMessageFileName,
											ExchangeMessage,
											ExchangeSettingsStructure.ItemCountInTransaction,
											ExchangeSettingsStructure.EventLogMonitorMessageKey,
											ProcessedObjectCount);
			
			If StandardProcessing = True Then
				
				ProcessedObjectCount = 0;
				
				HandlerOnDataExporting(StandardProcessing,
												ExchangeSettingsStructure.InfobaseNode,
												ExchangeMessageFileName,
												ExchangeMessage,
												ExchangeSettingsStructure.ItemCountInTransaction,
												ExchangeSettingsStructure.EventLogMonitorMessageKey,
												ProcessedObjectCount);
				
			EndIf;
			
		Except
			
			ErrorMessageString = DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(ExchangeSettingsStructure.EventLogMonitorMessageKey, EventLogLevel.Error,
					ExchangeSettingsStructure.InfobaseNode.Metadata(), 
					ExchangeSettingsStructure.InfobaseNode, ErrorMessageString);
			ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
			ExchangeSettingsStructure.ErrorMessageString = ErrorMessageString;
			Return;
		EndTry;
		
		If StandardProcessing = False Then
			ExchangeSettingsStructure.ProcessedObjectCount = ProcessedObjectCount;
			Return;
		EndIf;
		// {Handler: OnDataExport} End
		
		// Universal exchange (exchange according to conversion rules).
		If ExchangeSettingsStructure.ExchangeByObjectConversionRules Then
			
			GenerateExchangeMessage = IsBlankString(ExchangeMessageFileName);
			If GenerateExchangeMessage Then
				ExchangeMessageFileName = GetTempFileName(".xml");
			EndIf;
			
			// Receives the initialized data exchange processor.
			DataExchangeXMLDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
			DataExchangeXMLDataProcessor.ExchangeFileName = ExchangeMessageFileName;
			
			// data export
			DataExchangeXMLDataProcessor.ExecuteDataExport();
			
			If GenerateExchangeMessage Then
				TextFile = New TextDocument;
				TextFile.Read(ExchangeMessageFileName, TextEncoding.UTF8);
				ExchangeMessage = TextFile.GetText();
			EndIf;
			
			ExchangeSettingsStructure.ExchangeProcessResult = DataExchangeXMLDataProcessor.ExchangeProcessResult();
			
			// Write the state of exchanging data.
			ExchangeSettingsStructure.ProcessedObjectCount = DataExchangeXMLDataProcessor.DumpedObjectsCounter();
			ExchangeSettingsStructure.ExchangeMessage           = DataExchangeXMLDataProcessor.CommentDuringDataExport;
			ExchangeSettingsStructure.ErrorMessageString      = DataExchangeXMLDataProcessor.ErrorMessageString();
			
		Else // Standard exchange (platform serialization).
			
			Cancel = False;
			ProcessedObjectCount = 0;
			
			ExecuteStandardNodeChangeExport(Cancel,
								ExchangeSettingsStructure.InfobaseNode,
								ExchangeMessageFileName,
								ExchangeMessage,
								ExchangeSettingsStructure.ItemCountInTransaction,
								ExchangeSettingsStructure.EventLogMonitorMessageKey,
								ProcessedObjectCount);
			
			ExchangeSettingsStructure.ProcessedObjectCount = ProcessedObjectCount;
			
			If Cancel Then
				
				ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Receives an exchange message with new data and imports the data to the infobase.
//
// Parameters:
//  ExchangeSettingsStructure - Structure - structure with all necessary data and objects for exchange.
// 
Procedure ReadMessageWithChangesForNode(ExchangeSettingsStructure, Val ExchangeMessageFileName = "", ExchangeMessage = "", Val OnlyParameters = False)
	
	If ExchangeSettingsStructure.IsDIBExchange Then // Exchange in DIB
		
		Cancel = False;
		
		// Get processor of the data exchange.
		DataExchangeDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
		
		// Set attachment file name of the exchange message that is required to be read.
		DataExchangeDataProcessor.SetExchangeMessageFileName(ExchangeMessageFileName);
		
		DataExchangeDataProcessor.ExecuteDataImport(Cancel, OnlyParameters);
		
		If Cancel Then
			
			ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
			
		EndIf;
		
	Else
		
		// {Handler: OnDataImport} Begin. Override the standard processor of data import.
		StandardProcessing = True;
		ProcessedObjectCount = 0;
		
		Try
			HandlerOnDataImportSSL(StandardProcessing,
											ExchangeSettingsStructure.InfobaseNode,
											ExchangeMessageFileName,
											ExchangeMessage,
											ExchangeSettingsStructure.ItemCountInTransaction,
											ExchangeSettingsStructure.EventLogMonitorMessageKey,
											ProcessedObjectCount);
			
			If StandardProcessing = True Then
				
				ProcessedObjectCount = 0;
				
				HandlerOnDataImport(StandardProcessing,
												ExchangeSettingsStructure.InfobaseNode,
												ExchangeMessageFileName,
												ExchangeMessage,
												ExchangeSettingsStructure.ItemCountInTransaction,
												ExchangeSettingsStructure.EventLogMonitorMessageKey,
												ProcessedObjectCount);
				
			EndIf;
			
		Except
			ErrorMessageString = DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(ExchangeSettingsStructure.EventLogMonitorMessageKey, EventLogLevel.Error,
					ExchangeSettingsStructure.InfobaseNode.Metadata(), 
					ExchangeSettingsStructure.InfobaseNode, ErrorMessageString);
			ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
			ExchangeSettingsStructure.ErrorMessageString = ErrorMessageString;
			Return;
		EndTry;
		
		If StandardProcessing = False Then
			ExchangeSettingsStructure.ProcessedObjectCount = ProcessedObjectCount;
			Return;
		EndIf;
		// {Handler: OnDataImport} End
		
		// Universal exchange (exchange according to conversion rules).
		If ExchangeSettingsStructure.ExchangeByObjectConversionRules Then
			
			// Receives the initialized data exchange processor.
			DataExchangeXMLDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
			DataExchangeXMLDataProcessor.ExchangeFileName = ExchangeMessageFileName;
			
			// data import
			DataExchangeXMLDataProcessor.ExecuteDataImport();
			
			ExchangeSettingsStructure.ExchangeProcessResult = DataExchangeXMLDataProcessor.ExchangeProcessResult();
			
			// Write the state of exchanging data.
			ExchangeSettingsStructure.ProcessedObjectCount = DataExchangeXMLDataProcessor.CounterOfImportedObjects();
			ExchangeSettingsStructure.ExchangeMessage           = DataExchangeXMLDataProcessor.CommentDuringDataImport;
			ExchangeSettingsStructure.ErrorMessageString      = DataExchangeXMLDataProcessor.ErrorMessageString();
			
		Else // Standard exchange (platform serialization).
			
			ProcessedObjectCount = 0;
			ExchangeProcessResult = Undefined;
			
			ExecuteStandardNodeChangeImport(
								ExchangeSettingsStructure.InfobaseNode,
								ExchangeMessageFileName,
								ExchangeMessage,
								ExchangeSettingsStructure.ItemCountInTransaction,
								ExchangeSettingsStructure.EventLogMonitorMessageKey,
								ProcessedObjectCount,
								ExchangeProcessResult);
			//
			
			ExchangeSettingsStructure.ProcessedObjectCount = ProcessedObjectCount;
			ExchangeSettingsStructure.ExchangeProcessResult = ExchangeProcessResult;
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Exchange serialization methods.

// Procedure of writing changes for exchange message.
// Applicable for cases when the metadata structure of exchanged bases is the same for all objects involved in the exchange.
//
Procedure ExecuteStandardNodeChangeExport(Cancel,
							InfobaseNode,
							FileName,
							ExchangeMessage,
							ItemCountInTransaction = 0,
							EventLogMonitorMessageKey = "",
							ProcessedObjectCount = 0)
	
	If IsBlankString(EventLogMonitorMessageKey) Then
		EventLogMonitorMessageKey = EventLogMonitorMessageTextDataExchange();
	EndIf;
	
	InitialDataExport = InitialDataExportFlagIsSet(InfobaseNode);
	
	WritingToFile = Not IsBlankString(FileName);
	
	XMLWriter = New XMLWriter;
	
	If WritingToFile Then
		
		XMLWriter.OpenFile(FileName);
	Else
		
		XMLWriter.SetString();
	EndIf;
	
	XMLWriter.WriteXMLDeclaration();
	
	// Create a new message
	WriteMessage = ExchangePlans.CreateMessageWriter();
	
	WriteMessage.BeginWrite(XMLWriter, InfobaseNode);
	
	// Count the number of written objects.
	WrittenObjectCount = 0;
	ProcessedObjectCount = 0;
	
	UseTransactions = ItemCountInTransaction <> 1;
	
	DataExchangeServerCall.CheckObjectRegistrationMechanismCache();
	
	// Get the changed data selection.
	ChangeSelection = SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo);
	
	If UseTransactions Then
		BeginTransaction();
	EndIf;
	
	Try
		
		ObjectRecipient = WriteMessage.Recipient.GetObject();
		
		While ChangeSelection.Next() Do
			
			Data = ChangeSelection.Get();
			
			ProcessedObjectCount = ProcessedObjectCount + 1;
			
			// Check if the objects passes PRO filter
			// if the object does not pass PRO filter, then send object removal
			// to the base-receiver filter each record for
			// the records set always export sets even the empty ones (analog of the object removal).
			ItemSend = DataItemSend.Auto;
			
			StandardSubsystemsServer.OnSendDataToSubordinate(Data, ItemSend, InitialDataExport, ObjectRecipient);
			
			If ItemSend = DataItemSend.Delete Then
				
				If CommonUse.ThisIsRegister(Data.Metadata()) Then
					
					// Send register removal as an empty records set.
					
				Else
					
					Data = New ObjectDeletion(Data.Ref);
					
				EndIf;
				
			ElsIf ItemSend = DataItemSend.Ignore Then
				
				Continue;
				
			EndIf;
			
			// Write data to the message.
			WriteXML(XMLWriter, Data);
			
			WrittenObjectCount = WrittenObjectCount + 1;
			
			If UseTransactions
				AND ItemCountInTransaction > 0
				AND WrittenObjectCount = ItemCountInTransaction Then
				
				// Close the staging transaction and open a new one.
				CommitTransaction();
				BeginTransaction();
				
				WrittenObjectCount = 0;
			EndIf;
			
		EndDo;
		
		If UseTransactions Then
			
			CommitTransaction();
			
		EndIf;
		
		// Finish writing the message
		WriteMessage.EndWrite();
		
		ExchangeMessage = XMLWriter.Close();
		
	Except
		
		If UseTransactions Then
			
			RollbackTransaction();
			
		EndIf;
		
		WriteMessage.CancelWrite();
		
		XMLWriter.Close();
		
		Cancel = True;
		
		WriteLogEvent(EventLogMonitorMessageKey, EventLogLevel.Error,
			InfobaseNode.Metadata(), InfobaseNode, DetailErrorDescription(ErrorInfo()));
		//
		Return;
	EndTry;
	
EndProcedure

// Procedure of reading changes from the exchange message.
// Applicable for cases when the metadata structure of exchanged bases is the same for all objects involved in the exchange.
//
Procedure ExecuteStandardNodeChangeImport(
							InfobaseNode,
							FileName = "",
							ExchangeMessage = "",
							ItemCountInTransaction = 0,
							EventLogMonitorMessageKey = "",
							ProcessedObjectCount = 0,
							ExchangeProcessResult = Undefined)
	//
	
	If IsBlankString(EventLogMonitorMessageKey) Then
		EventLogMonitorMessageKey = EventLogMonitorMessageTextDataExchange();
	EndIf;
	
	ExchangePlanManager = DataExchangeReUse.GetExchangePlanManager(InfobaseNode);
	
	Try
		XMLReader = New XMLReader;
		
		If Not IsBlankString(ExchangeMessage) Then
			XMLReader.SetString(ExchangeMessage);
		Else
			XMLReader.OpenFile(FileName);
		EndIf;
		
		MessageReader = ExchangePlans.CreateMessageReader();
		MessageReader.BeginRead(XMLReader, AllowedMessageNo.Greater);
	Except
		
		ErrorInfo = ErrorInfo();
		
		If IsErrorMessageNumberLessOrEqualToPreviouslyAcceptedMessageNumber(BriefErrorDescription(ErrorInfo)) Then
			
			ExchangeProcessResult = Enums.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived;
			
			WriteLogEvent(EventLogMonitorMessageKey, EventLogLevel.Warning,
				InfobaseNode.Metadata(), InfobaseNode, BriefErrorDescription(ErrorInfo));
			//
		Else
			
			ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
			
			WriteLogEvent(EventLogMonitorMessageKey, EventLogLevel.Error,
				InfobaseNode.Metadata(), InfobaseNode, DetailErrorDescription(ErrorInfo));
			//
		EndIf;
		
		Return;
	EndTry;
	
	If MessageReader.Sender <> InfobaseNode Then // Message is intended not for this node.
		
		ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
		
		WriteLogEvent(EventLogMonitorMessageKey, EventLogLevel.Error,
			InfobaseNode.Metadata(), InfobaseNode, NStr("en='The exchange message contains data for another infobase node.';ru='Сообщение обмена содержит данные для другого узла информационной базы.'",
			CommonUseClientServer.MainLanguageCode()));
		//
		Return;
	EndIf;
	
	BackupCopiesParameters = BackupCopiesParameters(MessageReader.Sender, MessageReader.ReceivedNo);
	
	DeleteChangeRecords = Not BackupCopiesParameters.BackupRestored;
	
	If DeleteChangeRecords Then
		
		// Delete changes registration for the message sender node.
		ExchangePlans.DeleteChangeRecords(MessageReader.Sender, MessageReader.ReceivedNo);
		
		InformationRegisters.InfobasesNodesCommonSettings.ClearInitialDataExportFlag(MessageReader.Sender, MessageReader.ReceivedNo);
		
	EndIf;
	
	// Count how many objects you have read.
	WrittenObjectCount = 0;
	ProcessedObjectCount = 0;
	
	UseTransactions = ItemCountInTransaction <> 1;
	
	If UseTransactions Then
		
		// start transaction
		BeginTransaction();
		
	EndIf;
	
	Try
		
		// Read data from the message
		While CanReadXML(XMLReader) Do
			
			// Read the next value
			Data = ReadXML(XMLReader);
			
			ItemReceive = DataItemReceive.Auto;
			SendBack = False;
			
			StandardSubsystemsServer.OnReceiveDataFromMaster(Data, ItemReceive, SendBack, MessageReader.Sender);
			
			If ItemReceive = DataItemReceive.Ignore Then
				Continue;
			EndIf;
				
			ThisIsObjectDeletion = (TypeOf(Data) = Type("ObjectDeletion"));
			
			ProcessedObjectCount = ProcessedObjectCount + 1;
			
			If Not SendBack Then
				Data.DataExchange.Sender = MessageReader.Sender;
			EndIf;
			
			Data.DataExchange.Load = True;
			
			// Redefine the default behavior of the system on receiving the object removal.
			// Set the deletion mark instead of the actual object removal without the reference integrity control.
			If ThisIsObjectDeletion Then
				
				ObjectDeletion = Data;
				
				Data = Data.Ref.GetObject();
				
				If Data = Undefined Then
					
					Continue;
					
				EndIf;
				
				If Not SendBack Then
					Data.DataExchange.Sender = MessageReader.Sender;
				EndIf;
				
				Data.DataExchange.Load = True;
				
				Data.DeletionMark = True;
				
				If CommonUse.ThisIsDocument(Data.Metadata()) Then
					
					Data.Posted = False;
					
				EndIf;
				
			EndIf;
			
			If ThisIsObjectDeletion Then
				
				Data = ObjectDeletion;
				
			EndIf;
			
			// Try to write the object.
			Try
				Data.Write();
			Except
				
				ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
				
				ErrorDescription = DetailErrorDescription(ErrorInfo());
				
				WriteLogEvent(EventLogMonitorMessageKey, EventLogLevel.Error,
					Data.Metadata(), String(Data), ErrorDescription);
				//
				Break;
			EndTry;
			
			WrittenObjectCount = WrittenObjectCount + 1;
			
			If UseTransactions
				AND ItemCountInTransaction > 0
				AND WrittenObjectCount = ItemCountInTransaction Then
				
				// Close the staging transaction and open a new one.
				CommitTransaction();
				BeginTransaction();
				
				WrittenObjectCount = 0;
			EndIf;
			
		EndDo;
		
	Except
		
		ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
		
		WriteLogEvent(EventLogMonitorMessageKey, EventLogLevel.Error,
			InfobaseNode.Metadata(), InfobaseNode, DetailErrorDescription(ErrorInfo()));
		//
	EndTry;
	
	If ExchangeProcessResult = Enums.ExchangeExecutionResult.Error Then
		
		MessageReader.CancelRead();
		
		If UseTransactions Then
			RollbackTransaction();
		EndIf;
	Else
		
		MessageReader.EndRead();
		
		WhenRestoringBackupCopies(BackupCopiesParameters);
		
		If UseTransactions Then
			CommitTransaction();
		EndIf;
		
	EndIf;
	
	XMLReader.Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Export service functions-properties.

// Returns name of the temporary directory for the data exchange messages.
// Directory name corresponds the pattern:
// Exchange82 {GUID}, where GUID - String of the unique identifier.
// 
// Parameters:
//  No.
// 
// Returns:
//  String - name of the temporary directory for data exchange messages.
//
Function TemporaryExchangeMessagesDirectoryName() Export
	
	Return StrReplace("Exchange82 {GUID}", "GUID", Upper(String(New UUID)));
	
EndFunction

// Returns the name of the exchange messages transport processor.
// 
// Parameters:
//  TransportKind - EnumRef.ExchangeMessagesTransportKinds - transport kind for which it
//                                                                     is required to receive processor name.
// 
//  Returns:
//  String - name of the exchange messages transport processor.
//
Function DataProcessorNameOfExchangeMessagesTransport(TransportKind) Export
	
	Return StrReplace("ExchangeMessagesTransport[TransportKind]", "[TransportKind]", CommonUse.NameOfEnumValue(TransportKind));
	
EndFunction

// Double of the procedure on server DataExchangeClient.ObjectsMatchFieldsMaximumCount().
//
Function MaximumQuantityOfFieldsOfObjectMapping() Export
	
	Return 5;
	
EndFunction

// Defines if the exchange plan is included to the list of exchange plans that use data exchange according to XDTO format.
//
// Parameters:
//  ExchangePlan - Ref to exchange plan node or exchange plan name.
//
// Return value: Boolean.
//
Function ThisIsExchangePlanXDTO(ExchangePlan) Export
	If TypeOf(ExchangePlan) = Type("String") Then
		ExchangePlanName = ExchangePlan;
	Else
		ExchangePlanName = ExchangePlan.Metadata().Name;
	EndIf;
	Return ExchangePlanSettingValue(ExchangePlanName, "ThisIsExchangePlanXDTO");
EndFunction

////////////////////////////////////////////////////////////////////////////////
// The exchange messages transport

// For an internal use.
// 
Procedure RunExchangeMessagesTransportBeforeProcessing(ExchangeSettingsStructure)
	
	// Receive initialized messages transport processor.
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Receive a new name of the temporary file.
	If Not ExchangeMessageTransportDataProcessor.ExecuteActionsBeforeMessageProcessing() Then
		
		WriteLogEventOfDataExchange(ExchangeMessageTransportDataProcessor.ErrorMessageStringEL, ExchangeSettingsStructure, True);
		
		ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error_MessageTransport;
		
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure RunExchangeMessagesTransportSend(ExchangeSettingsStructure)
	
	// Receive initialized messages transport processor.
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Send exchange message from the temporary directory.
	If Not ExchangeMessageTransportDataProcessor.SendMessage() Then
		
		WriteLogEventOfDataExchange(ExchangeMessageTransportDataProcessor.ErrorMessageStringEL, ExchangeSettingsStructure, True);
		
		ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error_MessageTransport;
		
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure RunExchangeMessagesTransportReceiving(ExchangeSettingsStructure)
	
	// Receive initialized messages transport processor.
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Receive exchange message in the temporary directory.
	If Not ExchangeMessageTransportDataProcessor.GetMessage() Then
		
		WriteLogEventOfDataExchange(ExchangeMessageTransportDataProcessor.ErrorMessageStringEL, ExchangeSettingsStructure, True);
		
		ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error_MessageTransport;
		
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure RunExchangeMessagesTransportAfterProcessing(ExchangeSettingsStructure)
	
	// Receive initialized messages transport processor.
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Execute actions after sending messages.
	ExchangeMessageTransportDataProcessor.ExecuteActionsAfterMessageProcessing();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// File transfer service

// Function by the passed identifier exports file from the service of files transfer.
//
// Parameters:
//  FileID       - UUID - identifier of the received file.
//  AccessParametersToService - Structure: ServiceAddress, UserName, UserPassword. 
//  PartSize              - Number - size of the part in kilobytes. If value is
//                             0, then it is not broken into parts.
// Returns:
//  String - path to the received file.
//
Function GetFileFromStorageInService(Val FileID, Val InfobaseNode, Val PartSize = 1024, Val AuthenticationParameters = Undefined) Export
	
	// Return value of the function.
	ResultFileName = "";
	
	Proxy = GetWSProxyForInfobaseNode(InfobaseNode,, AuthenticationParameters);
	
	ExchangeInsideNetwork = DataExchangeReUse.IsExchangeInSameLAN(InfobaseNode, AuthenticationParameters);
	
	If ExchangeInsideNetwork Then
		
		FileNameFromStorage = Proxy.GetFileFromStorage(FileID);
		
		ResultFileName = CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), FileNameFromStorage);
		
	Else
		
		SessionID = Undefined;
		PartCount = Undefined;
		
		Proxy.PrepareGetFile(FileID, PartSize, SessionID, PartCount);
		
		FileNames = New Array;
		
		AssemblyDirectory = GetTempFileName();
		CreateDirectory(AssemblyDirectory);
		
		FileNamePattern = "data.zip.[n]";
		
		// Logging of the exchange events.
		ExchangeSettingsStructure = New Structure("EventLogMonitorMessageKey");
		ExchangeSettingsStructure.EventLogMonitorMessageKey = GetEventLogMonitorMessageKey(InfobaseNode, Enums.ActionsAtExchange.DataImport);
		
		Comment = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Start of the Internet exchange message receiving (number of file parts is %1).';ru='Начало получения сообщения обмена из Интернета (количество частей файла %1).'"),
			Format(PartCount, "NZ=0; NG=0")
		);
		WriteLogEventOfDataExchange(Comment, ExchangeSettingsStructure);
		//
		
		For PartNumber = 1 To PartCount Do
			
			PartData = Undefined;
			Proxy.GetFilePart(SessionID, PartNumber, PartData);
			
			FileName = StrReplace(FileNamePattern, "[n]", Format(PartNumber, "NG=0"));
			FileNamePart = CommonUseClientServer.GetFullFileName(AssemblyDirectory, FileName);
			
			PartData.Write(FileNamePart);
			FileNames.Add(FileNamePart);
		EndDo;
		PartData = Undefined;
		
		Proxy.ReleaseFile(SessionID);
		
		ArchiveName = CommonUseClientServer.GetFullFileName(AssemblyDirectory, "data.zip");
		
		MergeFiles(FileNames, ArchiveName);
		
		Dearchiver = New ZipFileReader(ArchiveName);
		If Dearchiver.Items.Count() = 0 Then
			Try
				DeleteFiles(AssemblyDirectory);
			Except
				WriteLogEvent(EventLogMonitorMessageTextRemovingTemporaryFile(),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			EndTry;
			Raise(NStr("en='Archive file contains no data.';ru='Файл архива не содержит данных.'"));
		EndIf;
		
		// Logging of the exchange events.
		FileOfArchive = New File(ArchiveName);
		
		Comment = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='End of exchange message receiving from the Internet (size of a compressed exchange message is %1 MB).';ru='Окончание получения сообщения обмена из Интернета (размер сжатого сообщения обмена %1 Мб).'"),
			Format(Round(FileOfArchive.Size() / 1024 / 1024, 3), "NZ=0; NG=0")
		);
		WriteLogEventOfDataExchange(Comment, ExchangeSettingsStructure);
		//
		
		FileName = CommonUseClientServer.GetFullFileName(AssemblyDirectory, Dearchiver.Items[0].Name);
		
		Dearchiver.Extract(Dearchiver.Items[0], AssemblyDirectory);
		Dearchiver.Close();
		
		File = New File(FileName);
		
		ResultFileName = CommonUseClientServer.GetFullFileName(TempFilesDir(), File.Name);
		MoveFile(FileName, ResultFileName);
		
		Try
			DeleteFiles(AssemblyDirectory);
		Except
			WriteLogEvent(EventLogMonitorMessageTextRemovingTemporaryFile(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndIf;
	
	Return ResultFileName;
EndFunction

// Function passes the specified file to the files passing service.
//
// Parameters:
//  FileName                 - String - path to the sent file.
//  AccessParametersToService - Structure: ServiceAddress, UserName, UserPassword. 
//  PartSize              - Number - size of the part in kilobytes. If value is
//                             0, then it is not broken into parts.
// Returns:
//  UUID  - file identifier in the file pass service.
//
Function PutFileToStorageInService(Val FileName, Val InfobaseNode, Val PartSize = 1024, Val AuthenticationParameters = Undefined) Export
	
	// Return value of the function.
	FileID = Undefined;
	
	Proxy = GetWSProxyForInfobaseNode(InfobaseNode,, AuthenticationParameters);
	
	ExchangeInsideNetwork = DataExchangeReUse.IsExchangeInSameLAN(InfobaseNode, AuthenticationParameters);
	
	If ExchangeInsideNetwork Then
		
		FileNameInStorage = CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), UniqueExchangeMessageFileName());
		
		MoveFile(FileName, FileNameInStorage);
		
		Proxy.PutFileIntoStorage(FileNameInStorage, FileID);
		
	Else
		
		FileDirectory = GetTempFileName();
		CreateDirectory(FileDirectory);
		
		// Archiving of file
		SharedFileName = CommonUseClientServer.GetFullFileName(FileDirectory, "data.zip");
		Archiver = New ZipFileWriter(SharedFileName,,,, ZIPCompressionLevel.Maximum);
		Archiver.Add(FileName);
		Archiver.Write();
		
		// Divide file into parts
		SessionID = New UUID;
		
		PartCount = 1;
		If ValueIsFilled(PartSize) Then
			FileNames = SplitFile(SharedFileName, PartSize * 1024);
			PartCount = FileNames.Count();
			For PartNumber = 1 To PartCount Do
				FileNamePart = FileNames[PartNumber - 1];
				FileData = New BinaryData(FileNamePart);
				Proxy.PutFilePart(SessionID, PartNumber, FileData);
			EndDo;
		Else
			FileData = New BinaryData(SharedFileName);
			Proxy.PutFilePart(SessionID, 1, FileData);
		EndIf;
		
		Try
			DeleteFiles(FileDirectory);
		Except
			WriteLogEvent(EventLogMonitorMessageTextRemovingTemporaryFile(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		Proxy.SaveFileFromParts(SessionID, PartCount, FileID);
		
	EndIf;
	
	Return FileID;
EndFunction

// Receive file on its ID.
//
// Parameters:
// FileID - UUID - identifier of the received file.
//
// Returns:
//  FileName - String - attachment file name.
//
Function GetFileFromStorage(Val FileID) Export
	
	FileName = "";
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		
		ModuleDataExchangeSaaS = CommonUse.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnReceiveFileFromStore(FileID, FileName);
		
	Else
		
		OnReceiveFileFromStore(FileID, FileName);
		
	EndIf;
	
	Return CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), FileName);
EndFunction

// Save file.
//
// Parameters:
//  FileName               - String - attachment file name.
//  FileID     - UUID - file identifier. If it is specified, then
//                           this value will be used while saving the file, otherwise, - a new one will be generated.
//
// Returns:
//  UUID - file identifier.
//
Function PutFileToStorage(Val FileName, Val FileID = Undefined) Export
	
	FileID = ?(FileID = Undefined, New UUID, FileID);
	
	File = New File(FileName);
	
	RecordStructure = New Structure;
	RecordStructure.Insert("MessageID", String(FileID));
	RecordStructure.Insert("MessageFileName", File.Name);
	RecordStructure.Insert("MessageSendingDate", CurrentUniversalDate());
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		
		ModuleDataExchangeSaaS = CommonUse.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnPlaceFileStorage(RecordStructure);
	Else
		
		OnPlaceFileStorage(RecordStructure);
		
	EndIf;
	
	Return FileID;
EndFunction

// Defines if it is possible to pass files from one base to another via the local area network.
//
// Parameters:
//  InfobaseNode  - ExchangePlanRef - node of the exchange plan for which the exchange message is received.
//  AuthenticationParameters - Structure. Contains the authentication Parameters to a Web service user Password).
//
Function IsExchangeInSameLAN(Val InfobaseNode, Val AuthenticationParameters = Undefined) Export
	
	Proxy = GetWSProxyForInfobaseNode(InfobaseNode,, AuthenticationParameters);
	
	TempFileName = StrReplace("test{GUID}.tmp", "GUID", String(New UUID));
	
	TempFileFullName = CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), TempFileName);
	TextWriter = New TextWriter(TempFileFullName);
	TextWriter.Close();
	
	Try
		Result = Proxy.FileExists(TempFileName);
	Except
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		Try
			DeleteFiles(TempFileFullName);
		Except
			WriteLogEvent(EventLogMonitorMessageTextRemovingTemporaryFile(),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		Raise DetailErrorDescription;
	EndTry;
	
	Try
		DeleteFiles(TempFileFullName);
	Except
		WriteLogEvent(EventLogMonitorMessageTextRemovingTemporaryFile(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return Result;
EndFunction

// Receive the attachment file name by its ID from the storage.
// If there is no file with the specified ID, the exception is called.
// If the file is found, then its name is returned and information about this file is deleted from the storage.
//
// Parameters:
// FileID - UUID - identifier of the received file.
// FileName           - String - name of the file, from the storage.
//
Procedure OnReceiveFileFromStore(Val FileID, FileName)
	
	QueryText =
	"SELECT
	|	DataExchangeMessages.MessageFileName AS FileName
	|FROM
	|	InformationRegister.DataExchangeMessages AS DataExchangeMessages
	|WHERE
	|	DataExchangeMessages.MessageID = &MessageID";
	
	Query = New Query;
	Query.SetParameter("MessageID", String(FileID));
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Definition = NStr("en='A file with ID %1 not found.';ru='Файл с идентификатором %1 не обнаружен.'");
		Raise StringFunctionsClientServer.SubstituteParametersInString(Definition, String(FileID));
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	FileName = Selection.FileName;
	
	// Delete information about the exchange message file from the storage.
	RecordStructure = New Structure;
	RecordStructure.Insert("MessageID", String(FileID));
	InformationRegisters.DataExchangeMessages.DeleteRecord(RecordStructure);
	
EndProcedure

// Place file to the storage.
//
Procedure OnPlaceFileStorage(Val RecordStructure)
	
	InformationRegisters.DataExchangeMessages.AddRecord(RecordStructure);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Registration of changes for initial data export.

// Registers the changes for the initial data export considering the date of the export start and the list of companies.
// The procedure is universal and can be used for registration of data changes by
// the date of the export start and by the companies list for object data types and sets of register records.
// If companies list is not specified (Company = Undefined), then the changes are registered
// only by the date of the export start.
// Data for all metadata objects included in the content of exchange plan should be registered.
// If the auto-registration flag is set as part of
// the exchange plan for the metadata object or the auto-registration flag
// is not set and the registration rules are not specified, then the changes registration will be unconditionally executed for all data of this type.
// If the registration rules are set for the metadata object, then the registration of changes will be executed taking into account export start date and list of companies.
// The registration of changes by the date of export start and list of companies is supported for documents.
// For business processes and jobs the registration of changes is supported by export start date.
// Registration of changes by the date of export start and list of companies is supported for sets of the register records.
// This procedure can be a prototype for developing their own
// procedures of changes registration for the initial data export.
//
// Parameters:
//
//  Recipient - ExchangePlanRef - Exchange
//               plan node for which it is required to register data changes.
//  ExportStartDate - Date - date relative to which
//               it is required to register changes of data for export. Changes will be
//               registered for data that is placed after this date on the time axis.
//  Companies - Array, Undefined - List of companies of which it
//               is required to register the data change. If the parameter is not specified, then
//               companies will be ignored during the changes registration.
//
Procedure RegisterDataByExportStartDateAndCounterparty(Val Recipient, ExportStartDate,
	Companies = Undefined,
	Data = Undefined) Export
	
	FilterByCompanies = (Companies <> Undefined);
	FilterByExportStartDate = ValueIsFilled(ExportStartDate);
	
	If Not FilterByCompanies AND Not FilterByExportStartDate Then
		
		If TypeOf(Data) = Type("Array") Then
			
			For Each MetadataObject IN Data Do
				
				ExchangePlans.RecordChanges(Recipient, MetadataObject);
				
			EndDo;
			
		Else
			
			ExchangePlans.RecordChanges(Recipient, Data);
			
		EndIf;
		
		Return;
	EndIf;
	
	FilterByExportStartDateAndCompanies = FilterByExportStartDate AND FilterByCompanies;
	
	ExchangePlanName = DataExchangeReUse.GetExchangePlanName(Recipient);
	
	ExchangePlanContent = Metadata.ExchangePlans[ExchangePlanName].Content;
	
	UseFilterByMetadata = (TypeOf(Data) = Type("Array"));
	
	For Each ExchangePlanContentItem IN ExchangePlanContent Do
		
		If UseFilterByMetadata
			AND Data.Find(ExchangePlanContentItem.Metadata) = Undefined Then
			
			Continue;
			
		EndIf;
		
		FullObjectName = ExchangePlanContentItem.Metadata.FullName();
		
		If ExchangePlanContentItem.AutoRecord = AutoChangeRecord.Deny
			AND DataExchangeReUse.ObjectChangeRecordRulesExist(ExchangePlanName, FullObjectName) Then
			
			If CommonUse.ThisIsDocument(ExchangePlanContentItem.Metadata) Then // Documents
				
				If FilterByExportStartDateAndCompanies
					// Registration by date and companies.
					AND ExchangePlanContentItem.Metadata.Attributes.Find("Company") <> Undefined Then
					
					Selection = DocumentSelectionByExportStartDateAndCounterparty(FullObjectName, ExportStartDate, Companies);
					
					While Selection.Next() Do
						
						ExchangePlans.RecordChanges(Recipient, Selection.Ref);
						
					EndDo;
					
					Continue;
					
				Else // Registration by date
					
					Selection = ObjectSelectionByExportStartDate(FullObjectName, ExportStartDate);
					
					While Selection.Next() Do
						
						ExchangePlans.RecordChanges(Recipient, Selection.Ref);
						
					EndDo;
					
					Continue;
					
				EndIf;
				
			ElsIf CommonUse.ThisIsBusinessProcess(ExchangePlanContentItem.Metadata)
				OR CommonUse.ThisIsTask(ExchangePlanContentItem.Metadata) Then // Business processes and Jobs
				
				// Registration by date
				Selection = ObjectSelectionByExportStartDate(FullObjectName, ExportStartDate);
				
				While Selection.Next() Do
					
					ExchangePlans.RecordChanges(Recipient, Selection.Ref);
					
				EndDo;
				
				Continue;
				
			ElsIf CommonUse.ThisIsRegister(ExchangePlanContentItem.Metadata) Then // Registers
				
				// Information registers (independent).
				If CommonUse.ThisIsInformationRegister(ExchangePlanContentItem.Metadata)
					AND ExchangePlanContentItem.Metadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
					
					MainFilter = MainInformationRegisterFilter(ExchangePlanContentItem.Metadata);
					
					FilterByPeriod     = (MainFilter.Find("Period") <> Undefined);
					FilterByCounterparty = (MainFilter.Find("Company") <> Undefined);
					
					// Registration by date and companies.
					If FilterByExportStartDateAndCompanies AND FilterByPeriod AND FilterByCounterparty Then
						
						Selection = MainInformationRegisterFilterValueSelectionByExportStartDateAndCompanies(MainFilter, FullObjectName, ExportStartDate, Companies);
						
					ElsIf FilterByExportStartDate AND FilterByPeriod Then // Registration by date
						
						Selection = MainInformationRegisterFilterValueSelectionByExportStartDate(MainFilter, FullObjectName, ExportStartDate);
						
					ElsIf FilterByCompanies AND FilterByCounterparty Then // Registration by companies.
						
						Selection = MainInformationRegisterFilterByCompaniesValueSelection(MainFilter, FullObjectName, Companies);
						
					Else
						
						Selection = Undefined;
						
					EndIf;
					
					If Selection <> Undefined Then
						
						RecordSet = CommonUse.ObjectManagerByFullName(FullObjectName).CreateRecordSet();
						
						While Selection.Next() Do
							
							For Each DimensionName IN MainFilter Do
								
								RecordSet.Filter[DimensionName].Value = Selection[DimensionName];
								RecordSet.Filter[DimensionName].Use = True;
								
							EndDo;
							
							ExchangePlans.RecordChanges(Recipient, RecordSet);
							
						EndDo;
						
						Continue;
						
					EndIf;
					
				Else // Registers (other)
					
					If FilterByExportStartDateAndCompanies
						AND ExchangePlanContentItem.Metadata.Dimensions.Find("Period") <> Undefined
						// Registration by date and companies.
						AND ExchangePlanContentItem.Metadata.Dimensions.Find("Company") <> Undefined Then
						
						Selection = RecordSetRecorderSelectionByExportStartDateAndCounterparty(FullObjectName, ExportStartDate, Companies);
						
						RecordSet = CommonUse.ObjectManagerByFullName(FullObjectName).CreateRecordSet();
						
						While Selection.Next() Do
							
							RecordSet.Filter.Recorder.Value = Selection.Recorder;
							RecordSet.Filter.Recorder.Use = True;
							
							ExchangePlans.RecordChanges(Recipient, RecordSet);
							
						EndDo;
						
						Continue;
						
					// Registration by date
					ElsIf ExchangePlanContentItem.Metadata.Dimensions.Find("Period") <> Undefined Then
						
						Selection = RecordSetRecorderSelectionByExportStartDate(FullObjectName, ExportStartDate);
						
						RecordSet = CommonUse.ObjectManagerByFullName(FullObjectName).CreateRecordSet();
						
						While Selection.Next() Do
							
							RecordSet.Filter.Recorder.Value = Selection.Recorder;
							RecordSet.Filter.Recorder.Use = True;
							
							ExchangePlans.RecordChanges(Recipient, RecordSet);
							
						EndDo;
						
						Continue;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		ExchangePlans.RecordChanges(Recipient, ExchangePlanContentItem.Metadata);
		
	EndDo;
	
EndProcedure

// For an internal use.
// 
Function DocumentSelectionByExportStartDateAndCounterparty(FullObjectName, ExportStartDate, Companies)
	
	QueryText =
	"SELECT
	|	Table.Ref AS Ref
	|FROM
	|	[FullObjectName] AS Table
	|WHERE
	|	Table.Company IN(&Companies)
	|	AND Table.Date >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.SetParameter("Companies", Companies);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

// For an internal use.
// 
Function ObjectSelectionByExportStartDate(FullObjectName, ExportStartDate)
	
	QueryText =
	"SELECT
	|	Table.Ref AS Ref
	|FROM
	|	[FullObjectName] AS Table
	|WHERE
	|	Table.Date >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

// For an internal use.
// 
Function RecordSetRecorderSelectionByExportStartDateAndCounterparty(FullObjectName, ExportStartDate, Companies)
	
	QueryText =
	"SELECT DISTINCT
	|	RegisterTable.Recorder AS Recorder
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Company IN(&Companies)
	|	AND RegisterTable.Period >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.SetParameter("Companies", Companies);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

// For an internal use.
// 
Function RecordSetRecorderSelectionByExportStartDate(FullObjectName, ExportStartDate)
	
	QueryText =
	"SELECT DISTINCT
	|	RegisterTable.Recorder AS Recorder
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Period >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

// For an internal use.
// 
Function MainInformationRegisterFilterValueSelectionByExportStartDateAndCompanies(MainFilter,
	FullObjectName,
	ExportStartDate,
	Companies)
	
	QueryText =
	"SELECT DISTINCT
	|	[Dimensions]
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Company IN(&Companies)
	|	AND RegisterTable.Period >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	QueryText = StrReplace(QueryText, "[Dimensions]", StringFunctionsClientServer.RowFromArraySubrows(MainFilter));
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.SetParameter("Companies", Companies);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

// For an internal use.
// 
Function MainInformationRegisterFilterValueSelectionByExportStartDate(MainFilter, FullObjectName, ExportStartDate)
	
	QueryText =
	"SELECT DISTINCT
	|	[Dimensions]
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Period >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	QueryText = StrReplace(QueryText, "[Dimensions]", StringFunctionsClientServer.RowFromArraySubrows(MainFilter));
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

// For an internal use.
// 
Function MainInformationRegisterFilterByCompaniesValueSelection(MainFilter, FullObjectName, Companies)
	
	QueryText =
	"SELECT DISTINCT
	|	[Dimensions]
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Company IN(&Companies)";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	QueryText = StrReplace(QueryText, "[Dimensions]", StringFunctionsClientServer.RowFromArraySubrows(MainFilter));
	
	Query = New Query;
	Query.SetParameter("Companies", Companies);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

// For an internal use.
// 
Function MainInformationRegisterFilter(MetadataObject)
	
	Result = New Array;
	
	If MetadataObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical
		AND MetadataObject.MainFilterOnPeriod Then
		
		Result.Add("Period");
		
	EndIf;
	
	For Each Dimension IN MetadataObject.Dimensions Do
		
		If Dimension.MainFilter Then
			
			Result.Add(Dimension.Name);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Helper service procedures and functions.

// For an internal use.
// 
Function DataExchangeMonitorTable(Val ExchangePlans, Val ExchangePlanAdditionalProperties = "", Val OnlyErrors = False) Export
	
	QueryText = "SELECT
	|	DataExchangeStatus.InfobaseNode AS InfobaseNode,
	|	DataExchangeStatus.EndDate AS EndDate,
	|	CASE
	|		WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived)
	|				OR DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.CompletedWithWarnings)
	|			THEN 2
	|		WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Completed)
	|			THEN CASE
	|					WHEN ISNULL(CountProblems.Quantity, 0) > 0
	|						THEN 2
	|					ELSE 0
	|				END
	|		ELSE 1
	|	END AS ExchangeProcessResult
	|INTO DataExchangeStatusImport
	|FROM
	|	InformationRegister.DataExchangeStatus AS DataExchangeStatus
	|		LEFT JOIN CountProblems AS CountProblems
	|		ON DataExchangeStatus.InfobaseNode = CountProblems.InfobaseNode
	|WHERE
	|	DataExchangeStatus.ActionOnExchange = VALUE(Enum.ActionsAtExchange.DataImport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataExchangeStatus.InfobaseNode AS InfobaseNode,
	|	DataExchangeStatus.EndDate AS EndDate,
	|	CASE
	|		WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived)
	|			THEN 2
	|		WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.CompletedWithWarnings)
	|			THEN 2
	|		WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Completed)
	|			THEN 0
	|		ELSE 1
	|	END AS ExchangeProcessResult
	|INTO DataExchangeStatusExport
	|FROM
	|	InformationRegister.DataExchangeStatus AS DataExchangeStatus
	|WHERE
	|	DataExchangeStatus.ActionOnExchange = VALUE(Enum.ActionsAtExchange.DataExport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SuccessfulDataExchangeStatus.InfobaseNode AS InfobaseNode,
	|	SuccessfulDataExchangeStatus.EndDate AS EndDate
	|INTO SuccessfulDataExchangeStatusImport
	|FROM
	|	InformationRegister.SuccessfulDataExchangeStatus AS SuccessfulDataExchangeStatus
	|WHERE
	|	SuccessfulDataExchangeStatus.ActionOnExchange = VALUE(Enum.ActionsAtExchange.DataImport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SuccessfulDataExchangeStatus.InfobaseNode AS InfobaseNode,
	|	SuccessfulDataExchangeStatus.EndDate AS EndDate
	|INTO SuccessfulDataExchangeStatusExport
	|FROM
	|	InformationRegister.SuccessfulDataExchangeStatus AS SuccessfulDataExchangeStatus
	|WHERE
	|	SuccessfulDataExchangeStatus.ActionOnExchange = VALUE(Enum.ActionsAtExchange.DataExport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataExchangeScenarioExchangeSettings.InfobaseNode AS InfobaseNode
	|INTO DataSynchronizationScenario
	|FROM
	|	Catalog.DataExchangeScripts.ExchangeSettings AS DataExchangeScenarioExchangeSettings
	|WHERE
	|	DataExchangeScenarioExchangeSettings.Ref.UseScheduledJob = TRUE
	|
	|GROUP BY
	|	DataExchangeScenarioExchangeSettings.InfobaseNode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangePlans.InfobaseNode AS InfobaseNode,
	|
	|	[ExchangePlanAdditionalProperties]
	|
	|	ISNULL(DataExchangeStatusExport.ExchangeProcessResult, 0) AS LastDataExportResult,
	|	ISNULL(DataExchangeStatusImport.ExchangeProcessResult, 0) AS LastDataImportResult,
	|	DataExchangeStatusImport.EndDate AS LastImportDate,
	|	DataExchangeStatusExport.EndDate AS LastExportDate,
	|	SuccessfulDataExchangeStatusImport.EndDate AS LastSuccessfulImportDate,
	|	SuccessfulDataExchangeStatusExport.EndDate AS LastSuccessfulExportDate,
	|	CASE
	|		WHEN DataSynchronizationScenario.InfobaseNode IS NULL
	|			THEN 0
	|		ELSE 1
	|	END AS ScheduleIsCustomized
	|FROM
	|	ConfigurationExchangePlans AS ExchangePlans
	|		LEFT JOIN DataExchangeStatusImport AS DataExchangeStatusImport
	|		ON ExchangePlans.InfobaseNode = DataExchangeStatusImport.InfobaseNode
	|		LEFT JOIN DataExchangeStatusExport AS DataExchangeStatusExport
	|		ON ExchangePlans.InfobaseNode = DataExchangeStatusExport.InfobaseNode
	|		LEFT JOIN SuccessfulDataExchangeStatusImport AS SuccessfulDataExchangeStatusImport
	|		ON ExchangePlans.InfobaseNode = SuccessfulDataExchangeStatusImport.InfobaseNode
	|		LEFT JOIN SuccessfulDataExchangeStatusExport AS SuccessfulDataExchangeStatusExport
	|		ON ExchangePlans.InfobaseNode = SuccessfulDataExchangeStatusExport.InfobaseNode
	|		LEFT JOIN DataSynchronizationScenario AS DataSynchronizationScenario
	|		ON ExchangePlans.InfobaseNode = DataSynchronizationScenario.InfobaseNode
	|
	|[Filter]
	|
	|ORDER BY
	|	ExchangePlans.Description";
	
	SetPrivilegedMode(True);
	
	TempTablesManager = New TempTablesManager;
	
	GetExchangePlanTableForMonitor(TempTablesManager, ExchangePlans, ExchangePlanAdditionalProperties);
	GetTableOfExchangeForMonitor(TempTablesManager, ExchangePlans);
	
	QueryText = StrReplace(QueryText, "[ExchangePlanAdditionalProperties]", GetExchangePlanAdditionalPropertiesString(ExchangePlanAdditionalProperties));
	
	If OnlyErrors Then
		Filter = "
			|	WHERE ISNULL(DataExchangeStateExport.ExchangeResult, 0) <> 0 OR ISNULL(DataExchangeStatusImport.ExchangeResult, 0) <> 0"
		;
	Else
		Filter = "";
	EndIf;
	
	QueryText = StrReplace(QueryText, "[Filter]", Filter);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	SynchronizationSettings = Query.Execute().Unload();
	SynchronizationSettings.Columns.Add("LastExportDatePresentation");
	SynchronizationSettings.Columns.Add("LastImportDatePresentation");
	SynchronizationSettings.Columns.Add("LastSuccessfulExportDatePresentation");
	SynchronizationSettings.Columns.Add("LastSuccessfulImportDatePresentation");
	SynchronizationSettings.Columns.Add("VariantExchangeData", New TypeDescription("String"));
	SynchronizationSettings.Columns.Add("ExchangePlanName", New TypeDescription("String"));
	
	For Each SynchronizationSetting IN SynchronizationSettings Do
		
		OverridableExchangePlanNodeName = OverridableExchangePlanNodeName(SynchronizationSetting.InfobaseNode, "CorrespondentConfigurationName");
		
		If ValueIsFilled(OverridableExchangePlanNodeName) Then
			SynchronizationSetting.ExchangePlanName = OverridableExchangePlanNodeName;
		EndIf;
		
		SynchronizationSetting.LastExportDatePresentation         = RelativeSynchronizationDate(SynchronizationSetting.LastImportDate);
		SynchronizationSetting.LastImportDatePresentation         = RelativeSynchronizationDate(SynchronizationSetting.LastExportDate);
		SynchronizationSetting.LastSuccessfulImportDatePresentation = RelativeSynchronizationDate(SynchronizationSetting.LastSuccessfulImportDate);
		SynchronizationSetting.LastSuccessfulImportDatePresentation = RelativeSynchronizationDate(SynchronizationSetting.LastSuccessfulExportDate);
		
		SynchronizationSetting.VariantExchangeData = VariantExchangeData(SynchronizationSetting.InfobaseNode);
		
	EndDo;
	
	Return SynchronizationSettings;
	
EndFunction

Function SetExchangesQuantity(Val ExchangePlans) Export
	
	QueryText = "SELECT
	|	1 AS Field1
	|FROM
	|	ConfigurationExchangePlans AS ExchangePlans";
	
	SetPrivilegedMode(True);
	
	TempTablesManager = New TempTablesManager;
	
	GetExchangePlanTableForMonitor(TempTablesManager, ExchangePlans, "");
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload().Count();
	
EndFunction

// For an internal use.
// 
Function DataExchangeIsExecutedWithWarnings(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	QueryText = "
	|SELECT TOP 1 1
	|FROM
	|	InformationRegister.DataExchangeStatus AS DataExchangeStatus
	|WHERE
	|	DataExchangeStatus.InfobaseNode = &InfobaseNode
	|	AND (DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived)
	|			OR DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.CompletedWithWarnings))";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// For an internal use.
// 
Function GetExchangePlanAdditionalPropertiesString(Val PropertiesString)
	
	Result = "";
	
	Pattern = "ExchangePlans.[PropertyAsString] AS [PropertyAsString]";
	
	ArrayProperties = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(PropertiesString);
	
	For Each PropertyAsString IN ArrayProperties Do
		
		PropertyAsStringInQuery = StrReplace(Pattern, "[PropertyAsString]", PropertyAsString);
		
		Result = Result + PropertyAsStringInQuery + ", ";
		
	EndDo;
	
	Return Result;
EndFunction

// For an internal use.
// 
Function ExchangePlanFilterByDataSeparationFlag(ExchangePlansArray)
	
	Result = New Array;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		If CommonUseReUse.CanUseSeparatedData() Then
			
			For Each ExchangePlanName IN ExchangePlansArray Do
				
				If CommonUseReUse.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName,
						CommonUseReUse.MainDataSeparator())
					OR  CommonUseReUse.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName,
						CommonUseReUse.SupportDataSplitter()) Then
					
					Result.Add(ExchangePlanName);
					
				EndIf;
				
			EndDo;
			
		Else
			
			For Each ExchangePlanName IN ExchangePlansArray Do
				
				If Not CommonUseReUse.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName,
						CommonUseReUse.MainDataSeparator())
					AND Not CommonUseReUse.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName,
						CommonUseReUse.SupportDataSplitter()) Then
					
					Result.Add(ExchangePlanName);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	Else
		
		For Each ExchangePlanName IN ExchangePlansArray Do
			
			Result.Add(ExchangePlanName);
			
		EndDo;
		
	EndIf;
	
	Return Result;
EndFunction

// For an internal use.
// 
Function FilterOfExchangePlansByautonomousModeAttribute(ExchangePlansArray)
	
	Result = New Array;
	
	For Each ExchangePlanName IN ExchangePlansArray Do
		
		If ExchangePlanName <> DataExchangeReUse.OfflineWorkExchangePlan() Then
			
			Result.Add(ExchangePlanName);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// For an internal use.
// 
Function CorrespondentTablesForValuesByDefault(Val ExchangePlanName, Val CorrespondentVersion) Export
	
	Result = New Array;
	
	DefaultValues = CorrespondentInfobaseNodeDefaultValues(ExchangePlanName, CorrespondentVersion);
	
	For Each Item IN DefaultValues Do
		
		If Find(Item.Key, "_Key") > 0 Then
			Continue;
		EndIf;
		
		Result.Add(Item.Key);
		
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

// Procedure deletes irrelevant records in the information register.
// The record is considered irrelevant if the exchange plan for
// which the record is created have been renamed or deleted.
//
// Parameters:
//  No.
// 
Procedure DeleteNonActualRecordsFromDataExchangeRulesRegister()
	
	ExchangePlanList = DataExchangeReUse.SLExchangePlanList();
	
	QueryText = "
	|SELECT DISTINCT
	|	DataExchangeRules.ExchangePlanName AS ExchangePlanName
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If ExchangePlanList.FindByValue(Selection.ExchangePlanName) = Undefined Then
			
			RecordSet = CreateInformationRegisterRecordSet(New Structure("ExchangePlanName", Selection.ExchangePlanName), "DataExchangeRules");
			RecordSet.Write();
			
		EndIf;
		
	EndDo;
	
EndProcedure

// For an internal use.
// 
Procedure GetExchangePlanTableForMonitor(TempTablesManager, ExchangePlansArray, Val ExchangePlanAdditionalProperties)
	
	MethodExchangePlans = ExchangePlanFilterByDataSeparationFlag(ExchangePlansArray);
	
	If DataExchangeReUse.OfflineWorkSupported() Then
		
		// For autonomous work exchange plan separate monitor is used.
		MethodExchangePlans = FilterOfExchangePlansByautonomousModeAttribute(MethodExchangePlans);
		
	EndIf;
	
	ExchangePlanAdditionalPropertiesString = ?(IsBlankString(ExchangePlanAdditionalProperties), "", ExchangePlanAdditionalProperties + ", ");
	
	Query = New Query;
	
	QueryPattern = "
	|
	|UNION ALL
	|
	|//////////////////////////////////////////////////////// {[ExchangePlanName]}
	|SELECT
	|
	|	[ExchangePlanAdditionalProperties]
	|
	|	Ref                      AS InfobaseNode,
	|	Description                AS Description,
	|	""[ExchangePlanNameSynonym]"" AS ExchangePlanName
	|FROM
	|	ExchangePlan.[ExchangePlanName]
	|WHERE
	|	     Ref <> &ThisNode[ExchangePlanName]
	|	AND Not DeletionMark
	|";
	
	QueryText = "";
	
	If MethodExchangePlans.Count() > 0 Then
		
		For Each ExchangePlanName IN MethodExchangePlans Do
			
			ExchangePlanQueryText = StrReplace(QueryPattern,              "[ExchangePlanName]",        ExchangePlanName);
			ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "[ExchangePlanNameSynonym]", Metadata.ExchangePlans[ExchangePlanName].Synonym);
			ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "[ExchangePlanAdditionalProperties]", ExchangePlanAdditionalPropertiesString);
			
			ParameterName = StrReplace("ThisNode[ExchangePlanName]", "[ExchangePlanName]", ExchangePlanName);
			Query.SetParameter(ParameterName, DataExchangeReUse.GetThisNodeOfExchangePlan(ExchangePlanName));
			
			// Delete literal of merging for the first table.
			If IsBlankString(QueryText) Then
				
				ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "UNION ALL", "");
				
			EndIf;
			
			QueryText = QueryText + ExchangePlanQueryText;
			
		EndDo;
		
	Else
		
		AdditionalPropertiesWithoutDataSourceString = "";
		
		If Not IsBlankString(ExchangePlanAdditionalProperties) Then
			
			AdditionalProperties = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ExchangePlanAdditionalProperties);
			
			AdditionalPropertiesWithoutDataSource = New Array;
			
			For Each Property IN AdditionalProperties Do
				
				AdditionalPropertiesWithoutDataSource.Add(StrReplace("Undefined AS [Property]", "[Property]", Property));
				
			EndDo;
			
			AdditionalPropertiesWithoutDataSourceString = StringFunctionsClientServer.RowFromArraySubrows(AdditionalPropertiesWithoutDataSource) + ", ";
			
		EndIf;
		
		QueryText = "
		|SELECT
		|
		|	[AdditionalPropertiesWithoutDataSourceString]
		|
		|	Undefined AS InfobaseNode,
		|	Undefined AS Description,
		|	Undefined AS ExchangePlanName
		|";
		
		QueryText = StrReplace(QueryText, "[AdditionalPropertiesWithoutDataSourceInRow]", AdditionalPropertiesWithoutDataSourceString);
		
	EndIf;
	
	QueryTextResult = "
	|//////////////////////////////////////////////////////// {ConfigurationExchangePlans}
	|SELECT
	|
	|	[ExchangePlanAdditionalProperties]
	|
	|	InfobaseNode,
	|	Description,
	|	ExchangePlanName
	|INTO ConfigurationExchangePlans
	|FROM
	|	(
	|	[QueryText]
	|	) AS NestedSelect
	|;
	|";
	
	QueryTextResult = StrReplace(QueryTextResult, "[QueryText]", QueryText);
	QueryTextResult = StrReplace(QueryTextResult, "[ExchangePlanAdditionalProperties]", ExchangePlanAdditionalPropertiesString);
	
	Query.Text = QueryTextResult;
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
EndProcedure

// For an internal use.
// 
Procedure GetTableOfExchangeForMonitor(TempTablesManager, ExchangePlansArray)
	
	Query = New Query;
	
	If CommonUseReUse.CanUseSeparatedData() Then
		
		QueryTextResult = "
		|SELECT
		|	DataExchangeResults.InfobaseNode AS InfobaseNode,
		|	COUNT(DISTINCT DataExchangeResults.ProblematicObject) AS Quantity
		|INTO CountProblems
		|FROM
		|	InformationRegister.DataExchangeResults AS DataExchangeResults
		|WHERE
		|	DataExchangeResults.skipped = FALSE
		|
		|GROUP BY
		|	DataExchangeResults.InfobaseNode";
		
	Else
		
		QueryTextResult = "
		|SELECT
		|	Undefined AS InfobaseNode,
		|	Undefined AS Quantity
		|INTO CountProblems";
		
	EndIf;
	
	Query.Text = QueryTextResult;
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
EndProcedure

// Only for internal use.
//
Function ExchangePlansWithRulesFromFile()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataExchangeRules.ExchangePlanName
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesSource = &RulesSource";
	
	Query.SetParameter("RulesSource", Enums.RuleSourcesForDataExchange.File);
	Result = Query.Execute().Unload();
	
	Return Result.Count();
	
EndFunction

//

// For an internal use.
// 
Procedure CheckUseDataExchange() Export
	
	If GetFunctionalOption("UseDataSynchronization") <> True Then
		
		MessageText = NStr("en='Data synchronization is prohibited by administrator.';ru='Синхронизация данных запрещена администратором.'");
		WriteLogEvent(EventLogMonitorMessageTextDataExchange(), EventLogLevel.Error,,,MessageText);
		Raise MessageText;
		
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure CheckIfExchangesPossible() Export
	
	If Not Users.RolesAvailable("DataSynchronization, DataSynchronizationSetting") Then
		
		Raise NStr("en='Insufficient rights to data synchronization.';ru='Недостаточно прав для синхронизации данных.'");
		
	ElsIf InfobaseUpdate.InfobaseUpdateRequired()
	        AND Not DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart("ImportAllowed") Then
		
		Raise NStr("en='Infobase is being updated.';ru='Информационная база находится в состоянии обновления.'");
		
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure CheckExchangesAdministrationPossibility() Export
	
	If Not Users.RolesAvailable("DataSynchronizationSetting") Then
		
		Raise NStr("en='Insufficient rights to administer data synchronization.';ru='Недостаточно прав для администрирования синхронизации данных.'");
		
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure ValidateExternalConnection()
	
	If CommonUse.ThisLinuxServer() Then
		
		Raise NStr("en='Data synchronization via the direct connection on server managed by Linux OS is not available.
		|You need to use Windows OS for data synchronization via the direct connection.';ru='Синхронизация данных через прямое подключение на сервере под управлением ОС Linux недоступно.
		|Для синхронизации данных через прямое подключение требуется использовать ОС Windows.'");
			
	EndIf;
	
EndProcedure

// Returns the flag showing that a user has rights to execute the data synchronization.
// Either a full user, or a
// user with rights of the Data synchronization with other applications delivered profile can execute data synchronization.
//
//  Parameters:
// User (optional) - InfobaseUser, Undefined.
// User for which it is required to calculate the flag og permission to use data synchronization.
// If the parameter is not specified, then the function is calculated for the current user of infobase.
//
Function DataSynchronizationIsEnabled(Val User = Undefined) Export
	
	If User = Undefined Then
		User = InfobaseUsers.CurrentUser();
	EndIf;
	
	If User.Roles.Contains(Metadata.Roles.FullRights) Then
		Return True;
	EndIf;
	
	ProfileRoles = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(
		ProfileRolesAccessSyncDataWithAnotherApplications());
	For Each Role IN ProfileRoles Do
		
		If Not User.Roles.Contains(Metadata.Roles.Find(TrimAll(Role))) Then
			Return False;
		EndIf;
		
	EndDo;
	
	Return True;
EndFunction

//

// Fills in the list of values with the available transport kinds for the exchange plan node.
//
Procedure FillChoiceListByAvailableTransportKinds(InfobaseNode, FormItem, Filter = Undefined) Export
	
	FilterSet = (Filter <> Undefined);
	
	UsedTransports = DataExchangeReUse.UsedTransportsOfExchangeMessages(InfobaseNode);
	
	FormItem.ChoiceList.Clear();
	
	For Each Item IN UsedTransports Do
		
		If FilterSet Then
			
			If Filter.Find(Item) <> Undefined Then
				
				FormItem.ChoiceList.Add(Item, String(Item));
				
			EndIf;
			
		Else
			
			FormItem.ChoiceList.Add(Item, String(Item));
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Registers that exchange was made and writes the information to the protocol.
//
// Parameters:
//  ExchangeSettingsStructure - Structure - structure with all necessary data and objects for exchange.
// 
Procedure FixEndExchange(ExchangeSettingsStructure) Export
	
	// The Undefined status at the end of the exchange indicates successful execution of the exchange.
	If ExchangeSettingsStructure.ExchangeProcessResult = Undefined Then
		ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Completed;
	EndIf;
	
	// Generate the final message for protocol.
	If ExchangeSettingsStructure.IsDIBExchange Then
		MessageString = NStr("en='%1, %2';ru='%1, %2'", CommonUseClientServer.MainLanguageCode());
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
							ExchangeSettingsStructure.ExchangeProcessResult,
							ExchangeSettingsStructure.ActionOnExchange);
	Else
		MessageString = NStr("en='%1, %2; Processed objects: %3';ru='%1, %2; Объектов обработано: %3'", CommonUseClientServer.MainLanguageCode());
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
							ExchangeSettingsStructure.ExchangeProcessResult,
							ExchangeSettingsStructure.ActionOnExchange,
							ExchangeSettingsStructure.ProcessedObjectCount);
	EndIf;
	
	ExchangeSettingsStructure.EndDate = CurrentSessionDate();
	
	// Fix the exchange state in IR.
	FixEndExchangeInInformationRegister(ExchangeSettingsStructure);
	
	// If data exchange was successfully executed.
	If ExchangeProcessResultCompleted(ExchangeSettingsStructure.ExchangeProcessResult) Then
		
		FixSuccessfulDataExchangeInInformationRegister(ExchangeSettingsStructure);
		
		InformationRegisters.InfobasesNodesCommonSettings.RemoveSignOfDataTransfer(ExchangeSettingsStructure.InfobaseNode);
		
	EndIf;
	
	WriteLogEventOfDataExchange(MessageString, ExchangeSettingsStructure);
	
EndProcedure

// Writes the state of the data exchange to the DataExchangeState information register.
//
// Parameters:
//  ExchangeSettingsStructure - Structure - structure with all necessary data and objects for exchange.
// 
Procedure FixEndExchangeInInformationRegister(ExchangeSettingsStructure)
	
	// Create structure for a new record in IR.
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode",    ExchangeSettingsStructure.InfobaseNode);
	RecordStructure.Insert("ActionOnExchange",         ExchangeSettingsStructure.ActionOnExchange);
	
	RecordStructure.Insert("ExchangeProcessResult", ExchangeSettingsStructure.ExchangeProcessResult);
	RecordStructure.Insert("StartDate",                ExchangeSettingsStructure.StartDate);
	RecordStructure.Insert("EndDate",             ExchangeSettingsStructure.EndDate);
	
	InformationRegisters.DataExchangeStatus.AddRecord(RecordStructure);
	
EndProcedure

// For an internal use.
// 
Procedure FixSuccessfulDataExchangeInInformationRegister(ExchangeSettingsStructure)
	
	// Create structure for a new record in IR.
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", ExchangeSettingsStructure.InfobaseNode);
	RecordStructure.Insert("ActionOnExchange",      ExchangeSettingsStructure.ActionOnExchange);
	RecordStructure.Insert("EndDate",          ExchangeSettingsStructure.EndDate);
	
	InformationRegisters.SuccessfulDataExchangeStatus.AddRecord(RecordStructure);
	
EndProcedure

// For an internal use.
// 
Procedure WriteLogEventDataExchangeStart(ExchangeSettingsStructure) Export
	
	MessageString = NStr("en='Data exchange process start for node %1';ru='Начало процесса обмена данными для узла %1'", CommonUseClientServer.MainLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteLogEventOfDataExchange(MessageString, ExchangeSettingsStructure);
	
EndProcedure

// Expands the values table with empty rows up to the specified number of rows.
//
Procedure SetTableRowQuantity(Table, LineCount) Export
	
	While Table.Count() < LineCount Do
		
		Table.Add();
		
	EndDo;
	
EndProcedure

// Creates a record in the events log monitor about data exchange event/exchange messages transport.
//
Procedure WriteLogEventOfDataExchange(Comment, ExchangeSettingsStructure, IsError = False) Export
	
	Level = ?(IsError, EventLogLevel.Error, EventLogLevel.Information);
	
	WriteLogEvent(ExchangeSettingsStructure.EventLogMonitorMessageKey, Level,,, Comment);
	
EndProcedure

Procedure WriteEventGetData(Val InfobaseNode, Val Comment, Val IsError = False)
	
	Level = ?(IsError, EventLogLevel.Error, EventLogLevel.Information);
	
	EventLogMonitorMessageKey = GetEventLogMonitorMessageKey(InfobaseNode, Enums.ActionsAtExchange.DataImport);
	
	WriteLogEvent(EventLogMonitorMessageKey, Level,,, Comment);
	
EndProcedure

// For an internal use.
// 
Procedure NodeSettingsFormOnCreateAtServerHandler(Form, FormAttributeName)
	
	FormAttributes = FormAttributeNames(Form);
	
	For Each FilterSettings IN Form[FormAttributeName] Do
		
		FSKey = FilterSettings.Key;
		
		If FormAttributes.Find(FSKey) = Undefined Then
			Continue;
		EndIf;
		
		If TypeOf(Form[FSKey]) = Type("FormDataCollection") Then
			
			Table = New ValueTable;
			
			TabularSectionStructure = Form.Parameters[FormAttributeName][FSKey];
			
			For Each Item IN TabularSectionStructure Do
				
				SetTableRowQuantity(Table, Item.Value.Count());
				
				Table.Columns.Add(Item.Key);
				
				Table.LoadColumn(Item.Value, Item.Key);
				
			EndDo;
			
			Form[FSKey].Load(Table);
			
		Else
			
			Form[FSKey] = Form.Parameters[FormAttributeName][FSKey];
			
		EndIf;
		
		Form[FormAttributeName][FSKey] = Form.Parameters[FormAttributeName][FSKey];
		
	EndDo;
	
EndProcedure

// For an internal use.
// 
Function FormAttributeNames(Form)
	
	// Return value of the function.
	Result = New Array;
	
	For Each FormAttribute IN Form.GetAttributes() Do
		
		Result.Add(FormAttribute.Name);
		
	EndDo;
	
	Return Result;
EndFunction

// Unpacks the ZIP archive file to the specified directory; Extracts all archive files.
// 
// Parameters:
//  ArchiveFileFullName  - String - archive attachment file name that is required to be uncompressed.
//  FileUnpackPath  - String - path according to which it is required to uncompress files.
//  ArchivePassword          - String - password for the archive unpacking. Default empty row.
// 
// Returns:
//  Result - Boolean - True if successful, False if not.
//
Function UnpackZIPFile(Val ArchiveFileFullName, Val FileUnpackPath, Val ArchivePassword = "") Export
	
	// Return value of the function.
	Result = True;
	
	Try
		
		Archiver = New ZipFileReader(ArchiveFileFullName, ArchivePassword);
		
	Except
		Archiver = Undefined;
		ShowMessageAboutError(BriefErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	Try
		
		Archiver.ExtractAll(FileUnpackPath, ZIPRestoreFilePathsMode.DontRestore);
		
	Except
		
		MessageString = NStr("en='An error occurred when unpacking archive files %1 to directory: %2';ru='Ошибка при распаковке файлов архива: %1 в каталог: %2'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ArchiveFileFullName, FileUnpackPath);
		CommonUseClientServer.MessageToUser(MessageString);
		
		Result = False;
	EndTry;
	
	Archiver.Close();
	Archiver = Undefined;
	
	Return Result;
	
EndFunction

// Packs the specified directory to the ZIP archive file.
// 
// Parameters:
//  ArchiveFileFullName  - String - name of the archive file to which it is required to pack.
//  FilePackingMask    - String - attachment file name put to the archive or a mask.
// 		You can not use letters of the national alphabet in the names of files and folders. These letters can be converted losing information from UNICODE characters to narrow characters. 
// 		It is recommended to use latin alphabet characters in the names of files and directories. 
//  ArchivePassword          - String - password for archive. Default empty row.
// 
// Returns:
//  Result - Boolean - True if successful, False if not.
//
Function PackIntoZipFile(Val ArchiveFileFullName, Val FilePackingMask, Val ArchivePassword = "") Export
	
	// Return value of the function.
	Result = True;
	
	Try
		
		Archiver = New ZipFileWriter(ArchiveFileFullName, ArchivePassword);
		
	Except
		Archiver = Undefined;
		ShowMessageAboutError(BriefErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	Try
		
		Archiver.Add(FilePackingMask, ZIPStorePathMode.DontStorePath);
		Archiver.Write();
		
	Except
		
		MessageString = NStr("en='An error occurred when packing archive files: %1 from directory: %2';ru='Ошибка при запаковке файлов архива: %1 из каталог: %2'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ArchiveFileFullName, FilePackingMask);
		CommonUseClientServer.MessageToUser(MessageString);
		
		Result = False;
	EndTry;
	
	Archiver = Undefined;
	
	Return Result;
	
EndFunction

// Returns the quantity of records in the data base table.
// 
// Parameters:
//  TableName - String - full name of the data base table. For example: Catalog.Counterparties.Orders.
// 
// Returns:
//  Number - Quantity of records in the data base table.
//
Function NumberOfRecordInDatabaseTable(Val TableName) Export
	
	QueryText = "
	|SELECT
	|	Count(*) AS Quantity
	|FROM
	|	#TableName
	|";
	
	QueryText = StrReplace(QueryText, "#TableName", TableName);
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection["Quantity"];
	
EndFunction

// Returns quantity of records in the data base temporary table.
// 
// Parameters:
//  TableName - String - table name. For example: TemporaryTable1.
//  TempTablesManager - Manager of the temporary tables that contains a pointer to the TableName temporary table.
// 
// Returns:
//  Number - Quantity of records in the data base table.
//
Function NumberOfRecordsInTemporaryTableOfDatabase(Val TableName, TempTablesManager) Export
	
	QueryText = "
	|SELECT
	|	Count(*) AS Quantity
	|FROM
	|	#TableName
	|";
	
	QueryText = StrReplace(QueryText, "#TableName", TableName);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection["Quantity"];
	
EndFunction

// Returns message key of the events log monitor.
//
Function GetEventLogMonitorMessageKey(InfobaseNode, ActionOnExchange) Export
	
	ExchangePlanName     = DataExchangeReUse.GetExchangePlanName(InfobaseNode);
	ExchangePlanNodeCode = TrimAll(CommonUse.ObjectAttributeValue(InfobaseNode, "Code"));
	
	MessageKey = NStr("en='Data exchange.[ExchangePlanName].Node[NodeCode].[ActionOnExchange]';ru='Обмен данными.[ИмяПланаОбмена].Узел [КодУзла].[ДействиеПриОбмене]'",
		CommonUseClientServer.MainLanguageCode());
	
	MessageKey = StrReplace(MessageKey, "[ExchangePlanName]",    ExchangePlanName);
	MessageKey = StrReplace(MessageKey, "[NodeCode]",           ExchangePlanNodeCode);
	MessageKey = StrReplace(MessageKey, "[ActionOnExchange]", ActionOnExchange);
	
	Return MessageKey;
	
EndFunction

// Returns the name of the data exchange message file by the data of node-sender and node-recipient.
//
Function ExchangeMessageFileName(SenderNodeCode, RecipientNodeCode) Export
	
	NamePattern = "[Prefix]_[SenderNode]_[RecipientNode]";
	
	NamePattern = StrReplace(NamePattern, "[Prefix]",         "Message");
	NamePattern = StrReplace(NamePattern, "[SenderNode]", SenderNodeCode);
	NamePattern = StrReplace(NamePattern, "[RecipientNode]",  RecipientNodeCode);
	
	Return NamePattern;
EndFunction

// Returns the flag showing that the attribute is included into the subset of standard attributes.
//
Function ThisIsStandardAttribute(StandardAttributes, AttributeName) Export
	
	For Each Attribute IN StandardAttributes Do
		
		If Attribute.Name = AttributeName Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

// Returns array of all kinds of exchange messages transport defined in configuration.
// 
// Parameters:
//  No.
// 
//  Returns:
//   Array - Array items have the EnumRef.ExchangeMessagesTransportKinds type.
//
Function AllExchangeMessageTransportsOfConfiguration() Export
	
	Result = New Array;
	Result.Add(Enums.ExchangeMessagesTransportKinds.COM);
	Result.Add(Enums.ExchangeMessagesTransportKinds.WS);
	Result.Add(Enums.ExchangeMessagesTransportKinds.FILE);
	Result.Add(Enums.ExchangeMessagesTransportKinds.FTP);
	Result.Add(Enums.ExchangeMessagesTransportKinds.EMAIL);
	
	Return Result;
EndFunction

// Returns the flag showing that data exchange was successfull.
//
Function ExchangeProcessResultCompleted(ExchangeProcessResult)
	
	Return ExchangeProcessResult = Undefined
		OR ExchangeProcessResult = Enums.ExchangeExecutionResult.Completed
		OR ExchangeProcessResult = Enums.ExchangeExecutionResult.CompletedWithWarnings;
	
EndFunction

// Generates and returns the key of the data table.
// Key of the table is used for the selective data import from the exchange message by the specified key.
//
Function DataTableKey(Val SourceType, Val ReceiverType, Val ThisIsObjectDeletion) Export
	
	Return SourceType + "#" + ReceiverType + "#" + String(ThisIsObjectDeletion);
	
EndFunction

// For an internal use.
// 
Function NeedToExecuteHandler(Object, Ref, PropertyName)
	
	NumberAfterProcessing = Object[PropertyName];
	
	NumberBeforeProcessing = CommonUse.ObjectAttributeValue(Ref, PropertyName);
	
	NumberBeforeProcessing = ?(NumberBeforeProcessing = Undefined, 0, NumberBeforeProcessing);
	
	Return NumberBeforeProcessing <> NumberAfterProcessing;
	
EndFunction

// For an internal use.
// 
Function FillExternalConnectionParameters(TransportSettings)
	
	ConnectionParameters = CommonUseClientServer.ExternalConnectionParameterStructure();
	
	ConnectionParameters.InfobaseOperationMode             = TransportSettings.COMInfobaseOperationMode;
	ConnectionParameters.InfobaseDirectory                   = TransportSettings.COMInfobaseDirectory;
	ConnectionParameters.PlatformServerName                     = TransportSettings.COMServerName1CEnterprise;
	ConnectionParameters.InfobaseNameAtPlatformServer = TransportSettings.COMInfobaseNameAtServer1CEnterprise;
	ConnectionParameters.OSAuthentication           = TransportSettings.COMAuthenticationOS;
	ConnectionParameters.UserName                             = TransportSettings.COMUserName;
	ConnectionParameters.UserPassword                          = TransportSettings.COMUserPassword;
	
	Return ConnectionParameters;
EndFunction

// For an internal use.
// 
Function AddLiteralToFileName(Val FullFileName, Val Literal)
	
	If IsBlankString(FullFileName) Then
		Return "";
	EndIf;
	
	FileDescriptionWithoutExtension = Mid(FullFileName, 1, StrLen(FullFileName) - 4);
	
	Extension = Right(FullFileName, 3);
	
	Result = "[FileDescriptionWithoutExtension]_[Literal].[Extension]";
	
	Result = StrReplace(Result, "[FileDescriptionWithoutExtension]", FileDescriptionWithoutExtension);
	Result = StrReplace(Result, "[Literal]",               Literal);
	Result = StrReplace(Result, "[Extension]",            Extension);
	
	Return Result;
EndFunction

// For an internal use.
// 
Function ExchangePlanNodeCodeString(Value) Export
	
	If TypeOf(Value) = Type("String") Then
		
		Return TrimAll(Value);
		
	ElsIf TypeOf(Value) = Type("Number") Then
		
		Return Format(Value, "ND=7; NLZ=; NG=0");
		
	EndIf;
	
	Return Value;
EndFunction

// For an internal use.
// 
Function DataAreaNumberByExchangePlanNodeCode(Val NodeCode) Export
	
	If TypeOf(NodeCode) <> Type("String") Then
		Raise NStr("en='Invalid type of parameter number [1].';ru='Неправильный тип параметра номер [1].'");
	EndIf;
	
	Result = StrReplace(NodeCode, "S0", "");
	
	Return Number(Result);
EndFunction

// For an internal use.
// 
Function ValueByType(Value, TypeName) Export
	
	If TypeOf(Value) <> Type(TypeName) Then
		
		Return New(Type(TypeName));
		
	EndIf;
	
	Return Value;
EndFunction

// For an internal use.
// 
Function PredefinedExchangePlanNodeDescription(ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return CommonUse.ObjectAttributeValue(DataExchangeReUse.GetThisNodeOfExchangePlan(ExchangePlanName), "Description");
EndFunction

// For an internal use.
// 
Function ThisNodeDefaultDescription() Export
	
	Return ?(CommonUseReUse.DataSeparationEnabled(), Metadata.Synonym, DataExchangeReUse.ThisInfobaseName());
	
EndFunction

// For an internal use.
// 
Procedure HandlerOnDataExportSSL(StandardProcessing,
											Val Recipient,
											Val MessageFileName,
											MessageData,
											Val ItemCountInTransaction,
											Val EventLogMonitorEventName,
											SentObjectCount)
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.DataExchange\DuringDataDumpService");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.DuringDataDumpService(
			StandardProcessing,
			Recipient,
			MessageFileName,
			MessageData,
			ItemCountInTransaction,
			EventLogMonitorEventName,
			SentObjectCount);
	EndDo;
	
EndProcedure

// For an internal use.
// 
Procedure HandlerOnDataExporting(StandardProcessing,
											Val Recipient,
											Val MessageFileName,
											MessageData,
											Val ItemCountInTransaction,
											Val EventLogMonitorEventName,
											SentObjectCount)
	
	DataExchangeOverridable.DuringDataDump(StandardProcessing,
											Recipient,
											MessageFileName,
											MessageData,
											ItemCountInTransaction,
											EventLogMonitorEventName,
											SentObjectCount);
	
EndProcedure

// For an internal use.
// 
Procedure HandlerOnDataImportSSL(StandardProcessing,
											Val Sender,
											Val MessageFileName,
											MessageData,
											Val ItemCountInTransaction,
											Val EventLogMonitorEventName,
											ReceivedObjectCount)
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.DataExchange\WithImportingDataCall");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.WithImportingDataCall(
			StandardProcessing,
			Sender,
			MessageFileName,
			MessageData,
			ItemCountInTransaction,
			EventLogMonitorEventName,
			ReceivedObjectCount);
	EndDo;
	
EndProcedure

// For an internal use.
// 
Procedure HandlerOnDataImport(StandardProcessing,
											Val Sender,
											Val MessageFileName,
											MessageData,
											Val ItemCountInTransaction,
											Val EventLogMonitorEventName,
											ReceivedObjectCount)
	
	DataExchangeOverridable.OnDataImport(StandardProcessing,
											Sender,
											MessageFileName,
											MessageData,
											ItemCountInTransaction,
											EventLogMonitorEventName,
											ReceivedObjectCount);
	
EndProcedure

// For an internal use.
// 
Procedure FixExchangeFinishedWithError(Val InfobaseNode, 
												Val ActionOnExchange, 
												Val StartDate, 
												Val ErrorMessageString
	) Export
	
	If TypeOf(ActionOnExchange) = Type("String") Then
		
		ActionOnExchange = Enums.ActionsAtExchange[ActionOnExchange];
		
	EndIf;
	
	ExchangeSettingsStructure = New Structure;
	ExchangeSettingsStructure.Insert("InfobaseNode", InfobaseNode);
	ExchangeSettingsStructure.Insert("ExchangeProcessResult", Enums.ExchangeExecutionResult.Error);
	ExchangeSettingsStructure.Insert("ActionOnExchange", ActionOnExchange);
	ExchangeSettingsStructure.Insert("ProcessedObjectCount", 0);
	ExchangeSettingsStructure.Insert("EventLogMonitorMessageKey", GetEventLogMonitorMessageKey(InfobaseNode, ActionOnExchange));
	ExchangeSettingsStructure.Insert("StartDate", StartDate);
	ExchangeSettingsStructure.Insert("EndDate", CurrentSessionDate());
	ExchangeSettingsStructure.Insert("IsDIBExchange", DataExchangeReUse.ThisIsDistributedInformationBaseNode(InfobaseNode));
	
	WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
	
	FixEndExchange(ExchangeSettingsStructure);
	
EndProcedure

// For an internal use.
// 
Procedure ExecuteFormTablesComparisonAndMerging(Form, Cancel)
	
	ExchangePlanName = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Form.FormName, ".")[1];
	
	CorrespondentData = CorrespondentNodeCommonData(ExchangePlanName, Form.Parameters.ConnectionParameters, Cancel);
	
	If CorrespondentData = Undefined Then
		Return;
	EndIf;
	
	ThisInfobaseData = DataForThisInfobaseNodeTabularSections(ExchangePlanName, Form.CorrespondentVersion);
	
	ExchangePlanTabularSections = DataExchangeReUse.ExchangePlanTabularSections(ExchangePlanName, Form.CorrespondentVersion);
	
	FormAttributeNames = FormAttributeNames(Form);
	
	// Join tables of the Common data.
	For Each TabularSectionName IN ExchangePlanTabularSections["CommonTables"] Do
		
		If FormAttributeNames.Find(TabularSectionName) = Undefined Then
			Continue;
		EndIf;
		
		CommonTable = New ValueTable;
		CommonTable.Columns.Add("Presentation", New TypeDescription("String"));
		CommonTable.Columns.Add("RefUUID", New TypeDescription("String"));
		
		For Each TableRow IN ThisInfobaseData[TabularSectionName] Do
			
			FillPropertyValues(CommonTable.Add(), TableRow);
			
		EndDo;
		
		For Each TableRow IN CorrespondentData[TabularSectionName] Do
			
			FillPropertyValues(CommonTable.Add(), TableRow);
			
		EndDo;
		
		ResultTable = CommonTable.Copy(, "RefUUID");
		ResultTable.GroupBy("RefUUID");
		ResultTable.Columns.Add("Presentation", New TypeDescription("String"));
		ResultTable.Columns.Add("Use", New TypeDescription("Boolean"));
		
		For Each ResultTableRow IN ResultTable Do
			
			TableRow = CommonTable.Find(ResultTableRow.RefUUID, "RefUUID");
			
			ResultTableRow.Presentation = TableRow.Presentation;
			
		EndDo;
		
		SynchronizeUseAttributeInTablesFlag(Form[TabularSectionName], ResultTable);
		
		ResultTable.Sort("Presentation");
		
		Form[TabularSectionName].Load(ResultTable);
		
	EndDo;
	
	MatchThisApplicationAttribute = Form.AttributeNames;
	
	// Join tables of data This base.
	For Each TabularSectionName IN ExchangePlanTabularSections["ThisInfobaseTables"] Do
		
		If MatchThisApplicationAttribute.Property(TabularSectionName) Then
			AttributeName = MatchThisApplicationAttribute[TabularSectionName];
		ElsIf FormAttributeNames.Find(TabularSectionName) = Undefined Then
			Continue;
		Else
			AttributeName = TabularSectionName;
		EndIf;
		
		ResultTable = ThisInfobaseData[TabularSectionName].Copy();
		ResultTable.Columns.Add("Use", New TypeDescription("Boolean"));
		
		SynchronizeUseAttributeInTablesFlag(Form[AttributeName], ResultTable);
		
		Form[AttributeName].Load(ResultTable);
		
	EndDo;
	
	MatchCorrespondentAttributes = Form.CorrespondentBaseAttributeNames;
	
	// Join tables of Correspondent data.
	For Each TabularSectionName IN ExchangePlanTabularSections["CorrespondentTables"] Do
		
		If MatchCorrespondentAttributes.Property(TabularSectionName) Then
			AttributeName = MatchCorrespondentAttributes[TabularSectionName];
		ElsIf FormAttributeNames.Find(TabularSectionName) = Undefined Then
			Continue;
		Else
			AttributeName = TabularSectionName;
		EndIf;
		
		ResultTable = CorrespondentData[TabularSectionName].Copy();
		ResultTable.Columns.Add("Use", New TypeDescription("Boolean"));
		
		SynchronizeUseAttributeInTablesFlag(Form[AttributeName], ResultTable);
		
		Form[AttributeName].Load(ResultTable);
		
	EndDo;
	
EndProcedure

// For an internal use.
// 
Procedure SynchronizeUseAttributeInTablesFlag(FormTable, ResultTable)
	
	If FormTable.Count() = 0 Then
		
		// When you access the table for the first time, select all check boxes.
		ResultTable.FillValues(True, "Use");
		
	Else
		
		// If there is a previous context of the table, then use this context for selecting check boxes.
		PreviousContextTable = FormTable.Unload(New Structure("Use", True), "RefUUID");
		
		ResultTable.FillValues(False, "Use");
		
		For Each ContextTableRow IN PreviousContextTable Do
			
			TableRow = ResultTable.Find(ContextTableRow.RefUUID, "RefUUID");
			
			If TableRow <> Undefined Then
				
				TableRow.Use = True;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure FillFormData(Form)
	
	// Fill data of this application.
	CorrespondingAttributes = Form.AttributeNames;
	FilterSsettingsAtNode = Form.Context.FilterSsettingsAtNode;
	
	For Each SettingItem IN FilterSsettingsAtNode Do
		
		If CorrespondingAttributes.Property(SettingItem.Key) Then
			AttributeName = CorrespondingAttributes[SettingItem.Key];
		Else
			AttributeName = SettingItem.Key;
		EndIf;
		
		FormAttribute = Form[AttributeName];
		
		If TypeOf(FormAttribute) = Type("FormDataCollection") Then
			
			If TypeOf(SettingItem.Value) = Type("Array")
				AND SettingItem.Value.Count() > 0 Then
				
				Table = Form[AttributeName].Unload();
				
				Table.Clear();
				
				For Each TableRow IN SettingItem.Value Do
					
					FillPropertyValues(Table.Add(), TableRow);
					
				EndDo;
				
				Form[AttributeName].Load(Table);
				
			EndIf;
			
		Else
			
			Form[AttributeName] = SettingItem.Value;
			
		EndIf;
		
	EndDo;
	
	// Fill data of the correspondent.
	CorrespondingAttributes = Form.CorrespondentBaseAttributeNames;
	CorrespondentInfobaseNodeFilterSetup = Form.Context.CorrespondentInfobaseNodeFilterSetup;
	
	For Each SettingItem IN CorrespondentInfobaseNodeFilterSetup Do
		
		If CorrespondingAttributes.Property(SettingItem.Key) Then
			AttributeName = CorrespondingAttributes[SettingItem.Key];
		Else
			AttributeName = SettingItem.Key;
		EndIf;
		
		FormAttribute = Form[AttributeName];
		
		If TypeOf(FormAttribute) = Type("FormDataCollection") Then
			
			If TypeOf(SettingItem.Value) = Type("Array")
				AND SettingItem.Value.Count() > 0 Then
				
				Table = Form[AttributeName].Unload();
				
				Table.Clear();
				
				For Each TableRow IN SettingItem.Value Do
					
					FillPropertyValues(Table.Add(), TableRow);
					
				EndDo;
				
				Form[AttributeName].Load(Table);
				
			EndIf;
			
		Else
			
			Form[AttributeName] = SettingItem.Value;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Checks if there are specified attributes in form.
// If at least one attribute is absent, then throws an exception.
//
Procedure ValidateRequiredFormAttributes(Form, Val Attributes)
	
	MissingAttributes = New Array;
	
	FormAttributes = FormAttributeNames(Form);
	
	For Each Attribute IN StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Attributes) Do
		
		Attribute = TrimAll(Attribute);
		
		If FormAttributes.Find(Attribute) = Undefined Then
			
			MissingAttributes.Add(Attribute);
			
		EndIf;
		
	EndDo;
	
	If MissingAttributes.Count() > 0 Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(NStr("en='No required attributes of node configuration form: %1';ru='Отсутствуют обязательные реквизиты формы настройки узла: %1'"),
			StringFunctionsClientServer.RowFromArraySubrows(MissingAttributes)
		);
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure SetMandatoryFormAttributes(Form, MandatoryFormAttributes)
	
	MissingAttributes = New Array;
	
	FormAttributes = FormAttributeNames(Form);
	
	For Each Attribute IN MandatoryFormAttributes Do
		
		If FormAttributes.Find(Attribute.Name) = Undefined Then
			
			MissingAttributes.Add(New FormAttribute(Attribute.Name, Attribute.AttributeType));
			Attribute.AttributeAdded = True;
			
		EndIf;
		
	EndDo;
	
	If MissingAttributes.Count() = 0 Then
		Return;
	EndIf;
	
	Form.ChangeAttributes(MissingAttributes);
	
	// Initialization of values
	FilterParameters = New Structure();
	FilterParameters.Insert("FillingRequired", True);
	FilterParameters.Insert("AttributeAdded", True);
	AttributesForFilling = MandatoryFormAttributes.FindRows(FilterParameters);
	
	For Each Attribute IN AttributesForFilling Do
		
		Form[Attribute.Name] = Attribute.FillValue;
		
	EndDo;
	
EndProcedure

// For an internal use.
// 
Function MandatoryFormAttributesNodesSettings()
	
	MandatoryFormAttributes = New ValueTable;
	
	MandatoryFormAttributes.Columns.Add("Name");
	MandatoryFormAttributes.Columns.Add("AttributeType");
	MandatoryFormAttributes.Columns.Add("FillingRequired");
	MandatoryFormAttributes.Columns.Add("FillValue");
	MandatoryFormAttributes.Columns.Add("AttributeAdded");
	
	NewRow = MandatoryFormAttributes.Add();
	NewRow.Name = "Context";
	NewRow.AttributeType = New TypeDescription();
	NewRow.FillingRequired = False;
	
	NewRow = MandatoryFormAttributes.Add();
	NewRow.Name = "ContextDetails";
	NewRow.AttributeType = New TypeDescription("String");
	NewRow.FillingRequired = False;
	
	NewRow = MandatoryFormAttributes.Add();
	NewRow.Name = "Attributes";
	NewRow.AttributeType = New TypeDescription("String");
	NewRow.FillingRequired = False;
	
	NewRow = MandatoryFormAttributes.Add();
	NewRow.Name = "CorrespondentVersion";
	NewRow.AttributeType = New TypeDescription("String");
	NewRow.FillingRequired = False;
	
	NewRow = MandatoryFormAttributes.Add();
	NewRow.Name = "AttributeNames";
	NewRow.AttributeType = New TypeDescription();
	NewRow.FillingRequired = True;
	NewRow.FillValue = New Structure;
	
	NewRow = MandatoryFormAttributes.Add();
	NewRow.Name = "CorrespondentBaseAttributeNames";
	NewRow.AttributeType = New TypeDescription();
	NewRow.FillingRequired = True;
	NewRow.FillValue = New Structure;
	
	MandatoryFormAttributes.FillValues(False, "AttributeAdded");
	
	Return MandatoryFormAttributes;
	
EndFunction

// For an internal use.
// 
Procedure ChangeTableSectionsStorageStructure(DefaultSettings)
	
	For Each Setting IN DefaultSettings Do
		
		If TypeOf(Setting.Value) = Type("Structure") Then
			
			DefaultSettings.Insert(Setting.Key, New Array);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// For an internal use.
// 
Procedure ExternalConnectionRefreshExchangeSettingsData(Val ExchangePlanName, Val NodeCode, Val DefaultValuesAtNode) Export
	
	SetPrivilegedMode(True);
	
	InfobaseNode = ExchangePlans[ExchangePlanName].FindByCode(NodeCode);
	
	If Not ValueIsFilled(InfobaseNode) Then
		Message = NStr("en='Exchange plan node is not found; exchange plan name %1; node code %2';ru='Не найден узел плана обмена; имя плана обмена %1; код узла %2'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ExchangePlanName, NodeCode);
		Raise Message;
	EndIf;
	
	DataExchangeCreationAssistant = DataProcessors.DataExchangeCreationAssistant.Create();
	DataExchangeCreationAssistant.InfobaseNode = InfobaseNode;
	DataExchangeCreationAssistant.ExternalConnectionRefreshExchangeSettingsData(GetFilterSettingsValues(DefaultValuesAtNode));
	
EndProcedure

// For an internal use.
// 
Function GetFilterSettingsValues(ExternalConnectionSettingsStructure) Export
	
	Result = New Structure;
	
	// object types
	For Each FilterSettings IN ExternalConnectionSettingsStructure Do
		
		If TypeOf(FilterSettings.Value) = Type("Structure") Then
			
			ResultNested = New Structure;
			
			For Each Item IN FilterSettings.Value Do
				
				If Find(Item.Key, "_Key") > 0 Then
					
					strKey = StrReplace(Item.Key, "_Key", "");
					
					Array = New Array;
					
					For Each ArrayElement IN Item.Value Do
						
						If Not IsBlankString(ArrayElement) Then
							
							Value = ValueFromStringInternal(ArrayElement);
							
							Array.Add(Value);
							
						EndIf;
						
					EndDo;
					
					ResultNested.Insert(strKey, Array);
					
				EndIf;
				
			EndDo;
			
			Result.Insert(FilterSettings.Key, ResultNested);
			
		Else
			
			If Find(FilterSettings.Key, "_Key") > 0 Then
				
				strKey = StrReplace(FilterSettings.Key, "_Key", "");
				
				Try
					If IsBlankString(FilterSettings.Value) Then
						Value = Undefined;
					Else
						Value = ValueFromStringInternal(FilterSettings.Value);
					EndIf;
				Except
					Value = Undefined;
				EndTry;
				
				Result.Insert(strKey, Value);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// primitive types
	For Each FilterSettings IN ExternalConnectionSettingsStructure Do
		
		If TypeOf(FilterSettings.Value) = Type("Structure") Then
			
			ResultNested = Result[FilterSettings.Key];
			
			If ResultNested = Undefined Then
				
				ResultNested = New Structure;
				
			EndIf;
			
			For Each Item IN FilterSettings.Value Do
				
				If Find(Item.Key, "_Key") <> 0 Then
					
					Continue;
					
				ElsIf FilterSettings.Value.Property(Item.Key + "_Key") Then
					
					Continue;
					
				EndIf;
				
				Array = New Array;
				
				For Each ArrayElement IN Item.Value Do
					
					Array.Add(ArrayElement);
					
				EndDo;
				
				ResultNested.Insert(Item.Key, Array);
				
			EndDo;
			
		Else
			
			If Find(FilterSettings.Key, "_Key") <> 0 Then
				
				Continue;
				
			ElsIf ExternalConnectionSettingsStructure.Property(FilterSettings.Key + "_Key") Then
				
				Continue;
				
			EndIf;
			
			// Shield the enumeration
			If TypeOf(FilterSettings.Value) = Type("String")
				AND (     Find(FilterSettings.Value, "Enum.") <> 0
					OR Find(FilterSettings.Value, "Enumeration.") <> 0
				) Then
				
				Result.Insert(FilterSettings.Key, PredefinedValue(FilterSettings.Value));
				
			Else
				
				Result.Insert(FilterSettings.Key, FilterSettings.Value);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// For an internal use.
// 
Function DataForThisInfobaseNodeTabularSections(Val ExchangePlanName, CorrespondentVersion = "") Export
	
	Result = New Structure;
	
	NodeCommonTables = DataExchangeReUse.ExchangePlanTabularSections(ExchangePlanName, CorrespondentVersion)["AllInfobaseTables"];
	
	For Each TabularSectionName IN NodeCommonTables Do
		
		TabularSectionData = New ValueTable;
		TabularSectionData.Columns.Add("Presentation",                 New TypeDescription("String"));
		TabularSectionData.Columns.Add("RefUUID", New TypeDescription("String"));
		
		QueryText =
		"SELECT TOP 1000
		|	Table.Ref AS Ref,
		|	Table.Presentation AS Presentation
		|FROM
		|	[TableName] AS Table
		|
		|WHERE
		|	Not Table.DeletionMark
		|
		|ORDER BY
		|	Table.Presentation";
		
		TableName = TableNameFromExchangePlanTabularSectionFirstAttribute(ExchangePlanName, TabularSectionName);
		
		QueryText = StrReplace(QueryText, "[TableName]", TableName);
		
		Query = New Query;
		Query.Text = QueryText;
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			TableRow = TabularSectionData.Add();
			TableRow.Presentation = Selection.Presentation;
			TableRow.RefUUID = String(Selection.Ref.UUID());
			
		EndDo;
		
		Result.Insert(TabularSectionName, TabularSectionData);
		
	EndDo;
	
	Return Result;
EndFunction

// For an internal use.
// 
Function CorrespondentNodeCommonData(Val ExchangePlanName, Val ConnectionParameters, Cancel)
	
	If ConnectionParameters.ConnectionType = "ExternalConnection" Then
		
		Connection = DataExchangeReUse.InstallOuterDatabaseJoin(ConnectionParameters);
		ErrorMessageString = Connection.DetailedErrorDescription;
		ExternalConnection       = Connection.Join;
		
		If ExternalConnection = Undefined Then
			CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return Undefined;
		EndIf;
		
		If ConnectionParameters.CorrespondentVersion_2_1_1_7
			OR ConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			Return CommonUse.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetCommonNodeData_2_0_1_6(ExchangePlanName));
			
		Else
			
			Return ValueFromStringInternal(ExternalConnection.DataExchangeExternalConnection.GetCommonNodeData(ExchangePlanName));
			
		EndIf;
		
	ElsIf ConnectionParameters.ConnectionType = "WebService" Then
		
		ErrorMessageString = "";
		
		If ConnectionParameters.CorrespondentVersion_2_1_1_7 Then
			
			WSProxy = GetWSProxy_2_1_1_7(ConnectionParameters, ErrorMessageString);
			
		ElsIf ConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			WSProxy = GetWSProxy_2_0_1_6(ConnectionParameters, ErrorMessageString);
			
		Else
			
			WSProxy = GetWSProxy(ConnectionParameters, ErrorMessageString);
			
		EndIf;
		
		If WSProxy = Undefined Then
			CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return Undefined;
		EndIf;
		
		If ConnectionParameters.CorrespondentVersion_2_1_1_7
			OR ConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			Return XDTOSerializer.ReadXDTO(WSProxy.GetCommonNodeData(ExchangePlanName));
		Else
			
			Return ValueFromStringInternal(WSProxy.GetCommonNodeData(ExchangePlanName));
		EndIf;
		
	ElsIf ConnectionParameters.ConnectionType = "TempStorage" Then
		
		Return GetFromTempStorage(ConnectionParameters.TemporaryStorageAddress).Get();
		
	EndIf;
	
	Return Undefined;
EndFunction

// For an internal use.
// 
Function TableNameFromExchangePlanTabularSectionFirstAttribute(Val ExchangePlanName, Val TabularSectionName)
	
	TabularSection = Metadata.ExchangePlans[ExchangePlanName].TabularSections[TabularSectionName];
	
	For Each Attribute IN TabularSection.Attributes Do
		
		Type = Attribute.Type.Types()[0];
		
		If CommonUse.IsReference(Type) Then
			
			Return Metadata.FindByType(Type).FullName();
			
		EndIf;
		
	EndDo;
	
	Return "";
EndFunction

// For an internal use.
// 
Function ExchangePlanCatalogs(Val ExchangePlanName)
	
	If TypeOf(ExchangePlanName) <> Type("String") Then
		
		ExchangePlanName = DataExchangeReUse.GetExchangePlanName(ExchangePlanName);
		
	EndIf;
	
	Result = New Array;
	
	ExchangePlanContent = Metadata.ExchangePlans[ExchangePlanName].Content;
	
	For Each Item IN ExchangePlanContent Do
		
		If CommonUse.ThisIsCatalog(Item.Metadata)
			OR CommonUse.ThisIsChartOfCharacteristicTypes(Item.Metadata) Then
			
			Result.Add(Item.Metadata);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// For an internal use.
// 
Function AllExchangePlanDataExceptCatalogs(Val ExchangePlanName)
	
	If TypeOf(ExchangePlanName) <> Type("String") Then
		
		ExchangePlanName = DataExchangeReUse.GetExchangePlanName(ExchangePlanName);
		
	EndIf;
	
	Result = New Array;
	
	ExchangePlanContent = Metadata.ExchangePlans[ExchangePlanName].Content;
	
	For Each Item IN ExchangePlanContent Do
		
		If Not (CommonUse.ThisIsCatalog(Item.Metadata)
			OR CommonUse.ThisIsChartOfCharacteristicTypes(Item.Metadata)) Then
			
			Result.Add(Item.Metadata);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// For an internal use.
// 
Function SystemAccountingSettingsAreSet(Val ExchangePlanName, Val Correspondent, ErrorInfo) Export
	
	If TypeOf(Correspondent) = Type("String") Then
		
		If IsBlankString(Correspondent) Then
			Return False;
		EndIf;
		
		CorrespondentCode = Correspondent;
		
		Correspondent = ExchangePlans[ExchangePlanName].FindByCode(Correspondent);
		
		If Not ValueIsFilled(Correspondent) Then
			Message = NStr("en='Exchange plan node is not found; exchange plan name %1; node code %2';ru='Не найден узел плана обмена; имя плана обмена %1; код узла %2'");
			Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ExchangePlanName, CorrespondentCode);
			Raise Message;
		EndIf;
		
	EndIf;
	
	Cancel = False;
	
	SetPrivilegedMode(True);
	ExchangePlans[ExchangePlanName].AccountingSettingsCheckHandler(Cancel, Correspondent, ErrorInfo);
	
	Return Not Cancel;
EndFunction

// For an internal use.
// 
Function GetInfobaseParameters(Val ExchangePlanName, Val NodeCode, ErrorInfo) Export
	
	Return ValueToStringInternal(InfobaseParameters(ExchangePlanName, NodeCode, ErrorInfo));
	
EndFunction

// For an internal use.
// 
Function GetInfobaseParameters_2_0_1_6(Val ExchangePlanName, Val NodeCode, ErrorInfo) Export
	
	Return CommonUse.ValueToXMLString(InfobaseParameters(ExchangePlanName, NodeCode, ErrorInfo));
	
EndFunction

// For an internal use.
// 
Function MetadataObjectProperties(Val FullTableName) Export
	
	Result = New Structure("Synonym, Hierarchical");
	
	MetadataObject = Metadata.FindByFullName(FullTableName);
	
	FillPropertyValues(Result, MetadataObject);
	
	Return Result;
EndFunction

// For an internal use.
// 
Function GetTableObjects(Val FullTableName) Export
	SetPrivilegedMode(True);
	
	MetadataObject = Metadata.FindByFullName(FullTableName);
	
	If CommonUse.ThisIsCatalog(MetadataObject) Then
		
		If MetadataObject.Hierarchical Then
			If MetadataObject.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
				Return HierarchyCatalogItemsFoldersAndItemsHierarchy(FullTableName);
			EndIf;
			
			Return HierarchicalCatalogHierarchyOfItemsItems(FullTableName);
		EndIf;
		
		Return NonHierarchicalCatalogItems(FullTableName);
		
	ElsIf CommonUse.ThisIsChartOfCharacteristicTypes(MetadataObject) Then
		
		If MetadataObject.Hierarchical Then
			Return HierarchyCatalogItemsFoldersAndItemsHierarchy(FullTableName);
		EndIf;
		
		Return NonHierarchicalCatalogItems(FullTableName);
		
	EndIf;
	
	Return Undefined;
EndFunction

// Only for internal use.
//
Function HierarchyCatalogItemsFoldersAndItemsHierarchy(Val FullTableName)
	
	Query = New Query("
		|SELECT TOP 2000
		|	Ref,
		|	Presentation,
		|	CASE
		|		WHEN    IsFolder AND Not DeletionMark THEN 0
		|		WHEN    IsFolder AND    DeletionMark THEN 1
		|		WHEN Not IsFolder AND Not DeletionMark THEN 2
		|		WHEN Not IsFolder AND    DeletionMark THEN 3
		|	END AS PictureIndex
		|FROM
		|	" + FullTableName + "
		|ORDER
		|	BY IsFolder
		|	HIERARCHY, Name
		|");
		
	Return QueryResultVXMLTree(Query);
EndFunction

// Only for internal use.
//
Function HierarchicalCatalogHierarchyOfItemsItems(Val FullTableName)
	
	Query = New Query("
		|SELECT TOP 2000
		|	Ref,
		|	Presentation,
		|	CASE
		|		WHEN DeletionMark THEN 3
		|		ELSE 2
		|	END AS PictureIndex
		|FROM
		|	" + FullTableName + "
		|ORDER
		|	BY Name HIERARCHY
		|");
		
	Return QueryResultVXMLTree(Query);
EndFunction

// Only for internal use.
//
Function NonHierarchicalCatalogItems(Val FullTableName)
	
	Query = New Query("
		|SELECT TOP 2000
		|	Ref,
		|	Presentation,
		|	CASE
		|		WHEN DeletionMark THEN 3
		|		ELSE 2
		|	END AS PictureIndex
		|FROM
		|	" + FullTableName + " 
		|ORDER
		|	BY Name
		|");
		
	Return QueryResultVXMLTree(Query);
EndFunction

// Only for internal use.
//
Function QueryResultVXMLTree(Val Query)
	Result = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	
	Result.Columns.Add("ID", New TypeDescription("String"));
	FillInLinkIdentifiersInTree(Result.Rows);
	Result.Columns.Delete("Ref");
	
	Return CommonUse.ValueToXMLString(Result);
EndFunction

// Only for internal use.
//
Procedure FillInLinkIdentifiersInTree(TreeRows)
	
	For Each String IN TreeRows Do
		String.ID = ValueToStringInternal(String.Ref);
		FillInLinkIdentifiersInTree(String.Rows);
	EndDo;
	
EndProcedure

// For an internal use.
// 
Function CorrespondentData(Val FullTableName) Export
	
	Result = New Structure("MetadataObjectProperties, CorrespondentBaseTable");
	
	Result.MetadataObjectProperties = MetadataObjectProperties(FullTableName);
	Result.CorrespondentInfobaseTable = GetTableObjects(FullTableName);
	
	Return Result;
EndFunction

// For an internal use.
// 
Function CorrespondentTablesData(Tables, Val ExchangePlanName) Export
	
	Result = New Map;
	ExchangePlanAttributes = Metadata.ExchangePlans[ExchangePlanName].Attributes;
	
	For Each Item IN Tables Do
		
		Attribute = ExchangePlanAttributes.Find(Item);
		
		If Attribute <> Undefined Then
			
			TypesAttribute = Attribute.Type.Types();
			
			If TypesAttribute.Count() <> 1 Then
				
				MessageString = NStr("en='Compound data type is not supported by default values.
		|Attribute %1.';ru='Составной тип данных для значений по умолчанию не поддерживается.
		|Реквизит ""%1"".'");
				MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, Attribute.FullName());
				Raise MessageString;
			EndIf;
			
			MetadataObject = Metadata.FindByType(TypesAttribute.Get(0));
			
			If Not CommonUse.ThisIsCatalog(MetadataObject) Then
				
				MessageString = NStr("en='Default values selection is supported only for catalogs.
		|Attribute %1.';ru='Выбор значений по умолчанию поддерживается только для справочников.
		|Реквизит ""%1"".'");
				MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, Attribute.FullName());
				Raise MessageString;
			EndIf;
			
			FullMetadataObjectName = MetadataObject.FullName();
			
			TableData = New Structure("MetadataObjectProperties, CorrespondentBaseTable");
			TableData.MetadataObjectProperties = MetadataObjectProperties(FullMetadataObjectName);
			TableData.CorrespondentInfobaseTable = GetTableObjects(FullMetadataObjectName);
			
			Result.Insert(FullMetadataObjectName, TableData);
			
		EndIf;
		
	EndDo;
	
	AdditionalInformation = New Structure;
	
	// {Handler: GetAdditionalDataForCorrespondent} Start
	ExchangePlans[ExchangePlanName].GetMoreDataForCorrespondent(AdditionalInformation);
	// {Handler: GetAdditionalDataForCorrespondent} End
	
	Result.Insert("{AdditionalData}", AdditionalInformation);
	
	Return Result;
	
EndFunction

// For an internal use.
// 
Function InfobaseParameters(Val ExchangePlanName, Val NodeCode, ErrorInfo) Export
	
	SetPrivilegedMode(True);
	
	Result = New Structure;
	
	Result.Insert("ExchangePlanExists");
	Result.Insert("InfobasePrefix");
	Result.Insert("InfobasePrefixByDefault");
	Result.Insert("InfobaseDescription");
	Result.Insert("DefaultInfobaseDescription");
	Result.Insert("SystemAccountingSettingsAreSet");
	Result.Insert("ThisNodeCode");
	Result.Insert("ConfigurationVersion"); // Beginning with SSL 2 version.1.5.1.
	
	Result.ExchangePlanExists = (Metadata.ExchangePlans.Find(ExchangePlanName) <> Undefined);
	
	If Result.ExchangePlanExists Then
		
		ThisNodeProperties = CommonUse.ObjectAttributesValues(ExchangePlans[ExchangePlanName].ThisNode(), "Code, description");
		
		InfobasePrefix = Undefined;
		InfobasePrefix = DataExchangeOverridable.InfobasePrefixByDefault();
		DataExchangeOverridable.OnDefineDefaultInfobasePrefix(InfobasePrefix);
		
		Result.InfobasePrefix                 = GetFunctionalOption("InfobasePrefix");
		Result.InfobasePrefixByDefault      = InfobasePrefix;
		Result.InfobaseDescription            = ThisNodeProperties.Description;
		Result.DefaultInfobaseDescription = ThisNodeDefaultDescription();
		Result.SystemAccountingSettingsAreSet            = SystemAccountingSettingsAreSet(ExchangePlanName, NodeCode, ErrorInfo);
		Result.ThisNodeCode                              = ThisNodeProperties.Code;
		Result.ConfigurationVersion                        = Metadata.Version;
	Else
		
		Result.InfobasePrefix = "";
		Result.InfobasePrefixByDefault = "";
		Result.InfobaseDescription = "";
		Result.DefaultInfobaseDescription = "";
		Result.SystemAccountingSettingsAreSet = False;
		Result.ThisNodeCode = "";
		Result.ConfigurationVersion = Metadata.Version;
	EndIf;
	
	Return Result;
EndFunction

// For an internal use.
// 
Function GetTreeOfInformationStatistics(StatisticsInformation, Val EnableObjectsRemoval = False) Export
	
	FilterArray = StatisticsInformation.UnloadColumn("ReceiverTableName");
	
	FilterRow = StringFunctionsClientServer.RowFromArraySubrows(FilterArray);
	
	Filter = New Structure("FullName", FilterRow);
	
	// Receive the tree of configuration metadata objects.
	StatisticsInformationTree = DataExchangeReUse.GetConfigurationMetadataTree(Filter).Copy();
	
	// Add columns
	StatisticsInformationTree.Columns.Add("Key");
	StatisticsInformationTree.Columns.Add("ObjectsCountInSource");
	StatisticsInformationTree.Columns.Add("ObjectsCountInReceiver");
	StatisticsInformationTree.Columns.Add("UnmappedObjectsCount");
	StatisticsInformationTree.Columns.Add("ObjectsMappingPercent");
	StatisticsInformationTree.Columns.Add("PictureIndex");
	StatisticsInformationTree.Columns.Add("UsePreview");
	StatisticsInformationTree.Columns.Add("ReceiverTableName");
	StatisticsInformationTree.Columns.Add("ObjectTypeAsString");
	StatisticsInformationTree.Columns.Add("TableFields");
	StatisticsInformationTree.Columns.Add("SearchFields");
	StatisticsInformationTree.Columns.Add("SourceTypeAsString");
	StatisticsInformationTree.Columns.Add("ReceiverTypeAsString");
	StatisticsInformationTree.Columns.Add("ThisIsObjectDeletion");
	StatisticsInformationTree.Columns.Add("DataSuccessfullyImported");
	
	
	// Indexes for search in statistics.
	Indexes = StatisticsInformation.Indexes;
	If Indexes.Count() = 0 Then
		If EnableObjectsRemoval Then
			Indexes.Add("ThisIsObjectDeletion");
			Indexes.Add("OneToMany, IsObjectDeletion");
			Indexes.Add("IsClassifier, IsObjectRemoval");
		Else
			Indexes.Add("OneToMany");
			Indexes.Add("IsClassifier");
		EndIf;
	EndIf;
	
	RowsProcessed = New Map;
	
	// Usual rows
	Filter = New Structure("OneToMany", False);
	If Not EnableObjectsRemoval Then
		Filter.Insert("ThisIsObjectDeletion", False);
	EndIf;
		
	For Each TableRow IN StatisticsInformation.FindRows(Filter) Do
		TreeRow = StatisticsInformationTree.Rows.Find(TableRow.ReceiverTableName, "FullName", True);
		FillPropertyValues(TreeRow, TableRow);
		
		TreeRow.Synonym = StatisticsInformationTreeRowDataSynonym(TreeRow, TableRow.SourceTypeAsString);
		
		RowsProcessed[TableRow] = True;
	EndDo;
	
	// Add rows with the OneToMany type.
	Filter = New Structure("OneToMany", True);
	If Not EnableObjectsRemoval Then
		Filter.Insert("ThisIsObjectDeletion", False);
	EndIf;
	FillTreeOfInformationStatisticsOneToMany(StatisticsInformationTree, StatisticsInformation, Filter, RowsProcessed);
	
	// Add rows of classifiers.
	Filter = New Structure("IsClassifier", True);
	If Not EnableObjectsRemoval Then
		Filter.Insert("ThisIsObjectDeletion", False);
	EndIf;
	FillTreeOfInformationStatisticsOneToMany(StatisticsInformationTree, StatisticsInformation, Filter, RowsProcessed);
	
	// Add rows of the objects removal.
	If EnableObjectsRemoval Then
		Filter = New Structure("ThisIsObjectDeletion", True);
		FillTreeOfInformationStatisticsOneToMany(StatisticsInformationTree, StatisticsInformation, Filter, RowsProcessed);
	EndIf;
	
	// Clear empty rows
	StatisticsRows = StatisticsInformationTree.Rows;
	GroupPosition = StatisticsRows.Count() - 1;
	While GroupPosition >=0 Do
		Group = StatisticsRows[GroupPosition];
		
		Items = Group.Rows;
		Position = Items.Count() - 1;
		While Position >=0 Do
			Item = Items[Position];
			
			If Item.ObjectsCountInReceiver = Undefined 
				AND Item.ObjectsCountInSource = Undefined
				AND Item.Rows.Count() = 0
			Then
				Items.Delete(Item);
			EndIf;
			
			Position = Position - 1;
		EndDo;
		
		If Items.Count() = 0 Then
			StatisticsRows.Delete(Group);
		EndIf;
		GroupPosition = GroupPosition - 1;
	EndDo;
	
	Return StatisticsInformationTree;
EndFunction

// For an internal use.
// 
Procedure FillTreeOfInformationStatisticsOneToMany(StatisticsInformationTree, StatisticsInformation, Filter, AlreadyProcessedRows)
	
	RowsForProcessor = StatisticsInformation.FindRows(Filter);
	
	// Ignore the source rows that have already been processed.
	Position = RowsForProcessor.UBound();
	While Position >= 0 Do
		Candidate = RowsForProcessor[Position];
		
		If AlreadyProcessedRows[Candidate] <> Undefined Then
			RowsForProcessor.Delete(Position);
		Else
			AlreadyProcessedRows[Candidate] = True;
		EndIf;
		
		Position = Position - 1;
	EndDo;
		
	If RowsForProcessor.Count() = 0 Then
		Return;
	EndIf;
	
	StatisticsOneToMany = StatisticsInformation.Copy(RowsForProcessor);
	StatisticsOneToMany.Indexes.Add("ReceiverTableName");
	
	StatisticsOneToManyTemporary = StatisticsOneToMany.Copy(RowsForProcessor, "ReceiverTableName");
	
	StatisticsOneToManyTemporary.GroupBy("ReceiverTableName");
	
	For Each TableRow IN StatisticsOneToManyTemporary Do
		Rows       = StatisticsOneToMany.FindRows(New Structure("ReceiverTableName", TableRow.ReceiverTableName));
		TreeRow = StatisticsInformationTree.Rows.Find(TableRow.ReceiverTableName, "FullName", True);
		
		For Each String IN Rows Do
			NewRowOfTree = TreeRow.Rows.Add();
			FillPropertyValues(NewRowOfTree, TreeRow);
			FillPropertyValues(NewRowOfTree, String);
			
			If String.ThisIsObjectDeletion Then
				NewRowOfTree.Picture = PictureLib.MarkToDelete;
			Else
				NewRowOfTree.Synonym = StatisticsInformationTreeRowDataSynonym(NewRowOfTree, String.SourceTypeAsString) ;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

// For an internal use.
// 
Function DeleteClassNameFromObjectName(Val Result)
	
	Result = StrReplace(Result, "DocumentRef.", "");
	Result = StrReplace(Result, "CatalogRef.", "");
	Result = StrReplace(Result, "ChartOfCharacteristicTypesRef.", "");
	Result = StrReplace(Result, "ChartOfAccountsRef.", "");
	Result = StrReplace(Result, "ChartOfCalculationTypesRef.", "");
	Result = StrReplace(Result, "BusinessProcessRef.", "");
	Result = StrReplace(Result, "TaskRef.", "");
	
	Return Result;
EndFunction

// Adds parameters of the client logic work for the data exchange subsystem.
//
Procedure AddClientWorkParameters(Parameters) Export
	
	SetPrivilegedMode(True);
	
	Parameters.Insert("MasterNode", MasterNode());
	
EndProcedure

// For an internal use.
// 
Procedure ExecuteCheckupOfExchangeRulesImportedFromFilePresence(ImportedFromFileExchangeRules, ImportedFromFileRecordRules)
	
	QueryText = "SELECT DISTINCT
	|	DataExchangeRules.ExchangePlanName AS ExchangePlanName,
	|	DataExchangeRules.RuleKind AS RuleKind
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesSource = VALUE(Enum.RuleSourcesForDataExchange.File)
	|	AND DataExchangeRules.RulesImported";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		ExchangePlansArray = New Array;
		
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			If Selection.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules Then
				
				ImportedFromFileExchangeRules.Add(Selection.ExchangePlanName);
				
			ElsIf Selection.RuleKind = Enums.DataExchangeRuleKinds.ObjectRegistrationRules Then
				
				ImportedFromFileRecordRules.Add(Selection.ExchangePlanName);
				
			EndIf;
			
			If ExchangePlansArray.Find(Selection.ExchangePlanName) = Undefined Then
				
				ExchangePlansArray.Add(Selection.ExchangePlanName);
				
			EndIf;
			
		EndDo;
		
		MessageString = NStr("en='For %1 exchange plans the exchange rules imported from file are used.
		|These rules can be incompatible with the new application version.
		|To prevent the possible error occurance when working with the application it is recommended to actualize the exchange rules from the file.';ru='Для планов обмена %1 используются правила обмена, загруженные из файла.
		|Эти правила могут быть несовместимы с новой версией программы.
		|Для предупреждения возможного возникновения ошибок при работе с программой рекомендуется актуализировать правила обмена из файла.'",
				CommonUseClientServer.MainLanguageCode());
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, StringFunctionsClientServer.RowFromArraySubrows(ExchangePlansArray));
		
		WriteLogEvent(InfobaseUpdate.EventLogMonitorEvent(), EventLogLevel.Error,,, MessageString);
		
	EndIf;
	
EndProcedure

// Checks the connection of transport processor by the specified settings.
//
Procedure CheckConnectionOfExchangeMessagesTransportDataProcessor(Cancel, SettingsStructure, TransportKind, ErrorInfo = "") Export
	
	SetPrivilegedMode(True);
	
	// Create the processor object instance.
	DataProcessorObject = DataProcessors[DataProcessorNameOfExchangeMessagesTransport(TransportKind)].Create();
	
	// Initialize processor properties with the passed settings parameters.
	FillPropertyValues(DataProcessorObject, SettingsStructure);
	
	// Initialization of the exchange transport.
	DataProcessorObject.Initialization();
	
	// Check connection.
	If Not DataProcessorObject.ConnectionIsDone() Then
		
		MessagePattern = "%1 %2";
		//
		
		AdditionalMessage = NStr("en='See technical information on the error in the event log.';ru='Техническую информацию об ошибке см. в журнале регистрации.'");
		
		ErrorInfo = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataProcessorObject.ErrorMessageString, AdditionalMessage);
		
		CommonUseClientServer.MessageToUser(ErrorInfo,,,, Cancel);
		
		WriteLogEvent(NStr("en='Exchange message transport';ru='Транспорт сообщений обмена'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,, DataProcessorObject.ErrorMessageStringEL);
		
	EndIf;
	
EndProcedure

// Outdated. IN the future it is required to use SetExternalConnectionWithBase.
//
Function EstablishExternalConnection(SettingsStructure, ErrorMessageString = "", ErrorAttachingAddIn = False) Export

	Result = InstallOuterDatabaseJoin(SettingsStructure);
	
	ErrorAttachingAddIn = Result.ErrorAttachingAddIn;
	ErrorMessageString     = Result.DetailedErrorDescription;

	Return Result.Join;
EndFunction

// Main function for using external connection during exchange. For an internal use.
//
// Parameters: 
//     SettingsStructure - structure of the transport settings of COM exchange.
//
Function InstallOuterDatabaseJoin(SettingsStructure) Export
	
	Result = CommonUseClientServer.InstallOuterDatabaseJoin(
		FillExternalConnectionParameters(SettingsStructure));
	
	ExternalConnection = Result.Join;
	If ExternalConnection = Undefined Then
		// An error occurred while connecting.
		Return Result;
	EndIf;
	
	// Additionally check whether it is possib;e to work with external base.
	
	Try
		NoFullRights = Not ExternalConnection.DataExchangeExternalConnection.IsInRoleFullAccess();
	Except
		NoFullRights = True;
	EndTry;
	
	If NoFullRights Then
		Result.DetailedErrorDescription = NStr("en='User specified for connection to another application should have been assigned roles ""System administrator"" and ""Full rights""';ru='Пользователю, указанному для подключения к другой программе, должны быть назначены роли ""Администратор системы"" и ""Полные права""'");
		Result.ErrorShortInfo   = Result.DetailedErrorDescription;
		Result.Join = Undefined;
	Else
		Try 
			StateUnacceptable = ExternalConnection.InfobaseUpdate.InfobaseUpdateRequired();
		Except
			StateUnacceptable = False
		EndTry;
		
		If StateUnacceptable Then
			Result.DetailedErrorDescription = NStr("en='Another application is being updated.';ru='Другая программа находится в состоянии обновления.'");
			Result.ErrorShortInfo   = Result.DetailedErrorDescription;
			Result.Join = Undefined;
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

Function TransportSettingsByExternalConnectionParameters(Parameters) Export
	
	// Convert settings - parameters of external connection to transport parameters.
	TransportSettings = 
		TransportSetting(Parameters, "COMInfobaseOperationMode",             "InfobaseOperationMode",
		TransportSetting(Parameters, "COMInfobaseDirectory",                   "InfobaseDirectory",
		TransportSetting(Parameters, "COMServerName1CEnterprise",                     "PlatformServerName",
		TransportSetting(Parameters, "COMInfobaseNameAtServer1CEnterprise", "InfobaseNameAtPlatformServer",
		TransportSetting(Parameters, "COMAuthenticationOS",           "OSAuthentication",
		TransportSetting(Parameters, "COMUserName",                             "UserName",
		TransportSetting(Parameters, "COMUserPassword",                          "UserPassword",
	)))))));
	
	Return TransportSettings;
EndFunction

// Helper
Function TransportSetting(Val ConnectionParameters, Val TransportParameterName, Val ConnectionParameterName, Val InitialSetting = Undefined)
	Result = ?(InitialSetting = Undefined, New Structure, InitialSetting);
	
	ParameterValue = Undefined;
	ConnectionParameters.Property(ConnectionParameterName, ParameterValue);
	Result.Insert(TransportParameterName, ParameterValue);
	
	Return Result;
EndFunction

// For an internal use.
// 
Function GetWSProxyByConnectionParameters(
					SettingsStructure,
					ErrorMessageString = "",
					UserMessage = "",
					MakeTestCall = False
	) Export
	
	Try
		DataExchangeClientServer.CheckInadmissibleSymbolsInUserNameWSProxy(SettingsStructure.WSUserName);
	Except
		UserMessage = BriefErrorDescription(ErrorInfo());
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(EventLogMonitorMessageTextEstablishingConnectionToWebService(), EventLogLevel.Error,,, ErrorMessageString);
		Return Undefined;
	EndTry;
	
	WSDLLocation = "[WebServiceURL]/ws/[ServiceName]?wsdl";
	WSDLLocation = StrReplace(WSDLLocation, "[WebServiceURL]", SettingsStructure.WSURLWebService);
	WSDLLocation = StrReplace(WSDLLocation, "[ServiceName]",    SettingsStructure.WSServiceName);
	
	Try
		WSProxy = CommonUse.WSProxy(
			WSDLLocation,
			SettingsStructure.NamespaceWebServiceURL,
			SettingsStructure.WSServiceName,
			,
			SettingsStructure.WSUserName,
			SettingsStructure.WSPassword,
			SettingsStructure.WSTimeout,
			MakeTestCall);
	Except
		UserMessage = BriefErrorDescription(ErrorInfo());
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(EventLogMonitorMessageTextEstablishingConnectionToWebService(), EventLogLevel.Error,,, ErrorMessageString);
		Return Undefined;
	EndTry;
	
	Return WSProxy;
EndFunction

// For an internal use.
// 
Function WSParameterStructure() Export
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("WSURLWebService");
	ParametersStructure.Insert("WSUserName");
	ParametersStructure.Insert("WSPassword");
	
	Return ParametersStructure;
EndFunction

// For an internal use.
// 
Function GetWSProxy(SettingsStructure, ErrorMessageString = "", UserMessage = "") Export
	
	DeleteProhibitedSymbolsInConnectionSettings(SettingsStructure);
	
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SSL/Exchange");
	SettingsStructure.Insert("WSServiceName",                 "Exchange");
	SettingsStructure.Insert("WSTimeout", 600);
	
	Return GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString, UserMessage);
EndFunction

// For an internal use.
// 
Function GetWSProxy_2_0_1_6(SettingsStructure, ErrorMessageString = "", UserMessage = "") Export
	
	DeleteProhibitedSymbolsInConnectionSettings(SettingsStructure);
	
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SSL/Exchange_2_0_1_6");
	SettingsStructure.Insert("WSServiceName",                 "Exchange_2_0_1_6");
	SettingsStructure.Insert("WSTimeout", 600);
	
	Return GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString, UserMessage);
EndFunction

// For an internal use.
// 
Function GetWSProxy_2_1_1_7(SettingsStructure, ErrorMessageString = "", UserMessage = "", Timeout = 600) Export
	
	DeleteProhibitedSymbolsInConnectionSettings(SettingsStructure);
	
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SSL/Exchange_2_0_1_6");
	SettingsStructure.Insert("WSServiceName",                 "Exchange_2_0_1_6");
	SettingsStructure.Insert("WSTimeout", Timeout);
	
	Return GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString, UserMessage, True);
EndFunction

// For an internal use.
// 
Function GetWSProxyForInfobaseNode(InfobaseNode, ErrorMessageString = "", AuthenticationParameters = Undefined)
	
	SettingsStructure = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(InfobaseNode, AuthenticationParameters);
	
	Try
		CorrespondentVersions = DataExchangeReUse.CorrespondentVersions(SettingsStructure);
	Except
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(EventLogMonitorMessageTextEstablishingConnectionToWebService(),
			EventLogLevel.Error,,, ErrorMessageString);
		Return Undefined;
	EndTry;
	
	CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	CorrespondentVersion_2_1_1_7 = (CorrespondentVersions.Find("2.1.1.7") <> Undefined);
	
	If CorrespondentVersion_2_1_1_7 Then
		
		WSProxy = GetWSProxy_2_1_1_7(SettingsStructure, ErrorMessageString);
		
	ElsIf CorrespondentVersion_2_0_1_6 Then
		
		WSProxy = GetWSProxy_2_0_1_6(SettingsStructure, ErrorMessageString);
		
	Else
		
		WSProxy = GetWSProxy(SettingsStructure, ErrorMessageString);
		
	EndIf;
	
	Return WSProxy;
EndFunction

// For an internal use.
// 
Procedure DeleteProhibitedSymbolsInConnectionSettings(Settings)
	
	For Each Setting IN Settings Do
		
		If TypeOf(Setting.Value) = Type("String") Then
			
			Settings.Insert(Setting.Key, TrimAll(Setting.Value));
			
		EndIf;
		
	EndDo;
	
EndProcedure

// For an internal use.
// 
Function CheckConnectionWSProxy(SettingsStructure, ErrorMessageString = "", UserMessage = "") Export
	
	CorrespondentVersions = DataExchangeReUse.CorrespondentVersions(SettingsStructure);
	
	CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	CorrespondentVersion_2_1_1_7 = (CorrespondentVersions.Find("2.1.1.7") <> Undefined);
	
	If CorrespondentVersion_2_1_1_7 Then
		
		WSProxy = GetWSProxy_2_1_1_7(SettingsStructure, ErrorMessageString, UserMessage);
		
	ElsIf CorrespondentVersion_2_0_1_6 Then
		
		WSProxy = GetWSProxy_2_0_1_6(SettingsStructure, ErrorMessageString, UserMessage);
		
	Else
		
		WSProxy = GetWSProxy(SettingsStructure, ErrorMessageString, UserMessage);
		
	EndIf;
	
	Return WSProxy;
EndFunction

// For an internal use.
// 
Function IsConnectionToCorrespondent(Val Correspondent, Val SettingsStructure, UserMessage = "") Export
	
	EventLogMonitorEvent = NStr("en='Data exchange.Connection check';ru='Обмен данными.Проверка подключения'", CommonUseClientServer.MainLanguageCode());
	
	Try
		CorrespondentVersions = DataExchangeReUse.CorrespondentVersions(SettingsStructure);
	Except
		DropPasswordSynchronizationData(Correspondent);
		WriteLogEvent(EventLogMonitorEvent,
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		UserMessage = ShortPresentationOfFirstErrors(ErrorInfo());
		Return False;
	EndTry;
	
	CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	CorrespondentVersion_2_1_1_7 = (CorrespondentVersions.Find("2.1.1.7") <> Undefined);
	
	If CorrespondentVersion_2_1_1_7 Then
		
		WSProxy = GetWSProxy_2_1_1_7(SettingsStructure,, UserMessage, 5);
		
		If WSProxy = Undefined Then
			DropPasswordSynchronizationData(Correspondent);
			Return False;
		EndIf;
		
		Try
			
			IsConnection = WSProxy.CheckConnection(
				DataExchangeReUse.GetExchangePlanName(Correspondent),
				CommonUse.ObjectAttributeValue(DataExchangeReUse.GetThisNodeOfExchangePlanByRef(Correspondent), "Code"),
				UserMessage);
			
			If IsConnection Then
				SetPasswordSynchronizationData(Correspondent, SettingsStructure.WSPassword);
			EndIf;
			
			Return IsConnection;
		Except
			DropPasswordSynchronizationData(Correspondent);
			WriteLogEvent(EventLogMonitorEvent,
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			UserMessage = ShortPresentationOfFirstErrors(ErrorInfo());
			Return False;
		EndTry;
		
	ElsIf CorrespondentVersion_2_0_1_6 Then
		
		WSProxy = GetWSProxy_2_0_1_6(SettingsStructure,, UserMessage);
		
	Else
		
		WSProxy = GetWSProxy(SettingsStructure,, UserMessage);
		
	EndIf;
	
	IsConnection = (WSProxy <> Undefined);
	
	If IsConnection Then
		SetPasswordSynchronizationData(Correspondent, SettingsStructure.WSPassword);
	Else
		DropPasswordSynchronizationData(Correspondent);
	EndIf;
	
	Return IsConnection;
EndFunction

// Displays error message and displays the Denial parameter to "True".
//
// Parameters:
//  MessageText - a string, message text.
//  Cancel          - Boolean, shows that it was denied (optional).
//
Procedure ShowMessageAboutError(MessageText, Cancel = False) Export
	
	Cancel = True;
	
	CommonUseClientServer.MessageToUser(MessageText);
	
EndProcedure

// It receives the table of object selective recording rules from the session parameters.
// 
// Parameters:
// No.
// 
// Returns:
// Values table - recording attribute table for all metadata objects.
//
Function GetSelectiveObjectRegistrationRulesSP() Export
	
	Return DataExchangeReUse.GetSelectiveObjectRegistrationRulesSP();
	
EndFunction

// Adds one record to the information register by the passed values of the structure.
//
// Parameters:
//  RecordStructure - Structure - structure by the values of which it is required
//                                to create the records set and fill in this set.
//  RegisterName     - String - information register name to which it is required to add record.
// 
Procedure AddRecordToInformationRegister(RecordStructure, Val RegisterName, Import = False) Export
	
	RecordSet = CreateInformationRegisterRecordSet(RecordStructure, RegisterName);
	
	// Add only one record to the new record set.
	NewRecord = RecordSet.Add();
	
	// Fill in record properties values from the passed structure.
	FillPropertyValues(NewRecord, RecordStructure);
	
	RecordSet.DataExchange.Load = Import;
	
	// write the set of records
	RecordSet.Write();
	
EndProcedure

// Updates a record to the information register by the passed structure values.
//
// Parameters:
//  RecordStructure - Structure - structure by the values of which it is required to create record manager and update record.
//  RegisterName     - String - information register name in which it is required to update record.
// 
Procedure UpdateRecordToInformationRegister(RecordStructure, Val RegisterName) Export
	
	RegisterMetadata = Metadata.InformationRegisters[RegisterName];
	
	// Create manager of the register record.
	RecordManager = InformationRegisters[RegisterName].CreateRecordManager();
	
	// Set filter by register changes.
	For Each Dimension IN RegisterMetadata.Dimensions Do
		
		// If the value is set in the structure, set filter.
		If RecordStructure.Property(Dimension.Name) Then
			
			RecordManager[Dimension.Name] = RecordStructure[Dimension.Name];
			
		EndIf;
		
	EndDo;
	
	// Read the record from the data base.
	RecordManager.Read();
	
	// Fill in record properties values from the passed structure.
	FillPropertyValues(RecordManager, RecordStructure);
	
	// write the record manager
	RecordManager.Write();
	
EndProcedure

// Deletes records set in the register by the passed structure values.
//
// Parameters:
//  RecordStructure - Structure - Structure by values of which it is required to delete records set.
//  RegisterName     - String - information register name in which it is required to delete records set.
// 
Procedure DeleteRecordSetInInformationRegister(RecordStructure, RegisterName, Import = False) Export
	
	RecordSet = CreateInformationRegisterRecordSet(RecordStructure, RegisterName);
	
	RecordSet.DataExchange.Load = Import;
	
	// write the set of records
	RecordSet.Write();
	
EndProcedure

// Performs export rules for data exchange (ORR or OCR) in the IB.
// 
Procedure ImportDataExchangeRules(Cancel,
										Val ExchangePlanName,
										Val RuleKind,
										Val RulesTemplateName,
										Val RulesTemplateNameCorrespondent = "")
	
	RecordStructure = New Structure;
	RecordStructure.Insert("ExchangePlanName",  ExchangePlanName);
	RecordStructure.Insert("RuleKind",       RuleKind);
	If Not IsBlankString(RulesTemplateNameCorrespondent) Then
		RecordStructure.Insert("RulesTemplateNameCorrespondent", RulesTemplateNameCorrespondent);
	EndIf;
	RecordStructure.Insert("RulesTemplateName", RulesTemplateName);
	RecordStructure.Insert("RulesSource",  Enums.RuleSourcesForDataExchange.ConfigurationTemplate);
	RecordStructure.Insert("UseSelectiveObjectsRegistrationFilter", True);
	
	// Get register records set.
	RecordSet = CreateInformationRegisterRecordSet(RecordStructure, "DataExchangeRules");
	
	// Add only one record to the new record set.
	NewRecord = RecordSet.Add();
	
	// Fill in properties values of record from the structure.
	FillPropertyValues(NewRecord, RecordStructure);
	
	// Import rules for data exchange in IB.
	InformationRegisters.DataExchangeRules.ImportRules(Cancel, RecordSet[0]);
	
	If Not Cancel Then
		RecordSet.Write();
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure ExecuteUpdateOfTypicalRulesVersionForDataExchange(Cancel, ImportedFromFileExchangeRules, ImportedFromFileRecordRules)
	
	For Each ExchangePlanName IN DataExchangeReUse.SSLExchangePlans() Do
		
		If CommonUseReUse.DataSeparationEnabled()
			AND Not DataExchangeReUse.ExchangePlanUsedSaaS(ExchangePlanName) Then
			Continue;
		EndIf;
		
		If ImportedFromFileExchangeRules.Find(ExchangePlanName) = Undefined
			AND DataExchangeReUse.IsTemplateOfExchangePlan(ExchangePlanName, "ExchangeRules")
			AND DataExchangeReUse.IsTemplateOfExchangePlan(ExchangePlanName, "CorrespondentExchangeRules") Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Updating data conversion rules for exchange plan %1';ru='Выполняется обновление правил конвертации данных для плана обмена %1'"), ExchangePlanName);
			WriteLogEvent(EventLogMonitorMessageTextDataExchange(),
				EventLogLevel.Information,,, MessageText);
			
			ImportDataExchangeRules(Cancel, ExchangePlanName, Enums.DataExchangeRuleKinds.ObjectConversionRules,
				"ExchangeRules", "CorrespondentExchangeRules");
			
		EndIf;
		
		If ImportedFromFileRecordRules.Find(ExchangePlanName) = Undefined
			AND DataExchangeReUse.IsTemplateOfExchangePlan(ExchangePlanName, "RegistrationRules") Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Updating data registration rules for exchange plan %1';ru='Выполняется обновление правил регистрации данных для плана обмена %1'"), ExchangePlanName);
			WriteLogEvent(EventLogMonitorMessageTextDataExchange(),
				EventLogLevel.Information,,, MessageText);
				
			ImportDataExchangeRules(Cancel, ExchangePlanName, Enums.DataExchangeRuleKinds.ObjectRegistrationRules, "RegistrationRules");
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Creates records set of the information register by passed structure values. Adds one record to the set.
//
// Parameters:
//  RecordStructure - Structure - structure by the values of which it is required
//                                to create the records set and fill in this set.
//  RegisterName     - String - name of the information register.
// 
Function CreateInformationRegisterRecordSet(RecordStructure, RegisterName) Export
	
	RegisterMetadata = Metadata.InformationRegisters[RegisterName];
	
	// Create register records set.
	RecordSet = InformationRegisters[RegisterName].CreateRecordSet();
	
	// Set filter by register changes.
	For Each Dimension IN RegisterMetadata.Dimensions Do
		
		// If the value is set in the structure, set filter.
		If RecordStructure.Property(Dimension.Name) Then
			
			RecordSet.Filter[Dimension.Name].Set(RecordStructure[Dimension.Name]);
			
		EndIf;
		
	EndDo;
	
	Return RecordSet;
EndFunction

// Receives the index of picture for the output in the table of objects match statistics.
//
Function InformationStatisticsTablePictureIndex(Val UnmappedObjectsCount, Val DataSuccessfullyImported) Export
	
	Return ?(UnmappedObjectsCount = 0, ?(DataSuccessfullyImported = True, 2, 0), 1);
	
EndFunction

// Checks the flag showing that exchange rules were imported for the specified exchange plan.
//
//  Returns:
//   True - exchange rules are imported to IB, otherwise, False.
//
Function ObjectConversionRulesForExchangePlanAreImported(Val ExchangePlanName) Export
	
	QueryText = "
	|SELECT TOP 1 1
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	  DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND DataExchangeRules.RulesImported
	|	AND DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Return Not Query.Execute().IsEmpty();
EndFunction

// Checks if the size of exchange message file exceeds the permissible size.
//
//  Returns:
//   True - if file size is greater than allowed, otherwise, False.
//
Function ExchangeMessageSizeExceedsValidSize(Val FileName, Val MaximumValidMessageSize) Export
	
	// Return value of the function.
	Result = False;
	
	File = New File(FileName);
	
	If File.Exist() AND File.IsFile() Then
		
		If MaximumValidMessageSize <> 0 Then
			
			PackageSize = Round(File.Size() / 1024, 0, RoundMode.Round15as20);
			
			If PackageSize > MaximumValidMessageSize Then
				
				MessageString = NStr("en='Outgoing package size is %1 KB and exceeds allowable limit of %2 KB.';ru='Размер исходящего пакета составил %1 Кбайт, что превышает допустимое ограничение %2 Кбайт.'");
				MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(PackageSize), String(MaximumValidMessageSize));
				ShowMessageAboutError(MessageString, Result);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// For an internal use.
// 
Function InitialDataExportFlagIsSet(InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.InfobasesNodesCommonSettings.InitialDataExportFlagIsSet(InfobaseNode);
	
EndFunction

// For an internal use.
// 
Procedure RegisterOnlyCatalogsForInitialLandings(Val InfobaseNode) Export
	
	RegisterDataForInitialExport(InfobaseNode, ExchangePlanCatalogs(InfobaseNode));
	
EndProcedure

// For an internal use.
// 
Procedure RegisterAllDataExceptCatalogsForInitialExporting(Val InfobaseNode) Export
	
	RegisterDataForInitialExport(InfobaseNode, AllExchangePlanDataExceptCatalogs(InfobaseNode));
	
EndProcedure

// For an internal use.
// 
Procedure RegisterDataForInitialExport(InfobaseNode, Data = Undefined) Export
	
	SetPrivilegedMode(True);
	
	// Update reused values of Objects registration mechanism.
	DataExchangeServerCall.CheckObjectRegistrationMechanismCache();
	
	StandardProcessing = True;
	
	DataExchangeOverridable.InitialDataExportChangeRecord(InfobaseNode, StandardProcessing, Data);
	
	If StandardProcessing Then
		
		If TypeOf(Data) = Type("Array") Then
			
			For Each MetadataObject IN Data Do
				
				ExchangePlans.RecordChanges(InfobaseNode, MetadataObject);
				
			EndDo;
			
		Else
			
			ExchangePlans.RecordChanges(InfobaseNode, Data);
			
		EndIf;
		
	EndIf;
	
	If DataExchangeReUse.ExchangePlanContainsObject(DataExchangeReUse.GetExchangePlanName(InfobaseNode),
		Metadata.InformationRegisters.InfobasesObjectsCompliance.FullName()) Then
		
		ExchangePlans.DeleteChangeRecords(InfobaseNode, Metadata.InformationRegisters.InfobasesObjectsCompliance);
		
	EndIf;
	
	If Not DataExchangeReUse.ThisIsDistributedInformationBaseNode(InfobaseNode) Then
		
		// Sets a flag of data initial export for node.
		InformationRegisters.InfobasesNodesCommonSettings.SetInitialDataExportFlag(InfobaseNode);
		
	EndIf;
	
EndProcedure

// Imports the exchange message that
// contains configuration changes before the infobase update.
//
Procedure ImportMessageBeforeInformationBaseUpdating() Export
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"IgnoreExportMessagesExchangeDataBeforeRunning") Then
		Return;
	EndIf;
	
	If GetFunctionalOption("UseDataSynchronization") = True Then
		
		InfobaseNode = MasterNode();
		
		If InfobaseNode <> Undefined Then
			
			SetPrivilegedMode(True);
			SetDataExchangeMessageImportModeBeforeStart("ImportAllowed", True);
			SetPrivilegedMode(False);
			
			Try
				// Update objects registration rules before the data import.
				ExecuteUpdateOfDataExchangeRules();
				
				TransportKind = InformationRegisters.ExchangeTransportSettings.ExchangeMessageTransportKindByDefault(InfobaseNode);
				
				Cancel = False;
				
				// import only
				ExecuteDataExchangeForInfobaseNode(Cancel, InfobaseNode, True, False, TransportKind);
				
				// Repeat mode requires to be enabled in the following cases.
				// Case 1. Metadata with a new version of the configuration is received i.e IB update will be executed.
				// If Denial = True, then it is unacceptable to continue as duplicates of the generated data can be created,
				// - If Denial = False, then an error may occur while updating IB that may require to import message again.
				// Case 2. Metadata with the same version of the configuration is received i.e. IB will not be updated.
				// If Denial = True, then an error may occur while continuing the start
				//   as the predefined items were not imported,
				// - if Denial = False, then it is possible to continue as you can export it later
				//   (if it is not exported successfully, then you can receive a new message for import later).
				
				If Cancel OR InfobaseUpdate.InfobaseUpdateRequired() Then
					EnableExchangeMessageDataExportRepetitionBeforeRunning();
				EndIf;
				
				If Cancel Then
					Raise NStr("en='Receiving data from the main node is completed with errors.';ru='Получение данных из главного узла завершилось с ошибками.'");
				EndIf;
			Except
				SetPrivilegedMode(True);
				SetDataExchangeMessageImportModeBeforeStart("ImportAllowed", False);
				SetPrivilegedMode(False);
				Raise;
			EndTry;
			SetPrivilegedMode(True);
			SetDataExchangeMessageImportModeBeforeStart("ImportAllowed", False);
			SetPrivilegedMode(False);
		EndIf;
		
	EndIf;
	
EndProcedure

// Exports the exchange message
// that contains configuration changes before the infobase update.
//
Procedure ExportMessageAfterInformationBaseUpdate() Export
	
	// You can disable the repeat mode after successful import and update of IB.
	DisconnectRepeatExportMessagesExchangeDataBeforeRunning();
	
	Try
		If GetFunctionalOption("UseDataSynchronization") = True Then
			
			InfobaseNode = MasterNode();
			
			If InfobaseNode <> Undefined Then
				
				RunExport = True;
				
				TransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettings(InfobaseNode);
				
				TransportKind = TransportSettings.ExchangeMessageTransportKindByDefault;
				
				If TransportKind = Enums.ExchangeMessagesTransportKinds.WS
					AND Not TransportSettings.WSRememberPassword Then
					
					RunExport = False;
					
					InformationRegisters.InfobasesNodesCommonSettings.SetDataSendSign(InfobaseNode);
					
				EndIf;
				
				If RunExport Then
					
					// export only
					ExecuteDataExchangeForInfobaseNode(False, InfobaseNode, False, True, TransportKind);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Except
		WriteLogEvent(EventLogMonitorMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Sets the flag showing that the import is repeated if an error of import or update occurs.
// Cleans exchange messages storage received from the main node DIB.
//
Procedure EnableExchangeMessageDataExportRepetitionBeforeRunning()
	
	ClearDataExchangeMessageFromMainNode();
	
	Constants.RetryDataExportExchangeMessagesBeforeStart.Set(True);
	
EndProcedure

// Resets the flag showing that import is repeated if an error occurs while import or update.
Procedure DisconnectRepeatExportMessagesExchangeDataBeforeRunning() Export
	
	SetPrivilegedMode(True);
	
	If Constants.RetryDataExportExchangeMessagesBeforeStart.Get() = True Then
		Constants.RetryDataExportExchangeMessagesBeforeStart.Set(False);
	EndIf;
	
EndProcedure

// Imports and exports the exchange
// message containing configuration changes
// that did not require the infobase update.
//
Procedure SynchronizeWhenNoUpdateOfInformationBase(
		ClientApplicationsOnStart, Restart) Export
	
	If Not ImportDataExchangeMessage() Then
		// If the import of the exchange message is
		// cancelled and configuration version is not improved, then disable the import repetition.
		DisconnectRepeatExportMessagesExchangeDataBeforeRunning();
		Return;
	EndIf;
		
	If ConfigurationChanged() Then
		// Configuration changes are imported but not applied.
		// It is too early to import message.
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		ImportMessageBeforeInformationBaseUpdating();
		CommitTransaction();
	Except
		If ConfigurationChanged() Then
			If Not DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
				"MessageReceivedFromCache") Then
				// Transition from configuration in which
				// the caching of exchange messages was not used. A new imported message
				// may contain new configuration changes. Unable to define
				// the return to data base configuration. You should fix the
				// transaction and continue the start without export of a new exchange messages.
				CommitTransaction();
				Return;
			Else
				// Configuration changes are
				// received, this means that a return to data base configuration is executed.
				// You should cancel the import.
				RollbackTransaction();
				SetPrivilegedMode(True);
				Constants.ImportDataExchangeMessage.Set(False);
				ClearDataExchangeMessageFromMainNode();
				SetPrivilegedMode(False);
				WriteEventGetData(MasterNode(),
					NStr("en='Return to the data base configuration is found.
		|Synchronization is cancelled.';ru='Обнаружен возврат к конфигурации базы данных.
		|Синхронизация отменена.'"));
				Return;
			EndIf;
		EndIf;
		// If the return to data base configuration
		// is executed but the linker is not closed. Then a new message has not been imported.
		// After going to the repeat mode you can click the
		// Do not synchronize and continue button and then the
		// return to configuration of the data base will be complete successfully.
		CommitTransaction();
		EnableExchangeMessageDataExportRepetitionBeforeRunning();
		If ClientApplicationsOnStart Then
			Restart = True;
			Return;
		EndIf;
		Raise;
	EndTry;
	
	ExportMessageAfterInformationBaseUpdate();
	
EndProcedure

// For an internal use.
// 
Function LongOperationStateForInfobaseNode(Val InfobaseNode,
																Val ActionID,
																ErrorMessageString = ""
	) Export
	
	WSProxy = GetWSProxyForInfobaseNode(InfobaseNode, ErrorMessageString);
	
	If WSProxy = Undefined Then
		Raise ErrorMessageString;
	EndIf;
	
	Return WSProxy.GetLongOperationState(ActionID, ErrorMessageString);
EndFunction

// For an internal use.
// 
Function TempFileStorageDirectory()
	
	Return DataExchangeReUse.TempFileStorageDirectory();
	
EndFunction

// For an internal use.
// 
Function UniqueExchangeMessageFileName()
	
	Result = "Message{GUID}.xml";
	Result = StrReplace(Result, "GUID", String(New UUID));
	
	Return Result;
EndFunction

// For an internal use.
// 
Function IsSubordinateDIBNode() Export
	
	Return MasterNode() <> Undefined;
	
EndFunction

// Receives the node of the distributed infobase that is the main
// node for the current infobase if the distributed infobase is created according to the exchange plan served by the subsystem of SSL exchange data.
//
// Returns:
//  ExchangePlanRef.<Exchange plan name>; Undefined - If the current infobase is
//   not the node of
//   the distributed infobase or the main node is not defined for it
//   (it is the root node itself) or the distributed infobase was created based on
//   the exchange plan that is not served by the subsystem of the SSL data exchange, then the method returns Undefined.
//
Function MasterNode() Export
	
	Result = ExchangePlans.MasterNode();
	
	If Result <> Undefined Then
		
		If Not DataExchangeReUse.IsSLDataExchangeNode(Result) Then
			
			Result = Undefined;
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// Returns array of the versions numbers supported by the correspondent interface for the DataExchange subsystem.
// 
// Parameters:
// ExternalConnection - COM-connection object that is used for work with correspondent.
//
// Returns:
// Array of the version numbers supported by the correspondent interface.
//
Function CorrespondentVersionsViaExternalConnection(ExternalConnection) Export
	
	Return CommonUse.GetInterfaceVersionsViaExternalConnection(ExternalConnection, "DataExchange");
	
EndFunction

// For an internal use.
// 
Function ShortPresentationOfFirstErrors(ErrorInfo)
	
	If ErrorInfo.Cause <> Undefined Then
		
		Return ShortPresentationOfFirstErrors(ErrorInfo.Cause);
		
	EndIf;
	
	Return BriefErrorDescription(ErrorInfo);
EndFunction

// Creates a temporary directory of the exchange messages.
// Writes catalog name to the register for the subsequent removal.
//
Function CreateTemporaryDirectoryOfExchangeMessages() Export
	
	Result = CommonUseClientServer.GetFullFileName(DataExchangeReUse.TempFileStorageDirectory(), TemporaryExchangeMessagesDirectoryName());
	
	CreateDirectory(Result);
	
	If Not CommonUse.FileInfobase() Then
		
		SetPrivilegedMode(True);
		
		PutFileToStorage(Result);
		
	EndIf;
	
	Return Result;
EndFunction

// Returns a flag showing that it is required to import data exchange message.
//
Function ImportDataExchangeMessage() Export
	
	SetPrivilegedMode(True);
	
	Return Constants.ImportDataExchangeMessage.Get() = True;
	
EndFunction

Function InvertDataItemReceiveDefault(Val GetFromMain) Export
	
	Return ?(GetFromMain, DataItemReceive.Ignore, DataItemReceive.Accept);
	
EndFunction

Function VariantExchangeData(Val Correspondent) Export
	
	Result = "Synchronization";
	
	If Not DataExchangeReUse.ThisIsDistributedInformationBaseNode(Correspondent) Then
		
		AttributeNames = CommonUse.NamesOfAttributesByType(Correspondent, Type("EnumRef.ExchangeObjectsExportModes"));
		
		AttributeValues = CommonUse.ObjectAttributesValues(Correspondent, AttributeNames);
		
		For Each Attribute IN AttributeValues Do
			
			If Attribute.Value = Enums.ExchangeObjectsExportModes.ExportManually
				OR Attribute.Value = Enums.ExchangeObjectsExportModes.DoNotExport Then
				
				Result = "GetingAndSending";
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Return Result;
EndFunction

Procedure ImportObjectContext(Val Context, Val Object) Export
	
	For Each Attribute IN Object.Metadata().Attributes Do
		
		If Context.Property(Attribute.Name) Then
			
			Object[Attribute.Name] = Context[Attribute.Name];
			
		EndIf;
		
	EndDo;
	
	For Each TabularSection IN Object.Metadata().TabularSections Do
		
		If Context.Property(TabularSection.Name) Then
			
			Object[TabularSection.Name].Load(Context[TabularSection.Name]);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetObjectContext(Val Object) Export
	
	Result = New Structure;
	
	For Each Attribute IN Object.Metadata().Attributes Do
		
		Result.Insert(Attribute.Name, Object[Attribute.Name]);
		
	EndDo;
	
	For Each TabularSection IN Object.Metadata().TabularSections Do
		
		Result.Insert(TabularSection.Name, Object[TabularSection.Name].Unload());
		
	EndDo;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Wrapper for work with external (published) applicationming interface of the exchange plan manager.

Function FilterSsettingsAtNode(Val ExchangePlanName, Val CorrespondentVersion, FormName = "", SettingID = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	FormName = "";
	
	Result = ExchangePlans[ExchangePlanName].FilterSsettingsAtNode(CorrespondentVersion, FormName, SettingID);
	
	If IsBlankString(FormName) Then
		FormName = "NodeConfigurationForm";
	EndIf;
	
	If Result = Undefined Then
		Result = New Structure;
	EndIf;
	
	Return Result;
EndFunction

Function DefaultValuesAtNode(Val ExchangePlanName, Val CorrespondentVersion, FormName = "", SettingID = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	FormName = "";
	
	Result = ExchangePlans[ExchangePlanName].DefaultValuesAtNode(CorrespondentVersion, FormName, SettingID);
	
	If IsBlankString(FormName) Then
		FormName = "DefaultValuesConfigurationForm";
	EndIf;
	
	If Result = Undefined Then
		Result = New Structure;
	EndIf;
	
	Return Result;
	
EndFunction

Function DataTransferRestrictionsDescriptionFull(Val ExchangePlanName, Val Setting, Val CorrespondentVersion, SettingID = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	Return ExchangePlans[ExchangePlanName].DataTransferRestrictionsDescriptionFull(Setting, CorrespondentVersion, SettingID);
	
EndFunction

Function ValuesDescriptionFullByDefault(Val ExchangePlanName, Val Setting, Val CorrespondentVersion, SettingID = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	Return ExchangePlans[ExchangePlanName].ValuesDescriptionFullByDefault(Setting, CorrespondentVersion, SettingID);
	
EndFunction

Function CommonNodeData(Val ExchangePlanName, Val CorrespondentVersion, FormName = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	FormName = "";
	
	Result = ExchangePlans[ExchangePlanName].CommonNodeData(CorrespondentVersion, FormName);
	
	If IsBlankString(FormName) Then
		FormName = "NodesSettingForm";
	EndIf;
	
	Return StrReplace(Result, " ", "");
EndFunction

Function CorrespondentInfobaseNodeFilterSetup(Val ExchangePlanName, Val CorrespondentVersion, FormName = "", SettingID = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	FormName = "";
	
	Result = ExchangePlans[ExchangePlanName].CorrespondentInfobaseNodeFilterSetup(CorrespondentVersion, FormName, SettingID);
	
	If IsBlankString(FormName) Then
		FormName = "CorrespondentInfobaseNodeSettingsForm";
	EndIf;
	
	If Result = Undefined Then
		Result = New Structure;
	EndIf;
	
	Return Result;
EndFunction

Function CorrespondentInfobaseNodeDefaultValues(Val ExchangePlanName, Val CorrespondentVersion, FormName = "", SettingID = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	FormName = "";
	
	Result = ExchangePlans[ExchangePlanName].CorrespondentInfobaseNodeDefaultValues(CorrespondentVersion, FormName, SettingID);
	
	If IsBlankString(FormName) Then
		FormName = "CorrespondentInfobaseDefaultValueSetupForm";
	EndIf;
	
	If Result = Undefined Then
		Result = New Structure;
	EndIf;
	
	Return Result;
EndFunction

Function CorrespondentInfobaseDataTransferRestrictionDetails(Val ExchangePlanName, Val FilterSsettingsAtNode, Val CorrespondentVersion, SettingID = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	Return ExchangePlans[ExchangePlanName].CorrespondentInfobaseDataTransferRestrictionDetails(FilterSsettingsAtNode, CorrespondentVersion, SettingID);
	
EndFunction

Function CorrespondentInfobaseDefaultValueDetails(Val ExchangePlanName, Val DefaultValuesAtNode, Val CorrespondentVersion, SettingID = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	Return ExchangePlans[ExchangePlanName].CorrespondentInfobaseDefaultValueDetails(DefaultValuesAtNode, CorrespondentVersion, SettingID);
	
EndFunction

Function CorrespondentInfobaseAccountingSettingsSetupComment(Val ExchangePlanName, Val CorrespondentVersion) Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	Return ExchangePlans[ExchangePlanName].CorrespondentInfobaseAccountingSettingsSetupComment(CorrespondentVersion);
	
EndFunction

Procedure OnConnectingToCorrespondent(Val ExchangePlanName, Val CorrespondentVersion) Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	ExchangePlans[ExchangePlanName].OnConnectingToCorrespondent(CorrespondentVersion);
	
EndProcedure

//

// For an internal use.
// 
Function ExchangeProcessingForDataImport(Cancel, Val InfobaseNode, Val ExchangeMessageFileName) Export
	
	Return DataExchangeReUse.DataProcessorForDataImport(Cancel, InfobaseNode, ExchangeMessageFileName);
	
EndFunction

// Returns the initialized InfobaseObjectsConversion processor for performing the data import.
// The processor is saved in the platform cache for a multiple
// use for one exchange plan node and specific exchange message file with a unique full name.
// 
// Parameters:
//  InfobaseNode - ExchangePlanRef - exchange plan node.
//  ExchangeMessageFileName - String - unique name of exchange message file to import data.
// 
// Returns:
//  DataProcessorObject.InfobaseObjectsConversion - initialized processor for the data import.
//
Function DataProcessorForDataImport(Cancel, Val InfobaseNode, Val ExchangeMessageFileName) Export
	
	// INITIALIZATION OF PROCESSOR TO UPLOAD DATA
	DataProcessorManager = ?(DataExchangeReUse.ThisIsExchangePlanXDTO(InfobaseNode),
		DataProcessors.XDTOObjectsConversion,
		DataProcessors.InfobaseObjectsConversion);
	
	DataExchangeDataProcessor = DataProcessorManager.Create();
	
	DataExchangeDataProcessor.ExchangeMode = "Import";
	
	DataExchangeDataProcessor.InfoMessagesOutputToMessagesWindow = False;
	DataExchangeDataProcessor.OutputInInformationMessagesToProtocol = False;
	DataExchangeDataProcessor.AppendDataToExchangeProtocol = False;
	DataExchangeDataProcessor.ExportAllowedOnly = False;
	DataExchangeDataProcessor.ContinueOnError = False;
	
	DataExchangeDataProcessor.ExchangeProtocolFileName = "";
	
	DataExchangeDataProcessor.EventLogMonitorMessageKey = GetEventLogMonitorMessageKey(InfobaseNode, Enums.ActionsAtExchange.DataImport);
	
	DataExchangeDataProcessor.ExchangeNodeForDataImport = InfobaseNode;
	DataExchangeDataProcessor.ExchangeFileName           = ExchangeMessageFileName;
	
	DataExchangeDataProcessor.ObjectsCountForTransactions = DataImportTransactionItemCount();
	
	ExchangePlanName = DataExchangeReUse.GetExchangePlanName(InfobaseNode);
	
	If DataExchangeDataProcessor.Metadata().Attributes.Find("DebuggingImportHandlers") <> Undefined Then
		SetSettingsDebuggingExportForRulesExchange(DataExchangeDataProcessor, ExchangePlanName);
	EndIf;
	
	Return DataExchangeDataProcessor;
EndFunction

// Work with passwords of the data synchronization.

// Returns values of data synchronization password for the specified node.
// If there is no password, Undefined is returned.
//
// Returns:
//  String, Undefined - password value of the data synchronization.
//
Function PasswordSynchronizationData(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.DataSynchronizationPasswords.Get(InfobaseNode);
EndFunction

// Returns the flag showing that the password of the data synchronization was specified by a user.
//
Function PasswordSynchronizationDataSet(Val InfobaseNode) Export
	
	Return PasswordSynchronizationData(InfobaseNode) <> Undefined;
	
EndFunction

// Sets data synchronization password for the specified node.
// Password is saved in the session parameter.
//
Procedure SetPasswordSynchronizationData(Val InfobaseNode, Val Password)
	
	SetPrivilegedMode(True);
	
	DataSynchronizationPasswords = New Map;
	
	For Each Item IN SessionParameters.DataSynchronizationPasswords Do
		
		DataSynchronizationPasswords.Insert(Item.Key, Item.Value);
		
	EndDo;
	
	DataSynchronizationPasswords.Insert(InfobaseNode, Password);
	
	SessionParameters.DataSynchronizationPasswords = New FixedMap(DataSynchronizationPasswords);
	
EndProcedure

// Resets data synchronization password for the specified node.
//
Procedure DropPasswordSynchronizationData(Val InfobaseNode)
	
	SetPasswordSynchronizationData(InfobaseNode, Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Control of the unseparated data.

// It is called when checking whether unseparated data is available for writing.
//
Procedure RunControlRecordsUndividedData(Val Data) Export
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData()
		AND Not IsDividedObject(Data) Then
		
		ExceptionsRepresentation = NStr("en='Access right violation';ru='Нарушение прав доступа!'");
		ErrorMessage = NStr("en='Access right violation';ru='Нарушение прав доступа!'", CommonUseClientServer.MainLanguageCode());
		
		WriteLogEvent(
			ErrorMessage,
			EventLogLevel.Error,
			Data.Metadata());
		
		Raise ExceptionsRepresentation;
	EndIf;
	
EndProcedure

Function IsDividedObject(Val Object)
	
	FullName = Object.Metadata().FullName();
	
	Return CommonUseReUse.IsSeparatedMetadataObject(FullName, CommonUseReUse.MainDataSeparator())
		OR CommonUseReUse.IsSeparatedMetadataObject(FullName, CommonUseReUse.SupportDataSplitter())
	;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with the data exchange monitor.

// Returns the structure with data of the last exchange for the specified node of the infobase.
// 
// Parameters:
//  No.
// 
// Returns:
//  DataExchangeStatus - Structure - structure with data of the last exchange for the specified infobase node.
//
Function ExchangeNodeDataExchangeStatus(Val InfobaseNode) Export
	
	// Return value of the function.
	DataExchangeStatus = New Structure;
	DataExchangeStatus.Insert("InfobaseNode");
	DataExchangeStatus.Insert("DataImportResult", "Undefined");
	DataExchangeStatus.Insert("DataExportResult", "Undefined");
	
	QueryText = "
	|// {QUERY No.0}
	|////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|	WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Completed)
	|	THEN ""Success""
	|	
	|	WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.CompletedWithWarnings)
	|	THEN ""CompletedWithWarnings""
	|	
	|	WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived)
	|	THEN ""Warning_ExchangeMessageHasBeenPreviouslyReceived""
	|	
	|	WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Error_MessageTransport)
	|	THEN ""Error_MessageTransport""
	|	
	|	ELSE ""Error""
	|	
	|	END AS ExchangeProcessResult
	|FROM
	|	InformationRegister.[DataExchangeStatus] AS DataExchangeStatus
	|WHERE
	|	  DataExchangeStatus.InfobaseNode = &InfobaseNode
	|	AND DataExchangeStatus.ActionOnExchange = VALUE(Enum.ActionsAtExchange.DataImport)
	|;
	|// {QUERY No.1}
	|////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|	WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Completed)
	|	THEN ""Success""
	|	
	|	WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.CompletedWithWarnings)
	|	THEN ""CompletedWithWarnings""
	|	
	|	WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived)
	|	THEN ""Warning_ExchangeMessageHasBeenPreviouslyReceived""
	|	
	|	WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Error_MessageTransport)
	|	THEN ""Error_MessageTransport""
	|	
	|	ELSE ""Error""
	|	END AS ExchangeProcessResult
	|	
	|FROM
	|	InformationRegister.[DataExchangeStatus] AS DataExchangeStatus
	|WHERE
	|	  DataExchangeStatus.InfobaseNode = &InfobaseNode
	|	AND DataExchangeStatus.ActionOnExchange = VALUE(Enum.ActionsAtExchange.DataExport)
	|;
	|";
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		QueryText = StrReplace(QueryText, "[DataExchangeState]", "DataAreaDataExchangeStatus");
	Else
		QueryText = StrReplace(QueryText, "[DataExchangeState]", "DataExchangeStatus");
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	QueryResultArray = Query.ExecuteBatch();
	
	DataImportResultSelection = QueryResultArray[0].Select();
	DataExportResultSelection = QueryResultArray[1].Select();
	
	If DataImportResultSelection.Next() Then
		
		DataExchangeStatus.DataImportResult = DataImportResultSelection.ExchangeProcessResult;
		
	EndIf;
	
	If DataExportResultSelection.Next() Then
		
		DataExchangeStatus.DataExportResult = DataExportResultSelection.ExchangeProcessResult;
		
	EndIf;
	
	DataExchangeStatus.InfobaseNode = InfobaseNode;
	
	Return DataExchangeStatus;
EndFunction

// Returns the structure with data of the last event for the specified node of the infobase and actions during the exchange.
// 
// Parameters:
//  No.
// 
// Returns:
//  DataExchangeStatus - Structure - structure with data of the last exchange for the specified infobase node.
//
Function DataExchangeStatus(Val InfobaseNode, ActionOnExchange) Export
	
	// Return value of the function.
	DataExchangeStatus = New Structure;
	DataExchangeStatus.Insert("StartDate",    Date('00010101'));
	DataExchangeStatus.Insert("EndDate", Date('00010101'));
	
	QueryText = "
	|SELECT
	|	StartDate,
	|	EndDate
	|FROM
	|	InformationRegister.[DataExchangeStatus] AS DataExchangeStatus
	|WHERE
	|	  DataExchangeStatus.InfobaseNode = &InfobaseNode
	|	AND DataExchangeStatus.ActionOnExchange      = &ActionOnExchange
	|";
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		QueryText = StrReplace(QueryText, "[DataExchangeStatus]", "DataAreaDataExchangeStatus");
	Else
		QueryText = StrReplace(QueryText, "[DataExchangeStatus]", "DataExchangeStatus");
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.SetParameter("ActionOnExchange",      ActionOnExchange);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		FillPropertyValues(DataExchangeStatus, Selection);
		
	EndIf;
	
	Return DataExchangeStatus;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Session initialization

// Receives array of all exchange plans according to which the data exchange is executed.
// To define whether there is exchange with an exchange plan, you should check whether this plan has nodes exchange except of the redefined one.
// 
// Parameters:
//  No.
// 
// Returns:
//  ExchangePlanArray - Array - array of rows (names) of all exchange plans according to which the data exchange is executed.
//
Function GetExchangePlansBeingUsed() Export
	
	// the return value
	ExchangePlanArray = New Array;
	
	// List all nodes in configuration.
	ExchangePlanList = DataExchangeReUse.SLExchangePlanList();
	
	For Each Item IN ExchangePlanList Do
		
		ExchangePlanName = Item.Value;
		
		If Not ExchangePlanDoesNotContainsNodes(ExchangePlanName) Then
			
			ExchangePlanArray.Add(ExchangePlanName);
			
		EndIf;
		
	EndDo;
	
	Return ExchangePlanArray;
	
EndFunction

// Receives table of objects registration table from infobase.
// 
// Parameters:
//  No.
// 
// Returns:
//  ObjectRegistrationRules - ValueTable - table of common rules of objects registration for ORM.
// 
Function GetObjectRegistrationRules() Export
	
	// Return value of the function.
	ObjectRegistrationRules = ObjectRegistrationRulesTableInitialization();
	
	QueryText = "
	|SELECT
	|	DataExchangeRules.ReadOutRules AS ReadOutRules
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	  DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectRegistrationRules)
	|	AND DataExchangeRules.RulesImported
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		FillPropertyValuesForORRValueTable(ObjectRegistrationRules, Selection.ReadOutRules.Get());
		
	EndDo;
	
	Return ObjectRegistrationRules;
	
EndFunction

// Receives the table of selective registration rules of objects from the infobase.
// 
// Parameters:
//  No.
// 
// Returns:
//  SelectiveObjectRegistrationRules - ValueTable - common rules table of objects selective
//                                                           registration for object registration mechanism.
// 
Function GetSelectiveObjectRegistrationRules() Export
	
	// Return value of the function.
	SelectiveObjectRegistrationRules = ObjectSelectiveRegistrationRulesTableInitialization();
	
	QueryText = "
	|SELECT
	|	DataExchangeRules.ReadOutRules AS ReadOutRules
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	  DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND DataExchangeRules.UseSelectiveObjectsRegistrationFilter
	|	AND DataExchangeRules.RulesImported
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		ExchangeRuleStructure = Selection.ReadOutRules.Get();
		
		FillPropertyValuesForValueTable(SelectiveObjectRegistrationRules, ExchangeRuleStructure["SelectiveObjectRegistrationRules"]);
		
	EndDo;
	
	Return SelectiveObjectRegistrationRules;
	
EndFunction

// For an internal use.
// 
Function ObjectRegistrationRulesTableInitialization() Export
	
	// Return value of the function.
	Rules = New ValueTable;
	
	Columns = Rules.Columns;
	
	Columns.Add("MetadataObjectName", New TypeDescription("String"));
	Columns.Add("ExchangePlanName",      New TypeDescription("String"));
	
	Columns.Add("FlagAttributeName", New TypeDescription("String"));
	
	Columns.Add("QueryText",    New TypeDescription("String"));
	Columns.Add("PropertiesOfObject", New TypeDescription("Structure"));
	
	Columns.Add("ObjectPropertiesString", New TypeDescription("String"));
	
	// Shows that the rules are empty.
	Columns.Add("RuleByObjectPropertiesEmpty", New TypeDescription("Boolean"));
	
	// events handlers
	Columns.Add("BeforeProcess",            New TypeDescription("String"));
	Columns.Add("OnProcess",               New TypeDescription("String"));
	Columns.Add("OnProcessAdditional", New TypeDescription("String"));
	Columns.Add("AfterProcessing",             New TypeDescription("String"));
	
	Columns.Add("HasBeforeProcessHandler",            New TypeDescription("Boolean"));
	Columns.Add("HasOnProcessHandler",               New TypeDescription("Boolean"));
	Columns.Add("HasOnProcessHandlerAdditional", New TypeDescription("Boolean"));
	Columns.Add("HasAfterProcessHandler",             New TypeDescription("Boolean"));
	
	Columns.Add("FilterByObjectProperties", New TypeDescription("ValueTree"));
	
	// Field for operational data storage from object or reference.
	Columns.Add("FilterByProperties", New TypeDescription("ValueTree"));
	
	// add index
	Rules.Indexes.Add("ExchangePlanName, MetadataObjectName");
	
	Return Rules;
	
EndFunction

// For an internal use.
// 
Function ObjectSelectiveRegistrationRulesTableInitialization() Export
	
	// Return value of the function.
	Rules = New ValueTable;
	
	Columns = Rules.Columns;
	
	Columns.Add("Order",                        New TypeDescription("Number"));
	Columns.Add("ObjectName",                     New TypeDescription("String"));
	Columns.Add("ExchangePlanName",                 New TypeDescription("String"));
	Columns.Add("TabularSectionName",              New TypeDescription("String"));
	Columns.Add("ChangeRecordAttributes",           New TypeDescription("String"));
	Columns.Add("ChangeRecordAttributeStructure", New TypeDescription("Structure"));
	
	// add index
	Rules.Indexes.Add("ExchangePlanName, ObjectName");
	
	Return Rules;
	
EndFunction

// For an internal use.
// 
Function ExchangePlanDoesNotContainsNodes(Val ExchangePlanName)
	
	QueryText = "
	|SELECT TOP 1 1
	|FROM
	|	ExchangePlan." + ExchangePlanName + " AS
	|ExchangePlan
	|WHERE ExchangePlan.Ref <> &ThisNode
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ThisNode", ExchangePlans[ExchangePlanName].ThisNode());
	
	Return Query.Execute().IsEmpty()
	
EndFunction

// For an internal use.
// 
Procedure FillPropertyValuesForORRValueTable(TargetTable, SourceTable)
	
	For Each SourceRow IN SourceTable Do
		
		FillPropertyValues(TargetTable.Add(), SourceRow);
		
	EndDo;
	
EndProcedure

// For an internal use.
// 
Procedure FillPropertyValuesForValueTable(TargetTable, SourceTable)
	
	For Each SourceRow IN SourceTable Do
		
		FillPropertyValues(TargetTable.Add(), SourceRow);
		
	EndDo;
	
EndProcedure

// For an internal use.
// 
Function DataSynchronizationRulesDescription(Val InfobaseNode) Export
	
	CorrespondentVersion = CorrespondentVersion(InfobaseNode);
	
	ExchangePlanName = DataExchangeReUse.GetExchangePlanName(InfobaseNode);
	
	Setting = ValuesSettingsSelectionsOnSite(InfobaseNode, CorrespondentVersion);
	
	Return DataTransferRestrictionsDescriptionFull(ExchangePlanName, Setting, CorrespondentVersion, SavedExchangePlanNodeSettingsVariant(InfobaseNode));
	
EndFunction

// For an internal use.
// 
Function ValuesSettingsSelectionsOnSite(Val InfobaseNode, Val CorrespondentVersion)
	
	Result = New Structure;
	
	InfobaseNodeObject = InfobaseNode.GetObject();
	
	ExchangePlanName = DataExchangeReUse.GetExchangePlanName(InfobaseNode);
	
	FilterSsettingsAtNode = FilterSsettingsAtNode(ExchangePlanName, CorrespondentVersion, , SavedExchangePlanNodeSettingsVariant(InfobaseNode));
	
	For Each Setting IN FilterSsettingsAtNode Do
		
		If TypeOf(Setting.Value) = Type("Structure") Then
			
			TabularSection = New Structure;
			
			For Each Column IN Setting.Value Do
				
				TabularSection.Insert(Column.Key, InfobaseNodeObject[Setting.Key].UnloadColumn(Column.Key));
				
			EndDo;
			
			Result.Insert(Setting.Key, TabularSection);
			
		Else
			
			Result.Insert(Setting.Key, InfobaseNodeObject[Setting.Key]);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// For an internal use.
Procedure SetDataExchangeMessageImportModeBeforeStart(Val Property, Val EnableMode) Export
	
	// Before calling it is required to set privileged mode.
	
	If IsSubordinateDIBNode() Then
		
		NewStructure = New Structure(SessionParameters.DataExchangeMessageImportModeBeforeStart);
		If EnableMode Then
			If Not NewStructure.Property(Property) Then
				NewStructure.Insert(Property);
			EndIf;
		Else
			If NewStructure.Property(Property) Then
				NewStructure.Delete(Property);
			EndIf;
		EndIf;
		
		SessionParameters.DataExchangeMessageImportModeBeforeStart =
			New FixedStructure(NewStructure);
	Else
		
		SessionParameters.DataExchangeMessageImportModeBeforeStart = New FixedStructure;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Initialization of the data exchange settings structure.

// Initializes the subsystem of data exchange to execute the exchange process.
// 
// Parameters:
// 
// Returns:
//  ExchangeSettingsStructure - Structure - structure with all necessary data and objects for exchange.
//
Function GetExchangeSettingsStructureForInfobaseNode(
	InfobaseNode,
	ActionOnExchange,
	ExchangeMessageTransportKind,
	UseTransportSettings = True
	) Export
	
	// Return value of the function.
	ExchangeSettingsStructure = ExchangeSettingsStructureBasic();
	
	ExchangeSettingsStructure.InfobaseNode = InfobaseNode;
	ExchangeSettingsStructure.ActionOnExchange      = ActionOnExchange;
	ExchangeSettingsStructure.ExchangeTransportKind    = ExchangeMessageTransportKind;
	ExchangeSettingsStructure.IsDIBExchange           = DataExchangeReUse.ThisIsDistributedInformationBaseNode(InfobaseNode);
	
	RunInitOfExchangeSettingsStructureForInfobaseNode(ExchangeSettingsStructure, UseTransportSettings);
	
	SetDebuggingModeSettingsForStructure(ExchangeSettingsStructure);
	
	// Check the settings structure for the values validity for exchange. Write errors to ELM.
	RunExchangeStructureValidityCheck(ExchangeSettingsStructure, UseTransportSettings);
	
	// If settings contain errors, then sign out.
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	If UseTransportSettings Then
		
		// Initialize processor of the exchange messages transport.
		RunInitOfProcessingOfExchangeMessagesTransport(ExchangeSettingsStructure);
		
	EndIf;
	
	// Initialize processor of the data exchange.
	If ExchangeSettingsStructure.IsDIBExchange Then
		
		ExecuteExchangeProcessingInit(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.ExchangeByObjectConversionRules Then
		
		ExecuteExchangeProcessingInitAccordingToConversionRules(ExchangeSettingsStructure);
		
	EndIf;
	
	Return ExchangeSettingsStructure;
EndFunction

// For an internal use.
// 
Function GetExchangeSettingsStructureForExternalConnection(InfobaseNode, ActionOnExchange, ItemCountInTransaction)
	
	// Return value of the function.
	ExchangeSettingsStructure = ExchangeSettingsStructureBasic();
	
	ExchangeSettingsStructure.InfobaseNode = InfobaseNode;
	ExchangeSettingsStructure.ActionOnExchange      = ActionOnExchange;
	ExchangeSettingsStructure.IsDIBExchange           = DataExchangeReUse.ThisIsDistributedInformationBaseNode(InfobaseNode);
	
	PropertyStructure = CommonUse.ObjectAttributesValues(ExchangeSettingsStructure.InfobaseNode, "Code, description");
	
	ExchangeSettingsStructure.InfobaseNodeCode          = PropertyStructure.Code;
	ExchangeSettingsStructure.InfobaseNodeDescription = PropertyStructure.Description;
	
	//
	ExchangeSettingsStructure.TransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettings(ExchangeSettingsStructure.InfobaseNode);
	
	If ItemCountInTransaction = Undefined Then
		
		ItemCountInTransaction = ?(ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsAtExchange.DataImport,
									ExchangeSettingsStructure.TransportSettings.DataImportTransactionItemCount,
									ExchangeSettingsStructure.TransportSettings.DataExportTransactionItemCount);
		//
		
	EndIf;
	
	ExchangeSettingsStructure.ItemCountInTransaction = ItemCountInTransaction;
	
	// CALCULATED VALUES
	ExchangeSettingsStructure.DoDataImport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsAtExchange.DataImport);
	ExchangeSettingsStructure.DoDataExport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsAtExchange.DataExport);
	
	ExchangeSettingsStructure.ExchangePlanName = DataExchangeReUse.GetExchangePlanName(ExchangeSettingsStructure.InfobaseNode);
	
	ExchangeSettingsStructure.CurrentExchangePlanNode = DataExchangeReUse.GetThisNodeOfExchangePlan(ExchangeSettingsStructure.ExchangePlanName);
	ExchangeSettingsStructure.CurrentExchangePlanNodeCode = CommonUse.ObjectAttributeValue(ExchangeSettingsStructure.CurrentExchangePlanNode, "Code");
	
	// Get message key for ELM.
	ExchangeSettingsStructure.EventLogMonitorMessageKey = GetEventLogMonitorMessageKey(ExchangeSettingsStructure.InfobaseNode, ExchangeSettingsStructure.ActionOnExchange);
	
	ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessagesTransportKinds.COM;
	
	SetDebuggingModeSettingsForStructure(ExchangeSettingsStructure);
	
	// Check the settings structure for the values validity for exchange. Write errors to ELM.
	RunExchangeStructureValidityCheck(ExchangeSettingsStructure);
	
	// If settings contain errors, then sign out.
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	// Initialize processor of the data exchange.
	ExecuteExchangeProcessingInitAccordingToConversionRules(ExchangeSettingsStructure);
	
	Return ExchangeSettingsStructure;
EndFunction

// Initializes the subsystem of data exchange to execute the exchange process.
// 
// Parameters:
// 
// Returns:
//  ExchangeSettingsStructure - Structure - structure with all necessary data and objects for exchange.
//
Function GetExchangeSettingsStructure(ExchangeExecutionSettings, LineNumber) Export
	
	// Return value of the function.
	ExchangeSettingsStructure = ExchangeSettingsStructureBasic();
	
	RunInitOfExchangeSettingsStructure(ExchangeSettingsStructure, ExchangeExecutionSettings, LineNumber);
	
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	SetDebuggingModeSettingsForStructure(ExchangeSettingsStructure);
	
	// Check the settings structure for the values validity for exchange. Write errors to ELM.
	RunExchangeStructureValidityCheck(ExchangeSettingsStructure);
	
	// If settings contain errors, then sign out.
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	// Initialize processor of the exchange messages transport.
	RunInitOfProcessingOfExchangeMessagesTransport(ExchangeSettingsStructure);
	
	// Initialize processor of the data exchange.
	If ExchangeSettingsStructure.IsDIBExchange Then
		
		ExecuteExchangeProcessingInit(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.ExchangeByObjectConversionRules Then
		
		ExecuteExchangeProcessingInitAccordingToConversionRules(ExchangeSettingsStructure);
		
	EndIf;
	
	Return ExchangeSettingsStructure;
EndFunction

// It receives the vehicle setting structure for the data exchange.
//
Function GetSettingsStructureOfTransport(InfobaseNode, ExchangeMessageTransportKind) Export
	
	// Return value of the function.
	ExchangeSettingsStructure = ExchangeSettingsStructureBasic();
	
	ExchangeSettingsStructure.InfobaseNode = InfobaseNode;
	ExchangeSettingsStructure.ActionOnExchange      = Enums.ActionsAtExchange.DataImport;
	ExchangeSettingsStructure.ExchangeTransportKind    = ExchangeMessageTransportKind;
	
	RunInitOfExchangeSettingsStructureForInfobaseNode(ExchangeSettingsStructure, True);
	
	// Check the settings structure for the values validity for exchange. Write errors to ELM.
	RunExchangeStructureValidityCheck(ExchangeSettingsStructure);
	
	// If settings contain errors, then sign out.
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	// Initialize processor of the exchange messages transport.
	RunInitOfProcessingOfExchangeMessagesTransport(ExchangeSettingsStructure);
	
	Return ExchangeSettingsStructure;
EndFunction

// For an internal use.
// 
Procedure RunInitOfExchangeSettingsStructure(ExchangeSettingsStructure, ExchangeExecutionSettings, LineNumber)
	
	QueryText = "
	|SELECT
	|	ExchangeExecutionSettingsExchangeSettings.InfobaseNode         AS InfobaseNode,
	|	ExchangeExecutionSettingsExchangeSettings.InfobaseNode.Code     AS InfobaseNodeCode,
	|	ExchangeExecutionSettingsExchangeSettings.ExchangeTransportKind            AS ExchangeTransportKind,
	|	ExchangeExecutionSettingsExchangeSettings.RunningAction            AS ActionOnExchange,
	|	ExchangeExecutionSettingsExchangeSettings.Ref                         AS ExchangeExecutionSettings,
	|	ExchangeExecutionSettingsExchangeSettings.Ref.Description            AS ExchangeExecutionSettingsDescription,
	|	CASE
	|		WHEN ExchangeExecutionSettingsExchangeSettings.RunningAction = VALUE(Enum.ActionsAtExchange.DataImport) THEN TRUE
	|		ELSE FALSE
	|	END                                                                   AS DoDataImport,
	|	CASE
	|		WHEN ExchangeExecutionSettingsExchangeSettings.RunningAction = VALUE(Enum.ActionsAtExchange.DataExport) THEN TRUE
	|		ELSE FALSE
	|	END                                                                   AS DoDataExport
	|FROM
	|	Catalog.DataExchangeScripts.ExchangeSettings AS ExchangeExecutionSettingsExchangeSettings
	|WHERE
	|	  ExchangeExecutionSettingsExchangeSettings.Ref      = &ExchangeExecutionSettings
	|	AND ExchangeExecutionSettingsExchangeSettings.LineNumber = &LineNumber
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangeExecutionSettings", ExchangeExecutionSettings);
	Query.SetParameter("LineNumber",               LineNumber);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	// Fill in values of the structure properties.
	FillPropertyValues(ExchangeSettingsStructure, Selection);
	
	ExchangeSettingsStructure.IsDIBExchange = DataExchangeReUse.ThisIsDistributedInformationBaseNode(ExchangeSettingsStructure.InfobaseNode);
	
	ExchangeSettingsStructure.EventLogMonitorMessageKey = NStr("en='Data exchange description';ru='Обмен данными описание'");
	
	// Check whether main fields of exchange settings structure are specified.
	RunCheckOfMainFieldsOfExchangeSettingsStructure(ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	
	//
	ExchangeSettingsStructure.ExchangePlanName = ExchangeSettingsStructure.InfobaseNode.Metadata().Name;
	ExchangeSettingsStructure.ExchangeByObjectConversionRules = DataExchangeReUse.IsUniversalDataExchangeNode(ExchangeSettingsStructure.InfobaseNode);
	
	ExchangeSettingsStructure.CurrentExchangePlanNode    = ExchangePlans[ExchangeSettingsStructure.ExchangePlanName].ThisNode();
	ExchangeSettingsStructure.CurrentExchangePlanNodeCode = ExchangeSettingsStructure.CurrentExchangePlanNode.Code;
	
	ExchangeSettingsStructure.DataProcessorNameOfExchangeMessagesTransport = DataProcessorNameOfExchangeMessagesTransport(ExchangeSettingsStructure.ExchangeTransportKind);
	
	// Get message key for ELM.
	ExchangeSettingsStructure.EventLogMonitorMessageKey = GetEventLogMonitorMessageKey(ExchangeSettingsStructure.InfobaseNode, ExchangeSettingsStructure.ActionOnExchange);
	
	//
	ExchangeSettingsStructure.TransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettings(ExchangeSettingsStructure.InfobaseNode, ExchangeSettingsStructure.ExchangeTransportKind);
	
	ExchangeSettingsStructure.ItemCountInTransaction = ItemsQuantityInExecutedActionTransaction(ExchangeSettingsStructure.ActionOnExchange);
	
EndProcedure

// For an internal use.
// 
Procedure RunInitOfExchangeSettingsStructureForInfobaseNode(
		ExchangeSettingsStructure,
		UseTransportSettings)
	
	PropertyStructure = CommonUse.ObjectAttributesValues(ExchangeSettingsStructure.InfobaseNode, "Code, description");
	
	ExchangeSettingsStructure.InfobaseNodeCode          = PropertyStructure.Code;
	ExchangeSettingsStructure.InfobaseNodeDescription = PropertyStructure.Description;
	
	// Receive settings of the exchange transport.
	ExchangeSettingsStructure.TransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettings(ExchangeSettingsStructure.InfobaseNode);
	
	If ExchangeSettingsStructure.TransportSettings <> Undefined Then
		
		If UseTransportSettings Then
			
			// If transport kind is not specified, use default value.
			If ExchangeSettingsStructure.ExchangeTransportKind = Undefined Then
				ExchangeSettingsStructure.ExchangeTransportKind = ExchangeSettingsStructure.TransportSettings.ExchangeMessageTransportKindByDefault;
			EndIf;
			
			// If transport kind is not specified, then use FILE transport.
			If Not ValueIsFilled(ExchangeSettingsStructure.ExchangeTransportKind) Then
				
				ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessagesTransportKinds.FILE;
				
			EndIf;
			
			ExchangeSettingsStructure.DataProcessorNameOfExchangeMessagesTransport = DataProcessorNameOfExchangeMessagesTransport(ExchangeSettingsStructure.ExchangeTransportKind);
			
		EndIf;
		
		ExchangeSettingsStructure.ItemCountInTransaction = ?(ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsAtExchange.DataImport,
									ExchangeSettingsStructure.TransportSettings.DataImportTransactionItemCount,
									ExchangeSettingsStructure.TransportSettings.DataExportTransactionItemCount);
		
		If ExchangeSettingsStructure.TransportSettings.Property("WSUseLargeDataTransfer") Then
			ExchangeSettingsStructure.UseLargeDataTransfer = ExchangeSettingsStructure.TransportSettings.WSUseLargeDataTransfer;
		EndIf;
		
	EndIf;
	
	// DEFAULT VALUES
	ExchangeSettingsStructure.ExchangeExecutionSettings             = Undefined;
	ExchangeSettingsStructure.ExchangeExecutionSettingsDescription = "";
	
	// CALCULATED VALUES
	ExchangeSettingsStructure.DoDataImport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsAtExchange.DataImport);
	ExchangeSettingsStructure.DoDataExport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsAtExchange.DataExport);
	
	ExchangeSettingsStructure.ExchangePlanName = ExchangeSettingsStructure.InfobaseNode.Metadata().Name;
	ExchangeSettingsStructure.ExchangeByObjectConversionRules = DataExchangeReUse.IsUniversalDataExchangeNode(ExchangeSettingsStructure.InfobaseNode);
	
	ExchangeSettingsStructure.CurrentExchangePlanNode    = ExchangePlans[ExchangeSettingsStructure.ExchangePlanName].ThisNode();
	ExchangeSettingsStructure.CurrentExchangePlanNodeCode = ExchangeSettingsStructure.CurrentExchangePlanNode.Code;
	
	// Get message key for ELM.
	ExchangeSettingsStructure.EventLogMonitorMessageKey = GetEventLogMonitorMessageKey(ExchangeSettingsStructure.InfobaseNode, ExchangeSettingsStructure.ActionOnExchange);
	
EndProcedure

// For an internal use.
// 
Function ExchangeSettingsStructureBasic()
	
	ExchangeSettingsStructure = New Structure;
	
	// Structure of settings by the query fields.
	
	ExchangeSettingsStructure.Insert("StartDate");
	ExchangeSettingsStructure.Insert("EndDate");
	
	ExchangeSettingsStructure.Insert("LineNumber");
	ExchangeSettingsStructure.Insert("ExchangeExecutionSettings");
	ExchangeSettingsStructure.Insert("ExchangeExecutionSettingsDescription");
	ExchangeSettingsStructure.Insert("InfobaseNode");
	ExchangeSettingsStructure.Insert("InfobaseNodeCode", "");
	ExchangeSettingsStructure.Insert("InfobaseNodeDescription", "");
	ExchangeSettingsStructure.Insert("ExchangeTransportKind");
	ExchangeSettingsStructure.Insert("ActionOnExchange");
	ExchangeSettingsStructure.Insert("ItemCountInTransaction", 1); // There is a separate transaction for each item.
	ExchangeSettingsStructure.Insert("DoDataImport", False);
	ExchangeSettingsStructure.Insert("DoDataExport", False);
	ExchangeSettingsStructure.Insert("UseLargeDataTransfer", False);
	
	// Additional structure of settings.
	ExchangeSettingsStructure.Insert("Cancel", False);
	ExchangeSettingsStructure.Insert("IsDIBExchange", False);
	
	ExchangeSettingsStructure.Insert("DataExchangeDataProcessor");
	ExchangeSettingsStructure.Insert("ExchangeMessageTransportDataProcessor");
	
	ExchangeSettingsStructure.Insert("ExchangePlanName");
	ExchangeSettingsStructure.Insert("CurrentExchangePlanNode");
	ExchangeSettingsStructure.Insert("CurrentExchangePlanNodeCode");
	
	ExchangeSettingsStructure.Insert("ExchangeByObjectConversionRules", False);
	
	ExchangeSettingsStructure.Insert("DataProcessorNameOfExchangeMessagesTransport");
	
	ExchangeSettingsStructure.Insert("EventLogMonitorMessageKey");
	
	ExchangeSettingsStructure.Insert("TransportSettings");
	
	ExchangeSettingsStructure.Insert("ObjectConversionRules");
	ExchangeSettingsStructure.Insert("RulesImported", False);
	
	ExchangeSettingsStructure.Insert("DebuggingExportHandlers ", False);
	ExchangeSettingsStructure.Insert("DebuggingImportHandlers", False);
	ExchangeSettingsStructure.Insert("FileNameOfExternalDataProcessorOfExportDebugging", "");
	ExchangeSettingsStructure.Insert("FileNameOfExternalDataProcessorOfImportDebugging", "");
	ExchangeSettingsStructure.Insert("DataExchangeLoggingMode", False);
	ExchangeSettingsStructure.Insert("ExchangeProtocolFileName", "");
	ExchangeSettingsStructure.Insert("ContinueOnError", False);
	
	// Structure for registration of events in ELM.
	ExchangeSettingsStructure.Insert("ExchangeProcessResult");
	ExchangeSettingsStructure.Insert("ActionOnExchange");
	ExchangeSettingsStructure.Insert("ProcessedObjectCount", 0);
	ExchangeSettingsStructure.Insert("ExchangeMessage",           "");
	ExchangeSettingsStructure.Insert("ErrorMessageString",      "");
	
	Return ExchangeSettingsStructure;
EndFunction

// For an internal use.
// 
Procedure RunCheckOfMainFieldsOfExchangeSettingsStructure(ExchangeSettingsStructure)
	
	If Not ValueIsFilled(ExchangeSettingsStructure.InfobaseNode) Then
		
		// Infobase node should not be empty.
		ErrorMessageString = NStr("en='Infobase node with which information shall be exchanged is not specified. Exchange is canceled.';ru='Не задан узел информационной базы с которым нужно производить обмен информацией. Обмен отменен.'",
			CommonUseClientServer.MainLanguageCode());
		WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf Not ValueIsFilled(ExchangeSettingsStructure.ExchangeTransportKind) Then
		
		ErrorMessageString = NStr("en='Exchange transport kind is not specified. Exchange is canceled.';ru='Не задан вид транспорта обмена. Обмен отменен.'",
			CommonUseClientServer.MainLanguageCode());
		WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf Not ValueIsFilled(ExchangeSettingsStructure.ActionOnExchange) Then
		
		ErrorMessageString = NStr("en='Executed action (export/ import) is not specified. Exchange is canceled.';ru='Не указано выполняемое действие (выгрузка / загрузка). Обмен отменен.'",
			CommonUseClientServer.MainLanguageCode());
		WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure RunExchangeStructureValidityCheck(ExchangeSettingsStructure, UseTransportSettings = True)
	
	If Not ValueIsFilled(ExchangeSettingsStructure.InfobaseNode) Then
		
		// Infobase node should not be empty.
		ErrorMessageString = NStr("en='Infobase node with which information shall be exchanged is not specified. Exchange is canceled.';ru='Не задан узел информационной базы с которым нужно производить обмен информацией. Обмен отменен.'",
			CommonUseClientServer.MainLanguageCode());
		WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf UseTransportSettings AND Not ValueIsFilled(ExchangeSettingsStructure.ExchangeTransportKind) Then
		
		ErrorMessageString = NStr("en='Exchange transport kind is not specified. Exchange is canceled.';ru='Не задан вид транспорта обмена. Обмен отменен.'",
			CommonUseClientServer.MainLanguageCode());
		WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf Not ValueIsFilled(ExchangeSettingsStructure.ActionOnExchange) Then
		
		ErrorMessageString = NStr("en='Executed action (export/ import) is not specified. Exchange is canceled.';ru='Не указано выполняемое действие (выгрузка / загрузка). Обмен отменен.'",
			CommonUseClientServer.MainLanguageCode());
		WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.InfobaseNode.DeletionMark Then
		
		// Infobase node should not be marked for deletion.
		ErrorMessageString = NStr("en='Infobase node is marked for deletion. Exchange is canceled.';ru='Узел информационной базы помечен на удаление. Обмен отменен.'",
			CommonUseClientServer.MainLanguageCode());
		WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
	
	ElsIf ExchangeSettingsStructure.InfobaseNode = ExchangeSettingsStructure.CurrentExchangePlanNode Then
		
		// Do not exchange data with yourself.
		ErrorMessageString = NStr("en='Unable to properly communicate with the current infobase node. The exchange has been canceled.';ru='Нельзя организовать обмен данными с текущим узлом информационной базы. Обмен отменен.'",
			CommonUseClientServer.MainLanguageCode());
		WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
	
	ElsIf IsBlankString(ExchangeSettingsStructure.InfobaseNodeCode)
		  OR IsBlankString(ExchangeSettingsStructure.CurrentExchangePlanNodeCode) Then
		
		// Nodes participating in the exchange should not have an empty code.
		ErrorMessageString = NStr("en='One of exchange nodes has an empty code. Exchange is canceled.';ru='Один из узлов обмена имеет пустой код. Обмен отменен.'",
			CommonUseClientServer.MainLanguageCode());
		WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.DebuggingExportHandlers Then
		
		ExportDataProcessorFile = New File(ExchangeSettingsStructure.FileNameOfExternalDataProcessorOfExportDebugging);
		
		If Not ExportDataProcessorFile.Exist() Then
			
			ErrorMessageString = NStr("en='External data processor file for export debugging does not exist. Exchange is canceled.';ru='Файл внешней обработки для отладки выгрузки не существует. Обмен отменен.'",
				CommonUseClientServer.MainLanguageCode());
			WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
			
			SetExchangeInitEnd(ExchangeSettingsStructure);
			
		EndIf;
		
	ElsIf ExchangeSettingsStructure.DebuggingImportHandlers Then
		
		ImportDataProcessorFile = New File(ExchangeSettingsStructure.FileNameOfExternalDataProcessorOfImportDebugging);
		
		If Not ImportDataProcessorFile.Exist() Then
			
			ErrorMessageString = NStr("en='External data processor file for import debugging does not exist. Exchange is canceled.';ru='Файл внешней обработки для отладки загрузки не существует. Обмен отменен.'",
				CommonUseClientServer.MainLanguageCode());
			WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
			
			SetExchangeInitEnd(ExchangeSettingsStructure);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure ExecuteExchangeProcessingInit(ExchangeSettingsStructure)
	
	// If settings contain errors, do not execute the initialization.
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	
	// create
	DataExchangeDataProcessor = DataProcessors.DistributedInfobaseObjectsConversion.Create();
	
	// initialization of properties
	DataExchangeDataProcessor.InfobaseNode          = ExchangeSettingsStructure.InfobaseNode;
	DataExchangeDataProcessor.ItemCountInTransaction  = ExchangeSettingsStructure.ItemCountInTransaction;
	DataExchangeDataProcessor.EventLogMonitorMessageKey = ExchangeSettingsStructure.EventLogMonitorMessageKey;
	
	ExchangeSettingsStructure.Insert("DataExchangeDataProcessor", DataExchangeDataProcessor);
	
EndProcedure

// For an internal use.
// 
Procedure ExecuteExchangeProcessingInitAccordingToConversionRules(ExchangeSettingsStructure)
	
	Var DataExchangeDataProcessor;
	
	// If settings contain errors, do not execute the initialization.
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	
	If ExchangeSettingsStructure.DoDataExport Then
		
		DataExchangeDataProcessor = GetDataExchangeForDumpDataProcessor(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.DoDataImport Then
		
		DataExchangeDataProcessor = GetDataExchangeForImportDataProcessor(ExchangeSettingsStructure);
		
	EndIf;
	
	ExchangeSettingsStructure.Insert("DataExchangeDataProcessor", DataExchangeDataProcessor);
	
EndProcedure

// For an internal use.
// 
Procedure RunInitOfProcessingOfExchangeMessagesTransport(ExchangeSettingsStructure)
	
	// Create transport processor.
	ExchangeMessageTransportDataProcessor = DataProcessors[ExchangeSettingsStructure.DataProcessorNameOfExchangeMessagesTransport].Create();
	
	IsOutgoingMessage = ExchangeSettingsStructure.DoDataExport;
	
	// Fill in general attributes similar to all transport processors.
	ExchangeMessageTransportDataProcessor.MessageFileTemplateName = GetMessageFileTemplateName(ExchangeSettingsStructure.CurrentExchangePlanNode, ExchangeSettingsStructure.InfobaseNode, IsOutgoingMessage);
	
	// Fill in transport settings that are different for each transport processor.
	FillPropertyValues(ExchangeMessageTransportDataProcessor, ExchangeSettingsStructure.TransportSettings);
	
	// Initialize transport
	ExchangeMessageTransportDataProcessor.Initialization();
	
	ExchangeSettingsStructure.Insert("ExchangeMessageTransportDataProcessor", ExchangeMessageTransportDataProcessor);
	
EndProcedure

// For an internal use.
// 
Function GetDataExchangeForDumpDataProcessor(ExchangeSettingsStructure)
	
	DataProcessorManager = ?(DataExchangeReUse.ThisIsExchangePlanXDTO(ExchangeSettingsStructure.InfobaseNode),
		DataProcessors.XDTOObjectsConversion,
		DataProcessors.InfobaseObjectsConversion);
	
	DataExchangeDataProcessor = DataProcessorManager.Create();
	
	DataExchangeDataProcessor.ExchangeMode = "Export";
	
	// If processor supports the conversion rules mechanism.
	If DataExchangeDataProcessor.Metadata().Attributes.Find("ExchangeRulesFilename") <> Undefined Then
		SetExchangeRulesOfDataDump(DataExchangeDataProcessor, ExchangeSettingsStructure);
		DataExchangeDataProcessor.DoNotDumpObjectsByRefs = True;
		DataExchangeDataProcessor.ExchangeRulesFilename        = "1";
	EndIf;
	
	// If processor supports background exchange mechanism.
	If DataExchangeDataProcessor.Metadata().Attributes.Find("NodeForBackgroundExchange") <> Undefined Then
		DataExchangeDataProcessor.NodeForBackgroundExchange = Undefined;
	EndIf;
		
	DataExchangeDataProcessor.NodeForExchange = ExchangeSettingsStructure.InfobaseNode;
	
	SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessor, ExchangeSettingsStructure);
	
	Return DataExchangeDataProcessor;
	
EndFunction

// For an internal use.
// 
Function GetDataExchangeForImportDataProcessor(ExchangeSettingsStructure)
	
	DataProcessorManager = ?(DataExchangeReUse.ThisIsExchangePlanXDTO(ExchangeSettingsStructure.InfobaseNode),
		DataProcessors.XDTOObjectsConversion,
		DataProcessors.InfobaseObjectsConversion);
	
	DataExchangeDataProcessor = DataProcessorManager.Create();
	
	DataExchangeDataProcessor.ExchangeMode = "Import";
	DataExchangeDataProcessor.ExchangeNodeForDataImport = ExchangeSettingsStructure.InfobaseNode;
	
	If DataExchangeDataProcessor.Metadata().Attributes.Find("ExchangeRulesFilename") <> Undefined Then
		SetDataImportExchangeRules(DataExchangeDataProcessor, ExchangeSettingsStructure);
	EndIf;
	
	SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessor, ExchangeSettingsStructure);
	
	Return DataExchangeDataProcessor
	
EndFunction

// For an internal use.
// 
Procedure SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessor, ExchangeSettingsStructure, SSL20Exchange = False)
	
	DataExchangeDataProcessor.AppendDataToExchangeProtocol = False;
	DataExchangeDataProcessor.ExportAllowedOnly      = False;
	
	DataExchangeDataProcessor.UseTransactions         = ExchangeSettingsStructure.ItemCountInTransaction <> 1;
	DataExchangeDataProcessor.ObjectsCountForTransactions = ExchangeSettingsStructure.ItemCountInTransaction;
	
	DataExchangeDataProcessor.EventLogMonitorMessageKey = ExchangeSettingsStructure.EventLogMonitorMessageKey;
	
	If Not SSL20Exchange Then
		
		SetDebuggingModeSettingsForDataProcessors(DataExchangeDataProcessor, ExchangeSettingsStructure);
		
	EndIf;
	
EndProcedure

Procedure SetExchangeRulesOfDataDump(DataExchangeXMLDataProcessor, ExchangeSettingsStructure)
	
	ObjectConversionRules = InformationRegisters.DataExchangeRules.GetReadObjectConversionRules(ExchangeSettingsStructure.ExchangePlanName);
	
	If ObjectConversionRules = Undefined Then
		
		// Exchange rules should be specified.
		NString = NStr("en='Conversion rules are not specified for exchange plan %1. Data export is canceled.';ru='Не заданы правила конвертации для плана обмена %1. Выгрузка данных отменена.'",
			CommonUseClientServer.MainLanguageCode());
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(NString, ExchangeSettingsStructure.ExchangePlanName);
		WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
		Return;
	EndIf;
	
	DataExchangeXMLDataProcessor.SavedSettings = ObjectConversionRules;
	
	Try
		DataExchangeXMLDataProcessor.RestoreRulesFromInternalFormat();
	Except
		WriteLogEventOfDataExchange(BriefErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		Return;
	EndTry;
	
EndProcedure

Procedure SetDataImportExchangeRules(DataExchangeXMLDataProcessor, ExchangeSettingsStructure)
	
	ObjectConversionRules = InformationRegisters.DataExchangeRules.GetReadObjectConversionRules(ExchangeSettingsStructure.ExchangePlanName, True);
	
	If ObjectConversionRules = Undefined Then
		
		// Exchange rules should be specified.
		NString = NStr("en='Conversion rules are not specified for exchange plan %1. Data import is canceled.';ru='Не заданы правила конвертации для плана обмена %1. Загрузка данных отменена.'",
			CommonUseClientServer.MainLanguageCode());
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(NString, ExchangeSettingsStructure.ExchangePlanName);
		WriteLogEventOfDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
		Return;
	EndIf;
	
	DataExchangeXMLDataProcessor.SavedSettings = ObjectConversionRules;
	
	Try
		DataExchangeXMLDataProcessor.RestoreRulesFromInternalFormat();
	Except
		WriteLogEventOfDataExchange(BriefErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		Return;
	EndTry;
	
EndProcedure

// Reads debugging settings from IB and sets them for the exchange structure.
//
Procedure SetDebuggingModeSettingsForStructure(ExchangeSettingsStructure, ThisExternalConnection = False)
	
	QueryText = "SELECT
	|	CASE
	|		WHEN &ToMakeExporting
	|			THEN DataExchangeRules.ExportDebuggingMode
	|		ELSE FALSE
	|	END AS DebuggingExportHandlers,
	|	CASE
	|		WHEN &ToMakeExporting
	|			THEN DataExchangeRules.DataProcessorFileNameForExportDebugging
	|		ELSE """"
	|	END AS FileNameOfExternalDataProcessorOfExportDebugging,
	|	CASE
	|		WHEN &ToExport
	|			THEN DataExchangeRules.ImportDebuggingMode
	|		ELSE FALSE
	|	END AS DebuggingImportHandlers,
	|	CASE
	|		WHEN &ToExport
	|			THEN DataExchangeRules.DataProcessorFileNameForImportDebugging
	|		ELSE """"
	|	END AS FileNameOfExternalDataProcessorOfImportDebugging,
	|	DataExchangeRules.DataExchangeLoggingMode AS DataExchangeLoggingMode,
	|	DataExchangeRules.ExchangeProtocolFileName AS ExchangeProtocolFileName,
	|	DataExchangeRules.DoNotStopOnError AS ContinueOnError
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND DataExchangeRules.DebugMode";
	
	Query = New Query;
	Query.Text = QueryText;
	
	DoDataExport = False;
	If Not ExchangeSettingsStructure.Property("DoDataExport", DoDataExport) Then
		DoDataExport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsAtExchange.DataExport);
	EndIf;
	
	DoDataImport = False;
	If Not ExchangeSettingsStructure.Property("DoDataImport", DoDataImport) Then
		DoDataImport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsAtExchange.DataImport);
	EndIf;
	
	Query.SetParameter("ExchangePlanName", ExchangeSettingsStructure.ExchangePlanName);
	Query.SetParameter("ToMakeExporting", DoDataExport);
	Query.SetParameter("ToExport", DoDataImport);
	
	Result = Query.Execute();
	
	LogFileName = "";
	If ThisExternalConnection AND ExchangeSettingsStructure.Property("ExchangeProtocolFileName", LogFileName)
		AND Not IsBlankString(LogFileName) Then
		
		ExchangeSettingsStructure.ExchangeProtocolFileName = AddLiteralToFileName(LogFileName, "ExternalConnection")
	
	EndIf;
	
	If Not Result.IsEmpty() AND Not CommonUseReUse.DataSeparationEnabled() Then
		
		SettingsTable = Result.Unload();
		TableRow = SettingsTable[0];
		
		FillPropertyValues(ExchangeSettingsStructure, TableRow);
		
	EndIf;
	
EndProcedure

// Reads debugging settings from IB and sets them for structure of the exchange settings.
//
Procedure SetDebuggingModeSettingsForDataProcessors(DataExchangeDataProcessor, ExchangeSettingsStructure)
	
	If ExchangeSettingsStructure.Property("FileNameOfExternalDataProcessorOfExportDebugging")
		AND DataExchangeDataProcessor.Metadata().Attributes.Find("FileNameOfExternalDataProcessorOfExportDebugging") <> Undefined Then
		
		DataExchangeDataProcessor.DebuggingExportHandlers = ExchangeSettingsStructure.DebuggingExportHandlers;
		DataExchangeDataProcessor.DebuggingImportHandlers = ExchangeSettingsStructure.DebuggingImportHandlers;
		DataExchangeDataProcessor.FileNameOfExternalDataProcessorOfExportDebugging = ExchangeSettingsStructure.FileNameOfExternalDataProcessorOfExportDebugging;
		DataExchangeDataProcessor.FileNameOfExternalDataProcessorOfImportDebugging = ExchangeSettingsStructure.FileNameOfExternalDataProcessorOfImportDebugging;
		DataExchangeDataProcessor.DataExchangeLoggingMode = ExchangeSettingsStructure.DataExchangeLoggingMode;
		DataExchangeDataProcessor.ExchangeProtocolFileName = ExchangeSettingsStructure.ExchangeProtocolFileName;
		DataExchangeDataProcessor.ContinueOnError = ExchangeSettingsStructure.ContinueOnError;
		
		If ExchangeSettingsStructure.DataExchangeLoggingMode Then
			
			If ExchangeSettingsStructure.ExchangeProtocolFileName = "" Then
				DataExchangeDataProcessor.InfoMessagesOutputToMessagesWindow = True;
				DataExchangeDataProcessor.OutputInInformationMessagesToProtocol = False;
			Else
				DataExchangeDataProcessor.InfoMessagesOutputToMessagesWindow = False;
				DataExchangeDataProcessor.OutputInInformationMessagesToProtocol = True;
				DataExchangeDataProcessor.ExchangeProtocolFileName = ExchangeSettingsStructure.ExchangeProtocolFileName;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Sets for processor of the export setting.
//
Procedure SetSettingsDebuggingExportingsForRulesExchange(DataExchangeDataProcessor, ExchangePlanName, DebugMode) Export
	
	QueryText = "SELECT
	|	DataExchangeRules.ExportDebuggingMode AS DebuggingExportHandlers,
	|	DataExchangeRules.DataProcessorFileNameForExportDebugging AS FileNameOfExternalDataProcessorOfExportDebugging
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND &DebugMode = TRUE";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	Query.SetParameter("DebugMode", DebugMode);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Or CommonUseReUse.DataSeparationEnabled() Then
		
		DataExchangeDataProcessor.DebuggingExportHandlers = False;
		DataExchangeDataProcessor.FileNameOfExternalDataProcessorOfExportDebugging = "";
		
	Else
		
		SettingsTable = Result.Unload();
		DebugSetting = SettingsTable[0];
		
		FillPropertyValues(DataExchangeDataProcessor, DebugSetting);
		
	EndIf;
	
EndProcedure

// Sets for the import setting processor.
//
Procedure SetSettingsDebuggingExportForRulesExchange(DataExchangeDataProcessor, ExchangePlanName) Export
	
	QueryText = "SELECT
	|	DataExchangeRules.ImportDebuggingMode AS DebuggingImportHandlers,
	|	DataExchangeRules.DataProcessorFileNameForImportDebugging AS FileNameOfExternalDataProcessorOfImportDebugging
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND DataExchangeRules.DebugMode";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Or CommonUseReUse.DataSeparationEnabled() Then
		
		DataExchangeDataProcessor.DebuggingImportHandlers = False;
		DataExchangeDataProcessor.FileNameOfExternalDataProcessorOfImportDebugging = "";
		
	Else
		
		SettingsTable = Result.Unload();
		DebugSetting = SettingsTable[0];
		
		FillPropertyValues(DataExchangeDataProcessor, DebugSetting);
		
	EndIf;
	
EndProcedure

// For an internal use.
// 
Procedure SetExchangeInitEnd(ExchangeSettingsStructure)
	
	ExchangeSettingsStructure.Cancel = True;
	ExchangeSettingsStructure.ExchangeProcessResult = Enums.ExchangeExecutionResult.Canceled;
	
EndProcedure

// For an internal use.
// 
Function GetMessageFileTemplateName(CurrentExchangePlanNode, InfobaseNode, IsOutgoingMessage)
	
	SenderNode = ?(IsOutgoingMessage, CurrentExchangePlanNode, InfobaseNode);
	RecipientNode  = ?(IsOutgoingMessage, InfobaseNode, CurrentExchangePlanNode);
	
	Return ExchangeMessageFileName(TrimAll(CommonUse.ObjectAttributeValue(SenderNode, "Code")),
									TrimAll(CommonUse.ObjectAttributeValue(RecipientNode, "Code")));
	//
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Quantity of items in transaction.

Function DataImportTransactionItemCount() Export
	
	SetPrivilegedMode(True);
	Return Constants.DataImportTransactionItemCount.Get();
	
EndFunction

Function DataExportTransactionItemCount() Export
	
	Return 1;
	
EndFunction

Function ItemsQuantityInExecutedActionTransaction(Action)
	
	If Action = Enums.ActionsAtExchange.DataExport Then
		ItemCount = DataExportTransactionItemCount();
	Else
		ItemCount = DataImportTransactionItemCount();
	EndIf;
	
	Return ItemCount;
	
EndFunction

Procedure SetDataImportItemsInTransactionQuantity(Quantity) Export
	
	SetPrivilegedMode(True);
	Constants.DataImportTransactionItemCount.Set(Quantity);
	
EndProcedure

Procedure AddTransactionItemCountToTransportSettings(Result) Export
	
	Result.Insert("DataExportTransactionItemCount", DataExportTransactionItemCount());
	Result.Insert("DataImportTransactionItemCount", DataImportTransactionItemCount());
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with the monitor of data exchange issues.

// For an internal use.
// 
Function CountProblemsDataExchange(ExchangeNodes = Undefined, ProblemType = Undefined,
	ConsiderWereIgnored = False, Period = Undefined, SearchString = "") Export
	
	Return InformationRegisters.DataExchangeResults.CountProblems(ExchangeNodes,
		ProblemType, ConsiderWereIgnored, Period, SearchString);
	
EndFunction

// For an internal use.
// 
Function VersioningProblemsCount(ExchangeNodes = Undefined, ThisIsCollisionsQuantity = Undefined,
	ConsiderWereIgnored = False, Period = Undefined, SearchString = "") Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		ObjectVersioningModule = CommonUse.CommonModule("ObjectVersioning");
		Return ObjectVersioningModule.CollisionsOrUnacceptedQuantity(ExchangeNodes,
			ThisIsCollisionsQuantity, ConsiderWereIgnored, Period, SearchString);
	EndIf;
		
	Return 0;
	
EndFunction

// Registers errors occurred while delayed posting of the document in the exchange issues monitor.
//
// Parameters:
// Object - DocumentObject - Document on postponed posting of which errors occurreed.
// ExchangeNode - ExchangePlanRef - Infobase node from which the document is received.
// ErrorInfo - Error message for the events log monitor.
//
// Note: ErrorMessage contains a message text for the events log monitor.
// It is recommended to pass as this parameter ErrorBriefPresentation(InformationAboutError()).
// Message text for displaying on monitor is generated from the system
// messages to a user that have been generated but have not been output to a user yet. That is why it is
// recommended that the message buffer does not contain messages by the time of this method is called.
//
// Example of the procedure call while importing document to the infobase:
//
// Procedure PostDocumentOnImport(Document,
// ExchangeNode) Document.DataExchange.Load = True;
// Document.Write();
// Document.DataExchange.Load = False;
// Denial = False;
//
// Attempt
// 	Document.Write(DocumentWriteMode.Posting);
// Exception
// 	ErrorMessage = ErrorBriefPresentation (ErrorInfo());
// 	Denial = True;
// EndTry;
//
// If Denial
// 	Then RegisterDocumentPostingError(Document ExchangeNode, ErrorMessage);
// EndIf;
//
// EndProcedure;
//
Procedure RegisterErrorDocument(Object, ExchangeNode, ErrorMessage) Export
	
	UserMessages = GetUserMessages(True);
	MessageText = ErrorMessage;
	For Each Message IN UserMessages Do
		MessageText = MessageText + ?(IsBlankString(MessageText), "", Chars.LF) + Message.Text;
	EndDo;
	
	CauseErrors = MessageText;
	If Not IsBlankString(TrimAll(MessageText)) Then
		
		CauseErrors = NStr("en=' Due to %1.';ru=' По причине %1.'");
		CauseErrors = StringFunctionsClientServer.SubstituteParametersInString(CauseErrors, MessageText);
		
	EndIf;
	
	MessageString = NStr("en='Cannot post document %1 received from another infobase.%2 Maybe not all required attributes are filled in.';ru='Не удалось провести документ %1, полученный из другой информационной базы.%2 Возможно не заполнены все реквизиты, обязательные к заполнению.'",
		CommonUseClientServer.MainLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(Object), CauseErrors);
	
	WriteLogEvent(EventLogMonitorMessageTextDataExchange(), EventLogLevel.Warning,,, MessageString);
	
	InformationRegisters.DataExchangeResults.RegisterErrorChecksObject(Object.Ref, ExchangeNode,
		MessageText, Enums.DataExchangeProblemTypes.UnpostedDocument);
	
EndProcedure

// Registers errors that occur if the object record is postponed in the exchange issues monitor.
//
// Parameters:
// Object - Object of the reference type - Errors occurred while postponed writing the object.
// ExchangeNode - ExchangePlanRef - Infobase node from which the object is received.
// ErrorInfo - Error message for the events log monitor.
//
// Note: ErrorMessage contains a message text for the events log monitor.
// It is recommended to pass as this parameter ErrorBriefPresentation(InformationAboutError()).
// Message text for displaying on monitor is generated from the system
// messages to a user that have been generated but have not been output to a user yet. That is why it is
// recommended that the message buffer does not contain messages by the time of this method is called.
//
// Example of procedure call during object writing to the infobase:
//
// Procedure WriteObjectOnImport
// (Object, ExchangeNode) Object.DataExchange.Load = True;
// Object.Write();
// Object.DataExchange.Load = False;
// Denial = False;
//
// Try
// 	Object.Write();
// Exception
// 	ErrorMessage = ErrorBriefPresentation (ErrorInfo());
// 	Denial = True;
// EndTry;
//
// If Denial
// 	Then RegisterObjectWriteError (Object, ExchangeNode, ErrorMessage);
// EndIf;
//
// EndProcedure;
//
Procedure RegisterErrorRecordsObject(Object, ExchangeNode, ErrorMessage) Export
	
	UserMessages = GetUserMessages(True);
	MessageText = ErrorMessage;
	For Each Message IN UserMessages Do
		MessageText = MessageText + ?(IsBlankString(MessageText), "", Chars.LF) + Message.Text;
	EndDo;
	
	CauseErrors = MessageText;
	If Not IsBlankString(TrimAll(MessageText)) Then
		
		CauseErrors = NStr("en=' Due to %1.';ru=' По причине %1.'");
		CauseErrors = StringFunctionsClientServer.SubstituteParametersInString(CauseErrors, MessageText);
		
	EndIf;
	
	MessageString = NStr("en='Cannot write object %1 received from another infobase. %2 Maybe not all required attributes are filled in.';ru='Не удалось записать объект %1, полученный из другой информационной базы.%2 Возможно не заполнены все реквизиты, обязательные к заполнению.'",
		CommonUseClientServer.MainLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(Object), CauseErrors);
	
	WriteLogEvent(EventLogMonitorMessageTextDataExchange(), EventLogLevel.Warning,,, MessageString);
	
	InformationRegisters.DataExchangeResults.RegisterErrorChecksObject(Object.Ref, ExchangeNode,
		MessageText, Enums.DataExchangeProblemTypes.BlankAttributes);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// For an internal use.
// 
Function QueryResultIntoStructure(Val QueryResult) Export
	
	Result = New Structure;
	For Each Column IN QueryResult.Columns Do
		Result.Insert(Column.Name);
	EndDo;
	
	If QueryResult.IsEmpty() Then
		Return Result;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	FillPropertyValues(Result, Selection);
	
	Return Result;
EndFunction

// For an internal use.
// 
Function ValuesTableFromValueTree(Tree)
	
	Result = New ValueTable;
	
	For Each Column IN Tree.Columns Do
		
		Result.Columns.Add(Column.Name, Column.ValueType);
		
	EndDo;
	
	ExpandValueTree(Result, Tree.Rows);
	
	Return Result;
EndFunction

// For an internal use.
// 
Procedure ExpandValueTree(Table, Tree)
	
	For Each TreeRow IN Tree Do
		
		FillPropertyValues(Table.Add(), TreeRow);
		
		If TreeRow.Rows.Count() > 0 Then
			
			ExpandValueTree(Table, TreeRow.Rows);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns presentation of the synchronization date.
//
// Parameters:
// SynchronizationDate - Date. Absolute date of the data synchronization.
//
Function SynchronizationDatePresentation(Val SynchronizationDate) Export
	
	If Not ValueIsFilled(SynchronizationDate) Then
		Return NStr("en='Synchronization has never been performed.';ru='Синхронизация не выполнялась.'");
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Last synchronization: %1';ru='Последняя синхронизация: %1'"),
		RelativeSynchronizationDate(SynchronizationDate));
EndFunction

// Returns presentation of the relative synchronization date.
//
// Parameters:
// SynchronizationDate - Date. Absolute date of the data synchronization.
//
// Intervals of time:
//  Never             (T = empty date).
//  Now              (T < 5 min)
//  5 minutes ago (5 min < T < 15 min) 15 minutes ago
//  (15 min < T < 30 min) 30 minutes ago (30 min
//  < T < 1 hour)1 hour ago (1 hour < T < 2
//  hour) 2 hours ago (2 hour < T < 3 hour).
//  Today, 12:44:12 (3 hour < T < yesterday).
//  Yesterday, 22:30:45 (yesterday < T < day before yesterday).
//  Day before yesterday, 21:22:54 (the day before yesterday < T < two days before yesterday).
//  <March 12, 2012> (two days before yesterday < T).
//
Function RelativeSynchronizationDate(Val SynchronizationDate) Export
	
	If Not ValueIsFilled(SynchronizationDate) Then
		
		Return NStr("en='Never';ru='Никогда'");
		
	EndIf;
	
	DateCurrent = CurrentSessionDate();
	
	Interval = DateCurrent - SynchronizationDate;
	
	If Interval < 0 Then // 0 min
		
		Result = Format(SynchronizationDate, "DLF=DD");
		
	ElsIf Interval < 60 * 5 Then // 5 min
		
		Result = NStr("en='Now';ru='Сейчас'");
		
	ElsIf Interval < 60 * 15 Then // 15 min
		
		Result = NStr("en='5 minutes ago';ru='5 минут назад'");
		
	ElsIf Interval < 60 * 30 Then // 30 min
		
		Result = NStr("en='15 minutes ago';ru='15 минут назад'");
		
	ElsIf Interval < 60 * 60 * 1 Then // 1 hour
		
		Result = NStr("en='30 minutes ago';ru='30 минут назад'");
		
	ElsIf Interval < 60 * 60 * 2 Then // 2 hours
		
		Result = NStr("en='1 hour ago';ru='1 час назад'");
		
	ElsIf Interval < 60 * 60 * 3 Then // 3 hours
		
		Result = NStr("en='2 hours ago';ru='2 часа назад'");
		
	Else
		
		DaysNumberDifference = DaysNumberDifference(SynchronizationDate, DateCurrent);
		
		If DaysNumberDifference = 0 Then // today
			
			Result = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Today, %1';ru='Сегодня, %1'"), Format(SynchronizationDate, "DLF=T"));
			
		ElsIf DaysNumberDifference = 1 Then // yesterday
			
			Result = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Yesterday, %1';ru='Вчера, %1'"), Format(SynchronizationDate, "DLF=T"));
			
		ElsIf DaysNumberDifference = 2 Then // day before yesterday
			
			Result = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Day before yesterday, %1';ru='Позавчера, %1'"), Format(SynchronizationDate, "DLF=T"));
			
		Else // long ago
			
			Result = Format(SynchronizationDate, "DLF=DD");
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

Function DaysNumberDifference(Val Date1, Val Date2)
	
	Return Int((BegOfDay(Date2) - BegOfDay(Date1)) / 86400);
	
EndFunction

// For an internal use.
//
Procedure FillValueTable(Receiver, Val Source) Export
	Receiver.Clear();
	
	If TypeOf(Source)=Type("ValueTable") Then
		SourceColumn = Source.Columns;
	Else
		Temp = Source.Unload(New Array);
		SourceColumn = Temp.Columns;
	EndIf;
	
	If TypeOf(Receiver)=Type("ValueTable") Then
		ColumnsOfReceiver = Receiver.Columns;
		ColumnsOfReceiver.Clear();
		For Each Column IN SourceColumn Do
			FillPropertyValues(ColumnsOfReceiver.Add(), Column);
		EndDo;
	EndIf;
	
	For Each String IN Source Do
		FillPropertyValues(Receiver.Add(), String);
	EndDo;
EndProcedure

Function TableToStructureArray(Val ValueTable)
	Result = New Array;
	
	ColumnNames = "";
	For Each Column IN ValueTable.Columns Do
		ColumnNames = ColumnNames + "," + Column.Name;
	EndDo;
	ColumnNames = Mid(ColumnNames, 2);
	
	For Each String IN ValueTable Do
		StringStructure = New Structure(ColumnNames);
		FillPropertyValues(StringStructure, String);
		Result.Add(StringStructure);
	EndDo;
	
	Return Result;
EndFunction

// Check the difference of the correspondent version in rules of the current and another application.
//
Function CorrespondentVersionsDiffer(ExchangePlanName, EventLogMonitorMessageKey, VersionInThisApplication,
	VersionInAnotherApplication, MessageText, ExternalConnectionParameters = Undefined) Export
	
	VersionInThisApplication = ?(ValueIsFilled(VersionInThisApplication), VersionInThisApplication, CorrespondentVersionInRules(ExchangePlanName));
	
	If ValueIsFilled(VersionInThisApplication) AND ValueIsFilled(VersionInAnotherApplication)
		AND ExchangePlanSettingValue(ExchangePlanName, "WarnAboutExchangeRulesVersionsMismatch") Then
		
		VersionInThisApplicationWithoutBuildNumber = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(VersionInThisApplication);
		VersionInAnotherApplicationWithoutBuildNumber = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(VersionInAnotherApplication);
		
		If VersionInThisApplicationWithoutBuildNumber <> VersionInAnotherApplicationWithoutBuildNumber Then
			
			ThisExternalConnection = (MessageText = "ExternalConnection");
			
			ExchangePlanSynonym = Metadata.ExchangePlans[ExchangePlanName].Synonym;
			
			MessagePattern = NStr("en='Data may be synced incorrectly because version of application ""%1"" (%2) is different from the version %3 specified in conversion rules of another application. Make sure that you imported the rules relevant for both applications.';ru='Синхронизация данных может быть выполнена некорректно, т.к. версия программы ""%1"" (%2) в правилах конвертации этой программы отличается от версии %3 в правилах конвертации в другой программе. Убедитесь, что загружены актуальные правила, подходящие для используемых версий обеих программ.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ExchangePlanSynonym, VersionInThisApplicationWithoutBuildNumber, VersionInAnotherApplicationWithoutBuildNumber);
			
			WriteLogEvent(EventLogMonitorMessageKey, EventLogLevel.Warning,,, MessageText);
			
			If ExternalConnectionParameters <> Undefined
				AND CommonUseClientServer.CompareVersions("2.2.3.18", ExternalConnectionParameters.SSLVersionForExternalConnection) <= 0
				AND ExternalConnectionParameters.ExternalConnection.DataExchangeExternalConnection.WarnAboutExchangeRulesVersionsMismatch(ExchangePlanName) Then
				
				AnotherApplicationExchangePlanSynonym = ExternalConnectionParameters.InfobaseNode.Metadata().Synonym;
				MessageTextExternalConnection = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
					AnotherApplicationExchangePlanSynonym, VersionInAnotherApplicationWithoutBuildNumber, VersionInThisApplicationWithoutBuildNumber);
				
				ExternalConnectionParameters.ExternalConnection.WriteLogEvent(ExternalConnectionParameters.EventLogMonitorMessageKey,
					ExternalConnectionParameters.ExternalConnection.EventLogLevel.Warning,,, MessageTextExternalConnection);
				
			EndIf;
			
			If SessionParameters.VersionsDifferenceErrorOnReceivingData.CheckVersionDifference Then
				
				CheckStructure = New Structure(SessionParameters.VersionsDifferenceErrorOnReceivingData);
				CheckStructure.IsError = True;
				CheckStructure.ErrorText = MessageText;
				CheckStructure.CheckVersionDifference = False;
				SessionParameters.VersionsDifferenceErrorOnReceivingData = New FixedStructure(CheckStructure);
				Return True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return False;
	
EndFunction

// For an internal use.
// 
Function InitializeVersionDifferencesCheckParameters(CheckVersionDifference) Export
	
	SetPrivilegedMode(True);
	
	CheckStructure = New Structure(SessionParameters.VersionsDifferenceErrorOnReceivingData);
	CheckStructure.CheckVersionDifference = CheckVersionDifference;
	CheckStructure.IsError = False;
	SessionParameters.VersionsDifferenceErrorOnReceivingData = New FixedStructure(CheckStructure);
	
	Return SessionParameters.VersionsDifferenceErrorOnReceivingData;
	
EndFunction

// For an internal use.
// 
Function VersionsDifferenceErrorOnReceivingData() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.VersionsDifferenceErrorOnReceivingData;
	
EndFunction

Function CorrespondentVersionInRules(ExchangePlanName)
	
	Query = New Query;
	Query.Text = "SELECT
	|	DataExchangeRules.ReadOutRulesCorrespondent,
	|	DataExchangeRules.RuleKind
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RulesImported = TRUE
	|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)";
	
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		
		RuleStructure = Selection.ReadOutRulesCorrespondent.Get().Conversion;
		CorrespondentVersion = Undefined;
		RuleStructure.Property("SourceConfigurationVersion", CorrespondentVersion);
		
		Return CorrespondentVersion;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Constants

// Function-property: returns the literal of row of an unlimited length symbol.
//
// Returns:
//  String - literal of unlimited length row symbol.
//
Function OpenEndedString() Export
	
	Return "(uls)";
	
EndFunction

// Function-property: returns a literal of XML-node symbol that contains the value of PRO constant.
//
// Returns:
//  String - literal of XML-node symbol that contains PRO constant value.
//
Function FilterItemPropertyConstantValue() Export
	
	Return "ConstantValue";
	
EndFunction

// Function-property: returns the literal of XML-node symbol that contains algorithm of value receiving.
//
// Returns:
//  String - returns a literal of XML-node symbol that contains algorithm of getting value.
//
Function FilterItemPropertyValueAlgorithm() Export
	
	Return "ValueAlgorithm";
	
EndFunction

// Function-property: returns the name of the file that is used for checking the connection of transport processor.
//
// Returns:
//  String - returns the name of the file that is used to check connection of the transport processor.
//
Function FileNameOfVerificationOfConnection() Export
	
	Return "ConnectionCheckFile.tmp";
	
EndFunction

// For an internal use.
// 
Function InfobaseOperationModeFile() Export
	
	Return 0;
	
EndFunction

// For an internal use.
// 
Function InfobaseOperationModeClientServer() Export
	
	Return 1;
	
EndFunction

// For an internal use.
// 
Function IsErrorMessageNumberLessOrEqualToPreviouslyAcceptedMessageNumber(ErrorDescription)
	
	Return Find(Lower(ErrorDescription), Lower("en = 'Message number is lower or equals'")) > 0;
	
EndFunction

// For an internal use.
// 
Function EventLogMonitorMessageTextEstablishingConnectionToWebService() Export
	
	Return NStr("en='Data exchange.Connecting to web service';ru='Обмен данными.Установка подключения к web-сервису'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// For an internal use.
// 
Function DataExchangeRuleImportingEventLogMonitorMessageText() Export
	
	Return NStr("en='Data exchange.Rule import';ru='Обмен данными.Загрузка правил'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// For an internal use.
// 
Function DataExchangeCreationEventLogMonitorMessageText() Export
	
	Return NStr("en='Data exchang.Creating data exchange';ru='Обмен данными.Создание обмена данными'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// For an internal use.
// 
Function EventLogMonitorMessageTextRemovingTemporaryFile() Export
	
	Return NStr("en='Data exchange.Removing temporary file';ru='Обмен данными.Удаление временного файла'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// For an internal use.
// 
Function EventLogMonitorMessageTextDataExchange() Export
	
	Return NStr("en='Data exchange description';ru='Обмен данными описание'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Returns True if the configuration of DIB subordinate node infobase is required to be updated.
// IN the main node always - False.
// 
// Copy of the CommonUse.ConfigurationUpdateDIBSubordinateNodeRequired function.
// 
Function UpdateSettingRequired() Export
	
	Return IsSubordinateDIBNode() AND ConfigurationChanged();
	
EndFunction

// Returns the extended object presentation.
//
Function ObjectPresentation(ObjectParameter) Export
	
	If ObjectParameter = Undefined Then
		Return "";
	EndIf;
	ObjectMetadata = ?(TypeOf(ObjectParameter) = Type("String"), Metadata.FindByFullName(ObjectParameter), ObjectParameter);
	
	// There may not be any presentation attributes, bypass via structure.
	Presentation = New Structure("ExtendedObjectPresentation, ObjectPresentation");
	FillPropertyValues(Presentation, ObjectMetadata);
	If Not IsBlankString(Presentation.ExtendedObjectPresentation) Then
		Return Presentation.ExtendedObjectPresentation;
	ElsIf Not IsBlankString(Presentation.ObjectPresentation) Then
		Return Presentation.ObjectPresentation;
	EndIf;
	
	Return ObjectMetadata.Presentation();
EndFunction

// Returns the expanded presentation of the objects list.
//
Function SubmissionOfObjectsList(ObjectParameter) Export
	
	If ObjectParameter = Undefined Then
		Return "";
	EndIf;
	ObjectMetadata = ?(TypeOf(ObjectParameter) = Type("String"), Metadata.FindByFullName(ObjectParameter), ObjectParameter);
	
	// There may not be any presentation attributes, bypass via structure.
	Presentation = New Structure("ExtendedListPresentation, ListPresentation");
	FillPropertyValues(Presentation, ObjectMetadata);
	If Not IsBlankString(Presentation.ExtendedListPresentation) Then
		Return Presentation.ExtendedListPresentation;
	ElsIf Not IsBlankString(Presentation.ListPresentation) Then
		Return Presentation.ListPresentation;
	EndIf;
	
	Return ObjectMetadata.Presentation();
EndFunction

// Returns check box of export availability for the specified reference on node.
//
//  Parameters:
//      ExchangeNode             - ExchangePlanRef - exchange plan node possibility of export by which is checked.
//      Ref                 - Arbitrary     - checked object.
//      AdditionalProperties - Structure        - additional properties that are passed via object.
//
// Returns:
//  Boolean - check box of permission
//
Function ExportingReferencesPermitted(ExchangeNode, Ref, AdditionalProperties = Undefined) Export
	
	If Ref.IsEmpty() Then
		Return False;
	EndIf;
	
	RegistrationObject = Ref.GetObject();
	If RegistrationObject = Undefined Then
		// Object is deleted, it is always allowed.
		Return True;
	EndIf;
	
	If AdditionalProperties <> Undefined Then
		AttributesStructure = New Structure("AdditionalProperties");
		FillPropertyValues(AttributesStructure, RegistrationObject);
		AdditionalObjectProperties = AttributesStructure.AdditionalProperties;
		
		If TypeOf(AdditionalObjectProperties) = Type("Structure") Then
			For Each KeyValue IN AdditionalProperties Do
				AdditionalObjectProperties.Insert(KeyValue.Key, KeyValue.Value);
			EndDo;
		EndIf;
	EndIf;
	
	// Check if export is possibile.
	sending = DataItemSend.Auto;
	DataExchangeEvents.OnDataSendingToCorrespondent(RegistrationObject, sending, , ExchangeNode);
	Return sending = DataItemSend.Auto;
EndFunction

// Returns the check box of the export accessibility for the reference specified on node.
//
//  Parameters:
//      ExchangeNode - ExchangePlanRef - exchange plan node possibility of export by which is checked.
//      Ref     - Arbitrary     -  checked object.
//
// Returns:
//  Boolean - check box of permission
//
Function ExportRefFromInteractiveAdditionIsAllowed(ExchangeNode, Ref) Export
	
	AdditionalProperties = New Structure("InteractiveExportAddition", True);
	Return ExportingReferencesPermitted(ExchangeNode, Ref, AdditionalProperties);
	
EndFunction

// Wrappers of background procedures of export interactive change.
//
Procedure InteractiveExportChange_FormTableDocumentUser(Parameters, ResultAddress) Export
	
	ObjectOfReport = InteractiveExportChange_ObjectBySettings(Parameters.DataProcessorStructure);
	Result = ObjectOfReport.FormTableDocumentUser(Parameters.FullMetadataName, Parameters.Presentation, Parameters.SimplifiedMode);
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

// For an internal use.
// 
Procedure InteractiveExportChange_GenerateValueTree(Parameters, ResultAddress) Export
	
	ObjectOfReport = InteractiveExportChange_ObjectBySettings(Parameters.DataProcessorStructure);
	Result = ObjectOfReport.GenerateValueTree();
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

// For an internal use.
// 
Function InteractiveExportChange_ObjectBySettings(Val Settings)
	ObjectOfReport = DataProcessors.InteractiveExportChange.Create();
	
	FillPropertyValues(ObjectOfReport, Settings, , "ComposerAllDocumentsFilter");
	
	// Construct linker by pieces.
	Data = ObjectOfReport.SettingsComposerGeneralSelect();
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
	Composer.LoadSettings(Data.Settings);
	
	ObjectOfReport.ComposerAllDocumentsFilter = Composer;
	
	FilterItems = ObjectOfReport.ComposerAllDocumentsFilter.Settings.Filter.Items;
	FilterItems.Clear();
	ObjectOfReport.AddCompositionFilterValues(
		FilterItems, Settings.ComposerSettingsForAllSelectedDocuments.Filter.Items);
	
	Return ObjectOfReport;
EndFunction

// Returns the identifier of the transferred profile of the Data synchronization with other applications access groups.
//
// Returns:
//  String - identifier of the supplied profile of access groups.
//
Function ProfileSyncAccessDataWithOtherApplications() Export
	
	Return "04937803-5dba-11df-a1d4-005056c00008";
	
EndFunction

// Returns the list of profile roles of the Data synchronization with other applications access groups.
// 
Function ProfileRolesAccessSyncDataWithAnotherApplications()
	
	If CommonUse.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		Return "DataSynchronization, RemoteAccessBaseFunctionality, ReadingInformationAboutObjectsVersions";
	Else
		Return "DataSynchronization, DeletedAccessBaseFunctionality";
	EndIf;
	
EndFunction

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
// Procedures and functions for works with the DataExchangeMessageFromMainNode constant.
//

// Reads the data exchange information about message from the infobase.
//
// Returns - Structure - Information about exchange message file location (current format).
//                       - BinaryData - Exchange message in the infobase (outdated format).
//
Function GetDataExchangeMessageFromMainNode()
	
	Return Constants.DataExchangeMessageFromMainNode.Get().Get();
	
EndFunction

// Writes exchange message file received from the main node to the disk.
// Saves the path to a written message to the DataExchangeMessageFromMainNode constant.
//
// Parameters:
// ExchangeMessage - BinaryData - Read exchange message.
// MasterNode - ExchangePlanRef - Node from which the message was received.
//
Procedure SetDataExchangeMessageFromMainNode(ExchangeMessage, MasterNode) Export
	
	PathToFile = "[Directory][Path].xml";
	PathToFile = StrReplace(PathToFile, "[Directory]", TempFileStorageDirectory());
	PathToFile = StrReplace(PathToFile, "[Path]", New UUID);
	
	ExchangeMessage.Write(PathToFile);
	
	MessageStructure = New Structure;
	MessageStructure.Insert("PathToFile", PathToFile);
	
	Constants.DataExchangeMessageFromMainNode.Set(New ValueStorage(MessageStructure));
	
	WriteEventGetData(MasterNode, NStr("en='The exchange message was written to cache.';ru='Сообщение обмена записано в кэш.'"));
	
EndProcedure

// Deletes the exchange message file from the drive and clears the DataExchangeMessageFromMainNode constant.
//
Procedure ClearDataExchangeMessageFromMainNode() Export
	
	ExchangeMessage = GetDataExchangeMessageFromMainNode();
	
	If TypeOf(ExchangeMessage) = Type("Structure") Then
		
		DeleteFiles(ExchangeMessage.PathToFile);
		
	EndIf;
	
	Constants.DataExchangeMessageFromMainNode.Set(New ValueStorage(Undefined));
	
	WriteEventGetData(MasterNode(), NStr("en='The exchange message was deleted from cache.';ru='Сообщение обмена удалено из кэша.'"));
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
// Security profiles
//

Procedure GenerateQueriesOnExternalResourcesUse(PermissionsQueries)
	
	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	Constants.DataExchangeMessagesDirectoryForLinux.CreateValueManager().WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries);
	Constants.DataExchangeMessagesDirectoryForWindows.CreateValueManager().WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries);
	InformationRegisters.ExchangeTransportSettings.WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries);
	InformationRegisters.DataExchangeRules.WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries);
	
EndProcedure

Function QueryOnExternalResourcesUseWhenSharingEnabled() Export
	
	Queries = New Array();
	GenerateQueriesOnExternalResourcesUse(Queries);
	Return Queries;
	
EndFunction

Procedure ExternalResourcesQueryForDataExchangeMessagesDirectory(PermissionsQueries, Object) Export
	
	ConstantValue = Object.Value;
	If Not IsBlankString(ConstantValue) Then
		
		permissions = New Array();
		permissions.Add(WorkInSafeMode.PermissionToUseFileSystemDirectory(
			ConstantValue, True, True));
		
		PermissionsQueries.Add(
			WorkInSafeMode.QueryOnExternalResourcesUse(permissions,
				CommonUse.MetadataObjectID(Object.Metadata())));
		
	EndIf;
	
EndProcedure

Function QueryOnClearPermissionToUseExternalResources() Export
	
	Queries = New Array;
	
	For Each ExchangePlanName IN DataExchangeReUse.SSLExchangePlans() Do
		
		QueryText =
		"SELECT
		|	ExchangePlan.Ref AS Node
		|FROM
		|	ExchangePlan.[ExchangePlanName] AS ExchangePlan";
		
		QueryText = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlanName);
		
		Query = New Query;
		Query.Text = QueryText;
		
		Result = Query.Execute();
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			Queries.Add(WorkInSafeMode.QueryOnClearPermissionToUseExternalResources(Selection.Node));
			
		EndDo;
		
	EndDo;
	
	Queries.Add(WorkInSafeMode.QueryOnClearPermissionToUseExternalResources(
		CommonUse.MetadataObjectID(Metadata.Constants.DataExchangeMessagesDirectoryForLinux)));
	Queries.Add(WorkInSafeMode.QueryOnClearPermissionToUseExternalResources(
		CommonUse.MetadataObjectID(Metadata.Constants.DataExchangeMessagesDirectoryForWindows)));
	
	Return Queries;
	
EndFunction

// Returns template of security proattachment file name for the external module.
// Function should return the same value multiple times.
//
// Parameters:
//  ExternalModule - AnyRef, reference to the external module,
//
// Returns - String - pattern of the security
//  proattachment file name containing %1 characters instead of which a unique identifier will be substituted later.
//
Function SecurityProfileTemplateName(Val ExternalModule) Export
	
	Pattern = "Exchange_[ExchangePlanName]_%1"; // Not localized
	Return StrReplace(Pattern, "[ExchangePlanName]", ExternalModule.Name);
	
EndFunction

// Returns the icon that displays external module.
//
//  ExternalModule - AnyRef, reference to the external module,
//
// Returns - Picture.
//
Function ExternalModuleIcon(Val ExternalModule) Export
	
	Return PictureLib.DataSynchronization;
	
EndFunction

Function ExternalModuleContainerDictionary() Export
	
	Result = New Structure();
	
	Result.Insert("Nominative", NStr("en='Configure data synchronization';ru='Настройка синхронизация данных'"));
	Result.Insert("Genitive", NStr("en='Data synchronization settings';ru='Настройки синхронизации данных'"));
	
	Return Result;
	
EndFunction

Function ExternalModulesContainers() Export
	
	Result = New Array();
	DataExchangeOverridable.GetExchangePlans(Result);
	Return Result;
	
EndFunction

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
// SERVICE PROGRAM INTERFACE OF INTERACTIVE EXPORT ADDITION
//

// Initializes export addition for the stepped exchange.
//
// Parameters:
//     InfobaseNode - ExchangePlanRef                - ref to the node for which the setting is executed.
//     AddressOfFormStore    - String, UUID - address of saving between the server calls.
//     IsNodeScript       - Boolean                          - check box of the additional setting requirement.
//
// Returns:
//     Structure - data for the further export addition operation.
//
Function InteractiveExportChange(Val InfobaseNode, Val AddressOfFormStore, Val IsNodeScript=Undefined) Export
	
	Result = New Structure;
	Result.Insert("InfobaseNode", InfobaseNode);
	Result.Insert("ExportVariant", 0);
	
	Result.Insert("AllDocumentsFilterPeriod", New StandardPeriod);
	Result.AllDocumentsFilterPeriod.Variant = StandardPeriodVariant.LastMonth;
	
	ProcessingOfAddition = DataProcessors.InteractiveExportChange.Create();
	ProcessingOfAddition.InfobaseNode = InfobaseNode;
	ProcessingOfAddition.ExportVariant        = 0;
	
	// Compile linker by pieces.
	Data = ProcessingOfAddition.SettingsComposerGeneralSelect(AddressOfFormStore);
	Result.Insert("AddressLinkerAllDocuments", PutToTempStorage(Data, AddressOfFormStore));
	
	Result.Insert("AdditionalRegistration", New ValueTable);
	Columns = Result.AdditionalRegistration.Columns;
	
	StringType = New TypeDescription("String");
	Columns.Add("FullMetadataName", StringType);
	Columns.Add("Filter",         New TypeDescription("DataCompositionFilter"));
	Columns.Add("Period",        New TypeDescription("StandardPeriod"));
	Columns.Add("PeriodSelection",  New TypeDescription("Boolean"));
	Columns.Add("Presentation", StringType);
	Columns.Add("SelectionString",  StringType);
	Columns.Add("Quantity",    StringType);

	Result.Insert("ScriptParametersAdditions", New Structure);
	ScriptParametersAdditions = Result.ScriptParametersAdditions;
	
	ScriptParametersAdditions.Insert("VariantNoneAdds", New Structure("Use, Order, Title", True, 1));
	ScriptParametersAdditions.VariantNoneAdds.Insert("Explanation", 
		NStr("en='Only data according to general settings will be sent.';ru='Будут отправлены только данные согласно общим настройкам.'")
	); 
	
	ScriptParametersAdditions.Insert("VariantAllDocuments", New Structure("Use, Order, Title", True, 2));
	ScriptParametersAdditions.VariantAllDocuments.Insert("Explanation",
		NStr("en='All the period documents which satisfy the filter conditions will be sent additionally.';ru='Дополнительно будут отправлены все документы за период, удовлетворяющие условиям отбора.'")
	); 
	
	ScriptParametersAdditions.Insert("VariantArbitraryFilter", New Structure("Use, Order, Title", True, 3));
	ScriptParametersAdditions.VariantArbitraryFilter.Insert("Explanation",
		NStr("en='Data will be sent additionally according to the filter.';ru='Дополнительно будут отправлены данные согласно отбору.'")
	); 
	
	ScriptParametersAdditions.Insert("VariantAdditionally", New Structure("Use, Order, Title", False,   4));
	ScriptParametersAdditions.VariantAdditionally.Insert("Explanation",
		NStr("en='Additional data on settings will be sent.';ru='Будут отправлены дополнительные данные по настройкам.'")
	); 
	
	VariantAdditionally = ScriptParametersAdditions.VariantAdditionally;
	VariantAdditionally.Insert("Title", "");
	VariantAdditionally.Insert("UsePeriodFilter", False);
	VariantAdditionally.Insert("FilterPeriod");
	VariantAdditionally.Insert("Filter", Result.AdditionalRegistration.Copy());
	VariantAdditionally.Insert("FormNameFilter");
	VariantAdditionally.Insert("FormCommandTitle");
	
	MetaNode = InfobaseNode.Metadata();
	
	If IsNodeScript=Undefined Then
		// It can be defined by the node metadata.
		IsNodeScript = False;
	EndIf;
	
	If IsNodeScript Then
		
		ModuleNodeManager = ExchangePlans[MetaNode.Name];
		ModuleNodeManager.CustomizeInteractiveExporting(InfobaseNode, Result.ScriptParametersAdditions);
		
	EndIf;
	
	Result.Insert("AddressOfFormStore", AddressOfFormStore);
	Return Result;
EndFunction

// Clear filter of all documents.
//
// Parameters:
//     ExportAddition - Structure, FormsAttributeCollection - description of the export parameters.
//
Procedure InteractiveUpdateExportingsClearingGeneralFilter(ExportAddition) Export
	
	If IsBlankString(ExportAddition.AddressLinkerAllDocuments) Then
		ExportAddition.ComposerAllDocumentsFilter.Settings.Filter.Items.Clear();
	Else
		Data = GetFromTempStorage(ExportAddition.AddressLinkerAllDocuments);
		Data.Settings.Filter.Items.Clear();
		ExportAddition.AddressLinkerAllDocuments = PutToTempStorage(Data, ExportAddition.AddressOfFormStore);
		
		Composer = New DataCompositionSettingsComposer;
		Composer.Initialize(New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
		Composer.LoadSettings(Data.Settings);
		ExportAddition.ComposerAllDocumentsFilter = Composer;
	EndIf;
	
EndProcedure

// Clear detailed filter
//
// Parameters:
//     ExportAddition - Structure, FormsAttributeCollection - description of the export parameters.
//
Procedure InteractiveUpdateExportingsClearingInDetail(ExportAddition) Export
	ExportAddition.AdditionalRegistration.Clear();
EndProcedure

// Defines the description of the common filter. If the filter is empty, it returns an empty row.
//
// Parameters:
//     ExportAddition - Structure, FormsAttributeCollection - description of the export parameters.
//
// Returns:
//     String - filter description.
//
Function InteractiveChangeExportingDescriptionOfAdditionsOfCommonFilter(Val ExportAddition) Export
	
	ComposerData = GetFromTempStorage(ExportAddition.AddressLinkerAllDocuments);
	
	Source = New DataCompositionAvailableSettingsSource(ComposerData.CompositionSchema);
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(Source);
	Composer.LoadSettings(ComposerData.Settings);
	
	Return FilterPresentationExportAddition(Undefined, Composer, "");
EndFunction

// Specifies the description of a detailed filter. If the filter is empty, it returns an empty row.
//
// Parameters:
//     ExportAddition - Structure, FormsAttributeCollection - description of the export parameters.
//
// Returns:
//     String - filter description.
//
Function InteractiveChangeExportingDetailedFilterDescription(Val ExportAddition) Export
	Return PresentationDetailedAdditionOfExport(ExportAddition.AdditionalRegistration, "");
EndFunction

// Analyzes the history of settings-filters saved by a user for node.
//
// Parameters:
//     ExportAddition - Structure, FormsAttributeCollection - description of the export parameters.
//
// Returns:
//     List of values where presentation - setting name, value - setting data.
//
Function InteractiveUpdateExportingsHistorySettings(Val ExportAddition) Export
	ProcessingOfAddition = DataProcessors.InteractiveExportChange.Create();
	
	FilterOptions = InteractiveExchangeFilterOptionsExportings(ExportAddition);
	
	Return ProcessingOfAddition.ReadSettingsListPresentations(ExportAddition.InfobaseNode, FilterOptions);
EndFunction

// Restores the settings in ExportAddition attributes by the name of the saved setting.
//
// Parameters:
//     ExportAddition     - Structure, FormsAttributeCollection - description of the export parameters.
//     SettingRepresentation - String                            - name of the restored setting.
//
// Returns:
//     Boolean - True - restored successfully, False - setting is not found.
//
Function InteractiveUpdateExportingsResetSettings(ExportAddition, Val SettingRepresentation) Export
	
	ProcessingOfAddition = DataProcessors.InteractiveExportChange.Create();
	FillPropertyValues(ProcessingOfAddition, ExportAddition);
	
	FilterOptions = InteractiveExchangeFilterOptionsExportings(ExportAddition);
	
	// Restore the object state.
	Result = ProcessingOfAddition.RestoreCurrentFromSettings(SettingRepresentation, FilterOptions, ExportAddition.AddressOfFormStore);
	
	If Result Then
		FillPropertyValues(ExportAddition, ProcessingOfAddition, "ExportVariant, AllDocumentsFilterPeriod, AllDocumentsFilterLinker");
		
		// Always update the address of the linker.
		Data = ProcessingOfAddition.SettingsComposerGeneralSelect();
		Data.Settings = ExportAddition.ComposerAllDocumentsFilter.Settings;
		ExportAddition.AddressLinkerAllDocuments = PutToTempStorage(Data, ExportAddition.AddressOfFormStore);
		
		FillValueTable(ExportAddition.AdditionalRegistration, ProcessingOfAddition.AdditionalRegistration);
		
		// Update settings by the node script only if they are defined in the read. Otherwise, keep the current one.
		If ProcessingOfAddition.AdditionalRegistrationScriptSite.Count() > 0 Then
			FillPropertyValues(ExportAddition, ProcessingOfAddition, "NodeScriptFilterPeriod, NodeScriptFilterPresentation");
			FillValueTable(ExportAddition.AdditionalRegistrationScriptSite, ProcessingOfAddition.AdditionalRegistrationScriptSite);
			// Normalize the period settings.
			InteractiveExportingsChangeSetScriptNodePeriod(ExportAddition);
		EndIf;
		
		// Current presentation of the previously remembered settings.
		ExportAddition.ViewCurrentSettings = SettingRepresentation;
	EndIf;

	Return Result;
EndFunction

// Saves settings with the specified name by ExportAddition data.
//
// Parameters:
//     ExportAddition     - Structure, FormsAttributeCollection - description of the export parameters.
//     SettingRepresentation - String                            - name of the saved setting.
//
Procedure InteractiveUpdateExportingsSaveSettings(ExportAddition, Val SettingRepresentation) Export
	
	ProcessingOfAddition = DataProcessors.InteractiveExportChange.Create();
	FillPropertyValues(ProcessingOfAddition, ExportAddition);
	
	AttributesList = "
		|ExportVariant,
		|AllDocumentsFilterPeriod, NodeScriptFilterPeriod, NodeScriptFilterPresentation";
	
	FillPropertyValues(ProcessingOfAddition, ExportAddition, AttributesList);
	
	FillValueTable(ProcessingOfAddition.AdditionalRegistration,             ExportAddition.AdditionalRegistration);
	FillValueTable(ProcessingOfAddition.AdditionalRegistrationScriptSite, ExportAddition.AdditionalRegistrationScriptSite);
	
	// Compile the settings linker again.
	Data = ProcessingOfAddition.SettingsComposerGeneralSelect();
	
	If IsBlankString(ExportAddition.AddressLinkerAllDocuments) Then
		SettingsSource = ExportAddition.ComposerAllDocumentsFilter.Settings;
	Else
		LinkerStructure = GetFromTempStorage(ExportAddition.AddressLinkerAllDocuments);
		SettingsSource = LinkerStructure.Settings;
	EndIf;
		
	ProcessingOfAddition.ComposerAllDocumentsFilter = New DataCompositionSettingsComposer;
	ProcessingOfAddition.ComposerAllDocumentsFilter.Initialize( New DataCompositionAvailableSettingsSource(Data.CompositionSchema) );
	ProcessingOfAddition.ComposerAllDocumentsFilter.LoadSettings(SettingsSource);
	
	// Saving itself
	ProcessingOfAddition.SaveCurrentToSettings(SettingRepresentation);
	
	// Current presentation of remembered settings.
	ExportAddition.ViewCurrentSettings = SettingRepresentation;
EndProcedure

// Fills in the form attribute by the settings structure data.
//
// Parameters:
//     Form                       - ManagedForm - form for setting an attribute.
//     SettingsAdditionsExportings - Structure        - initial settings.
//     AdditionAttributeName      - String           - name of the form attribute for creation or filling.
//
Procedure InteractiveUpdateExportingsAttributeBySettings(Form, Val SettingsAdditionsExportings, Val AdditionAttributeName="ExportAddition") Export
	ScriptParametersAdditions = SettingsAdditionsExportings.ScriptParametersAdditions;
	
	// Deal with attributes
	AdditionsAttribute = Undefined;
	For Each Attribute IN Form.GetAttributes() Do
		If Attribute.Name=AdditionAttributeName Then
			AdditionsAttribute = Attribute;
			Break;
		EndIf;
	EndDo;
	
	// Check and add attribute.
	Adding = New Array;
	If AdditionsAttribute=Undefined Then
		AdditionsAttribute = New FormAttribute(AdditionAttributeName, 
			New TypeDescription("DataProcessorObject.InteractiveExportChange"));
			
		Adding.Add(AdditionsAttribute);
		Form.ChangeAttributes(Adding);
	EndIf;
	
	// Check and add columns of general additional registration.
	TableAttributePath = AdditionsAttribute.Name + ".AdditionalRegistration";
	If Form.GetAttributes(TableAttributePath).Count()=0 Then
		Adding.Clear();
		Columns = SettingsAdditionsExportings.AdditionalRegistration.Columns;
		For Each Column IN Columns Do
			Adding.Add(New FormAttribute(Column.Name, Column.ValueType, TableAttributePath));
		EndDo;
		Form.ChangeAttributes(Adding);
	EndIf;
	
	// Check and add columns of the additional registration of the node script.
	TableAttributePath = AdditionsAttribute.Name + ".NodeScriptAdditionalRegistration";
	If Form.GetAttributes(TableAttributePath).Count()=0 Then
		Adding.Clear();
		Columns = ScriptParametersAdditions.VariantAdditionally.Filter.Columns;
		For Each Column IN Columns Do
			Adding.Add(New FormAttribute(Column.Name, Column.ValueType, TableAttributePath));
		EndDo;
		Form.ChangeAttributes(Adding);
	EndIf;
	
	// Add data
	AttributeValue = Form[AdditionAttributeName];
	
	// Process the values tables.
	ValueToFormData(ScriptParametersAdditions.VariantAdditionally.Filter,
		AttributeValue.AdditionalRegistrationScriptSite);
	
	ScriptParametersAdditions.VariantAdditionally.Filter =TableToStructureArray(
		ScriptParametersAdditions.VariantAdditionally.Filter);
	
	AttributeValue.ScriptParametersAdditions = ScriptParametersAdditions;
	
	AttributeValue.InfobaseNode = SettingsAdditionsExportings.InfobaseNode;

	AttributeValue.ExportVariant                 = SettingsAdditionsExportings.ExportVariant;
	AttributeValue.AllDocumentsFilterPeriod      = SettingsAdditionsExportings.AllDocumentsFilterPeriod;
	
	Data = GetFromTempStorage(SettingsAdditionsExportings.AddressLinkerAllDocuments);
	DeleteFromTempStorage(SettingsAdditionsExportings.AddressLinkerAllDocuments);
	AttributeValue.AddressLinkerAllDocuments = PutToTempStorage(Data, Form.UUID);
	
	AttributeValue.NodeScriptFilterPeriod = ScriptParametersAdditions.VariantAdditionally.FilterPeriod;
	
	If ScriptParametersAdditions.VariantAdditionally.Use Then
		AttributeValue.NodeScriptFilterPresentation = PresentationOfExportingsNodeAdditions(AttributeValue);
	EndIf;
	
EndProcedure

// Returns the description of export by settings.
//
// Parameters:
//     ExportAddition - Structure, FormDataCollection - description of the export parameters.
//
// Returns:
//     String - presentation.
// 
Function PresentationOfExportingsNodeAdditions(Val ExportAddition) Export
	MetaNode = ExportAddition.InfobaseNode.Metadata();
	ManagerModule = ExchangePlans[MetaNode.Name];
	
	Parameters = New Structure;
	Parameters.Insert("UsePeriodFilter", ExportAddition.ScriptParametersAdditions.VariantAdditionally.UsePeriodFilter);
	Parameters.Insert("FilterPeriod",             ExportAddition.NodeScriptFilterPeriod);
	Parameters.Insert("Filter",                    ExportAddition.AdditionalRegistrationScriptSite);
	
	Return ManagerModule.FilterPresentationInteractiveExportings(ExportAddition.InfobaseNode, Parameters);
EndFunction

//  Returns description of the period and filter as a string.
//
//  Parameters:
//      Period:                the period for the filter description.
//      Filter:                 template data filter for description.
//      EmptyFilterDescription: value return in case of empty selection.
//
//  Returns:
//      String - description of period and filter.
//
Function FilterPresentationExportAddition(Val Period, Val Filter, Val DetailsOfEmptySelection=Undefined) Export
	
	OurFilter = ?(TypeOf(Filter)=Type("DataCompositionSettingsComposer"), Filter.Settings.Filter, Filter);
	
	PeriodString = ?(ValueIsFilled(Period), String(Period), "");
	SelectionString  = String(OurFilter);
	
	If IsBlankString(SelectionString) Then
		If DetailsOfEmptySelection=Undefined Then
			SelectionString = NStr("en='All objects';ru='Все объекты'");
		Else
			SelectionString = DetailsOfEmptySelection;
		EndIf;
	EndIf;
	
	If Not IsBlankString(PeriodString) Then
		SelectionString =  PeriodString + ", " + SelectionString;
	EndIf;
	
	Return SelectionString;
EndFunction

//  Returns description of a detailed filter by the AdditionalRegistration attribute.
//
//  Parameters:
//      AdditionalRegistration - ValuesTable, Array - Strings or structures describing the filter.
//      DetailsOfEmptySelection     - String                  - value return in case of an empty filter.
//
Function PresentationDetailedAdditionOfExport(Val AdditionalRegistration, Val DetailsOfEmptySelection=Undefined) Export
	
	Text = "";
	For Each String IN AdditionalRegistration Do
		Text = Text + Chars.LF + String.Presentation + ": " + FilterPresentationExportAddition(String.Period, String.Filter);
	EndDo;
	
	If Not IsBlankString(Text) Then
		Return TrimAll(Text);
		
	ElsIf DetailsOfEmptySelection=Undefined Then
		Return NStr("en='Additional data is not selected';ru='Дополнительные данные не выбраны'");
		
	EndIf;
	
	Return DetailsOfEmptySelection;
EndFunction

// Identifier of metadata objects service group "All documents".
//
Function ExportAdditionAllDocumentsID() Export
	// It can not overlap with the full name of metadata.
	Return "AllDocuments";
EndFunction

// Identifier of the service group of the All catalogs metadata objects.
//
Function ExportAdditionIDAllCatalogs() Export
	// It can not overlap with the full name of metadata.
	Return "AllCatalogs";
EndFunction

// Name for the saving and restoration settings during the online addition of export.
//
Function ExportAdditionNameAutoSaveSettings() Export
	Return NStr("en='Last sent (saved automatically)';ru='Последняя отправка (сохраняется автоматически)'");
EndFunction

// Additionally registers objects by settings.
//
// Parameters:
//     ExportAddition     - Structure, FormDataCollection - description of the export parameters.
//
Procedure InteractiveRegisterAdditionalExportingsDataUpdate(Val ExportAddition) Export
	
	If ExportAddition.ExportVariant <= 0 Then
		Return;
	EndIf;
	
	ObjectOfReport = DataProcessors.InteractiveExportChange.Create();
	FillPropertyValues(ObjectOfReport, ExportAddition,,"AdditionalRegistration, AdditionalRegistrationNodeScript");
		
	If ObjectOfReport.ExportVariant=1 Then
		// For the period with filter, additionally empty.
		
	ElsIf ExportAddition.ExportVariant=2 Then
		// Set in details
		ObjectOfReport.ComposerAllDocumentsFilter = Undefined;
		ObjectOfReport.AllDocumentsFilterPeriod      = Undefined;
		
		FillValueTable(ObjectOfReport.AdditionalRegistration, ExportAddition.AdditionalRegistration);
		
	ElsIf ExportAddition.ExportVariant=3 Then
		// By the node script, simulate the detailed.
		ObjectOfReport.ExportVariant = 2;
		
		ObjectOfReport.ComposerAllDocumentsFilter = Undefined;
		ObjectOfReport.AllDocumentsFilterPeriod      = Undefined;
		
		FillValueTable(ObjectOfReport.AdditionalRegistration, ExportAddition.AdditionalRegistrationScriptSite);
	EndIf;
	
	ObjectOfReport.RegisterAdditionalModifications();
EndProcedure

// Sets the general period to all filter profiles.
//
// Parameters:
//     ExportAddition - Structure, FormDataCollection - description of the export parameters.
//
Procedure InteractiveExportingsChangeSetScriptNodePeriod(ExportAddition) Export
	For Each String IN ExportAddition.AdditionalRegistrationScriptSite Do
		String.Period = ExportAddition.NodeScriptFilterPeriod;
	EndDo;
	
	// And update presentation
	ExportAddition.NodeScriptFilterPresentation = PresentationOfExportingsNodeAdditions(ExportAddition);
EndProcedure

// Returns used filter variants by the settinngs data.
//
// Parameters:
//     ExportAddition - Structure, FormDataCollection - description of the export parameters.
//
// Returns:
//     Array - with the numbers of used variants: 
//               0 - without filter, 1 - filter all documents, 2 - detailed, 3 - node script.
//
Function InteractiveExchangeFilterOptionsExportings(Val ExportAddition) Export
	
	Result = New Array;
	
	TestData = New Structure("ScriptParametersAdditions");
	FillPropertyValues(TestData, ExportAddition);
	ScriptParametersAdditions = TestData.ScriptParametersAdditions;
	If TypeOf(ScriptParametersAdditions)<>Type("Structure") Then
		// No settings, default values - all.
		Return Undefined;
	EndIf;
	
	If ScriptParametersAdditions.Property("VariantNoneAdds") 
		AND ScriptParametersAdditions.VariantNoneAdds.Use
	Then
		Result.Add(0);
	EndIf;
	
	If ScriptParametersAdditions.Property("VariantAllDocuments")
		AND ScriptParametersAdditions.VariantAllDocuments.Use 
	Then
		Result.Add(1);
	EndIf;
	
	If ScriptParametersAdditions.Property("VariantArbitraryFilter")
		AND ScriptParametersAdditions.VariantArbitraryFilter.Use 
	Then
		Result.Add(2);
	EndIf;
	
	If ScriptParametersAdditions.Property("VariantAdditionally")
		AND ScriptParametersAdditions.VariantAdditionally.Use 
	Then
		Result.Add(3);
	EndIf;
	
	If Result.Count()=4 Then
		// There are all variants, remove filter.
		Return Undefined;
	EndIf;

	Return Result;
EndFunction

// Parameter receives a secure connection.
//
Function SecureConnection(Path) Export
	
	Return ?(Lower(Left(Path, 4)) = "ftps", New OpenSSLSecureConnection, Undefined);
	
EndFunction

// Fills the user current work list.
//
// Parameters:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    * Identifier - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    * Important        - Boolean - If True, the work is marked in red.
//    * Presentation - String - a work presentation displayed to the user.
//    * Count    - Number  - a quantitative indicator of work, it is displayed in the work header string.
//    * Form         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner      - String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip     - String - The tooltip wording.
//
Procedure OnFillingToDoListForSynchronizationWarning(CurrentWorks)
	
	ModuleCurrentWorksService = CommonUse.CommonModule("CurrentWorksService");
	If Not AccessRight("view", Metadata.InformationRegisters.DataExchangeResults)
		Or ModuleCurrentWorksService.WorkDisabled("AlertOnSynchronization") Then
		Return;
	EndIf;
	ModuleCurrentWorksServer = CommonUse.CommonModule("CurrentWorksServer");
	
	CountOfPendingProblems = CountOfPendingProblems();
	
	// The procedure is called only if there is the
	// To-do lists subsystem, that is why here is no checking of subsystem existence.
	Sections = ModuleCurrentWorksServer.SectionsForObject(Metadata.CommonForms.DataExchanges.FullName());
	
	If Sections = Undefined Then
		Return;
	EndIf;
	
	For Each Section IN Sections Do
		
		AlertOnSynchronizationIdentifier = "AlertOnSynchronization" + StrReplace(Section.FullName(), ".", "");
		Work = CurrentWorks.Add();
		Work.ID  = AlertOnSynchronizationIdentifier;
		Work.ThereIsWork       = CountOfPendingProblems > 0;
		Work.Presentation  = NStr("en='Synchronization warnings';ru='Предупреждения при синхронизации'");
		Work.Quantity     = CountOfPendingProblems;
		Work.Form          = "InformationRegister.DataExchangeResults.Form.Form";
		Work.Owner       = Section;
		
	EndDo;
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    * Identifier - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    * Important        - Boolean - If True, the work is marked in red.
//    * Presentation - String - a work presentation displayed to the user.
//    * Count    - Number  - a quantitative indicator of work, it is displayed in the work header string.
//    * Form         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner      - String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip     - String - The tooltip wording.
//
Procedure OnFillingToDoListUpdateRequired(CurrentWorks)
	
	ModuleCurrentWorksService = CommonUse.CommonModule("CurrentWorksService");
	If Not AccessRight("Administration", Metadata)
		Or ModuleCurrentWorksService.WorkDisabled("UpdateRequiredDataExchange") Then
		Return;
	EndIf;
	ModuleCurrentWorksServer = CommonUse.CommonModule("CurrentWorksServer");
	
	UpdateSettingRequired = UpdateSettingRequired();
	
	// The procedure is called only if there is the
	// To-do lists subsystem, that is why here is no checking of subsystem existence.
	Sections = ModuleCurrentWorksServer.SectionsForObject(Metadata.CommonForms.DataExchanges.FullName());
	
	If Sections = Undefined Then
		Return;
	EndIf;
	
	For Each Section IN Sections Do
		
		IdentifierUpdateRequired = "UpdateRequiredDataExchange" + StrReplace(Section.FullName(), ".", "");
		Work = CurrentWorks.Add();
		Work.ID  = IdentifierUpdateRequired;
		Work.ThereIsWork       = UpdateSettingRequired;
		Work.Important         = True;
		Work.Presentation  = NStr("en='Update application version';ru='Обновить версию программы'");
		If CommonUse.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
			ModuleConfigurationUpdateClientServer = CommonUse.CommonModule("ConfigurationUpdateClientServer");
			FormParameters = New Structure("SystemWorkEnd, ConfigurationUpdateReceived", False, False);
			Work.Form      = ModuleConfigurationUpdateClientServer.DataProcessorFormNameConfigurationUpdate();
			Work.FormParameters = FormParameters;
		Else
			Work.Form      = "CommonForm.AdditionalDetails";
			Work.FormParameters = New Structure("Title,TemplateName",
				NStr("en='Install update';ru='Установка обновления'"), "InstructionHowToInstallUpdateManually");
		EndIf;
		Work.Owner       = Section;
		
	EndDo;
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    * Identifier - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    * Important        - Boolean - If True, the work is marked in red.
//    * Presentation - String - a work presentation displayed to the user.
//    * Count    - Number  - a quantitative indicator of work, it is displayed in the work header string.
//    * Form         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner      - String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip     - String - The tooltip wording.
//
Procedure OnFillCurrensTodosListCheckCompatibilityWithCurrentVersion(CurrentWorks)
	
	ModuleCurrentWorksService = CommonUse.CommonModule("CurrentWorksService");
	If Not AccessRight("Edit", Metadata.InformationRegisters.DataExchangeRules)
		Or ModuleCurrentWorksService.WorkDisabled("ExchangeRules") Then
		Return;
	EndIf;
	
	// If there is no administration section, the to-do is not added.
	Subsystem = Metadata.Subsystems.Find("Administration");
	If Subsystem <> Undefined
		AND Not AccessRight("view", Subsystem)
		AND Not CommonUse.MetadataObjectAvailableByFunctionalOptions(Subsystem) Then
		Return;
	EndIf;
	
	OutputToDo = True;
	CheckedForVersion = CommonSettingsStorage.Load("CurrentWorks", "ExchangePlans");
	If CheckedForVersion <> Undefined Then
		VersionArray  = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Metadata.Version, ".");
		CurrentVersion = VersionArray[0] + VersionArray[1] + VersionArray[2];
		If CheckedForVersion = CurrentVersion Then
			OutputToDo = False; // Additional reports and processors are checked on the current version.
		EndIf;
	EndIf;
	
	ExchangePlansWithRulesFromFile = ExchangePlansWithRulesFromFile();
	
	// Add to-do.
	Work = CurrentWorks.Add();
	Work.ID = "ExchangeRules";
	Work.ThereIsWork      = OutputToDo AND ExchangePlansWithRulesFromFile > 0;
	Work.Presentation = NStr("en='Exchange rules';ru='Правила обмена'");
	Work.Quantity    = ExchangePlansWithRulesFromFile;
	Work.Form         = "InformationRegister.DataExchangeRules.Form.ExchangePlanCheck";
	Work.Owner      = "CheckCompatibilityWithCurrentVersion";
	
	// Check if there is a to-do group. If there is no group - add.
	ToDosGroup = CurrentWorks.Find("CheckCompatibilityWithCurrentVersion", "ID");
	If ToDosGroup = Undefined Then
		ToDosGroup = CurrentWorks.Add();
		ToDosGroup.ID = "CheckCompatibilityWithCurrentVersion";
		ToDosGroup.ThereIsWork      = Work.ThereIsWork;
		ToDosGroup.Presentation = NStr("en='Check compatibility';ru='Проверить совместимость'");
		If Work.ThereIsWork Then
			ToDosGroup.Quantity = Work.Quantity;
		EndIf;
		ToDosGroup.Owner = Subsystem;
	Else
		If Not ToDosGroup.ThereIsWork Then
			ToDosGroup.ThereIsWork = Work.ThereIsWork;
		EndIf;
		
		If Work.ThereIsWork Then
			ToDosGroup.Quantity = ToDosGroup.Quantity + Work.Quantity;
		EndIf;
	EndIf;
	
EndProcedure

// For an internal use.
// 
Function StatisticsInformationTreeRowDataSynonym(TreeRow, SourceTypeAsString) 
	
	Synonym = TreeRow.Synonym;
	
	Filter = New Structure("FullName, Synonym", TreeRow.FullName, Synonym);
	Existing = TreeRow.Owner().Rows.FindRows(Filter, True);
	Quantity   = Existing.Count();
	If Quantity = 0 Or (Quantity = 1 AND Existing[0] = TreeRow) Then
		// There was no such description in this tree.
		Return Synonym;
	EndIf;
	
	Synonym = "[ReceiverTableSynonym] ([SourceTableName])"; // Not localized
	Synonym = StrReplace(Synonym, "[ReceiverTableSynonym]", TreeRow.Synonym);
	
	Return StrReplace(Synonym, "[SourceTableName]", DeleteClassNameFromObjectName(SourceTypeAsString));
EndFunction

Procedure DeleteFileFromStorage(FileID) Export
	
	DeleteFiles(TemporaryExportDirectory(FileID));
	
	// Delete information about the exchange message file from the storage.
	RecordStructure = New Structure;
	RecordStructure.Insert("MessageID", String(FileID));
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		
		ModuleDataExchangeSaaS = CommonUse.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnDeleteFileFromStorage(RecordStructure);
	Else
		
		OnDeleteFileFromStorage(RecordStructure);
		
	EndIf;
	
EndProcedure

// Delete file from storage.
//
Procedure OnDeleteFileFromStorage(Val RecordStructure)
	
	InformationRegisters.DataExchangeMessages.DeleteRecord(RecordStructure);
	
EndProcedure

Function TemporaryExportDirectory(Val SessionID)
	
	SetPrivilegedMode(True);
	
	TemporaryDirectory = "{SessionID}";
	TemporaryDirectory = StrReplace(TemporaryDirectory, "SessionID", String(SessionID));
	
	Result = CommonUseClientServer.GetFullFileName(DataExchangeReUse.TempFileStorageDirectory(), TemporaryDirectory);
	
	Return Result;
EndFunction

#EndRegion
