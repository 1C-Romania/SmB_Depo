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
	LockItem = Block.Add("AccumulationRegister.AccountsReceivable.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsAccountsReceivableChange")
		OR	StructureTemporaryTables.Property("RegisterRecordsAccountsReceivableChange")
	   AND Not StructureTemporaryTables.RegisterRecordsAccountsReceivableChange Then
		
		// If the temporary table "RegisterRecordsAccountsReceivableChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsAccountsReceivableBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	AccumulationRegisterAccountsReceivable.LineNumber AS LineNumber,
		|	AccumulationRegisterAccountsReceivable.Company AS Company,
		|	AccumulationRegisterAccountsReceivable.Counterparty AS Counterparty,
		|	AccumulationRegisterAccountsReceivable.Contract AS Contract,
		|	AccumulationRegisterAccountsReceivable.Document AS Document,
		|	AccumulationRegisterAccountsReceivable.Order AS Order,
		|	AccumulationRegisterAccountsReceivable.SettlementsType AS SettlementsType,
		|	CASE
		|		WHEN AccumulationRegisterAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterAccountsReceivable.Amount
		|		ELSE -AccumulationRegisterAccountsReceivable.Amount
		|	END AS SumBeforeWrite,
		|	CASE
		|		WHEN AccumulationRegisterAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterAccountsReceivable.AmountCur
		|		ELSE -AccumulationRegisterAccountsReceivable.AmountCur
		|	END AS AmountCurBeforeWrite
		|INTO RegisterRecordsAccountsReceivableBeforeWrite
		|FROM
		|	AccumulationRegister.AccountsReceivable AS AccumulationRegisterAccountsReceivable
		|WHERE
		|	AccumulationRegisterAccountsReceivable.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsAccountsReceivableChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsAccountsReceivableBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	RegisterRecordsAccountsReceivableChange.Company AS Company,
		|	RegisterRecordsAccountsReceivableChange.Counterparty AS Counterparty,
		|	RegisterRecordsAccountsReceivableChange.Contract AS Contract,
		|	RegisterRecordsAccountsReceivableChange.Document AS Document,
		|	RegisterRecordsAccountsReceivableChange.Order AS Order,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite
		|INTO RegisterRecordsAccountsReceivableBeforeWrite
		|FROM
		|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
		|
		|UNION ALL
		|
		|SELECT
		|	AccumulationRegisterAccountsReceivable.LineNumber,
		|	AccumulationRegisterAccountsReceivable.Company,
		|	AccumulationRegisterAccountsReceivable.Counterparty,
		|	AccumulationRegisterAccountsReceivable.Contract,
		|	AccumulationRegisterAccountsReceivable.Document,
		|	AccumulationRegisterAccountsReceivable.Order,
		|	AccumulationRegisterAccountsReceivable.SettlementsType,
		|	CASE
		|		WHEN AccumulationRegisterAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterAccountsReceivable.Amount
		|		ELSE -AccumulationRegisterAccountsReceivable.Amount
		|	END,
		|	CASE
		|		WHEN AccumulationRegisterAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterAccountsReceivable.AmountCur
		|		ELSE -AccumulationRegisterAccountsReceivable.AmountCur
		|	END
		|FROM
		|	AccumulationRegister.AccountsReceivable AS AccumulationRegisterAccountsReceivable
		|WHERE
		|	AccumulationRegisterAccountsReceivable.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsAccountsReceivableChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsAccountsReceivableChange") Then
		
		Query = New Query("DELETE RegisterRecordsAccountsReceivableChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsAccountsReceivableChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsAccountsReceivableChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsAccountsReceivableChange.LineNumber) AS LineNumber,
	|	RegisterRecordsAccountsReceivableChange.Company AS Company,
	|	RegisterRecordsAccountsReceivableChange.Counterparty AS Counterparty,
	|	RegisterRecordsAccountsReceivableChange.Contract AS Contract,
	|	RegisterRecordsAccountsReceivableChange.Document AS Document,
	|	RegisterRecordsAccountsReceivableChange.Order AS Order,
	|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType,
	|	SUM(RegisterRecordsAccountsReceivableChange.SumBeforeWrite) AS SumBeforeWrite,
	|	SUM(RegisterRecordsAccountsReceivableChange.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsAccountsReceivableChange.AmountOnWrite) AS AmountOnWrite,
	|	SUM(RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite) AS AmountCurBeforeWrite,
	|	SUM(RegisterRecordsAccountsReceivableChange.SumCurChange) AS SumCurChange,
	|	SUM(RegisterRecordsAccountsReceivableChange.SumCurOnWrite) AS SumCurOnWrite
	|INTO RegisterRecordsAccountsReceivableChange
	|FROM
	|	(SELECT
	|		RegisterRecordsAccountsReceivableBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsAccountsReceivableBeforeWrite.Company AS Company,
	|		RegisterRecordsAccountsReceivableBeforeWrite.Counterparty AS Counterparty,
	|		RegisterRecordsAccountsReceivableBeforeWrite.Contract AS Contract,
	|		RegisterRecordsAccountsReceivableBeforeWrite.Document AS Document,
	|		RegisterRecordsAccountsReceivableBeforeWrite.Order AS Order,
	|		RegisterRecordsAccountsReceivableBeforeWrite.SettlementsType AS SettlementsType,
	|		RegisterRecordsAccountsReceivableBeforeWrite.SumBeforeWrite AS SumBeforeWrite,
	|		RegisterRecordsAccountsReceivableBeforeWrite.SumBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite,
	|		RegisterRecordsAccountsReceivableBeforeWrite.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|		RegisterRecordsAccountsReceivableBeforeWrite.AmountCurBeforeWrite AS SumCurChange,
	|		0 AS SumCurOnWrite
	|	FROM
	|		RegisterRecordsAccountsReceivableBeforeWrite AS RegisterRecordsAccountsReceivableBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsAccountsReceivableOnWrite.LineNumber,
	|		RegisterRecordsAccountsReceivableOnWrite.Company,
	|		RegisterRecordsAccountsReceivableOnWrite.Counterparty,
	|		RegisterRecordsAccountsReceivableOnWrite.Contract,
	|		RegisterRecordsAccountsReceivableOnWrite.Document,
	|		RegisterRecordsAccountsReceivableOnWrite.Order,
	|		RegisterRecordsAccountsReceivableOnWrite.SettlementsType,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsAccountsReceivableOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsAccountsReceivableOnWrite.Amount
	|			ELSE RegisterRecordsAccountsReceivableOnWrite.Amount
	|		END,
	|		RegisterRecordsAccountsReceivableOnWrite.Amount,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsAccountsReceivableOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsAccountsReceivableOnWrite.AmountCur
	|			ELSE RegisterRecordsAccountsReceivableOnWrite.AmountCur
	|		END,
	|		RegisterRecordsAccountsReceivableOnWrite.AmountCur
	|	FROM
	|		AccumulationRegister.AccountsReceivable AS RegisterRecordsAccountsReceivableOnWrite
	|	WHERE
	|		RegisterRecordsAccountsReceivableOnWrite.Recorder = &Recorder) AS RegisterRecordsAccountsReceivableChange
	|
	|GROUP BY
	|	RegisterRecordsAccountsReceivableChange.Company,
	|	RegisterRecordsAccountsReceivableChange.Counterparty,
	|	RegisterRecordsAccountsReceivableChange.Contract,
	|	RegisterRecordsAccountsReceivableChange.Document,
	|	RegisterRecordsAccountsReceivableChange.Order,
	|	RegisterRecordsAccountsReceivableChange.SettlementsType
	|
	|HAVING
	|	(SUM(RegisterRecordsAccountsReceivableChange.AmountChange) <> 0
	|		OR SUM(RegisterRecordsAccountsReceivableChange.SumCurChange) <> 0)
	|
	|INDEX BY
	|	Company,
	|	Counterparty,
	|	Contract,
	|	Document,
	|	Order,
	|	SettlementsType");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsAccountsReceivableChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsAccountsReceivableChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsAccountsReceivableBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsAccountsReceivableBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf