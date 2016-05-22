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
	|	AccountsReceivable.LineNumber AS LineNumber,
	|	AccountsReceivable.Company AS Company,
	|	AccountsReceivable.Counterparty AS Counterparty,
	|	AccountsReceivable.Contract AS Contract,
	|	AccountsReceivable.Document AS Document,
	|	AccountsReceivable.Order AS Order,
	|	AccountsReceivable.SettlementsType AS SettlementsType,
	|	AccountsReceivable.Amount AS SumBeforeWrite,
	|	AccountsReceivable.Amount AS AmountChange,
	|	AccountsReceivable.Amount AS AmountOnWrite,
	|	AccountsReceivable.AmountCur AS AmountCurBeforeWrite,
	|	AccountsReceivable.AmountCur AS SumCurChange,
	|	AccountsReceivable.AmountCur AS SumCurOnWrite
	|INTO RegisterRecordsAccountsReceivableChange
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsAccountsReceivableChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf