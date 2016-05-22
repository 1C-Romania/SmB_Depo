////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Exchanges data separately for each row of the exchange setting.
// Data exchange process consists of two stages:
// - exchange initialization - preparation of the exchange data subsystem to the exchange process
// - data exchange           - process of the message file reading and the subsequent import of
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
//  ExchangeExecutionSettings  - CatalogRef.DataExchangeScripts - item
//                              of the catalog by values of attributes of which the data exchange will be executed.
//  LineNumber                 - Number - String number according to which the data was exchanged.
//                              If it is not specified, the data exchange will be performed for all strings.
// 
Procedure ExecuteDataExchangeByScenarioOfExchangeData(Cancel, ExchangeExecutionSettings, LineNumber = Undefined) Export
	
	DataExchangeServer.ExecuteDataExchangeByScenarioOfExchangeData(Cancel, ExchangeExecutionSettings, LineNumber);
	
EndProcedure

//

// It checks the relevance of the object recording mechanism cache.
// If the cache is obsolete, the cache is initialized by the actual values.
//
// Parameters:
//  No.
// 
Procedure CheckObjectRegistrationMechanismCache() Export
	
	SetPrivilegedMode(True);
	
	If CommonUseReUse.CanUseSeparatedData() Then
		
		ActualDate = GetFunctionalOption("ReusableValuesActualUpdateDateORM");
		
		If SessionParameters.ReusableValuesUpdateDateORM <> ActualDate Then
			
			RefreshCacheMechanismForRegistrationOfObjects();
			
		EndIf;
		
	EndIf;
	
EndProcedure

// It updates/sets reused values and session parameters for the data exchange subsystem.
//
// Settable session parameters:
//   ObjectRegistrationRules - ValueStorage - it contains the value table with the object
//                                            recording rules in the binary form.
//   SelectiveObjectRegistrationRules - 
//   ReusableValuesUpdateDateORM - Date (Date and time) - It contains the
//                                                                         date of the last actual cache for the exchange data subsystem.
//
// Parameters:
//  No.
// 
Procedure RefreshCacheMechanismForRegistrationOfObjects() Export
	
	SetPrivilegedMode(True);
	
	RefreshReusableValues();
	
	If DataExchangeReUse.UsedExchangePlans().Count() > 0 Then
		
		SessionParameters.ObjectRegistrationRules = New ValueStorage(DataExchangeServer.GetObjectRegistrationRules());
		
		SessionParameters.SelectiveObjectRegistrationRules = New ValueStorage(DataExchangeServer.GetSelectiveObjectRegistrationRules());
		
	Else
		
		SessionParameters.ObjectRegistrationRules = New ValueStorage(DataExchangeServer.ObjectRegistrationRulesTableInitialization());
		
		SessionParameters.SelectiveObjectRegistrationRules = New ValueStorage(DataExchangeServer.ObjectSelectiveRegistrationRulesTableInitialization());
		
	EndIf;
	
	// Key to check cache relevance.
	SessionParameters.ReusableValuesUpdateDateORM = GetFunctionalOption("ReusableValuesActualUpdateDateORM");
	
EndProcedure

// It specifies the value of the ReusableValuesUpdateDateORM constant.
// The current computer (server) date is used as the set value.
// At the time of this constant change all reused values for the data exchange subsystem become obsolete and require repeat initialization.
//
// Parameters:
//  No.
// 
Procedure ResetCacheMechanismForRegistrationOfObjects() Export
	
	If CommonUseReUse.CanUseSeparatedData() Then
		
		SetPrivilegedMode(True);
		// Write the date and time the server computer - you
		// can not use CurrentData() CurrentSessionDate() method.
		// In this case the current server date is used as the cache uniqueness
		// key of the object recording mechanism.
		Constants.ReusableValuesUpdateDateORM.Set(CurrentDate());
		
	EndIf;
	
EndProcedure

//

