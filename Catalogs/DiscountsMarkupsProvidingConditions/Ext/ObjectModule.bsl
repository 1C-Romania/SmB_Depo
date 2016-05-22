#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - FillCheckProcessing event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	UsedCurrencies = GetFunctionalOption("CurrencyTransactionsAccounting");
	
	If AssignmentCondition = Enums.DiscountsMarkupsProvidingConditions.ForOneTimeSalesVolume Then
		
		CheckedAttributes.Clear();
		CheckedAttributes.Add("RestrictionArea");
		CheckedAttributes.Add("UseRestrictionCriterionForSalesVolume");
		CheckedAttributes.Add("ComparisonType");
		If  UseRestrictionCriterionForSalesVolume = Enums.DiscountMarkupUseLimitCriteriaForSalesVolume.Amount 
			AND UsedCurrencies 
		Then
			CheckedAttributes.Add("RestrictionCurrency");
		EndIf;
		
	ElsIf AssignmentCondition = Enums.DiscountsMarkupsProvidingConditions.ForKitPurchase Then
		
		CheckedAttributes.Clear();
		CheckedAttributes.Add("PurchaseKit");
		CheckedAttributes.Add("PurchaseKit.ProductsAndServices");
		CheckedAttributes.Add("PurchaseKit.PackingsQuantity");
		CheckedAttributes.Add("PurchaseKit.Quantity");
		//TabularSectionDataProcessorProductsServer.CheckCharacteristicsFilling(ThisObject, New Array, Cancel, New Structure("TSName","PurchaseKit"));	
		
	EndIf;
	
	CheckedAttributes.Add("Description");
	CheckedAttributes.Add("AssignmentCondition");
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder Then
		TakeIntoAccountSaleOfOnlyParticularProductsAndServicesList = AssignmentCondition = Enums.DiscountsMarkupsProvidingConditions.ForOneTimeSalesVolume AND 
																(SalesFilterByProductsAndServices.Count() > 0);
															EndIf;
	
	If AssignmentCondition = Enums.DiscountsMarkupsProvidingConditions.ForKitPurchase Then
		SalesFilterByProductsAndServices.Clear();
	ElsIf AssignmentCondition = Enums.DiscountsMarkupsProvidingConditions.ForOneTimeSalesVolume Then
		PurchaseKit.Clear();
	EndIf;
	
EndProcedure

// Procedure - FillingProcessor event handler.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If Not IsFolder Then
		RestrictionCurrency = Constants.AccountingCurrency.Get();
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
