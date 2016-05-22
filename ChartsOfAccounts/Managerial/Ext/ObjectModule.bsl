#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Checked attributes deletion from structure depending on functional option.
	If Not Constants.FunctionalOptionUseBudgeting.Get()
		  AND TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "ClosingAccount");
	EndIf;
	
	If Constants.FunctionalOptionUseBudgeting.Get()
	   AND TypeOfAccount <> Enums.GLAccountsTypes.UnfinishedProduction
	   AND TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "ClosingAccount");
	EndIf;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel)
	
	If TypeOfAccount <> Enums.GLAccountsTypes.Incomings
	   AND TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND TypeOfAccount <> Enums.GLAccountsTypes.UnfinishedProduction
	   AND TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses
	   AND TypeOfAccount <> Enums.GLAccountsTypes.OtherIncome
	   AND TypeOfAccount <> Enums.GLAccountsTypes.OtherExpenses
	   AND TypeOfAccount <> Enums.GLAccountsTypes.CreditInterestRates Then
		MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	EndIf;
	
	If TypeOfAccount <> Enums.GLAccountsTypes.UnfinishedProduction
	   AND TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		ClosingAccount = ChartsOfAccounts.Managerial.EmptyRef();
	EndIf;
	
	If Not ValueIsFilled(Order) Then
		Order = 1;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf