///////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Creates a query to get the table of scheduled payments balances.
//
Function QueryByPlannedPaymentsBalance()

	QueryText = 
	"SELECT ALLOWED
	|	CASE
	|		WHEN PaymentCalendar.SecondPeriod < &WorkingDate
	|			THEN 1
	|		ELSE 2
	|	END AS PaymentOrder,
	|	CASE
	|		WHEN PaymentCalendar.SecondPeriod < &WorkingDate
	|			THEN &OverduePayments
	|		ELSE &ScheduledPayments
	|	END AS PaymentStatus,
	|	PaymentCalendar.DayPeriod AS Day,
	|	PaymentCalendar.SecondPeriod AS PaymentDate,
	|	PaymentCalendar.Recorder.Date AS DocumentDate,
	|	PaymentCalendar.Recorder AS Document,
	|	PaymentCalendar.Currency,
	|	PaymentCalendar.Currency AS PaymentCurrency,
	|	PaymentCalendar.BankAccountPettyCash,
	|	PaymentCalendar.CashAssetsType,
	|	CASE
	|		WHEN PaymentCalendar.InvoiceForPayment = UNDEFINED
	|				OR PaymentCalendar.InvoiceForPayment = VALUE(Document.InvoiceForPayment.EmptyRef)
	|				OR PaymentCalendar.InvoiceForPayment = VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
	|				OR PaymentCalendar.InvoiceForPayment = VALUE(Document.CustomerOrder.EmptyRef)
	|				OR PaymentCalendar.InvoiceForPayment = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN PaymentCalendar.Item.Presentation
	|		ELSE PaymentCalendar.InvoiceForPayment.Presentation
	|	END AS Payment,
	|	PaymentCalendar.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	FALSE AS RowCurrentBalance,
	|	ISNULL(PaymentCalendar.Recorder.Counterparty.Presentation, """") AS CounterpartyPresentation,
	|	PaymentCalendar.Item.Presentation AS ItemPresentation,
	|	SubString(PaymentCalendar.Recorder.Comment, 1, 100) AS Comment,
	|	&TextSummary AS TextSummary,
	|	SubString("""", 1, 200) AS PaymentData,
	|	MAX(PaymentCalendar.AmountTurnover) AS AmountTurnover,
	|	SUM(ISNULL(PaymentCalendarRegistrations.AmountTurnover, 0)) AS TotalTurnOverSumm,
	|	MAX(ISNULL(PaymentCalendarPay.PaymentAmountTurnover, 0)) AS PaymentAmountTurnover,
	|	CASE
	|		WHEN MAX(PaymentCalendar.AmountTurnover) > 0
	|			THEN CASE
	|					WHEN SUM(ISNULL(PaymentCalendarRegistrations.AmountTurnover, 0)) - MAX(ISNULL(PaymentCalendarPay.PaymentAmountTurnover, 0)) >= 0
	|						THEN MAX(PaymentCalendar.AmountTurnover)
	|					WHEN SUM(ISNULL(PaymentCalendarRegistrations.AmountTurnover, 0)) + MAX(PaymentCalendar.AmountTurnover) - MAX(ISNULL(PaymentCalendarPay.PaymentAmountTurnover, 0)) < 0
	|						THEN 0
	|					ELSE SUM(ISNULL(PaymentCalendarRegistrations.AmountTurnover, 0)) + MAX(PaymentCalendar.AmountTurnover) - MAX(ISNULL(PaymentCalendarPay.PaymentAmountTurnover, 0))
	|				END
	|		ELSE CASE
	|				WHEN SUM(ISNULL(PaymentCalendarRegistrations.AmountTurnover, 0)) - MAX(ISNULL(PaymentCalendarPay.PaymentAmountTurnover, 0)) <= 0
	|					THEN MAX(PaymentCalendar.AmountTurnover)
	|				WHEN SUM(ISNULL(PaymentCalendarRegistrations.AmountTurnover, 0)) + MAX(PaymentCalendar.AmountTurnover) - MAX(ISNULL(PaymentCalendarPay.PaymentAmountTurnover, 0)) > 0
	|					THEN 0
	|				ELSE SUM(ISNULL(PaymentCalendarRegistrations.AmountTurnover, 0)) + MAX(PaymentCalendar.AmountTurnover) - MAX(ISNULL(PaymentCalendarPay.PaymentAmountTurnover, 0))
	|			END
	|	END AS Amount,
	|	MAX(CASE
	|			WHEN PaymentCalendar.Recorder REFS Document.CashTransferPlan
	|					AND PaymentCalendar.AmountTurnover < 0
	|				THEN -PaymentCalendar.AmountTurnover
	|			ELSE PaymentCalendar.AmountTurnover
	|		END) AS PaymentAmount,
	|	0 AS AmountReceipt,
	|	0 AS AmountExpense,
	|	0 AS OpeningBalanceByAccount,
	|	0 AS ClosingBalanceOfAccount,
	|	0 AS InitialCurrencyBallance,
	|	0 AS ClosingBalanceByCurrency,
	|	0 AS OpeningBalanceByCashAssetsType,
	|	0 AS ClosingBalanceByCashAssetsType
	|FROM
	|	AccumulationRegister.PaymentCalendar.Turnovers(&StartDate, &EndDate, Auto, Company = &Company) AS PaymentCalendar
	|		LEFT JOIN AccumulationRegister.PaymentCalendar.Turnovers(
	|				&StartDate,
	|				&EndDate,
	|				Auto,
	|				Company = &Company
	|					AND PaymentConfirmationStatus = VALUE(Enum.PaymentApprovalStatuses.Approved)) AS PaymentCalendarRegistrations
	|		ON (PaymentCalendar.SecondPeriod > PaymentCalendarRegistrations.SecondPeriod
	|				OR PaymentCalendar.SecondPeriod = PaymentCalendarRegistrations.SecondPeriod
	|					AND PaymentCalendar.Recorder > PaymentCalendarRegistrations.Recorder)
	|			AND (CASE
	|				WHEN (PaymentCalendarRegistrations.InvoiceForPayment = UNDEFINED
	|						OR PaymentCalendarRegistrations.InvoiceForPayment = VALUE(Document.InvoiceForPayment.EmptyRef)
	|						OR PaymentCalendarRegistrations.InvoiceForPayment = VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
	|						OR PaymentCalendarRegistrations.InvoiceForPayment = VALUE(Document.CustomerOrder.EmptyRef)
	|						OR PaymentCalendarRegistrations.InvoiceForPayment = VALUE(Document.PurchaseOrder.EmptyRef))
	|						AND (PaymentCalendar.InvoiceForPayment = UNDEFINED
	|							OR PaymentCalendar.InvoiceForPayment = VALUE(Document.InvoiceForPayment.EmptyRef)
	|							OR PaymentCalendar.InvoiceForPayment = VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
	|							OR PaymentCalendar.InvoiceForPayment = VALUE(Document.CustomerOrder.EmptyRef)
	|							OR PaymentCalendar.InvoiceForPayment = VALUE(Document.PurchaseOrder.EmptyRef))
	|						AND PaymentCalendarRegistrations.Item <> VALUE(Catalog.CashFlowItems.EmptyRef)
	|						AND PaymentCalendarRegistrations.Item = PaymentCalendar.Item
	|					THEN TRUE
	|				WHEN PaymentCalendarRegistrations.InvoiceForPayment <> UNDEFINED
	|						AND PaymentCalendarRegistrations.InvoiceForPayment <> VALUE(Document.InvoiceForPayment.EmptyRef)
	|						AND PaymentCalendarRegistrations.InvoiceForPayment <> VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
	|						AND PaymentCalendarRegistrations.InvoiceForPayment <> VALUE(Document.CustomerOrder.EmptyRef)
	|						AND PaymentCalendarRegistrations.InvoiceForPayment <> VALUE(Document.PurchaseOrder.EmptyRef)
	|						AND PaymentCalendar.InvoiceForPayment = PaymentCalendarRegistrations.InvoiceForPayment
	|					THEN TRUE
	|				ELSE FALSE
	|			END)
	|		LEFT JOIN AccumulationRegister.PaymentCalendar.Turnovers(
	|				&StartDate,
	|				&EndDate,
	|				Auto,
	|				Company = &Company
	|					AND PaymentConfirmationStatus = VALUE(Enum.PaymentApprovalStatuses.Approved)) AS PaymentCalendarPay
	|		ON (PaymentCalendar.PaymentConfirmationStatus = VALUE(Enum.PaymentApprovalStatuses.Approved))
	|			AND (CASE
	|				WHEN (PaymentCalendarPay.InvoiceForPayment = UNDEFINED
	|						OR PaymentCalendarPay.InvoiceForPayment = VALUE(Document.InvoiceForPayment.EmptyRef)
	|						OR PaymentCalendarPay.InvoiceForPayment = VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
	|						OR PaymentCalendarPay.InvoiceForPayment = VALUE(Document.CustomerOrder.EmptyRef)
	|						OR PaymentCalendarPay.InvoiceForPayment = VALUE(Document.PurchaseOrder.EmptyRef))
	|						AND (PaymentCalendar.InvoiceForPayment = UNDEFINED
	|							OR PaymentCalendar.InvoiceForPayment = VALUE(Document.InvoiceForPayment.EmptyRef)
	|							OR PaymentCalendar.InvoiceForPayment = VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
	|							OR PaymentCalendar.InvoiceForPayment = VALUE(Document.CustomerOrder.EmptyRef)
	|							OR PaymentCalendar.InvoiceForPayment = VALUE(Document.PurchaseOrder.EmptyRef))
	|						AND PaymentCalendarPay.Item <> VALUE(Catalog.CashFlowItems.EmptyRef)
	|						AND PaymentCalendarPay.Item = PaymentCalendar.Item
	|					THEN TRUE
	|				WHEN PaymentCalendarPay.InvoiceForPayment <> UNDEFINED
	|						AND PaymentCalendarPay.InvoiceForPayment <> VALUE(Document.InvoiceForPayment.EmptyRef)
	|						AND PaymentCalendarPay.InvoiceForPayment <> VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
	|						AND PaymentCalendarPay.InvoiceForPayment <> VALUE(Document.CustomerOrder.EmptyRef)
	|						AND PaymentCalendarPay.InvoiceForPayment <> VALUE(Document.PurchaseOrder.EmptyRef)
	|						AND PaymentCalendar.InvoiceForPayment = PaymentCalendarPay.InvoiceForPayment
	|					THEN TRUE
	|				ELSE FALSE
	|			END)
	|
	|GROUP BY
	|	CASE
	|		WHEN PaymentCalendar.SecondPeriod < &WorkingDate
	|			THEN 1
	|		ELSE 2
	|	END,
	|	PaymentCalendar.DayPeriod,
	|	PaymentCalendar.SecondPeriod,
	|	PaymentCalendar.Recorder,
	|	PaymentCalendar.Currency,
	|	PaymentCalendar.BankAccountPettyCash,
	|	PaymentCalendar.CashAssetsType,
	|	CASE
	|		WHEN PaymentCalendar.InvoiceForPayment = UNDEFINED
	|				OR PaymentCalendar.InvoiceForPayment = VALUE(Document.InvoiceForPayment.EmptyRef)
	|				OR PaymentCalendar.InvoiceForPayment = VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
	|				OR PaymentCalendar.InvoiceForPayment = VALUE(Document.CustomerOrder.EmptyRef)
	|				OR PaymentCalendar.InvoiceForPayment = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN PaymentCalendar.Item.Presentation
	|		ELSE PaymentCalendar.InvoiceForPayment.Presentation
	|	END,
	|	PaymentCalendar.Recorder.Date,
	|	SubString(PaymentCalendar.Recorder.Comment, 1, 100),
	|	PaymentCalendar.Item.Presentation,
	|	CASE
	|		WHEN PaymentCalendar.SecondPeriod < &WorkingDate
	|			THEN &OverduePayments
	|		ELSE &ScheduledPayments
	|	END,
	|	PaymentCalendar.PaymentConfirmationStatus,
	|	ISNULL(PaymentCalendar.Recorder.Counterparty.Presentation, """"),
	|	PaymentCalendar.Currency
	|
	|ORDER BY
	|	PaymentOrder,
	|	PaymentCalendar.DayPeriod,
	|	PaymentCalendar.SecondPeriod,
	|	PaymentCalendar.Recorder,
	|	PaymentCalendar.BankAccountPettyCash";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("StartDate", Report.DelayedPaymentsPeriod.StartDate);
	Query.SetParameter("EndDate", EndOfDay(Report.FuturePaymentsPeriod.EndDate));
	Query.SetParameter("WorkingDate", Report.WorkingDate);
	Query.SetParameter("OverduePayments", NStr("en='Total Overdue payments';ru='Итого просроченные платежи'"));
	Query.SetParameter("ScheduledPayments", NStr("en='Total scheduled payments';ru='Итого запланированные платежи'"));
	Query.SetParameter("TextSummary", NStr("en='Total payments';ru='Всего платежи'"));
	
	Return Query;

EndFunction // QueryByPlannedPaymentBalance()

&AtServer
// Creates a query to get actual cash balance.
//
Function QueryByCashAssetsBalance()

	QueryText = 
	"SELECT ALLOWED
	|	0 AS PaymentOrder,
	|	&PaymentStatus AS PaymentStatus,
	|	&TextSummary AS TextSummary,
	|	CashAssets.CashAssetsType,
	|	&WorkingDate AS Day,
	|	&WorkingDate AS PaymentDate,
	|	&Payment AS Payment,
	|	TRUE AS RowCurrentBalance,
	|	CashAssets.BankAccountPettyCash,
	|	CashAssets.Currency,
	|	CashAssets.AmountCurBalance AS ClosingBalanceOfAccount,
	|	CashAssets.AmountCurBalance AS ClosingBalanceByCurrency,
	|	CashAssets.AmountCurBalance AS ClosingBalanceByCashAssetsType,
	|	0 AS Amount
	|FROM
	|	AccumulationRegister.CashAssets.Balance(, Company = &Company) AS CashAssets
	|
	|ORDER BY
	|	CashAssets.BankAccountPettyCash";
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("WorkingDate", Report.WorkingDate);
	Query.SetParameter("PaymentStatus", NStr("en='Available balance';ru='Доступный остаток'"));
	Query.SetParameter("TextSummary", NStr("en='Total payments';ru='Всего платежи'"));
	Query.SetParameter("Payment", NStr("en='Current balance';ru='Текущий остаток'"));
	
	Return Query;

EndFunction // QueryByPlannedPaymentBalance()

&AtServer
// Creates a table of scheduled payments.
//
Function GetPlannedPaymentsTable()

	Query = QueryByPlannedPaymentsBalance();
	QueryResult = Query.Execute();
	TablePayments = QueryResult.Unload();
	
	BalanceByAccountMap = New Map;
	CurrencyBalanceMap = New Map;
	AccordanceBalanceByCashAssetsType = New Map;
	
	BalanceQuery = QueryByCashAssetsBalance();
	BalancesRequestResult = BalanceQuery.Execute();
	Selection = BalancesRequestResult.Select();
	
	While Selection.Next() Do
		
		NewRow = TablePayments.Insert(0);
		FillPropertyValues(NewRow, Selection);
		
		CorrespondenceKey = String(Selection.BankAccountPettyCash) + String(Selection.Currency);
		BalanceByAccountMap.Insert(CorrespondenceKey, Selection.ClosingBalanceOfAccount);
		
		CorrespondenceKey = String(Selection.Currency);
		BalanceByCurrency = CurrencyBalanceMap[CorrespondenceKey];
		BalanceByCurrency = ?(BalanceByCurrency = Undefined, 0, BalanceByCurrency);
		CurrencyBalanceMap.Insert(CorrespondenceKey, BalanceByCurrency + Selection.ClosingBalanceByCurrency);
		
		CorrespondenceKey = String(Selection.CashAssetsType) + String(Selection.Currency);
		BalanceByCashAssetsType = AccordanceBalanceByCashAssetsType[CorrespondenceKey];
		BalanceByCashAssetsType = ?(BalanceByCashAssetsType = Undefined, 0, BalanceByCashAssetsType);
		AccordanceBalanceByCashAssetsType.Insert(CorrespondenceKey, BalanceByCashAssetsType + Selection.ClosingBalanceByCashAssetsType);
		
	EndDo;
	
	For Each TableRow IN TablePayments Do
		
		If TableRow.RowCurrentBalance Then
			
			CorrespondenceKey = String(TableRow.CashAssetsType) + String(TableRow.Currency);
			BalanceByCashAssetsType = AccordanceBalanceByCashAssetsType[CorrespondenceKey];
			TableRow.ClosingBalanceByCashAssetsType = BalanceByCashAssetsType;
			
			CorrespondenceKey = String(TableRow.Currency);
			BalanceByCurrency = CurrencyBalanceMap[CorrespondenceKey];
			TableRow.ClosingBalanceByCurrency = BalanceByCurrency;
			
			Continue;
		EndIf;
		
		PaymentDataRow = TableRow.CounterpartyPresentation
			+ ?(IsBlankString(TableRow.ItemPresentation), "", ", " + TableRow.ItemPresentation)
			+ ?(IsBlankString(TableRow.Comment), "", ", " + TableRow.Comment);
		
		If Left(PaymentDataRow, 1) = "," Then
			TableRow.PaymentData = TrimAll(Mid(PaymentDataRow, 2));
		Else
			TableRow.PaymentData = TrimAll(PaymentDataRow);
		EndIf;
		
		// If payment is completely paid it should not be displayed in report.
		If TableRow.Amount = 0
			AND Not TableRow.RowCurrentBalance Then
			TableRow.Document = NULL;
		EndIf;
		
		If TableRow.Amount < 0 Then
			TableRow.AmountExpense = -TableRow.Amount;
		Else
			TableRow.AmountReceipt = TableRow.Amount;
		EndIf;
		
		// Calculate current balance by account.
		CorrespondenceKey = String(TableRow.BankAccountPettyCash) + String(TableRow.Currency);
		BalanceByAccount = BalanceByAccountMap[CorrespondenceKey];
		BalanceByAccount = ?(BalanceByAccount = Undefined, 0, BalanceByAccount);
		BalanceByAccountMap.Insert(CorrespondenceKey, BalanceByAccount + TableRow.Amount);
		TableRow.OpeningBalanceByAccount = BalanceByAccount;
		TableRow.ClosingBalanceOfAccount = BalanceByAccount + TableRow.Amount;
		
		// Calculate current balance by currency.
		CorrespondenceKey = String(TableRow.Currency);
		BalanceByCurrency = CurrencyBalanceMap[CorrespondenceKey];
		BalanceByCurrency = ?(BalanceByCurrency = Undefined, 0, BalanceByCurrency);
		CurrencyBalanceMap.Insert(CorrespondenceKey, BalanceByCurrency + TableRow.Amount);
		TableRow.InitialCurrencyBallance = BalanceByCurrency;
		TableRow.ClosingBalanceByCurrency = BalanceByCurrency + TableRow.Amount;
		
		// Calculate current balance by cash type.
		CorrespondenceKey = String(TableRow.CashAssetsType) + String(TableRow.Currency);
		BalanceByCashAssetsType = AccordanceBalanceByCashAssetsType[CorrespondenceKey];
		BalanceByCashAssetsType = ?(BalanceByCashAssetsType = Undefined, 0, BalanceByCashAssetsType);
		AccordanceBalanceByCashAssetsType.Insert(CorrespondenceKey, BalanceByCashAssetsType + TableRow.Amount);
		TableRow.OpeningBalanceByCashAssetsType = BalanceByCashAssetsType;
		TableRow.ClosingBalanceByCashAssetsType = BalanceByCashAssetsType + TableRow.Amount;
		
	EndDo;
	
	Return TablePayments;
	
EndFunction // GetPlannedPaymentTable()

&AtServer
// Procedure generates the payment schedule.
//
Procedure OutputReport(DoNotShowMessages = False)
	
	ReportObject = FormAttributeToValue("Report");
	Result.Clear();
	
	Cancel = Not ReportObject.CheckFilling();
	
	If DoNotShowMessages Then
		GetUserMessages(True);
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	// Set parameter values of data composition.
	ParemeterCompany = Report.SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("Company"));
	If ParemeterCompany <> Undefined Then
		ParemeterCompany.Value = SmallBusinessServer.GetCompany(Company);
		ParemeterCompany.Use = True;
	EndIf;
	
	DeginingDataParameter = Report.SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("StartDate"));
	If DeginingDataParameter <> Undefined Then
		DeginingDataParameter.Value = Report.DelayedPaymentsPeriod.StartDate;
		DeginingDataParameter.Use = True;
	EndIf;
	
	EndDataParameter = Report.SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("EndDate"));
	If EndDataParameter <> Undefined Then
		EndDataParameter.Value = EndOfDay(Report.FuturePaymentsPeriod.EndDate);
		EndDataParameter.Use = True;
	EndIf;
	
	WorkingDataParameter = Report.SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("WorkingDate"));
	If WorkingDataParameter <> Undefined Then
		WorkingDataParameter.Value = Report.WorkingDate;
		WorkingDataParameter.Use = True;
	EndIf;
	
	For Each SettingItem IN Report.SettingsComposer.UserSettings.Items Do
	
		If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") Then
			
			If SettingItem.Parameter = New DataCompositionParameter("BeginDatePayment") Then
				SettingItem.Value = Report.DelayedPaymentsPeriod.StartDate;
			ElsIf SettingItem.Parameter = New DataCompositionParameter("EndDatePayment") Then
				SettingItem.Value = EndOfDay(Report.FuturePaymentsPeriod.EndDate);
			ElsIf SettingItem.Parameter = New DataCompositionParameter("CompanyPayment") Then
				SettingItem.Value = Company;
			EndIf;
		
		EndIf;
	
	EndDo;
	
	DataCompositionSettings = Report.SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(DataCompositionSettings);
	
	SmallBusinessReports.SetReportAppearanceTemplate(DataCompositionSettings);
	SmallBusinessReports.OutputReportTitle(ReportParameters, Result);
	
	// Prepare and display the report.
	TemplateComposer = New DataCompositionTemplateComposer;
	Schema = ReportObject.DataCompositionSchema;
	
	CompositionDetailsData = New DataCompositionDetailsData;
	
	CompositionTemplate = TemplateComposer.Execute(
		Schema, 
		DataCompositionSettings,
		CompositionDetailsData
	);
	
	TablePayments = GetPlannedPaymentsTable();
	ExternalDataSets = New Structure("TablePayments", TablePayments);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(
		CompositionTemplate,
		ExternalDataSets,
		CompositionDetailsData
	);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(Result);
	OutputProcessor.BeginOutput();
	OutputProcessor.Output(CompositionProcessor, True);
	OutputProcessor.EndOutput();
	
	DetailsData = PutToTempStorage(CompositionDetailsData, New UUID);
	CompositionSchema   = PutToTempStorage(Schema, New UUID);
	
EndProcedure // OutputReport()

&AtServer
Function PrepareReportParameters(ReportSettings)
	
	BeginOfPeriod = Report.DelayedPaymentsPeriod.StartDate;
	EndOfPeriod = Report.FuturePaymentsPeriod.EndDate;
	TitleOutput = False;
	Title = "Payment calendar";
	
	ParameterOutputTitle = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If ParameterOutputTitle <> Undefined
		AND ParameterOutputTitle.Use Then
		
		TitleOutput = ParameterOutputTitle.Value;
	EndIf;
	
	OutputParameter = ReportSettings.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If OutputParameter <> Undefined
		AND OutputParameter.Use Then
		Title = OutputParameter.Value;
	EndIf;
	
	ReportParameters = New Structure;
	ReportParameters.Insert("BeginOfPeriod"            , BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod"             , EndOfPeriod);
	ReportParameters.Insert("TitleOutput"        , TitleOutput);
	ReportParameters.Insert("Title"                , Title);
	ReportParameters.Insert("ReportId"      , "PaymentCalendar");
	ReportParameters.Insert("ReportSettings", ReportSettings);
		
	Return ReportParameters;
	
EndFunction

&AtServer
// Procedure fills company in report form.
//
Procedure FillCompany()

	RunCompanyAccounting = Constants.AccountingBySubsidiaryCompany.Get();
	
	If RunCompanyAccounting Then
		Company = Constants.SubsidiaryCompany.Get();
	Else
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Company = SettingValue;
		Else
			Company = Catalogs.Companies.MainCompany;
		EndIf;
	EndIf;
	
	Items.Company.Enabled = Not RunCompanyAccounting;

EndProcedure // FillCompany()

///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	FactPaymentsInput = True;
	
	FillCompany();
	
	Report.DelayedPaymentsPeriod.Variant = StandardPeriodVariant.Last7Days;
	Report.FuturePaymentsPeriod.Variant = StandardPeriodVariant.Next7Days;
	Report.WorkingDate = CurrentDate();
	
EndProcedure // OnCreateAtServer()

&AtServer
// Procedure - event handler "OnSaveVariantAtServer" of the form.
//
Procedure OnSaveVariantAtServer(Settings)
	
	CurrentVariantDescription = CurrentVariantPresentation;
	
EndProcedure // OnSaveVariantAtServer()

&AtServer
// Procedure - event handler "OnVariantImportAtServer" of the form.
//
Procedure OnLoadVariantAtServer(Settings)

	CurrentVariantDescription = CurrentVariantPresentation;

EndProcedure // OnLoadVariantAtServer()

&AtServer
Procedure OnLoadUserSettingsAtServer(Settings)
	
	OutputReport();
	
EndProcedure // OnLoadUserSettingsAtServer()

&AtClient
// Procedure - form event handler "NotificationProcessing".
Procedure NotificationProcessing(EventName, Parameter, Source)

	OutputReport(True);

EndProcedure // NotificationProcessing()

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, Settings);
EndProcedure

///////////////////////////////////////////////////////////////////////////////

&AtClient
// Procedure is executed when clicking the "Generate" button.
//
Procedure MakeExecute()
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("ReportCreation_PaymentCalendar");
	// StandardSubsystems.PerformanceEstimation
	
	OutputReport();
	
EndProcedure // MakeExecute()

///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM FIELD EVENT HANDLERS

&AtClient
// Procedure - event handler "OnChange" of field "Company".
//
Procedure CompanyOnChange(Item)

	OutputReport();
	
EndProcedure // CompanyOnChange()

///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF TABLE FIELD

&AtServer
// Gets details field value.
//
Function GetDetailsFieldValue(Details)
	
	SettingsSource = New DataCompositionAvailableSettingsSource(CompositionSchema);
	DetailProcessing = New DataCompositionDetailsProcess(DetailsData, SettingsSource);
		
	DetailsDataFromStorage = GetFromTempStorage(DetailsData);
	
	// Create and initialize the abbreviation handler.
	DetailsStructure = New Structure;
	
	ItemDetails = DetailsDataFromStorage.Items.Get(Details);
	
	If TypeOf(ItemDetails) = Type("DataCompositionFieldDetailsItem") Then
		For Each FieldDetailsValue IN ItemDetails.GetFields() Do
			If FieldDetailsValue.Field = "Document"
			  AND ValueIsFilled(FieldDetailsValue.Value) Then
				ReturnStructure = New Structure;
				ReturnStructure.Insert("NameOfFormDocument", "Document." + FieldDetailsValue.Value.Metadata().Name + ".ObjectForm");
				ReturnStructure.Insert("ReferenceDocument", FieldDetailsValue.Value);
				Return ReturnStructure;
			EndIf;
		EndDo;
	EndIf;
	
	Return Undefined;

EndFunction // GetDetailsFieldValue()

&AtClient
// Procedure - event handler "EncryptionDataProcessor" of field "Result".
//
Procedure ResultDetailProcessing(Item, Details, StandardProcessing)

	If TypeOf(Details) <> Type("DataCompositionDetailsID") Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	FieldDetailsValue = GetDetailsFieldValue(Details);
	
	If ValueIsFilled(FieldDetailsValue) Then
		ParameterStructure = New Structure("Key", FieldDetailsValue.ReferenceDocument);
		OpenForm(FieldDetailsValue.NameOfFormDocument, ParameterStructure);
	EndIf;

EndProcedure // ResultEncryptionProcessor()

&AtClient
// Procedure - event handler "OnChange" of field "DelayedPaymentsPeriod".
//
Procedure DelayedPaymentsPeriodOnChange(Item)
	
	OutputReport();

EndProcedure // DelayedPaymentsPeriodOnChange()

&AtClient
// Procedure - event handler "OnChange" of field "FuturePaymentPeriod".
//
Procedure FuturePaymentsPeriodOnChange(Item)
	
	OutputReport();
	
EndProcedure // FuturePaymentsPeriodOnChange()



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
