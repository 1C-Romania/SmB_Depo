////////////////////////////////////////////////////////////////////////////////
// MODULE VARIABLES

&AtClient
Var InterruptIfNotCompleted;

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
// Procedure initializes the month end according to IB kind.
//
Procedure InitializeMonthEnd()
	
	Completed = False;
	ExecuteMonthEndAtServer();
	
	If Completed Then
		
		ActualizeDateBanEditing();
		
	Else
		
		InterruptIfNotCompleted = False;
		Items["Pages" + String(CurMonth)].CurrentPage = Items["LongOperation" + String(CurMonth)];
		Items.ExecuteMonthEnd.Enabled = False;
		Items.CancelMonthEnd.Enabled = False;
		AttachIdleHandler("CheckExecution", 0.1, True);
		
	EndIf;
	
EndProcedure // InitializeMonthEnd()

&AtClient
// Procedure manages the actualizing of edit prohibition date in appendix
// 
Procedure ActualizeDateBanEditing()

	If UseProhibitionDatesOfDataImport
	AND Not ValueIsFilled(PostponeEditProhibitionDate) Then
		Response = Undefined;

		OpenForm("DataProcessor.MonthEnd.Form.PostponeEditProhibitionDate",,,,,, New NotifyDescription("ActualizeDateBanEditingEnd", ThisObject));
        Return;
	ElsIf UseProhibitionDatesOfDataImport
		    AND PostponeEditProhibitionDate = PredefinedValue("Enum.YesNo.Yes") Then
		ExecuteChangeProhibitionDatePostpone(EndOfMonth(Date(CurYear, CurMonth, 1)));
	EndIf;
	
	ActualizeDateBanEditingFragment();
EndProcedure

&AtClient
Procedure ActualizeDateBanEditingEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If ValueIsFilled(Response) AND Response = DialogReturnCode.Yes Then
        ExecuteChangeProhibitionDatePostpone(EndOfMonth(Date(CurYear, CurMonth, 1)));
    EndIf;
    
    ActualizeDateBanEditingFragment();

EndProcedure

&AtClient
Procedure ActualizeDateBanEditingFragment()
    
    Items.GenerateReport.Enabled = ListOfClosingsMonths[CurMonth - 1].Value;

EndProcedure // ActualizeDateBanEditing()

&AtServerNoContext
// Function reads and returns the form attribute value for the specified month
// 
Function AttributeValueFormsOnValueOfMonth(ThisForm, NameOfFlag, CurMonth)
	
	Return ThisForm[NameOfFlag + String(CurMonth)];
	
EndFunction // AttributeValueFormsOnValueOfMonth()

&AtServer
// Function forms the parameter structure from the form attribute values
//
Function GetStructureParametersAtServer()
	
	ParametersStructure = New Structure;
	
	ParametersStructure.Insert("CurMonth", CurMonth);
	ParametersStructure.Insert("CurYear", CurYear);
	ParametersStructure.Insert("Company", Object.Company);
	
	ExecuteCalculationOfDepreciation = AttributeValueFormsOnValueOfMonth(ThisForm, "DepreciationAccrual", CurMonth);
	ParametersStructure.Insert("ExecuteCalculationOfDepreciation", ExecuteCalculationOfDepreciation);
	
	// Fill the array of operations which are required for month end
	OperationArray = New Array;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "DirectCostCalculation", CurMonth) Then
		
		OperationArray.Add("DirectCostCalculation");
		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "CostAllocation", CurMonth) Then
		
		OperationArray.Add("CostAllocation");
		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "ActualCostCalculation", CurMonth) Then
		
		OperationArray.Add("ActualCostCalculation");
		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "RetailCostCalculation", CurMonth) Then
		
		OperationArray.Add("RetailCostCalculationAccrualAccounting");
		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "ExchangeDifferencesCalculation", CurMonth) Then
		
		OperationArray.Add("ExchangeDifferencesCalculation");
		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "FinancialResultCalculation", CurMonth) Then
		
		OperationArray.Add("FinancialResultCalculation");
		
	EndIf;
	
	ParametersStructure.Insert("OperationArray", OperationArray);
	
	Return ParametersStructure;
	
EndFunction // GetStructureParametersAtServer()

&AtServer
// Procedure executes the month end
//
Procedure ExecuteMonthEndAtServer()
	
	ParametersStructure = GetStructureParametersAtServer();
	
	If CommonUse.FileInfobase() Then
		
		DataProcessors.MonthEnd.ExecuteMonthEnd(ParametersStructure);
		Completed = True;
		
		GetInfoAboutPeriodsClosing();
		
	Else
		
		ExecuteClosingMonthInLongOperation(ParametersStructure);
		
	EndIf;
	
EndProcedure // ExecuteMonthEndAtServer()

&AtServer
// Procedure of the month end cancellation.
// It posts month end documents and updates the form state
//
Procedure CancelMonthEndAtServer()
	
	ParametersStructure = GetStructureParametersAtServer();
	DataProcessors.MonthEnd.CancelMonthEnd(ParametersStructure);
	GetInfoAboutPeriodsClosing();
	
EndProcedure // CancelMonthEndAtServer()

// LongActions

&AtClient
// Procedure checks the state of the month ending
//
Procedure CheckExecution()
	
	CheckResult = CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, InterruptIfNotCompleted);
	
	If CheckResult.JobCompleted Then
		
		GetInfoAboutPeriodsClosing();
		
		Items["Pages" + String(CurMonth)].CurrentPage = Items["Operations" + String(CurMonth)];
		Items.ExecuteMonthEnd.Enabled = True;
		Items.CancelMonthEnd.Enabled = True;
		
		ActualizeDateBanEditing();
		
	ElsIf InterruptIfNotCompleted Then
		
		DetachIdleHandler("CheckExecution");
		
		GetInfoAboutPeriodsClosing();
		
		Items["Pages" + String(CurMonth)].CurrentPage = Items["Operations" + String(CurMonth)];
		Items.ExecuteMonthEnd.Enabled = True;
		Items.CancelMonthEnd.Enabled = True;
		
		ActualizeDateBanEditing();
		
	Else
		
		If BackgroundJobIntervalChecks < 15 Then
			
			BackgroundJobIntervalChecks = BackgroundJobIntervalChecks + 0.7;
			
		EndIf;
		
		AttachIdleHandler("CheckExecution", BackgroundJobIntervalChecks, True);
		
	EndIf;
	
EndProcedure // CheckExecution()

&AtServer
// Procedure executes the month end in long actions (in the background)
//
Procedure ExecuteClosingMonthInLongOperation(ParametersStructureBackgroundJob)
	
	AssignmentResult = LongActions.ExecuteInBackground(
		UUID,
		"DataProcessors.MonthEnd.ExecuteMonthEnd",
		ParametersStructureBackgroundJob,
		NStr("en='Month closing is in progress';ru='Выполняется закрытие месяца'")
	);
	
	Completed = AssignmentResult.JobCompleted;
	
	If Completed Then
		
		GetInfoAboutPeriodsClosing();
		
	Else
		
		BackgroundJobID  = AssignmentResult.JobID;
		BackgroundJobStorageAddress = AssignmentResult.StorageAddress;
		
	EndIf;
	
EndProcedure // PrepareSpreadsheetDocumentInLongActions()

&AtServer
// Procedure checks the tabular document filling end on server
//
Function CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, InterruptIfNotCompleted)
	
	CheckResult = New Structure("JobComplete, Value", False, Undefined);
	
	If LongActions.JobCompleted(BackgroundJobID) Then
		
		Completed							= True;
		CheckResult.JobCompleted	= True;
		CheckResult.Value			= GetFromTempStorage(BackgroundJobStorageAddress);
		
	ElsIf InterruptIfNotCompleted Then
		
		LongActions.CancelJobExecution(BackgroundJobID);
		
	EndIf;
	
	Return CheckResult;
	
EndFunction // CheckExecutionAtServer()

&AtServerNoContext
// Function checks the state of the background job by variable form value
//
Function InProgressBackgroundJob(BackgroundJobID)
	
	If CommonUse.FileInfobase() Then
		
		Return False;
		
	EndIf;
	
	Task = BackgroundJobs.FindByUUID(BackgroundJobID);
	
	Return (Task <> Undefined) AND (Task.State = BackgroundJobState.Active);
	
EndFunction // InProgressBackgroundJob()

&AtClient
// Procedure warns user about action executing impossibility
//
// It is used when closing form, canceling results of closing month
//
Procedure WarnAboutActiveBackgroundJob(Cancel = True)
	
	Cancel = True;
	WarningText = NStr("en='Wait until the work process will be finished (recommended) or terminate it manually.';ru='Дождитесь окончания рабочего процесса (рекомендуется) либо прервите его самостоятельно.'");
	ShowMessageBox(Undefined,WarningText, 10, "it is impossible to close form.");
	
EndProcedure // WarnAboutActiveBackgroundJob()

// End LongActions


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - handler of the OnCreateAtServer event
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Object.Company = Catalogs.Companies.MainCompany;
	
	CurDate = CurrentDate();
	CurYear = Year(CurDate);
	CurMonth = Month(CurDate);
	
	If Constants.AccountingBySubsidiaryCompany.Get() Then
		Object.Company = Constants.SubsidiaryCompany.Get();
		Items.Company.Enabled = False;
	EndIf;
	
	SetLabelsText();
	
	GetInfoAboutPeriodsClosing();
	
	PropertyAccounting = Constants.FunctionalOptionAccountingFixedAssets.Get();
	RetailAccounting = Constants.FunctionalOptionAccountingRetail.Get();
	CurrencyTransactionsAccounting = Constants.FunctionalCurrencyTransactionsAccounting.Get();
	
	For Ct = 1 To 12 Do
		Items.Find("GroupDepreciationAccrual" + Ct).Visible = PropertyAccounting;
		Items.Find("GroupRetailCostCalculation" + Ct).Visible = RetailAccounting;
		Items.Find("GroupExchangeDifferencesCalculation" + Ct).Visible = CurrencyTransactionsAccounting;
	EndDo;
	
	SectionsProperties = ChangeProhibitionDatesServiceReUse.SectionsProperties();
	UseProhibitionDatesOfDataImport = SectionsProperties.UseProhibitionDatesOfDataImport;
	PostponeEditProhibitionDate = Constants.PostponeEditProhibitionDate.Get();
	
	DateProhibition = GetEditProhibitionDate();
	
	If ValueIsFilled(DateProhibition) Then
		EditProhibitionDate = DateProhibition;
	Else
		Items.EditProhibitionDate.Visible = False;
	EndIf;
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure - The AtOpen form event handler
//
Procedure OnOpen(Cancel)
	
	SetMarkCurMonth();
	
EndProcedure // OnOpen()

&AtClient
// Procedure - OnOpen form event handler
//
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If BackgroundJobID <> New UUID
		AND Not Completed
		AND InProgressBackgroundJob(BackgroundJobID) Then // Check for the case if the job has been interrupted
		
		WarnAboutActiveBackgroundJob(Cancel);
		
	EndIf;
	
EndProcedure // BeforeClose()


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtServer
Function GetEditProhibitionDate()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ChangeProhibitionDates.Section,
	|	ChangeProhibitionDates.Object,
	|	ChangeProhibitionDates.User,
	|	ChangeProhibitionDates.ProhibitionDate,
	|	ChangeProhibitionDates.ProhibitionDateDescription,
	|	ChangeProhibitionDates.Comment
	|FROM
	|	InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
	|WHERE
	|	ChangeProhibitionDates.User = &User
	|	AND ChangeProhibitionDates.Object = &Object";
	
	Query.SetParameter("User",  Enums.ProhibitionDatesPurposeKinds.ForAllUsers);
	Query.SetParameter("Object", ChartsOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef());
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Selection.ProhibitionDate;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

&AtServer
Procedure SetLabelsText()
	
	Items.YearAgo.Title = "" + Format((CurYear - 1),"NG=0") + " <<";
	Items.NextYear.Title = ">> " + Format((CurYear + 1),"NG=0");
	Items.NextYear.Enabled = Not (CurYear + 1 > Year(CurrentDate()));
	
EndProcedure

&AtClient
Procedure SetMarkCurMonth()
	
	Items.Months.CurrentPage = Items.Find("M" + CurMonth);
	Items.GenerateReport.Enabled = ListOfClosingsMonths[CurMonth - 1].Value;
	
EndProcedure

&AtServer
Procedure ExecuteChangeProhibitionDatePostpone(Date)
	
	RecordSet = InformationRegisters.ChangeProhibitionDates.CreateRecordSet();
	NewRow = RecordSet.Add();
	NewRow.User = Enums.ProhibitionDatesPurposeKinds.ForAllUsers;
	NewRow.Object = ChartsOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef();
	NewRow.ProhibitionDate = Date;
	NewRow.Comment = "(Default)";
	
	RecordSet.Write(True);
	
	EditProhibitionDate = Date;
	Items.EditProhibitionDate.Visible = True;
	
	PostponeEditProhibitionDate = Constants.PostponeEditProhibitionDate.Get();
	
EndProcedure

