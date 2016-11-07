#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefCreateEmploymentContract, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT 
	|	&Company AS Company,
	|	EmploymentContractEmployees.LineNumber,
	|	EmploymentContractEmployees.Employee,
	|	EmploymentContractEmployees.StructuralUnit,
	|	EmploymentContractEmployees.Position,
	|	EmploymentContractEmployees.WorkSchedule,
	|	EmploymentContractEmployees.OccupiedRates,
	|	EmploymentContractEmployees.Period
	|INTO TableEmployees
	|FROM
	|	Document.EmploymentContract.Employees AS EmploymentContractEmployees
	|WHERE
	|	EmploymentContractEmployees.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT 
	|	&Company AS Company,
	|	EmploymentContractEmployees.LineNumber,
	|	EmploymentContractEmployees.Employee,
	|	EmploymentContractEmployees.Period,
	|	EmploymentContractPayrollRetention.AccrualDeductionKind,
	|	EmploymentContractPayrollRetention.Currency,
	|	EmploymentContractPayrollRetention.Amount,
	|	EmploymentContractPayrollRetention.GLExpenseAccount
	|INTO TableAccrualsDeductions
	|FROM
	|	Document.EmploymentContract.Employees AS EmploymentContractEmployees
	|		INNER JOIN Document.EmploymentContract.AccrualsDeductions AS EmploymentContractPayrollRetention
	|		ON EmploymentContractEmployees.ConnectionKey = EmploymentContractPayrollRetention.ConnectionKey
	|			AND EmploymentContractEmployees.Ref = EmploymentContractPayrollRetention.Ref
	|WHERE
	|	EmploymentContractEmployees.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	EmploymentContractEmployees.LineNumber,
	|	EmploymentContractEmployees.Employee,
	|	EmploymentContractEmployees.Period,
	|	EmploymentContractIncomeTaxes.AccrualDeductionKind,
	|	EmploymentContractIncomeTaxes.Currency,
	|	0,
	|	UNDEFINED
	|FROM
	|	Document.EmploymentContract.Employees AS EmploymentContractEmployees
	|		INNER JOIN Document.EmploymentContract.IncomeTaxes AS EmploymentContractIncomeTaxes
	|		ON EmploymentContractEmployees.ConnectionKey = EmploymentContractIncomeTaxes.ConnectionKey
	|			AND EmploymentContractEmployees.Ref = EmploymentContractIncomeTaxes.Ref
	|WHERE
	|	EmploymentContractEmployees.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT 
	|	TableEmployees.Company,
	|	TableEmployees.LineNumber,
	|	TableEmployees.Employee,
	|	TableEmployees.StructuralUnit,
	|	TableEmployees.Position,
	|	TableEmployees.WorkSchedule,
	|	TableEmployees.OccupiedRates,
	|	TableEmployees.Period
	|FROM
	|	TableEmployees AS TableEmployees
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT 
	|	TableAccrualsDeductions.Company,
	|	TableAccrualsDeductions.LineNumber,
	|	TableAccrualsDeductions.Employee,
	|	TableAccrualsDeductions.Period,
	|	TableAccrualsDeductions.AccrualDeductionKind,
	|	TableAccrualsDeductions.Currency,
	|	TableAccrualsDeductions.Amount,
	|	TableAccrualsDeductions.GLExpenseAccount,
	|	TRUE AS Actuality
	|FROM
	|	TableAccrualsDeductions AS TableAccrualsDeductions");
	
	Query.SetParameter("Ref", DocumentRefCreateEmploymentContract);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	TempTablesManager = New TempTablesManager;
	Query.TempTablesManager = TempTablesManager;
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableEmployees", 				ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccrualsAndDeductionsPlan", ResultsArray[3].Unload());
	
	StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager = Query.TempTablesManager;
	
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