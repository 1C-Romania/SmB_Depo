
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

// Procedure - Click hyperlink event handler For more information, see the Creditors widget.
//
&AtClient
Procedure CreditorsDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "AccountsPayable");
	ReportProperties.Insert("VariantKey", "Statement");
	
	ParametersAndSelections = New Array;
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Company");
	Setting.Insert("RightValue", Company);
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "BeginOfPeriod");
	Setting.Insert("RightValue", AddMonth(BegOfDay(Period),-1));
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "EndOfPeriod");
	Setting.Insert("RightValue", EndOfDay(Period));
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = SmallBusinessServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);
	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see the CreditorsByDeadlines widget.
//
&AtClient
Procedure CreditorsOnTermsDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "AccountsPayableAgingRegister");
	ReportProperties.Insert("VariantKey", "Statement");
	
	ParametersAndSelections = New Array;
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Company");
	Setting.Insert("RightValue", Company);
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "PeriodUs");
	Setting.Insert("RightValue", EndOfDay(Period));
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = SmallBusinessServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);
	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see the CreditorsOverdue widget.
//
&AtClient
Procedure CreditorsArrearDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "AccountsPayableAgingRegister");
	ReportProperties.Insert("VariantKey", "Statement");
	
	ParametersAndSelections = New Array;
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Company");
	Setting.Insert("RightValue", Company);
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "PeriodUs");
	Setting.Insert("RightValue", EndOfDay(Period));
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "DOverdueDebt");
	Setting.Insert("RightValue", 0);
	Setting.Insert("ComparisonType", DataCompositionComparisonType.Greater);
	Setting.Insert("SettingKind", "FixedSettings");
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = SmallBusinessServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);

	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("FixedSettings",	 SettingsComposer.FixedSettings);
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
	
	RefreshChartCreditors();
	RefreshChartAndWidgetCreditorsByDeadlines();
	RefreshChartDebtDynamics();
	RefreshCreditorsWidget();
	RefreshWidgetOverdue();
	
EndProcedure

&AtServer
Procedure RefreshChartCreditors()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	AccountsPayableBalances.Counterparty,
		|	AccountsPayableBalances.Counterparty.Presentation,
		|	AccountsPayableBalances.AmountBalance AS Debt
		|FROM
		|	AccumulationRegister.AccountsPayable.Balance(
		|			&Period,
		|			Company = &Company
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
		|
		|ORDER BY
		|	Debt DESC";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Period", EndOfDay(Period));
	
	ChartCreditors.RefreshEnabled = False;
	ChartCreditors.Clear();
	ChartCreditors.AutoTransposition = False;
	ChartCreditors.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Point = ChartCreditors.Points.Add("Debt = ");
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		Series = ChartCreditors.Series.Add(Selection.CounterpartyPresentation);
		Series.Details = Selection.Counterparty;
		ToolTip = "Debt " + Selection.CounterpartyPresentation + " " + Selection.Debt;
		ChartCreditors.SetValue(Point, Series, Selection.Debt, , ToolTip);
		
	EndDo;

	ChartCreditors.AutoTransposition = True;
	ChartCreditors.RefreshEnabled = True;
	
EndProcedure

&AtServer
Procedure RefreshChartAndWidgetCreditorsByDeadlines()
	
	CounterpartyWidth  = 25;
	WidthLessThan7 = 9;
	WidthLessThan30 = 9;
	WidthMoreThan31 = 9;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	AccountsPayableBalances.Counterparty AS Counterparty,
		|	AccountsPayableBalances.Counterparty.Presentation,
		|	SUM(CASE
		|			WHEN DATEDIFF(AccountsPayableBalances.Document.Date, &Period, DAY) <= 7
		|					AND DATEDIFF(AccountsPayableBalances.Document.Date, &Period, DAY) >= 0
		|				THEN AccountsPayableBalances.AmountBalance
		|			ELSE 0
		|		END) AS DebtLessThan7,
		|	SUM(CASE
		|			WHEN DATEDIFF(AccountsPayableBalances.Document.Date, &Period, DAY) >= 8
		|					AND DATEDIFF(AccountsPayableBalances.Document.Date, &Period, DAY) <= 30
		|				THEN AccountsPayableBalances.AmountBalance
		|			ELSE 0
		|		END) AS DebtLessThan30,
		|	SUM(CASE
		|			WHEN DATEDIFF(AccountsPayableBalances.Document.Date, &Period, DAY) >= 31
		|				THEN AccountsPayableBalances.AmountBalance
		|			ELSE 0
		|		END) AS DebtMoreThan31
		|FROM
		|	AccumulationRegister.AccountsPayable.Balance(
		|			&Period,
		|			Company = &Company
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
		|WHERE
		|	AccountsPayableBalances.AmountBalance > 0
		|	AND DATEDIFF(AccountsPayableBalances.Document.Date, &Period, DAY) >= 0
		|
		|GROUP BY
		|	AccountsPayableBalances.Counterparty,
		|	AccountsPayableBalances.Counterparty.Presentation
		|
		|ORDER BY
		|	DebtMoreThan31 DESC,
		|	DebtLessThan30 DESC,
		|	DebtLessThan7 DESC
		|TOTALS BY
		|	OVERALL";
		
	Query.SetParameter("Period", EndOfDay(Period));
	Query.SetParameter("Company", Company);
	
	Items.DecorationCreditorsLessThan7Total.Title = "";
	Items.DecorationCreditorsLessThan30Total.Title = "";
	Items.DecorationCreditorsMoreThan31Total.Title = "";
	
	ChartCreditorsOnTerms.RefreshEnabled = False;
	ChartCreditorsOnTerms.Clear();
	ChartCreditorsOnTerms.AutoTransposition = False;
	ChartCreditorsOnTerms.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Point = ChartCreditorsOnTerms.Points.Add("Debt = ");
	
	DebtLessThan7 = "Up to 7 days";
	DebtLessThan30 = "8 - 30 days";
	DebtMoreThan31 = "from 31 day";
	
	Items.CounterpartiesOnTerms.Title = "";
	Items.CounterpartiesOnTerms.ToolTip = "";
	Items.CreditorsLessThan7.Title = "";
	Items.CreditorsLessThan7.ToolTip = "";
	Items.CreditorsLessThan30.Title = "";
	Items.CreditorsLessThan30.ToolTip = "";
	Items.CreditorsMoreThan31.Title = "";
	Items.CreditorsMoreThan31.ToolTip = "";
	
	SelectionTotal = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	If SelectionTotal.Next() Then
		
		Items.DecorationCreditorsLessThan7Total.Title = SmallBusinessServer.GenerateTitle(SelectionTotal.DebtLessThan7);
		Items.DecorationCreditorsLessThan30Total.Title = SmallBusinessServer.GenerateTitle(SelectionTotal.DebtLessThan30);
		Items.DecorationCreditorsMoreThan31Total.Title = SmallBusinessServer.GenerateTitle(SelectionTotal.DebtMoreThan31);
		
		Series = ChartCreditorsOnTerms.Series.Add(DebtLessThan7);
		Series.Color = SmallBusinessServer.ColorForMonitors("Green");
		ToolTip = "Overdue less than 7 days " + SelectionTotal.DebtLessThan7;
		ChartCreditorsOnTerms.SetValue(Point, Series, SelectionTotal.DebtLessThan7, , ToolTip);
		
		Series = ChartCreditorsOnTerms.Series.Add(DebtLessThan30);
		Series.Color = SmallBusinessServer.ColorForMonitors("Yellow");
		ToolTip = "Overdue from 8 to 30 days " + SelectionTotal.DebtLessThan30;
		ChartCreditorsOnTerms.SetValue(Point, Series, SelectionTotal.DebtLessThan30, , ToolTip);
		
		Series = ChartCreditorsOnTerms.Series.Add(DebtMoreThan31);
		Series.Color = SmallBusinessServer.ColorForMonitors("Red");
		ToolTip = "Overdue over 31 days " + SelectionTotal.DebtMoreThan31;
		ChartCreditorsOnTerms.SetValue(Point, Series, SelectionTotal.DebtMoreThan31, , ToolTip);
		
		Selection = SelectionTotal.Select();
		
		For IndexOf = 1 To 6 Do
			
			If Selection.Next() Then
				
				DebtLessThan7Presentation = Format(Selection.DebtLessThan7, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
				DebtLessThan30Presentation = Format(Selection.DebtLessThan30, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
				DebtMoreThan31Presentation = Format(Selection.DebtMoreThan31, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
				
				TitleCounterparty = StrReplace(Selection.CounterpartyPresentation, " ", Chars.NBSp);
				Items.CounterpartiesOnTerms.Title = Items.CounterpartiesOnTerms.Title + ?(IsBlankString(Items.CounterpartiesOnTerms.Title),"", Chars.LF) 
					+ Left(TitleCounterparty, CounterpartyWidth) + ?(StrLen(TitleCounterparty) > CounterpartyWidth, "...", "");
				Items.CounterpartiesOnTerms.ToolTip = Items.CounterpartiesOnTerms.ToolTip + ?(IsBlankString(Items.CounterpartiesOnTerms.ToolTip),"", Chars.LF) 
					+ TitleCounterparty;
				
				Items.CreditorsLessThan7.Title = Items.CreditorsLessThan7.Title + ?(IsBlankString(Items.CreditorsLessThan7.Title),"", Chars.LF) 
					+ Left(DebtLessThan7Presentation, WidthLessThan7) + ?(StrLen(DebtLessThan7Presentation) > WidthLessThan7, "...", "");
				Items.CreditorsLessThan7.ToolTip = Items.CreditorsLessThan7.ToolTip + ?(IsBlankString(Items.CreditorsLessThan7.ToolTip),"", Chars.LF) 
					+ DebtLessThan7Presentation;
				
				Items.CreditorsLessThan30.Title = Items.CreditorsLessThan30.Title + ?(IsBlankString(Items.CreditorsLessThan30.Title),"", Chars.LF) 
					+ Left(DebtLessThan30Presentation, WidthLessThan30) + ?(StrLen(DebtLessThan30Presentation) > WidthLessThan30, "...", "");
				Items.CreditorsLessThan30.ToolTip = Items.CreditorsLessThan30.ToolTip + ?(IsBlankString(Items.CreditorsLessThan30.ToolTip),"", Chars.LF) 
					+ DebtLessThan30Presentation;
				
				Items.CreditorsMoreThan31.Title = Items.CreditorsMoreThan31.Title + ?(IsBlankString(Items.CreditorsMoreThan31.Title),"", Chars.LF) 
					+ Left(DebtMoreThan31Presentation, WidthMoreThan31) + ?(StrLen(DebtMoreThan31Presentation) > WidthMoreThan31, "...", "");
				Items.CreditorsMoreThan31.ToolTip = Items.CreditorsMoreThan31.ToolTip + ?(IsBlankString(Items.CreditorsMoreThan31.ToolTip),"", Chars.LF) 
					+ DebtMoreThan31Presentation;
				
			EndIf;
			
		EndDo;
		
	Else
		
		Items.DecorationCreditorsLessThan7Total.Title = "—";
		Items.DecorationCreditorsLessThan30Total.Title = "—";
		Items.DecorationCreditorsMoreThan31Total.Title = "—";
		
	EndIf;
		
	ChartCreditorsOnTerms.AutoTransposition = True;
	ChartCreditorsOnTerms.RefreshEnabled = True;
	
EndProcedure

&AtServer
Procedure RefreshChartDebtDynamics()
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	AccountsPayableBalancesAndTurnovers.Period AS Period,
		|	AccountsPayableBalancesAndTurnovers.AmountClosingBalance AS AmountClosingBalance
		|FROM
		|	AccumulationRegister.AccountsPayable.BalanceAndTurnovers(
		|			&FilterDateBeginning,
		|			&FilterDateEnds,
		|			Day,
		|			RegisterRecordsAndPeriodBoundaries,
		|			Company = &Company
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalancesAndTurnovers
		|WHERE
		|	AccountsPayableBalancesAndTurnovers.AmountClosingBalance > 0
		|
		|ORDER BY
		|	Period
		|TOTALS
		|	SUM(AmountClosingBalance)
		|BY
		|	Period PERIODS(DAY, &FilterDateBeginning, &FilterDateEnds)";

	Query.SetParameter("FilterDateBeginning", AddMonth(BegOfDay(Period),-1));
	Query.SetParameter("FilterDateEnds", EndOfDay(Period));
	Query.SetParameter("Company", Company);
	
	ChartDebtDynamics.RefreshEnabled = False;
	ChartDebtDynamics.Clear();
	ChartDebtDynamics.AutoTransposition = False;
	ChartDebtDynamics.Border = New Border(ControlBorderType.WithoutBorder, -1);

	Series = ChartDebtDynamics.Series.Add("Period");
	Series.Line = New Line(ChartLineType.Solid, 2);
	Series.Marker = ChartMarkerType.None;
	
	Selection = Query.Execute().Select(QueryResultIteration.ByGroups, "Period", "All");
	
	While Selection.Next() Do
		
		Point = ChartDebtDynamics.Points.Add(Selection.Period);
		Point.Text = Format(Selection.Period, "DF=dd.MM.yy");
		ToolTip = "Debt " + Selection.AmountClosingBalance + " on " + Format(Selection.Period, "DF=dd.MM.yyyy");
		ChartDebtDynamics.SetValue(Point, Series, Selection.AmountClosingBalance, , ToolTip);
		 
	EndDo;	
	
	ChartDebtDynamics.AutoTransposition = True;
	ChartDebtDynamics.RefreshEnabled = True;
	
EndProcedure

&AtServer
Procedure RefreshCreditorsWidget()
	
	CounterpartyWidth  = 28;
	WidthDebt = 10;
	WidthAdvance = 10;
	
	Query = New Query;
	Query.Text =
		"SELECT
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
		|		END) AS AdvanceAmount
		|FROM
		|	AccumulationRegister.AccountsPayable.Balance(&FilterDate, Company = &Company) AS AccountsPayableBalances
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
		|	SUM(AdvanceAmount)
		|BY
		|	OVERALL";

	Query.SetParameter("FilterDate", EndOfDay(Period));
	Query.SetParameter("FilterDateBeginning", AddMonth(BegOfDay(Period),-1));
	Query.SetParameter("Company", Company);
	
	SelectionTotals = Query.Execute().Select(QueryResultIteration.ByGroups);
	If SelectionTotals.Next() Then
		Items.DecorationCreditorsQuantity.Title = SelectionTotals.Counterparty;
		Items.DecorationCreditorsDebtTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotals.DebtAmount);
		Items.DecorationCreditorsAdvanceTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotals.AdvanceAmount);
	Else
		Items.DecorationCreditorsQuantity.Title = "—";
		Items.DecorationCreditorsDebtTotal.Title = "—";
		Items.DecorationCreditorsAdvanceTotal.Title = "—";
	EndIf;
	
	Items.CreditorsCounterparty.Title = "";
	Items.CreditorsCounterparty.ToolTip = "";
	Items.CreditorsDebt.Title = "";
	Items.CreditorsDebt.ToolTip = "";
	Items.CreditorsAdvance.Title = "";
	Items.CreditorsAdvance.ToolTip = "";
	
	Selection = SelectionTotals.Select();
	For IndexOf = 1 To 6 Do
		If Selection.Next() Then
			
			DebtAmountPresentation = Format(Selection.DebtAmount, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
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
				
			Items.CreditorsAdvance.Title = Items.CreditorsAdvance.Title + ?(IsBlankString(Items.CreditorsAdvance.Title),"", Chars.LF) 
				+ Left(AdvanceAmountPresentation, WidthAdvance) + ?(StrLen(AdvanceAmountPresentation) > WidthAdvance, "...", "");
			Items.CreditorsAdvance.ToolTip = Items.CreditorsAdvance.ToolTip + ?(IsBlankString(Items.CreditorsAdvance.ToolTip),"", Chars.LF) 
				+ AdvanceAmountPresentation;
				
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshWidgetOverdue()
	
	CounterpartyWidth = 28;
	WidthOverdue = 10;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	AccountsPayableBalances.Counterparty AS Counterparty,
		|	AccountsPayableBalances.Counterparty.Presentation,
		|	AccountsPayableBalances.AmountBalance AS AmountOverdue
		|FROM
		|	AccumulationRegister.AccountsPayable.Balance(
		|			&FilterDate,
		|			Company = &Company
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|				AND Contract.VendorPaymentDueDate > 0
		|				AND DATEDIFF(Document.Date, &FilterDate, DAY) > Contract.VendorPaymentDueDate) AS AccountsPayableBalances
		|
		|GROUP BY
		|	AccountsPayableBalances.Counterparty,
		|	AccountsPayableBalances.Counterparty.Presentation,
		|	AccountsPayableBalances.AmountBalance
		|
		|ORDER BY
		|	AmountOverdue DESC
		|TOTALS
		|	COUNT(DISTINCT Counterparty),
		|	SUM(AmountOverdue)
		|BY
		|	OVERALL";
	
	Query.SetParameter("FilterDate", EndOfDay(Period));
	Query.SetParameter("Company", Company);
	
	SelectionTotals = Query.Execute().Select(QueryResultIteration.ByGroups);
	If SelectionTotals.Next() Then
		Items.DecorationArrearCreditorsQuantity.Title = SelectionTotals.Counterparty;
		Items.DecorationCreditorsOverdueTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotals.AmountOverdue);
	Else
		Items.DecorationArrearCreditorsQuantity.Title = "—";
		Items.DecorationCreditorsOverdueTotal.Title = "—";
	EndIf;
	
	Items.CreditorsArrearCounterparty.Title = "";
	Items.CreditorsArrearCounterparty.ToolTip = "";
	Items.CreditorsOverdue.Title = "";
	Items.CreditorsOverdue.ToolTip = "";
	
	Selection = SelectionTotals.Select();
	For IndexOf = 1 To 6 Do
		If Selection.Next() Then
			
			AmountOverduePresentation = Format(Selection.AmountOverdue, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			
			TitleCounterparty = StrReplace(Selection.CounterpartyPresentation, " ", Chars.NBSp);
			Items.CreditorsArrearCounterparty.Title = Items.CreditorsArrearCounterparty.Title + ?(IsBlankString(Items.CreditorsArrearCounterparty.Title),"", Chars.LF) 
				+ Left(TitleCounterparty, CounterpartyWidth) + ?(StrLen(TitleCounterparty) > CounterpartyWidth, "...", "");
			Items.CreditorsArrearCounterparty.ToolTip = Items.CreditorsArrearCounterparty.ToolTip + ?(IsBlankString(Items.CreditorsArrearCounterparty.ToolTip),"", Chars.LF) 
				+ TitleCounterparty;
				
			Items.CreditorsOverdue.Title = Items.CreditorsOverdue.Title + ?(IsBlankString(Items.CreditorsOverdue.Title),"", Chars.LF) 
				+ Left(AmountOverduePresentation, WidthOverdue) + ?(StrLen(AmountOverduePresentation) > WidthOverdue, "...", "");
			Items.CreditorsOverdue.ToolTip = Items.CreditorsOverdue.ToolTip + ?(IsBlankString(Items.CreditorsOverdue.ToolTip),"", Chars.LF) 
				+ AmountOverduePresentation;
				
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
