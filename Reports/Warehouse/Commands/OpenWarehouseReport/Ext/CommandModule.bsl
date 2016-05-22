
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("VariantKey, UsePurposeKey, Filter, GenerateAtOpen, ReportVariantCommandVisible", 
		"Statement",
		CommandParameter,
		New Structure("ProductsAndServices", CommandParameter), 
		True, 
		False);
	
	OpenForm("Report.Warehouse.Form",
		FormParameters,
		,
		"ProductsAndServices=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure
