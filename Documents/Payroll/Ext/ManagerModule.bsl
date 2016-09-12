#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefPayroll, StructureAdditionalProperties) Export
	
	Query = New Query(
	"SELECT
	|	&Company AS Company,
	|	PayrollAccrualRetention.LineNumber AS LineNumber,
	|	PayrollAccrualRetention.Ref.Date AS Period,
	|	PayrollAccrualRetention.Ref.RegistrationPeriod AS RegistrationPeriod,
	|	PayrollAccrualRetention.Ref.DocumentCurrency AS Currency,
	|	PayrollAccrualRetention.Ref.StructuralUnit AS StructuralUnit,
	|	PayrollAccrualRetention.Employee AS Employee,
	|	PayrollAccrualRetention.GLExpenseAccount AS GLExpenseAccount,
	|	PayrollAccrualRetention.CustomerOrder AS CustomerOrder,
	|	PayrollAccrualRetention.BusinessActivity AS BusinessActivity,
	|	PayrollAccrualRetention.StartDate AS StartDate,
	|	PayrollAccrualRetention.EndDate AS EndDate,
	|	PayrollAccrualRetention.DaysWorked AS DaysWorked,
	|	PayrollAccrualRetention.HoursWorked AS HoursWorked,
	|	PayrollAccrualRetention.Size AS Size,
	|	PayrollAccrualRetention.AccrualDeductionKind AS AccrualDeductionKind,
	|	CAST(PayrollAccrualRetention.Amount * SettlementsCurrencyRates.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	PayrollAccrualRetention.Amount AS AmountCur
	|INTO TableAccrual
	|FROM
	|	Document.Payroll.AccrualsDeductions AS PayrollAccrualRetention
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS SettlementsCurrencyRates
	|		ON PayrollAccrualRetention.Ref.DocumentCurrency = SettlementsCurrencyRates.Currency
	|WHERE
	|	PayrollAccrualRetention.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	PayrollAccrualRetention.LineNumber,
	|	PayrollAccrualRetention.Ref.Date,
	|	PayrollAccrualRetention.Ref.RegistrationPeriod,
	|	PayrollAccrualRetention.Ref.DocumentCurrency,
	|	PayrollAccrualRetention.Ref.StructuralUnit,
	|	PayrollAccrualRetention.Employee,
	|	PayrollAccrualRetention.AccrualDeductionKind.TaxKind.GLAccount,
	|	VALUE(Document.CustomerOrder.EmptyRef),
	|	VALUE(Catalog.BusinessActivities.EmptyRef),
	|	PayrollAccrualRetention.Ref.RegistrationPeriod,
	|	ENDOFPERIOD(PayrollAccrualRetention.Ref.RegistrationPeriod, MONTH),
	|	0,
	|	0,
	|	0,
	|	PayrollAccrualRetention.AccrualDeductionKind,
	|	CAST(PayrollAccrualRetention.Amount * SettlementsCurrencyRates.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2)),
	|	PayrollAccrualRetention.Amount
	|FROM
	|	Document.Payroll.IncomeTaxes AS PayrollAccrualRetention
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS SettlementsCurrencyRates
	|		ON PayrollAccrualRetention.Ref.DocumentCurrency = SettlementsCurrencyRates.Currency
	|WHERE
	|	PayrollAccrualRetention.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	PayrollAccrualRetention.Period AS Period,
	|	PayrollAccrualRetention.RegistrationPeriod AS RegistrationPeriod,
	|	PayrollAccrualRetention.Currency AS Currency,
	|	PayrollAccrualRetention.StructuralUnit AS StructuralUnit,
	|	PayrollAccrualRetention.Employee AS Employee,
	|	PayrollAccrualRetention.StartDate AS StartDate,
	|	PayrollAccrualRetention.EndDate AS EndDate,
	|	PayrollAccrualRetention.DaysWorked AS DaysWorked,
	|	PayrollAccrualRetention.HoursWorked AS HoursWorked,
	|	PayrollAccrualRetention.Size AS Size,
	|	PayrollAccrualRetention.AccrualDeductionKind AS AccrualDeductionKind,
	|	PayrollAccrualRetention.Amount AS Amount,
	|	PayrollAccrualRetention.AmountCur AS AmountCur
	|FROM
	|	TableAccrual AS PayrollAccrualRetention
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	PayrollAccrualRetention.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	PayrollAccrualRetention.RegistrationPeriod AS RegistrationPeriod,
	|	PayrollAccrualRetention.Currency AS Currency,
	|	PayrollAccrualRetention.StructuralUnit AS StructuralUnit,
	|	PayrollAccrualRetention.Employee AS Employee,
	|	CASE
	|		WHEN PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|			THEN PayrollAccrualRetention.AmountCur
	|		ELSE -1 * PayrollAccrualRetention.AmountCur
	|	END AS AmountCur,
	|	CASE
	|		WHEN PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|			THEN PayrollAccrualRetention.Amount
	|		ELSE -1 * PayrollAccrualRetention.Amount
	|	END AS Amount,
	|	PayrollAccrualRetention.Employee.SettlementsHumanResourcesGLAccount AS GLAccount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindManagerial,
	|	CASE
	|		WHEN PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Tax)
	|			THEN &AddedTax
	|		ELSE &Payroll
	|	END AS ContentOfAccountingRecord
	|FROM
	|	TableAccrual AS PayrollAccrualRetention
	|WHERE
	|	PayrollAccrualRetention.AmountCur <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PayrollAccrualRetention.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	PayrollAccrualRetention.RegistrationPeriod AS Period,
	|	&Company AS Company,
	|	PayrollAccrualRetention.StructuralUnit AS StructuralUnit,
	|	PayrollAccrualRetention.GLExpenseAccount AS GLExpenseAccount,
	|	PayrollAccrualRetention.GLExpenseAccount AS GLAccount,
	|	PayrollAccrualRetention.CustomerOrder AS CustomerOrder,
	|	CASE
	|		WHEN PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Deduction)
	|			THEN -1 * PayrollAccrualRetention.Amount
	|		ELSE PayrollAccrualRetention.Amount
	|	END AS Amount,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindManagerial,
	|	TRUE AS FixedCost,
	|	&Payroll AS ContentOfAccountingRecord
	|FROM
	|	TableAccrual AS PayrollAccrualRetention
	|WHERE
	|	PayrollAccrualRetention.AccrualDeductionKind.Type <> VALUE(Enum.AccrualAndDeductionTypes.Tax)
	|	AND (PayrollAccrualRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|			OR PayrollAccrualRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|	AND PayrollAccrualRetention.AmountCur <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PayrollAccrualRetention.LineNumber AS LineNumber,
	|	PayrollAccrualRetention.RegistrationPeriod AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN PayrollAccrualRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN PayrollAccrualRetention.BusinessActivity
	|		ELSE VALUE(Catalog.BusinessActivities.Other)
	|	END AS BusinessActivity,
	|	CASE
	|		WHEN PayrollAccrualRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN PayrollAccrualRetention.StructuralUnit
	|		ELSE UNDEFINED
	|	END AS StructuralUnit,
	|	PayrollAccrualRetention.GLExpenseAccount AS GLAccount,
	|	PayrollAccrualRetention.GLExpenseAccount AS GLExpenseAccount,
	|	CASE
	|		WHEN PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|			THEN PayrollAccrualRetention.Amount
	|		ELSE 0
	|	END AS AmountExpense,
	|	CASE
	|		WHEN PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Deduction)
	|			THEN PayrollAccrualRetention.Amount
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Deduction)
	|			THEN -1 * PayrollAccrualRetention.Amount
	|		ELSE PayrollAccrualRetention.Amount
	|	END AS Amount,
	|	CASE
	|		WHEN PayrollAccrualRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN PayrollAccrualRetention.CustomerOrder
	|		ELSE UNDEFINED
	|	END AS CustomerOrder,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindManagerial,
	|	&Payroll AS ContentOfAccountingRecord
	|FROM
	|	TableAccrual AS PayrollAccrualRetention
	|WHERE
	|	PayrollAccrualRetention.AccrualDeductionKind.Type <> VALUE(Enum.AccrualAndDeductionTypes.Tax)
	|	AND PayrollAccrualRetention.GLExpenseAccount.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.Expenses), VALUE(Enum.GLAccountsTypes.OtherExpenses), VALUE(Enum.GLAccountsTypes.Incomings), VALUE(Enum.GLAccountsTypes.OtherIncome))
	|	AND PayrollAccrualRetention.AmountCur <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	PayrollAccrualRetention.RegistrationPeriod AS Period,
	|	PayrollAccrualRetention.AccrualDeductionKind.TaxKind AS TaxKind,
	|	PayrollAccrualRetention.AccrualDeductionKind.TaxKind.GLAccount AS GLAccount,
	|	PayrollAccrualRetention.Amount,
	|	&AddedTax AS ContentOfAccountingRecord
	|FROM
	|	TableAccrual AS PayrollAccrualRetention
	|WHERE
	|	PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Tax)
	|	AND PayrollAccrualRetention.AmountCur <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PayrollAccrualRetention.LineNumber AS LineNumber,
	|	PayrollAccrualRetention.RegistrationPeriod AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|			THEN PayrollAccrualRetention.GLExpenseAccount
	|		ELSE PayrollAccrualRetention.Employee.SettlementsHumanResourcesGLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN (PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Deduction)
	|					OR PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Tax))
	|					AND PayrollAccrualRetention.Employee.SettlementsHumanResourcesGLAccount.Currency
	|				OR PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|					AND PayrollAccrualRetention.GLExpenseAccount.Currency
	|			THEN PayrollAccrualRetention.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN (PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Deduction)
	|					OR PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Tax))
	|					AND PayrollAccrualRetention.Employee.SettlementsHumanResourcesGLAccount.Currency
	|				OR PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|					AND PayrollAccrualRetention.GLExpenseAccount.Currency
	|			THEN PayrollAccrualRetention.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|			THEN PayrollAccrualRetention.Employee.SettlementsHumanResourcesGLAccount
	|		ELSE PayrollAccrualRetention.GLExpenseAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN (PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Deduction)
	|					OR PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Tax))
	|					AND PayrollAccrualRetention.GLExpenseAccount.Currency
	|				OR PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|					AND PayrollAccrualRetention.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN PayrollAccrualRetention.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN (PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Deduction)
	|					OR PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Tax))
	|					AND PayrollAccrualRetention.GLExpenseAccount.Currency
	|				OR PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	|					AND PayrollAccrualRetention.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN PayrollAccrualRetention.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	PayrollAccrualRetention.Amount AS Amount,
	|	CASE
	|		WHEN PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Tax)
	|			THEN &AddedTax
	|		ELSE &Payroll
	|	END AS Content
	|FROM
	|	TableAccrual AS PayrollAccrualRetention
	|WHERE
	|	PayrollAccrualRetention.AmountCur <> 0");
	
	Query.SetParameter("Ref", DocumentRefPayroll);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Payroll", NStr("en = 'Payroll'"));
	Query.SetParameter("AddedTax", NStr("en='Tax accrued';ru='Начисленные налоги'"));
	    	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccrualsAndDeductions", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePayrollPayments", ResultsArray[2].Unload());
    StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxAccounting", ResultsArray[5].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", ResultsArray[6].Unload());
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefPayroll, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
EndProcedure

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf