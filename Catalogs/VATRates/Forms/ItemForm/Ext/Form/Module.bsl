////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CommonUseClientServer.SetFormItemProperty(Items, "Rate", "Visible", Not Object.NotTaxable);
	CommonUseClientServer.SetFormItemProperty(Items, "Calculated", "Visible", Not Object.NotTaxable);
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - event handler OnChange of the NotTaxable input fields.
//
Procedure NotTaxableOnChange(Item)
	
	If Object.NotTaxable Then
		
		Object.Rate		= 0;
		Object.Calculated	= False;
		
	EndIf;
	
	CommonUseClientServer.SetFormItemProperty(Items, "Rate", "Visible", Not Object.NotTaxable);
	CommonUseClientServer.SetFormItemProperty(Items, "Calculated", "Visible", Not Object.NotTaxable);
	
EndProcedure // NotTaxableOnChange()
