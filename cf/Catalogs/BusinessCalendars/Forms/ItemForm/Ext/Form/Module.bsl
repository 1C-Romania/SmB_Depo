
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		FillDataThisYear(Parameters.CopyingValue);
	EndIf;
	
	DayKindColors = New FixedMap(Catalogs.BusinessCalendars.DecorColorsOfBusinessCalendarDayTypes());
	
	DayKindList = Catalogs.BusinessCalendars.DayKindList();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataExchangeSaaS") Then
		ModuleWorkOffline = CommonUse.CommonModule("OfflineWork");
		ModuleWorkOffline.ObjectOnReadAtServer(CurrentObject, ThisObject.ReadOnly);
	EndIf;
	
	FillDataThisYear();
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.DateSelection") Then
		If ValueSelected = Undefined Then
			Return;
		EndIf;
		SelectedDates = Items.Calendar.SelectedDates;
		If SelectedDates.Count() = 0 Or Year(SelectedDates[0]) <> CurrentYearNumber Then
			Return;
		EndIf;
		DestinationDate = SelectedDates[0];
		MoveDayKind(DestinationDate, ValueSelected);
		Items.Calendar.Refresh();
	EndIf;
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Var YearNumber;
	
	If Not WriteParameters.Property("YearNumber", YearNumber) Then
		YearNumber = CurrentYearNumber;
	EndIf;
	
	SpecifyBusinessCalendarData(YearNumber, CurrentObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM ITEMS EVENTS HANDLERS

&AtClient
Procedure CurrentYearNumberOnChange(Item)
	
	WriteScheduleData = False;
	If Modified Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en='Write modified data for %1 year?';ru='Записать измененные данные за %1 год?'"), 
							Format(PreviousYearNumber, "NG=0"));
		
		Notification = New NotifyDescription("CurrentYearNumberOnChangeEnd", ThisObject);
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo);
		Return;
		
	EndIf;
	
	HandleUpdateOfYear(WriteScheduleData);
	
	Modified = False;
	
	Items.Calendar.Refresh();
	
EndProcedure

&AtClient
Procedure CalendarOnPeriodOutput(Item, PeriodAppearance)
	
	For Each StringPeriodMaking IN PeriodAppearance.Dates Do
		DayAppearanceColor = DayKindColors.Get(DayKinds.Get(StringPeriodMaking.Date));
		If DayAppearanceColor = Undefined Then
			DayAppearanceColor = CommonUseClient.StyleColor("BusinessCalendarDayTypeNoDefinedColor");
		EndIf;
		StringPeriodMaking.TextColor = DayAppearanceColor;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ChangeDay(Command)
	
	SelectedDates = Items.Calendar.SelectedDates;
	
	If SelectedDates.Count() > 0 AND Year(SelectedDates[0]) = CurrentYearNumber Then
		Notification = New NotifyDescription("ChangeDayEnd", ThisObject, SelectedDates);
		ShowChooseFromList(Notification, DayKindList, , DayKindList.FindByValue(DayKinds.Get(SelectedDates[0])));
	EndIf;
	
EndProcedure

