&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "CashAssets");
	Variant.Insert("VariantKey", "BalanceInCurrency");
	
	SmallBusinessReportsClient.OpenReportOption(Variant);
	
EndProcedure
