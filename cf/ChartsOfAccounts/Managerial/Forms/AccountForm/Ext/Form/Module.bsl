
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UseBudgeting = Constants.FunctionalOptionUseBudgeting.Get();
	
	If Not ValueIsFilled(Object.Ref) Then
		
		If Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.FixedAssets")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Debitors")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.CashAssets") 
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Inventory")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.CreditInterestRates")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherFixedAssets")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherExpenses")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.CostOfGoodsSold") Then
			Object.Type = AccountType.Active;
		EndIf;
		
		If Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.DepreciationFixedAssets")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.LongtermObligations")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Incomings")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Capital") 
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Creditors")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.CreditsAndLoans")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherIncome")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.ReserveAndAdditionalCapital")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.TradeMarkup") Then
			Object.Type = AccountType.Passive;
		EndIf;
		
		If Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.ProfitTax")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.UndistributedProfit")
		 OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.ProfitLosses") Then
			Object.Type = AccountType.ActivePassive;
		EndIf;
		
	EndIf;
	
	TypeOfAccount = Object.TypeOfAccount;
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_ChartOfAccountsManagerial", Object.Ref);
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

// Procedure - OnChange event handler of the DistributionMethod entry field.
//
&AtClient
Procedure DistributionModeOnChange(Item)
	
	If Object.MethodOfDistribution = PredefinedValue("Enum.CostingBases.DirectCost") Then
		Items.Filter.Visible = True;
	Else
		Items.Filter.Visible = False;
		Object.GLAccounts.Clear();
	EndIf;

EndProcedure // DistributionModeOnChange()

// Procedure - OnChange event handler of the AccountType entry field.
//
&AtClient
Procedure GLAccountTypeOnChange(Item)
	
	If TypeOfAccount = Object.TypeOfAccount Then
		Return;
	EndIf;
	
	Object.GLAccounts.Clear();
	
	FormManagement();
	
	If Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.UnfinishedProduction") Then
		Object.MethodOfDistribution = PredefinedValue("Enum.CostingBases.DoNotDistribute");
	ElsIf Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.IndirectExpenses") Then
		Object.MethodOfDistribution = PredefinedValue("Enum.CostingBases.ProductionVolume");
	ElsIf Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Expenses")
		  OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Incomings")
		  OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherIncome")
		  OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherExpenses") Then
		Object.MethodOfDistribution = PredefinedValue("Enum.CostingBases.SalesVolume");
	Else
		Object.MethodOfDistribution = PredefinedValue("Enum.CostingBases.DoNotDistribute");
	EndIf;
	
	Items.Filter.Visible = Object.MethodOfDistribution = PredefinedValue("Enum.CostingBases.DirectCost");
	
	TypeOfAccount = Object.TypeOfAccount;
	
EndProcedure

#EndRegion

#Region CommandHandlers

// Procedure - command handler Filter.
//
&AtClient
Procedure Filter(Command)
	
	GLAccountsInStorageAddress = PlaceGLAccountsToStorage();
	
	FormParameters = New Structure(
		"GLAccountsInStorageAddress",
		GLAccountsInStorageAddress
	);
	
	Notification = New NotifyDescription("FilterCompletion",ThisForm,GLAccountsInStorageAddress);
	OpenForm("ChartOfAccounts.Managerial.Form.FilterForm", FormParameters,,,,,Notification);
	
EndProcedure // Filter()

&AtClient
Procedure FilterCompletion(Result,GLAccountsInStorageAddress) Export
	
	If Result = DialogReturnCode.OK Then
		GetGLAccountsFromStorage(GLAccountsInStorageAddress);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// The function moves the GLAccounts tabular section
// to the temporary storage and returns the address
//
&AtServer
Function PlaceGLAccountsToStorage()
	
	Return PutToTempStorage(
		Object.GLAccounts.Unload(,
			"GLAccount"
		),
		UUID
	);
	
EndFunction // PlacePaymentDetailsToStorage()

// The function receives the tabular section of GLAccounts from the temporary storage.
//
&AtServer
Procedure GetGLAccountsFromStorage(GLAccountsInStorageAddress)
	
	TableAccountsAccounting = GetFromTempStorage(GLAccountsInStorageAddress);
	Object.GLAccounts.Clear();
	For Each TableRow IN TableAccountsAccounting Do
		String = Object.GLAccounts.Add();
		FillPropertyValues(String, TableRow);
	EndDo;
	
EndProcedure // GetPaymentDetailsFromStorage()

&AtServer
Procedure FormManagement()
	
	UseBudgeting = Constants.FunctionalOptionUseBudgeting.Get();
	If Object.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses Then
		Items.ClosingAccount.Visible = True;
		Items.MethodOfDistribution.Visible = True;
		Items.MethodOfDistribution.ChoiceList.Clear();
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostingBases.ProductionVolume);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostingBases.DirectCost);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostingBases.DoNotDistribute);
		Items.ClosingAccount.ToolTip = ?(
			UseBudgeting,
			NStr("en='Auto closing account on month closing and budgeting';ru='Счет автоматического закрытия при закрытии месяца и бюджетировании'"),
			NStr("en='Auto closing account on month closing';ru='Счет автоматического закрытия при закрытии месяца'")
		);
		Items.MethodOfDistribution.ToolTip = NStr("en='Method of automatic allocation to the cost of released products on month-end closing';ru='Способ автоматического распределения на себестоимость выпущенной продукции при закрытии месяца'"
		);
	ElsIf Object.TypeOfAccount =  Enums.GLAccountsTypes.UnfinishedProduction Then
		Items.ClosingAccount.Visible = True;
		Items.MethodOfDistribution.Visible = True;
		Items.MethodOfDistribution.ChoiceList.Clear();
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostingBases.ProductionVolume);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostingBases.DirectCost);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostingBases.DoNotDistribute);
		Items.ClosingAccount.ToolTip = ?(
			UseBudgeting,
			NStr("en='Auto closing account on month closing and budgeting';ru='Счет автоматического закрытия при закрытии месяца и бюджетировании'"),
			NStr("en='Auto closing account on month closing';ru='Счет автоматического закрытия при закрытии месяца'")
		);
		Items.MethodOfDistribution.ToolTip = NStr("en='Method of automatic allocation to the cost of released products at month-end closing for intangible costs';ru='Способ автоматического распределения на себестоимость выпущенной продукции при закрытии месяца для нематериальных затрат'"
		);
	ElsIf (TypeOfAccount <>  Enums.GLAccountsTypes.OtherIncome
		   OR TypeOfAccount <>  Enums.GLAccountsTypes.OtherExpenses
		   OR TypeOfAccount <>  Enums.GLAccountsTypes.Expenses
		   OR TypeOfAccount <>  Enums.GLAccountsTypes.CreditInterestRates
		   OR TypeOfAccount <>  Enums.GLAccountsTypes.Incomings)
			AND (Object.TypeOfAccount =  Enums.GLAccountsTypes.OtherIncome
		   OR Object.TypeOfAccount =  Enums.GLAccountsTypes.OtherExpenses
		   OR Object.TypeOfAccount =  Enums.GLAccountsTypes.Expenses
		   OR Object.TypeOfAccount =  Enums.GLAccountsTypes.CreditInterestRates
		   OR Object.TypeOfAccount =  Enums.GLAccountsTypes.Incomings) Then
		Items.ClosingAccount.Visible = False;
		Items.MethodOfDistribution.Visible = True;
		Items.MethodOfDistribution.ChoiceList.Clear();
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostingBases.SalesVolume);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostingBases.SalesRevenue);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostingBases.CostOfGoodsSold);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostingBases.GrossProfit);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostingBases.DoNotDistribute, NStr("en='Direct allocation'"));
		Items.MethodOfDistribution.ToolTip = ?(
			UseBudgeting,
			NStr("en='Method of automatic allocation to the financial result on month-end closing and budgeting';ru='Способ автоматического распределения на финансовый результат при закрытии месяца и бюджетировании'"),
			NStr("en='Method of automatic allocation to the financial result on month-end closing';ru='Способ автоматического распределения на финансовый результат при закрытии месяца'")
		);
	Else
		Items.MethodOfDistribution.Visible = False;
		Items.ClosingAccount.Visible = False;
	EndIf;
	
	Items.Filter.Visible = Object.MethodOfDistribution = Enums.CostingBases.DirectCost;
	
EndProcedure

#EndRegion
