#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DataExchangeClient.OpenSentDataContent(CommandParameter);
	
EndProcedure

#EndRegion