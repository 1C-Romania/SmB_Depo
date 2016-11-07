
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ParametersStructure = GetParametersStructure(CommandParameter);
	OpenForm(
		"Catalog.StructuralUnits.Form.GLAccountsEditForm",
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
		"GLAccountInRetail, MarkupGLAccount, Ref",
		CommandParameter.GLAccountInRetail, CommandParameter.MarkupGLAccount, CommandParameter.Ref);
		
	Return ParametersStructure;
	
EndFunction
