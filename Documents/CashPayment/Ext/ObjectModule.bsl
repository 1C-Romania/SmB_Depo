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
	|	AccountsPayableBalances.Company AS Company,
	|	AccountsPayableBalances.Counterparty AS Counterparty,
	|	AccountsPayableBalances.Contract AS Contract,
	|	CASE
	|		WHEN AccountsPayableBalances.Counterparty.DoOperationsByDocuments
	|			THEN AccountsPayableBalances.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN AccountsPayableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsPayableBalances.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	AccountsPayableBalances.SettlementsType AS SettlementsType,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance,
	|	AccountsPayableBalances.Document.Date AS DocumentDate,
	|	SUM(CAST(AccountsPayableBalances.AmountCurBalance * SettlementsCurrencyRates.ExchangeRate * CurrencyRatesOfDocument.Multiplicity / (CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2))) AS AmountCurrDocument,
	|	CurrencyRatesOfDocument.ExchangeRate AS CashAssetsRate,
	|	CurrencyRatesOfDocument.Multiplicity AS CashMultiplicity,
	|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
	|	SettlementsCurrencyRates.Multiplicity AS Multiplicity
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Company AS Company,
	|		AccountsPayableBalances.Counterparty AS Counterparty,
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Order AS Order,
	|		AccountsPayableBalances.SettlementsType AS SettlementsType,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					// TextOfContractSelection
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Company,
	|		DocumentRegisterRecordsVendorSettlements.Counterparty,
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Order,
	|		DocumentRegisterRecordsVendorSettlements.SettlementsType,
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
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, Currency = &Currency) AS CurrencyRatesOfDocument
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, ) AS SettlementsCurrencyRates
	|		ON AccountsPayableBalances.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
	|WHERE
	|	AccountsPayableBalances.AmountCurBalance > 0
	|
	|GROUP BY
	|	AccountsPayableBalances.Company,
	|	AccountsPayableBalances.Counterparty,
	|	AccountsPayableBalances.Contract,
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.SettlementsType,
	|	AccountsPayableBalances.Document.Date,
	|	CurrencyRatesOfDocument.ExchangeRate,
	|	CurrencyRatesOfDocument.Multiplicity,
	|	SettlementsCurrencyRates.ExchangeRate,
	|	SettlementsCurrencyRates.Multiplicity,
	|	CASE
	|		WHEN AccountsPayableBalances.Counterparty.DoOperationsByDocuments
	|			THEN AccountsPayableBalances.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN AccountsPayableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsPayableBalances.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
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
				ExchangeRateCurrenciesDC,
				NewRow.ExchangeRate,
				CurrencyUnitConversionFactor,
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
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByCashOutflowPlan(BasisDocument, Amount = Undefined)
	
	If BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.NotApproved Then
		Raise NStr("en = 'Unable to enter the money expense according to the unapproved application!'");
	EndIf;
	If BasisDocument.CashAssetsType = Enums.CashAssetTypes.Noncash Then
		Raise NStr("en = 'Unable to enter the cash expense. Invalid payment method is specified in the application (cash assets type)!'");
	EndIf;

	Query = New Query;
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Amount", Amount);
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationKindsCashPayment.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.BasisDocument AS RequestBasisDocument,
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
		|	Document.CashOutflowPlan AS DocumentTable
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
		|	VALUE(Enum.OperationKindsCashPayment.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.BasisDocument AS RequestBasisDocument,
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
		|	Document.CashOutflowPlan AS DocumentTable
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
			AND TypeOf(BasisDocument.BasisDocument) = Type("DocumentRef.PurchaseOrder")
			AND Counterparty.DoOperationsByOrders Then
			
			NewRow.Order = BasisDocument.BasisDocument;
			
		EndIf;
		
		If ValueIsFilled(Selection.RequestBasisDocument)
			AND TypeOf(Selection.RequestBasisDocument) = Type("DocumentRef.SupplierInvoiceForPayment")
			AND Counterparty.TrackPaymentsByBills Then
			
			NewRow.InvoiceForPayment = Selection.RequestBasisDocument;
			
		EndIf;
		
	EndIf;
	
EndProcedure // FillByCashOutflowPlan()

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByCashTransferPlan(BasisDocument, Amount = Undefined)
	
	If BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.NotApproved Then
		Raise NStr("en = 'You can not enter the cash register records basing on the unapproved plan document!'");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", BasisDocument);

	// Fill document header data.
	Query.Text =
	"SELECT
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationKindsCashPayment.Other) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.VATTaxationTypes.TaxableByVAT) AS VATTaxation,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.DocumentCurrency AS CashCurrency,
	|	DocumentTable.PettyCash AS PettyCash,
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
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByPurchaseInvoice(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReturnFromCustomer)
	|			THEN VALUE(Enum.OperationKindsCashPayment.ToCustomer)
	|		ELSE VALUE(Enum.OperationKindsCashPayment.Vendor)
	|	END AS OperationKind,
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReturnFromCustomer)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|	END AS Item,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.Company.PettyCashByDefault AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN CASE
	|					WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReturnFromCustomer)
	|						THEN NestedSelect.CustomerOrder
	|					ELSE NestedSelect.PurchaseOrder
	|				END
	|		ELSE CASE
	|				WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReturnFromCustomer)
	|					THEN VALUE(Document.CustomerOrder.EmptyRef)
	|				ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|			END
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN VALUETYPE(NestedSelect.BasisDocument) = Type(Document.CustomerInvoice)
	|							AND NestedSelect.BasisDocument <> VALUE(Document.CustomerInvoice.EmptyRef)
	|						THEN NestedSelect.BasisDocument
	|					WHEN VALUETYPE(NestedSelect.BasisDocument) = Type(Document.CustomerOrder)
	|							AND NestedSelect.BasisDocument <> VALUE(Document.CustomerOrder.EmptyRef)
	|							AND NestedSelect.BasisDocument.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|						THEN NestedSelect.BasisDocument
	|					ELSE NestedSelect.Document
	|				END
	|		ELSE UNDEFINED
	|	END AS Document,
	|	SUM(ISNULL(NestedSelect.SettlementsAmount, 0)) AS SettlementsAmount,
	|	NestedSelect.ExchangeRate AS ExchangeRate,
	|	NestedSelect.Multiplicity AS Multiplicity,
	|	SUM(ISNULL(NestedSelect.PaymentAmount, 0)) AS PaymentAmount,
	|	NestedSelect.VATRate AS VATRate,
	|	SUM(ISNULL(NestedSelect.VATAmount, 0)) AS VATAmount
	|FROM
	|	Document.SupplierInvoice AS DocumentHeader
	|		LEFT JOIN (SELECT
	|			CASE
	|				WHEN DocumentTable.Order = UNDEFINED
	|						OR VALUETYPE(DocumentTable.Order) = Type(Document.CustomerOrder)
	|					THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|				ELSE DocumentTable.Order
	|			END AS PurchaseOrder,
	|			CASE
	|				WHEN DocumentTable.Order = UNDEFINED
	|						OR VALUETYPE(DocumentTable.Order) = Type(Document.PurchaseOrder)
	|					THEN VALUE(Document.CustomerOrder.EmptyRef)
	|				ELSE DocumentTable.Order
	|			END AS CustomerOrder,
	|			DocumentTable.Ref.BasisDocument AS BasisDocument,
	|			&Ref AS Document,
	|			CAST(DocumentTable.Total * CASE
	|					WHEN DocumentTable.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN RegCurrenciesRates.ExchangeRate * DocumentTable.Ref.Multiplicity / (DocumentTable.Ref.ExchangeRate * ISNULL(RegCurrenciesRates.Multiplicity, 1))
	|					ELSE 1
	|				END AS NUMBER(15, 2)) AS SettlementsAmount,
	|			CASE
	|				WHEN DocumentTable.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|					THEN DocumentTable.Ref.ExchangeRate
	|				ELSE SettlementsCurrencyRatesSliceLast.ExchangeRate
	|			END AS ExchangeRate,
	|			CASE
	|				WHEN DocumentTable.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|					THEN DocumentTable.Ref.Multiplicity
	|				ELSE SettlementsCurrencyRatesSliceLast.Multiplicity
	|			END AS Multiplicity,
	|			DocumentTable.Total AS PaymentAmount,
	|			DocumentTable.VATRate AS VATRate,
	|			DocumentTable.VATAmount AS VATAmount
	|		FROM
	|			Document.SupplierInvoice.Inventory AS DocumentTable
	|				LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|						&Date,
	|						Currency In
	|							(SELECT
	|								ConstantNationalCurrency.Value
	|							FROM
	|								Constant.NationalCurrency AS ConstantNationalCurrency)) AS RegCurrenciesRates
	|				ON (TRUE)
	|				LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRatesSliceLast
	|				ON DocumentTable.Ref.Contract.SettlementsCurrency = SettlementsCurrencyRatesSliceLast.Currency,
	|			Constant.NationalCurrency AS ConstantNationalCurrency
	|		WHERE
	|			DocumentTable.Ref = &Ref
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.PurchaseOrder,
	|			DocumentTable.Order,
	|			DocumentTable.Ref.BasisDocument,
	|			&Ref,
	|			CAST(DocumentTable.Total * CASE
	|					WHEN DocumentTable.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN RegCurrenciesRates.ExchangeRate * DocumentTable.Ref.Multiplicity / (DocumentTable.Ref.ExchangeRate * ISNULL(RegCurrenciesRates.Multiplicity, 1))
	|					ELSE 1
	|				END AS NUMBER(15, 2)),
	|			CASE
	|				WHEN DocumentTable.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|					THEN DocumentTable.Ref.ExchangeRate
	|				ELSE SettlementsCurrencyRatesSliceLast.ExchangeRate
	|			END,
	|			CASE
	|				WHEN DocumentTable.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|					THEN DocumentTable.Ref.Multiplicity
	|				ELSE SettlementsCurrencyRatesSliceLast.Multiplicity
	|			END,
	|			DocumentTable.Total,
	|			DocumentTable.VATRate,
	|			DocumentTable.VATAmount
	|		FROM
	|			Document.SupplierInvoice.Expenses AS DocumentTable
	|				LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|						&Date,
	|						Currency In
	|							(SELECT
	|								ConstantNationalCurrency.Value
	|							FROM
	|								Constant.NationalCurrency AS ConstantNationalCurrency)) AS RegCurrenciesRates
	|				ON (TRUE)
	|				LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS SettlementsCurrencyRatesSliceLast
	|				ON DocumentTable.Ref.Contract.SettlementsCurrency = SettlementsCurrencyRatesSliceLast.Currency,
	|			Constant.NationalCurrency AS ConstantNationalCurrency
	|		WHERE
	|			DocumentTable.Ref = &Ref) AS NestedSelect
	|		ON DocumentHeader.Ref = NestedSelect.Document
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Company.PettyCashByDefault,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.DocumentCurrency,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN CASE
	|					WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReturnFromCustomer)
	|						THEN NestedSelect.CustomerOrder
	|					ELSE NestedSelect.PurchaseOrder
	|				END
	|		ELSE CASE
	|				WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReturnFromCustomer)
	|					THEN VALUE(Document.CustomerOrder.EmptyRef)
	|				ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|			END
	|	END,
	|	DocumentHeader.Contract,
	|	NestedSelect.Document,
	|	NestedSelect.ExchangeRate,
	|	NestedSelect.Multiplicity,
	|	NestedSelect.VATRate,
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReturnFromCustomer)
	|			THEN VALUE(Enum.OperationKindsCashPayment.ToCustomer)
	|		ELSE VALUE(Enum.OperationKindsCashPayment.Vendor)
	|	END,
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReturnFromCustomer)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|	END,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN VALUETYPE(NestedSelect.BasisDocument) = Type(Document.CustomerInvoice)
	|							AND NestedSelect.BasisDocument <> VALUE(Document.CustomerInvoice.EmptyRef)
	|						THEN NestedSelect.BasisDocument
	|					WHEN VALUETYPE(NestedSelect.BasisDocument) = Type(Document.CustomerOrder)
	|							AND NestedSelect.BasisDocument <> VALUE(Document.CustomerOrder.EmptyRef)
	|							AND NestedSelect.BasisDocument.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|						THEN NestedSelect.BasisDocument
	|					ELSE NestedSelect.Document
	|				END
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
	
EndProcedure // FillBySupplierInvoice()

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByAdditionalCosts(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	VALUE(Enum.OperationKindsCashPayment.Vendor) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company.PettyCashByDefault AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentHeader.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
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
	|	Document.AdditionalCosts AS DocumentHeader
	|		LEFT JOIN Document.AdditionalCosts.Expenses AS DocumentTable
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
	|	DocumentHeader.PurchaseOrder,
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
	|			THEN DocumentHeader.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
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
	
EndProcedure // FillByAdditionalCosts()

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByAgentReport(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	VALUE(Enum.OperationKindsCashPayment.ToCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company.PettyCashByDefault AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.Contract AS Contract,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentTable.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS Order,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	SUM(ISNULL(CAST(CASE
	|					WHEN DocumentHeader.AmountIncludesVAT
	|						THEN DocumentTable.BrokerageAmount
	|					ELSE DocumentTable.BrokerageAmount + DocumentTable.BrokerageVATAmount
	|				END * CASE
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
	|	SUM(ISNULL(CASE
	|				WHEN DocumentHeader.AmountIncludesVAT
	|					THEN DocumentTable.BrokerageAmount
	|				ELSE DocumentTable.BrokerageAmount + DocumentTable.BrokerageVATAmount
	|			END, 0)) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(ISNULL(DocumentTable.BrokerageVATAmount, 0)) AS VATAmount
	|FROM
	|	Document.AgentReport AS DocumentHeader
	|		LEFT JOIN Document.AgentReport.Inventory AS DocumentTable
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
	
EndProcedure // FillByAdditionalCosts()

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByReportToPrincipal(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	VALUE(Enum.OperationKindsCashPayment.Vendor) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company.PettyCashByDefault AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.Contract AS Contract,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	SUM(ISNULL(CAST(CASE
	|					WHEN DocumentHeader.AmountIncludesVAT
	|						THEN CASE
	|								WHEN DocumentHeader.KeepBackComissionFee
	|									THEN DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount - DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount
	|								ELSE DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount
	|							END
	|					ELSE CASE
	|							WHEN DocumentHeader.KeepBackComissionFee
	|								THEN DocumentTable.AmountReceipt - DocumentTable.BrokerageAmount
	|							ELSE DocumentTable.AmountReceipt
	|						END
	|				END * CASE
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
	|	SUM(ISNULL(CASE
	|				WHEN DocumentHeader.AmountIncludesVAT
	|					THEN CASE
	|							WHEN DocumentHeader.KeepBackComissionFee
	|								THEN DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount - DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount
	|							ELSE DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount
	|						END
	|				ELSE CASE
	|						WHEN DocumentHeader.KeepBackComissionFee
	|							THEN DocumentTable.AmountReceipt - DocumentTable.BrokerageAmount
	|						ELSE DocumentTable.AmountReceipt
	|					END
	|			END, 0)) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(ISNULL(CASE
	|				WHEN DocumentHeader.KeepBackComissionFee
	|					THEN DocumentTable.ReceiptVATAmount - DocumentTable.BrokerageVATAmount
	|				ELSE DocumentTable.ReceiptVATAmount
	|			END, 0)) AS VATAmount
	|FROM
	|	Document.ReportToPrincipal AS DocumentHeader
	|		LEFT JOIN Document.ReportToPrincipal.Inventory AS DocumentTable
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
	|	DocumentTable.PurchaseOrder,
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
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
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
	
EndProcedure // FillByReportToPrincipal()

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillBySupplierInvoiceForPayment(FillingData, LineNumber = Undefined, Amount = Undefined)
	
	Query = New Query();
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		Query.SetParameter("Amount", Amount);
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationKindsPaymentExpense.Vendor) AS OperationKind,
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
		|				OR VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.CustomerOrder)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS AdvanceFlag,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
		|			THEN DocumentHeader.BasisDocument
		|		ELSE UNDEFINED
		|	END AS Document,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.TrackPaymentsByBills
		|			THEN &Ref
		|		ELSE VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
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
		|	Document.SupplierInvoiceForPayment AS DocumentHeader
		|		LEFT JOIN Document.SupplierInvoiceForPayment.Inventory AS DocumentTable
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
		|	VALUE(Enum.OperationKindsCashPayment.Vendor) AS OperationKind,
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
		|				OR VALUETYPE(DocumentHeader.BasisDocument) = Type(Document.CustomerOrder)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS AdvanceFlag,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
		|			THEN DocumentHeader.BasisDocument
		|		ELSE UNDEFINED
		|	END AS Document,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.TrackPaymentsByBills
		|			THEN &Ref
		|		ELSE VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
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
		|	Document.SupplierInvoiceForPayment AS DocumentHeader
		|		LEFT JOIN Document.SupplierInvoiceForPayment.Inventory AS DocumentTable
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
		|	END";
		
	Else
	
		Query.SetParameter("Ref", FillingData.Basis);
		Query.SetParameter("LineNumber", LineNumber);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill document header data.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationKindsCashPayment.Vendor) AS OperationKind,
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
		|				OR VALUETYPE(DocumentTable.Ref.BasisDocument) = Type(Document.CustomerOrder)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS AdvanceFlag,
		|	CASE
		|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
		|			THEN DocumentTable.Ref.BasisDocument
		|		ELSE UNDEFINED
		|	END AS Document,
		|	CASE
		|		WHEN DocumentTable.Ref.Counterparty.TrackPaymentsByBills
		|			THEN DocumentTable.Ref
		|		ELSE VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
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
		|	Document.SupplierInvoiceForPayment.PaymentCalendar AS DocumentTable
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
		|			Document.SupplierInvoiceForPayment.Inventory AS DocumentTable
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
	
EndProcedure // FillBySupplierInvoiceForPayment()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByPurchaseOrder(FillingData, LineNumber = Undefined, Amount = Undefined)
	
	Query = New Query();
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		Query.SetParameter("Amount", Amount);
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationKindsPaymentExpense.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.PettyCash AS PettyCash,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	TRUE AS AdvanceFlag,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
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
		|	Document.PurchaseOrder AS DocumentHeader
		|		LEFT JOIN Document.PurchaseOrder.Inventory AS DocumentTable
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
		
		// Fill out the data from the document tabular section.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationKindsCashPayment.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
		|	END AS Order,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.PettyCash AS PettyCash,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	TRUE AS AdvanceFlag,
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
		|	Document.PurchaseOrder AS DocumentHeader
		|		LEFT JOIN Document.PurchaseOrder.Inventory AS DocumentTable
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
		|	DocumentTable.VATRate,
		|	SettlementsCurrencyRates.ExchangeRate,
		|	SettlementsCurrencyRates.Multiplicity,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
		|	END";
		
	Else
	
		Query.SetParameter("Ref", FillingData.Basis);
		Query.SetParameter("LineNumber", LineNumber);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill document header data.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationKindsCashPayment.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	CASE
		|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
		|	END AS Order,
		|	DocumentTable.Ref.Company AS Company,
		|	DocumentTable.Ref.VATTaxation AS VATTaxation,
		|	DocumentTable.Ref.DocumentCurrency AS CashCurrency,
		|	DocumentTable.Ref.PettyCash AS PettyCash,
		|	DocumentTable.Ref.Counterparty AS Counterparty,
		|	DocumentTable.Ref.Contract AS Contract,
		|	TRUE AS AdvanceFlag,
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
		|	Document.PurchaseOrder.PaymentCalendar AS DocumentTable
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
		|			Document.PurchaseOrder.Inventory AS DocumentTable
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
	
EndProcedure // FillByPurchaseOrder()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//
Procedure FillByPurchaseOrderDependOnBalanceForPayment(FillingData)
	
	Query = New Query();
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	Query.Text =
	"SELECT
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationKindsCashPayment.Vendor) AS OperationKind,
	|	&Date AS Date,
	|	&Ref AS BasisDocument,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN &Ref
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.PettyCash AS PettyCash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	TRUE AS AdvanceFlag,
	|	DocumentTable.VATRate AS VATRate,
	|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
	|	SettlementsCurrencyRates.Multiplicity AS Multiplicity,
	|	InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover AS DocumentAmount,
	|	InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover AS PaymentAmount,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * CASE
	|			WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
	|					AND SettlementsCurrencyRates.ExchangeRate <> 0
	|					AND CurrencyRatesOfDocument.Multiplicity <> 0
	|				THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
	|			ELSE 1
	|		END AS NUMBER(15, 2)) AS SettlementsAmount,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
	|FROM
	|	Document.PurchaseOrder AS DocumentHeader
	|		LEFT JOIN (SELECT TOP 1
	|			&Ref AS Ref,
	|			PurchaseOrderInventory.VATRate AS VATRate
	|		FROM
	|			Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		WHERE
	|			PurchaseOrderInventory.Ref = &Ref) AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
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
	
EndProcedure // FillByPurchaseOrderDependingOnBalanceForPayment()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByPayrollSheet(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	DocumentTable.Ref.Company AS Company,
	|	VALUE(Catalog.CashFlowItems.Other) AS Item,
	|	VALUE(Enum.OperationKindsCashPayment.Salary) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	&Ref AS Statement,
	|	DocumentTable.Ref.Company.PettyCashByDefault AS PettyCash,
	|	REFPRESENTATION(DocumentTable.Ref) AS Basis,
	|	DocumentTable.DocumentAmount AS DocumentAmount,
	|	DocumentTable.DocumentAmount AS PaymentAmount,
	|	DocumentTable.DocumentCurrency AS CashCurrency
	|FROM
	|	Document.PayrollSheet AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		PayrollPayment.Clear();
		NewRow = PayrollPayment.Add();
		FillPropertyValues(NewRow, Selection);
		
	EndIf;
	
EndProcedure // FillByPayrollSheet()

// Procedure of filling the document on the basis of tax accrual.
//
// Parameters:
// BasisDocument - DocumentRef.PaymentReceiptPlan - Scheduled payment 
// FillingData   - Structure - Data on filling the document.
//	
Procedure FillByTaxAccrual(BasisDocument)
	
	If BasisDocument.OperationKind <> Enums.OperationKindsTaxAccrual.Accrual Then
		Raise NStr("en='Cash expense can be entered only according to the accrual of taxes but not the refund.'");
	EndIf;

	Query = New Query;
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	Query.SetParameter("ConstantNationalCurrency", Constants.NationalCurrency.Get());
	Query.SetParameter("ConstantAccountingCurrency", Constants.AccountingCurrency.Get());
	
	Query.Text =
	"SELECT
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationKindsCashPayment.Taxes) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	VALUE(Catalog.CashFlowItems.Other) AS Item,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Company.PettyCashByDefault AS PettyCash,
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

// Procedure of cancellation of posting of subordinate invoice note (supplier)
//
Procedure SubordinatedInvoiceControl()
	
	InvoiceStructure = SmallBusinessServer.GetSubordinateInvoice(Ref, True);
	If Not InvoiceStructure = Undefined Then
		
		CustomerInvoiceNote	 = InvoiceStructure.Ref;
		If CustomerInvoiceNote.Posted Then
			
			MessageText = NStr("en = 'Due to the absence of the turnovers by the %CurrentDocumentPresentation% document, undo the posting of %InvoicePresentation%.'");
			MessageText = StrReplace(MessageText, "%CurrentDocumentPresentation%", """Expense in PettyCashes # " + Number + " dated " + Format(Date, "DF=dd.MM.yyyy") + """");
			MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Invoice Note (Supplier) # " + InvoiceStructure.Number + " dated " + InvoiceStructure.Date + """");
			
			CommonUseClientServer.MessageToUser(MessageText);
			
			InvoiceObject = CustomerInvoiceNote.GetObject();
			InvoiceObject.Write(DocumentWriteMode.UndoPosting);
			
		EndIf;
		
	EndIf;
	
EndProcedure //SubordinateInvoiceControl()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - handler of the OnCopy event.
//
Procedure OnCopy(CopiedObject)
	
	ReceiptCRNumber = "";
	
EndProcedure // OnCopy()

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.CashOutflowPlan") Then
		FillByCashOutflowPlan(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CashTransferPlan") Then
		FillByCashTransferPlan(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then
		FillByPurchaseInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AdditionalCosts") Then
		FillByAdditionalCosts(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AgentReport") Then
		FillByAgentReport(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ReportToPrincipal") Then
		FillByReportToPrincipal(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") Then
		FillByPurchaseOrder(FillingData);
	ElsIf TypeOf(FillingData)= Type("DocumentRef.SupplierInvoiceForPayment") Then
		FillBySupplierInvoiceForPayment(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PayrollSheet") Then
		FillByPayrollSheet(FillingData);
	ElsIf TypeOf(FillingData)= Type("DocumentRef.TaxAccrual") Then
		FillByTaxAccrual(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure")
			AND FillingData.Property("Basis") Then
		If FillingData.Property("ConsiderBalances") 
			AND TypeOf(FillingData.Basis)= Type("DocumentRef.PurchaseOrder") Then
			FillByPurchaseOrderDependOnBalanceForPayment(FillingData.Basis);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.SupplierInvoiceForPayment") Then
			FillBySupplierInvoiceForPayment(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.PurchaseOrder") Then
			FillByPurchaseOrder(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.CashOutflowPlan") Then
			FillByCashOutflowPlan(FillingData.Document, FillingData.Amount);
		EndIf;
	ElsIf TypeOf(FillingData) = Type("Structure")
			AND FillingData.Property("Document") Then
		If TypeOf(FillingData.Document) = Type("DocumentRef.SupplierInvoiceForPayment") Then
			FillBySupplierInvoiceForPayment(FillingData.Document, Undefined, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.PurchaseOrder") Then
			FillByPurchaseOrder(FillingData.Document, Undefined, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.CashOutflowPlan") Then
			FillByCashOutflowPlan(FillingData.Document, FillingData.Amount);
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
	If OperationKind = Enums.OperationKindsCashPayment.Vendor
	 OR OperationKind = Enums.OperationKindsCashPayment.ToCustomer Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Division");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		
		If Counterparty.DoOperationsByDocuments Then
			For Each RowPaymentDetails IN PaymentDetails Do
				If Not ValueIsFilled(RowPaymentDetails.Document)
					AND (OperationKind = Enums.OperationKindsCashPayment.ToCustomer
				   OR (OperationKind = Enums.OperationKindsCashPayment.Vendor
				   AND Not RowPaymentDetails.AdvanceFlag)) Then
					If PaymentDetails.Count() = 1 Then
						If OperationKind = Enums.OperationKindsCashPayment.Vendor Then
							MessageText = NStr("en = 'Specify the shipment document or the advance payment sign.'");
						Else
							MessageText = NStr("en = 'Specify the settlements document.'");
						EndIf;
					Else
						If OperationKind = Enums.OperationKindsCashPayment.Vendor Then
							MessageText = NStr("en = 'Specify the shipment document or payment flag in the %LineNumber% row of the ""Payment details"" list.'");
						Else
							MessageText = NStr("en = 'Specify the payment document in the row %LineNumber% of the list ""Payment details"".'");
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
			MessageText = NStr("en = 'Document amount: %DocumentAmount% %CashCurrency% does not correspond to the posted payments in the tabular section: %PaymentAmount% %CashCurrency%!'");
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
		
	ElsIf OperationKind = Enums.OperationKindsCashPayment.ToAdvanceHolder Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Division");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.UnitConversionFactor");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		
	ElsIf OperationKind = Enums.OperationKindsCashPayment.Salary Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.UnitConversionFactor");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Division");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		PaymentAmount = PayrollPayment.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en = 'Document amount: %DocumentAmount% %CashCurrency% does not correspond to the posted payments in the tabular section: %PaymentAmount% %CashCurrency%!'");
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
		
	ElsIf OperationKind = Enums.OperationKindsCashPayment.SalaryForEmployee Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.UnitConversionFactor");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		
	ElsIf OperationKind = Enums.OperationKindsCashPayment.Other Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		If Correspondence.TypeOfAccount <> Enums.GLAccountsTypes.Expenses Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Division");
		EndIf;
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.UnitConversionFactor");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		
	ElsIf OperationKind = Enums.OperationKindsCashPayment.TransferToCashCR Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Division");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.UnitConversionFactor");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		
	Else
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Division");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.UnitConversionFactor");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		
	EndIf;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Constants.FunctionalOptionAccountingByMultipleBusinessActivities.Get()
		  AND Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
		
		BusinessActivity = Catalogs.BusinessActivities.MainActivity;
		
	EndIf;
	
	For Each TSRow IN PaymentDetails Do
		If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = Counterparty.ContractByDefault;
		EndIf;
	EndDo;
	
EndProcedure // BeforeWrite()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.CashPayment.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectCashAssetsInCashRegisters(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAdvanceHolderPayments(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectPayrollPayments(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesUndistributed(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.CashPayment.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.CashPayment.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	// Subordinate invoice note (supplier)
	If Not Cancel Then
		
		SubordinatedInvoiceControl();
		
	EndIf;
	
EndProcedure // UndoPosting()

#EndIf