
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// The procedure generates the period of work schedule.
//
&AtClient
Procedure GenerateScheduledWorksPeriod()
	
	If WorksScheduleRadioButton = "Week" Then
		
		CalendarDateBegin = BegOfWeek(CalendarDate);
		CalendarDateEnd = EndOfWeek(CalendarDate);
		
		If Month(CalendarDateBegin) = Month(CalendarDateEnd) Then
			
			DayOfScheduleBegin = Format(CalendarDateBegin, "DF=dd");
			DayOfScheduleEnd = Format(CalendarDateEnd, "DF=dd");
			MonthOfScheduleEnd = Format(CalendarDateEnd, "DF=MMM");
			YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
			PeriodPresentation = DayOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + ", " + YearOfSchedule;
			
		Else
			
			DayOfScheduleBegin = Format(CalendarDateBegin, "DF=dd");
			MonthOfScheduleBegin = Format(CalendarDateBegin, "DF=MMM");
			DayOfScheduleEnd = Format(CalendarDateEnd, "DF=dd");
			MonthOfScheduleEnd = Format(CalendarDateEnd, "DF=MMM");
			
			If Year(CalendarDateBegin) = Year(CalendarDateEnd) Then
				YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
				PeriodPresentation = DayOfScheduleBegin + " " + MonthOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + ", " + YearOfSchedule;
			Else
				YearOfScheduleBegin = Format(Year(CalendarDateBegin), "NG=0");
				YearOfScheduleEnd = Format(Year(CalendarDateEnd), "NG=0");
				PeriodPresentation = DayOfScheduleBegin + " " + MonthOfScheduleBegin + " " + YearOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + " " + YearOfScheduleEnd;
				
			EndIf;
			
		EndIf;
		
	ElsIf WorksScheduleRadioButton = "Month" Then
		
		CalendarDateBegin = BegOfMonth(CalendarDate);
		CalendarDateEnd = EndOfMonth(CalendarDate);
		
		MonthOfSchedule = Format(CalendarDateBegin, "DF=MMM");
		YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
		PeriodPresentation = MonthOfSchedule + " " + YearOfSchedule;
		
	ElsIf WorksScheduleRadioButton= "4days" Then
		
		CalendarDateBegin = BegOfDay(CalendarDate);
		CalendarDateEnd = EndOfDay(CalendarDate) + 3 *60 * 60 * 24;
		
		If Month(CalendarDateBegin) = Month(CalendarDateEnd) Then
			
			DayOfScheduleBegin = Format(CalendarDateBegin, "DF=dd");
			WeekDayOfScheduleBegin = SmallBusinessClient.GetPresentationOfWeekDay(CalendarDateBegin);
			DayOfScheduleEnd = Format(CalendarDateEnd, "DF=dd");
			WeekDayOfScheduleEnd = SmallBusinessClient.GetPresentationOfWeekDay(CalendarDateBegin);
			
			MonthOfSchedule = Format(CalendarDateBegin, "DF=MMM");
			YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
			
			PeriodPresentation = WeekDayOfScheduleBegin + " " + DayOfScheduleBegin + " - " + WeekDayOfScheduleEnd + " " + DayOfScheduleEnd + " " + MonthOfSchedule + ", " + YearOfSchedule;
			
		Else
			
			DayOfScheduleBegin = Format(CalendarDateBegin, "DF=dd");
			WeekDayOfScheduleBegin = SmallBusinessClient.GetPresentationOfWeekDay(CalendarDateBegin);
			MonthOfScheduleBegin = Format(CalendarDateBegin, "DF=MMM");
			DayOfScheduleEnd = Format(CalendarDateEnd, "DF=dd");
			WeekDayOfScheduleEnd = SmallBusinessClient.GetPresentationOfWeekDay(CalendarDateEnd);
			MonthOfScheduleEnd = Format(CalendarDateEnd, "DF=MMM");
			
			If Year(CalendarDateBegin) = Year(CalendarDateEnd) Then
				YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
				PeriodPresentation = WeekDayOfScheduleBegin + " " + DayOfScheduleBegin + " " + MonthOfScheduleBegin + " - " + WeekDayOfScheduleEnd + " " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + ", " + YearOfSchedule;
			Else
				YearOfScheduleBegin = Format(Year(CalendarDateBegin), "NG=0");
				YearOfScheduleEnd = Format(Year(CalendarDateEnd), "NG=0");
				PeriodPresentation = WeekDayOfScheduleBegin + " " + DayOfScheduleBegin + " " + MonthOfScheduleBegin + " " + YearOfScheduleBegin + " - " + WeekDayOfScheduleEnd + " " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + " " + YearOfScheduleEnd;
				
			EndIf;
			
		EndIf;
		
	Else // DayPeriod
		
		CalendarDateBegin = BegOfDay(CalendarDate);
		CalendarDateEnd = EndOfDay(CalendarDate);
		
		DayOfSchedule = Format(CalendarDateBegin, "DF=dd");
		MonthOfSchedule = Format(CalendarDateBegin, "DF=MMM");
		YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
		WeekDayOfSchedule = SmallBusinessClient.GetPresentationOfWeekDay(CalendarDateBegin);
		
		PeriodPresentation = WeekDayOfSchedule + " " + DayOfSchedule + " " + MonthOfSchedule + " " + YearOfSchedule;
		
	EndIf;
	
EndProcedure // GenerateWorkSchedulePeriod()

// The function returns the list of resources by resource kind.
//
&AtServer
Function GetListOfResourcesByResourceKind()
	
	ListResourcesKinds = New ValueList;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EnterpriseResourcesKinds.EnterpriseResource AS EnterpriseResource
	|FROM
	|	InformationRegister.EnterpriseResourcesKinds AS EnterpriseResourcesKinds
	|WHERE
	|	EnterpriseResourcesKinds.EnterpriseResourceKind = &EnterpriseResourceKind";
	
	Query.SetParameter("EnterpriseResourceKind", FilterResourceKind);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return ListResourcesKinds;
	EndIf;
	
	Selection = Result.Select();
	While Selection.Next() Do
		ListResourcesKinds.Add(Selection.EnterpriseResource);
	EndDo;
	
	Return ListResourcesKinds;
	
EndFunction // GetResourcesListByResourceKind()

// The function returns the list of resources for fast selection.
//
&AtServer
Function GetListOfResourcesForFilter()
	
	If ValueIsFilled(FilterKeyResource) Then
		ListResourcesKinds = New ValueList;
		ListResourcesKinds.Add(FilterKeyResource);
	ElsIf ValueIsFilled(FilterResourceKind) Then
		ListResourcesKinds = GetListOfResourcesByResourceKind();
	Else
		ListResourcesKinds = Undefined;
	EndIf;
	
	Return ListResourcesKinds;
	
EndFunction // GetResourcesListForFilter()

// The function returns the parameters to open the application.
//
&AtClient
Function GetOrderOpeningParameters(DayOnly = False)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("TimeLimitFrom", TimeLimitFrom);
	OpenParameters.Insert("TimeLimitTo", TimeLimitTo);
	OpenParameters.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	OpenParameters.Insert("FilterKeyResource", FilterKeyResource);
	OpenParameters.Insert("FilterResourceKind", FilterResourceKind);
	
	If DayOnly Then
		OpenParameters.Insert("DayOnly", CalendarDateBegin);
	Else
		ArrayDetails = New Array;
		CurrentCalendarArea = Items.ResourcesImport.CurrentArea;
		FirstRow = CurrentCalendarArea.Top;
		LastRow = CurrentCalendarArea.Bottom;
		LastColumn = CurrentCalendarArea.Right;
		While FirstRow <= LastRow Do
			FirstColumn = CurrentCalendarArea.Left;
			While FirstColumn <= LastColumn Do
				CellDetails = ResourcesImport.Area(FirstRow, FirstColumn).Details;
				If TypeOf(CellDetails) = Type("Structure") Then
					ArrayDetails.Add(CellDetails);
				EndIf;
				FirstColumn = FirstColumn + 1;
			EndDo;
			FirstRow = FirstRow + 1;
		EndDo;
		
		OpenParameters.Insert("Details", ArrayDetails);
	EndIf;
	
	Return OpenParameters;
	
EndFunction // GetOrderOpeningParameters()

////////////////////////////////////////////////////////////////////////////////
// LIST (SCHEDULE CHART)

// The procedure updates list data.
//
&AtServer
Procedure UpdateListAtServer()
	
	Items.List.Refresh();
	
EndProcedure // UpdateListOnServer()

// Procedure updates data in the list table.
//
&AtServer
Procedure UpdateScheduleChartList()
	
	AvailableDocumentsList = New ValueList;
	If ShowJobOrders Then
		AvailableDocumentsList.Add(Type("DocumentRef.CustomerOrder"));
	EndIf;
	If ShowProductionOrders Then
		AvailableDocumentsList.Add(Type("DocumentRef.ProductionOrder"));
	EndIf;
	SmallBusinessClientServer.SetListFilterItem(List, "Type", AvailableDocumentsList, True, DataCompositionComparisonType.InList);
	
	SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	SmallBusinessClientServer.SetListFilterItem(List, "KeyResources", TrimAll(FilterKeyResource), ValueIsFilled(FilterKeyResource), DataCompositionComparisonType.Contains);
	SmallBusinessClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
	SetPeriodOfListFilter();
	
EndProcedure // UpdateScheduleChartList()

// The procedure sets the filter by period for the list.
//
&AtServer
Procedure SetPeriodOfListFilter()
	
	List.Parameters.SetParameterValue("StartDate", CalendarDateBegin);
	List.Parameters.SetParameterValue("EndDate", CalendarDateEnd);
	
EndProcedure // SetListFilterPeriod()

///////////////////////////////////////////////////////////////////////////////
// CHART (SCHEDULE CHART)

// The procedure generates the time scale for Gantt chart.
//
&AtServer
Procedure GenerateTimeScaleOfGanttChart(GanttChart)
	
	// Setting the time scale.
	For n = 0 To GanttChart.PlotArea.TimeScale.Items.Count() - 1 Do
		If GanttChart.PlotArea.TimeScale.Items.Count() = 1 Then
			Break;
		EndIf;
		DeletedScaleLine = GanttChart.PlotArea.TimeScale.Items[n];
		If DeletedScaleLine.Unit <> TimeScaleUnitType.Day Then
			GanttChart.PlotArea.TimeScale.Items.Delete(DeletedScaleLine);
		EndIf;
	EndDo;
	
	NonWorkingTimeColor = StyleColors.WorktimeCompletelyBusy;
	DayOffColor = StyleColors.NonWorkingTimeDayOff;
	
	If WorksScheduleRadioButton = "Week" Then
		
		GanttChart.ScaleKeeping = GanttChartScaleKeeping.Period;
		GanttChart.PeriodicVariantUnit = TimeScaleUnitType.Day;
		GanttChart.PeriodicVariantRepetition = 5;
		
		GanttChart.SetWholeInterval(CalendarDateBegin, CalendarDateEnd);
		
		GanttChart.BackgroundIntervals.Clear();
		
		TimeScaleItem = GanttChart.PlotArea.TimeScale.Items[0];
		TimeScaleItem.Format = "DF=""dd ddd""";
		
		ScaleRepetitionFactor = 0;
		While ScaleRepetitionFactor <> 7 Do
			
			If ValueIsFilled(TimeLimitFrom) Then
				IntervalBeginBackground = CalendarDateBegin + ScaleRepetitionFactor * 24 * 60 * 60;
				BackgroundIntervalEnd = CalendarDateBegin + ScaleRepetitionFactor * 24 * 60 * 60 + Hour(TimeLimitFrom) * 60 *60 + Minute(TimeLimitFrom) * 60;
				NewIntervalBackground = GanttChart.BackgroundIntervals.Add(IntervalBeginBackground, BackgroundIntervalEnd);
				NewIntervalBackground.Color = NonWorkingTimeColor;
			EndIf;
			
			If ValueIsFilled(TimeLimitTo) Then
				IntervalBeginBackground = CalendarDateBegin + ScaleRepetitionFactor * 24 * 60 * 60 + Hour(TimeLimitTo) * 60 *60 + Minute(TimeLimitTo) * 60;
				BackgroundIntervalEnd = CalendarDateBegin + ScaleRepetitionFactor * 24 * 60 * 60;
				NewIntervalBackground = GanttChart.BackgroundIntervals.Add(IntervalBeginBackground, EndOfDay(BackgroundIntervalEnd));
				NewIntervalBackground.Color = NonWorkingTimeColor;
			EndIf;
			
			IntervalBeginBackground = CalendarDateBegin + ScaleRepetitionFactor * 24 * 60 * 60;
			If WeekDay(IntervalBeginBackground) = 6 OR WeekDay(IntervalBeginBackground) = 7 Then
				IntervalBeginBackground = CalendarDateBegin + ScaleRepetitionFactor * 24 * 60 * 60 + Hour(TimeLimitFrom) * 60 *60 + Minute(TimeLimitFrom) * 60;
				BackgroundIntervalEnd = CalendarDateBegin + ScaleRepetitionFactor * 24 * 60 * 60 + Hour(TimeLimitTo) * 60 *60 + Minute(TimeLimitTo) * 60;
				NewIntervalBackground = GanttChart.BackgroundIntervals.Add(IntervalBeginBackground, EndOfDay(BackgroundIntervalEnd));
				NewIntervalBackground.Color = DayOffColor;
			EndIf;
			
			ScaleRepetitionFactor = ScaleRepetitionFactor +1;
			
		EndDo;
		
		NewTimeScaleItem = GanttChart.PlotArea.TimeScale.Items.Add();
		NewTimeScaleItem.Unit = TimeScaleUnitType.Week;
		NewTimeScaleItem.Repetition = 1;
		GanttChart.PlotArea.TimeScale.Items.Move(NewTimeScaleItem, -1);
		
	ElsIf WorksScheduleRadioButton = "Month" Then
		
		GanttChart.ScaleKeeping = GanttChartScaleKeeping.Period;
		GanttChart.PeriodicVariantUnit = TimeScaleUnitType.Day;
		GanttChart.PeriodicVariantRepetition = 15;
		
		GanttChart.SetWholeInterval(CalendarDateBegin, CalendarDateEnd);
		
		GanttChart.BackgroundIntervals.Clear();
		
		TimeScaleItem = GanttChart.PlotArea.TimeScale.Items[0];
		TimeScaleItem.Format = "DF=""dd ddd""";
		
		IntervalBeginBackground = CalendarDateBegin;
		While IntervalBeginBackground < CalendarDateEnd Do
			
			If WeekDay(IntervalBeginBackground) = 6 OR WeekDay(IntervalBeginBackground) = 7 Then
				NewIntervalBackground = GanttChart.BackgroundIntervals.Add(IntervalBeginBackground, EndOfDay(IntervalBeginBackground));
				NewIntervalBackground.Color = DayOffColor;
			EndIf;
			
			IntervalBeginBackground = IntervalBeginBackground + 24 * 60 * 60;
			
		EndDo;
		
		NewTimeScaleItem = GanttChart.PlotArea.TimeScale.Items.Add();
		NewTimeScaleItem.Unit = TimeScaleUnitType.Month;
		NewTimeScaleItem.Repetition = 1;
		GanttChart.PlotArea.TimeScale.Items.Move(NewTimeScaleItem, -1);
		
	ElsIf WorksScheduleRadioButton= "4days" Then
		
		GanttChart.ScaleKeeping = GanttChartScaleKeeping.Period;
		GanttChart.PeriodicVariantUnit = TimeScaleUnitType.Day;
		GanttChart.PeriodicVariantRepetition = 1;
		
		GanttChart.SetWholeInterval(CalendarDateBegin, CalendarDateEnd);
		
		GanttChart.BackgroundIntervals.Clear();
		
		TimeScaleItem = GanttChart.PlotArea.TimeScale.Items[0];
		TimeScaleItem.Format = "DF=""dd MMMM yyyy dddd""";
		
		ScaleRepetitionFactor = 0;
		While ScaleRepetitionFactor <> 4 Do
			
			If ValueIsFilled(TimeLimitFrom) Then
				IntervalBeginBackground = CalendarDateBegin + ScaleRepetitionFactor * 24 * 60 * 60;
				BackgroundIntervalEnd = CalendarDateBegin + ScaleRepetitionFactor * 24 * 60 * 60 + Hour(TimeLimitFrom) * 60 *60 + Minute(TimeLimitFrom) * 60;
				NewIntervalBackground = GanttChart.BackgroundIntervals.Add(IntervalBeginBackground, BackgroundIntervalEnd);
				NewIntervalBackground.Color = NonWorkingTimeColor;
			EndIf;
			
			If ValueIsFilled(TimeLimitTo) Then
				IntervalBeginBackground = CalendarDateBegin + ScaleRepetitionFactor * 24 * 60 * 60 + Hour(TimeLimitTo) * 60 *60 + Minute(TimeLimitTo) * 60;
				BackgroundIntervalEnd = CalendarDateBegin + ScaleRepetitionFactor * 24 * 60 * 60;
				NewIntervalBackground = GanttChart.BackgroundIntervals.Add(IntervalBeginBackground, EndOfDay(BackgroundIntervalEnd));
				NewIntervalBackground.Color = NonWorkingTimeColor;
			EndIf;
			
			IntervalBeginBackground = CalendarDateBegin + ScaleRepetitionFactor * 24 * 60 * 60;
			If WeekDay(IntervalBeginBackground) = 6 OR WeekDay(IntervalBeginBackground) = 7 Then
				IntervalBeginBackground = CalendarDateBegin + ScaleRepetitionFactor * 24 * 60 * 60 + Hour(TimeLimitFrom) * 60 *60 + Minute(TimeLimitFrom) * 60;
				BackgroundIntervalEnd = CalendarDateBegin + ScaleRepetitionFactor * 24 * 60 * 60 + Hour(TimeLimitTo) * 60 *60 + Minute(TimeLimitTo) * 60;
				NewIntervalBackground = GanttChart.BackgroundIntervals.Add(IntervalBeginBackground, EndOfDay(BackgroundIntervalEnd));
				NewIntervalBackground.Color = DayOffColor;
			EndIf;
			
			ScaleRepetitionFactor = ScaleRepetitionFactor +1;
			
		EndDo;
		
		NewTimeScaleItem = GanttChart.PlotArea.TimeScale.Items.Add();
		NewTimeScaleItem.Unit = TimeScaleUnitType.Hour;
		NewTimeScaleItem.Repetition = 1;
		NewTimeScaleItem.Format = "DF=""HH""";
		
	Else // DayPeriod
		
		GanttChart.ScaleKeeping=GanttChartScaleKeeping.Auto;
		GanttChart.SetWholeInterval(CalendarDateBegin, CalendarDateEnd);
		
		GanttChart.BackgroundIntervals.Clear();
		
		TimeScaleItem = GanttChart.PlotArea.TimeScale.Items[0];
		TimeScaleItem.Format = "DF=""dd MMMM yyyy dddd""";
		
		If ValueIsFilled(TimeLimitFrom) Then
			IntervalBeginBackground = CalendarDateBegin;
			BackgroundIntervalEnd = CalendarDateBegin + Hour(TimeLimitFrom) * 60 *60 + Minute(TimeLimitFrom) * 60;
			NewIntervalBackground = GanttChart.BackgroundIntervals.Add(IntervalBeginBackground, BackgroundIntervalEnd);
			NewIntervalBackground.Color = NonWorkingTimeColor;
		EndIf;
		
		If ValueIsFilled(TimeLimitTo) Then
			IntervalBeginBackground = CalendarDateBegin + Hour(TimeLimitTo) * 60 *60 + Minute(TimeLimitTo) * 60;
			BackgroundIntervalEnd = CalendarDateEnd;
			NewIntervalBackground = GanttChart.BackgroundIntervals.Add(IntervalBeginBackground, BackgroundIntervalEnd);
			NewIntervalBackground.Color = NonWorkingTimeColor;
		EndIf;
		
		If WeekDay(CalendarDateBegin) = 6 OR WeekDay(CalendarDateBegin) = 7 Then
			IntervalBeginBackground = CalendarDateBegin + Hour(TimeLimitFrom) * 60 *60 + Minute(TimeLimitFrom) * 60;
			BackgroundIntervalEnd = CalendarDateBegin + Hour(TimeLimitTo) * 60 *60 + Minute(TimeLimitTo) * 60;
			NewIntervalBackground = GanttChart.BackgroundIntervals.Add(IntervalBeginBackground, EndOfDay(BackgroundIntervalEnd));
			NewIntervalBackground.Color = DayOffColor;
		EndIf;
		
		NewTimeScaleItem = GanttChart.PlotArea.TimeScale.Items.Add();
		NewTimeScaleItem.Unit = TimeScaleUnitType.Hour;
		NewTimeScaleItem.Repetition = 1;
		NewTimeScaleItem.Format = "DF=""HH""";
		
	EndIf;
	
EndProcedure // GenerateGanttDiagramTimeScale()

// The procedure updates data of schedule chart diagram.
//
&AtServer
Procedure UpdateScheduleChart()
	
	// Initialization.
	GanttChartPlanLine.ShowLegend = False;
	GanttChartPlanLine.RefreshEnabled = False;
	
	GanttChartPlanLine.Clear();
	
	GanttChartPlanLine.AutoDetectWholeInterval = False;
	GanttChartPlanLine.ValueTextRepresentation = GanttChartValueTextRepresentation.Right;
	
	GenerateTimeScaleOfGanttChart(GanttChartPlanLine);
	
	// Filling.
	QueryResult = GetScheduleChart();
	Selection = QueryResult.Select();
	Series = GanttChartPlanLine.Series.Add();
	
	While Selection.Next() Do
		
		DotValue = NStr("en='" + Format(Selection.Start, "DF=""HH:mm""") + " - "
							+ Format(Selection.Finish, "DF=""HH:mm""") + " (# "
							+ ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True) + " dated " 
							+ Format(Selection.Date, "DF=dd.MM.yy") + ") '");
		
		Point = GanttChartPlanLine.SetPoint(DotValue);
		Point.Details = Selection.Ref;
		
		If Selection.Closed Then
			Point.Picture = PictureLib.LockFile;
		Else
			Point.Picture = PictureLib.ReleaseFile;
		EndIf;
		
		ValueOfOrder = GanttChartPlanLine.GetValue(Point, Series);
		ValueOfOrder.Edit = False;
		
		Interval = ValueOfOrder.Add();
		Interval.Details = Selection.Ref;
		Interval.Begin = Selection.Start;
		Interval.End = Selection.Finish;
		BackColor = Selection.Color.Get();
		If TypeOf(BackColor) = Type("Color") Then
			Interval.Color = BackColor;
		EndIf;
		
		Interval.Value.Text = Selection.Counterparty;
		
		ValueText = NStr("en='ProductsAndServices: " + Selection.ProductsAndServices + "
							|Resources: " + Selection.KeyResources + "
							|Counterparty: " + Selection.Counterparty + "
							|Responsible: " + Selection.Responsible + "
							|Department: " + Selection.Department + "'");
		
		Interval.Text  = ValueText;
		
	EndDo;
	
	GanttChartPlanLine.RefreshEnabled = True;
	
EndProcedure // UpdateDiagramScheduleChart()

// The function returns the query result.
//
&AtServer
Function GetScheduleChart()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DocumentJournalResourcesPlanningDocuments.Ref,
	|	DocumentJournalResourcesPlanningDocuments.Date,
	|	DocumentJournalResourcesPlanningDocuments.Number,
	|	DocumentJournalResourcesPlanningDocuments.OperationKind,
	|	DocumentJournalResourcesPlanningDocuments.Closed,
	|	DocumentJournalResourcesPlanningDocuments.OrderState.Color AS Color,
	|	DocumentJournalResourcesPlanningDocuments.Start AS Start,
	|	DocumentJournalResourcesPlanningDocuments.Finish AS Finish,
	|	DocumentJournalResourcesPlanningDocuments.ProductsAndServices,
	|	DocumentJournalResourcesPlanningDocuments.KeyResources,
	|	CASE
	|		WHEN DocumentJournalResourcesPlanningDocuments.Type = Type(Document.ProductionOrder)
	|			THEN DocumentJournalResourcesPlanningDocuments.CustomerOrder.Counterparty
	|		ELSE DocumentJournalResourcesPlanningDocuments.Counterparty
	|	END AS Counterparty,
	|	DocumentJournalResourcesPlanningDocuments.Department,
	|	DocumentJournalResourcesPlanningDocuments.Responsible
	|FROM
	|	DocumentJournal.ResourcesPlanningDocuments AS DocumentJournalResourcesPlanningDocuments
	|WHERE
	|	CASE
	|			WHEN DocumentJournalResourcesPlanningDocuments.Type = Type(Document.CustomerOrder)
	|				THEN CASE
	|						WHEN DocumentJournalResourcesPlanningDocuments.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|							THEN TRUE
	|						ELSE FALSE
	|					END
	|			ELSE TRUE
	|		END
	|	AND (&StartDate between DocumentJournalResourcesPlanningDocuments.Start AND DocumentJournalResourcesPlanningDocuments.Finish
	|			OR &EndDate between DocumentJournalResourcesPlanningDocuments.Start AND DocumentJournalResourcesPlanningDocuments.Finish
	|			OR DocumentJournalResourcesPlanningDocuments.Start between &StartDate AND &EndDate
	|			OR DocumentJournalResourcesPlanningDocuments.Finish between &StartDate AND &EndDate)
	|	AND (&FilterCounterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|			OR CASE
	|				WHEN DocumentJournalResourcesPlanningDocuments.Type = Type(Document.ProductionOrder)
	|					THEN DocumentJournalResourcesPlanningDocuments.CustomerOrder.Counterparty = &FilterCounterparty
	|				ELSE DocumentJournalResourcesPlanningDocuments.Counterparty = &FilterCounterparty
	|			END)
	|	AND (&FilterKeyResource = """"
	|			OR DocumentJournalResourcesPlanningDocuments.KeyResources LIKE &FilterKeyResource)
	|	AND (&FilterResponsible = VALUE(Catalog.Employees.EmptyRef)
	|			OR DocumentJournalResourcesPlanningDocuments.Responsible = &FilterResponsible)
	|	AND CASE
	|			WHEN DocumentJournalResourcesPlanningDocuments.Type = Type(Document.ProductionOrder)
	|				THEN &ShowProductionOrders
	|			ELSE &ShowJobOrders
	|		END
	|	AND DocumentJournalResourcesPlanningDocuments.Posted
	|	AND ((NOT DocumentJournalResourcesPlanningDocuments.Closed)
	|			OR DocumentJournalResourcesPlanningDocuments.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	Start,
	|	Finish";
	
	Query.SetParameter("StartDate", CalendarDateBegin);
	Query.SetParameter("EndDate", CalendarDateEnd);
	Query.SetParameter("FilterCounterparty", FilterCounterparty);
	Query.SetParameter("FilterKeyResource", TrimAll(FilterKeyResource));
	Query.SetParameter("FilterResponsible", FilterResponsible);
	Query.SetParameter("ShowJobOrders", ShowJobOrders);
	Query.SetParameter("ShowProductionOrders", ShowProductionOrders);
	
	Return Query.Execute();
	
EndFunction // GetScheduleChart()

////////////////////////////////////////////////////////////////////////////////
// CALENDAR (RESOURCES UPLOAD)

// The procedure generates the schedule of resources import.
//
&AtServer
Procedure UpdateCalendar()
	
	Spreadsheet = ResourcesImport;
	Spreadsheet.Clear();
	
	SelectionResources = Catalogs.KeyResources.Select();
	If SelectionResources.Next() Then
		
		ResourcesList = GetListOfResourcesForFilter();
		
		If WorksScheduleRadioButton = "Week" Then
			
			UpdateCalendarWeekPeriod(Spreadsheet, ResourcesList);
			
		ElsIf WorksScheduleRadioButton = "Month" Then
			
			UpdateCalendarMonthPeriod(Spreadsheet, ResourcesList);
			
		ElsIf WorksScheduleRadioButton= "4days" Then
			
			UpdateCalendarDayPeriod(Spreadsheet, ResourcesList, True);
			
		Else // DayPeriod
			
			UpdateCalendarDayPeriod(Spreadsheet, ResourcesList);
			
		EndIf;
		
	Else
		
		ShowAssistant(Spreadsheet);
		
	EndIf;
	
	Spreadsheet.ShowGrid = False;
	Spreadsheet.Protection = False;
	Spreadsheet.ReadOnly = True;
	
EndProcedure // UpdateCalendar()

// The procedure generates the schedule of resources import - week period.
//
&AtServer
Procedure UpdateCalendarWeekPeriod(Spreadsheet, ResourcesList)
	
	ScaleTemplate = DataProcessors.Scheduler.GetTemplate("WeekScale");
	
	// Displaying the scale.
	ScaleBegin = 2;
	ShiftByScale = 2;
	DayCellHeight = 6;
	
	ArrayOfCoordinates = New Array();
	ScaleArea = ScaleTemplate.Area("RowScale|ColumnScale");
	Spreadsheet.InsertArea(ScaleArea, Spreadsheet.Area(ScaleArea.Name));
	
	// Mo.
	CalendarDateMo = CalendarDateBegin;
	MoCoordinates = "R" + ShiftByScale + "C" + ScaleBegin;
	CoordsTextMo = "R" + (ShiftByScale + 1) + "C" + ScaleBegin;
	MoDetailsCoordinates = "R" + ShiftByScale + "C" + ScaleBegin + ":R" + (DayCellHeight + 1) + "C" + (ScaleBegin + 1);
	Spreadsheet.Area(MoCoordinates).Text = Format(CalendarDateMo, "DF=""d MMMM""");
	Spreadsheet.Area(MoDetailsCoordinates).Details = GetDetailsOfWeekMonthCell(CalendarDateMo);
	
	// Tu.
	CalendarDateTu = CalendarDateMo + 24 * 60 * 60;
	TuCoordinates = "R" + ShiftByScale + "C" + (ScaleBegin + 2);
	TuTextCoordinates = "R" + (ShiftByScale + 1) + "C" + (ScaleBegin + 2);
	TuDetailsCoordinates = "R" + ShiftByScale + "C" + (ScaleBegin + 2) + ":R" + (DayCellHeight + 1) + "C" + (ScaleBegin + 3);
	Spreadsheet.Area(TuCoordinates).Text = Format(CalendarDateTu, "DF=""d MMMM""");
	Spreadsheet.Area(TuDetailsCoordinates).Details = GetDetailsOfWeekMonthCell(CalendarDateTu);
	
	// We.
	CalendarDateWe = CalendarDateTu + 24 * 60 * 60;
	WeCoordinates = "R" + ShiftByScale + "C" + (ScaleBegin + 4);
	CoordsTextWe = "R" + (ShiftByScale + 1) + "C" + (ScaleBegin + 4);
	CoordsDetailsWe = "R" + ShiftByScale + "C" + (ScaleBegin + 4) + ":R" + (DayCellHeight + 1) + "C" + (ScaleBegin + 5);
	Spreadsheet.Area(WeCoordinates).Text = Format(CalendarDateWe, "DF=""d MMMM""");
	Spreadsheet.Area(CoordsDetailsWe).Details = GetDetailsOfWeekMonthCell(CalendarDateWe);
	
	// Th.
	CalendarDateTh = CalendarDateWe + 24 * 60 * 60;
	CoordinatesTh = "R" + (ShiftByScale + DayCellHeight) + "C" + ScaleBegin;
	ThTextCoordinates = "R" + (ShiftByScale + DayCellHeight + 1) + "C" + ScaleBegin;
	ThDetailsCoordinates = "R" + (ShiftByScale + DayCellHeight) + "C" + ScaleBegin + ":R" + (2 * DayCellHeight + 1) + "C" + (ScaleBegin + 1);
	Spreadsheet.Area(CoordinatesTh).Text = Format(CalendarDateTh, "DF=""d MMMM""");
	Spreadsheet.Area(ThDetailsCoordinates).Details = GetDetailsOfWeekMonthCell(CalendarDateTh);
	
	// Fr.
	CoordsFr = "R" + (ShiftByScale + DayCellHeight) + "C" + (ScaleBegin + 2);
	FrTextCoordinates = "R" + (ShiftByScale + DayCellHeight + 1) + "C" + (ScaleBegin + 2);
	CoordinatesDetailsFr = "R" + (ShiftByScale + DayCellHeight) + "C" + (ScaleBegin + 2) + ":R" + (2 * DayCellHeight + 1) + "C" + (ScaleBegin + 3);
	CalendarDateFr = CalendarDateTh + 24 * 60 * 60;
	Spreadsheet.Area(CoordsFr).Text = Format(CalendarDateFr, "DF=""d MMMM""");
	Spreadsheet.Area(CoordinatesDetailsFr).Details = GetDetailsOfWeekMonthCell(CalendarDateFr);
	
	// Sa.
	CalendarDateSut = CalendarDateFr + 24 * 60 * 60;
	SutCoordinates = "R" + (ShiftByScale + DayCellHeight) + "C" + (ScaleBegin + 4);
	SutTextCoordinates = "R" + (ShiftByScale + DayCellHeight + 1) + "C" + (ScaleBegin + 4);
	SutDetailsCoordinates = "R" + (ShiftByScale + DayCellHeight) + "C" + (ScaleBegin + 4) + ":R" + (2 * DayCellHeight + 1) + "C" + (ScaleBegin + 5);
	Spreadsheet.Area(SutCoordinates).Text = Format(CalendarDateSut, "DF=""d MMMM""");
	Spreadsheet.Area(SutDetailsCoordinates).Details = GetDetailsOfWeekMonthCell(CalendarDateSut);
	
	// Su.
	CalendarDateSu = CalendarDateSut + 24 * 60 * 60;
	CoordinatesAll = "R" + (ShiftByScale + DayCellHeight * 2) + "C" + ScaleBegin;
	SuTextCoordinates = "R" + (ShiftByScale + DayCellHeight * 2 + 1) + "C" + ScaleBegin;
	SuDetailsCoordinates = "R" + (ShiftByScale + DayCellHeight * 2) + "C" + ScaleBegin + ":R" + (3 * DayCellHeight + 1) + "C" + (ScaleBegin + 1);
	Spreadsheet.Area(CoordinatesAll).Text = Format(CalendarDateSu, "DF=""d MMMM""");
	Spreadsheet.Area(SuDetailsCoordinates).Details = GetDetailsOfWeekMonthCell(CalendarDateSu);
	
	QueryResult = GetResourcesWorkloadScheduleWeekMonth(ResourcesList, CalendarDateBegin, CalendarDateEnd);
	
	// List of resources.
	SelectionResource = QueryResult[1].Select();
	R = ScaleBegin;
	While SelectionResource.Next() Do
		Spreadsheet.Area(R, 1).Text = SelectionResource.EnterpriseResource;
		Spreadsheet.Area(R, 1).VerticalAlign = VerticalAlign.Center;
		Spreadsheet.Area(R, 1).Details = SelectionResource.EnterpriseResource;
		Spreadsheet.Area(R, 1).RowHeight = 21;
		R = R + 1;
	EndDo;
	
	// Schedule.
	SelectionBeginTime = QueryResult[2].Select(QueryResultIteration.ByGroups, "BeginTime");
	While SelectionBeginTime.Next() Do
		QuantityOfResources = SelectionBeginTime.ResourcesQuant;
		WeekdayInSpreadsheet = WeekDay(SelectionBeginTime.BeginTime);
		ResourcesListOfDay = "" + Chars.LF;
		OrdersList = New Array();
		SelectionResource = SelectionBeginTime.Select(QueryResultIteration.ByGroups, "EnterpriseResource");
		ResourcesCt = 1;
		While SelectionResource.Next() Do
			If ResourcesCt = 8 AND ResourcesCt < QuantityOfResources Then
				ResourcesListOfDay = ResourcesListOfDay + TrimAll(ResourcesCt) + ". " + "Yet..." + Chars.LF;
			ElsIf ResourcesCt <= 8 Then
				ResourcesListOfDay = ResourcesListOfDay + TrimAll(ResourcesCt) + ". " + TrimAll(SelectionResource.EnterpriseResource) + Chars.LF;
			EndIf;
			Selection = SelectionResource.Select();
			While Selection.Next() Do
				OrdersList.Add(Selection.Order);
			EndDo;
			ResourcesCt = ResourcesCt + 1;
		EndDo;
		If WeekdayInSpreadsheet = 1 Then
			DayCoordinates = CoordsTextMo;
			CoordinatesDayDetails = MoDetailsCoordinates;
		ElsIf WeekdayInSpreadsheet = 2 Then
			DayCoordinates = TuTextCoordinates;
			CoordinatesDayDetails = TuDetailsCoordinates;
		ElsIf WeekdayInSpreadsheet = 3 Then
			DayCoordinates = CoordsTextWe;
			CoordinatesDayDetails = CoordsDetailsWe;
		ElsIf WeekdayInSpreadsheet = 4 Then
			DayCoordinates = ThTextCoordinates;
			CoordinatesDayDetails = ThDetailsCoordinates;
		ElsIf WeekdayInSpreadsheet = 5 Then
			DayCoordinates = FrTextCoordinates;
			CoordinatesDayDetails = CoordinatesDetailsFr;
		ElsIf WeekdayInSpreadsheet = 6 Then
			DayCoordinates = SutTextCoordinates;
			CoordinatesDayDetails = SutDetailsCoordinates;
		Else
			DayCoordinates = SuTextCoordinates;
			CoordinatesDayDetails = SuDetailsCoordinates;
		EndIf;
		Spreadsheet.Area(DayCoordinates).Text = ResourcesListOfDay;
		CellDetails = Spreadsheet.Area(CoordinatesDayDetails).Details;
		CellDetails.OrdersList = OrdersList;
	EndDo;
	
	// Initialization of scale sizes.
	Spreadsheet.Area(1,,1,).RowHeight = 16;
	Spreadsheet.Area(,1,,1).ColumnWidth = 25;
	
	TopScale = ScaleBegin;
	BottomScale = ScaleArea.Bottom;
	While TopScale <= BottomScale Do
		Spreadsheet.Area(TopScale, 1).RowHeight = 21;
		TopScale = TopScale + 1;
	EndDo;
	
	Spreadsheet.Area(,ScaleBegin,,ScaleBegin).ColumnWidth = 34;
	Spreadsheet.Area(,ScaleBegin + 1,,ScaleBegin + 1).ColumnWidth = 5;
	Spreadsheet.Area(,ScaleBegin + 2,,ScaleBegin + 2).ColumnWidth = 34;
	Spreadsheet.Area(,ScaleBegin + 3,,ScaleBegin + 3).ColumnWidth = 5;
	Spreadsheet.Area(,ScaleBegin + 4,,ScaleBegin + 4).ColumnWidth = 34;
	Spreadsheet.Area(,ScaleBegin + 5,,ScaleBegin + 5).ColumnWidth = 5;
	
	Spreadsheet.FixedTop = 1;
	Spreadsheet.FixedLeft = 1;
	
EndProcedure // UpdateCalendarWeekPeriod()

// The procedure generates the schedule of resources import - period month.
//
&AtServer
Procedure UpdateCalendarMonthPeriod(Spreadsheet, ResourcesList)
	
	ScaleTemplate = DataProcessors.Scheduler.GetTemplate("MonthScale");
	
	// Displaying the scale.
	ScaleBegin = 2;
	ShiftByScale = 1;
	DayCellHeight = 5;
	
	ScaleArea = ScaleTemplate.Area("RowScale|ColumnScale");
	Spreadsheet.InsertArea(ScaleArea, Spreadsheet.Area(ScaleArea.Name));
	
	// First day.
	If WeekDay(CalendarDateBegin) > 1 Then
		FirstDateOfMonth = BegOfMonth(CalendarDateBegin) - (WeekDay(CalendarDateBegin) - 1) * 60 * 60 * 24;
	Else
		FirstDateOfMonth = BegOfMonth(CalendarDateBegin);
	EndIf;
	
	// Last day.
	If WeekDay(CalendarDateEnd) < 7 Then
		LastDateOfMonth = EndOfMonth(CalendarDateEnd) + (7 - WeekDay(CalendarDateEnd)) * 60 * 60 * 24;
	Else
		LastDateOfMonth = EndOfMonth(CalendarDateEnd);
	EndIf;
	If WeekDay(CalendarDateBegin) <= 5 Then
		LastDateOfMonth = LastDateOfMonth + 7 * 60 * 60 * 24;
	EndIf;
	
	QueryResult = GetResourcesWorkloadScheduleWeekMonth(ResourcesList, FirstDateOfMonth, LastDateOfMonth);
	
	ScaleStep = 0;
	ScaleLineNumber = 2;
	CoordinatesCorrespondence = New Map;
	While FirstDateOfMonth <= BegOfDay(LastDateOfMonth) Do
		
		DayCoordinates = "R" + (ScaleLineNumber + 1) + "C" + (ScaleBegin + ScaleStep);
		DayDetailsCoordinates = "R" + (ScaleLineNumber + 1) + "C" + (ScaleBegin + ScaleStep) + ":R" + (ScaleLineNumber + DayCellHeight + 1) + "C" + (ScaleBegin + ScaleStep + 1);;
		
		Spreadsheet.Area(DayCoordinates).Text = Format(FirstDateOfMonth, "DF=""d""");
		Spreadsheet.Area(DayDetailsCoordinates).Details = GetDetailsOfWeekMonthCell(FirstDateOfMonth);
		
		CoordinatesCorrespondence.Insert(FirstDateOfMonth, DayDetailsCoordinates);
		
		If BegOfMonth(FirstDateOfMonth) <> BegOfMonth(CalendarDateBegin) Then
			Spreadsheet.Area(DayDetailsCoordinates).TextColor = StyleColors.WorktimeFreeAvailable;
		EndIf;
		
		FirstDateOfMonth = FirstDateOfMonth + 60 * 60 * 24;
		If (ScaleBegin + ScaleStep) = ScaleArea.Right - 1 Then
			ScaleStep = 0;
			ScaleLineNumber = ScaleLineNumber + DayCellHeight + 1;
		Else
			ScaleStep = ScaleStep + 2;
		EndIf;
		
	EndDo;
	
	//List of resources.
	SelectionResource = QueryResult[1].Select();
	R = ScaleBegin + 1;
	While SelectionResource.Next() Do
		Spreadsheet.Area(R, 1).RowHeight = 10;
		Spreadsheet.Area(R + 1, 1).RowHeight = 11;
		Spreadsheet.Area(R + 1, 1).Text = SelectionResource.EnterpriseResource;
		Spreadsheet.Area(R + 1, 1).VerticalAlign = VerticalAlign.Center;
		Spreadsheet.Area(R + 1, 1).Details = SelectionResource.EnterpriseResource;
		R = R + 2;
	EndDo;
	
	// Schedule.
	SelectionBeginTime = QueryResult[2].Select(QueryResultIteration.ByGroups, "BeginTime");
	While SelectionBeginTime.Next() Do
		
		QuantityOfResources = SelectionBeginTime.ResourcesQuant;
		ResourcesListOfDay = "";
		OrdersList = New Array();
		SelectionResource = SelectionBeginTime.Select(QueryResultIteration.ByGroups, "EnterpriseResource");
		ResourcesCt = 1;
		While SelectionResource.Next() Do
			If ResourcesCt = 5 AND ResourcesCt < QuantityOfResources Then
				ResourcesListOfDay = ResourcesListOfDay + TrimAll(ResourcesCt) + ". " + "Yet..." + Chars.LF;
			ElsIf ResourcesCt <= 5 Then
				ResourcesListOfDay = ResourcesListOfDay + TrimAll(ResourcesCt) + ". " + TrimAll(SelectionResource.EnterpriseResource) + Chars.LF;
			EndIf;
			Selection = SelectionResource.Select();
			While Selection.Next() Do
				OrdersList.Add(Selection.Order);
			EndDo;
			ResourcesCt = ResourcesCt + 1;
		EndDo;
		
		DayDetailsCoordinates = CoordinatesCorrespondence.Get(SelectionBeginTime.BeginTime);
		If DayDetailsCoordinates <> Undefined Then
			DayArea = Spreadsheet.Area(DayDetailsCoordinates);
			CellDetails = DayArea.Details;
			CellDetails.OrdersList = OrdersList;
			Spreadsheet.Area(DayArea.Top + 1, DayArea.Left, DayArea.Bottom, DayArea.Right).Text = ResourcesListOfDay;
		EndIf;
		
	EndDo;
	
	// Initialization of scale sizes.
	Spreadsheet.Area(1,,1,).RowHeight = 8;
	Spreadsheet.Area(2,,2,).RowHeight = 8;
	Spreadsheet.Area(,1,,1).ColumnWidth = 25;
	//
	TopScale = ScaleArea.Top + 2;
	BottomScale = ScaleArea.Bottom;
	While TopScale <= BottomScale Do
		Spreadsheet.Area(TopScale, 1).RowHeight = 10;
		Spreadsheet.Area(TopScale + 1, 1).RowHeight = 11;
		TopScale = TopScale + 2;
	EndDo;
	//
	ColumnNumber = ScaleBegin - 1;
	While ColumnNumber <= ScaleArea.Right Do
		Spreadsheet.Area(,ColumnNumber + 1,,ColumnNumber + 1).ColumnWidth = 16.38;
		Spreadsheet.Area(,ColumnNumber + 2,,ColumnNumber + 2).ColumnWidth = 1;
		ColumnNumber = ColumnNumber + 2;
	EndDo;
	
	Spreadsheet.FixedTop = 2;
	Spreadsheet.FixedLeft = 1;
	
EndProcedure // UpdateCalendarMonthPeriod()

// The procedure generates the schedule of resources import - period day.
//
&AtServer
Procedure UpdateCalendarDayPeriod(Spreadsheet, ResourcesList, Period4Days = False)
	
	ScaleTemplate = DataProcessors.Scheduler.GetTemplate("DayScale");
	
	// Displaying the scale.
	Indent = 1;
	ScaleStep = 3;
	ScaleBegin = 6;
	ShiftByScale = 1;
	ScaleSeparatorBottom = 3;
	ScaleSeparatorTop = 2;
	
	If ValueIsFilled(TimeLimitFrom) Then
		HourC = Hour(TimeLimitFrom);
		MinuteFrom = Minute(TimeLimitFrom);
	Else
		HourC = 0;
		MinuteFrom = 0;
	EndIf;
	If ValueIsFilled(TimeLimitTo) Then
		HourTo = Hour(TimeLimitTo);
		MinuteOn = Minute(TimeLimitTo);
	Else
		HourTo = 24;
		MinuteOn = 0;
	EndIf;
	
	ResourcesListArea = ScaleTemplate.Area("Scale60|ResourcesList");
	Spreadsheet.InsertArea(ResourcesListArea, Spreadsheet.Area(ResourcesListArea.Name));
	If RepetitionFactorOFDay = 60 Then
		If HourC = HourTo Then
			HourTo = HourC + ShiftByScale;
		ElsIf MinuteOn <> 0 Then
			HourTo = HourTo + ShiftByScale;
		EndIf;
		TotalMinutesFrom =  HourC * 60;
		TotalMinutesTo = HourTo * 60;
		ColumnNumberFrom = ScaleBegin + ?(HourC-Int(HourC/2)*2 = 1, (HourC - ShiftByScale), HourC) / 2 * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(HourC-Int(HourC/2)*2 = 1, (HourC - ShiftByScale), HourC)) * 60 * 60;
		ColumnNumberTo = ScaleBegin + ?(HourTo-Int(HourTo/2)*2 = 1, (HourTo + ShiftByScale), HourTo) / 2 * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(HourTo-Int(HourTo/2)*2 = 1, (HourTo + ShiftByScale), HourTo)) * 60 * 60;
		ScaleArea = ScaleTemplate.Area("Scale60|Repetition60");
	ElsIf RepetitionFactorOFDay = 15 Then
		TotalMinutesFrom = HourC * 60 + MinuteFrom;
		TotalMinutesTo = HourTo * 60 + MinuteOn;
		If TotalMinutesFrom = TotalMinutesTo Then
			TotalMinutesTo = TotalMinutesFrom + 60;
		EndIf;
		ColumnNumberFrom = ScaleBegin + Int(TotalMinutesFrom / 30) * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(Int(TotalMinutesFrom / 30) = (TotalMinutesFrom / 30), TotalMinutesFrom, Int(TotalMinutesFrom / 30) * 30)) * 60;
		ColumnNumberTo = ScaleBegin + ?(Int(TotalMinutesTo / 30) = (TotalMinutesTo / 30), (TotalMinutesTo / 30), Int(TotalMinutesTo / 30) + 1) * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(Int(TotalMinutesTo / 30) = (TotalMinutesTo / 30), TotalMinutesTo, Int(TotalMinutesTo / 30) * 30 + 30)) * 60;
		ScaleArea = ScaleTemplate.Area("Scale15|Repetition15");
	ElsIf RepetitionFactorOFDay = 10 Then
		TotalMinutesFrom = HourC * 60 + MinuteFrom;
		TotalMinutesTo = HourTo * 60 + MinuteOn;
		If TotalMinutesFrom = TotalMinutesTo Then
			TotalMinutesTo = TotalMinutesFrom + 60;
		EndIf;
		ColumnNumberFrom = ScaleBegin + Int(TotalMinutesFrom / 20) * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(Int(TotalMinutesFrom / 20) = (TotalMinutesFrom / 20), TotalMinutesFrom, Int(TotalMinutesFrom / 20) * 20)) * 60;
		ColumnNumberTo = ScaleBegin + ?(Int(TotalMinutesTo / 20) = (TotalMinutesTo / 20), (TotalMinutesTo / 20), Int(TotalMinutesTo / 20) + 1) * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(Int(TotalMinutesTo / 20) = (TotalMinutesTo / 20), TotalMinutesTo, Int(TotalMinutesTo / 20) * 20 + 20)) * 60;
		ScaleArea = ScaleTemplate.Area("Scale10|Repetition10");
	ElsIf RepetitionFactorOFDay = 5 Then
		TotalMinutesFrom = HourC * 60 + MinuteFrom;
		TotalMinutesTo = HourTo * 60 + MinuteOn;
		If TotalMinutesFrom = TotalMinutesTo Then
			TotalMinutesTo = TotalMinutesFrom + 60;
		EndIf;
		ColumnNumberFrom = ScaleBegin + Int(TotalMinutesFrom / 10) * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(Int(TotalMinutesFrom / 10) = (TotalMinutesFrom / 10), TotalMinutesFrom, Int(TotalMinutesFrom / 10) * 10)) * 60;
		ColumnNumberTo = ScaleBegin + ?(Int(TotalMinutesTo / 10) = (TotalMinutesTo / 10), (TotalMinutesTo / 10), Int(TotalMinutesTo / 10) + 1) * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(Int(TotalMinutesTo / 10) = (TotalMinutesTo / 10), TotalMinutesTo, Int(TotalMinutesTo / 10) * 10 + 10)) * 60;
		ScaleArea = ScaleTemplate.Area("Scale5|Repetition5");
	Else // 30 min
		If HourC = HourTo Then
			HourTo = HourC + ShiftByScale;
		ElsIf MinuteOn <> 0 Then
			HourTo = HourTo + ShiftByScale;
		EndIf;
		TotalMinutesFrom =  HourC * 60;
		TotalMinutesTo = HourTo * 60;
		ColumnNumberFrom = ScaleBegin + HourC * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(Int(TotalMinutesFrom / 60) = (TotalMinutesFrom / 60), TotalMinutesFrom, TotalMinutesFrom - 30)) * 60;
		ColumnNumberTo = ScaleBegin + HourTo * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(Int(TotalMinutesTo / 60) = (TotalMinutesTo / 60), TotalMinutesTo, TotalMinutesTo + 30)) * 60;
		ScaleArea = ScaleTemplate.Area("Scale30|Repetition30");
	EndIf;
	TemplateArea = ScaleTemplate.Area("R" + ScaleArea.Top + "C"+ ColumnNumberFrom +":R"+ ScaleArea.Bottom +"C" + ColumnNumberTo);
	SpreadsheetArea = Spreadsheet.Area("R" + ShiftByScale + "C" + ScaleBegin + ":R"+ (ScaleStep + 1) +"C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom));
	Spreadsheet.InsertArea(TemplateArea, SpreadsheetArea);
	
	// Initialization of days array.
	DaysArray = New Array;
	DaysArray.Add(CalendarDateBegin);
	
	// First column format.
	FirstColumnCoordinates = "R" + ShiftByScale + "C" + (ScaleBegin + ShiftByScale) + ":R" + ShiftByScale + "C" + (ScaleBegin + ShiftByScale);
	Spreadsheet.Area(FirstColumnCoordinates).Text = Format(CalendarDateBegin, "DF=""dd MMMM yyyy dddd""");
	Spreadsheet.Area("R" + ScaleSeparatorTop + "C" + (ScaleBegin + ShiftByScale) + ":R" + ScaleSeparatorBottom + "C" + (ScaleBegin + ShiftByScale)).LeftBorder = New Line(SpreadsheetDocumentCellLineType.None);
	
	// Last column format.
	LastColumnCoordinates = "R" + ShiftByScale + "C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom) + ":R" + (ScaleStep + 1) + "C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom);
	Spreadsheet.Area(LastColumnCoordinates).RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
	Spreadsheet.Area(LastColumnCoordinates).BorderColor = StyleColors.BorderColor;
	
	CoordinatesForUnion = "R" + ShiftByScale + "C" + (ScaleBegin + ShiftByScale) + ":R" + ShiftByScale + "C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom);
	UnionArea = Spreadsheet.Area(CoordinatesForUnion);
	UnionArea.Merge();
	
	// Coordinates of day end.
	EndOfDayCoordinates = LastColumnCoordinates;
	
	// Day-off format.
	If Weekday(CalendarDateBegin) = 6 
		OR Weekday(CalendarDateBegin) = 7 Then
		DayOffCoordinates = "R" + (ShiftByScale + 1) + "C" + ScaleBegin + ":R"+ (ScaleStep + 1) +"C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom);
		Spreadsheet.Area(DayOffCoordinates).BackColor = StyleColors.NonWorkingTimeDayOff;
	EndIf;
	
	// Period - 4 days.
	If Period4Days Then
		BeginTrailDays = ScaleBegin + ColumnNumberTo - ColumnNumberFrom;
		DaysNumber = 1;
		While DaysNumber <= 3 Do
			SpreadsheetArea = Spreadsheet.Area("R" + ShiftByScale + "C" + (BeginTrailDays + DaysNumber) + ":R"+ (ScaleStep + 1) +"C" + (BeginTrailDays + DaysNumber + ColumnNumberTo - ColumnNumberFrom));
			Spreadsheet.InsertArea(TemplateArea, SpreadsheetArea);
			
			// Day start format.
			CoordinatesBeginningDay = "R" + ShiftByScale + "C" + (BeginTrailDays + DaysNumber + ShiftByScale) + ":R" + ShiftByScale + "C" + (BeginTrailDays + DaysNumber + ShiftByScale);
			NextCalendarDate = CalendarDateBegin + DaysNumber * 24 * 60 * 60;
			Spreadsheet.Area(CoordinatesBeginningDay).Text = Format(NextCalendarDate, "DF=""dd MMMM yyyy dddd""");
			Spreadsheet.Area("R" + ScaleSeparatorTop + "C" + (BeginTrailDays + DaysNumber + ShiftByScale) + ":R" + ScaleSeparatorBottom + "C" + (BeginTrailDays + DaysNumber + ShiftByScale)).LeftBorder = New Line(SpreadsheetDocumentCellLineType.None);
			
			// Last column format.
			LastColumnCoordinates = "R" + ShiftByScale + "C" + (BeginTrailDays + DaysNumber + ColumnNumberTo - ColumnNumberFrom) + ":R" + (ScaleStep + 1) + "C" + (BeginTrailDays + DaysNumber + ColumnNumberTo - ColumnNumberFrom);
			Spreadsheet.Area(LastColumnCoordinates).RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
			Spreadsheet.Area(LastColumnCoordinates).BorderColor = StyleColors.BorderColor;
			
			CoordinatesForUnion = "R" + ShiftByScale + "C" + (BeginTrailDays + DaysNumber + ShiftByScale) + ":R" + ShiftByScale + "C" + (BeginTrailDays + DaysNumber + ColumnNumberTo - ColumnNumberFrom);
			UnionArea = Spreadsheet.Area(CoordinatesForUnion);
			UnionArea.Merge();
			
			// Day-off format.
			If Weekday(NextCalendarDate) = 6 
				OR Weekday(NextCalendarDate) = 7 Then
				DayOffCoordinates = "R" + (ShiftByScale + 1) + "C" + (BeginTrailDays + DaysNumber) + ":R"+ (ScaleStep + 1) +"C" + (BeginTrailDays + DaysNumber + ColumnNumberTo - ColumnNumberFrom);
				Spreadsheet.Area(DayOffCoordinates).BackColor = StyleColors.NonWorkingTimeDayOff;
			EndIf;
			
			DaysArray.Add(CalendarDateBegin + DaysNumber * 24 * 60 * 60);
			
			BeginTrailDays = BeginTrailDays + ColumnNumberTo - ColumnNumberFrom;
			DaysNumber = DaysNumber + 1;
			
		EndDo;
	EndIf;
	
	// Initialization of scale sizes.
	Spreadsheet.Area(1,,1,).RowHeight = 16;
	Spreadsheet.Area(2,,2,).RowHeight = 6;
	Spreadsheet.Area(3,,3,).RowHeight = 5;
	Spreadsheet.Area(4,,4,).RowHeight = 5;
	
	Spreadsheet.Area(,1,,1).ColumnWidth = 22;
	Spreadsheet.Area(,2,,2).ColumnWidth = 1;
	Spreadsheet.Area(,3,,3).ColumnWidth = 3;
	Spreadsheet.Area(,4,,4).ColumnWidth = 1;
	Spreadsheet.Area(,5,,5).ColumnWidth = 3;
	
	ColumnNumber = ScaleBegin;
	LastColumnNumber = Spreadsheet.TableWidth;
	While ColumnNumber <= LastColumnNumber Do
		
		Spreadsheet.Area(,ColumnNumber,,ColumnNumber).ColumnWidth = 0.8;
		Spreadsheet.Area(,ColumnNumber + 1,,ColumnNumber + 1).ColumnWidth = 6;
		Spreadsheet.Area(,ColumnNumber + 2,,ColumnNumber + 2).ColumnWidth = 6;
		ColumnNumber = ColumnNumber + 3;
		
	EndDo;
	
	// Displaying the schedule of resources import.
	BusyResourceCellColor = StyleColors.BusyResource;
	AvailableResourceCellColor = StyleColors.WorktimeCompletelyBusy;
	ResourceIsNotEditableCellColor = StyleColors.WorktimeFreeAvailable;
	CellBorderColor = StyleColors.CellBorder;
	
	QueryResult = GetResourcesWorkImportSchedule(ResourcesList, DaysArray);
	
	// Timetable by the schedule, without schedule (list of resources).
	ResourcesListBegin = ResourcesListArea.Bottom + Indent;
	SelectionResource = QueryResult[2].Select(QueryResultIteration.ByGroups, "EnterpriseResource");
	LineNumber = 1;
	While SelectionResource.Next() Do
		
		CountOfFreeSlots = 0;
		ResourceCapacity = ?(SelectionResource.Capacity = 1, 0, SelectionResource.Capacity);
		
		// List of resources.
		R = ResourcesListBegin + LineNumber;
		Spreadsheet.Area(R, 1).Text = SelectionResource.EnterpriseResource;
		Spreadsheet.Area(R, 1).VerticalAlign = VerticalAlign.Center;
		Spreadsheet.Area(R, 1).Details = SelectionResource.EnterpriseResource;
		
		// All intervals are nonworking.
		FirstColumnNumber = Spreadsheet.Area(FirstColumnCoordinates).Left - 1;
		NumberOfLasfColumnOfDay = Spreadsheet.Area(EndOfDayCoordinates).Right;
		NumberOfLasfColumnOfScale = Spreadsheet.Area(LastColumnCoordinates).Right;
		
		Interval = 0;
		NextFirstColumn = 0;
		NextLastColumn = 0;
		For Each DayArray IN DaysArray Do
			
			MultipleTimeFrom = MultipleRestrictionFrom;
			NextFirstColumn = NextFirstColumn + FirstColumnNumber;
			NextLastColumn = NextLastColumn + NumberOfLasfColumnOfDay + Interval;
			
			Interval = 0;
			R = ResourcesListBegin + LineNumber;
			While NextFirstColumn <= NextLastColumn Do
				// Cell 1.
				SearchInterval = DayArray + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
				Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = ResourceIsNotEditableCellColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid, 2);
				Spreadsheet.Area(R, NextFirstColumn + Indent).BorderColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + Indent).TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
				Spreadsheet.Area(R, NextFirstColumn + Indent).VerticalAlign = VerticalAlign.Center;
				Spreadsheet.Area(R, NextFirstColumn + Indent).HorizontalAlign = HorizontalAlign.Center;
				Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Font = New Font(, 8, True, , , );
				Spreadsheet.Area(R, NextFirstColumn + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, 1);
				// Cell 2.
				MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
				SearchInterval = DayArray + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = ResourceIsNotEditableCellColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).VerticalAlign = VerticalAlign.Center;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).HorizontalAlign = HorizontalAlign.Center;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Font = New Font(, 8, True, , , );
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, 1);
				
				MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
				NextFirstColumn = NextFirstColumn + 3;
				Interval = Interval + 3;
				
			EndDo;
			
			FirstColumnNumber = 0;
			NumberOfLasfColumnOfDay = 0;
			
		EndDo;
		
		FirstColumnNumber = Spreadsheet.Area(FirstColumnCoordinates).Left - 1;
		NumberOfLasfColumnOfDay = Spreadsheet.Area(EndOfDayCoordinates).Right;
		NumberOfLasfColumnOfScale = Spreadsheet.Area(LastColumnCoordinates).Right;
		
		// Work by schedule.
		ArrayOfIntervals = New Array();
		ArrayOfDaysBySchedule = New Array();
		SelectionPeriod = SelectionResource.Select(QueryResultIteration.ByGroups, "Period");
		While SelectionPeriod.Next() Do
			
			If Not ValueIsFilled(SelectionPeriod.Period) Then
				Continue;
			EndIf;
			
			ArrayOfDaysBySchedule.Add(SelectionPeriod.Period);
			
			Selection = SelectionPeriod.Select();
			While Selection.Next() Do
				If Not ValueIsFilled(Selection.BeginTime)
					AND Not ValueIsFilled(Selection.RejectionsBeginTime)
					OR Selection.RejectionsNotABusinessDay Then
					Continue;
				EndIf;
				If ValueIsFilled(Selection.RejectionsBeginTime) Then
					CalculateIntervals(ArrayOfIntervals, MultipleRestrictionFrom, MultipleRestrictionTo, Selection.RejectionsBeginTime, Selection.RejectionsEndTime);
				Else
					CalculateIntervals(ArrayOfIntervals, MultipleRestrictionFrom, MultipleRestrictionTo, Selection.BeginTime, Selection.EndTime);
				EndIf;
			EndDo;
			
		EndDo;
		
		If ArrayOfIntervals.Count() > 0 Then
			
			Interval = 0;
			NextFirstColumn = 0;
			NextLastColumn = 0;
			For Each DayArray IN DaysArray Do
				
				MultipleTimeFrom = MultipleRestrictionFrom;
				NextFirstColumn = NextFirstColumn + FirstColumnNumber;
				NextLastColumn = NextLastColumn + NumberOfLasfColumnOfDay + Interval;
				
				Interval = 0;
				R = ResourcesListBegin + LineNumber;
				While NextFirstColumn <= NextLastColumn Do
					
					SearchInterval = DayArray + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
					SearchResult = ArrayOfIntervals.Find(SearchInterval);
					If SearchResult <> Undefined Then
						// Cell 1.
						CountOfFreeSlots = CountOfFreeSlots + 1;
						Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = AvailableResourceCellColor;
						Spreadsheet.Area(R, NextFirstColumn + Indent).Text = ResourceCapacity;
						Spreadsheet.Area(R, NextFirstColumn + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, 2);
					Else
						Spreadsheet.Area(R, NextFirstColumn + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, 1);
					EndIf;
					
					MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
					SearchInterval = DayArray + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
					SearchResult = ArrayOfIntervals.Find(SearchInterval);
					If SearchResult <> Undefined Then
						// Cell 2.
						CountOfFreeSlots = CountOfFreeSlots + 1;
						Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = AvailableResourceCellColor;
						Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = ResourceCapacity;
						Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, 2);
					Else
						Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, 1);
					EndIf;
					
					MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
					NextFirstColumn = NextFirstColumn + 3;
					Interval = Interval + 3;
					
				EndDo;
				
				FirstColumnNumber = 0;
				NumberOfLasfColumnOfDay = 0;
				
			EndDo;
			
		EndIf;
		
		// Work without schedule.
		If ArrayOfDaysBySchedule.Count() = 0 Then
			WorkingDaysCount = DaysArray.Count();
			ByScheduleFrom = DaysArray[WorkingDaysCount - 1] + 24 * 60 *60
		ElsIf ArrayOfDaysBySchedule.Count() < DaysArray.Count() Then
			ByScheduleFrom = ArrayOfDaysBySchedule[0];
		ElsIf ArrayOfDaysBySchedule.Count() = DaysArray.Count() Then
			ByScheduleFrom = DaysArray[0];
		EndIf;
		
		Interval = 0;
		NextFirstColumn = 0;
		NextLastColumn = 0;
		DayArray = DaysArray[0];
		While DayArray < ByScheduleFrom Do
			
			MultipleTimeFrom = MultipleRestrictionFrom;
			NextFirstColumn = NextFirstColumn + FirstColumnNumber;
			NextLastColumn = NextLastColumn + NumberOfLasfColumnOfDay + Interval;
			
			Interval = 0;
			R = ResourcesListBegin + LineNumber;
			While NextFirstColumn <= NextLastColumn Do
				
				SearchInterval = DayArray + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
				CountOfFreeSlots = CountOfFreeSlots + 2;
				
				// Cell 1.
				Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = AvailableResourceCellColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, 2);
				
				// Cell 2.
				MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
				SearchInterval = DayArray + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = AvailableResourceCellColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, 2);
				
				MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
				NextFirstColumn = NextFirstColumn + 3;
				Interval = Interval + 3;
				
			EndDo;
			
			FirstColumnNumber = 0;
			NumberOfLasfColumnOfDay = 0;
			
			DayArray = DayArray + 24 * 60 *60;
			
		EndDo;
		
		// Displaying the totals.
		Line = New Line(SpreadsheetDocumentCellLineType.Solid,3);
		Spreadsheet.Area(R, 2).Outline(Line, Line, Line, Line);
		Spreadsheet.Area(R, 2).BorderColor = CellBorderColor;
		Spreadsheet.Area(R, 2).BackColor = AvailableResourceCellColor;
		Spreadsheet.Area(R, 3).Text = ?(CountOfFreeSlots = 0, "0", CountOfFreeSlots);
		Spreadsheet.Area(R, 3).VerticalAlign = VerticalAlign.Center;
		Spreadsheet.Area(R, 3).HorizontalAlign = HorizontalAlign.Left;
		
		Line = New Line(SpreadsheetDocumentCellLineType.Solid,3);
		Spreadsheet.Area(R, 4).Outline(Line, Line, Line, Line);
		Spreadsheet.Area(R, 4).BorderColor = CellBorderColor;
		Spreadsheet.Area(R, 4).BackColor = BusyResourceCellColor;
		Spreadsheet.Area(R, 5).Text = "0";
		Spreadsheet.Area(R, 5).VerticalAlign = VerticalAlign.Center;
		Spreadsheet.Area(R, 5).HorizontalAlign = HorizontalAlign.Left;
		
		LineNumber = LineNumber + 2;
		
	EndDo;
	
	// Schedule of resources import for the orders.
	IntervalsTable = New ValueTable();
	IntervalsTable.Columns.Add("Interval");
	IntervalsTable.Columns.Add("Order");
	IntervalsTable.Columns.Add("Import");
	IntervalsTable.Indexes.Add("Interval");
	
	LineNumber = 1;
	SelectionResource = QueryResult[3].Select(QueryResultIteration.ByGroups, "EnterpriseResource");
	While SelectionResource.Next() Do
		
		R = ResourcesListBegin + LineNumber;
		
		BusyIntervalsCount = 0;
		CountOfFreeSlots = 0;
		ResourceCapacity = ?(SelectionResource.Capacity = 1, 0, SelectionResource.Capacity);
		
		FirstColumnNumber = Spreadsheet.Area(FirstColumnCoordinates).Left - 1;
		NumberOfLasfColumnOfDay = Spreadsheet.Area(EndOfDayCoordinates).Right;
		NumberOfLasfColumnOfScale = Spreadsheet.Area(LastColumnCoordinates).Right;
		
		IntervalsTable.Clear();
		Selection = SelectionResource.Select();
		While Selection.Next() Do
			If Not ValueIsFilled(Selection.BeginTime)Then
				Continue;
			EndIf;
			CalculateIntervalsWithDetails(Selection, IntervalsTable, MultipleRestrictionFrom, MultipleRestrictionTo);
		EndDo;
		
		If IntervalsTable.Count() > 0 Then
			
			Interval = 0;
			NextFirstColumn = 0;
			NextLastColumn = 0;
			For Each DayArray IN DaysArray Do
				
				MultipleTimeFrom = MultipleRestrictionFrom;
				NextFirstColumn = NextFirstColumn + FirstColumnNumber;
				NextLastColumn = NextLastColumn + NumberOfLasfColumnOfDay + Interval;
				
				Interval = 0;
				R = ResourcesListBegin + LineNumber;
				While NextFirstColumn <= NextLastColumn Do
					
					SearchInterval = DayArray + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
					SearchStructure = New Structure("Interval", SearchInterval);
					SearchResult = IntervalsTable.FindRows(SearchStructure);
					If SearchResult.Count() > 0 Then
						// Cell 1.
						TotalImport = 0;
						OrdersArray = New Array;
						For Each ImportRow IN SearchResult Do
							TotalImport = TotalImport + ImportRow.Import;
							OrdersArray.Add(ImportRow.Order);
						EndDo;
						If ResourceCapacity = 0 Then
							ResourceImport = 0;
						Else
							TextResourceImport = Spreadsheet.Area(R, NextFirstColumn + Indent).Text;
							ResourceImport = Number(TextResourceImport);
							ResourceImport = ResourceImport - TotalImport;
						EndIf;
						If ResourceImport = 0 Then
							Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = BusyResourceCellColor;
							Spreadsheet.Area(R, NextFirstColumn + Indent).Text = ResourceImport;
							KindOfInterval = 3;
						ElsIf ResourceImport < 0 Then
							Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = BusyResourceCellColor;
							Spreadsheet.Area(R, NextFirstColumn + Indent).Text = ResourceImport * (-1);
							KindOfInterval = 3;
						Else
							Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = AvailableResourceCellColor;
							Spreadsheet.Area(R, NextFirstColumn + Indent).Text = ResourceImport;
							KindOfInterval = 2;
						EndIf;
						
						Spreadsheet.Area(R, NextFirstColumn + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, KindOfInterval, OrdersArray);
						
					EndIf;
					
					MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
					SearchInterval = DayArray + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
					SearchStructure = New Structure("Interval", SearchInterval);
					SearchResult = IntervalsTable.FindRows(SearchStructure);
					If SearchResult.Count() > 0 Then
						// Cell 2.
						TotalImport = 0;
						OrdersArray = New Array;
						For Each ImportRow IN SearchResult Do
							TotalImport = TotalImport + ImportRow.Import;
							OrdersArray.Add(ImportRow.Order);
						EndDo;
						If ResourceCapacity = 0 Then
							ResourceImport = 0;
						Else
							TextResourceImport = Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text;
							ResourceImport = Number(TextResourceImport);
							ResourceImport = ResourceImport - TotalImport;
						EndIf;
						If ResourceImport = 0 Then
							Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = BusyResourceCellColor;
							Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = ResourceImport;
							KindOfInterval = 3;
						ElsIf ResourceImport < 0 Then
							Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = BusyResourceCellColor;
							Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = ResourceImport * (-1);
							KindOfInterval = 3;
						Else
							Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = AvailableResourceCellColor;
							Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = ResourceImport;
							KindOfInterval = 2;
						EndIf;
						
						Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, KindOfInterval, OrdersArray);
						
					EndIf;
					
					DetailsOfCell1 = Spreadsheet.Area(R, NextFirstColumn + Indent).Details;
					If DetailsOfCell1.KindOfInterval = 2 Then
						CountOfFreeSlots = CountOfFreeSlots + 1;
					EndIf;
					If DetailsOfCell1.KindOfInterval = 3 Then
						BusyIntervalsCount = BusyIntervalsCount + 1;
					EndIf;
					DetailsOfCell2 = Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Details;
					If DetailsOfCell2.KindOfInterval = 2 Then
						CountOfFreeSlots = CountOfFreeSlots + 1;
					EndIf;
					If DetailsOfCell2.KindOfInterval = 3 Then
						BusyIntervalsCount = BusyIntervalsCount + 1;
					EndIf;
					
					MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
					NextFirstColumn = NextFirstColumn + 3;
					Interval = Interval + 3;
					
				EndDo;
				
				FirstColumnNumber = 0;
				NumberOfLasfColumnOfDay = 0;
				
			EndDo;
			
			// Displaying the totals.
			Spreadsheet.Area(R, 3).Text = ?(CountOfFreeSlots = 0, "0", CountOfFreeSlots);
			Spreadsheet.Area(R, 5).Text = ?(BusyIntervalsCount = 0, "0", BusyIntervalsCount);
			
		EndIf;
		
		// Initialization of line sizes.
		R = ScaleStep + LineNumber + ShiftByScale;
		Spreadsheet.Area(R, 1).RowHeight = 5;
		Spreadsheet.Area(R + Indent, 1).RowHeight = 18;
		
		LineNumber = LineNumber + 2;
		
	EndDo;
	
	Spreadsheet.FixedTop = 4;
	Spreadsheet.FixedLeft = 5;
	
EndProcedure // UpdateCalendarDayPeriod()

// The procedure calculates the planning intervals for calendar scale.
//
&AtServer
Procedure CalculateIntervals(ArrayOfIntervals, TimeFrom, TimeTo, BeginTime, EndTime)
	
	MultipleTimeRestrictionFrom = BegOfDay(BeginTime) + Hour(TimeFrom) * 60 * 60 + Minute(TimeFrom) * 60;
	MultipleTimeRestrictionTo = BegOfDay(BeginTime) + Hour(TimeTo) * 60 * 60 + Minute(TimeTo) * 60;
	
	// If 24 hours.
	If MultipleTimeRestrictionFrom >= MultipleTimeRestrictionTo Then
		MultipleTimeRestrictionTo = MultipleTimeRestrictionTo + 24 * 60 * 60;
	EndIf;
	
	If RepetitionFactorOFDay = 60 Then
		
		HourBeginTime = Hour(BeginTime);
		MultipleStartTime = BegOfDay(BeginTime) + HourBeginTime * 60 * 60;
		EndTimeHour = ?(Minute(EndTime) <> 0, Hour(EndTime) + 1, Hour(EndTime));
		MultipleEndTime = BegOfDay(EndTime) + EndTimeHour * 60 * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If Hour(MultipleStartTime) >= Hour(MultipleTimeRestrictionFrom) AND Hour(MultipleStartTime) <= Hour(MultipleTimeRestrictionTo) Then
				ArrayOfIntervals.Add(MultipleStartTime);
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	ElsIf RepetitionFactorOFDay = 15 Then
		
		MinutesBeginTime = Int(Minute(BeginTime) / 15) * 15;
		MultipleStartTime = BegOfDay(BeginTime) + Hour(BeginTime) * 60 * 60 + MinutesBeginTime * 60;
		
		MinutesEndTime = ?(Int(Minute(EndTime) / 15) = Minute(EndTime) / 15, Minute(EndTime), Int(Minute(EndTime) / 15) * 15 + 15);
		MultipleEndTime = BegOfDay(EndTime) + Hour(EndTime) * 60 * 60 + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				ArrayOfIntervals.Add(MultipleStartTime);
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	ElsIf RepetitionFactorOFDay = 10 Then
		
		MinutesBeginTime = Int(Minute(BeginTime) / 10) * 10;
		MultipleStartTime = BegOfDay(BeginTime) + Hour(BeginTime) * 60 * 60 + MinutesBeginTime * 60;
		
		MinutesEndTime = ?(Int(Minute(EndTime) / 10) = Minute(EndTime) / 10, Minute(EndTime), Int(Minute(EndTime) / 10) * 10 + 10);
		MultipleEndTime = BegOfDay(EndTime) + Hour(EndTime) * 60 * 60 + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				ArrayOfIntervals.Add(MultipleStartTime);
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	ElsIf RepetitionFactorOFDay = 5 Then
		
		MinutesBeginTime = Int(Minute(BeginTime) / 5) * 5;
		MultipleStartTime = BegOfDay(BeginTime) + Hour(BeginTime) * 60 * 60 + MinutesBeginTime * 60;
		
		MinutesEndTime = ?(Int(Minute(EndTime) / 5) = Minute(EndTime) / 5, Minute(EndTime), Int(Minute(EndTime) / 5) * 5 + 5);
		MultipleEndTime = BegOfDay(EndTime) + Hour(EndTime) * 60 * 60 + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				ArrayOfIntervals.Add(MultipleStartTime);
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
		TimeFrom = MultipleTimeRestrictionFrom;
		
	Else // Repetition = 30
		
		MinutesBeginTime = ?(Minute(BeginTime) < 30, Hour(BeginTime) * 60, Hour(BeginTime) * 60 + 30);
		MultipleStartTime = BegOfDay(BeginTime) + MinutesBeginTime * 60;
		If Minute(EndTime) <= 30 Then
			MinutesEndTime = ?(Minute(EndTime) = 0, Hour(EndTime) * 60, Hour(EndTime) * 60 + 30);
		Else
			MinutesEndTime = (Hour(EndTime) + 1) * 60;
		EndIf;
		MultipleEndTime = BegOfDay(EndTime) + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				ArrayOfIntervals.Add(MultipleStartTime);
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	EndIf;
	
EndProcedure // CalculateIntervals()

// The procedure calculates the planning intervals for the calendar scale with decryption.
//
&AtServer
Procedure CalculateIntervalsWithDetails(Selection, IntervalsTable, TimeFrom, TimeTo)
	
	BeginTime = Selection.BeginTime;
	EndTime = Selection.EndTime;
	
	MultipleTimeRestrictionFrom = BegOfDay(BeginTime) + Hour(TimeFrom) * 60 * 60 + Minute(TimeFrom) * 60;
	MultipleTimeRestrictionTo = BegOfDay(BeginTime) + Hour(TimeTo) * 60 * 60 + Minute(TimeTo) * 60;
	
	// If 24 hours.
	If MultipleTimeRestrictionFrom >= MultipleTimeRestrictionTo Then
		MultipleTimeRestrictionTo = MultipleTimeRestrictionTo + 24 * 60 * 60;
	EndIf;
	
	If RepetitionFactorOFDay = 60 Then
		
		HourBeginTime = Hour(BeginTime);
		MultipleStartTime = BegOfDay(BeginTime) + HourBeginTime * 60 * 60;
		EndTimeHour = ?(Minute(EndTime) <> 0, Hour(EndTime) + 1, Hour(EndTime));
		MultipleEndTime = BegOfDay(EndTime) + EndTimeHour * 60 * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If Hour(MultipleStartTime) >= Hour(MultipleTimeRestrictionFrom) AND Hour(MultipleStartTime) <= Hour(MultipleTimeRestrictionTo) Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Order = Selection.Ref;
				NewRow.Import = Selection.Import;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	ElsIf RepetitionFactorOFDay = 15 Then
		
		MinutesBeginTime = Int(Minute(BeginTime) / 15) * 15;
		MultipleStartTime = BegOfDay(BeginTime) + Hour(BeginTime) * 60 * 60 + MinutesBeginTime * 60;
		
		MinutesEndTime = ?(Int(Minute(EndTime) / 15) = Minute(EndTime) / 15, Minute(EndTime), Int(Minute(EndTime) / 15) * 15 + 15);
		MultipleEndTime = BegOfDay(EndTime) + Hour(EndTime) * 60 * 60 + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Order = Selection.Ref;
				NewRow.Import = Selection.Import;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	ElsIf RepetitionFactorOFDay = 10 Then
		
		MinutesBeginTime = Int(Minute(BeginTime) / 10) * 10;
		MultipleStartTime = BegOfDay(BeginTime) + Hour(BeginTime) * 60 * 60 + MinutesBeginTime * 60;
		
		MinutesEndTime = ?(Int(Minute(EndTime) / 10) = Minute(EndTime) / 10, Minute(EndTime), Int(Minute(EndTime) / 10) * 10 + 10);
		MultipleEndTime = BegOfDay(EndTime) + Hour(EndTime) * 60 * 60 + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Order = Selection.Ref;
				NewRow.Import = Selection.Import;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	ElsIf RepetitionFactorOFDay = 5 Then
		
		MinutesBeginTime = Int(Minute(BeginTime) / 5) * 5;
		MultipleStartTime = BegOfDay(BeginTime) + Hour(BeginTime) * 60 * 60 + MinutesBeginTime * 60;
		
		MinutesEndTime = ?(Int(Minute(EndTime) / 5) = Minute(EndTime) / 5, Minute(EndTime), Int(Minute(EndTime) / 5) * 5 + 5);
		MultipleEndTime = BegOfDay(EndTime) + Hour(EndTime) * 60 * 60 + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Order = Selection.Ref;
				NewRow.Import = Selection.Import;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
		TimeFrom = MultipleTimeRestrictionFrom;
		
	Else // Repetition = 30
		
		MinutesBeginTime = ?(Minute(BeginTime) < 30, Hour(BeginTime) * 60, Hour(BeginTime) * 60 + 30);
		MultipleStartTime = BegOfDay(BeginTime) + MinutesBeginTime * 60;
		If Minute(EndTime) <= 30 Then
			MinutesEndTime = ?(Minute(EndTime) = 0, Hour(EndTime) * 60, Hour(EndTime) * 60 + 30);
		Else
			MinutesEndTime = (Hour(EndTime) + 1) * 60;
		EndIf;
		MultipleEndTime = BegOfDay(EndTime) + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Order = Selection.Ref;
				NewRow.Import = Selection.Import;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	EndIf;
	
EndProcedure // CalculateIntervals()

// The function returns the schedule of resources import.
//
&AtServer
Function GetResourcesWorkImportSchedule(ResourcesList, DaysArray)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ResourcesWorkSchedules.Period AS Period,
	|	ResourcesWorkSchedules.EnterpriseResource AS EnterpriseResource,
	|	ResourcesWorkSchedules.WorkSchedule
	|FROM
	|	InformationRegister.ResourcesWorkSchedules AS ResourcesWorkSchedules
	|
	|ORDER BY
	|	EnterpriseResource,
	|	Period DESC
	|TOTALS BY
	|	EnterpriseResource";
	
	QueryResult = Query.Execute();
	SelectionResource = QueryResult.Select(QueryResultIteration.ByGroups, "EnterpriseResource");
	
	TableOfSchedules = New ValueTable;
	
	Array = New Array;
	Array.Add(Type("Date"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	TableOfSchedules.Columns.Add("Period", TypeDescription);
	
	Array = New Array;
	Array.Add(Type("CatalogRef.KeyResources"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	TableOfSchedules.Columns.Add("EnterpriseResource", TypeDescription);
	
	Array = New Array;
	Array.Add(Type("CatalogRef.WorkSchedules"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	TableOfSchedules.Columns.Add("WorkSchedule", TypeDescription);
	
	While SelectionResource.Next() Do
		
		ArrayOfScheduledDays = New Array();
		For Each ArrayItm IN DaysArray Do
			ArrayOfScheduledDays.Add(ArrayItm);
		EndDo;
		
		Selection = SelectionResource.Select();
		While Selection.Next() Do
			
			Ind = 0;
			While Ind <= ArrayOfScheduledDays.Count() - 1 Do
				
				If Selection.Period <= ArrayOfScheduledDays[Ind] Then
					
					NewRow = TableOfSchedules.Add();
					NewRow.EnterpriseResource = Selection.EnterpriseResource;
					NewRow.Period = ArrayOfScheduledDays[Ind];
					NewRow.WorkSchedule = Selection.WorkSchedule;
					ArrayOfScheduledDays.Delete(Ind);
					
				Else
					Ind = Ind + 1;
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT ALLOWED
	|	KeyResources.Ref AS EnterpriseResource,
	|	KeyResources.Capacity AS Capacity,
	|	KeyResources.Description AS ResourceDescription
	|INTO EnterpriseResourceTempTable
	|FROM
	|	Catalog.KeyResources AS KeyResources
	|WHERE
	|	(&FilterByKeyResource
	|			OR KeyResources.Ref IN (&FilterKeyResourcesList))
	|	AND Not KeyResources.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TableOfSchedules.Period AS Period,
	|	TableOfSchedules.EnterpriseResource AS EnterpriseResource,
	|	TableOfSchedules.WorkSchedule AS WorkSchedule
	|INTO SchedulesTempTable
	|FROM
	|	&TableOfSchedules AS TableOfSchedules
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	EnterpriseResourceTempTable.EnterpriseResource AS EnterpriseResource,
	|	EnterpriseResourceTempTable.Capacity AS Capacity,
	|	SchedulesTempTable.Period AS Period,
	|	SchedulesTempTable.WorkSchedule AS WorkSchedule,
	|	WorkSchedules.BeginTime AS BeginTime,
	|	WorkSchedules.EndTime AS EndTime,
	|	DeviationFromResourcesWorkSchedules.BeginTime AS RejectionsBeginTime,
	|	DeviationFromResourcesWorkSchedules.EndTime AS RejectionsEndTime,
	|	ISNULL(DeviationFromResourcesWorkSchedules.NotABusinessDay, FALSE) AS RejectionsNotABusinessDay
	|FROM
	|	EnterpriseResourceTempTable AS EnterpriseResourceTempTable
	|		LEFT JOIN SchedulesTempTable AS SchedulesTempTable
	|		ON EnterpriseResourceTempTable.EnterpriseResource = SchedulesTempTable.EnterpriseResource
	|		LEFT JOIN InformationRegister.WorkSchedules AS WorkSchedules
	|		ON (SchedulesTempTable.WorkSchedule = WorkSchedules.WorkSchedule)
	|			AND (WorkSchedules.BeginTime between &StartDate AND &EndDate)
	|			AND (WorkSchedules.EndTime between &StartDate AND &EndDate)
	|			AND (SchedulesTempTable.Period = BEGINOFPERIOD(WorkSchedules.BeginTime, DAY))
	|			AND (SchedulesTempTable.Period = BEGINOFPERIOD(WorkSchedules.EndTime, DAY))
	|		LEFT JOIN InformationRegister.DeviationFromResourcesWorkSchedules AS DeviationFromResourcesWorkSchedules
	|		ON EnterpriseResourceTempTable.EnterpriseResource = DeviationFromResourcesWorkSchedules.EnterpriseResource
	|			AND (SchedulesTempTable.Period = BEGINOFPERIOD(DeviationFromResourcesWorkSchedules.Day, DAY))
	|			AND (DeviationFromResourcesWorkSchedules.BeginTime between &StartDate AND &EndDate)
	|			AND (DeviationFromResourcesWorkSchedules.EndTime between &StartDate AND &EndDate)
	|
	|ORDER BY
	|	EnterpriseResourceTempTable.ResourceDescription,
	|	Period,
	|	BeginTime,
	|	EndTime
	|TOTALS
	|	MIN(Capacity)
	|BY
	|	EnterpriseResource,
	|	Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	NestedSelect.Ref,
	|	NestedSelect.Counterparty AS Counterparty,
	|	NestedSelect.Department,
	|	NestedSelect.Responsible,
	|	NestedSelect.Start AS BeginTime,
	|	NestedSelect.Finish AS EndTime,
	|	EnterpriseResourceTempTable.EnterpriseResource AS EnterpriseResource,
	|	EnterpriseResourceTempTable.Capacity AS Capacity,
	|	NestedSelect.Capacity AS Import
	|FROM
	|	EnterpriseResourceTempTable AS EnterpriseResourceTempTable
	|		LEFT JOIN (SELECT
	|			ProductionOrderEnterpriseResources.Ref AS Ref,
	|			ProductionOrderEnterpriseResources.EnterpriseResource AS EnterpriseResource,
	|			ProductionOrderEnterpriseResources.Capacity AS Capacity,
	|			ProductionOrderEnterpriseResources.Start AS Start,
	|			ProductionOrderEnterpriseResources.Finish AS Finish,
	|			ProductionOrderEnterpriseResources.Ref.CustomerOrder.Counterparty AS Counterparty,
	|			ProductionOrderEnterpriseResources.Ref.Responsible AS Responsible,
	|			ProductionOrderEnterpriseResources.Ref.StructuralUnit AS Department
	|		FROM
	|			Document.ProductionOrder.EnterpriseResources AS ProductionOrderEnterpriseResources
	|		WHERE
	|			Not ProductionOrderEnterpriseResources.EnterpriseResource.DeletionMark
	|			AND ProductionOrderEnterpriseResources.Ref.Posted
	|			AND (NOT ProductionOrderEnterpriseResources.Ref.Closed
	|					OR ProductionOrderEnterpriseResources.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|			AND ProductionOrderEnterpriseResources.Start between &StartDate AND &EndDate
	|			AND ProductionOrderEnterpriseResources.Finish between &StartDate AND &EndDate
	|			AND (&FilterCounterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|					OR ProductionOrderEnterpriseResources.Ref.CustomerOrder.Counterparty = &FilterCounterparty)
	|			AND (&FilterByKeyResource
	|					OR ProductionOrderEnterpriseResources.EnterpriseResource IN (&FilterKeyResourcesList))
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			CustomerOrderEnterpriseResources.Ref,
	|			CustomerOrderEnterpriseResources.EnterpriseResource,
	|			CustomerOrderEnterpriseResources.Capacity,
	|			CustomerOrderEnterpriseResources.Start,
	|			CustomerOrderEnterpriseResources.Finish,
	|			CustomerOrderEnterpriseResources.Ref.Counterparty,
	|			CustomerOrderEnterpriseResources.Ref.Responsible,
	|			CustomerOrderEnterpriseResources.Ref.SalesStructuralUnit
	|		FROM
	|			Document.CustomerOrder.EnterpriseResources AS CustomerOrderEnterpriseResources
	|		WHERE
	|			CustomerOrderEnterpriseResources.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|			AND Not CustomerOrderEnterpriseResources.EnterpriseResource.DeletionMark
	|			AND CustomerOrderEnterpriseResources.Ref.Posted
	|			AND (NOT CustomerOrderEnterpriseResources.Ref.Closed
	|					OR CustomerOrderEnterpriseResources.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|			AND CustomerOrderEnterpriseResources.Start between &StartDate AND &EndDate
	|			AND CustomerOrderEnterpriseResources.Finish between &StartDate AND &EndDate
	|			AND (&FilterCounterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|					OR CustomerOrderEnterpriseResources.Ref.Counterparty = &FilterCounterparty)
	|			AND (&FilterByKeyResource
	|					OR CustomerOrderEnterpriseResources.EnterpriseResource IN (&FilterKeyResourcesList))) AS NestedSelect
	|		ON EnterpriseResourceTempTable.EnterpriseResource = NestedSelect.EnterpriseResource
	|
	|ORDER BY
	|	EnterpriseResourceTempTable.ResourceDescription,
	|	BeginTime,
	|	EndTime
	|TOTALS
	|	MIN(Capacity)
	|BY
	|	EnterpriseResource";
	
	Query.SetParameter("StartDate", CalendarDateBegin);
	Query.SetParameter("EndDate", CalendarDateEnd);
	Query.SetParameter("FilterCounterparty", FilterCounterparty);
	Query.SetParameter("FilterByKeyResource", ResourcesList = Undefined);
	Query.SetParameter("FilterKeyResourcesList", ResourcesList);
	Query.SetParameter("TableOfSchedules", TableOfSchedules);
	
	Return Query.ExecuteBatch();
	
EndFunction // GetResourcesUpoadSchedule()

// The function returns the schedule of resources import for a week and a month.
//
&AtServer
Function GetResourcesWorkloadScheduleWeekMonth(ResourcesList, StartDate, EndDate)
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	KeyResources.Ref AS EnterpriseResource,
	|	KeyResources.Description AS ResourceDescription
	|INTO EnterpriseResourceTempTable
	|FROM
	|	Catalog.KeyResources AS KeyResources
	|WHERE
	|	(&FilterByKeyResource
	|			OR KeyResources.Ref IN (&FilterKeyResourcesList))
	|	AND (NOT KeyResources.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EnterpriseResourceTempTable.EnterpriseResource AS EnterpriseResource,
	|	EnterpriseResourceTempTable.ResourceDescription AS ResourceDescription
	|FROM
	|	EnterpriseResourceTempTable AS EnterpriseResourceTempTable
	|
	|ORDER BY
	|	ResourceDescription
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.Ref AS Order,
	|	BEGINOFPERIOD(NestedSelect.Start, DAY) AS BeginTime,
	|	NestedSelect.Finish AS EndTime,
	|	EnterpriseResourceTempTable.ResourceDescription AS ResourceDescription,
	|	EnterpriseResourceTempTable.EnterpriseResource AS ResourcesQuant,
	|	EnterpriseResourceTempTable.EnterpriseResource AS EnterpriseResource
	|FROM
	|	EnterpriseResourceTempTable AS EnterpriseResourceTempTable
	|		LEFT JOIN (SELECT
	|			ProductionOrderEnterpriseResources.Ref AS Ref,
	|			ProductionOrderEnterpriseResources.EnterpriseResource AS EnterpriseResource,
	|			ProductionOrderEnterpriseResources.Start AS Start,
	|			ProductionOrderEnterpriseResources.Finish AS Finish
	|		FROM
	|			Document.ProductionOrder.EnterpriseResources AS ProductionOrderEnterpriseResources
	|		WHERE
	|			(NOT ProductionOrderEnterpriseResources.EnterpriseResource.DeletionMark)
	|			AND ProductionOrderEnterpriseResources.Ref.Posted
	|			AND ((NOT ProductionOrderEnterpriseResources.Ref.Closed)
	|					OR ProductionOrderEnterpriseResources.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|			AND ProductionOrderEnterpriseResources.Start between &StartDate AND &EndDate
	|			AND ProductionOrderEnterpriseResources.Finish between &StartDate AND &EndDate
	|			AND (&FilterCounterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|					OR ProductionOrderEnterpriseResources.Ref.CustomerOrder.Counterparty = &FilterCounterparty)
	|			AND (&FilterByKeyResource
	|					OR ProductionOrderEnterpriseResources.EnterpriseResource IN (&FilterKeyResourcesList))
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			CustomerOrderEnterpriseResources.Ref,
	|			CustomerOrderEnterpriseResources.EnterpriseResource,
	|			CustomerOrderEnterpriseResources.Start,
	|			CustomerOrderEnterpriseResources.Finish
	|		FROM
	|			Document.CustomerOrder.EnterpriseResources AS CustomerOrderEnterpriseResources
	|		WHERE
	|			CustomerOrderEnterpriseResources.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|			AND (NOT CustomerOrderEnterpriseResources.EnterpriseResource.DeletionMark)
	|			AND CustomerOrderEnterpriseResources.Ref.Posted
	|			AND ((NOT CustomerOrderEnterpriseResources.Ref.Closed)
	|					OR CustomerOrderEnterpriseResources.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|			AND CustomerOrderEnterpriseResources.Start between &StartDate AND &EndDate
	|			AND CustomerOrderEnterpriseResources.Finish between &StartDate AND &EndDate
	|			AND (&FilterCounterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|					OR CustomerOrderEnterpriseResources.Ref.Counterparty = &FilterCounterparty)
	|			AND (&FilterByKeyResource
	|					OR CustomerOrderEnterpriseResources.EnterpriseResource IN (&FilterKeyResourcesList))) AS NestedSelect
	|		ON EnterpriseResourceTempTable.EnterpriseResource = NestedSelect.EnterpriseResource
	|WHERE
	|	ISNULL(NestedSelect.Start, &BlankDate) <> &BlankDate
	|
	|ORDER BY
	|	ResourceDescription
	|TOTALS
	|	COUNT(DISTINCT ResourcesQuant)
	|BY
	|	BeginTime,
	|	EnterpriseResource";
	
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", EndDate);
	Query.SetParameter("BlankDate", '00010101');
	Query.SetParameter("FilterCounterparty", FilterCounterparty);
	Query.SetParameter("FilterByKeyResource", ResourcesList = Undefined);
	Query.SetParameter("FilterKeyResourcesList", ResourcesList);
	
	Return Query.ExecuteBatch();
	
EndFunction // GetResourcesImportScheduleWeekMonth()

// The function returns the value of cell decryption.
//
&AtServer
Function GetCellDetails(EnterpriseResource, Interval, KindOfInterval, OrdersList = Undefined)
	
	DetailsStructure = New Structure;
	DetailsStructure.Insert("EnterpriseResource", EnterpriseResource);
	DetailsStructure.Insert("Interval", Interval);
	DetailsStructure.Insert("KindOfInterval", KindOfInterval);
	DetailsStructure.Insert("OrdersList", OrdersList);
	
	Return DetailsStructure;
	
EndFunction // GetCellDecryption()

// function returns the value of the cell for the decryption of the week and month.
//
&AtServer
Function GetDetailsOfWeekMonthCell(Interval, OrdersList = Undefined)
	
	DetailsStructure = New Structure;
	DetailsStructure.Insert("Interval", Interval);
	DetailsStructure.Insert("OrdersList", OrdersList);
	
	Return DetailsStructure;
	
EndFunction // GetWeekMonthCellDecryption()

// The procedure displays the assistant if there are no resources.
//
&AtServer
Procedure ShowAssistant(Spreadsheet)
	
	AssistantTemplate = DataProcessors.Scheduler.GetTemplate("Assistant");
	Spreadsheet.Put(AssistantTemplate);
	
EndProcedure // ShowAssistant()

// The procedure adds a new application in the calendar.
//
&AtClient
Procedure CreateNewOrderDetailProcessing(Details)
	
	If WorksScheduleRadioButton = "Day" OR WorksScheduleRadioButton = "4days" Then
		OpenParameters = GetOrderOpeningParameters();
		If ShowProductionOrders AND ShowJobOrders Then
			OrdersList = New ValueList();
			OrdersList.Add("ProductionOrder", "Production order");
			OrdersList.Add("JobOrder", "Job-order");
			Notification = New NotifyDescription("DetailProcessingCreateNewOrderCompletion",ThisForm,OpenParameters);
			OrdersList.ShowChooseItem(Notification,"Select order type");
		ElsIf ShowProductionOrders Then
			OpenForm("Document.ProductionOrder.Form.RequestForm", OpenParameters);
		Else
			OpenForm("Document.CustomerOrder.Form.RequestForm", OpenParameters);
		EndIf;
	ElsIf WorksScheduleRadioButton = "Week" Then
		DayInCalendar = Details.Interval;
		WorksScheduleRadioButton = "Day";
		CalendarDate = DayInCalendar;
		CalendarDateBegin = BegOfDay(CalendarDate);
		CalendarDateEnd = EndOfDay(CalendarDate);
		GenerateScheduledWorksPeriod();
		UpdateCalendar();
	ElsIf WorksScheduleRadioButton = "Month" Then
		DayInCalendar = Details.Interval;
		WorksScheduleRadioButton = "Day";
		CalendarDate = DayInCalendar;
		CalendarDateBegin = BegOfDay(CalendarDate);
		CalendarDateEnd = EndOfDay(CalendarDate);
		GenerateScheduledWorksPeriod();
		UpdateCalendar();
	EndIf;
	
EndProcedure // DecryptionProcessorCreateNewOrder()

&AtClient
Procedure DetailProcessingCreateNewOrderCompletion(SelectedOrder,OpenParameters) Export
	
	If SelectedOrder <> Undefined Then
		If SelectedOrder.Value = "ProductionOrder" Then
			OpenForm("Document.ProductionOrder.Form.RequestForm", OpenParameters);
		Else
			OpenForm("Document.CustomerOrder.Form.RequestForm", OpenParameters);
		EndIf;
	EndIf;
	
EndProcedure

// The procedure allows you to view the information about orders in the time interval.
//
&AtClient
Procedure OrdersInformationDetailProcessing()
	
	CurrentCalendarArea = Items.ResourcesImport.CurrentArea;
	OrdersList = New ValueList;
	If WorksScheduleRadioButton = "Day" OR WorksScheduleRadioButton= "4days" Then
		FirstRow = CurrentCalendarArea.Top;
		LastRow = CurrentCalendarArea.Bottom;
		LastColumn = CurrentCalendarArea.Right;
		While FirstRow <= LastRow Do
			FirstColumn = CurrentCalendarArea.Left;
			While FirstColumn <= LastColumn Do
				CellDetails = ResourcesImport.Area(FirstRow, FirstColumn).Details;
				If TypeOf(CellDetails) = Type("Structure") Then
					If CellDetails.OrdersList <> Undefined Then
						For Each OrderItm IN CellDetails.OrdersList Do
							OrdersList.Add(OrderItm);
						EndDo;
					EndIf;
				EndIf;
				FirstColumn = FirstColumn + 1;
			EndDo;
			FirstRow = FirstRow + 1;
		EndDo;
	Else
		CellDetails = CurrentCalendarArea.Details;
		If TypeOf(CellDetails) = Type("Structure") Then
			If CellDetails.OrdersList <> Undefined Then
				For Each OrderItm IN CellDetails.OrdersList Do
					OrdersList.Add(OrderItm);
				EndDo;
			EndIf;
		EndIf;
	EndIf;
	
	FilterParameters = New Structure;
	FilterParameters.Insert("FilterOrders", OrdersList);
	FilterParameters.Insert("TimeLimitFrom", TimeLimitFrom);
	FilterParameters.Insert("TimeLimitTo", TimeLimitTo);
	FilterParameters.Insert("ShowJobOrders", ShowJobOrders);
	FilterParameters.Insert("ShowProductionOrders", ShowProductionOrders);
	FilterParameters.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	
	If OrdersList.Count() = 1 Then
		FilterParameters.Insert("Key", OrdersList[0].Value);
		If TypeOf(OrdersList[0].Value) = Type("DocumentRef.ProductionOrder") Then
			OpenForm("Document.ProductionOrder.Form.RequestForm", FilterParameters,,,,,,FormWindowOpeningMode.LockOwnerWindow);
		Else
			OpenForm("Document.CustomerOrder.Form.RequestForm", FilterParameters,,,,,,FormWindowOpeningMode.LockOwnerWindow);
		EndIf;
	Else
		OpenForm("DataProcessor.Scheduler.Form.OrdersChoiceForm", New Structure("FilterParameters", FilterParameters),,,,,,FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure // OrdersInformationDecryptionProcessor()

////////////////////////////////////////////////////////////////////////////////
// DIAGRAM (RESOURCES UPLOAD)

// The procedure updates data of schedule chart diagram.
//
&AtServer
Procedure RefreshChartOfResources()
	
	// Initialization.
	GanttChartResourcesImport.ShowLegend = False;
	GanttChartResourcesImport.RefreshEnabled = False;
	
	GanttChartResourcesImport.Clear();
	
	GanttChartResourcesImport.AutoDetectWholeInterval = False;
	GanttChartResourcesImport.ValueTextRepresentation = GanttChartValueTextRepresentation.Right;
	
	GenerateTimeScaleOfGanttChart(GanttChartResourcesImport);
	
	ResourcesList = GetListOfResourcesForFilter();
	
	// Filling.
	QueryResult = GetResourcesWorkImport(ResourcesList);
	Series = GanttChartResourcesImport.Series.Add();
	
	OverlappingIntervalsColor = New Color(255, 0, 0);
	
	Series.SecondColor = OverlappingIntervalsColor;
	Series.OverlappedIntervalsHatch = True;
	
	SelectionResource = QueryResult.Select(QueryResultIteration.ByGroups, "Resource");
	While SelectionResource.Next() Do
		
		PointResource = GanttChartResourcesImport.SetPoint(SelectionResource.Resource);
		ValueResource = GanttChartResourcesImport.GetValue(PointResource, Series);
		
		PointResource.Details = SelectionResource.Resource;
		
		Selection = SelectionResource.Select();
		While Selection.Next() Do
			
			DotValue = StrReplace(String(Selection.Ref.UUID()), "-", "") + StrReplace(String(SelectionResource.Resource.UUID()), "-", "");
			Point = GanttChartResourcesImport.SetPoint(DotValue, SelectionResource.Resource);
			Point.Text = NStr("en='" + Format(Selection.Start, "DF=""HH:mm""") + " - "
							+ Format(Selection.Finish, "DF=""HH:mm""") + " (# "
							+ ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True) + " dated " 
							+ Format(Selection.Date, "DF=dd.MM.yy") + ") '");
			Point.Details = Selection.Ref;
			
			Interval = ValueResource.Add();
			Interval.Details = Selection.Resource;
			Interval.Begin = Selection.Start;
			Interval.End = Selection.Finish;
			Interval.Color = StyleColors.ReportGroup1BackColor;
			
			If Selection.Closed Then
				Point.Picture = PictureLib.LockFile;
			Else
				Point.Picture = PictureLib.ReleaseFile;
			EndIf;
			
			ValueOfOrder = GanttChartResourcesImport.GetValue(Point, Series);
			ValueOfOrder.Edit = False;
			
			Interval = ValueOfOrder.Add();
			Interval.Details = Selection.Ref;
			Interval.Begin = Selection.Start;
			Interval.End = Selection.Finish;
			BackColor = Selection.Color.Get();
			If TypeOf(BackColor) = Type("Color") Then
				Interval.Color = BackColor;
			EndIf;
			
			Interval.Value.Text = Selection.Counterparty;
			
			ValueText = NStr("en='Import: " + Selection.Import + "
								|Counterparty: " + Selection.Counterparty + "
								|Responsible: " + Selection.Responsible + "
								|Department: " + Selection.Department + "'");
			
			Interval.Text  = ValueText;
			
		EndDo;
		
	EndDo;
	
	For Each GanttChartPoint in GanttChartResourcesImport.Points Do
		
		GanttChartResourcesImport.ExpandPoint(GanttChartPoint, True);
		
	EndDo;
	
	GanttChartResourcesImport.RefreshEnabled = True;
	
EndProcedure // UpdateResourcesChart()

// The function returns the query result.
//
&AtServer
Function GetResourcesWorkImport(ResourcesList)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	NestedSelect.Ref,
	|	NestedSelect.Date,
	|	NestedSelect.Number,
	|	NestedSelect.OperationKind,
	|	NestedSelect.Closed,
	|	NestedSelect.Color AS Color,
	|	NestedSelect.Start AS Start,
	|	NestedSelect.Finish AS Finish,
	|	NestedSelect.EnterpriseResource AS Resource,
	|	NestedSelect.Capacity AS Import,
	|	NestedSelect.Counterparty AS Counterparty,
	|	NestedSelect.Department,
	|	NestedSelect.Responsible
	|FROM
	|	(SELECT
	|		ProductionOrderEnterpriseResources.Ref AS Ref,
	|		ProductionOrderEnterpriseResources.Ref.Date AS Date,
	|		ProductionOrderEnterpriseResources.Ref.Number AS Number,
	|		ProductionOrderEnterpriseResources.Ref.OperationKind AS OperationKind,
	|		ProductionOrderEnterpriseResources.Ref.Closed AS Closed,
	|		ProductionOrderEnterpriseResources.Ref.OrderState.Color AS Color,
	|		ProductionOrderEnterpriseResources.EnterpriseResource AS EnterpriseResource,
	|		ProductionOrderEnterpriseResources.Capacity AS Capacity,
	|		ProductionOrderEnterpriseResources.Start AS Start,
	|		ProductionOrderEnterpriseResources.Finish AS Finish,
	|		ProductionOrderEnterpriseResources.Ref.CustomerOrder.Counterparty AS Counterparty,
	|		ProductionOrderEnterpriseResources.Ref.Responsible AS Responsible,
	|		ProductionOrderEnterpriseResources.Ref.StructuralUnit AS Department
	|	FROM
	|		Document.ProductionOrder.EnterpriseResources AS ProductionOrderEnterpriseResources
	|	WHERE
	|		(NOT ProductionOrderEnterpriseResources.EnterpriseResource.DeletionMark)
	|		AND ProductionOrderEnterpriseResources.Ref.Posted
	|		AND ((NOT ProductionOrderEnterpriseResources.Ref.Closed)
	|				OR ProductionOrderEnterpriseResources.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|		AND ProductionOrderEnterpriseResources.Start between &StartDate AND &EndDate
	|		AND ProductionOrderEnterpriseResources.Finish between &StartDate AND &EndDate
	|		AND (&FilterCounterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|				OR ProductionOrderEnterpriseResources.Ref.CustomerOrder.Counterparty = &FilterCounterparty)
	|		AND (&FilterByKeyResource
	|				OR ProductionOrderEnterpriseResources.EnterpriseResource IN (&FilterKeyResourcesList))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CustomerOrderEnterpriseResources.Ref,
	|		CustomerOrderEnterpriseResources.Ref.Date,
	|		CustomerOrderEnterpriseResources.Ref.Number,
	|		CustomerOrderEnterpriseResources.Ref.OperationKind,
	|		CustomerOrderEnterpriseResources.Ref.Closed,
	|		CustomerOrderEnterpriseResources.Ref.OrderState.Color,
	|		CustomerOrderEnterpriseResources.EnterpriseResource,
	|		CustomerOrderEnterpriseResources.Capacity,
	|		CustomerOrderEnterpriseResources.Start,
	|		CustomerOrderEnterpriseResources.Finish,
	|		CustomerOrderEnterpriseResources.Ref.Counterparty,
	|		CustomerOrderEnterpriseResources.Ref.Responsible,
	|		CustomerOrderEnterpriseResources.Ref.SalesStructuralUnit
	|	FROM
	|		Document.CustomerOrder.EnterpriseResources AS CustomerOrderEnterpriseResources
	|	WHERE
	|		CustomerOrderEnterpriseResources.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|		AND (NOT CustomerOrderEnterpriseResources.EnterpriseResource.DeletionMark)
	|		AND CustomerOrderEnterpriseResources.Ref.Posted
	|		AND ((NOT CustomerOrderEnterpriseResources.Ref.Closed)
	|				OR CustomerOrderEnterpriseResources.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|		AND CustomerOrderEnterpriseResources.Start between &StartDate AND &EndDate
	|		AND CustomerOrderEnterpriseResources.Finish between &StartDate AND &EndDate
	|		AND (&FilterCounterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|				OR CustomerOrderEnterpriseResources.Ref.Counterparty = &FilterCounterparty)
	|		AND (&FilterByKeyResource
	|				OR CustomerOrderEnterpriseResources.EnterpriseResource IN (&FilterKeyResourcesList))) AS NestedSelect
	|
	|ORDER BY
	|	Resource,
	|	Start,
	|	Finish
	|TOTALS BY
	|	Resource";
	
	Query.SetParameter("StartDate", CalendarDateBegin);
	Query.SetParameter("EndDate", CalendarDateEnd);
	Query.SetParameter("FilterCounterparty", FilterCounterparty);
	Query.SetParameter("FilterByKeyResource", ResourcesList = Undefined);
	Query.SetParameter("FilterKeyResourcesList", ResourcesList);
	
	Return Query.Execute();
	
EndFunction // GetResourcesImport()

// Procedure - DecryptionProcessor event handler.
//
&AtClient
Procedure GanttChartOfResourcesDetailProcessing(Item, details, StandardProcessing, Date)
	
	SelectedOrder = Undefined;
	
	If TypeOf(details) = Type("DocumentRef.ProductionOrder")
		OR TypeOf(details) = Type("DocumentRef.CustomerOrder") Then
		SelectedOrder = details;
	ElsIf TypeOf(details) = Type("Array") Then
		For Each DetailsItm IN details Do
			
			If TypeOf(DetailsItm) = Type("DocumentRef.ProductionOrder")
				OR TypeOf(DetailsItm) = Type("DocumentRef.CustomerOrder") Then
				SelectedOrder = DetailsItm;
			EndIf;
			
		EndDo;
	EndIf;
	
	If SelectedOrder <> Undefined Then
		
		StandardProcessing = False;
		
		OpenParameters = New Structure;
		OpenParameters.Insert("Key", SelectedOrder);
		If ValueIsFilled(Date) Then
			OpenParameters.Insert("CalendarDate", Date);
		EndIf;
		OpenParameters.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
		OpenParameters.Insert("TimeLimitTo", TimeLimitTo);
		OpenParameters.Insert("TimeLimitFrom", TimeLimitFrom);
		OpenParameters.Insert("ShowJobOrders", ShowJobOrders);
		OpenParameters.Insert("ShowProductionOrders", ShowProductionOrders);
		
		If TypeOf(SelectedOrder) = Type("DocumentRef.ProductionOrder") Then
			OpenForm("Document.ProductionOrder.Form.RequestForm", OpenParameters, Items.List,,,,,FormWindowOpeningMode.LockOwnerWindow);
		Else
			OpenForm("Document.CustomerOrder.Form.RequestForm", OpenParameters, Items.List,,,,,FormWindowOpeningMode.LockOwnerWindow);
		EndIf;
		
	EndIf;
	
EndProcedure // GanttDiagramResourcesDecryptionProcessor()

////////////////////////////////////////////////////////////////////////////////
// Form settings

// Procedure saves the form settings.
//
&AtServerNoContext
Procedure SaveFormSettings(SettingsStructure, KeepForWork)
	
	If KeepForWork Then
		FormDataSettingsStorage.Save("WorkScheduler", "SettingsStructure", SettingsStructure);
	Else
		FormDataSettingsStorage.Save("ProductionScheduler", "SettingsStructure", SettingsStructure);
	EndIf;
	
	FormDataSettingsStorage.Save("Scheduler", "SettingsStructure", Undefined);
	
EndProcedure // SaveFormSettings()

// Procedure imports the form settings.
//
&AtServer
Procedure ImportFormSettings()
	
	SettingsStructure = FormDataSettingsStorage.Load("Scheduler", "SettingsStructure");
	If SettingsStructure = Undefined Then
		
		If WorksOnly Then
			SettingsStructure = FormDataSettingsStorage.Load("WorkScheduler", "SettingsStructure");
		Else
			SettingsStructure = FormDataSettingsStorage.Load("ProductionScheduler", "SettingsStructure");
		EndIf;
		
	EndIf;
		
	If TypeOf(SettingsStructure) = Type("Structure") Then
		
		If SettingsStructure.Property("WorksScheduleRadioButton") Then
			WorksScheduleRadioButton = SettingsStructure.WorksScheduleRadioButton;
		Else
			WorksScheduleRadioButton = "Day";
		EndIf;
		
		If SettingsStructure.Property("TimeLimitFrom") Then
			TimeLimitFrom = SettingsStructure.TimeLimitFrom;
		Else
			TimeLimitFrom = '00010101090000';
		EndIf;
		
		If SettingsStructure.Property("TimeLimitTo") Then
			TimeLimitTo = SettingsStructure.TimeLimitTo;
		Else
			TimeLimitTo = '00010101210000';
		EndIf;
		
		If SettingsStructure.Property("RepetitionFactorOFDay") Then
			RepetitionFactorOFDay = SettingsStructure.RepetitionFactorOFDay;
		Else
			RepetitionFactorOFDay = 30;
		EndIf;
		
		If SettingsStructure.Property("SchedulerCurrentPage") Then
			Items.Body.CurrentPage = Items[SettingsStructure.SchedulerCurrentPage];
		EndIf;
		
		If SettingsStructure.Property("KindChartPlanRadioButton") Then
			
			KindChartPlanRadioButton = SettingsStructure.KindChartPlanRadioButton;
			
			If KindChartPlanRadioButton = "List" Then
				Items.GroupOfListAndChartEditing.CurrentPage = Items.ListCommands;
				Items.ListAndChart.CurrentPage = Items.ListSchedule;
			Else
				Items.GroupOfListAndChartEditing.CurrentPage = Items.ScheduleChartCommands;
				Items.ListAndChart.CurrentPage = Items.ChartSchedule;
			EndIf;
			
		EndIf;
		
		If SettingsStructure.Property("CalendarKindRadioButton") Then
			
			CalendarKindRadioButton = SettingsStructure.CalendarKindRadioButton;
			
			If CalendarKindRadioButton = "Calendar" Then
				Items.GroupCalendarAndChartEditing.CurrentPage = Items.CalendarCommands;
				Items.CalendarAndChart.CurrentPage = Items.CalendarResources;
			Else
				Items.GroupCalendarAndChartEditing.CurrentPage = Items.CommandsChartResources;
				Items.CalendarAndChart.CurrentPage = Items.ChartResources;
			EndIf;
			
		EndIf;
		
		If SettingsStructure.Property("FilterCounterparty") Then
			FilterCounterparty = SettingsStructure.FilterCounterparty;
		EndIf;
		
		If SettingsStructure.Property("FilterKeyResource") Then
			FilterKeyResource = SettingsStructure.FilterKeyResource;
		EndIf;
		
		If SettingsStructure.Property("FilterResourceKind") Then
			FilterResourceKind = SettingsStructure.FilterResourceKind;
		EndIf;
		
		If SettingsStructure.Property("FilterResponsible") Then
			FilterResponsible = SettingsStructure.FilterResponsible;
		EndIf;
		
		If SettingsStructure.Property("ShowJobOrders") Then
			ShowJobOrders = SettingsStructure.ShowJobOrders;
		ElsIf WorksOnly Then
			ShowJobOrders = True;
		EndIf;
		
		If SettingsStructure.Property("ShowProductionOrders") Then
			ShowProductionOrders = SettingsStructure.ShowProductionOrders;
		ElsIf Not WorksOnly Then
			ShowProductionOrders = True;
		EndIf;
		
	Else
		
		WorksScheduleRadioButton = "Day";
		
		TimeLimitFrom = '00010101090000';
		TimeLimitTo = '00010101210000';
		
		RepetitionFactorOFDay = 30;
		
		If WorksOnly Then
			ShowJobOrders = True;
		Else
			ShowProductionOrders = True;
		EndIf;
		
		Items.Body.CurrentPage = Items.PanelSchedule;
		
		KindChartPlanRadioButton = "List";
		CalendarKindRadioButton = "Calendar";
		
		Items.GroupOfListAndChartEditing.CurrentPage = Items.ListCommands;
		Items.ListAndChart.CurrentPage = Items.ListSchedule;
		Items.GroupCalendarAndChartEditing.CurrentPage = Items.CalendarCommands;
		Items.CalendarAndChart.CurrentPage = Items.CalendarResources;
		
		UpdateScheduleChartList();
		
	EndIf;
	
EndProcedure // ImportFormSettings()

////////////////////////////////////////////////////////////////////////////////
// MANAGEMENT OF FORM APPEARANCE

// The procedure manages the availability of form items.
//
&AtClient
Procedure SetEnabledOfItemsOnForm()
	
	Items.AddJobOrderList.Enabled = ShowJobOrders;
	Items.AddProductionOrderList.Enabled = ShowProductionOrders;
	
	Items.KMAddJobOrder.Enabled = ShowJobOrders;
	Items.KMAddProductionOrder.Enabled = ShowProductionOrders;
	
	Items.AddJobOrderChartSchedule.Enabled = ShowJobOrders;
	Items.AddProductionOrderChartSchedule.Enabled = ShowProductionOrders;
	
	Items.ResourcesAddJobOrder.Enabled = ShowJobOrders;
	Items.ResourcesAddProductionOrder.Enabled = ShowProductionOrders;
	
	Items.ResourcesAddJobOrderChart.Enabled = ShowJobOrders;
	Items.ResourcesAddProductionOrderChart.Enabled = ShowProductionOrders;
	
	Items.KMAddJobOrderPW.Enabled = ShowJobOrders;
	Items.KMAddProductionOrderPW.Enabled = ShowProductionOrders;
	
EndProcedure // SetItemsOnFormAvailability()

// The procedure controls the visible of form items.
//
&AtServer
Procedure SetVisibleOfItemsOnForm()
	
	If ShowJobOrders AND ShowProductionOrders Then
		
		Items.GroupAdd.Visible = True;
		Items.GroupAddChartPlanLine.Visible = True;
		
		Items.ResourcesGroupAdd.Visible = True;
		Items.ResourcesGroupAddChart.Visible = True;
		
		Items.CreateJobOrderList.Visible = False;
		Items.CreateProductionOrderList.Visible = False;
		
		Items.KMGroupAdd.Visible = True;
		
		Items.KMCreateJobOrder.Visible = False;
		Items.KMCreateProductionOrder.Visible = False;
		
		Items.CreateJobOrderChartScheduler.Visible = False;
		Items.CreateProductionOrderChartSchedule.Visible = False;
		
		Items.ResourcesCreateJobOrder.Visible = False;
		Items.ResourcesCreateProductionOrder.Visible = False;
		
		Items.KMGroupAddPW.Visible = True;
		
		Items.KMCreateJobOrderPW.Visible = False;
		Items.KMCreateProductionOrderSP.Visible = False;
		
		Items.ResourcesCreateJobOrderChart.Visible = False;
		Items.ResourcesCreateProductionOrderChart.Visible = False;
		
		If Not Constants.UseCustomerOrderStates.Get()
			AND Not Constants.UseProductionOrderStates.Get() Then
			
			Items.ListOrderStatus.Visible = True;
			
			Items.ListOrderState.Visible = False;
			Items.ListIsClosed.Visible = False;
			
		Else
			
			Items.ListOrderStatus.Visible = False;
			
			Items.ListOrderState.Visible = True;
			Items.ListIsClosed.Visible = True;
			
		EndIf;
		
	ElsIf ShowJobOrders Then
		
		Items.GroupAdd.Visible = False;
		Items.GroupAddChartPlanLine.Visible = False;
		
		Items.ResourcesGroupAdd.Visible = False;
		Items.ResourcesGroupAddChart.Visible = False;
		
		Items.CreateJobOrderList.Visible = True;
		Items.CreateProductionOrderList.Visible = False;
		
		Items.KMGroupAdd.Visible = False;
		
		Items.KMCreateJobOrder.Visible = True;
		Items.KMCreateProductionOrder.Visible = False;
		
		Items.CreateJobOrderChartScheduler.Visible = True;
		Items.CreateProductionOrderChartSchedule.Visible = False;
		
		Items.ResourcesCreateJobOrder.Visible = True;
		Items.ResourcesCreateProductionOrder.Visible = False;
		
		Items.KMGroupAddPW.Visible = False;
		
		Items.KMCreateJobOrderPW.Visible = True;
		Items.KMCreateProductionOrderSP.Visible = False;
		
		Items.ResourcesCreateJobOrderChart.Visible = True;
		Items.ResourcesCreateProductionOrderChart.Visible = False;
		
		If Constants.UseCustomerOrderStates.Get() Then
			
			Items.ListOrderStatus.Visible = False;
			
			Items.ListOrderState.Visible = True;
			Items.ListIsClosed.Visible = True;
			
		Else
			
			Items.ListOrderStatus.Visible = True;
			
			Items.ListOrderState.Visible = False;
			Items.ListIsClosed.Visible = False;
			
		EndIf;
		
	Else
		
		Items.GroupAdd.Visible = False;
		Items.GroupAddChartPlanLine.Visible = False;
		
		Items.ResourcesGroupAdd.Visible = False;
		Items.ResourcesGroupAddChart.Visible = False;
		
		Items.CreateJobOrderList.Visible = False;
		Items.CreateProductionOrderList.Visible = True;
		
		Items.KMGroupAdd.Visible = False;
		
		Items.KMCreateJobOrder.Visible = False;
		Items.KMCreateProductionOrder.Visible = True;
		
		Items.CreateJobOrderChartScheduler.Visible = False;
		Items.CreateProductionOrderChartSchedule.Visible = True;
		
		Items.ResourcesCreateJobOrder.Visible = False;
		Items.ResourcesCreateProductionOrder.Visible = True;
		
		Items.KMGroupAddPW.Visible = False;
		
		Items.KMCreateJobOrderPW.Visible = False;
		Items.KMCreateProductionOrderSP.Visible = True;
		
		Items.ResourcesCreateJobOrderChart.Visible = False;
		Items.ResourcesCreateProductionOrderChart.Visible = True;
		
		If Constants.UseProductionOrderStates.Get() Then
			
			Items.ListOrderStatus.Visible = False;
			
			Items.ListOrderState.Visible = True;
			Items.ListIsClosed.Visible = True;
			
		Else
			
			Items.ListOrderStatus.Visible = True;
			
			Items.ListOrderState.Visible = False;
			Items.ListIsClosed.Visible = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure // SetItemsOnFormVisible()

// The procedure colors the list. - Plan - work schedule.
//
&AtServer
Procedure PaintList()
	
	// List coloring.
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem IN List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item IN ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	PaintByStateJobOrders = Constants.UseCustomerOrderStates.Get();
	If Not PaintByStateJobOrders Then
		InProcessStatus = Constants.CustomerOrdersInProgressStatus.Get();
		BackColorInProcessJobOrder = InProcessStatus.Color.Get();
		CompletedStatus = Constants.CustomerOrdersCompletedStatus.Get();
		BackColorCompletedJobOrder = CompletedStatus.Color.Get();
	EndIf;
	
	SelectionJobOrderStates = Catalogs.CustomerOrderStates.Select();
	While SelectionJobOrderStates.Next() Do
		
		If PaintByStateJobOrders Then
			BackColor = SelectionJobOrderStates.Color.Get();
			If TypeOf(BackColor) <> Type("Color") Then
				Continue;
			EndIf;
		Else
			If SelectionJobOrderStates.OrderStatus = Enums.OrderStatuses.InProcess Then
				If TypeOf(BackColorInProcessJobOrder) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorInProcessJobOrder;
			ElsIf SelectionJobOrderStates.OrderStatus = Enums.OrderStatuses.Completed Then
				If TypeOf(BackColorCompletedJobOrder) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorCompletedJobOrder;
			Else
				Continue;
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		If PaintByStateJobOrders Then
			FilterItem.LeftValue = New DataCompositionField("WorkOdrerState");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = SelectionJobOrderStates.Ref;
		Else
			FilterItem.LeftValue = New DataCompositionField("JobOrderStatus");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			If SelectionJobOrderStates.OrderStatus = Enums.OrderStatuses.InProcess Then
				FilterItem.RightValue = "In process";
			Else
				FilterItem.RightValue = "Completed";
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColor);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "By job order state " + SelectionJobOrderStates.Description;
		
	EndDo;
	
	If Not PaintByStateJobOrders Then
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("JobOrderStatus");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = "Canceled";
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		If TypeOf(BackColorCompletedJobOrder) = Type("Color") Then
			ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColorCompletedJobOrder);
		EndIf;
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "Job-order is cancelled";
		
	EndIf;
	
	If PaintByStateJobOrders Then
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Closed");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = True;
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "Order is closed";
		
	EndIf;
	
	If WorksOnly Then
		Return;
	EndIf;
	
	PaintByStateProductionOrders = Constants.UseProductionOrderStates.Get();
	If Not PaintByStateProductionOrders Then
		InProcessStatus = Constants.ProductionOrdersInProgressStatus.Get();
		BackColorInProcessProductionOrder = InProcessStatus.Color.Get();
		CompletedStatus = Constants.ProductionOrdersCompletedStatus.Get();
		BackColorCompletedProductionOrder = CompletedStatus.Color.Get();
	EndIf;
	
	SelectionProductionOrderStates = Catalogs.ProductionOrderStates.Select();
	While SelectionProductionOrderStates.Next() Do
		
		If PaintByStateProductionOrders Then
			BackColor = SelectionProductionOrderStates.Color.Get();
			If TypeOf(BackColor) <> Type("Color") Then
				Continue;
			EndIf;
		Else
			If SelectionProductionOrderStates.OrderStatus = Enums.OrderStatuses.InProcess Then
				If TypeOf(BackColorInProcessProductionOrder) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorInProcessProductionOrder;
			ElsIf SelectionProductionOrderStates.OrderStatus = Enums.OrderStatuses.Completed Then
				If TypeOf(BackColorCompletedProductionOrder) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorCompletedProductionOrder;
			Else
				Continue;
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		If PaintByStateProductionOrders Then
			FilterItem.LeftValue = New DataCompositionField("ProductionOrderState");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = SelectionProductionOrderStates.Ref;
		Else
			FilterItem.LeftValue = New DataCompositionField("ProductionOrderStatus");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			If SelectionProductionOrderStates.OrderStatus = Enums.OrderStatuses.InProcess Then
				FilterItem.RightValue = "In process";
			Else
				FilterItem.RightValue = "Completed";
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColor);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "By the state of production order " + SelectionProductionOrderStates.Description;
		
	EndDo;
	
	If Not PaintByStateJobOrders
		AND PaintByStateProductionOrders Then // add an item of conditional appearance if it was not previously added
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Closed");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = True;
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "Order is closed";
		
	EndIf;
	
	If Not PaintByStateProductionOrders Then
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("ProductionOrderStatus");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = "Canceled";
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		If TypeOf(BackColorCompletedProductionOrder) = Type("Color") Then
			ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColorCompletedProductionOrder);
		EndIf;
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "Production order cancelled";
		
	EndIf;
	
EndProcedure // PaintList()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("WorksOnly") Then
		WorksOnly = Parameters.WorksOnly;
	Else
		WorksOnly = True;
	EndIf;
	
	ImportFormSettings();
	
	OperationKindJobOrder = Enums.OperationKindsCustomerOrder.JobOrder;
	
	CalendarDate = CurrentDate();
	
	If WorksScheduleRadioButton = "Week" Then
		
		CalendarDateBegin = BegOfWeek(CalendarDate);
		CalendarDateEnd = EndOfWeek(CalendarDate);
		
	ElsIf WorksScheduleRadioButton = "Month" Then
		
		CalendarDateBegin = BegOfMonth(CalendarDate);
		CalendarDateEnd = EndOfMonth(CalendarDate);
		
	ElsIf WorksScheduleRadioButton= "4days" Then
		
		CalendarDateBegin = BegOfDay(CalendarDate);
		CalendarDateEnd = EndOfDay(CalendarDate) + 3 *60 * 60 * 24;
		
	Else
		
		CalendarDateBegin = BegOfDay(CalendarDate);
		CalendarDateEnd = EndOfDay(CalendarDate);
		
	EndIf;
	
	If Users.InfobaseUserWithFullAccess() OR (IsInRole("OutputToPrinterClipboardFile")
		AND EmailOperations.CheckSystemAccountAvailable())Then
		SystemEmailAccount = EmailOperations.SystemAccount();
	Else
		Items.InformationCounterpartyEmail.Hyperlink = False;
		Items.InformationContactPersonEmail.Hyperlink = False;
	EndIf;
	
	If Not Constants.FunctionalOptionPlanEnterpriseResourcesImporting.Get() Then
		Items.PanelResourcesLoad.Visible = False;
		Items.Body.PagesRepresentation = FormPagesRepresentation.None;
		Items.Body.CurrentPage = Items.PanelSchedule;
		Items.InCommandsListAndChart.ShowTitle = True;
		Items.InCommandsListAndChart.Representation = UsualGroupRepresentation.WeakSeparation;
		Items.ListKeyResources.Visible = False;
		FilterKeyResource = Undefined;
	EndIf;
	
	PaintList();
	
	SetPeriodOfListFilter();
	
	// Schedule chart.
	If Items.Body.CurrentPage = Items.PanelSchedule Then
		// Schedule chart: chart.
		If Items.GroupOfListAndChartEditing.CurrentPage = Items.ScheduleChartCommands Then
			Items.ListAndChart.CurrentPage = Items.ChartSchedule;
			UpdateScheduleChart();
		Else // Schedule chart: list.
			UpdateScheduleChartList();
		EndIf;
		
	Else // Resources import.
		// Resources import: chart.
		If CalendarKindRadioButton = "Chart" Then
			RefreshChartOfResources();
		Else // Resources import: calendar
			UpdateCalendar();
		EndIf;
		
	EndIf;
	
	SetVisibleOfItemsOnForm();
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
EndProcedure // OnCreateAtServer()

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	GenerateScheduledWorksPeriod();
	SetEnabledOfItemsOnForm();
	
EndProcedure // OnOpen()

&AtClient
// Procedure - event handler OnClose form.
//
Procedure OnClose()
	
	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("WorksScheduleRadioButton", WorksScheduleRadioButton);
	
	SettingsStructure.Insert("TimeLimitFrom", TimeLimitFrom);
	SettingsStructure.Insert("TimeLimitTo", TimeLimitTo);
	
	SettingsStructure.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	
	SettingsStructure.Insert("KindChartPlanRadioButton", KindChartPlanRadioButton);
	SettingsStructure.Insert("CalendarKindRadioButton", CalendarKindRadioButton);
	
	SettingsStructure.Insert("FilterResourceKind", FilterResourceKind);
	SettingsStructure.Insert("FilterKeyResource", FilterKeyResource);
	SettingsStructure.Insert("FilterCounterparty", FilterCounterparty);
	SettingsStructure.Insert("FilterResponsible", FilterResponsible);
	SettingsStructure.Insert("ShowJobOrders", ShowJobOrders);
	SettingsStructure.Insert("ShowProductionOrders", ShowProductionOrders);
	
	SettingsStructure.Insert("SchedulerCurrentPage", Items.Body.CurrentPage.Name);
	
	SaveFormSettings(SettingsStructure, WorksOnly);
	
EndProcedure // OnClose()

// Procedure - handler of form notification.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	If EventName = "NotificationAboutChangingDebt"
		AND Items.Body.CurrentPage = Items.PanelSchedule
		AND KindChartPlanRadioButton = "List" Then
		// Schedule chart: list.
		UpdateListAtServer();
	EndIf;
		
	If EventName = "Record_CustomerOrderStates"
	 OR EventName = "Record_ProductionOrderStates" Then
		
		// Schedule chart.
		If Items.Body.CurrentPage = Items.PanelSchedule Then
			// Schedule chart: chart.
			If KindChartPlanRadioButton = "Chart" Then
				UpdateScheduleChart();
			Else // Schedule chart: list.
				PaintList();
			EndIf;
		ElsIf CalendarKindRadioButton = "Chart" Then // Resources import: chart.
			RefreshChartOfResources();
		EndIf;
		
	EndIf;
	
	If EventName = "ChangedJobOrder"
	 OR EventName = "ChangedProductionOrder"
	 OR EventName = "Record_KeyResources" Then
		
		// Schedule chart.
		If Items.Body.CurrentPage = Items.PanelSchedule Then
			// Schedule chart: chart.
			If KindChartPlanRadioButton = "Chart" Then
				UpdateScheduleChart();
			Else // Schedule chart: list.
				UpdateScheduleChartList();
			EndIf;
			
		Else // Resources import.
			// Resources import: chart.
			If CalendarKindRadioButton = "Chart" Then
				RefreshChartOfResources();
			Else // Resources import: calendar
				UpdateCalendar();
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - HEADER COMMAND HANDLERS

// Procedure - handler of Calendar command.
//
&AtClient
Procedure PeriodPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ParametersStructure = New Structure("CalendarDate", CalendarDate);
	Notification = New NotifyDescription("PeriodPresentationStartChoiceEnd",ThisForm);
	OpenForm("CommonForm.CalendarForm", ParametersStructure,,,,,Notification);
	
EndProcedure // PeriodPresentationStartChoice()

&AtClient
Procedure PeriodPresentationStartChoiceEnd(Result,Parameters) Export
	
	If Not ValueIsFilled(Result) Then
		Return;
	EndIf;
	
	CalendarDateBegin = Result;
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	CalendarDate = EndOfDay(CalendarDateBegin);
	GenerateScheduledWorksPeriod();
	
	// Schedule chart.
	If Items.Body.CurrentPage = Items.PanelSchedule Then
		// Schedule chart: chart.
		If KindChartPlanRadioButton = "Chart" Then
			UpdateScheduleChart();
		Else // Schedule chart: list.
			SetPeriodOfListFilter();
		EndIf;
		
	Else // Resources import.
		// Resources import: chart.
		If CalendarKindRadioButton = "Chart" Then
			RefreshChartOfResources();
		Else // Resources import: calendar
			UpdateCalendar();
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - Day, 4 days, Week, Month command handler.
//
&AtClient
Procedure RadioButtonOnChange(Item)
	
	If WorksScheduleRadioButton = "Month" Then
		MonthPeriod();
	ElsIf WorksScheduleRadioButton = "4days" Then
		Period4Days();
	ElsIf WorksScheduleRadioButton = "Week" Then
		WeekPeriod();
	Else
		DayPeriod();
	EndIf;
	
EndProcedure // SwitchOnChange()

// Procedure - command handler Day.
//
&AtClient
Procedure DayPeriod()
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	GenerateScheduledWorksPeriod();
	
	// Schedule chart.
	If Items.Body.CurrentPage = Items.PanelSchedule Then
		// Schedule chart: chart.
		If KindChartPlanRadioButton = "Chart" Then
			UpdateScheduleChart();
		Else // Schedule chart: list.
			SetPeriodOfListFilter();
		EndIf;
		
	Else // Resources import.
		// Resources import: chart.
		If CalendarKindRadioButton = "Chart" Then
			RefreshChartOfResources();
		Else // Resources import: calendar
			UpdateCalendar();
		EndIf;
		
	EndIf;
	
EndProcedure // DayPeriod()

// Procedure - command handler 2 days.
//
&AtClient
Procedure Period4Days()
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	GenerateScheduledWorksPeriod();
	
	// Schedule chart.
	If Items.Body.CurrentPage = Items.PanelSchedule Then
		// Schedule chart: chart.
		If KindChartPlanRadioButton = "Chart" Then
			UpdateScheduleChart();
		Else // Schedule chart: list.
			SetPeriodOfListFilter();
		EndIf;
		
	Else // Resources import.
		// Resources import: chart.
		If CalendarKindRadioButton = "Chart" Then
			RefreshChartOfResources();
		Else // Resources import: calendar
			UpdateCalendar();
		EndIf;
		
	EndIf;
	
EndProcedure // Period4Days()

// Procedure - command  handler Week.
//
&AtClient
Procedure WeekPeriod()
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	GenerateScheduledWorksPeriod();
	
	// Schedule chart.
	If Items.Body.CurrentPage = Items.PanelSchedule Then
		// Schedule chart: chart.
		If KindChartPlanRadioButton = "Chart" Then
			UpdateScheduleChart();
		Else // Schedule chart: list.
			SetPeriodOfListFilter();
		EndIf;
		
	Else // Resources import.
		// Resources import: chart.
		If CalendarKindRadioButton = "Chart" Then
			RefreshChartOfResources();
		Else // Resources import: calendar
			UpdateCalendar();
		EndIf;
		
	EndIf;
	
EndProcedure // WeekPeriod()

// Procedure - command handler Month.
//
&AtClient
Procedure MonthPeriod()
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	GenerateScheduledWorksPeriod();
	
	// Schedule chart.
	If Items.Body.CurrentPage = Items.PanelSchedule Then
		// Schedule chart: chart.
		If KindChartPlanRadioButton = "Chart" Then
			UpdateScheduleChart();
		Else // Schedule chart: list.
			SetPeriodOfListFilter();
		EndIf;
		
	Else // Resources import.
		// Resources import: chart.
		If CalendarKindRadioButton = "Chart" Then
			RefreshChartOfResources();
		Else // Resources import: calendar
			UpdateCalendar();
		EndIf;
		
	EndIf;
	
EndProcedure // MonthPeriod()

// Procedure - handler of ShortenPeriod command.
//
&AtClient
Procedure ShortenPeriod(Command)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	If WorksScheduleRadioButton = "Week" Then
		
		CalendarDate = EndOfDay(BegOfWeek(BegOfWeek(CalendarDate) - 60 * 60 * 24));
		
	ElsIf WorksScheduleRadioButton = "Month" Then
		
		CalendarDate = EndOfDay(BegOfMonth(BegOfMonth(CalendarDate) - 60 * 60 * 24));
		
	ElsIf WorksScheduleRadioButton= "4days" Then
		
		CalendarDate = EndOfDay(CalendarDate - 3 * 60 * 60 * 24);
		
	Else
		
		CalendarDate = EndOfDay(CalendarDate - 60 * 60 * 24);
		
	EndIf;
	
	GenerateScheduledWorksPeriod();
	
	// Schedule chart.
	If Items.Body.CurrentPage = Items.PanelSchedule Then
		// Schedule chart: chart.
		If KindChartPlanRadioButton = "Chart" Then
			UpdateScheduleChart();
		Else // Schedule chart: list.
			SetPeriodOfListFilter();
		EndIf;
		
	Else // Resources import.
		// Resources import: chart.
		If CalendarKindRadioButton = "Chart" Then
			RefreshChartOfResources();
		Else // Resources import: calendar
			UpdateCalendar();
		EndIf;
		
	EndIf;
	
EndProcedure // ShortenPeriod()

// Procedure - handler of ExtendPeriod command.
//
&AtClient
Procedure ExtendPeriod(Command)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	If WorksScheduleRadioButton = "Week" Then
		
		CalendarDate = EndOfDay(EndOfWeek(CalendarDate) + 60 * 60 * 24);
		
	ElsIf WorksScheduleRadioButton = "Month" Then
		
		CalendarDate = EndOfDay(EndOfMonth(CalendarDate) + 60 * 60 * 24);
		
	ElsIf WorksScheduleRadioButton= "4days" Then
		
		CalendarDate = EndOfDay(CalendarDate + 3 * 60 * 60 * 24);
		
	Else
		
		CalendarDate = EndOfDay(CalendarDate + 60 * 60 * 24);
		
	EndIf;
	
	GenerateScheduledWorksPeriod();
	
	// Schedule chart.
	If Items.Body.CurrentPage = Items.PanelSchedule Then
		// Schedule chart: chart.
		If KindChartPlanRadioButton = "Chart" Then
			UpdateScheduleChart();
		Else // Schedule chart: list.
			SetPeriodOfListFilter();
		EndIf;
		
	Else // Resources import.
		// Resources import: chart.
		If CalendarKindRadioButton = "Chart" Then
			RefreshChartOfResources();
		Else // Resources import: calendar
			UpdateCalendar();
		EndIf;
		
	EndIf;
	
EndProcedure // ExtendPeriod()

// Procedure - Settings command handler.
//
&AtClient
Procedure Settings(Command)
	
	ParametersStructure = New Structure();
	
	ParametersStructure.Insert("TimeLimitFrom", TimeLimitFrom);
	ParametersStructure.Insert("TimeLimitTo", TimeLimitTo);
	
	ParametersStructure.Insert("ShowJobOrders", ShowJobOrders);
	ParametersStructure.Insert("ShowProductionOrders", ShowProductionOrders);
	
	ParametersStructure.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	
	ParametersStructure.Insert("WorkSchedules", WorksOnly);
	
	Notification = New NotifyDescription("SettingsEnd",ThisForm);
	OpenForm("DataProcessor.Scheduler.Form.Setting", ParametersStructure,,,,,Notification);
	
EndProcedure // Settings()

&AtClient
Procedure SettingsEnd(ReturnStructure,Parameters) Export
	
	If TypeOf(ReturnStructure) = Type("Structure") AND ReturnStructure.WereMadeChanges Then
		
		TimeLimitFrom = ReturnStructure.TimeLimitFrom;
		TimeLimitTo = ReturnStructure.TimeLimitTo;
		
		ShowJobOrders = ReturnStructure.ShowJobOrders;
		ShowProductionOrders = ReturnStructure.ShowProductionOrders;
		
		SetEnabledOfItemsOnForm();
		
		RepetitionFactorOFDay = ReturnStructure.RepetitionFactorOFDay;
		
		// Schedule chart.
		If Items.Body.CurrentPage = Items.PanelSchedule Then
			// Schedule chart: chart.
			If KindChartPlanRadioButton = "Chart" Then
				UpdateScheduleChart();
			Else // Schedule chart: list.
				AvailableDocumentsList = New ValueList;
				If ShowJobOrders Then
					AvailableDocumentsList.Add(Type("DocumentRef.CustomerOrder"));
				EndIf;
				If ShowProductionOrders Then
					AvailableDocumentsList.Add(Type("DocumentRef.ProductionOrder"));
				EndIf;
				SmallBusinessClientServer.SetListFilterItem(List, "Type", AvailableDocumentsList, True, DataCompositionComparisonType.InList);
			EndIf;
			
		Else // Resources import.
			// Resources import: chart.
			If CalendarKindRadioButton = "Chart" Then
				RefreshChartOfResources();
			Else // Resources import: calendar
				UpdateCalendar();
			EndIf;
			
		EndIf;
		
		SetVisibleOfItemsOnForm();
		
	EndIf;
	
	UpdateCalendar();
	
EndProcedure

&AtClient
// Procedure - command handler SendEmailToCounterparty.
//
Procedure SendEmailToCounterparty(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ListCurrentData = Items.List.CurrentData;
	If ListCurrentData = Undefined Then
		Return;
	EndIf;
	
	Recipients = New Array;
	If ValueIsFilled(ListCurrentData.CounterpartyEmail) Then
		StructureRecipient = New Structure;
		StructureRecipient.Insert("Presentation", ListCurrentData.Counterparty);
		StructureRecipient.Insert("Address", ListCurrentData.CounterpartyEmail);
		Recipients.Add(StructureRecipient);
	EndIf;
	
	SendingParameters = New Structure;
	SendingParameters.Insert("Recipient", Recipients);
	
	EmailOperationsClient.CreateNewEmail(SendingParameters);
	
EndProcedure // SendEmailToCounterparty()

&AtClient
// Procedure - SendEmailToContactPerson command handler.
//
Procedure SendEmailToContactPerson(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ListCurrentData = Items.List.CurrentData;
	If ListCurrentData = Undefined Then
		Return;
	EndIf;
	
	Recipients = New Array;
	If ValueIsFilled(ListCurrentData.ContactPersonEmail) Then
		StructureRecipient = New Structure;
		StructureRecipient.Insert("Presentation", ListCurrentData.ContactPerson);
		StructureRecipient.Insert("Address", ListCurrentData.ContactPersonEmail);
		Recipients.Add(StructureRecipient);
	EndIf;
	
	SendingParameters = New Structure;
	SendingParameters.Insert("Recipient", Recipients);
	
	EmailOperationsClient.CreateNewEmail(SendingParameters);
	
EndProcedure // SendEmailToContactPerson()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - QUICK SELECTION EVENT HANDLERS

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure FilterCounterpartyOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	// Schedule chart.
	If Items.Body.CurrentPage = Items.PanelSchedule Then
		// Schedule chart: chart.
		If KindChartPlanRadioButton = "Chart" Then
			UpdateScheduleChart();
		Else // Schedule chart: list.
			SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
		EndIf;
		
	Else // Resources import.
		// Resources import: chart.
		If CalendarKindRadioButton = "Chart" Then
			RefreshChartOfResources();
		Else // Resources import: calendar
			UpdateCalendar();
		EndIf;
		
	EndIf;
	
EndProcedure // FilterCounterpartyOnChange()

// Procedure - OnChange event handler of Resource input field.
//
&AtClient
Procedure FilterKeyResourceOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	// Schedule chart.
	If Items.Body.CurrentPage = Items.PanelSchedule Then
		// Schedule chart: chart.
		If KindChartPlanRadioButton = "Chart" Then
			UpdateScheduleChart();
		Else // Schedule chart: list.
			SmallBusinessClientServer.SetListFilterItem(List, "KeyResources", TrimAll(FilterKeyResource), ValueIsFilled(FilterKeyResource), DataCompositionComparisonType.Contains);
		EndIf;
		
	Else // Resources import.
		// Resources import: chart.
		If CalendarKindRadioButton = "Chart" Then
			RefreshChartOfResources();
		Else // Resources import: calendar
			UpdateCalendar();
		EndIf;
		
	EndIf;
	
EndProcedure // FilterKeyResourceOnChange()

// Procedure - OnChange event handler of Responsible input field.
//
&AtClient
Procedure FilterResponsibleOnChange(Item)
	
	// Schedule chart: list.
	If KindChartPlanRadioButton = "List" Then
		SmallBusinessClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	// Schedule chart: chart.
	ElsIf KindChartPlanRadioButton = "Chart" Then
		UpdateScheduleChart();
	EndIf;
	
EndProcedure // FilterResponsibleOnChange()

// Procedure - OnChange event handler of ResourceKind input field.
//
&AtClient
Procedure ResourcesFilterResourceKindOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	// Resources import: chart.
	If CalendarKindRadioButton = "Chart" Then
		RefreshChartOfResources();
	Else // Resources import: calendar
		UpdateCalendar();
	EndIf;
	
EndProcedure // ResourcesFilterResourceKindOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - COMMAND HANDLERS OF SCHEDULE CHART AND RESOURCES UPLOAD

// Procedure - handler of "Add production order" command.
//
&AtClient
Procedure AddProductionOrder(Command)
	
	// Schedule chart.
	If Items.Body.CurrentPage = Items.PanelSchedule Then
		// Schedule chart: chart.
		If KindChartPlanRadioButton = "Chart" Then
			OpenForm("Document.ProductionOrder.ObjectForm",,Items.List);
		Else // Schedule chart: list.
			OpenForm("Document.ProductionOrder.ObjectForm",,Items.List);
		EndIf;
		
	Else // Resources import.
		// Resources import: chart.
		If CalendarKindRadioButton = "Chart" Then
			OpenParameters = GetOrderOpeningParameters(True);
			OpenForm("Document.ProductionOrder.Form.RequestForm", OpenParameters);
		Else // Resources import: calendar
			OpenParameters = GetOrderOpeningParameters();
			OpenForm("Document.ProductionOrder.Form.RequestForm", OpenParameters);
		EndIf;
		
	EndIf;
	
EndProcedure // AddProductionOrder()

// Procedure - "Add work-order" command handler.
//
&AtClient
Procedure AddJobOrder(Command)
	
	// Schedule chart.
	If Items.Body.CurrentPage = Items.PanelSchedule Then
		// Schedule chart: chart.
		If KindChartPlanRadioButton = "Chart" Then
			FillValue = New Structure;
			FillValue.Insert("OperationKind", OperationKindJobOrder);
			OpenForm("Document.CustomerOrder.ObjectForm", New Structure("FillingValues", FillValue), Items.List);
		Else // Schedule chart: list.
			FillValue = New Structure;
			FillValue.Insert("OperationKind", OperationKindJobOrder);
			OpenForm("Document.CustomerOrder.ObjectForm", New Structure("FillingValues", FillValue), Items.List);
		EndIf;
		
	Else // Resources import.
		// Resources import: chart.
		If CalendarKindRadioButton = "Chart" Then
			OpenParameters = GetOrderOpeningParameters(True);
			OpenForm("Document.CustomerOrder.Form.RequestForm", OpenParameters);
		Else // Resources import: calendar
			OpenParameters = GetOrderOpeningParameters();
			OpenForm("Document.CustomerOrder.Form.RequestForm", OpenParameters);
		EndIf;
		
	EndIf;
	
EndProcedure // AddJobOrder()

// Procedure - Refresh command handler.
//
&AtClient
Procedure Refresh(Command)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	// Schedule chart.
	If Items.Body.CurrentPage = Items.PanelSchedule Then
		// Schedule chart: chart.
		If KindChartPlanRadioButton = "Chart" Then
			UpdateScheduleChart();
		Else // Schedule chart: list.
			UpdateListAtServer();
		EndIf;
		
	Else // Resources import.
		// Resources import: chart.
		If CalendarKindRadioButton = "Chart" Then
			RefreshChartOfResources();
		Else // Resources import: calendar
			UpdateCalendar();
		EndIf;
		
	EndIf;
	
EndProcedure // Refresh()

// Procedure - Chart, List command handler
//
&AtClient
Procedure KindChartPlanRadioButtonOnChange(Item)
	
	If KindChartPlanRadioButton = "Chart" Then
		ScheduleChart();
	Else
		ScheduleList();
	EndIf;
	
EndProcedure

// Procedure - List list command handler.
//
&AtClient
Procedure ScheduleList()
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	Items.GroupOfListAndChartEditing.CurrentPage = Items.ListCommands;
	Items.ListAndChart.CurrentPage = Items.ListSchedule;
	
	UpdateScheduleChartList();
	
EndProcedure // ScheduleChartList()

// Procedure - Chart list command handler.
//
&AtClient
Procedure ScheduleChart()
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	Items.GroupOfListAndChartEditing.CurrentPage = Items.ScheduleChartCommands;
	Items.ListAndChart.CurrentPage = Items.ChartSchedule;
	
	UpdateScheduleChart();
	
EndProcedure // ScheduleChartDiagram()

// Procedure - Calendar, Chart command handler
//
&AtClient
Procedure CalendarKindRadioButtonOnChange(Item)
	
	If CalendarKindRadioButton = "Chart" Then
		ResourcesChart();
	Else
		ResourcesCalendar();
	EndIf;
	
EndProcedure

// Procedure - Calendar command handler - resources.
//
&AtClient
Procedure ResourcesCalendar()
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	Items.GroupCalendarAndChartEditing.CurrentPage = Items.CalendarCommands;
	Items.CalendarAndChart.CurrentPage = Items.CalendarResources;
	
	UpdateCalendar();
	
EndProcedure // ResourcesCalendar()

// Procedure - Chart command handler - resources.
//
&AtClient
Procedure ResourcesChart()
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	Items.GroupCalendarAndChartEditing.CurrentPage = Items.CommandsChartResources;
	Items.CalendarAndChart.CurrentPage = Items.ChartResources;
	
	RefreshChartOfResources();
	
EndProcedure // ResourcesChart()

// Procedure - OnCurrentPageChange event handler.
//
&AtClient
Procedure BodyOnCurrentPageChange(Item, CurrentPage)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorSchedulerGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	If Items.Body.CurrentPage = Items.PanelSchedule Then
		
		If KindChartPlanRadioButton = "List" Then
			UpdateScheduleChartList();
		Else
			UpdateScheduleChart();
		EndIf;
		
	Else
		
		If CalendarKindRadioButton = "Calendar" Then
			UpdateCalendar();
		Else
			RefreshChartOfResources();
		EndIf;
		
	EndIf;
	
EndProcedure // BodyOnCurrentPageChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF TABULAR DOCUMENT

// Procedure - event handler Choice.
//
&AtClient
Procedure ResourcesImportSelection(Item, Area, StandardProcessing)
	
	If Area.Hyperlink
		AND Area.Text = "Fill resources" Then
		OpenForm("Catalog.KeyResources.ListForm");
	EndIf;
	
EndProcedure // ResourcesImportSelection()

// Procedure - DecryptionProcessor event handler.
//
&AtClient
Procedure ResourcesImportDetailProcessing(Item, Details, StandardProcessing)
	
	If TypeOf(Details) = Type("Structure") Then
		
		StandardProcessing = False;
		
		If Details.OrdersList <> Undefined Then
			OrdersInformationDetailProcessing();
		Else
			CreateNewOrderDetailProcessing(Details);
		EndIf;
		
	EndIf;
	
EndProcedure // ResourcesImportDecryptionProcessor()

// Procedure - ViewOrdersInformation command handler.
//
&AtClient
Procedure ViewOrdersInformation(Command)
	
	OrdersInformationDetailProcessing();
	
EndProcedure // ViewOrdersInformation()
