
////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// The procedure creates an empty table template of using selection forms by documents
//
Procedure CreateUsageTablePattern(UsageTable)
	
	ValidTypes = New TypeDescription("String", , New StringQualifiers(100));
	
	UsageTable = New ValueTable;
	UsageTable.Columns.Add("DocumentName",		ValidTypes);
	UsageTable.Columns.Add("TabularSectionName",	ValidTypes);
	UsageTable.Columns.Add("PickForm", 		ValidTypes);
	
EndProcedure // CreatePatternUsageTables()

Function ChoiceFormNameByDocument(DocumentFullName, TabularSectionName) Export
	Var ChoiceFormName, UsageTable;
	
	CreateUsageTablePattern(UsageTable);
	PickProductsAndServicesInDocumentsOverridable.ChoiceFormsUsageTable(UsageTable);
	
	RowFilter = New Structure("DocumentName, TabularSectionName", DocumentFullName, TabularSectionName);
	FoundStrings = UsageTable.FindRows(RowFilter);
	
	If FoundStrings.Count() = 0 Then
		
		MessageText = NStr("en='Cannot define which selection form to use.';ru='Не удалось определить какую форму подбора использовать.'");
		WriteLogEvent("PickProductsAndServices", EventLogLevel.Information, , , MessageText, EventLogEntryTransactionMode.Independent);
		
		Return ""; // if there is an error of form definition, open an old selection form.
		
	EndIf;
	
	Return FoundStrings[0].PickForm;
	
EndFunction

Procedure AssignPickForm(SelectionOpenParameters, DocumentFullName, TabularSectionName) Export
	
	If TypeOf(SelectionOpenParameters) <> Type("Structure") Then
		
		SelectionOpenParameters = New Structure;
		
	EndIf;
	
	UserSettingValue = SmallBusinessreuse.GetValueOfSetting("UseNewSelectionMechanism");
	If UserSettingValue Then
		
		ChoiceFormName = ChoiceFormNameByDocument(DocumentFullName, TabularSectionName);
		SelectionOpenParameters.Insert(TabularSectionName, ChoiceFormName);
		
	Else
		
		SelectionOpenParameters.Insert(TabularSectionName, "");
		
	EndIf;
	
EndProcedure

// Gets price and products and services measurement unit by the specified prices kind
//
// Returns:
//  Structure:
// 	- Price (Number). Obtained price of products and services by the pricelist.
// 	- MeasurementUnit (Catalog MeasurementUnits and MeasurementUnitsClassifier). Measurement unit specified in the price.
//
Function GetPriceAndProductsAndServicesMeasurementUnitByPricesKind(DataStructure) Export
	
	If DataStructure.PriceKind.CalculatesDynamically Then
		
		DynamicPriceKind	= True;
		PriceKindParameter		= DataStructure.PriceKind.PricesBaseKind;
		Markup				= DataStructure.PriceKind.Percent;
		RoundingOrder	= DataStructure.PriceKind.RoundingOrder;
		RoundUp = DataStructure.PriceKind.RoundUp;
		
	Else
		
		DynamicPriceKind	= False;
		PriceKindParameter		= DataStructure.PriceKind;
		
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProductsAndServicesPricesSliceLast.MeasurementUnit AS MeasurementUnit,
	|	ProductsAndServicesPricesSliceLast.PriceKind.PriceCurrency AS ProductsAndServicesPricesCurrency,
	|	ProductsAndServicesPricesSliceLast.PriceKind.PriceIncludesVAT AS PriceIncludesVAT,
	|	ProductsAndServicesPricesSliceLast.PriceKind.RoundingOrder AS RoundingOrder,
	|	ProductsAndServicesPricesSliceLast.PriceKind.RoundUp AS RoundUp,
	|	ISNULL(ProductsAndServicesPricesSliceLast.Price * RateCurrencyTypePrices.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(&Factor, 1) / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price
	|FROM
	|	InformationRegister.ProductsAndServicesPrices.SliceLast(
	|			&ProcessingDate,
	|			ProductsAndServices = &ProductsAndServices
	|				AND Characteristic = &Characteristic
	|				AND PriceKind = &PriceKind) AS ProductsAndServicesPricesSliceLast
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&ProcessingDate, ) AS RateCurrencyTypePrices
	|		ON ProductsAndServicesPricesSliceLast.PriceKind.PriceCurrency = RateCurrencyTypePrices.Currency,
	|	InformationRegister.CurrencyRates.SliceLast(&ProcessingDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|WHERE
	|	ProductsAndServicesPricesSliceLast.Actuality";
	
	Query.SetParameter("ProcessingDate",	 DataStructure.ProcessingDate);
	Query.SetParameter("ProductsAndServices",	 DataStructure.ProductsAndServices);
	Query.SetParameter("Characteristic",  DataStructure.Characteristic);
	Query.SetParameter("Factor",	 DataStructure.Factor);
	Query.SetParameter("DocumentCurrency", DataStructure.DocumentCurrency);
	Query.SetParameter("PriceKind",			 PriceKindParameter);
	
	Selection = Query.Execute().Select();
	
	Price			= 0;
	MeasurementUnit= Undefined;
	While Selection.Next() Do
		
		Price			= Selection.Price;
		MeasurementUnit= Selection.MeasurementUnit;
		
		// Dynamically calculate the price
		If DynamicPriceKind Then
			
			Price = Price * (1 + Markup / 100);
			
		Else
			
			RoundingOrder		= Selection.RoundingOrder;
			RoundUp= Selection.RoundUp;
			
		EndIf;
		
		If DataStructure.Property("AmountIncludesVAT")
			AND (DataStructure.AmountIncludesVAT <> Selection.PriceIncludesVAT) Then
			
			Price = SmallBusinessServer.RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, DataStructure.VATRate);
			
		EndIf;
		
		Price = SmallBusinessServer.RoundPrice(Price, RoundingOrder, RoundUp);
		
	EndDo;
	
	Return New Structure("MeasurementUnit, Price", MeasurementUnit, Price);
	
