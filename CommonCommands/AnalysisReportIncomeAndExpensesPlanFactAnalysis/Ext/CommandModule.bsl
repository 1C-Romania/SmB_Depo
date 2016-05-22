&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "IncomeAndExpensesForecast");
	Variant.Insert("VariantKey", "Planfact analysis");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
