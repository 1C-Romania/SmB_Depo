#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefPurchaseOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text = 	
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.ProductsAndServices,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Ref", DocumentRefPurchaseOrder);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();

	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("ProductsAndServices", RowTableInventory.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredReserve = RowTableInventory.Quantity;
		
		If QuantityRequiredReserve > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredReserve Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredReserve / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredReserve;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredReserve Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
	
			// Expense.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredReserve;
			TableRowExpense.CustomerOrder = Undefined;
			
			// Receipt
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 OR QuantityRequiredReserve > 0 Then
				
				TableRowReceipt = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.CustomerCorrOrder = Undefined;
					
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = QuantityRequiredReserve;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.RecordKindManagerial = AccountingRecordType.Debit;
					
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure // GenerateInventoryTable()

// Payment calendar table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.PaymentReceiptPlan - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefPurchaseOrder, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefPurchaseOrder);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.PayDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.CashAssetsType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	DocumentTable.Ref AS InvoiceForPayment,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	CASE
	|		WHEN DocumentTable.Ref.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.Ref.PettyCash
	|		WHEN DocumentTable.Ref.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN DocumentTable.Ref.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	CASE
	|		WHEN DocumentTable.Ref.Contract.SettlementsInStandardUnits
	|			THEN DocumentTable.Ref.Contract.SettlementsCurrency
	|		ELSE DocumentTable.Ref.DocumentCurrency
	|	END AS Currency,
	|	CASE
	|		WHEN DocumentTable.Ref.Contract.SettlementsInStandardUnits
	|			THEN CAST(-DocumentTable.PaymentAmount * CASE
	|						WHEN SettlementsCurrencyRates.ExchangeRate <> 0
	|								AND CurrencyRatesOfDocument.Multiplicity <> 0
	|							THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
	|						ELSE 1
	|					END AS NUMBER(15, 2))
	|		ELSE -DocumentTable.PaymentAmount
	|	END AS Amount
	|FROM
	|	Document.PurchaseOrder.PaymentCalendar AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS SettlementsCurrencyRates
	|		ON DocumentTable.Ref.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfDocument
	|		ON DocumentTable.Ref.DocumentCurrency = CurrencyRatesOfDocument.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND Not DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|	AND Not(DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND DocumentTable.Ref.Closed)";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure // GenerateTablePaymentCalendar()

// Generating procedure for the table of invoices for payment.
//
// Parameters:
// DocumentRef - DocumentRef.PaymentReceiptPlan - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefPurchaseOrder, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefPurchaseOrder);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref AS InvoiceForPayment,
	|	DocumentTable.DocumentAmount AS Amount
	|FROM
	|	Document.PurchaseOrder AS DocumentTable
	|WHERE
	|	DocumentTable.Counterparty.TrackPaymentsByBills
	|	AND DocumentTable.Ref = &Ref
	|	AND (NOT DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open))
	|	AND (NOT(DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND DocumentTable.Ref.Closed))";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure // GenerateTableInvoicesAndOrdersPayment()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
Procedure InitializeDocumentData(DocumentRefPurchaseOrder, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	PurchaseOrderInventory.Ref AS PurchaseOrder,
	|	PurchaseOrderInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PurchaseOrderInventory.Quantity
	|		ELSE PurchaseOrderInventory.Quantity * PurchaseOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	PurchaseOrderInventory.ReceiptDate AS ReceiptDate
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|WHERE
	|	PurchaseOrderInventory.Ref = &Ref
	|	AND (PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND PurchaseOrderInventory.Ref.Closed = FALSE
	|			OR PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderMaterials.LineNumber AS LineNumber,
	|	PurchaseOrderMaterials.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	CASE
	|		WHEN Constants.FunctionalOptionInventoryReservation
	|			THEN PurchaseOrderMaterials.Ref.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS CustomerOrder,
	|	PurchaseOrderMaterials.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderMaterials.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PurchaseOrderMaterials.Quantity
	|		ELSE PurchaseOrderMaterials.Quantity * PurchaseOrderMaterials.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.PurchaseOrder.Materials AS PurchaseOrderMaterials,
	|	Constants AS Constants
	|WHERE
	|	PurchaseOrderMaterials.Ref = &Ref
	|	AND PurchaseOrderMaterials.Ref.OperationKind = VALUE(Enum.OperationKindsPurchaseOrder.OrderForProcessing)
	|	AND (PurchaseOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND PurchaseOrderMaterials.Ref.Closed = FALSE
	|			OR PurchaseOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.ReceiptDate AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	PurchaseOrderInventory.Ref AS Order,
	|	PurchaseOrderInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PurchaseOrderInventory.Quantity
	|		ELSE PurchaseOrderInventory.Quantity * PurchaseOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|WHERE
	|	PurchaseOrderInventory.Ref = &Ref
	|	AND (PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND PurchaseOrderInventory.Ref.Closed = FALSE
	|			OR PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	PurchaseOrderInventory.LineNumber,
	|	PurchaseOrderInventory.ShipmentDate,
	|	&Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment),
	|	UNDEFINED,
	|	PurchaseOrderInventory.ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PurchaseOrderInventory.Quantity
	|		ELSE PurchaseOrderInventory.Quantity * PurchaseOrderInventory.MeasurementUnit.Factor
	|	END
	|FROM
	|	Document.PurchaseOrder.Materials AS PurchaseOrderInventory
	|WHERE
	|	PurchaseOrderInventory.Ref = &Ref
	|	AND PurchaseOrderInventory.Ref.OperationKind = VALUE(Enum.OperationKindsPurchaseOrder.OrderForProcessing)
	|	AND (PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND PurchaseOrderInventory.Ref.Closed = FALSE
	|			OR PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	CASE
	|		WHEN Constants.FunctionalOptionInventoryReservation
	|			THEN PurchaseOrderInventory.Ref.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS CustomerOrder,
	|	PurchaseOrderInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	PurchaseOrderInventory.Ref AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PurchaseOrderInventory.Quantity
	|		ELSE PurchaseOrderInventory.Quantity * PurchaseOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory,
	|	Constants AS Constants
	|WHERE
	|	PurchaseOrderInventory.Ref = &Ref
	|	AND PurchaseOrderInventory.Ref.CustomerOrder <> VALUE(Document.CustomerOrder.Emptyref)
	|	AND Constants.FunctionalOptionInventoryReservation
	|	AND (PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND PurchaseOrderInventory.Ref.Closed = FALSE
	|			OR PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	PurchaseOrderInventory.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderMaterials.LineNumber AS LineNumber,
	|	PurchaseOrderMaterials.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	PurchaseOrderMaterials.Ref.StructuralUnitReserve AS StructuralUnit,
	|	PurchaseOrderMaterials.ProductsAndServices.InventoryGLAccount AS GLAccount,
	|	PurchaseOrderMaterials.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsAndServicesBatches.EmptyRef) AS Batch,
	|	VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder,
	|	CASE
	|		WHEN Constants.FunctionalOptionInventoryReservation
	|			THEN PurchaseOrderMaterials.Ref.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderMaterials.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PurchaseOrderMaterials.Reserve
	|		ELSE PurchaseOrderMaterials.Reserve * PurchaseOrderMaterials.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindManagerial,
	|	&InventoryReservation AS ContentOfAccountingRecord
	|INTO TemporaryTableInventory
	|FROM
	|	Document.PurchaseOrder.Materials AS PurchaseOrderMaterials,
	|	Constants AS Constants
	|WHERE
	|	PurchaseOrderMaterials.Ref = &Ref
	|	AND PurchaseOrderMaterials.Reserve > 0
	|	AND (PurchaseOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND PurchaseOrderMaterials.Ref.Closed = FALSE
	|			OR PurchaseOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.GLAccount AS CorrGLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.ProductsAndServices AS ProductsAndServicesCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Characteristic AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Batch AS BatchCorr,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	TableInventory.RecordKindManagerial AS RecordKindManagerial,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.RecordKindManagerial";

	Query.SetParameter("Ref", DocumentRefPurchaseOrder);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("InventoryReservation", NStr("en = 'Inventory reservation'"));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchaseOrders", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryTransferSchedule", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableOrdersPlacement", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[5].Unload());
	
	GenerateTableInventory(DocumentRefPurchaseOrder, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefPurchaseOrder, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefPurchaseOrder, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefPurchaseOrder, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsPurchaseOrdersChange", "RegisterRecordsInventoryChange",
	// "RegisterRecordsInventoryDemandChange" contain records, control purchse order.
	
	If StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange
		OR StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsInventoryDemandChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryChange.GLAccount AS GLAccountPresentation,
		|	RegisterRecordsInventoryChange.ProductsAndServices AS ProductsAndServicesPresentation,
		|	RegisterRecordsInventoryChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryChange.CustomerOrder AS CustomerOrderPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryBalances.ProductsAndServices.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		INNER JOIN AccumulationRegister.Inventory.Balance(&ControlTime, ) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.GLAccount = InventoryBalances.GLAccount
		|			AND RegisterRecordsInventoryChange.ProductsAndServices = InventoryBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.CustomerOrder = InventoryBalances.CustomerOrder
		|			AND (ISNULL(InventoryBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPurchaseOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsPurchaseOrdersChange.Company AS CompanyPresentation,
		|	RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS PurchaseOrderPresentation,
		|	RegisterRecordsPurchaseOrdersChange.ProductsAndServices AS ProductsAndServicesPresentation,
		|	RegisterRecordsPurchaseOrdersChange.Characteristic AS CharacteristicPresentation,
		|	PurchaseOrdersBalances.ProductsAndServices.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsPurchaseOrdersChange.QuantityChange, 0) + ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS BalancePurchaseOrders,
		|	ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS QuantityBalancePurchaseOrders
		|FROM
		|	RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange
		|		INNER JOIN AccumulationRegister.PurchaseOrders.Balance(&ControlTime, ) AS PurchaseOrdersBalances
		|		ON RegisterRecordsPurchaseOrdersChange.Company = PurchaseOrdersBalances.Company
		|			AND RegisterRecordsPurchaseOrdersChange.PurchaseOrder = PurchaseOrdersBalances.PurchaseOrder
		|			AND RegisterRecordsPurchaseOrdersChange.ProductsAndServices = PurchaseOrdersBalances.ProductsAndServices
		|			AND RegisterRecordsPurchaseOrdersChange.Characteristic = PurchaseOrdersBalances.Characteristic
		|			AND (ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryDemandChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryDemandChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryDemandChange.MovementType AS MovementTypePresentation,
		|	RegisterRecordsInventoryDemandChange.CustomerOrder AS CustomerOrderPresentation,
		|	RegisterRecordsInventoryDemandChange.ProductsAndServices AS ProductsAndServicesPresentation,
		|	RegisterRecordsInventoryDemandChange.Characteristic AS CharacteristicPresentation,
		|	InventoryDemandBalances.ProductsAndServices.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryDemandChange.QuantityChange, 0) + ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS BalanceInventoryDemand,
		|	ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS QuantityBalanceInventoryDemand
		|FROM
		|	RegisterRecordsInventoryDemandChange AS RegisterRecordsInventoryDemandChange
		|		INNER JOIN AccumulationRegister.InventoryDemand.Balance(&ControlTime, ) AS InventoryDemandBalances
		|		ON RegisterRecordsInventoryDemandChange.Company = InventoryDemandBalances.Company
		|			AND RegisterRecordsInventoryDemandChange.MovementType = InventoryDemandBalances.MovementType
		|			AND RegisterRecordsInventoryDemandChange.CustomerOrder = InventoryDemandBalances.CustomerOrder
		|			AND RegisterRecordsInventoryDemandChange.ProductsAndServices = InventoryDemandBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryDemandChange.Characteristic = InventoryDemandBalances.Characteristic
		|			AND (ISNULL(InventoryDemandBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty() Then
			DocumentObjectPurchaseOrder = DocumentRefPurchaseOrder.GetObject()
		EndIf;
		
		// Negative balance of inventory and cost accounting.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectPurchaseOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the order to the vendor.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectPurchaseOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for inventory.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocumentObjectPurchaseOrder, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// FILLING PROCEDURES

// Checks the possibility of input on the basis.
//
Procedure CheckEnteringAbilityOnTheBasisOfVendorOrder(FillingData, AttributeValues) Export
	
	If AttributeValues.Property("Posted") Then
		If Not AttributeValues.Posted Then
			ErrorText = NStr("en='Document %Document% is not processed. Entry according to the unposted document is prohibited.'");
			ErrorText = StrReplace(ErrorText, "%Document%", FillingData);
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("Closed") Then
		If AttributeValues.Closed Then
			ErrorText = NStr("en='Document %Document% is closed (completed). Entry on the basis of the closed order is completed.'");
			ErrorText = StrReplace(ErrorText, "%Document%", FillingData);
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("OrderState") Then
		If AttributeValues.OrderState.OrderStatus = Enums.OrderStatuses.Open Then
			ErrorText = NStr("en='Document %Document% in state %OrderState%. Input on the basis is forbidden.'");
			ErrorText = StrReplace(ErrorText, "%Document%", FillingData);
			ErrorText = StrReplace(ErrorText, "%OrderState%", AttributeValues.OrderState);
			Raise ErrorText;
		EndIf;
	EndIf;
	
EndProcedure // CheckPossibilityToOutputBasedOnPurchseOrder()

#Region  DataLoadFromFile

Procedure SetImportParametersFromFileToTP(ExportParameters) Export
	
EndProcedure

// Returns the list of suitable IB objects for the ambiguous cell value.
// 
// Parameters:
//   TabularSectionFullName  - String - tabular section full name, data is imported manually.
//  ColumnName                - String - name of the column where the
// AmbiguitiesList ambiguity appeared    - ValueTable - List for filling with
//     ambiguous data * Identifier        - Number  - String unique
//     identifier * Column              - String -  Name of column with the
// ImportedValueString ambiguity - String - Imported data on the basis of which ambiguity appeared.
//
Procedure FillAmbiguitiesList(TabularSectionFullName, AmbiguitiesList, ColumnName, ImportedValueString) Export 
	
	If ColumnName = "ProductsAndServices" Then
		
		Query = New Query;
		Query.Text = "SELECT
		               |	ProductsAndServices.Ref
		               |FROM
		               |	Catalog.ProductsAndServices AS ProductsAndServices
		               |WHERE
		               |	ProductsAndServices.ProductsAndServicesType = &ProductsAndServicesType AND ProductsAndServices.Description = &Description
		               |	";
		
		If ValueIsFilled(ImportedValueString.SKU) Then 
			Query.Text = Query.Text + " OR ProductsAndServices.SKU = &SKU";
			Query.SetParameter("SKU", ImportedValueString.SKU);
		EndIf;
		
		If TabularSectionFullName = "Document.SupplierInvoice.TabularSection.Expenses" Then
			Query.SetParameter("Description", ImportedValueString.Service);
			Query.SetParameter("ProductsAndServicesType", Enums.ProductsAndServicesTypes.Service);
		Else
			Query.SetParameter("Description", ImportedValueString.ProductsAndServices);
			Query.SetParameter("ProductsAndServicesType", Enums.ProductsAndServicesTypes.InventoryItem);
		EndIf;
		
		QueryResult = Query.Execute();
		SelectionDetailRecords = QueryResult.Select();
		While SelectionDetailRecords.Next() Do
			AmbiguitiesList.Add(SelectionDetailRecords.Ref);
		EndDo;
	EndIf;
	
EndProcedure

// Matches data imported to the TabularSectionFullName
// tabular section to IB data and fills in parameters MatchTableAddress and AmbiguitiesList.
//
// Parameters:
//   TabularSectionFullName   - String - tabular section full name, data is imported manually.
//   ImportedDataAddress    - String - temporary storage address with values table
// 								      where data imported from file is located. Column content:
//     * Identifier - Number - String order number;
//     * the remaining columns correspond to the LoadFromFile layout columns.
//   MatchTableAddress - String - address of the temporary storage with
// 								      an empty values table that is
// a document tabular section copy that should be filled in from the ImportedDataAddress table.
//   AmbiguitiesList - ValueTable - list of ambiguous values for which there are several suitable options in IB.
//    IN the last request result the column is absent       - String - column name where ambiguity was found;
//    * Identifier - Number  - String ID where ambiguity was found.
//
Procedure MatchImportedData(ImportedDataAddress, MatchTableAddress, AmbiguitiesList, TabularSectionFullName) Export
	
	ExportableData = GetFromTempStorage(ImportedDataAddress);
	MappingTable = GetFromTempStorage(MatchTableAddress);
	
	MatchImportedDataIventory(ExportableData, AmbiguitiesList, MappingTable);
	
	PutToTempStorage(MappingTable, MatchTableAddress);
	
EndProcedure

Procedure MatchImportedDataIventory(ExportableData, AmbiguitiesList, MappingTable)
	
	Var MeasurementUnit, AmbiguityRecord, Query, QueryResult, ImportedDataRow, StringProductsAndServices, Product, Filter;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Products.ProductsAndServices AS Description,
	|	Products.SKU,
	|	Products.ID
	|INTO Products
	|FROM
	|	&Products AS Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServices.Ref,
	|	ProductsAndServices.SKU,
	|	ProductsAndServices.Code,
	|	Products.ID
	|INTO ProductsAndServicesSKU
	|FROM
	|	Products AS Products
	|		LEFT JOIN Catalog.ProductsAndServices AS ProductsAndServices
	|		ON (ProductsAndServices.SKU LIKE Products.SKU)
	|			AND (NOT Products.SKU LIKE """" )
	|WHERE
	|	Not ProductsAndServices.Ref IS NULL AND ProductsAndServices.ProductsAndServicesType = &ProductsAndServicesType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServices.Ref AS Ref,
	|	Products.ID
	|FROM
	|	Catalog.ProductsAndServices AS ProductsAndServices
	|		INNER JOIN Products AS Products
	|		ON ProductsAndServices.Description LIKE Products.Description
	|WHERE ProductsAndServices.ProductsAndServicesType = &ProductsAndServicesType AND 
	|	Not ProductsAndServices.Ref In
	|				(SELECT
	|					ProductsAndServicesSKU.Ref
	|				FROM
	|					ProductsAndServicesSKU)
	|
	|GROUP BY
	|	ProductsAndServices.Ref,
	|	Products.ID
	|
	|UNION ALL
	|
	|SELECT
	|	ProductsAndServicesSKU.Ref,
	|	ProductsAndServicesSKU.ID
	|FROM
	|	ProductsAndServicesSKU AS ProductsAndServicesSKU
	|
	|GROUP BY
	|	ProductsAndServicesSKU.Ref, ProductsAndServicesSKU.ID";
	
	Query.SetParameter("Products", ExportableData);
	Query.SetParameter("ProductsAndServicesType", Enums.ProductsAndServicesTypes.InventoryItem);
	
	QueryResult = Query.Execute().Unload();
	
	For Each ImportedDataRow IN ExportableData Do
		
		Product = MappingTable.Add();
		Product.Quantity = ImportedDataRow.Quantity;
		Product.Price = ImportedDataRow.Price;
		Product.Amount = Product.Quantity * Product.Price;
		Product.ID = ImportedDataRow.ID;
		
		If GetFunctionalOption("UseCharacteristics") Then
			
			If ValueIsFilled(ImportedDataRow.Characteristic) Then
				Product.Characteristic = Catalogs.ProductsAndServicesCharacteristics.FindByDescription(ImportedDataRow.Characteristic);
			EndIf;
			
		EndIf;
		
		If GetFunctionalOption("AccountingInVariousUOM") Then
			
			MeasurementUnit = Catalogs.UOM.FindByDescription(ImportedDataRow.MeasurementUnit);
			
			If MeasurementUnit.IsEmpty() Then
				MeasurementUnit = Catalogs.UOMClassifier.FindByDescription(ImportedDataRow.MeasurementUnit);
			EndIf;
			
			Product.MeasurementUnit = MeasurementUnit;
			
		EndIf;
		
		VATRate = TrimAll(ImportedDataRow.VATRate);
		If ValueIsFilled(ImportedDataRow.VATRate) Then
			If Left(VATRate, 1) = "0" Then
				VATRate = StrReplace(VATRate, ".", ",");
				If VATRate = "0,18" Then
					Product.VATRate = Catalogs.VATRates.FindByDescription("18%", False);
				ElsIf VATRate = "0,10" OR VATRate = "0,1" Then
					Product.VATRate = Catalogs.VATRates.FindByDescription("10%", False);
				Else
					Product.VATRate = Catalogs.VATRates.FindByDescription(ImportedDataRow.VATRate, False);
				EndIf;
			Else
				Product.VATRate = Catalogs.VATRates.FindByDescription(ImportedDataRow.VATRate, False);
			EndIf;
		EndIf;
		
		Filter = New Structure( "ID", ImportedDataRow.ID);
		StringProductsAndServices = QueryResult.FindRows(Filter);
		If StringProductsAndServices.Count() = 1 Then 
			Product.ProductsAndServices = StringProductsAndServices[0].Ref;
		ElsIf StringProductsAndServices.Count() > 1 Then 
			AmbiguityRecord = AmbiguitiesList.Add();
			AmbiguityRecord.ID = StringProductsAndServices[0].ID;
			AmbiguityRecord.Column = "ProductsAndServices";
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion


#Region DataImportFromExternalSources

Procedure DataImportFieldsFromExternalSource(ImportFieldsTable, FillingObjectFullName) Export
	
	//
	// The group of fields complies with rule: at least one field in the group must be selected in columns
	//
	
	TypeDescriptionString25 = New TypeDescription("String", , , , New StringQualifiers(25));
	TypeDescriptionString50 = New TypeDescription("String", , , , New StringQualifiers(50));
	TypeDescriptionString100 = New TypeDescription("String", , , , New StringQualifiers(100));
	TypeDescriptionString150 = New TypeDescription("String", , , , New StringQualifiers(150));
	TypeDescriptionString200 = New TypeDescription("String", , , , New StringQualifiers(200));
	TypeDescriptionNumber15_2 = New TypeDescription("Number", , , , New NumberQualifiers(15, 2, AllowedSign.Nonnegative));
	TypeDescriptionNumber15_3 = New TypeDescription("Number", , , , New NumberQualifiers(15, 3, AllowedSign.Nonnegative));
	TypeDescriptionDate = New TypeDescription("Date", , , , New DateQualifiers(DateFractions.Date));
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsAndServices");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Barcode", "Barcode", TypeDescriptionString200, TypeDescriptionColumn, "ProductsAndServices", 1, , True);
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "SKU", "SKU", TypeDescriptionString25, TypeDescriptionColumn, "ProductsAndServices", 2, , True);
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsAndServicesDescription", "Products and services (name)", TypeDescriptionString100, TypeDescriptionColumn, "ProductsAndServices", 3, , True);
	
	If GetFunctionalOption("UseCharacteristics") Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsAndServicesCharacteristics");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Characteristic", "Characteristic (name)", TypeDescriptionString150, TypeDescriptionColumn);
		
	EndIf;
	
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Quantity", "Quantity", TypeDescriptionString25, TypeDescriptionNumber15_3, , , True);
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "MeasurementUnit", "Unit of Measure", TypeDescriptionString25, TypeDescriptionColumn, , , , , GetFunctionalOption("AccountingInVariousUOM"));
	
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Price", "Price", TypeDescriptionString25, TypeDescriptionNumber15_2, , , True);
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.VATRates");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "VATRate", "VAT rate", TypeDescriptionString50, TypeDescriptionColumn);
	
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "VATAmount", "VAT amount", TypeDescriptionString25, TypeDescriptionNumber15_2);
	
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ReceiptDate", "Receipt date", TypeDescriptionString25, TypeDescriptionDate);
	
	TypeArray = New Array;
	TypeArray.Add(Type("DocumentRef.CustomerOrder"));
	TypeArray.Add(Type("DocumentRef.PurchaseOrder"));
	
	TypeDescriptionColumn = New TypeDescription(TypeArray);
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Order", "Order (customer/vendor)", TypeDescriptionString50, TypeDescriptionColumn);
	
EndProcedure

Procedure OnDefineDataImportSamples(DataLoadSettings, UUID) Export
	
	Sample_xlsx = GetTemplate("DataImportTemplate_xlsx");
	DataImportTemplate_xlsx = PutToTempStorage(Sample_xlsx, UUID);
	DataLoadSettings.Insert("DataImportTemplate_xlsx", DataImportTemplate_xlsx);
	
	DataLoadSettings.Insert("DataImportTemplate_mxl", "DataImportTemplate_mxl");
	
	Sample_csv = GetTemplate("DataImportTemplate_csv");
	DataImportTemplate_csv = PutToTempStorage(Sample_csv, UUID);
	DataLoadSettings.Insert("DataImportTemplate_csv", DataImportTemplate_csv);
	
EndProcedure

Procedure MatchImportedDataFromExternalSource(DataMatchingTable, AdditionalParameters) Export
	
	FillingObjectFullName = AdditionalParameters.DataLoadSettings.FillingObjectFullName;
	
	// DataMatchingTable - Type FormDataCollection
	For Each FormTableRow IN DataMatchingTable Do
		
		// Products and services by Barcode, SKU, Description
		DataImportFromExternalSourcesOverridable.CompareProductsAndServices(FormTableRow.ProductsAndServices, FormTableRow.Barcode, FormTableRow.SKU, FormTableRow.ProductsAndServicesDescription);
		
		If GetFunctionalOption("UseCharacteristics") Then
			
			If ValueIsFilled(FormTableRow.ProductsAndServices) Then
				
				// Characteristic by Owner and Name
				DataImportFromExternalSourcesOverridable.MapCharacteristic(FormTableRow.Characteristic, FormTableRow.ProductsAndServices, FormTableRow.Barcode, FormTableRow.Characteristic_IncomingData);
				
			EndIf;
			
		EndIf;
		
		// Quantity
		DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.Quantity, FormTableRow.Quantity_IncomingData, 1);
		
		// MeasurementUnits by Description (also consider the option to bind user MU)
		DefaultValue = ?(ValueIsFilled(FormTableRow.ProductsAndServices), FormTableRow.ProductsAndServices.MeasurementUnit, Catalogs.UOMClassifier.pcs);
		DataImportFromExternalSourcesOverridable.MapUOM(FormTableRow.ProductsAndServices, FormTableRow.MeasurementUnit, FormTableRow.MeasurementUnit_IncomingData, DefaultValue);
		
		// Price
		DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.Price, FormTableRow.Price_IncomingData, 1);
		
		// VATRate
		//by name DefaultValue = ?(ValueFilled(FormTableString.ProductsAnsServices), FormTableString.ProductsAnsServices.VATRate, Catalogs.Companies.MainCompany.DefaultVATRate);
		DataImportFromExternalSourcesOverridable.MapVATRate(FormTableRow.VATRate, FormTableRow.VATRate_IncomingData, Undefined);
		
		// VATAmount
		DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.VATAmount, FormTableRow.VATAmount_IncomingData, 0);
		
		// ReceiptDate
		DataImportFromExternalSourcesOverridable.ConvertStringToDate(FormTableRow.ReceiptDate, FormTableRow.ReceiptDate_IncomingData);
		
		CheckDataCorrectnessInTableRow(FormTableRow);
		
	EndDo;
	
EndProcedure

Procedure CheckDataCorrectnessInTableRow(FormTableRow, FillingObjectFullName = "") Export
	
	ServiceFieldName = DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible();
	
	FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.ProductsAndServices)
		AND (FormTableRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem 
			OR FormTableRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service)
		AND FormTableRow.Quantity <> 0;
	
EndProcedure

#EndRegion

#Region PrintInterface

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_VendorsOrder";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.Text = 
	"SELECT
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.Number AS Number,
	|	PurchaseOrder.Date AS DocumentDate,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	CASE
	|		WHEN IndividualsDescriptionFullSliceLast.Ind IS NULL 
	|			THEN PurchaseOrder.Responsible.Description
	|		ELSE IndividualsDescriptionFullSliceLast.Surname + "" "" + SubString(IndividualsDescriptionFullSliceLast.Name, 1, 1) + "". "" + SubString(IndividualsDescriptionFullSliceLast.Patronymic, 1, 1) + "".""
	|	END AS ResponsiblePresentation,
	|	PurchaseOrder.Company.Prefix AS Prefix,
	|	PurchaseOrder.Inventory.(
	|		LineNumber AS LineNumber,
	|		CASE
	|			WHEN (CAST(PurchaseOrder.Inventory.ProductsAndServices.DescriptionFull AS String(100))) = """"
	|				THEN PurchaseOrder.Inventory.ProductsAndServices.Description
	|			ELSE PurchaseOrder.Inventory.ProductsAndServices.DescriptionFull
	|		END AS InventoryItem,
	|		ProductsAndServices.SKU AS SKU,
	|		MeasurementUnit.Description AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		Price AS Price,
	|		Amount AS Amount,
	|		VATAmount AS VATAmount,
	|		Total AS Total,
	|		ReceiptDate AS ReceiptDate,
	|		Characteristic,
	|		Content
	|	)
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|		LEFT JOIN InformationRegister.IndividualsDescriptionFull.SliceLast AS IndividualsDescriptionFullSliceLast
	|		ON PurchaseOrder.Responsible.Ind = IndividualsDescriptionFullSliceLast.Ind
	|WHERE
	|	PurchaseOrder.Ref IN(&ObjectsArray)
	|
	|ORDER BY
	|	Ref,
	|	LineNumber";
	
	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_SuppliersOrder_TemplateSuppliersOrder";
		
		Template = PrintManagement.PrintedFormsTemplate("Document.PurchaseOrder.PF_MXL_PurchaseOrderTemplate");
		
		InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
		InfoAboutCounterparty = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
		
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = "Purchase order No "
												+ DocumentNumber
												+ " from "
												+ Format(Header.DocumentDate, "DLF=DD");
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Customer");
		TemplateArea.Parameters.RecipientPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,KPP,LegalAddress,PhoneNumbers,");
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Vendor");
		VendorPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr,TIN,KPP,LegalAddress,PhoneNumbers,");
		TemplateArea.Parameters.VendorPresentation = VendorPresentation; 
		SpreadsheetDocument.Put(TemplateArea);
		
		LinesSelectionInventory = Header.Inventory.Select();
		
		TemplateArea = Template.GetArea("TableHeader");
		SpreadsheetDocument.Put(TemplateArea);
		TemplateArea = Template.GetArea("String");
		
		Amount		= 0;
		VATAmount	= 0;
		Total		= 0;
		Quantity	= 0;
		
		While LinesSelectionInventory.Next() Do
			
			TemplateArea.Parameters.Fill(LinesSelectionInventory);
			
			If ValueIsFilled(LinesSelectionInventory.Content) Then
				TemplateArea.Parameters.InventoryItem = LinesSelectionInventory.Content;
			Else
				TemplateArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
																	LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU);
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
			
			Amount		= Amount		+ LinesSelectionInventory.Amount;
			VATAmount	= VATAmount	+ LinesSelectionInventory.VATAmount;
			Total		= Total		+ LinesSelectionInventory.Total;
			Quantity	= Quantity+ 1;
			
		EndDo;
		
		TemplateArea = Template.GetArea("Total");
		TemplateArea.Parameters.Total = SmallBusinessServer.AmountsFormat(Amount);
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("TotalVAT");
		If VATAmount = 0 Then
			TemplateArea.Parameters.VAT = "Without tax (VAT)";
			TemplateArea.Parameters.TotalVAT = "-";
		Else
			TemplateArea.Parameters.VAT = ?(Header.AmountIncludesVAT, "Including VAT:", "VAT Amount:");
			TemplateArea.Parameters.TotalVAT = SmallBusinessServer.AmountsFormat(VATAmount);
		EndIf; 
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("AmountInWords");
		AmountToBeWrittenInWords = Total;
		TemplateArea.Parameters.TotalRow = "Total titles "
												+ String(Quantity)
												+ ", in the amount of "
												+ SmallBusinessServer.AmountsFormat(AmountToBeWrittenInWords, Header.DocumentCurrency);
		
		TemplateArea.Parameters.AmountInWords = WorkWithCurrencyRates.GenerateAmountInWords(AmountToBeWrittenInWords, Header.DocumentCurrency);
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Signatures");
		TemplateArea.Parameters.ResponsiblePresentation = Header.ResponsiblePresentation;
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction // PrintForm()

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "VendorsOrderTemplate") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "VendorsOrderTemplate", "Purchase order", PrintForm(ObjectsArray, PrintObjects));
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "VendorsOrderTemplate";
	PrintCommand.Presentation = NStr("en = 'Purchase order'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf
