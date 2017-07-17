#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.OperationKind AS OperationKind,
	|	TableInventory.CurrencyPricesRecipient AS CurrencyPricesRecipient,
	|	TableInventory.ExpenseAccountType AS ExpenseAccountType,
	|	TableInventory.CorrActivityDirection AS CorrActivityDirection,
	|	TableInventory.Company AS Company,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	UNDEFINED AS SalesDocument,
	|	UNDEFINED AS OrderSales,
	|	TableInventory.CorrGLAccount AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	TableInventory.RetailTransfer AS RetailTransfer,
	|	TableInventory.RetailTransferAccrualAccounting AS RetailTransferAccrualAccounting,
	|	TableInventory.ReturnFromRetailAccrualAccounting AS ReturnFromRetailAccrualAccounting,
	|	TableInventory.GLAccountInRetail AS GLAccountInRetail,
	|	TableInventory.MarkupGLAccount AS MarkupGLAccount,
	|	TableInventory.FinancialAccountInRetailRecipient AS FinancialAccountInRetailRecipient,
	|	TableInventory.MarkupGLAccountRecipient AS MarkupGLAccountRecipient,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SUM(CASE
	|			WHEN TableInventory.ReturnFromRetailAccrualAccounting
	|				THEN -TableInventory.Quantity
	|			ELSE TableInventory.Quantity
	|		END) AS Quantity,
	|	SUM(CASE
	|			WHEN TableInventory.ReturnFromRetailAccrualAccounting
	|				THEN -TableInventory.Reserve
	|			ELSE TableInventory.Reserve
	|		END) AS Reserve,
	|	SUM(CASE
	|			WHEN TableInventory.ReturnFromRetailAccrualAccounting
	|				THEN -TableInventory.Cost
	|			ELSE TableInventory.Amount
	|		END) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	(NOT TableInventory.TransferInRetailAccrualAccounting)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.OperationKind,
	|	TableInventory.CurrencyPricesRecipient,
	|	TableInventory.ExpenseAccountType,
	|	TableInventory.CorrActivityDirection,
	|	TableInventory.Company,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.GLAccount,
	|	TableInventory.FinancialAccountInRetailRecipient,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.ProductsAndServicesCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.CustomerOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.MarkupGLAccountRecipient,
	|	TableInventory.RetailTransferAccrualAccounting,
	|	TableInventory.RetailTransfer,
	|	TableInventory.ReturnFromRetailAccrualAccounting,
	|	TableInventory.GLAccountInRetail,
	|	TableInventory.MarkupGLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.GLAccount,
	|	TableInventory.ContentOfAccountingRecord";
	
	QueryResult = Query.Execute();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
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
	|		TableInventory.CustomerOrder AS CustomerOrder
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|		AND (NOT TableInventory.TransferInRetailAccrualAccounting)
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
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		(NOT TableInventory.TransferInRetailAccrualAccounting)) AS TableInventory
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
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef))) AS InventoryBalances
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
	|		InventoryBalances.CustomerOrder,
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
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder
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
	
	Query.SetParameter("Ref", DocumentRefInventoryTransfer);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch,CustomerOrder");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	
	IsEmptyStructuralUnit = Catalogs.StructuralUnits.EmptyRef();
	EmptyAccount = ChartsOfAccounts.Managerial.EmptyRef();
	EmptyProductsAndServices = Catalogs.ProductsAndServices.EmptyRef();
	EmptyCharacteristic = Catalogs.ProductsAndServicesCharacteristics.EmptyRef();
	EmptyBatch = Catalogs.ProductsAndServicesBatches.EmptyRef();
    EmptyCustomerOrder = Documents.CustomerOrder.EmptyRef();

	RetailTransferAccrualAccounting = False;
	ReturnFromRetailAccrualAccounting = False;	
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		If RowTableInventory.ReturnFromRetailAccrualAccounting Then
			ReturnFromRetailAccrualAccounting = True;			
			
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			TableRowExpense.StructuralUnit = TableRowExpense.StructuralUnitCorr;
			TableRowExpense.StructuralUnitCorr = Undefined;
			TableRowExpense.CorrGLAccount = Undefined;
			TableRowExpense.ProductsAndServicesCorr = Undefined;
			TableRowExpense.CharacteristicCorr = Undefined;
			TableRowExpense.BatchCorr = Undefined;
			TableRowExpense.CustomerCorrOrder = Undefined;
			TableRowExpense.FixedCost = True;

			RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
			FillPropertyValues(RowTableManagerial, RowTableInventory);
			RowTableManagerial.Amount = RowTableInventory.Amount;
			RowTableManagerial.AccountDr = RowTableInventory.GLAccountInRetail;
			
			Continue;
		EndIf;
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("ProductsAndServices", RowTableInventory.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredReserve = RowTableInventory.Reserve;
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
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
	
			// Expense.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredReserve;
			
			If RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.Expenses
			 OR RowTableInventory.RetailTransferAccrualAccounting Then
				
				TableRowExpense.StructuralUnitCorr = IsEmptyStructuralUnit;
				TableRowExpense.CorrGLAccount = EmptyAccount;
				TableRowExpense.ProductsAndServicesCorr = EmptyProductsAndServices;
				TableRowExpense.CharacteristicCorr = EmptyCharacteristic;
				TableRowExpense.BatchCorr = EmptyBatch;
				TableRowExpense.CustomerCorrOrder = EmptyCustomerOrder;
				TableRowExpense.SalesDocument = DocumentRefInventoryTransfer;
				TableRowExpense.OrderSales = RowTableInventory.CustomerOrder;
				
			Else
				
				If RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.Move
				   AND RowTableInventory.RetailTransfer Then
				   TableRowExpense.CustomerCorrOrder = EmptyCustomerOrder;
				ElsIf Not RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.Move
				   	    AND Not RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
						TableRowExpense.CustomerCorrOrder = EmptyCustomerOrder;
				EndIf;
				
				If RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
					TableRowExpense.ProductsAndServicesCorr = EmptyProductsAndServices;
					TableRowExpense.CharacteristicCorr = EmptyCharacteristic;
					TableRowExpense.BatchCorr = EmptyBatch;
				EndIf;
				
			EndIf;
			
			If RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.ReturnFromExploitation Then
				
				TableRowExpense.StructuralUnitCorr = IsEmptyStructuralUnit;
				TableRowExpense.CorrGLAccount = EmptyAccount;
				TableRowExpense.ProductsAndServicesCorr = EmptyProductsAndServices;
				TableRowExpense.CharacteristicCorr = EmptyCharacteristic;
				TableRowExpense.BatchCorr = EmptyBatch;
				TableRowExpense.CustomerCorrOrder = EmptyCustomerOrder;
				TableRowExpense.FixedCost = True;
				
			EndIf;
			
			// Generate postings.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerial, RowTableInventory);
				RowTableManagerial.Amount = AmountToBeWrittenOff;
				
				If RowTableInventory.RetailTransferAccrualAccounting Then
					RowTableManagerial.AccountDr = RowTableInventory.FinancialAccountInRetailRecipient;
				EndIf;
																
			EndIf;
			
			If RowTableInventory.RetailTransferAccrualAccounting Then
				
				StringTableRetailAmountAccounting = StructureAdditionalProperties.TableForRegisterRecords.TableRetailAmountAccounting.Add();
				FillPropertyValues(StringTableRetailAmountAccounting, RowTableInventory);
				StringTableRetailAmountAccounting.Cost = AmountToBeWrittenOff;
				StringTableRetailAmountAccounting.RecordType = AccumulationRecordType.Receipt;
				StringTableRetailAmountAccounting.Currency = RowTableInventory.CurrencyPricesRecipient;
				StringTableRetailAmountAccounting.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				StringTableRetailAmountAccounting.Company = RowTableInventory.Company;
				StringTableRetailAmountAccounting.Amount = 0;
				StringTableRetailAmountAccounting.AmountCur = 0;
				
				RetailTransferAccrualAccounting = True;
							
			ElsIf Round(AmountToBeWrittenOff, 2, 1) <> 0 OR QuantityRequiredReserve > 0 Then // Receipt.
				
				If RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.Expenses Then
					
					StringTablesTurnover = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
					FillPropertyValues(StringTablesTurnover, RowTableInventory);
					StringTablesTurnover.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					StringTablesTurnover.BusinessActivity = RowTableInventory.CorrActivityDirection;
					StringTablesTurnover.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					StringTablesTurnover.Amount = AmountToBeWrittenOff;
					StringTablesTurnover.AmountExpense = AmountToBeWrittenOff;
					StringTablesTurnover.GLAccount = RowTableInventory.CorrGLAccount;
					
				Else // These are costs.
					
					TableRowReceipt = TemporaryTableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventory);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.Company = RowTableInventory.Company;
					TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					
					If RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.Move
					AND Not RowTableInventory.RetailTransfer Then
						TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;						
					ElsIf RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
						TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
						TableRowReceipt.ProductsAndServices = EmptyProductsAndServices;
						TableRowReceipt.Characteristic = EmptyCharacteristic;
						TableRowReceipt.Batch = EmptyBatch;
					Else
						TableRowReceipt.CustomerOrder = EmptyCustomerOrder;
					EndIf;
					
					TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
					TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
					TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
					TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
					TableRowReceipt.BatchCorr = RowTableInventory.Batch;
					TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerOrder;
					
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					
					If RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.TransferToOperation
					 OR RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.WriteOffToExpenses Then
						TableRowReceipt.Quantity = 0;
					Else
						TableRowReceipt.Quantity = QuantityRequiredReserve;
					EndIf;
					
					TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
					
					If RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.ReturnFromExploitation Then
						
						TableRowReceipt.StructuralUnitCorr = IsEmptyStructuralUnit;
						TableRowReceipt.CorrGLAccount = EmptyAccount;
						TableRowReceipt.ProductsAndServicesCorr = EmptyProductsAndServices;
						TableRowReceipt.CharacteristicCorr = EmptyCharacteristic;
						TableRowReceipt.BatchCorr = EmptyBatch;
						TableRowReceipt.CustomerCorrOrder = EmptyCustomerOrder;
						TableRowReceipt.FixedCost = True;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			StructureForSearch.Insert("CustomerOrder", EmptyCustomerOrder);
			
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
	
			// Expense.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.CustomerOrder = EmptyCustomerOrder;
			
			If RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.Expenses
			 OR RowTableInventory.RetailTransferAccrualAccounting Then
				
				TableRowExpense.StructuralUnitCorr = IsEmptyStructuralUnit;
				TableRowExpense.CorrGLAccount = EmptyAccount;
				TableRowExpense.ProductsAndServicesCorr = EmptyProductsAndServices;
				TableRowExpense.CharacteristicCorr = EmptyCharacteristic;
				TableRowExpense.BatchCorr = EmptyBatch;
				TableRowExpense.CustomerCorrOrder = EmptyCustomerOrder;
				TableRowExpense.SalesDocument = DocumentRefInventoryTransfer;
				TableRowExpense.OrderSales = RowTableInventory.CustomerOrder;
				
			Else
				If RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.Move
				   AND RowTableInventory.RetailTransfer Then
				   TableRowExpense.CustomerCorrOrder = EmptyCustomerOrder;
				ElsIf Not RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.Move
				   	   AND Not RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
						TableRowExpense.CustomerCorrOrder = EmptyCustomerOrder;
				EndIf;
				
				If RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
					TableRowExpense.ProductsAndServicesCorr = EmptyProductsAndServices;
					TableRowExpense.CharacteristicCorr = EmptyCharacteristic;
					TableRowExpense.BatchCorr = EmptyBatch;
				EndIf;
				
			EndIf;
			
			If RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.ReturnFromExploitation Then
				
				TableRowExpense.StructuralUnitCorr = IsEmptyStructuralUnit;
				TableRowExpense.CorrGLAccount = EmptyAccount;
				TableRowExpense.ProductsAndServicesCorr = EmptyProductsAndServices;
				TableRowExpense.CharacteristicCorr = EmptyCharacteristic;
				TableRowExpense.BatchCorr = EmptyBatch;
				TableRowExpense.CustomerCorrOrder = EmptyCustomerOrder;
				TableRowExpense.FixedCost = True;
				
			EndIf;
			
			// Generate postings.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerial, RowTableInventory);
				RowTableManagerial.Amount = AmountToBeWrittenOff;
				
				If RowTableInventory.RetailTransferAccrualAccounting Then
					RowTableManagerial.AccountDr = RowTableInventory.FinancialAccountInRetailRecipient;					
				EndIf;
				
			EndIf;
                        			
			If RowTableInventory.RetailTransferAccrualAccounting Then
				
				StringTableRetailAmountAccounting = StructureAdditionalProperties.TableForRegisterRecords.TableRetailAmountAccounting.Add();
				FillPropertyValues(StringTableRetailAmountAccounting, RowTableInventory);
				StringTableRetailAmountAccounting.RecordType = AccumulationRecordType.Receipt;
				StringTableRetailAmountAccounting.Cost = AmountToBeWrittenOff;
				StringTableRetailAmountAccounting.Currency = RowTableInventory.CurrencyPricesRecipient;
				StringTableRetailAmountAccounting.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				StringTableRetailAmountAccounting.Amount = 0;
				StringTableRetailAmountAccounting.AmountCur = 0;
				
				RetailTransferAccrualAccounting = True;
			
			ElsIf Round(AmountToBeWrittenOff, 2, 1) <> 0 OR QuantityRequiredAvailableBalance > 0 Then // Receipt
				
				If RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.Expenses Then
					
					StringTablesTurnover = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
					FillPropertyValues(StringTablesTurnover, RowTableInventory);
					StringTablesTurnover.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					StringTablesTurnover.BusinessActivity = RowTableInventory.CorrActivityDirection;
					StringTablesTurnover.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					StringTablesTurnover.Amount = AmountToBeWrittenOff;
					StringTablesTurnover.AmountExpense = AmountToBeWrittenOff;
					StringTablesTurnover.GLAccount = RowTableInventory.CorrGLAccount;
					
				Else // These are costs.
					
					TableRowReceipt = TemporaryTableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventory);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.Company = RowTableInventory.Company;
					TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					
					If RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.Move
					AND Not RowTableInventory.RetailTransfer Then
						TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					ElsIf RowTableInventory.ExpenseAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
						TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
						TableRowReceipt.ProductsAndServices = EmptyProductsAndServices;
						TableRowReceipt.Characteristic = EmptyCharacteristic;
						TableRowReceipt.Batch = EmptyBatch;
					Else
						TableRowReceipt.CustomerOrder = EmptyCustomerOrder;
					EndIf;
					
					TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
					TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
					TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
					TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
					TableRowReceipt.BatchCorr = RowTableInventory.Batch;
					TableRowReceipt.CustomerCorrOrder = EmptyCustomerOrder;
					
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					
					If RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.TransferToOperation
					 OR RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.WriteOffToExpenses Then
						TableRowReceipt.Quantity = 0;
					Else
						TableRowReceipt.Quantity = QuantityRequiredAvailableBalance;
					EndIf;
					
					TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
					
					If RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.ReturnFromExploitation Then
						
						TableRowReceipt.StructuralUnitCorr = IsEmptyStructuralUnit;
						TableRowReceipt.CorrGLAccount = EmptyAccount;
						TableRowReceipt.ProductsAndServicesCorr = EmptyProductsAndServices;
						TableRowReceipt.CharacteristicCorr = EmptyCharacteristic;
						TableRowReceipt.BatchCorr = EmptyBatch;
						TableRowReceipt.CustomerCorrOrder = EmptyCustomerOrder;
						TableRowReceipt.FixedCost = True;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		// If it is a passing to operation, transfer at zero cost and classify
		// the cost itself as recipient-subdepartments costs.
		If RowTableInventory.OperationKind = Enums.OperationKindsInventoryTransfer.TransferToOperation Then
		   
		   // It should be added, then receipt is only by
		   // quantity with an empty mail for the correct account in quantitative terms.
		   TableRowReceipt = TemporaryTableInventory.Add();
		   FillPropertyValues(TableRowReceipt, RowTableInventory);
		   
		   TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
		   
		   TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
		   
		   TableRowReceipt.CustomerOrder = EmptyCustomerOrder;
		  		   
		   TableRowReceipt.StructuralUnitCorr = IsEmptyStructuralUnit;
		   TableRowReceipt.CorrGLAccount = EmptyAccount;
		   TableRowReceipt.ProductsAndServicesCorr = EmptyProductsAndServices;
		   TableRowReceipt.CharacteristicCorr = EmptyCharacteristic;
		   TableRowReceipt.BatchCorr = EmptyBatch;
		   TableRowReceipt.CustomerCorrOrder = EmptyCustomerOrder;
		   
		   TableRowReceipt.Amount = 0;
		   TableRowReceipt.FixedCost = True;
		   
		EndIf;
			
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
	// Trade markup in case of retail (amount accounting).
	If RetailTransferAccrualAccounting
	 OR ReturnFromRetailAccrualAccounting Then
		
		SumCost = TemporaryTableInventory.Total("Amount");
		
		Query = New Query;
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		Query.Text =
		"SELECT
		|	SUM(ISNULL(TemporaryTableRetailAmountAccounting.Amount, 0)) AS Amount
		|FROM
		|	TemporaryTableRetailAmountAccounting AS TemporaryTableRetailAmountAccounting";
		
		SelectionOfQueryResult = Query.Execute().Select();
		
		If SelectionOfQueryResult.Next() Then
			SumInSalesPrices = SelectionOfQueryResult.Amount;			
		Else
			SumInSalesPrices = 0;
		EndIf;
		
		AmountMarkup = SumInSalesPrices - SumCost;
		
		If AmountMarkup <> 0 Then
			
			If TemporaryTableInventory.Count() > 0 Then
				TableRow = TemporaryTableInventory[0];
			ElsIf StructureAdditionalProperties.TableForRegisterRecords.TableRetailAmountAccounting.Count() > 0 Then
				TableRow = StructureAdditionalProperties.TableForRegisterRecords.TableRetailAmountAccounting[0];
			Else
				TableRow = Undefined;
			EndIf;
			
			If TableRow <> Undefined Then
				RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerial, TableRow);
				RowTableManagerial.AccountDr = ?(RetailTransferAccrualAccounting, TableRow.FinancialAccountInRetailRecipient, TableRow.GLAccountInRetail);
				RowTableManagerial.AccountCr = ?(RetailTransferAccrualAccounting, TableRow.MarkupGLAccountRecipient, TableRow.MarkupGLAccount);
				RowTableManagerial.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
				RowTableManagerial.Content = NStr("en='Markup';ru='Торговая наценка'");
				RowTableManagerial.Amount = AmountMarkup;
			EndIf;
			
		EndIf;
	
	EndIf;		
	
EndProcedure // GenerateInventoryTable()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Cell AS Cell,
	|	TableInventory.Company AS Company,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	(NOT TableInventory.OrderWarehouse)
	|	AND (NOT TableInventory.ReturnFromRetailAccrualAccounting)
	|	AND (NOT TableInventory.TransferInRetailAccrualAccounting)
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventory.LineNumber,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventory.Period,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.CorrCell,
	|	TableInventory.Company,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.Period < TableInventory.UpdateDateToRelease_1_2_1
	|	AND (NOT TableInventory.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.WriteOffToExpenses))
	|	AND (NOT TableInventory.RetailTransferAccrualAccounting)
	|	AND (NOT TableInventory.TransferInRetailAccrualAccounting)
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventory.LineNumber,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventory.Period,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.CorrCell,
	|	TableInventory.Company,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	(NOT TableInventory.CorrWarrantWarehouse)
	|	AND TableInventory.Period >= TableInventory.UpdateDateToRelease_1_2_1
	|	AND (NOT TableInventory.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.WriteOffToExpenses))
	|	AND (NOT TableInventory.RetailTransferAccrualAccounting)
	|	AND (NOT TableInventory.TransferInRetailAccrualAccounting)";
    		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryInWarehouses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryForExpenseFromWarehouses(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.OrderWarehouse
	|	AND (NOT TableInventory.TransferInRetailAccrualAccounting)";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryForExpenseFromWarehouses", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryForExpenseFromWarehouses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryForWarehouses(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.StructuralUnitCorr AS StructuralUnit,
	|	TableInventory.Company AS Company,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.CorrWarrantWarehouse = TRUE
	|	AND ((NOT TableInventory.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.WriteOffToExpenses))
	|			OR (NOT TableInventory.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.TransferToOperation)))
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventory.LineNumber,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventory.Period,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.Company,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.Period < TableInventory.UpdateDateToRelease_1_2_1
	|	AND TableInventory.CorrWarrantWarehouse = TRUE
	|	AND ((NOT TableInventory.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.WriteOffToExpenses))
	|			OR (NOT TableInventory.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.TransferToOperation)))";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryForWarehouses", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryForWarehouses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.StructuralUnits.EmptyRef) AS StructuralUnit,
	|	VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END AS GLAccount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS AmountExpense,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS Amount
	|FROM
	|	TemporaryTableCurrencyExchangeRateDifferencesRetailAmountAccounting AS DocumentTable";
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableRetailAmountAccounting(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref", DocumentRefInventoryTransfer);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("RetailTransfer", NStr("en='Move to retail';ru='Перемещение в розницу'"));
	Query.SetParameter("RetailTransfer", NStr("en='Movement in retail';ru='Перемещение в рознице'"));
	Query.SetParameter("ReturnAndRetail", NStr("en='Return from retail';ru='Возврат из розницы'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Date,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.RetailPriceKind AS RetailPriceKind,
	|	DocumentTable.ProductsAndServices AS ProductsAndServices,
	|	DocumentTable.Characteristic AS Characteristic,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.CustomerOrder AS CustomerOrder,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.AmountCur AS AmountCur,
	|	DocumentTable.Amount AS AmountForBalance,
	|	DocumentTable.AmountCur AS AmountCurForBalance,
	|	DocumentTable.Cost AS Cost,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
	|INTO TemporaryTableRetailAmountAccounting
	|FROM
	|	(SELECT
	|		DocumentTable.Period AS Date,
	|		VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|		DocumentTable.LineNumber AS LineNumber,
	|		DocumentTable.Company AS Company,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailAccrualAccounting
	|				THEN DocumentTable.RetailPriceKind
	|			ELSE DocumentTable.RetailPriceKindRecipient
	|		END AS RetailPriceKind,
	|		DocumentTable.ProductsAndServices AS ProductsAndServices,
	|		DocumentTable.Characteristic AS Characteristic,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailAccrualAccounting
	|				THEN DocumentTable.StructuralUnit
	|			ELSE DocumentTable.StructuralUnitCorr
	|		END AS StructuralUnit,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailAccrualAccounting
	|				THEN DocumentTable.PriceCurrency
	|			ELSE DocumentTable.CurrencyPricesRecipient
	|		END AS Currency,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailAccrualAccounting
	|				THEN DocumentTable.GLAccountInRetail
	|			ELSE DocumentTable.FinancialAccountInRetailRecipient
	|		END AS GLAccount,
	|		DocumentTable.CustomerOrder AS CustomerOrder,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailAccrualAccounting
	|				THEN -(CAST(ProductsAndServicesPricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2)))
	|			ELSE CAST(ProductsAndServicesPricesRecipientSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRateRecipient.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * CurrencyPriceExchangeRateRecipient.Multiplicity) / ISNULL(ProductsAndServicesPricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))
	|		END AS Amount,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailAccrualAccounting
	|				THEN -(CAST(ProductsAndServicesPricesSliceLast.Price * DocumentTable.Quantity / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2)))
	|			ELSE CAST(ProductsAndServicesPricesRecipientSliceLast.Price * DocumentTable.Quantity / ISNULL(ProductsAndServicesPricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))
	|		END AS AmountCur,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailAccrualAccounting
	|				THEN -(CAST(ProductsAndServicesPricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2)))
	|			ELSE CAST(ProductsAndServicesPricesRecipientSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRateRecipient.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * CurrencyPriceExchangeRateRecipient.Multiplicity) / ISNULL(ProductsAndServicesPricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))
	|		END AS SumForBalance,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailAccrualAccounting
	|				THEN -(CAST(ProductsAndServicesPricesSliceLast.Price * DocumentTable.Quantity / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2)))
	|			ELSE CAST(ProductsAndServicesPricesRecipientSliceLast.Price * DocumentTable.Quantity / ISNULL(ProductsAndServicesPricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))
	|		END AS AmountCurForBalance,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailAccrualAccounting
	|				THEN -DocumentTable.Cost
	|			ELSE 0
	|		END AS Cost,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailAccrualAccounting
	|				THEN &ReturnAndRetail
	|			ELSE &RetailTransfer
	|		END AS ContentOfAccountingRecord
	|	FROM
	|		TemporaryTableInventory AS DocumentTable
	|			LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(
	|					&PointInTime,
	|					(PriceKind, ProductsAndServices, Characteristic) In
	|						(SELECT
	|							TemporaryTableInventory.RetailPriceKindRecipient,
	|							TemporaryTableInventory.ProductsAndServices,
	|							TemporaryTableInventory.Characteristic
	|						FROM
	|							TemporaryTableInventory)) AS ProductsAndServicesPricesRecipientSliceLast
	|			ON DocumentTable.ProductsAndServices = ProductsAndServicesPricesRecipientSliceLast.ProductsAndServices
	|				AND DocumentTable.RetailPriceKindRecipient = ProductsAndServicesPricesRecipientSliceLast.PriceKind
	|				AND DocumentTable.Characteristic = ProductsAndServicesPricesRecipientSliceLast.Characteristic
	|			LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(
	|					&PointInTime,
	|					(PriceKind, ProductsAndServices, Characteristic) In
	|						(SELECT
	|							TemporaryTableInventory.RetailPriceKind,
	|							TemporaryTableInventory.ProductsAndServices,
	|							TemporaryTableInventory.Characteristic
	|						FROM
	|							TemporaryTableInventory)) AS ProductsAndServicesPricesSliceLast
	|			ON DocumentTable.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices
	|				AND DocumentTable.RetailPriceKind = ProductsAndServicesPricesSliceLast.PriceKind
	|				AND DocumentTable.Characteristic = ProductsAndServicesPricesSliceLast.Characteristic
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|					&PointInTime,
	|					Currency In
	|						(SELECT
	|							Constants.AccountingCurrency
	|						FROM
	|							Constants AS Constants)) AS ManagCurrencyRates
	|			ON (TRUE)
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRateRecipient
	|			ON DocumentTable.CurrencyPricesRecipient = CurrencyPriceExchangeRateRecipient.Currency
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRate
	|			ON DocumentTable.PriceCurrency = CurrencyPriceExchangeRate.Currency
	|	WHERE
	|		(DocumentTable.RetailTransferAccrualAccounting
	|				OR DocumentTable.ReturnFromRetailAccrualAccounting)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentTable.Period,
	|		VALUE(AccumulationRecordType.Expense),
	|		DocumentTable.LineNumber,
	|		DocumentTable.Company,
	|		DocumentTable.RetailPriceKind,
	|		DocumentTable.ProductsAndServices,
	|		DocumentTable.Characteristic,
	|		DocumentTable.StructuralUnit,
	|		DocumentTable.PriceCurrency,
	|		DocumentTable.GLAccountInRetail,
	|		DocumentTable.CustomerOrder,
	|		SUM(CAST(ProductsAndServicesPricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		SUM(CAST(ProductsAndServicesPricesSliceLast.Price * DocumentTable.Quantity / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		-SUM(CAST(ProductsAndServicesPricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		-SUM(CAST(ProductsAndServicesPricesSliceLast.Price * DocumentTable.Quantity / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		DocumentTable.Cost,
	|		&RetailTransfer
	|	FROM
	|		TemporaryTableInventory AS DocumentTable
	|			LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(
	|					&PointInTime,
	|					(PriceKind, ProductsAndServices, Characteristic) In
	|						(SELECT
	|							TemporaryTableInventory.RetailPriceKind,
	|							TemporaryTableInventory.ProductsAndServices,
	|							TemporaryTableInventory.Characteristic
	|						FROM
	|							TemporaryTableInventory)) AS ProductsAndServicesPricesSliceLast
	|			ON DocumentTable.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices
	|				AND DocumentTable.RetailPriceKind = ProductsAndServicesPricesSliceLast.PriceKind
	|				AND DocumentTable.Characteristic = ProductsAndServicesPricesSliceLast.Characteristic
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|					&PointInTime,
	|					Currency In
	|						(SELECT
	|							Constants.AccountingCurrency
	|						FROM
	|							Constants AS Constants)) AS ManagCurrencyRates
	|			ON (TRUE)
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRate
	|			ON DocumentTable.PriceCurrency = CurrencyPriceExchangeRate.Currency
	|	WHERE
	|		DocumentTable.TransferInRetailAccrualAccounting
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.LineNumber,
	|		DocumentTable.Company,
	|		DocumentTable.RetailPriceKind,
	|		DocumentTable.ProductsAndServices,
	|		DocumentTable.Characteristic,
	|		DocumentTable.StructuralUnit,
	|		DocumentTable.PriceCurrency,
	|		DocumentTable.GLAccountInRetail,
	|		DocumentTable.CustomerOrder,
	|		DocumentTable.Cost
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentTable.Period,
	|		VALUE(AccumulationRecordType.Receipt),
	|		DocumentTable.LineNumber,
	|		DocumentTable.Company,
	|		DocumentTable.RetailPriceKindRecipient,
	|		DocumentTable.ProductsAndServices,
	|		DocumentTable.Characteristic,
	|		DocumentTable.StructuralUnitCorr,
	|		DocumentTable.CurrencyPricesRecipient,
	|		DocumentTable.FinancialAccountInRetailRecipient,
	|		DocumentTable.CustomerOrder,
	|		SUM(CAST(ProductsAndServicesPricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		SUM(CAST(ProductsAndServicesPricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * CurrencyPriceExchangeRateRecipient.Multiplicity / (CurrencyPriceExchangeRateRecipient.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		SUM(CAST(ProductsAndServicesPricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		SUM(CAST(ProductsAndServicesPricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * CurrencyPriceExchangeRateRecipient.Multiplicity / (CurrencyPriceExchangeRateRecipient.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		DocumentTable.Cost,
	|		&RetailTransfer
	|	FROM
	|		TemporaryTableInventory AS DocumentTable
	|			LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(
	|					&PointInTime,
	|					(PriceKind, ProductsAndServices, Characteristic) In
	|						(SELECT
	|							TemporaryTableInventory.RetailPriceKind,
	|							TemporaryTableInventory.ProductsAndServices,
	|							TemporaryTableInventory.Characteristic
	|						FROM
	|							TemporaryTableInventory)) AS ProductsAndServicesPricesSliceLast
	|			ON DocumentTable.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices
	|				AND DocumentTable.RetailPriceKind = ProductsAndServicesPricesSliceLast.PriceKind
	|				AND DocumentTable.Characteristic = ProductsAndServicesPricesSliceLast.Characteristic
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|					&PointInTime,
	|					Currency In
	|						(SELECT
	|							Constants.AccountingCurrency
	|						FROM
	|							Constants AS Constants)) AS ManagCurrencyRates
	|			ON (TRUE)
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRate
	|			ON DocumentTable.PriceCurrency = CurrencyPriceExchangeRate.Currency
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRateRecipient
	|			ON DocumentTable.CurrencyPricesRecipient = CurrencyPriceExchangeRateRecipient.Currency
	|	WHERE
	|		DocumentTable.TransferInRetailAccrualAccounting
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.LineNumber,
	|		DocumentTable.Company,
	|		DocumentTable.RetailPriceKindRecipient,
	|		DocumentTable.ProductsAndServices,
	|		DocumentTable.Characteristic,
	|		DocumentTable.StructuralUnitCorr,
	|		DocumentTable.CurrencyPricesRecipient,
	|		DocumentTable.FinancialAccountInRetailRecipient,
	|		DocumentTable.CustomerOrder,
	|		DocumentTable.Cost) AS DocumentTable
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Currency,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTableRetailAmountAccounting.Company AS Company,
	|	TemporaryTableRetailAmountAccounting.StructuralUnit AS StructuralUnit,
	|	TemporaryTableRetailAmountAccounting.Currency AS Currency
	|FROM
	|	TemporaryTableRetailAmountAccounting AS TemporaryTableRetailAmountAccounting";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.RetailAmountAccounting");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult IN QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = SmallBusinessServer.GetQueryTextExchangeRateDifferencesRetailAmountAccounting(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableRetailAmountAccounting", ResultsArray[QueryNumber].Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE DocumentTable.GLAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	0 AS AmountCurDr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS Amount,
	|	&ExchangeDifference AS Content
	|FROM
	|	TemporaryTableCurrencyExchangeRateDifferencesRetailAmountAccounting AS DocumentTable
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", QueryResult.Unload());
	
EndProcedure // GenerateTableManagerial()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefInventoryTransfer, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	InventoryTransferInventory.LineNumber AS LineNumber,
	|	InventoryTransferInventory.ConnectionKey AS ConnectionKey,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	InventoryTransferInventory.Ref.Date AS Period,
	|	InventoryTransferInventory.Ref.OperationKind AS OperationKind,
	|	InventoryTransferInventory.ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType <> VALUE(Enum.StructuralUnitsTypes.RetailAccrualAccounting)
	|				AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.RetailAccrualAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailTransferAccrualAccounting,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType <> VALUE(Enum.StructuralUnitsTypes.Retail)
	|				AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailTransfer,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.RetailAccrualAccounting)
	|				AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType <> VALUE(Enum.StructuralUnitsTypes.RetailAccrualAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ReturnFromRetailAccrualAccounting,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.RetailAccrualAccounting)
	|				AND InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.RetailAccrualAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS TransferInRetailAccrualAccounting,
	|	InventoryTransferInventory.Ref.StructuralUnit.GLAccountInRetail AS GLAccountInRetail,
	|	InventoryTransferInventory.Ref.StructuralUnit.MarkupGLAccount AS MarkupGLAccount,
	|	InventoryTransferInventory.Ref.StructuralUnit.RetailPriceKind AS RetailPriceKind,
	|	InventoryTransferInventory.Ref.StructuralUnit.RetailPriceKind.PriceCurrency AS PriceCurrency,
	|	InventoryTransferInventory.Ref.StructuralUnitPayee.GLAccountInRetail AS FinancialAccountInRetailRecipient,
	|	InventoryTransferInventory.Ref.StructuralUnitPayee.MarkupGLAccount AS MarkupGLAccountRecipient,
	|	InventoryTransferInventory.Ref.StructuralUnitPayee.RetailPriceKind AS RetailPriceKindRecipient,
	|	InventoryTransferInventory.Ref.StructuralUnitPayee.RetailPriceKind.PriceCurrency AS CurrencyPricesRecipient,
	|	InventoryTransferInventory.Ref.StructuralUnit.OrderWarehouse AS OrderWarehouse,
	|	InventoryTransferInventory.Ref.StructuralUnitPayee.OrderWarehouse AS CorrWarrantWarehouse,
	|	InventoryTransferInventory.Ref.GLExpenseAccount.TypeOfAccount AS ExpenseAccountType,
	|	InventoryTransferInventory.Ref.BusinessActivity AS CorrActivityDirection,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	InventoryTransferInventory.Ref.StructuralUnit AS StructuralUnit,
	|	InventoryTransferInventory.Ref.StructuralUnitPayee AS StructuralUnitCorr,
	|	InventoryTransferInventory.Ref.Cell AS Cell,
	|	InventoryTransferInventory.Ref.CellPayee AS CorrCell,
	|	CASE
	|		WHEN InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryTransferInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.ReturnFromExploitation)
	|					THEN InventoryTransferInventory.ProductsAndServices.InventoryGLAccount
	|				ELSE CASE
	|						WHEN InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|								OR InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|								OR InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.RetailAccrualAccounting)
	|							THEN InventoryTransferInventory.ProductsAndServices.InventoryGLAccount
	|						ELSE InventoryTransferInventory.ProductsAndServices.ExpensesGLAccount
	|					END
	|			END
	|	END AS GLAccount,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.Move)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.ReturnFromExploitation)
	|			THEN CASE
	|					WHEN InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|							OR InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|							OR InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|						THEN InventoryTransferInventory.ProductsAndServices.InventoryGLAccount
	|					ELSE CASE
	|							WHEN InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|									OR InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|									OR InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.RetailAccrualAccounting)
	|								THEN InventoryTransferInventory.ProductsAndServices.InventoryGLAccount
	|							ELSE InventoryTransferInventory.ProductsAndServices.ExpensesGLAccount
	|						END
	|				END
	|		ELSE InventoryTransferInventory.Ref.GLExpenseAccount
	|	END AS CorrGLAccount,
	|	InventoryTransferInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.Move)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.ReturnFromExploitation)
	|			THEN InventoryTransferInventory.ProductsAndServices
	|		ELSE VALUE(Catalog.ProductsAndServices.EmptyRef)
	|	END AS ProductsAndServicesCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryTransferInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.Move)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.ReturnFromExploitation)
	|			THEN CASE
	|					WHEN &UseCharacteristics
	|						THEN InventoryTransferInventory.Characteristic
	|					ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|				END
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryTransferInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.Move)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.ReturnFromExploitation)
	|			THEN CASE
	|					WHEN &UseBatches
	|						THEN InventoryTransferInventory.Batch
	|					ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|				END
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS BatchCorr,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.Move)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.WriteOffToExpenses)
	|			THEN InventoryTransferInventory.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS CustomerOrder,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.Move)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.WriteOffToExpenses)
	|			THEN InventoryTransferInventory.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(InventoryTransferInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryTransferInventory.Quantity
	|		ELSE InventoryTransferInventory.Quantity * InventoryTransferInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.Move)
	|			THEN CASE
	|					WHEN VALUETYPE(InventoryTransferInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|						THEN InventoryTransferInventory.Reserve
	|					ELSE InventoryTransferInventory.Reserve * InventoryTransferInventory.MeasurementUnit.Factor
	|				END
	|		ELSE 0
	|	END AS Reserve,
	|	0 AS Amount,
	|	InventoryTransferInventory.Amount AS Cost,
	|	CASE
	|		WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.Move)
	|				OR InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.ReturnFromExploitation)
	|			THEN CASE
	|					WHEN InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|							OR InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|							OR InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|						THEN InventoryTransferInventory.ProductsAndServices.InventoryGLAccount
	|					ELSE CASE
	|							WHEN InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|									OR InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|									OR InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.RetailAccrualAccounting)
	|								THEN InventoryTransferInventory.ProductsAndServices.InventoryGLAccount
	|							ELSE InventoryTransferInventory.ProductsAndServices.ExpensesGLAccount
	|						END
	|				END
	|		ELSE InventoryTransferInventory.Ref.GLExpenseAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryTransferInventory.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryTransferInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.ReturnFromExploitation)
	|					THEN InventoryTransferInventory.ProductsAndServices.InventoryGLAccount
	|				ELSE CASE
	|						WHEN InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|								OR InventoryTransferInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|								OR InventoryTransferInventory.Ref.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.RetailAccrualAccounting)
	|							THEN InventoryTransferInventory.ProductsAndServices.InventoryGLAccount
	|						ELSE InventoryTransferInventory.ProductsAndServices.ExpensesGLAccount
	|					END
	|			END
	|	END AS AccountCr,
	|	&InventoryTransfer AS Content,
	|	&InventoryTransfer AS ContentOfAccountingRecord,
	|	InventoryTransferInventory.Amount AS AmountReturnCur,
	|	&UpdateDateToRelease_1_2_1 AS UpdateDateToRelease_1_2_1
	|INTO TemporaryTableInventory
	|FROM
	|	Document.InventoryTransfer.Inventory AS InventoryTransferInventory
	|WHERE
	|	InventoryTransferInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryTransferSerialNumbers.ConnectionKey,
	|	InventoryTransferSerialNumbers.SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.InventoryTransfer.SerialNumbers AS InventoryTransferSerialNumbers
	|WHERE
	|	InventoryTransferSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	Query.SetParameter("Ref", DocumentRefInventoryTransfer);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	// Temporarily: change motions by the order warehouse.
	Query.SetParameter("UpdateDateToRelease_1_2_1", Constants.UpdateDateToRelease_1_2_1.Get());
		
	Query.SetParameter("InventoryTransfer", NStr("en='Inventory movement';ru='Перемещение запасов'"));
	
	ResultsArray = Query.Execute();

	// Creation of document postings.
	GenerateTableInventoryInWarehouses(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	GenerateTableInventoryForExpenseFromWarehouses(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	GenerateTableInventoryForWarehouses(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	GenerateTableRetailAmountAccounting(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	
	GenerateTableManagerial(DocumentRefInventoryTransfer, StructureAdditionalProperties);
		
	// Calculation of the inventory write-off cost.
	GenerateTableInventory(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	
EndProcedure

// Generates a table of values that contains the data for the SerialNumbersGuarantees information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersGuarantees", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
		"SELECT
		|	TemporaryTableInventory.Period AS Period,
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	SerialNumbers.SerialNumber AS SerialNumber,
		|	TemporaryTableInventory.ProductsAndServices AS ProductsAndServices,
		|	TemporaryTableInventory.Characteristic AS Characteristic,
		|	TemporaryTableInventory.Batch AS Batch,
		|	TemporaryTableInventory.Company AS Company,
		|	TemporaryTableInventory.StructuralUnit AS StructuralUnit,
		|	TemporaryTableInventory.Cell AS Cell,
		|	TemporaryTableInventory.OperationKind AS OperationKind,
		|	1 AS Quantity,
		|	TemporaryTableInventory.OrderWarehouse AS OrderWarehouse
		|FROM
		|	TemporaryTableInventory AS TemporaryTableInventory
		|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
		|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey
		|WHERE
		|	NOT TemporaryTableInventory.OrderWarehouse
		|
		|UNION ALL
		|
		|SELECT
		|	TemporaryTableInventory.Period,
		|	VALUE(AccumulationRecordType.Receipt),
		|	SerialNumbers.SerialNumber,
		|	TemporaryTableInventory.ProductsAndServices,
		|	TemporaryTableInventory.Characteristic,
		|	TemporaryTableInventory.Batch,
		|	TemporaryTableInventory.Company,
		|	TemporaryTableInventory.StructuralUnitCorr,
		|	TemporaryTableInventory.CorrCell,
		|	TemporaryTableInventory.OperationKind,
		|	1,
		|	TemporaryTableInventory.OrderWarehouse
		|FROM
		|	TemporaryTableInventory AS TemporaryTableInventory
		|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
		|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey
		|WHERE
		|	NOT TemporaryTableInventory.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.WriteOffToExpenses)
		|	AND NOT TemporaryTableInventory.CorrWarrantWarehouse
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TemporaryTableInventory.Period AS EventDate,
		|	CASE
		|		WHEN TemporaryTableInventory.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.WriteOffToExpenses)
		|			THEN VALUE(Enum.SerialNumbersOperations.Expense)
		|		ELSE VALUE(Enum.SerialNumbersOperations.Record)
		|	END AS Operation,
		|	SerialNumbers.SerialNumber AS SerialNumber,
		|	TemporaryTableInventory.ProductsAndServices AS ProductsAndServices,
		|	TemporaryTableInventory.Characteristic AS Characteristic
		|FROM
		|	TemporaryTableInventory AS TemporaryTableInventory
		|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
		|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey";
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersGuarantees", ResultsArray[1].Unload());
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", ResultsArray[0].Unload());
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefInventoryTransfer, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the "InventoryTransferAtWarehouseChange",
	// "RegisterRecordsInventoryChange" temporary tables contain records, it is necessary to control the sales of goods.
	
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsRetailAmountAccountingUpdate
	 OR StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then

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
		|		INNER JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, ProductsAndServices, Characteristic, Batch, Cell) IN
		|					(SELECT
		|						RegisterRecordsInventoryInWarehousesChange.Company AS Company,
		|						RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryInWarehousesChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryInWarehousesChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryInWarehousesChange.Batch AS Batch,
		|						RegisterRecordsInventoryInWarehousesChange.Cell AS Cell
		|					FROM
		|						RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange)) AS InventoryInWarehousesOfBalance
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
		|		INNER JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) IN
		|					(SELECT
		|						RegisterRecordsInventoryChange.Company AS Company,
		|						RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryChange.GLAccount AS GLAccount,
		|						RegisterRecordsInventoryChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryChange.Batch AS Batch,
		|						RegisterRecordsInventoryChange.CustomerOrder AS CustomerOrder
		|					FROM
		|						RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange)) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.GLAccount = InventoryBalances.GLAccount
		|			AND RegisterRecordsInventoryChange.ProductsAndServices = InventoryBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.CustomerOrder = InventoryBalances.CustomerOrder
		|			AND (ISNULL(InventoryBalances.QuantityBalance, 0) < 0)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsRetailAmountAccountingUpdate.LineNumber AS LineNumber,
		|	RegisterRecordsRetailAmountAccountingUpdate.Company AS CompanyPresentation,
		|	RegisterRecordsRetailAmountAccountingUpdate.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsRetailAmountAccountingUpdate.StructuralUnit.RetailPriceKind.PriceCurrency AS CurrencyPresentation,
		|	ISNULL(RetailAmountAccountingBalances.AmountBalance, 0) AS AmountBalance,
		|	RegisterRecordsRetailAmountAccountingUpdate.SumCurChange + ISNULL(RetailAmountAccountingBalances.AmountCurBalance, 0) AS BalanceInRetail,
		|	RegisterRecordsRetailAmountAccountingUpdate.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsRetailAmountAccountingUpdate.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsRetailAmountAccountingUpdate.AmountChange AS AmountChange,
		|	RegisterRecordsRetailAmountAccountingUpdate.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsRetailAmountAccountingUpdate.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsRetailAmountAccountingUpdate.SumCurChange AS SumCurChange,
		|	RegisterRecordsRetailAmountAccountingUpdate.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsRetailAmountAccountingUpdate.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsRetailAmountAccountingUpdate.CostUpdate AS CostUpdate
		|FROM
		|	RegisterRecordsRetailAmountAccountingUpdate AS RegisterRecordsRetailAmountAccountingUpdate
		|		INNER JOIN AccumulationRegister.RetailAmountAccounting.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit) IN
		|					(SELECT
		|						RegisterRecordsRetailAmountAccountingUpdate.Company AS Company,
		|						RegisterRecordsRetailAmountAccountingUpdate.StructuralUnit AS StructuralUnit
		|					FROM
		|						RegisterRecordsRetailAmountAccountingUpdate AS RegisterRecordsRetailAmountAccountingUpdate)) AS RetailAmountAccountingBalances
		|		ON RegisterRecordsRetailAmountAccountingUpdate.Company = RetailAmountAccountingBalances.Company
		|			AND RegisterRecordsRetailAmountAccountingUpdate.StructuralUnit = RetailAmountAccountingBalances.StructuralUnit
		|			AND (ISNULL(RetailAmountAccountingBalances.AmountCurBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSerialNumbersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSerialNumbersChange.SerialNumber AS SerialNumberPresentation,
		|	RegisterRecordsSerialNumbersChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsSerialNumbersChange.ProductsAndServices AS ProductsAndServicesPresentation,
		|	RegisterRecordsSerialNumbersChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsSerialNumbersChange.Batch AS BatchPresentation,
		|	RegisterRecordsSerialNumbersChange.Cell AS PresentationCell,
		|	SerialNumbersBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	SerialNumbersBalance.ProductsAndServices.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSerialNumbersChange.QuantityChange, 0) + ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceSerialNumbers,
		|	ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceQuantitySerialNumbers
		|FROM
		|	RegisterRecordsSerialNumbersChange AS RegisterRecordsSerialNumbersChange
		|		INNER JOIN AccumulationRegister.SerialNumbers.Balance(&ControlTime, ) AS SerialNumbersBalance
		|		ON RegisterRecordsSerialNumbersChange.StructuralUnit = SerialNumbersBalance.StructuralUnit
		|			AND RegisterRecordsSerialNumbersChange.ProductsAndServices = SerialNumbersBalance.ProductsAndServices
		|			AND RegisterRecordsSerialNumbersChange.Characteristic = SerialNumbersBalance.Characteristic
		|			AND RegisterRecordsSerialNumbersChange.Batch = SerialNumbersBalance.Batch
		|			AND RegisterRecordsSerialNumbersChange.SerialNumber = SerialNumbersBalance.SerialNumber
		|			AND RegisterRecordsSerialNumbersChange.Cell = SerialNumbersBalance.Cell
		|			AND (ISNULL(SerialNumbersBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");

		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();

		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty() Then
			DocumentObjectInventoryTransfer = DocumentRefInventoryTransfer.GetObject()
		EndIf;

		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory and cost accounting.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance according to the amount-based account in retail.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			SmallBusinessServer.ShowMessageAboutPostingToRetailAmountAccountingRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If NOT ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			SmallBusinessServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region PrintInterface

// Function checks if the document is
// posted and calls the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_InventoryTransfer";

	FirstDocument = True;
	
	For Each CurrentDocument IN ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		Query.SetParameter("CurrentDocument", CurrentDocument);
		
		If TemplateName = "InventoryTransfer" Then
		
			Query.Text =
			"SELECT
			|	DocumentHeader.Date AS DocumentDate,
			|	DocumentHeader.Company AS Company,
			|	DocumentHeader.StructuralUnit AS Sender,
			|	DocumentHeader.StructuralUnitPayee AS Recipient,
			|	DocumentHeader.Number,
			|	DocumentHeader.Company.Prefix AS Prefix,
			|	DocumentHeader.StructuralUnitPayee.StructuralUnitType AS StructuralUnitPayeeStructuralUnitType,
			|	DocumentHeader.Released AS Released,
			|	DocumentHeader.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.InventoryTransfer AS DocumentHeader
			|WHERE
			|	DocumentHeader.Ref = &CurrentDocument
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	InventoryTransfer.LineNumber AS LineNumber,
			|	InventoryTransfer.ProductsAndServices.DescriptionFull AS InventoryItem,
			|	InventoryTransfer.ProductsAndServices.Code AS Code,
			|	InventoryTransfer.ProductsAndServices.SKU AS SKU,
			|	InventoryTransfer.MeasurementUnit AS StorageUnit,
			|	InventoryTransfer.Quantity AS Quantity,
			|	InventoryTransfer.Reserve AS Reserve,
			|	InventoryTransfer.CustomerOrder AS CustomerOrder,
			|	InventoryTransfer.Characteristic AS Characteristic,
			|	ISNULL(ProductsAndServicesPricesSliceLast.Price, 0) AS Price,
			|	ISNULL(ProductsAndServicesPricesSliceLast.Price * InventoryTransfer.Quantity, 0) AS Amount,
			|	InventoryTransfer.ConnectionKey
			|FROM
			|	Document.InventoryTransfer.Inventory AS InventoryTransfer
			|		LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(
			|				&DocumentDate,
			|				ProductsAndServices IN (&ListProductsAndServices)
			|					AND Characteristic IN (&ListCharacteristic)
			|					AND PriceKind = &PriceKind) AS ProductsAndServicesPricesSliceLast
			|		ON InventoryTransfer.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices
			|			AND InventoryTransfer.Characteristic = ProductsAndServicesPricesSliceLast.Characteristic
			|			AND InventoryTransfer.Ref.StructuralUnitPayee.RetailPriceKind = ProductsAndServicesPricesSliceLast.PriceKind
			|WHERE
			|	InventoryTransfer.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Query.SetParameter("PriceKind", CurrentDocument.StructuralUnitPayee.RetailPriceKind);
			Query.SetParameter("DocumentDate", CurrentDocument.Date);
			Query.SetParameter("ListProductsAndServices", CurrentDocument.Inventory.UnloadColumn("ProductsAndServices"));
			Query.SetParameter("ListCharacteristic", CurrentDocument.Inventory.UnloadColumn("Characteristic"));
			
			ResultsArray = Query.ExecuteBatch();
			
			Header = ResultsArray[0].Select();
			Header.Next();
			
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
			
			LinesSelectionInventory = ResultsArray[1].Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryTransfer_InventoryTransfer";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.InventoryTransfer.PF_MXL_InventoryTransfer");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText =
				"Inventory transfer #"
			  + DocumentNumber
			  + " from "
			  + Format(Header.DocumentDate, "DLF=DD");
			
			TemplateArea.Parameters.Fill(Header);
			SpreadsheetDocument.Put(TemplateArea);
			
			If Header.StructuralUnitPayeeStructuralUnitType = Enums.StructuralUnitsTypes.Retail
			 OR Header.StructuralUnitPayeeStructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
				TemplateArea = Template.GetArea("TableHeaderWithPrices");
			Else
				TemplateArea = Template.GetArea("TableHeader");
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
			
			If Header.StructuralUnitPayeeStructuralUnitType = Enums.StructuralUnitsTypes.Retail
			 OR Header.StructuralUnitPayeeStructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
				TemplateArea = Template.GetArea("StringPrices");
			Else
				TemplateArea = Template.GetArea("String");
			EndIf;
			
			Quantity = 0;
			TotalAmount = 0;
			
			While LinesSelectionInventory.Next() Do
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				TemplateArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(
					LinesSelectionInventory.InventoryItem,
					LinesSelectionInventory.Characteristic,
					LinesSelectionInventory.SKU,
					StringSerialNumbers);
				
				SpreadsheetDocument.Put(TemplateArea);
				
				Quantity = Quantity + 1;
				TotalAmount = TotalAmount + LinesSelectionInventory.Amount;
				
			EndDo;
			
			If Header.StructuralUnitPayeeStructuralUnitType = Enums.StructuralUnitsTypes.Retail
			 OR Header.StructuralUnitPayeeStructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
				TemplateArea = Template.GetArea("TotalPrices");
				TemplateArea.Parameters.TotalAmount = TotalAmount;
			Else
				TemplateArea = Template.GetArea("Total");
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Signatures");
			
			ParameterValues = New Structure;
			
			SNPReleaseMade = "";
			SmallBusinessServer.SurnameInitialsByName(SNPReleaseMade, String(Header.Released));
			ParameterValues.Insert("ResponsiblePresentation", SNPReleaseMade);
			
			TemplateArea.Parameters.Fill(ParameterValues);
			SpreadsheetDocument.Put(TemplateArea);
			
		ElsIf TemplateName = "MerchandiseFillingFormSender" Then
			
			Query.Text = 
			"SELECT
			|	InventoryTransfer.Date AS DocumentDate,
			|	InventoryTransfer.StructuralUnit AS WarehousePresentation,
			|	InventoryTransfer.Cell AS CellPresentation,
			|	InventoryTransfer.Number,
			|	InventoryTransfer.Company.Prefix AS Prefix,
			|	InventoryTransfer.Inventory.(
			|		LineNumber AS LineNumber,
			|		ProductsAndServices.Warehouse AS Warehouse,
			|		ProductsAndServices.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(InventoryTransfer.Inventory.ProductsAndServices.DescriptionFull AS String(100))) = """"
			|				THEN InventoryTransfer.Inventory.ProductsAndServices.Description
			|			ELSE InventoryTransfer.Inventory.ProductsAndServices.DescriptionFull
			|		END AS InventoryItem,
			|		ProductsAndServices.SKU AS SKU,
			|		ProductsAndServices.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
			|		ConnectionKey
			|	),
			|	InventoryTransfer.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.InventoryTransfer AS InventoryTransfer
			|WHERE
			|	InventoryTransfer.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryTransfer_FormOfFilling";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.InventoryTransfer.PF_MXL_MerchandiseFillingForm");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText =
				"Inventory transfer #"
			  + DocumentNumber
			  + " from "
			  + Format(Header.DocumentDate, "DLF=DD");
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.FunctionalOptionAccountingByCells.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime =
				"Date and time of printing: "
			  + CurrentDate()
			  + ". User: "
			  + Users.CurrentUser();
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do
				
				If Not LinesSelectionInventory.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				TemplateArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(
					LinesSelectionInventory.InventoryItem,
					LinesSelectionInventory.Characteristic,
					LinesSelectionInventory.SKU,
					StringSerialNumbers);
					
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);
			
		ElsIf TemplateName = "MerchandiseFillingFormRecipient" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text =
			"SELECT
			|	InventoryTransfer.Date AS DocumentDate,
			|	InventoryTransfer.StructuralUnitPayee AS WarehousePresentation,
			|	InventoryTransfer.CellPayee AS CellPresentation,
			|	InventoryTransfer.Number,
			|	InventoryTransfer.Company.Prefix AS Prefix,
			|	InventoryTransfer.Inventory.(
			|		LineNumber AS LineNumber,
			|		ProductsAndServices.Warehouse AS Warehouse,
			|		ProductsAndServices.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(InventoryTransfer.Inventory.ProductsAndServices.DescriptionFull AS String(100))) = """"
			|				THEN InventoryTransfer.Inventory.ProductsAndServices.Description
			|			ELSE InventoryTransfer.Inventory.ProductsAndServices.DescriptionFull
			|		END AS InventoryItem,
			|		ProductsAndServices.SKU AS SKU,
			|		ProductsAndServices.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
			|		ConnectionKey
			|	),
			|	InventoryTransfer.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.InventoryTransfer AS InventoryTransfer
			|WHERE
			|	InventoryTransfer.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryTransfer_FormOfFilling";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.InventoryTransfer.PF_MXL_MerchandiseFillingForm");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText =
				"Inventory transfer #"
			  + DocumentNumber
			  + " from "
			  + Format(Header.DocumentDate, "DLF=DD");
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.FunctionalOptionAccountingByCells.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime =
				"Date and time of printing: "
			  + CurrentDate()
			  + ". User: "
			  + Users.CurrentUser();
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do
				
				If Not LinesSelectionInventory.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				TemplateArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(
					LinesSelectionInventory.InventoryItem,
					LinesSelectionInventory.Characteristic,
					LinesSelectionInventory.SKU,
					StringSerialNumbers);
					
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
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
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "InventoryTransfer") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "InventoryTransfer", "Inventory transfer", PrintForm(ObjectsArray, PrintObjects, "InventoryTransfer"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "MerchandiseFillingFormSender") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "MerchandiseFillingFormSender", "Merchandise filling form", PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingFormSender"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "MerchandiseFillingFormRecipient") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "MerchandiseFillingFormRecipient", "Merchandise filling form", PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingFormRecipient"));
		
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
	PrintCommand.ID = "InventoryTransfer";
	PrintCommand.Presentation = NStr("en='Inventory movement';ru='Перемещение запасов'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 20;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingFormSender";
	PrintCommand.Presentation = NStr("en='Goods content form (Sender)';ru='Бланк товарного наполнения (Отправитель)'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 23;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingFormRecipient";
	PrintCommand.Presentation = NStr("en='Goods content form (Recipient)';ru='Бланк товарного наполнения (Получатель)'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 26;
	
	If AccessRight("view", Metadata.DataProcessors.PrintLabelsAndTags) Then
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler = "SmallBusinessClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID = "LabelsPrintingFromGoodsMovement";
		PrintCommand.Presentation = NStr("en='Print labels';ru='Печать этикеток'");
		PrintCommand.FormsList = "DocumentForm,ListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 29;
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler = "SmallBusinessClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID = "PriceTagsPrintingFromGoodsMovement";
		PrintCommand.Presentation = NStr("en='Print price tags';ru='Печать ценников'");
		PrintCommand.FormsList = "DocumentForm,ListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 32;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf