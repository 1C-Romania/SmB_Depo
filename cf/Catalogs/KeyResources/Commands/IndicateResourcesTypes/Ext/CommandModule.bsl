
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	Filter = New Structure("EnterpriseResource", CommandParameter);
	FormParameters = New Structure("Filter", Filter);
	OpenForm("InformationRegister.EnterpriseResourcesKinds.Form.FormForResources", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
EndProcedure
