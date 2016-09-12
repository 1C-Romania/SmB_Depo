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
	    //( elmi # 08.5
	    //StructureByCurrency.ExchangeRate = 0,
		  StructureByCurrency.Multiplicity = 0,
		//) elmi
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

//The procedure fills in counterparty bank account when entering on the basis
//
Procedure FillCounterpartyBankAcc()
	
	If Not ValueIsFilled(Counterparty) Then
		
		Return;
		
	EndIf;
	
	// 1. Counterparty bank account exists in the basis document and it is completed
	If ValueIsFilled(BasisDocument) Then
		
		If SmallBusinessServer.IsDocumentAttribute("CounterpartyAccount", BasisDocument.Metadata()) Then
			
			CounterpartyAccount = BasisDocument.CounterpartyAccount;
			
		ElsIf SmallBusinessServer.IsDocumentAttribute("CounterpartyBankAcc", BasisDocument.Metadata()) Then
			
			CounterpartyAccount = BasisDocument.CounterpartyBankAcc;
			
		EndIf;
		
	EndIf;
	
	// 2. Counterparty bank account is filled in based on currency of the document (taken from bank account
	//    of the organization) with the main bank account of the counterparty taken into account.
	If ValueIsFilled(CashCurrency) Then
		
		Query = New Query(
		"SELECT
		|	BankAccounts.Ref AS CounterpartyAccount,
		|	CASE
		|		WHEN BankAccounts.Owner.BankAccountByDefault = BankAccounts.Ref
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS ThisIsMainBankAccount
		|FROM
		|	Catalog.BankAccounts AS BankAccounts
		|WHERE
		|	BankAccounts.Owner = &Owner
		|	AND BankAccounts.CashCurrency = &CashCurrency
		|
		|ORDER BY
		|	ThisIsMainBankAccount DESC");
		
		Query.SetParameter("Owner", Counterparty);
		Query.SetParameter("CashCurrency", CashCurrency);
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
		
			Selection = QueryResult.Select();
			Selection.Next(); 
			
			CounterpartyAccount = Selection.CounterpartyAccount;
			
		EndIf;
		
	EndIf;
	
EndProcedure // FillInBankAccount()

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
		|	VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashFlowItem AS Item,
		|	CASE
		|		WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN DocumentTable.BankAccount
		|		WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|			THEN DocumentTable.Company.BankAccountByDefault
		|		ELSE NestedSelect.BankAccount
		|	END AS BankAccount,
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
		|		LEFT JOIN (SELECT TOP 1
		|			BankAccounts.Ref AS BankAccount,
		|			BankAccounts.Owner AS Owner,
		|			BankAccounts.CashCurrency AS CashCurrency
		|		FROM
		|			Document.PaymentReceiptPlan AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|		WHERE
		|			DocumentTable.Ref = &Ref
		|			AND BankAccounts.DeletionMark = FALSE) AS NestedSelect
		|		ON DocumentTable.DocumentCurrency = NestedSelect.CashCurrency
		|			AND DocumentTable.Company = NestedSelect.Owner
		|WHERE
		|	DocumentTable.Ref = &Ref";
		
	Else
		
		Query.Text =
		"SELECT
		|	VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashFlowItem AS Item,
		|	CASE
		|		WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN DocumentTable.BankAccount
		|		WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|			THEN DocumentTable.Company.BankAccountByDefault
		|		ELSE NestedSelect.BankAccount
		|	END AS BankAccount,
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
		|		LEFT JOIN (SELECT TOP 1
		|			BankAccounts.Ref AS BankAccount,
		|			BankAccounts.Owner AS Owner,
		|			BankAccounts.CashCurrency AS CashCurrency
		|		FROM
		|			Document.PaymentReceiptPlan AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|		WHERE
		|			DocumentTable.Ref = &Ref
		|			AND BankAccounts.DeletionMark = FALSE) AS NestedSelect
		|		ON DocumentTable.DocumentCurrency = NestedSelect.CashCurrency
		|			AND DocumentTable.Company = NestedSelect.Owner
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
	
	FillCounterpartyBankAcc();
	
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
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsPaymentReceipt.Other) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.VATTaxationTypes.TaxableByVAT) AS VATTaxation,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.BankAccountPayee AS BankAccount,
	|	DocumentTable.BankAccountPayee.CashCurrency AS CashCurrency,
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
	
EndProcedure // FillByPaymentReceiptPlan()

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
		|	VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	NestedSelect.CashCurrency AS CashCurrency,
		|	NestedSelect.BankAccount AS BankAccount,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
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
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
		|					AND SettlementsCurrencyRates.ExchangeRate <> 0
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountCurrencyRates.ExchangeRate <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS PaymentAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountCurrencyRates.ExchangeRate <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS VATAmount,
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountCurrencyRates.ExchangeRate <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS DocumentAmount
		|FROM
		|	Document.InvoiceForPayment AS DocumentHeader
		|		LEFT JOIN Document.InvoiceForPayment.Inventory AS DocumentTable
		|		ON DocumentHeader.Ref = DocumentTable.Ref
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRates
		|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
		|		ON DocumentHeader.DocumentCurrency = CurrencyRatesOfDocument.Currency
		|		LEFT JOIN (SELECT TOP 1
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref
		|				ELSE DocumentTable.Company.BankAccountByDefault
		|			END AS BankAccount,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.CashCurrency
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.CashCurrency
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.CashCurrency
		|				ELSE DocumentTable.Company.BankAccountByDefault.CashCurrency
		|			END AS CashCurrency,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.Owner
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.Owner
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref.Owner
		|				ELSE DocumentTable.Company.BankAccountByDefault.Owner
		|			END AS Owner
		|		FROM
		|			Document.InvoiceForPayment AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|					AND (BankAccounts.DeletionMark = FALSE)
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS NestedSelect
		|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS BankAcountCurrencyRates
		|			ON NestedSelect.CashCurrency = BankAcountCurrencyRates.Currency
		|		ON DocumentHeader.Company = NestedSelect.Owner
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|	AND ISNULL(DocumentTable.LineNumber, 1) = 1";
		
	ElsIf LineNumber = Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	NestedSelect.CashCurrency AS CashCurrency,
		|	NestedSelect.BankAccount AS BankAccount,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
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
		|	SUM(CAST(DocumentTable.Total * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
		|						AND SettlementsCurrencyRates.ExchangeRate <> 0
		|						AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS SettlementsAmount,
		|	SUM(CAST(DocumentTable.Total * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|						AND CurrencyRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountCurrencyRates.ExchangeRate <> 0
		|					THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS PaymentAmount,
		|	SUM(CAST(DocumentTable.VATAmount * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|						AND CurrencyRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountCurrencyRates.ExchangeRate <> 0
		|					THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS VATAmount,
		|	SUM(CAST(DocumentTable.Total * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|						AND CurrencyRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountCurrencyRates.ExchangeRate <> 0
		|					THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS DocumentAmount
		|FROM
		|	Document.InvoiceForPayment AS DocumentHeader
		|		LEFT JOIN Document.InvoiceForPayment.Inventory AS DocumentTable
		|		ON DocumentHeader.Ref = DocumentTable.Ref
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRates
		|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
		|		ON DocumentHeader.DocumentCurrency = CurrencyRatesOfDocument.Currency
		|		LEFT JOIN (SELECT TOP 1
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref
		|				ELSE DocumentTable.Company.BankAccountByDefault
		|			END AS BankAccount,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.CashCurrency
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.CashCurrency
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.CashCurrency
		|				ELSE DocumentTable.Company.BankAccountByDefault.CashCurrency
		|			END AS CashCurrency,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.Owner
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.Owner
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref.Owner
		|				ELSE DocumentTable.Company.BankAccountByDefault.Owner
		|			END AS Owner
		|		FROM
		|			Document.InvoiceForPayment AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|					AND (BankAccounts.DeletionMark = FALSE)
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS NestedSelect
		|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS BankAcountCurrencyRates
		|			ON NestedSelect.CashCurrency = BankAcountCurrencyRates.Currency
		|		ON DocumentHeader.Company = NestedSelect.Owner
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|
		|GROUP BY
		|	DocumentHeader.Company,
		|	DocumentHeader.VATTaxation,
		|	DocumentHeader.DocumentCurrency,
		|	DocumentHeader.Counterparty,
		|	DocumentHeader.Contract,
		|	DocumentHeader.BasisDocument,
		|	NestedSelect.CashCurrency,
		|	NestedSelect.BankAccount,
		|	DocumentTable.VATRate,
		|	SettlementsCurrencyRates.ExchangeRate,
		|	SettlementsCurrencyRates.Multiplicity,
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
		|		WHEN DocumentHeader.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN DocumentHeader.BankAccount
		|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
		|			THEN DocumentHeader.Company.BankAccountByDefault
		|		ELSE NestedSelect.BankAccount
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
		|	VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Ref.Company AS Company,
		|	DocumentTable.Ref.VATTaxation AS VATTaxation,
		|	NestedSelect.CashCurrency AS CashCurrency,
		|	NestedSelect.BankAccount AS BankAccount,
		|	DocumentTable.Ref.Counterparty AS Counterparty,
		|	DocumentTable.Ref.Contract AS Contract,
		|	DocumentTable.Ref.DocumentCurrency AS DocumentCurrency,
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
		|			THEN &Ref
		|		ELSE VALUE(Document.InvoiceForPayment.EmptyRef)
		|	END AS InvoiceForPayment,
		|	ISNULL(VATRatesDocumentsTable.VATRate, VATRates.VATRate) AS VATRate,
		|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
		|	SettlementsCurrencyRates.Multiplicity AS Multiplicity,
		|	CAST(DocumentTable.PaymentAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> DocumentTable.Ref.Contract.SettlementsCurrency
		|					AND SettlementsCurrencyRates.ExchangeRate <> 0
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(DocumentTable.PaymentAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountCurrencyRates.ExchangeRate <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS PaymentAmount,
		|	CAST(DocumentTable.PayVATAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountCurrencyRates.ExchangeRate <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS VATAmount,
		|	CAST(DocumentTable.PaymentAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountCurrencyRates.ExchangeRate <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS DocumentAmount
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
		|		LEFT JOIN (SELECT TOP 1
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref
		|				ELSE DocumentTable.Company.BankAccountByDefault
		|			END AS BankAccount,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.CashCurrency
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.CashCurrency
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.CashCurrency
		|				ELSE DocumentTable.Company.BankAccountByDefault.CashCurrency
		|			END AS CashCurrency,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.Owner
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.Owner
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref.Owner
		|				ELSE DocumentTable.Company.BankAccountByDefault.Owner
		|			END AS Owner
		|		FROM
		|			Document.InvoiceForPayment AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|					AND (BankAccounts.DeletionMark = FALSE)
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS NestedSelect
		|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS BankAcountCurrencyRates
		|			ON NestedSelect.CashCurrency = BankAcountCurrencyRates.Currency
		|		ON DocumentTable.Ref.Company = NestedSelect.Owner
		|WHERE
		|	DocumentTable.Ref = &Ref
		|	AND DocumentTable.LineNumber = &LineNumber";
		
	EndIf;
	
	Selection = Query.Execute().Select();
	PaymentDetails.Clear();
	
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		If Not ValueIsFilled(CashCurrency) Then
			CashCurrency = Selection.DocumentCurrency;
		EndIf;
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		If Not VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
	FillCounterpartyBankAcc();
	
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
		|	VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	NestedSelect.CashCurrency AS CashCurrency,
		|	NestedSelect.BankAccount AS BankAccount,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
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
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
		|					AND SettlementsCurrencyRates.ExchangeRate <> 0
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountCurrencyRates.ExchangeRate <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS PaymentAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountCurrencyRates.ExchangeRate <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS VATAmount,
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountCurrencyRates.ExchangeRate <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS DocumentAmount
		|FROM
		|	Document.CustomerOrder AS DocumentHeader
		|		LEFT JOIN Document.CustomerOrder.Inventory AS DocumentTable
		|		ON DocumentHeader.Ref = DocumentTable.Ref
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRates
		|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
		|		ON DocumentHeader.DocumentCurrency = CurrencyRatesOfDocument.Currency
		|		LEFT JOIN (SELECT TOP 1
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref
		|				ELSE DocumentTable.Company.BankAccountByDefault
		|			END AS BankAccount,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.CashCurrency
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.CashCurrency
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.CashCurrency
		|				ELSE DocumentTable.Company.BankAccountByDefault.CashCurrency
		|			END AS CashCurrency,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.Owner
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.Owner
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref.Owner
		|				ELSE DocumentTable.Company.BankAccountByDefault.Owner
		|			END AS Owner
		|		FROM
		|			Document.CustomerOrder AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|					AND (BankAccounts.DeletionMark = FALSE)
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS NestedSelect
		|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS BankAcountCurrencyRates
		|			ON NestedSelect.CashCurrency = BankAcountCurrencyRates.Currency
		|		ON DocumentHeader.Company = NestedSelect.Owner
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|	AND ISNULL(DocumentTable.LineNumber, 1) = 1";
		
	ElsIf LineNumber = Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	BankAccountsNestedSelect.CashCurrency AS CashCurrency,
		|	BankAccountsNestedSelect.BankAccount AS BankAccount,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
		|	CASE
		|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|				AND DocumentHeader.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS AdvanceFlag,
		|	&Ref AS InvoiceForPayment,
		|	NestedSelect.VATRate AS VATRate,
		|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
		|	SettlementsCurrencyRates.Multiplicity AS Multiplicity,
		|	SUM(CAST(NestedSelect.Total * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
		|						AND SettlementsCurrencyRates.ExchangeRate <> 0
		|						AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS SettlementsAmount,
		|	SUM(CAST(NestedSelect.Total * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> BankAccountsNestedSelect.CashCurrency
		|						AND CurrencyRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountCurrencyRates.ExchangeRate <> 0
		|					THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS PaymentAmount,
		|	SUM(CAST(NestedSelect.VATAmount * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> BankAccountsNestedSelect.CashCurrency
		|						AND CurrencyRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountCurrencyRates.ExchangeRate <> 0
		|					THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS VATAmount,
		|	SUM(CAST(NestedSelect.Total * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> BankAccountsNestedSelect.CashCurrency
		|						AND CurrencyRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountCurrencyRates.ExchangeRate <> 0
		|					THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS DocumentAmount,
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
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRates
		|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
		|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
		|		ON DocumentHeader.DocumentCurrency = CurrencyRatesOfDocument.Currency
		|		LEFT JOIN (SELECT
		|			&Ref AS BasisDocument,
		|			DocumentTable.VATRate AS VATRate,
		|			DocumentTable.Total AS Total,
		|			DocumentTable.VATAmount AS VATAmount
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
		|			DocumentTable.Total,
		|			DocumentTable.VATAmount
		|		FROM
		|			Document.CustomerOrder.Works AS DocumentTable
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS NestedSelect
		|		ON DocumentHeader.Ref = NestedSelect.BasisDocument
		|		LEFT JOIN (SELECT TOP 1
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref
		|				ELSE DocumentTable.Company.BankAccountByDefault
		|			END AS BankAccount,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.CashCurrency
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.CashCurrency
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.CashCurrency
		|				ELSE DocumentTable.Company.BankAccountByDefault.CashCurrency
		|			END AS CashCurrency,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.Owner
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.Owner
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref.Owner
		|				ELSE DocumentTable.Company.BankAccountByDefault.Owner
		|			END AS Owner
		|		FROM
		|			Document.CustomerOrder AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|					AND (BankAccounts.DeletionMark = FALSE)
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS BankAccountsNestedSelect
		|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS BankAcountCurrencyRates
		|			ON BankAccountsNestedSelect.CashCurrency = BankAcountCurrencyRates.Currency
		|		ON DocumentHeader.Company = BankAccountsNestedSelect.Owner
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|
		|GROUP BY
		|	DocumentHeader.Company,
		|	DocumentHeader.VATTaxation,
		|	DocumentHeader.DocumentCurrency,
		|	DocumentHeader.Counterparty,
		|	DocumentHeader.Contract,
		|	NestedSelect.VATRate,
		|	SettlementsCurrencyRates.ExchangeRate,
		|	SettlementsCurrencyRates.Multiplicity,
		|	BankAccountsNestedSelect.CashCurrency,
		|	BankAccountsNestedSelect.BankAccount,
		|	CASE
		|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|				AND DocumentHeader.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|			THEN FALSE
		|		ELSE TRUE
		|	END,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
		|	END,
		|	CASE
		|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|				AND DocumentHeader.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|				AND DocumentHeader.Counterparty.DoOperationsByDocuments
		|			THEN &Ref
		|		ELSE UNDEFINED
		|	END,
		|	CASE
		|		WHEN DocumentHeader.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN DocumentHeader.BankAccount
		|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
		|			THEN DocumentHeader.Company.BankAccountByDefault
		|		ELSE BankAccountsNestedSelect.BankAccount
		|	END";
		
	Else
	
		Query.SetParameter("Ref", FillingData.Basis);
		Query.SetParameter("LineNumber", LineNumber);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill document header data.
		Query.Text =
		"SELECT
		|	VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Ref.Company AS Company,
		|	DocumentTable.Ref.VATTaxation AS VATTaxation,
		|	NestedSelect.CashCurrency AS CashCurrency,
		|	NestedSelect.BankAccount AS BankAccount,
		|	DocumentTable.Ref.Counterparty AS Counterparty,
		|	DocumentTable.Ref.Contract AS Contract,
		|	DocumentTable.Ref.DocumentCurrency AS DocumentCurrency,
		|	CASE
		|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
		|				AND DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS AdvanceFlag,
		|	DocumentTable.Ref AS InvoiceForPayment,
		|	ISNULL(VATRatesDocumentsTable.VATRate, VATRates.VATRate) AS VATRate,
		|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
		|	SettlementsCurrencyRates.Multiplicity AS Multiplicity,
		|	CAST(DocumentTable.PaymentAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> DocumentTable.Ref.Contract.SettlementsCurrency
		|					AND SettlementsCurrencyRates.ExchangeRate <> 0
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(DocumentTable.PaymentAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountCurrencyRates.ExchangeRate <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS PaymentAmount,
		|	CAST(DocumentTable.PayVATAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountCurrencyRates.ExchangeRate <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS VATAmount,
		|	CAST(DocumentTable.PaymentAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND CurrencyRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountCurrencyRates.ExchangeRate <> 0
		|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS DocumentAmount,
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
		|		LEFT JOIN (SELECT TOP 1
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref
		|				ELSE DocumentTable.Company.BankAccountByDefault
		|			END AS BankAccount,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.CashCurrency
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.CashCurrency
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.CashCurrency
		|				ELSE DocumentTable.Company.BankAccountByDefault.CashCurrency
		|			END AS CashCurrency,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.Owner
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.Owner
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref.Owner
		|				ELSE DocumentTable.Company.BankAccountByDefault.Owner
		|			END AS Owner
		|		FROM
		|			Document.CustomerOrder AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|					AND (BankAccounts.DeletionMark = FALSE)
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS NestedSelect
		|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS BankAcountCurrencyRates
		|			ON NestedSelect.CashCurrency = BankAcountCurrencyRates.Currency
		|		ON DocumentTable.Ref.Company = NestedSelect.Owner
		|WHERE
		|	DocumentTable.Ref = &Ref
		|	AND DocumentTable.LineNumber = &LineNumber";
		
	EndIf;
	
	Selection = Query.Execute().Select();
	PaymentDetails.Clear();
	
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		If Not ValueIsFilled(CashCurrency) Then
			CashCurrency = Selection.DocumentCurrency;
		EndIf;
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		If Not VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
	FillCounterpartyBankAcc();
	
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
	
	// Fill data of the document tabular sections.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer) AS OperationKind,
	|	&Date AS Date,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	BankAccountsNestedSelect.CashCurrency AS CashCurrency,
	|	BankAccountsNestedSelect.BankAccount AS BankAccount,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|				AND DocumentHeader.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS AdvanceFlag,
	|	&Ref AS InvoiceForPayment,
	|	NestedSelect.VATRate AS VATRate,
	|	ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(CurrencyRatesOfDocument.Multiplicity, 1) AS Multiplicity,
	|	InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover AS Total,
	|	DocumentHeader.DocumentCurrency AS DocumentCur1,
	|	BankAccountsNestedSelect.CashCurrency AS CashCurrency1,
	|	CurrencyRatesOfDocument.ExchangeRate AS ExchangeRate1,
	|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate2,
	|	BankAcountCurrencyRates.ExchangeRate AS ExchangeRate3,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * CASE
	|			WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
	|					AND SettlementsCurrencyRates.ExchangeRate <> 0
	|					AND CurrencyRatesOfDocument.Multiplicity <> 0
	|				THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
	|			ELSE 1
	|		END AS NUMBER(15, 2)) AS SettlementsAmount,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * CASE
	|			WHEN DocumentHeader.DocumentCurrency <> BankAccountsNestedSelect.CashCurrency
	|					AND CurrencyRatesOfDocument.Multiplicity <> 0
	|					AND BankAcountCurrencyRates.ExchangeRate <> 0
	|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
	|			ELSE 1
	|		END AS NUMBER(15, 2)) AS PaymentAmount,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * (1 - 1 / ((ISNULL(NestedSelect.VATRate.Rate, 0) + 100) / 100)) * CASE
	|			WHEN DocumentHeader.DocumentCurrency <> BankAccountsNestedSelect.CashCurrency
	|					AND CurrencyRatesOfDocument.Multiplicity <> 0
	|					AND BankAcountCurrencyRates.ExchangeRate <> 0
	|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
	|			ELSE 1
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * CASE
	|			WHEN DocumentHeader.DocumentCurrency <> BankAccountsNestedSelect.CashCurrency
	|					AND CurrencyRatesOfDocument.Multiplicity <> 0
	|					AND BankAcountCurrencyRates.ExchangeRate <> 0
	|				THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
	|			ELSE 1
	|		END AS NUMBER(15, 2)) AS DocumentAmount,
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
	|		LEFT JOIN (SELECT TOP 1
	|			CASE
	|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
	|					THEN DocumentTable.BankAccount
	|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
	|					THEN DocumentTable.Company.BankAccountByDefault
	|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
	|					THEN BankAccounts.Ref
	|				ELSE DocumentTable.Company.BankAccountByDefault
	|			END AS BankAccount,
	|			CASE
	|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
	|					THEN DocumentTable.BankAccount.CashCurrency
	|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
	|					THEN DocumentTable.Company.BankAccountByDefault.CashCurrency
	|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
	|					THEN BankAccounts.CashCurrency
	|				ELSE DocumentTable.Company.BankAccountByDefault.CashCurrency
	|			END AS CashCurrency,
	|			CASE
	|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
	|					THEN DocumentTable.BankAccount.Owner
	|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
	|					THEN DocumentTable.Company.BankAccountByDefault.Owner
	|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
	|					THEN BankAccounts.Ref.Owner
	|				ELSE DocumentTable.Company.BankAccountByDefault.Owner
	|			END AS Owner
	|		FROM
	|			Document.CustomerOrder AS DocumentTable
	|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
	|				ON DocumentTable.Company = BankAccounts.Owner
	|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
	|					AND (BankAccounts.DeletionMark = FALSE)
	|		WHERE
	|			DocumentTable.Ref = &Ref) AS BankAccountsNestedSelect
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS BankAcountCurrencyRates
	|			ON BankAccountsNestedSelect.CashCurrency = BankAcountCurrencyRates.Currency
	|		ON DocumentHeader.Company = BankAccountsNestedSelect.Owner
	|WHERE
	|	DocumentHeader.Ref = &Ref";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		If Not ValueIsFilled(CashCurrency) Then
			CashCurrency = Selection.DocumentCurrency;
		EndIf;
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		If Not VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
	FillCounterpartyBankAcc();
	
EndProcedure // FillByCustomerOrderDependOnBalanceForPayment()

// Procedure of filling the document on the basis of tax accrual.
//
// Parameters:
// BasisDocument - DocumentRef.PaymentReceiptPlan - Scheduled
// payment FillingData - Structure - Data on filling the document.
//	
Procedure FillByTaxAccrual(BasisDocument)
	
	If BasisDocument.OperationKind <> Enums.OperationKindsTaxAccrual.Reimbursement Then
		Raise NStr("en='Payment receipt can be entered only according to the tax refund but not to the accrual.';ru='Поступление на счет можно ввести только на основании возмещения налогов, а не начисления.'");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	Query.SetParameter("ConstantNationalCurrency", Constants.NationalCurrency.Get());
	Query.SetParameter("ConstantAccountingCurrency", Constants.AccountingCurrency.Get());
	
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsPaymentReceipt.Taxes) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.Other) AS Item,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = &ConstantNationalCurrency
	|			THEN DocumentTable.Company.BankAccountByDefault
	|		ELSE NestedSelect.BankAccount
	|	END AS BankAccount,
	|	&ConstantNationalCurrency AS CashCurrency,
	|	DocumentTable.Company.DefaultVATRate AS VATRate,
	|	1 AS ExchangeRate,
	|	1 AS Multiplicity,
	|	CAST(DocumentTable.DocumentAmount * AccountingCurrencyRates.ExchangeRate * 1 / (1 * ISNULL(AccountingCurrencyRates.Multiplicity, 1)) AS NUMBER(15, 2)) AS DocumentAmount,
	|	DocumentTableTaxes.TaxKind AS TaxKind,
	|	DocumentTableTaxes.BusinessActivity AS BusinessActivity
	|FROM
	|	Document.TaxAccrual AS DocumentTable
	|		LEFT JOIN (SELECT TOP 1
	|			DocumentTable.Ref AS Ref,
	|			DocumentTable.TaxKind AS TaxKind,
	|			DocumentTable.BusinessActivity AS BusinessActivity
	|		FROM
	|			Document.TaxAccrual.Taxes AS DocumentTable
	|		WHERE
	|			DocumentTable.Ref = &Ref) AS DocumentTableTaxes
	|		ON DocumentTable.Ref = DocumentTableTaxes.Ref
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, Currency = &ConstantAccountingCurrency) AS AccountingCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN (SELECT TOP 1
	|			BankAccounts.Ref AS BankAccount,
	|			BankAccounts.Owner AS Owner,
	|			BankAccounts.CashCurrency AS CashCurrency
	|		FROM
	|			Document.TaxAccrual AS DocumentTable
	|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
	|				ON DocumentTable.Company = BankAccounts.Owner
	|					AND (BankAccounts.CashCurrency = &ConstantNationalCurrency)
	|		WHERE
	|			DocumentTable.Ref = &Ref
	|			AND BankAccounts.DeletionMark = FALSE) AS NestedSelect
	|		ON DocumentTable.Company = NestedSelect.Owner
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		VATTaxation = SmallBusinessServer.VATTaxation(Company, , Date);
		PaymentDetails.Clear();
		
	EndIf;
	
EndProcedure // FillByTaxAccrual()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillBySalesInvoice(BasisDocument)
	
	If BasisDocument.OperationKind = Enums.OperationKindsCustomerInvoice.TransferToProcessing Then
		ErrorMessage = NStr("en='Cannot enter a document based on the operation - ""%OperationKind""';ru='Невозможен ввод документа на основании операции - ""%ВидОперации""!'");
		ErrorMessage = StrReplace(ErrorMessage, "%OperationKind", BasisDocument.OperationKind);
		Raise ErrorMessage;
	EndIf;
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN VALUE(Enum.OperationKindsPaymentReceipt.FromVendor)
	|		ELSE VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer)
	|	END AS OperationKind,
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|	END AS Item,
	|	&Ref AS BasisDocument,
	|	CASE
	|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
	|			THEN DocumentHeader.Company.BankAccountByDefault
	|		ELSE NestedSelect.BankAccount
	|	END AS BankAccount,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
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
	|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsCurrencyRatesSliceLast.Currency
	|		LEFT JOIN (SELECT TOP 1
	|			BankAccounts.Ref AS BankAccount,
	|			BankAccounts.Owner AS Owner,
	|			BankAccounts.CashCurrency AS CashCurrency
	|		FROM
	|			Document.CustomerInvoice AS DocumentTable
	|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
	|				ON DocumentTable.Company = BankAccounts.Owner
	|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
	|		WHERE
	|			DocumentTable.Ref = &Ref
	|			AND BankAccounts.DeletionMark = FALSE) AS NestedSelect
	|		ON DocumentHeader.DocumentCurrency = NestedSelect.CashCurrency
	|			AND DocumentHeader.Company = NestedSelect.Owner,
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN VALUE(Enum.OperationKindsPaymentReceipt.FromVendor)
	|		ELSE VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer)
	|	END,
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|	END,
	|	DocumentHeader.Company,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.DocumentCurrency,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE CASE
	|				WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
	|					THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|				ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|			END
	|	END,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
	|			THEN DocumentHeader.Company.BankAccountByDefault
	|		ELSE NestedSelect.BankAccount
	|	END,
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
	
	FillCounterpartyBankAcc();
	
EndProcedure // FillBySalesInvoice()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByAcceptanceCertificate(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	CASE
	|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
	|			THEN DocumentHeader.Company.BankAccountByDefault
	|		ELSE NestedSelect.BankAccount
	|	END AS BankAccount,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
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
	|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsCurrencyRatesSliceLast.Currency
	|		LEFT JOIN (SELECT TOP 1
	|			BankAccounts.Ref AS BankAccount,
	|			BankAccounts.Owner AS Owner,
	|			BankAccounts.CashCurrency AS CashCurrency
	|		FROM
	|			Document.AcceptanceCertificate AS DocumentTable
	|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
	|				ON DocumentTable.Company = BankAccounts.Owner
	|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
	|		WHERE
	|			DocumentTable.Ref = &Ref
	|			AND BankAccounts.DeletionMark = FALSE) AS NestedSelect
	|		ON DocumentHeader.DocumentCurrency = NestedSelect.CashCurrency
	|			AND DocumentHeader.Company = NestedSelect.Owner,
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.DocumentCurrency,
	|	DocumentTable.CustomerOrder,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
	|			THEN DocumentHeader.Company.BankAccountByDefault
	|		ELSE NestedSelect.BankAccount
	|	END,
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
	
	FillCounterpartyBankAcc();
	
EndProcedure // FillByAcceptanceCertificate()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssetsTransfer(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsPaymentReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	CASE
	|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
	|			THEN DocumentHeader.Company.BankAccountByDefault
	|		ELSE NestedSelect.BankAccount
	|	END AS BankAccount,
	|	DocumentHeader.VATTaxation AS VATTaxation,
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
	|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsCurrencyRatesSliceLast.Currency
	|		LEFT JOIN (SELECT TOP 1
	|			BankAccounts.Ref AS BankAccount,
	|			BankAccounts.Owner AS Owner,
	|			BankAccounts.CashCurrency AS CashCurrency
	|		FROM
	|			Document.FixedAssetsTransfer AS DocumentTable
	|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
	|				ON DocumentTable.Company = BankAccounts.Owner
	|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
	|		WHERE
	|			DocumentTable.Ref = &Ref
	|			AND BankAccounts.DeletionMark = FALSE) AS NestedSelect
	|		ON DocumentHeader.DocumentCurrency = NestedSelect.CashCurrency
	|			AND DocumentHeader.Company = NestedSelect.Owner,
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.DocumentCurrency,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
	|			THEN DocumentHeader.Company.BankAccountByDefault
	|		ELSE NestedSelect.BankAccount
	|	END,
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

// Posting cancellation procedure at subordinate customer invoice note
//
Procedure SubordinatedInvoiceControl()
	
	InvoiceStructure = SmallBusinessServer.GetSubordinateInvoice(Ref);
	If Not InvoiceStructure = Undefined Then
		
		CustomerInvoiceNote	 = InvoiceStructure.Ref;
		If CustomerInvoiceNote.Posted Then
			
			MessageText = NStr("en='As there are no register records of the %CurrentDocumentPresentation% document, undo the posting of %InvoicePresentation%.';ru='В связи с отсутствием движений у документа %ПредставлениеТекущегоДокумента% распроводится счет фактура %ПредставлениеСчетФактуры%.'");
			MessageText = StrReplace(MessageText, "%CurrentDocumentPresentation%", """Cash receipt on account No " + Number + " dated " + Format(Date, "DF=dd.MM.yyyy") + """");
			MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Customer invoice note (issued) No " + InvoiceStructure.Number + " dated " + InvoiceStructure.Date + """");
			
			CommonUseClientServer.MessageToUser(MessageText);
			
			InvoiceObject = CustomerInvoiceNote.GetObject();
			InvoiceObject.Write(DocumentWriteMode.UndoPosting);
			
		EndIf;
		
	EndIf;
	
EndProcedure //SubordinateInvoiceControl()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each TSRow IN PaymentDetails Do
		If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = Counterparty.ContractByDefault;
		EndIf;
	EndDo;
	
EndProcedure // BeforeWrite()

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.InvoiceForPayment") Then
		FillByInvoiceForPayment(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PaymentReceiptPlan") Then
		FillByPaymentReceiptPlan(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CashTransferPlan") Then
		FillByCashTransferPlan(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerInvoice") Then
		FillBySalesInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AcceptanceCertificate") Then
		FillByAcceptanceCertificate(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.FixedAssetsTransfer") Then
		FillByFixedAssetsTransfer(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
		FillByCustomerOrder(FillingData);
	ElsIf TypeOf(FillingData)= Type("DocumentRef.TaxAccrual") Then
		FillByTaxAccrual(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure")
			AND FillingData.Property("Basis") Then
		If FillingData.Property("ConsiderBalances") 
			AND TypeOf(FillingData.Basis)= Type("DocumentRef.CustomerOrder") Then
			FillByCustomerOrderDependOnBalanceForPayment(FillingData.Basis);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.InvoiceForPayment") Then
			FillByInvoiceForPayment(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.CustomerOrder") Then
			FillByCustomerOrder(FillingData, FillingData.LineNumber);
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
	
EndProcedure // FillingProcessor()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Deletion of verifiable attributes from the structure depending
	// on the operation type.
	If OperationKind = Enums.OperationKindsPaymentReceipt.FromVendor
	 OR OperationKind = Enums.OperationKindsPaymentReceipt.FromCustomer Then
	 
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		
		If Counterparty.DoOperationsByDocuments Then
			For Each RowPaymentDetails IN PaymentDetails Do
				If Not ValueIsFilled(RowPaymentDetails.Document)
					AND (OperationKind = Enums.OperationKindsPaymentReceipt.FromVendor
				   OR (OperationKind = Enums.OperationKindsPaymentReceipt.FromCustomer
				   AND Not RowPaymentDetails.AdvanceFlag)) Then
					If PaymentDetails.Count() = 1 Then
						If OperationKind = Enums.OperationKindsPaymentReceipt.FromCustomer Then
							MessageText = NStr("en='Specify the shipment document or the advance payment sign.';ru='Укажите документ отгрузки или признак аванса платежа.'");
						Else
							MessageText = NStr("en='Specify the settlements document.';ru='Укажите документ расчетов.'");
						EndIf;
					Else
						If OperationKind = Enums.OperationKindsPaymentReceipt.FromCustomer Then
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
		
	ElsIf OperationKind = Enums.OperationKindsPaymentReceipt.FromAdvanceHolder Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
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
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		
	ElsIf OperationKind = Enums.OperationKindsPaymentReceipt.Other Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
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
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		
	ElsIf OperationKind = Enums.OperationKindsPaymentReceipt.CurrencyPurchase Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.UnitConversionFactor");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		
	Else
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.UnitConversionFactor");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		
	EndIf;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.PaymentReceipt.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAdvanceHolderPayments(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesUndistributed(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.PaymentReceipt.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.PaymentReceipt.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	// Subordinate customer invoice note
	If Not Cancel Then
		
		SubordinatedInvoiceControl();
		
	EndIf;
	
EndProcedure // UndoPosting()

#EndIf