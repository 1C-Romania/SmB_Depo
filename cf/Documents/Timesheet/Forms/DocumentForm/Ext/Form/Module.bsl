////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServerNoContext
// It receives data set from server for the DateOnChange procedure.
//
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	StructureData = New Structure();
	StructureData.Insert("DATEDIFF", SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange));
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", SmallBusinessServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

&AtClient
// Procedure - sets days of the week in the table header.
//
Procedure SetWeekDays()
	
	If Object.DataInputMethod <> PredefinedValue("Enum.TimeDataInputMethods.TotalForPeriod") Then
	
		AccordanceDaysOfWeek = New Map;
		AccordanceDaysOfWeek.Insert(1, "Mo");
		AccordanceDaysOfWeek.Insert(2, "Tu");
		AccordanceDaysOfWeek.Insert(3, "We");
		AccordanceDaysOfWeek.Insert(4, "Th");
		AccordanceDaysOfWeek.Insert(5, "Fr");
		AccordanceDaysOfWeek.Insert(6, "Sa");
		AccordanceDaysOfWeek.Insert(7, "Su"); 
		
		For Day = 1 To Day(EndOfMonth(Object.RegistrationPeriod)) Do
			Items["WorkedTimeByDaysFirstHours" + Day].Title = AccordanceDaysOfWeek.Get(WeekDay(Date(Year(Object.RegistrationPeriod), Month(Object.RegistrationPeriod), Day)));
		EndDo;
		
		For Day = 29 To Day(EndOfMonth(Object.RegistrationPeriod)) Do
			Items["WorkedTimeByDaysFirstHours" + Day].Visible = True;
			Items["WorkedTimeByDaysSecondHours" + Day].Visible = True;
			Items["WorkedTimeByDaysThirdHours" + Day].Visible = True;
			Items["WorkedTimeByDaysFirstTypeOfTime" + Day].Visible = True;
			Items["WorkedTimeByDaysSecondTypeOfTime" + Day].Visible = True;
			Items["WorkedTimeByDaysThirdTypeOfTime" + Day].Visible = True;
		EndDo;
		
		For Day = Day(EndOfMonth(Object.RegistrationPeriod)) + 1 To 31 Do
			Items["WorkedTimeByDaysFirstHours" + Day].Visible = False;
			Items["WorkedTimeByDaysSecondHours" + Day].Visible = False;
			Items["WorkedTimeByDaysThirdHours" + Day].Visible = False;
			Items["WorkedTimeByDaysFirstTypeOfTime" + Day].Visible = False;
			Items["WorkedTimeByDaysSecondTypeOfTime" + Day].Visible = False;
			Items["WorkedTimeByDaysThirdTypeOfTime" + Day].Visible = False;
		EndDo;
		
	EndIf;
	
EndProcedure

// Function - returns the position of employee.
//
&AtServerNoContext
Function FillPosition(Structure)
	
	Query = New Query(
	"SELECT
	|	EmployeesSliceLast.Position
	|FROM
	|	InformationRegister.Employees.SliceLast(
	|			&Date,
	|			Company = &Company
	|				AND Employee = &Employee) AS EmployeesSliceLast");
	
	Query.SetParameter("Date", Structure.Date);
	Query.SetParameter("Company", Structure.Company);
	Query.SetParameter("Employee", Structure.Employee);
	Result = Query.Execute();
	
	Return ?(Result.IsEmpty(), 
		Catalogs.Positions.EmptyRef(), 
			Result.Unload()[0].Position);
	
EndFunction // FillInPosition()
 
&AtServer
// The procedure fills in tabular section with division staff according to the production calendar.
//
Procedure FillTimesheet()
	
	Query = New Query;
		
	Query.SetParameter("Company", SubsidiaryCompany);
	Query.SetParameter("Calendar", SubsidiaryCompany.BusinessCalendar);
	Query.SetParameter("StructuralUnit", Object.StructuralUnit);
	Query.SetParameter("StartDate", Object.RegistrationPeriod);
	Query.SetParameter("EndDate", EndOfMonth(Object.RegistrationPeriod));
	
	Query.Text =
	"SELECT
	|	EmployeesSliceLast.Employee AS Employee,
	|	EmployeesSliceLast.Position AS Position
	|INTO YourEmployees
	|FROM
	|	InformationRegister.Employees.SliceLast(&StartDate, Company = &Company) AS EmployeesSliceLast
	|WHERE
	|	EmployeesSliceLast.StructuralUnit = &StructuralUnit
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	Employees.Employee,
	|	Employees.Position
	|FROM
	|	InformationRegister.Employees AS Employees
	|WHERE
	|	Employees.Company = &Company
	|	AND Employees.Period between &StartDate AND &EndDate
	|	AND Employees.StructuralUnit = &StructuralUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EmployeeCalendar.Employee AS Employee,
	|	EmployeeCalendar.Position AS Position,
	|	EmployeeCalendar.ScheduleDate AS ScheduleDate,
	|	Employees.Period AS Period,
	|	CASE
	|		WHEN Employees.StructuralUnit = &StructuralUnit
	|				AND Employees.Position = EmployeeCalendar.Position
	|			THEN 8 * Employees.OccupiedRates
	|		ELSE 0
	|	END AS Hours,
	|	CASE
	|		WHEN Employees.StructuralUnit = &StructuralUnit
	|				AND Employees.Position = EmployeeCalendar.Position
	|			THEN 1
	|		ELSE 0
	|	END AS Days
	|FROM
	|	(SELECT
	|		YourEmployees.Employee AS Employee,
	|		YourEmployees.Position AS Position,
	|		CalendarSchedules.ScheduleDate AS ScheduleDate
	|	FROM
	|		YourEmployees AS YourEmployees
	|			LEFT JOIN InformationRegister.CalendarSchedules AS CalendarSchedules
	|			ON (TRUE)
	|	WHERE
	|		CalendarSchedules.Calendar = &Calendar
	|		AND CalendarSchedules.ScheduleDate between &StartDate AND &EndDate
	|		AND CalendarSchedules.DayIncludedInSchedule) AS EmployeeCalendar
	|		LEFT JOIN (SELECT
	|			&StartDate AS Period,
	|			EmployeesSliceLast.Employee AS Employee,
	|			EmployeesSliceLast.StructuralUnit AS StructuralUnit,
	|			EmployeesSliceLast.Position AS Position,
	|			EmployeesSliceLast.OccupiedRates AS OccupiedRates
	|		FROM
	|			InformationRegister.Employees.SliceLast(
	|					&StartDate,
	|					Company = &Company
	|						AND StructuralUnit = &StructuralUnit) AS EmployeesSliceLast
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			Employees.Period,
	|			Employees.Employee,
	|			Employees.StructuralUnit,
	|			Employees.Position,
	|			Employees.OccupiedRates
	|		FROM
	|			InformationRegister.Employees AS Employees
	|		WHERE
	|			Employees.Company = &Company
	|			AND Employees.Period between DATEADD(&StartDate, Day, 1) AND &EndDate) AS Employees
	|		ON EmployeeCalendar.Employee = Employees.Employee
	|			AND EmployeeCalendar.ScheduleDate >= Employees.Period
	|
	|ORDER BY
	|	Employee,
	|	Position,
	|	ScheduleDate,
	|	Period DESC
	|TOTALS BY
	|	Employee,
	|	Position,
	|	ScheduleDate";
				   
	QueryResult = Query.ExecuteBatch();
	
	TimeKind = Catalogs.WorkingHoursKinds.Work;
	
	If Object.DataInputMethod = Enums.TimeDataInputMethods.ByDays Then
		
		Object.WorkedTimeByDays.Clear();
		
		SelectionEmployee = QueryResult[1].Select(QueryResultIteration.ByGroups, "Employee");
		While SelectionEmployee.Next() Do
		
			SelectionPosition = SelectionEmployee.Select(QueryResultIteration.ByGroups, "Position");	
			While SelectionPosition.Next() Do
				
				NewRow 			= Object.WorkedTimeByDays.Add();
				NewRow.Employee 	= SelectionPosition.Employee;
				NewRow.Position 	= SelectionPosition.Position;
				
				SelectionScheduleDate = SelectionPosition.Select(QueryResultIteration.ByGroups, "ScheduleDate");	
				While SelectionScheduleDate.Next() Do
				
					Selection = SelectionScheduleDate.Select();
					While Selection.Next() Do
						
						If Selection.Hours > 0 Then
						
							Day = Day(SelectionScheduleDate.ScheduleDate);
							
							NewRow["FirstTimeKind" + Day] 	= TimeKind;
							NewRow["FirstHours" + Day] 		= Selection.Hours;	
						
						EndIf; 
						
						Break;
						
					EndDo; 
				
				EndDo; 
				
			EndDo;			
			
		EndDo;
		
	Else		
		
		Object.WorkedTimePerPeriod.Clear();					   
					   
		SelectionEmployee = QueryResult[1].Select(QueryResultIteration.ByGroups, "Employee");
		While SelectionEmployee.Next() Do
		
			SelectionPosition = SelectionEmployee.Select(QueryResultIteration.ByGroups, "Position");	
			While SelectionPosition.Next() Do
				
				DaysNumber = 0;
				HoursCount = 0;
				
				SelectionScheduleDate = SelectionPosition.Select(QueryResultIteration.ByGroups, "ScheduleDate");	
				While SelectionScheduleDate.Next() Do
				
					Selection = SelectionScheduleDate.Select();
					While Selection.Next() Do
						DaysNumber 	= DaysNumber + Selection.Days;
						HoursCount = HoursCount + Selection.Hours;
						Break;
					EndDo; 
				
				EndDo; 
				
				NewRow 			= Object.WorkedTimePerPeriod.Add();
				NewRow.Employee 	= SelectionPosition.Employee;
				NewRow.Position 	= SelectionPosition.Position;
				NewRow.TimeKind1 = TimeKind;
				NewRow.Days1 		= DaysNumber;
				NewRow.Hours1 		= HoursCount;
				
			EndDo;			
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
// The function fills in the list of time kinds available for selection.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Function GetChoiceList(ArrayRestrictions)

	Query = New Query("SELECT
	                      |	WorkingHoursKinds.Ref
	                      |FROM
	                      |	Catalog.WorkingHoursKinds AS WorkingHoursKinds
	                      |WHERE
	                      |	(NOT WorkingHoursKinds.Ref IN (&ArrayRestrictions))
	                      |
	                      |ORDER BY
	                      |	WorkingHoursKinds.Description");
						  
	Query.SetParameter("ArrayRestrictions", ArrayRestrictions);					  
	Selection = Query.Execute().Select();
	
	ChoiceList = New ValueList;
	
	While Selection.Next() Do
		ChoiceList.Add(Selection.Ref);	
	EndDo; 
	
	Return ChoiceList

EndFunction // GetChoiceList()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed,
	Parameters.FillingValues);
	
	If Not ValueIsFilled(Object.Ref)
		AND Not (Parameters.FillingValues.Property("RegistrationPeriod") AND ValueIsFilled(Parameters.FillingValues.RegistrationPeriod)) Then
		Object.RegistrationPeriod 	= BegOfMonth(CurrentDate());
	EndIf;
	
	RegistrationPeriodPresentation = Format(ThisForm.Object.RegistrationPeriod, "DF='MMMM yyyy'");
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	If Object.DataInputMethod = PredefinedValue("Enum.TimeDataInputMethods.TotalForPeriod") Then
		Items.Pages.CurrentPage = Items.GroupWorkedTimeForPeriod;
	Else	
		Items.Pages.CurrentPage = Items.GroupWorkedTimeByDays;
	EndIf;
	
	If Object.DataInputMethod <> PredefinedValue("Enum.TimeDataInputMethods.TotalForPeriod") Then
	
		AccordanceDaysOfWeek = New Map;
		AccordanceDaysOfWeek.Insert(1, "Mo");
		AccordanceDaysOfWeek.Insert(2, "Tu");
		AccordanceDaysOfWeek.Insert(3, "We");
		AccordanceDaysOfWeek.Insert(4, "Th");
		AccordanceDaysOfWeek.Insert(5, "Fr");
		AccordanceDaysOfWeek.Insert(6, "Sa");
		AccordanceDaysOfWeek.Insert(7, "Su"); 
		
		For Day = 1 To Day(EndOfMonth(Object.RegistrationPeriod)) Do
			Items["WorkedTimeByDaysFirstHours" + Day].Title = AccordanceDaysOfWeek.Get(WeekDay(Date(Year(Object.RegistrationPeriod), Month(Object.RegistrationPeriod), Day)));
		EndDo;
		
		For Day = 28 To Day(EndOfMonth(Object.RegistrationPeriod)) Do
			Items["WorkedTimeByDaysFirstHours" + Day].Visible = True;
			Items["WorkedTimeByDaysSecondHours" + Day].Visible = True;
			Items["WorkedTimeByDaysThirdHours" + Day].Visible = True;
			Items["WorkedTimeByDaysFirstTypeOfTime" + Day].Visible = True;
			Items["WorkedTimeByDaysSecondTypeOfTime" + Day].Visible = True;
			Items["WorkedTimeByDaysThirdTypeOfTime" + Day].Visible = True;
		EndDo;
		
		For Day = Day(EndOfMonth(Object.RegistrationPeriod)) + 1 To 31 Do
			Items["WorkedTimeByDaysFirstHours" + Day].Visible = False;
			Items["WorkedTimeByDaysSecondHours" + Day].Visible = False;
			Items["WorkedTimeByDaysThirdHours" + Day].Visible = False;
			Items["WorkedTimeByDaysFirstTypeOfTime" + Day].Visible = False;
			Items["WorkedTimeByDaysSecondTypeOfTime" + Day].Visible = False;
			Items["WorkedTimeByDaysThirdTypeOfTime" + Day].Visible = False;
		EndDo;
		
	EndIf;
	
	If Not Constants.FunctionalOptionUseJobSharing.Get() Then
		If Items.Find("WorkedTimeDuringPeriodOfEmployeeCode") <> Undefined Then
			Items.WorkedTimeDuringPeriodOfEmployeeCode.Visible = False;
		EndIf;
		If Items.Find("WorkedTimeByDayOfEmployeeCode") <> Undefined Then
			Items.WorkedTimeByDayOfEmployeeCode.Visible = False;
		EndIf;
	EndIf;
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure // OnReadAtServer()

&AtClient
// Procedure - form event handler ChoiceProcessing
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ManagedForm")
		AND Find(ChoiceSource.FormName, "CalendarForm") > 0 Then
		
		Object.RegistrationPeriod = EndOfDay(ValueSelected);
		SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
		SetWeekDays();
		
	EndIf;
	
EndProcedure // ChoiceProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - event handler StartChoice of attribute RegistrationPeriod.
//
&AtClient
Procedure RegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(Object.RegistrationPeriod), Object.RegistrationPeriod, SmallBusinessReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.CalendarForm", SmallBusinessClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure //RegistrationPeriodStartChoice()

// Procedure - event handler Management of attribute RegistrationPeriod.
//
&AtClient
Procedure RegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	SmallBusinessClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
	SetWeekDays();
	
EndProcedure //RegistrationPeriodTuning()

&AtClient
// Procedure - OnChange event handler of DataInputMethod attribute.
//
Procedure DataInputMethodOnChange(Item)
	
	If Object.DataInputMethod = PredefinedValue("Enum.TimeDataInputMethods.TotalForPeriod") Then	
		Items.Pages.CurrentPage = Items.GroupWorkedTimeForPeriod;	
	Else	
		Items.Pages.CurrentPage = Items.GroupWorkedTimeByDays;	
	EndIf;
	
	If Object.DataInputMethod = PredefinedValue("Enum.TimeDataInputMethods.TotalForPeriod") Then
		Object.WorkedTimeByDays.Clear();
	Else
		Object.WorkedTimePerPeriod.Clear();
	EndIf;

EndProcedure

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure // DateOnChange()

&AtClient
// Procedure - event handler OnChange of the Company input field.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure // CompanyOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTIONS EVENT HANDLERS

&AtClient
// Procedure - event handler OnChange input field Employee.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure WorkedTimePerPeriodEmployeeOnChange(Item)
	
	If Not ValueIsFilled(Object.RegistrationPeriod) Then
		Return;
	EndIf; 
	
	CurrentData = Items.WorkedTimePerPeriod.CurrentData;
	
	Structure = New Structure;
	Structure.Insert("Date", EndOfMonth(Object.RegistrationPeriod));
	Structure.Insert("Company", Object.Company);
	Structure.Insert("Employee", CurrentData.Employee);
	CurrentData.Position = FillPosition(Structure);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field Employee.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure WorkedTimeByDaysEmployeeOnChange(Item)
	
	If Not ValueIsFilled(Object.RegistrationPeriod) Then
		Return;
	EndIf; 
	
	CurrentData = Items.WorkedTimeByDays.CurrentData;
	
	Structure = New Structure;
	Structure.Insert("Date", EndOfMonth(Object.RegistrationPeriod));
	Structure.Insert("Company", Object.Company);
	Structure.Insert("Employee", CurrentData.Employee);
	CurrentData.Position = FillPosition(Structure);
	
EndProcedure

&AtClient
// Procedure - FillIn command handler.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure Fill(Command)
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		SmallBusinessClient.ShowMessageAboutError(Object, "Division is not specified.");
		Return;
	EndIf;
	
	If Object.RegistrationPeriod = '00010101000000' Then
		SmallBusinessClient.ShowMessageAboutError(Object, "Registration period is not specified.");
		Return;
	EndIf;
	
	Mode = QuestionDialogMode.YesNo;
	If Object.WorkedTimeByDays.Count() > 0
	 OR Object.WorkedTimePerPeriod.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillEnd", ThisObject), NStr("en='Tabular section will be cleared. Continue?';ru='Табличная часть будет очищена! Продолжить выполнение операции?'"), Mode, 0);
	Else
		FillTimesheet();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillTimesheet();
    Else 
        Return;
    EndIf;

EndProcedure // Fill()

&AtClient
// Procedure - OnChange event handler of TimeKind1 input field.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure WorkedTimePerPeriodTimeKindStartChoice(Item, ChoiceData, StandardProcessing)	
	
	StandardProcessing = False;
	
	CurrentRow = Items.WorkedTimePerPeriod.CurrentData;
	ItemNumber = Right(Item.Name, 1);
	
	ArrayRestrictions = New Array;
	For Counter = 1 To 6 Do
		If Counter = ItemNumber Then
			Continue;		
		EndIf; 
		ArrayRestrictions.Add(CurrentRow["TimeKind" + Counter]);	
	EndDo; 
	
	ChoiceData = GetChoiceList(ArrayRestrictions);
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of FirstTimeKind input field.
//
Procedure WorkedTimeByDaysFirstTimeKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentRow = Items.WorkedTimeByDays.CurrentData;
	ItemNumber = StrReplace(Item.Name, "WorkedTimeByDaysFirstTypeOfTime", "");
	
	ArrayRestrictions = New Array;
	ArrayRestrictions.Add(CurrentRow["SecondTimeKind" + ItemNumber]);
	ArrayRestrictions.Add(CurrentRow["ThirdTimeKind" + ItemNumber]);
	
	ChoiceData = GetChoiceList(ArrayRestrictions);
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of SecondTimeKind input field.
//
Procedure WorkedTimeByDaysSecondTimeKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentRow = Items.WorkedTimeByDays.CurrentData;
	ItemNumber = StrReplace(Item.Name, "WorkedTimeByDaysSecondTypeOfTime", "");
	
	ArrayRestrictions = New Array;
	ArrayRestrictions.Add(CurrentRow["FirstTimeKind" + ItemNumber]);
	ArrayRestrictions.Add(CurrentRow["ThirdTimeKind" + ItemNumber]);
	
	ChoiceData = GetChoiceList(ArrayRestrictions);
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of ThirdTimeKind input field.
//
Procedure WorkedTimeByDaysThirdTimeKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentRow = Items.WorkedTimeByDays.CurrentData;
	ItemNumber = StrReplace(Item.Name, "WorkedTimeByDaysThirdTypeOfTime", "");
	
	ArrayRestrictions = New Array;
	ArrayRestrictions.Add(CurrentRow["SecondTimeKind" + ItemNumber]);
	ArrayRestrictions.Add(CurrentRow["FirstTimeKind" + ItemNumber]);
	
	ChoiceData = GetChoiceList(ArrayRestrictions);
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
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



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
