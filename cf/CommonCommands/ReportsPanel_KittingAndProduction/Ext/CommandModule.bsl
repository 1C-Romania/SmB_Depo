﻿
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CallParameters = New Structure("Source, Window");
	FillPropertyValues(CallParameters, CommandExecuteParameters);
	
	CallParameters.Insert("Uniqueness", "Panel_KittingAndProduction");
	
	ReportsVariantsClient.ShowReportsPanel("KittingAndProduction", CallParameters, NStr("en='Manufacturing reports';ru='Отчеты по производству'"));
	
EndProcedure
