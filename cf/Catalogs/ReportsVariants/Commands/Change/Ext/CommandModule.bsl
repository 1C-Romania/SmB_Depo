
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(VariantRef, CommandExecuteParameters)
	ReportsVariantsClient.ShowReportSettings(VariantRef);
EndProcedure

#EndRegion
