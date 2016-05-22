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
	LockItem = Block.Add("AccumulationRegister.InventoryTransferred.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsInventoryTransferredChange") OR
		StructureTemporaryTables.Property("RegisterRecordsInventoryTransferredChange") AND Not StructureTemporaryTables.RegisterRecordsInventoryTransferredChange Then
		
		// If the temporary table "RegisterRecordsTransferredInventoryChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsTransferredInventoryBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	InventoryTransferred.LineNumber AS LineNumber,
		|	InventoryTransferred.Company AS Company,
		|	InventoryTransferred.ProductsAndServices AS ProductsAndServices,
		|	InventoryTransferred.Characteristic AS Characteristic,
		|	InventoryTransferred.Batch AS Batch,
		|	InventoryTransferred.Counterparty AS Counterparty,
		|	InventoryTransferred.Contract AS Contract,
		|	InventoryTransferred.Order AS Order,
		|	InventoryTransferred.ReceptionTransmissionType AS ReceptionTransmissionType,
		|	CASE
		|		WHEN InventoryTransferred.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryTransferred.Quantity
		|		ELSE -InventoryTransferred.Quantity
		|	END AS QuantityBeforeWrite,
		|	CASE
		|		WHEN InventoryTransferred.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryTransferred.SettlementsAmount
		|		ELSE -InventoryTransferred.SettlementsAmount
		|	END AS AmountSettlementsBeforeWrite
		|INTO RegisterRecordsInventoryTransferredBeforeWrite
		|FROM
		|	AccumulationRegister.InventoryTransferred AS InventoryTransferred
		|WHERE
		|	InventoryTransferred.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsTransferredInventoryChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsTransferredInventoryBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryTransferredChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryTransferredChange.Company AS Company,
		|	RegisterRecordsInventoryTransferredChange.ProductsAndServices AS ProductsAndServices,
		|	RegisterRecordsInventoryTransferredChange.Characteristic AS Characteristic,
		|	RegisterRecordsInventoryTransferredChange.Batch AS Batch,
		|	RegisterRecordsInventoryTransferredChange.Counterparty AS Counterparty,
		|	RegisterRecordsInventoryTransferredChange.Contract AS Contract,
		|	RegisterRecordsInventoryTransferredChange.Order AS Order,
		|	RegisterRecordsInventoryTransferredChange.ReceptionTransmissionType AS ReceptionTransmissionType,
		|	RegisterRecordsInventoryTransferredChange.QuantityBeforeWrite AS QuantityBeforeWrite,
		|	RegisterRecordsInventoryTransferredChange.AmountSettlementsBeforeWrite AS AmountSettlementsBeforeWrite
		|INTO RegisterRecordsInventoryTransferredBeforeWrite
		|FROM
		|	RegisterRecordsInventoryTransferredChange AS RegisterRecordsInventoryTransferredChange
		|
		|UNION ALL
		|
		|SELECT
		|	InventoryTransferred.LineNumber,
		|	InventoryTransferred.Company,
		|	InventoryTransferred.ProductsAndServices,
		|	InventoryTransferred.Characteristic,
		|	InventoryTransferred.Batch,
		|	InventoryTransferred.Counterparty,
		|	InventoryTransferred.Contract,
		|	InventoryTransferred.Order,
		|	InventoryTransferred.ReceptionTransmissionType,
		|	CASE
		|		WHEN InventoryTransferred.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryTransferred.Quantity
		|		ELSE -InventoryTransferred.Quantity
		|	END,
		|	CASE
		|		WHEN InventoryTransferred.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryTransferred.SettlementsAmount
		|		ELSE -InventoryTransferred.SettlementsAmount
		|	END
		|FROM
		|	AccumulationRegister.InventoryTransferred AS InventoryTransferred
		|WHERE
		|	InventoryTransferred.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsTransferredInventoryChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsInventoryTransferredChange") Then
		
		Query = New Query("DELETE RegisterRecordsTransferredInventoryChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsInventoryTransferredChange");
		
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
	// accumulated changes and placed into temporary table "RegisterRecordsTransferredInventoryChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsInventoryTransferredChange.LineNumber) AS LineNumber,
	|	RegisterRecordsInventoryTransferredChange.Company AS Company,
	|	RegisterRecordsInventoryTransferredChange.ProductsAndServices AS ProductsAndServices,
	|	RegisterRecordsInventoryTransferredChange.Characteristic AS Characteristic,
	|	RegisterRecordsInventoryTransferredChange.Batch AS Batch,
	|	RegisterRecordsInventoryTransferredChange.Counterparty AS Counterparty,
	|	RegisterRecordsInventoryTransferredChange.Contract AS Contract,
	|	RegisterRecordsInventoryTransferredChange.Order AS Order,
	|	RegisterRecordsInventoryTransferredChange.ReceptionTransmissionType AS ReceptionTransmissionType,
	|	SUM(RegisterRecordsInventoryTransferredChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsInventoryTransferredChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsInventoryTransferredChange.QuantityOnWrite) AS QuantityOnWrite,
	|	SUM(RegisterRecordsInventoryTransferredChange.AmountSettlementsBeforeWrite) AS AmountSettlementsBeforeWrite,
	|	SUM(RegisterRecordsInventoryTransferredChange.SettlementsAmountChange) AS SettlementsAmountChange,
	|	SUM(RegisterRecordsInventoryTransferredChange.SettlementsAmountOnWrite) AS SettlementsAmountOnWrite
	|INTO RegisterRecordsInventoryTransferredChange
	|FROM
	|	(SELECT
	|		RegisterRecordsInventoryTransferredBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsInventoryTransferredBeforeWrite.Company AS Company,
	|		RegisterRecordsInventoryTransferredBeforeWrite.ProductsAndServices AS ProductsAndServices,
	|		RegisterRecordsInventoryTransferredBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsInventoryTransferredBeforeWrite.Batch AS Batch,
	|		RegisterRecordsInventoryTransferredBeforeWrite.Counterparty AS Counterparty,
	|		RegisterRecordsInventoryTransferredBeforeWrite.Contract AS Contract,
	|		RegisterRecordsInventoryTransferredBeforeWrite.Order AS Order,
	|		RegisterRecordsInventoryTransferredBeforeWrite.ReceptionTransmissionType AS ReceptionTransmissionType,
	|		RegisterRecordsInventoryTransferredBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsInventoryTransferredBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite,
	|		RegisterRecordsInventoryTransferredBeforeWrite.AmountSettlementsBeforeWrite AS AmountSettlementsBeforeWrite,
	|		RegisterRecordsInventoryTransferredBeforeWrite.AmountSettlementsBeforeWrite AS SettlementsAmountChange,
	|		0 AS SettlementsAmountOnWrite
	|	FROM
	|		RegisterRecordsInventoryTransferredBeforeWrite AS RegisterRecordsInventoryTransferredBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsInventoryTransferredOnWrite.LineNumber,
	|		RegisterRecordsInventoryTransferredOnWrite.Company,
	|		RegisterRecordsInventoryTransferredOnWrite.ProductsAndServices,
	|		RegisterRecordsInventoryTransferredOnWrite.Characteristic,
	|		RegisterRecordsInventoryTransferredOnWrite.Batch,
	|		RegisterRecordsInventoryTransferredOnWrite.Counterparty,
	|		RegisterRecordsInventoryTransferredOnWrite.Contract,
	|		RegisterRecordsInventoryTransferredOnWrite.Order,
	|		RegisterRecordsInventoryTransferredOnWrite.ReceptionTransmissionType,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryTransferredOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryTransferredOnWrite.Quantity
	|			ELSE RegisterRecordsInventoryTransferredOnWrite.Quantity
	|		END,
	|		RegisterRecordsInventoryTransferredOnWrite.Quantity,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryTransferredOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryTransferredOnWrite.SettlementsAmount
	|			ELSE RegisterRecordsInventoryTransferredOnWrite.SettlementsAmount
	|		END,
	|		RegisterRecordsInventoryTransferredOnWrite.SettlementsAmount
	|	FROM
	|		AccumulationRegister.InventoryTransferred AS RegisterRecordsInventoryTransferredOnWrite
	|	WHERE
	|		RegisterRecordsInventoryTransferredOnWrite.Recorder = &Recorder) AS RegisterRecordsInventoryTransferredChange
	|
	|GROUP BY
	|	RegisterRecordsInventoryTransferredChange.Company,
	|	RegisterRecordsInventoryTransferredChange.ProductsAndServices,
	|	RegisterRecordsInventoryTransferredChange.Characteristic,
	|	RegisterRecordsInventoryTransferredChange.Batch,
	|	RegisterRecordsInventoryTransferredChange.Counterparty,
	|	RegisterRecordsInventoryTransferredChange.Contract,
	|	RegisterRecordsInventoryTransferredChange.Order,
	|	RegisterRecordsInventoryTransferredChange.ReceptionTransmissionType
	|
	|HAVING
	|	(SUM(RegisterRecordsInventoryTransferredChange.QuantityChange) <> 0
	|		OR SUM(RegisterRecordsInventoryTransferredChange.SettlementsAmountChange) <> 0)
	|
	|INDEX BY
	|	Company,
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch,
	|	Counterparty,
	|	Contract,
	|	Order,
	|	ReceptionTransmissionType");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsTransferredInventoryChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsInventoryTransferredChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsTransferredInventoryBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsInventoryTransferredBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf