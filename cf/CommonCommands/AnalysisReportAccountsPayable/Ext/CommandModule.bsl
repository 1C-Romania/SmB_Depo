&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "AccountsPayable");
	Variant.Insert("VariantKey", "Statement");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
