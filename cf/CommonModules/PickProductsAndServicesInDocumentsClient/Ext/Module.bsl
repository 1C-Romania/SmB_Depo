////////////////////////////////////////////////////////////////////////////////
// Picking products and services (Client)
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// Rounds a number according to a specified order.
//
// Parameters:
//  Number        - Number required
//  to be rounded RoundingOrder - Enums.RoundingMethods - round
//  order RoundUpward - Boolean - rounding upward.
//
// Returns:
//  Number        - rounding result.
//
Function RoundPrice(Number, RoundRule, RoundUp) Export
	
	Var Result; // Returned result.
	
	// Transform order of numbers rounding.
	// If null order value is passed, then round to cents. 
	If Not ValueIsFilled(RoundRule) Then
		RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round0_01"); 
	Else
		RoundingOrder = RoundRule;
	EndIf;
	Order = Number(String(RoundingOrder));
	
	// calculate quantity of intervals included in number
	QuantityInterval = Number / Order;
	
	// calculate an integer quantity of intervals.
	NumberOfEntireIntervals = Int(QuantityInterval);
	
	If QuantityInterval = NumberOfEntireIntervals Then
		
		// Numbers are divided integrally. No need to round.
		Result	= Number;
	Else
		If RoundUp Then
			
			// During 0.05 rounding 0.371 must be rounded to 0.4
			Result = Order * (NumberOfEntireIntervals + 1);
		Else
			
			// During 0.05 rounding 0.371 must round to 0.35
			// and 0.376 to 0.4
			Result = Order * Round(QuantityInterval, 0, RoundMode.Round15as20);
		EndIf; 
	EndIf;
	
	Return Result;
	
EndFunction // RoundPrice()


Procedure OpenPick(OwnerForm, TabularSectionName, ChoiceFormFullName) Export
	
	SelectionParameters = New Structure;
	Cancel = False;
	
	FillSelectionParameterValues(OwnerForm, TabularSectionName, ChoiceFormFullName, SelectionParameters);
	
	If Not Cancel Then
		
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", PickProductsAndServicesInDocumentsClient.ThisObject);
		OpenForm(ChoiceFormFullName, SelectionParameters, OwnerForm, True, , , NotificationDescriptionOnCloseSelection, FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

// Procedure of processing the results of selection closing
//
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			Notify("SelectionIsMade", ClosingResult.CartAddressInStorage, ClosingResult.OwnerFormUUID);
			
		EndIf;
		
	EndIf;
	
EndProcedure // OnCloseSelection()

// Receive data from owner forms

Procedure FillSelectionParameterValues(OwnerForm, TabularSectionName, ChoiceFormFullName, SelectionParameters)
	
	SelectionParameters.Insert("Company", OwnerForm.ThisObject.Object.Company);
	SelectionParameters.Insert("Date", OwnerForm.ThisObject.Object.Date);
	SelectionParameters.Insert("PricePeriod", OwnerForm.ThisObject.Object.Date);
	SelectionParameters.Insert("OwnerFormUUID", OwnerForm.UUID);
	
	FillDocumentOperationKind(OwnerForm, SelectionParameters);
	FillParameterDocumentCurrency(OwnerForm, SelectionParameters);
	FillParameterStructuralUnit(OwnerForm, SelectionParameters);
	FillDocumentTaxationParameters(OwnerForm, SelectionParameters);
	FillProductsAndServicesTypes(OwnerForm, TabularSectionName, SelectionParameters);
	FillPriceKinds(OwnerForm, ChoiceFormFullName, SelectionParameters);
	FillDiscountKindMarkups(OwnerForm, ChoiceFormFullName, SelectionParameters);
	FillAdditionalParameters(OwnerForm, SelectionParameters);
	// DiscountCards
	FillDiscountCard(OwnerForm, ChoiceFormFullName, SelectionParameters);
	// End DiscountCards
	
EndProcedure

Procedure FillDocumentOperationKind(OwnerForm, SelectionParameters)
	Var OperationKind;
	
	If OwnerForm.Object.Property("OperationKind", OperationKind) Then
		
		SelectionParameters.Insert("OperationKind", OperationKind);
		
	EndIf;
	
EndProcedure

Procedure FillParameterDocumentCurrency(OwnerForm, SelectionParameters)
	
	If OwnerForm.Object.Property("DocumentCurrency") Then
		
		SelectionParameters.Insert("DocumentCurrency", OwnerForm.Object.DocumentCurrency);
		
	Else
		
		SelectionParameters.Insert("DocumentCurrency", Undefined);
		
	EndIf;
	
EndProcedure

Procedure FillParameterStructuralUnit(OwnerForm, SelectionParameters)
	Var StructuralUnit;
	
	If Find(OwnerForm.FormName, "CustomerOrder") > 0 
		OR Find(OwnerForm.FormName, "PurchaseOrder") > 0 Then
		
		OwnerForm.ThisObject.Object.Property("StructuralUnitReserve", StructuralUnit);
		SelectionParameters.Insert("StructuralUnit", StructuralUnit);
		
	ElsIf OwnerForm.FormName = "Document.InventoryTransfer.Form.DocumentForm" Then
		
		OwnerForm.ThisObject.Object.Property("StructuralUnit", StructuralUnit);
		SelectionParameters.Insert("StructuralUnitSender", StructuralUnit);
		
		OwnerForm.ThisObject.Object.Property("StructuralUnitPayee", StructuralUnit);
		SelectionParameters.Insert("StructuralUnitPayee", StructuralUnit);
		
	Else
		
		OwnerForm.ThisObject.Object.Property("StructuralUnit", StructuralUnit);
		SelectionParameters.Insert("StructuralUnit", StructuralUnit);
		
	EndIf;
	
EndProcedure

Procedure FillDocumentTaxationParameters(OwnerForm, SelectionParameters)
	
	If OwnerForm.FormName = "Document.CustomerInvoiceNote.Form.DocumentForm" 
		OR OwnerForm.FormName = "Document.SupplierInvoiceNote.Form.DocumentForm" Then
		
		SelectionParameters.Insert("VATTaxation", PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT"));
		SelectionParameters.Insert("AmountIncludesVAT", False);
		
	ElsIf OwnerForm.FormName = "Document.InventoryTransfer.Form.DocumentForm" Then
		// You do not need to fill attribute for transfer.
		
	Else
		
		SelectionParameters.Insert("VATTaxation", OwnerForm.ThisObject.Object.VATTaxation);
		SelectionParameters.Insert("AmountIncludesVAT", OwnerForm.ThisObject.Object.AmountIncludesVAT);
		
	EndIf;
	
EndProcedure

Procedure FillProductsAndServicesTypes(OwnerForm, TabularSectionName, SelectionParameters)
	
	ProductsAndServicesType = New ValueList;
	
	For Each ArrayElement IN OwnerForm.Items[TabularSectionName + "ProductsAndServices"].ChoiceParameters Do
		
		If ArrayElement.Name = "Filter.ProductsAndServicesType" Then
			
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				
				For Each FixArrayItem IN ArrayElement.Value Do
					
					ProductsAndServicesType.Add(FixArrayItem);
					
				EndDo; 
				
			Else
				
				ProductsAndServicesType.Add(ArrayElement.Value);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	SelectionParameters.Insert("ProductsAndServicesType", ProductsAndServicesType);
	
EndProcedure

Procedure FillPriceKinds(OwnerForm, ChoiceFormFullName, SelectionParameters)
	
	If ChoiceFormFullName = "DataProcessor.PickingReceipt.Form.CartPriceBalanceReserveCharacteristic" Then
	// Prices kind for receipt
		
		If OwnerForm.FormName = "Document.SupplierInvoiceNote.Form.DocumentForm" Then
		// Define the prices kinds for entry. documents without an explicit CounterpartyPriceKind attribute
			
			CounterpartyPriceKind = PickProductsAndServicesInDocumentsOverridable.PriceKindCustomerInvoiceNotes(OwnerForm.ThisObject.Object.Counterparty, OwnerForm.ThisObject.Object.Contract, True);
			SelectionParameters.Insert("CounterpartyPriceKind", CounterpartyPriceKind);
			
		Else
			
			SelectionParameters.Insert("CounterpartyPriceKind", OwnerForm.ThisObject.Object.CounterpartyPriceKind);
			
		EndIf;
		
	ElsIf ChoiceFormFullName = "DataProcessor.PickingSales.Form.CartPriceBalanceReserveCharacteristic" Then
	// Prices kind for realization
		
		If OwnerForm.FormName = "Document.CustomerInvoiceNote.Form.DocumentForm" Then
			
			PriceKind = PickProductsAndServicesInDocumentsOverridable.PriceKindCustomerInvoiceNotes(OwnerForm.ThisObject.Object.Counterparty, OwnerForm.ThisObject.Object.Contract, False);
			SelectionParameters.Insert("PriceKind", PriceKind);
			
		Else
			
			SelectionParameters.Insert("PriceKind", OwnerForm.ThisObject.Object.PriceKind);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillDiscountKindMarkups(OwnerForm, ChoiceFormFullName, SelectionParameters)
	
	DiscountsMarkupsVisible = False;
	If ChoiceFormFullName = "DataProcessor.PickingSales.Form.CartPriceBalanceReserveCharacteristic" Then
		
		If OwnerForm.ThisObject.Object.Property("DiscountMarkupKind") Then
			
			SelectionParameters.Insert("DiscountMarkupKind", OwnerForm.ThisObject.Object.DiscountMarkupKind);
			DiscountsMarkupsVisible = True;
			
		EndIf;
		
	EndIf;
	
	SelectionParameters.Insert("DiscountsMarkupsVisible", DiscountsMarkupsVisible);
	
EndProcedure

Procedure FillAdditionalParameters(OwnerForm, SelectionParameters)
	
	If OwnerForm.FormName = "Document.ReceiptCR.Form.DocumentForm" OR OwnerForm.FormName = "Document.ReceiptCR.Form.DocumentForm_CWP" Then
		
		SelectionParameters.Insert("IsCRReceipt", True);
		
	EndIf;
	
EndProcedure

#Region DiscountCards

Procedure FillDiscountCard(OwnerForm, ChoiceFormFullName, SelectionParameters)
	
	DiscountCardVisible = False;
	If ChoiceFormFullName = "DataProcessor.PickingSales.Form.CartPriceBalanceReserveCharacteristic" Then
		
		CurrObject = OwnerForm.ThisObject.Object;
		If CurrObject.Property("DiscountCard") Then
			
			DiscountCardVisible = True;
			If TypeOf(CurrObject) = Type("DocumentRef.CustomerOrder") Then
				If CurrObject.OperationKind = PredefinedValue("Enum.OperationKindsCustomerOrder.OrderForProcessing") Then
					DiscountCardVisible = False;
				EndIf;
			ElsIf TypeOf(CurrObject) = Type("DocumentRef.CustomerInvoice") Then
				If CurrObject.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer") Then
					DiscountCardVisible = False;
				EndIf;
			EndIf;
			
			If DiscountCardVisible = True Then
				SelectionParameters.Insert("DiscountCard", OwnerForm.ThisObject.Object.DiscountCard);
				SelectionParameters.Insert("DiscountPercentByDiscountCard", OwnerForm.ThisObject.Object.DiscountPercentByDiscountCard);			
			EndIf;
			
		EndIf;
		
	EndIf;
	
	SelectionParameters.Insert("DiscountCardVisible", DiscountCardVisible);
	
EndProcedure

#EndRegion

// End Get data from forms-owners
