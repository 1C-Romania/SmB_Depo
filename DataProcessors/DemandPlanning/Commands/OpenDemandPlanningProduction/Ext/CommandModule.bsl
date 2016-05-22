
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("PurchasesOnly", False);
	OpenForm("DataProcessor.DemandPlanning.Form", FormParameters, CommandExecuteParameters.Source, "DemandPlanningProduction", CommandExecuteParameters.Window);
	
EndProcedure
