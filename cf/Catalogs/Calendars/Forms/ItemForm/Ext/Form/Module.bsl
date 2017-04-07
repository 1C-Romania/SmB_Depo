&AtClient
Var SelectContext;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Object.Ref.IsEmpty() Then
		Return;
	EndIf;	
	
	// If the production schedule in the system is exclusive, we fill it in by default.
	BusinessCalendars = Catalogs.BusinessCalendars.BusinessCalendarsList();
	If BusinessCalendars.Count() = 1 Then
		Object.BusinessCalendar = BusinessCalendars[0];
	EndIf;
	
	Object.FillMethod = Enums.WorkScheduleFillingMethods.ByWeeks;
	
	CycleLength = 7;
	
	Object.StartDate = BegOfYear(CurrentSessionDate());
	Object.BeginnigDate = BegOfYear(CurrentSessionDate());
	
	SetItemsSettingsFill(ThisObject);
	
	GenerateFillTemplate(Object.FillMethod, Object.FillTemplate, CycleLength, Object.BeginnigDate);
	
	FillPresentationSchedule();
	
	SetEnabledAccountForHolidays(ThisObject);
	
	SpecifyDateOfOccupancyRate();
	
	FillDataThisYear(Parameters.CopyingValue);
	
	SetRemoveSignPatternMatchResults(ThisObject, True);
	
	SetEnabledTimesheetIncludedDays(ThisObject);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	CycleLength = Object.FillTemplate.Count();
	
	SetItemsSettingsFill(ThisObject);
	
	GenerateFillTemplate(Object.FillMethod, Object.FillTemplate, CycleLength, Object.BeginnigDate);
	
	FillPresentationSchedule();
	
	SetEnabledAccountForHolidays(ThisObject);
	
	SpecifyDateOfOccupancyRate();
	
	FillDataThisYear();
	
	SetRemoveSignPatternMatchResults(ThisObject, True);
	SetRemoveModifiedTemplate(ThisObject, False);
	
	SetEnabledTimesheetIncludedDays(ThisObject);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("Catalog.Calendars.Form.WorkSchedule") Then
		
		If ValueSelected = Undefined Or ReadOnly Then
			Return;
		EndIf;
		
		// Delete previously filled in the day schedule.
		RowsOfDay = New Array;
		For Each TimetableString IN Object.WorkSchedule Do
			If TimetableString.DayNumber = SelectContext.DayNumber Then
				RowsOfDay.Add(TimetableString.GetID());
			EndIf;
		EndDo;
		For Each RowID IN RowsOfDay Do
			Object.WorkSchedule.Delete(Object.WorkSchedule.FindByID(RowID));
		EndDo;
		
		// Fill in the work schedule for the day.
		For Each DetailsOfInterval IN ValueSelected.WorkSchedule Do
			NewRow = Object.WorkSchedule.Add();
			FillPropertyValues(NewRow, DetailsOfInterval);
			NewRow.DayNumber = SelectContext.DayNumber;
		EndDo;
		
		SetRemoveSignPatternMatchResults(ThisObject, False);
		SetRemoveModifiedTemplate(ThisObject, True);
		
		If SelectContext.Source = "FillTemplateChoice" Then
			
			RowTemplate = Object.FillTemplate.FindByID(SelectContext.IDRowsTemplate);
			RowTemplate.DayIncludedInSchedule = ValueSelected.WorkSchedule.Count() > 0; // the schedule is filled
			RowTemplate.SchedulePresentation = ScheduleForDayPresentation(ThisObject, SelectContext.DayNumber);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	Var YearNumber;
	
	If Not WriteParameters.Property("YearNumber", YearNumber) Then
		YearNumber = CurrentYearNumber;
	EndIf;
	
	// If the data of the current year is edited manually, we write it as it is, other periods are updated by the pattern.
	
	If ModifiedResults Then
		Catalogs.Calendars.WriteScheduleDataToRegister(CurrentObject.Ref, ScheduleDays, Date(YearNumber, 1, 1), Date(YearNumber, 12, 31), True);
	EndIf;
	WriteSignManualEditing(CurrentObject, YearNumber);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	CycleLength = Object.FillTemplate.Count();
	
	SetItemsSettingsFill(ThisObject);
	
	GenerateFillTemplate(Object.FillMethod, Object.FillTemplate, CycleLength, Object.BeginnigDate);
	
	FillPresentationSchedule();
	
	SpecifyDateOfOccupancyRate();
	
	SetRemoveModifiedTemplate(ThisObject, False);
	
	FillDataThisYear();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.FillMethod = Enums.WorkScheduleFillingMethods.ByCyclesOfAnyLength Then
		CheckedAttributes.Add("CycleLength");
		CheckedAttributes.Add("BeginnigDate");
	EndIf;
	
	If Object.FillTemplate.FindRows(New Structure("DayIncludedInSchedule", True)).Count() = 0 Then
		CommonUseClientServer.MessageToUser(
			NStr("en='Days included in the work schedule are not marked';ru='Не отмечены дни, включаемые в график работы'"), , "Object.FillTemplate", , Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure FillByTemplate(Command)
	
	FillByTemplateAtServer();
	
	Items.WorkSchedule.Refresh();
	
EndProcedure

&AtClient
Procedure ResultFill(Command)
	
	Items.Pages.CurrentPage = Items.ResultFillPage;
	
	If Not ResultFillByPattern Then
		FillByTemplateAtServer(True);
	EndIf;
	
	Items.WorkSchedule.Refresh();
	
EndProcedure

&AtClient
Procedure OptionsFill(Command)
	
	Items.Pages.CurrentPage = Items.OptionsFillPage;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM ITEMS EVENTS HANDLERS

&AtClient
Procedure BusinessCalendarOnChange(Item)
	
	SetEnabledAccountForHolidays(ThisObject);
	
	SetRemoveSignPatternMatchResults(ThisObject, False);
	SetRemoveModifiedTemplate(ThisObject, True);
	
EndProcedure

&AtClient
Procedure FillMethodOnChange(Item)

	SetItemsSettingsFill(ThisObject);
	
	GenerateFillTemplate(Object.FillMethod, Object.FillTemplate, CycleLength, Object.BeginnigDate);
	
	SetRemoveSignPatternMatchResults(ThisObject, False);
	SetRemoveModifiedTemplate(ThisObject, True);
	
EndProcedure

&AtClient
Procedure BeginDateOnChange(Item)
	
	If Object.StartDate < Date(1900, 1, 1) Then
		Object.StartDate = BegOfYear(CommonUseClient.SessionDate());
	EndIf;
	
EndProcedure

&AtClient
Procedure DateReferenceOnChange(Item)
	
	If Object.BeginnigDate < Date(1900, 1, 1) Then
		Object.BeginnigDate = BegOfYear(CommonUseClient.SessionDate());
	EndIf;
	
	GenerateFillTemplate(Object.FillMethod, Object.FillTemplate, CycleLength, Object.BeginnigDate);
	
	SetRemoveSignPatternMatchResults(ThisObject, False);
	SetRemoveModifiedTemplate(ThisObject, True);
	
EndProcedure

&AtClient
Procedure CycleLengthOnChange(Item)
	
	GenerateFillTemplate(Object.FillMethod, Object.FillTemplate, CycleLength, Object.BeginnigDate);
	
	SetRemoveSignPatternMatchResults(ThisObject, False);
	SetRemoveModifiedTemplate(ThisObject, True);
	
EndProcedure

&AtClient
Procedure ConsiderHolidaysOnChange(Item)
	
	SetRemoveSignPatternMatchResults(ThisObject, False);
	SetRemoveModifiedTemplate(ThisObject, True);
	
	SetEnabledTimesheetIncludedDays(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetEnabledTimesheetIncludedDays(Form)
	Form.Items.SchedulePreHolidayDay.Enabled = Form.Object.ConsiderHolidays;
EndProcedure

&AtClient
Procedure FillTemplateChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	RowTemplate = Object.FillTemplate.FindByID(SelectedRow);
	
	SelectContext = New Structure;
	SelectContext.Insert("Source", "FillTemplateChoice");
	SelectContext.Insert("DayNumber", RowTemplate.LineNumber);
	SelectContext.Insert("SchedulePresentation", RowTemplate.SchedulePresentation);
	SelectContext.Insert("IDRowsTemplate", SelectedRow);
	
	FormParameters = New Structure;
	FormParameters.Insert("WorkSchedule", WorkSchedule(SelectContext.DayNumber));
	FormParameters.Insert("ReadOnly", ReadOnly);
	
	OpenForm("Catalog.Calendars.Form.WorkSchedule", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure FillTemplateDayEnabledInLineOnChange(Item)
	
	SetRemoveSignPatternMatchResults(ThisObject, False);
	SetRemoveModifiedTemplate(ThisObject, True);
	
EndProcedure

&AtClient
Procedure SchedulePreHolidayDayClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectContext = New Structure;
	SelectContext.Insert("Source", "SchedulePreHolidayDayClick");
	SelectContext.Insert("DayNumber", 0);
	SelectContext.Insert("SchedulePresentation", SchedulePreHolidayDay);
	
	FormParameters = New Structure;
	FormParameters.Insert("WorkSchedule", WorkSchedule(SelectContext.DayNumber));
	FormParameters.Insert("ReadOnly", ReadOnly);
	
	OpenForm("Catalog.Calendars.Form.WorkSchedule", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure PlanningHorizonOnChange(Item)
	
	ClarifyOccupancyGraphics(ThisObject);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonUseClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Object.Definition");
	
EndProcedure

&AtClient
Procedure CurrentYearNumberOnChange(Item)
	
	If CurrentYearNumber < Year(Object.StartDate)
		Or (ValueIsFilled(Object.EndDate) AND CurrentYearNumber > Year(Object.EndDate)) Then
		CurrentYearNumber = PreviousYearNumber;
		Return;
	EndIf;
	
	WriteScheduleData = False;
	
	If ModifiedResults Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en='Write modified data for %1 year?';ru='Записать измененные данные за %1 год?'"), 
							Format(PreviousYearNumber, "NG=0"));
		
		Notification = New NotifyDescription("CurrentYearNumberOnChangeEnd", ThisObject);
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo);
		Return;
		
	EndIf;
	
	HandleUpdateOfYear(WriteScheduleData);
	
	SetRemoveModifiedResult(ThisObject, False);
	
	Items.WorkSchedule.Refresh();
	
EndProcedure

&AtClient
Procedure WorkScheduleOnPeriodOutput(Item, PeriodAppearance)
	
	For Each StringPeriodMaking IN PeriodAppearance.Dates Do
		If ScheduleDays.Get(StringPeriodMaking.Date) = Undefined Then
			TextColorOfDay = CommonUseClient.StyleColor("BusinessCalendarDayTypeNoDefinedColor");
		Else
			TextColorOfDay = CommonUseClient.StyleColor("BusinessCalendarDayTypeWorkColor");
		EndIf;
		StringPeriodMaking.TextColor = TextColorOfDay;
		// Manual editing
		If ModifiedDays.Get(StringPeriodMaking.Date) = Undefined Then
			BackColorOfDay = CommonUseClient.StyleColor("FieldBackColor");
		Else
			BackColorOfDay = CommonUseClient.StyleColor("ScheduleDateChangedBackground");
		EndIf;
		StringPeriodMaking.BackColor = BackColorOfDay;
	EndDo;
	
EndProcedure

&AtClient
Procedure WorkScheduleChoice(Item, SelectedDate)
	
	If ScheduleDays.Get(SelectedDate) = Undefined Then
		// Include in the schedule
		WorkSchedulesClientServer.InsertFixedMap(ScheduleDays, SelectedDate, True);
		DayIncludedInSchedule = True;
	Else
		// Exclude from the diagram
		WorkSchedulesClientServer.DeleteFromFixedMatch(ScheduleDays, SelectedDate);
		DayIncludedInSchedule = False;
	EndIf;
	
	// Record the manual change of the date.
	WorkSchedulesClientServer.InsertFixedMap(ModifiedDays, SelectedDate, DayIncludedInSchedule);
	
	Items.WorkSchedule.Refresh();
	
	SetRemoveSignOfManualEditing(ThisObject, True);
	SetRemoveModifiedResult(ThisObject, True);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FillTemplatePresentationSchedule.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.FillTemplate.SchedulePresentation");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.FillTemplate.DayIncludedInSchedule");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("Text", NStr("en='Fill in schedule';ru='Заполнить расписание'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FillTemplateLineNumber.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.FillMethod");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = Enums.WorkScheduleFillingMethods.ByWeeks;

	Item.Appearance.SetParameterValue("Visible", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OccupancyInformationText.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("RequiresFill");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ResultFillInformationText.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ResultFillByPattern");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ManualEdit");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SchedulePreHolidayDay.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("SchedulePreHolidayDay");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.ConsiderHolidays");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("Text", NStr("en='Fill in schedule';ru='Заполнить расписание'"));

EndProcedure

&AtClientAtServerNoContext
Procedure SetItemsSettingsFill(Form)
	
	EnabledSettings = Form.Object.FillMethod = PredefinedValue("Enum.WorkScheduleFillingMethods.ByCyclesOfAnyLength");
	
	Form.Items.CycleLength.ReadOnly = Not EnabledSettings;
	Form.Items.BeginnigDate.ReadOnly = Not EnabledSettings;
	
	Form.Items.BeginnigDate.AutoMarkIncomplete = EnabledSettings;
	Form.Items.BeginnigDate.MarkIncomplete = EnabledSettings AND Not ValueIsFilled(Form.Object.BeginnigDate);
	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateFillTemplate(FillMethod, FillTemplate, Val CycleLength, Val BeginnigDate = Undefined)
	
	// Creates a table to edit the template for filling by days.
	
	If FillMethod = PredefinedValue("Enum.WorkScheduleFillingMethods.ByWeeks") Then
		CycleLength = 7;
	EndIf;
	
	While FillTemplate.Count() > CycleLength Do
		FillTemplate.Delete(FillTemplate.Count() - 1);
	EndDo;

	While FillTemplate.Count() < CycleLength Do
		FillTemplate.Add();
	EndDo;
	
	If FillMethod = PredefinedValue("Enum.WorkScheduleFillingMethods.ByWeeks") Then
		FillTemplate[0].DayPresentation = NStr("en='Monday';ru='Понедельник'");
		FillTemplate[1].DayPresentation = NStr("en='Tuesday';ru='Вторник'");
		FillTemplate[2].DayPresentation = NStr("en='Wednesday';ru='Среда'");
		FillTemplate[3].DayPresentation = NStr("en='Thursday';ru='Четверг'");
		FillTemplate[4].DayPresentation = NStr("en='Friday';ru='Пятница'");
		FillTemplate[5].DayPresentation = NStr("en='Saturday';ru='Суббота'");
		FillTemplate[6].DayPresentation = NStr("en='Sunday';ru='Воскресенье'");
	Else
		DateOfDay = BeginnigDate;
		For Each RowDay IN FillTemplate Do
			RowDay.DayPresentation = Format(DateOfDay, "DF=d.MM");
			DateOfDay = DateOfDay + 86400;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillPresentationSchedule()
	
	For Each RowTemplate IN Object.FillTemplate Do
		RowTemplate.SchedulePresentation = ScheduleForDayPresentation(ThisObject, RowTemplate.LineNumber);
	EndDo;
	
	SchedulePreHolidayDay = ScheduleForDayPresentation(ThisObject, 0);
	
EndProcedure

&AtClientAtServerNoContext
Function ScheduleForDayPresentation(Form, DayNumber)
	
	IntervalsPresentation = "";
	Seconds = 0;
	For Each TimetableString IN Form.Object.WorkSchedule Do
		If TimetableString.DayNumber <> DayNumber Then
			Continue;
		EndIf;
		IntervalsPresentation = IntervalsPresentation 
			+ StringFunctionsClientServer.SubstituteParametersInString("%1-%2, ", 
				Format(TimetableString.BeginTime, "DF=HH:mm; DP="), 
				Format(TimetableString.EndTime, "DF=HH:mm; DP="));
		If Not ValueIsFilled(TimetableString.EndTime) Then
			SecondsInterval = EndOfDay(TimetableString.EndTime) - TimetableString.BeginTime + 1;
		Else
			SecondsInterval = TimetableString.EndTime - TimetableString.BeginTime;
		EndIf;
		Seconds = Seconds + SecondsInterval;
	EndDo;
	StringFunctionsClientServer.DeleteLatestCharInRow(IntervalsPresentation, 2);
	
	If Seconds = 0 Then
		Return NStr("en='Fill in schedule';ru='Заполнить расписание'");
	EndIf;
	
	Hours = Round(Seconds / 3600, 1);
	
	Return StringFunctionsClientServer.SubstituteParametersInString(NStr("en='% p. (%2)';ru='%1 ч. (%2)'"), Hours, IntervalsPresentation);
	
EndFunction

&AtClient
Function WorkSchedule(DayNumber)
	
	DailySchedule = New Array;
	
	For Each TimetableString IN Object.WorkSchedule Do
		If TimetableString.DayNumber = DayNumber Then
			DailySchedule.Add(New Structure("BeginTime, EndTime", TimetableString.BeginTime, TimetableString.EndTime));
		EndIf;
	EndDo;
	
	Return DailySchedule;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetEnabledAccountForHolidays(Form)
	
	Form.Items.ConsiderHolidays.Enabled = ValueIsFilled(Form.Object.BusinessCalendar);
	If Not Form.Items.ConsiderHolidays.Enabled Then
		Form.Object.ConsiderHolidays = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure SpecifyDateOfOccupancyRate()
	
	QueryText = 
	"SELECT
	|	MAX(CalendarSchedules.ScheduleDate) AS Date
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.Calendar = &WorkSchedule";
	
	Query = New Query(QueryText);
	Query.SetParameter("WorkSchedule", Object.Ref);
	Selection = Query.Execute().Select();
	
	DateOccupancyRate = Undefined;
	If Selection.Next() Then
		DateOccupancyRate = Selection.Date;
	EndIf;	
	
	ClarifyOccupancyGraphics(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure ClarifyOccupancyGraphics(Form)
	
	Form.RequiresFill = False;
	
	If Form.Parameters.Key.IsEmpty() Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Form.DateOccupancyRate) Then
		Form.OccupancyInformationText = NStr("en='The work schedule is not filled';ru='График работы не заполнен'");
		Form.RequiresFill = True;
	Else	
		If Not ValueIsFilled(Form.Object.PlanningHorizon) Then
			Form.OccupancyInformationText = StringFunctionsClientServer.SubstituteParametersInString(
													NStr("en='Work schedule is filled to %1';ru='График работы заполнен до %1'"), 
													Format(Form.DateOccupancyRate, "DLF=D"));
		Else											
			#If Client Then
				CurrentDate = CommonUseClient.SessionDate();
			#Else
				CurrentDate = CurrentSessionDate();
			#EndIf
			EndPlanningHorizon = AddMonth(CurrentDate, Form.Object.PlanningHorizon);
			Form.OccupancyInformationText = StringFunctionsClientServer.SubstituteParametersInString(
													NStr("en='Work schedule is filled till %1, in terms of the planning horizon the schedule must be filled till %2';ru='График работы заполнен до %1, с учетом горизонта планирования график должен быть заполнен до %2'"), 
													Format(Form.DateOccupancyRate, "DLF=D"),
													Format(EndPlanningHorizon, "DLF=D"));
			If EndPlanningHorizon > Form.DateOccupancyRate Then
				Form.RequiresFill = True;
			EndIf;
		EndIf;
	EndIf;
	Form.Items.OccupancyDecoration.Picture = ?(Form.RequiresFill, PictureLib.Warning, PictureLib.Information);
	
EndProcedure

&AtServer
Procedure FillByTemplateAtServer(StoreManualEdit = False)

	DaysIncludedInSchedule = Catalogs.Calendars.DaysIncludedInSchedule(
								Object.StartDate, 
								Object.FillMethod, 
								Object.FillTemplate, 
								Object.EndDate,
								Object.BusinessCalendar, 
								Object.ConsiderHolidays, 
								Object.BeginnigDate);
	
	If ManualEdit Then
		If StoreManualEdit Then
			// Transfer manual corrections.
			For Each KeyAndValue IN ModifiedDays Do
				DateChanges = KeyAndValue.Key;
				DayIncludedInSchedule = KeyAndValue.Value;
				If DayIncludedInSchedule Then
					DaysIncludedInSchedule.Insert(DateChanges, True);
				Else
					DaysIncludedInSchedule.Delete(DateChanges);
				EndIf;
			EndDo;
		Else
			SetRemoveModifiedResult(ThisObject, True);
			SetRemoveSignOfManualEditing(ThisObject, False);
		EndIf;
	EndIf;
	
	// Move the result to the original filling matching in order not to remove the dates outside the filling interval.
	DaysGraphicsAccordance = New Map(ScheduleDays);
	DateOfDay = Object.StartDate;
	EndDate = Object.EndDate;
	If Not ValueIsFilled(EndDate) Then
		EndDate = EndOfYear(Object.StartDate);
	EndIf;
	While DateOfDay <= EndDate Do
		DayIncludedInSchedule = DaysIncludedInSchedule[DateOfDay];
		If DayIncludedInSchedule = Undefined Then
			DaysGraphicsAccordance.Delete(DateOfDay);
		Else
			DaysGraphicsAccordance.Insert(DateOfDay, DayIncludedInSchedule);
		EndIf;
		DateOfDay = DateOfDay + 86400;
	EndDo;
	
	ScheduleDays = New FixedMap(DaysGraphicsAccordance);
	
	SetRemoveSignPatternMatchResults(ThisObject, True);
	
EndProcedure

&AtServer
Procedure FillDataThisYear(CopyingValue = Undefined)
	
	// Fills in the form by the current year data.
	
	CustomizeCalendarField();
	
	If ValueIsFilled(CopyingValue) Then
		LineReference = CopyingValue;
	Else
		LineReference = Object.Ref;
	EndIf;
	
	ScheduleDays = New FixedMap(
		Catalogs.Calendars.ReadScheduleDataFromRegister(LineReference, CurrentYearNumber));

	ReadSignManualEditing(Object, CurrentYearNumber);
	
	// If there is no manual corrections and data, we generate the result using the template for the selected year.
	If ScheduleDays.Count() = 0 AND ModifiedDays.Count() = 0 Then
		DaysIncludedInSchedule = Catalogs.Calendars.DaysIncludedInSchedule(
									Object.StartDate, 
									Object.FillMethod, 
									Object.FillTemplate, 
									Date(CurrentYearNumber, 12, 31),
									Object.BusinessCalendar, 
									Object.ConsiderHolidays, 
									Object.BeginnigDate);
		ScheduleDays = New FixedMap(DaysIncludedInSchedule);
	EndIf;
	
	SetRemoveModifiedResult(ThisObject, False);
	SetRemoveSignPatternMatchResults(ThisObject, Not ModifiedTemplate);

EndProcedure

&AtServer
Procedure ReadSignManualEditing(CurrentObject, YearNumber)
	
	If CurrentObject.Ref.IsEmpty() Then
		SetRemoveSignOfManualEditing(ThisObject, False);
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	ManualChanges.ScheduleDate
	|FROM
	|	InformationRegister.WorkSchedulesManualChanges AS ManualChanges
	|WHERE
	|	ManualChanges.WorkSchedule = &WorkSchedule
	|	AND ManualChanges.Year = &Year");
	
	Query.SetParameter("WorkSchedule", CurrentObject.Ref);
	Query.SetParameter("Year", YearNumber);
	
	Map = New Map;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Map.Insert(Selection.ScheduleDate, True);
	EndDo;
	ModifiedDays = New FixedMap(Map);
	
	SetRemoveSignOfManualEditing(ThisObject, ModifiedDays.Count() > 0);
	
EndProcedure

&AtServer
Procedure WriteSignManualEditing(CurrentObject, YearNumber)
	
	RecordSet = InformationRegisters.WorkSchedulesManualChanges.CreateRecordSet();
	RecordSet.Filter.WorkSchedule.Set(CurrentObject.Ref);
	RecordSet.Filter.Year.Set(YearNumber);
	
	For Each KeyAndValue IN ModifiedDays Do
		SetRow = RecordSet.Add();
		SetRow.ScheduleDate = KeyAndValue.Key;
		SetRow.WorkSchedule = CurrentObject.Ref;
		SetRow.Year = YearNumber;
	EndDo;
	
	RecordSet.Write();
	
EndProcedure

&AtServer
Procedure WriteScheduleDataWorkForYear(YearNumber)
	
	Catalogs.Calendars.WriteScheduleDataToRegister(Object.Ref, ScheduleDays, Date(YearNumber, 1, 1), Date(YearNumber, 12, 31), True);
	WriteSignManualEditing(Object, YearNumber);
	
EndProcedure

&AtServer
Procedure HandleUpdateOfYear(WriteScheduleData)
	
	If Not WriteScheduleData Then
		FillDataThisYear();
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		Write(New Structure("YearNumber", PreviousYearNumber));
	Else
		WriteScheduleDataWorkForYear(PreviousYearNumber);
		FillDataThisYear();	
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetRemoveSignOfManualEditing(Form, ManualEdit)
	
	Form.ManualEdit = ManualEdit;
	
	If Not ManualEdit Then
		Form.ModifiedDays = New FixedMap(New Map);
	EndIf;
	
	FillTextFillResultInformation(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetRemoveSignPatternMatchResults(Form, ResultFillByPattern)
	
	Form.ResultFillByPattern = ResultFillByPattern;
	
	FillTextFillResultInformation(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetRemoveModifiedTemplate(Form, ModifiedTemplate)
	
	Form.ModifiedTemplate = ModifiedTemplate;
	
	Form.Modified = Form.ModifiedTemplate Or Form.ModifiedResults;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetRemoveModifiedResult(Form, ModifiedResults)
	
	Form.ModifiedResults = ModifiedResults;
	
	Form.Modified = Form.ModifiedTemplate Or Form.ModifiedResults;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillTextFillResultInformation(Form)
	
	InformationalText = "";
	InformationalPicture = New Picture;
	AvailableFillingPattern = False;
	If Form.ManualEdit Then
		InformationalText = NStr("en='Work schedule for the current year is changed manually. Click ""Fill by template"" to return to automatic filling.';ru='График работы на текущий год изменен вручную. Нажмите ""Заполнить по шаблону"" чтобы вернуться к автоматическому заполнению.'");
		InformationalPicture = PictureLib.Warning;
		AvailableFillingPattern = True;
	Else
		If Form.ResultFillByPattern Then
			If ValueIsFilled(Form.Object.BusinessCalendar) Then
				InformationalText = NStr("en='Work schedule is automatically updated when changing the production calendar for the current period.';ru='График работы автоматически обновляется при изменении производственного календаря за текущий год.'");
				InformationalPicture = PictureLib.Information;
			EndIf;
		Else
			InformationalText = NStr("en='The displayed result does not match the template setting. Click ""Fill by template"" to see how the work schedule looks like with respect to the template modifications.';ru='Нажмите ""Заполнить по шаблону"", чтобы увидеть как выглядит график работы с учетом изменений шаблона.'");
			InformationalPicture = PictureLib.Warning;
			AvailableFillingPattern = True;
		EndIf;
	EndIf;
	
	Form.ResultFillInformationText = InformationalText;
	Form.Items.ResultFillDecoration.Picture = InformationalPicture;
	Form.Items.FillByTemplate.Enabled = AvailableFillingPattern;
	
	FillInformationTextEditing(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillInformationTextEditing(Form)
	
	InformationalText = "";
	InformationalPicture = New Picture;
	If Form.ManualEdit Then
		InformationalPicture = PictureLib.Warning;
		InformationalText = NStr("en='Work schedule for the current year is changed manually. Changes are highlighted in the filling results.';ru='График работы на текущий год изменен вручную. Изменения выделены в результатах заполнения.'");
	EndIf;
	
	Form.ManualEditTextInformation = InformationalText;
	Form.Items.ManualEditDecoration.Picture = InformationalPicture;
	
EndProcedure

&AtServer
Procedure CustomizeCalendarField()
	
	If CurrentYearNumber = 0 Then
		CurrentYearNumber = Year(CurrentSessionDate());
	EndIf;
	PreviousYearNumber = CurrentYearNumber;
	
	WorkSchedule = Date(CurrentYearNumber, 1, 1);
	Items.WorkSchedule.BeginOfRepresentationPeriod	= Date(CurrentYearNumber, 1, 1);
	Items.WorkSchedule.EndOfRepresentationPeriod	= Date(CurrentYearNumber, 12, 31);
		
EndProcedure

&AtClient
Procedure CurrentYearNumberOnChangeEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		WriteScheduleData = True;
	EndIf;
	
	HandleUpdateOfYear(WriteScheduleData);
	SetRemoveModifiedResult(ThisObject, False);
	Items.WorkSchedule.Refresh();
	
EndProcedure

#EndRegion
