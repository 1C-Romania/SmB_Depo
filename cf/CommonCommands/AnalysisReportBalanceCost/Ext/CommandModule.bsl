&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "Inventory");
	Variant.Insert("VariantKey", "Balance");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
