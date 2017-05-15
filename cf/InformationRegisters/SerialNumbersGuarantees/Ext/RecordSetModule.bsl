// Procedure - handler events Recordset BeforeWrite.
//

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR NOT AdditionalProperties.Property("ForPosting")
		OR NOT AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If NOT StructureTemporaryTables.Property("RegisterRecordsSerialNumbersGuaranteesUpdate") OR
		StructureTemporaryTables.Property("RegisterRecordsSerialNumbersGuaranteesUpdate") AND NOT StructureTemporaryTables.RegisterRecordsSerialNumbersGuaranteesUpdate Then
		
		Query = New Query(
			"SELECT
			|	SerialNumbers.LineNumber AS LineNumber,
			|	SerialNumbers.ProductsAndServices AS ProductsAndServices,
			|	SerialNumbers.Characteristic AS Characteristic,
			|	SerialNumbers.SerialNumber AS SerialNumber,
			|	SerialNumbers.Operation
			|INTO RegisterRecordsSerialNumbersGuaranteesBeforeRecording
			|FROM
			|	InformationRegister.SerialNumbersGuarantees AS SerialNumbers
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
			|	RegisterRecordsSerialNumbersGuaranteesUpdate.LineNumber AS LineNumber,
			|	RegisterRecordsSerialNumbersGuaranteesUpdate.ProductsAndServices AS ProductsAndServices,
			|	RegisterRecordsSerialNumbersGuaranteesUpdate.Characteristic AS Characteristic,
			|	RegisterRecordsSerialNumbersGuaranteesUpdate.SerialNumber AS SerialNumber,
			|	RegisterRecordsSerialNumbersGuaranteesUpdate.Operation AS Operation
			|INTO RegisterRecordsSerialNumbersGuaranteesBeforeRecording
			|FROM
			|	RegisterRecordsSerialNumbersGuaranteesUpdate AS RegisterRecordsSerialNumbersGuaranteesUpdate
			|
			|UNION ALL
			|
			|SELECT
			|	SerialNumbers.LineNumber,
			|	SerialNumbers.ProductsAndServices,
			|	SerialNumbers.Characteristic,
			|	SerialNumbers.SerialNumber,
			|	SerialNumbers.Operation
			|FROM
			|	InformationRegister.SerialNumbersGuarantees AS SerialNumbers
			|WHERE
			|	SerialNumbers.Recorder = &Recorder
			|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// The "RegisterRecordsSerialNumbersGuaranteesChange" temporary
	// table is deleted Information on its existence is deleted.
	If StructureTemporaryTables.Property("RegisterRecordsSerialNumbersGuaranteesUpdate") Then
		Query = New Query("DROP RegisterRecordsSerialNumbersGuaranteesUpdate");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsSerialNumbersGuaranteesUpdate");
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
	// current taking into account the accumulated changes and placed into a temporary table "RegisterRecordsSerialNumbersGuaranteesUpdate".
	
	Query = New Query(
		"SELECT
		|	RegisterRecordsSerialNumbersGuaranteesUpdate.ProductsAndServices AS ProductsAndServices,
		|	RegisterRecordsSerialNumbersGuaranteesUpdate.Characteristic AS Characteristic,
		|	RegisterRecordsSerialNumbersGuaranteesUpdate.Operation AS Operation,
		|	RegisterRecordsSerialNumbersGuaranteesUpdate.SerialNumber AS SerialNumber,
		|	RegisterRecordsSerialNumbersGuaranteesUpdate.SerialNumber.Sold AS SerialNumberSold,
		|	SUM(RegisterRecordsSerialNumbersGuaranteesUpdate.ChangeType) AS ChangeType
		|FROM
		|	(SELECT
		|		RegisterRecordsSerialNumbersGuaranteesBeforeRecording.ProductsAndServices AS ProductsAndServices,
		|		RegisterRecordsSerialNumbersGuaranteesBeforeRecording.Characteristic AS Characteristic,
		|		RegisterRecordsSerialNumbersGuaranteesBeforeRecording.Operation AS Operation,
		|		RegisterRecordsSerialNumbersGuaranteesBeforeRecording.SerialNumber AS SerialNumber,
		|		-1 AS ChangeType
		|	FROM
		|		RegisterRecordsSerialNumbersGuaranteesBeforeRecording AS RegisterRecordsSerialNumbersGuaranteesBeforeRecording
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		RegisterRecordsSerialNumbersGuaranteesOnWrite.ProductsAndServices,
		|		RegisterRecordsSerialNumbersGuaranteesOnWrite.Characteristic,
		|		RegisterRecordsSerialNumbersGuaranteesOnWrite.Operation,
		|		RegisterRecordsSerialNumbersGuaranteesOnWrite.SerialNumber,
		|		1
		|	FROM
		|		InformationRegister.SerialNumbersGuarantees AS RegisterRecordsSerialNumbersGuaranteesOnWrite
		|	WHERE
		|		RegisterRecordsSerialNumbersGuaranteesOnWrite.Recorder = &Recorder) AS RegisterRecordsSerialNumbersGuaranteesUpdate
		|
		|GROUP BY
		|	RegisterRecordsSerialNumbersGuaranteesUpdate.ProductsAndServices,
		|	RegisterRecordsSerialNumbersGuaranteesUpdate.Characteristic,
		|	RegisterRecordsSerialNumbersGuaranteesUpdate.Operation,
		|	RegisterRecordsSerialNumbersGuaranteesUpdate.SerialNumber,
		|	RegisterRecordsSerialNumbersGuaranteesUpdate.SerialNumber.Sold
		|
		|HAVING
		|	SUM(RegisterRecordsSerialNumbersGuaranteesUpdate.ChangeType) <> 0");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	While QueryResultSelection.Next() Do
		
		If QueryResultSelection.Operation = Enums.SerialNumbersOperations.Expense 
			AND NOT QueryResultSelection.SerialNumberSold Then
			SerialNumberObject = QueryResultSelection.SerialNumber.GetObject();
			SerialNumberObject.Sold = True;
			SerialNumberObject.Write();
		ElsIf QueryResultSelection.Operation = Enums.SerialNumbersOperations.Receipt 
			AND QueryResultSelection.SerialNumberSold Then
			SerialNumberObject = QueryResultSelection.SerialNumber.GetObject();
			SerialNumberObject.Sold = False;
			SerialNumberObject.Write();
		EndIf;
		
	EndDo;
	
	// New changes were placed into temporary table "RegisterRecordsSerialNumbersGuaranteesBeforeRecording".
	// The information on its existence and change records availability in it is added.
	//StructureTemporaryTables.Insert("RegisterRecordsSerialNumbersGuaranteesUpdate", QueryResultSelection.Count > 0);
	
	// Temporary table "RegisterRecordsSerialNumbersGuaranteesBeforeRecording" is deleted
	Query = New Query("DROP RegisterRecordsSerialNumbersGuaranteesBeforeRecording");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnWrite()

