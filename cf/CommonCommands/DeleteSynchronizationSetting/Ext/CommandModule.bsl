#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DataExchangeClient.DeleteSynchronizationSetting(CommandParameter);
	
EndProcedure

#EndRegion