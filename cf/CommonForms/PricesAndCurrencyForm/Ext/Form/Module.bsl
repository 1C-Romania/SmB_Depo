
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Procedure fills the form parameters.
//
Procedure GetFormValuesOfParameters()
	
	// Price kind.
	If Parameters.Property("PriceKind") Then
		
		// Price kind.
		PriceKind = Parameters.PriceKind;
		PriceKindOnOpen = Parameters.PriceKind;
		PriceKindIsAttribute = True;
		
	Else
		
		// Enabled of the price kind.
		Items.PriceKind.Visible = False;
		PriceKindIsAttribute = False;
		
		Items.DiscountKind.Visible = False;
		DiscountKindIsAttribute = False;
		
	EndIf;
	
	If Parameters.Property("DocumentCurrencyEnabled") Then
		
		Items.Currency.Enabled = Parameters.DocumentCurrencyEnabled;
		Items.RecalculatePrices.Visible = Parameters.DocumentCurrencyEnabled;
		
	EndIf;
	
	// Counterparty price kind.
	If Parameters.Property("CounterpartyPriceKind") Then
		
		// Price kind.
		CounterpartyPriceKind = Parameters.CounterpartyPriceKind;
		PriceKindCounterpartyOnOpen = Parameters.CounterpartyPriceKind;
		Counterparty = Parameters.Counterparty;
		PriceKindCounterpartyIsAttribute = True;
		
		ValueArray = New Array;
		ValueArray.Add(Counterparty);
		ValueArray = New FixedArray(ValueArray);
		NewParameter = New ChoiceParameter("Filter.Owner", ValueArray);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.CounterpartyPriceKind.ChoiceParameters = NewParameters;
		
	Else
		
		// Enabled of the counterparty price kind.
		Items.CounterpartyPriceKind.Visible = False;
		PriceKindCounterpartyIsAttribute = False;
		
	EndIf;
	
	// RegisterVendorPrices.
	If Parameters.Property("RegisterVendorPrices") Then
		
		RegisterVendorPrices = Parameters.RegisterVendorPrices;
		RegisterVendorPricesOnOpen = Parameters.RegisterVendorPrices;
		RegisterVendorPricesIsAttribute = True;
		
	Else
		
		// Enabled.
		Items.RegisterVendorPrices.Visible = False;
		RegisterVendorPricesIsAttribute = False;
		
	EndIf;
	
	// Flag - refill prices.
	If Not (PriceKindIsAttribute OR PriceKindCounterpartyIsAttribute) Then
		
		Items.RefillPrices.Visible = False;
		
	EndIf; 
	
	// Discounts.
	If Parameters.Property("DiscountKind") Then
		
		DiscountKind = Parameters.DiscountKind;
		DiscountKindOnOpen = Parameters.DiscountKind;
		DiscountKindIsAttribute = True;
		
	Else
		
		Items.DiscountKind.Visible = False;
		DiscountKindIsAttribute = False;
		
	EndIf;
	
	// Discount cards.
	If Parameters.Property("DiscountCard") Then
		
		DiscountCard = Parameters.DiscountCard;
		DiscountCardOnOpen = Parameters.DiscountCard;
		DiscountCardHasAttribute = True;
		If Parameters.Property("Counterparty") Then
			Counterparty = Parameters.Counterparty;
		EndIf;
		Items.DiscountCard.Visible = True;
		DiscountCardHasAttribute = True;
		
	Else
		
		Items.DiscountCard.Visible = False;
		DiscountCardHasAttribute = False;
		
	EndIf;
	
	// Document currency.
	If Parameters.Property("DocumentCurrency") Then
		
		DocumentCurrency = Parameters.DocumentCurrency;
		DocumentCurrencyOnOpen = Parameters.DocumentCurrency;
		DocumentCurrencyIsAttribute = True;
		
	Else
		
		Items.DocumentCurrency.Visible = False;
		Items.ExchangeRate.Visible = False;
		Items.Multiplicity.Visible = False;
		Items.RecalculatePrices.Visible = False;
		DocumentCurrencyIsAttribute = False;
		
	EndIf;
	
	// VAT taxation.
	If Parameters.Property("VATTaxation") Then
		
		VATTaxation = Parameters.VATTaxation;
		VATTaxationOnOpen = Parameters.VATTaxation;
		VATTaxationIsAttribute = True;
		
	Else
		
		Items.VATTaxation.Visible = False;
		VATTaxationIsAttribute = False;
		
	EndIf;
	
	// Amount includes VAT.
	If Parameters.Property("AmountIncludesVAT") Then
		
		AmountIncludesVAT = Parameters.AmountIncludesVAT;
		AmountIncludesVATOnOpen = Parameters.AmountIncludesVAT;
		AmountIncludesVATIsAttribute = True;
		
	Else
		
		Items.AmountIncludesVAT.Visible = False;
		AmountIncludesVATIsAttribute = False;
		
	EndIf;	
	
	// Include VAT in price.
	If Parameters.Property("IncludeVATInPrice") Then
		
		IncludeVATInPrice = Parameters.IncludeVATInPrice;
		IncludeVATInPriceOnOpen = Parameters.IncludeVATInPrice;
		IncludeVATInPriceIsAttribute = True;
		
	Else
		
		Items.IncludeVATInPrice.Visible = False;
		IncludeVATInPriceIsAttribute = False;
		
	EndIf;
		
	// Accounts currency.
	If Parameters.Property("Contract") Then
		
		SettlementsCurrency	  = Parameters.Contract.SettlementsCurrency;
		CalculationsInCur		  = Parameters.Contract.SettlementsInStandardUnits;
		PaymentsRate 	  = Parameters.ExchangeRate;
		SettlementsMultiplicity = Parameters.Multiplicity;
		
		SettlementsCurrencyRateOnOpen 	 = Parameters.ExchangeRate;
		SettlementsMultiplicityOnOpen = Parameters.Multiplicity;
		
		ContractIsAttribute = True;
		
		If Parameters.Property("ThisIsInvoice") Then
			
			Items.SettlementsCurrency.Visible = False;
			Items.PaymentsRate.Visible = False;
			Items.SettlementsMultiplicity.Visible = False;
			
		EndIf;
		
	Else
		
		Items.SettlementsCurrency.Visible = False;
		Items.PaymentsRate.Visible = False;
		Items.SettlementsMultiplicity.Visible = False;
		
		ContractIsAttribute = False;
		
	EndIf;
	
	RefillPrices = Parameters.RefillPrices;
	RecalculatePrices   = Parameters.RecalculatePrices;
		
	If ValueIsFilled(DocumentCurrency) Then
		ArrayCourseRepetition = CurrencyRates.FindRows(New Structure("Currency", DocumentCurrency));
		If DocumentCurrency = SettlementsCurrency
		   AND PaymentsRate <> 0
		   AND SettlementsMultiplicity <> 0 Then
			ExchangeRate = PaymentsRate;
			Multiplicity = SettlementsMultiplicity;
		Else
			If ValueIsFilled(ArrayCourseRepetition) Then
				ExchangeRate = ArrayCourseRepetition[0].ExchangeRate;
				Multiplicity = ArrayCourseRepetition[0].Multiplicity;
			Else
				ExchangeRate = 0;
				Multiplicity = 0;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure // GetFormParametersValues()

&AtServer
// Procedure fills the exchange rates table
//
Procedure FillCurrencyRatesTable()
	
	Query = New Query;
	Query.SetParameter("DocumentDate", Parameters.DocumentDate);
	Query.Text = 
	"SELECT
	|	CurrencyRatesSliceLast.Currency,
	|	CurrencyRatesSliceLast.ExchangeRate,
	|	CurrencyRatesSliceLast.Multiplicity
	|FROM
	|	InformationRegister.CurrencyRates.SliceLast(&DocumentDate, ) AS CurrencyRatesSliceLast";
	
	QueryResultTable = Query.Execute().Unload();
	CurrencyRates.Load(QueryResultTable);
	
EndProcedure // FillCurrencyRatesTable()

&AtClient
// Procedure checks the correctness of the form attributes filling.
//
Procedure CheckFillOfFormAttributes(Cancel, OnlyPriceKindIsNotFilled = False)
    	
	// Attributes filling check.
	
	// DiscountCards
	OnlyPriceKindIsNotFilled = True;
	// End DiscountCards
	
	// Kind of counterparty prices.
	If (RefillPrices OR RegisterVendorPrices) AND PriceKindCounterpartyIsAttribute Then
		If Not ValueIsFilled(CounterpartyPriceKind) Then
			Message = New UserMessage();
			Message.Text = NStr("en=""Company's  fill in price type has not been selected!"";ru='Не выбран вид цен контрагента для заполнения!'");
			Message.Field = "CounterpartyPriceKind";
			Message.Message();
  			Cancel = True;
			OnlyPriceKindIsNotFilled = False; // DiscountCards
    	EndIf;
	EndIf;
	
	// Document currency.
	If DocumentCurrencyIsAttribute Then
		If Not ValueIsFilled(DocumentCurrency) Then
            Message = New UserMessage();
			Message.Text = NStr("en='Field Currency is required!';ru='Не заполнена валюта документа!'");
			Message.Field = "DocumentCurrency";
			Message.Message();
			Cancel = True;
			OnlyPriceKindIsNotFilled = False; // DiscountCards
   		EndIf;
	EndIf;
	
	// VAT taxation.
	If VATTaxationIsAttribute Then
		If Not ValueIsFilled(VATTaxation) Then
            Message = New UserMessage();
			Message.Text = NStr("en='Field Taxation is required!';ru='Не заполнено налогообложение!'");
			Message.Field = "VATTaxation";
			Message.Message();
			Cancel = True;
			OnlyPriceKindIsNotFilled = False; // DiscountCards
   		EndIf;
	EndIf;
	
	// Calculations.
	If ContractIsAttribute Then
		If Not ValueIsFilled(PaymentsRate) Then
			Message = New UserMessage();
			Message.Text = NStr("en='Settlements currency exchange rate is equal to zero!';ru='Обнаружен нулевой курс валюты расчетов!'");
			Message.Field = "PaymentsRate";
			Message.Message();
			Cancel = True;
			OnlyPriceKindIsNotFilled = False; // DiscountCards
		EndIf;
		If Not ValueIsFilled(SettlementsMultiplicity) Then
			Message = New UserMessage();
			Message.Text = NStr("en='Settlements currency exchange rate multiplicity is equal to zero! ';ru='Обнаружена нулевая кратность курса валюты документа!'");
			Message.Field = "SettlementsMultiplicity";
			Message.Message();
			Cancel = True;
			OnlyPriceKindIsNotFilled = False; // DiscountCards
		EndIf;
	EndIf;
	
	// Prices kind.
	If RefillPrices AND PriceKindIsAttribute Then
		If Not ValueIsFilled(PriceKind) Then
			If DiscountKind.IsEmpty() AND Not DiscountCard.IsEmpty() AND OnlyPriceKindIsNotFilled Then // DiscountCards
				// You can recalculate the discounts on the discount card in the document.
			Else
				Message = New UserMessage();
				Message.Text = NStr("en='Fill in Price type has not been selected!';ru='Не выбран вид цены для заполнения!'");
				Message.Field = "PriceKind";
				Message.Message();
				OnlyPriceKindIsNotFilled = False;
			EndIf;
			Cancel = True;
    	EndIf;
	EndIf;
	
EndProcedure // CheckFillFormAttributes()

&AtClient
// Procedure checks if the form was modified.
//
Procedure CheckIfFormWasModified()

	WereMadeChanges = False;
	
	ChangesPriceKind 				= ?(PriceKindIsAttribute, PriceKindOnOpen <> PriceKind, False);
	ChangesCounterpartyPriceKind 		= ?(PriceKindCounterpartyIsAttribute, PriceKindCounterpartyOnOpen <> CounterpartyPriceKind, False);
	ChangesToRegisterVendorPrices = ?(RegisterVendorPricesIsAttribute, RegisterVendorPricesOnOpen <> RegisterVendorPrices, False);
	ChangesDiscountKind 				= ?(DiscountKindIsAttribute, DiscountKindOnOpen <> DiscountKind, False);
	ChangesDocumentCurrency 		= ?(DocumentCurrencyIsAttribute, DocumentCurrencyOnOpen <> DocumentCurrency, False);
	ChangesVATTaxation 	= ?(VATTaxationIsAttribute, VATTaxationOnOpen <> VATTaxation, False);
	ChangesAmountIncludesVAT 		= ?(AmountIncludesVATIsAttribute, AmountIncludesVATOnOpen <> AmountIncludesVAT, False);
	ChangesIncludeVATInPrice 	= ?(IncludeVATInPriceIsAttribute, IncludeVATInPriceOnOpen <> IncludeVATInPrice, False);
    ChangesPaymentsRate 			= ?(ContractIsAttribute, SettlementsCurrencyRateOnOpen <> PaymentsRate, False);
    ChangesSettlementsRates 		= ?(ContractIsAttribute, SettlementsMultiplicityOnOpen <> SettlementsMultiplicity, False);
    ChangesDiscountCard		= ?(DiscountCardHasAttribute, DiscountCardOnOpen <> DiscountCard, False); // DiscountCards
	
	If RefillPrices
	 OR RecalculatePrices
	 OR ChangesDocumentCurrency
	 OR ChangesVATTaxation
     OR ChangesAmountIncludesVAT
	 OR ChangesIncludeVATInPrice
	 OR ChangesPaymentsRate
	 OR ChangesSettlementsRates
	 OR ChangesPriceKind
	 OR ChangesCounterpartyPriceKind
	 OR ChangesToRegisterVendorPrices
	 OR ChangesDiscountCard // DiscountCards
	 OR ChangesDiscountKind Then	

		WereMadeChanges = True;

	EndIf;
	
EndProcedure // CheckIfFormWasModified()

&AtClient
// Procedure for filling the exchange rate and document currency multiplicity.
//
Procedure FillRateRepetitionOfDocumentCurrency()
	
	If ValueIsFilled(DocumentCurrency) Then
		ArrayCourseRepetition = CurrencyRates.FindRows(New Structure("Currency", DocumentCurrency));
		If DocumentCurrency = SettlementsCurrency
		   AND PaymentsRate <> 0
		   AND SettlementsMultiplicity <> 0 Then
			ExchangeRate = PaymentsRate;
			Multiplicity = SettlementsMultiplicity;
		Else
			If ValueIsFilled(ArrayCourseRepetition) Then
				ExchangeRate = ArrayCourseRepetition[0].ExchangeRate;
				Multiplicity = ArrayCourseRepetition[0].Multiplicity;
			Else
				ExchangeRate = 0;
				Multiplicity = 0;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure // FillRateRepetitionOfDocumentCurrency()

#Region DiscountCards

// Function returns the discount card holder.
//
&AtServerNoContext
Function GetCardHolder(DiscountCard)

	Return DiscountCard.CardOwner;

EndFunction // GetCardHolder()

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initializing the form parameters.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AccountingCurrency = Constants.NationalCurrency.Get();
	FillCurrencyRatesTable();
	GetFormValuesOfParameters();
	
	If ContractIsAttribute Then	
		NewArray = New Array();
		If CalculationsInCur
		   AND AccountingCurrency <> SettlementsCurrency Then
			NewArray.Add(AccountingCurrency);
		EndIf;
		NewArray.Add(SettlementsCurrency);
		NewParameter = New ChoiceParameter("Filter.Ref", New FixedArray(NewArray));
		NewArray2 = New Array();
		NewArray2.Add(NewParameter);
		NewParameters = New FixedArray(NewArray2);
		Items.Currency.ChoiceParameters = NewParameters;
	EndIf;
	
	Parameters.Property("WarningText", WarningText);
	If IsBlankString(WarningText) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "WarningGroup", "Visible", False);
		
	EndIf;
	Items.Warning.Title = WarningText;
	
	// DiscountCards
	Parameters.Property("DocumentDate", DocumentDate);
	ConfigureLabelOnDiscountCard();
	
