#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("InventoryReceipt", NStr("en = 'Inventory receiving'"));
	Query.SetParameter("OtherExpenses", NStr("en = 'Other expenses'"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.ProductsAndServices AS ProductsAndServices,
	|	DocumentTable.Characteristic AS Characteristic,
	|	DocumentTable.Batch AS Batch,
	|	DocumentTable.CustomerOrder AS CustomerOrder,
	|	DocumentTable.Quantity AS Quantity,
	//( elmi #11
	//|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Amount - DocumentTable.VATAmount AS Amount,     
	//) elmi
	|	TRUE AS FixedCost,
	|	&InventoryReceipt AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.GLAccount,
	|	VALUE(Catalog.ProductsAndServices.EmptyRef),
	|	DocumentTable.Characteristic,
	|	DocumentTable.Batch,
	|	DocumentTable.CustomerOrder,
	|	0,
	//( elmi #11
	//|	DocumentTable.Amount,
	|	DocumentTable.Amount - DocumentTable.VATAmount,           
	//) elmi
	|	TRUE,
	|	&OtherExpenses
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE
	|	(DocumentTable.Accounting_sAccountType = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|			OR DocumentTable.Accounting_sAccountType = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	ResultTable = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultTable);
	
EndProcedure // GenerateTableInventory()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	
	Query.Text =
	"SELECT
	|	ExpenseReportInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ExpenseReportInventory.Period AS Period,
	|	ExpenseReportInventory.Company AS Company,
	|	ExpenseReportInventory.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN ExpenseReportInventory.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	ExpenseReportInventory.ProductsAndServices AS ProductsAndServices,
	|	ExpenseReportInventory.Characteristic AS Characteristic,
	|	ExpenseReportInventory.Batch AS Batch,
	|	ExpenseReportInventory.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS ExpenseReportInventory
	|WHERE
	|	(NOT ExpenseReportInventory.OrderWarehouse)
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryInWarehouses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryForWarehouses(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	ExpenseReportInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	ExpenseReportInventory.Period AS Period,
	|	ExpenseReportInventory.Company AS Company,
	|	ExpenseReportInventory.StructuralUnit AS StructuralUnit,
	|	ExpenseReportInventory.ProductsAndServices AS ProductsAndServices,
	|	ExpenseReportInventory.Characteristic AS Characteristic,
	|	ExpenseReportInventory.Batch AS Batch,
	|	ExpenseReportInventory.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS ExpenseReportInventory
	|WHERE
	|	ExpenseReportInventory.OrderWarehouse
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryForWarehouses", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryForWarehouses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateAdvanceHolderPaymentsTable(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("RepaymentOfAdvanceHolderDebt", NStr("en = 'Repayment of advance holder debt'"));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Exchange rate difference'"));
	
	Query.Text =
	"SELECT
	|	MAX(DocumentTables.LineNumber) AS LineNumber,
	|	&RepaymentOfAdvanceHolderDebt AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	DocumentTables.Period AS Period,
	|	DocumentTables.Employee AS Employee,
	|	DocumentTables.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|	DocumentTables.OverrunGLAccount AS GLAccount,
	|	DocumentTables.Currency AS Currency,
	|	&Ref AS Document,
	|	SUM(DocumentTables.Amount) AS Amount,
	|	SUM(DocumentTables.AmountCur) AS AmountCur
	|INTO TemporaryTableCostsAccountablePerson
	|FROM
	|	(SELECT
	|		MAX(DocumentTable.LineNumber) AS LineNumber,
	|		DocumentTable.Period AS Period,
	|		DocumentTable.Employee AS Employee,
	|		DocumentTable.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount AS OverrunGLAccount,
	|		DocumentTable.Currency AS Currency,
	|		SUM(DocumentTable.Amount) AS Amount,
	|		SUM(DocumentTable.AmountCur) AS AmountCur
	|	FROM
	|		TemporaryTableInventory AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.Currency
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		MAX(DocumentTable.LineNumber),
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.Currency,
	|		SUM(DocumentTable.Amount),
	|		SUM(DocumentTable.AmountCur)
	|	FROM
	|		TemporaryTableExpenses AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.Currency
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		MAX(DocumentTable.LineNumber),
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.DocumentCurrency,
	|		SUM(DocumentTable.Amount),
	|		SUM(DocumentTable.PaymentAmount)
	|	FROM
	|		TemporaryTablePayments AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.DocumentCurrency) AS DocumentTables
	|
	|GROUP BY
	|	DocumentTables.Period,
	|	DocumentTables.Employee,
	|	DocumentTables.AdvanceHoldersGLAccount,
	|	DocumentTables.OverrunGLAccount,
	|	DocumentTables.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	&RepaymentOfAdvanceHolderDebt AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	DocumentTable.Ref.Date AS Period,
	|	DocumentTable.Ref.Employee AS Employee,
	|	DocumentTable.Ref.Employee.AdvanceHoldersGLAccount AS GLAccount,
	|	DocumentTable.Document.CashCurrency AS Currency,
	|	DocumentTable.Document AS Document,
	|	SUM(CAST(DocumentTable.Amount * CurrencyRatesOfIssuedAdvances.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * CurrencyRatesOfIssuedAdvances.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.Amount) AS AmountCur,
	|	-SUM(CAST(DocumentTable.Amount * CurrencyRatesOfIssuedAdvances.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * CurrencyRatesOfIssuedAdvances.Multiplicity) AS NUMBER(15, 2))) AS AmountForBalance,
	|	-SUM(DocumentTable.Amount) AS AmountCurForBalance
	|INTO TemporaryTableAdvancesPaid
	|FROM
	|	Document.ExpenseReport.AdvancesPaid AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfIssuedAdvances
	|		ON DocumentTable.Document.CashCurrency = CurrencyRatesOfIssuedAdvances.Currency
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRates
	|		ON (TRUE)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Document,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Employee,
	|	DocumentTable.Ref.Employee.AdvanceHoldersGLAccount,
	|	DocumentTable.Document.CashCurrency
	|
	|INDEX BY
	|	Company,
	|	Employee,
	|	Currency,
	|	Document,
	|	GLAccount";
	
	Query.ExecuteBatch();
	
	// Setting the exclusive lock of controlled balances of payments to accountable persons.
	Query.Text = 
	"SELECT
	|	TemporaryTableAdvancesPaid.Company AS Company,
	|	TemporaryTableAdvancesPaid.Employee AS Employee,
	|	TemporaryTableAdvancesPaid.Currency AS Currency,
	|	TemporaryTableAdvancesPaid.Document AS Document
	|FROM
	|	TemporaryTableAdvancesPaid AS TemporaryTableAdvancesPaid";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AdvanceHolderPayments");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult IN QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	
	"SELECT
	|	DocumentTable.Amount AS Amount
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Amount
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePayments.Amount
	|FROM
	|	TemporaryTablePayments AS TemporaryTablePayments
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsBalances.Company AS Company,
	|	AccountsBalances.Employee AS Employee,
	|	AccountsBalances.Currency AS Currency,
	|	AccountsBalances.Document AS Document,
	|	AccountsBalances.Employee.AdvanceHoldersGLAccount AS GLAccount,
	|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableBalancesAfterPosting
	|FROM
	|	(SELECT
	|		TemporaryTable.Company AS Company,
	|		TemporaryTable.Employee AS Employee,
	|		TemporaryTable.Currency AS Currency,
	|		TemporaryTable.Document AS Document,
	|		TemporaryTable.AmountForBalance AS AmountBalance,
	|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
	|	FROM
	|		TemporaryTableAdvancesPaid AS TemporaryTable
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableBalances.Company,
	|		TableBalances.Employee,
	|		TableBalances.Currency,
	|		TableBalances.Document,
	|		ISNULL(TableBalances.AmountBalance, 0),
	|		ISNULL(TableBalances.AmountCurBalance, 0)
	|	FROM
	|		AccumulationRegister.AdvanceHolderPayments.Balance(
	|				&PointInTime,
	|				(Company, Employee, Currency, Document) In
	|					(SELECT DISTINCT
	|						TemporaryTableAdvancesPaid.Company,
	|						TemporaryTableAdvancesPaid.Employee,
	|						TemporaryTableAdvancesPaid.Currency,
	|						TemporaryTableAdvancesPaid.Document
	|					FROM
	|						TemporaryTableAdvancesPaid)) AS TableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecords.Company,
	|		DocumentRegisterRecords.Employee,
	|		DocumentRegisterRecords.Currency,
	|		DocumentRegisterRecords.Document,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AdvanceHolderPayments AS DocumentRegisterRecords
	|	WHERE
	|		DocumentRegisterRecords.Recorder = &Ref
	|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
	|
	|GROUP BY
	|	AccountsBalances.Company,
	|	AccountsBalances.Employee,
	|	AccountsBalances.Currency,
	|	AccountsBalances.Document,
	|	AccountsBalances.Employee.AdvanceHoldersGLAccount
	|
	|INDEX BY
	|	Company,
	|	Employee,
	|	Currency,
	|	Document,
	|	GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	1 AS LineNumber,
	|	&ControlPeriod AS Date,
	|	TableAccounts.Company AS Company,
	|	TableAccounts.Employee AS Employee,
	|	TableAccounts.Currency AS Currency,
	|	TableAccounts.Document AS Document,
	|	ISNULL(TableBalances.AmountCurBalance, 0) * CalculationCurrencyRatesSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CalculationCurrencyRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
	|	TableAccounts.GLAccount AS GLAccount
	|INTO TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder
	|FROM
	|	TemporaryTableAdvancesPaid AS TableAccounts
	|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
	|		ON TableAccounts.Company = TableBalances.Company
	|			AND TableAccounts.Employee = TableBalances.Employee
	|			AND TableAccounts.Currency = TableBalances.Currency
	|			AND TableAccounts.Document = TableBalances.Document
	|			AND TableAccounts.GLAccount = TableBalances.GLAccount
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.AccountingCurrency AS ConstantAccountingCurrency)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT DISTINCT
	|						TemporaryTableAdvancesPaid.Currency
	|					FROM
	|						TemporaryTableAdvancesPaid)) AS CalculationCurrencyRatesSliceLast
	|		ON TableAccounts.Currency = CalculationCurrencyRatesSliceLast.Currency
	|WHERE
	|	(ISNULL(TableBalances.AmountCurBalance, 0) * CalculationCurrencyRatesSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CalculationCurrencyRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
	|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CalculationCurrencyRatesSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CalculationCurrencyRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Employee AS Employee,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.AmountCur AS AmountCur
	|FROM
	|	TemporaryTableAdvancesPaid AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.ContentOfAccountingRecord,
	|	DocumentTable.RecordType,
	|	DocumentTable.GLAccount,
	|	DocumentTable.Document,
	|	DocumentTable.Employee,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Currency,
	|	DocumentTable.Amount - ISNULL(TableAdvancesPaid.Amount, 0),
	|	DocumentTable.AmountCur - ISNULL(TableAdvancesPaid.AmountCur, 0)
	|FROM
	|	TemporaryTableCostsAccountablePerson AS DocumentTable
	|		LEFT JOIN (SELECT
	|			TemporaryTableAdvancesPaid.Currency AS Currency,
	|			SUM(TemporaryTableAdvancesPaid.Amount) AS Amount,
	|			SUM(TemporaryTableAdvancesPaid.AmountCur) AS AmountCur
	|		FROM
	|			TemporaryTableAdvancesPaid AS TemporaryTableAdvancesPaid
	|		
	|		GROUP BY
	|			TemporaryTableAdvancesPaid.Currency) AS TableAdvancesPaid
	|		ON DocumentTable.Currency = TableAdvancesPaid.Currency
	|WHERE
	|	DocumentTable.AmountCur - ISNULL(TableAdvancesPaid.AmountCur, 0) > 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END,
	|	DocumentTable.GLAccount,
	|	DocumentTable.Document,
	|	DocumentTable.Employee,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.Currency,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	0
	|FROM
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableBalancesAfterPosting";
	
	ResultsArray = Query.ExecuteBatch();
	AmountTable = ResultsArray[0].Unload(); // table for round-off error calculation
	ResultTable = ResultsArray[3].Unload();
	
	AmountTotal = AmountTable.Total("Amount"); // amount for round-off error calculation
	AmountOfResult = ResultTable.Total("Amount");
	ResultDifference = AmountTotal - AmountOfResult;
	
	If ResultDifference <> 0
		AND ResultTable.Count() > 0 Then
		ResultTable[0].Amount = ResultTable[0].Amount + ResultDifference;
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSettlementsWithAdvanceHolders", ResultTable);
	
EndProcedure // GenerateTableAdvanceHolderPayments()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("VendorObligationsRepayment", "Repayment of obligations to vendor");
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference'"));
	
	Query.Text =
	"SELECT
	|	TemporaryTablePayments.LineNumber AS LineNumber,
	|	CASE
	|		WHEN TemporaryTablePayments.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN TemporaryTablePayments.AdvanceFlag
	|						THEN &Ref
	|					ELSE TemporaryTablePayments.Document
	|				END
	|		ELSE UNDEFINED
	|	END AS Document,
	|	&VendorObligationsRepayment AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	CASE
	|		WHEN TemporaryTablePayments.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TemporaryTablePayments.GLAccount AS GLAccount,
	|	TemporaryTablePayments.Currency AS Currency,
	|	TemporaryTablePayments.Counterparty AS Counterparty,
	|	TemporaryTablePayments.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePayments.DoOperationsByOrders
	|			THEN TemporaryTablePayments.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	TemporaryTablePayments.Period AS Date,
	|	SUM(TemporaryTablePayments.Amount) AS Amount,
	|	SUM(TemporaryTablePayments.AmountCur) AS AmountCur,
	|	-SUM(TemporaryTablePayments.Amount) AS AmountForBalance,
	|	-SUM(TemporaryTablePayments.AmountCur) AS AmountCurForBalance
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTablePayments AS TemporaryTablePayments
	|
	|GROUP BY
	|	TemporaryTablePayments.LineNumber,
	|	TemporaryTablePayments.GLAccount,
	|	TemporaryTablePayments.Currency,
	|	TemporaryTablePayments.Counterparty,
	|	TemporaryTablePayments.Contract,
	|	TemporaryTablePayments.Period,
	|	CASE
	|		WHEN TemporaryTablePayments.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN TemporaryTablePayments.AdvanceFlag
	|						THEN &Ref
	|					ELSE TemporaryTablePayments.Document
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePayments.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN TemporaryTablePayments.DoOperationsByOrders
	|			THEN TemporaryTablePayments.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END
	|
	|INDEX BY
	|	Company,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	Order,
	|	SettlementsType,
	|	GLAccount";
	
	Query.Execute();

	// Setting the exclusive lock for the controlled balances of settlements with suppliers.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsPayable.Company AS Company,
	|	TemporaryTableAccountsPayable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsPayable.Contract AS Contract,
	|	TemporaryTableAccountsPayable.Document AS Document,
	|	TemporaryTableAccountsPayable.Order AS Order,
	|	TemporaryTableAccountsPayable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsPayable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsPayable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = SmallBusinessServer.GetQueryTextExchangeRatesDifferencesAccountsPayable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	ResultTable = ResultsArray[QueryNumber].Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultTable);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefExpenseReport, StructureAdditionalProperties)
   	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Exchange rate difference'"));
	Query.SetParameter("OtherExpenses", NStr("en = 'Expenses reflection'"));
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	UNDEFINED AS CustomerOrder,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END AS GLAccount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS AmountExpense,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS Amount
	|FROM
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.StructuralUnit,
	|	CASE
	|		WHEN DocumentTable.Accounting_sAccountType = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.BusinessActivities.Other)
	|		ELSE DocumentTable.BusinessActivity
	|	END,
	|	CASE
	|		WHEN DocumentTable.Accounting_sAccountType = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.CustomerOrder
	|	END,
	|	DocumentTable.GLAccount,
	|	&OtherExpenses,
	|	0,
	//( elmi #11
	//|	DocumentTable.Amount,
	//|	DocumentTable.Amount
	|	DocumentTable.Amount - DocumentTable.VATAmount,  
	|	DocumentTable.Amount - DocumentTable.VATAmount   
	//) elmi
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE
	|	(DocumentTable.Accounting_sAccountType = VALUE(Enum.GLAccountsTypes.Expenses)
	|			OR DocumentTable.Accounting_sAccountType = VALUE(Enum.GLAccountsTypes.OtherExpenses))
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	VALUE(Catalog.BusinessActivities.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|
	|ORDER BY
	|	Order,
	|	DocumentTable.LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.BusinessActivity AS BusinessActivity,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.BusinessActivity,
	|	DocumentTable.Item,
	|	DocumentTable.Amount
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	DocumentTable.Item,
	|	DocumentTable.Amount
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.BusinessActivity,
	|	Table.Item,
	|	Table.AmountExpense
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|WHERE
	|	Table.AmountExpense > 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesCashMethod()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesUndistributed(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesUndistributed", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesUndistributed()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	Query.SetParameter("Period", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.Item";
	
	QueryResult = Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.IncomeAndExpensesRetained");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	LockItem.UseFromDataSource("Company", "Company");
	LockItem.UseFromDataSource("Document", "Document");
	Block.Lock();
	
	TableAmountForWriteOff = QueryResult.Unload();
	
	// Generating the table with remaining balance.
	Query.Text =
	"SELECT
	|	&Period AS Period,
	|	IncomeAndExpensesRetainedBalances.Company AS Company,
	|	IncomeAndExpensesRetainedBalances.Document AS Document,
	|	IncomeAndExpensesRetainedBalances.BusinessActivity AS BusinessActivity,
	|	VALUE(Catalog.CashFlowItems.EmptyRef) AS Item,
	|	0 AS AmountIncome,
	|	0 AS AmountExpense,
	|	-SUM(IncomeAndExpensesRetainedBalances.AmountIncomeBalance) AS AmountIncomeBalance,
	|	SUM(IncomeAndExpensesRetainedBalances.AmountExpensesBalance) AS AmountExpensesBalance
	|FROM
	|	(SELECT
	|		IncomeAndExpensesRetainedBalances.Company AS Company,
	|		IncomeAndExpensesRetainedBalances.Document AS Document,
	|		IncomeAndExpensesRetainedBalances.BusinessActivity AS BusinessActivity,
	|		IncomeAndExpensesRetainedBalances.AmountIncomeBalance AS AmountIncomeBalance,
	|		IncomeAndExpensesRetainedBalances.AmountExpenseBalance AS AmountExpensesBalance
	|	FROM
	|		AccumulationRegister.IncomeAndExpensesRetained.Balance(
	|				,
	|				Company = &Company
	|					AND Document In
	|						(SELECT
	|							DocumentTable.Document
	|						FROM
	|							TemporaryTablePayments AS DocumentTable)) AS IncomeAndExpensesRetainedBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Company,
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Document,
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.BusinessActivity,
	|		CASE
	|			WHEN DocumentRegisterRecordsOfIncomeAndExpensesPending.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountIncome, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountIncome, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsOfIncomeAndExpensesPending.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountExpense, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountExpense, 0)
	|		END
	|	FROM
	|		AccumulationRegister.IncomeAndExpensesRetained AS DocumentRegisterRecordsOfIncomeAndExpensesPending
	|	WHERE
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Recorder = &Ref) AS IncomeAndExpensesRetainedBalances
	|
	|GROUP BY
	|	IncomeAndExpensesRetainedBalances.Company,
	|	IncomeAndExpensesRetainedBalances.Document,
	|	IncomeAndExpensesRetainedBalances.BusinessActivity
	|
	|ORDER BY
	|	Document";
	
	TableSumBalance = Query.Execute().Unload();

	TableSumBalance.Indexes.Add("Document");
	
	// Calculation of the write-off amounts.
	For Each StringSumToBeWrittenOff IN TableAmountForWriteOff Do
		AmountToBeWrittenOff = StringSumToBeWrittenOff.AmountToBeWrittenOff;
		Filter = New Structure("Document", StringSumToBeWrittenOff.Document);
		RowsArrayAmountsBalances = TableSumBalance.FindRows(Filter);
		For Each AmountRowBalances IN RowsArrayAmountsBalances Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf AmountRowBalances.AmountExpensesBalance < AmountToBeWrittenOff Then
				AmountRowBalances.AmountExpense = AmountRowBalances.AmountExpensesBalance;
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountExpensesBalance;
			ElsIf AmountRowBalances.AmountExpensesBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountExpense = AmountToBeWrittenOff;
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndDo;
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.Item";
	
	TableAmountForWriteOff = Query.Execute().Unload();
	
	For Each StringSumToBeWrittenOff IN TableAmountForWriteOff Do
		AmountToBeWrittenOff = StringSumToBeWrittenOff.AmountToBeWrittenOff;
		Filter = New Structure("Document", StringSumToBeWrittenOff.Document);
		RowsArrayAmountsBalances = TableSumBalance.FindRows(Filter);
		For Each AmountRowBalances IN RowsArrayAmountsBalances Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf AmountRowBalances.AmountIncomeBalance < AmountToBeWrittenOff Then
				AmountRowBalances.AmountIncome = AmountRowBalances.AmountIncomeBalance;
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountIncomeBalance;
			ElsIf AmountRowBalances.AmountIncomeBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountIncome = AmountToBeWrittenOff;
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndDo;
	
	// Generating a temporary table with amounts,
	// items and directions of activities. Required to generate movements of income
	// and expenses by cash method.
	Query.Text =
	"SELECT
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.Document AS Document,
	|	Table.Item AS Item,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessActivity AS BusinessActivity
	|INTO TemporaryTableTableDeferredIncomeAndExpenditure
	|FROM
	|	&Table AS Table
	|WHERE
	|	Table.AmountExpense > 0";
	
	Query.SetParameter("Table", TableSumBalance);
	
	Query.Execute();
	
	// Generating the table for recording in the register.
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.Document AS Document,
	|	Table.Item AS Item,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessActivity AS BusinessActivity
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesRetained()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchasing(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TablePurchasing.Period AS Period,
	|	TablePurchasing.Company AS Company,
	|	TablePurchasing.ProductsAndServices AS ProductsAndServices,
	|	TablePurchasing.Characteristic AS Characteristic,
	|	TablePurchasing.Batch AS Batch,
	|	UNDEFINED AS PurchaseOrder,
	|	TablePurchasing.Document AS Document,
	|	TablePurchasing.VATRate AS VATRate,
	|	SUM(TablePurchasing.Quantity) AS Quantity,
	|	SUM(TablePurchasing.AmountVATPurchase) AS VATAmount,
	|	SUM(TablePurchasing.Amount) AS Amount
	|FROM
	|	TemporaryTableInventory AS TablePurchasing
	|
	|GROUP BY
	|	TablePurchasing.Period,
	|	TablePurchasing.Company,
	|	TablePurchasing.ProductsAndServices,
	|	TablePurchasing.Characteristic,
	|	TablePurchasing.Batch,
	|	TablePurchasing.Document,
	|	TablePurchasing.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	TablePurchasing.Period,
	|	TablePurchasing.Company,
	|	TablePurchasing.ProductsAndServices,
	|	TablePurchasing.Characteristic,
	|	TablePurchasing.Batch,
	|	UNDEFINED,
	|	TablePurchasing.Document,
	|	TablePurchasing.VATRate,
	|	SUM(TablePurchasing.Quantity),
	|	SUM(TablePurchasing.AmountVATPurchase),
	|	SUM(TablePurchasing.Amount)
	|FROM
	|	TemporaryTableExpenses AS TablePurchasing
	|
	|GROUP BY
	|	TablePurchasing.Period,
	|	TablePurchasing.Company,
	|	TablePurchasing.ProductsAndServices,
	|	TablePurchasing.Characteristic,
	|	TablePurchasing.Batch,
	|	TablePurchasing.Document,
	|	TablePurchasing.VATRate";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchasing", QueryResult.Unload());
	
EndProcedure // GeneratePurchasingTable()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	//( elmi #11
    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
	|	Sum(TemporaryTable.VATAmount) AS VATInventory ,
	|	Sum(TemporaryTable.VATAmountCur) AS VATInventoryCur 
	|FROM
	|	TemporaryTableInventory AS TemporaryTable
	|GROUP BY
	|TemporaryTable.Period,
	|TemporaryTable.Company	";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	VATInventory = 0;
	VATInventoryCur = 0;
	
	While Selection.Next() Do  
		  VATInventory    = Selection.VATInventory;
	      VATInventoryCur = Selection.VATInventoryCur;
	EndDo;

    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
	|	Sum(TemporaryTable.VATAmount) AS VATExpenses ,
	|	Sum(TemporaryTable.VATAmountCur) AS VATExpensesCur 
	|FROM
	|	TemporaryTableExpenses AS TemporaryTable
	|GROUP BY
	|TemporaryTable.Period,
	|TemporaryTable.Company	";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	VATExpenses = 0;
	VATExpensesCur = 0;
	
	While Selection.Next() Do  
		  VATExpenses    = Selection.VATExpenses;
	      VATExpensesCur = Selection.VATExpensesCur;
	EndDo;
	//) elmi

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("ExchangeDifference", NStr("en = 'Exchange rate difference'"));
	Query.SetParameter("InventoryReceipt", NStr("en = 'Inventory receiving'"));
	Query.SetParameter("VendorsPayment", NStr("en = 'Payment to vendor'"));
	Query.SetParameter("OtherExpenses", NStr("en = 'Other expenses'"));
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.GLAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	//( elmi #11
	//|			THEN DocumentTable.AmountCur
	|			THEN DocumentTable.AmountCur - DocumentTable.VATAmountCur
	//) elmi
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.AdvanceHoldersGLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	//( elmi #11
	//|			THEN DocumentTable.AmountCur
	|			THEN DocumentTable.AmountCur - DocumentTable.VATAmountCur
	//) elmi
	|		ELSE 0
	|	END AS AmountCurCr,
	//( elmi #11
	//|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Amount - DocumentTable.VATAmount AS Amount,
	//) elmi
	|	CAST(&OtherExpenses AS String(100)) AS Content
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	//( elmi #11
	//|			THEN DocumentTable.AmountCur 
	|			THEN DocumentTable.AmountCur  -  DocumentTable.VATAmountCur
	//) elmi
	|		ELSE 0
	|	END,
	|	DocumentTable.AdvanceHoldersGLAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	//( elmi #11
	//|			THEN DocumentTable.AmountCur 
	|			THEN DocumentTable.AmountCur  -  DocumentTable.VATAmountCur
	//) elmi
    |		ELSE 0
	|	END,
	//( elmi #11
	//|	DocumentTable.Amount,
	|	DocumentTable.Amount - DocumentTable.VATAmount,
	//) elmi
	|	CAST(&InventoryReceipt AS String(100))
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.AdvanceHoldersGLAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&VendorsPayment AS String(100))
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.AdvanceHoldersGLAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.AmountCur - ISNULL(TableAdvancesPaid.AmountCur, 0)
	|		ELSE 0
	|	END,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur - ISNULL(TableAdvancesPaid.AmountCur, 0)
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount - ISNULL(TableAdvancesPaid.Amount, 0),
	|	DocumentTable.ContentOfAccountingRecord
	|FROM
	|	TemporaryTableCostsAccountablePerson AS DocumentTable
	|		LEFT JOIN (SELECT
	|			TemporaryTableAdvancesPaid.Currency AS Currency,
	|			SUM(TemporaryTableAdvancesPaid.Amount) AS Amount,
	|			SUM(TemporaryTableAdvancesPaid.AmountCur) AS AmountCur
	|		FROM
	|			TemporaryTableAdvancesPaid AS TemporaryTableAdvancesPaid
	|		
	|		GROUP BY
	|			TemporaryTableAdvancesPaid.Currency) AS TableAdvancesPaid
	|		ON DocumentTable.Currency = TableAdvancesPaid.Currency
	|WHERE
	|	DocumentTable.AmountCur - ISNULL(TableAdvancesPaid.AmountCur, 0) > 0
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference
	|FROM
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	8 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&TextVAT ,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.AdvanceHoldersGLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN &VATInventoryCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	 &VATInventory ,
	|	CAST(&TextVATInventory AS String(100)) AS Content
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE &VATInventory  > 0
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	9 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&TextVAT ,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.AdvanceHoldersGLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN &VATExpensesCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	&VATExpenses ,
	|	CAST(&TextVATExpenses AS String(100)) AS Content
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE &VATExpenses  > 0
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	
	//( elmi #11
	Query.SetParameter("TextVATInventory", NStr("en=' VAT goods'"));
	Query.SetParameter("TextVATExpenses", NStr("en=' VAT expenses'"));
	Query.SetParameter("TextVAT",  ChartsOfAccounts.Managerial.Taxes);
	Query.SetParameter("VATExpenses", VATExpenses);
	Query.SetParameter("VATInventory", VATInventory);
	Query.SetParameter("VATExpensesCur", VATExpensesCur);
	Query.SetParameter("VATInventoryCur", VATInventoryCur);
	//) elmi

	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", QueryResult.Unload());
	
EndProcedure // GenerateTableManagerial()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	&Company AS Company,
	|	DocumentTable.InvoiceForPayment AS InvoiceForPayment,
	|	SUM(CASE
	|			WHEN Not DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN DocumentTable.DocumentCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.PaymentAmount
	|			WHEN DocumentTable.Currency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.AmountCur
	|			ELSE CAST(DocumentTable.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|		END) AS AdvanceAmount,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN DocumentTable.DocumentCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.PaymentAmount
	|			WHEN DocumentTable.Currency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.AmountCur
	|			ELSE CAST(DocumentTable.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|		END) AS PaymentAmount
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfAccount
	|		ON DocumentTable.InvoiceForPayment.DocumentCurrency = CurrencyRatesOfAccount.Currency
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfPettyCashe
	|		ON DocumentTable.DocumentCurrency = CurrencyRatesOfPettyCashe.Currency
	|WHERE
	|	DocumentTable.InvoiceForPayment <> VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
	|	AND DocumentTable.TrackPaymentsByBills
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.InvoiceForPayment
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	&Company,
	|	DocumentTable.Order,
	|	SUM(CASE
	|			WHEN Not DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN DocumentTable.DocumentCurrency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.PaymentAmount
	|			WHEN DocumentTable.Currency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.AmountCur
	|			ELSE CAST(DocumentTable.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|		END),
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN DocumentTable.DocumentCurrency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.PaymentAmount
	|			WHEN DocumentTable.Currency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.AmountCur
	|			ELSE CAST(DocumentTable.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|		END)
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfAccount
	|		ON DocumentTable.Order.DocumentCurrency = CurrencyRatesOfAccount.Currency
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfPettyCashe
	|		ON DocumentTable.DocumentCurrency = CurrencyRatesOfPettyCashe.Currency
	|WHERE
	|	(VALUETYPE(DocumentTable.Order) = Type(Document.CustomerOrder)
	|				AND DocumentTable.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			OR VALUETYPE(DocumentTable.Order) = Type(Document.PurchaseOrder)
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef))
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Order
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure // GenerateTableInvoicesAndOrdersPayment()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePaymentCalendar(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UsePaymentCalendar", Constants.FunctionalOptionPaymentCalendar.Get());
	
	Query.Text =
	"SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	VALUE(Enum.CashAssetTypes.Cash) AS CashAssetsType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	UNDEFINED AS BankAccountPettyCash,
	|	CASE
	|		WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|			THEN DocumentTable.Currency
	|		ELSE DocumentTable.DocumentCurrency
	|	END AS Currency,
	|	DocumentTable.InvoiceForPaymentToPaymentCalendar AS InvoiceForPayment,
	|	SUM(CASE
	|			WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|				THEN -DocumentTable.AmountCur
	|			ELSE -DocumentTable.PaymentAmount
	|		END) AS PaymentAmount
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	CASE
	|		WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|			THEN DocumentTable.Currency
	|		ELSE DocumentTable.DocumentCurrency
	|	END,
	|	DocumentTable.InvoiceForPaymentToPaymentCalendar
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure // GenerateTablePaymentCalendar()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefExpenseReport, StructureAdditionalProperties) Export
	
	Query = New Query();
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("InventoryReceipt", NStr("en = 'Inventory receiving'"));
	Query.SetParameter("OtherExpenses", NStr("en = 'Expenses reflection'"));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Document.Item AS Item
	|FROM
	|	Document.ExpenseReport.AdvancesPaid AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND &IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute().Select();
	
	If QueryResult.Next() Then
		Item = QueryResult.Item;
	Else
		Item = Catalogs.CashFlowItems.PaymentToVendor;
	EndIf;
	
	Query.SetParameter("Item", Item);
	
	Query.Text =
	"SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Contract.SettlementsCurrency AS Currency,
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref.Employee AS Employee,
	|	DocumentTable.Ref.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Ref.Employee.OverrunGLAccount AS OverrunGLAccount,
	|	DocumentTable.Ref.Employee.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|	DocumentTable.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	DocumentTable.Counterparty.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Counterparty.VendorAdvancesGLAccount
	|		ELSE DocumentTable.Counterparty.GLAccountVendorSettlements
	|	END AS GLAccount,
	|	DocumentTable.Order AS Order,
	|	DocumentTable.InvoiceForPayment AS InvoiceForPayment,
	|	CASE
	|		WHEN DocumentTable.InvoiceForPayment.SchedulePayment
	|			THEN DocumentTable.InvoiceForPayment
	|		WHEN DocumentTable.Order.SchedulePayment
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS InvoiceForPaymentToPaymentCalendar,
	|	DocumentTable.ExchangeRate AS ExchangeRate,
	|	DocumentTable.Multiplicity AS Multiplicity,
	|	CASE
	|		WHEN DocumentTable.Item = VALUE(Catalog.CashFlowItems.EmptyRef)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Item
	|	END AS Item,
	|	SUM(DocumentTable.PaymentAmount) AS PaymentAmount,
	|	SUM(CAST(DocumentTable.PaymentAmount * DocumentTable.Ref.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * DocumentTable.Ref.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur
	|INTO TemporaryTablePayments
	|FROM
	|	Document.ExpenseReport.Payments AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRates
	|		ON (TRUE)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Document,
	|	DocumentTable.Order,
	|	DocumentTable.InvoiceForPayment,
	|	DocumentTable.ExchangeRate,
	|	DocumentTable.Multiplicity,
	|	DocumentTable.Item,
	|	DocumentTable.Ref.Date,
	|	CASE
	|		WHEN DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.Ref.Employee.OverrunGLAccount,
	|	DocumentTable.Ref.Employee.AdvanceHoldersGLAccount,
	|	DocumentTable.Ref.Employee,
	|	DocumentTable.Counterparty.GLAccountVendorSettlements,
	|	DocumentTable.Counterparty.VendorAdvancesGLAccount,
	|	DocumentTable.Ref.DocumentCurrency,
	|	CASE
	|		WHEN DocumentTable.InvoiceForPayment.SchedulePayment
	|			THEN DocumentTable.InvoiceForPayment
	|		WHEN DocumentTable.Order.SchedulePayment
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Counterparty.TrackPaymentsByBills
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExpenseReportInventory.LineNumber AS LineNumber,
	|	ExpenseReportInventory.Period AS Period,
	|	ExpenseReportInventory.Company AS Company,
	|	ExpenseReportInventory.StructuralUnit AS StructuralUnit,
	|	ExpenseReportInventory.StructuralUnit.OrderWarehouse AS OrderWarehouse,
	|	ExpenseReportInventory.Cell AS Cell,
	|	ExpenseReportInventory.GLAccount AS GLAccount,
	|	ExpenseReportInventory.ProductsAndServices AS ProductsAndServices,
	|	ExpenseReportInventory.BusinessActivity AS BusinessActivity,
	|	ExpenseReportInventory.Employee AS Employee,
	|	ExpenseReportInventory.Currency AS Currency,
	|	ExpenseReportInventory.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|	ExpenseReportInventory.OverrunGLAccount AS OverrunGLAccount,
	|	ExpenseReportInventory.Characteristic AS Characteristic,
	|	ExpenseReportInventory.Batch AS Batch,
	|	ExpenseReportInventory.CustomerOrder AS CustomerOrder,
	|	ExpenseReportInventory.Quantity AS Quantity,
	|	ExpenseReportInventory.Amount AS Amount,
	|	ExpenseReportInventory.AmountCur AS AmountCur,
	|	ExpenseReportInventory.VATAmount AS VATAmount,
	|	ExpenseReportInventory.VATRate AS VATRate,
	|	ExpenseReportInventory.AmountVATPurchase AS AmountVATPurchase,
	|	ExpenseReportInventory.VATAmountCur AS VATAmountCur,
	|	CASE
	|		WHEN ExpenseReportInventory.Item = VALUE(Catalog.CashFlowItems.EmptyRef)
	|			THEN &Item
	|		ELSE ExpenseReportInventory.Item
	|	END AS Item,
	|	&Ref AS Document
	|INTO TemporaryTableInventory
	|FROM
	|	(SELECT
	|		ExpenseReportInventory.LineNumber AS LineNumber,
	|		ExpenseReportInventory.Ref.Date AS Period,
	|		&Company AS Company,
	|		ExpenseReportInventory.StructuralUnit AS StructuralUnit,
	|		ExpenseReportInventory.Cell AS Cell,
	|		ExpenseReportInventory.ProductsAndServices.InventoryGLAccount AS GLAccount,
	|		ExpenseReportInventory.ProductsAndServices.BusinessActivity AS BusinessActivity,
	|		ExpenseReportInventory.ProductsAndServices AS ProductsAndServices,
	|		ExpenseReportInventory.Ref.Employee AS Employee,
	|		ExpenseReportInventory.VATRate AS VATRate,
	|		ExpenseReportInventory.Ref.DocumentCurrency AS Currency,
	|		ExpenseReportInventory.Ref.Employee.OverrunGLAccount AS OverrunGLAccount,
	|		ExpenseReportInventory.Ref.Employee.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|		ExpenseReportInventory.CustomerOrder AS CustomerOrder,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN ExpenseReportInventory.Characteristic
	|			ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|		END AS Characteristic,
	|		CASE
	|			WHEN &UseBatches
	|				THEN ExpenseReportInventory.Batch
	|			ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|		END AS Batch,
	|		CASE
	|			WHEN VALUETYPE(ExpenseReportInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN ExpenseReportInventory.Quantity
	|			ELSE ExpenseReportInventory.Quantity * ExpenseReportInventory.MeasurementUnit.Factor
	|		END AS Quantity,
	|		CASE
	|			WHEN ExpenseReportInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE ExpenseReportInventory.VATAmount
	|		END AS VATAmountCur,
	|		CASE
	|			WHEN ExpenseReportInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CAST(ExpenseReportInventory.VATAmount * ExpenseReportInventory.Ref.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * ExpenseReportInventory.Ref.Multiplicity) AS NUMBER(15, 2))
	|		END AS VATAmount,
	|		CAST(ExpenseReportInventory.VATAmount * ExpenseReportInventory.Ref.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * ExpenseReportInventory.Ref.Multiplicity) AS NUMBER(15, 2)) AS AmountVATPurchase,
	|		ExpenseReportInventory.Total AS AmountCur,
	|		CAST(ExpenseReportInventory.Total * ExpenseReportInventory.Ref.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * ExpenseReportInventory.Ref.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|		ExpenseReportInventory.Item AS Item,
	|		&InventoryReceipt AS ContentOfAccountingRecord
	|	FROM
	|		Document.ExpenseReport.Inventory AS ExpenseReportInventory
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|					&PointInTime,
	|					Currency In
	|						(SELECT
	|							Constants.AccountingCurrency
	|						FROM
	|							Constants AS Constants)) AS AccountingCurrencyRates
	|			ON (TRUE)
	|	WHERE
	|		ExpenseReportInventory.Ref = &Ref) AS ExpenseReportInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExpenseReportExpenses.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ExpenseReportExpenses.Period AS Period,
	|	ExpenseReportExpenses.Company AS Company,
	|	ExpenseReportExpenses.StructuralUnit AS StructuralUnit,
	|	ExpenseReportExpenses.GLAccount AS GLAccount,
	|	ExpenseReportExpenses.ProductsAndServices AS ProductsAndServices,
	|	ExpenseReportExpenses.Employee AS Employee,
	|	ExpenseReportExpenses.Currency AS Currency,
	|	ExpenseReportExpenses.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|	ExpenseReportExpenses.OverrunGLAccount AS OverrunGLAccount,
	|	ExpenseReportExpenses.Characteristic AS Characteristic,
	|	ExpenseReportExpenses.Batch AS Batch,
	|	ExpenseReportExpenses.Quantity AS Quantity,
	|	ExpenseReportExpenses.CustomerOrder AS CustomerOrder,
	|	ExpenseReportExpenses.Amount AS Amount,
	|	ExpenseReportExpenses.AmountCur AS AmountCur,
	|	ExpenseReportExpenses.VATRate AS VATRate,
	|	ExpenseReportExpenses.VATAmount AS VATAmount,
	|	ExpenseReportExpenses.VATAmountCur AS VATAmountCur,
	|	ExpenseReportExpenses.AmountVATPurchase AS AmountVATPurchase,
	|	ExpenseReportExpenses.Accounting_sAccountType AS Accounting_sAccountType,
	|	ExpenseReportExpenses.BusinessActivity AS BusinessActivity,
	|	CASE
	|		WHEN ExpenseReportExpenses.Item = VALUE(Catalog.CashFlowItems.EmptyRef)
	|			THEN &Item
	|		ELSE ExpenseReportExpenses.Item
	|	END AS Item,
	|	TRUE AS FixedCost,
	|	&Ref AS Document
	|INTO TemporaryTableExpenses
	|FROM
	|	(SELECT
	|		ExpenseReportExpenses.LineNumber AS LineNumber,
	|		ExpenseReportExpenses.Ref.Date AS Period,
	|		&Company AS Company,
	|		ExpenseReportExpenses.StructuralUnit AS StructuralUnit,
	|		ExpenseReportExpenses.ProductsAndServices.ExpensesGLAccount AS GLAccount,
	|		ExpenseReportExpenses.BusinessActivity AS BusinessActivity,
	|		ExpenseReportExpenses.ProductsAndServices AS ProductsAndServices,
	|		ExpenseReportExpenses.VATRate AS VATRate,
	|		ExpenseReportExpenses.Ref.Employee AS Employee,
	|		ExpenseReportExpenses.Ref.DocumentCurrency AS Currency,
	|		ExpenseReportExpenses.Ref.Employee.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|		ExpenseReportExpenses.Ref.Employee.OverrunGLAccount AS OverrunGLAccount,
	|		VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef) AS Characteristic,
	|		VALUE(Catalog.ProductsAndServicesBatches.EmptyRef) AS Batch,
	|		CASE
	|			WHEN VALUETYPE(ExpenseReportExpenses.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN ExpenseReportExpenses.Quantity
	|			ELSE ExpenseReportExpenses.Quantity * ExpenseReportExpenses.MeasurementUnit.Factor
	|		END AS Quantity,
	|		ExpenseReportExpenses.CustomerOrder AS CustomerOrder,
	|		CASE
	|			WHEN ExpenseReportExpenses.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE ExpenseReportExpenses.VATAmount
	|		END AS VATAmountCur,
	|		CASE
	|			WHEN ExpenseReportExpenses.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CAST(ExpenseReportExpenses.VATAmount * ExpenseReportExpenses.Ref.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * ExpenseReportExpenses.Ref.Multiplicity) AS NUMBER(15, 2))
	|		END AS VATAmount,
	|		CAST(ExpenseReportExpenses.VATAmount * ExpenseReportExpenses.Ref.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * ExpenseReportExpenses.Ref.Multiplicity) AS NUMBER(15, 2)) AS AmountVATPurchase,
	|		ExpenseReportExpenses.Total AS AmountCur,
	|		ExpenseReportExpenses.Item AS Item,
	|		CAST(ExpenseReportExpenses.Total * ExpenseReportExpenses.Ref.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * ExpenseReportExpenses.Ref.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|		ExpenseReportExpenses.ProductsAndServices.ExpensesGLAccount.TypeOfAccount AS Accounting_sAccountType
	|	FROM
	|		Document.ExpenseReport.Expenses AS ExpenseReportExpenses
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|					&PointInTime,
	|					Currency In
	|						(SELECT
	|							Constants.AccountingCurrency
	|						FROM
	|							Constants AS Constants)) AS AccountingCurrencyRates
	|			ON (TRUE)
	|	WHERE
	|		ExpenseReportExpenses.Ref = &Ref) AS ExpenseReportExpenses";
	
	Query.ExecuteBatch();
	
	GenerateTableInventory(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableInventoryInWarehouses(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableInventoryForWarehouses(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateAdvanceHolderPaymentsTable(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesUndistributed(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTablePurchasing(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableManagerial(DocumentRefExpenseReport, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefExpenseReport, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.	
	If StructureTemporaryTables.RegisterRecordsAdvanceHolderPaymentsChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Cell) AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryInWarehousesOfBalance.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, ProductsAndServices, Characteristic, Batch, Cell) In
		|					(SELECT
		|						RegisterRecordsInventoryInWarehousesChange.Company AS Company,
		|						RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryInWarehousesChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryInWarehousesChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryInWarehousesChange.Batch AS Batch,
		|						RegisterRecordsInventoryInWarehousesChange.Cell AS Cell
		|					FROM
		|						RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange)) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.ProductsAndServices = InventoryInWarehousesOfBalance.ProductsAndServices
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|WHERE
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.GLAccount) AS GLAccountPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.CustomerOrder) AS CustomerOrderPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		LEFT JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
		|					(SELECT
		|						RegisterRecordsInventoryChange.Company AS Company,
		|						RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryChange.GLAccount AS GLAccount,
		|						RegisterRecordsInventoryChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryChange.Batch AS Batch,
		|						RegisterRecordsInventoryChange.CustomerOrder AS CustomerOrder
		|					FROM
		|						RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange)) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.GLAccount = InventoryBalances.GLAccount
		|			AND RegisterRecordsInventoryChange.ProductsAndServices = InventoryBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.CustomerOrder = InventoryBalances.CustomerOrder
		|WHERE
		|	ISNULL(InventoryBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsAdvanceHolderPaymentsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsAdvanceHolderPaymentsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsAdvanceHolderPaymentsChange.Employee) AS EmployeePresentation,
		|	REFPRESENTATION(RegisterRecordsAdvanceHolderPaymentsChange.Currency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAdvanceHolderPaymentsChange.Document) AS DocumentPresentation,
		|	ISNULL(AdvanceHolderPaymentsBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AdvanceHolderPaymentsBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAdvanceHolderPaymentsChange.SumCurChange + ISNULL(AdvanceHolderPaymentsBalances.AmountCurBalance, 0) AS AccountablePersonBalance,
		|	RegisterRecordsAdvanceHolderPaymentsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAdvanceHolderPaymentsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAdvanceHolderPaymentsChange.AmountChange AS AmountChange,
		|	RegisterRecordsAdvanceHolderPaymentsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAdvanceHolderPaymentsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAdvanceHolderPaymentsChange.SumCurChange AS SumCurChange
		|FROM
		|	RegisterRecordsAdvanceHolderPaymentsChange AS RegisterRecordsAdvanceHolderPaymentsChange
		|		LEFT JOIN AccumulationRegister.AdvanceHolderPayments.Balance(
		|				&ControlTime,
		|				(Company, Employee, Currency, Document) In
		|					(SELECT
		|						RegisterRecordsAdvanceHolderPaymentsChange.Company AS Company,
		|						RegisterRecordsAdvanceHolderPaymentsChange.Employee AS Employee,
		|						RegisterRecordsAdvanceHolderPaymentsChange.Currency AS Currency,
		|						RegisterRecordsAdvanceHolderPaymentsChange.Document AS Document
		|					FROM
		|						RegisterRecordsAdvanceHolderPaymentsChange AS RegisterRecordsAdvanceHolderPaymentsChange)) AS AdvanceHolderPaymentsBalances
		|		ON RegisterRecordsAdvanceHolderPaymentsChange.Company = AdvanceHolderPaymentsBalances.Company
		|			AND RegisterRecordsAdvanceHolderPaymentsChange.Employee = AdvanceHolderPaymentsBalances.Employee
		|			AND RegisterRecordsAdvanceHolderPaymentsChange.Currency = AdvanceHolderPaymentsBalances.Currency
		|			AND RegisterRecordsAdvanceHolderPaymentsChange.Document = AdvanceHolderPaymentsBalances.Document
		|WHERE
		|	(VALUETYPE(AdvanceHolderPaymentsBalances.Document) = Type(Document.ExpenseReport)
		|				AND ISNULL(AdvanceHolderPaymentsBalances.AmountCurBalance, 0) > 0
		|			OR VALUETYPE(AdvanceHolderPaymentsBalances.Document) <> Type(Document.ExpenseReport)
		|				AND ISNULL(AdvanceHolderPaymentsBalances.AmountCurBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.SettlementsType) AS CalculationsTypesPresentation,
		|	TRUE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountChange AS AmountChange,
		|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS DebtBalanceAmount,
		|	-(RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0)) AS AmountOfOutstandingAdvances,
		|	ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
		|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(
		|				&ControlTime,
		|				(Company, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT
		|						RegisterRecordsSuppliersSettlementsChange.Company AS Company,
		|						RegisterRecordsSuppliersSettlementsChange.Counterparty AS Counterparty,
		|						RegisterRecordsSuppliersSettlementsChange.Contract AS Contract,
		|						RegisterRecordsSuppliersSettlementsChange.Document AS Document,
		|						RegisterRecordsSuppliersSettlementsChange.Order AS Order,
		|						RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange)) AS AccountsPayableBalances
		|		ON RegisterRecordsSuppliersSettlementsChange.Company = AccountsPayableBalances.Company
		|			AND RegisterRecordsSuppliersSettlementsChange.Counterparty = AccountsPayableBalances.Counterparty
		|			AND RegisterRecordsSuppliersSettlementsChange.Contract = AccountsPayableBalances.Contract
		|			AND RegisterRecordsSuppliersSettlementsChange.Document = AccountsPayableBalances.Document
		|			AND RegisterRecordsSuppliersSettlementsChange.Order = AccountsPayableBalances.Order
		|			AND RegisterRecordsSuppliersSettlementsChange.SettlementsType = AccountsPayableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsSuppliersSettlementsChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsPayableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsPayableBalances.AmountCurBalance, 0) < 0
		|		END
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty() Then
			DocumentObjectExpenseReport = DocumentRefExpenseReport.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectExpenseReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory and cost accounting.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectExpenseReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on advance holder payments.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			SmallBusinessServer.ShowMessageAboutPostingToAdvanceHolderPaymentsRegisterErrors(DocumentObjectExpenseReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			SmallBusinessServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectExpenseReport, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure // RunControl()

#Region PrintInterface

Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	SetPrivilegedMode(True);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ExpenseReport";
	
	FirstDocument = True;
	NationalCurrency = Constants.NationalCurrency.Get();
	
	For Each CurrentDocument IN ObjectsArray Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query;
		Query.SetParameter("CurrentDocument", CurrentDocument);
		
		Query.Text =
		"SELECT
		|	ExpenseReport.Number,
		|	ExpenseReport.Date AS DocumentDate,
		|	ExpenseReport.Company,
		|	ExpenseReport.Company AS Heads,
		|	ExpenseReport.Employee AS AdvanceHolder,
		|	ExpenseReport.Employee.Ind AS Ind,
		|	ExpenseReport.DocumentCurrency,
		|	ExpenseReport.DocumentCurrency.Presentation AS PresentationOfCurrency,
		|	CASE
		|		WHEN ExpenseReport.ExchangeRate = 0
		|			THEN 1
		|		ELSE ExpenseReport.ExchangeRate
		|	END AS ExchangeRate,
		|	CASE
		|		WHEN ExpenseReport.Multiplicity = 0
		|			THEN 1
		|		ELSE ExpenseReport.Multiplicity
		|	END AS Multiplicity,
		|	ExpenseReport.AmountIncludesVAT,
		|	ExpenseReport.IncludeVATInPrice,
		|	ExpenseReport.DocumentAmount AS DocumentAmount,
		|	CASE
		|		WHEN ExpenseReport.Multiplicity = 0
		|			THEN 0
		|		ELSE CAST(ExpenseReport.DocumentAmount * ExpenseReport.ExchangeRate / ExpenseReport.Multiplicity AS NUMBER(15, 2))
		|	END AS DocumentAmountInNatCurrency,
		|	ExpenseReport.AdvancesPaid.(
		|		Document,
		|		Amount
		|	),
		|	ExpenseReport.Inventory.(
		|		Ref,
		|		LineNumber,
		|		ProductsAndServices,
		|		Characteristic,
		|		Batch,
		|		MeasurementUnit,
		|		Quantity,
		|		Price,
		|		Amount,
		|		VATRate,
		|		VATAmount,
		|		Total,
		|		CustomerOrder,
		|		StructuralUnit,
		|		Cell,
		|		ProductsAndServices.InventoryGLAccount.Code AS DebitOfSubAccount,
		|		ProductsAndServices.SKU AS SKU,
		|		IncomingDocumentDate AS DocumentDate,
		|		IncomingDocumentNumber AS DocumentNumber,
		|		CASE
		|			WHEN (CAST(ExpenseReport.Inventory.ProductsAndServices.DescriptionFull AS String(1000))) = """"
		|				THEN ExpenseReport.Inventory.ProductsAndServices.Description
		|			ELSE CAST(ExpenseReport.Inventory.ProductsAndServices.DescriptionFull AS String(1000))
		|		END AS InventoryItemDescription,
		|		Content
		|	),
		|	ExpenseReport.Expenses.(
		|		Ref,
		|		LineNumber,
		|		ProductsAndServices,
		|		MeasurementUnit,
		|		Quantity,
		|		Price,
		|		Amount,
		|		VATRate,
		|		VATAmount,
		|		Total,
		|		CustomerOrder,
		|		StructuralUnit,
		|		BusinessActivity,
		|		ProductsAndServices.ExpensesGLAccount.Code AS DebitOfSubAccount,
		|		ProductsAndServices.SKU AS SKU,
		|		IncomingDocumentDate AS DocumentDate,
		|		IncomingDocumentNumber AS DocumentNumber,
		|		CASE
		|			WHEN (CAST(ExpenseReport.Expenses.ProductsAndServices.DescriptionFull AS String(1000))) = """"
		|				THEN ExpenseReport.Expenses.ProductsAndServices.Description
		|			ELSE CAST(ExpenseReport.Expenses.ProductsAndServices.DescriptionFull AS String(1000))
		|		END AS ExpenseDescription,
		|		Content
		|	),
		|	ExpenseReport.Payments.(
		|		IncomingDocumentDate AS DocumentDate,
		|		IncomingDocumentNumber AS DocumentNumber,
		|		CASE
		|			WHEN ExpenseReport.Payments.AdvanceFlag
		|				THEN ExpenseReport.Payments.Counterparty.VendorAdvancesGLAccount.Code
		|			ELSE ExpenseReport.Payments.Counterparty.GLAccountVendorSettlements.Code
		|		END AS DebitOfSubAccount,
		|		PaymentAmount AS PaymentAmount,
		|		Counterparty
		|	),
		|	ExpenseReport.Employee.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
		|	ExpenseReport.Company.Prefix AS Prefix
		|FROM
		|	Document.ExpenseReport AS ExpenseReport
		|WHERE
		|	ExpenseReport.Ref = &CurrentDocument";
		
		Header = Query.Execute().Select();
		Header.Next();
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_Report_AdvancesExpenseReport";
		
		If (TemplateName = "ExpenseReport") Then
			Template 					= PrintManagement.PrintedFormsTemplate("Document.ExpenseReport.PF_MXL_ExpenseReport");
			
		ElsIf TemplateName = "ExpenseReportInCurrency" Then
			Template 					= PrintManagement.PrintedFormsTemplate("Document.ExpenseReport.PF_MXL_ExpenseReportInCurrency");
			
		EndIf;
		
		InForeignCurrency = Not (Header.DocumentCurrency = NationalCurrency);
		
		Counterparty = SmallBusinessServer.GetCompany(Header.Company);
		
		// TITLE PAGE
		AdvancesPaid = Header.AdvancesPaid.Unload();
		AdvanceDocumentsArray = AdvancesPaid.UnloadColumn("Document");
		
		Query = New Query();
		Query.SetParameter("Employee",  Header.AdvanceHolder);
		Query.SetParameter("Company", Counterparty);
		Query.SetParameter("DateOfTotals", Header.DocumentDate);
		Query.SetParameter("Currency", Header.DocumentCurrency);
		Query.SetParameter("AdvanceDocumentsArray", AdvanceDocumentsArray);
		Query.SetParameter("ConvertIntoNatCurrency",	Not InForeignCurrency);
		Query.SetParameter("ExchangeRate", 						Header.ExchangeRate);
		Query.SetParameter("Multiplicity", 					Header.Multiplicity);
		
		Query.Text = 
		"SELECT
		|	SUM(NestedSelect.AmountBalance) AS AmountBalanceInCurrency,
		|	SUM(CASE
		|			WHEN &ConvertIntoNatCurrency
		|				THEN CAST(NestedSelect.AmountBalance * &ExchangeRate / &Multiplicity AS NUMBER(15, 2))
		|			ELSE NestedSelect.AmountBalance
		|		END) AS AmountBalance
		|FROM
		|	(SELECT
		|		AdvanceHolderPaymentsBalances.AmountCurBalance AS AmountBalance
		|	FROM
		|		AccumulationRegister.AdvanceHolderPayments.Balance(
		|				&DateOfTotals,
		|				Company = &Company
		|					AND Employee = &Employee
		|					AND Currency = &Currency) AS AdvanceHolderPaymentsBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		CASE
		|			WHEN AdvanceHolderPayments.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(AdvanceHolderPayments.AmountCur, 0)
		|			ELSE -ISNULL(AdvanceHolderPayments.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.AdvanceHolderPayments AS AdvanceHolderPayments
		|	WHERE
		|		AdvanceHolderPayments.Recorder IN(&AdvanceDocumentsArray)
		|		AND AdvanceHolderPayments.Period <= &DateOfTotals) AS NestedSelect";
		PreviousAdvance = Query.Execute().Select();
		PreviousAdvance.Next();
		
		AmountBeforeDocument		= ?(ValueIsFilled(PreviousAdvance.AmountBalance), PreviousAdvance.AmountBalance, 0);
		AmountBeforeDocumentInCurrency	= ?(ValueIsFilled(PreviousAdvance.AmountBalanceInCurrency), PreviousAdvance.AmountBalanceInCurrency, 0);
		
		Query = New Query();
		Query.SetParameter("AdvanceDocumentsArray", AdvanceDocumentsArray);
		Query.SetParameter("ConvertIntoNatCurrency",	InForeignCurrency);
		Query.SetParameter("ExchangeRate", 						Header.ExchangeRate);
		Query.SetParameter("Multiplicity", 					Header.Multiplicity);
		Query.Text = 
		"SELECT
		|	SUM(CashPayment.DocumentAmount) AS DocumentAmountInCurrency,
		|	SUM(CASE
		|			WHEN &ConvertIntoNatCurrency
		|				THEN CAST(CashPayment.DocumentAmount * &ExchangeRate / &Multiplicity AS NUMBER(15, 2))
		|			ELSE CashPayment.DocumentAmount
		|		END) AS DocumentAmount
		|FROM
		|	Document.CashPayment AS CashPayment
		|WHERE
		|	CashPayment.Ref IN(&AdvanceDocumentsArray)
		|
		|GROUP BY
		|	CashPayment.Ref";
		Tab = Query.Execute().Unload();
		Tab = Query.Execute().Unload();
		AcceptedFromPettyCash = Number(Tab.Total("DocumentAmount"));
		ReceivedFromPettyCashInCurrency = Number(Tab.Total("DocumentAmountInCurrency"));
		
		Query = New Query();
		Query.SetParameter("AdvanceDocumentsArray",	AdvanceDocumentsArray);
		Query.SetParameter("ConvertIntoNatCurrency",	Not InForeignCurrency);
		Query.SetParameter("ExchangeRate", 						Header.ExchangeRate);
		Query.SetParameter("Multiplicity", 					Header.Multiplicity);
		Query.Text = 
		"SELECT
		|	SUM(PaymentExpense.DocumentAmount) AS DocumentAmountInCurrency,
		|	SUM(CASE
		|			WHEN &ConvertIntoNatCurrency
		|				THEN CAST(PaymentExpense.DocumentAmount * &ExchangeRate / &Multiplicity AS NUMBER(15, 2))
		|			ELSE PaymentExpense.DocumentAmount
		|		END) AS DocumentAmount
		|FROM
		|	Document.PaymentExpense AS PaymentExpense
		|WHERE
		|	PaymentExpense.Ref IN(&AdvanceDocumentsArray)";
		
		Tab = Query.Execute().Unload();
		AcceptedFromPettyCashOnCards = Number(Tab.Total("DocumentAmount"));
		ReceivedFromPettyCashByCardsInCurrency = Number(Tab.Total("DocumentAmountInCurrency"));
		
		TemplateArea = Template.GetArea("title");
		
		ExchangeDifference = 0;
		If Not (Header.DocumentCurrency = NationalCurrency) Then
			TemplateArea.Parameters.PresentationOfDocumentCurrency	= Header.PresentationOfCurrency;
			TemplateArea.Parameters.ReceivedFromPettyCashInCurrency			= ReceivedFromPettyCashInCurrency;
			TemplateArea.Parameters.ReceivedFromPettyCashInCurrencyByCards	= ReceivedFromPettyCashByCardsInCurrency;
		EndIf;
		
		TotalReceived = AcceptedFromPettyCash + AcceptedFromPettyCashOnCards;
		
		Query = New Query(
		"SELECT
		|	EmployeesSliceLast.StructuralUnit,
		|	EmployeesSliceLast.Position,
		|	EmployeesSliceLast.Employee.Code AS EmployeeCode,
		|	IndividualsDescriptionFull.Surname AS Surname,
		|	IndividualsDescriptionFull.Name AS Name,
		|	IndividualsDescriptionFull.Patronymic AS Patronymic,
		|	EmployeesSliceLast.Employee.Presentation AS Presentation
		|FROM
		|	InformationRegister.Employees.SliceLast(
		|			&ToDate,
		|			Company = &Company
		|				AND Employee = &Employee) AS EmployeesSliceLast,
		|	InformationRegister.IndividualsDescriptionFull.SliceLast(&ToDate, Ind = &Ind) AS IndividualsDescriptionFull");
		
		Query.SetParameter("ToDate", Header.DocumentDate);
		Query.SetParameter("Ind", Header.Ind);
		Query.SetParameter("Employee", Header.AdvanceHolder);
		Query.SetParameter("Company", Counterparty);
		
		QueryResult = Query.Execute();
		If QueryResult.IsEmpty() Then
			AdvanceHolder   = Header.AdvanceHolder;
			AccountablePersonFrom = Header.AdvanceHolder;
			EmployeeCode    = Header.AdvanceHolder.Code;
			Division     = Catalogs.StructuralUnits.EmptyRef();
			Position         = Catalogs.Positions.EmptyRef();
		Else
			DataReportingPerson = QueryResult.Unload()[0];
			If ValueIsFilled(DataReportingPerson.Surname) Then
				AdvanceHolder   = SmallBusinessServer.GetSurnameNamePatronymic(DataReportingPerson.Surname, DataReportingPerson.Name, DataReportingPerson.Patronymic);
			Else
				AdvanceHolder   = DataReportingPerson.Presentation;
			EndIf;
			AccountablePersonFrom = AdvanceHolder;
			EmployeeCode    = DataReportingPerson.EmployeeCode;
			Division     = DataReportingPerson.StructuralUnit;
			Position         = DataReportingPerson.Position;
		EndIf; 
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
		
		// Displaying title page of expense report
		TemplateArea.Parameters.Fill(Header);
		If TemplateName = "ExpenseReportInCurrency" Then
			TemplateArea.Parameters.AccountingCurrency						= Header.DocumentCurrency;
		EndIf;
		TemplateArea.Parameters.PresentationOfAccountablePerson		= AdvanceHolder;
		TemplateArea.Parameters.AdvanceHolderPresentationOf		= AccountablePersonFrom;
		TemplateArea.Parameters.EmployeeCode						= EmployeeCode;
		TemplateArea.Parameters.DivisionsPresentation			= Division;
		TemplateArea.Parameters.DivisionCode					= ?(NOT ValueIsFilled(Division), "", Division.Code);
		TemplateArea.Parameters.PositionOfAccountablePersonPresentation = Position;
		TemplateArea.Parameters.DocumentNumber						= DocumentNumber;
		TemplateArea.Parameters.AcceptedFromPettyCash						= AcceptedFromPettyCash;
		TemplateArea.Parameters.AcceptedFromPettyCashOnCards				= AcceptedFromPettyCashOnCards;
		
		If AmountBeforeDocument >= 0 Then
			TemplateArea.Parameters.OpeningBalance    =   AmountBeforeDocument;
		Else
			TemplateArea.Parameters.InitialSurcharge = - AmountBeforeDocument;
		EndIf;
		
		TemplateArea.Parameters.TotalReceived = TotalReceived;
		Spent = ?(InForeignCurrency, Header.DocumentAmountInNatCurrency, Header.DocumentAmount);
		TemplateArea.Parameters.Spent = Spent;
		
		BalanceAtTheEnd = AmountBeforeDocument + TotalReceived - Spent;
		If BalanceAtTheEnd >= 0  Then
			TemplateArea.Parameters.ClosingBalance    = BalanceAtTheEnd;
		Else
			TemplateArea.Parameters.FinalOverrun = - BalanceAtTheEnd;
		EndIf;
		
		InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Counterparty, Header.DocumentDate);
		CompanyPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
		
		Heads	= SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Header.Heads, Header.DocumentDate);
		Head	= Heads.HeadDescriptionFull;
		Accountant		= Heads.ChiefAccountantNameAndSurname;
		Cashier			= Heads.CashierNameAndSurname;
		
		If TemplateName = "ExpenseReportInCurrency" Then
			
			ForCalculation 									= Header.DocumentAmount;
			TemplateArea.Parameters.SpentUSD	= ForCalculation;
			ForCurrencyInWords 							= Header.DocumentCurrency;
			
		Else
			
			ForCalculation		= Header.DocumentAmountInNatCurrency;
			
			UsedAmount		= Round(ForCalculation, 2, 1);
			WholeAmount		= Int(ForCalculation);
			CentsAmount		= 100 * (Round(UsedAmount - WholeAmount, 2, 1));
			If CentsAmount = 0 Then
				CentsAmount = "00";
			EndIf;
			
			TemplateArea.Parameters.SpentUSD	= WholeAmount;
			TemplateArea.Parameters.SpentCent	= CentsAmount;
			
			TemplateArea.Parameters.CompanyByOKPO	= InfoAboutCompany.CodeByOKPO;
			ForCurrencyInWords 							= NationalCurrency;
			
		EndIf;
		
		TemplateArea.Parameters.DocumentDate		= Header.DocumentDate;
		
		TemplateArea.Parameters.Head		= Head;
		TemplateArea.Parameters.ChiefAccountant	= Accountant;
		
		ReportAmountInWords = WorkWithCurrencyRates.GenerateAmountInWords(ForCalculation, ForCurrencyInWords);
		If Not InForeignCurrency Then
			ReportAmountInWords = ReportAmountInWords + " (" + WholeAmount + " USD " + CentsAmount + " cop.)";
		EndIf;
		
		TemplateArea.Parameters.ReportAmountInWords = ReportAmountInWords;
		
		TemplateArea.Parameters.CompanyPresentation			= CompanyPresentation;
		TemplateArea.Parameters.PresentationOfChiefAccountant		= Accountant;
		TemplateArea.Parameters.Cashier								= Cashier;
		TemplateArea.Parameters.HeadPresentation			= Head;
		TemplateArea.Parameters.HeadPostPresentation	= Heads.HeadPosition;
		
		If (NOT InForeignCurrency AND Constants.AccountingCurrency.Get() = NationalCurrency)
			OR InForeignCurrency Then
		 
			QueryByAccountingRecords = New Query();
			QueryByAccountingRecords.SetParameter("Ref", 					CurrentDocument);
			QueryByAccountingRecords.SetParameter("ConvertIntoNatCurrency",	Not InForeignCurrency);
			QueryByAccountingRecords.SetParameter("ExchangeRate", 					Header.ExchangeRate);
			QueryByAccountingRecords.SetParameter("Multiplicity", 				Header.Multiplicity);
			QueryByAccountingRecords.Text = 
			"SELECT TOP 8
			|	Managerial.AccountDr.Code AS AccountDr,
			|	Managerial.AccountCr.Code AS AccountCr,
			|	SUM(Managerial.Amount) AS AmountInCurrency,
			|	SUM(CASE
			|			WHEN &ConvertIntoNatCurrency
			|				THEN CAST(Managerial.Amount * &ExchangeRate / &Multiplicity AS NUMBER(15, 2))
			|			ELSE Managerial.Amount
			|		END) AS Amount,
			|	MIN(Managerial.LineNumber) AS LineNumber
			|FROM
			|	AccountingRegister.Managerial AS Managerial
			|WHERE
			|	Managerial.Recorder = &Ref
			|	AND Not Managerial.AccountDr.OffBalance
			|	AND Managerial.PlanningPeriod = VALUE(Catalog.PlanningPeriods.Actual)
			|
			|GROUP BY
			|	Managerial.AccountDr.Code,
			|	Managerial.AccountCr.Code
			|
			|ORDER BY
			|	LineNumber";
			AccountingRecordsSelection = QueryByAccountingRecords.Execute().Select();
			
			Counter = 0;
			While AccountingRecordsSelection.Next() Do
				
				TemplateArea.Parameters["SubAccountDebit"  + (Counter + 1)] = AccountingRecordsSelection.AccountDr;
				TemplateArea.Parameters["DebitAmount"    + (Counter + 1)] = AccountingRecordsSelection.Amount;
				TemplateArea.Parameters["SubAccountCredit" + (Counter + 1)] = AccountingRecordsSelection.AccountCr;
				TemplateArea.Parameters["AmountOfCredit"   + (Counter + 1)] = AccountingRecordsSelection.Amount;
				
				Counter = Counter + 1;
				
			EndDo;
			
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		SpreadsheetDocument.PutHorizontalPageBreak();
		
		// Back page
		
		Inventory = Header.Inventory.Select();
		Expenses = Header.Expenses.Select();
		Payments = Header.Payments.Select();
		
		TemplateArea = Template.GetArea("Header");
		If TemplateName = "ExpenseReportInCurrency" Then
			TemplateArea.Parameters.DocumentCurrency = Header.DocumentCurrency;
		EndIf; 
		SpreadsheetDocument.Put(TemplateArea);
		
		// Display tabular sections
		TemplateArea			= Template.GetArea("String");
		LineNumber				= 0;
		TotalByReport			= 0;
		TotalByReportInCurrency	= 0;
		
		While Inventory.Next() Do
			
			TemplateArea.Parameters.Fill(Inventory);
			LineNumber = LineNumber + 1;
			TemplateArea.Parameters.LineNumber         = LineNumber;
			If ValueIsFilled(Inventory.Content) Then
				TemplateArea.Parameters.ExpeditureName = Inventory.Content;
			Else
				TemplateArea.Parameters.ExpeditureName = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(
					Inventory.InventoryItemDescription,
					Inventory.Characteristic,
					Inventory.SKU
				);
			EndIf;
			
			Amount = ?((NOT InForeignCurrency) AND (NOT Header.DocumentCurrency = NationalCurrency), 
							Round(Inventory.Total * Header.ExchangeRate / Header.Multiplicity, 2), 
								Inventory.Total);
			
			TemplateArea.Parameters.ByReport = Amount;
			TemplateArea.Parameters.ByAccounting  = Amount;
			
			TotalByReport = TotalByReport + Amount;
			
			If Not (NationalCurrency = Header.DocumentCurrency) Then
			
				AmountInCurrency = Inventory.Total;
				
				TemplateArea.Parameters.ByAccountingInCurrency  = AmountInCurrency;
				TemplateArea.Parameters.ByReportInCurrency = AmountInCurrency;
				
				TotalByReportInCurrency = TotalByReportInCurrency + AmountInCurrency;
				
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
			
		EndDo;
		
		LineNumber = ?(ValueIsFilled(Inventory.LineNumber), Inventory.LineNumber, 0);
		
		While Expenses.Next() Do
		
			TemplateArea.Parameters.Fill(Expenses);
			LineNumber = LineNumber + 1;
			TemplateArea.Parameters.LineNumber         = LineNumber;
			If ValueIsFilled(Expenses.Content) Then
				TemplateArea.Parameters.ExpeditureName = Expenses.Content;
			Else
				TemplateArea.Parameters.ExpeditureName = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(
					Expenses.ExpenseDescription,
					,
					Expenses.SKU
				);
			EndIf;
				
			Amount = ?((NOT InForeignCurrency) AND (NOT Header.DocumentCurrency = NationalCurrency), 
							Round(Expenses.Total * Header.ExchangeRate / Header.Multiplicity, 2), 
									Expenses.Total);
			
			TemplateArea.Parameters.ByReport = Amount;
			TemplateArea.Parameters.ByAccounting  = Amount;
			
			TotalByReport = TotalByReport + Amount;
			
			If Not (NationalCurrency = Header.DocumentCurrency) Then
			
				AmountInCurrency = Expenses.Total;
				
				TemplateArea.Parameters.ByAccountingInCurrency  = AmountInCurrency;
				TemplateArea.Parameters.ByReportInCurrency = AmountInCurrency;
				
				TotalByReportInCurrency = TotalByReportInCurrency + AmountInCurrency;
				
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
			
		EndDo;
		
		While Payments.Next() Do
		
			TemplateArea.Parameters.Fill(Payments);
			LineNumber = LineNumber + 1;
			TemplateArea.Parameters.LineNumber = LineNumber;
			Amount = ?(InForeignCurrency, 
						Round(Payments.PaymentAmount * Header.ExchangeRate / Header.Multiplicity, 2), 
							Payments.PaymentAmount);
			TemplateArea.Parameters.ExpeditureName = NStr("en = 'Payment to counterparty '") + Payments.Counterparty;
			
			TemplateArea.Parameters.ByReport = Amount;
			TemplateArea.Parameters.ByAccounting  = Amount;
			
			TotalByReport = TotalByReport + Amount;
			
			If Not (NationalCurrency = Header.DocumentCurrency) Then
			
				AmountInCurrency = Payments.PaymentAmount;
				
				TemplateArea.Parameters.ByAccountingInCurrency  = AmountInCurrency;
				TemplateArea.Parameters.ByReportInCurrency = AmountInCurrency;
				
				TotalByReportInCurrency = TotalByReportInCurrency + AmountInCurrency;
				
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
			
		EndDo;
		
		// Displaying expense report footer
		TemplateArea = Template.GetArea("Footer");
		TemplateArea.Parameters.Fill(Header);
		TemplateArea.Parameters.PresentationOfAccountablePerson = AdvanceHolder;
		TemplateArea.Parameters.TotalByReport        = TotalByReport;
		TemplateArea.Parameters.TotalByReportinCurrency = TotalByReportInCurrency;
		TemplateArea.Parameters.TotalByAccounting         = TotalByReport;
		TemplateArea.Parameters.TotalByAccountinginCurrency  = TotalByReportInCurrency;
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	SetPrivilegedMode(False);
	
	Return SpreadsheetDocument;
	
EndFunction // PrintForm()

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "ExpenseReport") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "ExpenseReport", "Expense report", PrintForm(ObjectsArray, PrintObjects, "ExpenseReport"));
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "ExpenseReportInCurrency") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "ExpenseReportInCurrency", "Expense report (cur.)", PrintForm(ObjectsArray, PrintObjects, "ExpenseReportInCurrency"));
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// ExpenseReport
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "ExpenseReport";
	PrintCommand.Presentation = NStr("en = 'Expense report'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	// ExpenseReport (in currency)
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "ExpenseReportInCurrency";
	PrintCommand.Presentation = NStr("en = 'Expense report (cur.)'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 4;
	
EndProcedure

#EndRegion

#EndIf