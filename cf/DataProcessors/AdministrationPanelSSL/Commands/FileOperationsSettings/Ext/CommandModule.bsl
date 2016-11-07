
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	RunMode = ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	NameDataProcessorForm = ?(RunMode.SaaS AND RunMode.ThisIsSystemAdministrator, 
		"DataProcessor.AdministrationPanelSSL.Form.FileOperationsSettingsServiceAdministrator",
		"DataProcessor.AdministrationPanelSSL.Form.FileOperationsSettings");
	
	OpenForm(NameDataProcessorForm, , CommandExecuteParameters.Source, NameDataProcessorForm + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""), CommandExecuteParameters.Window);
	
EndProcedure

Function ApplicationRunningMode()
	
	Return CommonUseReUse.ApplicationRunningMode();
	
EndFunction

#EndRegion
