
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure("Owner", CommandParameter);
	FormParameters = New Structure("Filter", FilterStructure);
	
	OpenForm("Catalog.ContactPersons.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
