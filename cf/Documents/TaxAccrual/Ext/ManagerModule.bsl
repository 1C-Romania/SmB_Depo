#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefTaxAccrual, StructureAdditionalProperties) Export
	
	Query = New Query(
	"SELECT
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsTaxAccrual.Accrual)
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	DocumentTable.Ref.Date AS Period,
	|	DocumentTable.TaxKind AS TaxKind,
	|	DocumentTable.TaxKind.GLAccount AS GLAccount,
	|	DocumentTable.Amount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsTaxAccrual.Accrual)
	|			THEN &AddedTax
	|		ELSE &RecoveredTax
	|	END AS ContentOfAccountingRecord
	|FROM
	|	Document.TaxAccrual.Taxes AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	DocumentTable.Ref.Date AS Period,
	|	CASE
	|		WHEN DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.BusinessActivities.Other)
	|		ELSE DocumentTable.BusinessActivity
	|	END AS BusinessActivity,
	|	DocumentTable.TaxKind AS TaxKind,
	|	CASE
	|		WHEN DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.StructuralUnits.EmptyRef)
	|		ELSE DocumentTable.Department
	|	END AS StructuralUnit,
	|	DocumentTable.Correspondence AS GLAccount,
	|	CASE
	|		WHEN DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.CustomerOrder
	|	END AS CustomerOrder,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsTaxAccrual.Accrual)
	|			THEN &Expenses
	|		ELSE &Incomings
	|	END AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsTaxAccrual.Accrual)
	|			THEN 0
	|		ELSE DocumentTable.Amount
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsTaxAccrual.Accrual)
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountExpense,
	|	DocumentTable.Amount AS Amount
	|FROM
	|	Document.TaxAccrual.Taxes AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			OR DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			OR DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Incomings)
	|			OR DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsTaxAccrual.Accrual)
	|			THEN DocumentTable.Correspondence
	|		ELSE DocumentTable.TaxKind.GLAccountForReimbursement
	|	END AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsTaxAccrual.Accrual)
	|			THEN DocumentTable.TaxKind.GLAccount
	|		ELSE DocumentTable.Correspondence
	|	END AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsTaxAccrual.Accrual)
	|			THEN &AddedTax
	|		ELSE &RecoveredTax
	|	END AS Content
	|FROM
	|	Document.TaxAccrual.Taxes AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsTaxAccrual.Accrual)
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Department AS StructuralUnit,
	|	DocumentTable.Correspondence AS GLAccount,
	|	DocumentTable.CustomerOrder AS CustomerOrder,
	|	DocumentTable.Amount AS Amount,
	|	TRUE AS FixedCost,
	|	&AddedTax AS ContentOfAccountingRecord
	|FROM
	|	Document.TaxAccrual.Taxes AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|			OR DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))");
	
	Query.SetParameter("Ref", DocumentRefTaxAccrual);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AddedTax", NStr("en='Tax accrued';ru='Начисленные налоги'"));
	Query.SetParameter("RecoveredTax", NStr("en='Tax reimbursed';ru='Возмещен налог'"));
	Query.SetParameter("Incomings", NStr("en='Incomings';ru='Доходы'")); 
	Query.SetParameter("Expenses", NStr("en='Expenses';ru='Расходы'")); 
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxAccounting", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[3].Unload());
	
EndProcedure // DocumentDataInitialization()

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf