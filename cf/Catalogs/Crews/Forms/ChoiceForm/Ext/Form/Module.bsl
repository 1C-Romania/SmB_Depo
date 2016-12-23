///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Form opening from job order (PM Performers).
	If Parameters.Property("MultiselectList") Then
		Items.List.Multiselect = True;
	EndIf;
	
EndProcedure // OnCreateAtServer()














