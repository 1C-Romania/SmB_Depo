&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	DocumentsFormAtServer.OnCreateAtServer(ThisForm, Cancel, StandardProcessing);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	DocumentsFormAtClient.ListOnOpen(ThisForm, Cancel);
EndProcedure
