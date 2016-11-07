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
	LockItem = Block.Add("AccumulationRegister.IncomeAndExpensesUndistributed.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsIncomeAndExpensesUndistributedChange") OR
		StructureTemporaryTables.Property("RegisterRecordsIncomeAndExpensesUndistributedChange") AND Not StructureTemporaryTables.RegisterRecordsIncomeAndExpensesUndistributedChange Then
		
		// If the temporary table "RegisterRecordsIncomeAndExpensesUndistributedChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.LineNumber AS LineNumber,
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Company AS Company,
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Document AS Document,
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Item AS Item,
		|	CASE
		|		WHEN AccumulationRegisterUnassignedIncomesAndExpenditures.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterUnassignedIncomesAndExpenditures.AmountIncome
		|		ELSE -AccumulationRegisterUnassignedIncomesAndExpenditures.AmountIncome
		|	END AS AmountIncomeBeforeWrite,
		|	CASE
		|		WHEN AccumulationRegisterUnassignedIncomesAndExpenditures.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterUnassignedIncomesAndExpenditures.AmountExpense
		|		ELSE -AccumulationRegisterUnassignedIncomesAndExpenditures.AmountExpense
		|	END AS AmountExpensesBeforeWrite
		|INTO RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite
		|FROM
		|	AccumulationRegister.IncomeAndExpensesUndistributed AS AccumulationRegisterUnassignedIncomesAndExpenditures
		|WHERE
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsIncomeAndExpensesUndistributedChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsIncomeAndExpensesUndistributedChange.LineNumber AS LineNumber,
		|	RegisterRecordsIncomeAndExpensesUndistributedChange.Company AS Company,
		|	RegisterRecordsIncomeAndExpensesUndistributedChange.Document AS Document,
		|	RegisterRecordsIncomeAndExpensesUndistributedChange.Item AS Item,
		|	RegisterRecordsIncomeAndExpensesUndistributedChange.AmountIncomeBeforeWrite AS AmountIncomeBeforeWrite,
		|	RegisterRecordsIncomeAndExpensesUndistributedChange.AmountExpensesBeforeWrite AS AmountExpensesBeforeWrite
		|INTO RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite
		|FROM
		|	RegisterRecordsIncomeAndExpensesUndistributedChange AS RegisterRecordsIncomeAndExpensesUndistributedChange
		|
		|UNION ALL
		|
		|SELECT
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.LineNumber,
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Company,
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Document,
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Item,
		|	CASE
		|		WHEN AccumulationRegisterUnassignedIncomesAndExpenditures.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterUnassignedIncomesAndExpenditures.AmountIncome
		|		ELSE -AccumulationRegisterUnassignedIncomesAndExpenditures.AmountIncome
		|	END,
		|	CASE
		|		WHEN AccumulationRegisterUnassignedIncomesAndExpenditures.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterUnassignedIncomesAndExpenditures.AmountExpense
		|		ELSE -AccumulationRegisterUnassignedIncomesAndExpenditures.AmountExpense
		|	END
		|FROM
		|	AccumulationRegister.IncomeAndExpensesUndistributed AS AccumulationRegisterUnassignedIncomesAndExpenditures
		|WHERE
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsIncomeAndExpensesUndistributedChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsIncomeAndExpensesUndistributedChange") Then
		
		Query = New Query("DROP RegisterRecordsIncomeAndExpensesUndistributedChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsIncomeAndExpensesUndistributedChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsIncomeAndExpensesUndistributedChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsIncomeAndExpensesUndistributedChange.LineNumber) AS LineNumber,
	|	RegisterRecordsIncomeAndExpensesUndistributedChange.Company AS Company,
	|	RegisterRecordsIncomeAndExpensesUndistributedChange.Document AS Document,
	|	RegisterRecordsIncomeAndExpensesUndistributedChange.Item AS Item,
	|	SUM(RegisterRecordsIncomeAndExpensesUndistributedChange.AmountIncomeBeforeWrite) AS AmountIncomeBeforeWrite,
	|	SUM(RegisterRecordsIncomeAndExpensesUndistributedChange.AmountIncomeUpdate) AS AmountIncomeUpdate,
	|	SUM(RegisterRecordsIncomeAndExpensesUndistributedChange.AmountIncomeOnWrite) AS AmountIncomeOnWrite,
	|	SUM(RegisterRecordsIncomeAndExpensesUndistributedChange.AmountExpensesBeforeWrite) AS AmountExpensesBeforeWrite,
	|	SUM(RegisterRecordsIncomeAndExpensesUndistributedChange.AmountExpensesUpdate) AS AmountExpensesUpdate,
	|	SUM(RegisterRecordsIncomeAndExpensesUndistributedChange.AmountExpensesOnWrite) AS AmountExpensesOnWrite
	|INTO RegisterRecordsIncomeAndExpensesUndistributedChange
	|FROM
	|	(SELECT
	|		RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite.Company AS Company,
	|		RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite.Document AS Document,
	|		RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite.Item AS Item,
	|		RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite.AmountIncomeBeforeWrite AS AmountIncomeBeforeWrite,
	|		RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite.AmountIncomeBeforeWrite AS AmountIncomeUpdate,
	|		0 AS AmountIncomeOnWrite,
	|		RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite.AmountExpensesBeforeWrite AS AmountExpensesBeforeWrite,
	|		RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite.AmountExpensesBeforeWrite AS AmountExpensesUpdate,
	|		0 AS AmountExpensesOnWrite
	|	FROM
	|		RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite AS RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsIncomeAndExpensesUndistributedOnWrite.LineNumber,
	|		RegisterRecordsIncomeAndExpensesUndistributedOnWrite.Company,
	|		RegisterRecordsIncomeAndExpensesUndistributedOnWrite.Document,
	|		RegisterRecordsIncomeAndExpensesUndistributedOnWrite.Item,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsIncomeAndExpensesUndistributedOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsIncomeAndExpensesUndistributedOnWrite.AmountIncome
	|			ELSE RegisterRecordsIncomeAndExpensesUndistributedOnWrite.AmountIncome
	|		END,
	|		RegisterRecordsIncomeAndExpensesUndistributedOnWrite.AmountIncome,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsIncomeAndExpensesUndistributedOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsIncomeAndExpensesUndistributedOnWrite.AmountExpense
	|			ELSE RegisterRecordsIncomeAndExpensesUndistributedOnWrite.AmountExpense
	|		END,
	|		RegisterRecordsIncomeAndExpensesUndistributedOnWrite.AmountExpense
	|	FROM
	|		AccumulationRegister.IncomeAndExpensesUndistributed AS RegisterRecordsIncomeAndExpensesUndistributedOnWrite
	|	WHERE
	|		RegisterRecordsIncomeAndExpensesUndistributedOnWrite.Recorder = &Recorder) AS RegisterRecordsIncomeAndExpensesUndistributedChange
	|
	|GROUP BY
	|	RegisterRecordsIncomeAndExpensesUndistributedChange.Company,
	|	RegisterRecordsIncomeAndExpensesUndistributedChange.Document,
	|	RegisterRecordsIncomeAndExpensesUndistributedChange.Item
	|
	|HAVING
	|	(SUM(RegisterRecordsIncomeAndExpensesUndistributedChange.AmountIncomeUpdate) <> 0
	|		OR SUM(RegisterRecordsIncomeAndExpensesUndistributedChange.AmountExpensesUpdate) <> 0)
	|
	|INDEX BY
	|	Company,
	|	Document,
	|	Item");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsIncomeAndExpensesUndistributedChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsIncomeAndExpensesUndistributedChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsIncomeAndExpensesUndistributedBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf