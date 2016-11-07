////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPanelSB.Form.PurchaseSection",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanelSB.Form.PurchaseSection" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window
	);
	
EndProcedure
