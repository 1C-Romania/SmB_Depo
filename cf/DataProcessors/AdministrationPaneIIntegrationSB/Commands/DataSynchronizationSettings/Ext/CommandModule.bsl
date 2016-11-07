
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If SmallBusinessReUse.SettingsForSynchronizationSaaS() Then
		
		If StandardSubsystemsClientReUse.ClientWorkParameters().CanUseSeparatedData Then
			
			OpenForm(
				"DataProcessor.AdministrationPaneIIntegrationSB.Form.DataSynchronizationSettings",
				New Structure,
				CommandExecuteParameters.Source,
				"DataProcessor.AdministrationPaneIIntegrationSB.Form.DataSynchronizationSettings" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
				CommandExecuteParameters.Window);
				
		Else
			OpenForm(
				"DataProcessor.AdministrationPanelSSLSaaS.Form.DataSynchronizationForServiceAdministrator",
				New Structure,
				CommandExecuteParameters.Source,
				"DataProcessor.AdministrationPanelSSLSaaS.Form.DataSynchronizationForServiceAdministrator" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
				CommandExecuteParameters.Window);
			
		EndIf;
			
	Else
			
		OpenForm(
			"DataProcessor.AdministrationPaneIIntegrationSB.Form.DataSynchronizationSettings",
			New Structure,
			CommandExecuteParameters.Source,
			"DataProcessor.AdministrationPaneIIntegrationSB.Form.DataSynchronizationSettings" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
			CommandExecuteParameters.Window);
		
	EndIf;
	
EndProcedure

#EndRegion
