#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure for filling the payment destination in the document
//
Procedure FillPaymentDestination()
	
	PaymentText = "";
	
	If ValueIsFilled(CounterpartyAccount) Then
		If ValueIsFilled(CounterpartyAccount.CorrespondentText) Then
			PayeeText = CounterpartyAccount.CorrespondentText;
		EndIf;
		PaymentText = CounterpartyAccount.DestinationText;
	ElsIf ValueIsFilled(Counterparty) Then
		PayeeText = Counterparty.DescriptionFull;
	EndIf;
	
	If IsBlankString(PaymentText)
		AND ValueIsFilled(BasisDocument)
		AND TypeOf(BasisDocument) = Type("DocumentRef.SupplierInvoiceForPayment")
		AND ValueIsFilled(BasisDocument.IncomingDocumentNumber) Then
		PaymentText = NStr("en='Payment against the invoice for payment No.%AccountNumber%';ru='Оплата по счету N %НомерСчета%'");
		PaymentText = StrReplace(PaymentText, "%AccountNo%", TrimAll(String(BasisDocument.IncomingDocumentNumber)));
		If ValueIsFilled(BasisDocument.IncomingDocumentDate) Then
			PaymentText = PaymentText + " dated " + TrimAll(String(Format(BasisDocument.IncomingDocumentDate, "DF=dd MMMM yyyy'"))) + " g.";
		EndIf;
	EndIf;
	
	TextVAT = "";
	WithoutTaxVAT = True;
	
	If ValueIsFilled(VATRate)
	AND Not VATRate.NotTaxable Then
		TextVAT = NStr("en='VAT(%VATRate%) %VATAmount%';ru='НДС(%VATRate%) %VATAmount%'");
		TextVAT = StrReplace(TextVAT, "%VATRate%", String(VATRate));
		TextVAT = StrReplace(TextVAT, "%VATAmount%", String(Format(VATAmount, "ND=15; NFD=2; NDS=-; NZ=0-00; NG=")));
		WithoutTaxVAT = False;
	EndIf;
	
	If ValueIsFilled(VATAmount)
	AND Not ValueIsFilled(VATRate) Then
		TextVAT = NStr("en='VAT %VATAmount%';ru='НДС %СуммаНДС%'");
		TextVAT = StrReplace(TextVAT, "%VATAmount%", String(Format(VATAmount, "ND=15; NFD=2; NDS=-; NZ=0-00; NG=")));
		WithoutTaxVAT = False;
	EndIf;
	
	TextAmount = String(Format(DocumentAmount, "ND=15; NFD=2; NDS=-; NZ=0-00; NG="));
	
	TextPaymentDestination = NStr("en='%TextDestination% Amount %TextAmount% %VATRateValue% %TextVAT%';ru='%ТекстНазначение% Сумма %ТекстСумма% %ЗначениеСтавкиНДС% %ТекстНДС%'"
	);
	
	TextPaymentDestination = StrReplace(TextPaymentDestination, "%TextDestination%", PaymentText);
	TextPaymentDestination = StrReplace(TextPaymentDestination, "%TextAmount%", TextAmount);
	TextPaymentDestination = StrReplace(TextPaymentDestination, "%VATRateValue%", ?(WithoutTaxVAT, NStr("en='Without tax (VAT)';ru='Без налога (НДС)'"), NStr("en='including';ru='В т.ч.'")));
	TextPaymentDestination = StrReplace(TextPaymentDestination, "%TextVAT%", TextVAT);
	
	PaymentDestination = TextPaymentDestination;
	
EndProcedure // FillPaymentDestination()

// Procedure of document filling based on purchase order.
//
// Parameters:
//  BasisDocument - DocumentRef.PurchaseOrder - Purchase order
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByPurchaseOrder(BasisDocument, Amount = Undefined)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", CurrentDate());
	
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsPaymentOrder.Payment) AS OperationKind,
	|	DocumentTable.Ref.Company AS Company,
	|	BankOfAccount.CompanyBankAcc AS BankAccount,
	|	BankOfAccount.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Ref.Counterparty AS Counterparty,
	|	BankOfAccount.CounterpartyBankAcc AS CounterpartyAccount,
	|	DocumentTable.Ref.Company.TIN AS PayerTIN,
	|	DocumentTable.Ref.Counterparty.TIN AS PayeeTIN,
	|	CAST(DocumentTable.Ref.Counterparty.BankAccountByDefault.CorrespondentText AS STRING(1000)) AS CorrespondentText,
	|	CAST(DocumentTable.Ref.Counterparty.BankAccountByDefault.DestinationText AS STRING(1000)) AS DestinationText,
	|	CAST(DocumentTable.Ref.Counterparty.DescriptionFull AS STRING(1000)) AS DescriptionFull,
	|	SUM(CAST(DocumentTable.Total * CASE
	|				WHEN DocumentTable.Ref.DocumentCurrency <> BankOfAccount.CompanyBankAcc.CashCurrency
	|						AND CurrencyRatesOfDocument.Multiplicity <> 0
	|						AND BankAcountCurrencyRates.ExchangeRate <> 0
	|					THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
	|				ELSE 1
	|			END AS NUMBER(15, 2))) AS DocumentAmount,
	|	SUM(CAST(DocumentTable.VATAmount * CASE
	|				WHEN DocumentTable.Ref.DocumentCurrency <> BankOfAccount.CompanyBankAcc.CashCurrency
	|						AND CurrencyRatesOfDocument.Multiplicity <> 0
	|						AND BankAcountCurrencyRates.ExchangeRate <> 0
	|					THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
	|				ELSE 1
	|			END AS NUMBER(15, 2))) AS VATAmount,
	|	CASE
	|		WHEN DocumentVATRate.DistinctRatesCount = 1
	|			THEN DocumentTable.VATRate
	|		ELSE UNDEFINED
	|	END AS VATRate,
	|	DocumentVATRate.DistinctRatesCount AS DistinctRatesCount,
	|	DocumentTable.Ref AS BasisDocument
	|FROM
	|	Document.PurchaseOrder.Inventory AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
	|		ON DocumentTable.Ref.DocumentCurrency = CurrencyRatesOfDocument.Currency
	|		LEFT JOIN (SELECT
	|			COUNT(DISTINCT PurchaseOrderInventory.VATRate) AS DistinctRatesCount,
	|			PurchaseOrderInventory.Ref AS Ref
	|		FROM
	|			Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		WHERE
	|			PurchaseOrderInventory.Ref = &Ref
	|		
	|		GROUP BY
	|			PurchaseOrderInventory.Ref) AS DocumentVATRate
	|		ON DocumentTable.Ref = DocumentVATRate.Ref,
	|	(SELECT TOP 1
	|		CASE
	|			WHEN NOT PurchaseOrder.BankAccount = VALUE(Catalog.BankAccounts.EmptyRef)
	|				THEN PurchaseOrder.BankAccount
	|			WHEN PurchaseOrder.DocumentCurrency = PurchaseOrder.Company.BankAccountByDefault.CashCurrency
	|				THEN PurchaseOrder.Company.BankAccountByDefault
	|			ELSE CompanyBankAccs.Ref
	|		END AS CompanyBankAcc,
	|		CASE
	|			WHEN PurchaseOrder.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
	|				THEN PurchaseOrder.BankAccount.CashCurrency
	|			WHEN PurchaseOrder.DocumentCurrency = PurchaseOrder.Company.BankAccountByDefault.CashCurrency
	|				THEN PurchaseOrder.Company.BankAccountByDefault.CashCurrency
	|			WHEN CompanyBankAccs.Ref <> VALUE(Catalog.BankAccounts.EmptyRef)
	|				THEN CompanyBankAccs.Ref.CashCurrency
	|			ELSE PurchaseOrder.DocumentCurrency
	|		END AS DocumentCurrency,
	|		CASE
	|			WHEN PurchaseOrder.DocumentCurrency = PurchaseOrder.Counterparty.BankAccountByDefault.CashCurrency
	|				THEN PurchaseOrder.Counterparty.BankAccountByDefault
	|			ELSE CounterpartyBankAccs.Ref
	|		END AS CounterpartyBankAcc
	|	FROM
	|		Document.PurchaseOrder AS PurchaseOrder
	|			LEFT JOIN Catalog.BankAccounts AS CounterpartyBankAccs
	|			ON PurchaseOrder.DocumentCurrency = CounterpartyBankAccs.CashCurrency
	|				AND PurchaseOrder.Counterparty = CounterpartyBankAccs.Owner
	|			LEFT JOIN Catalog.BankAccounts AS CompanyBankAccs
	|			ON PurchaseOrder.Company = CompanyBankAccs.Owner
	|				AND PurchaseOrder.DocumentCurrency = CompanyBankAccs.CashCurrency
	|	WHERE
	|		PurchaseOrder.Ref = &Ref) AS BankOfAccount
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS BankAcountCurrencyRates
	|		ON BankOfAccount.CompanyBankAcc.CashCurrency = BankAcountCurrencyRates.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentVATRate.DistinctRatesCount = 1
	|			THEN DocumentTable.VATRate
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.Ref.Company,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Counterparty.TIN,
	|	CAST(DocumentTable.Ref.Counterparty.BankAccountByDefault.CorrespondentText AS STRING(1000)),
	|	CAST(DocumentTable.Ref.Counterparty.DescriptionFull AS STRING(1000)),
	|	CAST(DocumentTable.Ref.Counterparty.BankAccountByDefault.DestinationText AS STRING(1000)),
	|	DocumentVATRate.DistinctRatesCount,
	|	BankOfAccount.CompanyBankAcc,
	|	BankOfAccount.DocumentCurrency,
	|	BankOfAccount.CounterpartyBankAcc,
	|	DocumentTable.Ref,
	|	DocumentTable.Ref.Company.TIN";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		FillPaymentDestination();
		
	EndIf;
	
