#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = Employees.Total("PaymentAmount");
	
EndProcedure // BeforeWrite()

#EndRegion

#Region ProgramInterface

// Procedure fills tabular section Employees balance by charges.
//
Procedure FillByBalanceAtServer() Export
	
	If OperationKind = Enums.OperationKindsPayrollSheet.Salary Then
	
		Query = New Query;
		Query.Text = "SELECT
		               |	PayrollPaymentsBalance.Employee,
		               |	SUM(CASE
		               |			WHEN &SettlementsCurrency = &DocumentCurrency
		               |				THEN PayrollPaymentsBalance.AmountCurBalance
		               |			ELSE CAST(PayrollPaymentsBalance.AmountCurBalance * &ExchangeRate / &Multiplicity AS NUMBER(15, 2))
		               |		END) AS PaymentAmount,
		               |	SUM(PayrollPaymentsBalance.AmountCurBalance) AS SettlementsAmount
		               |FROM
		               |	AccumulationRegister.PayrollPayments.Balance(,
		               |			Company = &Company
		               |				AND RegistrationPeriod = &RegistrationPeriod
		               |				AND Currency = &SettlementsCurrency
		               |				AND StructuralUnit = &StructuralUnit) AS PayrollPaymentsBalance
		               |WHERE
		               |	PayrollPaymentsBalance.AmountCurBalance > 0
		               |
		               |GROUP BY
		               |	PayrollPaymentsBalance.Employee
		               |
		               |ORDER BY
		               |	PayrollPaymentsBalance.Employee.Description";
		
		Query.SetParameter("RegistrationPeriod", 	RegistrationPeriod);
		Query.SetParameter("Company", 		SmallBusinessServer.GetCompany(Company));
		Query.SetParameter("StructuralUnit", StructuralUnit);
		Query.SetParameter("SettlementsCurrency",		SettlementsCurrency);
		Query.SetParameter("DocumentCurrency",	DocumentCurrency);
		Query.SetParameter("ExchangeRate",				ExchangeRate);
		Query.SetParameter("Multiplicity",			Multiplicity);
		
		Employees.Load(Query.Execute().Unload());

	ElsIf OperationKind = Enums.OperationKindsPayrollSheet.Advance Then	
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'In case of advance payment filling in by balances is not provided!'");
 		Message.Message();
		
	EndIf;
	
EndProcedure

// Procedure fills tabular section Employees by department.
//
Procedure FillByDivisionAtServer() Export
		
	Query = New Query;
	Query.Text = "SELECT DISTINCT
	               |	EmployeesDeparnments.Employee AS Employee,
	               |	EmployeesDeparnments.StructuralUnit AS StructuralUnit
	               |FROM
	               |	(SELECT
	               |		EmployeesSliceLast.Employee AS Employee,
	               |		EmployeesSliceLast.StructuralUnit AS StructuralUnit
	               |	FROM
	               |		InformationRegister.Employees.SliceLast(
	               |				&RegistrationPeriod,
	               |				Company = &Company
	               |					AND (StructuralUnit = &StructuralUnit
	               |						OR StructuralUnit = VALUE(Catalog.StructuralUnits.EmptyRef))) AS EmployeesSliceLast
	               |	
	               |	UNION ALL
	               |	
	               |	SELECT
	               |		Employees.Employee,
	               |		Employees.StructuralUnit
	               |	FROM
	               |		InformationRegister.Employees AS Employees
	               |	WHERE
	               |		Employees.Company = &Company
	               |		AND Employees.StructuralUnit = &StructuralUnit
	               |		AND Employees.Period between &RegistrationPeriod AND ENDOFPERIOD(&RegistrationPeriod, MONTH)) AS EmployeesDeparnments
	               |WHERE
	               |	EmployeesDeparnments.StructuralUnit <> VALUE(Catalog.StructuralUnits.EmptyRef)
	               |
	               |GROUP BY
	               |	EmployeesDeparnments.Employee,
	               |	EmployeesDeparnments.StructuralUnit
	               |
	               |ORDER BY
	               |	Employee";
	
	Query.SetParameter("RegistrationPeriod", 		RegistrationPeriod);
	Query.SetParameter("StructuralUnit",		StructuralUnit);
	Query.SetParameter("Company", 			SmallBusinessServer.GetCompany(Company));
	
	Employees.Load(Query.Execute().Unload());
	
EndProcedure

#EndRegion

#EndIf