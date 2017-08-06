
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	AdditionalReportsAndDataProcessorsClient.OpenFormOfCommandsOfAdditionalReportsAndDataProcessors(
			CommandParameter,
			CommandExecuteParameters,
			AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalReport(),
			"Finances");
	
EndProcedure
