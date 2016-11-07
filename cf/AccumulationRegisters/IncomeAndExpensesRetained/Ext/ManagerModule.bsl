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
	|	IncomeAndExpensesRetained.LineNumber AS LineNumber,
	|	IncomeAndExpensesRetained.Company AS Company,
	|	IncomeAndExpensesRetained.Document AS Document,
	|	IncomeAndExpensesRetained.BusinessActivity AS BusinessActivity,
	|	IncomeAndExpensesRetained.AmountIncome AS AmountIncomeBeforeWrite,
	|	IncomeAndExpensesRetained.AmountIncome AS AmountIncomeUpdate,
	|	IncomeAndExpensesRetained.AmountIncome AS AmountIncomeOnWrite,
	|	IncomeAndExpensesRetained.AmountExpense AS AmountExpensesBeforeWrite,
	|	IncomeAndExpensesRetained.AmountExpense AS AmountExpensesUpdate,
	|	IncomeAndExpensesRetained.AmountExpense AS AmountExpensesOnWrite
	|INTO RegisterRecordsIncomeAndExpensesRetainedChange
	|FROM
	|	AccumulationRegister.IncomeAndExpensesRetained AS IncomeAndExpensesRetained");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsIncomeAndExpensesRetainedChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf