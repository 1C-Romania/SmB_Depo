
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Information = Parameters.Information;
	Title = Parameters.Title;
	WithSubfolders = Parameters.WithSubfolders;
EndProcedure

#EndRegion
