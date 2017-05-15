#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - handler events Recordset BeforeWrite.
//
Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR NOT AdditionalProperties.Property("ForPosting")
		OR NOT AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Set an exclusive lock on the current set of records Registrar.
	Lock = New DataLock;
	LockItem = Lock.Add("AccumulationRegister.SerialNumbers.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Lock.Lock();
	
	If NOT StructureTemporaryTables.Property("RegisterRecordsSerialNumbersChange") OR
		StructureTemporaryTables.Property("RegisterRecordsSerialNumbersChange") AND NOT StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then
		
		// If the "RegisterRecordsSerialNumbersGuaranteesChange" temporary table does not exists
		// or does not contain records on the set change, it means that the set is written for the first time or the set was controlled for balances.
		// Current state of the set is placed
		// into the "RegisterRecordsSerialNumbersGuaranteesBeforeWrite" temporary table in order to get the change of a new set with respect to the current one when writing.
		
		Query = New Query(
		"SELECT
		|	SerialNumbers.LineNumber AS LineNumber,
		|	SerialNumbers.ProductsAndServices AS ProductsAndServices,
		|	SerialNumbers.Characteristic AS Characteristic,
		|	SerialNumbers.Batch AS Batch,
		|	SerialNumbers.SerialNumber AS SerialNumber,
		|	SerialNumbers.StructuralUnit AS StructuralUnit,
		|	SerialNumbers.Cell AS Cell,
		|	CASE
		|		WHEN SerialNumbers.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN SerialNumbers.Quantity
		|		ELSE -SerialNumbers.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsSerialNumbersBeforeWrite
		|FROM
		|	AccumulationRegister.SerialNumbers AS SerialNumbers
		|WHERE
		|	SerialNumbers.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the "RegisterRecordsSerialNumbersGuaranteesChange" temporary table exists and
		// contains records on the set change, it means that the set is written not for the first time, and the set was not controlled for balances.
		// Current state of the set and current state of changes are
		// placed into the "RegisterRecordsSerialNumbersGuaranteesBeforeWrite" temporary table in order to get the change of a new set with respect to the initial one when writing.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsSerialNumbersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSerialNumbersChange.ProductsAndServices AS ProductsAndServices,
		|	RegisterRecordsSerialNumbersChange.Characteristic AS Characteristic,
		|	RegisterRecordsSerialNumbersChange.Batch AS Batch,
		|	RegisterRecordsSerialNumbersChange.SerialNumber AS SerialNumber,
		|	RegisterRecordsSerialNumbersChange.StructuralUnit AS StructuralUnit,
		|	RegisterRecordsSerialNumbersChange.Cell AS Cell,
		|	RegisterRecordsSerialNumbersChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsSerialNumbersBeforeWrite
		|FROM
		|	RegisterRecordsSerialNumbersChange AS RegisterRecordsSerialNumbersChange
		|
		|UNION ALL
		|
		|SELECT
		|	SerialNumbers.LineNumber,
		|	SerialNumbers.ProductsAndServices,
		|	SerialNumbers.Characteristic,
		|	SerialNumbers.Batch,
		|	SerialNumbers.SerialNumber,
		|	SerialNumbers.StructuralUnit,
		|	SerialNumbers.Cell,
		|	CASE
		|		WHEN SerialNumbers.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN SerialNumbers.Quantity
		|		ELSE -SerialNumbers.Quantity
		|	END
		|FROM
		|	AccumulationRegister.SerialNumbers AS SerialNumbers
		|WHERE
		|	SerialNumbers.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsSerialNumbersChange" dropped. Removed information about its existence.
	
	If StructureTemporaryTables.Property("RegisterRecordsSerialNumbersChange") Then
		
		Query = New Query("DROP RegisterRecordsSerialNumbersChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsSerialNumbersChange");
	
	EndIf;
	
EndProcedure // BeforeWrite()

// Procedure - handler events OnWrite Recordset.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR NOT AdditionalProperties.Property("ForPosting")
		OR NOT AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Update the new set is calculated relative to the
	// current taking into account the accumulated changes and placed into a temporary table "RegisterRecordsSerialNumbersChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsSerialNumbersChange.LineNumber) AS
	|	LineNumber, RegisterRecordsSerialNumbersChange.ProductsAndServices
	|	AS ProductsAndServices, RegisterRecordsSerialNumbersChange.Characteristic
	|	AS Characteristic, RegisterRecordsSerialNumbersChange.Batch
	|	AS Batch, RegisterRecordsSerialNumbersChange.SerialNumber
	|	AS SerialNumber, RegisterRecordsSerialNumbersChange.StructuralUnit
	|	AS StructuralUnit, RegisterRecordsSerialNumbersChange.Cell
	|	AS Cell, SUM(RegisterRecordsSerialNumbersChange.QuantityBeforeWrite)
	|	AS QuantityBeforeWrite, SUM(RegisterRecordsSerialNumbersChange.QuantityChange)
	|	AS QuantityChange, SUM(RegisterRecordsSerialNumbersChange.QuantityOnWrite)
	|AS QuantityOnWrite
	|INTO
	|	RegisterRecordsSerialNumbersChange
	|		FROM (SELECT RegisterRecordsSerialNumbersBeforeWrite.LineNumber
	|		AS LineNumber, RegisterRecordsSerialNumbersBeforeWrite.ProductsAndServices
	|		AS ProductsAndServices, RegisterRecordsSerialNumbersBeforeWrite.Characteristic
	|		AS Characteristic, RegisterRecordsSerialNumbersBeforeWrite.Batch
	|		AS Batch, RegisterRecordsSerialNumbersBeforeWrite.SerialNumber
	|		AS SerialNumber, RegisterRecordsSerialNumbersBeforeWrite.StructuralUnit
	|		AS StructuralUnit, RegisterRecordsSerialNumbersBeforeWrite.Cell
	|		AS Cell, RegisterRecordsSerialNumbersBeforeWrite.QuantityBeforeWrite
	|		AS QuantityBeforeWrite, RegisterRecordsSerialNumbersBeforeWrite.QuantityBeforeWrite
	|		AS QuantityChange, 0
	|	AS
	|		QuantityOnWrite FROM RegisterRecordsSerialNumbersBeforeWrite
	|	AS
	|	RegisterRecordsSerialNumbersBeforeWrite UNION
	|	ALL
	|	SELECT
	|		RegisterRecordsSerialNumbersOnWrite.LineNumber,
	|		RegisterRecordsSerialNumbersOnWrite.ProductsAndServices,
	|		RegisterRecordsSerialNumbersOnWrite.Characteristic,
	|		RegisterRecordsSerialNumbersOnWrite.Batch,
	|		RegisterRecordsSerialNumbersOnWrite.SerialNumber,
	|		RegisterRecordsSerialNumbersOnWrite.StructuralUnit,
	|		RegisterRecordsSerialNumbersOnWrite.Cell,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsSerialNumbersOnWrite.RecordType
	|				= VALUE(AccumulationRecordType.Receipt)
	|			THEN -RegisterRecordsSerialNumbersOnWrite.Quantity
	|		ELSE
	|		RegisterRecordsSerialNumbersOnWrite.Quantity
	|	END,
	|		RegisterRecordsSerialNumbersOnWrite.Quantity FROM AccumulationRegister.SerialNumbers
	|	AS
	|		RegisterRecordsSerialNumbersOnWrite WHERE RegisterRecordsSerialNumbersOnWrite.Recorder =
	|&Recorder)
	|AS RegisterRecordsSerialNumbersChange
	|	GROUP
	|	BY
	|	RegisterRecordsSerialNumbersChange.ProductsAndServices,
	|	RegisterRecordsSerialNumbersChange.Characteristic,
	|	RegisterRecordsSerialNumbersChange.Batch,
	|	RegisterRecordsSerialNumbersChange.SerialNumber,
	|RegisterRecordsSerialNumbersChange.StructuralUnit,
	|RegisterRecordsSerialNumbersChange.Cell
	|	HAVING SUM(RegisterRecordsSerialNumbersChange.QuantityChange)
	|<>
	|0 INDEX
	|	BY
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch,
	|	SerialNumber,
	|	StructuralUnit, Cell");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into a temporary table "RegisterRecordsSerialNumbersChange".
	// The information on its existence and change records availability in it is added.
	StructureTemporaryTables.Insert("RegisterRecordsSerialNumbersChange", QueryResultSelection.Count > 0);
	
	// Temporary table "RegisterRecordsSerialNumbersBeforeWrite" dropped
	Query = New Query("DROP RegisterRecordsSerialNumbersBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnWrite()

#EndRegion

#EndIf