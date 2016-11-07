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
	LockItem = Block.Add("AccumulationRegister.AccountsPayable.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsSuppliersSettlementsChange")
		OR StructureTemporaryTables.Property("RegisterRecordsSuppliersSettlementsChange")
	   AND Not StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
		// If the temporary table "RegisterRecordsAccountsPayableChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsAccountsPayableBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	AccumulationRegisterAccountsPayable.LineNumber AS LineNumber,
		|	AccumulationRegisterAccountsPayable.Company AS Company,
		|	AccumulationRegisterAccountsPayable.Counterparty AS Counterparty,
		|	AccumulationRegisterAccountsPayable.Contract AS Contract,
		|	AccumulationRegisterAccountsPayable.Document AS Document,
		|	AccumulationRegisterAccountsPayable.Order AS Order,
		|	AccumulationRegisterAccountsPayable.SettlementsType AS SettlementsType,
		|	CASE
		|		WHEN AccumulationRegisterAccountsPayable.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterAccountsPayable.Amount
		|		ELSE -AccumulationRegisterAccountsPayable.Amount
		|	END AS SumBeforeWrite,
		|	CASE
		|		WHEN AccumulationRegisterAccountsPayable.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterAccountsPayable.AmountCur
		|		ELSE -AccumulationRegisterAccountsPayable.AmountCur
		|	END AS AmountCurBeforeWrite
		|INTO RegisterRecordsAccountsPayableBeforeWrite
		|FROM
		|	AccumulationRegister.AccountsPayable AS AccumulationRegisterAccountsPayable
		|WHERE
		|	AccumulationRegisterAccountsPayable.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsAccountsPayableChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsAccountsPayableBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	RegisterRecordsSuppliersSettlementsChange.Company AS Company,
		|	RegisterRecordsSuppliersSettlementsChange.Counterparty AS Counterparty,
		|	RegisterRecordsSuppliersSettlementsChange.Contract AS Contract,
		|	RegisterRecordsSuppliersSettlementsChange.Document AS Document,
		|	RegisterRecordsSuppliersSettlementsChange.Order AS Order,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType,
		|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite
		|INTO RegisterRecordsAccountsPayableBeforeWrite
		|FROM
		|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
		|
		|UNION ALL
		|
		|SELECT
		|	AccumulationRegisterAccountsPayable.LineNumber,
		|	AccumulationRegisterAccountsPayable.Company,
		|	AccumulationRegisterAccountsPayable.Counterparty,
		|	AccumulationRegisterAccountsPayable.Contract,
		|	AccumulationRegisterAccountsPayable.Document,
		|	AccumulationRegisterAccountsPayable.Order,
		|	AccumulationRegisterAccountsPayable.SettlementsType,
		|	CASE
		|		WHEN AccumulationRegisterAccountsPayable.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterAccountsPayable.Amount
		|		ELSE -AccumulationRegisterAccountsPayable.Amount
		|	END,
		|	CASE
		|		WHEN AccumulationRegisterAccountsPayable.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterAccountsPayable.AmountCur
		|		ELSE -AccumulationRegisterAccountsPayable.AmountCur
		|	END
		|FROM
		|	AccumulationRegister.AccountsPayable AS AccumulationRegisterAccountsPayable
		|WHERE
		|	AccumulationRegisterAccountsPayable.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsAccountsPayableChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsSuppliersSettlementsChange") Then
		
		Query = New Query("DELETE RegisterRecordsAccountsPayableChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsSuppliersSettlementsChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsAccountsPayableChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsSuppliersSettlementsChange.LineNumber) AS LineNumber,
	|	RegisterRecordsSuppliersSettlementsChange.Company AS Company,
	|	RegisterRecordsSuppliersSettlementsChange.Counterparty AS Counterparty,
	|	RegisterRecordsSuppliersSettlementsChange.Contract AS Contract,
	|	RegisterRecordsSuppliersSettlementsChange.Document AS Document,
	|	RegisterRecordsSuppliersSettlementsChange.Order AS Order,
	|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType,
	|	SUM(RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite) AS SumBeforeWrite,
	|	SUM(RegisterRecordsSuppliersSettlementsChange.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsSuppliersSettlementsChange.AmountOnWrite) AS AmountOnWrite,
	|	SUM(RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite) AS AmountCurBeforeWrite,
	|	SUM(RegisterRecordsSuppliersSettlementsChange.SumCurChange) AS SumCurChange,
	|	SUM(RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite) AS SumCurOnWrite
	|INTO RegisterRecordsSuppliersSettlementsChange
	|FROM
	|	(SELECT
	|		RegisterRecordsAccountsPayableBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsAccountsPayableBeforeWrite.Company AS Company,
	|		RegisterRecordsAccountsPayableBeforeWrite.Counterparty AS Counterparty,
	|		RegisterRecordsAccountsPayableBeforeWrite.Contract AS Contract,
	|		RegisterRecordsAccountsPayableBeforeWrite.Document AS Document,
	|		RegisterRecordsAccountsPayableBeforeWrite.Order AS Order,
	|		RegisterRecordsAccountsPayableBeforeWrite.SettlementsType AS SettlementsType,
	|		RegisterRecordsAccountsPayableBeforeWrite.SumBeforeWrite AS SumBeforeWrite,
	|		RegisterRecordsAccountsPayableBeforeWrite.SumBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite,
	|		RegisterRecordsAccountsPayableBeforeWrite.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|		RegisterRecordsAccountsPayableBeforeWrite.AmountCurBeforeWrite AS SumCurChange,
	|		0 AS SumCurOnWrite
	|	FROM
	|		RegisterRecordsAccountsPayableBeforeWrite AS RegisterRecordsAccountsPayableBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsAccountsPayableOnWrite.LineNumber,
	|		RegisterRecordsAccountsPayableOnWrite.Company,
	|		RegisterRecordsAccountsPayableOnWrite.Counterparty,
	|		RegisterRecordsAccountsPayableOnWrite.Contract,
	|		RegisterRecordsAccountsPayableOnWrite.Document,
	|		RegisterRecordsAccountsPayableOnWrite.Order,
	|		RegisterRecordsAccountsPayableOnWrite.SettlementsType,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsAccountsPayableOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsAccountsPayableOnWrite.Amount
	|			ELSE RegisterRecordsAccountsPayableOnWrite.Amount
	|		END,
	|		RegisterRecordsAccountsPayableOnWrite.Amount,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsAccountsPayableOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsAccountsPayableOnWrite.AmountCur
	|			ELSE RegisterRecordsAccountsPayableOnWrite.AmountCur
	|		END,
	|		RegisterRecordsAccountsPayableOnWrite.AmountCur
	|	FROM
	|		AccumulationRegister.AccountsPayable AS RegisterRecordsAccountsPayableOnWrite
	|	WHERE
	|		RegisterRecordsAccountsPayableOnWrite.Recorder = &Recorder) AS RegisterRecordsSuppliersSettlementsChange
	|
	|GROUP BY
	|	RegisterRecordsSuppliersSettlementsChange.Company,
	|	RegisterRecordsSuppliersSettlementsChange.Counterparty,
	|	RegisterRecordsSuppliersSettlementsChange.Contract,
	|	RegisterRecordsSuppliersSettlementsChange.Document,
	|	RegisterRecordsSuppliersSettlementsChange.Order,
	|	RegisterRecordsSuppliersSettlementsChange.SettlementsType
	|
	|HAVING
	|	(SUM(RegisterRecordsSuppliersSettlementsChange.AmountChange) <> 0
	|		OR SUM(RegisterRecordsSuppliersSettlementsChange.SumCurChange) <> 0)
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
	
	// New changes were placed into temporary table "RegisterRecordsAccountsPayableChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsSuppliersSettlementsChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsAccountsPayableBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsAccountsPayableBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf