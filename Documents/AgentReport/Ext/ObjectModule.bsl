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
	|	0 AS ConnectionKey
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
		
	EndIf;
	
EndProcedure // FillBySalesInvoice()

// Procedure generates invoices for customers.
//
Procedure GenerateInvoicesCustomers(RefNew)
	
	TableOfSubordinatedInvoices = GetSubordinateCustomerInvoicesList();
	For Each TabularSectionRow IN Customers Do
		
		If Not ValueIsFilled(TabularSectionRow.Customer) Then
			 TabularSectionRow.CustomerInvoiceNoteIssued = False;
		EndIf;
		
		If Not TabularSectionRow.CustomerInvoiceNoteIssued
			OR Not ValueIsFilled(TabularSectionRow.InvoiceDate) Then
			TabularSectionRow.CustomerInvoiceNote = Documents.CustomerInvoiceNote.EmptyRef();
			Continue;
		EndIf;
		
		FilterParameters = New Structure;
		FilterParameters.Insert("Used", False);
		FilterParameters.Insert("Counterparty", TabularSectionRow.Customer);
		FilterParameters.Insert("Date", TabularSectionRow.InvoiceDate);
		
		GeneratedNewInvoice = False;
		SearchResult = TableOfSubordinatedInvoices.FindRows(FilterParameters);
		If SearchResult.Count() = 0 Then
			
			DocInvoice = Documents.CustomerInvoiceNote.CreateDocument();
			DocInvoice.Date = TabularSectionRow.InvoiceDate;
			GeneratedNewInvoice = True;
			
		Else
			
			If ValueIsFilled(TabularSectionRow.CustomerInvoiceNote) Then
				SearchIndex = 0;
				ResultIndex = Undefined;
				For Each SearchString IN SearchResult Do
					If SearchString.Ref = TabularSectionRow.CustomerInvoiceNote Then
						ResultIndex = SearchIndex;
					EndIf;
					SearchIndex = SearchIndex + 1;
				EndDo;
				If ResultIndex = Undefined Then
					FoundInvoice = SearchResult[0].Ref;
					SearchResult[0].Used = True;
				Else
					FoundInvoice = SearchResult[ResultIndex].Ref;
					SearchResult[ResultIndex].Used = True;
				EndIf;
			Else
				FoundInvoice = SearchResult[0].Ref;
				SearchResult[0].Used = True;
			EndIf;
			
			DocInvoice = FoundInvoice.GetObject();
			
		EndIf;
		
		DataStructure = New Structure;
		If RefNew = Undefined Then
			DataStructure.Insert("Ref", Ref);
		Else
			DataStructure.Insert("Ref", RefNew);
		EndIf;
		DataStructure.Insert("Date", TabularSectionRow.InvoiceDate);
		DataStructure.Insert("Company", Company);
		DataStructure.Insert("Customer", TabularSectionRow.Customer);
		DataStructure.Insert("ConsolidatedCommission", False);
		DataStructure.Insert("DocumentCurrency", DocumentCurrency);
		DataStructure.Insert("AmountIncludesVAT", AmountIncludesVAT);
		DataStructure.Insert("ExchangeRate", ExchangeRate);
		DataStructure.Insert("Multiplicity", Multiplicity);
		
		FilterParameters = New Structure;
		FilterParameters.Insert("ConnectionKey", TabularSectionRow.ConnectionKey);
		SearchResult = Inventory.FindRows(FilterParameters);
		
		DataStructure.Insert("Inventory", SearchResult);
		
		DocInvoice.FillByAgentReportCustomers(DataStructure);
		DocInvoice.Write();
		
		TabularSectionRow.CustomerInvoiceNote = DocInvoice.Ref;
		
		If GeneratedNewInvoice Then
			MessageText = NStr("en = 'Document %InvoicePresentation% is generated.'");
			MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Customer invoice note (issued) No " + DocInvoice.Number + " from " + DocInvoice.Date + """");
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
	EndDo;
	
EndProcedure // GenerateInvoicesCustomers()

// Procedure generates invoices for customers.
//
Procedure GenerateInvoicesConsolidated(RefNew)
	
	TableOfSubordinatedInvoices = GetSubordinateCustomerInvoicesList();
	ConnectionKeyCustomersConsolidated = New Array;
	For Each TabularSectionRow IN Customers Do
		
		If ConnectionKeyCustomersConsolidated.Find(TabularSectionRow.ConnectionKey) <> Undefined Then
			Continue;
		EndIf;
		
		If Not ValueIsFilled(TabularSectionRow.Customer) Then
			 TabularSectionRow.CustomerInvoiceNoteIssued = False;
		EndIf;
		
		If Not TabularSectionRow.CustomerInvoiceNoteIssued
			OR Not ValueIsFilled(TabularSectionRow.InvoiceDate) Then
			TabularSectionRow.CustomerInvoiceNote = Documents.CustomerInvoiceNote.EmptyRef();
			Continue;
		EndIf;
		
		FilterParameters = New Structure;
		FilterParameters.Insert("Used", False);
		FilterParameters.Insert("Counterparty", Counterparty);
		FilterParameters.Insert("Date", TabularSectionRow.InvoiceDate);
		
		GeneratedNewInvoice = False;
		SearchResult = TableOfSubordinatedInvoices.FindRows(FilterParameters);
		If SearchResult.Count() = 0 Then
			
			DocInvoice = Documents.CustomerInvoiceNote.CreateDocument();
			DocInvoice.Date = TabularSectionRow.InvoiceDate;
			GeneratedNewInvoice = True;
			
		Else
			
			If ValueIsFilled(TabularSectionRow.CustomerInvoiceNote) Then
				SearchIndex = 0;
				ResultIndex = Undefined;
				For Each SearchString IN SearchResult Do
					If SearchString.Ref = TabularSectionRow.CustomerInvoiceNote Then
						ResultIndex = SearchIndex;
					EndIf;
					SearchIndex = SearchIndex + 1;
				EndDo;
				If ResultIndex = Undefined Then
					FoundInvoice = SearchResult[0].Ref;
					SearchResult[0].Used = True;
				Else
					FoundInvoice = SearchResult[ResultIndex].Ref;
					SearchResult[ResultIndex].Used = True;
				EndIf;
			Else
				FoundInvoice = SearchResult[0].Ref;
				SearchResult[0].Used = True;
			EndIf;
			
			DocInvoice = FoundInvoice.GetObject();
			
		EndIf;
		
		FilterParametersConsolidated = New Structure;
		FilterParametersConsolidated.Insert("InvoiceDate", TabularSectionRow.InvoiceDate);
		SearchResultConsolidated = Customers.FindRows(FilterParametersConsolidated);
		
		ConnectionKeyConsolidated = New Array;
		For Each StringComposite IN SearchResultConsolidated Do
			
			If Not ValueIsFilled(StringComposite.Customer) Then
				StringComposite.CustomerInvoiceNoteIssued = False;
			EndIf;
				
			If Not StringComposite.CustomerInvoiceNoteIssued
				OR Not ValueIsFilled(StringComposite.InvoiceDate) Then
				StringComposite.CustomerInvoiceNote = Documents.CustomerInvoiceNote.EmptyRef();
				Continue;
			EndIf;
			
			ConnectionKeyConsolidated.Add(StringComposite.ConnectionKey);
			ConnectionKeyCustomersConsolidated.Add(StringComposite.ConnectionKey);
			
		EndDo;
		
		DataStructure = New Structure;
		If RefNew = Undefined Then
			DataStructure.Insert("Ref", Ref);
		Else
			DataStructure.Insert("Ref", RefNew);
		EndIf;
		DataStructure.Insert("Date", TabularSectionRow.InvoiceDate);
		DataStructure.Insert("Company", Company);
		DataStructure.Insert("Customer", Counterparty);
		DataStructure.Insert("ConsolidatedCommission", True);
		DataStructure.Insert("DocumentCurrency", DocumentCurrency);
		DataStructure.Insert("AmountIncludesVAT", AmountIncludesVAT);
		DataStructure.Insert("ExchangeRate", ExchangeRate);
		DataStructure.Insert("Multiplicity", Multiplicity);
		
		ArrayOfRowsInventory = New Array;
		For Each StringInventory IN Inventory Do
			If ConnectionKeyConsolidated.Find(StringInventory.ConnectionKey) <> Undefined Then
				ArrayOfRowsInventory.Add(StringInventory);
			EndIf;
		EndDo;
		
		DataStructure.Insert("Inventory", ArrayOfRowsInventory);
		
		DocInvoice.FillByAgentReportCustomers(DataStructure);
		DocInvoice.Write();
		
		For Each RowCustomers IN Customers Do
			If ConnectionKeyConsolidated.Find(RowCustomers.ConnectionKey) <> Undefined Then
				RowCustomers.CustomerInvoiceNote = DocInvoice.Ref;
			EndIf;
		EndDo;
		
		If GeneratedNewInvoice Then
			MessageText = NStr("en = 'Document %InvoicePresentation% is generated.'");
			MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Customer invoice note (issued) No " + DocInvoice.Number + " from " + DocInvoice.Date + """");
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
			
	EndDo;
	
EndProcedure // GenerateInvoicesConsolidated()

// Procedure generates invoices.
//
Procedure GenerateInvoices(RefNew = Undefined)
	
	If MakeOutInvoicesCollective Then
		GenerateInvoicesConsolidated(RefNew);
	Else
		GenerateInvoicesCustomers(RefNew);
	EndIf;
	
EndProcedure // GenerateInvoices()

// Procedure of cancellation of posting of subordinate invoice note (supplier)
//
Procedure ControlOfSubordinatedInvoiceReceived()
	
	InvoiceStructure = SmallBusinessServer.GetSubordinateInvoice(Ref, True);
	If Not InvoiceStructure = Undefined Then
		
		CustomerInvoiceNote	 = InvoiceStructure.Ref;
		If CustomerInvoiceNote.Posted Then
			
			MessageText = NStr("en = 'Due to the absence of the turnovers by the %CurrentDocumentPresentation% document, undo the posting of %InvoicePresentation%.'");
			MessageText = StrReplace(MessageText, "%CurrentDocumentPresentation%", """Agent report No. " + Number + " from " + Format(Date, "DF=dd.MM.yyyy") + """");
			MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Invoice Note (Supplier) No. " + InvoiceStructure.Number + " from " + InvoiceStructure.Date + """");
			
			CommonUseClientServer.MessageToUser(MessageText);
			
			InvoiceObject = CustomerInvoiceNote.GetObject();
			InvoiceObject.Write(DocumentWriteMode.UndoPosting);
			
		EndIf;
		
	EndIf;
	
	InvoiceStructure = SmallBusinessServer.GetSubordinateInvoice(Ref);
	If Not InvoiceStructure = Undefined Then
		
		CustomerInvoiceNote	 = InvoiceStructure.Ref;
		If CustomerInvoiceNote.Posted Then
			
			MessageText = NStr("en = 'As there are no register records of the %CurrentDocumentPresentation% document, undo the posting of %InvoicePresentation%.'");
			MessageText = StrReplace(MessageText, "%CurrentDocumentPresentation%", """Agent report No. " + Number + " from " + Format(Date, "DF=dd.MM.yyyy") + """");
			MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Customer invoice note (issued) No " + InvoiceStructure.Number + " from " + InvoiceStructure.Date + """");
			
			CommonUseClientServer.MessageToUser(MessageText);
			
			InvoiceObject = CustomerInvoiceNote.GetObject();
			InvoiceObject.Write(DocumentWriteMode.UndoPosting);
			
		EndIf;
		
	EndIf;
	
EndProcedure //SubordinateInvoiceControl()

// Function updates the parameters of subordinate invoices.
//
Function GetSubordinateCustomerInvoicesList()
	
	Query = New Query;
	Query.Text =
	
	"SELECT DISTINCT
	|	BEGINOFPERIOD(Doc.Date, Day) AS Date,
	|	FALSE AS Used,
	|	Doc.Ref AS Ref,
	|	Doc.Counterparty AS Counterparty
	|FROM
	|	(SELECT
	|		InvoiceBasisDocument.Date AS Date,
	|		InvoiceBasisDocument.Ref AS Ref,
	|		InvoiceBasisDocument.Counterparty AS Counterparty
	|	FROM
	|		Document.CustomerInvoiceNote AS InvoiceBasisDocument
	|	WHERE
	|		InvoiceBasisDocument.BasisDocument = &BasisDocument
	|		AND Not InvoiceBasisDocument.DeletionMark
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InvoiceBasisDocuments.Ref.Date,
	|		InvoiceBasisDocuments.Ref,
	|		InvoiceBasisDocuments.Ref.Counterparty
	|	FROM
	|		Document.CustomerInvoiceNote.BasisDocuments AS InvoiceBasisDocuments
	|	WHERE
	|		InvoiceBasisDocuments.BasisDocument = &BasisDocument
	|		AND Not InvoiceBasisDocuments.Ref.DeletionMark) AS Doc";
	
	Query.SetParameter("BasisDocument", Ref);
	Query.SetParameter("CounterpartiesList", Customers.UnloadColumn("Customer"));
	
	Return Query.Execute().Unload();
	
EndFunction // GetSubordinateCustomerInvoicesList()

// Procedure updates the parameters of subordinate invoices.
//
Procedure UpdateRefsOfInvoices() Export
	
	// Delete unused invoices.
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	Doc.Ref AS Ref,
	|	Doc.Number AS Number,
	|	Doc.Date AS Date
	|FROM
	|	(SELECT
	|		InvoiceBasisDocument.Ref AS Ref,
	|		InvoiceBasisDocument.Number AS Number,
	|		InvoiceBasisDocument.Date AS Date
	|	FROM
	|		Document.CustomerInvoiceNote AS InvoiceBasisDocument
	|	WHERE
	|		InvoiceBasisDocument.BasisDocument = &BasisDocument
	|		AND (NOT InvoiceBasisDocument.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InvoiceBasisDocuments.Ref,
	|		InvoiceBasisDocuments.Ref.Number,
	|		InvoiceBasisDocuments.Ref.Date
	|	FROM
	|		Document.CustomerInvoiceNote.BasisDocuments AS InvoiceBasisDocuments
	|	WHERE
	|		InvoiceBasisDocuments.BasisDocument = &BasisDocument
	|		AND (NOT InvoiceBasisDocuments.Ref.DeletionMark)) AS Doc";
	
	Query.SetParameter("BasisDocument", Ref);
	
	InvoicesTable = Query.Execute().Unload();
	For Each RowOfInvoice IN InvoicesTable Do
		
		FilterParameters = New Structure;
		FilterParameters.Insert("CustomerInvoiceNote", RowOfInvoice.Ref);
		FilterParameters.Insert("CustomerInvoiceNoteIssued", True);
		SearchResult = Customers.FindRows(FilterParameters);
		If SearchResult.Count() = 0 Then
			
			CurrentInvoice = RowOfInvoice.Ref.GetObject();
			If CurrentInvoice.BasisDocuments.Count() > 0 Then
				
				RowBasis = CurrentInvoice.BasisDocuments.Find(Ref, "BasisDocument");
				If Not RowBasis = Undefined Then
					
					CurrentInvoice.BasisDocuments.Delete(RowBasis);
					CurrentInvoice.Write();
					
					MessageText = NStr("en = 'From the document %InvoicePresentation% the reference to the current document is deleted.'");
					MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Customer invoice note (issued) No " + CurrentInvoice.Number + " from " + CurrentInvoice.Date + """");
					
					CommonUseClientServer.MessageToUser(MessageText);
					
				EndIf;
				
			Else
				
				CurrentInvoice.SetDeletionMark(True);
				CurrentInvoice.Write();
				
				MessageText = NStr("en = 'Document %InvoicePresentation% is marked for deletion.'");
				MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Customer invoice note (issued) No " + CurrentInvoice.Number + " from " + CurrentInvoice.Date + """");
				
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	SubordinatedInvoicesProcessing(Posted);
	
EndProcedure // UpdateRefsOfInvoices()

// Procedure of cancellation / posting for subordinate invoice notes.
//
Procedure SubordinatedInvoicesProcessing(Post = True)
	
	Query = New Query;
	Query.SetParameter("BasisDocument", Ref);
	Query.SetParameter("FlagOfPosting", Not Post);
	
	Query.Text =
	"SELECT DISTINCT
	|	Doc.Ref AS Ref,
	|	Doc.Number AS Number,
	|	Doc.Date AS Date
	|FROM
	|	(SELECT
	|		InvoiceBasisDocument.Ref AS Ref,
	|		InvoiceBasisDocument.Number AS Number,
	|		InvoiceBasisDocument.Date AS Date
	|	FROM
	|		Document.CustomerInvoiceNote AS InvoiceBasisDocument
	|	WHERE
	|		InvoiceBasisDocument.Posted = &FlagOfPosting
	|		AND InvoiceBasisDocument.BasisDocument = &BasisDocument
	|		AND (NOT InvoiceBasisDocument.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InvoiceBasisDocuments.Ref,
	|		InvoiceBasisDocuments.Ref.Number,
	|		InvoiceBasisDocuments.Ref.Date
	|	FROM
	|		Document.CustomerInvoiceNote.BasisDocuments AS InvoiceBasisDocuments
	|	WHERE
	|		InvoiceBasisDocuments.Ref.Posted = &FlagOfPosting
	|		AND InvoiceBasisDocuments.BasisDocument = &BasisDocument
	|		AND (NOT InvoiceBasisDocuments.Ref.DeletionMark)) AS Doc";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	QueryResult = QueryResult.Unload();
	For Each ResultRow IN QueryResult Do
		
		CurrentDocument = ResultRow.Ref.GetObject();
		If Post AND Not CurrentDocument.CheckFilling() Then
			Continue;
		EndIf;
		
		StatePosted = CurrentDocument.Posted;
		
		CurrentDocument.Posted = Post;
		CurrentDocument.Write();
		
		If StatePosted AND Not Post Then
			
			MessageText = NStr("en = 'The invoice note %InvoicePresentation% is unposted.'");
			MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Customer invoice note (issued) No " + CurrentDocument.Number + " from " + CurrentDocument.Date + """");
			
			CommonUseClientServer.MessageToUser(MessageText);
			
		ElsIf Not StatePosted AND Post Then
			
			MessageText = NStr("en = 'The invoice %InvoicePresentation% is posted.'");
			MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Customer invoice note (issued) No " + CurrentDocument.Number + " from " + CurrentDocument.Date + """");
			
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndDo;
	
EndProcedure // SubordinatedInvoicesProcessing()

// Procedure synchronizes the deletion mark for the subordinate invoices.
//
Procedure SynchronizationDeletionMarkInSubordinatedInvoices(MarkToDelete = False)
	
	Query = New Query;
	Query.SetParameter("BasisDocument", Ref);
	Query.SetParameter("DeletionFlag", Not MarkToDelete);
	
	Query.Text =
	"SELECT DISTINCT
	|	Doc.Ref AS Ref
	|FROM
	|	(SELECT
	|		InvoiceBasisDocument.Ref AS Ref
	|	FROM
	|		Document.CustomerInvoiceNote AS InvoiceBasisDocument
	|	WHERE
	|		InvoiceBasisDocument.BasisDocument = &BasisDocument
	|		AND InvoiceBasisDocument.DeletionMark = &DeletionFlag
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InvoiceBasisDocuments.Ref
	|	FROM
	|		Document.CustomerInvoiceNote.BasisDocuments AS InvoiceBasisDocuments
	|	WHERE
	|		InvoiceBasisDocuments.BasisDocument = &BasisDocument
	|		AND InvoiceBasisDocuments.Ref.DeletionMark = &DeletionFlag) AS Doc";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	QueryResult = QueryResult.Unload();
	For Each ResultRow IN QueryResult Do
		CurrentDocument = ResultRow.Ref.GetObject();
		CurrentDocument.Posted = ?(MarkToDelete, False, CurrentDocument.Posted);
		CurrentDocument.DeletionMark = MarkToDelete;
		CurrentDocument.Write();
	EndDo;
	
EndProcedure // SynchronizationDeletionMarkInSubordinatedInvoices()

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
			MessageText = NStr("en = 'Advance by order that is different form specified in the tabular section ""Inventory"" can not be accepted!'");
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
	
	SynchronizationDeletionMarkInSubordinatedInvoices(DeletionMark);
	
	If Not DeletionMark Then
		
		If ValueIsFilled(Ref) Then
			GenerateInvoices();
		Else
			RefNew = GetNewObjectRef();
			If Not ValueIsFilled(RefNew) Then
				RefNew = Documents.AgentReport.GetRef();
			EndIf;
			GenerateInvoices(RefNew);
			SetNewObjectRef(RefNew);
		EndIf;
		
	EndIf;
	
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
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.AgentReport.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	// Subordinate invoice notes.
	If Not Cancel Then
		
		SubordinatedInvoicesProcessing();
		
	EndIf;
	
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
	
	// Subordinate invoice notes.
	If Not Cancel Then
		
		SubordinatedInvoicesProcessing(False);
		
	EndIf;
	
	// Subordinate invoice notes (supplier).
	If Not Cancel Then
		
		ControlOfSubordinatedInvoiceReceived();
		
	EndIf;
	
EndProcedure // UndoPosting()

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	Prepayment.Clear();
	
	// Customer invoice notes for sold products and services
	MakeOutInvoicesCollective = MakeOutInvoicesCollective AND Date >= '20150101';
	
EndProcedure // OnCopy()

#EndIf