&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "Sales");
	Variant.Insert("VariantKey", "GrossProfitByManagers");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
