#Region FormEventsHandlers

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	NewUUID = New UUID(IdentifierString);
	If Record.ID <> NewUUID Then
		Record.ID = NewUUID;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	IdentifierString = Record.ID;
	
EndProcedure

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
