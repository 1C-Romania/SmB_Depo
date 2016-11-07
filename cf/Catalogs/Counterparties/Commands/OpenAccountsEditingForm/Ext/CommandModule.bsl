
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ParametersStructure = GetParametersStructure(CommandParameter);
	OpenForm(
		"Catalog.Counterparties.Form.GLAccountsEditForm",
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
		"GLAccountCustomerSettlements, CustomerAdvancesGLAccount, GLAccountVendorSettlements, VendorAdvancesGLAccount, Ref",
		CommandParameter.GLAccountCustomerSettlements, CommandParameter.CustomerAdvancesGLAccount, CommandParameter.GLAccountVendorSettlements, CommandParameter.VendorAdvancesGLAccount, CommandParameter.Ref);
		
	Return ParametersStructure;
	
EndFunction
