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
	LockItem = Block.Add("AccumulationRegister.IncomeAndExpensesRetained.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsIncomeAndExpensesRetainedChange") OR
		StructureTemporaryTables.Property("RegisterRecordsIncomeAndExpensesRetainedChange") AND Not StructureTemporaryTables.RegisterRecordsIncomeAndExpensesRetainedChange Then
		
		// If the temporary table "RegisterRecordsIncomeAndExpensesRetainedChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsIncomeAndExpensesRetainedBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	AccumulationRegisterDeferredIncomeAndExpenditure.LineNumber AS LineNumber,
		|	AccumulationRegisterDeferredIncomeAndExpenditure.Company AS Company,
		|	AccumulationRegisterDeferredIncomeAndExpenditure.Document AS Document,
		|	AccumulationRegisterDeferredIncomeAndExpenditure.BusinessActivity AS BusinessActivity,
		|	CASE
		|		WHEN AccumulationRegisterDeferredIncomeAndExpenditure.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterDeferredIncomeAndExpenditure.AmountIncome
		|		ELSE -AccumulationRegisterDeferredIncomeAndExpenditure.AmountIncome
		|	END AS AmountIncomeBeforeWrite,
		|	CASE
		|		WHEN AccumulationRegisterDeferredIncomeAndExpenditure.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterDeferredIncomeAndExpenditure.AmountExpense
		|		ELSE -AccumulationRegisterDeferredIncomeAndExpenditure.AmountExpense
		|	END AS AmountExpensesBeforeWrite
		|INTO RegisterRecordsIncomeAndExpensesRetainedBeforeWrite
		|FROM
		|	AccumulationRegister.IncomeAndExpensesRetained AS AccumulationRegisterDeferredIncomeAndExpenditure
		|WHERE
		|	AccumulationRegisterDeferredIncomeAndExpenditure.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsIncomeAndExpensesRetainedChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsIncomeAndExpensesRetainedBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsIncomeAndExpensesRetainedChange.LineNumber AS LineNumber,
		|	RegisterRecordsIncomeAndExpensesRetainedChange.Company AS Company,
		|	RegisterRecordsIncomeAndExpensesRetainedChange.Document AS Document,
		|	RegisterRecordsIncomeAndExpensesRetainedChange.BusinessActivity AS BusinessActivity,
		|	RegisterRecordsIncomeAndExpensesRetainedChange.AmountIncomeBeforeWrite AS AmountIncomeBeforeWrite,
		|	RegisterRecordsIncomeAndExpensesRetainedChange.AmountExpensesBeforeWrite AS AmountExpensesBeforeWrite
		|INTO RegisterRecordsIncomeAndExpensesRetainedBeforeWrite
		|FROM
		|	RegisterRecordsIncomeAndExpensesRetainedChange AS RegisterRecordsIncomeAndExpensesRetainedChange
		|
		|UNION ALL
		|
		|SELECT
		|	AccumulationRegisterDeferredIncomeAndExpenditure.LineNumber,
		|	AccumulationRegisterDeferredIncomeAndExpenditure.Company,
		|	AccumulationRegisterDeferredIncomeAndExpenditure.Document,
		|	AccumulationRegisterDeferredIncomeAndExpenditure.BusinessActivity,
		|	CASE
		|		WHEN AccumulationRegisterDeferredIncomeAndExpenditure.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterDeferredIncomeAndExpenditure.AmountIncome
		|		ELSE -AccumulationRegisterDeferredIncomeAndExpenditure.AmountIncome
		|	END,
		|	CASE
		|		WHEN AccumulationRegisterDeferredIncomeAndExpenditure.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterDeferredIncomeAndExpenditure.AmountExpense
		|		ELSE -AccumulationRegisterDeferredIncomeAndExpenditure.AmountExpense
		|	END
		|FROM
		|	AccumulationRegister.IncomeAndExpensesRetained AS AccumulationRegisterDeferredIncomeAndExpenditure
		|WHERE
		|	AccumulationRegisterDeferredIncomeAndExpenditure.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsIncomeAndExpensesRetainedChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsIncomeAndExpensesRetainedChange") Then
		
		Query = New Query("DROP RegisterRecordsIncomeAndExpensesRetainedChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsIncomeAndExpensesRetainedChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsIncomeAndExpensesRetainedChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsIncomeAndExpensesRetainedChange.LineNumber) AS LineNumber,
	|	RegisterRecordsIncomeAndExpensesRetainedChange.Company AS Company,
	|	RegisterRecordsIncomeAndExpensesRetainedChange.Document AS Document,
	|	RegisterRecordsIncomeAndExpensesRetainedChange.BusinessActivity AS BusinessActivity,
	|	SUM(RegisterRecordsIncomeAndExpensesRetainedChange.AmountIncomeBeforeWrite) AS AmountIncomeBeforeWrite,
	|	SUM(RegisterRecordsIncomeAndExpensesRetainedChange.AmountIncomeUpdate) AS AmountIncomeUpdate,
	|	SUM(RegisterRecordsIncomeAndExpensesRetainedChange.AmountIncomeOnWrite) AS AmountIncomeOnWrite,
	|	SUM(RegisterRecordsIncomeAndExpensesRetainedChange.AmountExpensesBeforeWrite) AS AmountExpensesBeforeWrite,
	|	SUM(RegisterRecordsIncomeAndExpensesRetainedChange.AmountExpensesUpdate) AS AmountExpensesUpdate,
	|	SUM(RegisterRecordsIncomeAndExpensesRetainedChange.AmountExpensesOnWrite) AS AmountExpensesOnWrite
	|INTO RegisterRecordsIncomeAndExpensesRetainedChange
	|FROM
	|	(SELECT
	|		RegisterRecordsIncomeAndExpensesRetainedBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsIncomeAndExpensesRetainedBeforeWrite.Company AS Company,
	|		RegisterRecordsIncomeAndExpensesRetainedBeforeWrite.Document AS Document,
	|		RegisterRecordsIncomeAndExpensesRetainedBeforeWrite.BusinessActivity AS BusinessActivity,
	|		RegisterRecordsIncomeAndExpensesRetainedBeforeWrite.AmountIncomeBeforeWrite AS AmountIncomeBeforeWrite,
	|		RegisterRecordsIncomeAndExpensesRetainedBeforeWrite.AmountIncomeBeforeWrite AS AmountIncomeUpdate,
	|		0 AS AmountIncomeOnWrite,
	|		RegisterRecordsIncomeAndExpensesRetainedBeforeWrite.AmountExpensesBeforeWrite AS AmountExpensesBeforeWrite,
	|		RegisterRecordsIncomeAndExpensesRetainedBeforeWrite.AmountExpensesBeforeWrite AS AmountExpensesUpdate,
	|		0 AS AmountExpensesOnWrite
	|	FROM
	|		RegisterRecordsIncomeAndExpensesRetainedBeforeWrite AS RegisterRecordsIncomeAndExpensesRetainedBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsIncomeAndExpensesRetainedOnWrite.LineNumber,
	|		RegisterRecordsIncomeAndExpensesRetainedOnWrite.Company,
	|		RegisterRecordsIncomeAndExpensesRetainedOnWrite.Document,
	|		RegisterRecordsIncomeAndExpensesRetainedOnWrite.BusinessActivity,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsIncomeAndExpensesRetainedOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsIncomeAndExpensesRetainedOnWrite.AmountIncome
	|			ELSE RegisterRecordsIncomeAndExpensesRetainedOnWrite.AmountIncome
	|		END,
	|		RegisterRecordsIncomeAndExpensesRetainedOnWrite.AmountIncome,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsIncomeAndExpensesRetainedOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsIncomeAndExpensesRetainedOnWrite.AmountExpense
	|			ELSE RegisterRecordsIncomeAndExpensesRetainedOnWrite.AmountExpense
	|		END,
	|		RegisterRecordsIncomeAndExpensesRetainedOnWrite.AmountExpense
	|	FROM
	|		AccumulationRegister.IncomeAndExpensesRetained AS RegisterRecordsIncomeAndExpensesRetainedOnWrite
	|	WHERE
	|		RegisterRecordsIncomeAndExpensesRetainedOnWrite.Recorder = &Recorder) AS RegisterRecordsIncomeAndExpensesRetainedChange
	|
	|GROUP BY
	|	RegisterRecordsIncomeAndExpensesRetainedChange.Company,
	|	RegisterRecordsIncomeAndExpensesRetainedChange.Document,
	|	RegisterRecordsIncomeAndExpensesRetainedChange.BusinessActivity
	|
	|HAVING
	|	(SUM(RegisterRecordsIncomeAndExpensesRetainedChange.AmountIncomeUpdate) <> 0
	|		OR SUM(RegisterRecordsIncomeAndExpensesRetainedChange.AmountExpensesUpdate) <> 0)
	|
	|INDEX BY
	|	Company,
	|	Document,
	|	BusinessActivity");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsIncomeAndExpensesRetainedChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsIncomeAndExpensesRetainedChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsIncomeAndExpensesRetainedBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsIncomeAndExpensesRetainedBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf