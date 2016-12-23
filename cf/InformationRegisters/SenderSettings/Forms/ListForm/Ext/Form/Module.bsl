
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.Filter.Property("Recipient") Then
		Items.Recipient.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion














