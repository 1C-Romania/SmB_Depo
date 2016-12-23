
#Region FormEventsHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	GetSettings();
	RefreshData();
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure - event handler OnClose form.
//
Procedure OnClose()
	
	SaveSettings();
	
EndProcedure // OnClose()

#EndRegion

#Region FormAttributesEventsHandlers

&AtClient
// Procedure - event handler OnChange of the Company input field.
//
Procedure CompanyOnChange(Item)

    RefreshData();
	
EndProcedure // CompanyOnChange()

&AtClient
// Procedure - event handler OnChange of the Period field.
//
Procedure PeriodOnChange(Item)
	
	If Period = '00010101' Then
		Period = CurrentDate();
	EndIf;	
		
	RefreshData();	
    	
EndProcedure // PeriodOnChange()

// Procedure - Click hyperlink event handler For more information, see the CashAssets widget.
//
&AtClient
Procedure CashAssetsDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "CashAssets");
	ReportProperties.Insert("VariantKey", "Statement");
	
	ParametersAndSelections = New Array;
	
	PeriodOfReport = New StandardPeriod;
	PeriodOfReport.StartDate = AddMonth(BegOfDay(Period),-1);
	PeriodOfReport.EndDate = EndOfDay(Period);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Company");
	Setting.Insert("RightValue", Company);
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "ItmPeriod");
	Setting.Insert("RightValue", PeriodOfReport);
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = SmallBusinessServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);
	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see widget Debitors.
//
&AtClient
Procedure DebitorsDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "AccountsReceivable");
	ReportProperties.Insert("VariantKey", "Statement");
	
	ParametersAndSelections = New Array;
	
	PeriodOfReport = New StandardPeriod;
	PeriodOfReport.StartDate = AddMonth(BegOfDay(Period),-1);
	PeriodOfReport.EndDate = EndOfDay(Period);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Company");
	Setting.Insert("RightValue", Company);
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Period");
	Setting.Insert("RightValue", PeriodOfReport);
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = SmallBusinessServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);
	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see the Creditors widget.
//
&AtClient
Procedure CreditorsDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "AccountsPayable");
	ReportProperties.Insert("VariantKey", "Statement");
	
	ParametersAndSelections = New Array;
	
	PeriodOfReport = New StandardPeriod;
	PeriodOfReport.StartDate = AddMonth(BegOfDay(Period),-1);
	PeriodOfReport.EndDate = EndOfDay(Period);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Company");
	Setting.Insert("RightValue", Company);
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Period");
	Setting.Insert("RightValue", PeriodOfReport);
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = SmallBusinessServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);
	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see the CustomerOrders widget.
//
&AtClient
Procedure CustomerOrdersDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "CustomersOrdersConsolidatedAnalysis");
	ReportProperties.Insert("VariantKey", "Default");
	
	ParametersAndSelections = New Array;
	
	Setting = New Structure;
	Setting.Insert("FieldName", "EndOfPeriod");
	Setting.Insert("RightValue", EndOfDay(Period));
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = SmallBusinessServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("FilterByShippingState", "NotShipped");
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);
	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see the PurchaseOrders widget.
//
&AtClient
Procedure PurchaseOrdersDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "PurchaseOrdersConsolidatedAnalysis");
	ReportProperties.Insert("VariantKey", "Default");
	
	ParametersAndSelections = New Array;
	
	Setting = New Structure;
	Setting.Insert("FieldName", "EndOfPeriod");
	Setting.Insert("RightValue", EndOfDay(Period));
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = SmallBusinessServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 			 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings",	 SettingsComposer.UserSettings);
	FormParameters.Insert("FilterByReceiptState", "Outstanding");
	FormParameters.Insert("GenerateOnOpen",		 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);
	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see the ProfitLoss widget.
//
&AtClient
Procedure ProfitDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "IncomeAndExpenses");
	ReportProperties.Insert("VariantKey", "Statement");
	
	ParametersAndSelections = New Array;
	
	PeriodOfReport = New StandardPeriod;
	PeriodOfReport.StartDate = AddMonth(BegOfDay(Period),-1);
	PeriodOfReport.EndDate = EndOfDay(Period);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Company");
	Setting.Insert("RightValue", Company);
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "ItmPeriod");
	Setting.Insert("RightValue", PeriodOfReport);
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = SmallBusinessServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);
	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see the Sales widget.
//
&AtClient
Procedure SalesDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "Sales");
	ReportProperties.Insert("VariantKey", "SalesDynamics");
	
	ParametersAndSelections = New Array;
	
	PeriodOfReport = New StandardPeriod;
	PeriodOfReport.StartDate = AddMonth(BegOfDay(Period),-1);
	PeriodOfReport.EndDate = EndOfDay(Period);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Company");
	Setting.Insert("RightValue", Company);
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Period");
	Setting.Insert("RightValue", PeriodOfReport);
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = SmallBusinessServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);

EndProcedure

// Procedure - event handler Chart selection Petty cash.
//
&AtClient
Procedure ChartPettyCashSelection(Item, ChartValue, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(Undefined, ChartValue.ToolTip);
	
EndProcedure

// Procedure - event handler Chart selection Accounts.
//
&AtClient
Procedure ChartAccountSelection(Item, ChartValue, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(Undefined, ChartValue.ToolTip);
	
EndProcedure

// Procedure - event handler Chart selection Profit.
//
&AtClient
Procedure ProfitChartChoice(Item, ChartValue, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(Undefined, ChartValue.ToolTip);
	
EndProcedure

// Procedure - event handler Chart selection Sales.
//
&AtClient
Procedure SaleDiagramChoice(Item, ChartValue, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(Undefined, ChartValue.ToolTip);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Refresh(Command)
	
	RefreshData();
	
EndProcedure

#EndRegion

#Region CommonUseProceduresAndFunctions

&AtServer
// The procedure restores common monitor settings.
//
Procedure GetSettings()
	
	If Constants.AccountingBySubsidiaryCompany.Get() Then
		Company = Constants.SubsidiaryCompany.Get();
		Items.Company.ReadOnly = True;
	Else
		Company = CommonUse.CommonSettingsStorageImport("SettingsForMonitors", "Company");
		If Not ValueIsFilled(Company) Then
			Company = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
			If Not ValueIsFilled(Company) Then
				Company = Catalogs.Companies.MainCompany;
			EndIf;
		EndIf;
	EndIf;
	
	Period = CommonUse.CommonSettingsStorageImport("SettingsForMonitors", "Period");
	If Not ValueIsFilled(Period) Then
		Period = CurrentSessionDate();
	EndIf;
	
EndProcedure // GetSettings()

&AtServer
// The procedure saves common monitor settings.
//
Procedure SaveSettings()
	
	CommonUse.CommonSettingsStorageSave("SettingsForMonitors", "Company", Company);
	
	If (BegOfDay(CurrentSessionDate()) = BegOfDay(Period)) Then
		CommonUse.CommonSettingsStorageSave("SettingsForMonitors", "Period", '00010101');
	Else
		CommonUse.CommonSettingsStorageSave("SettingsForMonitors", "Period", Period);
	EndIf;

EndProcedure // SaveSettings()

&AtServer
// The procedure updates the form data.
//
Procedure RefreshData()
		
	PeriodPresentation = Format(AddMonth(Period, -1), "DLF=DD") + " — " + Format(Period, "DLF=DD") + ?(BegOfDay(Period) = BegOfDay(CurrentSessionDate()), " (Today)", "");
	
	RefreshWidgetCashAssets();
	RefreshOrdersWidget();
	RefreshDebitorsWidget();
	RefreshWidgetProfitLoss();
	UpdateSalesWidget();
	RefreshCreditorsWidget();
	
EndProcedure // UpdateData()	

&AtServer
Procedure RefreshWidgetCashAssets()
	
	// Petty cashes.
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	CashFundsBalanceAndTurnovers.Period AS Period,
		|	CashFundsBalanceAndTurnovers.AmountClosingBalance AS AmountClosingBalance
		|FROM
		|	AccumulationRegister.CashAssets.BalanceAndTurnovers(
		|			&FilterDateBeginning,
		|			&FilterDate,
		|			Day,
		|			RegisterRecordsAndPeriodBoundaries,
		|			Company = &Company
		|				AND CashAssetsType = &CashAssetsType) AS CashFundsBalanceAndTurnovers
		|WHERE
		|	CashFundsBalanceAndTurnovers.AmountClosingBalance >= 0
		|
		|ORDER BY
		|	Period
		|TOTALS
		|	SUM(AmountClosingBalance)
		|BY
		|	Period PERIODS(Day, &FilterDateBeginning, &FilterDate)";
	
	Query.SetParameter("FilterDate", EndOfDay(Period));
	Query.SetParameter("FilterDateBeginning", AddMonth(BegOfDay(Period),-1));
	Query.SetParameter("Company", Company);
	Query.SetParameter("CashAssetsType", Enums.CashAssetTypes.Cash);
	
	PettyCashChart.RefreshEnabled = False;
	PettyCashChart.Clear();
	PettyCashChart.AutoTransposition = False;
	PettyCashChart.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Series = PettyCashChart.Series.Add("Balance");
	Series.Color = SmallBusinessServer.ColorForMonitors("Orange");
	
	Selection = Query.Execute().Select(QueryResultIteration.ByGroups, "Period", "All");
	RecNo = 0;
	CurrentBalance = 0;
	BalanceYesterday = 0;
	While Selection.Next() Do
		
		Point = PettyCashChart.Points.Add(Selection.Period);
		Point.Text = Format(Selection.Period, "DF=dd.MM.yy");
		Point.Details = Selection.Period;
		ToolTip = "Balance " + Selection.AmountClosingBalance + " on " + Format(Selection.Period, "DF=dd.MM.yyyy");
		PettyCashChart.SetValue(Point, Series, Selection.AmountClosingBalance, Point.Details, ToolTip);
		
		RecNo = RecNo + 1;
		If RecNo = Selection.Count()-1 Then
			BalanceYesterday = ?(Selection.AmountClosingBalance = Null, 0, Selection.AmountClosingBalance);
		ElsIf RecNo = Selection.Count() Then
			CurrentBalance = ?(Selection.AmountClosingBalance = Null, 0, Selection.AmountClosingBalance);
		EndIf;
		
	EndDo;
	
	PettyCashChart.AutoTransposition = True;
	PettyCashChart.RefreshEnabled = True;
	
	Items.DecorationPettyCashBalance.Title = ?(CurrentBalance = 0, "—", SmallBusinessServer.GenerateTitle(CurrentBalance));
	ChangePercent = ?(BalanceYesterday = 0, 0, Round((CurrentBalance - BalanceYesterday) / BalanceYesterday * 100));
	If ChangePercent = 0 Then
		Items.DecorationPettyCashPercent.Visible = False;
	ElsIf ChangePercent < 0 Then
		Items.DecorationPettyCashPercent.Visible = True;
		Items.DecorationPettyCashPercent.Title = "" + Format(ChangePercent, "NFD=") + "%";
		Items.DecorationPettyCashPercent.TextColor = SmallBusinessServer.ColorForMonitors("Red");
	ElsIf ChangePercent > 0 Then
		Items.DecorationPettyCashPercent.Visible = True;
		Items.DecorationPettyCashPercent.Title = "+" + Format(ChangePercent, "NFD=") + "%";
		Items.DecorationPettyCashPercent.TextColor = SmallBusinessServer.ColorForMonitors("Green");
	EndIf;
	
	
	// Accounts.
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	CashFundsBalanceAndTurnovers.Period AS Period,
		|	CashFundsBalanceAndTurnovers.AmountClosingBalance AS AmountClosingBalance
		|FROM
		|	AccumulationRegister.CashAssets.BalanceAndTurnovers(
		|			&FilterDateBeginning,
		|			&FilterDate,
		|			Day,
		|			RegisterRecordsAndPeriodBoundaries,
		|			Company = &Company
		|				AND CashAssetsType = &CashAssetsType) AS CashFundsBalanceAndTurnovers
		|WHERE
		|	CashFundsBalanceAndTurnovers.AmountClosingBalance >= 0
		|
		|ORDER BY
		|	Period
		|TOTALS
		|	SUM(AmountClosingBalance)
		|BY
		|	Period PERIODS(Day, &FilterDateBeginning, &FilterDate)";
	
	Query.SetParameter("FilterDate", EndOfDay(Period));
	Query.SetParameter("FilterDateBeginning", AddMonth(BegOfDay(Period),-1));
	Query.SetParameter("Company", Company);
	Query.SetParameter("CashAssetsType", Enums.CashAssetTypes.Noncash);
	
	AccountChart.RefreshEnabled = False;
	AccountChart.Clear();
	AccountChart.AutoTransposition = False;
	AccountChart.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Series = AccountChart.Series.Add("Balance");
	Series.Color = SmallBusinessServer.ColorForMonitors("Orange");
	
	Selection = Query.Execute().Select(QueryResultIteration.ByGroups, "Period", "All");
	RecNo = 0;
	CurrentBalance = 0;
	BalanceYesterday = 0;
	While Selection.Next() Do
		
		Point = AccountChart.Points.Add(Selection.Period);
		Point.Text = Format(Selection.Period, "DF=dd.MM.yy");
		Point.Details = Selection.Period;
		ToolTip = "Balance " + Selection.AmountClosingBalance + " on " + Format(Selection.Period, "DF=dd.MM.yyyy");
		AccountChart.SetValue(Point, Series, Selection.AmountClosingBalance, Point.Details, ToolTip);
		
		RecNo = RecNo + 1;
		If RecNo = Selection.Count()-1 Then
			BalanceYesterday = ?(Selection.AmountClosingBalance = Null, 0, Selection.AmountClosingBalance);
		ElsIf RecNo = Selection.Count() Then
			CurrentBalance = ?(Selection.AmountClosingBalance = Null, 0, Selection.AmountClosingBalance);
		EndIf;
		
	EndDo;
	
	AccountChart.AutoTransposition = True;
	AccountChart.RefreshEnabled = True;
	
	Items.DecorationAccountsBalance.Title = ?(CurrentBalance = 0, "—", SmallBusinessServer.GenerateTitle(CurrentBalance));
	ChangePercent = ?(BalanceYesterday = 0, 0, Round((CurrentBalance - BalanceYesterday) / BalanceYesterday * 100));
	If ChangePercent = 0 Then
		Items.AccountDecorationPercent.Visible = False;
	ElsIf ChangePercent < 0 Then
		Items.AccountDecorationPercent.Visible = True;
		Items.AccountDecorationPercent.Title = "" + Format(ChangePercent, "NFD=") + "%";
		Items.AccountDecorationPercent.TextColor = SmallBusinessServer.ColorForMonitors("Red");
	ElsIf ChangePercent > 0 Then
		Items.AccountDecorationPercent.Visible = True;
		Items.AccountDecorationPercent.Title = "+" + Format(ChangePercent, "NFD=") + "%";
		Items.AccountDecorationPercent.TextColor = SmallBusinessServer.ColorForMonitors("Green");
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshWidgetProfitLoss()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	IncomeAndExpencesTurnOvers.Period AS Period,
		|	IncomeAndExpencesTurnOvers.AmountIncomeTurnover AS Incomings,
		|	IncomeAndExpencesTurnOvers.AmountExpenseTurnover AS Expenses,
		|	IncomeAndExpencesTurnOvers.AmountIncomeTurnover - IncomeAndExpencesTurnOvers.AmountExpenseTurnover AS Profit
		|FROM
		|	AccumulationRegister.IncomeAndExpenses.Turnovers(
		|			&FilterDateBeginning,
		|			&FilterDateEnds,
		|			Day,
		|			Company = &Company
		|				AND GLAccount <> &EmptyAccount) AS IncomeAndExpencesTurnOvers
		|
		|ORDER BY
		|	Period
		|TOTALS
		|	SUM(Incomings),
		|	SUM(Expenses),
		|	SUM(Profit)
		|BY
		|	OVERALL,
		|	Period PERIODS(Day, &FilterDateBeginning, &FilterDateEnds)";

	Query.SetParameter("FilterDateBeginning", AddMonth(BegOfDay(Period),-1));
	Query.SetParameter("FilterDateEnds", EndOfDay(Period));
	Query.SetParameter("Company", Company);
	Query.SetParameter("EmptyAccount", ChartsOfAccounts.Managerial.EmptyRef());

	SelectionTotal = Query.Execute().Select(QueryResultIteration.ByGroups);
	If SelectionTotal.Next() Then
		Items.DecorationTotalIncomings.Title = SmallBusinessServer.GenerateTitle(SelectionTotal.Incomings);
		Items.DecorationExpensesTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotal.Expenses);
		Items.DecorationProfitTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotal.Profit);
	Else
		Items.DecorationTotalIncomings.Title = "—";
		Items.DecorationExpensesTotal.Title = "—";
		Items.DecorationProfitTotal.Title = "—";
	EndIf;
	
	ProfitChart.RefreshEnabled = False;
	ProfitChart.Clear();
	ProfitChart.AutoTransposition = False;
	ProfitChart.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Series = ProfitChart.Series.Add("Profit (Loss)");
	Series.Color = SmallBusinessServer.ColorForMonitors("Blue");
	Series.Line = New Line(ChartLineType.Solid, 2);
	Series.Marker = ChartMarkerType.None;
	
	MaxValue = 0;
	MinValue = 0;
	Selection = SelectionTotal.Select(QueryResultIteration.ByGroups, "Period", "All");
	While Selection.Next() Do
		
		Point = ProfitChart.Points.Add(Selection.Period);
		If Selection.Profit = Null Then
			ProfitLoss = 0;
		Else
			ProfitLoss = Selection.Profit;
		EndIf;
		Point.Text = Format(Selection.Period, "DF=dd.MM.yy");
		Point.Details = Selection.Period;
		ToolTip = ?(ProfitLoss < 0, "Loss " + -ProfitLoss, "Profit " + ProfitLoss) + " on " + Format(Selection.Period, "DF=dd.MM.yyyy");
		ProfitChart.SetValue(Point, Series, Selection.Profit, Point.Details, ToolTip);
		
		If ProfitLoss > MaxValue Then
			MaxValue = ProfitLoss;
		ElsIf ProfitLoss < MinValue Then
			MinValue = ProfitLoss;
		EndIf;
		 
	EndDo;
	
	ProfitChart.MaxValue = Max(Max(MaxValue, -MaxValue), Max(MinValue, -MinValue));
	ProfitChart.MinValue = -ProfitChart.MaxValue;
	
	ProfitChart.AutoTransposition = True;
	ProfitChart.RefreshEnabled = True;
	
EndProcedure

&AtServer
Procedure RefreshDebitorsWidget()
	
	CounterpartyWidth = 28;
	WidthDebt = 9;
	WidthOverdue = 9;
	WidthAdvance = 9;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	AccountsReceivableBalancesOverdue.SettlementsType AS SettlementsType,
		|	AccountsReceivableBalancesOverdue.Counterparty AS Counterparty,
		|	AccountsReceivableBalancesOverdue.AmountBalance
		|INTO vtOverdue
		|FROM
		|	AccumulationRegister.AccountsReceivable.Balance(
		|			&FilterDate,
		|			Company = &Company
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|				AND Contract.CustomerPaymentDueDate > 0
		|				AND DATEDIFF(CASE
		|						WHEN VALUETYPE(Document) = Type(Document.AcceptanceCertificate)
		|							THEN CAST(Document AS Document.AcceptanceCertificate).Date
		|						WHEN VALUETYPE(Document) = Type(Document.Netting)
		|							THEN CAST(Document AS Document.Netting).Date
		|						WHEN VALUETYPE(Document) = Type(Document.CustomerOrder)
		|							THEN CAST(Document AS Document.CustomerOrder).Date
		|						WHEN VALUETYPE(Document) = Type(Document.AgentReport)
		|							THEN CAST(Document AS Document.AgentReport).Date
		|						WHEN VALUETYPE(Document) = Type(Document.ProcessingReport)
		|							THEN CAST(Document AS Document.ProcessingReport).Date
		|						WHEN VALUETYPE(Document) = Type(Document.FixedAssetsTransfer)
		|							THEN CAST(Document AS Document.FixedAssetsTransfer).Date
		|						WHEN VALUETYPE(Document) = Type(Document.CashReceipt)
		|							THEN CAST(Document AS Document.CashReceipt).Date
		|						WHEN VALUETYPE(Document) = Type(Document.PaymentReceipt)
		|							THEN CAST(Document AS Document.PaymentReceipt).Date
		|						WHEN VALUETYPE(Document) = Type(Document.SupplierInvoice)
		|							THEN CAST(Document AS Document.SupplierInvoice).Date
		|						WHEN VALUETYPE(Document) = Type(Document.CustomerInvoice)
		|							THEN CAST(Document AS Document.CustomerInvoice).Date
		|						ELSE Document.Date
		|					END, &FilterDate, Day) > Contract.CustomerPaymentDueDate) AS AccountsReceivableBalancesOverdue
		|
		|INDEX BY
		|	SettlementsType,
		|	Counterparty
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountsReceivableBalances.Counterparty AS Counterparty,
		|	AccountsReceivableBalances.Counterparty.Presentation,
		|	SUM(CASE
		|			WHEN AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|				THEN AccountsReceivableBalances.AmountBalance
		|			ELSE 0
		|		END) AS DebtAmount,
		|	SUM(CASE
		|			WHEN AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN -AccountsReceivableBalances.AmountBalance
		|			ELSE 0
		|		END) AS AdvanceAmount,
		|	SUM(ISNULL(vtOverdue.AmountBalance, 0)) AS AmountOverdue
		|FROM
		|	AccumulationRegister.AccountsReceivable.Balance(&FilterDate, Company = &Company) AS AccountsReceivableBalances
		|		LEFT JOIN vtOverdue AS vtOverdue
		|		ON AccountsReceivableBalances.SettlementsType = vtOverdue.SettlementsType
		|			AND AccountsReceivableBalances.Counterparty = vtOverdue.Counterparty
		|
		|GROUP BY
		|	AccountsReceivableBalances.Counterparty,
		|	AccountsReceivableBalances.Counterparty.Presentation
		|
		|ORDER BY
		|	DebtAmount DESC
		|TOTALS
		|	COUNT(DISTINCT Counterparty),
		|	SUM(DebtAmount),
		|	SUM(AdvanceAmount),
		|	SUM(AmountOverdue)
		|BY
		|	OVERALL";
	
	Query.SetParameter("FilterDate", EndOfDay(Period));
	Query.SetParameter("Company", Company);
	
	SelectionTotals = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	If SelectionTotals.Next() Then
		Items.DecorationDebitorsQuantity.Title = SelectionTotals.Counterparty;
		Items.DecorationDebitorsDebtTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotals.DebtAmount);
		Items.DecorationDebitorsArrearTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotals.AmountOverdue);
	Else
		Items.DecorationDebitorsQuantity.Title = "—";
		Items.DecorationDebitorsDebtTotal.Title = "—";
		Items.DecorationDebitorsArrearTotal.Title = "—";
	EndIf;
	
	Items.DebitorsCounterparty.Title = "";
	Items.DebitorsCounterparty.ToolTip = "";
	Items.DebitorsDebt.Title = "";
	Items.DebitorsDebt.ToolTip = "";
	Items.OverdueDebitors.Title = "";
	Items.OverdueDebitors.ToolTip = "";
	Items.DebitorsAdvance.Title = "";
	Items.DebitorsAdvance.ToolTip = "";
	
	Selection = SelectionTotals.Select();
	For IndexOf = 1 To 5 Do
		If Selection.Next() Then
			
			DebtAmountPresentation = Format(Selection.DebtAmount, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			AmountOverduePresentation = Format(Selection.AmountOverdue, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			AdvanceAmountPresentation = Format(Selection.AdvanceAmount, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			
			TitleCounterparty = StrReplace(Selection.CounterpartyPresentation, " ", Chars.NBSp);
			Items.DebitorsCounterparty.Title = Items.DebitorsCounterparty.Title + ?(IsBlankString(Items.DebitorsCounterparty.Title),"", Chars.LF) 
				+ Left(TitleCounterparty, CounterpartyWidth) + ?(StrLen(TitleCounterparty) > CounterpartyWidth, "...", "");
			Items.DebitorsCounterparty.ToolTip = Items.DebitorsCounterparty.ToolTip + ?(IsBlankString(Items.DebitorsCounterparty.ToolTip),"", Chars.LF) 
				+ TitleCounterparty;
				
			Items.DebitorsDebt.Title = Items.DebitorsDebt.Title + ?(IsBlankString(Items.DebitorsDebt.Title),"", Chars.LF) 
				+ Left(DebtAmountPresentation, WidthDebt) + ?(StrLen(DebtAmountPresentation) > WidthDebt, "...", "");
			Items.DebitorsDebt.ToolTip = Items.DebitorsDebt.ToolTip + ?(IsBlankString(Items.DebitorsDebt.ToolTip),"", Chars.LF) 
				+ DebtAmountPresentation;
				
			Items.OverdueDebitors.Title = Items.OverdueDebitors.Title + ?(IsBlankString(Items.OverdueDebitors.Title),"", Chars.LF) 
				+ Left(AmountOverduePresentation, WidthOverdue) + ?(StrLen(AmountOverduePresentation) > WidthOverdue, "...", "");
			Items.OverdueDebitors.ToolTip = Items.OverdueDebitors.ToolTip + ?(IsBlankString(Items.OverdueDebitors.ToolTip),"", Chars.LF) 
				+ AmountOverduePresentation;
				
			Items.DebitorsAdvance.Title = Items.DebitorsAdvance.Title + ?(IsBlankString(Items.DebitorsAdvance.Title),"", Chars.LF) 
				+ Left(AdvanceAmountPresentation, WidthAdvance) + ?(StrLen(AdvanceAmountPresentation) > WidthAdvance, "...", "");
			Items.DebitorsAdvance.ToolTip = Items.DebitorsAdvance.ToolTip + ?(IsBlankString(Items.DebitorsAdvance.ToolTip),"", Chars.LF) 
				+ AdvanceAmountPresentation;
				
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshCreditorsWidget()
	
	CounterpartyWidth = 28;
	WidthDebt = 9;
	WidthOverdue = 9;
	WidthAdvance = 9;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	AccountsPayableOverdueBalances.SettlementsType,
		|	AccountsPayableOverdueBalances.Counterparty,
		|	AccountsPayableOverdueBalances.AmountBalance
		|INTO vtOverdue
		|FROM
		|	AccumulationRegister.AccountsPayable.Balance(
		|			&FilterDate,
		|			Company = &Company
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|				AND Contract.VendorPaymentDueDate > 0
		|				AND DATEDIFF(CASE
		|						WHEN VALUETYPE(Document) = Type(Document.ExpenseReport)
		|							THEN CAST(Document AS Document.ExpenseReport).Date
		|						WHEN VALUETYPE(Document) = Type(Document.Netting)
		|							THEN CAST(Document AS Document.Netting).Date
		|						WHEN VALUETYPE(Document) = Type(Document.AdditionalCosts)
		|							THEN CAST(Document AS Document.AdditionalCosts).Date
		|						WHEN VALUETYPE(Document) = Type(Document.ReportToPrincipal)
		|							THEN CAST(Document AS Document.ReportToPrincipal).Date
		|						WHEN VALUETYPE(Document) = Type(Document.SubcontractorReport)
		|							THEN CAST(Document AS Document.SubcontractorReport).Date
		|						WHEN VALUETYPE(Document) = Type(Document.SupplierInvoice)
		|							THEN CAST(Document AS Document.SupplierInvoice).Date
		|						WHEN VALUETYPE(Document) = Type(Document.CashPayment)
		|							THEN CAST(Document AS Document.CashPayment).Date
		|						WHEN VALUETYPE(Document) = Type(Document.CustomerInvoice)
		|							THEN CAST(Document AS Document.CustomerInvoice).Date
		|						WHEN VALUETYPE(Document) = Type(Document.PaymentExpense)
		|							THEN CAST(Document AS Document.PaymentExpense).Date
		|						ELSE Document.Date
		|					END, &FilterDate, Day) > Contract.VendorPaymentDueDate) AS AccountsPayableOverdueBalances
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountsPayableBalances.Counterparty AS Counterparty,
		|	AccountsPayableBalances.Counterparty.Presentation,
		|	SUM(CASE
		|			WHEN AccountsPayableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|				THEN AccountsPayableBalances.AmountBalance
		|			ELSE 0
		|		END) AS DebtAmount,
		|	SUM(CASE
		|			WHEN AccountsPayableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN -AccountsPayableBalances.AmountBalance
		|			ELSE 0
		|		END) AS AdvanceAmount,
		|	SUM(ISNULL(vtOverdue.AmountBalance, 0)) AS AmountOverdue
		|FROM
		|	AccumulationRegister.AccountsPayable.Balance(&FilterDate, Company = &Company) AS AccountsPayableBalances
		|		LEFT JOIN vtOverdue AS vtOverdue
		|		ON AccountsPayableBalances.SettlementsType = vtOverdue.SettlementsType
		|			AND AccountsPayableBalances.Counterparty = vtOverdue.Counterparty
		|
		|GROUP BY
		|	AccountsPayableBalances.Counterparty,
		|	AccountsPayableBalances.Counterparty.Presentation
		|
		|ORDER BY
		|	DebtAmount DESC
		|TOTALS
		|	COUNT(DISTINCT Counterparty),
		|	SUM(DebtAmount),
		|	SUM(AdvanceAmount),
		|	SUM(AmountOverdue)
		|BY
		|	OVERALL";
	
	Query.SetParameter("FilterDate", EndOfDay(Period));
	Query.SetParameter("Company", Company);
	
	SelectionTotals = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	If SelectionTotals.Next() Then
		Items.DecorationCreditorsQuantity.Title = SelectionTotals.Counterparty;
		Items.DecorationCreditorsDebtTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotals.DebtAmount);
		Items.DecorationCreditorsOverdueTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotals.AmountOverdue);
	Else
		Items.DecorationCreditorsQuantity.Title = "—";
		Items.DecorationCreditorsDebtTotal.Title = "—";
		Items.DecorationCreditorsOverdueTotal.Title = "—";
	EndIf;
	
	Items.CreditorsCounterparty.Title = "";
	Items.CreditorsCounterparty.ToolTip = "";
	Items.CreditorsDebt.Title = "";
	Items.CreditorsDebt.ToolTip = "";
	Items.CreditorsOverdue.Title = "";
	Items.CreditorsOverdue.ToolTip = "";
	Items.CreditorsAdvance.Title = "";
	Items.CreditorsAdvance.ToolTip = "";
	
	Selection = SelectionTotals.Select();
	For IndexOf = 1 To 5 Do
		If Selection.Next() Then
			
			DebtAmountPresentation = Format(Selection.DebtAmount, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			AmountOverduePresentation = Format(Selection.AmountOverdue, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			AdvanceAmountPresentation = Format(Selection.AdvanceAmount, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			
			TitleCounterparty = StrReplace(Selection.CounterpartyPresentation, " ", Chars.NBSp);
			Items.CreditorsCounterparty.Title = Items.CreditorsCounterparty.Title + ?(IsBlankString(Items.CreditorsCounterparty.Title),"", Chars.LF) 
				+ Left(TitleCounterparty, CounterpartyWidth) + ?(StrLen(TitleCounterparty) > CounterpartyWidth, "...", "");
			Items.CreditorsCounterparty.ToolTip = Items.CreditorsCounterparty.ToolTip + ?(IsBlankString(Items.CreditorsCounterparty.ToolTip),"", Chars.LF) 
				+ TitleCounterparty;
				
			Items.CreditorsDebt.Title = Items.CreditorsDebt.Title + ?(IsBlankString(Items.CreditorsDebt.Title),"", Chars.LF) 
				+ Left(DebtAmountPresentation, WidthDebt) + ?(StrLen(DebtAmountPresentation) > WidthDebt, "...", "");
			Items.CreditorsDebt.ToolTip = Items.CreditorsDebt.ToolTip + ?(IsBlankString(Items.CreditorsDebt.ToolTip),"", Chars.LF) 
				+ DebtAmountPresentation;
				
			Items.CreditorsOverdue.Title = Items.CreditorsOverdue.Title + ?(IsBlankString(Items.CreditorsOverdue.Title),"", Chars.LF) 
				+ Left(AmountOverduePresentation, WidthOverdue) + ?(StrLen(AmountOverduePresentation) > WidthOverdue, "...", "");
			Items.CreditorsOverdue.ToolTip = Items.CreditorsOverdue.ToolTip + ?(IsBlankString(Items.CreditorsOverdue.ToolTip),"", Chars.LF) 
				+ AmountOverduePresentation;
				
			Items.CreditorsAdvance.Title = Items.CreditorsAdvance.Title + ?(IsBlankString(Items.CreditorsAdvance.Title),"", Chars.LF) 
				+ Left(AdvanceAmountPresentation, WidthAdvance) + ?(StrLen(AdvanceAmountPresentation) > WidthAdvance, "...", "");
			Items.CreditorsAdvance.ToolTip = Items.CreditorsAdvance.ToolTip + ?(IsBlankString(Items.CreditorsAdvance.ToolTip),"", Chars.LF) 
				+ AdvanceAmountPresentation;
				
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshOrdersWidget()
	
	AccountingBySubsidiaryCompany = Constants.AccountingBySubsidiaryCompany.Get();
	
	// CUSTOMER ORDERS
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	COUNT(DISTINCT CASE
		|			WHEN DocCustomerOrder.Posted
		|					AND DocCustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|					AND Not RunSchedule.Order IS NULL 
		|					AND RunSchedule.Period < &DayStartFilterDate
		|				THEN DocCustomerOrder.Ref
		|		END) AS BuyersOrdersExecutionExpired,
		|	COUNT(DISTINCT CASE
		|			WHEN DocCustomerOrder.Posted
		|					AND DocCustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|					AND Not RunSchedule.Order IS NULL 
		|					AND RunSchedule.Period = &DayStartFilterDate
		|				THEN DocCustomerOrder.Ref
		|			WHEN DocCustomerOrder.Posted
		|					AND DocCustomerOrder.SchedulePayment
		|					AND DocCustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|					AND Not PaymentSchedule.InvoiceForPayment IS NULL 
		|					AND PaymentSchedule.Period = &DayStartFilterDate
		|				THEN DocCustomerOrder.Ref
		|		END) AS CustomersOrdersForToday,
		|	COUNT(DISTINCT CASE
		|			WHEN DocCustomerOrder.Posted
		|					AND DocCustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|				THEN DocCustomerOrder.Ref
		|		END) AS BuyersOrdersInWork
		|FROM
		|	Document.CustomerOrder AS DocCustomerOrder
		|		LEFT JOIN InformationRegister.OrderFulfillmentSchedule AS RunSchedule
		|		ON DocCustomerOrder.Ref = RunSchedule.Order
		|			AND (RunSchedule.Period <= &DayStartFilterDate)
		|		{LEFT JOIN InformationRegister.OrdersPaymentSchedule AS PaymentSchedule
		|		ON DocCustomerOrder.Ref = PaymentSchedule.InvoiceForPayment
		|			AND (PaymentSchedule.Period <= &DayStartFilterDate)},
		|	Constant.UseCustomerOrderStates AS UseCustomerOrderStates
		|WHERE
		|	DocCustomerOrder.OperationKind <> VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|	AND Not DocCustomerOrder.Closed
		|	AND Not DocCustomerOrder.DeletionMark
		|	AND CASE
		|			WHEN &AccountingBySubsidiaryCompany = FALSE
		|				THEN DocCustomerOrder.Company = &Company
		|			ELSE TRUE
		|		END";

	Query.SetParameter("DayStartFilterDate", BegOfDay(Period));
	Query.SetParameter("AccountingBySubsidiaryCompany", AccountingBySubsidiaryCompany);
	Query.SetParameter("Company", Company);

	Selection = Query.Execute().Select();

	If Selection.Next() Then
		Items.DecorationForShipmentQuantity.Title = ?(Selection.BuyersOrdersInWork = 0, "—", Selection.BuyersOrdersInWork);
		Items.DecorationForShipmentTodayQuantity.Title = ?(Selection.CustomersOrdersForToday = 0, "—", Selection.CustomersOrdersForToday);
		Items.DecorationForShipmentArrearQuantity.Title = ?(Selection.BuyersOrdersExecutionExpired = 0, "—", Selection.BuyersOrdersExecutionExpired);
	EndIf;
	
	// Purchase orders
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	COUNT(DISTINCT CASE
		|			WHEN DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|					AND Not RunSchedule.Order IS NULL 
		|					AND RunSchedule.Period < &DayStartFilterDate
		|				THEN DocPurchaseOrder.Ref
		|		END) AS SupplierOrdersExecutionExpired,
		|	COUNT(DISTINCT CASE
		|			WHEN DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|					AND Not RunSchedule.Order IS NULL 
		|					AND RunSchedule.Period = &DayStartFilterDate
		|				THEN DocPurchaseOrder.Ref
		|			WHEN DocPurchaseOrder.SchedulePayment
		|					AND DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|					AND Not PaymentSchedule.InvoiceForPayment IS NULL 
		|					AND PaymentSchedule.Period = &DayStartFilterDate
		|				THEN DocPurchaseOrder.Ref
		|		END) AS SupplierOrdersForToday,
		|	COUNT(DISTINCT CASE
		|			WHEN DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|				THEN DocPurchaseOrder.Ref
		|		END) AS SupplierOrdersInWork
		|FROM
		|	Document.PurchaseOrder AS DocPurchaseOrder
		|		LEFT JOIN InformationRegister.OrderFulfillmentSchedule AS RunSchedule
		|		ON DocPurchaseOrder.Ref = RunSchedule.Order
		|			AND (RunSchedule.Period <= &DayStartFilterDate)
		|		{LEFT JOIN InformationRegister.OrdersPaymentSchedule AS PaymentSchedule
		|		ON DocPurchaseOrder.Ref = PaymentSchedule.InvoiceForPayment
		|			AND (PaymentSchedule.Period <= &DayStartFilterDate)}
		|WHERE
		|	DocPurchaseOrder.Posted
		|	AND Not DocPurchaseOrder.Closed
		|	AND CASE
		|			WHEN &AccountingBySubsidiaryCompany = FALSE
		|				THEN DocPurchaseOrder.Company = &Company
		|			ELSE TRUE
		|		END";

	Query.SetParameter("DayStartFilterDate", BegOfDay(Period));
	Query.SetParameter("AccountingBySubsidiaryCompany", AccountingBySubsidiaryCompany);
	Query.SetParameter("Company", Company);
	
	Selection = Query.Execute().Select();

	If Selection.Next() Then
		Items.DecorationForEntryQuantity.Title = ?(Selection.SupplierOrdersInWork = 0, "—", Selection.SupplierOrdersInWork);
		Items.DecorationForEntryTodayQuantity.Title = ?(Selection.SupplierOrdersForToday = 0, "—", Selection.SupplierOrdersForToday);
		Items.DecorationForEntryArrearQuantity.Title = ?(Selection.SupplierOrdersExecutionExpired = 0, "—", Selection.SupplierOrdersExecutionExpired);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateSalesWidget()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	COUNT(DISTINCT CASE
		|			WHEN SalesTurnovers.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
		|				THEN SalesTurnovers.ProductsAndServices
		|		END) AS Products,
		|	COUNT(DISTINCT CASE
		|			WHEN SalesTurnovers.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Service)
		|				THEN SalesTurnovers.ProductsAndServices
		|		END) AS Services
		|FROM
		|	AccumulationRegister.Sales.Turnovers(&FilterDateBeginning, &FilterDate, , Company = &Company) AS SalesTurnovers
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesTurnovers.Period AS Period,
		|	SalesTurnovers.AmountTurnover AS Amount
		|FROM
		|	AccumulationRegister.Sales.Turnovers(&FilterDateBeginning, &FilterDate, Day, Company = &Company) AS SalesTurnovers
		|
		|ORDER BY
		|	Period
		|TOTALS
		|	SUM(Amount)
		|BY
		|	OVERALL,
		|	Period PERIODS(Day, &FilterDateBeginning, &FilterDate)";

	Query.SetParameter("FilterDate", EndOfDay(Period));
	Query.SetParameter("FilterDateBeginning", AddMonth(BegOfDay(Period),-1));
	Query.SetParameter("Company", Company);
	
	ResultsArray = Query.ExecuteBatch();
	
	Selection = ResultsArray[0].Select();
	Selection.Next();
	Items.DecorationGoodsQuantity.Title = ?(Selection.Products = 0, "—", Selection.Products);
	Items.DecorationServicesQuantity.Title = ?(Selection.Services = 0, "—", Selection.Services);
	
	SelectionTotal = ResultsArray[1].Select(QueryResultIteration.ByGroups);
	If SelectionTotal.Next() Then
		Items.DecorationSalesTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotal.Amount);
	Else
		Items.DecorationSalesTotal.Title = "—";
	EndIf;
	
	SaleDiagram.RefreshEnabled = False;
	SaleDiagram.Clear();
	SaleDiagram.AutoTransposition = False;
	SaleDiagram.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Series = SaleDiagram.Series.Add("Sales amount");
	Series.Color = SmallBusinessServer.ColorForMonitors("Dark-green");
	
	Selection = SelectionTotal.Select(QueryResultIteration.ByGroups, "Period", "All");

	While Selection.Next() Do
		
		Point = SaleDiagram.Points.Add(Selection.Period);
		Point.Text = Format(Selection.Period, "DF=dd.MM.yy");
		Point.Details = Selection.Period;
		ToolTip = "Sales amount " + Selection.Amount + " on " + Format(Selection.Period, "DF=dd.MM.yyyy");
		SaleDiagram.SetValue(Point, Series, Selection.Amount, Point.Details, ToolTip);
		 
	EndDo;
	
	SaleDiagram.AutoTransposition = True;
	SaleDiagram.RefreshEnabled = True;
	
EndProcedure

#EndRegion














