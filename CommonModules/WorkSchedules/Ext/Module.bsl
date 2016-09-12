////////////////////////////////////////////////////////////////////////////////
// Subsystem "Work schedules".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Function returns the dates array that differs from specified date
// on the number of days, included in the specified schedule.
//
// Parameters:
// WorkSchedule	- schedule that should be used, type CatalogRef.Calendars.
// DateFrom			- the date from which you need to calculate the number of days, Date type.
// DaysArray		- array with the number of days for which you need to increase the beginning date, type Array, Number.
// CalculateNextDateFromPrevious	- do you need to calculate the following
// 										  date from the previous or all the dates are calculated from the passed date.
// CallingException - Boolean if True, the exception is thrown if a schedule is not filled in.
//
// Return value 
// Array		- an array of dates, increased by the number
// of days, included in the schedule, If the selected schedule is not filled and RaiseException = False, then it returns Undefined.
//
Function DatesOnSchedule(Val WorkSchedule, Val DateFrom, Val DaysArray, Val CalculateNextDateFromPrevious = False, CallingException = True) Export
	
	TempTablesManager = New TempTablesManager;
	
	CalendarSchedules.CreateTTIncrementInDays(TempTablesManager, DaysArray, CalculateNextDateFromPrevious);
	
	// The algorithm works in the following way:
	// Receive the number of days, included in the schedule, on start date.
	// For all subsequent years, get the "offset" number of days as an amount of days of the previous years.
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
	|	CalendarSchedules.Year,
	|	MAX(CalendarSchedules.NumberOfDaysInScheduleSinceTheBeginningOfTheYear) AS DaysInSchedule
	|INTO TTCountDaysInScheduleByYear
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.ScheduleDate >= &DateFrom
	|	AND CalendarSchedules.Calendar = &WorkSchedule
	|	AND CalendarSchedules.DayIncludedInSchedule
	|
	|GROUP BY
	|	CalendarSchedules.Year
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DaysCountInScheduleByYears.Year,
	|	SUM(ISNULL(PastYearsDaysCount.DaysInSchedule, 0)) AS DaysInSchedule
	|INTO TTCountDaysInViewOfPreviousYears
	|FROM
	|	TTCountDaysInScheduleByYear AS DaysCountInScheduleByYears
	|		LEFT JOIN TTCountDaysInScheduleByYear AS PastYearsDaysCount
	|		ON (PastYearsDaysCount.Year < DaysCountInScheduleByYears.Year)
	|
	|GROUP BY
	|	DaysCountInScheduleByYears.Year
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(CalendarSchedules.NumberOfDaysInScheduleSinceTheBeginningOfTheYear) AS NumberOfDaysInScheduleSinceTheBeginningOfTheYear
	|INTO TTCountDaysStartingOnDateOfSchedule
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.ScheduleDate >= &DateFrom
	|	AND CalendarSchedules.Year = YEAR(&DateFrom)
	|	AND CalendarSchedules.Calendar = &WorkSchedule
	|	AND CalendarSchedules.DayIncludedInSchedule
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IncrementDays.RowIndex,
	|	ISNULL(CalendarSchedules.ScheduleDate, UNDEFINED) AS DateInCalendar
	|FROM
	|	TTIncrementInDays AS IncrementDays
	|		INNER JOIN TTCountDaysStartingOnDateOfSchedule AS DaysCountInScheduleOnReferenceDate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CalendarSchedules AS CalendarSchedules
	|			INNER JOIN TTCountDaysInViewOfPreviousYears AS DaysCountWithPastYears
	|			ON (DaysCountWithPastYears.Year = CalendarSchedules.Year)
	|		ON (CalendarSchedules.NumberOfDaysInScheduleSinceTheBeginningOfTheYear = DaysCountInScheduleOnReferenceDate.NumberOfDaysInScheduleSinceTheBeginningOfTheYear - DaysCountWithPastYears.DaysInSchedule + IncrementDays.DaysNumber)
	|			AND (CalendarSchedules.ScheduleDate >= &DateFrom)
	|			AND (CalendarSchedules.Calendar = &WorkSchedule)
	|			AND (CalendarSchedules.DayIncludedInSchedule)
	|
	|ORDER BY
	|	IncrementDays.RowIndex";
	
	Query.SetParameter("DateFrom", BegOfDay(DateFrom));
	Query.SetParameter("WorkSchedule", WorkSchedule);
	
	Selection = Query.Execute().Select();
	
	DatesArray = New Array;
	
	While Selection.Next() Do
		If Selection.DateInCalendar = Undefined Then
			ErrorInfo = NStr("en='Work schedule %1 is not filled from the date %2 for the specified number of days.';ru='График работы «%1» не заполнен с даты %2 на указанное количество рабочих дней.'");
			If CallingException Then
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					ErrorInfo,
					WorkSchedule, Format(DateFrom, "DLF=D"));
			Else
				Return Undefined;
			EndIf;
		EndIf;
		
		DatesArray.Add(Selection.DateInCalendar);
	EndDo;
	
	Return DatesArray;
	
EndFunction

// Function returns the date that differs from specified date
// by the number of days, included in the specified schedule.
//
// Parameters:
// WorkSchedule	- schedule that should be used, type CatalogRef.Calendars.
// DateFrom			- the date from which you need to calculate the number of days, Date type.
// DaysNumber	- the number of days for which you need to increase the beginning date, type Number.
// CallingException - Boolean if True, the exception is thrown if a schedule is not filled in.
//
// Return value 
// Date			- date, increased by the number of days included in the schedule.
// If the selected schedule is not filled and RaiseException = False, then it returns Undefined.
//
Function DateOnSchedule(Val WorkSchedule, Val DateFrom, Val DaysNumber, CallingException = True) Export
	
	DateFrom = BegOfDay(DateFrom);
	
	If DaysNumber = 0 Then
		Return DateFrom;
	EndIf;
	
	DaysArray = New Array;
	DaysArray.Add(DaysNumber);
	
	DatesArray = DatesOnSchedule(WorkSchedule, DateFrom, DaysArray, , CallingException);
	
	Return ?(DatesArray <> Undefined, DatesArray[0], Undefined);
	
EndFunction

// Makes work schedules for dates included in the specified schedules for the specified period.
// If the preholiday day schedule is not set, then it will be defined as if this day is a work day.
//
// Parameters:
// Schedules - items array of the CatalogRef.Calendars type.
// StartDate - Beginning date of the period for which you need to make schedules.
// EndDate - Ending date of a period.
//
// Returns - Value table with columns.
// WorkSchedule
// ScheduleDate
// BeginTime
// EndTime
//
Function SchedulesOfWorkOnPeriod(Graphics, StartDate, EndDate) Export
	
	TempTablesManager = New TempTablesManager;
	
	// Create temporary schedules table.
	CreateTSchedulesOfWorkOnPeriod(TempTablesManager, Graphics, StartDate, EndDate);
	
	QueryText = 
	"SELECT
	|	SchedulesOfWork.WorkSchedule,
	|	SchedulesOfWork.ScheduleDate,
	|	SchedulesOfWork.BeginTime,
	|	SchedulesOfWork.EndTime
	|FROM
	|	TTWorkSchedule AS SchedulesOfWork";
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

