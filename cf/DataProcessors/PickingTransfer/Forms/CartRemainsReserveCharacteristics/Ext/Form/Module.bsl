
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
	InputHint = ?(FulltextSearchSetPartially, NStr("en='You need to update the index of full-text search...';ru='Необходимо обновить индекс полнотекстового поиска...'"), NStr("en='(ALT+F3) Enter search text ...';ru='(ALT+F3) Введите текст поиска...'"));
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
	FoundStrings = Object.CartRemainsReserveCharacteristics.FindRows(FilterStructure);
	
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
	CartRowData.Insert("Free", DataCurrentRows.FreeSender);
	
	If SelectionSettingsCache.RequestQuantity Then
		
		CartRowData.Insert("SelectionSettingsCache",	SelectionSettingsCache);
		CartRowData.Insert("Quantity",			1);
		CartRowData.Insert("MeasurementUnit", 	CartRowData.MeasurementUnit);
		
		NotificationDescriptionOnCloseSelection = New NotifyDescription("AfterQuantitySelection", ThisObject, CartRowData);
		OpenForm("DataProcessor.PickingTransfer.Form.Quantity", CartRowData, ThisForm, True, , ,NotificationDescriptionOnCloseSelection , FormWindowOpeningMode.LockOwnerWindow);
		
	Else
		
		If CartRowData.StringCart = Undefined Then
			
			StringCart = Object.CartRemainsReserveCharacteristics.Add();
			FillPropertyValues(StringCart, CartRowData);
			
		Else
			
			StringCart = FoundString;
			
		EndIf;
		
		StringCart.Quantity = StringCart.Quantity + 1;
		StringCart.Reserve	 = ?(ReservationEnabled AND FillReserveQuantity, min(StringCart.Quantity, CartRowData.Free),0);
		
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
		
		MessageText = NStr("en='There are no analogs for products and services.';ru='Для номенклатуры не заведены аналоги.'");
		
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
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
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

&AtServer
// Procedure fills in objects data
// by passed parameters called by the OnWriteObject event, 
//
Procedure FillObjectData()
	
	FillPropertyValues(Object, Parameters);
	
EndProcedure // FillObjectData()

&AtServer
// Procedure fills in document data that
// caused selection is called by the OnWriteObject event, 
//
Procedure FillInformationAboutDocument(InformationAboutDocument)
	
	DataProcessors.PickingTransfer.InformationAboutDocumentStructure(InformationAboutDocument);
	FillPropertyValues(InformationAboutDocument, Object);
	
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
	
	CartAddressInStorage = PutToTempStorage(Object.CartRemainsReserveCharacteristics.Unload(), Object.OwnerFormUUID);
	Return New Structure("CartAddressInStorage, OwnerFormUUID", CartAddressInStorage, Object.OwnerFormUUID);
	
EndFunction // WritePickToStorage()

&AtServer
// Procedure sets properties of the form items
//
Procedure SetFormItemsProperties()
	
	PickProductsAndServicesInDocuments.SetChoiceParameters(Items.CartRemainsReserveCharacteristicsProductsAndServices, Object.ProductsAndServicesType);
	
	CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryMeasurementUnit", "Visible", GetFunctionalOption("AccountingInVariousUOM"));
	CommonUseClientServer.SetFormItemProperty(Items, "CharacteristicsListMeasurementUnit", "Visible", GetFunctionalOption("AccountingInVariousUOM"));
	CommonUseClientServer.SetFormItemProperty(Items, "CartRemainsReserveCharacteristicsMeasurementUnit", "Visible", GetFunctionalOption("AccountingInVariousUOM"));
	
	CommonUseClientServer.SetFormItemProperty(Items, "FormChangeVisibleWarehouseBalance", "Check", True);
	CommonUseClientServer.SetFormItemProperty(Items, "FormChangeCartVisibile", "Check", True);
	CommonUseClientServer.SetFormItemProperty(Items, "FormRefreshTitles", "Check", True);
	
	CommonUseClientServer.SetFormItemProperty(Items, "FormTransitionProductsAndServicesCharacteristics", "Title", "ProductsAndServices");
	
	ReservationEnabled = GetFunctionalOption("InventoryReservation");
	
	CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryReserveSender", "Visible", ReservationEnabled);
	CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryReserveRecipient", "Visible", ReservationEnabled);
	CommonUseClientServer.SetFormItemProperty(Items, "ListWarehouseBalancesReserve", "Visible", ReservationEnabled);
	CommonUseClientServer.SetFormItemProperty(Items, "CartRemainsReserveCharacteristicsReserve", "Visible", ReservationEnabled);
	
	ShowCommand_FillReserveQuantity = (Object.OperationKind <> Enums.OperationKindsInventoryTransfer.TransferToOperation 
		AND Object.OperationKind <> Enums.OperationKindsInventoryTransfer.ReturnFromExploitation
		AND Object.StructuralUnitSender.StructuralUnitType <> Enums.StructuralUnitsTypes.Retail 
		AND Object.StructuralUnitSender.StructuralUnitType <> Enums.StructuralUnitsTypes.RetailAccrualAccounting
		AND ReservationEnabled); // All document conditions should be met and the reservation should be used
	
	CommonUseClientServer.SetFormItemProperty(Items, "FormFillReserveQuantity", "Visible", ShowCommand_FillReserveQuantity);
	
EndProcedure // SetFormItemsProperties()

&AtClient
// Procedure sets a passed item of form with the current
//
Procedure SetCurrentFormItem(Item)
	
	ThisForm.CurrentItem = Item;
	
EndProcedure // SetCurrentFormItems()

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
		
		FormTitle = NStr("en='Advice';ru='Совет'");
		MessageText = NStr("en='You can disable/enable using a new selection form in the user settings.';ru='Выключить/включить использование новой формы подбора можно в настройках пользователя.'");
		
		ShowUserAdvice(FormTitle, MessageText, True, "OutputBoardUsePreviousPick");
		
	EndIf;
	
EndProcedure // DisplaySelectionAdvice()

&AtClient
// Procedure of the user advice output about returning to the products and services list
//
Procedure OutputAdviceGoBackToProductsAndServices()
	
	If SelectionSettingsCache.OutputAdviceGoBackToProductsAndServices Then
		
		FormTitle = NStr("en='Advice';ru='Совет'");
		MessageText = NStr("en='You can return to the products and services list using context menu or the BackSpace button.';ru='Вернуться к списку номенклатуры можно при помощи контекстного меню или клавиши BackSpace.'");
		
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
	OpenForm("DataProcessor.PickingTransfer.Form.Setting", , ThisForm, True, , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
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
//Procedure - handler of the ShowProductsAndServices command (context. menu of the characteristics list)
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
	CommonUseClientServer.SetFormItemProperty(Items, "CartRemainsReserveCharacteristics", "Visible", Items.FormChangeCartVisibile.Check);
	
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
	
	SetCurrentFormItem(Items.CartRemainsReserveCharacteristics);
	
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
	
	If Items.ListInventory.CurrentItem  = Items.ListInventoryFreeRecipient Then
		
		DetailsParameters.Insert("StructuralUnit", Object.StructuralUnitPayee);
		
	Else
		
		DetailsParameters.Insert("StructuralUnit", Object.StructuralUnitSender);
		
	EndIf;
	
	NotificationDescriptionOnCloseSelection = New NotifyDescription("AfterOpeningReserveDecryption", ThisObject, DetailsParameters);
	OpenForm("DataProcessor.PickingTransfer.Form.DecryptReserve", DetailsParameters, ThisForm, True, , ,NotificationDescriptionOnCloseSelection , FormWindowOpeningMode.LockOwnerWindow);
	
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
	OpenForm("DataProcessor.PickingTransfer.Form.InformationAboutDocument", SelectionSettingsCache.InformationAboutDocument, ThisForm, True, , ,NotificationDescriptionOnCloseSelection, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure // InformationAboutDocument()

&AtClient
// Procedure - handler of the ProductsAndServicesPresent command
//
Procedure ProductsAndServicesInInventory(Command)
	
	If Items.FormProductsAndServicesInInventory.Check Then
		
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(ListInventory, "BalanceSender");
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(CharacteristicsList, "BalanceSender");
		CommonUseClientServer.SetFormItemProperty(Items, "FormProductsAndServicesInInventory", "Check", False);
		
	Else
		
		//::: Products and services
		ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(ListInventory.SettingsComposer.FixedSettings.Filter, "BalanceSender");
		If ItemArray.Count() = 0 Then
			
			CommonUseClientServer.AddCompositionItem(ListInventory.SettingsComposer.FixedSettings.Filter, "BalanceSender", DataCompositionComparisonType.Filled, 0);
			
		Else
			
			CommonUseClientServer.ChangeFilterItems(ListInventory.SettingsComposer.FixedSettings.Filter, "BalanceSender", , 0, DataCompositionComparisonType.Filled);
			
		EndIf;
		
		//::: Characteristics
		CharacteristicItemsArray = CommonUseClientServer.FindFilterItemsAndGroups(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "BalanceSender");
		If CharacteristicItemsArray.Count() = 0  Then
			
			CommonUseClientServer.AddCompositionItem(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "BalanceSender", DataCompositionComparisonType.Filled, 0);
			
		Else
			
			CommonUseClientServer.ChangeFilterItems(CharacteristicsList.SettingsComposer.FixedSettings.Filter, "BalanceSender", , 0, DataCompositionComparisonType.Filled);
			
		EndIf;
		
		CommonUseClientServer.SetFormItemProperty(Items, "FormProductsAndServicesInInventory", "Check", True);
		
	EndIf;
	
EndProcedure // ProductsAndServicesInStore()

&AtClient
// Procedure - handler of the FillReserveQuantity command
//
Procedure FillReserveQuantity(Command)
	
	FillReserveQuantity = Not FillReserveQuantity;
	CommonUseClientServer.SetFormItemProperty(Items, "FormFillReserveQuantity", "Check", FillReserveQuantity);
	
EndProcedure // FillReserveCount()


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

&AtClient
// Procedure processes the results of opening the Quantities additional form
//
//
Procedure AfterQuantitySelection(ClosingResult, CartRowData) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If CartRowData.StringCart = Undefined Then
			
			StringCart = Object.CartRemainsReserveCharacteristics.Add();
			FillPropertyValues(StringCart, CartRowData);
			StringCart.Quantity = ClosingResult.Quantity;
			
		Else
			
			StringCart = Object.CartRemainsReserveCharacteristics.FindByID(CartRowData.StringCart);
			StringCart.Quantity = StringCart.Quantity + ClosingResult.Quantity;
			
		EndIf;
		
		StringCart.Reserve	= ?(ReservationEnabled AND FillReserveQuantity, min(StringCart.Quantity, CartRowData.Free),0);
		
	EndIf;
	
EndProcedure // AfterQuantitySelection()

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
	
	DataProcessors.PickingTransfer.CheckParametersFilling(Parameters, Cancel);
	
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
	SelectionSettingsCache.Insert("CurrentUser", Users.AuthorizedUser());
	SelectionSettingsCache.Insert("InformationAboutDocument", InformationAboutDocument);
	
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
Procedure CartRemainsReserveCharacteristicsProductsAndServicesOnChange(Item)
	
	StringCart = Items.CartRemainsReserveCharacteristics.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", 		Object.Company);
	StructureData.Insert("ProductsAndServices", 		StringCart.ProductsAndServices);
	StructureData.Insert("Characteristic", 		StringCart.Characteristic);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	StringCart.Quantity	= 1;
	StringCart.MeasurementUnit	= StructureData.MeasurementUnit;
	
EndProcedure // BasketProductsAndServicesOnChange()

&AtClient
// Procedure - handler of the OnChange event of the Characteristics attribute of the Cart tabular field
//
Procedure CartRemainsReserveCharacteristicsCharacteristicOnChange(Item)
	
	StringCart = Items.CartRemainsReserveCharacteristics.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", 		Object.Company);
	StructureData.Insert("ProductsAndServices", 		StringCart.ProductsAndServices);
	StructureData.Insert("Characteristic", 		StringCart.Characteristic);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	StringCart.Quantity	= 1;
	StringCart.MeasurementUnit	= StructureData.MeasurementUnit;
	
EndProcedure // BasketCharacteristicsOnChange()

&AtClient
// Procedure - handler of the OnChange event of the Quantity attribute of the Cart tabular field
//
Procedure CartRemainsReserveCharacteristicsReserveOnChange(Item)
	
	StringCart = Items.CartRemainsReserveCharacteristics.CurrentData;
	
	If StringCart.Reserve > StringCart.Quantity Then
		
		StringCart.Quantity = StringCart.Reserve;
		
	EndIf;
	
EndProcedure // CartReserveOnChange()






