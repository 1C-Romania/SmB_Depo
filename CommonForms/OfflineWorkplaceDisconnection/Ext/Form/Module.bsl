
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	OfflineWorkplace = Parameters.OfflineWorkplace;
	
	If Not ValueIsFilled(OfflineWorkplace) Then
		Raise NStr("en = 'Offline workplace is not specified.'");
	EndIf;
	
	EventLogMonitorEventDeletionOfflineWorkplace = OfflineWorkService.EventLogMonitorEventDeletionOfflineWorkplace();
	
	SetMainScript();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Position at the assistant's first step
	SetGoToNumber(1);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure StopDataSynchronization(Command)
	
	GoToNext();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	Close();
	
EndProcedure

// Wait handlers

&AtClient
Procedure LongOperationIdleHandler()
	
	Try
		
		If JobCompleted(JobID) Then
			
			LongOperation = False;
			LongOperationFinished = True;
			GoToNext();
			
		Else
			
			LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler("LongOperationIdleHandler", IdleHandlerParameters.CurrentInterval, True);
			
		EndIf;
		
	Except
		
		WriteErrorInEventLogMonitor(
			DetailErrorDescription(ErrorInfo()), EventLogMonitorEventDeletionOfflineWorkplace);
		
		LongOperation = False;
		SkipBack();
		ShowMessageBox(,NStr("en = 'The errors have occurred during the work.'"));
		
	EndTry;
	
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
	
	If Not IsBlankString(GoToRowCurrent.DecorationPageName) Then
		
		Items.DecorationPanel.CurrentPage = Items[GoToRowCurrent.DecorationPageName];
		
	EndIf;
	
	// Set current button by default
	ButtonNext = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "StopDataSynchronization");
	
	If ButtonNext <> Undefined Then
		
		ButtonNext.DefaultButton = True;
		
	Else
		
		DoneButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "Close");
		
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
		
		If GoToRows.Count() = 0 Then
			Return;
		EndIf;
		
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
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() = 0 Then
			Return;
		EndIf;
		
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

&AtClient
Procedure GoToNext()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure SkipBack()
	
	ChangeGoToNumber(-1);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part - SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure DeleteOfflineWorkplace(Cancel)
	
	Result = LongActions.ExecuteInBackground(
					UUID,
					"OfflineWorkService.DeleteOfflineWorkplace",
					New Structure("OfflineWorkplace", OfflineWorkplace),
					NStr("en = 'Offline workplace deletion'"));
	
	If Not Result.JobCompleted Then
		LongOperation = True;
		JobID = Result.JobID;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure WriteErrorInEventLogMonitor(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part - Transition events handlers

&AtClient
Function Attachable_Wait_LongOperationProcessing(Cancel, GoToNext)
	
	LongOperation = False;
	LongOperationFinished = False;
	JobID = Undefined;
	
	DeleteOfflineWorkplace(Cancel);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = 'The errors have occurred during the work.'"));
		
	ElsIf Not LongOperation Then
		
		Notify("Deletes_HotSeat");
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WaitLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperation Then
		
		GoToNext = False;
		
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		
		AttachIdleHandler("LongOperationIdleHandler", IdleHandlerParameters.CurrentInterval, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WaitLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperationFinished Then
		
		Notify("Deletes_HotSeat");
		
	EndIf;
	
EndFunction

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part - Initialize assistant's transitions

&AtServer
Procedure SetMainScript()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "Begin",     "NavigationPageStart");
	GoToTableNewRow(2, "Wait",   "NavigationPageWait",,,,, True, "Waiting_LongOperationProcessing");
	GoToTableNewRow(3, "Wait",   "NavigationPageWait",,,,, True, "WaitingLongOperation_LongOperationProcessing");
	GoToTableNewRow(4, "Wait",   "NavigationPageWait",,,,, True, "WaitingLongOperationEnding_LongOperationProcessing");
	GoToTableNewRow(5, "End", "NavigationPageEnd");
	
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
