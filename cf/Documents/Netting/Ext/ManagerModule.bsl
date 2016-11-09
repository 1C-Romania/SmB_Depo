#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefNetting, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefNetting);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	&Company AS Company,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Currency AS Currency,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS Order,
	|	DocumentTable.SettlementsType AS SettlementsType,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.Date AS Date,
	|	SUM(DocumentTable.AccountingAmount) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	SUM(DocumentTable.AccountingAmountBalance) AS AmountForBalance,
	|	SUM(DocumentTable.SettlementsAmountBalance) AS AmountCurForBalance
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableCustomers AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.ContentOfAccountingRecord,
	|	DocumentTable.RecordType,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Currency,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.GLAccount,
	|	DocumentTable.Date,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
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
	|	TemporaryTableAccountsReceivable";
	
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
Procedure GenerateTableAccountsPayable(DocumentRefNetting, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefNetting);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	&Company AS Company,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Currency AS Currency,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentTable.SettlementsType AS SettlementsType,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.Date AS Date,
	|	SUM(DocumentTable.AccountingAmount) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	SUM(DocumentTable.AccountingAmountBalance) AS AmountForBalance,
	|	SUM(DocumentTable.SettlementsAmountBalance) AS AmountCurForBalance
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTableVendors AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.ContentOfAccountingRecord,
	|	DocumentTable.RecordType,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Currency,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.GLAccount,
	|	DocumentTable.Date,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
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
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure // GenerateTableAccountsPayable()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
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
	|			WHEN (NOT DocumentTable.AdvanceFlag)
	|				THEN 0
	|			WHEN Constants.AccountingCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.AccountingAmount
	|			WHEN DocumentTable.Currency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.SettlementsAmount * SettlementsCurrencyRates.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END AS AdvanceAmount,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN Constants.AccountingCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.AccountingAmount
	|			WHEN DocumentTable.Currency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.SettlementsAmount * SettlementsCurrencyRates.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END AS PaymentAmount
	|FROM
	|	TemporaryTableCustomers AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfAccount
	|		ON DocumentTable.InvoiceForPayment.DocumentCurrency = CurrencyRatesOfAccount.Currency
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS SettlementsCurrencyRates
	|		ON DocumentTable.Currency = SettlementsCurrencyRates.Currency
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|WHERE
	|	DocumentTable.TrackPaymentsByBills
	|	AND VALUETYPE(DocumentTable.InvoiceForPayment) = Type(Document.InvoiceForPayment)
	|	AND DocumentTable.InvoiceForPayment <> VALUE(Document.InvoiceForPayment.EmptyRef)
	|	AND DocumentTable.InvoiceForPayment <> UNDEFINED
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.InvoiceForPayment,
	|	DocumentTable.RecordType
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.InvoiceForPayment,
	|	SUM(CASE
	|			WHEN (NOT DocumentTable.AdvanceFlag)
	|				THEN 0
	|			WHEN Constants.AccountingCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.AccountingAmount
	|			WHEN DocumentTable.Currency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.SettlementsAmount * SettlementsCurrencyRates.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN Constants.AccountingCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.AccountingAmount
	|			WHEN DocumentTable.Currency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.SettlementsAmount * SettlementsCurrencyRates.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END
	|FROM
	|	TemporaryTableVendors AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfAccount
	|		ON DocumentTable.InvoiceForPayment.DocumentCurrency = CurrencyRatesOfAccount.Currency
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS SettlementsCurrencyRates
	|		ON DocumentTable.Currency = SettlementsCurrencyRates.Currency
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|WHERE
	|	DocumentTable.TrackPaymentsByBills
	|	AND VALUETYPE(DocumentTable.InvoiceForPayment) = Type(Document.SupplierInvoiceForPayment)
	|	AND DocumentTable.InvoiceForPayment <> VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
	|	AND DocumentTable.InvoiceForPayment <> UNDEFINED
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.InvoiceForPayment,
	|	DocumentTable.RecordType
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.Order,
	|	SUM(CASE
	|			WHEN (NOT DocumentTable.AdvanceFlag)
	|				THEN 0
	|			WHEN Constants.AccountingCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.AccountingAmount
	|			WHEN DocumentTable.Currency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.SettlementsAmount * SettlementsCurrencyRates.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN Constants.AccountingCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.AccountingAmount
	|			WHEN DocumentTable.Currency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.SettlementsAmount * SettlementsCurrencyRates.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END
	|FROM
	|	TemporaryTableCustomers AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfAccount
	|		ON DocumentTable.Order.DocumentCurrency = CurrencyRatesOfAccount.Currency
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS SettlementsCurrencyRates
	|		ON DocumentTable.Currency = SettlementsCurrencyRates.Currency
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|WHERE
	|	DocumentTable.TrackPaymentsByBills
	|	AND VALUETYPE(DocumentTable.Order) = Type(Document.CustomerOrder)
	|	AND DocumentTable.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Order,
	|	DocumentTable.RecordType
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.Order,
	|	SUM(CASE
	|			WHEN (NOT DocumentTable.AdvanceFlag)
	|				THEN 0
	|			WHEN Constants.AccountingCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.AccountingAmount
	|			WHEN DocumentTable.Currency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.SettlementsAmount * SettlementsCurrencyRates.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN Constants.AccountingCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.AccountingAmount
	|			WHEN DocumentTable.Currency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.SettlementsAmount * SettlementsCurrencyRates.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END
	|FROM
	|	TemporaryTableVendors AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfAccount
	|		ON DocumentTable.Order.DocumentCurrency = CurrencyRatesOfAccount.Currency
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS SettlementsCurrencyRates
	|		ON DocumentTable.Currency = SettlementsCurrencyRates.Currency
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|WHERE
	|	DocumentTable.TrackPaymentsByBills
	|	AND VALUETYPE(DocumentTable.Order) = Type(Document.PurchaseOrder)
	|	AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Order,
	|	DocumentTable.RecordType
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure // GenerateTableInvoicesAndOrdersPayment()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefNetting, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefNetting);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	UNDEFINED AS BusinessActivity,
	|	DocumentTable.Document.Item AS Item,
	|	0 AS AmountIncome,
	|	-DocumentTable.AccountingAmount AS AmountExpense
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	UNDEFINED,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor),
	|	0,
	|	DocumentTable.AccountingAmount
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	UNDEFINED,
	|	DocumentTable.Document.Item,
	|	0,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE -DocumentTable.AccountingAmount
	|	END
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.VendorDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	UNDEFINED,
	|	DocumentTable.Document.Item,
	|	-DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	UNDEFINED,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor),
	|	DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	UNDEFINED,
	|	DocumentTable.Document.Item,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE -DocumentTable.AccountingAmount
	|	END,
	|	0
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesCashMethod()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesUndistributed(DocumentRefNetting, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefNetting);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Item
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|						OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment)
	|					THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|			END
	|	END AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.AccountingAmount AS AmountExpense
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Item
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|						OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor)
	|					THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|			END
	|	END,
	|	0,
	|	DocumentTable.AccountingAmount
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Item
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|						OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment)
	|					THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|			END
	|	END,
	|	DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Item
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|						OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor)
	|					THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|			END
	|	END,
	|	DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Item
	|		ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE -DocumentTable.AccountingAmount
	|	END,
	|	0
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Item
	|		ELSE VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE -DocumentTable.AccountingAmount
	|	END
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.VendorDebtAdjustment)
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
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefNetting, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefNetting);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	Query.SetParameter("Period", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("DocumentArray", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Ref.OperationKind,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END";
	
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
	|	0 AS AmountIncome,
	|	0 AS AmountExpense,
	|	SUM(IncomeAndExpensesRetainedBalances.AmountIncomeBalance) AS AmountIncomeBalance,
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
	|							Document.Netting.Debitor AS DocumentTable
	|						WHERE
	|							DocumentTable.Ref = &Ref
	|				
	|						UNION ALL
	|				
	|						SELECT
	|							DocumentTable.Document
	|						FROM
	|							Document.Netting.Creditor AS DocumentTable
	|						WHERE
	|							DocumentTable.Ref = &Ref)) AS IncomeAndExpensesRetainedBalances
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
			ElsIf AmountRowBalances.AmountIncomeBalance < AmountToBeWrittenOff Then
				AmountRowBalances.AmountIncome = AmountRowBalances.AmountIncomeBalance;
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountIncomeBalance;
			ElsIf AmountRowBalances.AmountIncomeBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountIncome = AmountToBeWrittenOff;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndDo;
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Ref.OperationKind,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END"; 
	
	TableAmountForWriteOff = Query.Execute().Unload();
	
	For Each StringSumToBeWrittenOff IN TableAmountForWriteOff Do
		AmountToBeWrittenOff = StringSumToBeWrittenOff.AmountToBeWrittenOff;
		Filter = New Structure("Document", StringSumToBeWrittenOff.Document);
		RowsArrayAmountsBalances = TableSumBalance.FindRows(Filter);
		For Each AmountRowBalances IN RowsArrayAmountsBalances Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf AmountRowBalances.AmountExpensesBalance < AmountToBeWrittenOff Then
				AmountRowBalances.AmountExpense = AmountRowBalances.AmountExpensesBalance;
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountExpensesBalance;
			ElsIf AmountRowBalances.AmountExpensesBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountExpense = AmountToBeWrittenOff;
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
	|	Table.AmountIncome AS AmountIncome,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessActivity AS BusinessActivity
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	Table.Period,
	|	Table.Company,
	|	&Ref,
	|	Table.AmountIncome,
	|	Table.AmountExpense,
	|	Table.BusinessActivity
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesUndistributed()  

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefNetting, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefNetting);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	Query.SetParameter("DebtAdjustment", NStr("en='Debt adjustment';ru='Корректировка долга'"));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS StructuralUnit,
	|	UNDEFINED AS Order,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|	END AS GLAccount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END AS AmountExpense,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS Amount
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
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
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.BusinessActivities.Other),
	|	DocumentTable.Correspondence,
	|	&DebtAdjustment,
	|	CASE
	|		WHEN DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount
	|FROM
	|	TemporaryTableCustomers AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAdjustment)
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.BusinessActivities.Other),
	|	DocumentTable.Correspondence,
	|	&DebtAdjustment,
	|	CASE
	|		WHEN DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount
	|FROM
	|	TemporaryTableVendors AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsNetting.VendorDebtAdjustment)
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
Procedure GenerateTableManagerial(DocumentRefNetting, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref", DocumentRefNetting);
	Query.SetParameter("Netting", "Netting");
	Query.SetParameter("Novation", "Novation ");
	Query.SetParameter("DebtAdjustment", "Debt adjustment ");
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	VALUE(ChartOfAccounts.Managerial.TransfersInProcess) AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.AccountingAmount AS Amount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN &Netting
	|		ELSE &Novation
	|	END AS Content
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	VALUE(ChartOfAccounts.Managerial.TransfersInProcess),
	|	UNDEFINED,
	|	0,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN &Netting
	|		ELSE &Novation
	|	END
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	&DebtAdjustment
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAdjustment)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	&DebtAdjustment
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	VALUE(ChartOfAccounts.Managerial.TransfersInProcess),
	|	UNDEFINED,
	|	0,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN &Netting
	|		ELSE &Novation
	|	END
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	&DebtAdjustment
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.VendorDebtAdjustment)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.CounterpartySource.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	&DebtAdjustment
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.VendorDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	VALUE(ChartOfAccounts.Managerial.TransfersInProcess),
	|	UNDEFINED,
	|	0,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN &Netting
	|		ELSE &Novation
	|	END
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	7,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.Ref.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN &Netting
	|		ELSE &Novation
	|	END
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	8,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.Ref.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN &Netting
	|		ELSE &Novation
	|	END
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	9,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.Ref.CounterpartySource.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.Ref.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN &Netting
	|		ELSE &Novation
	|	END
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	10,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.Ref.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Ref.CounterpartySource.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN &Netting
	|		ELSE &Novation
	|	END
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor)
	|	AND DocumentTable.AdvanceFlag
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
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	12,
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
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", QueryResult.Unload());
	
EndProcedure // GenerateTableManagerial()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefNetting, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefNetting);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Netting", NStr("en='Netting';ru='Взаимозачет'"));
	Query.SetParameter("Novation", NStr("en='Novation';ru='Переуступка долга'"));
	Query.SetParameter("DebtAdjustment", NStr("en='Debt adjustment';ru='Корректировка долга'"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	DocumentTable.Ref.CounterpartySource AS Counterparty,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Ref.CounterpartySource.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Contract.SettlementsCurrency AS Currency,
	|	DocumentTable.Order AS Order,
	|	DocumentTable.InvoiceForPayment AS InvoiceForPayment,
	|	DocumentTable.Ref.Correspondence AS Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount AS CorrespondenceGLAccountType,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements
	|	END AS GLAccount,
	|	DocumentTable.Ref.Date AS Date,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.AccountingAmount) AS AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN SUM(DocumentTable.SettlementsAmount)
	|		ELSE -SUM(DocumentTable.SettlementsAmount)
	|	END AS SettlementsAmountBalance,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN SUM(DocumentTable.AccountingAmount)
	|		ELSE -SUM(DocumentTable.AccountingAmount)
	|	END AS AccountingAmountBalance,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN &Netting
	|		ELSE &Novation
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableCustomers
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment))
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.InvoiceForPayment,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders,
	|	DocumentTable.Ref.CounterpartySource.TrackPaymentsByBills
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END,
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Document = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders,
	|	DocumentTable.Ref.CounterpartySource.TrackPaymentsByBills,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Order,
	|	DocumentTable.InvoiceForPayment,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	SUM(DocumentTable.SettlementsAmount),
	|	SUM(DocumentTable.AccountingAmount),
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN SUM(DocumentTable.SettlementsAmount)
	|		ELSE -SUM(DocumentTable.SettlementsAmount)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN SUM(DocumentTable.AccountingAmount)
	|		ELSE -SUM(DocumentTable.AccountingAmount)
	|	END,
	|	&DebtAdjustment
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAdjustment)
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.InvoiceForPayment,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders,
	|	DocumentTable.Ref.CounterpartySource.TrackPaymentsByBills
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|				AND DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(Enum.SettlementsTypes.Advance)
	|					ELSE VALUE(Enum.SettlementsTypes.Debt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(Enum.SettlementsTypes.Advance)
	|				ELSE VALUE(Enum.SettlementsTypes.Debt)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(AccumulationRecordType.Expense)
	|					ELSE VALUE(AccumulationRecordType.Receipt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(AccumulationRecordType.Expense)
	|				ELSE VALUE(AccumulationRecordType.Receipt)
	|			END
	|	END,
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Ref.AccountsDocument
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Order,
	|	DocumentTable.Ref.InvoiceForPayment,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	SUM(CASE
	|			WHEN DocumentTable.Ref.AccountingAmount = 0
	|				THEN 0
	|			ELSE DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		END),
	|	SUM(DocumentTable.AccountingAmount),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN -1
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN -1
	|				ELSE 1
	|			END
	|	END * SUM(CASE
	|			WHEN DocumentTable.Ref.AccountingAmount = 0
	|				THEN 0
	|			ELSE DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		END),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN -SUM(DocumentTable.AccountingAmount)
	|					ELSE SUM(DocumentTable.AccountingAmount)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN -SUM(DocumentTable.AccountingAmount)
	|				ELSE SUM(DocumentTable.AccountingAmount)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN &Netting
	|		ELSE &Novation
	|	END
	|FROM
	|	Document.Netting.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.CustomerDebtAssignment)
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|				AND DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(Enum.SettlementsTypes.Advance)
	|					ELSE VALUE(Enum.SettlementsTypes.Debt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(Enum.SettlementsTypes.Advance)
	|				ELSE VALUE(Enum.SettlementsTypes.Debt)
	|			END
	|	END,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.InvoiceForPayment,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Ref.AccountsDocument
	|	END,
	|	DocumentTable.Ref.Order,
	|	DocumentTable.Ref.InvoiceForPayment,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(AccumulationRecordType.Expense)
	|					ELSE VALUE(AccumulationRecordType.Receipt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(AccumulationRecordType.Expense)
	|				ELSE VALUE(AccumulationRecordType.Receipt)
	|			END
	|	END,
	|	DocumentTable.Ref.AdvanceFlag,
	|	DocumentTable.Ref.AccountsDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN DocumentTable.Ref.Counterparty
	|		ELSE DocumentTable.Ref.CounterpartySource
	|	END AS Counterparty,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByContracts
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByContracts
	|	END AS DoOperationsByContracts,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|	END AS DoOperationsByDocuments,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByOrders
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByOrders
	|	END AS DoOperationsByOrders,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN DocumentTable.Ref.Counterparty.TrackPaymentsByBills
	|		ELSE DocumentTable.Ref.CounterpartySource.TrackPaymentsByBills
	|	END AS TrackPaymentsByBills,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Contract.SettlementsCurrency AS Currency,
	|	DocumentTable.Order AS Order,
	|	DocumentTable.InvoiceForPayment AS InvoiceForPayment,
	|	DocumentTable.Ref.Correspondence AS Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount AS CorrespondenceGLAccountType,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN CASE
	|					WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|						THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|					ELSE DocumentTable.Ref.CounterpartySource.VendorAdvancesGLAccount
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|					THEN DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|				ELSE DocumentTable.Ref.CounterpartySource.GLAccountVendorSettlements
	|			END
	|	END AS GLAccount,
	|	DocumentTable.Ref.Date AS Date,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.AccountingAmount) AS AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN SUM(DocumentTable.SettlementsAmount)
	|		ELSE -SUM(DocumentTable.SettlementsAmount)
	|	END AS SettlementsAmountBalance,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN SUM(DocumentTable.AccountingAmount)
	|		ELSE -SUM(DocumentTable.AccountingAmount)
	|	END AS AccountingAmountBalance,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN &Netting
	|		ELSE &Novation
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableVendors
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor))
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.InvoiceForPayment,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN CASE
	|					WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|						THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|					ELSE DocumentTable.Ref.CounterpartySource.VendorAdvancesGLAccount
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|					THEN DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|				ELSE DocumentTable.Ref.CounterpartySource.GLAccountVendorSettlements
	|			END
	|	END,
	|	DocumentTable.Ref.Date,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN DocumentTable.Ref.Counterparty
	|		ELSE DocumentTable.Ref.CounterpartySource
	|	END,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByContracts
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByContracts
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByOrders
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByOrders
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN DocumentTable.Ref.Counterparty.TrackPaymentsByBills
	|		ELSE DocumentTable.Ref.CounterpartySource.TrackPaymentsByBills
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		ELSE VALUE(AccumulationRecordType.Receipt)
	|	END,
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Document = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Order,
	|	DocumentTable.InvoiceForPayment,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	SUM(DocumentTable.SettlementsAmount),
	|	SUM(DocumentTable.AccountingAmount),
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN -SUM(DocumentTable.SettlementsAmount)
	|		ELSE SUM(DocumentTable.SettlementsAmount)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN -SUM(DocumentTable.AccountingAmount)
	|		ELSE SUM(DocumentTable.AccountingAmount)
	|	END,
	|	&DebtAdjustment
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.VendorDebtAdjustment)
	|	AND DocumentTable.SettlementsAmount <> 0
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.InvoiceForPayment,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN DocumentTable.Ref.Counterparty
	|		ELSE DocumentTable.Ref.CounterpartySource
	|	END,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|				AND DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(Enum.SettlementsTypes.Advance)
	|					ELSE VALUE(Enum.SettlementsTypes.Debt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(Enum.SettlementsTypes.Advance)
	|				ELSE VALUE(Enum.SettlementsTypes.Debt)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(AccumulationRecordType.Expense)
	|					ELSE VALUE(AccumulationRecordType.Receipt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(AccumulationRecordType.Expense)
	|				ELSE VALUE(AccumulationRecordType.Receipt)
	|			END
	|	END,
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Ref.AccountsDocument
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Order,
	|	DocumentTable.Ref.InvoiceForPayment,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	SUM(CASE
	|			WHEN DocumentTable.Ref.AccountingAmount = 0
	|				THEN 0
	|			ELSE DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		END),
	|	SUM(DocumentTable.AccountingAmount),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN -1
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN -1
	|				ELSE 1
	|			END
	|	END * SUM(CASE
	|			WHEN DocumentTable.Ref.AccountingAmount = 0
	|				THEN 0
	|			ELSE DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		END),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN -SUM(DocumentTable.AccountingAmount)
	|					ELSE SUM(DocumentTable.AccountingAmount)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN -SUM(DocumentTable.AccountingAmount)
	|				ELSE SUM(DocumentTable.AccountingAmount)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.Netting)
	|			THEN &Netting
	|		ELSE &Novation
	|	END
	|FROM
	|	Document.Netting.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsNetting.DebtAssignmentToVendor)
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Ref.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|				AND DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(Enum.SettlementsTypes.Advance)
	|					ELSE VALUE(Enum.SettlementsTypes.Debt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(Enum.SettlementsTypes.Advance)
	|				ELSE VALUE(Enum.SettlementsTypes.Debt)
	|			END
	|	END,
	|	DocumentTable.Contract,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	DocumentTable.Ref.Order,
	|	DocumentTable.Ref.InvoiceForPayment,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Ref.AccountsDocument
	|	END,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills,
	|	DocumentTable.Ref.AdvanceFlag,
	|	DocumentTable.Ref.AccountsDocument";
	
	Query.ExecuteBatch();
	
	// Register record table creation by account sections.
	GenerateTableCustomerAccounts(DocumentRefNetting, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefNetting, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefNetting, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefNetting, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefNetting, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesUndistributed(DocumentRefNetting, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefNetting, StructureAdditionalProperties);
	GenerateTableManagerial(DocumentRefNetting, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefNetting, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsAccountsReceivableChange
	 OR StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.SettlementsType) AS CalculationsTypesPresentation,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS DebtBalanceAmount,
		|	-(RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0)) AS AmountOfOutstandingAdvances,
		|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
		|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance(
		|				&ControlTime,
		|				(Company, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT
		|						RegisterRecordsAccountsReceivableChange.Company AS Company,
		|						RegisterRecordsAccountsReceivableChange.Counterparty AS Counterparty,
		|						RegisterRecordsAccountsReceivableChange.Contract AS Contract,
		|						RegisterRecordsAccountsReceivableChange.Document AS Document,
		|						RegisterRecordsAccountsReceivableChange.Order AS Order,
		|						RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange)) AS AccountsReceivableBalances
		|		ON RegisterRecordsAccountsReceivableChange.Company = AccountsReceivableBalances.Company
		|			AND RegisterRecordsAccountsReceivableChange.Counterparty = AccountsReceivableBalances.Counterparty
		|			AND RegisterRecordsAccountsReceivableChange.Contract = AccountsReceivableBalances.Contract
		|			AND RegisterRecordsAccountsReceivableChange.Document = AccountsReceivableBalances.Document
		|			AND RegisterRecordsAccountsReceivableChange.Order = AccountsReceivableBalances.Order
		|			AND RegisterRecordsAccountsReceivableChange.SettlementsType = AccountsReceivableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsAccountsReceivableChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) < 0
		|		END
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
			OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectNetting = DocumentRefNetting.GetObject()
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[0].IsEmpty() Then
			
			ErrorTitle = NStr("en='Error:';ru='Ошибка:'");
			MessageTitleText = ErrorTitle + Chars.LF + NStr("en='No possiblity to fix the settlements with customers';ru='Нет возможности зафиксировать расчеты с покупателями'");
			SmallBusinessServer.ShowMessageAboutError(
				DocumentObjectNetting,
				MessageTitleText,
				Undefined,
				Undefined,
				"",
				Cancel
			);
			
			QueryResultSelection = ResultsArray[0].Select();
			While QueryResultSelection.Next() Do
				If QueryResultSelection.SettlementsType = Enums.SettlementsTypes.Debt Then
					MessageText = NStr("en='%CounterpartyPresentation% - customer debt balance by settlements document is less than written amount.
		|Written-off amount: %SumCurOnWrite% %CurrencyPresentation%.
		|Remaining customer debt: %RemainingDebtAmount% %CurrencyPresentation%.';ru='%ПредставлениеКонтрагента% - остаток задолженности покупателя по документу расчетов меньше списываемой суммы.
		|Списываемая сумма: %СуммаВалПриЗаписи% %ВалютаПредставление%.
		|Остаток задолженности покупателя: %СуммаОстаткаЗадолженности% %ВалютаПредставление%.'"
					);
				EndIf;
				If QueryResultSelection.SettlementsType = Enums.SettlementsTypes.Advance Then
					If QueryResultSelection.AmountOfOutstandingAdvances = 0 Then
						MessageText = NStr("en='%PresentationOfCounterparty% - perhaps the advances of the customer have not been received or they have been completely set off in the trade documents.';ru='%ПредставлениеКонтрагента% - возможно, авансов от покупателя не было или они уже полностью зачтены в товарных документах.'"
						);
					Else
						MessageText = NStr("en='%CounterpartyPresentation% - advances received from customer are already partially set off in commercial documents.
		|Balance of non-offset advances: %OutstandingAdvancesAmount% %CurrencyPresentation%.';ru='%ПредставлениеКонтрагента% - полученные авансы от покупателя уже частично зачтены в товарных документах.
		|Остаток незачтенных авансов: %СуммаНепогашенныхАвансов% %ВалютаПредставление%.'"
						);
						MessageText = StrReplace(MessageText, "%UnpaidAdvancesAmount%", String(QueryResultSelection.AmountOfOutstandingAdvances));
					EndIf;
				EndIf;
				MessageText = StrReplace(MessageText, "%CounterpartyPresentation%", SmallBusinessServer.PresentationOfCounterparty(QueryResultSelection.CounterpartyPresentation, QueryResultSelection.ContractPresentation, QueryResultSelection.DocumentPresentation, QueryResultSelection.OrderPresentation, QueryResultSelection.CalculationsTypesPresentation));
				MessageText = StrReplace(MessageText, "%CurrencyPresentation%", QueryResultSelection.CurrencyPresentation);
				MessageText = StrReplace(MessageText, "%SumCurOnWrite%", String(QueryResultSelection.SumCurOnWrite));
				MessageText = StrReplace(MessageText, "%RemainingDebtAmount%", String(QueryResultSelection.DebtBalanceAmount));
				SmallBusinessServer.ShowMessageAboutError(
					DocumentObjectNetting,
					MessageText,
					Undefined,
					Undefined,
					"",
					Cancel
				);
			EndDo;
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[1].IsEmpty() Then
			
			ErrorTitle = NStr("en='Error:';ru='Ошибка:'");
			MessageTitleText = ErrorTitle + Chars.LF + NStr("en='Cannot record the accounts payables.';ru='Нет возможности зафиксировать расчеты с поставщиками'");
			SmallBusinessServer.ShowMessageAboutError(
				DocumentObjectNetting,
				MessageTitleText,
				Undefined,
				Undefined,
				"",
				Cancel
			);
			
			QueryResultSelection = ResultsArray[1].Select();
			While QueryResultSelection.Next() Do
				If QueryResultSelection.SettlementsType = Enums.SettlementsTypes.Debt Then
					MessageText = NStr("en='%CounterpartyPresentation% - debt to vendor balance by settlements document is less than written amount.
		|Written-off amount: %SumCurOnWrite% %CurrencyPresentation%.
		|Debt before the balance provider:%RemainingDebtAmount% CurrencyPresentation%.';ru='%ПредставлениеКонтрагента% - остаток задолженности перед поставщиком по документу расчетов меньше списываемой суммы.
		|Списываемая сумма: %СуммаВалПриЗаписи% %ВалютаПредставление%.
		|Остаток задолженности перед поставщиком: %СуммаОстаткаЗадолженности% %ВалютаПредставление%.'"
					);
				EndIf;
				If QueryResultSelection.SettlementsType = Enums.SettlementsTypes.Advance Then
					If QueryResultSelection.AmountOfOutstandingAdvances = 0 Then
						MessageText = NStr("en=""%CounterpartyPresentation% - perhaps the vendor didn't get the advances or they have been completely set off in the trade documents ."";ru='%ПредставлениеКонтрагента% - возможно, авансов поставщику не было или они уже полностью зачтены в товарных документах.'"
						);
					Else
						MessageText = NStr("en='%CounterpartyPresentation% - advances issued to vendors are already partially set off in commercial documents.
		|Balance of non-offset advances: %OutstandingAdvancesAmount% %CurrencyPresentation%.';ru='%ПредставлениеКонтрагента% - выданные авансы поставщику уже частично зачтены в товарных документах.
		|Остаток незачтенных авансов: %СуммаНепогашенныхАвансов% %ВалютаПредставление%.'"
						);
						MessageText = StrReplace(MessageText, "%UnpaidAdvancesAmount%", String(QueryResultSelection.AmountOfOutstandingAdvances));
					EndIf;
				EndIf;
				MessageText = StrReplace(MessageText, "%CounterpartyPresentation%", SmallBusinessServer.PresentationOfCounterparty(QueryResultSelection.CounterpartyPresentation, QueryResultSelection.ContractPresentation, QueryResultSelection.DocumentPresentation, QueryResultSelection.OrderPresentation, QueryResultSelection.CalculationsTypesPresentation));
				MessageText = StrReplace(MessageText, "%CurrencyPresentation%", QueryResultSelection.CurrencyPresentation);
				MessageText = StrReplace(MessageText, "%SumCurOnWrite%", String(QueryResultSelection.SumCurOnWrite));
				MessageText = StrReplace(MessageText, "%RemainingDebtAmount%", String(QueryResultSelection.DebtBalanceAmount));
				SmallBusinessServer.ShowMessageAboutError(
					DocumentObjectNetting,
					MessageText,
					Undefined,
					Undefined,
					"",
					Cancel
				);
			EndDo;
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