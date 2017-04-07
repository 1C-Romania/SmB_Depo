////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure saves the form settings.
//
&AtServerNoContext
Procedure SaveFormSettings(SettingsStructure)
	
	FormDataSettingsStorage.Save("KeyResources", "SettingsStructure", SettingsStructure);
	
EndProcedure // SaveFormSettings()

// Procedure imports the form settings.
//
&AtServer
Procedure ImportFormSettings()
	
	SettingsStructure = FormDataSettingsStorage.Load("KeyResources", "SettingsStructure");
	
	If TypeOf(SettingsStructure) = Type("Structure") Then
		
		RadioButton = "Year";
		
		If SettingsStructure.Property("TimetableScheduleDayPeriodCheck")
			AND SettingsStructure.TimetableScheduleDayPeriodCheck Then
			RadioButton = "Day";
		EndIf;
		
		If SettingsStructure.Property("RepetitionFactorOFDay") Then
			RepetitionFactorOFDay = SettingsStructure.RepetitionFactorOFDay;
		Else
			RepetitionFactorOFDay = 5;
		EndIf;
		
	Else
		
		RadioButton = "Year";
		
		RepetitionFactorOFDay = 5;
		
	EndIf;
	
EndProcedure // ImportFormSettings()

// Procedure displays the timetable based on the schedule.
//
&AtServer
Procedure DisplayTimetableSchedule()
	
	// Filling the schedule table to display the current one.
	FillTableOfSchedules();
	
	// Schedule timetable display depending on the clicked button.
	If RadioButton = "Year" Then
		DisplayTimetableScheduleYear();
	ElsIf RadioButton = "Day" Then
		DisplayTimetableScheduleDay();
	EndIf;
	
EndProcedure // DisplayTimetableSchedule()

// Procedure displays the timetable based on the schedule of the Year kind.
//
&AtServer
Procedure DisplayTimetableScheduleYear()
	
	Items.WorkingDaysTotal.Visible = True;
	Items.NonworkingDaysTotal.Visible = True;
	Items.WorkingHoursTotal.Visible = True;
	
	TimetableSchedule.Clear();
	
	TimetableScheduleTemplate = Catalogs.WorkSchedules.GetTemplate("TimetableByYearSchedule");
	TemplateArea = TimetableScheduleTemplate.GetArea("Header");
	TimetableSchedule.Put(TemplateArea);
	TemplateArea = TimetableScheduleTemplate.GetArea("Calendar");
	TimetableSchedule.Put(TemplateArea);
	
	LineCountInTable = TableOfSchedules.Count();
	
	For MonthNumber = 1 To 12 Do
		DaysNumber = NumberOfDaysInMonthAtServer(MonthNumber, Year(ScheduleDate));
		For DayNumber = 1 To 31 Do
			Area = TimetableSchedule.Area("R" + String(MonthNumber + 1) + "C" + String(DayNumber + 1));
			Area.Text = "";
			If DayNumber > DaysNumber Then
				
				// Coloring the missing day in the calendar.
				Area.BackColor = StyleColors.FormBackColor;
				
			Else
				
				CurDate = Date(Year(ScheduleDate), MonthNumber, DayNumber, 0, 0, 0);
				
				// Weekend coloring.
				If WeekDay(CurDate) = 6
				 OR WeekDay(CurDate) = 7 Then
					If ThisIsWebClient Then
						Area.Text = "In";
						Area.TextColor = StyleColors.NonWorkingTimeDayOff;
						Area.BackColor = StyleColors.FieldBackColor;
					Else
						Area.BackColor = StyleColors.NonWorkingTimeDayOff;
					EndIf;
				Else
					Area.BackColor = StyleColors.FieldBackColor;
				EndIf;
				
				// Coloring the periods related to various schedules.
				PatternColor = Undefined;
				For Each CurSchedule IN TableOfSchedules Do
					If CurDate >= BegOfDay(CurSchedule.Period) Then
						PatternColor = CurSchedule.Color;
					EndIf;
				EndDo;
				
				If PatternColor = Undefined Then
					If ThisIsWebClient Then
						Area.BackColor = StyleColors.FieldBackColor;
					Else
						Area.Pattern = SpreadsheetDocumentPatternType.WithoutPattern;
					EndIf;
				Else
					If ThisIsWebClient Then
						Area.BackColor = PatternColor;
					Else
						Area.Pattern = SpreadsheetDocumentPatternType.Pattern15;
						Area.PatternColor = PatternColor;
					EndIf;
				EndIf;
				
			EndIf;
		EndDo;
	EndDo;
	
	// Get the schedule timetable and deviations.
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorkSchedules.WorkSchedule,
	|	WorkSchedules.Year,
	|	WorkSchedules.BeginTime,
	|	WorkSchedules.EndTime,
	|	WorkSchedules.WorkSchedule.Color AS Color
	|FROM
	|	InformationRegister.WorkSchedules AS WorkSchedules
	|WHERE
	|	WorkSchedules.WorkSchedule = &WorkSchedule
	|	AND WorkSchedules.Year = &Year
	|	AND WorkSchedules.BeginTime >= &BeginOfPeriod
	|	AND WorkSchedules.EndTime <= &EndOfPeriod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DeviationFromResourcesWorkSchedules.EnterpriseResource,
	|	DeviationFromResourcesWorkSchedules.Year,
	|	DeviationFromResourcesWorkSchedules.Day,
	|	DeviationFromResourcesWorkSchedules.BeginTime,
	|	DeviationFromResourcesWorkSchedules.EndTime,
	|	DeviationFromResourcesWorkSchedules.NotABusinessDay
	|FROM
	|	InformationRegister.DeviationFromResourcesWorkSchedules AS DeviationFromResourcesWorkSchedules
	|WHERE
	|	DeviationFromResourcesWorkSchedules.EnterpriseResource = &EnterpriseResource
	|	AND DeviationFromResourcesWorkSchedules.BeginTime >= &BeginOfPeriod
	|	AND DeviationFromResourcesWorkSchedules.EndTime <= &EndOfPeriod";
	
	Query.SetParameter("Year", Year(ScheduleDate));
	Query.SetParameter("EnterpriseResource", Object.Ref);
	
	For Ct = 0 To LineCountInTable - 1 Do
		
		BeginOfPeriod = BegOfDay(TableOfSchedules[Ct].Period);
		
		If Ct = LineCountInTable - 1 Then
			EndOfPeriod = EndOfYear(ScheduleDate);
		Else
			EndOfPeriod = BegOfDay(TableOfSchedules[Ct + 1].Period) - 1;
		EndIf;
		
		Query.SetParameter("BeginOfPeriod", BeginOfPeriod);
		Query.SetParameter("EndOfPeriod", EndOfPeriod);
		Query.SetParameter("WorkSchedule", TableOfSchedules[Ct].WorkSchedule);
		
		QueryResult = Query.ExecuteBatch();
		ScheduleData = QueryResult[0].Select();
		
		// Calculate the number of the scheduled hours.
		While ScheduleData.Next() Do
			Value = Round((ScheduleData.EndTime - ScheduleData.BeginTime) / 3600);
			TableRow = Month(ScheduleData.BeginTime) + 1;
			TableColumn = Day(ScheduleData.BeginTime) + 1;
			Area = TimetableSchedule.Area("R" + TableRow + "C" + TableColumn);
			Area.Text = String(Number(?(ValueIsFilled(?(Area.Text = "In", 0, Area.Text)), Area.Text, 0)) + Value);
		EndDo;
		
		// Clearing hours corresponding to the deviation days.
		DataAboutRejections = QueryResult[1].Select();
		While DataAboutRejections.Next() Do
			TableRow = Month(DataAboutRejections.BeginTime) + 1;
			TableColumn = Day(DataAboutRejections.BeginTime) + 1;
			Area = TimetableSchedule.Area("R" + TableRow + "C" + TableColumn);
			Area.Text = "";
		EndDo;
		
		// Calculate the number of hours by deviations.
		DataAboutRejections.Reset();
		While DataAboutRejections.Next() Do
			Value = Round((DataAboutRejections.EndTime - DataAboutRejections.BeginTime) / 3600);
			TableRow = Month(DataAboutRejections.BeginTime) + 1;
			TableColumn = Day(DataAboutRejections.BeginTime) + 1;
			Area = TimetableSchedule.Area("R" + TableRow + "C" + TableColumn);
			If DataAboutRejections.NotABusinessDay Then
				Value = 0;
			Else
				Value = Number(?(ValueIsFilled(Area.Text), Area.Text, 0)) + Value;
			EndIf;
			Area.Text = String(?(Value > 0, Value, ""));
			Area.Note.Text = "Deviations are introduced.";
		EndDo;
		
	EndDo
	
EndProcedure // DisplayTimetableScheduleYear()

// Procedure displays the timetable based on the schedule of the Day kind.
//
&AtServer
Procedure DisplayTimetableScheduleDay()
	
	Items.WorkingDaysTotal.Visible = False;
	Items.NonworkingDaysTotal.Visible = False;
	Items.WorkingHoursTotal.Visible = True;
	
	TimetableSchedule.Clear();
	
	TimetableScheduleTemplate = Catalogs.WorkSchedules.GetTemplate("TimetableByDaySchedule");
	TemplateArea = TimetableScheduleTemplate.GetArea("Calendar" + String(RepetitionFactorOFDay));
	TimetableSchedule.Put(TemplateArea);
	
	TimetableScheduleTemplate = Catalogs.WorkSchedules.GetTemplate("TimetableByDaySchedule");
	
	// Receiving the deviation data per day.
	Query = New Query();
	Query.Text = 
	"SELECT
	|	DeviationFromResourcesWorkSchedules.EnterpriseResource,
	|	DeviationFromResourcesWorkSchedules.Year,
	|	DeviationFromResourcesWorkSchedules.Day,
	|	DeviationFromResourcesWorkSchedules.BeginTime,
	|	DeviationFromResourcesWorkSchedules.EndTime,
	|	DeviationFromResourcesWorkSchedules.NotABusinessDay
	|FROM
	|	InformationRegister.DeviationFromResourcesWorkSchedules AS DeviationFromResourcesWorkSchedules
	|WHERE
	|	DeviationFromResourcesWorkSchedules.EnterpriseResource = &EnterpriseResource
	|	AND DeviationFromResourcesWorkSchedules.Day = &BeginOfPeriod
	|	AND DeviationFromResourcesWorkSchedules.BeginTime >= &BeginOfPeriod
	|	AND DeviationFromResourcesWorkSchedules.EndTime <= &EndOfPeriod";
	
	Query.SetParameter("BeginOfPeriod", BegOfDay(ScheduleDate));
	Query.SetParameter("EndOfPeriod", EndOfDay(ScheduleDate));
	Query.SetParameter("EnterpriseResource", Object.Ref);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then // if there are no deviations, we take data from the schedule
	
		Query.Text =
		"SELECT
		|	RecourcesWorkScheduleSliceLast.WorkSchedule AS WorkSchedule
		|INTO TempTableWorkSchedule
		|FROM
		|	InformationRegister.ResourcesWorkSchedules.SliceLast(&EndOfPeriod, EnterpriseResource = &EnterpriseResource) AS RecourcesWorkScheduleSliceLast
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkSchedules.WorkSchedule,
		|	WorkSchedules.Year,
		|	WorkSchedules.BeginTime,
		|	WorkSchedules.EndTime,
		|	WorkSchedules.WorkSchedule.Color AS Color
		|FROM
		|	InformationRegister.WorkSchedules AS WorkSchedules
		|WHERE
		|	WorkSchedules.WorkSchedule In
		|			(SELECT
		|				TempTableWorkSchedule.WorkSchedule
		|			FROM
		|				TempTableWorkSchedule AS TempTableWorkSchedule)
		|	AND WorkSchedules.Year = &Year
		|	AND WorkSchedules.BeginTime >= &BeginOfPeriod
		|	AND WorkSchedules.EndTime <= &EndOfPeriod";
		
		Query.SetParameter("Year", Year(ScheduleDate));
		
		QueryResult = Query.ExecuteBatch();
		
		ScheduleData = QueryResult[1].Select();
		
		// Scheduled working periods coloring.
		While ScheduleData.Next() Do
			For CurRow = 1 To 4 Do
				For CurColumn = 1 to 72 Do
					CurEndOfPeriod = BegOfDay(ScheduleDate) + (CurRow - 1) * 72 * 300 + CurColumn * 300 - 1;
					CurBeginOfPeriod = CurEndOfPeriod - 299;
					TableRow = CurRow * 2;
					CoefTableColumn = ?(CurColumn / 12 - Round(CurColumn / 12) > 0, Round(CurColumn / 12 + 0.5), Round(CurColumn / 12));
					TableColumn = CurColumn + CoefTableColumn;
					Area = TimetableSchedule.Area("R" + TableRow + "C" + TableColumn);
					If CurBeginOfPeriod >= ScheduleData.BeginTime
						AND CurEndOfPeriod <= ScheduleData.EndTime Then
						Area.BackColor = StyleColors.WorktimeCompletelyBusy;
					EndIf;
				EndDo;
			EndDo;
		EndDo;
		
	Else // there are deviations
		
		DataAboutRejections = QueryResult.Select();
		
		// Coloring the working periods by deviations.
		While DataAboutRejections.Next() Do
			If DataAboutRejections.NotABusinessDay Then
				Continue
			EndIf;
			For CurRow = 1 To 4 Do
				For CurColumn = 1 to 72 Do
					CurEndOfPeriod = BegOfDay(ScheduleDate) + (CurRow - 1) * 72 * 300 + CurColumn * 300 - 1;
					CurBeginOfPeriod = CurEndOfPeriod - 299;
					TableRow = CurRow * 2;
					CoefTableColumn = ?(CurColumn / 12 - Round(CurColumn / 12) > 0, Round(CurColumn / 12 + 0.5), Round(CurColumn / 12));
					TableColumn = CurColumn + CoefTableColumn;
					Area = TimetableSchedule.Area("R" + TableRow + "C" + TableColumn);
					If CurBeginOfPeriod >= DataAboutRejections.BeginTime
						AND CurEndOfPeriod <= DataAboutRejections.EndTime Then
						Area.BackColor = StyleColors.WorktimeCompletelyBusy;
					EndIf;
				EndDo;
			EndDo;
		EndDo;
		
	EndIf;
	
EndProcedure // DisplayTimetableScheduleDay()

// The function calculates the number of days in a month.
//
&AtClient
Function NumberOfDaysInMonthAtClient(Month, Year)
	
	DateOfMonth = Date(Year, Month, 1);
	DaysInMonth = Day(EndOfMonth(DateOfMonth));
	Return DaysInMonth;
	
EndFunction // NumberOfDaysInMonth()

// The function calculates the number of days in a month.
//
&AtServer
Function NumberOfDaysInMonthAtServer(Month, Year)
	
	DateOfMonth = Date(Year, Month, 1);
	DaysInMonth = Day(EndOfMonth(DateOfMonth));
	Return DaysInMonth;
	
EndFunction // NumberOfDaysInMonth()

 // Procedure fills the period presentation.
//
&AtClient
Procedure FillPresentationOfPeriod()
	
	If RadioButton = "Year" Then
		TimetableSchedulePresentationPeriod = "" + Year(ScheduleDate) + " year";
	ElsIf RadioButton = "Day" Then
		DayOfSchedule = Format(ScheduleDate, "DF=dd");
		MonthOfSchedule = Format(ScheduleDate, "DF=MMM");
		YearOfSchedule = Format(Year(ScheduleDate), "NG=0");
		WeekDayOfSchedule = SmallBusinessClient.GetPresentationOfWeekDay(ScheduleDate);
		TimetableSchedulePresentationPeriod = WeekDayOfSchedule + " " + DayOfSchedule + " " + MonthOfSchedule + " " + YearOfSchedule;
	EndIf;
	
EndProcedure // FillPeriodPresentation()

// Procedure fills in the schedule table
// used to display the current schedule.
&AtServer
Procedure FillTableOfSchedules()
	
	TableOfSchedules.Clear();
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	ResourcesWorkSchedules.Period AS Period,
	|	ResourcesWorkSchedules.EnterpriseResource,
	|	ResourcesWorkSchedules.WorkSchedule,
	|	ResourcesWorkSchedules.WorkSchedule.Color AS Color
	|FROM
	|	InformationRegister.ResourcesWorkSchedules AS ResourcesWorkSchedules
	|WHERE
	|	ResourcesWorkSchedules.Period >= &BeginOfPeriod
	|	AND ResourcesWorkSchedules.Period <= &EndOfPeriod
	|	AND ResourcesWorkSchedules.EnterpriseResource = &EnterpriseResource
	|
	|ORDER BY
	|	Period";
	
	Query.SetParameter("BeginOfPeriod", BegOfYear(ScheduleDate));
	Query.SetParameter("EndOfPeriod", EndOfYear(ScheduleDate));
	Query.SetParameter("EnterpriseResource", Object.Ref);
	
	SelectionQueryResult = Query.Execute().Select();
	
	While SelectionQueryResult.Next() Do
		
		RowOfTableOfSchedules = TableOfSchedules.Add();
		FillPropertyValues(RowOfTableOfSchedules, SelectionQueryResult);
		RowOfTableOfSchedules.Color = SelectionQueryResult.Color.Get();
		
	EndDo;
	
EndProcedure // FillTableOfSchedules

// Procedure receives the current schedule corresponding to the selected period.
//
&AtClient
Function GetCurrentSchedule()
	
	If RadioButton = "Year" Then
		SelectedArea = TimetableSchedule.SelectedAreas[0];
		MonthNumber = SelectedArea.Top - 1;
		DayNumber = SelectedArea.Left - 1;
		If MonthNumber < 1 OR MonthNumber > 12 OR DayNumber < 1 OR DayNumber > 31 OR DayNumber > NumberOfDaysInMonthAtClient(MonthNumber, Year(ScheduleDate)) Then
			Return Undefined;
		EndIf;
		CurDate = Date(Year(ScheduleDate), MonthNumber, DayNumber, 0, 0, 0);
	Else
		CurDate = BegOfDay(ScheduleDate);
	EndIf;
	
	Return GetCurrentScheduleOnDate(CurDate);
	
EndFunction // GetCurrentSchedule()

// Procedure receives current schedule to the date.
//
&AtClient
Function GetCurrentScheduleOnDate(Date)
	
	For Each CurSchedule IN TableOfSchedules Do
		If Date >= BegOfDay(CurSchedule.Period) Then
			WorkSchedule = CurSchedule.WorkSchedule;
		EndIf;
	EndDo;
	
	If Not ValueIsFilled(WorkSchedule) Then
		WorkSchedule = NStr("en='<Not set>';ru='<Не установлено>'");
		Items.Schedule.Hyperlink = False;
	Else 
		Items.Schedule.Hyperlink = True;
	EndIf;
	
	Return WorkSchedule;
	
EndFunction // GetCurrentScheduleOnDate()

// Procedure marks the selected period as nonworking in the Year presentation.
//
&AtClient
Procedure MarkSelectedAsNonWorkingYear()
	
	TableSelected.Clear();
	SelectedAreas = TimetableSchedule.SelectedAreas;
	
	ThereAreSuitableDays = False;
	CurSchedule = Undefined;
	
	For Each CurArea IN SelectedAreas Do
		
		If TypeOf(CurArea) <> Type("SpreadsheetDocumentRange") Then
			Continue;
		EndIf;
		
		For CurRow = CurArea.Top To CurArea.Bottom Do
			For CurColumn = CurArea.Left To CurArea.Right Do
				If CurColumn >= 2 AND CurColumn <= 32 AND CurRow >= 2 AND CurRow <= 13 Then
					Try
						CurDate = Date(Year(ScheduleDate), CurRow - 1, CurColumn - 1, 0, 0, 0);
					Except
						Continue;
					EndTry;
					ThereAreSuitableDays = True;
					CurSchedule = GetCurrentScheduleOnDate(CurDate);
					If CurSchedule = Undefined Then
						Continue;
					EndIf;
					NewRow = TableSelected.Add();
					NewRow.Top = CurRow - 1;
					NewRow.Left = CurColumn - 1;
				EndIf;
			EndDo;
		EndDo;
		
	EndDo;
	
	If ThereAreSuitableDays
	   AND CurSchedule = Undefined Then
		ShowMessageBox(Undefined,NStr("en='Set schedule for selected days first!';ru='Установите вначале график для выбранных дней!'"));
	EndIf;
	
	MarkSelectedAsNonWorkingYearAtServer();
	GenerateReturns();
	
EndProcedure // MarkSelectedAsNonWorkingYear

// Procedure marks the selected period as nonworking in the Day presentation.
//
&AtClient
Procedure MarkSelectedAsNonWorkingDay()
	
	CurSchedule = GetCurrentScheduleOnDate(ScheduleDate);
	If CurSchedule = Undefined Then
		ShowMessageBox(Undefined,NStr("en='Set schedule for that day first!';ru='Установите вначале график для этого дня!'"));
		Return;
	EndIf;
	
	SetBackColorForChoosedAreas(ColorOfFreePeriod);
	WriteRejectionsToRegister();
	
EndProcedure // MarkSelectedAsNonWorkingDay()

// Procedure marks the selected period as nonworking in the Year presentation on the server.
//
&AtServer
Procedure MarkSelectedAsNonWorkingYearAtServer()
	
	For Each CurArea IN TableSelected Do
		
		RecordSet = InformationRegisters.DeviationFromResourcesWorkSchedules.CreateRecordSet();
		RecordSet.Filter.EnterpriseResource.Set(Object.Ref);
		RecordSet.Filter.Year.Set(Year(ScheduleDate));
		RecordSet.Filter.Day.Set(Date(Year(ScheduleDate), CurArea.Top, CurArea.Left, 0, 0, 0));
		RecordSet.Write(True);
		
		RecordSet = InformationRegisters.DeviationFromResourcesWorkSchedules.CreateRecordSet();
		NewRow = RecordSet.Add();
		NewRow.EnterpriseResource = Object.Ref;
		NewRow.Year = Year(ScheduleDate);
		NewRow.Day = Date(Year(ScheduleDate), CurArea.Top, CurArea.Left, 0, 0, 0);
		NewRow.BeginTime = Date(Year(ScheduleDate), CurArea.Top, CurArea.Left, 0, 0, 0);
		NewRow.EndTime = Date(Year(ScheduleDate), CurArea.Top, CurArea.Left, 23, 59, 59);
		NewRow.NotABusinessDay = True;
		RecordSet.Write(False);
		
	EndDo;
	
	DisplayTimetableSchedule();
	
