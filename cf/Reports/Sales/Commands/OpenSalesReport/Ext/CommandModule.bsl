
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructureKey = ?(TypeOf(CommandParameter) = Type("CatalogRef.ProductsAndServices"), "ProductsAndServices", "Counterparty");
	FilterStructure	= New Structure(FilterStructureKey, CommandParameter);
	
	FormParameters = New Structure("VariantKey, UsePurposeKey, Filter, GenerateOnOpen, ReportVariantsCommandsVisible", 
		"SalesContext",
		FilterStructureKey,
		FilterStructure, 
		True, 
		False);
	
	OpenForm("Report.Sales.Form",
		FormParameters,
		,
		CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure
