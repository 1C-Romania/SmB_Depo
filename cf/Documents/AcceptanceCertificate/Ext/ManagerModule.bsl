#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefAcceptanceCertificate, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.Document AS Document,
	|	TableInventory.Document AS SalesDocument,
	|	TableInventory.CustomerOrder AS OrderSales,
	|	TableInventory.BusinessActivitySales AS BusinessActivity,
	|	TableInventory.GLAccountCost AS GLAccountCost,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.VATRate AS VATRate,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	0 AS Amount,
	|	SUM(TableInventory.VATAmount) AS VATAmount,
	|	TableInventory.StructuralUnit AS Department,
	|	TableInventory.Responsible AS Responsible,
	|	FALSE AS FixedCost,
	|	TableInventory.GLAccountCost AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	&InventoryAssembly AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableWorksAndServices AS TableInventory
	|WHERE
	|	TableInventory.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Work)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.Document,
	|	TableInventory.BusinessActivitySales,
	|	TableInventory.GLAccountCost,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder,
	|	TableInventory.VATRate,
	|	TableInventory.Responsible,
	|	TableInventory.Document,
	|	TableInventory.CustomerOrder,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccountCost,
	|	TableInventory.GLAccount";
	
	Query.SetParameter("InventoryAssembly", NStr("en='Manufacturing';ru='Производство'"));
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
	|	TemporaryTableWorksAndServices AS TableInventory
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
	|						TemporaryTableWorksAndServices AS TableInventory)) AS InventoryBalances
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
	
	Query.SetParameter("Ref", DocumentRefAcceptanceCertificate);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch,CustomerOrder");
	
	InventoryReservation = Constants.FunctionalOptionInventoryReservation.Get();
	OrderBlankRef = Documents.CustomerOrder.EmptyRef();
	
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
		
		If InventoryReservation Then
			StructureForSearch.Insert("CustomerOrder", RowTableInventory.CustomerOrder);
		Else
			StructureForSearch.Insert("CustomerOrder", OrderBlankRef);
		EndIf;
		
		QuantityWanted = RowTableInventory.Quantity;
		
		If QuantityWanted > 0 Then
			
			// Adding job release.
			TableRowReceipt = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
			
			If Not InventoryReservation Then
				TableRowReceipt.CustomerOrder = OrderBlankRef;
			EndIf;
			
			TableRowReceipt.SalesDocument = Undefined;
			TableRowReceipt.OrderSales = Undefined;
			TableRowReceipt.Department = Undefined;
			TableRowReceipt.Responsible = Undefined;
			
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
				
			ElsIf QuantityBalance = 0 Then
				
				AmountToBeWrittenOff = AmountBalance;
				
				If BalanceRowsArray.Count() > 0 Then
					BalanceRowsArray[0].AmountBalance = 0;
				EndIf;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Adding job completion.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			If Not InventoryReservation Then
				TableRowExpense.CustomerOrder = OrderBlankRef;
			EndIf;
			
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			TableRowExpense.ContentOfAccountingRecord = NStr("en='Inventory write-off';ru='Списание запасов'");
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Generate postings.
				RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerial, RowTableInventory);
				RowTableManagerial.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
				RowTableManagerial.Content = NStr("en='Inventory write-off';ru='Списание запасов'");
				RowTableManagerial.Amount = AmountToBeWrittenOff;
				
				// Move the cost of sales.
				StringTableSale = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
				FillPropertyValues(StringTableSale, RowTableInventory);
				
				StringTableSale.Quantity = 0;
				StringTableSale.Amount = 0;
				StringTableSale.VATAmount = 0;
				StringTableSale.Cost = AmountToBeWrittenOff;
				
				// Move income and expenses.
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.GLAccount = RowTableInventory.GLAccountCost;
				RowIncomeAndExpenses.AmountIncome = 0;
				RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
				RowIncomeAndExpenses.Amount = AmountToBeWrittenOff;
				
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en='Record expenses';ru='Отражение расходов'");
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure // GenerateTableInventory()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableProductRelease(DocumentRefAcceptanceCertificate, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProductRelease.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProductRelease.Period AS Period,
	|	TableProductRelease.Company AS Company,
	|	TableProductRelease.StructuralUnit AS StructuralUnit,
	|	TableProductRelease.ProductsAndServices AS ProductsAndServices,
	|	TableProductRelease.Characteristic AS Characteristic,
	|	TableProductRelease.Batch AS Batch,
	|	TableProductRelease.CustomerOrder AS CustomerOrder,
	|	SUM(TableProductRelease.Quantity) AS Quantity
	|FROM
	|	TemporaryTableWorksAndServices AS TableProductRelease
	|
	|GROUP BY
	|	TableProductRelease.Period,
	|	TableProductRelease.Company,
	|	TableProductRelease.StructuralUnit,
	|	TableProductRelease.ProductsAndServices,
	|	TableProductRelease.Characteristic,
	|	TableProductRelease.Batch,
	|	TableProductRelease.CustomerOrder";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", QueryResult.Unload());
	
EndProcedure // GenerateTableProductRelease()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefAcceptanceCertificate, StructureAdditionalProperties)
	
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
	|	TableSales.StructuralUnit AS Department,
	|	TableSales.Responsible AS Responsible,
	|	SUM(TableSales.Quantity) AS Quantity,
	|	SUM(TableSales.VATAmountSales) AS VATAmount,
	|	SUM(TableSales.Amount) AS Amount,
	|	0 AS Cost
	|FROM
	|	TemporaryTableWorksAndServices AS TableSales
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
	|	TableSales.StructuralUnit,
	|	TableSales.Responsible";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure // GenerateTableSales()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerOrders(DocumentRefAcceptanceCertificate, StructureAdditionalProperties)
	
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
	|	TemporaryTableWorksAndServices AS TableCustomerOrders
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
Procedure GenerateTableIncomeAndExpenses(DocumentRefAcceptanceCertificate, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	TableIncomeAndExpenses.LineNumber AS LineNumber,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.DepartmentSales AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessActivitySales AS BusinessActivity,
	|	TableIncomeAndExpenses.CustomerOrder AS CustomerOrder,
	|	TableIncomeAndExpenses.AccountStatementSales AS GLAccount,
	|	&IncomeReflection AS ContentOfAccountingRecord,
   //( elmi #11
	//|	SUM(TableIncomeAndExpenses.Amount) AS AmountIncome,
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS AmountIncome,      
	|	0 AS AmountExpense,
   //|	SUM(TableIncomeAndExpenses.Amount) AS Amount
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS Amount             
	//) elmi
	|FROM
	|	TemporaryTableWorksAndServices AS TableIncomeAndExpenses
	|WHERE
	|	TableIncomeAndExpenses.Amount <> 0
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.LineNumber,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.DepartmentSales,
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
	Query.SetParameter("IncomeReflection", NStr("en='Record income';ru='Отражение доходов'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefAcceptanceCertificate, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAcceptanceCertificate);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerLiability", NStr("en='Incurrence of customer liabilities';ru='Возникновение обязательств покупателя'"));
	Query.SetParameter("AdvanceCredit", NStr("en='Prepayment setoff';ru='Зачет предоплаты'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
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
	|	TemporaryTableWorksAndServices AS DocumentTable
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
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountCustomerSettlements
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
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefAcceptanceCertificate, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAcceptanceCertificate);
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
	|	TemporaryTableWorksAndServices AS DocumentTable
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
	|	Table.BusinessActivity AS BusinessActivity,
	|	&Item AS Item,
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
Procedure GenerateTableIncomeAndExpensesUndistributed(DocumentRefAcceptanceCertificate, StructureAdditionalProperties)
	
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefAcceptanceCertificate, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAcceptanceCertificate);
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

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefAcceptanceCertificate, StructureAdditionalProperties)
	
	//( elmi #11
    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
	|	Sum(TemporaryTable.VATAmount) AS VATExpenses ,
	|	Sum(TemporaryTable.VATAmountCur) AS VATExpensesCur 
	|FROM
	|	TemporaryTableWorksAndServices AS TemporaryTable
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
	|	TableManagerial.Amount - TableManagerial.VATAmount AS Amount ,          
	//) elmi
	|	&IncomeReflection AS Content
	|FROM
	|	TemporaryTableWorksAndServices AS TableManagerial
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
	//( elmi #11
	|		
	|	UNION ALL
	|		
	|	SELECT TOP 1
	|	4 AS Order,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Period AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableManagerial.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TableManagerial.GLAccountCustomerSettlements.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableManagerial.GLAccountCustomerSettlements.Currency
	|			THEN &VATExpensesCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	&TextVAT ,
	|	UNDEFINED ,
	|	0 ,
	|	&VATExpenses ,
	|	&VAT AS Content
	|FROM
	|	TemporaryTableWorksAndServices AS TableManagerial
	|		WHERE &VATExpenses  > 0
	//) elmi
	|
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	Query.SetParameter("SetOffAdvancePayment", NStr("en='Prepayment setoff';ru='Зачет предоплаты'"));
	Query.SetParameter("IncomeReflection", NStr("en='Revenue from sale';ru='Выручка от продажи'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
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

#Region DiscountCards

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByDiscountCard(DocumentRefAcceptanceCertificate, StructureAdditionalProperties)
	
	If DocumentRefAcceptanceCertificate.DiscountCard.IsEmpty() Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("SaleByDiscountCardTable", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Document.DiscountCard AS DiscountCard,
	|	TableSales.Document.DiscountCard.CardOwner AS CardOwner,
	|	SUM(TableSales.Amount) AS Amount
	|FROM
	|	TemporaryTableWorksAndServices AS TableSales
	|
	|GROUP BY
	|	TableSales.Period,
	|	TableSales.Document.DiscountCard,
	|	TableSales.Document.DiscountCard.CardOwner";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("SaleByDiscountCardTable", QueryResult.Unload());
	
EndProcedure // GenerateTableSalesByDiscountCard()

#EndRegion

#Region AutomaticDiscounts

Procedure GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefAcceptanceCertificate, StructureAdditionalProperties)
	
	If DocumentRefAcceptanceCertificate.DiscountsMarkups.Count() = 0 OR Not GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
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
	|	TemporaryTableWorksAndServices.ProductsAndServices,
	|	TemporaryTableWorksAndServices.Characteristic,
	|	TemporaryTableWorksAndServices.Document AS DocumentDiscounts,
	|	TemporaryTableWorksAndServices.Counterparty AS RecipientDiscounts
	|FROM
	|	TemporaryTableWorksAndServices AS TemporaryTableWorksAndServices
	|		INNER JOIN TemporaryTableAutoDiscountsMarkups AS TemporaryTableAutoDiscountsMarkups
	|		ON TemporaryTableWorksAndServices.ConnectionKey = TemporaryTableAutoDiscountsMarkups.ConnectionKey";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", QueryResult.Unload());
	
EndProcedure // GenerateTableSalesByAutomaticDiscountsApplied()

#EndRegion

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefAcceptanceCertificate, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	AcceptanceCertificateWorksAndServices.LineNumber AS LineNumber,
	|	AcceptanceCertificateWorksAndServices.Ref.Date AS Period,
	|	&Company AS Company,
	|	AcceptanceCertificateWorksAndServices.Ref.Department AS StructuralUnit,
	|	AcceptanceCertificateWorksAndServices.Ref.Responsible AS Responsible,
	|	AcceptanceCertificateWorksAndServices.ProductsAndServices.ExpensesGLAccount AS GLAccount,
	|	AcceptanceCertificateWorksAndServices.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN AcceptanceCertificateWorksAndServices.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsAndServicesBatches.EmptyRef) AS Batch,
	|	AcceptanceCertificateWorksAndServices.CustomerOrder AS CustomerOrder,
	|	AcceptanceCertificateWorksAndServices.Ref AS Document,
	|	AcceptanceCertificateWorksAndServices.Ref.Counterparty AS Counterparty,
	|	AcceptanceCertificateWorksAndServices.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	AcceptanceCertificateWorksAndServices.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	AcceptanceCertificateWorksAndServices.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	AcceptanceCertificateWorksAndServices.Ref.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	AcceptanceCertificateWorksAndServices.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	AcceptanceCertificateWorksAndServices.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	AcceptanceCertificateWorksAndServices.Ref.Contract AS Contract,
	|	AcceptanceCertificateWorksAndServices.Ref.Department AS DepartmentSales,
	|	AcceptanceCertificateWorksAndServices.ProductsAndServices.BusinessActivity AS BusinessActivitySales,
	|	AcceptanceCertificateWorksAndServices.ProductsAndServices.BusinessActivity.GLAccountRevenueFromSales AS AccountStatementSales,
	|	AcceptanceCertificateWorksAndServices.ProductsAndServices.BusinessActivity.GLAccountCostOfSales AS GLAccountCost,
	|	AcceptanceCertificateWorksAndServices.ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|	CASE
	|		WHEN VALUETYPE(AcceptanceCertificateWorksAndServices.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN AcceptanceCertificateWorksAndServices.Quantity
	|		ELSE AcceptanceCertificateWorksAndServices.Quantity * AcceptanceCertificateWorksAndServices.MeasurementUnit.Factor
	|	END AS Quantity,
	|	AcceptanceCertificateWorksAndServices.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN AcceptanceCertificateWorksAndServices.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AcceptanceCertificateWorksAndServices.Total * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE AcceptanceCertificateWorksAndServices.Total * AcceptanceCertificateWorksAndServices.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AcceptanceCertificateWorksAndServices.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN AcceptanceCertificateWorksAndServices.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AcceptanceCertificateWorksAndServices.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AcceptanceCertificateWorksAndServices.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE AcceptanceCertificateWorksAndServices.VATAmount * AcceptanceCertificateWorksAndServices.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AcceptanceCertificateWorksAndServices.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN AcceptanceCertificateWorksAndServices.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AcceptanceCertificateWorksAndServices.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE AcceptanceCertificateWorksAndServices.VATAmount * AcceptanceCertificateWorksAndServices.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AcceptanceCertificateWorksAndServices.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmountSales,
	|	CAST(CASE
	|			WHEN AcceptanceCertificateWorksAndServices.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AcceptanceCertificateWorksAndServices.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AcceptanceCertificateWorksAndServices.VATAmount * RegCurrencyRates.ExchangeRate * AcceptanceCertificateWorksAndServices.Ref.Multiplicity / (AcceptanceCertificateWorksAndServices.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE AcceptanceCertificateWorksAndServices.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN AcceptanceCertificateWorksAndServices.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AcceptanceCertificateWorksAndServices.Total * RegCurrencyRates.ExchangeRate * AcceptanceCertificateWorksAndServices.Ref.Multiplicity / (AcceptanceCertificateWorksAndServices.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE AcceptanceCertificateWorksAndServices.Total
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	AcceptanceCertificateWorksAndServices.ConnectionKey
	|INTO TemporaryTableWorksAndServices
	|FROM
	|	Document.AcceptanceCertificate.WorksAndServices AS AcceptanceCertificateWorksAndServices
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
	|	AcceptanceCertificateWorksAndServices.Ref = &Ref
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
	|	DocumentTable.Order AS Order,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivitySales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	DocumentTable.Ref.BasisDocument AS BasisDocument,
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
	|	Document.AcceptanceCertificate.Prepayment AS DocumentTable
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
	|	DocumentTable.Ref.BasisDocument,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AcceptanceCertificateDiscountsMarkups.ConnectionKey,
	|	AcceptanceCertificateDiscountsMarkups.DiscountMarkup,
	|	CAST(CASE
	|			WHEN AcceptanceCertificateDiscountsMarkups.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AcceptanceCertificateDiscountsMarkups.Amount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE AcceptanceCertificateDiscountsMarkups.Amount * AcceptanceCertificateDiscountsMarkups.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * AcceptanceCertificateDiscountsMarkups.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	AcceptanceCertificateDiscountsMarkups.Ref.Date AS Period,
	|	AcceptanceCertificateDiscountsMarkups.Ref.Department AS StructuralUnit
	|INTO TemporaryTableAutoDiscountsMarkups
	|FROM
	|	Document.AcceptanceCertificate.DiscountsMarkups AS AcceptanceCertificateDiscountsMarkups
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
	|	AcceptanceCertificateDiscountsMarkups.Ref = &Ref
	|	AND AcceptanceCertificateDiscountsMarkups.Amount <> 0";
	
	Query.SetParameter("Ref", DocumentRefAcceptanceCertificate);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	SmallBusinessServer.GenerateTransactionsTable(DocumentRefAcceptanceCertificate, StructureAdditionalProperties);
	
	GenerateTableProductRelease(DocumentRefAcceptanceCertificate, StructureAdditionalProperties);
	GenerateTableSales(DocumentRefAcceptanceCertificate, StructureAdditionalProperties);
	GenerateTableCustomerOrders(DocumentRefAcceptanceCertificate, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefAcceptanceCertificate, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefAcceptanceCertificate, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRefAcceptanceCertificate, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefAcceptanceCertificate, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesUndistributed(DocumentRefAcceptanceCertificate, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefAcceptanceCertificate, StructureAdditionalProperties);
	
	GenerateTableManagerial(DocumentRefAcceptanceCertificate, StructureAdditionalProperties);
	
	// DiscountCards
	GenerateTableSalesByDiscountCard(DocumentRefAcceptanceCertificate, StructureAdditionalProperties);
	// AutomaticDiscounts
	GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefAcceptanceCertificate, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefAcceptanceCertificate, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange",
	// "RegisterRecordsCustomerOrdersChange" contain records, it is required to control products sales.
	If StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsCustomerOrdersChange
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
		|	RegisterRecordsCustomerOrdersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsCustomerOrdersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsCustomerOrdersChange.CustomerOrder) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsCustomerOrdersChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsCustomerOrdersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(CustomerOrdersBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsCustomerOrdersChange.QuantityChange, 0) + ISNULL(CustomerOrdersBalances.QuantityBalance, 0) AS BalanceCustomerOrders,
		|	ISNULL(CustomerOrdersBalances.QuantityBalance, 0) AS QuantityBalanceCustomerOrders
		|FROM
		|	RegisterRecordsCustomerOrdersChange AS RegisterRecordsCustomerOrdersChange
		|		LEFT JOIN AccumulationRegister.CustomerOrders.Balance(
		|				&ControlTime,
		|				(Company, CustomerOrder, ProductsAndServices, Characteristic) In
		|					(SELECT
		|						RegisterRecordsCustomerOrdersChange.Company AS Company,
		|						RegisterRecordsCustomerOrdersChange.CustomerOrder AS CustomerOrder,
		|						RegisterRecordsCustomerOrdersChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsCustomerOrdersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsCustomerOrdersChange AS RegisterRecordsCustomerOrdersChange)) AS CustomerOrdersBalances
		|		ON RegisterRecordsCustomerOrdersChange.Company = CustomerOrdersBalances.Company
		|			AND RegisterRecordsCustomerOrdersChange.CustomerOrder = CustomerOrdersBalances.CustomerOrder
		|			AND RegisterRecordsCustomerOrdersChange.ProductsAndServices = CustomerOrdersBalances.ProductsAndServices
		|			AND RegisterRecordsCustomerOrdersChange.Characteristic = CustomerOrdersBalances.Characteristic
		|WHERE
		|	ISNULL(CustomerOrdersBalances.QuantityBalance, 0) < 0
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
			DocumentObjectAcceptanceCertificate = DocumentRefAcceptanceCertificate.GetObject()
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectAcceptanceCertificate, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on customer order.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToCustomerOrdersRegisterErrors(DocumentObjectAcceptanceCertificate, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			SmallBusinessServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectAcceptanceCertificate, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure // RunControl()

#Region PrintInterface

// Procedure for generation of print form Acceptance certificate
//
Procedure GenerateAct(ObjectsArray, PrintObjects, SpreadsheetDocument)
	
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_CompletionCertificate";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Query.Text = 
	"SELECT
	|	AcceptanceCertificate.Ref AS Ref,
	|	AcceptanceCertificate.Number AS Number,
	|	AcceptanceCertificate.Date AS DocumentDate,
	|	AcceptanceCertificate.Company AS Company,
	|	AcceptanceCertificate.Counterparty AS Counterparty,
	|	AcceptanceCertificate.AmountIncludesVAT AS AmountIncludesVAT,
	|	AcceptanceCertificate.DocumentCurrency AS DocumentCurrency,
	|	AcceptanceCertificate.Company.Prefix AS Prefix,
	|	AcceptanceCertificate.WorksAndServices.(
	|		LineNumber AS LineNumber,
	|		CASE
	|			WHEN (CAST(AcceptanceCertificate.WorksAndServices.ProductsAndServices.DescriptionFull AS String(1000))) = """"
	|				THEN AcceptanceCertificate.WorksAndServices.ProductsAndServices.Description
	|			ELSE CAST(AcceptanceCertificate.WorksAndServices.ProductsAndServices.DescriptionFull AS String(1000))
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
	|			WHEN AcceptanceCertificate.WorksAndServices.DiscountMarkupPercent <> 0
	|					OR AcceptanceCertificate.WorksAndServices.AutomaticDiscountAmount <> 0
	|				THEN 1
	|			ELSE 0
	|		END AS IsDiscount,
	|		AutomaticDiscountAmount
	|	)
	|FROM
	|	Document.AcceptanceCertificate AS AcceptanceCertificate
	|WHERE
	|	AcceptanceCertificate.Ref IN(&ObjectsArray)
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
		
		StringSelectionProducts = Header.WorksAndServices.Select();
		
		SpreadsheetDocument.PrintParametersName = "PRINT_OPTIONS_ActOfExecutedWorks_PF_MXL_Act";
		
		Template = PrintManagement.PrintedFormsTemplate("Document.AcceptanceCertificate.PF_MXL_Act");
		
		InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
		InfoAboutCounterparty = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
		
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = "Act # "
		                                        + DocumentNumber
		                                        + " dated "
		                                        + Format(Header.DocumentDate, "DLF=DD");
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Vendor");
		TemplateArea.Parameters.VendorPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,LegalAddress,PhoneNumbers,");
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Customer");
		TemplateArea.Parameters.RecipientPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr,TIN,LegalAddress,PhoneNumbers,");
		SpreadsheetDocument.Put(TemplateArea);
		
		AreDiscounts = Header.WorksAndServices.Unload().Total("IsDiscount") <> 0;
		
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
				TemplateArea.Parameters.Product = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(
					StringSelectionProducts.Product,
					StringSelectionProducts.Characteristic,
					StringSelectionProducts.SKU
				);
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
			
			Amount		= Amount		+ StringSelectionProducts.Amount;
			VATAmount	= VATAmount	+ StringSelectionProducts.VATAmount;
			Total		= Total 	+ StringSelectionProducts.Total;
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
		
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
EndProcedure // GenerateAct()

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName) Export
	
	SpreadsheetDocument = New SpreadsheetDocument;	
	
	If TemplateName = "Act" Then
		
		GenerateAct(ObjectsArray, PrintObjects, SpreadsheetDocument);
		
	EndIf;
	
	Return SpreadsheetDocument;
	
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
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Act") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "Act", "Services acceptance certificate", PrintForm(ObjectsArray, PrintObjects, "Act"));
		
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
	
	// ServicesAcceptanceCertificate
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "Act";
	PrintCommand.Presentation = NStr("en='Acceptance certificate';ru='Акт выполненных работ'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf