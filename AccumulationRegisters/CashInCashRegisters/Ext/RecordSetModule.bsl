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
	LockItem = Block.Add("AccumulationRegister.CashInCashRegisters.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsCashInCashRegistersChange")
		OR	StructureTemporaryTables.Property("RegisterRecordsCashInCashRegistersChange") AND Not StructureTemporaryTables.RegisterRecordsCashInCashRegistersChange Then
		
		// If the temporary table "RegisterRecordsCashInCashRegistersChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsCashInCashRegistersBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	AccumulationRegisterCashInCashCR.LineNumber AS LineNumber,
		|	AccumulationRegisterCashInCashCR.Company AS Company,
		|	AccumulationRegisterCashInCashCR.CashCR AS CashCR,
		|	CASE
		|		WHEN AccumulationRegisterCashInCashCR.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterCashInCashCR.Amount
		|		ELSE -AccumulationRegisterCashInCashCR.Amount
		|	END AS SumBeforeWrite,
		|	CASE
		|		WHEN AccumulationRegisterCashInCashCR.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterCashInCashCR.AmountCur
		|		ELSE -AccumulationRegisterCashInCashCR.AmountCur
		|	END AS AmountCurBeforeWrite
		|INTO RegisterRecordsCashInCashRegistersBeforeWrite
		|FROM
		|	AccumulationRegister.CashInCashRegisters AS AccumulationRegisterCashInCashCR
		|WHERE
		|	AccumulationRegisterCashInCashCR.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsCashInCashRegistersChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsCashInCashRegistersBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsCashInCashRegistersChange.LineNumber AS LineNumber,
		|	RegisterRecordsCashInCashRegistersChange.Company AS Company,
		|	RegisterRecordsCashInCashRegistersChange.CashCR AS CashCR,
		|	RegisterRecordsCashInCashRegistersChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsCashInCashRegistersChange.AmountCurBeforeWrite AS AmountCurBeforeWrite
		|INTO RegisterRecordsCashInCashRegistersBeforeWrite
		|FROM
		|	RegisterRecordsCashInCashRegistersChange AS RegisterRecordsCashInCashRegistersChange
		|
		|UNION ALL
		|
		|SELECT
		|	AccumulationRegisterCashInCashCR.LineNumber,
		|	AccumulationRegisterCashInCashCR.Company,
		|	AccumulationRegisterCashInCashCR.CashCR,
		|	CASE
		|		WHEN AccumulationRegisterCashInCashCR.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterCashInCashCR.Amount
		|		ELSE -AccumulationRegisterCashInCashCR.Amount
		|	END,
		|	CASE
		|		WHEN AccumulationRegisterCashInCashCR.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterCashInCashCR.AmountCur
		|		ELSE -AccumulationRegisterCashInCashCR.AmountCur
		|	END
		|FROM
		|	AccumulationRegister.CashInCashRegisters AS AccumulationRegisterCashInCashCR
		|WHERE
		|	AccumulationRegisterCashInCashCR.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsCashInCashRegistersChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsCashInCashRegistersChange") Then
		
		Query = New Query("DROP RegisterRecordsCashInCashRegistersChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsCashInCashRegistersChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsCashInCashRegistersChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsCashInCashRegistersChange.LineNumber) AS LineNumber,
	|	RegisterRecordsCashInCashRegistersChange.Company AS Company,
	|	RegisterRecordsCashInCashRegistersChange.CashCR AS CashCR,
	|	SUM(RegisterRecordsCashInCashRegistersChange.SumBeforeWrite) AS SumBeforeWrite,
	|	SUM(RegisterRecordsCashInCashRegistersChange.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsCashInCashRegistersChange.AmountOnWrite) AS AmountOnWrite,
	|	SUM(RegisterRecordsCashInCashRegistersChange.AmountCurBeforeWrite) AS AmountCurBeforeWrite,
	|	SUM(RegisterRecordsCashInCashRegistersChange.SumCurChange) AS SumCurChange,
	|	SUM(RegisterRecordsCashInCashRegistersChange.SumCurOnWrite) AS SumCurOnWrite
	|INTO RegisterRecordsCashInCashRegistersChange
	|FROM
	|	(SELECT
	|		RegisterRecordsCashInCashRegistersBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsCashInCashRegistersBeforeWrite.Company AS Company,
	|		RegisterRecordsCashInCashRegistersBeforeWrite.CashCR AS CashCR,
	|		RegisterRecordsCashInCashRegistersBeforeWrite.SumBeforeWrite AS SumBeforeWrite,
	|		RegisterRecordsCashInCashRegistersBeforeWrite.SumBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite,
	|		RegisterRecordsCashInCashRegistersBeforeWrite.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|		RegisterRecordsCashInCashRegistersBeforeWrite.AmountCurBeforeWrite AS SumCurChange,
	|		0 AS SumCurOnWrite
	|	FROM
	|		RegisterRecordsCashInCashRegistersBeforeWrite AS RegisterRecordsCashInCashRegistersBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsCashInCashRegistersOnWrite.LineNumber,
	|		RegisterRecordsCashInCashRegistersOnWrite.Company,
	|		RegisterRecordsCashInCashRegistersOnWrite.CashCR,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsCashInCashRegistersOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsCashInCashRegistersOnWrite.Amount
	|			ELSE RegisterRecordsCashInCashRegistersOnWrite.Amount
	|		END,
	|		RegisterRecordsCashInCashRegistersOnWrite.Amount,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsCashInCashRegistersOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsCashInCashRegistersOnWrite.AmountCur
	|			ELSE RegisterRecordsCashInCashRegistersOnWrite.AmountCur
	|		END,
	|		RegisterRecordsCashInCashRegistersOnWrite.AmountCur
	|	FROM
	|		AccumulationRegister.CashInCashRegisters AS RegisterRecordsCashInCashRegistersOnWrite
	|	WHERE
	|		RegisterRecordsCashInCashRegistersOnWrite.Recorder = &Recorder) AS RegisterRecordsCashInCashRegistersChange
	|
	|GROUP BY
	|	RegisterRecordsCashInCashRegistersChange.Company,
	|	RegisterRecordsCashInCashRegistersChange.CashCR
	|
	|HAVING
	|	(SUM(RegisterRecordsCashInCashRegistersChange.AmountChange) <> 0
	|		OR SUM(RegisterRecordsCashInCashRegistersChange.SumCurChange) <> 0)
	|
	|INDEX BY
	|	Company,
	|	CashCR");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed in temporary table "RegisterRecordsCashInCashRegistersChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsCashInCashRegistersChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsCashInCashRegistersBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsCashInCashRegistersBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf