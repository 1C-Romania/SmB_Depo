&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"Report.FixedAssets.Form",
		New Structure("PurposeUseKey, Filter, GenerateOnOpen, VariantKey", CommandParameter, New Structure("FixedAsset", CommandParameter), True, "Statement"),
		,
		"FixedAsset=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure // CommandProcessing()
