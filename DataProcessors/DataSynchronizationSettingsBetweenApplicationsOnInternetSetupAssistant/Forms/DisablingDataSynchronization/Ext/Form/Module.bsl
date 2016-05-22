#Region FormEventsHandlers

// Overridable part

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Only exchange administrator can disable data synchronization (for subscriber).
	DataExchangeServer.CheckExchangesAdministrationPossibility();
	
	SetPrivilegedMode(True);
	
	ExchangePlanName              = Parameters.ExchangePlanName;
	CorrespondentDataArea = Parameters.CorrespondentDataArea;
	
	EventLogMonitorEventDataSyncronizationSetting = DataExchangeSaaS.EventLogMonitorEventDataSyncronizationSetting();
	
	Items.LabelWarnings.Title = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en = 'Disable data
			|synchronization from % 1?'"), Parameters.CorrespondentDescription);
	
	Items.TitleInformational.Title = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en = 'Data
			|synchronization with % 1 is disabled.'"), Parameters.CorrespondentDescription);
	
	// Set the current table of transitions
	DisableDataSynchronizationScript();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Position at the assistant's first step
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If GoToNumber > 1
		AND GoToNumber < 5 Then
		
		Notify("Disable_DataSynchronization");
		
	EndIf;
	
EndProcedure

// Wait handlers

&AtClient
Procedure LongOperationIdleHandler()
	
	Try
		StatusOfSession = StatusOfSession(Session);
	Except
		WriteErrorInEventLogMonitor(
			DetailErrorDescription(ErrorInfo()), EventLogMonitorEventDataSyncronizationSetting);
		SkipBack();
		ShowMessageBox(, NStr("en = 'Failed to execute the operation.'"));
		Return;
	EndTry;
	
	If StatusOfSession = "Successfully" Then
		
		GoToNext();
		
	ElsIf StatusOfSession = "Error" Then
		
		SkipBack();
		
		ShowMessageBox(, NStr("en = 'Failed to execute the operation.'"));
		
	Else
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Supplied part

&AtClient
Procedure DisableDataSynchronization(Command)
	
	GoToNext();
	
EndProcedure

&AtClient
Procedure CommandCancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure CloseCommand(Command)
	
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
		Raise NStr("en = 'Page for displaying has not been defined.'");
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
		Raise NStr("en = 'Page for displaying has not been defined.'");
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
		Raise NStr("en = 'Page for displaying has not been defined.'");
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
Procedure WriteErrorInEventLogMonitor(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Transition events handlers

// Page 2 (waiting)
//
&AtClient
Function Attachable_SynchronizationDisableExpectation_LongOperationProcessing(Cancel, GoToNext)
	
	RequestToDisableSynchronization(Cancel);
	
	If Cancel Then
		ShowMessageBox(, NStr("en = 'Failed to execute the operation.'"));
	EndIf;
	
EndFunction

// Page 2 (waiting)
//
&AtClient
Function Attachable_SynchronizationDisableExpectationLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("LongOperationIdleHandler", 5, True);
	
EndFunction

// Page 2 (waiting)
//
&AtClient
Function Attachable_SynchronizationDisableExpectationLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	Notify("Disable_DataSynchronization");
	
	Items.CloseCommand.DefaultButton = True;
	
EndFunction

&AtServer
Procedure RequestToDisableSynchronization(Cancel)
	
	If Not DataExchangeSaaS.DeleteSettingExchange(ExchangePlanName, CorrespondentDataArea, Session) Then
		Cancel = True;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Initialization of assistant transitions

&AtServer
Procedure DisableDataSynchronizationScript()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "Begin",                          "NavigationPageStart");
	GoToTableNewRow(2, "SynchronizationDisableExpectation", "NavigationPageWait",,,,, True, "SynchronizationDisableExpectation_LongOperationProcessing");
	GoToTableNewRow(3, "SynchronizationDisableExpectation", "NavigationPageWait",,,,, True, "DisablePendingSynchronizationOperation_LongTreatmentOperation");
	GoToTableNewRow(4, "SynchronizationDisableExpectation", "NavigationPageWait",,,,, True, "DisablePendingCompletionOfLongRunningOperation_SyncProcessingLongRunningOperation");
	GoToTableNewRow(5, "End",                       "NavigationPageEnd");
	
EndProcedure

#EndRegion