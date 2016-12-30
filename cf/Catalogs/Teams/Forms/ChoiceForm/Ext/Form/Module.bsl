
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Form opening from job order (TS Performers).
	If Parameters.Property("MultiselectList") Then
		Items.List.Multiselect = True;
	EndIf;
	
EndProcedure

#EndRegion