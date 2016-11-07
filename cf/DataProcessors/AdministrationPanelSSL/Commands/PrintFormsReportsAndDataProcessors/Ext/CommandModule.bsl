
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPanelSSL.Form.PrintFormsReportsAndDataProcessors",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanelSSL.Form.PrintFormsReportsAndDataProcessors" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
