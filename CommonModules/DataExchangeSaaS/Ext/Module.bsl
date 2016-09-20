
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\OnStart"].Add(
			"DataExchangeSaaSClient");
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\OnGetListOfWarningsToCompleteJobs"].Add(
			"DataExchangeSaaSClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"DataExchangeSaaS");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ServerHandlers["StandardSubsystems.SaaS.MessageExchange\OnDefenitionMessagesFeedHandlers"].Add(
			"DataExchangeSaaS");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers["StandardSubsystems.SaaS.JobQueue\WhenYouDefineAliasesHandlers"].Add(
			"DataExchangeSaaS");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ServerHandlers[
			"StandardSubsystems.SaaS\WhenCompletingTablesOfParametersOfIB"].Add(
				"DataExchangeSaaS");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSendDataToMaster"].Add(
		"DataExchangeSaaS");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromSubordinate"].Add(
		"DataExchangeSaaS");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnDefenitionSupportedVersionsOfSoftwareInterfaces"].Add(
		"DataExchangeSaaS");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsOnComplete"].Add(
		"DataExchangeSaaS");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsRunning"].Add(
		"DataExchangeSaaS");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
		"DataExchangeSaaS");
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers[
			"ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport"].Add(
				"DataExchangeSaaS");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObligatoryExchangePlanObjects"].Add(
		"DataExchangeSaaS");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObjectExceptionsOfExchangePlan"].Add(
		"DataExchangeSaaS");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGetPrimaryImagePlanExchangeObjects"].Add(
		"DataExchangeSaaS");
	
	ServerHandlers["StandardSubsystems.SaaS.MessageExchange\RegistrationOfReceivedMessageInterfaces"].Add(
		"DataExchangeSaaS");
	
	ServerHandlers["StandardSubsystems.SaaS.MessageExchange\RegistrationSendingMessageInterfaces"].Add(
		"DataExchangeSaaS");
		
	ServerHandlers["ServiceTechnology.SaaS.DataExchangeSaaS\OnCreatingIndependentWorkingPlace"].Add(
		"DataExchangeSaaS");
		
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.SuppliedData") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.SuppliedData\OnDefenitionHandlersProvidedData"].Add(
				"DataExchangeSaaS");
	EndIf;
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// DataExchangeSaaS: data exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceApplicationInterface

// It specifies the
// constant-flag of the data change and sends the message about the change with the number of the current area to the service manager.
//
Procedure SetDataChangeFlag() Export
	
	SetPrivilegedMode(True);
	
	DataArea = CommonUse.SessionSeparatorValue();
	
	BeginTransaction();
	Try
		MessageExchange.SendMessage("DataExchange\ManagementApplication\DataChangeFlag",
						New Structure("NodeCode", DataExchangeServer.ExchangePlanNodeCodeString(DataArea)),
						SaaSReUse.ServiceManagerEndPoint());
		
		Constants.DataChangesRecorded.Set(True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// It adds parameters of the client logic work for the data exchange subsystem in the service model
//
Procedure AddClientWorkParameters(Parameters) Export
	
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code at logout.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure AddClientWorkParametersOnComplete(Parameters) Export
	
	Parameters.Insert("OfflineWorkParameters", AutonomousWorkParametersOnExit());
	
EndProcedure

// Fills the transferred array with common modules which
//  comprise the handlers of received messages interfaces
//
// Parameters:
//  ArrayOfHandlers - array
//
Procedure RegistrationOfReceivedMessageInterfaces(ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessagesDataExchangeAdministrationControlInterface);
	ArrayOfHandlers.Add(MessagesDataExchangeAdministrationManagementInterface);
	ArrayOfHandlers.Add(MessageControlDataExchangeInterface);
	ArrayOfHandlers.Add(MessagesDataExchangeManagementInterface);
	
EndProcedure

// Fills the transferred array with the common modules
//  being the sent message interface handlers
//
// Parameters:
//  ArrayOfHandlers - array
//
Procedure RegistrationSendingMessageInterfaces(ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessagesDataExchangeAdministrationControlInterface);
	ArrayOfHandlers.Add(MessagesDataExchangeAdministrationManagementInterface);
	ArrayOfHandlers.Add(MessageControlDataExchangeInterface);
	ArrayOfHandlers.Add(MessagesDataExchangeManagementInterface);
	
EndProcedure

// IB update handlers.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		Handler = Handlers.Add();
		Handler.SharedData = True;
		Handler.HandlersManagement = True;
		Handler.Version = "*";
		Handler.PerformModes = "Promptly";
		Handler.Procedure = "DataExchangeSaaS.FillSeparatedDataHandlers";
		
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.SharedData = True;
		Handler.ExclusiveMode = False;
		Handler.Procedure = "DataExchangeSaaS.LockEndPoints";
		
		Handler = Handlers.Add();
		Handler.Version = "2.1.2.0";
		Handler.Procedure = "DataExchangeSaaS.MoveExchangeSettingsToDataStructure_2_1_2_0";
		
		Handler = Handlers.Add();
		Handler.Version = "2.1.2.12";
		Handler.SharedData = True;
		Handler.Procedure = "DataExchangeSaaS.SetSignRegisterChangesForAllDataAreas";
		
		Handler = Handlers.Add();
		Handler.Version = "2.1.3.22";
		Handler.SharedData = True;
		Handler.Procedure = "DataExchangeSaaS.MoveDataExchangeStatesData";
		
	EndIf;
	
EndProcedure

// Fills the separated data handler which is dependent on the change in unseparated data.
//
// Parameters:
//   Handlers - ValueTable, Undefined - see description 
//    of the NewUpdateHandlersTable function 
//    of the InfobaseUpdate common module.
//    For the direct call (not using the IB
//    version update mechanism) Undefined is passed.
// 
Procedure FillSeparatedDataHandlers(Parameters = Undefined) Export
	
	If Parameters <> Undefined AND ThereAreFixedNodeBlankCodes() Then
		Handlers = Parameters.SeparatedHandlers;
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.PerformModes = "Promptly";
		Handler.Procedure = "DataExchangeSaaS.SetPredefinedNodeCodes";
	EndIf;
	
EndProcedure

// It defines and sets the code and name of the predefined node
// for each exchange plan used in the service model.
// The code is generated based on the separator value.
// Description  - either using the application header or if it is empty, 
// using the presentation of the current data area from the InformationRegister.DataAreas register.
//
Procedure SetPredefinedNodeCodes() Export
	
	For Each ExchangePlan IN Metadata.ExchangePlans Do
		
		If DataExchangeSaaSReUse.IsDataSynchronizationExchangePlan(ExchangePlan.Name) Then
			
			ThisNode = ExchangePlans[ExchangePlan.Name].ThisNode();
			
			If IsBlankString(CommonUse.ObjectAttributeValue(ThisNode, "Code")) Then
				
				ThisNodeObject = ThisNode.GetObject();
				ThisNodeObject.Code = ExchangePlanNodeCodeInService(SaaSOperations.SessionSeparatorValue());
				ThisNodeObject.Description = TrimAll(GeneratePredefinedNodeDescription());
				ThisNodeObject.DataExchange.Load = True;
				ThisNodeObject.Write();
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// It converts exchange message transport settings from SSL 2.0.0 format to SSL 2.1.2 format
//
Procedure MoveExchangeSettingsToDataStructure_2_1_2_0() Export
	
	CorrespondentsEndPoints = DataStructureCorrespondentsEndPoints_2_1_2_0();
	
	Query = New Query;
	
	QueryText2 =
	"SELECT
	|	ExchangeTransportSettings.FILEInformationExchangeDirectory AS FILEInformationExchangeDirectory,
	|	ExchangeTransportSettings.WSURLWebService AS Address
	|FROM
	|	InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|WHERE
	|	ExchangeTransportSettings.Node = &Node";
	
	Query2 = New Query;
	Query2.Text = QueryText2;
	
	BeginTransaction();
	Try
		
		For Each ExchangePlanName IN DataExchangeReUse.SeparatedSSLExchangePlans() Do
			
			QueryText =
			"SELECT
			|	ExchangePlan.Ref AS Node
			|FROM
			|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
			|WHERE
			|	ExchangePlan.Ref <> &ThisNode";
			
			QueryText = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlanName);
			
			Query.SetParameter("ThisNode", ExchangePlans[ExchangePlanName].ThisNode());
			Query.Text = QueryText;
			
			QueryResult = Query.Execute();
			
			If Not QueryResult.IsEmpty() Then
				
				Selection = QueryResult.Select();
				
				While Selection.Next() Do
					
					Block = New DataLock;
					LockItem = Block.Add("InformationRegister.ExchangeTransportSettings");
					LockItem.SetValue("Node", Selection.Node);
					Block.Lock();
					
					Query2.SetParameter("Node", Selection.Node);
					
					QueryResult2 = Query2.Execute();
					
					If Not QueryResult2.IsEmpty() Then
						
						Selection2 = QueryResult2.Select();
						
						If Selection2.Next() Then
							
							CorrespondentEndPoint = CorrespondentsEndPoints[Selection2.Address];
							
							If CorrespondentEndPoint = Undefined Then
								
								Raise StringFunctionsClientServer.PlaceParametersIntoString(
									NStr("en='The correspondent end point is not defined for the address ""%1"".';ru='Не определена конечная точка корреспондента для адреса ""%1"".'"),
									Selection2.Address);
							EndIf;
							
							Record = New Structure;
							Record.Insert("Correspondent", Selection.Node);
							Record.Insert("CorrespondentEndPoint", CorrespondentEndPoint);
							Record.Insert("InformationExchangeDirectory", InformationExchangeDirectoryRelative(Selection2.FILEInformationExchangeDirectory));
							
							InformationRegisters.DataAreaTransportExchangeSettings.AddRecord(Record);
							
							DataExchangeServer.DeleteRecordSetInInformationRegister(New Structure("Node", Selection.Node), "ExchangeTransportSettings");
							
						EndIf;
						
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Sets the RecordChanges flag for all nodes of the separated BSP
// exchange plans except for the predefined ones for all data areas
//
// Parameters:
//  No.
// 
Procedure SetSignRegisterChangesForAllDataAreas() Export
	
	SeparatedSSLExchangePlans = DataExchangeReUse.SeparatedSSLExchangePlans();
	
	QueryText =
	"SELECT
	|	DataAreas.DataAreaAuxiliaryData AS DataArea
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|WHERE
	|	DataAreas.Status = VALUE(Enum.DataAreaStatuses.Used)";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		CommonUse.SetSessionSeparation(True, Selection.DataArea);
		
		For Each ExchangePlanName IN SeparatedSSLExchangePlans Do
			
			QueryText2 =
			"SELECT
			|	ExchangePlan.Ref AS Ref
			|FROM
			|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
			|WHERE
			|	Not ExchangePlan.RegisterChanges
			|	AND ExchangePlan.Ref <> &ThisNode";
			
			QueryText2 = StrReplace(QueryText2, "[ExchangePlanName]", ExchangePlanName);
			
			Query2 = New Query;
			Query2.SetParameter("ThisNode", ExchangePlans[ExchangePlanName].ThisNode());
			Query2.Text = QueryText2;
			
			QueryResult2 = Query2.Execute();
			
			If Not QueryResult2.IsEmpty() Then
				
				Selection2 = QueryResult2.Select();
				
				While Selection2.Next() Do
					
					Node = Selection2.Ref.GetObject();
					Node.RegisterChanges = True;
					Node.DataExchange.Load = True;
					Node.Write();
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	CommonUse.SetSessionSeparation(False);
	
EndProcedure

// Locks all endpoints except for the service manager endpoint.
//
Procedure LockEndPoints() Export
	
	QueryText =
	"SELECT
	|	MessageExchange.Ref AS Ref
	|FROM
	|	ExchangePlan.MessageExchange AS MessageExchange
	|WHERE
	|	MessageExchange.Ref <> &ThisNode
	|	AND MessageExchange.Ref <> &ServiceManagerEndPoint
	|	AND Not MessageExchange.Blocked";
	
	Query = New Query;
	Query.SetParameter("ThisNode", MessageExchangeInternal.ThisNode());
	Query.SetParameter("ServiceManagerEndPoint", SaaSReUse.ServiceManagerEndPoint());
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		EndPoint = Selection.Ref.GetObject();
		EndPoint.Blocked = True;
		EndPoint.Write();
		
	EndDo;
	
EndProcedure

// It transfers data of DataExchangeStates and
// SuccessfulDataExchangeStates registers to the corresponding 
// DataAreaDataExchangeStates and DataAreasSuccessfulDataExchangeStates registers when updating the IB.
//
Procedure MoveDataExchangeDataStates() Export
	
	If DataExchangeReUse.SeparatedSSLExchangePlans().Count() = 0 Then
		Return;
	EndIf;
	
	// DataExchangeStates and DataAreaDataExchangeStates register processor
	BeginTransaction();
	Try
		
		QueryText =
		"SELECT
		|	DataExchangeStatus.InfobaseNode,
		|	DataExchangeStatus.ActionOnExchange,
		|	DataExchangeStatus.ExchangeProcessResult,
		|	DataExchangeStatus.StartDate,
		|	DataExchangeStatus.EndDate,
		|	DataExchangeStatus.InfobaseNode.DataAreaBasicData AS DataArea
		|FROM
		|	InformationRegister.DataExchangeStatus AS DataExchangeStatus
		|WHERE
		|	Not DataExchangeStatus.InfobaseNode.DataAreaBasicData IS NULL";
		
		Query = New Query;
		Query.Text = QueryText;
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			// Delete a record in RS.DataExchangeStates
			RecordStructure = New Structure("InfobaseNode, ActionOnExchange, ExchangeProcessResult, StartDate, EndDate");
			FillPropertyValues(RecordStructure, Selection);
			InformationRegisters.DataExchangeStatus.DeleteRecord(RecordStructure);
			
			// Add record to RS.DataAreaDataExchangeStates
			RecordStructure.Insert("DataAreaAuxiliaryData", Selection.DataArea);
			InformationRegisters.DataAreaDataExchangeStatus.AddRecord(RecordStructure);
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	// SuccessfulDataExchangeStates and DataAreasSuccessfulDataExchangeStates registers handling
	BeginTransaction();
	Try
		
		QueryText =
		"SELECT
		|	SuccessfulDataExchangeStatus.InfobaseNode,
		|	SuccessfulDataExchangeStatus.ActionOnExchange,
		|	SuccessfulDataExchangeStatus.EndDate,
		|	SuccessfulDataExchangeStatus.InfobaseNode.DataAreaBasicData AS DataArea
		|FROM
		|	InformationRegister.SuccessfulDataExchangeStatus AS SuccessfulDataExchangeStatus
		|WHERE
		|	Not SuccessfulDataExchangeStatus.InfobaseNode.DataAreaBasicData IS NULL";
		
		Query = New Query;
		Query.Text = QueryText;
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			// Delete the record in RS.SuccessfulDataExchangeStates
			RecordStructure = New Structure("InfobaseNode, ActionOnExchange, EndDate");
			FillPropertyValues(RecordStructure, Selection);
			InformationRegisters.SuccessfulDataExchangeStatus.DeleteRecord(RecordStructure);
			
			// Add the record to RS.DataAreaSuccessfulDataExchangeStates
			RecordStructure.Insert("DataAreaAuxiliaryData", Selection.DataArea);
			InformationRegisters.DataAreasSuccessfulDataExchangeStatus.AddRecord(RecordStructure);
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function DataStructureCorrespondentsEndPoints_2_1_2_0()
	
	Result = New Map;
	
	QueryText =
	"SELECT
	|	ExchangeTransportSettings.Node AS CorrespondentEndPoint,
	|	ExchangeTransportSettings.WSURLWebService AS Address
	|FROM
	|	InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|WHERE
	|	VALUETYPE(ExchangeTransportSettings.Node) IN (&Types)";
	
	Types = New Array;
	Types.Add(Type("ExchangePlanRef.MessageExchange"));
	
	Query = New Query;
	Query.SetParameter("Types", Types);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		Result.Insert(Selection.Address, Selection.CorrespondentEndPoint);
		
	EndDo;
	
	Return Result;
EndFunction

Function InformationExchangeDirectoryRelative(Val Folder)
	
	If IsBlankString(Folder) Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Incorrect info exchange catalog format ""%1"".';ru='Неправильный формат каталога обмена информацией ""%1"".'"),
			Folder);
	EndIf;
	
	Delimiter = "/";
	
	If Find(Folder, Delimiter) = 0 Then
		
		Delimiter = "\";
		
		If Find(Folder, Delimiter) = 0 Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Incorrect info exchange catalog format ""%1"".';ru='Неправильный формат каталога обмена информацией ""%1"".'"),
				Folder);
		EndIf;
		
	EndIf;
	
	Directories = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Folder, Delimiter);
	
	If Directories.Count() = 0 Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Incorrect info exchange catalog format ""%1"".';ru='Неправильный формат каталога обмена информацией ""%1"".'"),
			Folder);
	EndIf;
	
	Result = Directories[Directories.UBound()];
	
	If IsBlankString(Result) Then
		
		If Directories.Count() = 1 Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Incorrect info exchange catalog format ""%1"".';ru='Неправильный формат каталога обмена информацией ""%1"".'"),
				Folder);
		EndIf;
		
		Result = Directories[Directories.UBound() - 1];
		
	EndIf;
	
	Return Result;
EndFunction

// It checks the availability of the predefined nodes with blank codes
//
Function ThereAreFixedNodeBlankCodes()
	
	For Each ExchangePlan IN Metadata.ExchangePlans Do
		
		If DataExchangeSaaSReUse.IsDataSynchronizationExchangePlan(ExchangePlan.Name) Then
			
			QueryText = "SELECT
			|	ExchangePlan.Code
			|FROM
			|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
			|WHERE
			|	ExchangePlan.Code = """"";
			
			QueryText = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlan.Name);
			Query = New Query;
			Query.Text = QueryText;
			Result = Query.Execute();
			
			If Not Result.IsEmpty() Then
				
				Return True;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

// For internal use
//
Procedure OnSendDataToSubordinate(DataItem, ItemSend, Val CreatingInitialImage, Recipient) Export
	
	If Recipient = Undefined Then
		
		//
		
	ElsIf ItemSend = DataItemSend.Delete
		OR ItemSend = DataItemSend.Ignore Then
		
		// Do not override standard DataProcessor.
		
	ElsIf CreatingInitialImage
		AND CommonUseReUse.DataSeparationEnabled()
		AND OfflineWorkService.ThisIsNodeOfOfflineWorkplace(Recipient.Ref)
		AND CommonUse.IsSeparatedMetadataObject(DataItem.Metadata(),
			CommonUseReUse.MainDataSeparator()) Then
		
		ItemSend = DataItemSend.Ignore;
		
		WriteXML(Recipient.AdditionalProperties.ExportedData, DataItem);
		
	EndIf;
	
EndProcedure

//

// For internal use
//
Procedure OnSendDataToMaster(DataItem, ItemSend, Recipient) Export
	
	If ItemSend = DataItemSend.Ignore Then
		//
	ElsIf OfflineWorkService.ThisIsOfflineWorkplace() Then
		
		If TypeOf(DataItem) = Type("ObjectDeletion") Then
			
			MetadataObject = DataItem.Ref.Metadata();
			
		Else
			
			MetadataObject = DataItem.Metadata();
			
		EndIf;
		
		If Not CommonUse.IsSeparatedMetadataObject(MetadataObject,
				CommonUseReUse.MainDataSeparator()) Then
			
			ItemSend = DataItemSend.Ignore;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// For internal use
//
Procedure OnReceiveDataFromSubordinate(DataItem, ItemReceive, SendBack, Sender) Export
	
	If ItemReceive = DataItemReceive.Ignore Then
		//
	ElsIf CommonUseReUse.DataSeparationEnabled() Then
		
		If TypeOf(DataItem) = Type("ObjectDeletion") Then
			
			MetadataObject = DataItem.Ref.Metadata();
			
		Else
			
			MetadataObject = DataItem.Metadata();
			
		EndIf;
		
		If Not CommonUse.IsSeparatedMetadataObject(MetadataObject,
				CommonUseReUse.MainDataSeparator()) Then
			
			ItemReceive = DataItemReceive.Ignore;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Handlers of conditional calls from SSL.

// Handler to remove the UseDataSynchronization constant.
//
//  Parameters:
// Cancel - Boolean. Check box of canceling the data synchronization disabling.
// If you set True in the value, then the synchronization will not be disabled.
//
Procedure OnDataSynchronizationDisabling(Cancel) Export
	
	Constants.OfflineSaaS.Set(False);
	Constants.UseDataSynchronizationSaaSWithLocalApplication.Set(False);
	Constants.UseDataSynchronizationSaaSWithApplicationInInternet.Set(False);
	
EndProcedure

//

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// SSL subsystems event handlers

// Fills in parameters structure required for client
// code work during the configuration end i.e. in the handlers:
// - BeforeExit,
// - OnExit
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystemsOnComplete(Parameters) Export
	
	AddClientWorkParametersOnComplete(Parameters);
	
EndProcedure

// Fills the map of method names and call aliases from the jobs queue.
//
// Parameters:
//  AccordanceNamespaceAliases - Correspondence
//   Key - Method alias, for example, ClearDataArea
//   Value - Method name for calling, for example SaaSOperations.ClearDataArea.
//   You can specify Undefined as a value, in this case
//   the name is assumed to match the alias
//
Procedure WhenYouDefineAliasesHandlers(AccordanceNamespaceAliases) Export
	
	AccordanceNamespaceAliases.Insert("DataExchangeSaaS.SetDataChangeSign"); 
	AccordanceNamespaceAliases.Insert("DataExchangeSaaS.PerformDataExchange");
	AccordanceNamespaceAliases.Insert("DataExchangeSaaS.PerformDataExchangeScriptActionInFirstInfobase");
	AccordanceNamespaceAliases.Insert("DataExchangeSaaS.PerformDataExchangeScriptActionInSecondInfobase");
	
EndProcedure

// Generates a list of IB parameters.
//
// Parameters:
// ParameterTable - ValueTable - parameters description table.
// Description columns content - see SaaSOperations.GetIBParameterTable()
//
Procedure WhenCompletingTablesOfParametersOfIB(Val ParameterTable) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
		ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "AddressForAccountPasswordRecovery");
	EndIf;
	
EndProcedure

// After Defining Recipients handler.
// It is called at the object registration in the exchange plan.
// It specifies the
// constant-flag of the data change and sends the message about the change with the number of the current area to the service manager.
//
// Parameters:
// Data - CatalogRef or DocumentObject - Object to receive attribute values and other properties.
// Recipients - Array - Array of items of the ExchangePlanRef.<Name> type - Exchange plan nodes.
// ExchangePlanName - String.
//
Procedure AfterGetRecipients(Data, Recipients, ExchangePlanName) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		If Data.DataExchange.Load Then
			Return;
		EndIf;
		
		If Recipients.Count() > 0
			AND DataExchangeSaaSReUse.IsDataSynchronizationExchangePlan(ExchangePlanName)
			AND Not GetFunctionalOption("DataChangesRecorded") Then
			
			If CommonUseReUse.SessionWithoutSeparator() Then
				
				SetDataChangeFlag();
			Else
				
				Try
					BackgroundJobs.Execute("DataExchangeSaaS.SetDataChangeSign",, "1");
				Except
					// Additional exception data processor is not required, 
					// the expected exception - redundancy of the task with the same key
				EndTry;
			EndIf;
			
		EndIf;
		
	Else
		
		// Export the changes to the service
		// only for the applied data (separated by DataAreaBasicData)
		If OfflineWorkService.ThisIsOfflineWorkplace()
			AND Not CommonUse.IsSeparatedMetadataObject(Data.Metadata(),
				CommonUseReUse.MainDataSeparator()) Then
			
			CommonUseClientServer.DeleteValueFromArray(Recipients, OfflineWorkService.ApplicationInService());
		EndIf;
		
	EndIf;
	
EndProcedure

// Fills the structure with the arrays of supported
// versions of all subsystems subject to versioning and uses subsystems names as keys.
// Provides the functionality of InterfaceVersion Web-service.
// during the implementation the body of the procedure shall be changed so it will return relevant version sets (see example below).
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
	VersionArray.Add("2.1.2.1");
	VersionArray.Add("2.1.5.17");
	VersionArray.Add("2.1.6.1");
	SupportedVersionStructure.Insert("DataExchangeSaaS", VersionArray);
	
EndProcedure

// Gets the list of message handlers that handle library subsystems.
// 
// Parameters:
//  Handlers - ValueTable - for the field content see MessageExchange.NewMessageHandlersTable
// 
Procedure OnDefenitionMessagesFeedHandlers(Handlers) Export
	
	MessagesExchangeDataHandlerMessages.GetMessageChannelHandlers(Handlers);
	
EndProcedure

// Adds parameters of the client logic work at the system start for the data exchange subsystem in the service model.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystemsRunning(Parameters) Export
	
	SetPrivilegedMode(True);
	
	Parameters.Insert("ThisIsOfflineWorkplace",
		OfflineWorkService.ThisIsOfflineWorkplace());
	Parameters.Insert("SynchronizeDataWithApplicationInInternetOnWorkStart",
		OfflineWorkService.SynchronizeDataWithApplicationInInternetOnWorkStart());
	Parameters.Insert("SynchronizeDataWithApplicationInInternetOnExit",
		OfflineWorkService.SynchronizeDataWithApplicationInInternetOnExit());
	
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

// Fills the array of types excluded from the import and export of data.
//
// Parameters:
//  Types - Array(Types).
//
Procedure WhenFillingTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.Constants.ReusableValuesUpdateDateORM);
	Types.Add(Metadata.Constants.DataChangesRecorded);
	Types.Add(Metadata.Constants.SubordinatedDIBNodeSetup);
	Types.Add(Metadata.Constants.LastOfflineWorkplacePrefix);
	Types.Add(Metadata.Constants.DistributedInformationBaseNodePrefix);
	
	Types.Add(Metadata.InformationRegisters.NodesCommonDataChange);
	Types.Add(Metadata.InformationRegisters.DataAreaTransportExchangeSettings);
	Types.Add(Metadata.InformationRegisters.InfobasesNodesCommonSettings);
	Types.Add(Metadata.InformationRegisters.DataExchangeResults);
	Types.Add(Metadata.InformationRegisters.SystemMessagesExchangeSessions);
	Types.Add(Metadata.InformationRegisters.InfobasesObjectsCompliance);
	Types.Add(Metadata.InformationRegisters.DataAreaDataExchangeStatus);
	
EndProcedure

// Deletes files of the exchange messages that were not deleted because of errors in the system work.
// Files with posting date that exceeds 24 hours from the current universal date are subject to removal.
// RS.DataAreaDataExchangeMessages is analyzed
//
// Parameters:
// No.
//
Procedure OnDeleteOutdatedMessagesExchange() Export
	
	QueryText =
	"SELECT
	|	DataExchangeMessages.MessageID AS MessageID,
	|	DataExchangeMessages.MessageFileName AS FileName,
	|	DataExchangeMessages.DataAreaAuxiliaryData AS DataAreaAuxiliaryData
	|FROM
	|	InformationRegister.MessageDataExchangeDataAreas AS DataExchangeMessages
	|WHERE
	|	DataExchangeMessages.MessageSendingDate < &UpdateDate
	|
	|ORDER BY
	|	DataAreaAuxiliaryData";
	
	Query = New Query;
	Query.SetParameter("UpdateDate", CurrentUniversalDate() - 60 * 60 * 24);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	SessionParameters.DataAreasUse = True;
	DataAreaAuxiliaryData = Undefined;
	
	While Selection.Next() Do
		
		MessageFileFullName = CommonUseClientServer.GetFullFileName(DataExchangeReUse.TempFileStorageDirectory(), Selection.FileName);
		
		MessageFile = New File(MessageFileFullName);
		
		If MessageFile.Exist() Then
			
			Try
				DeleteFiles(MessageFile.DescriptionFull);
			Except
				WriteLogEvent(NStr("en='Data exchange';ru='Обмен данными описание'", CommonUseClientServer.MainLanguageCode()),
					EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
				Continue;
			EndTry;
		EndIf;
		
		If DataAreaAuxiliaryData <> Selection.DataAreaAuxiliaryData Then
			
			DataAreaAuxiliaryData = Selection.DataAreaAuxiliaryData;
			SessionParameters.DataAreaValue = DataAreaAuxiliaryData;
			
		EndIf;
		
		// Delete info of the exchange message file from the storage
		RecordStructure = New Structure;
		RecordStructure.Insert("MessageID", String(Selection.MessageID));
		InformationRegisters.MessageDataExchangeDataAreas.DeleteRecord(RecordStructure);
		
	EndDo;
	
	SessionParameters.DataAreasUse = False;
	
EndProcedure

// Receive the attachment file name by its ID from the storage.
// If there is no file with the specified ID, the exception is called.
// If the file is found, then its name is returned and information about this file is deleted from the storage.
//
// Parameters:
//  FileID - UUID - identifier of the received file.
//  FileName           - String - name of the file, from the storage.
//
Procedure OnReceiveFileFromStore(Val FileID, FileName) Export
	
	QueryText =
	"SELECT
	|	DataExchangeMessages.MessageFileName AS FileName
	|FROM
	|	InformationRegister.MessageDataExchangeDataAreas AS DataExchangeMessages
	|WHERE
	|	DataExchangeMessages.MessageID = &MessageID";
	
	Query = New Query;
	Query.SetParameter("MessageID", String(FileID));
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Definition = NStr("en='File with ID %1 is not found.';ru='Файл с идентификатором %1 не обнаружен.'");
		Raise StringFunctionsClientServer.PlaceParametersIntoString(Definition, String(FileID));
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	FileName = Selection.FileName;
	
	// Delete info of the exchange message file from the storage
	RecordStructure = New Structure;
	RecordStructure.Insert("MessageID", String(FileID));
	InformationRegisters.MessageDataExchangeDataAreas.DeleteRecord(RecordStructure);
	
EndProcedure

// Place file to the storage.
//
Procedure OnPlaceFileStorage(Val RecordStructure) Export
	
	InformationRegisters.MessageDataExchangeDataAreas.AddRecord(RecordStructure);
	
EndProcedure

// Delete file from storage.
//
Procedure OnDeleteFileFromStorage(Val RecordStructure) Export
	
	InformationRegisters.DataExchangeMessages.DeleteRecord(RecordStructure);
	
EndProcedure

// Used to receive metadata objects mandatory for an exchange plan.
// If the subsystem has metadata objects that have to be included in the exchange plan,
// then these metadata objects should be added to the <Object> parameter.
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
// If the subsystem has metadata objects that should not be included in the exchange plan, 
// then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects that should not be included into the exchange plan.
// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
// True - required to get the list of the exception objects of the DIB exchange plan;
// False - it is required to receive a list for an exchange plan NOT RIB.
//
Procedure OnGettingObjectExceptionsOfExchangePlan(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Constants.DataChangesRecorded);
		Objects.Add(Metadata.Constants.OfflineSaaS);
		Objects.Add(Metadata.Constants.UseDataSynchronizationSaaSWithLocalApplication);
		Objects.Add(Metadata.Constants.UseDataSynchronizationSaaSWithApplicationInInternet);
		Objects.Add(Metadata.Constants.LastOfflineWorkplacePrefix);
		Objects.Add(Metadata.Constants.SynchronizeDataWithApplicationInInternetOnApplicationEnd);
		Objects.Add(Metadata.Constants.SynchronizeDataWithApplicationInInternetOnApplicationStart);
		
		Objects.Add(Metadata.InformationRegisters.DataAreasTransportExchangeSettings);
		Objects.Add(Metadata.InformationRegisters.DataAreaTransportExchangeSettings);
		Objects.Add(Metadata.InformationRegisters.SystemMessagesExchangeSessions);
		Objects.Add(Metadata.InformationRegisters.DataAreaDataExchangeStatus);
		Objects.Add(Metadata.InformationRegisters.DataAreasSuccessfulDataExchangeStatus);
		Objects.Add(Metadata.InformationRegisters.MessageDataExchangeDataAreas);
		
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
	
	Objects.Add(Metadata.Constants.AddressForAccountPasswordRecovery);
	
EndProcedure

// Register provided data handlers
//
// When receiving notifications of new common data availability
// the NewDataAvailable procedure of the modules registered using GetProvidedDataHandlers is called.
// Descriptor is passed to the procedure - XDTOObject Descriptor.
// 
// If NewDataAvailable sets the Import argument to the True value, the data is imported, the handle and the file path with data are passed to the ProcessNewData procedure. File will be deleted automatically after completion of the procedure.
// If the file was not specified in the service manager - The argument value is Undefined.
//
// Parameters: 
//   Handlers, ValueTable - The table for adding handlers. 
//       Columns:
//        DataKind, string - data kind code processed
//        by the HandlerCode handler, string(20) - will be used at dataprocessor recovery after
//        the Handler failure, CommonModule - the module that contains the following procedures:
//          AvailableNewData(Handle,
//          Import) Export ProcessNewData(Handle,
//          PathToFile) Export DataProcessingCanceled(Handle) Export
//
Procedure OnDefenitionHandlersProvidedData(Handlers) Export
	
	RegisterProvidedDataHandlers(Handlers);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions

// It exports data in the exchange between data areas.
//
// Parameters:
//  Cancel         - Boolean - failure flag; it is used if an error occurs
//  during the Correspondent data exporting - ExchangePlanRef - exchange plan node for which the data is exported.
// 
Procedure ExecuteDataExport(Cancel, Val Correspondent) Export
	
	DataExchangeServer.RunExchangeActionForInfobaseNode(
		Cancel, Correspondent, Enums.ActionsAtExchange.DataExport);
EndProcedure

// Imports data in the exchange between data areas.
//
// Parameters:
//  Cancel         - Boolean - failure flag; it is used if an error occurs
//  during the Correspondent data importing - ExchangePlanRef - exchange plan node for which the data is imported.
// 
Procedure ExecuteDataImport(Cancel, Val Correspondent) Export
	
	DataExchangeServer.RunExchangeActionForInfobaseNode(
		Cancel, Correspondent, Enums.ActionsAtExchange.DataImport);
EndProcedure

//

// It initiates data exchange between two IBs.
//
// Parameters:
// DataExchangeScenario - ValuesTable.
//
Procedure ExecuteDataExchange(DataExchangeScenario) Export
	
	SetPrivilegedMode(True);
	
	// Reset the flag of cumulative data change for the exchange
	Constants.DataChangesRecorded.Set(False);
	
	If DataExchangeScenario.Count() > 0 Then
		
		// Run the script
		ExecuteDataExchangeScenarioActionInFirstInfobase(0, DataExchangeScenario);
		
	EndIf;
	
EndProcedure

// Performs script exchange action specified by the value table string for the first of two exchanging IBs.
//
// Parameters:
// ScenarioRowIndex - Number - String index in the DataExchangeScript table.
// DataExchangeScenario - ValuesTable.
//
Procedure ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex, DataExchangeScenario) Export
	
	SetPrivilegedMode(True);
	
	If ScenarioRowIndex > DataExchangeScenario.Count() - 1 Then
		Return; // End the script
	EndIf;
	
	ScenarioString = DataExchangeScenario[ScenarioRowIndex];
	
	If ScenarioString.InfobaseNumber = 1 Then
		
		InfobaseNode = FindInfobaseNode(ScenarioString.ExchangePlanName, ScenarioString.CodeOfInfobaseNode);
		
		If ScenarioString.RunningAction = "DataImport" Then
			
			ExecuteDataImport(False, InfobaseNode);
			
		ElsIf ScenarioString.RunningAction = "DataExport" Then
			
			ExecuteDataExport(False, InfobaseNode);
			
		Else
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Unknown action ""%1"" when exchanging data between data areas.';ru='Неизвестное действие ""%1"" при обмене данными между областями данных.'"),
				ScenarioString.RunningAction);
		EndIf;
		
		// Go to the next step of the script
		ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex + 1, DataExchangeScenario);
		
	ElsIf ScenarioString.InfobaseNumber = 2 Then
		
		InfobaseNode = FindInfobaseNode(ScenarioString.ExchangePlanName, ScenarioString.ThisNodeCode);
		
		CorrespondentVersions = CorrespondentVersions(InfobaseNode);
		
		If CorrespondentVersions.Find("2.0.1.6") <> Undefined Then
			
			WSProxy = DataExchangeSaaSReUse.GetCorrespondentWSProxy_2_0_1_6(InfobaseNode);
			
			If WSProxy = Undefined Then
				
				// Go to the next step of the script
				ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex + 1, DataExchangeScenario);
				Return;
			EndIf;
			
			WSProxy.StartExchangeExecutionInSecondDataBase(ScenarioRowIndex, XDTOSerializer.WriteXDTO(DataExchangeScenario));
			
		Else
			
			WSProxy = DataExchangeSaaSReUse.GetCorrespondentWSProxy(InfobaseNode);
			
			If WSProxy = Undefined Then
				
				// Go to the next step of the script
				ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex + 1, DataExchangeScenario);
				Return;
			EndIf;
			
			WSProxy.StartExchangeExecutionInSecondDataBase(ScenarioRowIndex, ValueToStringInternal(DataExchangeScenario));
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Performs exchange script action specified by the value table string for the second of two exchanging IBs.
//
// Parameters:
// ScenarioRowIndex - Number - String index in the DataExchangeScript table.
// DataExchangeScenario - ValuesTable.
//
Procedure ExecuteDataExchangeScenarioActionInSecondInfobase(ScenarioRowIndex, DataExchangeScenario) Export
	
	SetPrivilegedMode(True);
	
	ScenarioString = DataExchangeScenario[ScenarioRowIndex];
	
	InfobaseNode = FindInfobaseNode(ScenarioString.ExchangePlanName, ScenarioString.CodeOfInfobaseNode);
	
	If ScenarioString.ExecutionOrderNumber = 1 Then
		// Reset the flag of cumulative data change for the exchange
		Constants.DataChangesRecorded.Set(False);
	EndIf;
	
	If ScenarioString.RunningAction = "DataImport" Then
		
		ExecuteDataImport(False, InfobaseNode);
		
	ElsIf ScenarioString.RunningAction = "DataExport" Then
		
		ExecuteDataExport(False, InfobaseNode);
		
	Else
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Unknown action ""%1"" when exchanging data between data areas.';ru='Неизвестное действие ""%1"" при обмене данными между областями данных.'"),
			ScenarioString.RunningAction);
	EndIf;
	
	// End the script
	If ScenarioRowIndex = DataExchangeScenario.Count() - 1 Then
		
		// Indicate the exchange completion in the managing application
		WSServiceProxy = DataExchangeSaaSReUse.GetExchangeServiceWSProxy();
		WSServiceProxy.CommitExchange(XDTOSerializer.WriteXDTO(DataExchangeScenario));
		Return;
	EndIf;
	
	CorrespondentVersions = CorrespondentVersions(InfobaseNode);
	
	If CorrespondentVersions.Find("2.0.1.6") <> Undefined Then
		
		WSProxy = DataExchangeSaaSReUse.GetCorrespondentWSProxy_2_0_1_6(InfobaseNode);
		
		If WSProxy <> Undefined Then
			
			WSProxy.StartExchangeExecutionInFirstDataBase(ScenarioRowIndex + 1, XDTOSerializer.WriteXDTO(DataExchangeScenario));
			
		EndIf;
		
	Else
		
		WSProxy = DataExchangeSaaSReUse.GetCorrespondentWSProxy(InfobaseNode);
		
		If WSProxy <> Undefined Then
			
			WSProxy.StartExchangeExecutionInFirstDataBase(ScenarioRowIndex + 1, ValueToStringInternal(DataExchangeScenario));
			
		EndIf;
		
	EndIf;
	
EndProcedure

// It determines whether it is exchanging now.
// For this the request is sent to the service manager, whether the exchange lock is activated.
//
// Returns:
// Boolean. 
//
Function ExecutingDataExchange() Export
	
	SetPrivilegedMode(True);
	
	WSServiceProxy = DataExchangeSaaSReUse.GetExchangeServiceWSProxy();
	
	Return WSServiceProxy.ExchangeBlockIsSet(CommonUse.SessionSeparatorValue());
	
EndFunction

// It returns the date of the last successful importing of the current data area for all IB nodes.
// If the data is not synchronized, it returns Undefined.
//
// Returns:
// Date; Undefined. 
//
Function LastSuccessfulImportForAllInfobaseNodesDate() Export
	
	QueryText =
	"SELECT
	|	MIN(SuccessfulDataExchangeStatus.EndDate) AS EndDate
	|FROM
	|	InformationRegister.DataAreasSuccessfulDataExchangeStatus AS SuccessfulDataExchangeStatus
	|WHERE
	|	SuccessfulDataExchangeStatus.ActionOnExchange = VALUE(Enum.ActionsAtExchange.DataImport)
	|	AND SuccessfulDataExchangeStatus.InfobaseNode.DataAreaBasicData = &DataArea
	|	AND SuccessfulDataExchangeStatus.InfobaseNode.Code LIKE ""S%""";
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("DataArea", SaaSOperations.SessionSeparatorValue());
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return ?(ValueIsFilled(Selection.EndDate), Selection.EndDate, Undefined);
	
EndFunction

// It returns data synchronization statuses for the applications in the service model
//
Function SynchronizationStatusesData() Export
	
	QueryText = "SELECT
	|	DataExchangeStatus.InfobaseNode AS InfobaseNode,
	|	CASE
	|		WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Completed)
	|			OR DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.CompletedWithWarnings)
	|			THEN 0
	|		ELSE 1
	|	END AS Status
	|INTO DataExchangeStatusImport
	|FROM
	|	InformationRegister.DataAreaDataExchangeStatus AS DataExchangeStatus
	|WHERE
	|	DataExchangeStatus.ActionOnExchange = VALUE(Enum.ActionsAtExchange.DataImport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataExchangeStatus.InfobaseNode AS InfobaseNode,
	|	CASE
	|		WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Completed)
	|			OR DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.CompletedWithWarnings)
	|			THEN 0
	|		ELSE 1
	|	END AS Status
	|INTO DataExchangeStatusExport
	|FROM
	|	InformationRegister.DataAreaDataExchangeStatus AS DataExchangeStatus
	|WHERE
	|	DataExchangeStatus.ActionOnExchange = VALUE(Enum.ActionsAtExchange.DataExport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataExchangeResults.InfobaseNode AS InfobaseNode,
	|	COUNT(DISTINCT DataExchangeResults.ProblematicObject) AS Count
	|INTO ProblemsExchangeData
	|FROM
	|	InformationRegister.DataExchangeResults AS DataExchangeResults
	|WHERE
	|	Not DataExchangeResults.skipped
	|GROUP BY
	|	DataExchangeResults.InfobaseNode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataExchangeStatusExport.InfobaseNode AS Application,
	|	ISNULL(ProblemsExchangeData.Count, 0)          AS CountProblems,
	|	CASE
	|		WHEN DataExchangeStatusExport.Status = 1 OR DataExchangeStatusImport.Status = 1
	|			THEN 1 // Error
	|		ELSE CASE
	|				WHEN ISNULL(ProblemsExchangeData.Count, 0) > 0
	|					THEN 2 // Exchange issue
	|				ELSE 3 // No errors and no exchange issues
	|			END
	|	END AS Status
	|FROM
	|	DataExchangeStatusExport AS DataExchangeStatusExport
	|		LEFT JOIN DataExchangeStatusImport AS DataExchangeStatusImport
	|		BY DataExchangeStatusExport.InfobaseNode = DataExchangeStatusImport.InfobaseNode
	|		LEFT JOIN ProblemsExchangeData AS ProblemsExchangeData
	|		BY DataExchangeStatusExport.InfobaseNode = ProblemsExchangeData.InfobaseNode";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Return Query.Execute().Unload();
EndFunction

// It generates the exchange plan node code for the specified data area.
//
// Parameters:
// DataAreaNumber - Number - Separator value. 
//
// Returns:
// String - Exchange plan node code for the specified area. 
//
Function ExchangePlanNodeCodeInService(Val DataAreaNumber) Export
	
	If TypeOf(DataAreaNumber) <> Type("Number") Then
		Raise NStr("en='Inccorect number parameter type [1].';ru='Неправильный тип параметра номер [1].'");
	EndIf;
	
	Result = "S0[DataAreaNumber]";
	
	Return StrReplace(Result, "[DataAreaNumber]", Format(DataAreaNumber, "ND=7; NLZ=; NG=0"));
	
EndFunction

// Generates the application name in the service
//
Function GeneratePredefinedNodeDescription() Export
	
	ApplicationName = SaaSOperations.GetApplicationName();
	
	Return ?(IsBlankString(ApplicationName), NStr("en='Application in Internet';ru='приложение в Интернете'"), ApplicationName);
EndFunction

// It receives the end point for the correspondent.
// If the end point is not specified for the correspondent, the exception is called.
//
// Parameters:
// Correspondent - ExchangePlanRef - the correspondent for which it is necessary to receive the end point.
//
// Returns:
// ExchangePlanRef.MessageExchange - Correspondent end point
//
Function CorrespondentEndPoint(Val Correspondent) Export
	
	QueryText =
	"SELECT
	|	DataAreaTransportExchangeSettings.CorrespondentEndPoint AS CorrespondentEndPoint
	|FROM
	|	InformationRegister.DataAreaTransportExchangeSettings AS DataAreaTransportExchangeSettings
	|WHERE
	|	DataAreaTransportExchangeSettings.Correspondent = &Correspondent";
	
	Query = New Query;
	Query.SetParameter("Correspondent", Correspondent);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		MessageString = NStr("en='The correspondent end point is not specified for ""%1"".';ru='Не назначена конечная точка корреспондента для ""%1"".'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, String(Correspondent));
		Raise MessageString;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return Selection.CorrespondentEndPoint;
EndFunction

Function ExchangeMessagesDirectoryName(Val Code1, Val Code2)
	
	Return StringFunctionsClientServer.PlaceParametersIntoString("Exchange %1-%2", Code1, Code2);
	
EndFunction

// It registers the provided data handlers.
//
Procedure RegisterProvidedDataHandlers(Val Handlers) Export
	
	Handler = Handlers.Add();
	Handler.DataKind = ProvidedDataKindId();
	Handler.ProcessorCode = ProvidedDataKindId();
	Handler.Handler = DataExchangeSaaS;
	
EndProcedure

// It is called when a notification of new data received.
// IN the body you should check whether these data is necessary for the application, and if so, - select the Import check box.
// 
// Parameters:
//   Handle   - XDTOObject Descriptor.
//   Import    - Boolean, return
//
Procedure AvailableNewData(Val Handle, Import) Export
	
	If Handle.DataType = ProvidedDataKindId() Then
		
		ProvidedRulesDescription = ParseDataSuppliedHandle(Handle);
		
		If ProvidedRulesDescription.ConfigurationName = Metadata.Name
			AND ProvidedRulesDescription.ConfigurationVersion = Metadata.Version
			AND Metadata.ExchangePlans.Find(ProvidedRulesDescription.ExchangePlanName) <> Undefined
			AND DataExchangeReUse.ExchangePlanUsedSaaS(ProvidedRulesDescription.ExchangePlanName)
			AND DataExchangeServer.IsSeparatedExchangePlanSSL(ProvidedRulesDescription.ExchangePlanName) Then // Rules are compatible with the IB
			
			Import = True;
			
		Else
			
			Import = False;
			
			MessageText = NStr("en='Provided exchange rules are not applicable for the current configuration and intended for the %1 exchange plan of the %3 version of the %2 configuration';ru='Поставляемые правила обмена не подходят для текущей конфигурации и предназначены для плана обмена %1 конфигурации %2 версии %3'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText,
				ProvidedRulesDescription.ExchangePlanName, ProvidedRulesDescription.ConfigurationName, ProvidedRulesDescription.ConfigurationVersion);
			
			WriteLogEvent(NStr("en='Provided data exchange rules. The loading of the provided rules is cancelled.';ru='Поставляемые правила обмена данными.Загрузка поставляемых правил отменена'",
				CommonUseClientServer.MainLanguageCode()), EventLogLevel.Information,,, MessageText);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// It is called after the call of AvailableNewData, allows you to parse data.
//
// Parameters:
//   Handle   - XDTOObject Descriptor.
//   PathToFile   - String or Undefined. The full name of the extracted file. File will be deleted automatically after completion of the procedure. If the file was not
//                  specified in the service manager - The argument value is Undefined.
//
Procedure ProcessNewData(Val Handle, Val PathToFile) Export
	
	If Handle.DataType = ProvidedDataKindId() Then
		HandleProvidedExchangeRules(Handle, PathToFile);
	EndIf;
	
EndProcedure

// It is called when cancelling data processing in case of a failure.
//
Procedure DataProcessingCanceled(Val Handle) Export 
	
EndProcedure

// It returns the provided data kind identifier for the data exchange rules
//
// Return value: String.
//
Function ProvidedDataKindId()
	
	Return "ER"; // Not localized
	
EndFunction

Function ProvidedRulesDescription()
	
	Return New Structure("ConfigurationName, ConfigurationVersion, ExchangePlanName, Use");
	
EndFunction

Function ParseDataSuppliedHandle(Handle)
	
	ProvidedRulesDescription = ProvidedRulesDescription();
	
	For Each CharacteristicOfDeliveredData IN Handle.Properties.Property Do
		
		ProvidedRulesDescription[CharacteristicOfDeliveredData.Code] = CharacteristicOfDeliveredData.Value;
		
	EndDo;
	
	Return ProvidedRulesDescription;
	
EndFunction

Procedure HandleProvidedExchangeRules(Handle, PathToFile)
	
	SetPrivilegedMode(True);
	
	// Read characteristics of the provided data instance
	ProvidedRulesDescription = ParseDataSuppliedHandle(Handle);
	
	If ProvidedRulesDescription.Use Then
		InformationRegisters.DataExchangeRules.ImportProvidedRules(ProvidedRulesDescription.ExchangePlanName, PathToFile);
	Else
		InformationRegisters.DataExchangeRules.DeleteProvidedRules(ProvidedRulesDescription.ExchangePlanName);
	EndIf;
	
	DataExchangeServerCall.ResetCacheMechanismForRegistrationOfObjects();
	RefreshReusableValues();
	
EndProcedure

//

// Sends message
//
// Parameters:
// Message - XDTODataObject - message
//
Function SendMessage(Val Message) Export
	
	Message.Body.Zone = CommonUse.SessionSeparatorValue();
	Message.Body.SessionId = InformationRegisters.SystemMessagesExchangeSessions.NewSession();
	
	MessagesSaaS.SendMessage(Message, SaaSReUse.ServiceManagerEndPoint(), True);
	
	Return Message.Body.SessionId;
EndFunction

//

// For internal use
//
Procedure CreateExchangeSetting(
			Val ExchangePlanName,
			Val CorrespondentCode,
			Val CorrespondentDescription,
			Val CorrespondentEndPoint,
			Val Settings,
			Correspondent = Undefined,
			IsCorrespondent = False,
			CompatibilityModeSBAA_2_0_0 = False,
			Val Prefix = ""
	) Export
	
	BeginTransaction();
	Try
		
		ThisNodeCode = CommonUse.ObjectAttributeValue(ExchangePlans[ExchangePlanName].ThisNode(), "Code");
		
		// Check if the code is set for the current node
		If IsBlankString(ThisNodeCode) Then
			
			// The node code is specified in the IB update handler
			MessageString = NStr("en='For the predefined exchange plan node ""%1"" the code is not specified.';ru='Для предопределенного узла плана обмена ""%1"" не задан код.'");
			MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, ExchangePlanName);
			Raise MessageString;
		EndIf;
		
		// Check the prefix of this IB
		If IsBlankString(GetFunctionalOption("InfobasePrefix")) Then
			
			If IsBlankString(Prefix) Then
				Raise NStr("en='In the service Manager the prefix for this application is not installed.';ru='В Менеджере сервиса не установлен префикс для этого приложения.'");
			EndIf;
			
			DataExchangeServer.SetIBPrefix(Prefix);
			
		EndIf;
		
		// Create/update the correspondent node
		Correspondent = ExchangePlans[ExchangePlanName].FindByCode(CorrespondentCode);
		
		CheckCode = False;
		
		If Correspondent.IsEmpty() Then
			CorrespondentObject = ExchangePlans[ExchangePlanName].CreateNode();
			CorrespondentObject.Code = CorrespondentCode;
			CheckCode = True;
		Else
			CorrespondentObject = Correspondent.GetObject();
		EndIf;
		
		CorrespondentObject.Description = CorrespondentDescription;
		
		DataExchangeEvents.SetValuesOfFiltersAtNode(CorrespondentObject, Settings);
		
		CorrespondentObject.SentNo = 0;
		CorrespondentObject.ReceivedNo     = 0;
		
		CorrespondentObject.RegisterChanges = True;
		
		CorrespondentObject.DataExchange.Load = True;
		CorrespondentObject.Write();
		
		Correspondent = CorrespondentObject.Ref;
		
		ActualCorrespondentCode = CommonUse.ObjectAttributeValue(Correspondent, "Code");
		
		If CheckCode AND CorrespondentCode <> ActualCorrespondentCode Then
			
			MessageString = NStr("en='An error occurred while assigning a correspondent node code.
		|Set value
		|""%1"" Actual value ""%2"".';ru='Ошибка назначения кода узла корреспондента.
		|Назначенное
		|значение ""%1"" Фактическое значение ""%2"".'");
			MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, CorrespondentCode, ActualCorrespondentCode);
			Raise MessageString;
		EndIf;
		
		// Work with the exchange message transport settings
		If IsCorrespondent Then
			InformationExchangeDirectoryRelative = ExchangeMessagesDirectoryName(CorrespondentCode, ThisNodeCode);
		Else
			InformationExchangeDirectoryRelative = ExchangeMessagesDirectoryName(ThisNodeCode, CorrespondentCode);
		EndIf;
		
		TransportSettings = InformationRegisters.DataAreasTransportExchangeSettings.TransportSettings(CorrespondentEndPoint);
		
		If TransportSettings.ExchangeMessageTransportKindByDefault = Enums.ExchangeMessagesTransportKinds.FILE Then
			
			// Share folder exchange
			
			FILEInformationExchangeCommonDirectory = TrimAll(TransportSettings.FILEInformationExchangeDirectory);
			
			If IsBlankString(FILEInformationExchangeCommonDirectory) Then
				
				MessageString = NStr("en='Info exchange directory is not specified for the end point ""%1"".';ru='Не задан каталог обмена информацией для конечной точки ""%1"".'");
				MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, String(CorrespondentEndPoint));
				Raise MessageString;
			EndIf;
			
			CommonDirectory = New File(FILEInformationExchangeCommonDirectory);
			
			If Not CommonDirectory.Exist() Then
				
				MessageString = NStr("en='Info exchange directory ""%1"" does not exist.';ru='Каталог обмена информацией ""%1"" не существует.'");
				MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, FILEInformationExchangeCommonDirectory);
				Raise MessageString;
			EndIf;
			
			If Not CompatibilityModeSBAA_2_0_0 Then
				
				FILEInformationExchangeAbsoluteDirectory = CommonUseClientServer.GetFullFileName(
					FILEInformationExchangeCommonDirectory,
					InformationExchangeDirectoryRelative
				);
				
				// Creating the message exchange directory
				AbsoluteDirectory = New File(FILEInformationExchangeAbsoluteDirectory);
				If Not AbsoluteDirectory.Exist() Then
					CreateDirectory(AbsoluteDirectory.DescriptionFull);
				EndIf;
				
				// Save exchange message transport settings for the current data area
				RecordStructure = New Structure;
				RecordStructure.Insert("Correspondent", Correspondent);
				RecordStructure.Insert("CorrespondentEndPoint", CorrespondentEndPoint);
				RecordStructure.Insert("InformationExchangeDirectory", InformationExchangeDirectoryRelative);
				
				InformationRegisters.DataAreaTransportExchangeSettings.UpdateRecord(RecordStructure);
			EndIf;
			
		ElsIf TransportSettings.ExchangeMessageTransportKindByDefault = Enums.ExchangeMessagesTransportKinds.FTP Then
			
			// Exchange using FTP server
			
			FTPSettings = DataExchangeServer.FTPConnectionSettings();
			FTPSettings.Server               = TransportSettings.FTPServer;
			FTPSettings.Port                 = TransportSettings.FTPConnectionPort;
			FTPSettings.UserName      = TransportSettings.FTPConnectionUser;
			FTPSettings.UserPassword   = TransportSettings.FTPConnectionPassword;
			FTPSettings.PassiveConnection  = TransportSettings.FTPConnectionPassiveConnection;
			FTPSettings.SecureConnection = DataExchangeServer.SecureConnection(TransportSettings.FTPConnectionPath);
			
			FTPConnection = DataExchangeServer.FTPConnection(FTPSettings);
			
			InformationExchangeAbsoluteDirectory = CommonUseClientServer.GetFullFileName(
				TransportSettings.FTPPath,
				InformationExchangeDirectoryRelative
			);
			If Not DataExchangeServer.FTPDirectoryExist(InformationExchangeAbsoluteDirectory, InformationExchangeDirectoryRelative, FTPConnection) Then
				FTPConnection.CreateDirectory(InformationExchangeAbsoluteDirectory);
			EndIf;
			
			// Save exchange message transport settings for the current data area
			RecordStructure = New Structure;
			RecordStructure.Insert("Correspondent", Correspondent);
			RecordStructure.Insert("CorrespondentEndPoint", CorrespondentEndPoint);
			RecordStructure.Insert("InformationExchangeDirectory", InformationExchangeDirectoryRelative);
			
			InformationRegisters.DataAreaTransportExchangeSettings.UpdateRecord(RecordStructure);
			
		Else
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Exchange message transport kind ""%1"" is not supported for the %2 end point.';ru='Вид транспорта сообщений обмена ""%1"" для конечной точки %2 не поддерживается.'"),
				String(TransportSettings.ExchangeMessageTransportKindByDefault),
				String(CorrespondentEndPoint)
				);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// It updates settings and sets default values on the node
//
Procedure RefreshYourExchangeConfiguration(
		Val Correspondent,
		Val DefaultValuesAtNode
	) Export
	
	CorrespondentObject = Correspondent.GetObject();
	
	// Setting the default values 
	DataExchangeEvents.SetDefaultValuesAtNode(CorrespondentObject, DefaultValuesAtNode);
	
	CorrespondentObject.AdditionalProperties.Insert("GettingExchangeMessage");
	CorrespondentObject.Write();
	
EndProcedure

// Deletes the synchronization setting
Function DeleteSettingExchange(ExchangePlanName, CorrespondentDataArea, Session = Undefined) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Send the message to the Service Manager
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.MessageDisableSynchronization());
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		Message.Body.ExchangePlan = ExchangePlanName;
		Session = SendMessage(Message);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		WriteLogEvent(EventLogMonitorEventDataSyncronizationSetting(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return False;
		
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
	Return True;
	
EndFunction

//

// Saves session data and sets the CompletedSuccessfully flag value to True
//
Procedure SaveSessionData(Val Message, Val Presentation = "") Export
	
	If Not IsBlankString(Presentation) Then
		Presentation = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en=' {%1}';ru=' {%1}'"), Presentation);
	EndIf;
	
	MessageString = NStr("en='System messages exchange session ""%1"" is successfully completed.%2';ru='Сессия обмена сообщениями системы ""%1"" успешно завершена.%2'",
		CommonUseClientServer.MainLanguageCode());
	MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString,
		String(Message.Body.SessionId), Presentation);
	WriteLogEvent(SystemMessagesExchangeSessionEventLogMonitorEvent(),
		EventLogLevel.Information,,, MessageString);
	InformationRegisters.SystemMessagesExchangeSessions.SaveSessionData(Message.Body.SessionId, Message.Body.Data);
	
EndProcedure

// Sets the CompletedSuccessfully flag value to True for a session that is passed to the procedure
//
Procedure FixSuccessfullSessionCompletion(Val Message, Val Presentation = "") Export
	
	If Not IsBlankString(Presentation) Then
		Presentation = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en=' {%1}';ru=' {%1}'"), Presentation);
	EndIf;
	
	MessageString = NStr("en='System messages exchange session ""%1"" is successfully completed.%2';ru='Сессия обмена сообщениями системы ""%1"" успешно завершена.%2'",
		CommonUseClientServer.MainLanguageCode());
	MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString,
		String(Message.Body.SessionId), Presentation);
	WriteLogEvent(SystemMessagesExchangeSessionEventLogMonitorEvent(),
		EventLogLevel.Information,,, MessageString);
	InformationRegisters.SystemMessagesExchangeSessions.FixSuccessfullSessionCompletion(Message.Body.SessionId);
	
EndProcedure

// Sets the CompletedWithError flag value to True for a session that is passed to the procedure
//
Procedure FixUnsuccessfullSessionCompletion(Val Message, Val Presentation = "") Export
	
	If Not IsBlankString(Presentation) Then
		Presentation = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en=' {%1}';ru=' {%1}'"), Presentation);
	EndIf;
	
	MessageString = NStr("en='Error of the %1 system message
		|exchange session performance. %2 Error description from the correspondent: %3';ru='Ошибка выполнения сессии обмена сообщениями системы ""%1"".%2 Описание ошибки из корреспондента: %3'", CommonUseClientServer.MainLanguageCode());
	MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString,
		String(Message.Body.SessionId), Presentation, Message.Body.ErrorDescription);
	WriteLogEvent(SystemMessagesExchangeSessionEventLogMonitorEvent(),
		EventLogLevel.Error,,, MessageString);
	InformationRegisters.SystemMessagesExchangeSessions.FixUnsuccessfullSessionCompletion(Message.Body.SessionId);
	
EndProcedure

//

// Enters the area and performs exchange scripts specified by the value table string for the first of two exchanging IBs.
//
// Parameters:
// ScenarioRowIndex - Number - String index in the DataExchangeScript table.
// DataExchangeScenario - ValuesTable.
//
Procedure ExecuteDataExchangeScenarioActionInFirstInfobaseFromSharedSession(
																		ScenarioRowIndex,
																		DataExchangeScenario,
																		DataArea
	) Export
	
	SetPrivilegedMode(True);
	CommonUse.SetSessionSeparation(True, DataArea);
	SetPrivilegedMode(False);
	
	ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex, DataExchangeScenario);
	
	SetPrivilegedMode(True);
	CommonUse.SetSessionSeparation(False);
	SetPrivilegedMode(False);
	
EndProcedure

// Enters the area and performs exchange script specified by the value table string for the second of two exchanging IBs.
//
// Parameters:
// ScenarioRowIndex - Number - String index in the DataExchangeScript table.
// DataExchangeScenario - ValuesTable.
//
Procedure ExecuteDataExchangeScenarioActionInSecondInfobaseFromSharedSession(
																		ScenarioRowIndex,
																		DataExchangeScenario,
																		DataArea
	) Export
	
	SetPrivilegedMode(True);
	CommonUse.SetSessionSeparation(True, DataArea);
	SetPrivilegedMode(False);
	
	ExecuteDataExchangeScenarioActionInSecondInfobase(ScenarioRowIndex, DataExchangeScenario);
	
	SetPrivilegedMode(True);
	CommonUse.SetSessionSeparation(False);
	SetPrivilegedMode(False);
	
EndProcedure

// Returns the minimum required version of the platform
//
Function RequiredPlatformVersion() Export
	
	PlatformVersion = "";
	PlatformVersion = DataExchangeSaaSOverridable.RequiredApplicationVersion();
	DataExchangeSaaSOverridable.OnDefineRequiredApplicationVersion(PlatformVersion);
	If ValueIsFilled(PlatformVersion) Then
		Return PlatformVersion;
	EndIf;
	
	SystemInfo = New SystemInfo;
	PlatformVersion = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(SystemInfo.AppVersion, ".");
	
	// Remove the additional release number from the version number (the last number)
	PlatformVersion.Delete(3);
	Return StringFunctionsClientServer.RowFromArraySubrows(PlatformVersion, ".");
	
EndFunction

// Event for the event log of the data synchronization settings
//
Function EventLogMonitorEventDataSyncronizationSetting() Export
	
	Return NStr("en='Data exchange in the service model. Data synchronization setup';ru='Обмен данными в модели сервиса.Настройка синхронизации данных'",
		CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Event for the data synchronization monitor event log
//
Function EventLogMonitorEventDataSynchronizationMonitor() Export
	
	Return NStr("en='Data exchange in the service model. Data synchronization monitor';ru='Обмен данными в модели сервиса.Монитор синхронизации данных'",
		CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Event for the data synchronization event log
//
Function EventLogMonitorEventDataSynchronization() Export
	
	Return NStr("en='Data exchange in the service model. Data synchronization';ru='Обмен данными в модели сервиса.Синхронизация данных'",
		CommonUseClientServer.MainLanguageCode());
	
EndFunction

Function SystemMessagesExchangeSessionEventLogMonitorEvent()
	
	Return NStr("en='Data exchange in the service model. Sessions of the system messages exchange';ru='Обмен данными в модели сервиса.Сессии обмена сообщениями системы'",
		CommonUseClientServer.MainLanguageCode());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of the exchange data monitor

// For internal use
// 
Function DataExchangeMonitorTable(Val MethodExchangePlans, Val ExchangePlanAdditionalProperties = "", Val OnlyUnsuccessful = False) Export
	
	QueryText = "SELECT
	|	DataExchangeStatus.InfobaseNode AS InfobaseNode,
	|	DataExchangeStatus.EndDate AS EndDate,
	|	CASE
	|		WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Completed)
	|			OR DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.CompletedWithWarnings)
	|			THEN 0
	|		ELSE 1
	|	END AS ExchangeProcessResult
	|INTO DataExchangeStatusImport
	|FROM
	|	InformationRegister.DataAreaDataExchangeStatus AS DataExchangeStatus
	|WHERE
	|	DataExchangeStatus.ActionOnExchange = VALUE(Enum.ActionsAtExchange.DataImport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataExchangeStatus.InfobaseNode AS InfobaseNode,
	|	DataExchangeStatus.EndDate AS EndDate,
	|	CASE
	|		WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Completed)
	|			OR DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.CompletedWithWarnings)
	|			THEN 0
	|		ELSE 1
	|	END AS ExchangeProcessResult
	|INTO DataExchangeStatusExport
	|FROM
	|	InformationRegister.DataAreaDataExchangeStatus AS DataExchangeStatus
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
	|	InformationRegister.DataAreasSuccessfulDataExchangeStatus AS SuccessfulDataExchangeStatus
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
	|	InformationRegister.DataAreasSuccessfulDataExchangeStatus AS SuccessfulDataExchangeStatus
	|WHERE
	|	SuccessfulDataExchangeStatus.ActionOnExchange = VALUE(Enum.ActionsAtExchange.DataExport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangePlans.ExchangePlanName AS ExchangePlanName,
	|	ExchangePlans.InfobaseNode AS InfobaseNode,
	|	ExchangePlans.InfobaseNode.DataAreaBasicData AS DataArea,
	|
	|	[ExchangePlanAdditionalProperties]
	|
	|	ISNULL(DataExchangeStatusExport.ExchangeProcessResult, 0) AS LastDataExportResult,
	|	ISNULL(DataExchangeStatusImport.ExchangeProcessResult, 0) AS LastDataImportResult,
	|	DataExchangeStatusImport.EndDate AS LastImportDate,
	|	DataExchangeStatusExport.EndDate AS LastExportDate,
	|	SuccessfulDataExchangeStatusImport.EndDate AS LastSuccessfulImportDate,
	|	SuccessfulDataExchangeStatusExport.EndDate AS LastSuccessfulExportDate
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
	|
	|[Filter]
	|
	|ORDER BY
	|	ExchangePlans.ExchangePlanName,
	|	ExchangePlans.Description";
	
	SetPrivilegedMode(True);
	
	TempTablesManager = New TempTablesManager;
	
	GetExchangePlanTableForMonitor(TempTablesManager, MethodExchangePlans, ExchangePlanAdditionalProperties);
	
	QueryText = StrReplace(QueryText, "[ExchangePlanAdditionalProperties]",
		GetExchangePlanAdditionalPropertiesString(ExchangePlanAdditionalProperties));
	
	If OnlyUnsuccessful Then
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
	SynchronizationSettings.Columns.Add("LastImportDatePresentation");
	SynchronizationSettings.Columns.Add("LastExportDatePresentation");
	SynchronizationSettings.Columns.Add("LastSuccessfulImportDatePresentation");
	SynchronizationSettings.Columns.Add("LastSuccessfulExportDatePresentation");
	
	For Each SynchronizationSetting IN SynchronizationSettings Do
		
		SynchronizationSetting.LastImportDatePresentation         = DataExchangeServer.RelativeSynchronizationDate(SynchronizationSetting.LastImportDate);
		SynchronizationSetting.LastExportDatePresentation         = DataExchangeServer.RelativeSynchronizationDate(SynchronizationSetting.LastExportDate);
		SynchronizationSetting.LastSuccessfulImportDatePresentation = DataExchangeServer.RelativeSynchronizationDate(SynchronizationSetting.LastSuccessfulImportDate);
		SynchronizationSetting.LastSuccessfulExportDatePresentation = DataExchangeServer.RelativeSynchronizationDate(SynchronizationSetting.LastSuccessfulExportDate);
		
	EndDo;
	
	Return SynchronizationSettings;
EndFunction

// For internal use
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

// For internal use
// 
Procedure GetExchangePlanTableForMonitor(Val TempTablesManager, Val MethodExchangePlans, Val ExchangePlanAdditionalProperties)
	
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
	|	RegisterChanges
	|	AND Not DeletionMark
	|";
	
	QueryText = "";
	
	If MethodExchangePlans.Count() > 0 Then
		
		For Each ExchangePlanName IN MethodExchangePlans Do
			
			ExchangePlanQueryText = StrReplace(QueryPattern,              "[ExchangePlanName]",        ExchangePlanName);
			ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "[ExchangePlanNameSynonym]", Metadata.ExchangePlans[ExchangePlanName].Synonym);
			ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "[ExchangePlanAdditionalProperties]", ExchangePlanAdditionalPropertiesString);
			
			// Delete the merging literal for the first table.
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

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions

Function FindInfobaseNode(Val ExchangePlanName, Val NodeCode)
	
	NodeCodeWithPrefix = ExchangePlanNodeCodeInService(Number(NodeCode));
	
	// Searching the node by the S00000123 node code format
	Result = DataExchangeReUse.FindExchangePlanNodeByCode(ExchangePlanName, NodeCodeWithPrefix);
	
	If Result = Undefined Then
		
		// Searching for the node by the 0000123 (old) code format
		Result = DataExchangeReUse.FindExchangePlanNodeByCode(ExchangePlanName, NodeCode);
		
	EndIf;
	
	If Result = Undefined Then
		Message = NStr("en='The exchange plan node is not found. Name of the %1 exchange plan; code of the %2 or %3 node';ru='Не найден узел плана обмена. Имя плана обмена %1; код узла %2 или %3'");
		Message = StringFunctionsClientServer.PlaceParametersIntoString(Message, ExchangePlanName, NodeCode, NodeCodeWithPrefix);
		Raise Message;
	EndIf;
	
	Return Result;
EndFunction

Function CorrespondentVersions(Val InfobaseNode)
	
	SettingsStructure = InformationRegisters.DataAreaTransportExchangeSettings.TransportSettingsWS(InfobaseNode);
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL",      SettingsStructure.WSURLWebService);
	ConnectionParameters.Insert("UserName", SettingsStructure.WSUserName);
	ConnectionParameters.Insert("Password", SettingsStructure.WSPassword);
	
	Return CommonUse.GetInterfaceVersions(ConnectionParameters, "DataExchangeSaaS");
EndFunction

// Returns DataExchangeSaaS subsystem parameters required
// to end user work.
//
// Returns:
// Structure - Parameters.
//
Function AutonomousWorkParametersOnExit()
	
	ParametersOnComplete = New Structure;
	
	If OfflineWorkService.ThisIsOfflineWorkplace() Then
		
		FormParametersDataExchange = OfflineWorkService.FormParametersDataExchange();
		SynchronizationWithServiceHasNotBeenExecutedLongAgo = OfflineWorkService.SynchronizationWithServiceHasNotBeenExecutedLongAgo();
		
	Else
		
		FormParametersDataExchange = New Structure;
		SynchronizationWithServiceHasNotBeenExecutedLongAgo = False;
		
	EndIf;
	
	ParametersOnComplete.Insert("FormParametersDataExchange", FormParametersDataExchange);
	ParametersOnComplete.Insert("SynchronizationWithServiceHasNotBeenExecutedLongAgo", SynchronizationWithServiceHasNotBeenExecutedLongAgo);
	
	Return ParametersOnComplete;
EndFunction

Procedure BeforeCommonDataWrite(Object, Cancel)
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
	ReadOnly = False;
	OfflineWorkService.DetermineWhetherChangesData(Object.Metadata(), ReadOnly);
	
	If ReadOnly Then
		ErrorString = NStr("en='Change of unseparated data (%1) loaded from the application is prohibited for the Offline workplace.
		|Contact your administrator.';ru='Изменение неразделенных данных (%1), загружаемых из приложения, в Автономном рабочем месте запрещено.
		|Обратитесь к администратору.'");
		ErrorString = StringFunctionsClientServer.PlaceParametersIntoString(ErrorString, String(Object));
		Raise ErrorString;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event subscriptions for the independent working place

// It checks the option to record unseparated data at the Offline workplace.
// For the detailed description see OfflineWorkService.DefineDataChangePossibility
//
Procedure WorkOfflineCheckCommonDataRecordingPossibility(Source, Cancel) Export
	
	BeforeCommonDataWrite(Source, Cancel);
	
EndProcedure

// It checks the option to record unseparated data at the Offline workplace.
// For the detailed description see OfflineWorkService.DefineDataChangePossibility
//
Procedure WorkOfflineCheckCommonDataRecordingPossibilityDocument(Source, Cancel, WriteMode, PostingMode) Export
	
	BeforeCommonDataWrite(Source, Cancel);
	
EndProcedure

// It checks the option to record unseparated data at the Offline workplace.
// For the detailed description see OfflineWorkService.DefineDataChangePossibility
//
Procedure WorkOfflineCheckCommonDataRecordingPossibilityConstant(Source, Cancel) Export
	
	BeforeCommonDataWrite(Source, Cancel);
	
EndProcedure

// It checks the option to record unseparated data at the Offline workplace.
// For the detailed description see OfflineWorkService.DefineDataChangePossibility
//
Procedure WorkOfflineCheckCommonDataRecordingPossibilityRecordSet(Source, Cancel, Replacing) Export
	
	BeforeCommonDataWrite(Source, Cancel);
	
EndProcedure

// It checks the option to record unseparated data at the Offline workplace.
// For the detailed description see OfflineWorkService.DefineDataChangePossibility
//
Procedure WorkOfflineCheckCommonDataRecordingPossibilityRecordSetCalculation(Source, Cancel, Replacing, WriteOnly, WriteActualActionPeriod, WriteRecalculations) Export
	
	BeforeCommonDataWrite(Source, Cancel);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Receive references to the general info pages of the service

// It returns the
// ref address by ID For internal use
//
Function RefAddressFromInfoCenter(Val ID)
	Result = "";
	
	If Not CommonUse.SubsystemExists("ServiceTechnology.InformationCenter") Then
		Return Result;
	EndIf;
	
	ModuleInformationCenterServer = CommonUse.CommonModule("InformationCenterServer");
	
	SetPrivilegedMode(True);
	Try
		DataRefs = ModuleInformationCenterServer.ContextRefByUUID(ID);
	Except
		// if there is no method
		DataRefs = Undefined;
	EndTry;
	
	If DataRefs <> Undefined Then
		Result = DataRefs.Address;
	EndIf;
	
	Return Result;
EndFunction

// Returns the address of the reference to the
// item related to the setting of the thin client For internal use
//
Function InstructionAddressToSetThinClient() Export
	
	Return RefAddressFromInfoCenter("InstructionForConfiguringThinClient");
	
EndFunction

// Returns the address of the reference
// to the item related to backup copying For internal use
//
Function AddressBackupInstructions() Export
	
	Return RefAddressFromInfoCenter("BackupInstruction");
	
EndFunction

// Handler of the background job to record additional
// data and exchange For Internal Use
//
// Parameters:
//     ImportingHandling - DataProcessorObject.InteractiveExportChange - the
//     StorageAddress initialized object    - String, UUID - Address in storage for getting a result
// 
Procedure ExchangeOnDemand(Val ImportingHandling, Val StorageAddress = Undefined) Export
	
	DataProcessors.InteractiveDataExchangeInModelServiceAssistant.ExchangeOnDemand(ImportingHandling, StorageAddress);
	
EndProcedure

Procedure OnCreatingIndependentWorkingPlace() Export
	
	If UsersServiceSaaSSTL.UserRegisteredAsUnseparated(
			InfobaseUsers.CurrentUser().UUID) Then
		
		Raise NStr("en='You can create the offline workplace only acting as a separated user.
		|Current user is unseparated.';ru='Создать автономное рабочее место можно только от имени разделенного пользователя.
		|Текущий пользователь является неразделенным.'");
		
	EndIf;
	
EndProcedure

#EndRegion