// Creates the TTWorkSchedule temporary table with columns in the manager.
// For more information, see comment to function WorkSchedulesOnPeriod.
//
Procedure CreateTSchedulesOfWorkOnPeriod(TempTablesManager, Graphics, StartDate, EndDate) Export
	
	QueryText = 
	"SELECT
	|	FillTemplate.Ref AS WorkSchedule,
	|	MAX(FillTemplate.LineNumber) AS CycleLength
	|INTO VTCycleLengthGraphs
	|FROM
	|	Catalog.Calendars.FillTemplate AS FillTemplate
	|WHERE
	|	FillTemplate.Ref IN(&Calendars)
	|
	|GROUP BY
	|	FillTemplate.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendars.Ref AS WorkSchedule,
	|	BusinessCalendarData.Date AS ScheduleDate,
	|	BusinessCalendarData.DestinationDate,
	|	CASE
	|		WHEN BusinessCalendarData.DayKind = VALUE(Enum.BusinessCalendarDayKinds.Preholiday)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS HolidayDay
	|INTO VTInformationOnCalendar
	|FROM
	|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON BusinessCalendarData.BusinessCalendar = Calendars.BusinessCalendar
	|			AND (Calendars.Ref IN (&Calendars))
	|			AND (BusinessCalendarData.Date between &StartDate AND &EndDate)
	|			AND (BusinessCalendarData.DayKind = VALUE(Enum.BusinessCalendarDayKinds.Preholiday)
	|				OR BusinessCalendarData.DestinationDate <> DateTime(1, 1, 1))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CalendarSchedules.Calendar AS WorkSchedule,
	|	CalendarSchedules.ScheduleDate AS ScheduleDate,
	|	DATEDIFF(Calendars.BeginnigDate, CalendarSchedules.ScheduleDate, Day) + 1 AS DaysFromCountdownDate,
	|	InformationOnCalendar.HolidayDay,
	|	InformationOnCalendar.DestinationDate
	|INTO TTDaysIncludedInLine
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON CalendarSchedules.Calendar = Calendars.Ref
	|			AND (CalendarSchedules.Calendar IN (&Calendars))
	|			AND (CalendarSchedules.ScheduleDate between &StartDate AND &EndDate)
	|			AND (CalendarSchedules.DayIncludedInSchedule)
	|		LEFT JOIN VTInformationOnCalendar AS InformationOnCalendar
	|		ON (InformationOnCalendar.WorkSchedule = CalendarSchedules.Calendar)
	|			AND (InformationOnCalendar.ScheduleDate = CalendarSchedules.ScheduleDate)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DaysIncludedInSchedule.WorkSchedule,
	|	DaysIncludedInSchedule.ScheduleDate,
	|	CASE
	|		WHEN DaysIncludedInSchedule.ModulusOfResult = 0
	|			THEN DaysIncludedInSchedule.CycleLength
	|		ELSE DaysIncludedInSchedule.ModulusOfResult
	|	END AS DayNumber,
	|	DaysIncludedInSchedule.HolidayDay
	|INTO TTDatesNumbersOfDays
	|FROM
	|	(SELECT
	|		DaysIncludedInSchedule.WorkSchedule AS WorkSchedule,
	|		DaysIncludedInSchedule.ScheduleDate AS ScheduleDate,
	|		DaysIncludedInSchedule.HolidayDay AS HolidayDay,
	|		DaysIncludedInSchedule.CycleLength AS CycleLength,
	|		DaysIncludedInSchedule.DaysFromCountdownDate - DaysIncludedInSchedule.IntegerPartResultOfDivision * DaysIncludedInSchedule.CycleLength AS ModulusOfResult
	|	IN
	|		(SELECT
	|			DaysIncludedInSchedule.WorkSchedule AS WorkSchedule,
	|			DaysIncludedInSchedule.ScheduleDate AS ScheduleDate,
	|			DaysIncludedInSchedule.HolidayDay AS HolidayDay,
	|			DaysIncludedInSchedule.DaysFromCountdownDate AS DaysFromCountdownDate,
	|			LengthCycle.CycleLength AS CycleLength,
	|			(CAST(DaysIncludedInSchedule.DaysFromCountdownDate / LengthCycle.CycleLength AS NUMBER(15, 0))) - CASE
	|				WHEN (CAST(DaysIncludedInSchedule.DaysFromCountdownDate / LengthCycle.CycleLength AS NUMBER(15, 0))) > DaysIncludedInSchedule.DaysFromCountdownDate / LengthCycle.CycleLength
	|					THEN 1
	|				ELSE 0
	|			END AS IntegerPartResultOfDivision
	|		IN
	|			TTDaysIncludedInLine AS DaysIncludedInSchedule
	|				INNER JOIN Catalog.Calendars AS Calendars
	|				ON DaysIncludedInSchedule.WorkSchedule = Calendars.Ref
	|					AND (Calendars.FillMethod = VALUE(Enum.WorkScheduleFillingMethods.ByCyclesOfAnyLength))
	|				INNER JOIN VTCycleLengthGraphs AS LengthCycle
	|				ON DaysIncludedInSchedule.WorkSchedule = LengthCycle.WorkSchedule) AS DaysIncludedInSchedule) AS DaysIncludedInSchedule
	|
	|UNION ALL
	|
	|SELECT
	|	DaysIncludedInSchedule.WorkSchedule,
	|	DaysIncludedInSchedule.ScheduleDate,
	|	CASE
	|		WHEN DaysIncludedInSchedule.DestinationDate IS NULL 
	|			THEN WeekDay(DaysIncludedInSchedule.ScheduleDate)
	|		ELSE WeekDay(DaysIncludedInSchedule.DestinationDate)
	|	END,
	|	DaysIncludedInSchedule.HolidayDay
	|FROM
	|	TTDaysIncludedInLine AS DaysIncludedInSchedule
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON DaysIncludedInSchedule.WorkSchedule = Calendars.Ref
	|WHERE
	|	Calendars.FillMethod = VALUE(Enum.WorkScheduleFillingMethods.ByWeeks)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	DaysIncludedInSchedule.WorkSchedule,
	|	DaysIncludedInSchedule.ScheduleDate,
	|	DaysIncludedInSchedule.DayNumber,
	|	ISNULL(SchedulesOfWorkOfThePre-holidayDay.BeginTime, SchedulesOfWork.BeginTime) AS BeginTime,
	|	ISNULL(SchedulesOfWorkOfThePre-holidayDay.EndTime, SchedulesOfWork.EndTime) AS EndTime
	|INTO TTWorkSchedule
	|FROM
	|	TTDatesNumbersOfDays AS DaysIncludedInSchedule
	|		LEFT JOIN Catalog.Calendars.WorkSchedule AS SchedulesOfWork
	|		ON (SchedulesOfWork.Ref = DaysIncludedInSchedule.WorkSchedule)
	|			AND (SchedulesOfWork.DayNumber = DaysIncludedInSchedule.DayNumber)
	|		LEFT JOIN Catalog.Calendars.WorkSchedule AS SchedulesOfWorkOfThePre-holidayDay
	|		ON (SchedulesOfWorkOfThePre-holidayDay.Ref = DaysIncludedInSchedule.WorkSchedule)
	|			AND (SchedulesOfWorkOfThePre-holidayDay.DayNumber = 0)
	|			AND (DaysIncludedInSchedule.HolidayDay)
	|
	|INDEX BY
	|	DaysIncludedInSchedule.WorkSchedule,
	|	DaysIncludedInSchedule.ScheduleDate";
	
	// Use the following formula for calculation of number in the cycle of any length for the day, included in the schedule:
	// Number of the day = Days from date of start% Cycle length, where % - the division operation on the module.
	
	// The division operation on the module in its turn is produced by the formula:
	// Dividend - Int(Dividend / Divisor) * Divisor, where Int() - function selecting the integer part.
	
	// For the selection of the whole part the construction is used:
	// if the result of rounding the number by the rules "1.5 as 2" higher than the original value, decrease the result by 1.
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("Calendars", Graphics);
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", EndDate);
	Query.Execute();
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// Updates work schedules by production calendar data based on which they are filled in.
//
// Parameters:
// - UpdateConditions - Value table with columns.
// 	- BusinessCalendarCode - production calendar code which data has been changed,
// 	- Year - year for which it is required to update data.
//
Procedure UpdateWorkSchedulesByFactoryCalendarData(UpdateConditions) Export
	
	Catalogs.Calendars.UpdateWorkSchedulesByFactoryCalendarData(UpdateConditions);
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"
	].Add("WorkSchedules");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnGettingObligatoryExchangePlanObjects"
	].Add("WorkSchedules");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Used to receive metadata objects mandatory for an exchange plan.
// If the subsystem has metadata objects that have to be included
// in the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects that should be included into the exchange plan.
// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
// True - need to receive a list of RIB exchange plan;
// False - it is required to receive a list for an exchange plan NOT RIB.
//
Procedure OnGettingObligatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Catalogs.Calendars);
		Objects.Add(Metadata.InformationRegisters.CalendarSchedules);
		
	EndIf;
	
EndProcedure

// Create a temporary table VTCalendarSchedules containing the data of schedule WorkSchedule for the years that are specified in the TTVariousYearsGraphics.
//
// Parameters:
// - TempTablesManager - must contain TTVariousYearsGraphics with the field Year, type Number (4,0),
// - WorkSchedule - schedule that should be used, type CatalogRef.Calendars.
//
Procedure CreateVTScheduleData(TempTablesManager, WorkSchedule) Export
	
	QueryText = 
	"SELECT
	|	CalendarSchedules.Year,
	|	CalendarSchedules.ScheduleDate,
	|	CalendarSchedules.DayIncludedInSchedule
	|INTO VTCalendarSchedules
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|		INNER JOIN TTVariousYearsGraphics AS YearGraphics
	|		ON (YearGraphics.Year = CalendarSchedules.Year)
	|WHERE
	|	CalendarSchedules.Calendar = &WorkSchedule";
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("WorkSchedule", WorkSchedule);
	Query.Execute();
	
EndProcedure

// Form a text query template, embedded in the method CalendarSchedules.GetWorkingDaysDates.
//
Function QueryTextTemplateDefinitionNextDatesOnWorkSchedule() Export
	
	Return
	"SELECT
	|	BeginningDates.Date,
	|	%Function%(CalendarDates.ScheduleDate) AS ClosestDate
	|FROM
	|	BeginningDates AS BeginningDates
	|		LEFT JOIN InformationRegister.CalendarSchedules AS CalendarDates
	|		ON (CalendarDates.ScheduleDate %ConditionSign% BeginningDates.Date)
	|			AND (CalendarDates.Calendar = &Schedule)
	|			AND (CalendarDates.DayIncludedInSchedule)
	|
	|GROUP BY
	|	BeginningDates.Date";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "WorkSchedules.CreateRussianFederationFiveDaysCalendar";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.1";
	Handler.Procedure = "WorkSchedules.FillWorkSchedulesFillingSettings";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.14";
	Handler.Procedure = "WorkSchedules.FillDaysCountInScheduleYearToDate";
	
EndProcedure

// Procedure creates a work schedule based on the production calendar.
// Russian Federation on the template "fiveday week".
//
Procedure CreateRussianFederationFiveDaysCalendar() Export
	
	BusinessCalendar = CalendarSchedules.BusinessCalendarOfRussiaFederation();
	If BusinessCalendar = Undefined Then 
		Return;
	EndIf;
	
	If Not Catalogs.Calendars.FindByAttribute("BusinessCalendar", BusinessCalendar).IsEmpty() Then
		Return;
	EndIf;
	
	NewWorkSchedule = Catalogs.Calendars.CreateItem();
	NewWorkSchedule.Description = CommonUse.ObjectAttributeValue(BusinessCalendar, "Description");
	NewWorkSchedule.BusinessCalendar = BusinessCalendar;
	NewWorkSchedule.FillMethod = Enums.WorkScheduleFillingMethods.ByWeeks;
	NewWorkSchedule.StartDate = BegOfYear(CurrentSessionDate());
	NewWorkSchedule.ConsiderHolidays = True;
	
	// Fill the week cycle as a fiveday week.
	For DayNumber = 1 To 7 Do
		NewWorkSchedule.FillTemplate.Add().DayIncludedInSchedule = DayNumber <= 5;
	EndDo;
	
	InfobaseUpdate.WriteData(NewWorkSchedule, True, True);
	
EndProcedure

// Fill the production calendar for those work schedules that were created not by a template or before the appearance of the production calendars.
// 
Procedure FillWorkSchedulesFillingSettings() Export
	
	BusinessCalendarRF = CalendarSchedules.BusinessCalendarOfRussiaFederation();
	
	If BusinessCalendarRF = Undefined Then
		// If for some reason there is no default production calendar, it makes no sense to fill the settings.
		Return;
	EndIf;
	
	QueryText = 
	"SELECT
	|	Calendars.Ref,
	|	Calendars.DeleteTypeCalendar AS CalendarType,
	|	Calendars.BusinessCalendar
	|FROM
	|	Catalog.Calendars AS Calendars
	|WHERE
	|	Calendars.FillMethod = VALUE(Enum.WorkScheduleFillingMethods.EmptyRef)";
	
	Query = New Query(QueryText);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		WorkScheduleObject = Selection.Ref.GetObject();
		If Not ValueIsFilled(Selection.BusinessCalendar) Then
			// Set the calendar of the Russian Federation
			WorkScheduleObject.BusinessCalendar = BusinessCalendarRF;
		EndIf;
		WorkScheduleObject.StartDate = Date(2012, 1, 1);
		If Not ValueIsFilled(Selection.CalendarType) Then
			// If the calendar kind was not specified, there is no possibility to write accurate filling setting.
			WorkScheduleObject.FillMethod = Enums.WorkScheduleFillingMethods.ByCyclesOfAnyLength;
			WorkScheduleObject.BeginnigDate = Date(2012, 1, 1);
		Else
			// For fivedays and sixdays week fill the appropriate setting.
			WorkScheduleObject.ConsiderHolidays = True;
			WorkScheduleObject.FillMethod = Enums.WorkScheduleFillingMethods.ByWeeks;
			WorkingDaysCount = 5;
			If Selection.CalendarType = Enums.DeleteCalendarKinds.SixDays Then
				WorkingDaysCount = 6;
			EndIf;
			WorkScheduleObject.FillTemplate.Clear();
			For DayNumber = 1 To 7 Do
				NewRow = WorkScheduleObject.FillTemplate.Add();
				NewRow.DayIncludedInSchedule = DayNumber <= WorkingDaysCount;
			EndDo;
		EndIf;
		InfobaseUpdate.WriteData(WorkScheduleObject);
	EndDo;
	
EndProcedure

// Fill the secondary data for optimizing the calculation of dates on the calendar.
//
Procedure FillDaysCountInScheduleYearToDate() Export
	
	QueryText = 
	"SELECT DISTINCT
	|	BusinessCalendarData.Date,
	|	BusinessCalendarData.Year
	|INTO WDates
	|FROM
	|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Dates.Year,
	|	COUNT(Dates.Date) AS DaysNumber
	|INTO VTDaysNumberByYear
	|FROM
	|	WDates AS Dates
	|
	|GROUP BY
	|	Dates.Year
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CalendarSchedules.Calendar,
	|	CalendarSchedules.Year,
	|	COUNT(CalendarSchedules.ScheduleDate) AS DaysNumber
	|INTO VTDaysNumberOnGraphs
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|
	|GROUP BY
	|	CalendarSchedules.Calendar,
	|	CalendarSchedules.Year
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DaysNumberOnGraphs.Calendar,
	|	DaysNumberOnGraphs.Year
	|INTO VTGraphicsYears
	|FROM
	|	VTDaysNumberOnGraphs AS DaysNumberOnGraphs
	|		INNER JOIN VTDaysNumberByYear AS DaysNumberByYear
	|		ON DaysNumberOnGraphs.Year = DaysNumberByYear.Year
	|			AND DaysNumberOnGraphs.DaysNumber < DaysNumberByYear.DaysNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GraphicsYears.Calendar AS Calendar,
	|	GraphicsYears.Year AS Year,
	|	Dates.Date AS ScheduleDate,
	|	ISNULL(CalendarSchedules.DayIncludedInSchedule, FALSE) AS DayIncludedInSchedule
	|FROM
	|	VTGraphicsYears AS GraphicsYears
	|		INNER JOIN WDates AS Dates
	|		ON GraphicsYears.Year = Dates.Year
	|		LEFT JOIN InformationRegister.CalendarSchedules AS CalendarSchedules
	|		ON (CalendarSchedules.Calendar = GraphicsYears.Calendar)
	|			AND (CalendarSchedules.Year = GraphicsYears.Year)
	|			AND (CalendarSchedules.ScheduleDate = Dates.Date)
	|
	|ORDER BY
	|	GraphicsYears.Calendar,
	|	GraphicsYears.Year,
	|	Dates.Date
	|TOTALS BY
	|	Calendar,
	|	Year";
	
	// Select work schedules and years for which resourse value is
	// not filled NumberOfDaysInScheduleSinceTheBeginningOfTheYear fill them sequentially counting the number of days.
	
	Query = New Query(QueryText);
	PicksFromGraphs = Query.Execute().Select(QueryResultIteration.ByGroups);
	While PicksFromGraphs.Next() Do
		SelectionByYear = PicksFromGraphs.Select(QueryResultIteration.ByGroups);
		While SelectionByYear.Next() Do
			RecordSet = InformationRegisters.CalendarSchedules.CreateRecordSet();
			NumberOfDaysInScheduleSinceTheBeginningOfTheYear = 0;
			Selection = SelectionByYear.Select();
			While Selection.Next() Do
				If Selection.DayIncludedInSchedule Then
					NumberOfDaysInScheduleSinceTheBeginningOfTheYear = NumberOfDaysInScheduleSinceTheBeginningOfTheYear + 1;
				EndIf;
				SetRow = RecordSet.Add();
				FillPropertyValues(SetRow, Selection);
				SetRow.NumberOfDaysInScheduleSinceTheBeginningOfTheYear = NumberOfDaysInScheduleSinceTheBeginningOfTheYear;
			EndDo;
			RecordSet.Filter.Calendar.Set(SelectionByYear.Calendar);
			RecordSet.Filter.Year.Set(SelectionByYear.Year);
			InfobaseUpdate.WriteData(RecordSet);
		EndDo;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Procedure executes the update of work schedules on the data of production calendars on all areas of data.
// 
Procedure ScheduleRefreshGraphsWork(Val UpdateConditions) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.CalendarSchedulesSaaS") Then
		ModuleCalendarSchedulesServiceSaaS = CommonUse.CommonModule("CalendarSchedulesServiceSaaS");
		ModuleCalendarSchedulesServiceSaaS.ScheduleRefreshGraphsWork(UpdateConditions);
	EndIf;
	
EndProcedure

#EndRegion
