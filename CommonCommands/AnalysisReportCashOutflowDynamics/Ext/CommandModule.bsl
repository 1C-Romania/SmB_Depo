&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "CashAssets");
	Variant.Insert("VariantKey", "CashExpenseDynamics");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
