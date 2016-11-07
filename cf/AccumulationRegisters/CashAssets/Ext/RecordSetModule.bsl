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
	LockItem = Block.Add("AccumulationRegister.CashAssets.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsCashAssetsChange") OR
		StructureTemporaryTables.Property("RegisterRecordsCashAssetsChange") AND Not StructureTemporaryTables.RegisterRecordsCashAssetsChange Then
		
		// If the temporary table "RegisterRecordsCashAssetsChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsCashAssetsBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	AccumulationRegisterCashAssets.LineNumber AS LineNumber,
		|	AccumulationRegisterCashAssets.Company AS Company,
		|	AccumulationRegisterCashAssets.CashAssetsType AS CashAssetsType,
		|	AccumulationRegisterCashAssets.BankAccountPettyCash AS BankAccountPettyCash,
		|	AccumulationRegisterCashAssets.Currency AS Currency,
		|	CASE
		|		WHEN AccumulationRegisterCashAssets.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterCashAssets.Amount
		|		ELSE -AccumulationRegisterCashAssets.Amount
		|	END AS SumBeforeWrite,
		|	CASE
		|		WHEN AccumulationRegisterCashAssets.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterCashAssets.AmountCur
		|		ELSE -AccumulationRegisterCashAssets.AmountCur
		|	END AS AmountCurBeforeWrite
		|INTO RegisterRecordsCashAssetsBeforeWrite
		|FROM
		|	AccumulationRegister.CashAssets AS AccumulationRegisterCashAssets
		|WHERE
		|	AccumulationRegisterCashAssets.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsCashAssetsChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsCashAssetsBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsCashAssetsChange.LineNumber AS LineNumber,
		|	RegisterRecordsCashAssetsChange.Company AS Company,
		|	RegisterRecordsCashAssetsChange.CashAssetsType AS CashAssetsType,
		|	RegisterRecordsCashAssetsChange.BankAccountPettyCash AS BankAccountPettyCash,
		|	RegisterRecordsCashAssetsChange.Currency AS Currency,
		|	RegisterRecordsCashAssetsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsCashAssetsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite
		|INTO RegisterRecordsCashAssetsBeforeWrite
		|FROM
		|	RegisterRecordsCashAssetsChange AS RegisterRecordsCashAssetsChange
		|
		|UNION ALL
		|
		|SELECT
		|	AccumulationRegisterCashAssets.LineNumber,
		|	AccumulationRegisterCashAssets.Company,
		|	AccumulationRegisterCashAssets.CashAssetsType,
		|	AccumulationRegisterCashAssets.BankAccountPettyCash,
		|	AccumulationRegisterCashAssets.Currency,
		|	CASE
		|		WHEN AccumulationRegisterCashAssets.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterCashAssets.Amount
		|		ELSE -AccumulationRegisterCashAssets.Amount
		|	END,
		|	CASE
		|		WHEN AccumulationRegisterCashAssets.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterCashAssets.AmountCur
		|		ELSE -AccumulationRegisterCashAssets.AmountCur
		|	END
		|FROM
		|	AccumulationRegister.CashAssets AS AccumulationRegisterCashAssets
		|WHERE
		|	AccumulationRegisterCashAssets.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsCashAssetsChange" is destroyed Deleted info about its existence.
	
	If StructureTemporaryTables.Property("RegisterRecordsCashAssetsChange") Then
		
		Query = New Query("DROP RegisterRecordsCashAssetsChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsCashAssetsChange");
	
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
	
	// It is calculated new set changes relatively current with
	// accounting accumulated changes and placed into temporary table "RegisterRecordsCashAssetsChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsCashAssetsChange.LineNumber) AS LineNumber,
	|	RegisterRecordsCashAssetsChange.Company AS Company,
	|	RegisterRecordsCashAssetsChange.CashAssetsType AS CashAssetsType,
	|	RegisterRecordsCashAssetsChange.BankAccountPettyCash AS BankAccountPettyCash,
	|	RegisterRecordsCashAssetsChange.Currency AS Currency,
	|	SUM(RegisterRecordsCashAssetsChange.SumBeforeWrite) AS SumBeforeWrite,
	|	SUM(RegisterRecordsCashAssetsChange.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsCashAssetsChange.AmountOnWrite) AS AmountOnWrite,
	|	SUM(RegisterRecordsCashAssetsChange.AmountCurBeforeWrite) AS AmountCurBeforeWrite,
	|	SUM(RegisterRecordsCashAssetsChange.SumCurChange) AS SumCurChange,
	|	SUM(RegisterRecordsCashAssetsChange.SumCurOnWrite) AS SumCurOnWrite
	|INTO RegisterRecordsCashAssetsChange
	|FROM
	|	(SELECT
	|		RegisterRecordsCashAssetsBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsCashAssetsBeforeWrite.Company AS Company,
	|		RegisterRecordsCashAssetsBeforeWrite.CashAssetsType AS CashAssetsType,
	|		RegisterRecordsCashAssetsBeforeWrite.BankAccountPettyCash AS BankAccountPettyCash,
	|		RegisterRecordsCashAssetsBeforeWrite.Currency AS Currency,
	|		RegisterRecordsCashAssetsBeforeWrite.SumBeforeWrite AS SumBeforeWrite,
	|		RegisterRecordsCashAssetsBeforeWrite.SumBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite,
	|		RegisterRecordsCashAssetsBeforeWrite.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|		RegisterRecordsCashAssetsBeforeWrite.AmountCurBeforeWrite AS SumCurChange,
	|		0 AS SumCurOnWrite
	|	FROM
	|		RegisterRecordsCashAssetsBeforeWrite AS RegisterRecordsCashAssetsBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsCashAssetsOnWrite.LineNumber,
	|		RegisterRecordsCashAssetsOnWrite.Company,
	|		RegisterRecordsCashAssetsOnWrite.CashAssetsType,
	|		RegisterRecordsCashAssetsOnWrite.BankAccountPettyCash,
	|		RegisterRecordsCashAssetsOnWrite.Currency,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsCashAssetsOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsCashAssetsOnWrite.Amount
	|			ELSE RegisterRecordsCashAssetsOnWrite.Amount
	|		END,
	|		RegisterRecordsCashAssetsOnWrite.Amount,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsCashAssetsOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsCashAssetsOnWrite.AmountCur
	|			ELSE RegisterRecordsCashAssetsOnWrite.AmountCur
	|		END,
	|		RegisterRecordsCashAssetsOnWrite.AmountCur
	|	FROM
	|		AccumulationRegister.CashAssets AS RegisterRecordsCashAssetsOnWrite
	|	WHERE
	|		RegisterRecordsCashAssetsOnWrite.Recorder = &Recorder) AS RegisterRecordsCashAssetsChange
	|
	|GROUP BY
	|	RegisterRecordsCashAssetsChange.Company,
	|	RegisterRecordsCashAssetsChange.CashAssetsType,
	|	RegisterRecordsCashAssetsChange.BankAccountPettyCash,
	|	RegisterRecordsCashAssetsChange.Currency
	|
	|HAVING
	|	(SUM(RegisterRecordsCashAssetsChange.AmountChange) <> 0
	|		OR SUM(RegisterRecordsCashAssetsChange.SumCurChange) <> 0)
	|
	|INDEX BY
	|	Company,
	|	CashAssetsType,
	|	BankAccountPettyCash,
	|	Currency");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed in temporary table "RegisterRecordsCashAssetsChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsCashAssetsChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsCashAssetsBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsCashAssetsBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf