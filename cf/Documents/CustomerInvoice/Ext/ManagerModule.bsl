#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromProcessing)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody)
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	TableInventory.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromProcessing)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Return,
	|	TableInventory.Document AS Document,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN TableInventory.Document
	|		ELSE UNDEFINED
	|	END AS SalesDocument,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|			THEN TableInventory.Order
	|		ELSE UNDEFINED
	|	END AS OrderSales,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|			THEN TableInventory.DepartmentSales
	|		ELSE UNDEFINED
	|	END AS Department,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|			THEN TableInventory.Responsible
	|		ELSE UNDEFINED
	|	END AS Responsible,
	|	TableInventory.DepartmentSales AS DepartmentSales,
	|	TableInventory.BusinessActivitySales AS BusinessActivity,
	|	TableInventory.GLAccountCost AS GLAccountCost,
	|	TableInventory.CorrOrganization AS CorrOrganization,
	|	ISNULL(TableInventory.StructuralUnit, VALUE(Catalog.Counterparties.EmptyRef)) AS StructuralUnit,
	|	ISNULL(TableInventory.StructuralUnitCorr, VALUE(Catalog.StructuralUnits.EmptyRef)) AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.ProductsOnCommission AS ProductsOnCommission,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	CASE
	|		WHEN TableInventory.Order REFS Document.CustomerOrder
	|				AND Not TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|				AND Not TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal)
	|				AND Not TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody)
	|				AND Not TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN TableInventory.Order
	|		WHEN TableInventory.Order REFS Document.PurchaseOrder
	|				AND TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|			THEN TableInventory.Order.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS CustomerOrder,
	|	CASE
	|		WHEN TableInventory.CorrOrder REFS Document.CustomerOrder
	|			THEN TableInventory.CorrOrder
	|		WHEN TableInventory.CorrOrder REFS Document.PurchaseOrder
	|				AND TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|				AND FunctionalOptionInventoryReservation.Value
	|			THEN TableInventory.CorrOrder.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS CustomerCorrOrder,
	|	SUM(CASE
	|			WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|					OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal)
	|					OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromProcessing)
	|					OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody)
	|				THEN -1 * TableInventory.Quantity
	|			ELSE TableInventory.Quantity
	|		END) AS Quantity,
	|	SUM(TableInventory.Reserve) AS Reserve,
	|	TableInventory.VATRate AS VATRate,
	|	SUM(TableInventory.VATAmount) AS VATAmount,
	|	SUM(CASE
	|			WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal)
	|					OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromProcessing)
	|					OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody)
	|				THEN 0
	|			WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	//( elmi #11
	//|				THEN -1 * TableInventory.Amount
	|				THEN -1 * (TableInventory.Amount - TableInventory.VATAmount)
	//) elmi
	|			ELSE TableInventory.Amount
	|		END) AS Amount,
	|	0 AS Cost,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS FixedCost,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|			THEN TableInventory.GLAccountCost
	|		ELSE TableInventory.CorrGLAccount
	|	END AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN CAST(&InventoryReceipt AS String(100))
	|		ELSE CAST(&InventoryWriteOff AS String(100))
	|	END AS Content,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN CAST(&InventoryReceipt AS String(100))
	|		ELSE CAST(&InventoryWriteOff AS String(100))
	|	END AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableInventory AS TableInventory,
	|	Constant.FunctionalOptionInventoryReservation AS FunctionalOptionInventoryReservation
	|WHERE
	|	TableInventory.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.Document,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromProcessing)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN TableInventory.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|			THEN TableInventory.Order
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|			THEN TableInventory.DepartmentSales
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|			THEN TableInventory.Responsible
	|		ELSE UNDEFINED
	|	END,
	|	TableInventory.DepartmentSales,
	|	TableInventory.BusinessActivitySales,
	|	TableInventory.GLAccountCost,
	|	TableInventory.CorrOrganization,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.ProductsOnCommission,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.ProductsAndServicesCorr,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.BatchCorr,
	|	TableInventory.Responsible,
	|	CASE
	|		WHEN TableInventory.Order REFS Document.CustomerOrder
	|				AND Not TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|				AND Not TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal)
	|				AND Not TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody)
	|				AND Not TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN TableInventory.Order
	|		WHEN TableInventory.Order REFS Document.PurchaseOrder
	|				AND TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|			THEN TableInventory.Order.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END,
	|	CASE
	|		WHEN TableInventory.CorrOrder REFS Document.CustomerOrder
	|			THEN TableInventory.CorrOrder
	|		WHEN TableInventory.CorrOrder REFS Document.PurchaseOrder
	|				AND TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|				AND FunctionalOptionInventoryReservation.Value
	|			THEN TableInventory.CorrOrder.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END,
	|	TableInventory.VATRate,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN FALSE
	|		ELSE TRUE
	|	END,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN CAST(&InventoryReceipt AS String(100))
	|		ELSE CAST(&InventoryWriteOff AS String(100))
	|	END,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|			THEN TableInventory.GLAccountCost
	|		ELSE TableInventory.CorrGLAccount
	|	END,
	|	TableInventory.GLAccount,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromProcessing)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody)
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN VALUE(AccumulationRecordType.Expense)
	|	END,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN CAST(&InventoryReceipt AS String(100))
	|		ELSE CAST(&InventoryWriteOff AS String(100))
	|	END";
	
	Query.SetParameter("InventoryReceipt", NStr("en='Inventory receiving';ru='Прием запасов'"));
	Query.SetParameter("InventoryWriteOff", NStr("en='Inventory write off';ru='Списание запасов'"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
	If DocumentRefSalesInvoice.OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer 
		OR DocumentRefSalesInvoice.OperationKind = Enums.OperationKindsCustomerInvoice.TransferForCommission 
		OR DocumentRefSalesInvoice.OperationKind = Enums.OperationKindsCustomerInvoice.TransferToProcessing
		OR DocumentRefSalesInvoice.OperationKind = Enums.OperationKindsCustomerInvoice.TransferForSafeCustody Then
		
		PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCustomerInvoicePositingGenerateTableProductionCostTable");
		
		GenerateTableInventorySale(DocumentRefSalesInvoice, StructureAdditionalProperties);
		
	ElsIf DocumentRefSalesInvoice.OperationKind = Enums.OperationKindsCustomerInvoice.ReturnToVendor Then
		GenerateTableInventoryReturn(DocumentRefSalesInvoice, StructureAdditionalProperties);
	EndIf;
	
EndProcedure // GenerateTableInventory()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventorySale(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
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
	|	TableInventory.CustomerOrder AS CustomerOrder
	|FROM
	|	(SELECT
	|		TableInventory.Company AS Company,
	|		TableInventory.StructuralUnit AS StructuralUnit,
	|		TableInventory.GLAccount AS GLAccount,
	|		TableInventory.ProductsAndServices AS ProductsAndServices,
	|		TableInventory.Characteristic AS Characteristic,
	|		TableInventory.Batch AS Batch,
	|		CASE
	|			WHEN TableInventory.Order REFS Document.CustomerOrder
	|				THEN TableInventory.Order
	|			WHEN TableInventory.Order REFS Document.PurchaseOrder
	|					AND TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|				THEN TableInventory.Order.CustomerOrder
	|			ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|		END AS CustomerOrder
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		TableInventory.Order <> UNDEFINED
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableInventory.Company,
	|		TableInventory.StructuralUnit,
	|		TableInventory.GLAccount,
	|		TableInventory.ProductsAndServices,
	|		TableInventory.Characteristic,
	|		TableInventory.Batch,
	|		VALUE(Document.CustomerOrder.EmptyRef)
	|	FROM
	|		TemporaryTableInventory AS TableInventory) AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder";
	
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
	|	InventoryBalances.CustomerOrder AS CustomerOrder,
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
	|		InventoryBalances.CustomerOrder AS CustomerOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						TableInventory.Company AS Company,
	|						TableInventory.StructuralUnit AS StructuralUnit,
	|						TableInventory.GLAccount AS GLAccount,
	|						TableInventory.ProductsAndServices AS ProductsAndServices,
	|						TableInventory.Characteristic AS Characteristic,
	|						TableInventory.Batch AS Batch,
	|						CASE
	|							WHEN TableInventory.Order REFS Document.CustomerOrder
	|								THEN TableInventory.Order
	|							WHEN TableInventory.Order REFS Document.PurchaseOrder
	|									AND TableInventory.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|								THEN TableInventory.Order.CustomerOrder
	|							ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|						END
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.Order <> UNDEFINED)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		VALUE(Document.CustomerOrder.EmptyRef),
	|		SUM(InventoryBalances.QuantityBalance),
	|		SUM(InventoryBalances.AmountBalance)
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
	|						VALUE(Document.CustomerOrder.EmptyRef)
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
	|		DocumentRegisterRecordsInventory.CustomerOrder,
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
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.CustomerOrder";
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch,CustomerOrder");
	
	Transfer = (DocumentRefSalesInvoice.OperationKind = Enums.OperationKindsCustomerInvoice.TransferForCommission
				OR DocumentRefSalesInvoice.OperationKind = Enums.OperationKindsCustomerInvoice.TransferToProcessing
				OR DocumentRefSalesInvoice.OperationKind = Enums.OperationKindsCustomerInvoice.TransferForSafeCustody);
	
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
		
		QuantityRequiredReserve = ?(ValueIsFilled(RowTableInventory.Reserve), RowTableInventory.Reserve, 0);
		QuantityRequiredAvailableBalance = ?(ValueIsFilled(RowTableInventory.Quantity), RowTableInventory.Quantity, 0);
		
		If QuantityRequiredReserve > 0 Then
			
			QuantityRequiredAvailableBalance = QuantityRequiredAvailableBalance - QuantityRequiredReserve;
			
			StructureForSearch.Insert("CustomerOrder", RowTableInventory.CustomerOrder);
			
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
			
			// Expense. Inventory.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredReserve;
			
			// Generate postings.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerial, RowTableInventory);
				RowTableManagerial.Amount = AmountToBeWrittenOff;
			EndIf;
			
			If Transfer Then
				
				// Receipt.
				TableRowReceipt = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory,,"StructuralUnit, StructuralUnitCorr");
				
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				
				
				TableRowReceipt.Company = RowTableInventory.CorrOrganization;
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				
				TableRowReceipt.CorrOrganization = RowTableInventory.Company;
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
			
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = QuantityRequiredReserve;
				
				TableRowReceipt.ContentOfAccountingRecord = NStr("en='Inventory transfer';ru='Перемещение запасов'"); 
				
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
			Else
				
				If RowTableInventory.ProductsOnCommission Then
				
				ElsIf Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					
					// Move income and expenses.
					RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
					FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
					
					RowIncomeAndExpenses.StructuralUnit = RowTableInventory.DepartmentSales;
					RowIncomeAndExpenses.GLAccount = RowTableInventory.GLAccountCost;
					RowIncomeAndExpenses.AmountIncome = 0;
					RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
					RowIncomeAndExpenses.Amount = AmountToBeWrittenOff;
					
					RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en='Costs reflection';ru='Отражение расходов'");
					
				EndIf;
				
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
					// Move the cost of sales.
					SaleString = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
					FillPropertyValues(SaleString, RowTableInventory);
					SaleString.Quantity = 0;
					SaleString.Amount = 0;
					SaleString.VATAmount = 0;
					SaleString.Cost = AmountToBeWrittenOff;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			StructureForSearch.Insert("CustomerOrder", Documents.CustomerOrder.EmptyRef());
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = AmountBalance;
				
				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Expense. Inventory.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.CustomerOrder = Documents.CustomerOrder.EmptyRef();
			
			// Generate postings.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerial, RowTableInventory);
				RowTableManagerial.Amount = AmountToBeWrittenOff;
			EndIf;
			
			If Transfer Then
				
				// Receipt.
				TableRowReceipt = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory,,"StructuralUnit, StructuralUnitCorr");
				
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceipt.Company = RowTableInventory.CorrOrganization;
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
 
				TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
				
				TableRowReceipt.CorrOrganization = RowTableInventory.Company;
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
 
				TableRowReceipt.CustomerCorrOrder = Documents.CustomerOrder.EmptyRef();
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = QuantityRequiredAvailableBalance;
				
				TableRowReceipt.ContentOfAccountingRecord = NStr("en='Inventory transfer';ru='Перемещение запасов'");
				
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
			Else
				
				If RowTableInventory.ProductsOnCommission Then
								
				ElsIf Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					
					// Move income and expenses.
					RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
					FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
					
					RowIncomeAndExpenses.StructuralUnit = RowTableInventory.DepartmentSales;
					RowIncomeAndExpenses.GLAccount = RowTableInventory.GLAccountCost;
					RowIncomeAndExpenses.AmountIncome = 0;
					RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
					RowIncomeAndExpenses.Amount = AmountToBeWrittenOff;
					
					RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en='Costs reflection';ru='Отражение расходов'");
					
				EndIf;
				
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
					// Move the cost of sales.
					SaleString = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
					FillPropertyValues(SaleString, RowTableInventory);
					SaleString.Quantity = 0;
					SaleString.Amount = 0;
					SaleString.VATAmount = 0;
					SaleString.Cost = AmountToBeWrittenOff;
					
				EndIf;	
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure // GenerateTableInventorySale()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryReturn(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	BasisInvoice = Undefined;
	If ValueIsFilled(DocumentRefSalesInvoice.BasisDocument)
		AND TypeOf(DocumentRefSalesInvoice.BasisDocument) = Type("DocumentRef.SupplierInvoice") Then
		BasisInvoice = DocumentRefSalesInvoice.BasisDocument;
	EndIf;
	
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
	If ValueIsFilled(BasisInvoice) Then
		
		Query.Text =
		"SELECT
		|	Inventory.Company AS Company,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.GLAccount AS GLAccount,
		|	Inventory.ProductsAndServices AS ProductsAndServices,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder,
		|	SUM(Inventory.Quantity) AS QuantityBalance,
		|	SUM(Inventory.Amount) AS AmountBalance
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.Recorder = &BasisInvoice
		|
		|GROUP BY
		|	Inventory.Company,
		|	Inventory.StructuralUnit,
		|	Inventory.GLAccount,
		|	Inventory.ProductsAndServices,
		|	Inventory.Characteristic,
		|	Inventory.Batch";
		
		Query.SetParameter("BasisInvoice", BasisInvoice);
		
	Else
		
		Query.Text =
		"SELECT
		|	InventoryBalances.Company AS Company,
		|	InventoryBalances.StructuralUnit AS StructuralUnit,
		|	InventoryBalances.GLAccount AS GLAccount,
		|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
		|	InventoryBalances.Characteristic AS Characteristic,
		|	InventoryBalances.Batch AS Batch,
		|	InventoryBalances.CustomerOrder AS CustomerOrder,
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
		|		VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder,
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
		|						VALUE(Document.CustomerOrder.EmptyRef)
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
		|		DocumentRegisterRecordsInventory.CustomerOrder,
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
		|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
		|
		|GROUP BY
		|	InventoryBalances.Company,
		|	InventoryBalances.StructuralUnit,
		|	InventoryBalances.GLAccount,
		|	InventoryBalances.ProductsAndServices,
		|	InventoryBalances.Characteristic,
		|	InventoryBalances.Batch,
		|	InventoryBalances.CustomerOrder";
		
		Query.SetParameter("Ref", DocumentRefSalesInvoice);
		Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
		Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
		
	EndIf;
	
	QueryResult = Query.Execute();
	TableInventoryBalances = QueryResult.Unload();
	
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch");
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("ProductsAndServices", RowTableInventory.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredAvailableBalance = -RowTableInventory.Quantity;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = AmountBalance;
				
				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Inventory.
			If Round((RowTableInventory.Amount + AmountToBeWrittenOff), 2, 1) <> 0 Then
				
				TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowExpense, RowTableInventory);
				
				CalculatedAmount = -(TableRowExpense.Amount + AmountToBeWrittenOff);
				TableRowExpense.RecordType = AccumulationRecordType.Receipt;
				TableRowExpense.Amount = CalculatedAmount;
				
				TableRowExpense.Quantity = 0;
				TableRowExpense.SalesDocument = DocumentRefSalesInvoice;
				TableRowExpense.Return = True;
				TableRowExpense.FixedCost = True;
				
				// Income and expenses.
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.StructuralUnit = Undefined;
				RowIncomeAndExpenses.CustomerOrder = Undefined;
				RowIncomeAndExpenses.BusinessActivity = Catalogs.BusinessActivities.Other;
				If TableRowExpense.Amount < 0 Then
					RowIncomeAndExpenses.GLAccount = ChartsOfAccounts.Managerial.OtherExpenses;
					RowIncomeAndExpenses.AmountExpense = - TableRowExpense.Amount;
				Else
					RowIncomeAndExpenses.GLAccount = ChartsOfAccounts.Managerial.OtherIncome;
					RowIncomeAndExpenses.AmountIncome = TableRowExpense.Amount;
				EndIf;
				
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en='Costs reflection';ru='Отражение расходов'");
				
				// Management.
				RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerial, RowTableInventory);
				If TableRowExpense.Amount < 0 Then
					RowTableManagerial.AccountDr = ChartsOfAccounts.Managerial.OtherExpenses;
					RowTableManagerial.AccountCr = RowTableInventory.AccountCr;
					RowTableManagerial.Amount = - TableRowExpense.Amount;
				Else
					RowTableManagerial.AccountDr = RowTableInventory.AccountCr;
					RowTableManagerial.AccountCr = ChartsOfAccounts.Managerial.OtherIncome;
					RowTableManagerial.Amount = TableRowExpense.Amount;
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure // GenerateTableInventoryReturn()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchasing(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TablePurchasing.Period AS Period,
	|	TablePurchasing.Company AS Company,
	|	TablePurchasing.ProductsAndServices AS ProductsAndServices,
	|	TablePurchasing.Characteristic AS Characteristic,
	|	TablePurchasing.Batch AS Batch,
	|	TablePurchasing.Order AS PurchaseOrder,
	|	CASE
	|		WHEN VALUETYPE(TablePurchasing.BasisDocument) = Type(Document.SupplierInvoice)
	|				AND TablePurchasing.BasisDocument <> VALUE(Document.SupplierInvoice.EmptyRef)
	|			THEN TablePurchasing.BasisDocument
	|		ELSE TablePurchasing.Document
	|	END AS Document,
	|	TablePurchasing.VATRate AS VATRate,
	|	-SUM(TablePurchasing.Quantity) AS Quantity,
	|	-SUM(TablePurchasing.AmountVATPurchaseSale) AS VATAmount,
	|	-SUM(TablePurchasing.Amount) AS Amount
	|FROM
	|	TemporaryTableInventory AS TablePurchasing
	|WHERE
	|	TablePurchasing.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	AND (TablePurchasing.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			OR TablePurchasing.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal))
	|
	|GROUP BY
	|	TablePurchasing.Period,
	|	TablePurchasing.Company,
	|	TablePurchasing.ProductsAndServices,
	|	TablePurchasing.Characteristic,
	|	TablePurchasing.Batch,
	|	TablePurchasing.Order,
	|	CASE
	|		WHEN VALUETYPE(TablePurchasing.BasisDocument) = Type(Document.SupplierInvoice)
	|				AND TablePurchasing.BasisDocument <> VALUE(Document.SupplierInvoice.EmptyRef)
	|			THEN TablePurchasing.BasisDocument
	|		ELSE TablePurchasing.Document
	|	END,
	|	TablePurchasing.VATRate";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchasing", QueryResult.Unload());
	
EndProcedure // GeneratePurchasingTable()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.ProductsAndServices AS ProductsAndServices,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	CASE
	|		WHEN TableSales.Order REFS Document.CustomerOrder
	|			THEN TableSales.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS CustomerOrder,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.DepartmentSales AS Department,
	|	TableSales.Responsible AS Responsible,
	|	SUM(TableSales.Quantity) AS Quantity,
	|	SUM(TableSales.AmountVATPurchaseSale) AS VATAmount,
	|	SUM(TableSales.Amount) AS Amount,
	|	0 AS Cost
	|FROM
	|	TemporaryTableInventory AS TableSales
	|WHERE
	|	TableSales.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|
	|GROUP BY
	|	TableSales.Period,
	|	TableSales.Company,
	|	TableSales.ProductsAndServices,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	CASE
	|		WHEN TableSales.Order REFS Document.CustomerOrder
	|			THEN TableSales.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.DepartmentSales,
	|	TableSales.Responsible";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure // GenerateTableSales()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableProductRelease(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProductRelease.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProductRelease.Period AS Period,
	|	TableProductRelease.Company AS Company,
	|	TableProductRelease.DepartmentSales AS StructuralUnit,
	|	TableProductRelease.ProductsAndServices AS ProductsAndServices,
	|	TableProductRelease.Characteristic AS Characteristic,
	|	CASE
	|		WHEN TableProductRelease.Order REFS Document.CustomerOrder
	|			THEN TableProductRelease.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS CustomerOrder,
	|	SUM(TableProductRelease.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableProductRelease
	|WHERE
	|	TableProductRelease.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Service)
	|
	|GROUP BY
	|	TableProductRelease.Period,
	|	TableProductRelease.Company,
	|	TableProductRelease.DepartmentSales,
	|	TableProductRelease.ProductsAndServices,
	|	TableProductRelease.Characteristic,
	|	CASE
	|		WHEN TableProductRelease.Order REFS Document.CustomerOrder
	|			THEN TableProductRelease.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", QueryResult.Unload());
	
EndProcedure // GenerateTableProductRelease()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventoryInWarehouses.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventoryInWarehouses.Period AS Period,
	|	TableInventoryInWarehouses.Company AS Company,
	|	TableInventoryInWarehouses.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryInWarehouses.Characteristic AS Characteristic,
	|	TableInventoryInWarehouses.Batch AS Batch,
	|	TableInventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	TableInventoryInWarehouses.Cell AS Cell,
	|	SUM(TableInventoryInWarehouses.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventoryInWarehouses
	|WHERE
	|	TableInventoryInWarehouses.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	AND (NOT TableInventoryInWarehouses.OrderWarehouse)
	|
	|GROUP BY
	|	TableInventoryInWarehouses.Period,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.ProductsAndServices,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell";
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryInWarehouses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryForExpenseFromWarehouses(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventoryForExpenseFromWarehouses.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventoryForExpenseFromWarehouses.Period AS Period,
	|	TableInventoryForExpenseFromWarehouses.Company AS Company,
	|	TableInventoryForExpenseFromWarehouses.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryForExpenseFromWarehouses.Characteristic AS Characteristic,
	|	TableInventoryForExpenseFromWarehouses.Batch AS Batch,
	|	TableInventoryForExpenseFromWarehouses.StructuralUnit AS StructuralUnit,
	|	SUM(TableInventoryForExpenseFromWarehouses.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventoryForExpenseFromWarehouses
	|WHERE
	|	TableInventoryForExpenseFromWarehouses.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	AND TableInventoryForExpenseFromWarehouses.OrderWarehouse
	|
	|GROUP BY
	|	TableInventoryForExpenseFromWarehouses.Period,
	|	TableInventoryForExpenseFromWarehouses.Company,
	|	TableInventoryForExpenseFromWarehouses.ProductsAndServices,
	|	TableInventoryForExpenseFromWarehouses.Characteristic,
	|	TableInventoryForExpenseFromWarehouses.Batch,
	|	TableInventoryForExpenseFromWarehouses.StructuralUnit";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryForExpenseFromWarehouses", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryForExpenseFromWarehouses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryReceived(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MIN(TableInventoryReceived.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventoryReceived.Period AS Period,
	|	TableInventoryReceived.Company AS Company,
	|	TableInventoryReceived.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryReceived.Characteristic AS Characteristic,
	|	TableInventoryReceived.Batch AS Batch,
	|	TableInventoryReceived.Counterparty AS Counterparty,
	|	TableInventoryReceived.Contract AS Contract,
	|	TableInventoryReceived.Order AS Order,
	|	TableInventoryReceived.GLAccount AS GLAccount,
	|	CASE
	|		WHEN TableInventoryReceived.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal)
	|			THEN VALUE(Enum.ProductsReceiptTransferTypes.ReceiptFromPrincipal)
	|		WHEN TableInventoryReceived.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromProcessing)
	|			THEN VALUE(Enum.ProductsReceiptTransferTypes.ReceiptToProcessing)
	|		ELSE VALUE(Enum.ProductsReceiptTransferTypes.SafeCustody)
	|	END AS ReceptionTransmissionType,
	|	-SUM(TableInventoryReceived.Quantity) AS Quantity,
	//( elmi #11
	//|	-SUM(TableInventoryReceived.SettlementsAmountTakenPassed) AS SettlementsAmount,
	//|	-SUM(TableInventoryReceived.SettlementsAmountTakenPassed) AS Amount,
	|	-SUM(TableInventoryReceived.SettlementsAmountTakenPassed - TableInventoryReceived.VATAmount) AS SettlementsAmount,
	|	-SUM(TableInventoryReceived.SettlementsAmountTakenPassed - TableInventoryReceived.VATAmount) AS Amount,
	//) elmi
	|	0 AS SalesAmount,
	|	&AdmAccountingCurrency AS Currency,
	//( elmi #11
	//|	-SUM(TableInventoryReceived.SettlementsAmountTakenPassed) AS AmountCur, 
	|	-SUM(TableInventoryReceived.SettlementsAmountTakenPassed - TableInventoryReceived.VATAmount) AS AmountCur, 
	//) elmi
	|	CAST(&InventoryReception AS String(100)) AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableInventory AS TableInventoryReceived
	|WHERE
	|	TableInventoryReceived.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	AND (TableInventoryReceived.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal)
	|			OR TableInventoryReceived.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromProcessing)
	|			OR TableInventoryReceived.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody))
	|
	|GROUP BY
	|	TableInventoryReceived.Period,
	|	TableInventoryReceived.Company,
	|	TableInventoryReceived.ProductsAndServices,
	|	TableInventoryReceived.Characteristic,
	|	TableInventoryReceived.Batch,
	|	TableInventoryReceived.Counterparty,
	|	TableInventoryReceived.Contract,
	|	TableInventoryReceived.Order,
	|	TableInventoryReceived.GLAccount,
	|	CASE
	|		WHEN TableInventoryReceived.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal)
	|			THEN VALUE(Enum.ProductsReceiptTransferTypes.ReceiptFromPrincipal)
	|		WHEN TableInventoryReceived.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromProcessing)
	|			THEN VALUE(Enum.ProductsReceiptTransferTypes.ReceiptToProcessing)
	|		ELSE VALUE(Enum.ProductsReceiptTransferTypes.SafeCustody)
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	MIN(TableInventoryReceived.LineNumber),
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventoryReceived.Period,
	|	TableInventoryReceived.Company,
	|	TableInventoryReceived.ProductsAndServices,
	|	TableInventoryReceived.Characteristic,
	|	TableInventoryReceived.Batch,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableInventoryReceived.Order,
	|	TableInventoryReceived.GLAccountVendorSettlements,
	|	VALUE(Enum.ProductsReceiptTransferTypes.ReportToPrincipal),
	|	SUM(TableInventoryReceived.Quantity),
	|	0,
	//( elmi #11
	//|	SUM(TableInventoryReceived.Amount),
	|	SUM(TableInventoryReceived.Amount - TableInventoryReceived.VATAmount),  
	//|	SUM(TableInventoryReceived.Amount ),
	|	SUM(TableInventoryReceived.Amount - TableInventoryReceived.VATAmount),  
	|	&AdmAccountingCurrency,
	//|	SUM(TableInventoryReceived.Amount),
	|	SUM(TableInventoryReceived.Amount - TableInventoryReceived.VATAmount),  
	//) elmi
	|	CAST(&InventoryReceiptProductsOnCommission AS String(100))
	|FROM
	|	TemporaryTableInventory AS TableInventoryReceived
	|WHERE
	|	TableInventoryReceived.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	AND TableInventoryReceived.ProductsOnCommission
	|
	|GROUP BY
	|	TableInventoryReceived.Period,
	|	TableInventoryReceived.Company,
	|	TableInventoryReceived.ProductsAndServices,
	|	TableInventoryReceived.Characteristic,
	|	TableInventoryReceived.Batch,
	|	TableInventoryReceived.Counterparty,
	|	TableInventoryReceived.Contract,
	|	TableInventoryReceived.Order,
	|	TableInventoryReceived.GLAccountVendorSettlements,
	|	TableInventoryReceived.GLAccount";
	
	Query.SetParameter("InventoryReception", "");
	Query.SetParameter("InventoryReceiptProductsOnCommission", NStr("en='Inventory receiving';ru='Прием запасов'"));
	Query.SetParameter("AdmAccountingCurrency", Constants.AccountingCurrency.Get());
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryReceived", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryReceived()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryTransferred(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventoryTransferred.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventoryTransferred.Period AS Period,
	|	TableInventoryTransferred.Company AS Company,
	|	TableInventoryTransferred.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryTransferred.Characteristic AS Characteristic,
	|	TableInventoryTransferred.Batch AS Batch,
	|	TableInventoryTransferred.Counterparty AS Counterparty,
	|	TableInventoryTransferred.Contract AS Contract,
	|	TableInventoryTransferred.Order AS Order,
	|	CASE
	|		WHEN TableInventoryTransferred.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|			THEN VALUE(Enum.ProductsReceiptTransferTypes.TransferToAgent)
	|		WHEN TableInventoryTransferred.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|			THEN VALUE(Enum.ProductsReceiptTransferTypes.TransferToProcessing)
	|		ELSE VALUE(Enum.ProductsReceiptTransferTypes.SafeCustody)
	|	END AS ReceptionTransmissionType,
	|	SUM(TableInventoryTransferred.Quantity) AS Quantity,
	//( elmi #11
   //|	SUM(TableInventoryTransferred.SettlementsAmountTakenPassed) AS SettlementsAmount
	|	SUM(TableInventoryTransferred.SettlementsAmountTakenPassed - TableInventoryTransferred.VATAmount) AS SettlementsAmount 
	//) elmi
	|FROM
	|	TemporaryTableInventory AS TableInventoryTransferred
	|WHERE
	|	TableInventoryTransferred.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	AND (TableInventoryTransferred.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|			OR TableInventoryTransferred.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|			OR TableInventoryTransferred.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody))
	|
	|GROUP BY
	|	TableInventoryTransferred.Period,
	|	TableInventoryTransferred.Company,
	|	TableInventoryTransferred.ProductsAndServices,
	|	TableInventoryTransferred.Characteristic,
	|	TableInventoryTransferred.Batch,
	|	TableInventoryTransferred.Counterparty,
	|	TableInventoryTransferred.Contract,
	|	TableInventoryTransferred.Order,
	|	CASE
	|		WHEN TableInventoryTransferred.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|			THEN VALUE(Enum.ProductsReceiptTransferTypes.TransferToAgent)
	|		WHEN TableInventoryTransferred.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|			THEN VALUE(Enum.ProductsReceiptTransferTypes.TransferToProcessing)
	|		ELSE VALUE(Enum.ProductsReceiptTransferTypes.SafeCustody)
	|	END";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryTransferred", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryTransferred()  

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerOrders(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableCustomerOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableCustomerOrders.Period AS Period,
	|	TableCustomerOrders.Company AS Company,
	|	TableCustomerOrders.ProductsAndServices AS ProductsAndServices,
	|	TableCustomerOrders.Characteristic AS Characteristic,
	|	TableCustomerOrders.Order AS CustomerOrder,
	|	SUM(TableCustomerOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableCustomerOrders
	|WHERE
	|	TableCustomerOrders.Order <> UNDEFINED
	|	AND (TableCustomerOrders.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|			OR TableCustomerOrders.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|			OR TableCustomerOrders.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody))
	|
	|GROUP BY
	|	TableCustomerOrders.Period,
	|	TableCustomerOrders.Company,
	|	TableCustomerOrders.ProductsAndServices,
	|	TableCustomerOrders.Characteristic,
	|	TableCustomerOrders.Order";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCustomerOrders", QueryResult.Unload());
	
EndProcedure // GenerateTableCustomerOrders()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchaseOrders(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TablePurchaseOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TablePurchaseOrders.Period AS Period,
	|	TablePurchaseOrders.Company AS Company,
	|	TablePurchaseOrders.ProductsAndServices AS ProductsAndServices,
	|	TablePurchaseOrders.Characteristic AS Characteristic,
	|	TablePurchaseOrders.Order AS PurchaseOrder,
	|	-SUM(TablePurchaseOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TablePurchaseOrders
	|WHERE
	|	TablePurchaseOrders.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	AND TablePurchaseOrders.Order <> UNDEFINED
	|	AND (TablePurchaseOrders.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			OR TablePurchaseOrders.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal)
	|			OR TablePurchaseOrders.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody))
	|
	|GROUP BY
	|	TablePurchaseOrders.Period,
	|	TablePurchaseOrders.Company,
	|	TablePurchaseOrders.ProductsAndServices,
	|	TablePurchaseOrders.Characteristic,
	|	TablePurchaseOrders.Order";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchaseOrders", QueryResult.Unload());
	
EndProcedure // GenerateTablePurchaseOrders()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableIncomeAndExpenses.LineNumber AS LineNumber,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.DepartmentSales AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessActivitySales AS BusinessActivity,
	|	TableIncomeAndExpenses.Order AS CustomerOrder,
	|	TableIncomeAndExpenses.AccountStatementSales AS GLAccount,
	|	CAST(&Income AS String(100)) AS ContentOfAccountingRecord,
	//( elmi #11
	//|	SUM(TableIncomeAndExpenses.Amount) AS AmountIncome,
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS AmountIncome, 
	|	0 AS AmountExpense,
	//|	SUM(TableIncomeAndExpenses.Amount) AS Amount
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS Amount        
	//) elmi
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|WHERE
	|	TableIncomeAndExpenses.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|	AND Not TableIncomeAndExpenses.ProductsOnCommission
	|	AND TableIncomeAndExpenses.Amount <> 0
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.LineNumber,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.DepartmentSales,
	|	TableIncomeAndExpenses.BusinessActivitySales,
	|	TableIncomeAndExpenses.Order,
	|	TableIncomeAndExpenses.AccountStatementSales
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	VALUE(Catalog.BusinessActivities.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE &PositiveExchangeDifferenceGLAccount
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	VALUE(Catalog.BusinessActivities.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END
	|FROM
	|	(SELECT
	|		TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|		SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableExchangeRateDifferencesAccountsReceivable
	|	
	|	GROUP BY
	|		TableExchangeRateDifferencesAccountsReceivable.Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company
	|	
	|	HAVING
	|		(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)) AS DocumentTable
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	Query.SetParameter("Income", NStr("en='Sales revenue';ru='Выручка от продажи'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDemand(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventoryDemand.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventoryDemand.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryDemand.Characteristic AS Characteristic,
	|	CASE
	|		WHEN FunctionalOptionInventoryReservation.Value
	|				AND TableInventoryDemand.Order REFS Document.PurchaseOrder
	|			THEN ISNULL(TableInventoryDemand.Order.CustomerOrder, VALUE(Document.CustomerOrder.EmptyRef))
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS CustomerOrder,
	|	SUM(TableInventoryDemand.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventoryDemand,
	|	Constant.FunctionalOptionInventoryReservation AS FunctionalOptionInventoryReservation
	|WHERE
	|	TableInventoryDemand.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	AND TableInventoryDemand.Order <> UNDEFINED
	|	AND TableInventoryDemand.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|
	|GROUP BY
	|	TableInventoryDemand.Period,
	|	TableInventoryDemand.Company,
	|	TableInventoryDemand.ProductsAndServices,
	|	TableInventoryDemand.Characteristic,
	|	CASE
	|		WHEN FunctionalOptionInventoryReservation.Value
	|				AND TableInventoryDemand.Order REFS Document.PurchaseOrder
	|			THEN ISNULL(TableInventoryDemand.Order.CustomerOrder, VALUE(Document.CustomerOrder.EmptyRef))
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", QueryResult.Unload());
	
EndProcedure // GenerateTableNeedForInventory()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerLiability", NStr("en='Appearance of customer liabilities';ru='Возникновение обязательств покупателя'"));
	Query.SetParameter("AdvanceCredit", NStr("en='Setoff of advance payment';ru='Зачет предоплаты'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	// Generate temporary table by accounts payable.
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.GLAccountCustomerSettlements AS GLAccount,
	|	DocumentTable.Contract AS Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				OR Not DocumentTable.DoOperationsByOrders
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	CAST(&AppearenceOfCustomerLiability AS String(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|	AND DocumentTable.Amount <> 0
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				OR Not DocumentTable.DoOperationsByOrders
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountCustomerSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				OR Not DocumentTable.DoOperationsByOrders
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS String(100))
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				OR Not DocumentTable.DoOperationsByOrders
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.CustomerAdvancesGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				OR Not DocumentTable.DoOperationsByOrders
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS String(100))
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				OR Not DocumentTable.DoOperationsByOrders
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere
	|
	|INDEX BY
	|	Company,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	Order,
	|	SettlementsType,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of settlements with suppliers.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsReceivable.Company AS Company,
	|	TemporaryTableAccountsReceivable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsReceivable.Contract AS Contract,
	|	TemporaryTableAccountsReceivable.Document AS Document,
	|	TemporaryTableAccountsReceivable.Order AS Order,
	|	TemporaryTableAccountsReceivable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsReceivable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult IN QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = SmallBusinessServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, True, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("DebtCancelling", NStr("en='Debt cancelling';ru='Сторнирование долга'"));
	Query.SetParameter("PrepaymentRecovery", NStr("en='Prepayment recovery';ru='Восстановление предоплаты'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&DebtCancelling AS ContentOfAccountingRecord,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.GLAccountVendorSettlements AS GLAccount,
	|	DocumentTable.Contract AS Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN VALUETYPE(DocumentTable.BasisDocument) = Type(Document.SupplierInvoice)
	|							AND DocumentTable.BasisDocument <> VALUE(Document.SupplierInvoice.EmptyRef)
	|						THEN DocumentTable.BasisDocument
	|					ELSE DocumentTable.Document
	|				END
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				OR Not DocumentTable.DoOperationsByOrders
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	-SUM(DocumentTable.Amount) AS Amount,
	|	-SUM(DocumentTable.AmountCur) AS AmountCur,
	|	-SUM(DocumentTable.Amount) AS AmountForBalance,
	|	-SUM(DocumentTable.AmountCur) AS AmountCurForBalance
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN VALUETYPE(DocumentTable.BasisDocument) = Type(Document.SupplierInvoice)
	|							AND DocumentTable.BasisDocument <> VALUE(Document.SupplierInvoice.EmptyRef)
	|						THEN DocumentTable.BasisDocument
	|					ELSE DocumentTable.Document
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				OR Not DocumentTable.DoOperationsByOrders
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountVendorSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	MAX(DocumentTable.LineNumber),
	|	VALUE(AccumulationRecordType.Expense),
	|	&PrepaymentRecovery,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN VALUETYPE(DocumentTable.BasisDocument) = Type(Document.SupplierInvoice)
	|							AND DocumentTable.BasisDocument <> VALUE(Document.SupplierInvoice.EmptyRef)
	|						THEN DocumentTable.BasisDocument
	|					ELSE &Ref
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				OR Not DocumentTable.DoOperationsByOrders
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur)
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN VALUETYPE(DocumentTable.BasisDocument) = Type(Document.SupplierInvoice)
	|							AND DocumentTable.BasisDocument <> VALUE(Document.SupplierInvoice.EmptyRef)
	|						THEN DocumentTable.BasisDocument
	|					ELSE &Ref
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				OR Not DocumentTable.DoOperationsByOrders
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.SettlemensTypeWhere,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountVendorSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	MAX(DocumentTable.LineNumber),
	|	VALUE(AccumulationRecordType.Receipt),
	|	&PrepaymentRecovery,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				OR Not DocumentTable.DoOperationsByOrders
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur)
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				OR Not DocumentTable.DoOperationsByOrders
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.VendorAdvancesGLAccount
	|
	|INDEX BY
	|	Company,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	Order,
	|	SettlementsType,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of settlements with suppliers.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsPayable.Company AS Company,
	|	TemporaryTableAccountsPayable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsPayable.Contract AS Contract,
	|	TemporaryTableAccountsPayable.Document AS Document,
	|	TemporaryTableAccountsPayable.Order AS Order,
	|	TemporaryTableAccountsPayable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsPayable AS TemporaryTableAccountsPayable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsPayable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = SmallBusinessServer.GetQueryTextExchangeRatesDifferencesAccountsPayable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.BusinessActivitySales AS BusinessActivity,
	//( elmi #11
    //|	DocumentTable.Amount AS AmountIncome
	|	DocumentTable.Amount - DocumentTable.VATAmount AS AmountIncome
	//) elmi
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|	AND DocumentTable.Amount <> 0
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Company AS Company,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|
	|GROUP BY
	|	DocumentTable.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Item AS Item
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|
	|ORDER BY
	|	LineNumber";
	
	ResultsArray = Query.ExecuteBatch();
	
	TableInventoryIncomeAndExpensesRetained = ResultsArray[0].Unload();
	SelectionOfQueryResult = ResultsArray[1].Select();
	
	TablePrepaymentIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Copy();
	TablePrepaymentIncomeAndExpensesRetained.Clear();
	
	If SelectionOfQueryResult.Next() Then
		AmountToBeWrittenOff = SelectionOfQueryResult.AmountToBeWrittenOff;
		For Each StringInventoryIncomeAndExpensesRetained IN TableInventoryIncomeAndExpensesRetained Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountIncome <= AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				AmountToBeWrittenOff = AmountToBeWrittenOff - StringInventoryIncomeAndExpensesRetained.AmountIncome;
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountIncome > AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				StringPrepaymentIncomeAndExpensesRetained.AmountIncome = AmountToBeWrittenOff;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndIf;
	
	For Each StringPrepaymentIncomeAndExpensesRetained IN TablePrepaymentIncomeAndExpensesRetained Do
		StringInventoryIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Add();
		FillPropertyValues(StringInventoryIncomeAndExpensesRetained, StringPrepaymentIncomeAndExpensesRetained);
		StringInventoryIncomeAndExpensesRetained.RecordType = AccumulationRecordType.Expense;
	EndDo;
	
	SelectionOfQueryResult = ResultsArray[2].Select();
	
	If SelectionOfQueryResult.Next() Then
		Item = SelectionOfQueryResult.Item;
	Else
		Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.Document AS Document,
	|	&Item AS Item,
	|	Table.BusinessActivity AS BusinessActivity,
	|	Table.AmountIncome AS AmountIncome
	|INTO TemporaryTablePrepaidIncomeAndExpensesRetained
	|FROM
	|	&Table AS Table";
	Query.SetParameter("Table", TablePrepaymentIncomeAndExpensesRetained);
	Query.SetParameter("Item", Item);
	
	Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", TableInventoryIncomeAndExpensesRetained);
	
EndProcedure // GenerateTableIncomeAndExpensesRetained()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesUndistributed(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountIncome
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesUndistributed", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesUndistributed()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.DocumentDate AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS BusinessActivity,
	|	DocumentTable.Item AS Item,
	|	-DocumentTable.Amount AS AmountIncome
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.BusinessActivity,
	|	Table.Item,
	|	Table.AmountIncome
	|FROM
	|	TemporaryTablePrepaidIncomeAndExpensesRetained AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesCashMethod()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	//( elmi #11
    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
	|	Sum(TemporaryTable.VATAmount) AS VATInventory ,
	|	Sum(TemporaryTable.VATAmountCur) AS VATInventoryCur 
	|FROM
	|	TemporaryTableInventory AS TemporaryTable
	|GROUP BY
	|TemporaryTable.Period,
	|TemporaryTable.Company	";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	VATInventory = 0;
	VATInventoryCur = 0;
	
	While Selection.Next() Do  
		  VATInventory    = Selection.VATInventory;
	      VATInventoryCur = Selection.VATInventoryCur;
	EndDo;
	//) elmi
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Period AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableManagerial.GLAccountCustomerSettlements AS AccountDr,
	|	CASE
	|		WHEN TableManagerial.GLAccountCustomerSettlements.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableManagerial.GLAccountCustomerSettlements.Currency
	//( elmi #11
	//|			THEN TableManagerial.AmountCur
	|			THEN TableManagerial.AmountCur -  TableManagerial.VATAmountCur 
	//) elmi
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN TableManagerial.ProductsOnCommission
	|			THEN TableManagerial.GLAccountVendorSettlements
	|		ELSE TableManagerial.AccountStatementSales
	|	END AS AccountCr,
	|	CASE
	|		WHEN TableManagerial.ProductsOnCommission
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableManagerial.ProductsOnCommission
	//( elmi #11
	//|			THEN TableManagerial.Amount
	|			THEN TableManagerial.Amount - TableManagerial.VATAmount    
	|		ELSE 0
	|	END AS AmountCurCr,
	//|	TableManagerial.Amount AS Amount,
	|	TableManagerial.Amount - TableManagerial.VATAmount  AS Amount,    
	//) elmi
	|	&IncomeReflection AS Content
	|FROM
	|	TemporaryTableInventory AS TableManagerial
	|WHERE
	|	TableManagerial.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|	AND TableManagerial.Amount <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableManagerial.LineNumber,
	|	TableManagerial.Period,
	|	TableManagerial.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableManagerial.GLAccount,
	|	CASE
	|		WHEN TableManagerial.GLAccount.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableManagerial.GLAccount.Currency
	//( elmi #11
	//|			THEN -TableManagerial.AmountCur
	|			THEN -(TableManagerial.AmountCur - TableManagerial.VATAmountCur)
	//) elmi
	|		ELSE 0
	|	END,
	|	TableManagerial.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	//( elmi #11
	//|			THEN -TableManagerial.AmountCur
	|			THEN -(TableManagerial.AmountCur - TableManagerial.VATAmountCur) 
	|		ELSE 0
	|	END,
	//|	-TableManagerial.Amount,
	|	-(TableManagerial.Amount- TableManagerial.VATAmount) ,                     
	//) elmi
	|	&ReversingSupplies
	|FROM
	|	TemporaryTableInventory AS TableManagerial
	|WHERE
	|	TableManagerial.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountForeignCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountForeignCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	&SetOffAdvancePayment
	|FROM
	|	(SELECT
	|		DocumentTable.Period AS Period,
	|		DocumentTable.Company AS Company,
	|		DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|		DocumentTable.CustomerAdvancesGLAccountForeignCurrency AS CustomerAdvancesGLAccountForeignCurrency,
	|		DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|		DocumentTable.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|		SUM(DocumentTable.AmountCur) AS AmountCur,
	|		SUM(DocumentTable.Amount) AS Amount
	|	FROM
	|		(SELECT
	|			DocumentTable.Period AS Period,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|			DocumentTable.CustomerAdvancesGLAccount.Currency AS CustomerAdvancesGLAccountForeignCurrency,
	|			DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|			DocumentTable.GLAccountCustomerSettlements.Currency AS GLAccountCustomerSettlementsCurrency,
	|			DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|			DocumentTable.AmountCur AS AmountCur,
	|			DocumentTable.Amount AS Amount
	|		FROM
	|			TemporaryTablePrepayment AS DocumentTable
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.Counterparty.CustomerAdvancesGLAccount,
	|			DocumentTable.Counterparty.CustomerAdvancesGLAccount.Currency,
	|			DocumentTable.Counterparty.GLAccountCustomerSettlements,
	|			DocumentTable.Counterparty.GLAccountCustomerSettlements.Currency,
	|			DocumentTable.Currency,
	|			0,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Company,
	|		DocumentTable.CustomerAdvancesGLAccount,
	|		DocumentTable.CustomerAdvancesGLAccountForeignCurrency,
	|		DocumentTable.GLAccountCustomerSettlements,
	|		DocumentTable.GLAccountCustomerSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency
	|	
	|	HAVING
	|		(SUM(DocumentTable.Amount) >= 0.005
	|			OR SUM(DocumentTable.Amount) <= -0.005
	|			OR SUM(DocumentTable.AmountCur) >= 0.005
	|			OR SUM(DocumentTable.AmountCur) <= -0.005)) AS DocumentTable
	|WHERE
	|	&OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlements.Currency
	|			THEN -DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccount.Currency
	|			THEN -DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	-DocumentTable.Amount,
	|	&PrepaymentReversal
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	TableManagerial.LineNumber,
	|	TableManagerial.Date,
	|	TableManagerial.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE TableManagerial.GLAccount
	|	END,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences < 0
	|				AND TableManagerial.GLAccount.Currency
	|			THEN TableManagerial.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|			THEN TableManagerial.GLAccount
	|		ELSE &PositiveExchangeDifferenceGLAccount
	|	END,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|				AND TableManagerial.GLAccount.Currency
	|			THEN TableManagerial.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|			THEN TableManagerial.AmountOfExchangeDifferences
	|		ELSE -TableManagerial.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS TableManagerial
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	1,
	|	TableManagerial.Date,
	|	TableManagerial.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|			THEN TableManagerial.GLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|				AND TableManagerial.GLAccountForeignCurrency
	|			THEN TableManagerial.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE TableManagerial.GLAccount
	|	END,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences < 0
	|				AND TableManagerial.GLAccountForeignCurrency
	|			THEN TableManagerial.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|			THEN TableManagerial.AmountOfExchangeDifferences
	|		ELSE -TableManagerial.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference
	|FROM
	|	(SELECT
	|		TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccount AS GLAccount,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccountForeignCurrency AS GLAccountForeignCurrency,
	|		TableExchangeRateDifferencesAccountsReceivable.Currency AS Currency,
	|		SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.GLAccount AS GLAccount,
	|			DocumentTable.GLAccount.Currency AS GLAccountForeignCurrency,
	|			DocumentTable.Currency AS Currency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.GLAccount,
	|			DocumentTable.GLAccount.Currency,
	|			DocumentTable.Currency,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableExchangeRateDifferencesAccountsReceivable
	|	
	|	GROUP BY
	|		TableExchangeRateDifferencesAccountsReceivable.Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccount,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccountForeignCurrency,
	|		TableExchangeRateDifferencesAccountsReceivable.Currency
	|	
	|	HAVING
	|		(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)) AS TableManagerial
	//( elmi #11
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	7 AS Ordering,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Period AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableManagerial.GLAccountCustomerSettlements AS AccountDr,
	|	CASE
	|		WHEN TableManagerial.GLAccountCustomerSettlements.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableManagerial.GLAccountCustomerSettlements.Currency
	|			THEN &VATInventoryCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	&TextVAT AS AccountCr,
	|  UNDEFINED AS CurrencyCr,
	|  0  AS AmountCurCr,
	|  &VATInventory  AS Amount,    
	|  &VAT AS Content
	|FROM
	|	TemporaryTableInventory AS TableManagerial
	|WHERE
	|	TableManagerial.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|	AND &VATInventory <> 0
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	8,
	|	TableManagerial.LineNumber,
	|	TableManagerial.Period,
	|	TableManagerial.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&TextVAT,
	|	UNDEFINED,
	|   0,
	|	TableManagerial.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN -&VATInventoryCur
	|		ELSE 0
	|	END,
	|	-&VATInventory,
	|	&VAT
	|FROM
	|	TemporaryTableInventory AS TableManagerial
	|WHERE
	|	TableManagerial.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|	AND &VATInventory <> 0
	//) elmi
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	Query.SetParameter("SetOffAdvancePayment", NStr("en='Setoff of advance payment';ru='Зачет предоплаты'"));
	Query.SetParameter("PrepaymentReversal", NStr("en='Prepayment reversing';ru='Сторнирование предоплаты'"));
	Query.SetParameter("ReversingSupplies", NStr("en='Delivery reversing';ru='Сторнирование поставки'"));
	Query.SetParameter("IncomeReflection", NStr("en='Sales revenue';ru='Выручка от продажи'"));
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	Query.SetParameter("OperationKind", DocumentRefSalesInvoice.OperationKind);
	//( elmi #11
	Query.SetParameter("VAT", NStr("en=' VAT '"));
	Query.SetParameter("TextVAT",  ChartsOfAccounts.Managerial.Taxes);
	Query.SetParameter("VATInventory", VATInventory);
	Query.SetParameter("VATInventoryCur", VATInventoryCur);
	//) elmi

	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do  
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure // GenerateTableManagerial()

#Region DiscountCards

// Generates values table creating data for posting by the SalesByDiscountCards register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByDiscountCard(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	If DocumentRefSalesInvoice.DiscountCard.IsEmpty() Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("SaleByDiscountCardTable", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Document.DiscountCard AS DiscountCard,
	|	TableSales.Document.DiscountCard.CardOwner AS CardOwner,
	|	SUM(TableSales.Amount) AS Amount
	|FROM
	|	TemporaryTableInventory AS TableSales
	|WHERE
	|	TableSales.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|
	|GROUP BY
	|	TableSales.Period,
	|	TableSales.Document.DiscountCard,
	|	TableSales.Document.DiscountCard.CardOwner";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("SaleByDiscountCardTable", QueryResult.Unload());
	
EndProcedure // GenerateTableSalesByDiscountCard()

#EndRegion

#Region AutomaticDiscounts

// Generates a table of values that contains the data for posting by the register AutomaticDiscountsApplied.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	If DocumentRefSalesInvoice.DiscountsMarkups.Count() = 0 Or Not GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableAutoDiscountsMarkups.Period,
	|	TemporaryTableAutoDiscountsMarkups.DiscountMarkup AS AutomaticDiscount,
	|	TemporaryTableAutoDiscountsMarkups.Amount AS DiscountAmount,
	|	TemporaryTableInventory.ProductsAndServices,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Document AS DocumentDiscounts,
	|	TemporaryTableInventory.Counterparty AS RecipientDiscounts
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableAutoDiscountsMarkups AS TemporaryTableAutoDiscountsMarkups
	|		ON TemporaryTableInventory.ConnectionKey = TemporaryTableAutoDiscountsMarkups.ConnectionKey";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", QueryResult.Unload());
	
EndProcedure // GenerateTableSalesByAutomaticDiscountsApplied()

#EndRegion

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefSalesInvoice, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	CurrencyRatesSliceLast.Currency AS Currency,
	|	CurrencyRatesSliceLast.ExchangeRate AS ExchangeRate,
	|	CurrencyRatesSliceLast.Multiplicity AS Multiplicity
	|INTO TemporaryTableCurrencyRatesSliceLatest
	|FROM
	|	InformationRegister.CurrencyRates.SliceLast(&PointInTime, Currency IN (&AccountingCurrency, &CurrencyNational, &InvoiceCurrency)) AS CurrencyRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CustomerInvoiceInventory.LineNumber AS LineNumber,
	|	CustomerInvoiceInventory.Ref.OperationKind AS OperationKind,
	|	CustomerInvoiceInventory.Ref AS Document,
	|	CustomerInvoiceInventory.Ref.Responsible AS Responsible,
	|	CustomerInvoiceInventory.Ref.BasisDocument AS BasisDocument,
	|	CustomerInvoiceInventory.Ref.Counterparty AS Counterparty,
	|	CustomerInvoiceInventory.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	CustomerInvoiceInventory.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	CustomerInvoiceInventory.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	CustomerInvoiceInventory.Ref.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	CustomerInvoiceInventory.Ref.Contract AS Contract,
	|	CustomerInvoiceInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|				OR CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|				OR CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN &Company
	|		ELSE UNDEFINED
	|	END AS CorrOrganization,
	|	CustomerInvoiceInventory.Ref.Department AS DepartmentSales,
	|	CustomerInvoiceInventory.ProductsAndServices.BusinessActivity AS BusinessActivitySales,
	|	CustomerInvoiceInventory.ProductsAndServices.BusinessActivity.GLAccountRevenueFromSales AS AccountStatementSales,
	|	CustomerInvoiceInventory.ProductsAndServices.BusinessActivity.GLAccountCostOfSales AS GLAccountCost,
	|	CustomerInvoiceInventory.ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|	CustomerInvoiceInventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|				OR CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|				OR CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN CustomerInvoiceInventory.Ref.Counterparty
	|		ELSE UNDEFINED
	|	END AS StructuralUnitCorr,
	|	CASE
	|		WHEN CustomerInvoiceInventory.Ref.StructuralUnit.OrderWarehouse
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS OrderWarehouse,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN CustomerInvoiceInventory.Ref.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	CustomerInvoiceInventory.ProductsAndServices.InventoryGLAccount AS GLAccount,
	|	CASE
	|		WHEN CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|				OR CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|				OR CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN CustomerInvoiceInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE UNDEFINED
	|	END AS CorrGLAccount,
	|	CASE
	|		WHEN &UseBatches
	|				AND CustomerInvoiceInventory.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				AND CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsOnCommission,
	|	CustomerInvoiceInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|				OR CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|				OR CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN CustomerInvoiceInventory.ProductsAndServices
	|		ELSE UNDEFINED
	|	END AS ProductsAndServicesCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN CustomerInvoiceInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|				OR CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|				OR CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN CASE
	|					WHEN &UseCharacteristics
	|						THEN CustomerInvoiceInventory.Characteristic
	|					ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|				END
	|		ELSE UNDEFINED
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN CustomerInvoiceInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|				OR CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|				OR CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN CASE
	|					WHEN &UseBatches
	|						THEN CustomerInvoiceInventory.Batch
	|					ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|				END
	|		ELSE UNDEFINED
	|	END AS BatchCorr,
	|	CASE
	|		WHEN CustomerInvoiceInventory.Order REFS Document.CustomerOrder
	|				AND CustomerInvoiceInventory.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN CustomerInvoiceInventory.Order
	|		WHEN CustomerInvoiceInventory.Order REFS Document.PurchaseOrder
	|				AND CustomerInvoiceInventory.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN CustomerInvoiceInventory.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	CASE
	|		WHEN CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|				OR CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|				OR CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN CASE
	|					WHEN CustomerInvoiceInventory.Order REFS Document.CustomerOrder
	|							AND CustomerInvoiceInventory.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|						THEN CustomerInvoiceInventory.Order
	|					WHEN CustomerInvoiceInventory.Order REFS Document.PurchaseOrder
	|							AND CustomerInvoiceInventory.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|						THEN CustomerInvoiceInventory.Order
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS CorrOrder,
	|	CASE
	|		WHEN VALUETYPE(CustomerInvoiceInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN CustomerInvoiceInventory.Quantity
	|		ELSE CustomerInvoiceInventory.Quantity * CustomerInvoiceInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(CustomerInvoiceInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN CustomerInvoiceInventory.Reserve
	|		ELSE CustomerInvoiceInventory.Reserve * CustomerInvoiceInventory.MeasurementUnit.Factor
	|	END AS Reserve,
	|	CustomerInvoiceInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN CustomerInvoiceInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN CustomerInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|						THEN CustomerInvoiceInventory.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE CustomerInvoiceInventory.VATAmount * CustomerInvoiceInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * CustomerInvoiceInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN CustomerInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|				THEN CustomerInvoiceInventory.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE CustomerInvoiceInventory.VATAmount * CustomerInvoiceInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * CustomerInvoiceInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountVATPurchaseSale,
	|	CAST(CASE
	|			WHEN CustomerInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|				THEN CustomerInvoiceInventory.Total * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE CustomerInvoiceInventory.Total * CustomerInvoiceInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * CustomerInvoiceInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN CustomerInvoiceInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN CustomerInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|						THEN CustomerInvoiceInventory.VATAmount * RegCurrencyRates.ExchangeRate * CustomerInvoiceInventory.Ref.Multiplicity / (CustomerInvoiceInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE CustomerInvoiceInventory.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN CustomerInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|				THEN CustomerInvoiceInventory.Total * RegCurrencyRates.ExchangeRate * CustomerInvoiceInventory.Ref.Multiplicity / (CustomerInvoiceInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE CustomerInvoiceInventory.Total
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CustomerInvoiceInventory.Total AS SettlementsAmountTakenPassed,
	|	CustomerInvoiceInventory.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	CustomerInvoiceInventory.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	CustomerInvoiceInventory.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	CustomerInvoiceInventory.ConnectionKey
	|INTO TemporaryTableInventory
	|FROM
	|	Document.CustomerInvoice.Inventory AS CustomerInvoiceInventory
	|		LEFT JOIN TemporaryTableCurrencyRatesSliceLatest AS ManagCurrencyRates
	|		ON (ManagCurrencyRates.Currency = &AccountingCurrency)
	|		LEFT JOIN TemporaryTableCurrencyRatesSliceLatest AS RegCurrencyRates
	|		ON (RegCurrencyRates.Currency = &CurrencyNational)
	|WHERE
	|	CustomerInvoiceInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.Counterparty AS Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	DocumentTable.Ref.Contract AS Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentTable.Order AS Order,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivitySales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	DocumentTable.Ref.BasisDocument AS BasisDocument,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN Not DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = Type(Document.Netting)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE CASE
	|				WHEN DocumentTable.Document REFS Document.PaymentExpense
	|					THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Item
	|				WHEN DocumentTable.Document REFS Document.CashReceipt
	|					THEN CAST(DocumentTable.Document AS Document.CashReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashPayment
	|					THEN CAST(DocumentTable.Document AS Document.CashPayment).Item
	|				WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|					THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Item
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|			END
	|	END AS Item,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN DocumentTable.Document REFS Document.PaymentExpense
	|						THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Date
	|					WHEN DocumentTable.Document REFS Document.CashReceipt
	|						THEN CAST(DocumentTable.Document AS Document.CashReceipt).Date
	|					WHEN DocumentTable.Document REFS Document.CashPayment
	|						THEN CAST(DocumentTable.Document AS Document.CashPayment).Date
	|					WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|						THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Date
	|					WHEN DocumentTable.Document REFS Document.Netting
	|						THEN CAST(DocumentTable.Document AS Document.Netting).Date
	|				END
	|		ELSE DocumentTable.Ref.Date
	|	END AS DocumentDate,
	|	SUM(CAST(DocumentTable.PaymentAmount * DocumentCurrencyExchangeRateSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * DocumentCurrencyExchangeRateSliceLast.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.CustomerInvoice.Prepayment AS DocumentTable
	|		LEFT JOIN TemporaryTableCurrencyRatesSliceLatest AS AccountingCurrencyRatesSliceLast
	|		ON (AccountingCurrencyRatesSliceLast.Currency = &AccountingCurrency)
	|		LEFT JOIN TemporaryTableCurrencyRatesSliceLatest AS DocumentCurrencyExchangeRateSliceLast
	|		ON (DocumentCurrencyExchangeRateSliceLast.Currency = &InvoiceCurrency)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Document,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount,
	|	DocumentTable.Ref.OperationKind,
	|	CASE
	|		WHEN Not DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = Type(Document.Netting)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE CASE
	|				WHEN DocumentTable.Document REFS Document.PaymentExpense
	|					THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Item
	|				WHEN DocumentTable.Document REFS Document.CashReceipt
	|					THEN CAST(DocumentTable.Document AS Document.CashReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashPayment
	|					THEN CAST(DocumentTable.Document AS Document.CashPayment).Item
	|				WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|					THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Item
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN DocumentTable.Document REFS Document.PaymentExpense
	|						THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Date
	|					WHEN DocumentTable.Document REFS Document.CashReceipt
	|						THEN CAST(DocumentTable.Document AS Document.CashReceipt).Date
	|					WHEN DocumentTable.Document REFS Document.CashPayment
	|						THEN CAST(DocumentTable.Document AS Document.CashPayment).Date
	|					WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|						THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Date
	|					WHEN DocumentTable.Document REFS Document.Netting
	|						THEN CAST(DocumentTable.Document AS Document.Netting).Date
	|				END
	|		ELSE DocumentTable.Ref.Date
	|	END,
	|	DocumentTable.Ref.BasisDocument,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CustomerInvoiceDiscountsMarkups.ConnectionKey,
	|	CustomerInvoiceDiscountsMarkups.DiscountMarkup,
	|	CAST(CASE
	|			WHEN CustomerInvoiceDiscountsMarkups.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CustomerInvoiceDiscountsMarkups.Amount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE CustomerInvoiceDiscountsMarkups.Amount * CustomerInvoiceDiscountsMarkups.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * CustomerInvoiceDiscountsMarkups.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CustomerInvoiceDiscountsMarkups.Ref.Date AS Period,
	|	CustomerInvoiceDiscountsMarkups.Ref.StructuralUnit
	|INTO TemporaryTableAutoDiscountsMarkups
	|FROM
	|	Document.CustomerInvoice.DiscountsMarkups AS CustomerInvoiceDiscountsMarkups
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.AccountingCurrency AS ConstantAccountingCurrency)) AS ManagCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.NationalCurrency AS ConstantNationalCurrency)) AS RegCurrencyRates
	|		ON (TRUE),
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|WHERE
	|	CustomerInvoiceDiscountsMarkups.Ref = &Ref
	|	AND CustomerInvoiceDiscountsMarkups.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CustomerInvoiceSerialNumbers.ConnectionKey,
	|	CustomerInvoiceSerialNumbers.SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.CustomerInvoice.SerialNumbers AS CustomerInvoiceSerialNumbers
	|WHERE
	|	CustomerInvoiceSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
	|	AND NOT CustomerInvoiceSerialNumbers.Ref.StructuralUnit.OrderWarehouse";
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	Query.SetParameter("CurrencyNational", Constants.NationalCurrency.Get());
	Query.SetParameter("InvoiceCurrency", DocumentRefSalesInvoice.DocumentCurrency);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	SmallBusinessServer.GenerateTransactionsTable(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCustomerInvoicePositingGenerateTable");
	
	GenerateTablePurchasing(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableSales(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableProductRelease(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableInventoryInWarehouses(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableInventoryForExpenseFromWarehouses(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableInventoryReceived(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableInventoryTransferred(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableCustomerOrders(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTablePurchaseOrders(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableInventoryDemand(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	// DiscountCards
	GenerateTableSalesByDiscountCard(DocumentRefSalesInvoice, StructureAdditionalProperties);
	// AutomaticDiscounts
	GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCustomerInvoicePositingGenerateTableInventory");
	
	GenerateTableInventory(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCustomerInvoicePositingGenerateTableIncomeAndExpenses");
	
	GenerateTableIncomeAndExpensesRetained(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesUndistributed(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCustomerInvoicePositingGenerateTableManagement");
	
	GenerateTableManagerial(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefSalesInvoice, StructureAdditionalProperties);	
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefSalesInvoice, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", "MovementsInventoryInWarehousesChange",
	// "RegisterRecordsInventoryFromWarehousesChange",
	// "MovementsInventoryPassedChange", "RegisterRecordsInventoryReceivedChange",
	// "RegisterRecordsOrdersPlacementChange", "RegisterRecordsInventoryDemandChange" contain records, it is
	// required to control goods implementation.
		
	If StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryFromWarehousesChange 
	 OR StructureTemporaryTables.RegisterRecordsInventoryTransferredChange 
	 OR StructureTemporaryTables.RegisterRecordsInventoryReceivedChange 
	 OR StructureTemporaryTables.RegisterRecordsCustomerOrdersChange 
	 OR StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryDemandChange
	 OR StructureTemporaryTables.RegisterRecordsAccountsReceivableChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryInWarehousesChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.ProductsAndServices AS ProductsAndServicesPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Cell AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryInWarehousesOfBalance.ProductsAndServices.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		INNER JOIN AccumulationRegister.InventoryInWarehouses.Balance(&ControlTime, ) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.ProductsAndServices = InventoryInWarehousesOfBalance.ProductsAndServices
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|			AND (ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
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
		|	RegisterRecordsInventoryTransferredChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryTransferredChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryTransferredChange.ProductsAndServices AS ProductsAndServicesPresentation,
		|	RegisterRecordsInventoryTransferredChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryTransferredChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryTransferredChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsInventoryTransferredChange.Contract AS ContractPresentation,
		|	RegisterRecordsInventoryTransferredChange.Order AS OrderPresentation,
		|	RegisterRecordsInventoryTransferredChange.ReceptionTransmissionType AS ReceptionTransmissionTypePresentation,
		|	InventoryTransferredBalances.ProductsAndServices.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryTransferredChange.QuantityChange, 0) + ISNULL(InventoryTransferredBalances.QuantityBalance, 0) AS BalanceInventoryTransferred,
		|	ISNULL(InventoryTransferredBalances.QuantityBalance, 0) AS QuantityBalanceInventoryTransferred,
		|	ISNULL(RegisterRecordsInventoryTransferredChange.SettlementsAmountChange, 0) + ISNULL(InventoryTransferredBalances.SettlementsAmountBalance, 0) AS SettlementsAmountInventoryTransferred,
		|	ISNULL(InventoryTransferredBalances.SettlementsAmountBalance, 0) AS SettlementsAmountBalanceInventoryTransferred
		|FROM
		|	RegisterRecordsInventoryTransferredChange AS RegisterRecordsInventoryTransferredChange
		|		INNER JOIN AccumulationRegister.InventoryTransferred.Balance(&ControlTime, ) AS InventoryTransferredBalances
		|		ON RegisterRecordsInventoryTransferredChange.Company = InventoryTransferredBalances.Company
		|			AND RegisterRecordsInventoryTransferredChange.ProductsAndServices = InventoryTransferredBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryTransferredChange.Characteristic = InventoryTransferredBalances.Characteristic
		|			AND RegisterRecordsInventoryTransferredChange.Batch = InventoryTransferredBalances.Batch
		|			AND RegisterRecordsInventoryTransferredChange.Counterparty = InventoryTransferredBalances.Counterparty
		|			AND RegisterRecordsInventoryTransferredChange.Contract = InventoryTransferredBalances.Contract
		|			AND RegisterRecordsInventoryTransferredChange.Order = InventoryTransferredBalances.Order
		|			AND RegisterRecordsInventoryTransferredChange.ReceptionTransmissionType = InventoryTransferredBalances.ReceptionTransmissionType
		|			AND (ISNULL(InventoryTransferredBalances.QuantityBalance, 0) < 0
		|				OR ISNULL(InventoryTransferredBalances.SettlementsAmountBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryReceivedChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryReceivedChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryReceivedChange.ProductsAndServices AS ProductsAndServicesPresentation,
		|	RegisterRecordsInventoryReceivedChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryReceivedChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryReceivedChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsInventoryReceivedChange.Contract AS ContractPresentation,
		|	RegisterRecordsInventoryReceivedChange.Order AS OrderPresentation,
		|	RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType AS ReceptionTransmissionTypePresentation,
		|	InventoryReceivedBalances.ProductsAndServices.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryReceivedChange.QuantityChange, 0) + ISNULL(InventoryReceivedBalances.QuantityBalance, 0) AS BalanceInventoryReceived,
		|	ISNULL(InventoryReceivedBalances.QuantityBalance, 0) AS QuantityBalanceInventoryReceived,
		|	ISNULL(RegisterRecordsInventoryReceivedChange.SettlementsAmountChange, 0) + ISNULL(InventoryReceivedBalances.SettlementsAmountBalance, 0) AS SettlementsAmountInventoryReceived,
		|	ISNULL(InventoryReceivedBalances.SettlementsAmountBalance, 0) AS SettlementsAmountBalanceInventoryReceived
		|FROM
		|	RegisterRecordsInventoryReceivedChange AS RegisterRecordsInventoryReceivedChange
		|		INNER JOIN AccumulationRegister.InventoryReceived.Balance(&ControlTime, ) AS InventoryReceivedBalances
		|		ON RegisterRecordsInventoryReceivedChange.Company = InventoryReceivedBalances.Company
		|			AND RegisterRecordsInventoryReceivedChange.ProductsAndServices = InventoryReceivedBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryReceivedChange.Characteristic = InventoryReceivedBalances.Characteristic
		|			AND RegisterRecordsInventoryReceivedChange.Batch = InventoryReceivedBalances.Batch
		|			AND RegisterRecordsInventoryReceivedChange.Counterparty = InventoryReceivedBalances.Counterparty
		|			AND RegisterRecordsInventoryReceivedChange.Contract = InventoryReceivedBalances.Contract
		|			AND RegisterRecordsInventoryReceivedChange.Order = InventoryReceivedBalances.Order
		|			AND RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType = InventoryReceivedBalances.ReceptionTransmissionType
		|			AND (ISNULL(InventoryReceivedBalances.QuantityBalance, 0) < 0
		|				OR ISNULL(InventoryReceivedBalances.SettlementsAmountBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsCustomerOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsCustomerOrdersChange.Company AS CompanyPresentation,
		|	RegisterRecordsCustomerOrdersChange.CustomerOrder AS OrderPresentation,
		|	RegisterRecordsCustomerOrdersChange.ProductsAndServices AS ProductsAndServicesPresentation,
		|	RegisterRecordsCustomerOrdersChange.Characteristic AS CharacteristicPresentation,
		|	CustomerOrdersBalances.ProductsAndServices.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsCustomerOrdersChange.QuantityChange, 0) + ISNULL(CustomerOrdersBalances.QuantityBalance, 0) AS BalanceCustomerOrders,
		|	ISNULL(CustomerOrdersBalances.QuantityBalance, 0) AS QuantityBalanceCustomerOrders
		|FROM
		|	RegisterRecordsCustomerOrdersChange AS RegisterRecordsCustomerOrdersChange
		|		INNER JOIN AccumulationRegister.CustomerOrders.Balance(&ControlTime, ) AS CustomerOrdersBalances
		|		ON RegisterRecordsCustomerOrdersChange.Company = CustomerOrdersBalances.Company
		|			AND RegisterRecordsCustomerOrdersChange.CustomerOrder = CustomerOrdersBalances.CustomerOrder
		|			AND RegisterRecordsCustomerOrdersChange.ProductsAndServices = CustomerOrdersBalances.ProductsAndServices
		|			AND RegisterRecordsCustomerOrdersChange.Characteristic = CustomerOrdersBalances.Characteristic
		|			AND (ISNULL(CustomerOrdersBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPurchaseOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsPurchaseOrdersChange.Company AS CompanyPresentation,
		|	RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS OrderPresentation,
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	RegisterRecordsAccountsReceivableChange.Company AS CompanyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Contract AS ContractPresentation,
		|	RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency AS CurrencyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Document AS DocumentPresentation,
		|	RegisterRecordsAccountsReceivableChange.Order AS OrderPresentation,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite - ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AdvanceAmountsReceived,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
		|		INNER JOIN AccumulationRegister.AccountsReceivable.Balance(&ControlTime, ) AS AccountsReceivableBalances
		|		ON RegisterRecordsAccountsReceivableChange.Company = AccountsReceivableBalances.Company
		|			AND RegisterRecordsAccountsReceivableChange.Counterparty = AccountsReceivableBalances.Counterparty
		|			AND RegisterRecordsAccountsReceivableChange.Contract = AccountsReceivableBalances.Contract
		|			AND RegisterRecordsAccountsReceivableChange.Document = AccountsReceivableBalances.Document
		|			AND RegisterRecordsAccountsReceivableChange.Order = AccountsReceivableBalances.Order
		|			AND RegisterRecordsAccountsReceivableChange.SettlementsType = AccountsReceivableBalances.SettlementsType
		|			AND (CASE
		|				WHEN RegisterRecordsAccountsReceivableChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|					THEN ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) > 0
		|				ELSE ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) < 0
		|			END)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty()
			OR Not ResultsArray[4].IsEmpty()
			OR Not ResultsArray[5].IsEmpty()
			OR Not ResultsArray[6].IsEmpty()
			OR Not ResultsArray[7].IsEmpty() Then
			DocumentObjectSalesInvoice = DocumentRefSalesInvoice.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// The negative balance of transferred inventory.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryTransferredRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryReceivedRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on customer order.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			SmallBusinessServer.ShowMessageAboutPostingToCustomerOrdersRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the order to the vendor.
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			SmallBusinessServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for inventory.
		If Not ResultsArray[6].IsEmpty() Then
			QueryResultSelection = ResultsArray[6].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[7].IsEmpty() Then
			QueryResultSelection = ResultsArray[7].Select();
			SmallBusinessServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure // RunControl()

#Region DataLoadFromFile

Procedure SetImportParametersFromFileToTP(Parameters) Export
	
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
	
	UseCharacteristics = ?(ExportableData.Columns.Find("Characteristic") <> Undefined, True, False);
	UseBatches = ?(ExportableData.Columns.Find("Batch") <> Undefined, True, False);
	UseMeasurementUnits = ?(ExportableData.Columns.Find("MeasurementUnit") <> Undefined, True, False);
	
	Query = New Query;
	
	Query.Text = "SELECT
	               |	Products.ProductsAndServices AS Description,
	               |	Products.Barcode AS Barcode,
	               |	Products.SKU AS SKU,
	               |	Products.ID AS ID
	               |INTO Products
	               |FROM
	               |	&Products AS Products
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	ProductsAndServicesBarcodes.Barcode AS Barcode,
	               |	ProductsAndServicesBarcodes.ProductsAndServices.Ref AS ProductsAndServicesRef,
	               |	Products.ID AS ID
	               |INTO ProductsAndServicesByBarcodes
	               |FROM
	               |	Products AS Products
	               |		LEFT JOIN InformationRegister.ProductsAndServicesBarcodes AS ProductsAndServicesBarcodes
	               |		ON (ProductsAndServicesBarcodes.Barcode LIKE Products.Barcode)
	               |WHERE
	               |	Not ProductsAndServicesBarcodes.ProductsAndServices.Ref IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	ProductsAndServices.Ref AS Ref,
	               |	ProductsAndServices.SKU AS SKU,
	               |	ProductsAndServices.Code AS Code,
	               |	Products.ID AS ID
	               |INTO ProductsAndServicesSKU
	               |FROM
	               |	Products AS Products
	               |		LEFT JOIN ProductsAndServicesByBarcodes AS ProductsAndServicesByBarcodes
	               |		ON (ProductsAndServicesByBarcodes.ID = Products.ID)
	               |		LEFT JOIN Catalog.ProductsAndServices AS ProductsAndServices
	               |		ON (ProductsAndServices.SKU LIKE Products.SKU)
	               |			AND ((CAST(ProductsAndServices.SKU AS String(25))) <> """")
	               |			AND (NOT ProductsAndServices.SKU IS NULL )
	               |WHERE
	               |	ProductsAndServicesByBarcodes.ID IS NULL 
	               |	AND Not ProductsAndServices.Ref IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	ProductsAndServices.Ref AS Ref,
	               |	Products.ID AS ID
	               |FROM
	               |	Products AS Products
	               |		LEFT JOIN ProductsAndServicesByBarcodes AS ProductsAndServicesByBarcodes
	               |		ON (ProductsAndServicesByBarcodes.ID = Products.ID)
	               |		LEFT JOIN ProductsAndServicesSKU AS ProductsAndServicesSKU
	               |		ON (ProductsAndServicesSKU.ID = Products.ID)
	               |		LEFT JOIN Catalog.ProductsAndServices AS ProductsAndServices
	               |		ON (ProductsAndServices.Description LIKE Products.Description)
	               |			AND ((CAST(ProductsAndServices.Description AS String(250))) <> """")
	               |			AND (NOT ProductsAndServices.Description IS NULL )
	               |WHERE
	               |	ProductsAndServicesByBarcodes.ID IS NULL 
	               |	AND ProductsAndServicesSKU.ID IS NULL 
	               |	AND Not ProductsAndServices.Ref IS NULL 
	               |
	               |UNION ALL
	               |
	               |SELECT
	               |	ProductsAndServicesByBarcodes.ProductsAndServicesRef,
	               |	ProductsAndServicesByBarcodes.ID
	               |FROM
	               |	ProductsAndServicesByBarcodes AS ProductsAndServicesByBarcodes
	               |
	               |UNION ALL
	               |
	               |SELECT
	               |	ProductsAndServicesSKU.Ref,
	               |	ProductsAndServicesSKU.ID
	               |FROM
	               |	ProductsAndServicesSKU AS ProductsAndServicesSKU
	               |
	               |ORDER BY
	               |	ID";
	
	Query.SetParameter("Products", ExportableData);
	QueryResult = Query.Execute().Unload();
	
	For Each ImportedDataRow IN ExportableData Do
		
		Product = MappingTable.Add();
		Product.Quantity = ImportedDataRow.Quantity;
		Product.Price = ImportedDataRow.Price;
		Product.Amount = Product.Quantity * Product.Price;
		Product.ID = ImportedDataRow.ID; 
		
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
			
			If VATRate = Undefined Then
				Product.VATRate = Product.ProductsAndServices.VATRate;
			EndIf;
			
			ProductsAndServicesPropertiesByBarcode = ProductsAndServicesPropertiesByBarcode(Product.ProductsAndServices, ImportedDataRow.Barcode);
			If UseCharacteristics Then
				If ValueIsFilled(ProductsAndServicesPropertiesByBarcode.Characteristic) Then
					Product.Characteristic = ProductsAndServicesPropertiesByBarcode.Characteristic;
				ElsIf ValueIsFilled(ImportedDataRow.Characteristic) Then
					Product.Characteristic = Catalogs.ProductsAndServicesCharacteristics.FindByDescription(ImportedDataRow.Characteristic,,, Product.ProductsAndServices);
				EndIf;
			EndIf;
			
			If UseBatches Then
				If ValueIsFilled(ProductsAndServicesPropertiesByBarcode.Batch) Then
					Product.Batch = ProductsAndServicesPropertiesByBarcode.Batch;
				ElsIf ValueIsFilled(ImportedDataRow.Batch) Then
					Product.Batch = Catalogs.ProductsAndServicesBatches.FindByDescription(ImportedDataRow.Batch,,, Product.ProductsAndServices);
				EndIf;
			EndIf;
			
			If UseMeasurementUnits Then
				If ValueIsFilled(ProductsAndServicesPropertiesByBarcode.MeasurementUnit) Then
					MeasurementUnit = ProductsAndServicesPropertiesByBarcode.MeasurementUnit;
				ElsIf ValueIsFilled(Product.ProductsAndServices) Then
					MeasurementUnit = Catalogs.UOM.FindByDescription(ImportedDataRow.MeasurementUnit, False, , Product.ProductsAndServices);
					If Not ValueIsFilled(MeasurementUnit) Then
						MeasurementUnit = Product.ProductsAndServices.MeasurementUnit;
						If Not ValueIsFilled(MeasurementUnit) Then 
							MeasurementUnit = Catalogs.UOMClassifier.pcs;
						EndIf;
					EndIf;
				Else
					If Not IsBlankString(ImportedDataRow.MeasurementUnit) Then
						MeasurementUnit = Catalogs.UOMClassifier.FindByDescription(ImportedDataRow.MeasurementUnit, False);
					Else
						MeasurementUnit = Catalogs.UOMClassifier.pcs;
					EndIf;
				EndIf;
				Product.MeasurementUnit = MeasurementUnit;
			EndIf;
			
		ElsIf StringProductsAndServices.Count() > 1 Then 
			AmbiguityRecord = AmbiguitiesList.Add();
			AmbiguityRecord.ID = StringProductsAndServices[0].ID; 
			AmbiguityRecord.Column = "ProductsAndServices";
			
			If UseMeasurementUnits Then
				Product.MeasurementUnit =  Catalogs.UOMClassifier.pcs;
			EndIf;
		EndIf;
	EndDo;
	
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
		QueryText = "SELECT
		               |	ProductsAndServices.Ref
		               |FROM
		               |	Catalog.ProductsAndServices AS ProductsAndServices
		               |WHERE ";
					   
		Delimiter = "";
		TextWhereName = "";
		TextWhereSKU = "";
		
		If ValueIsFilled(ImportedValueString.SKU) Then
			TextWhereSKU = "ProductsAndServices.SKU = &SKU";
			Query.SetParameter("SKU", ImportedValueString.SKU);
			Delimiter = " OR ";
		EndIf;
		
		If ValueIsFilled(ImportedValueString.ProductsAndServices) Then
			TextWhereName = "Name.Name = &Name";
			Query.SetParameter("Description", ImportedValueString.ProductsAndServices);
		EndIf;
		
		Query.Text = QueryText + TextWhereSKU + Delimiter + TextWhereName;
		
		QueryResult = Query.Execute();
		SelectionDetailRecords = QueryResult.Select();
		While SelectionDetailRecords.Next() Do
			AmbiguitiesList.Add(SelectionDetailRecords.Ref);
		EndDo;
	EndIf;
	
EndProcedure

// Service function
//
Function ProductsAndServicesPropertiesByBarcode(ProductsAndServices, Barcode)
	
	ProductsAndServicesProperties = New Structure("Characteristic, Batch, MeasurementUnit");
	
	If ValueIsFilled(Barcode) Then
		Query = New Query("SELECT
		                      |	ProductsAndServicesBarcodes.Characteristic,
		                      |	ProductsAndServicesBarcodes.Batch,
		                      |	ProductsAndServicesBarcodes.MeasurementUnit
		                      |FROM
		                      |	InformationRegister.ProductsAndServicesBarcodes AS ProductsAndServicesBarcodes
		                      |WHERE
		                      |	ProductsAndServicesBarcodes.Barcode = &Barcode
		                      |	AND ProductsAndServicesBarcodes.ProductsAndServices = &ProductsAndServices");
		Query.SetParameter("Barcode", Barcode);
		Query.SetParameter("ProductsAndServices", ProductsAndServices);
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			ProductsAndServicesProperties.Characteristic = Selection.Characteristic;
			ProductsAndServicesProperties.Batch = Selection.Batch;
			ProductsAndServicesProperties.MeasurementUnit = Selection.MeasurementUnit;
		EndIf;
	EndIf;
	
	Return ProductsAndServicesProperties;
EndFunction

#EndRegion

#Region PrintInterface

// Procedure of generating printing form of the Certificate of services provided
//
Function GenerateCompletionCertificate(SpreadsheetDocument, CurrentDocument, Errors)
	
	UseVAT	= GetFunctionalOption("UseVAT");
	
	Query = New Query;
	Query.SetParameter("CurrentDocument", CurrentDocument);
	
	Query.Text = 
	"SELECT
	|	CustomerInvoice.Date AS DocumentDate,
	|	CustomerInvoice.Company AS Company,
	|	CustomerInvoice.Counterparty AS Counterparty,
	|	CustomerInvoice.AmountIncludesVAT AS AmountIncludesVAT,
	|	CustomerInvoice.DocumentCurrency AS DocumentCurrency,
	|	CustomerInvoice.Number AS DocumentNumber,
	|	CustomerInvoice.Company.Prefix AS Prefix,
	|	CustomerInvoice.Released AS ResponsiblePresentation,
	|	CustomerInvoice.Inventory.(
	|		LineNumber AS LineNumber,
	|		CASE
	|			WHEN (CAST(CustomerInvoice.Inventory.ProductsAndServices.DescriptionFull AS String(100))) = """"
	|				THEN CustomerInvoice.Inventory.ProductsAndServices.Description
	|			ELSE CustomerInvoice.Inventory.ProductsAndServices.DescriptionFull
	|		END AS InventoryItem,
	|		ProductsAndServices.SKU AS SKU,
	|		ProductsAndServices.Code AS Code,
	|		MeasurementUnit AS UnitOfMeasure,
	|		Quantity AS Quantity,
	|		Price AS Price,
	|		Amount AS Amount,
	|		VATAmount,
	|		Total,
	|		Characteristic,
	|		Content,
	|		DiscountMarkupPercent,
	|		CASE
	|			WHEN CustomerInvoice.Inventory.DiscountMarkupPercent <> 0
	|					OR CustomerInvoice.Inventory.AutomaticDiscountAmount <> 0
	|				THEN 1
	|			ELSE 0
	|		END AS IsDiscount,
	|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|		AutomaticDiscountAmount
	|	)
	|FROM
	|	Document.CustomerInvoice AS CustomerInvoice
	|WHERE
	|	CustomerInvoice.Ref = &CurrentDocument
	|
	|ORDER BY
	|	LineNumber";
	
	Header = Query.Execute().Select();
	Header.Next();
	
	LinesSelectionInventory = Header.Inventory.Select();
	
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_CustomerInvoice_CompletionCertificate";
	
	Template = PrintManagement.PrintedFormsTemplate("Document.CustomerInvoice.PF_MXL_CompletionCertificate");
	InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
	InfoAboutCounterparty = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
	
	If Template.Areas.Find("TitleWithLogo") <> Undefined
		AND Template.Areas.Find("TitleWithoutLogo") <> Undefined Then
		
		If ValueIsFilled(Header.Company.LogoFile) Then
			
			TemplateArea = Template.GetArea("TitleWithLogo");
			TemplateArea.Parameters.Fill(Header);
			
			PictureData = AttachedFiles.GetFileBinaryData(Header.Company.LogoFile);
			If ValueIsFilled(PictureData) Then
				
				TemplateArea.Drawings.Logo.Picture = New Picture(PictureData);
				
			EndIf;
			
		Else // If images are not selected, print regular header
			
			TemplateArea = Template.GetArea("TitleWithoutLogo");
			TemplateArea.Parameters.Fill(Header);
			
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
	Else
		
		MessageText = NStr("en='ATTENTION! Perhaps, user template is used default methods for the accounts printing may work incorrectly.';ru='ВНИМАНИЕ! Возможно используется пользовательский макет. Штатный механизм печати счетов может работать некоректно.'");
		CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
		
	EndIf;
	
	TemplateArea = Template.GetArea("InvoiceHeaderVendor");
	
	TemplateArea.Parameters.Fill(Header);
	
	VendorPresentation	= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
	
	TemplateArea.Parameters.VendorPresentation	= VendorPresentation;
	TemplateArea.Parameters.VendorAddress		= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "LegalAddress");
	TemplateArea.Parameters.VendorPhoneFax		= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "PhoneNumbers,Fax");
	TemplateArea.Parameters.VendorEmail			= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "Email");
	
	SpreadsheetDocument.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("InvoiceHeaderCustomer");
	
	TemplateArea.Parameters.CustomerPresentation	= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr");;
	TemplateArea.Parameters.CustomerAddress			= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "LegalAddress");;
	TemplateArea.Parameters.CustomerPhoneFax		= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "PhoneNumbers,Fax");;
	
	SpreadsheetDocument.Put(TemplateArea);
	
	AreDiscounts = Header.Inventory.Unload().Total("IsDiscount") <> 0;
	If AreDiscounts Then
		
		TemplateArea = Template.GetArea("TableHeaderWithDiscount");
		SpreadsheetDocument.Put(TemplateArea);
		TemplateArea = Template.GetArea("TableRowWithDiscount");
		
	Else
		
		TemplateArea = Template.GetArea("TableHeader");
		SpreadsheetDocument.Put(TemplateArea);
		TemplateArea = Template.GetArea("TableRow");
		
	EndIf;
	
	FillStructureSection = New Structure;
	
	PPServices	= 0;
	Amount		= 0;
	VATAmount	= 0;
	Total		= 0;
	Quantity	= 0;
	While LinesSelectionInventory.Next() Do
	
		If LinesSelectionInventory.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.Service Then
			
			Continue;
			
		EndIf;
		
		FillStructureSection.Clear();
		
		TemplateArea.Parameters.Fill(LinesSelectionInventory);
		
		PPServices = PPServices + 1;
		FillStructureSection.Insert("LineNumber", PPServices);
		
		ServiceDescription = ?(ValueIsFilled(LinesSelectionInventory.Content),
			LinesSelectionInventory.Content,
			SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU));
			
		FillStructureSection.Insert("ServiceDescription", ServiceDescription);
		
		If AreDiscounts Then
			
			If LinesSelectionInventory.DiscountMarkupPercent = 100 Then
				
				Discount = LinesSelectionInventory.Price * LinesSelectionInventory.Quantity;
				
				FillStructureSection.Insert("Discount", 			Discount);
				FillStructureSection.Insert("AmountWithoutDiscount",	Discount);
				
			ElsIf LinesSelectionInventory.DiscountMarkupPercent = 0 AND LinesSelectionInventory.AutomaticDiscountAmount = 0 Then
				FillStructureSection.Insert("Discount", 			0);
				FillStructureSection.Insert("AmountWithoutDiscount",	LinesSelectionInventory.Amount);
				
			Else
				
				Discount = LinesSelectionInventory.Quantity * LinesSelectionInventory.Price - LinesSelectionInventory.Amount; // AutomaticDiscounts
				FillStructureSection.Insert("Discount", 			Discount);
				FillStructureSection.Insert("AmountWithoutDiscount",	LinesSelectionInventory.Amount + Discount);
				
			EndIf;
			
		EndIf;
		
		TemplateArea.Parameters.Fill(FillStructureSection);
		SpreadsheetDocument.Put(TemplateArea);
		
		Amount		= Amount 	+ LinesSelectionInventory.Amount;
		VATAmount	= VATAmount	+ LinesSelectionInventory.VATAmount;
		Total		= Total + LinesSelectionInventory.Total;
		Quantity	= Quantity+ 1;
		
	EndDo;
	
	TemplateArea = Template.GetArea("Subtotal");
	TemplateArea.Parameters.TitleSubtotal	= ?(UseVAT, NStr("ru = 'СУММА'; en = 'SUBTOTAL'"), NStr("ru = 'ИТОГО'; en = 'TOTAL'"));
	TemplateArea.Parameters.Amount			= SmallBusinessServer.AmountsFormat(Amount);
	TemplateArea.Parameters.Currency		= Header.DocumentCurrency;
	SpreadsheetDocument.Put(TemplateArea);
	
	If UseVAT Then
		
		TemplateArea = Template.GetArea("TotalVAT");
		TemplateArea.Parameters.Currency	= Header.DocumentCurrency;
		If VATAmount = 0 Then
			TemplateArea.Parameters.VAT = NStr("ru = 'Без налога (НДС)'; en = 'Without tax (VAT)'");
			TemplateArea.Parameters.TotalVAT = "-";
		Else
			TemplateArea.Parameters.VAT = ?(Header.AmountIncludesVAT, NStr("ru = 'В том числе НДС'; en = 'Including VAT'"), NStr("ru = 'Сумма НДС'; en = 'VAT'"));
			TemplateArea.Parameters.TotalVAT = SmallBusinessServer.AmountsFormat(VATAmount);
		EndIf; 
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Total");
		TemplateArea.Parameters.Total			= SmallBusinessServer.AmountsFormat(Total);
		TemplateArea.Parameters.Currency		= Header.DocumentCurrency;
		SpreadsheetDocument.Put(TemplateArea);
	
	EndIf;
	
EndFunction // GenerateCompletionCertificate()

// Procedure of generating printed form Invoice, Invoice with services
//
Procedure GenerateInvoice(SpreadsheetDocument, CurrentDocument)
	
	Var Errors;
	
	UseVAT	= GetFunctionalOption("UseVAT");
	
	Query = New Query();
	Query.SetParameter("CurrentDocument", CurrentDocument);
	Query.Text = 
	"SELECT
	|	CustomerInvoice.Date AS DocumentDate,
	|	CustomerInvoice.Company AS Company,
	|	CustomerInvoice.Counterparty AS Counterparty,
	|	CustomerInvoice.AmountIncludesVAT AS AmountIncludesVAT,
	|	CustomerInvoice.DocumentCurrency AS DocumentCurrency,
	|	CustomerInvoice.Number AS DocumentNumber,
	|	CustomerInvoice.Company.Prefix AS Prefix,
	|	CASE
	|		WHEN CustomerInvoice.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.SaleToCustomer)
	|			THEN ""(Sale to customer)""
	|		WHEN CustomerInvoice.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForCommission)
	|			THEN ""(Pass to commission)""
	|		WHEN CustomerInvoice.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|			THEN ""(Pass to data processor)""
	|		WHEN CustomerInvoice.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferForSafeCustody)
	|			THEN ""(Pass to the counterparty for safekeeping)""
	|		WHEN CustomerInvoice.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN ""(Return to vendor)""
	|		WHEN CustomerInvoice.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal)
	|			THEN ""(Return to principal)""
	|		WHEN CustomerInvoice.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromProcessing)
	|			THEN ""(Return to counterparty from data processor)""
	|		WHEN CustomerInvoice.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody)
	|			THEN ""(Return to the counterparty from safekeeping)""
	|	END AS OperationKind,
	|	CustomerInvoice.Released,
	|	CustomerInvoice.Inventory.(
	|		LineNumber AS LineNumber,
	|		CASE
	|			WHEN (CAST(CustomerInvoice.Inventory.ProductsAndServices.DescriptionFull AS STRING(100))) = """"
	|				THEN CustomerInvoice.Inventory.ProductsAndServices.Description
	|			ELSE CustomerInvoice.Inventory.ProductsAndServices.DescriptionFull
	|		END AS InventoryItem,
	|		ProductsAndServices.SKU AS SKU,
	|		ProductsAndServices.Code AS Code,
	|		MeasurementUnit AS UnitOfMeasure,
	|		Quantity AS Quantity,
	|		Price AS Price,
	|		Amount AS Amount,
	|		VATAmount,
	|		Total,
	|		Characteristic,
	|		Batch,
	|		Content,
	|		DiscountMarkupPercent,
	|		CASE
	|			WHEN CustomerInvoice.Inventory.DiscountMarkupPercent <> 0
	|					OR CustomerInvoice.Inventory.AutomaticDiscountAmount <> 0
	|				THEN 1
	|			ELSE 0
	|		END AS IsDiscount,
	|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|		AutomaticDiscountAmount,
	|		ConnectionKey
	|	),
	|	CustomerInvoice.SerialNumbers.(
	|		SerialNumber,
	|		ConnectionKey
	|	)
	|FROM
	|	Document.CustomerInvoice AS CustomerInvoice
	|WHERE
	|	CustomerInvoice.Ref = &CurrentDocument
	|
	|ORDER BY
	|	LineNumber";
	
	Header = Query.Execute().Select();
	Header.Next();
	
	LinesSelectionInventory = Header.Inventory.Select();
	LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
	
	SpreadsheetDocument.PrintParametersName = "PARAMETRS_PRINT_Customer_Invoice";

	Template = GetTemplate("PF_MXL_CustomerInvoice");
	InfoAboutCompany		= SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
	InfoAboutCounterparty	= SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);

	If Template.Areas.Find("TitleWithLogo") <> Undefined
		AND Template.Areas.Find("TitleWithoutLogo") <> Undefined Then
		
		If ValueIsFilled(Header.Company.LogoFile) Then
			
			TemplateArea = Template.GetArea("TitleWithLogo");
			TemplateArea.Parameters.Fill(Header);
			
			PictureData = AttachedFiles.GetFileBinaryData(Header.Company.LogoFile);
			If ValueIsFilled(PictureData) Then
				
				TemplateArea.Drawings.Logo.Picture = New Picture(PictureData);
				
			EndIf;
			
		Else // If images are not selected, print regular header
			
			TemplateArea = Template.GetArea("TitleWithoutLogo");
			TemplateArea.Parameters.Fill(Header);
			
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
	Else
		
		MessageText = NStr("en='ATTENTION! Perhaps, user template is used default methods for the accounts printing may work incorrectly.';ru='ВНИМАНИЕ! Возможно используется пользовательский макет. Штатный механизм печати счетов может работать некоректно.'");
		CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
		
	EndIf;
	
	TemplateArea = Template.GetArea("InvoiceHeaderVendor");
	
	TemplateArea.Parameters.Fill(Header);
	
	VendorPresentation	= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
	
	TemplateArea.Parameters.VendorPresentation	= VendorPresentation;
	TemplateArea.Parameters.VendorAddress		= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "LegalAddress");
	TemplateArea.Parameters.VendorPhoneFax		= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "PhoneNumbers,Fax");
	TemplateArea.Parameters.VendorEmail			= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "Email");
	
	TemplateArea.Parameters.BankPresentation	=  SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "Bank", False);
	TemplateArea.Parameters.BankAccountNumber	=  SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "AccountNo", False);
	TemplateArea.Parameters.BankSWIFT			=  SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "SWIFT", False);
	
	CorrespondentText	= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "CorrespondentText", False);
	TemplateArea.Parameters.BankBeneficiary		=  ?(ValueIsFilled(CorrespondentText), CorrespondentText, VendorPresentation);
	
	SpreadsheetDocument.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("InvoiceHeaderCustomer");
	
	TemplateArea.Parameters.CustomerPresentation	= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr");
	TemplateArea.Parameters.CustomerAddress			= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "LegalAddress");
	TemplateArea.Parameters.CustomerPhoneFax		= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "PhoneNumbers,Fax");
	
	SpreadsheetDocument.Put(TemplateArea);
	
	AreDiscounts = Header.Inventory.Unload().Total("IsDiscount") <> 0;

	If AreDiscounts Then
		
		TemplateArea = Template.GetArea("TableHeaderWithDiscount");
		SpreadsheetDocument.Put(TemplateArea);
		TemplateArea = Template.GetArea("TableRowWithDiscount");
		
	Else
		
		TemplateArea = Template.GetArea("TableHeader");
		SpreadsheetDocument.Put(TemplateArea);
		TemplateArea = Template.GetArea("TableRow");
		
	EndIf;
	
	Amount		= 0;
	VATAmount	= 0;
	Total		= 0;
	Quantity	= 0;
	
	While LinesSelectionInventory.Next() Do
	
		TemplateArea.Parameters.Fill(LinesSelectionInventory);
		If ValueIsFilled(LinesSelectionInventory.Content) Then
			
			TemplateArea.Parameters.ProductDescription = LinesSelectionInventory.Content;
			
		Else
			
			StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
			ProductDescription = 
				SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU, StringSerialNumbers);
				
			If ValueIsFilled(LinesSelectionInventory.Batch) Then
				
				ProductDescription = ProductDescription + "; " + String(LinesSelectionInventory.Batch);
				
			EndIf;
			
			TemplateArea.Parameters.ProductDescription = ProductDescription;
			
		EndIf;
			
		If AreDiscounts Then
			If LinesSelectionInventory.DiscountMarkupPercent = 100 Then
				Discount = LinesSelectionInventory.Price * LinesSelectionInventory.Quantity;
				TemplateArea.Parameters.Discount         = Discount;
				TemplateArea.Parameters.AmountWithoutDiscount = Discount;
			ElsIf LinesSelectionInventory.DiscountMarkupPercent = 0 AND LinesSelectionInventory.AutomaticDiscountAmount = 0 Then
				TemplateArea.Parameters.Discount         = 0;
				TemplateArea.Parameters.AmountWithoutDiscount = LinesSelectionInventory.Amount;
			Else
				Discount = LinesSelectionInventory.Quantity * LinesSelectionInventory.Price - LinesSelectionInventory.Amount; // AutomaticDiscounts
				TemplateArea.Parameters.Discount         = Discount;
				TemplateArea.Parameters.AmountWithoutDiscount = LinesSelectionInventory.Amount + Discount;
			EndIf;
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		Amount		= Amount	+ LinesSelectionInventory.Amount;
		VATAmount	= VATAmount	+ LinesSelectionInventory.VATAmount;
		Total		= Total		+ LinesSelectionInventory.Total;
		Quantity	= Quantity+ 1;
		
	EndDo;
	
	TemplateArea = Template.GetArea("Subtotal");
	TemplateArea.Parameters.TitleSubtotal	= ?(UseVAT, NStr("ru = 'СУММА'; en = 'SUBTOTAL'"), NStr("ru = 'ИТОГО'; en = 'TOTAL'"));
	TemplateArea.Parameters.Amount			= SmallBusinessServer.AmountsFormat(Amount);
	TemplateArea.Parameters.Currency		= Header.DocumentCurrency;
	SpreadsheetDocument.Put(TemplateArea);
	
	If UseVAT Then
		
		TemplateArea = Template.GetArea("TotalVAT");
		TemplateArea.Parameters.Currency	= Header.DocumentCurrency;
		If VATAmount = 0 Then
			TemplateArea.Parameters.VAT = NStr("ru = 'Без налога (НДС)'; en = 'Without tax (VAT)'");
			TemplateArea.Parameters.TotalVAT = "-";
		Else
			TemplateArea.Parameters.VAT = ?(Header.AmountIncludesVAT, NStr("ru = 'В том числе НДС'; en = 'Including VAT'"), NStr("ru = 'Сумма НДС'; en = 'VAT'"));
			TemplateArea.Parameters.TotalVAT = SmallBusinessServer.AmountsFormat(VATAmount);
		EndIf; 
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Total");
		TemplateArea.Parameters.Total			= SmallBusinessServer.AmountsFormat(Total);
		TemplateArea.Parameters.Currency		= Header.DocumentCurrency;
		SpreadsheetDocument.Put(TemplateArea);
	
	EndIf;
	
EndProcedure // GenerateInvoice()

// Generate printed forms of objects
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	Var Errors;
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_CustomerInvoice";

	FirstDocument = True;
	
	For Each CurrentDocument IN ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "CustomerInvoice" Then
			
			GenerateInvoice(SpreadsheetDocument, CurrentDocument);
			
		ElsIf TemplateName = "CompletionCertificate" Then
			
			GenerateCompletionCertificate(SpreadsheetDocument, CurrentDocument, Errors)
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors);
	
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
	Var Errors;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "CustomerInvoice") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "CustomerInvoice", "Customer invoice", PrintForm(ObjectsArray, PrintObjects, "CustomerInvoice"));
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "CompletionCertificate") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "CompletionCertificate", "Completion certificate", PrintForm(ObjectsArray, PrintObjects, "CompletionCertificate"));
	EndIf;
	
	If Errors <> Undefined Then
		CommonUseClientServer.ShowErrorsToUser(Errors);
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
	PrintCommand.ID							= "CustomerInvoice";
	PrintCommand.Presentation				= NStr("en = 'Customer invoice'; ru = 'Расходная накладная'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "CompletionCertificate";
	PrintCommand.Presentation				= NStr("en = 'Completion certificate'; ru = 'Акт выполненных работ'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	
EndProcedure

#EndRegion

#Region WorkWithSerialNumbers

// Generates a table of values that contains the data for the SerialNumbersGuarantees information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersGuarantees", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
	|	TemporaryTableInventory.Period AS EventDate,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.ProductsAndServices AS ProductsAndServices,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	TemporaryTableInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableInventory.Cell AS Cell,
	|	TemporaryTableInventory.OrderWarehouse AS OrderWarehouse,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey";
	
	QueryResult = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersGuarantees", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf; 
	
EndProcedure

#EndRegion

#EndIf