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
	LockItem = Block.Add("AccumulationRegister.InventoryInWarehouses.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsInventoryInWarehousesChange") OR
		StructureTemporaryTables.Property("RegisterRecordsInventoryInWarehousesChange") AND Not StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange Then
		
		// If the temporary table "RegisterRecordsInventoryInWarehousesChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsInventoryInWarehousesBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	InventoryInWarehouses.LineNumber AS LineNumber,
		|	InventoryInWarehouses.Company AS Company,
		|	InventoryInWarehouses.StructuralUnit AS StructuralUnit,
		|	InventoryInWarehouses.ProductsAndServices AS ProductsAndServices,
		|	InventoryInWarehouses.Characteristic AS Characteristic,
		|	InventoryInWarehouses.Batch AS Batch,
		|	InventoryInWarehouses.Cell AS Cell,
		|	CASE
		|		WHEN InventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryInWarehouses.Quantity
		|		ELSE -InventoryInWarehouses.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsInventoryInWarehousesBeforeWrite
		|FROM
		|	AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
		|WHERE
		|	InventoryInWarehouses.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsInventoryInWarehousesChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsInventoryInWarehousesBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryInWarehousesChange.Company AS Company,
		|	RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnit,
		|	RegisterRecordsInventoryInWarehousesChange.ProductsAndServices AS ProductsAndServices,
		|	RegisterRecordsInventoryInWarehousesChange.Characteristic AS Characteristic,
		|	RegisterRecordsInventoryInWarehousesChange.Batch AS Batch,
		|	RegisterRecordsInventoryInWarehousesChange.Cell AS Cell,
		|	RegisterRecordsInventoryInWarehousesChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsInventoryInWarehousesBeforeWrite
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|
		|UNION ALL
		|
		|SELECT
		|	InventoryInWarehouses.LineNumber,
		|	InventoryInWarehouses.Company,
		|	InventoryInWarehouses.StructuralUnit,
		|	InventoryInWarehouses.ProductsAndServices,
		|	InventoryInWarehouses.Characteristic,
		|	InventoryInWarehouses.Batch,
		|	InventoryInWarehouses.Cell,
		|	CASE
		|		WHEN InventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryInWarehouses.Quantity
		|		ELSE -InventoryInWarehouses.Quantity
		|	END
		|FROM
		|	AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
		|WHERE
		|	InventoryInWarehouses.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsInventoryInWarehousesChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsInventoryInWarehousesChange") Then
		
		Query = New Query("DELETE RegisterRecordsInventoryInWarehousesChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsInventoryInWarehousesChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsInventoryInWarehousesChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsInventoryInWarehousesChange.LineNumber) AS LineNumber,
	|	RegisterRecordsInventoryInWarehousesChange.Company AS Company,
	|	RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnit,
	|	RegisterRecordsInventoryInWarehousesChange.ProductsAndServices AS ProductsAndServices,
	|	RegisterRecordsInventoryInWarehousesChange.Characteristic AS Characteristic,
	|	RegisterRecordsInventoryInWarehousesChange.Batch AS Batch,
	|	RegisterRecordsInventoryInWarehousesChange.Cell AS Cell,
	|	SUM(RegisterRecordsInventoryInWarehousesChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsInventoryInWarehousesChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsInventoryInWarehousesChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsInventoryInWarehousesChange
	|FROM
	|	(SELECT
	|		RegisterRecordsInventoryInWarehousesBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsInventoryInWarehousesBeforeWrite.Company AS Company,
	|		RegisterRecordsInventoryInWarehousesBeforeWrite.StructuralUnit AS StructuralUnit,
	|		RegisterRecordsInventoryInWarehousesBeforeWrite.ProductsAndServices AS ProductsAndServices,
	|		RegisterRecordsInventoryInWarehousesBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsInventoryInWarehousesBeforeWrite.Batch AS Batch,
	|		RegisterRecordsInventoryInWarehousesBeforeWrite.Cell AS Cell,
	|		RegisterRecordsInventoryInWarehousesBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsInventoryInWarehousesBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsInventoryInWarehousesBeforeWrite AS RegisterRecordsInventoryInWarehousesBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsInventoryInWarehousesOnWrite.LineNumber,
	|		RegisterRecordsInventoryInWarehousesOnWrite.Company,
	|		RegisterRecordsInventoryInWarehousesOnWrite.StructuralUnit,
	|		RegisterRecordsInventoryInWarehousesOnWrite.ProductsAndServices,
	|		RegisterRecordsInventoryInWarehousesOnWrite.Characteristic,
	|		RegisterRecordsInventoryInWarehousesOnWrite.Batch,
	|		RegisterRecordsInventoryInWarehousesOnWrite.Cell,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryInWarehousesOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryInWarehousesOnWrite.Quantity
	|			ELSE RegisterRecordsInventoryInWarehousesOnWrite.Quantity
	|		END,
	|		RegisterRecordsInventoryInWarehousesOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.InventoryInWarehouses AS RegisterRecordsInventoryInWarehousesOnWrite
	|	WHERE
	|		RegisterRecordsInventoryInWarehousesOnWrite.Recorder = &Recorder) AS RegisterRecordsInventoryInWarehousesChange
	|
	|GROUP BY
	|	RegisterRecordsInventoryInWarehousesChange.Company,
	|	RegisterRecordsInventoryInWarehousesChange.StructuralUnit,
	|	RegisterRecordsInventoryInWarehousesChange.ProductsAndServices,
	|	RegisterRecordsInventoryInWarehousesChange.Characteristic,
	|	RegisterRecordsInventoryInWarehousesChange.Batch,
	|	RegisterRecordsInventoryInWarehousesChange.Cell
	|
	|HAVING
	|	SUM(RegisterRecordsInventoryInWarehousesChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch,
	|	Cell");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsInventoryInWarehousesChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsInventoryInWarehousesChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsInventoryInWarehousesBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsInventoryInWarehousesBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf