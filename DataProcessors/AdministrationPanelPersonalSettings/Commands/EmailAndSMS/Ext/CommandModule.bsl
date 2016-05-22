////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPanelPersonalSettings.Form.EmailAndSMS",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanelPersonalSettings.Form.EmailAndSMS" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window
	);
	
EndProcedure
