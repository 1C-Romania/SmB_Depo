#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefAdditionalCosts, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TRUE AS FixedCost,
	|	&InventoryReceipt AS ContentOfAccountingRecord,
	|	0 AS Quantity,
	|	SUM(TableInventory.AmountExpense) AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
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
	
	Query.SetParameter("InventoryReceipt", NStr("en = 'Inventory receiving'"));
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
EndProcedure // GenerateTableInventory()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefAdditionalCosts, StructureAdditionalProperties)
	
	//( elmi #11
    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
	|	Sum(TemporaryTable.Amount) AS AmountWithVAT ,
	|	Sum(TemporaryTable.AmountCur) AS AmountWithVATCur 
	|FROM
	|	TemporaryTableExpenses AS TemporaryTable
	|GROUP BY
	|TemporaryTable.Period,
	|TemporaryTable.Company	";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	AmountWithVAT = 0;
	AmountWithVATCur = 0;
	
	While Selection.Next() Do  
		  AmountWithVAT    = Selection.AmountWithVAT;
	      AmountWithVATCur = Selection.AmountWithVATCur;
	EndDo;
    //) elmi
	
	
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAdditionalCosts);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfLiabilityToVendor", NStr("en='Appearance of vendor liabilities'"));
	Query.SetParameter("AdvanceCredit", NStr("en='Setoff of advance payment'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference'"));
	
	//( elmi #11
	Query.SetParameter("AmountWithVAT", AmountWithVAT);         
	Query.SetParameter("AmountWithVATCur", AmountWithVATCur);   
	//) elmi
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.GLAccountVendorSettlements AS GLAccount,
	|	DocumentTable.Contract AS Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.PurchaseOrder REFS Document.PurchaseOrder
	|				AND DocumentTable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	//( elmi #11
	//|	SUM(DocumentTable.AmountExpense) AS Amount,
	//|	SUM(DocumentTable.AmountExpensesCur) AS AmountCur,
	//|	SUM(DocumentTable.AmountExpense) AS AmountForBalance,
	//|	SUM(DocumentTable.AmountExpensesCur) AS AmountCurForBalance,
	|	&AmountWithVAT AS Amount,
	|	&AmountWithVATCur AS AmountCur,
	|	&AmountWithVAT AS AmountForBalance,
	|	&AmountWithVATCur AS AmountCurForBalance,
    //) elmi
	|	CAST(&AppearenceOfLiabilityToVendor AS String(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsPayable
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
	|		WHEN DocumentTable.PurchaseOrder REFS Document.PurchaseOrder
	|				AND DocumentTable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
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
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.VendorAdvancesGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
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
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.GLAccountVendorSettlements,
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
	Query.Text = SmallBusinessServer.GetQueryTextExchangeRatesDifferencesAccountsPayable(Query.TempTablesManager, True, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchasing(DocumentRefAdditionalCosts, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TablePurchasing.Period AS Period,
	|	TablePurchasing.Company AS Company,
	|	TablePurchasing.ProductsAndServices AS ProductsAndServices,
	|	TablePurchasing.Characteristic AS Characteristic,
	|	TablePurchasing.Batch AS Batch,
	|	TablePurchasing.PurchaseOrder AS PurchaseOrder,
	|	TablePurchasing.Document AS Document,
	|	TablePurchasing.VATRate AS VATRate,
	|	SUM(TablePurchasing.Quantity) AS Quantity,
	|	SUM(TablePurchasing.AmountVATPurchase) AS VATAmount,
	|	SUM(TablePurchasing.Amount) AS Amount
	|FROM
	|	TemporaryTableExpenses AS TablePurchasing
	|
	|GROUP BY
	|	TablePurchasing.Period,
	|	TablePurchasing.Company,
	|	TablePurchasing.ProductsAndServices,
	|	TablePurchasing.Characteristic,
	|	TablePurchasing.Batch,
	|	TablePurchasing.PurchaseOrder,
	|	TablePurchasing.Document,
	|	TablePurchasing.VATRate";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchasing", QueryResult.Unload());
	
EndProcedure // GeneratePurchasingTable()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchaseOrders(DocumentRefAdditionalCosts, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TablePurchaseOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TablePurchaseOrders.Period AS Period,
	|	TablePurchaseOrders.Company AS Company,
	|	TablePurchaseOrders.ProductsAndServices AS ProductsAndServices,
	|	TablePurchaseOrders.Characteristic AS Characteristic,
	|	TablePurchaseOrders.PurchaseOrder AS PurchaseOrder,
	|	SUM(TablePurchaseOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableExpenses AS TablePurchaseOrders
	|WHERE
	|	TablePurchaseOrders.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|
	|GROUP BY
	|	TablePurchaseOrders.Period,
	|	TablePurchaseOrders.Company,
	|	TablePurchaseOrders.ProductsAndServices,
	|	TablePurchaseOrders.Characteristic,
	|	TablePurchaseOrders.PurchaseOrder";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchaseOrders", QueryResult.Unload());
	
EndProcedure // GenerateTablePurchaseOrders()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefAdditionalCosts, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	UNDEFINED AS CustomerOrder,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE &PositiveExchangeDifferenceGLAccount
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
	|	(SELECT
	|		TableOfExchangeRateDifferencesAccountsPayable.Date AS Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company AS Company,
	|		SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
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
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableOfExchangeRateDifferencesAccountsPayable
	|	
	|	GROUP BY
	|		TableOfExchangeRateDifferencesAccountsPayable.Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company
	|	
	|	HAVING
	|		(SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) <= -0.005)) AS DocumentTable
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	Query.SetParameter("ExchangeDifference", NStr("en = 'Exchange rate difference'"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefAdditionalCosts, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAdditionalCosts);
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
	|	DocumentTable.BusinessActivity AS BusinessActivity,
	//( elmi #11
	//|	DocumentTable.Amount AS AmountExpense
	|	DocumentTable.Amount - DocumentTable.VATAmount AS AmountExpense  
	//) elmi
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	DocumentTable.LineNumber
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
	
	TableInventoryIncomeAndExpensesRetained =  ResultsArray[0].Unload();
	SelectionOfQueryResult = ResultsArray[1].Select();
	
	TablePrepaymentIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Copy();
	TablePrepaymentIncomeAndExpensesRetained.Clear();
	
	If SelectionOfQueryResult.Next() Then
		AmountToBeWrittenOff = SelectionOfQueryResult.AmountToBeWrittenOff;
		For Each StringInventoryIncomeAndExpensesRetained IN TableInventoryIncomeAndExpensesRetained Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountExpense <= AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				AmountToBeWrittenOff = AmountToBeWrittenOff - StringInventoryIncomeAndExpensesRetained.AmountExpense;
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountExpense > AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				StringPrepaymentIncomeAndExpensesRetained.AmountExpense = AmountToBeWrittenOff;
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
		Item = Catalogs.CashFlowItems.PaymentToVendor;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.Document AS Document,
	|	&Item AS Item,
	|	Table.BusinessActivity AS BusinessActivity,
	|	Table.AmountExpense AS AmountExpense
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
Procedure GenerateTableIncomeAndExpensesUndistributed(DocumentRefAdditionalCosts, StructureAdditionalProperties)
	
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
	|	DocumentTable.Amount AS AmountExpense
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefAdditionalCosts, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAdditionalCosts);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.DocumentDate AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS BusinessActivity,
	|	DocumentTable.Item AS Item,
	|	-DocumentTable.Amount AS AmountExpense
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
	|	Table.AmountExpense
	|FROM
	|	TemporaryTablePrepaidIncomeAndExpensesRetained AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesCashMethod() 

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefAdditionalCosts, StructureAdditionalProperties)
	
	//( elmi #11
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
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Period AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableManagerial.GLAccount AS AccountDr,
	|	CASE
	|		WHEN TableManagerial.GLAccount.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableManagerial.GLAccount.Currency
	|			THEN TableManagerial.AmountExpensesCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableManagerial.GLAccountVendorSettlements AS AccountCr,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN TableManagerial.AmountExpensesCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableManagerial.AmountExpense AS Amount,
	|	&InventoryReceipt AS Content
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
	|	DocumentTable.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	&SetOffAdvancePayment
	|FROM
	|	(SELECT
	|		DocumentTable.Period AS Period,
	|		DocumentTable.Company AS Company,
	|		DocumentTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|		DocumentTable.VendorAdvancesGLAccountCurrency AS VendorAdvancesGLAccountCurrency,
	|		DocumentTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|		DocumentTable.GLAccountVendorSettlementsCurrency AS GLAccountVendorSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|		SUM(DocumentTable.AmountCur) AS AmountCur,
	|		SUM(DocumentTable.Amount) AS Amount
	|	FROM
	|		(SELECT
	|			DocumentTable.Period AS Period,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|			DocumentTable.VendorAdvancesGLAccount.Currency AS VendorAdvancesGLAccountCurrency,
	|			DocumentTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|			DocumentTable.GLAccountVendorSettlements.Currency AS GLAccountVendorSettlementsCurrency,
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
	|			DocumentTable.Counterparty.VendorAdvancesGLAccount,
	|			DocumentTable.Counterparty.VendorAdvancesGLAccount.Currency,
	|			DocumentTable.Counterparty.GLAccountVendorSettlements,
	|			DocumentTable.Counterparty.GLAccountVendorSettlements.Currency,
	|			DocumentTable.Currency,
	|			0,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Company,
	|		DocumentTable.VendorAdvancesGLAccount,
	|		DocumentTable.VendorAdvancesGLAccountCurrency,
	|		DocumentTable.GLAccountVendorSettlements,
	|		DocumentTable.GLAccountVendorSettlementsCurrency,
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
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
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
	|			THEN TableManagerial.GLAccount
	|		ELSE &PositiveExchangeDifferenceGLAccount
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
	|			THEN TableManagerial.AmountOfExchangeDifferences
	|		ELSE -TableManagerial.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference
	|FROM
	|	(SELECT
	|		TableOfExchangeRateDifferencesAccountsPayable.Date AS Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company AS Company,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccount AS GLAccount,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccountForeignCurrency AS GLAccountForeignCurrency,
	|		TableOfExchangeRateDifferencesAccountsPayable.Currency AS Currency,
	|		SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.GLAccount AS GLAccount,
	|			DocumentTable.GLAccount.Currency AS GLAccountForeignCurrency,
	|			DocumentTable.Currency AS Currency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
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
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableOfExchangeRateDifferencesAccountsPayable
	|	
	|	GROUP BY
	|		TableOfExchangeRateDifferencesAccountsPayable.Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccount,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccountForeignCurrency,
	|		TableOfExchangeRateDifferencesAccountsPayable.Currency
	|	
	|	HAVING
	|		(SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) <= -0.005)) AS TableManagerial
	//( elmi #11
	|		
	|		UNION ALL
	|		
	|	SELECT TOP 1
	|	4 AS Order,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Period AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&TextVAT,
	|	UNDEFINED,
	|	0,
	|	TableManagerial.GLAccountVendorSettlements AS AccountCr, 
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN &VATExpensesCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	&VATExpenses ,
	|	&VAT AS Content
	|FROM
	|	TemporaryTableInventory AS TableManagerial
	|		WHERE &VATExpenses  > 0
	//) elmi
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
		
	Query.SetParameter("InventoryReceipt", NStr("en = 'Add. expenses receiving'"));
	Query.SetParameter("SetOffAdvancePayment", NStr("en = 'Setoff of advance payment'"));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Exchange rate difference'"));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	//( elmi #11
	Query.SetParameter("VAT", NStr("en=' VAT '"));
	Query.SetParameter("TextVAT",  ChartsOfAccounts.Managerial.Taxes);
	Query.SetParameter("VATExpenses", VATExpenses);
	Query.SetParameter("VATExpensesCur", VATExpensesCur);
	//) elmi

	
	QueryResult = Query.Execute();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", QueryResult.Unload());
	
EndProcedure // GenerateTableManagerial()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefAdditionalCosts, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	AdditionalCostsInventory.LineNumber AS LineNumber,
	|	AdditionalCostsInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	AdditionalCostsInventory.Ref.Counterparty AS Counterparty,
	|	AdditionalCostsInventory.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	AdditionalCostsInventory.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	AdditionalCostsInventory.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	AdditionalCostsInventory.Ref.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	AdditionalCostsInventory.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	AdditionalCostsInventory.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	AdditionalCostsInventory.Ref.Contract AS Contract,
	|	AdditionalCostsInventory.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	AdditionalCostsInventory.Ref.PurchaseOrder AS PurchaseOrder,
	|	AdditionalCostsInventory.Ref.StructuralUnit AS StructuralUnit,
	|	AdditionalCostsInventory.ProductsAndServices.InventoryGLAccount AS GLAccount,
	|	AdditionalCostsInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN AdditionalCostsInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN AdditionalCostsInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	AdditionalCostsInventory.CustomerOrder AS CustomerOrder,
	|	CASE
	|		WHEN VALUETYPE(AdditionalCostsInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN AdditionalCostsInventory.Quantity
	|		ELSE AdditionalCostsInventory.Quantity * AdditionalCostsInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CAST(CASE
	|			WHEN AdditionalCostsInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AdditionalCostsInventory.Total * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE AdditionalCostsInventory.Total * AdditionalCostsInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AdditionalCostsInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN AdditionalCostsInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AdditionalCostsInventory.AmountExpense * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE AdditionalCostsInventory.AmountExpense * AdditionalCostsInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AdditionalCostsInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountExpense,
	|	CAST(CASE
	|			WHEN AdditionalCostsInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AdditionalCostsInventory.AmountExpense * RegCurrencyRates.ExchangeRate * AdditionalCostsInventory.Ref.Multiplicity / (AdditionalCostsInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE AdditionalCostsInventory.AmountExpense
	|		END AS NUMBER(15, 2)) AS AmountExpensesCur
	|INTO TemporaryTableInventory
	|FROM
	|	Document.AdditionalCosts.Inventory AS AdditionalCostsInventory
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
	|	AdditionalCostsInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdditionalCostsExpenses.LineNumber AS LineNumber,
	|	AdditionalCostsExpenses.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	AdditionalCostsExpenses.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	AdditionalCostsExpenses.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	AdditionalCostsExpenses.Ref.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	AdditionalCostsExpenses.Ref.Date AS Period,
	|	AdditionalCostsExpenses.Ref AS Document,
	|	AdditionalCostsExpenses.ProductsAndServices.ExpensesGLAccount AS GLAccount,
	|	AdditionalCostsExpenses.ProductsAndServices.BusinessActivity AS BusinessActivity,
	|	&Company AS Company,
	|	AdditionalCostsExpenses.ProductsAndServices AS ProductsAndServices,
	|	VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef) AS Characteristic,
	|	VALUE(Catalog.ProductsAndServicesBatches.EmptyRef) AS Batch,
	|	AdditionalCostsExpenses.Ref.PurchaseOrder AS PurchaseOrder,
	|	AdditionalCostsExpenses.VATRate AS VATRate,
	|	CASE
	|		WHEN VALUETYPE(AdditionalCostsExpenses.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN AdditionalCostsExpenses.Quantity
	|		ELSE AdditionalCostsExpenses.Quantity * AdditionalCostsExpenses.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CAST(CASE
	|			WHEN AdditionalCostsExpenses.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AdditionalCostsExpenses.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AdditionalCostsExpenses.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE AdditionalCostsExpenses.VATAmount * AdditionalCostsExpenses.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AdditionalCostsExpenses.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN AdditionalCostsExpenses.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AdditionalCostsExpenses.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE AdditionalCostsExpenses.VATAmount * AdditionalCostsExpenses.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AdditionalCostsExpenses.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountVATPurchase,
	|	CAST(CASE
	|			WHEN AdditionalCostsExpenses.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AdditionalCostsExpenses.Total * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE AdditionalCostsExpenses.Total * AdditionalCostsExpenses.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AdditionalCostsExpenses.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount ,
	//( elmi #11
	|	CAST(CASE
	|			WHEN AdditionalCostsExpenses.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AdditionalCostsExpenses.VATAmount * RegCurrencyRates.ExchangeRate * AdditionalCostsExpenses.Ref.Multiplicity / (AdditionalCostsExpenses.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE AdditionalCostsExpenses.VATAmount
	|		END AS NUMBER(15, 2)) AS VATAmountCur ,
	|	CAST(CASE
	|			WHEN AdditionalCostsExpenses.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AdditionalCostsExpenses.Total * RegCurrencyRates.ExchangeRate * AdditionalCostsExpenses.Ref.Multiplicity / (AdditionalCostsExpenses.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE AdditionalCostsExpenses.Total
	|		END AS NUMBER(15, 2)) AS AmountCur
	//) elmi
	|INTO TemporaryTableExpenses
	|FROM
	|	Document.AdditionalCosts.Expenses AS AdditionalCostsExpenses
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
	|	AdditionalCostsExpenses.Ref = &Ref
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
	|	DocumentTable.Ref.PurchaseOrder AS Order,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivitySales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN Not DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = Type(Document.ExpenseReport)
	|				OR VALUETYPE(DocumentTable.Document) = Type(Document.Netting)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
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
	|	Document.AdditionalCosts.Prepayment AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRatesSliceLast
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
	|				OR VALUETYPE(DocumentTable.Document) = Type(Document.ExpenseReport)
	|				OR VALUETYPE(DocumentTable.Document) = Type(Document.Netting)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Date
	|		ELSE DocumentTable.Ref.Date
	|	END,
	|	DocumentTable.Ref.PurchaseOrder,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills";
	
	Query.SetParameter("Ref", DocumentRefAdditionalCosts);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.ExecuteBatch();
	
	GenerateTableInventory(DocumentRefAdditionalCosts, StructureAdditionalProperties);
	GenerateTablePurchasing(DocumentRefAdditionalCosts, StructureAdditionalProperties);
	GenerateTablePurchaseOrders(DocumentRefAdditionalCosts, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefAdditionalCosts, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefAdditionalCosts, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefAdditionalCosts, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesUndistributed(DocumentRefAdditionalCosts, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefAdditionalCosts, StructureAdditionalProperties);
	
	GenerateTableManagerial(DocumentRefAdditionalCosts, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefAdditionalCosts, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the temporary tables "RegisterRecordsSuppliersSettlementsChange", "RegisterRecordsPurchaseOrdersChange" contain records, 
	// it is required to execute the implementation products control.
	
	If StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange
	 OR StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsPurchaseOrdersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.PurchaseOrder) AS PurchaseOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(PurchaseOrdersBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsPurchaseOrdersChange.QuantityChange, 0) + ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS BalancePurchaseOrders,
		|	ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS QuantityBalancePurchaseOrders
		|FROM
		|	RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange
		|		LEFT JOIN AccumulationRegister.PurchaseOrders.Balance(
		|				&ControlTime,
		|				(Company, PurchaseOrder, ProductsAndServices, Characteristic) In
		|					(SELECT
		|						RegisterRecordsPurchaseOrdersChange.Company AS Company,
		|						RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS PurchaseOrder,
		|						RegisterRecordsPurchaseOrdersChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsPurchaseOrdersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange)) AS PurchaseOrdersBalances
		|		ON RegisterRecordsPurchaseOrdersChange.Company = PurchaseOrdersBalances.Company
		|			AND RegisterRecordsPurchaseOrdersChange.PurchaseOrder = PurchaseOrdersBalances.PurchaseOrder
		|			AND RegisterRecordsPurchaseOrdersChange.ProductsAndServices = PurchaseOrdersBalances.ProductsAndServices
		|			AND RegisterRecordsPurchaseOrdersChange.Characteristic = PurchaseOrdersBalances.Characteristic
		|WHERE
		|	ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) < 0
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
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectAdditionalCosts = DocumentRefAdditionalCosts.GetObject()
		EndIf;
		
		// Negative balance by the purchase order.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectAdditionalCosts, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectAdditionalCosts, QueryResultSelection, Cancel);
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
