
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("PurchasesOnly", True);
	OpenForm("DataProcessor.DemandPlanning.Form", FormParameters, CommandExecuteParameters.Source, "DemandPlanningPurchasing", CommandExecuteParameters.Window);
	
EndProcedure
