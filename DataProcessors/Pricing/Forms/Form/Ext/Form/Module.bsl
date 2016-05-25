
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - SERVER TABLE FILLING MECHANISMS

&AtServer
Procedure FillProductsAndServicesPricesFirstTime(Period, ParameterPriceKind, ParameterPriceGroup, ParameterProductsAndServices)
	
	If ValueIsFilled(ParameterPriceKind) Then
	
		Query = New Query();
		Query.Text = 
		"SELECT
		|	ProductsAndServicesPricesSliceLast.ProductsAndServices,
		|	ProductsAndServicesPricesSliceLast.Characteristic,
		|	ProductsAndServicesPricesSliceLast.Price AS OriginalPrice,
		|	ProductsAndServicesPricesSliceLast.Price,
		|	ProductsAndServicesPricesSliceLast.MeasurementUnit,
		|	TRUE AS Check
		|FROM
		|	InformationRegister.ProductsAndServicesPrices.SliceLast(
		|			&Period,
		|			PriceKind = &PriceKind
		|				AND CASE
		|					WHEN &ProductsAndServices = UNDEFINED
		|							OR ProductsAndServices = &ProductsAndServices
		|						THEN TRUE
		|					ELSE FALSE
		|				END
		|				AND CASE
		|					WHEN &PriceGroup = UNDEFINED
		|							OR ProductsAndServices.PriceGroup = &PriceGroup
		|						THEN TRUE
		|					ELSE FALSE
		|				END AND Actuality) AS ProductsAndServicesPricesSliceLast
		|
		|ORDER BY
		|	ProductsAndServicesPricesSliceLast.ProductsAndServices.Description";
			
		Query.SetParameter("Period", Period);
		Query.SetParameter("PriceKind", ParameterPriceKind);
		Query.SetParameter("ProductsAndServices", ParameterProductsAndServices);
		Query.SetParameter("PriceGroup", ParameterPriceGroup);
		ProductsAndServicesPrices.Load(Query.Execute().Unload());	
	
	Else
	
		If ValueIsFilled(ParameterProductsAndServices) OR ValueIsFilled(ParameterPriceGroup) Then
		
			Query = New Query();
			Query.Text = 
			"SELECT
			|	CatalogProductsAndServices.Ref AS ProductsAndServices,
			|	TRUE AS Check,
			|	CatalogProductsAndServices.MeasurementUnit
			|FROM
			|	Catalog.ProductsAndServices AS CatalogProductsAndServices
			|WHERE
			|	CASE
			|			WHEN &PriceGroup = UNDEFINED
			|					OR CatalogProductsAndServices.PriceGroup = &PriceGroup
			|				THEN TRUE
			|			ELSE FALSE
			|		END
			|	AND CASE
			|			WHEN &ProductsAndServices = UNDEFINED
			|					OR CatalogProductsAndServices.Ref = &ProductsAndServices
			|				THEN TRUE
			|			ELSE FALSE
			|		END
			|
			|ORDER BY
			|	CatalogProductsAndServices.Description";
				
			Query.SetParameter("ProductsAndServices", ParameterProductsAndServices);
			Query.SetParameter("PriceGroup", ParameterPriceGroup);
			ProductsAndServicesPrices.Load(Query.Execute().Unload());		
		
		EndIf; 	
	
	EndIf;		
	
EndProcedure

&AtServer
Function GetProductsAndServicesTable(Briefly = False)
	
	ProductsAndServicesTable = New ValueTable;
	
	Array = New Array;
	
	Array.Add(Type("CatalogRef.ProductsAndServices"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	ProductsAndServicesTable.Columns.Add("ProductsAndServices", TypeDescription);
	
	Array.Add(Type("CatalogRef.ProductsAndServicesCharacteristics"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	ProductsAndServicesTable.Columns.Add("Characteristic", TypeDescription);
	
	If Not Briefly Then
	
		Array.Add(Type("Boolean"));
		TypeDescription = New TypeDescription(Array, ,);
		Array.Clear();

		ProductsAndServicesTable.Columns.Add("Check", TypeDescription);
		
		Array.Add(Type("CatalogRef.UOM"));
		Array.Add(Type("CatalogRef.UOMClassifier"));
		TypeDescription = New TypeDescription(Array, ,);
		Array.Clear();

		ProductsAndServicesTable.Columns.Add("MeasurementUnit", TypeDescription);
		
		NQ = New NumberQualifiers(15,2);
		Array.Add(Type("Number"));
		TypeDescription = New TypeDescription(Array, , , NQ);

		ProductsAndServicesTable.Columns.Add("Price", TypeDescription);
		
		Array.Add(Type("Number"));
		TypeDescription = New TypeDescription(Array, , );

		ProductsAndServicesTable.Columns.Add("Factor", TypeDescription);	
	
	EndIf; 
	
	For Each TSRow IN ProductsAndServicesPrices Do
		
		If Not ValueIsFilled(TSRow.ProductsAndServices) Then
			
			Continue;
			
		EndIf; 
		
		NewRow = ProductsAndServicesTable.Add();
		FillPropertyValues(NewRow, TSRow);
		
		If Not Briefly Then
			
			If TypeOf(TSRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
				NewRow.Factor = 1;
			Else
				NewRow.Factor = TSRow.MeasurementUnit.Factor;
			EndIf;
			
		EndIf; 
		
	EndDo;
	
	Return ProductsAndServicesTable;

EndFunction // GetProductsAndServicesTable()

&AtServer
Procedure AddProductsAndServices(ProductsAndServicesTable)
	
	For Each TableRow IN ProductsAndServicesTable Do
		
		NewRow = ProductsAndServicesPrices.Add();
		FillPropertyValues(NewRow, TableRow);
		NewRow.OriginalPrice = TableRow.Price;
		
	EndDo;
	
EndProcedure // AddProductsAndServices()

&AtServer
Procedure AddByPriceKindsAtServer(ValueSelected, ToDate, PriceFilled, UseCharacteristics = False)
	
	DynamicPriceKind	= ValueSelected.CalculatesDynamically;
	ParameterPriceKind		= ?(DynamicPriceKind, ValueSelected.PricesBaseKind, ValueSelected);
	
	Query = New Query();
	
	Query.Text = DataProcessors.Pricing.QueryTextForAddingByPriceKind(PriceFilled, UseCharacteristics);
	
	CurrencySource = ?(ValueIsFilled(ParameterPriceKind.PriceCurrency), ValueSelected.PriceCurrency, NationalCurrency);
	CurrencyOfReceiver = ?(ValueIsFilled(PriceKindInstallation.PriceCurrency), PriceKindInstallation.PriceCurrency, NationalCurrency);
	
	Query.SetParameter("ToDate", ToDate);
	Query.SetParameter("PriceKind", ParameterPriceKind);
	Query.SetParameter("CurrencySource",CurrencySource);
	Query.SetParameter("CurrencyOfReceiver",CurrencyOfReceiver);
	Query.SetParameter("ProductsAndServicesTable", GetProductsAndServicesTable(True));
	
	ResultTable = Query.Execute().Unload();
	
	If DynamicPriceKind AND ResultTable.Count() > 0 Then
		
		Markup 					= ValueSelected.Percent;
		RoundingOrder			= ValueSelected.RoundingOrder;
		RoundUp	= ValueSelected.RoundUp;
	
		For Each TableRow IN ResultTable Do
			
			TableRow.Price = TableRow.Price * (1 + Markup / 100);
			
		EndDo; 
	
	EndIf; 
	
	AddProductsAndServices(ResultTable);
	
EndProcedure // AddByPriceKindsAtServer()

&AtServer
Procedure AddByPriceGroupsAtServer(ValueSelected, UseCharacteristics = False)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic,
	|	ProductsAndServicesTable.MeasurementUnit AS MeasurementUnit,
	|	TRUE AS IsInTable
	|INTO ProductsAndServicesTable
	|FROM
	|	&ProductsAndServicesTable AS ProductsAndServicesTable
	|
	|INDEX BY
	|	ProductsAndServicesTable.ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CatalogProductsAndServices.Ref AS ProductsAndServices,
	|	VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef) AS Characteristic,
	|	CatalogProductsAndServices.MeasurementUnit AS MeasurementUnit,
	|	FALSE AS IsInTable
	|INTO NewProductsAndServices
	|FROM
	|	Catalog.ProductsAndServices AS CatalogProductsAndServices
	|WHERE
	|	CatalogProductsAndServices.PriceGroup IN(&PriceGroups)
	|
	|INDEX BY
	|	CatalogProductsAndServices.Ref,
	|	VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServicesCharacteristics.Owner AS ProductsAndServices,
	|	ProductsAndServicesCharacteristics.Ref AS Characteristic,
	|	ProductsAndServicesCharacteristics.Owner.MeasurementUnit AS MeasurementUnit,
	|	FALSE AS IsInTable
	|INTO NewCharacteristics
	|FROM
	|	Catalog.ProductsAndServicesCharacteristics AS ProductsAndServicesCharacteristics
	|WHERE
	|	ProductsAndServicesCharacteristics.Owner.PriceGroup IN(&PriceGroups)
	|	AND &UseCharacteristics
	|
	|INDEX BY
	|	ProductsAndServicesCharacteristics.Owner,
	|	ProductsAndServicesCharacteristics.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServicesTable.ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic,
	|	ProductsAndServicesTable.MeasurementUnit,
	|	ProductsAndServicesTable.IsInTable
	|INTO TemporaryTableOfAllProductsAndServices
	|FROM
	|	ProductsAndServicesTable AS ProductsAndServicesTable
	|
	|UNION ALL
	|
	|SELECT
	|	NewProductsAndServices.ProductsAndServices,
	|	NewProductsAndServices.Characteristic,
	|	NewProductsAndServices.MeasurementUnit,
	|	NewProductsAndServices.IsInTable
	|FROM
	|	NewProductsAndServices AS NewProductsAndServices
	|
	|UNION ALL
	|
	|SELECT
	|	NewCharacteristics.ProductsAndServices,
	|	NewCharacteristics.Characteristic,
	|	NewCharacteristics.MeasurementUnit,
	|	NewCharacteristics.IsInTable
	|FROM
	|	NewCharacteristics AS NewCharacteristics
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TRUE AS Check,
	|	ProductsAndServicesTableWithPrices.ProductsAndServices,
	|	ProductsAndServicesTableWithPrices.Characteristic,
	|	ProductsAndServicesTableWithPrices.MeasurementUnit,
	|	ProductsAndServicesPrices.Price AS Price,
	|	MAX(ProductsAndServicesTableWithPrices.IsInTable) AS IsInTable
	|FROM
	|	TemporaryTableOfAllProductsAndServices AS ProductsAndServicesTableWithPrices
	|		LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(
	|				&Period,
	|				Actuality
	|					AND PriceKind = &PriceKind) AS ProductsAndServicesPrices
	|		ON ProductsAndServicesTableWithPrices.ProductsAndServices = ProductsAndServicesPrices.ProductsAndServices
	|			AND ProductsAndServicesTableWithPrices.Characteristic = ProductsAndServicesPrices.Characteristic
	|
	|GROUP BY
	|	ProductsAndServicesTableWithPrices.ProductsAndServices,
	|	ProductsAndServicesTableWithPrices.Characteristic,
	|	ProductsAndServicesTableWithPrices.MeasurementUnit,
	|	ProductsAndServicesPrices.Price
	|
	|HAVING
	|	MAX(ProductsAndServicesTableWithPrices.IsInTable) = FALSE
	|
	|ORDER BY
	|	ProductsAndServicesTableWithPrices.ProductsAndServices.Description,
	|	ProductsAndServicesTableWithPrices.Characteristic.Description";
	
	Query.SetParameter("Period",					InstallationPeriod);
	Query.SetParameter("PriceKind",					PriceKindInstallation);
	Query.SetParameter("PriceGroups",			ValueSelected);
	Query.SetParameter("ProductsAndServicesTable",	GetProductsAndServicesTable(False));
	Query.SetParameter("UseCharacteristics", UseCharacteristics);
	
	AddProductsAndServices(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure AddByProductsAndServicesCategoriesAtServer(ValueSelected, UseCharacteristics = False)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic,
	|	ProductsAndServicesTable.MeasurementUnit AS MeasurementUnit,
	|	TRUE AS IsInTable
	|INTO ProductsAndServicesTable
	|FROM
	|	&ProductsAndServicesTable AS ProductsAndServicesTable
	|
	|INDEX BY
	|	ProductsAndServicesTable.ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CatalogProductsAndServices.Ref AS ProductsAndServices,
	|	VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef) AS Characteristic,
	|	CatalogProductsAndServices.MeasurementUnit AS MeasurementUnit,
	|	FALSE AS IsInTable
	|INTO NewProductsAndServices
	|FROM
	|	Catalog.ProductsAndServices AS CatalogProductsAndServices
	|WHERE
	|	CatalogProductsAndServices.Ref IN HIERARCHY(&ProductsAndServicesGroup)
	|	AND Not CatalogProductsAndServices.IsFolder
	|
	|INDEX BY
	|	CatalogProductsAndServices.Ref,
	|	VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServicesCharacteristics.Owner AS ProductsAndServices,
	|	ProductsAndServicesCharacteristics.Ref AS Characteristic,
	|	ProductsAndServicesCharacteristics.Owner.MeasurementUnit AS MeasurementUnit,
	|	FALSE AS IsInTable
	|INTO NewCharacteristics
	|FROM
	|	Catalog.ProductsAndServicesCharacteristics AS ProductsAndServicesCharacteristics
	|WHERE
	|	ProductsAndServicesCharacteristics.Owner IN HIERARCHY(&ProductsAndServicesGroup)
	|	AND &UseCharacteristics
	|
	|INDEX BY
	|	ProductsAndServicesCharacteristics.Owner,
	|	ProductsAndServicesCharacteristics.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServicesTable.ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic,
	|	ProductsAndServicesTable.MeasurementUnit,
	|	ProductsAndServicesTable.IsInTable
	|INTO TemporaryTableOfAllProductsAndServices
	|FROM
	|	ProductsAndServicesTable AS ProductsAndServicesTable
	|
	|UNION ALL
	|
	|SELECT
	|	NewProductsAndServices.ProductsAndServices,
	|	NewProductsAndServices.Characteristic,
	|	NewProductsAndServices.MeasurementUnit,
	|	NewProductsAndServices.IsInTable
	|FROM
	|	NewProductsAndServices AS NewProductsAndServices
	|
	|UNION ALL
	|
	|SELECT
	|	NewCharacteristics.ProductsAndServices,
	|	NewCharacteristics.Characteristic,
	|	NewCharacteristics.MeasurementUnit,
	|	NewCharacteristics.IsInTable
	|FROM
	|	NewCharacteristics AS NewCharacteristics
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TRUE AS Check,
	|	ProductsAndServicesTableWithPrices.ProductsAndServices,
	|	ProductsAndServicesTableWithPrices.Characteristic,
	|	ProductsAndServicesTableWithPrices.MeasurementUnit,
	|	ProductsAndServicesPrices.Price AS Price,
	|	MAX(ProductsAndServicesTableWithPrices.IsInTable) AS IsInTable
	|FROM
	|	TemporaryTableOfAllProductsAndServices AS ProductsAndServicesTableWithPrices
	|		LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(
	|				&Period,
	|				Actuality
	|					AND PriceKind = &PriceKind) AS ProductsAndServicesPrices
	|		ON ProductsAndServicesTableWithPrices.ProductsAndServices = ProductsAndServicesPrices.ProductsAndServices
	|			AND ProductsAndServicesTableWithPrices.Characteristic = ProductsAndServicesPrices.Characteristic
	|
	|GROUP BY
	|	ProductsAndServicesTableWithPrices.ProductsAndServices,
	|	ProductsAndServicesTableWithPrices.Characteristic,
	|	ProductsAndServicesTableWithPrices.MeasurementUnit,
	|	ProductsAndServicesPrices.Price
	|
	|HAVING
	|	MAX(ProductsAndServicesTableWithPrices.IsInTable) = FALSE
	|
	|ORDER BY
	|	ProductsAndServicesTableWithPrices.ProductsAndServices.Description,
	|	ProductsAndServicesTableWithPrices.Characteristic.Description";
	
	Query.SetParameter("Period",					InstallationPeriod);
	Query.SetParameter("PriceKind",					PriceKindInstallation);
	Query.SetParameter("ProductsAndServicesGroup",		ValueSelected);
	Query.SetParameter("ProductsAndServicesTable",	GetProductsAndServicesTable(False));
	Query.SetParameter("UseCharacteristics", UseCharacteristics);
	
	AddProductsAndServices(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure AddByReceiptInvoiceAtServer(ValueSelected)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic
	|INTO ProductsAndServicesTable
	|FROM
	|	&ProductsAndServicesTable AS ProductsAndServicesTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(CurrencyRates.Period) AS Period,
	|	CurrencyRates.ExchangeRate AS ExchangeRate,
	|	CurrencyRates.Multiplicity AS Multiplicity
	|INTO PriceKindCurrencyRate
	|FROM
	|	InformationRegister.CurrencyRates.SliceLast(&Period, Currency = &CurrencyPriceKind) AS CurrencyRates
	|
	|GROUP BY
	|	CurrencyRates.ExchangeRate,
	|	CurrencyRates.Multiplicity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TRUE AS Check,
	|	SupplierInvoiceInventory.ProductsAndServices AS ProductsAndServices,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.MeasurementUnit,
	|	CASE
	|		WHEN &CurrencyPriceKind <> SupplierInvoiceInventory.Ref.DocumentCurrency
	|			THEN SupplierInvoiceInventory.Price * SupplierInvoiceInventory.Ref.ExchangeRate * PriceKindCurrencyRate.Multiplicity / PriceKindCurrencyRate.ExchangeRate * SupplierInvoiceInventory.Ref.Multiplicity
	|		ELSE SupplierInvoiceInventory.Price
	|	END AS Price
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory,
	|	PriceKindCurrencyRate AS PriceKindCurrencyRate
	|WHERE
	|	SupplierInvoiceInventory.Ref = &SupplierInvoice
	|	AND Not (SupplierInvoiceInventory.ProductsAndServices, SupplierInvoiceInventory.Characteristic) In
	|				(SELECT
	|					Table.ProductsAndServices,
	|					Table.Characteristic
	|				FROM
	|					ProductsAndServicesTable AS Table)
	|
	|ORDER BY
	|	SupplierInvoiceInventory.LineNumber";
	
	CurrencyPriceKind = ?(ValueIsFilled(PriceKindInstallation.PriceCurrency), PriceKindInstallation.PriceCurrency, NationalCurrency);
	
	Query.SetParameter("CurrencyPriceKind", CurrencyPriceKind);
	Query.SetParameter("Period", ValueSelected.Date);
	Query.SetParameter("SupplierInvoice", ValueSelected);
	Query.SetParameter("ProductsAndServicesTable", GetProductsAndServicesTable(True));
	
	AddProductsAndServices(Query.Execute().Unload());
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - PRICES FILLING MECHANISMS

&AtServer
Procedure PlacePrices(PricesTable)

	For Each TabularSectionRow IN ProductsAndServicesPrices Do
		
		If Not TabularSectionRow.Check Then
			Continue;		
		EndIf; 
		
		SearchStructure = New Structure;
		SearchStructure.Insert("ProductsAndServices",	 TabularSectionRow.ProductsAndServices);
		SearchStructure.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
		SearchResult = PricesTable.FindRows(SearchStructure);
		If SearchResult.Count() > 0 Then			
			TabularSectionRow.Price = SearchResult[0].Price;
		EndIf;
		
	EndDo;	

EndProcedure // PlacePrices()

&AtServer
Procedure FillPricesByPriceKindAtServer()
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic,
	|	ProductsAndServicesTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsAndServicesTable.Factor AS Factor,
	|	ProductsAndServicesTable.Check AS Check
	|INTO ProductsAndServicesTable
	|FROM
	|	&ProductsAndServicesTable AS ProductsAndServicesTable
	|WHERE
	|	ProductsAndServicesTable.Check
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic,
	|	CASE
	|		WHEN ProductsAndServicesPricesSliceLast.Actuality
	|			THEN ISNULL(ProductsAndServicesPricesSliceLast.Price * RateCurrencyTypePrices.ExchangeRate * CurrencyRateOfPriceKindInstallation.Multiplicity / (CurrencyRateOfPriceKindInstallation.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(ProductsAndServicesTable.Factor, 1) / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1), 0)
	|		ELSE 0
	|	END AS Price,
	|	ProductsAndServicesTable.MeasurementUnit
	|FROM
	|	ProductsAndServicesTable AS ProductsAndServicesTable
	|		LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(
	|				&ToDate,
	|				PriceKind = &PriceKind
	|					AND (ProductsAndServices, Characteristic) In
	|						(SELECT
	|							Table.ProductsAndServices,
	|							Table.Characteristic
	|						FROM
	|							ProductsAndServicesTable AS Table)) AS ProductsAndServicesPricesSliceLast
	|		ON ProductsAndServicesTable.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices
	|			AND ProductsAndServicesTable.Characteristic = ProductsAndServicesPricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&ToDate, ) AS RateCurrencyTypePrices
	|		ON (ProductsAndServicesPricesSliceLast.PriceKind.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.CurrencyRates.SliceLast(&ToDate, Currency = &Currency) AS CurrencyRateOfPriceKindInstallation";
		
	Query.SetParameter("ToDate", Period);
	Query.SetParameter("PriceKind", PriceKind);
	Query.SetParameter("Currency", PriceKindInstallation.PriceCurrency);
	Query.SetParameter("ProductsAndServicesTable", GetProductsAndServicesTable());
	PlacePrices(Query.Execute().Unload());	
	
EndProcedure

&AtServer
Procedure FillPricesByCounterpartyPriceKindAtServer()
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic,
	|	ProductsAndServicesTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsAndServicesTable.Factor AS Factor,
	|	ProductsAndServicesTable.Check AS Check
	|INTO ProductsAndServicesTable
	|FROM
	|	&ProductsAndServicesTable AS ProductsAndServicesTable
	|WHERE
	|	ProductsAndServicesTable.Check
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic,
	|	CASE
	|		WHEN CounterpartyProductsAndServicesPricesSliceLast.Actuality
	|			THEN ISNULL(CounterpartyProductsAndServicesPricesSliceLast.Price * RateCurrencyTypePrices.ExchangeRate * CurrencyRateOfPriceKindInstallation.Multiplicity / (CurrencyRateOfPriceKindInstallation.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(ProductsAndServicesTable.Factor, 1) / ISNULL(CounterpartyProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1), 0)
	|		ELSE 0
	|	END AS Price,
	|	ProductsAndServicesTable.MeasurementUnit
	|FROM
	|	ProductsAndServicesTable AS ProductsAndServicesTable
	|		LEFT JOIN InformationRegister.CounterpartyProductsAndServicesPrices.SliceLast(
	|				&ToDate,
	|				CounterpartyPriceKind = &CounterpartyPriceKind
	|					AND (ProductsAndServices, Characteristic) In
	|						(SELECT
	|							Table.ProductsAndServices,
	|							Table.Characteristic
	|						FROM
	|							ProductsAndServicesTable AS Table)) AS CounterpartyProductsAndServicesPricesSliceLast
	|		ON ProductsAndServicesTable.ProductsAndServices = CounterpartyProductsAndServicesPricesSliceLast.ProductsAndServices
	|			AND ProductsAndServicesTable.Characteristic = CounterpartyProductsAndServicesPricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&ToDate, ) AS RateCurrencyTypePrices
	|		ON (CounterpartyProductsAndServicesPricesSliceLast.CounterpartyPriceKind.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.CurrencyRates.SliceLast(&ToDate, Currency = &Currency) AS CurrencyRateOfPriceKindInstallation";
		
	Query.SetParameter("ToDate", Period);
	Query.SetParameter("CounterpartyPriceKind", CounterpartyPriceKind);
	Query.SetParameter("Currency", PriceKindInstallation.PriceCurrency);
	Query.SetParameter("ProductsAndServicesTable", GetProductsAndServicesTable());
	PlacePrices(Query.Execute().Unload());	
	
EndProcedure

&AtServer
Procedure FillPricesByReceiptInvoiceAtServer()
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic,
	|	ProductsAndServicesTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsAndServicesTable.Factor AS Factor,
	|	ProductsAndServicesTable.Check AS Check
	|INTO ProductsAndServicesTable
	|FROM
	|	&ProductsAndServicesTable AS ProductsAndServicesTable
	|WHERE
	|	ProductsAndServicesTable.Check
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic,
	|	ISNULL(SupplierInvoiceInventory.Price * RateCurrencyTypePrices.ExchangeRate * CurrencyRateOfPriceKindInstallation.Multiplicity / (CurrencyRateOfPriceKindInstallation.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(ProductsAndServicesTable.Factor, 1) / ISNULL(SupplierInvoiceInventory.MeasurementUnit.Factor, 1), 0) AS Price,
	|	ProductsAndServicesTable.MeasurementUnit
	|FROM
	|	ProductsAndServicesTable AS ProductsAndServicesTable
	|		LEFT JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON ProductsAndServicesTable.ProductsAndServices = SupplierInvoiceInventory.ProductsAndServices
	|			AND ProductsAndServicesTable.Characteristic = SupplierInvoiceInventory.Characteristic
	|			AND (SupplierInvoiceInventory.Ref = &SupplierInvoice)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&ToDate, ) AS RateCurrencyTypePrices
	|		ON (SupplierInvoiceInventory.Ref.DocumentCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.CurrencyRates.SliceLast(&ToDate, Currency = &Currency) AS CurrencyRateOfPriceKindInstallation";
		
	Query.SetParameter("ToDate", Period);
	Query.SetParameter("SupplierInvoice", SupplierInvoice);
	Query.SetParameter("Currency", PriceKindInstallation.PriceCurrency);
	Query.SetParameter("ProductsAndServicesTable", GetProductsAndServicesTable());
	PlacePrices(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure CalculateByBasicPriceKindAtServer()
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic,
	|	ProductsAndServicesTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsAndServicesTable.Factor AS Factor,
	|	ProductsAndServicesTable.Check AS Check
	|INTO ProductsAndServicesTable
	|FROM
	|	&ProductsAndServicesTable AS ProductsAndServicesTable
	|WHERE
	|	ProductsAndServicesTable.Check
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic,
	|	CASE
	|		WHEN ProductsAndServicesPricesSliceLast.Actuality
	|			THEN ISNULL(ProductsAndServicesPricesSliceLast.Price * (1 + &Markup / 100) * RateCurrencyTypePrices.ExchangeRate * CurrencyRateOfPriceKindInstallation.Multiplicity / (CurrencyRateOfPriceKindInstallation.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(ProductsAndServicesTable.Factor, 1) / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1), 0)
	|		ELSE 0
	|	END AS Price,
	|	ProductsAndServicesTable.MeasurementUnit
	|FROM
	|	ProductsAndServicesTable AS ProductsAndServicesTable
	|		LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(
	|				&ToDate,
	|				PriceKind = &PriceKind
	|					AND (ProductsAndServices, Characteristic) In
	|						(SELECT
	|							Table.ProductsAndServices,
	|							Table.Characteristic
	|						FROM
	|							ProductsAndServicesTable AS Table)) AS ProductsAndServicesPricesSliceLast
	|		ON ProductsAndServicesTable.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices
	|			AND ProductsAndServicesTable.Characteristic = ProductsAndServicesPricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&ToDate, ) AS RateCurrencyTypePrices
	|		ON (ProductsAndServicesPricesSliceLast.PriceKind.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.CurrencyRates.SliceLast(&ToDate, Currency = &Currency) AS CurrencyRateOfPriceKindInstallation";
		
	Query.SetParameter("ToDate", Period);
	Query.SetParameter("PriceKind", PricesBaseKind);
	Query.SetParameter("Currency", PriceKindInstallation.PriceCurrency);
	Query.SetParameter("Markup", Markup);
	Query.SetParameter("ProductsAndServicesTable", GetProductsAndServicesTable());
	PlacePrices(Query.Execute().Unload());	
	
EndProcedure

&AtClient
Procedure ChangeForPercentAtClient()
	
	For Each TSRow IN ProductsAndServicesPrices Do
		
		If TSRow.Check Then
			
			If PlusMinus = "+" Then
				Price = TSRow.Price * (1 + Percent / 100);
			Else
				Price = TSRow.Price * (1 - Percent / 100);
			EndIf;
			
			TSRow.Price = Price;
			
		EndIf;
	
	EndDo;
	
EndProcedure

&AtClient
Procedure ChangeForAmountAtClient()
	
	For Each TSRow IN ProductsAndServicesPrices Do
		
		If TSRow.Check Then
			
			If PlusMinus = "+" Then
				Price = TSRow.Price + Amount;
			Else
				Price = TSRow.Price - Amount;
			EndIf;
			
			TSRow.Price = Price;
			
		EndIf;
	
	EndDo;
	
EndProcedure

&AtClient
Procedure RoundAtClient()
	
	For Each TSRow IN ProductsAndServicesPrices Do
		
		TSRow.Price = RoundPrice(TSRow.Price, RoundingOrder, RoundUp, RoundingOrder0_01);
			
	EndDo;	
	
EndProcedure

&AtServer
Procedure RemoveActualityAtServer()
	
	SetupAtServer(True);
	
EndProcedure

&AtServer
Procedure DeletePriceListRecordsAtServer()
	
	Query = New Query();
	Query.Text = "SELECT
	               |	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	               |	ProductsAndServicesTable.Characteristic AS Characteristic,
	               |	ProductsAndServicesTable.Check AS Check
	               |INTO ProductsAndServicesTable
	               |FROM
	               |	&ProductsAndServicesTable AS ProductsAndServicesTable
	               |WHERE
	               |	ProductsAndServicesTable.Check
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	ProductsAndServicesPricesSliceLast.ProductsAndServices AS ProductsAndServices,
	               |	ProductsAndServicesPricesSliceLast.Characteristic AS Characteristic,
	               |	ProductsAndServicesPricesSliceLast.Period
	               |FROM
	               |	InformationRegister.ProductsAndServicesPrices.SliceLast(
	               |			&ToDate,
	               |			PriceKind = &PriceKind
	               |				AND (ProductsAndServices, Characteristic) In
	               |					(SELECT
	               |						Table.ProductsAndServices,
	               |						Table.Characteristic
	               |					FROM
	               |						ProductsAndServicesTable AS Table)) AS ProductsAndServicesPricesSliceLast";
		
	Query.SetParameter("PriceKind", PriceKindInstallation);
	Query.SetParameter("ToDate", InstallationPeriod);
	Query.SetParameter("ProductsAndServicesTable", GetProductsAndServicesTable());
	
	Selection = Query.Execute().Select();
    	
	While Selection.Next() Do
	
		RecordSet = InformationRegisters.ProductsAndServicesPrices.CreateRecordSet();
		RecordSet.Filter.Period.Set(Selection.Period);
		RecordSet.Filter.PriceKind.Set(PriceKindInstallation);
		RecordSet.Filter.ProductsAndServices.Set(Selection.ProductsAndServices);
		RecordSet.Filter.Characteristic.Set(Selection.Characteristic);
		
		RecordSet.Write();
		
		FilterStructure = New Structure;
		FilterStructure.Insert("ProductsAndServices", Selection.ProductsAndServices);
		FilterStructure.Insert("Characteristic", Selection.Characteristic);
		FilterStructure.Insert("Check", True);
		RowArray = ProductsAndServicesPrices.FindRows(FilterStructure);
		
		For Each FoundString IN RowArray Do			
			FoundString.Picture = 1;
		EndDo;
			
	EndDo;	
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - PRICES SETTINGS

&AtServer
Procedure SetupAtServer(RemoveActuality = False)
	
	Query = New Query();
	
	Query.Text = 
	"SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic,
	|	ProductsAndServicesTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsAndServicesTable.Price AS Price,
	|	ProductsAndServicesTable.Check AS Check
	|INTO ProductsAndServicesTable
	|FROM
	|	&ProductsAndServicesTable AS ProductsAndServicesTable
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic,
	|	ProductsAndServicesTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsAndServicesTable.Price AS Price,
	|	CASE
	|		WHEN ProductsAndServicesPrices.PriceKind IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS double,
	|	MAX(ProductAndServicesPricesPeriods.Period) AS ProductsAndServicesPricePeriod
	|FROM
	|	ProductsAndServicesTable AS ProductsAndServicesTable
	|		LEFT JOIN InformationRegister.ProductsAndServicesPrices AS ProductsAndServicesPrices
	|		ON ProductsAndServicesTable.ProductsAndServices = ProductsAndServicesPrices.ProductsAndServices
	|			AND ProductsAndServicesTable.Characteristic = ProductsAndServicesPrices.Characteristic
	|			AND (ProductsAndServicesPrices.PriceKind = &PriceKind)
	|			AND (ProductsAndServicesPrices.Period = &ToDate)
	|		LEFT JOIN InformationRegister.ProductsAndServicesPrices AS ProductAndServicesPricesPeriods
	|		ON ProductsAndServicesTable.ProductsAndServices = ProductAndServicesPricesPeriods.ProductsAndServices
	|			AND ProductsAndServicesTable.Characteristic = ProductAndServicesPricesPeriods.Characteristic
	|			AND (ProductAndServicesPricesPeriods.PriceKind = &PriceKind)
	|			AND (ProductAndServicesPricesPeriods.Period < &ToDate)
	|WHERE
	|	ProductsAndServicesTable.Check
	|	
	|GROUP BY
	|	ProductsAndServicesTable.ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic,
	|	ProductsAndServicesTable.MeasurementUnit,
	|	ProductsAndServicesTable.Price,
	|	CASE
	|		WHEN ProductsAndServicesPrices.PriceKind IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.ProductsAndServices,
	|	NestedSelect.Characteristic,
	|	NestedSelect.Counter
	|FROM
	|	(SELECT
	|		ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|		ProductsAndServicesTable.Characteristic AS Characteristic,
	|		SUM(1) AS Counter
	|	FROM
	|		ProductsAndServicesTable AS ProductsAndServicesTable
	|	WHERE
	|		ProductsAndServicesTable.Check
	|	
	|	GROUP BY
	|		ProductsAndServicesTable.Characteristic,
	|		ProductsAndServicesTable.ProductsAndServices) AS NestedSelect
	|WHERE
	|	NestedSelect.Counter > 1";
		
	Query.SetParameter("PriceKind", PriceKindInstallation);
	Query.SetParameter("ToDate", InstallationPeriod);
	Query.SetParameter("ProductsAndServicesTable", GetProductsAndServicesTable());
	
	ResultsArray = Query.ExecuteBatch();
	
	// Duplication check. If duplicates exist - cancel!
	Selection = ResultsArray[2].Select();
	Cancel = False;
	
	While Selection.Next() Do
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'The string %ProductsAndServices%%Charachteristic% is duplicated!'");
		Message.Text = StrReplace(Message.Text, "%ProductsAndServices%", Selection.ProductsAndServices);
		Message.Text = StrReplace(Message.Text, "%Characteristic%", ?(ValueIsFilled(Selection.Characteristic), 
										(" (" + Selection.Characteristic + ")"), ""));
		Message.Message();
		Cancel = True;
		
	EndDo;
	
	If Cancel Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'The price setup is canceled!'");
		Message.Message();
		Return;
	EndIf;
	
	// Price setting
	Selection = ResultsArray[1].Select();
	
	While Selection.Next() Do
		
		If Selection.double Then
			
			Message = New UserMessage();
			Message.Text = NStr("en = 'Price for the products and services %ProductsAndServices%%Characteristic% to %ToDate% has been already specified! New price is not written!'");
			Message.Text = StrReplace(Message.Text, "%ToDate%", Format(InstallationPeriod, "DF=dd.MM.yy"));
			Message.Text = StrReplace(Message.Text, "%ProductsAndServices%", Selection.ProductsAndServices);
			Message.Text = StrReplace(Message.Text, "%Characteristic%", ?(ValueIsFilled(Selection.Characteristic), 
										 (" (" + Selection.Characteristic + ")"), ""));
			Message.Message();
			
			FilterStructure = New Structure;
			FilterStructure.Insert("ProductsAndServices", Selection.ProductsAndServices);
			FilterStructure.Insert("Characteristic", Selection.Characteristic);
			FilterStructure.Insert("Check", True);
			RowArray = ProductsAndServicesPrices.FindRows(FilterStructure);
			
			For Each FoundString IN RowArray Do
				FoundString.Picture = 2;
			EndDo;
		
		ElsIf Not ValueIsFilled(Selection.Price) AND (NOT RemoveActuality) Then
			
			Message = New UserMessage();
			Message.Text = NStr("en = 'Price for products and services %ProductsAndServices%%Characteristic% is not specified!'");
			Message.Text = StrReplace(Message.Text, "%ProductsAndServices%", Selection.ProductsAndServices);
			Message.Text = StrReplace(Message.Text, "%Characteristic%", ?(ValueIsFilled(Selection.Characteristic), 
										 (" (" + Selection.Characteristic + ")"), ""));
			Message.Message();
			
			FilterStructure = New Structure;
			FilterStructure.Insert("ProductsAndServices", Selection.ProductsAndServices);
			FilterStructure.Insert("Characteristic", Selection.Characteristic);
			FilterStructure.Insert("Check", True);
			RowArray = ProductsAndServicesPrices.FindRows(FilterStructure);
			
			For Each FoundString IN RowArray Do
				FoundString.Picture = 2;
			EndDo;
			
		ElsIf RemoveActuality Then
			
			RecordManager = InformationRegisters.ProductsAndServicesPrices.CreateRecordManager();
			RecordManager.Author = Users.AuthorizedUser();
			RecordManager.Actuality = False;
			RecordManager.PriceKind = PriceKindInstallation;
			RecordManager.MeasurementUnit = Selection.MeasurementUnit;
			RecordManager.ProductsAndServices = Selection.ProductsAndServices;
			
			If ValueIsFilled(Selection.ProductsAndServicesPricePeriod) Then
				
				RecordManager.Period = Selection.ProductsAndServicesPricePeriod;
				
			Else
				
				RecordManager.Period = InstallationPeriod;
				
			EndIf;
			
			RecordManager.Characteristic = Selection.Characteristic;
			RecordManager.Price = Selection.Price;
			RecordManager.Write(True);
			
			FilterStructure = New Structure;
			FilterStructure.Insert("ProductsAndServices", Selection.ProductsAndServices);
			FilterStructure.Insert("Characteristic", Selection.Characteristic);
			FilterStructure.Insert("Check", True);
			RowArray = ProductsAndServicesPrices.FindRows(FilterStructure);
			
			For Each FoundString IN RowArray Do
				
				FoundString.Picture = 1;
				FoundString.Price = Selection.Price;
				
			EndDo; 
			
		Else
		
			RecordSet = InformationRegisters.ProductsAndServicesPrices.CreateRecordSet();
			RecordSet.Filter.Period.Set(InstallationPeriod);
			RecordSet.Filter.PriceKind.Set(PriceKindInstallation);
			RecordSet.Filter.ProductsAndServices.Set(Selection.ProductsAndServices);
			RecordSet.Filter.Characteristic.Set(Selection.Characteristic);
			
			NewRecord = RecordSet.Add();
			FillPropertyValues(NewRecord, Selection);
			NewRecord.Period = InstallationPeriod;
			NewRecord.PriceKind = PriceKindInstallation;
			
			NewRecord.Actuality = True;
			NewRecord.Price = RoundPrice(NewRecord.Price, SetupRoundingOrder, RoundUpToInstallation, RoundingOrder0_01);
			
			NewRecord.Author = Author;
			RecordSet.Write();
			
			FilterStructure = New Structure;
			FilterStructure.Insert("ProductsAndServices", Selection.ProductsAndServices);
			FilterStructure.Insert("Characteristic", Selection.Characteristic);
			FilterStructure.Insert("Check", True);
			RowArray = ProductsAndServicesPrices.FindRows(FilterStructure);
			
			For Each FoundString IN RowArray Do
				
				FoundString.Picture = 1;
				FoundString.Price = NewRecord.Price;
				
			EndDo; 
			
		EndIf;
	
	EndDo; 
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OTHER COMMON PROCEDURES AND FUNCTIONS

&AtClient
Procedure ClearTabularSection()
	
	If ProductsAndServicesPrices.Count() = 0 Then
		
		Return;
		
	EndIf;
	
	QuestionText = NStr("en = 'Tabular section will be cleared.
								|Continue?'");
	
	NotifyDescription = New NotifyDescription("DetermineNecessityForTabularSectionClearing", ThisObject);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClientAtServerNoContext
Function RoundPrice(Number, RoundRule, RoundUp, RoundingOrder0_01)
	
	Var Result; // Returned result.
	
	// Transform order of numbers rounding.
	// If null order value is passed, then round to cents. 
	If Not ValueIsFilled(RoundRule) Then
		RoundingOrder = RoundingOrder0_01; 
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

&AtServerNoContext
// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	If StructureData.Property("PriceKind") Then
		
		StructureData.Insert("Characteristic", Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
		StructureData.Insert("DocumentCurrency", StructureData.PriceKind.PriceCurrency);
		StructureData.Insert("Factor", 1);
		
		PriceByPriceKind = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
		StructureData.Insert("Price", PriceByPriceKind);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

&AtServerNoContext
// It receives data set from server for the CharacteristicOnChange procedure.
//
Function GetDataCharacteristicOnChange(StructureData)
	
	StructureData.Insert("DocumentCurrency", StructureData.PriceKind.PriceCurrency);
	
	If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
	EndIf;
	
	PriceByPriceKind = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
	StructureData.Insert("Price", PriceByPriceKind);
	
	Return StructureData;
	
EndFunction // GetDataCharacteristicOnChange()

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure;
	
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

&AtServerNoContext
Procedure GetPriceKindAttributesAtServer(StructurePriceKind)
	
    StructurePriceKind.Insert("RoundUp", StructurePriceKind.PriceKind.RoundUp);
	StructurePriceKind.Insert("RoundingOrder", StructurePriceKind.PriceKind.RoundingOrder);
	StructurePriceKind.Insert("PricesBaseKind", StructurePriceKind.PriceKind.PricesBaseKind);
	StructurePriceKind.Insert("Markup", StructurePriceKind.PriceKind.Percent);  	

EndProcedure // GetPriceKindAttributesAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM AND COMMANDS EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ValueDates 	= ?(Parameters.Property("ToDate") AND ValueIsFilled(Parameters.ToDate), Parameters.ToDate, CurrentDate());
	Period 			= ValueDates;
	InstallationPeriod = ValueDates;
	
	If Parameters.Property("PriceKind") AND ValueIsFilled(Parameters.PriceKind) Then
		
		ParameterPriceKind = Parameters.PriceKind;
		
		If ParameterPriceKind.CalculatesDynamically Then
			
			MessageText = NStr("en = 'Dynamic price kinds generating is prohibited!'");
			SmallBusinessServer.ShowMessageAboutError(Object, MessageText, , , , Cancel);
			
		EndIf;
		
		PriceKindInstallation		= Parameters.PriceKind;
		
	Else
		
		ParameterPriceKind		= Undefined;
		//PriceKindInstallation 	= Catalogs.PriceKinds.GetMainKindOfSalePrices();
		
	EndIf;
	
	SetupRoundingOrder			= PriceKindInstallation.RoundingOrder;
	RoundUpToInstallation	= PriceKindInstallation.RoundUp;
	RoundingOrder 					= PriceKindInstallation.RoundingOrder;
	RoundUp 			= PriceKindInstallation.RoundUp;
	PricesBaseKind						= PriceKindInstallation.PricesBaseKind;
	Markup								= PriceKindInstallation.Percent;
	
	If Parameters.Property("PriceGroup") AND ValueIsFilled(Parameters.PriceGroup) Then
		ParameterPriceGroup = Parameters.PriceGroup;
	Else
		ParameterPriceGroup = Undefined;
	EndIf;
	
	If Parameters.Property("ProductsAndServices") AND ValueIsFilled(Parameters.ProductsAndServices) Then
		ParameterProductsAndServices = Parameters.ProductsAndServices;
	Else
		ParameterProductsAndServices = Undefined;
	EndIf;
	
	If Parameters.Property("AddressInventoryInStorage") Then
		ProductsAndServicesPrices.Load(GetFromTempStorage(Parameters.AddressInventoryInStorage));
		For Each CurRow IN ProductsAndServicesPrices Do
			CurRow.Check = True;
		EndDo;
	EndIf;
	
	FillProductsAndServicesPricesFirstTime(Period, ParameterPriceKind, ParameterPriceGroup, ParameterProductsAndServices);
	
	FillingPrices = "Choose action...";
	CurrentAction = "";
	CurrentActionFill = "";
	RoundingOrder0_01 = Enums.RoundingMethods.Round0_01;
	Author = Users.CurrentUser();
	
	Items.PageSetup.CurrentPage = Items.Page0; 
	
	NationalCurrency = Constants.NationalCurrency.Get();
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ValueSelected.FillVariant = "AddOnPrice" Then
		
		AddByPriceKindsAtServer(ValueSelected.ValueSelected, ValueSelected.ToDate, True, ValueSelected.UseCharacteristics);
		
	ElsIf ValueSelected.FillVariant = "AddBlankPricesByPriceKind" Then
		
		AddByPriceKindsAtServer(ValueSelected.ValueSelected, ValueSelected.ToDate, False, ValueSelected.UseCharacteristics);
		
	ElsIf ValueSelected.FillVariant = "AddOnPriceToFolders" Then
		
		AddByPriceGroupsAtServer(ValueSelected.ValueSelected, ValueSelected.UseCharacteristics);
		
	ElsIf ValueSelected.FillVariant = "AddOnToFoldersProductsAndServices" Then
		
		AddByProductsAndServicesCategoriesAtServer(ValueSelected.ValueSelected, ValueSelected.UseCharacteristics);
		
	ElsIf ValueSelected.FillVariant = "AddToInvoiceReceipt" Then
		
		AddByReceiptInvoiceAtServer(ValueSelected.ValueSelected);
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure ExecuteActions(Command)
	
	If CurrentAction = "FillPricesByPriceKind" Then
		
		FillPricesByPriceKindAtServer();
		
	ElsIf CurrentAction = "FillPricesByCounterpartyPriceKind" Then
		
		FillPricesByCounterpartyPriceKindAtServer();
		
	ElsIf CurrentAction = "CalculateByBasicPriceKind" Then
		
		CalculateByBasicPriceKindAtServer()
		
	ElsIf CurrentAction = "ChangeForPercent" Then
		
		ChangeForPercentAtClient();
		
	ElsIf CurrentAction = "ChangeForAmount" Then
		
		ChangeForAmountAtClient();
		
	ElsIf CurrentAction = "Round" Then
		
		RoundAtClient();
		
	ElsIf CurrentAction = "FillPricesByReceiptInvoice" Then
		
		FillPricesByReceiptInvoiceAtServer();
		
	ElsIf CurrentAction = "RemoveActuality" Then
		
		RemoveActualityAtServer();
		
	ElsIf CurrentAction = "DeletePriceListRecords" Then
		
		DeletePriceListRecordsAtServer();
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure Set(Command)
	
	If Not ValueIsFilled(PriceKindInstallation) Then
	
		Message = New UserMessage();
		Message.Text = NStr("en = 'Step 1: The prices type is not selected!'");
		Message.Field = "PriceKindInstallation";
		Message.Message();
		Return;
	
	EndIf; 
	
	If Not ValueIsFilled(InstallationPeriod) Then
	
		Message = New UserMessage();
		Message.Text = NStr("en = 'Step 4: Prices setting date is not selected!'");
		Message.Field = "InstallationPeriod";
		Message.Message();
		Return;
	
	EndIf; 
	
	SetupAtServer();
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	Close(True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABLE FILLING MECHANISMS

&AtClient
Procedure FillPriceTabularSection(Command)
	
	OpenForm("DataProcessor.Pricing.Form.FillingSettingsForm", , ThisForm);
	
EndProcedure

&AtClient
Procedure ClearPriceTabularSection(Command)
	
	ClearTabularSection();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - PAGES AND ACTIONS ATTRIBUTES PROCESSING SWITCHING

&AtClient
Procedure FillingPricesOnChange(Item)
	
	If FillingPrices = "Choose action..." Then
		
		CurrentAction = "";
		Items.PageSetup.CurrentPage = Items.Page0;
		
	ElsIf FillingPrices = "FillPricesByPriceKind" Then
		
		FillPricesByPriceKind(Undefined);
		
	ElsIf FillingPrices = "FillPricesByCounterpartyPriceKind" Then
		
		FillPricesByCounterpartyPriceKind(Undefined);
		
	ElsIf FillingPrices = "FillPricesByReceiptInvoice" Then
		
		FillPricesByReceiptInvoice(Undefined);
		
	ElsIf FillingPrices = "CalculateByBasicPriceKind" Then
		
		CalculateByBasicPriceKind(Undefined);
		
	ElsIf FillingPrices = "RemoveActuality" Then
		
		RemoveActuality(Undefined);
		
	ElsIf FillingPrices = "DeletePriceListRecords" Then
		
		DeletePriceListRecords(Undefined);
		
	ElsIf FillingPrices = "Round" Then
		
		Rounding(Undefined);
		
	ElsIf FillingPrices = "ChangeForAmount" Then
		
		ChangeForAmount(Undefined);
		
	ElsIf FillingPrices = "ChangeForPercent" Then
		
		ChangeForPercent(Undefined);
		
	EndIf;
	
EndProcedure

// FillPricesByPriceKind

&AtClient
Procedure FillPricesByPriceKind(Command)
	
	If CurrentAction = "FillPricesByPriceKind" Then
		Return;
	EndIf;
	CurrentAction = "FillPricesByPriceKind";
	
	Items.PageSetup.CurrentPage = Items.Page1;
	PriceKind = PriceKindInstallation;
	Period = CurrentDate();
	Items.Step4.Enabled = True;
	
EndProcedure

// FillPricesByCounterpartyPriceKind

&AtClient
Procedure FillPricesByCounterpartyPriceKind(Command)
	
	If CurrentAction = "FillPricesByCounterpartyPriceKind" Then
		Return;
	EndIf;
	CurrentAction = "FillPricesByCounterpartyPriceKind";
	
	Items.PageSetup.CurrentPage = Items.Page2;
	Items.Step4.Enabled = True;	
	
EndProcedure

// CalculateByBasicPriceKind

&AtClient
Procedure CalculateByBasicPriceKind(Command)
	
	If CurrentAction = "CalculateByBasicPriceKind" Then
		Return;
	EndIf;
	CurrentAction = "CalculateByBasicPriceKind";
	
	Items.PageSetup.CurrentPage = Items.Page3;
	Items.Step4.Enabled = True;
	
EndProcedure

// ChangeForPercent

&AtClient
Procedure ChangeForPercent(Command)
	
	If CurrentAction = "ChangeForPercent" Then
		Return;
	EndIf;
	CurrentAction = "ChangeForPercent";
	
	Items.PageSetup.CurrentPage = Items.Page4;
	PlusMinus = "+";
	Items.Step4.Enabled = True;
	
EndProcedure

// ChangeForAmount

&AtClient
Procedure ChangeForAmount(Command)
	
	If CurrentAction = "ChangeForAmount" Then
		Return;
	EndIf;
	CurrentAction = "ChangeForAmount";
	
	Items.PageSetup.CurrentPage = Items.Page5;
	PlusMinus = "+";
	Items.Step4.Enabled = True;
	
EndProcedure

// Round

&AtClient
Procedure Rounding(Command)
	
	If CurrentAction = "Rounding" Then
		Return;
	EndIf;
	CurrentAction = "Rounding";
	
	Items.PageSetup.CurrentPage = Items.Page6;
	Items.Step4.Enabled = True;
	
EndProcedure

// FillPricesByReceiptInvoice

&AtClient
Procedure FillPricesByReceiptInvoice(Command)
	
	If CurrentAction = "FillPricesByReceiptInvoice" Then
		Return;
	EndIf;
	CurrentAction = "FillPricesByReceiptInvoice";
	
	Items.PageSetup.CurrentPage = Items.Page7;
	Items.Step4.Enabled = True;
	
EndProcedure

// RemoveActuality

&AtClient
Procedure RemoveActuality(Command)
	
	If CurrentAction = "RemoveActuality" Then
		Return;
	EndIf;
	CurrentAction = "RemoveActuality";
	
	Items.PageSetup.CurrentPage = Items.Page8;
	Items.Step4.Enabled = False;
	
EndProcedure

// DeletePriceListRecords

&AtClient
Procedure DeletePriceListRecords(Command)
	
	If CurrentAction = "DeletePriceListRecords" Then
		Return;
	EndIf;
	CurrentAction = "DeletePriceListRecords";
	
	Items.PageSetup.CurrentPage = Items.Page9;
	Items.Step4.Enabled = False;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// OTHER PROCEDURES

&AtClient
Procedure MarkAll(Command)
	
	For Each TableRow IN ProductsAndServicesPrices Do
		TableRow.Check = True;
	EndDo;  
	
EndProcedure

&AtClient
Procedure UncheckMarks(Command)
	For Each TableRow IN ProductsAndServicesPrices Do
		TableRow.Check = False;
	EndDo;
EndProcedure

&AtClient
// Procedure - event handler OnChange of the ProductsAndServices input field.
//
Procedure ProductsAndServicesPricesProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.ProductsAndServicesPrices.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	If ValueIsFilled(PriceKindInstallation) Then
		StructureData.Insert("PriceKind", PriceKindInstallation);
		StructureData.Insert("ProcessingDate", InstallationPeriod);
	EndIf;
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Check = True;
	
	TabularSectionRow.OriginalPrice = StructureData.Price;
	TabularSectionRow.Price = StructureData.Price;
	
EndProcedure // InventoryProductsAndServicesOnChange()

&AtClient
Procedure ProductsAndServicesPricesCharacteristicOnChange(Item)
	
	If ValueIsFilled(PriceKindInstallation) Then
		
		TabularSectionRow = Items.ProductsAndServicesPrices.CurrentData;
		
		StructureData = New Structure;
		StructureData.Insert("PriceKind", PriceKindInstallation);
		StructureData.Insert("ProcessingDate", InstallationPeriod);
		StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
		StructureData = GetDataCharacteristicOnChange(StructureData);
		
		TabularSectionRow.OriginalPrice = StructureData.Price;
		TabularSectionRow.Price = StructureData.Price;
		
	EndIf;
	
EndProcedure // ProductsAndServicesPricesCharacteristicOnChange()

&AtClient
// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
Procedure ProductsAndServicesPricesMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.ProductsAndServicesPrices.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
	 OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
		
EndProcedure // InventoryMeasurementUnitChoiceProcessing()

&AtClient
Procedure PriceKindInstallationOnChange(Item)
	
	If Not ValueIsFilled(PriceKindInstallation) Then
		Return;
	EndIf; 
	
	StructurePriceKind = New Structure("PriceKind", PriceKindInstallation);
	
	GetPriceKindAttributesAtServer(StructurePriceKind);
	
	RoundUpToInstallation = StructurePriceKind.RoundUp;
	RoundUp = StructurePriceKind.RoundUp;
	SetupRoundingOrder = StructurePriceKind.RoundingOrder;
	RoundingOrder = StructurePriceKind.RoundingOrder;
	PricesBaseKind = StructurePriceKind.PricesBaseKind;
	Markup = StructurePriceKind.Markup;
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the question result document form filling by a basis document
//
//
Procedure DetermineNecessityForTabularSectionClearing(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		ProductsAndServicesPrices.Clear();
		
	EndIf;
	
EndProcedure // DetermineNecessityForTabularSectionClearing()

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
