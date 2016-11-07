&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "MutualSettlements");
	Variant.Insert("VariantKey", "Statement in currency (briefly)");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