EndProcedure // OnCreateAtServer()


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// Procedure - event handler of clicking the OK button.
//
Procedure CommandOK(Command)
	
	Cancel = False;
	OnlyPriceKindIsNotFilledAndCardIsFilled = False; // DiscountCards

	CheckFillOfFormAttributes(Cancel, OnlyPriceKindIsNotFilledAndCardIsFilled);
	CheckIfFormWasModified();
    
	If Not Cancel OR OnlyPriceKindIsNotFilledAndCardIsFilled Then

		StructureOfFormAttributes = New Structure;

        StructureOfFormAttributes.Insert("WereMadeChanges", 			WereMadeChanges);

        StructureOfFormAttributes.Insert("PriceKind", 						PriceKind);
		StructureOfFormAttributes.Insert("CounterpartyPriceKind", 				CounterpartyPriceKind);
		StructureOfFormAttributes.Insert("RegisterVendorPrices", 	RegisterVendorPrices);
		StructureOfFormAttributes.Insert("DiscountKind",  					DiscountKind);

		StructureOfFormAttributes.Insert("DocumentCurrency", 				DocumentCurrency);
		StructureOfFormAttributes.Insert("VATTaxation",				VATTaxation);
		StructureOfFormAttributes.Insert("AmountIncludesVAT", 				AmountIncludesVAT);
		StructureOfFormAttributes.Insert("IncludeVATInPrice", 			IncludeVATInPrice);

		StructureOfFormAttributes.Insert("SettlementsCurrency", 				SettlementsCurrency);
		StructureOfFormAttributes.Insert("ExchangeRate", 							ExchangeRate);
		StructureOfFormAttributes.Insert("PaymentsRate", 					PaymentsRate);
		StructureOfFormAttributes.Insert("Multiplicity", 						Multiplicity);
        StructureOfFormAttributes.Insert("SettlementsMultiplicity", 				SettlementsMultiplicity);
                         
		StructureOfFormAttributes.Insert("PrevCurrencyOfDocument", 			DocumentCurrencyOnOpen);
		StructureOfFormAttributes.Insert("PrevVATTaxation", 		VATTaxationOnOpen);
		StructureOfFormAttributes.Insert("PrevAmountIncludesVAT", 			AmountIncludesVATOnOpen);

        StructureOfFormAttributes.Insert("RefillPrices", 				RefillPrices AND Not Cancel);
        StructureOfFormAttributes.Insert("RecalculatePrices", 				RecalculatePrices);

		StructureOfFormAttributes.Insert("FormName", 						"CommonForm.CurrencyForm");

		// DiscountCards
		StructureOfFormAttributes.Insert("RefillDiscounts",			RefillPrices AND OnlyPriceKindIsNotFilledAndCardIsFilled);
		StructureOfFormAttributes.Insert("DiscountCard",  				DiscountCard);
		StructureOfFormAttributes.Insert("DiscountPercentByDiscountCard",	DiscountPercentByDiscountCard);
		StructureOfFormAttributes.Insert("Counterparty",						GetCardHolder(DiscountCard));
		// End DiscountCards
		
		Close(StructureOfFormAttributes);

	EndIf;
	
EndProcedure // CommandOK()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - event handler OnChange of the PriceKind input field.
//
Procedure PriceKindOnChange(Item)
	
	If ValueIsFilled(PriceKind) Then
                        
        If PriceKindOnOpen <> PriceKind Then
			
			RefillPrices = True;

		EndIf;
        
	EndIf;
	
EndProcedure // PriceKindOnChange()

&AtClient
// Procedure - event handler OnChange of the CounterpartyPriceKind input field.
//
Procedure CounterpartyPriceKindOnChange(Item)
	
	If ValueIsFilled(CounterpartyPriceKind) Then
                        
        If PriceKindCounterpartyOnOpen <> CounterpartyPriceKind Then
			
			RefillPrices = True;

		EndIf;
        
	EndIf;
	
EndProcedure // PriceKindOnChange()

&AtClient
// Procedure - event handler OnChange of the DiscountKind input field.
//
Procedure DiscountKindOnChange(Item)
	
	If DiscountKindOnOpen <> DiscountKind Then
		RefillPrices = True;
	EndIf;
	
EndProcedure // DiscountKindOnChange()

&AtClient
// Procedure - event handler OnChange of the Currency input field.
//
Procedure CurrencyOnChange(Item)
	
	FillRateRepetitionOfDocumentCurrency();

	If ValueIsFilled(DocumentCurrency)
		
	   AND DocumentCurrencyOnOpen <> DocumentCurrency Then
  		RecalculatePrices = True;
		
  	EndIf;

EndProcedure // CurrencyOnChange()

&AtClient
// Procedure - event handler OnChange of the SettlementsCurrency input field.
//
Procedure SettlementsCurrencyOnChange(Item)
	
	FillRateRepetitionOfDocumentCurrency();

EndProcedure // SettlementsCurrencyOnChange()

&AtClient
// Procedure - event  handler OnChange of the PaymentsRate input field.
//
Procedure SettlementsRateOnChange(Item)
	
	FillRateRepetitionOfDocumentCurrency();

EndProcedure // SettlementsRateOnChange()

&AtClient
// Procedure - event handler OnChange of the SettlementsMultiplicity input field.
//
Procedure SettlementsMultiplicityOnChange(Item)
	
	FillRateRepetitionOfDocumentCurrency();

