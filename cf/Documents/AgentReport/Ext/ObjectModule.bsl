#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	Counterparty = SmallBusinessServer.GetCompany(Company);
	
	// Preparation of the order table.
	OrdersTable = Inventory.Unload(, "CustomerOrder, Total");
	OrdersTable.Columns.Add("TotalCalc");
	For Each CurRow IN OrdersTable Do
		If Not Counterparty.DoOperationsByOrders Then
			CurRow.CustomerOrder = Documents.CustomerOrder.EmptyRef();
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

// Procedure of the document filling based on the customer invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier invoice 
// FillingData   - Structure - Document filling data
//	
Procedure FillBySalesInvoice(FillingData)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CustomerInvoiceInventory.Ref.Company AS Company,
	|	CustomerInvoiceInventory.Ref.Counterparty AS Counterparty,
	|	CustomerInvoiceInventory.Ref.Contract AS Contract,
	|	CustomerInvoiceInventory.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	CustomerInvoiceInventory.Ref.PriceKind AS PriceKind,
	|	CustomerInvoiceInventory.Ref.DocumentCurrency AS DocumentCurrency,
	|	CustomerInvoiceInventory.Ref.VATTaxation AS VATTaxation,
	|	CustomerInvoiceInventory.Ref.AmountIncludesVAT AS AmountIncludesVAT,
	|	CustomerInvoiceInventory.Ref.IncludeVATInPrice AS IncludeVATInPrice,
	|	CustomerInvoiceInventory.Ref.ExchangeRate AS ExchangeRate,
	|	CustomerInvoiceInventory.Ref.Multiplicity AS Multiplicity,
	|	CustomerInvoiceInventory.ProductsAndServices AS ProductsAndServices,
	|	CustomerInvoiceInventory.Characteristic AS Characteristic,
	|	CustomerInvoiceInventory.Batch AS Batch,
	|	CustomerInvoiceInventory.Quantity AS Quantity,
	|	CustomerInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	CustomerInvoiceInventory.Price AS TransmissionPrice,
	|	CustomerInvoiceInventory.Amount AS TransmissionAmount,
	|	CustomerInvoiceInventory.VATRate AS VATRate,
	|	CustomerInvoiceInventory.VATAmount AS TransmissionVATAmount,
	|	CustomerInvoiceInventory.Order AS CustomerOrder,
	|	0 AS ConnectionKey,
	|	CustomerInvoiceInventory.ConnectionKey AS ConnectionKeySerialNumbes
	|FROM
	|	Document.CustomerInvoice.Inventory AS CustomerInvoiceInventory
	|WHERE
	|	CustomerInvoiceInventory.Ref = &BasisDocument";
	
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
		
		NewRow = Customers.Add();
		NewRow.Customer = QueryResultSelection.Counterparty;
		NewRow.ConnectionKey = QueryResultSelection.ConnectionKey;
		
		QueryResultSelection.Reset();
		While QueryResultSelection.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, QueryResultSelection);
		EndDo;
		
		If GetFunctionalOption("UseSerialNumbers") Then
			SerialNumbers.Load(FillingData.SerialNumbers.Unload());
			For Each Str In Inventory Do
				Str.SerialNumbers = WorkWithSerialNumbersClientServer.StringPresentationOfSerialNumbersOfLine(SerialNumbers, Str.ConnectionKeySerialNumbers);
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure // FillBySalesInvoice()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	TableInventory = Inventory.Unload(, "CustomerOrder, Total");
	TableInventory.GroupBy("CustomerOrder", "Total");
	
	TablePrepayment = Prepayment.Unload(, "Order, PaymentAmount");
	TablePrepayment.GroupBy("Order", "PaymentAmount");
	
	QuantityInventory = Inventory.Count();
	
	For Each String IN TablePrepayment Do
		
		FoundStringWorksAndServices = Undefined;
		
		If Counterparty.DoOperationsByOrders
		   AND String.Order <> Undefined
		   AND String.Order <> Documents.CustomerOrder.EmptyRef() Then
			FoundStringInventory = Inventory.Find(String.Order, "CustomerOrder");
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		ElsIf Counterparty.DoOperationsByOrders Then
			FoundStringInventory = TableInventory.Find(Undefined, "CustomerOrder");
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.CustomerOrder.EmptyRef(), "CustomerOrder"), FoundStringInventory);
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
	
EndProcedure // FillCheckProcessing()

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("Structure") Then
		FillPropertyValues(ThisObject, FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerInvoice") Then
		If FillingData.OperationKind = Enums.OperationKindsCustomerInvoice.TransferForCommission Then
			FillBySalesInvoice(FillingData);
		Else
			Raise NStr("en = 'You can not enter the Agent report on the basis of the operation " + FillingData.OperationKind + "!'");
		EndIf;
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total");
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
EndProcedure // BeforeWrite()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.AgentReport.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryTransferred(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesUndistributed(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	SmallBusinessServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.AgentReport.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.AgentReport.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure // UndoPosting()

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	Prepayment.Clear();
	
EndProcedure // OnCopy()

#EndIf