EndFunction // GetPriceAndProductsAndServicesMeasurementUnitByPricesKind()

// Gets price and products and services measurement unit by the specified prices kind
//
// Returns:
//  Structure:
// 	- Price (Number). Obtained price of products and services by the pricelist.
// 	- MeasurementUnit (Catalog MeasurementUnits and MeasurementUnitsClassifier). Measurement unit specified in the price.
//
Function GetPriceAndProductsAndServicesMeasurementUnitByCounterpartyPricesKind(DataStructure) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CounterpartyProductsAndServicesPricesSliceLast.CounterpartyPriceKind.PriceCurrency AS ProductsAndServicesPricesCurrency,
	|	CounterpartyProductsAndServicesPricesSliceLast.CounterpartyPriceKind.PriceIncludesVAT AS PriceIncludesVAT,
	|	CounterpartyProductsAndServicesPricesSliceLast.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(CounterpartyProductsAndServicesPricesSliceLast.Price * RateCurrencyTypePrices.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(&Factor, 1) / ISNULL(CounterpartyProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price
	|FROM
	|	InformationRegister.CounterpartyProductsAndServicesPrices.SliceLast(
	|			&ProcessingDate,
	|			ProductsAndServices = &ProductsAndServices
	|				AND Characteristic = &Characteristic
	|				AND CounterpartyPriceKind = &CounterpartyPriceKind) AS CounterpartyProductsAndServicesPricesSliceLast
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&ProcessingDate, ) AS RateCurrencyTypePrices
	|		ON CounterpartyProductsAndServicesPricesSliceLast.CounterpartyPriceKind.PriceCurrency = RateCurrencyTypePrices.Currency,
	|	InformationRegister.CurrencyRates.SliceLast(&ProcessingDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|WHERE
	|	CounterpartyProductsAndServicesPricesSliceLast.Actuality";
	
	Query.SetParameter("ProcessingDate",		DataStructure.ProcessingDate);
	Query.SetParameter("ProductsAndServices",		DataStructure.ProductsAndServices);
	Query.SetParameter("Characteristic",		DataStructure.Characteristic);
	Query.SetParameter("Factor",		DataStructure.Factor);
	Query.SetParameter("DocumentCurrency",	DataStructure.DocumentCurrency);
	Query.SetParameter("CounterpartyPriceKind",	DataStructure.CounterpartyPriceKind);
	
	Selection = Query.Execute().Select();
	
	Price			= 0;
	MeasurementUnit= Undefined;
	While Selection.Next() Do
		
		Price			= Selection.Price;
		MeasurementUnit= Selection.MeasurementUnit;
		
		If DataStructure.AmountIncludesVAT <> Selection.PriceIncludesVAT Then
			
			Price = SmallBusinessServer.RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, DataStructure.VATRate);
			
		EndIf;
		
	EndDo;
	
	Return New Structure("MeasurementUnit, Price", MeasurementUnit, Price);
	
EndFunction // GetPriceAndProductsAndServicesMeasurementUnitByCounterpartyPricesKind()

// Transform types

// Converts a data set with the ValuesList type into Array
// 
Function ValueListIntoArray(IncValueList) Export
	
	ArrayOfData = New Array;
	
	For Each ValueListItem IN IncValueList Do
		
		ArrayOfData.Add(ValueListItem.Value);
		
	EndDo;
	
	Return ArrayOfData;
	
EndFunction // ValuesListIntoArray()

// The function defines if the received variable has the ValuesList type
//
Function IsValuesList(IncomingValue) Export
	
	Return (TypeOf(IncomingValue) = Type("ValueList"));
	
EndFunction // IsValuesList()

// Transform types End

// The procedure initially fills user settings
//
Procedure InitialSelectionSettingsFilling(User = Undefined, StandardProcessing = True) Export
	
	PickProductsAndServicesInDocumentsOverridable.OverrideInitialSelectionSettingsFilling(User, StandardProcessing);
	
	If StandardProcessing = True Then
		
		SmallBusinessServer.SetUserSetting(True, "UseNewSelectionMechanism", User);
		
	EndIf;
	
EndProcedure // FillUserSettings()

// The procedure sets selection parameters by the transferred structure/array with products and services types.
//
Procedure SetChoiceParameters(Item, Val ProductsAndServicesType) Export
	
	If IsValuesList(ProductsAndServicesType) Then
		
		ProductsAndServicesType = ValueListIntoArray(ProductsAndServicesType);
		
	EndIf;
	
	If TypeOf(Item) <> Type("FormField")
		OR TypeOf(ProductsAndServicesType) <> Type("Array")
		OR ProductsAndServicesType.Count() < 1 Then
		
		Return;
		
	EndIf;
	
	NewParameter = New ChoiceParameter("Filter.ProductsAndServicesType", New FixedArray(ProductsAndServicesType));
	
	SelectionParametersArray = New Array;
	SelectionParametersArray.Add(NewParameter);
	Item.ChoiceParameters = New FixedArray(SelectionParametersArray);
	
EndProcedure // SetChoiceParameterLinks()
