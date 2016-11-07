#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	OrderInHeader = (CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader);
	Counterparty = SmallBusinessServer.GetCompany(Company);
	
	OrdersTable = WorksAndServices.Unload(, "CustomerOrder, Total");
	OrdersTable.Columns.Add("TotalCalc");
	For Each CurRow IN OrdersTable Do
		If Not Counterparty.DoOperationsByOrders Then
			CurRow.CustomerOrder = Documents.CustomerOrder.EmptyRef();
		ElsIf OrderInHeader Then
			CurRow.CustomerOrder = CustomerOrder;
		EndIf;
		CurRow.TotalCalc = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
			CurRow.Total,
			?(Contract.SettlementsCurrency = DocumentCurrency, ExchangeRate, 1),
			ExchangeRate,
			?(Contract.SettlementsCurrency = DocumentCurrency, Multiplicity, 1),
			Multiplicity
		);
	EndDo;
	OrdersTable.GroupBy("CustomerOrder", "Total, TotalCalc");
	OrdersTable.Sort("CustomerOrder Asc");
	
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
	
	Query.SetParameter("Order", OrdersTable.UnloadColumn("CustomerOrder"));
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
		
		FoundString = OrdersTable.Find(SelectionOfQueryResult.Order, "CustomerOrder");
		
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
	
EndProcedure

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
		OrdersArray.Add(FillingData);
		CustomerOrderPosition = SmallBusinessReUse.GetValueOfSetting("CustomerOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(CustomerOrderPosition) Then
			CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader;
		EndIf;
		If CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader Then
			CustomerOrder = FillingData;
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
	|		ON CustomerOrder.Ref.Contract.SettlementsCurrency = CurrencyRatesSliceLast.Currency},
	|	Constant.NationalCurrency AS NationalCurrency
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
	|					AND (ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Work)
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
	|	CustomerOrderInventory.Characteristic AS Characteristic,
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
	|	CustomerOrderInventory.Ref AS CustomerOrder,
	|	CustomerOrderInventory.Content AS Content,
	|	CustomerOrderInventory.AutomaticDiscountsPercent,
	|	CustomerOrderInventory.AutomaticDiscountAmount,
	|	CustomerOrderInventory.ConnectionKey
	|FROM
	|	Document.CustomerOrder.Inventory AS CustomerOrderInventory
	|WHERE
	|	CustomerOrderInventory.Ref IN(&OrdersArray)
	|	AND (CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Work)
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
	BalanceTable.Indexes.Add("CustomerOrder, ProductsAndServices,Characteristic");
	
	// AutomaticDiscounts.
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscountsMarkups");
	If UseAutomaticDiscounts Then
		OrderDiscountsMarkups = ResultsArray[2].Unload();
		DiscountsMarkups.Clear();
	EndIf;
	// End AutomaticDiscounts.
	
	WorksAndServices.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[1].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("CustomerOrder", Selection.CustomerOrder);
			StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
			StructureForSearch.Insert("Characteristic", Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = WorksAndServices.Add();
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
					For Each OrderDiscountString IN OrderDiscountsMarkups.FindRows(New Structure("Order,ConnectionKey", Selection.CustomerOrder, Selection.ConnectionKey)) Do
						
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
	
	// AutomaticDiscounts.
	If UseAutomaticDiscounts Then
		DiscountsMarkupsCalculationResult = DiscountsMarkups.Unload();
		DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(ThisObject, "WorksAndServices", DiscountsMarkupsCalculationResult);
	EndIf;
	
EndProcedure // FillByCustomerOrder()

// Procedure of filling the document on the basis of the supplier invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier
// invoice FillingData - Structure - Document filling data
//	
Procedure FillByInvoiceForPayment(FillingData)
	
	// Filling out a document header.
	ThisObject.BasisDocument = FillingData.Ref;
	Company = FillingData.Company;
	Counterparty = FillingData.Counterparty;
	Contract = FillingData.Contract;
	PriceKind = FillingData.PriceKind;
	DiscountMarkupKind = FillingData.DiscountMarkupKind;
	DocumentCurrency = FillingData.DocumentCurrency;
	AmountIncludesVAT = FillingData.AmountIncludesVAT;
	VATTaxation = FillingData.VATTaxation;
	// DiscountCards
	DiscountCard = FillingData.DiscountCard;
	DiscountPercentByDiscountCard = FillingData.DiscountPercentByDiscountCard;
	// End DiscountCards
	
	If DocumentCurrency = Constants.NationalCurrency.Get() Then
		ExchangeRate = FillingData.ExchangeRate;
		Multiplicity = FillingData.Multiplicity;
	Else
		StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
	EndIf;	
	
	OrderInTabularSection = Not SmallBusinessReUse.AttributeInHeader("CustomerOrderPositionInShipmentDocuments");	
	If TypeOf(FillingData.BasisDocument) = Type("DocumentRef.CustomerOrder") Then
		CustomerOrderForFill = FillingData.BasisDocument;
	Else
		CustomerOrderForFill = Documents.CustomerOrder.EmptyRef();
	EndIf;
	If Not OrderInTabularSection Then
		CustomerOrder = CustomerOrderForFill;
	EndIf; 
	
	
	// Filling document tabular section.
	WorksAndServices.Clear();
	
	For Each TabularSectionRow IN FillingData.Inventory Do
		
		If TabularSectionRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work
			OR TabularSectionRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service Then
		
			NewRow = WorksAndServices.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			
			If OrderInTabularSection Then
				NewRow.CustomerOrder = CustomerOrderForFill;
			EndIf;
			
			
		EndIf;
		
	EndDo;

	// AutomaticDiscounts
	If GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
		For Each DiscountsMarkUpsString IN FillingData.DiscountsMarkups Do
			SearchStructure = New Structure("ConnectionKey", );
			If WorksAndServices.Find(DiscountsMarkUpsString.ConnectionKey, "ConnectionKey") <> Undefined Then
				NewDiscountsMarksUpString = DiscountsMarkups.Add();
				FillPropertyValues(NewDiscountsMarksUpString, DiscountsMarkUpsString);
			EndIf;
		EndDo;
		DiscountsAreCalculated = FillingData.DiscountsAreCalculated;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure // FillByInvoiceForPayment()

// Posting cancellation procedure of the subordinate customer invoice note
//
Procedure SubordinatedInvoiceControl()
	
	InvoiceStructure = SmallBusinessServer.GetSubordinateInvoice(Ref);
	If Not InvoiceStructure = Undefined Then
		
		CustomerInvoiceNote	 = InvoiceStructure.Ref;
		If CustomerInvoiceNote.Posted Then
			
			MessageText = NStr("en='As there are no register records of the %CurrentDocumentPresentation% document, undo the posting of %InvoicePresentation%.';ru='В связи с отсутствием движений у документа %ПредставлениеТекущегоДокумента% распроводится счет фактура %ПредставлениеСчетФактуры%.'");
			MessageText = StrReplace(MessageText, "%CurrentDocumentPresentation%", """Acceptance certificate No " + Number + " dated " + Format(Date, "DF=dd.MM.yyyy") + """");
			MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Customer invoice note (issued) No " + InvoiceStructure.Number + " dated " + InvoiceStructure.Date + """");
			
			CommonUseClientServer.MessageToUser(MessageText);
			
			InvoiceObject = CustomerInvoiceNote.GetObject();
			InvoiceObject.Write(DocumentWriteMode.UndoPosting);
			
		EndIf;
		
	EndIf;
	
EndProcedure //SubordinateInvoiceControl()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	OrderInHeader = CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader;
	
	TableWorksAndServices = WorksAndServices.Unload(, "CustomerOrder, Total");
	TableWorksAndServices.GroupBy("CustomerOrder", "Total");
	
	TablePrepayment = Prepayment.Unload(, "Order, PaymentAmount");
	TablePrepayment.GroupBy("Order", "PaymentAmount");
	
	If OrderInHeader Then
		For Each StringWorksAndServices IN TableWorksAndServices Do
			StringWorksAndServices.CustomerOrder = CustomerOrder;
		EndDo;
		If Counterparty.DoOperationsByOrders Then
			For Each RowPrepayment IN TablePrepayment Do
				RowPrepayment.Order = CustomerOrder;
			EndDo;
		EndIf;
	EndIf;
	
	// 100% discount.
	ThereAreManualDiscounts = GetFunctionalOption("UseDiscountsMarkups");
	ThereAreAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscountsMarkups"); // AutomaticDiscounts
	If ThereAreManualDiscounts OR ThereAreAutomaticDiscounts Then
		For Each StringWorksAndServices IN WorksAndServices Do
			// AutomaticDiscounts
			CurAmount = StringWorksAndServices.Price * StringWorksAndServices.Quantity;
			ManualDiscountCurAmount = ?(ThereAreManualDiscounts, ROUND(CurAmount * StringWorksAndServices.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount = ?(ThereAreAutomaticDiscounts, StringWorksAndServices.AutomaticDiscountAmount, 0);
			CurAmountDiscounts = ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			If StringWorksAndServices.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(StringWorksAndServices.Amount) Then
				MessageText = NStr("en='The column ""Amount"" in the %Number% string of the list ""Works and services"" is not filled.';ru='Не заполнена колонка ""Сумма"" в строке %Номер% списка ""Работы и услуги"".'");
				MessageText = StrReplace(MessageText, "%Number%", StringWorksAndServices.LineNumber);
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"WorksAndServices",
					StringWorksAndServices.LineNumber,
					"Amount",
					Cancel
				);
			EndIf;
		EndDo;
	EndIf;
	
	QuantityOfWorkAndService = WorksAndServices.Count();
	
	For Each String IN TablePrepayment Do
		
		FoundStringWorksAndServices = Undefined;
		
		If Counterparty.DoOperationsByOrders
		   AND String.Order <> Undefined
		   AND String.Order <> Documents.CustomerOrder.EmptyRef()
		   AND String.Order <> Documents.PurchaseOrder.EmptyRef() Then
			FoundStringWorksAndServices = TableWorksAndServices.Find(String.Order, "CustomerOrder");
			Total = ?(FoundStringWorksAndServices = Undefined, 0, FoundStringWorksAndServices.Total);
		ElsIf Counterparty.DoOperationsByOrders Then
			FoundStringWorksAndServices = TableWorksAndServices.Find(Undefined, "CustomerOrder");
			FoundStringWorksAndServices = ?(FoundStringWorksAndServices = Undefined, TableWorksAndServices.Find(Documents.CustomerOrder.EmptyRef(), "CustomerOrder"), FoundStringWorksAndServices);
			Total = ?(FoundStringWorksAndServices = Undefined, 0, FoundStringWorksAndServices.Total);
		Else
			Total = WorksAndServices.Total("Total");
		EndIf;
		
		If FoundStringWorksAndServices = Undefined
		   AND QuantityOfWorkAndService > 0
		   AND Counterparty.DoOperationsByOrders Then
			MessageText = NStr("en='Advance by order that is different from the one specified in tabular section ""Works and services"" can not be accepted.';ru='Нельзя зачесть аванс по заказу отличному от указанных в табличной части ""Работы и услуги""!'");
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

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
		If FillingData.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
			Raise NStr("en='Unable to generate Acceptance certificate based on the job order.';ru='Нельзя ввести Акт выполненных работ на основании заказ-наряда!'");;
		EndIf;
		FillByCustomerOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfCustomerOrders") Then
		FillByCustomerOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.InvoiceForPayment") Then
		BasisOfInvoiceForPayment = FillingData.BasisDocument;
		If TypeOf(BasisOfInvoiceForPayment) = Type("DocumentRef.CustomerOrder") Then
			If BasisOfInvoiceForPayment.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
				Raise NStr("en='Unable to generate Acceptance certificate based on the invoice for payment issued for the Job order.';ru='Нельзя ввести Акт выполненных работ на основании Счета на оплату, выписанного на Заказ-наряд!'");;
			EndIf;
		EndIf;
		FillByInvoiceForPayment(FillingData);
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
		For Each TabularSectionRow IN WorksAndServices Do
			TabularSectionRow.CustomerOrder = CustomerOrder;
		EndDo;
		If Counterparty.DoOperationsByOrders Then
			For Each TabularSectionRow IN Prepayment Do
				TabularSectionRow.Order = CustomerOrder;
			EndDo;
		EndIf;
	EndIf;
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	DocumentAmount = WorksAndServices.Total("Total");
	
EndProcedure // BeforeWrite()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.AcceptanceCertificate.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectCustomerOrders(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesUndistributed(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// DiscountCards
	SmallBusinessServer.ReflectSalesByDiscountCard(AdditionalProperties, RegisterRecords, Cancel);
	// AutomaticDiscounts
	SmallBusinessServer.FlipAutomaticDiscountsApplied(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.AcceptanceCertificate.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.AcceptanceCertificate.RunControl(Ref, AdditionalProperties, Cancel, True);
	
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