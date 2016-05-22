////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPanelED.Form.ElectronicDocumentsExchange",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanelED.Form.ElectronicDocumentsExchange" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window
	);
	
EndProcedure
