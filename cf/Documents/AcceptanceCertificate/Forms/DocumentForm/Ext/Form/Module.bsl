////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Procedure calls the data processor for document filling by basis.
//
Procedure FillByDocumentBase()
	
	Document = FormAttributeToValue("Object");
	Document.Filling(Object.BasisDocument, );
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then	
		Items.WorksAndServicesVATRate.Visible = True;
		Items.WorksAndServicesSumVAT.Visible = True;
		Items.WorksAndServicesTotal.Visible = True;    			
	Else		
		Items.WorksAndServicesVATRate.Visible = False;
		Items.WorksAndServicesSumVAT.Visible = False;
		Items.WorksAndServicesTotal.Visible = False;
	EndIf;
	
	SetContractVisible();
	
EndProcedure // FillByDocumentBase()

&AtServer
// Procedure calls the data processor for document filling by basis.
//
Procedure FillByDocumentCustomerOrder()
	
	Document = FormAttributeToValue("Object");
	Document.Filling(Object.CustomerOrder, );
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then	
		Items.WorksAndServicesVATRate.Visible = True;
		Items.WorksAndServicesSumVAT.Visible = True;
		Items.WorksAndServicesTotal.Visible = True;
	Else
		Items.WorksAndServicesVATRate.Visible = False;
		Items.WorksAndServicesSumVAT.Visible = False;
		Items.WorksAndServicesTotal.Visible = False;
	EndIf;
	
	SetContractVisible();
	
EndProcedure // FillByDocumentCustomerOrder()

&AtServer
// It receives data set from server for the DateOnChange procedure.
//
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

&AtServer
// Gets data set from server.
//
Function GetCompanyDataOnChange()
	
	StructureData = New Structure;
	
	StructureData.Insert("Company", SmallBusinessServer.GetCompany(Object.Company));
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

&AtServerNoContext
// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
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

&AtServerNoContext
// It receives data set from server for the CharacteristicOnChange procedure.
//
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

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure;
	
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

&AtServer
// It receives data set from the server for the CounterpartyOnChange procedure.
//
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	StructureData = New Structure();
	
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
	
	StructureData.Insert(
		"DoOperationsByOrders",
		Counterparty.DoOperationsByOrders
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(ContractByDefault.PriceKind), ContractByDefault.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction // GetDataCounterpartyOnChange()

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"SettlementsCurrency",
		Contract.SettlementsCurrency
	);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency))
	);
	
	StructureData.Insert(
		"PriceKind",
		Contract.PriceKind
	);
	
	StructureData.Insert(
		"DiscountMarkupKind",
		Contract.DiscountMarkupKind
	);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		Contract.SettlementsInStandardUnits
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	Return StructureData;
	
EndFunction // GetDataContractOnChange()

&AtServer
// Procedure fills the VAT rate in the tabular section
// according to company's taxation system.
// 
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company,, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure // FillVATRateByVATTaxation()

&AtServer
// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		Items.WorksAndServicesVATRate.Visible = True;
		Items.WorksAndServicesSumVAT.Visible = True;
		Items.WorksAndServicesTotal.Visible = True;
		
		For Each TabularSectionRow IN Object.WorksAndServices Do
			
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
		
		Items.WorksAndServicesVATRate.Visible = False;
		Items.WorksAndServicesSumVAT.Visible = False;
		Items.WorksAndServicesTotal.Visible = False;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then	
		    DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
		Else
			DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
		EndIf;	
		
		For Each TabularSectionRow IN Object.WorksAndServices Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;	
		
	EndIf;	
	
EndProcedure // FillVATRateByVATTaxation()	

&AtClient
// VAT amount is calculated in the row of tabular section.
//
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure // CalculateVATAmount()

&AtClient
// Procedure calculates the amount in the row of tabular section.
//
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined, ResetFlagDiscountsAreCalculated = True)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.WorksAndServices.CurrentData;
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
	If ResetFlagDiscountsAreCalculated Then
		ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	EndIf;
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts

EndProcedure // CalculateAmountInTabularSectionLine()

&AtClient
// Procedure recalculates the exchange rate and multiplicity of
// the settlement currency when the date of a document is changed.
//
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	NewExchangeRate = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
	NewRatio = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		CurrencyRateInLetters = String(Object.Multiplicity) + " " + TrimAll(SettlementsCurrency) + " = " + String(Object.ExchangeRate) + " " + TrimAll(NationalCurrency);
		RateNewCurrenciesInLetters = String(NewRatio) + " " + TrimAll(SettlementsCurrency) + " = " + String(NewExchangeRate) + " " + TrimAll(NationalCurrency);
		
		QuestionParameters = New Structure;
		QuestionParameters.Insert("NewExchangeRate", NewExchangeRate);
		QuestionParameters.Insert("NewRatio", NewRatio);
		
		NotifyDescription = New NotifyDescription("QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd", ThisObject, QuestionParameters);
		
		QuestionText = NStr("ru = 'На дату документа у валюты расчетов (" + CurrencyRateInLetters + ") был задан курс.
									|Установить курс расчетов (" + RateNewCurrenciesInLetters + ") в соответствии с курсом валюты?'; en = 'As of the date of document the settlement currency (" + CurrencyRateInLetters + ") exchange rate was specified.
									|Set the settlements rate (" + RateNewCurrenciesInLetters + ") according to exchange rate?'");
		
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure // RecalculateRateAccountCurrencyRepetition()	

// Performs the actions after a response to the question on recalculation of rate and conversion factor of payment currency.
//
&AtClient
Procedure QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		
		For Each TabularSectionRow IN Object.Prepayment Do
			TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = NationalCurrency, RateNationalCurrency, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = NationalCurrency, RepetitionNationalCurrency, Object.Multiplicity));
		EndDo;
		
		// Generate price and currency label.
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;

EndProcedure

&AtClient
// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",		  Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",				  Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",			  Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation",	  Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",	  Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice", Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty",			  Object.Counterparty);
	ParametersStructure.Insert("Contract",				  Object.Contract);
	ParametersStructure.Insert("Company",			  Company);
	ParametersStructure.Insert("DocumentDate",		  Object.Date);
	ParametersStructure.Insert("RefillPrices",	  RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",		  RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",  False);
	ParametersStructure.Insert("PriceKind",				  Object.PriceKind);
	ParametersStructure.Insert("DiscountKind",			  Object.DiscountMarkupKind);
	ParametersStructure.Insert("DiscountCard", Object.DiscountCard);
	ParametersStructure.Insert("WarningText",   WarningText);
	
	//Open form "Prices and Currency".
	//Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrencyForm", ParametersStructure, ThisForm,,,, NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure // ProcessChangesByButtonPricesAndCurrencies()

&AtClient
// Procedure-handler of the result of opening the "Prices and currencies" form
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	StructurePricesAndCurrency = ClosingResult;
	SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
	
	If TypeOf(StructurePricesAndCurrency) = Type("Structure")
	   AND StructurePricesAndCurrency.WereMadeChanges Then
		
		Object.PriceKind = StructurePricesAndCurrency.PriceKind;
		Object.DiscountMarkupKind = StructurePricesAndCurrency.DiscountKind;
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
		Object.DocumentCurrency = StructurePricesAndCurrency.DocumentCurrency;
		Object.ExchangeRate = StructurePricesAndCurrency.PaymentsRate;
		Object.Multiplicity = StructurePricesAndCurrency.SettlementsMultiplicity;
		Object.VATTaxation = StructurePricesAndCurrency.VATTaxation;
		Object.AmountIncludesVAT = StructurePricesAndCurrency.AmountIncludesVAT;
		Object.IncludeVATInPrice = StructurePricesAndCurrency.IncludeVATInPrice;
		
		// Recalculate prices by kind of prices.
		If StructurePricesAndCurrency.RefillPrices Then
			SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "WorksAndServices", True);
		EndIf;
		
		// Recalculate prices by currency.
		If Not StructurePricesAndCurrency.RefillPrices
			  AND StructurePricesAndCurrency.RecalculatePrices Then
			SmallBusinessClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "WorksAndServices");
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If StructurePricesAndCurrency.VATTaxation <> StructurePricesAndCurrency.PrevVATTaxation Then
			FillVATRateByVATTaxation();		
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not StructurePricesAndCurrency.RefillPrices
			AND Not StructurePricesAndCurrency.AmountIncludesVAT = StructurePricesAndCurrency.PrevAmountIncludesVAT Then
			SmallBusinessClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "WorksAndServices");
		EndIf;
		
		For Each TabularSectionRow IN Object.Prepayment Do
			TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = NationalCurrency, RateNationalCurrency, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = NationalCurrency, RepetitionNationalCurrency, Object.Multiplicity));  
		EndDo;
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;

	EndIf;
	
	// Generate price and currency label.
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate,  RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure // OpenPricesAndCurrencyFormEnd()

&AtClientAtServerNoContext
// Function returns the label text "Prices and currency".
//
Function GenerateLabelPricesAndCurrency(LabelStructure)
	
	LabelText = "";
	
	// Currency.
	If LabelStructure.CurrencyTransactionsAccounting Then
		If ValueIsFilled(LabelStructure.DocumentCurrency) Then
			LabelText = NStr("ru = '%Currency%'; en = '%Currency%'");
			LabelText = StrReplace(LabelText, "%Currency%", TrimAll(String(LabelStructure.DocumentCurrency)));
		EndIf;
	EndIf;	
	
	// Prices kind.
	If ValueIsFilled(LabelStructure.PriceKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("ru = '%PriceKind%'; en = '%PriceKind%'");
		Else	
			LabelText = LabelText + NStr("ru = ' • %PriceKind%'; en = ' • %PriceKind%'");
		EndIf;	
		LabelText = StrReplace(LabelText, "%PriceKind%", TrimAll(String(LabelStructure.PriceKind)));
	EndIf;
	
	// Margins discount kind.
	If ValueIsFilled(LabelStructure.DiscountKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("ru = '%DiscountMarkupKind%'; en = '%DiscountMarkupKind%'");
		Else
			LabelText = LabelText + NStr("ru = ' • %DiscountMarkupKind%'; en = ' • %MarkupDiscountKind%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%DiscountMarkupKind%", TrimAll(String(LabelStructure.DiscountKind)));
	EndIf;
	
	// Discount card.
	If ValueIsFilled(LabelStructure.DiscountCard) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("ru = '%DiscountCard%'; en = '%DiscountCard%'");
		Else
			LabelText = LabelText + NStr("ru = ' • %DiscountCard%'; en = ' • %DiscountCard%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%DiscountCard%", String(LabelStructure.DiscountPercentByDiscountCard)+"% by map"); //ShortLP(String(LabelStructure.DiscountCard)));
	EndIf;	
	
	// VAT taxation.
	If ValueIsFilled(LabelStructure.VATTaxation) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("ru = '%VATTaxation%'; en = '%VATTaxation%'");
		Else
			LabelText = LabelText + NStr("ru = ' • %VATTaxation%'; en = ' • %VATTaxation%'");
		EndIf;	
		LabelText = StrReplace(LabelText, "%VATTaxation%", TrimAll(String(LabelStructure.VATTaxation)));
	EndIf;
	
	// Flag showing that amount includes VAT.
	If IsBlankString(LabelText) Then	
		If LabelStructure.AmountIncludesVAT Then	
			LabelText = NStr("ru = 'Сумма включает НДС'; en = 'Amount includes VAT'");
		Else		
			LabelText = NStr("ru = 'Сумма не включает НДС'; en = 'Amount does not include VAT'");
		EndIf;	
	EndIf;	
	
	Return LabelText;
	
EndFunction // GenerateLabelPricesAndCurrency()	

// Procedure sets the form item visible.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleFromUserSettings()
	
	If Object.CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader Then
		Items.CustomerOrder.Visible = True;
		Items.WorksAndServicesCustomerOrder.Visible = False;
		Items.FillByOrder.Visible = True;
		OrderInHeader = True;
	Else
		Items.CustomerOrder.Visible = False;
		Items.WorksAndServicesCustomerOrder.Visible = True;
		Items.FillByOrder.Visible = False;
		OrderInHeader = False;
	EndIf;	
	
EndProcedure // SetVisibleFromUserSettings()

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	CounterpartyDoSettlementsByOrders = Object.Counterparty.DoOperationsByOrders;
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
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractKinds", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
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
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
		
		If Object.Prepayment.Count() > 0
			AND Object.Contract <> ContractBeforeChange Then
			
			DocumentParameters = New Structure;
			DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
			DocumentParameters.Insert("ContractData", ContractData);
			
			NotifyDescription = New NotifyDescription("PrepaymentClearingQuestionEnd", ThisObject, DocumentParameters);
			QuestionText = NStr("en='Prepayment set-off will be cleared, do you want to continue?';ru='Зачет предоплаты будет очищен, продолжить?'");
			
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
			Return;
		EndIf;
		
		HandleContractConditionsChange(ContractData, ContractBeforeChange);
		
	Else
		
		Object.CustomerOrder = Order;
	
	EndIf;
	
	Order = Object.CustomerOrder;
	
EndProcedure // ProcessContractChange()

// Performs the actions after a response to the question about prepayment clearing.
//
&AtClient
Procedure PrepaymentClearingQuestionEnd(Result, AdditionalParameters) Export
	
	ContractBeforeChange = AdditionalParameters.ContractBeforeChange;
	
	If Result = DialogReturnCode.Yes Then
		Object.Prepayment.Clear();
	Else
		If AdditionalParameters.Property("CounterpartyChange") Then
			Object.Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			CounterpartyDoSettlementsByOrders = AdditionalParameters.CounterpartyDoSettlementsByOrdersBeforeChange;
			Items.Contract.Visible = AdditionalParameters.ContractVisibleBeforeChange;
		EndIf;
		Object.Contract = ContractBeforeChange;
		Contract = ContractBeforeChange;
		Object.CustomerOrder = Order;
		Return;
	EndIf;
	
	HandleContractConditionsChange(AdditionalParameters.ContractData, ContractBeforeChange);

EndProcedure

// The procedure handles the change of attributes of Price kind and Settlement currency documents.
//
&AtClient
Procedure HandleContractConditionsChange(ContractData, ContractBeforeChange)
	
	SettlementsCurrencyBeforeChange = SettlementsCurrency;
	SettlementsCurrency = ContractData.SettlementsCurrency;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	If ValueIsFilled(Object.Contract) Then 
		
		Object.ExchangeRate      = ?(ContractData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Multiplicity);
		
	EndIf;
	
	PriceKindChanged = Object.PriceKind <> ContractData.PriceKind AND ValueIsFilled(ContractData.PriceKind);
	DiscountKindChanged = Object.DiscountMarkupKind <> ContractData.DiscountMarkupKind AND ValueIsFilled(ContractData.DiscountMarkupKind);
	If ContractData.Property("CallFromProcedureAtCounterpartyChange") Then
		ClearDiscountCard = ValueIsFilled(Object.DiscountCard);
	Else
		ClearDiscountCard = False;
	EndIf;			
	
	If ClearDiscountCard Then		
		Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
		Object.DiscountPercentByDiscountCard = 0;		
	EndIf;
	
	QueryPriceKind = ValueIsFilled(Object.Contract) AND (PriceKindChanged OR DiscountKindChanged);
	
	If QueryPriceKind Then
		
		If PriceKindChanged Then
			
			Object.PriceKind = ContractData.PriceKind;
			
		EndIf; 
		
		If DiscountKindChanged Then
			
			Object.DiscountMarkupKind = ContractData.DiscountMarkupKind;
			
		EndIf; 
		
	EndIf;
	
	NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
		AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> ContractData.SettlementsCurrency;
	OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
		AND Object.WorksAndServices.Count() > 0;
	
	DocumentParameters = New Structure;
	DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
	DocumentParameters.Insert("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange);
	DocumentParameters.Insert("ContractData", ContractData);
	
	Object.DocumentCurrency = SettlementsCurrency;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If QueryPriceKind Then
			
			WarningText = NStr("en='The price and discount conditions in the contract with counterparty differ from price and discount in the document! 
		|Perhaps you have to refill prices.';ru='Договор с контрагентом предусматривает условия цен и скидок, отличные от установленных в документе! 
		|Возможно, необходимо перезаполнить цены.'") + Chars.LF + Chars.LF;
			
		EndIf;
		
		WarningText = WarningText + NStr("en='Settlement currency of the contract with counterparty changed! 
		|It is necessary to check the document currency!';ru='Изменилась валюта расчетов по договору с контрагентом! 
		|Необходимо проверить валюту документа!'");
		
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, PriceKindChanged, WarningText);
		
	ElsIf QueryPriceKind Then
		
		RecalculationRequired = (Object.WorksAndServices.Count() > 0);
		
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
			
			QuestionText = NStr("en='The price and discount conditions in the contract with counterparty differ from price and discount in the document! 
		|Recalculate the document according to the contract?';ru='Договор с контрагентом предусматривает условия цен и скидок, отличные от установленных в документе! 
		|Пересчитать документ в соответствии с договором?'");
			
			NotifyDescription = New NotifyDescription("RecalculationQuestionByPriceKindEnd", ThisObject, DocumentParameters);
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
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
	
	// Clear order.
	For Each CurRow IN Object.WorksAndServices Do
		CurRow.CustomerOrder = Undefined;
	EndDo;
	
EndProcedure // HandleContractConditionsChange()

&AtClient
// Procedure-handler of a response to the question on recalculation of the document by the kind of prices and discounts.
//
Procedure RecalculationQuestionByPriceKindEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "WorksAndServices", True);
		
	EndIf;
	
EndProcedure // DefineDocumentRecalculateNeedByContractTerms()

////////////////////////////////////////////////////////////////////////////////
// Subsystem 'ElectronicDocuments'

&AtServer
Procedure SetEDStateTextAtServer()
	
	EDStateText = ElectronicDocumentsClientServer.GetTextOfEDState(Object.Ref, ThisForm);
	
EndProcedure

// Event handler of clicking the EDState attribute
//
&AtClient
Procedure EDStateClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Uniqueness",	Object.Ref.UUID());
	OpenParameters.Insert("Source",		ThisForm);
	OpenParameters.Insert("Window", 			ThisForm.Window);
	
	ElectronicDocumentsClient.OpenEDTree(Object.Ref, OpenParameters);
	
EndProcedure // EDStateClick()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR WORK WITH THE SELECTION

&AtClient
// Procedure - event handler Action of the Pick command
//
Procedure Pick(Command)
	
	TabularSectionName  = "WorksAndServices";
	
	If Not IsBlankString(SelectionOpenParameters[TabularSectionName]) Then
		
		PickProductsAndServicesInDocumentsClient.OpenPick(ThisForm, TabularSectionName, SelectionOpenParameters[TabularSectionName]);
		Return;
		
	EndIf;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period",					Object.Date);
	SelectionParameters.Insert("Company",			Company);
	SelectionParameters.Insert("PriceKind",					Object.PriceKind);
	SelectionParameters.Insert("DiscountMarkupKind",		Object.DiscountMarkupKind);
	SelectionParameters.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	SelectionParameters.Insert("Currency",					Object.DocumentCurrency);
	SelectionParameters.Insert("VATTaxation",		Object.VATTaxation);
	SelectionParameters.Insert("AmountIncludesVAT",		Object.AmountIncludesVAT);
	SelectionParameters.Insert("DocumentOrganization",	Object.Company);
	SelectionParameters.Insert("BatchesUsed",		False);
	SelectionParameters.Insert("AvailablePriceChanging",	Not Items.WorksAndServicesPrice.ReadOnly);
	
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
	
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	
	OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm);
	
EndProcedure // ExecutePick()

&AtServer
// Function gets a product list from the temporary storage
//
Procedure GetWorksAndServicesFromStorages(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
			
	EndDo;
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;

EndProcedure // GetWorksAndServicesFromStorages()

&AtServer
// Function places the list of advances into temporary storage and returns the address
//
Function PlacePrepaymentToStorage()
	
	Return PutToTempStorage(
		Object.Prepayment.Unload(,
			"Document,
			|Order,
			|SettlementsAmount,
			|ExchangeRate,
			|Multiplicity,
			|PaymentAmount"),
		UUID
	);
	
EndFunction // PlacePrepaymentToStorage()

&AtServer
// Function gets the list of advances from the temporary storage
//
Procedure GetPrepaymentFromStorage(AddressPrepaymentInStorage)
	
	TableForImport = GetFromTempStorage(AddressPrepaymentInStorage);
	Object.Prepayment.Load(TableForImport);
	
EndProcedure // GetPrepaymentFromStorage()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	If Not ValueIsFilled(Object.Ref) AND ValueIsFilled(Object.Counterparty) AND Not ValueIsFilled(Parameters.CopyingValue) Then
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = Object.Counterparty.ContractByDefault;
		EndIf;
		If ValueIsFilled(Object.Contract) Then
			Object.DocumentCurrency = Object.Contract.SettlementsCurrency;
			SettlementsCurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.Contract.SettlementsCurrency));
			Object.ExchangeRate      = ?(SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity = ?(SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, SettlementsCurrencyRateRepetition.Multiplicity);
			Object.DiscountMarkupKind = Object.Contract.DiscountMarkupKind;
			Object.PriceKind = Object.Contract.PriceKind;
		EndIf;
	EndIf;
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Company = SmallBusinessServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	Order = Object.CustomerOrder;
	SettlementsCurrency = Object.Contract.SettlementsCurrency;
	NationalCurrency = Constants.NationalCurrency.Get();
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", NationalCurrency));
	RateNationalCurrency = StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		Items.WorksAndServicesVATRate.Visible = True;
		Items.WorksAndServicesSumVAT.Visible = True;
		Items.WorksAndServicesTotal.Visible = True;
	Else
		Items.WorksAndServicesVATRate.Visible = False;
		Items.WorksAndServicesSumVAT.Visible = False;
		Items.WorksAndServicesTotal.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	CurrencyTransactionsAccounting = Constants.FunctionalCurrencyTransactionsAccounting.Get();
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Attribute visible set from user settings
	SetVisibleFromUserSettings();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.WorksAndServicesPrice.ReadOnly 				  = Not AllowedEditDocumentPrices;
	Items.WorksAndServicesDiscountMarkupPercent.ReadOnly = Not AllowedEditDocumentPrices;
	Items.WorksAndServicesSum.ReadOnly 				  = Not AllowedEditDocumentPrices;
	Items.WorksAndServicesSumVAT.ReadOnly 			  = Not AllowedEditDocumentPrices;
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// Subsystem 'ElectronicDocuments'
	SetEDStateTextAtServer();
	
	// PickProductsAndServicesInDocuments
	PickProductsAndServicesInDocuments.AssignPickForm(SelectionOpenParameters, Object.Ref.Metadata().Name, "WorksAndServices");
	// End PickProductsAndServicesInDocuments
	
	// Setting contract visible.
	SetContractVisible();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
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
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			CalculatedDiscounts = True;
			
			Message = New UserMessage;
			Message.Text = NStr("ru = 'Рассчитаны автоматические скидки (наценки)!'; en = 'Automatic discounts (markups) are calculated!'");
			Message.SetData(ThisObject);
			Message.Message();
			
			DiscountsCalculatedBeforeWrite = True;
		Else
			Object.DiscountsAreCalculated = True;
			RefreshImageAutoDiscountsAfterWrite = True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

// Procedure - handler of the AfterWriteAtServer event.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.WorksAndServicesCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
	// Subsystem 'ElectronicDocuments'
	SetEDStateTextAtServer();
	
EndProcedure

&AtClient
// Procedure - event handler AfterWriting.
//
Procedure AfterWrite(WriteParameters)
	
	OrderIsFilled = False;
	For Each TSRow IN Object.WorksAndServices Do
		If ValueIsFilled(TSRow.CustomerOrder) Then
			OrderIsFilled = True;
			Break;
		EndIf;		
	EndDo;	
	
	If OrderIsFilled Then
		Notify("Write_AcceptanceCertificate", Object.Ref);
	EndIf;
	
	Notify("NotificationAboutChangingDebt");
	
	// AutomaticDiscounts
	If DiscountsCalculatedBeforeWrite Then
		DiscountsAreCalculatedDateTime = CurrentDate(); // It is better to leave the string last to minimize the time difference between AfterRecording handler and BeforeClosing handler calling .
	EndIf;

EndProcedure // AfterWrite()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		
		UpdateAdditionalAttributesItems();
		
	EndIf;
	
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
		
		GetWorksAndServicesFromStorages(InventoryAddressInStorage, "WorksAndServices", True, False);
		
	ElsIf EventName = "RefreshStateED" Then // Subsystem 'ElectronicDocuments'
		
		SetEDStateTextAtServer();
		
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
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
		
		If SmallBusinessReUse.GetAdvanceOffsettingSettingValue() = Enums.YesNo.Yes
			AND CurrentObject.Prepayment.Count() = 0 Then
			FillPrepayment(CurrentObject);
		EndIf;
		
	EndIf;
	
	// Mechanism handler "Properties".
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	
EndProcedure // BeforeWriteAtServer()

&AtServer
// Procedure-handler of the FillCheckProcessingAtServer event.
//
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure // FillCheckProcessingAtServer()

// Procedure fills advances.
//
&AtServer
Procedure FillPrepayment(CurrentObject)
	
	CurrentObject.FillPrepayment();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// Procedure is called by clicking the PricesCurrency
// button of the command bar tabular field.
//
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure // EditPricesAndCurrency()

&AtClient
// You can call the procedure by clicking
// the button "FillByBasis" of the tabular field command panel.
//
Procedure FillByBasis(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en='Document will be completely refilled by ""Basis""! Continue?';ru='Документ будет полностью перезаполнен по ""Основанию""! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        
        FillByDocumentBase();
        LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
        PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
        
    EndIf;

EndProcedure // FillByBasis()

&AtClient
// You can call the procedure by clicking
// the button "FillByOrder" of the tabular field command panel.
//
Procedure FillByOrder(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillEndByOrder", ThisObject), NStr("en='The document will be completely refilled according to ""Customer order""! Continue?';ru='Документ будет полностью перезаполнен по ""Заказу покупателя""! Продолжить выполнение операции?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillEndByOrder(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocumentCustomerOrder();
        LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
        PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
    EndIf;

EndProcedure // FillByOrder()

&AtClient
// Procedure - command handler of the tabular section command panel.
//
Procedure EditPrepaymentOffset(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en='Specify the counterparty first.';ru='Укажите вначале контрагента!'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en='Specify the counterparty contract first.';ru='Укажите вначале договор контрагента!'"));
		Return;
	EndIf;
	
	OrdersArray = New Array;
	For Each CurItem IN Object.WorksAndServices Do
		OrderStructure = New Structure("Order, Total");
		OrderStructure.Order = CurItem.CustomerOrder;
		OrderStructure.Total = CurItem.Total;
		OrdersArray.Add(OrderStructure);
	EndDo;
	
	AddressPrepaymentInStorage = PlacePrepaymentToStorage();
	SelectionParameters = New Structure(
		"AddressPrepaymentInStorage,
		|Pick,
		|IsOrder,
		|OrderInHeader,
		|Company,
		|Order,
		|Date,
		|Ref,
		|Counterparty,
		|Contract,
		|ExchangeRate,
		|Multiplicity,
		|DocumentCurrency,
		|DocumentAmount",
		AddressPrepaymentInStorage, // AddressPrepaymentInStorage
		True, // Pick
		True, // IsOrder
		OrderInHeader, // OrderInHeader
		Company, // Company
		?(CounterpartyDoSettlementsByOrders, ?(OrderInHeader, Object.CustomerOrder, OrdersArray), Undefined), // Order
		Object.Date, // Date
		Object.Ref, // Ref
		Object.Counterparty, // Counterparty
		Object.Contract, // Contract
		Object.ExchangeRate, // ExchangeRate
		Object.Multiplicity, // Multiplicity
		Object.DocumentCurrency, // DocumentCurrency
		Object.WorksAndServices.Total("Total") // DocumentAmount
	);
	
	ReturnCode = Undefined;
	
	OpenForm("CommonForm.CustomerAdvancesPickForm", SelectionParameters,,,,, New NotifyDescription("EditPrepaymentOffsetEnd", ThisObject, New Structure("AddressPrepaymentInStorage", AddressPrepaymentInStorage)));
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetEnd(Result, AdditionalParameters) Export
    
    AddressPrepaymentInStorage = AdditionalParameters.AddressPrepaymentInStorage;
    
    
    ReturnCode = Result;
    If ReturnCode = DialogReturnCode.OK Then
        GetPrepaymentFromStorage(AddressPrepaymentInStorage);
    EndIf;

EndProcedure // EditPrepaymentOffset()

// Procedure - command handler DocumentSetting.
//
&AtClient
Procedure DocumentSetting(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("CustomerOrderPositionInShipmentDocuments", 	Object.CustomerOrderPosition);
	ParametersStructure.Insert("WereMadeChanges", 						False);
	
	StructureDocumentSetting = Undefined;

	
	OpenForm("CommonForm.DocumentSetting", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
    
    // 2. Open the form "Prices and Currency".
    StructureDocumentSetting = Result;
    
    // 3. Apply changes made in "Document setting" form.
    If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
        
        Object.CustomerOrderPosition = StructureDocumentSetting.CustomerOrderPositionInShipmentDocuments;
        SetVisibleFromUserSettings();
        
    EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
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
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		// DiscountCards
		// IN this procedure call not modal window of question is occurred.
		RecalculateDiscountPercentAtDocumentDateChange();
		// End DiscountCards		
	EndIf;
	
	// AutomaticDiscounts
	DocumentDateChangedManually = True;
	ClearCheckboxDiscountsAreCalculatedClient("DateOnChange");
	
EndProcedure // DateOnChange()

&AtClient
// Procedure - event handler OnChange of the Company input field.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange();
	Company = StructureData.Company;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure // CompanyOnChange()

&AtClient
// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	CounterpartyDoSettlementsByOrdersBeforeChange = CounterpartyDoSettlementsByOrders;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ContractVisibleBeforeChange = Items.Contract.Visible;
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		
		Object.Contract = StructureData.Contract;
		ContractBeforeChange = Contract;
		Contract = Object.Contract;
		
		If Object.Prepayment.Count() > 0
			AND Object.Contract <> ContractBeforeChange Then
			
			DocumentParameters = New Structure;
			DocumentParameters.Insert("CounterpartyChange", True);
			DocumentParameters.Insert("ContractData", StructureData);
			DocumentParameters.Insert("CounterpartyBeforeChange", CounterpartyBeforeChange);
			DocumentParameters.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", CounterpartyDoSettlementsByOrdersBeforeChange);
			DocumentParameters.Insert("ContractVisibleBeforeChange", ContractVisibleBeforeChange);
			DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
			
			NotifyDescription = New NotifyDescription("PrepaymentClearingQuestionEnd", ThisObject, DocumentParameters);
			QuestionText = NStr("en='Prepayment set-off will be cleared, do you want to continue?';ru='Зачет предоплаты будет очищен, продолжить?'");
			
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
			Return;
		EndIf;
		
		HandleContractConditionsChange(StructureData, ContractBeforeChange);
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		Object.CustomerOrder = Order;
		
	EndIf;
	
	Order = Object.CustomerOrder;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("CounterpartyOnChange");
	
EndProcedure // CounterpartyOnChange()

&AtClient
// Procedure - event handler OnChange of the Contract input field.
// Fills form attributes - exchange rate and multiplicity.
//
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure // ContractOnChange()

// Procedure - event handler StartChoice of the Contract input field.
//
&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of the CustomerOrder input field.
//
&AtClient
Procedure CustomerOrderOnChange(Item)
	
	If Object.Prepayment.Count() > 0
	   AND Object.CustomerOrder <> Order
	   AND CounterpartyDoSettlementsByOrders Then
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("CustomerOrderOnChangeEnd", ThisObject), NStr("en='Prepayment set-off will be cleared, do you want to continue?';ru='Зачет предоплаты будет очищен, продолжить?'"), Mode, 0);
        Return;
	EndIf;
	
	CustomerOrderOnChangeFragment();
EndProcedure

&AtClient
Procedure CustomerOrderOnChangeEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Object.Prepayment.Clear();
    Else
        Object.CustomerOrder = Order;
        Return;
    EndIf;
    
    CustomerOrderOnChangeFragment();

EndProcedure

&AtClient
Procedure CustomerOrderOnChangeFragment()
    
    Order = Object.CustomerOrder;
	
	// AutomaticDiscounts
	If ClearCheckboxDiscountsAreCalculatedClient("CustomerOrderOnChangeFragment") Then
		CalculateAmountInTabularSectionLine(Undefined, False);
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure // CustomerOrderOnChange()

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE INVENTORY TABULAR SECTION ATTRIBUTES

&AtClient
// Procedure - event handler OnChange of the ProductsAndServices input field.
//
Procedure WorksAndServicesProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.WorksAndServices.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 Object.Date);
		StructureData.Insert("DocumentCurrency",	 Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind",			 Object.PriceKind);
		StructureData.Insert("Factor",		 1);
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
	TabularSectionRow.Content = "";
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // WorksAndServicesProductsAndServicesOnChange()

&AtClient
// Procedure - event handler OnChange of the Characteristic input field.
//
Procedure WorksAndServicesCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.WorksAndServices.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices",	 TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", 		Object.Date);
		StructureData.Insert("DocumentCurrency",	 	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
				
		StructureData.Insert("Price",			 	TabularSectionRow.Price);
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		
		StructureData.Insert("PriceKind",				Object.PriceKind);
		StructureData.Insert("MeasurementUnit", 	TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.Content = "";
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // WorksAndServicesCharacteristicOnChange()

&AtClient
// Procedure - event handler AutoPick of the Content input field.
//
Procedure WorksAndServicesContentAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow = Items.WorksAndServices.CurrentData;
		ContentPattern = SmallBusinessServer.GetContentText(TabularSectionRow.ProductsAndServices, TabularSectionRow.Characteristic);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Count input field.
//
Procedure WorksAndServicesQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // WorksAndServicesQuantityOnChange()

&AtClient
// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
Procedure WorksAndServicesMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.WorksAndServices.CurrentData;
	
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
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // WorksAndServicesMeasurementUnitChoiceProcessing()

&AtClient
// Procedure - event handler OnChange of the Price input field.
//
Procedure WorksAndServicesPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // WorksAndServicesPriceOnChange()

&AtClient
// Procedure - event handler OnChange of the DiscountMarkupPercent input field.
//
Procedure JobsAndServicesDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // WorksAndServicesDiscountMarkupPercentOnChange()

&AtClient
// Procedure - event handler OnChange of the Amount input field.
//
Procedure WorksAndServicesAmountOnChange(Item)
	
	TabularSectionRow = Items.WorksAndServices.CurrentData;
	
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
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure // WorksAndServicesAmountOnChange()

&AtClient
// Procedure - event handler OnChange of the VATRate input field.
//
Procedure WorksAndServicesVATRateOnChange(Item)
	
	TabularSectionRow = Items.WorksAndServices.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure // WorksAndServicesVATRateOnChange()

&AtClient
// Procedure - event handler OnChange of the VATRate input field.
//
Procedure WorksAndServicesAmountVATOnChange(Item)
	
	TabularSectionRow = Items.WorksAndServices.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure // WorksAndServicesAmountVATOnChange()

&AtClient
Procedure PrepaymentDocumentOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.Document) Then
		
		StructureData = GetDataDocumentOnChange(TabularSectionRow.Document);
		
		TabularSectionRow.SettlementsAmount = StructureData.SettlementsAmount;
		
		TabularSectionRow.ExchangeRate = 
			?(TabularSectionRow.ExchangeRate = 0,
				?(Object.ExchangeRate = 0,
				1,
				Object.ExchangeRate),
			TabularSectionRow.ExchangeRate
		);
		
		TabularSectionRow.Multiplicity =
			?(TabularSectionRow.Multiplicity = 0,
				?(Object.Multiplicity = 0,
				1,
				Object.Multiplicity),
			TabularSectionRow.Multiplicity
		);
			
		TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.SettlementsAmount,
			TabularSectionRow.ExchangeRate,
			?(Object.DocumentCurrency = NationalCurrency, RateNationalCurrency, Object.ExchangeRate),
			TabularSectionRow.Multiplicity,
			?(Object.DocumentCurrency = NationalCurrency,RepetitionNationalCurrency, Object.Multiplicity)
		);
		
	EndIf;
	
EndProcedure

// Receives data set from server for procedure PrepaymentDocumentOnChange.
//
&AtServerNoContext
Function GetDataDocumentOnChange(Document)
	
	StructureData = New Structure();
	
	StructureData.Insert("SettlementsAmount", Document.PaymentDetails.Total("SettlementsAmount"));
	
	Return StructureData;
	
EndFunction // GetDataDocumentOntChange()

&AtClient
Procedure PrepaymentAccountsAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
		
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
			?(Object.ExchangeRate = 0,
			1,
			Object.ExchangeRate),
		TabularSectionRow.ExchangeRate
	);
	
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
			?(Object.Multiplicity = 0,
			1,
			Object.Multiplicity),
		TabularSectionRow.Multiplicity
	);
	
	TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		?(Object.DocumentCurrency = NationalCurrency, RateNationalCurrency, Object.ExchangeRate),
		TabularSectionRow.Multiplicity,
		?(Object.DocumentCurrency = NationalCurrency,RepetitionNationalCurrency, Object.Multiplicity)
	);

EndProcedure

&AtClient
Procedure PrepaymentRateOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
		1,
		TabularSectionRow.Multiplicity
	);
	
	TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		?(Object.DocumentCurrency = NationalCurrency, RateNationalCurrency, Object.ExchangeRate),
		TabularSectionRow.Multiplicity,
		?(Object.DocumentCurrency = NationalCurrency,RepetitionNationalCurrency, Object.Multiplicity)
	);
	
EndProcedure

&AtClient
Procedure PrepaymentMultiplicityOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
		1,
		TabularSectionRow.Multiplicity
	);
	
	TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		?(Object.DocumentCurrency = NationalCurrency, RateNationalCurrency, Object.ExchangeRate),
		TabularSectionRow.Multiplicity,
		?(Object.DocumentCurrency = NationalCurrency,RepetitionNationalCurrency, Object.Multiplicity)
	);
	
EndProcedure

&AtClient
Procedure PrepaymentPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	
	TabularSectionRow.Multiplicity = 1;
	
	TabularSectionRow.ExchangeRate =
		?(TabularSectionRow.SettlementsAmount = 0,
			1,
			TabularSectionRow.PaymentAmount
		  / TabularSectionRow.SettlementsAmount
		  * Object.ExchangeRate
	);
	
EndProcedure

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
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()

	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));

EndProcedure
// End StandardSubsystems.Properties

#EndRegion

#Region DiscountCards

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

&AtClient
Procedure DiscountCardIsSelectedAdditionally(DiscountCard)
	
	If Not Modified Then
		Modified = True;
	EndIf;
	
	Object.DiscountCard = DiscountCard;
	Object.DiscountPercentByDiscountCard = SmallBusinessServer.CalculateDiscountPercentByDiscountCard(Object.Date, DiscountCard);
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
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
	
	If Object.WorksAndServices.Count() > 0 Then
		Text = NStr("en='Refill discounts in all rows?';ru='Перезаполнить скидки во всех строках?'");
		Notification = New NotifyDescription("DiscountCardIsSelectedAdditionallyEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

&AtClient
Procedure DiscountCardIsSelectedAdditionallyEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		SmallBusinessClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "WorksAndServices");
	EndIf;
	
		// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("DiscountRecalculationByDiscountCard");
	
EndProcedure

&AtServerNoContext
Function GetDiscountCardOwner(DiscountCard)
	
	Return DiscountCard.CardOwner;
	
EndFunction

&AtClient
Procedure ReadDiscountCardClick(Item)
	
	ParametersStructure = New Structure("Counterparty", Object.Counterparty);
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
EndProcedure

&AtClient
Procedure ReadDiscountCardClickEnd(ReturnParameters, Parameters) Export

	If TypeOf(ReturnParameters) = Type("Structure") Then
		DiscountCardRead = ReturnParameters.DiscountCardRead;
		DiscountCardIsSelected(ReturnParameters.DiscountCard);
	EndIf;

EndProcedure

&AtServerNoContext
Function ThisDiscountCardWithFixedDiscount(DiscountCard)
	
	Return DiscountCard.Owner.DiscountKindForDiscountCards = Enums.DiscountKindsForDiscountCards.FixedDiscount;
	
EndFunction

&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChange()
	
	If Object.DiscountCard.IsEmpty() OR ThisDiscountCardWithFixedDiscount(Object.DiscountCard) Then
		Return;
	EndIf;
	
	PreDiscountPercentByDiscountCard = Object.DiscountPercentByDiscountCard;
	NewDiscountPercentByDiscountCard = SmallBusinessServer.CalculateDiscountPercentByDiscountCard(Object.Date, Object.DiscountCard);
	
	If PreDiscountPercentByDiscountCard <> NewDiscountPercentByDiscountCard Then
		
		If Object.WorksAndServices.Count() > 0 Then
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

&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChangeEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		Object.DiscountPercentByDiscountCard = AdditionalParameters.NewDiscountPercentByDiscountCard;
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
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
			SmallBusinessClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "WorksAndServices");
		EndIf;
				
	EndIf;
	
EndProcedure
#EndRegion

#Region AutomaticDiscounts

&AtClient
Procedure CalculateDiscountsMarkups(Command)
	
	If Object.WorksAndServices.Count() = 0 Then
		If Object.DiscountsMarkups.Count() > 0 Then
			Object.DiscountsMarkups.Clear();
		EndIf;
		Return;
	EndIf;
	
	CalculateDiscountsMarkupsClient();
	
EndProcedure

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
		
		If Object.WorksAndServices.Total("AutomaticDiscountAmount") <> Object.DiscountsMarkups.Total("Amount") Then
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

&AtServer
Procedure CalculateMarkupsDiscountsForOrderServer()

	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "WorksAndServices");
	
	OrdersArray = New Array;
	CustomerOrderPosition = SmallBusinessReUse.GetValueOfSetting("CustomerOrderPositionInShipmentDocuments");
	If CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader Then
		OrdersArray.Add(Object.CustomerOrder);
	Else
		OrdersGO = Object.WorksAndServices.Unload(, "CustomerOrder");
		OrdersGO.GroupBy("CustomerOrder");
		OrdersArray = OrdersGO.UnloadColumn("CustomerOrder");
	EndIf;
	
	Query = New Query;
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
	
	ResultsArray = Query.ExecuteBatch();
	
	OrderDiscountsMarkups = ResultsArray[0].Unload();
	
	Object.DiscountsMarkups.Clear();
	For Each CurrentDocumentRow IN Object.WorksAndServices Do
		CurrentDocumentRow.AutomaticDiscountsPercent = 0;
		CurrentDocumentRow.AutomaticDiscountAmount = 0;
	EndDo;
	
	DiscountsMarkupsCalculationResult = Object.DiscountsMarkups.Unload();
	
	For Each CurrentOrderRow IN OrderDiscountsMarkups Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("CustomerOrder", CurrentOrderRow.Order);
		StructureForSearch.Insert("ProductsAndServices", CurrentOrderRow.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", CurrentOrderRow.Characteristic);
		
		DocumentRowsArray = Object.WorksAndServices.FindRows(StructureForSearch);
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
	
	DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(Object, "WorksAndServices", DiscountsMarkupsCalculationResult);
		
EndProcedure

&AtServer
Function GetAutomaticDiscountCalculationParametersStructureServer()

	OrderParametersStructure = New Structure("SalesByOrders, SalesExceedingOrder", False, False);
	
	CustomerOrderPosition = Object.CustomerOrderPosition;
	If Not ValueIsFilled(CustomerOrderPosition) Then
		CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader;
	EndIf;
	If CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader Then
		If ValueIsFilled(Object.CustomerOrder) Then
			OrderParametersStructure.SalesByOrders = True;
		Else
			OrderParametersStructure.SalesByOrders = False;
		EndIf;
		OrderParametersStructure.SalesExceedingOrder = False;
	Else
		Query = New Query;
		Query.Text = 
			"SELECT
			|	AcceptanceCertificateWorksAndServices.CustomerOrder AS Order
			|INTO TU_Inventory
			|FROM
			|	&WorksAndServices AS AcceptanceCertificateWorksAndServices
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	TU_Inventory.Order AS Order
			|FROM
			|	TU_Inventory AS TU_Inventory
			|
			|GROUP BY
			|	TU_Inventory.Order";
		
		Query.SetParameter("WorksAndServices", Object.WorksAndServices.Unload());
		QueryResult = Query.Execute();
		
		Selection = QueryResult.Select();
		
		While Selection.Next() Do
			If ValueIsFilled(Selection.Order) Then
				OrderParametersStructure.SalesByOrders = True;
			Else
				OrderParametersStructure.SalesExceedingOrder = True;
			EndIf;
		EndDo;
	EndIf;
	
	Return OrderParametersStructure;
	
EndFunction // ThereAreOrdersInTS()

// Procedure - "CalculateDiscountsMarkups" command handler.
//
&AtServer
Procedure CalculateDiscountsMarkupsOnServer(ParameterStructure)
	
	OrderParametersStructure = GetAutomaticDiscountCalculationParametersStructureServer(); // If there are orders in TS "Goods", then for such rows the automatic discount shall be calculated by the order.
	If OrderParametersStructure.SalesByOrders Then
		CalculateMarkupsDiscountsForOrderServer();
		If OrderParametersStructure.SalesExceedingOrder Then
			ParameterStructure.Insert("SalesExceedingOrder", True);
			AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
		Else
			ParameterStructure.Insert("ApplyToObject", False);
			AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
		EndIf;
	Else
		
		AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	EndIf;
	
	AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	
	Modified = True;
	
	DiscountsMarkupsServerOverridable.UpdateDiscountDisplay(Object, "WorksAndServices");
	
	If Not Object.DiscountsAreCalculated Then
	
		Object.DiscountsAreCalculated = True;
	
	EndIf;
	
	Items.WorksAndServicesCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
	
	ThereAreManualDiscounts = Constants.FunctionalOptionUseDiscountsMarkups.Get();
	For Each CurrentRow IN Object.WorksAndServices Do
		ManualDiscountCurAmount = ?(ThereAreManualDiscounts, CurrentRow.Price * CurrentRow.Quantity * CurrentRow.DiscountMarkupPercent / 100, 0);
		CurAmountDiscounts = ManualDiscountCurAmount + CurrentRow.AutomaticDiscountAmount;
		If CurAmountDiscounts >= CurrentRow.Amount AND CurrentRow.Price > 0 Then
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = True;
		Else
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.WorksAndServices.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient()
	
EndProcedure

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

&AtClient
Procedure NotificationQueryCalculateDiscounts(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	ParameterStructure = AdditionalParameters.ParameterStructure;
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	
EndProcedure

&AtClient
Procedure CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure)
	
	If Not ValueIsFilled(AddressDiscountsAppliedInTemporaryStorage) Then
		CalculateDiscountsMarkupsClient();
	EndIf;
	
	CurrentData = Items.WorksAndServices.CurrentData;
	MarkupsDiscountsClient.OpenFormAppliedDiscounts(CurrentData, Object, ThisObject);
	
EndProcedure

&AtClient
Procedure WorksAndServicesChoice(Item, SelectedRow, Field, StandardProcessing)
	
	If Item.CurrentItem = Items.WorksAndServicesAutomaticDiscountPercent
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient()
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	// AutomaticDiscounts
	// Display the message about discount calculation when user clicks the "Post and close" button or closes the form by the cross with saving the changes.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification("Update:", 
										GetURL(Object.Ref), 
										String(Object.Ref)+". Automatic discounts (markups) are calculated.", 
										PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure WorksAndServicesAfterDeleteRow(Item)
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure

&AtServer
Function ResetFlagDiscountsAreCalculatedServer(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.WorksAndServices.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

&AtClient
Function ClearCheckboxDiscountsAreCalculatedClient(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.WorksAndServices.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn, "WorksAndServices");
	
EndFunction

&AtServer
Procedure AutomaticDiscountsOnCreateAtServer()
	
	InstalledGrayColor = False;
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscountsMarkups");
	If UseAutomaticDiscounts Then
		If Object.WorksAndServices.Count() = 0 Then
			Items.WorksAndServicesCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
			InstalledGrayColor = True;
		ElsIf Not Object.DiscountsAreCalculated Then
			Object.DiscountsAreCalculated = False;
			Items.WorksAndServicesCalculateDiscountsMarkups.Picture = PictureLib.UpdateRed;
		Else
			Items.WorksAndServicesCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		EndIf;
	EndIf;
	AddressDiscountsAppliedInTemporaryStorage = "";
	
EndProcedure

&AtClient
Procedure WorksAndServicesOnStartEdit(Item, NewRow, Copy)
	
	// AutomaticDiscounts
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure WorksAndServicesCustomerOrderOnChange(Item)
	
	// AutomaticDiscounts
	If ClearCheckboxDiscountsAreCalculatedClient("WorksAndServicesCustomerOrderOnChange") Then
		CalculateAmountInTabularSectionLine(Undefined, False);
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

#EndRegion
