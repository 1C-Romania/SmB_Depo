&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "AccountsReceivableDynamics");
	Variant.Insert("VariantKey", "DebtDynamics");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
