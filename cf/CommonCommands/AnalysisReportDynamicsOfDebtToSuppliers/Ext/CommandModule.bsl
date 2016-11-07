&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "DynamicsOfDebtToSuppliers");
	Variant.Insert("VariantKey", "DebtDynamics");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
