////////////////////////////////////////////////////////////////////////////////
// Subsystem "Calendar schedules".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// The function returns the array of dates that differ from
// the specified date by the number of days included in the specified schedule.
//
// Parameters:
// WorkSchedule	- schedule (or production calendar) that is to be used, type CatalogRef.Calendars or CatalogRef.BusinessCalendars.
// DateFrom			- the date from which you need to calculate the number of days, Date type.
// DaysArray		- array with the number of days for which you need to increase the beginning date, type Array, Number.
// CalculateNextDateFromPrevious	- whether you need to calculate the
// 										  following date from the previous one or all the dates are calculated from the passed date.
// CallingException - Boolean if True, the exception is thrown if a schedule is not filled in.
//
// Return value
//  Array		- an array of dates increased by the number of days, included in the schedule. 
//  If the selected schedule is not filled and RaiseException = False, then it returns Undefined.
//
Function GetDatesArrayByCalendar(Val WorkSchedule, Val DateFrom, Val DaysArray, Val CalculateNextDateFromPrevious = False, CallingException = True) Export
	
	If TypeOf(WorkSchedule) <> Type("CatalogRef.BusinessCalendars") Then
		If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
			WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
			Return WorkSchedulesModule.DatesOnSchedule(
				WorkSchedule, DateFrom, DaysArray, CalculateNextDateFromPrevious, CallingException);
		EndIf;
	EndIf;
	
	TempTablesManager = New TempTablesManager;
	
	CreateTTIncrementInDays(TempTablesManager, DaysArray, CalculateNextDateFromPrevious);
	
	// The algorithm works in the following way:
	// Receive all calendar dates after the report date.
	// For each such day, calculate a number of days included into the schedule from the report date.
	// Select a number calculated using this method by the days increment table.
	
	Query = New Query;
	
	Query.TempTablesManager = TempTablesManager;
	
	// By production calendar.
	Query.Text =
	"SELECT
	|	CalendarSchedules.Date AS ScheduleDate
	|INTO TTSubsequentDatesGraphics
	|FROM
	|	InformationRegister.BusinessCalendarData AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.Date >= &DateFrom
	|	AND CalendarSchedules.BusinessCalendar = &WorkSchedule
	|	AND CalendarSchedules.DayKind IN (VALUE(Enum.BusinessCalendarDayKinds.Working), VALUE(Enum.BusinessCalendarDayKinds.Preholiday))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FollowScheduleDates.ScheduleDate,
	|	COUNT(CalendarSchedules.ScheduleDate) - 1 AS DaysIncludedToScheduleCount
	|INTO TTSuggestedDatesGraphicsWithNumberOfDays
	|FROM
	|	TTSubsequentDatesGraphics AS FollowScheduleDates
	|		INNER JOIN TTSubsequentDatesGraphics AS CalendarSchedules
	|		ON (CalendarSchedules.ScheduleDate <= FollowScheduleDates.ScheduleDate)
	|
	|GROUP BY
	|	FollowScheduleDates.ScheduleDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IncrementDays.RowIndex,
	|	ISNULL(NextDays.ScheduleDate, UNDEFINED) AS DateInCalendar
	|FROM
	|	TTIncrementInDays AS IncrementDays
	|		LEFT JOIN TTSuggestedDatesGraphicsWithNumberOfDays AS NextDays
	|		ON IncrementDays.DaysNumber = NextDays.DaysIncludedToScheduleCount
	|
	|ORDER BY
	|	IncrementDays.RowIndex";
	
	Query.SetParameter("DateFrom", BegOfDay(DateFrom));
	Query.SetParameter("WorkSchedule", WorkSchedule);
	
	Selection = Query.Execute().Select();
	
	DatesArray = New Array;
	
	While Selection.Next() Do
		If Selection.DateInCalendar = Undefined Then
			ErrorInfo = NStr("en='The ""%1"" business calendar is not filled in from date %2 for the specified number of working days.';ru='Производственный календарь ""%1"" не заполнен с даты %2 на указанное количество рабочих дней.'");
			If CallingException Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
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

