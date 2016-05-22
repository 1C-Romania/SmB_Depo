
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CallParameters = New Structure("Source, Window");
	FillPropertyValues(CallParameters, CommandExecuteParameters);
	
	CallParameters.Insert("Uniqueness", "Panel_PayrollAndHumanResources");
	
	ReportsVariantsClient.ShowReportsPanel("PayrollAndHumanResources", CallParameters, NStr("en = 'Payroll and human resources reports'"));
	
EndProcedure