// It imports the data of the exchange message located in the local file system of the server.
//
Procedure ImportInfobaseNodeViaFile(Cancel, Val InfobaseNode, Val ExchangeMessageFullFileName) Export
	
	Try
		DataExchangeServer.ExecuteDataExchangeForInfobaseNodeOverFileOrString(InfobaseNode, ExchangeMessageFullFileName, Enums.ActionsAtExchange.DataImport);
	Except
		Cancel = True;
	EndTry;
	
EndProcedure

// It fixes the successful data exchange in the system.
//
Procedure CommitDataExportExecutionInLongOperationMode(Val InfobaseNode, Val StartDate) Export
	
	SetPrivilegedMode(True);
	
	ActionOnExchange = Enums.ActionsAtExchange.DataExport;
	
	ExchangeSettingsStructure = New Structure;
	ExchangeSettingsStructure.Insert("InfobaseNode", InfobaseNode);
	ExchangeSettingsStructure.Insert("ExchangeProcessResult", Enums.ExchangeExecutionResult.Completed);
	ExchangeSettingsStructure.Insert("ActionOnExchange", ActionOnExchange);
	ExchangeSettingsStructure.Insert("ProcessedObjectCount", 0);
	ExchangeSettingsStructure.Insert("EventLogMonitorMessageKey", DataExchangeServer.GetEventLogMonitorMessageKey(InfobaseNode, ActionOnExchange));
	ExchangeSettingsStructure.Insert("StartDate", StartDate);
	ExchangeSettingsStructure.Insert("EndDate", CurrentSessionDate());
	ExchangeSettingsStructure.Insert("IsDIBExchange", DataExchangeReUse.ThisIsDistributedInformationBaseNode(InfobaseNode));
	
	DataExchangeServer.FixEndExchange(ExchangeSettingsStructure);
	
EndProcedure

// It fixes data exchange failure.
//
Procedure FixExchangeFinishedWithError(Val InfobaseNode,
												Val ActionOnExchange,
												Val StartDate,
												Val ErrorMessageString
	) Export
	
	SetPrivilegedMode(True);
	
	DataExchangeServer.FixExchangeFinishedWithError(InfobaseNode,
											ActionOnExchange,
											StartDate,
											ErrorMessageString);
EndProcedure

// Receives exchange message file from the base-correspondent via the web service.
// It imports the received exchange message file to this base.
//
Procedure ExecuteDataExchangeForInfobaseNodeFinishLongOperation(
															Cancel,
															Val InfobaseNode,
															Val FileID,
															Val OperationStartDate,
															Val AuthenticationParameters = Undefined
	) Export
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNodeFinishLongOperation(
															Cancel,
															InfobaseNode,
															FileID,
															OperationStartDate,
															AuthenticationParameters);
EndProcedure

// It makes an attempt to set the external connection using transferred connection parameters.
// If failed to establish external connection, the Cancel flag is set to true.
//
Procedure CheckExternalConnection(Cancel, SettingsStructure, ErrorAttachingAddIn = False) Export
	
	ErrorMessageString = "";
	
	// Make an attempt to set external join.
	Result = DataExchangeServer.InstallOuterDatabaseJoin(SettingsStructure);
	// Output an error message.
	If Result.Join = Undefined Then
		CommonUseClientServer.MessageToUser(Result.ErrorShortInfo,,,, Cancel);
	EndIf;
	ErrorAttachingAddIn = Result.ErrorAttachingAddIn;
	
EndProcedure

// It shows that the register record set does not contain data.
//
Function RecordSetRegisterIsEmpty(RecordStructure, RegisterName) Export
	
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
	
	RecordSet.Read();
	
	Return RecordSet.Count() = 0;
	
EndFunction

// It returns the event log message key by the action string.
//
Function GetEventLogMonitorMessageKeyByActionString(InfobaseNode, ExchangeActionString) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeServer.GetEventLogMonitorMessageKey(InfobaseNode, Enums.ActionsAtExchange[ExchangeActionString]);
	
EndFunction

// It returns the structure with the filter data for the log.
//
Function GetEventLogMonitorDataFilterStructureData(InfobaseNode, Val ActionOnExchange) Export
	
	If TypeOf(ActionOnExchange) = Type("String") Then
		
		ActionOnExchange = Enums.ActionsAtExchange[ActionOnExchange];
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	DataExchangeStatus = DataExchangeServer.DataExchangeStatus(InfobaseNode, ActionOnExchange);
	
	Filter = New Structure;
	Filter.Insert("EventLogMonitorEvent", DataExchangeServer.GetEventLogMonitorMessageKey(InfobaseNode, ActionOnExchange));
	Filter.Insert("StartDate",                DataExchangeStatus.StartDate);
	Filter.Insert("EndDate",             DataExchangeStatus.EndDate);
	
	Return Filter;
EndFunction

// It receives the code of the predefined exchange plan node.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as specified in the designer.
// 
// Returns:
//  String - code of the exchange plan predefined node.
//
Function GetThisNodeCodeForExchangePlan(ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeReUse.GetThisNodeCodeForExchangePlan(ExchangePlanName);
EndFunction

// It returns the array of all reference types specified in the configuration.
//
Function AllConfigurationReferenceTypes() Export
	
	Return DataExchangeReUse.AllConfigurationReferenceTypes();
	
EndFunction

// It returns the state background job performance.
// It is used to implement the logic of long running operations.
// 
// Parameters:
//  JobID - UUID - identifier of the background job
//                 for which you shall get the state.
// 
// Returns:
//  String - Background job performance state:
// "Active" - job in progress;
// "Completed" - the job is successfully completed;
// "Failed" - the job is completed with failure or canceled by the user.
//
Function JobState(Val JobID) Export
	
	Try
		Result = ?(LongActions.JobCompleted(JobID), "Completed", "Active");
	Except
		Result = "Failed";
		WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
	EndTry;
	
	Return Result;
EndFunction

// It receives the state long running operation (background job) performed in the correspondent base.
//
Function LongOperationState(Val ActionID,
									Val WebServiceURL,
									Val UserName,
									Val Password,
									ErrorMessageString = ""
	) Export
	
	Try
		
		ConnectionParameters = DataExchangeServer.WSParameterStructure();
		ConnectionParameters.WSURLWebService   = WebServiceURL;
		ConnectionParameters.WSUserName = UserName;
		ConnectionParameters.WSPassword          = Password;
		
		WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters, ErrorMessageString);
		
		If WSProxy = Undefined Then
			Raise ErrorMessageString;
		EndIf;
		
		Result = WSProxy.GetLongOperationState(ActionID, ErrorMessageString);
		
	Except
		Result = "Failed";
		WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
	EndTry;
	
	Return Result;
EndFunction

// It receives the state long-running operations (background job) performed
// in the correspondent database for the infobase node.
//
Function LongOperationStateForInfobaseNode(Val ActionID,
									Val InfobaseNode,
									Val AuthenticationParameters = Undefined,
									ErrorMessageString = ""
	) Export
	
	Try
		SetPrivilegedMode(True);
		
		ConnectionParameters = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(InfobaseNode, AuthenticationParameters);
		
		WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters, ErrorMessageString);
		
		If WSProxy = Undefined Then
			Raise ErrorMessageString;
		EndIf;
		
		Result = WSProxy.GetLongOperationState(ActionID, ErrorMessageString);
		
	Except
		Result = "Failed";
		WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
	EndTry;
	
	Return Result;
EndFunction

// It receives the exchange message from the correspondent database using the web service.
// It saves the received exchange message in the temporary directory.
//
Function GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebService(
											Cancel,
											InfobaseNode,
											FileID,
											LongOperation,
											ActionID,
											Val AuthenticationParameters = Undefined
	) Export
	
	Return DataExchangeServer.GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebService(
											Cancel,
											InfobaseNode,
											FileID,
											LongOperation,
											ActionID,
											AuthenticationParameters);
EndFunction

// It receives the exchange message from the correspondent database using the web service.
// It saves the received exchange message in the temporary directory.
// Used in case the message receipt is executed in the context of
// the background job in base-correspondent.
//
Function GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebServiceFinishLongOperation(
							Cancel,
							InfobaseNode,
							FileID,
							Val AuthenticationParameters = Undefined
	) Export
	
	Return DataExchangeServer.GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebServiceFinishLongOperation(
							Cancel,
							InfobaseNode,
							FileID,
							AuthenticationParameters);
EndFunction

// It returns the sign of the configuration change for the subordinate node of the distributed IB.
//
Function UpdateSettingRequired() Export
	
	DataExchangeServer.CheckIfExchangesPossible();
	
	SetPrivilegedMode(True);
	
	Return DataExchangeServer.UpdateSettingRequired();
	
EndFunction

// It deletes information of the object recording issues at the recording.
//
Procedure RegisterProblemSolving(Source, ProblemType, Val DeletionMarkNewValue) Export
	
	SetPrivilegedMode(True);
	
	If DataExchangeReUse.UsedExchangePlans().Count() > 0 Then
		
		RecordSetConflict = InformationRegisters.DataExchangeResults.CreateRecordSet();
		RecordSetConflict.Filter.ProblematicObject.Set(Source);
		RecordSetConflict.Filter.ProblemType.Set(ProblemType);
		
		RecordSetConflict.Read();
		
		If RecordSetConflict.Count() = 1 Then
			
			If DeletionMarkNewValue <> CommonUse.ObjectAttributeValue(Source, "DeletionMark") Then
				
				RecordSetConflict[0].DeletionMark = DeletionMarkNewValue;
				RecordSetConflict.Write();
				
			Else
				
				RecordSetConflict.Clear();
				RecordSetConflict.Write();
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Deletes data synchronization setting.
//
Procedure DeleteSynchronizationSetting(Val InfobaseNode) Export
	
	DataExchangeServer.CheckExchangesAdministrationPossibility();
	
	NodeObject = InfobaseNode.GetObject();
	If NodeObject = Undefined Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	NodeObject.Delete();
	
EndProcedure

Function VariantExchangeData(Val Correspondent) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeServer.VariantExchangeData(Correspondent);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Data exchange with the full rights.

// Sets the parameters of data exchange subsystem session.
//
// Parameters:
//  ParameterName - String - name of the session parameter the value of which shall be set.
//  SpecifiedParameters - array - this parameter includes info on the setup session parameters.
// 
Procedure SessionParametersSetting(ParameterName, SpecifiedParameters) Export
	
	// You shall initialize session parameters without addressing to the application work parameters.
	
	If ParameterName = "DataExchangeMessageImportModeBeforeStart" Then
		SessionParameters.DataExchangeMessageImportModeBeforeStart = New FixedStructure(New Structure);
		SpecifiedParameters.Add("DataExchangeMessageImportModeBeforeStart");
		Return;
	EndIf;
	
	If CommonUseReUse.CanUseSeparatedData() Then
		
		// Updating procedure for the reused values and session parameters.
		RefreshCacheMechanismForRegistrationOfObjects();
		
		// It records the names of the parameters set at
		// the execution of DataExchangeServerCall.UpdateObjectRecordingMechanismCache.
		SpecifiedParameters.Add("SelectiveObjectRegistrationRules");
		SpecifiedParameters.Add("ObjectRegistrationRules");
		SpecifiedParameters.Add("ReusableValuesUpdateDateORM");
		
		SessionParameters.DataSynchronizationPasswords = New FixedMap(New Map);
		SpecifiedParameters.Add("DataSynchronizationPasswords");
		
		SessionParameters.ExchangeDataPriority = New FixedArray(New Array);
		SpecifiedParameters.Add("ExchangeDataPriority");
		
		CheckStructure =New Structure;
		CheckStructure.Insert("CheckVersionDifference", False);
		CheckStructure.Insert("IsError", False);
		CheckStructure.Insert("ErrorText", "");
		
		SessionParameters.VersionsDifferenceErrorOnReceivingData = New FixedStructure(CheckStructure);
		SpecifiedParameters.Add("VersionsDifferenceErrorOnReceivingData");
		
	Else
		
		SessionParameters.DataSynchronizationPasswords = New FixedMap(New Map);
		SpecifiedParameters.Add("DataSynchronizationPasswords");
		
	EndIf;
	
EndProcedure

