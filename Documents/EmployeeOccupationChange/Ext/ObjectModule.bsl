#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Function returns the tabular section filled with
// the scheduled accruals and deductions of employee
//
// Parameters:
//  FilterStructure - Structure contained data of person
//                 for who it is necessary to find accruals or deductions      
//
// Returns:
//  ValueTable with received accruals or deductions.
//
Function FindEmployeeAccrualsDeductions(FilterStructure, Tax = False) Export

	Query = New Query;
	Query.Text = "SELECT
	               |	AccrualsAndDeductionsPlanSliceLast.AccrualDeductionKind,
	               |	AccrualsAndDeductionsPlanSliceLast.Currency,
	               |	AccrualsAndDeductionsPlanSliceLast.GLExpenseAccount,
	               |	AccrualsAndDeductionsPlanSliceLast.Amount,
	               |	AccrualsAndDeductionsPlanSliceLast.Actuality
	               |FROM
	               |	InformationRegister.AccrualsAndDeductionsPlan.SliceLast(
	               |			&Date,
	               |			Employee = &Employee
	               |				AND Company = &Company
	               |				AND Recorder <> &Recorder
	               |				AND CASE
	               |					WHEN &Tax
	               |						THEN AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Tax)
	               |					ELSE AccrualDeductionKind.Type <> VALUE(Enum.AccrualAndDeductionTypes.Tax)
	               |				END) AS AccrualsAndDeductionsPlanSliceLast
	               |WHERE
	               |	AccrualsAndDeductionsPlanSliceLast.Actuality";
	
	Query.SetParameter("Employee", FilterStructure.Employee);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(FilterStructure.Company));
	Query.SetParameter("Date", FilterStructure.Date);
	Query.SetParameter("Recorder", Ref); 
	Query.SetParameter("Tax", Tax);
	
	ResultTable = Query.Execute().Unload();
	ResultArray = New Array;
    For Each TSRow IN ResultTable Do
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("AccrualDeductionKind", TSRow.AccrualDeductionKind);
        TabularSectionRow.Insert("Currency", 				TSRow.Currency);
		TabularSectionRow.Insert("GLExpenseAccount", 			TSRow.GLExpenseAccount);
		TabularSectionRow.Insert("Amount", 					TSRow.Amount);
		TabularSectionRow.Insert("Actuality", 			TSRow.Actuality);
		
		ResultArray.Add(TabularSectionRow);
		
	EndDo;
	
	Return ResultArray;
	
EndFunction // FindEmployeeDeductionAccruals()

// Controls conflicts.
//
Procedure RunPreliminaryControl(Cancel) 
	
	Query = New Query(
	"SELECT
	|	StaffDisplacementEmployees.LineNumber,
	|	StaffDisplacementEmployees.Employee,
	|	StaffDisplacementEmployees.Period,
	|	StaffDisplacementEmployees.ConnectionKey
	|INTO TableEmployees
	|FROM
	|	Document.EmployeeOccupationChange.Employees AS StaffDisplacementEmployees
	|WHERE
	|	StaffDisplacementEmployees.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableAccrualsDeductions.LineNumber,
	|	TableAccrualsDeductions.AccrualDeductionKind,
	|	TableAccrualsDeductions.Currency,
	|	TableEmployees.Employee,
	|	TableEmployees.Period
	|INTO TableAccrualsDeductions
	|FROM
	|	Document.EmployeeOccupationChange.AccrualsDeductions AS TableAccrualsDeductions
	|		INNER JOIN TableEmployees AS TableEmployees
	|		ON TableAccrualsDeductions.ConnectionKey = TableEmployees.ConnectionKey
	|			AND (TableAccrualsDeductions.Ref = &Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEmployees.LineNumber AS LineNumber,
	|	Employees.Recorder
	|FROM
	|	TableEmployees AS TableEmployees
	|		INNER JOIN InformationRegister.Employees AS Employees
	|		ON (Employees.Company = &Company)
	|			AND TableEmployees.Employee = Employees.Employee
	|			AND TableEmployees.Period = Employees.Period
	|			AND (Employees.Recorder <> &Ref)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableAccrualsDeductions.LineNumber AS LineNumber,
	|	AccrualsAndDeductionsPlan.Recorder
	|FROM
	|	InformationRegister.AccrualsAndDeductionsPlan AS AccrualsAndDeductionsPlan
	|		INNER JOIN TableAccrualsDeductions AS TableAccrualsDeductions
	|		ON (AccrualsAndDeductionsPlan.Company = &Company)
	|			AND AccrualsAndDeductionsPlan.Employee = TableAccrualsDeductions.Employee
	|			AND AccrualsAndDeductionsPlan.AccrualDeductionKind = TableAccrualsDeductions.AccrualDeductionKind
	|			AND AccrualsAndDeductionsPlan.Currency = TableAccrualsDeductions.Currency
	|			AND AccrualsAndDeductionsPlan.Period = TableAccrualsDeductions.Period
	|			AND (AccrualsAndDeductionsPlan.Recorder <> &Ref)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(TableEmployeesTwinsRows.LineNumber) AS LineNumber,
	|	TableEmployeesTwinsRows.Employee
	|FROM
	|	TableEmployees AS TableEmployees
	|		INNER JOIN TableEmployees AS TableEmployeesTwinsRows
	|		ON TableEmployees.LineNumber <> TableEmployeesTwinsRows.LineNumber
	|			AND TableEmployees.Employee = TableEmployeesTwinsRows.Employee
	|
	|GROUP BY
	|	TableEmployeesTwinsRows.Employee
	|
	|ORDER BY
	|	LineNumber");
	
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Register "Employees".
	If Not ResultsArray[2].IsEmpty() Then
		QueryResultSelection = ResultsArray[2].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr(
				"en = 'In row No.%Number% of the ""Employees"" tabular section the order validity conflicts with the personnel order ""%PersonnelOrder%"".'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%RegularOrder%", QueryResultSelection.Recorder);
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumber,
				"Period",
				Cancel);
		EndDo;
	EndIf;

	// Register "Planned accruals and deductions".
	If Not ResultsArray[3].IsEmpty() Then
		QueryResultSelection = ResultsArray[3].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr(
				"en = 'In row No.%Number% of the ""Accruals and deductions"" tabular section the order validity conflicts with personnel order ""%PersonnelOrder%"".'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%RegularOrder%", QueryResultSelection.Recorder);
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccrualsDeductions",
				QueryResultSelection.LineNumber,
				"Period",
				Cancel);
		EndDo;
	EndIf;
	
	// Row duplicates.
	If Not ResultsArray[4].IsEmpty() Then
		QueryResultSelection = ResultsArray[4].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr(
				"en = 'In row No.%Number% of the ""Employees"" tabular section the employee is specified repeatedly.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber);
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumber,
				"Employee",
				Cancel);
		EndDo;
	EndIf;	 
	
EndProcedure

// Controls conflicts.
//
Procedure RunControl(AdditionalProperties, Cancel) 
	
	If Cancel Then
		Return;	
	EndIf;
	
	Query = New Query(
	"SELECT
	|	NestedSelect.Employee,
	|	NestedSelect.LineNumber AS LineNumber,
	|	Employees.StructuralUnit
	|FROM
	|	(SELECT
	|		TableEmployees.Employee AS Employee,
	|		TableEmployees.LineNumber AS LineNumber,
	|		MAX(Employees.Period) AS Period
	|	FROM
	|		TableEmployees AS TableEmployees
	|			LEFT JOIN InformationRegister.Employees AS Employees
	|			ON (Employees.Employee = TableEmployees.Employee)
	|				AND (Employees.Company = &Company)
	|				AND (Employees.Period <= TableEmployees.Period)
	|				AND (Employees.Recorder <> &Ref)
	|	
	|	GROUP BY
	|		TableEmployees.Employee,
	|		TableEmployees.LineNumber) AS NestedSelect
	|		LEFT JOIN InformationRegister.Employees AS Employees
	|		ON NestedSelect.Employee = Employees.Employee
	|			AND NestedSelect.Period = Employees.Period
	|			AND (Employees.Company = &Company)
	|
	|ORDER BY
	|	LineNumber");
	
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	Result = Query.Execute();
	
	// Employee is not employed by the company as of the date of occupation change.
	QueryResultSelection = Result.Select();
	While QueryResultSelection.Next() Do
		If Not ValueIsFilled(QueryResultSelection.StructuralUnit) Then
		    MessageText = NStr(
				"en = 'In row No.%Number% of tabular section ""Employees"", the employee %Employee% is not hired to %Company% company.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%Employee%", QueryResultSelection.Employee); 
			MessageText = StrReplace(MessageText, "%Company%", AdditionalProperties.ForPosting.Company);
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumber,
				"Employee",
				Cancel);
		EndIf; 
	EndDo;	 
	
EndProcedure

