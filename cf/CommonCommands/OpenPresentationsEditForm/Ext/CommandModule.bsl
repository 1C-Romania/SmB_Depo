
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters) 	
	
	FormParameters = New Structure("CatalogRef", CommandParameter);
	OpenForm("CommonForm.PresentationsEditForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window, CommandExecuteParameters.URL);
	
EndProcedure
