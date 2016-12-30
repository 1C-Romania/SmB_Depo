#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Controls conflicts.
//
Procedure RunPreliminaryControl(Cancel)
	
	TableEmployees 			= Employees.Unload(,"LineNumber, Employee, Period, ConnectionKey");
	TableAccrualsDeductions 	= AccrualsDeductions.Unload(,"LineNumber, AccrualDeductionKind, Currency, ConnectionKey");
	
	//Add columns and fill by connection key. 
	//Link is mandatory and it must correspond to one employee only.
	TableAccrualsDeductions.Columns.Add("Employee", New TypeDescription("CatalogRef.Employees"));
	TableAccrualsDeductions.Columns.Add("Period", New TypeDescription("Date"));
	
	For Each AccrualDetentionRow IN TableAccrualsDeductions Do
		
		RowsOfEmployeesArray = TableEmployees.FindRows(New Structure("ConnectionKey", AccrualDetentionRow.ConnectionKey));
		
		If RowsOfEmployeesArray.Count() = 1 Then
			
			AccrualDetentionRow.Employee	= RowsOfEmployeesArray[0].Employee;
			AccrualDetentionRow.Period	= RowsOfEmployeesArray[0].Period;
			
		Else
			
			//Erroneous link, it must not exist, but the check remains
			MessageText = NStr("en='Invalid link condition in row No.%Number% of the ""Accruals and deductions"" tabular section.';ru='Не верное условие связи в строке №%Номер% табл. части ""Начислений и удержаний"".'");
			MessageText = StrReplace(MessageText, "%Number%", AccrualDetentionRow.LineNumber); 
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccrualsDeductions",
				 AccrualDetentionRow.LineNumber,
				"LineNumber",
				Cancel);
			
		EndIf;
		
	EndDo;
	
	Query = New Query(
	"SELECT 
	|	EmploymentContractEmployees.LineNumber,
	|	EmploymentContractEmployees.Employee,
	|	EmploymentContractEmployees.Period,
	|	EmploymentContractEmployees.ConnectionKey
	|INTO TableEmployees
	|FROM
	|	&TableEmployees AS EmploymentContractEmployees
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT 
	|	TableAccrualsDeductions.LineNumber,
	|	TableAccrualsDeductions.AccrualDeductionKind,
	|	TableAccrualsDeductions.Currency,
	|	TableAccrualsDeductions.Employee,
	|	TableAccrualsDeductions.Period
	|INTO TableAccrualsDeductions
	|FROM
	|	&TableAccrualsDeductions AS TableAccrualsDeductions
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
	
	
	Query.SetParameter("Ref", 					Ref);
	Query.Parameters.Insert("Company", 				SmallBusinessServer.GetCompany(Company));
	Query.Parameters.Insert("TableEmployees", 			TableEmployees);
	Query.Parameters.Insert("TableAccrualsDeductions", TableAccrualsDeductions);
	
	ResultsArray = Query.ExecuteBatch();
	
	// Register "Employees".
	If Not ResultsArray[2].IsEmpty() Then
		QueryResultSelection = ResultsArray[2].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en='In row No.%Number% of the ""Employees"" tabular section the order validity conflicts with the personnel order ""%PersonnelOrder%"".';ru='В строке №%Номер% табл. части ""Сотрудники"" период действия приказа противоречит кадровому приказу ""%КадровыйПриказ%"".'");
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
			MessageText = NStr("en='In row No.%Number% of the ""Accruals and deductions"" tabular section the order validity conflicts with personnel order ""%PersonnelOrder%"".';ru='В строке №%Номер% табл. части ""Начисления и удержания"" период действия приказа противоречит кадровому приказу ""%КадровыйПриказ%"".'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%RegularOrder%", QueryResultSelection.Recorder);
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccrualsDeductions",
				QueryResultSelection.LineNumber,
				"AccrualDeductionKind",
				Cancel);
		EndDo;
	EndIf;
	
	// Row duplicates.
	If Not ResultsArray[4].IsEmpty() Then
		QueryResultSelection = ResultsArray[4].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en='In row No.%Number% of the ""Employees"" tabular section the employee is specified repeatedly.';ru='В строке №%Номер% табл. части ""Сотрудники"" сотрудник указывается повторно.'");
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
	|	NestedSelect.LineNumber,
	|	Employees.StructuralUnit
	|FROM
	|	(SELECT
	|		TableEmployees.Employee AS Employee,
	|		TableEmployees.LineNumber AS LineNumber,
	|		MAX(Employees.Period) AS Period
	|	FROM
	|		InformationRegister.Employees AS Employees
	|			INNER JOIN TableEmployees AS TableEmployees
	|			ON Employees.Employee = TableEmployees.Employee
	|				AND (Employees.Company = &Company)
	|				AND Employees.Period <= TableEmployees.Period
	|				AND (Employees.Recorder <> &Ref)
	|	
	|	GROUP BY
	|		TableEmployees.Employee,
	|		TableEmployees.LineNumber) AS NestedSelect
	|		INNER JOIN InformationRegister.Employees AS Employees
	|		ON NestedSelect.Employee = Employees.Employee
	|			AND NestedSelect.Period = Employees.Period
	|			AND (Employees.Company = &Company)
	|WHERE
	|	Employees.StructuralUnit <> VALUE(Catalog.StructuralUnits.EmptyRef)
	|	
	|ORDER BY
	|	NestedSelect.LineNumber
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.Employee,
	|	NestedSelect.Employee.Ind AS Ind,
	|	NestedSelect.LineNumber,
	|	Employees.StructuralUnit,
	|	Employees.Employee AS AdoptedEmployee
	|FROM
	|	(SELECT
	|		TableEmployees.Employee AS Employee,
	|		TableEmployees.LineNumber AS LineNumber,
	|		MAX(Employees.Period) AS DateOfReception,
	|		Employees.Employee AS MainStaff
	|	FROM
	|		InformationRegister.Employees AS Employees
	|			INNER JOIN TableEmployees AS TableEmployees
	|			ON (Employees.Company = &Company)
	|				AND (Employees.Recorder <> &Ref)
	|				AND Employees.Period <= TableEmployees.Period
	|				AND TableEmployees.Employee.Ind <> VALUE(Catalog.Individuals.EmptyRef)
	|				AND Employees.Employee.Ind = TableEmployees.Employee.Ind
	|				AND (TableEmployees.Employee.OccupationType = VALUE(Enum.OccupationTypes.MainWorkplace))
	|				AND (Employees.Employee.OccupationType = VALUE(Enum.OccupationTypes.MainWorkplace))
	|	
	|	GROUP BY
	|		TableEmployees.Employee,
	|		TableEmployees.LineNumber,
	|		Employees.Employee) AS NestedSelect
	|		INNER JOIN InformationRegister.Employees AS Employees
	|		ON (Employees.Company = &Company)
	|			AND NestedSelect.MainStaff = Employees.Employee
	|			AND NestedSelect.DateOfReception = Employees.Period
	|WHERE
	|	Employees.StructuralUnit <> VALUE(Catalog.StructuralUnits.EmptyRef)
	|	
	|ORDER BY
	|	NestedSelect.LineNumber
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEmployees.LineNumber,
	|	EmployeesTableTwice.LineNumber AS LineNumberTwo,
	|	EmployeesTableTwice.Employee,
	|	TableEmployees.Employee.Ind AS Ind
	|FROM
	|	
	|		TableEmployees AS TableEmployees
	|			INNER JOIN TableEmployees AS EmployeesTableTwice
	|			ON TableEmployees.Employee.Ind = EmployeesTableTwice.Employee.Ind
	|				AND TableEmployees.Employee.Ind <> VALUE(Catalog.Individuals.EmptyRef)
	|				AND (TableEmployees.Employee.OccupationType = VALUE(Enum.OccupationTypes.MainWorkplace))
	|				AND (EmployeesTableTwice.Employee.OccupationType = VALUE(Enum.OccupationTypes.MainWorkplace))
	|				AND EmployeesTableTwice.LineNumber > TableEmployees.LineNumber
	|	
	|ORDER BY
	|	TableEmployees.LineNumber
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEmployees.LineNumber,
	|	Employees.Employee
	|FROM
	|	
	|		TableEmployees AS TableEmployees
	|			INNER JOIN InformationRegister.Employees AS Employees
	|			ON TableEmployees.Employee = Employees.Employee
	|				AND (Employees.Recorder <> &Ref)
	|				AND (Employees.Recorder REFS Document.EmploymentContract)
	|				AND (Employees.Period > TableEmployees.Period)
	|	
	|GROUP BY
	|		Employees.Employee,
	|		TableEmployees.LineNumber
	|		
	|ORDER BY
	|	TableEmployees.LineNumber");
	
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	ResultsArray = Query.ExecuteBatch();
	
	// Employee is already accepted on work to reception date.
	If Not ResultsArray[0].IsEmpty() Then
		QueryResultSelection = ResultsArray[0].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en='In row No.%Number% of the ""Employees"" tabular section the employee %Employee% is already working in the %StructuralUnit% department.';ru='В строке №%Номер% табл. части ""Сотрудники"" сотрудник %Сотрудник% уже работает в подразделении %СтруктурнаяЕдиница%.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%Employee%", QueryResultSelection.Employee); 
			MessageText = StrReplace(MessageText, "%StructuralUnit%", QueryResultSelection.StructuralUnit);
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumber,
				"Employee",
				Cancel);
		EndDo;
	EndIf;

	// For the Individual of Employee hired to a primary job, another Employee is already hired to a primary job.
	If Not ResultsArray[1].IsEmpty() Then
		QueryResultSelection = ResultsArray[1].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en='In row No.%Number% of the ""Employees"" tabular section for individual %Individual%, the employee %Employee% is already hired to a primary job in the %StructuralUnit% department.';ru='В строке №%Номер% табл. части ""Сотрудники"" для физлица %Физлицо% уже принят на основное место работы сотрудник %Сотрудник% в подразделение %СтруктурнаяЕдиница%.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%Employee%", QueryResultSelection.AdoptedEmployee); 
			MessageText = StrReplace(MessageText, "%StructuralUnit%", QueryResultSelection.StructuralUnit); 
			MessageText = StrReplace(MessageText, "%Ind%", QueryResultSelection.Ind);
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumber,
				"Employee",
				Cancel);
		EndDo;
	EndIf;

	// For Individual of the Employee, who is hired to a primary job, another Employee is already specified in this document with a primary job.
	If Not ResultsArray[2].IsEmpty() Then
		QueryResultSelection = ResultsArray[2].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en='In row No.%NumberDouble% of the ""Employees"" tabular section, for individual %Individual% the employee %Employee% is being hired repeatedly to a primary job. Individual is already specified in row No.%Number%.';ru='В строке №%НомерДубль% табл. части ""Сотрудники"" для физлица %Физлицо% повторно принимается на основное место работы сотрудник %Сотрудник%. Физлицо уже указано в строке №%Номер%.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%TwinNumber%", QueryResultSelection.LineNumberTwo); 
			MessageText = StrReplace(MessageText, "%Employee%", QueryResultSelection.Employee); 
			MessageText = StrReplace(MessageText, "%Ind%", QueryResultSelection.Ind);
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumberTwo,
				"Employee",
				Cancel);
		EndDo;
	EndIf;

	// The employee is hired repeatedly. 
	If Not ResultsArray[3].IsEmpty() Then
		QueryResultSelection = ResultsArray[3].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en='In row No.%Number% of the ""Employee"" tabular section: the employee %Employee% worked in the company earlier. To hire an employee once again, it is necessary to create a new employee.';ru='В строке №%Номер% табл. части ""Сотрудники"": сотрудник %Сотрудник% уже работал в компании. Для повторного приема на работу необходимо создать нового сотрудника.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%Employee%", QueryResultSelection.Employee);
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

// Controls the staff list.
//
Procedure RunControlStaffSchedule(AdditionalProperties, Cancel) 
	
	If Cancel OR Not Constants.FunctionalOptionDoStaffSchedule.Get() Then
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
	                      |			EmploymentContractEmployees.LineNumber AS LineNumber
	                      |		FROM
	                      |			Document.EmploymentContract.Employees AS EmploymentContractEmployees
	                      |				INNER JOIN InformationRegister.StaffList AS StaffList
	                      |				ON EmploymentContractEmployees.StructuralUnit = StaffList.StructuralUnit
	                      |					AND EmploymentContractEmployees.Position = StaffList.Position
	                      |					AND EmploymentContractEmployees.Period >= StaffList.Period
	                      |					AND (StaffList.Company = &Company)
	                      |		WHERE
	                      |			EmploymentContractEmployees.Ref = &Ref
	                      |		
	                      |		GROUP BY
	                      |			StaffList.Position,
	                      |			StaffList.StructuralUnit,
	                      |			StaffList.Company,
	                      |			EmploymentContractEmployees.LineNumber) AS StaffListMaxPeriods
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
	                      |				EmploymentContractEmployees.LineNumber AS LineNumber,
	                      |				Employees.Employee AS Employee,
	                      |				EmploymentContractEmployees.StructuralUnit AS StructuralUnit,
	                      |				EmploymentContractEmployees.Position AS Position
	                      |			FROM
	                      |				Document.EmploymentContract.Employees AS EmploymentContractEmployees
	                      |					LEFT JOIN InformationRegister.Employees AS Employees
	                      |					ON EmploymentContractEmployees.Period >= Employees.Period
	                      |						AND (Employees.Company = &Company)
	                      |			WHERE
	                      |				EmploymentContractEmployees.Ref = &Ref
	                      |			
	                      |			GROUP BY
	                      |				Employees.Company,
	                      |				EmploymentContractEmployees.LineNumber,
	                      |				Employees.Employee,
	                      |				EmploymentContractEmployees.StructuralUnit,
	                      |				EmploymentContractEmployees.Position) AS EmployeesMaximalPeriods
	                      |				INNER JOIN InformationRegister.Employees AS Employees
	                      |				ON EmployeesMaximalPeriods.Employee = Employees.Employee
	                      |					AND EmployeesMaximalPeriods.StructuralUnit = Employees.StructuralUnit
	                      |					AND EmployeesMaximalPeriods.Position = Employees.Position
	                      |					AND EmployeesMaximalPeriods.Period = Employees.Period
	                      |					AND (Employees.Company = &Company)
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
			MessageText = NStr("en='Row No.%Number% of the ""Employees"" tabular section: employment positions are not provided for in the staff list!';ru='Строка №%Номер% табл. части ""Сотрудники"": в штатном расписании не предусмотрены ставки для приема сотрудника!'");
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

#EndRegion

#Region EventsHandlers

// IN handler of document event FillCheckProcessing,
// checked attributes are being copied and reset
// to exclude a standard platform fill check and subsequent check by embedded language tools.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	// Precheck
	RunPreliminaryControl(Cancel);	
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.EmploymentContract.InitializeDocumentData(Ref, AdditionalProperties);
	
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

#EndRegion

#EndIf