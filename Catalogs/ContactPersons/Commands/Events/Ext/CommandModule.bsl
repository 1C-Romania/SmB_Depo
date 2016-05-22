
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure;
	FilterStructure.Insert("ContactPerson", CommandParameter);
	
	FormParameters = New Structure("InformationPanel", FilterStructure);
	If CommandExecuteParameters.Window = Undefined Then
		FormParameters.Insert("OpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
	OpenForm("Document.Event.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
