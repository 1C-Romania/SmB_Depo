////////////////////////////////////////////////////////////////////////////////
// Subsystem "User reminders".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns the current user reminders form.
Function GetReminderForm() Export
	#If WebClient Then
	Return GetForm("InformationRegister.UserReminders.Form.NotificationForm");
	#Else
	Return GetForm("InformationRegister.UserReminders.Form.NotificationForm",,,,WindowOpenVariant.SingleWindow);
	#EndIf
EndFunction

// Requests the current user reminders set for 30 minutes ahead of the current time.
// Time is shifted from the actual time so that the data is relevant while the cache exists.
// When processing the result of the function execution it is required to take into account this peculiarity.
//
// Parameters:
//  No
//
// Return value
//  Array - values table converted to the array of structures containing data of table rows.
Function GetRemindersForCurrentUser() Export
	Return UserRemindersServerCall.GetRemindersForCurrentUser();
EndFunction

#EndRegion
