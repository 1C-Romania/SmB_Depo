#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// The procedure fills in the document using PurchaseOrder
//
Procedure FillByPurchaseOrder(FillingData)
	
	Query = New Query(
	"SELECT
	|	Document.Ref AS BasisDocument,
	|	VALUE(Enum.OperationKindsSupplierInvoiceNote.Advance) AS OperationKind,
	|	Document.Company,
	|	Document.Counterparty,
	|	Document.Contract AS Contract,
	|	Document.DocumentCurrency,
	|	Document.ExchangeRate,
	|	Document.Multiplicity,
	|	Document.Inventory.(
	|		ProductsAndServices,
	|		Characteristic,
	|		MeasurementUnit,
	|		Quantity,
	|		CASE
	|			WHEN Document.Inventory.Quantity = 0
	|				THEN 0
	|			WHEN Document.AmountIncludesVAT
	|				THEN Document.Inventory.Amount / ((Document.Inventory.VATRate.Rate + 100) / 100) / Document.Inventory.Quantity
	|			ELSE Document.Inventory.Amount / Document.Inventory.Quantity
	|		END AS Price,
	|		CASE
	|			WHEN Document.AmountIncludesVAT
	|				THEN Document.Inventory.Amount / ((Document.Inventory.VATRate.Rate + 100) / 100)
	|			ELSE Document.Inventory.Amount
	|		END AS Amount,
	|		VATRate,
	|		VATAmount,
	|		Total,
	|		Content
	|	)
	|FROM
	|	Document.PurchaseOrder AS Document
	|WHERE
	|	Document.Ref = &Ref");
	
	Query.SetParameter("Ref", FillingData);
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	If QueryResultSelection.Next() Then
		
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		If DocumentCurrency <> Constants.NationalCurrency.Get() Then
			
			StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
			ExchangeRate = StructureByCurrency.ExchangeRate;
			Multiplicity = StructureByCurrency.Multiplicity;
			
		EndIf;
		
		Inventory.Load(QueryResultSelection.Inventory.Unload());
		
	EndIf;
	
EndProcedure // FillByPurchaseOrder()

// The procedure fills in the document using AdditionalCosts
//
Procedure FillByAdditionalExpence(FillingData)
	
	Query = New Query(
	"SELECT
	|	Document.Ref AS BasisDocument,
	|	VALUE(Enum.OperationKindsSupplierInvoiceNote.Receipt) AS OperationKind,
	|	Document.Company,
	|	Document.Counterparty,
	|	Document.Contract,
	|	Document.DocumentCurrency,
	|	Document.ExchangeRate,
	|	Document.Multiplicity,
	|	Document.Expenses.(
	|		ProductsAndServices,
	|		MeasurementUnit,
	|		Quantity,
	|		CASE
	|			WHEN Document.Expenses.Quantity = 0
	|				THEN 0
	|			WHEN Document.AmountIncludesVAT
	|				THEN Document.Expenses.Amount / ((Document.Expenses.VATRate.Rate + 100) / 100) / Document.Expenses.Quantity
	|			ELSE Document.Expenses.Amount / Document.Expenses.Quantity
	|		END AS Price,
	|		CASE
	|			WHEN Document.AmountIncludesVAT
	|				THEN Document.Expenses.Amount / ((Document.Expenses.VATRate.Rate + 100) / 100)
	|			ELSE Document.Expenses.Amount
	|		END AS Amount,
	|		VATRate,
	|		VATAmount,
	|		Total
	|	)
	|FROM
	|	Document.AdditionalCosts AS Document
	|WHERE
	|	Document.Ref = &Ref");
	
	Query.SetParameter("Ref", FillingData);
	QueryResult = Query.Execute();
	QueryResultSelection = QueryResult.Select();
	If QueryResultSelection.Next() Then		
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		If DocumentCurrency <> Constants.NationalCurrency.Get() Then
			StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
			ExchangeRate = StructureByCurrency.ExchangeRate;
			Multiplicity = StructureByCurrency.Multiplicity;
		EndIf;
		
		Inventory.Load(QueryResultSelection.Expenses.Unload());
		
	EndIf;
	
EndProcedure // FillByAdditionalExpence()

// The procedure fills in the document using ExpenseReport
//
Procedure FillByExpenseReport(FillingData)
	
	Query = New Query(
	"SELECT
	|	Document.Ref AS BasisDocument,
	|	VALUE(Enum.OperationKindsSupplierInvoiceNote.Receipt) AS OperationKind,
	|	Document.Company,
	|	Document.DocumentCurrency,
	|	Document.ExchangeRate,
	|	Document.Multiplicity,
	|	Document.Inventory.(
	|		ProductsAndServices,
	|		Characteristic,
	|		Batch,
	|		MeasurementUnit,
	|		Quantity,
	|		CASE
	|			WHEN Document.Inventory.Quantity = 0
	|				THEN 0
	|			WHEN Document.AmountIncludesVAT
	|				THEN Document.Inventory.Amount / ((Document.Inventory.VATRate.Rate + 100) / 100) / Document.Inventory.Quantity
	|			ELSE Document.Inventory.Amount / Document.Inventory.Quantity
	|		END AS Price,
	|		CASE
	|			WHEN Document.AmountIncludesVAT
	|				THEN Document.Inventory.Amount / ((Document.Inventory.VATRate.Rate + 100) / 100)
	|			ELSE Document.Inventory.Amount
	|		END AS Amount,
	|		VATRate,
	|		VATAmount,
	|		Total
	|	),
	|	Document.Expenses.(
	|		ProductsAndServices AS ProductsAndServices,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		CASE
	|			WHEN Document.Expenses.Quantity = 0
	|				THEN 0
	|			WHEN Document.AmountIncludesVAT
	|				THEN Document.Expenses.Amount / ((Document.Expenses.VATRate.Rate + 100) / 100) / Document.Expenses.Quantity
	|			ELSE Document.Expenses.Amount / Document.Expenses.Quantity
	|		END AS Price,
	|		CASE
	|			WHEN Document.AmountIncludesVAT
	|				THEN Document.Expenses.Amount / ((Document.Expenses.VATRate.Rate + 100) / 100)
	|			ELSE Document.Expenses.Amount
	|		END AS Amount,
	|		VATRate AS VATRate,
	|		VATAmount AS VATAmount,
	|		Total AS Total
	|	)
	|FROM
	|	Document.ExpenseReport AS Document
	|WHERE
	|	Document.Ref = &Ref");
	
	Query.SetParameter("Ref", FillingData);
	QueryResult = Query.Execute();
	QueryResultSelection = QueryResult.Select();
	If QueryResultSelection.Next() Then
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		If DocumentCurrency <> Constants.NationalCurrency.Get() Then
			StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", DocumentCurrency));
			ExchangeRate = StructureByCurrency.ExchangeRate;
			Multiplicity = StructureByCurrency.Multiplicity;
		EndIf;
		
		Inventory.Load(QueryResultSelection.Inventory.Unload());
		
		For Each TabularSectionRow IN QueryResultSelection.Expenses.Unload() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
		EndDo;
	EndIf;
	
EndProcedure // FillByExpenseReport()

// The procedure fills in the document using SupplierInvoice
//
Procedure FillByInvoiceReceipt(FillingData)
	
	Query = New Query(
	"SELECT
	|	Document.Ref AS BasisDocument,
	|	VALUE(Enum.OperationKindsSupplierInvoiceNote.Receipt) AS OperationKind,
	|	Document.Company,
	|	Document.Counterparty,
	|	Document.Contract,
	|	Document.DocumentCurrency,
	|	Document.ExchangeRate,
	|	Document.Multiplicity,
	|	Document.Inventory.(
	|		ProductsAndServices,
	|		Characteristic,
	|		Batch,
	|		Content,
	|		MeasurementUnit,
	|		Quantity,
	|		CASE
	|			WHEN Document.Inventory.Quantity = 0
	|				THEN 0
	|			WHEN Document.AmountIncludesVAT
	|				THEN Document.Inventory.Amount / ((Document.Inventory.VATRate.Rate + 100) / 100) / Document.Inventory.Quantity
	|			ELSE Document.Inventory.Amount / Document.Inventory.Quantity
	|		END AS Price,
	|		CASE
	|			WHEN Document.AmountIncludesVAT
	|				THEN Document.Inventory.Amount / ((Document.Inventory.VATRate.Rate + 100) / 100)
	|			ELSE Document.Inventory.Amount
	|		END AS Amount,
	|		VATRate,
	|		VATAmount,
	|		Total
	|	),
	|	Document.Expenses.(
	|		ProductsAndServices AS ProductsAndServices,
	|		Content AS Content,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		CASE
	|			WHEN Document.Expenses.Quantity = 0
	|				THEN 0
	|			WHEN Document.AmountIncludesVAT
	|				THEN Document.Expenses.Amount / ((Document.Expenses.VATRate.Rate + 100) / 100) / Document.Expenses.Quantity
	|			ELSE Document.Expenses.Amount / Document.Expenses.Quantity
	|		END AS Price,
	|		CASE
	|			WHEN Document.AmountIncludesVAT
	|				THEN Document.Expenses.Amount / ((Document.Expenses.VATRate.Rate + 100) / 100)
	|			ELSE Document.Expenses.Amount
	|		END AS Amount,
	|		VATRate AS VATRate,
	|		VATAmount AS VATAmount,
	|		Total AS Total
	|	)
	|FROM
	|	Document.SupplierInvoice AS Document
	|WHERE
	|	Document.Ref = &Ref");
	
	Query.SetParameter("Ref", FillingData);
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	If QueryResultSelection.Next() Then
		
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		If DocumentCurrency <> Constants.NationalCurrency.Get() Then
			
			StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
			ExchangeRate = StructureByCurrency.ExchangeRate;
			Multiplicity = StructureByCurrency.Multiplicity;
			
		EndIf;
		
		Inventory.Load(QueryResultSelection.Inventory.Unload());
		
		For Each TabularSectionRow IN QueryResultSelection.Expenses.Unload() Do
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			
		EndDo;
		
	EndIf;
	
	
EndProcedure // FillByInvoiceReceipt()

// The procedure fills in the document using SubcontractorReport
//
Procedure FillByReportProcesser(FillingData)
	
	Inventory.Clear();
	
	Query = New Query(
	"SELECT
	|	Document.Ref AS BasisDocument,
	|	VALUE(Enum.OperationKindsSupplierInvoiceNote.Receipt) AS OperationKind,
	|	Document.Company,
	|	Document.Counterparty,
	|	Document.Contract,
	|	Document.DocumentCurrency,
	|	Document.ExchangeRate,
	|	Document.Multiplicity,
	|	Document.Expense AS ProductsAndServices,
	|	Document.Expense.MeasurementUnit AS MeasurementUnit,
	|	1 AS Quantity,
	|	CASE
	|		WHEN Document.AmountIncludesVAT
	|			THEN Document.Amount / ((Document.VATRate.Rate + 100) / 100)
	|		ELSE Document.Amount
	|	END AS Price,
	|	CASE
	|		WHEN Document.AmountIncludesVAT
	|			THEN Document.Amount / ((Document.VATRate.Rate + 100) / 100)
	|		ELSE Document.Amount
	|	END AS Amount,
	|	Document.VATRate,
	|	Document.VATAmount,
	|	Document.Total
	|FROM
	|	Document.SubcontractorReport AS Document
	|WHERE
	|	Document.Ref = &Ref");
	
	Query.SetParameter("Ref", FillingData);
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	If QueryResultSelection.Next() Then
		
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		If DocumentCurrency <> Constants.NationalCurrency.Get() Then
			
			StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
			ExchangeRate = StructureByCurrency.ExchangeRate;
			Multiplicity = StructureByCurrency.Multiplicity;
			
		EndIf;
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, QueryResultSelection);
		
	EndIf;
	
EndProcedure // FillByReportProcesser()

// The procedure fills in the document using CashReceipt or PaymentReceipt
// 
Procedure FillByCashBankDocument(FillingData)
	
	MetadataDocumentName = ?(TypeOf(FillingData) = Type("DocumentRef.CashPayment"), "CashPayment", "PaymentExpense");
	
	NameDocumentTable = "Document." + MetadataDocumentName;
	PaymentDetailsTableName = NameDocumentTable + ".PaymentDetails";
	
	QueryText = 
	"SELECT
	|	VALUE(Enum.OperationKindsSupplierInvoiceNote.Advance) AS OperationKind,
	|	CashPayment.Company,
	|	CashPayment.Counterparty,
	|	CashPayment.CashCurrency AS DocumentCurrency,
	|	TSContract.Contract,
	|	1 AS ExchangeRate,
	|	1 AS Multiplicity,
	|	""Prepayment"" AS Content,
	|	TSPaymentAmount.VATRate,
	|	TSPaymentAmount.PaymentAmount AS Amount,
	|	TSPaymentAmount.VATAmount,
	|	TSPaymentAmount.Total
	|FROM
	|	&NameDocumentTable AS CashPayment,
	|	(SELECT
	|		CashExpensePaymentDetails.Ref AS Ref,
	|		SUM(CashExpensePaymentDetails.PaymentAmount - CashExpensePaymentDetails.VATAmount) AS PaymentAmount,
	|		SUM(CashExpensePaymentDetails.VATAmount) AS VATAmount,
	|		CashExpensePaymentDetails.VATRate AS VATRate,
	|		SUM(CashExpensePaymentDetails.PaymentAmount) AS Total
	|	FROM
	|		&PaymentDetailsTableName AS CashExpensePaymentDetails
	|	WHERE
	|		CashExpensePaymentDetails.Ref = &Ref
	|		AND CashExpensePaymentDetails.AdvanceFlag
	|		AND CashExpensePaymentDetails.VATRate.Rate > 0
	|		AND Not CashExpensePaymentDetails.VATRate.NotTaxable
	|	
	|	GROUP BY
	|		CashExpensePaymentDetails.Ref,
	|		CashExpensePaymentDetails.VATRate) AS TSPaymentAmount,
	|	(SELECT TOP 1
	|		CashExpensePaymentDetails.Contract AS Contract,
	|		CashExpensePaymentDetails.ExchangeRate AS ExchangeRate,
	|		CashExpensePaymentDetails.Multiplicity AS Multiplicity
	|	FROM
	|		&PaymentDetailsTableName AS CashExpensePaymentDetails
	|	WHERE
	|		CashExpensePaymentDetails.Ref = &Ref
	|		AND CashExpensePaymentDetails.AdvanceFlag
	|		AND CashExpensePaymentDetails.VATRate.Rate > 0
	|		AND Not CashExpensePaymentDetails.VATRate.NotTaxable) AS TSContract
	|WHERE
	|	CashPayment.Ref = &Ref";
	
	QueryText = StrReplace(QueryText, "&NameDocumentTable", NameDocumentTable);
	QueryText = StrReplace(QueryText, "&PaymentDetailsTableName", PaymentDetailsTableName);
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", FillingData);
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	If QueryResultSelection.Next() Then
		
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		If FillingData.PaymentDetails.Count() > 0 Then
			
			ThisObject.Contract = FillingData.PaymentDetails[0].Contract;
			
		EndIf;
		
		ThisObject.BasisDocument = FillingData;
		
		If DocumentCurrency <> Constants.NationalCurrency.Get() Then
			
			StructureByCurrency	= InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", DocumentCurrency));
			ExchangeRate 				= StructureByCurrency.ExchangeRate;
			Multiplicity			= StructureByCurrency.Multiplicity;
			
		EndIf;
		
		Inventory.Load(QueryResult.Unload());
		
		// Fill in quantity and price to provide correct calculation
		For Each StringSupplies IN Inventory Do 
			
			StringSupplies.Quantity = 1;
			StringSupplies.Price = StringSupplies.Amount;
			
		EndDo;
		
		// If VAT rate is not calculated, then substitute a payment rate
		For Each NewRow IN Inventory Do
			
			If ValueIsFilled(NewRow.VATRate) AND Not NewRow.VATRate.Calculated Then
				
				NewRow.VATRate = SmallBusinessReUse.GetVATRateEstimated(NewRow.VATRate);
				
			EndIf;
			
		EndDo;
		
	Else // Check data for an advance invoice
		
		ErrorMessage = NStr("en = 'No data found for the advance invoice.
			|Basis
			|document: %1.'");
		
		ErrorMessage = StringFunctionsClientServer.PlaceParametersIntoString(ErrorMessage, FillingData);
		
		Raise ErrorMessage;
		
	EndIf;
	
EndProcedure // FillByCashBankDocument()

// The procedure fills in the document using AgentReport
// 
Procedure FillByAgentReport(FillingData)
	
	Query = New Query(
	"SELECT
	|	AgentReportInventory.Ref AS Ref,
	|	SUM(CASE
	|			WHEN AgentReportInventory.Ref.AmountIncludesVAT
	|				THEN AgentReportInventory.BrokerageAmount / ((AgentReportInventory.VATRate.Rate + 100) / 100)
	|			ELSE AgentReportInventory.BrokerageAmount
	|		END) AS Price,
	|	SUM(CASE
	|			WHEN AgentReportInventory.Ref.AmountIncludesVAT
	|				THEN AgentReportInventory.BrokerageAmount / ((AgentReportInventory.VATRate.Rate + 100) / 100)
	|			ELSE AgentReportInventory.BrokerageAmount
	|		END) AS Amount,
	|	AgentReportInventory.VATRate,
	|	SUM(AgentReportInventory.BrokerageVATAmount) AS VATAmount,
	|	SUM(CASE
	|			WHEN AgentReportInventory.Ref.AmountIncludesVAT
	|				THEN AgentReportInventory.BrokerageAmount
	|			ELSE AgentReportInventory.BrokerageAmount + AgentReportInventory.BrokerageVATAmount
	|		END) AS Total
	|INTO Remuneration
	|FROM
	|	Document.AgentReport.Inventory AS AgentReportInventory
	|WHERE
	|	AgentReportInventory.Ref = &Ref
	|
	|GROUP BY
	|	AgentReportInventory.VATRate,
	|	AgentReportInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Document.Ref AS BasisDocument,
	|	VALUE(Enum.OperationKindsSupplierInvoiceNote.Receipt) AS OperationKind,
	|	Document.Company,
	|	Document.Counterparty,
	|	Document.Contract,
	|	Document.DocumentCurrency,
	|	Document.ExchangeRate,
	|	Document.Multiplicity,
	|	""Fee"" AS Content,
	|	1 AS Quantity,
	|	Remuneration.Price AS Price,
	|	Remuneration.Amount AS Amount,
	|	Remuneration.VATRate AS VATRate,
	|	Remuneration.VATAmount AS VATAmount,
	|	Remuneration.Total AS Total
	|FROM
	|	Document.AgentReport AS Document
	|		LEFT JOIN Remuneration AS Remuneration
	|		ON Document.Ref = Remuneration.Ref
	|WHERE
	|	Document.Ref = &Ref
	|
	|GROUP BY
	|	Document.Ref,
	|	Remuneration.VATRate,
	|	Document.Company,
	|	Document.Counterparty,
	|	Document.Contract,
	|	Document.DocumentCurrency,
	|	Document.ExchangeRate,
	|	Document.Multiplicity,
	|	Remuneration.Price,
	|	Remuneration.Amount,
	|	Remuneration.VATAmount,
	|	Remuneration.Total");
	
	Query.SetParameter("Ref", FillingData);
		
	QueryResultSelection = Query.Execute().Select();
	
	If QueryResultSelection.Next() Then
		
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		If DocumentCurrency <> Constants.NationalCurrency.Get() Then
			
			StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
			ExchangeRate 		= StructureByCurrency.ExchangeRate;
			Multiplicity	= StructureByCurrency.Multiplicity;
			
		EndIf;
		
		Inventory.Clear();
		NewRow = Inventory.Add();
		
		FillPropertyValues(NewRow, QueryResultSelection);
		
	EndIf;
	
EndProcedure // FillByAgentReport()

// The procedure fills in the document using ReportToPrincipal.
//
Procedure FillByReportToPrincipal(FillingData)
	
	Query = New Query;
	
	Query.Text = 
	"SELECT
	|	Document.Ref AS BasisDocument,
	|	VALUE(Enum.OperationKindsCustomerInvoiceNote.Sale) AS OperationKind,
	|	Document.Company,
	|	Document.Counterparty,
	|	Document.Contract AS Contract,
	|	Document.DocumentCurrency,
	|	Document.ExchangeRate,
	|	Document.Multiplicity,
	|	TRUE AS Same
	|FROM
	|	Document.ReportToPrincipal AS Document
	|WHERE
	|	Document.Ref = &Ref";
	
	Query.SetParameter("Ref", FillingData);
	
	QueryResultSelection = Query.Execute().Select();
	
	If QueryResultSelection.Next() Then
		
		FillPropertyValues(ThisObject, QueryResultSelection);
		ThisObject.BasisDocument = FillingData;
		
		If DocumentCurrency <> Constants.NationalCurrency.Get() Then
			
			StructureByCurrency	= InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
			ExchangeRate 				= StructureByCurrency.ExchangeRate;
			Multiplicity			= StructureByCurrency.Multiplicity;
			
		EndIf;
		
		OperationKind = Enums.OperationKindsSupplierInvoiceNote.Receipt;
		
		// 
		// Do not fill in the "Inventory" tabular section 
		//
		
	EndIf;
	
EndProcedure // FillByReportToPrincipal()

// The procedure initiates filling in. 
//
Procedure FillInAccountInvoiceByDocumentBase(FillingData)
	
	If TypeOf(FillingData) = Type("DocumentRef.ReportToPrincipal") Then
	
		FillByReportToPrincipal(FillingData);
	
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") Then
		
		FillByPurchaseOrder(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AgentReport") Then
		
		FillByAgentReport(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AdditionalCosts") Then 
		
		FillByAdditionalExpence(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ExpenseReport") Then 
		
		FillByExpenseReport(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then 
		
		FillByInvoiceReceipt(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SubcontractorReport") Then 
		
		FillByReportProcesser(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CashPayment") 
		OR TypeOf(FillingData) = Type("DocumentRef.PaymentExpense") Then 
		
		FillByCashBankDocument(FillingData);
		
	EndIf;
	
EndProcedure // FillInAccountInvoiceByDocumentBase()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	SmallBusinessManagementElectronicDocumentsServer.ClearIncomingDocumentDateNumber(ThisObject);
	
EndProcedure // OnCopy()

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		
		Return;
		
	EndIf;

	// Check invoice note duplicate
	If TypeOf(FillingData) <> Type("Structure")  Then
		
		If TypeOf(FillingData) <> Type("DocumentRef.ReportToPrincipal") Then
			
			InvoiceFound = SmallBusinessServer.GetSubordinateInvoice(FillingData, True);
			If ValueIsFilled(InvoiceFound) 
				AND InvoiceFound.Ref <> Ref Then
			
				MessageText = NStr("en = 'Invoice note ""%InvoiceNote%"" already exists for document ""%Reference%"". 
										|Cannot add another document ""Supplier Invoice"".'");
				MessageText = StrReplace(MessageText, "%Ref%", FillingData);
				MessageText = StrReplace(MessageText, "%CustomerInvoiceNote%", InvoiceFound.Ref);
				
				Raise MessageText;
				
			EndIf;
			
		EndIf;
		
	Else
		
		If FillingData.Property("FillDocument") Then
			
			FillingData = FillingData.FillDocument;
			
		ElsIf FillingData.Property("FillByBasisDocuments")
			AND FillingData.FillByBasisDocuments Then
			
			FillingData = BasisDocument;
			
		Else
			
			Return;
			
		EndIf;
		
	EndIf;
	
	FillInAccountInvoiceByDocumentBase(FillingData);
	
EndProcedure // FillingProcessor()

// IN handler of document event
// FillCheckProcessing, checked attributes are being copied and reset
// a exclude a standard platform fill check and subsequent check by embedded language tools.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	If Not (ValueIsFilled(BasisDocument) 
			AND (TypeOf(BasisDocument) = Type("DocumentRef.ReportToPrincipal")
				OR TypeOf(BasisDocument) = Type("DocumentRef.AgentReport")))
		AND Not OperationKind = Enums.OperationKindsSupplierInvoiceNote.Advance Then
		
		CheckedAttributes.Add("Inventory.ProductsAndServices");
		CheckedAttributes.Add("Inventory.Quantity");
		CheckedAttributes.Add("Inventory.MeasurementUnit");
		CheckedAttributes.Add("Inventory.Price");
		
	EndIf;
	
	For Each InventoryTableRow IN Inventory Do
		
		If Not OperationKind = Enums.OperationKindsSupplierInvoiceNote.Advance
			AND ValueIsFilled(InventoryTableRow.CCDNo)
			AND (NOT ValueIsFilled(InventoryTableRow.CountryOfOrigin) 
				OR InventoryTableRow.CountryOfOrigin = Catalogs.WorldCountries.Russia) Then
		
			ErrorText = NStr("en = 'Incorrect country of origin in string [%LineNumberWithError%]'");
			ErrorText = StrReplace(ErrorText, "%LineNumberWithError%", TrimAll(InventoryTableRow.LineNumber));
		
			SmallBusinessServer.ShowMessageAboutError(ThisObject, 
			ErrorText,
			"Inventory",
			InventoryTableRow.LineNumber,
			"CountryOfOrigin",
			Cancel);
			
		EndIf;
		
		If Not OperationKind = Enums.OperationKindsSupplierInvoiceNote.Advance
			AND (ValueIsFilled(InventoryTableRow.CountryOfOrigin)
				AND Not InventoryTableRow.CountryOfOrigin = Catalogs.WorldCountries.Russia)
			AND Not ValueIsFilled(InventoryTableRow.CCDNo) Then
			
			ErrorText = NStr("en = 'Specify the CCD number in string [%LineNumberWithError%]'");
			ErrorText = StrReplace(ErrorText, "%LineNumberWithError%", TrimAll(InventoryTableRow.LineNumber));
			
			SmallBusinessServer.ShowMessageAboutError(ThisObject, 
			ErrorText,
			"Inventory",
			InventoryTableRow.LineNumber,
			"CCDNo",
			Cancel);
			
		EndIf;
		
	EndDo;
	
	// Post basis document
	If ValueIsFilled(BasisDocument)
		AND Not BasisDocument.Posted Then
		
		ErrorText = NStr("en = 'Basis document %BasisDocumentView% is not posted. Invoice posting is impossible.'");
		ErrorText = StrReplace(ErrorText, "%BasisDocumentView%", """" + TypeOf(BasisDocument) + " No." + BasisDocument.Number + " from " + BasisDocument.Date + """");
		
		SmallBusinessServer.ShowMessageAboutError(ThisObject, ErrorText, , , , Cancel);
		
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then 
		Return;
	EndIf;
	
	// Check supplier invoice note duplicate
	If ValueIsFilled(BasisDocument) Then
		
		If TypeOf(BasisDocument) <> Type("DocumentRef.ReportToPrincipal") Then
		
			InvoiceFound = SmallBusinessServer.GetSubordinateInvoice(BasisDocument, True);
			If ValueIsFilled(InvoiceFound) AND InvoiceFound.Ref <> Ref Then
			
				MessageText = NStr("en = 'Invoice note ""%InvoiceNote%"" already exists for document ""%Reference%"". 
										|Cannot add another document ""Supplier Invoice"".'");
				MessageText = StrReplace(MessageText, "%Ref%", BasisDocument);						
				MessageText = StrReplace(MessageText, "%CustomerInvoiceNote%", InvoiceFound.Ref);
				MessageField = "Object.BasisDocument";
				
				SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText,,,MessageField, Cancel);
				
				Return;
				
			EndIf;
			
		EndIf;
		
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
	Documents.SupplierInvoiceNote.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectInventoryByCCD(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);

    // Control
	Documents.SupplierInvoiceNote.RunControl(Ref, AdditionalProperties, Cancel);    
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.SupplierInvoiceNote.RunControl(Ref, AdditionalProperties, Cancel, True);
		
EndProcedure // UndoPosting()

#EndIf