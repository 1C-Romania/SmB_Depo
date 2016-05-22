
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandExecuteParameters.Window = Undefined Then
		Source = Undefined;
		Uniqueness = "CustomerOrder";
	Else
		Source = CommandExecuteParameters.Source;
		Uniqueness = CommandExecuteParameters.Uniqueness;
	EndIf;
	
	OpenForm("Document.CustomerOrder.ListForm", , Source, Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure // CommandProcessing()
