
//////////////////////////////////////////////////////////////////////////////// 
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Gets query for customer settlement document selection for "Payment receipt" and "Cash receipt" documents.
// 
&AtServerNoContext
Function GetQueryTextAccountDocumentsOfAccountsReceivableReceipt(FilterByContract)
	
	QueryText = "";
	
	If AccessRight("Read", Metadata.Documents.AcceptanceCertificate) Then
		QueryText = "
		|SELECT
		|	DocumentData.Ref AS Ref,
		|	DocumentData.Date AS Date,
		|	DocumentData.Number AS Number,
		|	DocumentData.Company AS Company,
		|	DocumentData.Counterparty AS Counterparty,
		|	DocumentData.Contract AS Contract,
		|	DocumentData.DocumentAmount AS Amount,
		|	DocumentData.DocumentCurrency AS Currency,
		|	VALUETYPE(DocumentData.Ref) AS Type,
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END AS DocumentStatus
		|FROM
		|	Document.AcceptanceCertificate AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.CustomerOrder) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CustomerOrder AS DocumentData
		|WHERE
		|	DocumentData.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.Netting) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.SettlementsAmount,
		|	VALUE(Catalog.Currencies.EmptyRef),
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.Netting AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.AgentReport) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.AgentReport AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.ProcessingReport) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.ProcessingReport AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.FixedAssetsTransfer) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.FixedAssetsTransfer AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.CustomerInvoice) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CustomerInvoice AS DocumentData
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction // GetQueryTextCustomerSettlementDocument()

// Gets query for supplier settlement document selection for "Payment receipt" and "Cash Reciept" documents.
// 
&AtServerNoContext
Function GetQueryTextDocumentsOfAccountsPayableReceipt(FilterByContract)
	
	QueryText = "";
	
	If AccessRight("Read", Metadata.Documents.ExpenseReport) Then
		QueryText = "
		|SELECT
		|	DocumentData.Ref AS Ref,
		|	DocumentData.Date AS Date,
		|	DocumentData.Number AS Number,
		|	DocumentData.Company AS Company,
		|	&CounterpartyByDefault AS Counterparty,
		|	&ContractByDefault AS Contract,
		|	DocumentData.DocumentAmount AS Amount,
		|	DocumentData.DocumentCurrency AS Currency,
		|	VALUETYPE(DocumentData.Ref) AS Type,
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END AS DocumentStatus
		|FROM
		|	Document.ExpenseReport AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.AdditionalCosts) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.AdditionalCosts AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.Netting) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.SettlementsAmount,
		|	VALUE(Catalog.Currencies.EmptyRef),
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.Netting AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.ReportToPrincipal) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE WHEN DocumentData.Posted THEN
		|		1
		|	WHEN DocumentData.DeletionMark THEN
		|		2
		|	ELSE
		|		0
		|	END
		|FROM
		|	Document.ReportToPrincipal AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SubcontractorReport) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.Amount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE WHEN DocumentData.Posted THEN
		|		1
		|	WHEN DocumentData.DeletionMark THEN
		|		2
		|	ELSE
		|		0
		|	END
		|FROM
		|	Document.SubcontractorReport AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SupplierInvoice) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SupplierInvoice AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.CustomerInvoice) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	CustomerInvoice.Ref,
		|	CustomerInvoice.Date,
		|	CustomerInvoice.Number,
		|	CustomerInvoice.Company,
		|	CustomerInvoice.Counterparty,
		|	CustomerInvoice.Contract,
		|	CustomerInvoice.DocumentAmount,
		|	CustomerInvoice.DocumentCurrency,
		|	VALUETYPE(CustomerInvoice.Ref),
		|	CASE
		|		WHEN CustomerInvoice.Posted
		|			THEN 1
		|		WHEN CustomerInvoice.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CustomerInvoice AS CustomerInvoice
		|WHERE
		|	(CustomerInvoice.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToVendor)
		|			OR CustomerInvoice.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnToPrincipal)
		|			OR CustomerInvoice.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromProcessing)
		|			OR CustomerInvoice.OperationKind = VALUE(Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody))
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.CashPayment) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CashPayment AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.PaymentExpense) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.PaymentExpense AS DocumentData
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction // GetQueryTextSupplierSettlementDocuments()

