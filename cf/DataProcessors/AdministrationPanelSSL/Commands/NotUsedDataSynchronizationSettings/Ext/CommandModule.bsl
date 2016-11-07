
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.AdministrationPanelSSL.Form.NotUsedDataSynchronizationSettings",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanelSSL.Form.NotUsedDataSynchronizationSettings" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
