&AtClient
Var UpdateSubordinatedInvoice;

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument()
	
	Document = FormAttributeToValue("Object");
	Document.Filling(Object.BasisDocument, );
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = True;
	Else	
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = False;
	EndIf;
	
EndProcedure // FillByDocument()

// It receives data set from server for the DateOnChange procedure.
//
&AtServer
Function GetDataDateOnChange(DateBeforeChange, SettlementsCurrency)
	
	DATEDIFF = SmallBusinessServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", SettlementsCurrency));
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	StructureData.Insert(
		"CurrencyRateRepetition",
		CurrencyRateRepetition
	);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

// Receives the data set from the server for the CompanyOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	
	StructureData.Insert("Counterparty", SmallBusinessServer.GetCompany(Object.Company));
	StructureData.Insert("BankAccount", Object.Company.BankAccountByDefault);
	StructureData.Insert("BankAccountCashAssetsCurrency", Object.Company.BankAccountByDefault.CashCurrency);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
		
	StructureData.Insert(
		"SettlementsCurrency",
		ContractByDefault.SettlementsCurrency
	);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", ContractByDefault.SettlementsCurrency))
	);
	
	StructureData.Insert(
		"DiscountMarkupKind",
		ContractByDefault.DiscountMarkupKind
	);
	
	StructureData.Insert(
		"PriceKind",
		ContractByDefault.PriceKind
	);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		ContractByDefault.SettlementsInStandardUnits
	);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction // GetDataCounterpartyOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"SettlementsCurrency",
		Contract.SettlementsCurrency
	);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency))
	);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		Contract.SettlementsInStandardUnits
	);
	
	StructureData.Insert(
		"DiscountMarkupKind",
		Contract.DiscountMarkupKind
	);
	
	StructureData.Insert(
		"PriceKind",
		Contract.PriceKind
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	Return StructureData;
	
EndFunction // GetDataContractOnChange()

// Gets payment term by the contract.
//
&AtServerNoContext
Function GetCustomerPaymentDueDate(Contract)
	
	Return Contract.CustomerPaymentDueDate;

EndFunction // GetCustomerPaymentDueDate()

// Procedure fills VAT Rate in tabular section
// by company taxation system.
// 
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company,, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure // FillVATRateByVATTaxation()

// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = True;
		
		For Each TabularSectionRow IN Object.Inventory Do
			
			If ValueIsFilled(TabularSectionRow.ProductsAndServices.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.ProductsAndServices.VATRate;
			Else
				TabularSectionRow.VATRate = Object.Company.DefaultVATRate;
			EndIf;	
			
			VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;	
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = False;
		
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

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
	EndIf;
	
	Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
	StructureData.Insert("Price", Price);
	
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

// VAT amount is calculated in the row of tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure // CalculateVATAmount()

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Amount = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0
			AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// AutomaticDiscounts.
	AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure // CalculateAmountInTabularSectionLine()

// Procedure recalculates amounts in the payment calendar.
//
&AtClient
Procedure RecalculatePaymentCalendar()
	
	For Each CurRow IN Object.PaymentCalendar Do
		CurRow.PaymentAmount = Round(Object.Inventory.Total("Total") * CurRow.PaymentPercentage / 100, 2, 1);
		CurRow.PayVATAmount = Round(Object.Inventory.Total("VATAmount") * CurRow.PaymentPercentage / 100, 2, 1);
	EndDo;
	
EndProcedure // RecalculatePaymentCalendar()

// Procedure recalculates the rate and multiplicity of
// settlement currency when document date change.
//
&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	NewExchangeRate = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
	NewRatio = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		CurrencyRateInLetters = String(Object.Multiplicity) + " " + TrimAll(SettlementsCurrency) + " = " + String(Object.ExchangeRate) + " " + TrimAll(NationalCurrency);
		RateNewCurrenciesInLetters = String(NewRatio) + " " + TrimAll(SettlementsCurrency) + " = " + String(NewExchangeRate) + " " + TrimAll(NationalCurrency);
		
		MessageText = NStr("en = 'As of the date of document the settlement currency (" + CurrencyRateInLetters + ") exchange rate was specified.
									|Set the settlements rate (" + RateNewCurrenciesInLetters + ") according to exchange rate?'");
		
		Mode = QuestionDialogMode.YesNo;
		ShowQueryBox(New NotifyDescription("RecalculatePaymentCurrencyRateConversionFactorEnd", ThisObject, New Structure("NewUnitConversionFactor, NewExchangeRate", NewRatio, NewExchangeRate)), MessageText, Mode, 0);
		Return;
		
	EndIf;
	
	RecalculatePaymentCurrencyRateConversionFactorFragment()
	
EndProcedure // RecalculateRateAccountCurrencyRepetition()

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export
	
	NewRatio = AdditionalParameters.NewRatio;
	NewExchangeRate = AdditionalParameters.NewExchangeRate;
	
	Response = Result;
	
	If Response = DialogReturnCode.Yes Then
		Object.ExchangeRate = NewExchangeRate;
		Object.Multiplicity = NewRatio;
	EndIf;
	
	RecalculatePaymentCurrencyRateConversionFactorFragment();
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorFragment()
	
	// Generate price and currency label.
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, AmountIncludesVAT, CurrencyTransactionsAccounting, RateNationalCurrency, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, RateNationalCurrency, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure // RecalculateRateAccountCurrencyRepetition()

// Procedure executes recalculate in the document tabular section
// after changes in "Prices and currency" form.Column recalculation is executed:
// price, discount, amount, VAT amount, total.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure();
	
	ParametersStructure.Insert("PriceKind",				 Object.PriceKind);
	ParametersStructure.Insert("DocumentCurrency",		 Object.DocumentCurrency);
	ParametersStructure.Insert("VATTaxation",	 Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",	 Object.AmountIncludesVAT);
	ParametersStructure.Insert("Contract",				 Object.Contract);
	ParametersStructure.Insert("ExchangeRate",				 Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",			 Object.Multiplicity);
	ParametersStructure.Insert("Company",			 Counterparty);
	ParametersStructure.Insert("DocumentDate",		 Object.Date);
	ParametersStructure.Insert("RefillPrices",	 RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",		 RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges", False);
	ParametersStructure.Insert("DiscountKind",			 Object.DiscountMarkupKind);
	ParametersStructure.Insert("DiscountCard", Object.DiscountCard);
	// DiscountCards
	ParametersStructure.Insert("Counterparty", Object.Counterparty);
	// End DiscountCards
	ParametersStructure.Insert("WarningText",	 WarningText);
	
	NotifyDescription = New NotifyDescription("ProcessChangesOnButtonPricesAndCurrenciesEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrencyForm", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure // ProcessChangesByButtonPricesAndCurrencies()

// Procedure-handler of the result of opening the "Prices and currencies" form
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrenciesEnd(ClosingResult, AdditionalParameters) Export
	
	// 3. Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	If TypeOf(ClosingResult) = Type("Structure")
	   AND ClosingResult.WereMadeChanges Then
		
		If Object.DocumentCurrency <> ClosingResult.DocumentCurrency Then
			Object.BankAccount = Undefined;
		EndIf;
		
		Object.PriceKind = ClosingResult.PriceKind;
		Object.DiscountMarkupKind = ClosingResult.DiscountKind;
		// DiscountCards
		If ValueIsFilled(ClosingResult.DiscountCard) AND ValueIsFilled(ClosingResult.Counterparty) AND Not Object.Counterparty.IsEmpty() Then
			If ClosingResult.Counterparty = Object.Counterparty Then
				Object.DiscountCard = ClosingResult.DiscountCard;
				Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
			Else // We will show the message and we will not change discount card data.
				CommonUseClientServer.MessageToUser(
				NStr("en='Discount card is not read. Discount card owner does not match with a counterparty in the document.';ru='Дисконтная карта не считана. Владелец дисконтной карты не совпадает с контрагентом в документе.'"),
				,
				"Counterparty",
				"Object");
			EndIf;
		Else
			Object.DiscountCard = ClosingResult.DiscountCard;
			Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
		EndIf;
		// End DiscountCards
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.PaymentsRate;
		Object.Multiplicity = ClosingResult.SettlementsMultiplicity;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.VATTaxation = ClosingResult.VATTaxation;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			  AND ClosingResult.RecalculatePrices Then
			SmallBusinessClient.RecalculateTabularSectionPricesByCurrency(ThisForm, AdditionalParameters.SettlementsCurrencyBeforeChange, "Inventory");
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			FillVATRateByVATTaxation();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			SmallBusinessClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
		EndIf;
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;

	EndIf;
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, AmountIncludesVAT, CurrencyTransactionsAccounting, RateNationalCurrency, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, RateNationalCurrency, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	RecalculatePaymentCalendar();
	
EndProcedure // ProcessChangesOnButtonPricesAndCurrenciesEnd()

// Function returns the label text "Prices and currency".
//
&AtClientAtServerNoContext
Function GenerateLabelPricesAndCurrency(LabelStructure)
	
	LabelText = "";
	
	// Currency.
	If LabelStructure.CurrencyTransactionsAccounting Then
		If ValueIsFilled(LabelStructure.DocumentCurrency) Then
			LabelText = NStr("en='%Currency%';ru='%Currency%'");
			LabelText = StrReplace(LabelText, "%Currency%", TrimAll(String(LabelStructure.DocumentCurrency)));
		EndIf;
	EndIf;
	
	// Prices kind.
	If ValueIsFilled(LabelStructure.PriceKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en='%PriceKind%';ru='%PriceKind%'");
		Else	
			LabelText = LabelText + NStr("en=' • %PriceKind%';ru=' • %PriceKind%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%PriceKind%", TrimAll(String(LabelStructure.PriceKind)));
	EndIf;
	
	// Margins discount kind.
	If ValueIsFilled(LabelStructure.DiscountKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en='%DiscountMarkupKind%';ru='%DiscountMarkupKind%'");
		Else
			LabelText = LabelText + NStr("en='; • %DiscountMarkupKind%';ru='; • %DiscountMarkupKind%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%DiscountMarkupKind%", TrimAll(String(LabelStructure.DiscountKind)));
	EndIf;
	
	// Discount card.
	If ValueIsFilled(LabelStructure.DiscountCard) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en='%DiscountCard%';ru='%DiscountCard%'");
		Else
			LabelText = LabelText + NStr("en=' • %DiscountCard%';ru=' • %DiscountCard%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%DiscountCard%", String(LabelStructure.DiscountPercentByDiscountCard)+"% by map"); //ShortLP(String(LabelStructure.DiscountCard)));
	EndIf;	
	
	If SmallBusinessServer.GetFunctionalOptionValue("UseVAT") Then
	
		// VAT taxation.
		If ValueIsFilled(LabelStructure.VATTaxation) Then
			If IsBlankString(LabelText) Then
				LabelText = LabelText + NStr("en='%VATTaxation%';ru='%VATTaxation%'");
			Else
				LabelText = LabelText + NStr("en=' • %VATTaxation%';ru=' • %VATTaxation%'");
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
	
	EndIf;
	
	Return LabelText;
	
EndFunction // GenerateLabelPricesAndCurrency()

// Peripherals
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
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
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
	
EndProcedure

// End Peripherals

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = Object.Counterparty.DoOperationsByContracts;
	
EndProcedure // SetContractVisible()

// Checks the match of the "Company" and "ContractKind" contract attributes to the terms of the document.
//
&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText, Contract, Document, Company, Counterparty, Cancel)
	
	If Not SmallBusinessReUse.CounterpartyContractsControlNeeded()
		OR Not Counterparty.DoOperationsByContracts Then
		
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractKindsListForDocument(Document);
	
	If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList)
		AND Constants.DoNotPostDocumentsWithIncorrectContracts.Get() Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormOfContractParameters(Document, Company, Counterparty, Contract)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractKinds", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

// Gets the banking account selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormParametersBankAccount(Contract, Company, NationalCurrency)
	
	AttributesContract = CommonUse.ObjectAttributesValues(Contract, "SettlementsCurrency, SettlementsInStandardUnits");
	
	CurrenciesList = New ValueList;
	CurrenciesList.Add(AttributesContract.SettlementsCurrency);
	CurrenciesList.Add(NationalCurrency);
	
	FormParameters = New Structure;
	FormParameters.Insert("SettlementsInStandardUnits", AttributesContract.SettlementsInStandardUnits);
	FormParameters.Insert("Owner", Company);
	FormParameters.Insert("CurrenciesList", CurrenciesList);
	
	Return FormParameters;
	
EndFunction

// Gets the default contract depending on the settlements method.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

// Performs actions when counterparty contract is changed.
//
&AtClient
Procedure ProcessContractChange()
	
	ContractBeforeChange	= Contract;
	Contract 				= Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		StructureData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency = StructureData.SettlementsCurrency;
		
		If Not StructureData.AmountIncludesVAT = Undefined Then
			
			Object.AmountIncludesVAT = StructureData.AmountIncludesVAT;
			
		EndIf;
		
		If ValueIsFilled(Object.Contract) Then 
			Object.ExchangeRate	  = ?(StructureData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity = ?(StructureData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Multiplicity);
		EndIf;
		
		PriceKindChanged = Object.PriceKind <> StructureData.PriceKind 
			AND ValueIsFilled(StructureData.PriceKind);
			
		DiscountKindChanged = Object.DiscountMarkupKind <> StructureData.DiscountMarkupKind 
			AND ValueIsFilled(StructureData.DiscountMarkupKind);
		
		NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
			AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> StructureData.SettlementsCurrency;
			
		OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> StructureData.SettlementsCurrency
			AND Object.Inventory.Count() > 0;

			
		QueryPriceKind = ValueIsFilled(Object.Contract) AND (PriceKindChanged OR DiscountKindChanged);
		If QueryPriceKind Then
			If PriceKindChanged Then
				Object.PriceKind = StructureData.PriceKind;
			EndIf; 
			If DiscountKindChanged Then
				Object.DiscountMarkupKind = StructureData.DiscountMarkupKind;
			EndIf; 
		EndIf;
		
		If Object.DocumentCurrency <> StructureData.SettlementsCurrency Then
			Object.BankAccount = Undefined;
		EndIf;
		Object.DocumentCurrency = StructureData.SettlementsCurrency;
		
		If OpenFormPricesAndCurrencies Then
			
			WarningText = "";
			If QueryPriceKind Then
				
				WarningText = NStr("en='The price and discount conditions in the contract with counterparty differ from price and discount in the document! 
		|Perhaps you have to refill prices.';ru='Договор с контрагентом предусматривает условия цен и скидок, отличные от установленных в документе! 
		|Возможно, необходимо перезаполнить цены.'") + Chars.LF + Chars.LF;
				
			EndIf;
			
			WarningText = WarningText + NStr("en='Settlement currency of the contract with counterparty changed!
		|It is necessary to check the document currency!';ru='Изменилась валюта расчетов по договору с контрагентом!
		|Необходимо проверить валюту документа!'"
			);
			
			ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, PriceKindChanged, WarningText);
			
		ElsIf QueryPriceKind Then
			
			RecalculationRequired = (Object.Inventory.Count() > 0);
			
			LabelStructure = 
				New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, PriceKind, DiscountKind, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", 
					Object.DocumentCurrency, 
					SettlementsCurrency, 
					Object.ExchangeRate, 
					RateNationalCurrency, 
					Object.AmountIncludesVAT, 
					CurrencyTransactionsAccounting, 
					Object.PriceKind, 
					Object.DiscountMarkupKind, 
					Object.VATTaxation, 
					Object.DiscountCard, 
					Object.DiscountPercentByDiscountCard);
					
			PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
			
			If RecalculationRequired Then
				
				MessageText = NStr("en='The price and discount conditions in the contract with counterparty differ from price and discount in the document! 
		|Recalculate the document according to the contract?';ru='Договор с контрагентом предусматривает условия цен и скидок, отличные от установленных в документе! 
		|Пересчитать документ в соответствии с договором?'");
										
				Mode = QuestionDialogMode.YesNo;
				ShowQueryBox(New NotifyDescription("ProcessContractChangeEnd", ThisObject, New Structure("ContractBeforeChange, SettlementsCurrencyBeforeChange, StructureData", ContractBeforeChange, SettlementsCurrencyBeforeChange, StructureData)), MessageText, Mode, 0);
				Return;
				
			EndIf;
			
		Else
			
			LabelStructure = 
				New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, PriceKind, DiscountKind, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", 
					Object.DocumentCurrency, 
					SettlementsCurrency, 
					Object.ExchangeRate, 
					RateNationalCurrency, 
					Object.AmountIncludesVAT, 
					CurrencyTransactionsAccounting, 
					Object.PriceKind, 
					Object.DiscountMarkupKind, 
					Object.VATTaxation, 
					Object.DiscountCard, 
					Object.DiscountPercentByDiscountCard);
					
			PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
			
		EndIf;
		
	EndIf;
	
EndProcedure // ProcessContractChange()

&AtClient
Procedure ProcessContractChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
		RecalculatePaymentCalendar();
		
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

// Sets the current page for document operation kind.
//
// Parameters:
// BusinessOperation - EnumRef.EconomicOperations - Economic operations
//
&AtClient
Procedure SetCurrentPage()
	
	PageName = "";
	
	If Object.CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then
		PageName = "PageBankAccount";
	ElsIf Object.CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		PageName = "PagePettyCash";
	EndIf;  

	PageItem = Items.Find(PageName);
	If PageItem <> Undefined Then
		Items.CashboxBankAccount.Visible = True;
		Items.CashboxBankAccount.CurrentPage = PageItem;
	Else
		Items.CashboxBankAccount.Visible = False;
	EndIf;
	
EndProcedure // SetCurrentPage()

// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
&AtClient
Procedure SetPagesBookmarks()
	
	If Object.SchedulePayment Then
		Items.GroupPaymentsCalendar.Visible = True;
	Else
		Items.GroupPaymentsCalendar.Visible = False;
	EndIf;
	
EndProcedure // SetPagesBookmarks()

// Procedure - Set edit by list option.
//
&AtClient
Procedure SetEditInListOption()
	
	Items.EditInList.Check = Not Items.EditInList.Check;
	
	LineCount = Object.PaymentCalendar.Count();
	
	If Not Items.EditInList.Check
		  AND Object.PaymentCalendar.Count() > 1 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("SetEditInListEndOption", ThisObject, New Structure("LineCount", LineCount)), 
			NStr("en='All rows except the first will be deleted. Continue?';ru='Все строки кроме первой будут удалены. Продолжить?'"),
			QuestionDialogMode.YesNo
		);
		Return;
	EndIf;
	
	SetEditInListFragmentOption();
EndProcedure

&AtClient
Procedure SetEditInListEndOption(Result, AdditionalParameters) Export
	
	LineCount = AdditionalParameters.LineCount;
	
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Items.EditInList.Check = True;
		Return;
	EndIf;
	
	While LineCount > 1 Do
		Object.PaymentCalendar.Delete(Object.PaymentCalendar[LineCount - 1]);
		LineCount = LineCount - 1;
	EndDo;
	Items.PaymentCalendar.CurrentRow = Object.PaymentCalendar[0].GetID();
	
	SetEditInListFragmentOption();

EndProcedure

&AtClient
Procedure SetEditInListFragmentOption()
	
	If Items.EditInList.Check Then
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupPaymentCalendarList;
	Else
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupBillingCalendarString;
	EndIf;

EndProcedure // SetEditByListOption()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR WORK WITH THE SELECTION

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	
	If Not IsBlankString(SelectionOpenParameters[TabularSectionName]) Then
		
		PickProductsAndServicesInDocumentsClient.OpenPick(ThisForm, TabularSectionName, SelectionOpenParameters[TabularSectionName]);
		Return;
		
	EndIf;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period",					Object.Date);
	SelectionParameters.Insert("Company",			Counterparty);
	SelectionParameters.Insert("DocumentOrganization", 	Object.Company);
	SelectionParameters.Insert("Currency",					Object.DocumentCurrency);
	SelectionParameters.Insert("PriceKind",					Object.PriceKind);
	SelectionParameters.Insert("DiscountMarkupKind", 		Object.DiscountMarkupKind);
	SelectionParameters.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	SelectionParameters.Insert("VATTaxation",		Object.VATTaxation);
	SelectionParameters.Insert("AmountIncludesVAT", 		Object.AmountIncludesVAT);
	SelectionParameters.Insert("AvailablePriceChanging",	Not Items.InventoryPrice.ReadOnly);
	
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
	
EndProcedure // Selection()

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
	EndDo;
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;

EndProcedure // GetInventoryFromStorage()

// Procedure - OnCreateAtServer event handler.
// The procedure implements
// - form attribute initialization,
// - setting of the form functional options parameters.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	If Not ValueIsFilled(Object.Ref)
		  AND ValueIsFilled(Object.Counterparty)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		If Not ValueIsFilled(Object.Contract) Then
			
			Object.Contract = Object.Counterparty.ContractByDefault;
			
		EndIf;
		
		If ValueIsFilled(Object.Contract) Then
			
			Object.DocumentCurrency 		= Object.Contract.SettlementsCurrency;
			SettlementsCurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.Contract.SettlementsCurrency));
			Object.ExchangeRate					= ?(SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity			= ?(SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, SettlementsCurrencyRateRepetition.Multiplicity);
			Object.DiscountMarkupKind		= Object.Contract.DiscountMarkupKind;
			Object.PriceKind				= Object.Contract.PriceKind;
			
		EndIf;
		
	EndIf;
	
	// Initialization of form attributes.
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		Query = New Query(
		"SELECT
		|	CASE
		|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
		|			THEN Companies.BankAccountByDefault
		|		ELSE UNDEFINED
		|	END AS BankAccount
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.Ref = &Company");
		Query.SetParameter("Company", Object.Company);
		Query.SetParameter("CashCurrency", Object.DocumentCurrency);
		QueryResult = Query.Execute();
		Selection = QueryResult.Select();
		If Selection.Next() Then
			Object.BankAccount = Selection.BankAccount;
		EndIf;
		Object.PettyCash = Catalogs.PettyCashes.GetPettyCashByDefault(Object.Company);
		
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty					= Object.Counterparty;
	Contract 					= Object.Contract;
	SettlementsCurrency				= Object.Contract.SettlementsCurrency;
	NationalCurrency			= Constants.NationalCurrency.Get();
	StructureByCurrency			= InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", NationalCurrency));
	RateNationalCurrency 		= StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = True;
	Else	
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = False;
	EndIf;
	
	If Not Constants.FunctionalOptionPaymentCalendar.Get() Then
		Items.GroupPaymentsCalendar.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	CurrencyTransactionsAccounting = Constants.FunctionalCurrencyTransactionsAccounting.Get();
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, AmountIncludesVAT, CurrencyTransactionsAccounting, RateNationalCurrency, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, RateNationalCurrency, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Setting contract visible.
	SetContractVisible();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPrice.ReadOnly 				   = Not AllowedEditDocumentPrices;
	Items.InventoryDiscountPercentMargin.ReadOnly = Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly 			   = Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 			   = Not AllowedEditDocumentPrices;
	
	// PickProductsAndServicesInDocuments
	PickProductsAndServicesInDocuments.AssignPickForm(SelectionOpenParameters, Object.Ref.Metadata().Name, "Inventory");
	// End PickProductsAndServicesInDocuments
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
	// Peripherals
	UsePeripherals = SmallBusinessReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
EndProcedure // OnCreateAtServer()

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // OnReadAtServer()

&AtClient
//Procedure - event handler of the form BeforeWrite
//
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentInvoiceForPaymentPosting");
	// StandardSubsystems.PerformanceEstimation
	
	UpdateSubordinatedInvoice = Modified;
	
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

// Procedure - "AfterWrite" event handler of the forms.
//
&AtClient
Procedure AfterWrite()
	
	Notify();
	
EndProcedure // AfterWrite()

// Procedure - form event handler "OnOpen".
//
&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	SetPagesBookmarks();
	SetCurrentPage();
	
	LineCount = Object.PaymentCalendar.Count();
	Items.EditInList.Check = LineCount > 1;
	
	If Object.PaymentCalendar.Count() > 0 Then
		Items.PaymentCalendar.CurrentRow = Object.PaymentCalendar[0].GetID();
	EndIf;
	
	If Items.EditInList.Check Then
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupPaymentCalendarList;
	Else
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupBillingCalendarString;
	EndIf;
	
EndProcedure // OnOpen()

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose()

	// AutomaticDiscounts
	// Display message about discount calculation if you click the "Post and close" or form closes by the cross with change saving.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification("Update:", 
										GetURL(Object.Ref), 
										String(Object.Ref)+". Automatic discounts (markups) are calculated!", 
										PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure // OnClose()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Properties subsystem
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		
		UpdateAdditionalAttributesItems();
		
	EndIf;
	
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
	
	If EventName = "AfterRecordingOfCounterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		SetContractVisible();
		
	ElsIf EventName = "SelectionIsMade" 
		AND ValueIsFilled(Parameter) 
		//Check for the form owner
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		InventoryAddressInStorage = Parameter;
		
		GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
		
		// Payment calendar
		RecalculatePaymentCalendar();
		
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
// 
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(MessageText, Object.Contract, Object.Ref, Object.Company, Object.Counterparty, Cancel);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en='Document is not posted! ';ru='Документ не проведен! '") + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath = "Object";
				Message.Field = "Contract";
				Message.Message();
				Return;
			Else
				Message.Message();
			EndIf;
		EndIf;
		
	EndIf;
	
	// "Properties" mechanism handler
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// "Properties" mechanism handler
	
EndProcedure // BeforeWriteAtServer()

&AtServer
// Procedure-handler of the FillCheckProcessingAtServer event.
//
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure // FillCheckProcessingAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure is called by clicking the PricesCurrency button of the command bar tabular field.
//
&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure // EditPricesAndCurrency()

// Procedure - FillIn button click handler.
//
&AtClient
Procedure FillExecute()
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillInExecuteEnd", ThisObject), NStr("en='Document will be completely refilled by ""Basis""! Continue?';ru='Документ будет полностью перезаполнен по ""Основанию""! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillInExecuteEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		FillByDocument();
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, AmountIncludesVAT, CurrencyTransactionsAccounting, RateNationalCurrency, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, RateNationalCurrency, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		RecalculatePaymentCalendar();
	EndIf;

EndProcedure  // FillExecute()

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en='Enter barcode';ru='Введите штрихкод'"));
	
EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
	EndIf;
	
	// Payment calendar.
	RecalculatePaymentCalendar();

EndProcedure // SearchByBarcode()

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
			CalculateAmountInTabularSectionLine(TabularSectionRow);
			RecalculatePaymentCalendar();
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure // ImportDataFromDCT()

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

// Procedure - EditByList command handler.
//
&AtClient
Procedure EditInList(Command)
	
	SetEditInListOption();
	
EndProcedure // EditByList()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

// Procedure - event handler OnChange of the Date input field.
// IN procedure situation is determined when date change document is
// into document numbering another period and in this case
// assigns to the document new unique number.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(DateBeforeChange, SettlementsCurrency);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(SettlementsCurrency) Then
			RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
		EndIf;	
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, AmountIncludesVAT, CurrencyTransactionsAccounting, RateNationalCurrency, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, RateNationalCurrency, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		// Payment calendar.
		RecalculatePaymentCalendar();
		
		// DiscountCards
		// IN this procedure call not modal window of question is occurred.
		RecalculateDiscountPercentAtDocumentDateChange();
		// End DiscountCards		
	EndIf;
	
	// AutomaticDiscounts
	DocumentDateChangedManually = True;
	ClearCheckboxDiscountsAreCalculatedClient("DateOnChange");

EndProcedure // DateOnChange()

// Procedure - event handler OnChange of the Company input field.
// IN procedure is executed document
// number clearing and also make parameter set of the form functional options.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange();
	Counterparty = StructureData.Counterparty;
	If Object.DocumentCurrency = StructureData.BankAccountCashAssetsCurrency Then
		Object.BankAccount = StructureData.BankAccount;
	EndIf;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, AmountIncludesVAT, CurrencyTransactionsAccounting, RateNationalCurrency, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, RateNationalCurrency, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure // CompanyOnChange()

// Procedure - event handler OnChange input field CashAssetsType.
//
&AtClient
Procedure CashAssetsTypeOnChange(Item)
	
	SetCurrentPage();

EndProcedure // CashAssetsTypeOnChange()

// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		StructureData 		= GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		
		Object.Contract 			= StructureData.Contract;
		ContractBeforeChange	= Contract;
		Contract 				= Object.Contract;
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency 			= StructureData.SettlementsCurrency;
		
		If ValueIsFilled(Object.Contract) Then 
			Object.ExchangeRate	  = ?(StructureData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity = ?(StructureData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Multiplicity);
		EndIf;
		
		PriceKindChanged = Object.PriceKind <> StructureData.PriceKind 
			AND ValueIsFilled(StructureData.PriceKind);
			
		DiscountKindChanged = Object.DiscountMarkupKind <> StructureData.DiscountMarkupKind 
			AND ValueIsFilled(StructureData.DiscountMarkupKind);
			
		// DiscountCards	
		Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
		Object.DiscountPercentByDiscountCard = 0;
		// End DiscountCards
			
		NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
			AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> StructureData.SettlementsCurrency;
			
		OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> StructureData.SettlementsCurrency
			AND Object.Inventory.Count() > 0;
			
		QueryPriceKind = ValueIsFilled(Object.Contract) AND (PriceKindChanged OR DiscountKindChanged);
		If QueryPriceKind Then
			If PriceKindChanged Then
				Object.PriceKind = StructureData.PriceKind;
			EndIf;
			If DiscountKindChanged Then
				Object.DiscountMarkupKind = StructureData.DiscountMarkupKind;
			EndIf;
		EndIf;
		
		If Object.DocumentCurrency <> StructureData.SettlementsCurrency Then
			Object.BankAccount = Undefined;
		EndIf;
		Object.DocumentCurrency = StructureData.SettlementsCurrency;
		
		If OpenFormPricesAndCurrencies Then
			
			WarningText = "";
			If QueryPriceKind Then
				WarningText = NStr("en='The price and discount conditions in the contract with counterparty differ from price and discount in the document! 
		|Perhaps you have to refill prices.';ru='Договор с контрагентом предусматривает условия цен и скидок, отличные от установленных в документе! 
		|Возможно, необходимо перезаполнить цены.'") + Chars.LF + Chars.LF;
			EndIf;
			
			WarningText = WarningText + NStr("en='Settlement currency of the contract with counterparty changed!
		|It is necessary to check the document currency!';ru='Изменилась валюта расчетов по договору с контрагентом!
		|Необходимо проверить валюту документа!'"
			);
			ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, PriceKindChanged, WarningText);
		
		ElsIf QueryPriceKind Then
			
			RecalculationRequired = (Object.Inventory.Count() > 0);
			
			LabelStructure = 
				New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, PriceKind, DiscountKind, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", 
					Object.DocumentCurrency, 
					SettlementsCurrency, 
					Object.ExchangeRate, 
					RateNationalCurrency, 
					Object.AmountIncludesVAT, 
					CurrencyTransactionsAccounting, 
					Object.PriceKind, 
					Object.DiscountMarkupKind, 
					Object.VATTaxation, 
					Object.DiscountCard, 
					Object.DiscountPercentByDiscountCard);
					
			PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
			
			If RecalculationRequired Then
				
				Message = NStr("en='The price and discount conditions in the contract with counterparty differ from price and discount in the document! 
		|Recalculate the document according to the contract?';ru='Договор с контрагентом предусматривает условия цен и скидок, отличные от установленных в документе! 
		|Пересчитать документ в соответствии с договором?'");
				
				ShowQueryBox(New NotifyDescription("CounterpartyOnChangeEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange, ContractBeforeChange, StructureData", SettlementsCurrencyBeforeChange, ContractBeforeChange, StructureData)), Message, QuestionDialogMode.YesNo);
				Return;
				
			EndIf;
			
		Else
			
			LabelStructure = 
				New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, PriceKind, DiscountKind, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", 
					Object.DocumentCurrency, 
					SettlementsCurrency, 
					Object.ExchangeRate, 
					RateNationalCurrency, 
					Object.AmountIncludesVAT, 
					CurrencyTransactionsAccounting, 
					Object.PriceKind, 
					Object.DiscountMarkupKind, 
					Object.VATTaxation, 
					Object.DiscountCard, 
					Object.DiscountPercentByDiscountCard);
					
			PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
			
		EndIf;
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("CounterpartyOnChange");
	
EndProcedure

&AtClient
Procedure CounterpartyOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
		RecalculatePaymentCalendar();
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Contract input field.
// Fills form attributes - exchange rate and multiplicity.
//
&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure // ContractOnChange()

// Procedure - event handler StartChoice of the Contract input field.
//
&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormOfContractParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - event handler SelectionStart input field BankAccount.
//
&AtClient
Procedure BankAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.Contract) Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParametersBankAccount(Object.Contract, Object.Company, NationalCurrency);
	If FormParameters.SettlementsInStandardUnits Then
		
		StandardProcessing = False;
		OpenForm("Catalog.BankAccounts.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the ReflectInPaymentCalendar input field.
//
&AtClient
Procedure SchedulePayOnChange(Item)
	
	SetPagesBookmarks();
	
	If Object.SchedulePayment
	   AND Object.PaymentCalendar.Count() = 0 Then
		NewRow = Object.PaymentCalendar.Add();
		NewRow.PayDate = Object.Date + GetCustomerPaymentDueDate(Object.Contract) * 86400;
		NewRow.PaymentPercentage = 100;
		NewRow.PaymentAmount = Object.Inventory.Total("Total");
		NewRow.PayVATAmount = Object.Inventory.Total("VATAmount");
		Items.PaymentCalendar.CurrentRow = NewRow.GetID();
	ElsIf Not Object.SchedulePayment
			   AND Object.PaymentCalendar.Count() > 0 Then
		Object.PaymentCalendar.Clear();
	EndIf;
	
EndProcedure // SchedulePayOnChange()

// Procedure - event handler OnChange of the PaymentCalendarPaymentPercent input field.
//
&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	PercentOfPaymentTotal = Object.PaymentCalendar.Total("PaymentPercentage");
	
	If PercentOfPaymentTotal > 100 Then
		CurrentRow.PaymentPercentage = CurrentRow.PaymentPercentage - (PercentOfPaymentTotal - 100);
	EndIf;
	
	CurrentRow.PaymentAmount = Round(Object.Inventory.Total("Total") * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PayVATAmount = Round(Object.Inventory.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure // PaymentCalendarPaymentPercentOnChange()

// Procedure - event handler OnChange of the PaymentCalendarPaymentAmount input field.
//
&AtClient
Procedure PaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = Object.Inventory.Total("Total");
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentAmount");
		
	If PaymentCalendarTotal > InventoryTotal Then
		CurrentRow.PaymentAmount = CurrentRow.PaymentAmount - (PaymentCalendarTotal - InventoryTotal);
	EndIf;
	
	CurrentRow.PaymentPercentage = ?(InventoryTotal = 0, 0, Round(CurrentRow.PaymentAmount / InventoryTotal * 100, 2, 1));
	CurrentRow.PayVATAmount = Round(Object.Inventory.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure // PaymentCalendarPaymentSumOnChange()

// Procedure - event handler OnChange of the PaymentCalendarPayVATAmount input field.
//
&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = Object.Inventory.Total("VATAmount");
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PayVATAmount");
	
	If PaymentCalendarTotal > InventoryTotal Then
		CurrentRow.PayVATAmount = CurrentRow.PayVATAmount - (PaymentCalendarTotal - InventoryTotal);
	EndIf;
	
EndProcedure // PaymentCalendarPayVATAmountOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTION ATTRIBUTE EVENT HANDLERS

// Procedure - OnEditEnd event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	// Payment calendar.
	RecalculatePaymentCalendar();

EndProcedure // InventoryOnEditEnd()

// Procedure - AfterDeletion event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure // InventoryAfterDeletion()

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	
	StructureData.Insert("Company", 	 Object.Company);
	StructureData.Insert("ProcessingDate",	 Object.Date);
	StructureData.Insert("PriceKind",			 Object.PriceKind);
	StructureData.Insert("DocumentCurrency",	 Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("ProductsAndServices",	 TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
	StructureData.Insert("Factor",		 1);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	
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
	TabularSectionRow.Content = "";
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	
	StructureData.Insert("ProcessingDate",	 	Object.Date);
	StructureData.Insert("PriceKind",			 	Object.PriceKind);
	StructureData.Insert("DocumentCurrency",	 	Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
	
	StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
	StructureData.Insert("ProductsAndServices",	 	TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic",	 	TabularSectionRow.Characteristic);
	StructureData.Insert("MeasurementUnit", 	TabularSectionRow.MeasurementUnit);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.Content = "";
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryCharacteristicOnChange()

// Procedure - event handler AutoPick of the Content input field.
//
&AtClient
Procedure InventoryContentAutoComplete(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow = Items.Inventory.CurrentData;
		ContentPattern = SmallBusinessServer.GetContentText(TabularSectionRow.ProductsAndServices, TabularSectionRow.Characteristic);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
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
	
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryMeasurementUnitChoiceProcessing()

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure // InventoryPriceOnChange()

// Procedure - event handler OnChange of the DiscountMarkupPercent input field.
//
&AtClient
Procedure InventoryDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure // InventoryDiscountMarkupPercentOnChange()

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
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
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", ThisObject.CurrentItem.CurrentItem.Name);
	
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
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure  // InventoryVATRateOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure // InventoryVATAmountOnChange()

// Procedure - OnStartEdit event handler of the .PaymentCalendar list
//
&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		CurrentRow = Items.PaymentCalendar.CurrentData;
		PercentOfPaymentTotal = Object.PaymentCalendar.Total("PaymentPercentage");
		
		If PercentOfPaymentTotal > 100 Then
			CurrentRow.PaymentPercentage = CurrentRow.PaymentPercentage - (PercentOfPaymentTotal - 100);
		EndIf;
		
		CurrentRow.PaymentAmount = Round(Object.Inventory.Total("Total") * CurrentRow.PaymentPercentage / 100, 2, 1);
		CurrentRow.PayVATAmount = Round(Object.Inventory.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	EndIf;
	
EndProcedure // PaymentCalendarOnStartEdit()

// Procedure - event handler OnChange input field ListPaymentCalendarPaymentPercent.
//
&AtClient
Procedure ListPaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	PercentOfPaymentTotal = Object.PaymentCalendar.Total("PaymentPercentage");
	
	If PercentOfPaymentTotal > 100 Then
		CurrentRow.PaymentPercentage = CurrentRow.PaymentPercentage - (PercentOfPaymentTotal - 100);
	EndIf;
	
	CurrentRow.PaymentAmount = Round(Object.Inventory.Total("Total") * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PayVATAmount = Round(Object.Inventory.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure // ListPaymentCalendarPaymentPercentOnChange()

// Procedure - event handler OnChange of the ListPaymentCalendarPaymentAmount input field.
//
&AtClient
Procedure ListPaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	InventoryTotal = Object.Inventory.Total("Total");
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentAmount");
	
	If PaymentCalendarTotal > InventoryTotal Then
		CurrentRow.PaymentAmount = CurrentRow.PaymentAmount - (PaymentCalendarTotal - InventoryTotal);
	EndIf;
	
	CurrentRow.PaymentPercentage = ?(InventoryTotal = 0, 0, Round(CurrentRow.PaymentAmount / InventoryTotal * 100, 2, 1));
	CurrentRow.PayVATAmount = Round(Object.Inventory.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure // ListPaymentCalendarPaymentSumOnChange()

// Procedure - event handler OnChange of the ListPaymentCalendarPayVATAmount input field.
//
&AtClient
Procedure ListPaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = Object.Inventory.Total("VATAmount");
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PayVATAmount");
	
	If PaymentCalendarTotal > InventoryTotal Then
		CurrentRow.PayVATAmount = CurrentRow.PayVATAmount - (PaymentCalendarTotal - InventoryTotal);
	EndIf;

EndProcedure // ListPaymentCalendarPayVATAmountOnChange()

// Procedure - BeforeDeletion event handler of the PaymentCalendar tabular section.
//
&AtClient
Procedure PaymentCalendarBeforeDelete(Item, Cancel)
	
	If Object.PaymentCalendar.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure // PaymentCalendarBeforeDelete()

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
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure // Attachable_EditPropertyContent()

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalAttributeItems()
// End StandardSubsystems.Properties

#EndRegion

#Region DiscountCards

// Procedure - Command handler ReadDiscountCard forms.
//
&AtClient
Procedure ReadDiscountCardClick(Item)
	
	ParametersStructure = New Structure("Counterparty", Object.Counterparty);
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
EndProcedure

// Final part of procedure - of command handler ReadDiscountCard forms.
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

	DiscountCardOwner = GetDiscountCardOwner(DiscountCard);
	If Object.Counterparty.IsEmpty() AND Not DiscountCardOwner.IsEmpty() Then
		Object.Counterparty = DiscountCardOwner;
		CounterpartyOnChange(Items.Counterparty);
		
		ShowUserNotification(
			NStr("en='Counterparty is filled and discount card is read';ru='Заполнен контрагент и считана дисконтная карта'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersInString(NStr("en='The counterparty is filled out in the document and discount card %1 is read';ru='В документе заполнен контрагент и считана дисконтная карта %1'"), DiscountCard),
			PictureLib.Information32);
	ElsIf Object.Counterparty <> DiscountCardOwner AND Not DiscountCardOwner.IsEmpty() Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en='Discount card is not read. Discount card owner does not match with a counterparty in the document.';ru='Дисконтная карта не считана. Владелец дисконтной карты не совпадает с контрагентом в документе.'"),
			,
			"Counterparty",
			"Object");
		
		Return;
	Else
		ShowUserNotification(
			NStr("en='Discount card read';ru='Считана дисконтная карта'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Discount card %1 is read';ru='Считана дисконтная карта %1'"), DiscountCard),
			PictureLib.Information32);
	EndIf;
	
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
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
			Object.PriceKind,
			Object.DiscountMarkupKind,
			Object.DocumentCurrency,
			SettlementsCurrency,
			Object.ExchangeRate,
			RateNationalCurrency,
			Object.AmountIncludesVAT,
			CurrencyTransactionsAccounting,
			Object.VATTaxation,
			Object.DiscountCard,
			Object.DiscountPercentByDiscountCard);
			
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
		SmallBusinessClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
	EndIf;
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("DiscountRecalculationByDiscountCard");
	
EndProcedure

// Function returns the discount card owner.
//
&AtServerNoContext
Function GetDiscountCardOwner(DiscountCard)
	
	Return DiscountCard.CardOwner;
	
EndFunction

// Function returns True if the discount card, which is passed as the parameter, is fixed.
//
&AtServerNoContext
Function ThisDiscountCardWithFixedDiscount(DiscountCard)
	
	Return DiscountCard.Owner.DiscountKindForDiscountCards = Enums.DiscountKindsForDiscountCards.FixedDiscount;
	
EndFunction

// Procedure executes only for ACCUMULATIVE discount cards.
// Procedure calculates document discounts after document date change. Recalculation is executed if
// the discount percent by selected discount card changed. 
//
&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChange()
	
	If Object.DiscountCard.IsEmpty() OR ThisDiscountCardWithFixedDiscount(Object.DiscountCard) Then
		Return;
	EndIf;
	
	PreDiscountPercentByDiscountCard = Object.DiscountPercentByDiscountCard;
	NewDiscountPercentByDiscountCard = SmallBusinessServer.CalculateDiscountPercentByDiscountCard(Object.Date, Object.DiscountCard);
	
	If PreDiscountPercentByDiscountCard <> NewDiscountPercentByDiscountCard Then
		
		If Object.Inventory.Count() > 0 Then
			Text = NStr("en = 'Change the percent of discount of the progressive discount card with "+PreDiscountPercentByDiscountCard+"% on "+NewDiscountPercentByDiscountCard+"% and refill discounts in all rows?'");
			
			AdditionalParameters = New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, True);
			Notification = New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
		Else
			Text = NStr("en = 'Change the percent of discount of the progressive discount card with "+PreDiscountPercentByDiscountCard+"% on "+NewDiscountPercentByDiscountCard+"%?'");
			
			AdditionalParameters = New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, False);
			Notification = New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
		EndIf;
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

// Procedure executes only for ACCUMULATIVE discount cards.
// Procedure calculates document discounts after document date change. Recalculation is executed if
// the discount percent by selected discount card changed. 
//
&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChangeEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		Object.DiscountPercentByDiscountCard = AdditionalParameters.NewDiscountPercentByDiscountCard;
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
				Object.PriceKind,
				Object.DiscountMarkupKind,
				Object.DocumentCurrency,
				SettlementsCurrency,
				Object.ExchangeRate,
				RateNationalCurrency,
				Object.AmountIncludesVAT,
				CurrencyTransactionsAccounting,
				Object.VATTaxation,
				Object.DiscountCard,
				Object.DiscountPercentByDiscountCard);
				
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		If AdditionalParameters.RecalculateTP Then
			SmallBusinessClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
			
			// Payment calendar.
			RecalculatePaymentCalendar();
		EndIf;
				
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

&AtServer
Procedure CalculateDiscountsMarkupsByBaseDocumentServer()

	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "Inventory");
	
	OrdersArray = New Array;
	OrdersArray.Add(Object.BasisDocument);
	
	Query = New Query;
	If TypeOf(Object.BasisDocument) = Type("DocumentRef.AcceptanceCertificate") Then
		Query.Text =
		"SELECT
		|	DiscountsMarkups.Ref AS Order,
		|	DiscountsMarkups.DiscountMarkup AS DiscountMarkup,
		|	DiscountsMarkups.Amount AS AutomaticDiscountAmount,
		|	CASE
		|		WHEN AcceptanceCertificateWorksAndServices.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS ProductsAndServicesTypeInventory,
		|	CASE
		|		WHEN VALUETYPE(AcceptanceCertificateWorksAndServices.MeasurementUnit) = Type(Catalog.UOMClassifier)
		|			THEN 1
		|		ELSE AcceptanceCertificateWorksAndServices.MeasurementUnit.Factor
		|	END AS Factor,
		|	AcceptanceCertificateWorksAndServices.ProductsAndServices,
		|	AcceptanceCertificateWorksAndServices.Characteristic,
		|	AcceptanceCertificateWorksAndServices.MeasurementUnit,
		|	AcceptanceCertificateWorksAndServices.Quantity
		|FROM
		|	Document.AcceptanceCertificate.DiscountsMarkups AS DiscountsMarkups
		|		INNER JOIN Document.AcceptanceCertificate.WorksAndServices AS AcceptanceCertificateWorksAndServices
		|		ON DiscountsMarkups.Ref = AcceptanceCertificateWorksAndServices.Ref
		|			AND DiscountsMarkups.ConnectionKey = AcceptanceCertificateWorksAndServices.ConnectionKey
		|WHERE
		|	DiscountsMarkups.Ref IN(&OrdersArray)";
		
		Query.SetParameter("OrdersArray", OrdersArray);
	Else
		Query.Text =
		"SELECT
		|	DiscountsMarkups.Ref AS Order,
		|	DiscountsMarkups.DiscountMarkup AS DiscountMarkup,
		|	DiscountsMarkups.Amount AS AutomaticDiscountAmount,
		|	CASE
		|		WHEN CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS ProductsAndServicesTypeInventory,
		|	CASE
		|		WHEN VALUETYPE(CustomerOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
		|			THEN 1
		|		ELSE CustomerOrderInventory.MeasurementUnit.Factor
		|	END AS Factor,
		|	CustomerOrderInventory.ProductsAndServices,
		|	CustomerOrderInventory.Characteristic,
		|	CustomerOrderInventory.MeasurementUnit,
		|	CustomerOrderInventory.Quantity
		|FROM
		|	Document.CustomerOrder.DiscountsMarkups AS DiscountsMarkups
		|		INNER JOIN Document.CustomerOrder.Inventory AS CustomerOrderInventory
		|		ON DiscountsMarkups.Ref = CustomerOrderInventory.Ref
		|			AND DiscountsMarkups.ConnectionKey = CustomerOrderInventory.ConnectionKey
		|WHERE
		|	DiscountsMarkups.Ref IN(&OrdersArray)";
		
		Query.SetParameter("OrdersArray", OrdersArray);
		
		Query.Text = StrReplace(Query.Text, "Document.CustomerOrder.", "Document."+Object.BasisDocument.Metadata().Name+".");
	EndIf;
	
	ResultsArray = Query.ExecuteBatch();
	
	OrderDiscountsMarkups = ResultsArray[0].Unload();
	
	Object.DiscountsMarkups.Clear();
	For Each CurrentDocumentRow IN Object.Inventory Do
		CurrentDocumentRow.AutomaticDiscountsPercent = 0;
		CurrentDocumentRow.AutomaticDiscountAmount = 0;
	EndDo;
	
	DiscountsMarkupsCalculationResult = Object.DiscountsMarkups.Unload();
	
	For Each CurrentOrderRow IN OrderDiscountsMarkups Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("ProductsAndServices", CurrentOrderRow.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", CurrentOrderRow.Characteristic);
		
		DocumentRowsArray = Object.Inventory.FindRows(StructureForSearch);
		If DocumentRowsArray.Count() = 0 Then
			Continue;
		EndIf;
		
		QuantityInOrder = CurrentOrderRow.Quantity * CurrentOrderRow.Factor;
		Distributed = 0;
		For Each CurrentDocumentRow IN DocumentRowsArray Do
			QuantityToWriteOff = CurrentDocumentRow.Quantity * 
									?(TypeOf(CurrentDocumentRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), 1, CurrentDocumentRow.MeasurementUnit.Factor);
			
			RecalculateAmounts = QuantityInOrder <> QuantityToWriteOff;
			DiscountRecalculationCoefficient = ?(RecalculateAmounts, QuantityToWriteOff / QuantityInOrder, 1);
			If DiscountRecalculationCoefficient <> 1 Then
				CurrentAutomaticDiscountAmount = ROUND(CurrentOrderRow.AutomaticDiscountAmount * DiscountRecalculationCoefficient,2);
			Else
				CurrentAutomaticDiscountAmount = CurrentOrderRow.AutomaticDiscountAmount;
			EndIf;
			
			DiscountString = DiscountsMarkupsCalculationResult.Add();
			FillPropertyValues(DiscountString, CurrentOrderRow);
			DiscountString.Amount = CurrentAutomaticDiscountAmount;
			DiscountString.ConnectionKey = CurrentDocumentRow.ConnectionKey;
			
			CurrentOrderRow.AutomaticDiscountAmount = CurrentOrderRow.AutomaticDiscountAmount - CurrentAutomaticDiscountAmount;
			QuantityInOrder = QuantityInOrder - QuantityToWriteOff;
			If QuantityInOrder <=0 Or CurrentOrderRow.AutomaticDiscountAmount <=0 Then
				Break;
			EndIf;
		EndDo;
		
	EndDo;
	
	DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(Object, "Inventory", DiscountsMarkupsCalculationResult);
		
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
		
EndProcedure

// Function compares discount calculating data on current moment with data of the discount last calculation in document.
// If discounts changed the function returns the value True.
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
	
	If Object.BasisDocument <> Undefined AND Not Object.BasisDocument.IsEmpty() Then
		If TypeOf(Object.BasisDocument) = Type("DocumentRef.CustomerOrder")
			OR TypeOf(Object.BasisDocument) = Type("DocumentRef.AcceptanceCertificate")
			OR TypeOf(Object.BasisDocument) = Type("DocumentRef.CustomerInvoice")
			Then
			CalculateDiscountsMarkupsByBaseDocumentServer();
			ParameterStructure.Insert("ApplyToObject", False);
			AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
		ElsIf TypeOf(Object.BasisDocument) = Type("DocumentRef.Event") Then
			AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
		Else
			// When entering the invoice for payment based on recycling report do not fill in data about automatic discounts.
		EndIf;
	Else
		AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	EndIf;
	
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
	EndDo;

EndProcedure

// Procedure - command handler "OpenInformationAboutDiscounts".
//
&AtClient
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient()
	
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

// End modeless window opening "ShowQuestion()". Procedure opens a common form for information analysis about discounts by current row.
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

// Procedure - event handler Table parts selection Inventory.
//
&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	// AutomaticDiscounts
	If Item.CurrentItem = Items.InventoryAutomaticDiscountPercent
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient()
		
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

// Procedure - event handler OnStartEdit tabular section Inventory forms.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	// AutomaticDiscounts
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
	EndIf;
	// End AutomaticDiscounts
	
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

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure BasisDocumentOnChange(Item)
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("BasisDocumentOnChange");
	// End AutomaticDiscounts
	
EndProcedure

#EndRegion
