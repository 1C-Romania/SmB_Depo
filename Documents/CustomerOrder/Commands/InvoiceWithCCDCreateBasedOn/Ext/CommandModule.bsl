
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FillStructure = New Structure();
	FillStructure.Insert("FillCCDNumbers", True);
	FillStructure.Insert("FillDocument", CommandParameter);
	OpenForm("Document.CustomerInvoiceNote.ObjectForm", New Structure("Basis", FillStructure));
	
EndProcedure
