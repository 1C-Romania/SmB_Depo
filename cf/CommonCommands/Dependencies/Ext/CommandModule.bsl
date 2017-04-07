
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If ValueIsFilled(CommandParameter) Then
	
		OpenForm("CommonForm.Dependencies",New Structure("FilterObject", CommandParameter),
				CommandExecuteParameters.Source,
				CommandExecuteParameters.Source.UniqueKey,
				CommandExecuteParameters.Window);
	
	EndIf;
	
EndProcedure

#EndRegion
