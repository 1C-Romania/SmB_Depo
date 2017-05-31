&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonAtServer.UseMultiCompaniesMode() Then
		
		Items.List.ChildItems.Company.Visible	= False;
		
	EndIf;
	
EndProcedure

#Region FormEventHandlers

&AtClient
Procedure ListBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	Document = Item.CurrentData.Document; 
	
	If ValueIsFilled(Document) Then 	
		ShowValue(, Document);
	EndIf;

EndProcedure

#EndRegion
