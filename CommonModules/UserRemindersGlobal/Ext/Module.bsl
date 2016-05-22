////////////////////////////////////////////////////////////////////////////////
// Subsystem "User reminders".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Opens currents user reminders form.
//
Procedure CheckCurrentReminders() Export

	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
	CheckRemindersInterval = ClientWorkParameters.ReminderSettings.CheckRemindersInterval;
	
	// Opening current alerts form.
	TimeOfTheClosest = Undefined;
	IntervalFollowingChecks = CheckRemindersInterval * 60;
	
	If UserRemindersClient.GetCurrentNotifications(TimeOfTheClosest).Count() > 0 Then
		UserRemindersClient.OpenNotificationForm();
	ElsIf ValueIsFilled(TimeOfTheClosest) Then
		IntervalFollowingChecks = Max(min(TimeOfTheClosest - CommonUseClient.SessionDate(), IntervalFollowingChecks), 1);
	EndIf;
	
	AttachIdleHandler("CheckCurrentReminders", IntervalFollowingChecks, True);
	
EndProcedure

#EndRegion
