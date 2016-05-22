#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure fills tabular section according to specification.
//
Procedure FillTabularSectionBySpecification(NodesSpecificationStack, NodesTable = Undefined) Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Factor AS Factor,
	|	TableProduction.Specification AS Specification
	|INTO TemporaryTableProduction
	|FROM
	|	&TableProduction AS TableProduction
	|WHERE
	|	TableProduction.Specification <> VALUE(Catalog.Specifications.EmptyRef)";
	
	If NodesTable = Undefined Then
		Inventory.Clear();
		TableProduction = Products.Unload();
		Array = New Array();
		Array.Add(Type("Number"));
		TypeDescriptionC = New TypeDescription(Array, , ,New NumberQualifiers(10,3));
		TableProduction.Columns.Add("Factor", TypeDescriptionC);
		For Each StringProducts IN TableProduction Do
			If ValueIsFilled(StringProducts.MeasurementUnit)
				AND TypeOf(StringProducts.MeasurementUnit) = Type("CatalogRef.UOM") Then
				StringProducts.Factor = StringProducts.MeasurementUnit.Factor;
			Else
				StringProducts.Factor = 1;
			EndIf;
		EndDo;
		NodesTable = TableProduction.CopyColumns("LineNumber,Quantity,Factor,Specification");
		Query.SetParameter("TableProduction", TableProduction);
	Else
		Query.SetParameter("TableProduction", NodesTable);
	EndIf;
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	MIN(TableProduction.LineNumber) AS ProductionLineNumber,
	|	TableProduction.Specification AS ProductionSpecification,
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.ProductsQuantity * TableProduction.Factor * TableProduction.Quantity) AS Quantity,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.SpecificationContentRowTypes.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = Type(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END AS Factor,
	|	TableMaterials.CostPercentage AS CostPercentage,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN Catalog.Specifications.Content AS TableMaterials
	|		ON TableProduction.Specification = TableMaterials.Ref,
	|	Constant.FunctionalOptionUseCharacteristics AS UseCharacteristics
	|WHERE
	|	TableMaterials.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|
	|GROUP BY
	|	TableProduction.Specification,
	|	TableMaterials.ContentRowType,
	|	TableMaterials.ProductsAndServices,
	|	TableMaterials.MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.SpecificationContentRowTypes.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = Type(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END,
	|	TableMaterials.CostPercentage,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Selection.ContentRowType = Enums.SpecificationContentRowTypes.Node Then
			NodesTable.Clear();
			If Not NodesSpecificationStack.Find(Selection.Specification) = Undefined Then
				MessageText = NStr("en = 'During filling in of the Specification materials
									|tabular section a recursive item occurrence was found'")+" "+Selection.ProductsAndServices+" "+NStr("en = 'in specifications'")+" "+Selection.ProductionSpecification+"
									|The operation failed.";
				Raise MessageText;
			EndIf;
			NodesSpecificationStack.Add(Selection.Specification);
			NewRow = NodesTable.Add();
			FillPropertyValues(NewRow, Selection);
			FillTabularSectionBySpecification(NodesSpecificationStack, NodesTable);
		Else
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
			If VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
				If ValueIsFilled(NewRow.ProductsAndServices.VATRate) Then
					NewRow.VATRate = NewRow.ProductsAndServices.VATRate;
				Else
					NewRow.VATRate = Company.DefaultVATRate;
				EndIf;
			Else
				If VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
					NewRow.VATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
				Else
					NewRow.VATRate = SmallBusinessReUse.GetVATRateZero();
				EndIf;
			EndIf;
			
		EndIf;
	EndDo;
	
	NodesSpecificationStack.Clear();
	Inventory.GroupBy("ProductsAndServices, Characteristic, Batch, MeasurementUnit, VATRate", "Quantity");
	
EndProcedure // FillTabularSectionBySpecification()

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	Counterparty = SmallBusinessServer.GetCompany(Company);
	
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
	|					AND Order = &Order
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
	|		AND DocumentRegisterRecordsAccountsReceivable.Order = &Order
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
	
	If Counterparty.DoOperationsByOrders Then
		Query.SetParameter("Order", CustomerOrder);
	Else
		Query.SetParameter("Order", Documents.CustomerOrder.EmptyRef());
	EndIf;
	
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
	AmountLeftToDistribute = Products.Total("Total");
	AmountLeftToDistribute = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
		AmountLeftToDistribute,
		?(Contract.SettlementsCurrency = DocumentCurrency, ExchangeRate, 1),
		ExchangeRate,
		?(Contract.SettlementsCurrency = DocumentCurrency, Multiplicity, 1),
		Multiplicity
	);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	While AmountLeftToDistribute > 0 Do
		
		If SelectionOfQueryResult.Next() Then
			
			If SelectionOfQueryResult.SettlementsAmount <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow = Prepayment.Add();
				FillPropertyValues(NewRow, SelectionOfQueryResult);
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.SettlementsAmount;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow = Prepayment.Add();
				FillPropertyValues(NewRow, SelectionOfQueryResult);
				NewRow.SettlementsAmount = AmountLeftToDistribute;
				NewRow.PaymentAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
					NewRow.SettlementsAmount,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.DocumentCurrencyCurrencyRatesRate,
					SelectionOfQueryResult.Multiplicity,
					SelectionOfQueryResult.DocumentCurrencyCurrencyRatesMultiplicity
				);
				AmountLeftToDistribute = 0;
				
			EndIf;
			
		Else
			
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Posting cancellation procedure of the subordinate customer invoice note
//
Procedure SubordinatedInvoiceControl()
	
	InvoiceStructure = SmallBusinessServer.GetSubordinateInvoice(Ref);
	If Not InvoiceStructure = Undefined Then
		
		CustomerInvoiceNote	 = InvoiceStructure.Ref;
		If CustomerInvoiceNote.Posted Then
			
			MessageText = NStr("en = 'As there are no register records of the %CurrentDocumentPresentation% document, undo the posting of %InvoicePresentation%.'");
			MessageText = StrReplace(MessageText, "%CurrentDocumentPresentation%", """Processing report No. " + Number + " from " + Format(Date, "DF=dd.MM.yyyy") + """");
			MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Customer invoice note (issued) No " + InvoiceStructure.Number + " from " + InvoiceStructure.Date + """");
			
			CommonUseClientServer.MessageToUser(MessageText);
			
			InvoiceObject = CustomerInvoiceNote.GetObject();
			InvoiceObject.Write(DocumentWriteMode.UndoPosting);
			
		EndIf;
		
	EndIf;
	
EndProcedure //SubordinateInvoiceControl()

// Procedure fills out the Quantity column according to reserves to be ordered.
//
Procedure FillColumnReserveByReserves() Export
	
	Products.LoadColumn(New Array(Products.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	&Order AS CustomerOrder
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory";
	
	Query.SetParameter("TableInventory", Products.Unload());
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
		StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Products.FindRows(StructureForSearch);
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

// Procedure of filling the document on the basis of the supplier invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier invoice 
// FillingData   - Structure - Document filling data
//	
Procedure FillByCustomerOrder(FillingData)
	
	// Header filling.
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData,
			New Structure("Company, Counterparty, Contract, Ref, StructuralUnitReserve, PriceKind, DiscountMarkupKind, DocumentCurrency, VATTaxation, AmountIncludesVAT, IncludeVATInPrice, ExchangeRate, Multiplicity, OrderState, Closed, Posted"));
	
	Documents.CustomerOrder.CheckAbilityOfEnteringByCustomerOrder(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues, "Company, Counterparty, Contract, PriceKind, DiscountMarkupKind, DocumentCurrency, VATTaxation, AmountIncludesVAT, IncludeVATInPrice, ExchangeRate, Multiplicity");
	
	CustomerOrder = AttributeValues.Ref;
	If Constants.FunctionalOptionInventoryReservation.Get() Then
		StructuralUnit = AttributeValues.StructuralUnitReserve;
	EndIf;
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = SmallBusinessReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
		EndIf;
	EndIf;
	
	If Not DocumentCurrency = Constants.NationalCurrency.Get() Then
		StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(?(ValueIsFilled(Date), Date, CurrentDate()), New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
	EndIf;
	
	// Filling out tabular section.
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
	|		DocumentRegisterRecordsCustomersOrders.Recorder = &Ref) AS OrdersBalance
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
	|	InventoryReceivedBalances.CustomerOrder AS CustomerOrder,
	|	InventoryReceivedBalances.Contract AS Contract,
	|	InventoryReceivedBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryReceivedBalances.Characteristic AS Characteristic,
	|	InventoryReceivedBalances.Batch AS Batch,
	|	SUM(InventoryReceivedBalances.QuantityBalance) AS Quantity,
	|	SUM(InventoryReceivedBalances.SettlementsAmount) AS Amount
	|FROM
	|	(SELECT
	|		InventoryReceivedBalances.Order AS CustomerOrder,
	|		InventoryReceivedBalances.Contract AS Contract,
	|		InventoryReceivedBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryReceivedBalances.Characteristic AS Characteristic,
	|		InventoryReceivedBalances.Batch AS Batch,
	|		InventoryReceivedBalances.QuantityBalance AS QuantityBalance,
	|		InventoryReceivedBalances.SettlementsAmountBalance AS SettlementsAmount
	|	FROM
	|		AccumulationRegister.InventoryReceived.Balance(
	|				,
	|				Order = &BasisDocument
	|					AND ReceptionTransmissionType = VALUE(Enum.ProductsReceiptTransferTypes.ReceiptToProcessing)) AS InventoryReceivedBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryAccepted.Order,
	|		DocumentRegisterRecordsInventoryAccepted.Contract,
	|		DocumentRegisterRecordsInventoryAccepted.ProductsAndServices,
	|		DocumentRegisterRecordsInventoryAccepted.Characteristic,
	|		DocumentRegisterRecordsInventoryAccepted.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryAccepted.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryAccepted.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryAccepted.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryAccepted.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryAccepted.SettlementsAmount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryAccepted.SettlementsAmount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryReceived AS DocumentRegisterRecordsInventoryAccepted
	|	WHERE
	|		DocumentRegisterRecordsInventoryAccepted.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryAccepted.ReceptionTransmissionType = VALUE(Enum.ProductsReceiptTransferTypes.ReceiptToProcessing)) AS InventoryReceivedBalances
	|
	|GROUP BY
	|	InventoryReceivedBalances.CustomerOrder,
	|	InventoryReceivedBalances.Contract,
	|	InventoryReceivedBalances.ProductsAndServices,
	|	InventoryReceivedBalances.Characteristic,
	|	InventoryReceivedBalances.Batch
	|
	|HAVING
	|	SUM(InventoryReceivedBalances.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CustomerOrderInventory.ProductsAndServices AS ProductsAndServices,
	|	CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|	CustomerOrderInventory.Characteristic AS Characteristic,
	|	CustomerOrderInventory.Batch AS Batch,
	|	CASE
	|		WHEN VALUETYPE(CustomerOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE CustomerOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	CustomerOrderInventory.Quantity AS Quantity,
	|	CustomerOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CustomerOrderInventory.Price AS Price,
	|	CustomerOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	CustomerOrderInventory.Amount AS Amount,
	|	CustomerOrderInventory.VATRate AS VATRate,
	|	CustomerOrderInventory.VATAmount AS VATAmount,
	|	CustomerOrderInventory.Total AS Total,
	|	CustomerOrderInventory.Content AS Content,
	|	CustomerOrderInventory.Specification AS Specification,
	|	CustomerOrderInventory.AutomaticDiscountsPercent,
	|	CustomerOrderInventory.AutomaticDiscountAmount,
	|	CustomerOrderInventory.ConnectionKey
	|FROM
	|	Document.CustomerOrder.Inventory AS CustomerOrderInventory
	|WHERE
	|	CustomerOrderInventory.Ref = &BasisDocument
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
	|	DiscountsMarkups.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("ProductsAndServices,Characteristic");
	
	// AutomaticDiscounts.
	OrderDiscountsMarkups = ResultsArray[3].Unload();
	DiscountsMarkups.Clear();
	// End AutomaticDiscounts.
	
	Products.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
			StructureForSearch.Insert("Characteristic", Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = Products.Add();
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
				For Each OrderDiscountString IN OrderDiscountsMarkups.FindRows(New Structure("Order,ConnectionKey", FillingData, Selection.ConnectionKey)) Do
					
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
			// End AutomaticDiscounts
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// AutomaticDiscounts.
	DiscountsMarkupsCalculationResult = DiscountsMarkups.Unload();
	DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(ThisObject, "Inventory", DiscountsMarkupsCalculationResult);
	// End AutomaticDiscounts.
	
	Inventory.Clear();
	BalanceTable = ResultsArray[1].Unload();
	AccountingCurrency = Constants.AccountingCurrency.Get();
	For Each StringInventory IN BalanceTable Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, StringInventory);
		
		If StringInventory.Amount > 0 Then
			If DocumentCurrency = StringInventory.Contract.SettlementsCurrency Then
				Amount = StringInventory.Amount;
			Else
				CurrencyRatesStructure = SmallBusinessServer.GetCurrencyRates(DocumentCurrency, StringInventory.Contract.SettlementsCurrency, ?(ValueIsFilled(Date), Date, CurrentDate()));
				Amount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
							StringInventory.Amount,
							CurrencyRatesStructure.InitRate,
							CurrencyRatesStructure.ExchangeRate,
							CurrencyRatesStructure.RepetitionBeg,
							CurrencyRatesStructure.Multiplicity);
			EndIf;
		Else
			Amount = 0;
		EndIf;
		
		NewRow.MeasurementUnit = StringInventory.ProductsAndServices.MeasurementUnit;
		NewRow.Price = Amount / StringInventory.Quantity;
		
		If VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
			If ValueIsFilled(StringInventory.ProductsAndServices.VATRate) Then
				NewRow.VATRate = StringInventory.ProductsAndServices.VATRate;
			Else
				NewRow.VATRate = Company.DefaultVATRate;
			EndIf;
		Else
			If VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
				NewRow.VATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
			Else
				NewRow.VATRate = SmallBusinessReUse.GetVATRateZero();
			EndIf;
		EndIf;
		
		DataStructure = SmallBusinessServer.GetTabularSectionRowSum(
					New Structure("Quantity, Price, Amount, VATRate, VATAmount, AmountIncludesVAT, Total",
						StringInventory.Quantity, NewRow.Price, 0, NewRow.VATRate, 0, AmountIncludesVAT, 0));
						
		FillPropertyValues(NewRow, DataStructure);
		
	EndDo;
	
	// Filling out reserves.
	If Products.Count() > 0
		AND Constants.FunctionalOptionInventoryReservation.Get() Then
		FillColumnReserveByReserves();
	EndIf;
	
EndProcedure // FillByCustomerOrder()

// Procedure for filling the document on the basis of inventory assembly.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier invoice 
// FillingData - Structure - Document filling data
//	
Procedure FillByInventoryAssembly(FillingData)
	
	// Header filling.
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, OperationKind, ProductsStructuralUnit, ProductsCell, CustomerOrder"));
	
	FillPropertyValues(ThisObject, AttributeValues);
	
	If AttributeValues.ProductsStructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Warehouse Then
		StructuralUnit = AttributeValues.ProductsStructuralUnit;
		Cell = AttributeValues.ProductsCell;
	EndIf;
	
	If AttributeValues.OperationKind = Enums.OperationKindsInventoryAssembly.Disassembly Then
		TSProducts = "Inventory";
		TSMaterials = "Products";
	Else
		TSProducts = "Products";
		TSMaterials = "Inventory";
	EndIf;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	Production.Products.(
	|		ProductsAndServices AS ProductsAndServices,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		CASE
	|			WHEN Production.Products.ProductsAndServices.VATRate = VALUE(Catalog.VATRates.EmptyRef)
	|				THEN Production.Products.Ref.Company.DefaultVATRate
	|			ELSE Production.Products.ProductsAndServices.VATRate
	|		END AS VATRate,
	|		Quantity AS Quantity,
	|		MeasurementUnit AS MeasurementUnit,
	|		Specification AS Specification
	|	),
	|	Production.Inventory.(
	|		ProductsAndServices AS ProductsAndServices,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		CASE
	|			WHEN Production.Inventory.ProductsAndServices.VATRate = VALUE(Catalog.VATRates.EmptyRef)
	|				THEN Production.Inventory.Ref.Company.DefaultVATRate
	|			ELSE Production.Inventory.ProductsAndServices.VATRate
	|		END AS VATRate,
	|		Quantity AS Quantity,
	|		MeasurementUnit AS MeasurementUnit,
	|		Specification AS Specification
	|	),
	|	Production.Disposals.(
	|		ProductsAndServices AS ProductsAndServices,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		Quantity AS Quantity,
	|		MeasurementUnit AS MeasurementUnit
	|	)
	|FROM
	|	Document.InventoryAssembly AS Production
	|WHERE
	|	Production.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Products.Clear();
	Inventory.Clear();
	Disposals.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		Selection.Next();
		For Each SelectionMaterials IN Selection[TSMaterials].Unload() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, SelectionMaterials);
		EndDo;
		For Each SelectionProducts IN Selection[TSProducts].Unload() Do
			NewRow = Products.Add();
			FillPropertyValues(NewRow, SelectionProducts);
		EndDo;
		For Each SelectionDisposals IN Selection.Disposals.Unload() Do
			NewRow = Disposals.Add();
			FillPropertyValues(NewRow, SelectionDisposals);
		EndDo;
	EndIf;
	
	// Filling out reserves.
	If Products.Count() > 0
		AND Constants.FunctionalOptionInventoryReservation.Get()
		AND ValueIsFilled(StructuralUnit) Then
		FillColumnReserveByReserves();
	EndIf;
	
EndProcedure // FillByInventoryAssembly()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	PrepaymentTotal = Prepayment.Total("PaymentAmount");
	TotalAmountProducts = Products.Total("Total");
	
	If Constants.FunctionalOptionInventoryReservation.Get() Then
		
		For Each StringProducts IN Products Do
			
			If StringProducts.Reserve > StringProducts.Quantity Then
				
				MessageText = NStr("en = 'In the row No.%Number% of the ""Products"" tabular section, the quantity of the items shipped from the reserve exceeds the total quantity of inventory.'");
				MessageText = StrReplace(MessageText, "%Number%", StringProducts.LineNumber);
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Products",
					StringProducts.LineNumber,
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
		For Each StringProducts IN Products Do
			// AutomaticDiscounts
			CurAmount = StringProducts.Price * StringProducts.Quantity;
			ManualDiscountCurAmount = ?(ThereAreManualDiscounts, ROUND(CurAmount * StringProducts.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount = ?(ThereAreAutomaticDiscounts, StringProducts.AutomaticDiscountAmount, 0);
			CurAmountDiscounts = ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			If StringProducts.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(StringProducts.Amount) Then
				MessageText = NStr("en = 'Column ""Amount"" in the row %Number% of the ""Products"" list is not filled.'");
				MessageText = StrReplace(MessageText, "%Number%", StringProducts.LineNumber);
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Products",
					StringProducts.LineNumber,
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

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
		If FillingData.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
			Raise NStr("en = 'Unable to keep Report on processing according to the job order!'");;
		EndIf;
		FillByCustomerOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.InventoryAssembly") Then
		FillByInventoryAssembly(FillingData);
	EndIf;
	
EndProcedure // FillingProcessor()

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
	
	DocumentAmount = Products.Total("Total");
	
EndProcedure // BeforeWrite()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.ProcessingReport.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryForExpenseFromWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectCustomerOrders(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesUndistributed(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	
	// AutomaticDiscounts
	SmallBusinessServer.FlipAutomaticDiscountsApplied(AdditionalProperties, RegisterRecords, Cancel);

	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ProcessingReport.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.ProcessingReport.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	// Subordinate customer invoice note
	If Not Cancel Then
		
		SubordinatedInvoiceControl();
		
	EndIf;
	
EndProcedure // UndoPosting()

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	Prepayment.Clear();
	
EndProcedure // OnCopy()

#EndIf
