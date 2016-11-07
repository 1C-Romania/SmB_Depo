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
	LockItem = Block.Add("AccumulationRegister.FixedAssets.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsFixedAssetsChange") OR
		StructureTemporaryTables.Property("RegisterRecordsFixedAssetsChange") AND Not StructureTemporaryTables.RegisterRecordsFixedAssetsChange Then
		
		// If the temporary table "RegisterRecordsFixedAssetsChange" doesn't exist and doesn't
		// contain records about set change, then set is written for the first times and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsFixedAssetsBeforeWrite" when records get  new set change rather current.
		
		Query = New Query(
		"SELECT
		|	FixedAssets.LineNumber AS LineNumber,
		|	FixedAssets.Company AS Company,
		|	FixedAssets.FixedAsset AS FixedAsset,
		|	CASE
		|		WHEN FixedAssets.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN FixedAssets.Cost
		|		ELSE -FixedAssets.Cost
		|	END AS CostBeforeWrite,
		|	CASE
		|		WHEN FixedAssets.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN FixedAssets.Depreciation
		|		ELSE -FixedAssets.Depreciation
		|	END AS DepreciationBeforeWrite
		|INTO RegisterRecordsFixedAssetsBeforeWrite
		|FROM
		|	AccumulationRegister.FixedAssets AS FixedAssets
		|WHERE
		|	FixedAssets.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsFixedAssetsChange" exists and
		// contains records about set change, then set is written not for the first times and for set balance control wasn't executed.
		// Current set state current change state are placed in a
		// temporary table "RegisterRecordsFixedAssetsBeforeWrite" when records get new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsFixedAssetsChange.LineNumber AS LineNumber,
		|	RegisterRecordsFixedAssetsChange.Company AS Company,
		|	RegisterRecordsFixedAssetsChange.FixedAsset AS FixedAsset,
		|	RegisterRecordsFixedAssetsChange.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationBeforeWrite AS DepreciationBeforeWrite
		|INTO RegisterRecordsFixedAssetsBeforeWrite
		|FROM
		|	RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange
		|
		|UNION ALL
		|
		|SELECT
		|	FixedAssets.LineNumber,
		|	FixedAssets.Company,
		|	FixedAssets.FixedAsset,
		|	CASE
		|		WHEN FixedAssets.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN FixedAssets.Cost
		|		ELSE -FixedAssets.Cost
		|	END,
		|	CASE
		|		WHEN FixedAssets.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN FixedAssets.Depreciation
		|		ELSE -FixedAssets.Depreciation
		|	END
		|FROM
		|	AccumulationRegister.FixedAssets AS FixedAssets
		|WHERE
		|	FixedAssets.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsFixedAssetsChange" is destroyed Delete info about its existence.
	If StructureTemporaryTables.Property("RegisterRecordsFixedAssetsChange") Then
		
		Query = New Query("DROP RegisterRecordsFixedAssetsChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsFixedAssetsChange");
	
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
	// accounting accumulated changes and placed into temporary table "RegisterRecordsFixedAssetsChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsFixedAssetsChange.LineNumber) AS LineNumber,
	|	RegisterRecordsFixedAssetsChange.Company AS Company,
	|	RegisterRecordsFixedAssetsChange.FixedAsset AS FixedAsset,
	|	SUM(RegisterRecordsFixedAssetsChange.CostBeforeWrite) AS CostBeforeWrite,
	|	SUM(RegisterRecordsFixedAssetsChange.CostChanging) AS CostChanging,
	|	SUM(RegisterRecordsFixedAssetsChange.CostOnWrite) AS CostOnWrite,
	|	SUM(RegisterRecordsFixedAssetsChange.DepreciationBeforeWrite) AS DepreciationBeforeWrite,
	|	SUM(RegisterRecordsFixedAssetsChange.DepreciationUpdate) AS DepreciationUpdate,
	|	SUM(RegisterRecordsFixedAssetsChange.DepreciationOnWrite) AS DepreciationOnWrite
	|INTO RegisterRecordsFixedAssetsChange
	|FROM
	|	(SELECT
	|		RegisterRecordsFixedAssetsBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsFixedAssetsBeforeWrite.Company AS Company,
	|		RegisterRecordsFixedAssetsBeforeWrite.FixedAsset AS FixedAsset,
	|		RegisterRecordsFixedAssetsBeforeWrite.CostBeforeWrite AS CostBeforeWrite,
	|		RegisterRecordsFixedAssetsBeforeWrite.CostBeforeWrite AS CostChanging,
	|		0 AS CostOnWrite,
	|		RegisterRecordsFixedAssetsBeforeWrite.DepreciationBeforeWrite AS DepreciationBeforeWrite,
	|		RegisterRecordsFixedAssetsBeforeWrite.DepreciationBeforeWrite AS DepreciationUpdate,
	|		0 AS DepreciationOnWrite
	|	FROM
	|		RegisterRecordsFixedAssetsBeforeWrite AS RegisterRecordsFixedAssetsBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsFixedAssetsOnWrite.LineNumber,
	|		RegisterRecordsFixedAssetsOnWrite.Company,
	|		RegisterRecordsFixedAssetsOnWrite.FixedAsset,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsFixedAssetsOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsFixedAssetsOnWrite.Cost
	|			ELSE RegisterRecordsFixedAssetsOnWrite.Cost
	|		END,
	|		RegisterRecordsFixedAssetsOnWrite.Cost,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsFixedAssetsOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsFixedAssetsOnWrite.Depreciation
	|			ELSE RegisterRecordsFixedAssetsOnWrite.Depreciation
	|		END,
	|		RegisterRecordsFixedAssetsOnWrite.Depreciation
	|	FROM
	|		AccumulationRegister.FixedAssets AS RegisterRecordsFixedAssetsOnWrite
	|	WHERE
	|		RegisterRecordsFixedAssetsOnWrite.Recorder = &Recorder) AS RegisterRecordsFixedAssetsChange
	|
	|GROUP BY
	|	RegisterRecordsFixedAssetsChange.Company,
	|	RegisterRecordsFixedAssetsChange.FixedAsset
	|
	|HAVING
	|	(SUM(RegisterRecordsFixedAssetsChange.CostChanging) <> 0
	|		OR SUM(RegisterRecordsFixedAssetsChange.DepreciationUpdate) <> 0)
	|
	|INDEX BY
	|	Company,
	|	FixedAsset");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed in temporary table "RegisterRecordsFixedAssetsChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsFixedAssetsChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsFixedAssetsBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsFixedAssetsBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf