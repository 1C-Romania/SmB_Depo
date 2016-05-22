
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ProductsAndServices") Then
		SmallBusinessClientServer.SetListFilterItem(List, "ProductsAndServices", Parameters.ProductsAndServices);
		If Parameters.ProductsAndServices.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.InventoryItem Then
			AutoTitle = False;
			Title = NStr("en = 'Barcode are stored for inventories'");
			Items.List.ReadOnly = True;
		EndIf;
	EndIf;
	
EndProcedure