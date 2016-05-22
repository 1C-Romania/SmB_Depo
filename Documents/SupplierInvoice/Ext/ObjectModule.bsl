#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS OF DOCUMENT

// Procedure distributes expenses by quantity.
//
Procedure DistributeTabSectExpensesByQuantity() Export
	
	SrcAmount = 0;
	DistributionBaseQuantity = Inventory.Total("Quantity");
	TotalExpenses = Expenses.Total("Total");
	
	//( elmi #11
	If  Not IncludeVATInPrice Then
	      TotalVatAmount = Expenses.Итог("VATAmount");
	      TotalExpenses = TotalExpenses - TotalVatAmount ;
	EndIf;		  
    //) elmi
	
	
	For Each StringInventory IN Inventory Do
		
		StringInventory.AmountExpenses = ?(DistributionBaseQuantity <> 0, Round((TotalExpenses - SrcAmount) * StringInventory.Quantity / DistributionBaseQuantity, 2, 1),0); 
		DistributionBaseQuantity = DistributionBaseQuantity - StringInventory.Quantity;
		SrcAmount = SrcAmount + StringInventory.AmountExpenses; 
		
	EndDo;
	
EndProcedure // DistributeTabSectionExpensesByCount()

// Procedure distributes expenses by amount.
//
Procedure DistributeTabSectExpensesByAmount() Export
	
	SrcAmount = 0;
	ReserveAmount = Inventory.Total("Total");
	TotalExpenses = Expenses.Total("Total");
	
	//( elmi #11
	If  Not IncludeVATInPrice Then
	      TotalVatAmount = Expenses.Итог("VATAmount");
	      TotalExpenses = TotalExpenses - TotalVatAmount ;
	EndIf;		  
    //) elmi
	
	
	For Each StringInventory IN Inventory Do
		
		StringInventory.AmountExpenses = ?(ReserveAmount <> 0, Round((TotalExpenses - SrcAmount) * StringInventory.Total / ReserveAmount, 2, 1),0);     
		ReserveAmount = ReserveAmount - StringInventory.Total;
		SrcAmount = SrcAmount + StringInventory.AmountExpenses; 
		
	EndDo;
	
EndProcedure // DistributeTabSectionExpensesByAmount()

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	OrderInHeader = (PurchaseOrderPosition = Enums.AttributePositionOnForm.InHeader);
	Counterparty = SmallBusinessServer.GetCompany(Company);
	
	// Preparation of the order table.
	OrdersTable = Inventory.Unload(, "Order, Total");
	OrdersTable.Columns.Add("TotalCalc");
	For Each CurRow IN Expenses Do
		NewRow = OrdersTable.Add();
		NewRow.Order = CurRow.PurchaseOrder;
		NewRow.Total = CurRow.Total;
	EndDo;
	For Each CurRow IN OrdersTable Do
		If Not Counterparty.DoOperationsByOrders Then
			CurRow.Order = Documents.PurchaseOrder.EmptyRef();
		ElsIf OrderInHeader Then
			CurRow.Order = Order;
		Else
			CurRow.Order = ?(CurRow.Order = Undefined, Documents.PurchaseOrder.EmptyRef(), CurRow.Order);
		EndIf;
		CurRow.TotalCalc = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
			CurRow.Total,
			?(Contract.SettlementsCurrency = DocumentCurrency, ExchangeRate, 1),
			ExchangeRate,
			?(Contract.SettlementsCurrency = DocumentCurrency, Multiplicity, 1),
			Multiplicity
		);
	EndDo;
	OrdersTable.GroupBy("Order", "Total, TotalCalc");
	OrdersTable.Sort("Order Asc");
	
	// Filling prepayment details.
	Query = New Query;
	
	QueryText =
	"SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsPayableBalances
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Document.Date AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order IN (&Order)
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Document.Date,
	|		DocumentRegisterRecordsVendorSettlements.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsVendorSettlements.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsVendorSettlements.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsVendorSettlements.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsVendorSettlements.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsVendorSettlements
	|	WHERE
	|		DocumentRegisterRecordsVendorSettlements.Recorder = &Ref
	|		AND DocumentRegisterRecordsVendorSettlements.Period <= &Period
	|		AND DocumentRegisterRecordsVendorSettlements.Company = &Company
	|		AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsVendorSettlements.Contract = &Contract
	|		AND DocumentRegisterRecordsVendorSettlements.Order IN (&Order)
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsPayableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(AccountsPayableBalances.AccountingAmount) AS AccountingAmount,
	|	-SUM(AccountsPayableBalances.SettlementsAmount) AS SettlementsAmount,
	|	-SUM(AccountsPayableBalances.PaymentAmount) AS PaymentAmount,
	|	SUM(AccountsPayableBalances.AccountingAmount / CASE
	|			WHEN ISNULL(AccountsPayableBalances.SettlementsAmount, 0) <> 0
	|				THEN AccountsPayableBalances.SettlementsAmount
	|			ELSE 1
	|		END) * (AccountsPayableBalances.SettlementsCurrencyCurrencyRatesRate / AccountsPayableBalances.SettlementsCurrencyCurrencyRatesMultiplicity) AS ExchangeRate,
	|	1 AS Multiplicity,
	|	AccountsPayableBalances.DocumentCurrencyCurrencyRatesRate AS DocumentCurrencyCurrencyRatesRate,
	|	AccountsPayableBalances.DocumentCurrencyCurrencyRatesMultiplicity AS DocumentCurrencyCurrencyRatesMultiplicity
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.DocumentDate AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AccountingAmount,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS SettlementsAmount,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) * SettlementsCurrencyCurrencyRates.ExchangeRate * &MultiplicityOfDocumentCurrency / (&DocumentCurrencyRate * SettlementsCurrencyCurrencyRates.Multiplicity) AS PaymentAmount,
	|		SettlementsCurrencyCurrencyRates.ExchangeRate AS SettlementsCurrencyCurrencyRatesRate,
	|		SettlementsCurrencyCurrencyRates.Multiplicity AS SettlementsCurrencyCurrencyRatesMultiplicity,
	|		&DocumentCurrencyRate AS DocumentCurrencyCurrencyRatesRate,
	|		&MultiplicityOfDocumentCurrency AS DocumentCurrencyCurrencyRatesMultiplicity
	|	FROM
	|		TemporaryTableAccountsPayableBalances AS AccountsPayableBalances
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, Currency = &AccountingCurrency) AS SettlementsCurrencyCurrencyRates
	|			ON (TRUE)) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency,
	|	AccountsPayableBalances.SettlementsCurrencyCurrencyRatesRate,
	|	AccountsPayableBalances.SettlementsCurrencyCurrencyRatesMultiplicity,
	|	AccountsPayableBalances.DocumentCurrencyCurrencyRatesRate,
	|	AccountsPayableBalances.DocumentCurrencyCurrencyRatesMultiplicity
	|
	|HAVING
	|	-SUM(AccountsPayableBalances.SettlementsAmount) > 0
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Order", OrdersTable.UnloadColumn("Order"));
	Query.SetParameter("Company", Counterparty);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", Date);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	If Contract.SettlementsCurrency = DocumentCurrency Then
		Query.SetParameter("DocumentCurrencyRate", ExchangeRate);
		Query.SetParameter("MultiplicityOfDocumentCurrency", Multiplicity);
	Else
		Query.SetParameter("DocumentCurrencyRate", 1);
		Query.SetParameter("MultiplicityOfDocumentCurrency", 1);
	EndIf;
	Query.SetParameter("Ref", Ref);
	
	Query.Text = QueryText;
	
	Prepayment.Clear();
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	While SelectionOfQueryResult.Next() Do
		
		FoundString = OrdersTable.Find(SelectionOfQueryResult.Order, "Order");
		
		If FoundString.TotalCalc = 0 Then
			Continue;
		EndIf;
		
		If SelectionOfQueryResult.SettlementsAmount <= FoundString.TotalCalc Then // balance amount is less or equal than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			FoundString.TotalCalc = FoundString.TotalCalc - SelectionOfQueryResult.SettlementsAmount;
			
		Else // Balance amount is greater than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			NewRow.SettlementsAmount = FoundString.TotalCalc;
			NewRow.PaymentAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
				NewRow.SettlementsAmount,
				SelectionOfQueryResult.ExchangeRate,
				SelectionOfQueryResult.DocumentCurrencyCurrencyRatesRate,
				SelectionOfQueryResult.Multiplicity,
				SelectionOfQueryResult.DocumentCurrencyCurrencyRatesMultiplicity
			);
			FoundString.TotalCalc = 0;
			
		EndIf;
		
	EndDo;
	
EndProcedure // FillPrepayment()

// Procedure of the document filling based on the customer invoice.
//
// Parameters:
// BasisDocument - DocumentRef.CustomerInvoice - customer
// invoice FillingData - Structure - Document filling data
//	
Procedure FillBySalesInvoice(FillingData)
	
	// Filling out a document header.
	If FillingData.OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer Then
		OperationKind = Enums.OperationKindsSupplierInvoice.ReturnFromCustomer;
		DiscountCard = FillingData.DiscountCard;
	ElsIf FillingData.OperationKind = Enums.OperationKindsCustomerInvoice.TransferForCommission Then
		OperationKind = Enums.OperationKindsSupplierInvoice.ReturnFromAgent;
	ElsIf FillingData.OperationKind = Enums.OperationKindsCustomerInvoice.TransferToProcessing Then
		OperationKind = Enums.OperationKindsSupplierInvoice.ReturnFromSubcontractor;
	ElsIf FillingData.OperationKind = Enums.OperationKindsCustomerInvoice.TransferForSafeCustody Then
		OperationKind = Enums.OperationKindsSupplierInvoice.ReturnFromSafeCustody;
	Else
		ErrorMessage = NStr("en = 'Cannot input operation ""Receipt"" on the basis of the operation - ""%OperationKind"".'");
		ErrorMessage = StrReplace(ErrorMessage, "%OperationKind", FillingData.OperationKind);
		Raise ErrorMessage;
	EndIf;
	
	If FillingData.CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader 
		AND SmallBusinessReUse.AttributeInHeader("PurchaseOrderPositionInReceiptDocuments") Then
		Order = FillingData.Order;
	Else
		Order = Undefined;
	EndIf;
	
	ThisObject.BasisDocument = FillingData.Ref;
	Company = FillingData.Company;
	Counterparty = FillingData.Counterparty;
	Contract = FillingData.Contract;
	StructuralUnit = FillingData.StructuralUnit;
	Cell = FillingData.Cell;
	DocumentCurrency = FillingData.DocumentCurrency;
	AmountIncludesVAT = FillingData.AmountIncludesVAT;
	IncludeVATInPrice = FillingData.IncludeVATInPrice;
	VATTaxation = FillingData.VATTaxation;
	
	ExchangeRate = FillingData.ExchangeRate;
	Multiplicity = FillingData.Multiplicity;
	
	// Filling document tabular section.
	Inventory.Clear();
	For Each TabularSectionRow IN FillingData.Inventory Do
		
		If TabularSectionRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
		
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			
			If Not FillingData.CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader
				AND SmallBusinessReUse.AttributeInHeader("PurchaseOrderPositionInReceiptDocuments") Then
				NewRow.Order = Undefined;
			EndIf;
			
		EndIf;
		
	EndDo;
		
EndProcedure // FillBySalesInvoice()

// Procedure of document filling based on customer order.
//
// Parameters:
// FillingData - Structure - Document filling data
//	
Procedure FillByCustomerOrder(FillingData)
	
	If SmallBusinessReUse.AttributeInHeader("PurchaseOrderPositionInReceiptDocuments") Then
		Order = FillingData;
	Else
		Order = Undefined;
	EndIf;
	
	// Header filling.
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, 
			New Structure("Company, Ref, OperationKind, Counterparty, Contract, DocumentCurrency, VATTaxation, AmountIncludesVAT, IncludeVATInPrice, ExchangeRate, Multiplicity, OrderState, Closed, Posted"));
			
	AttributeValues.Insert("JobOrderReturn");
	Documents.CustomerOrder.CheckAbilityOfEnteringByCustomerOrder(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues, "Company, Counterparty, Contract, DocumentCurrency, VATTaxation, AmountIncludesVAT, IncludeVATInPrice, ExchangeRate, Multiplicity");
	ThisObject.BasisDocument = FillingData;
	
	If Not DocumentCurrency = Constants.NationalCurrency.Get() Then
		StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(?(ValueIsFilled(Date), Date, CurrentDate()), New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
	EndIf;
	
	If ValueIsFilled(Contract) Then
		
		CounterpartyPriceKind = Contract.CounterpartyPriceKind;
		RegisterVendorPrices = True;
		
	EndIf;
	
	// Tabular section filling.
	Inventory.Clear();
	If AttributeValues.OperationKind = Enums.OperationKindsCustomerOrder.OrderForProcessing Then
		OperationKind = Enums.OperationKindsSupplierInvoice.ReceptionIntoProcessing;
		VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
		FillByCustomerOrderForProcessing(FillingData);
	ElsIf AttributeValues.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
		OperationKind = Enums.OperationKindsSupplierInvoice.ReturnFromCustomer;
		FillByJobOrder(FillingData);
		DiscountCard = FillingData.DiscountCard;
	Else
		OperationKind = Enums.OperationKindsSupplierInvoice.ReturnFromCustomer;
		FillByCustomerOrderForSale(FillingData);
		DiscountCard = FillingData.DiscountCard;
	EndIf;
	
EndProcedure // FillByCustomerOrder()

// Procedure of document filling based on customer order.
//
// Parameters:
// FillingData - Structure - Document filling data
//	
Procedure FillByCustomerOrderForProcessing(FillingData)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DemandBalances.ProductsAndServices AS ProductsAndServices,
	|	DemandBalances.Characteristic AS Characteristic,
	|	SUM(DemandBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		DemandBalances.ProductsAndServices AS ProductsAndServices,
	|		DemandBalances.Characteristic AS Characteristic,
	|		DemandBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				,
	|				CustomerOrder = &BasisDocument
	|					AND MovementType = VALUE(Enum.InventoryMovementTypes.Receipt)) AS DemandBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryDemand.ProductsAndServices,
	|		DocumentRegisterRecordsInventoryDemand.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryDemand AS DocumentRegisterRecordsInventoryDemand
	|	WHERE
	|		DocumentRegisterRecordsInventoryDemand.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryDemand.CustomerOrder = &BasisDocument) AS DemandBalances
	|
	|GROUP BY
	|	DemandBalances.ProductsAndServices,
	|	DemandBalances.Characteristic
	|
	|HAVING
	|	SUM(DemandBalances.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(CustomerOrderConsumerMaterials.LineNumber) AS LineNumber,
	|	CustomerOrderConsumerMaterials.ProductsAndServices AS ProductsAndServices,
	|	CustomerOrderConsumerMaterials.Characteristic AS Characteristic,
	|	CustomerOrderConsumerMaterials.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN VALUETYPE(CustomerOrderConsumerMaterials.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE CustomerOrderConsumerMaterials.MeasurementUnit.Factor
	|	END AS Factor,
	|	CASE
	|		WHEN CustomerOrderConsumerMaterials.ProductsAndServices.VATRate = VALUE(Catalog.VATRates.EmptyRef)
	|			THEN CustomerOrderConsumerMaterials.Ref.Company.DefaultVATRate
	|		ELSE CustomerOrderConsumerMaterials.ProductsAndServices.VATRate
	|	END AS VATRate,
	|	CustomerOrderConsumerMaterials.Ref AS Order,
	|	SUM(CustomerOrderConsumerMaterials.Quantity) AS Quantity
	|FROM
	|	Document.CustomerOrder.ConsumerMaterials AS CustomerOrderConsumerMaterials
	|WHERE
	|	CustomerOrderConsumerMaterials.Ref = &BasisDocument
	|
	|GROUP BY
	|	CustomerOrderConsumerMaterials.ProductsAndServices,
	|	CustomerOrderConsumerMaterials.Characteristic,
	|	CustomerOrderConsumerMaterials.MeasurementUnit,
	|	CASE
	|		WHEN VALUETYPE(CustomerOrderConsumerMaterials.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE CustomerOrderConsumerMaterials.MeasurementUnit.Factor
	|	END,
	|	CustomerOrderConsumerMaterials.Ref,
	|	CASE
	|		WHEN CustomerOrderConsumerMaterials.ProductsAndServices.VATRate = VALUE(Catalog.VATRates.EmptyRef)
	|			THEN CustomerOrderConsumerMaterials.Ref.Company.DefaultVATRate
	|		ELSE CustomerOrderConsumerMaterials.ProductsAndServices.VATRate
	|	END
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("ProductsAndServices,Characteristic");
	
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[1].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
			StructureForSearch.Insert("Characteristic", Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
			QuantityToWriteOff = Selection.Quantity * Selection.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				
				NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
				
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure // FillByCustomerOrderForProcessing()

// Procedure of document filling based on customer order.
//
// Parameters:
// FillingData - Structure - Document filling data
//	
Procedure FillByCustomerOrderForSale(FillingData)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	OrdersBalance.ProductsAndServices AS ProductsAndServices,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.ProductsAndServices AS ProductsAndServices,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.CustomerOrders.Balance(
	|				,
	|				CustomerOrder = &BasisDocument
	|					AND ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsCustomersOrders.ProductsAndServices,
	|		DocumentRegisterRecordsCustomersOrders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsCustomersOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsCustomersOrders.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsCustomersOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.CustomerOrders AS DocumentRegisterRecordsCustomersOrders
	|	WHERE
	|		DocumentRegisterRecordsCustomersOrders.Recorder = &Ref
	|		AND DocumentRegisterRecordsCustomersOrders.CustomerOrder = &BasisDocument) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.ProductsAndServices,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CustomerOrderInventory.ProductsAndServices AS ProductsAndServices,
	|	CustomerOrderInventory.Batch AS Batch,
	|	CustomerOrderInventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(CustomerOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE CustomerOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	CustomerOrderInventory.Quantity AS Quantity,
	|	CustomerOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CustomerOrderInventory.Price AS Price,
	|	CustomerOrderInventory.Amount AS Amount,
	|	CustomerOrderInventory.VATRate AS VATRate,
	|	CustomerOrderInventory.VATAmount AS VATAmount,
	|	CustomerOrderInventory.Total AS Total,
	|	CustomerOrderInventory.Content AS Content,
	|	CustomerOrderInventory.Ref AS Order
	|FROM
	|	Document.CustomerOrder.Inventory AS CustomerOrderInventory
	|WHERE
	|	CustomerOrderInventory.Ref = &BasisDocument
	|	AND CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("ProductsAndServices,Characteristic");
	
	Selection = ResultsArray[1].Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		
		BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() = 0 Then
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
		ElsIf (BalanceRowsArray[0].QuantityBalance / Selection.Factor) = Selection.Quantity Then
			
			Continue;
			
		ElsIf (BalanceRowsArray[0].QuantityBalance / Selection.Factor) > Selection.Quantity Then
			
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - Selection.Quantity * Selection.Factor;
			Continue;
			
		ElsIf (BalanceRowsArray[0].QuantityBalance / Selection.Factor) < Selection.Quantity Then
			
			QuantityToWriteOff = -1 * (BalanceRowsArray[0].QuantityBalance / Selection.Factor - Selection.Quantity);
			BalanceRowsArray[0].QuantityBalance = 0;
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
			DataStructure = SmallBusinessServer.GetTabularSectionRowSum(
				New Structure("Quantity, Price, Amount, VATRate, VATAmount, AmountIncludesVAT, Total",
					QuantityToWriteOff, Selection.Price, 0, Selection.VATRate, 0, AmountIncludesVAT, 0));
					
			FillPropertyValues(NewRow, DataStructure);
			
		EndIf;
		
	EndDo;
	
EndProcedure // FillByCustomerOrderForSale()

// The procedure of document completion on the basis of the job order.
//
// Parameters:
// FillingData - Structure - Document filling data
//	
Procedure FillByJobOrder(FillingData)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CustomerOrderInventory.ProductsAndServices AS ProductsAndServices,
	|	CustomerOrderInventory.Batch AS Batch,
	|	CustomerOrderInventory.Characteristic AS Characteristic,
	|	CustomerOrderInventory.Quantity AS Quantity,
	|	CustomerOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CustomerOrderInventory.Price AS Price,
	|	CustomerOrderInventory.Amount AS Amount,
	|	CustomerOrderInventory.VATRate AS VATRate,
	|	CustomerOrderInventory.VATAmount AS VATAmount,
	|	CustomerOrderInventory.Total AS Total,
	|	CustomerOrderInventory.Content AS Content,
	|	CustomerOrderInventory.Ref AS Order
	|FROM
	|	Document.CustomerOrder.Inventory AS CustomerOrderInventory
	|WHERE
	|	CustomerOrderInventory.Ref = &BasisDocument
	|	AND CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	EndIf;
	
EndProcedure // FillByJobOrder()

// Procedure of document filling based on purchase order.
//
// Parameters:
// FillingData - Structure - Document filling data
//	
Procedure FillByPurchaseOrder(FillingData)
	
	// Document basis and document setting.
	OrdersArray = New Array;
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("PurchaseOrdersArray") Then
		OrdersArray = FillingData.PurchaseOrdersArray;
		PurchaseOrderPosition = Enums.AttributePositionOnForm.InTabularSection;
	Else
		OrdersArray.Add(FillingData.Ref);
		PurchaseOrderPosition = SmallBusinessReUse.GetValueOfSetting("PurchaseOrderPositionInReceiptDocuments");
		If Not ValueIsFilled(PurchaseOrderPosition) Then
			PurchaseOrderPosition = Enums.AttributePositionOnForm.InHeader;
		EndIf;
		If PurchaseOrderPosition = Enums.AttributePositionOnForm.InHeader Then
			Order = FillingData;
		EndIf;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT
	|	PurchaseOrder.Ref AS BasisRef,
	|	PurchaseOrder.Posted AS BasisPosted,
	|	PurchaseOrder.Closed AS Closed,
	|	PurchaseOrder.OrderState AS OrderState,
	|	PurchaseOrder.CustomerOrder AS CustomerOrder,
	|	PurchaseOrder.StructuralUnit AS StructuralUnitExpense,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	PurchaseOrder.VATTaxation AS VATTaxation,
	|	CASE
	|		WHEN PurchaseOrder.CounterpartyPriceKind = VALUE(Catalog.CounterpartyPriceKind.EmptyRef)
	|			THEN PurchaseOrder.Contract.CounterpartyPriceKind
	|		ELSE PurchaseOrder.CounterpartyPriceKind
	|	END AS CounterpartyPriceKind,
	|	True AS RegisterVendorPrices,
	|	CASE
	|		WHEN PurchaseOrder.DocumentCurrency = NationalCurrency.Value
	|			THEN PurchaseOrder.ExchangeRate
	|		ELSE CurrencyRatesSliceLast.ExchangeRate
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN PurchaseOrder.DocumentCurrency = NationalCurrency.Value
	|			THEN PurchaseOrder.Multiplicity
	|		ELSE CurrencyRatesSliceLast.Multiplicity
	|	END AS Multiplicity
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|		{LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&DocumentDate, ) AS CurrencyRatesSliceLast
	|		ON PurchaseOrder.Contract.SettlementsCurrency = CurrencyRatesSliceLast.Currency},
	|	Constant.NationalCurrency AS NationalCurrency
	|WHERE
	|	PurchaseOrder.Ref IN(&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted", Selection.OrderState, Selection.Closed, Selection.BasisPosted);
		Documents.PurchaseOrder.CheckEnteringAbilityOnTheBasisOfVendorOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	FillPropertyValues(ThisObject, Selection);
	
	If OrdersArray.Count() = 1 Then
		ThisObject.BasisDocument = OrdersArray[0];
	EndIf;
	
	// Document filling.
	Query = New Query;
	Query.Text =
	"SELECT
	|	OrdersBalance.PurchaseOrder AS PurchaseOrder,
	|	OrdersBalance.ProductsAndServices AS ProductsAndServices,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.PurchaseOrder AS PurchaseOrder,
	|		OrdersBalance.ProductsAndServices AS ProductsAndServices,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.PurchaseOrders.Balance(
	|				,
	|				PurchaseOrder IN (&OrdersArray)
	|					AND (ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|						OR ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Service))) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsPurchaseOrders.PurchaseOrder,
	|		DocumentRegisterRecordsPurchaseOrders.ProductsAndServices,
	|		DocumentRegisterRecordsPurchaseOrders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsPurchaseOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsPurchaseOrders.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsPurchaseOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.PurchaseOrders AS DocumentRegisterRecordsPurchaseOrders
	|	WHERE
	|		DocumentRegisterRecordsPurchaseOrders.Recorder = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.PurchaseOrder,
	|	OrdersBalance.ProductsAndServices,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.Ref.CustomerOrder AS CustomerOrder,
	|	PurchaseOrderInventory.Ref.StructuralUnit AS StructuralUnitExpense,
	|	PurchaseOrderInventory.ProductsAndServices AS ProductsAndServices,
	|	PurchaseOrderInventory.ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|	PurchaseOrderInventory.ProductsAndServices.ExpensesGLAccount.TypeOfAccount AS TypeOfAccount,
	|	PurchaseOrderInventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE PurchaseOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	PurchaseOrderInventory.Quantity AS Quantity,
	|	PurchaseOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	PurchaseOrderInventory.Price AS Price,
	|	PurchaseOrderInventory.Amount AS Amount,
	|	PurchaseOrderInventory.VATRate AS VATRate,
	|	PurchaseOrderInventory.VATAmount AS VATAmount,
	|	PurchaseOrderInventory.Total AS Total,
	|	PurchaseOrderInventory.Content AS Content,
	|	PurchaseOrderInventory.Ref AS OrderBasis
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|WHERE
	|	PurchaseOrderInventory.Ref IN(&OrdersArray)
	|	AND (PurchaseOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Service)
	|			OR PurchaseOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem))
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentDate()));
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("PurchaseOrder,ProductsAndServices,Characteristic");
	
	Inventory.Clear();
	Expenses.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[1].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("PurchaseOrder", Selection.OrderBasis);
			StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
			StructureForSearch.Insert("Characteristic", Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			If Selection.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service Then
				NewRow = Expenses.Add();
				NewRow.PurchaseOrder = Selection.OrderBasis;
				NewRow.StructuralUnit = Selection.StructuralUnitExpense;
				If ValueIsFilled(Selection.CustomerOrder)
					AND (Selection.TypeOfAccount = Enums.GLAccountsTypes.Expenses
					OR Selection.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
					OR Selection.TypeOfAccount = Enums.GLAccountsTypes.UnfinishedProduction) Then
					NewRow.Order = Selection.CustomerOrder;
				EndIf;
			Else
				NewRow = Inventory.Add();
				NewRow.Order = Selection.OrderBasis;
			EndIf;
			FillPropertyValues(NewRow, Selection);
			
			QuantityToWriteOff = Selection.Quantity * Selection.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				
				QuantityToWriteOff = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
				
				DataStructure = SmallBusinessServer.GetTabularSectionRowSum(
					New Structure("Quantity, Price, Amount, VATRate, VATAmount, AmountIncludesVAT, Total",
						QuantityToWriteOff, Selection.Price, 0, Selection.VATRate, 0, AmountIncludesVAT, 0));
				
				FillPropertyValues(NewRow, DataStructure);
				
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure // FillByPurchaseOrder()

// Procedure of document filling on the basis of the goods receipt.
//
// Parameters:
// FillingData - Structure - Document filling data
//	
Procedure FillByGoodsReceipt(FillingData)
	
	// Filling out a document header.
	ThisObject.BasisDocument = FillingData.Ref;
	OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor;
	Company = FillingData.Company;
	StructuralUnit = FillingData.StructuralUnit;
	Cell = FillingData.Cell;
	VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
	
	// Filling document tabular section.
	For Each TabularSectionRow IN FillingData.Inventory Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		
		NewRow.VATRate = TabularSectionRow.ProductsAndServices.VATRate;
		
	EndDo;
	
EndProcedure // FillByGoodsReceipt()

// Procedure of document filling based on purchase order.
//
// Parameters:
// FillingData - Structure - Document filling data
//	
Procedure FillBySupplierInvoiceForPayment(FillingData)
	
	// Filling out a document header.
	ThisObject.BasisDocument = FillingData.Ref;
	OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor;
	
	If SmallBusinessReUse.AttributeInHeader("PurchaseOrderPositionInReceiptDocuments") Then
		Order = FillingData.BasisDocument;
	Else
		Order = Undefined;
	EndIf;
	
	Company = FillingData.Company;
	Counterparty = FillingData.Counterparty;
	Contract = FillingData.Contract;
	DocumentCurrency = FillingData.DocumentCurrency;
	AmountIncludesVAT = FillingData.AmountIncludesVAT;
	VATTaxation = FillingData.VATTaxation;
	
	CounterpartyPriceKind = FillingData.CounterpartyPriceKind;
	If Not ValueIsFilled(CounterpartyPriceKind) Then
		CounterpartyPriceKind = Contract.CounterpartyPriceKind;
	EndIf;
	
	RegisterVendorPrices = ValueIsFilled(CounterpartyPriceKind);
	
	If DocumentCurrency = Constants.NationalCurrency.Get() Then
		ExchangeRate = FillingData.ExchangeRate;
		Multiplicity = FillingData.Multiplicity;
	Else
		StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
	EndIf;
	
	// Filling document tabular section.
	Inventory.Clear();
	Expenses.Clear();
	For Each TabularSectionRow IN FillingData.Inventory Do
		
		If TabularSectionRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			NewRow.Order = FillingData.BasisDocument;
			
		ElsIf TabularSectionRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service Then
			
			NewRow = Expenses.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			NewRow.PurchaseOrder = FillingData.BasisDocument;
			
			TypePaymentExpenses = NewRow.ProductsAndServices.ExpensesGLAccount.TypeOfAccount;
			If TypePaymentExpenses <> Enums.GLAccountsTypes.Expenses
				AND TypePaymentExpenses <> Enums.GLAccountsTypes.Incomings
				AND TypePaymentExpenses <> Enums.GLAccountsTypes.UnfinishedProduction
				AND TypePaymentExpenses <> Enums.GLAccountsTypes.IndirectExpenses Then
				
				NewRow.Order = Undefined;
				NewRow.StructuralUnit = Undefined;
				
			Else
				
				NewRow.StructuralUnit = FillingData.Division;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure // FillByPurchaseOrder()

#Region CWP

// Procedure of the document filling based on the customer invoice.
//
// Parameters:
// BasisDocument - DocumentRef.CustomerInvoice - customer
// invoice FillingData - Structure - Document filling data
//	
Procedure FillInByCRReceipt(FillingData)
	
	// Filling out a document header.
	OperationKind = Enums.OperationKindsSupplierInvoice.ReturnFromCustomer;
	Order = Undefined;
	DiscountCard = FillingData.DiscountCard;
	
	ThisObject.ReceiptCR = FillingData.Ref;
	Company = FillingData.Company;
	StructuralUnit = FillingData.StructuralUnit;
	DocumentCurrency = FillingData.DocumentCurrency;
	AmountIncludesVAT = FillingData.AmountIncludesVAT;
	IncludeVATInPrice = FillingData.IncludeVATInPrice;
	VATTaxation = FillingData.VATTaxation;
	
	ExchangeRate = 1; // Receipts are issued in the currency of the regulatory accounting.
	Multiplicity = 1; // Receipts are issued in the currency of the regulatory accounting.
	
	// Filling document tabular section.
	Inventory.Clear();
	For Each TabularSectionRow IN FillingData.Inventory Do
		
		If TabularSectionRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
		
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			NewRow.Order = Undefined;
			
		EndIf;
		
	EndDo;
		
EndProcedure // FillBySalesInvoice()

#EndRegion

// Procedure of cancellation of posting of subordinate invoice note (supplier)
//
Procedure SubordinatedInvoiceControl()
	
	InvoiceStructure = SmallBusinessServer.GetSubordinateInvoice(Ref, True);
	If Not InvoiceStructure = Undefined Then
		
		CustomerInvoiceNote	 = InvoiceStructure.Ref;
		If CustomerInvoiceNote.Posted Then
			
			MessageText = NStr("en = 'Due to the absence of the turnovers by the %CurrentDocumentPresentation% document, undo the posting of %InvoicePresentation%.'");
			MessageText = StrReplace(MessageText, "%CurrentDocumentPresentation%", """Supplier invoice No " + Number + " from " + Format(Date, "DF=dd.MM.yyyy") + """");
			MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Invoice Note (Supplier) No. " + InvoiceStructure.Number + " from " + InvoiceStructure.Date + """");
			
			CommonUseClientServer.MessageToUser(MessageText);
			
			InvoiceObject = CustomerInvoiceNote.GetObject();
			InvoiceObject.Write(DocumentWriteMode.UndoPosting);
			
		EndIf;
		
	EndIf;
	
EndProcedure //SubordinateInvoiceControl()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	SmallBusinessManagementElectronicDocumentsServer.ClearIncomingDocumentDateNumber(ThisObject);
	Prepayment.Clear();
	
EndProcedure // OnCopy()

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.CustomerInvoice") Then
		
		FillBySalesInvoice(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
		
		FillByCustomerOrder(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") 
		OR (TypeOf(FillingData) = Type("Structure") AND FillingData.Property("PurchaseOrdersArray")) Then
		
		FillByPurchaseOrder(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.GoodsReceipt") Then
		
		FillByGoodsReceipt(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoiceForPayment") Then	
		
		FillBySupplierInvoiceForPayment(FillingData);
		
	// CWP
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ReceiptCR") Then
		
		FillInByCRReceipt(FillingData);
		
	// End CWP
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		
		FillPropertyValues(ThisObject, FillingData);
		If Not ValueIsFilled(CounterpartyPriceKind) 
			AND ValueIsFilled(Contract) Then
			
			CounterpartyPriceKind = Contract.CounterpartyPriceKind;
			
		EndIf;
		RegisterVendorPrices = ValueIsFilled(CounterpartyPriceKind);
		
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If PurchaseOrderPosition = Enums.AttributePositionOnForm.InHeader Then
		For Each TabularSectionRow IN Inventory Do
			TabularSectionRow.Order = Order;
		EndDo;
		If Counterparty.DoOperationsByOrders Then
			For Each TabularSectionRow IN Prepayment Do
				TabularSectionRow.Order = Order;
			EndDo;
		EndIf;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total") + Expenses.Total("Total");
	
	If Not Constants.FunctionalOptionAccountingByMultipleBusinessActivities.Get() Then
		
		If OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor
		AND Not IncludeExpensesInCostPrice Then
			
			For Each RowsExpenses in Expenses Do
				
				If RowsExpenses.ProductsAndServices.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
					
					RowsExpenses.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
EndProcedure // BeforeWrite()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Check existence of retail prices.
	CheckExistenceOfRetailPrice(Cancel);
	
	If Inventory.Count() > 0 Then
		CheckedAttributes.Add("StructuralUnit");
		If OperationKind = Enums.OperationKindsSupplierInvoice.ReceptionForCommission
			OR OperationKind = Enums.OperationKindsSupplierInvoice.ReceptionIntoProcessing
			OR OperationKind = Enums.OperationKindsSupplierInvoice.ReceptionForSafeCustody Then
			CheckedAttributes.Add("Inventory.Batch");
		EndIf;
	EndIf;
	
	If Not IncludeExpensesInCostPrice Then
		
		For Each RowsExpenses IN Expenses Do
			
			If Constants.FunctionalOptionAccountingByMultipleDivisions.Get()
			   AND (RowsExpenses.ProductsAndServices.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.UnfinishedProduction
			 OR RowsExpenses.ProductsAndServices.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
			 OR RowsExpenses.ProductsAndServices.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.Incomings
			 OR RowsExpenses.ProductsAndServices.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses)
			 AND Not ValueIsFilled(RowsExpenses.StructuralUnit) Then
				MessageText = NStr(
					"en = 'For products and services ""%ProductsAndServices%"" specified in row %RowNumber% of list ""Services"" attribute ""Division"" must be filled in.'"
				);
				MessageText = StrReplace(MessageText, "%ProductsAndServices%", TrimAll(String(RowsExpenses.ProductsAndServices))); 
				MessageText = StrReplace(MessageText, "%LineNumber%",String(RowsExpenses.LineNumber));
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Expenses",
					RowsExpenses.LineNumber,
					"StructuralUnit",
					Cancel
				);
			EndIf;
		
		EndDo;
		
	EndIf;
	
	
	//( elmi #11
	//If IncludeExpensesInCostPrice
	//	AND Inventory.Total("AmountExpenses") <> Expenses.Total("Total") Then 
	If  IncludeExpensesInCostPrice Then
		If  (ThisObject.IncludeVATInPrice And Inventory.Total("AmountExpenses") <> Expenses.Total("Total"))
			OR  ( NOT ThisObject.IncludeVATInPrice And Inventory.Total("AmountExpenses") <> Expenses.Total("Total")- Expenses.Total("VATAmount")) Then
	
		MessageText = NStr("en = 'Amount of services is not equal to the distributed amount by inventories!'");
		SmallBusinessServer.ShowMessageAboutError(
			,
			MessageText,
			Undefined,
			Undefined,
			Undefined,
			Cancel
		);
		EndIf;
	EndIf;
	//) elmi

	OrderReceptionInHeader = PurchaseOrderPosition = Enums.AttributePositionOnForm.InHeader;
	
	TableInventory = Inventory.Unload(, "Order, Total");
	TableInventory.GroupBy("Order", "Total");
	
	TableExpenses = Expenses.Unload(, "PurchaseOrder, Total");
	TableExpenses.GroupBy("PurchaseOrder", "Total");
	
	TablePrepayment = Prepayment.Unload(, "Order, PaymentAmount");
	TablePrepayment.GroupBy("Order", "PaymentAmount");
	
	If OrderReceptionInHeader Then
		For Each StringInventory IN TableInventory Do
			StringInventory.Order = Order;
		EndDo;
		If Counterparty.DoOperationsByOrders Then
			For Each RowPrepayment IN TablePrepayment Do
				RowPrepayment.Order = Order;
			EndDo;
		EndIf;
	EndIf;
	
	QuantityCustomerInvoices = Inventory.Count() + Expenses.Count();
	
	For Each String IN TablePrepayment Do
		
		FoundStringExpenses = Undefined;
		FoundStringInventory = Undefined;
		
		If Counterparty.DoOperationsByOrders
		   AND String.Order <> Undefined
		   AND String.Order <> Documents.CustomerOrder.EmptyRef()
		   AND String.Order <> Documents.PurchaseOrder.EmptyRef() Then
			FoundStringInventory = TableInventory.Find(String.Order, "Order");
			FoundStringExpenses = TableExpenses.Find(String.Order, "PurchaseOrder");
			Total = 0 + ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total) + ?(FoundStringExpenses = Undefined, 0, FoundStringExpenses.Total);
		ElsIf Counterparty.DoOperationsByOrders Then
			FoundStringInventory = TableInventory.Find(Undefined, "Order");
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.CustomerOrder.EmptyRef(), "Order"), FoundStringInventory);
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.PurchaseOrder.EmptyRef(), "Order"), FoundStringInventory);
			FoundStringExpenses = TableExpenses.Find(Undefined, "PurchaseOrder");
			FoundStringExpenses = ?(FoundStringExpenses = Undefined, TableExpenses.Find(Documents.CustomerOrder.EmptyRef(), "PurchaseOrder"), FoundStringExpenses);
			FoundStringExpenses = ?(FoundStringExpenses = Undefined, TableExpenses.Find(Documents.PurchaseOrder.EmptyRef(), "PurchaseOrder"), FoundStringExpenses);
			Total = 0 + ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total) + ?(FoundStringExpenses = Undefined, 0, FoundStringExpenses.Total);
		Else
			Total = Inventory.Total("Total") + Expenses.Total("Total");
		EndIf;
		
		If FoundStringInventory = Undefined
		   AND FoundStringExpenses = Undefined
		   AND QuantityCustomerInvoices > 0
		   AND Counterparty.DoOperationsByOrders Then
			MessageText = NStr("en = 'Unable to offset the advance for the order different from the specified amount in tabular sections ""Inventory"" or ""Services"".'");
			SmallBusinessServer.ShowMessageAboutError(
				,
				MessageText,
				Undefined,
				Undefined,
				"PrepaymentTotalSettlementsAmountCurrency",
				Cancel
			);
		EndIf;
		
	EndDo;
	
	If Not Counterparty.DoOperationsByContracts Then
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.SupplierInvoice.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectOrdersPlacement(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectPurchasing(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryForWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryTransferred(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectCustomerOrders(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesUndistributed(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectRetailAmountAccounting(AdditionalProperties, RegisterRecords, Cancel);
	
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// DiscountCards
	SmallBusinessServer.ReflectSalesByDiscountCard(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.SupplierInvoice.RunControl(Ref, AdditionalProperties, Cancel);
	
	// Recording prices in information register Prices of counterparty products and services.
	Documents.SupplierInvoice.RecordVendorPrices(Ref);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.SupplierInvoice.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	// Deleting the prices from information register Prices of counterparty products and services.
	Documents.SupplierInvoice.DeleteVendorPrices(Ref);
	
	// Subordinate invoice note (supplier)
	If Not Cancel Then
		
		SubordinatedInvoiceControl();
		
	EndIf;
	
EndProcedure // UndoPosting()

// Procedure checks the existence of retail price.
//
Procedure CheckExistenceOfRetailPrice(Cancel)
	
	If StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
	 OR StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
	 
		Query = New Query;
		Query.SetParameter("Date", Date);
		Query.SetParameter("DocumentTable", Inventory);
		Query.SetParameter("RetailPriceKind", StructuralUnit.RetailPriceKind);
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
			
			MessageText = NStr("en = 'For products and services %ProductsAndServicesPresentation% in string %LineNumber% of list ""Inventory"" retail price is not set!'");
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

#EndIf