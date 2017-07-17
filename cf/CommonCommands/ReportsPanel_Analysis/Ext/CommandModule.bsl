
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CallParameters = New Structure("Source, Window");
	FillPropertyValues(CallParameters, CommandExecuteParameters);
	CallParameters.Insert("Uniqueness", "Panel_Analysis");
	ReportsVariantsClient.ShowReportsPanel("Analysis", CallParameters, NStr("en='Analysis reports';ru='Отчеты для анализа'"));
	
EndProcedure
