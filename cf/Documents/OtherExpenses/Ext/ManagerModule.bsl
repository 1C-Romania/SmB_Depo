#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region OtherSettlements

Procedure GenerateTableSettlementsWithOtherCounterparties(DocumentRefOtherExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AccountingForOtherOperations",	NStr("ru = 'Учет расчетов по прочим операциям'; en = 'Accounting for other operations'",	Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("CommentReceipt",				NStr("ru = 'Увеличение долга контрагента'; en = 'Increase company debt'", Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("CommentExpense",				NStr("ru = 'Уменьшение долга контрагента'; en = 'Decrease company debt'", Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("Ref",							DocumentRefOtherExpenses);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",		NStr("ru = 'Курсовая разница'; en = 'Exchange rate difference'", Metadata.DefaultLanguage.LanguageCode));
	
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	
	Query.Text =
	"SELECT
	|	OtherExpensesExpenses.LineNumber AS LineNumber,
	|	&Company AS Company,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OtherExpensesExpenses.Counterparty AS Counterparty,
	|	OtherExpensesExpenses.Contract AS Contract,
	|	OtherExpensesExpenses.Contract.SettlementsCurrency AS Currency,
	|	CASE
	|		WHEN OtherExpensesExpenses.Counterparty.DoOperationsByOrders
	|			THEN OtherExpensesExpenses.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS Order,
	|	OtherExpensesExpenses.Ref.Date AS Period,
	|	SUM(OtherExpensesExpenses.Amount) AS Amount,
	|	&AccountingForOtherOperations AS PostingContent,
	|	&CommentReceipt AS Comment,
	|	OtherExpensesExpenses.GLExpenseAccount AS GLAccount,
	|	CAST(OtherExpensesExpenses.Amount * CurrencyRatesSettlements.Multiplicity * CurrencyRatesAccounting.ExchangeRate / (CurrencyRatesSettlements.ExchangeRate * CurrencyRatesAccounting.Multiplicity) AS NUMBER(15, 2)) AS AmountCur
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesExpenses
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesSettlements
	|		ON OtherExpensesExpenses.Contract.SettlementsCurrency = CurrencyRatesSettlements.Currency
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, Currency = &AccountingCurrency) AS CurrencyRatesAccounting
	|		ON (CurrencyRatesAccounting.Currency = &AccountingCurrency)
	|WHERE
	|	OtherExpensesExpenses.Ref = &Ref
	|	AND OtherExpensesExpenses.Ref.OtherSettlementsAccounting
	|	AND OtherExpensesExpenses.Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)
	|	AND (OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Debitors)
	|			OR OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Creditors))
	|
	|GROUP BY
	|	OtherExpensesExpenses.LineNumber,
	|	OtherExpensesExpenses.Counterparty,
	|	OtherExpensesExpenses.Contract,
	|	OtherExpensesExpenses.Contract.SettlementsCurrency,
	|	OtherExpensesExpenses.Ref.Date,
	|	CASE
	|		WHEN OtherExpensesExpenses.Counterparty.DoOperationsByOrders
	|			THEN OtherExpensesExpenses.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END,
	|	OtherExpensesExpenses.GLExpenseAccount,
	|	CAST(OtherExpensesExpenses.Amount * CurrencyRatesSettlements.Multiplicity * CurrencyRatesAccounting.ExchangeRate / (CurrencyRatesSettlements.ExchangeRate * CurrencyRatesAccounting.Multiplicity) AS NUMBER(15, 2))
	|
	|UNION ALL
	|
	|SELECT
	|	OtherExpensesExpenses.LineNumber,
	|	&Company,
	|	VALUE(AccumulationRecordType.Expense),
	|	OtherExpenses.Counterparty,
	|	OtherExpenses.Contract,
	|	OtherExpenses.Contract.SettlementsCurrency,
	|	UNDEFINED,
	|	OtherExpenses.Date,
	|	SUM(OtherExpensesExpenses.Amount),
	|	&AccountingForOtherOperations,
	|	&CommentExpense,
	|	OtherExpenses.Correspondence,
	|	CAST(OtherExpensesExpenses.Amount * CurrencyRatesSettlements.Multiplicity * CurrencyRatesAccounting.ExchangeRate / (CurrencyRatesSettlements.ExchangeRate * CurrencyRatesAccounting.Multiplicity) AS NUMBER(15, 2))
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesExpenses
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, Currency = &AccountingCurrency) AS CurrencyRatesAccounting
	|		ON (CurrencyRatesAccounting.Currency = &AccountingCurrency)
	|		INNER JOIN Document.OtherExpenses AS OtherExpenses
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesSettlements
	|			ON OtherExpenses.Contract.SettlementsCurrency = CurrencyRatesSettlements.Currency
	|		ON OtherExpensesExpenses.Ref = OtherExpenses.Ref
	|WHERE
	|	OtherExpensesExpenses.Ref = &Ref
	|	AND OtherExpenses.Ref = &Ref
	|	AND OtherExpensesExpenses.Ref.OtherSettlementsAccounting
	|	AND OtherExpenses.Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)
	|	AND (OtherExpenses.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Debitors)
	|			OR OtherExpenses.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Creditors))
	|
	|GROUP BY
	|	OtherExpensesExpenses.LineNumber,
	|	OtherExpenses.Counterparty,
	|	OtherExpenses.Contract,
	|	OtherExpenses.Contract.SettlementsCurrency,
	|	OtherExpenses.Date,
	|	OtherExpenses.Correspondence,
	|	CAST(OtherExpensesExpenses.Amount * CurrencyRatesSettlements.Multiplicity * CurrencyRatesAccounting.ExchangeRate / (CurrencyRatesSettlements.ExchangeRate * CurrencyRatesAccounting.Multiplicity) AS NUMBER(15, 2))";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSettlementsWithOtherCounterparties", QueryResult.Unload());
	
EndProcedure // GenerateTableSettlementsWithOtherCounterparties()

#EndRegion

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefOtherExpenses, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	OtherExpensesCosts.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OtherExpensesCosts.Ref.Date AS Period,
	|	&Company AS Company,
	|	OtherExpensesCosts.Ref.StructuralUnit AS StructuralUnit,
	|	OtherExpensesCosts.GLExpenseAccount AS GLAccount,
	|	OtherExpensesCosts.CustomerOrder AS CustomerOrder,
	|	OtherExpensesCosts.Amount AS Amount,
	|	TRUE AS FixedCost,
	|	&OtherExpenses AS ContentOfAccountingRecord
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND (OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|			OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OtherExpensesCosts.LineNumber AS LineNumber,
	|	OtherExpensesCosts.Ref.Date AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CreditInterestRates)
	|			THEN VALUE(Catalog.BusinessActivities.Other)
	|		ELSE OtherExpensesCosts.BusinessActivity
	|	END AS BusinessActivity,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CreditInterestRates)
	|			THEN VALUE(Catalog.StructuralUnits.EmptyRef)
	|		ELSE OtherExpensesCosts.Ref.StructuralUnit
	|	END AS StructuralUnit,
	|	OtherExpensesCosts.GLExpenseAccount AS GLAccount,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CreditInterestRates)
	|			THEN UNDEFINED
	|		ELSE OtherExpensesCosts.CustomerOrder
	|	END AS CustomerOrder,
	|	0 AS AmountIncome,
	|	OtherExpensesCosts.Amount AS AmountExpense,
	|	OtherExpensesCosts.Amount AS Amount,
	|	&OtherExpenses AS ContentOfAccountingRecord
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND (OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CreditInterestRates))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OtherExpensesCosts.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	SUM(OtherExpensesCosts.Amount) AS AmountIncome,
	|	SUM(OtherExpensesCosts.Amount) AS Amount,
	|	OtherExpensesCosts.Ref.Correspondence AS GLAccount,
	|	&RevenueIncomes AS ContentOfAccountingRecord
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND OtherExpensesCosts.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|	AND OtherExpensesCosts.Amount > 0
	|
	|GROUP BY
	|	OtherExpensesCosts.Ref,
	|	OtherExpensesCosts.Ref.Date,
	|	OtherExpensesCosts.Ref.Correspondence
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OtherExpensesCosts.LineNumber AS LineNumber,
	|	OtherExpensesCosts.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	OtherExpensesCosts.GLExpenseAccount AS AccountDr,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.Currency
	|			THEN UNDEFINED
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.Currency
	|			THEN 0
	|		ELSE 0
	|	END AS AmountCurDr,
	|	OtherExpensesCosts.Ref.Correspondence AS AccountCr,
	|	CASE
	|		WHEN OtherExpensesCosts.Ref.Correspondence.Currency
	|			THEN UNDEFINED
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN OtherExpensesCosts.Ref.Correspondence.Currency
	|			THEN 0
	|		ELSE 0
	|	END AS AmountCurCr,
	|	OtherExpensesCosts.Amount AS Amount,
	|	&OtherIncome AS Content
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND OtherExpensesCosts.Amount > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS LineNumber,
	|	OtherExpensesExpenses.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	VALUE(Catalog.StructuralUnits.EmptyRef) AS StructuralUnit,
	|	OtherExpensesExpenses.Ref.Correspondence AS GLAccount,
	|	UNDEFINED AS CustomerOrder,
	|	0 AS AmountIncome,
	|	SUM(OtherExpensesExpenses.Amount) AS AmountExpense,
	|	SUM(OtherExpensesExpenses.Amount) AS Amount,
	|	&OtherExpenses AS PostingContent
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesExpenses
	|WHERE
	|	OtherExpensesExpenses.Ref = &Ref
	|	AND (OtherExpensesExpenses.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Creditors)
	|			OR OtherExpensesExpenses.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Debitors))
	|	AND OtherExpensesExpenses.Ref.OtherSettlementsAccounting
	|	AND OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount <> VALUE(Enum.GLAccountsTypes.Expenses)
	|	AND OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount <> VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|	AND OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount <> VALUE(Enum.GLAccountsTypes.CreditInterestRates)
	|	AND OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount <> VALUE(Enum.GLAccountsTypes.UndistributedProfit)
	|
	|GROUP BY
	|	OtherExpensesExpenses.Ref.Date,
	|	OtherExpensesExpenses.Ref.Correspondence
	|
	|UNION ALL
	|
	|SELECT
	|	OtherExpensesExpenses.LineNumber,
	|	OtherExpensesExpenses.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.BusinessActivities.Other),
	|	VALUE(Catalog.StructuralUnits.EmptyRef),
	|	OtherExpensesExpenses.Ref.Correspondence,
	|	UNDEFINED,
	|	OtherExpensesExpenses.Amount,
	|	0,
	|	OtherExpensesExpenses.Amount,
	|	&RevenueIncomes
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesExpenses
	|WHERE
	|	OtherExpensesExpenses.Ref = &Ref
	|	AND (OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Creditors)
	|			OR OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Debitors))
	|	AND OtherExpensesExpenses.Ref.OtherSettlementsAccounting
	|	AND (OtherExpensesExpenses.Ref.Correspondence.TypeOfAccount <> VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			OR OtherExpensesExpenses.Amount < 0)");
	
	Query.SetParameter("Ref", DocumentRefOtherExpenses);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.SetParameter("OtherExpenses", NStr("en='Expenses reflection';ru='Отражение затрат'"));
	Query.SetParameter("RevenueIncomes", NStr("en='Other income';ru='Прочие доходы'"));
	Query.SetParameter("OtherIncome", NStr("en='Other expenses';ru='Прочих затраты (расходы)'"));
	
	ResultsArray = Query.ExecuteBatch();
	
    StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[1].Unload());
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[2].Unload());
	Else
		
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
			FillPropertyValues(NewRow, Selection);
			
		EndDo;
		
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", ResultsArray[3].Unload());
	
	// Other settlements
	If StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[4].Unload());
	Else
		
		Selection = ResultsArray[4].Select();
		While Selection.Next() Do
			
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
			FillPropertyValues(NewRow, Selection);
			
		EndDo;
		
	EndIf;
	
	GenerateTableSettlementsWithOtherCounterparties(DocumentRefOtherExpenses, StructureAdditionalProperties);
	// End Other settlements
	
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