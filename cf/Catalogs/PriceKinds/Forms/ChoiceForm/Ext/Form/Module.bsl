////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF SAVING SETTINGS

&AtServer
// Procedure saves the selected item in settings.
//
Procedure SetMainItem(SelectedItem)
	
	If SelectedItem <> SmallBusinessReUse.GetValueOfSetting("MainPriceKindSales") Then
		SmallBusinessServer.SetUserSetting(SelectedItem, "MainPriceKindSales");	
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
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.List.ReadOnly = Not AllowedEditDocumentPrices;
	
	// Main item allocation.	
	SmallBusinessServer.MarkMainItemWithBold(SmallBusinessReUse.GetValueOfSetting("MainPriceKindSales"), List);
	
EndProcedure // OnCreateAtServer()
// 














