#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	OrderInHeader = (CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader);
	Counterparty = SmallBusinessServer.GetCompany(Company);
	
	// Preparation of the order table.
	OrdersTable = Inventory.Unload(, "Order, Total");
	OrdersTable.Columns.Add("TotalCalc");
	For Each CurRow IN OrdersTable Do
		If Not Counterparty.DoOperationsByOrders Then
			CurRow.Order = Documents.CustomerOrder.EmptyRef();
		ElsIf OrderInHeader Then
			CurRow.Order = Order;
		Else
			CurRow.Order = ?(CurRow.Order = Undefined, Documents.CustomerOrder.EmptyRef(), CurRow.Order);
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
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|	AccountsReceivableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsReceivableBalances
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.Contract AS Contract,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.Document.Date AS DocumentDate,
	|		AccountsReceivableBalances.Order AS Order,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order IN (&Order)
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsAccountsReceivable.Contract,
	|		DocumentRegisterRecordsAccountsReceivable.Document,
	|		DocumentRegisterRecordsAccountsReceivable.Document.Date,
	|		DocumentRegisterRecordsAccountsReceivable.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsAccountsReceivable.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsAccountsReceivable.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsAccountsReceivable.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsAccountsReceivable.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AccountsReceivable AS DocumentRegisterRecordsAccountsReceivable
	|	WHERE
	|		DocumentRegisterRecordsAccountsReceivable.Recorder = &Ref
	|		AND DocumentRegisterRecordsAccountsReceivable.Period <= &Period
	|		AND DocumentRegisterRecordsAccountsReceivable.Company = &Company
	|		AND DocumentRegisterRecordsAccountsReceivable.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsAccountsReceivable.Contract = &Contract
	|		AND DocumentRegisterRecordsAccountsReceivable.Order IN (&Order)
	|		AND DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.DocumentDate,
	|	AccountsReceivableBalances.Contract.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsReceivableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|	AccountsReceivableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(AccountsReceivableBalances.AccountingAmount) AS AccountingAmount,
	|	-SUM(AccountsReceivableBalances.SettlementsAmount) AS SettlementsAmount,
	|	-SUM(AccountsReceivableBalances.PaymentAmount) AS PaymentAmount,
	|	SUM(AccountsReceivableBalances.AccountingAmount / CASE
	|			WHEN ISNULL(AccountsReceivableBalances.SettlementsAmount, 0) <> 0
	|				THEN AccountsReceivableBalances.SettlementsAmount
	|			ELSE 1
	|		END) * (SettlementsCurrencyCurrencyRatesRate / SettlementsCurrencyCurrencyRatesMultiplicity) AS ExchangeRate,
	|	1 AS Multiplicity,
	|	AccountsReceivableBalances.DocumentCurrencyCurrencyRatesRate AS DocumentCurrencyCurrencyRatesRate,
	|	AccountsReceivableBalances.DocumentCurrencyCurrencyRatesMultiplicity AS DocumentCurrencyCurrencyRatesMultiplicity
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.SettlementsCurrency AS SettlementsCurrency,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|		AccountsReceivableBalances.Order AS Order,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AccountingAmount,
	|		ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS SettlementsAmount,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) * SettlementsCurrencyCurrencyRates.ExchangeRate * &MultiplicityOfDocumentCurrency / (&DocumentCurrencyRate * SettlementsCurrencyCurrencyRates.Multiplicity) AS PaymentAmount,
	|		SettlementsCurrencyCurrencyRates.ExchangeRate AS SettlementsCurrencyCurrencyRatesRate,
	|		SettlementsCurrencyCurrencyRates.Multiplicity AS SettlementsCurrencyCurrencyRatesMultiplicity,
	|		&DocumentCurrencyRate AS DocumentCurrencyCurrencyRatesRate,
	|		&MultiplicityOfDocumentCurrency AS DocumentCurrencyCurrencyRatesMultiplicity
	|	FROM
	|		TemporaryTableAccountsReceivableBalances AS AccountsReceivableBalances
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, Currency = &AccountingCurrency) AS SettlementsCurrencyCurrencyRates
	|			ON (TRUE)) AS AccountsReceivableBalances
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.DocumentDate,
	|	AccountsReceivableBalances.SettlementsCurrency,
	|	SettlementsCurrencyCurrencyRatesRate,
	|	SettlementsCurrencyCurrencyRatesMultiplicity,
	|	AccountsReceivableBalances.DocumentCurrencyCurrencyRatesRate,
	|	AccountsReceivableBalances.DocumentCurrencyCurrencyRatesMultiplicity
	|
	|HAVING
	|	-SUM(AccountsReceivableBalances.SettlementsAmount) > 0
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

// Procedure of filling the document on the basis of the supplier invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier
// invoice FillingData - Structure - Document filling data
//	
Procedure FillByPurchaseInvoice(FillingData, Operation = "")
	
	// Filling out a document header.
	If Operation = "Sale" Then
		If FillingData.OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor
			OR FillingData.OperationKind = Enums.OperationKindsSupplierInvoice.ReceptionForCommission Then
			OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer;
		Else
			ErrorMessage = NStr("en='Cannot input ""Sale to customer"" operation on the basis of the operation ""%OperationKind""!';ru='Невозможен ввод операции ""Продажа покупателю"" на основании операции - ""%ВидОперации""!'");
			ErrorMessage = StrReplace(ErrorMessage, "%OperationKind", FillingData.OperationKind);
			Raise ErrorMessage;
		EndIf;
	ElsIf Operation = "Return" Then
				
		If FillingData.OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor Then
			OperationKind = Enums.OperationKindsCustomerInvoice.ReturnToVendor;
		ElsIf FillingData.OperationKind = Enums.OperationKindsSupplierInvoice.ReceptionForCommission Then
			OperationKind = Enums.OperationKindsCustomerInvoice.ReturnToPrincipal;
		ElsIf FillingData.OperationKind = Enums.OperationKindsSupplierInvoice.ReceptionIntoProcessing Then
			OperationKind = Enums.OperationKindsCustomerInvoice.ReturnFromProcessing;
		ElsIf FillingData.OperationKind = Enums.OperationKindsSupplierInvoice.ReceptionForSafeCustody Then
			OperationKind = Enums.OperationKindsCustomerInvoice.ReturnFromSafeCustody;
		Else
			ErrorMessage = NStr("en='Cannot input the ""Return"" operation on the basis of the operation ""%OperationKind""!';ru='Невозможен ввод операции ""Возврат"" на основании операции - ""%ВидОперации""!'");
			ErrorMessage = StrReplace(ErrorMessage, "%OperationKind", FillingData.OperationKind);
			Raise ErrorMessage;
		EndIf;			
	EndIf;
	
	If SmallBusinessReUse.AttributeInHeader("CustomerOrderPositionInShipmentDocuments") 
		AND FillingData.PurchaseOrderPosition = Enums.AttributePositionOnForm.InHeader Then
		Order = FillingData.Order;
	Else
		Order = Undefined;
	EndIf;
	
	ThisObject.BasisDocument = FillingData.Ref;
	Company = FillingData.Company;
	
	If OperationKind = Enums.OperationKindsCustomerInvoice.ReturnToVendor
		OR OperationKind = Enums.OperationKindsCustomerInvoice.ReturnToPrincipal 
		OR OperationKind = Enums.OperationKindsCustomerInvoice.ReturnFromProcessing 
		OR OperationKind = Enums.OperationKindsCustomerInvoice.ReturnFromSafeCustody Then
		Counterparty = FillingData.Counterparty;
		Contract = FillingData.Contract;
		VATTaxation = FillingData.VATTaxation;
	Else	
		VATTaxation = SmallBusinessServer.VATTaxation(Company,, Date);
	EndIf;
	
	StructuralUnit = FillingData.StructuralUnit;
	Cell = FillingData.Cell;
	DocumentCurrency = FillingData.DocumentCurrency;
	AmountIncludesVAT = FillingData.AmountIncludesVAT;
	IncludeVATInPrice = FillingData.IncludeVATInPrice;
	
	ExchangeRate = FillingData.ExchangeRate;
	Multiplicity = FillingData.Multiplicity;
	
	// Filling document tabular section.
	Inventory.Clear();
	For Each TabularSectionRow IN FillingData.Inventory Do
		
		NewRow = Inventory.Add();
		If OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer Then
			FillPropertyValues(NewRow, TabularSectionRow, ,"Price, Amount, VATAmount, Total");
		Else
			FillPropertyValues(NewRow, TabularSectionRow);
		EndIf;
		
		NewRow.ProductsAndServicesTypeInventory = (NewRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem);
		
		If Not FillingData.PurchaseOrderPosition = Enums.AttributePositionOnForm.InHeader
			AND SmallBusinessReUse.AttributeInHeader("CustomerOrderPositionInShipmentDocuments") Then
			NewRow.Order = Undefined;
		EndIf;
		
		If VATTaxation = FillingData.VATTaxation Then
			Continue;
		EndIf;
		
		If VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
			
			For Each TabularSectionRow IN Inventory Do
				
				If ValueIsFilled(TabularSectionRow.ProductsAndServices.VATRate) Then
					TabularSectionRow.VATRate = TabularSectionRow.ProductsAndServices.VATRate;
				Else
					TabularSectionRow.VATRate = Company.DefaultVATRate;
				EndIf;	
				
				VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
				TabularSectionRow.VATAmount = ?(AmountIncludesVAT, 
										  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
										  		TabularSectionRow.Amount * VATRate / 100);
				TabularSectionRow.Total = TabularSectionRow.Amount + ?(AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
				
			EndDo;	
			
		Else
						
			If VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then	
			    DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
			Else
				DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
			EndIf;	
			
			For Each TabularSectionRow IN Inventory Do
			
				TabularSectionRow.VATRate = DefaultVATRate;
				TabularSectionRow.VATAmount = 0;
				
				TabularSectionRow.Total = TabularSectionRow.Amount;
				
			EndDo;	
			
		EndIf;
		
	EndDo;
	
EndProcedure // FillBySupplierInvoice()

// Procedure of filling the document on the basis of the supplier invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier
// invoice FillingData - Structure - Document filling data
//	
Procedure FillByCustomerOrder(FillingData)
	
	// Document basis and document setting.
	OrdersArray = New Array;
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfCustomerOrders") Then
		OrdersArray = FillingData.ArrayOfCustomerOrders;
		CustomerOrderPosition = Enums.AttributePositionOnForm.InTabularSection;
	Else
		OrdersArray.Add(FillingData.Ref);
		CustomerOrderPosition = SmallBusinessReUse.GetValueOfSetting("CustomerOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(CustomerOrderPosition) Then
			CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader;
		EndIf;
		If CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader Then
			Order = FillingData;
		EndIf;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT
	|	CustomerOrder.Ref AS BasisRef,
	|	CustomerOrder.Posted AS BasisPosted,
	|	CustomerOrder.Closed AS Closed,
	|	CustomerOrder.OrderState AS OrderState,
	|	CustomerOrder.Company AS Company,
	|	CASE
	|		WHEN CustomerOrder.BankAccount = VALUE(Catalog.BankAccounts.EmptyRef)
	|			THEN CustomerOrder.Company.BankAccountByDefault
	|		ELSE CustomerOrder.BankAccount
	|	END AS BankAccount,
	|	CASE
	|		WHEN InventoryReservation.Value
	|			THEN CustomerOrder.StructuralUnitReserve
	|	END AS StructuralUnit,
	|	CustomerOrder.Counterparty AS Counterparty,
	|	CustomerOrder.Contract AS Contract,
	|	CustomerOrder.PriceKind AS PriceKind,
	|	CustomerOrder.DiscountMarkupKind AS DiscountMarkupKind,
	|	CustomerOrder.DiscountCard AS DiscountCard,
	|	CustomerOrder.DiscountPercentByDiscountCard AS DiscountPercentByDiscountCard,
	|	CustomerOrder.DocumentCurrency AS DocumentCurrency,
	|	CustomerOrder.VATTaxation AS VATTaxation,
	|	CustomerOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	CustomerOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	CASE
	|		WHEN CustomerOrder.DocumentCurrency = NationalCurrency.Value
	|			THEN CustomerOrder.ExchangeRate
	|		ELSE CurrencyRatesSliceLast.ExchangeRate
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN CustomerOrder.DocumentCurrency = NationalCurrency.Value
	|			THEN CustomerOrder.Multiplicity
	|		ELSE CurrencyRatesSliceLast.Multiplicity
	|	END AS Multiplicity
	|FROM
	|	Document.CustomerOrder AS CustomerOrder
	|		{LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&DocumentDate, ) AS CurrencyRatesSliceLast
	|		ON CustomerOrder.Contract.SettlementsCurrency = CurrencyRatesSliceLast.Currency},
	|	Constant.NationalCurrency AS NationalCurrency,
	|	Constant.FunctionalOptionInventoryReservation AS InventoryReservation
	|WHERE
	|	CustomerOrder.Ref IN(&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted", Selection.OrderState, Selection.Closed, Selection.BasisPosted);
		Documents.CustomerOrder.CheckAbilityOfEnteringByCustomerOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	FillPropertyValues(ThisObject, Selection);
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = SmallBusinessReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
		EndIf;
	EndIf;
	
	// Tabular section filling.
	Query = New Query;
	Query.Text =
	"SELECT
	|	OrdersBalance.CustomerOrder AS CustomerOrder,
	|	OrdersBalance.ProductsAndServices AS ProductsAndServices,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.CustomerOrder AS CustomerOrder,
	|		OrdersBalance.ProductsAndServices AS ProductsAndServices,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.CustomerOrders.Balance(
	|				,
	|				CustomerOrder IN (&OrdersArray)
	|					AND (ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|						OR ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Service))) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsCustomersOrders.CustomerOrder,
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
	|		DocumentRegisterRecordsCustomersOrders.Recorder = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.CustomerOrder,
	|	OrdersBalance.ProductsAndServices,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CustomerOrderInventory.LineNumber AS LineNumber,
	|	CustomerOrderInventory.ProductsAndServices AS ProductsAndServices,
	|	CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|	CASE
	|		WHEN CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsAndServicesTypeInventory,
	|	CustomerOrderInventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(CustomerOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE CustomerOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	CustomerOrderInventory.Quantity AS Quantity,
	|	CustomerOrderInventory.Batch AS Batch,
	|	CustomerOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CustomerOrderInventory.Price AS Price,
	|	CustomerOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	CustomerOrderInventory.Amount AS Amount,
	|	CustomerOrderInventory.VATRate AS VATRate,
	|	CustomerOrderInventory.VATAmount AS VATAmount,
	|	CustomerOrderInventory.Total AS Total,
	|	CustomerOrderInventory.Ref AS Order,
	|	CustomerOrderInventory.Content AS Content,
	|	CustomerOrderInventory.AutomaticDiscountsPercent,
	|	CustomerOrderInventory.AutomaticDiscountAmount,
	|	CustomerOrderInventory.ConnectionKey,
	|	CustomerOrderInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent1,
	|	CustomerOrderInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount1
	|FROM
	|	Document.CustomerOrder.Inventory AS CustomerOrderInventory
	|WHERE
	|	CustomerOrderInventory.Ref IN(&OrdersArray)
	|	AND (CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|			OR CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Service))
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DiscountsMarkups.Ref AS Order,
	|	DiscountsMarkups.ConnectionKey AS ConnectionKey,
	|	DiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	DiscountsMarkups.Amount AS Amount
	|FROM
	|	Document.CustomerOrder.DiscountsMarkups AS DiscountsMarkups
	|WHERE
	|	DiscountsMarkups.Ref IN(&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("CustomerOrder,ProductsAndServices,Characteristic");
	
	// AutomaticDiscounts.
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscountsMarkups");
	If UseAutomaticDiscounts Then
		OrderDiscountsMarkups = ResultsArray[2].Unload();
		DiscountsMarkups.Clear();
	EndIf;
	// End AutomaticDiscounts.
	
	Inventory.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[1].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("CustomerOrder", Selection.Order);
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
				
				QuantityToWriteOff = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
				
				DataStructure = SmallBusinessServer.GetTabularSectionRowSum(
					New Structure("Quantity, Price, Amount, DiscountMarkupPercent, VATRate, VATAmount, AmountIncludesVAT, Total",
						QuantityToWriteOff, Selection.Price, 0, Selection.DiscountMarkupPercent, Selection.VATRate, 0, AmountIncludesVAT, 0));
				
				FillPropertyValues(NewRow, DataStructure);
				
			EndIf;
			
			// AutomaticDiscounts
			If UseAutomaticDiscounts Then
				QuantityInDocument = Selection.Quantity * Selection.Factor;
				RecalculateAmounts = QuantityInDocument <> QuantityToWriteOff;
				DiscountRecalculationCoefficient = ?(RecalculateAmounts, QuantityToWriteOff / QuantityInDocument, 1);
				If DiscountRecalculationCoefficient <> 1 Then
					NewRow.AutomaticDiscountAmount = ROUND(Selection.AutomaticDiscountAmount * DiscountRecalculationCoefficient,2);
				EndIf;
			
				// Creating discounts tabular section
				SumDistribution = NewRow.AutomaticDiscountAmount;
				
				HasDiscountString = False;
				If Selection.ConnectionKey <> 0 Then
					For Each OrderDiscountString IN OrderDiscountsMarkups.FindRows(New Structure("Order,ConnectionKey", Selection.Order, Selection.ConnectionKey)) Do
						
						DiscountString = DiscountsMarkups.Add();
						FillPropertyValues(DiscountString, OrderDiscountString);
						DiscountString.Amount = DiscountRecalculationCoefficient * DiscountString.Amount;
						SumDistribution = SumDistribution - DiscountString.Amount;
						HasDiscountString = True;
						
					EndDo;
				EndIf;
				
				If HasDiscountString AND SumDistribution <> 0 Then
					DiscountString.Amount = DiscountString.Amount + SumDistribution;
				EndIf;
			EndIf;
			// End AutomaticDiscounts
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Filling out reserves.
	If Inventory.Count() > 0
		AND Constants.FunctionalOptionInventoryReservation.Get()
		AND ValueIsFilled(StructuralUnit) Then
		FillColumnReserveByReserves();
	EndIf;
	
	// AutomaticDiscounts.
	If UseAutomaticDiscounts Then
		DiscountsMarkupsCalculationResult = DiscountsMarkups.Unload();
		DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(ThisObject, "Inventory", DiscountsMarkupsCalculationResult);
	EndIf;
	
EndProcedure // FillByCustomerOrder()

// Procedure of filling the document on the basis of the supplier invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier
// invoice FillingData - Structure - Document filling data
//	
Procedure FillByPurchaseOrder(FillingData)
	
	If SmallBusinessReUse.AttributeInHeader("CustomerOrderPositionInShipmentDocuments") Then
		Order = FillingData.Ref;
	Else
		Order = Undefined;
	EndIf;
	
	// Header filling.
	AttributeValues = CommonUse.GetAttributeValues(FillingData, 
			New Structure("Company, OperationKind, StructuralUnitReserve, Counterparty, Contract, DocumentCurrency, VATTaxation, AmountIncludesVAT, IncludeVATInPrice, ExchangeRate, Multiplicity, OrderState, Closed, Posted"));
	
	Documents.PurchaseOrder.CheckEnteringAbilityOnTheBasisOfVendorOrder(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues, "Company, Counterparty, Contract, DocumentCurrency, VATTaxation, AmountIncludesVAT, IncludeVATInPrice, ExchangeRate, Multiplicity");
	ThisObject.BasisDocument = FillingData;
	
	If Not DocumentCurrency = Constants.NationalCurrency.Get() Then
		StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(?(ValueIsFilled(Date), Date, CurrentDate()), New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
	EndIf;
	
	// Tabular section filling.
	Inventory.Clear();
	If FillingData.OperationKind = Enums.OperationKindsPurchaseOrder.OrderForProcessing Then
		OperationKind = Enums.OperationKindsCustomerInvoice.TransferToProcessing;
		StructuralUnit = AttributeValues.StructuralUnitReserve;
		VATTaxation = SmallBusinessServer.VATTaxation(Company,, ?(ValueIsFilled(Date), Date, CurrentDate()));
		FillByPurchaseOrderForProcessing(FillingData);
	Else
		OperationKind = Enums.OperationKindsCustomerInvoice.ReturnToVendor;
		FillByPurchaseOrderForPurchase(FillingData);
	EndIf;
	
EndProcedure // FillByPurchaseOrder()

// Procedure of document filling based on purchase order.
//
// Parameters:
// FillingData - Structure - Document filling data
//	
Procedure FillByPurchaseOrderForProcessing(FillingData)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(OrdersBalance.LineNumber) AS LineNumber,
	|	CASE
	|		WHEN OrdersBalance.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsAndServicesTypeInventory,
	|	OrdersBalance.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN OrdersBalance.ProductsAndServices.VATRate = VALUE(Catalog.VATRates.EmptyRef)
	|			THEN OrdersBalance.Order.Company.DefaultVATRate
	|		ELSE OrdersBalance.ProductsAndServices.VATRate
	|	END AS VATRate,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
	|	OrdersBalance.Order AS Order,
	|	SUM(OrdersBalance.Quantity) AS Quantity
	|FROM
	|	(SELECT
	|		PurchaseOrderMaterials.LineNumber AS LineNumber,
	|		PurchaseOrderMaterials.ProductsAndServices AS ProductsAndServices,
	|		PurchaseOrderMaterials.Characteristic AS Characteristic,
	|		PurchaseOrderMaterials.MeasurementUnit AS MeasurementUnit,
	|		PurchaseOrderMaterials.Ref AS Order,
	|		PurchaseOrderMaterials.Quantity AS Quantity
	|	FROM
	|		Document.PurchaseOrder.Materials AS PurchaseOrderMaterials
	|	WHERE
	|		PurchaseOrderMaterials.Ref = &BasisDocument
	|		AND PurchaseOrderMaterials.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SupplierInvoiceInventory.LineNumber,
	|		SupplierInvoiceInventory.ProductsAndServices,
	|		SupplierInvoiceInventory.Characteristic,
	|		SupplierInvoiceInventory.MeasurementUnit,
	|		SupplierInvoiceInventory.Order,
	|		SupplierInvoiceInventory.Quantity
	|	FROM
	|		Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|	WHERE
	|		SupplierInvoiceInventory.Ref.Posted
	|		AND SupplierInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReturnFromSubcontractor)
	|		AND SupplierInvoiceInventory.Order = &BasisDocument
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CustomerInvoiceInventory.LineNumber,
	|		CustomerInvoiceInventory.ProductsAndServices,
	|		CustomerInvoiceInventory.Characteristic,
	|		CustomerInvoiceInventory.MeasurementUnit,
	|		CustomerInvoiceInventory.Order,
	|		-CustomerInvoiceInventory.Quantity
	|	FROM
	|		Document.CustomerInvoice.Inventory AS CustomerInvoiceInventory
	|	WHERE
	|		CustomerInvoiceInventory.Ref.Posted
	|		AND CustomerInvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.TransferToProcessing)
	|		AND CustomerInvoiceInventory.Order = &BasisDocument
	|		AND Not CustomerInvoiceInventory.Ref = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	CASE
	|		WHEN OrdersBalance.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	OrdersBalance.ProductsAndServices,
	|	CASE
	|		WHEN OrdersBalance.ProductsAndServices.VATRate = VALUE(Catalog.VATRates.EmptyRef)
	|			THEN OrdersBalance.Order.Company.DefaultVATRate
	|		ELSE OrdersBalance.ProductsAndServices.VATRate
	|	END,
	|	OrdersBalance.Characteristic,
	|	OrdersBalance.MeasurementUnit,
	|	OrdersBalance.Order
	|
	|HAVING
	|	SUM(OrdersBalance.Quantity) > 0";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
			If Not VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
				
				If VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
					NewRow.VATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
				Else
					NewRow.VATRate = SmallBusinessReUse.GetVATRateZero();
				EndIf;
				
			EndIf;
			
		EndDo;
	EndIf;
		
	// Filling out reserves.
	If Inventory.Count() > 0
		AND Constants.FunctionalOptionInventoryReservation.Get()
		AND ValueIsFilled(StructuralUnit) Then
		FillColumnReserveByReserves();
	EndIf;
	
EndProcedure // FillByPurchaseOrderForProcessing()

// Procedure of document filling based on purchase order.
//
// Parameters:
// FillingData - Structure - Document filling data
//	
Procedure FillByPurchaseOrderForPurchase(FillingData)
	
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
	|		AccumulationRegister.PurchaseOrders.Balance(
	|				,
	|				PurchaseOrder = &BasisDocument
	|					AND ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
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
	|		DocumentRegisterRecordsPurchaseOrders.Recorder = &Ref
	|		AND DocumentRegisterRecordsPurchaseOrders.PurchaseOrder = &BasisDocument) AS OrdersBalance
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
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN PurchaseOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsAndServicesTypeInventory,
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
	|	PurchaseOrderInventory.Ref AS Order
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|WHERE
	|	PurchaseOrderInventory.Ref = &BasisDocument
	|	AND PurchaseOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("ProductsAndServices,Characteristic");
	
	Selection = ResultsArray[1].Select();
	Selection.Reset();
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
	
EndProcedure // FillByPurchaseOrderForPurchase()

// Procedure of filling the document on the basis of the supplier invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier
// invoice FillingData - Structure - Document filling data
//	
Procedure FillByInvoiceForPayment(FillingData)
	
	// Filling out a document header.
	ThisObject.BasisDocument = FillingData.Ref;
	
	OperationKind			= Enums.OperationKindsCustomerInvoice.SaleToCustomer;
	Company			= FillingData.Company;
	
	BankAccount		= FillingData.BankAccount;
	If Not ValueIsFilled(BankAccount) 
		AND ValueIsFilled(Company) Then
		
		BankAccount = Company.BankAccountByDefault;
		
	EndIf;
	
	Counterparty			= FillingData.Counterparty;
	Contract				= FillingData.Contract;
	PriceKind				= FillingData.PriceKind;
	DiscountMarkupKind	= FillingData.DiscountMarkupKind;
	DocumentCurrency		= FillingData.DocumentCurrency;
	AmountIncludesVAT	= FillingData.AmountIncludesVAT;
	VATTaxation	= FillingData.VATTaxation;
	// DiscountCards
	DiscountCard = FillingData.DiscountCard;
	DiscountPercentByDiscountCard = FillingData.DiscountPercentByDiscountCard;
	// End DiscountCards
		
	If DocumentCurrency = Constants.NationalCurrency.Get() Then
		ExchangeRate		= FillingData.ExchangeRate;
		Multiplicity	= FillingData.Multiplicity;
	Else
		StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate		= StructureByCurrency.ExchangeRate;
		Multiplicity	= StructureByCurrency.Multiplicity;
	EndIf;
	
	OrderInTabularSection = Not SmallBusinessReUse.AttributeInHeader("CustomerOrderPositionInShipmentDocuments");	
	If TypeOf(FillingData.BasisDocument) = Type("DocumentRef.CustomerOrder") Then
		CustomerOrderForFill = FillingData.BasisDocument;
	Else
		CustomerOrderForFill = Documents.CustomerOrder.EmptyRef();
	EndIf;
	
	If Not OrderInTabularSection Then
		Order = CustomerOrderForFill;
	EndIf;
	 
	// Filling document tabular section.
	Inventory.Clear();
	For Each TabularSectionRow IN FillingData.Inventory Do
		
		If TabularSectionRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem
			OR TabularSectionRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service Then
		
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			NewRow.ProductsAndServicesTypeInventory = (NewRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem);
			
			If OrderInTabularSection Then
				NewRow.Order = CustomerOrderForFill;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// AutomaticDiscounts
	If GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
		DiscountsAreCalculated = True;
		DiscountsMarkups.Clear();
		For Each TabularSectionRow IN FillingData.DiscountsMarkups Do
			If Inventory.Find(TabularSectionRow.ConnectionKey, "ConnectionKey") <> Undefined Then
				NewRowDiscountsMarkups = DiscountsMarkups.Add();
				FillPropertyValues(NewRowDiscountsMarkups, TabularSectionRow);
			EndIf;
		EndDo;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure // FillByInvoiceForPayment()

// Procedure fills out the Quantity by reserves under order column.
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
	|				WHEN TableInventory.Order REFS Document.CustomerOrder
	|						AND TableInventory.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|					THEN TableInventory.Order
	|				ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|			END
	|	END AS CustomerOrder
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.ProductsAndServicesTypeInventory";
	
	OrderInHeader = CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader;
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.SetParameter("OrderInHeader", OrderInHeader);
	Query.SetParameter("Order", ?(ValueIsFilled(Order), Order, Documents.CustomerOrder.EmptyRef()));
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
			StructureForSearch.Insert("Order", Selection.CustomerOrder);
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

// Posting cancellation procedure of the subordinate customer invoice note
//
Procedure SubordinatedInvoiceControl()
	
	InvoiceStructure = SmallBusinessServer.GetSubordinateInvoice(Ref);
	If Not InvoiceStructure = Undefined Then
		
		CustomerInvoiceNote	 = InvoiceStructure.Ref;
		If CustomerInvoiceNote.Posted Then
			
			MessageText = NStr("en='As there are no register records of the %CurrentDocumentPresentation% document, undo the posting of %InvoicePresentation%.';ru='В связи с отсутствием движений у документа %ПредставлениеТекущегоДокумента% распроводится счет фактура %ПредставлениеСчетФактуры%.'");
			MessageText = StrReplace(MessageText, "%CurrentDocumentPresentation%", """Sales invoice No " + Number + " dated " + Format(Date, "DF=dd.MM.yyyy") + """");
			MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Customer invoice note (issued) No " + InvoiceStructure.Number + " dated " + InvoiceStructure.Date + """");
			
			CommonUseClientServer.MessageToUser(MessageText);
			
			InvoiceObject = CustomerInvoiceNote.GetObject();
			InvoiceObject.Write(DocumentWriteMode.UndoPosting);
			
		EndIf;
		
	EndIf;
	
EndProcedure //SubordinateInvoiceControl()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If (TypeOf(FillingData) = Type("DocumentRef.CustomerOrder")
		AND FillingData.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder)
		OR (TypeOf(FillingData) = Type("Structure") AND FillingData.Property("Basis")
		AND FillingData.Basis.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder) Then
		
		Raise NStr("en='Expense Invoice can not be entered on the basis of Job order!';ru='Нельзя ввести Расходную накладную на основании заказ-наряда!'");
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then
		FillByPurchaseInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") 
		OR (TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfCustomerOrders")) Then
		FillByCustomerOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") Then
		FillByPurchaseOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.InvoiceForPayment") Then
		FillByInvoiceForPayment(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("BasisDocumentSale") Then
		FillByPurchaseInvoice(FillingData.BasisDocumentSale, "Sale");
	ElsIf TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("BasisDocumentReturn") Then
		FillByPurchaseInvoice(FillingData.BasisDocumentReturn, "Return");
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		FillPropertyValues(ThisObject, FillingData);
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader Then
		For Each TabularSectionRow IN Inventory Do
			TabularSectionRow.Order = Order;
		EndDo;
		If Counterparty.DoOperationsByOrders Then
			For Each TabularSectionRow IN Prepayment Do
				TabularSectionRow.Order = Order;
			EndDo;
		EndIf;
	EndIf;
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total");
	
EndProcedure // BeforeWrite()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer Then
		CheckedAttributes.Add("Division");
	EndIf;
	
	If OperationKind = Enums.OperationKindsCustomerInvoice.ReturnToPrincipal
		OR OperationKind = Enums.OperationKindsCustomerInvoice.ReturnFromProcessing
		OR OperationKind = Enums.OperationKindsCustomerInvoice.ReturnFromSafeCustody Then
		CheckedAttributes.Add("Inventory.Batch");
	EndIf;
	
	OrderInHeader = CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader;
	
	TableInventory = Inventory.Unload(, "Order, Total");
	TableInventory.GroupBy("Order", "Total");
	
	TablePrepayment = Prepayment.Unload(, "Order, PaymentAmount");
	TablePrepayment.GroupBy("Order", "PaymentAmount");
	
	If OrderInHeader Then
		For Each StringInventory IN TableInventory Do
			StringInventory.Order = Order;
		EndDo;
		If Counterparty.DoOperationsByOrders Then
			For Each RowPrepayment IN TablePrepayment Do
				RowPrepayment.Order = Order;
			EndDo;
		EndIf;
	EndIf;
	
	QuantityInventory = Inventory.Count();
	
	For Each String IN TablePrepayment Do
		
		FoundStringInventory = Undefined;
		
		If Counterparty.DoOperationsByOrders
		   AND String.Order <> Undefined
		   AND String.Order <> Documents.CustomerOrder.EmptyRef()
		   AND String.Order <> Documents.PurchaseOrder.EmptyRef() Then
			FoundStringInventory = TableInventory.Find(String.Order, "Order");
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		ElsIf Counterparty.DoOperationsByOrders Then
			FoundStringInventory = TableInventory.Find(Undefined, "Order");
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.CustomerOrder.EmptyRef(), "Order"), FoundStringInventory);
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.PurchaseOrder.EmptyRef(), "Order"), FoundStringInventory);				
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		Else
			Total = Inventory.Total("Total");
		EndIf;
		
		If FoundStringInventory = Undefined
		   AND QuantityInventory > 0
		   AND Counterparty.DoOperationsByOrders Then
			MessageText = NStr("en='Advance by order different from the one specified in tabular sections ""inventory"" or ""Expenses"" can not be accepted.';ru='Нельзя зачесть аванс по заказу отличному от указанных в табличных частях ""Запасы"" или ""Расходы""!'");
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
	
	If Constants.FunctionalOptionInventoryReservation.Get()
		AND (OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer
		OR OperationKind = Enums.OperationKindsCustomerInvoice.TransferForCommission) Then
		
		For Each StringInventory IN Inventory Do
			
			If StringInventory.Reserve > StringInventory.Quantity Then
				
				MessageText = NStr("en='In row #%Number% of tabular section ""Inventory and services"" the quantity of shipped items from the reserve exceeds the total quantity of inventory.';ru='В строке №%Номер% табл. части ""Запасы и услуги"" количество отгружаемых позиций из резерва превышает общее количество запасов.'");
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
	
	// 100% discount.
	ThereAreManualDiscounts = GetFunctionalOption("UseDiscountsMarkups");
	ThereAreAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscountsMarkups"); // AutomaticDiscounts
	If ThereAreManualDiscounts OR ThereAreAutomaticDiscounts Then
		For Each StringInventory IN Inventory Do
			// AutomaticDiscounts
			CurAmount = StringInventory.Price * StringInventory.Quantity;
			ManualDiscountCurAmount = ?(ThereAreManualDiscounts, ROUND(CurAmount * StringInventory.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount = ?(ThereAreAutomaticDiscounts, StringInventory.AutomaticDiscountAmount, 0);
			CurAmountDiscounts = ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			If StringInventory.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(StringInventory.Amount) Then
				MessageText = NStr("en='Column ""Amount"" is not populated in string %Number% of list ""Inventory"".';ru='Не заполнена колонка ""Сумма"" в строке %Номер% списка ""Запасы"".'");
				MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Amount",
					Cancel
				);
			EndIf;
		EndDo;
	EndIf;
	
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
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesInvoiceDocumentPostingInitialization");
	
	Documents.CustomerInvoice.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesInvoiceDocumentPostingMovementsCreation");
	
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectPurchasing(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryForExpenseFromWarehouses(AdditionalProperties, RegisterRecords, Cancel);
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
	
	// DiscountCards
	SmallBusinessServer.ReflectSalesByDiscountCard(AdditionalProperties, RegisterRecords, Cancel);
	
	// AutomaticDiscounts
	SmallBusinessServer.FlipAutomaticDiscountsApplied(AdditionalProperties, RegisterRecords, Cancel);

	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);

	// Record of the records sets.
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesInvoiceDocumentPostingMovementsRecord");
	
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesInvoiceDocumentPostingControl");
	
	Documents.CustomerInvoice.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.CustomerInvoice.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	// Subordinate customer invoice note
	If Not Cancel Then
		
		SubordinatedInvoiceControl();
		
	EndIf;
	
EndProcedure // UndoPosting()

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	SmallBusinessManagementElectronicDocumentsServer.ClearIncomingDocumentDateNumber(ThisObject);
	Prepayment.Clear();
	
EndProcedure // OnCopy()

#EndIf