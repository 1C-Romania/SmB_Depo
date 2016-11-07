////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPanelPersonalSettings.Form.FilesProcessingInterface",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanelPersonalSettings.Form.FilesProcessingInterface" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window
	);
	
EndProcedure