&AtClient
Procedure MoveDay(Command)
	
	SelectedDates = Items.Calendar.SelectedDates;
	
	If SelectedDates.Count() = 0 Or Year(SelectedDates[0]) <> CurrentYearNumber Then
		Return;
	EndIf;
		
	DestinationDate = SelectedDates[0];
	DayKind = DayKinds.Get(DestinationDate);
	
	DateChoiceParameters = New Structure;
	DateChoiceParameters.Insert("InitialValue",			DestinationDate);
	DateChoiceParameters.Insert("BeginOfRepresentationPeriod",	BegOfYear(Calendar));
	DateChoiceParameters.Insert("EndOfRepresentationPeriod",		EndOfYear(Calendar));
	DateChoiceParameters.Insert("Title",					NStr("en='Transfer date selection';ru='Выбор даты переноса'"));
	DateChoiceParameters.Insert("ExplanationText",				StringFunctionsClientServer.SubstituteParametersInString(
																NStr("en='Select the date on which the day will be transferred %1 (%2)';ru='Выберите дату, на которую будет осуществлен перенос дня %1 (%2)'"), 
																Format(DestinationDate, "DF=d MMMM'"), 
																DayKind));
	
	OpenForm("CommonForm.DateSelection", DateChoiceParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure FillDefault(Command)
	
	FillOfDefaultData();
	
	Items.Calendar.Refresh();
	
EndProcedure

&AtClient
Procedure Print(Command)
	
	If Object.Ref.IsEmpty() Then
		Handler = New NotifyDescription("PrintEnd", ThisObject);
		ShowQueryBox(
			Handler,
			NStr("en='Business calendar data is not written yet.
		|You can print it only after data recording.
		|
		|Record?';ru='Данные производственного календаря еще не записаны.
		|Печать возможна только после записи данных.
		|
		|Записать?'"),
			QuestionDialogMode.YesNo,
			,
			DialogReturnCode.Yes);
		Return;
	EndIf;
	
	PrintEnd(-1);
		
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillDataThisYear(CopyingValue = Undefined)
	
	// Fills in the form by the current year data.
	
	CustomizeCalendarField();
	
	CalendarRef = Object.Ref;
	If ValueIsFilled(CopyingValue) Then
		CalendarRef = CopyingValue;
		Object.Description = Undefined;
		Object.Code = Undefined;
	EndIf;
	
	ReadDataOfBusinessCalendar(CalendarRef, CurrentYearNumber);
		
EndProcedure

&AtServer
Procedure ReadDataOfBusinessCalendar(BusinessCalendar, YearNumber)
	
	// Data import of production calendar for the specified year.
	ConvertDataShopCalendar(
		Catalogs.BusinessCalendars.BusinessCalendarData(BusinessCalendar, YearNumber));
	
EndProcedure

&AtServer
Procedure FillOfDefaultData()
	
	// Fills out the form with the production calendar data composed on the basis of holidays and holiday shifts.
	
	ConvertDataShopCalendar(
		Catalogs.BusinessCalendars.ResultFillManufacturingCalendarDefault(Object.Code, CurrentYearNumber));

	Modified = True;
	
EndProcedure

&AtServer
Procedure ConvertDataShopCalendar(BusinessCalendarData)
	
	// Business calendar data is used in the form as the DayKinds and TransfersOfDays matching.
	// Procedure fills these matchings.
	
	TypesOfDaysAccordance = New Map;
	TransfersOfDaysAccordance = New Map;
	
	For Each TableRow IN BusinessCalendarData Do
		TypesOfDaysAccordance.Insert(TableRow.Date, TableRow.DayKind);
		If ValueIsFilled(TableRow.DestinationDate) Then
			TransfersOfDaysAccordance.Insert(TableRow.Date, TableRow.DestinationDate);
		EndIf;
	EndDo;
	
	DayKinds = New FixedMap(TypesOfDaysAccordance);
	TransfersOfDays = New FixedMap(TransfersOfDaysAccordance);
	
	FillPresentationTransfers(ThisObject);
	
	Items.ListTransfers.Visible = ListTransfers.Count() > 0;
	
EndProcedure

&AtServer
Procedure SpecifyBusinessCalendarData(Val YearNumber, Val CurrentObject = Undefined)
	
	// Data recording of production calendar for the specified year.
	
	If CurrentObject = Undefined Then
		CurrentObject = FormAttributeToValue("Object");
	EndIf;
	
	BusinessCalendarData = New ValueTable;
	BusinessCalendarData.Columns.Add("Date", New TypeDescription("Date"));
	BusinessCalendarData.Columns.Add("DayKind", New TypeDescription("EnumRef.BusinessCalendarDayKinds"));
	BusinessCalendarData.Columns.Add("DestinationDate", New TypeDescription("Date"));
	
	For Each KeyAndValue IN DayKinds Do
		
		TableRow = BusinessCalendarData.Add();
		TableRow.Date = KeyAndValue.Key;
		TableRow.DayKind = KeyAndValue.Value;
		
		// If day is transferred from another date, enter transfer date.
		DestinationDate = TransfersOfDays.Get(TableRow.Date);
		If DestinationDate <> Undefined 
			AND DestinationDate <> TableRow.Date Then
			TableRow.DestinationDate = DestinationDate;
		EndIf;
		
	EndDo;
	
	Catalogs.BusinessCalendars.SpecifyBusinessCalendarData(CurrentObject.Ref, YearNumber, BusinessCalendarData);
	
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
		SpecifyBusinessCalendarData(PreviousYearNumber);
	EndIf;
	
	FillDataThisYear();	
	
EndProcedure

&AtClient
Procedure ChangeDayKinds(DayDates, DayKind)
	
	// Sets the certain kind to days of all dates of the array.
	
	TypesOfDaysAccordance = New Map(DayKinds);
	
	For Each SelectedDate IN DayDates Do
		TypesOfDaysAccordance.Insert(SelectedDate, DayKind);
	EndDo;
	
	DayKinds = New FixedMap(TypesOfDaysAccordance);
	
EndProcedure

&AtClient
Procedure MoveDayKind(DestinationDate, DateAppointment)
	
	// It is necessary to replace two days with each other in the calendar
	// - exchange with day types
	// - remember transfer dates 
	// * if transferred day already has transfer date (already from
	// where it was transferred), use existing transfer date
	// * if dates match (day is returned to "its place") - delete such record.
	
	TypesOfDaysAccordance = New Map(DayKinds);
	
	TypesOfDaysAccordance.Insert(DateAppointment, DayKinds.Get(DestinationDate));
	TypesOfDaysAccordance.Insert(DestinationDate, DayKinds.Get(DateAppointment));
	
	TransfersOfDaysAccordance = New Map(TransfersOfDays);
	
	EnterDateOfTransfer(TransfersOfDaysAccordance, DestinationDate, DateAppointment);
	EnterDateOfTransfer(TransfersOfDaysAccordance, DateAppointment, DestinationDate);
	
	DayKinds = New FixedMap(TypesOfDaysAccordance);
	TransfersOfDays = New FixedMap(TransfersOfDaysAccordance);
	
	FillPresentationTransfers(ThisObject);
	
EndProcedure

&AtClient
Procedure EnterDateOfTransfer(TransfersOfDaysAccordance, DestinationDate, DateAppointment)
	
	// Fills correct transfer date in compliance with the day transfer dates.
	
	SourceDatesDayDestination = TransfersOfDays.Get(DateAppointment);
	If SourceDatesDayDestination = Undefined Then
		SourceDatesDayDestination = DateAppointment;
	EndIf;
	
	If DestinationDate = SourceDatesDayDestination Then
		TransfersOfDaysAccordance.Delete(DestinationDate);
	Else	
		TransfersOfDaysAccordance.Insert(DestinationDate, SourceDatesDayDestination);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillPresentationTransfers(Form)
	
	// Creates transfer presentation in a value list form.
	
	Form.ListTransfers.Clear();
	For Each KeyAndValue IN Form.TransfersOfDays Do
		// From the practical point of view, it is always the holiday that is shifted to the working day, therefore from two dates we select the one to which the holiday corresponded (now it is the working day that corresponds to it).
		DateSource = KeyAndValue.Key;
		DateTransmitters = KeyAndValue.Value;
		DayKind = Form.DayKinds.Get(DateSource);
		If DayKind = PredefinedValue("Enum.BusinessCalendarDayKinds.Saturday")
			Or DayKind = PredefinedValue("Enum.BusinessCalendarDayKinds.Sunday") Then
			// Replace the dates with each other to display the information on the shift as "A to B", rather than "B to A".
			DestinationDate = DateTransmitters;
			DateTransmitters = DateSource;
			DateSource = DestinationDate;
		EndIf;
		If Form.ListTransfers.FindByValue(DateSource) <> Undefined 
			Or Form.ListTransfers.FindByValue(DateTransmitters) <> Undefined Then
			// Transfer is already added, skip.
			Continue;
		EndIf;
		TypeOfDaySource = KindTransferDayPresentation(Form.DayKinds.Get(DateTransmitters), DateSource);
		TypeOfDayReceiver = KindTransferDayPresentation(Form.DayKinds.Get(DateSource), DateTransmitters);
		Form.ListTransfers.Add(DateSource, StringFunctionsClientServer.SubstituteParametersInString(
															NStr("en='%1 (%3) transferred to %2 (%4)';ru='%1 (%3) перенесен на %2 (%4)'"),
															Format(DateSource, "DF=d MMMM'"),
															Format(DateTransmitters, "DF=d MMMM'"),
															TypeOfDaySource,
															TypeOfDayReceiver));
	EndDo;
	Form.ListTransfers.SortByValue();
	
EndProcedure

&AtClientAtServerNoContext
Function KindTransferDayPresentation(DayKind, Date)
	
	// If the day is working (or holiday), then the name of a week day is displayed as a presentation.
	
	If DayKind = PredefinedValue("Enum.BusinessCalendarDayKinds.Working") 
		Or DayKind = PredefinedValue("Enum.BusinessCalendarDayKinds.Holiday") Then
		DayKind = Format(Date, "DF='dddd'");
	EndIf;
	
	Return Lower(String(DayKind));
	
EndFunction	

&AtServer
Procedure CustomizeCalendarField()
	
	If CurrentYearNumber = 0 Then
		CurrentYearNumber = Year(CurrentSessionDate());
	EndIf;
	PreviousYearNumber = CurrentYearNumber;
	
	Items.Calendar.BeginOfRepresentationPeriod	= Date(CurrentYearNumber, 1, 1);
	Items.Calendar.EndOfRepresentationPeriod	= Date(CurrentYearNumber, 12, 31);
		
EndProcedure

&AtClient
Procedure CurrentYearNumberOnChangeEnd(Response, AdditionalParameters) Export
	
	HandleUpdateOfYear(Response = DialogReturnCode.Yes);
	Modified = False;
	Items.Calendar.Refresh();
	
EndProcedure

&AtClient
Procedure ChangeDayEnd(SelectedItem, SelectedDates) Export
	
	If SelectedItem <> Undefined Then
		ChangeDayKinds(SelectedDates, SelectedItem.Value);
		Items.Calendar.Refresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintEnd(ResponseOnOfferWrite, ExecuteParameters = Undefined) Export
	
	If ResponseOnOfferWrite <> -1 Then
		If ResponseOnOfferWrite <> DialogReturnCode.Yes Then
			Return;
		EndIf;
		Recorded = Write();
		If Not Recorded Then
			Return;
		EndIf;
	EndIf;
	
	PrintParameters = New Structure;
	PrintParameters.Insert("BusinessCalendar", Object.Ref);
	PrintParameters.Insert("YearNumber", CurrentYearNumber);
	
	CommandParameter = New Array;
	CommandParameter.Add(Object.Ref);
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.Print") Then
		PrintManagementModuleClient = CommonUseClient.CommonModule("PrintManagementClient");
		PrintManagementModuleClient.ExecutePrintCommand("Catalog.BusinessCalendars", "BusinessCalendar", 
			CommandParameter, ThisObject, PrintParameters);
	EndIf;
	
EndProcedure

#EndRegion














