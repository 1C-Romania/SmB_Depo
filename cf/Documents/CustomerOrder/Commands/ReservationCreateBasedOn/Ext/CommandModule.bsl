
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Document.InventoryReservation.ObjectForm", New Structure("Basis", CommandParameter));
	
EndProcedure
