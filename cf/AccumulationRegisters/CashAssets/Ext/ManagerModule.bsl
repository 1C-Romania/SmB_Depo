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
	|	CashAssets.LineNumber AS LineNumber,
	|	CashAssets.Company AS Company,
	|	CashAssets.CashAssetsType AS CashAssetsType,
	|	CashAssets.BankAccountPettyCash AS BankAccountPettyCash,
	|	CashAssets.Currency AS Currency,
	|	CashAssets.Amount AS SumBeforeWrite,
	|	CashAssets.Amount AS AmountChange,
	|	CashAssets.Amount AS AmountOnWrite,
	|	CashAssets.AmountCur AS AmountCurBeforeWrite,
	|	CashAssets.AmountCur AS SumCurChange,
	|	CashAssets.AmountCur AS SumCurOnWrite
	|INTO RegisterRecordsCashAssetsChange
	|FROM
	|	AccumulationRegister.CashAssets AS CashAssets");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsCashAssetsChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf