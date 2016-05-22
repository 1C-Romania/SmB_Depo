////////////////////////////////////////////////////////////////////////////////
// Subsystem "User reminders".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Announces events of the UserReminders subsystem:
//
// Server events:
//   AtFillingSourceAttributeListWithReminderDates.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Overrides the array of object attributes for which the time of reminder is allowed to be set.
	// For example, you can hide those attributes with dates that are service attributes or there
	//is not sense to set a reminder for them: date of a document or job, and others.
	// 
	//Parameters:
	//  Source - Any refs - reference to the object for which the attributes array with dates is generated.
	//  AttributeArray - Array - Array of attributes names (from metadata) containing dates.
	//
	// Syntax:
	// Procedure AtFillingSourceAttributesListWithDatesForReminder (Source, AttributesArray) Export
	//
	// (The
	// same as UserRemindersClientServerOverridable.AtFillingSourceAttributesListWithDatesForReminder).
	//
	ServerEvents.Add("StandardSubsystems.UserReminders\OnFillSourceAttributeListWithReminderDates");
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\AfterSystemOperationStart"].Add(
			"UserRemindersClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsRunning"].Add(
		"UserRemindersService");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
		"UserRemindersService");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns standard schedules for periodic reminders.
Function GetStandardSchedulesToRemind() Export
	
	Result = New Map;
		
	// on Mondays at 9:00
	Schedule = New JobSchedule;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.WeeksPeriod = 1;
	Schedule.BeginTime = '00010101090000';
	WeekDays = New Array;
	WeekDays.Add(1);
	Schedule.WeekDays = WeekDays;
	Result.Insert(NStr("en = 'on Mondays, at 9:00'"), Schedule);
	
	// on Fridays at 3 p.m.
	Schedule = New JobSchedule;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.WeeksPeriod = 1;
	Schedule.BeginTime = '00010101150000';
	WeekDays = New Array;
	WeekDays.Add(5);
	Schedule.WeekDays = WeekDays;
	Result.Insert(NStr("en = 'on Fridays, at 15:00'"), Schedule);
	
	// each day at 9:00
	Schedule = New JobSchedule;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.WeeksPeriod = 1;
	Schedule.BeginTime = '00010101090000';
	Result.Insert(NStr("en = 'every day, at 9:00'"), Schedule);
	
	// to change the list
	UserRemindersClientServerOverridable.OnGettingStandardSchedulesToRemind(Result);
	
	Return Result;
	
EndFunction

// Returns the structure of user reminders settings.
Function GetReminderSettings() Export
	
	Result = New Structure;
	Result.Insert("UseReminders", HasRightToUseNotifications() AND GetFunctionalOption("UseUserReminders"));
	Result.Insert("CheckRemindersInterval", GetCheckRemindersInterval());
	
	Return Result;
	
EndFunction

// Checks availability of the right to change UserReminder RS.
//
// Returns:
//  Boolean - True if the right is provided.
Function HasRightToUseNotifications()
	Return AccessRight("Update", Metadata.InformationRegisters.UserReminders); 
EndFunction

