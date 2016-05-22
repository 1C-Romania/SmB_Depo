
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FillStructure = New Structure();
	FillStructure.Insert("BasisDocumentReturn", CommandParameter);
	OpenForm("Document.CustomerInvoice.ObjectForm", New Structure("Basis", FillStructure));
	
EndProcedure
