&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "CashAssets");
	Variant.Insert("VariantKey", "Analysis of movements in currency");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
