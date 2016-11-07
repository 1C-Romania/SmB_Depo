
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FillStructure = New Structure();
	FillStructure.Insert("FillDocument", CommandParameter);
	FillStructure.Insert("RemoveReser", True);
	
	OpenForm("Document.InventoryReservation.ObjectForm", New Structure("Basis", FillStructure));
	
EndProcedure
