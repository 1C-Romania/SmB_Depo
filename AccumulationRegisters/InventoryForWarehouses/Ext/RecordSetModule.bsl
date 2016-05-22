#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite record set.
//
Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
  OR Not AdditionalProperties.Property("ForPosting")
  OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of current registrar record set.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryForWarehouses.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsInventoryForWarehousesChange") OR
		StructureTemporaryTables.Property("RegisterRecordsInventoryForWarehousesChange") AND Not StructureTemporaryTables.RegisterRecordsInventoryForWarehousesChange Then
		
		// If the temporary table "RegisterRecordsInventoryForWarehousesChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsInventoryForWarehousesBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	InventoryForWarehouses.LineNumber AS LineNumber,
		|	InventoryForWarehouses.Company AS Company,
		|	InventoryForWarehouses.StructuralUnit AS StructuralUnit,
		|	InventoryForWarehouses.ProductsAndServices AS ProductsAndServices,
		|	InventoryForWarehouses.Characteristic AS Characteristic,
		|	InventoryForWarehouses.Batch AS Batch,
		|	CASE
		|		WHEN InventoryForWarehouses.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryForWarehouses.Quantity
		|		ELSE -InventoryForWarehouses.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsInventoryForWarehousesBeforeWrite
		|FROM
		|	AccumulationRegister.InventoryForWarehouses AS InventoryForWarehouses
		|WHERE
		|	InventoryForWarehouses.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsInventoryForWarehousesChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsInventoryForWarehousesBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryForWarehousesChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryForWarehousesChange.Company AS Company,
		|	RegisterRecordsInventoryForWarehousesChange.StructuralUnit AS StructuralUnit,
		|	RegisterRecordsInventoryForWarehousesChange.ProductsAndServices AS ProductsAndServices,
		|	RegisterRecordsInventoryForWarehousesChange.Characteristic AS Characteristic,
		|	RegisterRecordsInventoryForWarehousesChange.Batch AS Batch,
		|	RegisterRecordsInventoryForWarehousesChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsInventoryForWarehousesBeforeWrite
		|FROM
		|	RegisterRecordsInventoryForWarehousesChange AS RegisterRecordsInventoryForWarehousesChange
		|
		|UNION ALL
		|
		|SELECT
		|	InventoryForWarehouses.LineNumber,
		|	InventoryForWarehouses.Company,
		|	InventoryForWarehouses.StructuralUnit,
		|	InventoryForWarehouses.ProductsAndServices,
		|	InventoryForWarehouses.Characteristic,
		|	InventoryForWarehouses.Batch,
		|	CASE
		|		WHEN InventoryForWarehouses.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryForWarehouses.Quantity
		|		ELSE -InventoryForWarehouses.Quantity
		|	END
		|FROM
		|	AccumulationRegister.InventoryForWarehouses AS InventoryForWarehouses
		|WHERE
		|	InventoryForWarehouses.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsInventoryForWarehousesChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsInventoryForWarehousesChange") Then
		
		Query = New Query("DELETE RegisterRecordsInventoryForWarehousesChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsInventoryForWarehousesChange");
	
	EndIf;
	
EndProcedure // BeforeWrite()

// Procedure - event handler OnWrite record set.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
  OR Not AdditionalProperties.Property("ForPosting")
  OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// New set change is calculated relatively current with accounting
	// accumulated changes and placed into temporary table "RegisterRecordsInventoryForWarehousesChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsInventoryForWarehousesChange.LineNumber) AS LineNumber,
	|	RegisterRecordsInventoryForWarehousesChange.Company AS Company,
	|	RegisterRecordsInventoryForWarehousesChange.StructuralUnit AS StructuralUnit,
	|	RegisterRecordsInventoryForWarehousesChange.ProductsAndServices AS ProductsAndServices,
	|	RegisterRecordsInventoryForWarehousesChange.Characteristic AS Characteristic,
	|	RegisterRecordsInventoryForWarehousesChange.Batch AS Batch,
	|	SUM(RegisterRecordsInventoryForWarehousesChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsInventoryForWarehousesChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsInventoryForWarehousesChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsInventoryForWarehousesChange
	|FROM
	|	(SELECT
	|		RegisterRecordsInventoryForWarehousesBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsInventoryForWarehousesBeforeWrite.Company AS Company,
	|		RegisterRecordsInventoryForWarehousesBeforeWrite.StructuralUnit AS StructuralUnit,
	|		RegisterRecordsInventoryForWarehousesBeforeWrite.ProductsAndServices AS ProductsAndServices,
	|		RegisterRecordsInventoryForWarehousesBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsInventoryForWarehousesBeforeWrite.Batch AS Batch,
	|		RegisterRecordsInventoryForWarehousesBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsInventoryForWarehousesBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsInventoryForWarehousesBeforeWrite AS RegisterRecordsInventoryForWarehousesBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsInventoryForWarehousesOnWrite.LineNumber,
	|		RegisterRecordsInventoryForWarehousesOnWrite.Company,
	|		RegisterRecordsInventoryForWarehousesOnWrite.StructuralUnit,
	|		RegisterRecordsInventoryForWarehousesOnWrite.ProductsAndServices,
	|		RegisterRecordsInventoryForWarehousesOnWrite.Characteristic,
	|		RegisterRecordsInventoryForWarehousesOnWrite.Batch,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryForWarehousesOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryForWarehousesOnWrite.Quantity
	|			ELSE RegisterRecordsInventoryForWarehousesOnWrite.Quantity
	|		END,
	|		RegisterRecordsInventoryForWarehousesOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.InventoryForWarehouses AS RegisterRecordsInventoryForWarehousesOnWrite
	|	WHERE
	|		RegisterRecordsInventoryForWarehousesOnWrite.Recorder = &Recorder) AS RegisterRecordsInventoryForWarehousesChange
	|
	|GROUP BY
	|	RegisterRecordsInventoryForWarehousesChange.Company,
	|	RegisterRecordsInventoryForWarehousesChange.StructuralUnit,
	|	RegisterRecordsInventoryForWarehousesChange.ProductsAndServices,
	|	RegisterRecordsInventoryForWarehousesChange.Characteristic,
	|	RegisterRecordsInventoryForWarehousesChange.Batch
	|
	|HAVING
	|	SUM(RegisterRecordsInventoryForWarehousesChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsInventoryForWarehousesChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsInventoryForWarehousesChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsInventoryForWarehousesBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsInventoryForWarehousesBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf