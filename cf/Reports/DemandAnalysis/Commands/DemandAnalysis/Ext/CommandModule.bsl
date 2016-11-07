&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Report.DemandAnalysis.Form",
		New Structure("UsePurposeKey, Filter, GenerateOnOpen", CommandParameter, New Structure("CustomerOrder", CommandParameter), True),
		,
		"CustomerOrder=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure // CommandProcessing()
