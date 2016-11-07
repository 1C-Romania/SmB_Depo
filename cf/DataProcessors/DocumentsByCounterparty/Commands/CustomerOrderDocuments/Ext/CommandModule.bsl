
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)

	FormParameters = New Structure(
			"Filter, SettingKey, GenerateOnOpen",
			New Structure("Order", CommandParameter),
			"Order",
			True);
	
	OpenForm("DataProcessor.DocumentsByCounterparty.Form.CustomerOrderDocuments",
			FormParameters,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window);

EndProcedure
