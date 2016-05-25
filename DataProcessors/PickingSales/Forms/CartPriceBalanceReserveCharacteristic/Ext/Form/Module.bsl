
////////////////////////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE
//

// Full-text search

&AtServerNoContext
// Function fills in an array of search result references or returns an error description
//
//
Function FullTextSearchOnServerWithoutContext(SearchString, SearchResult)
	
	ErrorDescription = "";
	SearchResult = PickProductsAndServicesInDocumentsOverridable.SearchGoods(SearchString, ErrorDescription);
	
	Return ErrorDescription;
	
EndFunction // FullTextSearchOnServerWithoutContext()

&AtClient
// Procedure sets a filter by references received using a full-text search
//
Procedure FulltextSearchOnClient()
	
	If Not IsBlankString(SearchText) Then
		
		SearchResult = Undefined;
		ErrorDescription = FullTextSearchOnServerWithoutContext(SearchText, SearchResult);
		
		If IsBlankString(ErrorDescription) Then
			
			//::: Products and services
			Use = SearchResult.ProductsAndServices.Count() > 0;
			ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(ListInventory.SettingsComposer.FixedSettings.Filter, "ProductsAndServicesRef");
			If ItemArray.Count() = 0 Then
				
				CommonUseClientServer.AddCompositionItem(ListInventory.SettingsComposer.FixedSettings.Filter, "ProductsAndServicesRef", DataCompositionComparisonType.InList, SearchResult.ProductsAndServices, , Use);
				
			Else
				
				CommonUseClientServer.ChangeFilterItems(ListInventory.SettingsComposer.FixedSettings.Filter, "ProductsAndServicesRef", , SearchResult.ProductsAndServices, DataCompositionComparisonType.InList, Use);
				
			EndIf;
			
			//::: Characteristics
			Use = SearchResult.ProductsAndServicesCharacteristics.Count() > 0;
			CharacteristicItemsArray = CommonUseClientServer.FindFilterItemsAndGroups(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "CharacteristicRef");
			If CharacteristicItemsArray.Count() = 0 Then
				
				CommonUseClientServer.AddCompositionItem(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "CharacteristicRef", DataCompositionComparisonType.InList, SearchResult.ProductsAndServicesCharacteristics, , Use);
				
			Else
				
				CommonUseClientServer.ChangeFilterItems(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "CharacteristicRef", , SearchResult.ProductsAndServicesCharacteristics, DataCompositionComparisonType.InList, Use);
				
			EndIf;
			
			If Items.PagesProductsAndServicesCharacteristics.CurrentPage = Items.PageProductsAndServices Then
				
				ThisForm.CurrentItem = Items.ListInventory;
				
			Else
				
				ThisForm.CurrentItem = Items.CharacteristicsList;
				
			EndIf;
			
		Else
			
			ShowMessageBox(Undefined, ErrorDescription, 5, "Search...");
			
		EndIf;
		
	EndIf;
	
EndProcedure // FulltextSearchOnClient()

// Procedure sets a filter by references received using a context search
//
Procedure ContextSearchOnClient()
	
	FieldsGroupPresentation = "Context search";
	
	If IsBlankString(SearchText) Then
		
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(ListInventory, , FieldsGroupPresentation);
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(CharacteristicsList, , FieldsGroupPresentation);
		
	Else
		
		//::: Products and services
		ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(ListInventory.SettingsComposer.FixedSettings.Filter, , FieldsGroupPresentation);
		If ItemArray.Count() = 0 Then
			
			FilterGroupProductsAndServices = CommonUseClientServer.CreateGroupOfFilterItems(ListInventory.SettingsComposer.FixedSettings.Filter.Items, FieldsGroupPresentation, DataCompositionFilterItemsGroupType.OrGroup);
			
			CommonUseClientServer.AddCompositionItem(FilterGroupProductsAndServices, "ProductsAndServicesRef.Name", DataCompositionComparisonType.Contains, SearchText, "Name of the products and services", True, DataCompositionSettingsItemViewMode.Normal);
			CommonUseClientServer.AddCompositionItem(FilterGroupProductsAndServices, "ProductsAndServicesRef.DescriptionFull", DataCompositionComparisonType.Contains, SearchText, "Full name of products and services", True, DataCompositionSettingsItemViewMode.Normal);
			CommonUseClientServer.AddCompositionItem(FilterGroupProductsAndServices, "ProductsAndServicesRef.SKU", DataCompositionComparisonType.Contains, SearchText, "SKU of products and services", True, DataCompositionSettingsItemViewMode.Normal);
			CommonUseClientServer.AddCompositionItem(FilterGroupProductsAndServices, "ProductsAndServicesGroup.Name", DataCompositionComparisonType.Contains, SearchText, "Products and services category", True, DataCompositionSettingsItemViewMode.Normal);
			CommonUseClientServer.AddCompositionItem(FilterGroupProductsAndServices, "PriceGroup.Name", DataCompositionComparisonType.Contains, SearchText, "Price group", True, DataCompositionSettingsItemViewMode.Normal);
			
		Else
			
			CommonUseClientServer.ChangeFilterItems(ItemArray[0], "ProductsAndServicesRef.Name", "Name of the products and services", SearchText, DataCompositionComparisonType.Contains, True, DataCompositionSettingsItemViewMode.Normal);
			CommonUseClientServer.ChangeFilterItems(ItemArray[0], "ProductsAndServicesRef.DescriptionFull", "Full name of products and services", SearchText, DataCompositionComparisonType.Contains, True, DataCompositionSettingsItemViewMode.Normal);
			CommonUseClientServer.ChangeFilterItems(ItemArray[0], "ProductsAndServicesRef.SKU", "SKU of products and services", SearchText, DataCompositionComparisonType.Contains, True, DataCompositionSettingsItemViewMode.Normal);
			CommonUseClientServer.ChangeFilterItems(ItemArray[0], "ProductsAndServicesGroup.Name", "Products and services category", SearchText, DataCompositionComparisonType.Contains, True, DataCompositionSettingsItemViewMode.Normal);
			CommonUseClientServer.ChangeFilterItems(ItemArray[0], "PriceGroup.Name", "Price group", SearchText, DataCompositionComparisonType.Contains, True, DataCompositionSettingsItemViewMode.Normal);
			
		EndIf;
		
		//::: Characteristics
		CharacteristicItemsArray = CommonUseClientServer.FindFilterItemsAndGroups(CharacteristicsList.SettingsComposer.FixedSettings.Filter, , FieldsGroupPresentation);
		If CharacteristicItemsArray.Count() = 0 Then
			
			CharacteristicsFilterGroup = CommonUseClientServer.CreateGroupOfFilterItems(CharacteristicsList.SettingsComposer.FixedSettings.Filter.Items, FieldsGroupPresentation, DataCompositionFilterItemsGroupType.OrGroup);
			CommonUseClientServer.AddCompositionItem(CharacteristicsFilterGroup, "CharacteristicsRef.Name", DataCompositionComparisonType.Contains, SearchText, "Characteristics description", True, DataCompositionSettingsItemViewMode.Normal);
			
		Else
			
			CommonUseClientServer.ChangeFilterItems(CharacteristicItemsArray[0], "CharacteristicsRef.Name", "Characteristics description", SearchText, DataCompositionComparisonType.Contains, True, DataCompositionSettingsItemViewMode.Normal);
			
		EndIf;
		
	EndIf;
	
EndProcedure // ContextSearchOnClient()

&AtClient
// Procedure initializes the execution of a full-text search and filter setting
// 
Procedure SearchAndSetFilter()
	
	If UseFullTextSearch Then
		
		FulltextSearchOnClient();
		
	Else
		
		ContextSearchOnClient();
		
	EndIf;
	
EndProcedure // SearchAndSetFilter()

&AtServer
// Procedure sets a tooltip of entering for the TextSearch form item
//
Procedure SetSearchStringOnServerInputHint()
	
	FulltextSearchSetPartially = (UseFullTextSearch AND Not RelevancyFullTextSearchIndex);
	InputHint = ?(FulltextSearchSetPartially, NStr("en = 'You need to update the index of full-text search...'"), NStr("en = '(ALT+F3) Enter search text ...'"));
	Items.SearchText.InputHint = InputHint;
	
EndProcedure // SetSearchStringOnServerToolTipInput()

&AtServer
// Procedure enables a full-text search and sets properties of form attributes
//
Procedure EnableFulltextSearchOnOpenSelection()
	
	UseFullTextSearch = GetFunctionalOption("UseFullTextSearch");
	If UseFullTextSearch Then
		
		RelevancyFullTextSearchIndex = FullTextSearch.IndexTrue();
		
		If Not RelevancyFullTextSearchIndex Then
			
			If CommonUseReUse.DataSeparationEnabled()
				AND CommonUseReUse.CanUseSeparatedData() Then
				
				//in the separated IB, the index is considered recent within 2 days
				RelevancyFullTextSearchIndex = FullTextSearch.UpdateDate() >= (CurrentSessionDate()-(2*24*60*60));
				
			Else
				
				//in the unseparated IB, the index is considered recent within a day
				RelevancyFullTextSearchIndex = FullTextSearch.UpdateDate() >= (CurrentSessionDate() - (1*24*60*60));
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	SetSearchStringOnServerInputHint();
	
EndProcedure // EnableFulltextSearchOnOpenSelection()

// End Full-text search


// Add product to cart

&AtClient
// Function returns VAT rate depending on the VAT taxation parameter value
//
Function GetVATRate(VATRate)
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT") Then
		
		If ValueIsFilled(VATRate) Then
			
			Return VATRate;
			
		Else
			
			Return PickProductsAndServicesInDocumentsReUse.GetCompanyVATRate(Object.Company);
		
		EndIf;
		
	Else
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotTaxableByVAT") Then
			
			Return SmallBusinessReUse.GetVATRateWithoutVAT();
			
		Else
			
			Return SmallBusinessReUse.GetVATRateZero();
			
		EndIf;
		
	EndIf;
	
EndFunction // GetVATRate()

&AtClient
// Function edits a price for a selection cart depending on the AmountIncludesVAT document values and prices kinds
//
//
Function CalculateProductsAndServicesPrice(VATRate, Price)
	
	PricesKindPriceIncludesVAT = SelectionSettingsCache.PricesKindPriceIncludesVAT;
	
	If Object.AmountIncludesVAT = PricesKindPriceIncludesVAT Then
		
		Return Price;
		
	ElsIf Object.AmountIncludesVAT > PricesKindPriceIncludesVAT Then
		
		VATRateValue = SmallBusinessReUse.GetVATRateValue(VATRate);
		Return Price * (100 + VATRateValue) / 100;
		
	Else
		
		VATRateValue = SmallBusinessReUse.GetVATRateValue(VATRate);
		Return Price * 100 / (100 + VATRateValue);
		
	EndIf;
	
EndFunction // CalculateProductsAndServicesPrice()

&AtClient
// VAT amount is calculated in the row of a tabular section.
//
Procedure CalculateVATSUM(StringCart)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(StringCart.VATRate);
	
	StringCart.VATAmount = ?(Object.AmountIncludesVAT, 
									StringCart.Amount - (StringCart.Amount) / ((VATRate + 100) / 100),
									StringCart.Amount * VATRate / 100);
	
EndProcedure // CalculateVATAmount()

&AtClient
// Procedure calculates the amount in the row of a tabular section.
//
Procedure CalculateAmountInTabularSectionLine(StringCart)
	
	StringCart.Amount = StringCart.Quantity * StringCart.Price;
	
	If StringCart.DiscountMarkupPercent <> 0
		AND StringCart.Quantity <> 0 Then
		
		StringCart.Amount = StringCart.Amount * (1 - StringCart.DiscountMarkupPercent / 100);
		
	EndIf;
	
	CalculateVATSUM(StringCart);
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure // CalculateAmountInTabularSectionLine()

&AtClient
// Function returns the current row data of a tabular field form item
//
Function GetListCurrentRowData()
	
	DataCurrentRows = ?(Items.PagesProductsAndServicesCharacteristics.CurrentPage = Items.PageProductsAndServices,
			Items.ListInventory.CurrentData,
			Items.CharacteristicsList.CurrentData);
	
	Return DataCurrentRows;
	
EndFunction // GetListCurrentRowData()

&AtClient
// Function searches for rows in the selection cart with specified products and services during adding products and services to the cart.
//
// Returns:
// 	- Undefined if products and services are not found;
// 	- Cart line if products and services are found;
//
Function FindProductsAndServicesInCart(DataCurrentRows)
	
	FilterStructure = New Structure("ProductsAndServices, Characteristic", DataCurrentRows.ProductsAndServicesRef, DataCurrentRows.CharacteristicRef);
	FoundStrings = Object.CartPriceBalanceReserveCharacteristic.FindRows(FilterStructure);
	
	Return ?(FoundStrings.Count() = 0, Undefined, FoundStrings[0]);
	
EndFunction // FindProductsAndServicesInCart()

&AtClient
// Procedure of adding products and services to the selection cart
//
Procedure AddProductsAndServicesToCart()
	
	DataCurrentRows = GetListCurrentRowData();
	If DataCurrentRows = Undefined Then
		
		Return;
		
	EndIf;
	
	CartRowData = New Structure;
	
	FoundString = FindProductsAndServicesInCart(DataCurrentRows);
	CartRowData.Insert("StringCart", ?(FoundString <> Undefined, FoundString.GetID(), FoundString));
	CartRowData.Insert("ProductsAndServices", DataCurrentRows.ProductsAndServicesRef);
	CartRowData.Insert("Characteristic", DataCurrentRows.CharacteristicRef);
	CartRowData.Insert("MeasurementUnit", DataCurrentRows.MeasurementUnit);
	CartRowData.Insert("VATRate", GetVATRate(DataCurrentRows.VATRate));
	CartRowData.Insert("Free", DataCurrentRows.Free);
	
	If FoundString <> Undefined 
		AND ValueIsFilled(FoundString.Price) Then
		
		CartRowData.Insert("Price", FoundString.Price);
		CartRowData.Insert("DiscountMarkupPercent", FoundString.DiscountMarkupPercent);
		
	Else
		
		CartRowData.Insert("Price", DataCurrentRows.Price);
		CartRowData.Insert("DiscountMarkupPercent", SelectionSettingsCache.DiscountMarkupPercent + SelectionSettingsCache.DiscountPercentByDiscountCard);
		
	EndIf;
	
	If SelectionSettingsCache.RequestQuantity
		OR SelectionSettingsCache.RequestPrice Then
		
		CartRowData.Insert("SelectionSettingsCache",	SelectionSettingsCache);
		CartRowData.Insert("Quantity",			1);
		CartRowData.Insert("MeasurementUnit", 	CartRowData.MeasurementUnit);
		CartRowData.Insert("Price",				CartRowData.Price);
		
		NotificationDescriptionOnCloseSelection = New NotifyDescription("AfterSelectionQuantityAndPrice", ThisObject, CartRowData);
		OpenForm("DataProcessor.PickingSales.Form.QuantityAndPrice", CartRowData, ThisForm, True, , ,NotificationDescriptionOnCloseSelection , FormWindowOpeningMode.LockOwnerWindow);
		
	Else
		
		If CartRowData.StringCart = Undefined Then
			
			StringCart = Object.CartPriceBalanceReserveCharacteristic.Add();
			FillPropertyValues(StringCart, CartRowData);
			StringCart.Price = CalculateProductsAndServicesPrice(StringCart.VATRate, CartRowData.Price);
			StringCart.Price = PickProductsAndServicesInDocumentsClient.RoundPrice(StringCart.Price, Object.RoundingOrder, Object.RoundUp);
			
		Else
			
			StringCart = FoundString;
			
		EndIf;
		
		StringCart.Quantity = StringCart.Quantity + 1;
		StringCart.Reserve	 = ?(ReservationEnabled, min(StringCart.Quantity, CartRowData.Free),0);
		
		CalculateAmountInTabularSectionLine(StringCart);
		
	EndIf;
	
EndProcedure // AddProductsAndServicesToCart()

// End Add products to cart


// Lists management

&AtClient
// Procedure sets a filter in the inventory list by an array of products and services analogs
//
Procedure FilterByProductsAndServicesAnalogs(ProductsAndServices, MessageText)
	
	ListProductsAndServicesAnalogs = New ValueList;
	GetProductsAndServicesAnalogs(ProductsAndServices, ListProductsAndServicesAnalogs);
	
	If ListProductsAndServicesAnalogs.Count() = 0 Then
		
		MessageText = NStr("en = 'There are no analogs for products and services.'");
		
	Else
		
		ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(ListInventory.SettingsComposer.FixedSettings.Filter, "ProductsAndServicesRef");
		If ItemArray.Count() = 0 Then
			
			CommonUseClientServer.AddCompositionItem(ListInventory.SettingsComposer.FixedSettings.Filter, "ProductsAndServicesRef", DataCompositionComparisonType.InList, ListProductsAndServicesAnalogs);
			
		Else
			
			CommonUseClientServer.ChangeFilterItems(ListInventory.SettingsComposer.FixedSettings.Filter, "ProductsAndServicesRef", , ListProductsAndServicesAnalogs, DataCompositionComparisonType.InList);
			
		EndIf;
		
	EndIf;
	
EndProcedure // SelectionByProductsAndServicesAnalogs()

&AtClient
// Procedure updates the Inventory dynamic lists
//
Procedure UpdateFilterByGroupOfDynamicLists()
	
	ProductsAndServicesParent = Items.ListProductsAndServicesHierarchy.CurrentData;
	
	If ProductsAndServicesParent = Undefined Then
		
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(ListInventory, "Parent");
		
	Else
		
		ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(ListInventory.SettingsComposer.FixedSettings.Filter, "Parent");
		If ItemArray.Count() = 0 Then
			
			CommonUseClientServer.AddCompositionItem(ListInventory.SettingsComposer.FixedSettings.Filter, "Parent", DataCompositionComparisonType.InHierarchy, ProductsAndServicesParent.Ref);
			
		Else
			
			CommonUseClientServer.ChangeFilterItems(ListInventory.SettingsComposer.FixedSettings.Filter, "Parent", , ProductsAndServicesParent.Ref, DataCompositionComparisonType.InHierarchy);
			
		EndIf;
		
	EndIf;
	
EndProcedure //UpdateFilterByDynamicListsGroup()

&AtClient
// Open characteristics list and set a filter by products and services
//
Procedure ShowCharacteristicsList()
	
	ProductsAndServicesListCurrentData = Items.ListInventory.CurrentData;
	
	ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "Owner");
	If ItemArray.Count() = 0 Then
		
		CommonUseClientServer.AddCompositionItem(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "Owner", DataCompositionComparisonType.Equal, ProductsAndServicesListCurrentData.ProductsAndServicesRef);
		
	Else
		
		CommonUseClientServer.ChangeFilterItems(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "Owner", , ProductsAndServicesListCurrentData.ProductsAndServicesRef, DataCompositionComparisonType.Equal);
		
	EndIf;
	
	CommonUseClientServer.SetFormItemProperty(Items, "ListProductsAndServicesHierarchy", "Enabled", False);
	Items.ListProductsAndServicesHierarchy.TextColor = New Color(150, 150, 150);
	Items.PagesProductsAndServicesCharacteristics.CurrentPage = Items.PageCharacteristics;
	
EndProcedure // ShowCharacteristicsList()

&AtServer
// Procedure sets values of the dynamic lists parameters 
//
// Values are written from the processor attributes
//
Procedure SetDynamicListParameters()
	
	//Parameters filled in a special way, for example, Company
	ParemeterCompany = New DataCompositionParameter("Company");
	
	ListsArray = New Array;
	ListsArray.Add(ListProductsAndServicesHierarchy);
	ListsArray.Add(ListInventory);
	ListsArray.Add(CharacteristicsList);
	ListsArray.Add(ListWarehouseBalances);
	
	For Each DynamicList IN ListsArray Do
	
		For Each ListParameter IN DynamicList.Parameters.Items Do
			
			ObjectAttributeValue = Undefined;
			If ListParameter.Parameter = ParemeterCompany Then
				
				DynamicList.Parameters.SetParameterValue(ListParameter.Parameter, SmallBusinessServer.GetCompany(Object.Company));
				
			ElsIf Object.Property(ListParameter.Parameter, ObjectAttributeValue) Then
				
				If PickProductsAndServicesInDocuments.IsValuesList(ObjectAttributeValue) Then
					
					ObjectAttributeValue = PickProductsAndServicesInDocuments.ValueListIntoArray(ObjectAttributeValue);
					
				EndIf;
				
				DynamicList.Parameters.SetParameterValue(ListParameter.Parameter, ObjectAttributeValue);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	CurrencyRates = SmallBusinessServer.GetCurrencyRates(Object.PriceKindCurrency, Object.DocumentCurrency, Object.Date);
	
	ListInventory.Parameters.SetParameterValue("PriceKindCurrencyRate",			CurrencyRates.InitRate);
	ListInventory.Parameters.SetParameterValue("PriceKindCurrencyMultiplicity",	CurrencyRates.RepetitionBeg);
	ListInventory.Parameters.SetParameterValue("DocumentCurrencyRate",		CurrencyRates.ExchangeRate);
	ListInventory.Parameters.SetParameterValue("DocumentCurrencyMultiplicity",	CurrencyRates.Multiplicity);
	
	CharacteristicsList.Parameters.SetParameterValue("PriceKindCurrencyRate",		CurrencyRates.InitRate);
	CharacteristicsList.Parameters.SetParameterValue("PriceKindCurrencyMultiplicity",	CurrencyRates.RepetitionBeg);
	CharacteristicsList.Parameters.SetParameterValue("DocumentCurrencyRate",	CurrencyRates.ExchangeRate);
	CharacteristicsList.Parameters.SetParameterValue("DocumentCurrencyMultiplicity",CurrencyRates.Multiplicity);
	
	If ValueIsFilled(Object.DynamicPriceKindBasic) Then
		
		ListInventory.Parameters.SetParameterValue("PriceKind", Object.DynamicPriceKindBasic);
		CharacteristicsList.Parameters.SetParameterValue("PriceKind", Object.DynamicPriceKindBasic);
		
	EndIf;
	
	// Percent = 0 for the dynamical prices kinds, therefore the price does not change.
	ListInventory.Parameters.SetParameterValue("DynamicPriceKindPercent", Object.DynamicPriceKindPercent);
	CharacteristicsList.Parameters.SetParameterValue("DynamicPriceKindPercent", Object.DynamicPriceKindPercent);
	
EndProcedure // SetDynamicListParameters()

&AtClient
// Procedure sets values of the dynamic lists parameters 
//
Procedure SetWarehouseRemainingsListSelection()
	
	If Not Items.FormChangeVisibleWarehouseBalance.Check Then
		
		Return;
		
	EndIf;
	
	DataCurrentRows = GetListCurrentRowData();
	CurrentRowDataFilled = (DataCurrentRows <> Undefined);
	
	//ProductsAndServices
	ProductsAndServicesRef = ?(CurrentRowDataFilled, DataCurrentRows.ProductsAndServicesRef, PredefinedValue("Catalog.ProductsAndServices.EmptyRef"));
	FiltersProductsAndServices = CommonUseClientServer.FindFilterItemsAndGroups(ListWarehouseBalances.Filter, "ProductsAndServices");
	If FiltersProductsAndServices.Count() = 0 Then
		
		CommonUseClientServer.AddCompositionItem(ListWarehouseBalances.Filter, "ProductsAndServices", DataCompositionComparisonType.Equal, ProductsAndServicesRef);
		
	Else
		
		CommonUseClientServer.ChangeFilterItems(ListWarehouseBalances.Filter, "ProductsAndServices", , ProductsAndServicesRef, DataCompositionComparisonType.Equal);
		
	EndIf;
	
	//Characteristics
	If Items.PagesProductsAndServicesCharacteristics.CurrentPage = Items.PageProductsAndServices Then
		
		CommonUseClientServer.DeleteItemsOfFilterGroup(ListWarehouseBalances.Filter, "Characteristic");
		
	Else
		
		CharacteristicRef = ?(CurrentRowDataFilled, DataCurrentRows.CharacteristicRef, PredefinedValue("Catalog.ProductsAndServicesCharacteristics.EmptyRef"));
		FiltersCharacteristic = CommonUseClientServer.FindFilterItemsAndGroups(ListWarehouseBalances.Filter, "Characteristic");
		If FiltersCharacteristic.Count() = 0 Then
			
			CommonUseClientServer.AddCompositionItem(ListWarehouseBalances.Filter, "Characteristic", DataCompositionComparisonType.Equal, CharacteristicRef);
			
		Else
			
			CommonUseClientServer.ChangeFilterItems(ListWarehouseBalances.Filter, "Characteristic", , CharacteristicRef, DataCompositionComparisonType.Equal);
			
		EndIf;
		
	EndIf;
	
EndProcedure // SetWarehouseRemainingsListSelection()

&AtClient
// Procedure sets values of the dynamic lists parameters 
//
Procedure SetListsTitles()
	
	If Items.FormRefreshTitles.Check Then
	
		If Items.PagesProductsAndServicesCharacteristics.CurrentPage = Items.PageCharacteristics Then
			
			DataCurrentRows = GetListCurrentRowData();
			CurrentRowDataFilled = (DataCurrentRows <> Undefined);
			
			PresentationOfProductsAndServices = ?(CurrentRowDataFilled, String(DataCurrentRows.ProductsAndServicesRef), "<...>");
			
			CommonUseClientServer.SetFormItemProperty(Items, "CharacteristicsListCharacteristicRef", "Title", "Characteristics: " + PresentationOfProductsAndServices);
			CommonUseClientServer.SetFormItemProperty(Items, "ListWarehouseBalancesStructuralUnit", "Title", "Warehouse. balance: " + PresentationOfProductsAndServices);
			CommonUseClientServer.SetFormItemProperty(Items, "FormTransitionProductsAndServicesCharacteristics", "Title", "Characteristics");
			
		Else
			
			CommonUseClientServer.SetFormItemProperty(Items, "CharacteristicsListCharacteristicRef", "Title", "Characteristic");
			CommonUseClientServer.SetFormItemProperty(Items, "ListWarehouseBalancesStructuralUnit", "Title", "Warehouse");
			CommonUseClientServer.SetFormItemProperty(Items, "FormTransitionProductsAndServicesCharacteristics", "Title", "ProductsAndServices");
			
		EndIf;
		
	EndIf;
	
EndProcedure // SetWarehouseRemainingsListSelection()

// End of Lists management

&AtServerNoContext
// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("ProductsAndServicesVATRate", StructureData.ProductsAndServices.VATRate);
	
	If StructureData.Property("PriceKind") Then
		
		StructurePriceAndMeasurementUnit = PickProductsAndServicesInDocuments.GetPriceAndProductsAndServicesMeasurementUnitByPricesKind(StructureData);
		StructureData.Insert("Price", StructurePriceAndMeasurementUnit.Price);
		StructureData.Insert("MeasurementUnit", StructurePriceAndMeasurementUnit.MeasurementUnit);
		
	Else
		
		StructureData.Insert("Price", 0);
		StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
		
	EndIf;
	
	StructureData.Insert("DiscountMarkupPercent", StructureData.DiscountMarkupKind.Percent);
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

&AtServerNoContext
// Procedure fills a list of analogs by the passed products and services
//
Procedure GetProductsAndServicesAnalogs(ProductsAndServices, ListProductsAndServicesAnalogs)
	
	ListProductsAndServicesAnalogs.Clear();
	
	Query = New Query("SELECT * IN InformationRegister.ProductsAndServicesAnalogs AS Analogs WHERE ProductsAndServices = &ProductsAndServices ORDER BY Priority");
	Query.SetParameter("ProductsAndServices", ProductsAndServices);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		ListProductsAndServicesAnalogs.Add(Selection.Analog);
		
	EndDo;
	
	ListProductsAndServicesAnalogs.Insert(0, ProductsAndServices);
	
EndProcedure // GetProductsAndServicesAnalogs()

&AtServerNoContext
// Function returns the key of the register record.
//
Function GetRecordKey(ParametersStructure)
	
	Return InformationRegisters.ProductsAndServicesPrices.GetRecordKey(ParametersStructure);
	
EndFunction // GetRecordKey()

&AtServer
// Procedure fills in objects data
// by passed parameters called by the OnWriteObject event, 
//
Procedure FillObjectData()
	
	FillPropertyValues(Object, Parameters);
	Object.PriceKindCurrency = Object.PriceKind.PriceCurrency;
	Object.RoundingOrder = Object.PriceKind.RoundingOrder;
	Object.RoundUp = Object.PriceKind.RoundUp;
	
	If Object.PriceKind.CalculatesDynamically = True Then
		
		Object.DynamicPriceKindBasic = Object.PriceKind.PricesBaseKind;
		Object.DynamicPriceKindPercent = Object.PriceKind.Percent;
		
	EndIf;
	
EndProcedure // FillObjectData()

&AtServer
// Procedure fills in document data that
// caused selection is called by the OnWriteObject event, 
//
Procedure FillInformationAboutDocument(InformationAboutDocument)
	
	DataProcessors.PickingSales.InformationAboutDocumentStructure(InformationAboutDocument);
	FillPropertyValues(InformationAboutDocument, Object);
	InformationAboutDocument.Insert("DiscountsMarkupsVisible", Parameters.DiscountsMarkupsVisible);
	
EndProcedure // FillInInformationAboutDocument()

&AtServer
// Function places picking results into storage
//
// Returns the structure:
// Structure
// 	- Address of the storage where the selected products and services are located (cart);
// 	- Unique identifier of owner form, required for identification during the processor of selection results;
//
Function WritePickToStorage() 
	
	CartAddressInStorage = PutToTempStorage(Object.CartPriceBalanceReserveCharacteristic.Unload(), Object.OwnerFormUUID);
	Return New Structure("CartAddressInStorage, OwnerFormUUID", CartAddressInStorage, Object.OwnerFormUUID);
	
EndFunction // WritePickToStorage()

&AtServer
// Procedure sets properties of the form items
//
Procedure SetFormItemsProperties()
	
	PickProductsAndServicesInDocuments.SetChoiceParameters(Items.CartPriceBalanceReserveProductCharacteristicAndServices, Object.ProductsAndServicesType);
	
	CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryMeasurementUnit", "Visible", GetFunctionalOption("AccountingInVariousUOM"));
	CommonUseClientServer.SetFormItemProperty(Items, "CharacteristicsListMeasurementUnit", "Visible", GetFunctionalOption("AccountingInVariousUOM"));
	CommonUseClientServer.SetFormItemProperty(Items, "CartPriceBalanceReserveCharacteristicMeasurementUnit", "Visible", GetFunctionalOption("AccountingInVariousUOM"));
	
	CommonUseClientServer.SetFormItemProperty(Items, "FormChangeVisibleWarehouseBalance", "Check", True);
	CommonUseClientServer.SetFormItemProperty(Items, "FormChangeCartVisibile", "Check", True);
	CommonUseClientServer.SetFormItemProperty(Items, "FormRefreshTitles", "Check", True);
	
	CommonUseClientServer.SetFormItemProperty(Items, "FormTransitionProductsAndServicesCharacteristics", "Title", "ProductsAndServices");
	
	CommonUseClientServer.SetFormItemProperty(Items, "ProductsAndServicesListContextMenuChangePrice", "Enabled", ValueIsFilled(Object.PriceKind));
	CommonUseClientServer.SetFormItemProperty(Items, "CharacteristicsListContextMenuPriceSetNew", "Enabled", ValueIsFilled(Object.PriceKind));
	
	CommonUseClientServer.SetFormItemProperty(Items, "CartPriceBalanceReserveCharacteristicPrice", "Enabled", SelectionSettingsCache.AllowedToChangeAmount);
	CommonUseClientServer.SetFormItemProperty(Items, "CartPriceBalanceReserveCharacteristicDiscountMarkupPercent", "Visible", SelectionSettingsCache.DiscountsMarkupsVisible 
		OR SelectionSettingsCache.DiscountCardVisible); // DiscountCards
	CommonUseClientServer.SetFormItemProperty(Items, "CartPriceBalanceReserveCharacteristicAmount", "Enabled", SelectionSettingsCache.AllowedToChangeAmount);
	CommonUseClientServer.SetFormItemProperty(Items, "CartPriceBalanceReserveCharacteristicVATAmount", "Enabled", SelectionSettingsCache.AllowedToChangeAmount);
	CommonUseClientServer.SetFormItemProperty(Items, "CartPriceBalanceReserveCharacteristicTotal", "Enabled", SelectionSettingsCache.AllowedToChangeAmount);
	CommonUseClientServer.SetFormItemProperty(Items, "ProductsAndServicesListContextMenuChangePrice", "Enabled", SelectionSettingsCache.AllowedToChangeAmount);
	CommonUseClientServer.SetFormItemProperty(Items, "CharacteristicsListContextMenuPriceSetNew", "Enabled", SelectionSettingsCache.AllowedToChangeAmount);
	
	ReservationEnabled = GetFunctionalOption("InventoryReservation");
	
	CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryReserve", "Visible", ReservationEnabled);
	CommonUseClientServer.SetFormItemProperty(Items, "ListWarehouseBalancesReserve", "Visible", ReservationEnabled);
	CommonUseClientServer.SetFormItemProperty(Items, "CartPriceBalanceReserveCharacteristicReserve", "Visible", ReservationEnabled);
	
EndProcedure // SetFormItemsProperties()

&AtClient
// Procedure sets a passed item of form with the current
//
Procedure SetCurrentFormItem(Item)
	
	ThisForm.CurrentItem = Item;
	
EndProcedure // SetCurrentFormItems()

&AtServerNoContext
// Receives a data set from server for the CartPriceBalanceReserveCharacteristicsMeasurementUnitSelectionProcessor procedure
//
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure();
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
		
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataMeasurementUnitOnChange()

&AtClient
// Procedure calls form containing user advice
//
Procedure ShowUserAdvice(FormTitle, MessageText, VisibleDoNotShowAgain, CustomSettingName)
	
	AdviceParameter = New Structure;
	AdviceParameter.Insert("Title", FormTitle);
	AdviceParameter.Insert("MessageText", MessageText);
	AdviceParameter.Insert("VisibleDoNotShowAgain", VisibleDoNotShowAgain);
	AdviceParameter.Insert("CustomSettingName", CustomSettingName);
	
	NotifyDescription = New NotifyDescription("AfterAdviceOutput", ThisObject, AdviceParameter);
	OpenForm("CommonForm.MessageForm", AdviceParameter, ThisForm, True, , , NotifyDescription, FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure // ShowUserAdvice()

&AtClient
// Procedure waiting processor. Output user advice on top of selection window
//
Procedure OutputBoardUsePreviousPick()
	
	If SelectionSettingsCache.OutputBoardUsePreviousPick Then
		
		FormTitle = NStr("en = 'Advice'");
		MessageText = NStr("en = 'You can disable/enable using a new selection form in the user settings.'");
		
		ShowUserAdvice(FormTitle, MessageText, True, "OutputBoardUsePreviousPick");
		
	EndIf;
	
EndProcedure // DisplaySelectionAdvice()

&AtClient
// Procedure of the user advice output about returning to the products and services list
//
Procedure OutputAdviceGoBackToProductsAndServices()
	
	If SelectionSettingsCache.OutputAdviceGoBackToProductsAndServices Then
		
		FormTitle = NStr("en = 'Advice'");
		MessageText = NStr("en = 'You can return to the products and services list using context menu or the BackSpace button.'");
		
		ShowUserAdvice(FormTitle, MessageText, True, "OutputAdviceGoBackToProductsAndServices");
		
	EndIf;
	
EndProcedure // OutputToolTipReturnToProductsAndServers


////////////////////////////////////////////////////////////////////////////////////////////////////
// COMMANDS HANDLERS PROCEDURES 
//

&AtClient
// Procedure - handler of the ExecuteSearch command
//
Procedure RunSearch(Command)
	
	SearchAndSetFilter();
	
EndProcedure // ExecuteSearch()

&AtClient
// Procedure - handler of the ChangeSettings command
//
Procedure ChangeSettings(Command)
	
	NotifyDescription = New NotifyDescription("UpdateSelectionSettings", ThisObject);
	OpenForm("DataProcessor.PickingSales.Form.Setting", , ThisForm, True, , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure // ChangeSettings()

&AtClient
// Procedure - handler of the TransferToDocument command
//
Procedure MoveIntoDocument(Command)
	
	Close(WritePickToStorage());
	
EndProcedure // TransferToDocument()

// Procedure - handler of the Select command
//
&AtClient
Procedure AddToCart(Command)
	
	AddProductsAndServicesToCart();
	
EndProcedure // Select()

&AtClient
//Procedure - handler of the GoToParent command (context. menu of the products and services list)
//
Procedure GoToParent(Command)
	
	DataCurrentRows = GetListCurrentRowData();
	
	If DataCurrentRows <> Undefined Then
		
		Items.ListProductsAndServicesHierarchy.CurrentRow = DataCurrentRows.Parent;
		
	EndIf;
	
EndProcedure // GoToParent()

&AtClient
//Procedure - handler of the SetNewPrice command (context. menu of the products and services list)
//
Procedure ChangePrice(Command)
	
	DataCurrentRows = GetListCurrentRowData();
	
	If DataCurrentRows <> Undefined Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("Period", 		EndOfDay(Object.PricePeriod));
		ParametersStructure.Insert("PriceKind", 		Object.PriceKind);
		ParametersStructure.Insert("ProductsAndServices", DataCurrentRows.ProductsAndServicesRef);
		ParametersStructure.Insert("Characteristic", DataCurrentRows.CharacteristicRef);
		ParametersStructure.Insert("MeasurementUnit", DataCurrentRows.MeasurementUnit);
		
		NotifyDescription = New NotifyDescription("UpdateListAfterPriceChange", ThisObject);
		
		RecordKey = GetRecordKey(ParametersStructure);
		
		If RecordKey.WriteExist Then
			
			RecordKey.Delete("WriteExist");
			
			ParametersArray = New Array;
			ParametersArray.Add(RecordKey);
			
			RecordKeyRegister = New("InformationRegisterRecordKey.ProductsAndServicesPrices", ParametersArray);
			OpenForm("InformationRegister.ProductsAndServicesPrices.RecordForm", New Structure("Key", RecordKeyRegister), ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
			
		Else
			
			OpenForm("InformationRegister.ProductsAndServicesPrices.RecordForm", New Structure("FillingValues", ParametersStructure), ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
			
		EndIf; 
		
	EndIf;
	
EndProcedure // SetNewPrice()

&AtClient
//Procedure - handler of the SetNewPrice command (context. menu of the characteristics list)
//
Procedure ShowProductsAndServices(Command)
	
	CommonUseClientServer.SetFormItemProperty(Items, "ListProductsAndServicesHierarchy", "Enabled", True);
	
	If ValueIsFilled(OwnerCharacteristics) Then
		
		Items.ListInventory.CurrentRow = OwnerCharacteristics;
		OwnerCharacteristics = Undefined;
		
	EndIf;
	
	Items.ListProductsAndServicesHierarchy.TextColor = New Color();
	
	Items.PagesProductsAndServicesCharacteristics.CurrentPage = Items.PageProductsAndServices;
	
	AttachIdleHandler("SetWarehouseRemainingsListSelection", 0.1, True);
	AttachIdleHandler("SetListsTitles", 0.1, True);
	
EndProcedure // ShowProductsAndServices()

&AtClient
//Procedure - handler of the ChangeVisibleStorageBalance command (form menu)
//
Procedure ChangeVisibleWarehouseBalance(Command)
	
	Items.FormChangeVisibleWarehouseBalance.Check = Not Items.FormChangeVisibleWarehouseBalance.Check;
	CommonUseClientServer.SetFormItemProperty(Items, "ListWarehouseBalances", "Visible", Items.FormChangeVisibleWarehouseBalance.Check);
	
EndProcedure // ChangeWarehouseRemainingsVisible()

&AtClient
//Procedure - handler of the ChangeCartVisible command (form menu)
//
Procedure ChangeCartVisible(Command)
	
	Items.FormChangeCartVisibile.Check = Not Items.FormChangeCartVisibile.Check;
	CommonUseClientServer.SetFormItemProperty(Items, "CartPriceBalanceReserveCharacteristic", "Visible", Items.FormChangeCartVisibile.Check);
	
EndProcedure // ChangeBasketVisible()

&AtClient
//Procedure - handler of the TransferFulltextSearch command
Procedure TransitionFullTextSearch(Command)
	
	SetCurrentFormItem(Items.SearchText);
	
EndProcedure // TransferFulltextSearch()

&AtClient
//Procedure - handler of the TransferHierarchy command
Procedure TransitionHierarchy(Command)
	
	SetCurrentFormItem(Items.ListProductsAndServicesHierarchy);
	
EndProcedure // TransitionHierarchy()

&AtClient
//Procedure - handler of the TransferProductsAndServicesCharacteristics command
//
Procedure TransitionProductsAndServicesCharacteristics(Command)
	
	IsProductsAndServices = (Items.PagesProductsAndServicesCharacteristics.CurrentPage = Items.PageProductsAndServices);
	
	SetCurrentFormItem(?(IsProductsAndServices, Items.ListInventory, Items.CharacteristicsList));
	
EndProcedure // TransferCharacteristicsProductsAndServices()

&AtClient
//Procedure - handler of the TransferBasket command
Procedure TransitionCart(Command)
	
	SetCurrentFormItem(Items.CartPriceBalanceReserveCharacteristic);
	
EndProcedure // TransitionCart()

&AtClient
//Procedure - handler of the UpdateTitles command
//
Procedure RefreshTitles(Command)
	
	Items.FormRefreshTitles.Check = Not Items.FormRefreshTitles.Check;
	
	// If the titles update is enabled, return titles to the typical state...
	If Not Items.FormRefreshTitles.Check Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "CharacteristicsListCharacteristicRef", "Title", "Characteristic");
		CommonUseClientServer.SetFormItemProperty(Items, "ListWarehouseBalancesStructuralUnit", "Title", "Warehouse");
		CommonUseClientServer.SetFormItemProperty(Items, "FormTransitionProductsAndServicesCharacteristics", "Title", "ProductsAndServices/Characteristics");
		
	EndIf;
	
EndProcedure // UpdateTitles()

&AtClient
//Procedure - handler of the DecryptReserve command
//
Procedure DecryptReserve(Command)
	
	DataCurrentRows = GetListCurrentRowData();
	If DataCurrentRows = Undefined Then
		
		Return;
		
	EndIf;
	
	DetailsParameters = New Structure;
	DetailsParameters.Insert("Company", 	Object.Company);
	DetailsParameters.Insert("ProductsAndServices",	DataCurrentRows.ProductsAndServicesRef);
	DetailsParameters.Insert("Characteristic", DataCurrentRows.CharacteristicRef);
	
	
	NotificationDescriptionOnCloseSelection = New NotifyDescription("AfterOpeningReserveDecryption", ThisObject, DetailsParameters);
	OpenForm("DataProcessor.PickingSales.Form.DecryptReserve", DetailsParameters, ThisForm, True, , ,NotificationDescriptionOnCloseSelection , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure // DecryptReserve()

&AtClient
//Procedure - handler of the ProductsAndServicesAnalogs command
//
Procedure ProductsAndServicesAnalogs(Command)
	Var MessageText;
	
	If Items.ListInventoryContextMenuProductsAndServicesAnalogs.Check Then
		
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(ListInventory, "ProductsAndServicesRef");
		Items.ListInventoryContextMenuProductsAndServicesAnalogs.Check = False;
		
		If Items.FormRefreshTitles.Check Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryDescription", "Title", "ProductsAndServices");
			
		EndIf;
		
		Return;
		
	EndIf;
	
	DataCurrentRows = Items.ListInventory.CurrentData;
	If DataCurrentRows <> Undefined Then
		
		FilterByProductsAndServicesAnalogs(DataCurrentRows.ProductsAndServicesRef, MessageText);
		
		If IsBlankString(MessageText) Then
			
			Items.ListInventoryContextMenuProductsAndServicesAnalogs.Check = True;
			
			If Items.FormRefreshTitles.Check Then
				
				CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryDescription", "Title", "ProductsAndServices (inc. Analogs)");
				
			EndIf
			
		Else
			
			CommonUseClientServer.MessageToUser(MessageText, , "ListInventoryDescription", , );
			
		EndIf;
		
	EndIf;
	
EndProcedure // ProductsAndServicesAnalogs()

&AtClient
//Procedure - handler of the InformationAboutDocument command
//
Procedure InformationAboutDocument(Command)
	
	NotificationDescriptionOnCloseSelection = New NotifyDescription("AfterClosingInformationAboutDocumentForm", ThisObject);
	OpenForm("DataProcessor.PickingSales.Form.InformationAboutDocument", SelectionSettingsCache.InformationAboutDocument, ThisForm, True, , ,NotificationDescriptionOnCloseSelection, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure // InformationAboutDocument()

&AtClient
//Procedure - handler of the ProductsAndServicesWithPrice command
//
Procedure ProductsAndServicesWithPrice(Command)
	
	If Items.FormProductsAndServicesWithPrice.Check Then
		
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(ListInventory, "Price");
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(CharacteristicsList, "Price");
		CommonUseClientServer.SetFormItemProperty(Items, "FormProductsAndServicesWithPrice", "Check", False);
		
	Else
		
		//::: Products and services
		ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(ListInventory.SettingsComposer.FixedSettings.Filter, "Price");
		If ItemArray.Count() = 0 Then
			
			CommonUseClientServer.AddCompositionItem(ListInventory.SettingsComposer.FixedSettings.Filter, "Price", DataCompositionComparisonType.Filled, 0);
			
		Else
			
			CommonUseClientServer.ChangeFilterItems(ListInventory.SettingsComposer.FixedSettings.Filter, "Price", , 0, DataCompositionComparisonType.Filled);
			
		EndIf;
		
		//::: Characteristics
		CharacteristicItemsArray = CommonUseClientServer.FindFilterItemsAndGroups(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "Price");
		If CharacteristicItemsArray.Count() = 0 Then
			
			CommonUseClientServer.AddCompositionItem(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "Price", DataCompositionComparisonType.Filled, 0);
			
		Else
			
			CommonUseClientServer.ChangeFilterItems(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "Price", , 0, DataCompositionComparisonType.Filled);
			
		EndIf;
		
		CommonUseClientServer.SetFormItemProperty(Items, "FormProductsAndServicesWithPrice", "Check", True);
		
	EndIf;
	
EndProcedure // ProductsAndServicesWithPrice()

&AtClient
// Procedure - handler of the ProductsAndServicesPresent command
//
Procedure ProductsAndServicesInInventory(Command)
	
	If Items.FormProductsAndServicesInInventory.Check Then
		
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(ListInventory, "Balance");
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(CharacteristicsList, "Balance");
		CommonUseClientServer.SetFormItemProperty(Items, "FormProductsAndServicesInInventory", "Check", False);
		
	Else
		
		//::: Products and services
		ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(ListInventory.SettingsComposer.FixedSettings.Filter, "Balance");
		If ItemArray.Count() = 0 Then
			
			CommonUseClientServer.AddCompositionItem(ListInventory.SettingsComposer.FixedSettings.Filter, "Balance", DataCompositionComparisonType.Filled, 0);
			
		Else
			
			CommonUseClientServer.ChangeFilterItems(ListInventory.SettingsComposer.FixedSettings.Filter, "Balance", , 0, DataCompositionComparisonType.Filled);
			
		EndIf;
		
		//::: Characteristics
		CharacteristicItemsArray = CommonUseClientServer.FindFilterItemsAndGroups(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "Balance");
		If CharacteristicItemsArray.Count() = 0  Then
			
			CommonUseClientServer.AddCompositionItem(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "Balance", DataCompositionComparisonType.Filled, 0);
			
		Else
			
			CommonUseClientServer.ChangeFilterItems(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "Balance", , 0, DataCompositionComparisonType.Filled);
			
		EndIf;
		
		CommonUseClientServer.SetFormItemProperty(Items, "FormProductsAndServicesInInventory", "Check", True);
		
	EndIf;
	
EndProcedure // ProductsAndServicesInStore()


////////////////////////////////////////////////////////////////////////////////////////////////////
// PROCESSOR PROCEDURE OF OPENING HELPER FORMS RESULTS
//

&AtClient
// Procedure processes the result of the Setting additional form opening
//
Procedure UpdateSelectionSettings(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		For Each SettingItem IN ClosingResult Do
			
			If SettingItem.Value <> SelectionSettingsCache[SettingItem.Key] Then
				
				SelectionSettingsCache[SettingItem.Key] = SettingItem.Value;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure // UpdateSelectionSettings()

// Procedure processes results of opening setting form of an actual price
//
Procedure UpdateListAfterPriceChange(ClosingResult, AdditionalParameters)
	
	If Items.PagesProductsAndServicesCharacteristics.CurrentPage = Items.PageProductsAndServices Then
		
		Items.ListInventory.Refresh();
		
	Else
		
		Items.CharacteristicsList.Refresh();
		
	EndIf;
	
EndProcedure // UpdateListAfterPriceChange()

&AtClient
// Procedure processes the results of opening the Quantity and price additional form
//
//
Procedure AfterSelectionQuantityAndPrice(ClosingResult, CartRowData) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If CartRowData.StringCart = Undefined Then
			
			StringCart = Object.CartPriceBalanceReserveCharacteristic.Add();
			FillPropertyValues(StringCart, CartRowData);
			StringCart.Quantity = ClosingResult.Quantity;
			StringCart.Price		 = CalculateProductsAndServicesPrice(StringCart.VATRate, ClosingResult.Price);
			StringCart.DiscountMarkupPercent = CartRowData.DiscountMarkupPercent;
			
		Else
			
			StringCart = Object.CartPriceBalanceReserveCharacteristic.FindByID(CartRowData.StringCart);
			StringCart.Quantity = StringCart.Quantity + ClosingResult.Quantity;
			StringCart.Price		 = ClosingResult.Price;
			
		EndIf;
		
		StringCart.Price 		= PickProductsAndServicesInDocumentsClient.RoundPrice(StringCart.Price, Object.RoundingOrder, Object.RoundUp);
		StringCart.Reserve	= ?(ReservationEnabled, min(StringCart.Quantity, CartRowData.Free),0);
		
		CalculateAmountInTabularSectionLine(StringCart);
		
	EndIf;
	
EndProcedure // AfterSelectingQuantityAndPrice()

&AtClient
// Procedure processes the results of opening the Information about document additional form
//
Procedure AfterClosingInformationAboutDocumentForm(ClosingResult, AdditionalParameters) Export
	
	SelectionMainFormParameters = AdditionalParameters;
	
EndProcedure // AfterInformationAboutDocumentsFormClosing()

&AtClient
// Procedure processes the results of opening the Reserve decryption additional form
//
Procedure AfterOpeningReserveDecryption(ClosingResult, AdditionalParameters) Export
	
	SelectionMainFormParameters = AdditionalParameters;
	
EndProcedure // AfterOpeningReserveDecryption()

&AtClient
// Procedure processes results of the user advice form opening
//
Procedure AfterAdviceOutput(ClosingResult, AdviceParameter) Export
	
	If AdviceParameter.VisibleDoNotShowAgain 
		AND TypeOf(ClosingResult) = Type("Structure") Then
		
		SelectionSettingsCache.Insert(AdviceParameter.CustomSettingName, ClosingResult.CustomSettingValue);
		SmallBusinessServer.SetUserSetting(ClosingResult.CustomSettingValue, AdviceParameter.CustomSettingName);
		
	EndIf;
	
EndProcedure // AfterAdviceOutput()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS
//

&AtServer
// Procedure - handler of the OnCreateAtServer event
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Var InformationAboutDocument;
	
	DataProcessors.PickingSales.CheckParametersFilling(Parameters, Cancel);
	
	FillObjectData();
	FillInformationAboutDocument(InformationAboutDocument);
	
	EnableFulltextSearchOnOpenSelection();
	SetDynamicListParameters();
	
	// Correct the Warehouse balance list flicker
	CommonUseClientServer.AddCompositionItem(ListWarehouseBalances.Filter, "ProductsAndServices", DataCompositionComparisonType.Equal, Catalogs.ProductsAndServices.EmptyRef());
	
	SelectionSettingsCache = New Structure;
	SelectionSettingsCache.Insert("OutputAdviceGoBackToProductsAndServices", SmallBusinessReUse.GetValueOfSetting("OutputAdviceGoBackToProductsAndServices"));
	SelectionSettingsCache.Insert("OutputBoardUsePreviousPick", SmallBusinessReUse.GetValueOfSetting("OutputBoardUsePreviousPick"));
	SelectionSettingsCache.Insert("RequestQuantity", SmallBusinessReUse.GetValueOfSetting("RequestQuantity"));
	SelectionSettingsCache.Insert("RequestPrice", SmallBusinessReUse.GetValueOfSetting("RequestPrice"));
	SelectionSettingsCache.Insert("CurrentUser", Users.AuthorizedUser());
	SelectionSettingsCache.Insert("PricesKindPriceIncludesVAT", ?(ValueIsFilled(Object.PriceKind), Object.PriceKind.PriceIncludesVAT, Object.AmountIncludesVAT));
	SelectionSettingsCache.Insert("DiscountsMarkupsVisible", Parameters.DiscountsMarkupsVisible);
	SelectionSettingsCache.Insert("DiscountMarkupPercent", Object.DiscountMarkupKind.Percent);
	SelectionSettingsCache.Insert("InformationAboutDocument", InformationAboutDocument);
	// DiscountCards
	SelectionSettingsCache.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	SelectionSettingsCache.Insert("DiscountCardVisible", Parameters.DiscountCardVisible);
	// End DiscountCards
	
	//Manually changing of the price is invalid for the CRReceipt document with a retail warehouse
	AllowedToChangeAmount = True;
	If Parameters.Property("IsCRReceipt") Then
		
		If ValueIsFilled(Object.StructuralUnit) Then
			
			AllowedToChangeAmount = Not (Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Retail);
			
		EndIf;
		
	EndIf;
	
	SelectionSettingsCache.Insert("AllowedToChangeAmount", AllowedToChangeAmount
		AND SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices());
		
	SetFormItemsProperties();
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure - handler of the OnCreateAtServer event
//
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("SetWarehouseRemainingsListSelection", 0.2, True);
	AttachIdleHandler("OutputBoardUsePreviousPick", 1.5, True); // Because of the behavioral feature of a platform, do it using the handler
	
EndProcedure // OnOpen()


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - HANDLERS OF THE FORM ATTRIBUTES
//

&AtClient
// Procedure - handler of the OnActivateRow event of the ListProductsAndServicesHierarchy attribute
//
Procedure ListProductsAndServicesHierarchyOnActivateRow(Item)
	
	AttachIdleHandler("UpdateFilterByGroupOfDynamicLists", 0.2, True);
	
EndProcedure // ListProductsAndServicesHierarchyOnActivateRow()

&AtClient
// Procedure - handler of the Selection event of the BalanceList attribute
//
Procedure ListInventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	DataCurrentRows = Items.ListInventory.CurrentData;
	
	If DataCurrentRows.UseCharacteristics Then
		
		If Items.FormRefreshTitles.Check Then
			
			OwnerCharacteristics = DataCurrentRows.ProductsAndServicesRef;
			
		EndIf;
		
		ShowCharacteristicsList();
		AttachIdleHandler("SetListsTitles", 0.1, True);
		OutputAdviceGoBackToProductsAndServices();
		
	Else
		
		AddProductsAndServicesToCart();
		
	EndIf;
	
EndProcedure // ListInventorySelection()

&AtClient
// Procedure - handler of the OnActivateRow event of the InventoryList attribute
//
Procedure ListInventoryOnActivateRow(Item)
	
	AttachIdleHandler("SetWarehouseRemainingsListSelection", 0.2, True);
	
EndProcedure // ListInventoryOnActivateRow()

&AtClient
// Procedure - handler of the DraggingEnd event of the WriteList attribute
//
Procedure ListInventoryDragEnd(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsAndServicesToCart();
	
EndProcedure // ListInventoryDragEnd()

&AtClient
// Procedure - handler of the Selection event of the CharacteristicsList attribute
//
Procedure CharacteristicsListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsAndServicesToCart();
	
EndProcedure // CharacteristicsListSelection()

&AtClient
// Procedure - handler of the DraggingEnd event of the CharacteristicsList attribute
//
Procedure CharacteristicsListDragEnd(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsAndServicesToCart();
	
EndProcedure // CharacteristicsListDragEnd()

&AtClient
// Procedure - handler of the OnActivateRow event of the CharacteristicsList attribute
//
Procedure CharacteristicsListOnActivateRow(Item)
	
	AttachIdleHandler("SetWarehouseRemainingsListSelection", 0.2, True);
	
EndProcedure // CharacteristicsListOnActivateRow()

&AtClient
// Procedure - handler of the Selection event of the StorageBalanceList attribute
//
Procedure ListWarehouseBalancesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsAndServicesToCart();
	
EndProcedure // WarehouseRemainingsChoiceList()

&AtClient
// Procedure - handler of the DraggingEnd event of the ListStorageBalance attribute
//
Procedure ListWarehouseBalancesDragEnd(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsAndServicesToCart();
	
EndProcedure // ListWarehouseRemainsDragEnd()

&AtClient
// Procedure - handler of the OnChange event of the SearchText attribute
//
Procedure SearchTextOnChange(Item)
	
	If IsBlankString(SearchText) Then
		
		If UseFullTextSearch Then
			
			SmallBusinessClient.DeleteListFilterItem(ListInventory, "ProductsAndServicesRef");
			SmallBusinessClient.DeleteListFilterItem(CharacteristicsList, "CharacteristicRef");
			
		Else
			
			ContextSearchOnClient();
			
		EndIf;
		
	Else
		
		SearchAndSetFilter();
		
	EndIf;
	
EndProcedure // SearchTextOnChange()

&AtClient
// Procedure - handler of the Clear event of the SearchText attribute
//
Procedure SearchTextClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	SearchText = "";
	If UseFullTextSearch Then
		
		SmallBusinessClient.DeleteListFilterItem(ListInventory, "ProductsAndServicesRef");
		SmallBusinessClient.DeleteListFilterItem(CharacteristicsList, "CharacteristicRef");
		
	Else
		
		ContextSearchOnClient();
		
	EndIf;
	
EndProcedure // SearchTextClear()

// The Selection cart tabular section

&AtClient
// Procedure - handler of the OnChange event of the ProductsAndServices attribute of the Cart tabular field
//
Procedure CartPriceBalanceReserveProductCharacteristicAndServicesOnChanging(Item)
	
	StringCart = Items.CartPriceBalanceReserveCharacteristic.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", 		Object.Company);
	StructureData.Insert("ProductsAndServices", 		StringCart.ProductsAndServices);
	StructureData.Insert("Characteristic", 		StringCart.Characteristic);
	StructureData.Insert("VATTaxation",	Object.VATTaxation);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", 			Object.PriceKind);
		StructureData.Insert("Factor",		1);
		
	EndIf;
	
	StructureData.Insert("DiscountMarkupKind",	Object.DiscountMarkupKind);
	// DiscountCards
	StructureData.Insert("DiscountCard",	Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	// End DiscountCards
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	StringCart.Quantity 		= 1;
	StringCart.MeasurementUnit	= StructureData.MeasurementUnit;
	StringCart.Price				= StructureData.Price;
	StringCart.DiscountMarkupPercent= StructureData.DiscountMarkupPercent;
	StringCart.VATRate 		= GetVATRate(StructureData.ProductsAndServicesVATRate);
	StringCart.DiscountMarkupPercent= StructureData.DiscountMarkupPercent + StructureData.DiscountPercentByDiscountCard; // DiscountCards
	
	CalculateAmountInTabularSectionLine(StringCart);
	
EndProcedure // BasketProductsAndServicesOnChange()

&AtClient
// Procedure - handler of the OnChange event of the Characteristics attribute of the Cart tabular field
//
Procedure CartPriceBalanceReserveCharacteristicCharacteristicOnChanging(Item)
	
	StringCart = Items.CartPriceBalanceReserveCharacteristic.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", 		Object.Company);
	StructureData.Insert("ProductsAndServices", 		StringCart.ProductsAndServices);
	StructureData.Insert("Characteristic", 		StringCart.Characteristic);
	StructureData.Insert("VATTaxation",	Object.VATTaxation);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", 			Object.PriceKind);
		StructureData.Insert("Factor",		1);
		
	EndIf;
	
	StructureData.Insert("DiscountMarkupKind",	Object.DiscountMarkupKind);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	StringCart.Quantity 		= 1;
	StringCart.MeasurementUnit	= StructureData.MeasurementUnit;
	StringCart.Price				= StructureData.Price;
	StringCart.VATRate 		= GetVATRate(StructureData.ProductsAndServicesVATRate);
	
	CalculateAmountInTabularSectionLine(StringCart);
	
EndProcedure // BasketCharacteristicsOnChange()

&AtClient
// Procedure - handler of the OnChange event of the Quantity attribute of the Cart tabular field
//
Procedure CartPriceBalanceReserveCharacteristicQuantityOnChanging(Item)
	
	StringCart = Items.CartPriceBalanceReserveCharacteristic.CurrentData;
	
	CalculateAmountInTabularSectionLine(StringCart);
	
EndProcedure // BasketQuantityOnChange()

&AtClient
// Procedure - handler of the OnChange event of the Quantity attribute of the Cart tabular field
//
Procedure CartPriceBalanceReserveCharacteristicReserveOnChanging(Item)
	
	StringCart = Items.CartPriceBalanceReserveCharacteristic.CurrentData;
	
	If StringCart.Reserve > StringCart.Quantity Then
		
		StringCart.Quantity = StringCart.Reserve;
		
	EndIf;
	
	CalculateAmountInTabularSectionLine(StringCart);
	
EndProcedure // CartReserveOnChange()

&AtClient
// Procedure - handler of the OnChange event of the Price attribute of the Basket tabular field
//
Procedure CartPriceBalanceReserveCharacteristicPriceOnChanging(Item)
	
	StringCart = Items.CartPriceBalanceReserveCharacteristic.CurrentData;
	
	CalculateAmountInTabularSectionLine(StringCart);
	
EndProcedure // CartPriceOnChange()

&AtClient
// Procedure - handler of the OnChange event of the Amount attribute of the Cart tabular field
//
Procedure CartPriceBalanceReserveCharacteristicAmountOnChanging(Item)
	
	StringCart = Items.CartPriceBalanceReserveCharacteristic.CurrentData;
	
	If StringCart.Quantity <> 0 Then
		
		StringCart.Price = StringCart.Amount / StringCart.Quantity;
		
	EndIf;
	
	CalculateVATSUM(StringCart);
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure // BasketAmountOnChange()

&AtClient
// Procedure - handler of the OnChange event of the VATRate attribute of the Cart tabular field
//
Procedure CartPriceBalanceReserveCharacteristicVATRateOnChanging(Item)
	
	StringCart = Items.CartPriceBalanceReserveCharacteristic.CurrentData;
	
	CalculateVATSUM(StringCart);
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure // BasketVATRateOnChange()

&AtClient
// Procedure - handler of the OnChange event of the VATRate attribute of the Cart tabular field
//
Procedure CartPriceBalanceReserveCharacteristicVATAmountOnChanging(Item)
	
	StringCart = Items.CartPriceBalanceReserveCharacteristic.CurrentData;
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure // BasketVATAmountOnChange()

&AtClient
// Procedure - handler of the SelectionFilter event the MeasurementUnit edit box of the Basket tabular field
//
Procedure CartPriceBalanceReserveCharacteristicMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StringCart = Items.CartPriceBalanceReserveCharacteristic.CurrentData;
	
	If StringCart.MeasurementUnit = ValueSelected 
		OR StringCart.Price = 0 Then
		
		Return;
		
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(StringCart.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		
		CurrentFactor = 1;
		
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		
		Factor = 1;
		
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		
		StructureData = GetDataMeasurementUnitOnChange(StringCart.MeasurementUnit, ValueSelected);
		
	ElsIf CurrentFactor = 0 Then
		
		StructureData = GetDataMeasurementUnitOnChange(StringCart.MeasurementUnit);
		
	ElsIf Factor = 0 Then
		
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
		
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
		
	EndIf;
	
	If StructureData.CurrentFactor <> 0 Then
		
		StringCart.Price = StringCart.Price * StructureData.Factor / StructureData.CurrentFactor;
		
	EndIf;
	
	CalculateAmountInTabularSectionLine(StringCart);
	
EndProcedure // CartPriceBalanceReserveCharacteristicMeasurementUnitSelectionProcessor()











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
