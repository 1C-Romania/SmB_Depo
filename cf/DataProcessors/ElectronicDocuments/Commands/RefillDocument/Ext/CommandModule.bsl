
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ElectronicDocumentsClient.RefillDocument(CommandParameter, CommandExecuteParameters.Source);
	
EndProcedure