// Gets a query for selecting accounts receivable documents for "Payment expense" and "Cash payment" documents.
// 
&AtServerNoContext
Function GetQueryTextAccountDocumentsOfAccountsReceivableWriteOff(FilterByContract)
	
	QueryText = "";
	
	If AccessRight("Read", Metadata.Documents.CashReceipt) Then
		QueryText = "
		|SELECT
		|	DocumentData.Ref AS Ref,
		|	DocumentData.Date AS Date,
		|	DocumentData.Number AS Number,
		|	DocumentData.Company AS Company,
		|	DocumentData.Counterparty AS Counterparty,
		|	&ContractByDefault AS Contract,
		|	DocumentData.DocumentAmount AS Amount,
		|	DocumentData.CashCurrency AS Currency,
		|	VALUETYPE(DocumentData.Ref) AS Type,
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END AS DocumentStatus
		|FROM
		|	Document.CashReceipt AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.PaymentReceipt) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.PaymentReceipt AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.AcceptanceCertificate) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.AcceptanceCertificate AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.Netting) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.SettlementsAmount,
		|	VALUE(Catalog.Currencies.EmptyRef),
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.Netting AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.CustomerOrder) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CustomerOrder AS DocumentData
		|WHERE
		|	DocumentData.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.AgentReport) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.AgentReport AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.ProcessingReport) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.ProcessingReport AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.FixedAssetsTransfer) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.FixedAssetsTransfer AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SupplierInvoice) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	SupplierInvoice.Ref,
		|	SupplierInvoice.Date,
		|	SupplierInvoice.Number,
		|	SupplierInvoice.Company,
		|	SupplierInvoice.Counterparty,
		|	SupplierInvoice.Contract,
		|	SupplierInvoice.DocumentAmount,
		|	SupplierInvoice.DocumentCurrency,
		|	VALUETYPE(SupplierInvoice.Ref) AS Field1,
		|	CASE
		|		WHEN SupplierInvoice.Posted
		|			THEN 1
		|		WHEN SupplierInvoice.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END AS Field2
		|FROM
		|	Document.SupplierInvoice AS SupplierInvoice
		|WHERE
		|	(SupplierInvoice.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReturnFromCustomer)
		|			OR SupplierInvoice.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReturnFromAgent)
		|			OR SupplierInvoice.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReturnFromSubcontractor)
		|			OR SupplierInvoice.OperationKind = VALUE(Enum.OperationKindsSupplierInvoice.ReturnFromSafeCustody))
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.CustomerInvoice) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CustomerInvoice AS DocumentData
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets a query for selecting accounts payable documents for "Payment expense" and "Cash payment" documents.
// 
&AtServerNoContext
Function GetQueryTextDocumentsOfAccountsPayableWriteOff(FilterByContract)
	
	QueryText = "";
	
	If AccessRight("Read", Metadata.Documents.AdditionalCosts) Then
		QueryText = "
		|SELECT
		|	DocumentData.Ref AS Ref,
		|	DocumentData.Date AS Date,
		|	DocumentData.Number AS Number,
		|	DocumentData.Company AS Company,
		|	DocumentData.Counterparty AS Counterparty,
		|	DocumentData.Contract AS Contract,
		|	DocumentData.DocumentAmount AS Amount,
		|	DocumentData.DocumentCurrency AS Currency,
		|	VALUETYPE(DocumentData.Ref) AS Type,
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END AS DocumentStatus
		|FROM
		|	Document.AdditionalCosts AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SupplierInvoice) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SupplierInvoice AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.CustomerInvoice) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CustomerInvoice AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.ReportToPrincipal) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE WHEN DocumentData.Posted THEN
		|		1
		|	WHEN DocumentData.DeletionMark THEN
		|		2
		|	ELSE
		|		0
		|	END
		|FROM
		|	Document.ReportToPrincipal AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SubcontractorReport) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.Amount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE WHEN DocumentData.Posted THEN
		|		1
		|	WHEN DocumentData.DeletionMark THEN
		|		2
		|	ELSE
		|		0
		|	END
		|FROM
		|	Document.SubcontractorReport AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.Netting) Then
		QueryText = QueryText + "UNION ALL" +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.SettlementsAmount,
		|	VALUE(Catalog.Currencies.EmptyRef),
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.Netting AS DocumentData
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets order from the settlement document header.
//
&AtServerNoContext
Function GetOrder(Document, ThisIsAccountsReceivable)
	
	If ThisIsAccountsReceivable Then
		
		If TypeOf(Document) = Type("DocumentRef.AcceptanceCertificate")
			OR TypeOf(Document) = Type("DocumentRef.ProcessingReport") Then
			
			Order = Document.CustomerOrder;
			
		ElsIf (TypeOf(Document) = Type("DocumentRef.Netting")
			OR TypeOf(Document) = Type("DocumentRef.SupplierInvoice")
			OR TypeOf(Document) = Type("DocumentRef.CustomerInvoice"))
			AND TypeOf(Document.Order) = Type("DocumentRef.CustomerOrder") Then
			
			Order = Document.Order;
			
		Else
			
			Order = Documents.CustomerOrder.EmptyRef();
			
		EndIf;
			
	Else
		
		If TypeOf(Document) = Type("DocumentRef.AdditionalCosts") Then
			
			Order = Document.PurchaseOrder;
			
		ElsIf (TypeOf(Document) = Type("DocumentRef.Netting")
			OR TypeOf(Document) = Type("DocumentRef.SupplierInvoice")
			OR TypeOf(Document) = Type("DocumentRef.CustomerInvoice"))
			AND TypeOf(Document.Order) = Type("DocumentRef.PurchaseOrder") Then
			
			Order = Document.Order;
			
		Else
			
			Order = Documents.PurchaseOrder.EmptyRef();
			
		EndIf;
		
	EndIf;
	
	Return Order;
	
EndFunction

// Gets payment account associated with the settlement document.
//
&AtServerNoContext
Function GetInvoiceForPayment(Document, Order, ThisIsAccountsReceivable)

	If ThisIsAccountsReceivable Then
		
		InvoiceForPayment = Documents.InvoiceForPayment.EmptyRef();
		
		If TypeOf(Document) = Type("DocumentRef.AcceptanceCertificate")
			OR TypeOf(Document) = Type("DocumentRef.ProcessingReport")
			OR TypeOf(Document) = Type("DocumentRef.CustomerInvoice")
			OR (TypeOf(Document) = Type("DocumentRef.CustomerOrder")
			AND Document.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder) Then
			
			BasisDocument = Document;
		Else
			BasisDocument = Order;
		EndIf;
		
		If Not ValueIsFilled(BasisDocument) Then
			Return InvoiceForPayment;
		EndIf;
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	InvoiceForPayment.Ref AS InvoiceForPayment
		|FROM
		|	Document.InvoiceForPayment AS InvoiceForPayment
		|WHERE
		|	InvoiceForPayment.BasisDocument = &BasisDocument";
		
		Query.SetParameter("BasisDocument", BasisDocument);
		Selection = Query.Execute().Select();
		
		If Selection.Count() = 1
			AND Selection.Next() Then
			
			InvoiceForPayment = Selection.InvoiceForPayment;
			
		EndIf;
		
	Else
		
		InvoiceForPayment = Documents.SupplierInvoiceForPayment.EmptyRef();
		If Not ValueIsFilled(Order) Then
			Return InvoiceForPayment;
		EndIf;
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	SupplierInvoiceForPayment.Ref AS InvoiceForPayment
		|FROM
		|	Document.SupplierInvoiceForPayment AS SupplierInvoiceForPayment
		|WHERE
		|	SupplierInvoiceForPayment.BasisDocument = &BasisDocument";
		
		Query.SetParameter("BasisDocument", BasisDocument);
		Selection = Query.Execute().Select();
		
		If Selection.Count() = 1
			AND Selection.Next() Then
			
			InvoiceForPayment = Selection.InvoiceForPayment;
			
		EndIf;
		
	EndIf;
	
	Return InvoiceForPayment;

