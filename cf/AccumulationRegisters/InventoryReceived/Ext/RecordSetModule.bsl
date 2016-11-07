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
	LockItem = Block.Add("AccumulationRegister.InventoryReceived.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsInventoryReceivedChange") OR
		StructureTemporaryTables.Property("RegisterRecordsInventoryReceivedChange") AND Not StructureTemporaryTables.RegisterRecordsInventoryReceivedChange Then
		
		// If the temporary table "RegisterRecordsInventoryReceivedChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsInventoryBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	InventoryReceived.LineNumber AS LineNumber,
		|	InventoryReceived.Company AS Company,
		|	InventoryReceived.ProductsAndServices AS ProductsAndServices,
		|	InventoryReceived.Characteristic AS Characteristic,
		|	InventoryReceived.Batch AS Batch,
		|	InventoryReceived.Counterparty AS Counterparty,
		|	InventoryReceived.Contract AS Contract,
		|	InventoryReceived.Order AS Order,
		|	InventoryReceived.ReceptionTransmissionType AS ReceptionTransmissionType,
		|	CASE
		|		WHEN InventoryReceived.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryReceived.Quantity
		|		ELSE -InventoryReceived.Quantity
		|	END AS QuantityBeforeWrite,
		|	CASE
		|		WHEN InventoryReceived.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryReceived.SettlementsAmount
		|		ELSE -InventoryReceived.SettlementsAmount
		|	END AS AmountSettlementsBeforeWrite
		|INTO RegisterRecordsInventoryReceivedBeforeWrite
		|FROM
		|	AccumulationRegister.InventoryReceived AS InventoryReceived
		|WHERE
		|	InventoryReceived.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsInventoryReceivedChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsInventoryBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryReceivedChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryReceivedChange.Company AS Company,
		|	RegisterRecordsInventoryReceivedChange.ProductsAndServices AS ProductsAndServices,
		|	RegisterRecordsInventoryReceivedChange.Characteristic AS Characteristic,
		|	RegisterRecordsInventoryReceivedChange.Batch AS Batch,
		|	RegisterRecordsInventoryReceivedChange.Counterparty AS Counterparty,
		|	RegisterRecordsInventoryReceivedChange.Contract AS Contract,
		|	RegisterRecordsInventoryReceivedChange.Order AS Order,
		|	RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType AS ReceptionTransmissionType,
		|	RegisterRecordsInventoryReceivedChange.QuantityBeforeWrite AS QuantityBeforeWrite,
		|	RegisterRecordsInventoryReceivedChange.AmountSettlementsBeforeWrite AS AmountSettlementsBeforeWrite
		|INTO RegisterRecordsInventoryReceivedBeforeWrite
		|FROM
		|	RegisterRecordsInventoryReceivedChange AS RegisterRecordsInventoryReceivedChange
		|
		|UNION ALL
		|
		|SELECT
		|	InventoryReceived.LineNumber,
		|	InventoryReceived.Company,
		|	InventoryReceived.ProductsAndServices,
		|	InventoryReceived.Characteristic,
		|	InventoryReceived.Batch,
		|	InventoryReceived.Counterparty,
		|	InventoryReceived.Contract,
		|	InventoryReceived.Order,
		|	InventoryReceived.ReceptionTransmissionType,
		|	CASE
		|		WHEN InventoryReceived.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryReceived.Quantity
		|		ELSE -InventoryReceived.Quantity
		|	END,
		|	CASE
		|		WHEN InventoryReceived.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN InventoryReceived.SettlementsAmount
		|		ELSE -InventoryReceived.SettlementsAmount
		|	END
		|FROM
		|	AccumulationRegister.InventoryReceived AS InventoryReceived
		|WHERE
		|	InventoryReceived.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsInventoryReceivedChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsInventoryReceivedChange") Then
		
		Query = New Query("DROP RegisterRecordsInventoryReceivedChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsInventoryReceivedChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsInventoryReceivedChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsInventoryReceivedChange.LineNumber) AS LineNumber,
	|	RegisterRecordsInventoryReceivedChange.Company AS Company,
	|	RegisterRecordsInventoryReceivedChange.ProductsAndServices AS ProductsAndServices,
	|	RegisterRecordsInventoryReceivedChange.Characteristic AS Characteristic,
	|	RegisterRecordsInventoryReceivedChange.Batch AS Batch,
	|	RegisterRecordsInventoryReceivedChange.Counterparty,
	|	RegisterRecordsInventoryReceivedChange.Contract,
	|	RegisterRecordsInventoryReceivedChange.Order,
	|	RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType AS ReceptionTransmissionType,
	|	SUM(RegisterRecordsInventoryReceivedChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsInventoryReceivedChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsInventoryReceivedChange.QuantityOnWrite) AS QuantityOnWrite,
	|	SUM(RegisterRecordsInventoryReceivedChange.AmountSettlementsBeforeWrite) AS AmountSettlementsBeforeWrite,
	|	SUM(RegisterRecordsInventoryReceivedChange.SettlementsAmountChange) AS SettlementsAmountChange,
	|	SUM(RegisterRecordsInventoryReceivedChange.SettlementsAmountOnWrite) AS SettlementsAmountOnWrite
	|INTO RegisterRecordsInventoryReceivedChange
	|FROM
	|	(SELECT
	|		RegisterRecordsInventoryReceivedBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsInventoryReceivedBeforeWrite.Company AS Company,
	|		RegisterRecordsInventoryReceivedBeforeWrite.ProductsAndServices AS ProductsAndServices,
	|		RegisterRecordsInventoryReceivedBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsInventoryReceivedBeforeWrite.Batch AS Batch,
	|		RegisterRecordsInventoryReceivedBeforeWrite.Counterparty AS Counterparty,
	|		RegisterRecordsInventoryReceivedBeforeWrite.Contract AS Contract,
	|		RegisterRecordsInventoryReceivedBeforeWrite.Order AS Order,
	|		RegisterRecordsInventoryReceivedBeforeWrite.ReceptionTransmissionType AS ReceptionTransmissionType,
	|		RegisterRecordsInventoryReceivedBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsInventoryReceivedBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite,
	|		RegisterRecordsInventoryReceivedBeforeWrite.AmountSettlementsBeforeWrite AS AmountSettlementsBeforeWrite,
	|		RegisterRecordsInventoryReceivedBeforeWrite.AmountSettlementsBeforeWrite AS SettlementsAmountChange,
	|		0 AS SettlementsAmountOnWrite
	|	FROM
	|		RegisterRecordsInventoryReceivedBeforeWrite AS RegisterRecordsInventoryReceivedBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsInventoryReceivedOnWrite.LineNumber,
	|		RegisterRecordsInventoryReceivedOnWrite.Company,
	|		RegisterRecordsInventoryReceivedOnWrite.ProductsAndServices,
	|		RegisterRecordsInventoryReceivedOnWrite.Characteristic,
	|		RegisterRecordsInventoryReceivedOnWrite.Batch,
	|		RegisterRecordsInventoryReceivedOnWrite.Counterparty,
	|		RegisterRecordsInventoryReceivedOnWrite.Contract,
	|		RegisterRecordsInventoryReceivedOnWrite.Order,
	|		RegisterRecordsInventoryReceivedOnWrite.ReceptionTransmissionType,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryReceivedOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryReceivedOnWrite.Quantity
	|			ELSE RegisterRecordsInventoryReceivedOnWrite.Quantity
	|		END,
	|		RegisterRecordsInventoryReceivedOnWrite.Quantity,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryReceivedOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryReceivedOnWrite.SettlementsAmount
	|			ELSE RegisterRecordsInventoryReceivedOnWrite.SettlementsAmount
	|		END,
	|		RegisterRecordsInventoryReceivedOnWrite.SettlementsAmount
	|	FROM
	|		AccumulationRegister.InventoryReceived AS RegisterRecordsInventoryReceivedOnWrite
	|	WHERE
	|		RegisterRecordsInventoryReceivedOnWrite.Recorder = &Recorder) AS RegisterRecordsInventoryReceivedChange
	|
	|GROUP BY
	|	RegisterRecordsInventoryReceivedChange.Company,
	|	RegisterRecordsInventoryReceivedChange.ProductsAndServices,
	|	RegisterRecordsInventoryReceivedChange.Characteristic,
	|	RegisterRecordsInventoryReceivedChange.Batch,
	|	RegisterRecordsInventoryReceivedChange.Counterparty,
	|	RegisterRecordsInventoryReceivedChange.Contract,
	|	RegisterRecordsInventoryReceivedChange.Order,
	|	RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType
	|
	|HAVING
	|	(SUM(RegisterRecordsInventoryReceivedChange.QuantityChange) <> 0
	|		OR SUM(RegisterRecordsInventoryReceivedChange.SettlementsAmountChange) <> 0)
	|
	|INDEX BY
	|	Company,
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch,
	|	RegisterRecordsInventoryReceivedChange.Counterparty,
	|	RegisterRecordsInventoryReceivedChange.Contract,
	|	RegisterRecordsInventoryReceivedChange.Order,
	|	ReceptionTransmissionType");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsInventoryReceivedChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsInventoryReceivedChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsInventoryBeforeWrite" temprorary table is deleted
	Query = New Query("DROP RegisterRecordsInventoryReceivedBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf