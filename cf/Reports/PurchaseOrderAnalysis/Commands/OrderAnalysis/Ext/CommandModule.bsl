&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Report.PurchaseOrderAnalysis.Form",
		New Structure("VariantKey, PurposeUseKey, Order, GenerateOnOpen", "Default", CommandParameter, CommandParameter[0], True),
		,
		"PurchaseOrder=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure // CommandProcessing()
