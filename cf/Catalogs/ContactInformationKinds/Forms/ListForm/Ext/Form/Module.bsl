
#Region FormHeaderItemEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	// Checking if group is being cloned
	If Copy AND Group Then
		Cancel = True;
		
		ShowMessageBox(, NStr("en='Adding new groups to the catalog is prohibited.';ru='Добавление новых групп в справочнике запрещено.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure MoveItemUp()
	
	ItemOrderSetupClient.MoveItemUpExecute(List, Items.List);
	
EndProcedure

&AtClient
Procedure MoveItemDown()
	
	ItemOrderSetupClient.MoveItemDownExecute(List, Items.List);
	
EndProcedure

#EndRegion
