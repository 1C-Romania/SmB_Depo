
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPaneIIntegrationSB.Form.MobileApplicationSettings",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPaneIIntegrationSB.Form.MobileApplicationSettings" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
