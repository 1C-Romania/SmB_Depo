
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("WorksOnly", True);
	OpenForm("DataProcessor.Scheduler.Form", FormParameters, CommandExecuteParameters.Source, "WorkScheduler", CommandExecuteParameters.Window);
	
EndProcedure
