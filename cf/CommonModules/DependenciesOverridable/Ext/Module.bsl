
////////////////////////////////////////////////////////////////////////////////
// Subsystem "Subordination structure".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Creates document attribute array. 
// 
// Parameters: 
//  DocumentName - String - document name.
// 
// Returns: 
//  Array - document attribute description array. 
// 
Function ArrayAdditionalDocumentAttributes(DocumentName) Export
	
	AdditAttributesArray = New Array;
	
	// SB
	// Perhaps specify not more 3 additional attributes for presentation formation
	If DocumentName = "ExpenseReport" Then
		
		AdditAttributesArray.Add("Employee");
		
	ElsIf DocumentName = "WorkOrder" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("State");
		
	ElsIf DocumentName = "ProductionOrder" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("OrderState");
		
	ElsIf DocumentName = "CustomerOrder" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("OrderState");
		
	ElsIf DocumentName = "PurchaseOrder" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("OrderState");
		
	ElsIf DocumentName = "EmployeeOccupationChange" Then
		
		AdditAttributesArray.Add("OperationKind");
		
	ElsIf DocumentName = "AgentReport" Then
		
		AdditAttributesArray.Add("Counterparty"); // Agent
		
	ElsIf DocumentName = "ReportToPrincipal" Then
		
		AdditAttributesArray.Add("Counterparty"); // Consignor
		
	ElsIf DocumentName = "RetailReport" Then
		
		AdditAttributesArray.Add("CashCR");
		
	ElsIf DocumentName = "InventoryTransfer" Then
		
		AdditAttributesArray.Add("OperationKind");
		
	ElsIf DocumentName = "TransferBetweenCells" Then
		
		AdditAttributesArray.Add("OperationKind");
		
	ElsIf DocumentName = "SupplierInvoice" Then
		
		AdditAttributesArray.Add("OperationKind");
		
	ElsIf DocumentName = "PayrollSheet" Then
		
		AdditAttributesArray.Add("OperationKind");
		
	ElsIf DocumentName = "PaymentOrder" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("BankAccount");
		
	ElsIf DocumentName = "CashReceipt" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("PettyCash");
		
	ElsIf DocumentName = "PaymentReceipt" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("BankAccount");
		
	ElsIf DocumentName = "CashPayment" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("PettyCash");
		
	ElsIf DocumentName = "CustomerInvoice" Then
		
		AdditAttributesArray.Add("OperationKind");
		
	ElsIf DocumentName = "PaymentExpense" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("BankAccount");
		
	ElsIf DocumentName = "InventoryAssembly" Then
		
		AdditAttributesArray.Add("OperationKind");
		
	ElsIf DocumentName = "SettlementsReconciliation" Then
		
		AdditAttributesArray.Add("Status");
		
	ElsIf DocumentName = "JobSheet" Then
		
		AdditAttributesArray.Add("Performer");
		
	ElsIf DocumentName = "Event" Then
		
		AdditAttributesArray.Add("EventType");
		
	ElsIf DocumentName = "ReceiptCR" Then
		
		AdditAttributesArray.Add("CashCR");
		
	ElsIf DocumentName = "ReceiptCRReturn" Then
		
		AdditAttributesArray.Add("CashCR");
		
	EndIf;
	
	// End. SB
	
	Return AdditAttributesArray;
	
EndFunction

// Receives document presentation for printing.
//
// Parameters:
//  Selection  - DataCollection - structure or selection from
//                 inquiry results in which additional attributes are
//                 contained on the basis of which
//                 it is possible to create the overridden document presentation for output in report "Subordination structure".
//
// Returns:
//   String, Undefined   - overridden document presentation
//                           or Undefined if for this document type such isn't set.
//
Function GetDocumentPresentationToPrint(Selection) Export
	
	// SB
	
	DocumentPresentation = Selection.Presentation;
	If (Selection.DocumentAmount <> 0) 
		AND (Selection.DocumentAmount <> NULL) Then
		
		DocumentPresentation = DocumentPresentation + " " + NStr("en='to the amount of';ru='на сумму'") + " " + Selection.DocumentAmount;
		
		If ValueIsFilled(Selection.Currency) Then
			
			DocumentPresentation = DocumentPresentation + " " + Selection.Currency;
			
		ElsIf TypeOf(Selection.Ref) = Type("DocumentRef.InventoryReconciliation")
			OR TypeOf(Selection.Ref) = Type("DocumentRef.InventoryReceipt")
			OR TypeOf(Selection.Ref) = Type("DocumentRef.OtherExpenses")
			OR TypeOf(Selection.Ref) = Type("DocumentRef.InventoryWriteOff") Then
			
			DocumentPresentation = DocumentPresentation + " " + Constants.AccountingCurrency.Get();
			
		ElsIf TypeOf(Selection.Ref) = Type("DocumentRef.WorkOrder") Then
			
			If ValueIsFilled(Selection.Ref.PriceKind) Then
				
				DocumentPresentation = DocumentPresentation + " " + Selection.Ref.PriceKind.PriceCurrency;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	For IndexOfAdditionalAttribute = 1 To 3 Do
		
		AdditionalValue = Selection["AdditionalAttribute" + String(IndexOfAdditionalAttribute)];
		
		If ValueIsFilled(AdditionalValue) Then
			
			DocumentPresentation = DocumentPresentation + ", " + TrimAll(AdditionalValue);
			
		EndIf;
		
	EndDo;
	
	// End. SB
	
	Return DocumentPresentation;
	
EndFunction

// Returns document attribute name in which info about Amount and Currency of the document
// is contained for output in the subordination structure.
// Default attributes Currency and DocumentAmount are used. If for particular document or configuration in
// overall other
// attributes are used that it is possible to override values default in this function.
//
// Parameters:
//  DocumentName  - String - document name for which it is necessary to receive attribute name.
//  Attribute      - String - String, it can take the "Currency" and "DocumentAmount" values.
//
// Returns:
//   String   - Attribute name of the document containing the information on Currency or Amount.
//
Function DocumentAttributeName(DocumentName, Attribute) Export
	
	
	
	Return Undefined;
	
EndFunction

#EndRegion