EndProcedure // SettlementsMultiplicityOnChange()

&AtClient
// Procedure - event handler OnChange of the RefillPrices input field.
//
Procedure RefillPricesOnChange(Item)
	
	If PriceKindIsAttribute Then
		
		If RefillPrices Then
			If DiscountKind.IsEmpty() AND Not DiscountCard.IsEmpty() Then // DiscountCards
				Items.PriceKind.AutoMarkIncomplete = False;
			Else
				Items.PriceKind.AutoMarkIncomplete = True;
			EndIf;
		Else	
			Items.PriceKind.AutoMarkIncomplete = False;
			ClearMarkIncomplete();
		EndIf;		
	
	ElsIf PriceKindCounterpartyIsAttribute Then
		
		If RefillPrices OR RegisterVendorPrices Then
			Items.CounterpartyPriceKind.AutoMarkIncomplete = True;
		Else	
			Items.CounterpartyPriceKind.AutoMarkIncomplete = False;
			ClearMarkIncomplete();
		EndIf;		
	
	EndIf;
	
EndProcedure // RefillPricesOnChange()

&AtClient
// Procedure - event handler OnChange of the RegisterVendorPrices input field.
//
Procedure RegisterVendorPricesOnChange(Item)
	
	If RegisterVendorPrices OR RefillPrices Then
		Items.CounterpartyPriceKind.AutoMarkIncomplete = True;
	Else	
		Items.CounterpartyPriceKind.AutoMarkIncomplete = False;
		ClearMarkIncomplete();
	EndIf;
	
EndProcedure // RefillPricesOnChange()

#Region DiscountCards

// Procedure - event handler of the StartChoice item of the DiscountCard form.
//
&AtClient
Procedure DiscountCardStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	NotifyDescription = New NotifyDescription("OpenDiscountCardSelectionFormEnd", ThisObject); //, New Structure("Filter", FilterStructure));
	OpenForm("Catalog.DiscountCards.ChoiceForm", New Structure("Counterparty", Counterparty), ThisForm.DiscountCard, ThisForm.UUID, , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure is called after selection of the discount card from the form catalog selection DiscountCards.
//
&AtClient
Procedure OpenDiscountCardSelectionFormEnd(ClosingResult, AdditionalParameters) Export

	If ValueIsFilled(ClosingResult) Then 
		DiscountCard = ClosingResult;
	
		If DiscountCardOnOpen <> DiscountCard Then
			
			RefillPrices = True;
			
		EndIf;
	EndIf;

	// The % of the progressive discount could have been changed, so refresh the label, even if the discount card is not changed.
	ConfigureLabelOnDiscountCard();
	
EndProcedure

// Procedure - event handler of the OnChange item of the DiscountCard form.
//
&AtClient
Procedure DiscountCardOnChange(Item)
	
	If DiscountCardOnOpen <> DiscountCard Then
		
		RefillPrices = True;
		
	EndIf;
	
	// The % of the progressive discount could have been changed, so refresh the label, even if the discount card is not changed.
	ConfigureLabelOnDiscountCard();
	
	RefillPricesOnChange(Items.RefillPrices);
	
EndProcedure

// Procedure fills the discount card tooltip with the information about the discount on the discount card.
//
&AtServer
Procedure ConfigureLabelOnDiscountCard()
	
	If Not DiscountCard.IsEmpty() Then
		If Not Counterparty.IsEmpty() AND DiscountCard.Owner.ThisIsMembershipCard AND DiscountCard.CardOwner <> Counterparty Then
			
			DiscountCard = Catalogs.DiscountCards.EmptyRef();
			
			Message = New UserMessage;
			Message.Text = "Discount card owner does not match with a counterparty in the document.";
			Message.Field = "DiscountCard";
			Message.Message();
			
		EndIf;
	EndIf;
	
	If DiscountCard.IsEmpty() Then
		DiscountPercentByDiscountCard = 0;
		Items.DiscountCard.ToolTip = "";
	Else
		DiscountPercentByDiscountCard = SmallBusinessServer.CalculateDiscountPercentByDiscountCard(DocumentDate, DiscountCard);		
		Items.DiscountCard.ToolTip = "Discount by the card is "+DiscountPercentByDiscountCard+"%";
	EndIf;
	
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
