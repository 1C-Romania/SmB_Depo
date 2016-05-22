#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
	 OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then  	
		Return;  		
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	FixedAssets.LineNumber AS LineNumber,
	|	FixedAssets.Company AS Company,
	|	FixedAssets.FixedAsset AS FixedAsset,
	|	FixedAssets.Cost AS CostBeforeWrite,
	|	FixedAssets.Cost AS CostChanging,
	|	FixedAssets.Cost AS CostOnWrite,
	|	FixedAssets.Depreciation AS DepreciationBeforeWrite,
	|	FixedAssets.Depreciation AS DepreciationUpdate,
	|	FixedAssets.Depreciation AS DepreciationOnWrite
	|INTO RegisterRecordsFixedAssetsChange
	|FROM
	|	AccumulationRegister.FixedAssets AS FixedAssets");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsFixedAssetsChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf