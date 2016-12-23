////////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF ITEMS ORDER SETTING SUBSYSTEM

&AtClient
Procedure MoveItemUp(Command)
	
	ItemOrderSetupClient.MoveItemUpExecute(List, Items.List);
	
EndProcedure

&AtClient
Procedure MoveItemDown(Command)
	
	ItemOrderSetupClient.MoveItemDownExecute(List, Items.List);
	
EndProcedure














