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
	|	TaxesSettlements.LineNumber AS LineNumber,
	|	TaxesSettlements.Company AS Company,
	|	TaxesSettlements.TaxKind AS TaxKind,
	|	TaxesSettlements.Amount AS SumBeforeWrite,
	|	TaxesSettlements.Amount AS AmountChange,
	|	TaxesSettlements.Amount AS AmountOnWrite
	|INTO RegisterRecordsTaxesSettlementsUpdate
	|FROM
	|	AccumulationRegister.TaxesSettlements AS TaxesSettlements");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsTaxesSettlementsUpdate", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf