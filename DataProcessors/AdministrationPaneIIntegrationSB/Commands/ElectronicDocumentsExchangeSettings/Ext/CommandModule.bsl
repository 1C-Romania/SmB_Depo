
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPaneIIntegrationSB.Form.ElectronicDocumentsExchange",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPaneIIntegrationSB.Form.ElectronicDocumentsExchange" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window
	);
	
EndProcedure

#EndRegion
