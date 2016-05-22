////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPanelPersonalSettings.Form.CurrentUser",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanelPersonalSettings.Form.CurrentUser" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window
	);
	
EndProcedure
