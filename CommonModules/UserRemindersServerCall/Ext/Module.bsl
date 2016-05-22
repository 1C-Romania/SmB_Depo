////////////////////////////////////////////////////////////////////////////////
// Subsystem "User reminders".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Runs a request on reminders for a current user at the moment CurrentSessionDate() + 30minutes.
// The moment is shifted from the current for using the function from
// the module with repeating use returned values.
// When processing the result of the function execution it is required to take into account this peculiarity.
//
// Parameters:
// No
//
// Return
//  value Array - values table converted to the array of structures containing data of table rows.
Function GetRemindersForCurrentUser() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Reminders.User AS User,
	|	Reminders.EventTime AS EventTime,
	|	Reminders.Source AS Source,
	|	Reminders.ReminderPeriod AS ReminderPeriod,
	|	Reminders.Definition AS Definition,
	|	2 AS PictureIndex
	|FROM
	|	InformationRegister.UserReminders AS Reminders
	|WHERE
	|	Reminders.ReminderPeriod <= &CurrentDate
	|	AND Reminders.User = &User
	|
	|ORDER BY
	|	EventTime";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate() + 30*60);// +30 minutes for cache
	Query.SetParameter("User", Users.CurrentUser());
	
	Result = UserRemindersService.GetStructuresArrayFromTable(Query.Execute().Unload());
	
	Return Result;
	
EndFunction

// Creates a new reminder at the time specified.
Function ConnectReminderAtSpecifiedTime(Text, Time, Subject = Undefined) Export
	
	Return UserRemindersService.ConnectReminderAtSpecifiedTime(
		Text, Time, Subject);
	
EndFunction

// Creates a new reminder at the time calculated with respect to the time in the subject.
Function ConnectReminderPriorToTimeOf(Text, Interval, Subject, AttributeName) Export
	
	Return UserRemindersService.ConnectReminderPriorToTimeOf(
		Text, Interval, Subject, AttributeName);
	
EndFunction

#EndRegion
