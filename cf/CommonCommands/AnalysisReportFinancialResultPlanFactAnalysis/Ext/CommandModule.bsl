&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "FinancialResultForecast");
	Variant.Insert("VariantKey", "Planfact analysis");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
