#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Function reads graphic data from register
//
// Parameters
//  Calendar		 - Refs to the current catalog item
//  YearNumber	 - Year number for which it is required to read the calendar
//
// Return value 
//  ValueList		- value list in which dates entering in calendar are stored
//
Function ReadWorkScheduleDataFromRegisterForYear(WorkSchedule, YearNumber) Export
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	WorkSchedules.WorkSchedule,
	|	WorkSchedules.BeginTime,
	|	WorkSchedules.EndTime
	|FROM
	|	InformationRegister.WorkSchedules AS WorkSchedules
	|WHERE
	|	WorkSchedules.WorkSchedule = &WorkSchedule
	|	AND WorkSchedules.Year = &Year";
	
	Query.SetParameter("WorkSchedule", WorkSchedule);
	Query.SetParameter("Year", YearNumber);
	
	SelectionQueryResult = Query.Execute().Select();
	
	Return SelectionQueryResult;
	
EndFunction

// Function reads graphic data from register
//
// Parameters
//  Calendar	 	- Refs to the current catalog item
//  YearNumber 	- Year number for which it is required to read the calendar
//
// Return value 
//  ValueList		- value list in which dates entering in calendar are stored
//
Function ReadWorkScheduleDataFromRegisterForDay(WorkSchedule, Day) Export
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	WorkSchedules.WorkSchedule,
	|	WorkSchedules.BeginTime,
	|	WorkSchedules.EndTime
	|FROM
	|	InformationRegister.WorkSchedules AS WorkSchedules
	|WHERE
	|	WorkSchedules.WorkSchedule = &WorkSchedule
	|	AND WorkSchedules.Year = &Year
	|	AND WorkSchedules.BeginTime >= &BeginTime
	|	AND WorkSchedules.EndTime <= &EndTime";
	
	Query.SetParameter("WorkSchedule", WorkSchedule);
	Query.SetParameter("Year", Year(Day));
	Query.SetParameter("BeginTime", BegOfDay(Day));
	Query.SetParameter("EndTime", EndOfDay(Day));
	
	SelectionQueryResult = Query.Execute().Select();
	
	Return SelectionQueryResult;
	
EndFunction

// Procedure writes the graphic data in register
//
// Parameters
//  Calendar	  - Refs to the current catalog item
//  YearNumber	- Year number for which it is required to write calendar 
//  DateList	  - the list of values containing data on the dates that are included in the calendar
//
// Return value
//  No
//
Procedure WriteScheduleDataToRegister(WorkSchedule, DateOfFilling) Export
	
	If Not ValueIsFilled(WorkSchedule) Then
		Return;
	EndIf;
	
	RecordSet = InformationRegisters.WorkSchedules.CreateRecordSet();
	RecordSet.Filter.WorkSchedule.Set(WorkSchedule);
	RecordSet.Filter.Year.Set(Year(DateOfFilling));
	
	DateOfBeginningOfYear = Date(Year(DateOfFilling), 1, 1, 0, 0, 0);
	
	FirstDay = ?(WorkSchedule.ScheduleType = Enums.WorkScheduleTypes.ShiftWork, ?(ValueIsFilled(DateOfFilling), DAYOFYEAR(DateOfFilling), 1), 1);
	LastDay = DAYOFYEAR(EndOfYear(DateOfBeginningOfYear));
	
	PeriodsTable = WorkSchedule.Periods.Unload();
	PeriodsTable.Sort("DayNumber Decr");
	MaxNumberOfDay = 0;
	If PeriodsTable.Count() > 0 Then
		MaxNumberOfDay = PeriodsTable[0].DayNumber;
	EndIf;
	DaysCnt = 0;
	
	CurDate = DateOfBeginningOfYear + (FirstDay - 1) * 86400;
	BaseCalendar = ?(ValueIsFilled(WorkSchedule), WorkSchedule.Calendar, Undefined);
	CalendarData = SmallBusinessServer.ReadScheduleDataFromRegister(BaseCalendar, Year(DateOfFilling));
	
	For Ct = FirstDay To LastDay Do
		
		DaysCnt = DaysCnt + 1;
		If DaysCnt > MaxNumberOfDay Then
			DaysCnt = 1;
		EndIf;
		
		For Each CurRow IN WorkSchedule.Periods Do
			If WorkSchedule.ScheduleType = Enums.WorkScheduleTypes.ShiftWork Then
				If DaysCnt = CurRow.DayNumber AND (ValueIsFilled(CurRow.BeginTime) OR ValueIsFilled(CurRow.EndTime)) Then
					NewRow = RecordSet.Add();
					NewRow.WorkSchedule = WorkSchedule;
					NewRow.Year = Year(DateOfFilling);
					NewRow.BeginTime = CurDate + Hour(CurRow.BeginTime) * 3600 + Minute(CurRow.BeginTime) * 60 + Second(CurRow.BeginTime);
					NewRow.EndTime = CurDate + Hour(CurRow.EndTime) * 3600 + Minute(CurRow.EndTime) * 60 + Second(CurRow.EndTime);
				EndIf;
			Else
				If WeekDay(CurDate) = CurRow.DayNumber
				  AND (ValueIsFilled(CurRow.BeginTime)
				  OR ValueIsFilled(CurRow.EndTime)) Then
					If CalendarData.Count() = 0
					 OR CalendarData.Find(BegOfDay(CurDate)) <> Undefined
					 OR WeekDay(CurDate) = 6
					 OR WeekDay(CurDate) = 7 Then
						NewRow = RecordSet.Add();
						NewRow.WorkSchedule = WorkSchedule;
						NewRow.Year = Year(DateOfFilling);
						NewRow.BeginTime = CurDate + Hour(CurRow.BeginTime) * 3600 + Minute(CurRow.BeginTime) * 60 + Second(CurRow.BeginTime);
						NewRow.EndTime = CurDate + Hour(CurRow.EndTime) * 3600 + Minute(CurRow.EndTime) * 60 + Second(CurRow.EndTime);
					EndIf;
				EndIf;
			EndIf;
		EndDo;
		
		CurDate = DateOfBeginningOfYear + Ct * 86400;
		
	EndDo;
	
	RecordSet.Write(True);
	
EndProcedure

#EndIf