#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByPurchaseOrder(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.PettyCash AS PettyCash,
	|	DocumentTable.BankAccount AS BankAccount,
	|	DocumentTable.CashAssetsType AS CashAssetsType,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.PurchaseOrder AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure // FillByPurchaseOrder()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByPurchaseInvoice(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.SupplierInvoice AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure // FillBySupplierInvoice()

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByExpenseReport(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.ExpenseReport AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure // FillByExpenseReport()

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByReportToPrincipal(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.ReportToPrincipal AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure // FillByReportToPrincipal()

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByPayrollSheet(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.PayrollSheet AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure // FillByPayrollSheet()

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillBySupplierInvoiceNote(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.SupplierInvoiceNote AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure // FillBySupplierInvoiceNote()

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByAdditionalCosts(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.AdditionalCosts AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure // FillByAdditionalCosts()

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillBySubcontractorReport(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Amount AS DocumentAmount
	|FROM
	|	Document.SubcontractorReport AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure // FillBySubcontractorReport()

// Procedure for filling the document on the basis of InvoicesForPayment
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByVendorInvoiceForPayment(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.PettyCash AS PettyCash,
	|	DocumentTable.BankAccount AS BankAccount,
	|	DocumentTable.CashAssetsType AS CashAssetsType,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.SupplierInvoiceForPayment AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") Then
		FillByPurchaseOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then
		FillByPurchaseInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ExpenseReport") Then
		FillByExpenseReport(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ReportToPrincipal") Then
		FillByReportToPrincipal(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PayrollSheet") Then
		FillByPayrollSheet(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoiceNote") Then
		FillBySupplierInvoiceNote(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AdditionalCosts") Then
		FillByAdditionalCosts(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SubcontractorReport") Then
		FillBySubcontractorReport(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoiceForPayment") Then
		FillByVendorInvoiceForPayment(FillingData);
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - "FillCheckProcessing" event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.Approved Then
		
		CheckedAttributes.Add("CashAssetsType");
		
		If CashAssetsType = Enums.CashAssetTypes.Noncash Then
			CheckedAttributes.Add("BankAccount");
		ElsIf CashAssetsType = Enums.CashAssetTypes.Cash Then
			CheckedAttributes.Add("PettyCash");
		EndIf;
		
	EndIf;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler "Posting".
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.CashOutflowPlan.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

#EndIf