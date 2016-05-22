
// It performs the currency searching by the string code received from XML.
//
// Parameters:
// CurrencyCodeString - String- currency code
//
// Returns:
//  CatalogRef.Currencies - found currency.
//
Function ProcessCurrencyXML(CurrencyCodeString) Export
	
	Currency = Catalogs.Currencies.FindByDescription(CurrencyCodeString);
	
	If Not ValueIsFilled(Currency) Then
		Currency = Constants.NationalCurrency.Get();
	EndIf;
		
	Return Currency;
	
EndFunction

// It defines the field name for the contact information.
//
// Parameters:
//  TypeName - String, contact information type name
//
// Returns:
//  String, contact information filed name.
//
Function DefineByContactInfoFieldNameType(TypeName) Export
	
	If TypeName = "Postal index" Then
		FieldName = "IndexOf";
	ElsIf TypeName = "Settlement" Then
		FieldName = "Settlement";
	Else
		FieldName = TypeName;
	EndIf;
	
	Return FieldName;
	
EndFunction

// It receives a unique object identifier for exporting to XML.
//
// Parameters:
//  Object - arbitrary reference type 
//  Characteristic - CatalogRef.ProductsAndServicesCharacteristics
//
// Returns:
//  String, object unique identifier.
//
Function GenerateObjectUUID(Object, Characteristic = Undefined) Export
	
	ID = String(Object.UUID());
	
	If TypeOf(Object) = Type("CatalogRef.ProductsAndServices")
		AND (NOT Object.IsFolder)
		AND Object.UseCharacteristics
		AND ValueIsFilled(Characteristic) Then
		
		ID = ID + "#" + String(Characteristic.UUID());
		
	EndIf;
	
	Return ID;
	
EndFunction

// It receives the VAT rate based on the XML value.
// 
// Parameters:
//  TaxValue - String
//  Company - CatalogRef.Companies
// 
// Returns:
//  CatalogRef.VATRates.
//
Function GetByValueForExportingVATRate(TaxValue) Export
	
	Rate = 0;
	Calculated = False;
	NotTaxable = False;
	
	If TaxValue = "0" Then
		Rate = 0;
	ElsIf TaxValue = "10" Then
		Rate = 10;
	ElsIf TaxValue = "10/110" Then
		Rate = 10;
		Calculated = True;
	ElsIf TaxValue = "18" Then
		Rate = 18;
	ElsIf TaxValue = "18/118" Then
		Rate = 18;
		Calculated = True;
	Else
		NotTaxable = True;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	VATRates.Ref AS VATRate
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	VATRates.Rate = &Rate
	|	AND VATRates.NotTaxable = &NotTaxable
	|	AND VATRates.Calculated = &Calculated";
	
	Query.SetParameter("Rate", Rate);
	Query.SetParameter("NotTaxable", NotTaxable);
	Query.SetParameter("Calculated", Calculated);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then 
		
		VATRate = Selection.VATRate;
		
	Else
		
		NewRate = Catalogs.VATRates.CreateItem();
		NewRate.Description = ?(NOTTaxable, "Without VAT", Rate + "%");
		NewRate.Rate = Rate;
		NewRate.NotTaxable = NotTaxable;
		NewRate.Write();
		
		VATRate = NewRate;
		
	EndIf;
	
	Return VATRate
	
EndFunction

// It receives the VAT rate value for exporting to XML.
// 
// Parameters:
//  VATRate - Enums.VATRates
// 
// Returns:
//  String - VAT rate value.
//
Function GetValueForExportingByVATRate(VATRate) Export
	
	If VATRate.NotTaxable Then 
		TaxValue = NStr("en = 'Without VAT'");
	ElsIf VATRate.Rate = 0 Then 
		TaxValue = "0";
	ElsIf VATRate.Rate = 10 Then 
		TaxValue = "10" + ?(VATRate.Calculated, "/110", "");
	ElsIf VATRate.Rate = 18 Then 
		TaxValue = "18" + ?(VATRate.Calculated, "/118", "");
	Else
		TaxValue = String(VATRate.Rate);
	EndIf;
	
	Return TaxValue;
	
EndFunction

// It receives the customer order status with the InProcess order status.
//
Function GetStatusInProcessOfCustomerOrders() Export
	
	InProcessStatus = Constants.CustomerOrdersInProgressStatus.Get();
	
	If InProcessStatus.IsEmpty() Then
		
		Query = New Query;
		Query.Text = 
		"SELECT TOP 1
		|	CustomerOrderStates.Ref AS OrderState
		|FROM
		|	Catalog.CustomerOrderStates AS CustomerOrderStates
		|WHERE
		|	CustomerOrderStates.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)";
		
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			
			InProcessStatus = Selection.OrderState;
			
		EndIf;
		
	EndIf;
	
	Return InProcessStatus;
	
EndFunction

// It performs the discount kind searching by the discount description and percentage.
// If the discount kind is not found, it is created.
//
Function GetDiscountKindOnDocument(DescriptionDiscounts, Percent) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	MarkupAndDiscountKinds.Ref
	|FROM
	|	Catalog.MarkupAndDiscountKinds AS MarkupAndDiscountKinds
	|WHERE
	|	MarkupAndDiscountKinds.Description = &Description
	|	AND MarkupAndDiscountKinds.Percent = &Percent";
	
	Query.SetParameter("Description", TrimAll(DescriptionDiscounts));
	Query.SetParameter("Percent", Percent);
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		
		NewDiscount = Catalogs.MarkupAndDiscountKinds.CreateItem();
		NewDiscount.Description = DescriptionDiscounts;
		NewDiscount.Percent = Percent;
		NewDiscount.Write();
		
		DiscountKind = NewDiscount.Ref;
		
	Else
		
		Selection = Result.Select();
		Selection.Next();
		
		DiscountKind = Selection.Ref;
		
	EndIf;
	
	Return DiscountKind;
	
EndFunction

// It receives the predefined exchange plan node.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in the designer
// 
// Returns:
//  ThisNode - ExchangePlanRef - predefined exchange plan node
//
Function GetThisNodeOfExchangePlan(ExchangePlanName) Export
	
	Return ExchangePlans[ExchangePlanName].ThisNode()
	
EndFunction
