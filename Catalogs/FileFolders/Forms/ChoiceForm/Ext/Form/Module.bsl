
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.Property("CurrentFolder") Then
		Items.List.CurrentRow = Parameters.CurrentFolder;
	EndIf;
	
EndProcedure

#EndRegion
