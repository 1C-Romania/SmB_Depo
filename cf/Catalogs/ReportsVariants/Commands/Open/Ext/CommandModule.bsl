
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	ReportsVariantsClient.OpenReportOption(CommandExecuteParameters.Source);
EndProcedure

#EndRegion
