
#Region FormEventsHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
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
// Procedure - event  handler OnChange input field Period.
//
Procedure PeriodOnChange(Item)
	
	If Period = '00010101' Then
		Period = CurrentDate();
	EndIf;	
		
	RefreshData();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Interval input field.
//
Procedure IntervalOnChange(Item)
	
	RefreshData();
	
EndProcedure

&AtClient
// Procedure - Click hyperlink event For more information, see widget CashAssetsBalance.
//
Procedure CABalanceDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "CashAssets");
	ReportProperties.Insert("VariantKey", "Statement");
	
	ParametersAndSelections = New Array;
	
	PeriodOfReport = New StandardPeriod;
	PeriodOfReport.StartDate = BeginOfPeriod;
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

&AtClient
// Procedure - Click hyperlink event handler For more information, see widget Profit.
//
Procedure IncomingsDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "CashAssets");
	ReportProperties.Insert("VariantKey", "CashReceiptsDynamics");
	
	ParametersAndSelections = New Array;
	
	PeriodOfReport = New StandardPeriod;
	PeriodOfReport.StartDate = BeginOfPeriod;
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

&AtClient
// Procedure - Click hyperlink event handler For more information, see widget Expenses.
//
Procedure ExpensesDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "CashAssets");
	ReportProperties.Insert("VariantKey", "CashExpenseDynamics");
	
	ParametersAndSelections = New Array;
	
	PeriodOfReport = New StandardPeriod;
	PeriodOfReport.StartDate = BeginOfPeriod;
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
	
	Interval = CommonUse.CommonSettingsStorageImport("SettingsForMonitors", "Interval", Enums.Periodicity.Day);
	
EndProcedure // GetSettings()

&AtServer
// The procedure saves common monitor settings.
//
Procedure SaveSettings()
	
	CommonUse.CommonSettingsStorageSave("SettingsForMonitors", "Company", Company);
	CommonUse.CommonSettingsStorageSave("SettingsForMonitors", "Interval", Interval);
	
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
	
	If Interval = Enums.Periodicity.Day Then
		BeginOfPeriod = AddMonth(BegOfDay(Period),-1);
	ElsIf Interval = Enums.Periodicity.Week Then
		BeginOfPeriod = BegOfWeek(Period) - 4*7*24*3600;
	ElsIf Interval = Enums.Periodicity.Month Or Interval = Enums.Periodicity.Quarter Then
		BeginOfPeriod = AddMonth(BegOfDay(Period),-12);
	EndIf;
	
	PeriodPresentation = Format(BeginOfPeriod, "DLF=DD") + " — " + Format(Period, "DLF=DD") + ?(BegOfDay(Period) = BegOfDay(CurrentSessionDate()), " (Today)", "");
	
	RefreshChartCashAssetsBalance();
	RefreshCAReceiptAndExpenseChart();
	RefreshWidgetCashAssetsBalance();
	RefreshProfitWidget();
	RefreshWidgetLoss();
	
EndProcedure

