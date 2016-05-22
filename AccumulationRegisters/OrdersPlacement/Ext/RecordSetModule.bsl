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
	LockItem = Block.Add("AccumulationRegister.OrdersPlacement.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsOrdersPlacementChange") OR
		StructureTemporaryTables.Property("RegisterRecordsOrdersPlacementChange") AND Not StructureTemporaryTables.RegisterRecordsOrdersPlacementChange Then
		
		// If the temporary table "RegisterRecordsOrdersPlacementChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsOrdersPlacementBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	OrdersPlacement.LineNumber AS LineNumber,
		|	OrdersPlacement.Company AS Company,
		|	OrdersPlacement.CustomerOrder AS CustomerOrder,
		|	OrdersPlacement.ProductsAndServices AS ProductsAndServices,
		|	OrdersPlacement.Characteristic AS Characteristic,
		|	OrdersPlacement.SupplySource AS SupplySource,
		|	CASE
		|		WHEN OrdersPlacement.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN OrdersPlacement.Quantity
		|		ELSE -OrdersPlacement.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsOrdersPlacementBeforeWrite
		|FROM
		|	AccumulationRegister.OrdersPlacement AS OrdersPlacement
		|WHERE
		|	OrdersPlacement.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsOrdersPlacementChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsOrdersPlacementBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsOrdersPlacementChange.LineNumber AS LineNumber,
		|	RegisterRecordsOrdersPlacementChange.Company AS Company,
		|	RegisterRecordsOrdersPlacementChange.CustomerOrder AS CustomerOrder,
		|	RegisterRecordsOrdersPlacementChange.ProductsAndServices AS ProductsAndServices,
		|	RegisterRecordsOrdersPlacementChange.Characteristic AS Characteristic,
		|	RegisterRecordsOrdersPlacementChange.SupplySource AS SupplySource,
		|	RegisterRecordsOrdersPlacementChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsOrdersPlacementBeforeWrite
		|FROM
		|	RegisterRecordsOrdersPlacementChange AS RegisterRecordsOrdersPlacementChange
		|
		|UNION ALL
		|
		|SELECT
		|	OrdersPlacement.LineNumber,
		|	OrdersPlacement.Company,
		|	OrdersPlacement.CustomerOrder,
		|	OrdersPlacement.ProductsAndServices,
		|	OrdersPlacement.Characteristic,
		|	OrdersPlacement.SupplySource,
		|	CASE
		|		WHEN OrdersPlacement.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN OrdersPlacement.Quantity
		|		ELSE -OrdersPlacement.Quantity
		|	END
		|FROM
		|	AccumulationRegister.OrdersPlacement AS OrdersPlacement
		|WHERE
		|	OrdersPlacement.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsOrdersPlacementChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsOrdersPlacementChange") Then
		
		Query = New Query("DROP RegisterRecordsOrdersPlacementChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsOrdersPlacementChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsOrdersPlacementChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsOrdersPlacementChange.LineNumber) AS LineNumber,
	|	RegisterRecordsOrdersPlacementChange.Company AS Company,
	|	RegisterRecordsOrdersPlacementChange.CustomerOrder AS CustomerOrder,
	|	RegisterRecordsOrdersPlacementChange.ProductsAndServices AS ProductsAndServices,
	|	RegisterRecordsOrdersPlacementChange.Characteristic AS Characteristic,
	|	RegisterRecordsOrdersPlacementChange.SupplySource AS SupplySource,
	|	SUM(RegisterRecordsOrdersPlacementChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsOrdersPlacementChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsOrdersPlacementChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsOrdersPlacementChange
	|FROM
	|	(SELECT
	|		RegisterRecordsOrdersPlacementBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsOrdersPlacementBeforeWrite.Company AS Company,
	|		RegisterRecordsOrdersPlacementBeforeWrite.CustomerOrder AS CustomerOrder,
	|		RegisterRecordsOrdersPlacementBeforeWrite.ProductsAndServices AS ProductsAndServices,
	|		RegisterRecordsOrdersPlacementBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsOrdersPlacementBeforeWrite.SupplySource AS SupplySource,
	|		RegisterRecordsOrdersPlacementBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsOrdersPlacementBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsOrdersPlacementBeforeWrite AS RegisterRecordsOrdersPlacementBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsOrdersPlacementOnWrite.LineNumber,
	|		RegisterRecordsOrdersPlacementOnWrite.Company,
	|		RegisterRecordsOrdersPlacementOnWrite.CustomerOrder,
	|		RegisterRecordsOrdersPlacementOnWrite.ProductsAndServices,
	|		RegisterRecordsOrdersPlacementOnWrite.Characteristic,
	|		RegisterRecordsOrdersPlacementOnWrite.SupplySource,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsOrdersPlacementOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsOrdersPlacementOnWrite.Quantity
	|			ELSE RegisterRecordsOrdersPlacementOnWrite.Quantity
	|		END,
	|		RegisterRecordsOrdersPlacementOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.OrdersPlacement AS RegisterRecordsOrdersPlacementOnWrite
	|	WHERE
	|		RegisterRecordsOrdersPlacementOnWrite.Recorder = &Recorder) AS RegisterRecordsOrdersPlacementChange
	|
	|GROUP BY
	|	RegisterRecordsOrdersPlacementChange.Company,
	|	RegisterRecordsOrdersPlacementChange.CustomerOrder,
	|	RegisterRecordsOrdersPlacementChange.ProductsAndServices,
	|	RegisterRecordsOrdersPlacementChange.Characteristic,
	|	RegisterRecordsOrdersPlacementChange.SupplySource
	|
	|HAVING
	|	SUM(RegisterRecordsOrdersPlacementChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	CustomerOrder,
	|	ProductsAndServices,
	|	Characteristic,
	|	SupplySource");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsOrdersPlacementChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsOrdersPlacementChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsOrdersPlacementBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsOrdersPlacementBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf