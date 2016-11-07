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
	|	AccountsPayable.LineNumber AS LineNumber,
	|	AccountsPayable.Company AS Company,
	|	AccountsPayable.Counterparty AS Counterparty,
	|	AccountsPayable.Contract AS Contract,
	|	AccountsPayable.Document AS Document,
	|	AccountsPayable.Order AS Order,
	|	AccountsPayable.SettlementsType AS SettlementsType,
	|	AccountsPayable.Amount AS SumBeforeWrite,
	|	AccountsPayable.Amount AS AmountChange,
	|	AccountsPayable.Amount AS AmountOnWrite,
	|	AccountsPayable.AmountCur AS AmountCurBeforeWrite,
	|	AccountsPayable.AmountCur AS SumCurChange,
	|	AccountsPayable.AmountCur AS SumCurOnWrite
	|INTO RegisterRecordsSuppliersSettlementsChange
	|FROM
	|	AccumulationRegister.AccountsPayable AS AccountsPayable");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsSuppliersSettlementsChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf