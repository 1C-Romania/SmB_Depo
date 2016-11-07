
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FillStructure = New Structure();
	FillStructure.Insert("BasisDocumentSale", CommandParameter);
	OpenForm("Document.CustomerInvoice.ObjectForm", New Structure("Basis", FillStructure));

EndProcedure
