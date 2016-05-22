#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure calculates and writes the schedule of order execution.
// Shipping date is specified in "Period". Upon the actual shipment by order,
// the schedule is closed according to FIFO.
//
Procedure CalculateOrdersFulfilmentSchedule()
	
	OrdersTable = AdditionalProperties.OrdersTable;
	Query = New Query;
	Query.SetParameter("OrdersArray", OrdersTable.UnloadColumn("PurchaseOrder"));
	Query.Text =
	"SELECT
	|	PurchaseOrdersBalances.Company AS Company,
	|	PurchaseOrdersBalances.PurchaseOrder AS PurchaseOrder,
	|	PurchaseOrdersBalances.ProductsAndServices AS ProductsAndServices,
	|	PurchaseOrdersBalances.Characteristic AS Characteristic,
	|	PurchaseOrdersBalances.QuantityBalance AS QuantityBalance
	|INTO TU_Balance
	|FROM
	|	AccumulationRegister.PurchaseOrders.Balance(, PurchaseOrder IN (&OrdersArray)) AS PurchaseOrdersBalances
	|
	|INDEX BY
	|	Company,
	|	PurchaseOrder,
	|	ProductsAndServices,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BEGINOFPERIOD(Table.ReceiptDate, Day) AS Period,
	|	Table.Company AS Company,
	|	Table.PurchaseOrder AS PurchaseOrder,
	|	Table.ProductsAndServices AS ProductsAndServices,
	|	Table.Characteristic AS Characteristic,
	|	SUM(Table.Quantity) AS QuantityPlan
	|INTO TU_RegisterRecordPlan
	|FROM
	|	AccumulationRegister.PurchaseOrders AS Table
	|WHERE
	|	Table.PurchaseOrder IN(&OrdersArray)
	|	AND Table.ReceiptDate <> DATETIME(1, 1, 1)
	|	AND Table.Quantity > 0
	|	AND Table.Active
	|
	|GROUP BY
	|	BEGINOFPERIOD(Table.ReceiptDate, Day),
	|	Table.Company,
	|	Table.PurchaseOrder,
	|	Table.ProductsAndServices,
	|	Table.Characteristic
	|
	|INDEX BY
	|	Company,
	|	PurchaseOrder,
	|	ProductsAndServices,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_Table.Period AS Period,
	|	TU_Table.Company AS Company,
	|	TU_Table.PurchaseOrder AS PurchaseOrder,
	|	TU_Table.ProductsAndServices AS ProductsAndServices,
	|	TU_Table.Characteristic AS Characteristic,
	|	TU_Table.QuantityPlan AS QuantityPlan,
	|	ISNULL(TU_Balance.QuantityBalance, 0) AS QuantityBalance
	|FROM
	|	TU_RegisterRecordPlan AS TU_Table
	|		LEFT JOIN TU_Balance AS TU_Balance
	|		ON TU_Table.Company = TU_Balance.Company
	|			AND TU_Table.PurchaseOrder = TU_Balance.PurchaseOrder
	|			AND TU_Table.ProductsAndServices = TU_Balance.ProductsAndServices
	|			AND TU_Table.Characteristic = TU_Balance.Characteristic
	|
	|ORDER BY
	|	PurchaseOrder,
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
		CurPurchaseOrder = Selection.PurchaseOrder;
		
		PeriodsList = New ValueList;
		
		RecordSet.Filter.Order.Set(CurPurchaseOrder);
		
		// Delete the closed order from the table.
		OrdersTable.Delete(OrdersTable.Find(CurPurchaseOrder, "PurchaseOrder"));
		
		// Cycle by single order strings.
		TotalPlan = 0;
		TotalBalance = 0;
		StructureRecordSet = New Structure;
		While ThereAreRecordsInSelection AND Selection.PurchaseOrder = CurPurchaseOrder Do
			
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
				StructureRecordSet.Insert("PurchaseOrder", Selection.PurchaseOrder);
				
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
			Record.Order = StructureRecordSet.PurchaseOrder;
			Record.Completed = TotalPlan - TotalBalance;
		EndIf;
		
		RecordSet.Write(True);
		RecordSet.Clear();
		
	EndDo;
	
	// The register records should be cleared for unfinished orders.
	If OrdersTable.Count() > 0 Then
		For Each TabRow IN OrdersTable Do
			
			RecordSet.Filter.Order.Set(TabRow.PurchaseOrder);
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
	|	TablePurchaseOrders.PurchaseOrder AS PurchaseOrder
	|FROM
	|	AccumulationRegister.PurchaseOrders AS TablePurchaseOrders
	|WHERE
	|	TablePurchaseOrders.Recorder = &Recorder";
	
	OrdersTable = Query.Execute().Unload();
	TableOfNewOrders = Unload(, "PurchaseOrder");
	TableOfNewOrders.GroupBy("PurchaseOrder");
	For Each Record IN TableOfNewOrders Do
		
		If OrdersTable.Find(Record.PurchaseOrder, "PurchaseOrder") = Undefined Then
			OrdersTable.Add().PurchaseOrder = Record.PurchaseOrder;
		EndIf;
		
	EndDo;
	
	AdditionalProperties.Insert("OrdersTable", OrdersTable);
	
EndProcedure // GenerateTableOfOrders()

// Procedure locks data for schedule calculation.
//
Procedure InstallLocksOnDataForCalculatingSchedule()
	
	Block = New DataLock;
	
	// Locking the register for balance calculation by orders.
	LockItem = Block.Add("AccumulationRegister.PurchaseOrders");
	LockItem.Mode = DataLockMode.Shared;
	LockItem.DataSource = AdditionalProperties.OrdersTable;
	LockItem.UseFromDataSource("PurchaseOrder", "PurchaseOrder");
	
	// Locking the record set.
	LockItem = Block.Add("InformationRegister.OrderFulfillmentSchedule");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = AdditionalProperties.OrdersTable;
	LockItem.UseFromDataSource("Order", "PurchaseOrder");
	
	Block.Lock();
	
EndProcedure // InstallLocksOnDataForCalculatingSchedule()

// Procedure forms the table of initial records of the register.
//
Procedure GenerateSourceRecordsTable(Cancel, Replacing)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of the current set of records of the registrar.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.PurchaseOrders.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsPurchaseOrdersChange") OR
		StructureTemporaryTables.Property("RegisterRecordsPurchaseOrdersChange") AND Not StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange Then
		
		// If the "RegisterRecordsPurchaseOrdersChange" temporary table does not exist and does not contain records
		// on changes of the set, it means that the set is written for the first time, and the set was controlled for balances.
		// The state of the current set is placed into the "RegisterRecordsPurchaseOrdersBeforeWrite" temporary table
		// to get the change of a new set with respect to the current one.
		
		Query = New Query(
		"SELECT
		|	PurchaseOrders.LineNumber AS LineNumber,
		|	PurchaseOrders.Company AS Company,
		|	PurchaseOrders.PurchaseOrder AS PurchaseOrder,
		|	PurchaseOrders.ProductsAndServices AS ProductsAndServices,
		|	PurchaseOrders.Characteristic AS Characteristic,
		|	CASE
		|		WHEN PurchaseOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN PurchaseOrders.Quantity
		|		ELSE -PurchaseOrders.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsPurchaseOrdersBeforeWrite
		|FROM
		|	AccumulationRegister.PurchaseOrders AS PurchaseOrders
		|WHERE
		|	PurchaseOrders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the "RegisterRecordsCustomerOrdersChange" temporary table exists and contains records on changes of the set,
		// it means the set is written not for the first time and the set was not controlled for balances.
		// Current state of the set and current state of changes are placed into the "RegisterRecordsCustomerOrdersBeforeWrite" temporary table
		// to get the change of a new set with respect to the initial set when writing.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsPurchaseOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsPurchaseOrdersChange.Company AS Company,
		|	RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS PurchaseOrder,
		|	RegisterRecordsPurchaseOrdersChange.ProductsAndServices AS ProductsAndServices,
		|	RegisterRecordsPurchaseOrdersChange.Characteristic AS Characteristic,
		|	RegisterRecordsPurchaseOrdersChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsPurchaseOrdersBeforeWrite
		|FROM
		|	RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange
		|
		|UNION ALL
		|
		|SELECT
		|	PurchaseOrders.LineNumber,
		|	PurchaseOrders.Company,
		|	PurchaseOrders.PurchaseOrder,
		|	PurchaseOrders.ProductsAndServices,
		|	PurchaseOrders.Characteristic,
		|	CASE
		|		WHEN PurchaseOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN PurchaseOrders.Quantity
		|		ELSE -PurchaseOrders.Quantity
		|	END
		|FROM
		|	AccumulationRegister.PurchaseOrders AS PurchaseOrders
		|WHERE
		|	PurchaseOrders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// The "RegisterRecordsPurchaseOrdersChange" temporary table is deleted
	// Information on its existence is deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsPurchaseOrdersChange") Then
		
		Query = New Query("DROP RegisterRecordsPurchaseOrdersChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsPurchaseOrdersChange");
	
	EndIf;
	
EndProcedure // GenerateSourceRegisterRecordTable()

// Procedure forms the table of change records of the register.
//
Procedure GenerateRecordsChangeTable(Cancel, Replacing)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Change of a new set is calculated with respect to current one taking into account the accumulated changes,
	// and it is placed into the "RegisterRecordsPurchaseOrdersChange" temporary table.
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsPurchaseOrdersChange.LineNumber) AS LineNumber,
	|	RegisterRecordsPurchaseOrdersChange.Company AS Company,
	|	RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS PurchaseOrder,
	|	RegisterRecordsPurchaseOrdersChange.ProductsAndServices AS ProductsAndServices,
	|	RegisterRecordsPurchaseOrdersChange.Characteristic AS Characteristic,
	|	SUM(RegisterRecordsPurchaseOrdersChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsPurchaseOrdersChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsPurchaseOrdersChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsPurchaseOrdersChange
	|FROM
	|	(SELECT
	|		RegisterRecordsPurchaseOrdersBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsPurchaseOrdersBeforeWrite.Company AS Company,
	|		RegisterRecordsPurchaseOrdersBeforeWrite.PurchaseOrder AS PurchaseOrder,
	|		RegisterRecordsPurchaseOrdersBeforeWrite.ProductsAndServices AS ProductsAndServices,
	|		RegisterRecordsPurchaseOrdersBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsPurchaseOrdersBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsPurchaseOrdersBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsPurchaseOrdersBeforeWrite AS RegisterRecordsPurchaseOrdersBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsPurchaseOrdersOnWrite.LineNumber,
	|		RegisterRecordsPurchaseOrdersOnWrite.Company,
	|		RegisterRecordsPurchaseOrdersOnWrite.PurchaseOrder,
	|		RegisterRecordsPurchaseOrdersOnWrite.ProductsAndServices,
	|		RegisterRecordsPurchaseOrdersOnWrite.Characteristic,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsPurchaseOrdersOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsPurchaseOrdersOnWrite.Quantity
	|			ELSE RegisterRecordsPurchaseOrdersOnWrite.Quantity
	|		END,
	|		RegisterRecordsPurchaseOrdersOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.PurchaseOrders AS RegisterRecordsPurchaseOrdersOnWrite
	|	WHERE
	|		RegisterRecordsPurchaseOrdersOnWrite.Recorder = &Recorder) AS RegisterRecordsPurchaseOrdersChange
	|
	|GROUP BY
	|	RegisterRecordsPurchaseOrdersChange.Company,
	|	RegisterRecordsPurchaseOrdersChange.PurchaseOrder,
	|	RegisterRecordsPurchaseOrdersChange.ProductsAndServices,
	|	RegisterRecordsPurchaseOrdersChange.Characteristic
	|
	|HAVING
	|	SUM(RegisterRecordsPurchaseOrdersChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	PurchaseOrder,
	|	ProductsAndServices,
	|	Characteristic");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into the "RegisterRecordsPurchaseOrdersChange" temporary table.
	// The information on its existence and change records availability in it is added.
	StructureTemporaryTables.Insert("RegisterRecordsPurchaseOrdersChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsPurchaseOrdersBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsPurchaseOrdersBeforeWrite");
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