// Returns the nearest schedule date relative to the date presented in the parameter.
//
// Parameters:
//  Schedule - JobSchedule - any schedule.
//  PreviousDate - Date - date of the previous event according to the schedule.
//
// Returns:
//   Date - date and time of the next event as per the schedule.
//
Function GetTheClosestEventDateOnSchedule(Schedule, PreviousDate = '000101010000') Export

	Result = Undefined;
	
	BeginnigDate = PreviousDate;
	If Not ValueIsFilled(BeginnigDate) Then
		BeginnigDate = CurrentSessionDate();
	EndIf;

	Calendar = GetCalendarForFuture(365*4+1, BeginnigDate, Schedule.StartDate, Schedule.DaysRepeatPeriod, Schedule.WeeksPeriod);
	
	WeekDays = Schedule.WeekDays;
	If WeekDays.Count() = 0 Then
		WeekDays = New Array;
		For Day = 1 To 7 Do
			WeekDays.Add(Day);
		EndDo;
	EndIf;
	
	Months = Schedule.Months;
	If Months.Count() = 0 Then
		Months = New Array;
		For Month = 1 To 12 Do
			Months.Add(Month);
		EndDo;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.Text = "SELECT * INTO Calendar FROM &Calendar AS Calendar";
	Query.SetParameter("Calendar", Calendar);
	Query.Execute();
	
	Query.SetParameter("StartDate",			Schedule.StartDate);
	Query.SetParameter("EndDate",			Schedule.EndDate);
	Query.SetParameter("WeekDays",			WeekDays);
	Query.SetParameter("Months",				Months);
	Query.SetParameter("DayInMonth",		Schedule.DayInMonth);
	Query.SetParameter("WeekDayInMonth",	Schedule.WeekDayInMonth);
	Query.SetParameter("DaysRepeatPeriod",	?(Schedule.DaysRepeatPeriod = 0,1,Schedule.DaysRepeatPeriod));
	Query.SetParameter("WeeksPeriod",		?(Schedule.WeeksPeriod = 0,1,Schedule.WeeksPeriod));
	
	Query.Text = 
	"SELECT
	|	Calendar.Date,
	|	Calendar.MonthNumber,
	|	Calendar.NumberOfDayOfWeekInMonth,
	|	Calendar.NumberOfDayOfWeekWithEndOfMonth,
	|	Calendar.DayOfMonth,
	|	Calendar.DayNumberInMonthSinceEndOfMonth,
	|	Calendar.DayOfWeek,
	|	Calendar.NumberOfDaysInPeriod,
	|	Calendar.WeekNumberInPeriod
	|FROM
	|	Calendar AS Calendar
	|WHERE
	|	CASE
	|			WHEN &StartDate = DATETIME(1, 1, 1, 0, 0, 0)
	|				THEN TRUE
	|			ELSE Calendar.Date >= &StartDate
	|		END
	|	AND CASE
	|			WHEN &EndDate = DATETIME(1, 1, 1, 0, 0, 0)
	|				THEN TRUE
	|			ELSE Calendar.Date <= &EndDate
	|		END
	|	AND Calendar.DayOfWeek IN(&WeekDays)
	|	AND Calendar.MonthNumber IN(&Months)
	|	AND CASE
	|			WHEN &DayInMonth = 0
	|				THEN TRUE
	|			ELSE CASE
	|					WHEN &DayInMonth > 0
	|						THEN Calendar.DayOfMonth = &DayInMonth
	|					ELSE Calendar.DayNumberInMonthSinceEndOfMonth = -&DayInMonth
	|				END
	|		END
	|	AND CASE
	|			WHEN &WeekDayInMonth = 0
	|				THEN TRUE
	|			ELSE CASE
	|					WHEN &WeekDayInMonth > 0
	|						THEN Calendar.NumberOfDayOfWeekInMonth = &WeekDayInMonth
	|					ELSE Calendar.NumberOfDayOfWeekWithEndOfMonth = -&WeekDayInMonth
	|				END
	|		END
	|	AND Calendar.NumberOfDaysInPeriod = &DaysRepeatPeriod
	|	AND Calendar.WeekNumberInPeriod = &WeeksPeriod";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		ClosestDate = Selection.Date;
		
		TimeReference = '00010101';
		If BegOfDay(ClosestDate) = BegOfDay(CurrentSessionDate()) Then
			TimeReference = TimeReference + (CurrentSessionDate()-BegOfDay(CurrentSessionDate()));
		EndIf;
		
		ClosestTime = GetClosestTimeFromSchedule(Schedule, TimeReference);
		If ClosestTime <> Undefined Then
			Result = ClosestDate + (ClosestTime - '00010101');
		Else
			If Selection.Next() Then
				Time = GetClosestTimeFromSchedule(Schedule);
				Result = Selection.Date + (Time - '00010101');
			EndIf;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

Function GetCalendarForFuture(NumberOfDaysInCalendar, BeginnigDate, Val PeriodicityStartDate = Undefined, Val DaysPeriod = 1, Val WeeksPeriod = 1) 
	
	If WeeksPeriod = 0 Then 
		WeeksPeriod = 1;
	EndIf;
	
	If DaysPeriod = 0 Then
		DaysPeriod = 1;
	EndIf;
	
	If Not ValueIsFilled(PeriodicityStartDate) Then
		PeriodicityStartDate = BeginnigDate;
	EndIf;
	
	Calendar = New ValueTable;
	Calendar.Columns.Add("Date", New TypeDescription("Date",,,New DateQualifiers()));
	Calendar.Columns.Add("MonthNumber", New TypeDescription("Number",New NumberQualifiers(2,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("NumberOfDayOfWeekInMonth", New TypeDescription("Number",New NumberQualifiers(1,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("NumberOfDayOfWeekWithEndOfMonth", New TypeDescription("Number",New NumberQualifiers(1,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("DayOfMonth", New TypeDescription("Number",New NumberQualifiers(2,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("DayNumberInMonthSinceEndOfMonth", New TypeDescription("Number",New NumberQualifiers(2,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("DayOfWeek", New TypeDescription("Number",New NumberQualifiers(2,0,AllowedSign.Nonnegative)));	
	Calendar.Columns.Add("NumberOfDaysInPeriod", New TypeDescription("Number",New NumberQualifiers(3,0,AllowedSign.Nonnegative)));	
	Calendar.Columns.Add("WeekNumberInPeriod", New TypeDescription("Number",New NumberQualifiers(3,0,AllowedSign.Nonnegative)));
	
	Date = BegOfDay(BeginnigDate);
	PeriodicityStartDate = BegOfDay(PeriodicityStartDate);
	NumberOfDaysInPeriod = 0;
	WeekNumberInPeriod = 0;
	
	If PeriodicityStartDate <= Date Then
		DaysNumber = (Date - PeriodicityStartDate)/60/60/24;
		NumberOfDaysInPeriod = DaysNumber - Int(DaysNumber/DaysPeriod)*DaysPeriod;
		
		WeeksNumber = Int(DaysNumber / 7);
		WeekNumberInPeriod = WeeksNumber - Int(WeeksNumber/WeeksPeriod)*WeeksPeriod;
	EndIf;
	
	If NumberOfDaysInPeriod = 0 Then 
		NumberOfDaysInPeriod = DaysPeriod;
	EndIf;
	
	If WeekNumberInPeriod = 0 Then 
		WeekNumberInPeriod = WeeksPeriod;
	EndIf;
	
	For Counter = 0 To NumberOfDaysInCalendar - 1 Do
		
		Date = BegOfDay(BeginnigDate) + Counter * 60*60*24;
		NewRow = Calendar.Add();
		NewRow.Date = Date;
		NewRow.MonthNumber = Month(Date);
		NewRow.NumberOfDayOfWeekInMonth = Int((Date - BegOfMonth(Date))/60/60/24/7) + 1;
		NewRow.NumberOfDayOfWeekWithEndOfMonth = Int((EndOfMonth(BegOfDay(Date)) - Date)/60/60/24/7) + 1;
		NewRow.DayOfMonth = Day(Date);
		NewRow.DayNumberInMonthSinceEndOfMonth = Day(EndOfMonth(BegOfDay(Date))) - Day(Date) + 1;
		NewRow.DayOfWeek = WeekDay(Date);
		
		If PeriodicityStartDate <= Date Then
			NewRow.NumberOfDaysInPeriod = NumberOfDaysInPeriod;
			NewRow.WeekNumberInPeriod = WeekNumberInPeriod;
			
			NumberOfDaysInPeriod = ?(NumberOfDaysInPeriod+1 > DaysPeriod, 1, NumberOfDaysInPeriod+1);
			
			If NewRow.DayOfWeek = 1 Then
				WeekNumberInPeriod = ?(WeekNumberInPeriod+1 > WeeksPeriod, 1, WeekNumberInPeriod+1);
			EndIf;
		EndIf;
		
	EndDo;
	
	Return Calendar;
	
EndFunction

Function GetClosestTimeFromSchedule(Schedule, Val TimeReference = '000101010000')
	
	Result = Undefined;
	
	ValueList = New ValueList;
	
	If Schedule.DetailedDailySchedules.Count() = 0 Then
		ValueList.Add(Schedule.BeginTime);
	Else
		For Each DailySchedule IN Schedule.DetailedDailySchedules Do
			ValueList.Add(DailySchedule.BeginTime);
		EndDo;
	EndIf;
	
	ValueList.SortByValue(SortDirection.Asc);
	
	For Each TimeOfDay IN ValueList Do
		If TimeReference <= TimeOfDay.Value Then
			Result = TimeOfDay.Value;
			Break;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns the time interval in minutes in which it is required to repeat current reminders validation.
Function GetCheckRemindersInterval(User = Undefined) Export
	Interval = CommonUse.CommonSettingsStorageImport(
									"ReminderSettings", 
									"CheckRemindersInterval", 
									1,
									,
									GetInfobaseUserName(User));
	Return Max(Interval, 1);
EndFunction

// Converts the table to an array of structures.
//
// Parameters:
//  ValueTable - an arbitrary table of values with named columns.
//
// Return
//  value Array - array of structures containing table line values.
Function GetStructuresArrayFromTable(ValueTable) Export
	Result = New Array;
	For Each String IN ValueTable Do
		StringStructure = New Structure;
		For Each Column IN ValueTable.Columns Do
			StringStructure.Insert(Column.Name, String[Column.Name]);
		EndDo;
		Result.Add(StringStructure);
	EndDo;
	Return Result;			
EndFunction

Function GetInfobaseUserName(User)
	If Not ValueIsFilled(User) Then
		Return Undefined;
	EndIf;
	
	SetPrivilegedMode(True);
	
	IBUser = InfobaseUsers.FindByUUID(CommonUse.ObjectAttributeValue(User, "InfobaseUserID"));
	If IBUser = Undefined Then
		Return Undefined;
	EndIf;
	
	Return IBUser.Name;
EndFunction

// Receives attribute value for any object of reference type.
Function GetItemAttributeValue(SubjectRef, AttributeName) Export
	
	Result = Undefined;
	
	Query = New Query;
	
	QueryText =
	"SELECT 
	|	Table.&Attribute AS Attribute
	|FROM
	|	&TableName AS Table
	|WHERE
	|	Table.Ref = &Ref";

	QueryText = StrReplace(QueryText, "&TableName", SubjectRef.Metadata().FullName());
	QueryText = StrReplace(QueryText, "&Attribute", AttributeName);
	
	Query.Text = QueryText;
	
	Query.SetParameter("Ref", SubjectRef);

	Result = Query.Execute();

	Selection = Result.Select();

	If Selection.Next() Then
		Result = Selection.Attribute;
	EndIf;

	Return Result;
	
EndFunction

// Checks changes in attributes of items, for which
// user subscribtion exists, changes the reminder term if necessary.
Procedure CheckDateChangesInSubject(Subject) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Reminders.User,
	|	Reminders.EventTime,
	|	Reminders.Source,
	|	Reminders.ReminderPeriod,
	|	Reminders.Definition,
	|	Reminders.ReminderTimeSettingVariant,
	|	Reminders.ReminderInterval,
	|	Reminders.SourceAttributeName,
	|	Reminders.Schedule
	|FROM
	|	InformationRegister.UserReminders AS Reminders
	|WHERE
	|	Reminders.ReminderTimeSettingVariant = VALUE(Enum.ReminderTimeSettingVariants.RelativelyToSubjectTime)
	|	AND Reminders.Source = &Source";
	
	Query.SetParameter("Source", Subject);
	
	ResultTable = Query.Execute().Unload();
	
	For Each TableRow IN ResultTable Do
		DateObject = GetItemAttributeValue(TableRow.Source, TableRow.SourceAttributeName);
		If (DateObject - TableRow.ReminderInterval) <> TableRow.EventTime Then
			DisableReminder(TableRow);
			TableRow.ReminderPeriod = DateObject - TableRow.ReminderInterval;
			TableRow.EventTime = DateObject;
			AttachReminder(TableRow);
		EndIf;
	EndDo;
EndProcedure

// Handler of the subscription to the OnWrite of object event regarding which reminders can be created.
Procedure CheckDatesChangesInSubjectOnWrite(Source, Cancel) Export
	If Not CommonUse.ThisIsExchangePlan(Source.Metadata()) AND Source.DataExchange.Load Then 
		Return; 
	EndIf;
	If GetFunctionalOption("UseUserReminders") Then
		CheckDateChangesInSubject(Source.Ref);
	EndIf;
EndProcedure

// Creates a reminder for the user. If a reminder for the object already exists, the application rewrites it.
Procedure AttachReminder(ReminderParameters, UpdateReminderDueTime = False) Export
	
	RecordSet = InformationRegisters.UserReminders.CreateRecordSet();
	RecordSet.Filter.User.Set(ReminderParameters.User);
	RecordSet.Filter.Source.Set(ReminderParameters.Source);
	RecordSet.Filter.EventTime.Set(ReminderParameters.EventTime);
	
	RecordSet.Read();
	
	If RecordSet.Count() = 0 Then
		If Not UpdateReminderDueTime Then
			NewRecord = RecordSet.Add();
			FillPropertyValues(NewRecord, ReminderParameters);
		EndIf;
	Else
		For Each Record IN RecordSet Do
			FillPropertyValues(Record, ReminderParameters,,?(UpdateReminderDueTime,"","ReminderPeriod"));
		EndDo;
	EndIf;
	
	RecordSet.Write();
	
EndProcedure

// Disables the reminder if any. If the reminder is periodic, the application links it to the nearest date as per the schedule.
Procedure DisableReminder(ReminderParameters, AttachOnSchedule = True) Export
	
	// look for an existing record
	Query = New Query;
	
	QueryText = 
	"SELECT
	|	UserReminders.User,
	|	UserReminders.EventTime,
	|	UserReminders.Source,
	|	UserReminders.ReminderPeriod,
	|	UserReminders.Definition,
	|	UserReminders.ReminderTimeSettingVariant,
	|	UserReminders.Schedule
	|FROM
	|	InformationRegister.UserReminders AS UserReminders
	|WHERE
	|	UserReminders.User = &User
	|	AND UserReminders.EventTime = &EventTime
	|	AND UserReminders.Source = &Source";
	
	Query.SetParameter("User", ReminderParameters.User);
	Query.SetParameter("EventTime", ReminderParameters.EventTime);
	Query.SetParameter("Source", ReminderParameters.Source);
	
	Query.Text = QueryText;
	QueryResult = Query.Execute().Unload();
	Reminder = Undefined;
	If QueryResult.Count() > 0 Then
		Reminder = QueryResult[0];
	EndIf;
	
	// Delete the existing record.
	RecordSet = InformationRegisters.UserReminders.CreateRecordSet();
	RecordSet.Filter.User.Set(ReminderParameters.User);
	RecordSet.Filter.Source.Set(ReminderParameters.Source);
	RecordSet.Filter.EventTime.Set(ReminderParameters.EventTime);
	
	RecordSet.Clear();
	RecordSet.Write();
	
	NextDateOnSchedule = Undefined;
	NextDateOnScheduleDefined = False;
	
	// Enable the next reminder as per the schedule.
	If AttachOnSchedule AND Reminder <> Undefined Then
		If Reminder.ReminderTimeSettingVariant = PredefinedValue("Enum.ReminderTimeSettingVariants.Periodically") Then
			Schedule = Reminder.Schedule.Get();
			If Schedule.DaysRepeatPeriod > 0 Then
				NextDateOnSchedule = GetTheClosestEventDateOnSchedule(Schedule);
			EndIf;
			NextDateOnScheduleDefined = NextDateOnSchedule <> Undefined;
		EndIf;
		
		If NextDateOnScheduleDefined Then
			Reminder.EventTime = NextDateOnSchedule;
			Reminder.ReminderPeriod = Reminder.EventTime;
			AttachReminder(Reminder);
		EndIf;
	EndIf;
	
EndProcedure

// Creates a new reminder at the time specified.
Function ConnectReminderAtSpecifiedTime(Text, Time, Subject = Undefined) Export
	ReminderParameters = New Structure;
	ReminderParameters.Insert("Definition", Text);
	ReminderParameters.Insert("EventTime", Time);
	ReminderParameters.Insert("Source", Subject);
	
	Reminder = CreateReminder(ReminderParameters);
	AttachReminder(Reminder);
	
	Return Reminder;
EndFunction

// Creates a new reminder at the time calculated with respect to the time in the subject.
Function ConnectReminderPriorToTimeOf(Text, Interval, Subject, AttributeName) Export
	ReminderParameters = New Structure;
	ReminderParameters.Insert("Definition", Text);
	ReminderParameters.Insert("Source", Subject);
	ReminderParameters.Insert("SourceAttributeName", AttributeName);
	ReminderParameters.Insert("ReminderInterval", Interval);
	
	Reminder = CreateReminder(ReminderParameters);
	AttachReminder(Reminder);
	
	Return Reminder;
EndFunction

// Returns structure of a new reminder for the next connection.
Function CreateReminder(ReminderParameters)
	
	Reminder = UserRemindersClientServer.GetReminderStructure(ReminderParameters, True);
	
	If Not ValueIsFilled(Reminder.User) Then
		Reminder.User = UsersClientServer.CurrentUser();
	EndIf;
	
	If Not ValueIsFilled(Reminder.ReminderTimeSettingVariant) Then
		If ValueIsFilled(Reminder.Source) AND Not IsBlankString(Reminder.SourceAttributeName) Then
			Reminder.ReminderTimeSettingVariant = Enums.ReminderTimeSettingVariants.RelativelyToSubjectTime;
		Else
			Reminder.ReminderTimeSettingVariant = Enums.ReminderTimeSettingVariants.InSpecifiedTime;
		EndIf;
	EndIf;
	
	If Reminder.ReminderTimeSettingVariant = Enums.ReminderTimeSettingVariants.RelativelyToSubjectTime Then
		Reminder.EventTime = CommonUse.ObjectAttributeValue(Reminder.Source, Reminder.SourceAttributeName);
		Reminder.ReminderPeriod = Reminder.EventTime - ?(ValueIsFilled(Reminder.EventTime), Reminder.ReminderInterval, 0);
	ElsIf Reminder.ReminderTimeSettingVariant = Enums.ReminderTimeSettingVariants.RelativelyToCurrentTime Then
		Reminder.ReminderTimeSettingVariant = Enums.ReminderTimeSettingVariants.InSpecifiedTime;
		Reminder.EventTime = CurrentSessionDate() + Reminder.ReminderInterval;
	EndIf;
	
	If Not ValueIsFilled(Reminder.ReminderPeriod) Then
		Reminder.ReminderPeriod = Reminder.EventTime;
	EndIf;
	
	Return Reminder;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of SSL subsystems internal events.

// Fills the structure of the parameters required
// for functioning of the client code at the configuration start. 
//
// Parameters:
//   Parameters - Structure - structure of the start parameters.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystemsRunning(Parameters) Export
	
	Parameters.Insert("ReminderSettings", 
		New FixedStructure("UseReminders", GetReminderSettings().UseReminders));
		
EndProcedure 

// Fills the structure of the parameters required
// for the client configuration code.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystems(Parameters) Export
	
	Parameters.Insert("ReminderSettings", 
		New FixedStructure(GetReminderSettings()));
	
EndProcedure

#EndRegion
