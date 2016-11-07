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
	LockItem = Block.Add("AccumulationRegister.InventoryDemand.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsInventoryDemandChange") OR
		StructureTemporaryTables.Property("RegisterRecordsInventoryDemandChange") AND Not StructureTemporaryTables.RegisterRecordsInventoryDemandChange Then
		
		// If the temporary table "RegisterRecordsInventoryDemandChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsInventoryDemandBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	InventoryDemand.LineNumber AS LineNumber,
		|	InventoryDemand.Company AS Company,
		|	InventoryDemand.MovementType AS MovementType,
		|	InventoryDemand.CustomerOrder AS CustomerOrder,
		|	InventoryDemand.ProductsAndServices AS ProductsAndServices,
		|	InventoryDemand.Characteristic AS Characteristic,
		|	CASE
		|		WHEN InventoryDemand.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryDemand.Quantity
		|		ELSE -InventoryDemand.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsInventoryDemandBeforeWrite
		|FROM
		|	AccumulationRegister.InventoryDemand AS InventoryDemand
		|WHERE
		|	InventoryDemand.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsInventoryDemandChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsInventoryDemandBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryDemandChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryDemandChange.Company AS Company,
		|	RegisterRecordsInventoryDemandChange.MovementType AS MovementType,
		|	RegisterRecordsInventoryDemandChange.CustomerOrder AS CustomerOrder,
		|	RegisterRecordsInventoryDemandChange.ProductsAndServices AS ProductsAndServices,
		|	RegisterRecordsInventoryDemandChange.Characteristic AS Characteristic,
		|	RegisterRecordsInventoryDemandChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsInventoryDemandBeforeWrite
		|FROM
		|	RegisterRecordsInventoryDemandChange AS RegisterRecordsInventoryDemandChange
		|
		|UNION ALL
		|
		|SELECT
		|	InventoryDemand.LineNumber,
		|	InventoryDemand.Company,
		|	InventoryDemand.MovementType,
		|	InventoryDemand.CustomerOrder,
		|	InventoryDemand.ProductsAndServices,
		|	InventoryDemand.Characteristic,
		|	CASE
		|		WHEN InventoryDemand.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryDemand.Quantity
		|		ELSE -InventoryDemand.Quantity
		|	END
		|FROM
		|	AccumulationRegister.InventoryDemand AS InventoryDemand
		|WHERE
		|	InventoryDemand.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsInventoryDemandChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsInventoryDemandChange") Then
		
		Query = New Query("DROP RegisterRecordsInventoryDemandChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsInventoryDemandChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsInventoryDemandChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsInventoryDemandChange.LineNumber) AS LineNumber,
	|	RegisterRecordsInventoryDemandChange.Company AS Company,
	|	RegisterRecordsInventoryDemandChange.MovementType AS MovementType,
	|	RegisterRecordsInventoryDemandChange.CustomerOrder AS CustomerOrder,
	|	RegisterRecordsInventoryDemandChange.ProductsAndServices AS ProductsAndServices,
	|	RegisterRecordsInventoryDemandChange.Characteristic AS Characteristic,
	|	SUM(RegisterRecordsInventoryDemandChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsInventoryDemandChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsInventoryDemandChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsInventoryDemandChange
	|FROM
	|	(SELECT
	|		RegisterRecordsInventoryDemandBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsInventoryDemandBeforeWrite.Company AS Company,
	|		RegisterRecordsInventoryDemandBeforeWrite.MovementType AS MovementType,
	|		RegisterRecordsInventoryDemandBeforeWrite.CustomerOrder AS CustomerOrder,
	|		RegisterRecordsInventoryDemandBeforeWrite.ProductsAndServices AS ProductsAndServices,
	|		RegisterRecordsInventoryDemandBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsInventoryDemandBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsInventoryDemandBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsInventoryDemandBeforeWrite AS RegisterRecordsInventoryDemandBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsInventoryDemandOnWrite.LineNumber,
	|		RegisterRecordsInventoryDemandOnWrite.Company,
	|		RegisterRecordsInventoryDemandOnWrite.MovementType,
	|		RegisterRecordsInventoryDemandOnWrite.CustomerOrder,
	|		RegisterRecordsInventoryDemandOnWrite.ProductsAndServices,
	|		RegisterRecordsInventoryDemandOnWrite.Characteristic,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryDemandOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryDemandOnWrite.Quantity
	|			ELSE RegisterRecordsInventoryDemandOnWrite.Quantity
	|		END,
	|		RegisterRecordsInventoryDemandOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.InventoryDemand AS RegisterRecordsInventoryDemandOnWrite
	|	WHERE
	|		RegisterRecordsInventoryDemandOnWrite.Recorder = &Recorder) AS RegisterRecordsInventoryDemandChange
	|
	|GROUP BY
	|	RegisterRecordsInventoryDemandChange.Company,
	|	RegisterRecordsInventoryDemandChange.MovementType,
	|	RegisterRecordsInventoryDemandChange.CustomerOrder,
	|	RegisterRecordsInventoryDemandChange.ProductsAndServices,
	|	RegisterRecordsInventoryDemandChange.Characteristic
	|
	|HAVING
	|	SUM(RegisterRecordsInventoryDemandChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	MovementType,
	|	CustomerOrder,
	|	ProductsAndServices,
	|	Characteristic");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsInventoryDemandChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsInventoryDemandChange", QueryResultSelection.Count > 0);
	
	// Temporary table "RegisterRecordsInventoryDemandBeforeWrite" is destroyed
	Query = New Query("DROP RegisterRecordsInventoryDemandBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf