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
	|	RetailAmountAccounting.LineNumber AS LineNumber,
	|	RetailAmountAccounting.Company AS Company,
	|	RetailAmountAccounting.StructuralUnit AS StructuralUnit,
	|	RetailAmountAccounting.Currency AS Currency,
	|	RetailAmountAccounting.Amount AS SumBeforeWrite,
	|	RetailAmountAccounting.Amount AS AmountChange,
	|	RetailAmountAccounting.Amount AS AmountOnWrite,
	|	RetailAmountAccounting.AmountCur AS AmountCurBeforeWrite,
	|	RetailAmountAccounting.AmountCur AS SumCurChange,
	|	RetailAmountAccounting.AmountCur AS SumCurOnWrite,
	|	RetailAmountAccounting.Cost AS CostBeforeWrite,
	|	RetailAmountAccounting.Cost AS CostUpdate,
	|	RetailAmountAccounting.Cost AS CostOnWrite
	|INTO RegisterRecordsRetailAmountAccountingUpdate
	|FROM
	|	AccumulationRegister.RetailAmountAccounting AS RetailAmountAccounting");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsRetailAmountAccountingUpdate", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf