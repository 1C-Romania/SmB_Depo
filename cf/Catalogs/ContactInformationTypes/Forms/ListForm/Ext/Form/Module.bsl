#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	// Check whether the group is being copied.
	If Copy AND Group Then
		Cancel = True;
		
		ShowMessageBox(, NStr("en='Adding of the new groups in the catalog has been completed.';ru='Добавление новых групп в справочнике запрещено.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure MoveItemUp()
	
	If Not ThereIsOptionItemMove(Items.List.CurrentData.Ref, "Up") Then
		CommonUseClientServer.MessageToUser(NStr("en=""Move this contact information type is n't provided"";ru='Перемещение данного вида контактной информации не предусмотрено'"));
		Return;
	EndIf;
	
	ItemOrderSetupClient.MoveItemUpExecute(List, Items.List);
	
EndProcedure

&AtClient
Procedure MoveItemDown()
	
	If Not ThereIsOptionItemMove(Items.List.CurrentData.Ref, "Down") Then
		CommonUseClientServer.MessageToUser(NStr("en='Move this contact information type is not provided';ru='Перемещение данного вида контактной информации не предусмотрено'"));
		Return;
	EndIf;
	
	ItemOrderSetupClient.MoveItemDownExecute(List, Items.List);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function ThereIsOptionItemMove(CurrentItem, Direction)
	
	NearbyItem = ItemOrderSetupService.NearbyItem(CurrentItem, List, Direction);
	
	Return NearbyItem = Undefined Or Not (CurrentItem.DisableEditByUser Or NearbyItem.DisableEditByUser);
	
EndFunction

#EndRegion




// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
