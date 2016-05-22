#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableOrdersPlacement(DocumentRefInventoryReservation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.StructuralUnit AS SupplySource
	|FROM
	|	TemporaryTableInventorySource AS TableInventory
	|WHERE
	|	(VALUETYPE(TableInventory.StructuralUnit) = Type(Document.CustomerOrder)
	|				AND TableInventory.StructuralUnit <> VALUE(Document.CustomerOrder.EmptyRef)
	|			OR VALUETYPE(TableInventory.StructuralUnit) = Type(Document.ProductionOrder)
	|				AND TableInventory.StructuralUnit <> VALUE(Document.ProductionOrder.EmptyRef)
	|			OR VALUETYPE(TableInventory.StructuralUnit) = Type(Document.PurchaseOrder)
	|				AND TableInventory.StructuralUnit <> VALUE(Document.PurchaseOrder.EmptyRef))
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.CustomerOrder,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.StructuralUnit";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.OrdersPlacement");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text = 	
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.StructuralUnit AS SupplySource,
	|	CASE
	|		WHEN TableInventory.Quantity > ISNULL(OrdersPlacementBalances.QuantityBalance, 0)
	|			THEN ISNULL(OrdersPlacementBalances.QuantityBalance, 0)
	|		WHEN TableInventory.Quantity <= ISNULL(OrdersPlacementBalances.QuantityBalance, 0)
	|			THEN TableInventory.Quantity
	|	END AS Quantity
	|FROM
	|	TemporaryTableInventorySource AS TableInventory
	|		LEFT JOIN (SELECT
	|			OrdersPlacementBalances.Company AS Company,
	|			OrdersPlacementBalances.CustomerOrder AS CustomerOrder,
	|			OrdersPlacementBalances.ProductsAndServices AS ProductsAndServices,
	|			OrdersPlacementBalances.Characteristic AS Characteristic,
	|			OrdersPlacementBalances.SupplySource AS SupplySource,
	|			SUM(OrdersPlacementBalances.QuantityBalance) AS QuantityBalance
	|		FROM
	|			(SELECT
	|				OrdersPlacementBalances.Company AS Company,
	|				OrdersPlacementBalances.CustomerOrder AS CustomerOrder,
	|				OrdersPlacementBalances.ProductsAndServices AS ProductsAndServices,
	|				OrdersPlacementBalances.Characteristic AS Characteristic,
	|				OrdersPlacementBalances.SupplySource AS SupplySource,
	|				SUM(OrdersPlacementBalances.QuantityBalance) AS QuantityBalance
	|			FROM
	|				AccumulationRegister.OrdersPlacement.Balance(
	|						&ControlTime,
	|						(Company, CustomerOrder, ProductsAndServices, Characteristic, SupplySource) In
	|							(SELECT
	|								TableInventory.Company AS Company,
	|								TableInventory.CustomerOrder AS CustomerOrder,
	|								TableInventory.ProductsAndServices AS ProductsAndServices,
	|								TableInventory.Characteristic AS Characteristic,
	|								TableInventory.StructuralUnit AS SupplySource
	|							FROM
	|								TemporaryTableInventorySource AS TableInventory
	|							WHERE
	|								(VALUETYPE(TableInventory.StructuralUnit) = Type(Document.CustomerOrder)
	|										AND TableInventory.StructuralUnit <> VALUE(Document.CustomerOrder.EmptyRef)
	|									OR VALUETYPE(TableInventory.StructuralUnit) = Type(Document.ProductionOrder)
	|										AND TableInventory.StructuralUnit <> VALUE(Document.ProductionOrder.EmptyRef)
	|									OR VALUETYPE(TableInventory.StructuralUnit) = Type(Document.PurchaseOrder)
	|										AND TableInventory.StructuralUnit <> VALUE(Document.PurchaseOrder.EmptyRef)))) AS OrdersPlacementBalances
			
	|			GROUP BY
	|				OrdersPlacementBalances.Company,
	|				OrdersPlacementBalances.CustomerOrder,
	|				OrdersPlacementBalances.ProductsAndServices,
	|				OrdersPlacementBalances.Characteristic,
	|				OrdersPlacementBalances.SupplySource
			
	|			UNION ALL
			
	|			SELECT
	|				DocumentRegisterRecordsOrdersPlacement.Company,
	|				DocumentRegisterRecordsOrdersPlacement.CustomerOrder,
	|				DocumentRegisterRecordsOrdersPlacement.ProductsAndServices,
	|				DocumentRegisterRecordsOrdersPlacement.Characteristic,
	|				DocumentRegisterRecordsOrdersPlacement.SupplySource,
	|				CASE
	|					WHEN DocumentRegisterRecordsOrdersPlacement.RecordType = VALUE(AccumulationRecordType.Expense)
	|						THEN ISNULL(DocumentRegisterRecordsOrdersPlacement.Quantity, 0)
	|					ELSE -ISNULL(DocumentRegisterRecordsOrdersPlacement.Quantity, 0)
	|				END
	|			FROM
	|				AccumulationRegister.OrdersPlacement AS DocumentRegisterRecordsOrdersPlacement
	|			WHERE
	|				DocumentRegisterRecordsOrdersPlacement.Recorder = &Ref
	|				AND DocumentRegisterRecordsOrdersPlacement.Period <= &ControlPeriod
	|				AND DocumentRegisterRecordsOrdersPlacement.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)) AS OrdersPlacementBalances
		
	|		GROUP BY
	|			OrdersPlacementBalances.Company,
	|			OrdersPlacementBalances.CustomerOrder,
	|			OrdersPlacementBalances.ProductsAndServices,
	|			OrdersPlacementBalances.Characteristic,
	|			OrdersPlacementBalances.SupplySource) AS OrdersPlacementBalances
	|		ON TableInventory.Company = OrdersPlacementBalances.Company
	|			AND TableInventory.ProductsAndServices = OrdersPlacementBalances.ProductsAndServices
	|			AND TableInventory.Characteristic = OrdersPlacementBalances.Characteristic
	|			AND TableInventory.StructuralUnit = OrdersPlacementBalances.SupplySource
	|WHERE
	|	(VALUETYPE(TableInventory.StructuralUnit) = Type(Document.CustomerOrder)
	|				AND TableInventory.StructuralUnit <> VALUE(Document.CustomerOrder.EmptyRef)
	|			OR VALUETYPE(TableInventory.StructuralUnit) = Type(Document.ProductionOrder)
	|				AND TableInventory.StructuralUnit <> VALUE(Document.ProductionOrder.EmptyRef)
	|			OR VALUETYPE(TableInventory.StructuralUnit) = Type(Document.PurchaseOrder)
	|				AND TableInventory.StructuralUnit <> VALUE(Document.PurchaseOrder.EmptyRef))";
	
	Query.SetParameter("Ref", DocumentRefInventoryReservation);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableOrdersPlacement", QueryResult.Unload());
	
