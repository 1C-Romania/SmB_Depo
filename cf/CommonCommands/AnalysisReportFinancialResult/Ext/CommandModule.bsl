&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "FinancialResult");
	Variant.Insert("VariantKey", "Statement");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
