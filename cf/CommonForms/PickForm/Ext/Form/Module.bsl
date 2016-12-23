&AtClient
Var FilterByDescription;

//////////////////////////////////////////////////////////////////////////////// 
// OVERALL PROCEDURES AND FUNCTIONS 

&AtClient
Procedure ChangeAddRowToCart(ProductsListRow, RowCharacteristicsOfBatches, StringCart, Quantity, Price, AvailableBalance, UnitDimensions = Undefined)
	
	If StringCart = Undefined Then
		
		FilterStructure = New Structure;
		FilterStructure.Insert("ProductsAndServices", 	ProductsListRow.ProductsAndServices);
		
		If Not RowCharacteristicsOfBatches = Undefined Then
			
			If ProductsListRow.UseCharacteristics Then
				
				FilterStructure.Insert("Characteristic", 	RowCharacteristicsOfBatches.CharacteristicRef);
				
			EndIf;
			
			If ProductsListRow.UseBatches Then
				
				FilterStructure.Insert("Batch", RowCharacteristicsOfBatches.BatchRef);
				
			EndIf;
			
		EndIf;
		
		If RequestQuantity Then
			
			FilterStructure.Insert("Price", Price);
			
		EndIf;
		
		Rows = FilteredInventory.FindRows(FilterStructure);
		
	EndIf;
	
	If Rows.Count() > 0 Then
		
		Rows[0].MeasurementUnit		= ?(ValueIsFilled(UnitDimensions), UnitDimensions, Rows[0].MeasurementUnit);
		
		Rows[0].Quantity 			= Rows[0].Quantity + Quantity;
		
		If FillReserve
			AND Rows[0].Property("Reserve") Then
			
			Rows[0].Reserve				= min(Rows[0].Quantity, AvailableBalance); 
			
		EndIf;
		
		Items.FilteredInventory.CurrentRow = Rows[0].GetID();
		
	Else
		
		NewRow 					= FilteredInventory.Add();
		NewRow.ProductsAndServices 		= ProductsListRow.ProductsAndServices;
		NewRow.MeasurementUnit 	= ?(ValueIsFilled(UnitDimensions), UnitDimensions, ProductsListRow.MeasurementUnit);
		NewRow.Quantity 			= Quantity;
		
		If FillReserve
			AND NewRow.Property("Reserve") Then
			
			NewRow.Reserve				= min(NewRow.Quantity, AvailableBalance); 
			
		EndIf;
		
		// VAT rate
		DataStructure = New Structure();
		DataStructure.Insert("ProcessingDate", 	Period);
		DataStructure.Insert("Company", 	Company);
		DataStructure.Insert("ProductsAndServices", 	NewRow.ProductsAndServices);
		DataStructure.Insert("Characteristic", 	NewRow.Characteristic);
		DataStructure.Insert("VATTaxation", VATTaxation);
		DataStructure.Insert("AmountIncludesVAT", AmountIncludesVAT);
		DataStructure.Insert("AccrualVATRate", AccrualVATRate);
		DataStructure.Insert("DiscountMarkupKind", DiscountMarkupKind);
		DataStructure.Insert("Factor", 	1);
		
		ProductsAndServicesData 		= GetDataProductsAndServicesOnChange(DataStructure);
		NewRow.VATRate 	= ProductsAndServicesData.VATRate;
		
		// Price
		ProvisionalPrice = 0;
		If (AmountIncludesVAT = PriceIncludesVAT) 
			OR RequestQuantity Then
			
			ProvisionalPrice = Price;
			
		Else
			
			ProvisionalPrice = ?(AmountIncludesVAT,
							(Price * (100 + SmallBusinessReUse.GetVATRateValue(NewRow.VATRate))) / 100,
							(Price * 100) / (100 + SmallBusinessReUse.GetVATRateValue(NewRow.VATRate)));
							
			ProvisionalPrice = RoundPrice(ProvisionalPrice, PriceKindsRoundingOrder, PriceKindsRoundUp);
			
		EndIf;
		
		// If the document currency and prices kind currency are different, then recalculation is required
		NewRow.Price = ?(Currency = PriceKindCurrency,
			ProvisionalPrice,
			SmallBusinessServer.RecalculateFromCurrencyToCurrency(ProvisionalPrice, RatePriceKindCurrency, RateDocumentCurrency, CurrencyMultiplicityPriceKind, RepetitionDocumentCurrency)
			);
		
		If DiscountsMarkupsUsed Then
			
			NewRow.DiscountMarkupPercent = ProductsAndServicesData.DiscountMarkupPercent;
			
		EndIf;
		
		// DiscountCards
		If DiscountCardsAreUsed Then
			
			NewRow.DiscountMarkupPercent = NewRow.DiscountMarkupPercent + DiscountPercentByDiscountCard;
			
		EndIf;
		// End DiscountCards
		
		If Not RowCharacteristicsOfBatches = Undefined Then
			
			If ProductsListRow.UseCharacteristics Then
				NewRow.Characteristic 		= RowCharacteristicsOfBatches.CharacteristicRef;
			EndIf;
			
			If ProductsListRow.UseBatches Then
				NewRow.Batch 				= RowCharacteristicsOfBatches.BatchRef;
			EndIf;
			
		EndIf;
		
		Items.FilteredInventory.CurrentRow = NewRow.GetID();
		
	EndIf;
	
	CalculateAmountInTabularSectionLine();

EndProcedure

&AtClient
// Forms the selection data structure from form attributes
//
Function GenerateDataStructureOfCurrentFilterSession()
	
	CurrentRowOfFilteredInventory = Items.FilteredInventory.CurrentData;
	
	DataStructure = New Structure();
	DataStructure.Insert("ProcessingDate", 	Period);
	DataStructure.Insert("Company", 	Company);
	DataStructure.Insert("VATTaxation",VATTaxation);
	DataStructure.Insert("AmountIncludesVAT",AmountIncludesVAT);
	DataStructure.Insert("AccrualVATRate", AccrualVATRate);
	DataStructure.Insert("Factor", 	1);
	DataStructure.Insert("DocumentCurrency", Currency);
	
	DataStructure.Insert("ProductsAndServices", 	CurrentRowOfFilteredInventory.ProductsAndServices);
	DataStructure.Insert("Characteristic",	CurrentRowOfFilteredInventory.Characteristic);
	
	If PricesUsed Then
		
		DataStructure.Insert("PriceKind", PriceKind);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction // GetCurrentSelectionSessionDataStructure()

&AtClient
// Rounds a number according to a specified order.
//
// Parameters:
//  Number        - Number required
//  to be rounded RoundingOrder - Enums.RoundingMethods - round
//  order RoundUpward - Boolean - rounding upward.
//
// Returns:
//  Number        - rounding result.
//
Function RoundPrice(Number, RoundRule, RoundUp)
	
	Var Result; // Returned result.
	
	// Transform order of numbers rounding.
	// If null order value is passed, then round to cents. 
	If Not ValueIsFilled(RoundRule) Then
		
		RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round0_01");
	Else
		
		RoundingOrder = RoundRule;
		
	EndIf;
	
	Order = Number(String(RoundingOrder));
	
	// calculate quantity of intervals included in number
	QuantityInterval	= Number / Order;
	
	// calculate an integer quantity of intervals.
	NumberOfEntireIntervals = Int(QuantityInterval);
	
	If QuantityInterval = NumberOfEntireIntervals Then
		
		// Numbers are divided integrally. No need to round.
		Result	= Number;
		
	Else
		
		If RoundUp Then
			
			// During 0.05 rounding 0.371 must be rounded to 0.4
			Result = Order * (NumberOfEntireIntervals + 1);
			
		Else
			
			// During 0.05 rounding 0.371 must be rounded to
			// 0.35 and 0.376 to 0.4
			Result = Order * Round(QuantityInterval, 0, RoundMode.Round15as20);
			
		EndIf; 
		
	EndIf;
	
	Return Result;
	
EndFunction // RoundPrice()

&AtServer
// Converts a data set with the ValuesList type into Array
// 
Function ValueListIntoArray(IncValueList)
	
	ArrayOfData	= New Array;
	
	For Each ValueListItem IN IncValueList Do
		
		ArrayOfData.Add(ValueListItem.Value);
		
	EndDo;
	
	Return ArrayOfData;
	
EndFunction // ValuesListIntoArray()

// Procedure fills in the form opening parameters with default values
//
//
&AtServer
Procedure FillGenerateFormOpeningParametersWithValuesByDefault(StructureOfParametersByDefault, Parameters)
	
	User = Users.CurrentUser();
	
	StructureOfParametersByDefault.Insert("Period", CurrentDate());
	
	// Company
	ValueForParameterCompany = SmallBusinessReUse.GetValueByDefaultUser(User, "MainCompany");
	If Not ValueIsFilled(ValueForParameterCompany) Then
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED
		|	Companies.Ref AS Company,
		|	CASE
		|		WHEN Companies.Predefined
		|			THEN 0
		|		ELSE 1
		|	END AS Order
		|FROM
		|	Catalog.Companies AS Companies
		|
		|ORDER BY
		|	Order";
		
		Selection = Query.Execute().Select();
		
		While Not ValueIsFilled(ValueForParameterCompany) Do
			
			Selection.Next();
			ValueForParameterCompany = Selection.Company;
			
		EndDo;
		
	EndIf;
	
	StructureOfParametersByDefault.Insert("DocumentOrganization",	ValueForParameterCompany);
	StructureOfParametersByDefault.Insert("Company", 
		?(Constants.AccountingBySubsidiaryCompany.Get(), Constants.SubsidiaryCompany.Get(), ValueForParameterCompany));
	
	//Warehouse
	ValueForParameterStructuralUnit = SmallBusinessReUse.GetValueByDefaultUser(User, "MainWarehouse");
	If ValueIsFilled(ValueForParameterStructuralUnit) Then
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED
		|	StructuralUnits.Ref AS Warehouse
		|FROM
		|	Catalog.StructuralUnits AS StructuralUnits
		|WHERE
		|	StructuralUnits.StructuralUnitType = Value(Enum.StructuralUnitsTypes.Warehouse)";
		
		Selection = Query.Execute().Select();
		
		While Not ValueIsFilled(ValueForParameterStructuralUnit) Do
			
			Selection.Next();
			ValueForParameterStructuralUnit = Selection.Warehouse;
			
		EndDo;
		
	EndIf;
	
	StructureOfParametersByDefault.Insert("StructuralUnit", ValueForParameterStructuralUnit);
	
	If Parameters.Property("IsPriceKind")
		AND Parameters.IsPriceKind Then
	
		//Price kind
		ValueForParameterPriceKind = SmallBusinessReUse.GetValueByDefaultUser(User, "MainPriceKindSales");
		StructureOfParametersByDefault.Insert("PriceKind", ?(ValueIsFilled(ValueForParameterPriceKind), ValueForParameterPriceKind, Catalogs.PriceKinds.Wholesale));
		
		//Currency, VAT
		StructureOfParametersByDefault.Insert("Currency", StructureOfParametersByDefault.PriceKind.PriceCurrency);
		StructureOfParametersByDefault.Insert("AmountIncludesVAT", StructureOfParametersByDefault.PriceKind.PriceIncludesVAT);
		
	EndIf;
	
	If Parameters.Property("AvailablePriceChanging") Then
		
		StructureOfParametersByDefault.Insert("AvailablePriceChanging", Parameters.AvailablePriceChanging);
		
	EndIf;

	If Parameters.Property("IsTaxation") Then
		If Parameters.IsTaxation Then
		
		//VAT taxation
		StructureOfParametersByDefault.Insert("VATTaxation",
				SmallBusinessServer.VATTaxation(StructureOfParametersByDefault.Company,
								StructureOfParametersByDefault.StructuralUnit,
								StructureOfParametersByDefault.Period));
			
		Else
			
			StructureOfParametersByDefault.Insert("VATTaxation", Enums.VATTaxationTypes.TaxableByVAT);
			
		EndIf;
		
	EndIf;
	
	//Use the reservation (reserve column visible in selected products)
	If Parameters.Property("ReservationUsed") 
		AND Parameters.ReservationUsed Then
		
		StructureOfParametersByDefault.Insert("ReservationUsed", True);
		
	EndIf;
	
	//Fill the reserve (fill the reserve column with quantity value)
	If Parameters.Property("FillReserve")
		AND Parameters.FillReserve Then
		
		StructureOfParametersByDefault.Insert("FillReserve", True);
		
	EndIf;
	
	// Norms are used.
	If Parameters.Property("NormsUsed")
		AND Parameters.NormsUsed Then
		
		StructureOfParametersByDefault.Insert("NormsUsed", True);
		
	EndIf;
	
	// Products and services type
	If Parameters.Property("ArrayProductsAndServicesTypes") Then
		FilterProductsAndServicesType = New ValueList;
		For Each ArrayElement IN Parameters.ArrayProductsAndServicesTypes Do
			FilterProductsAndServicesType.Add(Enums.ProductsAndServicesTypes[ArrayElement]);
		EndDo;
		StructureOfParametersByDefault.Insert("ProductsAndServicesType", FilterProductsAndServicesType);
	EndIf;
	
	// Button OK
	If Parameters.Property("OperationKindJobOrder") Then
		OperationKindJobOrder = True;
		Items.OK.Title= "Create " + """Job-order""";
	Else
		Items.OK.Title= "Create " + """" + Metadata.Documents[Parameters.KindOfNewDocument].Synonym + """";
	EndIf;
	
EndProcedure //FillInDefaultValues()

&AtServer
// Function places picking results into storage
//
Function WritePickToStorage() 
	
	For Each ImportRow IN FilteredInventory Do
		
		If NormsUsed Then
			
			ImportRow.Factor = ImportRow.Quantity;
			ImportRow.Multiplicity = 1;
			
			StructureData = New Structure;
			StructureData.Insert("ProcessingDate", 		Period);
			StructureData.Insert("ProductsAndServices", 		ImportRow.ProductsAndServices);
			StructureData.Insert("Characteristic", 		ImportRow.Characteristic);
			
			If Not ImportRow.ProductsAndServices.FixedCost Then // Time standards and prices by kind of works are not used for fixed cost
				
				ImportRow.Quantity = SmallBusinessServer.GetWorkTimeRate(StructureData);
				StructureData.Insert("ProductsAndServices", 	WorkKind);
				
			EndIf;
			
			If UseTypeOfWorks Then
				
				StructureData.Insert("Characteristic", 	Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
				StructureData.Insert("Factor", 	1);
				StructureData.Insert("MeasurementUnit",WorkKind.MeasurementUnit);
				StructureData.Insert("PriceKind",			PriceKind);
				StructureData.Insert("DocumentCurrency",	Currency);
				
				ImportRow.Price 	= SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
				ImportRow.Amount 	= ImportRow.Quantity * ImportRow.Factor * ImportRow.Multiplicity * ImportRow.Price;
				
				If ValueIsFilled(VATTaxation)
					AND Not VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
			
					If VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
						
						ImportRow.VATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
						
					Else
						
						ImportRow.VATRate = SmallBusinessReUse.GetVATRateZero();
						
					EndIf;
					
				ElsIf ValueIsFilled(ImportRow.ProductsAndServices.VATRate) Then
					
					ImportRow.VATRate = ImportRow.ProductsAndServices.VATRate;
					
				Else
					
					ImportRow.VATRate = DocumentOrganization.DefaultVATRate;
					
				EndIf;
				
				VATRate = SmallBusinessReUse.GetVATRateValue(ImportRow.VATRate);
				
				ImportRow.VATAmount = ?(AmountIncludesVAT,
									ImportRow.Amount - (ImportRow.Amount) / ((VATRate + 100) / 100),
									ImportRow.Amount * VATRate / 100);
				
			EndIf;
			
		EndIf;
		
		If SpecificationsUsed Then
			ImportRow.Specification = SmallBusinessServer.GetDefaultSpecification(ImportRow.ProductsAndServices, ImportRow.Characteristic);
		EndIf;
		
		ImportRow.CostPercentage 		= 1;
		
	EndDo;
	
	SmallBusinessServer.SetUserSetting(Items.InventoryListRequestQuantityAndPrices.Check, "RequestQuantityAndPrice");
	
	If SettingsStructure.KeepCurrentHierarchy Then
		
		SmallBusinessServer.SetUserSetting(ProductsAndServicesGroup, "FilterGroup");
		
	EndIf;
	
	Return PutToTempStorage(
		FilteredInventory.Unload(),
		?(OwnerFormUUID = New UUID("00000000-0000-0000-0000-000000000000"), Undefined, OwnerFormUUID)
										);
	
EndFunction

&AtClient
// VAT amount is calculated in the row of tabular section.
//
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure // RecalculateDocumentAmounts()

&AtServerNoContext
// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
Function GetDataProductsAndServicesOnChange(StructureData)
	
	ProductsAndServicesStructure = New Structure("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	If Not StructureData.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		DataVATRate = ?(StructureData.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT,
							SmallBusinessReUse.GetVATRateWithoutVAT(),
							SmallBusinessReUse.GetVATRateZero());
		
	ElsIf ValueIsFilled(StructureData.ProductsAndServices.VATRate) Then
		
		DataVATRate = StructureData.ProductsAndServices.VATRate;
		
	Else
		
		DataVATRate = StructureData.Company.DefaultVATRate;
		
	EndIf;
	
	If StructureData.AccrualVATRate AND ValueIsFilled(DataVATRate) AND Not DataVATRate.Calculated Then
		
		DataVATRate = SmallBusinessReUse.GetVATRateEstimated(DataVATRate);
		
	EndIf;
	
	ProductsAndServicesStructure.Insert("VATRate", DataVATRate);

	ProductsAndServicesStructure.Insert("Price", ?(StructureData.Property("PriceKind"), SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData), 0));
	
	If StructureData.Property("DiscountMarkupKind") 
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then 
		
		ProductsAndServicesStructure.Insert("DiscountMarkupPercent", StructureData.DiscountMarkupKind.Percent);
		
	EndIf;
	
	Return ProductsAndServicesStructure;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

&AtClient
// VAT amount is calculated in the row of tabular section.
//
Procedure CalculateVATAmountAtClient(TabularSectionRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  TabularSectionRow.Amount * VATRate / 100);
											
EndProcedure // RecalculateDocumentAmounts() 

&AtClient
// Procedure calculates the amount in the row of tabular section.
//
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		
		TabularSectionRow = Items.FilteredInventory.CurrentData;
		
	EndIf;
	
	// Remember the "Total" amount
	TotalBeforeRecosting = TabularSectionRow.Total;
	
	// Amount
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	// Discount
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		
		TabularSectionRow.Amount = 0;
		
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 Then
		
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
		
	EndIf;
	
	// VAT amount
	CalculateVATAmountAtClient(TabularSectionRow);
	
	// Total
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Update total
	AmountOfSelectedProducts = AmountOfSelectedProducts + (TabularSectionRow.Total - TotalBeforeRecosting);
	
EndProcedure // CalculateAmountInTabularSectionLine()

&AtClient
// Procedure - handler of the RequestQuantity command.
//
Procedure RequestQuantity(Command)
	
	Items.InventoryListRequestQuantityAndPrices.Check	= Not RequestQuantity;
	Items.ListOfBalancesRequestQuantityAndPrice.Check	= Not RequestQuantity;
	
	RequestQuantity = Not RequestQuantity;
	
EndProcedure

&AtClient
// Procedure is used to go to the characteristics list
//
// Parameters:
// InventoryListCurrentRow - current row of "Inventory" dynamic list
//
Procedure GoToCharacteristics(ProductsListRow, OpenWithoutBalance = False)
	
	CommonUseClientServer.SetFilterDynamicListItem(CharacteristicsList, "ProductsAndServices", ProductsListRow.ProductsAndServices, DataCompositionComparisonType.Equal, , True, DataCompositionSettingsItemViewMode.QuickAccess);
	
	If (ProductsListRow.UseCharacteristics OR ProductsListRow.UseBatches)
		AND ((ProductsListRow.Property("Balance") AND ProductsListRow.Balance > 0) 
			OR ThisIsReceiptDocument
			OR OpenWithoutBalance
			OR (TrimAll(SettingsStructure.OutputBalancesMethod) = "Separately" AND TextBalance > 0)) Then
		 
		Items.PagesGroup.CurrentPage	= Items.PageCharacteristicsList;
		Items.CommandBarInventoryAndCharacteristics.CurrentPage = Items.PageCommandBarCharacteristics;
		
		AttachIdleHandler("PickCharacteristicsListOnActivateRowIdleHandler",0.2,True);
		
	Else 
		
		If Not SettingsStructure.ShowPrices Then
			
			PriceForCart = 0;
			
		ElsIf TrimAll(SettingsStructure.OutputBalancesMethod) = "Separately" Then
			
			If CacheInventoryListCurrentRow <> Items.InventoryList.CurrentRow Then
				
				DetachIdleHandler("PickInventoryListOnActivateRowIdleHandler");
				PickInventoryListOnActivateRowIdleHandler();
				
			EndIf;
			
			PriceForCart = TextPrice;
			
		Else
			
			PriceForCart = ?(PricingInVariousUOM, ProductsListRow.PriceByClassifier, ProductsListRow.Price);
			
		EndIf;
		
		ChangeProductInCart(ProductsListRow, , , 1, PriceForCart);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure changes (adds) products in the "Cart"
//
// The cart is considered to be a "FilteredInventory" tablular section
//
Procedure ChangeProductInCart(ProductsListRow, RowCharacteristicsOfBatches = Undefined, StringCart = Undefined, Quantity, Price)
	
	If SettingsStructure.ShowAvailableBalance Then
		
		If TrimAll(SettingsStructure.OutputBalancesMethod) = "Separately" Then
			
				AvailableBalance = TextAvailableBalance;
			
		Else
			
			If RowCharacteristicsOfBatches = Undefined Then
				
				AvailableBalance = ProductsListRow.AvailableBalance;
				
			Else
				
				AvailableBalance = RowCharacteristicsOfBatches.AvailableBalance;
				
			EndIf;
			
		EndIf;
		
	Else
		
		AvailableBalance = 0;
		
	EndIf;
	
	If RequestQuantity Then
		
		PriceAvailable = SettingsStructure.ShowPrices AND AvailablePriceChanging AND (PricesUsed OR CounterpartyPricesUsed);
		
		ChangingParameters = New Structure("UOMOwner, Quantity, PriceAvailable, Price", ProductsListRow.ProductsAndServices, Quantity, PriceAvailable, Price);
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ProductsListRow", ProductsListRow);
		AdditionalParameters.Insert("RowCharacteristicsOfBatches", RowCharacteristicsOfBatches);
		AdditionalParameters.Insert("StringCart", StringCart);
		AdditionalParameters.Insert("AvailableBalance", AvailableBalance);
		AdditionalParameters.Insert("Quantity", Quantity);
		AdditionalParameters.Insert("Price", Price);
		
		NotifyDescription = New NotifyDescription("AfterQuantityAndPriceRequestAddProductToCart", ThisObject, AdditionalParameters);
		OpenForm("CommonForm.QuantityAndPriceForm", New Structure("FillValue", ChangingParameters), ThisForm, , , , NotifyDescription);
		
	Else
		
		ChangeAddRowToCart(ProductsListRow, RowCharacteristicsOfBatches, StringCart, Quantity, Price, AvailableBalance);
		
	EndIf;
	
	
	
EndProcedure //ChangeProductInCart()

&AtClient
// Procedure initializes the addition
// of a product to "Cart" for products and services being
// accounted by characteristics, but user have no need to access this data
//
Procedure AddProductsWithoutGettingCharacteristics(Command)
	
	ProductsListRow = Items.InventoryList.CurrentData;
	If Not ProductsListRow = Undefined Then
		
		If Not SettingsStructure.ShowPrices Then
			
			PriceForCart = 0;
			
		ElsIf TrimAll(SettingsStructure.OutputBalancesMethod) = "Separately" Then
			
			If CacheInventoryListCurrentRow <> Items.InventoryList.CurrentRow Then
				
				DetachIdleHandler("PickInventoryListOnActivateRowIdleHandler");
				PickInventoryListOnActivateRowIdleHandler();
				
			EndIf;
			
			PriceForCart = TextPrice;
			
		Else
			
			PriceForCart = ?(PricingInVariousUOM, ProductsListRow.PriceByClassifier, ProductsListRow.Price);
			
		EndIf;
		
		ChangeProductInCart(ProductsListRow, , , 1, PriceForCart);
		
	EndIf;
	
EndProcedure // AddProductsWithoutGettingInCharacteristics()

&AtServer
// Procedure sets visible for selection form items
//
Procedure ManagementOfFormItemsVisible(FormOpenParameters)
	
	Items.FilteredInventoryReserve.Visible = (FormOpenParameters.Property("ReservationUsed") 
									AND FormOpenParameters.ReservationUsed 
									AND Constants.FunctionalOptionInventoryReservation.Get()
									AND Not QueryByWarehouse);
	
	If ValueIsFilled(VATTaxation) 
		AND Not UseTypeOfWorks Then
		
		Items.FilteredInventoryVATAmount.Visible		= (VATTaxation = Enums.VATTaxationTypes.TaxableByVAT);
		Items.FilteredInventoryVATRate.Visible	= (VATTaxation = Enums.VATTaxationTypes.TaxableByVAT);
		
	EndIf;
	
	Items.FilteredInventoryPrice.Visible		= (PricesUsed OR CounterpartyPricesUsed);
	Items.FilteredInventoryAmountTotal.Visible	= (PricesUsed OR CounterpartyPricesUsed);
	
	Items.Cell.Visible					= AccountingByCells;
	Items.FilteredInventoryBatch.Visible	= BatchesUsed;
	
	Items.FilteredInventoryDiscountMarkupPercent.Visible = DiscountsMarkupsUsed OR DiscountCardsAreUsed; // DiscountCards
	
EndProcedure //FormItemsVisibleManagement()

&AtServer
// Procedure sets the visible of the
// form dynamic lists fields depending on the passed settings
//
// Parameters:
// SettingsStructure - Structure contains the user settings value
//
Procedure SetVisibleOfDynamicListFields(SettingsStructure)
	
	ShowInTable = (SettingsStructure.OutputBalancesMethod = Enums.BalancesOutputMethodInSelection.InTable);
	
	Items.InventoryListBalance.Visible 			= SettingsStructure.ShowBalance AND ShowInTable AND SettingsStructure.NeedToShowBalances;
	Items.InventoryListReserve.Visible 				= SettingsStructure.ShowReserve AND ShowInTable AND Not QueryByWarehouse AND SettingsStructure.NeedToShowBalances;
	Items.InventoryListAvailableBalance.Visible 	= SettingsStructure.ShowAvailableBalance AND ShowInTable AND Not QueryByWarehouse AND SettingsStructure.NeedToShowBalances;
	
	Items.InventoryListMeasurementUnit.Visible		= PricingInVariousUOM;	
	
	Items.InventoryListPrice.Visible = SettingsStructure.ShowPrices 
											AND (PricesUsed OR CounterpartyPricesUsed)
											AND Not PricingInVariousUOM
											AND ShowInTable;
	
	Items.InventoryListPriceByClassifier.Visible = SettingsStructure.ShowPrices
														AND (PricesUsed OR CounterpartyPricesUsed)
														AND PricingInVariousUOM
														AND ShowInTable;
																
	Items.CharacteristicsListPrice.Visible = SettingsStructure.ShowPrices 
											AND (PricesUsed OR CounterpartyPricesUsed)
											AND Not PricingInVariousUOM
											AND ShowInTable;
	
	Items.CharacteristicsListPriceByClassifier.Visible = SettingsStructure.ShowPrices
														AND (PricesUsed OR CounterpartyPricesUsed)
														AND PricingInVariousUOM
														AND ShowInTable;
	
	Items.CharacteristicsListBalance.Visible 			= ShowInTable AND SettingsStructure.ShowBalance AND SettingsStructure.NeedToShowBalances;
	Items.CharacteristicsListReserve.Visible 			= ShowInTable AND SettingsStructure.ShowReserve AND Not QueryByWarehouse AND SettingsStructure.NeedToShowBalances;
	Items.CharacteristicsListGroupBalances.Visible		= Items.CharacteristicsListBalance.Visible OR Items.CharacteristicsListReserve.Visible;
	Items.CharacteristicsListAvailableBalance.Visible	= ShowInTable AND SettingsStructure.ShowAvailableBalance AND SettingsStructure.NeedToShowBalances;
	
	Items.FilteredInventoryCharacteristic.Visible		= CharacteristicsUsed;
	
	Items.Warehouse.Visible 					= SettingsStructure.NeedToShowBalances;
	
	Items.GroupBalancesPriceKindsPriceAsText.Visible = SettingsStructure.OutputBalancesMethod = Enums.BalancesOutputMethodInSelection.Separately;
	Items.TextBalance.Visible 			= SettingsStructure.ShowBalance;
	Items.TextReserve.Visible 				= SettingsStructure.ShowReserve AND Not QueryByWarehouse;
	Items.TextAvailableBalance.Visible 	= SettingsStructure.ShowAvailableBalance;
	
	If SettingsStructure.ShowPrices Then
		
		If ValueIsFilled(PriceKind) Then
			
			Items.GroupPriceKindsVisible.CurrentPage = Items.GroupConsolidatingCounterpartyPriceKind;
			
		ElsIf ValueIsFilled(CounterpartyPriceKind) Then
			
			Items.GroupPriceKindsVisible.CurrentPage = Items.GroupPriceKindCounterparty;
			
		Else 
			
			Items.GroupPriceKindsVisible.CurrentPage = Items.GroupPriceKindsNotSpecified;
			
		EndIf;
		
	EndIf;
	
	Items.TextPrice.Visible			= SettingsStructure.ShowPrices;
	Items.PriceKind.Visible				= SettingsStructure.ShowPrices AND PricesUsed;
	Items.CounterpartyPriceKind.Visible	= SettingsStructure.ShowPrices AND CounterpartyPricesUsed;
	Items.DecorationOfKindNotSpecifiedPrice.Visible = SettingsStructure.ShowPrices AND (PricesUsed OR CounterpartyPricesUsed);
	
EndProcedure //SetVisibleDynamicListFields()

&AtServer
// Sets the value of the dynamic list parameter on server
//
// Parameters:
// DynamicList - dynamic list which the
// Name parameter is set for - parameter name
// of ParameterValue dynamic list - value of the set parameter
//
Procedure SetDynamicListParameter(DynamicList, Name, ParameterValue)
	
	If Not DynamicList.Parameters.Items.Find(Name) = Undefined Then
		
		CommonUseClientServer.SetDynamicListParameter(DynamicList, Name, ParameterValue, True);
		
	EndIf;
	
EndProcedure // SetDynamicListParameter()

&AtServer
// Procedure receives data from the storage by the specified address and imports it into receiver object (Tabular section, table of values)
//
// Parameters:
// Address - address of storage passed
// to the TableForImport selection form - table value for inventory import (SelectedInventory)
//
Procedure ImportInventoryFromStorage(Address, TableForImport)
	
	InventoryTable 				= GetFromTempStorage(Address);
	AreReserveShipmentColumn 	= InventoryTable.Columns.Find("ReserveShipment");
	
	For Each TSRow IN InventoryTable Do
		
		NewRow = TableForImport.Add();
		FillPropertyValues(NewRow, TSRow);
		
		If NormsUsed Then
			NewRow.Quantity = TSRow.Factor;
		EndIf;
		
		If AreReserveShipmentColumn <> Undefined 
			AND NewRow.Property("Reserve") Then
			
			NewRow.Reserve = TSRow.ReserveShipment;
			
		EndIf;
		
	EndDo;
	
EndProcedure //ImportInventoryFromStorage()

&AtServer
// Procedure reads user settings
// for data displaying in a selection form
//
Function GetPickSettings()
	
	User 			= Users.CurrentUser();
	OutputBalancesMethod	= SmallBusinessReUse.GetValueByDefaultUser(User, "OutputBalancesMethod");
	
	If Not ValueIsFilled(OutputBalancesMethod) Then
		
		OutputBalancesMethod = Enums.BalancesOutputMethodInSelection.InTable;
		
	EndIf;
	
	NeedToShowBalances = Not ((ProductsAndServicesType.FindByValue(Enums.ProductsAndServicesTypes.InventoryItem) = Undefined)
								AND (ProductsAndServicesType.FindByValue(Enums.ProductsAndServicesTypes.Operation) = Undefined))
							AND Not ThisIsReceiptDocument;
	
	Return New Structure("RequestQuantityAndPrice, ShowBalance, ShowReserve, ShowAvailableBalance, ShowPrices, NeedToShowBalances, OutputBalancesMethod, KeepCurrentHierarchy",
				SmallBusinessReUse.GetValueByDefaultUser(User, "RequestQuantityAndPrice"),
				SmallBusinessReUse.GetValueByDefaultUser(User, "ShowBalance") AND NeedToShowBalances,
				SmallBusinessReUse.GetValueByDefaultUser(User, "ShowReserve") AND Constants.FunctionalOptionInventoryReservation.Get() AND NeedToShowBalances,
				SmallBusinessReUse.GetValueByDefaultUser(User, "ShowAvailableBalance") AND Constants.FunctionalOptionInventoryReservation.Get() AND NeedToShowBalances,
				SmallBusinessReUse.GetValueByDefaultUser(User, "ShowPrices") AND (PricesUsed OR CounterpartyPricesUsed),
				NeedToShowBalances,
				OutputBalancesMethod,
				SmallBusinessReUse.GetValueByDefaultUser(User, "KeepCurrentHierarchy"));
	
EndFunction //GetSelectionSettings()

&AtServer
// Procedure sets query text for the "InventoryList" dynamic list
//
// Parameters:
// SettingsStructure - Structure contains the user settings value
//
Procedure SetQueryTextOfInventoryList(SettingsStructure)
	
	// Query generation conditions
	QueryWithRemainders = (SettingsStructure.ShowBalance OR SettingsStructure.ShowReserve OR SettingsStructure.ShowAvailableBalance) 
							AND (SettingsStructure.OutputBalancesMethod = Enums.BalancesOutputMethodInSelection.InTable)
							AND SettingsStructure.NeedToShowBalances;
							
	QueryWithPrices 				= SettingsStructure.ShowPrices AND (SettingsStructure.OutputBalancesMethod = Enums.BalancesOutputMethodInSelection.InTable);
	QueryWithProductsAndServicesTypes 	= (ProductsAndServicesType.Count() > 0);
	QueryWithBatchStatuses 	= (BatchStatus.Count() > 0);
	
	// Generation of the query text
	InventoryList.CustomQuery = True;
	
	QueryText = 
	"SELECT
	|	ProductsAndServicesList.Ref AS Ref,
	|	ProductsAndServicesList.Ref AS ProductsAndServices,
	|	ProductsAndServicesList.Code AS Code,
	|	ProductsAndServicesList.SKU AS SKU,
	|	ProductsAndServicesList.Description AS Description,
	|	ProductsAndServicesList.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN &ThisIsReceiptDocument
	|				AND ProductsAndServicesList.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Service)
	|			THEN FALSE
	|		ELSE ProductsAndServicesList.UseCharacteristics
	|	END AS UseCharacteristics,
	|	ProductsAndServicesList.UseBatches AS UseBatches,
	|	&BalanceFieldOutputCondition AS Balance,
	|	&ReserveFieldOutputCondition AS Reserve,
	|	&AvailableBalanceFieldOutputCondition AS AvailableBalance,
	|	&PriceByClassifierFieldOutputCondition AS PriceByClassifier,
	|	&PriceFieldOutputCondition AS Price
	|FROM
	|	Catalog.ProductsAndServices AS ProductsAndServicesList";
	
	If QueryWithRemainders Then
	
		QueryText = QueryText + "
		|	LEFT JOIN &QueryTitleByRegister(
		|				, 
		|				Company = &Company 
		|				AND (NOT ProductsAndServices.IsFolder)
		|				AND &FilterConditionByWarehouse
		|				AND &FilterConditionByCell
		|				AND &FilterConditionByProductsAndServicesTypes AND &FilterConditionByBatchStatus) AS InventoryBalances
		|   ON ProductsAndServicesList.Ref = InventoryBalances.ProductsAndServices";
		
		QueryText = StrReplace(QueryText, 
				"&QueryTitleByRegister", 
				?(QueryByWarehouse, "AccumulationRegister.InventoryInWarehouses.Balance", "AccumulationRegister.Inventory.Balance"));
				
		QueryText = StrReplace(QueryText, 
				"&FilterConditionByWarehouse",
				?(NOT (Warehouse = UNDEFINED OR Warehouse = Catalogs.StructuralUnits.EmptyRef()), "StructuralUnit = &StructuralUnit", "TRUE"));
				
		QueryText = StrReplace(QueryText, 
				"&FilterConditionByCell",
				?(AccountingByCells, "Cell = &StorageBin", "TRUE"));
				
		QueryText = StrReplace(QueryText, 
				"&FilterConditionByProductsAndServicesTypes",
				?(QueryWithProductsAndServicesTypes, "ProductsAndServices.ProductsAndServicesType IN (&ProductsAndServicesType)", "TRUE"));
				
		QueryText = StrReplace(QueryText, 
				"&FilterConditionByBatchStatus",
				?(QueryWithBatchStatuses, "(Batch = VALUE(Catalog.ProductsAndServicesBatches.EmptyREf) OR Batch.Status IN (&BatchStatus))", "TRUE"));
					
	EndIf;
	
	If QueryWithPrices Then
		QueryText = QueryText + "
		|	LEFT JOIN &RegisterNameWithPricesType.SliceLast(
		|		&PricePeriod,
		|		&PriceKindFieldForComparison = &PriceKind
		|		AND ProductsAndServices.ProductsAndServicesType <> Value(Enum.ProductsAndServicesTypes.Work)) AS ProductsAndServicesPricesSliceLast
		|       ON ProductsAndServicesList.Ref = ProductsAndServicesPricesSliceLast.ProductsAndServices 
		|		AND (ProductsAndServicesPricesSliceLast.Characteristic = VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef))";
		
		QueryText = StrReplace(QueryText, 
				"&RegisterNameWithPricesType", 
				?(CounterpartyPricesUsed, "InformationRegister.CounterpartyProductsAndServicesPrices", "InformationRegister.ProductsAndServicesPrices"));
				
		QueryText = StrReplace(QueryText, 
				"&PriceKindFieldForComparison", 	
				?(CounterpartyPricesUsed, "CounterpartyPriceKind", "PriceKind"));
				
	EndIf;
	
	QueryText = QueryText + "
	|WHERE
	|	(NOT ProductsAndServicesList.IsFolder)
	|   AND &FilterConditionByProductsAndServicesTypes
	|GROUP BY
	|	ProductsAndServicesList.Ref,
	|	ProductsAndServicesList.Code,
	|	ProductsAndServicesList.SKU,
	|	ProductsAndServicesList.Description,
	|	ProductsAndServicesList.MeasurementUnit, 
	|	CASE
	|		WHEN &ThisIsReceiptDocument 
	|			AND ProductsAndServicesList.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Service) 
	|		THEN FALSE
	|		ELSE ProductsAndServicesList.UseCharacteristics
	|	END, 
	|	ProductsAndServicesList.UseBatches,
	|	&PriceByClassifierFieldOutputCondition, 
	|	&PriceFieldOutputCondition";
	
	QueryText = StrReplace(QueryText, 
			"&FilterConditionByProductsAndServicesTypes",
			?(QueryWithProductsAndServicesTypes, "ProductsAndServicesList.ProductsAndServicesType IN (&ProductsAndServicesType)", "TRUE"));
			
	QueryText = StrReplace(QueryText, "&BalanceFieldOutputCondition", ?(QueryWithRemainders, "SUM(InventoryBalances.QuantityBalance) ", "0"));
	QueryText = StrReplace(QueryText, "&ReserveFieldOutputCondition", ?(QueryWithRemainders AND Not QueryByWarehouse, "	
	|	SUM(CASE
	|			WHEN InventoryBalances.CustomerOrder = VALUE(Document.CustomerOrder.EmptyREf)
	|				THEN 0
	|			ELSE InventoryBalances.QuantityBalance
	|		END) ", "0"));
	
	QueryText = StrReplace(QueryText, "&AvailableBalanceFieldOutputCondition", ?(QueryWithRemainders AND Not QueryByWarehouse, "
	|		SUM(InventoryBalances.QuantityBalance - CASE
	|			WHEN InventoryBalances.CustomerOrder = VALUE(Document.CustomerOrder.EmptyREf)
	|				THEN 0
	|			ELSE InventoryBalances.QuantityBalance
	|		END) ", "0"));
	
	QueryText = StrReplace(QueryText, "&PriceByClassifierFieldOutputCondition", ?(QueryWithPrices, "ProductsAndServicesPricesSliceLast.Price ", "0"));
	QueryText = StrReplace(QueryText, "&PriceFieldOutputCondition", ?(QueryWithPrices, "
	|	CASE
	|		WHEN VALUETYPE(ProductsAndServicesPricesSliceLast.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProductsAndServicesPricesSliceLast.Price
	|		ELSE ProductsAndServicesPricesSliceLast.Price / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1)
	|	END ", "0"));
	
	// Update the query text
	If Not InventoryList.QueryText = QueryText Then
		
		InventoryList.QueryText = QueryText;
		
	EndIf;
	
	// Query parameters
	SetDynamicListParameter(InventoryList, "PricePeriod", 		Period);
	SetDynamicListParameter(InventoryList, "ProductsAndServicesType", ValueListIntoArray(ProductsAndServicesType));
	SetDynamicListParameter(InventoryList, "Company", 	Company);
	SetDynamicListParameter(InventoryList, "StructuralUnit", Warehouse);
	SetDynamicListParameter(InventoryList, "StorageBin",	Cell);
	SetDynamicListParameter(InventoryList, "BatchStatus", 	BatchStatus);
	SetDynamicListParameter(InventoryList, "PriceKind", 			?(CounterpartyPricesUsed, CounterpartyPriceKind, PriceKind));
	SetDynamicListParameter(InventoryList, "ThisIsReceiptDocument", ThisIsReceiptDocument);
	
EndProcedure // SetQueryTextInventoryList()

&AtServer
// Procedure sets query text for the "CharacteristicsList" dynamic list
//
// Parameters:
// SettingsStructure - Structure contains the user settings value
//
Procedure SetQueryTextOfCharacteristicsList(SettingsStructure)
	
	// Query generation conditions
	QueryWithRemainders = (SettingsStructure.ShowBalance OR SettingsStructure.ShowReserve OR SettingsStructure.ShowAvailableBalance)
							AND Not ThisIsReceiptDocument
							AND SettingsStructure.NeedToShowBalances;
	
	QueryWithPrices 				= SettingsStructure.ShowPrices;
	QueryWithProductsAndServicesTypes 	= (ProductsAndServicesType.Count() > 0);
	QueryWithBatchStatuses 	= (BatchStatus.Count() > 0);
	
	// Generation of the query text
	CharacteristicsList.CustomQuery = True;
	
	If QueryWithRemainders Then
		
		QueryText = 
		"SELECT
		|	InventoryBalances.ProductsAndServices.Ref AS ProductsAndServices,
		|	InventoryBalances.Characteristic.Description AS Characteristic,
		|	InventoryBalances.Characteristic.Ref AS Ref,
		|	InventoryBalances.Characteristic.Ref AS CharacteristicRef,
		|	InventoryBalances.Batch.Description AS Batch,
		|	InventoryBalances.Batch.Ref AS BatchRef,
		|	SUM(InventoryBalances.QuantityBalance) AS Balance,
		|	SUM(&ReserveCalculationCondition) AS Reserve,
		|	SUM(&AvailableBalanceCalculationCondition) AS AvailableBalance,
		|	&PriceByClassifierFieldOutputCondition AS PriceByClassifier,
		|	&PriceFieldOutputCondition AS Price
		|FROM
		|	&QueryTitleByRegister(
		|			,
		|			Company = &Company
		|				AND (ProductsAndServices.UseCharacteristics
		|					OR ProductsAndServices.UseBatches)
		|				AND &FilterConditionByWarehouse
		|				AND &FilterConditionByCell
		|				AND &FilterConditionByProductsAndServicesTypes
		|				AND &FilterConditionByBatchStatus) AS InventoryBalances";
		
		QueryText = StrReplace(QueryText, 
				"&ReserveCalculationCondition", 
				?(QueryByWarehouse, "0", "CASE
				|			WHEN InventoryBalances.CustomerOrder = VALUE(Document.CustomerOrder.EmptyREf)
				|				THEN 0
				|			ELSE InventoryBalances.QuantityBalance
				|		END"));
				
		QueryText = StrReplace(QueryText, 
				"&AvailableBalanceCalculationCondition", 
				?(QueryByWarehouse, "0", " InventoryBalances.QuantityBalance - CASE
				|			WHEN InventoryBalances.CustomerOrder = VALUE(Document.CustomerOrder.EmptyREf)
				|				THEN 0
				|			ELSE InventoryBalances.QuantityBalance
				|		END"));
				
		QueryText = StrReplace(QueryText, 
				"&QueryTitleByRegister", 
				?(QueryByWarehouse, "AccumulationRegister.InventoryInWarehouses.Balance", "AccumulationRegister.Inventory.Balance"));
				
		QueryText = StrReplace(QueryText, 
				"&FilterConditionByWarehouse",
				?(NOT (Warehouse = UNDEFINED OR Warehouse = Catalogs.StructuralUnits.EmptyRef()), "StructuralUnit = &StructuralUnit", "TRUE"));
				
		QueryText = StrReplace(QueryText, 
				"&FilterConditionByCell",
				?(AccountingByCells, "Cell = &StorageBin", "TRUE"));
				
		QueryText = StrReplace(QueryText, 
				"&FilterConditionByProductsAndServicesTypes",
				?(QueryWithProductsAndServicesTypes, "ProductsAndServices.ProductsAndServicesType IN (&ProductsAndServicesType)", "TRUE"));
				
		QueryText = StrReplace(QueryText, 
				"&FilterConditionByBatchStatus",
				?(QueryWithBatchStatuses, "(Batch = VALUE(Catalog.ProductsAndServicesBatches.EmptyRef) OR Batch.Status IN (&BatchStatus))", "TRUE"));
		
		If QueryWithPrices Then
			
			QueryText = QueryText + "
			|
			|			LEFT JOIN &RegisterNameWithPricesType.SliceLast(
			|				&PricesPeriod,
			|				(ProductsAndServices.UseCharacteristics 
			|				OR ProductsAndServices.UseBatches)
			|				AND &ConditionByProductsAndServicesTypes
			|				AND &PriceKindFieldForComparison = &PricesKind
			|				AND ProductsAndServices.ProductsAndServicesType <> Value (Enum.ProductsAndServicesTypes.Work)) AS ProductsAndServicesPricesSliceLast
			|			ON InventoryBalances.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices 
			|				AND (ISNULL(InventoryBalances.Characteristic, VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)) = ISNULL(ProductsAndServicesPricesSliceLast.Characteristic, VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)))";
			
			QueryText = StrReplace(QueryText, 
					"&RegisterNameWithPricesType", 	
					?(CounterpartyPricesUsed, "InformationRegister.CounterpartyProductsAndServicesPrices", "InformationRegister.ProductsAndServicesPrices"));
					
			QueryText = StrReplace(QueryText, 
					"&ConditionByProductsAndServicesTypes", 
					?(QueryWithProductsAndServicesTypes, 	"ProductsAndServices.ProductsAndServicesType IN (&ProductsAndServicesType)", "TRUE"));
					
			QueryText = StrReplace(QueryText, 
					"&PriceKindFieldForComparison", 	
					?(CounterpartyPricesUsed, "CounterpartyPriceKind", "PriceKind"));
			
		EndIf;
		
		QueryText = QueryText + "
		|GROUP BY 
		|	InventoryBalances.Characteristic,
		|	InventoryBalances.Batch,
		|	InventoryBalances.ProductsAndServices.Ref,
		|	&PriceByClassifierFieldOutputCondition,
		|	&PriceFieldOutputCondition";
		
	Else
		
		QueryText =
		"SELECT
		|	DetailsData.ProductsAndServices AS ProductsAndServices,
		|	IsNull(DetailsData.CharacteristicRef, VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)) AS CharacteristicRef,
		|	IsNull(DetailsData.Characteristic, """") AS Characteristic,
		|	IsNull(DetailsData.BatchRef, VALUE(Catalog.ProductsAndServicesBatches.EmptyREf)) AS BatchRef,
		|	IsNull(DetailsData.Batch, """") AS Batch,
		|	&PriceByClassifierFieldOutputCondition AS PriceByClassifier,
		|	&PriceFieldOutputCondition AS Price
		|FROM
		|	(SELECT
		|		IsNULL(ProductsAndServicesCharacteristics.Owner, ProductsAndServicesBatches.Owner) AS ProductsAndServices,
		|		ProductsAndServicesCharacteristics.Description AS Characteristic,
		|		ISNULL(ProductsAndServicesCharacteristics.Ref, VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyREf)) AS CharacteristicRef,
		|		ProductsAndServicesBatches.Description AS Batch,
		|		ProductsAndServicesBatches.Ref AS BatchRef
		|	FROM
		|		Catalog.ProductsAndServicesCharacteristics AS ProductsAndServicesCharacteristics
		|		FULL JOIN Catalog.ProductsAndServicesBatches AS ProductsAndServicesBatches
		|			ON ProductsAndServicesCharacteristics.Owner = ProductsAndServicesBatches.Owner
		|				AND (&FilterConditionByProductsAndServicesTypesCharacteristic)
		|				AND (&FilterConditionByBatchProductsAndServicesTypes)
		|	WHERE &FilterConditionByBatchesStatuses) AS DetailsData";
		
		QueryText = StrReplace(QueryText, 
				"&FilterConditionByProductsAndServicesTypesCharacteristic",
				?(QueryWithProductsAndServicesTypes, "ProductsAndServicesCharacteristics.Owner.ProductsAndServicesType IN(&ProductsAndServicesType)", "TRUE"));
				
		If QueryWithProductsAndServicesTypes 
			AND GetFunctionalOption("UseBatches") Then
				
			QueryText = StrReplace(QueryText, "&FilterConditionByBatchProductsAndServicesTypes", "ProductsAndServicesBatches.Owner.ProductsAndServicesType IN(&ProductsAndServicesType)");
				
		Else
				
			QueryText = StrReplace(QueryText, "&FilterConditionByBatchProductsAndServicesTypes", "TRUE");
				
		EndIf;
			
		QueryText = StrReplace(QueryText, 
				"&FilterConditionByBatchesStatuses",
				?(QueryWithBatchStatuses, "(ProductsAndServicesBatches.Ref = VALUE(Catalog.ProductsAndServicesBatches.EmptyRef) OR ProductsAndServicesBatches.Status IN (&BatchStatus))", "TRUE"));
				
		If QueryWithPrices Then
		
			QueryText = QueryText + "
			|
			|LEFT JOIN &RegisterNameWithPricesType.SliceLast(
			|		&PricesPeriod,
			|		(ProductsAndServices.UseCharacteristics
			|		OR ProductsAndServices.UseBatches) 
			|		AND &ConditionByProductsAndServicesTypes 
			|		AND &PriceKindFieldForComparison = &PricesKind 
			|		AND ProductsAndServices.ProductsAndServicesType <> Value (Enum.ProductsAndServicesTypes.Work)) AS ProductsAndServicesPricesSliceLast 
			|	ON DetailsData.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices 
			|		AND DetailsData.CharacteristicRef = ProductsAndServicesPricesSliceLast.Characteristic";
			
			QueryText = StrReplace(QueryText, "&RegisterNameWithPricesType", 	?(CounterpartyPricesUsed, "InformationRegister.CounterpartyProductsAndServicesPrices", "InformationRegister.ProductsAndServicesPrices"));
			QueryText = StrReplace(QueryText, "&ConditionByProductsAndServicesTypes", ?(QueryWithProductsAndServicesTypes, 	"ProductsAndServices.ProductsAndServicesType IN (&ProductsAndServicesType)", "True"));
			QueryText = StrReplace(QueryText, "&PriceKindFieldForComparison", 	?(CounterpartyPricesUsed, "CounterpartyPriceKind", "PriceKind"));
			
		EndIf;
		
		QueryText = QueryText + "
		|UNION ALL
		|
		|SELECT
		|	ProductsAndServicesWithEmptyCharacteristicBatch.Ref,
		|	VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef),
		|	"""",
		|	VALUE(Catalog.ProductsAndServicesBatches.EmptyRef),
		|	"""",
		|	&PriceByClassifierFieldOutputCondition,
		|	&PriceFieldOutputCondition
		|FROM
		|	Catalog.ProductsAndServices AS ProductsAndServicesWithEmptyCharacteristicBatch";
		
		If QueryWithPrices Then
		
			QueryText = QueryText + "
			|		LEFT JOIN &RegisterNameWithPricesType.SliceLast(
			|			&PricesPeriod,
			|			(ProductsAndServices.UseCharacteristics 
			|			OR ProductsAndServices.UseBatches)
			|			AND &ConditionByProductsAndServicesTypes
			|			AND &PriceKindFieldForComparison = &PricesKind
			|			AND ProductsAndServices.ProductsAndServicesType <> VALUE(Enum.ProductsAndServicesTypes.Work)) AS ProductsAndServicesPricesSliceLast
			|		ON ProductsAndServicesWithEmptyCharacteristicBatch.Ref = ProductsAndServicesPricesSliceLast.ProductsAndServices
			|			AND VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef) = ProductsAndServicesPricesSliceLast.Characteristic";
			
			
			QueryText = StrReplace(QueryText, "&RegisterNameWithPricesType", 	?(CounterpartyPricesUsed, "InformationRegister.CounterpartyProductsAndServicesPrices", "InformationRegister.ProductsAndServicesPrices"));
			QueryText = StrReplace(QueryText, "&ConditionByProductsAndServicesTypes", ?(QueryWithProductsAndServicesTypes, 	"ProductsAndServices.ProductsAndServicesType IN (&ProductsAndServicesType)", "True"));
			QueryText = StrReplace(QueryText, "&PriceKindFieldForComparison", 	?(CounterpartyPricesUsed, "CounterpartyPriceKind", "PriceKind"));
			
		EndIf;
		
	EndIf;
	
	QueryText = StrReplace(QueryText, "&PriceByClassifierFieldOutputCondition", ?(QueryWithPrices, "ProductsAndServicesPricesSliceLast.Price", "0"));
	QueryText = StrReplace(QueryText, "&PriceFieldOutputCondition", 				?(QueryWithPrices, "CASE
		|		WHEN VALUETYPE(ProductsAndServicesPricesSliceLast.MeasurementUnit) = Type(Catalog.UOMClassifier)
		|			THEN ProductsAndServicesPricesSliceLast.Price
		|		ELSE ProductsAndServicesPricesSliceLast.Price / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1)
		|	END", "0"));
	
	// Update the query text
	If Not CharacteristicsList.QueryText = QueryText Then
		
		CharacteristicsList.QueryText = QueryText;
		
	EndIf;
	
	// Query parameters
	SetDynamicListParameter(CharacteristicsList,	"PricePeriod",		Period);
	SetDynamicListParameter(CharacteristicsList,	"Company", 		Company);
	SetDynamicListParameter(CharacteristicsList,	"StructuralUnit", Warehouse);
	SetDynamicListParameter(CharacteristicsList, 	"StorageBin",	Cell);
	SetDynamicListParameter(CharacteristicsList,	"PriceKind", 			?(CounterpartyPricesUsed, CounterpartyPriceKind, PriceKind));
	SetDynamicListParameter(CharacteristicsList,	"ProductsAndServicesType", 	ValueListIntoArray(ProductsAndServicesType));
	SetDynamicListParameter(CharacteristicsList,	"BatchStatus", 	BatchStatus);
	
	// Bypass of the platform error in WEB client with filter in dynamic list.
	CommonUseClientServer.SetFilterDynamicListItem(CharacteristicsList, "ProductsAndServices", Catalogs.ProductsAndServices.EmptyRef(), DataCompositionComparisonType.Equal, , True, DataCompositionSettingsItemViewMode.QuickAccess);
	
EndProcedure // SetCharacteristicsListQueryText()

&AtServer
// Procedure fills in attribute of the "ProductsAndServicesType" form with values of available products and services types depending on the form opening parameters
//
// Parameters:
// FormOpenParameters - incoming parameters of the form opening. Type can be either Structure or FormDataStructure
//
Procedure GenerateUsedProductsAndServicesTypes(FormOpenParameters)
	
	If FormOpenParameters.Property("ProductsAndServicesType") 
		AND ValueIsFilled(FormOpenParameters.ProductsAndServicesType)  Then
			
		ArrayProductsAndServicesType = New Array();
		For Each ItemProductsAndServicesType IN FormOpenParameters.ProductsAndServicesType Do
			
			If FormOpenParameters.Property("ExcludeProductsAndServicesTypeWork") 
				AND ItemProductsAndServicesType.Value = Enums.ProductsAndServicesTypes.Work Then
				
				Continue;
				
			EndIf;
			
			ProductsAndServicesType.Add(ItemProductsAndServicesType.Value, ItemProductsAndServicesType.Presentation);
			ArrayProductsAndServicesType.Add(ItemProductsAndServicesType.Value);
			
		EndDo; 
		
		ArrayRestrictionsProductsAndServicesType 	= New FixedArray(ArrayProductsAndServicesType);
		NewParameter 						= New ChoiceParameter("Filter.ProductsAndServicesType", ArrayRestrictionsProductsAndServicesType);
		NewParameter2 						= New ChoiceParameter("Additionally.TypeRestriction", ArrayRestrictionsProductsAndServicesType);
		
		NewArray 						= New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		
		NewParameters 						= New FixedArray(NewArray);
		Items.FilteredInventoryProductsAndServices.ChoiceParameters = NewParameters;
		
	EndIf;
	
EndProcedure //GenerateUsedProductsAndServicesTypes()

&AtServer
// Procedure fills in attribute of the "BatchStatus" form with values of available statuses depending on the form opening parameters
//
// Parameters:
// FormOpenParameters - incoming parameters of the form opening. Type can be either Structure or FormDataStructure
//
Procedure GenerateUsedBatchStatuses(FormOpenParameters)
	
	If FormOpenParameters.Property("BatchStatus")
		AND ValueIsFilled(FormOpenParameters.BatchStatus) Then
		
		ArrayBatchStatus = New Array();
		For Each ItemBatchStatus IN FormOpenParameters.BatchStatus Do
			
			BatchStatus.Add(ItemBatchStatus.Value, ItemBatchStatus.Presentation);
			ArrayBatchStatus.Add(ItemBatchStatus.Value);
			
		EndDo;
		
		BatchStatus.Add(Enums.BatchStatuses.EmptyRef());
		
		ArrayRestrictionsBatchStatus = New FixedArray(ArrayBatchStatus);
		NewParameter	= New ChoiceParameter("Filter.Status", ArrayRestrictionsBatchStatus);
		NewParameter2	= New ChoiceParameter("Additionally.StatusRestriction", ArrayRestrictionsBatchStatus);
		
		NewArray		= New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		
		NewParameters = New FixedArray(NewArray);
		Items.FilteredInventoryBatch.ChoiceParameters = NewParameters;
		
	EndIf;
	
EndProcedure // GenerateUsedBatchStatuses()

&AtClient
// Procedure - idle handler of the
// "InventoryList" tabular section is called on new row activation
//
// To optimize the "flick" operation, the idle delay of 0.2 seconds is enabled
//
Procedure PickInventoryListOnActivateRowIdleHandler()
	
	If TrimAll(SettingsStructure.OutputBalancesMethod) = "Separately" 
		AND 
		(SettingsStructure.ShowBalance 
		OR SettingsStructure.ShowReserve 
		OR SettingsStructure.ShowAvailableBalance 
		OR SettingsStructure.ShowPrices)
		AND
		CacheInventoryListCurrentRow <> Items.InventoryList.CurrentRow Then
		
		CurrentRow	= Items.InventoryList.CurrentData;
		If CurrentRow = Undefined Then 
			
			Return;
			
		EndIf;
		
		DataStructure = GetStructureOfBalancesAndPriceOfProduct(Period, CurrentRow.ProductsAndServices, Undefined, Undefined, PriceKind, True);
		
		TextBalance			= ?(DataStructure.Property("Balance"), 			DataStructure.Balance, 			0);
		TextReserve				= ?(DataStructure.Property("Reserve"), 			DataStructure.Reserve,				0);
		TextAvailableBalance	= ?(DataStructure.Property("AvailableBalance"),	DataStructure.AvailableBalance,	0);
		TextPrice 				= ?(DataStructure.Property("Price"), 				DataStructure.Price,				0);
		
		CacheInventoryListCurrentRow = Items.InventoryList.CurrentRow;
		
	EndIf;
	
EndProcedure // PickInventoryListOnActivateRowIdleHandler()

&AtClient
// Procedure - wait handler of the
// "CharacteristicsList" tabular section is called on new row activation
//
// To optimize the "flick" operation, the idle delay of 0.2 seconds is enabled
//
Procedure PickCharacteristicsListOnActivateRowIdleHandler()
	
	If TrimAll(SettingsStructure.OutputBalancesMethod) = "Separately" Then
		
		CurrentRow	= Items.CharacteristicsList.CurrentData;
		If CurrentRow = Undefined Then 
			
			Return;
			
		EndIf;
		
		TextBalance			= ?(CurrentRow.Property("Balance"), 			CurrentRow.Balance, 			0);
		TextReserve				= ?(CurrentRow.Property("Reserve"), 			CurrentRow.Reserve,			0);
		TextAvailableBalance	= ?(CurrentRow.Property("AvailableBalance"), CurrentRow.AvailableBalance,	0);
		TextPrice 				= ?(CurrentRow.Property("Price"), 			CurrentRow.Price,				0);
		
	EndIf;
	
EndProcedure // PickCharacteristicsListOnActivateRowIdleHandler()

&AtServer
// Procedure receives the structure that contains necessary data on current dynamic list row
//
// Purpose - used when prices and balance are displayed separately from tabular section
//
// Parameters:
// ToDate - period for balance and prices
// receiving Company - company that will have prices and
// balance received StructuralUnit - structural unit that will have prices and
// balance received ProductsAndServices - products and services that will have
// prices and balance received Characteristic - products and services characteristic that will have
// prices and balance received Batch - products and services batch that will have prices
// and balance received  PricesKind - kind of prices where the price will be extracted from
//
Function GetStructureOfBalancesAndPriceOfProduct(ToDate, ProductsAndServices, Characteristic, Batch, PriceKind, ConsolidatedByCharacteristics)
	
	DataStructure = New Structure("Balance, Reserve, AvailableBalance, Price, PriceByClassifier");
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProductsAndServicesList.Ref AS ProductsAndServices,
	|	SUM(InventoryBalances.QuantityBalance) AS Balance,
	|	SUM(&ReserveFieldOutputCondition) AS Reserve,
	|	SUM(&AvailableBalanceFieldOutputCondition) AS AvailableBalance,
	|	ProductsAndServicesPricesSliceLast.Price AS PriceByClassifier,
	|	CASE
	|		WHEN VALUETYPE(ProductsAndServicesPricesSliceLast.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProductsAndServicesPricesSliceLast.Price
	|		ELSE ProductsAndServicesPricesSliceLast.Price / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1)
	|	END AS Price
	|FROM
	|	Catalog.ProductsAndServices AS ProductsAndServicesList
	|		LEFT JOIN &QueryTitleByRegister(
	|				,
	|				ProductsAndServices = &ProductsAndServices
	|				AND Company = &Company
	|				AND &FilterConditionByWarehouse
	|				AND &FilterConditionByCell
	|				AND &FilterConditionByCharacteristics
	|				AND &FilterConditionByBatchesStatuses
	|				AND &FilterConditionByOneBatchStatus) AS InventoryBalances
	|		ON (InventoryBalances.ProductsAndServices = ProductsAndServicesList.Ref)
	|		LEFT JOIN &RegisterNameWithPricesType.SliceLast(
	|				&PricePeriod,
	|				ProductsAndServices = &ProductsAndServices
	|					AND Characteristic = VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|					AND &PriceKindFieldForComparison = &PriceKind
	|					AND ProductsAndServices.ProductsAndServicesType <> Value(Enum.ProductsAndServicesTypes.Work)) AS ProductsAndServicesPricesSliceLast
	|		ON (ProductsAndServicesPricesSliceLast.ProductsAndServices = ProductsAndServicesList.Ref)
	|WHERE
	|	ProductsAndServicesList.Ref = &ProductsAndServices
	|
	|GROUP BY
	|	ProductsAndServicesList.Ref,
	|	ProductsAndServicesPricesSliceLast.Price,
	|	CASE
	|		WHEN VALUETYPE(ProductsAndServicesPricesSliceLast.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProductsAndServicesPricesSliceLast.Price
	|		ELSE ProductsAndServicesPricesSliceLast.Price / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1)
	|	END";
	
	Query.Text = StrReplace(Query.Text, 
			"&QueryTitleByRegister", 
			?(QueryByWarehouse, "AccumulationRegister.InventoryInWarehouses.Balance", "AccumulationRegister.Inventory.Balance"));
			
	Query.Text = StrReplace(Query.Text, 
			"&FilterConditionByWarehouse",
			?(NOT (Warehouse = UNDEFINED OR Warehouse = Catalogs.StructuralUnits.EmptyRef()), "StructuralUnit = &StructuralUnit", "TRUE"));
			
	Query.Text = StrReplace(Query.Text, 
			"&FilterConditionByCell",
			?(AccountingByCells, "Cell = &StorageBin", "TRUE"));
			
	Query.Text = StrReplace(Query.Text, 
			"&FilterConditionByBatchesStatuses", 
			?(BatchStatus.Count() > 0, "(Batch = VALUE(Catalog.ProductsAndServicesBatches.EmptyREf) OR Batch.Status IN (&BatchStatus))", "TRUE"));
			
	Query.Text = StrReplace(Query.Text, 
			"&FilterConditionByOneBatchStatus", 
			?(NOT Batch = Undefined, "Batch = &Batch", "TRUE"));
			
	If ConsolidatedByCharacteristics Then
		
		Query.Text = StrReplace(Query.Text, "&FilterConditionByCharacteristics", "True");
		
	Else
		
		Query.Text = StrReplace(Query.Text, 
				"&FilterConditionByCharacteristics",
				?(Characteristic = Undefined, "Characteristic = VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)", "Characteristic = &Characteristic"));
		
	EndIf;
			
	Query.Text = StrReplace(Query.Text, 
			"&RegisterNameWithPricesType", 	
			?(CounterpartyPricesUsed, "InformationRegister.CounterpartyProductsAndServicesPrices", "InformationRegister.ProductsAndServicesPrices"));
			
	Query.Text = StrReplace(Query.Text, 
			"&PriceKindFieldForComparison", 	
			?(CounterpartyPricesUsed, "CounterpartyPriceKind", "PriceKind"));
	
	Query.Text = StrReplace(Query.Text, 
			"&ReserveFieldOutputCondition", 
			?(QueryByWarehouse, "0", "	
			|	CASE
			|		WHEN InventoryBalances.CustomerOrder = VALUE(Document.CustomerOrder.EmptyREf)
			|			THEN 0
			|		ELSE InventoryBalances.QuantityBalance
			|	END "));
	
	Query.Text = StrReplace(Query.Text, 
			"&AvailableBalanceFieldOutputCondition", 
			?(QueryByWarehouse, "0", "
			|	InventoryBalances.QuantityBalance - CASE
			|		WHEN InventoryBalances.CustomerOrder = VALUE(Document.CustomerOrder.EmptyREf)
			|			THEN 0
			|		ELSE InventoryBalances.QuantityBalance
			|	END "));
	
	Query.SetParameter("PricePeriod",		ToDate);
	Query.SetParameter("Company", 	Company);
	Query.SetParameter("StructuralUnit", Warehouse);
	Query.SetParameter("StorageBin", Cell);
	Query.SetParameter("ProductsAndServices", 	ProductsAndServices);
	Query.SetParameter("Characteristic", Characteristic);
	Query.SetParameter("Batch", 		Batch);
	Query.SetParameter("BatchStatus", 	BatchStatus);
	Query.SetParameter("PriceKind", 		?(CounterpartyPricesUsed, CounterpartyPriceKind, PriceKind));
	
	Selection	= Query.Execute().Select();
	
	Selection.Next();
	FillPropertyValues(DataStructure, Selection);
	
	Return DataStructure;
	
EndFunction // GetBalancesStructureAndPriceByProduct()

&AtServer
// Procedure updates the "Selection" form data on server
//
// The execution condition is either the change of form display user parameters or change of the company, structural unit
//
Procedure UpdateDataOfFormAtServer(CatalogGroupSelected = Undefined)
	
	SettingsStructure 			= GetPickSettings();
	
	// ProductsAndServices hierarchy
	If Not ValueIsFilled(CatalogGroupSelected) Then
		
		ProductsAndServicesGroup = ?(SettingsStructure.KeepCurrentHierarchy,
			SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "FilterGroup"),
			Catalogs.ProductsAndServices.EmptyRef());
			
	Else
		
		ProductsAndServicesGroup = CatalogGroupSelected;
		
	EndIf;
	
	Items.InventoryHierarchy.CurrentRow	= ProductsAndServicesGroup;
	
	// Texts of requests
	SetQueryTextOfInventoryList(SettingsStructure);
	
	SetQueryTextOfCharacteristicsList(SettingsStructure);
	
	// Visible
	SetVisibleOfDynamicListFields(SettingsStructure);
	
	// Filter by group
	Items.InventoryListContextMenuFilterByGroup.Check = ValueIsFilled(ProductsAndServicesGroup);
	UpdateFilterByGroupOfDynamicLists(Items.InventoryListContextMenuFilterByGroup.Check, ProductsAndServicesGroup);
	
	If JustOpened Then
		
		Items.InventoryListRequestQuantityAndPrices.Check = SettingsStructure.RequestQuantityAndPrice;
		Items.ListOfBalancesRequestQuantityAndPrice.Check = SettingsStructure.RequestQuantityAndPrice;
		RequestQuantity 										= SettingsStructure.RequestQuantityAndPrice;
		
	EndIf;
	
EndProcedure // UpdateFormDataAtServer()

&AtServer
//Procedure updates the Inventory and Characteristics dynamic lists
//
Procedure UpdateFilterByGroupOfDynamicLists(ApplyFilterByGroup, ProductsAndServicesGroupToFilter)
	
	If ApplyFilterByGroup Then
		
		SmallBusinessClientServer.SetListFilterItem(InventoryList, 			"ProductsAndServices.Parent", ProductsAndServicesGroupToFilter, True, DataCompositionComparisonType.InHierarchy);
		SmallBusinessClientServer.SetListFilterItem(CharacteristicsList,	"ProductsAndServices.Parent", ProductsAndServicesGroupToFilter, True, DataCompositionComparisonType.InHierarchy);
		
	Else
		
		SmallBusinessClientServer.DeleteListFilterItem(InventoryList,		"ProductsAndServices.Parent");
		SmallBusinessClientServer.DeleteListFilterItem(CharacteristicsList,	"ProductsAndServices.Parent");
		
	EndIf;
	
EndProcedure //UpdateFilterByDynamicListsGroup()

//////////////////////////////////////////////////////////////////////////////// 
// COMMAND HANDLERS

&AtClient
// Procedure - handler of the Create command.
//
Procedure Create(Command)
	
	FillValue = New Structure;	
	FillValue.Insert("IsFolder", False);
	FillValue.Insert("Parent", ProductsAndServicesGroup);
	
	If ProductsAndServicesType.Count() > 0 Then
		
		FillValue.Insert("ProductsAndServicesType", ProductsAndServicesType[0].Value);
		
	EndIf;
	
	OpenForm("Catalog.ProductsAndServices.ObjectForm", New Structure("FillingValues", FillValue), ThisForm);
	
EndProcedure //Create()

&AtClient
// Procedure - handler of the Change command.
//
Procedure Change(Command)
	
	If Items.InventoryList.CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpeningStructure = New Structure("Key", Items.InventoryList.CurrentData.ProductsAndServices);
	OpenForm("Catalog.ProductsAndServices.ObjectForm", OpeningStructure, ThisForm);
	
EndProcedure //Change()

&AtClient
// Procedure - handler of the Copy command.
//
Procedure Copy(Command)
	
	If Items.InventoryList.CurrentData = Undefined Then
		Return;
	EndIf;
	
	CopyingValue = New Structure("CopyingValue", Items.InventoryList.CurrentData.ProductsAndServices);
	OpenForm("Catalog.ProductsAndServices.ObjectForm", CopyingValue, ThisForm);
	
EndProcedure //Copy()

&AtClient
//Procedure - OK button click handler.
//
Procedure OK(Command)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("CommonFormPickForm");
	// End StandardSubsystems.PerformanceEstimation
	
	InventoryAddressInStorage = WritePickToStorage();
	
	If Not ValueIsFilled(QueryResultIntoNewDocument) Then
		
		Notify("SelectionIsMade", 
			InventoryAddressInStorage, 
				?(OwnerFormUUID = New UUID("00000000-0000-0000-0000-000000000000"), Undefined, OwnerFormUUID));
		
		Close();
		
	Else
		
		FillStructure = New Structure;
		FillStructure.Insert("Company", 			Company);
		FillStructure.Insert("StructuralUnit", 		Warehouse);
		FillStructure.Insert("AmountIncludesVAT",		UsingVAT);
		FillStructure.Insert("AreCharacteristics", 		CharacteristicsUsed);
		FillStructure.Insert("AreBatches",				BatchesUsed);
		FillStructure.Insert("InventoryAddressInStorage", 	InventoryAddressInStorage);
		
		If OperationKindJobOrder Then
			FillStructure.Insert("OperationKind", PredefinedValue("Enum.OperationKindsCustomerOrder.JobOrder"));
			FillStructure.Insert("TabularSectionName", "Works");
		Else
			FillStructure.Insert("TabularSectionName", "Inventory");
		EndIf;
		
		OpenForm("Document."+ QueryResultIntoNewDocument +".ObjectForm", New Structure("FillingValues", FillStructure));
		
		Close();
		
	EndIf;
	
EndProcedure // Ok()

&AtClient
//Procedure - handler of clicking the Refresh button.
//
Procedure Refresh(Command)
	
	UpdateDataOfFormAtServer();
	
EndProcedure

&AtClient
//Procedure - handler of the "GetBackToProductsAndServices" command
//
Procedure PickGetBackToProductsAndServices(Command)
	
	Items.PagesGroup.CurrentPage	= Items.PagesGroup.ChildItems.PageInventoryList;
	
	Items.CommandBarInventoryAndCharacteristics.CurrentPage = 
		Items.PageCommandBarInventory;
	
	AttachIdleHandler("PickInventoryListOnActivateRowIdleHandler",0.2,True);
	
EndProcedure //PickGetBackToProductsAndServices()

&AtClient
// Procedure - handler of the "GoToCharacteristics" command
//
Procedure PickGoToCharacteristics(Command)
	
	Items.CommandBarInventoryAndCharacteristics.CurrentPage = 
			Items.PageCommandBarCharacteristics;
			
	GoToCharacteristics(Items.InventoryList.CurrentData, True);
	
EndProcedure // PickGoToCharacteristics()

&AtClient
// Procedure - handler of the "SelectionSetup" command
//
//
Procedure MultiplePickSetting(Command)
	
	Notification = New NotifyDescription("PickupSettingEnd",ThisForm);
	OpenForm("CommonForm.MultiplePickSettingForm", , ThisForm,,,,Notification);
	
EndProcedure // SelectionSetup()

&AtClient
Procedure PickupSettingEnd(NewSettings,Parameters) Export
	
	If Not TypeOf(NewSettings) = Type("Structure") Then
		
		Return;
		
	EndIf;
	
	RefreshForm = False;
	For Each SettingRecord IN SettingsStructure Do
		
		If NewSettings.Property(SettingRecord.Key)
			AND Not SettingRecord.Value = NewSettings[SettingRecord.Key] Then
			
			RefreshForm = True;
			Break;
			
		EndIf;
		
	EndDo;
	
	If RefreshForm Then
		
		UpdateDataOfFormAtServer();
		
	EndIf;
	
EndProcedure

//Procedure - handler of clicking the FilterByGroup button.
//
&AtClient
Procedure FilterByGroup(Command)
	
	Items.InventoryListContextMenuFilterByGroup.Check = Not Items.InventoryListContextMenuFilterByGroup.Check;
	
	UpdateFilterByGroupOfDynamicLists(Items.InventoryListContextMenuFilterByGroup.Check, ProductsAndServicesGroup);
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////// 
// FORM EVENTS AND FORM ATTRIBUTES HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// If the filter is called
	// from functions menu then parameters shall be
	// filled in independently with default values and continue the form opening
	If Parameters.Property("CreateNewDocument")
		AND Parameters.CreateNewDocument Then
		
		Items.Company.Enabled	= True;
		StructureOfParametersByDefault		= New Structure;
		
		FillGenerateFormOpeningParametersWithValuesByDefault(StructureOfParametersByDefault, Parameters);
		
		FormOpenParameters				= StructureOfParametersByDefault;
		QueryResultIntoNewDocument		= Parameters.KindOfNewDocument;
		Items.Warehouse.Enabled			= True; 
		
	Else
		
		Items.Company.Enabled	= False;
		FormOpenParameters				= Parameters;
		Items.Warehouse.Enabled			= False; 
		
		If FormOpenParameters.Property("AvailableStructuralUnitEdit") Then
			
			Items.Warehouse.Enabled			= FormOpenParameters.AvailableStructuralUnitEdit; 
			
		EndIf;
		
		OwnerFormUUID = FormOpenParameters.OwnerFormUUID;
		
	EndIf;
	
	If FormOpenParameters.Property("Period") Then
		
		Period = FormOpenParameters.Period;
		
	Else
		
		Period = CurrentDate();
		
	EndIf;
	
	JustOpened = True;
	Company		= FormOpenParameters.Company;
	
	NormsUsed = FormOpenParameters.Property("NormsUsed");
	Items.FilteredInventoryMeasurementUnit.Visible = Not NormsUsed;
	
	If FormOpenParameters.Property("DocumentInventoryAddress")
		AND ValueIsFilled(FormOpenParameters.DocumentInventoryAddress) Then
		
		ImportInventoryFromStorage(FormOpenParameters.DocumentInventoryAddress, FilteredInventory);
		
	EndIf;
	
	If FormOpenParameters.Property("StructuralUnit") Then
		
		Warehouse = FormOpenParameters.StructuralUnit;
		
	EndIf;
	
	//If backup is enabled, then fill the backup parameters
	If Constants.FunctionalOptionInventoryReservation.Get() Then
		
		FormOpenParameters.Property("FillReserve", FillReserve); //Only for customer orders.
		
	EndIf;
	
	QueryByWarehouse = FormOpenParameters.Property("QueryByWarehouse");
	
	AccountingByCells	= (QueryByWarehouse AND Constants.FunctionalOptionAccountingByCells.Get() AND FormOpenParameters.Property("Cell"));
	
	If AccountingByCells Then
		
		Cell = FormOpenParameters.Cell;
		
	EndIf;
	
	// ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	// PARAMETERS OF DYNAMIC LISTS QUERIES
	
	//Product and services types
	GenerateUsedProductsAndServicesTypes(FormOpenParameters);
	
	//Statuses of Batches
	GenerateUsedBatchStatuses(FormOpenParameters);
	
	//Prices
	PricingInVariousUOM = Constants.FunctionalOptionAccountingInVariousUOM.Get();
	
	PricesUsed = False;
	If FormOpenParameters.Property("PriceKind") Then
		
		PricesUsed 		= True;
		PriceKind 					= FormOpenParameters.PriceKind;
		
		If ValueIsFilled(PriceKind) Then
			
			PriceIncludesVAT					= PriceKind.PriceIncludesVAT;
			PriceKindsRoundingOrder			= PriceKind.RoundingOrder;
			PriceKindsRoundUp	= PriceKind.RoundUp;
			Currency 							= FormOpenParameters.Currency;
			PriceKindCurrency					= PriceKind.PriceCurrency;
			
			If Currency <> PriceKindCurrency Then
				
				CurrencyRatesStructure = SmallBusinessServer.GetCurrencyRates(PriceKindCurrency, Currency, Period);
				
				RatePriceKindCurrency = CurrencyRatesStructure.InitRate;
				CurrencyMultiplicityPriceKind = CurrencyRatesStructure.RepetitionBeg;
				
				RateDocumentCurrency = CurrencyRatesStructure.ExchangeRate;
				RepetitionDocumentCurrency = CurrencyRatesStructure.Multiplicity;
				
			EndIf;
			
		Else
			
			PriceIncludesVAT					= True;
			PriceKindsRoundingOrder			= Enums.RoundingMethods.Round0_01;
			PriceKindsRoundUp	= False;
			Currency 							= Constants.NationalCurrency.Get();
			
		EndIf;
		
		
		AmountIncludesVAT 		= FormOpenParameters.AmountIncludesVAT;
		DocumentOrganization	= FormOpenParameters.DocumentOrganization;
		
		TextPricePresentation	= ?(ValueIsFilled(PriceKind), "(" + PriceKind.Description + ")", "(Kind of prices is not specified)");
		
		Items.InventoryListPrice.Title = "Price" + Chars.LF + TextPricePresentation;
		Items.InventoryListPriceByClassifier.Title = "Price" + Chars.LF + TextPricePresentation;
		
		Items.CharacteristicsListPrice.Title = "Price" + Chars.LF + TextPricePresentation;
		Items.CharacteristicsListPriceByClassifier.Title = "Price" + Chars.LF + TextPricePresentation;
		
	ElsIf FormOpenParameters.Property("PriceKindsByWorkKinds") Then
		
		PriceKind				= FormOpenParameters.PriceKindsByWorkKinds;
		Currency				= FormOpenParameters.Currency;
		AmountIncludesVAT	= FormOpenParameters.AmountIncludesVAT;
		
	EndIf;
	
	CounterpartyPricesUsed = False;
	If FormOpenParameters.Property("CounterpartyPriceKind") Then
		
		CounterpartyPricesUsed = True;
		CounterpartyPriceKind 			= FormOpenParameters.CounterpartyPriceKind;
		
		If ValueIsFilled(CounterpartyPriceKind) Then
			
			PriceIncludesVAT		= CounterpartyPriceKind.PriceIncludesVAT;
			
			PriceKindCurrency		= CounterpartyPriceKind.PriceCurrency;
			If Currency <> PriceKindCurrency Then
				
				CurrencyRatesStructure = SmallBusinessServer.GetCurrencyRates(PriceKindCurrency, Currency, Period);
				
				RatePriceKindCurrency = CurrencyRatesStructure.InitRate;
				CurrencyMultiplicityPriceKind = CurrencyRatesStructure.RepetitionBeg;
				
				RateDocumentCurrency = CurrencyRatesStructure.ExchangeRate;
				RepetitionDocumentCurrency = CurrencyRatesStructure.Multiplicity;
				
			EndIf;
			
		Else
			
			PriceIncludesVAT		= True;
			
		EndIf;
		
		PriceKindsRoundingOrder = Enums.RoundingMethods.Round0_01;
		PriceKindsRoundUp = False;
		Currency 					= FormOpenParameters.Currency;
		AmountIncludesVAT 		= FormOpenParameters.AmountIncludesVAT;
		DocumentOrganization	= FormOpenParameters.DocumentOrganization;
		
	EndIf;
	
	//If the currency is filled then correct information line header
	If ValueIsFilled(Currency) Then
		
		NewHeaderRow 						= NStr("en='Products were selected to the amount of (%InCurrency%)';ru='Товаров подобрано на сумму (%ВВалюте%)'");
		Items.InformationLabel.Title	= StrReplace(NewHeaderRow, "%InCurrency%", Currency.Description);
		
	EndIf;
	
	//Set the characteristics and batches list display
	ThisIsReceiptDocument = False;
	If FormOpenParameters.Property("ThisIsReceiptDocument") Then
		
		ThisIsReceiptDocument = FormOpenParameters.ThisIsReceiptDocument;
		
		If ThisIsReceiptDocument Then
			NewConnectionsClear = New ChoiceParameterLink("Filter.Owner", "Items.FilteredInventory.CurrentData.ProductsAndServices");
			NewConnectionsDontChange = New ChoiceParameterLink("ThisIsReceiptDocument", "ThisIsReceiptDocument", LinkedValueChangeMode.DontChange);
			NewArray = New Array();
			NewArray.Add(NewConnectionsClear);
			NewArray.Add(NewConnectionsDontChange);
			NewConnections = New FixedArray(NewArray);
			Items.FilteredInventoryCharacteristic.ChoiceParameterLinks = NewConnections;
			
		EndIf;
		
	EndIf;
	
	//Settings of dynamic lists
	UpdateDataOfFormAtServer();
	
	// Discount
	DiscountsMarkupsUsed = False;
	If FormOpenParameters.Property("DiscountMarkupKind")
		AND ValueIsFilled(FormOpenParameters.DiscountMarkupKind) Then
		
		DiscountsMarkupsUsed	= True;
		DiscountMarkupKind 			= FormOpenParameters.DiscountMarkupKind;
		
	EndIf;
	
	// Discount card
	DiscountCardsAreUsed = False;
	If FormOpenParameters.Property("DiscountCard")
		AND ValueIsFilled(FormOpenParameters.DiscountCard) Then
		
		DiscountCardsAreUsed		= True;
		DiscountPercentByDiscountCard 	= FormOpenParameters.DiscountPercentByDiscountCard;
		
	EndIf;
	
	// VAT Taxation and Total Amount enabled VAT
	VATTaxation 		= ?(FormOpenParameters.Property("VATTaxation"), FormOpenParameters.VATTaxation, Undefined);
	If FormOpenParameters.Property("AmountIncludesVAT") Then
		
		UsingVAT			= FormOpenParameters.AmountIncludesVAT;
		DocumentOrganization	= FormOpenParameters.DocumentOrganization;
		
	EndIf;
	
	If FormOpenParameters.Property("AccrualVATRate") Then
		AccrualVATRate = FormOpenParameters.AccrualVATRate;
	EndIf;
	
	UseTypeOfWorks = FormOpenParameters.Property("WorkKind");
	If UseTypeOfWorks Then
		
		WorkKind = FormOpenParameters.WorkKind;
		
	EndIf;

	SpecificationsUsed	= FormOpenParameters.Property("SpecificationsUsed");
	
	If FormOpenParameters.Property("AvailablePriceChanging", AvailablePriceChanging) Then
		
		Items.FilteredInventoryPrice.ReadOnly = Not AvailablePriceChanging;
		Items.FilteredInventoryDiscountMarkupPercent.ReadOnly = Not AvailablePriceChanging;
		Items.FilteredInventoryVATAmount.ReadOnly = Not AvailablePriceChanging;
		Items.FilteredInventoryAmount.ReadOnly = Not AvailablePriceChanging;
		
	EndIf;
	
	CharacteristicsUsed 	= Constants.FunctionalOptionUseCharacteristics.Get() 
			AND ?(FormOpenParameters.Property("CharacteristicsUsed"), FormOpenParameters.CharacteristicsUsed, True);
			
	BatchesUsed 			= Constants.FunctionalOptionUseBatches.Get() 
			AND ?(FormOpenParameters.Property("BatchesUsed"), FormOpenParameters.BatchesUsed, True);
		
	ManagementOfFormItemsVisible(FormOpenParameters);
	SetVisibleOfDynamicListFields(SettingsStructure);
	
	// Additional price column displaying check
	If FormOpenParameters.Property("ShowPriceColumn") Then
		
		Items.FilteredInventoryPrice.Visible = FormOpenParameters.ShowPriceColumn;
		
	EndIf;
	
	// Setting the method of structural unit selection depending on FO.
	If Not Constants.FunctionalOptionAccountingByMultipleDivisions.Get()
		AND Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
		
		Items.Warehouse.ListChoiceMode = True;
		Items.Warehouse.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		Items.Warehouse.ChoiceList.Add(Catalogs.StructuralUnits.MainDivision);
		
	EndIf;
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure - OnOpen form event handler
//
Procedure OnOpen(Cancel)
	
	JustOpened = False;
	
EndProcedure

&AtClient
// Procedure - handler of form notification.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshPickup" Then
		
		UpdateDataOfFormAtServer();
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - handler events ChoiceProcessing PM InventoryHierarchy.
//
Procedure InventoryHierarchyChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	ProductsAndServicesGroup = ValueSelected;
	UpdateDataOfFormAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the Goods list selection event.
//
Procedure ProductsListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	ProductsListRow = Item.CurrentData;
	
	If (CharacteristicsUsed OR BatchesUsed) 
		AND (ProductsListRow.UseCharacteristics OR ProductsListRow.UseBatches)Then
		
		GoToCharacteristics(ProductsListRow);
		
	Else
		
		If Not SettingsStructure.ShowPrices Then
			
			PriceForCart = 0;
			
		ElsIf TrimAll(SettingsStructure.OutputBalancesMethod) = "Separately" Then
			
			If CacheInventoryListCurrentRow <> Items.InventoryList.CurrentRow Then
				
				DetachIdleHandler("PickInventoryListOnActivateRowIdleHandler");
				PickInventoryListOnActivateRowIdleHandler();
				
			EndIf;
			
			PriceForCart = TextPrice;
			
		Else
			
			PriceForCart = ?(PricingInVariousUOM, ProductsListRow.PriceByClassifier, ProductsListRow.Price);
			
		EndIf;
		
		ChangeProductInCart(ProductsListRow, , , 1, PriceForCart);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event for "Warehouse" attribute
// 
Procedure WarehouseOnChange(Item)
	
	UpdateDataOfFormAtServer();
	
EndProcedure

&AtClient
//Procedure - handler of the OnChange event for "Organization" attribute
//
Procedure CompanyOnChange(Item)
	
	If ValueIsFilled(Company) Then
		
		UpdateDataOfFormAtServer();
		
	Else
		
		Message 				= New UserMessage;
		Message.Text 		= NStr("en='Fill company to update data of the form';ru='Для обновление данных формы заполните организацию'");
		Message.DataPath	= "Company";
		Message.Message();
		
	EndIf;
	
EndProcedure // CompanyOnChange()

&AtClient
// Procedure - handler of the OnChange event of the ProductsAndServices field in the FilteredInventory tabular section
//
Procedure FilteredInventoryProductsAndServicesOnChange(Item)
	
	DataStructure		= GenerateDataStructureOfCurrentFilterSession();
	ProductsAndServicesData	= GetDataProductsAndServicesOnChange(DataStructure);
	
	CurrentRowOfFilteredInventory = Items.FilteredInventory.CurrentData;
	
	CurrentRowOfFilteredInventory.MeasurementUnit = ProductsAndServicesData.MeasurementUnit;
	CurrentRowOfFilteredInventory.Price 			= ProductsAndServicesData.Price;
	CurrentRowOfFilteredInventory.VATRate 		= ProductsAndServicesData.VATRate;
	
	If CurrentRowOfFilteredInventory.Quantity = 0 Then
		
		CurrentRowOfFilteredInventory.Quantity = 1;
		
	EndIf;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // FilteredInventoryProductsAndServicesOnChange()

&AtClient
// Procedure - handler of the OnChange event of the Characteristic  field in FilteredInventory tabular section
//
Procedure FilteredInventoryCharacteristicOnChange(Item)
	
	DataStructure		= GenerateDataStructureOfCurrentFilterSession();
	ProductsAndServicesData	= GetDataProductsAndServicesOnChange(DataStructure);
	
	CurrentRowOfFilteredInventory = Items.FilteredInventory.CurrentData;
	
	CurrentRowOfFilteredInventory.MeasurementUnit = ProductsAndServicesData.MeasurementUnit;
	CurrentRowOfFilteredInventory.Price 			= ProductsAndServicesData.Price;
	CurrentRowOfFilteredInventory.VATRate 		= ProductsAndServicesData.VATRate;
	
	If CurrentRowOfFilteredInventory.Quantity = 0 Then
		
		CurrentRowOfFilteredInventory.Quantity = 1;
		
	EndIf;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // FilteredInventoryCharacteristicOnChange()

&AtClient
// Procedure - handler of the DragStart event of PM InventoryList.
//
Procedure InventoryListDragStart(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	ProductsListRow = Item.CurrentData;
	
	If Not SettingsStructure.ShowPrices Then
		
		PriceForCart = 0;
		
	ElsIf TrimAll(SettingsStructure.OutputBalancesMethod) = "Separately" Then
		
		If CacheInventoryListCurrentRow <> Items.InventoryList.CurrentRow Then
			
			DetachIdleHandler("PickInventoryListOnActivateRowIdleHandler");
			PickInventoryListOnActivateRowIdleHandler();
			
		EndIf;
		
		PriceForCart = TextPrice;
		
	Else
		
		PriceForCart = ?(PricingInVariousUOM, ProductsListRow.PriceByClassifier, ProductsListRow.Price);
		
	EndIf;
	
	ChangeProductInCart(ProductsListRow, , , 1, PriceForCart);
	
EndProcedure // InventoryListDragStart()

&AtClient
// Procedure - handler of the DragCheck event PM FilteredInventory.
//
Procedure FilteredInventoryDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	DragParameters.Action = DragAction.Copy;
	StandardProcessing = False;
	
EndProcedure // FilteredInventoryDragCheck()

&AtClient
// Procedure - handler of
// the "OnActivateRow" event of the "Inventory" tabular section
Procedure InventoryListOnActivateRow(Item)
	
	CurrentRow	= Items.InventoryList.CurrentData;
	If CurrentRow = Undefined Then 
		
		Items.InventoryListGoToCharacteristics.Enabled = False;
		
	Else
		
		Items.InventoryListGoToCharacteristics.Enabled = (CharacteristicsUsed OR BatchesUsed) AND (CurrentRow.UseBatches OR CurrentRow.UseCharacteristics);
		
	EndIf;
	
	If CacheInventoryListCurrentRow <> Items.InventoryList.CurrentRow Then
	
		AttachIdleHandler("PickInventoryListOnActivateRowIdleHandler",0.2,True);
		//CacheInventoryListCurrentRow = Items.InventoryList.CurrentRow;
		
	EndIf;
	
EndProcedure //InventoryListOnActivateRow()

&AtClient
// Procedure - handler of
// the "OnActivateRow" event of "Characteristics" tabular section
Procedure CharacteristicsListOnActivateRow(Item)
	
	CurrentRow	= Items.CharacteristicsList.CurrentData;
	
	If CurrentRow = Undefined 
		Or Items.PagesGroup.CurrentPage = Items.PageInventoryList Then 
		
		Return;
		
	EndIf;
	
	AttachIdleHandler("PickCharacteristicsListOnActivateRowIdleHandler",0.2,True);

EndProcedure //CharacteristicsListOnActivateRow()

&AtClient
// Procedure - handler for
// "Selection" event of "Characteristics" tabular field
Procedure CharacteristicsListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ProductsListRow = Items.InventoryList.CurrentData;
	
	If Not ProductsListRow = Undefined Then
		
		If Not SettingsStructure.ShowPrices Then
			
			PriceForCart = 0;
			
		ElsIf TrimAll(SettingsStructure.OutputBalancesMethod) = "Separately" Then
			
			If CacheInventoryListCurrentRow <> Items.InventoryList.CurrentRow Then
				
				DetachIdleHandler("PickInventoryListOnActivateRowIdleHandler");
				PickInventoryListOnActivateRowIdleHandler();
				
			EndIf;
			
			PriceForCart = TextPrice;
			
		Else
			
			PriceForCart = ?(PricingInVariousUOM, Item.CurrentData.PriceByClassifier, Item.CurrentData.Price);
			
		EndIf;
		
		ChangeProductInCart(ProductsListRow, Item.CurrentData, , 1, PriceForCart);
		
	EndIf;
	
EndProcedure // CharacteristicsListSelection()

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure FilteredInventoryCountOnChange(Item)
	
	CurrentRow = Items.FilteredInventory.CurrentData;
	
	If CurrentRow.Property("Reserve")
		AND CurrentRow.Reserve <> 0 
		AND CurrentRow.Quantity < CurrentRow.Reserve Then
		
		CurrentRow.Reserve = CurrentRow.Quantity;
		
	EndIf;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // FilteredInventoryCountOnChange()

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure FilteredInventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // FilteredInventoryPriceOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure FilteredInventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.FilteredInventory.CurrentData;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure  // ProductsVATRateOnChange()

&AtClient
// Procedure - handler of the OnCurrentParentChange event of PM InventoryHierarchy.
//
Procedure InventoryHierarchyOnCurrentParentChange(Item)
	
	If ProductsAndServicesGroup = Item.CurrentParent Then
		
		Return;
		
	EndIf;
	
	ProductsAndServicesGroup = Item.CurrentParent;
	Items.PagesGroup.CurrentPage = Items.PageInventoryList;
	
	If ValueIsFilled(ProductsAndServicesGroup) Then
		
		Items.InventoryListContextMenuFilterByGroup.Check = True;
		UpdateFilterByGroupOfDynamicLists(True, ProductsAndServicesGroup);
		
	Else
		
		Items.InventoryListContextMenuFilterByGroup.Check = False;
		UpdateFilterByGroupOfDynamicLists(False, ProductsAndServicesGroup);
		
	EndIf;
	
EndProcedure // InventoryHierarchyOnCurrentParentChange()

&AtClient
Procedure InventoryHierarchyOnActivateRow(Item)
	
	Items.PagesGroup.CurrentPage	= Items.PageInventoryList;
	Items.CommandBarInventoryAndCharacteristics.CurrentPage = Items.PageCommandBarInventory;
	
	Value = Items.InventoryHierarchy.CurrentData;
	
	If Not Value = Undefined
		AND ValueIsFilled(Value.ProductsAndServicesRef) Then
		
		Items.InventoryListContextMenuFilterByGroup.Check = True;
		ProductsAndServicesGroup = Value.ProductsAndServicesRef;
		UpdateFilterByGroupOfDynamicLists(True, ProductsAndServicesGroup);
		
	Else
		
		Items.InventoryListContextMenuFilterByGroup.Check = False;
		ProductsAndServicesGroup = Undefined;
		UpdateFilterByGroupOfDynamicLists(False, ProductsAndServicesGroup);
		
	EndIf;
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the add product to cart result
//
//
Procedure AfterQuantityAndPriceRequestAddProductToCart(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		UnitDimensions	= ?(ClosingResult.Property("MeasurementUnit"), ClosingResult.MeasurementUnit, Undefined);
		Quantity	= ?(ClosingResult.Property("Quantity"), ClosingResult.Quantity, AdditionalParameters.Quantity);
		Price 		= ?(ClosingResult.Property("Price"), ClosingResult.Price, AdditionalParameters.Price);
		
		//Apply rounding rules from the company price kind
		If ValueIsFilled(PriceKind) Then
			
			Price = RoundPrice(Price, PriceKindsRoundingOrder, PriceKindsRoundUp);
			
		EndIf;
		
		ChangeAddRowToCart(AdditionalParameters.ProductsListRow, AdditionalParameters.RowCharacteristicsOfBatches, AdditionalParameters.StringCart, Quantity, Price, AdditionalParameters.AvailableBalance, UnitDimensions);
		
	EndIf;
	
EndProcedure // DetermineNeedForDocumentFillByBasis()

#EndRegion













