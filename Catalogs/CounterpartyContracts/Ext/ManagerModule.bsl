#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	Result.Add("Owner");
	Result.Add("SettlementsCurrency");
	
	Return Result;
	
EndFunction // GetLockedObjectAttributes()

// Receives the counterparty contract by default according to the filter conditions. Default or the only contract returns or an empty reference.
//
// Parameters
//  Counterparty	-	<CatalogRef.Counterparty> 
// 						counterparty, contract of which
//  is	needed	to 
// 						get Company - <CatalogRef.Companies> Company,
//  contract	of	which is needed to get ContractKindsList - <Array> 
// 						or <ValuesList> consisting values of the type <EnumRef.ContractKinds> Desired contract kinds
//
// Returns:
//   <CatalogRef.CounterpartyContracts> - found contract or empty ref
//
Function GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractKindsList = Undefined) Export
	
	CounterpartyMainContract = Counterparty.ContractByDefault;
	
	If Not SmallBusinessReUse.CounterpartyContractsControlNeeded() Then
		
		Return CounterpartyMainContract;
	EndIf;
	
	If ContractKindsList = Undefined
		OR (ContractKindsList.FindByValue(CounterpartyMainContract.ContractKind) <> Undefined
		AND CounterpartyMainContract.Company = Company) Then
		
		Return CounterpartyMainContract;
	EndIf;
	
	Query = New Query;
	QueryText = 
	"SELECT ALLOWED
	|	CounterpartyContracts.Ref
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|WHERE
	|	CounterpartyContracts.Owner = &Counterparty
	|	AND CounterpartyContracts.Company = &Company
	|	AND CounterpartyContracts.DeletionMark = False"
	+?(ContractKindsList <> Undefined,"
	|	And CounterpartyContracts.ContractType IN (&ContractTypeList)","");
	
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Company", Company);
	Query.SetParameter("ContractKindsList", ContractKindsList);
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		Return Catalogs.CounterpartyContracts.EmptyRef();
	EndIf;
	
	Selection = Result.Select();
	
	Selection.Next();
	Return Selection.Ref;

EndFunction // GetContractOfCounterparty()

// Checks the counterparty contract on the map to passed parameters.
//
// Parameters
// MessageText - <String> - error message
// about	errors	Contract - <CatalogRef.CounterpartyContracts> - checked
// contract	Company	- <CatalogRef.Company> - company
// document	Counterparty	- <CatalogRef.Counterparty> - document
// counterparty	ContractKindsList	- <ValuesList> consisting values of the type <EnumRef.ContractKinds>. 
// 						Desired contract kinds.
//
// Returns:
// <Boolean> -True if checking is completed successfully.
//
Function ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList) Export
	
	MessageText = "";
	
	If Not Counterparty.DoOperationsByContracts Then
		Return True;
	EndIf;
	
	DoesNotMatchCompany = False;
	DoesNotMatchContractKind = False;
	
	If Contract.Company <> Company Then
		DoesNotMatchCompany = True;
	EndIf;
		
	If ContractKindsList.FindByValue(Contract.ContractKind) = Undefined Then
		DoesNotMatchContractKind = True;
	EndIf;
	
	If (DoesNotMatchCompany OR DoesNotMatchContractKind) = False Then
		Return True;
	EndIf;
	
	MessageText = NStr("en = 'Contract attributes do not match the document terms:'");
	
	If DoesNotMatchCompany Then
		MessageText = MessageText + NStr("en = '
		| - The company does not match'");
	EndIf;
	
	If DoesNotMatchContractKind Then
		MessageText = MessageText + NStr("en = '
		| - Contract kind does not match'");
	EndIf;
	
	Return False;
	
EndFunction // ContractMeetsDocumentTerms()

// Returns a list of available contract kinds for the document.
//
// Parameters
// Document  - any document providing counterparty
// contract OperationKind  - document operation kind.
//
// Returns:
// <ValuesList>   - list of contract kinds which are available for the document.
//
Function GetContractKindsListForDocument(Document, OperationKind = Undefined, TabularSectionName = "") Export
	
	ContractKindsList = New ValueList;
	
	If TypeOf(Document) = Type("DocumentRef.AcceptanceCertificate") Then
		
		ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.EnterOpeningBalance") Then
		
		If TabularSectionName = "InventoryTransferred" Then
			
			If OperationKind = Enums.OperationKindsCustomerInvoice.TransferForCommission Then
				ContractKindsList.Add(Enums.ContractKinds.WithAgent);
			Else
				ContractKindsList.Add(Enums.ContractKinds.WithVendor);
			EndIf;
			
		ElsIf TabularSectionName = "InventoryReceived" Then
			
			If OperationKind = Enums.OperationKindsSupplierInvoice.ReceptionForCommission Then
				ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
			Else
				ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
			EndIf;
			
		ElsIf TabularSectionName = "AccountsPayable" Then
			
			ContractKindsList.Add(Enums.ContractKinds.WithVendor);
			ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
			
		ElsIf TabularSectionName = "AccountsReceivable" Then
			
			ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
			ContractKindsList.Add(Enums.ContractKinds.WithAgent);
			
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.Netting") Then
		
		If TabularSectionName = "Debitor" Then
			ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
			ContractKindsList.Add(Enums.ContractKinds.WithAgent);
		ElsIf TabularSectionName = "Creditor" Then
			ContractKindsList.Add(Enums.ContractKinds.WithVendor);
			ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		Else
			If OperationKind = Enums.OperationKindsNetting.CustomerDebtAssignment Then
				ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
				ContractKindsList.Add(Enums.ContractKinds.WithAgent);
			Else
				ContractKindsList.Add(Enums.ContractKinds.WithVendor);
				ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
			EndIf;
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.PowerOfAttorney") Then
		
		ContractKindsList.Add(Enums.ContractKinds.WithVendor);
		ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.AdditionalCosts") Then
		
		ContractKindsList.Add(Enums.ContractKinds.WithVendor);
		ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.CustomerOrder") Then
		
		If OperationKind = Enums.OperationKindsCustomerOrder.OrderForSale Then
			ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
			ContractKindsList.Add(Enums.ContractKinds.WithAgent);
		Else
			ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.PurchaseOrder") Then
		
		If OperationKind = Enums.OperationKindsPurchaseOrder.OrderForPurchase Then
			ContractKindsList.Add(Enums.ContractKinds.WithVendor);
			ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		Else
			ContractKindsList.Add(Enums.ContractKinds.WithVendor);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.AgentReport") Then
		
		ContractKindsList.Add(Enums.ContractKinds.WithAgent);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.ReportToPrincipal") Then
		
		ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.ProcessingReport") Then
		
		ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SubcontractorReport") Then
		
		ContractKindsList.Add(Enums.ContractKinds.WithVendor);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.CashReceipt") 
		OR TypeOf(Document) = Type("DocumentRef.PaymentReceipt") Then
		
		If OperationKind = Enums.OperationKindsCashReceipt.FromVendor
			OR OperationKind = Enums.OperationKindsPaymentReceipt.FromVendor Then
			ContractKindsList.Add(Enums.ContractKinds.WithVendor);
			ContractKindsList.Add(Enums.ContractKinds.WithAgent);
			ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		Else
			ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
			ContractKindsList.Add(Enums.ContractKinds.WithAgent);
			ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SupplierInvoice") Then
		
		If OperationKind = Enums.OperationKindsSupplierInvoice.ReceptionForCommission Then
			ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		ElsIf OperationKind = Enums.OperationKindsSupplierInvoice.ReturnFromAgent Then
			ContractKindsList.Add(Enums.ContractKinds.WithAgent);
		ElsIf OperationKind = Enums.OperationKindsSupplierInvoice.ReceptionIntoProcessing
			OR OperationKind = Enums.OperationKindsSupplierInvoice.ReceptionForSafeCustody
			OR OperationKind = Enums.OperationKindsSupplierInvoice.ReturnFromCustomer Then
			ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
		Else 
			ContractKindsList.Add(Enums.ContractKinds.WithVendor);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.CashPayment") 
		OR TypeOf(Document) = Type("DocumentRef.PaymentExpense") Then
		
		If OperationKind = Enums.OperationKindsCashPayment.Vendor 
			OR OperationKind = Enums.OperationKindsPaymentExpense.Vendor Then
			ContractKindsList.Add(Enums.ContractKinds.WithVendor);
			ContractKindsList.Add(Enums.ContractKinds.WithAgent);
			ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		Else
			ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
			ContractKindsList.Add(Enums.ContractKinds.WithAgent);
			ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.CustomerInvoice") Then
		
		If OperationKind = Enums.OperationKindsCustomerInvoice.TransferForCommission Then
			ContractKindsList.Add(Enums.ContractKinds.WithAgent);
		ElsIf OperationKind = Enums.OperationKindsCustomerInvoice.ReturnToPrincipal Then
			ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		ElsIf OperationKind = Enums.OperationKindsCustomerInvoice.TransferToProcessing
			OR OperationKind = Enums.OperationKindsCustomerInvoice.TransferForSafeCustody
			OR OperationKind = Enums.OperationKindsCustomerInvoice.ReturnToVendor Then
			ContractKindsList.Add(Enums.ContractKinds.WithVendor);
		Else 
			ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.InvoiceForPayment") Then
		
		ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
		ContractKindsList.Add(Enums.ContractKinds.WithAgent);
		ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SupplierInvoiceForPayment") Then
		
		ContractKindsList.Add(Enums.ContractKinds.WithVendor);
		ContractKindsList.Add(Enums.ContractKinds.WithAgent);
		ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.CustomerInvoiceNote") Then
		
		If OperationKind = Enums.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance Then
			ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		Else
			ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
			ContractKindsList.Add(Enums.ContractKinds.WithVendor);
			ContractKindsList.Add(Enums.ContractKinds.WithAgent);
			ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SupplierInvoiceNote") Then
		
		ContractKindsList.Add(Enums.ContractKinds.WithCustomer);
		ContractKindsList.Add(Enums.ContractKinds.WithVendor);
		ContractKindsList.Add(Enums.ContractKinds.WithAgent);
		ContractKindsList.Add(Enums.ContractKinds.FromPrincipal);
		
	EndIf;
	
	Return ContractKindsList;
	
EndFunction // GetContractKindsListForDocument()

#Region PrintInterface

// Fills in Customer order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// Contract
	PrintCommand = PrintCommands.Add();
	PrintCommand.Handler = "SmallBusinessClient.PrintCounterpartyContract";
	PrintCommand.ID = "ContractForm";
	PrintCommand.Presentation = NStr("en = 'Contract form'");
	PrintCommand.FormsList = "ItemForm,ListForm,ChoiceForm,ChoiceFormWithCounterparty";
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf