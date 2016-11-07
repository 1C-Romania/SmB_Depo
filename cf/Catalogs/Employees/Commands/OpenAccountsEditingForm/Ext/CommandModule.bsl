
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ParametersStructure = GetParametersStructure(CommandParameter);
	OpenForm(
		"Catalog.Employees.Form.GLAccountsEditForm",
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
		"SettlementsHumanResourcesGLAccount, AdvanceHoldersGLAccount, OverrunGLAccount, Ref",
		CommandParameter.SettlementsHumanResourcesGLAccount, CommandParameter.AdvanceHoldersGLAccount, CommandParameter.OverrunGLAccount, CommandParameter.Ref);
		
	Return ParametersStructure;
	
EndFunction
