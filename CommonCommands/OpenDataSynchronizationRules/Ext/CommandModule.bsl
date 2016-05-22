#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DataExchangeClient.ImportDataSynchronizationRules(ExchangePlanName(CommandParameter));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function ExchangePlanName(Val InfobaseNode)
	
	Return DataExchangereuse.GetExchangePlanName(InfobaseNode);
	
EndFunction

#EndRegion