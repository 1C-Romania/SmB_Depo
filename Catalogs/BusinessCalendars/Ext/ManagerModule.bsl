#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Function reads business calendar data from register.
//
// Parameters:
// BusinessCalendar			- Ref to the current catalog item.
// YearNumber							- Number of the year for which it is required to read business calendar.
//
// Return
// value BusinessCalendarData	- values table that stores information about a day kind for each calendar date.
//
Function BusinessCalendarData(BusinessCalendar, YearNumber) Export
	
	Query = New Query;
	
	Query.SetParameter("BusinessCalendar",	BusinessCalendar);
	Query.SetParameter("CurrentYear",	YearNumber);
	Query.Text =
	"SELECT
	|	BusinessCalendarData.Date,
	|	BusinessCalendarData.DayKind,
	|	BusinessCalendarData.DestinationDate
	|FROM
	|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|WHERE
	|	BusinessCalendarData.Year = &CurrentYear
	|	AND BusinessCalendarData.BusinessCalendar = &BusinessCalendar";
	
	Return Query.Execute().Unload();
	
EndFunction

// The function prepares the result of
// filling business calendar with the default data.
// If there is layout with predefined data of
//  the business calendar for this year in configuration,
//  layout data is used, otherwise, the business calendar data is
//  generated based on the holidays information and considering existing weekends transfer rules.
//
Function ResultFillManufacturingCalendarDefault(BusinessCalendarCode, YearNumber) Export
	
	LengthOfDay = 24 * 3600;
	
	BusinessCalendarData = New ValueTable;
	BusinessCalendarData.Columns.Add("Date", New TypeDescription("Date"));
	BusinessCalendarData.Columns.Add("DayKind", New TypeDescription("EnumRef.BusinessCalendarDayKinds"));
	BusinessCalendarData.Columns.Add("DestinationDate", New TypeDescription("Date"));
	
	// If there is data in the layout, - use it.
	PredefinedData = BusinessCalendarsDataFromTemplate().FindRows(
								New Structure("BusinessCalendarCode, Year", BusinessCalendarCode, YearNumber));
	If PredefinedData.Count() > 0 Then
		CommonUseClientServer.SupplementTable(PredefinedData, BusinessCalendarData);
		Return BusinessCalendarData;
	EndIf;
	
	// If not - fill in holidays and transfers.
	HolidayDays = BusinessCalendarHolidays(BusinessCalendarCode, YearNumber);
	// Expand table using the next year holidays as they influence filling of the current year (for example, December 31 - pre-holiday).
	NextYearHolidays = BusinessCalendarHolidays(BusinessCalendarCode, YearNumber + 1);
	CommonUseClientServer.SupplementTable(NextYearHolidays, HolidayDays);
	
	DayKinds = New Map;
	
	DateOfDay = Date(YearNumber, 1, 1);
	While DateOfDay <= Date(YearNumber, 12, 31) Do
		// "FromNonHoliday" day - determine considering the weekday.
		WeekDayNumber = WeekDay(DateOfDay);
		If WeekDayNumber <= 5 Then
			DayKinds.Insert(DateOfDay, Enums.BusinessCalendarDayKinds.Working);
		ElsIf WeekDayNumber = 6 Then
			DayKinds.Insert(DateOfDay, Enums.BusinessCalendarDayKinds.Saturday);
		ElsIf WeekDayNumber = 7 Then
			DayKinds.Insert(DateOfDay, Enums.BusinessCalendarDayKinds.Sunday);
		EndIf;
		DateOfDay = DateOfDay + LengthOfDay;
	EndDo;
	
	// If a weekend day and a public holiday match, the weekend day is transferred to the next working day after the holiday except of the weekends that match with public holidays during the New Year holidays and Christmas.	
	
	TransfersOfDays = New Map;
	For Each TableRow IN HolidayDays Do
		HoliDay = TableRow.Date;
		// Mark the working day preceding the holiday as a pre-holiday.
		DateIncludedDays = HoliDay - LengthOfDay;
		If Year(DateIncludedDays) <> YearNumber Then
			// Skip pre-holidays of another year.
			Continue;
		EndIf;
		If DayKinds[DateIncludedDays] = Enums.BusinessCalendarDayKinds.Working 
			AND HolidayDays.Find(DateIncludedDays, "Date") = Undefined Then
			DayKinds.Insert(DateIncludedDays, Enums.BusinessCalendarDayKinds.Preholiday);
		EndIf;
		If DayKinds[HoliDay] <> Enums.BusinessCalendarDayKinds.Working 
			AND TableRow.WeekendWrap Then
			// If a holiday is on the weekend, the weekend day which is the holiday is transferred - 
			// transfer weekend day to the nearest working day.
			DateOfDay = HoliDay;
			While True Do
				DateOfDay = DateOfDay + LengthOfDay;
				If DayKinds[DateOfDay] = Enums.BusinessCalendarDayKinds.Working 
					AND HolidayDays.Find(DateOfDay, "Date") = Undefined Then
					DayKinds.Insert(DateOfDay, DayKinds[HoliDay]);
					TransfersOfDays.Insert(DateOfDay, HoliDay);
					TransfersOfDays.Insert(HoliDay, DateOfDay);
					Break;
				EndIf;
			EndDo;
		EndIf;
		DayKinds.Insert(HoliDay, Enums.BusinessCalendarDayKinds.Holiday);
	EndDo;
	
	For Each KeyAndValue IN DayKinds Do
		NewRow = BusinessCalendarData.Add();
		NewRow.Date = KeyAndValue.Key;
		NewRow.DayKind = KeyAndValue.Value;
		DestinationDate = TransfersOfDays[NewRow.Date];
		If DestinationDate <> Undefined Then
			NewRow.DestinationDate = DestinationDate;
		EndIf;
	EndDo;
	
	BusinessCalendarData.Sort("Date");
	
	Return BusinessCalendarData;
	
EndFunction

// The function converts business calendars
// data passed as a configuration layout.
//
// Parameters:
// - no
//
// Returns - Value table with columns.
// For more information, see comment to the BusinessCalendarsDataFromXML function.
//
Function BusinessCalendarsDataFromTemplate() Export
	
	TextDocument = InformationRegisters.BusinessCalendarData.GetTemplate("BusinessCalendarsData");
	
	Return BusinessCalendarsDataFromXML(TextDocument.GetText());
	
EndFunction

// The function converts business calendars
// data presented as XML.
//
// Parameters:
// - XML - document with data
//
// Returns - a table of values with the following columns:
// - BusinessCalendarCode
// - DayKind
// - Year
// - Date
// - DestinationDate
//
Function BusinessCalendarsDataFromXML(Val XML) Export
	
	DataTable = New ValueTable;
	DataTable.Columns.Add("BusinessCalendarCode", New TypeDescription("String", , New StringQualifiers(2)));
	DataTable.Columns.Add("DayKind", New TypeDescription("EnumRef.BusinessCalendarDayKinds"));
	DataTable.Columns.Add("Year", New TypeDescription("Number"));
	DataTable.Columns.Add("Date", New TypeDescription("Date"));
	DataTable.Columns.Add("DestinationDate", New TypeDescription("Date"));
	
	ClassifierTable = CommonUse.ReadXMLToTable(XML).Data;
	
	For Each ClassifierRow IN ClassifierTable Do
		NewRow = DataTable.Add();
		NewRow.BusinessCalendarCode = ClassifierRow.Calendar;
		NewRow.DayKind	= Enums.BusinessCalendarDayKinds[ClassifierRow.DayType];
		NewRow.Year		= Number(ClassifierRow.Year);
		NewRow.Date	= Date(ClassifierRow.Date);
		If ValueIsFilled(ClassifierRow.SwapDate) Then
			NewRow.DestinationDate = Date(ClassifierRow.SwapDate);
		EndIf;
	EndDo;
	
	Return DataTable;
	
EndFunction

// Updates catalog Business calendars from XML file.
//
// Parameters:
// - TableCalendars - values table with the business calendars description.
//
Procedure UpdateBusinessCalendars(TableCalendars) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CAST(ClassifierTable.Code AS String(2)) AS Code,
	|	CAST(ClassifierTable.Description AS String(100)) AS Description
	|INTO ClassifierTable
	|FROM
	|	&ClassifierTable AS ClassifierTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ClassifierTable.Code,
	|	ClassifierTable.Description,
	|	BusinessCalendars.Ref AS Ref,
	|	ISNULL(BusinessCalendars.Code, """") AS BusinessCalendarCode,
	|	ISNULL(BusinessCalendars.Description, """") AS BusinessCalendarName
	|FROM
	|	ClassifierTable AS ClassifierTable
	|		LEFT JOIN Catalog.BusinessCalendars AS BusinessCalendars
	|		ON ClassifierTable.Code = BusinessCalendars.Code";
	
	Query.SetParameter("ClassifierTable", TableCalendars);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If TrimAll(Selection.Code) = TrimAll(Selection.BusinessCalendarCode)
			AND Selection.Description = Selection.BusinessCalendarName Then
			Continue;
		EndIf;
		If ValueIsFilled(Selection.Ref) Then
			CatalogObject = Selection.Ref.GetObject();
		Else
			CatalogObject = Catalogs.BusinessCalendars.CreateItem();
		EndIf;
		CatalogObject.Code = TrimAll(Selection.Code);
		CatalogObject.Description = TrimAll(Selection.Description);
		CatalogObject.Write();
	EndDo;
	
EndProcedure

// Updates business calendars data by the data table.
//
Procedure RefreshDataBusinessCalendars(DataTable) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ClassifierTable.BusinessCalendarCode AS CalendarCode,
	|	ClassifierTable.Date,
	|	ClassifierTable.Year,
	|	ClassifierTable.DayKind,
	|	ClassifierTable.DestinationDate
	|INTO ClassifierTable
	|FROM
	|	&ClassifierTable AS ClassifierTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BusinessCalendars.Ref AS BusinessCalendar,
	|	ClassifierTable.Year,
	|	ClassifierTable.Date,
	|	ClassifierTable.DayKind,
	|	ClassifierTable.DestinationDate
	|FROM
	|	ClassifierTable AS ClassifierTable
	|		INNER JOIN Catalog.BusinessCalendars AS BusinessCalendars
	|		ON ClassifierTable.CalendarCode = BusinessCalendars.Code
	|		LEFT JOIN InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|		ON (BusinessCalendars.Ref = BusinessCalendarData.BusinessCalendar)
	|			AND ClassifierTable.Year = BusinessCalendarData.Year
	|			AND ClassifierTable.Date = BusinessCalendarData.Date
	|WHERE
	|	(BusinessCalendarData.DayKind IS NULL 
	|			OR ClassifierTable.DayKind <> BusinessCalendarData.DayKind
	|			OR ClassifierTable.DestinationDate <> BusinessCalendarData.DestinationDate)";
	
	Query.SetParameter("ClassifierTable", DataTable);
	
	RecordSet = InformationRegisters.BusinessCalendarData.CreateRecordSet();
	
	RegisterKeys = New Array;
	RegisterKeys.Add("BusinessCalendar");
	RegisterKeys.Add("Year");
	RegisterKeys.Add("Date");
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		RecordSet.Clear();
		FillPropertyValues(RecordSet.Add(), Selection);
		For Each Key1 IN RegisterKeys Do 
			RecordSet.Filter[Key1].Set(Selection[Key1]);
		EndDo;
		RecordSet.Write(True);
	EndDo;
	
	DataTable.GroupBy("BusinessCalendarCode, Year");
	DistributeChangesDataBusinessCalendars(DataTable);
	
EndProcedure

// Procedure writes data of one business calendar for 1 year.
//
// Parameters:
// BusinessCalendar			- Ref to the current catalog item.
// YearNumber							- Year number for which it is required to write business calendar.
// BusinessCalendarData	- values table that stores information about a day kind for each calendar date.
//
// Return
// value No
//
Procedure SpecifyBusinessCalendarData(BusinessCalendar, YearNumber, BusinessCalendarData) Export
	
	RecordSet = InformationRegisters.BusinessCalendarData.CreateRecordSet();
	
	For Each KeyAndValue IN BusinessCalendarData Do
		FillPropertyValues(RecordSet.Add(), KeyAndValue);
	EndDo;
	
	FilterValues = New Structure("BusinessCalendar, Year", BusinessCalendar, YearNumber);
	
	For Each KeyAndValue IN FilterValues Do
		RecordSet.Filter[KeyAndValue.Key].Set(KeyAndValue.Value);
	EndDo;
	
	For Each SetRow IN RecordSet Do
		FillPropertyValues(SetRow, FilterValues);
	EndDo;
	
	RecordSet.Write(True);
	
	UpdateConditions = ConditionsUpdatedGraphsWork(BusinessCalendar, YearNumber);
	DistributeChangesDataBusinessCalendars(UpdateConditions);
	
EndProcedure

// Designed to update items connected with the business calendar, for example, Work schedules.
//
// Parameters:
// ChangeTable - table with columns.
// 	- BusinessCalendarCode - production calendar code which data has been changed,
// 	- Year - year for which it is required to update data.
//
Procedure DistributeChangesDataBusinessCalendars(ChangeTable) Export
	
	// Update working schedules data filled in automatically based on the business calendar.
	
	If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
		If CommonUseReUse.DataSeparationEnabled() Then
			WorkSchedulesModule.ScheduleRefreshGraphsWork(ChangeTable);
		Else
			WorkSchedulesModule.UpdateWorkSchedulesByFactoryCalendarData(ChangeTable);
		EndIf;
	EndIf;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.CalendarSchedules\OnUpdateBusinessCalendars");
	For Each Handler IN EventHandlers Do
		Handler.Module.OnUpdateBusinessCalendars(ChangeTable);
	EndDo;
	
	CalendarSchedulesOverridable.OnUpdateBusinessCalendars(ChangeTable);
	
EndProcedure

// Function determines match of the business calendar day kinds
// with design color of this day in the calendar field.
//
// Return
// value is DesignColors - match of the day kinds with the design colors.
//
Function DecorColorsOfBusinessCalendarDayTypes() Export
	
	AppearanceColors = New Map;
	
	AppearanceColors.Insert(Enums.BusinessCalendarDayKinds.Working,			StyleColors.BusinessCalendarDayTypeWorkColor);
	AppearanceColors.Insert(Enums.BusinessCalendarDayKinds.Saturday,			StyleColors.BusinessCalendarDayTypeSaturdayColor);
	AppearanceColors.Insert(Enums.BusinessCalendarDayKinds.Sunday,		StyleColors.BusinessCalendarDayTypeSundayColor);
	AppearanceColors.Insert(Enums.BusinessCalendarDayKinds.Preholiday,	StyleColors.BusinessCalendarDayTypePreHolidayColor);
	AppearanceColors.Insert(Enums.BusinessCalendarDayKinds.Holiday,			StyleColors.BusinessCalendarDayTypeHolidayColor);
	
	Return AppearanceColors;
	
EndFunction

// Function makes a list of all possible day kinds of the business calendar by the BusinessCalendarDayKinds enumeration metadata.
//
// Return
// value is DayKindsList - values list containing enumeration value
// and its synonym as a presentation.
//
Function DayKindList() Export
	
	DayKindList = New ValueList;
	
	For Each DayKindMetadata IN Metadata.Enums.BusinessCalendarDayKinds.EnumValues Do
		DayKindList.Add(Enums.BusinessCalendarDayKinds[DayKindMetadata.Name], DayKindMetadata.Synonym);
	EndDo;
	
	Return DayKindList;
	
EndFunction

// Function makes an array of
// available business calendars for usage, for example, as a template.
//
Function BusinessCalendarsList() Export

	Query = New Query(
	"SELECT
	|	BusinessCalendars.Ref
	|FROM
	|	Catalog.BusinessCalendars AS BusinessCalendars
	|WHERE
	|	(NOT BusinessCalendars.DeletionMark)");
		
	BusinessCalendarsList = New Array;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		BusinessCalendarsList.Add(Selection.Ref);
	EndDo;
	
	Return BusinessCalendarsList;
	
EndFunction

// Function determines the last day for which data of the specified business calendar is filled in.
//
// Parameters:
// - BusinessCalendar - type CatalogRef.BusinessCalendars.
//
Function BusinessCalendars(BusinessCalendar) Export
	
	QueryText = 
	"SELECT
	|	MAX(BusinessCalendarData.Date) AS Date
	|FROM
	|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|WHERE
	|	BusinessCalendarData.BusinessCalendar = &BusinessCalendar
	|
	|HAVING
	|	MAX(BusinessCalendarData.Date) IS Not NULL ";
	
	Query = New Query(QueryText);
	Query.SetParameter("BusinessCalendar", BusinessCalendar);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Date;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Function fills in an array of holiday dates by the production calendar for the specified calendar year.
// 
Function BusinessCalendarHolidays(BusinessCalendarCode, YearNumber)
	
	HolidayDays = New ValueTable;
	HolidayDays.Columns.Add("Date", New TypeDescription("Date"));
	HolidayDays.Columns.Add("WeekendWrap", New TypeDescription("Boolean"));
	
	If BusinessCalendarCode = "RF" Then
		
		// AND, January, 2, 3, 4, 5, 6 and 8 - New Year holidays.
		AddFestiveDay(HolidayDays, "01.01", YearNumber, False);
		AddFestiveDay(HolidayDays, "02.01", YearNumber, False);
		AddFestiveDay(HolidayDays, "03.01", YearNumber, False);
		AddFestiveDay(HolidayDays, "04.01", YearNumber, False);
		AddFestiveDay(HolidayDays, "05.01", YearNumber, False);
		AddFestiveDay(HolidayDays, "06.01", YearNumber, False);
		AddFestiveDay(HolidayDays, "08.01", YearNumber, False);
		
		// J January - Christmas.
		AddFestiveDay(HolidayDays, "07.01", YearNumber, False);
		
		// F3 February - Defender's Day.
		AddFestiveDay(HolidayDays, "23.02", YearNumber);
		
		// M March - International Women's Day.
		AddFestiveDay(HolidayDays, "08.03", YearNumber);
		
		// M May - Spring and Labour Day.
		AddFestiveDay(HolidayDays, "01.05", YearNumber);
		
		// May 9 - Victory Day
		AddFestiveDay(HolidayDays, "09.05", YearNumber);
		
		// June 12 - Russia Day
		AddFestiveDay(HolidayDays, "12.06", YearNumber);
		
		// N November - National Unity Day.
		AddFestiveDay(HolidayDays, "04.11", YearNumber);
		
	EndIf;
	
	Return HolidayDays;
	
EndFunction

Procedure AddFestiveDay(HolidayDays, HoliDay, YearNumber, WeekendWrap = True)
	
	DayMonth = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(HoliDay, ".");
	
	NewRow = HolidayDays.Add();
	NewRow.Date = Date(YearNumber, DayMonth[1], DayMonth[0]);
	NewRow.WeekendWrap = WeekendWrap;
	
EndProcedure

Function ConditionsUpdatedGraphsWork(BusinessCalendar, Year)
	
	UpdateConditions = New ValueTable;
	UpdateConditions.Columns.Add("BusinessCalendarCode", New TypeDescription("String", , New StringQualifiers(3)));
	UpdateConditions.Columns.Add("Year", New TypeDescription("Number", New NumberQualifiers(4)));
	
	NewRow = UpdateConditions.Add();
	NewRow.BusinessCalendarCode = CommonUse.ObjectAttributeValue(BusinessCalendar, "Code");
	NewRow.Year = Year;

	Return UpdateConditions;
	
EndFunction

// Returns catalog attributes which form
//  the natural key for the catalog items.
//
// Return value: Array(Row) - is the array
//  of names of attributes which form the natural key.
//
Function NaturalKeyFields() Export
	
	Result = New Array();
	
	Result.Add("Code");
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Business calendar print form.

// Generates print forms
//
// Parameters:
//  (input)
//    ObjectsArray  - Array    - references to objects to be printed;
//    PrintParameters - Structure - additional printing settings;
//  (weekend)
//   PrintFormsCollection - ValueTable - generated tabular documents.
//   PrintObjects         - ValueList  - value - ref to object;
//                                             Presentation - area name to which object was output;
//   OutputParameters       - Structure       - additional parameters of the generated tabular documents.
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.Print") Then
		PrintManagementModule = CommonUse.CommonModule("PrintManagement");
		PrintManagementModule.OutputSpreadsheetDocumentToCollection(
				PrintFormsCollection,
				"BusinessCalendar", NStr("en='Business calendar';ru='Производственный календарь'"),
				Catalogs.BusinessCalendars.PrintingFormBusinessCalendar(PrintParameters),
				,
				"Catalog.BusinessCalendars.PF_MXL_BusinessCalendar");
	EndIf;
	
EndProcedure

Function PrintingFormBusinessCalendar(ParametersForPrintingForms) Export
	
	QueryText = 
	"SELECT
	|	YEAR(CalendarData.Date) AS YearCalendar,
	|	QUARTER(CalendarData.Date) AS QuarterWeek,
	|	MONTH(CalendarData.Date) AS MonthCalendar,
	|	COUNT(DISTINCT CalendarData.Date) AS CalendarDays,
	|	CalendarData.DayKind AS DayKind
	|FROM
	|	InformationRegister.BusinessCalendarData AS CalendarData
	|WHERE
	|	CalendarData.Year = &Year
	|	AND CalendarData.BusinessCalendar = &BusinessCalendar
	|
	|GROUP BY
	|	CalendarData.DayKind,
	|	YEAR(CalendarData.Date),
	|	QUARTER(CalendarData.Date),
	|	MONTH(CalendarData.Date)
	|
	|ORDER BY
	|	YearCalendar,
	|	QuarterWeek,
	|	MonthCalendar
	|TOTALS BY
	|	YearCalendar,
	|	QuarterWeek,
	|	MonthCalendar";
	
	BusinessCalendar = ParametersForPrintingForms.BusinessCalendar;
	YearNumber = ParametersForPrintingForms.YearNumber;
	
	Template = Catalogs.BusinessCalendars.GetTemplate("PF_MXL_BusinessCalendar");
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	PrintTitle = Template.GetArea("Title");
	PrintTitle.Parameters.BusinessCalendar = BusinessCalendar;
	PrintTitle.Parameters.Year = Format(YearNumber, "NG=");
	SpreadsheetDocument.Put(PrintTitle);
	
	// Initial values, regardless of the query execution result.
	WorkingTime40Year = 0;
	WorkingTime36Year = 0;
	WorkingTime24Year = 0;
	
	TypesOfNonWorkingDays = New Array;
	TypesOfNonWorkingDays.Add(Enums.BusinessCalendarDayKinds.Saturday);
	TypesOfNonWorkingDays.Add(Enums.BusinessCalendarDayKinds.Sunday);
	TypesOfNonWorkingDays.Add(Enums.BusinessCalendarDayKinds.Holiday);
	
	Query = New Query(QueryText);
	Query.SetParameter("Year", YearNumber);
	Query.SetParameter("BusinessCalendar", BusinessCalendar);
	Result = Query.Execute();
	
	SelectionByYear = Result.Select(QueryResultIteration.ByGroups);
	While SelectionByYear.Next() Do
		
		SelectionByQuarter = SelectionByYear.Select(QueryResultIteration.ByGroups);
		While SelectionByQuarter.Next() Do
			NumberOfQuarter = Template.GetArea("Quarter");
			NumberOfQuarter.Parameters.NumberOfQuarter = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='%1 Quarter';ru='%1 квартал'"), SelectionByQuarter.QuarterWeek);
			SpreadsheetDocument.Put(NumberOfQuarter);
			
			HeaderBlock = Template.GetArea("HeaderBlock");
			SpreadsheetDocument.Put(HeaderBlock);
			
			CalendarDaysQ = 0;
			WorkingTime40Kv = 0;
			WorkingTime36Kv = 0;
			WorkingTime42Kv = 0;
			WorkingDaysQr	 = 0;
			WeekendQ	 = 0;
			
			If SelectionByQuarter.QuarterWeek = 1 
				Or SelectionByQuarter.QuarterWeek = 3 Then
				HalfYearCalendarDays1	= 0;
				WorkingTime40HalfYear1	= 0;
				WorkingTime36HalfYear1	= 0;
				WorkingTime24HalfYear1	= 0;
				WeekdaysHalfYear1		= 0;
				WeekendHalfYear1		= 0;
			EndIf;
			
			If SelectionByQuarter.QuarterWeek = 1 Then
				CalendarDaysOfYear	= 0;
				WorkingTime40Year	= 0;
				WorkingTime36Year	= 0;
				WorkingTime24Year	= 0;
				WorkingDaysOfYear		= 0;
				WeekendYear		= 0;
			EndIf;
			
			SelectionByMonth = SelectionByQuarter.Select(QueryResultIteration.ByGroups);
			While SelectionByMonth.Next() Do
				
				WeekEnd		= 0;
				WorkingTime40	= 0;
				WorkingTime36	= 0;
				WorkingTime24	= 0;
				CalendarDays	= 0;
				WorkDays		= 0;
				SelectionByTypeOfDay = SelectionByMonth.Select(QueryResultIteration.Linear);
				
				While SelectionByTypeOfDay.Next() Do
					If SelectionByTypeOfDay.DayKind = Enums.BusinessCalendarDayKinds.Saturday 
						Or SelectionByTypeOfDay.DayKind = Enums.BusinessCalendarDayKinds.Sunday
						Or SelectionByTypeOfDay.DayKind = Enums.BusinessCalendarDayKinds.Holiday Then
						 WeekEnd = WeekEnd + SelectionByTypeOfDay.CalendarDays
					 ElsIf SelectionByTypeOfDay.DayKind = Enums.BusinessCalendarDayKinds.Working Then 
						 WorkingTime40 = WorkingTime40 + SelectionByTypeOfDay.CalendarDays * 8;
						 WorkingTime36 = WorkingTime36 + SelectionByTypeOfDay.CalendarDays * 36 / 5;
						 WorkingTime24 = WorkingTime24 + SelectionByTypeOfDay.CalendarDays * 24 / 5;
						 WorkDays 	= WorkDays + SelectionByTypeOfDay.CalendarDays;
					 ElsIf SelectionByTypeOfDay.DayKind = Enums.BusinessCalendarDayKinds.Preholiday Then
						 WorkingTime40 = WorkingTime40 + SelectionByTypeOfDay.CalendarDays * 7;
						 WorkingTime36 = WorkingTime36 + SelectionByTypeOfDay.CalendarDays * (36 / 5 - 1);
						 WorkingTime24 = WorkingTime24 + SelectionByTypeOfDay.CalendarDays * (24 / 5 - 1);
						 WorkDays		= WorkDays + SelectionByTypeOfDay.CalendarDays;
					 EndIf;
					 CalendarDays = CalendarDays + SelectionByTypeOfDay.CalendarDays;
				EndDo;
				
				CalendarDaysQ = CalendarDaysQ + CalendarDays;
				WorkingTime40Kv = WorkingTime40Kv + WorkingTime40;
				WorkingTime36Kv = WorkingTime36Kv + WorkingTime36;
				WorkingTime42Kv = WorkingTime42Kv + WorkingTime24;
				WorkingDaysQr	 = WorkingDaysQr 	+ WorkDays;
				WeekendQ	 = WeekendQ	+ WeekEnd;
				
				HalfYearCalendarDays1 = HalfYearCalendarDays1 + CalendarDays;
				WorkingTime40HalfYear1 = WorkingTime40HalfYear1 + WorkingTime40;
				WorkingTime36HalfYear1 = WorkingTime36HalfYear1 + WorkingTime36;
				WorkingTime24HalfYear1 = WorkingTime24HalfYear1 + WorkingTime24;
				WeekdaysHalfYear1	 = WeekdaysHalfYear1 	+ WorkDays;
				WeekendHalfYear1	 = WeekendHalfYear1	+ WeekEnd;
				
				CalendarDaysOfYear = CalendarDaysOfYear + CalendarDays;
				WorkingTime40Year = WorkingTime40Year + WorkingTime40;
				WorkingTime36Year = WorkingTime36Year + WorkingTime36;
				WorkingTime24Year = WorkingTime24Year + WorkingTime24;
				WorkingDaysOfYear	 = WorkingDaysOfYear 	+ WorkDays;
				WeekendYear	 = WeekendYear	+ WeekEnd;
				
				ColumnOfMonth = Template.GetArea("ColumnOfMonth");
				ColumnOfMonth.Parameters.WeekEnd = WeekEnd;
				ColumnOfMonth.Parameters.WorkingTime40 	= WorkingTime40;
				ColumnOfMonth.Parameters.WorkingTime36 	= WorkingTime36;
				ColumnOfMonth.Parameters.WorkingTime24 	= WorkingTime24;
				ColumnOfMonth.Parameters.CalendarDays 	= CalendarDays;
				ColumnOfMonth.Parameters.WorkDays 		= WorkDays;
				ColumnOfMonth.Parameters.NameOfMonth 		= Format(Date(YearNumber, SelectionByMonth.MonthCalendar, 1), "DF='MMMM'");
				SpreadsheetDocument.Join(ColumnOfMonth);
				
			EndDo;
			ColumnOfMonth = Template.GetArea("ColumnOfMonth");
			ColumnOfMonth.Parameters.WeekEnd 	= WeekendQ;
			ColumnOfMonth.Parameters.WorkingTime40 	= WorkingTime40Kv;
			ColumnOfMonth.Parameters.WorkingTime36 	= WorkingTime36Kv;
			ColumnOfMonth.Parameters.WorkingTime24 	= WorkingTime42Kv;
			ColumnOfMonth.Parameters.CalendarDays 	= CalendarDaysQ;
			ColumnOfMonth.Parameters.WorkDays 		= WorkingDaysQr;
			ColumnOfMonth.Parameters.NameOfMonth 		= StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='%1 Quarter';ru='%1 квартал'"), SelectionByQuarter.QuarterWeek);
			SpreadsheetDocument.Join(ColumnOfMonth);
			
			If SelectionByQuarter.QuarterWeek = 2 
				Or SelectionByQuarter.QuarterWeek = 4 Then 
				ColumnOfMonth = Template.GetArea("ColumnOfMonth");
				ColumnOfMonth.Parameters.WeekEnd 	= WeekendHalfYear1;
				ColumnOfMonth.Parameters.WorkingTime40 	= WorkingTime40HalfYear1;
				ColumnOfMonth.Parameters.WorkingTime36 	= WorkingTime36HalfYear1;
				ColumnOfMonth.Parameters.WorkingTime24 	= WorkingTime24HalfYear1;
				ColumnOfMonth.Parameters.CalendarDays 	= HalfYearCalendarDays1;
				ColumnOfMonth.Parameters.WorkDays 		= WeekdaysHalfYear1;
				ColumnOfMonth.Parameters.NameOfMonth 		= StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='%1 half-year';ru='%1 полугодие'"), SelectionByQuarter.QuarterWeek / 2);
				SpreadsheetDocument.Join(ColumnOfMonth);
			EndIf;
			
		EndDo;
		
		ColumnOfMonth = Template.GetArea("ColumnOfMonth");
		ColumnOfMonth.Parameters.WeekEnd 	= WeekendYear;
		ColumnOfMonth.Parameters.WorkingTime40 	= WorkingTime40Year;
		ColumnOfMonth.Parameters.WorkingTime36 	= WorkingTime36Year;
		ColumnOfMonth.Parameters.WorkingTime24 	= WorkingTime24Year;
		ColumnOfMonth.Parameters.CalendarDays 	= CalendarDaysOfYear;
		ColumnOfMonth.Parameters.WorkDays 		= WorkingDaysOfYear;
		ColumnOfMonth.Parameters.NameOfMonth 		= StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='%1 year';ru='%1 год'"), Format(SelectionByYear.YearCalendar, "NG="));
		SpreadsheetDocument.Join(ColumnOfMonth);
		
	EndDo;
	
	ColumnOfMonth = Template.GetArea("MonthlyAverage");
	ColumnOfMonth.Parameters.WorkingTime40 	= WorkingTime40Year;
	ColumnOfMonth.Parameters.WorkingTime36 	= WorkingTime36Year;
	ColumnOfMonth.Parameters.WorkingTime24 	= WorkingTime24Year;
	ColumnOfMonth.Parameters.NameOfMonth 		= StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='%1 year';ru='%1 год'"), Format(YearNumber, "NG="));
	SpreadsheetDocument.Put(ColumnOfMonth);
	
	ColumnOfMonth = Template.GetArea("ColumnOfMonthAvg");
	ColumnOfMonth.Parameters.WorkingTime40 	= Format(WorkingTime40Year / 12, "NFD=2; NG=0");
	ColumnOfMonth.Parameters.WorkingTime36 	= Format(WorkingTime36Year / 12, "NFD=2; NG=0");
	ColumnOfMonth.Parameters.WorkingTime24 	= Format(WorkingTime24Year / 12, "NFD=2; NG=0");
	ColumnOfMonth.Parameters.NameOfMonth 		= NStr("en='Average monthly quantity';ru='Среднемесячное количество'");
	SpreadsheetDocument.Join(ColumnOfMonth);
	
	Return SpreadsheetDocument;
	
EndFunction

#EndRegion

#EndIf