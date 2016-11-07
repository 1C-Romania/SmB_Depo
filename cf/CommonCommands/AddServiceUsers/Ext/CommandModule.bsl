
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	UserStructure = OpenForm("CommonForm.ServiceUsers", ,
		CommandExecuteParameters.Source);
	
EndProcedure

#EndRegion
