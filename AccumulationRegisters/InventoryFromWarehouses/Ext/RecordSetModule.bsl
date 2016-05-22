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
	LockItem = Block.Add("AccumulationRegister.InventoryFromWarehouses.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsInventoryFromWarehousesChange") OR
		StructureTemporaryTables.Property("RegisterRecordsInventoryFromWarehousesChange") AND Not StructureTemporaryTables.RegisterRecordsInventoryFromWarehousesChange Then
		
		// If the temporary table "RegisterRecordsInventoryFromWarehousesChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsInventoryFromWarehousesBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	InventoryFromWarehouses.LineNumber AS LineNumber,
		|	InventoryFromWarehouses.Company AS Company,
		|	InventoryFromWarehouses.StructuralUnit AS StructuralUnit,
		|	InventoryFromWarehouses.ProductsAndServices AS ProductsAndServices,
		|	InventoryFromWarehouses.Characteristic AS Characteristic,
		|	InventoryFromWarehouses.Batch AS Batch,
		|	CASE
		|		WHEN InventoryFromWarehouses.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryFromWarehouses.Quantity
		|		ELSE -InventoryFromWarehouses.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsInventoryFromWarehousesBeforeWrite
		|FROM
		|	AccumulationRegister.InventoryFromWarehouses AS InventoryFromWarehouses
		|WHERE
		|	InventoryFromWarehouses.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsInventoryFromWarehousesChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsInventoryFromWarehousesBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryFromWarehousesChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryFromWarehousesChange.Company AS Company,
		|	RegisterRecordsInventoryFromWarehousesChange.StructuralUnit AS StructuralUnit,
		|	RegisterRecordsInventoryFromWarehousesChange.ProductsAndServices AS ProductsAndServices,
		|	RegisterRecordsInventoryFromWarehousesChange.Characteristic AS Characteristic,
		|	RegisterRecordsInventoryFromWarehousesChange.Batch AS Batch,
		|	RegisterRecordsInventoryFromWarehousesChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsInventoryFromWarehousesBeforeWrite
		|FROM
		|	RegisterRecordsInventoryFromWarehousesChange AS RegisterRecordsInventoryFromWarehousesChange
		|
		|UNION ALL
		|
		|SELECT
		|	InventoryFromWarehouses.LineNumber,
		|	InventoryFromWarehouses.Company,
		|	InventoryFromWarehouses.StructuralUnit,
		|	InventoryFromWarehouses.ProductsAndServices,
		|	InventoryFromWarehouses.Characteristic,
		|	InventoryFromWarehouses.Batch,
		|	CASE
		|		WHEN InventoryFromWarehouses.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryFromWarehouses.Quantity
		|		ELSE -InventoryFromWarehouses.Quantity
		|	END
		|FROM
		|	AccumulationRegister.InventoryFromWarehouses AS InventoryFromWarehouses
		|WHERE
		|	InventoryFromWarehouses.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsInventoryFromWarehousesChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsInventoryFromWarehousesChange") Then
		
		Query = New Query("DROP RegisterRecordsInventoryFromWarehousesChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsInventoryFromWarehousesChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsInventoryFromWarehousesChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsInventoryFromWarehousesChange.LineNumber) AS LineNumber,
	|	RegisterRecordsInventoryFromWarehousesChange.Company AS Company,
	|	RegisterRecordsInventoryFromWarehousesChange.StructuralUnit AS StructuralUnit,
	|	RegisterRecordsInventoryFromWarehousesChange.ProductsAndServices AS ProductsAndServices,
	|	RegisterRecordsInventoryFromWarehousesChange.Characteristic AS Characteristic,
	|	RegisterRecordsInventoryFromWarehousesChange.Batch AS Batch,
	|	SUM(RegisterRecordsInventoryFromWarehousesChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsInventoryFromWarehousesChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsInventoryFromWarehousesChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsInventoryFromWarehousesChange
	|FROM
	|	(SELECT
	|		RegisterRecordsInventoryFromWarehousesBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsInventoryFromWarehousesBeforeWrite.Company AS Company,
	|		RegisterRecordsInventoryFromWarehousesBeforeWrite.StructuralUnit AS StructuralUnit,
	|		RegisterRecordsInventoryFromWarehousesBeforeWrite.ProductsAndServices AS ProductsAndServices,
	|		RegisterRecordsInventoryFromWarehousesBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsInventoryFromWarehousesBeforeWrite.Batch AS Batch,
	|		RegisterRecordsInventoryFromWarehousesBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsInventoryFromWarehousesBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsInventoryFromWarehousesBeforeWrite AS RegisterRecordsInventoryFromWarehousesBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsInventoryFromWarehousesOnWrite.LineNumber,
	|		RegisterRecordsInventoryFromWarehousesOnWrite.Company,
	|		RegisterRecordsInventoryFromWarehousesOnWrite.StructuralUnit,
	|		RegisterRecordsInventoryFromWarehousesOnWrite.ProductsAndServices,
	|		RegisterRecordsInventoryFromWarehousesOnWrite.Characteristic,
	|		RegisterRecordsInventoryFromWarehousesOnWrite.Batch,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryFromWarehousesOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryFromWarehousesOnWrite.Quantity
	|			ELSE RegisterRecordsInventoryFromWarehousesOnWrite.Quantity
	|		END,
	|		RegisterRecordsInventoryFromWarehousesOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.InventoryFromWarehouses AS RegisterRecordsInventoryFromWarehousesOnWrite
	|	WHERE
	|		RegisterRecordsInventoryFromWarehousesOnWrite.Recorder = &Recorder) AS RegisterRecordsInventoryFromWarehousesChange
	|
	|GROUP BY
	|	RegisterRecordsInventoryFromWarehousesChange.Company,
	|	RegisterRecordsInventoryFromWarehousesChange.StructuralUnit,
	|	RegisterRecordsInventoryFromWarehousesChange.ProductsAndServices,
	|	RegisterRecordsInventoryFromWarehousesChange.Characteristic,
	|	RegisterRecordsInventoryFromWarehousesChange.Batch
	|
	|HAVING
	|	SUM(RegisterRecordsInventoryFromWarehousesChange.QuantityChange) <> 0
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
	
	// New changes were placed into temporary table "RegisterRecordsInventoryFromWarehousesChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsInventoryFromWarehousesChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsInventoryFromWarehousesBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsInventoryFromWarehousesBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf