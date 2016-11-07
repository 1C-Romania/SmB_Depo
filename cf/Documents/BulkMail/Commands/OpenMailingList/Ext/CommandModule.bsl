
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Document.BulkMail.ListForm", , CommandExecuteParameters.Source, 
CommandExecuteParameters.Uniqueness, 
CommandExecuteParameters.Window, 
CommandExecuteParameters.URL);
	
EndProcedure
