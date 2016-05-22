
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(OptionsArray, CommandExecuteParameters)
	ReportsVariantsClient.OpenUsersSettingsResetDialog(OptionsArray, CommandExecuteParameters.Source);
EndProcedure

#EndRegion
