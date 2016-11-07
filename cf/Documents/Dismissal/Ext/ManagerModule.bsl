#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefDismissal, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	&Company AS Company,
	|	DismissalStaff.LineNumber,
	|	DismissalStaff.Employee,
	|	VALUE(Catalog.StructuralUnits.EmptyRef) AS StructuralUnit,
	|	VALUE(Catalog.Positions.EmptyRef) AS Position,
	|	DismissalStaff.Period
	|INTO TableEmployees
	|FROM
	|	Document.Dismissal.Employees AS DismissalStaff
	|WHERE
	|	DismissalStaff.Ref = &Ref
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEmployees.Company,
	|	TableEmployees.LineNumber,
	|	TableEmployees.Employee,
	|	TableEmployees.StructuralUnit,
	|	TableEmployees.Position,
	|	TableEmployees.Period
	|FROM
	|	TableEmployees AS TableEmployees
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.Employee,
	|	NestedSelect.AccrualDeductionKind,
	|	NestedSelect.Currency,
	|	NestedSelect.Company,
	|	FALSE AS Actuality,
	|	VALUE(ChartOfAccounts.Managerial.EmptyRef) AS GLExpenseAccount,
	|	0 AS Amount,
	|	NestedSelect.PeriodRows AS Period
	|FROM
	|	(SELECT
	|		TableEmployees.Employee AS Employee,
	|		MAX(AccrualsAndDeductionsPlan.Period) AS Period,
	|		AccrualsAndDeductionsPlan.AccrualDeductionKind AS AccrualDeductionKind,
	|		AccrualsAndDeductionsPlan.Currency AS Currency,
	|		AccrualsAndDeductionsPlan.Company AS Company,
	|		TableEmployees.Period AS PeriodRows
	|	FROM
	|		TableEmployees AS TableEmployees
	|			INNER JOIN InformationRegister.AccrualsAndDeductionsPlan AS AccrualsAndDeductionsPlan
	|			ON TableEmployees.Employee = AccrualsAndDeductionsPlan.Employee
	|				AND (AccrualsAndDeductionsPlan.Period <= TableEmployees.Period)
	|				AND TableEmployees.Company = AccrualsAndDeductionsPlan.Company
	|	
	|	GROUP BY
	|		AccrualsAndDeductionsPlan.AccrualDeductionKind,
	|		AccrualsAndDeductionsPlan.Currency,
	|		TableEmployees.Employee,
	|		TableEmployees.Period,
	|		AccrualsAndDeductionsPlan.Company) AS NestedSelect
	|		INNER JOIN InformationRegister.AccrualsAndDeductionsPlan AS AccrualsAndDeductionsPlan
	|		ON NestedSelect.Company = AccrualsAndDeductionsPlan.Company
	|			AND NestedSelect.Employee = AccrualsAndDeductionsPlan.Employee
	|			AND NestedSelect.AccrualDeductionKind = AccrualsAndDeductionsPlan.AccrualDeductionKind
	|			AND NestedSelect.Currency = AccrualsAndDeductionsPlan.Currency
	|			AND NestedSelect.Period = AccrualsAndDeductionsPlan.Period
	|WHERE
	|	AccrualsAndDeductionsPlan.Actuality");
	 
	Query.SetParameter("Ref", DocumentRefDismissal);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	TempTablesManager = New TempTablesManager;
	Query.TempTablesManager = TempTablesManager;
	
	ResultsArray = Query.ExecuteBatch();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableEmployees", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccrualsAndDeductionsPlan", ResultsArray[2].Unload());
	
	StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager = Query.TempTablesManager;
	
EndProcedure // DocumentDataInitialization()

#EndRegion

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