EndProcedure // MarkSelectedAsNonWorkingYearAtServer()

// Procedure marks the selected period as working in the Year presentation.
//
&AtClient
Procedure MarkSelectedAsWorkingYear()
	
	TableSelected.Clear();
	SelectedAreas = TimetableSchedule.SelectedAreas;
	
	ThereAreSuitableDays = False;
	CurSchedule = Undefined;
	
	For Each CurArea IN SelectedAreas Do
		
		If TypeOf(CurArea) <> Type("SpreadsheetDocumentRange") Then
			Continue;
		EndIf;
		
		For CurRow = CurArea.Top To CurArea.Bottom Do
			For CurColumn = CurArea.Left To CurArea.Right Do
				If CurColumn >= 2 AND CurColumn <= 32 AND CurRow >= 2 AND CurRow <= 13 Then
					Try
						CurDate = Date(Year(ScheduleDate), CurRow - 1, CurColumn - 1, 0, 0, 0);
					Except
						Continue;
					EndTry;
					ThereAreSuitableDays = True;
					CurSchedule = GetCurrentScheduleOnDate(CurDate);
					If CurSchedule = Undefined Then
						Continue;
					EndIf;
					NewRow = TableSelected.Add();
					NewRow.Top = CurRow - 1;
					NewRow.Left = CurColumn - 1;
				EndIf;
			EndDo;
		EndDo;
		
	EndDo;
	
	If ThereAreSuitableDays
	   AND CurSchedule = Undefined Then
		ShowMessageBox(Undefined,NStr("en='Set schedule for selected days first!';ru='Установите вначале график для выбранных дней!'"));
	EndIf;
	
	MarkSelectedAsWorkingYearAtServer();
	GenerateReturns();
	
EndProcedure // MarkSelectedAsWorkingYear()

// Procedure marks the selected period as working in the Day presentation.
//
&AtClient
Procedure MarkSelectedAsWorkingDay()
	
	CurSchedule = GetCurrentScheduleOnDate(ScheduleDate);
	If CurSchedule = Undefined Then
		ShowMessageBox(Undefined,NStr("en='Set schedule for that day first!';ru='Установите вначале график для этого дня!'"));
		Return;
	EndIf;
	
	SetBackColorForChoosedAreas(BusyPeriodColor);
	WriteRejectionsToRegister();
	
EndProcedure // MarkSelectedAsWorkingDay()

// Function checks the possibility to set the color for the current line and column.
//
&AtClient
Function CheckPossibilityOfSettingColor(CurColumn, CurRow)
	
	If (CurColumn >= 2 AND CurColumn <= 78 AND CurColumn <> 14 AND CurColumn <> 27 AND CurColumn <> 40 AND CurColumn <> 53 AND CurColumn <> 66)
		AND (CurRow = 2 OR CurRow = 4 OR CurRow = 6 OR CurRow = 8)  Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction // CheckColorSettingOption()

// Procedure specifies the background color for the selected areas.
//
&AtClient
Procedure SetBackColorForChoosedAreas(Color)
	
	SelectedAreas = TimetableSchedule.SelectedAreas;
	
	For Each CurArea IN SelectedAreas Do
		
		If TypeOf(CurArea) <> Type("SpreadsheetDocumentRange") Then
			Continue;
		EndIf;
		
		For CurRow = CurArea.Top To CurArea.Bottom Do
			For CurColumn = CurArea.Left To CurArea.Right Do
				If CheckPossibilityOfSettingColor(CurColumn, CurRow) Then
					Area = TimetableSchedule.Area("R" + CurRow + "C" + CurColumn);
					Area.BackColor = Color;
				EndIf;
			EndDo;
		EndDo;
		
	EndDo;
	
EndProcedure // SetBackgroundColorForSelectedAreas()

// Procedure writes deviations to the register.
//
&AtServer
Procedure WriteRejectionsToRegister()
	
	RecordSet = InformationRegisters.DeviationFromResourcesWorkSchedules.CreateRecordSet();
	
	RecordSet.Filter.EnterpriseResource.Set(Object.Ref);
	RecordSet.Filter.Year.Set(Year(ScheduleDate));
	RecordSet.Filter.Day.Set(BegOfDay(ScheduleDate));
	RecordSet.Write(True);
	
	RecordSet = InformationRegisters.DeviationFromResourcesWorkSchedules.CreateRecordSet();
	
	IntervalIsOpened = False;
	IsWorkingTime = False;
	
	ColumnsCount = 360 / RepetitionFactorOFDay;
	NumberOfSecondsInPeriod = RepetitionFactorOFDay * 60;
	NumberOfPeriodsInColumn = 60 / RepetitionFactorOFDay;
	
	For CurRow = 1 To 4 Do
		For CurColumn = 1 To 72 Do
			
			CurBeginOfPeriod = BegOfDay(ScheduleDate) + (CurRow - 1) * ColumnsCount * NumberOfSecondsInPeriod + CurColumn * NumberOfSecondsInPeriod - NumberOfSecondsInPeriod;
			TableRow = CurRow * 2;
			CoefTableColumn = ?(CurColumn / NumberOfPeriodsInColumn - Round(CurColumn / NumberOfPeriodsInColumn) > 0, Round(CurColumn / NumberOfPeriodsInColumn + 0.5), Round(CurColumn / NumberOfPeriodsInColumn));
			
			TableColumn = CurColumn + CurColumn * (RepetitionFactorOFDay / 5 - 1) - RepetitionFactorOFDay / 5 + 1 + CoefTableColumn;
			Area = TimetableSchedule.Area("R" + TableRow + "C" + TableColumn);
			
			If Area.BackColor = StyleColors.WorktimeCompletelyBusy Then
				If Not IntervalIsOpened Then
					IntervalIsOpened = True;
					NewRecord = RecordSet.Add();
					NewRecord.EnterpriseResource = Object.Ref;
					NewRecord.Year = Year(ScheduleDate);
					NewRecord.Day = BegOfDay(ScheduleDate);
					NewRecord.BeginTime = CurBeginOfPeriod;
					NewRecord.NotABusinessDay = False;
					IsWorkingTime = True;
				EndIf;
			Else
				If IntervalIsOpened Then
					IntervalIsOpened = False;
					NewRecord.EndTime = CurBeginOfPeriod;
				EndIf;
			EndIf;
			
			If CurColumn = ColumnsCount AND CurRow = 4 AND IntervalIsOpened Then
				IntervalIsOpened = False;
				NewRecord.EndTime = EndOfDay(ScheduleDate);
			EndIf;
			
		EndDo;
	EndDo;
	
	If Not IsWorkingTime Then
		NewRecord = RecordSet.Add();
		NewRecord.EnterpriseResource = Object.Ref;
		NewRecord.Year = Year(ScheduleDate);
		NewRecord.Day = BegOfDay(ScheduleDate);
		NewRecord.BeginTime = BegOfDay(ScheduleDate);
		NewRecord.EndTime = EndOfDay(ScheduleDate);
		NewRecord.NotABusinessDay = True;
	EndIf;
	
	RecordSet.Write(False);
	
EndProcedure // WriteDeviationsToRegister()

// Procedure marks the selected period as working in the Year presentation on the server.
//
&AtServer
Procedure MarkSelectedAsWorkingYearAtServer()
	
	For Each CurArea IN TableSelected Do
		RecordSet = InformationRegisters.DeviationFromResourcesWorkSchedules.CreateRecordSet();
		RecordSet.Filter.EnterpriseResource.Set(Object.Ref);
		RecordSet.Filter.Year.Set(Year(ScheduleDate));
		RecordSet.Filter.Day.Set(Date(Year(ScheduleDate), CurArea.Top, CurArea.Left, 0, 0, 0));
		NewRecord = RecordSet.Add();
		NewRecord.EnterpriseResource = Object.Ref;
		NewRecord.Year = Year(ScheduleDate);
		NewRecord.Day = Date(Year(ScheduleDate), CurArea.Top, CurArea.Left, 0, 0, 0);
		NewRecord.BeginTime = Date(Year(ScheduleDate), CurArea.Top, CurArea.Left, 8, 0, 0);
		NewRecord.EndTime = Date(Year(ScheduleDate), CurArea.Top, CurArea.Left, 16, 0, 0);
		RecordSet.Write(True);
	EndDo;
	
	DisplayTimetableSchedule();
	
EndProcedure // MarkSelectedAsWorkingYearAtServer()

// Procedure cancels all entered deviations for the year.
//
&AtServer
Procedure CancelAllChangesOfScheduleYearAtServer()
	
	RecordSet = InformationRegisters.DeviationFromResourcesWorkSchedules.CreateRecordSet();
	RecordSet.Filter.EnterpriseResource.Set(Object.Ref);
	RecordSet.Filter.Year.Set(Year(ScheduleDate));
	RecordSet.Write(True);
	
	DisplayTimetableSchedule();
	
EndProcedure // CancelAllScheduleChangesOnServer()

// Procedure cancels all entered deviations for the day.
//
&AtServer
Procedure CancelAllChangesOfScheduleDayAtServer()
	
	RecordSet = InformationRegisters.DeviationFromResourcesWorkSchedules.CreateRecordSet();
	RecordSet.Filter.EnterpriseResource.Set(Object.Ref);
	RecordSet.Filter.Year.Set(Year(ScheduleDate));
	RecordSet.Filter.Day.Set(BegOfDay(ScheduleDate));
	RecordSet.Write(True);
	
	DisplayTimetableSchedule();
	
EndProcedure // CancelAllScheduleChangesDayAtServer()

// Procedure specified the timetable on the server.
//
&AtServer
Procedure SetTimetableAtServer(Period)
	
	RecordSet = InformationRegisters.ResourcesWorkSchedules.CreateRecordSet();
	RecordSet.Filter.Period.Set(Period);
	RecordSet.Filter.EnterpriseResource.Set(Object.Ref);
	
	RecordSet.Write(True);
	
	RecordSet = InformationRegisters.ResourcesWorkSchedules.CreateRecordSet();
	
	NewRow = RecordSet.Add();
	NewRow.Period = Period;
	NewRow.EnterpriseResource = Object.Ref;
	NewRow.WorkSchedule = Schedule;
	
	RecordSet.Write(False);
	
	DisplayTimetableSchedule();
	
EndProcedure // SetTimetableAtServer()

