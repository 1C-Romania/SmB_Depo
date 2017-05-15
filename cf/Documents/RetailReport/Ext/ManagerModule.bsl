#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.Document AS Document,
	|	TableInventory.Document AS SalesDocument,
	|	TableInventory.Department AS Department,
	|	TableInventory.Responsible AS Responsible,
	|	TableInventory.ProductsOnCommission AS ProductsOnCommission,
	|	UNDEFINED AS OrderSales,
	|	ISNULL(TableInventory.StructuralUnit, VALUE(Catalog.StructuralUnits.EmptyRef)) AS StructuralUnit,
	|	ISNULL(TableInventory.StructuralUnitCorr, VALUE(Catalog.StructuralUnits.EmptyRef)) AS StructuralUnitCorr,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.CorrespondentAccountAccountingInventory AS CorrGLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.ProductsAndServicesType AS ProductsAndServicesType,
	|	TableInventory.BusinessActivity AS BusinessActivity,
	|	TableInventory.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.CustomerOrder AS CustomerCorrOrder,
	|	TableInventory.VATRate AS VATRate,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.VATAmount) AS VATAmount,
	|	SUM(TableInventory.Amount) AS Amount,
	|	0 AS Cost,
	|	FALSE AS FixedCost,
	|	TableInventory.GLAccountCostOfSales AS AccountDr,
	|	TableInventory.InventoryGLAccount AS AccountCr,
	|	CAST(&InventoryWriteOff AS String(100)) AS Content,
	|	CAST(&InventoryWriteOff AS String(100)) AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|
	|GROUP BY
	|	TableInventory.Date,
	|	TableInventory.Company,
	|	TableInventory.Document,
	|	TableInventory.Department,
	|	ISNULL(TableInventory.StructuralUnit, VALUE(Catalog.StructuralUnits.EmptyRef)),
	|	ISNULL(TableInventory.StructuralUnitCorr, VALUE(Catalog.StructuralUnits.EmptyRef)),
	|	TableInventory.InventoryGLAccount,
	|	TableInventory.CorrespondentAccountAccountingInventory,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.ProductsAndServicesType,
	|	TableInventory.BusinessActivity,
	|	TableInventory.ProductsAndServicesCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.CustomerOrder,
	|	TableInventory.VATRate,
	|	TableInventory.GLAccountCostOfSales,
	|	TableInventory.ProductsOnCommission,
	|	TableInventory.Responsible,
	|	TableInventory.Document,
	|	TableInventory.CustomerOrder,
	|	TableInventory.InventoryGLAccount";
	
	Query.SetParameter("InventoryReceipt", NStr("en='Inventory receiving';ru='Прием запасов'"));
	Query.SetParameter("InventoryWriteOff", NStr("en='Inventory write off';ru='Списание запасов'"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
	GenerateTableInventorySale(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	
EndProcedure // GenerateTableInventory()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventorySale(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT DISTINCT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.CustomerOrder AS CustomerOrder
	|FROM
	|	TemporaryTableInventory AS TableInventory";
	
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
	|		VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.InventoryGLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						VALUE(Document.CustomerOrder.EmptyRef)
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch
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
	
	Query.SetParameter("Ref", DocumentRefReportOnRetailSales);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch,CustomerOrder");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	
	For Ct = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[Ct];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("ProductsAndServices", RowTableInventory.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
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
			
			If RowTableInventory.ProductsOnCommission Then
				
				TableRowExpense.ContentOfAccountingRecord = Undefined;
				
			ElsIf Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Generate postings.
				RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerial, RowTableInventory);
				RowTableManagerial.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
				RowTableManagerial.Amount = AmountToBeWrittenOff;
				
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.StructuralUnit = RowTableInventory.Department;
				RowIncomeAndExpenses.GLAccount = RowTableInventory.AccountDr;
				
				RowIncomeAndExpenses.AmountIncome = 0;
				RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
				RowIncomeAndExpenses.Amount = AmountToBeWrittenOff;
				
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en='Costs reflection';ru='Отражение расходов'");
				
			EndIf;
			
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Sales.
				SaleString = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
				FillPropertyValues(SaleString, RowTableInventory);
				SaleString.Quantity = 0;
				SaleString.Amount = 0;
				SaleString.VATAmount = 0;
				SaleString.Cost = AmountToBeWrittenOff;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure // GenerateTableInventorySale()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Date AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.ProductsAndServices AS ProductsAndServices,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	TableSales.CustomerOrder AS CustomerOrder,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.Department AS Department,
	|	TableSales.Responsible AS Responsible,
	|	SUM(TableSales.Quantity) AS Quantity,
	|	SUM(TableSales.AmountVATPurchaseSale) AS VATAmount,
	|	SUM(TableSales.Amount) AS Amount,
	|	0 AS Cost
	|FROM
	|	TemporaryTableInventory AS TableSales
	|WHERE
	|	&CompletePosting
	|
	|GROUP BY
	|	TableSales.Date,
	|	TableSales.Company,
	|	TableSales.ProductsAndServices,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.CustomerOrder,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.Department,
	|	TableSales.Responsible";
	
	Query.SetParameter("CompletePosting", StructureAdditionalProperties.ForPosting.CompletePosting);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure // GenerateTableSales()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventoryInWarehouses.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventoryInWarehouses.Date AS Period,
	|	TableInventoryInWarehouses.Company AS Company,
	|	TableInventoryInWarehouses.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryInWarehouses.Characteristic AS Characteristic,
	|	TableInventoryInWarehouses.Batch AS Batch,
	|	TableInventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	TableInventoryInWarehouses.Cell AS Cell,
	|	SUM(TableInventoryInWarehouses.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventoryInWarehouses
	|WHERE
	|	TableInventoryInWarehouses.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	AND &CompletePosting
	|
	|GROUP BY
	|	TableInventoryInWarehouses.Date,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.ProductsAndServices,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell";
	
	Query.SetParameter("CompletePosting", StructureAdditionalProperties.ForPosting.CompletePosting);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryInWarehouses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryReceived(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventoryReceived.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventoryReceived.Date AS Period,
	|	TableInventoryReceived.Company AS Company,
	|	TableInventoryReceived.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryReceived.Characteristic AS Characteristic,
	|	TableInventoryReceived.Batch AS Batch,
	|	UNDEFINED AS Counterparty,
	|	UNDEFINED AS Contract,
	|	UNDEFINED AS Order,
	|	VALUE(Enum.ProductsReceiptTransferTypes.ReportToPrincipal) AS ReceptionTransmissionType,
	|	SUM(TableInventoryReceived.Quantity) AS Quantity,
	|	0 AS SettlementsAmount,
	|	CAST(&InventoryReceiptProductsOnCommission AS String(100)) AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableInventory AS TableInventoryReceived
	|WHERE
	|	TableInventoryReceived.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	AND TableInventoryReceived.ProductsOnCommission
	|
	|GROUP BY
	|	TableInventoryReceived.Date,
	|	TableInventoryReceived.Company,
	|	TableInventoryReceived.ProductsAndServices,
	|	TableInventoryReceived.Characteristic,
	|	TableInventoryReceived.Batch
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("InventoryReceiptProductsOnCommission", NStr("en='Sale of commission goods';ru='Реализация комиссионных товаров'"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryReceived", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryReceived()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	TableIncomeAndExpenses.LineNumber AS LineNumber,
	|	TableIncomeAndExpenses.Date AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.Department AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessActivity AS BusinessActivity,
	|	TableIncomeAndExpenses.CustomerOrder AS CustomerOrder,
	|	TableIncomeAndExpenses.GLAccountRevenueFromSales AS GLAccount,
	|	CAST(&IncomeReflection AS String(100)) AS ContentOfAccountingRecord,
	//( elmi #11
	//|	SUM(TableIncomeAndExpenses.Amount) AS AmountIncome,
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS AmountIncome,         
	|	0 AS AmountExpense,
	//|	SUM(TableIncomeAndExpenses.Amount) AS Amount
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS Amount               
	//) elmi
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|WHERE
	|	(NOT TableIncomeAndExpenses.ProductsOnCommission)
	|	AND &CompletePosting
	|	AND TableIncomeAndExpenses.Amount <> 0
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Date,
	|	TableIncomeAndExpenses.LineNumber,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.Department,
	|	TableIncomeAndExpenses.BusinessActivity,
	|	TableIncomeAndExpenses.CustomerOrder,
	|	TableIncomeAndExpenses.GLAccountRevenueFromSales
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
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
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS DocumentTable
	|WHERE
	|	&CompletePosting
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	Query.SetParameter("IncomeReflection", NStr("en='Income accounting';ru='Отражение доходов'"));
	Query.SetParameter("CompletePosting", StructureAdditionalProperties.ForPosting.CompletePosting);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefReportOnRetailSales);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.BusinessActivity AS BusinessActivity,
	|	DocumentTable.Item AS Item,
	//( elmi #11
	//|	DocumentTable.Amount AS AmountIncome
	|	DocumentTable.Amount - DocumentTable.VATAmount AS AmountIncome
	//) elmi
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Amount <> 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesCashMethod()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssetsInCashRegisters(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentData.Date AS Date,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentData.Company AS Company,
	|	DocumentData.CashCR AS CashCR,
	|	DocumentData.CashCRGLAccount AS GLAccount,
	|	DocumentData.DocumentCurrency AS Currency,
	|	SUM(DocumentData.Amount) AS Amount,
	|	SUM(DocumentData.AmountCur) AS AmountCur,
	|	SUM(DocumentData.Amount) AS AmountForBalance,
	|	SUM(DocumentData.AmountCur) AS AmountCurForBalance,
	|	CAST(&CashFundsReceipt AS String(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableCashAssetsInRetailCashes
	|FROM
	|	TemporaryTableInventory AS DocumentData
	|WHERE
	|	&CompletePosting
	|	AND DocumentData.Amount <> 0
	|
	|GROUP BY
	|	DocumentData.Date,
	|	DocumentData.Company,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	DocumentData.Date,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentData.Company,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency,
	|	SUM(DocumentData.Amount),
	|	SUM(DocumentData.AmountCur),
	|	-SUM(DocumentData.Amount),
	|	-SUM(DocumentData.AmountCur),
	|	CAST(&PaymentWithPaymentCards AS String(100))
	|FROM
	|	TemporaryTablePaymentCards AS DocumentData
	|WHERE
	|	&CompletePosting
	|
	|GROUP BY
	|	DocumentData.Date,
	|	DocumentData.Company,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency
	|
	|INDEX BY
	|	Company,
	|	CashCR,
	|	Currency,
	|	GLAccount";
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref", DocumentRefReportOnRetailSales);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("CompletePosting", StructureAdditionalProperties.ForPosting.CompletePosting);
	Query.SetParameter("CashFundsReceipt", NStr("en='Cash receipt to the cash registers';ru='Поступление денежных средств в кассу ККМ'"));
	Query.SetParameter("PaymentWithPaymentCards", NStr("en='Payment by cards';ru='Оплата платежными картами'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTableCashAssetsInRetailCashes.Company AS Company,
	|	TemporaryTableCashAssetsInRetailCashes.CashCR AS CashCR
	|FROM
	|	TemporaryTableCashAssetsInRetailCashes AS TemporaryTableCashAssetsInRetailCashes";
	
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
Procedure GenerateTableManagerial(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	//( elmi #11
    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
	|	Sum(TemporaryTable.VATAmount) AS VATInventory ,
	|	Sum(TemporaryTable.VATAmountCur) AS VATInventoryCur 
	|FROM
	|	TemporaryTableInventory AS TemporaryTable
	|GROUP BY
	|TemporaryTable.Date,
	|TemporaryTable.Company	";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	VATInventory = 0;
	VATInventoryCur = 0;
	
	While Selection.Next() Do  
		  VATInventory    = Selection.VATInventory;
	      VATInventoryCur = Selection.VATInventoryCur;
	EndDo;
    //) elmi
	
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Date AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableManagerial.CashCRGLAccount AS AccountDr,
	|	CASE
	|		WHEN TableManagerial.CashCRGLAccount.Currency
	|			THEN TableManagerial.DocumentCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableManagerial.CashCRGLAccount.Currency
	//( elmi #11
	//|			THEN TableManagerial.AmountCur
	|			THEN TableManagerial.AmountCur - TableManagerial.VATAmountCur
	//) elmi
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN TableManagerial.ProductsOnCommission
	|			THEN VALUE(ChartOfAccounts.Managerial.AccountsPayable)
	|		ELSE TableManagerial.GLAccountRevenueFromSales
	|	END AS AccountCr,
	|	CASE
	|		WHEN TableManagerial.ProductsOnCommission
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableManagerial.ProductsOnCommission
	//( elmi #11
	//|			THEN TableManagerial.Amount
	|			THEN TableManagerial.Amount - TableManagerial.VATAmount                          
	//) elmi
	|		ELSE 0
	|	END AS AmountCurCr,
	//( elmi #11
	//|	TableManagerial.Amount AS Amount,
	|	TableManagerial.Amount - TableManagerial.VATAmount   AS Amount,                          
	//) elmi
	|	&IncomeReflection AS Content
	|FROM
	|	TemporaryTableInventory AS TableManagerial
	|WHERE
	|	&CompletePosting
	|	AND TableManagerial.Amount <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableManagerial.LineNumber,
	|	TableManagerial.Date,
	|	TableManagerial.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableManagerial.POSTerminalGlAccount,
	|	CASE
	|		WHEN TableManagerial.POSTerminalGlAccount.Currency
	|			THEN TableManagerial.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableManagerial.POSTerminalGlAccount.Currency
	|			THEN TableManagerial.AmountCur
	|		ELSE 0
	|	END,
	|	TableManagerial.CashCRGLAccount,
	|	CASE
	|		WHEN TableManagerial.CashCRGLAccount.Currency
	|			THEN TableManagerial.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableManagerial.CashCRGLAccount.Currency
	|			THEN TableManagerial.AmountCur
	|		ELSE 0
	|	END,
	|	TableManagerial.Amount,
	|	&ReflectionOfPaymentByCards
	|FROM
	|	TemporaryTablePaymentCards AS TableManagerial
	|WHERE
	|	&CompletePosting
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TableManagerial.LineNumber,
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
	|				AND TableManagerial.GLAccount.Currency
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
	|				AND TableManagerial.GLAccount.Currency
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
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS TableManagerial
	|WHERE
	|	&CompletePosting
	|
	//( elmi #11
	|UNION ALL
	|
	|SELECT TOP 1
	|	4 AS Order,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Date AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableManagerial.CashCRGLAccount AS AccountDr,
	|	CASE
	|		WHEN TableManagerial.CashCRGLAccount.Currency
	|			THEN TableManagerial.DocumentCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableManagerial.CashCRGLAccount.Currency
	|			THEN  &VATInventoryCur
	|		ELSE 0
	|	END AS AmountCurDr,
    |   &TextVAT,
	|   UNDEFINED,
	|	0,
	|	&VATInventory,                      
 	|	&VAT AS Content
	|FROM
	|	TemporaryTableInventory AS TableManagerial
	|WHERE
	|	&CompletePosting  AND &VATInventory > 0
	|
    //) elmi
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	Query.SetParameter("IncomeReflection", NStr("en='Sales revenue';ru='Выручка от продажи'"));
	Query.SetParameter("ReflectionOfPaymentByCards", NStr("en='Payment by cards';ru='Оплата платежными картами'"));
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	Query.SetParameter("CompletePosting", StructureAdditionalProperties.ForPosting.CompletePosting);
	//( elmi #11
	Query.SetParameter("VAT", NStr("en=' VAT '"));
	Query.SetParameter("TextVAT",  ChartsOfAccounts.Managerial.Taxes);
	Query.SetParameter("VATInventoryCur", VATInventoryCur);
	Query.SetParameter("VATInventory", VATInventory);
	//) elmi
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do  
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure // GenerateTableManagerial()

#Region DiscountCards

// Generates values table containing data for posting on the SalesByDiscountCard register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByDiscountCard(DocumentRefReportOnRetailSales, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Date AS Period,
	|	TableSales.DiscountCard AS DiscountCard,
	|	TableSales.CardOwner AS CardOwner,
	|	SUM(TableSales.Amount) AS Amount
	|FROM
	|	TemporaryTableInventory AS TableSales
	|WHERE
	|	&CompletePosting
	|	AND TableSales.DiscountCard <> VALUE(Catalog.DiscountCards.EmptyRef)
	|
	|GROUP BY
	|	TableSales.Date,
	|	TableSales.DiscountCard,
	|	TableSales.CardOwner";
	
	Query.SetParameter("CompletePosting", StructureAdditionalProperties.ForPosting.CompletePosting);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("SaleByDiscountCardTable", QueryResult.Unload());
	
EndProcedure // GenerateTableSalesByDiscountCard()

#EndRegion

#Region AutomaticDiscounts

// Generates a table of values that contains the data for posting by the register AutomaticDiscountsApplied.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
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
	|	TemporaryTableAutoDiscountsMarkups.ProductsAndServices,
	|	TemporaryTableAutoDiscountsMarkups.Characteristic,
	|	TemporaryTableAutoDiscountsMarkups.Document AS DocumentDiscounts,
	|	TemporaryTableAutoDiscountsMarkups.StructuralUnit AS RecipientDiscounts
	|FROM
	|	TemporaryTableAutoDiscountsMarkups AS TemporaryTableAutoDiscountsMarkups
	|WHERE
	|	&CompletePosting";
	
	Query.SetParameter("CompletePosting", StructureAdditionalProperties.ForPosting.CompletePosting);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", QueryResult.Unload());
	
EndProcedure // GenerateTableSalesByAutomaticDiscountsApplied()

#EndRegion

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefReportOnRetailSales, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	RetailSalesReportInventory.LineNumber AS LineNumber,
	|	RetailSalesReportInventory.ConnectionKey AS ConnectionKey,
	|	RetailSalesReportInventory.Ref AS Document,
	|	RetailSalesReportInventory.Ref.InventoryReconciliation AS BasisDocument,
	|	RetailSalesReportInventory.Ref.Item AS Item,
	|	RetailSalesReportInventory.Ref.DocumentCurrency AS DocumentCurrency,
	|	RetailSalesReportInventory.Ref.Date AS Date,
	|	RetailSalesReportInventory.Ref.CashCR AS CashCR,
	|	RetailSalesReportInventory.Ref.CashCR.Owner AS CashCROwner,
	|	RetailSalesReportInventory.Ref.CashCR.GLAccount AS CashCRGLAccount,
	|	&Company AS Company,
	|	VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder,
	|	RetailSalesReportInventory.Ref.Department AS Department,
	|	RetailSalesReportInventory.Responsible AS Responsible,
	|	RetailSalesReportInventory.ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|	RetailSalesReportInventory.ProductsAndServices.BusinessActivity AS BusinessActivity,
	|	RetailSalesReportInventory.ProductsAndServices.BusinessActivity.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
	|	RetailSalesReportInventory.ProductsAndServices.BusinessActivity.GLAccountCostOfSales AS GLAccountCostOfSales,
	|	RetailSalesReportInventory.Ref.StructuralUnit AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	UNDEFINED AS Cell,
	|	RetailSalesReportInventory.ProductsAndServices.InventoryGLAccount AS InventoryGLAccount,
	|	RetailSalesReportInventory.ProductsAndServices.ExpensesGLAccount AS ExpensesGLAccount,
	|	UNDEFINED AS CorrespondentAccountAccountingInventory,
	|	CASE
	|		WHEN &UseBatches
	|				AND RetailSalesReportInventory.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsOnCommission,
	|	RetailSalesReportInventory.ProductsAndServices AS ProductsAndServices,
	|	UNDEFINED AS ProductsAndServicesCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN RetailSalesReportInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN RetailSalesReportInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN RetailSalesReportInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN &UseBatches
	|			THEN RetailSalesReportInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS BatchCorr,
	|	CASE
	|		WHEN VALUETYPE(RetailSalesReportInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN RetailSalesReportInventory.Quantity
	|		ELSE RetailSalesReportInventory.Quantity * RetailSalesReportInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	RetailSalesReportInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN RetailSalesReportInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE RetailSalesReportInventory.VATAmount * DocCurrencyCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * DocCurrencyCurrencyRates.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(RetailSalesReportInventory.VATAmount * DocCurrencyCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * DocCurrencyCurrencyRates.Multiplicity) AS NUMBER(15, 2)) AS AmountVATPurchaseSale,
	|	CAST(RetailSalesReportInventory.Total * DocCurrencyCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * DocCurrencyCurrencyRates.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	CAST(RetailSalesReportInventory.VATAmount AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(RetailSalesReportInventory.Total AS NUMBER(15, 2)) AS AmountCur,
	|	RetailSalesReportInventory.Total AS SettlementsAmountTakenPassed,
	|	RetailSalesReportInventory.DiscountCard,
	|	RetailSalesReportInventory.DiscountCard.CardOwner AS CardOwner
	|INTO TemporaryTableInventory
	|FROM
	|	Document.RetailReport.Inventory AS RetailSalesReportInventory
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS ManagCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS DocCurrencyCurrencyRates
	|		ON RetailSalesReportInventory.Ref.DocumentCurrency = DocCurrencyCurrencyRates.Currency
	|WHERE
	|	RetailSalesReportInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TabularSection.LineNumber AS LineNumber,
	|	TabularSection.Ref.Date AS Date,
	|	&Ref AS Document,
	|	&Company AS Company,
	|	TabularSection.Ref.CashCR AS CashCR,
	|	TabularSection.Ref.CashCR.GLAccount AS CashCRGLAccount,
	|	TabularSection.POSTerminal.GLAccount AS POSTerminalGlAccount,
	|	TabularSection.Ref.DocumentCurrency AS DocumentCurrency,
	|	CAST(TabularSection.Amount * CurrencyRatesOfPettyCashe.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	TabularSection.Amount AS AmountCur
	|INTO TemporaryTablePaymentCards
	|FROM
	|	Document.RetailReport.PaymentWithPaymentCards AS TabularSection
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfPettyCashe
	|		ON TabularSection.Ref.DocumentCurrency = CurrencyRatesOfPettyCashe.Currency
	|WHERE
	|	TabularSection.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RetailSalesReportDiscountsMarkups.DiscountMarkup,
	|	CAST(CASE
	|			WHEN RetailSalesReportDiscountsMarkups.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN RetailSalesReportDiscountsMarkups.Amount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE RetailSalesReportDiscountsMarkups.Amount * ManagCurrencyRates.Multiplicity / ManagCurrencyRates.ExchangeRate
	|		END AS NUMBER(15, 2)) AS Amount,
	|	RetailSalesReportDiscountsMarkups.Ref.Date AS Period,
	|	RetailSalesReportDiscountsMarkups.ProductsAndServices,
	|	RetailSalesReportDiscountsMarkups.Characteristic,
	|	RetailSalesReportDiscountsMarkups.Ref AS Document,
	|	RetailSalesReportDiscountsMarkups.Ref.StructuralUnit AS StructuralUnit
	|INTO TemporaryTableAutoDiscountsMarkups
	|FROM
	|	Document.RetailReport.DiscountsMarkups AS RetailSalesReportDiscountsMarkups
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
	|	RetailSalesReportDiscountsMarkups.Ref = &Ref
	|	AND RetailSalesReportDiscountsMarkups.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RetailReportSerialNumbers.ConnectionKey,
	|	RetailReportSerialNumbers.SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.RetailReport.SerialNumbers AS RetailReportSerialNumbers
	|WHERE
	|	RetailReportSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	Query.SetParameter("Ref", DocumentRefReportOnRetailSales);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	SmallBusinessServer.GenerateTransactionsTable(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	
	GenerateTableInventoryInWarehouses(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	GenerateTableCashAssetsInCashRegisters(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	GenerateTableSales(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	GenerateTableInventoryReceived(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	
	GenerateTableManagerial(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	
	// DiscountCards
	GenerateTableSalesByDiscountCard(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	// AutomaticDiscounts
	GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefReportOnRetailSales, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Generates a table of values that contains the data for the SerialNumbersGuarantees information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersGuarantees", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableInventory.Date AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.ProductsAndServices AS ProductsAndServices,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	TemporaryTableInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableInventory.Cell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey";
	
	QueryResult = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersGuarantees", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf; 
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefReportOnRetailSales, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", control goods implementation.
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryReceivedChange
	 OR StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryInWarehousesChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.ProductsAndServices AS ProductsAndServicesPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Cell AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryInWarehousesOfBalance.ProductsAndServices.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		INNER JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, ProductsAndServices, Characteristic, Batch, Cell) IN
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
		|			AND (ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryChange.GLAccount AS GLAccountPresentation,
		|	RegisterRecordsInventoryChange.ProductsAndServices AS ProductsAndServicesPresentation,
		|	RegisterRecordsInventoryChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryChange.CustomerOrder AS CustomerOrderPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryBalances.ProductsAndServices.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		INNER JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) IN
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
		|			AND (ISNULL(InventoryBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryReceivedChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryReceivedChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryReceivedChange.ProductsAndServices AS ProductsAndServicesPresentation,
		|	RegisterRecordsInventoryReceivedChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryReceivedChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryReceivedChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsInventoryReceivedChange.Contract AS ContractPresentation,
		|	RegisterRecordsInventoryReceivedChange.Order AS OrderPresentation,
		|	RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType AS ReceptionTransmissionTypePresentation,
		|	InventoryReceivedBalances.ProductsAndServices.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryReceivedChange.QuantityChange, 0) + ISNULL(InventoryReceivedBalances.QuantityBalance, 0) AS BalanceInventoryReceived,
		|	ISNULL(InventoryReceivedBalances.QuantityBalance, 0) AS QuantityBalanceInventoryReceived,
		|	ISNULL(RegisterRecordsInventoryReceivedChange.SettlementsAmountChange, 0) + ISNULL(InventoryReceivedBalances.SettlementsAmountBalance, 0) AS SettlementsAmountInventoryReceived,
		|	ISNULL(InventoryReceivedBalances.SettlementsAmountBalance, 0) AS SettlementsAmountBalanceInventoryReceived
		|FROM
		|	RegisterRecordsInventoryReceivedChange AS RegisterRecordsInventoryReceivedChange
		|		INNER JOIN AccumulationRegister.InventoryReceived.Balance(
		|				&ControlTime,
		|				(Company, ProductsAndServices, Characteristic, Batch, Counterparty, Contract, Order, ReceptionTransmissionType) IN
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
		|			AND (ISNULL(InventoryReceivedBalances.QuantityBalance, 0) < 0
		|				OR ISNULL(InventoryReceivedBalances.SettlementsAmountBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSerialNumbersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSerialNumbersChange.SerialNumber AS SerialNumberPresentation,
		|	RegisterRecordsSerialNumbersChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsSerialNumbersChange.ProductsAndServices AS ProductsAndServicesPresentation,
		|	RegisterRecordsSerialNumbersChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsSerialNumbersChange.Batch AS BatchPresentation,
		|	RegisterRecordsSerialNumbersChange.Cell AS PresentationCell,
		|	SerialNumbersBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	SerialNumbersBalance.ProductsAndServices.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSerialNumbersChange.QuantityChange, 0) + ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceSerialNumbers,
		|	ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceQuantitySerialNumbers
		|FROM
		|	RegisterRecordsSerialNumbersChange AS RegisterRecordsSerialNumbersChange
		|		INNER JOIN AccumulationRegister.SerialNumbers.Balance(&ControlTime, ) AS SerialNumbersBalance
		|		ON RegisterRecordsSerialNumbersChange.StructuralUnit = SerialNumbersBalance.StructuralUnit
		|			AND RegisterRecordsSerialNumbersChange.ProductsAndServices = SerialNumbersBalance.ProductsAndServices
		|			AND RegisterRecordsSerialNumbersChange.Characteristic = SerialNumbersBalance.Characteristic
		|			AND RegisterRecordsSerialNumbersChange.Batch = SerialNumbersBalance.Batch
		|			AND RegisterRecordsSerialNumbersChange.SerialNumber = SerialNumbersBalance.SerialNumber
		|			AND RegisterRecordsSerialNumbersChange.Cell = SerialNumbersBalance.Cell
		|			AND (ISNULL(SerialNumbersBalance.QuantityBalance, 0) < 0)
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
			DocumentRetailReport = DocumentRefReportOnRetailSales.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentRetailReport, QueryResultSelection, Cancel);
		EndIf;

		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentRetailReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryReceivedRegisterErrors(DocumentRetailReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If NOT ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			SmallBusinessServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentRetailReport, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure // RunControl()

//////////////////////////////////////////////////////////////////////////////
// SHIFT OPENING AND CLOSING PROCEDURE

// Function opens petty cash shift.
//
Function CashCRSessionOpen(CashCR, ErrorDescription = "") Export
	
	CompletedSuccessfully = True;
	
	StructureStateCashCRSession = GetCashCRSessionStatus(CashCR);
	
	OpeningDateOfCashCRSession = CurrentDate();
	
	If StructureStateCashCRSession.CashCRSessionStatus = Enums.CashCRSessionStatuses.IsOpen Then
		
		// If shift is opened, then since the opening there must be not more than 24 hours.
		If OpeningDateOfCashCRSession - StructureStateCashCRSession.StatusModificationDate < 86400 Then
			
			// Everything is OK
			
		Else
			
			CompletedSuccessfully = False;
			// Shift may not have been closed.
			ErrorDescription = NStr("en='More than 24 hours have passed since the opening. It is required to close petty cash shift.';ru='С момента открытия кассовой смены истекло более 24 часов. Необходимо выполнить закрытие кассовой смены.'");
			
		EndIf;
		
	Else
		
		// Shift is closed. Open new petty cash shift.
		
		NewCashCRSession = Documents.RetailReport.CreateDocument();
		NewCashCRSession.Author = Users.CurrentUser();
		NewCashCRSession.Fill(New Structure("CashCR", CashCR));
		
		NewCashCRSession.Date                   = OpeningDateOfCashCRSession;
		NewCashCRSession.CashCRSessionStatus    = Enums.CashCRSessionStatuses.IsOpen;
		NewCashCRSession.CashCRSessionStart    = OpeningDateOfCashCRSession;
		NewCashCRSession.CashCRSessionEnd = '00010101';
		
		If NewCashCRSession.CheckFilling() Then
			NewCashCRSession.Write(DocumentWriteMode.Posting);
		Else
			CompletedSuccessfully = False;
			ErrorDescription = NStr("en='Verify the retail warehouse and cash register settings.';ru='Проверьте настройки розничного склада и кассы ККМ.'");
		EndIf;
		
	EndIf;
	
	Return CompletedSuccessfully;
	
EndFunction // OpenCashCRSession()

// Function closes petty cash shift.
//
Function CloseCashCRSession(ObjectCashCRSession) Export
	
	StructureReturns = New Structure;
	StructureReturns.Insert("RetailReport");
	StructureReturns.Insert("ErrorDescription");
	
	BeginTransaction();
	
	Try
		
		TempTablesManager = New TempTablesManager;
		
		// Data preparation.
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ReceiptCRInventory.ProductsAndServices AS ProductsAndServices,
		|	ReceiptCRInventory.Characteristic AS Characteristic,
		|	ReceiptCRInventory.Batch AS Batch,
		|	SUM(ReceiptCRInventory.Quantity) AS Quantity,
		|	ReceiptCRInventory.MeasurementUnit AS MeasurementUnit,
		|	ReceiptCRInventory.Price AS Price,
		|	CASE
		|		WHEN &UseAutomaticDiscounts
		|			THEN ReceiptCRInventory.DiscountMarkupPercent + ReceiptCRInventory.AutomaticDiscountsPercent
		|		ELSE ReceiptCRInventory.DiscountMarkupPercent
		|	END AS DiscountMarkupPercent,
		|	ReceiptCRInventory.VATRate AS VATRate,
		|	SUM(ReceiptCRInventory.Amount) AS Amount,
		|	SUM(ReceiptCRInventory.VATAmount) AS VATAmount,
		|	SUM(ReceiptCRInventory.Total) AS Total,
		|	ReceiptCRInventory.StructuralUnit AS StructuralUnit,
		|	ReceiptCRInventory.DocumentCurrency AS DocumentCurrency,
		|	ReceiptCRInventory.PriceKind AS PriceKind,
		|	ReceiptCRInventory.CashCR AS CashCR,
		|	ReceiptCRInventory.Department AS Department,
		|	ReceiptCRInventory.Responsible AS Responsible,
		|	ReceiptCRInventory.Company AS Company,
		|	ReceiptCRInventory.DiscountCard AS DiscountCard,
		|	ReceiptCRInventory.AutomaticDiscountsPercent,
		|	SUM(ReceiptCRInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount
		|FROM
		|	(SELECT
		|		ReceiptCRInventory.ProductsAndServices AS ProductsAndServices,
		|		ReceiptCRInventory.Characteristic AS Characteristic,
		|		ReceiptCRInventory.Batch AS Batch,
		|		ReceiptCRInventory.Quantity AS Quantity,
		|		ReceiptCRInventory.MeasurementUnit AS MeasurementUnit,
		|		ReceiptCRInventory.Price AS Price,
		|		ReceiptCRInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
		|		ReceiptCRInventory.VATRate AS VATRate,
		|		ReceiptCRInventory.Amount AS Amount,
		|		ReceiptCRInventory.VATAmount AS VATAmount,
		|		ReceiptCRInventory.Total AS Total,
		|		ReceiptCRInventory.Ref.StructuralUnit AS StructuralUnit,
		|		ReceiptCRInventory.Ref.DocumentCurrency AS DocumentCurrency,
		|		ReceiptCRInventory.Ref.PriceKind AS PriceKind,
		|		ReceiptCRInventory.Ref.CashCR AS CashCR,
		|		ReceiptCRInventory.Ref.Department AS Department,
		|		ReceiptCRInventory.Ref.Responsible AS Responsible,
		|		ReceiptCRInventory.Ref.Company AS Company,
		|		ReceiptCRInventory.Ref.DiscountCard AS DiscountCard,
		|		ReceiptCRInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
		|		ReceiptCRInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount
		|	FROM
		|		Document.ReceiptCR.Inventory AS ReceiptCRInventory
		|	WHERE
		|		ReceiptCRInventory.Ref.CashCRSession = &CashCRSession
		|		AND ReceiptCRInventory.Ref.Posted
		|		AND ReceiptCRInventory.Ref.ReceiptCRNumber > 0
		|		AND NOT ReceiptCRInventory.Ref.Archival
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ReceiptCRInventory.ProductsAndServices,
		|		ReceiptCRInventory.Characteristic,
		|		ReceiptCRInventory.Batch,
		|		-ReceiptCRInventory.Quantity,
		|		ReceiptCRInventory.MeasurementUnit,
		|		ReceiptCRInventory.Price,
		|		ReceiptCRInventory.DiscountMarkupPercent,
		|		ReceiptCRInventory.VATRate,
		|		-ReceiptCRInventory.Amount,
		|		-ReceiptCRInventory.VATAmount,
		|		-ReceiptCRInventory.Total,
		|		ReceiptCRInventory.Ref.StructuralUnit,
		|		ReceiptCRInventory.Ref.DocumentCurrency,
		|		ReceiptCRInventory.Ref.PriceKind,
		|		ReceiptCRInventory.Ref.CashCR,
		|		ReceiptCRInventory.Ref.Department,
		|		ReceiptCRInventory.Ref.Responsible,
		|		ReceiptCRInventory.Ref.Company,
		|		ReceiptCRInventory.Ref.DiscountCard,
		|		ReceiptCRInventory.AutomaticDiscountsPercent,
		|		-ReceiptCRInventory.AutomaticDiscountAmount
		|	FROM
		|		Document.ReceiptCRReturn.Inventory AS ReceiptCRInventory
		|	WHERE
		|		ReceiptCRInventory.Ref.CashCRSession = &CashCRSession
		|		AND ReceiptCRInventory.Ref.Posted
		|		AND ReceiptCRInventory.Ref.ReceiptCRNumber > 0
		|		AND NOT ReceiptCRInventory.Ref.Archival) AS ReceiptCRInventory
		|
		|GROUP BY
		|	ReceiptCRInventory.ProductsAndServices,
		|	ReceiptCRInventory.Characteristic,
		|	ReceiptCRInventory.Batch,
		|	ReceiptCRInventory.MeasurementUnit,
		|	ReceiptCRInventory.Price,
		|	ReceiptCRInventory.DiscountMarkupPercent,
		|	ReceiptCRInventory.StructuralUnit,
		|	ReceiptCRInventory.DocumentCurrency,
		|	ReceiptCRInventory.PriceKind,
		|	ReceiptCRInventory.CashCR,
		|	ReceiptCRInventory.Company,
		|	ReceiptCRInventory.Department,
		|	ReceiptCRInventory.Responsible,
		|	ReceiptCRInventory.VATRate,
		|	ReceiptCRInventory.DiscountCard,
		|	ReceiptCRInventory.AutomaticDiscountsPercent,
		|	CASE
		|		WHEN &UseAutomaticDiscounts
		|			THEN ReceiptCRInventory.DiscountMarkupPercent + ReceiptCRInventory.AutomaticDiscountsPercent
		|		ELSE ReceiptCRInventory.DiscountMarkupPercent
		|	END
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PaymentWithPaymentCards.POSTerminal AS POSTerminal,
		|	PaymentWithPaymentCards.ChargeCardKind AS ChargeCardKind,
		|	PaymentWithPaymentCards.ChargeCardNo AS ChargeCardNo,
		|	SUM(PaymentWithPaymentCards.Amount) AS Amount
		|FROM
		|	(SELECT
		|		ReceiptCRPaymentWithPaymentCards.Ref.POSTerminal AS POSTerminal,
		|		ReceiptCRPaymentWithPaymentCards.ChargeCardKind AS ChargeCardKind,
		|		ReceiptCRPaymentWithPaymentCards.ChargeCardNo AS ChargeCardNo,
		|		ReceiptCRPaymentWithPaymentCards.Amount AS Amount,
		|		ReceiptCRPaymentWithPaymentCards.Ref.CashCR AS CashCR,
		|		ReceiptCRPaymentWithPaymentCards.Ref.Company AS Company,
		|		ReceiptCRPaymentWithPaymentCards.Ref.StructuralUnit AS Warehouse,
		|		ReceiptCRPaymentWithPaymentCards.Ref.DocumentCurrency AS Currency,
		|		ReceiptCRPaymentWithPaymentCards.Ref.PriceKind AS PriceKind
		|	FROM
		|		Document.ReceiptCR.PaymentWithPaymentCards AS ReceiptCRPaymentWithPaymentCards
		|	WHERE
		|		ReceiptCRPaymentWithPaymentCards.Ref.CashCRSession = &CashCRSession
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ReceiptsCRReturnPaymentWithPaymentCards.Ref.POSTerminal,
		|		ReceiptsCRReturnPaymentWithPaymentCards.ChargeCardKind,
		|		ReceiptsCRReturnPaymentWithPaymentCards.ChargeCardNo,
		|		-ReceiptsCRReturnPaymentWithPaymentCards.Amount,
		|		ReceiptsCRReturnPaymentWithPaymentCards.Ref.CashCR,
		|		ReceiptsCRReturnPaymentWithPaymentCards.Ref.Company,
		|		ReceiptsCRReturnPaymentWithPaymentCards.Ref.StructuralUnit,
		|		ReceiptsCRReturnPaymentWithPaymentCards.Ref.DocumentCurrency,
		|		ReceiptsCRReturnPaymentWithPaymentCards.Ref.PriceKind
		|	FROM
		|		Document.ReceiptCRReturn.PaymentWithPaymentCards AS ReceiptsCRReturnPaymentWithPaymentCards
		|	WHERE
		|		ReceiptsCRReturnPaymentWithPaymentCards.Ref.CashCRSession = &CashCRSession) AS PaymentWithPaymentCards
		|
		|GROUP BY
		|	PaymentWithPaymentCards.POSTerminal,
		|	PaymentWithPaymentCards.ChargeCardKind,
		|	PaymentWithPaymentCards.ChargeCardNo
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	COUNT(DISTINCT ReceiptCRInventory.Responsible) AS CountResponsible
		|FROM
		|	(SELECT
		|		ReceiptCRInventory.Ref.Responsible AS Responsible
		|	FROM
		|		Document.ReceiptCR.Inventory AS ReceiptCRInventory
		|	WHERE
		|		ReceiptCRInventory.Ref.CashCRSession = &CashCRSession
		|		AND ReceiptCRInventory.Ref.Posted
		|		AND ReceiptCRInventory.Ref.ReceiptCRNumber > 0
		|		AND NOT ReceiptCRInventory.Ref.Archival
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ReceiptCRInventory.Ref.Responsible
		|	FROM
		|		Document.ReceiptCRReturn.Inventory AS ReceiptCRInventory
		|	WHERE
		|		ReceiptCRInventory.Ref.CashCRSession = &CashCRSession
		|		AND ReceiptCRInventory.Ref.Posted
		|		AND ReceiptCRInventory.Ref.ReceiptCRNumber > 0
		|		AND NOT ReceiptCRInventory.Ref.Archival) AS ReceiptCRInventory
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ReceiptCRInventory.ProductsAndServices,
		|	ReceiptCRInventory.Characteristic,
		|	ReceiptCRDiscountsMarkups.DiscountMarkup,
		|	ReceiptCRDiscountsMarkups.Amount
		|INTO TU_AutoDiscountsMarkupsJoin
		|FROM
		|	Document.ReceiptCR.Inventory AS ReceiptCRInventory
		|		INNER JOIN Document.ReceiptCR.DiscountsMarkups AS ReceiptCRDiscountsMarkups
		|		ON ReceiptCRInventory.ConnectionKey = ReceiptCRDiscountsMarkups.ConnectionKey
		|			AND (ReceiptCRInventory.Ref.CashCRSession = &CashCRSession)
		|			AND (ReceiptCRInventory.Ref.Posted)
		|			AND (ReceiptCRInventory.Ref.ReceiptCRNumber > 0)
		|			AND (NOT ReceiptCRInventory.Ref.Archival)
		|			AND ReceiptCRInventory.Ref = ReceiptCRDiscountsMarkups.Ref
		|
		|UNION ALL
		|
		|SELECT
		|	ReceiptCRReturnInventory.ProductsAndServices,
		|	ReceiptCRReturnInventory.Characteristic,
		|	CRReceiptReturnDiscountsMarkups.DiscountMarkup,
		|	-CRReceiptReturnDiscountsMarkups.Amount
		|FROM
		|	Document.ReceiptCRReturn.Inventory AS ReceiptCRReturnInventory
		|		INNER JOIN Document.ReceiptCRReturn.DiscountsMarkups AS CRReceiptReturnDiscountsMarkups
		|		ON ReceiptCRReturnInventory.ConnectionKey = CRReceiptReturnDiscountsMarkups.ConnectionKey
		|			AND (ReceiptCRReturnInventory.Ref.CashCRSession = &CashCRSession)
		|			AND (ReceiptCRReturnInventory.Ref.Posted)
		|			AND (ReceiptCRReturnInventory.Ref.ReceiptCRNumber > 0)
		|			AND (NOT ReceiptCRReturnInventory.Ref.Archival)
		|			AND ReceiptCRReturnInventory.Ref = CRReceiptReturnDiscountsMarkups.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TU_AutoDiscountsMarkupsJoin.ProductsAndServices,
		|	TU_AutoDiscountsMarkupsJoin.Characteristic,
		|	TU_AutoDiscountsMarkupsJoin.DiscountMarkup,
		|	SUM(TU_AutoDiscountsMarkupsJoin.Amount) AS Amount
		|FROM
		|	TU_AutoDiscountsMarkupsJoin AS TU_AutoDiscountsMarkupsJoin
		|
		|GROUP BY
		|	TU_AutoDiscountsMarkupsJoin.ProductsAndServices,
		|	TU_AutoDiscountsMarkupsJoin.Characteristic,
		|	TU_AutoDiscountsMarkupsJoin.DiscountMarkup
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ReceiptCRSalesRefunds.ProductsAndServices AS ProductsAndServices,
		|	ReceiptCRSalesRefunds.Characteristic AS Characteristic,
		|	ReceiptCRSalesRefunds.Batch AS Batch,
		|	ReceiptCRSalesRefunds.MeasurementUnit AS MeasurementUnit,
		|	ReceiptCRSalesRefunds.Price AS Price,
		|	ReceiptCRSalesRefunds.DiscountMarkupPercent AS DiscountMarkupPercent,
		|	ReceiptCRSalesRefunds.VATRate AS VATRate,
		|	ReceiptCRSalesRefunds.SerialNumber,
		|	SUM(ReceiptCRSalesRefunds.FlagOfSales) AS FlagOfSales
		|FROM
		|	(SELECT
		|		ReceiptCRInventory.ProductsAndServices AS ProductsAndServices,
		|		ReceiptCRInventory.Characteristic AS Characteristic,
		|		ReceiptCRInventory.Batch AS Batch,
		|		ReceiptCRInventory.MeasurementUnit AS MeasurementUnit,
		|		ReceiptCRInventory.Price AS Price,
		|		ReceiptCRInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
		|		ReceiptCRInventory.VATRate AS VATRate,
		|		ReceiptCRSerialNumbers.SerialNumber AS SerialNumber,
		|		1 AS FlagOfSales
		|	FROM
		|		Document.ReceiptCR.Inventory AS ReceiptCRInventory
		|			INNER JOIN Document.ReceiptCR.SerialNumbers AS ReceiptCRSerialNumbers
		|			ON ReceiptCRInventory.ConnectionKey = ReceiptCRSerialNumbers.ConnectionKey
		|				AND ReceiptCRInventory.Ref = ReceiptCRSerialNumbers.Ref
		|	WHERE
		|		ReceiptCRInventory.Ref.CashCRSession = &CashCRSession
		|		AND ReceiptCRInventory.Ref.Posted
		|		AND ReceiptCRInventory.Ref.ReceiptCRNumber > 0
		|		AND NOT ReceiptCRInventory.Ref.Archival
		|		AND ReceiptCRSerialNumbers.Ref.CashCRSession = &CashCRSession
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ReceiptCRReturnInventory.ProductsAndServices,
		|		ReceiptCRReturnInventory.Characteristic,
		|		ReceiptCRReturnInventory.Batch,
		|		ReceiptCRReturnInventory.MeasurementUnit,
		|		ReceiptCRReturnInventory.Price,
		|		ReceiptCRReturnInventory.DiscountMarkupPercent,
		|		ReceiptCRReturnInventory.VATRate,
		|		ReceiptCRReturnSerialNumbers.SerialNumber,
		|		-1
		|	FROM
		|		Document.ReceiptCRReturn.Inventory AS ReceiptCRReturnInventory
		|			INNER JOIN Document.ReceiptCRReturn.SerialNumbers AS ReceiptCRReturnSerialNumbers
		|			ON ReceiptCRReturnInventory.ConnectionKey = ReceiptCRReturnSerialNumbers.ConnectionKey
		|				AND ReceiptCRReturnInventory.Ref = ReceiptCRReturnSerialNumbers.Ref
		|	WHERE
		|		ReceiptCRReturnInventory.Ref.CashCRSession = &CashCRSession
		|		AND ReceiptCRReturnInventory.Ref.Posted
		|		AND ReceiptCRReturnInventory.Ref.ReceiptCRNumber > 0
		|		AND NOT ReceiptCRReturnInventory.Ref.Archival
		|		AND ReceiptCRReturnSerialNumbers.Ref.CashCRSession = &CashCRSession) AS ReceiptCRSalesRefunds
		|
		|GROUP BY
		|	ReceiptCRSalesRefunds.ProductsAndServices,
		|	ReceiptCRSalesRefunds.Characteristic,
		|	ReceiptCRSalesRefunds.Batch,
		|	ReceiptCRSalesRefunds.MeasurementUnit,
		|	ReceiptCRSalesRefunds.VATRate,
		|	ReceiptCRSalesRefunds.SerialNumber,
		|	ReceiptCRSalesRefunds.Price,
		|	ReceiptCRSalesRefunds.DiscountMarkupPercent
		|
		|HAVING
		|	SUM(ReceiptCRSalesRefunds.FlagOfSales) > 0";
		
		Query.TempTablesManager = TempTablesManager;
		Query.SetParameter("CashCRSession", ObjectCashCRSession.Ref);
		// AutomaticDiscounts
		Query.SetParameter("UseAutomaticDiscounts", GetFunctionalOption("UseAutomaticDiscountsMarkups"));
		// End AutomaticDiscounts
		
		Result = Query.ExecuteBatch();
		
		Inventory = Result[0].Unload();
		PaymentWithPaymentCards = Result[1].Unload();
		
		ObjectCashCRSession.Inventory.Clear();
		ObjectCashCRSession.PaymentWithPaymentCards.Clear();
		
		If Inventory.Count() > 0 Then
			ObjectCashCRSession.PositionResponsible = ?(
				Result[2].Unload()[0].CountResponsible > 1,
				Enums.AttributePositionOnForm.InTabularSection,
				Enums.AttributePositionOnForm.InHeader
			);
		EndIf;
		
		For Each TSRow IN Inventory Do
			
			If TSRow.Total <> 0 Then
				RowOfTabularSectionInventory = ObjectCashCRSession.Inventory.Add();
				FillPropertyValues(RowOfTabularSectionInventory, TSRow);
			EndIf;
			
		EndDo;
		
		For Each TSRow IN PaymentWithPaymentCards Do
			
			If TSRow.Amount <> 0 Then
				TabularSectionRow = ObjectCashCRSession.PaymentWithPaymentCards.Add();
				FillPropertyValues(TabularSectionRow, TSRow);
			EndIf;
			
		EndDo;
		
		// AutomaticDiscounts
		ObjectCashCRSession.DiscountsMarkups.Clear();
		If GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
			
			AutomaticDiscounts = Result[4].Unload();
			For Each TSRow IN AutomaticDiscounts Do
				
				If TSRow.Amount <> 0 Then
					TabularSectionRow = ObjectCashCRSession.DiscountsMarkups.Add();
					FillPropertyValues(TabularSectionRow, TSRow);
				EndIf;
				
			EndDo;
			
		EndIf;
		// End AutomaticDiscounts
		
		// Serial numbers
		ObjectCashCRSession.SerialNumbers.Clear();
		WorkWithSerialNumbersClientServer.FillConnectionKeysInTabularSectionProducts(ObjectCashCRSession, "Inventory");
		If GetFunctionalOption("UseSerialNumbers") Then
			
			SerialNumbers = Result[5].Unload();
			For Each TSRow In ObjectCashCRSession.Inventory Do
				
				ConnectionKey = 0;
				FilterStructure = New Structure("ProductsAndServices, Characteristic, Batch, MeasurementUnit, Price, VATRate");
				FillPropertyValues(FilterStructure, TSRow);
				
				SerialNumbersByFilter = SerialNumbers.FindRows(FilterStructure);
				
				If SerialNumbersByFilter.Count()>0 Then
					
					ConnectionKey = TSRow.ConnectionKey;
					
					For Each Str In SerialNumbersByFilter Do
						NewRow = ObjectCashCRSession.SerialNumbers.Add();
						NewRow.ConnectionKey = ConnectionKey;
						NewRow.SerialNumber = Str.SerialNumber;
					EndDo;
				EndIf;
				
				WorkWithSerialNumbersClientServer.UpdateStringPresentationOfSerialNumbersOfLine(TSRow, ObjectCashCRSession, "ConnectionKey");
				
			EndDo;
			
		EndIf;
		// Serial numbers
		
		ClosingDateOfCashCRSession = CurrentDate();
		ObjectCashCRSession.CashCRSessionStatus    = Enums.CashCRSessionStatuses.Closed;
		ObjectCashCRSession.Date                   = ClosingDateOfCashCRSession;
		ObjectCashCRSession.CashCRSessionEnd = ClosingDateOfCashCRSession;
		ObjectCashCRSession.DocumentAmount         = ObjectCashCRSession.Inventory.Total("Total");
		
		If Inventory.Count() > 0 Then
			ObjectCashCRSession.Responsible = Inventory[0].Responsible;
		EndIf;
		
		If Not ValueIsFilled(ObjectCashCRSession.Responsible) Then
			ObjectCashCRSession.Responsible = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");
		EndIf;
		
		ObjectCashCRSession.Write(DocumentWriteMode.Posting);
		
		CommitTransaction();
		
		StructureReturns.RetailReport = ObjectCashCRSession.Ref;
		StructureReturns.ErrorDescription = "";
		
	Except
		
		RollbackTransaction();
		
		StructureReturns.RetailReport = Undefined;
		StructureReturns.ErrorDescription = NStr("ru = 'При формировании отчета о розничных продажах произошла ошибка.
		|Закрытие кассовой смены не выполнено.'; en = 'An error occurred while generating retail sales report.
		|Cash session closing is not completed.'"
		);
		
	EndTry;
	
	Return StructureReturns;
	
EndFunction // CloseCashCRSession()

// Function deletes deferred receipts.
//
Function DeleteDeferredReceipts(CashCRSession, ErrorDescription)
	
	Result = True;
	
	BeginTransaction();
	
	Query = New Query(
	"SELECT
	|	ReceiptCR.Ref AS Ref
	|FROM
	|	Document.ReceiptCR AS ReceiptCR
	|WHERE
	|	ReceiptCR.Status <> &Status
	|	AND ReceiptCR.CashCRSession = &CashCRSession
	|
	|UNION ALL
	|
	|SELECT
	|	ReceiptCRReturn.Ref
	|FROM
	|	Document.ReceiptCRReturn AS ReceiptCRReturn
	|WHERE
	|	ReceiptCRReturn.ReceiptCRNumber = 0
	|	AND ReceiptCRReturn.CashCRSession = &CashCRSession");
	Query.SetParameter("CashCRSession", CashCRSession.Ref);
	Query.SetParameter("Status",        Enums.ReceiptCRStatuses.Issued);
	ReceiptCRSelection = Query.Execute().Select();
	
	Try
		
		While ReceiptCRSelection.Next() Do
			ReceiptCRObject = ReceiptCRSelection.Ref.GetObject();
			ReceiptCRObject.Delete();
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		Result = False;
		
		ErrorDescription = NStr("en='An error occurred while deleting deferred receipts.
		|Additional
		|description: %AdditionalDetails%';ru='При удалении отложенных чеков произошла ошибка.
		|Дополнительное
		|описание: %ДополнительноеОписание%'"
		);
		ErrorDescription = StrReplace(ErrorDescription, "%AdditionalDetails%", ErrorInfo().Definition);
		
	EndTry;
	
	Return Result;
	
EndFunction

// Function archives receipts CR by the petty cash shift.
//
Procedure RunReceiptsBackup(ObjectCashCRSession, ErrorDescription = "") Export
	
	BeginTransaction();

	Query = New Query(
	"SELECT
	|	2 AS Order,
	|	ReceiptCR.Ref AS Ref
	|FROM
	|	Document.ReceiptCR AS ReceiptCR
	|WHERE
	|	(NOT ReceiptCR.Archival)
	|	AND ReceiptCR.Posted
	|	AND ReceiptCR.ReceiptCRNumber > 0
	|	AND ReceiptCR.CashCRSession = &CashCRSession
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	ReceiptCRReturn.Ref
	|FROM
	|	Document.ReceiptCRReturn AS ReceiptCRReturn
	|WHERE
	|	(NOT ReceiptCRReturn.Archival)
	|	AND ReceiptCRReturn.Posted
	|	AND ReceiptCRReturn.ReceiptCRNumber > 0
	|	AND ReceiptCRReturn.CashCRSession = &CashCRSession
	|
	|ORDER BY
	|	Order");
	Query.SetParameter("CashCRSession", ObjectCashCRSession.Ref);
	ReceiptCRSelection = Query.Execute().Select();
	
	Try
		
		While ReceiptCRSelection.Next() Do
			ReceiptCRObject = ReceiptCRSelection.Ref.GetObject();
			ReceiptCRObject.Archival = True;
			ReceiptCRObject.Write(DocumentWriteMode.Posting);
		EndDo;
		
		ObjectCashCRSession.CashCRSessionStatus = Enums.CashCRSessionStatuses.ClosedReceiptsArchived;
		ObjectCashCRSession.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism", True);
		ObjectCashCRSession.Write(DocumentWriteMode.Posting);
		
		If WorkWithSerialNumbers.UseSerialNumbersBalance() = True Then
			Set = AccumulationRegisters.SerialNumbers.CreateRecordSet();
			Set.Filter.Recorder.Set(ReceiptCRSelection.Ref);
			Set.Write(True);
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		ErrorDescription = NStr("ru = 'При архивации чеков ККМ произошла ошибка.
		|Архивация чеков ККМ не выполнена.
		|Дополнительное
		|описание: %ДополнительноеОписание%'; en = 'An error occurred while archiving receipts CR.
		|Receipts CR are not archived.
		|Additional
		|description: %AdditionalDetails%'"
		);
		ErrorDescription = StrReplace(ErrorDescription, "%AdditionalDetails%", ErrorInfo().Definition);

	EndTry;

EndProcedure // ArchiveReceiptsCR()

// Procedure closes petty cash shift.
//
Function CloseCashCRSessionExecuteArchiving(CashCR, ErrorDescription = "") Export
	
	DocumentArray = New Array;
	
	StructureStateCashCRSession = GetCashCRSessionStatus(CashCR);
	
	If StructureStateCashCRSession.CashCRSessionStatus = Enums.CashCRSessionStatuses.IsOpen Then
		
		ObjectCashCRSession = StructureStateCashCRSession.CashCRSession.GetObject();
		
		StructureReturns = Documents.RetailReport.CloseCashCRSession(ObjectCashCRSession);
		If StructureReturns.RetailReport = Undefined Then
			
			ErrorDescription = StructureReturns.ErrorDescription;
			
		Else
			
			DocumentArray.Add(StructureReturns.RetailReport);
			
			If Constants.DeleteUnissuedReceiptsOnCloseCashCRSession.Get() Then
				DeleteDeferredReceipts(StructureStateCashCRSession.CashCRSession.GetObject(), ErrorDescription);
			EndIf;
			
			If Constants.ArchiveCRReceiptsOnCloseCashCRSession.Get() Then
				RunReceiptsBackup(StructureStateCashCRSession.CashCRSession.GetObject(), ErrorDescription);
			EndIf;
			
		EndIf;
		
	Else
		
		// Session is not opened.
		
	EndIf;
	
	Return DocumentArray;
	
EndFunction // ClearZReport()

//////////////////////////////////////////////////////////////////////////////
// SHIFT STATE CHECK FUNCTIONS

// Function returns empty string of petty cash shift state.
//
Function GetCashCRSessionDescriptionStructure()
	
	StatusCashCRSession = New Structure;
	StatusCashCRSession.Insert("StatusModificationDate");
	StatusCashCRSession.Insert("CashCRSessionStatus");
	StatusCashCRSession.Insert("CashCRSession");
	StatusCashCRSession.Insert("CashInPettyCash");
	StatusCashCRSession.Insert("CashCRSessionNumber");
	StatusCashCRSession.Insert("SessionIsOpen", False);
	
	// Description of petty cash shift attributes
	StatusCashCRSession.Insert("CashCR");
	StatusCashCRSession.Insert("DocumentCurrency");
	StatusCashCRSession.Insert("DocumentCurrencyPresentation");
	StatusCashCRSession.Insert("PriceKind");
	StatusCashCRSession.Insert("Company");
	StatusCashCRSession.Insert("Responsible");
	StatusCashCRSession.Insert("Department");
	StatusCashCRSession.Insert("StructuralUnit");
	StatusCashCRSession.Insert("AmountIncludesVAT");
	StatusCashCRSession.Insert("IncludeVATInPrice");
	StatusCashCRSession.Insert("VATTaxation");
	
	Return StatusCashCRSession;
	
EndFunction // GetPettyCashShiftDescriptionStructure()

// Function returns structure that characterizes last petty cash shift state by receipt CR.
//
Function GetCashCRSessionStatus(CashCR) Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	RetailReport.Number AS CashCRSessionNumber,
	|	RetailReport.Ref AS CashCRSession,
	|	RetailReport.CashCRSessionStatus AS CashCRSessionStatus,
	|	RetailReport.CashCR AS CashCR,
	|	RetailReport.DocumentCurrency AS DocumentCurrency,
	|	RetailReport.DocumentCurrency.Presentation AS DocumentCurrencyPresentation,
	|	RetailReport.PriceKind AS PriceKind,
	|	RetailReport.Company AS Company,
	|	RetailReport.Responsible AS Responsible,
	|	RetailReport.Department AS Department,
	|	RetailReport.StructuralUnit AS StructuralUnit,
	|	RetailReport.AmountIncludesVAT AS AmountIncludesVAT,
	|	RetailReport.IncludeVATInPrice AS IncludeVATInPrice,
	|	CASE
	|		WHEN RetailReport.CashCRSessionStatus = VALUE(Enum.CashCRSessionStatuses.IsOpen)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS SessionIsOpen,
	|	CASE
	|		WHEN RetailReport.CashCRSessionStatus = VALUE(Enum.CashCRSessionStatuses.IsOpen)
	|			THEN RetailReport.CashCRSessionStart
	|		ELSE RetailReport.CashCRSessionEnd
	|	END AS StatusModificationDate,
	|	ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) AS CashInPettyCash,
	|	RetailReport.VATTaxation AS VATTaxation
	|FROM
	|	Document.RetailReport AS RetailReport
	|		LEFT JOIN AccumulationRegister.CashInCashRegisters.Balance(, CashCR = &CashCR) AS CashAssetsInRetailCashesBalances
	|		ON RetailReport.CashCR = CashAssetsInRetailCashesBalances.CashCR
	|WHERE
	|	RetailReport.Posted
	|	AND RetailReport.CashCR = &CashCR
	|
	|ORDER BY
	|	RetailReport.Date DESC,
	|	CashCRSession DESC";
	
	Query.SetParameter("CashCR", CashCR);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	CashShiftDescription = GetCashCRSessionDescriptionStructure();
	
	If Selection.Next() Then
		FillPropertyValues(CashShiftDescription, Selection);
	EndIf;
	
	Return CashShiftDescription;
	
EndFunction // GetPettyCashShiftState()

// Function returns structure that characterizes petty cash shift state on date.
//
Function GetCashCRSessionAttributesToDate(CashCR, DateTime) Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	RetailReport.Number AS CashCRSessionNumber,
	|	RetailReport.Ref AS CashCRSession,
	|	RetailReport.CashCRSessionStatus AS CashCRSessionStatus,
	|	RetailReport.CashCR AS CashCR,
	|	RetailReport.DocumentCurrency AS DocumentCurrency,
	|	RetailReport.DocumentCurrency.Presentation AS DocumentCurrencyPresentation,
	|	RetailReport.PriceKind AS PriceKind,
	|	RetailReport.Company AS Company,
	|	RetailReport.Responsible AS Responsible,
	|	RetailReport.Department AS Department,
	|	RetailReport.StructuralUnit AS StructuralUnit,
	|	RetailReport.AmountIncludesVAT AS AmountIncludesVAT,
	|	RetailReport.IncludeVATInPrice AS IncludeVATInPrice,
	|	CASE
	|		WHEN RetailReport.CashCRSessionStatus = VALUE(Enum.CashCRSessionStatuses.IsOpen)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS SessionIsOpen,
	|	CASE
	|		WHEN RetailReport.CashCRSessionStatus = VALUE(Enum.CashCRSessionStatuses.IsOpen)
	|			THEN RetailReport.CashCRSessionStart
	|		ELSE RetailReport.CashCRSessionEnd
	|	END AS StatusModificationDate,
	|	ISNULL(CashAssetsInRetailCashesBalances.AmountBalance, 0) AS CashInPettyCash,
	|	RetailReport.VATTaxation AS VATTaxation
	|FROM
	|	(SELECT
	|		MAX(CASE
	|				WHEN RetailReport.CashCRSessionStatus = VALUE(Enum.CashCRSessionStatuses.IsOpen)
	|					THEN RetailReport.CashCRSessionStart
	|				ELSE RetailReport.CashCRSessionEnd
	|			END) AS StatusModificationDate,
	|		RetailReport.CashCR AS CashCR
	|	FROM
	|		Document.RetailReport AS RetailReport
	|	WHERE
	|		RetailReport.Posted
	|		AND RetailReport.CashCR = &CashCR
	|		AND CASE
	|				WHEN RetailReport.CashCRSessionStatus = VALUE(Enum.CashCRSessionStatuses.IsOpen)
	|					THEN RetailReport.CashCRSessionStart
	|				ELSE RetailReport.CashCRSessionEnd
	|			END <= &DateTime
	|	
	|	GROUP BY
	|		RetailReport.CashCR) AS CashChange
	|		LEFT JOIN Document.RetailReport AS RetailReport
	|		ON CashChange.CashCR = RetailReport.CashCR
	|			AND (RetailReport.Posted)
	|			AND (CashChange.StatusModificationDate = CASE
	|				WHEN RetailReport.CashCRSessionStatus = VALUE(Enum.CashCRSessionStatuses.IsOpen)
	|					THEN RetailReport.CashCRSessionStart
	|				ELSE RetailReport.CashCRSessionEnd
	|			END)
	|		LEFT JOIN AccumulationRegister.CashInCashRegisters.Balance(&DateTime, CashCR = &CashCR) AS CashAssetsInRetailCashesBalances
	|		ON CashChange.CashCR = CashAssetsInRetailCashesBalances.CashCR";
	
	Query.SetParameter("CashCR", CashCR);
	Query.SetParameter("DateTime", DateTime+100);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	StatusCashCRSession = GetCashCRSessionDescriptionStructure();
	
	If Selection.Next() Then
		FillPropertyValues(StatusCashCRSession, Selection);
	EndIf;
	
	Return StatusCashCRSession;
	
EndFunction // GetPettyCashShiftAttributesOnDate()

// Function receives open petty cash shift by Receipt CR in the specified period.
// Used to control petty cash shifts intersection.
// Only one petty cash shift can simultaneously exist during one period.
//
Function GetOpenCashCRSession(CashCR, CashCRSession = Undefined, CashCRSessionStart, CashCRSessionEnd) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	RetailReport.Ref
	|FROM
	|	Document.RetailReport AS RetailReport
	|WHERE
	|	RetailReport.CashCRSessionStart <= &CashCRSessionStart
	|	AND CASE
	|			WHEN RetailReport.CashCRSessionEnd = DATETIME(1, 1, 1)
	|				THEN TRUE
	|			ELSE RetailReport.CashCRSessionEnd >= &CashCRSessionStart
	|		END
	|	AND RetailReport.CashCR = &CashCR
	|	AND RetailReport.Ref <> &CashCRSession
	|	AND RetailReport.Posted
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	RetailReport.Ref
	|FROM
	|	Document.RetailReport AS RetailReport
	|WHERE
	|	&CashCRSessionEnd <> DATETIME(1, 1, 1)
	|	AND RetailReport.CashCRSessionStart <= &CashCRSessionEnd
	|	AND CASE
	|			WHEN RetailReport.CashCRSessionEnd = DATETIME(1, 1, 1)
	|				THEN TRUE
	|			ELSE RetailReport.CashCRSessionEnd >= &CashCRSessionEnd
	|		END
	|	AND RetailReport.CashCR = &CashCR
	|	AND RetailReport.Ref <> &CashCRSession
	|	AND RetailReport.Posted
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	RetailReport.Ref
	|FROM
	|	Document.RetailReport AS RetailReport
	|WHERE
	|	&CashCRSessionEnd = DATETIME(1, 1, 1)
	|	AND RetailReport.CashCRSessionStart >= &CashCRSessionStart
	|	AND RetailReport.CashCR = &CashCR
	|	AND RetailReport.Ref <> &CashCRSession
	|	AND RetailReport.Posted";
	
	Query.SetParameter("CashCR",               CashCR);
	Query.SetParameter("CashCRSessionStart",    CashCRSessionStart);
	Query.SetParameter("CashCRSessionEnd", CashCRSessionEnd);
	Query.SetParameter("CashCRSession",          CashCRSession);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	EndIf;
	
	Return Undefined;
	
EndFunction // GetOpenPettyCashShift()

// Function checks petty cash shift state on date. If shift is not opened - error description is returned.
//
Function SessionIsOpen(CashCRSession, Date, ErrorDescription = "") Export
	
	SessionIsOpen = False;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	RetailReport.CashCRSessionStatus AS CashCRSessionStatus,
	|	RetailReport.CashCRSessionStart AS CashCRSessionStart,
	|	RetailReport.CashCRSessionEnd AS CashCRSessionEnd
	|FROM
	|	Document.RetailReport AS RetailReport
	|WHERE
	|	RetailReport.Posted
	|	AND RetailReport.Ref = &CashCRSession";
	
	Query.SetParameter("CashCRSession", CashCRSession);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
		
		If Selection.CashCRSessionStatus = Enums.CashCRSessionStatuses.IsOpen Then
			
			// If shift is opened, then since the opening there must be not more than 24 hours.
			If Date - Selection.CashCRSessionStart < 86400 Then
				SessionIsOpen = True;
			Else
				ErrorDescription = NStr("en='More than 24 hours have passed since the opening. It is required to close petty cash shift';ru='С момента открытия кассовой смены истекло более 24 часов. Необходимо выполнить закрытие кассовой смены'");
				SessionIsOpen = False;
			EndIf;
			
		ElsIf ValueIsFilled(Selection.CashCRSessionStatus) Then
			
			If Selection.CashCRSessionEnd >= Date AND Selection.CashCRSessionStart <= Date Then
				SessionIsOpen = True;
			Else
				ErrorDescription = NStr("en='Session is not opened';ru='Смена не открыта'");
				SessionIsOpen = False;
			EndIf;
			
		EndIf;
		
	Else
		
		ErrorDescription = NStr("en='Session is not opened';ru='Смена не открыта'");
		SessionIsOpen = False;
		
	EndIf;
	
	Return SessionIsOpen;
	
EndFunction // ShiftOpened()

#Region PrintInterface

// Function generates tabular document of petty cash book cover.
//
Function GeneratePrintFormOfReportAboutRetailSales(ObjectsArray, PrintObjects)
	
	Template = PrintManagement.PrintedFormsTemplate("Document.RetailReport.PF_MXL_RetailReport");
	
	Spreadsheet = New SpreadsheetDocument;
	Spreadsheet.PrintParametersName = "PRINT_PARAMETERS_Check_SaleInvoice";
	
	For Each ReceiptCR IN ObjectsArray Do
		
		FirstLineNumber = Spreadsheet.TableHeight + 1;
		
		Query = New Query;
		Query.SetParameter("CurrentDocument", ReceiptCR.Ref);
		
		Query.Text =
		"SELECT
		|	RetailReport.Number AS Number,
		|	RetailReport.Date AS Date,
		|	RetailReport.CashCR AS CashCR,
		|	RetailReport.DocumentCurrency AS Currency,
		|	RetailReport.CashCR.Presentation AS Customer,
		|	RetailReport.Company AS Company,
		|	RetailReport.Company.Prefix AS Prefix,
		|	RetailReport.Company.Presentation AS Vendor,
		|	RetailReport.DocumentAmount AS DocumentAmount,
		|	RetailReport.AmountIncludesVAT AS AmountIncludesVAT,
		|	RetailReport.Responsible.Ind AS Responsible,
		|	RetailReport.Inventory.(
		|		LineNumber AS LineNumber,
		|		ProductsAndServices AS ProductsAndServices,
		|		ProductsAndServices.Presentation AS InventoryItem,
		|		ProductsAndServices.DescriptionFull AS InventoryFullDescr,
		|		ProductsAndServices.Code AS Code,
		|		ProductsAndServices.SKU AS SKU,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Price AS Price,
		|		Amount AS Amount,
		|		VATAmount AS VATAmount,
		|		Total AS Total,
		|		DiscountMarkupPercent,
		|		CASE
		|			WHEN RetailReport.Inventory.DiscountMarkupPercent <> 0
		|					OR RetailReport.Inventory.AutomaticDiscountAmount <> 0
		|				THEN 1
		|			ELSE 0
		|		END AS IsDiscount,
		|		AutomaticDiscountAmount,
		|		ConnectionKey
		|	),
		|	RetailReport.SerialNumbers.(
		|		SerialNumber,
		|		ConnectionKey
		|	)
		|FROM
		|	Document.RetailReport AS RetailReport
		|WHERE
		|	RetailReport.Ref = &CurrentDocument";
		
		Header = Query.Execute().Select();
		Header.Next();
		
		InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.Date, ,);
		
		If Header.Date < Date('20110101') Then
			DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
			
		// Output invoice header.
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = 
			"Retail sales report No"
		  + DocumentNumber
		  + " from "
		  + Format(Header.Date, "DLF=DD");
		
		Spreadsheet.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Vendor");
		VendorPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,LegalAddress,PhoneNumbers,");
		TemplateArea.Parameters.VendorPresentation = VendorPresentation;
		TemplateArea.Parameters.Vendor = Header.Company;
		Spreadsheet.Put(TemplateArea);
		
		AreDiscounts = Header.Inventory.Unload().Total("IsDiscount") <> 0;
		
		NumberArea = Template.GetArea("TableHeader|LineNumber");
		DataArea = Template.GetArea("TableHeader|Data");
		DiscountsArea = Template.GetArea("TableHeader|Discount");
		AmountArea  = Template.GetArea("TableHeader|Amount");
		
		Spreadsheet.Put(NumberArea);
		
		Spreadsheet.Join(DataArea);
		If AreDiscounts Then
			Spreadsheet.Join(DiscountsArea);
		EndIf;
		Spreadsheet.Join(AmountArea);
		
		AreaColumnInventory = Template.Area("InventoryItem");
		
		If Not AreDiscounts Then
			AreaColumnInventory.ColumnWidth = AreaColumnInventory.ColumnWidth
											  + Template.Area("AmountWithoutDiscount").ColumnWidth
											  + Template.Area("DiscountAmount").ColumnWidth;
		EndIf;
		
		NumberArea = Template.GetArea("String|LineNumber");
		DataArea = Template.GetArea("String|Data");
		DiscountsArea = Template.GetArea("String|Discount");
		AmountArea  = Template.GetArea("String|Amount");
		
		Amount			= 0;
		VATAmount		= 0;
		Total			= 0;
		TotalDiscounts		= 0;
		TotalWithoutDiscounts	= 0;
		
		LinesSelectionInventory = Header.Inventory.Select();
		LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
		While LinesSelectionInventory.Next() Do
			
			If Not ValueIsFilled(LinesSelectionInventory.ProductsAndServices) Then
				Message("Products and services value is not filled in in one of the rows - String during printing is skipped.", MessageStatus.Important);
				Continue;
			EndIf;
			
			NumberArea.Parameters.Fill(LinesSelectionInventory);
			Spreadsheet.Put(NumberArea);
			
			DataArea.Parameters.Fill(LinesSelectionInventory);
			StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
			DataArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(
				LinesSelectionInventory.InventoryItem,
				LinesSelectionInventory.Characteristic,
				LinesSelectionInventory.SKU,
				StringSerialNumbers
			);
			
			Spreadsheet.Join(DataArea);
			
			Discount = 0;
			
			If AreDiscounts Then
				If LinesSelectionInventory.DiscountMarkupPercent = 100 Then
					Discount = LinesSelectionInventory.Price * LinesSelectionInventory.Quantity;
					DiscountsArea.Parameters.Discount         = Discount;
					DiscountsArea.Parameters.AmountWithoutDiscount = Discount;
				ElsIf LinesSelectionInventory.DiscountMarkupPercent = 0 AND LinesSelectionInventory.AutomaticDiscountAmount = 0 Then
					DiscountsArea.Parameters.Discount         = 0;
					DiscountsArea.Parameters.AmountWithoutDiscount = LinesSelectionInventory.Amount;
				Else
					Discount = LinesSelectionInventory.Quantity * LinesSelectionInventory.Price - LinesSelectionInventory.Amount; // AutomaticDiscounts
					DiscountsArea.Parameters.Discount         = Discount;
					DiscountsArea.Parameters.AmountWithoutDiscount = LinesSelectionInventory.Amount + Discount;
				EndIf;
				Spreadsheet.Join(DiscountsArea);
			EndIf;
			
			AmountArea.Parameters.Fill(LinesSelectionInventory);
			Spreadsheet.Join(AmountArea);
			
			Amount			= Amount			+ LinesSelectionInventory.Amount;
			VATAmount		= VATAmount		+ LinesSelectionInventory.VATAmount;
			Total			= Total			+ LinesSelectionInventory.Total;
			TotalDiscounts		= TotalDiscounts	+ Discount;
			TotalWithoutDiscounts	= Amount			+ TotalDiscounts;
			
		EndDo;
		
		// Output Total.
		NumberArea = Template.GetArea("Total|LineNumber");
		DataArea = Template.GetArea("Total|Data");
		DiscountsArea = Template.GetArea("Total|Discount");
		AmountArea  = Template.GetArea("Total|Amount");
		
		Spreadsheet.Put(NumberArea);
		
		DataStructure = New Structure("Total", Amount);
		If VATAmount = 0 Then
			
			DataStructure.Insert("VAT", "Without tax (VAT)");
			DataStructure.Insert("VATAmount", "-");
			
		Else
			
			DataStructure.Insert("VAT", ?(Header.AmountIncludesVAT, "Including VAT:", "VAT Amount:"));
			DataStructure.Insert("VATAmount", SmallBusinessServer.AmountsFormat(VATAmount));
			
		EndIf; 
		
		DataArea.Parameters.Fill(DataStructure);
		
		Spreadsheet.Join(DataArea);
		If AreDiscounts Then
			DiscountsArea.Parameters.TotalDiscounts    = TotalDiscounts;
			DiscountsArea.Parameters.TotalWithoutDiscounts = TotalWithoutDiscounts;
			Spreadsheet.Join(DiscountsArea);
		EndIf;
		
		AmountArea.Parameters.Fill(DataStructure);
		Spreadsheet.Join(AmountArea);
		
		// Output amount in writing.
		TemplateArea = Template.GetArea("AmountInWords");
		AmountToBeWrittenInWords = Total;
		TemplateArea.Parameters.TotalRow = "Total titles "
													+ String(LinesSelectionInventory.Count())
													+ ", in the amount of "
													+ SmallBusinessServer.AmountsFormat(AmountToBeWrittenInWords, Header.Currency);
		
		TemplateArea.Parameters.AmountInWords = WorkWithCurrencyRates.GenerateAmountInWords(AmountToBeWrittenInWords, Header.Currency);
		Spreadsheet.Put(TemplateArea);
	
		// Output signatures.
		TemplateArea = Template.GetArea("Signatures");
		TemplateArea.Parameters.Fill(Header);
		
		If ValueIsFilled(Header.Responsible) Then
			
			ResponsibleData = SmallBusinessServer.IndData(
				SmallBusinessServer.GetCompany(Header.Company),
				Header.Responsible, 
				Header.Date);
			
			TemplateArea.Parameters.ResponsibleDetails	= ResponsibleData.Presentation;
			
		EndIf;
		
		Spreadsheet.Put(TemplateArea);
		
		Spreadsheet.PutHorizontalPageBreak();
		
		PrintManagement.SetDocumentPrintArea(Spreadsheet, FirstLineNumber, PrintObjects, ReceiptCR);
		
	EndDo;
	
	Return Spreadsheet;
	
EndFunction // GeneratePettyCashBookCoverAndLastSheetPrintableForm()

// Document printing procedure.
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "RetailReport") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"RetailReport",
			"Retail report",
			GeneratePrintFormOfReportAboutRetailSales(ObjectsArray, PrintObjects)
		);
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure // Print()

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "RetailReport";
	PrintCommand.Presentation = NStr("en='Retail report';ru='Отчет о розничных продажах'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf