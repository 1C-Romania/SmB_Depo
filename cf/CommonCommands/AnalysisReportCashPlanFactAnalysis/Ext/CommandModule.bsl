&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "CashAssetsForecast");
	Variant.Insert("VariantKey", "Planfact analysis (cur.)");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
