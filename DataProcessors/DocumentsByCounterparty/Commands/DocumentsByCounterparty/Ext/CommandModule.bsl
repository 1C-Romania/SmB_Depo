
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)

	FormParameters = New Structure(
			"Filter, SettingKey, GenerateOnOpen",
			New Structure("Counterparty", CommandParameter),
			"Counterparty",
			True);
	
	OpenForm("DataProcessor.DocumentsByCounterparty.Form.DocumentsByCounterparty",
			FormParameters,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window);

EndProcedure
