
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Function calculates the number of days in a month on server.
//
&AtServer
Function NumberOfDaysInMonthAtServer(Month, Year)
	
	DateOfMonth = Date(Year, Month, 1);
	DaysInMonth = Day(EndOfMonth(DateOfMonth));
	Return DaysInMonth;
	
EndFunction // NumberOfDaysInMonthAtServer()

// Function calculates the number of days in a month on client.
//
&AtClient
Function NumberOfDaysInMonthAtClient(Month, Year)
	
	DateOfMonth = Date(Year, Month, 1);
	DaysInMonth = Day(EndOfMonth(DateOfMonth));
	Return DaysInMonth;
	
EndFunction // NumberOfDaysInMonthAtClient()

// Procedure sets Visible and Enabled.
//
&AtServer
Procedure SetVisibleAndEnabled()
	
	If RadioButton = "Year" Then
		Items.TimetableSchedulePanelDay.Visible = False;
		Items.TimetableSchedulePanelYear.Visible = True;
	ElsIf RadioButton = "Day" Then
		Items.TimetableSchedulePanelDay.Visible = True;
		Items.TimetableSchedulePanelYear.Visible = False;
	EndIf;
	
	If Not Constants.FunctionalOptionPlanEnterpriseResourcesImporting.Get() Then
		Items.PageResourcesWorkingBySchedule.Visible = False;
	EndIf;

EndProcedure // SetVisibleAndEnabled()

// Procedure displays the timetable by schedule.
//
&AtServer
Procedure DisplayTimetableSchedule(PutOnlyResourcesBySchedule = False)
	
	ResourcesBySchedule.Parameters.SetParameterValue("BeginTime", BegOfMonth(ScheduleDate));
	ResourcesBySchedule.Parameters.SetParameterValue("EndTime", EndOfMonth(ScheduleDate));
	ResourcesBySchedule.Parameters.SetParameterValue("WorkSchedule", Items.List.CurrentRow);
	
	If PutOnlyResourcesBySchedule Then
		Return;
	EndIf;
	
	SetVisibleAndEnabled();
	
	If RadioButton = "Year" Then
		DisplayTimetableScheduleYear();
	ElsIf RadioButton = "Day" Then
		DisplayTimetableScheduleDay();
	EndIf;
	
	PaintList();
	
EndProcedure // DisplayTimetableSchedule()

// Procedure displays the timetable based on the schedule of the Year kind.
//
&AtServer
Procedure DisplayTimetableScheduleYear()
	
	TimetableSchedule.Clear();
	
	TimetableScheduleTemplate = Catalogs.WorkSchedules.GetTemplate("TimetableByYearSchedule");
	TemplateArea = TimetableScheduleTemplate.GetArea("Header");
	TimetableSchedule.Put(TemplateArea);
	TemplateArea = TimetableScheduleTemplate.GetArea("Calendar");
	TimetableSchedule.Put(TemplateArea);
	
	Schedule = Items.List.CurrentRow;
	BaseCalendar = ?(ValueIsFilled(Schedule), Schedule.Calendar, Undefined);
	//CalendarData = Catalogs.Calendars.ReadScheduleDataFromRegister(BaseCalendar, Year(ScheduleDate));
	CalendarData = SmallBusinessServer.ReadScheduleDataFromRegister(BaseCalendar, Year(ScheduleDate));
	
	For MonthNumber = 1 To 12 Do
		DaysNumber = NumberOfDaysInMonthAtServer(MonthNumber, Year(ScheduleDate));
		For DayNumber = 1 To 31 Do
			Area = TimetableSchedule.Area("R" + String(MonthNumber + 1) + "C" + String(DayNumber + 1));
			Area.Text = "";
			If DayNumber > DaysNumber Then
				Area.BackColor = StyleColors.FormBackColor;
			Else
				If CalendarData.Count() = 0 Then
					If WeekDay(Date(Year(ScheduleDate), MonthNumber, DayNumber, 0, 0, 0)) = 6
					 OR WeekDay(Date(Year(ScheduleDate), MonthNumber, DayNumber, 0, 0, 0)) = 7 Then
						Area.BackColor = StyleColors.NonWorkingTimeDayOff;
					Else
						Area.BackColor = StyleColors.FieldBackColor;
					EndIf;
				ElsIf CalendarData.Find(Date(Year(ScheduleDate), MonthNumber, DayNumber, 0, 0, 0)) = Undefined Then
					Area.BackColor = StyleColors.NonWorkingTimeDayOff;
				Else
					Area.BackColor = StyleColors.FieldBackColor;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	ScheduleData = Catalogs.WorkSchedules.ReadWorkScheduleDataFromRegisterForYear(Schedule, Year(ScheduleDate));
	
	While ScheduleData.Next() Do
		ScheduleIsDisplayed = True;
		Value = Round((ScheduleData.EndTime - ScheduleData.BeginTime) / 3600, 1);
		TableRow = Month(ScheduleData.BeginTime) + 1;
		TableColumn = Day(ScheduleData.BeginTime) + 1;
		Area = TimetableSchedule.Area("R" + TableRow + "C" + TableColumn);
		Area.Text = String(Number(?(ValueIsFilled(Area.Text), Area.Text, 0)) + Value);
	EndDo;
	
EndProcedure // DisplayTimetableScheduleYear()

// Procedure displays the timetable based on the schedule of the Day kind.
//
&AtServer
Procedure DisplayTimetableScheduleDay()
	
	TimetableSchedule.Clear();
	
	TimetableScheduleTemplate = Catalogs.WorkSchedules.GetTemplate("TimetableByDaySchedule");
	
	TemplateArea = TimetableScheduleTemplate.GetArea("Calendar" + String(RepetitionFactorOFDay));
	
	TimetableSchedule.Put(TemplateArea);
	
	Schedule = Items.List.CurrentRow;
	
	TimetableScheduleTemplate = Catalogs.WorkSchedules.GetTemplate("TimetableByDaySchedule");
	
	ScheduleData = Catalogs.WorkSchedules.ReadWorkScheduleDataFromRegisterForDay(Schedule, ScheduleDate);
	
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
	
EndProcedure // DisplayTimetableScheduleDay()

// Procedure fills the period presentation.
//
&AtClient
Procedure FillPresentationOfPeriod()
	
	If RadioButton = "Year" Then
		TimetableSchedulePresentationPeriod = "" + Format(Year(ScheduleDate),"NG=") + " year";
	ElsIf RadioButton = "Day" Then
		DayOfSchedule = Format(ScheduleDate, "DF=dd");
		MonthOfSchedule = Format(ScheduleDate, "DF=MMM");
		YearOfSchedule = Format(Year(ScheduleDate), "NG=0");
		WeekDayOfSchedule = SmallBusinessClient.GetPresentationOfWeekDay(ScheduleDate);
		TimetableSchedulePresentationPeriod = WeekDayOfSchedule + " " + DayOfSchedule + " " + MonthOfSchedule + " " + YearOfSchedule;
	EndIf;
	
	MonthOfSchedule = Format(ScheduleDate, "DF=MMM");
	YearOfSchedule = Format(Year(ScheduleDate), "NG=0");
	ResourcesWorkBySchedulePeriodPresentation = MonthOfSchedule + " " + YearOfSchedule;
	
EndProcedure // FillPeriodPresentation()

// Procedure writes the schedule to the register.
//
&AtServer
Procedure WriteScheduleToRegister()
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	WorkSchedules.WorkSchedule,
	|	WorkSchedules.Year,
	|	WorkSchedules.BeginTime,
	|	WorkSchedules.EndTime
	|FROM
	|	InformationRegister.WorkSchedules AS WorkSchedules
	|WHERE
	|	WorkSchedules.WorkSchedule = &WorkSchedule
	|	AND WorkSchedules.Year = &Year
	|	AND WorkSchedules.BeginTime >= &BeginTime
	|	AND WorkSchedules.EndTime <= &EndTime";
	
	WorkSchedule = Items.List.CurrentRow;
	
	Query.SetParameter("WorkSchedule", WorkSchedule);
	Query.SetParameter("Year", Year(ScheduleDate));
	Query.SetParameter("BeginTime", BegOfDay(ScheduleDate));
	Query.SetParameter("EndTime", EndOfDay(ScheduleDate));
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	RecordSet = InformationRegisters.WorkSchedules.CreateRecordSet();
	
	While SelectionOfQueryResult.Next() Do
		RecordSet.Filter.WorkSchedule.Set(SelectionOfQueryResult.WorkSchedule);
		RecordSet.Filter.Year.Set(SelectionOfQueryResult.Year);
		RecordSet.Filter.BeginTime.Set(SelectionOfQueryResult.BeginTime);
		RecordSet.Filter.EndTime.Set(SelectionOfQueryResult.EndTime);
		RecordSet.Write(True);
	EndDo;
	
	RecordSet = InformationRegisters.WorkSchedules.CreateRecordSet();
	
	IntervalIsOpened = False;
	
	ColumnsCount = 360 / RepetitionFactorOFDay;
	NumberOfSecondsInPeriod = RepetitionFactorOFDay * 60;
	NumberOfPeriodsInColumn = 60 / RepetitionFactorOFDay;
	
	For CurRow = 1 To 4 Do
		For CurColumn = 1 To ColumnsCount Do
			
			CurBeginOfPeriod = BegOfDay(ScheduleDate) + (CurRow - 1) * ColumnsCount * NumberOfSecondsInPeriod + CurColumn * NumberOfSecondsInPeriod - NumberOfSecondsInPeriod;
			TableRow = CurRow * 2;
			CoefTableColumn = ?(CurColumn / NumberOfPeriodsInColumn - Round(CurColumn / NumberOfPeriodsInColumn) > 0, Round(CurColumn / NumberOfPeriodsInColumn + 0.5), Round(CurColumn / NumberOfPeriodsInColumn));
			
			TableColumn = CurColumn + CurColumn * (RepetitionFactorOFDay / 5 - 1) - RepetitionFactorOFDay / 5 + 1 + CoefTableColumn;
			Area = TimetableSchedule.Area("R" + TableRow + "C" + TableColumn);
			
			If Area.BackColor = StyleColors.WorktimeCompletelyBusy Then
				If Not IntervalIsOpened Then
					IntervalIsOpened = True;
					NewRow = RecordSet.Add();
					NewRow.WorkSchedule = WorkSchedule;
					NewRow.Year = Year(ScheduleDate);
					NewRow.BeginTime = CurBeginOfPeriod;
				EndIf;
			Else
				If IntervalIsOpened Then
					IntervalIsOpened = False;
					NewRow.EndTime = CurBeginOfPeriod;
				EndIf;
			EndIf;
			
			If CurColumn = ColumnsCount AND CurRow = 4 AND IntervalIsOpened Then
				IntervalIsOpened = False;
				NewRow.EndTime = EndOfDay(ScheduleDate);
			EndIf;
			
		EndDo;
	EndDo;
	
	RecordSet.Write(False);
	
EndProcedure // WriteScheduleToRegister()

// Procedure clears the day of schedule in the register.
//
&AtServerNoContext
Procedure ClearDayOfScheduleInRegister(WorkSchedule, Day)
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	WorkSchedules.WorkSchedule,
	|	WorkSchedules.Year,
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
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	RecordSet = InformationRegisters.WorkSchedules.CreateRecordSet();
	
	While SelectionOfQueryResult.Next() Do
		RecordSet.Filter.WorkSchedule.Set(SelectionOfQueryResult.WorkSchedule);
		RecordSet.Filter.Year.Set(SelectionOfQueryResult.Year);
		RecordSet.Filter.BeginTime.Set(SelectionOfQueryResult.BeginTime);
		RecordSet.Filter.EndTime.Set(SelectionOfQueryResult.EndTime);
		RecordSet.Write(True);
	EndDo;
	
EndProcedure // WriteScheduleToRegister()

// Procedure sets the color for the selected areas.
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

// Procedure checks the option to set color.
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

// Procedure saves the form settings.
//
&AtServerNoContext
Procedure SaveFormSettings(SettingsStructure)
	
	FormDataSettingsStorage.Save("WorkSchedules", "SettingsStructure", SettingsStructure);
	
EndProcedure // SaveFormSettings()

// Procedure imports the form settings.
//
&AtServer
Procedure ImportFormSettings()
	
	SettingsStructure = FormDataSettingsStorage.Load("WorkSchedules", "SettingsStructure");
	
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

// Procedure fills the schedule based on the pattern on server.
//
&AtServer
Procedure FillByTemplateAtServer(Schedule, DateOfFilling)
	
	Catalogs.WorkSchedules.WriteScheduleDataToRegister(Schedule, DateOfFilling);
	DisplayTimetableSchedule();
	
EndProcedure // FillByTemplateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ImportFormSettings();
	
	ScheduleDate = CurrentDate();
	
	ResourcesBySchedule.Parameters.SetParameterValue("BeginTime", BegOfMonth(ScheduleDate));
	ResourcesBySchedule.Parameters.SetParameterValue("EndTime", EndOfMonth(ScheduleDate));
	ResourcesBySchedule.Parameters.SetParameterValue("WorkSchedule", Undefined);
	
	BusyPeriodColor = StyleColors.WorktimeCompletelyBusy;
	ColorOfFreePeriod = StyleColors.WorktimeFreeAvailable;
	
	SetVisibleAndEnabled();
	
EndProcedure // OnCreateAtServer()

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	FillPresentationOfPeriod();
	
EndProcedure // OnOpen()

