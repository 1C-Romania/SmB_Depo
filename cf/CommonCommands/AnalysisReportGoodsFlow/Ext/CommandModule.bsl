&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "Warehouse");
	Variant.Insert("VariantKey", "Statement");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
