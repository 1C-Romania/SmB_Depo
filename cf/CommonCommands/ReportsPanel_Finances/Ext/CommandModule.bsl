
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CallParameters = New Structure("Source, Window");
	FillPropertyValues(CallParameters, CommandExecuteParameters);
	CallParameters.Insert("Uniqueness", "Panel_Banking");
	ReportsVariantsClient.ShowReportsPanel("Finances", CallParameters, NStr("en='Reports by finances';ru='Отчеты по денежным средствам'"));
	
EndProcedure
