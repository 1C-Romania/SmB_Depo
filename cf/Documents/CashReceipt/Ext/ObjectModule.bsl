#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure is filling the payment details.
//
Procedure FillPaymentDetails() Export
	
	Counterparty = SmallBusinessServer.GetCompany(Company);
	
	If VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		DefaultVATRate = Company.DefaultVATRate;
	ElsIf VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
		DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
	Else
		DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
	EndIf;
	
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", CashCurrency));
	
	ExchangeRateCurrenciesDC = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	CurrencyUnitConversionFactor = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.Multiplicity
	);
	
	// Filling default payment details.
	Query = New Query;
	Query.Text =
	
	"SELECT
	|	AccountsReceivableBalances.Company AS Company,
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	CASE
	|		WHEN AccountsReceivableBalances.Counterparty.DoOperationsByDocuments
	|			THEN AccountsReceivableBalances.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN AccountsReceivableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsReceivableBalances.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS Order,
	|	AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS AmountCurBalance,
	|	AccountsReceivableBalances.Document.Date AS DocumentDate,
	|	SUM(CAST(AccountsReceivableBalances.AmountCurBalance * SettlementsCurrencyRates.ExchangeRate * CurrencyRatesOfDocument.Multiplicity / (CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2))) AS AmountCurrDocument,
	|	CurrencyRatesOfDocument.ExchangeRate AS CashAssetsRate,
	|	CurrencyRatesOfDocument.Multiplicity AS CashMultiplicity,
	|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
	|	SettlementsCurrencyRates.Multiplicity AS Multiplicity
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.Company AS Company,
	|		AccountsReceivableBalances.Counterparty AS Counterparty,
	|		AccountsReceivableBalances.Contract AS Contract,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.Order AS Order,
	|		AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					// TextOfContractSelection
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsAccountsReceivable.Company,
	|		DocumentRegisterRecordsAccountsReceivable.Counterparty,
	|		DocumentRegisterRecordsAccountsReceivable.Contract,
	|		DocumentRegisterRecordsAccountsReceivable.Document,
	|		DocumentRegisterRecordsAccountsReceivable.Order,
	|		DocumentRegisterRecordsAccountsReceivable.SettlementsType,
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
	|		AND DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, Currency = &Currency) AS CurrencyRatesOfDocument
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, ) AS SettlementsCurrencyRates
	|		ON AccountsReceivableBalances.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
	|WHERE
	|	AccountsReceivableBalances.AmountCurBalance > 0
	|
	|GROUP BY
	|	AccountsReceivableBalances.Company,
	|	AccountsReceivableBalances.Counterparty,
	|	AccountsReceivableBalances.Contract,
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.SettlementsType,
	|	AccountsReceivableBalances.Document.Date,
	|	CurrencyRatesOfDocument.ExchangeRate,
	|	CurrencyRatesOfDocument.Multiplicity,
	|	SettlementsCurrencyRates.ExchangeRate,
	|	SettlementsCurrencyRates.Multiplicity,
	|	CASE
	|		WHEN AccountsReceivableBalances.Counterparty.DoOperationsByDocuments
	|			THEN AccountsReceivableBalances.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN AccountsReceivableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsReceivableBalances.Order
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END
	|
	|ORDER BY
	|	DocumentDate";
		
	Query.SetParameter("Company", Counterparty);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Period", Date);
	Query.SetParameter("Currency", CashCurrency);
	Query.SetParameter("Ref", Ref);
	
	NeedFilterByContracts = SmallBusinessReUse.CounterpartyContractsControlNeeded();
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Ref, OperationKind);
	If NeedFilterByContracts
	   AND Counterparty.DoOperationsByContracts Then
		Query.Text = StrReplace(Query.Text, "// TextOfContractSelection", "And Contract.ContractType IN (&ContractTypesList)");
		Query.SetParameter("ContractTypesList", ContractTypesList);
	EndIf;
	
	ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
		Counterparty,
		Company,
		ContractTypesList
	);
	
	StructureContractCurrencyRateByDefault = InformationRegisters.CurrencyRates.GetLast(
		Date,
		New Structure("Currency", ContractByDefault.SettlementsCurrency)
	);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	PaymentDetails.Clear();
	
	AmountLeftToDistribute = DocumentAmount;
	
	While AmountLeftToDistribute > 0 Do
		
		NewRow = PaymentDetails.Add();
		
		If SelectionOfQueryResult.Next() Then
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurrDocument <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow.SettlementsAmount = SelectionOfQueryResult.AmountCurBalance;
				NewRow.PaymentAmount = SelectionOfQueryResult.AmountCurrDocument;
				NewRow.VATRate = DefaultVATRate;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.AmountCurrDocument;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow.SettlementsAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
					AmountLeftToDistribute,
					SelectionOfQueryResult.CashAssetsRate,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.CashMultiplicity,
					SelectionOfQueryResult.Multiplicity
				);
				NewRow.PaymentAmount = AmountLeftToDistribute;
				NewRow.VATRate = DefaultVATRate;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
				AmountLeftToDistribute = 0;
				
			EndIf;
			
		Else
			
			NewRow.Contract = ContractByDefault;
			NewRow.ExchangeRate = ?(
				StructureContractCurrencyRateByDefault.ExchangeRate = 0,
				1,
				StructureContractCurrencyRateByDefault.ExchangeRate
			);
			NewRow.Multiplicity = ?(
				StructureContractCurrencyRateByDefault.Multiplicity = 0,
				1,
				StructureContractCurrencyRateByDefault.Multiplicity
			);
			NewRow.SettlementsAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
				AmountLeftToDistribute,
				ExchangeRate,
				NewRow.ExchangeRate,
				Multiplicity,
				NewRow.Multiplicity
			);
			NewRow.AdvanceFlag = True;
			NewRow.PaymentAmount = AmountLeftToDistribute;
			NewRow.VATRate = DefaultVATRate;
			NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
	If PaymentDetails.Count() = 0 Then
		PaymentDetails.Add();
		PaymentDetails[0].PaymentAmount = DocumentAmount;
	EndIf;
	
	PaymentAmount = PaymentDetails.Total("PaymentAmount");
	
EndProcedure // FillPaymentDetails()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByPaymentReceiptPlan(BasisDocument, Amount = Undefined)
	
	Query = New Query;
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Amount", Amount);
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashFlowItem AS Item,
		|	DocumentTable.PettyCash AS PettyCash,
		|	DocumentTable.DocumentCurrency AS CashCurrency,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	&Amount AS DocumentAmount,
		|	&Amount AS PaymentAmount,
		|	DocumentTable.Company.DefaultVATRate AS VATRate,
		|	ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) AS ExchangeRate,
		|	ISNULL(SettlementsCurrencyRates.Multiplicity, 1) AS Multiplicity,
		|	CAST(&Amount * CASE
		|			WHEN DocumentTable.DocumentCurrency <> DocumentTable.Contract.SettlementsCurrency
		|					AND SettlementsCurrencyRates.ExchangeRate <> 0
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(DocumentTable.Company.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.PaymentReceiptPlan AS DocumentTable
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRates
		|		ON DocumentTable.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
		|		ON DocumentTable.DocumentCurrency = CurrencyRatesOfDocument.Currency
		|WHERE
		|	DocumentTable.Ref = &Ref";
		
	Else
		
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashFlowItem AS Item,
		|	DocumentTable.PettyCash AS PettyCash,
		|	DocumentTable.DocumentCurrency AS CashCurrency,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	DocumentTable.DocumentAmount AS DocumentAmount,
		|	DocumentTable.DocumentAmount AS PaymentAmount,
		|	DocumentTable.Company.DefaultVATRate AS VATRate,
		|	ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) AS ExchangeRate,
		|	ISNULL(SettlementsCurrencyRates.Multiplicity, 1) AS Multiplicity,
		|	CAST(DocumentTable.DocumentAmount * CASE
		|			WHEN DocumentTable.DocumentCurrency <> DocumentTable.Contract.SettlementsCurrency
		|					AND SettlementsCurrencyRates.ExchangeRate <> 0
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(DocumentTable.DocumentAmount * (1 - 1 / ((ISNULL(DocumentTable.Company.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.PaymentReceiptPlan AS DocumentTable
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRates
		|		ON DocumentTable.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
		|		ON DocumentTable.DocumentCurrency = CurrencyRatesOfDocument.Currency
		|WHERE
		|	DocumentTable.Ref = &Ref";
		
	EndIf;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
		VATTaxation = SmallBusinessServer.VATTaxation(Company, , Date);
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.AdvanceFlag = True;
		NewRow.PlanningDocument = BasisDocument;
		
		If ValueIsFilled(BasisDocument.BasisDocument)
		   AND TypeOf(BasisDocument.BasisDocument) = Type("DocumentRef.CustomerOrder")
		   AND Counterparty.DoOperationsByOrders Then
			
			NewRow.Order = BasisDocument.BasisDocument;
			
		EndIf;
		
	EndIf;
	
EndProcedure // FillByPaymentReceiptPlan()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByCashTransferPlan(BasisDocument, Amount = Undefined)
	
	If BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.NotApproved Then
		Raise NStr("en='You can not enter the cash register records basing on the unapproved plan document!';ru='Нельзя ввести перемещение денег на основании неутвержденного планового документа!'");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	// Fill document header data.
	Query.Text = 
	"SELECT
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationKindsCashReceipt.Other) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.VATTaxationTypes.TaxableByVAT) AS VATTaxation,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.DocumentCurrency AS CashCurrency,
	|	DocumentTable.PettyCashPayee AS PettyCash,
	|	DocumentTable.DocumentAmount AS DocumentAmount,
	|	DocumentTable.DocumentAmount AS PaymentAmount
	|FROM
	|	Document.CashTransferPlan AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		VATTaxation = SmallBusinessServer.VATTaxation(Company, , Date);
		If Amount <> Undefined Then
			ThisObject.DocumentAmount = Amount;
		EndIf;
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.PlanningDocument = BasisDocument;
		
	EndIf;
	
EndProcedure // FillByCashTransferPlan()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByInvoiceForPayment(FillingData, LineNumber = Undefined, Amount = Undefined)
	
	Query = New Query();
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		Query.SetParameter("Amount", Amount);
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.PettyCash AS PettyCash,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	CASE
		|		WHEN DocumentHeader.BasisDocument = UNDEFINED
		|				OR DocumentHeader.BasisDocument = VALUE(Document.AcceptanceCertificate.EmptyRef)
		|				OR DocumentHeader.BasisDocument = VALUE(Document.CustomerInvoice.EmptyRef)
		|				OR DocumentHeader.BasisDocument = VALUE(Document.ProcessingReport.EmptyRef)
		|				OR VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.CustomerOrder)
		|					AND DocumentHeader.BasisDocument.OperationKind <> VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS AdvanceFlag,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
		|				AND (VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.AcceptanceCertificate)
		|					OR VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.CustomerInvoice)
		|					OR VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.ProcessingReport)
		|					OR VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.CustomerOrder)
		|						AND DocumentHeader.BasisDocument.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder))
		|			THEN DocumentHeader.BasisDocument
		|		ELSE UNDEFINED
		|	END AS Document,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|				AND VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.CustomerOrder)
		|			THEN DocumentHeader.BasisDocument
		|		ELSE UNDEFINED
		|	END AS Order,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.TrackPaymentsByBills
		|			THEN &Ref
		|		ELSE VALUE(Document.InvoiceForPayment.EmptyRef)
		|	END AS InvoiceForPayment,
		|	DocumentTable.VATRate AS VATRate,
		|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
		|	SettlementsCurrencyRates.Multiplicity AS Multiplicity,
		|	&Amount AS DocumentAmount,
		|	&Amount AS PaymentAmount,
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
		|					AND SettlementsCurrencyRates.ExchangeRate <> 0
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.InvoiceForPayment AS DocumentHeader
		|		LEFT JOIN Document.InvoiceForPayment.Inventory AS DocumentTable
		|		ON DocumentHeader.Ref = DocumentTable.Ref
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRates
		|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
		|		ON DocumentHeader.DocumentCurrency = CurrencyRatesOfDocument.Currency
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|	AND ISNULL(DocumentTable.LineNumber, 1) = 1";
		
	ElsIf LineNumber = Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.PettyCash AS PettyCash,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	CASE
		|		WHEN DocumentHeader.BasisDocument = UNDEFINED
		|				OR DocumentHeader.BasisDocument = VALUE(Document.AcceptanceCertificate.EmptyRef)
		|				OR DocumentHeader.BasisDocument = VALUE(Document.CustomerInvoice.EmptyRef)
		|				OR DocumentHeader.BasisDocument = VALUE(Document.ProcessingReport.EmptyRef)
		|				OR VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.CustomerOrder)
		|					AND DocumentHeader.BasisDocument.OperationKind <> VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS AdvanceFlag,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
		|				AND (VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.AcceptanceCertificate)
		|					OR VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.CustomerInvoice)
		|					OR VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.ProcessingReport)
		|					OR VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.CustomerOrder)
		|						AND DocumentHeader.BasisDocument.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder))
		|			THEN DocumentHeader.BasisDocument
		|		ELSE UNDEFINED
		|	END AS Document,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|				AND VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.CustomerOrder)
		|			THEN DocumentHeader.BasisDocument
		|		ELSE UNDEFINED
		|	END AS Order,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.TrackPaymentsByBills
		|			THEN &Ref
		|		ELSE VALUE(Document.InvoiceForPayment.EmptyRef)
		|	END AS InvoiceForPayment,
		|	DocumentTable.VATRate AS VATRate,
		|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
		|	SettlementsCurrencyRates.Multiplicity AS Multiplicity,
		|	SUM(DocumentTable.Total) AS DocumentAmount,
		|	SUM(DocumentTable.Total) AS PaymentAmount,
		|	SUM(CAST(DocumentTable.Total * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
		|						AND SettlementsCurrencyRates.ExchangeRate <> 0
		|						AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS SettlementsAmount,
		|	SUM(CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2))) AS VATAmount
		|FROM
		|	Document.InvoiceForPayment AS DocumentHeader
		|		LEFT JOIN Document.InvoiceForPayment.Inventory AS DocumentTable
		|		ON DocumentHeader.Ref = DocumentTable.Ref
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRates
		|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
		|		ON DocumentHeader.DocumentCurrency = CurrencyRatesOfDocument.Currency
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|
		|GROUP BY
		|	DocumentHeader.Company,
		|	DocumentHeader.VATTaxation,
		|	DocumentHeader.DocumentCurrency,
		|	DocumentHeader.PettyCash,
		|	DocumentHeader.Counterparty,
		|	DocumentHeader.Contract,
		|	DocumentHeader.BasisDocument,
		|	DocumentTable.VATRate,
		|	SettlementsCurrencyRates.ExchangeRate,
		|	SettlementsCurrencyRates.Multiplicity,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
		|			THEN DocumentHeader.BasisDocument
		|		ELSE UNDEFINED
		|	END,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.TrackPaymentsByBills
		|			THEN &Ref
		|		ELSE VALUE(Document.InvoiceForPayment.EmptyRef)
		|	END,
		|	CASE
		|		WHEN DocumentHeader.BasisDocument = UNDEFINED
		|				OR DocumentHeader.BasisDocument = VALUE(Document.AcceptanceCertificate.EmptyRef)
		|				OR DocumentHeader.BasisDocument = VALUE(Document.CustomerInvoice.EmptyRef)
		|				OR DocumentHeader.BasisDocument = VALUE(Document.ProcessingReport.EmptyRef)
		|				OR VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.CustomerOrder)
		|					AND DocumentHeader.BasisDocument.OperationKind <> VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|			THEN TRUE
		|		ELSE FALSE
		|	END,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
		|				AND (VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.AcceptanceCertificate)
		|					OR VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.CustomerInvoice)
		|					OR VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.ProcessingReport)
		|					OR VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.CustomerOrder)
		|						AND DocumentHeader.BasisDocument.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder))
		|			THEN DocumentHeader.BasisDocument
		|		ELSE UNDEFINED
		|	END,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|				AND VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.CustomerOrder)
		|			THEN DocumentHeader.BasisDocument
		|		ELSE UNDEFINED
		|	END";
		
	Else
	
		Query.SetParameter("Ref", FillingData.Basis);
		Query.SetParameter("LineNumber", LineNumber);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill document header data.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Ref.Company AS Company,
		|	DocumentTable.Ref.VATTaxation AS VATTaxation,
		|	DocumentTable.Ref.DocumentCurrency AS CashCurrency,
		|	DocumentTable.Ref.PettyCash AS PettyCash,
		|	DocumentTable.Ref.Counterparty AS Counterparty,
		|	DocumentTable.Ref.Contract AS Contract,
		|	CASE
		|		WHEN DocumentTable.Ref.BasisDocument = UNDEFINED
		|				OR DocumentTable.Ref.BasisDocument = VALUE(Document.AcceptanceCertificate.EmptyRef)
		|				OR DocumentTable.Ref.BasisDocument = VALUE(Document.CustomerInvoice.EmptyRef)
		|				OR DocumentTable.Ref.BasisDocument = VALUE(Document.ProcessingReport.EmptyRef)
		|				OR VALUETYPE(DocumentTable.Ref.BasisDocument) = Type(Document.CustomerOrder)
		|					AND DocumentTable.Ref.BasisDocument.OperationKind <> VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS AdvanceFlag,
		|	CASE
		|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
		|				AND (VALUETYPE(DocumentTable.Ref.BasisDocument) = Type(Document.AcceptanceCertificate)
		|					OR VALUETYPE(DocumentTable.Ref.BasisDocument) = Type(Document.CustomerInvoice)
		|					OR VALUETYPE(DocumentTable.Ref.BasisDocument) = Type(Document.ProcessingReport)
		|					OR VALUETYPE(DocumentTable.Ref.BasisDocument) = Type(Document.CustomerOrder)
		|						AND DocumentTable.Ref.BasisDocument.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder))
		|			THEN DocumentTable.Ref.BasisDocument
		|		ELSE UNDEFINED
		|	END AS Document,
		|	CASE
		|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByOrders
		|				AND VALUETYPE(DocumentTable.Ref.BasisDocument) = Type(Document.CustomerOrder)
		|			THEN DocumentTable.Ref.BasisDocument
		|		ELSE UNDEFINED
		|	END AS Order,
		|	CASE
		|		WHEN DocumentTable.Ref.Counterparty.TrackPaymentsByBills
		|			THEN DocumentTable.Ref
		|		ELSE VALUE(Document.InvoiceForPayment.EmptyRef)
		|	END AS InvoiceForPayment,
		|	ISNULL(VATRatesDocumentsTable.VATRate, VATRates.VATRate) AS VATRate,
		|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
		|	SettlementsCurrencyRates.Multiplicity AS Multiplicity,
		|	DocumentTable.PaymentAmount AS DocumentAmount,
		|	DocumentTable.PaymentAmount AS PaymentAmount,
		|	CAST(DocumentTable.PaymentAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> DocumentTable.Ref.Contract.SettlementsCurrency
		|					AND SettlementsCurrencyRates.ExchangeRate <> 0
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(DocumentTable.PaymentAmount * (1 - 1 / ((ISNULL(VATRates.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.InvoiceForPayment.PaymentCalendar AS DocumentTable
		|		LEFT JOIN (SELECT TOP 1
		|			VATRates.Ref AS VATRate
		|		FROM
		|			Catalog.VATRates AS VATRates
		|		WHERE
		|			VATRates.Rate = 18
		|			AND VATRates.DeletionMark = FALSE
		|			AND VATRates.Calculated = FALSE) AS VATRates
		|		ON (TRUE)
		|		LEFT JOIN (SELECT TOP 1
		|			DocumentTable.Ref AS Ref,
		|			DocumentTable.VATRate AS VATRate
		|		FROM
		|			Document.InvoiceForPayment.Inventory AS DocumentTable
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS VATRatesDocumentsTable
		|		ON DocumentTable.Ref = VATRatesDocumentsTable.Ref
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRates
		|		ON DocumentTable.Ref.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
		|		ON DocumentTable.Ref.DocumentCurrency = CurrencyRatesOfDocument.Currency
		|WHERE
		|	DocumentTable.Ref = &Ref
		|	AND DocumentTable.LineNumber = &LineNumber";
		
	EndIf;
	
	Selection = Query.Execute().Select();
	PaymentDetails.Clear();
	
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		
		If Not VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
EndProcedure // FillByInvoiceForPayment()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByCustomerOrder(FillingData, LineNumber = Undefined, Amount = Undefined)
	
	Query = New Query();
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		Query.SetParameter("Amount", Amount);
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.PettyCash AS PettyCash,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	CASE
		|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|				AND DocumentHeader.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS AdvanceFlag,
		|	CASE
		|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|				AND DocumentHeader.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|				AND DocumentHeader.Counterparty.DoOperationsByDocuments
		|			THEN &Ref
		|		ELSE UNDEFINED
		|	END AS Document,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
		|	END AS Order,
		|	DocumentTable.VATRate AS VATRate,
		|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
		|	SettlementsCurrencyRates.Multiplicity AS Multiplicity,
		|	&Amount AS DocumentAmount,
		|	&Amount AS PaymentAmount,
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
		|					AND SettlementsCurrencyRates.ExchangeRate <> 0
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.CustomerOrder AS DocumentHeader
		|		LEFT JOIN Document.CustomerOrder.Inventory AS DocumentTable
		|		ON DocumentHeader.Ref = DocumentTable.Ref
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRates
		|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
		|		ON DocumentHeader.DocumentCurrency = CurrencyRatesOfDocument.Currency
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|	AND ISNULL(DocumentTable.LineNumber, 1) = 1";
		
	ElsIf LineNumber = Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.PettyCash AS PettyCash,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	CASE
		|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|				AND DocumentHeader.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS AdvanceFlag,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
		|	END AS Order,
		|	NestedSelect.VATRate AS VATRate,
		|	ISNULL(NestedSelect.ExchangeRate, 1) AS ExchangeRate,
		|	ISNULL(NestedSelect.Multiplicity, 1) AS Multiplicity,
		|	SUM(NestedSelect.DocumentAmount) AS DocumentAmount,
		|	SUM(NestedSelect.PaymentAmount) AS PaymentAmount,
		|	SUM(NestedSelect.SettlementsAmount) AS SettlementsAmount,
		|	SUM(NestedSelect.VATAmount) AS VATAmount,
		|	CASE
		|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|				AND DocumentHeader.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|				AND DocumentHeader.Counterparty.DoOperationsByDocuments
		|			THEN &Ref
		|		ELSE UNDEFINED
		|	END AS Document
		|FROM
		|	Document.CustomerOrder AS DocumentHeader
		|		LEFT JOIN (SELECT
		|			&Ref AS BasisDocument,
		|			DocumentTable.VATRate AS VATRate,
		|			SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
		|			SettlementsCurrencyRates.Multiplicity AS Multiplicity,
		|			DocumentTable.Total AS DocumentAmount,
		|			DocumentTable.Total AS PaymentAmount,
		|			CAST(DocumentTable.Total * CASE
		|					WHEN DocumentTable.Ref.DocumentCurrency <> DocumentTable.Ref.Contract.SettlementsCurrency
		|							AND SettlementsCurrencyRates.ExchangeRate <> 0
		|							AND CurrencyRatesOfDocument.Multiplicity <> 0
		|						THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|					ELSE 1
		|				END AS NUMBER(15, 2)) AS SettlementsAmount,
		|			CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|		FROM
		|			Document.CustomerOrder.Inventory AS DocumentTable
		|				LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRates
		|				ON DocumentTable.Ref.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
		|				LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
		|				ON DocumentTable.Ref.DocumentCurrency = CurrencyRatesOfDocument.Currency
		|		WHERE
		|			DocumentTable.Ref = &Ref
		|		
		|		UNION ALL
		|		
		|		SELECT
		|			&Ref,
		|			DocumentTable.VATRate,
		|			SettlementsCurrencyRates.ExchangeRate,
		|			SettlementsCurrencyRates.Multiplicity,
		|			DocumentTable.Total,
		|			DocumentTable.Total,
		|			CAST(DocumentTable.Total * CASE
		|					WHEN DocumentTable.Ref.DocumentCurrency <> DocumentTable.Ref.Contract.SettlementsCurrency
		|							AND SettlementsCurrencyRates.ExchangeRate <> 0
		|							AND CurrencyRatesOfDocument.Multiplicity <> 0
		|						THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|					ELSE 1
		|				END AS NUMBER(15, 2)),
		|			CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2))
		|		FROM
		|			Document.CustomerOrder.Works AS DocumentTable
		|				LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRates
		|				ON DocumentTable.Ref.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
		|				LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
		|				ON DocumentTable.Ref.DocumentCurrency = CurrencyRatesOfDocument.Currency
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS NestedSelect
		|		ON DocumentHeader.Ref = NestedSelect.BasisDocument
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|
		|GROUP BY
		|	DocumentHeader.Company,
		|	DocumentHeader.VATTaxation,
		|	DocumentHeader.DocumentCurrency,
		|	DocumentHeader.PettyCash,
		|	DocumentHeader.Counterparty,
		|	DocumentHeader.Contract,
		|	NestedSelect.VATRate,
		|	NestedSelect.ExchangeRate,
		|	NestedSelect.Multiplicity,
		|	CASE
		|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|				AND DocumentHeader.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|			THEN FALSE
		|		ELSE TRUE
		|	END,
		|	CASE
		|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|				AND DocumentHeader.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|				AND DocumentHeader.Counterparty.DoOperationsByDocuments
		|			THEN &Ref
		|		ELSE UNDEFINED
		|	END,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
		|	END";
		
	Else
	
		Query.SetParameter("Ref", FillingData.Basis);
		Query.SetParameter("LineNumber", LineNumber);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill document header data.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Ref.Company AS Company,
		|	DocumentTable.Ref.VATTaxation AS VATTaxation,
		|	DocumentTable.Ref.DocumentCurrency AS CashCurrency,
		|	DocumentTable.Ref.PettyCash AS PettyCash,
		|	DocumentTable.Ref.Counterparty AS Counterparty,
		|	DocumentTable.Ref.Contract AS Contract,
		|	CASE
		|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|				AND DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS AdvanceFlag,
		|	ISNULL(VATRatesDocumentsTable.VATRate, VATRates.VATRate) AS VATRate,
		|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
		|	SettlementsCurrencyRates.Multiplicity AS Multiplicity,
		|	DocumentTable.PaymentAmount AS DocumentAmount,
		|	DocumentTable.PaymentAmount AS PaymentAmount,
		|	CAST(DocumentTable.PaymentAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> DocumentTable.Ref.Contract.SettlementsCurrency
		|					AND SettlementsCurrencyRates.ExchangeRate <> 0
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(DocumentTable.PaymentAmount * (1 - 1 / ((ISNULL(VATRates.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount,
		|	CASE
		|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
		|	END AS Order,
		|	CASE
		|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|				AND DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|				AND DocumentTable.Ref.Counterparty.DoOperationsByDocuments
		|			THEN &Ref
		|		ELSE UNDEFINED
		|	END AS Document
		|FROM
		|	Document.CustomerOrder.PaymentCalendar AS DocumentTable
		|		LEFT JOIN (SELECT TOP 1
		|			VATRates.Ref AS VATRate
		|		FROM
		|			Catalog.VATRates AS VATRates
		|		WHERE
		|			VATRates.Rate = 18
		|			AND VATRates.DeletionMark = FALSE
		|			AND VATRates.Calculated = FALSE) AS VATRates
		|		ON (TRUE)
		|		LEFT JOIN (SELECT TOP 1
		|			VATRatesDocumentsTable.Ref AS Ref,
		|			VATRatesDocumentsTable.VATRate AS VATRate
		|		FROM
		|			(SELECT TOP 1
		|				DocumentTable.Ref AS Ref,
		|				DocumentTable.VATRate AS VATRate
		|			FROM
		|				Document.CustomerOrder.Inventory AS DocumentTable
		|			WHERE
		|				DocumentTable.Ref = &Ref
			
		|			UNION ALL
			
		|			SELECT TOP 1
		|				DocumentTable.Ref,
		|				DocumentTable.VATRate
		|			FROM
		|				Document.CustomerOrder.Works AS DocumentTable
		|			WHERE
		|				DocumentTable.Ref = &Ref) AS VATRatesDocumentsTable) AS VATRatesDocumentsTable
		|		ON DocumentTable.Ref = VATRatesDocumentsTable.Ref
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRates
		|		ON DocumentTable.Ref.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
		|		ON DocumentTable.Ref.DocumentCurrency = CurrencyRatesOfDocument.Currency
		|WHERE
		|	DocumentTable.Ref = &Ref
		|	AND DocumentTable.LineNumber = &LineNumber";
		
	EndIf;
	
	Selection = Query.Execute().Select();
	PaymentDetails.Clear();
	
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		
		If Not VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
EndProcedure // FillByCustomerOrder()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//
Procedure FillByCustomerOrderDependOnBalanceForPayment(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	Query.Text =
	"SELECT
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Date AS Date,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.PettyCash AS PettyCash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|				AND DocumentHeader.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS AdvanceFlag,
	|	NestedSelect.VATRate AS VATRate,
	|	ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(SettlementsCurrencyRates.Multiplicity, 1) AS Multiplicity,
	|	InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover AS DocumentAmount,
	|	InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover AS PaymentAmount,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * CASE
	|			WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
	|					AND SettlementsCurrencyRates.ExchangeRate <> 0
	|					AND CurrencyRatesOfDocument.Multiplicity <> 0
	|				THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
	|			ELSE 1
	|		END AS NUMBER(15, 2)) AS SettlementsAmount,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * (1 - 1 / ((ISNULL(NestedSelect.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN &Ref
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS Order,
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|				AND DocumentHeader.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document
	|FROM
	|	Document.CustomerOrder AS DocumentHeader
	|		LEFT JOIN (SELECT TOP 1
	|			VATRatesDocumentsTable.Ref AS Ref,
	|			VATRatesDocumentsTable.VATRate AS VATRate
	|		FROM
	|			(SELECT TOP 1
	|				&Ref AS Ref,
	|				DocumentTable.VATRate AS VATRate
	|			FROM
	|				Document.CustomerOrder.Inventory AS DocumentTable
	|			WHERE
	|				DocumentTable.Ref = &Ref
			
	|			UNION ALL
			
	|			SELECT TOP 1
	|				DocumentTable.Ref,
	|				DocumentTable.VATRate
	|			FROM
	|				Document.CustomerOrder.Works AS DocumentTable
	|			WHERE
	|				DocumentTable.Ref = &Ref) AS VATRatesDocumentsTable) AS NestedSelect
	|		ON DocumentHeader.Ref = NestedSelect.Ref
	|		LEFT JOIN AccumulationRegister.InvoicesAndOrdersPayment.Turnovers AS InvoicesAndOrdersPaymentTurnovers
	|		ON DocumentHeader.Ref = InvoicesAndOrdersPaymentTurnovers.InvoiceForPayment
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRates
	|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
	|		ON DocumentHeader.DocumentCurrency = CurrencyRatesOfDocument.Currency
	|WHERE
	|	DocumentHeader.Ref = &Ref";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		
		If Not VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
EndProcedure // FillByCustomerOrderDependOnBalanceForPayment()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillBySalesInvoice(FillingData)
	
	If FillingData.OperationKind = Enums.OperationKindsCustomerInvoice.TransferToProcessing Then
		ErrorMessage = NStr("en='Cannot enter a document based on the operation - ""%OperationKind""';ru='Невозможен ввод документа на основании операции - ""%ВидОперации""!'");
		ErrorMessage = StrReplace(ErrorMessage, "%OperationKind", FillingData.OperationKind);
		Raise ErrorMessage;
	EndIf;
	
	Query = New Query;
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN VALUE(Enum.OperationKindsCashReceipt.FromVendor)
	|		ELSE VALUE(Enum.OperationKindsCashReceipt.FromCustomer)
	|	END AS OperationKind,
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|	END AS Item,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	PRESENTATION(DocumentHeader.Counterparty) AS AcceptedFrom,
	|	DocumentHeader.Company.PettyCashByDefault AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE CASE
	|				WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|					THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|				ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|			END
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	SUM(ISNULL(CAST(DocumentTable.Total * CASE
	|					WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN RegCurrenciesRates.ExchangeRate * DocumentHeader.Multiplicity / (DocumentHeader.ExchangeRate * ISNULL(RegCurrenciesRates.Multiplicity, 1))
	|					ELSE 1
	|				END AS NUMBER(15, 2)), 0)) AS SettlementsAmount,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.ExchangeRate
	|		ELSE SettlementsCurrencyRatesSliceLast.ExchangeRate
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.Multiplicity
	|		ELSE SettlementsCurrencyRatesSliceLast.Multiplicity
	|	END AS Multiplicity,
	|	SUM(ISNULL(DocumentTable.Total, 0)) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(ISNULL(DocumentTable.VATAmount, 0)) AS VATAmount
	|FROM
	|	Document.CustomerInvoice AS DocumentHeader
	|		LEFT JOIN Document.CustomerInvoice.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&Date,
	|				Currency In
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.NationalCurrency AS ConstantNationalCurrency)) AS RegCurrenciesRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRatesSliceLast
	|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsCurrencyRatesSliceLast.Currency,
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN VALUE(Enum.OperationKindsCashReceipt.FromVendor)
	|		ELSE VALUE(Enum.OperationKindsCashReceipt.FromCustomer)
	|	END,
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|	END,
	|	DocumentHeader.Company,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Company.PettyCashByDefault,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.DocumentCurrency,
	|	DocumentTable.Order,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.ExchangeRate
	|		ELSE SettlementsCurrencyRatesSliceLast.ExchangeRate
	|	END,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.Multiplicity
	|		ELSE SettlementsCurrencyRatesSliceLast.Multiplicity
	|	END,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE CASE
	|				WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|					THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|				ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|			END
	|	END";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		ThisObject.DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			ThisObject.DocumentAmount = ThisObject.DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
	EndIf;
	
EndProcedure // FillBySalesInvoice()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByAcceptanceCertificate(FillingData)
	
	Query = New Query;
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	PRESENTATION(DocumentHeader.Counterparty) AS AcceptedFrom,
	|	DocumentHeader.Company.PettyCashByDefault AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentTable.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	SUM(ISNULL(CAST(DocumentTable.Total * CASE
	|					WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN RegCurrenciesRates.ExchangeRate * DocumentHeader.Multiplicity / (DocumentHeader.ExchangeRate * ISNULL(RegCurrenciesRates.Multiplicity, 1))
	|					ELSE 1
	|				END AS NUMBER(15, 2)), 0)) AS SettlementsAmount,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.ExchangeRate
	|		ELSE SettlementsCurrencyRatesSliceLast.ExchangeRate
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.Multiplicity
	|		ELSE SettlementsCurrencyRatesSliceLast.Multiplicity
	|	END AS Multiplicity,
	|	SUM(ISNULL(DocumentTable.Total, 0)) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(ISNULL(DocumentTable.VATAmount, 0)) AS VATAmount
	|FROM
	|	Document.AcceptanceCertificate AS DocumentHeader
	|		LEFT JOIN Document.AcceptanceCertificate.WorksAndServices AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&Date,
	|				Currency In
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.NationalCurrency AS ConstantNationalCurrency)) AS RegCurrenciesRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRatesSliceLast
	|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsCurrencyRatesSliceLast.Currency,
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Company.PettyCashByDefault,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.DocumentCurrency,
	|	DocumentTable.CustomerOrder,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.ExchangeRate
	|		ELSE SettlementsCurrencyRatesSliceLast.ExchangeRate
	|	END,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.Multiplicity
	|		ELSE SettlementsCurrencyRatesSliceLast.Multiplicity
	|	END,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentTable.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		ThisObject.DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			ThisObject.DocumentAmount = ThisObject.DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
	EndIf;
	
EndProcedure // FillByAcceptanceCertificate()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssetsTransfer(FillingData)
	
	Query = New Query;
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	PRESENTATION(DocumentHeader.Counterparty) AS AcceptedFrom,
	|	DocumentHeader.Company.PettyCashByDefault AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	SUM(ISNULL(CAST(DocumentTable.Total * CASE
	|					WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN RegCurrenciesRates.ExchangeRate * DocumentHeader.Multiplicity / (DocumentHeader.ExchangeRate * ISNULL(RegCurrenciesRates.Multiplicity, 1))
	|					ELSE 1
	|				END AS NUMBER(15, 2)), 0)) AS SettlementsAmount,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.ExchangeRate
	|		ELSE SettlementsCurrencyRatesSliceLast.ExchangeRate
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.Multiplicity
	|		ELSE SettlementsCurrencyRatesSliceLast.Multiplicity
	|	END AS Multiplicity,
	|	SUM(ISNULL(DocumentTable.Total, 0)) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(ISNULL(DocumentTable.VATAmount, 0)) AS VATAmount
	|FROM
	|	Document.FixedAssetsTransfer AS DocumentHeader
	|		LEFT JOIN Document.FixedAssetsTransfer.FixedAssets AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&Date,
	|				Currency In
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.NationalCurrency AS ConstantNationalCurrency)) AS RegCurrenciesRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRatesSliceLast
	|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsCurrencyRatesSliceLast.Currency,
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Company.PettyCashByDefault,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.DocumentCurrency,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.ExchangeRate
	|		ELSE SettlementsCurrencyRatesSliceLast.ExchangeRate
	|	END,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.Multiplicity
	|		ELSE SettlementsCurrencyRatesSliceLast.Multiplicity
	|	END,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		ThisObject.DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			ThisObject.DocumentAmount = ThisObject.DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
	EndIf;
	
EndProcedure // FillByFixedAssetsTransfer()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByRetailReport(FillingData)
	
	Query = New Query;
	
	Query.SetParameter("Ref", FillingData);
	
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.RetailIncome) AS OperationKind,
	|	SUM(ISNULL(DocumentTable.Total, 0)) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(ISNULL(DocumentTable.VATAmount, 0)) AS VATAmount,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CashCR AS CashCR,
	|	DocumentHeader.Item AS Item,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	&Ref AS BasisDocument
	|FROM
	|	Document.RetailReport AS DocumentHeader
	|		LEFT JOIN Document.RetailReport.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.VATRate,
	|	DocumentHeader.Company,
	|	DocumentHeader.CashCR,
	|	DocumentHeader.Item,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.DocumentCurrency";
	
	QueryResult = Query.Execute();
	
	AmountLeftToDistribute = FillingData.PaymentWithPaymentCards.Total("Amount");
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		PaymentDetails.Clear();
		
		If Selection.PaymentAmount - AmountLeftToDistribute > 0 Then
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			NewRow.PaymentAmount = Selection.PaymentAmount - AmountLeftToDistribute;
			NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((NewRow.VATRate.Rate + 100) / 100);
			ThisObject.DocumentAmount = Selection.PaymentAmount - AmountLeftToDistribute;
			AmountLeftToDistribute = 0;
		Else
			AmountLeftToDistribute = AmountLeftToDistribute - Selection.PaymentAmount;
		EndIf;
		
		While Selection.Next() Do
			If Selection.PaymentAmount - AmountLeftToDistribute > 0 Then
				NewRow = PaymentDetails.Add();
				FillPropertyValues(NewRow, Selection);
				NewRow.PaymentAmount = Selection.PaymentAmount - AmountLeftToDistribute;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((NewRow.VATRate.Rate + 100) / 100);
				ThisObject.DocumentAmount = ThisObject.DocumentAmount + Selection.PaymentAmount - AmountLeftToDistribute;
				AmountLeftToDistribute = 0;
			Else
				AmountLeftToDistribute = AmountLeftToDistribute - Selection.PaymentAmount;
			EndIf;
		EndDo;
		
		If PaymentDetails.Count() = 0 Then
			PaymentDetails.Add();
		EndIf;
		
	EndIf;
	
EndProcedure // FillByRetailReport()

// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
Procedure FillVATRateByVATTaxation(TabularSectionRow)
	
	If VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
		TabularSectionRow.VATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
		TabularSectionRow.VATAmount = 0;
	ElsIf VATTaxation = Enums.VATTaxationTypes.ForExport Then
		TabularSectionRow.VATRate = SmallBusinessReUse.GetVATRateZero();
		TabularSectionRow.VATAmount = 0;
	EndIf;
	
EndProcedure // FillVATRateByVATTaxation()	

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - handler of the OnCopy event.
//
Procedure OnCopy(CopiedObject)
	
	ReceiptCRNumber = "";
	
EndProcedure // OnCopy()

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Constants.FunctionalOptionAccountingByMultipleBusinessActivities.Get() Then
		
		If OperationKind = Enums.OperationKindsCashReceipt.RetailIncomeAccrualAccounting Then
			
			BusinessActivity = Catalogs.BusinessActivities.MainActivity;
			
		EndIf;
		
	EndIf;
	
	For Each TSRow IN PaymentDetails Do
		If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = Counterparty.ContractByDefault;
		EndIf;
		
		// Other settlements
		If (OperationKind = Enums.OperationKindsCashReceipt.OtherSettlements)
			And TSRow.VATRate.IsEmpty() Then
			TSRow.VATRate	= SmallBusinessReUse.GetVATRateWithoutVAT();
			TSRow.VATAmount	= 0;
		EndIf;
		// End Other settlements
	EndDo;
	
EndProcedure // BeforeWrite()

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.InvoiceForPayment") Then
		FillByInvoiceForPayment(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PaymentReceiptPlan") Then
		FillByPaymentReceiptPlan(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CashTransferPlan") Then
		FillByCashTransferPlan(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerInvoice") Then
		FillBySalesInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.RetailReport") Then
		FillByRetailReport(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AcceptanceCertificate") Then
		FillByAcceptanceCertificate(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.FixedAssetsTransfer") Then
		FillByFixedAssetsTransfer(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
		FillByCustomerOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure")
			AND FillingData.Property("Basis") Then
		If FillingData.Property("ConsiderBalances") 
			AND TypeOf(FillingData.Basis)= Type("DocumentRef.CustomerOrder") Then
			FillByCustomerOrderDependOnBalanceForPayment(FillingData.Basis);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.InvoiceForPayment") Then
			FillByInvoiceForPayment(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.CustomerOrder") Then
			FillByCustomerOrder(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.PaymentReceiptPlan") Then
			FillByPaymentReceiptPlan(FillingData.Document, FillingData.Amount);
		EndIf;
	ElsIf TypeOf(FillingData) = Type("Structure")
			AND FillingData.Property("Document") Then
		If TypeOf(FillingData.Document) = Type("DocumentRef.InvoiceForPayment") Then
			FillByInvoiceForPayment(FillingData.Document, Undefined, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.CustomerOrder") Then
			FillByCustomerOrder(FillingData.Document, Undefined, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.PaymentReceiptPlan") Then
			FillByPaymentReceiptPlan(FillingData.Document, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.CashTransferPlan") Then
			FillByCashTransferPlan(FillingData.Document, FillingData.Amount);
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(AcceptedFrom)
	      AND ValueIsFilled(Counterparty)
	      AND (OperationKind = Enums.OperationKindsCashReceipt.FromCustomer
	     OR OperationKind = Enums.OperationKindsCashReceipt.FromVendor) Then
			
			AcceptedFrom = ?(Counterparty.DescriptionFull = "", Counterparty.Description, Counterparty.DescriptionFull);
			
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Deletion of verifiable attributes from the structure depending
	// on the operation type.
	If OperationKind = Enums.OperationKindsCashReceipt.FromVendor
	 OR OperationKind = Enums.OperationKindsCashReceipt.FromCustomer Then
	 
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessActivity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		
		If Counterparty.DoOperationsByDocuments Then
			For Each RowPaymentDetails IN PaymentDetails Do
				If Not ValueIsFilled(RowPaymentDetails.Document)
					AND (OperationKind = Enums.OperationKindsCashReceipt.FromVendor
				   OR (OperationKind = Enums.OperationKindsCashReceipt.FromCustomer
				   AND Not RowPaymentDetails.AdvanceFlag)) Then
					If PaymentDetails.Count() = 1 Then
						If OperationKind = Enums.OperationKindsCashReceipt.FromCustomer Then
							MessageText = NStr("en='Specify the shipment document or the advance payment sign.';ru='Укажите документ отгрузки или признак аванса платежа.'");
						Else
							MessageText = NStr("en='Specify the settlements document.';ru='Укажите документ расчетов.'");
						EndIf;
					Else
						If OperationKind = Enums.OperationKindsCashReceipt.FromCustomer Then
							MessageText = NStr("en='Specify the shipment document or payment flag in the %LineNumber% row of the ""Payment details"" list.';ru='Укажите документ отгрузки или признак оплаты в строке %НомерСтроки% списка ""Расшифровка платежа"".'");
						Else
							MessageText = NStr("en='Specify the payment document in the row %LineNumber% of the list ""Payment details"".';ru='Укажите документ расчетов в строке %НомерСтроки% списка ""Расшифровка платежа"".'");
						EndIf;
						MessageText = StrReplace(MessageText, "%LineNumber%", String(RowPaymentDetails.LineNumber));
					EndIf;
					SmallBusinessServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"PaymentDetails",
						RowPaymentDetails.LineNumber,
						"Document",
						Cancel
					);
				EndIf;
			EndDo;
		EndIf;
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en='Document amount: %DocumentAmount% %CashCurrency% does not correspond to the posted payments in the tabular section: %PaymentAmount% %CashCurrency%!';ru='Сумма документа: %СуммаДокумента% %ВалютаДенежныхСредств%, не соответствует сумме разнесенных платежей в табличной части: %СуммаПлатежа% %ВалютаДенежныхСредств%!'");
			MessageText = StrReplace(MessageText, "%DocumentAmount%", String(DocumentAmount));
			MessageText = StrReplace(MessageText, "%PaymentAmount%", String(PaymentAmount));
			MessageText = StrReplace(MessageText, "%CashCurrency%", TrimAll(String(CashCurrency)));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel
			);
		EndIf;
		
		If Not Counterparty.DoOperationsByContracts Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		EndIf;
		
	ElsIf OperationKind = Enums.OperationKindsCashReceipt.FromAdvanceHolder Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessActivity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.UnitConversionFactor");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		
	ElsIf OperationKind = Enums.OperationKindsCashReceipt.RetailIncome Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessActivity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.UnitConversionFactor");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en='Document amount: %DocumentAmount% %CashCurrency% does not correspond to the posted payments in the tabular section: %PaymentAmount% %CashCurrency%!';ru='Сумма документа: %СуммаДокумента% %ВалютаДенежныхСредств%, не соответствует сумме разнесенных платежей в табличной части: %СуммаПлатежа% %ВалютаДенежныхСредств%!'");
			MessageText = StrReplace(MessageText, "%DocumentAmount%", String(DocumentAmount));
			MessageText = StrReplace(MessageText, "%PaymentAmount%", String(PaymentAmount));
			MessageText = StrReplace(MessageText, "%CashCurrency%", TrimAll(String(CashCurrency)));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel
			);
		EndIf;
		
	ElsIf OperationKind = Enums.OperationKindsCashReceipt.RetailIncomeAccrualAccounting Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.UnitConversionFactor");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en='Document amount: %DocumentAmount% %CashCurrency% does not correspond to the posted payments in the tabular section: %PaymentAmount% %CashCurrency%!';ru='Сумма документа: %СуммаДокумента% %ВалютаДенежныхСредств%, не соответствует сумме разнесенных платежей в табличной части: %СуммаПлатежа% %ВалютаДенежныхСредств%!'");
			MessageText = StrReplace(MessageText, "%DocumentAmount%", String(DocumentAmount));
			MessageText = StrReplace(MessageText, "%PaymentAmount%", String(PaymentAmount));
			MessageText = StrReplace(MessageText, "%CashCurrency%", TrimAll(String(CashCurrency)));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel
			);
		EndIf;
		
	ElsIf OperationKind = Enums.OperationKindsCashReceipt.Other Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessActivity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.UnitConversionFactor");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		
	ElsIf OperationKind = Enums.OperationKindsCashReceipt.CurrencyPurchase Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessActivity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.UnitConversionFactor");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		
	// Other settlements
	ElsIf OperationKind = Enums.OperationKindsCashReceipt.OtherSettlements Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessActivity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("ru = 'Сумма документа: %DocumentAmount% %CashCurrency%, не соответствует сумме разнесенных платежей в табличной части: %PaymentAmount% %CashCurrency%!'; en = 'Document amount: %DocumentAmount% %CashCurrency% does not match with the posted payments in the tabular section:  %PaymentAmount% %CashCurrency%!'");
			MessageText = StrReplace(MessageText, "%DocumentAmount%", String(DocumentAmount));
			MessageText = StrReplace(MessageText, "%PaymentAmount%", String(PaymentAmount));
			MessageText = StrReplace(MessageText, "%CashCurrency%", String(Строка(CashCurrency)));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel
			);
		EndIf;
		
	// End Other settlements	
	EndIf;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.CashReceipt.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectCashAssetsInCashRegisters(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAdvanceHolderPayments(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesUndistributed(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectRetailAmountAccounting(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	// Other settlements
	SmallBusinessServer.ReflectSettlementsWithOtherCounterparties(AdditionalProperties, RegisterRecords, Cancel);
	// End Other settlements
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.CashReceipt.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo the posting of a document.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.CashReceipt.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure // UndoPosting()

#EndIf