EndFunction


///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ThisIsAccountsReceivable = Parameters.ThisIsAccountsReceivable;
	DocumentType = Parameters.DocumentType;
	
	Counterparty = Parameters.Filter.Counterparty;
	
	FilterByContract = Parameters.Filter.Property("Contract");
	If FilterByContract Then
		Contract = Parameters.Filter.Contract;
	Else
		Contract = Catalogs.CounterpartyContracts.EmptyRef();
	EndIf;
	
	If DocumentType = Type("DocumentRef.PaymentReceipt")
		OR DocumentType = Type("DocumentRef.CashReceipt") Then
		
		If ThisIsAccountsReceivable Then
			List.QueryText = GetQueryTextAccountDocumentsOfAccountsReceivableReceipt(FilterByContract);
		Else
			List.QueryText = GetQueryTextDocumentsOfAccountsPayableReceipt(FilterByContract);
			List.Parameters.SetParameterValue("CounterpartyByDefault", Parameters.Filter.Counterparty);
		EndIf;
		
	Else
		
		If ThisIsAccountsReceivable Then
			List.QueryText = GetQueryTextAccountDocumentsOfAccountsReceivableWriteOff(FilterByContract);
		Else
			List.QueryText = GetQueryTextDocumentsOfAccountsPayableWriteOff(FilterByContract);
		EndIf;
		
	EndIf;
	
	List.Parameters.SetParameterValue("ContractByDefault", Contract);
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// The procedure is called when clicking button "Select".
//
&AtClient
Procedure ChooseDocument(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		
		DocumentData = New Structure;
		DocumentData.Insert("Document", CurrentData.Ref);
		DocumentData.Insert("Contract", CurrentData.Contract);
		
		Order = GetOrder(CurrentData.Ref, ThisIsAccountsReceivable);
		DocumentData.Insert("Order", Order);
		
		InvoiceForPayment = GetInvoiceForPayment(CurrentData.Ref, Order, ThisIsAccountsReceivable);
		DocumentData.Insert("InvoiceForPayment", InvoiceForPayment);
		
		NotifyChoice(DocumentData);
	Else
		Close();
	EndIf;
	
EndProcedure // ChooseDocument()

// The procedure is called when clicking button "Open document".
//
&AtClient
Procedure OpenDocument(Command)
	
	TableRow = Items.List.CurrentData;
	If TableRow <> Undefined Then
		ShowValue(Undefined,TableRow.Ref);
	EndIf;
	
EndProcedure // OpenDocument()

///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM FIELD EVENT HANDLERS

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Items.List.CurrentData;
	
	DocumentData = New Structure;
	DocumentData.Insert("Document", CurrentData.Ref);
	DocumentData.Insert("Contract", CurrentData.Contract);
	
	Order = GetOrder(CurrentData.Ref, ThisIsAccountsReceivable);
	DocumentData.Insert("Order", Order);
	
	InvoiceForPayment = GetInvoiceForPayment(CurrentData.Ref, Order, ThisIsAccountsReceivable);
	DocumentData.Insert("InvoiceForPayment", InvoiceForPayment);
	
	NotifyChoice(DocumentData);
	
EndProcedure // ListSelection()