&AtServer
Procedure GetInfoAboutPeriodsClosing()
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	// Coloring of tabs and operations.
	TableMonths = New ValueTable;
	
	TableMonths.Columns.Add("Year", New TypeDescription("Number"));
	TableMonths.Columns.Add("Month", New TypeDescription("Number"));
	
	For Ct = 1 To 12 Do
		NewRow = TableMonths.Add();
		NewRow.Year = CurYear;
		NewRow.Month = Ct;
	EndDo;
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	TableMonths.Year AS Year,
	|	TableMonths.Month AS Month
	|INTO TableMonths
	|FROM
	|	&TableMonths AS TableMonths
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN COUNT(FixedAssetsDepreciation.Ref) > 0
	|			THEN 1
	|		ELSE 0
	|	END AS DepreciationAccrual,
	|	YEAR(FixedAssetsDepreciation.Date) AS Year,
	|	MONTH(FixedAssetsDepreciation.Date) AS Month
	|INTO NestedSelectDepreciation
	|FROM
	|	Document.FixedAssetsDepreciation AS FixedAssetsDepreciation
	|WHERE
	|	FixedAssetsDepreciation.Posted = TRUE
	|	AND YEAR(FixedAssetsDepreciation.Date) = &Year
	|	AND CASE
	|			WHEN &FilterByCompanyIsNecessary
	|				THEN FixedAssetsDepreciation.Company = &Company
	|			ELSE TRUE
	|		END
	|
	|GROUP BY
	|	YEAR(FixedAssetsDepreciation.Date),
	|	MONTH(FixedAssetsDepreciation.Date)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(MonthEnd.Ref) AS CountRef,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEnd.DirectCostCalculation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS DirectCostCalculation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEnd.CostAllocation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS CostAllocation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEnd.ActualCostCalculation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS ActualCostCalculation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEnd.FinancialResultCalculation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS FinancialResultCalculation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEnd.ExchangeDifferencesCalculation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS ExchangeDifferencesCalculation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEnd.RetailCostCalculationAccrualAccounting, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS RetailCostCalculationAccrualAccounting,
	|	YEAR(MonthEnd.Date) AS Year,
	|	MONTH(MonthEnd.Date) AS Month
	|INTO NestedSelect
	|FROM
	|	Document.MonthEnd AS MonthEnd
	|WHERE
	|	MonthEnd.Posted = TRUE
	|	AND YEAR(MonthEnd.Date) = &Year
	|	AND CASE
	|			WHEN &FilterByCompanyIsNecessary
	|				THEN MonthEnd.Company = &Company
	|			ELSE TRUE
	|		END
	|
	|GROUP BY
	|	YEAR(MonthEnd.Date),
	|	MONTH(MonthEnd.Date)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableMonths.Month AS Month,
	|	TableMonths.Year AS Year,
	|	CASE
	|		WHEN SUM(InventoryTurnover.AmountTurnover) <> 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS MonthEndIsNecessary,
	|	CASE
	|		WHEN SUM(InventoryTurnover.AmountTurnover) <> 0
	|					AND (ISNULL(NestedSelect.DirectCostCalculation, 0) = 0
	|						OR ISNULL(NestedSelect.CostAllocation, 0) = 0
	|						OR ISNULL(NestedSelect.ActualCostCalculation, 0) = 0
	|						OR ISNULL(NestedSelect.FinancialResultCalculation, 0) = 0)
	|				OR COUNT(RetailAmountAccounting.Recorder) > 0
	|					AND ISNULL(NestedSelect.RetailCostCalculationAccrualAccounting, 0) = 0
	|				OR COUNT(CurrencyRates.Currency) > 0
	|					AND ISNULL(NestedSelect.ExchangeDifferencesCalculation, 0) = 0
	|				OR COUNT(FixedAssets.FixedAsset) > 0
	|					AND ISNULL(NestedSelectDepreciation.DepreciationAccrual, 0) = 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AreNecessaryUnperformedSettlements,
	|	CASE
	|		WHEN COUNT(RetailAmountAccounting.Recorder) > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailCostCalculationIsNecessary,
	|	CASE
	|		WHEN COUNT(CurrencyRates.Currency) > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ExchangeDifferencesCalculationIsNecessary,
	|	CASE
	|		WHEN COUNT(FixedAssets.FixedAsset) > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS DepreciationAccrualIsNecessary,
	|	CASE
	|		WHEN NestedSelect.CountRef > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS MonthEndWasPerformed,
	|	CASE
	|		WHEN NestedSelect.DirectCostCalculation = 0
	|				OR NestedSelect.CostAllocation = 0
	|				OR NestedSelect.ActualCostCalculation = 0
	|				OR NestedSelect.FinancialResultCalculation = 0
	|				OR NestedSelect.ExchangeDifferencesCalculation = 0
	|				OR NestedSelect.RetailCostCalculationAccrualAccounting = 0
	|				OR NestedSelectDepreciation.DepreciationAccrual = 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS IsNonProducedCalculations,
	|	CASE
	|		WHEN NestedSelect.DirectCostCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS DirectCostCalculation,
	|	CASE
	|		WHEN NestedSelect.CostAllocation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS CostAllocation,
	|	CASE
	|		WHEN NestedSelect.ActualCostCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ActualCostCalculation,
	|	CASE
	|		WHEN NestedSelect.FinancialResultCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FinancialResultCalculation,
	|	CASE
	|		WHEN NestedSelect.ExchangeDifferencesCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ExchangeDifferencesCalculation,
	|	CASE
	|		WHEN NestedSelect.RetailCostCalculationAccrualAccounting > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailCostCalculationAccrualAccounting,
	|	CASE
	|		WHEN MonthEndErrors.ErrorDescription > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS HasErrors,
	|	CASE
	|		WHEN NestedSelectDepreciation.DepreciationAccrual > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS DepreciationAccrual
	|FROM
	|	TableMonths AS TableMonths
	|		LEFT JOIN AccumulationRegister.Inventory.Turnovers(, , Month, ) AS InventoryTurnover
	|		ON (TableMonths.Month = MONTH(InventoryTurnover.Period))
	|			AND (TableMonths.Year = YEAR(InventoryTurnover.Period))
	|			AND (InventoryTurnover.Company = &Company)
	|		LEFT JOIN InformationRegister.CurrencyRates AS CurrencyRates
	|		ON (TableMonths.Month = MONTH(CurrencyRates.Period))
	|			AND (TableMonths.Year = YEAR(CurrencyRates.Period))
	|		LEFT JOIN AccumulationRegister.RetailAmountAccounting AS RetailAmountAccounting
	|		ON (TableMonths.Month = MONTH(RetailAmountAccounting.Period))
	|			AND (TableMonths.Year = YEAR(RetailAmountAccounting.Period))
	|			AND (RetailAmountAccounting.Active = TRUE)
	|			AND (RetailAmountAccounting.Company = &Company)
	|		LEFT JOIN AccumulationRegister.FixedAssets.BalanceAndTurnovers(, , Month, , ) AS FixedAssets
	|		ON (TableMonths.Month = MONTH(FixedAssets.Period))
	|			AND (TableMonths.Year = YEAR(FixedAssets.Period))
	|			AND (FixedAssets.Company = &Company)
	|		LEFT JOIN NestedSelectDepreciation AS NestedSelectDepreciation
	|		ON TableMonths.Year = NestedSelectDepreciation.Year
	|			AND TableMonths.Month = NestedSelectDepreciation.Month
	|		LEFT JOIN NestedSelect AS NestedSelect
	|		ON TableMonths.Year = NestedSelect.Year
	|			AND TableMonths.Month = NestedSelect.Month
	|		LEFT JOIN InformationRegister.MonthEndErrors AS MonthEndErrors
	|		ON (TableMonths.Year = YEAR(MonthEndErrors.Period))
	|			AND (TableMonths.Month = MONTH(MonthEndErrors.Period))
	|			AND (CASE
	|				WHEN &FilterByCompanyIsNecessary
	|					THEN MonthEndErrors.Recorder.Company = &Company
	|				ELSE TRUE
	|			END)
	|
	|GROUP BY
	|	TableMonths.Month,
	|	TableMonths.Year,
	|	CASE
	|		WHEN MonthEndErrors.ErrorDescription > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	CASE
	|		WHEN ISNULL(FixedAssets.CostClosingBalance, 0) <> 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	CASE
	|		WHEN NestedSelectDepreciation.DepreciationAccrual > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	NestedSelect.DirectCostCalculation,
	|	NestedSelect.CostAllocation,
	|	NestedSelect.ActualCostCalculation,
	|	NestedSelect.FinancialResultCalculation,
	|	NestedSelect.RetailCostCalculationAccrualAccounting,
	|	NestedSelectDepreciation.DepreciationAccrual,
	|	NestedSelect.ExchangeDifferencesCalculation,
	|	CASE
	|		WHEN NestedSelect.CountRef > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END
	|
	|ORDER BY
	|	Year,
	|	Month";
	
	Query.SetParameter("Company", Counterparty);
	Query.SetParameter("FilterByCompanyIsNecessary", Not Constants.AccountingBySubsidiaryCompany.Get());
	Query.SetParameter("TableMonths", TableMonths);
	Query.SetParameter("Year", CurYear);
	
	CurrentMonth = Month(CurrentDate());
	CurrentYear = Year(CurrentDate());
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		Items["M" + Selection.Month].Enabled = True;
		
		// Bookmarks.
		If Selection.Year = CurrentYear
		   AND Selection.Month = CurrentMonth
		   AND Not Selection.MonthEndWasPerformed
		   AND Not Selection.DepreciationAccrual Then
			Items["M" + Selection.Month].Picture = Items.Gray.Picture;
		ElsIf (Selection.Month > CurrentMonth AND Selection.Year = CurrentYear)
		 OR Selection.Year > CurrentYear Then
			Items["M" + Selection.Month].Picture = Items.Gray.Picture;
			Items["M" + Selection.Month].Enabled = False;
		ElsIf (Selection.MonthEndIsNecessary
			 AND Not Selection.MonthEndWasPerformed)
			OR (Selection.RetailCostCalculationIsNecessary
			 AND Not Selection.RetailCostCalculationAccrualAccounting)
			OR (Selection.ExchangeDifferencesCalculationIsNecessary
			 AND Not Selection.ExchangeDifferencesCalculation)
			OR (Selection.DepreciationAccrualIsNecessary
			 AND Not Selection.DepreciationAccrual) Then
			Items["M" + Selection.Month].Picture = Items.Yellow.Picture;
		ElsIf (Selection.MonthEndIsNecessary
				AND Selection.MonthEndWasPerformed
				AND Selection.AreNecessaryUnperformedSettlements)
				OR Selection.HasErrors Then
			Items["M" + Selection.Month].Picture = Items.Yellow.Picture;
		Else
			Items["M" + Selection.Month].Picture = Items.Green.Picture;
		EndIf;
		
		// Operations.
		ThisForm["CostAllocation" + Selection.Month] = Selection.CostAllocation;
		ThisForm["ExchangeDifferencesCalculation" + Selection.Month] = Selection.ExchangeDifferencesCalculation;
		ThisForm["DirectCostCalculation" + Selection.Month] = Selection.DirectCostCalculation;
		ThisForm["RetailCostCalculation" + Selection.Month] = Selection.RetailCostCalculationAccrualAccounting;
		ThisForm["ActualCostCalculation" + Selection.Month] = Selection.ActualCostCalculation;
		ThisForm["FinancialResultCalculation" + Selection.Month] = Selection.FinancialResultCalculation;
		ThisForm["DepreciationAccrual" + Selection.Month] = Selection.DepreciationAccrual;
		
		If Selection.MonthEndIsNecessary Then
			Items.Find("CostAllocationPicture" + Selection.Month).Picture = ?(ThisForm["CostAllocation" + Selection.Month], Items.Green.Picture, Items.Red.Picture);
			Items.Find("DirectCostCalculationPicture" + Selection.Month).Picture = ?(ThisForm["DirectCostCalculation" + Selection.Month], Items.Green.Picture, Items.Red.Picture);
			Items.Find("ActualCostCalculationPicture" + Selection.Month).Picture = ?(ThisForm["ActualCostCalculation" + Selection.Month], Items.Green.Picture, Items.Red.Picture);
			Items.Find("FinancialResultCalculationPicture" + Selection.Month).Picture = ?(ThisForm["FinancialResultCalculation" + Selection.Month], Items.Green.Picture, Items.Red.Picture);
		ElsIf Selection.Month > CurrentMonth
			  OR Selection.Year > CurrentYear Then
			Items.Find("CostAllocationPicture" + Selection.Month).Picture = Items.Gray.Picture;
			Items.Find("DirectCostCalculationPicture" + Selection.Month).Picture = Items.Gray.Picture;
			Items.Find("ActualCostCalculationPicture" + Selection.Month).Picture = Items.Gray.Picture;
			Items.Find("FinancialResultCalculationPicture" + Selection.Month).Picture = Items.Gray.Picture;
		Else
			Items.Find("CostAllocationPicture" + Selection.Month).Picture = Items.GreenIsNotRequired.Picture;
			Items.Find("DirectCostCalculationPicture" + Selection.Month).Picture = Items.GreenIsNotRequired.Picture;
			Items.Find("ActualCostCalculationPicture" + Selection.Month).Picture = Items.GreenIsNotRequired.Picture;
			Items.Find("FinancialResultCalculationPicture" + Selection.Month).Picture = Items.GreenIsNotRequired.Picture;
		EndIf;
		
		If Selection.ExchangeDifferencesCalculationIsNecessary Then
			Items.Find("ExchangeDifferencesCalculationPicture" + Selection.Month).Picture = ?(ThisForm["ExchangeDifferencesCalculation" + Selection.Month], Items.Green.Picture, Items.Red.Picture);
		Else
			Items.Find("ExchangeDifferencesCalculationPicture" + Selection.Month).Picture = ?(ThisForm["ExchangeDifferencesCalculation" + Selection.Month], Items.Green.Picture, Items.GreenIsNotRequired.Picture);
		EndIf;
		
		If Selection.RetailCostCalculationIsNecessary Then
			Items.Find("RetailCostCalculationPicture" + Selection.Month).Picture = ?(ThisForm["RetailCostCalculation" + Selection.Month], Items.Green.Picture, Items.Red.Picture);
		Else
			Items.Find("RetailCostCalculationPicture" + Selection.Month).Picture = ?(ThisForm["RetailCostCalculation" + Selection.Month], Items.Green.Picture, Items.GreenIsNotRequired.Picture);
		EndIf;
		
		If Selection.DepreciationAccrualIsNecessary Then
			Items.Find("DepreciationAccrualPicture" + Selection.Month).Picture = ?(ThisForm["DepreciationAccrual" + Selection.Month], Items.Green.Picture, Items.Red.Picture);
		Else
			Items.Find("DepreciationAccrualPicture" + Selection.Month).Picture = ?(ThisForm["DepreciationAccrual" + Selection.Month], Items.Green.Picture, Items.GreenIsNotRequired.Picture);
		EndIf;
		
		ThisForm["TextErrorCostAllocation" + Selection.Month] = "";
		ThisForm["TextErrorDirectCostCalculation" + Selection.Month] = "";
		ThisForm["TextErrorActualCostCalculation" + Selection.Month] = "";
		ThisForm["TextErrorFinancialResultCalculation" + Selection.Month] = "";
		ThisForm["TextErrorExchangeDifferencesCalculation" + Selection.Month] = "";
		ThisForm["TextErrorCalculationPrimecostInRetail" + Selection.Month] = "";
		ThisForm["TextErrorDepreciationAccrual" + Selection.Month] = "";
		
	EndDo;
	
	// Errors.
	Query = New Query;
	
	Query.Text = 
	"SELECT
	|	MONTH(MonthEndErrors.Period) AS Month,
	|	MonthEndErrors.OperationKind,
	|	MonthEndErrors.ErrorDescription
	|FROM
	|	InformationRegister.MonthEndErrors AS MonthEndErrors
	|WHERE
	|	MonthEndErrors.Active = TRUE
	|	AND YEAR(MonthEndErrors.Period) = &Year
	|	AND CASE
	|			WHEN &FilterByCompanyIsNecessary
	|				THEN MonthEndErrors.Recorder.Company = &Company
	|			ELSE TRUE
	|		END
	|
	|ORDER BY
	|	Month";
	
	Query.SetParameter("FilterByCompanyIsNecessary", Not Constants.AccountingBySubsidiaryCompany.Get());
	Query.SetParameter("Company", Counterparty);
	Query.SetParameter("Year", CurYear);
	
	SelectionErrors = Query.Execute().Select();
	
	While SelectionErrors.Next() Do
		
		If TrimAll(SelectionErrors.OperationKind) = "CostAllocation" Then
			Items.Find("CostAllocationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			If Not ValueIsFilled(ThisForm["TextErrorCostAllocation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorCostAllocation" + SelectionErrors.Month] = 
					"While cost allocation the errors have occurred. See details in the month end report.";
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "ExchangeDifferencesCalculation" Then
			Items.Find("ExchangeDifferencesCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			If Not ValueIsFilled(ThisForm["TextErrorExchangeDifferencesCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + SelectionErrors.Month] = 
					"While currency difference calculation the errors have occurred. See details in the month end report.";
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "DirectCostCalculation" Then
			Items.Find("DirectCostCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			If Not ValueIsFilled(ThisForm["TextErrorDirectCostCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorDirectCostCalculation" + SelectionErrors.Month] = 
					"While direct cost calculation the Errors have occurred. See details in the month end report.";
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "RetailCostCalculation" Then
			Items.Find("RetailCostCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			If Not ValueIsFilled(ThisForm["TextErrorCalculationPrimecostInRetail" + SelectionErrors.Month]) Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + SelectionErrors.Month] = 
					"While calculation of primecost in retail the Errors have occurred. See details in the month end report.";
				EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "ActualCostCalculation" Then
			Items.Find("ActualCostCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			If Not ValueIsFilled(ThisForm["TextErrorActualCostCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorActualCostCalculation" + SelectionErrors.Month] = 
					"While actual primecost calculation the Errors have occurred. See details in the month end report.";
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "FinancialResultCalculation" Then
			Items.Find("FinancialResultCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			If Not ValueIsFilled(ThisForm["TextErrorFinancialResultCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorFinancialResultCalculation" + SelectionErrors.Month] = 
					"While the financial result calculation the Errors have occurred. For more details see the closing month report";
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "DepreciationAccrual" Then
			Items.Find("DepreciationAccrualPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			If Not ValueIsFilled(ThisForm["TextErrorDepreciationAccrual" + SelectionErrors.Month]) Then
				ThisForm["TextErrorDepreciationAccrual" + SelectionErrors.Month] = 
					"While depreciation charging the Errors have occurred. See details in the month end report.";
			EndIf;
		EndIf;
		
	EndDo;
	
	ListOfClosingsMonths.Clear();
	
	For Ct = 1 To 12 Do
		
		MonthClosed = False; // Sign of month end closing
		
		If Not ValueIsFilled(ThisForm["TextErrorCostAllocation" + Ct]) Then
			If Items.Find("CostAllocationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en='Costing completed successfully!';ru='Расчет себестоимости в рознице (суммовой учет) выполнен успешно!'");
				MonthClosed = True; // month is closed if distribution was completed successfully
			ElsIf Items.Find("CostAllocationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en='Costing is not required.';ru='Расчет себестоимости в рознице (суммовой учет) не требуется.'");
			ElsIf Items.Find("CostAllocationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en=""Costing was n't performed."";ru='Распределение затрат не производилось.'");
			ElsIf Items.Find("CostAllocationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en='Costing is required.';ru='Требуется выполнить распределение затрат.'");
			EndIf;
		Else
			MonthClosed = True; // month is closed if there are any errors
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorDirectCostCalculation" + Ct]) Then
			If Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en='Direct cost calculation completed successfully!';ru='Расчет прямых затрат выполнен успешно!'");
				MonthClosed = True; // month is closed if distribution was completed successfully
			ElsIf Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en='Direct cost calculation is not required.';ru='Расчет прямых затрат не требуется.'");
			ElsIf Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en='Direct cost calculation was not performed.';ru='Расчет прямых затрат не производился.'");
			ElsIf Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en='Direct cost calculation is required.';ru='Требуется выполнить расчет прямых затрат.'");
			EndIf;
		Else
			MonthClosed = True; // month is closed if there are any errors
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorActualCostCalculation" + Ct]) Then
			If Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en='Actual cost calculation completed successfully!';ru='Расчет фактической себестоимости выполнен успешно!'");
				MonthClosed = True; // month is closed if distribution was completed successfully
			ElsIf Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en='Actual cost calculation is not required.';ru='Расчет фактической себестоимости не требуется.'");
			ElsIf Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en='Actual cost calculation was not performed.';ru='Расчет фактической себестоимости не производился.'");
			ElsIf Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en='Actual cost calculation is required.';ru='Требуется выполнить расчет фактической себестоимости.'");
			EndIf;
		Else
			MonthClosed = True; // month is closed if there are any errors
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorFinancialResultCalculation" + Ct]) Then
			If Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en='Financial result calculation completed successfully!';ru='Расчет финансового результата выполнен успешно!'");
				MonthClosed = True; // month is closed if distribution was completed successfully
			ElsIf Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en='Financial result calculation is not required.';ru='Расчет финансового результата не требуется.'");
			ElsIf Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en='Financial result calculation was not performed.';ru='Расчет финансового результата не производился.'");
			ElsIf Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en='Financial result calculation is required.';ru='Требуется выполнить расчет финансового результата.'");
			EndIf;
		Else
			MonthClosed = True; // month is closed if there are any errors
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorExchangeDifferencesCalculation" + Ct]) Then
			If Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en='Costing completed successfully!';ru='Расчет себестоимости в рознице (суммовой учет) выполнен успешно!'");
				MonthClosed = True; // month is closed if distribution was completed successfully
			ElsIf Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en='Costing is not required.';ru='Расчет себестоимости в рознице (суммовой учет) не требуется.'");
			ElsIf Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en='Costing was not performed.';ru='Расчет курсовых разниц не производился.'");
			ElsIf Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en='Costing required.';ru='Требуется выполнить расчет себестоимости в рознице (суммовой учет).'");
			EndIf;
		Else
			MonthClosed = True; // month is closed if there are any errors
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorCalculationPrimecostInRetail" + Ct]) Then
			If Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en='Costing completed successfully!';ru='Расчет себестоимости в рознице (суммовой учет) выполнен успешно!'");
				MonthClosed = True; // month is closed if distribution was completed successfully
			ElsIf Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en='Costing is not required.';ru='Расчет себестоимости в рознице (суммовой учет) не требуется.'");
			ElsIf Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en='Costing was not performed';ru='Расчет себестоимости в рознице (суммовой учет) не производился.'");
			ElsIf Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en='Costing required.';ru='Требуется выполнить расчет себестоимости в рознице (суммовой учет).'");
			EndIf;
		Else
			MonthClosed = True; // month is closed if there are any errors
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorDepreciationAccrual" + Ct]) Then
			If Items.Find("DepreciationAccrualPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorDepreciationAccrual" + Ct] = NStr("en='Depreciation accrual has been successfully completed!';ru='Начисление амортизации выполнено успешно!'");
				MonthClosed = True; // month is closed if distribution was completed successfully
			ElsIf Items.Find("DepreciationAccrualPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorDepreciationAccrual" + Ct] = NStr("en='Depreciation accrual is not required.';ru='Начисление амортизации не требуется.'");
			ElsIf Items.Find("DepreciationAccrualPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorDepreciationAccrual" + Ct] = NStr("en='Depreciation accrual has not been performed.';ru='Начисление амортизации не производилось.'");
			ElsIf Items.Find("DepreciationAccrualPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorDepreciationAccrual" + Ct] = NStr("en='Depreciation accrual is required to be performed.';ru='Требуется выполнить начисление амортизации.'");
			EndIf;
		Else
			MonthClosed = True; // month is closed if there are any errors
		EndIf;
		
		If Items.Find("CostAllocationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture
			AND Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture
			AND Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture
			AND Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture
			AND Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture
			AND Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture
			AND Items.Find("DepreciationAccrualPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
			Items.Find("DecorationPerformClosingNotNeeded" + Ct).Title = NStr("en='Month end is not required because there is no data for calculation.';ru='Закрытие месяца не требуется, т.к. нет данных для расчета.'");
		Else
			Items.Find("DecorationPerformClosingNotNeeded" + Ct).Title = "";
		EndIf;
		
		ListOfClosingsMonths.Add(MonthClosed);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure DepreciationAccrualPictureClick(Item)
	
	ShowMessageBox(Undefined,ThisForm["TextErrorDepreciationAccrual" + CurMonth]);
	
EndProcedure

&AtClient
Procedure DirectCostCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined,ThisForm["TextErrorDirectCostCalculation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure CostAllocationPictureClick(Item)
	
	ShowMessageBox(Undefined,ThisForm["TextErrorCostAllocation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure ActualCostCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined,ThisForm["TextErrorActualCostCalculation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure RetailCostCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined,ThisForm["TextErrorCalculationPrimecostInRetail" + CurMonth]);
	
EndProcedure

&AtClient
Procedure ExchangeDifferencesCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined,ThisForm["TextErrorExchangeDifferencesCalculation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure FinancialResultCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined,ThisForm["TextErrorFinancialResultCalculation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure MonthsOnCurrentPageChange(Item, CurrentPage)
	
	If Not Completed 
		AND ValueIsFilled(BackgroundJobID) Then
		
		Return;
		
	EndIf;
	
	If Items.Months.CurrentPage = Items.M1 Then
		CurMonth = 1;
	ElsIf Items.Months.CurrentPage = Items.M2 Then
		CurMonth = 2;
	ElsIf Items.Months.CurrentPage = Items.M3 Then
		CurMonth = 3;
	ElsIf Items.Months.CurrentPage = Items.M4 Then
		CurMonth = 4;
	ElsIf Items.Months.CurrentPage = Items.M5 Then
		CurMonth = 5;
	ElsIf Items.Months.CurrentPage = Items.M6 Then
		CurMonth = 6;
	ElsIf Items.Months.CurrentPage = Items.M7 Then
		CurMonth = 7;
	ElsIf Items.Months.CurrentPage = Items.M8 Then
		CurMonth = 8;
	ElsIf Items.Months.CurrentPage = Items.M9 Then
		CurMonth = 9;
	ElsIf Items.Months.CurrentPage = Items.M10 Then
		CurMonth = 10;
	ElsIf Items.Months.CurrentPage = Items.M11 Then
		CurMonth = 11;
	ElsIf Items.Months.CurrentPage = Items.M12 Then
		CurMonth = 12;
	EndIf;
	
	Items.GenerateReport.Enabled = ListOfClosingsMonths[CurMonth - 1].Value;
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	If ValueIsFilled(Object.Company) Then
		Items.Months.Enabled = True;
		GetInfoAboutPeriodsClosing();
	Else
		Items.Months.Enabled = False;
	EndIf;
	
	Items.GenerateReport.Enabled = ListOfClosingsMonths[CurMonth - 1].Value;
	
EndProcedure

&AtClient
Procedure EditProhibitionDateClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	OpenForm("InformationRegister.ChangeProhibitionDates.Form.ChangeProhibitionDates", FormParameters);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
// Procedure is the ExecuteMonthEnd command handler
//
Procedure ExecuteMonthEnd(Command)
	
	If EndOfMonth(Date(CurYear, CurMonth, 1)) <= EndOfDay(EditProhibitionDate) Then
		ShowMessageBox(Undefined, NStr("en='It is impossible to close month, because it relates to the prohibited for editing period!';ru='Нельзя закрыть месяц, т.к. он относится к запрещенному для редактирования периоду!'"));
		Return;
	EndIf;
	InitializeMonthEnd();
	
EndProcedure // ExecuteMonthEnd()

&AtClient
Procedure NextYear(Command)
	
	CurYear = CurYear + 1;
	SetLabelsText();
	GetInfoAboutPeriodsClosing();
	Items.GenerateReport.Enabled = ListOfClosingsMonths[CurMonth - 1].Value;
	
EndProcedure

&AtClient
Procedure YearAgo(Command)
	
	CurYear = ?(CurYear = 1, CurYear, CurYear - 1);
	SetLabelsText();
	GetInfoAboutPeriodsClosing();
	Items.GenerateReport.Enabled = ListOfClosingsMonths[CurMonth - 1].Value;
	
EndProcedure

&AtClient
Procedure CancelMonthEnd(Command)
	
	If BackgroundJobID <> New UUID
		AND Not Completed
		AND InProgressBackgroundJob(BackgroundJobID) Then // Check for the case if the job has been interrupted
		
		WarnAboutActiveBackgroundJob();
		
	Else
		
		CancelMonthEndAtServer();
		Items.GenerateReport.Enabled = ListOfClosingsMonths[CurMonth - 1].Value;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateReport(Command)
	
	FormParameters = New Structure(
		"BeginOfPeriod, EndOfPeriod, Company, GeneratingDate",
		BegOfMonth(Date(CurYear, CurMonth, 1)), EndOfMonth(Date(CurYear, CurMonth, 1)), Object.Company, CurrentDate());
	OpenForm("Report.MonthEnd.ObjectForm", FormParameters);
	
EndProcedure

// LongActions

&AtClient
/////////////////////////////////////////////////////////////////////////////
// Procedure-handler of the command "Abort month closing in long Operations"
//
Procedure AbortClosingMonthInLongOperation(Command)
	
	InterruptIfNotCompleted = True;
	CheckExecution();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "EditProhibitionDatesOnClose" Then
		
		ProhibitionDate = GetEditProhibitionDate();
		
		If ValueIsFilled(ProhibitionDate) Then
			EditProhibitionDate = ProhibitionDate;
		Else
			Items.EditProhibitionDate.Visible = False;
		EndIf;
		
	EndIf;
	
EndProcedure

// End LongActions

&AtClient
Procedure ExecutePreliminaryAnalysis(Command)
	
	FormParameters = New Structure(
		"BeginOfPeriod, EndOfPeriod, Company, MonthEndContext",
		BegOfMonth(Date(CurYear, CurMonth, 1)), EndOfMonth(Date(CurYear, CurMonth, 1)), Object.Company, True);
		
	OpenForm("DataProcessor.AccountingCorrectnessControl.Form.Form", FormParameters);
	
EndProcedure