EndProcedure // GenerateInventoryTableSource()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventorySource(DocumentRefInventoryReservation, StructureAdditionalProperties)
	
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
	|	TemporaryTableInventorySource AS TableInventory
	|WHERE
	|	VALUETYPE(TableInventory.StructuralUnit) = Type(Catalog.StructuralUnits)
	|	AND TableInventory.StructuralUnit <> VALUE(Catalog.StructuralUnits.EmptyRef)
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
	|						TemporaryTableInventorySource AS TableInventory
	|					WHERE
	|						VALUETYPE(TableInventory.StructuralUnit) = Type(Catalog.StructuralUnits)
	|						AND TableInventory.StructuralUnit <> VALUE(Catalog.StructuralUnits.EmptyRef))) AS InventoryBalances
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
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod
	|		AND DocumentRegisterRecordsInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.CustomerOrder";
	
	Query.SetParameter("Ref", DocumentRefInventoryReservation);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch,CustomerOrder");
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventorySource.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventorySource[n];
		
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
	
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityWanted;
			
			// Receipt.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
					
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
			TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
			TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
			TableRowReceipt.Batch = RowTableInventory.BatchCorr;
			TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					
			TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
			TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
			TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
			TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
			TableRowReceipt.BatchCorr = RowTableInventory.Batch;
			TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerOrder;
					
			TableRowReceipt.Amount = AmountToBeWrittenOff;
			TableRowReceipt.Quantity = QuantityWanted;
				
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowReceipt.RecordKindManagerial = AccountingRecordType.Debit;
					
		EndIf;
		
	EndDo;
	
EndProcedure // GenerateInventoryTableSource()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryRecipient(DocumentRefInventoryReservation, StructureAdditionalProperties)
	
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
	|	TemporaryTableInventoryRecipient AS TableInventory
	|WHERE
	|	VALUETYPE(TableInventory.StructuralUnit) = Type(Catalog.StructuralUnits)
	|	AND TableInventory.StructuralUnit <> VALUE(Catalog.StructuralUnits.EmptyRef)
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
	|						TemporaryTableInventoryRecipient AS TableInventory
	|					WHERE
	|						VALUETYPE(TableInventory.StructuralUnit) = Type(Catalog.StructuralUnits)
	|						AND TableInventory.StructuralUnit <> VALUE(Catalog.StructuralUnits.EmptyRef))) AS InventoryBalances
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
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod
	|		AND DocumentRegisterRecordsInventory.CustomerOrder = VALUE(Document.CustomerOrder.EmptyRef)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.CustomerOrder";
	
	Query.SetParameter("Ref", DocumentRefInventoryReservation);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch,CustomerOrder");
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryRecipient.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryRecipient[n];
		
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
	
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityWanted;
			
			// Receipt.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
					
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
			TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
			TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
			TableRowReceipt.Batch = RowTableInventory.BatchCorr;
			TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					
			TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
			TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
			TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
			TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
			TableRowReceipt.BatchCorr = RowTableInventory.Batch;
			TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerOrder;
					
			TableRowReceipt.Amount = AmountToBeWrittenOff;
			TableRowReceipt.Quantity = QuantityWanted;
				
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowReceipt.RecordKindManagerial = AccountingRecordType.Debit;
					
		EndIf;
		
	EndDo;
	
EndProcedure // GenerateInventoryTableRecipient()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefInventoryReservation, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	InventoryReservationInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	InventoryReservationInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryReservationInventory.OriginalReservePlace AS StructuralUnit,
	|	CASE
	|		WHEN InventoryReservationInventory.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryReservationInventory.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryReservationInventory.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryReservationInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN VALUETYPE(InventoryReservationInventory.OriginalReservePlace) = Type(Catalog.StructuralUnits)
	|					THEN CASE
	|							WHEN InventoryReservationInventory.OriginalReservePlace.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|								THEN InventoryReservationInventory.ProductsAndServices.InventoryGLAccount
	|							ELSE InventoryReservationInventory.ProductsAndServices.ExpensesGLAccount
	|						END
	|				ELSE InventoryReservationInventory.ProductsAndServices.InventoryGLAccount
	|			END
	|	END AS GLAccount,
	|	InventoryReservationInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryReservationInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryReservationInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	InventoryReservationInventory.Ref.CustomerOrder AS CustomerOrder,
	|	VALUE(Document.CustomerOrder.EmptyRef) AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(InventoryReservationInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryReservationInventory.Quantity
	|		ELSE InventoryReservationInventory.Quantity * InventoryReservationInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindManagerial,
	|	&InventoryReservation AS ContentOfAccountingRecord
	|INTO TemporaryTableInventorySource
	|FROM
	|	Document.InventoryReservation.Inventory AS InventoryReservationInventory
	|WHERE
	|	InventoryReservationInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.GLAccount AS CorrGLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.ProductsAndServices AS ProductsAndServicesCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Characteristic AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Batch AS BatchCorr,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	TableInventory.RecordKindManagerial AS RecordKindManagerial,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableInventorySource AS TableInventory
	|WHERE
	|	VALUETYPE(TableInventory.StructuralUnit) = Type(Catalog.StructuralUnits)
	|	AND TableInventory.StructuralUnit <> VALUE(Catalog.StructuralUnits.EmptyRef)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.RecordKindManagerial
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryReservationInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	InventoryReservationInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryReservationInventory.NewReservePlace AS StructuralUnit,
	|	CASE
	|		WHEN InventoryReservationInventory.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryReservationInventory.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryReservationInventory.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryReservationInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN VALUETYPE(InventoryReservationInventory.NewReservePlace) = Type(Catalog.StructuralUnits)
	|					THEN CASE
	|							WHEN InventoryReservationInventory.NewReservePlace.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|								THEN InventoryReservationInventory.ProductsAndServices.InventoryGLAccount
	|							ELSE InventoryReservationInventory.ProductsAndServices.ExpensesGLAccount
	|						END
	|				ELSE InventoryReservationInventory.ProductsAndServices.InventoryGLAccount
	|			END
	|	END AS GLAccount,
	|	InventoryReservationInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryReservationInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryReservationInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder,
	|	InventoryReservationInventory.Ref.CustomerOrder AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(InventoryReservationInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryReservationInventory.Quantity
	|		ELSE InventoryReservationInventory.Quantity * InventoryReservationInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindManagerial,
	|	&InventoryReservation AS ContentOfAccountingRecord
	|INTO TemporaryTableInventoryRecipient
	|FROM
	|	Document.InventoryReservation.Inventory AS InventoryReservationInventory
	|WHERE
	|	InventoryReservationInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.GLAccount AS CorrGLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.ProductsAndServices AS ProductsAndServicesCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Characteristic AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Batch AS BatchCorr,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	TableInventory.RecordKindManagerial AS RecordKindManagerial,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableInventoryRecipient AS TableInventory
	|WHERE
	|	VALUETYPE(TableInventory.StructuralUnit) = Type(Catalog.StructuralUnits)
	|	AND TableInventory.StructuralUnit <> VALUE(Catalog.StructuralUnits.EmptyRef)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.RecordKindManagerial
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS SupplySource,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CustomerCorrOrder AS CustomerOrder,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventoryRecipient AS TableInventory
	|WHERE
	|	(VALUETYPE(TableInventory.StructuralUnit) = Type(Document.CustomerOrder)
	|				AND TableInventory.StructuralUnit <> VALUE(Document.CustomerOrder.EmptyRef)
	|			OR VALUETYPE(TableInventory.StructuralUnit) = Type(Document.ProductionOrder)
	|				AND TableInventory.StructuralUnit <> VALUE(Document.ProductionOrder.EmptyRef)
	|			OR VALUETYPE(TableInventory.StructuralUnit) = Type(Document.PurchaseOrder)
	|				AND TableInventory.StructuralUnit <> VALUE(Document.PurchaseOrder.EmptyRef))
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.CustomerCorrOrder";
	
	Query.SetParameter("Ref", DocumentRefInventoryReservation);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("InventoryReservation", NStr("en = 'Inventory reservation'"));

	ResultsArray = Query.ExecuteBatch();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventorySource", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryRecipient", ResultsArray[3].Unload());
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", StructureAdditionalProperties.TableForRegisterRecords.TableInventorySource.CopyColumns());
	
	// Inventory reservation.
	GenerateTableInventorySource(DocumentRefInventoryReservation, StructureAdditionalProperties);
	GenerateTableInventoryRecipient(DocumentRefInventoryReservation, StructureAdditionalProperties);
	
	// Placement of the orders.
	GenerateTableOrdersPlacement(DocumentRefInventoryReservation, StructureAdditionalProperties);
	
	// Complete the table of orders placement.
	ResultsSelection = ResultsArray[4].Select();
	While ResultsSelection.Next() Do
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableOrdersPlacement.Add();
		FillPropertyValues(TableRowReceipt, ResultsSelection);
	EndDo;
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefInventoryReservation, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the temporary tables
	// "RegisterRecordsOrdersPlacementChange", "RegisterRecordsInventoryChange" contain records, it is required to execute the inventory control.
	
	If StructureTemporaryTables.RegisterRecordsOrdersPlacementChange
		OR StructureTemporaryTables.RegisterRecordsInventoryChange Then
		
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
		|	RegisterRecordsOrdersPlacementChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.CustomerOrder) AS CustomerOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.SupplySource) AS SupplySourcePresentation,
		|	REFPRESENTATION(OrdersPlacementBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsOrdersPlacementChange.QuantityChange, 0) + ISNULL(OrdersPlacementBalances.QuantityBalance, 0) AS BalanceOrdersPlacement,
		|	ISNULL(OrdersPlacementBalances.QuantityBalance, 0) AS QuantityBalanceOrdersPlacement
		|FROM
		|	RegisterRecordsOrdersPlacementChange AS RegisterRecordsOrdersPlacementChange
		|		LEFT JOIN AccumulationRegister.OrdersPlacement.Balance(
		|				&ControlTime,
		|				(Company, CustomerOrder, ProductsAndServices, Characteristic, SupplySource) In
		|					(SELECT
		|						RegisterRecordsOrdersPlacementChange.Company AS Company,
		|						RegisterRecordsOrdersPlacementChange.CustomerOrder AS CustomerOrder,
		|						RegisterRecordsOrdersPlacementChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsOrdersPlacementChange.Characteristic AS Characteristic,
		|						RegisterRecordsOrdersPlacementChange.SupplySource AS SupplySource
		|					FROM
		|						RegisterRecordsOrdersPlacementChange AS RegisterRecordsOrdersPlacementChange)) AS OrdersPlacementBalances
		|		ON RegisterRecordsOrdersPlacementChange.Company = OrdersPlacementBalances.Company
		|			AND RegisterRecordsOrdersPlacementChange.CustomerOrder = OrdersPlacementBalances.CustomerOrder
		|			AND RegisterRecordsOrdersPlacementChange.ProductsAndServices = OrdersPlacementBalances.ProductsAndServices
		|			AND RegisterRecordsOrdersPlacementChange.Characteristic = OrdersPlacementBalances.Characteristic
		|			AND RegisterRecordsOrdersPlacementChange.SupplySource = OrdersPlacementBalances.SupplySource
		|WHERE
		|	ISNULL(OrdersPlacementBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");

		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectInventoryReservation = DocumentRefInventoryReservation.GetObject()
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectInventoryReservation, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on inventory placement.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToOrdersPlacementRegisterErrors(DocumentObjectInventoryReservation, QueryResultSelection, Cancel);
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