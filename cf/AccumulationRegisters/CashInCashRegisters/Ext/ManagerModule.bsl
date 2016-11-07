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
	|	CashInCashRegisters.LineNumber AS LineNumber,
	|	CashInCashRegisters.Company AS Company,
	|	CashInCashRegisters.CashCR AS CashCR,
	|	CashInCashRegisters.Amount AS SumBeforeWrite,
	|	CashInCashRegisters.Amount AS AmountChange,
	|	CashInCashRegisters.Amount AS AmountOnWrite,
	|	CashInCashRegisters.AmountCur AS AmountCurBeforeWrite,
	|	CashInCashRegisters.AmountCur AS SumCurChange,
	|	CashInCashRegisters.AmountCur AS SumCurOnWrite
	|INTO RegisterRecordsCashInCashRegistersChange
	|FROM
	|	AccumulationRegister.CashInCashRegisters AS CashInCashRegisters");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsCashInCashRegistersChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf