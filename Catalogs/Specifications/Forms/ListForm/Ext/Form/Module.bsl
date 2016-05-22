
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Owner") Then
		
		ProductsAndServices = Parameters.Filter.Owner;
		
		UseSubsystemProduction = Constants.FunctionalOptionUseSubsystemProduction.Get();
		UseWorkSubsystem = Constants.FunctionalOptionUseWorkSubsystem.Get();
		
		If Not ValueIsFilled(ProductsAndServices)
			OR ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.WorkKind
			OR ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service
			OR ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Operation Then
			
			AutoTitle = False;
			If UseSubsystemProduction AND UseWorkSubsystem Then
				Title = NStr("en = 'Specifications are stored for inventory and work only'");
			ElsIf UseSubsystemProduction Then
				Title = NStr("en = 'Specifications are stored for inventory only'");
			Else
				Title = NStr("en = 'Specifications are stored for work only'");
			EndIf;
			Items.List.ReadOnly = True;
			
		ElsIf ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem AND Not UseSubsystemProduction Then
			
			AutoTitle = False;
			Title = NStr("en = 'Specifications are stored for work only'");
			Items.List.ReadOnly = True;
			
		ElsIf ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work AND Not UseWorkSubsystem Then
			
			AutoTitle = False;
			Title = NStr("en = 'Specifications are stored for inventory only'");
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
	
	KeyOperation = "FormCreatingSpecifications";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningSpecifications";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

#EndRegion