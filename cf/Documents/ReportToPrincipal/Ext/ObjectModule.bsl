#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure fills advances.
//
Procedure FillPrepayment()Export
	
	Counterparty = SmallBusinessServer.GetCompany(Company);
	
	// Preparation of the order table.
	OrdersTable = Inventory.Unload(, "PurchaseOrder, Total");
	OrdersTable.Columns.Add("TotalCalc");
	For Each CurRow IN OrdersTable Do
		If Not Counterparty.DoOperationsByOrders Then
			CurRow.PurchaseOrder = Documents.PurchaseOrder.EmptyRef();
		EndIf;
		CurRow.TotalCalc = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
			CurRow.Total,
			?(Contract.SettlementsCurrency = DocumentCurrency, ExchangeRate, 1),
			ExchangeRate,
			?(Contract.SettlementsCurrency = DocumentCurrency, Multiplicity, 1),
			Multiplicity
		);
	EndDo;
	OrdersTable.GroupBy("PurchaseOrder", "Total, TotalCalc");
	OrdersTable.Sort("PurchaseOrder Asc");

	
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
	
	Query.SetParameter("Order", OrdersTable.UnloadColumn("PurchaseOrder"));
	
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
		
		FoundString = OrdersTable.Find(SelectionOfQueryResult.Order, "PurchaseOrder");
		
		If FoundString.TotalCalc = 0 Then
			Continue;
		EndIf;
		
		If SelectionOfQueryResult.SettlementsAmount <= FoundString.TotalCalc  Then // balance amount is less or equal than it is necessary to distribute
			
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

// Procedure of the document filling according to the header attributes.
//
Procedure FillByHeaderAttributes()
	
	Query = New Query();
	Query.SetParameter("Company",		SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("Counterparty",			Counterparty);
	Query.SetParameter("Contract",			Contract);
	Query.SetParameter("SettlementsCurrency",		Contract.SettlementsCurrency);
	Query.SetParameter("DocumentCurrency",	DocumentCurrency);
	Query.SetParameter("EndOfPeriod",		CurrentDate());
	Query.SetParameter("CounterpartyPriceKind",	CounterpartyPriceKind);
	Query.SetParameter("PriceKindCurrency",		CounterpartyPriceKind.PriceCurrency);
	Query.SetParameter("Ref",				Ref);
	Query.SetParameter("AccountingCurrency",		Constants.AccountingCurrency.Get());
	
	// Define date of the last report
	Query.Text = 
	"SELECT TOP 1
	|	ReportToPrincipal.Date AS Date
	|FROM
	|	Document.ReportToPrincipal AS ReportToPrincipal
	|WHERE
	|	ReportToPrincipal.Posted
	|	AND ReportToPrincipal.Company = &Company
	|	AND ReportToPrincipal.Counterparty = &Counterparty
	|	AND ReportToPrincipal.Contract = &Contract
	|	AND ReportToPrincipal.Date < &EndOfPeriod
	|	AND ReportToPrincipal.Ref <> &Ref
	|
	|ORDER BY
	|	Date DESC";
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Query.SetParameter("BeginOfPeriod",Undefined);
	Else
		Selection = Result.Select();
		Selection.Next();
		Query.SetParameter("BeginOfPeriod",Selection.Date);
	EndIf;
	
	// Define the amount of sold goods and purchase prices
	Query.Text = 
	"SELECT ALLOWED
	|	SalesTurnovers.Company.DefaultVATRate AS CompanyVATRate,
	|	SalesTurnovers.ProductsAndServices,
	|	SalesTurnovers.ProductsAndServices.VATRate AS ProductsAndServicesVATRate,
	|	SalesTurnovers.Characteristic,
	|	SalesTurnovers.Batch,
	|	SalesTurnovers.CustomerOrder,
	|	CASE
	|		WHEN VALUETYPE(SalesTurnovers.Document) = Type(Document.CustomerInvoice)
	|			THEN SalesTurnovers.Document.Counterparty
	|	END AS Customer,
	|	CASE
	|		WHEN VALUETYPE(SalesTurnovers.Document) = Type(Document.CustomerInvoice)
	|			THEN SalesTurnovers.Document.Date
	|	END AS DateOfSale,
	|	SalesTurnovers.QuantityTurnover AS Quantity,
	|	SalesTurnovers.ProductsAndServices.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN SalesTurnovers.QuantityTurnover > 0
	|			THEN CASE
	|					WHEN &DocumentCurrency = &AccountingCurrency
	|						THEN SalesTurnovers.AmountTurnover / SalesTurnovers.QuantityTurnover
	|					ELSE ISNULL(SalesTurnovers.AmountTurnover * AccountingCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * AccountingCurrencyRate.Multiplicity), 0) / SalesTurnovers.QuantityTurnover
	|				END
	|		ELSE 0
	|	END AS Price,
	|	CASE
	|		WHEN &DocumentCurrency = &AccountingCurrency
	|			THEN SalesTurnovers.AmountTurnover
	|		ELSE SalesTurnovers.AmountTurnover * AccountingCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * AccountingCurrencyRate.Multiplicity)
	|	END AS Amount,
	|	ISNULL(CASE
	|			WHEN &DocumentCurrency = &PriceKindCurrency
	|				THEN FixedReceiptPrices.Price
	|			ELSE FixedReceiptPrices.Price * PriceKindCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * PriceKindCurrencyRate.Multiplicity)
	|		END, CASE
	|			WHEN InventoryReceivedBalances.QuantityBalance > 0
	|				THEN CASE
	|						WHEN &DocumentCurrency = &SettlementsCurrency
	|							THEN InventoryReceivedBalances.SettlementsAmountBalance / InventoryReceivedBalances.QuantityBalance
	|						ELSE ISNULL(InventoryReceivedBalances.SettlementsAmountBalance * SettlementsCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * SettlementsCurrencyRate.Multiplicity), 0) / InventoryReceivedBalances.QuantityBalance
	|					END
	|			ELSE 0
	|		END) AS ReceiptPrice,
	|	InventoryReceivedBalances.Order AS PurchaseOrder
	|FROM
	|	AccumulationRegister.Sales.Turnovers(
	|			&BeginOfPeriod,
	|			&EndOfPeriod,
	|			,
	|			Company = &Company
	|				AND Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				AND Batch.BatchOwner = &Counterparty) AS SalesTurnovers
	|		LEFT JOIN AccumulationRegister.InventoryReceived.Balance(
	|				&EndOfPeriod,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND ReceptionTransmissionType = VALUE(Enum.ProductsReceiptTransferTypes.ReceiptFromPrincipal)) AS InventoryReceivedBalances
	|		ON (InventoryReceivedBalances.ProductsAndServices = SalesTurnovers.ProductsAndServices)
	|			AND (InventoryReceivedBalances.Characteristic = SalesTurnovers.Characteristic)
	|			AND (InventoryReceivedBalances.Batch = SalesTurnovers.Batch)
	|		LEFT JOIN InformationRegister.CounterpartyProductsAndServicesPrices.SliceLast(
	|				&EndOfPeriod,
	|				CounterpartyPriceKind = &CounterpartyPriceKind
	|					AND Actuality) AS FixedReceiptPrices
	|		ON (FixedReceiptPrices.ProductsAndServices = SalesTurnovers.ProductsAndServices)
	|			AND (FixedReceiptPrices.Characteristic = SalesTurnovers.Characteristic)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&EndOfPeriod, Currency = &SettlementsCurrency) AS SettlementsCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&EndOfPeriod, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&EndOfPeriod, Currency = &AccountingCurrency) AS AccountingCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&EndOfPeriod, Currency = &PriceKindCurrency) AS PriceKindCurrencyRate
	|		ON (TRUE)
	|WHERE
	|	SalesTurnovers.QuantityTurnover > 0
	|	AND InventoryReceivedBalances.QuantityBalance > 0";
	
	RemunerationVATRateNumber = SmallBusinessReUse.GetVATRateValue(VATCommissionFeePercent);
	
	// Refill the Inventory tabular section
	Inventory.Clear();
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, Selection);
		
		// VAT rate, VATAmount and Total
		If VATTaxation <> Enums.VATTaxationTypes.TaxableByVAT Then
			If VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
				NewRow.VATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
			Else
				NewRow.VATRate = SmallBusinessReUse.GetVATRateZero();
			EndIf;	
		ElsIf ValueIsFilled(Selection.ProductsAndServicesVATRate) Then
			NewRow.VATRate = Selection.ProductsAndServicesVATRate;
		Else
			NewRow.VATRate = Selection.CompanyVATRate;
		EndIf;
		VATRate = SmallBusinessReUse.GetVATRateValue(NewRow.VATRate);
		
		NewRow.VATAmount = ?(AmountIncludesVAT, 
								 NewRow.Amount - (NewRow.Amount) / ((VATRate + 100) / 100),
								 NewRow.Amount * VATRate / 100);
		
		NewRow.Total = NewRow.Amount + ?(AmountIncludesVAT, 0, NewRow.VATAmount);
		
		// Receipt amount and VAT.
		NewRow.AmountReceipt = NewRow.Quantity * NewRow.ReceiptPrice;
		
		NewRow.ReceiptVATAmount = ?(AmountIncludesVAT, 
											NewRow.AmountReceipt - (NewRow.AmountReceipt) / ((VATRate + 100) / 100),
											NewRow.AmountReceipt * VATRate / 100);
		
		// Fee
		If BrokerageCalculationMethod <> Enums.CommissionFeeCalculationMethods.IsNotCalculating Then

			If BrokerageCalculationMethod = Enums.CommissionFeeCalculationMethods.PercentFromSaleAmount Then
	
				NewRow.BrokerageAmount = CommissionFeePercent * NewRow.Amount / 100;
	
			ElsIf BrokerageCalculationMethod = Enums.CommissionFeeCalculationMethods.PercentFromDifferenceOfSaleAndAmountReceipts Then

				NewRow.BrokerageAmount = CommissionFeePercent * (NewRow.Amount - NewRow.AmountReceipt) / 100;

			Else
		
				NewRow.BrokerageAmount = 0;
		
			EndIf;
			
		EndIf;
	
		NewRow.BrokerageVATAmount = ?(AmountIncludesVAT, 
												NewRow.BrokerageAmount - (NewRow.BrokerageAmount) / ((RemunerationVATRateNumber + 100) / 100),
												NewRow.BrokerageAmount * RemunerationVATRateNumber / 100);
		
	EndDo;
	
EndProcedure // FillByHeaderAttributes()

// Procedure of filling the document on the basis of the supplier invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier
// invoice FillingData - Structure - Document filling
//	data
Procedure FillByPurchaseInvoice(FillingData)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SupplierInvoiceInventory.Ref.Company AS Company,
	|	SupplierInvoiceInventory.Ref.Counterparty AS Counterparty,
	|	SupplierInvoiceInventory.Ref.Contract AS Contract,
	|	SupplierInvoiceInventory.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SupplierInvoiceInventory.Ref.CounterpartyPriceKind AS CounterpartyPriceKind,
	|	SupplierInvoiceInventory.Ref.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoiceInventory.Ref.VATTaxation AS VATTaxation,
	|	SupplierInvoiceInventory.Ref.AmountIncludesVAT AS AmountIncludesVAT,
	|	SupplierInvoiceInventory.Ref.IncludeVATInPrice AS IncludeVATInPrice,
	|	SupplierInvoiceInventory.Ref.ExchangeRate AS ExchangeRate,
	|	SupplierInvoiceInventory.Ref.Multiplicity AS Multiplicity,
	|	SupplierInvoiceInventory.ProductsAndServices AS ProductsAndServices,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.Batch AS Batch,
	|	SupplierInvoiceInventory.Quantity AS Quantity,
	|	SupplierInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	SupplierInvoiceInventory.Price AS ReceiptPrice,
	|	SupplierInvoiceInventory.Amount AS AmountReceipt,
	|	SupplierInvoiceInventory.VATRate AS VATRate,
	|	SupplierInvoiceInventory.VATAmount AS ReceiptVATAmount,
	|	SupplierInvoiceInventory.Order AS PurchaseOrder
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|WHERE
	|	SupplierInvoiceInventory.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		QueryResultSelection = QueryResult.Select();
		
		QueryResultSelection.Next();
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		If DocumentCurrency <> Constants.NationalCurrency.Get() Then
			StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", QueryResultSelection.SettlementsCurrency));
			ExchangeRate = StructureByCurrency.ExchangeRate;
			Multiplicity = StructureByCurrency.Multiplicity;
		EndIf;
		
		QueryResultSelection.Reset();
		While QueryResultSelection.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, QueryResultSelection);
		EndDo;
		
		WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData);
		
	EndIf;
	
EndProcedure // FillBySupplierInvoice()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		
		Return;
		
	EndIf;
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
	
		Counterparty = FillingData;
		Contract = FillingData.ContractByDefault;
		
		DocumentCurrency = Contract.SettlementsCurrency;
		StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
		
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			If Company <> SettingValue Then
				Company = SettingValue;
			EndIf;
		Else
			Company = Catalogs.Companies.MainCompany;
		EndIf;
		
		VATTaxation = SmallBusinessServer.VATTaxation(Company,, Date);
		
		FillByHeaderAttributes();
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then
		
		If FillingData.OperationKind = Enums.OperationKindsSupplierInvoice.ReceptionForCommission Then
			FillByPurchaseInvoice(FillingData);
		Else
			Raise NStr("en = 'Report to principal can not be entered basing on operation " + FillingData.OperationKind + "!'");
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		
		FillPropertyValues(ThisObject, FillingData);
		
		FillByHeaderAttributes();
		
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	TableInventory = Inventory.Unload(, "PurchaseOrder, Total");
	TableInventory.GroupBy("PurchaseOrder", "Total");
	
	TablePrepayment = Prepayment.Unload(, "Order, PaymentAmount");
	TablePrepayment.GroupBy("Order", "PaymentAmount");
	
	QuantityInventory = Inventory.Count();
	
	For Each String IN TablePrepayment Do
		
		FoundStringWorksAndServices = Undefined;
		
		If Counterparty.DoOperationsByOrders
		   AND String.Order <> Undefined
		   AND String.Order <> Documents.PurchaseOrder.EmptyRef() Then
			FoundStringInventory = Inventory.Find(String.Order, "PurchaseOrder");
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		ElsIf Counterparty.DoOperationsByOrders Then
			FoundStringInventory = TableInventory.Find(Undefined, "PurchaseOrder");
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.PurchaseOrder.EmptyRef(), "PurchaseOrder"), FoundStringInventory);
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		Else
			Total = Inventory.Total("Total");
		EndIf;
		
		If FoundStringInventory = Undefined
		   AND QuantityInventory > 0
		   AND Counterparty.DoOperationsByOrders Then
			MessageText = NStr("en='Advance of order that is different form specified in the ""Inventory"" tabular section cannot be set off!';ru='Нельзя зачесть аванс по заказу отличному от указанных в табличной части ""Запасы""!'");
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
	
	// Serial numbers - control is not required
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total");
	
EndProcedure // BeforeWrite()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.ReportToPrincipal.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesUndistributed(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	SmallBusinessServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ReportToPrincipal.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ReportToPrincipal.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure // UndoPosting()

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	Prepayment.Clear();
	
EndProcedure // OnCopy()

#EndIf