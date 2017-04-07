
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Form opening from job order (PM Performers).
	If Parameters.Property("MultiselectList") Then
		Items.List.Multiselect = True;
	EndIf;
	
EndProcedure

#EndRegion

