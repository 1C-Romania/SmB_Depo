
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	PrintManagerName = "Catalog.EDAttachedFiles";
	PrintParameters = New Structure;
	
	If TypeOf(CommandParameter) = Type("DocumentRef.RandomED") Then
		TemplateName = "EDCard";
		PrintParameters.Insert("ID", "EDCard");
		
	ElsIf ElectronicDocumentsServiceCallServer.ThisIsServiceDocument(CommandParameter) Then
		TemplateName = "ED";
		PrintParameters.Insert("ID", "ED");
		
	Else
		TemplateName = "ED,EDCard";
		PrintParameters.Insert("ID", "ED,EDCard");
		
	EndIf;
	
	PrintParameters.Insert("FormTitle", "Printing electronic document");
	PrintParameters.Insert("Presentation", NStr("en = 'Printing electronic document'"));
	
	PrintManagementClient.ExecutePrintCommand(PrintManagerName, TemplateName, CommandParameter, ,PrintParameters);
	
EndProcedure
