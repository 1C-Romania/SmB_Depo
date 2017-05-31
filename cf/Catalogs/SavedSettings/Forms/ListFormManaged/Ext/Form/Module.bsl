&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	FormsAtServer.CatalogFormOnCreateAtServer(ThisForm, Cancel, StandardProcessing);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FormsAtClient.CatalogListFormOnOpen(ThisForm, Cancel);
EndProcedure
