////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

&AtClient
Procedure CommandProcessing(CommandParameter, ExecuteParameters)
	ReportsVariantsClient.ShowReportsPanel("SetupAndAdministration", ExecuteParameters);
EndProcedure
