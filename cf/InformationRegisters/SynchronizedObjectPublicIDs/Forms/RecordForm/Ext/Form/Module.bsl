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













