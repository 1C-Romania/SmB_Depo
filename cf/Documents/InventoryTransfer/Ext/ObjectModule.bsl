#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Procedure checks the existence of retail price.
//
Procedure CheckExistenceOfRetailPrice(Cancel)
	
	If StructuralUnitPayee.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
	 OR StructuralUnitPayee.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
	 
		Query = New Query;
		Query.SetParameter("Date", Date);
		Query.SetParameter("DocumentTable", Inventory);
		Query.SetParameter("RetailPriceKind", StructuralUnitPayee.RetailPriceKind);
		Query.SetParameter("ListProductsAndServices", Inventory.UnloadColumn("ProductsAndServices"));
		Query.SetParameter("ListCharacteristic", Inventory.UnloadColumn("Characteristic"));
		
		Query.Text =
		"SELECT
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.ProductsAndServices AS ProductsAndServices,
		|	DocumentTable.Characteristic AS Characteristic,
		|	DocumentTable.Batch AS Batch
		|INTO InventoryTransferInventory
		|FROM
		|	&DocumentTable AS DocumentTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	InventoryTransferInventory.LineNumber AS LineNumber,
		|	PRESENTATION(InventoryTransferInventory.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	PRESENTATION(InventoryTransferInventory.Characteristic) AS CharacteristicPresentation,
		|	PRESENTATION(InventoryTransferInventory.Batch) AS BatchPresentation
		|FROM
		|	InventoryTransferInventory AS InventoryTransferInventory
		|		LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(
		|				&Date,
		|				PriceKind = &RetailPriceKind
		|					AND ProductsAndServices IN (&ListProductsAndServices)
		|					AND Characteristic IN (&ListCharacteristic)) AS ProductsAndServicesPricesSliceLast
		|		ON InventoryTransferInventory.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices
		|			AND InventoryTransferInventory.Characteristic = ProductsAndServicesPricesSliceLast.Characteristic
		|WHERE
		|	ISNULL(ProductsAndServicesPricesSliceLast.Price, 0) = 0";
		
		SelectionOfQueryResult = Query.Execute().Select();
		
		While SelectionOfQueryResult.Next() Do
			
			MessageText = NStr("en='For products and services %ProductsAndServicesPresentation% in string %LineNumber% of the ""Inventory"" list the retail price is not set!';ru='Для номенклатуры %ПредставлениеНоменклатуры% в строке %НомерСтроки% списка ""Запасы"" не установлена розничная цена!'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(SelectionOfQueryResult.LineNumber));
			MessageText = StrReplace(MessageText, "%ProductsAndServicesPresentation%",  SmallBusinessServer.PresentationOfProductsAndServices(SelectionOfQueryResult.ProductsAndServicesPresentation, SelectionOfQueryResult.CharacteristicPresentation, SelectionOfQueryResult.BatchPresentation));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Inventory",
				SelectionOfQueryResult.LineNumber,
				"ProductsAndServices",
				Cancel
			);
			
		EndDo;
	 
	EndIf;
	
EndProcedure // CheckRetailPriceExistence()

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure fills the Inventory tabular section by balances at warehouse.
//
Procedure FillInventoryByInventoryBalances() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InventoryInWarehousesOfBalance.Company AS Company,
	|	InventoryInWarehousesOfBalance.ProductsAndServices AS ProductsAndServices,
	|	InventoryInWarehousesOfBalance.ProductsAndServices.MeasurementUnit AS MeasurementUnit,
	|	InventoryInWarehousesOfBalance.Characteristic AS Characteristic,
	|	InventoryInWarehousesOfBalance.Batch AS Batch,
	|	InventoryInWarehousesOfBalance.StructuralUnit AS StructuralUnit,
	|	InventoryInWarehousesOfBalance.Cell AS Cell,
	|	SUM(InventoryInWarehousesOfBalance.QuantityBalance) AS Quantity
	|FROM
	|	(SELECT
	|		InventoryInWarehouses.Company AS Company,
	|		InventoryInWarehouses.ProductsAndServices AS ProductsAndServices,
	|		InventoryInWarehouses.Characteristic AS Characteristic,
	|		InventoryInWarehouses.Batch AS Batch,
	|		InventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|		InventoryInWarehouses.Cell AS Cell,
	|		InventoryInWarehouses.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.InventoryInWarehouses.Balance(
	|				,
	|				Company = &Company
	|					AND StructuralUnit = &StructuralUnit
	|					AND Cell = &Cell) AS InventoryInWarehouses
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryInWarehouses.Company,
	|		DocumentRegisterRecordsInventoryInWarehouses.ProductsAndServices,
	|		DocumentRegisterRecordsInventoryInWarehouses.Characteristic,
	|		DocumentRegisterRecordsInventoryInWarehouses.Batch,
	|		DocumentRegisterRecordsInventoryInWarehouses.StructuralUnit,
	|		DocumentRegisterRecordsInventoryInWarehouses.Cell,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryInWarehouses.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryInWarehouses.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryInWarehouses AS DocumentRegisterRecordsInventoryInWarehouses
	|	WHERE
	|		DocumentRegisterRecordsInventoryInWarehouses.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryInWarehouses.Period <= &Period
	|		AND DocumentRegisterRecordsInventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryInWarehousesOfBalance
	|WHERE
	|	InventoryInWarehousesOfBalance.QuantityBalance > 0
	|
	|GROUP BY
	|	InventoryInWarehousesOfBalance.Company,
	|	InventoryInWarehousesOfBalance.ProductsAndServices,
	|	InventoryInWarehousesOfBalance.Characteristic,
	|	InventoryInWarehousesOfBalance.Batch,
	|	InventoryInWarehousesOfBalance.StructuralUnit,
	|	InventoryInWarehousesOfBalance.Cell,
	|	InventoryInWarehousesOfBalance.ProductsAndServices.MeasurementUnit";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	Query.SetParameter("Cell", Cell);
	
	Inventory.Load(Query.Execute().Unload());
	
EndProcedure // FillInventoryByInventoryBalances()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByPurchaseInvoice(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS CashCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.Cell,
	|	DocumentTable.Inventory.(
	|		Ref,
	|		LineNumber,
	|		ProductsAndServices,
	|		Characteristic,
	|		Batch,
	|		MeasurementUnit,
	|		Quantity,
	|		Price,
	|		Amount,
	|		VATRate,
	|		VATAmount,
	|		Inventory.Order,
	|		Total,
	|		Cost,
	|		AmountExpenses,
	|		Content,
	|		SerialNumbers,
	|		ConnectionKey
	|	)
	|FROM
	|	Document.SupplierInvoice AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	FillPropertyValues(ThisObject, Selection);
	
	Inventory.Load(Selection.Inventory.Unload());
	
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData);
	
EndProcedure // FillBySupplierInvoice()

// Procedure fills out the Quantity column according to reserves to be ordered.
//
Procedure FillColumnReserveByReserves() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	CASE
	|		WHEN &OrderInHeader
	|			THEN &Order
	|		ELSE CASE
	|				WHEN TableInventory.CustomerOrder REFS Document.CustomerOrder
	|						AND TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|					THEN TableInventory.CustomerOrder
	|				ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|			END
	|	END AS CustomerOrder
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory";
	
	OrderInHeader = CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader;
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.SetParameter("OrderInHeader", OrderInHeader);
	Query.SetParameter("Order", ?(ValueIsFilled(CustomerOrder), CustomerOrder, Documents.CustomerOrder.EmptyRef()));
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.CustomerOrder AS CustomerOrder,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.CustomerOrder AS CustomerOrder,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.ProductsAndServices.InventoryGLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef))) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.CustomerOrder,
	|		DocumentRegisterRecordsInventory.ProductsAndServices,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|		AND DocumentRegisterRecordsInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.CustomerOrder,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		If Not OrderInHeader Then
			StructureForSearch.Insert("CustomerOrder", Selection.CustomerOrder);
		EndIf;
		StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory IN ArrayOfRowsInventory Do
			
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure // FillColumnReserveByReserves()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader Then
		
		For Each TabularSectionRow IN Inventory Do
			
			TabularSectionRow.CustomerOrder = CustomerOrder;
			
		EndDo;	
		
	EndIf;	
	
	If Not Constants.FunctionalOptionAccountingByMultipleBusinessActivities.Get() Then
		
		If GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses
			AND (OperationKind = Enums.OperationKindsInventoryTransfer.WriteOffToExpenses
			OR OperationKind = Enums.OperationKindsInventoryTransfer.TransferToOperation) Then
			
			BusinessActivity = Catalogs.BusinessActivities.MainActivity;
			
		EndIf;	
		
	EndIf;	
	
EndProcedure // BeforeWrite()

// IN the event handler of the FillingProcessor document
// - filling the document according to reconciliation of products at the place of storage.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.TransferBetweenCells") Then
		
		Query = New Query( 
		"SELECT
		|	TransferBetweenCells.Ref AS BasisDocument,
		|	VALUE(Enum.OperationKindsInventoryTransfer.Move) AS OperationKind,
		|	TransferBetweenCells.Company AS Company,
		|	TransferBetweenCells.StructuralUnit AS StructuralUnit,
		|	TransferBetweenCells.Cell AS Cell,
		|	CASE
		|		WHEN TransferBetweenCells.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
		|				OR TransferBetweenCells.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Department)
		|			THEN TransferBetweenCells.StructuralUnit.TransferRecipient
		|		ELSE VALUE(Catalog.StructuralUnits.EmptyRef)
		|	END AS StructuralUnitPayee,
		|	CASE
		|		WHEN TransferBetweenCells.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
		|				OR TransferBetweenCells.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Department)
		|			THEN TransferBetweenCells.StructuralUnit.TransferRecipientCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS CellPayee,
		|	TransferBetweenCells.Inventory.(
		|		ProductsAndServices AS ProductsAndServices,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity
		|	)
		|FROM
		|	Document.TransferBetweenCells AS TransferBetweenCells
		|WHERE
		|	TransferBetweenCells.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			Inventory.Load(QueryResultSelection.Inventory.Unload());
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.InventoryAssembly") 
		AND FillingData.OperationKind = Enums.OperationKindsInventoryAssembly.Assembly Then
		
		Query = New Query(
		"SELECT
		|	InventoryAssembly.Ref AS BasisDocument,
		|	VALUE(Enum.OperationKindsInventoryTransfer.Move) AS OperationKind,
		|	InventoryAssembly.Company AS Company,
		|	InventoryAssembly.CustomerOrder AS CustomerOrder,
		|	InventoryAssembly.ProductsStructuralUnit AS StructuralUnit,
		|	InventoryAssembly.ProductsCell AS Cell,
		|	CASE
		|		WHEN InventoryAssembly.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
		|				OR InventoryAssembly.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Department)
		|			THEN InventoryAssembly.ProductsStructuralUnit.TransferRecipient
		|		ELSE VALUE(Catalog.StructuralUnits.EmptyRef)
		|	END AS StructuralUnitPayee,
		|	CASE
		|		WHEN InventoryAssembly.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
		|				OR InventoryAssembly.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Department)
		|			THEN InventoryAssembly.ProductsStructuralUnit.TransferRecipientCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS CellPayee,
		|	InventoryAssembly.Products.(
		|		ProductsAndServices AS ProductsAndServices,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Ref.CustomerOrder AS CustomerOrder,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity,
		|		CASE
		|			WHEN InventoryAssembly.Products.Ref.CustomerOrder = VALUE(Document.CustomerOrder.EmptyRef)
		|				THEN 0
		|			ELSE InventoryAssembly.Products.Quantity
		|		END AS Reserve
		|	)
		|FROM
		|	Document.InventoryAssembly AS InventoryAssembly
		|WHERE
		|	InventoryAssembly.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionProducts = QueryResultSelection.Products.Select();
			While SelectionProducts.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionProducts);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.InventoryAssembly")
		AND FillingData.OperationKind = Enums.OperationKindsInventoryAssembly.Disassembly Then
		
		Query = New Query(
		"SELECT
		|	InventoryAssembly.Ref AS BasisDocument,
		|	VALUE(Enum.OperationKindsInventoryTransfer.Move) AS OperationKind,
		|	InventoryAssembly.Company AS Company,
		|	InventoryAssembly.CustomerOrder AS CustomerOrder,
		|	InventoryAssembly.ProductsStructuralUnit AS StructuralUnit,
		|	InventoryAssembly.ProductsCell AS Cell,
		|	CASE
		|		WHEN InventoryAssembly.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
		|				OR InventoryAssembly.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Department)
		|			THEN InventoryAssembly.ProductsStructuralUnit.TransferRecipient
		|		ELSE VALUE(Catalog.StructuralUnits.EmptyRef)
		|	END AS StructuralUnitPayee,
		|	CASE
		|		WHEN InventoryAssembly.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
		|				OR InventoryAssembly.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Department)
		|			THEN InventoryAssembly.ProductsStructuralUnit.TransferRecipientCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS CellPayee,
		|	InventoryAssembly.Inventory.(
		|		ProductsAndServices AS ProductsAndServices,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Quantity AS Quantity,
		|		CASE
		|			WHEN InventoryAssembly.Inventory.Ref.CustomerOrder = VALUE(Document.CustomerOrder.EmptyRef)
		|				THEN 0
		|			ELSE InventoryAssembly.Inventory.Quantity
		|		END AS Reserve,
		|		MeasurementUnit AS MeasurementUnit,
		|		Ref.CustomerOrder AS CustomerOrder
		|	)
		|FROM
		|	Document.InventoryAssembly AS InventoryAssembly
		|WHERE
		|	InventoryAssembly.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionInventory = QueryResultSelection.Inventory.Select();
			While SelectionInventory.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionInventory);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder")
		AND FillingData.OperationKind = Enums.OperationKindsProductionOrder.Assembly Then
		
		Query = New Query( 
		"SELECT
		|	ProductionOrder.Ref AS BasisDocument,
		|	ProductionOrder.StructuralUnit AS StructuralUnitPayee,
		|	ProductionOrder.Company AS Company,
		|	VALUE(Enum.OperationKindsInventoryTransfer.Move) AS OperationKind,
		|	ProductionOrder.CustomerOrder AS CustomerOrder,
		|	CASE
		|		WHEN ProductionOrder.StructuralUnitReserve.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
		|				OR ProductionOrder.StructuralUnitReserve.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Department)
		|			THEN ProductionOrder.StructuralUnitReserve
		|		ELSE VALUE(Catalog.StructuralUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	CASE
		|		WHEN ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
		|				OR ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Department)
		|			THEN ProductionOrder.StructuralUnit.TransferSourceCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS Cell,
		|	ProductionOrder.Inventory.(
		|		ProductsAndServices AS ProductsAndServices,
		|		Characteristic AS Characteristic,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity,
		|		Reserve AS Reserve,
		|		Ref.CustomerOrder AS CustomerOrder
		|	)
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|WHERE
		|	ProductionOrder.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionInventory = QueryResultSelection.Inventory.Select();
			While SelectionInventory.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionInventory);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") 
		AND FillingData.OperationKind = Enums.OperationKindsProductionOrder.Disassembly Then
		
		Query = New Query(
		"SELECT
		|	ProductionOrder.Ref AS BasisDocument,
		|	ProductionOrder.StructuralUnit AS StructuralUnitPayee,
		|	ProductionOrder.Company AS Company,
		|	VALUE(Enum.OperationKindsInventoryTransfer.Move) AS OperationKind,
		|	ProductionOrder.Ref.CustomerOrder AS CustomerOrder,
		|	CASE
		|		WHEN ProductionOrder.StructuralUnitReserve.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
		|				OR ProductionOrder.StructuralUnitReserve.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Department)
		|			THEN ProductionOrder.StructuralUnitReserve
		|		ELSE VALUE(Catalog.StructuralUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	CASE
		|		WHEN ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
		|				OR ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Department)
		|			THEN ProductionOrder.StructuralUnit.TransferSourceCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS Cell,
		|	ProductionOrder.Products.(
		|		ProductsAndServices AS ProductsAndServices,
		|		Characteristic AS Characteristic,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity,
		|		Reserve AS Reserve,
		|		Ref.CustomerOrder AS CustomerOrder
		|	)
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|WHERE
		|	ProductionOrder.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionProducts = QueryResultSelection.Products.Select();
			While SelectionProducts.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionProducts);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.GoodsReceipt") Then
		
		Company = FillingData.Company;
		OperationKind = Enums.OperationKindsInventoryTransfer.Move;
		ThisObject.BasisDocument = FillingData.Ref;
		StructuralUnitPayee = FillingData.StructuralUnit;
		CellPayee = FillingData.Cell;
		
		Inventory.Clear();
		For Each CurStringInventory IN FillingData.Inventory Do
			
			NewRow = Inventory.Add();
			NewRow.MeasurementUnit = CurStringInventory.MeasurementUnit;
			NewRow.Quantity = CurStringInventory.Quantity;
			NewRow.ProductsAndServices = CurStringInventory.ProductsAndServices;
			NewRow.Batch = CurStringInventory.Batch;
			NewRow.Characteristic = CurStringInventory.Characteristic;
			
		EndDo;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then	
		
		FillByPurchaseInvoice(FillingData);
		
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Check existence of retail prices.
	CheckExistenceOfRetailPrice(Cancel);
	
	If Inventory.Count() = 0 Then
		Return;
	EndIf;
	
	If OperationKind = Enums.OperationKindsInventoryTransfer.TransferToOperation
	 OR OperationKind = Enums.OperationKindsInventoryTransfer.WriteOffToExpenses Then
		CheckedAttributes.Add("GLExpenseAccount");
	EndIf;
	
	If CustomerOrderPosition = Enums.AttributePositionOnForm.InTabularSection Then
		
		For Each StringInventory IN Inventory Do
			
			If Not ValueIsFilled(StringInventory.CustomerOrder) AND StringInventory.Reserve > 0 Then
				
				SmallBusinessServer.ShowMessageAboutError(ThisObject, 
				"The row contains reserve quantity, but order is not specified.",
				"Inventory",
				StringInventory.LineNumber,
				"Reserve",
				Cancel);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader Then
		
		For Each StringInventory IN Inventory Do
			
			If Not ValueIsFilled(CustomerOrder) AND StringInventory.Reserve > 0 Then
				
				SmallBusinessServer.ShowMessageAboutError(ThisObject, 
				"The row contains reserve quantity, but order is not specified.",
				"Inventory",
				StringInventory.LineNumber,
				"Reserve",
				Cancel);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Constants.FunctionalOptionInventoryReservation.Get() 
		AND (OperationKind = Enums.OperationKindsInventoryTransfer.Move
		OR OperationKind = Enums.OperationKindsInventoryTransfer.WriteOffToExpenses) Then
		
		For Each StringInventory IN Inventory Do
			
			If StringInventory.Reserve > StringInventory.Quantity Then
				
				MessageText = NStr("en='In row No. %Number% of the ""Inventory"" tabular section, the quantity of items transferred to reserve exceeds the total inventory quantity.';ru='В строке №%Номер% табл. части ""Запасы"" количество передаваемых в резерв позиций превышает общее количество запасов.'");
				MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Reserve",
					Cancel
				);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.InventoryTransfer.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectInventoryForExpenseFromWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryForWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectRetailAmountAccounting(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);

	// SerialNumbers
	SmallBusinessServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);

	// Control
	Documents.InventoryTransfer.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);

	// Control
	Documents.InventoryTransfer.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndIf