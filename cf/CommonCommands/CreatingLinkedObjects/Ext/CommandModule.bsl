
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	AdditionalReportsAndDataProcessorsClient.OpenFormOfCommandsOfAdditionalReportsAndDataProcessors(
		CommandParameter,
		CommandExecuteParameters,
		AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindCreatingRelatedObjects());
	
EndProcedure

#EndRegion
