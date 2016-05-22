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
	LockItem = Block.Add("AccumulationRegister.RetailAmountAccounting.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsRetailAmountAccountingUpdate") OR
		StructureTemporaryTables.Property("RegisterRecordsRetailAmountAccountingUpdate") AND Not StructureTemporaryTables.RegisterRecordsRetailAmountAccountingUpdate Then
		
		// If the temporary table "RegisterRecordsRetailAmountAccountingChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsRetailAmountAccountingBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	AccumulationRegisterRetailAmountAccounting.LineNumber AS LineNumber,
		|	AccumulationRegisterRetailAmountAccounting.Company AS Company,
		|	AccumulationRegisterRetailAmountAccounting.StructuralUnit AS StructuralUnit,
		|	AccumulationRegisterRetailAmountAccounting.Currency AS Currency,
		|	CASE
		|		WHEN AccumulationRegisterRetailAmountAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterRetailAmountAccounting.Amount
		|		ELSE -AccumulationRegisterRetailAmountAccounting.Amount
		|	END AS SumBeforeWrite,
		|	CASE
		|		WHEN AccumulationRegisterRetailAmountAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterRetailAmountAccounting.AmountCur
		|		ELSE -AccumulationRegisterRetailAmountAccounting.AmountCur
		|	END AS AmountCurBeforeWrite,
		|	CASE
		|		WHEN AccumulationRegisterRetailAmountAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterRetailAmountAccounting.Cost
		|		ELSE -AccumulationRegisterRetailAmountAccounting.Cost
		|	END AS CostBeforeWrite
		|INTO RegisterRecordsRetailAmountAccountingBeforeWrite
		|FROM
		|	AccumulationRegister.RetailAmountAccounting AS AccumulationRegisterRetailAmountAccounting
		|WHERE
		|	AccumulationRegisterRetailAmountAccounting.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsRetailAmountAccountingChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsRetailAmountAccountingBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsRetailAmountAccountingUpdate.LineNumber AS LineNumber,
		|	RegisterRecordsRetailAmountAccountingUpdate.Company AS Company,
		|	RegisterRecordsRetailAmountAccountingUpdate.StructuralUnit AS StructuralUnit,
		|	RegisterRecordsRetailAmountAccountingUpdate.Currency AS Currency,
		|	RegisterRecordsRetailAmountAccountingUpdate.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsRetailAmountAccountingUpdate.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsRetailAmountAccountingUpdate.CostBeforeWrite AS CostBeforeWrite
		|INTO RegisterRecordsRetailAmountAccountingBeforeWrite
		|FROM
		|	RegisterRecordsRetailAmountAccountingUpdate AS RegisterRecordsRetailAmountAccountingUpdate
		|
		|UNION ALL
		|
		|SELECT
		|	AccumulationRegisterRetailAmountAccounting.LineNumber,
		|	AccumulationRegisterRetailAmountAccounting.Company,
		|	AccumulationRegisterRetailAmountAccounting.StructuralUnit,
		|	AccumulationRegisterRetailAmountAccounting.Currency,
		|	CASE
		|		WHEN AccumulationRegisterRetailAmountAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterRetailAmountAccounting.Amount
		|		ELSE -AccumulationRegisterRetailAmountAccounting.Amount
		|	END,
		|	CASE
		|		WHEN AccumulationRegisterRetailAmountAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterRetailAmountAccounting.AmountCur
		|		ELSE -AccumulationRegisterRetailAmountAccounting.AmountCur
		|	END,
		|	CASE
		|		WHEN AccumulationRegisterRetailAmountAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterRetailAmountAccounting.Cost
		|		ELSE -AccumulationRegisterRetailAmountAccounting.Cost
		|	END
		|FROM
		|	AccumulationRegister.RetailAmountAccounting AS AccumulationRegisterRetailAmountAccounting
		|WHERE
		|	AccumulationRegisterRetailAmountAccounting.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsRetailAmountAccountingChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsRetailAmountAccountingUpdate") Then
		
		Query = New Query("DROP RegisterRecordsRetailAmountAccountingChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsRetailAmountAccountingUpdate");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsRetailAmountAccountingChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsRetailAmountAccountingUpdate.LineNumber) AS LineNumber,
	|	RegisterRecordsRetailAmountAccountingUpdate.Company AS Company,
	|	RegisterRecordsRetailAmountAccountingUpdate.StructuralUnit AS StructuralUnit,
	|	RegisterRecordsRetailAmountAccountingUpdate.Currency AS Currency,
	|	SUM(RegisterRecordsRetailAmountAccountingUpdate.SumBeforeWrite) AS SumBeforeWrite,
	|	SUM(RegisterRecordsRetailAmountAccountingUpdate.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsRetailAmountAccountingUpdate.AmountOnWrite) AS AmountOnWrite,
	|	SUM(RegisterRecordsRetailAmountAccountingUpdate.AmountCurBeforeWrite) AS AmountCurBeforeWrite,
	|	SUM(RegisterRecordsRetailAmountAccountingUpdate.SumCurChange) AS SumCurChange,
	|	SUM(RegisterRecordsRetailAmountAccountingUpdate.SumCurOnWrite) AS SumCurOnWrite,
	|	SUM(RegisterRecordsRetailAmountAccountingUpdate.CostBeforeWrite) AS CostBeforeWrite,
	|	SUM(RegisterRecordsRetailAmountAccountingUpdate.CostUpdate) AS CostUpdate,
	|	SUM(RegisterRecordsRetailAmountAccountingUpdate.CostOnWrite) AS CostOnWrite
	|
	|INTO RegisterRecordsRetailAmountAccountingUpdate
	|FROM
	|	(SELECT
	|		RegisterRecordsRetailAmountAccountingBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsRetailAmountAccountingBeforeWrite.Company AS Company,
	|		RegisterRecordsRetailAmountAccountingBeforeWrite.StructuralUnit AS StructuralUnit,
	|		RegisterRecordsRetailAmountAccountingBeforeWrite.Currency AS Currency,
	|		RegisterRecordsRetailAmountAccountingBeforeWrite.SumBeforeWrite AS SumBeforeWrite,
	|		RegisterRecordsRetailAmountAccountingBeforeWrite.SumBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite,
	|		RegisterRecordsRetailAmountAccountingBeforeWrite.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|		RegisterRecordsRetailAmountAccountingBeforeWrite.AmountCurBeforeWrite AS SumCurChange,
	|		0 AS SumCurOnWrite,
	|		RegisterRecordsRetailAmountAccountingBeforeWrite.CostBeforeWrite AS CostBeforeWrite,
	|		RegisterRecordsRetailAmountAccountingBeforeWrite.CostBeforeWrite AS CostUpdate,
	|		0 AS CostOnWrite
	|
	|	FROM
	|		RegisterRecordsRetailAmountAccountingBeforeWrite AS RegisterRecordsRetailAmountAccountingBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsRetailAmountAccountingOnWrite.LineNumber,
	|		RegisterRecordsRetailAmountAccountingOnWrite.Company,
	|		RegisterRecordsRetailAmountAccountingOnWrite.StructuralUnit,
	|		RegisterRecordsRetailAmountAccountingOnWrite.Currency,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsRetailAmountAccountingOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsRetailAmountAccountingOnWrite.Amount
	|			ELSE RegisterRecordsRetailAmountAccountingOnWrite.Amount
	|		END,
	|		RegisterRecordsRetailAmountAccountingOnWrite.Amount,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsRetailAmountAccountingOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsRetailAmountAccountingOnWrite.AmountCur
	|			ELSE RegisterRecordsRetailAmountAccountingOnWrite.AmountCur
	|		END,
	|		RegisterRecordsRetailAmountAccountingOnWrite.AmountCur,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsRetailAmountAccountingOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsRetailAmountAccountingOnWrite.Cost
	|			ELSE RegisterRecordsRetailAmountAccountingOnWrite.Cost
	|		END,
	|		RegisterRecordsRetailAmountAccountingOnWrite.Cost
	|
	|	FROM
	|		AccumulationRegister.RetailAmountAccounting AS RegisterRecordsRetailAmountAccountingOnWrite
	|	WHERE
	|		RegisterRecordsRetailAmountAccountingOnWrite.Recorder = &Recorder) AS RegisterRecordsRetailAmountAccountingUpdate
	|
	|GROUP BY
	|	RegisterRecordsRetailAmountAccountingUpdate.Company,
	|	RegisterRecordsRetailAmountAccountingUpdate.StructuralUnit,
	|	RegisterRecordsRetailAmountAccountingUpdate.Currency
	|
	|HAVING
	|	(SUM(RegisterRecordsRetailAmountAccountingUpdate.AmountChange) <> 0
	|		OR SUM(RegisterRecordsRetailAmountAccountingUpdate.SumCurChange) <> 0
	|		OR SUM(RegisterRecordsRetailAmountAccountingUpdate.CostUpdate) <> 0)
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Currency");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsRetailAmountAccountingChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsRetailAmountAccountingUpdate", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsRetailAmountAccountingBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsRetailAmountAccountingBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf