#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Controls conflicts.
//
Procedure RunPreliminaryControl(Cancel) 
	
	Query = New Query(
	"SELECT
	|	DismissalStaff.LineNumber,
	|	DismissalStaff.Employee,
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
	If Not ResultsArray[1].IsEmpty() Then
		QueryResultSelection = ResultsArray[1].Select();
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
	
	// Row duplicates.
	If Not ResultsArray[2].IsEmpty() Then
		QueryResultSelection = ResultsArray[2].Select();
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
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEmployees.LineNumber AS LineNumber,
	|	TableEmployees.Employee,
	|	MIN(Employees.Period) AS Period
	|FROM
	|	TableEmployees AS TableEmployees
	|		INNER JOIN InformationRegister.Employees AS Employees
	|		ON (Employees.Employee = TableEmployees.Employee)
	|			AND (Employees.Period > TableEmployees.Period)
	|			AND (Employees.Recorder <> &Ref)
	|
	|GROUP BY
	|	TableEmployees.Employee,
	|	TableEmployees.LineNumber
	|
	|ORDER BY
	|	LineNumber");
	
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	Result = Query.ExecuteBatch();
	
	// Employee isn't assepted in company on the dismissal date.
	QueryResultSelection = Result[0].Select();
	While QueryResultSelection.Next() Do
		If Not ValueIsFilled(QueryResultSelection.StructuralUnit) Then
		    MessageText = NStr("en='In row No.%Number% of tabular section ""Employees"", the employee %Employee% is not hired to %Company% company.';ru='В строке №%Номер% табл. части ""Сотрудники"" сотрудник %Сотрудник% не принят на работу в организацию %Организация%.'");
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
	
	// There are register records after dismissal of the employee.
	QueryResultSelection = Result[1].Select();
	While QueryResultSelection.Next() Do
		MessageText = NStr("en='In row No.%Number% of tabular section ""Employees"" there are personnel register records for employee %Employee% within %Period% after dismissal date.';ru='В строке №%Номер% табл. части ""Сотрудники"" по сотруднику %Сотрудник% есть кадровые движения %Период% после даты увольнения.'");
		MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
		MessageText = StrReplace(MessageText, "%Employee%", QueryResultSelection.Employee); 
		MessageText = StrReplace(MessageText, "%Period%", Format(QueryResultSelection.Period, "DF=dd.MM.yy"));
		SmallBusinessServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			"Employees",
			QueryResultSelection.LineNumber,
			"Employee",
			Cancel);
	EndDo; 
			
EndProcedure

#EndRegion

#Region EventsHandlers

// IN handler of document event
// FillCheckProcessing, checked attributes are being copied and reset
// a exclude a standard platform fill check and subsequent check by embedded language tools.
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
	Documents.Dismissal.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectEmployees(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccrualsAndDeductionsPlan(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control
	RunControl(AdditionalProperties, Cancel);
	
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