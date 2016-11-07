
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPaneIIntegrationSB.Form.ExchangeWithSitesSettings",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPaneIIntegrationSB.Form.ExchangeWithSitesSettings" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
