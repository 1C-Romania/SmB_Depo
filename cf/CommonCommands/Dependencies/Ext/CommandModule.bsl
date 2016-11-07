
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If ValueIsFilled(CommandParameter) Then
	
		OpenForm("CommonForm.DependenciesForm",New Structure("DocumentRef", CommandParameter),
				CommandExecuteParameters.Source,
				CommandExecuteParameters.Source.UniqueKey,
				CommandExecuteParameters.Window);
	
	EndIf;
	
EndProcedure

#EndRegion
