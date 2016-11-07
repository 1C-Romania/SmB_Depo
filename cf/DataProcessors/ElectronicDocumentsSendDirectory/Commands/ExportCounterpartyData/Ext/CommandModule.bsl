
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("Counterparty", CommandParameter);
	
	OpenForm("DataProcessor.ElectronicDocuments.Form.CounterpartyAttributesImport", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
