
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If CommonUseClientServer.ThisIsWebClient() Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ReNotificationTerm = "15 m";
	ReNotificationTerm = UserRemindersClientServer.MakeTime(ReNotificationTerm);
	
	UpdateTableOfReminders();
	
	FillTimeReReminders();
	
	UpdateTimeTableOfReminders();
	AttachIdleHandler("UpdateTimeTableOfReminders", 5);
	Activate();
EndProcedure

&AtClient
Procedure OnReopen()
	UpdateTableOfReminders();
	ThisObject.CurrentItem = Items.ReNotificationTerm;
	Activate();
EndProcedure

&AtClient
Procedure OnClose()
	DeferActiveReminders();
	UserRemindersClient.ResetTimerOnCurrentNotificationsCheck();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure TermRepeatNotificationsOnChange(Item)
	ReNotificationTerm = UserRemindersClientServer.MakeTime(ReNotificationTerm);
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersReminders

&AtClient
Procedure RemindersSelect(Item, SelectedRow, Field, StandardProcessing)
	OpenReminder();
EndProcedure

&AtClient
Procedure RemindersOnActivateRow(Item)
	
	If Item.CurrentRow = Undefined Then
		Return;
	EndIf;
		
	Source = Item.CurrentData.Source;
	SourceString = Item.CurrentData.SourceString;
	
	IsSource = ValueIsFilled(Source);
	Items.RemindersOpenContextMenu.Enabled = IsSource;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Change(Command)
	EditReminder();
EndProcedure

&AtClient
Procedure CommandOpen(Command)
	OpenReminder();
EndProcedure

&AtClient
Procedure Postpone(Command)
	DeferActiveReminders();
EndProcedure

&AtClient
Procedure Stop(Command)
	If Items.Reminders.CurrentData = Undefined Then
		Return;
	EndIf;
	
	For Each RowIndex IN Items.Reminders.SelectedRows Do
		RowData = Reminders.FindByID(RowIndex);
	
		ReminderParameters = UserRemindersClientServer.GetReminderStructure(RowData);
		
		DisableReminder(ReminderParameters);
		UserRemindersClient.DeleteRecordFromNotificationCache(RowData);
	EndDo;
	
	NotifyChanged(Type("InformationRegisterRecordKey.UserReminders"));
	
	UpdateTableOfReminders();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure AttachReminder(ReminderParameters)
	UserRemindersService.AttachReminder(ReminderParameters, True);
EndProcedure

&AtServer
Procedure DisableReminder(ReminderParameters)
	UserRemindersService.DisableReminder(ReminderParameters);
EndProcedure

&AtClient
Procedure UpdateTableOfReminders() 

	DetachIdleHandler("UpdateTableOfReminders");
	
	TimeOfTheClosest = Undefined;
	TableReminders = UserRemindersClient.GetCurrentNotifications(TimeOfTheClosest);
	For Each Reminder IN TableReminders Do
		FoundStrings = Reminders.FindRows(New Structure("Source,EventTime", Reminder.Source, Reminder.EventTime));
		If FoundStrings.Count() > 0 Then
			FillPropertyValues(FoundStrings[0], Reminder, , "ReminderPeriod");
		Else
			NewRow = Reminders.Add();
			FillPropertyValues(NewRow, Reminder);
		EndIf;
	EndDo;
	
	RowsForDeletion = New Array;
	For Each Reminder IN Reminders Do
		If ValueIsFilled(Reminder.Source) AND IsBlankString(Reminder.SourceString) Then
			RefreshPresentationOfItems();
		EndIf;
			
		StringFound = False;
		For Each RowCache IN TableReminders Do
			If RowCache.Source = Reminder.Source AND RowCache.EventTime = Reminder.EventTime Then
				StringFound = True;
				Break;
			EndIf;
		EndDo;
		If Not StringFound Then 
			RowsForDeletion.Add(Reminder);
		EndIf;
	EndDo;
	
	For Each String IN RowsForDeletion Do
		Reminders.Delete(String);
	EndDo;
	
	SetVisible();
	
	Interval = 15; // Table update at least 1 time in 15 sec.
	If TimeOfTheClosest <> Undefined Then 
		Interval = Max(min(Interval, TimeOfTheClosest - CommonUseClient.SessionDate()), 1); 
	EndIf;
	
	AttachIdleHandler("UpdateTableOfReminders", Interval, True);
	
EndProcedure

&AtServer
Procedure RefreshPresentationOfItems()
	
	For Each Reminder IN Reminders Do
		If ValueIsFilled(Reminder.Source) Then
			Reminder.SourceString = CommonUse.SubjectString(Reminder.Source);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure UpdateTimeTableOfReminders()
	For Each TableRow IN Reminders Do
		TimePresentation = NStr("en = 'term is not defined'");
		
		If ValueIsFilled(TableRow.EventTime) Then
			Time = CommonUseClient.SessionDate() - TableRow.EventTime;
			If Time > 60*60*24 Or Time < -60*60*24 Then
				Time = BegOfDay(CommonUseClient.SessionDate()) - BegOfDay(TableRow.EventTime);
			EndIf;
			TimePresentation = TimeIntervalPresentation(Time);
		EndIf;
		
		If TableRow.EventTimeString <> TimePresentation Then
			TableRow.EventTimeString = TimePresentation;
		EndIf;
		
	EndDo;
EndProcedure

&AtClient
Procedure DeferActiveReminders()
	TimeInterval = UserRemindersClientServer.GetTimeIntervalFromString(ReNotificationTerm);
	For Each TableRow IN Reminders Do
		TableRow.ReminderPeriod = CommonUseClient.SessionDate() + TimeInterval;
		
		ReminderParameters = UserRemindersClientServer.GetReminderStructure(TableRow);
		
		AttachReminder(ReminderParameters);
		UserRemindersClient.UpdateRecordInNotificationsCache(TableRow);
	EndDo;
	UpdateTableOfReminders();
EndProcedure

&AtClient
Procedure OpenReminder()
	If Items.Reminders.CurrentData = Undefined Then
		Return;
	EndIf;
	Source = Items.Reminders.CurrentData.Source;
	If ValueIsFilled(Source) Then
		ShowValue(, Source);
	Else
		EditReminder();
	EndIf;
EndProcedure

&AtClient
Procedure EditReminder()
	ReminderParameters = New Structure("User,Source,EventTime");
	FillPropertyValues(ReminderParameters, Items.Reminders.CurrentData);
	
	OpenForm("InformationRegister.UserReminders.Form.Reminder", New Structure("Key", GetRecordKey(ReminderParameters)));
EndProcedure

&AtServer
Function GetRecordKey(ReminderParameters)
	Return InformationRegisters.UserReminders.CreateRecordKey(ReminderParameters);
EndFunction

&AtClient
Procedure SetVisible()
	IsDataInTable = Reminders.Count() > 0;
	
	If Not IsDataInTable AND ThisObject.IsOpen() Then
		ThisObject.Close();
	EndIf;
	
	Items.ButtonPanel.Enabled = IsDataInTable;
EndProcedure

&AtClient
Procedure FillTimeReReminders()
	For Each Item IN Items.ReNotificationTerm.ChoiceList Do
		Item.Presentation = UserRemindersClientServer.MakeTime(Item.Value); 
	EndDo;
EndProcedure	

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Record_UserReminders" Then 
		UpdateTableOfReminders();
	EndIf;
EndProcedure

&AtClient
Function TimeIntervalPresentation(Val TimeQuantity)
	Result = "";
	
	WeeksRepresentation = NStr("en = 'Week'") + "," + NStr("en = 'of the week'") + "," + NStr("en = 'weeks'");
	DaysRepresentation = NStr("en = 'day'") + "," + NStr("en = 'days'") + "," + NStr("en = 'days'");
	HoursRepresentation = NStr("en = 'hour'") + "," + NStr("en = 'hours'") + "," + NStr("en = 'Hours'");
	MinutesRepresentation = NStr("en = 'minute'") + "," + NStr("en = 'Minutes'") + "," + NStr("en = 'minutes'");
	
	TimeQuantity = Number(TimeQuantity);
	
	EventIsOccurred = True;
	PresentationPattern = NStr("en = '%1 ago'");
	If TimeQuantity < 0 Then
		PresentationPattern = NStr("en = 'in %1'");
		TimeQuantity = -TimeQuantity;
		EventIsOccurred = False;
	EndIf;
	
	WeeksNumber = Int(TimeQuantity / 60/60/24/7);
	DaysNumber   = Int(TimeQuantity / 60/60/24);
	HoursCount  = Int(TimeQuantity / 60/60);
	MinutesCount  = Int(TimeQuantity / 60);
	CountSeconds = Int(TimeQuantity);
	
	CountSeconds = CountSeconds - MinutesCount * 60;
	MinutesCount  = MinutesCount - HoursCount * 60;
	HoursCount  = HoursCount - DaysNumber * 24;
	DaysNumber   = DaysNumber - WeeksNumber * 7;
	
	CurrentDate = CommonUseClient.SessionDate();
	
	If WeeksNumber > 4 Then
		If EventIsOccurred Then
			Return NStr("en = 'long ago'");
		Else
			Return NStr("en = 'not soon'");
		EndIf;
		
	ElsIf WeeksNumber > 1 Then
		Result = StringFunctionsClientServer.NumberInDigitsMeasurementUnitInWords(WeeksNumber, WeeksRepresentation);
	ElsIf WeeksNumber > 0 Then
		Result = NStr("en = 'Week'");
		
	ElsIf DaysNumber > 1 Then
		If BegOfDay(CurrentDate) - BegOfDay(CurrentDate - TimeQuantity) = 60*60*24 * 2 Then
			If EventIsOccurred Then
				Return NStr("en = 'day before yesterday'");
			Else
				Return NStr("en = 'day after tomorrow'");
			EndIf;
		Else
			Result = StringFunctionsClientServer.NumberInDigitsMeasurementUnitInWords(DaysNumber, DaysRepresentation);
		EndIf;
	ElsIf HoursCount + DaysNumber * 24 > 12 
		AND BegOfDay(CurrentDate) - BegOfDay(CurrentDate - TimeQuantity) = 60*60*24 Then
			If EventIsOccurred Then
				Return NStr("en = 'yesterday'");
			Else
				Return NStr("en = 'tomorrow'");
			EndIf;
	ElsIf DaysNumber > 0 Then
		Result = NStr("en = 'day'");
		
	ElsIf HoursCount > 1 Then
		Result = StringFunctionsClientServer.NumberInDigitsMeasurementUnitInWords(HoursCount, HoursRepresentation);
	ElsIf HoursCount > 0 Then
		Result = NStr("en = 'hour'");
		
	ElsIf MinutesCount > 1 Then
		Result = StringFunctionsClientServer.NumberInDigitsMeasurementUnitInWords(MinutesCount, MinutesRepresentation);
	ElsIf MinutesCount > 0 Then
		Result = NStr("en = 'minute'");
		
	Else
		Return NStr("en = 'now'");
	EndIf;
	
	Result = StringFunctionsClientServer.PlaceParametersIntoString(PresentationPattern, Result);
	
	Return Result;
EndFunction

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
