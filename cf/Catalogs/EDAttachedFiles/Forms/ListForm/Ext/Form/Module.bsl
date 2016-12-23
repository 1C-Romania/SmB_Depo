
&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ElectronicDocumentsServiceClient.OpenEDForViewing(SelectedRow);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	ElectronicDocumentsServiceClient.OpenEDForViewing(Items.List.CurrentRow);
	
EndProcedure

















