
#Region ServiceProceduresAndFunctions

&AtServer
// Procedure fills the data structure for the GL account selection.
//
Procedure ReceiveDataForSelectAccountsSettlements(DataStructure)
	
	GLAccountsAvailableTypes = New Array;
	AccrualDeductionKind = DataStructure.AccrualDeductionKind;
	If Not ValueIsFilled(AccrualDeductionKind) Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.UnfinishedProduction);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.IndirectExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.Expenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherFixedAssets);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherIncome);
		
	ElsIf AccrualDeductionKind.Type = Enums.AccrualAndDeductionTypes.Accrual Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.UnfinishedProduction);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.IndirectExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.Expenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherFixedAssets);
		
	ElsIf AccrualDeductionKind.Type = Enums.AccrualAndDeductionTypes.Deduction Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherIncome);
		
	EndIf;
	
	DataStructure.Insert("GLAccountsAvailableTypes", GLAccountsAvailableTypes);
	
EndProcedure // ReceiveDataForSelectAccountsSettlements()

// The procedure fills in the indicator table by parameters.
//
&AtServer
Function FillIndicators(AccrualDeductionKind)

	ReturnStructure = New Structure;
	ReturnStructure.Insert("Indicator1", "");
	ReturnStructure.Insert("Presentation1", Catalogs.CalculationsParameters.EmptyRef());
	ReturnStructure.Insert("Value1", 0);
	ReturnStructure.Insert("Indicator2", "");
	ReturnStructure.Insert("Presentation2", Catalogs.CalculationsParameters.EmptyRef());
	ReturnStructure.Insert("Value2", 0);
	ReturnStructure.Insert("Indicator3", "");
	ReturnStructure.Insert("Presentation3", Catalogs.CalculationsParameters.EmptyRef());
	ReturnStructure.Insert("Value3", 0);
	
	// 1. Checking
	If Not ValueIsFilled(AccrualDeductionKind) Then
		Return ReturnStructure;
	EndIf; 
	
	// 2. Search of all parameters-identifiers for the formula
	ParametersStructure = New Structure;
	SmallBusinessServer.AddParametersToStructure(AccrualDeductionKind.Formula, ParametersStructure);
		
	// 3. Adding the indicator
	Counter = 0;
	For Each ParameterStructures IN ParametersStructure Do
		
		If ParameterStructures.Key = "DaysWorked" 
			OR ParameterStructures.Key = "HoursWorked"
			OR ParameterStructures.Key = "TariffRate" Then
			
			Continue;
			
		EndIf; 
		
		CalculationParameter = Catalogs.CalculationsParameters.FindByAttribute("ID", ParameterStructures.Key);
		If Not ValueIsFilled(CalculationParameter) Then
			
			Message = New UserMessage();
			Message.Text = NStr("en = 'Parameter is not found '") + CalculationParameter + NStr("en = ' for accrual (deduction) formula '") + AccrualDeductionKind;
			Message.Message();
			Continue;
			
		EndIf; 
		
		Counter = Counter + 1;
		
		If Counter > 3 Then
			
			Break;
			
		EndIf; 
		
		ReturnStructure["Indicator" + Counter] = ParameterStructures.Key;
		ReturnStructure["Presentation" + Counter] = CalculationParameter;
		
	EndDo;
	
	Return ReturnStructure;
	
EndFunction // FillIndicators()

