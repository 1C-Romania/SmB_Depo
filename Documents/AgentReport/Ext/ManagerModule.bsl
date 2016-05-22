#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// AccountingRecords

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefAgentReport, StructureAdditionalProperties)
	
		
	//( elmi #11
    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
	|	Sum(TemporaryTable.VATAmount) AS VATAmount ,
	|	Sum(TemporaryTable.BrokerageVATAmount) AS BrokerageVATAmount, 
	|	Sum(TemporaryTable.VATAmountCur) AS VATAmountCur ,
	|	Sum(TemporaryTable.BrokerageVATAmountCur) AS BrokerageVATAmountCur 
	|FROM
	|	TemporaryTableInventory AS TemporaryTable
	|GROUP BY
	|TemporaryTable.Period,
	|TemporaryTable.Company	";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	VATAmount = 0;
	VATAmountCur = 0;
    BrokerageVATAmount=0;
	BrokerageVATAmountCur = 0;
	
	While Selection.Next() Do  
		  VATAmount    = Selection.VATAmount;
	      VATAmountCur = Selection.VATAmountCur;
		  BrokerageVATAmount    = Selection.BrokerageVATAmount;
	      BrokerageVATAmountCur = Selection.BrokerageVATAmountCur;
	EndDo;
    //) elmi
	
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
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
	|			THEN CASE
	|					WHEN TableManagerial.KeepBackComissionFee
	//( elmi #11
	//|						THEN TableManagerial.AmountCur - TableManagerial.BrokerageAmountCur
	|						THEN TableManagerial.AmountCur - TableManagerial.VATAmountCur - (TableManagerial.BrokerageAmountCur - TableManagerial.BrokerageVATAmountCur)  
	//|					ELSE TableManagerial.AmountCur
	|					ELSE TableManagerial.AmountCur  - TableManagerial.VATAmountCur 
	//) elmi
	|				END
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableManagerial.AccountStatementSales AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN TableManagerial.KeepBackComissionFee
	//( elmi #11
	//|			THEN TableManagerial.Amount - TableManagerial.BrokerageAmount
	|			THEN TableManagerial.Amount - TableManagerial.VATAmount - (TableManagerial.BrokerageAmount - TableManagerial.BrokerageVATAmount)  
	//|		ELSE TableManagerial.Amount
	|		ELSE TableManagerial.Amount - TableManagerial.VATAmount 
	//) elmi
	|	END AS Amount,
	|	&IncomeReflection AS Content
	|FROM
	|	TemporaryTableInventory AS TableManagerial
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
	//( elmi #11
	|
	|UNION ALL
	|
	|SELECT
	|	4 AS Order,
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
	|			THEN CASE
	|					WHEN TableManagerial.KeepBackComissionFee
	|						THEN &VATAmountCur -  &BrokerageVATAmountCur
	|					ELSE &VATAmountCur
	|				END
	|		ELSE 0
	|	END AS AmountCurDr,
	|	&TextVAT,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN TableManagerial.KeepBackComissionFee
	|						THEN &VATAmount -  &BrokerageVATAmount
	|					ELSE &VATAmount
    |	END AS Amount,
	|	&VAT AS Content
	|FROM
	|	TemporaryTableInventory AS TableManagerial
	|		WHERE   &VATAmountCur > 0
	//) elmi
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference'"));
	Query.SetParameter("SetOffAdvancePayment", NStr("en = 'Setoff of advance payment'"));
	Query.SetParameter("IncomeReflection", NStr("en = 'Sales revenue'"));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	//( elmi #11
	Query.SetParameter("VAT", NStr("en=' VAT '"));
	Query.SetParameter("TextVAT",  ChartsOfAccounts.Managerial.Taxes);
	Query.SetParameter("VATAmount", VATAmount);
	Query.SetParameter("VATAmountCur", VATAmountCur);
	Query.SetParameter("BrokerageVATAmount", BrokerageVATAmount);
	Query.SetParameter("BrokerageVATAmountCur", BrokerageVATAmountCur);
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
Procedure GenerateTableInventory(DocumentRefAgentReport, StructureAdditionalProperties)
	
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
	|	TableInventory.KeepBackComissionFee AS KeepBackComissionFee,
	|	TableInventory.VATRate AS VATRate,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.VATAmount) AS VATAmount,
	|	SUM(TableInventory.Amount) AS Amount,
	|	SUM(TableInventory.BrokerageAmount) AS BrokerageAmount,
	|	FALSE AS FixedCost,
	|	TableInventory.GLAccountCost AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	&AgentReport AS Content,
	|	&AgentReport AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableInventory AS TableInventory
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
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder,
	|	TableInventory.VATRate,
	|	TableInventory.KeepBackComissionFee,
	|	TableInventory.Responsible,
	|	TableInventory.Document,
	|	TableInventory.DivisionSales,
	|	TableInventory.CustomerOrder,
	|	TableInventory.GLAccountCost,
	|	TableInventory.GLAccount";
	
	Query.SetParameter("AgentReport", NStr("en = 'Agent report'"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
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
	|	TemporaryTableInventory AS TableInventory
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
	
	For Each ColumnQueryResult in QueryResult.Columns Do
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
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
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
	
	Query.SetParameter("Ref", DocumentRefAgentReport);
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

		StructureForSearch.Insert("CustomerOrder", RowTableInventory.CustomerOrder);
		
		QuantityWanted = RowTableInventory.Quantity;
		
		If QuantityWanted > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityWanted Then
				
				AmountToBeWrittenOff = Round(AmountBalance * QuantityWanted / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityWanted;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityWanted Then
				
				AmountToBeWrittenOff = AmountBalance;
				
				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Add the row for the order.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityWanted;
									
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Generate postings.
				RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerial, RowTableInventory);
				RowTableManagerial.Amount = AmountToBeWrittenOff;
				
				// Move the cost of sales.
				StringTableSale = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
				FillPropertyValues(StringTableSale, RowTableInventory);
				
				StringTableSale.Quantity = 0;
				StringTableSale.Amount = 0;
				StringTableSale.VATAmount = 0;
				StringTableSale.Cost = AmountToBeWrittenOff;
				
				If RowTableInventory.KeepBackComissionFee Then
					
					// It is necessary to increase the sales cost by the amount of fee.
					NewRow	= StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
					FillPropertyValues(NewRow, RowTableInventory);
					
					NewRow.Quantity		= 0;
					NewRow.Amount			= 0;
					NewRow.VATAmount		= 0;
					NewRow.Cost	= RowTableInventory.BrokerageAmount;
					
				EndIf;
				
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
Procedure GenerateTableSales(DocumentRefAgentReport, StructureAdditionalProperties)
	
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
	|	SUM(CASE
	|			WHEN TableSales.KeepBackComissionFee
	|				THEN TableSales.VATAmount - TableSales.BrokerageVATAmount
	|			ELSE TableSales.VATAmount
	|		END) AS VATAmount,
	|	SUM(CASE
	|			WHEN TableSales.KeepBackComissionFee
	|				THEN TableSales.Amount - TableSales.BrokerageAmount
	|			ELSE TableSales.Amount
	|		END) AS Amount,
	|	0 AS Cost
	|FROM
	|	TemporaryTableInventory AS TableSales
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
Procedure GenerateTableInventoryTransferred(DocumentRefAgentReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventoryTransferred.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventoryTransferred.Period AS Period,
	|	TableInventoryTransferred.Company AS Company,
	|	TableInventoryTransferred.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryTransferred.Characteristic AS Characteristic,
	|	TableInventoryTransferred.Counterparty AS Counterparty,
	|	TableInventoryTransferred.Contract AS Contract,
	|	CASE
	|		WHEN TableInventoryTransferred.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN TableInventoryTransferred.CustomerOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TableInventoryTransferred.Batch AS Batch,
	|	TableInventoryTransferred.ReceptionTransmissionType AS ReceptionTransmissionType,
	|	SUM(TableInventoryTransferred.Quantity) AS Quantity,
	//( elmi #11
	//|	SUM(TableInventoryTransferred.SettlementsAmountTakenPassed) AS SettlementsAmount
	|	SUM(TableInventoryTransferred.SettlementsAmountTakenPassed - TableInventoryTransferred.CostVAT) AS SettlementsAmount        
	//) elmi
	|FROM
	|	TemporaryTableInventory AS TableInventoryTransferred
	|
	|GROUP BY
	|	TableInventoryTransferred.Period,
	|	TableInventoryTransferred.Company,
	|	TableInventoryTransferred.ProductsAndServices,
	|	TableInventoryTransferred.Characteristic,
	|	TableInventoryTransferred.Batch,
	|	TableInventoryTransferred.Counterparty,
	|	TableInventoryTransferred.Contract,
	|	CASE
	|		WHEN TableInventoryTransferred.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN TableInventoryTransferred.CustomerOrder
	|		ELSE UNDEFINED
	|	END,
	|	TableInventoryTransferred.ReceptionTransmissionType";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryTransferred", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryTransferred()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefAgentReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	MAX(TableIncomeAndExpenses.LineNumber) AS LineNumber,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.DivisionSales AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessActivitySales AS BusinessActivity,
	|	TableIncomeAndExpenses.CustomerOrder AS CustomerOrder,
	|	TableIncomeAndExpenses.AccountStatementSales AS GLAccount,
	|	&IncomeReflection AS ContentOfAccountingRecord,
	|	SUM(CASE
	|			WHEN TableIncomeAndExpenses.KeepBackComissionFee
	//( elmi #11
	//|				THEN TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.BrokerageAmount
	|				THEN (TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) - (TableIncomeAndExpenses.BrokerageAmount - TableIncomeAndExpenses.BrokerageVATAmount) 
	//|			ELSE TableIncomeAndExpenses.Amount
	|			ELSE TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount    
	|		END) AS AmountIncome,
	|	0 AS AmountExpense,
	|	SUM(CASE
	|			WHEN TableIncomeAndExpenses.KeepBackComissionFee
	//|				THEN TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.BrokerageAmount
	|				THEN (TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.BrokerageAmount) - (TableIncomeAndExpenses.VATAmount - TableIncomeAndExpenses.BrokerageVATAmount)  
	//|			ELSE TableIncomeAndExpenses.Amount
	|			ELSE TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount     
	//) elmi
	|		END) AS Amount
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Period,
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
	|	Order,
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
Procedure GenerateTableCustomerAccounts(DocumentRefAgentReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAgentReport);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerLiability", NStr("en='Appearance of customer liabilities'"));
	Query.SetParameter("AdvanceCredit", NStr("en='Setoff of advance payment'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference'"));
	
	Query.Text =
	"SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
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
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.Amount - DocumentTable.BrokerageAmount
	|			ELSE DocumentTable.Amount
	|		END) AS Amount,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.AmountCur - DocumentTable.BrokerageAmountCur
	|			ELSE DocumentTable.AmountCur
	|		END) AS AmountCur,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.Amount - DocumentTable.BrokerageAmount
	|			ELSE DocumentTable.Amount
	|		END) AS AmountForBalance,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.AmountCur - DocumentTable.BrokerageAmountCur
	|			ELSE DocumentTable.AmountCur
	|		END) AS AmountCurForBalance,
	|	CAST(&AppearenceOfCustomerLiability AS String(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableInventory AS DocumentTable
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
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountCustomerSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	MAX(DocumentTable.LineNumber),
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
	|	MAX(DocumentTable.LineNumber),
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
	|	TemporaryTableAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsReceivable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult in QueryResult.Columns Do
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
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefAgentReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAgentReport);
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
	|	CASE
	|		WHEN DocumentTable.KeepBackComissionFee
	//( elmi #11
	//|			THEN DocumentTable.Amount - DocumentTable.BrokerageAmount
	|			THEN (DocumentTable.Amount - DocumentTable.VATAmount) - (DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount)    
	//|		ELSE DocumentTable.Amount
	|			ELSE DocumentTable.Amount -  DocumentTable.VATAmount      
	//) elmi
	|	END AS AmountIncome
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
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
Procedure GenerateTableIncomeAndExpensesUndistributed(DocumentRefAgentReport, StructureAdditionalProperties)
	
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefAgentReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAgentReport);
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

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefAgentReport, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	AgentReportInventory.LineNumber AS LineNumber,
	|	AgentReportInventory.Ref AS Document,
	|	AgentReportInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	AgentReportInventory.Ref.Counterparty AS Counterparty,
	|	AgentReportInventory.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	AgentReportInventory.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	AgentReportInventory.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	AgentReportInventory.Ref.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	AgentReportInventory.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	AgentReportInventory.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	AgentReportInventory.Ref.Contract AS Contract,
	|	AgentReportInventory.Ref.Counterparty AS StructuralUnit,
	|	AgentReportInventory.Ref.KeepBackComissionFee AS KeepBackComissionFee,
	|	VALUE(Enum.ProductsReceiptTransferTypes.TransferToAgent) AS ReceptionTransmissionType,
	|	AgentReportInventory.Ref.Division AS DivisionSales,
	|	AgentReportInventory.Ref.Responsible AS Responsible,
	|	AgentReportInventory.ProductsAndServices.BusinessActivity AS BusinessActivitySales,
	|	AgentReportInventory.ProductsAndServices.BusinessActivity.GLAccountRevenueFromSales AS AccountStatementSales,
	|	AgentReportInventory.ProductsAndServices.BusinessActivity.GLAccountCostOfSales AS GLAccountCost,
	|	AgentReportInventory.ProductsAndServices.InventoryGLAccount AS GLAccount,
	|	AgentReportInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN AgentReportInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN AgentReportInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(AgentReportInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN AgentReportInventory.Quantity
	|		ELSE AgentReportInventory.Quantity * AgentReportInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	AgentReportInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN AgentReportInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AgentReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AgentReportInventory.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE AgentReportInventory.VATAmount * AgentReportInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AgentReportInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN AgentReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AgentReportInventory.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE AgentReportInventory.VATAmount * AgentReportInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AgentReportInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmountSales,
	|	CAST(CASE
	|			WHEN AgentReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AgentReportInventory.Total * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE AgentReportInventory.Total * AgentReportInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AgentReportInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN AgentReportInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AgentReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AgentReportInventory.VATAmount * RegCurrencyRates.ExchangeRate * AgentReportInventory.Ref.Multiplicity / (AgentReportInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE AgentReportInventory.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN AgentReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AgentReportInventory.Total * RegCurrencyRates.ExchangeRate * AgentReportInventory.Ref.Multiplicity / (AgentReportInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE AgentReportInventory.Total
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(CASE
	|			WHEN AgentReportInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AgentReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AgentReportInventory.TransmissionVATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE AgentReportInventory.TransmissionVATAmount * AgentReportInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AgentReportInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS CostVAT,
	|	CAST(CASE
	|			WHEN AgentReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CASE
	|						WHEN AgentReportInventory.Ref.AmountIncludesVAT
	|							THEN AgentReportInventory.TransmissionAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|						ELSE (AgentReportInventory.TransmissionAmount + AgentReportInventory.TransmissionVATAmount) * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					END
	|			ELSE CASE
	|					WHEN AgentReportInventory.Ref.AmountIncludesVAT
	|						THEN AgentReportInventory.TransmissionAmount * AgentReportInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AgentReportInventory.Ref.Multiplicity)
	|					ELSE (AgentReportInventory.TransmissionAmount + AgentReportInventory.TransmissionVATAmount) * AgentReportInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AgentReportInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS Cost,
	|	CAST(CASE
	|			WHEN AgentReportInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AgentReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AgentReportInventory.BrokerageVATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE AgentReportInventory.BrokerageVATAmount * AgentReportInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AgentReportInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageVATAmount,
	|	CAST(CASE
	|			WHEN AgentReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CASE
	|						WHEN AgentReportInventory.Ref.AmountIncludesVAT
	|							THEN AgentReportInventory.BrokerageAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|						ELSE (AgentReportInventory.BrokerageAmount + AgentReportInventory.BrokerageVATAmount) * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					END
	|			ELSE CASE
	|					WHEN AgentReportInventory.Ref.AmountIncludesVAT
	|						THEN AgentReportInventory.BrokerageAmount * AgentReportInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AgentReportInventory.Ref.Multiplicity)
	|					ELSE (AgentReportInventory.BrokerageAmount + AgentReportInventory.BrokerageVATAmount) * AgentReportInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AgentReportInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageAmount,
	|	CAST(CASE
	|			WHEN AgentReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CASE
	|						WHEN AgentReportInventory.Ref.AmountIncludesVAT
	|							THEN AgentReportInventory.BrokerageAmount * RegCurrencyRates.ExchangeRate * AgentReportInventory.Ref.Multiplicity / (AgentReportInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|						ELSE (AgentReportInventory.BrokerageAmount + AgentReportInventory.BrokerageVATAmount) * RegCurrencyRates.ExchangeRate * AgentReportInventory.Ref.Multiplicity / (AgentReportInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					END
	|			ELSE CASE
	|					WHEN AgentReportInventory.Ref.AmountIncludesVAT
	|						THEN AgentReportInventory.BrokerageAmount
	|					ELSE AgentReportInventory.BrokerageAmount + AgentReportInventory.BrokerageVATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageAmountCur,
	//( elmi #11
	 |	CAST(CASE
	|			    WHEN AgentReportInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			    ELSE CASE
	|					  WHEN AgentReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AgentReportInventory.BrokerageVATAmount *  RegCurrencyRates.ExchangeRate * AgentReportInventory.Ref.Multiplicity / (AgentReportInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					  ELSE AgentReportInventory.BrokerageVATAmount
	|				      END
	|		        END AS NUMBER(15, 2))КАК BrokerageVATAmountCur,
	//) elmi
	|	AgentReportInventory.CustomerOrder AS CustomerOrder,
	|	CAST(CASE
	|			WHEN AgentReportInventory.Ref.AmountIncludesVAT
	|				THEN AgentReportInventory.TransmissionAmount
	|			ELSE AgentReportInventory.TransmissionAmount + AgentReportInventory.TransmissionVATAmount
	|		END AS NUMBER(15, 2)) AS SettlementsAmountTakenPassed
	|INTO TemporaryTableInventory
	|FROM
	|	Document.AgentReport.Inventory AS AgentReportInventory
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
	|	AgentReportInventory.Ref = &Ref
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
	|	DocumentTable.Order AS Order,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivitySales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	DocumentTable.Document AS Document,
	|	SUM(CAST(DocumentTable.SettlementsAmount * DocumentTable.Ref.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * DocumentTable.Ref.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.AgentReport.Prepayment AS DocumentTable
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
	|	DocumentTable.Order,
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
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills";
	
	Query.SetParameter("Ref", DocumentRefAgentReport);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	SmallBusinessServer.GenerateTransactionsTable(DocumentRefAgentReport, StructureAdditionalProperties);
	
	GenerateTableSales(DocumentRefAgentReport, StructureAdditionalProperties);
	GenerateTableInventoryTransferred(DocumentRefAgentReport, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefAgentReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefAgentReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefAgentReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesUndistributed(DocumentRefAgentReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefAgentReport, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRefAgentReport, StructureAdditionalProperties);
	
	GenerateTableManagerial(DocumentRefAgentReport, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefAgentReport, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the "RegisterRecordsInventoryChange", "TransfersInventoryTransferredChange"
	// temprorary tables contain records, it is necessary to control the sale of goods.
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryTransferredChange
	 OR StructureTemporaryTables.RegisterRecordsAccountsReceivableChange Then
		
		Query = New Query(
		"SELECT
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
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.ReceptionTransmissionType) AS ReceptionTransmissionTypePresentation,
		|	REFPRESENTATION(InventoryTransferredBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryTransferredChange.QuantityChange, 0) + ISNULL(InventoryTransferredBalances.QuantityBalance, 0) AS BalanceInventoryTransferred,
		|	ISNULL(InventoryTransferredBalances.QuantityBalance, 0) AS QuantityBalanceInventoryTransferred,
		|	ISNULL(RegisterRecordsInventoryTransferredChange.SettlementsAmountChange, 0) + ISNULL(InventoryTransferredBalances.SettlementsAmountBalance, 0) AS SettlementsAmountInventoryTransferred,
		|	ISNULL(InventoryTransferredBalances.SettlementsAmountBalance, 0) AS SettlementsAmountBalanceInventoryTransferred
		|FROM
		|	RegisterRecordsInventoryTransferredChange AS RegisterRecordsInventoryTransferredChange
		|		LEFT JOIN AccumulationRegister.InventoryTransferred.Balance(
		|				&ControlTime,
		|				(Company, ProductsAndServices, Characteristic, Batch, Counterparty, Contract, Order, ReceptionTransmissionType) In
		|					(SELECT
		|						RegisterRecordsInventoryTransferredChange.Company AS Company,
		|						RegisterRecordsInventoryTransferredChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryTransferredChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryTransferredChange.Batch AS Batch,
		|						RegisterRecordsInventoryTransferredChange.Counterparty AS Counterparty,
		|						RegisterRecordsInventoryTransferredChange.Contract AS Contract,
		|						RegisterRecordsInventoryTransferredChange.Order AS Order,
		|						RegisterRecordsInventoryTransferredChange.ReceptionTransmissionType AS ReceptionTransmissionType
		|					FROM
		|						RegisterRecordsInventoryTransferredChange AS RegisterRecordsInventoryTransferredChange)) AS InventoryTransferredBalances
		|		ON RegisterRecordsInventoryTransferredChange.Company = InventoryTransferredBalances.Company
		|			AND RegisterRecordsInventoryTransferredChange.ProductsAndServices = InventoryTransferredBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryTransferredChange.Characteristic = InventoryTransferredBalances.Characteristic
		|			AND RegisterRecordsInventoryTransferredChange.Batch = InventoryTransferredBalances.Batch
		|			AND RegisterRecordsInventoryTransferredChange.Counterparty = InventoryTransferredBalances.Counterparty
		|			AND RegisterRecordsInventoryTransferredChange.Contract = InventoryTransferredBalances.Contract
		|			AND RegisterRecordsInventoryTransferredChange.Order = InventoryTransferredBalances.Order
		|			AND RegisterRecordsInventoryTransferredChange.ReceptionTransmissionType = InventoryTransferredBalances.ReceptionTransmissionType
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
			OR Not ResultsArray[2].IsEmpty() Then
			DocumentObjectAgentReport = DocumentRefAgentReport.GetObject();
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectAgentReport, QueryResultSelection, Cancel);
		EndIf;
		
		// The negative balance of transferred inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryTransferredRegisterErrors(DocumentObjectAgentReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			SmallBusinessServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectAgentReport, QueryResultSelection, Cancel);
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