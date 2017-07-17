////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Function forms and performs query.
//
Function ExecuteQuery()
	
	SetPrivilegedMode(True);
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	AccrualsAndDeductions.Employee AS Ind,
	|	AccrualsAndDeductions.Employee.Code AS EmployeeCode,
	|	AccrualsAndDeductions.StructuralUnit AS Department,
	|	AccrualsAndDeductions.StructuralUnit.Description AS DepartmentPresentation,
	|	EmployeesSliceLast.Position AS Position,
	|	CASE
	|		WHEN AccrualsAndDeductions.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|			THEN AccrualsAndDeductions.AccrualDeductionKind
	|		ELSE NULL
	|	END AS Accrual,
	|	CASE
	|		WHEN AccrualsAndDeductions.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|			THEN NULL
	|		ELSE AccrualsAndDeductions.AccrualDeductionKind
	|	END AS Deduction,
	|	SUM(CASE
	|			WHEN AccrualsAndDeductions.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|				THEN ISNULL(AccrualsAndDeductions.AmountCur, 0)
	|			ELSE 0
	|		END) AS AmountAccrued,
	|	SUM(CASE
	|			WHEN AccrualsAndDeductions.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|				THEN 0
	|			ELSE ISNULL(AccrualsAndDeductions.AmountCur, 0)
	|		END) AS AmountWithheld,
	|	CASE
	|		WHEN AccrualsAndDeductions.AccrualDeductionKind = VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePayment)
	|				OR AccrualsAndDeductions.AccrualDeductionKind = VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePaymentPercent)
	|			THEN &RegistrationPeriod
	|		ELSE AccrualsAndDeductions.StartDate
	|	END AS StartDate,
	|	CASE
	|		WHEN AccrualsAndDeductions.AccrualDeductionKind = VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePayment)
	|				OR AccrualsAndDeductions.AccrualDeductionKind = VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePaymentPercent)
	|			THEN ENDOFPERIOD(&RegistrationPeriod, MONTH)
	|		ELSE AccrualsAndDeductions.EndDate
	|	END AS EndDate,
	|	SUM(AccrualsAndDeductions.DaysWorked) AS DaysWorked,
	|	SUM(AccrualsAndDeductions.HoursWorked) AS HoursWorked,
	|	ISNULL(DebtAtEnd.AmountCurBalance, 0) AS ClosingBalance,
	|	ISNULL(DebtToBegin.AmountCurBalance, 0) AS BalanceAtBegin,
	|	IndividualsDescriptionFullSliceLast.Surname AS Surname,
	|	IndividualsDescriptionFullSliceLast.Name AS Name,
	|	IndividualsDescriptionFullSliceLast.Patronymic AS Patronymic,
	|	CASE
	|		WHEN ISNULL(IndividualsDescriptionFullSliceLast.Surname, """") <> """"
	|			THEN IndividualsDescriptionFullSliceLast.Surname + "" "" + IndividualsDescriptionFullSliceLast.Name + "" "" + IndividualsDescriptionFullSliceLast.Patronymic
	|		ELSE AccrualsAndDeductions.Employee.Description
	|	END AS EmployeePresentation
	|FROM
	|	AccumulationRegister.AccrualsAndDeductions AS AccrualsAndDeductions
	|		LEFT JOIN AccumulationRegister.PayrollPayments.Balance(
	|				&RegistrationPeriod,
	|				Company = &Company
	|					AND Currency = &Currency
	|					" + ?(Not ValueIsFilled(Department), "", "AND StructuralUnit = &Department") + ") AS DebtToBegin 
	|		ON AccrualsAndDeductions.Employee = DebtToBegin.Employee 
	|			AND AccrualsAndDeductions.StructuralUnit = DebtToBegin.StructuralUnit 
	|		LEFT JOIN AccumulationRegister.PayrollPayments.Balance( 
	|				&RegistrationEndOfPeriod, 
	|				Company = &Company 
	|					AND Currency = &Currency
	|					" + ?(Not ValueIsFilled(Department), "", "AND StructuralUnit = &Department") + ") AS DebtAtEnd 
	|		ON AccrualsAndDeductions.Employee = DebtAtEnd.Employee 
	|			AND AccrualsAndDeductions.StructuralUnit = DebtAtEnd.StructuralUnit 
	|		LEFT JOIN InformationRegister.Employees.SliceLast(
	|				&RegistrationEndOfPeriod, 
	|				Company = &Company 
	|					AND StructuralUnit <> VALUE(Catalog.StructuralUnits.EmptyRef)) AS EmployeesSliceLast 
	|		ON AccrualsAndDeductions.Employee = EmployeesSliceLast.Employee
	|		LEFT JOIN InformationRegister.IndividualsDescriptionFull.SliceLast(&RegistrationEndOfPeriod, ) AS IndividualsDescriptionFullSliceLast 
	|		ON AccrualsAndDeductions.Employee.Ind = IndividualsDescriptionFullSliceLast.Ind
	|WHERE 
	|	AccrualsAndDeductions.Company = &Company 
	|	AND AccrualsAndDeductions.RegistrationPeriod = &RegistrationPeriod 
	|	AND AccrualsAndDeductions.Currency = &Currency" + ?(Not ValueIsFilled(Department), "", "
	|	AND AccrualsAndDeductions.StructuralUnit = &Department") + " " + ?(Not ValueIsFilled(Employee), "", "
	|	AND AccrualsAndDeductions.Employee = &Employee") + "
	|
	|GROUP BY
	|	AccrualsAndDeductions.Employee.Code,
	|	CASE
	|		WHEN AccrualsAndDeductions.AccrualDeductionKind = VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePayment)
	|				OR AccrualsAndDeductions.AccrualDeductionKind = VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePaymentPercent)
	|			THEN &RegistrationPeriod
	|		ELSE AccrualsAndDeductions.StartDate
	|	END,
	|	CASE
	|		WHEN AccrualsAndDeductions.AccrualDeductionKind = VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePayment)
	|				OR AccrualsAndDeductions.AccrualDeductionKind = VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePaymentPercent)
	|			THEN ENDOFPERIOD(&RegistrationPeriod, MONTH)
	|		ELSE AccrualsAndDeductions.EndDate
	|	END,
	|	AccrualsAndDeductions.Employee,
	|	AccrualsAndDeductions.StructuralUnit,
	|	AccrualsAndDeductions.StructuralUnit.Description,
	|	EmployeesSliceLast.Position,
	|	ISNULL(DebtAtEnd.AmountCurBalance, 0),
	|	ISNULL(DebtToBegin.AmountCurBalance, 0),
	|	IndividualsDescriptionFullSliceLast.Surname,
	|	IndividualsDescriptionFullSliceLast.Name,
	|	IndividualsDescriptionFullSliceLast.Patronymic,
	|	CASE
	|		WHEN AccrualsAndDeductions.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|			THEN AccrualsAndDeductions.AccrualDeductionKind
	|		ELSE NULL
	|	END,
	|	CASE
	|		WHEN AccrualsAndDeductions.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|			THEN NULL
	|		ELSE AccrualsAndDeductions.AccrualDeductionKind
	|	END,
	|	CASE
	|		WHEN ISNULL(IndividualsDescriptionFullSliceLast.Surname, """") <> """"
	|			THEN IndividualsDescriptionFullSliceLast.Surname + "" "" + IndividualsDescriptionFullSliceLast.Name + "" "" + IndividualsDescriptionFullSliceLast.Patronymic
	|		ELSE AccrualsAndDeductions.Employee.Description
	|	END
	|
	|ORDER BY
	|	DepartmentPresentation,
	|	EmployeePresentation,
	|	StartDate
	|TOTALS
	|	MAX(DepartmentPresentation),
	|	MAX(Position),
	|	SUM(AmountAccrued),
	|	SUM(AmountWithheld),
	|	AVG(ClosingBalance),
	|	AVG(BalanceAtBegin),
	|	MAX(Surname),
	|	MAX(Name),
	|	MAX(Patronymic)
	|BY
	|	Department,
	|	Ind
	|
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN PayrollPaymentsTurnovers.Recorder REFS Document.CashPayment
	|			THEN ""Through petty cash ""
	|		ELSE ""From account ""
	|	END AS DocumentPresentation,
	|	CASE
	|		WHEN PayrollPaymentsTurnovers.Recorder.BasisDocument REFS Document.PayrollSheet
	|				AND PayrollPaymentsTurnovers.Recorder.BasisDocument.OperationKind = VALUE(Enum.OperationKindsPayrollSheet.Advance)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AdvanceFlag,
	|	PayrollPaymentsTurnovers.Recorder.Number As Number,
	|	PayrollPaymentsTurnovers.Recorder.Date AS Date,
	|	PayrollPaymentsTurnovers.Recorder,
	|	PayrollPaymentsTurnovers.Employee,
	|	PayrollPaymentsTurnovers.AmountCurExpense AS PaymentAmount
	|FROM
	|	AccumulationRegister.PayrollPayments.Turnovers(
	|			&RegistrationPeriod,
	|			&RegistrationEndOfPeriod,
	|			Record,
	|			Company = &Company
	|				AND Currency = &Currency" + ?(Not ValueIsFilled(Department), "", "
	|				AND StructuralUnit = &Department") + " " + ?(Not ValueIsFilled(Employee), "", "
	|				AND Employee = &Employee") + ") AS PayrollPaymentsTurnovers
	|WHERE 
	|	(PayrollPaymentsTurnovers.Recorder REFS Document.PaymentExpense 
	|			OR PayrollPaymentsTurnovers.Recorder REFS Document.PaymentExpense)
	|ORDER BY
	|	PayrollPaymentsTurnovers.Recorder.BasisDocument.Date, 
	|	PayrollPaymentsTurnovers.Recorder.Date";
	
	Query.SetParameter("Currency", Currency);
	Query.SetParameter("Company", Company);
	Query.SetParameter("RegistrationPeriod", RegistrationPeriod);
	Query.SetParameter("RegistrationEndOfPeriod", EndOfMonth(RegistrationPeriod)); 
	Query.SetParameter("Department", Department);
	Query.SetParameter("Employee", Employee);
	QueryResult = Query.ExecuteBatch();
	
	SetPrivilegedMode(False);
	
	Return QueryResult;

EndFunction // ExecuteQuery()

&AtServer
// Procedure forms the report.
//
Procedure MakeExecute()

	If Constants.UseSeveralCompanies.Get() AND Not ValueIsFilled(Company) Then
		MessageText = NStr("en='Company is not selected.';ru='Не выбрана организация!'");
		MessageField = "Company";
		SmallBusinessServer.ShowMessageAboutError(Report, MessageText,,,MessageField);
		Return;
	EndIf;

	If Not ValueIsFilled(RegistrationPeriod) Then
		MessageText = NStr("en='The registration period is required.';ru='Не выбран период регистрации!'");
		MessageField = "RegistrationPeriod";
		SmallBusinessServer.ShowMessageAboutError(Report, MessageText,,,MessageField);
		Return;
	EndIf;

	If Not Constants.FunctionalCurrencyTransactionsAccounting.Get() AND Not ValueIsFilled(Currency) Then
		MessageText = NStr("en='Currency is not selected.';ru='Не выбрана валюта!'");
		MessageField = "Currency";
		SmallBusinessServer.ShowMessageAboutError(Report, MessageText,,,MessageField);
		Return;
	EndIf;

	QueryResult = ExecuteQuery();

	If QueryResult[0].IsEmpty() Then
		Message = New UserMessage();
		Message.Text = NStr("en='No data to generate the report.';ru='Нет данных для формирования отчета!'");
		Message.Message();
		Return;
	EndIf;

	Template = Reports.PayrollSheets.GetTemplate("Template");

	AreaHeader 				= Template.GetArea("Header");
	HeaderArea 			= Template.GetArea("Title");
	AreaAccuredDeducted 	= Template.GetArea("AccruedWithheld");
	AreaDetails 				= Template.GetArea("Details");
	AreaIncomePayed 		= Template.GetArea("IncomePaid");
	AreaPaymentDetails 		= Template.GetArea("DetailsPayment");
	AreaTotal 				= Template.GetArea("Total");
	FooterArea 				= Template.GetArea("Footer");
	AreaSpace 				= Template.GetArea("Spacing");

	SpreadsheetDocument.Clear();

    AreaSpace.Parameters.TextPadding = Format(RegistrationPeriod , "DF=""MMMM yyyy 'g.' """);
	SpreadsheetDocument.Put(AreaSpace);

    AreaSpace.Parameters.TextPadding = "Company: " + Company;
	SpreadsheetDocument.Put(AreaSpace);

	SelectionSubdepartment = QueryResult[0].Select(QueryResultIteration.ByGroups, "Department");
	While SelectionSubdepartment.Next() Do

        AreaSpace.Parameters.TextPadding = "Department: " + SelectionSubdepartment.Department;
		SpreadsheetDocument.Put(AreaSpace);
        SpreadsheetDocument.StartRowGroup();
		
		IndividualSelection = SelectionSubdepartment.Select(QueryResultIteration.ByGroups, "Ind");
		While IndividualSelection.Next() Do

			AreaHeader.Parameters.Title = "Payroll sheet for " + Format(RegistrationPeriod , "DF=""MMMM yyyy 'g.' """);
			AreaHeader.Parameters.Company = Company;
			AreaHeader.Parameters.Fill(IndividualSelection);
			PresentationIndividual = SmallBusinessServer.GetSurnameNamePatronymic(IndividualSelection.Surname, IndividualSelection.Name, IndividualSelection.Patronymic, True);
			AreaHeader.Parameters.Ind = ?(ValueIsFilled(PresentationIndividual), PresentationIndividual, IndividualSelection.Ind);
			SpreadsheetDocument.Put(AreaHeader);
			SpreadsheetDocument.Put(HeaderArea);
			SpreadsheetDocument.Put(AreaAccuredDeducted);

			LastAccrual = SpreadsheetDocument.TableHeight;
			LastDeduction = SpreadsheetDocument.TableHeight;
			
			SelectionDetails = IndividualSelection.Select();
			While SelectionDetails.Next() Do
			
				If SelectionDetails.Deduction = NULL Then
					
					If LastAccrual < LastDeduction Then
						
						SpreadsheetDocument.Area(LastAccrual + 1, 1).Text = SelectionDetails.Accrual;
						SpreadsheetDocument.Area(LastAccrual + 1, 2, LastAccrual + 1, 3).Text = "" + Day(SelectionDetails.StartDate) + "-" + Day(SelectionDetails.EndDate) + " " + Format(SelectionDetails.EndDate , "DF=""MMM gg""");
						SpreadsheetDocument.Area(LastAccrual + 1, 4).Text = SelectionDetails.DaysWorked;
						SpreadsheetDocument.Area(LastAccrual + 1, 5).Text = SelectionDetails.HoursWorked;
						SpreadsheetDocument.Area(LastAccrual + 1, 6, LastAccrual + 1, 7).Text = SelectionDetails.AmountAccrued;
					
					Else
					
						AreaDetails.Parameters.Accrual = SelectionDetails.Accrual;
						AreaDetails.Parameters.PeriodAccrual = "" + Day(SelectionDetails.StartDate) + "-" + Day(SelectionDetails.EndDate) + " " + Format(SelectionDetails.EndDate , "DF=""MMM gg""");
						AreaDetails.Parameters.DaysWorkedAccrual = SelectionDetails.DaysWorked;
						AreaDetails.Parameters.HoursWorkedAccrual = SelectionDetails.HoursWorked;
						AreaDetails.Parameters.AmountAccrual = SelectionDetails.AmountAccrued;
						
						SpreadsheetDocument.Put(AreaDetails);
						
						AreaDetails.Parameters.Accrual = Catalogs.AccrualAndDeductionKinds.EmptyRef();
						AreaDetails.Parameters.PeriodAccrual = "";
						AreaDetails.Parameters.DaysWorkedAccrual = 0;
						AreaDetails.Parameters.HoursWorkedAccrual = 0;
						AreaDetails.Parameters.AmountAccrual = 0;
					
					EndIf; 
					
					LastAccrual = LastAccrual + 1;
				
				Else
					
					If LastDeduction < LastAccrual Then
					
						SpreadsheetDocument.Area(LastDeduction + 1, 8, LastDeduction + 1, 10).Text = SelectionDetails.Deduction;	
						SpreadsheetDocument.Area(LastDeduction + 1, 11, LastDeduction + 1, 12).Text = "" + Day(SelectionDetails.StartDate) + "-" + Day(SelectionDetails.EndDate) + " " + Format(SelectionDetails.EndDate , "DF=""MMM gg""");
						SpreadsheetDocument.Area(LastDeduction + 1, 13, LastDeduction + 1, 14).Text = SelectionDetails.AmountWithheld;
					
					Else
					
						AreaDetails.Parameters.Deduction = SelectionDetails.Deduction;
						AreaDetails.Parameters.DeductionPeriod = "" + Day(SelectionDetails.StartDate) + "-" + Day(SelectionDetails.EndDate) + " " + Format(SelectionDetails.EndDate , "DF=""MMM gg""");
						AreaDetails.Parameters.AmountDeduction = SelectionDetails.AmountWithheld;
						
						SpreadsheetDocument.Put(AreaDetails);
						
						AreaDetails.Parameters.Deduction = Catalogs.AccrualAndDeductionKinds.EmptyRef();
						AreaDetails.Parameters.DeductionPeriod = "";
						AreaDetails.Parameters.AmountDeduction = 0;
					
					EndIf; 
					
					LastDeduction = LastDeduction + 1;
				
				EndIf; 
		
			EndDo;

			AreaTotal.Parameters.TotalAccrual = IndividualSelection.AmountAccrued;
			AreaTotal.Parameters.TotalDeductions = IndividualSelection.AmountWithheld;
			SpreadsheetDocument.Put(AreaTotal);
			
			SpreadsheetDocument.Put(AreaIncomePayed);
			EmployeePaymentsSelection		= QueryResult[1].Select();
			
			StructureSearchBySelection	= New Structure("Employee", IndividualSelection.Ind);
			While EmployeePaymentsSelection.FIndNext(StructureSearchBySelection) Do
				
				AreaPaymentDetails.Parameters.Fill(EmployeePaymentsSelection);
				AreaPaymentDetails.Parameters.PaymentText = "" + EmployeePaymentsSelection.DocumentPresentation + ?(EmployeePaymentsSelection.AdvanceFlag, "(advance) #", " #") + 
																TrimAll(EmployeePaymentsSelection.Number) + " dated " + Format(EmployeePaymentsSelection.Date, "DF=dd.MM.yyyy");
				AreaPaymentDetails.Parameters.PaymentsPeriod		= "" + Day(RegistrationPeriod) + "-" + Day(EndOfMonth(RegistrationPeriod)) + " " + Format(EndOfMonth(RegistrationPeriod) , "DF=""MMM gg""");
				
				SpreadsheetDocument.Put(AreaPaymentDetails);
				
			EndDo;
			
			FooterArea.Parameters.AmountDebtOnBeginOfPeriod = IndividualSelection.BalanceAtBegin;
			FooterArea.Parameters.AmountDebtAtEndOfPeriod = IndividualSelection.ClosingBalance;
			If IndividualSelection.BalanceAtBegin < 0 Then
				FooterArea.Parameters.TextByBeginOfDebtPeriod = "Employee's debt on month start:";
			Else	
				FooterArea.Parameters.TextByBeginOfDebtPeriod = "Company's debt on month start:";
			EndIf; 
			If IndividualSelection.ClosingBalance < 0 Then
				FooterArea.Parameters.TextAtEndOfPeriodOfDebt = "Employee's debt on month end:";
			Else	
				FooterArea.Parameters.TextAtEndOfPeriodOfDebt = "Company's debt on month end:";
			EndIf; 
			SpreadsheetDocument.Put(FooterArea);
			
		EndDo;

        SpreadsheetDocument.EndRowGroup();
	EndDo;	

EndProcedure // Generate()

&AtClient
// Procedure - command handler Generate.
//
Procedure Generate(Command)
	
	MakeExecute();
	
EndProcedure

 
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer form event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RegistrationPeriod 				= BegOfMonth(CurrentDate());
	RegistrationPeriodPresentation 	= Format(RegistrationPeriod, "DF='MMMM yyyy'");
	
	If Constants.AccountingBySubsidiaryCompany.Get() Then
		
		Company = Constants.SubsidiaryCompany.Get();
		Items.Company.Visible = False;
		
	Else
		
		Company 				= SmallBusinessServer.GetCompany(Catalogs.Companies.MainCompany);
		
	EndIf;
	
	Currency 							= Constants.AccountingCurrency.Get();

	If Not Constants.FunctionalOptionAccountingByMultipleDepartments.Get() Then
		
		Department = Catalogs.StructuralUnits.MainDepartment;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - form event handler ChoiceProcessing
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ManagedForm")
		AND Find(ChoiceSource.FormName, "CalendarForm") > 0 Then
		
		RegistrationPeriod = EndOfDay(ValueSelected);
		SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
		
	EndIf;
	
EndProcedure // ChoiceProcessing()


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - HANDLERS OF THE FORM ATTRIBUTES

&AtClient
// Procedure - event handler Management of attribute RegistrationPeriod.
//
Procedure RegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	SmallBusinessClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
	
EndProcedure //RegistrationPeriodTuning()

&AtClient
// Procedure - event handler StartChoice of attribute RegistrationPeriod.
//
Procedure RegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(RegistrationPeriod), RegistrationPeriod, SmallBusinessReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.CalendarForm", SmallBusinessClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure //RegistrationPeriodStartChoice()

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, Settings);
	
EndProcedure
