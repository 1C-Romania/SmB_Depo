#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssets(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("CashFundsReceipt", NStr("en='Cash receipt';ru='Приходный кассовый ордер'"));
	Query.SetParameter("RevenueInRetailReceipt", NStr("en='Retail Revenue Receipt';ru='Поступление розничной выручки'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.CashAssetTypes.Cash) AS CashAssetsType,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.PettyCash AS BankAccountPettyCash,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.PettyCashGLAccount AS GLAccount,
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.RetailIncome)
	|				OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.RetailIncomeAccrualAccounting)
	|			THEN &RevenueInRetailReceipt
	|		ELSE &CashFundsReceipt
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableCashAssets
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromAdvanceHolder)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.CurrencyPurchase)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.RetailIncome)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.RetailIncomeAccrualAccounting))
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.Item,
	|	DocumentTable.PettyCash,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.PettyCashGLAccount,
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.RetailIncome)
	|				OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.RetailIncomeAccrualAccounting)
	|			THEN &RevenueInRetailReceipt
	|		ELSE &CashFundsReceipt
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePaymentDetails.LineNumber,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	VALUE(Enum.CashAssetTypes.Cash),
	|	TemporaryTablePaymentDetails.Item,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount,
	|	&CashFundsReceipt
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	(TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromCustomer)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.Item,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount
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
	|	TemporaryTableCashAssets";
	
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
Procedure GenerateTableCashAssetsInCashRegisters(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	
	"SELECT
	|	1 AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.CashCR AS CashCR,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.CashCRGLAccount AS GLAccount,
	|	&CashExpense AS ContentOfAccountingRecord
	|INTO TemporaryTableCashAssetsInRetailCashes
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.RetailIncome)
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.CashCR,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.CashCRGLAccount
	|
	|INDEX BY
	|	Company,
	|	CashCR,
	|	Currency,
	|	GLAccount";
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("CashExpense", NStr("en='Cash expense from cash register';ru='Расход денежных средств из кассы ККМ'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTableCashAssetsInRetailCashes.Company AS Company,
	|	TemporaryTableCashAssetsInRetailCashes.CashCR AS CashCR
	|FROM
	|	TemporaryTableCashAssetsInRetailCashes";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.CashInCashRegisters");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult IN QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = SmallBusinessServer.GetQueryTextExchangeRateDifferencesCashInCashRegisters(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashInCashRegisters", ResultsArray[QueryNumber].Unload());
	
EndProcedure // GenerateTableCashAssetsInCashRegisters()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateAdvanceHolderPaymentsTable(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("RepaymentOfAdvanceHolderDebt", NStr("en='Repayment of advance holder debt';ru='Погашение долга подотчетника'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.PettyCash AS PettyCash,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.AdvanceHolder AS Employee,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	-SUM(DocumentTable.Amount) AS AmountForBalance,
	|	-SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.AdvanceHolderAdvanceHoldersGLAccount AS GLAccount,
	|	&RepaymentOfAdvanceHolderDebt AS ContentOfAccountingRecord
	|INTO TemporaryTableAdvanceHolderPayments
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromAdvanceHolder)
	|
	|GROUP BY
	|	DocumentTable.PettyCash,
	|	DocumentTable.Document,
	|	DocumentTable.AdvanceHolder,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.AdvanceHolderAdvanceHoldersGLAccount
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
	|	TemporaryTableAdvanceHolderPayments";
	
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
Procedure GenerateTableCustomerAccounts(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerAdvance", "Appearence of customer advance");
	Query.SetParameter("CustomerObligationsRepayment", "Repayment of obligations of customer");
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
	|	TemporaryTablePaymentDetails.PettyCash AS PettyCash,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS Order,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount) AS PaymentAmount,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCur,
	|	-SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForBalance,
	|	-SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCurForBalance,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.CustomerAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountCustomerSettlements
	|	END AS GLAccount,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &AppearenceOfCustomerAdvance
	|		ELSE &CustomerObligationsRepayment
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromCustomer)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.PettyCash,
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
	|			THEN &AppearenceOfCustomerAdvance
	|		ELSE &CustomerObligationsRepayment
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
Procedure GenerateTableAccountsPayable(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("VendorAdvanceRepayment", NStr("en='Vendor advance repayment';ru='Погашение аванса поставщику'"));
	Query.SetParameter("AppearenceOfLiabilityToVendor", NStr("en='Appearance of vendor liabilities';ru='Возникновение обязательств перед поставщиком'"));
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
	|	TemporaryTablePaymentDetails.PettyCash AS PettyCash,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount) AS PaymentAmount,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCur,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForBalance,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCurForBalance,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.VendorAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountVendorSettlements
	|	END AS GLAccount,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &VendorAdvanceRepayment
	|		ELSE &AppearenceOfLiabilityToVendor
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.PettyCash,
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
	|			THEN &VendorAdvanceRepayment
	|		ELSE &AppearenceOfLiabilityToVendor
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
Procedure GenerateTableIncomeAndExpenses(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeReflection", NStr("en='Income accounting';ru='Отражение доходов'"));
	Query.SetParameter("CostsReflection", NStr("en='Costs reflection';ru='Отражение расходов'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS StructuralUnit,
	|	UNDEFINED AS Order,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	DocumentTable.Correspondence AS GLAccount,
	|	&IncomeReflection AS ContentOfAccountingRecord,
	|	DocumentTable.Amount AS AmountIncome,
	|	0 AS AmountExpense,
	|	DocumentTable.Amount AS Amount
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.Incomings)
	|			OR DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.OtherIncome))
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.CurrencyPurchase))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.Division,
	|	UNDEFINED,
	|	DocumentTable.BusinessActivity,
	|	DocumentTable.BusinessActivityGLAccountOfRevenueFromSales,
	|	&IncomeReflection,
	|	DocumentTable.Amount,
	|	0,
	|	DocumentTable.Amount
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.RetailIncomeAccrualAccounting)
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
	|	TemporaryTableExchangeRateLossesBanking AS DocumentTable
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
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	7,
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
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	8,
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
	|	TemporaryTableCurrencyExchangeRateDifferencesRetailAmountAccounting AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	9,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.Division,
	|	UNDEFINED,
	|	DocumentTable.BusinessActivity,
	|	DocumentTable.BusinessActivityGLAccountOfSalesCost,
	|	&CostsReflection,
	|	0,
	|	DocumentTable.Cost,
	|	DocumentTable.Cost
	|FROM
	|	TemporaryTableCost AS DocumentTable
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
Procedure GenerateTableManagerial(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	Query.SetParameter("Content", NStr("en='Cash as received from any account';ru='Оприходование денежных средств с произвольного счета'"));
	Query.SetParameter("ContentCurrencyPurchase", NStr("en='Currency purchase';ru='Покупка валюты'"));
	Query.SetParameter("ContentRetailIncome", NStr("en='Retail income';ru='Розничная выручка'"));
	Query.SetParameter("ContentCost", NStr("en='Cost';ru='Себестоимость'"));
	Query.SetParameter("ContentMarkup", NStr("en='Markup';ru='Наценка'"));
		
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.PettyCashGLAccount AS AccountDr,
	|	DocumentTable.Correspondence AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	CAST(CASE
	|			WHEN DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.CurrencyPurchase)
	|				THEN &ContentCurrencyPurchase
	|			ELSE &Content
	|		END AS String(100)) AS Content
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.CurrencyPurchase))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCashGLAccount,
	|	DocumentTable.CashCRGLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.CashCRGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.CashCRGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&ContentRetailIncome AS String(100))
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.RetailIncome)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCashGLAccount,
	|	DocumentTable.BusinessActivityGLAccountOfRevenueFromSales,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BusinessActivityGLAccountOfRevenueFromSales.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BusinessActivityGLAccountOfRevenueFromSales.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&ContentRetailIncome AS String(100))
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.RetailIncomeAccrualAccounting)
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCash.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
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
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCash.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
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
	|	7,
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
	|	8,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCash.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
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
	|	9,
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
	|	10,
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
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS DocumentTable
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
	|	TemporaryTableCurrencyExchangeRateDifferencesRetailAmountAccounting AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	13,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.BusinessActivityGLAccountOfSalesCost,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	CASE
	|		WHEN DocumentTable.BusinessActivityGLAccountOfSalesCost.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BusinessActivityGLAccountOfSalesCost.Currency
	|			THEN 0
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN 0
	|		ELSE 0
	|	END,
	|	DocumentTable.Cost,
	|	CAST(&ContentCost AS String(100))
	|FROM
	|	TemporaryTableCost AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	14,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN 0
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN 0
	|		ELSE 0
	|	END,
	|	-(DocumentTable.Amount - TableCost.Cost),
	|	CAST(&ContentMarkup AS String(100))
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|		LEFT JOIN TemporaryTableCost AS TableCost
	|		ON DocumentTable.Company = TableCost.Company
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.RetailIncomeAccrualAccounting)
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	UNDEFINED AS BusinessActivity,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.AccountingAmount AS AmountIncome,
	|	0 AS AmountExpense
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromCustomer)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.BusinessActivity,
	|	Table.Item,
	|	Table.AmountIncome,
	|	0
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|WHERE
	|	Table.AmountIncome > 0
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.BusinessActivities.Other),
	|	DocumentTable.Item,
	|	DocumentTable.Amount,
	|	0
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.CurrencyPurchase))
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	&Company,
	|	UNDEFINED,
	|	DocumentTable.Item,
	|	0,
	|	-DocumentTable.AccountingAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor)
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
	|	-Table.AmountExpense
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
Procedure GenerateTableIncomeAndExpensesUndistributed(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
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
	|	DocumentTable.AccountingAmount AS AmountIncome,
	|	0 AS AmountExpense
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromCustomer)
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
	|	0,
	|	-DocumentTable.AccountingAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor)
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
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	Query.SetParameter("Period", StructureAdditionalProperties.ForPosting.Date);
	
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
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromCustomer)
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
	|	SUM(IncomeAndExpensesRetainedBalances.AmountIncomeBalance) AS AmountIncomeBalance,
	|	-SUM(IncomeAndExpensesRetainedBalances.AmountExpensesBalance) AS AmountExpensesBalance
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
	|							(DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromCustomer)
	|								OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor)))) AS IncomeAndExpensesRetainedBalances
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
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item; 
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountIncomeBalance;
			ElsIf AmountRowBalances.AmountIncomeBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountIncome = AmountToBeWrittenOff;
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
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor)
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
	|	Table.AmountIncome AS AmountIncome,
	|	- Table.AmountExpense AS AmountExpense,
	|	Table.BusinessActivity AS BusinessActivity
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table";

	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesUndistributed()  

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePaymentCalendar(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UsePaymentCalendar", Constants.FunctionalOptionPaymentCalendar.Get());
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Item AS Item,
	|	VALUE(Enum.CashAssetTypes.Cash) AS CashAssetsType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	DocumentTable.PettyCash AS BankAccountPettyCash,
	|	CASE
	|		WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE DocumentTable.CashCurrency
	|	END AS Currency,
	|	DocumentTable.InvoiceForPaymentToPaymentCalendar AS InvoiceForPayment,
	|	SUM(CASE
	|			WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE DocumentTable.PaymentAmount
	|		END) AS PaymentAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.PettyCash,
	|	CASE
	|		WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE DocumentTable.CashCurrency
	|	END,
	|	DocumentTable.InvoiceForPaymentToPaymentCalendar,
	|	DocumentTable.Item
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.Item,
	|	VALUE(Enum.CashAssetTypes.Cash),
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	DocumentTable.PettyCash,
	|	DocumentTable.CashCurrency,
	|	UNDEFINED,
	|	DocumentTable.DocumentAmount
	|FROM
	|	Document.CashPayment AS DocumentTable
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
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure // GenerateTablePaymentCalendar()

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
	|			WHEN Not DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN DocumentTable.CashCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.PaymentAmount
	|			WHEN DocumentTable.SettlementsCurrency = DocumentTable.InvoiceForPayment.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * CurrencyRatesOfAccount.Multiplicity / (CurrencyRatesOfAccount.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor)
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
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor)
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
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromCustomer)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor))
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
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor)
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
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor)
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
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromCustomer)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor))
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

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableRetailAmountAccounting(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("RetailIncome", NStr("en='Retail income';ru='Розничная выручка'"));
	Query.SetParameter("Cost", NStr("en='Cost';ru='Себестоимость'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Date,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Division AS Division,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS StructuralUnitGLAccountInRetail,
	|	DocumentTable.BusinessActivity AS BusinessActivity,
	|	DocumentTable.BusinessActivityGLAccountOfSalesCost AS BusinessActivityGLAccountOfSalesCost,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	-SUM(DocumentTable.Amount) AS AmountForBalance,
	|	-SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS GLAccount,
	|	0 AS Cost,
	|	&RetailIncome AS ContentOfAccountingRecord
	|INTO TemporaryTableRetailAmountAccounting
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.RetailIncomeAccrualAccounting)
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.Division,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	DocumentTable.BusinessActivity,
	|	DocumentTable.BusinessActivityGLAccountOfSalesCost,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.StructuralUnitGLAccountInRetail
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Currency,
	|	GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.Division AS Division,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.BusinessActivity AS BusinessActivity,
	|	DocumentTable.BusinessActivityGLAccountOfSalesCost AS BusinessActivityGLAccountOfSalesCost,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS StructuralUnitGLAccountInRetail,
	|	CASE
	|		WHEN RetailAmountAccountingBalances.AmountCurBalance - DocumentTable.AmountCur = 0
	|			THEN RetailAmountAccountingBalances.CostBalance
	|		WHEN RetailAmountAccountingBalances.AmountCurBalance <> 0
	|			THEN CAST(RetailAmountAccountingBalances.CostBalance * DocumentTable.AmountCur / RetailAmountAccountingBalances.AmountCurBalance AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS Cost
	|INTO TemporaryTableCost
	|FROM
	|	TemporaryTableRetailAmountAccounting AS DocumentTable
	|		LEFT JOIN (SELECT
	|			RetailAmountAccountingBalances.Company AS Company,
	|			RetailAmountAccountingBalances.StructuralUnit AS StructuralUnit,
	|			RetailAmountAccountingBalances.Currency AS Currency,
	|			SUM(RetailAmountAccountingBalances.AmountBalance) AS AmountBalance,
	|			SUM(RetailAmountAccountingBalances.AmountCurBalance) AS AmountCurBalance,
	|			SUM(RetailAmountAccountingBalances.CostBalance) AS CostBalance
	|		FROM
	|			(SELECT
	|				RetailAmountAccountingBalances.Company AS Company,
	|				RetailAmountAccountingBalances.StructuralUnit AS StructuralUnit,
	|				RetailAmountAccountingBalances.Currency AS Currency,
	|				ISNULL(RetailAmountAccountingBalances.AmountBalance, 0) AS AmountBalance,
	|				ISNULL(RetailAmountAccountingBalances.AmountCurBalance, 0) AS AmountCurBalance,
	|				ISNULL(RetailAmountAccountingBalances.CostBalance, 0) AS CostBalance
	|			FROM
	|				AccumulationRegister.RetailAmountAccounting.Balance(
	|						&PointInTime,
	|						(Company, StructuralUnit, Currency) In
	|							(SELECT DISTINCT
	|								TemporaryTableRetailAmountAccounting.Company,
	|								TemporaryTableRetailAmountAccounting.StructuralUnit,
	|								TemporaryTableRetailAmountAccounting.Currency
	|							FROM
	|								TemporaryTableRetailAmountAccounting)) AS RetailAmountAccountingBalances
	|			
	|			UNION ALL
	|			
	|			SELECT
	|				DocumentRegisterRecordsRetailAmountAccounting.Company,
	|				DocumentRegisterRecordsRetailAmountAccounting.StructuralUnit,
	|				DocumentRegisterRecordsRetailAmountAccounting.Currency,
	|				CASE
	|					WHEN DocumentRegisterRecordsRetailAmountAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						THEN -ISNULL(DocumentRegisterRecordsRetailAmountAccounting.Amount, 0)
	|					ELSE ISNULL(DocumentRegisterRecordsRetailAmountAccounting.Amount, 0)
	|				END,
	|				CASE
	|					WHEN DocumentRegisterRecordsRetailAmountAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						THEN -ISNULL(DocumentRegisterRecordsRetailAmountAccounting.AmountCur, 0)
	|					ELSE ISNULL(DocumentRegisterRecordsRetailAmountAccounting.AmountCur, 0)
	|				END,
	|				CASE
	|					WHEN DocumentRegisterRecordsRetailAmountAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						THEN -ISNULL(DocumentRegisterRecordsRetailAmountAccounting.Cost, 0)
	|					ELSE ISNULL(DocumentRegisterRecordsRetailAmountAccounting.Cost, 0)
	|				END
	|			FROM
	|				AccumulationRegister.RetailAmountAccounting AS DocumentRegisterRecordsRetailAmountAccounting
	|			WHERE
	|				DocumentRegisterRecordsRetailAmountAccounting.Recorder = &Ref
	|				AND DocumentRegisterRecordsRetailAmountAccounting.Period <= &ControlPeriod) AS RetailAmountAccountingBalances
	|		
	|		GROUP BY
	|			RetailAmountAccountingBalances.Company,
	|			RetailAmountAccountingBalances.StructuralUnit,
	|			RetailAmountAccountingBalances.Currency) AS RetailAmountAccountingBalances
	|		ON DocumentTable.Company = RetailAmountAccountingBalances.Company
	|			AND DocumentTable.StructuralUnit = RetailAmountAccountingBalances.StructuralUnit
	|			AND DocumentTable.Currency = RetailAmountAccountingBalances.Currency
	|WHERE
	|	(CASE
	|				WHEN RetailAmountAccountingBalances.AmountCurBalance - DocumentTable.AmountCur = 0
	|					THEN RetailAmountAccountingBalances.CostBalance
	|				WHEN RetailAmountAccountingBalances.AmountCurBalance <> 0
	|					THEN CAST(RetailAmountAccountingBalances.CostBalance * DocumentTable.AmountCur / RetailAmountAccountingBalances.AmountCurBalance AS NUMBER(15, 2))
	|				ELSE 0
	|			END > 0.005
	|			OR CASE
	|				WHEN RetailAmountAccountingBalances.AmountCurBalance - DocumentTable.AmountCur = 0
	|					THEN RetailAmountAccountingBalances.CostBalance
	|				WHEN RetailAmountAccountingBalances.AmountCurBalance <> 0
	|					THEN CAST(RetailAmountAccountingBalances.CostBalance * DocumentTable.AmountCur / RetailAmountAccountingBalances.AmountCurBalance AS NUMBER(15, 2))
	|				ELSE 0
	|			END < -0.005)";
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTableRetailAmountAccounting.Company AS Company,
	|	TemporaryTableRetailAmountAccounting.StructuralUnit AS StructuralUnit,
	|	TemporaryTableRetailAmountAccounting.Currency AS Currency
	|FROM
	|	TemporaryTableRetailAmountAccounting AS TemporaryTableRetailAmountAccounting";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.RetailAmountAccounting");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult IN QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	"SELECT
	|	RetailAmountAccountingBalances.Company AS Company,
	|	RetailAmountAccountingBalances.StructuralUnit AS StructuralUnit,
	|	RetailAmountAccountingBalances.GLAccount AS GLAccount,
	|	RetailAmountAccountingBalances.Currency AS Currency,
	|	SUM(RetailAmountAccountingBalances.AmountBalance) AS AmountBalance,
	|	SUM(RetailAmountAccountingBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableBalancesAfterPosting
	|FROM
	|	(SELECT
	|		TemporaryTable.Company AS Company,
	|		TemporaryTable.StructuralUnit AS StructuralUnit,
	|		TemporaryTable.Currency AS Currency,
	|		TemporaryTable.GLAccount AS GLAccount,
	|		TemporaryTable.AmountForBalance AS AmountBalance,
	|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
	|	FROM
	|		TemporaryTableRetailAmountAccounting AS TemporaryTable
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableBalances.Company,
	|		TableBalances.StructuralUnit,
	|		TableBalances.Currency,
	|		TableBalances.StructuralUnit.GLAccountInRetail,
	|		ISNULL(TableBalances.AmountBalance, 0),
	|		ISNULL(TableBalances.AmountCurBalance, 0)
	|	FROM
	|		AccumulationRegister.RetailAmountAccounting.Balance(
	|				&PointInTime,
	|				(Company, StructuralUnit, Currency) In
	|					(SELECT DISTINCT
	|						TemporaryTableRetailAmountAccounting.Company,
	|						TemporaryTableRetailAmountAccounting.StructuralUnit,
	|						TemporaryTableRetailAmountAccounting.Currency
	|					FROM
	|						TemporaryTableRetailAmountAccounting)) AS TableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecords.Company,
	|		DocumentRegisterRecords.StructuralUnit,
	|		DocumentRegisterRecords.Currency,
	|		DocumentRegisterRecords.StructuralUnit.GLAccountInRetail,
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
	|		AccumulationRegister.RetailAmountAccounting AS DocumentRegisterRecords
	|	WHERE
	|		DocumentRegisterRecords.Recorder = &Ref
	|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS RetailAmountAccountingBalances
	|
	|GROUP BY
	|	RetailAmountAccountingBalances.Company,
	|	RetailAmountAccountingBalances.StructuralUnit,
	|	RetailAmountAccountingBalances.Currency,
	|	RetailAmountAccountingBalances.GLAccount
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Currency,
	|	GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	1 AS LineNumber,
	|	&ControlPeriod AS Date,
	|	TableRetailAmountAccounting.Company AS Company,
	|	TableRetailAmountAccounting.StructuralUnit AS StructuralUnit,
	|	ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRateCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyExchangeRateCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
	|	TableRetailAmountAccounting.Currency AS Currency,
	|	TableRetailAmountAccounting.GLAccount AS GLAccount
	|INTO TemporaryTableCurrencyExchangeRateDifferencesRetailAmountAccounting
	|FROM
	|	TemporaryTableRetailAmountAccounting AS TableRetailAmountAccounting
	|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
	|		ON TableRetailAmountAccounting.Company = TableBalances.Company
	|			AND TableRetailAmountAccounting.StructuralUnit = TableBalances.StructuralUnit
	|			AND TableRetailAmountAccounting.Currency = TableBalances.Currency
	|			AND TableRetailAmountAccounting.GLAccount = TableBalances.GLAccount
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
	|						TemporaryTableRetailAmountAccounting.Currency
	|					FROM
	|						TemporaryTableRetailAmountAccounting)) AS CurrencyExchangeRateCashSliceLast
	|		ON TableRetailAmountAccounting.Currency = CurrencyExchangeRateCashSliceLast.Currency
	|WHERE
	|	(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRateCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyExchangeRateCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
	|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRateCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyExchangeRateCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.AmountCur AS AmountCur,
	|	0 AS Cost,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	UNDEFINED AS SalesDocument
	|FROM
	|	TemporaryTableRetailAmountAccounting AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.Currency,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	0,
	|	0,
	|	&ExchangeDifference,
	|	UNDEFINED
	|FROM
	|	TemporaryTableCurrencyExchangeRateDifferencesRetailAmountAccounting AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.Currency,
	|	0,
	|	0,
	|	DocumentTable.Cost,
	|	&Cost,
	|	&Ref
	|FROM
	|	TemporaryTableCost AS DocumentTable
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableBalancesAfterPosting";
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableRetailAmountAccounting", ResultsArray[2].Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefCashReceipt, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	Query.SetParameter("CashCurrency", DocumentRefCashReceipt.CashCurrency);
	
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
	|	DocumentTable.Ref.PettyCash AS PettyCash,
	|	DocumentTable.Ref.PettyCash.GLAccount AS BankAccountCashGLAccount,
	|	DocumentTable.Ref.Item AS Item,
	|	DocumentTable.Ref.Correspondence AS Correspondence,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromCustomer)
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor)
	|				AND DocumentTable.Order = VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END AS Order,
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	DocumentTable.Ref.Date AS Date,
	|	SUM(CAST(DocumentTable.PaymentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))) AS AccountingAmount,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.PaymentAmount) AS PaymentAmount,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = Type(Document.PaymentReceiptPlan)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.PaymentReceiptPlan.EmptyRef)
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
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount AS VendorAdvancesGLAccount
	|INTO TemporaryTablePaymentDetails
	|FROM
	|	Document.CashReceipt.PaymentDetails AS DocumentTable
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
	|	DocumentTable.Ref.PettyCash,
	|	DocumentTable.Ref.Item,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromCustomer)
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromVendor)
	|				AND DocumentTable.Order = VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsCashReceipt.FromCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = Type(Document.PaymentReceiptPlan)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.PaymentReceiptPlan.EmptyRef)
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
	|	DocumentTable.Ref.PettyCash.GLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS LineNumber,
	|	DocumentTable.OperationKind AS OperationKind,
	|	DocumentTable.Date AS Date,
	|	&Company AS Company,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.PettyCash AS PettyCash,
	|	DocumentTable.CashCR AS CashCR,
	|	DocumentTable.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationKindsCashReceipt.CurrencyPurchase)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE CAST(DocumentTable.DocumentAmount * CurrencyRatesOfPettyCashe.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|	END AS Amount,
	|	DocumentTable.DocumentAmount AS AmountCur,
	|	DocumentTable.PettyCash.GLAccount AS PettyCashGLAccount,
	|	DocumentTable.CashCR.GLAccount AS CashCRGLAccount,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.StructuralUnit.GLAccountInRetail AS StructuralUnitGLAccountInRetail,
	|	DocumentTable.StructuralUnit.MarkupGLAccount AS StructuralUnitGLAccountMarkup,
	|	DocumentTable.Division AS Division,
	|	DocumentTable.BusinessActivity AS BusinessActivity,
	|	DocumentTable.BusinessActivity.GLAccountRevenueFromSales AS BusinessActivityGLAccountOfRevenueFromSales,
	|	DocumentTable.BusinessActivity.GLAccountCostOfSales AS BusinessActivityGLAccountOfSalesCost,
	|	DocumentTable.Correspondence AS Correspondence,
	|	DocumentTable.Correspondence.TypeOfAccount AS CorrespondenceGLAccountType,
	|	DocumentTable.AdvanceHolder AS AdvanceHolder,
	|	DocumentTable.AdvanceHolder.AdvanceHoldersGLAccount AS AdvanceHolderAdvanceHoldersGLAccount,
	|	DocumentTable.Document AS Document
	|INTO TemporaryTableHeader
	|FROM
	|	Document.CashReceipt AS DocumentTable
	|		LEFT JOIN TemporaryTableCurrencyRatesSliceLatest AS AccountingCurrencyRatesSliceLast
	|		ON (AccountingCurrencyRatesSliceLast.Currency = &AccountingCurrency)
	|		LEFT JOIN TemporaryTableCurrencyRatesSliceLatest AS CurrencyRatesOfPettyCashe
	|		ON (CurrencyRatesOfPettyCashe.Currency = &CashCurrency)
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	Query.ExecuteBatch();
	
	// Register record table creation by account sections.
	GenerateTableCashAssets(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableCashAssetsInCashRegisters(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateAdvanceHolderPaymentsTable(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableRetailAmountAccounting(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesUndistributed(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableManagerial(DocumentRefCashReceipt, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefCashReceipt, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.ControlBalancesOnPosting.Get() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsCashAssetsChange
	 OR StructureTemporaryTables.RegisterRecordsAdvanceHolderPaymentsChange
	 OR StructureTemporaryTables.RegisterRecordsAccountsReceivableChange
	 OR StructureTemporaryTables.RegisterRecordsRetailAmountAccountingUpdate
	 OR StructureTemporaryTables.RegisterRecordsCashInCashRegistersChange Then
		
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
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	RegisterRecordsAccountsReceivableChange.Company AS CompanyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Contract AS ContractPresentation,
		|	RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency AS CurrencyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Document AS DocumentPresentation,
		|	RegisterRecordsAccountsReceivableChange.Order AS OrderPresentation,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS CalculationsTypesPresentation,
		|	TRUE AS RegisterRecordsOfCashDocuments,
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
		|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance(&ControlTime, ) AS AccountsReceivableBalances
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
		|	RegisterRecordsRetailAmountAccountingUpdate.LineNumber AS LineNumber,
		|	RegisterRecordsRetailAmountAccountingUpdate.Company AS CompanyPresentation,
		|	RegisterRecordsRetailAmountAccountingUpdate.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsRetailAmountAccountingUpdate.StructuralUnit.RetailPriceKind.PriceCurrency AS CurrencyPresentation,
		|	ISNULL(RetailAmountAccountingBalances.AmountBalance, 0) AS AmountBalance,
		|	RegisterRecordsRetailAmountAccountingUpdate.SumCurChange + ISNULL(RetailAmountAccountingBalances.AmountCurBalance, 0) AS BalanceInRetail,
		|	RegisterRecordsRetailAmountAccountingUpdate.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsRetailAmountAccountingUpdate.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsRetailAmountAccountingUpdate.AmountChange AS AmountChange,
		|	RegisterRecordsRetailAmountAccountingUpdate.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsRetailAmountAccountingUpdate.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsRetailAmountAccountingUpdate.SumCurChange AS SumCurChange,
		|	RegisterRecordsRetailAmountAccountingUpdate.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsRetailAmountAccountingUpdate.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsRetailAmountAccountingUpdate.CostUpdate AS CostUpdate
		|FROM
		|	RegisterRecordsRetailAmountAccountingUpdate AS RegisterRecordsRetailAmountAccountingUpdate
		|		LEFT JOIN AccumulationRegister.RetailAmountAccounting.Balance(&ControlTime, ) AS RetailAmountAccountingBalances
		|		ON RegisterRecordsRetailAmountAccountingUpdate.Company = RetailAmountAccountingBalances.Company
		|			AND RegisterRecordsRetailAmountAccountingUpdate.StructuralUnit = RetailAmountAccountingBalances.StructuralUnit
		|WHERE
		|	ISNULL(RetailAmountAccountingBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsCashInCashRegistersChange.LineNumber AS LineNumber,
		|	RegisterRecordsCashInCashRegistersChange.Company AS CompanyPresentation,
		|	RegisterRecordsCashInCashRegistersChange.CashCR AS CashCRDescription,
		|	RegisterRecordsCashInCashRegistersChange.CashCR.CashCurrency AS CurrencyPresentation,
		|	ISNULL(CashAssetsInRetailCashesBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsCashInCashRegistersChange.SumCurChange + ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) AS BalanceCashAssets,
		|	RegisterRecordsCashInCashRegistersChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsCashInCashRegistersChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsCashInCashRegistersChange.AmountChange AS AmountChange,
		|	RegisterRecordsCashInCashRegistersChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsCashInCashRegistersChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsCashInCashRegistersChange.SumCurChange AS SumCurChange
		|FROM
		|	RegisterRecordsCashInCashRegistersChange AS RegisterRecordsCashInCashRegistersChange
		|		LEFT JOIN AccumulationRegister.CashInCashRegisters.Balance(&ControlTime, ) AS CashAssetsInRetailCashesBalances
		|		ON RegisterRecordsCashInCashRegistersChange.Company = CashAssetsInRetailCashesBalances.Company
		|			AND RegisterRecordsCashInCashRegistersChange.CashCR = CashAssetsInRetailCashesBalances.CashCR
		|WHERE
		|	ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty()
			OR Not ResultsArray[4].IsEmpty() Then
			DocumentObjectCashReceipt = DocumentRefCashReceipt.GetObject()
		EndIf;
		
		// Negative balance on cash.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on advance holder payments.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToAdvanceHolderPaymentsRegisterErrors(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			SmallBusinessServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance according to the amount-based account in retail.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			SmallBusinessServer.ShowMessageAboutPostingToRetailAmountAccountingRegisterErrors(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance in cash CR.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			SmallBusinessServer.ErrorMessageOfPostingOnRegisterOfCashAtCashRegisters(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure // RunControl()

#Region PrintInterface

// The function forms the field for printed form as well.
//
// Parameters:      
// SelectionForPrinting - Filter from the query result
//
// Returns: 
//  String       - text of field "including".
//
Function GetTextToo(SelectionForPrinting, PaymentDetails = 21)
	
	TabVAT = PaymentDetails.Unload();

	TabVAT.GroupBy("VATRate", "VATAmount");

	TextAmountOfVat = "";
	
	If TabVAT.Count() > 0 Then
		
		For Each RowVAT IN TabVAT Do
			TextAmountOfVat = TextAmountOfVat
						  + Chars.LF
						  + "VAT ("
						  + ?(NOT ValueIsFilled(RowVAT.VATRate),
							"without tax",
							RowVAT.VATRate)
						  + ") "
						  + Format(RowVAT.VATAmount, "ND=15; NFD=2; NDS=-; NZ=0-00")
						  + " "
						  + SelectionForPrinting.CurrencyPresentation;
		EndDo;
		
	Else
		TextAmountOfVat = TextAmountOfVat
					  + Chars.LF
					  + "VAT (without tax) "
					  + Format(0, "ND=15; NFD=2; NDS=-; NZ=0-00")
					  + " "
					  + SelectionForPrinting.CurrencyPresentation;
	EndIf;

	TextAmountOfVat = Mid(TextAmountOfVat, 2);
	
	Return TextAmountOfVat;
	
EndFunction

// Function generates field SumRubKop for print form.
//
Function DollarsCents(Amount)
	
	Rub = Int(Amount);
	cop = ROUND(100 * (Amount - Rub), 0, 1);
	SumOfRubCop = "" + Rub + " USD " + Int(cop/10) + (cop - 10 * Int(cop / 10)) + " cop.";
	Return SumOfRubCop;
	
EndFunction // RublesKopecks()

// Function generates document printing form by specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects)
	
	//SpreadsheetDocument = New SpreadsheetDocument;
	//
	//Return SpreadsheetDocument;
	
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
	
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
EndProcedure

#EndRegion

#EndIf
