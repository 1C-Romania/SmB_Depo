&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "IncomeAndExpenses");
	Variant.Insert("VariantKey", "Statement");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
