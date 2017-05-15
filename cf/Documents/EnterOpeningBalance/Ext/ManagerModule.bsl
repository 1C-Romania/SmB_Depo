#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generating procedure for the table of invoices for payment.
//
// Parameters:
// DocumentRefEnterOpeningBalance - DocumentRef.EnterOpeningBalance - Current document
// StructureAdditionalProperties - Structure - Additional properties of the document
//
Procedure InitializeInvoicesAndOrdersPaymentDocumentData(DocumentRefEnterOpeningBalance, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefEnterOpeningBalance);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	AccountsReceivable.Ref.Date AS Period,
	|	&Company AS Company,
	|	AccountsReceivable.CustomerOrder AS InvoiceForPayment,
	|	AccountsReceivable.AmountCur AS AdvanceAmount
	|FROM
	|	Document.EnterOpeningBalance.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Counterparty.TrackPaymentsByBills
	|	AND AccountsReceivable.Ref = &Ref
	|	AND AccountsReceivable.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|	AND AccountsReceivable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	AccountsReceivable.Ref.Date,
	|	&Company,
	|	AccountsReceivable.InvoiceForPayment,
	|	AccountsReceivable.AmountCur
	|FROM
	|	Document.EnterOpeningBalance.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Counterparty.TrackPaymentsByBills
	|	AND AccountsReceivable.Ref = &Ref
	|	AND AccountsReceivable.InvoiceForPayment <> VALUE(Document.InvoiceForPayment.EmptyRef)
	|	AND AccountsReceivable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	AccountsPayable.Ref.Date,
	|	&Company,
	|	AccountsPayable.PurchaseOrder,
	|	AccountsPayable.AmountCur
	|FROM
	|	Document.EnterOpeningBalance.AccountsPayable AS AccountsPayable
	|WHERE
	|	AccountsPayable.Counterparty.TrackPaymentsByBills
	|	AND AccountsPayable.Ref = &Ref
	|	AND AccountsPayable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|	AND AccountsPayable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	AccountsPayable.Ref.Date,
	|	&Company,
	|	AccountsPayable.InvoiceForPayment,
	|	AccountsPayable.AmountCur
	|FROM
	|	Document.EnterOpeningBalance.AccountsPayable AS AccountsPayable
	|WHERE
	|	AccountsPayable.Counterparty.TrackPaymentsByBills
	|	AND AccountsPayable.Ref = &Ref
	|	AND AccountsPayable.InvoiceForPayment <> VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
	|	AND AccountsPayable.AdvanceFlag";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure // DocumentDataInitializationInvoicesAndOrdersPayment()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataManagerial(DocumentRefEnterOpeningBalance, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	Managerial.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	Managerial.Amount AS Amount,
	|	CASE
	|		WHEN Managerial.RecordType = VALUE(Enum.DebitCredit.Debit)
	|			THEN Managerial.Account
	|		ELSE VALUE(ChartOfAccounts.Managerial.Service)
	|	END AS AccountDr,
	|	CASE
	|		WHEN Managerial.RecordType = VALUE(Enum.DebitCredit.Debit)
	|			THEN CASE
	|					WHEN Managerial.Account.Currency
	|						THEN Managerial.Currency
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN Managerial.RecordType = VALUE(Enum.DebitCredit.Debit)
	|			THEN CASE
	|					WHEN Managerial.Account.Currency
	|						THEN Managerial.AmountCur
	|					ELSE 0
	|				END
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN Managerial.RecordType = VALUE(Enum.DebitCredit.Debit)
	|			THEN VALUE(ChartOfAccounts.Managerial.Service)
	|		ELSE Managerial.Account
	|	END AS AccountCr,
	|	CASE
	|		WHEN Managerial.RecordType = VALUE(Enum.DebitCredit.Debit)
	|			THEN UNDEFINED
	|		ELSE CASE
	|				WHEN Managerial.Account.Currency
	|					THEN Managerial.Currency
	|				ELSE UNDEFINED
	|			END
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN Managerial.RecordType = VALUE(Enum.DebitCredit.Debit)
	|			THEN 0
	|		ELSE CASE
	|				WHEN Managerial.Account.Currency
	|					THEN Managerial.AmountCur
	|				ELSE 0
	|			END
	|	END AS AmountCurCr,
	|	Managerial.Currency AS Currency,
	|	Managerial.AmountCur AS AmountCur,
	|	&Content AS Content
	|FROM
	|	Document.EnterOpeningBalance.OtherSections AS Managerial
	|WHERE
	|	Managerial.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefEnterOpeningBalance);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Content", NStr("en='Enter opening balance';ru='Ввод начальных остатков'"));
	
	QueryResult = Query.Execute();
	
    StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", QueryResult.Unload());
	
EndProcedure // DocumentDataInitializationManagerial()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAdvanceHolderPayments(DocumentRefEnterOpeningBalance, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	AdvanceHolderPayments.Ref AS Ref,
	|	AdvanceHolderPayments.Ref.Date AS Period,
	|	CASE
	|		WHEN AdvanceHolderPayments.Overrun = TRUE
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		WHEN AdvanceHolderPayments.Overrun = FALSE
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|	END AS RecordType,
	|	MIN(AdvanceHolderPayments.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	AdvanceHolderPayments.Employee AS Employee,
	|	CASE
	|		WHEN AdvanceHolderPayments.Overrun = TRUE
	|			THEN AdvanceHolderPayments.Employee.OverrunGLAccount
	|		WHEN AdvanceHolderPayments.Overrun = FALSE
	|			THEN AdvanceHolderPayments.Employee.AdvanceHoldersGLAccount
	|	END AS GLAccount,
	|	AdvanceHolderPayments.Currency AS Currency,
	|	AdvanceHolderPayments.Document AS Document,
	|	CASE
	|		WHEN AdvanceHolderPayments.Overrun = TRUE
	|			THEN VALUE(AccountingRecordType.Credit)
	|		WHEN AdvanceHolderPayments.Overrun = FALSE
	|			THEN VALUE(AccountingRecordType.Debit)
	|	END AS RecordKindManagerial,
	|	CASE
	|		WHEN AdvanceHolderPayments.Overrun = TRUE
	|			THEN &DebtRepaymentToAdvanceHolder
	|		WHEN AdvanceHolderPayments.Overrun = FALSE
	|			THEN &AdvanceHolderDebtEmergence
	|	END AS ContentOfAccountingRecord,
	|	SUM(AdvanceHolderPayments.AmountCur) AS AmountCur,
	|	SUM(AdvanceHolderPayments.Amount) AS Amount
	|FROM
	|	Document.EnterOpeningBalance.AdvanceHolderPayments AS AdvanceHolderPayments
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|WHERE
	|	AdvanceHolderPayments.Ref = &Ref
	|
	|GROUP BY
	|	Constants.AccountingCurrency,
	|	AdvanceHolderPayments.Ref,
	|	AdvanceHolderPayments.Employee,
	|	AdvanceHolderPayments.Currency,
	|	AdvanceHolderPayments.Document,
	|	AdvanceHolderPayments.Overrun,
	|	AdvanceHolderPayments.Ref.Date,
	|	CASE
	|		WHEN AdvanceHolderPayments.Overrun = TRUE
	|			THEN AdvanceHolderPayments.Employee.OverrunGLAccount
	|		WHEN AdvanceHolderPayments.Overrun = FALSE
	|			THEN AdvanceHolderPayments.Employee.AdvanceHoldersGLAccount
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Employee.AdvanceHoldersGLAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Employee.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Employee.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	VALUE(ChartOfAccounts.Managerial.Service) AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&AdvanceHolderDebtEmergence AS Content
	|FROM
	|	Document.EnterOpeningBalance.AdvanceHolderPayments AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Overrun = FALSE
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.Amount,
	|	VALUE(ChartOfAccounts.Managerial.Service),
	|	UNDEFINED,
	|	0,
	|	DocumentTable.Employee.OverrunGLAccount,
	|	CASE
	|		WHEN DocumentTable.Employee.OverrunGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Employee.OverrunGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	&DebtRepaymentToAdvanceHolder
	|FROM
	|	Document.EnterOpeningBalance.AdvanceHolderPayments AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Overrun = TRUE
	|
	|ORDER BY
	|	Order,
	|	LineNumber");
	
	Query.SetParameter("Ref", DocumentRefEnterOpeningBalance);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AdvanceHolderDebtEmergence", NStr("en='Entering of advance holder debt balances';ru='Ввод остатков задолженности подотчетника'"));
	Query.SetParameter("DebtRepaymentToAdvanceHolder", NStr("en='Entering of advance holder debt residue';ru='Ввод остатков задолженности перед подотчетником'"));
	
	ResultsArray = Query.ExecuteBatch();
	
    StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSettlementsWithAdvanceHolders", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", ResultsArray[1].Unload());
	
EndProcedure // DocumentDataInitializationAdvanceHolderPayments()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataPayrollPayments(DocumentRefEnterOpeningBalance, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	PayrollPayments.Ref AS Ref,
	|	PayrollPayments.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	MIN(PayrollPayments.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	PayrollPayments.StructuralUnit AS StructuralUnit,
	|	PayrollPayments.Employee AS Employee,
	|	PayrollPayments.Employee.SettlementsHumanResourcesGLAccount AS GLAccount,
	|	PayrollPayments.Currency AS Currency,
	|	BEGINOFPERIOD(PayrollPayments.RegistrationPeriod, MONTH) AS RegistrationPeriod,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindManagerial,
	|	&OccurrenceOfObligationsToStaff AS ContentOfAccountingRecord,
	|	SUM(PayrollPayments.AmountCur) AS AmountCur,
	|	SUM(PayrollPayments.Amount) AS Amount
	|FROM
	|	Document.EnterOpeningBalance.PayrollPayments AS PayrollPayments
	|WHERE
	|	PayrollPayments.Ref = &Ref
	|
	|GROUP BY
	|	PayrollPayments.Ref,
	|	PayrollPayments.Employee,
	|	PayrollPayments.StructuralUnit,
	|	PayrollPayments.Currency,
	|	PayrollPayments.RegistrationPeriod,
	|	PayrollPayments.Ref.Date,
	|	PayrollPayments.Employee.SettlementsHumanResourcesGLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	VALUE(ChartOfAccounts.Managerial.Service) AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.Employee.SettlementsHumanResourcesGLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	&OccurrenceOfObligationsToStaff AS Content
	|FROM
	|	Document.EnterOpeningBalance.PayrollPayments AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefEnterOpeningBalance);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("OccurrenceOfObligationsToStaff", NStr("en='Appearence of liability to staff';ru='Возникновение обязательств перед персоналом'"));
	
	ResultsArray = Query.ExecuteBatch();
	
    StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePayrollPayments", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", ResultsArray[1].Unload());
	
EndProcedure // DocumentDataInitializationPayrollPayments()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataTaxesSettlements(DocumentRefEnterOpeningBalance, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	TaxesSettlements.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	MIN(TaxesSettlements.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	TaxesSettlements.TaxKind AS TaxKind,
	|	TaxesSettlements.TaxKind.GLAccount AS GLAccount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindManagerial,
	|	&TaxAccrual AS ContentOfAccountingRecord,
	|	SUM(TaxesSettlements.Amount) AS Amount
	|FROM
	|	Document.EnterOpeningBalance.TaxesSettlements AS TaxesSettlements
	|WHERE
	|	TaxesSettlements.Ref = &Ref
	|
	|GROUP BY
	|	TaxesSettlements.Ref,
	|	TaxesSettlements.TaxKind,
	|	TaxesSettlements.Ref.Date,
	|	TaxesSettlements.TaxKind.GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	VALUE(ChartOfAccounts.Managerial.Service) AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.TaxKind.GLAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&TaxAccrual AS Content
	|FROM
	|	Document.EnterOpeningBalance.TaxesSettlements AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefEnterOpeningBalance);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("TaxAccrual", NStr("en='Entering the debts balance to the budget';ru='Ввод остатков задолженности перед бюджетом'"));
	
	ResultsArray = Query.ExecuteBatch();
	
    StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxAccounting", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", ResultsArray[1].Unload());
	
EndProcedure // DocumentDataInitializationTaxesSettlements()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAccountsReceivable(DocumentRefEnterOpeningBalance, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	AccountsReceivable.Ref.Date AS Period,
	|	CASE
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		ELSE VALUE(AccumulationRecordType.Receipt)
	|	END AS RecordType,
	|	MIN(AccountsReceivable.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	AccountsReceivable.Counterparty AS Counterparty,
	|	AccountsReceivable.Contract AS Contract,
	|	CASE
	|		WHEN AccountsReceivable.Counterparty.DoOperationsByOrders
	|			THEN AccountsReceivable.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS Order,
	|	CASE
	|		WHEN AccountsReceivable.Counterparty.DoOperationsByDocuments
	|			THEN AccountsReceivable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	AccountsReceivable.Contract.SettlementsCurrency AS Currency,
	|	CASE
	|		WHEN Not AccountsReceivable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Debt)
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|	END AS SettlementsType,
	|	CASE
	|		WHEN Not AccountsReceivable.AdvanceFlag
	|			THEN VALUE(AccountingRecordType.Debit)
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN VALUE(AccountingRecordType.Credit)
	|	END AS RecordKindManagerial,
	|	CASE
	|		WHEN Not AccountsReceivable.AdvanceFlag
	|			THEN &AppearenceOfCustomerLiability
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN &CustomerObligationsRepayment
	|	END AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN Not AccountsReceivable.AdvanceFlag
	|			THEN AccountsReceivable.Counterparty.GLAccountCustomerSettlements
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN AccountsReceivable.Counterparty.CustomerAdvancesGLAccount
	|	END AS GLAccount,
	|	SUM(AccountsReceivable.AmountCur) AS AmountCur,
	|	SUM(AccountsReceivable.Amount) AS Amount
	|FROM
	|	Document.EnterOpeningBalance.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Ref = &Ref
	|
	|GROUP BY
	|	AccountsReceivable.Counterparty,
	|	AccountsReceivable.Contract,
	|	AccountsReceivable.AdvanceFlag,
	|	AccountsReceivable.CustomerOrder,
	|	AccountsReceivable.Document,
	|	AccountsReceivable.Ref,
	|	AccountsReceivable.Ref.Date,
	|	CASE
	|		WHEN Not AccountsReceivable.AdvanceFlag
	|			THEN AccountsReceivable.Counterparty.GLAccountCustomerSettlements
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN AccountsReceivable.Counterparty.CustomerAdvancesGLAccount
	|	END,
	|	AccountsReceivable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN AccountsReceivable.Counterparty.DoOperationsByOrders
	|			THEN AccountsReceivable.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END,
	|	CASE
	|		WHEN AccountsReceivable.Counterparty.DoOperationsByDocuments
	|			THEN AccountsReceivable.Document
	|		ELSE UNDEFINED
	|	END
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Counterparty.GLAccountCustomerSettlements AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Counterparty.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Counterparty.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	VALUE(ChartOfAccounts.Managerial.Service) AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&AppearenceOfCustomerLiability AS Content
	|FROM
	|	Document.EnterOpeningBalance.AccountsReceivable AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND Not DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.Amount,
	|	VALUE(ChartOfAccounts.Managerial.Service),
	|	UNDEFINED,
	|	0,
	|	DocumentTable.Counterparty.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Counterparty.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Counterparty.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	&CustomerObligationsRepayment
	|FROM
	|	Document.EnterOpeningBalance.AccountsReceivable AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	Order,
	|	LineNumber");
	
	Query.SetParameter("Ref", DocumentRefEnterOpeningBalance);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerLiability", NStr("en='Entering of customers debt balances';ru='Ввод остатков задолженности покупателей'"));
	Query.SetParameter("CustomerObligationsRepayment", NStr("en='Balance entering of customers advances';ru='Ввод остатков авансов от покупателей'"));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", ResultsArray[1].Unload());
	
EndProcedure // DocumentDataInitializationAccountsReceivable()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAccountsPayable(DocumentRefEnterOpeningBalance, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	AccountsPayable.Ref.Date AS Period,
	|	CASE
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		ELSE VALUE(AccumulationRecordType.Receipt)
	|	END AS RecordType,
	|	MIN(AccountsPayable.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	AccountsPayable.Counterparty AS Counterparty,
	|	AccountsPayable.Contract AS Contract,
	|	CASE
	|		WHEN AccountsPayable.Counterparty.DoOperationsByOrders
	|			THEN AccountsPayable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	CASE
	|		WHEN AccountsPayable.Counterparty.DoOperationsByDocuments
	|			THEN AccountsPayable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	AccountsPayable.Contract.SettlementsCurrency AS Currency,
	|	CASE
	|		WHEN Not AccountsPayable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Debt)
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|	END AS SettlementsType,
	|	CASE
	|		WHEN Not AccountsPayable.AdvanceFlag
	|			THEN VALUE(AccountingRecordType.Credit)
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN VALUE(AccountingRecordType.Debit)
	|	END AS RecordKindManagerial,
	|	CASE
	|		WHEN Not AccountsPayable.AdvanceFlag
	|			THEN &AppearenceOfLiabilityToVendor
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN &VendorObligationsRepayment
	|	END AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN Not AccountsPayable.AdvanceFlag
	|			THEN AccountsPayable.Counterparty.GLAccountVendorSettlements
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN AccountsPayable.Counterparty.VendorAdvancesGLAccount
	|	END AS GLAccount,
	|	SUM(AccountsPayable.AmountCur) AS AmountCur,
	|	SUM(AccountsPayable.Amount) AS Amount
	|FROM
	|	Document.EnterOpeningBalance.AccountsPayable AS AccountsPayable
	|WHERE
	|	AccountsPayable.Ref = &Ref
	|
	|GROUP BY
	|	AccountsPayable.Counterparty,
	|	AccountsPayable.Contract,
	|	AccountsPayable.AdvanceFlag,
	|	AccountsPayable.PurchaseOrder,
	|	AccountsPayable.Document,
	|	AccountsPayable.Ref,
	|	AccountsPayable.Ref.Date,
	|	CASE
	|		WHEN Not AccountsPayable.AdvanceFlag
	|			THEN AccountsPayable.Counterparty.GLAccountVendorSettlements
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN AccountsPayable.Counterparty.VendorAdvancesGLAccount
	|	END,
	|	AccountsPayable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN AccountsPayable.Counterparty.DoOperationsByOrders
	|			THEN AccountsPayable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	CASE
	|		WHEN AccountsPayable.Counterparty.DoOperationsByDocuments
	|			THEN AccountsPayable.Document
	|		ELSE UNDEFINED
	|	END
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	VALUE(ChartOfAccounts.Managerial.Service) AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.Counterparty.GLAccountVendorSettlements AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	&AppearenceOfLiabilityToVendor AS Content
	|FROM
	|	Document.EnterOpeningBalance.AccountsPayable AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND Not DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.Amount,
	|	DocumentTable.Counterparty.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	VALUE(ChartOfAccounts.Managerial.Service),
	|	UNDEFINED,
	|	0,
	|	&VendorObligationsRepayment
	|FROM
	|	Document.EnterOpeningBalance.AccountsPayable AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	Order,
	|	LineNumber");
 
	Query.SetParameter("Ref", DocumentRefEnterOpeningBalance);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfLiabilityToVendor", NStr("en='Entering debt balances to suppliers';ru='Ввод остатков задолженности поставщикам'"));
	Query.SetParameter("VendorObligationsRepayment", NStr("en='Entering the balances of advances to suppliers';ru='Ввод остатков авансов поставщикам'"));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[0].Unload());
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Count() > 0 Then
		Selection = ResultsArray[1].Select();
		While Selection.Next() Do
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", ResultsArray[1].Unload());
	EndIf;
	
EndProcedure // DocumentDataInitializationAccountsPayable()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIncomeAndExpensesUndistributed(DocumentRefEnterOpeningBalance, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = Type(Document.ExpenseReport)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	Document.EnterOpeningBalance.AccountsPayable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	DocumentTable.Document,
	|	DocumentTable.Document.Item,
	|	DocumentTable.Amount,
	|	0
	|FROM
	|	Document.EnterOpeningBalance.AccountsReceivable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	LineNumber");
 
	Query.SetParameter("Ref", DocumentRefEnterOpeningBalance);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	QueryResult = Query.Execute();
	
    StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesUndistributed", QueryResult.Unload());
		
EndProcedure // DocumentDataInitializationIncomeAndExpensesUndistributed()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIncomeAndExpensesCashMethod(DocumentRefEnterOpeningBalance, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	UNDEFINED AS BusinessActivity,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = Type(Document.ExpenseReport)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	Document.EnterOpeningBalance.AccountsPayable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	UNDEFINED,
	|	DocumentTable.Document.Item,
	|	DocumentTable.Amount,
	|	0
	|FROM
	|	Document.EnterOpeningBalance.AccountsReceivable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	DocumentTable.LineNumber");
 
	Query.SetParameter("Ref", DocumentRefEnterOpeningBalance);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure // DocumentDataInitializationIncomeAndExpensesCashMethod()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIncomeAndExpensesRetained(DocumentRefEnterOpeningBalance, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Document AS Document,
	|	VALUE(Catalog.BusinessActivities.MainActivity) AS BusinessActivity,
	|	0 AS AmountIncome,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	Document.EnterOpeningBalance.AccountsPayable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (NOT DocumentTable.AdvanceFlag)
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	DocumentTable.Document,
	|	VALUE(Catalog.BusinessActivities.MainActivity),
	|	DocumentTable.Amount,
	|	0
	|FROM
	|	Document.EnterOpeningBalance.AccountsReceivable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (NOT DocumentTable.AdvanceFlag)
	|
	|ORDER BY
	|	LineNumber");

	Query.SetParameter("Ref", DocumentRefEnterOpeningBalance);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesRetained()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DocumentDataInitializationCashAssets(DocumentRefEnterOpeningBalance, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	CashAssets.Ref.Date AS Period,
	|	MIN(CashAssets.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	CASE
	|		WHEN VALUETYPE(CashAssets.BankAccountPettyCash) = Type(Catalog.PettyCashes)
	|			THEN VALUE(Enum.CashAssetTypes.Cash)
	|		ELSE VALUE(Enum.CashAssetTypes.Noncash)
	|	END AS CashAssetsType,
	|	CashAssets.BankAccountPettyCash AS BankAccountPettyCash,
	|	CashAssets.CashCurrency AS Currency,
	|	CashAssets.BankAccountPettyCash.GLAccount AS GLAccount,
	|	&ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SUM(CashAssets.AmountCur) AS AmountCur,
	|	SUM(CashAssets.Amount) AS Amount
	|FROM
	|	Document.EnterOpeningBalance.CashAssets AS CashAssets
	|WHERE
	|	CashAssets.Ref = &Ref
	|
	|GROUP BY
	|	CashAssets.Ref,
	|	CashAssets.CashCurrency,
	|	CASE
	|		WHEN VALUETYPE(CashAssets.BankAccountPettyCash) = Type(Catalog.PettyCashes)
	|			THEN VALUE(Enum.CashAssetTypes.Cash)
	|		ELSE VALUE(Enum.CashAssetTypes.Noncash)
	|	END,
	|	CashAssets.BankAccountPettyCash,
	|	CashAssets.Ref.Date,
	|	CashAssets.BankAccountPettyCash.GLAccount
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.BankAccountPettyCash.GLAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.BankAccountPettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.BankAccountPettyCash.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	VALUE(ChartOfAccounts.Managerial.Service) AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&ContentOfAccountingRecord AS Content
	|FROM
	|	Document.EnterOpeningBalance.CashAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefEnterOpeningBalance);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ContentOfAccountingRecord", NStr("en='Entering of the cash funds balances';ru='Ввод остатков денежных средств'"));
		
	ResultsArray = Query.ExecuteBatch();
	
    StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashAssets", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", ResultsArray[1].Unload());
	
EndProcedure // DocumentDataInitializationCashAssets()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeInventoryDocumentData(DocumentRefEnterOpeningBalance, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	EnterOpeningBalanceInventory.Order AS Order,
	|	EnterOpeningBalanceInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	EnterOpeningBalanceInventory.Period AS Period,
	|	EnterOpeningBalanceInventory.Company AS Company,
	|	EnterOpeningBalanceInventory.StructuralUnit AS StructuralUnit,
	|	EnterOpeningBalanceInventory.GLAccount AS GLAccount,
	|	EnterOpeningBalanceInventory.ProductsAndServices AS ProductsAndServices,
	|	EnterOpeningBalanceInventory.Characteristic AS Characteristic,
	|	EnterOpeningBalanceInventory.Batch AS Batch,
	|	EnterOpeningBalanceInventory.CustomerOrder AS CustomerOrder,
	|	EnterOpeningBalanceInventory.Quantity AS Quantity,
	|	EnterOpeningBalanceInventory.Amount AS Amount,
	|	TRUE AS FixedCost,
	|	EnterOpeningBalanceInventory.RecordKindManagerial AS RecordKindManagerial,
	|	EnterOpeningBalanceInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord
	|FROM
	|	(SELECT
	|		0 AS Order,
	|		EnterOpeningBalanceInventory.LineNumber AS LineNumber,
	|		EnterOpeningBalanceInventory.Ref.Date AS Period,
	|		&Company AS Company,
	|		EnterOpeningBalanceInventory.StructuralUnit AS StructuralUnit,
	|		CASE
	|			WHEN EnterOpeningBalanceInventory.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					OR EnterOpeningBalanceInventory.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|				THEN EnterOpeningBalanceInventory.ProductsAndServices.InventoryGLAccount
	|			ELSE EnterOpeningBalanceInventory.ProductsAndServices.ExpensesGLAccount
	|		END AS GLAccount,
	|		EnterOpeningBalanceInventory.ProductsAndServices AS ProductsAndServices,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN EnterOpeningBalanceInventory.Characteristic
	|			ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|		END AS Characteristic,
	|		CASE
	|			WHEN &UseBatches
	|				THEN EnterOpeningBalanceInventory.Batch
	|			ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|		END AS Batch,
	|		EnterOpeningBalanceInventory.CustomerOrder AS CustomerOrder,
	|		CASE
	|			WHEN VALUETYPE(EnterOpeningBalanceInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN EnterOpeningBalanceInventory.Quantity
	|			ELSE EnterOpeningBalanceInventory.Quantity * EnterOpeningBalanceInventory.MeasurementUnit.Factor
	|		END AS Quantity,
	|		EnterOpeningBalanceInventory.Amount AS Amount,
	|		VALUE(AccountingRecordType.Debit) AS RecordKindManagerial,
	|		&InventoryReceipt AS ContentOfAccountingRecord
	|	FROM
	|		Document.EnterOpeningBalance.Inventory AS EnterOpeningBalanceInventory
	|	WHERE
	|		EnterOpeningBalanceInventory.Ref = &Ref
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		1,
	|		EnteringOpeningBalancesDirectCost.LineNumber,
	|		EnteringOpeningBalancesDirectCost.Ref.Date,
	|		&Company,
	|		EnteringOpeningBalancesDirectCost.StructuralUnit,
	|		EnteringOpeningBalancesDirectCost.GLExpenseAccount,
	|		VALUE(Catalog.ProductsAndServices.EmptyRef),
	|		VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef),
	|		VALUE(Catalog.ProductsAndServicesBatches.EmptyRef),
	|		EnteringOpeningBalancesDirectCost.CustomerOrder,
	|		0,
	|		EnteringOpeningBalancesDirectCost.Amount,
	|		VALUE(AccountingRecordType.Debit),
	|		&ExpediturePosting
	|	FROM
	|		Document.EnterOpeningBalance.DirectCost AS EnteringOpeningBalancesDirectCost
	|	WHERE
	|		EnteringOpeningBalancesDirectCost.Ref = &Ref
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		2,
	|		EnterOpeningBalanceInventoryReceived.LineNumber,
	|		EnterOpeningBalanceInventoryReceived.Ref.Date,
	|		&Company,
	|		EnterOpeningBalanceInventoryReceived.StructuralUnit,
	|		EnterOpeningBalanceInventoryReceived.ProductsAndServices.InventoryGLAccount,
	|		EnterOpeningBalanceInventoryReceived.ProductsAndServices,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN EnterOpeningBalanceInventoryReceived.Characteristic
	|			ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|		END,
	|		CASE
	|			WHEN &UseBatches
	|				THEN EnterOpeningBalanceInventoryReceived.Batch
	|			ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|		END,
	|		CASE
	|			WHEN EnterOpeningBalanceInventoryReceived.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReceptionIntoProcessing)
	|					AND (NOT &UseReservation)
	|				THEN VALUE(Document.CustomerOrder.EmptyRef)
	|			ELSE EnterOpeningBalanceInventoryReceived.Order
	|		END,
	|		CASE
	|			WHEN VALUETYPE(EnterOpeningBalanceInventoryReceived.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN EnterOpeningBalanceInventoryReceived.Quantity
	|			ELSE EnterOpeningBalanceInventoryReceived.Quantity * EnterOpeningBalanceInventoryReceived.MeasurementUnit.Factor
	|		END,
	|		0,
	|		VALUE(AccountingRecordType.Debit),
	|		&InventoryAcceptedReceiving
	|	FROM
	|		Document.EnterOpeningBalance.InventoryReceived AS EnterOpeningBalanceInventoryReceived
	|	WHERE
	|		EnterOpeningBalanceInventoryReceived.Ref = &Ref
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		3,
	|		EnterOpeningBalanceInventoryTransferred.LineNumber,
	|		EnterOpeningBalanceInventoryTransferred.Ref.Date,
	|		&Company,
	|		EnterOpeningBalanceInventoryTransferred.Counterparty,
	|		EnterOpeningBalanceInventoryTransferred.ProductsAndServices.InventoryGLAccount,
	|		EnterOpeningBalanceInventoryTransferred.ProductsAndServices,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN EnterOpeningBalanceInventoryTransferred.Characteristic
	|			ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|		END,
	|		CASE
	|			WHEN &UseBatches
	|				THEN EnterOpeningBalanceInventoryTransferred.Batch
	|			ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|		END,
	|		EnterOpeningBalanceInventoryTransferred.Order,
	|		CASE
	|			WHEN VALUETYPE(EnterOpeningBalanceInventoryTransferred.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN EnterOpeningBalanceInventoryTransferred.Quantity
	|			ELSE EnterOpeningBalanceInventoryTransferred.Quantity * EnterOpeningBalanceInventoryTransferred.MeasurementUnit.Factor
	|		END,
	|		EnterOpeningBalanceInventoryTransferred.Cost,
	|		VALUE(AccountingRecordType.Debit),
	|		&TransferredInventoryReceipt
	|	FROM
	|		Document.EnterOpeningBalance.InventoryTransferred AS EnterOpeningBalanceInventoryTransferred
	|	WHERE
	|		EnterOpeningBalanceInventoryTransferred.Ref = &Ref) AS EnterOpeningBalanceInventory
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	0 AS Order,
	|	EnterOpeningBalanceInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	EnterOpeningBalanceInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	EnterOpeningBalanceInventory.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN EnterOpeningBalanceInventory.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	EnterOpeningBalanceInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN EnterOpeningBalanceInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN EnterOpeningBalanceInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(EnterOpeningBalanceInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN EnterOpeningBalanceInventory.Quantity
	|		ELSE EnterOpeningBalanceInventory.Quantity * EnterOpeningBalanceInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.EnterOpeningBalance.Inventory AS EnterOpeningBalanceInventory
	|WHERE
	|	EnterOpeningBalanceInventory.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	EnterOpeningBalanceInventoryReceived.LineNumber,
	|	VALUE(AccumulationRecordType.Receipt),
	|	EnterOpeningBalanceInventoryReceived.Ref.Date,
	|	&Company,
	|	EnterOpeningBalanceInventoryReceived.StructuralUnit,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN EnterOpeningBalanceInventoryReceived.Cell
	|		ELSE UNDEFINED
	|	END,
	|	EnterOpeningBalanceInventoryReceived.ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN EnterOpeningBalanceInventoryReceived.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseBatches
	|			THEN EnterOpeningBalanceInventoryReceived.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(EnterOpeningBalanceInventoryReceived.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN EnterOpeningBalanceInventoryReceived.Quantity
	|		ELSE EnterOpeningBalanceInventoryReceived.Quantity * EnterOpeningBalanceInventoryReceived.MeasurementUnit.Factor
	|	END
	|FROM
	|	Document.EnterOpeningBalance.InventoryReceived AS EnterOpeningBalanceInventoryReceived
	|WHERE
	|	EnterOpeningBalanceInventoryReceived.Ref = &Ref
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	EnterOpeningBalanceInventoryTransferred.Ref.Date AS Period,
	|	EnterOpeningBalanceInventoryTransferred.LineNumber,
	|	&Company AS Company,
	|	CASE
	|		WHEN EnterOpeningBalanceInventoryTransferred.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|			THEN VALUE(Enum.ProductsReceiptTransferTypes.TransferToAgent)
	|		WHEN EnterOpeningBalanceInventoryTransferred.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|			THEN VALUE(Enum.ProductsReceiptTransferTypes.TransferToProcessing)
	|		WHEN EnterOpeningBalanceInventoryTransferred.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN VALUE(Enum.ProductsReceiptTransferTypes.SafeCustody)
	|		ELSE FALSE
	|	END AS ReceptionTransmissionType,
	|	EnterOpeningBalanceInventoryTransferred.Counterparty,
	|	EnterOpeningBalanceInventoryTransferred.Contract,
	|	CASE
	|		WHEN EnterOpeningBalanceInventoryTransferred.Order REFS Document.CustomerOrder
	|				AND EnterOpeningBalanceInventoryTransferred.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN EnterOpeningBalanceInventoryTransferred.Order
	|		WHEN EnterOpeningBalanceInventoryTransferred.Order REFS Document.PurchaseOrder
	|				AND EnterOpeningBalanceInventoryTransferred.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN EnterOpeningBalanceInventoryTransferred.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	EnterOpeningBalanceInventoryTransferred.ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN EnterOpeningBalanceInventoryTransferred.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN EnterOpeningBalanceInventoryTransferred.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	EnterOpeningBalanceInventoryTransferred.MeasurementUnit,
	|	CASE
	|		WHEN VALUETYPE(EnterOpeningBalanceInventoryTransferred.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN EnterOpeningBalanceInventoryTransferred.Quantity
	|		ELSE EnterOpeningBalanceInventoryTransferred.Quantity * EnterOpeningBalanceInventoryTransferred.MeasurementUnit.Factor
	|	END AS Quantity,
	|	EnterOpeningBalanceInventoryTransferred.SettlementsAmount
	|FROM
	|	Document.EnterOpeningBalance.InventoryTransferred AS EnterOpeningBalanceInventoryTransferred
	|WHERE
	|	EnterOpeningBalanceInventoryTransferred.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	EnterOpeningBalanceInventoryReceived.Ref.Date AS Period,
	|	EnterOpeningBalanceInventoryReceived.LineNumber,
	|	&Company AS Company,
	|	CASE
	|		WHEN EnterOpeningBalanceInventoryReceived.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReceptionForCommission)
	|			THEN VALUE(Enum.ProductsReceiptTransferTypes.ReceiptFromPrincipal)
	|		WHEN EnterOpeningBalanceInventoryReceived.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReceptionIntoProcessing)
	|			THEN VALUE(Enum.ProductsReceiptTransferTypes.ReceiptToProcessing)
	|		WHEN EnterOpeningBalanceInventoryReceived.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReceptionForSafeCustody)
	|			THEN VALUE(Enum.ProductsReceiptTransferTypes.SafeCustody)
	|		ELSE FALSE
	|	END AS ReceptionTransmissionType,
	|	EnterOpeningBalanceInventoryReceived.Counterparty AS Counterparty,
	|	EnterOpeningBalanceInventoryReceived.Contract AS Contract,
	|	CASE
	|		WHEN EnterOpeningBalanceInventoryReceived.Order REFS Document.CustomerOrder
	|				AND EnterOpeningBalanceInventoryReceived.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN EnterOpeningBalanceInventoryReceived.Order
	|		WHEN EnterOpeningBalanceInventoryReceived.Order REFS Document.PurchaseOrder
	|				AND EnterOpeningBalanceInventoryReceived.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN EnterOpeningBalanceInventoryReceived.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	EnterOpeningBalanceInventoryReceived.StructuralUnit AS StructuralUnit,
	|	EnterOpeningBalanceInventoryReceived.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN EnterOpeningBalanceInventoryReceived.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN EnterOpeningBalanceInventoryReceived.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(EnterOpeningBalanceInventoryReceived.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN EnterOpeningBalanceInventoryReceived.Quantity
	|		ELSE EnterOpeningBalanceInventoryReceived.Quantity * EnterOpeningBalanceInventoryReceived.MeasurementUnit.Factor
	|	END AS Quantity,
	|	EnterOpeningBalanceInventoryReceived.SettlementsAmount AS SettlementsAmount,
	|	EnterOpeningBalanceInventoryReceived.SettlementsAmount AS Amount,
	|	EnterOpeningBalanceInventoryReceived.ProductsAndServices.InventoryGLAccount AS GLAccount,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindManagerial,
	|	&InventoryReception AS ContentOfAccountingRecord
	|FROM
	|	Document.EnterOpeningBalance.InventoryReceived AS EnterOpeningBalanceInventoryReceived
	|WHERE
	|	EnterOpeningBalanceInventoryReceived.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OpeningBalancesForInventoryByEnteringCCD.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OpeningBalancesForInventoryByEnteringCCD.Ref.Date AS Period,
	|	&Company AS Company,
	|	OpeningBalancesForInventoryByEnteringCCD.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OpeningBalancesForInventoryByEnteringCCD.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN OpeningBalancesForInventoryByEnteringCCD.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	OpeningBalancesForInventoryByEnteringCCD.CCDNo AS CCDNo,
	|	OpeningBalancesForInventoryByEnteringCCD.CountryOfOrigin AS CountryOfOrigin,
	|	CASE
	|		WHEN VALUETYPE(OpeningBalancesForInventoryByEnteringCCD.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN OpeningBalancesForInventoryByEnteringCCD.Quantity
	|		ELSE OpeningBalancesForInventoryByEnteringCCD.Quantity * OpeningBalancesForInventoryByEnteringCCD.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.EnterOpeningBalance.InventoryByCCD AS OpeningBalancesForInventoryByEnteringCCD
	|WHERE
	|	OpeningBalancesForInventoryByEnteringCCD.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	CASE
	|		WHEN DocumentTable.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|				OR DocumentTable.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|			THEN DocumentTable.ProductsAndServices.InventoryGLAccount
	|		ELSE DocumentTable.ProductsAndServices.ExpensesGLAccount
	|	END AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	VALUE(ChartOfAccounts.Managerial.Service) AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&InventoryReceipt AS Content
	|FROM
	|	Document.EnterOpeningBalance.Inventory AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.Amount,
	|	DocumentTable.GLExpenseAccount,
	|	UNDEFINED,
	|	0,
	|	VALUE(ChartOfAccounts.Managerial.Service),
	|	UNDEFINED,
	|	0,
	|	&ExpediturePosting
	|FROM
	|	Document.EnterOpeningBalance.DirectCost AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.Cost,
	|	DocumentTable.ProductsAndServices.InventoryGLAccount,
	|	UNDEFINED,
	|	0,
	|	VALUE(ChartOfAccounts.Managerial.Service),
	|	UNDEFINED,
	|	0,
	|	&TransferredInventoryReceipt
	|FROM
	|	Document.EnterOpeningBalance.InventoryTransferred AS DocumentTable
	|WHERE
	|	DocumentTable.Cost <> 0
	|	AND DocumentTable.Ref = &Ref
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Ref.Date AS Period,
	|	TableInventory.Ref.Date AS EventDate,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Cell AS Cell,
	|	1 AS Quantity
	|FROM
	|	Document.EnterOpeningBalance.Inventory AS TableInventory
	|		INNER JOIN Document.EnterOpeningBalance.SerialNumbers AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|		AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	TableInventory.Ref = &Ref AND TableSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers");
	
	Query.SetParameter("Ref", DocumentRefEnterOpeningBalance);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	Query.SetParameter("UseReservation", Constants.FunctionalOptionInventoryReservation.Get());
	Query.SetParameter("InventoryReceipt", NStr("ru = 'Прием запасов'; en = 'Inventory receiving'"));
	Query.SetParameter("ExpediturePosting", NStr("ru = 'Оприходование затрат'; en = 'Expediture posting'"));
	Query.SetParameter("InventoryAcceptedReceiving", NStr("ru = 'Оприходование запасов принятых'; en = 'Receipt of received inventory'"));
	Query.SetParameter("TransferredInventoryReceipt", NStr("ru = 'Оприходование запасов переданных'; en = 'Receipt of the inventories transferred'"));
	Query.SetParameter("InventoryReception", NStr("ru = 'Прием запасов'; en = 'Inventory receiving'"));
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	ResultsArray = Query.ExecuteBatch();
	
    StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryTransferred", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryReceived", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryByCCD", ResultsArray[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", ResultsArray[5].Unload());
	
	// Serial numbers
	QueryResult = ResultsArray[6].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersGuarantees", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf;

EndProcedure // DocumentDataInitializationInventory()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationFixedAssetsDataInitialization(DocumentRefEnterOpeningBalance, StructureAdditionalProperties)

	Query = New Query(
	"SELECT
	|	DocumentTable.Ref.Date AS Date,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.FixedAsset.DepreciationMethod AS DepreciationMethod,
	|	DocumentTable.FixedAsset.InitialCost AS OriginalCost,
	|	DocumentTable.FixedAssetCurrentCondition AS FixedAssetCurrentCondition,
	|	DocumentTable.CurrentOutputQuantity AS CurrentOutputQuantity,
	|	DocumentTable.CurrentDepreciationAccrued AS CurrentDepreciationAccrued,
	|	DocumentTable.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	TRUE AS EnterIntoService,
	|	DocumentTable.AccrueDepreciation AS AccrueDepreciation,
	|	CASE
	|		WHEN DocumentTable.CurrentDepreciationAccrued <> 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AccrueDepreciationInCurrentMonth,
	|	DocumentTable.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	DocumentTable.GLExpenseAccount AS GLExpenseAccount,
	|	DocumentTable.BusinessActivity AS BusinessActivity
	|INTO TemporaryTableFixedAssets
	|FROM
	|	Document.EnterOpeningBalance.FixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	&Company AS Company,
	|	DocumentTable.FixedAssetCurrentCondition AS State,
	|	DocumentTable.AccrueDepreciation AS AccrueDepreciation,
	|	DocumentTable.AccrueDepreciationInCurrentMonth AS AccrueDepreciationInCurrentMonth
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	&Company AS Company,
	|	DocumentTable.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DocumentTable.OriginalCost AS CostForDepreciationCalculation,
	|	DocumentTable.AccrueDepreciationInCurrentMonth AS ApplyInCurrentMonth,
	|	DocumentTable.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	DocumentTable.GLExpenseAccount AS GLExpenseAccount,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.BusinessActivity AS BusinessActivity
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.OriginalCost AS Cost,
	|	0 AS Depreciation,
	|	&FixedAssetAcceptanceForAccounting AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.OriginalCost > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	VALUE(AccumulationRecordType.Receipt),
	|	&Company,
	|	DocumentTable.FixedAsset,
	|	0,
	|	DocumentTable.CurrentDepreciationAccrued,
	|	&DepreciationAccrual
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.CurrentDepreciationAccrued > 0
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.CurrentOutputQuantity AS Quantity
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.DepreciationMethod = VALUE(Enum.FixedAssetsDepreciationMethods.ProportionallyToProductsVolume)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.OriginalCost AS Amount,
	|	DocumentTable.FixedAsset.GLAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.FixedAsset.GLAccount.Currency
	|			THEN UNDEFINED
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.FixedAsset.GLAccount.Currency
	|			THEN 0
	|		ELSE 0
	|	END AS AmountCurDr,
	|	VALUE(ChartOfAccounts.Managerial.Service) AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&FixedAssetAcceptanceForAccounting AS Content
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.OriginalCost > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.CurrentDepreciationAccrued,
	|	VALUE(ChartOfAccounts.Managerial.Service),
	|	UNDEFINED,
	|	0,
	|	DocumentTable.FixedAsset.DepreciationAccount,
	|	CASE
	|		WHEN DocumentTable.FixedAsset.DepreciationAccount.Currency
	|			THEN UNDEFINED
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.FixedAsset.DepreciationAccount.Currency
	|			THEN 0
	|		ELSE 0
	|	END,
	|	&DepreciationAccrual
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.CurrentDepreciationAccrued > 0
	|
	|ORDER BY
	|	Order,
	|	LineNumber");
	
	Query.SetParameter("Ref", DocumentRefEnterOpeningBalance);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("FixedAssetAcceptanceForAccounting", NStr("en='Enter opening balance for fixed assets';ru='Ввод начальных остатков по внеоборотным активам'"));
	Query.SetParameter("DepreciationAccrual", NStr("en='Entry of opening balances for depreciation';ru='Ввод начальных остатков по амортизации'"));
	
	ResultsArray = Query.ExecuteBatch();

    StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetsStates", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetsParameters", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssets", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetsOutput", ResultsArray[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", ResultsArray[5].Unload());

EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefEnterOpeningBalance, StructureAdditionalProperties) Export

	AccountingSection = DocumentRefEnterOpeningBalance.AccountingSection;

	If      AccountingSection = "Property" Then

		DataInitializationFixedAssetsDataInitialization(DocumentRefEnterOpeningBalance, StructureAdditionalProperties);

	ElsIf AccountingSection = "Inventory" Then

		InitializeInventoryDocumentData(DocumentRefEnterOpeningBalance, StructureAdditionalProperties);

	ElsIf AccountingSection = "Cash assets" Then

		DocumentDataInitializationCashAssets(DocumentRefEnterOpeningBalance, StructureAdditionalProperties);

	ElsIf AccountingSection = "Settlements with suppliers and customers" Then

		InitializeDocumentDataAccountsReceivable(DocumentRefEnterOpeningBalance, StructureAdditionalProperties);
		InitializeDocumentDataAccountsPayable(DocumentRefEnterOpeningBalance, StructureAdditionalProperties);
		InitializeDocumentDataIncomeAndExpensesUndistributed(DocumentRefEnterOpeningBalance, StructureAdditionalProperties);
		InitializeDocumentDataIncomeAndExpensesCashMethod(DocumentRefEnterOpeningBalance, StructureAdditionalProperties);
		InitializeDocumentDataIncomeAndExpensesRetained(DocumentRefEnterOpeningBalance, StructureAdditionalProperties);
		InitializeInvoicesAndOrdersPaymentDocumentData(DocumentRefEnterOpeningBalance, StructureAdditionalProperties);
		
	ElsIf AccountingSection = "Tax settlements" Then

		InitializeDocumentDataTaxesSettlements(DocumentRefEnterOpeningBalance, StructureAdditionalProperties);

	ElsIf AccountingSection = "Personnel settlements" Then

		InitializeDocumentDataPayrollPayments(DocumentRefEnterOpeningBalance, StructureAdditionalProperties);

	ElsIf AccountingSection = "Settlements with advance holders" Then
		
		InitializeDocumentDataAdvanceHolderPayments(DocumentRefEnterOpeningBalance, StructureAdditionalProperties);

	ElsIf AccountingSection = "Other sections" Then

		InitializeDocumentDataManagerial(DocumentRefEnterOpeningBalance, StructureAdditionalProperties);

	EndIf;

EndProcedure // DocumentDataInitialization()

// Control

// Control of the accounting section CashAssets.
//
Procedure RunControlCashAssets(DocumentRefEnterOpeningBalance, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables
	// "RegisterRecordsCashAssetsChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsCashAssetsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsCashAssetsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsCashAssetsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsCashAssetsChange.BankAccountPettyCash) AS BankAccountCashPresentation,
		|	REFPRESENTATION(RegisterRecordsCashAssetsChange.Currency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsCashAssetsChange.CashAssetsType) AS CashAssetsTypeRepresentation,
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
		|		LEFT JOIN AccumulationRegister.CashAssets.Balance(
		|				&ControlTime,
		|				(Company, CashAssetsType, BankAccountPettyCash, Currency) In
		|					(SELECT
		|						RegisterRecordsCashAssetsChange.Company AS Company,
		|						RegisterRecordsCashAssetsChange.CashAssetsType AS CashAssetsType,
		|						RegisterRecordsCashAssetsChange.BankAccountPettyCash AS BankAccountPettyCash,
		|						RegisterRecordsCashAssetsChange.Currency AS Currency
		|					FROM
		|						RegisterRecordsCashAssetsChange AS RegisterRecordsCashAssetsChange)) AS CashAssetsBalances
		|		ON RegisterRecordsCashAssetsChange.Company = CashAssetsBalances.Company
		|			AND RegisterRecordsCashAssetsChange.CashAssetsType = CashAssetsBalances.CashAssetsType
		|			AND RegisterRecordsCashAssetsChange.BankAccountPettyCash = CashAssetsBalances.BankAccountPettyCash
		|			AND RegisterRecordsCashAssetsChange.Currency = CashAssetsBalances.Currency
		|WHERE
		|	ISNULL(CashAssetsBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.Execute();
		
		// Negative balance on cash.
		If Not ResultsArray.IsEmpty() Then
			
			DocumentObjectEnterOpeningBalance = DocumentRefEnterOpeningBalance.GetObject();
			
			QueryResultSelection = ResultsArray.Select();
			SmallBusinessServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObjectEnterOpeningBalance, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Control of the accounting section AccountsReceivable.
//
Procedure RunControlCustomerAccounts(DocumentRefEnterOpeningBalance, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables
	// "RegisterRecordsAccountsReceivableChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsAccountsReceivableChange Then
		
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
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite - ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AdvanceAmountsReceived,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
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
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.Execute();
		
		// Negative balance on accounts receivable.
		If Not ResultsArray.IsEmpty() Then
			
			DocumentObjectEnterOpeningBalance = DocumentRefEnterOpeningBalance.GetObject();
			
			QueryResultSelection = ResultsArray.Select();
			SmallBusinessServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectEnterOpeningBalance, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Control of the accounting section AccountsPayable.
//
Procedure RunControlAccountsPayable(DocumentRefEnterOpeningBalance, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables
	// "TransferAccountsPayableChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.SettlementsType) AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountChange AS AmountChange,
		|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite - ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AdvanceAmountsPaid,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
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
		
		ResultsArray = Query.Execute();
		
		// Negative balance on accounts payable.
		If Not ResultsArray.IsEmpty() Then
			
			DocumentObjectEnterOpeningBalance = DocumentRefEnterOpeningBalance.GetObject();
			
			QueryResultSelection = ResultsArray.Select();
			SmallBusinessServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectEnterOpeningBalance, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Control of the accounting section AdvanceHolderPayments.
//
Procedure RunControlAdvanceHolderPayments(DocumentRefEnterOpeningBalance, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables
	// "RegisterRecordsAdvanceHolderPaymentsChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsAdvanceHolderPaymentsChange Then
		
		Query = New Query(
		"SELECT
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
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.Execute();
		
		// Negative balance on advance holder payments.
		If Not ResultsArray.IsEmpty() Then
			
			DocumentObjectEnterOpeningBalance = DocumentRefEnterOpeningBalance.GetObject();
			
			QueryResultSelection = ResultsArray.Select();
			SmallBusinessServer.ShowMessageAboutPostingToAdvanceHolderPaymentsRegisterErrors(DocumentObjectEnterOpeningBalance, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Control of the accounting section Inventory.
//
Procedure RunControlInventory(DocumentRefEnterOpeningBalance, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;

	// If temporary tables "RegisterRecordsCustomerOrdersChange",
	// "TransferInternalOrdersChange", "RegisterRecordsPurchaseOrdersChange",
	// "RegisterRecordsProductionOrdersChange", "TransferInventoryAndCostAccountingChange",
	// "TransferInventoryInStorageAreaChange", "TransferProductsTransferredChange",
	// "TransferProductsReceivedChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsInventoryReceivedChange
		OR StructureTemporaryTables.RegisterRecordsInventoryTransferredChange
		OR StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsInventoryByCCDChange Then

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
		|	RegisterRecordsInventoryTransferredChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.ReceptionTransmissionType) AS ReceptionTransmissionTypePresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(InventoryTransferredBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryTransferredChange.QuantityChange, 0) + ISNULL(InventoryTransferredBalances.QuantityBalance, 0) AS BalanceInventoryTransferred,
		|	ISNULL(InventoryTransferredBalances.QuantityBalance, 0) AS QuantityBalanceInventoryTransferred,
		|	ISNULL(RegisterRecordsInventoryTransferredChange.SettlementsAmountChange, 0) + ISNULL(InventoryTransferredBalances.SettlementsAmountBalance, 0) AS SettlementsAmountInventoryTransferred,
		|	ISNULL(InventoryTransferredBalances.SettlementsAmountBalance, 0) AS SettlementsAmountBalanceInventoryTransferred
		|FROM
		|	RegisterRecordsInventoryTransferredChange AS RegisterRecordsInventoryTransferredChange
		|		LEFT JOIN AccumulationRegister.InventoryTransferred.Balance(
		|				&ControlTime,
		|				(Company, ReceptionTransmissionType, Counterparty, Contract, Order, ProductsAndServices, Characteristic, Batch) In
		|					(SELECT
		|						RegisterRecordsInventoryTransferredChange.Company AS Company,
		|						RegisterRecordsInventoryTransferredChange.ReceptionTransmissionType AS ReceptionTransmissionType,
		|						RegisterRecordsInventoryTransferredChange.Counterparty AS Counterparty,
		|						RegisterRecordsInventoryTransferredChange.Contract AS Contract,
		|						RegisterRecordsInventoryTransferredChange.Order AS Order,
		|						RegisterRecordsInventoryTransferredChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryTransferredChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryTransferredChange.Batch AS Batch
		|					FROM
		|						RegisterRecordsInventoryTransferredChange AS RegisterRecordsInventoryTransferredChange)) AS InventoryTransferredBalances
		|		ON RegisterRecordsInventoryTransferredChange.Company = InventoryTransferredBalances.Company
		|			AND RegisterRecordsInventoryTransferredChange.ReceptionTransmissionType = InventoryTransferredBalances.ReceptionTransmissionType
		|			AND RegisterRecordsInventoryTransferredChange.Counterparty = InventoryTransferredBalances.Counterparty
		|			AND RegisterRecordsInventoryTransferredChange.Contract = InventoryTransferredBalances.Contract
		|			AND RegisterRecordsInventoryTransferredChange.Order = InventoryTransferredBalances.Order
		|			AND RegisterRecordsInventoryTransferredChange.ProductsAndServices = InventoryTransferredBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryTransferredChange.Characteristic = InventoryTransferredBalances.Characteristic
		|			AND RegisterRecordsInventoryTransferredChange.Batch = InventoryTransferredBalances.Batch
		|WHERE
		|	(ISNULL(InventoryTransferredBalances.QuantityBalance, 0) < 0
		|			OR ISNULL(InventoryTransferredBalances.SettlementsAmountBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryReceivedChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType) AS ReceptionTransmissionTypePresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(InventoryReceivedBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryReceivedChange.QuantityChange, 0) + ISNULL(InventoryReceivedBalances.QuantityBalance, 0) AS BalanceInventoryReceived,
		|	ISNULL(InventoryReceivedBalances.QuantityBalance, 0) AS QuantityBalanceInventoryReceived,
		|	ISNULL(RegisterRecordsInventoryReceivedChange.SettlementsAmountChange, 0) + ISNULL(InventoryReceivedBalances.SettlementsAmountBalance, 0) AS SettlementsAmountInventoryReceived,
		|	ISNULL(InventoryReceivedBalances.SettlementsAmountBalance, 0) AS SettlementsAmountBalanceInventoryReceived
		|FROM
		|	RegisterRecordsInventoryReceivedChange AS RegisterRecordsInventoryReceivedChange
		|		LEFT JOIN AccumulationRegister.InventoryReceived.Balance(
		|				&ControlTime,
		|				(Company, ReceptionTransmissionType, Counterparty, Contract, Order, ProductsAndServices, Characteristic, Batch) In
		|					(SELECT
		|						RegisterRecordsInventoryReceivedChange.Company AS Company,
		|						RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType AS ReceptionTransmissionType,
		|						RegisterRecordsInventoryReceivedChange.Counterparty AS Counterparty,
		|						RegisterRecordsInventoryReceivedChange.Contract AS Contract,
		|						RegisterRecordsInventoryReceivedChange.Order AS Order,
		|						RegisterRecordsInventoryReceivedChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryReceivedChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryReceivedChange.Batch AS Batch
		|					FROM
		|						RegisterRecordsInventoryReceivedChange AS RegisterRecordsInventoryReceivedChange)) AS InventoryReceivedBalances
		|		ON RegisterRecordsInventoryReceivedChange.Company = InventoryReceivedBalances.Company
		|			AND RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType = InventoryReceivedBalances.ReceptionTransmissionType
		|			AND RegisterRecordsInventoryReceivedChange.Counterparty = InventoryReceivedBalances.Counterparty
		|			AND RegisterRecordsInventoryReceivedChange.Contract = InventoryReceivedBalances.Contract
		|			AND RegisterRecordsInventoryReceivedChange.Order = InventoryReceivedBalances.Order
		|			AND RegisterRecordsInventoryReceivedChange.ProductsAndServices = InventoryReceivedBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryReceivedChange.Characteristic = InventoryReceivedBalances.Characteristic
		|			AND RegisterRecordsInventoryReceivedChange.Batch = InventoryReceivedBalances.Batch
		|WHERE
		|	(ISNULL(InventoryReceivedBalances.QuantityBalance, 0) < 0
		|			OR ISNULL(InventoryReceivedBalances.SettlementsAmountBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryByCCDChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.CCDNo) AS CCDNoPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.CountryOfOrigin) AS CountryOfOriginPresentation,
		|	REFPRESENTATION(InventoryByCCDBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryByCCDChange.QuantityChange, 0) + ISNULL(InventoryByCCDBalances.QuantityBalance, 0) AS BalanceInventoryByCCD,
		|	ISNULL(InventoryByCCDBalances.QuantityBalance, 0) AS QuantityBalanceInventoryByCCD
		|FROM
		|	RegisterRecordsInventoryByCCDChange AS RegisterRecordsInventoryByCCDChange
		|		LEFT JOIN AccumulationRegister.InventoryByCCD.Balance(
		|				&ControlTime,
		|				(Company, CCDNo, ProductsAndServices, Characteristic, Batch, CountryOfOrigin) In
		|					(SELECT
		|						RegisterRecordsInventoryByCCDChange.Company AS Company,
		|						RegisterRecordsInventoryByCCDChange.CCDNo AS CCDNo,
		|						RegisterRecordsInventoryByCCDChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryByCCDChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryByCCDChange.Batch AS Batch,
		|						RegisterRecordsInventoryByCCDChange.CountryOfOrigin AS CountryOfOrigin
		|					FROM
		|						RegisterRecordsInventoryByCCDChange AS RegisterRecordsInventoryByCCDChange)) AS InventoryByCCDBalances
		|		ON RegisterRecordsInventoryByCCDChange.Company = InventoryByCCDBalances.Company
		|			AND RegisterRecordsInventoryByCCDChange.CCDNo = InventoryByCCDBalances.CCDNo
		|			AND RegisterRecordsInventoryByCCDChange.ProductsAndServices = InventoryByCCDBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryByCCDChange.Characteristic = InventoryByCCDBalances.Characteristic
		|			AND RegisterRecordsInventoryByCCDChange.Batch = InventoryByCCDBalances.Batch
		|			AND RegisterRecordsInventoryByCCDChange.CountryOfOrigin = InventoryByCCDBalances.CountryOfOrigin
		|WHERE
		|	ISNULL(InventoryByCCDBalances.QuantityBalance, 0) < 0
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
			
			DocumentObjectEnterOpeningBalance = DocumentRefEnterOpeningBalance.GetObject()
			
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrorsAsList(DocumentObjectEnterOpeningBalance, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory and cost accounting.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryRegisterErrorsAsList(DocumentObjectEnterOpeningBalance, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of products transferred.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryTransferredRegisterErrorsAsList(DocumentObjectEnterOpeningBalance, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of products received accounting.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryReceivedRegisterErrorsAsList(DocumentObjectEnterOpeningBalance, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory by CCD accounting.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryByCCDRegisterErrors(DocumentObjectEnterOpeningBalance, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;

EndProcedure

// Control of the accounting section FixedAssets.
//
Procedure RunControlFixedAssets(DocumentRefEnterOpeningBalance, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;

	// If temporary tables
	// "RegisterRecordsFixedAssetsChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsFixedAssetsChange Then

		Query = New Query(
		"SELECT
		|	RegisterRecordsFixedAssetsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.FixedAsset) AS FixedAssetPresentation,
		|	ISNULL(FixedAssetsBalance.CostBalance, 0) AS CostBalance,
		|	ISNULL(FixedAssetsBalance.DepreciationBalance, 0) AS DepreciationBalance,
		|	RegisterRecordsFixedAssetsChange.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsFixedAssetsChange.CostChanging AS CostChanging,
		|	RegisterRecordsFixedAssetsChange.CostChanging + ISNULL(FixedAssetsBalance.CostBalance, 0) AS DepreciatedCost,
		|	RegisterRecordsFixedAssetsChange.DepreciationBeforeWrite AS DepreciationBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationOnWrite AS DepreciationOnWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationUpdate AS DepreciationUpdate,
		|	RegisterRecordsFixedAssetsChange.DepreciationUpdate + ISNULL(FixedAssetsBalance.DepreciationBalance, 0) AS AccuredDepreciation
		|FROM
		|	RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange
		|		LEFT JOIN AccumulationRegister.FixedAssets.Balance(
		|				&ControlTime,
		|				(Company, FixedAsset) In
		|					(SELECT
		|						RegisterRecordsFixedAssetsChange.Company AS Company,
		|						RegisterRecordsFixedAssetsChange.FixedAsset AS FixedAsset
		|					FROM
		|						RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange)) AS FixedAssetsBalance
		|		ON (RegisterRecordsFixedAssetsChange.Company = RegisterRecordsFixedAssetsChange.Company)
		|			AND (RegisterRecordsFixedAssetsChange.FixedAsset = RegisterRecordsFixedAssetsChange.FixedAsset)
		|WHERE
		|	(ISNULL(FixedAssetsBalance.CostBalance, 0) < 0
		|			OR ISNULL(FixedAssetsBalance.DepreciationBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		QueryResult = Query.Execute();
		
		// Negative balance of property depriciation.
		If Not QueryResult.IsEmpty() Then
			
			DocumentObjectEnterOpeningBalance = DocumentRefEnterOpeningBalance.GetObject();
			
			QueryResultSelection = QueryResult.Select();
			SmallBusinessServer.ShowMessageAboutPostingToFixedAssetsRegisterErrors(DocumentObjectEnterOpeningBalance, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefEnterOpeningBalance, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;

	AccountingSection = DocumentRefEnterOpeningBalance.AccountingSection;

	If AccountingSection = "Property" Then

		RunControlFixedAssets(DocumentRefEnterOpeningBalance, AdditionalProperties, Cancel, PostingDelete = False);

	ElsIf AccountingSection = "Inventory" Then

		RunControlInventory(DocumentRefEnterOpeningBalance, AdditionalProperties, Cancel, PostingDelete = False);

	ElsIf AccountingSection = "Cash assets" Then

		RunControlCashAssets(DocumentRefEnterOpeningBalance, AdditionalProperties, Cancel, PostingDelete = False);

	ElsIf AccountingSection = "Settlements with suppliers and customers" Then

		RunControlCustomerAccounts(DocumentRefEnterOpeningBalance, AdditionalProperties, Cancel, PostingDelete = False);
		RunControlAccountsPayable(DocumentRefEnterOpeningBalance, AdditionalProperties, Cancel, PostingDelete = False);

	ElsIf AccountingSection = "Settlements with advance holders" Then
		
		RunControlAdvanceHolderPayments(DocumentRefEnterOpeningBalance, AdditionalProperties, Cancel, PostingDelete = False);

	EndIf;

EndProcedure

#Region DataImportFromExternalSources

Procedure WhenDefiningDefaultValue(CatalogRef, AttributeName, IncomingData, RowMatched, DefaultValue)
	
	If RowMatched 
		AND Not ValueIsFilled(IncomingData) 
		AND ValueIsFilled(CatalogRef[AttributeName]) Then
		
		DefaultValue = CatalogRef[AttributeName];
		
	EndIf;
	
EndProcedure

Procedure DataImportFieldsFromExternalSource(ImportFieldsTable, FillingObjectFullName) Export
	
	//
	// The group of fields complies with rule: at least one field in the group must be selected in columns
	//
	
	TypeDescriptionString25 = New TypeDescription("String", , , , New StringQualifiers(25));
	TypeDescriptionString50 = New TypeDescription("String", , , , New StringQualifiers(50));
	TypeDescriptionString100 = New TypeDescription("String", , , , New StringQualifiers(100));
	TypeDescriptionString150 = New TypeDescription("String", , , , New StringQualifiers(150));
	TypeDescriptionString200 = New TypeDescription("String", , , , New StringQualifiers(200));
	TypeDescriptionNumber15_2 = New TypeDescription("Number", , , , New NumberQualifiers(15, 2, AllowedSign.Nonnegative));
	TypeDescriptionNumber15_3 = New TypeDescription("Number", , , , New NumberQualifiers(15, 3, AllowedSign.Nonnegative));
	TypeDescriptionDate = New TypeDescription("Date", , , , New DateQualifiers(DateFractions.Date));
	
	
	If FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.Inventory" Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.StructuralUnits");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "StructuralUnit", "Warehouse (name)", TypeDescriptionString150, TypeDescriptionColumn);
		
		If GetFunctionalOption("AccountingByCells") Then
			
			TypeDescriptionColumn = New TypeDescription("CatalogRef.Cells");
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Cell", "Cell (description)", TypeDescriptionString50, TypeDescriptionColumn);
			
		EndIf;
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsAndServices");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Barcode", "Barcode", TypeDescriptionString200, TypeDescriptionColumn, "ProductsAndServices", 1, , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "SKU", "SKU", TypeDescriptionString25, TypeDescriptionColumn, "ProductsAndServices", 2, , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsAndServicesDescription", "Products and services (name)", TypeDescriptionString100, TypeDescriptionColumn, "ProductsAndServices", 3, , True);
		
		If GetFunctionalOption("UseCharacteristics") Then
			
			TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsAndServicesCharacteristics");
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Characteristic", "Characteristic (name)", TypeDescriptionString150, TypeDescriptionColumn);
			
		EndIf;
		
		If GetFunctionalOption("UseBatches") Then
			
			TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsAndServicesBatches");
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Batch", "Batch (name)", TypeDescriptionString150, TypeDescriptionColumn);
			
		EndIf;
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "MeasurementUnit", "Unit of Measure", TypeDescriptionString25, TypeDescriptionColumn);
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Quantity", "Quantity", TypeDescriptionString25, TypeDescriptionNumber15_3, , , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Price", "Price", TypeDescriptionString25, TypeDescriptionNumber15_2, , , True);
		
	ElsIf FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsReceivable" Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Counterparties");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Counterparty", "Counterparty (TIN or name)", TypeDescriptionString100, TypeDescriptionColumn, , , True);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.CounterpartyContracts");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Contract", "Counterparty contract (name or number)", TypeDescriptionString100, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "AdvanceFlag", "Is this an advance?", TypeDescriptionString25, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("DocumentRef.CustomerOrder");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CustomerOrderNumber", "Customer order number", TypeDescriptionString25, TypeDescriptionColumn, "Order");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CustomerOrderDate", "Customer order date", TypeDescriptionString25, TypeDescriptionColumn, "Order");
		
		TypeArray = New Array;
		TypeArray.Add(Type("DocumentRef.AcceptanceCertificate"));
		TypeArray.Add(Type("DocumentRef.CustomerOrder"));
		TypeArray.Add(Type("DocumentRef.Netting"));
		TypeArray.Add(Type("DocumentRef.AgentReport"));
		TypeArray.Add(Type("DocumentRef.ProcessingReport"));
		TypeArray.Add(Type("DocumentRef.CashReceipt"));
		TypeArray.Add(Type("DocumentRef.PaymentReceipt"));
		TypeArray.Add(Type("DocumentRef.FixedAssetsTransfer"));
		TypeArray.Add(Type("DocumentRef.CustomerInvoice"));
		
		TypeDescriptionColumn = New TypeDescription(TypeArray);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "PaymentDocumentKind", "Payment document kind", TypeDescriptionString50, TypeDescriptionColumn, "Document");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "NumberOfAccountsDocument", "Payment document number", TypeDescriptionString25, TypeDescriptionColumn, "Document");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "DateAccountingDocument", "Payment document date", TypeDescriptionString25, TypeDescriptionColumn, "Document");
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "AmountCur", "Amount (cur.)", TypeDescriptionString25, TypeDescriptionNumber15_2, , , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Amount", "Amount", TypeDescriptionString25, TypeDescriptionNumber15_2);
		
		TypeDescriptionColumn = New TypeDescription("DocumentRef.InvoiceForPayment");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CustomerAccountNo", "Number of account for payment", TypeDescriptionString25, TypeDescriptionColumn, "Account", , , );
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CustomerAccountDate", "Date of account for payment", TypeDescriptionString25, TypeDescriptionColumn, "Account", , , );
		
	ElsIf FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsPayable" Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Counterparties");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Counterparty", "Counterparty (TIN or name)", TypeDescriptionString100, TypeDescriptionColumn, , , True);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.CounterpartyContracts");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Contract", "Counterparty contract (name or number)", TypeDescriptionString100, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "AdvanceFlag", "Is this an advance?", TypeDescriptionString25, TypeDescriptionColumn, , , , False);
		
		TypeDescriptionColumn = New TypeDescription("DocumentRef.PurchaseOrder");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "PurchaseOrderNumber", "Purchase order number", TypeDescriptionString25, TypeDescriptionColumn, "Order");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "PurchaseOrderDate", "Purchase order date", TypeDescriptionString25, TypeDescriptionColumn, "Order");
		
		TypeArray = New Array;
		TypeArray.Add(Type("DocumentRef.ExpenseReport"));
		TypeArray.Add(Type("DocumentRef.AdditionalCosts"));
		TypeArray.Add(Type("DocumentRef.Netting"));
		TypeArray.Add(Type("DocumentRef.ReportToPrincipal"));
		TypeArray.Add(Type("DocumentRef.SubcontractorReport"));
		TypeArray.Add(Type("DocumentRef.SupplierInvoice"));
		TypeArray.Add(Type("DocumentRef.CashPayment"));
		TypeArray.Add(Type("DocumentRef.PaymentExpense"));
		
		TypeDescriptionColumn = New TypeDescription(TypeArray);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "PaymentDocumentKind", "Payment document kind", TypeDescriptionString50, TypeDescriptionColumn, "Document");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "NumberOfAccountsDocument", "Payment document number", TypeDescriptionString25, TypeDescriptionColumn, "Document");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "DateAccountingDocument", "Payment document date", TypeDescriptionString25, TypeDescriptionColumn, "Document");
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "AmountCur", "Amount (cur.)", TypeDescriptionString25, TypeDescriptionNumber15_2, , , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Amount", "Amount", TypeDescriptionString25, TypeDescriptionNumber15_2);
		
		TypeDescriptionColumn = New TypeDescription("DocumentRef.SupplierInvoiceForPayment");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CustomerAccountNo", "Number of account for payment", TypeDescriptionString25, TypeDescriptionString25, "Account");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CustomerAccountDate", "Date of account for payment", TypeDescriptionString25, TypeDescriptionColumn, "Account");
		
	EndIf;
	
EndProcedure

Procedure OnDefineDataImportSamples(DataLoadSettings, UUID) Export
	
	If DataLoadSettings.FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.Inventory" Then
		
		Sample_xlsx = GetTemplate("DataImportTemplate_xlsx");
		DataImportTemplate_xlsx = PutToTempStorage(Sample_xlsx, UUID);
		DataLoadSettings.Insert("DataImportTemplate_xlsx", DataImportTemplate_xlsx);
		
		DataLoadSettings.Insert("DataImportTemplate_mxl", "DataImportTemplate_mxl");
		
		Sample_csv = GetTemplate("DataImportTemplate_csv");
		DataImportTemplate_csv = PutToTempStorage(Sample_csv, UUID);
		DataLoadSettings.Insert("DataImportTemplate_csv", DataImportTemplate_csv);
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsReceivable" Then
		
		Sample_xlsx = GetTemplate("DataImportTemplate_AccountsReceivable_xlsx");
		DataImportTemplate_xlsx = PutToTempStorage(Sample_xlsx, UUID);
		DataLoadSettings.Insert("DataImportTemplate_xlsx", DataImportTemplate_xlsx);
		
		DataLoadSettings.Insert("DataImportTemplate_mxl", "DataImportTemplate_AccountsReceivable_mxl");
		
		Sample_csv = GetTemplate("DataImportTemplate_AccountsReceivable_csv");
		DataImportTemplate_csv = PutToTempStorage(Sample_csv, UUID);
		DataLoadSettings.Insert("DataImportTemplate_csv", DataImportTemplate_csv);
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsPayable" Then
		
		Sample_xlsx = GetTemplate("DataImportTemplate_AccountsPayable_xlsx");
		DataImportTemplate_xlsx = PutToTempStorage(Sample_xlsx, UUID);
		DataLoadSettings.Insert("DataImportTemplate_xlsx", DataImportTemplate_xlsx);
		
		DataLoadSettings.Insert("DataImportTemplate_mxl", "DataImportTemplate_AccountsPayable_mxl");
		
		Sample_csv = GetTemplate("DataImportTemplate_AccountsPayable_csv");
		DataImportTemplate_csv = PutToTempStorage(Sample_csv, UUID);
		DataLoadSettings.Insert("DataImportTemplate_csv", DataImportTemplate_csv);
		
	EndIf;
	
EndProcedure

Procedure MatchImportedDataFromExternalSource(DataMatchingTable, AdditionalParameters) Export
	
	FillingObjectFullName = AdditionalParameters.DataLoadSettings.FillingObjectFullName;
	
	// DataMatchingTable - Type FormDataCollection
	For Each FormTableRow IN DataMatchingTable Do
		
		If FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.Inventory" Then
			
			// Products and services by Barcode, SKU, Description
			DataImportFromExternalSourcesOverridable.CompareProductsAndServices(FormTableRow.ProductsAndServices, FormTableRow.Barcode, FormTableRow.SKU, FormTableRow.ProductsAndServicesDescription);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.ProductsAndServices);
			
			// StructuralUnit by name
			DefaultValue = Catalogs.StructuralUnits.MainWarehouse;
			WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "Warehouse", FormTableRow.StructuralUnit_IncomingData, ThisStringIsMapped, DefaultValue);
			DataImportFromExternalSourcesOverridable.MapStructuralUnit(FormTableRow.StructuralUnit, FormTableRow.StructuralUnit_IncomingData, DefaultValue);
			
			If GetFunctionalOption("AccountingByCells") Then
				
				// Cell by description
				DefaultValue = Catalogs.Cells.EmptyRef();
				WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "Cell", FormTableRow.Cell_IncomingData, ThisStringIsMapped, DefaultValue);
				DataImportFromExternalSourcesOverridable.MapCell(FormTableRow.Cell, FormTableRow.Cell_IncomingData, DefaultValue);
				
			EndIf;
			
			If ThisStringIsMapped Then
				
				If GetFunctionalOption("UseCharacteristics") Then
					
					// Characteristic by Owner and Name
					DataImportFromExternalSourcesOverridable.MapCharacteristic(FormTableRow.Characteristic, FormTableRow.ProductsAndServices, FormTableRow.Barcode, FormTableRow.Characteristic_IncomingData);
					
				EndIf;
				
				If GetFunctionalOption("UseBatches") Then
					
					// Batch by Owner and Name
					DataImportFromExternalSourcesOverridable.MapBatch(FormTableRow.Batch, FormTableRow.ProductsAndServices, FormTableRow.Barcode, FormTableRow.Batch_IncomingData);
					
				EndIf;
				
			EndIf;
			
			// Quantity
			DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.Quantity, FormTableRow.Quantity_IncomingData, 1);
			
			// UOM by Name, Owner
			DefaultValue = ?(ValueIsFilled(FormTableRow.ProductsAndServices), FormTableRow.ProductsAndServices.MeasurementUnit, Catalogs.UOMClassifier.pcs);
			DataImportFromExternalSourcesOverridable.MapUOM(FormTableRow.ProductsAndServices, FormTableRow.MeasurementUnit, FormTableRow.MeasurementUnit_IncomingData, DefaultValue);
			
			// Price
			DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.Price, FormTableRow.Price_IncomingData, 1);
			
			CheckDataCorrectnessInTableRow(FormTableRow, FillingObjectFullName);
			
		ElsIf FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsReceivable" Then
			
			// Counterparty by TIN, Name
			DataImportFromExternalSourcesOverridable.MapSupplier(FormTableRow.Counterparty, FormTableRow.Counterparty_IncomingData);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Counterparty);
			
			If ThisStringIsMapped Then
				
				DataImportFromExternalSourcesOverridable.MapContract(FormTableRow.Counterparty, FormTableRow.Contract, FormTableRow.Contract_IncomingData);
				DataImportFromExternalSourcesOverridable.MapOrderByNumberDate(FormTableRow.Order, "CustomerOrder", FormTableRow.Counterparty, FormTableRow.CustomerOrderNumber, FormTableRow.CustomerOrderDate);
				DataImportFromExternalSourcesOverridable.MapAccountingDocumentByNumberDate(FormTableRow.Document, FormTableRow.PaymentDocumentKind, FormTableRow.Counterparty, FormTableRow.NumberOfAccountsDocument, FormTableRow.DateAccountingDocument);
				DataImportFromExternalSourcesOverridable.MapAccountByNumberDate(FormTableRow.Account, FormTableRow.Counterparty, FormTableRow.CustomerAccountNo, FormTableRow.CustomerAccountDate);
				
			EndIf;
			
			DataImportFromExternalSourcesOverridable.ConvertStringToBoolean(FormTableRow.AdvanceFlag, FormTableRow.AdvanceFlag_IncomingData);
			
			DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.AmountCur, FormTableRow.AmountCur_IncomingData);
			DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.Amount, FormTableRow.Amount_IncomingData);
			
			CheckDataCorrectnessInTableRow(FormTableRow, FillingObjectFullName);
			
		ElsIf FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsPayable" Then
			
			// Counterparty by TIN, Name
			DataImportFromExternalSourcesOverridable.MapSupplier(FormTableRow.Counterparty, FormTableRow.Counterparty_IncomingData);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Counterparty);
			
			If ThisStringIsMapped Then
				
				DataImportFromExternalSourcesOverridable.MapContract(FormTableRow.Counterparty, FormTableRow.Contract, FormTableRow.Contract_IncomingData);
				DataImportFromExternalSourcesOverridable.MapOrderByNumberDate(FormTableRow.Order, "PurchaseOrder", FormTableRow.Counterparty, FormTableRow.PurchaseOrderNumber, FormTableRow.PurchaseOrderDate);
				DataImportFromExternalSourcesOverridable.MapAccountingDocumentByNumberDate(FormTableRow.Document, FormTableRow.PaymentDocumentKind, FormTableRow.Counterparty, FormTableRow.NumberOfAccountsDocument, FormTableRow.DateAccountingDocument);
				DataImportFromExternalSourcesOverridable.MapAccountByNumberDate(FormTableRow.Account, FormTableRow.Counterparty, FormTableRow.CustomerAccountNo, FormTableRow.CustomerAccountDate);
				
			EndIf;
			
			DataImportFromExternalSourcesOverridable.ConvertStringToBoolean(FormTableRow.AdvanceFlag, FormTableRow.AdvanceFlag_IncomingData);
			
			DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.AmountCur, FormTableRow.AmountCur_IncomingData);
			DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.Amount, FormTableRow.Amount_IncomingData);
			
			CheckDataCorrectnessInTableRow(FormTableRow, FillingObjectFullName);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CheckDataCorrectnessInTableRow(FormTableRow, FillingObjectFullName = "") Export
	
	ServiceFieldName = DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible();
	If IsBlankString(FillingObjectFullName) 
		OR FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.Inventory" Then
		
		FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.ProductsAndServices) 
			AND FormTableRow.Quantity <> 0 AND FormTableRow.Price <> 0;
		
	ElsIf FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsReceivable" 
		OR FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsPayable" Then
		
		FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.Counterparty);
		
	EndIf;
	
EndProcedure

#EndRegion

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
