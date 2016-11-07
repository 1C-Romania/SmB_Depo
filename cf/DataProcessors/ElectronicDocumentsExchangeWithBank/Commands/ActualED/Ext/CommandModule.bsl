
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ElectronicDocumentsClient.OpenActualED(CommandParameter, CommandExecuteParameters.Source, CommandExecuteParameters);
	
EndProcedure
