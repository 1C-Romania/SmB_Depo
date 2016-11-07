
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(InfobaseNode, CommandExecuteParameters)
	
	DataExchangeClient.GoToEventLogMonitorOfDataEvents(InfobaseNode, CommandExecuteParameters, "DataImport");
	
EndProcedure

#EndRegion