&AtServer
// The function creates the table of accruals.
//
Function GenerateAccrualsTable()

	TableAccruals = New ValueTable;

    Array = New Array;
	
	Array.Add(Type("CatalogRef.Employees"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableAccruals.Columns.Add("Employee", TypeDescription);

	Array.Add(Type("CatalogRef.Positions"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableAccruals.Columns.Add("Position", TypeDescription);
	
	Array.Add(Type("CatalogRef.AccrualAndDeductionKinds"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableAccruals.Columns.Add("AccrualDeductionKind", TypeDescription);

	Array.Add(Type("Date"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	TableAccruals.Columns.Add("StartDate", TypeDescription);
	  
	Array.Add(Type("Date"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	TableAccruals.Columns.Add("EndDate", TypeDescription);
		        
	Array.Add(Type("ChartOfAccountsRef.Managerial"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableAccruals.Columns.Add("GLExpenseAccount", TypeDescription);

	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableAccruals.Columns.Add("Size", TypeDescription);

	For Each TSRow IN Object.AccrualsDeductions Do

		NewRow = TableAccruals.Add();
        NewRow.Employee = TSRow.Employee;
        NewRow.Position = TSRow.Position;
		NewRow.AccrualDeductionKind = TSRow.AccrualDeductionKind;
        NewRow.StartDate = TSRow.StartDate;
        NewRow.EndDate = TSRow.EndDate;
        NewRow.GLExpenseAccount = TSRow.GLExpenseAccount;
        NewRow.Size = TSRow.Size;

	EndDo;
    	    
	Return TableAccruals;

EndFunction // GenerateAccrualsTable()

&AtServer
// The procedure fills in the Employees tabular section with filter by division.
//
Procedure FillByDivision()

	Object.AccrualsDeductions.Clear();
	Object.IncomeTaxes.Clear();
	
	Query = New Query;
	
	Query.Parameters.Insert("BegOfMonth", 		Object.RegistrationPeriod);
	Query.Parameters.Insert("EndOfMonth",	EndOfMonth(Object.RegistrationPeriod));
	Query.Parameters.Insert("Company", 		SmallBusinessServer.GetCompany(Object.Company));
	Query.Parameters.Insert("StructuralUnit", Object.StructuralUnit);
	Query.Parameters.Insert("Currency", 			Object.DocumentCurrency);
		
	// 1. Define the	employees we need
	// 2. Define all records of the employees we need, and accruals in the corresponding department.
	Query.Text = 
	"SELECT DISTINCT
	|	NestedSelect.Employee AS Employee
	|INTO EmployeesDeparnments
	|FROM
	|	(SELECT
	|		EmployeesSliceLast.Employee AS Employee
	|	FROM
	|		InformationRegister.Employees.SliceLast(&BegOfMonth, Company = &Company) AS EmployeesSliceLast
	|	WHERE
	|		EmployeesSliceLast.StructuralUnit = &StructuralUnit
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Employees.Employee
	|	FROM
	|		InformationRegister.Employees AS Employees
	|	WHERE
	|		Employees.StructuralUnit = &StructuralUnit
	|		AND Employees.Period between &BegOfMonth AND &EndOfMonth
	|		AND Employees.Company = &Company) AS NestedSelect
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.Employee AS Employee,
	|	NestedSelect.StructuralUnit AS StructuralUnit,
	|	NestedSelect.Position AS Position,
	|	AccrualsAndDeductionsPlan.AccrualDeductionKind AS AccrualDeductionKind,
	|	AccrualsAndDeductionsPlan.Amount AS Amount,
	|	AccrualsAndDeductionsPlan.GLExpenseAccount AS GLExpenseAccount,
	|	AccrualsAndDeductionsPlan.Actuality AS Actuality,
	|	NestedSelect.Period AS Period,
	|	NestedSelect.OthersUnitDismissal AS OthersUnitDismissal
	|INTO EmployeeRecords
	|FROM
	|	(SELECT
	|		EmployeesDeparnments.Employee AS Employee,
	|		Employees.StructuralUnit AS StructuralUnit,
	|		Employees.Position AS Position,
	|		MAX(AccrualsAndDeductionsPlan.Period) AS AccrualPeriod,
	|		Employees.Period AS Period,
	|		CASE
	|			WHEN Employees.StructuralUnit = &StructuralUnit
	|				THEN FALSE
	|			ELSE TRUE
	|		END AS OthersUnitDismissal,
	|		AccrualsAndDeductionsPlan.AccrualDeductionKind AS AccrualDeductionKind,
	|		AccrualsAndDeductionsPlan.Currency AS Currency
	|	FROM
	|		EmployeesDeparnments AS EmployeesDeparnments
	|			INNER JOIN InformationRegister.Employees AS Employees
	|				LEFT JOIN InformationRegister.AccrualsAndDeductionsPlan AS AccrualsAndDeductionsPlan
	|				ON Employees.Company = AccrualsAndDeductionsPlan.Company
	|					AND Employees.Employee = AccrualsAndDeductionsPlan.Employee
	|					AND Employees.Period >= AccrualsAndDeductionsPlan.Period
	|					AND (Employees.StructuralUnit = &StructuralUnit)
	|					AND (AccrualsAndDeductionsPlan.Currency = &Currency)
	|					AND (AccrualsAndDeductionsPlan.AccrualDeductionKind <> VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePayment))
	|					AND (AccrualsAndDeductionsPlan.AccrualDeductionKind <> VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePaymentPercent))
	|					AND (AccrualsAndDeductionsPlan.AccrualDeductionKind <> VALUE(Catalog.AccrualAndDeductionKinds.FixedAmount))
	|			ON EmployeesDeparnments.Employee = Employees.Employee
	|	WHERE
	|		Employees.Company = &Company
	|		AND Employees.Period between DATEADD(&BegOfMonth, Day, 1) AND &EndOfMonth
	|	
	|	GROUP BY
	|		Employees.StructuralUnit,
	|		EmployeesDeparnments.Employee,
	|		Employees.Position,
	|		Employees.Period,
	|		AccrualsAndDeductionsPlan.AccrualDeductionKind,
	|		AccrualsAndDeductionsPlan.Currency,
	|		CASE
	|			WHEN Employees.StructuralUnit = &StructuralUnit
	|				THEN FALSE
	|			ELSE TRUE
	|		END) AS NestedSelect
	|		LEFT JOIN InformationRegister.AccrualsAndDeductionsPlan AS AccrualsAndDeductionsPlan
	|		ON NestedSelect.Employee = AccrualsAndDeductionsPlan.Employee
	|			AND (AccrualsAndDeductionsPlan.Currency = &Currency)
	|			AND (AccrualsAndDeductionsPlan.Company = &Company)
	|			AND NestedSelect.AccrualPeriod = AccrualsAndDeductionsPlan.Period
	|			AND NestedSelect.AccrualDeductionKind = AccrualsAndDeductionsPlan.AccrualDeductionKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.Employee,
	|	NestedSelect.Period,
	|	NestedSelect.AccrualDeductionKind,
	|	NestedSelect.Amount,
	|	NestedSelect.GLExpenseAccount,
	|	NestedSelect.Actuality,
	|	Employees.StructuralUnit,
	|	Employees.Position
	|INTO RegisterRecordsPlannedAccrual
	|FROM
	|	(SELECT
	|		AccrualsAndDeductionsPlan.Employee AS Employee,
	|		AccrualsAndDeductionsPlan.Period AS Period,
	|		AccrualsAndDeductionsPlan.AccrualDeductionKind AS AccrualDeductionKind,
	|		AccrualsAndDeductionsPlan.Amount AS Amount,
	|		CASE
	|			WHEN AccrualsAndDeductionsPlan.GLExpenseAccount = VALUE(ChartOfAccounts.Managerial.EmptyRef)
	|				THEN AccrualsAndDeductionsPlan.AccrualDeductionKind.GLExpenseAccount
	|			ELSE AccrualsAndDeductionsPlan.GLExpenseAccount
	|		END AS GLExpenseAccount,
	|		AccrualsAndDeductionsPlan.Actuality AS Actuality,
	|		MAX(Employees.Period) AS PeriodStaff
	|	FROM
	|		EmployeesDeparnments AS EmployeesDeparnments
	|			INNER JOIN InformationRegister.AccrualsAndDeductionsPlan AS AccrualsAndDeductionsPlan
	|				LEFT JOIN InformationRegister.Employees AS Employees
	|				ON AccrualsAndDeductionsPlan.Employee = Employees.Employee
	|					AND AccrualsAndDeductionsPlan.Period >= Employees.Period
	|					AND (Employees.Company = &Company)
	|			ON EmployeesDeparnments.Employee = AccrualsAndDeductionsPlan.Employee
	|				AND (AccrualsAndDeductionsPlan.Currency = &Currency)
	|				AND (AccrualsAndDeductionsPlan.Period between DATEADD(&BegOfMonth, Day, 1) AND &EndOfMonth)
	|				AND (AccrualsAndDeductionsPlan.AccrualDeductionKind <> VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePayment))
	|				AND (AccrualsAndDeductionsPlan.AccrualDeductionKind <> VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePaymentPercent))
	|				AND (AccrualsAndDeductionsPlan.AccrualDeductionKind <> VALUE(Catalog.AccrualAndDeductionKinds.FixedAmount))
	|				AND (AccrualsAndDeductionsPlan.Company = &Company)
	|	
	|	GROUP BY
	|		AccrualsAndDeductionsPlan.Actuality,
	|		CASE
	|			WHEN AccrualsAndDeductionsPlan.GLExpenseAccount = VALUE(ChartOfAccounts.Managerial.EmptyRef)
	|				THEN AccrualsAndDeductionsPlan.AccrualDeductionKind.GLExpenseAccount
	|			ELSE AccrualsAndDeductionsPlan.GLExpenseAccount
	|		END,
	|		AccrualsAndDeductionsPlan.Period,
	|		AccrualsAndDeductionsPlan.AccrualDeductionKind,
	|		AccrualsAndDeductionsPlan.Employee,
	|		AccrualsAndDeductionsPlan.Amount) AS NestedSelect
	|		LEFT JOIN InformationRegister.Employees AS Employees
	|		ON NestedSelect.PeriodStaff = Employees.Period
	|			AND (Employees.Company = &Company)
	|			AND NestedSelect.Employee = Employees.Employee
	|WHERE
	|	Employees.StructuralUnit = &StructuralUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.Employee AS Employee,
	|	NestedSelect.StructuralUnit AS StructuralUnit,
	|	NestedSelect.Position AS Position,
	|	NestedSelect.DateActionsBegin AS DateActionsBegin,
	|	NestedSelect.AccrualDeductionKind AS AccrualDeductionKind,
	|	NestedSelect.Size AS Size,
	|	NestedSelect.GLExpenseAccount AS GLExpenseAccount,
	|	NestedSelect.Actuality,
	|	CASE
	|		WHEN NestedSelect.StructuralUnit = &StructuralUnit
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS OtherUnitDismissal,
	|	CASE
	|		WHEN NestedSelect.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Tax)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS IsTax
	|FROM
	|	(SELECT
	|		EmployeesDeparnments.Employee AS Employee,
	|		EmployeesSliceLast.StructuralUnit AS StructuralUnit,
	|		EmployeesSliceLast.Position AS Position,
	|		&BegOfMonth AS DateActionsBegin,
	|		AccrualsAndDeductionsPlanSliceLast.AccrualDeductionKind AS AccrualDeductionKind,
	|		AccrualsAndDeductionsPlanSliceLast.Amount AS Size,
	|		CASE
	|			WHEN AccrualsAndDeductionsPlanSliceLast.GLExpenseAccount = VALUE(ChartOfAccounts.Managerial.EmptyRef)
	|				THEN AccrualsAndDeductionsPlanSliceLast.AccrualDeductionKind.GLExpenseAccount
	|			ELSE AccrualsAndDeductionsPlanSliceLast.GLExpenseAccount
	|		END AS GLExpenseAccount,
	|		TRUE AS Actuality
	|	FROM
	|		EmployeesDeparnments AS EmployeesDeparnments
	|			INNER JOIN InformationRegister.Employees.SliceLast(&BegOfMonth, Company = &Company) AS EmployeesSliceLast
	|			ON EmployeesDeparnments.Employee = EmployeesSliceLast.Employee
	|			INNER JOIN InformationRegister.AccrualsAndDeductionsPlan.SliceLast(
	|					&BegOfMonth,
	|					Company = &Company
	|						AND Currency = &Currency) AS AccrualsAndDeductionsPlanSliceLast
	|			ON EmployeesDeparnments.Employee = AccrualsAndDeductionsPlanSliceLast.Employee
	|	WHERE
	|		AccrualsAndDeductionsPlanSliceLast.Actuality
	|		AND AccrualsAndDeductionsPlanSliceLast.AccrualDeductionKind <> VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePayment)
	|		AND AccrualsAndDeductionsPlanSliceLast.AccrualDeductionKind <> VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePaymentPercent)
	|		AND AccrualsAndDeductionsPlanSliceLast.AccrualDeductionKind <> VALUE(Catalog.AccrualAndDeductionKinds.FixedAmount)
	|		AND EmployeesSliceLast.StructuralUnit = &StructuralUnit
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN AccrualsAndDeductionsPlan.Employee
	|			ELSE Employees.Employee
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN AccrualsAndDeductionsPlan.StructuralUnit
	|			ELSE Employees.StructuralUnit
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN AccrualsAndDeductionsPlan.Position
	|			ELSE Employees.Position
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN AccrualsAndDeductionsPlan.Period
	|			ELSE Employees.Period
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN AccrualsAndDeductionsPlan.AccrualDeductionKind
	|			ELSE Employees.AccrualDeductionKind
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN AccrualsAndDeductionsPlan.Amount
	|			ELSE Employees.Amount
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CASE
	|						WHEN AccrualsAndDeductionsPlan.GLExpenseAccount = VALUE(ChartOfAccounts.Managerial.EmptyRef)
	|							THEN AccrualsAndDeductionsPlan.AccrualDeductionKind.GLExpenseAccount
	|						ELSE AccrualsAndDeductionsPlan.GLExpenseAccount
	|					END
	|			ELSE CASE
	|					WHEN Employees.GLExpenseAccount = VALUE(ChartOfAccounts.Managerial.EmptyRef)
	|						THEN Employees.AccrualDeductionKind.GLExpenseAccount
	|					ELSE Employees.GLExpenseAccount
	|				END
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN AccrualsAndDeductionsPlan.Actuality
	|			ELSE Employees.Actuality
	|		END
	|	FROM
	|		EmployeeRecords AS Employees
	|			Full JOIN RegisterRecordsPlannedAccrual AS AccrualsAndDeductionsPlan
	|			ON Employees.Employee = AccrualsAndDeductionsPlan.Employee
	|				AND Employees.Period = AccrualsAndDeductionsPlan.Period
	|				AND Employees.AccrualDeductionKind = AccrualsAndDeductionsPlan.AccrualDeductionKind) AS NestedSelect
	|
	|ORDER BY
	|	Employee,
	|	DateActionsBegin
	|TOTALS BY
	|	Employee";
	
	ResultsArray = Query.ExecuteBatch();
	
	// 3. We define the period end dates and fill in the value table.
	
	EndOfMonth = BegOfDay(EndOfMonth(Object.RegistrationPeriod));
	SelectionEmployee = ResultsArray[3].Select(QueryResultIteration.ByGroups, "Employee");
	While SelectionEmployee.Next() Do
		
		Selection = SelectionEmployee.Select();
		
		While Selection.Next() Do
			
			If Selection.OtherUnitDismissal Then
				ReplaceDateArray = Object.AccrualsDeductions.FindRows(New Structure("EndDate, Employee", EndOfMonth, Selection.Employee));
				For Each ArrayElement IN ReplaceDateArray Do
					ArrayElement.EndDate = Selection.DateActionsBegin - 60*60*24;
				EndDo;
				Continue;
			EndIf; 
			
			ReplaceDateArray = Object.AccrualsDeductions.FindRows(New Structure("EndDate, Employee, AccrualDeductionKind", EndOfMonth, Selection.Employee, Selection.AccrualDeductionKind));
			For Each ArrayElement IN ReplaceDateArray Do
				ArrayElement.EndDate = Selection.DateActionsBegin - 60*60*24;
			EndDo;
			
			If ValueIsFilled(Selection.AccrualDeductionKind) AND Selection.Actuality Then
			
				If Selection.IsTax Then				
										
					NewRow							= Object.IncomeTaxes.Add();
					NewRow.Employee 				= Selection.Employee;
					NewRow.AccrualDeductionKind 	= Selection.AccrualDeductionKind;				
				
				Else
				
					NewRow							= Object.AccrualsDeductions.Add();
					NewRow.Employee 				= Selection.Employee;
					NewRow.Position 				= Selection.Position;				 
											
					NewRow.AccrualDeductionKind 	= Selection.AccrualDeductionKind;
					NewRow.StartDate 				= Selection.DateActionsBegin;
					NewRow.EndDate 			= EndOfMonth;
					NewRow.Size 					= Selection.Size;
					
					TypeOfAccount = Selection.GLExpenseAccount.TypeOfAccount;
					If Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Division
						AND  Not (TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
						OR TypeOfAccount = Enums.GLAccountsTypes.Expenses
						OR TypeOfAccount = Enums.GLAccountsTypes.OtherCurrentAssets
						OR TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
						OR TypeOfAccount = Enums.GLAccountsTypes.UnfinishedProduction
						OR TypeOfAccount = Enums.GLAccountsTypes.OtherCurrentAssets
						OR TypeOfAccount = Enums.GLAccountsTypes.Creditors) Then
					
						NewRow.GLExpenseAccount = ChartsOfAccounts.Managerial.EmptyRef();					
					Else
						NewRow.GLExpenseAccount          	= Selection.GLExpenseAccount;				
					EndIf;
					
				EndIf;	
				
			EndIf; 
					
		EndDo;
		
	EndDo;
	
	// 4. Fill in working hours
		
	Query.Parameters.Insert("TableAccrualsDeductions", GenerateAccrualsTable());
	
	Query.Text =
	"SELECT
	|	TableAccrualsDeductions.Employee,
	|	TableAccrualsDeductions.Position,
	|	TableAccrualsDeductions.AccrualDeductionKind,
	|	TableAccrualsDeductions.StartDate,
	|	TableAccrualsDeductions.EndDate,
	|	TableAccrualsDeductions.Size,
	|	TableAccrualsDeductions.GLExpenseAccount
	|INTO TableAccrualsDeductions
	|FROM
	|	&TableAccrualsDeductions AS TableAccrualsDeductions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentAssessment.Employee AS Employee,
	|	DocumentAssessment.Position AS Position,
	|	DocumentAssessment.AccrualDeductionKind AS AccrualDeductionKind,
	|	DocumentAssessment.StartDate AS StartDate,
	|	DocumentAssessment.EndDate AS EndDate,
	|	DocumentAssessment.Size AS Size,
	|	DocumentAssessment.GLExpenseAccount AS GLExpenseAccount,
	|	ScheduleData.DaysWorked AS DaysWorked,
	|	ScheduleData.HoursWorked,
	|	ScheduleData.TotalForPeriod
	|FROM
	|	TableAccrualsDeductions AS DocumentAssessment
	|		LEFT JOIN (SELECT
	|			DocumentAssessment.Employee AS Employee,
	|			SUM(Timesheet.Days) AS DaysWorked,
	|			SUM(Timesheet.Hours) AS HoursWorked,
	|			DocumentAssessment.StartDate AS StartDate,
	|			DocumentAssessment.EndDate AS EndDate,
	|			MAX(Timesheet.TotalForPeriod) AS TotalForPeriod
	|		FROM
	|			(SELECT DISTINCT
	|				DocumentAssessment.Employee AS Employee,
	|				DocumentAssessment.StartDate AS StartDate,
	|				DocumentAssessment.EndDate AS EndDate
	|			FROM
	|				TableAccrualsDeductions AS DocumentAssessment) AS DocumentAssessment
	|				LEFT JOIN AccumulationRegister.Timesheet AS Timesheet
	|				ON DocumentAssessment.Employee = Timesheet.Employee
	|					AND (Timesheet.TimeKind = VALUE(Catalog.WorkingHoursKinds.Work))
	|					AND (Timesheet.Company = &Company)
	|					AND (Timesheet.StructuralUnit = &StructuralUnit)
	|					AND ((NOT Timesheet.TotalForPeriod)
	|							AND DocumentAssessment.StartDate <= Timesheet.Period
	|							AND DocumentAssessment.EndDate >= Timesheet.Period
	|						OR Timesheet.TotalForPeriod
	|							AND Timesheet.Period = BEGINOFPERIOD(DocumentAssessment.StartDate, MONTH))
	|		
	|		GROUP BY
	|			DocumentAssessment.Employee,
	|			DocumentAssessment.StartDate,
	|			DocumentAssessment.EndDate) AS ScheduleData
	|		ON DocumentAssessment.Employee = ScheduleData.Employee
	|			AND DocumentAssessment.StartDate = ScheduleData.StartDate
	|			AND DocumentAssessment.EndDate = ScheduleData.EndDate";
	
	QueryResult = Query.ExecuteBatch()[1].Unload();
	Object.AccrualsDeductions.Load(QueryResult); 
		
	Object.AccrualsDeductions.Sort("Employee Asc, StartDate Asc, AccrualDeductionKind Asc");
	
	For Each TabularSectionRow IN Object.AccrualsDeductions Do
		
		// 1. Checking
		If Not ValueIsFilled(TabularSectionRow.AccrualDeductionKind) Then
			Continue;
		EndIf; 
		RepetitionsArray = QueryResult.FindRows(New Structure("Employee, AccrualDeductionKind", TabularSectionRow.Employee, TabularSectionRow.AccrualDeductionKind));
		If RepetitionsArray.Count() > 1 AND RepetitionsArray[0].TotalForPeriod Then
			
			TabularSectionRow.DaysWorked = 0;
			TabularSectionRow.HoursWorked = 0;
			
			MessageText = NStr("en = '%Employee%, %AccrualKind%: Working hours data has been entered consolidated. Time calculation for each accrual (deduction) kind is not possible!'");
			MessageText = StrReplace(MessageText, "%Employee%", TabularSectionRow.Employee);
			MessageText = StrReplace(MessageText, "%AccrualKind%", TabularSectionRow.AccrualDeductionKind);
			MessageField = "Object.AccrualsDeductions[" + Object.AccrualsDeductions.IndexOf(TabularSectionRow) + "].Employee";
			
			SmallBusinessServer.ShowMessageAboutError(Object, MessageText,,,MessageField);
			
		EndIf;
		
		// 2. Clearing
		For Counter = 1 To 3 Do		
			TabularSectionRow["Indicator" + Counter] = "";
			TabularSectionRow["Presentation" + Counter] = Catalogs.CalculationsParameters.EmptyRef();
			TabularSectionRow["Value" + Counter] = 0;	
		EndDo;
		
		// 3. Search of all parameters-identifiers for the formula
		ParametersStructure = New Structure;
		SmallBusinessServer.AddParametersToStructure(TabularSectionRow.AccrualDeductionKind.Formula, ParametersStructure);
		
		// 4. Adding the indicator
		Counter = 0;
		For Each ParameterStructures IN ParametersStructure Do
			
			If ParameterStructures.Key = "DaysWorked"
					OR ParameterStructures.Key = "HoursWorked"
					OR ParameterStructures.Key = "TariffRate" Then
			    Continue;
			EndIf; 
						
			CalculationParameter = Catalogs.CalculationsParameters.FindByAttribute("ID", ParameterStructures.Key);
		 	If Not ValueIsFilled(CalculationParameter) Then		
				Message = New UserMessage();
				Message.Text = NStr("en = 'Parameter is not found '") + CalculationParameter + NStr("en = ' for the employee in row No. '") + (Object.AccrualsDeductions.IndexOf(TabularSectionRow) + 1);
				Message.Message();
		    EndIf; 
			
			Counter = Counter + 1;
			
			If Counter > 3 Then
				Break;
			EndIf; 
			
			TabularSectionRow["Indicator" + Counter] = ParameterStructures.Key;
			TabularSectionRow["Presentation" + Counter] = CalculationParameter;
			
			If CalculationParameter.SpecifyValueAtPayrollCalculation Then
				Continue;
			EndIf; 
			
		// 5. Indicator calculation
			
			StructureOfSelections = New Structure;
			StructureOfSelections.Insert("RegistrationPeriod", 		Object.RegistrationPeriod);
			StructureOfSelections.Insert("Company", 			SmallBusinessServer.GetCompany(Object.Company));
			StructureOfSelections.Insert("Currency", 				Object.DocumentCurrency);
			StructureOfSelections.Insert("Division", 			Object.StructuralUnit);
			StructureOfSelections.Insert("StructuralUnit", 	Object.StructuralUnit);
			StructureOfSelections.Insert("PointInTime", 			EndOfDay(TabularSectionRow.EndDate));
			StructureOfSelections.Insert("BeginOfPeriod", 			TabularSectionRow.StartDate);
			StructureOfSelections.Insert("EndOfPeriod", 			EndOfDay(TabularSectionRow.EndDate));
			StructureOfSelections.Insert("Employee",		 		TabularSectionRow.Employee);
			StructureOfSelections.Insert("OccupationType",		 	TabularSectionRow.Employee.OccupationType);
			StructureOfSelections.Insert("EmployeeCode",		 	TabularSectionRow.Employee.Code);
			StructureOfSelections.Insert("TabNumber",		 		TabularSectionRow.Employee.Code);
			StructureOfSelections.Insert("Performer",		 	TabularSectionRow.Employee);
			StructureOfSelections.Insert("Ind",		 		TabularSectionRow.Employee.Ind);
			StructureOfSelections.Insert("Individual",		 	TabularSectionRow.Employee.Ind);
			StructureOfSelections.Insert("Position", 				TabularSectionRow.Position);
			StructureOfSelections.Insert("AccrualDeductionKind", TabularSectionRow.AccrualDeductionKind);
			StructureOfSelections.Insert("CustomerOrder", 		TabularSectionRow.CustomerOrder);
			StructureOfSelections.Insert("Order", 					TabularSectionRow.CustomerOrder);
			StructureOfSelections.Insert("Project", 				TabularSectionRow.CustomerOrder.Project);
			StructureOfSelections.Insert("GLExpenseAccount", 			TabularSectionRow.GLExpenseAccount);
			StructureOfSelections.Insert("BusinessActivity",TabularSectionRow.BusinessActivity);
			StructureOfSelections.Insert("Size",					TabularSectionRow.Size);
			StructureOfSelections.Insert("DaysWorked",			TabularSectionRow.DaysWorked);
			StructureOfSelections.Insert("HoursWorked",		TabularSectionRow.HoursWorked);
			
			// SalesAmountInNationalCurrency
			AccountingCurrency = Constants.AccountingCurrency.Get();
			If AccountingCurrency = Object.DocumentCurrency Then
				
				StructureOfSelections.Insert("AccountingCurrecyFrequency", 1);
				StructureOfSelections.Insert("AccountingCurrencyExchangeRate", 1);
				StructureOfSelections.Insert("DocumentCurrencyMultiplicity", 1);
				StructureOfSelections.Insert("DocumentCurrencyRate", 1);
				
			Else
				
				CurrencyRateStructure = WorkWithCurrencyRates.GetCurrencyRate(AccountingCurrency, Object.Date);
				StructureOfSelections.Insert("AccountingCurrecyFrequency", CurrencyRateStructure.Multiplicity);
				StructureOfSelections.Insert("AccountingCurrencyExchangeRate", CurrencyRateStructure.ExchangeRate);
				
				CurrencyRateStructure = WorkWithCurrencyRates.GetCurrencyRate(Object.DocumentCurrency, Object.Date);
				StructureOfSelections.Insert("DocumentCurrencyMultiplicity", CurrencyRateStructure.Multiplicity);
				StructureOfSelections.Insert("DocumentCurrencyRate", CurrencyRateStructure.ExchangeRate);
				
			EndIf;
			
			TabularSectionRow["Value" + Counter] = SmallBusinessServer.CalculateParameterValue(StructureOfSelections, CalculationParameter, NStr("en = ' for the employee in row No.'") + (Object.AccrualsDeductions.IndexOf(TabularSectionRow) + 1));
		
		EndDo;
		
	EndDo; 
	
	RefreshFormFooter();
	
EndProcedure // FillByDivision()

&AtServer
// The procedure calculates the value of the accrual or deduction using the formula.
//
Procedure CalculateByFormulas()

	For Each AccrualsRow IN Object.AccrualsDeductions Do
		
		If AccrualsRow.ManualCorrection OR Not ValueIsFilled(AccrualsRow.AccrualDeductionKind.Formula) Then
			Continue;
		EndIf; 
		
		// 1. Add parameters and values to the structure
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("TariffRate", AccrualsRow.Size);
		ParametersStructure.Insert("DaysWorked", AccrualsRow.DaysWorked);
		ParametersStructure.Insert("HoursWorked", AccrualsRow.HoursWorked);
		
		For Counter = 1 To 3 Do
			If ValueIsFilled(AccrualsRow["Presentation" + Counter]) Then
				ParametersStructure.Insert(AccrualsRow["Indicator" + Counter], AccrualsRow["Value" + Counter]);
			EndIf; 
		EndDo; 
		
		
		// 2. Calculate using formulas
			 
		Formula = AccrualsRow.AccrualDeductionKind.Formula;
		For Each Parameter IN ParametersStructure Do
			Formula = StrReplace(Formula, "[" + Parameter.Key + "]", Format(Parameter.Value, "NDS=.; NZ=0; NG=0"));
		EndDo;
		Try
			CalculatedSum = Eval(Formula);
		Except
			MessageText = NStr("en = 'Failed to calculate the accrual amount in the row No.%LineNumber%. The formula probably contains an error, or indicators are not filled.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", (Object.AccrualsDeductions.IndexOf(AccrualsRow) + 1));
			MessageField = "Object.AccrualsDeductions[" + Object.AccrualsDeductions.IndexOf(AccrualsRow) + "].AccrualDeductionKind";
			
			SmallBusinessServer.ShowMessageAboutError(Object, MessageText,,,MessageField);
			
			CalculatedSum = 0;
		EndTry;
		AccrualsRow.Amount = Round(CalculatedSum, 2); 

	EndDo;
	
	RefreshFormFooter();

EndProcedure // CalculateByFormulas()

// Gets the data set from the server for the ExpenseGLAccount attribute of the AccrualsAndDeductions tabular section
//
&AtServerNoContext
Function GetDataCostsAccount(GLExpenseAccount)
	
	DataStructure = New Structure("TypeOfAccount", Undefined);
	If ValueIsFilled(GLExpenseAccount) Then
		
		DataStructure.TypeOfAccount = GLExpenseAccount.TypeOfAccount;
		
	EndIf;
	
	Return DataStructure;
	
EndFunction // GetDataCostsAccount()

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

&AtServer
// Procedure updates data in form footer.
//
Procedure RefreshFormFooter()
	
	Document = FormAttributeToValue("Object");
	ResultsStructure = Document.GetDocumentAmount();
	DocumentAmount = ResultsStructure.DocumentAmount;
	AmountAccrued = ResultsStructure.AmountAccrued;
	AmountWithheld = ResultsStructure.AmountWithheld;
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // UpdateFormFooter()

#EndRegion

#Region FormEventsHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initialization of form parameters,
// - setting of the form functional options parameters.
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
		Object.RegistrationPeriod = BegOfMonth(CurrentDate());
	EndIf;
	
	RegistrationPeriodPresentation = Format(ThisForm.Object.RegistrationPeriod, "DF='MMMM yyyy'");
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	DocumentCurrency = Object.DocumentCurrency;
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	RefreshFormFooter();
	
	If Not Constants.FunctionalOptionUseJobSharing.Get() Then
		
		If Items.Find("AccrualsDeductionsEmployeeCode") <> Undefined Then
			
			Items.AccrualsDeductionsEmployeeCode.Visible = False;
			
		EndIf;
		
		If Items.Find("IncomeTaxesEmployeeCode") <> Undefined Then
			
			Items.IncomeTaxesEmployeeCode.Visible = False;
			
		EndIf;
		
	EndIf;
	
	If Object.AccrualsDeductions.Count() > 0 Then
		
		For Each DataRow IN Object.AccrualsDeductions Do
			
			If ValueIsFilled(DataRow.GLExpenseAccount) Then
				
				DataRow.TypeOfAccount = DataRow.GLExpenseAccount.TypeOfAccount;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

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
		
	EndIf;
	
EndProcedure // ChoiceProcessing()

#EndRegion

#Region FormCommandsHandlers

&AtClient
// Procedure - Calculate command handler.
//
Procedure Calculate(Command)
	
	CalculateByFormulas();
	
EndProcedure

&AtClient
// The procedure fills in the Employees tabular section with filter by division.
//
Procedure Fill(Command)
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'The division is not filled! Document filling is cancelled.'");
		Message.Field = "Object.StructuralUnit";
		Message.Message();
		
		Return;
		
	EndIf;

	If Object.AccrualsDeductions.Count() > 0 AND Object.IncomeTaxes.Count() > 0 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("FillEnd1", ThisObject), NStr("en = 'Document tabular sections will be cleared! Continue?'"), QuestionDialogMode.YesNo, 0);
        Return;
		
	ElsIf Object.AccrualsDeductions.Count() > 0 OR Object.IncomeTaxes.Count() > 0 Then
		
		ShowQueryBox(New NotifyDescription("FillEnd", ThisObject), NStr("en = 'Tabular section of the document will be cleared. Continue?'"), QuestionDialogMode.YesNo, 0);
        Return; 
		
	EndIf;
	
	FillFragment1();
EndProcedure

&AtClient
Procedure FillEnd1(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response <> DialogReturnCode.Yes Then
		
		Return;
		
	EndIf;
	
	
	FillFragment1();
	
EndProcedure

&AtClient
Procedure FillFragment1()
	
	FillFragment();
	
EndProcedure

&AtClient
Procedure FillEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response <> DialogReturnCode.Yes Then
		Return;
		
	EndIf; 
	
	
	FillFragment();
	
EndProcedure

&AtClient
Procedure FillFragment()
	
	FillByDivision();
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

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

&AtClient
// Procedure - handler of event OnChange of input field DocumentCurrency.
//
Procedure DocumentCurrencyOnChange(Item)
	
	If Object.DocumentCurrency = DocumentCurrency Then
		Return;
	EndIf; 
	
	If Object.AccrualsDeductions.Count() > 0 Then
		
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("DocumentCurrencyOnChangeEnd", ThisObject), NStr("en = 'Tabular section will be cleared. Continue?'"), Mode, 0);
		Return;
		
	EndIf; 
	
	DocumentCurrencyOnChangeFragment();
EndProcedure

//Procedure event handler of field management RegistrationPeriod
//
&AtClient
Procedure RegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	SmallBusinessClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
	
EndProcedure //RegistrationPeriodTuning()

//Procedure-handler of the data entry start event of the RegistrationPeriod field
//
&AtClient
Procedure RegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(Object.RegistrationPeriod), Object.RegistrationPeriod, SmallBusinessReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.CalendarForm", SmallBusinessClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure //RegistrationPeriodStartChoice()

&AtClient
Procedure DocumentCurrencyOnChangeEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Object.AccrualsDeductions.Clear();
		Object.IncomeTaxes.Clear();
	EndIf;
    
    
    DocumentCurrencyOnChangeFragment();

EndProcedure

&AtClient
Procedure DocumentCurrencyOnChangeFragment()
    
    DocumentCurrency = Object.DocumentCurrency;

EndProcedure // DocumentCurrencyOnChange()

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

&AtClient
Procedure AccrualsDeductionsExpensesAccountOnChange(Item)
	
	DataCurrentRows = Items.AccrualsDeductions.CurrentData;
	If DataCurrentRows <> Undefined Then
		
		DataStructure = GetDataCostsAccount(DataCurrentRows.GLExpenseAccount);
		DataCurrentRows.TypeOfAccount = DataStructure.TypeOfAccount;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AccrualsDeductionsExpensesAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataCurrentRows = Items.AccrualsDeductions.CurrentData;
	
	DataStructure = New Structure;
	DataStructure.Insert("AccrualDeductionKind", 
		?(DataCurrentRows = Undefined, Undefined, DataCurrentRows.AccrualDeductionKind));
		
	ReceiveDataForSelectAccountsSettlements(DataStructure);
	
	NewArray = New Array;
	NewParameter = New ChoiceParameter("Filter.TypeOfAccount", New FixedArray(DataStructure.GLAccountsAvailableTypes));
	NewArray.Add(NewParameter);
	ChoiceParameters = New FixedArray(NewArray);
	Items.AccrualsDeductionsExpensesAccount.ChoiceParameters = ChoiceParameters
	
EndProcedure

&AtClient
// Procedure - OnStartEdit event handler of the Accruals tabular section.
//
Procedure AccrualsDeductionsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		If Not Copy Then
			
			CurrentData 				= Items.AccrualsDeductions.CurrentData;
			
			CurrentData.StartDate 	= Object.RegistrationPeriod;
			CurrentData.EndDate = EndOfMonth(Object.RegistrationPeriod);
			CurrentData.ManualCorrection = True;
			
		EndIf; 
		
	EndIf;

EndProcedure

&AtClient
// Procedure - OnChange event handler of the Accruals tabular section.
//
Procedure AccrualsDeductionsOnChange(Item)
	
	RefreshFormFooter();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the Accruals tabular section.
//
Procedure IncomeTaxesOnChange(Item)
	
	RefreshFormFooter();
	
EndProcedure

&AtClient
// Procedure - OnChange event data of the AccrualDeductionKind attribute of the AccrualsDeductions tabular section.
//
Procedure AccrualsDeductionsAccrualDeductionKindOnChange(Item)
	
	CurrentRow = Items.AccrualsDeductions.CurrentData;
	
	DataStructure = FillIndicators(CurrentRow.AccrualDeductionKind);
	FillPropertyValues(CurrentRow, DataStructure);
	SmallBusinessClient.PutExpensesGLAccountByDefault(ThisForm, Object.StructuralUnit);
	
EndProcedure

#EndRegion

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