// Procedure - event handler OnClose form.
//
&AtClient
Procedure OnClose()
	
	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("TimetableScheduleDayPeriodCheck", RadioButton = "Day");
	SettingsStructure.Insert("TimetableSchedulePeriodYearCheck", RadioButton = "Year");
	
	SettingsStructure.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	
	SaveFormSettings(SettingsStructure);
	
EndProcedure // OnClose()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

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
	
EndProcedure // TimetableScheduleShortenPeriod()

// Procedure - handler of clicking the TimetableScheduleEdit button.
//
&AtClient
Procedure TimetableScheduleEdit(Command)
	
	SelectedArea = TimetableSchedule.SelectedAreas[0];
	
	If RadioButton = "Day"
	 OR SelectedArea.Left = 1
	 OR SelectedArea.Bottom = 1
	 OR SelectedArea.Bottom > 13
	 OR SelectedArea.Left - 1 > NumberOfDaysInMonthAtClient(SelectedArea.Bottom - 1, Year(ScheduleDate)) Then
		Return;
	EndIf;
	
	ScheduleDate = Date(Year(ScheduleDate), SelectedArea.Bottom - 1, SelectedArea.Left - 1);
	
	RadioButton = "Day";
	
	FillPresentationOfPeriod();
	DisplayTimetableSchedule();
	
EndProcedure // TimetableScheduleEdit()

// Procedure - MarkSelectedAsWorking click handler.
//
&AtClient
Procedure MarkSelectedAsWorking(Command)
	
	SetBackColorForChoosedAreas(BusyPeriodColor);
	WriteScheduleToRegister();
	
EndProcedure // MarkSelectedAsWorking()

// Procedure - handler of clicking the MarkSelectedAsNonWorking button.
//
&AtClient
Procedure MarkSelectedAsNonWorking(Command)
	
	SetBackColorForChoosedAreas(ColorOfFreePeriod);
	WriteScheduleToRegister();
	
EndProcedure // MarkSelectedAsNonWorking()

// Procedure - handler of clicking the ResourcesWorkByScheduleShortenPeriod button.
//
&AtClient
Procedure ResourcesWorkByScheduleShortenPeriod(Command)
	
	ScheduleDate = AddMonth(ScheduleDate, -1);
	
	FillPresentationOfPeriod();
	DisplayTimetableSchedule();
	
EndProcedure // ResourcesWorkByScheduleShortenPeriod()

// Procedure - handler of clicking the ResourcesWorkByScheduleExtendPeriod button.
//
&AtClient
Procedure ResourcesWorkByScheduleExtendPeriod(Command)
	
	ScheduleDate = AddMonth(ScheduleDate, 1);
	
	FillPresentationOfPeriod();
	DisplayTimetableSchedule();
	
EndProcedure // ResourcesWorkByScheduleExtendPeriod()

// Procedure - Settings command handler.
//
&AtClient
Procedure Settings(Command)
	
	ParametersStructure = New Structure();
	ParametersStructure.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	Notification = New NotifyDescription("SettingsEnd",ThisForm);
	OpenForm("Catalog.WorkSchedules.Form.Setting", ParametersStructure,,,,,Notification);
	
EndProcedure // Settings()

&AtClient
Procedure SettingsEnd(ReturnStructure,Parameters) Export

	If TypeOf(ReturnStructure) = Type("Structure") AND ReturnStructure.WereMadeChanges Then
		RepetitionFactorOFDay = ReturnStructure.RepetitionFactorOFDay;
		DisplayTimetableSchedule();
	EndIf;

EndProcedure // SettingsEnd()


// Procedure - handler of the TimetableScheduleCreate command.
//
&AtClient
Procedure TimetableScheduleCreate(Command)
	
	OpenForm("InformationRegister.ResourcesWorkSchedules.RecordForm", New Structure("WorkSchedule", Items.List.CurrentRow));
	
EndProcedure // TimetableScheduleCreate()

// Procedure - handler of the TimetableScheduleDelete command.
//
&AtClient
Procedure TimetableScheduleDelete(Command)
	
	SelectedArea = TimetableSchedule.SelectedAreas[0];
	
	If RadioButton = "Day"
	 OR SelectedArea.Left = 1
	 OR SelectedArea.Bottom = 1
	 OR SelectedArea.Bottom > 13
	 OR SelectedArea.Left - 1 > NumberOfDaysInMonthAtClient(SelectedArea.Bottom - 1, Year(ScheduleDate)) Then
		Return;
	EndIf;
	
	WorkSchedule = Items.List.CurrentRow;
	DayGraphics = Date(Year(ScheduleDate), SelectedArea.Bottom - 1, SelectedArea.Left - 1);
	
	ClearDayOfScheduleInRegister(WorkSchedule, DayGraphics);
	
	DisplayTimetableSchedule();
	
EndProcedure // TimetableScheduleDelete()

// Procedure - handler of the FillByTemplate command.
//
&AtClient
Procedure FillByTemplate(Command)
	
	SelectedArea = TimetableSchedule.SelectedAreas[0];
	Schedule = Items.List.CurrentRow;
	
	If RadioButton = "Day"
	 OR SelectedArea.Left = 1
	 OR SelectedArea.Bottom = 1
	 OR SelectedArea.Bottom > 13
	 OR SelectedArea.Left - 1 > NumberOfDaysInMonthAtClient(SelectedArea.Bottom - 1, Year(ScheduleDate)) Then
		FillByTemplateAtServer(Schedule, BegOfYear(ScheduleDate));
	Else
		DayGraphics = Date(Year(ScheduleDate), SelectedArea.Bottom - 1, SelectedArea.Left - 1);
		FillByTemplateAtServer(Schedule, DayGraphics);
	EndIf;
	
EndProcedure // FillByTemplate()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - event handler StartChoice of the PeriodPresentation input field.
//
&AtClient
Procedure PeriodPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ParametersStructure = New Structure("CalendarDate", ScheduleDate);
	Notification = New NotifyDescription("PeriodPresentationStartChoiceEnd",ThisForm);
	OpenForm("CommonForm.CalendarForm", ParametersStructure,,,,,Notification);
	
EndProcedure // PeriodPresentationStartChoice()

&AtClient
Procedure PeriodPresentationStartChoiceEnd(Result,Parameters) Export
	
	If ValueIsFilled(Result) Then
		
		ScheduleDate = Result;
		FillPresentationOfPeriod();
		
	EndIf;

EndProcedure // PeriodPresentationStartChoice()


// Procedure - event handler Choice of the TimetableSchedule input field.
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
	
EndProcedure // TimetableScheduleSelection()

// Procedure - event handler OnActivateRow of the List list.
//
&AtClient
Procedure ListOnActivateRow(Item)
	
	If Items.List.CurrentRow = Undefined Then
		Items.GroupPages.Enabled = False;
		Return;
	Else
		Items.GroupPages.Enabled = True;
	EndIf;
	
	DisplayTimetableSchedule();
	
EndProcedure // ListOnActivateRow()

// Procedure - event handler StartChoice of the Presentation field of the ResourcesWorkBySchedule list.
//
&AtClient
Procedure ResourcesWorkBySchedulePeriodPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ParametersStructure = New Structure("CalendarDate", ScheduleDate);
	Notification = New NotifyDescription("ResourcesRunningOnSchedulePeriodPresentationStartChoiceEnd", ThisForm);
	OpenForm("CommonForm.CalendarForm", ParametersStructure,,,,,Notification);
	
EndProcedure // ResourcesWorkBySchedulePeriodPresentationStartChoice()

&AtClient
Procedure ResourcesRunningOnSchedulePeriodPresentationStartChoiceEnd(Result, Parameters) Export
	
	If ValueIsFilled(Result) Then
		
		ScheduleDate = Result;
		FillPresentationOfPeriod();
		
	EndIf;
	
EndProcedure

// Procedure colors list.
//
&AtServer
Procedure PaintList()
	
	// List coloring
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem IN List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	
	For Each Item IN ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	SelectionWorkSchedules = Catalogs.WorkSchedules.Select();
	While SelectionWorkSchedules.Next() Do
		
		BackColor = SelectionWorkSchedules.Color.Get();
		If TypeOf(BackColor) <> Type("Color") Then
			Continue;
		EndIf;
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Ref");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = SelectionWorkSchedules.Ref;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("BackColor", BackColor);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Text", " ");
		
		FilterField = ConditionalAppearanceItem.Fields.Items.Add();
		FilterField.Use = True;
		FilterField.Field = New DataCompositionField("Marker");
		
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "By event state " + SelectionWorkSchedules.Description;
	
	EndDo;
	
EndProcedure // PaintList()

&AtClient
Procedure PagesGroupOnCurrentPageChange(Item, CurrentPage)
	
	If Items.GroupPages.CurrentPage = Items.PageResourcesWorkingBySchedule Then
		DisplayTimetableSchedule(True);
	EndIf;
	
EndProcedure

&AtClient
Procedure RadioButtonOnChange(Item)
	
	FillPresentationOfPeriod();
	DisplayTimetableSchedule();
	
EndProcedure
