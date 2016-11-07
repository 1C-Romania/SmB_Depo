
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ParametersStructure = GetParametersStructure(CommandParameter);
	OpenForm(
		"Catalog.ProductsAndServices.Form.GLAccountsEditForm",
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
		"InventoryGLAccount, ExpensesGLAccount, ProductsAndServicesType, Ref",
		CommandParameter.InventoryGLAccount, CommandParameter.ExpensesGLAccount, CommandParameter.ProductsAndServicesType, CommandParameter.Ref);
		
	Return ParametersStructure;
	
EndFunction
