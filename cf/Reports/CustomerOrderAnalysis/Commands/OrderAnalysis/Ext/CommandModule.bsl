&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Report.CustomerOrderAnalysis.Form",
		New Structure("VariantKey, PurposeUseKey, Order, GenerateOnOpen", "Default", CommandParameter, CommandParameter[0], True),
		,
		"CustomerOrder=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure // CommandProcessing()
