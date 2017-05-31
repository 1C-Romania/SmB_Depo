
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DataExchangeClient.OpenObjectMappingAssistantCommandProcessing(CommandParameter, CommandExecuteParameters.Source);
	
EndProcedure

#EndRegion
