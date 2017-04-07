#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByCustomerOrder(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.PettyCash AS PettyCash,
	|	DocumentTable.BankAccount AS BankAccount,
	|	DocumentTable.CashAssetsType AS CashAssetsType,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.CustomerOrder AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure // FillByCustomerOrder()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByAgentReport(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.AgentReport AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure // FillByAgentReport()

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
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.CustomerInvoice AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure // FillBySalesInvoice()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByAcceptanceCertificate(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.AcceptanceCertificate AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure // FillByAcceptanceCertificate()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByProcessingReport(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationKindsCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.ProcessingReport AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure // FillByProcessingReport()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
		FillByCustomerOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AgentReport") Then
		FillByAgentReport(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerInvoice") Then
		FillBySalesInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AcceptanceCertificate") Then
		FillByAcceptanceCertificate(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProcessingReport") Then
		FillByProcessingReport(FillingData);
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler "Posting".
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.PaymentReceiptPlan.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

#EndIf