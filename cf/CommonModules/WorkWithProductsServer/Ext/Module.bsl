
#Region WorkWithTabularSectionProducts

Procedure FillDataInTabularSectionRow(Object, TabularSectionName, TabularSectionRow) Export
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	If WorkWithProductsClientServer.IsObjectAttribute("Characteristic", TabularSectionRow) Then
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	EndIf;
	StructureData.Insert("ProcessingDate", CurrentDate());
	If WorkWithProductsClientServer.IsObjectAttribute("Factor", TabularSectionRow) 
		And WorkWithProductsClientServer.IsObjectAttribute("Multiplicity", TabularSectionRow) 
		Then
		StructureData.Insert("TimeNorm", 1);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("VATTaxation", Object) Then
		StructureData.Insert("VATTaxation", Object.VATTaxation);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("DocumentCurrency", Object) Then
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("AmountIncludesVAT", Object) Then
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("PriceKind", Object) And ValueIsFilled(Object.PriceKind) Then
		StructureData.Insert("PriceKind", Object.PriceKind);
	EndIf; 
	If WorkWithProductsClientServer.IsObjectAttribute("CounterpartyPriceKind", Object) And ValueIsFilled(Object.CounterpartyPriceKind) Then
		StructureData.Insert("CounterpartyPriceKind", Object.CounterpartyPriceKind);
	EndIf; 
	If WorkWithProductsClientServer.IsObjectAttribute("MeasurementUnit", Object) And TypeOf(TabularSectionRow.MeasurementUnit)=Type("CatalogRef.UOM") Then
		StructureData.Insert("Factor", TabularSectionRow.MeasurementUnit.Factor);
	Else
		StructureData.Insert("Factor", 1);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("WorkKind", Object) And ValueIsFilled(Object.WorkKind) Then
		StructureData.Insert("WorkKind", Object.WorkKind);
	EndIf; 
	
	UseDiscounts = WorkWithProductsClientServer.IsObjectAttribute("DiscountMarkupKind", Object);
	If UseDiscounts And ValueIsFilled(Object.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	EndIf; 
	If WorkWithProductsClientServer.IsObjectAttribute("DiscountCard", Object) And ValueIsFilled(Object.DiscountCard) Then
		StructureData.Insert("DiscountCard", Object.DiscountCard);
		StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);		
	EndIf; 

	RowFillingData = GetProductDataOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, RowFillingData);
	
	If WorkWithProductsClientServer.IsObjectAttribute("Quantity", TabularSectionRow) Then
		
		If TabularSectionName = "Works" Then
			
			TabularSectionRow.Quantity = StructureData.TimeNorm;
			
			If Not ValueIsFilled(TabularSectionRow.Multiplicity) Then
				TabularSectionRow.Multiplicity = 1;
			EndIf;
			If Not ValueIsFilled(TabularSectionRow.Factor) Then
				TabularSectionRow.Factor = 1;
			EndIf;
			
			TabularSectionRow.ProductsAndServicesTypeService = StructureData.IsService;
			
		ElsIf TabularSectionName = "Inventory" Then
			
			If WorkWithProductsClientServer.IsObjectAttribute("ProductsAndServicesTypeInventory", Object) Then
				TabularSectionRow.ProductsAndServicesTypeInventory = StructureData.IsInventory;
			EndIf;
			
			If Not ValueIsFilled(TabularSectionRow.MeasurementUnit) Then
				TabularSectionRow.MeasurementUnit = StructureData.BaseMeasurementUnit;
			EndIf;
			
		ElsIf TabularSectionName = "ConsumerMaterials" Then
			
			If Not ValueIsFilled(TabularSectionRow.MeasurementUnit) Then
				TabularSectionRow.MeasurementUnit = StructureData.BaseMeasurementUnit;
			EndIf;
			
		EndIf;
		
		WorkWithProductsClientServer.CalculateAmountInTabularSectionRow(Object, TabularSectionRow, TabularSectionName = "Inventory");
		
	EndIf;
		
EndProcedure

Function GetProductDataOnChange(StructureData)
	
	StructureData.Insert("BaseMeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	StructureData.Insert("IsService", StructureData.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.Service"));
	StructureData.Insert("IsInventory", StructureData.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem"));
	
	If StructureData.Property("TimeNorm") Then
		StructureData.TimeNorm = SmallBusinessServer.GetWorkTimeRate(StructureData);
	EndIf;
	
	If StructureData.Property("VATTaxation")
		And Not StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT") Then
		
		If StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotTaxableByVAT") Then
			StructureData.Insert("VATRate", SmallBusinessReUse.GetVATRateWithoutVAT());
		Else
			StructureData.Insert("VATRate", SmallBusinessReUse.GetVATRateZero());
		EndIf;
		
	ElsIf ValueIsFilled(StructureData.ProductsAndServices.VATRate) Then
		StructureData.Insert("VATRate", StructureData.ProductsAndServices.VATRate);
	Else
		StructureData.Insert("VATRate", StructureData.Company.DefaultVATRate);
	EndIf;
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices));
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		
		If Not StructureData.Property("Characteristic") Then
			StructureData.Insert("Characteristic", Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
		EndIf;
		If Not StructureData.Property("DocumentCurrency") And ValueIsFilled(StructureData.PriceKind) Then
			StructureData.Insert("DocumentCurrency", StructureData.PriceKind.PriceCurrency);
		EndIf;
		
		If StructureData.Property("WorkKind") Then
		
			CurProduct = StructureData.ProductsAndServices;
			StructureData.ProductsAndServices = StructureData.WorkKind;
			StructureData.Characteristic = Catalogs.ProductsAndServicesCharacteristics.EmptyRef();
			Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
			StructureData.Insert("Price", Price);
			
			StructureData.ProductsAndServices = CurProduct;
		
		Else
			
			Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
			StructureData.Insert("Price", Price);
			
		EndIf;
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	If StructureData.Property("DiscountMarkupKind")
		And ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", StructureData.DiscountMarkupKind.Percent);
	Else
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
	
	If StructureData.Property("DiscountPercentByDiscountCard") 
		And ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
	EndIf;
	
	Return StructureData;
	
EndFunction // GetProductDataOnChange()

#EndRegion