// It checks the start mode, sets the privileged mode and runs the handler.
//
Procedure ExecuteHandlerInPrivilegedMode(Value, Val HandlerLine) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("en = 'Method is not supported in the managed application mode.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Execute(HandlerLine);
	
EndProcedure

// It finds the scheduled job by GUID.
// 
// Parameters:
//  JobUUID - String - String with scheduled job GUID.
// 
// Returns:
//  Undefined    - if the search of scheduled job by GUID gave no results or
//  ScheduledJob - scheduled job found by GUID.
//
Function FindScheduledJobByParameter(Val JobUUID) Export
	
	If IsBlankString(JobUUID) Then
		Return Undefined;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return ScheduledJobs.FindByUUID(New UUID(JobUUID));
EndFunction

// It returns the structure with the object property values received using the IB request.
// Structure key - property name; Value - object property value.
//
// Parameters:
//  Ref - ref to the IB object which property values shall be received.
//
// Returns:
//  Structure - structure with the object property values.
//
Function GetPropertiesValuesForRef(Ref, PropertiesOfObject, Val ObjectPropertiesString, Val MetadataObjectName) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("en = 'Method is not supported in the managed application mode.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeEvents.GetPropertiesValuesForRef(Ref, PropertiesOfObject, ObjectPropertiesString, MetadataObjectName);
EndFunction

// It returns the array of exchange plan nodes by the specified request parameters and query text to the exchange plan table.
//
//
Function NodesArrayByPropertiesValues(PropertyValues, Val QueryText, Val ExchangePlanName, Val FlagAttributeName, Val Exporting = False) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("en = 'Method is not supported in the managed application mode.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeEvents.NodesArrayByPropertiesValues(PropertyValues, QueryText, ExchangePlanName, FlagAttributeName, Exporting);
EndFunction

// It returns the value of the ObjectRecordingRules session parameter received in the privileged mode.
//
// Returns:
//  ValueStorage - ObjectRecordingRules session parameter value.
//
Function SessionParametersObjectRegistrationRules() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.ObjectRegistrationRules;
	
EndFunction

// The function returns the list of all specified exchange plan nodes except for the predefined node.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name as specified in the designer for which
//                            you shall receive the node list.
//
//  Returns:
//   Array - list of all specified exchange plan nodes.
//
Function AllExchangePlanNodes(Val ExchangePlanName) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("en = 'Method is not supported in the managed application mode.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeReUse.GetExchangePlanNodesArray(ExchangePlanName);
	
EndFunction

// Returns the flag showing that the data change is recorded for the recipient.
//
Function ChangesRegistered(Val Recipient) Export
	
	QueryText =
	"SELECT TOP 1 1
	|FROM
	|	[Table].Changes AS ChangeTable
	|WHERE
	|	ChangeTable.Node = &Node";
	
	Query = New Query;
	Query.SetParameter("Node", Recipient);
	
	SetPrivilegedMode(True);
	
	ExchangePlanContent = Metadata.ExchangePlans[DataExchangeReUse.GetExchangePlanName(Recipient)].Content;
	
	For Each ContentItem IN ExchangePlanContent Do
		
		Query.Text = StrReplace(QueryText, "[Table]", ContentItem.Metadata.FullName());
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

// It returns the flag of the exchange plan usage during data exchange.
// If the exchange plan contains at least one node
// except for the predefined one, then it is considered to be used.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name as specified in the designer.
//
// Returns:
//  Boolean - True if the exchange plan is used; - no.
//
Function DataExchangeEnabled(Val ExchangePlanName, Val Sender) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeReUse.DataExchangeEnabled(ExchangePlanName, Sender);
EndFunction

// It receives the array of the exchange plan nodes for which the check box "Always export" is selected.
//
// Parameters:
//  ExchangePlanName  - String - name of an exchange plan as metadata object according to which the nodes are defined.
//  FlagAttributeName - String - name of the exchange plan attribute according to which a filter of nodes selection is set.
//
// Returns:
//  Array - exchange plan nodes for which the check box "Always export" flag is selected.
//
Function GetNodesArrayForRegistrationAlwaysExport(Val ExchangePlanName, Val FlagAttributeName) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("en = 'Method is not supported in the managed application mode.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeEvents.GetNodesArrayForRegistrationAlwaysExport(ExchangePlanName, FlagAttributeName);
EndFunction

// It receives the array of the exchange plan nodes for which the "Export if necessary" flag is selected.
//
// Parameters:
//  Ref - IB object reference for which it is necessary to receive the node array where the object was previously exported.
//  ExchangePlanName    - String - name of an exchange plan as metadata object according to which the nodes are defined.
//  FlagAttributeName - String - name of the exchange plan attribute according to which a filter of nodes selection is set.
//
// Returns:
//  Array - exchange plan nodes for which the "Export if necessary" check box is selected.
//
Function GetArrayOfNodesForRegistrationExportIfNeeded(Ref, Val ExchangePlanName, Val FlagAttributeName) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("en = 'Method is not supported in the managed application mode.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeEvents.GetArrayOfNodesForRegistrationExportIfNeeded(Ref, ExchangePlanName, FlagAttributeName);
EndFunction

// It returns the flag of the application work parameters import from the exchange message to the infobase.
// It is relevant for the DIB exchange at data exporting in the subordinate DIB node.
//
Function DataExchangeMessageImportModeBeforeStart(Property) Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.DataExchangeMessageImportModeBeforeStart.Property(Property);
	
EndFunction

// It returns the flag of error at start:
// 1) Error of exchange message loading:
//    - error of the metadata object ID importing at exchange message loading,
//    - error of metadata object ID check,
//    - error of the exchange mesage importing before IB updating,
//    - error of the exchange message importing before the IB updating in the mode when the version was not changed;
// 2) IB updating error after successful exchange message importing.
//
Function RetryDataExportExchangeMessagesBeforeStart() Export
	
	SetPrivilegedMode(True);
	
	Return Constants.RetryDataExportExchangeMessagesBeforeStart.Get() = True;
	
EndFunction

// It returns the list of priority exchange data.
//
// Returns:
//  Array - collection of references to exported priority exchange data.
//
Function ExchangeDataPriority() Export
	
	SetPrivilegedMode(True);
	
	Result = New Array;
	
	For Each Item IN SessionParameters.ExchangeDataPriority Do
		
		Result.Add(Item);
		
	EndDo;
	
	Return Result;
EndFunction

// It adds transferred data to the list of priority exchange data.
//
Procedure AddExchangePriorityData(Val Data) Export
	
	Result = ExchangeDataPriority();
	
	Result.Add(Data);
	
	SetPrivilegedMode(True);
	
	SessionParameters.ExchangeDataPriority = New FixedArray(Result);
	
EndProcedure

// It clears the list of priority exchange data.
//
Procedure ClearExchangeDataPriority() Export
	
	SetPrivilegedMode(True);
	
	SessionParameters.ExchangeDataPriority = New FixedArray(New Array);
	
EndProcedure

// It receives the list of the node metadata objects for which exporting is not allowed.
// Exporting is not allowed if the table is marked as DoNotExported in the object recording rules of the exchange plan.
//
// Parameters:
//     InfobaseNode - ExchangePlanRef - ref to the analyzed exchange plan node.
//
// Returns:
//     The array containing full names of metadata objects.
//
Function NotExportedNodeObjectsMetadataNames(Val InfobaseNode) Export
	Result = New Array;
	
	DoNotExportMode = Enums.ExchangeObjectsExportModes.DoNotExport;
	ImportMode   = DataExchangeReUse.UserExchangePlanContent(InfobaseNode);
	For Each KeyValue IN ImportMode Do
		If KeyValue.Value=DoNotExportMode Then
			Result.Add(KeyValue.Key);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// It creates a request for node permissions clearing (when deleting).
//
Function QueryOnClearPermissionToUseExternalResources(Val InfobaseNode) Export
	
	Query = WorkInSafeMode.QueryOnClearPermissionToUseExternalResources(InfobaseNode);
	Return CommonUseClientServer.ValueInArray(Query);
	
EndFunction

#EndRegion