// The function returns the date that differs from the
// specified date by a number of days included in the specified schedule.
//
// Parameters:
// WorkSchedule	- schedule (or production calendar) that is to be used, type CatalogRef.Calendars or CatalogRef.BusinessCalendars.
// DateFrom			- the date from which you need to calculate the number of days, Date type.
// DaysNumber	- the number of days for which you need to increase the beginning date, type Number.
// CallingException - Boolean if True, the exception is thrown if a schedule is not filled in.
//
// Return value 
// Date			- date, increased by the number of days included in the schedule.
// If the selected schedule is not filled and RaiseException = False, then it returns Undefined.
//
Function GetDateByCalendar(Val WorkSchedule, Val DateFrom, Val DaysNumber, CallingException = True) Export
	
	DateFrom = BegOfDay(DateFrom);
	
	If DaysNumber = 0 Then
		Return DateFrom;
	EndIf;
	
	DaysArray = New Array;
	DaysArray.Add(DaysNumber);
	
	DatesArray = GetDatesArrayByCalendar(WorkSchedule, DateFrom, DaysArray, , CallingException);
	
	Return ?(DatesArray <> Undefined, DatesArray[0], Undefined);
	
EndFunction

// The function determines a number of days included into the schedule for the specified period.
//
// Parameters:
// WorkSchedule	- schedule (or production calendar) that is to be used, type CatalogRef.Calendars or CatalogRef.BusinessCalendars.
// StartDate		- period start date.
// EndDate	- Ending date of a period.
// CallingException - Boolean if True, the exception is thrown if a schedule is not filled in.
//
// Return value 
// Number		- number of days between the start date and the end date.
// If the selected schedule is not filled and RaiseException = False, then it returns Undefined.
//
Function GetDatesDiffByCalendar(Val WorkSchedule, Val StartDate, Val EndDate, CallingException = True) Export
	
	StartDate = BegOfDay(StartDate);
	EndDate = BegOfDay(EndDate);
	
	ScheduleDates = New Array;
	ScheduleDates.Add(StartDate);
	If Year(StartDate) <> Year(EndDate) AND EndOfDay(StartDate) <> EndOfYear(StartDate) Then
		// If there are dates of different years, then add year boundaries.
		For YearNumber = Year(StartDate) To Year(EndDate) - 1 Do
			ScheduleDates.Add(Date(YearNumber, 12, 31));
		EndDo;
	EndIf;
	ScheduleDates.Add(EndDate);
	
	// Generates a query text of a temporary table that contains the specified dates.
	QueryText = "";
	For Each ScheduleDate IN ScheduleDates Do
		If IsBlankString(QueryText) Then
			TemplateAssociation = 
			"SELECT
			|	DATETIME(%1) AS ScheduleDate
			|INTO TTGraphicDates
			|";
		Else
			TemplateAssociation = 
			"UNION ALL
			|
			|SELECT
			|	DATETIME(%1)";
		EndIf;
		QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
										TemplateAssociation, Format(ScheduleDate, "DF='yyyy, MM, d'"));
	EndDo;
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
	// Prepare temporary tables with source data.
	Query.Text =
	"SELECT DISTINCT
	|	ScheduleDates.ScheduleDate
	|INTO TTVariousDatesGraphics
	|FROM
	|	TTGraphicDates AS ScheduleDates
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	YEAR(ScheduleDates.ScheduleDate) AS Year
	|INTO TTVariousYearsGraphics
	|FROM
	|	TTGraphicDates AS ScheduleDates";
	
	Query.Execute();
	
	If TypeOf(WorkSchedule) = Type("CatalogRef.BusinessCalendars") Then
		// By production calendar.
		Query.Text = 
		"SELECT
		|	CalendarSchedules.Year,
		|	CalendarSchedules.Date AS ScheduleDate,
		|	CASE
		|		WHEN CalendarSchedules.DayKind IN (VALUE(Enum.BusinessCalendarDayKinds.Working), VALUE(Enum.BusinessCalendarDayKinds.Preholiday))
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS DayIncludedInSchedule
		|INTO VTCalendarSchedules
		|FROM
		|	InformationRegister.BusinessCalendarData AS CalendarSchedules
		|		INNER JOIN TTVariousYearsGraphics AS YearGraphics
		|		ON (YearGraphics.Year = CalendarSchedules.Year)
		|WHERE
		|	CalendarSchedules.BusinessCalendar = &WorkSchedule";
		Query.SetParameter("WorkSchedule", WorkSchedule);
		Query.Execute();
	Else
		// on work schedule
		If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
			WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
			WorkSchedulesModule.CreateVTScheduleData(TempTablesManager, WorkSchedule);
		EndIf;
	EndIf;
	
	Query.Text =
	"SELECT
	|	ScheduleDates.ScheduleDate,
	|	COUNT(DaysIncludedInSchedule.ScheduleDate) AS NumberOfDaysInScheduleSinceTheBeginningOfTheYear
	|INTO TTCountOfDaysIncludedInLine
	|FROM
	|	TTVariousDatesGraphics AS ScheduleDates
	|		LEFT JOIN VTCalendarSchedules AS DaysIncludedInSchedule
	|		ON (DaysIncludedInSchedule.Year = YEAR(ScheduleDates.ScheduleDate))
	|			AND (DaysIncludedInSchedule.ScheduleDate <= ScheduleDates.ScheduleDate)
	|			AND (DaysIncludedInSchedule.DayIncludedInSchedule)
	|
	|GROUP BY
	|	ScheduleDates.ScheduleDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ScheduleDates.ScheduleDate,
	|	ISNULL(ScheduleData.DayIncludedInSchedule, FALSE) AS DayIncludedInSchedule,
	|	DaysIncludedInSchedule.NumberOfDaysInScheduleSinceTheBeginningOfTheYear
	|FROM
	|	TTGraphicDates AS ScheduleDates
	|		LEFT JOIN VTCalendarSchedules AS ScheduleData
	|		ON (ScheduleData.Year = YEAR(ScheduleDates.ScheduleDate))
	|			AND (ScheduleData.ScheduleDate = ScheduleDates.ScheduleDate)
	|		LEFT JOIN TTCountOfDaysIncludedInLine AS DaysIncludedInSchedule
	|		ON (DaysIncludedInSchedule.ScheduleDate = ScheduleDates.ScheduleDate)
	|
	|ORDER BY
	|	ScheduleDates.ScheduleDate";
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		If CallingException Then
			ErrorInfo = NStr("en='The ""%1"" work schedule is not filled in for period %2.';ru='График работы ""%1"" не заполнен на период %2.'");
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				ErrorInfo,
				WorkSchedule, PeriodPresentation(StartDate, EndOfDay(EndDate)));
		Else
			Return Undefined;
		EndIf;
	EndIf;
	
	Selection = Result.Select();
	
	// Get a selection for which for each initial date a number of days included into the schedule from the year start is determined.
	// Subtract all the following dates from the value set for the first selection date. As a result, get a number of days included into schedule for the whole period with the minus sign.
	// If the first selection day is a business day, and the following one - weekend, 
	// then a number of days included in both dates will be the same. 
	// IN this case, add 1 day to the result value for correction.
	
	DaysNumberInSchedule = Undefined;
	AddFirstDay = False;
	
	While Selection.Next() Do
		If DaysNumberInSchedule = Undefined Then
			DaysNumberInSchedule = Selection.NumberOfDaysInScheduleSinceTheBeginningOfTheYear;
			AddFirstDay = Selection.DayIncludedInSchedule;
		Else
			DaysNumberInSchedule = DaysNumberInSchedule - Selection.NumberOfDaysInScheduleSinceTheBeginningOfTheYear;
		EndIf;
	EndDo;
	
	Return - DaysNumberInSchedule + ?(AddFirstDay, 1, 0);
	
EndFunction

// The function determines the nearest business day for each date.
//
//	Parameters:
//	Schedule 				 - ref to work schedule or production calendar.
//	BeginningDates  - date array.
//	GetPreceding		 - nearest date receipt method if True - determine business dates before those passed in parameter InitialDates if False - dates not earlier than the start date.
//	CallingException - Boolean if True, the exception is thrown if a schedule is not filled in.
//	IgnoreUnfilledGraphics - Boolean if True, then a match is anyway returned. 
//								Initial dates for which there are no values due to incomplete schedule will not be included.
//
//	Returns:
//	BusinessDates					- match where key - date from passed array, value - the nearest business date (if a business date is passed, it is also returned).
//	If the selected schedule is not filled and RaiseException = False, then it returns Undefined.
//
Function GetWorkingDaysDates(Schedule, BeginningDates, GetPreceding = False, CallingException = True, IgnoreUnfilledGraphics = False) Export
	
	QueryTextTT = "";
	FirstPart = True;
	For Each BeginningDate IN BeginningDates Do
		If Not ValueIsFilled(BeginningDate) Then
			Continue;
		EndIf;
		If Not FirstPart Then
			QueryTextTT = QueryTextTT + "
			|UNION ALL
			|";
		EndIf;
		QueryTextTT = QueryTextTT + "
		|SELECT
		|	DATETIME(" + Format(BeginningDate, "DF=yyyy,MM,dd") + ")";
		If FirstPart Then
			QueryTextTT = QueryTextTT + " HOW Date PLACE InitialDates
			|";
		EndIf;
		FirstPart = False;
	EndDo;

	If IsBlankString(QueryTextTT) Then
		Return New Map;
	EndIf;
	
	Query = New Query(QueryTextTT);
	Query.TempTablesManager = New TempTablesManager;
	Query.Execute();
	
	If TypeOf(Schedule) = Type("CatalogRef.BusinessCalendars") Then
		QueryText = 
		"SELECT
		|	BeginningDates.Date,
		|	%Function%(CalendarDates.Date) AS ClosestDate
		|FROM
		|	BeginningDates AS BeginningDates
		|		LEFT JOIN InformationRegister.BusinessCalendarData AS CalendarDates
		|		ON (CalendarDates.Date %ConditionSign% BeginningDates.Date)
		|			AND (CalendarDates.BusinessCalendar = &Schedule)
		|			AND (CalendarDates.DayKind IN (
		|			VALUE(Enum.BusinessCalendarDayKinds.Working), 
		|			VALUE(Enum.BusinessCalendarDayKinds.Preholiday)
		|			))
		|
		|GROUP BY
		|	BeginningDates.Date";
	Else
		// on work schedule
		If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
			WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
			QueryText = WorkSchedulesModule.QueryTextTemplateDefinitionNextDatesOnWorkSchedule();
		EndIf;
	EndIf;
	
	QueryText = StrReplace(QueryText, "%Function%", 				?(GetPreceding, "MAX", "MIN"));
	QueryText = StrReplace(QueryText, "%ConditionSign%", 			?(GetPreceding, "<=", ">="));
	
	Query.Text = QueryText;
	Query.SetParameter("Schedule", Schedule);
	
	Selection = Query.Execute().Select();
	
	WorkingDaysDates = New Map;
	While Selection.Next() Do
		If ValueIsFilled(Selection.ClosestDate) Then
			WorkingDaysDates.Insert(Selection.Date, Selection.ClosestDate);
		Else 
			If IgnoreUnfilledGraphics Then
				Continue;
			EndIf;
			If CallingException Then
				ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(
									NStr("en='Cannot determine the nearest workday for date %1, work schedule might not be populated.';ru='Невозможно определить ближайшую рабочую дату для даты %1, возможно, график работы не заполнен.'"), 
									Format(Selection.Date, "DLF=D"));
				Raise(ErrorMessage);
			Else
				Return Undefined;
			EndIf;
		EndIf;
	EndDo;
	
	Return WorkingDaysDates;
	
EndFunction

// Makes work schedules for dates included in the specified schedules for the specified period.
// If the preholiday day schedule is not set, then it will be defined as if this day is a work day.
//
// ATTENTION! Subsystem WorkSchedules must exist for the method operation.
//
// Parameters:
// Graphics  - items array of the CatalogRef.Calendars type.
// StartDate - Beginning date of the period for which you need to make schedules.
// EndDate   - Ending date of a period.
//
// Returns - Value table with columns.
// WorkSchedule
// ScheduleDate
// BeginTime
// EndTime
//
Function SchedulesOfWorkOnPeriod(Graphics, StartDate, EndDate) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
		Return WorkSchedulesModule.SchedulesOfWorkOnPeriod(Graphics, StartDate, EndDate);
	EndIf;
	
	Raise NStr("en='Subsystem ""Work schedules"" not found.';ru='Подсистема ""Графики работы"" не обнаружена.'");
	
EndFunction

// Creates the TTWorkSchedule temporary table with columns in the manager.
// For more information, see comment to function WorkSchedulesOnPeriod.
//
// ATTENTION! Subsystem WorkSchedules must exist for the method operation.
//
Procedure CreateTSchedulesOfWorkOnPeriod(TempTablesManager, Graphics, StartDate, EndDate) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
		WorkSchedulesModule.CreateTSchedulesOfWorkOnPeriod(TempTablesManager, Graphics, StartDate, EndDate);
		Return;
	EndIf;
	
	Raise NStr("en='Subsystem ""Work schedules"" not found.';ru='Подсистема ""Графики работы"" не обнаружена.'");
	
EndProcedure

// Fills out an attribute in the form if a single production calendar is used.
//
// Parameters:
// Form
// AttributePath - String, data path, for example, "Object.BusinessCalendar".
//
Procedure FillFactoryCalendarInForm(Form, AttributePath) Export
	
	If GetFunctionalOption("UseSeveralBusinessCalendars") Then
		Return;
	EndIf;
	
	UsedCalendars = Catalogs.BusinessCalendars.BusinessCalendarsList();
	
	If UsedCalendars.Count() > 0 Then
		CommonUseClientServer.SetFormAttributeByPath(Form, AttributePath, UsedCalendars[0]);
	EndIf;
	
EndProcedure

// Allows to get a production calendar made up according to art. 112 TC RF.
//
// Returns - ref to the Business calendars catalog item, Undefined if the production calendar is not found.
//
Function BusinessCalendarOfRussiaFederation() Export
		
	BusinessCalendar = Catalogs.BusinessCalendars.FindByCode("RF");
	
	If BusinessCalendar.IsEmpty() Then 
		Return Undefined;
	EndIf;

	Return BusinessCalendar;
	
EndFunction

#EndRegion

#Region ServiceProgramInterface

// Declares service events of subsystem CalendarSchedules:
//
// Server events:
//   OnUpdateBusinessCalendars.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// It is called when the production calendars data is changed.
	//
	// Parameters:
	//  - UpdateConditions - Value table with columns.
	// 	- BusinessCalendarCode - production calendar code which data has been changed,
	// 	- Year - the year during which the data has changed.
	//
	// Syntax:
	// Procedure OnUpdateBusinessCalendars(UpdateConditions) Export
	//
	// (Same as CalendarSchedulesOverridable.OnUpdateBusinessCalendars).
	//
	ServerEvents.Add("StandardSubsystems.CalendarSchedules\OnUpdateBusinessCalendars");
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"
	].Add("CalendarSchedules");
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers[
			"ServiceTechnology.DataExportImport\WhenFillingCommonDataTypesSupportingMatchingRefsOnImport"
		].Add("CalendarSchedules");
	EndIf;
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnGettingObligatoryExchangePlanObjects"
	].Add("CalendarSchedules");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Fills the array of types of undivided data for
// which the refs matching during data import to another infobase is supported.
//
// Parameters:
//  Types - Array(MetadataObject)
//
Procedure WhenFillingCommonDataTypesSupportingMatchingRefsOnImport(Types) Export
	
	Types.Add(Metadata.Catalogs.BusinessCalendars);
	
EndProcedure

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
		
		Objects.Add(Metadata.Catalogs.BusinessCalendars);
		Objects.Add(Metadata.InformationRegisters.BusinessCalendarData);
		
	EndIf;
	
EndProcedure

// Creates temporary table VTDaysIncrement in which a string with an item index and value is created for each item from DaysArray. - by number of days.
// 
// Parameters:
// - TemporaryTablesManager,
// - DaysArray - array, number of days,
// - CalculateNextDateFromPrevious - optional, default value is False.
//
Procedure CreateTTIncrementInDays(TempTablesManager, Val DaysArray, Val CalculateNextDateFromPrevious = False) Export
	
	IncrementDays = New ValueTable;
	IncrementDays.Columns.Add("RowIndex", New TypeDescription("Number"));
	IncrementDays.Columns.Add("DaysNumber", New TypeDescription("Number"));
	
	DaysNumber = 0;
	LineNumber = 0;
	For Each RowDays IN DaysArray Do
		DaysNumber = DaysNumber + RowDays;
		
		String = IncrementDays.Add();
		String.RowIndex			= LineNumber;
		If CalculateNextDateFromPrevious Then
			String.DaysNumber	= DaysNumber;
		Else
			String.DaysNumber	= RowDays;
		EndIf;
			
		LineNumber = LineNumber + 1;
	EndDo;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
	|	IncrementDays.RowIndex,
	|	IncrementDays.DaysNumber
	|INTO TTIncrementInDays
	|FROM
	|	&IncrementDays AS IncrementDays";
	
	Query.SetParameter("IncrementDays",	IncrementDays);
	
	Query.Execute();
	
EndProcedure

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
	Handler.Procedure = "CalendarSchedules.UpdateBusinessCalendars";
	Handler.Version = "1.0.0.1";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "CalendarSchedules.RefreshDataBusinessCalendars";
	Handler.PerformModes = "Exclusive";
	Handler.Version = "1.0.0.1";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "CalendarSchedules.UpdateSeveralBusinessCalendarsUse";
	Handler.Version = "1.0.0.1";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.7";
	Handler.Procedure = "CalendarSchedules.UpdateSeveralBusinessCalendarsUse";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.4.26";
	Handler.Procedure = "CalendarSchedules.RefreshDataBusinessCalendars";
	Handler.PerformModes = "Exclusive";
	Handler.SharedData = True;
	
EndProcedure

// Updates catalog Business calendars for a directory with the same name.
//
Procedure UpdateBusinessCalendars() Export
	
	TextDocument = Catalogs.BusinessCalendars.GetTemplate("CalendarsDescription");
	TableCalendars = CommonUse.ReadXMLToTable(TextDocument.GetText()).Data;
	
	Catalogs.BusinessCalendars.UpdateBusinessCalendars(TableCalendars);
	
EndProcedure

// Updates the production calendar data from a template.
//  BusinessCalendarsData
//
Procedure RefreshDataBusinessCalendars() Export
	
	DataTable = Catalogs.BusinessCalendars.BusinessCalendarsDataFromTemplate();
	
	// Update data of production calendars.
	Catalogs.BusinessCalendars.RefreshDataBusinessCalendars(DataTable);
	
EndProcedure

// Sets the constant value that determines use of multiple production calendars.
//
Procedure UpdateSeveralBusinessCalendarsUse() Export
	
	UseFewCalendars = Catalogs.BusinessCalendars.BusinessCalendarsList().Count() <> 1;
	If UseFewCalendars <> GetFunctionalOption("UseSeveralBusinessCalendars") Then
		Constants.UseSeveralBusinessCalendars.Set(UseFewCalendars);
	EndIf;
	
EndProcedure

#EndRegion
