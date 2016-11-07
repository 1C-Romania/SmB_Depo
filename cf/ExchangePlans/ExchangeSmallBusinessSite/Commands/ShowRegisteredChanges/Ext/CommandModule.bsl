
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("ExchangeNode", CommandParameter);
	OpenForm("ExchangePlan.ExchangeSmallBusinessSite.Form.InformationAboutRegisteredChangesForm",
		FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure



