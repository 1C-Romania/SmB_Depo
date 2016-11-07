#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefHrMove, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	&Company AS Company,
	|	StaffDisplacementEmployees.LineNumber,
	|	StaffDisplacementEmployees.Employee,
	|	StaffDisplacementEmployees.StructuralUnit,
	|	StaffDisplacementEmployees.Position,
	|	StaffDisplacementEmployees.WorkSchedule,
	|	StaffDisplacementEmployees.OccupiedRates,
	|	StaffDisplacementEmployees.Period,
	|	StaffDisplacementEmployees.Ref
	|INTO TableEmployees
	|FROM
	|	Document.EmployeeOccupationChange.Employees AS StaffDisplacementEmployees
	|WHERE
	|	StaffDisplacementEmployees.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	StaffDisplacementEmployees.LineNumber,
	|	StaffDisplacementEmployees.Employee,
	|	StaffDisplacementEmployees.Period,
	|	StaffDisplacementAccrualsDeductions.AccrualDeductionKind AS AccrualDeductionKind,
	|	StaffDisplacementAccrualsDeductions.Currency,
	|	StaffDisplacementAccrualsDeductions.Amount AS Amount,
	|	StaffDisplacementAccrualsDeductions.GLExpenseAccount,
	|	StaffDisplacementAccrualsDeductions.Actuality
	|INTO TableAccrualsDeductions
	|FROM
	|	Document.EmployeeOccupationChange.Employees AS StaffDisplacementEmployees
	|		INNER JOIN Document.EmployeeOccupationChange.AccrualsDeductions AS StaffDisplacementAccrualsDeductions
	|		ON StaffDisplacementEmployees.ConnectionKey = StaffDisplacementAccrualsDeductions.ConnectionKey
	|WHERE
	|	StaffDisplacementEmployees.Ref = &Ref
	|	AND StaffDisplacementAccrualsDeductions.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	StaffDisplacementEmployees.LineNumber,
	|	StaffDisplacementEmployees.Employee,
	|	StaffDisplacementEmployees.Period,
	|	StaffDisplacementIncomeTaxes.AccrualDeductionKind,
	|	StaffDisplacementIncomeTaxes.Currency,
	|	0,
	|	UNDEFINED,
	|	StaffDisplacementIncomeTaxes.Actuality
	|FROM
	|	Document.EmployeeOccupationChange.Employees AS StaffDisplacementEmployees
	|		INNER JOIN Document.EmployeeOccupationChange.IncomeTaxes AS StaffDisplacementIncomeTaxes
	|		ON StaffDisplacementEmployees.ConnectionKey = StaffDisplacementIncomeTaxes.ConnectionKey
	|WHERE
	|	StaffDisplacementEmployees.Ref = &Ref
	|	AND StaffDisplacementIncomeTaxes.Ref = &Ref
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
	|WHERE
	|	TableEmployees.Ref.OperationKind = VALUE(Enum.OperationKindsEmployeeOccupationChange.TransferAndPaymentFormChange)
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
	|	TableAccrualsDeductions.Actuality
	|FROM
	|	TableAccrualsDeductions AS TableAccrualsDeductions");
	                
	Query.SetParameter("Ref", DocumentRefHrMove);
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