
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandExecuteParameters.Window = Undefined Then
		Source = Undefined;
		Uniqueness = "JobOrder";
	Else
		Source = CommandExecuteParameters.Source;
		Uniqueness = CommandExecuteParameters.Uniqueness;
	EndIf;
	
	OpenForm("Document.CustomerOrder.ListForm", New Structure("JobOrder", True), Source, Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure // CommandProcessing()
