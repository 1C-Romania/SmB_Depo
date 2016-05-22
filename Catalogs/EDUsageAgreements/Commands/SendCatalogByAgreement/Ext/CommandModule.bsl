&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	AdditParameters = New Structure("AgreementAboutEDUsage", CommandParameter);
	NotifyDescription = New NotifyDescription(
		"GenerateSignSendDirectoryComplete", ElectronicDocumentsServiceClient, AdditParameters);
	ElectronicDocumentsClientOverridable.OpenProductSelectionForm(CommandExecuteParameters.Source.UUID,
		NotifyDescription);
	
EndProcedure