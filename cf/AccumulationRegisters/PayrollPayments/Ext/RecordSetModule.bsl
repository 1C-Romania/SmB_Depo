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
	LockItem = Block.Add("AccumulationRegister.PayrollPayments.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsPayrollPaymentsUpdate") OR
		StructureTemporaryTables.Property("RegisterRecordsPayrollPaymentsUpdate") AND Not StructureTemporaryTables.RegisterRecordsPayrollPaymentsUpdate Then
		
		// If the temporary table "RegisterRecordsPayrollPaymentsChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsPayrollPaymentsBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	PayrollPayments.LineNumber AS LineNumber,
		|	PayrollPayments.Company AS Company,
		|	PayrollPayments.StructuralUnit AS StructuralUnit,
		|	PayrollPayments.Employee AS Employee,
		|	PayrollPayments.Currency AS Currency,
		|	PayrollPayments.RegistrationPeriod AS RegistrationPeriod,
		|	CASE
		|		WHEN PayrollPayments.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN PayrollPayments.Amount
		|		ELSE -PayrollPayments.Amount
		|	END AS SumBeforeWrite,
		|	CASE
		|		WHEN PayrollPayments.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN PayrollPayments.AmountCur
		|		ELSE -PayrollPayments.AmountCur
		|	END AS AmountCurBeforeWrite
		|INTO RegisterRecordsPayrollPaymentsBeforeWrite
		|FROM
		|	AccumulationRegister.PayrollPayments AS PayrollPayments
		|WHERE
		|	PayrollPayments.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsPayrollPaymentsChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsPayrollPaymentsBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsPayrollPaymentsUpdate.LineNumber AS LineNumber,
		|	RegisterRecordsPayrollPaymentsUpdate.Company AS Company,
		|	RegisterRecordsPayrollPaymentsUpdate.StructuralUnit AS StructuralUnit,
		|	RegisterRecordsPayrollPaymentsUpdate.Employee AS Employee,
		|	RegisterRecordsPayrollPaymentsUpdate.Currency AS Currency,
		|	RegisterRecordsPayrollPaymentsUpdate.RegistrationPeriod AS RegistrationPeriod,
		|	RegisterRecordsPayrollPaymentsUpdate.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsPayrollPaymentsUpdate.AmountCurBeforeWrite AS AmountCurBeforeWrite
		|INTO RegisterRecordsPayrollPaymentsBeforeWrite
		|FROM
		|	RegisterRecordsPayrollPaymentsUpdate AS RegisterRecordsPayrollPaymentsUpdate
		|
		|UNION ALL
		|
		|SELECT
		|	PayrollPayments.LineNumber,
		|	PayrollPayments.Company,
		|	PayrollPayments.StructuralUnit,
		|	PayrollPayments.Employee,
		|	PayrollPayments.Currency,
		|	PayrollPayments.RegistrationPeriod,
		|	CASE
		|		WHEN PayrollPayments.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN PayrollPayments.Amount
		|		ELSE -PayrollPayments.Amount
		|	END,
		|	CASE
		|		WHEN PayrollPayments.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN PayrollPayments.AmountCur
		|		ELSE -PayrollPayments.AmountCur
		|	END
		|FROM
		|	AccumulationRegister.PayrollPayments AS PayrollPayments
		|WHERE
		|	PayrollPayments.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsPayrollPaymentsChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsPayrollPaymentsUpdate") Then
		
		Query = New Query("DROP RegisterRecordsPayrollPaymentsChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsPayrollPaymentsUpdate");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsPayrollPaymentsChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsPayrollPaymentsUpdate.LineNumber) AS LineNumber,
	|	RegisterRecordsPayrollPaymentsUpdate.Company AS Company,
	|	RegisterRecordsPayrollPaymentsUpdate.StructuralUnit AS StructuralUnit,
	|	RegisterRecordsPayrollPaymentsUpdate.Employee AS Employee,
	|	RegisterRecordsPayrollPaymentsUpdate.Currency AS Currency,
	|	RegisterRecordsPayrollPaymentsUpdate.RegistrationPeriod AS RegistrationPeriod,
	|	SUM(RegisterRecordsPayrollPaymentsUpdate.SumBeforeWrite) AS SumBeforeWrite,
	|	SUM(RegisterRecordsPayrollPaymentsUpdate.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsPayrollPaymentsUpdate.AmountOnWrite) AS AmountOnWrite,
	|	SUM(RegisterRecordsPayrollPaymentsUpdate.AmountCurBeforeWrite) AS AmountCurBeforeWrite,
	|	SUM(RegisterRecordsPayrollPaymentsUpdate.SumCurChange) AS SumCurChange,
	|	SUM(RegisterRecordsPayrollPaymentsUpdate.SumCurOnWrite) AS SumCurOnWrite
	|INTO RegisterRecordsPayrollPaymentsUpdate
	|FROM
	|	(SELECT
	|		RegisterRecordsPayrollPaymentsBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsPayrollPaymentsBeforeWrite.Company AS Company,
	|		RegisterRecordsPayrollPaymentsBeforeWrite.StructuralUnit AS StructuralUnit,
	|		RegisterRecordsPayrollPaymentsBeforeWrite.Employee AS Employee,
	|		RegisterRecordsPayrollPaymentsBeforeWrite.Currency AS Currency,
	|		RegisterRecordsPayrollPaymentsBeforeWrite.RegistrationPeriod AS RegistrationPeriod,
	|		RegisterRecordsPayrollPaymentsBeforeWrite.SumBeforeWrite AS SumBeforeWrite,
	|		RegisterRecordsPayrollPaymentsBeforeWrite.SumBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite,
	|		RegisterRecordsPayrollPaymentsBeforeWrite.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|		RegisterRecordsPayrollPaymentsBeforeWrite.AmountCurBeforeWrite AS SumCurChange,
	|		0 AS SumCurOnWrite
	|	FROM
	|		RegisterRecordsPayrollPaymentsBeforeWrite AS RegisterRecordsPayrollPaymentsBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsPayrollPaymentsOnWrite.LineNumber,
	|		RegisterRecordsPayrollPaymentsOnWrite.Company,
	|		RegisterRecordsPayrollPaymentsOnWrite.StructuralUnit,
	|		RegisterRecordsPayrollPaymentsOnWrite.Employee,
	|		RegisterRecordsPayrollPaymentsOnWrite.Currency,
	|		RegisterRecordsPayrollPaymentsOnWrite.RegistrationPeriod,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsPayrollPaymentsOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsPayrollPaymentsOnWrite.Amount
	|			ELSE RegisterRecordsPayrollPaymentsOnWrite.Amount
	|		END,
	|		RegisterRecordsPayrollPaymentsOnWrite.Amount,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsPayrollPaymentsOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsPayrollPaymentsOnWrite.AmountCur
	|			ELSE RegisterRecordsPayrollPaymentsOnWrite.AmountCur
	|		END,
	|		RegisterRecordsPayrollPaymentsOnWrite.AmountCur
	|	FROM
	|		AccumulationRegister.PayrollPayments AS RegisterRecordsPayrollPaymentsOnWrite
	|	WHERE
	|		RegisterRecordsPayrollPaymentsOnWrite.Recorder = &Recorder) AS RegisterRecordsPayrollPaymentsUpdate
	|
	|GROUP BY
	|	RegisterRecordsPayrollPaymentsUpdate.Company,
	|	RegisterRecordsPayrollPaymentsUpdate.StructuralUnit,
	|	RegisterRecordsPayrollPaymentsUpdate.Employee,
	|	RegisterRecordsPayrollPaymentsUpdate.Currency,
	|	RegisterRecordsPayrollPaymentsUpdate.RegistrationPeriod
	|
	|HAVING
	|	(SUM(RegisterRecordsPayrollPaymentsUpdate.AmountChange) <> 0
	|		OR SUM(RegisterRecordsPayrollPaymentsUpdate.SumCurChange) <> 0)
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Employee,
	|	Currency,
	|	RegistrationPeriod");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsPayrollPaymentsChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsPayrollPaymentsUpdate", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsPayrollPaymentsBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsPayrollPaymentsBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf