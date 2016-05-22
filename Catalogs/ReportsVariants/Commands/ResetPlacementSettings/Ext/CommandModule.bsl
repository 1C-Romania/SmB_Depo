
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(OptionsArray, CommandExecuteParameters)
	ReportsVariantsClient.OpenDirectoryPropertiesResetDialog(OptionsArray, CommandExecuteParameters.Source);
EndProcedure

#EndRegion
