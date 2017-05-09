
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandExecuteParameters.Window = Undefined Then
		Source = Undefined;
		Uniqueness = "WorkOrder";
	Else
		Source = CommandExecuteParameters.Source;
		Uniqueness = CommandExecuteParameters.Uniqueness;
	EndIf;
	
	OpenForm("Document.CustomerOrder.ListForm", 
		New Structure("WorkOrder", True), 
		Source, 
		Uniqueness, 
		CommandExecuteParameters.Window
	);
	
EndProcedure // CommandProcessing()
