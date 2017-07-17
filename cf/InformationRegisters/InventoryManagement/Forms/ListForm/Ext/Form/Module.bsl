////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("ProductsAndServices") Then
		
		ProductsAndServices = Parameters.Filter.ProductsAndServices;
		
		If Not ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
			
			AutoTitle = False;
			Title = NStr("en='Inventory management is used only for inventories';ru='Управление запасами используется только для запасов'");
			
			Items.List.ReadOnly = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure // OnCreateAtServer()
