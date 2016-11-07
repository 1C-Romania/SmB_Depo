#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure calculates and writes the schedule of order execution.
// Shipping date is specified in "Period". Upon the actual shipment by order,
// the schedule is closed according to FIFO.
//
Procedure CalculateOrdersFulfilmentSchedule()
	
	OrdersTable = AdditionalProperties.OrdersTable;
	Query = New Query;
	Query.SetParameter("OrdersArray", OrdersTable.UnloadColumn("CustomerOrder"));
	Query.Text =
	"SELECT
	|	CustomerOrdersBalances.Company AS Company,
	|	CustomerOrdersBalances.CustomerOrder AS CustomerOrder,
	|	CustomerOrdersBalances.ProductsAndServices AS ProductsAndServices,
	|	CustomerOrdersBalances.Characteristic AS Characteristic,
	|	CustomerOrdersBalances.QuantityBalance AS QuantityBalance
	|INTO TU_Balance
	|FROM
	|	AccumulationRegister.CustomerOrders.Balance(, CustomerOrder IN (&OrdersArray)) AS CustomerOrdersBalances
	|
	|INDEX BY
	|	Company,
	|	CustomerOrder,
	|	ProductsAndServices,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN Table.ShipmentDate = DATETIME(1, 1, 1)
	|			THEN BEGINOFPERIOD(Table.Period, Day)
	|		ELSE BEGINOFPERIOD(Table.ShipmentDate, Day)
	|	END AS Period,
	|	Table.Company AS Company,
	|	Table.CustomerOrder AS CustomerOrder,
	|	Table.ProductsAndServices AS ProductsAndServices,
	|	Table.Characteristic AS Characteristic,
	|	SUM(Table.Quantity) AS QuantityPlan
	|INTO TU_RegisterRecordPlan
	|FROM
	|	AccumulationRegister.CustomerOrders AS Table
	|WHERE
	|	Table.CustomerOrder IN(&OrdersArray)
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|	AND Table.Active
	|
	|GROUP BY
	|	CASE
	|		WHEN Table.ShipmentDate = DATETIME(1, 1, 1)
	|			THEN BEGINOFPERIOD(Table.Period, Day)
	|		ELSE BEGINOFPERIOD(Table.ShipmentDate, Day)
	|	END,
	|	Table.Company,
	|	Table.CustomerOrder,
	|	Table.ProductsAndServices,
	|	Table.Characteristic
	|
	|INDEX BY
	|	Company,
	|	CustomerOrder,
	|	ProductsAndServices,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_Table.Period AS Period,
	|	TU_Table.Company AS Company,
	|	TU_Table.CustomerOrder AS CustomerOrder,
	|	TU_Table.ProductsAndServices AS ProductsAndServices,
	|	TU_Table.Characteristic AS Characteristic,
	|	TU_Table.QuantityPlan AS QuantityPlan,
	|	ISNULL(TU_Balance.QuantityBalance, 0) AS QuantityBalance
	|FROM
	|	TU_RegisterRecordPlan AS TU_Table
	|		LEFT JOIN TU_Balance AS TU_Balance
	|		ON TU_Table.Company = TU_Balance.Company
	|			AND TU_Table.CustomerOrder = TU_Balance.CustomerOrder
	|			AND TU_Table.ProductsAndServices = TU_Balance.ProductsAndServices
	|			AND TU_Table.Characteristic = TU_Balance.Characteristic
	|
	|ORDER BY
	|	CustomerOrder,
	|	ProductsAndServices,
	|	Characteristic,
	|	Period DESC";
	
	RecordSet = InformationRegisters.OrderFulfillmentSchedule.CreateRecordSet();
	Selection = Query.Execute().Select();
	ThereAreRecordsInSelection = Selection.Next();
	While ThereAreRecordsInSelection Do
		
		CurPeriod = Undefined;
		CurCompany = Undefined;
		CurProductsAndServices = Undefined;
		CurCharacteristic = Undefined;
		CurCustomerOrder = Selection.CustomerOrder;
		
		RecordSet.Filter.Order.Set(CurCustomerOrder);
		
		// Delete the closed order from the table.
		OrdersTable.Delete(OrdersTable.Find(CurCustomerOrder, "CustomerOrder"));
		
		// Cycle by single order strings.
		TotalPlan = 0;
		TotalBalance = 0;
		StructureRecordSet = New Structure;
		While ThereAreRecordsInSelection AND Selection.CustomerOrder = CurCustomerOrder Do
			
			TotalPlan = TotalPlan + Selection.QuantityPlan;
			
			If CurProductsAndServices <> Selection.ProductsAndServices
				OR CurCharacteristic <> Selection.Characteristic
				OR CurCompany <> Selection.Company Then
				
				CurProductsAndServices = Selection.ProductsAndServices;
				CurCharacteristic = Selection.Characteristic;
				CurCompany = Selection.Company;
				
				TotalQuantityBalance = 0;
				If Selection.QuantityBalance > 0 Then
					TotalQuantityBalance = Selection.QuantityBalance;
				EndIf;
				
				TotalBalance = TotalBalance + Selection.QuantityBalance;
				
			EndIf;
			
			CurQuantity = min(Selection.QuantityPlan, TotalQuantityBalance);
			If CurQuantity > 0 AND ?(ValueIsFilled(CurPeriod), CurPeriod > Selection.Period, True) Then
				
				StructureRecordSet.Insert("Period", Selection.Period);
				StructureRecordSet.Insert("CustomerOrder", Selection.CustomerOrder);
				
				CurPeriod = Selection.Period;
				
			EndIf;
			
			TotalQuantityBalance = TotalQuantityBalance - CurQuantity;
			
			// Go to the next record in the selection.
			ThereAreRecordsInSelection = Selection.Next();
			
		EndDo;
		
		// Writing and clearing the set.
		If StructureRecordSet.Count() > 0 Then
			Record = RecordSet.Add();
			Record.Period = StructureRecordSet.Period;
			Record.Order = StructureRecordSet.CustomerOrder;
			Record.Completed = TotalPlan - TotalBalance;
		EndIf;
		
		RecordSet.Write(True);
		RecordSet.Clear();
		
	EndDo;
	
	// The register records should be cleared for unfinished orders.
	If OrdersTable.Count() > 0 Then
		For Each TabRow IN OrdersTable Do
			
			RecordSet.Filter.Order.Set(TabRow.CustomerOrder);
			RecordSet.Write(True);
			RecordSet.Clear();
			
		EndDo;
	EndIf;
	
EndProcedure // CalculateOrderPerformanceSchedule()

// Procedure forms the table of orders that were
// previously in the register records and which will be written now.
//
Procedure GenerateTableOfOrders()
	
	Query = New Query;
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.Text =
	"SELECT DISTINCT
	|	TableCustomerOrders.CustomerOrder AS CustomerOrder
	|FROM
	|	AccumulationRegister.CustomerOrders AS TableCustomerOrders
	|WHERE
	|	TableCustomerOrders.Recorder = &Recorder";
	
	OrdersTable = Query.Execute().Unload();
	TableOfNewOrders = Unload(, "CustomerOrder");
	TableOfNewOrders.GroupBy("CustomerOrder");
	For Each Record IN TableOfNewOrders Do
		
		If OrdersTable.Find(Record.CustomerOrder, "CustomerOrder") = Undefined Then
			OrdersTable.Add().CustomerOrder = Record.CustomerOrder;
		EndIf;
		
	EndDo;
	
	AdditionalProperties.Insert("OrdersTable", OrdersTable);
	
EndProcedure // GenerateTableOfOrders()

// Procedure locks data for schedule calculation.
//
Procedure InstallLocksOnDataForCalculatingSchedule()
	
	Block = New DataLock;
	
	// Locking the register for balance calculation by orders.
	LockItem = Block.Add("AccumulationRegister.CustomerOrders");
	LockItem.Mode = DataLockMode.Shared;
	LockItem.DataSource = AdditionalProperties.OrdersTable;
	LockItem.UseFromDataSource("CustomerOrder", "CustomerOrder");
	
	// Locking the record set.
	LockItem = Block.Add("InformationRegister.OrderFulfillmentSchedule");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = AdditionalProperties.OrdersTable;
	LockItem.UseFromDataSource("Order", "CustomerOrder");
	
	Block.Lock();
	
EndProcedure // InstallLocksOnDataForCalculatingSchedule()

// Procedure forms the table of initial records of the register.
//
Procedure GenerateSourceRecordsTable(Cancel, Replacing)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of the current set of records of the registrar.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.CustomerOrders.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsCustomerOrdersChange") OR
		StructureTemporaryTables.Property("RegisterRecordsCustomerOrdersChange") AND Not StructureTemporaryTables.RegisterRecordsCustomerOrdersChange Then
		
		// If the "RegisterRecordsCustomerOrdersChange" temporary table does not exist and
		// does not contain records on change of the set, it means that the set is written for the first time, and the set was controlled for balances.
		// Current state of the set is placed into the "RegisterRecordsCustomerOrdersBeforeWrite" temporary table
		// to get the change of a new set with respect to the current set when writing.
		
		Query = New Query(
		"SELECT
		|	CustomerOrders.LineNumber AS LineNumber,
		|	CustomerOrders.Company AS Company,
		|	CustomerOrders.CustomerOrder AS CustomerOrder,
		|	CustomerOrders.ProductsAndServices AS ProductsAndServices,
		|	CustomerOrders.Characteristic AS Characteristic,
		|	CASE
		|		WHEN CustomerOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN CustomerOrders.Quantity
		|		ELSE -CustomerOrders.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsCustomerOrdersBeforeWrite
		|FROM
		|	AccumulationRegister.CustomerOrders AS CustomerOrders
		|WHERE
		|	CustomerOrders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the "RegisterRecordsCustomerOrdersChange" temporary table exists and
		// contains records about the set change, it means the set is written not for the first time and the set was not controlled for balances.
		// Current state of the set and current state of changes are placed into the "RegisterRecordsCustomerOrdersBeforeWrite" temporary table
		// to get the change of a new set with respect to the initial set when writing.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsCustomerOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsCustomerOrdersChange.Company AS Company,
		|	RegisterRecordsCustomerOrdersChange.CustomerOrder AS CustomerOrder,
		|	RegisterRecordsCustomerOrdersChange.ProductsAndServices AS ProductsAndServices,
		|	RegisterRecordsCustomerOrdersChange.Characteristic AS Characteristic,
		|	RegisterRecordsCustomerOrdersChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsCustomerOrdersBeforeWrite
		|FROM
		|	RegisterRecordsCustomerOrdersChange AS RegisterRecordsCustomerOrdersChange
		|
		|UNION ALL
		|
		|SELECT
		|	CustomerOrders.LineNumber,
		|	CustomerOrders.Company,
		|	CustomerOrders.CustomerOrder,
		|	CustomerOrders.ProductsAndServices,
		|	CustomerOrders.Characteristic,
		|	CASE
		|		WHEN CustomerOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN CustomerOrders.Quantity
		|		ELSE -CustomerOrders.Quantity
		|	END
		|FROM
		|	AccumulationRegister.CustomerOrders AS CustomerOrders
		|WHERE
		|	CustomerOrders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table "RegisterRecordsCustomerOrdersChange" is deleted
	// Information related to its existence is deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsCustomerOrdersChange") Then
		
		Query = New Query("DROP RegisterRecordsCustomerOrdersChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsCustomerOrdersChange");
		
	EndIf;
	
EndProcedure // GenerateSourceRegisterRecordTable()

// Procedure forms the table of change records of the register.
//
Procedure GenerateRecordsChangeTable(Cancel, Replacing)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Change of a new set is calculated with respect to current one, taking into account the accumulated changes,
	// and the set is placed into the "RegisterRecordsCustomerOrdersChange" temporary table.
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsCustomerOrdersChange.LineNumber) AS LineNumber,
	|	RegisterRecordsCustomerOrdersChange.Company AS Company,
	|	RegisterRecordsCustomerOrdersChange.CustomerOrder AS CustomerOrder,
	|	RegisterRecordsCustomerOrdersChange.ProductsAndServices AS ProductsAndServices,
	|	RegisterRecordsCustomerOrdersChange.Characteristic AS Characteristic,
	|	SUM(RegisterRecordsCustomerOrdersChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsCustomerOrdersChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsCustomerOrdersChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsCustomerOrdersChange
	|FROM
	|	(SELECT
	|		RegisterRecordsCustomerOrdersBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsCustomerOrdersBeforeWrite.Company AS Company,
	|		RegisterRecordsCustomerOrdersBeforeWrite.CustomerOrder AS CustomerOrder,
	|		RegisterRecordsCustomerOrdersBeforeWrite.ProductsAndServices AS ProductsAndServices,
	|		RegisterRecordsCustomerOrdersBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsCustomerOrdersBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsCustomerOrdersBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsCustomerOrdersBeforeWrite AS RegisterRecordsCustomerOrdersBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsCustomerOrdersOnWrite.LineNumber,
	|		RegisterRecordsCustomerOrdersOnWrite.Company,
	|		RegisterRecordsCustomerOrdersOnWrite.CustomerOrder,
	|		RegisterRecordsCustomerOrdersOnWrite.ProductsAndServices,
	|		RegisterRecordsCustomerOrdersOnWrite.Characteristic,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsCustomerOrdersOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsCustomerOrdersOnWrite.Quantity
	|			ELSE RegisterRecordsCustomerOrdersOnWrite.Quantity
	|		END,
	|		RegisterRecordsCustomerOrdersOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.CustomerOrders AS RegisterRecordsCustomerOrdersOnWrite
	|	WHERE
	|		RegisterRecordsCustomerOrdersOnWrite.Recorder = &Recorder) AS RegisterRecordsCustomerOrdersChange
	|
	|GROUP BY
	|	RegisterRecordsCustomerOrdersChange.Company,
	|	RegisterRecordsCustomerOrdersChange.CustomerOrder,
	|	RegisterRecordsCustomerOrdersChange.ProductsAndServices,
	|	RegisterRecordsCustomerOrdersChange.Characteristic
	|
	|HAVING
	|	SUM(RegisterRecordsCustomerOrdersChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	CustomerOrder,
	|	ProductsAndServices,
	|	Characteristic");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsCustomerOrdersChange".
	// The information on its existence and change records availability in it is added.
	StructureTemporaryTables.Insert("RegisterRecordsCustomerOrdersChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsInventoryInWarehousesBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsCustomerOrdersBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // GenerateRegisterRecordChangeTable()

#EndRegion

#Region EventsHandlers

// Procedure - event handler BeforeWrite record set.
//
Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	GenerateSourceRecordsTable(Cancel, Replacing);
	
	GenerateTableOfOrders();
	InstallLocksOnDataForCalculatingSchedule();
	
EndProcedure // BeforeWrite()

// Procedure - event handler OnWrite record set.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	GenerateRecordsChangeTable(Cancel, Replacing);
	
	CalculateOrdersFulfilmentSchedule();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf