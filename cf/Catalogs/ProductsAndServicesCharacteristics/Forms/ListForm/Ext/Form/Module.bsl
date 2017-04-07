
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Owner") Then
		
		OwnerObject = Parameters.Filter.Owner;
		
		If TypeOf(OwnerObject) = Type("CatalogRef.ProductsAndServices") Then
			
			If Not ValueIsFilled(OwnerObject)
				OR Not OwnerObject.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem
				AND Not OwnerObject.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service
				AND Not OwnerObject.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work Then
				
				AutoTitle = False;
				Title = NStr("en='Characteristics are stored only for inventory, services and work';ru='Характеристики хранятся только для запасов, услуг и работ'");
				
				Items.List.ReadOnly = True;
				
			EndIf;
			
			SetOfAdditAttributes = OwnerObject.ProductsAndServicesCategory.SetOfCharacteristicProperties;
			
		ElsIf TypeOf(OwnerObject) = Type("CatalogRef.ProductsAndServicesCategories") Then
			
			SetOfAdditAttributes = OwnerObject.SetOfCharacteristicProperties;
			
		Else
			
			Items.ChangeSetOfAdditionalAttributesAndInformation.Visible = False;
			
		EndIf;
		
	Else
		
		Items.ChangeSetOfAdditionalAttributesAndInformation.Visible = False;
		
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure - event handler Execute Commands ChangeSetOfAdditionalAttributesAndInformation.
//
Procedure ChangeSetOfAdditionalAttributesAndInformation(Command)
	
	If ValueIsFilled(SetOfAdditAttributes) Then
		ParametersOfFormOfPropertiesSet = New Structure("Key", SetOfAdditAttributes);
		OpenForm("Catalog.AdditionalAttributesAndInformationSets.Form.ItemForm", ParametersOfFormOfPropertiesSet);
	Else
		ShowMessageBox(Undefined,NStr("en='You can not receive the set of object properties. Perhaps, the necessary attributes are not filled.';ru='Нельзя получить набор свойств объекта. Возможно не заполнены необходимые реквизиты.'"));
	EndIf;
	
EndProcedure // ChangeSetOfAdditionalAttributesAndInformation()

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingProductsAndServicesCharacteristics";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningProductsAndServicesCharacteristics";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

#EndRegion
