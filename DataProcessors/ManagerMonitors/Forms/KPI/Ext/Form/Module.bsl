
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
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccountingIncomeAndCosts.Period AS Period,
	|	AccountingIncomeAndCosts.AmountIncomeTurnover AS Income,
	|	0 AS Cost,
	|	0 AS Expenses
	|FROM
	|	AccumulationRegister.IncomeAndExpenses.Turnovers(
	|			&FilterDateBeginning,
	|			&FilterDateEnds,
	|			Month,
	|			Company = &Company
	|				AND GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Incomings)) AS AccountingIncomeAndCosts
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingIncomeAndCosts.Period,
	|	0,
	|	AccountingIncomeAndCosts.AmountExpenseTurnover,
	|	0
	|FROM
	|	AccumulationRegister.IncomeAndExpenses.Turnovers(
	|			&FilterDateBeginning,
	|			&FilterDateEnds,
	|			Month,
	|			Company = &Company
	|				AND GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfGoodsSold)) AS AccountingIncomeAndCosts
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingIncomeAndCosts.Period,
	|	0,
	|	0,
	|	AccountingIncomeAndCosts.AmountExpenseTurnover
	|FROM
	|	AccumulationRegister.IncomeAndExpenses.Turnovers(
	|			&FilterDateBeginning,
	|			&FilterDateEnds,
	|			Month,
	|			Company = &Company
	|				AND GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)) AS AccountingIncomeAndCosts
	|
	|ORDER BY
	|	Period
	|TOTALS
	|	SUM(Income),
	|	SUM(Cost),
	|	SUM(Expenses)
	|BY
	|	Period PERIODS(MONTH, &FilterDateBeginning, &FilterDateEnds)";
	
	Query.SetParameter("FilterDateBeginning", AddMonth(EndOfMonth(Period)+1,-12));
	Query.SetParameter("FilterDateEnds", EndOfMonth(Period));
	Query.SetParameter("Company", Company);
	
	QueryResult = Query.Execute();
	
	MaxIncome = 0;
	MaxCost = 0;
	MaxGrossProfit = 0;
	MaxExpenses = 0;
	MaxProfit = 0;
	Selection = QueryResult.Select(QueryResultIteration.ByGroups);
	While Selection.Next() Do
		If Selection.Income > MaxIncome Then
			MaxIncome = Selection.Income;
		EndIf;
		If Selection.Cost > MaxCost Then
			MaxCost = Selection.Cost;
		EndIf;
		If Selection.Income - Selection.Cost > MaxGrossProfit Then
			MaxGrossProfit = Selection.Income - Selection.Cost;
		EndIf;
		If Selection.Expenses > MaxExpenses Then
			MaxExpenses = Selection.Expenses;
		EndIf;
		If Selection.Income - Selection.Cost - Selection.Expenses > MaxProfit Then
			MaxProfit = Selection.Income - Selection.Cost - Selection.Expenses;
		EndIf;
	EndDo;
	
	Selection = Query.Execute().Select(QueryResultIteration.ByGroups, "Period", "All");
	MonthNumber = 0;
	While Selection.Next() Do
		
		MonthNumber = MonthNumber + 1;
		
		Income = ?(ValueIsFilled(Selection.Income), Selection.Income, 0);
		Cost = ?(ValueIsFilled(Selection.Cost), Selection.Cost, 0);
		GrossProfit = Income - Cost;
		Expenses = ?(ValueIsFilled(Selection.Expenses), Selection.Expenses, 0);
		Profit = Income - Cost - Expenses;
		
		Items["Month"+MonthNumber].Title = Format(Selection.Period, "DF='MMMM yyyy'");
		
		Items["Income"+MonthNumber].Title = FormattedStringForChart(Income, MaxIncome, SmallBusinessServer.ColorForMonitors("Green"));
		Items["Cost"+MonthNumber].Title = FormattedStringForChart(Cost, MaxCost, SmallBusinessServer.ColorForMonitors("Blue"));
		Items["GrossProfit"+MonthNumber].Title = FormattedStringForChart(GrossProfit, MaxGrossProfit, SmallBusinessServer.ColorForMonitors("Coral"));
		Items["Expenses"+MonthNumber].Title = FormattedStringForChart(Expenses, MaxExpenses, SmallBusinessServer.ColorForMonitors("Orange"));
		Items["Profit"+MonthNumber].Title = FormattedStringForChart(Profit, MaxProfit, SmallBusinessServer.ColorForMonitors("Magenta"));
		
	EndDo;
	
EndProcedure

// The function returns a formatted string for the form item as a chart (horizontal stacked chart) with a signature
//
// Parameters:
//  CurrentValue	 - Number	 - series
//  MaxValue value	 - Number	 - maximum value for
//  the ValueColor chart	 - Color	 - Color
// for series Return value:
//  FormattedString
&AtServerNoContext
Function FormattedStringForChart(CurrentValue, MaxValue, ValueColor)
	
	CharactersInChart = 16;
	EmptyValueColor = SmallBusinessServer.ColorForMonitors("Light-gray");
	
	RowItems = New Array;
	ItemChartValue = New Structure("String, Font, TextColor");
	ChartLine = "";
	
	If CurrentValue < 0 Or MaxValue <= 0 Then
		CurrentValueCharacters = 0;
	Else
		CurrentValueCharacters = ?(MaxValue = 0, 0, Round(CurrentValue / MaxValue * CharactersInChart));
	EndIf;
	For IndexOf = 1 To CurrentValueCharacters Do
		ChartLine = ChartLine + "▄";
	EndDo;
	ItemChartValue.String = ChartLine;
	ItemChartValue.Font = New Font("@Arial Unicode MS");
	ItemChartValue.TextColor = ValueColor;
	
	RowItems.Add(ItemChartValue);
	
	ItemEmptyValueCharts = New Structure("String, Font, TextColor");
	ChartLine = "";
	
	For IndexOf = CurrentValueCharacters+1 To CharactersInChart Do
		ChartLine = ChartLine + "▄";
	EndDo;
	ChartLine = ChartLine + Chars.LF;
	ItemEmptyValueCharts.String = ChartLine;
	ItemEmptyValueCharts.Font = New Font("@Arial Unicode MS");
	ItemEmptyValueCharts.TextColor = EmptyValueColor;
	RowItems.Add(ItemEmptyValueCharts);
	
	ItemValuePresentation = New Structure("String, Font, TextColor");
	
	ItemValuePresentation.String = Format(CurrentValue, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
	If CurrentValue < 0 Then
		ItemValuePresentation.TextColor = SmallBusinessServer.ColorForMonitors("Red");
	Else
		ItemValuePresentation.TextColor = SmallBusinessServer.ColorForMonitors("Gray");
	EndIf;
	RowItems.Add(ItemValuePresentation);
	
	Return SmallBusinessServer.BuildFormattedString(RowItems);
	
EndFunction

#EndRegion
