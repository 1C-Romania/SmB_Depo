
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtClient
Procedure OnOpen(Cancel)
	
	If DaysNumber = 0 Then
		DaysNumber = 30;
	EndIf;
	
	If Not ValueIsFilled(ProductsPurchaseMode) Then
		ProductsPurchaseMode = "from supplier";
	EndIf;
	
	If Not ValueIsFilled(MiddleSalesCalculationPeriod.StartDate)
		OR Not ValueIsFilled(MiddleSalesCalculationPeriod.EndDate) Then
		MiddleSalesCalculationPeriod.Variant = StandardPeriodVariant.LastMonth;
	EndIf;
	
	SetVisibleServer();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ChangedOrderVendor" Then
		
		ClearMessages();
		RefreshTablePartOrdersServer();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure ProductsPurchaseModeOnChange(Item)
	
	SetVisibleServer();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// THE TABLE EVENT HANDLERS OF THE "Demand" FORM

&AtClient
Procedure RequirmentSelect(Item, SelectedRow, Field, StandardProcessing)
	
	FieldName = Field.Name;
	
	If FieldName <> "NeedForVendor" 
		AND FieldName <> "NeedForProductsAndServices"
		AND FieldName <> "NeedForCharacteristic" Then
		
		Return;
	EndIf;
	
	AttributeName = StrReplace(Field.Name, "Demand", "");
	
	Value = Item.CurrentData[AttributeName];
	If ValueIsFilled(Value) Then
		ShowValue(Undefined, Value);
	EndIf;
	
EndProcedure

&AtClient
Procedure NeedToCheckOnChange(Item)
	
	CurrentData = Items.Demand.CurrentData;
	If CurrentData <> Undefined Then
		
		MarkValue = CurrentData.Check;
		If CurrentData.GetParent() = Undefined Then
			FillMarksRequirement(MarkValue, CurrentData.GetID());
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DemandQuantityForPurchaseOnChange(Item)
	
	CurrentData = Items.Demand.CurrentData;
	If CurrentData <> Undefined Then
		
		UpperLevelRow = CurrentData.GetParent();
		If UpperLevelRow <> Undefined Then
			
			QuantityForPurchaseTotal = 0;
			LowerLevelElements = UpperLevelRow.GetItems();
			For Each LowerLevelElement IN LowerLevelElements Do
				QuantityForPurchaseTotal = QuantityForPurchaseTotal + LowerLevelElement.QuantityForPurchase;
			EndDo;
			
			UpperLevelRow.QuantityForPurchase = QuantityForPurchaseTotal;
			
			If Not CurrentData.Check Then
				CurrentData.Check = True;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// THE TABLE EVENT HANDLERS OF THE "Orders" FORM

&AtClient
Procedure OrdersSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	Document = Item.CurrentData.Document;
	If ValueIsFilled(Document) Then
		ShowValue(Undefined, Document);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure CheckAll(Command)
	
	FillMarksRequirement(True);
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	FillMarksRequirement(False);
	
EndProcedure

&AtClient
Procedure OrderFlagsSet(Command)
	
	OrdersFillMarks(True);
	
EndProcedure

&AtClient
Procedure RemoveOrdersFlags(Command)
	
	OrdersFillMarks(False);
	
EndProcedure

&AtClient
Procedure ShowZeroSales(Command)
	
	If Demand.GetItems().Count() > 0 Then
		QuestionText = NStr("en='Tabular section will be refilled. Continue?';ru='Табличная часть будет перезаполнена. Продолжить?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("ShowZeroSalesEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
	EndIf;
	
	ShowZeroSalesFragment();
EndProcedure

&AtClient
Procedure ShowZeroSalesEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    ShowZeroSalesFragment();

EndProcedure

&AtClient
Procedure ShowZeroSalesFragment()
    
    Items.ShowZeroSales.Check = Not Items.ShowZeroSales.Check;
    FillAndCalculateServer();
    
    TreeStringsRecount();

EndProcedure

&AtClient
Procedure FillAndCalculate(Command)
	
	If Demand.GetItems().Count() > 0 Then
		QuestionText = NStr("en='Tabular section will be refilled. Continue?';ru='Табличная часть будет перезаполнена. Продолжить?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillAndCalculateEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
	EndIf;
	
	FillAndCalculateFragment();
EndProcedure

&AtClient
Procedure FillAndCalculateEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    FillAndCalculateFragment();

EndProcedure

&AtClient
Procedure FillAndCalculateFragment()
    
    If Not ValueIsFilled(MiddleSalesCalculationPeriod.StartDate)
        OR Not ValueIsFilled(MiddleSalesCalculationPeriod.EndDate) Then
        
        MiddleSalesCalculationPeriod.Variant = StandardPeriodVariant.LastMonth;
    EndIf;
    
    FillAndCalculateServer();
    
    TreeStringsRecount();

EndProcedure

&AtClient
Procedure GenerateOrders(Command)
	
	ClearMessages();
	Orders.Clear();
	If OrderSetServer() Then
		
		ShowUserNotification(
			,,
			NStr("en='Purchase orders have been successfully created.';ru='Заказы поставщикам успешно созданы.'"),
			PictureLib.Information32
		);
		
		Items.PagesProducts.CurrentPage = Items.OrdersPage;
		
	Else
		
		Message = New UserMessage;
		Message.Text = NStr("en='No data to generate the orders.';ru='Нет данных для формирования заказов.'");
		Message.Message();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OrderEdit(Command)
	
	CurrentData = Items.Orders.CurrentData;
	If CurrentData <> Undefined
		AND ValueIsFilled(CurrentData.Document) Then
		ShowValue(Undefined, CurrentData.Document);
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteOrder(Command)
	
	OrdersForDeleting = Orders.FindRows(New Structure("Check", True));
	If OrdersForDeleting.Count() = 0 Then
		
		Return;
		
	ElsIf OrdersForDeleting.Count() = 1 Then
		
		QuestionText = NStr("en='Selected document will be deleted. Continue?';ru='Выбранный документ будет удален. Продолжить?'");
		
	Else
		
		QuestionText = NStr("en='Selected documents will be deleted. Continue?';ru='Выбранные документы будут удалены. Продолжить?'");
		
	EndIf;
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("DeleteOrderEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure DeleteOrderEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        
        OrdersDeleteServer();
        
    EndIf;

EndProcedure

&AtClient
Procedure PostOrders(Command)
	
	ClearMessages();
	PostOrdersServer();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// Procedure sets the form item visible.
//
&AtServer
Procedure SetVisibleServer()
	
	If ProductsPurchaseMode = "from supplier" Then
		Items.Vendor.Visible = True;
		Items.ProductsGroup.Visible = False;
	Else
		Items.Vendor.Visible = False;
		Items.ProductsGroup.Visible = True;
	EndIf;
	
EndProcedure

// Procedure fills the Demand
// table by data and calculates the quantity recommended for purchase.
//
&AtServer
Procedure FillAndCalculateServer()
	
	RequirementTree = FormAttributeToValue("Demand");
	RequirementTree.Rows.Clear();
	
	OutputZeroSale = Items.ShowZeroSales.Check;
	
	BeginOfPeriodForCalculatingStatistics = MiddleSalesCalculationPeriod.StartDate;
	EndOfPeriodForCalculatingStatistics = MiddleSalesCalculationPeriod.EndDate;
	
	TableBalancesOnDays = New ValueTable;
	
	TableBalancesOnDays.Columns.Add("DayPeriod", New TypeDescription("Date"));
	TableBalancesOnDays.Columns.Add("ProductsAndServices", New TypeDescription("CatalogRef.ProductsAndServices"));
	TableBalancesOnDays.Columns.Add("Characteristic", New TypeDescription("CatalogRef.ProductsAndServicesCharacteristics"));
	TableBalancesOnDays.Columns.Add("DaysNumber", New TypeDescription("Number"));
	TableBalancesOnDays.Columns.Add("OpeningBalance", New TypeDescription("Number"));
	TableBalancesOnDays.Columns.Add("ClosingBalance", New TypeDescription("Number"));
	TableBalancesOnDays.Columns.Add("QuantityReceipt", New TypeDescription("Number"));
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	InventoryInWarehousesBalanceAndTurnovers.Period AS DayPeriod,
	|	InventoryInWarehousesBalanceAndTurnovers.ProductsAndServices AS ProductsAndServices,
	|	InventoryInWarehousesBalanceAndTurnovers.Characteristic AS Characteristic,
	|	InventoryInWarehousesBalanceAndTurnovers.QuantityOpeningBalance AS OpeningBalance,
	|	InventoryInWarehousesBalanceAndTurnovers.QuantityReceipt AS QuantityReceipt,
	|	InventoryInWarehousesBalanceAndTurnovers.QuantityExpense AS QuantityExpense,
	|	InventoryInWarehousesBalanceAndTurnovers.QuantityClosingBalance AS ClosingBalance
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.BalanceAndTurnovers(
	|			&BeginOfPeriod,
	|			&EndOfPeriod,
	|			Day,
	|			RegisterRecordsAndPeriodBoundaries,
	|			%FilterByVendor%
	|				AND %FilterByGroup%) AS InventoryInWarehousesBalanceAndTurnovers
	|
	|ORDER BY
	|	DayPeriod,
	|	ProductsAndServices,
	|	Characteristic
	|TOTALS
	|	SUM(OpeningBalance),
	|	SUM(QuantityReceipt),
	|	SUM(QuantityExpense),
	|	SUM(ClosingBalance)
	|BY
	|	DayPeriod PERIODS(Day, &BeginOfPeriod, &EndOfPeriod),
	|	ProductsAndServices,
	|	Characteristic";
	
	Query.SetParameter("BeginOfPeriod", BeginOfPeriodForCalculatingStatistics);
	Query.SetParameter("EndOfPeriod", EndOfPeriodForCalculatingStatistics);

	ProcessQueryText(Query);
	
	QueryResult = Query.Execute();

	SelectionPeriod = QueryResult.Select(QueryResultIteration.ByGroups, "DayPeriod", "All");

	While SelectionPeriod.Next() Do

		SelectionProductsAndServices = SelectionPeriod.Select(QueryResultIteration.ByGroups);
		While SelectionProductsAndServices.Next() Do
			
			SelectionCharacteristic = SelectionProductsAndServices.Select(QueryResultIteration.ByGroups);
			While SelectionCharacteristic.Next() Do
				
				If SelectionCharacteristic.OpeningBalance > 0
					OR SelectionCharacteristic.ClosingBalance > 0
					OR (SelectionCharacteristic.QuantityReceipt <> Null AND SelectionCharacteristic.QuantityReceipt > 0) Then
					
					NewRow = TableBalancesOnDays.Add();
					FillPropertyValues(NewRow, SelectionCharacteristic);
					NewRow.DaysNumber = 1;
					
				EndIf;
				
			EndDo;
		EndDo;
	EndDo;
	
	TableBalancesOnDays.GroupBy("ProductsAndServices, Characteristic", "DaysNumber");
	TableBalancesOnDays.Indexes.Add("ProductsAndServices, Characteristic");

	Query = New Query;
	Query.Text = 
	"SELECT
	|	TableBalancesOnDays.ProductsAndServices AS ProductsAndServices,
	|	TableBalancesOnDays.Characteristic AS Characteristic,
	|	TableBalancesOnDays.DaysNumber AS NumberOfSalesDays
	|INTO Tu_NumberOfSalesDays
	|FROM
	|	&TableBalancesOnDays AS TableBalancesOnDays
	|
	|INDEX BY
	|	ProductsAndServices,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ProductsAndServices.Ref AS ProductsAndServices,
	|	VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef) AS Characteristic,
	|	ProductsAndServices.Vendor
	|INTO Tu_ProductsAndServicesCharacteristics
	|FROM
	|	Catalog.ProductsAndServices AS ProductsAndServices
	|WHERE
	|	ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	AND Not ProductsAndServices.IsFolder
	|	AND %FilterByVendor%
	|	AND %FilterByGroup%
	|
	|UNION ALL
	|
	|SELECT
	|	ProductsAndServices.Ref,
	|	ProductsAndServicesCharacteristics.Ref,
	|	ProductsAndServices.Vendor
	|FROM
	|	Catalog.ProductsAndServices AS ProductsAndServices
	|		INNER JOIN Catalog.ProductsAndServicesCharacteristics AS ProductsAndServicesCharacteristics
	|		ON (ProductsAndServicesCharacteristics.Owner = ProductsAndServices.Ref)
	|WHERE
	|	ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	AND Not ProductsAndServices.IsFolder
	|	AND %FilterByVendor%
	|	AND %FilterByGroup%
	|
	|INDEX BY
	|	ProductsAndServices,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServicesCharacteristics.Vendor AS Vendor,
	|	ProductsAndServicesCharacteristics.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesCharacteristics.Characteristic AS Characteristic,
	|	ISNULL(InventoryBalances.QuantityBalance, 0) AS CurrentBalance
	|INTO Tu_ProductsAndServicesCharacteristicsBalance
	|FROM
	|	Tu_ProductsAndServicesCharacteristics AS ProductsAndServicesCharacteristics
	|		LEFT JOIN AccumulationRegister.Inventory.Balance(
	|				,
	|				(ProductsAndServices, Characteristic) In
	|					(SELECT
	|						ProductsAndServicesCharacteristics.ProductsAndServices,
	|						ProductsAndServicesCharacteristics.Characteristic
	|					FROM
	|						Tu_ProductsAndServicesCharacteristics AS ProductsAndServicesCharacteristics)) AS InventoryBalances
	|		ON ProductsAndServicesCharacteristics.ProductsAndServices = InventoryBalances.ProductsAndServices
	|			AND ProductsAndServicesCharacteristics.Characteristic = InventoryBalances.Characteristic
	|
	|INDEX BY
	|	ProductsAndServices,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesTurnovers.ProductsAndServices,
	|	SalesTurnovers.Characteristic,
	|	SUM(SalesTurnovers.QuantityTurnover) AS Sold
	|INTO Tu_Sales
	|FROM
	|	AccumulationRegister.Sales.Turnovers(
	|			&StartPeriod,
	|			&EndPeriod,
	|			Auto,
	|			(ProductsAndServices, Characteristic) In
	|				(SELECT
	|					Tu_ProductsAndServicesCharacteristics.ProductsAndServices,
	|					Tu_ProductsAndServicesCharacteristics.Characteristic
	|				FROM
	|					Tu_ProductsAndServicesCharacteristics AS Tu_ProductsAndServicesCharacteristics)) AS SalesTurnovers
	|
	|GROUP BY
	|	SalesTurnovers.ProductsAndServices,
	|	SalesTurnovers.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tu_ProductsAndServicesCharacteristicsBalance.Vendor AS Vendor,
	|	Tu_ProductsAndServicesCharacteristicsBalance.ProductsAndServices AS ProductsAndServices,
	|	Tu_ProductsAndServicesCharacteristicsBalance.Characteristic AS Characteristic,
	|	Tu_ProductsAndServicesCharacteristicsBalance.CurrentBalance AS CurrentBalance,
	|	ISNULL(Tu_Sales.Sold, 0) AS SalesStatisticsQuantity,
	|	CASE
	|		WHEN ISNULL(Tu_Sales.Sold, 0) = 0 
	|				OR ISNULL(Tu_NumberOfSalesDays.NumberOfSalesDays, 0) = 0
	|			THEN 0
	|		ELSE ISNULL(Tu_Sales.Sold, 0) / Tu_NumberOfSalesDays.NumberOfSalesDays
	|	END AS SalesStatisticsAverageSale,
	|	CASE
	|		WHEN ISNULL(Tu_Sales.Sold, 0) = 0 
	|				OR ISNULL(Tu_NumberOfSalesDays.NumberOfSalesDays, 0) = 0
	|			THEN 0
	|		ELSE ISNULL(Tu_Sales.Sold, 0) / Tu_NumberOfSalesDays.NumberOfSalesDays
	|	END * &DaysNumber - Tu_ProductsAndServicesCharacteristicsBalance.CurrentBalance AS QuantityForPurchase,
	|	Tu_NumberOfSalesDays.NumberOfSalesDays AS SalesStatisticsQuantityDays
	|FROM
	|	Tu_ProductsAndServicesCharacteristicsBalance AS Tu_ProductsAndServicesCharacteristicsBalance
	|		LEFT JOIN Tu_Sales AS Tu_Sales
	|		ON Tu_ProductsAndServicesCharacteristicsBalance.ProductsAndServices = Tu_Sales.ProductsAndServices
	|			AND Tu_ProductsAndServicesCharacteristicsBalance.Characteristic = Tu_Sales.Characteristic
	|		LEFT JOIN Tu_NumberOfSalesDays AS Tu_NumberOfSalesDays
	|		ON Tu_ProductsAndServicesCharacteristicsBalance.ProductsAndServices = Tu_NumberOfSalesDays.ProductsAndServices
	|			AND Tu_ProductsAndServicesCharacteristicsBalance.Characteristic = Tu_NumberOfSalesDays.Characteristic
	|WHERE
	|	CASE
	|			WHEN Not &OutputZeroSale
	|				THEN ISNULL(Tu_Sales.Sold, 0) > 0
	|			ELSE TRUE
	|		END
	|
	|ORDER BY
	|	Vendor, QuantityForPurchase DESC, ProductsAndServices, Characteristic
	|TOTALS
	|	SUM(CurrentBalance),
	|	SUM(SalesStatisticsQuantity),
	|	SUM(SalesStatisticsAverageSale),
	|	SUM(QuantityForPurchase),
	|	SUM(SalesStatisticsQuantityDays)
	|BY
	|	Vendor";
	
	Query.SetParameter("TableBalancesOnDays", TableBalancesOnDays);
	Query.SetParameter("StartPeriod", BeginOfPeriodForCalculatingStatistics);
	Query.SetParameter("EndPeriod", EndOfPeriodForCalculatingStatistics);
	Query.SetParameter("DaysNumber", DaysNumber);
	Query.SetParameter("OutputZeroSale", OutputZeroSale);
	
	ProcessQueryText(Query);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		ValueToFormAttribute(RequirementTree, "Demand");
		Return;
	EndIf;
	
	VendorSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	While VendorSelection.Next() Do
		
		SuplierString = RequirementTree.Rows.Add();
		FillPropertyValues(SuplierString, VendorSelection);
		
		SuplierString.QuantityForPurchase = Round(SuplierString.QuantityForPurchase);
		
		SelectionProductsAndServices = VendorSelection.Select();
		While SelectionProductsAndServices.Next() Do
			
			StringProductsAndServices = SuplierString.Rows.Add();
			FillPropertyValues(StringProductsAndServices, SelectionProductsAndServices,,"Vendor");
			
			StringProductsAndServices.QuantityForPurchase = Round(StringProductsAndServices.QuantityForPurchase);
			
		EndDo;
		
	EndDo;
	
	ValueToFormAttribute(RequirementTree, "Demand");
	Items.Demand.InitialTreeView = InitialTreeView.ExpandAllLevels;
	
EndProcedure

&AtServer
Procedure ProcessQueryText(Query)
	
	If ProductsPurchaseMode = "from supplier"
		AND ValueIsFilled(Vendor) Then
		
		Query.SetParameter("Vendor", Vendor);
		Query.Text = StrReplace(Query.Text, "%FilterByVendor%", "ProductsAndServices.Vendor = &Vendor");
		Query.Text = StrReplace(Query.Text, "%FilterByGroup%", "TRUE");
		
	ElsIf ProductsPurchaseMode = "products group"
		AND ValueIsFilled(ProductsGroup) Then
		
		Query.SetParameter("ProductsGroup", ProductsGroup);
		Query.Text = StrReplace(Query.Text, "%FilterByGroup%", "ProductsAndServices.Ref IN HIERARCHY (&ProductsGroup)");
		Query.Text = StrReplace(Query.Text, "%FilterByVendor%", "TRUE");
		
	Else
		
		Query.Text = StrReplace(Query.Text, "%FilterByVendor%", "TRUE");
		Query.Text = StrReplace(Query.Text, "%FilterByGroup%", "TRUE");
		
	EndIf;
	
EndProcedure

// Procedure fills the string check boxes in the Orders table.
//
&AtClient
Procedure OrdersFillMarks(MarkValue)
	
	For Each TableRow IN Orders Do
		TableRow.Check = MarkValue;
	EndDo;
	
EndProcedure

// Procedure fills the string check boxes in the Demand table.
//
&AtClient
Procedure FillMarksRequirement(MarkValue, ItemIdentificator = Undefined)
	
	If ItemIdentificator <> Undefined Then
		TreeItem = Demand.FindByID(ItemIdentificator);
		LowerLevelElements = TreeItem.GetItems();
		For Each LowerLevelElement IN LowerLevelElements Do
			LowerLevelElement.Check = MarkValue;
		EndDo;
	Else
		UpperLevelItems = Demand.GetItems();
		For Each TopLevelItem IN UpperLevelItems Do
			TopLevelItem.Check = MarkValue;
			LowerLevelElements = TopLevelItem.GetItems();
			For Each LowerLevelElement IN LowerLevelElements Do
				LowerLevelElement.Check = MarkValue;
			EndDo;
		EndDo;
	EndIf;
	
EndProcedure

// Receives the counterparty contract corresponding to document conditions by default.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, OperationKind, Company)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ContractKindsList = New ValueList;
	ContractKindsList.Add(Enums.ContractKinds.WithVendor);
	ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
	
	ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractKindsList);
	
	Return ContractByDefault;
	
EndFunction

// The procedure generates purchase orders by data in selected strings of the Demand table.
//
&AtServer
Function OrderSetServer()
	
	RequirementTree = FormAttributeToValue("Demand");
	OrdersComposed = False;
	
	BeginTransaction();
	
	Try
		
		For Each SuplierString IN RequirementTree.Rows Do
			
			If SuplierString.Rows.Find(True, "Check") = Undefined
				OR SuplierString.Rows.Total("QuantityForPurchase") = 0 Then
				Continue;
			EndIf;
			
			VendorCounterparty = SuplierString.Vendor;
			
			DocumentObject = Documents.PurchaseOrder.CreateDocument();
			
			OperationKind = Enums.OperationKindsPurchaseOrder.OrderForPurchase;
			PostingIsAllowed = True;
			
			DocumentObject.AmountIncludesVAT = True;
			
			SmallBusinessServer.FillDocumentHeader(
				DocumentObject,
				OperationKind,,,
				PostingIsAllowed
			);
			
			DocumentObject.Date = CurrentDate();
			DocumentObject.OperationKind = OperationKind;
			DocumentObject.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
			DocumentObject.ReceiptDatePosition = Enums.AttributePositionOnForm.InHeader;
			DocumentObject.Counterparty = VendorCounterparty;
			
			ContractByDefault = GetContractByDefault(DocumentObject, VendorCounterparty, OperationKind, DocumentObject.Company);
			If ValueIsFilled(ContractByDefault) Then
				
				DocumentObject.DocumentCurrency = ContractByDefault.SettlementsCurrency;
				DocumentObject.Contract = ContractByDefault;
				
				CounterpartyPriceKind = ContractByDefault.CounterpartyPriceKind;
				DocumentObject.CounterpartyPriceKind = CounterpartyPriceKind;
				
			EndIf;
			
			Filter = New Structure("Currency", DocumentObject.DocumentCurrency);
			StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(CurrentDate(), Filter);
			
			DocumentObject.ExchangeRate = StructureByCurrency.ExchangeRate;
			DocumentObject.Multiplicity = StructureByCurrency.Multiplicity;
			
			If ValueIsFilled(CounterpartyPriceKind) Then
				DocumentObject.AmountIncludesVAT = CounterpartyPriceKind.PriceIncludesVAT;
			EndIf;
			
			For Each StringProductsAndServices IN SuplierString.Rows Do
				
				If Not StringProductsAndServices.Check
					OR StringProductsAndServices.QuantityForPurchase = 0 Then
					Continue;
				EndIf;
				
				NewRow = DocumentObject.Inventory.Add();
				NewRow.ProductsAndServices = StringProductsAndServices.ProductsAndServices;
				NewRow.Characteristic = StringProductsAndServices.Characteristic;
				NewRow.Quantity = StringProductsAndServices.QuantityForPurchase;
				
				StructureData = New Structure;
				StructureData.Insert("Company", DocumentObject.Company);
				StructureData.Insert("ProductsAndServices", NewRow.ProductsAndServices);
				StructureData.Insert("Characteristic", NewRow.Characteristic);
				StructureData.Insert("VATTaxation", DocumentObject.VATTaxation);
				
				If ValueIsFilled(DocumentObject.CounterpartyPriceKind) Then
					
					StructureData.Insert("ProcessingDate", DocumentObject.Date);
					StructureData.Insert("DocumentCurrency", DocumentObject.DocumentCurrency);
					StructureData.Insert("AmountIncludesVAT", DocumentObject.AmountIncludesVAT);
					StructureData.Insert("CounterpartyPriceKind", DocumentObject.CounterpartyPriceKind);
					StructureData.Insert("Factor", 1);
					
				EndIf;
				
				StructureData = GetDataProductsAndServicesOnChange(StructureData);
				
				NewRow.MeasurementUnit = StructureData.MeasurementUnit;
				NewRow.Quantity = StringProductsAndServices.QuantityForPurchase;
				NewRow.Price = StructureData.Price;
				NewRow.VATRate = StructureData.VATRate;
				NewRow.Content = "";
				
				CalculateAmountInTabularSectionLine(NewRow, DocumentObject.AmountIncludesVAT);
				
			EndDo;
			
			If DocumentObject.Inventory.Count() = 0 Then
				DocumentObject = Undefined;
				Continue;
			EndIf;
			
			DocumentObject.DocumentAmount = DocumentObject.Inventory.Total("Total");
			DocumentObject.Comment = NStr("en='It is automatically created by the ""Product need calculation"" data processor';ru='Создан автоматически обработкой ""Расчет потребности товаров""'");
			
			DocumentObject.Write(DocumentWriteMode.Write);
			
			OrdersString = Orders.Add();
			OrdersString.Document = DocumentObject.Ref;
			OrdersString.Vendor = DocumentObject.Counterparty;
			OrdersString.DocumentAmount = DocumentObject.DocumentAmount;
			OrdersString.PictureIndex = 0;
			
			OrdersComposed = True
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		ErrorDescription = NStr("en='While generating an order, an error occurred.
		|Order generation is canceled.
		|Additional
		|description: %AdditionalDetails%';ru='При формировании заказов произошла ошибка.
		|Формирование заказов отменено.
		|Дополнительное
		|описание: %ДополнительноеОписание%'"
		);
		
		ErrorDescription = StrReplace(ErrorDescription, "%AdditionalDetails%", ErrorInfo().Definition);
		Raise ErrorDescription;
		
	EndTry;
	
	Return OrdersComposed;
	
EndFunction

&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	If StructureData.Property("VATTaxation") 
		AND Not StructureData.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		If StructureData.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
			StructureData.Insert("VATRate", SmallBusinessReUse.GetVATRateWithoutVAT());
		Else
			StructureData.Insert("VATRate", SmallBusinessReUse.GetVATRateZero());
		EndIf;
		
	ElsIf ValueIsFilled(StructureData.ProductsAndServices.VATRate) Then
		StructureData.Insert("VATRate", StructureData.ProductsAndServices.VATRate);
	Else
		StructureData.Insert("VATRate", StructureData.Company.DefaultVATRate);
	EndIf;
	
	If StructureData.Property("CounterpartyPriceKind") Then
		
		Price = SmallBusinessServer.GetPriceProductsAndServicesByCounterpartyPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow, AmountIncludesVAT)
	
	// Amount.
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	// VAT amount.
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(AmountIncludesVAT, 
	TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
	TabularSectionRow.Amount * VATRate / 100);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// The procedure posts the selected purchase orders.
//
&AtServer
Procedure PostOrdersServer()
	
	For Each TableRow IN Orders Do
		
		If Not TableRow.Check
			OR Not ValueIsFilled(TableRow.Document) Then
			Continue;
		EndIf;
		
		DocumentObject = TableRow.Document.GetObject();
		DocumentPostedSuccessfully = False;
		Try
			
			If DocumentObject.CheckFilling() Then
				
				// Trying to post the document
				DocumentObject.Write(DocumentWriteMode.Posting);
				DocumentPostedSuccessfully = DocumentObject.Posted;
				
			Else
				
				DocumentPostedSuccessfully = False;
				
			EndIf;
			
		Except
			
			DocumentPostedSuccessfully = False;
			
		EndTry;
		
		If DocumentPostedSuccessfully Then
			
			TableRow.PictureIndex = 1;
			
		Else
			
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Cannot post the %1 document.';ru='Не удалось провести документ: %1.'"), String(DocumentObject));
			
			Message = New UserMessage;
			Message.Text = MessageText;
			Message.Message();
			
			TableRow.PictureIndex = 0;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Function defines references to the document.
//
&AtServerNoContext
Function IsReferencesToDocument(Document)

	RefArray = New Array;
	RefArray.Add(Document);
	
	ReferenceTab = FindByRef(RefArray);
	
	If ReferenceTab.Count() > 0 Then
		Return True;
	Else
		Return False;
	EndIf;

EndFunction

// The procedure removes the selected purchase orders.
//
&AtServer
Procedure OrdersDeleteServer()
	
	SetPrivilegedMode(True);
	
	StringsArrayForDelete = New Array;
	
	For Each TableRow IN Orders Do
		
		If Not TableRow.Check
			OR Not ValueIsFilled(TableRow.Document) Then
			Continue;
		EndIf;
		
		DocumentObject = TableRow.Document.GetObject();
		Try
			If IsReferencesToDocument(DocumentObject.Ref) Then
				DocumentObject.SetDeletionMark(True);
			Else
				DocumentObject.Delete();
			EndIf;
			StringsArrayForDelete.Add(TableRow);
		Except
			
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Cannot mark the %1 document for deletion.';ru='Не удалось пометить на удаление документ: %1.'"), String(DocumentObject));
			
			Message = New UserMessage;
			Message.Text = MessageText;
			Message.Message();
			
		EndTry;
		
	EndDo;
	
	For Each RowForDeletion IN StringsArrayForDelete Do
		
		Orders.Delete(RowForDeletion);
		
	EndDo;
	
EndProcedure

// The procedure updates the Orders table data while changing a purchase order.
//
&AtServer
Procedure RefreshTablePartOrdersServer()
	
	For Each TableRow IN Orders Do
		If Not ValueIsFilled(TableRow.Document) Then
			Continue;
		EndIf;
		
		AttributeValues = CommonUse.ObjectAttributesValues(TableRow.Document, "Posted, Counterparty, DocumentAmount");
		TableRow.Vendor = AttributeValues.Counterparty;
		TableRow.DocumentAmount = AttributeValues.DocumentAmount;
		
		TableRow.PictureIndex = ?(AttributeValues.Posted, 1, 0);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure TreeStringsRecount()
	
	UpperLevelStrings = Demand.GetItems();
	For Each UpperLevelRow IN UpperLevelStrings Do
		
		QuantityForPurchaseTotal = 0;
		SalesStatisticsQuantityDaysMax = 0;
		SalesStatisticsAverageSaleMax = 0;
		
		LowerLevelElements = UpperLevelRow.GetItems();
		For Each LowerLevelElement IN LowerLevelElements Do
			QuantityForPurchaseTotal = QuantityForPurchaseTotal + LowerLevelElement.QuantityForPurchase;
			If LowerLevelElement.SalesStatisticsQuantityDays > SalesStatisticsQuantityDaysMax Then
				SalesStatisticsQuantityDaysMax = LowerLevelElement.SalesStatisticsQuantityDays;
			EndIf;
			If LowerLevelElement.SalesStatisticsAverageSale > SalesStatisticsAverageSaleMax Then
				SalesStatisticsAverageSaleMax = LowerLevelElement.SalesStatisticsAverageSale;
			EndIf;
		EndDo;
		
		UpperLevelRow.QuantityForPurchase = QuantityForPurchaseTotal;
		UpperLevelRow.SalesStatisticsQuantityDays = SalesStatisticsQuantityDaysMax;
		UpperLevelRow.SalesStatisticsAverageSale = SalesStatisticsAverageSaleMax;
		
	EndDo;
	
EndProcedure






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
