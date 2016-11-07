
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
				Title = NStr("en='Specifications are stored for inventory and work only';ru='Спецификации хранятся только для запасов и работ'");
			ElsIf UseSubsystemProduction Then
				Title = NStr("en='Specifications are stored for inventory only';ru='Спецификации хранятся только для запасов'");
			Else
				Title = NStr("en='Specifications are stored for work only';ru='Спецификации хранятся только для работ'");
			EndIf;
			Items.List.ReadOnly = True;
			
		ElsIf ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem AND Not UseSubsystemProduction Then
			
			AutoTitle = False;
			Title = NStr("en='Specifications are stored for work only';ru='Спецификации хранятся только для работ'");
			Items.List.ReadOnly = True;
			
		ElsIf ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work AND Not UseWorkSubsystem Then
			
			AutoTitle = False;
			Title = NStr("en='Specifications are stored for inventory only';ru='Спецификации хранятся только для запасов'");
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


// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
