&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "Sales");
	Variant.Insert("VariantKey", "SalesDynamicsByProductsAndServicesCategories");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
