////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPanelSB.Form.FinanceSection",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanelSB.Form.FinanceSection" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window
	);
	
EndProcedure
