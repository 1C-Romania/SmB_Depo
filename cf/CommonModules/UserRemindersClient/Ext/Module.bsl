////////////////////////////////////////////////////////////////////////////////
// Subsystem "User reminders".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Launches the periodical check of current user reminders.
Procedure Enable() Export
	CheckCurrentReminders();
EndProcedure

// Disables the periodical check of current user reminders.
Procedure Disable() Export
	DetachIdleHandler("CheckCurrentReminders");
EndProcedure

// Creates a new reminder at the time specified.
//
// Parameters:
//  Text - String - reminder text;
//  Time - Date - reminder date and time;
//  Subject - AnyRef - reminder item.
//
Procedure RemindAtSpecifiedTime(Text, Time, Subject = Undefined) Export
	
	Reminder = UserRemindersServerCall.ConnectReminderAtSpecifiedTime(
		Text, Time, Subject);
		
	UpdateRecordInNotificationsCache(Reminder);
	ResetTimerOnCurrentNotificationsCheck();
	
EndProcedure

// Creates a new reminder at the time calculated with respect to the time in the subject.
//
// Parameters:
//  Text - String - reminder text;
//  Interval - Number - time in seconds within which it is required to remind with respect to the date in the subject attribute;
//  Subject - AnyRef - reminder subject;
//  AttributeName - String - subject attribute name with respect to which the reminder term is set.
//
Procedure RemindToTimeSubject(Text, Interval, Subject, AttributeName) Export
	
	Reminder = UserRemindersServerCall.ConnectReminderPriorToTimeOf(
		Text, Interval, Subject, AttributeName);
		
	UpdateRecordInNotificationsCache(Reminder);
	ResetTimerOnCurrentNotificationsCheck();
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// Activates wait handler that checks user's current reminders.
Procedure AfterSystemOperationStart() Export
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If Not ClientWorkParameters.CanUseSeparatedData Then
		Return;
	EndIf;
	
	If ClientWorkParameters.ReminderSettings.UseReminders Then
		AttachIdleHandler("CheckCurrentReminders", 60, True); // IN 60 seconds after launching the client.
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Resets the timer of current reminders check and start checking immediately.
Procedure ResetTimerOnCurrentNotificationsCheck() Export
	DetachIdleHandler("CheckCurrentReminders");
	CheckCurrentReminders();
EndProcedure

// Opens notification form
Procedure OpenNotificationForm() Export
	NotificationForm = UserRemindersClientReUse.GetReminderForm();
	NotificationForm.Open();
EndProcedure

// Returns the cached alerts of the current user deleting the non-occurred alerts from the result.
//
// Parameters:
//  TimeOfTheClosest - Date - the time of the nearest upcoming reminder is returned in this parameter. If
//                           the nearest reminder is outside the cache selection, then the Undefined is returned.
Function GetCurrentNotifications(TimeOfTheClosest = Undefined) Export
	
	NotificationTable = UserRemindersClientReUse.GetRemindersForCurrentUser();
	Result = New Array;
	
	TimeOfTheClosest = Undefined;
	
	For Each Notification IN NotificationTable Do
		If Notification.ReminderPeriod <= CommonUseClient.SessionDate() Then
			Result.Add(Notification);
		Else                                                           
			If TimeOfTheClosest = Undefined Then
				TimeOfTheClosest = Notification.ReminderPeriod;
			Else
				TimeOfTheClosest = min(TimeOfTheClosest, Notification.ReminderPeriod);
			EndIf;
		EndIf;
	EndDo;		
	
	Return Result;
	
EndFunction

// Updates the record in the cache of result of running the GetRemindersForCurrentUser() function.
Procedure UpdateRecordInNotificationsCache(NotificationParameters) Export
	NotificationCache = UserRemindersClientReUse.GetRemindersForCurrentUser();
	Record = FindRecordInNotificationCache(NotificationCache, NotificationParameters);
	If Record <> Undefined Then
		FillPropertyValues(Record, NotificationParameters);
	Else
		NotificationCache.Add(NotificationParameters);
	EndIf;
EndProcedure

// Deletes the record from the cache of result of running the GetRemindersForCurrentUser() function.
Procedure DeleteRecordFromNotificationCache(NotificationParameters) Export
	NotificationCache = UserRemindersClientReUse.GetRemindersForCurrentUser();
	Record = FindRecordInNotificationCache(NotificationCache, NotificationParameters);
	If Record <> Undefined Then
		NotificationCache.Delete(NotificationCache.Find(Record));
	EndIf;
EndProcedure

// Returns the record from the cache of result of running the GetRemindersForCurrentUser() function.
Function FindRecordInNotificationCache(NotificationCache, NotificationParameters)
	For Each Record IN NotificationCache Do
		If Record.Source = NotificationParameters.Source
		   AND Record.EventTime = NotificationParameters.EventTime Then
			Return Record;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

#EndRegion
