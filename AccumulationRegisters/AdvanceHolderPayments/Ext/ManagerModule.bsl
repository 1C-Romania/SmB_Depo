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
	|	AccumulationRegisterAdvanceHolderPayments.LineNumber AS LineNumber,
	|	AccumulationRegisterAdvanceHolderPayments.Company AS Company,
	|	AccumulationRegisterAdvanceHolderPayments.Employee AS Employee,
	|	AccumulationRegisterAdvanceHolderPayments.Currency AS Currency,
	|	AccumulationRegisterAdvanceHolderPayments.Document AS Document,
	|	AccumulationRegisterAdvanceHolderPayments.Amount AS SumBeforeWrite,
	|	AccumulationRegisterAdvanceHolderPayments.Amount AS AmountChange,
	|	AccumulationRegisterAdvanceHolderPayments.Amount AS AmountOnWrite,
	|	AccumulationRegisterAdvanceHolderPayments.AmountCur AS AmountCurBeforeWrite,
	|	AccumulationRegisterAdvanceHolderPayments.AmountCur AS SumCurChange,
	|	AccumulationRegisterAdvanceHolderPayments.AmountCur AS SumCurOnWrite
	|INTO RegisterRecordsAdvanceHolderPaymentsChange
	|FROM
	|	AccumulationRegister.AdvanceHolderPayments AS AccumulationRegisterAdvanceHolderPayments");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsAdvanceHolderPaymentsChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf