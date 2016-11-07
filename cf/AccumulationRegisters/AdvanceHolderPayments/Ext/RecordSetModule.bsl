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
	LockItem = Block.Add("AccumulationRegister.AdvanceHolderPayments.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsAdvanceHolderPaymentsChange")
	    OR StructureTemporaryTables.Property("RegisterRecordsAdvanceHolderPaymentsChange")
	   AND Not StructureTemporaryTables.RegisterRecordsAdvanceHolderPaymentsChange Then
		
		// If the temporary table "RegisterRecordsAdvanceHolderPaymentsChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsAdvanceHolderPaymentsBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	RegisterAdvanceHolderPaymentss.LineNumber AS LineNumber,
		|	RegisterAdvanceHolderPaymentss.Company AS Company,
		|	RegisterAdvanceHolderPaymentss.Employee AS Employee,
		|	RegisterAdvanceHolderPaymentss.Currency AS Currency,
		|	RegisterAdvanceHolderPaymentss.Document AS Document,
		|	CASE
		|		WHEN RegisterAdvanceHolderPaymentss.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN RegisterAdvanceHolderPaymentss.Amount
		|		ELSE -RegisterAdvanceHolderPaymentss.Amount
		|	END AS SumBeforeWrite,
		|	CASE
		|		WHEN RegisterAdvanceHolderPaymentss.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN RegisterAdvanceHolderPaymentss.AmountCur
		|		ELSE -RegisterAdvanceHolderPaymentss.AmountCur
		|	END AS AmountCurBeforeWrite
		|INTO RegisterRecordsAdvanceHolderPaymentsBeforeWrite
		|FROM
		|	AccumulationRegister.AdvanceHolderPayments AS RegisterAdvanceHolderPaymentss
		|WHERE
		|	RegisterAdvanceHolderPaymentss.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsAdvanceHolderPaymentsChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsAdvanceHolderPaymentsBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsAdvanceHolderPaymentsChange.LineNumber AS LineNumber,
		|	RegisterRecordsAdvanceHolderPaymentsChange.Company AS Company,
		|	RegisterRecordsAdvanceHolderPaymentsChange.Employee AS Employee,
		|	RegisterRecordsAdvanceHolderPaymentsChange.Currency AS Currency,
		|	RegisterRecordsAdvanceHolderPaymentsChange.Document AS Document,
		|	RegisterRecordsAdvanceHolderPaymentsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAdvanceHolderPaymentsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite
		|INTO RegisterRecordsAdvanceHolderPaymentsBeforeWrite
		|FROM
		|	RegisterRecordsAdvanceHolderPaymentsChange AS RegisterRecordsAdvanceHolderPaymentsChange
		|
		|UNION ALL
		|
		|SELECT
		|	RegisterAdvanceHolderPaymentss.LineNumber,
		|	RegisterAdvanceHolderPaymentss.Company,
		|	RegisterAdvanceHolderPaymentss.Employee,
		|	RegisterAdvanceHolderPaymentss.Currency,
		|	RegisterAdvanceHolderPaymentss.Document,
		|	CASE
		|		WHEN RegisterAdvanceHolderPaymentss.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN RegisterAdvanceHolderPaymentss.Amount
		|		ELSE -RegisterAdvanceHolderPaymentss.Amount
		|	END,
		|	CASE
		|		WHEN RegisterAdvanceHolderPaymentss.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN RegisterAdvanceHolderPaymentss.AmountCur
		|		ELSE -RegisterAdvanceHolderPaymentss.AmountCur
		|	END
		|FROM
		|	AccumulationRegister.AdvanceHolderPayments AS RegisterAdvanceHolderPaymentss
		|WHERE
		|	RegisterAdvanceHolderPaymentss.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsAdvanceHolderPaymentsChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsAdvanceHolderPaymentsChange") Then
		
		Query = New Query("DROP RegisterRecordsAdvanceHolderPaymentsChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsAdvanceHolderPaymentsChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsAdvanceHolderPaymentsChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsAdvanceHolderPaymentsChange.LineNumber) AS LineNumber,
	|	RegisterRecordsAdvanceHolderPaymentsChange.Company AS Company,
	|	RegisterRecordsAdvanceHolderPaymentsChange.Employee AS Employee,
	|	RegisterRecordsAdvanceHolderPaymentsChange.Currency AS Currency,
	|	RegisterRecordsAdvanceHolderPaymentsChange.Document AS Document,
	|	SUM(RegisterRecordsAdvanceHolderPaymentsChange.SumBeforeWrite) AS SumBeforeWrite,
	|	SUM(RegisterRecordsAdvanceHolderPaymentsChange.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsAdvanceHolderPaymentsChange.AmountOnWrite) AS AmountOnWrite,
	|	SUM(RegisterRecordsAdvanceHolderPaymentsChange.AmountCurBeforeWrite) AS AmountCurBeforeWrite,
	|	SUM(RegisterRecordsAdvanceHolderPaymentsChange.SumCurChange) AS SumCurChange,
	|	SUM(RegisterRecordsAdvanceHolderPaymentsChange.SumCurOnWrite) AS SumCurOnWrite
	|INTO RegisterRecordsAdvanceHolderPaymentsChange
	|FROM
	|	(SELECT
	|		RegisterRecordsAdvanceHolderPaymentsBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsAdvanceHolderPaymentsBeforeWrite.Company AS Company,
	|		RegisterRecordsAdvanceHolderPaymentsBeforeWrite.Employee AS Employee,
	|		RegisterRecordsAdvanceHolderPaymentsBeforeWrite.Currency AS Currency,
	|		RegisterRecordsAdvanceHolderPaymentsBeforeWrite.Document AS Document,
	|		RegisterRecordsAdvanceHolderPaymentsBeforeWrite.SumBeforeWrite AS SumBeforeWrite,
	|		RegisterRecordsAdvanceHolderPaymentsBeforeWrite.SumBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite,
	|		RegisterRecordsAdvanceHolderPaymentsBeforeWrite.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|		RegisterRecordsAdvanceHolderPaymentsBeforeWrite.AmountCurBeforeWrite AS SumCurChange,
	|		0 AS SumCurOnWrite
	|	FROM
	|		RegisterRecordsAdvanceHolderPaymentsBeforeWrite AS RegisterRecordsAdvanceHolderPaymentsBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsAdvanceHolderPaymentsOnWrite.LineNumber,
	|		RegisterRecordsAdvanceHolderPaymentsOnWrite.Company,
	|		RegisterRecordsAdvanceHolderPaymentsOnWrite.Employee,
	|		RegisterRecordsAdvanceHolderPaymentsOnWrite.Currency,
	|		RegisterRecordsAdvanceHolderPaymentsOnWrite.Document,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsAdvanceHolderPaymentsOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsAdvanceHolderPaymentsOnWrite.Amount
	|			ELSE RegisterRecordsAdvanceHolderPaymentsOnWrite.Amount
	|		END,
	|		RegisterRecordsAdvanceHolderPaymentsOnWrite.Amount,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsAdvanceHolderPaymentsOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsAdvanceHolderPaymentsOnWrite.AmountCur
	|			ELSE RegisterRecordsAdvanceHolderPaymentsOnWrite.AmountCur
	|		END,
	|		RegisterRecordsAdvanceHolderPaymentsOnWrite.AmountCur
	|	FROM
	|		AccumulationRegister.AdvanceHolderPayments AS RegisterRecordsAdvanceHolderPaymentsOnWrite
	|	WHERE
	|		RegisterRecordsAdvanceHolderPaymentsOnWrite.Recorder = &Recorder) AS RegisterRecordsAdvanceHolderPaymentsChange
	|
	|GROUP BY
	|	RegisterRecordsAdvanceHolderPaymentsChange.Company,
	|	RegisterRecordsAdvanceHolderPaymentsChange.Employee,
	|	RegisterRecordsAdvanceHolderPaymentsChange.Currency,
	|	RegisterRecordsAdvanceHolderPaymentsChange.Document
	|
	|HAVING
	|	(SUM(RegisterRecordsAdvanceHolderPaymentsChange.AmountChange) <> 0
	|		OR SUM(RegisterRecordsAdvanceHolderPaymentsChange.SumCurChange) <> 0)
	|
	|INDEX BY
	|	Company,
	|	Employee,
	|	Currency,
	|	Document");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsAdvanceHolderPaymentsChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsAdvanceHolderPaymentsChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsAdvanceHolderPaymentsBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsAdvanceHolderPaymentsBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf