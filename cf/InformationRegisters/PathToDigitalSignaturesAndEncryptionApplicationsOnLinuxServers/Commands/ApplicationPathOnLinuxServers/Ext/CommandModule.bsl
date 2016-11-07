
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	// Insert handler content
	FormParameters = New Structure("Filter", New Structure("Application", CommandParameter));
	OpenForm("InformationRegister.PathToDigitalSignaturesAndEncryptionApplicationsOnLinuxServers.ListForm",
		FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window, CommandExecuteParameters.URL);
	
EndProcedure
