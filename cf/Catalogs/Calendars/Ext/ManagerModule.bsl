#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Function reads working schedule data from register.
//
// Parameters:
// WorkSchedule	- Ref to the current catalog item.
// YearNumber		- Year number for which it is required to read schedule.
//
// Returns - map, where Key - date.
//
Function ReadScheduleDataFromRegister(WorkSchedule, YearNumber) Export
	
	QueryText =
	"SELECT
	|	CalendarSchedules.ScheduleDate AS CalendarDate
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.Calendar = &WorkSchedule
	|	AND CalendarSchedules.Year = &CurrentYear
	|	AND CalendarSchedules.DayIncludedInSchedule
	|
	|ORDER BY
	|	CalendarDate";
	
	Query = New Query(QueryText);
	Query.SetParameter("WorkSchedule",	WorkSchedule);
	Query.SetParameter("CurrentYear",		YearNumber);
	
	DaysIncludedInSchedule = New Map;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		DaysIncludedInSchedule.Insert(Selection.CalendarDate, True);
	EndDo;
	
	Return DaysIncludedInSchedule;
	
EndFunction

// Procedure writes schedule data to register.
//
// Parameters:
// WorkSchedule	- Ref to the current catalog item.
// YearNumber		- Year number for which it is required to write schedule.
// DaysIncludedInSchedule - date and data related to it match.
//
// Returned
// value Not
//
Procedure WriteScheduleDataToRegister(WorkSchedule, DaysIncludedInSchedule, StartDate, EndDate, ReplaceManualChanges = False) Export
	
	SetDays = InformationRegisters.CalendarSchedules.CreateRecordSet();
	SetDays.Filter.Calendar.Set(WorkSchedule);
	
	// It is better to write by years.
	// Select used
	// years For each year 
	// - read set, 
	// - modify it based on the written data
	// - write.
	
	DataByYear = New Map;
	
	DateOfDay = StartDate;
	While DateOfDay <= EndDate Do
		DataByYear.Insert(Year(DateOfDay), True);
		DateOfDay = DateOfDay + 86400;
	EndDo;
	
	ManualChanges = Undefined;
	If Not ReplaceManualChanges Then
		ManualChanges = ManualChangesGraphics(WorkSchedule);
	EndIf;
	
	// Process data by years.
	For Each KeyAndValue IN DataByYear Do
		Year = KeyAndValue.Key;
		
		// Read sets for year
		SetDays.Filter.Year.Set(Year);
		SetDays.Read();
		
		// Fill in set content to the match by dates for a quick access.
		RowsCollectionDays = New Map;
		For Each SetRow IN SetDays Do
			RowsCollectionDays.Insert(SetRow.ScheduleDate, SetRow);
		EndDo;
		
		BegOfYear = Date(Year, 1, 1);
		EndOfYear = Date(Year, 12, 31);
		
		BeginCrawling = ?(StartDate > BegOfYear, StartDate, BegOfYear);
		EndBypass = ?(EndDate < EndOfYear, EndDate, EndOfYear);
		
		// Set data should be replaced for the bypass period.
		DateOfDay = BeginCrawling;
		While DateOfDay <= EndBypass Do
			
			If ManualChanges <> Undefined AND ManualChanges[DateOfDay] <> Undefined Then
				// Leave manual corrections in set without changes.
				DateOfDay = DateOfDay + 86400;
				Continue;
			EndIf;
			
			// If there is no string on date in the set, - create it.
			RowSetDays = RowsCollectionDays[DateOfDay];
			If RowSetDays = Undefined Then
				RowSetDays = SetDays.Add();
				RowSetDays.Calendar = WorkSchedule;
				RowSetDays.Year = Year;
				RowSetDays.ScheduleDate = DateOfDay;
				RowsCollectionDays.Insert(DateOfDay, RowSetDays);
			EndIf;
			
			// If a day is included to the schedule, fill in its intervals.
			DataDay = DaysIncludedInSchedule.Get(DateOfDay);
			If DataDay = Undefined Then
				// Delete string from set if a day - is a nonworking one.
				SetDays.Delete(RowSetDays);
				RowsCollectionDays.Delete(DateOfDay);
			Else
				RowSetDays.DayIncludedInSchedule = True;
			EndIf;
			DateOfDay = DateOfDay + 86400;
		EndDo;
		
		// Fill in secondary data to optimize calculations by calendars.
		CrawlDate = BegOfYear;
		NumberOfDaysInScheduleSinceTheBeginningOfTheYear = 0;
		While CrawlDate <= EndOfYear Do
			RowSetDays = RowsCollectionDays[CrawlDate];
			If RowSetDays <> Undefined Then
				// DayIncludedInSchedule
				NumberOfDaysInScheduleSinceTheBeginningOfTheYear = NumberOfDaysInScheduleSinceTheBeginningOfTheYear + 1;
			Else
				// Day is not included in the schedule
				RowSetDays = SetDays.Add();
				RowSetDays.Calendar = WorkSchedule;
				RowSetDays.Year = Year;
				RowSetDays.ScheduleDate = CrawlDate;
			EndIf;
			RowSetDays.NumberOfDaysInScheduleSinceTheBeginningOfTheYear = NumberOfDaysInScheduleSinceTheBeginningOfTheYear;
			CrawlDate = CrawlDate + 86400;
		EndDo;
		
		SetDays.Write();
		
	EndDo;
	
EndProcedure

// Updates work schedules by production calendar data based on which they are filled in.
//
// Parameters:
// - UpdateConditions - Value table with columns.
// 	- BusinessCalendarCode - production calendar code which data has been changed,
// 	- Year - year for which it is required to update data.
//
Procedure UpdateWorkSchedulesByFactoryCalendarData(UpdateConditions) Export
	
	// Detect schedules that should
	// be updated sequentially
	// receive data of these schedules update for each year.
	
	QueryText = 
	"SELECT
	|	UpdateConditions.BusinessCalendarCode,
	|	UpdateConditions.Year,
	|	DATEADD(DATETIME(1, 1, 1), YEAR, UpdateConditions.Year - 1) AS BegOfYear,
	|	DATEADD(DATETIME(1, 12, 31), YEAR, UpdateConditions.Year - 1) AS EndOfYear
	|INTO UpdateConditions
	|FROM
	|	&UpdateConditions AS UpdateConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendars.Ref AS WorkSchedule,
	|	UpdateConditions.Year,
	|	Calendars.FillMethod,
	|	Calendars.BusinessCalendar,
	|	CASE
	|		WHEN Calendars.StartDate < UpdateConditions.BegOfYear
	|			THEN UpdateConditions.BegOfYear
	|		ELSE Calendars.StartDate
	|	END AS StartDate,
	|	CASE
	|		WHEN Calendars.EndDate > UpdateConditions.EndOfYear
	|				OR Calendars.EndDate = DATETIME(1, 1, 1)
	|			THEN UpdateConditions.EndOfYear
	|		ELSE Calendars.EndDate
	|	END AS EndDate,
	|	Calendars.BeginnigDate,
	|	Calendars.ConsiderHolidays
	|INTO UpdatedSchedules
	|FROM
	|	Catalog.Calendars AS Calendars
	|		INNER JOIN Catalog.BusinessCalendars AS BusinessCalendars
	|		ON (BusinessCalendars.Ref = Calendars.BusinessCalendar)
	|			AND (Calendars.FillMethod = VALUE(Enum.WorkScheduleFillingMethods.ByWeeks)
	|				OR Calendars.FillMethod = VALUE(Enum.WorkScheduleFillingMethods.ByCyclesOfAnyLength)
	|					AND Calendars.ConsiderHolidays)
	|		INNER JOIN UpdateConditions AS UpdateConditions
	|		ON (UpdateConditions.BusinessCalendarCode = BusinessCalendars.Code)
	|			AND Calendars.StartDate <= UpdateConditions.EndOfYear
	|			AND (Calendars.EndDate >= UpdateConditions.BegOfYear
	|				OR Calendars.EndDate = DATETIME(1, 1, 1))
	|		LEFT JOIN InformationRegister.WorkSchedulesManualChanges AS ManualChangesForAllYears
	|		ON (ManualChangesForAllYears.WorkSchedule = Calendars.Ref)
	|			AND (ManualChangesForAllYears.Year = 0)
	|WHERE
	|	ManualChangesForAllYears.WorkSchedule IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UpdatedSchedules.WorkSchedule,
	|	UpdatedSchedules.Year,
	|	UpdatedSchedules.FillMethod,
	|	UpdatedSchedules.BusinessCalendar,
	|	UpdatedSchedules.StartDate,
	|	UpdatedSchedules.EndDate,
	|	UpdatedSchedules.BeginnigDate,
	|	UpdatedSchedules.ConsiderHolidays
	|FROM
	|	UpdatedSchedules AS UpdatedSchedules
	|
	|ORDER BY
	|	UpdatedSchedules.WorkSchedule,
	|	UpdatedSchedules.Year
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FillTemplate.Ref AS WorkSchedule,
	|	FillTemplate.LineNumber AS LineNumber,
	|	FillTemplate.DayIncludedInSchedule
	|FROM
	|	Catalog.Calendars.FillTemplate AS FillTemplate
	|WHERE
	|	FillTemplate.Ref In
	|			(SELECT
	|				UpdatedSchedules.WorkSchedule
	|			FROM
	|				UpdatedSchedules)
	|
	|ORDER BY
	|	WorkSchedule,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkSchedule.Ref AS WorkSchedule,
	|	WorkSchedule.DayNumber AS DayNumber,
	|	WorkSchedule.BeginTime,
	|	WorkSchedule.EndTime
	|FROM
	|	Catalog.Calendars.WorkSchedule AS WorkSchedule
	|WHERE
	|	WorkSchedule.Ref In
	|			(SELECT
	|				UpdatedSchedules.WorkSchedule
	|			FROM
	|				UpdatedSchedules)
	|
	|ORDER BY
	|	WorkSchedule,
	|	WorkSchedule.DayNumber";
	
	Query = New Query(QueryText);
	Query.SetParameter("UpdateConditions", UpdateConditions);
	
	ResultsOfQuery = Query.ExecuteBatch();
	PicksFromGraphs = ResultsOfQuery[ResultsOfQuery.UBound() - 2].Select();
	SelectionByTemplate = ResultsOfQuery[ResultsOfQuery.UBound() - 1].Select();
	SelectionBySchedule = ResultsOfQuery[ResultsOfQuery.UBound()].Select();
	
	FillTemplate = New ValueTable;
	FillTemplate.Columns.Add("DayIncludedInSchedule", New TypeDescription("Boolean"));
	
	WorkSchedule = New ValueTable;
	WorkSchedule.Columns.Add("DayNumber", 		New TypeDescription("Number", New NumberQualifiers(7)));
	WorkSchedule.Columns.Add("BeginTime", 	New TypeDescription("Date", , , New DateQualifiers(DateFractions.Time)));
	WorkSchedule.Columns.Add("EndTime",	New TypeDescription("Date", , , New DateQualifiers(DateFractions.Time)));
	
	While PicksFromGraphs.NextByFieldValue("WorkSchedule") Do
		FillTemplate.Clear();
		While SelectionByTemplate.FindNext(PicksFromGraphs.WorkSchedule, "WorkSchedule") Do
			NewRow = FillTemplate.Add();
			NewRow.DayIncludedInSchedule = SelectionByTemplate.DayIncludedInSchedule;
		EndDo;
		WorkSchedule.Clear();
		While SelectionBySchedule.FindNext(PicksFromGraphs.WorkSchedule, "WorkSchedule") Do
			NewInterval = WorkSchedule.Add();
			NewInterval.DayNumber			= SelectionBySchedule.DayNumber;
			NewInterval.BeginTime		= SelectionBySchedule.BeginTime;
			NewInterval.EndTime	= SelectionBySchedule.EndTime;
		EndDo;
		While PicksFromGraphs.NextByFieldValue("StartDate") Do
			// If the end date is not specified it will be selected according to production calendar.
			EndDateFill = PicksFromGraphs.EndDate;
			DaysIncludedInSchedule = Catalogs.Calendars.DaysIncludedInSchedule(
										PicksFromGraphs.StartDate, 
										PicksFromGraphs.FillMethod, 
										FillTemplate, 
										EndDateFill,
										PicksFromGraphs.BusinessCalendar, 
										PicksFromGraphs.ConsiderHolidays, 
										PicksFromGraphs.BeginnigDate);
			Catalogs.Calendars.WriteScheduleDataToRegister(PicksFromGraphs.WorkSchedule, DaysIncludedInSchedule, PicksFromGraphs.StartDate, EndDateFill);
		EndDo;
	EndDo;
	
