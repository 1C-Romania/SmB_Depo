
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)

	FormParameters = New Structure(
			"Filter, SettingKey, GenerateOnOpen",
			New Structure("Order", CommandParameter),
			"Order",
			True);
	
	OpenForm("DataProcessor.DocumentsByCounterparty.Form.SupplierInvoiceForPaymentDocuments",
			FormParameters,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window);

EndProcedure
