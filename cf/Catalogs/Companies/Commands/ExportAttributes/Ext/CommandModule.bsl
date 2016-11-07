
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("DataProcessor.ElectronicDocuments.Form.ExportCompanyAttributes",
		New Structure("Company",CommandParameter), CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
		
EndProcedure
