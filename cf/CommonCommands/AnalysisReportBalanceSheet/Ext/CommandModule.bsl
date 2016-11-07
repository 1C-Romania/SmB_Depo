&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "BalanceSheet");
	Variant.Insert("VariantKey", "Default");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
