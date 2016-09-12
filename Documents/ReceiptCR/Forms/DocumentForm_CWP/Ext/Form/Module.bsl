&AtClient
Var Displays;

#Region CommonUseProceduresAndFunctions

// Procedure initializes new receipt parameters.
//
&AtServer
Procedure InitializeNewReceipt()
	
	Try
		UnlockDataForEdit(Object.Ref, UUID);
	Except
		//
	EndTry;
	
	NewReceipt = Documents.ReceiptCR.CreateDocument();
	
	FillPropertyValues(NewReceipt, Object,, "Inventory, PaymentWithPaymentCards, DiscountsMarkups, Number");
	
	ValueToFormData(NewReceipt, Object);
	
	Object.DocumentAmount = 0;
	
	Object.DiscountMarkupKind = Undefined;
	Object.DiscountCard = Undefined;
	Object.DiscountPercentByDiscountCard = 0;
	Object.DiscountsAreCalculated = False;
	DiscountAmount = 0;
	
	Object.CashReceived = 0;
	ReceivedPaymentCards = 0;
	
	AmountReceiptWithoutDiscounts = 0;
	AmountShortChange = 0;
	
	Object.Inventory.Clear();
	Object.PaymentWithPaymentCards.Clear();
	Object.DiscountsMarkups.Clear();
	
	Object.ReceiptCRNumber = "";
	Object.Archival = False;
	Object.Status = Enums.ReceiptCRStatuses.ReceiptIsNotIssued;
	
	InstalledGrayColor = True;
	Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
	
EndProcedure // InitializeNewReceipt()

// Fills amount discounts at client.
//
&AtClient
Procedure FillAmountsDiscounts()
	
	For Each CurRow IN Object.Inventory Do
		AmountWithoutDiscount = CurRow.Price * CurRow.Quantity;
		TotalDiscount = AmountWithoutDiscount - CurRow.Amount;
		ManualDiscountAmountMarkups = ?((TotalDiscount - CurRow.AutomaticDiscountAmount) > 0, TotalDiscount - CurRow.AutomaticDiscountAmount, 0);
		
		CurRow.DiscountAmount = TotalDiscount;
		CurRow.AmountDiscountsMarkups = ManualDiscountAmountMarkups;
	EndDo;
	
EndProcedure

// Procedure recalculates the document on client.
//
&AtClient
Procedure RecalculateDocumentAtClient()
	
	Object.DocumentAmount = Object.Inventory.Total("Total");
	
	Paid = Object.CashReceived + Object.PaymentWithPaymentCards.Total("Amount");
	AmountShortChange = ?(Paid = 0, 0, Paid - Object.DocumentAmount);
	
	DiscountAmount = Object.Inventory.Total("DiscountAmount");
	AmountReceiptWithoutDiscounts = Object.DocumentAmount + DiscountAmount;
	
	DisplayInformationOnCustomerDisplay();
	
EndProcedure // RecalculateDocumentAtClient()

// The procedure fills out a list of payment card kinds.
//
&AtServer
Procedure GetChoiceListOfPaymentCardKinds()
	
	ArrayTypesOfPaymentCards = Catalogs.POSTerminals.PaymentCardKinds(Object.POSTerminal);
	
	Items.PaymentByChargeCardTypeCards.ChoiceList.LoadValues(ArrayTypesOfPaymentCards);
	
EndProcedure // GetPaymentCardKindsChoiceList()

// Gets references to external equipment.
//
&AtServer
Procedure GetRefsToEquipment()

	FiscalRegister = ?(
		UsePeripherals // Check for the included FO "Use Peripherals"
	  AND ValueIsFilled(Object.CashCR)
	  AND ValueIsFilled(Object.CashCR.Peripherals),
	  Object.CashCR.Peripherals.Ref,
	  Catalogs.Peripherals.EmptyRef()
	);

	POSTerminal = ?(
		UsePeripherals
	  AND ValueIsFilled(Object.POSTerminal)
	  AND ValueIsFilled(Object.POSTerminal.Peripherals)
	  AND Not Object.POSTerminal.UseWithoutEquipmentConnection,
	  Object.POSTerminal.Peripherals,
	  Catalogs.Peripherals.EmptyRef()
	);

EndProcedure // GetRefsOnEquipment()

// Procedure fills the VAT rate in the tabular section according to company's taxation system.
// 
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company, Object.StructuralUnit, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure // FillVATRateByVATTaxation()

// Procedure fills the VAT rate in the tabular section according to taxation system.
// 
&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		
		For Each TabularSectionRow IN Object.Inventory Do
			
			If ValueIsFilled(TabularSectionRow.ProductsAndServices.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.ProductsAndServices.VATRate;
			Else
				TabularSectionRow.VATRate = Object.Company.DefaultVATRate;
			EndIf;
			
			VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(
				Object.AmountIncludesVAT,
				TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
				TabularSectionRow.Amount * VATRate / 100
			);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
			DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
		Else
			DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
		EndIf;
		
		For Each TabularSectionRow IN Object.Inventory Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
	EndIf;
	
EndProcedure // FillVATRateByVATTaxation()

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	StructureData.Insert(
		"Content",
		SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(
			?(ValueIsFilled(StructureData.ProductsAndServices.DescriptionFull),
			StructureData.ProductsAndServices.DescriptionFull, StructureData.ProductsAndServices.Description),
			StructureData.Characteristic, StructureData.ProductsAndServices.SKU)
	);
	
	If StructureData.Property("VATTaxation") 
		AND Not StructureData.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		If StructureData.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
			StructureData.Insert("VATRate", SmallBusinessReUse.GetVATRateWithoutVAT());
		Else
			StructureData.Insert("VATRate", SmallBusinessReUse.GetVATRateZero());
		EndIf;	
																
	ElsIf ValueIsFilled(StructureData.ProductsAndServices.VATRate) Then
		StructureData.Insert("VATRate", StructureData.ProductsAndServices.VATRate);
	Else
		StructureData.Insert("VATRate", StructureData.Company.DefaultVATRate);
	EndIf;	
	
	If StructureData.Property("PriceKind") Then
		Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
	Else
		StructureData.Insert("Price", 0);
	EndIf;
	
	If StructureData.Property("DiscountMarkupKind") 
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", StructureData.DiscountMarkupKind.Percent);
	Else	
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
		
	If StructureData.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
	EndIf;
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

// Procedure fills data when ProductsAndServices change.
//
&AtClient
Procedure ProductsAndServicesOnChange(TabularSectionRow)
	
	StructureData = New Structure();
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
		
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard",  Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	// End DiscountCards
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	TabularSectionRow.VATRate = StructureData.VATRate;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure // ProductsAndServicesOnChange()

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	If StructureData.Property("PriceKind") Then
		
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;
		
		Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataCharacteristicOnChange()

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure();
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataMeasurementUnitOnChange()

// VAT amount is calculated in the row of a tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(
		Object.AmountIncludesVAT,
		TabularSectionRow.Amount
	  - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
	  TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure // CalculateVATAmount()

// Procedure calculates the amount in the row of a tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined, SetDescription = True)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	AmountBeforeCalculation = TabularSectionRow.Amount;
	
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Amount = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0
		    AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	TabularSectionRow.DiscountAmount = AmountBeforeCalculation - TabularSectionRow.Amount;
	TabularSectionRow.AmountDiscountsMarkups = TabularSectionRow.DiscountAmount;
	
	// AutomaticDiscounts.
	RecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	
	// If picture was changed that focus goes from TS and procedure RecalculateDocumentAtClient() is not called.
	If RecalculationIsRequired Then
		RecalculateDocumentAtClient();
		DocumentConvertedAtClient = True;
	Else
		DocumentConvertedAtClient = False;
	EndIf;
	// End AutomaticDiscounts

	// CWP
	If SetDescription Then
		SetDescriptionForStringTSInventoryAtClient(TabularSectionRow);
	EndIf;
	
EndProcedure // CalculateAmountInTabularSectionLine()

// Procedure calculates discount % in tabular section string.
//
&AtClient
Procedure CalculateDiscountPercent(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	// AutomaticDiscounts.
	RecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateDiscountPercent");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	
	// If picture was changed that focus goes from TS and procedure RecalculateDocumentAtClient() is not called.
	If RecalculationIsRequired Then
		RecalculateDocumentAtClient();
		DocumentConvertedAtClient = True;
	Else
		DocumentConvertedAtClient = False;
	EndIf;
	// End AutomaticDiscounts
	
	If TabularSectionRow.Quantity * TabularSectionRow.Price < TabularSectionRow.DiscountAmount Then
		TabularSectionRow.AmountDiscountsMarkups = ?((TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.AutomaticDiscountAmount) < 0, 
			0, 
			TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.AutomaticDiscountAmount);
	EndIf;
	
	TabularSectionRow.DiscountAmount = TabularSectionRow.AmountDiscountsMarkups;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.DiscountAmount;
	If TabularSectionRow.Price <> 0
	   AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.DiscountMarkupPercent = (1 - TabularSectionRow.Amount / (TabularSectionRow.Price * TabularSectionRow.Quantity)) * 100;
	Else
		TabularSectionRow.DiscountMarkupPercent = 0;
	EndIf;
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	SetDescriptionForStringTSInventoryAtClient(TabularSectionRow);
	
EndProcedure // CalculateDiscountPercent()

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		NewRow.DiscountAmount = (NewRow.Quantity * NewRow.Price) - NewRow.Amount;
		NewRow.AmountDiscountsMarkups = NewRow.DiscountAmount;
		NewRow.ProductsAndServicesCharacteristicAndBatch = TrimAll(NewRow.ProductsAndServices.Description)+?(NewRow.Characteristic.IsEmpty(), "", ". "+NewRow.Characteristic)+?(NewRow.Batch.IsEmpty(), "", ". "+NewRow.Batch);
		If NewRow.DiscountAmount <> 0 Then
			DiscountPercent = Format(NewRow.DiscountAmount * 100 / (NewRow.Quantity * NewRow.Price), "NFD=2");
			DiscountText = ?(NewRow.DiscountAmount > 0, " - "+NewRow.DiscountAmount, " + "+(-NewRow.DiscountAmount))+" "+Object.DocumentCurrency
						  +" ("+?(NewRow.DiscountAmount > 0, " - "+DiscountPercent+"%)", " + "+(-DiscountPercent)+"%)");
		Else
			DiscountText = "";
		EndIf;
		NewRow.DataOnRow = ""+NewRow.Price+" "+Object.DocumentCurrency+" X "+NewRow.Quantity+" "+NewRow.MeasurementUnit+DiscountText+" = "+NewRow.Amount+" "+Object.DocumentCurrency;
		
	EndDo;
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;

	ShowHideDealAtServer(False, True);
	
EndProcedure // GetInventoryFromStorage()

// Procedure runs recalculation in the document tabular section after making changes in the "Prices and currency" form. The columns are recalculated as follows: price, discount, amount, VAT amount, total amount.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False)
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",		  Object.DocumentCurrency);
	ParametersStructure.Insert("VATTaxation",	  Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",	  Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice", Object.IncludeVATInPrice);
	ParametersStructure.Insert("Company",			  SubsidiaryCompany);
	ParametersStructure.Insert("DocumentDate",		  Object.Date);
	ParametersStructure.Insert("RefillPrices",	  False);
	ParametersStructure.Insert("RecalculatePrices",		  RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",  False);
	ParametersStructure.Insert("DocumentCurrencyEnabled", False);
	ParametersStructure.Insert("PriceKind", Object.PriceKind);
	ParametersStructure.Insert("DiscountKind", Object.DiscountMarkupKind);
	ParametersStructure.Insert("DiscountCard", Object.DiscountCard);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrencyForm", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure // ProcessChangesByButtonPricesAndCurrencies()

&AtClient
// Procedure-handler of the result of opening the "Prices and currencies" form
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	// 3. Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	If TypeOf(ClosingResult) = Type("Structure")
	   AND ClosingResult.WereMadeChanges Then
		
		Object.PriceKind = ClosingResult.PriceKind;
		Object.DiscountMarkupKind = ClosingResult.DiscountKind;
		// DiscountCards
		// do not verify counterparty in receipts, so. All sales are anonymised.
		Object.DiscountCard = ClosingResult.DiscountCard;
		Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
		// End DiscountCards
		Object.VATTaxation = ClosingResult.VATTaxation;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
			FillAmountsDiscounts();
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			  AND ClosingResult.RecalculatePrices Then
			SmallBusinessClient.RecalculateTabularSectionPricesByCurrency(ThisForm, AdditionalParameters.SettlementsCurrencyBeforeChange, "Inventory");
			FillAmountsDiscounts();
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			FillVATRateByVATTaxation();
			FillAmountsDiscounts();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			SmallBusinessClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
			FillAmountsDiscounts();
		EndIf;
		
		// DiscountCards
		If ClosingResult.RefillDiscounts AND Not ClosingResult.RefillPrices Then
			SmallBusinessClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		EndIf;
		// End DiscountCards
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;
	EndIf;
	
	// Generate price and currency label.
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, Object.DocumentCurrency, ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Update document footer
	RecalculateDocumentAtClient();
	
	// Update labels for all strings TS Inventory.
	FillInDetailsForTSInventoryAtClient();
	
EndProcedure // OpenPricesAndCurrencyFormEnd()

// Function returns the label text "Prices and currency".
//
&AtClientAtServerNoContext
Function GenerateLabelPricesAndCurrency(LabelStructure)
	
	LabelText = "";
	
	// Currency.
	If LabelStructure.CurrencyTransactionsAccounting Then
		If ValueIsFilled(LabelStructure.DocumentCurrency) Then
			LabelText = NStr("en='%Currency%';ru='%Вал%'");
			LabelText = StrReplace(LabelText, "%Currency%", TrimAll(String(LabelStructure.DocumentCurrency)));
		EndIf;
	EndIf;
	
	// Prices kind.
	If ValueIsFilled(LabelStructure.PriceKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en='%PriceKind%';ru='%PriceKind%'");
		Else
			LabelText = LabelText + NStr("en=' • %PriceKind%';ru=' • %ВидЦен%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%PriceKind%", TrimAll(String(LabelStructure.PriceKind)));
	EndIf;
	
	// Margins discount kind.
	If ValueIsFilled(LabelStructure.DiscountKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en='%DiscountMarkupKind%';ru='%ВидСкидкиНаценки%'");
		Else
			LabelText = LabelText + NStr("en=' • %MarkupDiscountKind%';ru=' • %ВидСкидкиНаценки%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%DiscountMarkupKind%", TrimAll(String(LabelStructure.DiscountKind)));
	EndIf;
	
	// Discount card.
	If ValueIsFilled(LabelStructure.DiscountCard) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en='%DiscountCard%';ru='%ДисконтнаяКарта%'");
		Else
			LabelText = LabelText + NStr("en=' • %DiscountCard%';ru=' • %ДисконтнаяКарта%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%DiscountCard%", String(LabelStructure.DiscountPercentByDiscountCard)+"% by map"); //ShortLP(String(LabelStructure.DiscountCard)));
	EndIf;	
	
	// VAT taxation.
	If ValueIsFilled(LabelStructure.VATTaxation) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en='%VATTaxation%';ru='%VATTaxation%'");
		Else
			LabelText = LabelText + NStr("en=' • %VATTaxation%';ru=' • %НалогообложениеНДС%'");
		EndIf;	
		LabelText = StrReplace(LabelText, "%VATTaxation%", TrimAll(String(LabelStructure.VATTaxation)));
	EndIf;
	
	// Flag showing that amount includes VAT.
	If IsBlankString(LabelText) Then	
		If LabelStructure.AmountIncludesVAT Then	
			LabelText = NStr("en='Amount includes VAT';ru='Сумма включает НДС'");
		Else
			LabelText = NStr("en='Amount does not include VAT';ru='Сумма не включает НДС'");
		EndIf;
	EndIf;
	
	Return LabelText;
	
EndFunction // GenerateLabelPricesAndCurrency()	

// Procedure forms form heading.
//
&AtServer
Procedure GenerateTitle(StructureStateCashCRSession)
	
	If StructureStateCashCRSession.SessionIsOpen Then
		MessageText = NStr("en='%Outlet%, Session No %NumberOfSession% %ModifiedAt%';ru='%ТорговаяТочка%, Смена № %НомерСмены%  %ВремяИзменения%'");
		MessageText = StrReplace(MessageText, "%Outlet%", TrimAll(StructureStateCashCRSession.StructuralUnit));
		MessageText = StrReplace(MessageText, "%NumberOfSession%", TrimAll(StructureStateCashCRSession.CashCRSessionNumber));
		MessageText = StrReplace(MessageText, "%ModifiedAt%", Format(StructureStateCashCRSession.StatusModificationDate,"DF=dd.MM.yyyy"));
	Else
		MessageText = NStr("en='%Outlet%';ru='%Outlet%'");
		If ValueIsFilled(StructureStateCashCRSession.StructuralUnit) Then
			MessageText = StrReplace(MessageText, "%Outlet%", TrimAll(StructureStateCashCRSession.StructuralUnit));
		Else
			MessageText = StrReplace(MessageText, "%Outlet%", TrimAll(CashCR.StructuralUnit));
		EndIf;
	EndIf;
	Title = MessageText;
	
EndProcedure // GenerateTitle()

#EndRegion

#Region UseCommonUseProceduresAndFunctionsCashCRSession

// Receipt print procedure on fiscal register.
//
&AtClient
Procedure IssueReceipt(GenerateSalesReceipt = False)
	
	ErrorDescription = "";
	
	If Object.ReceiptCRNumber <> 0
	AND Not CashCRUseWithoutEquipmentConnection Then
		
		MessageText = NStr("en='Check has already been issued on the fiscal record!';ru='Чек уже пробит на фискальном регистраторе!'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	ShowMessageBox = False;
	If SmallBusinessClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
		
		If UsePeripherals // Check for the included FO "Use Peripherals"
		AND Not CashCRUseWithoutEquipmentConnection Then 
			
			If EquipmentManagerClient.RefreshClientWorkplace() Then // Check on the certainty of Peripheral workplace
				
				DeviceIdentifier = ?(
					ValueIsFilled(FiscalRegister),
					FiscalRegister,
					Undefined
				);
				
				If DeviceIdentifier <> Undefined Then
					
					// Connect FR
					Result = EquipmentManagerClient.ConnectEquipmentByID(
						UUID,
						DeviceIdentifier,
						ErrorDescription
					);
						
					If Result Then
						
						// Prepare data
						InputParameters  = New Array;
						Output_Parameters = Undefined;
						
						SectionNumber = 1;
						
						// Preparation of the product table 
						ProductsTable = New Array();
						
						For Each TSRow IN Object.Inventory Do
							
							VATRate = SmallBusinessReUse.GetVATRateValue(TSRow.VATRate);
							
							ProductsTableRow = New ValueList();
							ProductsTableRow.Add(String(TSRow.ProductsAndServices));
																				  //  1 - Description
							ProductsTableRow.Add("");                    //  2 - Barcode
							ProductsTableRow.Add("");                    //  3 - SKU
							ProductsTableRow.Add(SectionNumber);           //  4 - Department number
							ProductsTableRow.Add(TSRow.Price);         //  5 - Price for position without discount
							ProductsTableRow.Add(TSRow.Quantity);   //  6 - Count
							ProductsTableRow.Add("");                    //  7 - Discount/markup description
							ProductsTableRow.Add(0);                     //  8 - Amount of a discount/markup
							ProductsTableRow.Add(0);                     //  9 - Discount/markup percent
							ProductsTableRow.Add(TSRow.Amount);        // 10 - Position amount with discount
							ProductsTableRow.Add(0);                     // 11 - Tax number (1)
							ProductsTableRow.Add(TSRow.VATAmount);     // 12 - Tax amount (1)
							ProductsTableRow.Add(VATRate);             // 13 - Tax percent (1)
							ProductsTableRow.Add(0);                     // 14 - Tax number (2)
							ProductsTableRow.Add(0);                     // 15 - Tax amount (2)
							ProductsTableRow.Add(0);                     // 16 - Tax percent (2)
							ProductsTableRow.Add("");                    // 17 - Section name of commodity string formatting
							
							ProductsTable.Add(ProductsTableRow);
							
						EndDo;
						
						// Preparation of the payment table 
						PaymentsTable = New Array();
						
						// Cash
						PaymentRow = New ValueList();
						PaymentRow.Add(0);
						PaymentRow.Add(Object.CashReceived);
						PaymentRow.Add("Payment by cash");
						PaymentRow.Add("");
						PaymentsTable.Add(PaymentRow);
						
						// Noncash
						PaymentRow = New ValueList();
						PaymentRow.Add(1);
						PaymentRow.Add(Object.PaymentWithPaymentCards.Total("Amount"));
						PaymentRow.Add("Group Cashless payment");
						PaymentRow.Add("");
						PaymentsTable.Add(PaymentRow);
						
						// Preparation of the common parameters table
						CommonParameters = New Array();
						CommonParameters.Add(0);                      //  1 - Receipt type
						CommonParameters.Add(True);                 //  2 - Fiscal receipt sign
						CommonParameters.Add(Undefined);           //  3 - Print on lining document
						CommonParameters.Add(Object.DocumentAmount);  //  4 - Amount by receipt without discounts/markups
						CommonParameters.Add(Object.DocumentAmount);  //  5 - Amount by receipt with accounting all discounts/markups
						CommonParameters.Add("");                     //  6 - Discount card number
						CommonParameters.Add("");                     //  7 - Header text
						CommonParameters.Add("");                     //  8 - Footer text
						CommonParameters.Add(0);                      //  9 - Session number (for receipt copy)
						CommonParameters.Add(0);                      // 10 - Receipt number (for receipt copy)
						CommonParameters.Add(0);                      // 11 - Document No (for receipt copy)
						CommonParameters.Add(0);                      // 12 - Document date (for receipt copy)
						CommonParameters.Add("");                     // 13 - Cashier name (for receipt copy)
						CommonParameters.Add("");                     // 14 - Cashier password
						CommonParameters.Add(0);                      // 15 - Template number
						CommonParameters.Add("");                     // 16 - Section name header format
						CommonParameters.Add("");                     // 17 - Section name cellar format
						
						InputParameters.Add(ProductsTable);
						InputParameters.Add(PaymentsTable);
						InputParameters.Add(CommonParameters);
						
						// Print receipt.
						Result = EquipmentManagerClient.RunCommand(
							DeviceIdentifier,
							"PrintReceipt",
							InputParameters,
							Output_Parameters
						);
						
						If Result Then
							
							// Set the received value of receipt number to document attribute.
							Object.ReceiptCRNumber = Output_Parameters[1];
							Object.Status = PredefinedValue("Enum.ReceiptCRStatuses.Issued");
							Object.Date = CurrentDate();
							
							If Not ValueIsFilled(Object.ReceiptCRNumber) Then
								Object.ReceiptCRNumber = 1;
							EndIf;
							
							Modified = True;
							
							Try
								PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
								ShowHideDealAtServer();
							Except
								//Object.Status = PredefinedValue("Enum.ReceiptCRStatuses.ReceiptIsNotIssued");
								//Write(New Structure("WriteMode", DocumentWriteMode.UndoPosting));
								
								FillInDetailsForTSInventoryAtClient();
								ShowMessageBox(Undefined, NStr("en='Failed to post the document';ru='Не удалось выполнить проведение документа'")); // Asynchronous method!
								Return;
							EndTry;
							
							If GenerateSalesReceipt AND Not Object.Ref.IsEmpty() Then
								
								OpenParameters = New Structure("PrintManagerName,TemplateNames,CommandParameter,PrintParameters");
								OpenParameters.PrintManagerName = "Document.ReceiptCR";
								OpenParameters.TemplateNames		 = "SalesReceipt";
								ReceiptsCRArray = New Array;
								ReceiptsCRArray.Add(Object.Ref);
								OpenParameters.CommandParameter	 = ReceiptsCRArray;
								OpenParameters.PrintParameters	 = Undefined;
								
								OpenForm("CommonForm.PrintingDocuments", OpenParameters, ThisForm, UniqueKey);
								
							EndIf;
							InitializeNewReceipt();
							DisplayInformationOnCustomerDisplay();
							
						Else
							
							MessageText = NStr("en='When printing a receipt, an error occurred."
"Receipt is not printed on the fiscal register."
"Additional"
"description: %AdditionalDetails%';ru='При печати чека произошла ошибка."
"Чек не напечатан на фискальном регистраторе."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
							);
							MessageText = StrReplace(
								MessageText,
								"%AdditionalDetails%",
								Output_Parameters[1]
							);
							CommonUseClientServer.MessageToUser(MessageText);
							
						EndIf;
						
						// Disconnect FR
						EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
						
					Else
						
						MessageText = NStr("en='An error occurred when connecting the device."
"Receipt is not printed on the fiscal register."
"Additional"
"description: %AdditionalDetails%';ru='При подключении устройства произошла ошибка."
"Чек не напечатан на фискальном регистраторе."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
						);
						MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
						CommonUseClientServer.MessageToUser(MessageText);
						
					EndIf;
					
				Else
					
					MessageText = NStr("en='Fiscal registration has not been selected';ru='Не выбран фискальный регистратор'");
					CommonUseClientServer.MessageToUser(MessageText);
					
				EndIf;
				
			Else
				
				MessageText = NStr("en='First, you need to select the workplace of the current session peripherals.';ru='Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.'");
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		Else
			
			// External equipment is not used
			Object.Status = PredefinedValue("Enum.ReceiptCRStatuses.Issued");
			Object.Date = CurrentDate();
			
			If Not ValueIsFilled(Object.ReceiptCRNumber) Then
				Object.ReceiptCRNumber = 1;
			EndIf;
			
			Modified = True;
			
			Try
				PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
				ShowHideDealAtServer();
			Except
				FillInDetailsForTSInventoryAtClient();
				ShowMessageBox(Undefined,NStr("en='Failed to post the document';ru='Не удалось выполнить проведение документа'")); // Asynchronous method!
				Return;
			EndTry;
			
			If GenerateSalesReceipt AND Not Object.Ref.IsEmpty() Then
				
				OpenParameters = New Structure("PrintManagerName,TemplateNames,CommandParameter,PrintParameters");
				OpenParameters.PrintManagerName = "Document.ReceiptCR";
				OpenParameters.TemplateNames		 = "SalesReceipt";
				ReceiptsCRArray = New Array;
				ReceiptsCRArray.Add(Object.Ref);
				OpenParameters.CommandParameter	 = ReceiptsCRArray;
				OpenParameters.PrintParameters	 = Undefined;
				
				OpenForm("CommonForm.PrintingDocuments", OpenParameters, ThisForm, UniqueKey);
				
			EndIf;
			InitializeNewReceipt();
			DisplayInformationOnCustomerDisplay();
			
		EndIf;
		
	Else
		
		FillInDetailsForTSInventoryAtClient();
		If ShowMessageBox Then
			ShowMessageBox(Undefined,NStr("en='Failed to post the document';ru='Не удалось выполнить проведение документа'"));
		EndIf;
		
	EndIf;
	
EndProcedure // PrintReceipt()

// Function gets cash session state on server.
//
&AtServerNoContext
Function GetCashCRSessionStateAtServer(CashCR)
	
	Return Documents.RetailReport.GetCashCRSessionStatus(CashCR);
	
EndFunction // GetCashCRSessionStateAtServer()

// Procedure - event handler "OpenCashCRSession".
//
&AtClient
Procedure CashCRSessionOpen()
	
	Result = False;
	ClearMessages();
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Device connection
		CashRegistersSettings = SmallBusinessReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If DeviceIdentifier <> Undefined OR UseWithoutEquipmentConnection Then
			
			ErrorDescription = "";
			
			If Not UseWithoutEquipmentConnection Then
				
				Result = EquipmentManagerClient.ConnectEquipmentByID(
					UUID,
					DeviceIdentifier,
					ErrorDescription
				);
				
			EndIf;
			
			If Result OR UseWithoutEquipmentConnection Then
				
				If Not UseWithoutEquipmentConnection Then
					
					InputParameters  = Undefined;
					Output_Parameters = Undefined;
					
					//Open session on fiscal register
					Result = EquipmentManagerClient.RunCommand(
						DeviceIdentifier,
						"OpenDay",
						InputParameters, 
						Output_Parameters
					);
					
				EndIf;
				
				If Result OR UseWithoutEquipmentConnection Then
					
					Result = CashCRSessionOpenAtServer(CashCR, ErrorDescription);
					
					If Not Result Then
						
						MessageText = NStr("en='An error occurred when opening the session."
"Session is not opened."
"Additional"
"description: %AdditionalDetails%';ru='При открытии смены произошла ошибка."
"Смена не открыта."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
						);
						MessageText = StrReplace(
							MessageText,
							"%AdditionalDetails%",
							?(UseWithoutEquipmentConnection, ErrorDescription, Output_Parameters[1])
						);
						CommonUseClientServer.MessageToUser(MessageText);
						
					EndIf;
					
				Else
					
					MessageText = NStr("en='An error occurred when opening the session."
"Session is not opened."
"Additional"
"description: %AdditionalDetails%';ru='При открытии смены произошла ошибка."
"Смена не открыта."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
					);
					MessageText = StrReplace(
						MessageText,
						"%AdditionalDetails%",
						ErrorDescription
					);
					CommonUseClientServer.MessageToUser(MessageText);
					
				EndIf;
				
				If Not UseWithoutEquipmentConnection Then
					
					EquipmentManagerClient.DisableEquipmentById(
						UUID,
						DeviceIdentifier
					);
					
				EndIf;
				
			Else
				
				MessageText = NStr("en='An error occurred when connecting the device."
"Session is not opened on the fiscal register."
"Additional"
"description: %AdditionalDetails%';ru='При подключении устройства произошла ошибка."
"Смена не открыта на фискальном регистраторе."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
				);
				MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
		
	Else
		
		MessageText = NStr("en='First, you need to select the workplace of the current session peripherals.';ru='Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.'"
		);
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure // OpenCashCRSession()

// Function opens the cash session on server.
//
&AtServer
Function CashCRSessionOpenAtServer(CashCR, ErrorDescription = "")
	
	Return Documents.RetailReport.CashCRSessionOpen(CashCR, ErrorDescription);
	
EndFunction // OpenCashCRSessionAtServer()

// Function verifies the existence of issued receipts during the session.
//
&AtServer
Function IssuedReceiptsExist(CashCR)
	
	StructureStateCashCRSession = Documents.RetailReport.GetCashCRSessionStatus(CashCR);
	
	If StructureStateCashCRSession.CashCRSessionStatus <> Enums.CashCRSessionStatuses.IsOpen Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ReceiptCRInventory.Ref AS CountRecipies
	|FROM
	|	(SELECT
	|		ReceiptCRInventory.Ref AS Ref
	|	FROM
	|		Document.ReceiptCR.Inventory AS ReceiptCRInventory
	|	WHERE
	|		ReceiptCRInventory.Ref.CashCRSession = &CashCRSession
	|		AND ReceiptCRInventory.Ref.Posted
	|		AND ReceiptCRInventory.Ref.ReceiptCRNumber > 0
	|		AND (NOT ReceiptCRInventory.Ref.Archival)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ReceiptCRInventory.Ref
	|	FROM
	|		Document.ReceiptCRReturn.Inventory AS ReceiptCRInventory
	|	WHERE
	|		ReceiptCRInventory.Ref.CashCRSession = &CashCRSession
	|		AND ReceiptCRInventory.Ref.Posted
	|		AND ReceiptCRInventory.Ref.ReceiptCRNumber > 0
	|		AND (NOT ReceiptCRInventory.Ref.Archival)) AS ReceiptCRInventory";
	
	Query.SetParameter("CashCRSession", StructureStateCashCRSession.CashCRSession);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction // ThereAreIssuedReceiptsForSession()

// Procedure closes the cash session on server.
//
&AtServer
Function CloseCashCRSessionAtServer(CashCR, ErrorDescription = "")
	
	Return Documents.RetailReport.CloseCashCRSessionExecuteArchiving(CashCR, ErrorDescription);
	
EndFunction // CloseCashCRSessionAtServer()

// Procedure - command handler "FundsIntroduction".
//
&AtClient
Procedure CashDeposition(Command)
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		InAmount = 0;
		
		WindowTitle = NStr("en='Receipt amount, %Currency%';ru='Сумма внесения, %Валюта%'");
		WindowTitle = StrReplace(
			WindowTitle,
			"%Currency%",
			StructureStateCashCRSession.DocumentCurrencyPresentation
		);
		
		ShowInputNumber(New NotifyDescription("FundsIntroductionEnd", ThisObject, New Structure("InAmount", InAmount)), InAmount, WindowTitle, 15, 2);
		
	Else
		
		MessageText = NStr("en='First, you need to select the workplace of the current session peripherals.';ru='Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.'"
		);
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

// Procedure - command handler "FundsIntroduction" after introduction amount enter.
//
&AtClient
Procedure FundsIntroductionEnd(Result1, AdditionalParameters) Export
	
	InAmount = ?(Result1 = Undefined, AdditionalParameters.InAmount, Result1);
	
	If (Result1 <> Undefined) Then
		
		// Device connection
		CashRegistersSettings = SmallBusinessReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If ValueIsFilled(DeviceIdentifier) Then
			FundsIntroductionFiscalRegisterConnectionsEnd(DeviceIdentifier, InAmount);
		Else
			NotifyDescription = New NotifyDescription("FundsIntroductionFiscalRegisterConnectionsEnd", ThisObject, InAmount);
			EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "FiscalRegister",
				NStr("en='Select the fiscal register';ru='Выберите фискальный регистратор'"), NStr("en='Fiscal register is not connected.';ru='Фискальный регистратор не подключен.'"));
		EndIf;
		
	EndIf;

EndProcedure // FundsIntroduction()

// Procedure prints receipt on FR (Encash command).
//
&AtClient
Procedure FundsIntroductionFiscalRegisterConnectionsEnd(DeviceIdentifier, Parameters) Export
	
	InAmount = Parameters;
	ErrorDescription = "";
	
	If DeviceIdentifier <> Undefined Then
		
		// Connect FR
		Result = EquipmentManagerClient.ConnectEquipmentByID(
			UUID,
			DeviceIdentifier,
			ErrorDescription
		);
		
		If Result Then
			
			//Prepare data
			InputParameters  = New Array();
			Output_Parameters = Undefined;
			
			InputParameters.Add(1);
			InputParameters.Add(InAmount);
			
			// Print receipt.
			Result = EquipmentManagerClient.RunCommand(
			DeviceIdentifier,
			"Encash",
			InputParameters,
			Output_Parameters
			);
			
			If Not Result Then
				
				MessageText = NStr("en='When printing a receipt, an error occurred."
"Receipt is not printed on the fiscal register."
"Additional"
"description: %AdditionalDetails%';ru='При печати чека произошла ошибка."
"Чек не напечатан на фискальном регистраторе."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
				);
				MessageText = StrReplace(MessageText,
				"%AdditionalDetails%",
				Output_Parameters[1]
				);
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
			// Disconnect FR
			EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
			
		Else
			
			MessageText = NStr("en='An error occurred when connecting the device."
"Receipt is not printed on the fiscal register."
"Additional"
"description: %AdditionalDetails%';ru='При подключении устройства произошла ошибка."
"Чек не напечатан на фискальном регистраторе."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
			);
			MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - command handler "FundsWithdrawal".
//
&AtClient
Procedure Withdrawal(Command)
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		WithdrawnAmount = 0;
		
		WindowTitle = NStr("en='Withdrawal amount, %Currency%';ru='Сумма выемки, %Валюта%'");
		WindowTitle = StrReplace(
			WindowTitle,
			"%Currency%",
			StructureStateCashCRSession.DocumentCurrencyPresentation
		);
		
		ShowInputNumber(New NotifyDescription("CashWithdrawalEnd", ThisObject, New Structure("WithdrawnAmount", WithdrawnAmount)), WithdrawnAmount, WindowTitle, 15, 2);
		
	Else
		
		MessageText = NStr("en='First, you need to select the workplace of the current session peripherals.';ru='Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

// Procedure - command handler "FundsWithdrawal" after enter dredging amount.
//
&AtClient
Procedure CashWithdrawalEnd(Result1, AdditionalParameters) Export
	
	WithdrawnAmount = ?(Result1 = Undefined, AdditionalParameters.WithdrawnAmount, Result1);
	
	If (Result1 <> Undefined) Then
		
		ErrorDescription = "";
		
		// Device connection
		CashRegistersSettings = SmallBusinessReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If ValueIsFilled(DeviceIdentifier) Then
			CashWithdrawalFiscalRegisterConnectionsEnd(DeviceIdentifier, WithdrawnAmount);
		Else
			NotifyDescription = New NotifyDescription("CashWithdrawalFiscalRegisterConnectionsEnd", ThisObject, WithdrawnAmount);
			EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "FiscalRegister",
				NStr("en='Select the fiscal register';ru='Выберите фискальный регистратор'"), NStr("en='Fiscal register is not connected.';ru='Фискальный регистратор не подключен.'"));
		EndIf;
	
	EndIf;

EndProcedure // FundsWithdrawal()

// Procedure prints receipt on FR (Encash command).
//
&AtClient
Procedure CashWithdrawalFiscalRegisterConnectionsEnd(DeviceIdentifier, Parameters) Export
	
	WithdrawnAmount = Parameters;
	ErrorDescription = "";
	
	If DeviceIdentifier <> Undefined Then
			
			// Connect FR
			Result = EquipmentManagerClient.ConnectEquipmentByID(
			UUID,
			DeviceIdentifier,
			ErrorDescription
			);
			
			If Result Then
				
				//Prepare data
				InputParameters  = New Array();
				Output_Parameters = Undefined;
				
				InputParameters.Add(0);
				InputParameters.Add(WithdrawnAmount);
				
				// Print receipt.
				Result = EquipmentManagerClient.RunCommand(
					DeviceIdentifier,
					"Encash",
					InputParameters,
					Output_Parameters
				);
				
				If Not Result Then
					
					MessageText = NStr("en='When printing a receipt, an error occurred."
"Receipt is not printed on the fiscal register."
"Additional"
"description: %AdditionalDetails%';ru='При печати чека произошла ошибка."
"Чек не напечатан на фискальном регистраторе."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
					);
					MessageText = StrReplace(
					MessageText,
					"%AdditionalDetails%",
					Output_Parameters[1]
					);
					CommonUseClientServer.MessageToUser(MessageText);
					
				EndIf;
				
				// Disconnect FR
				EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
				
			Else
				
				MessageText = NStr("en='An error occurred when connecting the device."
"Receipt is not printed on the fiscal register."
"Additional"
"description: %AdditionalDetails%';ru='При подключении устройства произошла ошибка."
"Чек не напечатан на фискальном регистраторе."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
				);
				MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
	
EndProcedure

// Procedure is called when pressing the PrintReceipt command panel button.
//
&AtClient
Procedure IssueReceiptExecute(Command, GenerateSalesReceipt = False)
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	If Not StructureStateCashCRSession.SessionIsOpen Then
		CashCRSessionOpen();
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	EndIf;
	
	If ValueIsFilled(StructureStateCashCRSession.CashCRSessionStatus) Then
		FillPropertyValues(Object, StructureStateCashCRSession,, "Responsible, Division");
		BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
		BalanceInCashierRow = ""+BalanceInCashier;
	EndIf;
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentReceiptCRPosting");
	// StandardSubsystems.PerformanceEstimation
	
	Cancel = False;
	
	ClearMessages();
	
	If Object.DeletionMark Then
		
		ErrorText = NStr("en='The document is marked for deletion.';ru='Документ помечен на удаление'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
	If Object.DocumentAmount > Object.CashReceived + Object.PaymentWithPaymentCards.Total("Amount") Then
		
		ErrorText = NStr("en='The payment amount is less than the receipt amount';ru='Сумма оплаты меньше суммы чека'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Field = "AmountShortChange";
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
	If Object.DocumentAmount < Object.PaymentWithPaymentCards.Total("Amount") Then
		
		ErrorText = NStr("en='The amount of payment by payment cards exceeds the amount of cheque';ru='Сумма оплаты платежными картами превышает сумму чека'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Field = "AmountShortChange";
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
	Object.Date = CurrentDate();
	
	If Not Cancel AND CheckFilling() Then
		
		IssueReceipt(GenerateSalesReceipt);
		Notify("RefreshReceiptCRDocumentsListForm");
		
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
		BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
		BalanceInCashierRow = ""+BalanceInCashier;
		GenerateTitle(StructureStateCashCRSession);
		
	EndIf;
	
EndProcedure // IssueReceiptExecute()

// Procedure X report printing.
//
&AtClient
Procedure ReportPrintingWithoutBlankingExecuteEnd(DeviceIdentifier, AdditionalParameters) Export

	ErrorDescription = "";

	If DeviceIdentifier <> Undefined Then
		Result = EquipmentManagerClient.ConnectEquipmentByID(UUID,
		                                                                              DeviceIdentifier, ErrorDescription);

		If Result Then
			InputParameters  = Undefined;
			Output_Parameters = Undefined;

			Result = EquipmentManagerClient.RunCommand(DeviceIdentifier,
			                                                        "PrintXReport",
			                                                        InputParameters,
			                                                        Output_Parameters);

			If Not Result Then
				MessageText = NStr("en='An error occurred while getting the report from fiscal register."
"%ErrorDescription%"
"Report on fiscal register is not formed.';ru='При снятии отчета на фискальном регистраторе произошла ошибка."
"%ОписаниеОшибки%"
"Отчет на фискальном регистраторе не сформирован.'");
				MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;

			EquipmentManagerClient.DisableEquipmentById(UUID,
			                                                                 DeviceIdentifier);
		Else
			MessageText = NStr("en='An error occurred when connecting the device.';ru='При подключении устройства произошла ошибка.'") + Chars.LF + ErrorDescription;
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - command handler "PrintReportWithoutClearing".
//
&AtClient
Procedure ReportPrintingWithoutBlankingExecute()
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		// Device connection
		NotifyDescription = New NotifyDescription("ReportPrintingWithoutBlankingExecuteEnd", ThisObject);
		MessageText = "";
		EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, 
																	 "FiscalRegister",
																	 NStr("en='Select the fiscal register';ru='Выберите фискальный регистратор'"), 
																	 NStr("en='Fiscal register is not connected';ru='Фискальный регистратор не подключен'")
																	 );
		If Not IsBlankString(MessageText) Then
			MessageText = NStr("en='Print X report';ru='Печать X-отчета'") + MessageText;
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
			
	Else
		MessageText = NStr("en='It is required to select a work place of the current peripheral session in advance.';ru='Предварительно необходимо выбрать рабочее место подключаемого оборудования текущего сеанса.'");

		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure // ReportPrintingWithoutBlankingExecute()

// Procedure - command handler "CloseCashCRSession".
//
&AtClient
Procedure CloseCashCRSession(Command)
	
	ClearMessages();
	
	If Not ValueIsFilled(CashCR) Then
		Return;
	EndIf;
	
	Result = False;
	
	If Not IssuedReceiptsExist(CashCR) Then
		
		ErrorDescription = "";
		
		DocumentArray = CloseCashCRSessionAtServer(CashCR, ErrorDescription);
		
		If ValueIsFilled(ErrorDescription) Then
			MessageText = NStr("en='Session is closed on the fiscal register, but errors occurred when generating the retail sales report."
"Additional"
"description: %AdditionalDetails%';ru='Смена закрыта на фискальном регистраторе, но при формировании отчета о розничных продажах возникли ошибки."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
			);
			MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
		// Show all resulting documents to user.
		For Each Document IN DocumentArray Do
			
			OpenForm("Document.RetailReport.ObjectForm", New Structure("Key", Document));
			
		EndDo;
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Device connection
		CashRegistersSettings = SmallBusinessReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
	
		If DeviceIdentifier <> Undefined OR UseWithoutEquipmentConnection Then
			
			ErrorDescription = "";
			
			If Not UseWithoutEquipmentConnection Then
				
				Result = EquipmentManagerClient.ConnectEquipmentByID(
					UUID,
					DeviceIdentifier,
					ErrorDescription
				);
				
			EndIf;
			
			If Result OR UseWithoutEquipmentConnection Then
				
				If Not UseWithoutEquipmentConnection Then
					InputParameters  = Undefined;
					Output_Parameters = Undefined;
					
					Result = EquipmentManagerClient.RunCommand(
						DeviceIdentifier,
						"PrintZReport",
						InputParameters,
						Output_Parameters
					);
				EndIf;
				
				If Not Result AND Not UseWithoutEquipmentConnection Then
					
					MessageText = NStr("en='Error occurred when closing the session on the fiscal register."
"""%ErrorDescription%"""
"Report on fiscal register is not formed.';ru='При закрытии смены на фискальном регистраторе произошла ошибка."
"""%ОписаниеОшибки%"""
"Отчет на фискальном регистраторе не сформирован.'"
					);
					MessageText = StrReplace(
						MessageText,
						"%ErrorDescription%",
						Output_Parameters[1]
					);
					CommonUseClientServer.MessageToUser(MessageText);
					
				Else
					
					DocumentArray = CloseCashCRSessionAtServer(CashCR, ErrorDescription);
					
					If ValueIsFilled(ErrorDescription)
					   AND UseWithoutEquipmentConnection Then
						
						CommonUseClientServer.MessageToUser(ErrorDescription);
						
					ElsIf ValueIsFilled(ErrorDescription)
						 AND Not UseWithoutEquipmentConnection Then
						
						MessageText = NStr("en='Session is closed on the fiscal register, but errors occurred when generating the retail sales report."
"Additional"
"description: %AdditionalDetails%';ru='Смена закрыта на фискальном регистраторе, но при формировании отчета о розничных продажах возникли ошибки."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
						);
						MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
						CommonUseClientServer.MessageToUser(MessageText);
						
					EndIf;
					
					// Show all resulting documents to user.
					For Each Document IN DocumentArray Do
						
						OpenForm("Document.RetailReport.ObjectForm", New Structure("Key", Document));
						
					EndDo;
					
				EndIf;
				
				If Not UseWithoutEquipmentConnection Then
					
					EquipmentManagerClient.DisableEquipmentById(
						UUID,
						DeviceIdentifier
					);
					
				EndIf;
				
			Else
				
				MessageText = NStr("en='An error occurred when connecting the device."
"Report is not printed and session is not closed on the fiscal register."
"Additional"
"description: %AdditionalDetails%';ru='При подключении устройства произошла ошибка."
"Отчет не напечатан и смена не закрыта на фискальном регистраторе."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
				);
				MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
		
	Else
		
		MessageText = NStr("en='First, you need to select the workplace of the current session peripherals.';ru='Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.'"
		);
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
	InitializeNewReceipt();
	
	//UpdateCashCRSessionStateAndSetDynamicListFilter(CashRegister);
	Items.List.Refresh();
	
	Notify("RefreshFormsAfterZReportIsDone");
	
EndProcedure // CloseCashCRSession()

&AtServerNoContext
Function GetLatestClosedCashCRSession()

	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED TOP 1
		|	RetailReport.Ref
		|FROM
		|	Document.RetailReport AS RetailReport
		|WHERE
		|	RetailReport.Posted
		|	AND RetailReport.CashCRSessionStatus <> &CashCRSessionStatus
		|
		|ORDER BY
		|	RetailReport.PointInTime DESC";
	
	Query.SetParameter("CashCRSessionStatus", Enums.CashCRSessionStatuses.IsOpen);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	Else
		Return Documents.RetailReport.EmptyRef();
	EndIf;
	
EndFunction // GetLatestClosedCashCRSession()

&AtServer
Function EnterParametersForCancellingReceiptCR()
	
	// Preparation of the common parameters table
	ReceiptType = 0; //?(TypeOf(ReceiptCR) = Type("DocumentRef.ReceiptCRReturn."), 1, 0);
	CommonParameters = New Array();
	CommonParameters.Add(ReceiptType);                //  1 - Receipt type
	CommonParameters.Add(True);                 //  2 - Fiscal receipt sign
	
	Return CommonParameters;
	
EndFunction

// Receipt cancellation procedure on fiscal register.
//
&AtClient
Function CancelReceiptCR(CashCR)
	
	ReceiptIsCanceled = False;
	
	ErrorDescription = "";
	
	CashRegistersSettings = SmallBusinessReUse.CashRegistersGetParameters(CashCR);
	DeviceIdentifierFR              = CashRegistersSettings.DeviceIdentifier;
	
	UseCashRegisterWithoutPeripheral = CashRegistersSettings.UseWithoutEquipmentConnection;
	
	If Not UsePeripherals 
		OR UseCashRegisterWithoutPeripheral Then
		ReceiptIsCanceled = True;
		Return ReceiptIsCanceled;
	EndIf;
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
	
		
		If DeviceIdentifierFR <> Undefined Then
			
			// Connect FR
			Result = EquipmentManagerClient.ConnectEquipmentByID(ThisObject,
			                                                                              DeviceIdentifierFR,
			                                                                              ErrorDescription);
			
			If Result Then   
				
				// Prepare data
				InputParameters  = EnterParametersForCancellingReceiptCR();
				Output_Parameters = Undefined;
				
				Result = EquipmentManagerClient.RunCommand(
					DeviceIdentifierFR,
					"OpenCheck",
					InputParameters,
					Output_Parameters);
					
				If Result Then
					SessionNumberCR = Output_Parameters[0];
					ReceiptCRNumber  = Output_Parameters[1]; 
					Output_Parameters = Undefined;
					Result = EquipmentManagerClient.RunCommand(
						DeviceIdentifierFR,
						"CancelCheck",
						InputParameters,
						Output_Parameters);
				EndIf;
				
				If Result Then
					ReceiptIsCanceled = True;
				Else
					MessageText = NStr("en='When cancellation receipt there was error. Receipt is not cancelled on fiscal register."
"Additional"
"description: %AdditionalDetails%';ru='При аннулировании чека произошла ошибка. Чек не аннулирован на фискальном регистраторе."
"Дополнительное"
"описание: %ДополнительноеОписание%'");
					MessageText = StrReplace(MessageText,
												 "%AdditionalDetails%",
												 Output_Parameters[1]);
					CommonUseClientServer.MessageToUser(MessageText);
				EndIf;
				
				// Disconnect FR
				EquipmentManagerClient.DisableEquipmentById(ThisObject, DeviceIdentifierFR);
				
			Else
				MessageText = NStr("en='An error occurred when connecting the device. Receipt is not cancelled on fiscal register."
"Additional"
"description: %AdditionalDetails%';ru='При подключении устройства произошла ошибка. Чек не аннулирован на фискальном регистраторе."
"Дополнительное"
"описание: %ДополнительноеОписание%'");
				MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;
			
		Else
			MessageText = NStr("en='Fiscal register is not selected.';ru='Не выбран фискальный регистратор.'");
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
	Else
		MessageText = NStr("en='First, you need to select the workplace of the current session peripherals.';ru='Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return ReceiptIsCanceled;
	
EndFunction

// Procedure - command handler ReceiptCancellation form.
//
&AtClient
Procedure ReceiptCancellation(Command)
	
	NotifyDescription = New NotifyDescription("ReceiptCancellationEnd", ThisObject);
	ShowQueryBox(NOTifyDescription, "Cancel last receipt?", QuestionDialogMode.YesNo,, DialogReturnCode.No);
	
EndProcedure

// Procedure - command handler ReceiptCancellation form. It is called after cancellation confirmation in issue window.
//
&AtClient
Procedure ReceiptCancellationEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		CancelReceiptCR(CashCR);
	EndIf;

EndProcedure

// Procedure - command handler PrintCopyOnFiscalRegister form.
//
&AtClient
Procedure PrintCopyOnFiscalRegistrar(Command)
	
	If Not UsePeripherals Then
		
		MessageText = NStr("en=""Slip receipt can't be printed. Peripheral is not used."";ru='Слип-чек не может быть напечатан. Подключаемое оборудование не используется.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Device selection FR
		NotifyDescription = New NotifyDescription("PrintCopyOnFiscalRegistrarEnd", ThisObject);
		MessageText = "";
		EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, 
																	 "FiscalRegister",
																	 NStr("en='Select the fiscal register';ru='Выберите фискальный регистратор'"), 
																	 NStr("en='Fiscal register is not connected';ru='Фискальный регистратор не подключен'")
																	 //, NStr("en='Fiscal register is not selected';ru='Фискальный регистратор не выбран'"),
																	 //True,
																	 //MessageText
																	 );
		If Not IsBlankString(MessageText) Then
			MessageText = NStr("en='Print last slip receipt';ru='Напечатать последний слип чек'") + MessageText;
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
	Else
		MessageText = NStr("en='Fiscal register is not connected';ru='Фискальный регистратор не подключен'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Procedure - command handler PrintCopyOnFiscalRegister form. Performs receipt printing on FR.
//
&AtClient
Procedure PrintCopyOnFiscalRegistrarEnd(DeviceIdentifierFR, Parameters) Export
	
	If DeviceIdentifierFR <> Undefined Then 
		
		ErrorDescription  = "";
		// FR device connection
		ResultFR = EquipmentManagerClient.ConnectEquipmentByID(UUID,
		                                                                                DeviceIdentifierFR,
		                                                                                ErrorDescription);
		If ResultFR Then
			If Not IsBlankString(glPeripherals.LastSlipReceipt) Then
				InputParameters = New Array();
				InputParameters.Add(glPeripherals.LastSlipReceipt);
				Output_Parameters = Undefined;
				
				ResultFR = EquipmentManagerClient.RunCommand(DeviceIdentifierFR,
				                                                          "PrintText",
				                                                          InputParameters,
				                                                          Output_Parameters);
				If Not ResultFR Then
					MessageText = NStr("en='When printing slip receipt there was error: ""%ErrorDescription%"".';ru='При печати слип-чека возникла ошибка: ""%ОписаниеОшибки%"".'"); 
					MessageText = StrReplace(MessageText,
					                             "%ErrorDescription%",
					                             Output_Parameters[1]);
					CommonUseClientServer.MessageToUser(MessageText);
				EndIf;
			EndIf;
			
			// FR device disconnect
			EquipmentManagerClient.DisableEquipmentById(UUID,
			                                                                 DeviceIdentifierFR);
		Else
			MessageText = NStr("en='When fiscal registrar connection there was error: ""%ErrorDescription%""."
"Slip receipt is not printed.';ru='При подключении фискального регистратора произошла ошибка: ""%ОписаниеОшибки%""."
"Слип-чек не напечатан.'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
	EndIf;

EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForFormAppearanceManagement

// Procedure sets mode Only view.
//
Procedure SetModeReadOnly()
	
	ReadOnly = True; // Receipt is issued. Change information is forbidden.
	Items.AcceptPayment.Enabled = False;
	Items.PricesAndCurrency.Enabled = False;
	Items.InventoryWeight.Enabled = False;
	Items.InventoryPick.Enabled = False;
	Items.InventoryImportDataFromDCT.Enabled = False;
	
EndProcedure // SetModeOnlyViewing()

// Procedure sets the receipt print availability.
//
&AtServer
Procedure SetEnabledOfReceiptPrinting()
	
	If Object.Status = Enums.ReceiptCRStatuses.ProductReserved
	 OR Object.CashCR.UseWithoutEquipmentConnection
	 OR ControlAtWarehouseDisabled Then
		Items.AcceptPayment.Enabled = True;
	Else
		Items.AcceptPayment.Enabled = True; // False;
	EndIf;
	
EndProcedure // SetReceiptPrintEnabled()

// Procedure sets button headings and key combinations for form commands.
//
&AtServer
Procedure ConfigureButtonsAndMenuCommands()
	
	If Not ValueIsFilled(CWPSetting) Then
		// We issue message in procedure "FillFastGoods()".
		Return;
	EndIf;
	
	DontShowOnOpenCashdeskChoiceForm = CWPSetting.DontShowOnOpenCashdeskChoiceForm;
	
	For Each CurrentSettingCommandButtons IN CWPSetting.LowerBarButtons Do
		Try
			If CurrentSettingCommandButtons.ButtonName = "ProductsAndServicesSearchValue" Then
				If ValueIsFilled(CurrentSettingCommandButtons.Key) Then
					Items.ProductsAndServicesSearchValue.Shortcut = New Shortcut(Key[CurrentSettingCommandButtons.Key], CurrentSettingCommandButtons.Alt,
						CurrentSettingCommandButtons.Ctrl, CurrentSettingCommandButtons.Shift);
					Items.ProductsAndServicesSearchValue.InputHint = "Enter name, code or SKU "+ShortcutPresentation(Items.ProductsAndServicesSearchValue.Shortcut, False);
				Else
					Items.ProductsAndServicesSearchValue.Shortcut = New Shortcut(Key.None);
					Items.ProductsAndServicesSearchValue.InputHint = "Enter name, code or SKU";
				EndIf;
			Else
				CurrentButton = Items[CurrentSettingCommandButtons.ButtonName];
				CurrentCommand = Commands[CurrentSettingCommandButtons.CommandName];
				
				If ValueIsFilled(CurrentSettingCommandButtons.ButtonName) Then
					CurrentButton.Title = CurrentSettingCommandButtons.ButtonTitle;
					
					If CurrentSettingCommandButtons.ButtonName = "ShowJournal" Then
						Items.SwitchJournalQuickProducts.ChoiceList.Get(0).Presentation = CurrentSettingCommandButtons.ButtonTitle;
					ElsIf CurrentSettingCommandButtons.ButtonName = "ShowQuickSales" Then
						Items.SwitchJournalQuickProducts.ChoiceList.Get(1).Presentation = CurrentSettingCommandButtons.ButtonTitle;
					ElsIf CurrentSettingCommandButtons.ButtonName = "ShowMyPettyCash" Then
						Items.SwitchJournalQuickProducts.ChoiceList.Get(2).Presentation = CurrentSettingCommandButtons.ButtonTitle;
					EndIf;
				EndIf;
				
				If ValueIsFilled(CurrentSettingCommandButtons.Key) Then
					CurrentCommand.Shortcut = New Shortcut(Key[CurrentSettingCommandButtons.Key], CurrentSettingCommandButtons.Alt,
						CurrentSettingCommandButtons.Ctrl, CurrentSettingCommandButtons.Shift);
				Else
					CurrentCommand.Shortcut = New Shortcut(Key.None);
				EndIf;
			EndIf;
		Except
			Message = New UserMessage;
			Message.Text = "Error is occurred when button and menu command setting. "+ErrorDescription();
			Message.Message();
		EndTry;
	EndDo;
	
EndProcedure

// Procedure - event handler Click item GroupbyExpandSalesSidePanel form.
//
&AtClient
Procedure GroupbyExpandSalesSidePanelClick(Item)
	
	GroupbyExpandSideSalePanelClickAtServer();
	
EndProcedure

// Procedure - event handler Click item GroupbyExpandSalesSidePanel on server.
//
&AtServer
Procedure GroupbyExpandSideSalePanelClickAtServer()
	
	If Items.ExpandGroupbySalesSidePanel.Title = ">>" Then
		Items.SidePanelSales.Visible = False;
		Items.ExpandGroupbySalesSidePanel.Title = "<<";
		Items.ExpandGroupbySalesSidePanel.Picture = PictureLib.CWP_ExpandAdditionalPanel;
	Else
		Items.SidePanelSales.Visible = True;
		Items.ExpandGroupbySalesSidePanel.Title = ">>";
		Items.ExpandGroupbySalesSidePanel.Picture = PictureLib.CWP_MinimizeAdditionalPanel;
	EndIf;
	
EndProcedure

// Procedure - event handler Click item GroupbySidePanelRefunds form.
//
&AtClient
Procedure GroupbySidePanelRefundsClick(Item)
	
	GroupbySidePanelRefundsClickAtServer();
	
EndProcedure

// Procedure - event handler Click item GroupbySidePanelRefunds on server.
//
&AtServer
Procedure GroupbySidePanelRefundsClickAtServer()
	
	If Items.GroupbySidePanelRefunds.Title = ">>" Then
		Items.SidePanelRefunds.Visible = False;
		Items.GroupbySidePanelRefunds.Title = "<<";
		Items.GroupbySidePanelRefunds.Picture = PictureLib.CWP_ExpandAdditionalPanel;
	Else
		Items.SidePanelRefunds.Visible = True;
		Items.GroupbySidePanelRefunds.Title = ">>";
		Items.GroupbySidePanelRefunds.Picture = PictureLib.CWP_MinimizeAdditionalPanel;
	EndIf;
	
EndProcedure

// Procedure changes page visible on which DEAL displays.
//
&AtServer
Procedure ShowHideDealAtServer(Show = True, Check = False)
	
	If Not Check OR Not Items.PagesDataOnRowAndChange.CurrentPage = Items.PageDataOnRow Then
		ChangeRow = "Deal: "+Change+" "+Object.DocumentCurrency;
		
		If Show Then
			Items.PagesDataOnRowAndChange.CurrentPage = Items.PageChange;
		Else
			Items.PagesDataOnRowAndChange.CurrentPage = Items.PageDataOnRow;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure changes page visible on which DEAL displays.
//
&AtClient
Procedure ShowHideDealAtClient()
	
	If Not Items.PagesDataOnRowAndChange.CurrentPage = Items.PageDataOnRow Then
		ShowHideDealAtServer(False);
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresFormEventsHandlers

// Procedure - OnCreateAtServer form event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed
	);
	
	// CWP
	CashCR = Parameters.CashCR;
	If Not ValueIsFilled(CashCR) Then
		Message = New UserMessage();
		Message.Text = NStr("en='For user Cash Register is not defined!';ru='Для пользователя не определена Касса ККМ!'");
		Message.Message();
		Cancel = True;
		Return;
	EndIf;
	
	User = Users.CurrentUser();
	
	PreviousCashCR = CashCR;
	CashCRUseWithoutEquipmentConnection = CashCR.UseWithoutEquipmentConnection;
	
	Object.POSTerminal = Parameters.POSTerminal;
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	FillPropertyValues(Object, StructureStateCashCRSession);
	BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
	BalanceInCashierRow = ""+BalanceInCashier;
	
	Object.CashCR = CashCR;
	Object.StructuralUnit = CashCR.StructuralUnit;
	Object.PriceKind = CashCR.StructuralUnit.RetailPriceKind;
	If Not ValueIsFilled(Object.DocumentCurrency) Then
		Object.DocumentCurrency = CashCR.CashCurrency;
	EndIf;
	Object.Company = Object.CashCR.Owner;
	Object.Division = Object.CashCR.Division;
	Object.Responsible = SmallBusinessReUse.GetValueByDefaultUser(User, "MainResponsible");
	// End CWP
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	// Temporarily.
	//( elmi # 08.5
	//Object.IncludeVATInPrice = True;
	//) elmi
	
	If Not ValueIsFilled(Object.Ref) Then
		GetChoiceListOfPaymentCardKinds();
	EndIf;
	
	UsePeripherals = SmallBusinessReUse.UsePeripherals();
	If UsePeripherals Then
		GetRefsToEquipment();
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	
	ControlAtWarehouseDisabled = Not Constants.ControlBalancesOnPosting.Get()
						   OR Not Constants.ControlBalancesDuringCreationCRReceipts.Get();
	
	Items.RemoveReservation.Visible = Not ControlAtWarehouseDisabled;
	
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.DocumentCurrency));
	ExchangeRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	Multiplicity = ?(
		//( elmi # 08.5
	    //StructureByCurrency.ExchangeRate = 0,
		  StructureByCurrency.Multiplicity = 0,
		//) elmi

		1,
		StructureByCurrency.Multiplicity
	);
	
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Constants.NationalCurrency.Get()));
	RateNationalCurrency = StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
	EndIf;
	
	CurrencyTransactionsAccounting = Constants.FunctionalCurrencyTransactionsAccounting.Get();
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, Object.DocumentCurrency, ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	CashCRUseWithoutEquipmentConnection = Object.CashCR.UseWithoutEquipmentConnection;
	
	SetEnabledOfReceiptPrinting();
	
	Items.InventoryAmountDiscountsMarkups.Visible = Constants.FunctionalOptionUseDiscountsMarkups.Get();
	
	If Object.Status = Enums.ReceiptCRStatuses.Issued
	AND Not CashCRUseWithoutEquipmentConnection Then
		SetModeReadOnly();
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	SaleFromWarehouse = Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Warehouse;
	
	Items.InventoryPrice.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	Items.InventoryAmount.ReadOnly 				= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse; 
	Items.InventoryDiscountPercentMargin.ReadOnly  = Not AllowedEditDocumentPrices;
	Items.InventoryAmountDiscountsMarkups.ReadOnly 	= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 				= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	
	// StructuralUnit - blank can't be
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	// PickProductsAndServicesInDocuments
	PickProductsAndServicesInDocuments.AssignPickForm(SelectionOpenParameters, Object.Ref.Metadata().Name, "Inventory");
	// End PickProductsAndServicesInDocuments
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// CWP
	SessionIsOpen = Enums.CashCRSessionStatuses.IsOpen;
	
	List.Parameters.SetParameterValue("CashCR", CashCR);
	List.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	List.Parameters.SetParameterValue("Status", Enums.CashCRSessionStatuses.IsOpen);
	List.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	List.Parameters.SetParameterValue("FilterByChange", False);
	List.Parameters.SetParameterValue("CashCRSession", Documents.RetailReport.EmptyRef());
	
	ReceiptCRList.Parameters.SetParameterValue("CashCR", CashCR);
	ReceiptCRList.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	ReceiptCRList.Parameters.SetParameterValue("Status", Enums.CashCRSessionStatuses.IsOpen);
	ReceiptCRList.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	ReceiptCRList.Parameters.SetParameterValue("FilterByChange", False);
	ReceiptCRList.Parameters.SetParameterValue("CashCRSession", Documents.RetailReport.EmptyRef());
	
	ReceiptCRListForReturn.Parameters.SetParameterValue("CashCR", CashCR);
	ReceiptCRListForReturn.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	ReceiptCRListForReturn.Parameters.SetParameterValue("Status", Enums.CashCRSessionStatuses.IsOpen);
	ReceiptCRListForReturn.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	ReceiptCRListForReturn.Parameters.SetParameterValue("FilterByChange", False);
	ReceiptCRListForReturn.Parameters.SetParameterValue("CashCRSession", Documents.RetailReport.EmptyRef());
	
	// StructuralUnit - blank can't be
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	GenerateTitle(StructureStateCashCRSession);
	
	// Fast goods and settings buttons and menu commands.
	FillFastGoods(True);
	ConfigureButtonsAndMenuCommands();
	
	ImportantButtonsColor = StyleColors.UnavailableCellTextColor;
	
	// Period kinds.
	ForCurrentShift = Enums.PeriodsCWPKinds.ForCurrentShift;
	ForUserDefinedPeriod = Enums.PeriodsCWPKinds.ForUserDefinedPeriod;
	ForYesterday = Enums.PeriodsCWPKinds.ForYesterday;
	ForEntirePeriod = Enums.PeriodsCWPKinds.ForEntirePeriod;
	ForPreviousShift = Enums.PeriodsCWPKinds.ForPreviousShift;
	
	FillPeriodKindLists();
	
	SetPeriodAtServer(ForCurrentShift, "ReceiptCRList");
	SetPeriodAtServer(ForCurrentShift, "ReceiptCRListForReturn");
	SetPeriodAtServer(ForCurrentShift, "List");
	
	SwitchJournalQuickProducts = 1;
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	SmallBusinessServer.SetDesignDateColumn(ReceiptCRList);
	SmallBusinessServer.SetDesignDateColumn(ReceiptCRListForReturn);
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	UpdateLabelVisibleTimedOutOver24Hours(StructureStateCashCRSession);
	
	ProductsAndServicesTypeInventory = Enums.ProductsAndServicesTypes.InventoryItem;
	ProductsAndServicesTypeService = Enums.ProductsAndServicesTypes.Service;
	// End CWP
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
		
EndProcedure // OnCreateAtServer()

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	GetChoiceListOfPaymentCardKinds();
	
EndProcedure

// Procedure - OnOpen form event handler.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarcodeScanner,CustomerDisplay");
	// End Peripherals
	
	FillAmountsDiscounts();
	
	RecalculateDocumentAtClient();
	
EndProcedure // OnOpen()

// Procedure - event handler BeforeWriteAtServer form.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		If ValueIsFilled(Object.Ref) Then
			UsePostingMode = PostingModeUse.Regular;
		EndIf;
	EndIf;

EndProcedure

// Procedure is called after closing issue form. Question form is called from a procedure BeforeClose.
//
&AtClient
Procedure BeforeCloseEnd(Result, AdditionalParameters) Export

	//If Result = DialogReturnCode.Yes
	//	Then  Modified = False;
	//	Close();
	//EndIf;

EndProcedure // BeforeCloseEnd()

// Procedure - event handler OnClose form.
//
&AtClient
Procedure OnClose()
	
	// AutomaticDiscounts Display the message about discount calculation when user clicks the "Post and close" button or closes the form by the cross with saving the changes.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification("Update:", 
										GetURL(Object.Ref), 
										String(Object.Ref)+". Automatic discounts (markups) are calculated!", 
										PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts

	// CWP
	CashierWorkplaceServerCall.UpdateSettingsCWP(CWPSetting, DontShowOnOpenCashdeskChoiceForm);
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure // OnClose()

// Procedure - event handler BeforeWrite form.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			CalculatedDiscounts = True;
			
			Message = New UserMessage;
			Message.Text = "Automatic discounts (markups) are calculated!";
			Message.DataKey = Object.Ref;
			Message.Message();
			
			DiscountsCalculatedBeforeWrite = True;
		Else
			Object.DiscountsAreCalculated = True;
			RefreshImageAutoDiscountsAfterWrite = True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

// Procedure - event handler AfterWrite form.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	// AutomaticDiscounts
	If DiscountsCalculatedBeforeWrite Then
		RecalculateDocumentAtClient();
	EndIf;
	
	Notify("RefreshReceiptCRDocumentsListForm");
	
EndProcedure // AfterWrite()

// Procedure - event handler AfterWriteAtServer form.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
		AND IsInputAvailable() AND Not DiscountCardRead Then
		If EventName = "ScanData" Then
			//Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;
			
			BarcodesReceived(Data);
			
		EndIf;
	EndIf;
	// End Peripherals
	
	// DiscountCards
	If DiscountCardRead Then
		DiscountCardRead = False;
	EndIf;
	// End DiscountCards
	
	If EventName = "RefreshReceiptCRDocumentsListForm" Then
		
		For Each CurRow IN Object.Inventory Do
			
			CurRow.DiscountAmount = CurRow.Price * CurRow.Quantity - CurRow.Amount;
			
		EndDo;
		
	ElsIf EventName = "SelectionIsMade" 
		AND ValueIsFilled(Parameter) 
		//Check for the form owner
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID Then
		
		InventoryAddressInStorage = Parameter;
		
		GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
		
		RecalculateDocumentAtClient();
		
	EndIf;
	
	If EventName = "RefreshReceiptCRDocumentsListForm" Then
		Items.List.Refresh();
		
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
		BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
		BalanceInCashierRow = ""+BalanceInCashier;
	EndIf;
	
	If EventName = "ProductsAndServicesIsAddedFromCWP" AND ValueIsFilled(Parameter) Then
		CurrentData = Items.Inventory.CurrentData;
		If CurrentData <> Undefined Then
			If Not ValueIsFilled(CurrentData.ProductsAndServices) Then
				CurrentData.ProductsAndServices = Parameter;
				ProductsAndServicesOnChange(CurrentData);
				RecalculateDocumentAtClient();
			EndIf;
		EndIf;
	EndIf;
	
	If EventName = "CWPSettingChanged" Then
		If CWPSetting = Parameter Then
			FillFastGoods();
			ConfigureButtonsAndMenuCommands();
		EndIf;
	EndIf;
	
	If EventName = "CWP_Write_SupplierInvoiceReturn" Then
		Items.CreateDebitInvoiceForReturn.TextColor = ?(ReceiptIsNotShown, WebColors.Gray, New Color);
		Items.CreateCPVBasedOnReceipt.TextColor = New Color;
		SupplierInvoiceForReturn = Parameter.Ref;
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Parameter.Number, True, True);
		Items.DecorationSupplierInvoice.Title = "Supplier invoice No"+DocumentNumber+" from "+Format(Parameter.Date, "DF=dd.MM.yyyy");
		Items.DecorationSupplierInvoice.Visible = True;
	ElsIf EventName = "CWP_Record_CPV" Then
		Items.CreateCPVBasedOnReceipt.TextColor = ?(ReceiptIsNotShown, WebColors.Gray, New Color);
		CPV = Parameter.Ref;
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Parameter.Number, True, True);
		Items.DecorationCPV.Title = "CPV No"+TrimAll(DocumentNumber)+" from "+Format(Parameter.Date, "DF=dd.MM.yyyy");
		Items.DecorationCPV.Visible = True;
	ElsIf EventName = "CWP_Write_ReceiptCRReturn" Then
		ReceiptCRForReturn = Parameter.Ref;
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Parameter.Number, True, True);
		Items.DecorationReceiptCRForReturn.Title = "Receipt CR on return No"+DocumentNumber+" from "+Format(Parameter.Date, "DF=dd.MM.yyyy");
		Items.CreateReceiptCRForReturn.TextColor = WebColors.Gray;
	EndIf;
	
	If EventName = "RefreshFormsAfterZReportIsDone" Then
		UpdateLabelVisibleTimedOutOver24Hours();
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtServer
Procedure UpdateLabelVisibleTimedOutOver24Hours(StructureStateCashCRSession = Undefined)

	Date = CurrentSessionDate();
	
	If StructureStateCashCRSession = Undefined Then
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	EndIf;
	
	SetLabelVisible = False;
	If StructureStateCashCRSession.SessionIsOpen Then
		MessageText = NStr("en='Cash session is opened';ru='Кассовая смена открыта'");
		If Not Documents.RetailReport.SessionIsOpen(Object.CashCRSession, Date, MessageText) Then
			If Find(MessageText, "24") > 0 Then
				Items.LabelSinceChangeOpeningMore24Hours.Title = MessageText;
				SetLabelVisible = True;
			EndIf;
		EndIf;
	EndIf;
	Items.LabelSinceChangeOpeningMore24Hours.Visible = SetLabelVisible;

EndProcedure


// Procedure - event handler BeforeImportDataFromSettingsAtServer.
//
&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	
	ListForSaving = Settings.Get("ListForSettingSaving");
	If TypeOf(ListForSaving) = Type("ValueList") Then
		// Period recovery.
		PeriodKind = ListForSaving.Get(0).Value;
		If PeriodKind = ForUserDefinedPeriod Then
			StartDate = ListForSaving.Get(1).Value;
			EndDate = ListForSaving.Get(2).Value;
			If PeriodKind <> CatalogPeriodKindTransfer OR Items.List.Period.StartDate <> StartDate OR Items.List.Period.EndDate <> EndDate Then
				SetPeriodAtServer(PeriodKind, "List", New StandardPeriod(StartDate, EndDate));
			EndIf;
		ElsIf PeriodKind <> CatalogPeriodKindTransfer Then
			SetPeriodAtServer(PeriodKind, "List");
		EndIf;
		
		PeriodKind = ListForSaving.Get(3).Value;
		If PeriodKind = ForUserDefinedPeriod Then
			StartDate = ListForSaving.Get(4).Value;
			EndDate = ListForSaving.Get(5).Value;
			If PeriodKind <> ReceiptCRPeriodTransferKind OR Items.ReceiptCRList.Period.StartDate <> StartDate OR Items.ReceiptCRList.Period.EndDate <> EndDate Then
				SetPeriodAtServer(PeriodKind, "ReceiptCRList", New StandardPeriod(StartDate, EndDate));
			EndIf;
		ElsIf PeriodKind <> ReceiptCRPeriodTransferKind Then
			SetPeriodAtServer(PeriodKind, "ReceiptCRList");
		EndIf;
		
		PeriodKind = ListForSaving.Get(6).Value;
		If PeriodKind = ForUserDefinedPeriod Then
			StartDate = ListForSaving.Get(7).Value;
			EndDate = ListForSaving.Get(8).Value;
			If PeriodKind <> ReceiptCRPeriodKindForReturnTransfer OR Items.ReceiptCRListForReturn.Period.StartDate <> StartDate OR Items.ReceiptCRListForReturn.Period.EndDate <> EndDate Then
				SetPeriodAtServer(PeriodKind, "ReceiptCRListForReturn", New StandardPeriod(StartDate, EndDate));
			EndIf;
		ElsIf PeriodKind <> ReceiptCRPeriodKindForReturnTransfer Then
			SetPeriodAtServer(PeriodKind, "ReceiptCRListForReturn");
		EndIf;
		
		// Recovery current page.
		CurrentPageName = ListForSaving.Get(9).Value;
		If ValueIsFilled(CurrentPageName) Then
			Items.GroupSalesAndReturn.CurrentPage = Items[CurrentPageName];
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler OnSaveDataInSettingsAtServer.
//
&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	
	ListForSettingSaving = New ValueList;
	// Period settings. Items 0 - 8.
	ListForSettingSaving.Add(CatalogPeriodKindTransfer);
	ListForSettingSaving.Add(Items.List.Period.StartDate);
	ListForSettingSaving.Add(Items.List.Period.EndDate);
	ListForSettingSaving.Add(ReceiptCRPeriodTransferKind);
	ListForSettingSaving.Add(Items.ReceiptCRList.Period.StartDate);
	ListForSettingSaving.Add(Items.ReceiptCRList.Period.EndDate);
	ListForSettingSaving.Add(ReceiptCRPeriodKindForReturnTransfer);
	ListForSettingSaving.Add(Items.ReceiptCRListForReturn.Period.StartDate);
	ListForSettingSaving.Add(Items.ReceiptCRListForReturn.Period.EndDate);
	// Current page. Item 9.
	ListForSettingSaving.Add(Items.GroupSalesAndReturn.CurrentPage.Name);
	
	Settings.Insert("ListForSettingSaving", ListForSettingSaving);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName = "Inventory";
	
	If Not IsBlankString(SelectionOpenParameters[TabularSectionName]) Then
		
		PickProductsAndServicesInDocumentsClient.OpenPick(ThisForm, TabularSectionName, SelectionOpenParameters[TabularSectionName]);
		Return;
		
	EndIf;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period",					Object.Date);
	SelectionParameters.Insert("Company",			SubsidiaryCompany);
	SelectionParameters.Insert("StructuralUnit",		Object.StructuralUnit);
	SelectionParameters.Insert("DiscountMarkupKind",		Object.DiscountMarkupKind);
	SelectionParameters.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	SelectionParameters.Insert("PriceKind",					Object.PriceKind);
	SelectionParameters.Insert("Currency",					Object.DocumentCurrency);
	SelectionParameters.Insert("VATTaxation",		Object.VATTaxation);
	SelectionParameters.Insert("AmountIncludesVAT",		Object.AmountIncludesVAT);
	SelectionParameters.Insert("DocumentOrganization",	Object.Company);
	SelectionParameters.Insert("ContentUsed",	True);
	SelectionParameters.Insert("AvailablePriceChanging",	Not Items.InventoryPrice.ReadOnly);
	
	If StructuralUnitType = PredefinedValue("Enum.StructuralUnitsTypes.Warehouse") Then
		
		SelectionParameters.Insert("ReservationUsed", True);
		
	Else
		
		SelectionParameters.Insert("QueryByWarehouse", True);
		
	EndIf;
	
	ProductsAndServicesType = New ValueList;
	For Each ArrayElement IN Items[TabularSectionName + "ProductsAndServices"].ChoiceParameters Do
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
	
	BatchStatus = New ValueList;
	For Each ArrayElement IN Items[TabularSectionName + "Batch"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.Status" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem IN ArrayElement.Value Do
					BatchStatus.Add(FixArrayItem);
				EndDo;
			Else
				BatchStatus.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	
	SelectionParameters.Insert("BatchStatus", BatchStatus);
	
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	
	OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm);
	
EndProcedure // ExecutePick()

// Procedure - command handler ShowLog form. Workaround for quick keys implementation for switch.
//
&AtClient
Procedure ShowJournal(Command)
	
	SwitchJournalQuickProducts = 1;
	SwitchJournalQuickProductsOnChange(Items.SwitchJournalQuickProducts);
	
EndProcedure

// Procedure - command handler ShowQuickSales form. Workaround for quick keys implementation for switch.
//
&AtClient
Procedure ShowQuickSales(Command)
	
	SwitchJournalQuickProducts = 2;
	SwitchJournalQuickProductsOnChange(Items.SwitchJournalQuickProducts);
	
EndProcedure

// Procedure - command handler ShowMyCash form. Workaround for quick keys implementation for switch.
//
&AtClient
Procedure ShowMyPettyCash(Command)
	
	SwitchJournalQuickProducts = 3;
	SwitchJournalQuickProductsOnChange(Items.SwitchJournalQuickProducts);
	
EndProcedure

// Procedure - command handler FastGoodsSetting form
//
&AtClient
Procedure QuickProductsSettings(Command)
	
	If ValueIsFilled(CWPSetting) Then
		ParametersStructure = New Structure("Key", CWPSetting);
		OpenForm("Catalog.SettingsCWP.ObjectForm", ParametersStructure, ThisObject);
	Else
		Message = New UserMessage;
		Message.Text = "CWP setting is not selected";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler CreateSupplierInvoiceForReturn form
//
&AtClient
Procedure CreateDebitInvoiceForReturn(Command)
	
	If ReceiptIsNotShown Then
		OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("CWP, OperationKindReturn", True, True), ThisObject, UUID);
	Else
		CurrentData = Items.ReceiptCRList.CurrentData;
		If CurrentData <> Undefined Then
			OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Basis, CWP", CurrentData.Ref, True), ThisObject, UUID);
		Else
			Message = New UserMessage;
			Message.Text = "Receipt CR is not selected!";
			Message.Field = "ReceiptCRList";
			Message.Message();
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - command handler CreateReceiptCRForReturn form
//
&AtClient
Procedure CreateReceiptCRForReturn(Command)
	
	If Not ReceiptCRForReturn.IsEmpty() Then
		Message = New UserMessage;
		Message.Text = "Receipt for return is already created.";
		Message.Field = "Items.CreateReceiptCRForReturn";
		Message.SetData(ThisObject);
		Message.Message();
	Else
		CurrentData = Items.ReceiptCRList.CurrentData;
		If CurrentData <> Undefined Then
			OpenForm("Document.ReceiptCRReturn.ObjectForm", New Structure("Basis", CurrentData.Ref), ThisObject);
		Else
			Message = New UserMessage;
			Message.Text = "Receipt CR is not selected!";
			Message.Field = "ReceiptCRList";
			Message.Message();
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - command handler CreateCPVBasedOnSupplierInvoice form
//
&AtClient
Procedure CreateCPVBasedOnReceipt(Command)
	
	If SupplierInvoiceForReturn.IsEmpty() Then
		Message = New UserMessage;
		Message.Text = "First of all it is necessary to create the supplier invoice for return.";
		Message.Field = "CreateDebitInvoiceForReturn";
		Message.SetData(ThisObject);
		Message.Message();
	Else
		CurrentData = Items.ReceiptCRList.CurrentData;
		If CurrentData <> Undefined OR ReceiptIsNotShown Then
			OpenForm("Document.CashPayment.ObjectForm", New Structure("Basis, CWP", SupplierInvoiceForReturn, True), ThisObject, UUID);
		Else
			Message = New UserMessage;
			Message.Text = "Receipt CR is not selected!";
			Message.Field = "ReceiptCRList";
			Message.Message();
		EndIf;
	EndIf;

EndProcedure

// Procedure - command handler AcceptPayment form.
//
&AtClient
Procedure Pay(Command)
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	If Not StructureStateCashCRSession.SessionIsOpen Then
		CashCRSessionOpen();
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
		
		Object.CashCRSession = StructureStateCashCRSession.CashCRSession;
	EndIf;
	
	If ValueIsFilled(StructureStateCashCRSession.CashCRSessionStatus) Then
		FillPropertyValues(Object, StructureStateCashCRSession,, "Responsible, Division");
	EndIf;
	
	If UseAutomaticDiscounts Then
		If Object.Inventory.Count() > 0 AND Not Object.DiscountsAreCalculated Then
			CalculateDiscountsMarkups(Commands.CalculateDiscountsMarkups);
		EndIf;
	EndIf;
	
	If Object.Inventory.Count() = 0 Or Object.Inventory.Total("Amount") = 0 Then
		Message = New UserMessage;
		Message.Text = "Amount to payment = 0!";
		Message.Field = "Object.DocumentAmount";
		Message.Message();
		Return;
	EndIf;
	
	If Not ControlAtWarehouseDisabled Then
		If Not ReserveAtServer() Then
			CommonUseClientServer.MessageToUser("It wasn't succeeded to execute reservation!");
			Return;
		Else
			FillInDetailsForTSInventoryAtClient();
		EndIf;
		Notify("RefreshReceiptCRDocumentsListForm");
	EndIf;
	
	// We will check that there were not goods with the zero price!
	ContinuePaymentReception = True;
	For Each CurrentRow IN Object.Inventory Do
		If CurrentRow.Price = 0 Then
			Message = New UserMessage;
			Message.Text = "In string price is not filled";
			Message.Field = "Object.Inventory["+(CurrentRow.LineNumber-1)+"].Price";
			Message.Message();
			
			ContinuePaymentReception = False;
		EndIf;
		If CurrentRow.Quantity = 0 Then
			Message = New UserMessage;
			Message.Text = "In string quantity isn't filled";
			Message.Field = "Object.Inventory["+(CurrentRow.LineNumber-1)+"].Quantity";
			Message.Message();
			
			ContinuePaymentReception = False;
		EndIf;
		If CurrentRow.ProductsAndServices.IsEmpty() Then
			Message = New UserMessage;
			Message.Text = "In string ProductsAndServices is not selected";
			Message.Field = "Object.Inventory["+(CurrentRow.LineNumber-1)+"].ProductsAndServices";
			Message.Message();
			
			ContinuePaymentReception = False;
		EndIf;
	EndDo;
	
	If Not ContinuePaymentReception Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("PayEnd", ThisForm);
	
	ParametersStructure = New Structure("Object, PaymentWithPaymentCards, DocumentAmount, DocumentCurrency, CardKinds, CashCR, UsePeripherals, POSTerminal, FormID", 
		Object,
		Object.PaymentWithPaymentCards,
		Object.DocumentAmount,
		Object.DocumentCurrency,
		Items.PaymentByChargeCardTypeCards.ChoiceList,
		CashCR,
		UsePeripherals,
		Object.POSTerminal,
		UUID);
		
		
	OpenForm("Document.ReceiptCR.Form.PaymentForm", ParametersStructure,,,,,Notification);
	
EndProcedure

// Procedure updates the form main attribute data after closing payment form.
//
&AtServer
Procedure UpdateDocumentAtServer(ObjectParameter)
	
	ValueToFormData(FormDataToValue(ObjectParameter, Type("DocumentObject.ReceiptCR")), Object);
	
	If Not Object.Ref.IsEmpty() Then
		Try
			LockDataForEdit(Object.Ref, , UUID);
		Except
			//
		EndTry;
	EndIf;
	
	For Each CurrentRow IN Object.Inventory Do
		SetDescriptionForTSRowsInventoryAtServer(CurrentRow);
	EndDo;
	
EndProcedure

// Procedure - command handler AcceptPayment. It is called after closing payment form.
//
&AtClient
Procedure PayEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		// Payments were made by plastic cards or cancel payments by plastic cards and in this case the document was written or posted.
		UpdateDocumentAtServer(Result.Object);
		
		If Result.Button = "Issue receipt" Then
		
			Object.CashReceived = Result.Cash;
			
			Change = Format(Result.Deal, "NFD=2");
			
			RecalculateDocumentAtClient();
			
			GenerateSalesReceipt = Result.GenerateSalesReceipt;
			
			IssueReceiptExecute(Commands.IssueReceipt, GenerateSalesReceipt);
			
		EndIf;
		
	EndIf;
	
	Items.DiscountAmount.UpdateEditText();
	Items.DocumentAmount.UpdateEditText();
	Items.Paid.UpdateEditText();
	
EndProcedure

// Procedure - command handler PrintSalesReceipt form
//
&AtClient
Procedure PrintSalesReceipt(Command)
	
	ReceiptsCRArray = New Array;
	ReceiptCRArrayForReturn = New Array;
	ThereAreRetailSaleReports = False;
	
	For Each ListRow IN Items.List.SelectedRows Do
		If ListRow <> Undefined Then
			If TypeOf(ListRow) = Type("DocumentRef.ReceiptCR") Then
				ReceiptsCRArray.Add(ListRow);
			ElsIf TypeOf(ListRow) = Type("DocumentRef.ReceiptCRReturn") Then
				ReceiptCRArrayForReturn.Add(ListRow);
			Else
				ThereAreRetailSaleReports = True;
			EndIf;
		EndIf;
	EndDo;
	
	If ThereAreRetailSaleReports Then
		Message = New UserMessage;
		Message.Text = "For retail sale reports sales receipt isn't formed.";
		Message.Field = "List";
		Message.Message();
	EndIf;
	
	If ReceiptsCRArray.Count() > 0 Then
		
		OpenParameters = New Structure("PrintManagerName,TemplateNames,CommandParameter,PrintParameters");
		OpenParameters.PrintManagerName = "Document.ReceiptCR";
		OpenParameters.TemplateNames		 = "SalesReceipt";
		OpenParameters.CommandParameter	 = ReceiptsCRArray;
		OpenParameters.PrintParameters	 = Undefined;
		
		OpenForm("CommonForm.PrintingDocuments", OpenParameters, ThisForm, UniqueKey);
		
	EndIf;
	
	If ReceiptCRArrayForReturn.Count() > 0 Then
		
		OpenParameters = New Structure("PrintManagerName,TemplateNames,CommandParameter,PrintParameters");
		OpenParameters.PrintManagerName = "Document.ReceiptCRReturn";
		OpenParameters.TemplateNames		 = "SalesReceipt";
		OpenParameters.CommandParameter	 = ReceiptCRArrayForReturn;
		OpenParameters.PrintParameters	 = Undefined;
		
		OpenForm("CommonForm.PrintingDocuments", OpenParameters, ThisForm, UniqueKey);
		
	EndIf;
	
EndProcedure

// Procedure - command handler Dependencies form
//
&AtClient
Procedure Dependencies(Command)
	
	CurrentDocument = Items.ReceiptCRList.CurrentRow;
	
	If CurrentDocument <> Undefined Then
		OpenForm("CommonForm.DependenciesForm",New Structure("DocumentRef", CurrentDocument),
					ThisObject,
					CurrentDocument.UUID(),
					Undefined
					);
	Else
		Message = New UserMessage;
		Message.Text = "Select document!";
		Message.Field = "ReceiptCRList";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler Reserve on server.
&AtServer
Function ReserveAtServer(CancelReservation = False)
	
	ReturnValue = False;
	If CancelReservation Then
		CurrentDocument = Items.List.CurrentRow;
		If ValueIsFilled(CurrentDocument) AND TypeOf(CurrentDocument) = Type("DocumentRef.ReceiptCR") Then
			DocObject = CurrentDocument.GetObject();
			
			OldStatus = DocObject.Status;
			
			DocObject.Status = Undefined;
			WriteMode = DocumentWriteMode.UndoPosting;
			
			Try
				DocObject.Write(WriteMode);
				If Not DocObject.Posted Then
					ReturnValue = True;
					// If we post object with which work in form you need to update the form object.
					// This situation arises in the following case. 
					// Balance control is set.
					// 1. Click the "Accept payment" button. Document will be written so. Reservation will the executed.
					// 2. IN the payment form click the "Cancel" button.
					// 3. Select current document in list and select "More..."-"Remove reserve".
					// 4. Click the "Accept payment" button.
					If DocObject.Ref = Object.Ref Then
						ValueToFormData(DocObject, Object);
					EndIf;
				EndIf;
			Except
				Message = New UserMessage;
				Message.Text = ErrorDescription();
				Message.Field = "List";
				Message.Message();
			EndTry;
		Else
			Message = New UserMessage;
			Message.Text = "Receipt CR is not selected!";
			Message.Field = "List";
			Message.Message();
		EndIf;
	Else
		OldStatus = Object.Status;
		
		Object.Status = Enums.ReceiptCRStatuses.ProductReserved;
		WriteMode = DocumentWriteMode.Posting;
		
		Try
			If Not Write(New Structure("WriteMode", WriteMode)) Then
				Object.Status = OldStatus;
			Else
				ReturnValue = True;
			EndIf;
		Except
			Object.Status = OldStatus;
			
			Message = New UserMessage;
			Message.Text = "It wasn't succeeded to execute document post!";
			Message.Message();
		EndTry;
		
		SetEnabledOfReceiptPrinting();
	EndIf;
	
	Return ReturnValue;
	
EndFunction // ReserveAtServer()

// Procedure - command handler RemoveReservation.
//
&AtClient
Procedure RemoveReservation(Command)
	
	ReserveAtServer(True);
	
	Notify("RefreshReceiptCRDocumentsListForm");
	
EndProcedure // RemoveReservation()

#EndRegion

#Region ProceduresElementFormEventsHandlers

// Procedure - event handler OnChange input field ProductsAndServicesSearchValue.
//
&AtClient
Procedure ProductsAndServicesSearchValueOnChange(Item)
	
	If ValueIsFilled(ProductsAndServicesSearchValue) Then
		
		NewRow = Object.Inventory.Add();
		NewRow.ProductsAndServices = ProductsAndServicesSearchValue;
		
		ProductsAndServicesSearchValue = Undefined;
		ThisForm.Modified = True;
		
		ProductsAndServicesOnChange(NewRow);
		
		RecalculateDocumentAtClient();
		
		CurrentItem = Items.ProductsAndServicesSearchValue;
		Items.Inventory.CurrentRow = NewRow.GetID();
		
	EndIf;
	
EndProcedure // ProductsAndServicesSearchValueOnChange()

// Procedure - event handler OnChange item ReceiptIsNotShown form.
//
&AtClient
Procedure ReceiptInNotShowedOnChange(Item)
	
	ReceiptIsNotShownOnChangeAtServer();
	
	If Not ReceiptIsNotShown Then
		AttachIdleHandler("ReceiptCRListOnActivateRowIdleProcessing", 0.2, True);
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange item ReceiptIsNotShown on server.
//
&AtServer
Procedure ReceiptIsNotShownOnChangeAtServer()
	
	If ReceiptIsNotShown Then
		SupplierInvoiceForReturn = "";
		CPV = "";
		
		Items.DecorationTitleReceiptsCR.Title = "Create supplier invoice and CPV";
		
		Items.DecorationSupplierInvoice.Title = "";
		Items.DecorationCPV.Title = "";
		
		Items.DecorationReceiptCRForReturn.Visible = False;
		Items.DecorationSupplierInvoice.Visible = True;
		Items.DecorationCPV.Visible = True;
		
		Items.CreateReceiptCRForReturn.Visible = False;
		Items.CreateDebitInvoiceForReturn.Visible = True;
		Items.CreateCPVBasedOnReceipt.Visible = True;
		
		Items.CreateDebitInvoiceForReturn.TextColor = New Color;
		Items.CreateCPVBasedOnReceipt.TextColor = ?(ReceiptIsNotShown, WebColors.Gray, New Color);
		
		Items.PagesReceiptCRList_and_ReceiptCRContent_and_PageWithInscription.CurrentPage = Items.PageWithEmptyLable;
	Else
		Items.DecorationTitleReceiptsCR.Title = "Choose reason for return";
		
		Items.PagesReceiptCRList_and_ReceiptCRContent_and_PageWithInscription.CurrentPage = Items.PageReceiptCRList_and_ReceiptCRContent;
	EndIf;
	
EndProcedure

// Function gets Associated documents of a certain kind, places them
// in a temporary storage and returns address
//
&AtServer
Function PlaceRelatedDocumentsInStorage(ReceiptCR, Kind)
	
	// Fill references on documents.
	Query = New Query;
	
	If Kind = "SupplierInvoice" Then
		Query.Text = 
			"SELECT ALLOWED
			|	SupplierInvoice.Ref AS RelatedDocument
			|FROM
			|	Document.SupplierInvoice AS SupplierInvoice
			|WHERE
			|	SupplierInvoice.Posted
			|	AND SupplierInvoice.ReceiptCR = &ReceiptCR";
	ElsIf Kind = "CashPayment" Then
		Query.Text = 
			"SELECT ALLOWED
			|	SupplierInvoice.Ref,
			|	SupplierInvoice.Number,
			|	SupplierInvoice.Date
			|INTO SupplierInvoice
			|FROM
			|	Document.SupplierInvoice AS SupplierInvoice
			|WHERE
			|	SupplierInvoice.Posted
			|	AND SupplierInvoice.ReceiptCR = &ReceiptCR
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED
			|	CashPayment.Ref AS RelatedDocument
			|FROM
			|	Document.CashPayment AS CashPayment
			|		INNER JOIN SupplierInvoice AS SupplierInvoice
			|		ON CashPayment.BasisDocument = SupplierInvoice.Ref
			|WHERE
			|	CashPayment.Posted";
	ElsIf Kind = "ReceiptCRReturn" Then
		Query.Text = 
			"SELECT ALLOWED
			|	ReceiptCRReturn.Ref AS RelatedDocument
			|FROM
			|	Document.ReceiptCRReturn AS ReceiptCRReturn
			|WHERE
			|	ReceiptCRReturn.Posted
			|	AND ReceiptCRReturn.ReceiptCR = &ReceiptCR";
	EndIf;
	
	Query.SetParameter("ReceiptCR", ReceiptCR);
	
	Result = Query.Execute();
	
	Return PutToTempStorage(
		Result.Unload(),
		UUID
	);
	
EndFunction // PutBasisDocumentsToStorage()

// Procedure - event handler Click item DecorationSupplierInvoice form.
//
&AtClient
Procedure DecorationDebitInvoiceClick(Item)
	
	If ReceiptIsNotShown Then
		If Not SupplierInvoiceForReturn.IsEmpty() Then
			OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Key", SupplierInvoiceForReturn));
		EndIf;
	Else
		CurReceiptCR = Items.ReceiptCRList.CurrentRow;
		If CurReceiptCR = Undefined Then
			Return;
		EndIf;
		
		Modified = True;
		AddressInRelatedDocumentsStorage = PlaceRelatedDocumentsInStorage(CurReceiptCR, "SupplierInvoice");
		FormParameters = New Structure("AddressInRelatedDocumentsStorage", AddressInRelatedDocumentsStorage);
		OpenForm("Document.ReceiptCR.Form.RelatedDocuments", FormParameters
			,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

// Procedure - event handler Click item DecorationCPV form.
//
&AtClient
Procedure DecorationCPVClick(Item)
	
	If ReceiptIsNotShown Then
		If Not CPV.IsEmpty() Then
			OpenForm("Document.CashPayment.ObjectForm", New Structure("Key", CPV));
		EndIf;
	Else
		CurReceiptCR = Items.ReceiptCRList.CurrentRow;
		If CurReceiptCR = Undefined Then
			Return;
		EndIf;
		
		Modified = True;
		AddressInRelatedDocumentsStorage = PlaceRelatedDocumentsInStorage(CurReceiptCR, "CashPayment");
		FormParameters = New Structure("AddressInRelatedDocumentsStorage", AddressInRelatedDocumentsStorage);
		OpenForm("Document.ReceiptCR.Form.RelatedDocuments", FormParameters
			,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

// Procedure - event handler Click item DecorationReceiptCRForReturn form.
//
&AtClient
Procedure CRDecorationForReturnReceiptClick(Item)
		
	CurReceiptCR = Items.ReceiptCRList.CurrentRow;
	If CurReceiptCR = Undefined Then
		Return;
	EndIf;
	
	Modified = True;
	AddressInRelatedDocumentsStorage = PlaceRelatedDocumentsInStorage(CurReceiptCR, "ReceiptCRReturn");
	FormParameters = New Structure("AddressInRelatedDocumentsStorage", AddressInRelatedDocumentsStorage);
	OpenForm("Document.ReceiptCR.Form.RelatedDocuments", FormParameters
		,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure - event handler OnChange item SwitchLogFastGoods form.
//
&AtClient
Procedure SwitchJournalQuickProductsOnChange(Item)
	
	If SwitchJournalQuickProducts = 1 Then // Journal
		Items.CatalogPagesAndQuickProducts.CurrentPage = Items.Journal;
	ElsIf SwitchJournalQuickProducts = 2 Then // Quick sale
		Items.CatalogPagesAndQuickProducts.CurrentPage = Items.QuickSale;
	Else // Main attributes
		Items.CatalogPagesAndQuickProducts.CurrentPage = Items.MainAttributes;
	EndIf;
	
EndProcedure

// Procedure - event handler OnCurrentPageChange item GroupSalesAndReturn form.
//
&AtClient
Procedure GroupSalesAndReturnOnCurrentPageChange(Item, CurrentPage)
	
	SavedInSettingsDataModified = True;
	
EndProcedure

#EndRegion

#Region ProceduresEventHandlersHeaderAttributes

// Procedure - event handler OnChange field POSTerminal form.
//
&AtClient
Procedure POSTerminalOnChange(Item)
	
	POSTerminalOnChangeAtServer();
	
EndProcedure // POSTerminalOnChange()

// Procedure - event handler OnChange field POSTerminal on server.
//
&AtServer
Procedure POSTerminalOnChangeAtServer()
	
	GetRefsToEquipment();
	GetChoiceListOfPaymentCardKinds();
	
EndProcedure // POSTerminalOnChangeAtServer()

// Procedure - event handler OnChange field CashCR.
//
&AtClient
Procedure CashCROnChange(Item)
	
	If CashCR.IsEmpty() Then
		Message = New UserMessage;
		Message.Text = "Cash register can't be empty";
		Message.Field = "CashCR";
		Message.Message();
		
		CashCR = PreviousCashCR;
		Return;
	EndIf;
	
	If CashCR = PreviousCashCR Then
		Return;
	EndIf;
	
	PreviousCashCR = CashCR;
	Object.CashCR = CashCR;
	
	CashParameters = New Structure("CashCurrency");
	CashCROnChangeAtServer(CashParameters);
	
	If Object.Inventory.Count() > 0 Then
		SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
		SmallBusinessClient.RecalculateTabularSectionPricesByCurrency(ThisForm, CashParameters.CashCurrency, "Inventory");
		FillVATRateByVATTaxation();
		SmallBusinessClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
		
		FillAmountsDiscounts();
		
		RecalculateDocumentAtClient();
	EndIf;
	
	// Generate price and currency label.
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, Object.DocumentCurrency, ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure // CashCROnChange()

// Procedure - event handler OnChange field CashRegister on server.
//
&AtServer
Procedure CashCROnChangeAtServer(CashParameters)
	
	CashParameters.Insert("CashCurrency", PreviousCashCR.CashCurrency);
	
	CashCRUseWithoutEquipmentConnection = CashCR.UseWithoutEquipmentConnection;
	
	Object.POSTerminal = Catalogs.POSTerminals.GetPOSTerminalByDefault(Object.CashCR);
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	FillPropertyValues(Object, StructureStateCashCRSession);
	
	Items.RemoveReservation.Visible = Not ControlAtWarehouseDisabled;
	
	UpdateLabelVisibleTimedOutOver24Hours(StructureStateCashCRSession);
	
	BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
	BalanceInCashierRow = ""+BalanceInCashier;
	
	Object.CashCR = CashCR;
	Object.StructuralUnit = CashCR.StructuralUnit;
	Object.PriceKind = CashCR.StructuralUnit.RetailPriceKind;
	If Not ValueIsFilled(Object.DocumentCurrency) Then
		Object.DocumentCurrency = CashCR.CashCurrency;
	EndIf;
	Object.Company = Object.CashCR.Owner;
	Object.Division = Object.CashCR.Division;
	Object.Responsible = SmallBusinessReUse.GetValueByDefaultUser(User, "MainResponsible");
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	Object.IncludeVATInPrice = True;
	
	If Not ValueIsFilled(Object.Ref) Then
		GetChoiceListOfPaymentCardKinds();
	EndIf;
	
	If UsePeripherals Then
		GetRefsToEquipment();
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.DocumentCurrency));
	ExchangeRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	Multiplicity = ?(
		 //( elmi # 08.5
	    //StructureByCurrency.ExchangeRate = 0,
		  StructureByCurrency.Multiplicity = 0,
		//) elmi

		1,
		StructureByCurrency.Multiplicity
	);
	
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Constants.NationalCurrency.Get()));
	RateNationalCurrency = StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	
	FillVATRateByCompanyVATTaxation();
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, Object.DocumentCurrency, ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	CashCRUseWithoutEquipmentConnection = Object.CashCR.UseWithoutEquipmentConnection;
	
	SetEnabledOfReceiptPrinting();
	
	If Object.Status = Enums.ReceiptCRStatuses.Issued
	AND Not CashCRUseWithoutEquipmentConnection Then
		SetModeReadOnly();
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	SaleFromWarehouse = Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Warehouse;
	
	Items.InventoryPrice.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	Items.InventoryAmount.ReadOnly 				= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse; 
	Items.InventoryDiscountPercentMargin.ReadOnly  = Not AllowedEditDocumentPrices;
	Items.InventoryAmountDiscountsMarkups.ReadOnly	= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 				= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	
	// StructuralUnit - blank can't be
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	List.Parameters.SetParameterValue("CashCR", CashCR);
	List.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	List.Parameters.SetParameterValue("Status", Enums.CashCRSessionStatuses.IsOpen);
	List.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	List.Parameters.SetParameterValue("FilterByChange", False);
	List.Parameters.SetParameterValue("CashCRSession", Documents.RetailReport.EmptyRef());
	
	ReceiptCRList.Parameters.SetParameterValue("CashCR", CashCR);
	ReceiptCRList.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	ReceiptCRList.Parameters.SetParameterValue("Status", Enums.CashCRSessionStatuses.IsOpen);
	ReceiptCRList.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	ReceiptCRList.Parameters.SetParameterValue("FilterByChange", False);
	ReceiptCRList.Parameters.SetParameterValue("CashCRSession", Documents.RetailReport.EmptyRef());
	
	ReceiptCRListForReturn.Parameters.SetParameterValue("CashCR", CashCR);
	ReceiptCRListForReturn.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	ReceiptCRListForReturn.Parameters.SetParameterValue("Status", Enums.CashCRSessionStatuses.IsOpen);
	ReceiptCRListForReturn.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	ReceiptCRListForReturn.Parameters.SetParameterValue("FilterByChange", False);
	ReceiptCRListForReturn.Parameters.SetParameterValue("CashCRSession", Documents.RetailReport.EmptyRef());
	
	// StructuralUnit - blank can't be
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	GenerateTitle(StructureStateCashCRSession);
	
	SetPeriodAtServer(ReceiptCRPeriodTransferKind, "ReceiptCRList", 
							  New StandardPeriod(Items.ReceiptCRList.Period.StartDate, Items.ReceiptCRList.Period.EndDate));
	SetPeriodAtServer(ReceiptCRPeriodKindForReturnTransfer, "ReceiptCRListForReturn", 
							  New StandardPeriod(Items.ReceiptCRListForReturn.Period.StartDate, Items.ReceiptCRListForReturn.Period.EndDate));
	SetPeriodAtServer(CatalogPeriodKindTransfer, "List", 
							  New StandardPeriod(Items.List.Period.StartDate, Items.List.Period.EndDate));
	
	// Recalculation TS Inventory
	ResetFlagDiscountsAreCalculatedServer("ChangeCashRegister");
	
EndProcedure // CashCROnChangeAtServer()

// Procedure - event handler OnChange field Company.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	FillVATRateByCompanyVATTaxation();
	
	// Generate price and currency label.
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, Object.DocumentCurrency, ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

// Procedure - event handler OnChange checkbox DoNotShowAtOpenCashChoiceForm.
//
&AtClient
Procedure DoNotShowOnOpenCashierChoiceFormOnChange(Item)
	
	// CWP
	CashierWorkplaceServerCall.UpdateSettingsCWP(CWPSetting, DontShowOnOpenCashdeskChoiceForm);
	
EndProcedure

#EndRegion

#Region ProceduresEventHandlersTablePartAttributes

// Procedure - event handler OnChange column ProductsAndServices TS Inventory.
//
&AtClient
Procedure InventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("Content", "");
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
		
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);		
	// End DiscountCards
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	TabularSectionRow.VATRate = StructureData.VATRate;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnStartEdit of the Inventory form tabular section.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
	EndIf;
	
EndProcedure

// Procedure - event handler OnEditEnd of the Inventory list row.
//
&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateDocumentAtClient();
	
EndProcedure // InventoryOnEditEnd()

// Procedure - event handler AfterDeletion of the Inventory list row.
//
&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	RecalculateDocumentAtClient();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure // ProductsAfterDeletion()

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices",	 TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 	Object.Date);
		StructureData.Insert("DocumentCurrency",	 	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		StructureData.Insert("Price",			 	TabularSectionRow.Price);
		
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price = StructureData.Price;
	
	CalculateAmountInTabularSectionLine();
	
	TabularSectionRow.ProductsAndServicesCharacteristicAndBatch = TrimAll(""+TabularSectionRow.ProductsAndServices)+?(TabularSectionRow.Characteristic.IsEmpty(), "", ". "+TabularSectionRow.Characteristic)+
		?(TabularSectionRow.Batch.IsEmpty(), "", ". "+TabularSectionRow.Batch);
	
EndProcedure // InventoryCharacteristicOnChange()

// Procedure - event handler OnChange column TS Batch Inventory.
//
&AtClient
Procedure DocumentReceiptCRInventoryBatchOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	If TabularSectionRow <> Undefined Then
		TabularSectionRow.ProductsAndServicesCharacteristicAndBatch = "" + TabularSectionRow.ProductsAndServices + ?(TabularSectionRow.Characteristic.IsEmpty(), "", ". "+TabularSectionRow.Characteristic)+
			?(TabularSectionRow.Batch.IsEmpty(), "", ". "+TabularSectionRow.Batch);
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryQuantityOnChange()

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure InventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
		OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine(, False);
	
EndProcedure // InventoryMeasurementUnitChoiceProcessing()

// Procedure - event handler OnChange input field MeasurementUnit.
//
&AtClient
Procedure InventoryMeasurementUnitOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	SetDescriptionForStringTSInventoryAtClient(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the Price entered field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryPriceOnChange()

// Procedure - event handler OnChange of the DiscountMarkupPercent input field.
//
&AtClient
Procedure InventoryDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryDiscountMarkupPercentOnChange()

// Procedure - event handler OnChange input field AmountDiscountsMarkups.
//
&AtClient
Procedure InventoryAmountDiscountsMarkupsOnChange(Item)
	
	CalculateDiscountPercent();
	
EndProcedure

// Procedure - event handler OnChange of the Amount entered field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	// Discount.
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Price = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / ((1 - TabularSectionRow.DiscountMarkupPercent / 100) * TabularSectionRow.Quantity);
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	TabularSectionRow.DiscountAmount = TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.Amount;
	
	// AutomaticDiscounts.
	AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
		
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure // InventoryAmountOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure // InventoryVATRateOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);	
	
EndProcedure // InventoryVATAmountOnChange()

&AtClient
Procedure InventoryOnChange(Item)
	
	ShowHideDealAtClient();
	
EndProcedure

#EndRegion

#Region ProceduresEventHandlersDynamicLists

// Procedure - event handler OnActivateRow item ReceiptCRList.
//
&AtClient
Procedure ReceiptCRListOnRowRevitalization(Item)
	
	// Make a bit more period better, else user will not be able to enter a number in the search field.
	AttachIdleHandler("ReceiptCRListOnActivateRowIdleProcessing", 0.3, True);
	
EndProcedure

// Procedure updates the information on the content, hyperlinks and sets cellar buttons on a Return bookmark.
//
&AtClient
Procedure ReceiptCRListOnActivateRowIdleProcessing()
	
	CurReceiptCR = Items.ReceiptCRList.CurrentRow;
	If CurReceiptCR <> Undefined Then
		FillReceiptAndRefContentOnDocumentsAtServer(CurReceiptCR);
	Else
		ReceiptContent = "";
	EndIf;
	
	DetachIdleHandler("ReceiptCRListOnActivateRowIdleProcessing");
	
EndProcedure

// Procedure fills information about current receipt CR TS content in the ReceiptCRList item.
//
&AtServer
Procedure FillReceiptAndRefContentOnDocumentsAtServer(ReceiptCR)
	
	// Fill receipt content.
	ThisIsFirstString = True;
	For Each CurRow IN ReceiptCR.Inventory Do
		If ThisIsFirstString Then
			ThisIsFirstString = False;
			ReceiptContent = ""+CurRow.ProductsAndServices+". "+Chars.LF+Chars.Tab+GetDescriptionForTSStringInventoryAtServer(CurRow);
		Else
			ReceiptContent = ReceiptContent+Chars.LF+CurRow.ProductsAndServices+". "+Chars.LF+Chars.Tab+GetDescriptionForTSStringInventoryAtServer(CurRow);
		EndIf;
	EndDo;
	
	// Fill references on documents.
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	SupplierInvoice.Ref,
		|	SupplierInvoice.Number,
		|	SupplierInvoice.Date
		|INTO SupplierInvoice
		|FROM
		|	Document.SupplierInvoice AS SupplierInvoice
		|WHERE
		|	SupplierInvoice.Posted
		|	AND SupplierInvoice.ReceiptCR = &ReceiptCR
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SupplierInvoice.Ref,
		|	SupplierInvoice.Number,
		|	SupplierInvoice.Date
		|FROM
		|	SupplierInvoice AS SupplierInvoice
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	CashPayment.Ref,
		|	CashPayment.Date,
		|	CashPayment.Number
		|FROM
		|	Document.CashPayment AS CashPayment
		|		INNER JOIN SupplierInvoice AS SupplierInvoice
		|		ON CashPayment.BasisDocument = SupplierInvoice.Ref
		|WHERE
		|	CashPayment.Posted
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	ReceiptCRReturn.Ref,
		|	ReceiptCRReturn.Number,
		|	ReceiptCRReturn.Date
		|FROM
		|	Document.ReceiptCRReturn AS ReceiptCRReturn
		|WHERE
		|	ReceiptCRReturn.Posted
		|	AND ReceiptCRReturn.ReceiptCR = &ReceiptCR";
	
	Query.SetParameter("ReceiptCR", ReceiptCR);
	
	MResults = Query.ExecuteBatch();
	
	// Define button and hyperlink visible.
	If ReceiptCR.CashCRSession.CashCRSessionStatus = Enums.CashCRSessionStatuses.IsOpen Then
		// Receipt CR on return.
		Selection = MResults[3].Select();
		If Selection.Next() Then
			ReceiptCRForReturn = Selection.Ref;
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
			Items.DecorationReceiptCRForReturn.Title = "Receipt CR on return No"+DocumentNumber+" from "+Format(Selection.Date, "DF=dd.MM.yyyy");
			Items.CreateReceiptCRForReturn.TextColor = WebColors.Gray;
		Else
			ReceiptCRForReturn = Documents.ReceiptCRReturn.EmptyRef();
			Items.DecorationReceiptCRForReturn.Title = "";
			Items.CreateReceiptCRForReturn.TextColor = New Color;
		EndIf;
		
		While Selection.Next() Do
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
			Items.DecorationReceiptCRForReturn.Title = Items.DecorationReceiptCRForReturn.Title + "; "+" #"+DocumentNumber+" from "+Format(Selection.Date, "DF=dd.MM.yyyy");
		EndDo;
		
		Items.CreateReceiptCRForReturn.Visible = True;
		Items.CreateDebitInvoiceForReturn.Visible = False;
		Items.CreateCPVBasedOnReceipt.Visible = False;
		
		Items.DecorationReceiptCRForReturn.Visible = True;
		Items.DecorationSupplierInvoice.Visible = False;
		Items.DecorationCPV.Visible = False;
		
		Items.DecorationTitleReceiptsCR.Title = "Choose reason for return";
	Else
		
		Selection = MResults[3].Select();
		If Selection.Next() Then // Receipt CR on return.
			ReceiptCRForReturn = Selection.Ref;
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
			Items.DecorationReceiptCRForReturn.Title = "Receipt CR on return No"+DocumentNumber+" from "+Format(Selection.Date, "DF=dd.MM.yyyy");
			
			While Selection.Next() Do
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
				Items.DecorationReceiptCRForReturn.Title = Items.DecorationReceiptCRForReturn.Title + "; "+" #"+DocumentNumber+" from "+Format(Selection.Date, "DF=dd.MM.yyyy");
			EndDo;
			
			Items.CreateReceiptCRForReturn.TextColor = WebColors.Gray;
			Items.CreateReceiptCRForReturn.Visible = True;
			Items.CreateDebitInvoiceForReturn.Visible = False;
			Items.CreateCPVBasedOnReceipt.Visible = False;
			
			Items.DecorationReceiptCRForReturn.Visible = True;
			Items.DecorationSupplierInvoice.Visible = False;
			Items.DecorationCPV.Visible = False;
		Else
			// Receipt CR on return.
			ReceiptCRForReturn = Documents.ReceiptCRReturn.EmptyRef();
			Items.DecorationReceiptCRForReturn.Title = "";
			
			// Supplier invoice for return.
			Selection = MResults[1].Select();
			If Selection.Next() Then
				SupplierInvoiceForReturn = Selection.Ref;
				
				Items.CreateDebitInvoiceForReturn.TextColor = WebColors.Gray;
				Items.CreateCPVBasedOnReceipt.TextColor = WebColors.Gray;
				
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
				Items.DecorationSupplierInvoice.Title = "Supplier invoice No"+TrimAll(DocumentNumber)+" from "+Format(Selection.Date, "DF=dd.MM.yyyy");
				
				While Selection.Next() Do
					DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
					Items.DecorationSupplierInvoice.Title = Items.DecorationSupplierInvoice.Title + "; "+" #"+DocumentNumber+" from "+Format(Selection.Date, "DF=dd.MM.yyyy");
				EndDo;
			Else
				SupplierInvoiceForReturn = Documents.SupplierInvoice.EmptyRef();
				
				Items.CreateDebitInvoiceForReturn.TextColor = New Color;
				Items.CreateCPVBasedOnReceipt.TextColor = WebColors.Gray;
				
				Items.DecorationSupplierInvoice.Title = "";
			EndIf;
			
			// CPV.
			Selection = MResults[2].Select();
			If Selection.Next() Then
				CPV = Selection.Ref;
				
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
				Items.DecorationCPV.Title = "CPV No"+DocumentNumber+" from "+Format(Selection.Date, "DF=dd.MM.yyyy");
				Items.CreateCPVBasedOnReceipt.TextColor = WebColors.Gray;
				
				While Selection.Next() Do
					DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
					Items.DecorationCPV.Title = Items.DecorationCPV.Title + "; "+" #"+DocumentNumber+" from "+Format(Selection.Date, "DF=dd.MM.yyyy");
				EndDo;
			Else
				CPV = Documents.GoodsExpense.EmptyRef();
				
				Items.DecorationCPV.Title = "";
				If Not SupplierInvoiceForReturn.IsEmpty() Then
					Items.CreateCPVBasedOnReceipt.TextColor = New Color;
				Else
					Items.CreateCPVBasedOnReceipt.TextColor = WebColors.Gray;
				EndIf;
			EndIf;
			
			Items.CreateReceiptCRForReturn.Visible = False;
			Items.CreateDebitInvoiceForReturn.Visible = True;
			Items.CreateCPVBasedOnReceipt.Visible = True;
			
			Items.DecorationReceiptCRForReturn.Visible = False;
			Items.DecorationSupplierInvoice.Visible = True;
			Items.DecorationCPV.Visible = True;
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler ValueSelection item List.
//
&AtClient
Procedure ValueChoiceList(Item, Value, StandardProcessing)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		If TypeOf(CurrentData.Ref) = Type("DocumentRef.ReceiptCR") Then
			OpenForm("Document.ReceiptCR.ObjectForm", New Structure("Key", CurrentData.Ref));
		ElsIf TypeOf(CurrentData.Ref) = Type("DocumentRef.ReceiptCR") Then
			OpenForm("Document.ReceiptCRReturn.ObjectForm", New Structure("Key", CurrentData.Ref));
		ElsIf TypeOf(CurrentData.Ref) = Type("DocumentRef.ReceiptCR") Then
			OpenForm("Document.RetailReport.ObjectForm", New Structure("Key", CurrentData.Ref));
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region CommandFormPanelsActionProcedures

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure // ImportDataFromDCT()

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en='It is required to select a line to get weight for it.';ru='Необходимо выбрать строку, для которой необходимо получить вес.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NOTifyDescription, UUID);
		
	EndIf;
	
EndProcedure // GetWeight()

// Procedure - command handler GetWeight form. It is executed after obtaining weight from electronic scales.
//
&AtClient
Procedure GetWeightEnd(Weight, Parameters) Export
	
	TabularSectionRow = Parameters;
	
	If Not Weight = Undefined Then
		If Weight = 0 Then
			MessageText = NStr("en='Electronic scales returned zero weight.';ru='Электронные весы вернули нулевой вес.'");
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
			CalculateAmountInTabularSectionLine();
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler Click item PricesAndCurrency form.
//
&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	
EndProcedure // EditPricesAndCurrency()

// Procedure - command handler IncreaseQuantity form.
//
&AtClient
Procedure GroupQuantity(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	If CurrentData <> Undefined Then
		CurrentData.Quantity = CurrentData.Quantity + 1;
		CalculateAmountInTabularSectionLine();
		RecalculateDocumentAtClient();
	Else
		Message = New UserMessage;
		Message.Text = "String is not selected!";
		Message.Field = "Object.Inventory";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler ReduceQuantity form.
//
&AtClient
Procedure ReduceQuantity(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	If CurrentData <> Undefined Then
		CurrentData.Quantity = CurrentData.Quantity - 1;
		CalculateAmountInTabularSectionLine();
		RecalculateDocumentAtClient();
	Else
		Message = New UserMessage;
		Message.Text = "String is not selected!";
		Message.Field = "Object.Inventory";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler ChangeQuantityByCalculator form.
//
&AtClient
Procedure ChangeQuantityUsingCalculator(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	If CurrentData <> Undefined Then
		Notification = New NotifyDescription("ChangeQuantityUsingCalculatorEnd", ThisForm);
		
		ParametersStructure = New Structure("Quantity, ProductsAndServicesCharacteristicAndBatch, Price, Amount, DiscountMarkupPercent, AutomaticDiscountPercent", 
			CurrentData.Quantity, 
			CurrentData.ProductsAndServicesCharacteristicAndBatch,
			CurrentData.Price,
			CurrentData.Amount,
			CurrentData.DiscountMarkupPercent,
			CurrentData.AutomaticDiscountsPercent);
			
		OpenForm("Document.ReceiptCR.Form.FormEnterQuantity", ParametersStructure,,,,,Notification);
	Else
		Message = New UserMessage;
		Message.Text = "String is not selected!";
		Message.Field = "Object.Inventory";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler ChangeQuantityByCalculatorEnd after closing quantity change form.
//
&AtClient
Procedure ChangeQuantityUsingCalculatorEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		CurrentData = Items.Inventory.CurrentData;
		If CurrentData <> Undefined Then
			CurrentData.Quantity = Result.Quantity;
			CalculateAmountInTabularSectionLine();
			RecalculateDocumentAtClient();
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - command handler ClearTSInventory form.
//
&AtClient
Procedure ClearTSInventory(Command)
	
	If Object.Inventory.Count() = 0 Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("ClearTSInventoryEnd", ThisObject);
	ShowQueryBox(NOTifyDescription, "Clear tabular section?", QuestionDialogMode.YesNo,,DialogReturnCode.Yes);
	
EndProcedure

// Procedure - command handler ClearTSInventoryEnd after confirmation delete all strings TS inventory in issue form.
//
&AtClient
Procedure ClearTSInventoryEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		Object.Inventory.Clear();
	EndIf;

EndProcedure

// Procedure - command handler OpenProductsAndServicesCard form.
//
&AtClient
Procedure OpenProductsAndServicesCard(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	If CurrentData <> Undefined Then
		MTypeRestriction = New Array;
		MTypeRestriction.Add(ProductsAndServicesTypeInventory);
		MTypeRestriction.Add(ProductsAndServicesTypeService);
		
		AdditParameters = New Structure("TypeRestriction", MTypeRestriction);
		FillingValues = New Structure("ProductsAndServicesType", MTypeRestriction);
		
		NewPositionProductsAndServicesParameters = New Structure("Key, AdditionalParameters, FillingValues", CurrentData.ProductsAndServices, AdditParameters, FillingValues);
		OpenForm("Catalog.ProductsAndServices.ObjectForm", NewPositionProductsAndServicesParameters, ThisObject);
	Else
		Message = New UserMessage;
		Message.Text = "String is not selected!";
		Message.Field = "Object.Inventory";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler ListCreateReceiptCRForReturn form.
//
&AtClient
Procedure ListCreateReceiptCRForReturn(Command)
	
	MessageText = "";
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		If TypeOf(CurrentData.Ref) = Type("DocumentRef.ReceiptCR") Then
			OpenForm("Document.ReceiptCRReturn.ObjectForm", New Structure("Basis", CurrentData.Ref));
		Else
			MessageText = "Receipt CR for return is not allowed to enter based on kind documents """+TypeOf(CurrentData.Ref)+""".";
		EndIf;
	Else
		MessageText = "Receipt CR is not selected!";
	EndIf;
	
	If MessageText <> "" Then
		Message = New UserMessage;
		Message.Text = MessageText;
		Message.Field = "List";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler ListCreateSupplierInvoiceForReturn form.
//
&AtClient
Procedure CreateSupplierInvoiceListForReturn(Command)
	
	MessageText = "";
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		If TypeOf(CurrentData.Ref) = Type("DocumentRef.ReceiptCR") Then
			OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Basis, CWP", CurrentData.Ref, True), ThisObject, UUID);
		Else
			MessageText = "Receipt CR for return is not allowed to enter based on kind documents """+TypeOf(CurrentData.Ref)+""".";
		EndIf;
	Else
		MessageText = "Receipt CR is not selected!";
	EndIf;
	
	If MessageText <> "" Then
		Message = New UserMessage;
		Message.Text = MessageText;
		Message.Field = "List";
		Message.Message();
	EndIf;
	
EndProcedure

#EndRegion

#Region AutomaticDiscounts

// Procedure - form command handler CalculateDiscountsMarkups.
//
&AtClient
Procedure CalculateDiscountsMarkups(Command)
	
	If Object.Inventory.Count() = 0 Then
		If Object.DiscountsMarkups.Count() > 0 Then
			Object.DiscountsMarkups.Clear();
		EndIf;
		Return;
	EndIf;
	
	CalculateDiscountsMarkupsClient();
	
EndProcedure

// Procedure calculates discounts by document.
//
&AtClient
Procedure CalculateDiscountsMarkupsClient()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	
	RecalculateDocumentAtClient();
	
EndProcedure

// Function compares discount calculating data on current moment with data of the discount last calculation in document.
// If the discounts are changed, the function returns True.
//
&AtServer
Function DiscountsChanged()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                False);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	
	DiscountsChanged = False;
	
	LineCount = AppliedDiscounts.TableDiscountsMarkups.Count();
	If LineCount <> Object.DiscountsMarkups.Count() Then
		DiscountsChanged = True;
	Else
		
		If Object.Inventory.Total("AutomaticDiscountAmount") <> Object.DiscountsMarkups.Total("Amount") Then
			DiscountsChanged = True;
		EndIf;
		
		If Not DiscountsChanged Then
			For LineNumber = 1 To LineCount Do
				If    Object.DiscountsMarkups[LineNumber-1].Amount <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].Amount
					OR Object.DiscountsMarkups[LineNumber-1].ConnectionKey <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].ConnectionKey
					OR Object.DiscountsMarkups[LineNumber-1].DiscountMarkup <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].DiscountMarkup Then
					DiscountsChanged = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	If DiscountsChanged Then
		AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	EndIf;
	
	Return DiscountsChanged;
	
EndFunction

// Procedure calculates discounts by document.
//
&AtServer
Procedure CalculateDiscountsMarkupsOnServer(ParameterStructure)
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	
	AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	
	Modified = True;
	
	DiscountsMarkupsServerOverridable.UpdateDiscountDisplay(Object, "Inventory");
	
	If Not Object.DiscountsAreCalculated Then
	
		Object.DiscountsAreCalculated = True;
	
	EndIf;
	
	Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
	
	ThereAreManualDiscounts = Constants.FunctionalOptionUseDiscountsMarkups.Get();
	For Each CurrentRow IN Object.Inventory Do
		ManualDiscountCurAmount = ?(ThereAreManualDiscounts, CurrentRow.Price * CurrentRow.Quantity * CurrentRow.DiscountMarkupPercent / 100, 0);
		CurAmountDiscounts = ManualDiscountCurAmount + CurrentRow.AutomaticDiscountAmount;
		If CurAmountDiscounts >= CurrentRow.Amount AND CurrentRow.Price > 0 Then
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = True;
		Else
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = False;
		EndIf;
		
		SetDescriptionForTSRowsInventoryAtServer(CurrentRow);
	EndDo;
	
EndProcedure

// Procedure opens a common form for information analysis about discounts by current row.
//
&AtClient
Procedure OpenInformationAboutDiscountsClient()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	ParameterStructure.Insert("OnlyMessagesAfterRegistration",   False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	If Not Object.DiscountsAreCalculated Then
		QuestionText = NStr("en='Discounts (markups) are not calculated, calculate?';ru='Скидки (наценки) не рассчитаны, рассчитать?'");
		
		AdditionalParameters = New Structure; 
		AdditionalParameters.Insert("ParameterStructure", ParameterStructure);
		NotificationHandler = New NotifyDescription("NotificationQueryCalculateDiscounts", ThisObject, AdditionalParameters);
		ShowQueryBox(NotificationHandler, QuestionText, QuestionDialogMode.YesNo);
	Else
		CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	EndIf;
	
EndProcedure

// End modeless window opening "ShowDoQueryBox()". Procedure opens a common form for information analysis about discounts by current row.
//
&AtClient
Procedure NotificationQueryCalculateDiscounts(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	ParameterStructure = AdditionalParameters.ParameterStructure;
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	
EndProcedure

// Procedure opens a common form for information analysis about discounts by current row after calculation of automatic discounts (if it was necessary).
//
&AtClient
Procedure CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure)
	
	If Not ValueIsFilled(AddressDiscountsAppliedInTemporaryStorage) Then
		CalculateDiscountsMarkupsClient();
	EndIf;
	
	CurrentData = Items.Inventory.CurrentData;
	MarkupsDiscountsClient.OpenFormAppliedDiscounts(CurrentData, Object, ThisObject);
	
EndProcedure

// Procedure - event handler Selection of the Inventory tabular section.
//
&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If (Item.CurrentItem = Items.InventoryAutomaticDiscountPercent OR Item.CurrentItem = Items.InventoryAutomaticDiscountAmount)
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient();
		
	EndIf;
	
EndProcedure

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculatedServer(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to recalculate discounts.
//
&AtClient
Function ClearCheckboxDiscountsAreCalculatedClient(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox DiscountsAreCalculated if it is necessary and returns True if it is required to recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn);
	
EndFunction

// Procedure executes necessary actions when creating the form on server.
//
&AtServer
Procedure AutomaticDiscountsOnCreateAtServer()
	
	InstalledGrayColor = False;
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscountsMarkups");
	If UseAutomaticDiscounts Then
		If Object.Inventory.Count() = 0 Then
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
			InstalledGrayColor = True;
		ElsIf Not Object.DiscountsAreCalculated Then
			Object.DiscountsAreCalculated = False;
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateRed;
		Else
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure calls the report form "Used discounts" for current document in the "List" item.
//
&AtClient
Procedure AppliedDiscounts(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		MessageText = "Document is not selected.
		|Go to ""Applied discounts"" is possible only after the selection in list.";
		Message = New UserMessage;
		Message.Text = MessageText;
		Message.Field = "List";
		Message.Message();
		Return;
	ElsIf TypeOf(CurrentData.Ref) <> Type("DocumentRef.RetailReport") Then
		FormParameters = New Structure("DocumentRef", CurrentData.Ref);
		OpenForm("Report.DiscountsAppliedInDocument.Form.ReportForm", FormParameters, ThisObject, UUID);
	Else
		MessageText = "Select receipt CR or receipt CR for return";
		Message = New UserMessage;
		Message.Text = MessageText;
		Message.Field = "List";
		Message.Message();
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region DiscountCards

// Procedure - Command handler ReadDiscountCard forms.
//
&AtClient
Procedure ReadDiscountCard(Command)
	
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", , ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
EndProcedure

// Final part of procedure - of the form command handler ReadDiscountCard.
// Is called after read form closing of discount card.
//
&AtClient
Procedure ReadDiscountCardClickEnd(ReturnParameters, Parameters) Export

	If TypeOf(ReturnParameters) = Type("Structure") Then
		DiscountCardRead = ReturnParameters.DiscountCardRead;
		DiscountCardIsSelected(ReturnParameters.DiscountCard);
	EndIf;

EndProcedure

// Procedure - selection handler of discount card, beginning.
//
&AtClient
Procedure DiscountCardIsSelected(DiscountCard)

	ShowUserNotification(
		NStr("en='Discount card read';ru='Считана дисконтная карта'"),
		GetURL(DiscountCard),
		StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='Discount card %1 is read';ru='Считана дисконтная карта %1'"), DiscountCard),
		PictureLib.Information32);
	
	DiscountCardIsSelectedAdditionally(DiscountCard);
		
EndProcedure

// Procedure - selection handler of discount card, end.
//
&AtClient
Procedure DiscountCardIsSelectedAdditionally(DiscountCard)
	
	If Not Modified Then
		Modified = True;
	EndIf;
	
	Object.DiscountCard = DiscountCard;
	Object.DiscountPercentByDiscountCard = SmallBusinessServer.CalculateDiscountPercentByDiscountCard(Object.Date, DiscountCard);
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, Object.DocumentCurrency, ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	If Object.Inventory.Count() > 0 Then
		Text = NStr("en='Refill discounts in all rows?';ru='Перезаполнить скидки во всех строках?'");
		Notification = New NotifyDescription("DiscountCardIsSelectedAdditionallyEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

// Procedure - selection handler of discount card, end.
//
&AtClient
Procedure DiscountCardIsSelectedAdditionallyEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		Discount = SmallBusinessServer.GetDiscountPercentByDiscountMarkupKind(Object.DiscountMarkupKind) + Object.DiscountPercentByDiscountCard;
	
		For Each TabularSectionRow IN Object.Inventory Do
			
			TabularSectionRow.DiscountMarkupPercent = Discount;
			
			CalculateAmountInTabularSectionLine(TabularSectionRow);
			        
		EndDo;
	EndIf;
	
	RecalculateDocumentAtClient();
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("DiscountRecalculationByDiscountCard");

EndProcedure

#EndRegion

#Region Peripherals

// Procedure displays information output on the customer display.
//
// Parameters:
//  No.
//
&AtClient
Procedure DisplayInformationOnCustomerDisplay()

	If Displays = Undefined Then
		Displays = EquipmentManagerClientReUse.GetEquipmentList("CustomerDisplay", , EquipmentManagerServerCall.GetClientWorkplace());
	EndIf;
	
	display = Undefined;
	DPText = ?(
		Items.Inventory.CurrentData = Undefined,
		"",
		TrimAll(Items.Inventory.CurrentData.ProductsAndServices)
	  + Chars.LF
	  + NStr("en='Total: ';ru='Итого: '")
	  + Format(Object.DocumentAmount, "NFD=2; NGS=' '; NZ=0")
	);
	
	For Each display IN Displays Do
		
		// Data preparation
		InputParameters  = New Array();
		Output_Parameters = Undefined;
		
		InputParameters.Add(DPText);
		InputParameters.Add(0);
		
		Result = EquipmentManagerClient.RunCommand(
			display.Ref,
			"DisplayText",
			InputParameters,
				Output_Parameters
		);
		
		If Not Result Then
			MessageText = NStr("en='When using customer display error occurred."
"Additional"
"description: %AdditionalDetails%';ru='При использовании дисплея покупателя произошла ошибка."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
			);
			MessageText = StrReplace(
				MessageText,
				"%AdditionalDetails%",
				Output_Parameters[1]
			);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
	EndDo;
	
EndProcedure // DisplayInformationOnCustomerDisplay()

// Procedure gets data by barcodes.
//
&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	// Transform weight barcodes.
	For Each CurBarcode IN StructureData.BarcodesArray Do
		
		InformationRegisters.ProductsAndServicesBarcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.ProductsAndServicesBarcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode IN StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() <> 0 Then
			
			StructureProductsAndServicesData = New Structure();
			StructureProductsAndServicesData.Insert("Company", StructureData.Company);
			StructureProductsAndServicesData.Insert("ProductsAndServices", BarcodeData.ProductsAndServices);
			StructureProductsAndServicesData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsAndServicesData.Insert("VATTaxation", StructureData.VATTaxation);
			If ValueIsFilled(StructureData.PriceKind) Then
				StructureProductsAndServicesData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsAndServicesData.Insert("DocumentCurrency", StructureData.DocumentCurrency);
				StructureProductsAndServicesData.Insert("AmountIncludesVAT", StructureData.AmountIncludesVAT);
				StructureProductsAndServicesData.Insert("PriceKind", StructureData.PriceKind);
				If ValueIsFilled(BarcodeData.MeasurementUnit)
					AND TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					StructureProductsAndServicesData.Insert("Factor", BarcodeData.MeasurementUnit.Factor);
				Else
					StructureProductsAndServicesData.Insert("Factor", 1);
				EndIf;
				StructureProductsAndServicesData.Insert("Content", "");
				StructureProductsAndServicesData.Insert("DiscountMarkupKind", StructureData.DiscountMarkupKind);
			EndIf;
			// DiscountCards
			StructureProductsAndServicesData.Insert("DiscountPercentByDiscountCard", StructureData.DiscountPercentByDiscountCard);
			StructureProductsAndServicesData.Insert("DiscountCard", StructureData.DiscountCard);
			// End DiscountCards
			BarcodeData.Insert("StructureProductsAndServicesData", GetDataProductsAndServicesOnChange(StructureProductsAndServicesData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.ProductsAndServices.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure // GetDataByBarCodes()

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("PriceKind", Object.PriceKind);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	// DiscountCards
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	// End DiscountCards
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode IN StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("ProductsAndServices,Characteristic,Batch,MeasurementUnit",BarcodeData.ProductsAndServices,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.ProductsAndServices = BarcodeData.ProductsAndServices;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsAndServicesData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsAndServicesData.Price;
				NewRow.DiscountMarkupPercent = BarcodeData.StructureProductsAndServicesData.DiscountMarkupPercent;
				NewRow.VATRate = BarcodeData.StructureProductsAndServicesData.VATRate;
				CalculateAmountInTabularSectionLine(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(FoundString);
				Items.Inventory.CurrentRow = FoundString.GetID();
			EndIf;
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;

EndFunction // FillByBarcodesData()

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisForm, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.ProductsAndServicesBarcodes.Form.ProductsAndServicesBarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisForm,,,,Notification
		);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure // BarcodesAreReceived()

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement IN ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement IN ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		UnknownBarcodes = FillByBarcodesData(BarcodesArray);
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode IN UnknownBarcodes Do
		
		MessageString = NStr("en='Data by barcode is not found: %1%; quantity: %2%';ru='Данные по штрихкоду не найдены: %1%; количество: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
	RecalculateDocumentAtClient();
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// Procedure - tabular section command bar command handler.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	
	NotifyDescription = New NotifyDescription("SearchByBarcodeEnd", ThisObject);
	ShowInputValue(NOTifyDescription, CurBarcode, NStr("en='Enter barcode';ru='Введите штрихкод'"));
	
EndProcedure // SearchByBarcode()

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	If Result = Undefined AND AdditionalParameters = Undefined Then
		Return;
	EndIf;
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
	EndIf;
	
EndProcedure // SearchByBarcode()

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion

#Region SettingDynamicListPeriods

// Procedure fills selection lists in items which manage the period in document lists.
//
&AtServer
Procedure FillPeriodKindLists()
	
	Items.MagazinePeriodKind.ChoiceList.Clear();
	Items.MagazinePeriodKind.ChoiceList.Add(Enums.PeriodsCWPKinds.ForCurrentShift);
	Items.MagazinePeriodKind.ChoiceList.Add(Enums.PeriodsCWPKinds.ForPreviousShift);
	Items.MagazinePeriodKind.ChoiceList.Add(Enums.PeriodsCWPKinds.ForUserDefinedPeriod);
	
	Items.ReceiptCRPeriodKind.ChoiceList.Clear();
	Items.ReceiptCRPeriodKind.ChoiceList.Add(Enums.PeriodsCWPKinds.ForCurrentShift);
	Items.ReceiptCRPeriodKind.ChoiceList.Add(Enums.PeriodsCWPKinds.ForPreviousShift);
	Items.ReceiptCRPeriodKind.ChoiceList.Add(Enums.PeriodsCWPKinds.ForUserDefinedPeriod);
	
	Items.ReceiptCRPeriodKindForReturn.ChoiceList.Clear();
	Items.ReceiptCRPeriodKindForReturn.ChoiceList.Add(Enums.PeriodsCWPKinds.ForCurrentShift);
	Items.ReceiptCRPeriodKindForReturn.ChoiceList.Add(Enums.PeriodsCWPKinds.ForPreviousShift);
	Items.ReceiptCRPeriodKindForReturn.ChoiceList.Add(Enums.PeriodsCWPKinds.ForUserDefinedPeriod);
	
EndProcedure

// Procedure - event handler SelectionDataProcessor item LogPeriodKind form.
//
&AtClient
Procedure JournalPeriodKindChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	SetPeriodAtClient(ValueSelected, "List");
	StandardProcessing = False;
	Items.MagazinePeriodKind.UpdateEditText();
	
EndProcedure

// Procedure - event handler SelectionDataProcessor item ReceiptCRPeriodKind form.
//
&AtClient
Procedure ReceiptCRPeriodKindChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	SetPeriodAtClient(ValueSelected, "ReceiptCRList");
	StandardProcessing = False;
	Items.ReceiptCRPeriodKind.UpdateEditText();
	
EndProcedure

// Procedure - event handler SelectionDataProcessor item ReceiptCRPeriodKindForReturn form.
//
&AtClient
Procedure ReceiptCRPeriodKindForReturnChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	SetPeriodAtClient(ValueSelected, "ReceiptCRListForReturn");
	StandardProcessing = False;
	Items.ReceiptCRPeriodKindForReturn.UpdateEditText();
	
EndProcedure

// Procedure sets dynamic list period.
//
&AtClient
Procedure SetPeriodAtClient(PeriodKindCWP, ListName, ParameterStandardPeriod = Undefined)
	
	If PeriodKindCWP = ThisObject.ForUserDefinedPeriod Then
		
		If ListName = "List" Then
			CatalogPeriodKindTransfer = PeriodKindCWP;
		ElsIf ListName = "ReceiptCRListForReturn" Then
			ReceiptCRPeriodKindForReturnTransfer = PeriodKindCWP;
		ElsIf ListName = "ReceiptCRList" Then
			ReceiptCRPeriodTransferKind = PeriodKindCWP;
		EndIf;
		
		NotifyDescription = New NotifyDescription("SetEndOfPeriod", ThisObject, New Structure("ListName", ListName));
		Dialog = New StandardPeriodEditDialog();
		Dialog.Period = ThisObject.Items[ListName].Period;
		Dialog.Show(NOTifyDescription);
		
	Else
		
		SetPeriodAtServer(PeriodKindCWP, ListName, ParameterStandardPeriod);
		
	EndIf;
	
EndProcedure

// Procedure sets dynamic list period (if it is required period interactive selection).
//
&AtClient
Procedure SetEndOfPeriod(Result, Parameters) Export
	
	SetEndOfPeriodAtServer(Result, Parameters);
	
EndProcedure

// Procedure sets dynamic list period on server (if it is required period interactive selection).
//
&AtServer
Procedure SetEndOfPeriodAtServer(Result, Parameters)
	
	If Result <> Undefined Then
		
		ThisObject[Parameters.ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[Parameters.ListName].Parameters.SetParameterValue("Status", SessionIsOpen);
		ThisObject[Parameters.ListName].Parameters.SetParameterValue("FilterByChange", False);
		
		Items[Parameters.ListName].Period.Variant = Result.Variant;
		Items[Parameters.ListName].Period.StartDate = Result.StartDate;
		Items[Parameters.ListName].Period.EndDate = Result.EndDate;
		Items[Parameters.ListName].Refresh();
		
		If Parameters.ListName = "List" Then
			Items.Date.Visible = True;
			MagazinePeriodKind = GetPeriodPresentation(Result, " - ");
		ElsIf Parameters.ListName = "ReceiptCRListForReturn" Then
			ReceiptCRPeriodKindForReturn = GetPeriodPresentation(Result, " - ");
		ElsIf Parameters.ListName = "ReceiptCRList" Then
			ReceiptCRPeriodKind = GetPeriodPresentation(Result, " - ");
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure sets dynamic list period on server.
//
&AtServer
Procedure SetPeriodAtServer(PeriodKindCWP, ListName, ParameterStandardPeriod = Undefined)
	
	If ListName = "List" Then
		CatalogPeriodKindTransfer = PeriodKindCWP;
	ElsIf ListName = "ReceiptCRListForReturn" Then
		ReceiptCRPeriodKindForReturnTransfer = PeriodKindCWP;
	ElsIf ListName = "ReceiptCRList" Then
		ReceiptCRPeriodTransferKind = PeriodKindCWP;
	EndIf;
	
	If PeriodKindCWP = ForCurrentShift Then
		
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", True);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", False);
		Items[ListName].Period = New StandardPeriod;
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = False;
			MagazinePeriodKind = "For current shift";
		ElsIf ListName = "ReceiptCRListForReturn" Then
			ReceiptCRPeriodKindForReturn = "For current shift";
		ElsIf ListName = "ReceiptCRList" Then
			ReceiptCRPeriodKind = "For current shift";
		EndIf;
		
	ElsIf PeriodKindCWP = ForPreviousShift Then
		
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", True);
		ThisObject[ListName].Parameters.SetParameterValue("CashCRSession", GetLatestClosedCashCRSession());
		Items[ListName].Period = New StandardPeriod;
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = False;
			MagazinePeriodKind = "For last shift";
		ElsIf ListName = "ReceiptCRListForReturn" Then
			ReceiptCRPeriodKindForReturn = "For last shift";
		ElsIf ListName = "ReceiptCRList" Then
			ReceiptCRPeriodKind = "For last shift";
		EndIf;
		
	ElsIf PeriodKindCWP = ForYesterday Then
		
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", False);
		Items[ListName].Refresh();
		Items[ListName].Period.StartDate = BegOfDay(BegOfDay(CurrentDate())-1);
		Items[ListName].Period.EndDate = BegOfDay(CurrentDate())-1;
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = False;
			MagazinePeriodKind = "For yesterday";
		ElsIf ListName = "ReceiptCRListForReturn" Then
			ReceiptCRPeriodKindForReturn = "For yesterday";
		ElsIf ListName = "ReceiptCRList" Then
			ReceiptCRPeriodKind = "For yesterday";
		EndIf;
		
	ElsIf PeriodKindCWP = ForUserDefinedPeriod Then
		
		Items[ListName].Period.StartDate = ParameterStandardPeriod.StartDate;
		Items[ListName].Period.EndDate = ParameterStandardPeriod.EndDate;
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", False);
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = True;
			MagazinePeriodKind = GetPeriodPresentation(Items.List.Period, " - ");
		ElsIf ListName = "ReceiptCRListForReturn" Then
			ReceiptCRPeriodKindForReturn = GetPeriodPresentation(Items.ReceiptCRListForReturn.Period, " - ");
		ElsIf ListName = "ReceiptCRList" Then
			ReceiptCRPeriodKind = GetPeriodPresentation(Items.ReceiptCRList.Period, " - ");
		EndIf;
		
	ElsIf PeriodKindCWP = ForEntirePeriod Then
		
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", False);
		Items[ListName].Period = New StandardPeriod;
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = True;
			MagazinePeriodKind = "During all the time";
		ElsIf ListName = "ReceiptCRListForReturn" Then
			ReceiptCRPeriodKindForReturn = "During all the time";
		ElsIf ListName = "ReceiptCRList" Then
			ReceiptCRPeriodKind = "During all the time";
		EndIf;
		
	EndIf;
	
EndProcedure

// Function returns the standard period presentation.
//
&AtClientAtServerNoContext
Function GetPeriodPresentation(StandardPeriod, Delimiter = " to ")
	
	StartDate = StandardPeriod.StartDate;
	EndDate = StandardPeriod.EndDate;
	If Not ValueIsFilled(StartDate) AND Not ValueIsFilled(EndDate) Then
		Return "During all the time";
	ElsIf Year(StartDate) = Year(EndDate) AND Month(StartDate) = Month(EndDate) Then
		Return Format(StartDate, "DF=dd")+Delimiter+Format(EndDate, "DF=dd.MM.yyyy");
	ElsIf Year(StartDate) = Year(EndDate) Then
		Return Format(StartDate, "DF=dd.MM")+Delimiter+Format(EndDate, "DF=dd.MM.yyyy");
	Else
		Return Format(StartDate, "DF=dd.MM.yyyy")+Delimiter+Format(EndDate, "DF=dd.MM.yyyy");
	EndIf;
	
EndFunction

#EndRegion

#Region QuickSale

// Procedure creates buttons on fast goods panel.
//
&AtServer
Procedure FillFastGoods(OnOpen = False)

	ColumnQuantity = 3;
	
	Workplace = EquipmentManagerServerCall.GetClientWorkplace();
	
	If Not ValueIsFilled(Workplace) Then
		Message = New UserMessage;
		Message.Text = "Failed to identify workplace to work with peripherals!";
		Message.Message();
		Return;
	EndIf;
	
	CWPSetting = CashierWorkplaceServerCall.GetCWPSetup(Workplace);
	If Not ValueIsFilled(CWPSetting) Then
		Message = New UserMessage;
		Message.Text = "Failed to receive the CWP settings for current workplace!";
		Message.Message();
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	QuickSale.ProductsAndServices AS ProductsAndServices,
		|	QuickSale.Characteristic AS Characteristic,
		|	QuickSale.Ctrl,
		|	QuickSale.Shift,
		|	QuickSale.Alt,
		|	QuickSale.Shortcut,
		|	QuickSale.Key,
		|	QuickSale.Title,
		|	QuickSale.ProductsAndServices.UseCharacteristics AS CharacteristicsAreUsed,
		|	QuickSale.ProductsAndServices.Description AS Description,
		|	QuickSale.Characteristic.Description,
		|	CASE
		|		WHEN QuickSale.SortingField = """"
		|			THEN QuickSale.ProductsAndServices.Description
		|		ELSE QuickSale.SortingField
		|	END AS SortingField
		|FROM
		|	Catalog.SettingsCWP.QuickSale AS QuickSale
		|WHERE
		|	QuickSale.Ref = &CWPSetting
		|	AND Not QuickSale.Disabled
		|
		|ORDER BY
		|	SortingField,
		|	ProductsAndServices,
		|	Characteristic
		|AUTOORDER";
	
	Query.SetParameter("CWPSetting", CWPSetting);
	
	MResults = Query.ExecuteBatch();
	
	ResultTable = MResults[0].Unload();
	
	// Delete commands.
	If Not OnOpen Then
		DeletedCommandArray = New Array;
		For Each Command IN Commands Do
			If (Find(Command.Name, "QuickProduct_") > 0) 
				OR (Find(Command.Name, "FastGoodsGroup_") > 0) 
				Then
				DeletedCommandArray.Add(Command);
			EndIf;
		EndDo;
		For Each Command IN DeletedCommandArray Do
			Commands.Delete(Command);
		EndDo;
		// Delete items.
		DeletedItemsArray = New Array;
		For Each Item IN Items Do
			If (Find(Item.Name, "QuickProduct_") > 0) 
				OR (Find(Item.Name, "GroupPaymentByCard_") > 0) 
				OR (Find(Item.Name, "FastGoodsGroup_")) Then
				DeletedItemsArray.Add(Item);
			EndIf;
		EndDo;
		For Each Item IN DeletedItemsArray Do
			Try
				Items.Delete(Item);
			Except EndTry;
		EndDo;
		
		QuickSale.Clear();
	EndIf;
	
	CurAcc = 1;
	For Each QuickProduct IN ResultTable Do
		If Not ValueIsFilled(QuickProduct.ProductsAndServices) Then
			Continue;
		EndIf;
		
		NewRow = QuickSale.Add();
		FillPropertyValues(NewRow, QuickProduct);
		
		ButtonName = "QuickProduct_" + QuickSale.IndexOf(NewRow);
			
		NewCommand = ThisForm.Commands.Add(ButtonName);
		NewCommand.Action = "FastGoodsIsSelected";
		If ValueIsFilled(QuickProduct.Title) Then
			NewCommand.Title = QuickProduct.Title;
		Else
			NewCommand.Title = String(QuickProduct.Description)+?(ValueIsFilled(QuickProduct.CharacteristicDescription), ". "+TrimAll(QuickProduct.CharacteristicDescription), "");
		EndIf;
		NewCommand.Representation               = ButtonRepresentation.Text;
		NewCommand.ModifiesStoredData = True;
		If ValueIsFilled(QuickProduct.Key) Then
			NewCommand.Shortcut           = New Shortcut(Key[QuickProduct.Key], QuickProduct.Alt, QuickProduct.Ctrl, QuickProduct.Shift);
		EndIf;
		
		If CurAcc = 1 OR (CurAcc-1) % ColumnQuantity = 0 Then
			NewFolder = Items.Add("GroupPaymentByCard_"+CurAcc, Type("FormGroup"), Items.ButtonsGroupFastProducts);
			NewFolder.Type = FormGroupType.UsualGroup;
			NewFolder.ShowTitle = False;
			NewFolder.Group = ChildFormItemsGroup.Horizontal;
		EndIf;

		NewButton = Items.Add(ButtonName, Type("FormButton"), NewFolder);
		NewButton.OnlyInAllActions = False;
		NewButton.Visible = True;
		NewButton.CommandName = NewCommand.Name;
		If ValueIsFilled(QuickProduct.Title) Then
			NewButton.Title = TrimAll(QuickProduct.Title);
		Else
			NewButton.Title = TrimAll(QuickProduct.Description)+?(ValueIsFilled(QuickProduct.CharacteristicDescription), ". "+TrimAll(QuickProduct.CharacteristicDescription), "");
		EndIf;
		CombinationPresentation = ShortcutPresentation(NewCommand.Shortcut);
		If ValueIsFilled(CombinationPresentation) Then
			NewButton.Title = Left(TrimAll(NewButton.Title), 20) + " " + CombinationPresentation;
		EndIf;
		NewButton.Width = 7;
		NewButton.Height = 3;
		NewButton.Shortcut = NewCommand.Shortcut;
		
		NewRow.CommandName = ButtonName;
		
		CurAcc = CurAcc + 1;
	EndDo;
	
	If CurAcc > ColumnQuantity Then
		While (CurAcc-1) % ColumnQuantity <> 0 Do
			NewDecoration = Items.Add("LabelDecoration_"+CurAcc, Type("FormDecoration"), NewFolder);
			NewDecoration.Type = FormDecorationType.Label;
			NewDecoration.Title = "";
			NewDecoration.Width = 7;
			NewDecoration.Height = 3;
			
			CurAcc = CurAcc + 1;
		EndDo;
	EndIf;
	
	// Fast goods setting button.
	CurAcc = CurAcc + 1;
	
	NewFolder = Items.Add("GroupPaymentByCard_"+CurAcc, Type("FormGroup"), Items.ButtonsGroupFastProducts);
	NewFolder.Type = FormGroupType.UsualGroup;
	NewFolder.ShowTitle = False;
	NewFolder.Group = ChildFormItemsGroup.Horizontal;
	
	NewButton = Items.Add("QuickProductsSettings", Type("FormButton"), NewFolder);
	NewButton.Representation = ButtonRepresentation.Picture;
	NewButton.OnlyInAllActions = False;
	NewButton.Visible = True;
	NewButton.CommandName = "QuickProductsSettings";
	NewButton.Title = "Settings";
	NewButton.Width = 3;
	NewButton.Height = 1;
	NewButton.Shortcut = New Shortcut(Key.S, True, False, False);
	
EndProcedure // FillFastGoods()

// Procedure - handler fast goods button click.
&AtClient
Procedure FastGoodsIsSelected(Command)
	
	FoundStrings = QuickSale.FindRows(New Structure("CommandName", ""+Command.Name));
	If FoundStrings.Count() > 0 Then
		
		FilterStructure = New Structure("ProductsAndServices, Characteristic", FoundStrings[0].ProductsAndServices, FoundStrings[0].Characteristic);
		InventoryFoundStrings = Object.Inventory.FindRows(FilterStructure);
		
		If InventoryFoundStrings.Count() = 0 Then
			NewRow = Object.Inventory.Add();
			NewRow.ProductsAndServices = FoundStrings[0].ProductsAndServices;
			NewRow.Characteristic = FoundStrings[0].Characteristic;
			
			DocumentConvertedAtClient = False;
			ProductsAndServicesOnChange(NewRow);
		Else
			InventoryFoundStrings[0].Quantity = InventoryFoundStrings[0].Quantity + 1;
			
			DocumentConvertedAtClient = False;
			CalculateAmountInTabularSectionLine(InventoryFoundStrings[0]);
			
			NewRow = InventoryFoundStrings[0];
		EndIf;
		
		SetDescriptionForStringTSInventoryAtClient(NewRow);
		
		Items.Inventory.Refresh();
		Items.List.CurrentRow = NewRow.GetID();
		
		RecalculateDocumentAtClient();
		
		Items.Inventory.CurrentRow = NewRow.GetID();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region KeyboardShortcuts

// The function returns
// the parameters key presentation:
// ValueKey						- Key
//
// Returned
// value String - Key presentation
//
&AtServer
Function KeyPresentation(ValueKey) Export
	
	If String(Key._1) = String(ValueKey) Then
		Return "1";
	ElsIf String(Key._2) = String(ValueKey) Then
		Return "2";
	ElsIf String(Key._3) = String(ValueKey) Then
		Return "3";
	ElsIf String(Key._4) = String(ValueKey) Then
		Return "4";
	ElsIf String(Key._5) = String(ValueKey) Then
		Return "5";
	ElsIf String(Key._6) = String(ValueKey) Then
		Return "6";
	ElsIf String(Key._7) = String(ValueKey) Then
		Return "7";
	ElsIf String(Key._8) = String(ValueKey) Then
		Return "8";
	ElsIf String(Key._9) = String(ValueKey) Then
		Return "9";
	ElsIf String(Key.Num0) = String(ValueKey) Then
		Return "Num 0";
	ElsIf String(Key.Num1) = String(ValueKey) Then
		Return "Num 1";
	ElsIf String(Key.Num2) = String(ValueKey) Then
		Return "Num 2";
	ElsIf String(Key.Num3) = String(ValueKey) Then
		Return "Num 3";
	ElsIf String(Key.Num4) = String(ValueKey) Then
		Return "Num 4";
	ElsIf String(Key.Num5) = String(ValueKey) Then
		Return "Num 5";
	ElsIf String(Key.Num6) = String(ValueKey) Then
		Return "Num 6";
	ElsIf String(Key.Num7) = String(ValueKey) Then
		Return "Num 7";
	ElsIf String(Key.Num8) = String(ValueKey) Then
		Return "Num 8";
	ElsIf String(Key.Num9) = String(ValueKey) Then
		Return "Num 9";
	ElsIf String(Key.NumAdd) = String(ValueKey) Then
		Return "Num +";
	ElsIf String(Key.NumDecimal) = String(ValueKey) Then
		Return "Num .";
	ElsIf String(Key.NumDivide) = String(ValueKey) Then
		Return "Num /";
	ElsIf String(Key.NumMultiply) = String(ValueKey) Then
		Return "Num *";
	ElsIf String(Key.NumSubtract) = String(ValueKey) Then
		Return "Num -";
	Else
		Return String(ValueKey);
	EndIf;
	
EndFunction

// The function returns
// the parameters key presentation:
// Shortcut						- Combination of keys that
// require WithoutBrackets presentation							- The flag indicating that the presentation shall be formed without brackets
//
// Returned
// value String - Key combination presentation
//
&AtServer
Function ShortcutPresentation(Shortcut, WithoutParentheses = False) Export
	
	If Shortcut.Key = Key.None Then
		Return "";
	EndIf;
	
	Description = ?(WithoutParentheses, "", "(");
	If Shortcut.Ctrl Then
		Description = Description + "Ctrl+"
	EndIf;
	If Shortcut.Alt Then
		Description = Description + "Alt+"
	EndIf;
	If Shortcut.Shift Then
		Description = Description + "Shift+"
	EndIf;
	Description = Description + KeyPresentation(Shortcut.Key) + ?(WithoutParentheses, "", ")");
	
	Return Description;
	
EndFunction

#EndRegion

#Region StringPresentationTSInventoryOnReceipt

// Function returns information about quantity and amounts in string form. Used to fill receipt content on a "Return" bookmark.
//
&AtServer
Function GetDescriptionForTSStringInventoryAtServer(String)
	
	DiscountAmountStrings = (String.Quantity * String.Price) - String.Amount;
	ProductsAndServicesCharacteristicAndBatch = TrimAll(String.ProductsAndServices.Description)+?(String.Characteristic.IsEmpty(), "", ". "+String.Characteristic)+?(String.Batch.IsEmpty(), "", ". "+String.Batch);
	If DiscountAmountStrings <> 0 Then
		DiscountPercent = Format(DiscountAmountStrings * 100 / (String.Quantity * String.Price), "NFD=2");
		DiscountText = ?(DiscountAmountStrings > 0, " - "+DiscountAmountStrings, " + "+(-DiscountAmountStrings))+" "+Object.DocumentCurrency
					  +" ("+?(DiscountAmountStrings > 0, " - "+DiscountPercent+"%)", " + "+(-DiscountPercent)+"%)");
	Else
		DiscountText = "";
	EndIf;
	Return ""+String.Price+" "+Object.DocumentCurrency+" X "+String.Quantity+" "+String.MeasurementUnit+DiscountText+" = "+String.Amount+" "+Object.DocumentCurrency;
	
EndFunction

// Function fills the DataByString and ProductsAndServicesCharacteristicAndBatch attributes string TS Inventory.
//
&AtClient
Function SetDescriptionForStringTSInventoryAtClient(String)
	
	DiscountAmountStrings = (String.Quantity * String.Price) - String.Amount;
	String.ProductsAndServicesCharacteristicAndBatch = TrimAll(""+String.ProductsAndServices)+?(String.Characteristic.IsEmpty(), "", ". "+String.Characteristic)+?(String.Batch.IsEmpty(), "", ". "+String.Batch);
	If DiscountAmountStrings <> 0 Then
		DiscountPercent = Format(DiscountAmountStrings * 100 / (String.Quantity * String.Price), "NFD=2");
		DiscountText = ?(DiscountAmountStrings > 0, " - "+DiscountAmountStrings, " + "+(-DiscountAmountStrings))+" "+Object.DocumentCurrency
					  +" ("+?(DiscountAmountStrings > 0, " - "+DiscountPercent+"%)", " + "+(-DiscountPercent)+"%)");
	Else
		DiscountText = "";
	EndIf;
	String.DataOnRow = ""+String.Price+" "+Object.DocumentCurrency+" X "+String.Quantity+" "+String.MeasurementUnit+DiscountText+" = "+String.Amount+" "+Object.DocumentCurrency;
	
	ShowHideDealAtClient();
	
EndFunction

// Function fills the DataByString and ProductsAndServicesCharacteristicAndBatch attributes string TS Inventory.
//
&AtServer
Function SetDescriptionForTSRowsInventoryAtServer(String)
	
	DiscountAmountStrings = (String.Quantity * String.Price) - String.Amount;
	String.ProductsAndServicesCharacteristicAndBatch = TrimAll(""+String.ProductsAndServices)+?(String.Characteristic.IsEmpty(), "", ". "+String.Characteristic)+?(String.Batch.IsEmpty(), "", ". "+String.Batch);
	If DiscountAmountStrings <> 0 Then
		DiscountPercent = Format(DiscountAmountStrings * 100 / (String.Quantity * String.Price), "NFD=2");
		DiscountText = ?(DiscountAmountStrings > 0, " - "+DiscountAmountStrings, " + "+(-DiscountAmountStrings))+" "+Object.DocumentCurrency
					  +" ("+?(DiscountAmountStrings > 0, " - "+DiscountPercent+"%)", " + "+(-DiscountPercent)+"%)");
	Else
		DiscountText = "";
	EndIf;
	String.DataOnRow = ""+String.Price+" "+Object.DocumentCurrency+" X "+String.Quantity+" "+String.MeasurementUnit+DiscountText+" = "+String.Amount+" "+Object.DocumentCurrency;
	
EndFunction

// Function fills the DataByString and ProductsAndServicesCharacteristicAndBatch attributes for all strings TS Inventory.
//
&AtClient
Procedure FillInDetailsForTSInventoryAtClient()
	
	For Each CurrentRow IN Object.Inventory Do
		SetDescriptionForStringTSInventoryAtClient(CurrentRow);
	EndDo;
	
EndProcedure

#EndRegion


// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