EndProcedure // FillByPurchaseOrder()

// Procedure for filling the document basing on the supplier invoice for payment.
//
// Parameters:
//  BasisDocument - DocumentRef.PurchaseOrder - Purchase order
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillBySupplierInvoiceForPayment(BasisDocument, Amount = Undefined)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", CurrentDate());
	
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsPaymentOrder.Payment) AS OperationKind,
	|	DocumentTable.Ref.Company AS Company,
	|	BankOfAccount.CompanyBankAcc AS BankAccount,
	|	BankOfAccount.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Ref.Counterparty AS Counterparty,
	|	BankOfAccount.CounterpartyBankAcc AS CounterpartyAccount,
	|	DocumentTable.Ref.Company.TIN AS PayerTIN,
	|	DocumentTable.Ref.Counterparty.TIN AS PayeeTIN,
	|	CAST(DocumentTable.Ref.Counterparty.BankAccountByDefault.CorrespondentText AS STRING(1000)) AS CorrespondentText,
	|	CAST(DocumentTable.Ref.Counterparty.BankAccountByDefault.DestinationText AS STRING(1000)) AS DestinationText,
	|	CAST(DocumentTable.Ref.Counterparty.DescriptionFull AS STRING(1000)) AS DescriptionFull,
	|	SUM(CAST(DocumentTable.Total * CASE
	|				WHEN DocumentTable.Ref.DocumentCurrency <> BankOfAccount.CompanyBankAcc.CashCurrency
	|						AND CurrencyRatesOfDocument.Multiplicity <> 0
	|						AND BankAcountCurrencyRates.ExchangeRate <> 0
	|					THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
	|				ELSE 1
	|			END AS NUMBER(15, 2))) AS DocumentAmount,
	|	SUM(CAST(DocumentTable.VATAmount * CASE
	|				WHEN DocumentTable.Ref.DocumentCurrency <> BankOfAccount.CompanyBankAcc.CashCurrency
	|						AND CurrencyRatesOfDocument.Multiplicity <> 0
	|						AND BankAcountCurrencyRates.ExchangeRate <> 0
	|					THEN CurrencyRatesOfDocument.ExchangeRate * BankAcountCurrencyRates.Multiplicity / (ISNULL(BankAcountCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
	|				ELSE 1
	|			END AS NUMBER(15, 2))) AS VATAmount,
	|	CASE
	|		WHEN DocumentVATRate.DistinctRatesCount = 1
	|			THEN DocumentTable.VATRate
	|		ELSE UNDEFINED
	|	END AS VATRate,
	|	DocumentVATRate.DistinctRatesCount AS DistinctRatesCount,
	|	DocumentTable.Ref AS BasisDocument
	|FROM
	|	Document.SupplierInvoiceForPayment.Inventory AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS CurrencyRatesOfDocument
	|		ON DocumentTable.Ref.DocumentCurrency = CurrencyRatesOfDocument.Currency
	|		LEFT JOIN (SELECT
	|			COUNT(DISTINCT SupplierInvoiceForPaymentInventory.VATRate) AS DistinctRatesCount,
	|			SupplierInvoiceForPaymentInventory.Ref AS Ref
	|		FROM
	|			Document.SupplierInvoiceForPayment.Inventory AS SupplierInvoiceForPaymentInventory
	|		WHERE
	|			SupplierInvoiceForPaymentInventory.Ref = &Ref
	|		
	|		GROUP BY
	|			SupplierInvoiceForPaymentInventory.Ref) AS DocumentVATRate
	|		ON DocumentTable.Ref = DocumentVATRate.Ref,
	|	(SELECT TOP 1
	|		CASE
	|			WHEN SupplierInvoiceForPayment.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
	|				THEN SupplierInvoiceForPayment.BankAccount
	|			WHEN SupplierInvoiceForPayment.DocumentCurrency = SupplierInvoiceForPayment.Company.BankAccountByDefault.CashCurrency
	|				THEN SupplierInvoiceForPayment.Company.BankAccountByDefault
	|			ELSE CompanyBankAccs.Ref
	|		END AS CompanyBankAcc,
	|		CASE
	|			WHEN SupplierInvoiceForPayment.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
	|				THEN SupplierInvoiceForPayment.BankAccount.CashCurrency
	|			WHEN SupplierInvoiceForPayment.DocumentCurrency = SupplierInvoiceForPayment.Company.BankAccountByDefault.CashCurrency
	|				THEN SupplierInvoiceForPayment.Company.BankAccountByDefault.CashCurrency
	|			WHEN CompanyBankAccs.Ref <> VALUE(Catalog.BankAccounts.EmptyRef)
	|				THEN CompanyBankAccs.Ref.CashCurrency
	|			ELSE SupplierInvoiceForPayment.DocumentCurrency
	|		END AS DocumentCurrency,
	|		CASE
	|			WHEN SupplierInvoiceForPayment.DocumentCurrency = SupplierInvoiceForPayment.Counterparty.BankAccountByDefault.CashCurrency
	|				THEN SupplierInvoiceForPayment.Counterparty.BankAccountByDefault
	|			ELSE CounterpartyBankAccs.Ref
	|		END AS CounterpartyBankAcc
	|	FROM
	|		Document.SupplierInvoiceForPayment AS SupplierInvoiceForPayment
	|			LEFT JOIN Catalog.BankAccounts AS CounterpartyBankAccs
	|			ON SupplierInvoiceForPayment.DocumentCurrency = CounterpartyBankAccs.CashCurrency
	|				AND SupplierInvoiceForPayment.Counterparty = CounterpartyBankAccs.Owner
	|			LEFT JOIN Catalog.BankAccounts AS CompanyBankAccs
	|			ON SupplierInvoiceForPayment.Company = CompanyBankAccs.Owner
	|				AND SupplierInvoiceForPayment.DocumentCurrency = CompanyBankAccs.CashCurrency
	|	WHERE
	|		SupplierInvoiceForPayment.Ref = &Ref) AS BankOfAccount
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, ) AS BankAcountCurrencyRates
	|		ON BankOfAccount.CompanyBankAcc.CashCurrency = BankAcountCurrencyRates.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentVATRate.DistinctRatesCount = 1
	|			THEN DocumentTable.VATRate
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.Ref.Company,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Counterparty.TIN,
	|	CAST(DocumentTable.Ref.Counterparty.BankAccountByDefault.CorrespondentText AS STRING(1000)),
	|	CAST(DocumentTable.Ref.Counterparty.DescriptionFull AS STRING(1000)),
	|	CAST(DocumentTable.Ref.Counterparty.BankAccountByDefault.DestinationText AS STRING(1000)),
	|	DocumentVATRate.DistinctRatesCount,
	|	BankOfAccount.CompanyBankAcc,
	|	BankOfAccount.DocumentCurrency,
	|	BankOfAccount.CounterpartyBankAcc,
	|	DocumentTable.Ref,
	|	DocumentTable.Ref.Company.TIN";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		FillPaymentDestination();
		
	EndIf;
	
EndProcedure // FillBySupplierInvoiceForPayment()

// Procedure for filling the document basing on the Cash outflow plan.
//
// Parameters:
//  BasisDocument - DocumentRef.CashOutflowPlan - Application
// on expense DC FillingData - Structure - Data on filling the document.
//	
Procedure FillByCashOutflowPlan(BasisDocument);
	
	If BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.NotApproved Then
		Raise NStr("en='You can not enter a payment order on the basis of non-confirmed application!';ru='Нельзя ввести платежное поручение на основании не утвержденной заявки!'");
	EndIf;
	If BasisDocument.CashAssetsType = Enums.CashAssetTypes.Cash Then
		Raise NStr("en='You can not enter a payment order. Invalid payment method is specified in the application (cash assets type)!';ru='Нельзя ввести платежное поручение. В заявке указан не верный способ оплаты (тип денежных средств)!'");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("BasisDocument", BasisDocument);
	Query.SetParameter("Date", 	CurrentDate());
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsPaymentOrder.Payment) AS OperationKind,
	|	&BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN DocumentTable.BasisDocument REFS Document.SupplierInvoiceForPayment
	|			THEN DocumentTable.BasisDocument
	|		ELSE VALUE(Document.SupplierInvoiceForPayment.EmptyRef)
	|	END AS InvoiceForPayment,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.BasisDocument REFS Document.SupplierInvoiceForPayment
	|				OR DocumentTable.BasisDocument REFS Document.PurchaseOrder
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AdvanceFlag,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.BankAccount AS BankAccount,
	|	NestedSelect.CounterpartyBankAcc AS CounterpartyAccount,
	|	DocumentTable.Company.TIN AS PayerTIN,
	|	DocumentTable.Counterparty.TIN AS PayeeTIN,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
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
	|		LEFT JOIN (SELECT TOP 1
	|			CASE
	|				WHEN DocumentTable.DocumentCurrency = DocumentTable.Counterparty.BankAccountByDefault.CashCurrency
	|					THEN DocumentTable.Counterparty.BankAccountByDefault
	|				ELSE CounterpartyBankAccs.Ref
	|			END AS CounterpartyBankAcc
	|		FROM
	|			Document.CashOutflowPlan AS DocumentTable
	|				LEFT JOIN Catalog.BankAccounts AS CounterpartyBankAccs
	|				ON DocumentTable.DocumentCurrency = CounterpartyBankAccs.CashCurrency
	|					AND DocumentTable.Counterparty = CounterpartyBankAccs.Owner
	|		WHERE
	|			DocumentTable.Ref = &BasisDocument
	|			AND CounterpartyBankAccs.DeletionMark = FALSE) AS NestedSelect
	|		ON (TRUE)
	|WHERE
	|	DocumentTable.Ref = &BasisDocument";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
		If BasisDocument.DocumentCurrency = Counterparty.BankAccountByDefault.CashCurrency Then
			CounterpartyAccount = Counterparty.BankAccountByDefault;
		EndIf;
		
		FillPaymentDestination();
		
	EndIf;
	
EndProcedure //FillByCashOutflowPlan()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If OperationKind <> Enums.OperationKindsPaymentOrder.TaxTransfer Then
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "TransferToBudgetKind");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "BKCode");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "OKATOCode");
	EndIf;
	
EndProcedure // FillCheckProcessing()

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") Then
		FillByPurchaseOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoiceForPayment") Then
		FillBySupplierInvoiceForPayment(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CashOutflowPlan") Then
		FillByCashOutflowPlan(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure")
			AND FillingData.Property("Document") Then
		If TypeOf(FillingData.Document) = Type("DocumentRef.SupplierInvoiceForPayment") Then
			FillBySupplierInvoiceForPayment(FillingData.Document, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.PurchaseOrder") Then
			FillByPurchaseOrder(FillingData.Document, FillingData.Amount);
		ElsIf TypeOf(FillingData) = Type("DocumentRef.CashOutflowPlan") Then
			FillByCashOutflowPlan(FillingData);
		EndIf;
	EndIf;
	
EndProcedure // FillingProcessor()

Procedure OnCopy(CopiedObject)
	
	#If Not ExternalConnection Then
		
	If ValueIsFilled(CopiedObject.Ref)
	   AND CopiedObject.OperationKind = PredefinedValue("Enum.OperationKindsPaymentOrder.TaxTransfer")
	   AND ((SmallBusinessClientServer.PaymentToBudgetAttributesNewRulesApplied(CopiedObject.Date)
	   AND Not SmallBusinessClientServer.PaymentToBudgetAttributesNewRulesApplied(CurrentDate()))
	   OR (NOT SmallBusinessClientServer.PaymentToBudgetAttributesNewRulesApplied(CopiedObject.Date)
	   AND SmallBusinessClientServer.PaymentToBudgetAttributesNewRulesApplied(Date))) Then
		OKATOCode = "";
		PaymentIdentifier = "";
	EndIf;
	
	#EndIf
	
EndProcedure

#EndIf