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
	LockItem = Block.Add("AccumulationRegister.ProductionOrders.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsProductionOrdersChange") OR
		StructureTemporaryTables.Property("RegisterRecordsProductionOrdersChange") AND Not StructureTemporaryTables.RegisterRecordsProductionOrdersChange Then
		
		// If the temporary table "RegisterRecordsProductionOrdersChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsProductionOrdersBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	ProductionOrders.LineNumber AS LineNumber,
		|	ProductionOrders.Company AS Company,
		|	ProductionOrders.ProductionOrder AS ProductionOrder,
		|	ProductionOrders.ProductsAndServices AS ProductsAndServices,
		|	ProductionOrders.Characteristic AS Characteristic,
		|	CASE
		|		WHEN ProductionOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN ProductionOrders.Quantity
		|		ELSE -ProductionOrders.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsProductionOrdersBeforeWrite
		|FROM
		|	AccumulationRegister.ProductionOrders AS ProductionOrders
		|WHERE
		|	ProductionOrders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsProductionOrdersChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsProductionOrdersBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsProductionOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsProductionOrdersChange.Company AS Company,
		|	RegisterRecordsProductionOrdersChange.ProductionOrder AS ProductionOrder,
		|	RegisterRecordsProductionOrdersChange.ProductsAndServices AS ProductsAndServices,
		|	RegisterRecordsProductionOrdersChange.Characteristic AS Characteristic,
		|	RegisterRecordsProductionOrdersChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsProductionOrdersBeforeWrite
		|FROM
		|	RegisterRecordsProductionOrdersChange AS RegisterRecordsProductionOrdersChange
		|
		|UNION ALL
		|
		|SELECT
		|	ProductionOrders.LineNumber,
		|	ProductionOrders.Company,
		|	ProductionOrders.ProductionOrder,
		|	ProductionOrders.ProductsAndServices,
		|	ProductionOrders.Characteristic,
		|	CASE
		|		WHEN ProductionOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN ProductionOrders.Quantity
		|		ELSE -ProductionOrders.Quantity
		|	END
		|FROM
		|	AccumulationRegister.ProductionOrders AS ProductionOrders
		|WHERE
		|	ProductionOrders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsProductionOrdersChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsProductionOrdersChange") Then
		
		Query = New Query("DROP RegisterRecordsProductionOrdersChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsProductionOrdersChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsProductionOrdersChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsProductionOrdersChange.LineNumber) AS LineNumber,
	|	RegisterRecordsProductionOrdersChange.Company AS Company,
	|	RegisterRecordsProductionOrdersChange.ProductionOrder AS ProductionOrder,
	|	RegisterRecordsProductionOrdersChange.ProductsAndServices AS ProductsAndServices,
	|	RegisterRecordsProductionOrdersChange.Characteristic AS Characteristic,
	|	SUM(RegisterRecordsProductionOrdersChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsProductionOrdersChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsProductionOrdersChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsProductionOrdersChange
	|FROM
	|	(SELECT
	|		RegisterRecordsProductionOrdersBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsProductionOrdersBeforeWrite.Company AS Company,
	|		RegisterRecordsProductionOrdersBeforeWrite.ProductionOrder AS ProductionOrder,
	|		RegisterRecordsProductionOrdersBeforeWrite.ProductsAndServices AS ProductsAndServices,
	|		RegisterRecordsProductionOrdersBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsProductionOrdersBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsProductionOrdersBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsProductionOrdersBeforeWrite AS RegisterRecordsProductionOrdersBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsProductionOrdersOnWrite.LineNumber,
	|		RegisterRecordsProductionOrdersOnWrite.Company,
	|		RegisterRecordsProductionOrdersOnWrite.ProductionOrder,
	|		RegisterRecordsProductionOrdersOnWrite.ProductsAndServices,
	|		RegisterRecordsProductionOrdersOnWrite.Characteristic,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsProductionOrdersOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsProductionOrdersOnWrite.Quantity
	|			ELSE RegisterRecordsProductionOrdersOnWrite.Quantity
	|		END,
	|		RegisterRecordsProductionOrdersOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.ProductionOrders AS RegisterRecordsProductionOrdersOnWrite
	|	WHERE
	|		RegisterRecordsProductionOrdersOnWrite.Recorder = &Recorder) AS RegisterRecordsProductionOrdersChange
	|
	|GROUP BY
	|	RegisterRecordsProductionOrdersChange.Company,
	|	RegisterRecordsProductionOrdersChange.ProductionOrder,
	|	RegisterRecordsProductionOrdersChange.ProductsAndServices,
	|	RegisterRecordsProductionOrdersChange.Characteristic
	|
	|HAVING
	|	SUM(RegisterRecordsProductionOrdersChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	ProductionOrder,
	|	ProductsAndServices,
	|	Characteristic");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsProductionOrdersChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsProductionOrdersChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsProductionOrdersBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsProductionOrdersBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf