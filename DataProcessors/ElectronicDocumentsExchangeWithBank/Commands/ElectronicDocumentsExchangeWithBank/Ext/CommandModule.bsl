
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)

	OpenForm(
			"DataProcessor.ElectronicDocumentsExchangeWithBank.Form.ProcessingForm",
			,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window);

EndProcedure
