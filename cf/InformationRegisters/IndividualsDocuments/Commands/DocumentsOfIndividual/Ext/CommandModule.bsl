&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("Filter", New Structure("Ind", CommandParameter));
	OpenForm("InformationRegister.IndividualsDocuments.Form.DocumentsOfIndividual", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
