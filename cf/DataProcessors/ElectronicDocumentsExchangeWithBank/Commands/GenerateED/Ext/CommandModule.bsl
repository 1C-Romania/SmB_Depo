
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Handler = New NotifyDescription("GenerateNewED", ElectronicDocumentsClient, True);
	ElectronicDocumentsClientOverridable.RunDocumentsPostingCheck(CommandParameter,
		Handler, CommandExecuteParameters.Source);
	
EndProcedure
