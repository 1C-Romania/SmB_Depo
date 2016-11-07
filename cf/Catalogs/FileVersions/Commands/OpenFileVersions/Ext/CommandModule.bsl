
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("File", CommandParameter);
	FormParameters.Insert("FileCardUUID",
		CommandExecuteParameters.Source.UUID);
	
	OpenForm(
		"Catalog.FileVersions.Form.FileVersions",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure
