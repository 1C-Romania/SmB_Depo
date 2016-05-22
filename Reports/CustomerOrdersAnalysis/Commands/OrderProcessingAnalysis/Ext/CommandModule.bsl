&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Report.CustomerOrdersAnalysis.Form",
		New Structure("VariantKey, PurposeUseKey, Filter, GenerateOnOpen", "Default", CommandParameter, New Structure("CustomerOrder, FilterByOrders", CommandParameter, "NoFilter"), True),
		,
		"CustomerOrder=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure // CommandProcessing()
