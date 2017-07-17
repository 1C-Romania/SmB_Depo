
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("ProductsAndServices") Then
		
		ProductsAndServices = Parameters.Filter.ProductsAndServices;
		
		If ProductsAndServices.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.InventoryItem Then
			
			AutoTitle = False;
			Title = NStr("en='Counterparty prices can be entered only for products and services with the Inventory type';ru='Цены контрагентов можно вводить только для номенклатуры с типом Запас'");
			
			Items.List.ReadOnly = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure // OnCreateAtServer()
