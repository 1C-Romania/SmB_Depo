
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure;
	FilterStructure.Insert("BasisOrderAccounts", CommandParameter);
	
	FormParameters = New Structure("InformationPanel", FilterStructure);
	
	OpenForm("Document.Event.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