// Controls the staff list.
//
Procedure RunControlStaffSchedule(AdditionalProperties, Cancel) 
	
	If Cancel OR Not Constants.FunctionalOptionDoStaffSchedule.Get() Then
		Return;	
	EndIf;
	
	If OperationKind = Enums.OperationKindsEmployeeOccupationChange.PaymentFormChange Then
		Return;
	EndIf; 
	
	Query = New Query("SELECT
	                      |	CASE
	                      |		WHEN ISNULL(TotalStaffList.CountOfRatesBySSh, 0) - ISNULL(TotalBusyBids.OccupiedRates, 0) < 0
	                      |			THEN TRUE
	                      |		ELSE FALSE
	                      |	END AS FontsContradiction,
	                      |	CASE
	                      |		WHEN TotalStaffList.LineNumber IS NULL 
	                      |			THEN TotalBusyBids.LineNumber
	                      |		ELSE TotalStaffList.LineNumber
	                      |	END AS LineNumber
	                      |FROM
	                      |	(SELECT
	                      |		StaffListMaxPeriods.LineNumber AS LineNumber,
	                      |		StaffList.NumberOfRates AS CountOfRatesBySSh,
	                      |		StaffList.StructuralUnit AS StructuralUnit,
	                      |		StaffList.Position AS Position,
	                      |		StaffList.Company AS Company
	                      |	FROM
	                      |		(SELECT
	                      |			StaffList.Company AS Company,
	                      |			StaffList.StructuralUnit AS StructuralUnit,
	                      |			StaffList.Position AS Position,
	                      |			MAX(StaffList.Period) AS Period,
	                      |			StaffDisplacementEmployees.LineNumber AS LineNumber
	                      |		FROM
	                      |			Document.EmployeeOccupationChange.Employees AS StaffDisplacementEmployees
	                      |				INNER JOIN InformationRegister.StaffList AS StaffList
	                      |				ON (StaffList.Company = &Company)
	                      |					AND StaffDisplacementEmployees.StructuralUnit = StaffList.StructuralUnit
	                      |					AND StaffDisplacementEmployees.Position = StaffList.Position
	                      |					AND StaffDisplacementEmployees.Period >= StaffList.Period
	                      |		WHERE
	                      |			StaffDisplacementEmployees.Ref = &Ref
	                      |		
	                      |		GROUP BY
	                      |			StaffList.Position,
	                      |			StaffList.StructuralUnit,
	                      |			StaffList.Company,
	                      |			StaffDisplacementEmployees.LineNumber) AS StaffListMaxPeriods
	                      |			LEFT JOIN InformationRegister.StaffList AS StaffList
	                      |			ON StaffListMaxPeriods.Period = StaffList.Period
	                      |				AND StaffListMaxPeriods.Company = StaffList.Company
	                      |				AND StaffListMaxPeriods.StructuralUnit = StaffList.StructuralUnit
	                      |				AND StaffListMaxPeriods.Position = StaffList.Position) AS TotalStaffList
	                      |		Full JOIN (SELECT
	                      |			Employees.StructuralUnit AS StructuralUnit,
	                      |			Employees.Position AS Position,
	                      |			SUM(Employees.OccupiedRates) AS OccupiedRates,
	                      |			Employees.Company AS Company,
	                      |			EmployeesMaximalPeriods.LineNumber AS LineNumber
	                      |		FROM
	                      |			(SELECT
	                      |				Employees.Company AS Company,
	                      |				MAX(Employees.Period) AS Period,
	                      |				StaffDisplacementEmployees.LineNumber AS LineNumber,
	                      |				Employees.Employee AS Employee,
	                      |				StaffDisplacementEmployees.StructuralUnit AS StructuralUnit,
	                      |				StaffDisplacementEmployees.Position AS Position
	                      |			FROM
	                      |				Document.EmployeeOccupationChange.Employees AS StaffDisplacementEmployees
	                      |					LEFT JOIN InformationRegister.Employees AS Employees
	                      |					ON (Employees.Company = &Company)
	                      |						AND StaffDisplacementEmployees.Period >= Employees.Period
	                      |			WHERE
	                      |				StaffDisplacementEmployees.Ref = &Ref
	                      |			
	                      |			GROUP BY
	                      |				Employees.Company,
	                      |				StaffDisplacementEmployees.LineNumber,
	                      |				Employees.Employee,
	                      |				StaffDisplacementEmployees.StructuralUnit,
	                      |				StaffDisplacementEmployees.Position) AS EmployeesMaximalPeriods
	                      |				INNER JOIN InformationRegister.Employees AS Employees
	                      |				ON (Employees.Company = &Company)
	                      |					AND EmployeesMaximalPeriods.Employee = Employees.Employee
	                      |					AND EmployeesMaximalPeriods.StructuralUnit = Employees.StructuralUnit
	                      |					AND EmployeesMaximalPeriods.Position = Employees.Position
	                      |					AND EmployeesMaximalPeriods.Period = Employees.Period
	                      |		WHERE
	                      |			Employees.StructuralUnit <> VALUE(Catalog.StructuralUnits.EmptyRef)
	                      |		
	                      |		GROUP BY
	                      |			Employees.StructuralUnit,
	                      |			Employees.Position,
	                      |			Employees.Company,
	                      |			EmployeesMaximalPeriods.LineNumber) AS TotalBusyBids
	                      |		ON TotalStaffList.LineNumber = TotalBusyBids.LineNumber
	                      |
	                      |ORDER BY
	                      |	LineNumber");
						  
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		If Selection.FontsContradiction Then
			MessageText = NStr("en = 'Row No.%Number% of the ""Employees"" tabular section: employment positions are not provided for in the staff list!'");
			MessageText = StrReplace(MessageText, "%Number%", Selection.LineNumber);
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				Selection.LineNumber,
				"OccupiedRates",
				);
		EndIf; 
	EndDo; 
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// IN handler of document event FillCheckProcessing,
// checked attributes are being copied and reset
// to exclude a standard platform fill check and subsequent check by embedded language tools.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Precheck
	RunPreliminaryControl(Cancel); 
	
	If OperationKind = Enums.OperationKindsEmployeeOccupationChange.TransferAndPaymentFormChange Then
		CheckedAttributes.Add("Employees.StructuralUnit");
		CheckedAttributes.Add("Employees.Position");
		CheckedAttributes.Add("Employees.CurrentPositions");
	EndIf;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.EmployeeOccupationChange.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectEmployees(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccrualsAndDeductionsPlan(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control
	RunControl(AdditionalProperties, Cancel);
	RunControlStaffSchedule(AdditionalProperties, Cancel);	
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
		
EndProcedure

#EndIf