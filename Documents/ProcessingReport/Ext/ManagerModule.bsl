#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
		
	//( elmi #11
    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
	|	Sum(TemporaryTable.VATAmount) AS VATExpenses ,
	|	Sum(TemporaryTable.VATAmountCur) AS VATExpensesCur 
	|FROM
	|	TemporaryTableProduction AS TemporaryTable
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
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Period AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableManagerial.GLAccountCustomerSettlements AS AccountDr,
	|	CASE
	|		WHEN TableManagerial.GLAccountCustomerSettlements.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableManagerial.GLAccountCustomerSettlements.Currency
	//( elmi #11
    //|			THEN TableManagerial.AmountCur
	|			THEN TableManagerial.AmountCur - TableManagerial.VATAmountCur     
	//) elmi
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableManagerial.AccountStatementSales AS AccountCr,
	|	CASE
	|		WHEN TableManagerial.AccountStatementSales.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableManagerial.AccountStatementSales.Currency
	//( elmi #11
	//|			THEN TableManagerial.AmountCur
	|			THEN TableManagerial.AmountCur - TableManagerial.VATAmountCur      
	|		ELSE 0
	|	END AS AmountCurCr,
	//|	TableManagerial.Amount AS Amount,
	|	TableManagerial.Amount  - TableManagerial.VATAmount AS Amount,             
	//) elmi
	|	&IncomeReflection AS Content
	|FROM
	|	TemporaryTableProduction AS TableManagerial
	|WHERE
	|	TableManagerial.Amount <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountForeignCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountForeignCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	&SetOffAdvancePayment
	|FROM
	|	(SELECT
	|		DocumentTable.Period AS Period,
	|		DocumentTable.Company AS Company,
	|		DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|		DocumentTable.CustomerAdvancesGLAccountForeignCurrency AS CustomerAdvancesGLAccountForeignCurrency,
	|		DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|		DocumentTable.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|		SUM(DocumentTable.AmountCur) AS AmountCur,
	|		SUM(DocumentTable.Amount) AS Amount
	|	FROM
	|		(SELECT
	|			DocumentTable.Period AS Period,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|			DocumentTable.CustomerAdvancesGLAccount.Currency AS CustomerAdvancesGLAccountForeignCurrency,
	|			DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|			DocumentTable.GLAccountCustomerSettlements.Currency AS GLAccountCustomerSettlementsCurrency,
	|			DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|			DocumentTable.AmountCur AS AmountCur,
	|			DocumentTable.Amount AS Amount
	|		FROM
	|			TemporaryTablePrepayment AS DocumentTable
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.Counterparty.CustomerAdvancesGLAccount,
	|			DocumentTable.Counterparty.CustomerAdvancesGLAccount.Currency,
	|			DocumentTable.Counterparty.GLAccountCustomerSettlements,
	|			DocumentTable.Counterparty.GLAccountCustomerSettlements.Currency,
	|			DocumentTable.Currency,
	|			0,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Company,
	|		DocumentTable.CustomerAdvancesGLAccount,
	|		DocumentTable.CustomerAdvancesGLAccountForeignCurrency,
	|		DocumentTable.GLAccountCustomerSettlements,
	|		DocumentTable.GLAccountCustomerSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency
	|	
	|	HAVING
	|		(SUM(DocumentTable.Amount) >= 0.005
	|			OR SUM(DocumentTable.Amount) <= -0.005
	|			OR SUM(DocumentTable.AmountCur) >= 0.005
	|			OR SUM(DocumentTable.AmountCur) <= -0.005)) AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	TableManagerial.Date,
	|	TableManagerial.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|			THEN TableManagerial.GLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|				AND TableManagerial.GLAccountForeignCurrency
	|			THEN TableManagerial.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE TableManagerial.GLAccount
	|	END,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences < 0
	|				AND TableManagerial.GLAccountForeignCurrency
	|			THEN TableManagerial.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|			THEN TableManagerial.AmountOfExchangeDifferences
	|		ELSE -TableManagerial.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference
	|FROM
	|	(SELECT
	|		TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccount AS GLAccount,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccountForeignCurrency AS GLAccountForeignCurrency,
	|		TableExchangeRateDifferencesAccountsReceivable.Currency AS Currency,
	|		SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.GLAccount AS GLAccount,
	|			DocumentTable.GLAccount.Currency AS GLAccountForeignCurrency,
	|			DocumentTable.Currency AS Currency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.GLAccount,
	|			DocumentTable.GLAccount.Currency,
	|			DocumentTable.Currency,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableExchangeRateDifferencesAccountsReceivable
	|	
	|	GROUP BY
	|		TableExchangeRateDifferencesAccountsReceivable.Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccount,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccountForeignCurrency,
	|		TableExchangeRateDifferencesAccountsReceivable.Currency
	|	
	|	HAVING
	|		(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)) AS TableManagerial
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	4 AS Ordering,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Period AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
    |	&TextVAT,
	|   UNDEFINED,
	|	0 ,
	|	TableManagerial.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TableManagerial.GLAccountCustomerSettlements.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END ,
	|	CASE
	|		WHEN TableManagerial.GLAccountCustomerSettlements.Currency
	|			THEN &VATExpensesCur
	|		ELSE 0
	|	END,
	|	&VATExpenses,
	|	&VAT 
	|FROM
	|	TemporaryTableProduction AS TableManagerial
	|WHERE &VATExpenses <> 0
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference'"));
	Query.SetParameter("SetOffAdvancePayment", NStr("en = 'Setoff of advance payment'"));
	Query.SetParameter("PrepaymentReversal", NStr("en = 'Prepayment reversing'"));
	Query.SetParameter("ReversingSupplies", NStr("en = 'Delivery reversing'"));
	Query.SetParameter("IncomeReflection", NStr("en = 'Sales revenue'"));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	//( elmi #11
	Query.SetParameter("VAT", NStr("en=' VAT '"));
	Query.SetParameter("TextVAT",  ChartsOfAccounts.Managerial.Taxes);
	Query.SetParameter("VATExpenses", VATExpenses);
	Query.SetParameter("VATExpensesCur", VATExpensesCur);
	//) elmi

	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do  
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure // GenerateTableManagerial()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableInventory.Document AS Document,
	|	TableInventory.Document AS SalesDocument,
	|	TableInventory.CustomerOrder AS OrderSales,
	|	TableInventory.DivisionSales AS Division,
	|	TableInventory.Responsible AS Responsible,
	|	TableInventory.BusinessActivitySales AS BusinessActivity,
	|	TableInventory.GLAccountCost AS GLAccountCost,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.DivisionSales AS DivisionSales,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.VATRate AS VATRate,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Reserve) AS Reserve,
	|	SUM(TableInventory.VATAmount) AS VATAmount,
	|	SUM(TableInventory.Amount) AS Amount,
	|	0 AS Cost,
	|	FALSE AS FixedCost,
	|	TableInventory.GLAccountCost AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	&InventoryWriteOff AS Content,
	|	&InventoryWriteOff AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableProduction AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.Document,
	|	TableInventory.BusinessActivitySales,
	|	TableInventory.GLAccountCost,
	|	TableInventory.StructuralUnit,
	|	TableInventory.DivisionSales,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.VATRate,
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder,
	|	TableInventory.Responsible,
	|	TableInventory.Document,
	|	TableInventory.DivisionSales,
	|	TableInventory.CustomerOrder,
	|	TableInventory.GLAccountCost,
	|	TableInventory.GLAccount";
	
	Query.SetParameter("InventoryWriteOff", NStr("en = 'Inventory write off'"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.CustomerOrder AS CustomerOrder
	|FROM
	|	TemporaryTableProduction AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult IN QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text = 	
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.CustomerOrder AS CustomerOrder,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.CustomerOrder AS CustomerOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.CustomerOrder
	|					FROM
	|						TemporaryTableProduction AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.ProductsAndServices,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		DocumentRegisterRecordsInventory.CustomerOrder,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.CustomerOrder";
	
	Query.SetParameter("Ref", DocumentRefReportAboutRecycling);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch,CustomerOrder");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("ProductsAndServices", RowTableInventory.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredReserve = RowTableInventory.Reserve;
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
		If QuantityRequiredReserve > 0 Then
			
			QuantityRequiredAvailableBalance = QuantityRequiredAvailableBalance - QuantityRequiredReserve;
			
			StructureForSearch.Insert("CustomerOrder", RowTableInventory.CustomerOrder);
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredReserve Then
				
				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredReserve / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredReserve;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityRequiredReserve Then
				
				AmountToBeWrittenOff = AmountBalance;
				
				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Expense. Inventory.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredReserve;
									
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Generate postings.
				RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerial, RowTableInventory);
				RowTableManagerial.Amount = AmountToBeWrittenOff;
				
				// Move the cost of sales.
				SaleString = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
				FillPropertyValues(SaleString, RowTableInventory);
				SaleString.Quantity = 0;
				SaleString.Amount = 0;
				SaleString.VATAmount = 0;
				SaleString.Cost = AmountToBeWrittenOff;
				
				// Move income and expenses.
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.StructuralUnit = RowTableInventory.DivisionSales;
				RowIncomeAndExpenses.GLAccount = RowTableInventory.GLAccountCost;
				RowIncomeAndExpenses.AmountIncome = 0;
				RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
				RowIncomeAndExpenses.Amount = AmountToBeWrittenOff;
				
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en='Costs reflection'");				
			
			EndIf;
			
		EndIf;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			StructureForSearch.Insert("CustomerOrder", Documents.CustomerOrder.EmptyRef());
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = AmountBalance;
				
				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Expense. Inventory.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.CustomerOrder = Documents.CustomerOrder.EmptyRef();
					
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Generate postings.
				RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerial, RowTableInventory);
				RowTableManagerial.Amount = AmountToBeWrittenOff;
				
				// Move the cost of sales.
				SaleString = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
				FillPropertyValues(SaleString, RowTableInventory);
				SaleString.Quantity = 0;
				SaleString.Amount = 0;
				SaleString.VATAmount = 0;
				SaleString.Cost = AmountToBeWrittenOff;
				
				// Move income and expenses.
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.StructuralUnit = RowTableInventory.DivisionSales;
				RowIncomeAndExpenses.GLAccount = RowTableInventory.GLAccountCost;
				RowIncomeAndExpenses.AmountIncome = 0;
				RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
				RowIncomeAndExpenses.Amount = AmountToBeWrittenOff;
				
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en='Costs reflection'");
								
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
			
EndProcedure // GenerateTableInventory()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDisposals(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	0 AS Amount,
	|	&InventoryWriteOff AS Content,
	|	&InventoryWriteOff AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableWaste AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder";
	
	Query.SetParameter("InventoryWriteOff", NStr("en = 'Inventory write off'"));
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDisposals", QueryResult.Unload());

	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals[n];
		
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowExpense, RowTableInventory);
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryDisposals");
	
EndProcedure // GenerateTableInventoryDisposals()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.ProductsAndServices AS ProductsAndServices,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	TableSales.CustomerOrder AS CustomerOrder,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.DivisionSales AS Division,
	|	TableSales.Responsible AS Responsible,
	|	SUM(TableSales.Quantity) AS Quantity,
	|	SUM(TableSales.VATAmountSales) AS VATAmount,
	|	SUM(TableSales.Amount) AS Amount,
	|	0 AS Cost
	|FROM
	|	TemporaryTableProduction AS TableSales
	|
	|GROUP BY
	|	TableSales.Period,
	|	TableSales.Company,
	|	TableSales.ProductsAndServices,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.CustomerOrder,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.DivisionSales,
	|	TableSales.Responsible";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure // GenerateTableSales()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MIN(TableInventoryInWarehouses.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventoryInWarehouses.Period AS Period,
	|	TableInventoryInWarehouses.Company AS Company,
	|	TableInventoryInWarehouses.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryInWarehouses.Characteristic AS Characteristic,
	|	TableInventoryInWarehouses.Batch AS Batch,
	|	TableInventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	TableInventoryInWarehouses.Cell AS Cell,
	|	SUM(TableInventoryInWarehouses.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableInventoryInWarehouses
	|WHERE
	|	(NOT TableInventoryInWarehouses.OrderWarehouse)
	|
	|GROUP BY
	|	TableInventoryInWarehouses.Period,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.ProductsAndServices,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	MIN(TableInventoryInWarehouses.LineNumber),
	|	VALUE(AccumulationRecordType.Expense),
	|	TableInventoryInWarehouses.Period,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.ProductsAndServices,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell,
	|	SUM(TableInventoryInWarehouses.Quantity)
	|FROM
	|	TemporaryTableWaste AS TableInventoryInWarehouses
	|WHERE
	|	(NOT TableInventoryInWarehouses.OrderWarehouse)
	|
	|GROUP BY
	|	TableInventoryInWarehouses.Period,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.ProductsAndServices,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryInWarehouses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryForExpenseFromWarehouses(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MIN(TableInventoryForExpenseFromWarehouses.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventoryForExpenseFromWarehouses.Period AS Period,
	|	TableInventoryForExpenseFromWarehouses.Company AS Company,
	|	TableInventoryForExpenseFromWarehouses.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryForExpenseFromWarehouses.Characteristic AS Characteristic,
	|	TableInventoryForExpenseFromWarehouses.Batch AS Batch,
	|	TableInventoryForExpenseFromWarehouses.StructuralUnit AS StructuralUnit,
	|	SUM(TableInventoryForExpenseFromWarehouses.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableInventoryForExpenseFromWarehouses
	|WHERE
	|	TableInventoryForExpenseFromWarehouses.OrderWarehouse
	|
	|GROUP BY
	|	TableInventoryForExpenseFromWarehouses.Period,
	|	TableInventoryForExpenseFromWarehouses.Company,
	|	TableInventoryForExpenseFromWarehouses.ProductsAndServices,
	|	TableInventoryForExpenseFromWarehouses.Characteristic,
	|	TableInventoryForExpenseFromWarehouses.Batch,
	|	TableInventoryForExpenseFromWarehouses.StructuralUnit
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	MIN(TableInventoryForExpenseFromWarehouses.LineNumber),
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventoryForExpenseFromWarehouses.Period,
	|	TableInventoryForExpenseFromWarehouses.Company,
	|	TableInventoryForExpenseFromWarehouses.ProductsAndServices,
	|	TableInventoryForExpenseFromWarehouses.Characteristic,
	|	TableInventoryForExpenseFromWarehouses.Batch,
	|	TableInventoryForExpenseFromWarehouses.StructuralUnit,
	|	SUM(TableInventoryForExpenseFromWarehouses.Quantity)
	|FROM
	|	TemporaryTableWaste AS TableInventoryForExpenseFromWarehouses
	|WHERE
	|	TableInventoryForExpenseFromWarehouses.OrderWarehouse
	|
	|GROUP BY
	|	TableInventoryForExpenseFromWarehouses.Period,
	|	TableInventoryForExpenseFromWarehouses.Company,
	|	TableInventoryForExpenseFromWarehouses.ProductsAndServices,
	|	TableInventoryForExpenseFromWarehouses.Characteristic,
	|	TableInventoryForExpenseFromWarehouses.Batch,
	|	TableInventoryForExpenseFromWarehouses.StructuralUnit";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryForExpenseFromWarehouses", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryForExpenseFromWarehouses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryReceived(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MIN(TableInventoryReceived.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventoryReceived.Period AS Period,
	|	TableInventoryReceived.Company AS Company,
	|	TableInventoryReceived.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryReceived.Characteristic AS Characteristic,
	|	TableInventoryReceived.Batch AS Batch,
	|	UNDEFINED AS Counterparty,
	|	UNDEFINED AS Contract,
	|	CASE
	|		WHEN TableInventoryReceived.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|				AND FunctionalOptionInventoryReservation.Value
	|			THEN TableInventoryReceived.CustomerOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	VALUE(Enum.ProductsReceiptTransferTypes.ReportByProcessing) AS ReceptionTransmissionType,
	|	SUM(TableInventoryReceived.Quantity) AS Quantity,
	|	0 AS SettlementsAmount,
	|	0 AS SalesAmount
	|FROM
	|	TemporaryTableInventory AS TableInventoryReceived,
	|	Constant.FunctionalOptionInventoryReservation AS FunctionalOptionInventoryReservation
	|WHERE
	|	TableInventoryReceived.BatchStatus = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|
	|GROUP BY
	|	TableInventoryReceived.Period,
	|	TableInventoryReceived.Company,
	|	TableInventoryReceived.ProductsAndServices,
	|	TableInventoryReceived.Characteristic,
	|	TableInventoryReceived.Batch,
	|	CASE
	|		WHEN TableInventoryReceived.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|				AND FunctionalOptionInventoryReservation.Value
	|			THEN TableInventoryReceived.CustomerOrder
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	MIN(TableInventoryReceived.LineNumber),
	|	VALUE(AccumulationRecordType.Expense),
	|	TableInventoryReceived.Period,
	|	TableInventoryReceived.Company,
	|	TableInventoryReceived.ProductsAndServices,
	|	TableInventoryReceived.Characteristic,
	|	TableInventoryReceived.Batch,
	|	TableInventoryReceived.Counterparty,
	|	TableInventoryReceived.Contract,
	|	CASE
	|		WHEN TableInventoryReceived.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN TableInventoryReceived.CustomerOrder
	|		ELSE UNDEFINED
	|	END,
	|	VALUE(Enum.ProductsReceiptTransferTypes.ReceiptToProcessing),
	|	SUM(TableInventoryReceived.Quantity),
	//|	SUM(TableInventoryReceived.SettlementsAmountTakenPassed),
	|	SUM(TableInventoryReceived.SettlementsAmountTakenPassed - TableInventoryReceived.VATAmount),
	|	0
	|FROM
	|	TemporaryTableInventory AS TableInventoryReceived
	|WHERE
	|	TableInventoryReceived.BatchStatus = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|
	|GROUP BY
	|	TableInventoryReceived.Period,
	|	TableInventoryReceived.Company,
	|	TableInventoryReceived.ProductsAndServices,
	|	TableInventoryReceived.Characteristic,
	|	TableInventoryReceived.Batch,
	|	TableInventoryReceived.Counterparty,
	|	TableInventoryReceived.Contract,
	|	CASE
	|		WHEN TableInventoryReceived.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN TableInventoryReceived.CustomerOrder
	|		ELSE UNDEFINED
	|	END";
	
	Query.SetParameter("InventoryReception", NStr("en = 'Inventory receiving'"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryReceived", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryReceived()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableIncomeAndExpenses.LineNumber AS LineNumber,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.DivisionSales AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessActivitySales AS BusinessActivity,
	|	TableIncomeAndExpenses.CustomerOrder AS CustomerOrder,
	|	TableIncomeAndExpenses.AccountStatementSales AS GLAccount,
	|	CAST(&IncomeReflection AS String(100)) AS ContentOfAccountingRecord,
	//( elmi #11
	//|	SUM(TableIncomeAndExpenses.Amount) AS AmountIncome,
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS AmountIncome,   
	|	0 AS AmountExpense,
	//|	SUM(TableIncomeAndExpenses.Amount) AS Amount
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS Amount          
	//) elmi
	|FROM
	|	TemporaryTableProduction AS TableIncomeAndExpenses
	|WHERE
	|	TableIncomeAndExpenses.Amount <> 0
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.LineNumber,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.DivisionSales,
	|	TableIncomeAndExpenses.BusinessActivitySales,
	|	TableIncomeAndExpenses.CustomerOrder,
	|	TableIncomeAndExpenses.AccountStatementSales
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	VALUE(Catalog.BusinessActivities.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
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
	|	(SELECT
	|		TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|		SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableExchangeRateDifferencesAccountsReceivable
	|	
	|	GROUP BY
	|		TableExchangeRateDifferencesAccountsReceivable.Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company
	|	
	|	HAVING
	|		(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)) AS DocumentTable
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	Query.SetParameter("IncomeReflection", NStr("en='Income accounting'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference'"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerOrders(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableCustomerOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableCustomerOrders.Period AS Period,
	|	TableCustomerOrders.Company AS Company,
	|	TableCustomerOrders.ProductsAndServices AS ProductsAndServices,
	|	TableCustomerOrders.Characteristic AS Characteristic,
	|	TableCustomerOrders.CustomerOrder AS CustomerOrder,
	|	SUM(TableCustomerOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableCustomerOrders
	|WHERE
	|	TableCustomerOrders.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|
	|GROUP BY
	|	TableCustomerOrders.Period,
	|	TableCustomerOrders.Company,
	|	TableCustomerOrders.ProductsAndServices,
	|	TableCustomerOrders.Characteristic,
	|	TableCustomerOrders.CustomerOrder";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCustomerOrders", QueryResult.Unload());
	
EndProcedure // GenerateTableCustomerOrders()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefReportAboutRecycling);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerLiability", NStr("en='Appearance of customer liabilities'"));
	Query.SetParameter("AdvanceCredit", NStr("en='Setoff of advance payment'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference'"));
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.GLAccountCustomerSettlements AS GLAccount,
	|	DocumentTable.Contract AS Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	CAST(&AppearenceOfCustomerLiability AS String(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableProduction AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.SettlementsCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS String(100))
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.CustomerAdvancesGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS String(100))
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere
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
	Query.Text = SmallBusinessServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, True, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[QueryNumber].Unload());
	
EndProcedure // GenerateTableAccountsReceivable()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefReportAboutRecycling);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
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
	|	DocumentTable.BusinessActivitySales AS BusinessActivity,
	//( elmi #11
	//|	DocumentTable.Amount AS AmountIncome
	|	DocumentTable.Amount - DocumentTable.VATAmount AS AmountIncome        
	//) elmi
	|FROM
	|	TemporaryTableProduction AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Amount <> 0
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Company AS Company,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|GROUP BY
	|	DocumentTable.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Item AS Item
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber";
	
	ResultsArray = Query.ExecuteBatch();
	
	TableInventoryIncomeAndExpensesRetained = ResultsArray[0].Unload();
	SelectionOfQueryResult = ResultsArray[1].Select();

	TablePrepaymentIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Copy();
	TablePrepaymentIncomeAndExpensesRetained.Clear();
	
	If SelectionOfQueryResult.Next() Then
		AmountToBeWrittenOff = SelectionOfQueryResult.AmountToBeWrittenOff;
		For Each StringInventoryIncomeAndExpensesRetained IN TableInventoryIncomeAndExpensesRetained Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountIncome <= AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				AmountToBeWrittenOff = AmountToBeWrittenOff - StringInventoryIncomeAndExpensesRetained.AmountIncome;
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountIncome > AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				StringPrepaymentIncomeAndExpensesRetained.AmountIncome = AmountToBeWrittenOff;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndIf;
	
	For Each StringPrepaymentIncomeAndExpensesRetained IN TablePrepaymentIncomeAndExpensesRetained Do
		StringInventoryIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Add();
		FillPropertyValues(StringInventoryIncomeAndExpensesRetained, StringPrepaymentIncomeAndExpensesRetained);
		StringInventoryIncomeAndExpensesRetained.RecordType = AccumulationRecordType.Expense;
	EndDo;
	
	SelectionOfQueryResult = ResultsArray[2].Select();
	
	If SelectionOfQueryResult.Next() Then
		Item = SelectionOfQueryResult.Item;
	Else
		Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.Document AS Document,
	|	&Item AS Item,
	|	Table.BusinessActivity AS BusinessActivity,
	|	Table.AmountIncome AS AmountIncome
	|INTO TemporaryTablePrepaidIncomeAndExpensesRetained
	|FROM
	|	&Table AS Table";
	Query.SetParameter("Table", TablePrepaymentIncomeAndExpensesRetained);
	Query.SetParameter("Item", Item);
	
	Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", TableInventoryIncomeAndExpensesRetained);
	
EndProcedure // GenerateTableIncomeAndExpensesRetained()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesUndistributed(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountIncome
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesUndistributed", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesUndistributed()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefReportAboutRecycling);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.DocumentDate AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS BusinessActivity,
	|	DocumentTable.Item AS Item,
	|	-DocumentTable.Amount AS AmountIncome
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.BusinessActivity,
	|	Table.Item,
	|	Table.AmountIncome
	|FROM
	|	TemporaryTablePrepaidIncomeAndExpensesRetained AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesCashMethod()

#Region AutomaticDiscounts

// Generates a table of values that contains the data for posting by the register AutomaticDiscountsApplied.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefReportAboutRecycling, StructureAdditionalProperties)
	
	If DocumentRefReportAboutRecycling.DiscountsMarkups.Count() = 0 Or Not GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableAutoDiscountsMarkups.Period,
	|	TemporaryTableAutoDiscountsMarkups.DiscountMarkup AS AutomaticDiscount,
	|	TemporaryTableAutoDiscountsMarkups.Amount AS DiscountAmount,
	|	TemporaryTableProduction.ProductsAndServices,
	|	TemporaryTableProduction.Characteristic,
	|	TemporaryTableProduction.Document AS DocumentDiscounts,
	|	TemporaryTableProduction.Counterparty AS RecipientDiscounts
	|FROM
	|	TemporaryTableProduction AS TemporaryTableProduction
	|		INNER JOIN TemporaryTableAutoDiscountsMarkups AS TemporaryTableAutoDiscountsMarkups
	|		ON TemporaryTableProduction.ConnectionKey = TemporaryTableAutoDiscountsMarkups.ConnectionKey";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", QueryResult.Unload());
	
EndProcedure // GenerateTableSalesByAutomaticDiscountsApplied()

#EndRegion

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefReportAboutRecycling, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ProcessingReportProducts.LineNumber AS LineNumber,
	|	ProcessingReportProducts.Ref.Date AS Period,
	|	ProcessingReportProducts.Ref AS Document,
	|	ProcessingReportProducts.Ref.Counterparty AS Counterparty,
	|	ProcessingReportProducts.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	ProcessingReportProducts.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	ProcessingReportProducts.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	ProcessingReportProducts.Ref.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	ProcessingReportProducts.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	ProcessingReportProducts.Ref.Contract AS Contract,
	|	ProcessingReportProducts.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	&Company AS Company,
	|	ProcessingReportProducts.Ref.Division AS DivisionSales,
	|	ProcessingReportProducts.Ref.Responsible AS Responsible,
	|	ProcessingReportProducts.ProductsAndServices.BusinessActivity AS BusinessActivitySales,
	|	ProcessingReportProducts.ProductsAndServices.BusinessActivity.GLAccountRevenueFromSales AS AccountStatementSales,
	|	ProcessingReportProducts.ProductsAndServices.BusinessActivity.GLAccountCostOfSales AS GLAccountCost,
	|	ProcessingReportProducts.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN ProcessingReportProducts.Ref.StructuralUnit.OrderWarehouse
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS OrderWarehouse,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN ProcessingReportProducts.Ref.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	ProcessingReportProducts.ProductsAndServices.InventoryGLAccount AS GLAccount,
	|	ProcessingReportProducts.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProcessingReportProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProcessingReportProducts.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	ProcessingReportProducts.Ref.CustomerOrder AS CustomerOrder,
	|	CASE
	|		WHEN VALUETYPE(ProcessingReportProducts.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProcessingReportProducts.Quantity
	|		ELSE ProcessingReportProducts.Quantity * ProcessingReportProducts.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(ProcessingReportProducts.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProcessingReportProducts.Reserve
	|		ELSE ProcessingReportProducts.Reserve * ProcessingReportProducts.MeasurementUnit.Factor
	|	END AS Reserve,
	|	ProcessingReportProducts.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN ProcessingReportProducts.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN ProcessingReportProducts.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN ProcessingReportProducts.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE ProcessingReportProducts.VATAmount * ProcessingReportProducts.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ProcessingReportProducts.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN ProcessingReportProducts.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN ProcessingReportProducts.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE ProcessingReportProducts.VATAmount * ProcessingReportProducts.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ProcessingReportProducts.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmountSales,
	|	CAST(CASE
	|			WHEN ProcessingReportProducts.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN ProcessingReportProducts.Total * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE ProcessingReportProducts.Total * ProcessingReportProducts.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ProcessingReportProducts.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN ProcessingReportProducts.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN ProcessingReportProducts.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN ProcessingReportProducts.VATAmount * RegCurrencyRates.ExchangeRate * ProcessingReportProducts.Ref.Multiplicity / (ProcessingReportProducts.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE ProcessingReportProducts.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN ProcessingReportProducts.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN ProcessingReportProducts.Total * RegCurrencyRates.ExchangeRate * ProcessingReportProducts.Ref.Multiplicity / (ProcessingReportProducts.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE ProcessingReportProducts.Total
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	ProcessingReportProducts.ConnectionKey
	|INTO TemporaryTableProduction
	|FROM
	|	Document.ProcessingReport.Products AS ProcessingReportProducts
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.AccountingCurrency AS ConstantAccountingCurrency)) AS ManagCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.NationalCurrency AS ConstantNationalCurrency)) AS RegCurrencyRates
	|		ON (TRUE),
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|WHERE
	|	ProcessingReportProducts.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProcessingReportInventory.LineNumber AS LineNumber,
	|	ProcessingReportInventory.Ref AS Document,
	|	ProcessingReportInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	ProcessingReportInventory.Ref.Counterparty AS Counterparty,
	|	ProcessingReportInventory.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	ProcessingReportInventory.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	ProcessingReportInventory.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	ProcessingReportInventory.Ref.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	ProcessingReportInventory.Ref.Contract AS Contract,
	|	ProcessingReportInventory.ProductsAndServices.InventoryGLAccount AS GLAccount,
	|	ProcessingReportInventory.Batch.Status AS BatchStatus,
	|	ProcessingReportInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProcessingReportInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProcessingReportInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(ProcessingReportInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProcessingReportInventory.Quantity
	|		ELSE ProcessingReportInventory.Quantity * ProcessingReportInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	ProcessingReportInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN ProcessingReportInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN ProcessingReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN ProcessingReportInventory.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE ProcessingReportInventory.VATAmount * ProcessingReportInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ProcessingReportInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN ProcessingReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN ProcessingReportInventory.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE ProcessingReportInventory.VATAmount * ProcessingReportInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ProcessingReportInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmountSales,
	|	CAST(CASE
	|			WHEN ProcessingReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN ProcessingReportInventory.Total * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE ProcessingReportInventory.Total * ProcessingReportInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ProcessingReportInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	ProcessingReportInventory.Total AS SettlementsAmountTakenPassed,
	|	ProcessingReportInventory.Ref.CustomerOrder AS CustomerOrder
	|INTO TemporaryTableInventory
	|FROM
	|	Document.ProcessingReport.Inventory AS ProcessingReportInventory
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.AccountingCurrency AS ConstantAccountingCurrency)) AS ManagCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.NationalCurrency AS ConstantNationalCurrency)) AS RegCurrencyRates
	|		ON (TRUE),
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|WHERE
	|	ProcessingReportInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProcessingReportDisposals.LineNumber AS LineNumber,
	|	ProcessingReportDisposals.Ref.Date AS Period,
	|	&Company AS Company,
	|	ProcessingReportDisposals.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN ProcessingReportDisposals.Ref.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	CASE
	|		WHEN ProcessingReportDisposals.Ref.StructuralUnit.OrderWarehouse
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS OrderWarehouse,
	|	ProcessingReportDisposals.ProductsAndServices.InventoryGLAccount AS GLAccount,
	|	ProcessingReportDisposals.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProcessingReportDisposals.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProcessingReportDisposals.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	ProcessingReportDisposals.Ref.CustomerOrder AS CustomerOrder,
	|	CASE
	|		WHEN VALUETYPE(ProcessingReportDisposals.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProcessingReportDisposals.Quantity
	|		ELSE ProcessingReportDisposals.Quantity * ProcessingReportDisposals.MeasurementUnit.Factor
	|	END AS Quantity
	|INTO TemporaryTableWaste
	|FROM
	|	Document.ProcessingReport.Disposals AS ProcessingReportDisposals
	|WHERE
	|	ProcessingReportDisposals.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.Counterparty AS Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	DocumentTable.Ref.Contract AS Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentTable.Ref.CustomerOrder AS Order,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivitySales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN Not DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = Type(Document.Netting)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE DocumentTable.Document.Item
	|	END AS Item,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Date
	|		ELSE DocumentTable.Ref.Date
	|	END AS DocumentDate,
	|	SUM(CAST(DocumentTable.SettlementsAmount * DocumentTable.Ref.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * DocumentTable.Ref.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.ProcessingReport.Prepayment AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.AccountingCurrency AS ConstantAccountingCurrency)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Document,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN Not DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = Type(Document.Netting)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE DocumentTable.Document.Item
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Date
	|		ELSE DocumentTable.Ref.Date
	|	END,
	|	DocumentTable.Ref.CustomerOrder,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProcessingReportDiscountsMarkups.ConnectionKey,
	|	ProcessingReportDiscountsMarkups.DiscountMarkup,
	|	CAST(CASE
	|			WHEN ProcessingReportDiscountsMarkups.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN ProcessingReportDiscountsMarkups.Amount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE ProcessingReportDiscountsMarkups.Amount * ProcessingReportDiscountsMarkups.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ProcessingReportDiscountsMarkups.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	ProcessingReportDiscountsMarkups.Ref.Date AS Period,
	|	ProcessingReportDiscountsMarkups.Ref.StructuralUnit
	|INTO TemporaryTableAutoDiscountsMarkups
	|FROM
	|	Document.ProcessingReport.DiscountsMarkups AS ProcessingReportDiscountsMarkups
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.AccountingCurrency AS ConstantAccountingCurrency)) AS ManagCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.NationalCurrency AS ConstantNationalCurrency)) AS RegCurrencyRates
	|		ON (TRUE),
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|WHERE
	|	ProcessingReportDiscountsMarkups.Ref = &Ref
	|	AND ProcessingReportDiscountsMarkups.Amount <> 0";
	
	Query.SetParameter("Ref", DocumentRefReportAboutRecycling);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	SmallBusinessServer.GenerateTransactionsTable(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	
	GenerateTableSales(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableInventoryInWarehouses(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableInventoryForExpenseFromWarehouses(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableInventoryReceived(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableCustomerOrders(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	
	GenerateTableInventory(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableInventoryDisposals(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	
	GenerateTableIncomeAndExpensesRetained(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesUndistributed(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	
	GenerateTableManagerial(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	
	// AutomaticDiscounts
	GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefReportAboutRecycling, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefReportAboutRecycling, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", "TransferInventoryInWarehousesChange",
	// "RegisterRecordsInventoryFromWarehousesChange", "RegisterRecordsInventoryReceivedChange"
	// contain entries, it is necessary to perform control of product selling.
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryFromWarehousesChange 
	 OR StructureTemporaryTables.RegisterRecordsInventoryReceivedChange
	 OR StructureTemporaryTables.RegisterRecordsAccountsReceivableChange Then
		
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
		|	RegisterRecordsInventoryReceivedChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType) AS ReceptionTransmissionTypePresentation,
		|	REFPRESENTATION(InventoryReceivedBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryReceivedChange.QuantityChange, 0) + ISNULL(InventoryReceivedBalances.QuantityBalance, 0) AS BalanceInventoryReceived,
		|	ISNULL(InventoryReceivedBalances.QuantityBalance, 0) AS QuantityBalanceInventoryReceived,
		|	ISNULL(RegisterRecordsInventoryReceivedChange.SettlementsAmountChange, 0) + ISNULL(InventoryReceivedBalances.SettlementsAmountBalance, 0) AS SettlementsAmountInventoryReceived,
		|	ISNULL(InventoryReceivedBalances.SettlementsAmountBalance, 0) AS SettlementsAmountBalanceInventoryReceived
		|FROM
		|	RegisterRecordsInventoryReceivedChange AS RegisterRecordsInventoryReceivedChange
		|		LEFT JOIN AccumulationRegister.InventoryReceived.Balance(
		|				&ControlTime,
		|				(Company, ProductsAndServices, Characteristic, Batch, Counterparty, Contract, Order, ReceptionTransmissionType) In
		|					(SELECT
		|						RegisterRecordsInventoryReceivedChange.Company AS Company,
		|						RegisterRecordsInventoryReceivedChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryReceivedChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryReceivedChange.Batch AS Batch,
		|						RegisterRecordsInventoryReceivedChange.Counterparty AS Counterparty,
		|						RegisterRecordsInventoryReceivedChange.Contract AS Contract,
		|						RegisterRecordsInventoryReceivedChange.Order AS Order,
		|						RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType AS ReceptionTransmissionType
		|					FROM
		|						RegisterRecordsInventoryReceivedChange AS RegisterRecordsInventoryReceivedChange)) AS InventoryReceivedBalances
		|		ON RegisterRecordsInventoryReceivedChange.Company = InventoryReceivedBalances.Company
		|			AND RegisterRecordsInventoryReceivedChange.ProductsAndServices = InventoryReceivedBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryReceivedChange.Characteristic = InventoryReceivedBalances.Characteristic
		|			AND RegisterRecordsInventoryReceivedChange.Batch = InventoryReceivedBalances.Batch
		|			AND RegisterRecordsInventoryReceivedChange.Counterparty = InventoryReceivedBalances.Counterparty
		|			AND RegisterRecordsInventoryReceivedChange.Contract = InventoryReceivedBalances.Contract
		|			AND RegisterRecordsInventoryReceivedChange.Order = InventoryReceivedBalances.Order
		|			AND RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType = InventoryReceivedBalances.ReceptionTransmissionType
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
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty() Then
			DocumentObjectProcessingReport = DocumentRefReportAboutRecycling.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectProcessingReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectProcessingReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryReceivedRegisterErrors(DocumentObjectProcessingReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			SmallBusinessServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectProcessingReport, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure // RunControl()

#Region PrintInterface

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ProcessingReport";

	FirstDocument = True;
	
	For Each CurrentDocument IN ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "Act" Then
		
			Query = New Query();
			Query.SetParameter("ObjectsArray", ObjectsArray);
			Query.Text = 
			"SELECT
			|	ProcessingReport.Ref AS Ref,
			|	ProcessingReport.Number AS Number,
			|	ProcessingReport.Date AS DocumentDate,
			|	ProcessingReport.Company AS Company,
			|	ProcessingReport.Counterparty AS Counterparty,
			|	ProcessingReport.AmountIncludesVAT AS AmountIncludesVAT,
			|	ProcessingReport.DocumentCurrency AS DocumentCurrency,
			|	ProcessingReport.Company.Prefix AS Prefix,
			|	ProcessingReport.Released,
			|	ProcessingReport.Products.(
			|		LineNumber AS LineNumber,
			|		CASE
			|			WHEN (CAST(ProcessingReport.Products.ProductsAndServices.DescriptionFull AS String(1000))) = """"
			|				THEN ProcessingReport.Products.ProductsAndServices.Description
			|			ELSE CAST(ProcessingReport.Products.ProductsAndServices.DescriptionFull AS String(1000))
			|		END AS Product,
			|		ProductsAndServices.SKU AS SKU,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Price AS Price,
			|		Amount AS Amount,
			|		VATAmount AS VATAmount,
			|		Total AS Total,
			|		Characteristic,
			|		Content,
			|		DiscountMarkupPercent,
			|		CASE
			|			WHEN ProcessingReport.Products.DiscountMarkupPercent <> 0
			|					OR ProcessingReport.Products.AutomaticDiscountAmount <> 0
			|				THEN 1
			|			ELSE 0
			|		END AS IsDiscount,
			|		AutomaticDiscountAmount
			|	)
			|FROM
			|	Document.ProcessingReport AS ProcessingReport
			|WHERE
			|	ProcessingReport.Ref IN(&ObjectsArray)
			|
			|ORDER BY
			|	Ref,
			|	LineNumber";
			
			Header = Query.Execute().Select();
			
			FirstDocument = True;
			
			While Header.Next() Do
				
				If Not FirstDocument Then
					SpreadsheetDocument.PutHorizontalPageBreak();
				EndIf;
				FirstDocument = False;
				
				FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
				
				StringSelectionProducts = Header.Products.Select();
				
				SpreadsheetDocument.PrintParametersName = "PRINTING_PARAMETERS_ReportRecycling_Act";
				
				Template = PrintManagement.PrintedFormsTemplate("Document.ProcessingReport.PF_MXL_Act");
				
				InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
				InfoAboutCounterparty = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
				
				If Header.DocumentDate < Date('20110101') Then
					DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
				Else
					DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
				EndIf;		
				
				TemplateArea = Template.GetArea("Title");
				TemplateArea.Parameters.HeaderText = "Act No. "
				                                        + DocumentNumber
				                                        + " from "
				                                        + Format(Header.DocumentDate, "DLF=DD");
				
				SpreadsheetDocument.Put(TemplateArea);
				
				TemplateArea = Template.GetArea("Vendor");
				TemplateArea.Parameters.VendorPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,KPP,LegalAddress,PhoneNumbers,");
				SpreadsheetDocument.Put(TemplateArea);
				
				TemplateArea = Template.GetArea("Customer");
				TemplateArea.Parameters.RecipientPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr,TIN,KPP,LegalAddress,PhoneNumbers,");
				SpreadsheetDocument.Put(TemplateArea);
				
				AreDiscounts = Header.Products.Unload().Total("IsDiscount") <> 0;
		
				If AreDiscounts Then
					
					TemplateArea = Template.GetArea("TableWithDiscountHeader");
					SpreadsheetDocument.Put(TemplateArea);
					TemplateArea = Template.GetArea("RowWithDiscount");
					
				Else
					
					TemplateArea = Template.GetArea("TableHeader");
					SpreadsheetDocument.Put(TemplateArea);
					TemplateArea = Template.GetArea("String");
					
				EndIf;
				
				Amount		= 0;
				VATAmount	= 0;
				Total		= 0;
				Quantity	= 0;
				
				While StringSelectionProducts.Next() Do
					TemplateArea.Parameters.Fill(StringSelectionProducts);
					
					If ValueIsFilled(StringSelectionProducts.Content) Then
						TemplateArea.Parameters.Product = StringSelectionProducts.Content;
					Else
						TemplateArea.Parameters.Product = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(StringSelectionProducts.Product, 
																			StringSelectionProducts.Characteristic, StringSelectionProducts.SKU);
					EndIf;
					
					If AreDiscounts Then
						If StringSelectionProducts.DiscountMarkupPercent = 100 Then
							Discount = StringSelectionProducts.Price * StringSelectionProducts.Quantity;
							TemplateArea.Parameters.Discount         = Discount;
							TemplateArea.Parameters.AmountWithoutDiscount = Discount;
						ElsIf StringSelectionProducts.DiscountMarkupPercent = 0 AND StringSelectionProducts.AutomaticDiscountAmount = 0 Then
							TemplateArea.Parameters.Discount         = 0;
							TemplateArea.Parameters.AmountWithoutDiscount = StringSelectionProducts.Amount;
						Else
							Discount = StringSelectionProducts.Quantity * StringSelectionProducts.Price - StringSelectionProducts.Amount; // AutomaticDiscounts
							TemplateArea.Parameters.Discount         = Discount;
							TemplateArea.Parameters.AmountWithoutDiscount = StringSelectionProducts.Amount + Discount;
						EndIf;
					EndIf;
					
					SpreadsheetDocument.Put(TemplateArea);
					
					Amount		= Amount 	+ StringSelectionProducts.Amount;
					VATAmount	= VATAmount	+ StringSelectionProducts.VATAmount;
					Total		= Total		+ StringSelectionProducts.Total;
					Quantity	= Quantity+ 1;
					
				EndDo;
				
				TemplateArea = Template.GetArea("Total");
				TemplateArea.Parameters.Total = SmallBusinessServer.AmountsFormat(Amount);
				SpreadsheetDocument.Put(TemplateArea);
				
				TemplateArea = Template.GetArea("TotalVAT");
				If VATAmount = 0 Then
					TemplateArea.Parameters.VAT = "Without tax (VAT)";
					TemplateArea.Parameters.TotalVAT = "-";
				Else
					TemplateArea.Parameters.VAT = ?(Header.AmountIncludesVAT, "Including VAT:", "VAT Amount:");
					TemplateArea.Parameters.TotalVAT = SmallBusinessServer.AmountsFormat(VATAmount);
				EndIf; 
				SpreadsheetDocument.Put(TemplateArea);
				
				TemplateArea = Template.GetArea("AmountInWords");
				AmountToBeWrittenInWords = Total;
				TemplateArea.Parameters.TotalRow = "Total titles "
				                                        + String(Quantity)
				                                        + ", in the amount of "
				                                        + SmallBusinessServer.AmountsFormat(AmountToBeWrittenInWords, Header.DocumentCurrency);
				
				TemplateArea.Parameters.AmountInWords = WorkWithCurrencyRates.GenerateAmountInWords(AmountToBeWrittenInWords, Header.DocumentCurrency);
				
				SpreadsheetDocument.Put(TemplateArea);
				
				TemplateArea = Template.GetArea("Signatures");
				
				ParameterValues = New Structure;
				
				SNPReleaseMade = "";
				SmallBusinessServer.SurnameInitialsByName(SNPReleaseMade, String(Header.Released));
				ParameterValues.Insert("Released", SNPReleaseMade);
				
				TemplateArea.Parameters.Fill(ParameterValues);
				SpreadsheetDocument.Put(TemplateArea);
				
				PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
				
			EndDo;
			
		ElsIf TemplateName = "TORG12" Then
			
			Query = New Query;
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text =
			"SELECT
			|	ProcessingReport.Date AS DocumentDate,
			|	ProcessingReport.Number AS Number,
			|	ProcessingReport.Company AS Heads,
			|	ProcessingReport.Company AS Company,
			|	ProcessingReport.BankAccount AS BankAccountOfTheCompany,
			|	ProcessingReport.Counterparty AS Counterparty,
			|	ProcessingReport.Company AS Vendor,
			|	ProcessingReport.Counterparty AS Consignee,
			|	ProcessingReport.Company AS Consignor,
			|	ProcessingReport.Counterparty AS Payer,
			|	ProcessingReport.CounterpartyBankAcc AS CounterpartyBankAcc,
			|	ProcessingReport.StampBase AS Basis,
			|	ProcessingReport.DocumentCurrency,
			|	ProcessingReport.AmountIncludesVAT,
			|	ProcessingReport.IncludeVATInPrice,
			|	ProcessingReport.Company.Prefix AS Prefix,
			|	ProcessingReport.ExchangeRate,
			|	ProcessingReport.Multiplicity,
			|	ProcessingReport.Head,
			|	ProcessingReport.HeadPosition,
			|	ProcessingReport.ChiefAccountant,
			|	ProcessingReport.Released,
			|	ProcessingReport.ReleasedPosition,
			|	ProcessingReport.PowerOfAttorneyIssued,
			|	ProcessingReport.PowerOfAttorneyDate,
			|	ProcessingReport.PowerAttorneyPerson,
			|	ProcessingReport.PowerOfAttorneyNumber

			|FROM
			|	Document.ProcessingReport AS ProcessingReport
			|WHERE
			|	ProcessingReport.Ref = &CurrentDocument";
			Header = Query.Execute().Select();
			
			Header.Next();
			
			UseConversion = (NOT Header.DocumentCurrency = Constants.NationalCurrency.Get());
			
			Query = New Query;
			Query.SetParameter("CurrentDocument", CurrentDocument);
			
			Query.Text =
			"SELECT
			|	NestedSelect.ProductsAndServices AS ProductsAndServices,
			|	NestedSelect.InventoryItem AS InventoryItem,
			|	NestedSelect.Characteristic,
			|	NestedSelect.ProductsAndServices.Code AS InventoryItemCode,
			|	NestedSelect.ProductsAndServices.SKU AS SKU,
			|	NestedSelect.ProductsAndServices.MeasurementUnit.Description AS BaseUnitDescription,
			|	NestedSelect.ProductsAndServices.MeasurementUnit.Code AS BaseUnitCodeRCUM,
			|	NestedSelect.MeasurementUnit AS PackagingKind,
			|	0 AS QuantityInOnePlace,
			|	NestedSelect.VATRate AS VATRate,
			|	ISNULL(&Price_Parameter, 0) AS Price,
			|	NestedSelect.Quantity AS Quantity,
			|	0 AS PlacesQuantity,
			|	ISNULL(&Amount_Parameter, 0) AS Amount,
			|	ISNULL(&VATAmount_Parameter, 0) AS VATAmount,
			|	ISNULL(&Total_Parameter, 0) AS Total,
			|	NestedSelect.LineNumber AS LineNumber,
			|	1 AS ID,
			|	NestedSelect.SKU AS SKU1,
			|	NestedSelect.Content AS Content
			|FROM
			|	(SELECT
			|		ProcessingReportProducts.ProductsAndServices AS ProductsAndServices,
			|		CASE
			|			WHEN (CAST(ProcessingReportProducts.ProductsAndServices.DescriptionFull AS String(1000))) = """"
			|				THEN ProcessingReportProducts.ProductsAndServices.Description
			|			ELSE CAST(ProcessingReportProducts.ProductsAndServices.DescriptionFull AS String(1000))
			|		END AS InventoryItem,
			|		ProcessingReportProducts.MeasurementUnit AS MeasurementUnit,
			|		ProcessingReportProducts.VATRate AS VATRate,
			|		ProcessingReportProducts.Price AS Price,
			|		SUM(ProcessingReportProducts.Quantity) AS Quantity,
			|		SUM(ProcessingReportProducts.Amount) AS Amount,
			|		SUM(ProcessingReportProducts.VATAmount) AS VATAmount,
			|		SUM(ProcessingReportProducts.Total) AS Total,
			|		MIN(ProcessingReportProducts.LineNumber) AS LineNumber,
			|		ProcessingReportProducts.Characteristic AS Characteristic,
			|		ProcessingReportProducts.ProductsAndServices.SKU AS SKU,
			|		CAST(ProcessingReportProducts.Content AS String(1000)) AS Content
			|	FROM
			|		Document.ProcessingReport.Products AS ProcessingReportProducts
			|	WHERE
			|		ProcessingReportProducts.Ref = &CurrentDocument
			|	
			|	GROUP BY
			|		ProcessingReportProducts.ProductsAndServices,
			|		CASE
			|			WHEN (CAST(ProcessingReportProducts.ProductsAndServices.DescriptionFull AS String(1000))) = """"
			|				THEN ProcessingReportProducts.ProductsAndServices.Description
			|			ELSE CAST(ProcessingReportProducts.ProductsAndServices.DescriptionFull AS String(1000))
			|		END,
			|		ProcessingReportProducts.MeasurementUnit,
			|		ProcessingReportProducts.VATRate,
			|		ProcessingReportProducts.Price,
			|		ProcessingReportProducts.Characteristic,
			|		ProcessingReportProducts.ProductsAndServices.SKU,
			|		CAST(ProcessingReportProducts.Content AS String(1000))
			|	
			|	UNION ALL
			|	
			|	SELECT
			|		ProcessingReportDisposals.ProductsAndServices,
			|		CASE
			|			WHEN (CAST(ProcessingReportDisposals.ProductsAndServices.DescriptionFull AS String(1000))) = """"
			|				THEN ProcessingReportDisposals.ProductsAndServices.Description
			|			ELSE CAST(ProcessingReportDisposals.ProductsAndServices.DescriptionFull AS String(1000))
			|		END,
			|		ProcessingReportDisposals.MeasurementUnit,
			|		NULL,
			|		NULL,
			|		SUM(ProcessingReportDisposals.Quantity),
			|		NULL,
			|		NULL,
			|		NULL,
			|		MIN(ProcessingReportDisposals.LineNumber),
			|		ProcessingReportDisposals.Characteristic,
			|		ProcessingReportDisposals.ProductsAndServices.SKU,
			|		NULL
			|	FROM
			|		Document.ProcessingReport.Disposals AS ProcessingReportDisposals
			|	WHERE
			|		ProcessingReportDisposals.Ref = &CurrentDocument
			|	
			|	GROUP BY
			|		ProcessingReportDisposals.ProductsAndServices,
			|		CASE
			|			WHEN (CAST(ProcessingReportDisposals.ProductsAndServices.DescriptionFull AS String(1000))) = """"
			|				THEN ProcessingReportDisposals.ProductsAndServices.Description
			|			ELSE CAST(ProcessingReportDisposals.ProductsAndServices.DescriptionFull AS String(1000))
			|		END,
			|		ProcessingReportDisposals.MeasurementUnit,
			|		ProcessingReportDisposals.Characteristic,
			|		ProcessingReportDisposals.ProductsAndServices.SKU) AS NestedSelect
			|
			|ORDER BY
			|	ID,
			|	LineNumber";
			
			If UseConversion Then
				
				Query.Text = StrReplace(Query.Text, "&Price_Parameter", 		"CAST(NestedSelect.Price * &ExchangeRate / &Multiplicity AS Number(15,2))");
				Query.Text = StrReplace(Query.Text, "&Amount_Parameter", 	"CAST(NestedSelect.Amount * &ExchangeRate / &Multiplicity AS Number(15,2))");
				Query.Text = StrReplace(Query.Text, "&VATAmount_Parameter", 	"CAST(NestedSelect.VATAmount * &ExchangeRate / &Multiplicity AS Number(15,2))");
				Query.Text = StrReplace(Query.Text, "&Total_Parameter", 	"CAST(NestedSelect.Total * &ExchangeRate / &Multiplicity AS Number(15,2))");
				
				Query.SetParameter("ExchangeRate",		Header.ExchangeRate);
				Query.SetParameter("Multiplicity",	Header.Multiplicity);
				
			Else
				
				Query.Text = StrReplace(Query.Text, "&Price_Parameter", 		"NestedSelect.Price");
				Query.Text = StrReplace(Query.Text, "&Amount_Parameter", 	"NestedSelect.Amount");
				Query.Text = StrReplace(Query.Text, "&VATAmount_Parameter", 	"NestedSelect.VATAmount");
				Query.Text = StrReplace(Query.Text, "&Total_Parameter", 	"NestedSelect.Total");
				
			EndIf;
			
			QueryInventory = Query.Execute().Unload();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_ProcessingReport_TRAD12";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.ProcessingReport.PF_MXL_TORG12");
			
			TemplateAreaHeader            = Template.GetArea("Header");
			TemplateAreaTableHeader = Template.GetArea("TabTitle");
			TemplateAreaRow           = Template.GetArea("String");
			TemplateAreaTotalByPage  = Template.GetArea("TotalByPage");
			TemplateAreaTotal            = Template.GetArea("Total");
			TemplateAreaFooter           = Template.GetArea("Footer");
			
			// Displaying general header attributes
			
			InfoAboutVendor       = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company,      Header.DocumentDate, , Header.BankAccountOfTheCompany);
			InfoAboutShipper = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Consignor, Header.DocumentDate, ,);
			InfoAboutCustomer       = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Counterparty,       Header.DocumentDate, , Header.CounterpartyBankAcc);
			InfoAboutConsignee  = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Consignee,  Header.DocumentDate, ,);

			TemplateAreaHeader.Parameters.Fill(Header);
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateAreaHeader.Parameters.DocumentNumber = DocumentNumber;
			TemplateAreaHeader.Parameters.DocumentDate  = Header.DocumentDate;
			TemplateAreaHeader.Parameters.CompanyPresentation     = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "FullDescr,TIN,ActualAddress,PhoneNumbers,Fax,AccountNo,Bank,BIN,CorrAccount");
			TemplateAreaHeader.Parameters.PresentationOfConsignee = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutConsignee,"FullDescr,TIN,ActualAddress,PhoneNumbers,AccountNo,Bank,BIN,CorrAccount");
			TemplateAreaHeader.Parameters.VendorPresentation      = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor);
			TemplateAreaHeader.Parameters.PayerPresentation     = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer);

			// Displaying all sorts of codes
			TemplateAreaHeader.Parameters.CompanyByOKPO     = InfoAboutShipper.CodeByOKPO;
			TemplateAreaHeader.Parameters.ActivityKindByOKDP = "";
			TemplateAreaHeader.Parameters.ConsigneeByARBOC = InfoAboutConsignee.CodeByOKPO;
			TemplateAreaHeader.Parameters.VendorByOKPO  = InfoAboutVendor.CodeByOKPO;
			TemplateAreaHeader.Parameters.PayerByRCEO = InfoAboutCustomer.CodeByOKPO;
			TemplateAreaHeader.Parameters.BasisNumber   = "";
			TemplateAreaHeader.Parameters.BasisDate    = "";
			TemplateAreaHeader.Parameters.WayBillNumber = "";
			TemplateAreaHeader.Parameters.WaybillDate  = "";

			SpreadsheetDocument.Put(TemplateAreaHeader);

			// Initializing page counter
			PageNumber = 1;

			// Initialization of totals for the page
			TotalPlacesOnPage       = 0;
			TotalQuantityOnPage = 0;
			TotalOnPage      = 0;
			TotalVATOnPage        = 0;
			TotalOfWithVATOnPage  = 0;

			// Initialization of totals for the document
			TotalPlaces       = 0;
			TotalQuantity = 0;
			TotalWithVAT  = 0;
			Total      = 0;
			TotalVAT        = 0;
			
			// Initializing line counter
			LineNumber     = 0;
			LineCount = QueryInventory.Count();
			
			// Displaying multiline header parts
			TemplateAreaTableHeader.Parameters.PageNumber = "Page " + PageNumber; 
			SpreadsheetDocument.Put(TemplateAreaTableHeader);
			
			// Displaying multiline part of the document
			For Each LinesSelection IN QueryInventory Do
				
				LineNumber = LineNumber + 1;
				
				TemplateAreaRow.Parameters.Fill(LinesSelection);
				
				TemplateAreaRow.Parameters.Number = LineNumber;
				
				If Not ValueIsFilled(LinesSelection.PlacesQuantity) Then
					TemplateAreaRow.Parameters.PackagingKind			= "";
					TemplateAreaRow.Parameters.QuantityInOnePlace	= "";
				EndIf;
				
				If ValueIsFilled(LinesSelection.Content) Then
					
					TemplateAreaRow.Parameters.InventoryItemDescription = LinesSelection.Content;
					
				Else
					
					TemplateAreaRow.Parameters.InventoryItemDescription = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(
						LinesSelection.InventoryItem, 
						LinesSelection.Characteristic, 
						LinesSelection.SKU);
					
				EndIf;
				
				PlacesQuantity	= LinesSelection.PlacesQuantity;
				Quantity		= LinesSelection.Quantity;
				SumWithVAT 		= LinesSelection.Total;
				VATAmount		= LinesSelection.VATAmount;
				AmountWithoutVAT		= LinesSelection.Amount - ?(Header.AmountIncludesVAT, LinesSelection.VATAmount, 0);
				
				TemplateAreaRow.Parameters.SumWithVAT   = SumWithVAT;
				TemplateAreaRow.Parameters.VATAmount    = VATAmount;
				TemplateAreaRow.Parameters.VATRate   = LinesSelection.VATRate;
				TemplateAreaRow.Parameters.AmountWithoutVAT = AmountWithoutVAT;
				TemplateAreaRow.Parameters.Price        = AmountWithoutVAT / ?(Quantity = 0, 1, Quantity);
				
				// Check output
				RowWithFooter = New Array;
				If LineNumber = 1 Then
					RowWithFooter.Add(TemplateAreaTableHeader); // if the first string, then should
				EndIf;                                                   // fit title
				RowWithFooter.Add(TemplateAreaRow);
				RowWithFooter.Add(TemplateAreaTotalByPage);
				If LineNumber = LineCount Then           // if the last string, should
					RowWithFooter.Add(TemplateAreaTotal);  // fit and document footer
					RowWithFooter.Add(TemplateAreaFooter);
				EndIf;

				If LineNumber <> 1 AND Not SpreadsheetDocument.CheckPut(RowWithFooter) Then
					
					// Displaying results for the page
					TemplateAreaTotalByPage.Parameters.ResultPagePlaces       = TotalPlacesOnPage;
					TemplateAreaTotalByPage.Parameters.TotalPageCount = TotalQuantityOnPage;
					TemplateAreaTotalByPage.Parameters.TotalAmountPerPage      = TotalOnPage;
					TemplateAreaTotalByPage.Parameters.VATByPageTotal        = TotalVATOnPage;
					TemplateAreaTotalByPage.Parameters.TotalAmountWithVATByPage  = TotalOfWithVATOnPage;
					SpreadsheetDocument.Put(TemplateAreaTotalByPage);
					
					SpreadsheetDocument.PutHorizontalPageBreak();
					
					// Clear results for the page
					TotalPlacesOnPage       = 0;
					TotalQuantityOnPage = 0;
					TotalOnPage      = 0;
					TotalVATOnPage        = 0;
					TotalOfWithVATOnPage  = 0;
					
					// Display table header
					PageNumber = PageNumber + 1;
					TemplateAreaTableHeader.Parameters.PageNumber = "Page " + PageNumber; 
					SpreadsheetDocument.Put(TemplateAreaTableHeader);
					
				EndIf;
					
				SpreadsheetDocument.Put(TemplateAreaRow);

				// Increase total by page
				TotalPlacesOnPage       = TotalPlacesOnPage       + PlacesQuantity;
				TotalQuantityOnPage = TotalQuantityOnPage + Quantity;
				TotalOnPage      = TotalOnPage      + AmountWithoutVAT;
				TotalVATOnPage        = TotalVATOnPage        + VATAmount;
				TotalOfWithVATOnPage  = TotalOfWithVATOnPage  + SumWithVAT;

				// Increase total by document
				TotalPlaces       = TotalPlaces       + PlacesQuantity;
				TotalQuantity = TotalQuantity + Quantity;
				Total      = Total      + AmountWithoutVAT;
				TotalVAT        = TotalVAT        + VATAmount;
				TotalWithVAT  = TotalWithVAT  + SumWithVAT;

			EndDo;

			// Displaying results for the page
			TemplateAreaTotalByPage.Parameters.ResultPagePlaces       = TotalPlacesOnPage;
			TemplateAreaTotalByPage.Parameters.TotalPageCount = TotalQuantityOnPage;
			TemplateAreaTotalByPage.Parameters.TotalAmountPerPage      = TotalOnPage;
			TemplateAreaTotalByPage.Parameters.VATByPageTotal        = TotalVATOnPage;
			TemplateAreaTotalByPage.Parameters.TotalAmountWithVATByPage  = TotalOfWithVATOnPage;

			SpreadsheetDocument.Put(TemplateAreaTotalByPage);
			
			// Display totals on the full document
			TemplateAreaTotal.Parameters.TotalPlaces       = TotalPlaces;
			TemplateAreaTotal.Parameters.TotalQuantity = TotalQuantity;
			TemplateAreaTotal.Parameters.TotalAmount      = Total;
			TemplateAreaTotal.Parameters.TotalVAT        = TotalVAT;
			TemplateAreaTotal.Parameters.TotalAmountWithVAT  = TotalWithVAT;

			SpreadsheetDocument.Put(TemplateAreaTotal);

			// Display the footer of the document
			ParameterValues = New Structure;
			
			ParameterValues.Insert("PowerOfAttorneyNumber", Header.PowerOfAttorneyNumber);
			ParameterValues.Insert("PowerOfAttorneyDate", Header.PowerOfAttorneyDate);
			ParameterValues.Insert("PowerOfAttorneyIssued", Header.PowerOfAttorneyIssued);
			ParameterValues.Insert("PowerOfAttorneyThroughWhom", Header.PowerAttorneyPerson);
			
			HeadDescriptionFull = "";
			SmallBusinessServer.SurnameInitialsByName(HeadDescriptionFull, String(Header.Head));
			ParameterValues.Insert("HeadDescriptionFull",		HeadDescriptionFull);
			ParameterValues.Insert("HeadPost", Header.HeadPosition);
			
			ChiefAccountantNameAndSurname = "";
			SmallBusinessServer.SurnameInitialsByName(ChiefAccountantNameAndSurname, String(Header.ChiefAccountant));
			ParameterValues.Insert("NameAndSurnameOfChiefAccountant",	ChiefAccountantNameAndSurname);
			
			WarehouseManSNP = "";
			SmallBusinessServer.SurnameInitialsByName(WarehouseManSNP, String(Header.Released));
			ParameterValues.Insert("WarehouseManSNP",		WarehouseManSNP);
			ParameterValues.Insert("WarehousemanPosition",	Header.ReleasedPosition);
			
			ParameterValues.Insert("RecordsSequenceNumbersQuantityInWords", NumberInWords(LineCount, ,",,,,,,,,0"));
			ParameterValues.Insert("TotalPlacesInWords", ?(TotalPlaces = 0, "", NumberInWords(TotalPlaces, ,",,,From,,,,,0")));
			ParameterValues.Insert("AmountInWords", WorkWithCurrencyRates.GenerateAmountInWords(TotalWithVAT, Constants.NationalCurrency.Get()));
			
			FullDocumentDate = Format(Header.DocumentDate, "DF=""dd MMMM yyyy """"year""""""");
			StringLength         = StrLen(FullDocumentDate);
			FirstSeparator   = Find(FullDocumentDate," ");
			SecondSeparator   = Find(Right(FullDocumentDate,StringLength - FirstSeparator), " ") + FirstSeparator;
			
			ParameterValues.Insert("DocumentDateDay", """" + Left(FullDocumentDate, FirstSeparator - 1) + """");
			ParameterValues.Insert("DocumentDateMonth", Mid(FullDocumentDate, FirstSeparator + 1, SecondSeparator - FirstSeparator - 1));
			ParameterValues.Insert("DocumentDateYear", Right(FullDocumentDate, StringLength - SecondSeparator));
			
			TemplateAreaFooter.Parameters.Fill(ParameterValues);
			SpreadsheetDocument.Put(TemplateAreaFooter);
			
			SpreadsheetDocument.PageOrientation = PageOrientation.Landscape;
			
		ElsIf TemplateName = "MerchandiseFillingForm" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text = 
			"SELECT
			|	ProcessingReport.Date AS DocumentDate,
			|	ProcessingReport.StructuralUnit AS WarehousePresentation,
			|	ProcessingReport.Cell AS CellPresentation,
			|	ProcessingReport.Number,
			|	ProcessingReport.Company.Prefix AS Prefix,
			|	ProcessingReport.Products.(
			|		LineNumber AS LineNumber,
			|		ProductsAndServices.Warehouse AS Warehouse,
			|		ProductsAndServices.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(ProcessingReport.Products.ProductsAndServices.DescriptionFull AS String(100))) = """"
			|				THEN ProcessingReport.Products.ProductsAndServices.Description
			|			ELSE ProcessingReport.Products.ProductsAndServices.DescriptionFull
			|		END AS InventoryItem,
			|		ProductsAndServices.SKU AS SKU,
			|		ProductsAndServices.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType
			|	)
			|FROM
			|	Document.ProcessingReport AS ProcessingReport
			|WHERE
			|	ProcessingReport.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Products.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_ReportAboutrocessing_FormOfProductContent";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.ProcessingReport.PF_MXL_MerchandiseFillingForm");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = "Processing report # "
													+ DocumentNumber
													+ " from "
													+ Format(Header.DocumentDate, "DLF=DD");
													
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.FunctionalOptionAccountingByCells.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime = "Date and time of printing: "
												 	+ CurrentDate()
													+ ". User: "
													+ Users.CurrentUser();
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do

				If Not LinesSelectionInventory.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				TemplateArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
																		LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU);
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction // PrintForm()

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames   - String    - Names of layouts separated  by commas 
//   ObjectsArray    - Array     - Array of refs to objects that need to be printed
//   PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   OutputParameters     - Structure   - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Act") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "Act", "Processing Service Report", PrintForm(ObjectsArray, PrintObjects, "Act"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "TORG12") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "TORG12", "Customer invoice", PrintForm(ObjectsArray, PrintObjects, "TORG12"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "BoL") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "BoL", "BILL OF LADING", DataProcessors.PrintBOL.PrintForm(ObjectsArray, PrintObjects, PrintParameters));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "MerchandiseFillingForm") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "MerchandiseFillingForm", "Merchandise filling form", PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingForm"));
		
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
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "Act,TORG12,BoL";
	PrintCommand.Presentation = NStr("en = 'Custom kit of documents'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "Act";
	PrintCommand.Presentation = NStr("en = 'Services acceptance certificate'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 4;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "TORG12";
	PrintCommand.Presentation = NStr("en = 'TORG12'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 7;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "BoL";
	PrintCommand.Presentation = NStr("en = '1-T (Shipping document)'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 10;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.Handler = "SmallBusinessClient.PrintWayBill";
	PrintCommand.ID = "CN";
	PrintCommand.Presentation = NStr("en = 'Application #4 (consignment note)'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 14;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingForm";
	PrintCommand.Presentation = NStr("en = 'Merchandise filling form'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 17;
	
EndProcedure

#EndRegion

#EndIf