////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF SAVING SETTINGS

&AtServer
// Procedure saves the selected item in settings.
//
Procedure SetMainItem(SelectedItem)
	
	If SelectedItem <> SmallBusinessReUse.GetValueOfSetting("MainResponsible") Then
		SmallBusinessServer.SetUserSetting(SelectedItem, "MainResponsible");	
		SmallBusinessServer.MarkMainItemWithBold(SelectedItem, List);
	EndIf; 
		
EndProcedure

&AtClient
// Procedure - Command execution handler SetMainItem.
//
Procedure CommandSetMainItem(Command)
		
	SelectedItem = Items.List.CurrentRow;
	If ValueIsFilled(SelectedItem) Then
		SetMainItem(SelectedItem);	
	EndIf; 
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Setting current row.
	If Parameters.Property("Responsible")
		AND ValueIsFilled(Parameters.Responsible) Then
		
		Items.List.CurrentRow = Parameters.Responsible;
		
	EndIf;
	
	// Main item allocation.
	SmallBusinessServer.MarkMainItemWithBold(SmallBusinessReUse.GetValueOfSetting("MainResponsible"), List);
	
EndProcedure // OnCreateAtServer()
// 














