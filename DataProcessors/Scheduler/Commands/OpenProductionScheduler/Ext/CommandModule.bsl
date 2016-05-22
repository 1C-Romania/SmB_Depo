
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("WorksOnly", False);
	OpenForm("DataProcessor.Scheduler.Form", FormParameters, CommandExecuteParameters.Source, "ProductionScheduler", CommandExecuteParameters.Window);
	
EndProcedure