&AtServer
Procedure RefreshChartCashAssetsBalance()
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	CashFundsBalanceAndTurnovers.Period AS Period,
		|	CashFundsBalanceAndTurnovers.AmountClosingBalance AS AmountClosingBalance
		|FROM
		|	AccumulationRegister.CashAssets.BalanceAndTurnovers(&BeginOfPeriod, &Period, Day, RegisterRecordsAndPeriodBoundaries, Company = &Company) AS CashFundsBalanceAndTurnovers
		|WHERE
		|	CashFundsBalanceAndTurnovers.AmountClosingBalance > 0
		|
		|ORDER BY
		|	Period
		|TOTALS
		|	SUM(AmountClosingBalance)
		|BY
		|	Period PERIODS(Day, &BeginOfPeriod, &Period)";
	
	Query.Text = StrReplace(Query.Text, "Day", Interval);	
	
	Query.SetParameter("Period", EndOfDay(Period));
	Query.SetParameter("BeginOfPeriod", BeginOfPeriod);
	Query.SetParameter("Company", Company);

	ChartCABalance.RefreshEnabled = False;
	ChartCABalance.Clear();
	ChartCABalance.AutoTransposition = False;
	ChartCABalance.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Series = ChartCABalance.Series.Add("Balance");
	Series.Color = SmallBusinessServer.ColorForMonitors("Orange");
	
	Selection = Query.Execute().Select(QueryResultIteration.ByGroups, "Period", "All");
	While Selection.Next() Do
		
		Point = ChartCABalance.Points.Add(Selection.Period);
		Point.Text = Format(Selection.Period, "DF=dd.MM.yy");
		ToolTip = "Balance " + Selection.AmountClosingBalance + " on " + Format(Selection.Period, "DF=dd.MM.yyyy");
		ChartCABalance.SetValue(Point, Series, Selection.AmountClosingBalance, , ToolTip);
		
	EndDo;
	
	ChartCABalance.AutoTransposition = True;
	ChartCABalance.RefreshEnabled = True;
	
EndProcedure

&AtServer
Procedure RefreshCAReceiptAndExpenseChart()
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	CashAssetsTurnovers.Period AS Period,
		|	CashAssetsTurnovers.AmountReceipt AS AmountReceipt,
		|	CashAssetsTurnovers.AmountExpense AS AmountExpense
		|FROM
		|	AccumulationRegister.CashAssets.Turnovers(&BeginOfPeriod, &Period, Day, Company = &Company) AS CashAssetsTurnovers
		|
		|ORDER BY
		|	Period
		|TOTALS
		|	SUM(AmountReceipt),
		|	SUM(AmountExpense)
		|BY
		|	Period PERIODS(DAY, &BeginOfPeriod, &Period)";
		
	Query.Text = StrReplace(Query.Text, "DAY", Interval);	
	Query.Text = StrReplace(Query.Text, "Day", Interval);
	
	Query.SetParameter("Period", EndOfDay(Period));
	Query.SetParameter("BeginOfPeriod", BeginOfPeriod);
	Query.SetParameter("Company", Company);

	ChartCAReceipt.RefreshEnabled = False;
	ChartCAReceipt.Clear();
	ChartCAReceipt.AutoTransposition = False;
	ChartCAReceipt.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Series = ChartCAReceipt.Series.Add("Receipt");
	Series.Color = SmallBusinessServer.ColorForMonitors("Green");
	
	Selection = Query.Execute().Select(QueryResultIteration.ByGroups, "Period", "All");
	While Selection.Next() Do
		
		Point = ChartCAReceipt.Points.Add(Selection.Period);
		Point.Text = Format(Selection.Period, "DF=dd.MM.yy");
		ToolTip = "Receipt " + Selection.AmountReceipt + " on " + Format(Selection.Period, "DF=dd.MM.yyyy");
		ChartCAReceipt.SetValue(Point, Series, Selection.AmountReceipt, , ToolTip);
		
	EndDo;
	
	ChartCAReceipt.AutoTransposition = True;
	ChartCAReceipt.RefreshEnabled = True;
	
	CAExpenseChart.RefreshEnabled = False;
	CAExpenseChart.Clear();
	CAExpenseChart.AutoTransposition = False;
	CAExpenseChart.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Series = CAExpenseChart.Series.Add("Expense");
	Series.Color = SmallBusinessServer.ColorForMonitors("Red");
	
	Selection.Reset();
	While Selection.Next() Do
		
		Point = CAExpenseChart.Points.Add(Selection.Period);
		Point.Text = Format(Selection.Period, "DF=dd.MM.yy");
		ToolTip = "Expense " + Selection.AmountExpense + " on " + Format(Selection.Period, "DF=dd.MM.yyyy");
		CAExpenseChart.SetValue(Point, Series, Selection.AmountExpense, , ToolTip);
		
	EndDo;
	
	CAExpenseChart.AutoTransposition = True;
	CAExpenseChart.RefreshEnabled = True;
	
EndProcedure

&AtServer
Procedure RefreshWidgetCashAssetsBalance()
	
	WidthAccount = 19;
	WidthBalanceAccount = 9;
	WidthPettyCash = 16;
	WidthBalancePettyCash = 8;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	CashAssetsBalances.BankAccountPettyCash AS BankAccount,
		|	CashAssetsBalances.BankAccountPettyCash.Presentation AS BankAccountPresentation,
		|	CashAssetsBalances.AmountBalance AS AmountBalance
		|FROM
		|	AccumulationRegister.CashAssets.Balance(
		|			&Period,
		|			Company = &Company
		|				AND CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)) AS CashAssetsBalances
		|
		|ORDER BY
		|	AmountBalance DESC
		|TOTALS
		|	SUM(AmountBalance)
		|BY
		|	OVERALL
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CashAssetsBalances.BankAccountPettyCash AS PettyCash,
		|	CashAssetsBalances.BankAccountPettyCash.Presentation AS PettyCashPresentation,
		|	CashAssetsBalances.AmountBalance AS AmountBalance
		|FROM
		|	AccumulationRegister.CashAssets.Balance(
		|			&Period,
		|			Company = &Company
		|				AND CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)) AS CashAssetsBalances
		|
		|ORDER BY
		|	AmountBalance DESC
		|TOTALS
		|	SUM(AmountBalance)
		|BY
		|	OVERALL";
	
	Query.SetParameter("Period", EndOfDay(Period));
	Query.SetParameter("BeginOfPeriod", BeginOfPeriod);
	Query.SetParameter("Company", Company);
	
	ResultsArray = Query.ExecuteBatch();

	SelectionTotals = ResultsArray[0].Select(QueryResultIteration.ByGroups);
	If SelectionTotals.Next() Then
		Items.DecorationBankAccountsTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotals.AmountBalance);
	Else
		Items.DecorationBankAccountsTotal.Title = "—";
	EndIf;
	
	Items.BankAccount.Title = "";
	Items.BankAccount.ToolTip = "";
	Items.BalanceBankAccount.Title = "";
	Items.BalanceBankAccount.ToolTip = "";
	
	Selection = SelectionTotals.Select();
	For IndexOf = 1 To 6 Do
		If Selection.Next() Then
			
			AmountBalancePresentation = Format(Selection.AmountBalance, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			
			Items.BankAccount.Title = Items.BankAccount.Title + ?(IsBlankString(Items.BankAccount.Title),"", Chars.LF) 
				+ Left(Selection.BankAccountPresentation, WidthAccount) + ?(StrLen(Selection.BankAccountPresentation) > WidthAccount, "...", "");
			Items.BankAccount.ToolTip = Items.BankAccount.ToolTip + ?(IsBlankString(Items.BankAccount.ToolTip),"", Chars.LF) 
				+ Selection.BankAccountPresentation;
				
			Items.BalanceBankAccount.Title = Items.BalanceBankAccount.Title + ?(IsBlankString(Items.BalanceBankAccount.Title),"", Chars.LF) 
				+ Left(AmountBalancePresentation, WidthBalanceAccount) + ?(StrLen(AmountBalancePresentation) > WidthBalanceAccount, "...", "");
			Items.BalanceBankAccount.ToolTip = Items.BalanceBankAccount.ToolTip + ?(IsBlankString(Items.BalanceBankAccount.ToolTip),"", Chars.LF) 
				+ AmountBalancePresentation;
				
		EndIf;
	EndDo;
	
	SelectionTotals = ResultsArray[1].Select(QueryResultIteration.ByGroups);
	If SelectionTotals.Next() Then
		Items.DecorationPettyCashesTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotals.AmountBalance);
	Else
		Items.DecorationPettyCashesTotal.Title = "—";
	EndIf;
	
	Items.PettyCash.Title = "";
	Items.PettyCash.ToolTip = "";
	Items.BalancePettyCash.Title = "";
	Items.BalancePettyCash.ToolTip = "";
	
	Selection = SelectionTotals.Select();
	For IndexOf = 1 To 6 Do
		If Selection.Next() Then
			
			AmountBalancePresentation = Format(Selection.AmountBalance, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			
			Items.PettyCash.Title = Items.PettyCash.Title + ?(IsBlankString(Items.PettyCash.Title),"", Chars.LF) 
				+ Left(Selection.PettyCashPresentation, WidthPettyCash) + ?(StrLen(Selection.PettyCashPresentation) > WidthPettyCash, "...", "");
			Items.PettyCash.ToolTip = Items.PettyCash.ToolTip + ?(IsBlankString(Items.PettyCash.ToolTip),"", Chars.LF) 
				+ Selection.PettyCashPresentation;
				
			Items.BalancePettyCash.Title = Items.BalancePettyCash.Title + ?(IsBlankString(Items.BalancePettyCash.Title),"", Chars.LF) 
				+ Left(AmountBalancePresentation, WidthBalancePettyCash) + ?(StrLen(AmountBalancePresentation) > WidthBalancePettyCash, "...", "");
			Items.BalancePettyCash.ToolTip = Items.BalancePettyCash.ToolTip + ?(IsBlankString(Items.BalancePettyCash.ToolTip),"", Chars.LF) 
				+ AmountBalancePresentation;
				
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshProfitWidget()
	
	WidthFlowItem  = 30;
	WidthAmount = 10;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	CASE
		|		WHEN CashFundsBalanceAndTurnovers.Recorder REFS Document.EnterOpeningBalance
		|			THEN ""Enter opening balance""
		|		ELSE CashFundsBalanceAndTurnovers.Recorder.Item.Presentation
		|	END AS IncomeKind,
		|	SUM(CashFundsBalanceAndTurnovers.AmountReceipt) AS Amount
		|FROM
		|	AccumulationRegister.CashAssets.BalanceAndTurnovers(&BeginOfPeriod, &Period, Recorder, , Company = &Company) AS CashFundsBalanceAndTurnovers
		|WHERE
		|	CashFundsBalanceAndTurnovers.AmountReceipt > 0
		|
		|GROUP BY
		|	CASE
		|		WHEN CashFundsBalanceAndTurnovers.Recorder REFS Document.EnterOpeningBalance
		|			THEN ""Enter opening balance""
		|		ELSE CashFundsBalanceAndTurnovers.Recorder.Item.Presentation
		|	END
		|
		|ORDER BY
		|	Amount DESC
		|TOTALS
		|	SUM(Amount)
		|BY
		|	OVERALL";
		
	Query.SetParameter("Period", EndOfDay(Period));
	Query.SetParameter("BeginOfPeriod", BeginOfPeriod);
	Query.SetParameter("Company", Company);
	
	SelectionTotals = Query.Execute().Select(QueryResultIteration.ByGroups);
	If SelectionTotals.Next() Then
		Items.AmountIncomeTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotals.Amount);
	Else
		Items.AmountIncomeTotal.Title = "—";
	EndIf;
	
	Items.IncomeKind.Title = "";
	Items.IncomeKind.ToolTip = "";
	Items.AmountIncome.Title = "";
	Items.AmountIncome.ToolTip = "";
	
	Selection = SelectionTotals.Select();
	For IndexOf = 1 To 6 Do
		If Selection.Next() Then
			
			AmountPresentation = Format(Selection.Amount, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			
			Items.IncomeKind.Title = Items.IncomeKind.Title + ?(IsBlankString(Items.IncomeKind.Title),"", Chars.LF) 
				+ Left(Selection.IncomeKind, WidthFlowItem) + ?(StrLen(Selection.IncomeKind) > WidthFlowItem, "...", "");
			Items.IncomeKind.ToolTip = Items.IncomeKind.ToolTip + ?(IsBlankString(Items.IncomeKind.ToolTip),"", Chars.LF) 
				+ Selection.IncomeKind;
				
			Items.AmountIncome.Title = Items.AmountIncome.Title + ?(IsBlankString(Items.AmountIncome.Title),"", Chars.LF) 
				+ Left(AmountPresentation, WidthAmount) + ?(StrLen(AmountPresentation) > WidthAmount, "...", "");
			Items.AmountIncome.ToolTip = Items.AmountIncome.ToolTip + ?(IsBlankString(Items.AmountIncome.ToolTip),"", Chars.LF) 
				+ AmountPresentation;
				
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshWidgetLoss()
	
	WidthFlowItem  = 30;
	WidthAmount = 10;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	CASE
		|		WHEN CashFundsBalanceAndTurnovers.Recorder REFS Document.EnterOpeningBalance
		|			THEN ""Enter opening balance""
		|		ELSE CashFundsBalanceAndTurnovers.Recorder.Item.Presentation
		|	END AS ExpenseKind,
		|	SUM(CashFundsBalanceAndTurnovers.AmountExpense) AS Amount
		|FROM
		|	AccumulationRegister.CashAssets.BalanceAndTurnovers(&BeginOfPeriod, &Period, Recorder, , Company = &Company) AS CashFundsBalanceAndTurnovers
		|WHERE
		|	CashFundsBalanceAndTurnovers.AmountExpense > 0
		|
		|GROUP BY
		|	CASE
		|		WHEN CashFundsBalanceAndTurnovers.Recorder REFS Document.EnterOpeningBalance
		|			THEN ""Enter opening balance""
		|		ELSE CashFundsBalanceAndTurnovers.Recorder.Item.Presentation
		|	END
		|
		|ORDER BY
		|	Amount DESC
		|TOTALS
		|	SUM(Amount)
		|BY
		|	OVERALL";

	Query.SetParameter("Period", EndOfDay(Period));
	Query.SetParameter("BeginOfPeriod", BeginOfPeriod);
	Query.SetParameter("Company", Company);
	
	SelectionTotals = Query.Execute().Select(QueryResultIteration.ByGroups);
	If SelectionTotals.Next() Then
		Items.AmountExpensesTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotals.Amount);
	Else
		Items.AmountExpensesTotal.Title = "—";
	EndIf;
	
	Items.ExpenseKind.Title = "";
	Items.ExpenseKind.ToolTip = "";
	Items.AmountExpense.Title = "";
	Items.AmountExpense.ToolTip = "";
	
	Selection = SelectionTotals.Select();
	For IndexOf = 1 To 6 Do
		If Selection.Next() Then
			
			AmountPresentation = Format(Selection.Amount, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			
			Items.ExpenseKind.Title = Items.ExpenseKind.Title + ?(IsBlankString(Items.ExpenseKind.Title),"", Chars.LF) 
				+ Left(Selection.ExpenseKind, WidthFlowItem) + ?(StrLen(Selection.ExpenseKind) > WidthFlowItem, "...", "");
			Items.ExpenseKind.ToolTip = Items.ExpenseKind.ToolTip + ?(IsBlankString(Items.ExpenseKind.ToolTip),"", Chars.LF) 
				+ Selection.ExpenseKind;
				
			Items.AmountExpense.Title = Items.AmountExpense.Title + ?(IsBlankString(Items.AmountExpense.Title),"", Chars.LF) 
				+ Left(AmountPresentation, WidthAmount) + ?(StrLen(AmountPresentation) > WidthAmount, "...", "");
			Items.AmountExpense.ToolTip = Items.AmountExpense.ToolTip + ?(IsBlankString(Items.AmountExpense.ToolTip),"", Chars.LF) 
				+ AmountPresentation;
				
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion