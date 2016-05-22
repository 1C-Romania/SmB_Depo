
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DataExchangeClient.GoToEventLogMonitorOfDataEventsModalRegistartion(CommandParameter, CommandExecuteParameters.Source, "DataExport");
	
EndProcedure
