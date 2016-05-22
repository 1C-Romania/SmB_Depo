
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	StandardSubsystemsClient.AuthorizeOnUserSupportSite(CommandExecuteParameters.Source);
	
EndProcedure
