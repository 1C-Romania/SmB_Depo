&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "Sales");
	Variant.Insert("VariantKey", "GrossProfit");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
