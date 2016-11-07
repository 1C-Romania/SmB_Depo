&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "FinancialResultForecast");
	Variant.Insert("VariantKey", "Default");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