// Procedure - Selection event handler of the TimetableSchedule tabular document.
//
&AtClient
Procedure TimetableScheduleSelection(Item, Area, StandardProcessing)
	
	If RadioButton = "Day"
	 OR Area.Left = 1
	 OR Area.Bottom = 1
	 OR Area.Bottom > 13
	 OR Area.Left - 1 > NumberOfDaysInMonthAtClient(Area.Bottom - 1, Year(ScheduleDate)) Then
		Return;
	EndIf;
	
	ScheduleDate = Date(Year(ScheduleDate), Area.Bottom - 1, Area.Left - 1);
	
	RadioButton = "Day";
	
	FillPresentationOfPeriod();
	DisplayTimetableSchedule();
	GenerateReturns();
	
EndProcedure // TimetableScheduleSelection()

// Procedure - SelectionStart event handler of the TimetableSchedulePeriodPresentation input field.
//
&AtClient
Procedure TimetableSchedulePresentationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ParametersStructure = New Structure("CalendarDate", ScheduleDate);
	CalendarDateBegin = Undefined;

	OpenForm("CommonForm.CalendarForm", ParametersStructure,,,,, New NotifyDescription("TimetableSchedulePeriodPresentationSelectionStartEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure TimetableSchedulePeriodPresentationSelectionStartEnd(Result, AdditionalParameters) Export
	
	If ValueIsFilled(Result) Then
		
		CalendarDateBegin = Result;
		
		ScheduleDate = EndOfDay(CalendarDateBegin);
		
		FillPresentationOfPeriod();
		DisplayTimetableSchedule();
		GenerateReturns();
		Schedule = GetCurrentSchedule();
		
	EndIf;
	
EndProcedure // TimetableSchedulePeriodPresentationSelectionStart()

// Procedure forms the results.
&AtClient
Procedure GenerateReturns()
	
	NonworkingDaysTotal = 0;
	WorkingDaysTotal = 0;
	WorkingHoursTotal = 0;
	
	WorkHours = 0;
	
	If RadioButton = "Day" Then
		
		For CurRow = 1 To 4 Do
			For CurColumn = 1 To 72 Do
				
				CurBeginOfPeriod = BegOfDay(ScheduleDate) + (CurRow - 1) * 72 * 300 + CurColumn * 300 - 300;
				TableRow = CurRow * 2;
				CoefTableColumn = ?(CurColumn / 12 - Round(CurColumn / 12) > 0, Round(CurColumn / 12 + 0.5), Round(CurColumn / 12));
				
				TableColumn = CurColumn + CoefTableColumn;
				Area = TimetableSchedule.Area("R" + TableRow + "C" + TableColumn);
				
				If Area.BackColor = BusyPeriodColor Then
					WorkHours = WorkHours + 1/12;
				EndIf;
				
			EndDo;
		EndDo;
		
		WorkingHoursTotal = Round(WorkHours);
		
	Else
		
		For MonthNumber = 1 To 12 Do
			DaysNumber = NumberOfDaysInMonthAtClient(MonthNumber, Year(ScheduleDate));
			For DayNumber = 1 To 31 Do
				If DayNumber > DaysNumber Then
					Continue;
				EndIf;
				Area = TimetableSchedule.Area("R" + String(MonthNumber + 1) + "C" + String(DayNumber + 1));
				If Area.Text = "" Then
					NonworkingDaysTotal = NonworkingDaysTotal + 1;
				Else
					WorkingDaysTotal = WorkingDaysTotal + 1;
					WorkingHoursTotal = WorkingHoursTotal + Number(?(Area.Text = "In", 0, Area.Text));
				EndIf;
			EndDo;
		EndDo;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ImportFormSettings();
	
	BusyPeriodColor = StyleColors.WorktimeCompletelyBusy;
	ColorOfFreePeriod = StyleColors.WorktimeFreeAvailable;
	
	ScheduleDate = CurrentDate();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	FillPresentationOfPeriod();
	GenerateReturns();
	
	#If WebClient Then
		ThisIsWebClient = True;
	#Else
		ThisIsWebClient = False;
	#EndIf
	
	DisplayTimetableSchedule();
	
EndProcedure // OnOpen()

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Record_KeyResources");
	
EndProcedure // AfterWrite()

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose()
	
	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("TimetableSchedulePeriodYearCheck", RadioButton = "Year");
	SettingsStructure.Insert("TimetableScheduleDayPeriodCheck", RadioButton = "Day");
	
	SettingsStructure.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	
	SaveFormSettings(SettingsStructure);
	
EndProcedure // OnClose()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - MarkSelectedAsWorking click handler.
//
&AtClient
Procedure MarkSelectedAsWorking(Command)
	
	If RadioButton = "Year" Then
		MarkSelectedAsWorkingYear();
	Else
		MarkSelectedAsWorkingDay();
	EndIf;
	
EndProcedure // MarkSelectedAsWorking()

// Procedure - MarkSelectedAsNonWorking click handler.
//
&AtClient
Procedure MarkSelectedAsNonWorking(Command)
	
	If RadioButton = "Year" Then
		MarkSelectedAsNonWorkingYear();
	Else
		MarkSelectedAsNonWorkingDay();
	EndIf;
	
EndProcedure // MarkSelectedAsNonWorking()

&AtServer
Procedure WriteResourceAtServer()
	
	ResourceForRecording = FormAttributeToValue("Object");
	ResourceForRecording.Write();
	ValueToFormAttribute(ResourceForRecording, "Object");
	
EndProcedure

// Procedure - SetTimetable click handler.
//
&AtClient
Procedure SetTimetable(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		Notification = New NotifyDescription("SetTimetableEnd",ThisForm);
		Mode = QuestionDialogMode.OKCancel;
		Text = NStr("en='You can set the schedule only after the company resource is written! Resource will be written.';ru='Установка графика возможна только после записи ресурса предприятия! Ресурс будет записан.'");
		ShowQueryBox(Notification,Text, Mode, 0);
		Return;
	EndIf;
	
	OpenForm("Catalog.WorkSchedules.ChoiceForm", New Structure("CurrentRow", Schedule), ThisForm);
	
EndProcedure // SetTimetable()

&AtClient
Procedure SetTimetableEnd(Response,Parameters) Export
	
	If Response = DialogReturnCode.OK Then
		WriteResourceAtServer();
		OpenForm("Catalog.WorkSchedules.ChoiceForm", New Structure("CurrentRow", Schedule), ThisForm);
	EndIf;
	
EndProcedure

// Procedure - TimetableScheduleExtendPeriod click handler.
//
&AtClient
Procedure TimetableScheduleExtendPeriod(Command)
	
	If RadioButton = "Year" Then
		ScheduleDate = AddMonth(ScheduleDate, 12);
	ElsIf RadioButton = "Day" Then
		ScheduleDate = ScheduleDate + 86400;
	EndIf;
	
	FillPresentationOfPeriod();
	DisplayTimetableSchedule();
	GenerateReturns();
	Schedule = GetCurrentSchedule();
	
EndProcedure // TimetableScheduleExtendPeriod()

// Procedure - TimetableScheduleShortenPeriod click handler.
//
&AtClient
Procedure TimetableScheduleShortenPeriod(Command)
	
	If RadioButton = "Year" Then
		ScheduleDate = AddMonth(ScheduleDate, -12);
	ElsIf RadioButton = "Day" Then
		ScheduleDate = ScheduleDate - 86400;
	EndIf;
	
	FillPresentationOfPeriod();
	DisplayTimetableSchedule();
	GenerateReturns();
	Schedule = GetCurrentSchedule();
	
EndProcedure // TimetableScheduleShortenPeriod()

// Procedure - CancelAllScheduleChanges click handler.
//
&AtClient
Procedure CancelAllChangesOfSchedule(Command)
	
	If RadioButton = "Year" Then
		CancelAllChangesOfScheduleYearAtServer();
	Else
		CancelAllChangesOfScheduleDayAtServer();
	EndIf;
	
	GenerateReturns();
	
EndProcedure // CancelAllScheduleChanges()


// Procedure - Settings command handler.
//
&AtClient
Procedure Settings(Command)
	
	Notification = New NotifyDescription("SettingsEnd",ThisForm);
	ParametersStructure = New Structure();
	ParametersStructure.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	OpenForm("Catalog.KeyResources.Form.Setting", ParametersStructure,,,,,Notification);
	
EndProcedure // Settings()

&AtClient
Procedure SettingsEnd(ReturnStructure,Parameters) Export
	
	If TypeOf(ReturnStructure) = Type("Structure") AND ReturnStructure.WereMadeChanges Then
		
		RepetitionFactorOFDay = ReturnStructure.RepetitionFactorOFDay;
		DisplayTimetableSchedule();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - OnActivateArea event handler of the TimetableSchedule field.
//
&AtClient
Procedure TimetableScheduleOnActivateArea(Item)
	
	Schedule = GetCurrentSchedule();
	Items.Schedule.Enabled = ValueIsFilled(Schedule);
	Items.SetTimetable.Enabled = ValueIsFilled(Schedule);
	Items.SetTimetable.Enabled = ValueIsFilled(Schedule);
	
	//If TypeOf(Schedule) = Type("String") Then
	//	Items.SetSchedule.Enabled = False;
	//EndIf;
	
	If RadioButton = "Year" AND
		(TimetableSchedule.SelectedAreas.Count() > 1
			OR (TimetableSchedule.SelectedAreas.Count() = 1
			AND (TimetableSchedule.SelectedAreas[0].Left <> TimetableSchedule.SelectedAreas[0].Right
			OR TimetableSchedule.SelectedAreas[0].Top <> TimetableSchedule.SelectedAreas[0].Bottom))) Then
		Items.SetTimetable.Enabled = False;
	EndIf;
	
EndProcedure // TimetableScheduleOnActivateArea()

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Schedule = ValueSelected Then
		Return;
	EndIf;
	
	Schedule = ValueSelected;
	
	If RadioButton = "Year" Then
		SelectedArea = TimetableSchedule.SelectedAreas[0];
		MonthNumber = SelectedArea.Top - 1;
		DayNumber = SelectedArea.Left - 1;
		If MonthNumber < 1 OR MonthNumber > 12 OR DayNumber < 1 OR DayNumber > 31 OR DayNumber > NumberOfDaysInMonthAtClient(MonthNumber, Year(ScheduleDate)) Then
			ShowMessageBox(Undefined,NStr("en='You need to select a day of schedule setting first!';ru='Вначале необходимо выделить день установки графика!'"));
			Return;
		EndIf;
		SetTimetableAtServer(Date(Year(ScheduleDate), MonthNumber, DayNumber, 0, 0, 0));
	Else
		SetTimetableAtServer(BegOfDay(ScheduleDate));
	EndIf;
	
EndProcedure

&AtClient
Procedure RadioButtonOnChange(Item)
	
	FillPresentationOfPeriod();
	DisplayTimetableSchedule();
	GenerateReturns();
	
EndProcedure

&AtClient
Procedure History(Command)
	
	OpenForm("InformationRegister.ResourcesWorkSchedules.ListForm",  New Structure("EnterpriseResource", Object.Ref), Object.Ref);

EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion
