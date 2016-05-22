#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	IntegrationWith1CBuhphoneClient.Run1CBuhphone();
EndProcedure

#EndRegion
