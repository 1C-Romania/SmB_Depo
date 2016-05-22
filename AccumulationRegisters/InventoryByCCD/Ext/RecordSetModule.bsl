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
	LockItem = Block.Add("AccumulationRegister.InventoryByCCD.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsInventoryByCCDChange") OR
		StructureTemporaryTables.Property("RegisterRecordsInventoryByCCDChange") AND Not StructureTemporaryTables.RegisterRecordsInventoryByCCDChange Then
		
		// If the temporary table "RegisterRecordsInventoryByCCDChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsInventoryByCCDBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	InventoryByCCD.LineNumber AS LineNumber,
		|	InventoryByCCD.Company AS Company,
		|	InventoryByCCD.CountryOfOrigin AS CountryOfOrigin,
		|	InventoryByCCD.ProductsAndServices AS ProductsAndServices,
		|	InventoryByCCD.Characteristic AS Characteristic,
		|	InventoryByCCD.Batch AS Batch,
		|	InventoryByCCD.CCDNo AS CCDNo,
		|	CASE
		|		WHEN InventoryByCCD.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryByCCD.Quantity
		|		ELSE -InventoryByCCD.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsInventoryByCCDBeforeWrite
		|FROM
		|	AccumulationRegister.InventoryByCCD AS InventoryByCCD
		|WHERE
		|	InventoryByCCD.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsInventoryByCCDChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsInventoryByCCDBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryByCCDChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryByCCDChange.Company AS Company,
		|	RegisterRecordsInventoryByCCDChange.CountryOfOrigin AS CountryOfOrigin,
		|	RegisterRecordsInventoryByCCDChange.ProductsAndServices AS ProductsAndServices,
		|	RegisterRecordsInventoryByCCDChange.Characteristic AS Characteristic,
		|	RegisterRecordsInventoryByCCDChange.Batch AS Batch,
		|	RegisterRecordsInventoryByCCDChange.CCDNo AS CCDNo,
		|	RegisterRecordsInventoryByCCDChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsInventoryByCCDBeforeWrite
		|FROM
		|	RegisterRecordsInventoryByCCDChange AS RegisterRecordsInventoryByCCDChange
		|
		|UNION ALL
		|
		|SELECT
		|	InventoryByCCD.LineNumber,
		|	InventoryByCCD.Company,
		|	InventoryByCCD.CountryOfOrigin,
		|	InventoryByCCD.ProductsAndServices,
		|	InventoryByCCD.Characteristic,
		|	InventoryByCCD.Batch,
		|	InventoryByCCD.CCDNo,
		|	CASE
		|		WHEN InventoryByCCD.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryByCCD.Quantity
		|		ELSE -InventoryByCCD.Quantity
		|	END
		|FROM
		|	AccumulationRegister.InventoryByCCD AS InventoryByCCD
		|WHERE
		|	InventoryByCCD.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsInventoryByCCDChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsInventoryByCCDChange") Then
		
		Query = New Query("DROP RegisterRecordsInventoryByCCDChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsInventoryByCCDChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsInventoryByCCDChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsInventoryByCCDChange.LineNumber) AS LineNumber,
	|	RegisterRecordsInventoryByCCDChange.Company AS Company,
	|	RegisterRecordsInventoryByCCDChange.CountryOfOrigin AS CountryOfOrigin,
	|	RegisterRecordsInventoryByCCDChange.ProductsAndServices AS ProductsAndServices,
	|	RegisterRecordsInventoryByCCDChange.Characteristic AS Characteristic,
	|	RegisterRecordsInventoryByCCDChange.Batch AS Batch,
	|	RegisterRecordsInventoryByCCDChange.CCDNo AS CCDNo,
	|	SUM(RegisterRecordsInventoryByCCDChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsInventoryByCCDChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsInventoryByCCDChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsInventoryByCCDChange
	|FROM
	|	(SELECT
	|		RegisterRecordsInventoryByCCDBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsInventoryByCCDBeforeWrite.Company AS Company,
	|		RegisterRecordsInventoryByCCDBeforeWrite.CountryOfOrigin AS CountryOfOrigin,
	|		RegisterRecordsInventoryByCCDBeforeWrite.ProductsAndServices AS ProductsAndServices,
	|		RegisterRecordsInventoryByCCDBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsInventoryByCCDBeforeWrite.Batch AS Batch,
	|		RegisterRecordsInventoryByCCDBeforeWrite.CCDNo AS CCDNo,
	|		RegisterRecordsInventoryByCCDBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsInventoryByCCDBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsInventoryByCCDBeforeWrite AS RegisterRecordsInventoryByCCDBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsInventoryByCCDOnWrite.LineNumber,
	|		RegisterRecordsInventoryByCCDOnWrite.Company,
	|		RegisterRecordsInventoryByCCDOnWrite.CountryOfOrigin,
	|		RegisterRecordsInventoryByCCDOnWrite.ProductsAndServices,
	|		RegisterRecordsInventoryByCCDOnWrite.Characteristic,
	|		RegisterRecordsInventoryByCCDOnWrite.Batch,
	|		RegisterRecordsInventoryByCCDOnWrite.CCDNo,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryByCCDOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryByCCDOnWrite.Quantity
	|			ELSE RegisterRecordsInventoryByCCDOnWrite.Quantity
	|		END,
	|		RegisterRecordsInventoryByCCDOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.InventoryByCCD AS RegisterRecordsInventoryByCCDOnWrite
	|	WHERE
	|		RegisterRecordsInventoryByCCDOnWrite.Recorder = &Recorder) AS RegisterRecordsInventoryByCCDChange
	|
	|GROUP BY
	|	RegisterRecordsInventoryByCCDChange.Company,
	|	RegisterRecordsInventoryByCCDChange.CountryOfOrigin,
	|	RegisterRecordsInventoryByCCDChange.ProductsAndServices,
	|	RegisterRecordsInventoryByCCDChange.Characteristic,
	|	RegisterRecordsInventoryByCCDChange.Batch,
	|	RegisterRecordsInventoryByCCDChange.CCDNo
	|
	|HAVING
	|	SUM(RegisterRecordsInventoryByCCDChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	CountryOfOrigin,
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch,
	|	CCDNo");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsInventoryByCCDChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsInventoryByCCDChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsInventoryByCCDBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsInventoryByCCDBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf