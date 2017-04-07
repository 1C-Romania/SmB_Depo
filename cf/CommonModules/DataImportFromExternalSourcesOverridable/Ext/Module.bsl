Procedure AddConditionalMatchTablesDesign(ThisObject, AttributePath, DataLoadSettings) Export
	
	If DataLoadSettings.IsTabularSectionImport Then
		
		Return;
		
	ElsIf DataLoadSettings.IsCatalogImport Then
		
		If DataLoadSettings.FillingObjectFullName = "Catalog.ProductsAndServices" Then
			
			FieldName = "ProductsAndServices";
			
		ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties" Then
			
			FieldName = "Counterparty";
			
		EndIf;
		
		TextNewItem	= NStr("en='<New item will be created>';ru='<Будет создан новый элемент>'");
		TextSkipped		= NStr("en='<Data will be skipped>';ru='<Данные будут пропущены>'");
		ConditionalAppearanceText = ?(DataLoadSettings.CreateIfNotMatched, TextNewItem, TextSkipped);
		
	ElsIf DataLoadSettings.IsInformationRegisterImport Then
		
		If DataLoadSettings.FillingObjectFullName = "InformationRegister.ProductsAndServicesPrices" Then
			
			FieldName = "ProductsAndServices";
			
		EndIf;
		
		ConditionalAppearanceText = NStr("en='<Row will be skipped...>';ru='<Строка будет пропущена...>'");
		
	EndIf;
	
	DCConditionalAppearanceItem = ThisObject.ConditionalAppearance.Items.Add();
	DCConditionalAppearanceItem.Use = True;
	
	DCFilterItem = DCConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DCFilterItem.LeftValue = New DataCompositionField(AttributePath + "." + FieldName);
	DCFilterItem.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	DCConditionalAppearanceItem.Appearance.SetParameterValue(New DataCompositionParameter("Text"), ConditionalAppearanceText);
	DCConditionalAppearanceItem.Appearance.SetParameterValue(New DataCompositionParameter("TextColor"), New Color(175, 175, 175));
	
	FormedFieldKD = DCConditionalAppearanceItem.Fields.Items.Add();
	FormedFieldKD.Field = New DataCompositionField(FieldName);
	
EndProcedure

Procedure ChangeConditionalDesignText(ConditionalAppearance, DataLoadSettings) Export
	
	If DataLoadSettings.IsTabularSectionImport Then
		
		Return;
		
	ElsIf DataLoadSettings.IsInformationRegisterImport Then
		
		Return;
		
	ElsIf DataLoadSettings.IsCatalogImport Then
		
		If DataLoadSettings.FillingObjectFullName = "Catalog.ProductsAndServices" Then
			
			FieldName = "ProductsAndServices";
			
		ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties" Then
			
			FieldName = "Counterparty";
			
		EndIf;
		
		TextNewItem	= NStr("en='<New item will be created>';ru='<Будет создан новый элемент>'");
		TextSkipped		= NStr("en='<Data will be skipped>';ru='<Данные будут пропущены>'");
		ConditionalAppearanceText = ?(DataLoadSettings.CreateIfNotMatched, TextNewItem, TextSkipped);
		
	EndIf;
	
	SearchItem = New DataCompositionField(FieldName);
	For Each ConditionalAppearanceItem IN ConditionalAppearance.Items Do
		
		ThisIsTargetFormat = False;
		For Each MadeOutField IN ConditionalAppearanceItem.Fields.Items Do
			
			If MadeOutField.Field = SearchItem Then
				
				ThisIsTargetFormat = True;
				Break;
				
			EndIf;
			
		EndDo;
		
		If ThisIsTargetFormat Then
			
			ConditionalAppearanceItem.Appearance.SetParameterValue(New DataCompositionParameter("Text"), ConditionalAppearanceText);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure WhenDeterminingDataImportForm(DataImportFormNameFromExternalSources, FillingObjectFullName, FilledObject) Export
	
	
	
EndProcedure

Procedure PredefineDataImportSamples(DataLoadSettings, UUID) Export
	
	//If FilledObjectFullName = "Catalog.Specifications.TabularSection.Content" Then
	//	
	//	Catalogs.Specifications.OnDefineDataImportSamples(DataLoadSettings, UUID);
	//	
	//Else FilledObjectFullName = "Catalog.ProductsAndServices" Then
	//	
	//	Catalogs.ProductsAndServices.OnDefineDataImportSamples(DataLoadSettings, UUID);
	//	
	//EndIf;
	
EndProcedure

Procedure OverrideDataImportFieldsFilling(ImportFieldsTable, FillingObjectFullName) Export
	
	
	
EndProcedure

Procedure WhenAddingServiceFields(ServiceFieldsGroup, FillingObjectFullName) Export
	
	
	
EndProcedure

Procedure AfterAddingItemsToMatchesTables(ThisObject, DataLoadSettings) Export
	
	If DataLoadSettings.FillingObjectFullName = "Catalog.ProductsAndServices" Then
		
		ThisObject.Items["Parent"].ChoiceForm = "Catalog.ProductsAndServices.Form.GroupChoiceForm";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties"  Then
		
		ThisObject.Items["Parent"].ChoiceForm = "Catalog.Counterparties.Form.GroupChoiceForm.";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Inventory" Then
		
		ArrayProductsAndServicesTypes = New Array;
		ArrayProductsAndServicesTypes.Add(Enums.ProductsAndServicesTypes.InventoryItem);
		
		NewParameter = New ChoiceParameter("Filter.ProductsAndServicesType", ArrayProductsAndServicesTypes);
		
		ParameterArray = New Array;
		ParameterArray.Add(NewParameter);
		
		ThisObject.Items["ProductsAndServices"].ChoiceParameters = New FixedArray(ParameterArray);
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Expenses" Then
		
		ArrayProductsAndServicesTypes = New Array;
		ArrayProductsAndServicesTypes.Add(Enums.ProductsAndServicesTypes.Service);
		
		NewParameter = New ChoiceParameter("Filter.ProductsAndServicesType", ArrayProductsAndServicesTypes);
		
		ParameterArray = New Array;
		ParameterArray.Add(NewParameter);
		
		ThisObject.Items["ProductsAndServices"].ChoiceParameters = New FixedArray(ParameterArray);
		
	EndIf;
	
EndProcedure

Procedure WhenDeterminingUsageMode(UseTogether) Export
	
	UseTogether = True;
	
EndProcedure

Function DefaultPriceKind() Export
	
	Return Catalogs.Counterparties.GetMainKindOfSalePrices();
	
EndFunction

#Region ComparisonMethods

//:::Common

Procedure CatalogByName(CatalogName, CatalogValue, CatalogDescription, DefaultValue = Undefined)
	
	If Not IsBlankString(CatalogDescription) Then
		
		CatalogRef = Catalogs[CatalogName].FindByDescription(CatalogDescription, False);
		If ValueIsFilled(CatalogRef) Then
			
			CatalogValue = CatalogRef;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(CatalogValue) Then
		
		CatalogValue = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure MapEnumeration(EnumerationName, EnumValue, IncomingData, DefaultValue)
	
	If ValueIsFilled(IncomingData) Then
		
		For Each EnumerationItem IN Metadata.Enums[EnumerationName].EnumValues Do
			
			Synonym = EnumerationItem.Synonym;
			If Find(Upper(Synonym), Upper(IncomingData)) > 0 Then
				
				EnumValue = Enums[EnumerationName][EnumerationItem.Name];
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Not ValueIsFilled(EnumValue) Then
		
		EnumValue = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure MapGLAccount(GLAccount, GLAccount_IncomingData, DefaultValue)
	
	If Not IsBlankString(GLAccount_IncomingData) Then
		
		FoundGLAccount = ChartsOfAccounts.Managerial.FindByCode(GLAccount_IncomingData);
		If FoundGLAccount = Undefined Then
			
			FoundGLAccount = ChartsOfAccounts.Managerial.FindByDescription(GLAccount_IncomingData);
			
		EndIf;
		
		If ValueIsFilled(FoundGLAccount) Then
			
			GLAccount = FoundGLAccount
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(GLAccount) Then
		
		GLAccount = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure ConvertStringToBoolean(ValueBoolean, IncomingData) Export
	
	IncomingData = UPPER(TrimAll(IncomingData));
	
	Array = New Array;
	Array.Add("+");
	Array.Add("1");
	Array.Add("TRUE");
	Array.Add("Yes");
	Array.Add("TRUE");
	Array.Add("YES");
	
	ValueBoolean = (Array.Find(IncomingData) <> Undefined);
	
EndProcedure

Procedure ConvertRowToNumber(NumberResult, NumberByString, DefaultValue = 0) Export
	
	If IsBlankString(NumberByString) Then
		
		NumberResult = DefaultValue;
		Return;
		
	EndIf;
	
	NumberStringCopy = StrReplace(NumberByString, ".", "");
	NumberStringCopy = StrReplace(NumberStringCopy, ",", "");
	NumberStringCopy = StrReplace(NumberStringCopy, Char(32), "");
	NumberStringCopy = StrReplace(NumberStringCopy, Char(160), "");
	If StringFunctionsClientServer.OnlyNumbersInString(NumberStringCopy) Then
		
		NumberStringCopy = StrReplace(NumberByString, " ", "");
		Try // through try, for example, in case of several points in the expression
			
			NumberResult = Number(NumberStringCopy);
			
		Except
			
			NumberResult = 0; // If trash was sent, then zero
			
		EndTry;
		
	Else
		
		NumberResult = 0; // If trash was sent, then zero
		
	EndIf;
	
EndProcedure

Procedure ConvertStringToDate(DateResult, DateString) Export
	
	If IsBlankString(DateString) Then
		
		DateResult = Date(0001, 01, 01);
		
	Else
		
		CopyDateString = DateString;
		
		DelimitersArray = New Array;
		DelimitersArray.Add(".");
		DelimitersArray.Add("/");
		
		For Each Delimiter IN DelimitersArray Do
			
			NumberByString = "";
			MonthString = "";
			YearString = "";
			
			SeparatorPosition = Find(CopyDateString, Delimiter);
			If SeparatorPosition > 0 Then
				
				NumberByString = Left(CopyDateString, SeparatorPosition - 1);
				CopyDateString = Mid(CopyDateString, SeparatorPosition + 1);
				
			EndIf;
			
			SeparatorPosition = Find(CopyDateString, Delimiter);
			If SeparatorPosition > 0 Then
				
				MonthString = Left(CopyDateString, SeparatorPosition - 1);
				CopyDateString = Mid(CopyDateString, SeparatorPosition + 1);
				
			EndIf;
			
			YearString = CopyDateString;
			
			If Not IsBlankString(NumberByString) 
				AND Not IsBlankString(MonthString) 
				AND Not IsBlankString(YearString) Then
				
				Try
					
					DateResult = Date(Number(YearString), Number(MonthString), Number(NumberByString));
					
				Except
					
					DateResult = Date(0001, 01, 01);
					
				EndTry;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure CopyRowToStringTypeValue(StringTypeValue, String) Export
	
	StringTypeValue = TrimAll(String);
	
EndProcedure

Procedure CompareProductsAndServices(ProductsAndServices, Barcode, SKU, ProductsAndServicesDescription, Code = Undefined) Export
	
	ValueWasMapped = False;
	If ValueIsFilled(Code) Then
		
		CatalogRef = Catalogs.ProductsAndServices.FindByCode(Code, False);
		If Not CatalogRef.IsEmpty() Then
			
			ValueWasMapped = True;
			ProductsAndServices = CatalogRef;
			
		EndIf;
		
	EndIf;
	
	If Not ValueWasMapped 
		AND ValueIsFilled(Barcode) Then
		
		Query = New Query("SELECT BC.ProductsAndServices FROM InformationRegister.ProductsAndServicesBarcodes AS BC WHERE BC.Barcode = &Barcode");
		Query.SetParameter("Barcode", Barcode);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			ValueWasMapped = True;
			ProductsAndServices = Selection.ProductsAndServices;
			
		EndIf;
		
	EndIf;
	
	If Not ValueWasMapped 
		AND ValueIsFilled(SKU) Then
		
		CatalogRef = Catalogs.ProductsAndServices.FindByAttribute("SKU", SKU);
		If Not CatalogRef.IsEmpty() Then
			
			ValueWasMapped = True;
			ProductsAndServices = CatalogRef;
			
		EndIf;
		
	EndIf;
	
	If Not ValueWasMapped 
		AND ValueIsFilled(ProductsAndServicesDescription) Then
		
		CatalogRef = Catalogs.ProductsAndServices.FindByDescription(ProductsAndServicesDescription, True);
		If ValueIsFilled(CatalogRef)
			AND Not CatalogRef.IsFolder Then
			
			ValueWasMapped = True;
			ProductsAndServices = CatalogRef;
			
		Else
			
			Query = New Query("SELECT Catalog.ProductsAndServices.Ref WHERE NOT Catalog.ProductsAndServices.IsFolder And Catalog.ProductsAndServices.Description LIKE &Description");
			Query.SetParameter("Description", ProductsAndServicesDescription + "%");
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				
				ValueWasMapped = True;
				ProductsAndServices = Selection.Ref;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Categories for catalog of products and services are not used at the moment.
	If ValueIsFilled(ProductsAndServices)
		AND ProductsAndServices.IsFolder Then
		
		ProductsAndServices = Catalogs.ProductsAndServices.EmptyRef();
		
	EndIf;
	
EndProcedure

Procedure MapCharacteristic(Characteristic, ProductsAndServices, Barcode, Characteristic_IncomingData) Export
	
	If ValueIsFilled(ProductsAndServices) Then
		
		ValueWasMapped = False;
		If ValueIsFilled(Barcode) Then
			
			Query = New Query("SELECT BC.Characteristic FROM InformationRegister.ProductsAndServicesBarcodes AS BC WHERE BC.Barcode = &Barcode AND BC.ProductsAndServices = &ProductsAndServices");
			Query.SetParameter("Barcode", Barcode);
			Query.SetParameter("ProductsAndServices", ProductsAndServices);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				
				ValueWasMapped = True;
				Characteristic = Selection.Characteristic;
				
			EndIf;
			
		EndIf;
		
		If Not ValueWasMapped
			AND ValueIsFilled(Characteristic_IncomingData) Then
			
			// Products and services or products and services category can be owners of a characteristic.
			//
			
			CatalogRef = Undefined;
			CatalogRef = Catalogs.ProductsAndServicesCharacteristics.FindByDescription(Characteristic_IncomingData, False, , ProductsAndServices);
			If Not ValueIsFilled(CatalogRef)
				AND ValueIsFilled(ProductsAndServices.ProductsAndServicesCategory) Then
				
				CatalogRef = Catalogs.ProductsAndServicesCharacteristics.FindByDescription(Characteristic_IncomingData, False, , ProductsAndServices.ProductsAndServicesCategory);
				
			EndIf;
			
			If ValueIsFilled(CatalogRef) Then
				
				Characteristic = CatalogRef;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapBatch(Batch, ProductsAndServices, Barcode, Batch_IncomingData) Export
	
	If ValueIsFilled(ProductsAndServices) Then
		
		ValueWasMapped = False;
		If ValueIsFilled(Barcode) Then
			
			Query = New Query("SELECT BC.Batch FROM InformationRegister.ProductsAndServicesBarcodes AS BC WHERE BC.Barcode = &Barcode AND BC.ProductsAndServices = &ProductsAndServices");
			Query.SetParameter("Barcode", Barcode);
			Query.SetParameter("ProductsAndServices", ProductsAndServices);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				
				ValueWasMapped = True;
				Batch = Selection.Batch;
				
			EndIf;
			
		EndIf;
		
		If Not ValueWasMapped
			AND ValueIsFilled(Batch_IncomingData) Then
			
			CatalogRef = Catalogs.ProductsAndServicesBatches.FindByDescription(Batch_IncomingData, False, , ProductsAndServices);
			If ValueIsFilled(CatalogRef) Then
				
				Batch = CatalogRef;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapUOM(ProductsAndServices, MeasurementUnit, MeasurementUnit_IncomingData, DefaultValue) Export
	
	If Not IsBlankString(MeasurementUnit_IncomingData) Then
		
		CatalogRef = Catalogs.UOMClassifier.FindByDescription(MeasurementUnit_IncomingData, False);
		If ValueIsFilled(CatalogRef) Then
			
			MeasurementUnit = CatalogRef;
			
		ElsIf ValueIsFilled(ProductsAndServices) Then
			
			CatalogRef = Catalogs.UOM.FindByDescription(MeasurementUnit_IncomingData, False, , ProductsAndServices);
			If ValueIsFilled(CatalogRef) Then
				
				MeasurementUnit = CatalogRef;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(MeasurementUnit) Then
		
		MeasurementUnit = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure MapParent(CatalogName, Parent, Parent_IncomingData, DefaultValue) Export
	
	If Not IsBlankString(Parent_IncomingData) Then
		
		Query = New Query("Select Catalog." + CatalogName + ".Ref WHERE Catalog." + CatalogName + ".IsFolder And Catalog." + CatalogName + ".Description LIKE &Description");
		Query.SetParameter("Description", Parent_IncomingData + "%");
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			
			Parent = Selection.Ref;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Parent) Then
		
		Parent = DefaultValue;
		
	EndIf;
	
EndProcedure

//:::Specification

Procedure MapRowType(RowType, RowType_IncomingData, DefaultValue) Export
	
	MapEnumeration("SpecificationContentRowTypes", RowType, RowType_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapSpecification(Specification, Specification_IncomingData, ProductsAndServices) Export
	
	If ValueIsFilled(ProductsAndServices) 
		AND Not IsBlankString(Specification_IncomingData) Then
		
		CatalogRef = Catalogs.Specifications.FindByDescription(Specification_IncomingData, False, , ProductsAndServices);
		If ValueIsFilled(CatalogRef) Then
			
			Specification = CatalogRef;
			
		EndIf;
		
	EndIf;
	
EndProcedure

//:::ProductsAndServices

Procedure MapProductsAndServicesType(ProductsAndServicesType, ProductsAndServicesType_IncomingData, DefaultValue) Export
	
	MapEnumeration("ProductsAndServicesTypes", ProductsAndServicesType, ProductsAndServicesType_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapEstimationMethod(EstimationMethod, EstimationMethod_IncomingData, DefaultValue) Export
	
	MapEnumeration("InventoryValuationMethods", EstimationMethod, EstimationMethod_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapBusinessActivity(BusinessActivity, BusinessActivity_IncomingData, DefaultValue) Export
	
	UseEnabled = GetFunctionalOption("AccountingBySeveralBusinessActivities");
	If Not UseEnabled Then
		
		// You can not fill in the default value as it can, for instance, come from custom settings.
		//
		BusinessActivity = Catalogs.BusinessActivities.MainActivity;
		
	Else
		
		CatalogByName("BusinessActivities", BusinessActivity, BusinessActivity_IncomingData, DefaultValue);
		
	EndIf;
	
EndProcedure

Procedure MapProductsAndServicesCategory(ProductsAndServicesCategory, ProductsAndServicesCategory_IncomingData, DefaultValue) Export
	
	CatalogByName("ProductsAndServicesCategories", ProductsAndServicesCategory, ProductsAndServicesCategory_IncomingData, DefaultValue)
	
EndProcedure

Procedure MapSupplier(Vendor, Vendor_IncomingData) Export
	
	If IsBlankString(Vendor_IncomingData) Then
		
		Return;
		
	EndIf;
	
	//:::TIN Search
	Separators = New Array;
	Separators.Add("/");
	Separators.Add("\");
	Separators.Add("-");
	Separators.Add("|");
	
	TIN = "";
	
	For Each SeparatorValue IN Separators Do
		
		SeparatorPosition = Find(Vendor_IncomingData, SeparatorValue);
		If SeparatorPosition = 0 Then 
			
			Continue;
			
		EndIf;
		
		TIN = Left(Vendor_IncomingData, SeparatorPosition - 1);
		
		Query = New Query("SELECT Catalog.Counterparties.Ref WHERE Not IsFolder AND TIN = &TIN");
		Query.SetParameter("TIN", TIN);
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			Vendor = Selection.Ref;
			Return;
			
		EndIf;
		
	EndDo;
	
	//:::Search TIN
	Query = New Query("SELECT Catalog.Counterparties.Ref WHERE Not IsFolder AND TIN = &TIN");
	Query.SetParameter("TIN", Vendor_IncomingData);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Vendor = Selection.Ref;
		Return;
		
	EndIf;
	
	//:::Search Name
	CatalogRef = Catalogs.Counterparties.FindByDescription(Vendor_IncomingData, False);
	If ValueIsFilled(CatalogRef) Then
		
		Vendor = CatalogRef;
		
	EndIf;
	
EndProcedure

Procedure MapStructuralUnit(Warehouse, Warehouse_IncomingData, DefaultValue) Export
	
	CatalogByName("StructuralUnits", Warehouse, Warehouse_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapReplenishmentMethod(ReplenishmentMethod, ReplenishmentMethod_IncomingData, DefaultValue) Export
	
	MapEnumeration("InventoryReplenishmentMethods", ReplenishmentMethod, ReplenishmentMethod_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapVATRate(VATRate, VATRate_IncomingData, DefaultValue) Export
	
	CatalogByName("VATRates", VATRate, VATRate_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapInventoryGLAccount(InventoryGLAccount, InventoryGLAccount_IncomingData, DefaultValue) Export
	
	MapGLAccount(InventoryGLAccount, InventoryGLAccount_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapExpensesGLAccount(ExpensesGLAccount, ExpensesGLAccount_IncomingData, DefaultValue) Export
	
	MapGLAccount(ExpensesGLAccount, ExpensesGLAccount_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapCell(Cell, Cell_IncomingData, DefaultValue) Export
	
	CatalogByName("Cells", Cell, Cell_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapPriceGroup(PriceGroup, PriceGroup_IncomingData, DefaultValue) Export
	
	CatalogByName("PriceGroups", PriceGroup, PriceGroup_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapOriginCountry(CountryOfOrigin, CountryOfOrigin_IncomingData, DefaultValue) Export
	
	If Not IsBlankString(CountryOfOrigin_IncomingData) Then
		
		CatalogRef = Catalogs.WorldCountries.FindByDescription(CountryOfOrigin_IncomingData, False);
		If Not ValueIsFilled(CatalogRef) Then
			
			CatalogRef = Catalogs.WorldCountries.FindByAttribute("AlphaCode3", CountryOfOrigin_IncomingData);
			If Not ValueIsFilled(CatalogRef) Then
				
				CatalogRef = Catalogs.WorldCountries.FindByCode(CountryOfOrigin_IncomingData, True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(CatalogRef) Then
		
		CountryOfOrigin = CatalogRef;
		
	Else
		
		CountryOfOrigin = DefaultValue;
		
	EndIf;
	
EndProcedure

//:::Purchase order
Procedure MatchOrder(Order, Order_IncomingData) Export
	
	If IsBlankString(Order_IncomingData) Then
		
		Return;
		
	EndIf;
	
	SuppliersTagsArray = New Array;
	SuppliersTagsArray.Add("Purchase order");
	SuppliersTagsArray.Add("PurchaseOrder");
	SuppliersTagsArray.Add("Vendor");
	SuppliersTagsArray.Add("Vendor");
	SuppliersTagsArray.Add("Post");
	
	NumberForSearch	= Order_IncomingData;
	DocumentKind	= "CustomerOrder";
	For Each TagFromArray IN SuppliersTagsArray Do
		
		If Find(Order_IncomingData, TagFromArray) > 0 Then
			
			DocumentKind = "PurchaseOrder";
			NumberForSearch = TrimAll(StrReplace(NumberForSearch, "", TagFromArray));
			
		EndIf;
		
	EndDo;
	
	Query = New Query("Select Document.CustomerOrder.Ref Where Number LIKE &Number ORDER BY Date Desc");
	Query.SetParameter("Number", "%" + NumberForSearch + "%");
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Order = Selection.Ref;
		
	EndIf;
	
EndProcedure

//:::Counterparty
Procedure MapCounterparty(Counterparty, TIN_KPP, CounterpartyDescription, BankAccount) Export
	
	//:::TIN Search
	If Not IsBlankString(TIN_KPP) Then
		
		Separators = New Array;
		Separators.Add("/");
		Separators.Add("\");
		Separators.Add("-");
		Separators.Add("|");
		
		TIN = "";
		
		For Each SeparatorValue IN Separators Do
			
			SeparatorPosition = Find(TIN_KPP, SeparatorValue);
			If SeparatorPosition = 0 Then 
				
				Continue;
				
			EndIf;
			
			TIN = Left(TIN_KPP, SeparatorPosition - 1);
			
			Query = New Query("SELECT Catalog.Counterparties.Ref WHERE Not IsFolder AND TIN = &TIN");
			Query.SetParameter("TIN", TIN);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				
				Counterparty = Selection.Ref;
				Return;
				
			EndIf;
			
		EndDo;
	
		//:::Search TIN
		Query = New Query("SELECT Catalog.Counterparties.Ref WHERE Not IsFolder AND TIN = &TIN");
		Query.SetParameter("TIN", TIN_KPP);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			Counterparty = Selection.Ref;
			Return;
			
		EndIf;
		
	EndIf;
	
	//:::Search Name
	If Not IsBlankString(CounterpartyDescription) Then
		
		CatalogRef = Catalogs.Counterparties.FindByDescription(CounterpartyDescription, False);
		If ValueIsFilled(CatalogRef) Then
			
			Counterparty = CatalogRef;
			Return;
			
		EndIf;
		
	EndIf;
	
	//:::Current account number
	If Not IsBlankString(BankAccount) Then
		
		CatalogRef = Catalogs.BankAccounts.FindByAttribute("AccountNo", BankAccount);
		If ValueIsFilled(CatalogRef) Then
			
			Counterparty = CatalogRef.Owner;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapIndividualPerson(Individual, Individual_IncomingData) Export
	
	CatalogByName("Individuals", Individual, Individual_IncomingData, Undefined);
	
EndProcedure

Procedure MapAccessGroup(AccessGroup, AccessGroup_IncomingData) Export
	
	CatalogByName("CounterpartiesAccessGroups", AccessGroup, AccessGroup_IncomingData);
	
EndProcedure

Procedure MapGLAccountCustomerSettlements(GLAccountCustomerSettlements, GLAccountCustomerSettlements_IncomingData, DefaultValue) Export
	
	MapGLAccount(GLAccountCustomerSettlements, GLAccountCustomerSettlements_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapCustomerAdvancesGLAccount(CustomerAdvancesGLAccount, CustomerAdvancesGLAccount_IncomingData, DefaultValue) Export
	
	MapGLAccount(CustomerAdvancesGLAccount, CustomerAdvancesGLAccount_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapGLAccountVendorSettlements(GLAccountVendorSettlements, GLAccountVendorSettlements_IncomingData, DefaultValue) Export
	
	MapGLAccount(GLAccountVendorSettlements, GLAccountVendorSettlements_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapVendorAdvancesGLAccount(VendorAdvancesGLAccount, VendorAdvancesGLAccount_IncomingData, DefaultValue) Export
	
	MapGLAccount(VendorAdvancesGLAccount, VendorAdvancesGLAccount_IncomingData, DefaultValue);
	
EndProcedure

//:::Products and services prices

Procedure MapPriceKind(PriceKind, PriceKind_IncomingData, DefaultValue) Export
	
	CatalogByName("PriceKinds", PriceKind, PriceKind_IncomingData, DefaultValue);
	
EndProcedure

//:::Enter opening balance

Procedure MapContract(Counterparty, Contract, Contract_IncomingData) Export
	
	If ValueIsFilled(Counterparty) 
		AND ValueIsFilled(Contract_IncomingData) Then
		
		CatalogRef = Undefined;
		CatalogRef = Catalogs.CounterpartyContracts.FindByDescription(Contract_IncomingData, False, , Counterparty);
		If Not ValueIsFilled(CatalogRef) Then
			
			CatalogRef = Catalogs.CounterpartyContracts.FindByAttribute("Number", Contract_IncomingData, , Counterparty);
			
		EndIf;
		
		If ValueIsFilled(CatalogRef) Then
			
			Contract = CatalogRef;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapOrderByNumberDate(Order, DocumentTypeName, Counterparty, Number_IncomingData, Date_IncomingData) Export
	
	If IsBlankString(Number_IncomingData) Then
		
		Return;
		
	EndIf;
	
	If DocumentTypeName <> "PurchaseOrder" Then
		
		DocumentTypeName = "CustomerOrder"
		
	EndIf;
	
	TableName = "Document." + DocumentTypeName;
	
	Query = New Query("Select Order.Ref FROM &TableName AS Order Where Order.Counterparty = &Counterparty And Order.Number LIKE &Number");
	Query.Text = StrReplace(Query.Text, "&TableName", TableName);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Number", "%" + Number_IncomingData + "%");
	
	If Not IsBlankString(Date_IncomingData) Then
		
		DateFromString = Date('00010101');
		ConvertStringToDate(DateFromString, Date_IncomingData);
		
		If ValueIsFilled(DateFromString) Then
			
			Query.Text = Query.Text + " And Order.Date Between &StartDate And &EndDate";
			Query.SetParameter("StartDate", BegOfDay(DateFromString));
			Query.SetParameter("EndDate", EndOfDay(DateFromString));
			
		EndIf;
		
	EndIf;
	
	Query.Text = Query.Text + " SORT BY Order.Date Desc";
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Order = Selection.Ref;
		
	EndIf;
	
EndProcedure

Procedure MapAccountingDocumentByNumberDate(Document, DocumentTypeName, Counterparty, Number_IncomingData, Date_IncomingData) Export
	
	If IsBlankString(DocumentTypeName) 
		OR IsBlankString(Number_IncomingData) Then
		
		Return;
		
	EndIf;
	
	MapDocumentNames = New Map;
	
	MapDocumentNames.Insert("CustomerOrder", 		"CustomerOrder");
	MapDocumentNames.Insert("Customer orders",	"CustomerOrder");
	MapDocumentNames.Insert("Customer order",		"CustomerOrder");
	
	MapDocumentNames.Insert("Netting",			"Netting");
	MapDocumentNames.Insert("Debt adjustment",	"Netting");
	MapDocumentNames.Insert("Debt adjustments",	"Netting");
	
	MapDocumentNames.Insert("AgentReport",	"AgentReport");
	MapDocumentNames.Insert("Agent report",	"AgentReport");
	MapDocumentNames.Insert("Agent reports",	"AgentReport");
	
	MapDocumentNames.Insert("ProcessingReport",	"ProcessingReport");
	MapDocumentNames.Insert("Processing report",	"ProcessingReport");
	MapDocumentNames.Insert("Processing reports",	"ProcessingReport");
	
	MapDocumentNames.Insert("CashReceipt",	"CashReceipt");
	MapDocumentNames.Insert("Petty cash receipt",	"CashReceipt");
	MapDocumentNames.Insert("Cash receipt",	"CashReceipt");
	MapDocumentNames.Insert("OCR",	"CashReceipt");
	
	MapDocumentNames.Insert("PaymentReceipt",	"PaymentReceipt");
	MapDocumentNames.Insert("Payment receipt",	"PaymentReceipt");
	MapDocumentNames.Insert("Payment receipt",	"PaymentReceipt");
	
	MapDocumentNames.Insert("FixedAssetsTransfer",			"FixedAssetsTransfer");
	MapDocumentNames.Insert("Fixed assets sale",	"FixedAssetsTransfer");
	MapDocumentNames.Insert("Fixed assets sales",	"FixedAssetsTransfer");
	
	MapDocumentNames.Insert("CustomerInvoice",	"CustomerInvoice");
	MapDocumentNames.Insert("PH",					"CustomerInvoice");
	MapDocumentNames.Insert("Customer invoice",	"CustomerInvoice");
	MapDocumentNames.Insert("Customer invoices",	"CustomerInvoice");
	
	MapDocumentNames.Insert("ExpenseReport", "ExpenseReport");
	MapDocumentNames.Insert("Expense report", "ExpenseReport");
	MapDocumentNames.Insert("Expense reports", "ExpenseReport");
	
	MapDocumentNames.Insert("AdditionalCosts", "AdditionalCosts");
	MapDocumentNames.Insert("Additional costs", "AdditionalCosts");
	
	MapDocumentNames.Insert("ReportToPrincipal", "ReportToPrincipal");
	MapDocumentNames.Insert("Principal report", "ReportToPrincipal");
	MapDocumentNames.Insert("Reports to principals", "ReportToPrincipal");
	
	MapDocumentNames.Insert("SubcontractorReport", "SubcontractorReport");
	MapDocumentNames.Insert("Subcontractor report", "SubcontractorReport");
	MapDocumentNames.Insert("Processor reports", "SubcontractorReport");
	
	MapDocumentNames.Insert("SupplierInvoice", "SupplierInvoice");
	MapDocumentNames.Insert("Supplier invoice", "SupplierInvoice");
	MapDocumentNames.Insert("Supplier invoices", "SupplierInvoice");
	MapDocumentNames.Insert("MON", "SupplierInvoice");
	
	MapDocumentNames.Insert("CashPayment", "CashPayment");
	MapDocumentNames.Insert("Cash payment", "CashPayment");
	MapDocumentNames.Insert("CPV", "CashPayment");
	
	MapDocumentNames.Insert("PaymentExpense", "PaymentExpense");
	MapDocumentNames.Insert("Payment expense", "PaymentExpense");
	
	DocumentType = MapDocumentNames.Get(DocumentTypeName);
	If DocumentType = Undefined Then
		
		Return;
		
	EndIf;
	
	TableName = "Document." + DocumentType;
	
	Query = New Query("Select AccountingDocument.Ref FROM &TableName AS AccountingDocument Where AccountingDocument.Counterparty = &Counterparty And AccountingDocument.Number LIKE &Number");
	Query.Text = StrReplace(Query.Text, "&TableName", TableName);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Number", "%" + Number_IncomingData + "%");
	
	If Not IsBlankString(Date_IncomingData) Then
		
		DateFromString = Date('00010101');
		ConvertStringToDate(DateFromString, Date_IncomingData);
		
		If ValueIsFilled(DateFromString) Then
			
			Query.Text = Query.Text + " And AccountingDocument.Date Between &StartDate And &EndDate";
			Query.SetParameter("StartDate", BegOfDay(DateFromString));
			Query.SetParameter("EndDate", EndOfDay(DateFromString));
			
		EndIf;
		
	EndIf;
	
	Query.Text = Query.Text + " SORT BY AccountsDocument.Date Desc";
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Document = Selection.Ref;
		
	EndIf;
	
EndProcedure

Procedure MapAccountByNumberDate(Account, Counterparty, Number_IncomingData, Date_IncomingData) Export
	
	If IsBlankString(Number_IncomingData) Then
		
		Return;
		
	EndIf;
	
	Query = New Query("Select Account.Ref FROM Document.InvoiceForPayment AS Account Where Account.Counterparty = &Counterparty And Account.Number LIKE &Number");
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Number", "%" + Number_IncomingData + "%");
	
	If Not IsBlankString(Date_IncomingData) Then
		
		DateFromString = Date('00010101');
		ConvertStringToDate(DateFromString, Date_IncomingData);
		
		If ValueIsFilled(DateFromString) Then
			
			Query.Text = Query.Text + " And Account.Date Between &StartDate And &EndDate";
			Query.SetParameter("StartDate", BegOfDay(DateFromString));
			Query.SetParameter("EndDate", EndOfDay(DateFromString));
			
		EndIf;
		
	EndIf;
	
	Query.Text = Query.Text + " SORT BY Account.Date Desc";
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Account = Selection.Ref;
		
	EndIf;
	
EndProcedure

#EndRegion
 

