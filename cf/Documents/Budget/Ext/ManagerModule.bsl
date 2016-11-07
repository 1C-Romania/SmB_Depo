#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataCashAssetsForecast(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeContent", NStr("en='Forecast of receipt of the cash funds';ru='Прогноз поступления денежных средств'"));
	Query.SetParameter("ExpenceContent", NStr("en='Forecast of retirement of the cash funds';ru='Прогноз выбытия денежных средств'"));
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Account AS GLAccount,
	|	&AccountingCurrency AS Currency,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountReceiptCur,
	|	DocumentTable.Amount AS AmountReceipt,
	|	0 AS AmountExpenseCur,
	|	0 AS AmountExpense,
	|	&IncomeContent AS ContentOfAccountingRecord
	|FROM
	|	Document.Budget.Receipts AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Account,
	|	&AccountingCurrency,
	|	DocumentTable.Item,
	|	0,
	|	0,
	|	DocumentTable.Amount,
	|	DocumentTable.Amount,
	|	&ExpenceContent
	|FROM
	|	Document.Budget.Disposal AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|ORDER BY
	|	LineNumber";
	
	Result = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashAssetsForecast", Result);
	
EndProcedure // InitializeCashAssertsDocumentDataForecast()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIncomeAndExpensesForecast(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeContent", NStr("en='Income forecast';ru='Прогноз доходов'"));
	Query.SetParameter("ExpenceContent", NStr("en='Expense forecast';ru='Прогноз расходов'"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.StructuralUnit
	|	END AS StructuralUnit,
	|	CASE
	|		WHEN DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.BusinessActivities.Other)
	|		ELSE DocumentTable.BusinessActivity
	|	END AS BusinessActivity,
	|	CASE
	|		WHEN DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.CustomerOrder
	|	END AS CustomerOrder,
	|	DocumentTable.Account AS GLAccount,
	|	DocumentTable.Amount AS AmountIncome,
	|	0 AS AmountExpenses,
	|	&IncomeContent AS ContentOfAccountingRecord
	|FROM
	|	Document.Budget.Incomings AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				OR DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CreditInterestRates)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.StructuralUnit
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				OR DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CreditInterestRates)
	|			THEN VALUE(Catalog.BusinessActivities.Other)
	|		ELSE DocumentTable.BusinessActivity
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.CustomerOrder
	|	END,
	|	DocumentTable.Account,
	|	0,
	|	DocumentTable.Amount,
	|	&ExpenceContent
	|FROM
	|	Document.Budget.Expenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
			
	Result = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesForecast", Result);
	
EndProcedure // DataInitializeIncomeAndExpensesDocumentDataForecast()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataDirectCost(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Account AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.CorrAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.DirectCost AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&DistributionOfDirectCost AS String(100))
	|FROM
	|	Document.Budget.DirectCost AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account.ClosingAccount.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&TransferOfFinishedProducts AS String(100))
	|FROM
	|	Document.Budget.DirectCost AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.ClosingAccount.ClosingAccount <> VALUE(ChartOfAccounts.Managerial.EmptyRef)");
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("DistributionOfDirectCost", "Direct costs allocating");
	Query.SetParameter("TransferOfFinishedProducts", "Finished products delivery");
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure // InitializeDirectCostsDocumentData()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIndirectExpenses(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Account AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.CorrAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.IndirectExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&DistributionOfIndirectCost AS String(100))
	|FROM
	|	Document.Budget.IndirectExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account.ClosingAccount.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&DistributionOfDirectCost AS String(100))
	|FROM
	|	Document.Budget.IndirectExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.ClosingAccount.ClosingAccount <> VALUE(ChartOfAccounts.Managerial.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account.ClosingAccount.ClosingAccount.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.ClosingAccount.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account.ClosingAccount.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&TransferOfFinishedProducts AS String(100))
	|FROM
	|	Document.Budget.IndirectExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.ClosingAccount.ClosingAccount.ClosingAccount <> VALUE(ChartOfAccounts.Managerial.EmptyRef)");
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("DistributionOfIndirectCost", "Indirect costs allocating");
	Query.SetParameter("DistributionOfDirectCost", "Direct costs allocating");
	Query.SetParameter("TransferOfFinishedProducts", "Finished products delivery");
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure // InitializeIndirectCostsDocumentData()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataExpenses(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Account AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.CorrAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.Expenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure // InitializeExpensesDocumentData()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIncome(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.CorrAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.Account AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.Incomings AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure // InitializeIncomeDocumentData()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataOutflows(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.CorrAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.Account AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.Disposal AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure // InitializeOutflowsDocumentData()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataReceipts(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Account AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.CorrAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.Receipts AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure // InitializeReceiptsDocumentData()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAccountingRecords(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.AccountDr AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.AccountDr.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.AccountDr.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.AccountCr AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.AccountCr.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.AccountCr.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.Operations AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure // InitializeAccountingRecordDocumentData()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataBalances(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DATEADD(DocumentTable.Ref.PlanningPeriod.StartDate, Second, -1) AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	VALUE(ChartOfAccounts.Managerial.Service) AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.Account AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(&Content AS String(100)) AS Content
	|FROM
	|	Document.Budget.Balance AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.TypeOfAccount IN(&CreditAccountTypes)
	|
	|UNION ALL
	|
	|SELECT
	|	DATEADD(DocumentTable.Ref.PlanningPeriod.StartDate, Second, -1),
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	VALUE(ChartOfAccounts.Managerial.Service),
	|	UNDEFINED,
	|	0,
	|	CAST(&Content AS String(100))
	|FROM
	|	Document.Budget.Balance AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.TypeOfAccount IN(&DebetAccountTypes)");
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	Query.SetParameter("Content", NStr("en='Opening balances forecast';ru='Прогноз начальных остатков'"));
	
	DebetAccountTypes = New ValueList;
	DebetAccountTypes.Add(Enums.GLAccountsTypes.FixedAssets);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.Debitors);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.CashAssets);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.Inventory);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.IndirectExpenses);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.ShorttermInvestments);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.UnfinishedProduction);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.OtherFixedAssets);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.OtherCurrentAssets);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.OtherExpenses);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.Expenses);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.CostOfGoodsSold);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.CreditInterestRates);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.ProfitTax);
	
	CreditAccountTypes = New ValueList;
	CreditAccountTypes.Add(Enums.GLAccountsTypes.DepreciationFixedAssets);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.LongtermObligations);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.Incomings);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.Capital);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.Creditors);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.CreditsAndLoans);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.UndistributedProfit);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.ProfitLosses);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.OtherIncome);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.OtherShorttermObligations);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.ReserveAndAdditionalCapital);
	
	Query.SetParameter("DebetAccountTypes", DebetAccountTypes);
	Query.SetParameter("CreditAccountTypes", CreditAccountTypes);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", QueryResult.Unload());
	
EndProcedure // InitializeBalancesDocumentData()

// Generates allocation base table.
//
// Parameters:
// DistributionBase - Enums.CostingBases
// GLAccountsArray - Array containing filter by
// GL accounts FilterByStructuralUnit - filer by
// structural units FilterByOrder - Filter by goods orders
//
// Returns:
//  ValuesTable containing allocation base.
//
Function GenerateFinancialResultDistributionBaseTable(DistributionBase, PlanningPeriod, StartDate, EndDate, FilterByStructuralUnit, FilterByBusinessActivity, FilterByOrder, AdditionalProperties)
	
	ResultTable = New ValueTable;
	
	If DistributionBase = Enums.CostingBases.SalesVolume Then
		
		QueryText = 
		"SELECT
		|	SalesTurnovers.Company AS Company,
		|	SalesTurnovers.ProductsAndServices.BusinessActivity AS BusinessActivity,
		|	SalesTurnovers.CustomerOrder AS Order,
		|	SalesTurnovers.ProductsAndServices.BusinessActivity.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
		|	SalesTurnovers.ProductsAndServices.BusinessActivity.GLAccountCostOfSales AS GLAccountCostOfSales,
		|	SalesTurnovers.ProductsAndServices.BusinessActivity.ProfitGLAccount AS ProfitGLAccount,
		|	SalesTurnovers.StructuralUnit AS StructuralUnit,
		|	SalesTurnovers.QuantityTurnover AS Base
		|FROM
		|	AccumulationRegister.SalesTargets.Turnovers(
		|			&StartDate,
		|			&EndDate,
		|			Auto,
		|			Company = &Company
		|			AND PlanningPeriod = &PlanningPeriod
		|				// FilterByStructuralUnit
		|				// FilterByBusinessActivity
		|				// FilterByOrder
		|			) AS SalesTurnovers";
		
		QueryText = StrReplace(QueryText, "// FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "AND StructuralUnit IN (&StructuralUnitsArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByBusinessActivity", ?(ValueIsFilled(FilterByBusinessActivity), "And ProductsAndServices.BusinessActivity IN (&ActivityDirectionsArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByOrder", ?(ValueIsFilled(FilterByOrder), "And CustomerOrder IN (&OrdersArray)", ""));
				
	ElsIf DistributionBase = Enums.CostingBases.SalesRevenue Then
		
		QueryText = 
		"SELECT
		|	&Company AS Company,
		|	Budget.BusinessActivity AS BusinessActivity,
		|	Budget.CustomerOrder AS Order,
		|	Budget.BusinessActivity.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
		|	Budget.BusinessActivity.GLAccountCostOfSales AS GLAccountCostOfSales,
		|	Budget.BusinessActivity.ProfitGLAccount AS ProfitGLAccount,
		|	Budget.StructuralUnit AS StructuralUnit,
		|	Budget.Amount AS Base
		|FROM
		|	Document.Budget.Incomings AS Budget
		|WHERE
		|	Budget.Ref = &Ref
		|	AND Budget.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Incomings)
		|	AND Budget.PlanningDate between &StartDate AND &EndDate
		|	// FilterByStructuralUnit
		|	// FilterByBusinessActivity
		|	// FilterByOrder
		|";
		
		QueryText = StrReplace(QueryText, "// FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "AND Budget.StructuralUnit IN (&StructuralUnitsArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByBusinessActivity", ?(ValueIsFilled(FilterByBusinessActivity), "And Budget.BusinessArea IN (&BusinessAreaArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByOrder", ?(ValueIsFilled(FilterByOrder), "AND Budget.CustomerOrder IN (&OdersArray)", ""));
		
	ElsIf DistributionBase = Enums.CostingBases.CostOfGoodsSold Then
		
		QueryText = 
		"SELECT
		|	&Company AS Company,
		|	Budget.BusinessActivity AS BusinessActivity,
		|	Budget.CustomerOrder AS Order,
		|	Budget.BusinessActivity.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
		|	Budget.BusinessActivity.GLAccountCostOfSales AS GLAccountCostOfSales,
		|	Budget.BusinessActivity.ProfitGLAccount AS ProfitGLAccount,
		|	Budget.StructuralUnit AS StructuralUnit,
		|	Budget.Amount AS Base
		|FROM
		|	Document.Budget.Expenses AS Budget
		|WHERE
		|	Budget.Ref = &Ref
		|	AND Budget.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfGoodsSold)
		|	AND Budget.PlanningDate between &StartDate AND &EndDate
		|	// FilterByStructuralUnit
		|	// FilterByBusinessActivity
		|	// FilterByOrder
		|";
		
		QueryText = StrReplace(QueryText, "// FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "AND Budget.StructuralUnit IN (&StructuralUnitsArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByBusinessActivity", ?(ValueIsFilled(FilterByBusinessActivity), "And Budget.BusinessArea IN (&BusinessAreaArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByOrder", ?(ValueIsFilled(FilterByOrder), "AND Budget.CustomerOrder IN (&OdersArray)", ""));
		
	ElsIf DistributionBase = Enums.CostingBases.GrossProfit Then
		
		QueryText =
		"SELECT
		|	Table.Company AS Company,
		|	Table.BusinessActivity AS BusinessActivity,
		|	Table.Order AS Order,
		|	Table.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
		|	Table.GLAccountCostOfSales AS GLAccountCostOfSales,
		|	Table.ProfitGLAccount AS ProfitGLAccount,
		|	Table.StructuralUnit AS StructuralUnit,
		|	SUM(Table.Base) AS Base
		|     |FROM
		|	(SELECT
		|		&Company AS Company,
		|		Budget.BusinessActivity AS BusinessActivity,
		|		Budget.CustomerOrder AS Order,
		|		Budget.BusinessActivity.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
		|		Budget.BusinessActivity.GLAccountCostOfSales AS GLAccountCostOfSales,
		|		Budget.BusinessActivity.ProfitGLAccount AS ProfitGLAccount,
		|		Budget.StructuralUnit AS StructuralUnit,
		|		Budget.Amount AS Base
		|	FROM
		|		Document.Budget.Incomings AS Budget
		|	WHERE
		|		Budget.Ref = &Ref
		|		AND Budget.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Incomings)
		|		AND Budget.PlanningDate between &StartDate AND &EndDate
		|		// FilterByStructuralUnit
		|		// FilterByBusinessActivity
		|		// FilterByOrder
		|
		|	UNION ALL
		|
		|	SELECT
		|		&Company,
		|		Budget.BusinessActivity,
		|		Budget.CustomerOrder,
		|		Budget.BusinessActivity.GLAccountRevenueFromSales,
		|		Budget.BusinessActivity.GLAccountCostOfSales,
		|		Budget.BusinessActivity.ProfitGLAccount,
		|		Budget.StructuralUnit,
		|		- Budget.Amount AS Base
		|	FROM
		|		Document.Budget.Expenses AS Budget
		|	WHERE
		|		Budget.Ref = &Ref
		|		AND Budget.PlanningDate between &StartDate AND &EndDate
		|		AND Budget.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfGoodsSold)
		|		// FilterByStructuralUnit
		|		// FilterByBusinessActivity
		|		// FilterByOrder
		|	) AS Table
		|
		|GROUP BY
		|	Table.Company,
		|	Table.BusinessActivity,
		|	Table.Order,
		|	Table.GLAccountRevenueFromSales,
		|	Table.GLAccountCostOfSales,
		|	Table.ProfitGLAccount,
		|	Table.StructuralUnit";
			
	Else
		
		Return ResultTable;
		
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	
	Query.SetParameter("StartDate"		  , StartDate);
	Query.SetParameter("EndDate"	  , EndDate);
	Query.SetParameter("Ref"			  , AdditionalProperties.ForPosting.Ref);
	Query.SetParameter("Company"		  , AdditionalProperties.ForPosting.Company);
	Query.SetParameter("PlanningPeriod", PlanningPeriod);
			
	If ValueIsFilled(FilterByOrder) Then
		If TypeOf(FilterByOrder) = Type("Array") Then
			Query.SetParameter("OrdersArray", FilterByOrder);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByOrder);
			Query.SetParameter("OrdersArray", ArrayForSelection);
		EndIf;
	EndIf;
	
	If ValueIsFilled(FilterByStructuralUnit) Then
		If TypeOf(FilterByStructuralUnit) = Type("Array") Then
			Query.SetParameter("StructuralUnitsArray", FilterByStructuralUnit);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByStructuralUnit);
			Query.SetParameter("StructuralUnitsArray", ArrayForSelection);
		EndIf;
	EndIf;
	
	If ValueIsFilled(FilterByBusinessActivity) Then
		If TypeOf(FilterByBusinessActivity) = Type("Array") Then
			Query.SetParameter("ActivityDirectionsArray", FilterByBusinessActivity);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByBusinessActivity);
			Query.SetParameter("ActivityDirectionsArray", FilterByBusinessActivity);
		EndIf;
	EndIf;
	
	ResultTable = Query.Execute().Unload();
	
	Return ResultTable;
	
EndFunction // GenerateAllocationBaseTable()

// Distributing financial result throughtout the base.
//
Procedure DistributeFinancialResultThroughoutBase(DocumentRefBudget, StructureAdditionalProperties, StartDate, EndDate)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	IncomeAndExpenses.Company AS Company,
	|	IncomeAndExpenses.Date AS Date,
	|	IncomeAndExpenses.PlanningPeriod AS PlanningPeriod,
	|	IncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	IncomeAndExpenses.BusinessActivity AS BusinessActivity,
	|	IncomeAndExpenses.ProfitGLAccount AS ProfitGLAccount,
	|	IncomeAndExpenses.Order AS Order,
	|	IncomeAndExpenses.GLAccount AS GLAccount,
	|	IncomeAndExpenses.MethodOfDistribution AS GLAccountMethodOfDistribution,
	|	SUM(IncomeAndExpenses.AmountIncome) AS AmountIncome,
	|	SUM(IncomeAndExpenses.AmountExpenses) AS AmountExpenses
	|FROM
	|	(SELECT
	|		&Company AS Company,
	|		DocumentTable.PlanningDate AS Date,
	|		DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|		DocumentTable.StructuralUnit AS StructuralUnit,
	|		DocumentTable.BusinessActivity AS BusinessActivity,
	|		DocumentTable.BusinessActivity.ProfitGLAccount AS ProfitGLAccount,
	|		DocumentTable.CustomerOrder AS Order,
	|		DocumentTable.Account AS GLAccount,
	|		DocumentTable.Account.MethodOfDistribution AS MethodOfDistribution,
	|		DocumentTable.Amount AS AmountIncome,
	|		0 AS AmountExpenses
	|	FROM
	|		Document.Budget.Incomings AS DocumentTable
	|	WHERE
	|		DocumentTable.PlanningDate between &StartDate AND &EndDate
	|		AND DocumentTable.Ref = &Ref
	|		AND (DocumentTable.Account.MethodOfDistribution <> VALUE(Enum.CostingBases.DoNotDistribute)
	|				OR (DocumentTable.BusinessActivity.GLAccountCostOfSales <> DocumentTable.Account
	|						AND DocumentTable.BusinessActivity.GLAccountRevenueFromSales <> DocumentTable.Account
	|					OR DocumentTable.BusinessActivity = VALUE(Catalog.BusinessActivities.Other)
	|					OR DocumentTable.BusinessActivity = VALUE(Catalog.BusinessActivities.EmptyRef)))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		&Company,
	|		DocumentTable.PlanningDate,
	|		DocumentTable.Ref.PlanningPeriod,
	|		DocumentTable.StructuralUnit,
	|		DocumentTable.BusinessActivity,
	|		DocumentTable.BusinessActivity.ProfitGLAccount,
	|		DocumentTable.CustomerOrder,
	|		DocumentTable.Account,
	|		DocumentTable.Account.MethodOfDistribution,
	|		0,
	|		DocumentTable.Amount
	|	FROM
	|		Document.Budget.Expenses AS DocumentTable
	|	WHERE
	|		DocumentTable.PlanningDate between &StartDate AND &EndDate
	|		AND DocumentTable.Ref = &Ref
	|		AND (DocumentTable.Account.MethodOfDistribution <> VALUE(Enum.CostingBases.DoNotDistribute)
	|				OR (DocumentTable.BusinessActivity.GLAccountCostOfSales <> DocumentTable.Account
	|						AND DocumentTable.BusinessActivity.GLAccountRevenueFromSales <> DocumentTable.Account
	|					OR DocumentTable.BusinessActivity = VALUE(Catalog.BusinessActivities.Other)
	|					OR DocumentTable.BusinessActivity = VALUE(Catalog.BusinessActivities.EmptyRef)))) AS IncomeAndExpenses
	|
	|GROUP BY
	|	IncomeAndExpenses.Company,
	|	IncomeAndExpenses.Date,
	|	IncomeAndExpenses.PlanningPeriod,
	|	IncomeAndExpenses.StructuralUnit,
	|	IncomeAndExpenses.BusinessActivity,
	|	IncomeAndExpenses.ProfitGLAccount,
	|	IncomeAndExpenses.Order,
	|	IncomeAndExpenses.GLAccount,
	|	IncomeAndExpenses.MethodOfDistribution
	|
	|ORDER BY
	|	GLAccountMethodOfDistribution,
	|	StructuralUnit,
	|	BusinessActivity,
	|	Order
	|TOTALS
	|	SUM(AmountIncome),
	|	SUM(AmountExpenses)
	|BY
	|	GLAccountMethodOfDistribution,
	|	StructuralUnit,
	|	BusinessActivity,
	|	Order";
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", EndDate);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	BypassByDistributionMethod = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While BypassByDistributionMethod.Next() Do
		
		BypassByStructuralUnit = BypassByDistributionMethod.Select(QueryResultIteration.ByGroups);
		
		// Bypass on divisions.
		While BypassByStructuralUnit.Next() Do
			
			FilterByStructuralUnit = BypassByStructuralUnit.StructuralUnit;
			
			BypassByActivityDirection = BypassByStructuralUnit.Select(QueryResultIteration.ByGroups);
			
			While BypassByActivityDirection.Next() Do
				
				FilterByBusinessActivity = BypassByActivityDirection.BusinessActivity;
				
				BypassByOrder = BypassByActivityDirection.Select(QueryResultIteration.ByGroups);
				
				// Bypass on orders.
				While BypassByOrder.Next() Do
				
					FilterByOrder = BypassByOrder.Order;
					
					If BypassByOrder.GLAccountMethodOfDistribution = Enums.CostingBases.DoNotDistribute Then
						Continue;
					EndIf;
					
					// Generate allocation base table.
					BaseTable = GenerateFinancialResultDistributionBaseTable(
						BypassByOrder.GLAccountMethodOfDistribution,
						StructureAdditionalProperties.ForPosting.PlanningPeriod,
						StartDate,
						EndDate,
						FilterByStructuralUnit,
						FilterByBusinessActivity,
						FilterByOrder,
						StructureAdditionalProperties
					);
					
					If BaseTable.Count() = 0 Then
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							BypassByOrder.GLAccountMethodOfDistribution,
							StructureAdditionalProperties.ForPosting.PlanningPeriod,
							StartDate,
							EndDate,
							FilterByStructuralUnit,
							FilterByBusinessActivity,
							Undefined,
							StructureAdditionalProperties
						);
					EndIf;
					
					If BaseTable.Count() = 0 Then
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							BypassByOrder.GLAccountMethodOfDistribution,
							StructureAdditionalProperties.ForPosting.PlanningPeriod,
							StartDate,
							EndDate,
							FilterByStructuralUnit,
							Undefined,
							Undefined,
							StructureAdditionalProperties
						);
					EndIf;
					
					If BaseTable.Count() = 0 Then
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							BypassByOrder.GLAccountMethodOfDistribution,
							StructureAdditionalProperties.ForPosting.PlanningPeriod,
							StartDate,
							EndDate,
							Undefined,
							Undefined,
							Undefined,
							StructureAdditionalProperties
						);
					EndIf;
					
					TotalBaseDistribution = BaseTable.Total("Base");
					DirectionsQuantity  = BaseTable.Count() - 1;
					
					BypassByGLAccounts = BypassByOrder.Select(QueryResultIteration.ByGroups);
					
					// Bypass on the expenses accounts.
					While BypassByGLAccounts.Next() Do
						
						If BaseTable.Count() = 0
						 OR TotalBaseDistribution = 0 Then
							BaseTable = New ValueTable;
							BaseTable.Columns.Add("Company");
							BaseTable.Columns.Add("StructuralUnit");
							BaseTable.Columns.Add("BusinessActivity");
							BaseTable.Columns.Add("Order");
							BaseTable.Columns.Add("GLAccountRevenueFromSales");
							BaseTable.Columns.Add("GLAccountCostOfSales");
							BaseTable.Columns.Add("ProfitGLAccount");
							BaseTable.Columns.Add("Base");
							TableRow = BaseTable.Add();
							TableRow.Company = BypassByGLAccounts.Company;
							TableRow.StructuralUnit = BypassByGLAccounts.StructuralUnit;
							TableRow.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
							TableRow.Order = BypassByGLAccounts.Order;
							TableRow.GLAccountRevenueFromSales = BypassByGLAccounts.GLAccount;
							TableRow.GLAccountCostOfSales = BypassByGLAccounts.GLAccount;
							TableRow.ProfitGLAccount = Catalogs.BusinessActivities.MainActivity.ProfitGLAccount;
							TableRow.Base = 1;
							TotalBaseDistribution = 1;
						EndIf;
					
						// Allocate amount.
						If BypassByGLAccounts.AmountIncome <> 0 
						 OR BypassByGLAccounts.AmountExpenses <> 0 Then
						 
						 	If BypassByGLAccounts.AmountIncome <> 0 Then
								SumDistribution = BypassByGLAccounts.AmountIncome;
							ElsIf BypassByGLAccounts.AmountExpenses <> 0 Then
								SumDistribution = BypassByGLAccounts.AmountExpenses;
							EndIf;
								
							SumWasDistributed = 0;
						
							For Each DistributionDirection IN BaseTable Do
							
								CostAmount = ?(SumDistribution = 0, 0, Round(DistributionDirection.Base / TotalBaseDistribution * SumDistribution, 2, 1));
								SumWasDistributed = SumWasDistributed + CostAmount;
							
								// If it is the last string - , correct amount in it to the rounding error.
								If BaseTable.IndexOf(DistributionDirection) = DirectionsQuantity Then
									CostAmount	= CostAmount + SumDistribution - SumWasDistributed;
								EndIf;
							
								If CostAmount <> 0 Then
									
									// Movements by register Financial result.
									NewRow	= StructureAdditionalProperties.TableForRegisterRecords.TableFinancialResultForecast.Add();
									NewRow.Period = BypassByGLAccounts.Date;
									NewRow.PlanningPeriod = BypassByGLAccounts.PlanningPeriod;
									NewRow.Recorder	= DocumentRefBudget;
									NewRow.Company	= DistributionDirection.Company;
									NewRow.StructuralUnit = DistributionDirection.StructuralUnit;
									NewRow.BusinessActivity	= DistributionDirection.BusinessActivity;
									
									NewRow.GLAccount = BypassByGLAccounts.GLAccount;
									If BypassByGLAccounts.AmountIncome <> 0 Then
										NewRow.AmountIncome = CostAmount;
									ElsIf BypassByGLAccounts.AmountExpenses <> 0 Then
										NewRow.AmountExpenses = CostAmount;
									EndIf;
									
									// Movements by register Managerial.
									NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
									NewRow.Period = BypassByGLAccounts.Date;
									NewRow.Company = StructureAdditionalProperties.ForPosting.Company;
									NewRow.PlanningPeriod = BypassByGLAccounts.PlanningPeriod;
									
									If BypassByGLAccounts.AmountIncome <> 0 Then
										NewRow.AccountDr = BypassByGLAccounts.GLAccount;
										NewRow.AccountCr = DistributionDirection.ProfitGLAccount;
										NewRow.Amount = CostAmount; 
									ElsIf BypassByGLAccounts.AmountExpenses <> 0 Then
										NewRow.AccountDr = DistributionDirection.ProfitGLAccount;
										NewRow.AccountCr = BypassByGLAccounts.GLAccount;
										NewRow.Amount = CostAmount;
									EndIf;
									
									NewRow.Content = "Financial result (forecast)";
									
								EndIf;
								
							EndDo;
						
							If SumWasDistributed = 0 Then
								
								MessageText = NStr("en='Financial result calculating:Financial account ""%FinancialAccount%"" has no distribution base!';ru='Расчет финансового результата: Счет учета ""%СчетУчета%"", не имеет базы распределения!'");
								MessageText = StrReplace(MessageText, "%GLAccount%", String(BypassByGLAccounts.GLAccount));
								SmallBusinessServer.ShowMessageAboutError(DocumentRefBudget, MessageText); 
								Continue;
								
							EndIf;
						
						EndIf
					
					EndDo;
				
				EndDo;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure // DistributeFinancialResultThroughoutBase()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataFinancialResultForecast(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	DocumentTable.PlanningDate AS Date,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.BusinessActivity AS BusinessActivity,
	|	DocumentTable.BusinessActivity.ProfitGLAccount AS ProfitGLAccount,
	|	DocumentTable.CustomerOrder AS Order,
	|	DocumentTable.Account AS GLAccount,
	|	DocumentTable.Amount AS AmountIncome,
	|	0 AS AmountExpenses
	|FROM
	|	Document.Budget.Incomings AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Account.MethodOfDistribution = VALUE(Enum.CostingBases.DoNotDistribute)
	|			OR (DocumentTable.BusinessActivity.GLAccountCostOfSales = DocumentTable.Account
	|				OR DocumentTable.BusinessActivity.GLAccountRevenueFromSales = DocumentTable.Account)
	|				AND DocumentTable.BusinessActivity <> VALUE(Catalog.BusinessActivities.Other))
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	DocumentTable.PlanningDate,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.BusinessActivity,
	|	DocumentTable.BusinessActivity.ProfitGLAccount,
	|	DocumentTable.CustomerOrder,
	|	DocumentTable.Account,
	|	0,
	|	DocumentTable.Amount
	|FROM
	|	Document.Budget.Expenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Account.MethodOfDistribution = VALUE(Enum.CostingBases.DoNotDistribute)
	|			OR (DocumentTable.BusinessActivity.GLAccountCostOfSales = DocumentTable.Account
	|				OR DocumentTable.BusinessActivity.GLAccountRevenueFromSales = DocumentTable.Account)
	|				AND DocumentTable.BusinessActivity <> VALUE(Catalog.BusinessActivities.Other))";
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref", DocumentRefBudget);
	
	QueryResult = Query.Execute();
	
	TableFinancialResultForecast = New ValueTable;
	
	TableFinancialResultForecast.Columns.Add("LineNumber");
	TableFinancialResultForecast.Columns.Add("Recorder");
	TableFinancialResultForecast.Columns.Add("Period");
	TableFinancialResultForecast.Columns.Add("Company");
	TableFinancialResultForecast.Columns.Add("PlanningPeriod");
	TableFinancialResultForecast.Columns.Add("StructuralUnit");
	TableFinancialResultForecast.Columns.Add("BusinessActivity");
	TableFinancialResultForecast.Columns.Add("GLAccount");
	TableFinancialResultForecast.Columns.Add("AmountIncome");
	TableFinancialResultForecast.Columns.Add("AmountExpenses");
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFinancialResultForecast", TableFinancialResultForecast);
	
	SelectionQueryResult = QueryResult.Select();
	
	While SelectionQueryResult.Next() Do
		
		// Movements by register Financial result.
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableFinancialResultForecast.Add();
		NewRow.Period = SelectionQueryResult.Date;
		NewRow.Recorder = DocumentRefBudget;
		NewRow.PlanningPeriod = SelectionQueryResult.PlanningPeriod;
		NewRow.Company = SelectionQueryResult.Company;
		NewRow.StructuralUnit = SelectionQueryResult.StructuralUnit;
		NewRow.BusinessActivity = ?(
			ValueIsFilled(SelectionQueryResult.BusinessActivity), SelectionQueryResult.BusinessActivity, Catalogs.BusinessActivities.MainActivity
		);

		NewRow.GLAccount = SelectionQueryResult.GLAccount;
		
		If SelectionQueryResult.AmountIncome <> 0 Then
			NewRow.AmountIncome = SelectionQueryResult.AmountIncome;
		ElsIf SelectionQueryResult.AmountExpenses <> 0 Then
			NewRow.AmountExpenses = SelectionQueryResult.AmountExpenses;
		EndIf;
		
		// Movements by register Managerial.
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		NewRow.Period = SelectionQueryResult.Date;
		NewRow.Company = SelectionQueryResult.Company;
		NewRow.PlanningPeriod = SelectionQueryResult.PlanningPeriod;
		
		If SelectionQueryResult.AmountIncome <> 0 Then
			NewRow.AccountDr = SelectionQueryResult.GLAccount;
			NewRow.AccountCr = ?(
				ValueIsFilled(SelectionQueryResult.BusinessActivity),
				SelectionQueryResult.ProfitGLAccount,
				Catalogs.BusinessActivities.MainActivity.ProfitGLAccount
			);
			NewRow.Amount = SelectionQueryResult.AmountIncome; 
		ElsIf SelectionQueryResult.AmountExpenses <> 0 Then
			NewRow.AccountDr = ?(
				ValueIsFilled(SelectionQueryResult.BusinessActivity),
				SelectionQueryResult.ProfitGLAccount,
				Catalogs.BusinessActivities.MainActivity.ProfitGLAccount
			);
			NewRow.AccountCr = SelectionQueryResult.GLAccount;
			NewRow.Amount = SelectionQueryResult.AmountExpenses;
		EndIf;
		
		NewRow.Content = "Financial result (forecast)";
		
	EndDo;
	
	StartDate = StructureAdditionalProperties.ForPosting.StartDate;
	EndDate = StructureAdditionalProperties.ForPosting.EndDate;
	
	While StartDate < EndDate Do
		DistributeFinancialResultThroughoutBase(DocumentRefBudget, StructureAdditionalProperties, StartDate, EndOfMonth(StartDate));
		StartDate = EndOfMonth(StartDate) + 1;;
	EndDo;
	
EndProcedure // InitializeFinancialResultDocumentDataForecast()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefBudget, StructureAdditionalProperties) Export
	
	InitializeDocumentDataBalances(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataDirectCost(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataIndirectExpenses(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataAccountingRecords(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataReceipts(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataOutflows(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataIncome(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataExpenses(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataIncomeAndExpensesForecast(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataCashAssetsForecast(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataFinancialResultForecast(DocumentRefBudget, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

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