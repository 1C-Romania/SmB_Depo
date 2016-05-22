&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "CashAssetsForecast");
	Variant.Insert("VariantKey", "InCurrency");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