EndProcedure

// Makes dates collection which are the working ones considering
// the business calendar, filling method and other settings.
//
// Parameters:
// - Year - number of year
// - BusinessCalendar - business calendar by which days are determined.
// - FillMethod - filling method.
// - FillTemplate - template of filling by days.
// - ConsiderHolidays - Boolean if it is True, then days that are holidays will be excluded.
// - StartDate - optional, it is specified only for filling by custom length cycles.
//
// Returns - map, where Key - date, structure array value with a description of
// the time intervals for the specified date.
//
Function DaysIncludedInSchedule(StartDate, FillMethod, FillTemplate, EndDate, BusinessCalendar, ConsiderHolidays, Val BeginnigDate = Undefined) Export
	
	DaysIncludedInSchedule = New Map;

	If FillTemplate.Count() = 0 Then
		Return DaysIncludedInSchedule;
	EndIf;
	
	If Not ValueIsFilled(EndDate) Then
		// If an end date is not specified, fill it in up to the end.
		EndDate = EndOfYear(StartDate);
		If ValueIsFilled(BusinessCalendar) Then
			// If the business calendar is specified, then fill it in up to the "end" of its fullness.
			EndDateFill = Catalogs.BusinessCalendars.BusinessCalendars(BusinessCalendar);
			If EndDateFill <> Undefined 
				AND EndDateFill > EndDate Then
				EndDate = EndDateFill;
			EndIf;
		EndIf;
	EndIf;
	
	// Data is filled in only by years.
	CurrentYear = Year(StartDate);
	While CurrentYear <= Year(EndDate) Do
		BeginDateOfYear = StartDate;
		EndDateOfYear = EndDate;
		AdjustDatesStartEnd(CurrentYear, BeginDateOfYear, EndDateOfYear);	
		// Receive schedule data for a year.
		If FillMethod = Enums.WorkScheduleFillingMethods.ByWeeks Then
			DaysPerYear = DaysIncludedInScheduleForWeek(CurrentYear, BusinessCalendar, FillTemplate, ConsiderHolidays, BeginDateOfYear, EndDateOfYear);
		Else
			DaysPerYear = DaysAreIncludedInScheduleOfArbitraryLength(CurrentYear, BusinessCalendar, FillTemplate, ConsiderHolidays, BeginnigDate, BeginDateOfYear, EndDateOfYear);
		EndIf;
		// Expand general collection
		For Each KeyAndValue IN DaysPerYear Do
			DaysIncludedInSchedule.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
		CurrentYear = CurrentYear + 1;
	EndDo;
	
	Return DaysIncludedInSchedule;
	
EndFunction

Function DaysIncludedInScheduleForWeek(Year, BusinessCalendar, FillTemplate, ConsiderHolidays, Val StartDate = Undefined, Val EndDate = Undefined)
	
	// Fill in the working schedule by weeks.
	
	DaysIncludedInSchedule = New Map;
	
	FillBusinessCalendar = ValueIsFilled(BusinessCalendar);
	
	DaysPerYear = DAYOFYEAR(Date(Year, 12, 31));
	BusinessCalendarData = Catalogs.BusinessCalendars.BusinessCalendarData(BusinessCalendar, Year);
	If FillBusinessCalendar 
		AND BusinessCalendarData.Count() <> DaysPerYear Then
		// If the business calendar is specified but it is filled in incorrectly, filling by weeks is not supported.
		Return DaysIncludedInSchedule;
	EndIf;
	
	BusinessCalendarData.Indexes.Add("Date");
	
	LengthOfDay = 24 * 3600;
	
	DateOfDay = StartDate;
	While DateOfDay <= EndDate Do
		
		HoliDay = False;
		If Not FillBusinessCalendar Then
			DayNumber = WeekDay(DateOfDay);
		Else
			DataDay = BusinessCalendarData.FindRows(New Structure("Date", DateOfDay))[0];
			If DataDay.DayKind = Enums.BusinessCalendarDayKinds.Saturday Then
				DayNumber = 6;
			ElsIf DataDay.DayKind = Enums.BusinessCalendarDayKinds.Sunday Then
				DayNumber = 7;
			Else
				DayNumber = WeekDay(?(ValueIsFilled(DataDay.DestinationDate), DataDay.DestinationDate, DataDay.Date));
			EndIf;
			HoliDay = ConsiderHolidays AND DataDay.DayKind = Enums.BusinessCalendarDayKinds.Holiday;
		EndIf;
		
		RowDay = FillTemplate[DayNumber - 1];
		If RowDay.DayIncludedInSchedule AND Not HoliDay Then
			DaysIncludedInSchedule.Insert(DateOfDay, True);
		EndIf;
		
		DateOfDay = DateOfDay + LengthOfDay;
	EndDo;
	
	Return DaysIncludedInSchedule;
	
EndFunction

Function DaysAreIncludedInScheduleOfArbitraryLength(Year, BusinessCalendar, FillTemplate, ConsiderHolidays, BeginnigDate, Val StartDate = Undefined, Val EndDate = Undefined)
	
	DaysIncludedInSchedule = New Map;
	
	LengthOfDay = 24 * 3600;
	
	DateOfDay = BeginnigDate;
	While DateOfDay <= EndDate Do
		For Each RowDay IN FillTemplate Do
			If RowDay.DayIncludedInSchedule 
				AND DateOfDay >= StartDate Then
				DaysIncludedInSchedule.Insert(DateOfDay, True);
			EndIf;
			DateOfDay = DateOfDay + LengthOfDay;
		EndDo;
	EndDo;
	
	If Not ConsiderHolidays Then
		Return DaysIncludedInSchedule;
	EndIf;
	
	// Exclude holiday dates.
	
	BusinessCalendarData = Catalogs.BusinessCalendars.BusinessCalendarData(BusinessCalendar, Year);
	If BusinessCalendarData.Count() = 0 Then
		Return DaysIncludedInSchedule;
	EndIf;
	
	DataOnPublicHolidays = BusinessCalendarData.FindRows(New Structure("DayKind", Enums.BusinessCalendarDayKinds.Holiday));
	
	For Each DataDay IN DataOnPublicHolidays Do
		DaysIncludedInSchedule.Delete(DataDay.Date);
	EndDo;
	
	Return DaysIncludedInSchedule;
	
EndFunction

Procedure AdjustDatesStartEnd(Year, StartDate, EndDate)
	
	BegOfYear = Date(Year, 1, 1);
	EndOfYear = Date(Year, 12, 31);
	
	If StartDate <> Undefined Then
		StartDate = Max(StartDate, BegOfYear);
	Else
		StartDate = BegOfYear;
	EndIf;
	
	If EndDate <> Undefined Then
		EndDate = min(EndDate, EndOfYear);
	Else
		EndDate = EndOfYear;
	EndIf;
	
EndProcedure

// Determines manual changes dates of the specified schedule.
//
Function ManualChangesGraphics(WorkSchedule)
	
	Query = New Query(
	"SELECT
	|	ManualChanges.WorkSchedule,
	|	ManualChanges.Year,
	|	ManualChanges.ScheduleDate,
	|	ISNULL(CalendarSchedules.DayIncludedInSchedule, FALSE) AS DayIncludedInSchedule
	|FROM
	|	InformationRegister.WorkSchedulesManualChanges AS ManualChanges
	|		LEFT JOIN InformationRegister.CalendarSchedules AS CalendarSchedules
	|		ON (CalendarSchedules.Calendar = ManualChanges.WorkSchedule)
	|			AND (CalendarSchedules.Year = ManualChanges.Year)
	|			AND (CalendarSchedules.ScheduleDate = ManualChanges.ScheduleDate)
	|WHERE
	|	ManualChanges.WorkSchedule = &WorkSchedule
	|	AND ManualChanges.ScheduleDate <> DATETIME(1, 1, 1)");

	Query.SetParameter("WorkSchedule", WorkSchedule);
	
	Selection = Query.Execute().Select();
	
	ManualChanges = New Map;
	While Selection.Next() Do
		ManualChanges.Insert(Selection.ScheduleDate, Selection.DayIncludedInSchedule);
	EndDo;
	
	Return ManualChanges;
	
EndFunction

#EndRegion

#EndIf