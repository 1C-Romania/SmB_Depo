
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Owner") Then
		
		ProductsAndServices = Parameters.Filter.Owner;
		
		If Not ValueIsFilled(ProductsAndServices)
			OR Not ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
			
			AutoTitle = False;
			Title = NStr("en='Batches are stored for inventories only';ru='Партии хранятся только для запасов'");
			
			Items.List.ReadOnly = True;
			
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure // OnCreateAtServer()

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingProductsAndServicesBatches";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningProductsAndServicesBatches";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

#EndRegion
