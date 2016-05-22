
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CallParameters = New Structure("Source, Window");
	FillPropertyValues(CallParameters, CommandExecuteParameters);
	CallParameters.Insert("Uniqueness", "Panel_Banking");
	ReportsVariantsClient.ShowReportsPanel("CashAssets", CallParameters, NStr("en = 'Reports by cash assets'"));
	
EndProcedure
