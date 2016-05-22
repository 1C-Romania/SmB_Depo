#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableRetailAmountAccounting(DocumentRefRetailRevaluation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref", DocumentRefRetailRevaluation);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("RetailRevaluation", NStr("en = 'Revaluation in retail'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference'"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Date,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.DocumentCurrency AS Currency,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS GLAccount,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS StructuralUnitGLAccountInRetail,
	|	DocumentTable.StructuralUnitGLAccountMarkup AS StructuralUnitGLAccountMarkup,
	|	DocumentTable.CustomerOrder AS CustomerOrder,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	0 AS Cost,
	|	&RetailRevaluation AS ContentOfAccountingRecord
	|INTO TemporaryTableRetailAmountAccounting
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Company,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.DocumentCurrency,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	DocumentTable.CustomerOrder
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Currency,
	|	GLAccount";
	
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
	
	QueryNumber = 0;
	Query.Text = SmallBusinessServer.GetQueryTextExchangeRateDifferencesRetailAmountAccounting(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableRetailAmountAccounting", ResultsArray[QueryNumber].Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefRetailRevaluation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("IncomeReflection", NStr("en = 'Income accounting'"));
	Query.SetParameter("CostsReflection", NStr("en = 'Costs reflection'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference'"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.StructuralUnits.EmptyRef) AS StructuralUnit,
	|	VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
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
	|	END AS AmountExpenses
	|FROM
	|	TemporaryTableCurrencyExchangeRateDifferencesRetailAmountAccounting AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.StructuralUnit,
	|	VALUE(Document.CustomerOrder.EmptyRef),
	|	VALUE(Catalog.BusinessActivities.Other),
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	&CostsReflection,
	|	0,
	|	-DocumentTable.Amount
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	DocumentTable.StructuralUnitGLAccountMarkup.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.StructuralUnit,
	|	VALUE(Document.CustomerOrder.EmptyRef),
	|	VALUE(Catalog.BusinessActivities.Other),
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	&IncomeReflection,
	|	DocumentTable.Amount,
	|	0
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	DocumentTable.StructuralUnitGLAccountMarkup.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)";
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefRetailRevaluation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("TradeMarkup", NStr("en = 'Trade markup'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference'"));
	Query.SetParameter("IncomeReflection", NStr("en = 'Income accounting'"));
	Query.SetParameter("CostsReflection", NStr("en = 'Costs reflection'"));
		
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS AccountDr,
	|	DocumentTable.StructuralUnitGLAccountMarkup AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE UNDEFINED
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE UNDEFINED
	|	END AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.TypeOfAccount = VALUE(Enum.GLAccountsTypes.TradeMarkup)
	|			THEN &TradeMarkup
	|		ELSE &IncomeReflection
	|	END AS Content
	|FROM
	|	TemporaryTableRetailAmountAccounting AS DocumentTable
	|WHERE
	|	DocumentTable.StructuralUnitGLAccountMarkup.TypeOfAccount <> VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE UNDEFINED
	|	END,
	|	-DocumentTable.Amount,
	|	&CostsReflection
	|FROM
	|	TemporaryTableRetailAmountAccounting AS DocumentTable
	|WHERE
	|	DocumentTable.StructuralUnitGLAccountMarkup.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|
	|UNION ALL
	|
	|SELECT
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
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", QueryResult.Unload());
	
EndProcedure // GenerateTableManagerial()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefRetailRevaluation, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefRetailRevaluation);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Ref.Date AS Date,
	|	VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder,
	|	DocumentTable.Ref.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Ref.StructuralUnit AS StructuralUnit,
	|	DocumentTable.Ref.StructuralUnit.GLAccountInRetail AS StructuralUnitGLAccountInRetail,
	|	DocumentTable.Ref.Correspondence AS StructuralUnitGLAccountMarkup,
	|	&Company AS Company,
	|	SUM(CAST(DocumentTable.Amount * CurrencyRatesOfDocument.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * CurrencyRatesOfDocument.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.Amount) AS AmountCur
	|INTO TemporaryTableInventory
	|FROM
	|	Document.RetailRevaluation.Inventory AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfDocument
	|		ON DocumentTable.Ref.DocumentCurrency = CurrencyRatesOfDocument.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Ref.DocumentCurrency,
	|	DocumentTable.Ref.StructuralUnit,
	|	DocumentTable.Ref.StructuralUnit.GLAccountInRetail,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Correspondence";
	
	Query.ExecuteBatch();
	
	// Register record table creation by account sections.
	GenerateTableRetailAmountAccounting(DocumentRefRetailRevaluation, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefRetailRevaluation, StructureAdditionalProperties);
	GenerateTableManagerial(DocumentRefRetailRevaluation, StructureAdditionalProperties);
		
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefRetailRevaluation, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.ControlBalancesOnPosting.Get() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsRetailAmountAccountingUpdate Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsRetailAmountAccountingUpdate.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsRetailAmountAccountingUpdate.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsRetailAmountAccountingUpdate.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsRetailAmountAccountingUpdate.StructuralUnit.RetailPriceKind.PriceCurrency) AS CurrencyPresentation,
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
		|		LEFT JOIN AccumulationRegister.RetailAmountAccounting.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit) In
		|					(SELECT
		|						RegisterRecordsRetailAmountAccountingUpdate.Company AS Company,
		|						RegisterRecordsRetailAmountAccountingUpdate.StructuralUnit AS StructuralUnit
		|					FROM
		|						RegisterRecordsRetailAmountAccountingUpdate AS RegisterRecordsRetailAmountAccountingUpdate)) AS RetailAmountAccountingBalances
		|		ON RegisterRecordsRetailAmountAccountingUpdate.Company = RetailAmountAccountingBalances.Company
		|			AND RegisterRecordsRetailAmountAccountingUpdate.StructuralUnit = RetailAmountAccountingBalances.StructuralUnit
		|WHERE
		|	ISNULL(RetailAmountAccountingBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty() Then
			DocumentObjectRetailRevaluation = DocumentRefRetailRevaluation.GetObject()
		EndIf;
		
		// Negative balance according to the amount-based account in retail.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToRetailAmountAccountingRegisterErrors(DocumentObjectRetailRevaluation, QueryResultSelection, Cancel);
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