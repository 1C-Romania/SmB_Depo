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
	|	PayrollPayments.LineNumber AS LineNumber,
	|	PayrollPayments.Company AS Company,
	|	PayrollPayments.StructuralUnit AS StructuralUnit,
	|	PayrollPayments.Employee AS Employee,
	|	PayrollPayments.Currency AS Currency,
	|	PayrollPayments.RegistrationPeriod AS RegistrationPeriod,
	|	PayrollPayments.Amount AS SumBeforeWrite,
	|	PayrollPayments.Amount AS AmountChange,
	|	PayrollPayments.Amount AS AmountOnWrite,
	|	PayrollPayments.AmountCur AS AmountCurBeforeWrite,
	|	PayrollPayments.AmountCur AS SumCurChange,
	|	PayrollPayments.AmountCur AS SumCurOnWrite
	|INTO RegisterRecordsPayrollPaymentsUpdate
	|FROM
	|	AccumulationRegister.PayrollPayments AS PayrollPayments");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsPayrollPaymentsUpdate", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf