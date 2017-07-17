
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Data synchronization can be enabled or disabled only by exchange administrator (for subscriber).
	DataExchangeServer.CheckExchangesAdministrationPossibility();
	
	If Not DataExchangeSaaSReUse.DataSynchronizationSupported() Then
		
		Raise NStr("en='Data synchronization for this configuration is not supported.';ru='Синхронизация данных для конфигурации не поддерживается!'");
		
	EndIf;
	
	EventLogMonitorEventDataSynchronizationMonitor = DataExchangeSaaS.EventLogMonitorEventDataSynchronizationMonitor();
	
	SynchronizationSettingsGettingScript();
	
	Items.DataSynchronizationSettingDisableDataSynchronization.Enabled = False;
	Items.DataSynchronizationSettingsContextMenuDisableDataSynchronization.Enabled = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// The second assistant step
	SetGoToNumber(2);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Creating_DataSynchronization"
		OR EventName = "Disable_DataSynchronization" Then
		
		RefreshMonitor();
		
	ElsIf EventName = "ClosedFormDataExchangeResults" Then
		
		RefreshDataSynchronizationSettings();
		
	EndIf;
	
EndProcedure

// Wait handlers

&AtClient
Procedure LongOperationIdleHandler()
	
	Try
		StatusOfSession = StatusOfSession(Session);
	Except
		WriteErrorInEventLogMonitor(
			DetailErrorDescription(ErrorInfo()), EventLogMonitorEventDataSynchronizationMonitor);
		SkipBack();
		Return;
	EndTry;
	
	If StatusOfSession = "Successfully" Then
		
		GoToNext();
		
	ElsIf StatusOfSession = "Error" Then
		
		SkipBack();
		Return;
		
	Else
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SendData(Command)
	// Add new data to the exported data
	
	ApplicationData = Items.DataSynchronizationSettings.CurrentData;
	If ApplicationData=Undefined Or Not ApplicationData.SynchronizationSet Then
		Return;
	EndIf;
	
	OpenForm("DataProcessor.InteractiveDataExchangeInModelServiceAssistant.Form.Form",
		New Structure("ProhibitExportOnlyChanged, InfobaseNode", 
			True, ApplicationData.Correspondent
		), ThisObject);
	
EndProcedure

&AtClient
Procedure ExecuteDataSynchronization(Command)
	
	GoToNext();
	
EndProcedure

&AtClient
Procedure ConfigureDataSynchronization(Command)
	
	PerformDataSynchronizationSetting(Items.DataSynchronizationSettings.CurrentData);
	
EndProcedure

&AtClient
Procedure DisableDataSynchronization(Command)
	
	CurrentData = Items.DataSynchronizationSettings.CurrentData;
	
	If CurrentData <> Undefined
		AND CurrentData.SynchronizationSet Then
		
		If CurrentData.SynchronizationSettingsInServiceManager Then
			
			ShowMessageBox(, NStr("en='To disable the data synchronization go to service manager.
		|In the service manager use the ""Data Synchronization"" command.';ru='Для отключения синхронизации данных перейдите в менеджер сервиса.
		|В менеджере сервиса воспользуйтесь командой ""Синхронизация данных"".'"));
		Else
			
			FormParameters = New Structure;
			FormParameters.Insert("ExchangePlanName",              CurrentData.ExchangePlan);
			FormParameters.Insert("CorrespondentDataArea", CurrentData.DataArea);
			FormParameters.Insert("CorrespondentDescription",  CurrentData.ApplicationName);
			
			OpenForm("DataProcessor.DataSynchronizationSettingsBetweenApplicationsOnInternetSetupAssistant.Form.DisablingDataSynchronization", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	RefreshMonitor();
	
EndProcedure

&AtClient
Procedure DataSynchronizationSettingsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	PerformDataSynchronizationSetting(Items.DataSynchronizationSettings.CurrentData);
	
EndProcedure

&AtClient
Procedure DataSynchronizationSettingsOnActivateRow(Item)
	
	CurrentData = Item.CurrentData;
	If CurrentData=Undefined Then
		Items.DataSynchronizationSettingDisableDataSynchronization.Enabled = False;
		Items.DataSynchronizationSettingsContextMenuDisableDataSynchronization.Enabled = False;
		DataSynchronizationSettingsDescription = "";
		
		Items.DataSynchronizationSettingsPrepareData.Enabled = False;
		Items.DataSynchronizationSettingsContextMenuSendData.Enabled = False;
	Else		
		Items.DataSynchronizationSettingDisableDataSynchronization.Enabled = CurrentData.SynchronizationSet;
		Items.DataSynchronizationSettingsContextMenuDisableDataSynchronization.Enabled = CurrentData.SynchronizationSet;
		DataSynchronizationSettingsDescription = CurrentData.Definition;
		
		Items.DataSynchronizationSettingsPrepareData.Enabled = CurrentData.SynchronizationSet;
		Items.DataSynchronizationSettingsContextMenuSendData.Enabled = CurrentData.SynchronizationSet;
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToConflicts(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangeNodes", UsedNodesArray(DataSynchronizationSettings));
	OpenForm("InformationRegister.DataExchangeResults.Form.Form", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS (Supplied part)

&AtClient
Procedure ChangeGoToNumber(Iterator)
	
	ClearMessages();
	
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsGoNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 0 Then
		
		GoToNumber = 0;
		
	EndIf;
	
	GoToNumberOnChange(IsGoNext);
	
EndProcedure

&AtClient
Procedure GoToNumberOnChange(Val IsGoNext)
	
	// Executing the step change event handlers
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Setting page visible
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying is not defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage = Items[GoToRowCurrent.MainPageName];
	
	If Not IsBlankString(GoToRowCurrent.DecorationPageName) Then
		
		Items.DataSynchronizationPanel.CurrentPage = Items[GoToRowCurrent.DecorationPageName];
		
	EndIf;
	
	If IsGoNext AND GoToRowCurrent.LongOperation Then
		
		AttachIdleHandler("ExecuteLongOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Transition events handlers
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - 1));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// handler OnGoingNext
			If Not IsBlankString(GoToRow.GoNextHandlerName)
				AND Not GoToRow.LongOperation Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoNextHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber - 1);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// handler OnGoingBack
			If Not IsBlankString(GoToRow.GoBackHandlerName)
				AND Not GoToRow.LongOperation Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoBackHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber + 1);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying is not defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	If GoToRowCurrent.LongOperation AND Not IsGoNext Then
		
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// handler OnOpen
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, SkipPage, IsGoNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsGoNext Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			Else
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteLongOperationHandler()
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying is not defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// handler LongOperationHandling
	If Not IsBlankString(GoToRowCurrent.LongOperationHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.LongOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetGoToNumber(GoToNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetGoToNumber(GoToNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure GoToTableNewRow(GoToNumber,
									MainPageName,
									NavigationPageName = "",
									DecorationPageName = "",
									OnOpenHandlerName = "",
									GoNextHandlerName = "",
									GoBackHandlerName = "",
									LongOperation = False,
									LongOperationHandlerName = "")
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber = GoToNumber;
	NewRow.MainPageName     = MainPageName;
	NewRow.DecorationPageName    = DecorationPageName;
	NewRow.NavigationPageName    = NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.GoBackHandlerName = GoBackHandlerName;
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.LongOperation = LongOperation;
	NewRow.LongOperationHandlerName = LongOperationHandlerName;
	
EndProcedure

&AtClientAtServerNoContext
Function UsedNodesArray(DataSynchronizationSettings)
	
	ExchangeNodes = New Array;
	
	For Each NodeString IN DataSynchronizationSettings Do
		If NodeString.SynchronizationSet Then
			ExchangeNodes.Add(NodeString.Correspondent);
		EndIf;
	EndDo;
	
	Return ExchangeNodes;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS (Overridable part)

&AtClient
Procedure GoToNext()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure SkipBack()
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtServerNoContext
Function StatusOfSession(Val Session)
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.SystemMessagesExchangeSessions.StatusOfSession(Session);
	
EndFunction

&AtServerNoContext
Procedure WriteErrorInEventLogMonitor(Val ErrorMessageString, Val Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

&AtServer
Function NewSession()
	
	Session = InformationRegisters.SystemMessagesExchangeSessions.NewSession();
	
	Return Session;
EndFunction

&AtServer
Procedure SetSynchronizationSettingsGettingScript()
	
	SynchronizationSettingsGettingScript();
	
EndProcedure

&AtClient
Procedure PerformDataSynchronizationSetting(Val CurrentData)
	
	If CurrentData <> Undefined Then
		
		If CurrentData.SynchronizationSet Then
			
			ShowValue(, CurrentData.Correspondent);
			
		ElsIf CurrentData.SynchronizationSettingsInServiceManager Then
			
			ShowMessageBox(, NStr("en='To set the data synchronization go to service manager.
		|In the service manager use the ""Data Synchronization"" command.';ru='Для настройки синхронизации данных перейдите в менеджер сервиса.
		|В менеджере сервиса воспользуйтесь командой ""Синхронизация данных"".'"));
		Else
			
			FormParameters = New Structure;
			FormParameters.Insert("ExchangePlanName",              CurrentData.ExchangePlan);
			FormParameters.Insert("CorrespondentDataArea", CurrentData.DataArea);
			FormParameters.Insert("CorrespondentDescription",  CurrentData.ApplicationName);
			FormParameters.Insert("CorrespondentEndPoint", CurrentData.CorrespondentEndPoint);
			FormParameters.Insert("Prefix",                     CurrentData.Prefix);
			FormParameters.Insert("CorrespondentPrefix",       CurrentData.CorrespondentPrefix);
			FormParameters.Insert("CorrespondentVersion",        CurrentData.CorrespondentVersion);
			
			Uniqueness = CurrentData.ExchangePlan + Format(CurrentData.DataArea, "ND=7; NLZ=; NG=0");
			
			OpenForm("DataProcessor.DataSynchronizationSettingsBetweenApplicationsOnInternetSetupAssistant.Form.Form",
				FormParameters, ThisObject, Uniqueness,,,,FormWindowOpeningMode.LockOwnerWindow);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshMonitor()
	
	SetSynchronizationSettingsGettingScript();
	
	GoToNumber = 0;
	
	// The second assistant step
	SetGoToNumber(2);
	
EndProcedure

&AtServer
Procedure RefreshDataSynchronizationSettings()
	
	CountProblems = 0;
	
	// Synchronization status getting for setting table
	SynchronizationStatuses = DataExchangeSaaS.SynchronizationStatusesData();
	
	For Each Setting IN DataSynchronizationSettings Do
		
		If Setting.SynchronizationSet Then
			
			SynchronizationStatus = SynchronizationStatuses.Find(Setting.Correspondent, "Application");
			
			If SynchronizationStatus <> Undefined Then
				
				Setting.SynchronizationStatus = SynchronizationStatus.Status;
				
				If SynchronizationStatus.Status = 1 Then // Service administrator intervention is required
					
					Setting.State = NStr("en='Errors occurred while synchronizing data';ru='Ошибки при синхронизации данных'");
					
				ElsIf SynchronizationStatus.Status = 2 Then // User can solve problems individually
					
					Setting.State = NStr("en='Data synchronization issues';ru='Проблемы при синхронизации данных'");
					
					CountProblems = CountProblems + SynchronizationStatus.CountProblems;
					
				ElsIf SynchronizationStatus.Status = 3 Then
					
					Setting.State = NStr("en='Data synchronization is configured';ru='Синхронизация данных настроена'");
					
				EndIf;
				
			Else
				Setting.State = NStr("en='Data synchronization is configured';ru='Синхронизация данных настроена'");
				Setting.SynchronizationStatus = 3;
			EndIf;
			
		Else
			
			Setting.Definition = NStr("en='Data synchronization is not configured';ru='Синхронизация данных не настроена'");
			Setting.SynchronizationStatus = 0;
			
		EndIf;
		
	EndDo;
		
	// Synchronization problem displaying in the monitor header
	HeaderStructure = DataExchangeServer.HeaderStructureHyperlinkMonitorProblems(UsedNodesArray(DataSynchronizationSettings));
	FillPropertyValues(Items.GoToConflicts, HeaderStructure);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Transition events handlers

// Page 1 (waiting): synchronization settings getting
//
&AtClient
Function Attachable_DataReceivingExpectation_LongOperationProcessing(Cancel, GoToNext)
	
	RequestDataSynchronizationSettings(Cancel);
	
EndFunction

// Page 1 (waiting): synchronization settings getting
//
&AtClient
Function Attachable_DataReceivingExpectationLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("LongOperationIdleHandler", 5, True);
	
EndFunction

// Page 1 (waiting): synchronization settings getting
//
&AtClient
Function Attachable_DataReceivingExpectationLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	ReadDataSynchronizationSettings(Cancel);
	
EndFunction

// Page 1 (waiting): synchronization settings getting
//
&AtServer
Procedure RequestDataSynchronizationSettings(Cancel)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// We are sending a message in SM
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.MessageGetDataSynchronizationSettings());
		Message.Body.Zone = CommonUse.SessionSeparatorValue();
		Message.Body.SessionId = NewSession();
		
		MessagesSaaS.SendMessage(Message,
			SaaSReUse.ServiceManagerEndPoint(), True);
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSynchronizationMonitor);
		Cancel = True;
		Return;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

// Page 1 (waiting): synchronization settings getting
//
&AtServer
Procedure ReadDataSynchronizationSettings(Cancel)
	
	SetPrivilegedMode(True);
	
	Try
		
		SynchronizationSettingsFromServiceManager = InformationRegisters.SystemMessagesExchangeSessions.GetSessionData(Session).Get();
		
		If SynchronizationSettingsFromServiceManager.Count() = 0 Then
			
			SynchronizationSettingsMissingScript();
			Cancel = True;
			Return;
		EndIf;
		
		IsPrefix              = SynchronizationSettingsFromServiceManager.Columns.Find("Prefix") <> Undefined;
		IsCorrespondentVersion = SynchronizationSettingsFromServiceManager.Columns.Find("CorrespondentVersion") <> Undefined;
		
		// We are filling the DataSynchronizationSettings table according to service Manager data
		DataSynchronizationSettings.Clear();
		
		SynchronizationSet = False;
		
		For Each SettingFromServiceManager IN SynchronizationSettingsFromServiceManager Do
			
			Setting = DataSynchronizationSettings.Add();
			
			Setting.ExchangePlan                              = SettingFromServiceManager.ExchangePlan;
			Setting.DataArea                           = SettingFromServiceManager.DataArea;
			Setting.ApplicationName                  = SettingFromServiceManager.ApplicationName;
			Setting.SynchronizationSet                  = SettingFromServiceManager.SynchronizationSet;
			Setting.SynchronizationSettingsInServiceManager = SettingFromServiceManager.SynchronizationSettingsInServiceManager;
			
			// We are filling the "CorrespondentEndPoint" filed
			Setting.CorrespondentEndPoint = ExchangePlans.MessageExchange.FindByCode(SettingFromServiceManager.CorrespondentEndPoint);
			
			If Setting.CorrespondentEndPoint.IsEmpty() Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Correspondent endpoint with the ""%1"" code is not found.';ru='Не найдена конечная точка корреспондента с кодом ""%1"".'"),
					SettingFromServiceManager.CorrespondentEndPoint);
			EndIf;
			
			If Setting.SynchronizationSet Then
				
				SynchronizationSet = True;
				
				// We are filling the "Correspondent" field for current settings
				Setting.Correspondent = ExchangePlans[Setting.ExchangePlan].FindByCode(
					DataExchangeSaaS.ExchangePlanNodeCodeInService(Setting.DataArea));
				
				Setting.Definition = DataExchangeServer.DataSynchronizationRulesDescription(Setting.Correspondent);
				
			EndIf;
			
			If IsPrefix Then
				Setting.Prefix               = SettingFromServiceManager.Prefix;
				Setting.CorrespondentPrefix = SettingFromServiceManager.CorrespondentPrefix;
			Else
				Setting.Prefix               = "";
				Setting.CorrespondentPrefix = "";
			EndIf;
			
			If IsCorrespondentVersion Then
				Setting.CorrespondentVersion = SettingFromServiceManager.CorrespondentVersion;
			Else
				Setting.CorrespondentVersion = "";
			EndIf;
			
		EndDo;
		
		Items.DataSynchronizationPanel.Visible = SynchronizationSet;
		
	Except
		
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSynchronizationMonitor);
		Cancel = True;
		Return;
	EndTry;
	
EndProcedure

//

// Page 2: Work with the synchronization setting list
//
&AtClient
Function Attachable_DataSynchronizationSetting_OnOpen(Cancel, SkipPage, IsGoNext)
	
	DataSynchronizationSetting_OnOpen(Cancel);
	
EndFunction

// Page 2: Work with the synchronization setting list
//
&AtServer
Procedure DataSynchronizationSetting_OnOpen(Cancel)
	
	SetPrivilegedMode(True);
	
	Try
		
		Items.SynchronizationMonitorGroup.Enabled = True;
		
		// We are getting a presentation of successful synchronization date
		Items.SynchronizationDatePresentation.Title = DataExchangeServer.SynchronizationDatePresentation(
			DataExchangeSaaS.LastSuccessfulImportForAllInfobaseNodesDate());
		
		RefreshDataSynchronizationSettings();
		
	Except
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSynchronizationMonitor);
		Cancel = True;
		Return;
	EndTry;
	
EndProcedure

//

// Page 3 (waiting): Synchronization execution
//
&AtClient
Function Attachable_SynchronizationExecution_LongOperationProcessing(Cancel, GoToNext)
	
	PushDataSynchronization(Cancel);
	
EndFunction

// Page 3 (waiting): Synchronization execution
//
&AtClient
Function Attachable_SynchronizationExecutionLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("LongOperationIdleHandler", 5, True);
	
EndFunction

// Page 3 (waiting): Synchronization execution
//
&AtClient
Function Attachable_SynchronizationExecutionLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	Cancel = True; // It is back to the monitor page (page 2)
	
	// We are refreshing all open dynamic lists
	DataExchangeClient.RefreshAllOpenDynamicLists();
	
EndFunction

// Page 3 (waiting): Synchronization execution
//
&AtServer
Procedure PushDataSynchronization(Cancel)
	
	Items.SynchronizationMonitorGroup.Enabled = False;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// We are sending a message in SM
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.MessagePushSynchronization());
		Message.Body.Zone = CommonUse.SessionSeparatorValue();
		Message.Body.SessionId = NewSession();
		
		MessagesSaaS.SendMessage(Message,
			SaaSReUse.ServiceManagerEndPoint(), True);
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSynchronizationMonitor);
		Cancel = True;
		Return;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Initialize assistant's transitions

&AtServer
Procedure SynchronizationSettingsGettingScript()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "DataReceivingError");
	
	// The synchronization settings getting
	GoToTableNewRow(2, "DataReceivingExpectation",,,,,, True, "DataReceivingExpectation_LongOperationProcessing");
	GoToTableNewRow(3, "DataReceivingExpectation",,,,,, True, "WaitingToGetDataTimeConsumingOperation_LongTreatment");
	GoToTableNewRow(4, "DataReceivingExpectation",,,,,, True, "WaitingForEndOfLongRunningOperation_DataProcessingOperation");
	
	// Work with the synchronization setting list
	GoToTableNewRow(5, "DataSynchronizationSetting",, "SynchronizationStatus", "DataSynchronizationSetting_OnOpen");
	
	// Synchronization in progress
	GoToTableNewRow(6, "DataSynchronizationSetting",, "SynchronizationExecution",,,, True, "ExecutionSynchronization_DataProcessingOfLongOperation");
	GoToTableNewRow(7, "DataSynchronizationSetting",, "SynchronizationExecution",,,, True, "ExecuteSynchronizationLongOperation_DataProcessingOfLongOperation");
	GoToTableNewRow(8, "DataSynchronizationSetting",, "SynchronizationExecution",,,, True, "PerformSynchronizationLongOperationEnding_DataProcessorLongActions");
	
EndProcedure

&AtServer
Procedure SynchronizationSettingsMissingScript()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "NoApplicationForSynchronization");
	GoToTableNewRow(2, "DataReceivingExpectation",,,,,, True, "DataReceivingExpectation_LongOperationProcessing");
	GoToTableNewRow(3, "DataReceivingExpectation",,,,,, True, "WaitingToGetDataTimeConsumingOperation_LongTreatment");
	GoToTableNewRow(4, "DataReceivingExpectation",,,,,, True, "WaitingForEndOfLongRunningOperation_DataProcessingOperation");
	
EndProcedure

#EndRegion
