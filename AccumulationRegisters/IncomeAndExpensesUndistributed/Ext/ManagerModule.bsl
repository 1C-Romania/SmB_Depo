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
	|	IncomeAndExpensesUndistributed.LineNumber AS LineNumber,
	|	IncomeAndExpensesUndistributed.Company AS Company,
	|	IncomeAndExpensesUndistributed.Document AS Document,
	|	IncomeAndExpensesUndistributed.Item AS Item,
	|	IncomeAndExpensesUndistributed.AmountIncome AS AmountIncomeBeforeWrite,
	|	IncomeAndExpensesUndistributed.AmountIncome AS AmountIncomeUpdate,
	|	IncomeAndExpensesUndistributed.AmountIncome AS AmountIncomeOnWrite,
	|	IncomeAndExpensesUndistributed.AmountExpense AS AmountExpensesBeforeWrite,
	|	IncomeAndExpensesUndistributed.AmountExpense AS AmountExpensesUpdate,
	|	IncomeAndExpensesUndistributed.AmountExpense AS AmountExpensesOnWrite
	|INTO RegisterRecordsIncomeAndExpensesUndistributedChange
	|FROM
	|	AccumulationRegister.IncomeAndExpensesUndistributed AS IncomeAndExpensesUndistributed");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsIncomeAndExpensesUndistributedChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf