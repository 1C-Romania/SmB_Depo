
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CallParameters = New Structure("Source, Window");
	FillPropertyValues(CallParameters, CommandExecuteParameters);
	CallParameters.Insert("Uniqueness", "Panel_CRM");
	ReportsVariantsClient.ShowReportsPanel("CRM", CallParameters, NStr("en='CRM reports';ru='Отчеты по CRM'"));
	
EndProcedure
