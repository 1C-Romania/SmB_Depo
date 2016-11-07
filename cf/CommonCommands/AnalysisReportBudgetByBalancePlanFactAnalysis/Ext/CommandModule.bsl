&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "BalanceEstimation");
	Variant.Insert("VariantKey", "Planfact analysis");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
