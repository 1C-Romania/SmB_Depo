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
