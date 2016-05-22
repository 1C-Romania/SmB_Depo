
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CallParameters = New Structure("Source, Window");
	FillPropertyValues(CallParameters, CommandExecuteParameters);
	CallParameters.Insert("Uniqueness", "Panel_MarketingAndSales");
	ReportsVariantsClient.ShowReportsPanel("MarketingAndSales", CallParameters, NStr("en = 'Sales reports'"));
	
EndProcedure
