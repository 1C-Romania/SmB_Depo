#Region FormEventsHandlers

// Overridable part

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Only exchange administrator can receive correspondent data (for subscriber).
	DataExchangeServer.CheckExchangesAdministrationPossibility();
	
	SetPrivilegedMode(True);
	
	ExchangePlanName              = Parameters.ExchangePlanName;
	CorrespondentDataArea         = Parameters.CorrespondentDataArea;
	CorrespondentTables           = Parameters.CorrespondentTables;
	Mode                          = Parameters.Mode;
	OwnerUuid                     = Parameters.OwnerUuid;
	
	EventLogMonitorEventDataSyncronizationSetting = DataExchangeSaaS.EventLogMonitorEventDataSyncronizationSetting();
	
	// Set the current table of transitions
	DataRetrievalScriptContributor();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Position at the assistant's first step
	SetGoToNumber(1);
	
EndProcedure

// Wait handlers

&AtClient
Procedure LongOperationIdleHandler()
	
	Try
		StatusOfSession = StatusOfSession(Session);
	Except
		WriteErrorInEventLogMonitor(
			DetailErrorDescription(ErrorInfo()), EventLogMonitorEventDataSyncronizationSetting);
		CancelOperation();
		Return;
	EndTry;
	
	If StatusOfSession = "Successfully" Then
		
		GoToNext();
		
	ElsIf StatusOfSession = "Error" Then
		
		CancelOperation();
		Return;
		
	Else
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Supplied part

&AtClient
Procedure CommandCancel(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Supplied part

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
	
	Items.MainPanel.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[GoToRowCurrent.NavigationPageName];
	
	// Set current button by default
	ButtonNext = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandNext");
	
	If ButtonNext <> Undefined Then
		
		ButtonNext.DefaultButton = True;
		
	Else
		
		DoneButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandDone");
		
		If DoneButton <> Undefined Then
			
			DoneButton.DefaultButton = True;
			
		EndIf;
		
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

// Adds new row to the end of current transitions table
//
// Parameters:
//
//  TransitionSequenceNumber (mandatory) - Number. Sequence number of transition that corresponds to the current transition step
//  MainPageName (mandatory) - String. Name of the MainPanel panel page that corresponds to the current number of the transition 
//  NavigationPageName (mandatory) - String. Page name of the NavigationPanel panel, which corresponds to the current number of transition 
//  DecorationPageName (optional) - String. Page name of the DecorationPanel panel, which corresponds to the current number of transition
//  DeveloperNameOnOpening (optional) - String. Name of the function-processor of the assistant current page open event
//  HandlerNameOnGoingNext (optional) - String. Name of the function-processor of the transition to the next assistant page event 
//  HandlerNameOnGoingBack (optional) - String. Name of the function-processor of the transition to assistant previous page event 
//  LongOperation (optional) - Boolean. Shows displayed long operation page.
//  True - long operation page is displayed; False - show normal page. Value by default - False.
// 
&AtServer
Procedure GoToTableNewRow(GoToNumber,
									MainPageName,
									NavigationPageName,
									DecorationPageName = "",
									OnOpenHandlerName = "",
									GoNextHandlerName = "",
									GoBackHandlerName = "",
									LongOperation = False,
									LongOperationHandlerName = "")
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber            = GoToNumber;
	NewRow.MainPageName          = MainPageName;
	NewRow.DecorationPageName    = DecorationPageName;
	NewRow.NavigationPageName    = NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.GoBackHandlerName = GoBackHandlerName;
	NewRow.OnOpenHandlerName = OnOpenHandlerName;
	
	NewRow.LongOperation = LongOperation;
	NewRow.LongOperationHandlerName = LongOperationHandlerName;
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item IN FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			AND Find(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Service procedures and functions

&AtClient
Procedure GoToNext()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtServerNoContext
Function StatusOfSession(Val Session)
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.SystemMessagesExchangeSessions.StatusOfSession(Session);
	
EndFunction

&AtServerNoContext
Procedure WriteErrorInEventLogMonitor(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

&AtClient
Procedure CancelOperation()
	
	ShowMessageBox(, NStr("en='Cannot execute the operation.';ru='Не удалось выполнить операцию.'"));
	Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Transition events handlers

&AtClient
Function Attachable_DataReceivingExpectation_LongOperationProcessing(Cancel, GoToNext)
	
	DataReceivingExpectation_LongOperationProcessing(Cancel);
	
	If Cancel Then
		Cancel = False;
		CancelOperation();
	EndIf;
	
EndFunction

&AtServer
Procedure DataReceivingExpectation_LongOperationProcessing(Cancel)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		If Mode = "GetCorrespondentData" Then
			
			// Send a message to the correspondent
			Message = MessagesSaaS.NewMessage(
				MessagesDataExchangeManagementInterface.MessageGetCorrespondentData());
			Message.Body.CorrespondentZone = CorrespondentDataArea;
			Message.Body.Tables = XDTOSerializer.WriteXDTO(CorrespondentTables);
			Message.Body.ExchangePlan = ExchangePlanName;
			Session = DataExchangeSaaS.SendMessage(Message);
			
		ElsIf Mode = "GetCorrespondentNodesCommonData" Then
			
			// Send a message to the correspondent
			Message = MessagesSaaS.NewMessage(
				MessagesDataExchangeManagementInterface.MessageGetCorrespondentNodesCommonData());
			Message.Body.CorrespondentZone = CorrespondentDataArea;
			Message.Body.ExchangePlan = ExchangePlanName;
			Session = DataExchangeSaaS.SendMessage(Message);
			
		Else
			
			Raise NStr("en='Unknown mode of correspondent data receipt.';ru='Неизвестный режим получения данных корреспондента.'");
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSyncronizationSetting);
		Cancel = True;
		Return;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

&AtClient
Function Attachable_DataReceivingExpectationLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("LongOperationIdleHandler", 5, True);
	
EndFunction

&AtClient
Function Attachable_DataReceivingExpectationLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	DataReceivingExpectationLongOperationEnd_LongOperationProcessing(Cancel);
	
	If Cancel Then
		CancelOperation();
		Return Undefined;
	EndIf;
	
	Close();
	
	If Mode = "GetCorrespondentData" Then
		
		Notify("DataContributor", TemporaryStorageAddress);
		
	ElsIf Mode = "GetCorrespondentNodesCommonData" Then
		
		Notify("CorrespondentNodeDataReceived", TemporaryStorageAddress);
		
	EndIf;
	
EndFunction

&AtServer
Procedure DataReceivingExpectationLongOperationEnd_LongOperationProcessing(Cancel)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		CorrespondentData = InformationRegisters.SystemMessagesExchangeSessions.GetSessionData(Session);
		
		TemporaryStorageAddress = PutToTempStorage(CorrespondentData, OwnerUuid);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSyncronizationSetting);
		Cancel = True;
		Return;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Initialization of assistant transitions

&AtServer
Procedure DataRetrievalScriptContributor()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "DataReceivingExpectation", "NavigationPageCancel",,,,, True, "DataReceivingExpectation_LongOperationProcessing");
	GoToTableNewRow(2, "DataReceivingExpectation", "NavigationPageCancel",,,,, True, "WaitingToGetDataTimeConsumingOperation_LongTreatment");
	GoToTableNewRow(3, "DataReceivingExpectation", "NavigationPageCancel",,,,, True, "WaitingForEndOfLongRunningOperation_DataProcessingOperation");
	
EndProcedure

#EndRegion
