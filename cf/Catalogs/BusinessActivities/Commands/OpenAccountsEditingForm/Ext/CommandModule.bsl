
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ParametersStructure = GetParametersStructure(CommandParameter);
	OpenForm(
		"Catalog.BusinessActivities.Form.GLAccountsEditForm",
		ParametersStructure,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL
	);
	
EndProcedure

&AtServer
Function GetParametersStructure(CommandParameter)
	
	ParametersStructure = New Structure(
		"GLAccountRevenueFromSales, GLAccountCostOfSales, ProfitGLAccount, Ref",
		CommandParameter.GLAccountRevenueFromSales, CommandParameter.GLAccountCostOfSales, CommandParameter.ProfitGLAccount, CommandParameter.Ref);
		
	Return ParametersStructure;
	
EndFunction
