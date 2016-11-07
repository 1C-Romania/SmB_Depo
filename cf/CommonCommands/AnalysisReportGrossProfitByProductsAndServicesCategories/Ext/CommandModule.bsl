&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "Sales");
	Variant.Insert("VariantKey", "GrossProfitByProductsAndServicesCategories");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
