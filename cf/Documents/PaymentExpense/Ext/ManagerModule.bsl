#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssets(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("CashExpense", NStr("en='Cash expense';ru='Расход денежных средств:'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	&CashExpense AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	&Company AS Company,
	|	VALUE(Enum.CashAssetTypes.Noncash) AS CashAssetsType,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.BankAccount AS BankAccountPettyCash,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(CAST(DocumentTable.DocumentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.DocumentAmount) AS AmountCur,
	|	-SUM(CAST(DocumentTable.DocumentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))) AS AmountForBalance,
	|	-SUM(DocumentTable.DocumentAmount) AS AmountCurForBalance,
	|	DocumentTable.BankAccount.GLAccount AS GLAccount
	|INTO TemporaryTableCashAssets
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfPettyCashe
	|		ON DocumentTable.CashCurrency = CurrencyRatesOfPettyCashe.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToAdvanceHolder)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Other)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Taxes))
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Item,
	|	DocumentTable.BankAccount,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.BankAccount.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePaymentDetails.LineNumber,
	|	&CashExpense,
	|	VALUE(AccumulationRecordType.Expense),
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	VALUE(Enum.CashAssetTypes.Noncash),
	|	TemporaryTablePaymentDetails.Item,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	-SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	-SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	(TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Vendor)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.Item,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	MAX(PayrollPayment.LineNumber),
	|	&CashExpense,
	|	VALUE(AccumulationRecordType.Expense),
	|	PayrollPayment.Ref.Date,
	|	&Company,
	|	VALUE(Enum.CashAssetTypes.Noncash),
	|	PayrollPayment.Ref.Item,
	|	PayrollPayment.Ref.BankAccount,
	|	PayrollPayment.Ref.CashCurrency,
	|	SUM(CAST(PayrollSheetEmployees.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))),
	|	MIN(PayrollPayment.Ref.DocumentAmount),
	|	-SUM(CAST(PayrollSheetEmployees.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))),
	|	-MIN(PayrollPayment.Ref.DocumentAmount),
	|	PayrollPayment.Ref.BankAccount.GLAccount
	|FROM
	|	Document.PayrollSheet.Employees AS PayrollSheetEmployees
	|		INNER JOIN Document.PaymentExpense.PayrollPayment AS PayrollPayment
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfPettyCashe
	|			ON PayrollPayment.Ref.CashCurrency = CurrencyRatesOfPettyCashe.Currency
	|		ON PayrollSheetEmployees.Ref = PayrollPayment.Statement
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
	|WHERE
	|	PayrollPayment.Ref = &Ref
	|	AND PayrollPayment.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Salary)
	|
	|GROUP BY
	|	PayrollPayment.Ref.Date,
	|	PayrollPayment.Ref.Item,
	|	PayrollPayment.Ref.BankAccount,
	|	PayrollPayment.Ref.CashCurrency,
	|	PayrollPayment.Ref.BankAccount.GLAccount
	|
	|INDEX BY
	|	Company,
	|	CashAssetsType,
	|	BankAccountPettyCash,
	|	Currency,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text = 
	"SELECT
	|	TemporaryTableCashAssets.Company AS Company,
	|	TemporaryTableCashAssets.CashAssetsType AS CashAssetsType,
	|	TemporaryTableCashAssets.BankAccountPettyCash AS BankAccountPettyCash,
	|	TemporaryTableCashAssets.Currency AS Currency
	|FROM
	|	TemporaryTableCashAssets AS TemporaryTableCashAssets";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.CashAssets");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult IN QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = SmallBusinessServer.GetQueryTextExchangeRateDifferencesCashAssets(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashAssets", ResultsArray[QueryNumber].Unload());
	
EndProcedure // GenerateTableCashAssets()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateAdvanceHolderPaymentsTable(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AdvanceHolderDebtEmergence", NStr("en=""The emergence of the advance holder's debt"";ru='Возникновение долга подотчетника'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	&AdvanceHolderDebtEmergence AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.BankAccount AS BankAccount,
	|	CASE
	|		WHEN DocumentTable.Document = VALUE(Document.ExpenseReport.EmptyRef)
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END AS Document,
	|	DocumentTable.AdvanceHolder AS Employee,
	|	DocumentTable.Date AS Date,
	|	&Company AS Company,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(CAST(DocumentTable.DocumentAmount * SettlementsCurrencyRates.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.DocumentAmount) AS AmountCur,
	|	SUM(CAST(DocumentTable.DocumentAmount * SettlementsCurrencyRates.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2))) AS AmountForBalance,
	|	SUM(DocumentTable.DocumentAmount) AS AmountCurForBalance,
	|	CASE
	|		WHEN DocumentTable.Document = VALUE(Document.ExpenseReport.EmptyRef)
	|			THEN DocumentTable.AdvanceHolder.AdvanceHoldersGLAccount
	|		ELSE DocumentTable.AdvanceHolder.OverrunGLAccount
	|	END AS GLAccount
	|INTO TemporaryTableAdvanceHolderPayments
	|FROM
	|	Document.PaymentExpense AS DocumentTable
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
	|		ON DocumentTable.CashCurrency = SettlementsCurrencyRates.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToAdvanceHolder)
	|
	|GROUP BY
	|	DocumentTable.BankAccount,
	|	DocumentTable.AdvanceHolder,
	|	DocumentTable.Date,
	|	DocumentTable.CashCurrency,
	|	CASE
	|		WHEN DocumentTable.Document = VALUE(Document.ExpenseReport.EmptyRef)
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END,
	|	CASE
	|		WHEN DocumentTable.Document = VALUE(Document.ExpenseReport.EmptyRef)
	|			THEN DocumentTable.AdvanceHolder.AdvanceHoldersGLAccount
	|		ELSE DocumentTable.AdvanceHolder.OverrunGLAccount
	|	END
	|
	|INDEX BY
	|	Company,
	|	Employee,
	|	Currency,
	|	Document,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock of controlled balances of payments to accountable persons.
	Query.Text = 
	"SELECT
	|	TemporaryTableAdvanceHolderPayments.Company AS Company,
	|	TemporaryTableAdvanceHolderPayments.Employee AS Employee,
	|	TemporaryTableAdvanceHolderPayments.Currency AS Currency,
	|	TemporaryTableAdvanceHolderPayments.Document AS Document
	|FROM
	|	TemporaryTableAdvanceHolderPayments AS TemporaryTableAdvanceHolderPayments";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AdvanceHolderPayments");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult IN QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = SmallBusinessServer.GetQueryTextCurrencyExchangeRateAdvanceHolderPayments(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSettlementsWithAdvanceHolders", ResultsArray[QueryNumber].Unload());
	
EndProcedure // GenerateTableAdvanceHolderPayments()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfVendorAdvance", "Appearence of vendor advance");
	Query.SetParameter("VendorObligationsRepayment", "Repayment of obligations to vendor");
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|						THEN &Ref
	|					ELSE TemporaryTablePaymentDetails.Document
	|				END
	|		ELSE UNDEFINED
	|	END AS Document,
	|	&Company AS Company,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTablePaymentDetails.BankAccount AS BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount) AS PaymentAmount,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCur,
	|	-SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForBalance,
	|	-SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCurForBalance,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.VendorAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountVendorSettlements
	|	END AS GLAccount,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &AppearenceOfVendorAdvance
	|		ELSE &VendorObligationsRepayment
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Vendor)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|						THEN &Ref
	|					ELSE TemporaryTablePaymentDetails.Document
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.VendorAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountVendorSettlements
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &AppearenceOfVendorAdvance
	|		ELSE &VendorObligationsRepayment
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
	|	TemporaryTableAccountsPayable AS TemporaryTableAccountsPayable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsPayable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult IN QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = SmallBusinessServer.GetQueryTextExchangeRatesDifferencesAccountsPayable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure // GenerateTableAccountsPayable()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("CustomerAdvanceRepayment", NStr("en='Discharge of the customer advance';ru='Погашение аванса покупателя'"));
	Query.SetParameter("AppearenceOfCustomerLiability", NStr("en='Appearance of customer liabilities';ru='Возникновение обязательств покупателя'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByDocuments
	|			THEN TemporaryTablePaymentDetails.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	&Company AS Company,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryTablePaymentDetails.BankAccount AS BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS Order,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount) AS PaymentAmount,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCur,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForBalance,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCurForBalance,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.CustomerAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountCustomerSettlements
	|	END AS GLAccount,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &CustomerAdvanceRepayment
	|		ELSE &AppearenceOfCustomerLiability
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByDocuments
	|			THEN TemporaryTablePaymentDetails.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.CustomerAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountCustomerSettlements
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &CustomerAdvanceRepayment
	|		ELSE &AppearenceOfCustomerLiability
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
	|	TemporaryTableAccountsReceivable.Company AS Company,
	|	TemporaryTableAccountsReceivable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsReceivable.Contract AS Contract,
	|	TemporaryTableAccountsReceivable.Document AS Document,
	|	TemporaryTableAccountsReceivable.Order AS Order,
	|	TemporaryTableAccountsReceivable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsReceivable AS TemporaryTableAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsReceivable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult IN QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = SmallBusinessServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[QueryNumber].Unload());
	
EndProcedure // GenerateTableAccountsReceivable()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePayrollPayments(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("RepaymentLiabilitiesToEmployees", NStr("en='Employees obligations repayment';ru='Погашение обязательств перед персоналом'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	PayrollSheet.Ref
	|FROM
	|	Document.PayrollSheet AS PayrollSheet
	|WHERE
	|	PayrollSheet.Ref In
	|			(SELECT
	|				PayrollPayment.Statement
	|			FROM
	|				Document.PaymentExpense.PayrollPayment AS PayrollPayment
	|			WHERE
	|				PayrollPayment.Ref = &Ref)";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("Document.PayrollSheet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	"SELECT
	|	MAX(PayrollPayment.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	PayrollPayment.Ref.Date AS Date,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	PayrollSheetEmployees.Ref.StructuralUnit AS StructuralUnit,
	|	PayrollSheetEmployees.Employee AS Employee,
	|	PayrollSheetEmployees.Ref.SettlementsCurrency AS Currency,
	|	PayrollSheetEmployees.Ref.RegistrationPeriod AS RegistrationPeriod,
	|	SUM(CAST(PayrollSheetEmployees.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(PayrollSheetEmployees.SettlementsAmount) AS AmountCur,
	|	-SUM(CAST(PayrollSheetEmployees.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))) AS AmountForBalance,
	|	-SUM(PayrollSheetEmployees.SettlementsAmount) AS AmountCurForBalance,
	|	PayrollSheetEmployees.Employee.SettlementsHumanResourcesGLAccount AS GLAccount,
	|	&RepaymentLiabilitiesToEmployees AS ContentOfAccountingRecord,
	|	PayrollPayment.Ref.BankAccount AS BankAccount
	|INTO TemporaryTablePayrollPayments
	|FROM
	|	Document.PayrollSheet.Employees AS PayrollSheetEmployees
	|		INNER JOIN Document.PaymentExpense.PayrollPayment AS PayrollPayment
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfPettyCashe
	|			ON PayrollPayment.Ref.CashCurrency = CurrencyRatesOfPettyCashe.Currency
	|		ON PayrollSheetEmployees.Ref = PayrollPayment.Statement
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
	|WHERE
	|	PayrollPayment.Ref = &Ref
	|	AND PayrollPayment.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Salary)
	|
	|GROUP BY
	|	PayrollPayment.Ref.Date,
	|	PayrollSheetEmployees.Ref.StructuralUnit,
	|	PayrollSheetEmployees.Employee,
	|	PayrollSheetEmployees.Ref.SettlementsCurrency,
	|	PayrollSheetEmployees.Ref.RegistrationPeriod,
	|	PayrollSheetEmployees.Employee.SettlementsHumanResourcesGLAccount,
	|	PayrollPayment.Ref.BankAccount
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Employee,
	|	Currency,
	|	RegistrationPeriod,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of settlements with suppliers.
	Query.Text =
	"SELECT
	|	TemporaryTablePayrollPayments.Company AS Company,
	|	TemporaryTablePayrollPayments.StructuralUnit AS StructuralUnit,
	|	TemporaryTablePayrollPayments.Employee AS Employee,
	|	TemporaryTablePayrollPayments.Currency AS Currency,
	|	TemporaryTablePayrollPayments.RegistrationPeriod AS RegistrationPeriod
	|FROM
	|	TemporaryTablePayrollPayments AS TemporaryTablePayrollPayments";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.PayrollPayments");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = SmallBusinessServer.GetQueryTextExchangeRateDifferencesPayrollPayments(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePayrollPayments", ResultsArray[QueryNumber].Unload());
	
EndProcedure // GenerateTablePayrollPayments()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("CostsReflection", NStr("en='Costs reflection';ru='Отражение расходов'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN DocumentTable.Department
	|		ELSE UNDEFINED
	|	END AS StructuralUnit,
	|	CASE
	|		WHEN DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS CustomerOrder,
	|	CASE
	|		WHEN DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN DocumentTable.BusinessActivity
	|		ELSE VALUE(Catalog.BusinessActivities.Other)
	|	END AS BusinessActivity,
	|	DocumentTable.Correspondence AS GLAccount,
	|	&CostsReflection AS ContentOfAccountingRecord,
	|	0 AS AmountIncome,
	|	CAST(DocumentTable.DocumentAmount * SettlementsCurrencyRates.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2)) AS AmountExpense,
	|	CAST(DocumentTable.DocumentAmount * SettlementsCurrencyRates.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2)) AS Amount
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS SettlementsCurrencyRates
	|		ON DocumentTable.CashCurrency = SettlementsCurrencyRates.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			OR DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses))
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Other)
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.BusinessActivities.Other),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END
	|FROM
	|	TemporaryTableExchangeRateLossesBanking AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.BusinessActivities.Other),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END
	|FROM
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.BusinessActivities.Other),
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
	|UNION ALL
	|
	|SELECT
	|	5,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.BusinessActivities.Other),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END
	|FROM
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.BusinessActivities.Other),
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
	|	TemporaryTableExchangeDifferencesPayrollPayments AS DocumentTable
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	Query.SetParameter("Content", NStr("en='Write-off of the cash to any account';ru='Списание денежных средств на произвольный счет'"));
	Query.SetParameter("TaxPay", NStr("en='Tax payment';ru='Оплата налога'"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.Correspondence AS AccountDr,
	|	DocumentTable.BankAccount.GLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.DocumentAmount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.DocumentAmount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.DocumentAmount * SettlementsCurrencyRates.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	CAST(&Content AS String(100)) AS Content
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS SettlementsCurrencyRates
	|		ON DocumentTable.CashCurrency = SettlementsCurrencyRates.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Other)
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.TaxKind.GLAccount,
	|	DocumentTable.BankAccount.GLAccount,
	|	CASE
	|		WHEN DocumentTable.TaxKind.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.TaxKind.GLAccount.Currency
	|			THEN DocumentTable.DocumentAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.DocumentAmount
	|		ELSE 0
	|	END,
	|	CAST(DocumentTable.DocumentAmount * SettlementsCurrencyRates.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2)),
	|	CAST(&TaxPay AS String(100))
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS SettlementsCurrencyRates
	|		ON DocumentTable.CashCurrency = SettlementsCurrencyRates.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Taxes)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.BankAccount.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord
	|FROM
	|	TemporaryTableAdvanceHolderPayments AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
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
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
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
	|	5,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.BankAccount.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord
	|FROM
	|	TemporaryTableAccountsReceivable AS DocumentTable
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
	|			THEN DocumentTable.GLAccount
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference
	|FROM
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	7,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.BankAccount.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord
	|FROM
	|	TemporaryTableAccountsPayable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	8,
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
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
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
	|SELECT
	|	9,
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
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference
	|FROM
	|	TemporaryTableExchangeRateLossesBanking AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	10,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.BankAccount.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord
	|FROM
	|	TemporaryTablePayrollPayments AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	11,
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
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference
	|FROM
	|	TemporaryTableExchangeDifferencesPayrollPayments AS DocumentTable
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";

	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", QueryResult.Unload());
	
EndProcedure // GenerateTableManagerial()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	UNDEFINED AS BusinessActivity,
	|	DocumentTable.Item AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.AccountingAmount AS AmountExpense
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Vendor)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.BusinessActivity,
	|	Table.Item,
	|	0,
	|	Table.AmountExpense
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|WHERE
	|	Table.AmountExpense > 0
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	&Company,
	|	CASE
	|		WHEN DocumentTable.BusinessActivity <> VALUE(Catalog.BusinessActivities.EmptyRef)
	|			THEN DocumentTable.BusinessActivity
	|		ELSE VALUE(Catalog.BusinessActivities.Other)
	|	END,
	|	DocumentTable.Item,
	|	0,
	|	CAST(DocumentTable.DocumentAmount * SettlementsCurrencyRates.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2))
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS SettlementsCurrencyRates
	|		ON DocumentTable.CashCurrency = SettlementsCurrencyRates.Currency
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Salary)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Taxes))
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	&Company,
	|	UNDEFINED,
	|	DocumentTable.Item,
	|	-DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.BusinessActivity,
	|	Table.Item,
	|	-Table.AmountIncome,
	|	0
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|WHERE
	|	Table.AmountIncome > 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesCashMethod()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesUndistributed(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.AccountingAmount AS AmountExpense
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Vendor)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.Item,
	|	-DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer)
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesUndistributed", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesUndistributed()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
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
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Vendor)
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
	|							TemporaryTablePaymentDetails AS DocumentTable
	|						WHERE
	|							(DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Vendor)
	|								OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer)))) AS IncomeAndExpensesRetainedBalances
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
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer)
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
	|	Table.AmountIncome AS AmountIncome,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessActivity AS BusinessActivity
	|INTO TemporaryTableTableDeferredIncomeAndExpenditure
	|FROM
	|	&Table AS Table
	|WHERE
	|	(Table.AmountIncome > 0
	|			OR Table.AmountExpense > 0)";
	
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
	|	-Table.AmountIncome AS AmountIncome,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessActivity AS BusinessActivity
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesUndistributed()  

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableTaxesSettlements(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", 		DocumentRefPaymentExpense);
	Query.SetParameter("AccountingCurrency",	Constants.AccountingCurrency.Get());
	Query.SetParameter("DocumentCurrency",DocumentRefPaymentExpense.CashCurrency);
	Query.SetParameter("Company",	StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",	New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("TaxPay",	NStr("en='Tax payment';ru='Оплата налога'"));
	
	Query.Text =
	"SELECT
	|	CurrencyRatesSliceLast.Currency AS Currency,
	|	CurrencyRatesSliceLast.ExchangeRate AS ExchangeRate,
	|	CurrencyRatesSliceLast.Multiplicity AS Multiplicity
	|INTO CurrencyRates
	|FROM
	|	InformationRegister.CurrencyRates.SliceLast(&PointInTime, Currency IN (&AccountingCurrency, &DocumentCurrency)) AS CurrencyRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	DocumentTable.TaxKind AS TaxKind,
	|	CAST(DocumentTable.DocumentAmount * DocumentCurrencyRate.ExchangeRate * AccountingCurrencyRate.Multiplicity / (AccountingCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	DocumentTable.TaxKind.GLAccount AS GLAccount,
	|	&TaxPay AS ContentOfAccountingRecord
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN CurrencyRates AS DocumentCurrencyRate
	|		ON DocumentTable.CashCurrency = DocumentCurrencyRate.Currency
	|		LEFT JOIN CurrencyRates AS AccountingCurrencyRate
	|		ON (AccountingCurrencyRate.Currency = &AccountingCurrency)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Taxes)";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxAccounting", QueryResult.Unload());
	
EndProcedure // GenerateTableTaxesSettlements()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePaymentCalendar(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UsePaymentCalendar", Constants.FunctionalOptionPaymentCalendar.Get());
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Item AS Item,
	|	VALUE(Enum.CashAssetTypes.Noncash) AS CashAssetsType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	DocumentTable.BankAccount AS BankAccountPettyCash,
	|	CASE
	|		WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE DocumentTable.CashCurrency
	|	END AS Currency,
	|	DocumentTable.InvoiceForPaymentToPaymentCalendar AS InvoiceForPayment,
	|	SUM(CASE
	|			WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|				THEN -DocumentTable.SettlementsAmount
	|			ELSE -DocumentTable.PaymentAmount
	|		END) AS PaymentAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.OperationKind <> VALUE(Enum.OperationKindsPaymentExpense.Salary)
	|
	|GROUP BY
	|	DocumentTable.Item,
	|	DocumentTable.Date,
	|	DocumentTable.BankAccount,
	|	CASE
	|		WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE DocumentTable.CashCurrency
	|	END,
	|	DocumentTable.InvoiceForPaymentToPaymentCalendar
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	MAX(DocumentTable.LineNumber),
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	DocumentTable.Ref.Item,
	|	VALUE(Enum.CashAssetTypes.Noncash),
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	DocumentTable.Ref.BankAccount,
	|	DocumentTable.Ref.CashCurrency,
	|	DocumentTable.PlanningDocument,
	|	SUM(-DocumentTable.PaymentAmount)
	|FROM
	|	Document.PaymentExpense.PayrollPayment AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Salary)
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.PlanningDocument,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Item,
	|	DocumentTable.Ref.BankAccount,
	|	DocumentTable.Ref.CashCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.Item,
	|	VALUE(Enum.CashAssetTypes.Noncash),
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	DocumentTable.BankAccount,
	|	DocumentTable.CashCurrency,
	|	UNDEFINED,
	|	-DocumentTable.DocumentAmount
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN (SELECT
	|			COUNT(ISNULL(TemporaryTablePaymentDetails.LineNumber, 0)) AS Quantity
	|		FROM
	|			TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails) AS NestedSelect
	|		ON (TRUE)
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.Ref = &Ref
	|	AND NestedSelect.Quantity = 0
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure // GenerateTablePaymentCalendar()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.InvoiceForPayment AS InvoiceForPayment,
	|	SUM(CASE
	|			WHEN Not DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN DocumentTable.CashCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.PaymentAmount
	|			WHEN DocumentTable.SettlementsCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer)
	|			THEN -1
	|		ELSE 1
	|	END AS AdvanceAmount,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN DocumentTable.CashCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.PaymentAmount
	|			WHEN DocumentTable.SettlementsCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer)
	|			THEN -1
	|		ELSE 1
	|	END AS PaymentAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfAccount
	|		ON DocumentTable.InvoiceForPayment.DocumentCurrency = CurrencyRatesOfAccount.Currency
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfPettyCashe
	|		ON DocumentTable.CashCurrency = CurrencyRatesOfPettyCashe.Currency
	|WHERE
	|	DocumentTable.TrackPaymentsByBills
	|	AND DocumentTable.InvoiceForPayment <> VALUE(Document.InvoiceForPayment.EmptyRef)
	|	AND DocumentTable.InvoiceForPayment <> VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
	|	AND DocumentTable.InvoiceForPayment <> UNDEFINED
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Vendor)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer))
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.InvoiceForPayment,
	|	DocumentTable.OperationKind
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.Order,
	|	SUM(CASE
	|			WHEN Not DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN DocumentTable.CashCurrency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.PaymentAmount
	|			WHEN DocumentTable.SettlementsCurrency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer)
	|			THEN -1
	|		ELSE 1
	|	END,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN DocumentTable.CashCurrency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.PaymentAmount
	|			WHEN DocumentTable.SettlementsCurrency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer)
	|			THEN -1
	|		ELSE 1
	|	END
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfAccount
	|		ON DocumentTable.Order.DocumentCurrency = CurrencyRatesOfAccount.Currency
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfPettyCashe
	|		ON DocumentTable.CashCurrency = CurrencyRatesOfPettyCashe.Currency
	|WHERE
	|	DocumentTable.TrackPaymentsByBills
	|	AND (VALUETYPE(DocumentTable.Order) = Type(Document.CustomerOrder)
	|				AND DocumentTable.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			OR VALUETYPE(DocumentTable.Order) = Type(Document.PurchaseOrder)
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef))
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Vendor)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer))
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Order,
	|	DocumentTable.OperationKind
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure // GenerateTableInvoicesAndOrdersPayment()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefPaymentExpense, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	Query.SetParameter("CashCurrency", DocumentRefPaymentExpense.CashCurrency);
	
	Query.Text =
	"SELECT
	|	CurrencyRatesSliceLast.Currency AS Currency,
	|	CurrencyRatesSliceLast.ExchangeRate AS ExchangeRate,
	|	CurrencyRatesSliceLast.Multiplicity AS Multiplicity
	|INTO TemporaryTableCurrencyRatesSliceLatest
	|FROM
	|	InformationRegister.CurrencyRates.SliceLast(&PointInTime, Currency IN (&AccountingCurrency, &CashCurrency)) AS CurrencyRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Ref.CashCurrency AS CashCurrency,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	DocumentTable.Ref.Counterparty AS Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentTable.Ref.BankAccount AS BankAccount,
	|	DocumentTable.Ref.Item AS Item,
	|	DocumentTable.Ref.Correspondence AS Correspondence,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer)
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Vendor)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Vendor)
	|				AND DocumentTable.Order = VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END AS Order,
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	DocumentTable.Ref.Date AS Date,
	|	SUM(CAST(DocumentTable.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))) AS AccountingAmount,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.PaymentAmount) AS PaymentAmount,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = Type(Document.CashOutflowPlan)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.CashOutflowPlan.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = Type(Document.CashTransferPlan)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.CashTransferPlan.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN DocumentTable.InvoiceForPayment.SchedulePayment
	|			THEN DocumentTable.InvoiceForPayment
	|		WHEN DocumentTable.Order.SchedulePayment
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS InvoiceForPaymentToPaymentCalendar,
	|	DocumentTable.InvoiceForPayment AS InvoiceForPayment,
	|	DocumentTable.Ref.BankAccount.GLAccount AS BankAccountCashGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount AS VendorAdvancesGLAccount
	|INTO TemporaryTablePaymentDetails
	|FROM
	|	Document.PaymentExpense.PaymentDetails AS DocumentTable
	|		LEFT JOIN TemporaryTableCurrencyRatesSliceLatest AS AccountingCurrencyRates
	|		ON (AccountingCurrencyRates.Currency = &AccountingCurrency)
	|		LEFT JOIN TemporaryTableCurrencyRatesSliceLatest AS CurrencyRatesOfPettyCashe
	|		ON (CurrencyRatesOfPettyCashe.Currency = &CashCurrency)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref.CashCurrency,
	|	DocumentTable.Document,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Ref.BankAccount,
	|	DocumentTable.Ref.Item,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer)
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Vendor)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.ToCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Vendor)
	|				AND DocumentTable.Order = VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Date,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = Type(Document.CashOutflowPlan)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.CashOutflowPlan.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = Type(Document.CashTransferPlan)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.CashTransferPlan.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN DocumentTable.InvoiceForPayment.SchedulePayment
	|			THEN DocumentTable.InvoiceForPayment
	|		WHEN DocumentTable.Order.SchedulePayment
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.InvoiceForPayment,
	|	DocumentTable.Ref.BankAccount.GLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills";
	
	Query.Execute();
	
	// Register record table creation by account sections.
	GenerateTableCashAssets(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateAdvanceHolderPaymentsTable(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTablePayrollPayments(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableTaxesSettlements(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableManagerial(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesUndistributed(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefPaymentExpense, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefPaymentExpense, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.ControlBalancesOnPosting.Get() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsCashAssetsChange
	 OR StructureTemporaryTables.RegisterRecordsAdvanceHolderPaymentsChange
	 OR StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsCashAssetsChange.LineNumber AS LineNumber,
		|	RegisterRecordsCashAssetsChange.Company AS CompanyPresentation,
		|	RegisterRecordsCashAssetsChange.BankAccountPettyCash AS BankAccountCashPresentation,
		|	RegisterRecordsCashAssetsChange.Currency AS CurrencyPresentation,
		|	RegisterRecordsCashAssetsChange.CashAssetsType AS CashAssetsTypeRepresentation,
		|	RegisterRecordsCashAssetsChange.CashAssetsType AS CashAssetsType,
		|	ISNULL(CashAssetsBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(CashAssetsBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsCashAssetsChange.SumCurChange + ISNULL(CashAssetsBalances.AmountCurBalance, 0) AS BalanceCashAssets,
		|	RegisterRecordsCashAssetsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsCashAssetsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsCashAssetsChange.AmountChange AS AmountChange,
		|	RegisterRecordsCashAssetsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsCashAssetsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsCashAssetsChange.SumCurChange AS SumCurChange
		|FROM
		|	RegisterRecordsCashAssetsChange AS RegisterRecordsCashAssetsChange
		|		LEFT JOIN AccumulationRegister.CashAssets.Balance(&ControlTime, ) AS CashAssetsBalances
		|		ON RegisterRecordsCashAssetsChange.Company = CashAssetsBalances.Company
		|			AND RegisterRecordsCashAssetsChange.CashAssetsType = CashAssetsBalances.CashAssetsType
		|			AND RegisterRecordsCashAssetsChange.BankAccountPettyCash = CashAssetsBalances.BankAccountPettyCash
		|			AND RegisterRecordsCashAssetsChange.Currency = CashAssetsBalances.Currency
		|WHERE
		|	ISNULL(CashAssetsBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsAdvanceHolderPaymentsChange.LineNumber AS LineNumber,
		|	RegisterRecordsAdvanceHolderPaymentsChange.Company AS CompanyPresentation,
		|	RegisterRecordsAdvanceHolderPaymentsChange.Employee AS EmployeePresentation,
		|	RegisterRecordsAdvanceHolderPaymentsChange.Currency AS CurrencyPresentation,
		|	RegisterRecordsAdvanceHolderPaymentsChange.Document AS DocumentPresentation,
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
		|		LEFT JOIN AccumulationRegister.AdvanceHolderPayments.Balance(&ControlTime, ) AS AdvanceHolderPaymentsBalances
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
		|	RegisterRecordsSuppliersSettlementsChange.Company AS CompanyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Contract AS ContractPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency AS CurrencyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Document AS DocumentPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Order AS OrderPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS CalculationsTypesPresentation,
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
		|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(&ControlTime, ) AS AccountsPayableBalances
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
			OR Not ResultsArray[2].IsEmpty() Then
			DocumentObjectPaymentExpense = DocumentRefPaymentExpense.GetObject()
		EndIf;
		
		// Negative balance on cash.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObjectPaymentExpense, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on advance holder payments.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToAdvanceHolderPaymentsRegisterErrors(DocumentObjectPaymentExpense, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			SmallBusinessServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectPaymentExpense, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure // RunControl()

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