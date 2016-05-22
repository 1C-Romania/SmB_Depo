
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Handler = New NotifyDescription("GenerateSignSendED", ElectronicDocumentsClient);
	ElectronicDocumentsClientOverridable.RunDocumentsPostingCheck(CommandParameter,
		Handler, CommandExecuteParameters.Source);
	
EndProcedure
