
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("DataImportingProhibitionDates", True);
	OpenForm("InformationRegister.ChangeProhibitionDates.Form.ChangeProhibitionDates", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
