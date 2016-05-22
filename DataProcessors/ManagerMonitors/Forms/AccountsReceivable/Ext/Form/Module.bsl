
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

// Procedure - Click hyperlink event handler For more information, see widget Debitors.
//
&AtClient
Procedure DebitorsDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "AccountsReceivable");
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

// Procedure - Click hyperlink event handler For more information, see widget DebitorsByDeadlines.
//
&AtClient
Procedure DebitorsOnTermsDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "AccountsReceivableAgingRegister");
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

// Procedure - Click hyperlink event handler For more information, see widget DebitorsOverdue.
//
&AtClient
Procedure DebitorsArrearDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "AccountsReceivableAgingRegister");
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
	
	RefreshChartDebitors();
	RefreshChartAndWidgetDebitorsByDeadlines();
	RefreshChartDebtDynamics();
	RefreshDebitorsWidget();
	RefreshWidgetOverdue();
	
EndProcedure

&AtServer
Procedure RefreshChartDebitors()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	AccountsReceivableBalances.Counterparty,
		|	AccountsReceivableBalances.Counterparty.Presentation,
		|	AccountsReceivableBalances.AmountBalance AS Debt
		|FROM
		|	AccumulationRegister.AccountsReceivable.Balance(
		|			&Period,
		|			Company = &Company
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
		|
		|ORDER BY
		|	Debt DESC";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Period", EndOfDay(Period));
	
	ChartDebitors.RefreshEnabled= False;
	ChartDebitors.Clear();
	ChartDebitors.AutoTransposition = False;
	ChartDebitors.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Point = ChartDebitors.Points.Add("Debt = ");
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		Series = ChartDebitors.Series.Add(Selection.CounterpartyPresentation);
		Series.Details = Selection.Counterparty;
		ToolTip = "Debt " + Selection.CounterpartyPresentation + " " + Selection.Debt;
		ChartDebitors.SetValue(Point, Series, Selection.Debt, , ToolTip);
		
	EndDo;

	ChartDebitors.AutoTransposition = True;
	ChartDebitors.RefreshEnabled = True;
	
EndProcedure

&AtServer
Procedure RefreshChartAndWidgetDebitorsByDeadlines()
	
	CounterpartyWidth  = 25;
	WidthLessThan7 = 9;
	WidthLessThan30 = 9;
	WidthMoreThan31 = 9;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	AccountsReceivableBalances.Counterparty AS Counterparty,
		|	AccountsReceivableBalances.Counterparty.Presentation,
		|	SUM(CASE
		|			WHEN DATEDIFF(AccountsReceivableBalances.Document.Date, &Period, Day) <= 7
		|					AND DATEDIFF(AccountsReceivableBalances.Document.Date, &Period, Day) >= 0
		|				THEN AccountsReceivableBalances.AmountBalance
		|			ELSE 0
		|		END) AS DebtLessThan7,
		|	SUM(CASE
		|			WHEN DATEDIFF(AccountsReceivableBalances.Document.Date, &Period, Day) >= 8
		|					AND DATEDIFF(AccountsReceivableBalances.Document.Date, &Period, Day) <= 30
		|				THEN AccountsReceivableBalances.AmountBalance
		|			ELSE 0
		|		END) AS DebtLessThan30,
		|	SUM(CASE
		|			WHEN DATEDIFF(AccountsReceivableBalances.Document.Date, &Period, Day) >= 31
		|				THEN AccountsReceivableBalances.AmountBalance
		|			ELSE 0
		|		END) AS DebtMoreThan31
		|FROM
		|	AccumulationRegister.AccountsReceivable.Balance(
		|			&Period,
		|			Company = &Company
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
		|WHERE
		|	AccountsReceivableBalances.AmountBalance > 0
		|	AND DATEDIFF(AccountsReceivableBalances.Document.Date, &Period, Day) >= 0
		|
		|GROUP BY
		|	AccountsReceivableBalances.Counterparty,
		|	AccountsReceivableBalances.Counterparty.Presentation
		|
		|ORDER BY
		|	DebtMoreThan31 DESC,
		|	DebtLessThan30 DESC,
		|	DebtLessThan7 DESC
		|TOTALS BY
		|	OVERALL";
		
	Query.SetParameter("Period", EndOfDay(Period));
	Query.SetParameter("Company", Company);
	
	Items.DecorationDebitorsLessThan7Total.Title = "";
	Items.DecorationDebitorsLessThan30Total.Title = "";
	Items.DecorationDebitorsMoreThan31Total.Title = "";
	
	ChartDebitorsOnTerms.RefreshEnabled = False;
	ChartDebitorsOnTerms.Clear();
	ChartDebitorsOnTerms.AutoTransposition = False;
	ChartDebitorsOnTerms.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Point = ChartDebitorsOnTerms.Points.Add("Debt = ");
	
	DebtLessThan7 = "Up to 7 days";
	DebtLessThan30 = "8 - 30 days";
	DebtMoreThan31 = "from 31 day";
	
	Items.CounterpartiesOnTerms.Title = "";
	Items.CounterpartiesOnTerms.ToolTip = "";
	Items.DebitorsLessThan7.Title = "";
	Items.DebitorsLessThan7.ToolTip = "";
	Items.DebitorsLessThan30.Title = "";
	Items.DebitorsLessThan30.ToolTip = "";
	Items.DebitorsMoreThan31.Title = "";
	Items.DebitorsMoreThan31.ToolTip = "";
	
	SelectionTotal = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	If SelectionTotal.Next() Then
		
		Items.DecorationDebitorsLessThan7Total.Title = SmallBusinessServer.GenerateTitle(SelectionTotal.DebtLessThan7);
		Items.DecorationDebitorsLessThan30Total.Title = SmallBusinessServer.GenerateTitle(SelectionTotal.DebtLessThan30);
		Items.DecorationDebitorsMoreThan31Total.Title = SmallBusinessServer.GenerateTitle(SelectionTotal.DebtMoreThan31);
		
		Series = ChartDebitorsOnTerms.Series.Add(DebtLessThan7);
		Series.Color = SmallBusinessServer.ColorForMonitors("Green");
		ToolTip = "Overdue less than 7 days " + SelectionTotal.DebtLessThan7;
		ChartDebitorsOnTerms.SetValue(Point, Series, SelectionTotal.DebtLessThan7, , ToolTip);
		
		Series = ChartDebitorsOnTerms.Series.Add(DebtLessThan30);
		Series.Color = SmallBusinessServer.ColorForMonitors("Yellow");
		ToolTip = "Overdue from 8 to 30 days " + SelectionTotal.DebtLessThan30;
		ChartDebitorsOnTerms.SetValue(Point, Series, SelectionTotal.DebtLessThan30, , ToolTip);
		
		Series = ChartDebitorsOnTerms.Series.Add(DebtMoreThan31);
		Series.Color = SmallBusinessServer.ColorForMonitors("Red");
		ToolTip = "Overdue over 31 days " + SelectionTotal.DebtMoreThan31;
		ChartDebitorsOnTerms.SetValue(Point, Series, SelectionTotal.DebtMoreThan31, , ToolTip);
		
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
				
				Items.DebitorsLessThan7.Title = Items.DebitorsLessThan7.Title + ?(IsBlankString(Items.DebitorsLessThan7.Title),"", Chars.LF) 
					+ Left(DebtLessThan7Presentation, WidthLessThan7) + ?(StrLen(DebtLessThan7Presentation) > WidthLessThan7, "...", "");
				Items.DebitorsLessThan7.ToolTip = Items.DebitorsLessThan7.ToolTip + ?(IsBlankString(Items.DebitorsLessThan7.ToolTip),"", Chars.LF) 
					+ DebtLessThan7Presentation;
				
				Items.DebitorsLessThan30.Title = Items.DebitorsLessThan30.Title + ?(IsBlankString(Items.DebitorsLessThan30.Title),"", Chars.LF) 
					+ Left(DebtLessThan30Presentation, WidthLessThan30) + ?(StrLen(DebtLessThan30Presentation) > WidthLessThan30, "...", "");
				Items.DebitorsLessThan30.ToolTip = Items.DebitorsLessThan30.ToolTip + ?(IsBlankString(Items.DebitorsLessThan30.ToolTip),"", Chars.LF) 
					+ DebtLessThan30Presentation;
				
				Items.DebitorsMoreThan31.Title = Items.DebitorsMoreThan31.Title + ?(IsBlankString(Items.DebitorsMoreThan31.Title),"", Chars.LF) 
					+ Left(DebtMoreThan31Presentation, WidthMoreThan31) + ?(StrLen(DebtMoreThan31Presentation) > WidthMoreThan31, "...", "");
				Items.DebitorsMoreThan31.ToolTip = Items.DebitorsMoreThan31.ToolTip + ?(IsBlankString(Items.DebitorsMoreThan31.ToolTip),"", Chars.LF) 
					+ DebtMoreThan31Presentation;
				
			EndIf;
			
		EndDo;
		
	Else
		
		Items.DecorationDebitorsLessThan7Total.Title = "—";
		Items.DecorationDebitorsLessThan30Total.Title = "—";
		Items.DecorationDebitorsMoreThan31Total.Title = "—";
		
	EndIf;
		
	ChartDebitorsOnTerms.AutoTransposition = True;
	ChartDebitorsOnTerms.RefreshEnabled = True;
	
EndProcedure

&AtServer
Procedure RefreshChartDebtDynamics()
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	AccountsReceivableBalancesAndTurnovers.Period AS Period,
		|	AccountsReceivableBalancesAndTurnovers.AmountClosingBalance AS AmountClosingBalance
		|FROM
		|	AccumulationRegister.AccountsReceivable.BalanceAndTurnovers(
		|			&FilterDateBeginning,
		|			&FilterDateEnds,
		|			Day,
		|			RegisterRecordsAndPeriodBoundaries,
		|			Company = &Company
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalancesAndTurnovers
		|WHERE
		|	AccountsReceivableBalancesAndTurnovers.AmountClosingBalance > 0
		|
		|ORDER BY
		|	Period
		|TOTALS
		|	SUM(AmountClosingBalance)
		|BY
		|	Period PERIODS(Day, &FilterDateBeginning, &FilterDateEnds)";

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
Procedure RefreshDebitorsWidget()
	
	CounterpartyWidth  = 28;
	WidthDebt = 10;
	WidthAdvance = 10;
	
	Query = New Query;
	Query.Text =
		"SELECT
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
		|		END) AS AdvanceAmount
		|FROM
		|	AccumulationRegister.AccountsReceivable.Balance(&FilterDate, Company = &Company) AS AccountsReceivableBalances
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
		|	SUM(AdvanceAmount)
		|BY
		|	OVERALL";

	Query.SetParameter("FilterDate", EndOfDay(Period));
	Query.SetParameter("FilterDateBeginning", AddMonth(BegOfDay(Period),-1));
	Query.SetParameter("Company", Company);
	
	SelectionTotals = Query.Execute().Select(QueryResultIteration.ByGroups);
	If SelectionTotals.Next() Then
		Items.DecorationDebitorsQuantity.Title = SelectionTotals.Counterparty;
		Items.DecorationDebitorsDebtTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotals.DebtAmount);
		Items.DecorationDebitorsAdvanceTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotals.AdvanceAmount);
	Else
		Items.DecorationDebitorsQuantity.Title = "—";
		Items.DecorationDebitorsDebtTotal.Title = "—";
		Items.DecorationDebitorsAdvanceTotal.Title = "—";
	EndIf;
	
	Items.DebitorsCounterparty.Title = "";
	Items.DebitorsCounterparty.ToolTip = "";
	Items.DebitorsDebt.Title = "";
	Items.DebitorsDebt.ToolTip = "";
	Items.DebitorsAdvance.Title = "";
	Items.DebitorsAdvance.ToolTip = "";
	
	Selection = SelectionTotals.Select();
	For IndexOf = 1 To 6 Do
		If Selection.Next() Then
			
			DebtAmountPresentation = Format(Selection.DebtAmount, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
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
				
			Items.DebitorsAdvance.Title = Items.DebitorsAdvance.Title + ?(IsBlankString(Items.DebitorsAdvance.Title),"", Chars.LF) 
				+ Left(AdvanceAmountPresentation, WidthAdvance) + ?(StrLen(AdvanceAmountPresentation) > WidthAdvance, "...", "");
			Items.DebitorsAdvance.ToolTip = Items.DebitorsAdvance.ToolTip + ?(IsBlankString(Items.DebitorsAdvance.ToolTip),"", Chars.LF) 
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
		|	AccountsReceivableBalances.Counterparty AS Counterparty,
		|	AccountsReceivableBalances.Counterparty.Presentation,
		|	AccountsReceivableBalances.AmountBalance AS AmountOverdue
		|FROM
		|	AccumulationRegister.AccountsReceivable.Balance(
		|			&FilterDate,
		|			Company = &Company
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|				AND Contract.CustomerPaymentDueDate > 0
		|				AND DATEDIFF(Document.Date, &FilterDate, Day) > Contract.CustomerPaymentDueDate) AS AccountsReceivableBalances
		|
		|GROUP BY
		|	AccountsReceivableBalances.Counterparty,
		|	AccountsReceivableBalances.Counterparty.Presentation,
		|	AccountsReceivableBalances.AmountBalance
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
		Items.DecorationDebitorsArrearQuantity.Title = SelectionTotals.Counterparty;
		Items.DecorationDebitorsArrearTotal.Title = SmallBusinessServer.GenerateTitle(SelectionTotals.AmountOverdue);
	Else
		Items.DecorationDebitorsArrearQuantity.Title = "—";
		Items.DecorationDebitorsArrearTotal.Title = "—";
	EndIf;
	
	Items.DebitorsArrearCounterparty.Title = "";
	Items.DebitorsArrearCounterparty.ToolTip = "";
	Items.OverdueDebitors.Title = "";
	Items.OverdueDebitors.ToolTip = "";
	
	Selection = SelectionTotals.Select();
	For IndexOf = 1 To 6 Do
		If Selection.Next() Then
			
			AmountOverduePresentation = Format(Selection.AmountOverdue, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			
			TitleCounterparty = StrReplace(Selection.CounterpartyPresentation, " ", Chars.NBSp);
			Items.DebitorsArrearCounterparty.Title = Items.DebitorsArrearCounterparty.Title + ?(IsBlankString(Items.DebitorsArrearCounterparty.Title),"", Chars.LF) 
				+ Left(TitleCounterparty, CounterpartyWidth) + ?(StrLen(TitleCounterparty) > CounterpartyWidth, "...", "");
			Items.DebitorsArrearCounterparty.ToolTip = Items.DebitorsArrearCounterparty.ToolTip + ?(IsBlankString(Items.DebitorsArrearCounterparty.ToolTip),"", Chars.LF) 
				+ TitleCounterparty;
				
			Items.OverdueDebitors.Title = Items.OverdueDebitors.Title + ?(IsBlankString(Items.OverdueDebitors.Title),"", Chars.LF) 
				+ Left(AmountOverduePresentation, WidthOverdue) + ?(StrLen(AmountOverduePresentation) > WidthOverdue, "...", "");
			Items.OverdueDebitors.ToolTip = Items.OverdueDebitors.ToolTip + ?(IsBlankString(Items.OverdueDebitors.ToolTip),"", Chars.LF) 
				+ AmountOverduePresentation;
				
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

// The function returns user report settings.
//
// Parameters:
//  ReportName			 - String	 - Report name as set in
//  metadata ParametersAndFilters	 - array	 - structure array that sets default filters and parameters. Structure item:
//  									"FieldName" - name of a parameter
//  									of filter field, "Value" - set
//  									value, "CDComparisonType" - DataCompositionComparisonType. If it is not specified, then "Equals to".
// Returns:
//  UserSettings - user report settings
Function GetReportUserSettings(ReportName, ParametersAndSelections, VariantName = "") Export
	
	DataCompositionSchema = Reports[ReportName].GetTemplate("MainDataCompositionSchema");
	If VariantName = "" Then
		Settings = DataCompositionSchema.DefaultSettings;
	Else
		For Each Variant IN DataCompositionSchema.SettingVariants Do
			If Variant.Name = VariantName Then
				Settings = Variant.Settings;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
	DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	DataCompositionSettingsComposer.LoadSettings(Settings);
	
	For Each FilterStructure IN ParametersAndSelections Do
		
		FieldName = Undefined;
		Value = Undefined;
		ComparisonTypeCD = Undefined;
		UserSettingID = Undefined;
		
		FilterStructure.Property("FieldName", FieldName);
		FilterStructure.Property("Value", Value);
		FilterStructure.Property("ComparisonTypeCD", ComparisonTypeCD);
		FilterStructure.Property("UserSettingID", UserSettingID);
		
		FoundParameter = DataCompositionSettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter(FieldName));
		If Not FoundParameter = Undefined Then
			DataCompositionSettingsComposer.Settings.DataParameters.SetParameterValue(FoundParameter.Parameter, Value);
		Else
			CommonUseClientServer.SetFilterItem(DataCompositionSettingsComposer.Settings.Filter, 
				FieldName, Value, ComparisonTypeCD, , True, DataCompositionSettingsItemViewMode.Normal, UserSettingID);
		EndIf;
		
	EndDo;
	
	Return DataCompositionSettingsComposer.UserSettings;
	
EndFunction // GetUserSettings()

// The function returns user report settings.
//
// Parameters:
//  ReportName			 - String	 - Report name as set in
//  metadata ParametersAndFilters	 - array	 - structure array that sets default filters and parameters. Structure item:
//  									"FieldName" - name of a parameter
//  									of filter field, "Value" - set
//  									value, "CDComparisonType" - DataCompositionComparisonType. If it is not specified, then "Equals to".
// Returns:
//  UserSettings - user report settings
Function GetStandardReportSettings(ReportName, ParametersAndSelections, VariantName = "") Export
	
	DataCompositionSchema = Reports[ReportName].GetTemplate("MainDataCompositionSchema");
	If VariantName = "" Then
		Settings = DataCompositionSchema.DefaultSettings;
	Else
		For Each Variant IN DataCompositionSchema.SettingVariants Do
			If Variant.Name = VariantName Then
				Settings = Variant.Settings;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
	DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	DataCompositionSettingsComposer.LoadSettings(Settings);
	
	For Each FilterStructure IN ParametersAndSelections Do
		
		FieldName = Undefined;
		Value = Undefined;
		ComparisonTypeCD = Undefined;
		UserSettingID = Undefined;
		
		FilterStructure.Property("FieldName", FieldName);
		FilterStructure.Property("Value", Value);
		FilterStructure.Property("ComparisonTypeCD", ComparisonTypeCD);
		FilterStructure.Property("UserSettingID", UserSettingID);
		
		FoundParameter = DataCompositionSettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter(FieldName));
		If Not FoundParameter = Undefined Then
			DataCompositionSettingsComposer.Settings.DataParameters.SetParameterValue(FoundParameter.Parameter, Value);
		Else
			CommonUseClientServer.SetFilterItem(DataCompositionSettingsComposer.Settings.Filter, 
				FieldName, Value, ComparisonTypeCD, , True, DataCompositionSettingsItemViewMode.Normal, UserSettingID);
		EndIf;
		
	EndDo;
	
	Return DataCompositionSettingsComposer.UserSettings;
	
EndFunction // GetUserSettings()
// 
