
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Procedure fills the form parameters.
//
Procedure GetFormValuesOfParameters()
	
	DocumentCurrency				   = Parameters.DocumentCurrency;
	DocumentCurrencyBeforeChange = Parameters.DocumentCurrency;
	ExchangeRate = Parameters.ExchangeRate;
	ExchangeRateBeforeChange = Parameters.ExchangeRate;
	Multiplicity = Parameters.Multiplicity;
	MultiplicityBeforeChange = Parameters.Multiplicity;
	
	AmountIncludesVAT 		= Parameters.AmountIncludesVAT;
	AmountIncludesVATBefore  = Parameters.AmountIncludesVAT;
	
	IncludeVATInPrice = Parameters.IncludeVATInPrice;
	VATIncludeInCostBeforeChange = Parameters.IncludeVATInPrice;
	
	DocumentDate = Parameters.DocumentDate;
	
	// VAT taxation.
	If Parameters.Property("VATTaxation") Then
		
		VATTaxation = Parameters.VATTaxation;
		VATTaxationOnOpen = Parameters.VATTaxation;
		VATTaxationIsAttribute = True;
		
	Else
		
		Items.VATTaxation.Visible = False;
		VATTaxationIsAttribute = False;
		
	EndIf;
	
EndProcedure // GetFormParametersValues()

&AtServer
// Procedure fills the exchange rates table
//
Procedure FillCurrencyRatesTable()
	
	Query = New Query;
	Query.SetParameter("DocumentDate", DocumentDate);
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
// Procedure for filling the exchange rate and document currency multiplicity.
//
Procedure FillRateRepetitionOfDocumentCurrency()
	
	If ValueIsFilled(DocumentCurrency) Then
		ArrayCourseRepetition = CurrencyRates.FindRows(New Structure("Currency", DocumentCurrency));
		If ValueIsFilled(ArrayCourseRepetition) Then
			ExchangeRate = ArrayCourseRepetition[0].ExchangeRate;
			Multiplicity = ArrayCourseRepetition[0].Multiplicity;
		Else
			ExchangeRate = 0;
			Multiplicity = 0;
		EndIf;
	EndIf;
	
EndProcedure // FillRateRepetitionOfDocumentCurrency()

&AtClient
// Procedure checks the correctness of the form attributes filling.
//
Procedure CheckFillOfFormAttributes(Cancel)
    	
	If Not ValueIsFilled(DocumentCurrency) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Currency has not been selected!'");
		Message.Field = "DocumentCurrency";
		Message.Message();
		Cancel = True;
	EndIf;
	If Not ValueIsFilled(ExchangeRate) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Currency rate should be different than zero!'");
		Message.Field = "ExchangeRate";
		Message.Message();
		Cancel = True;
	EndIf;
	If Not ValueIsFilled(Multiplicity) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Settlements currency exchange rate multiplicity is equal to zero! '");
		Message.Field = "SettlementsMultiplicity";
		Message.Message();
		Cancel = True;
	EndIf;	
	
	// VAT taxation.
	If VATTaxationIsAttribute Then
		If Not ValueIsFilled(VATTaxation) Then
            Message = New UserMessage();
			Message.Text = NStr("en = 'Field Taxation is required!'");
			Message.Field = "VATTaxation";
			Message.Message();
			Cancel = True;
   		EndIf;
	EndIf;
	
EndProcedure // CheckFillFormAttributes()

&AtClient
// Procedure checks if the form was modified.
//
Function CheckIfFormWasModified()

	WereMadeChanges = False;

	ChangesVATTaxation = ?(VATTaxationIsAttribute, VATTaxationOnOpen <> VATTaxation, False);
	
	If RecalculatePricesByCurrency 
		OR (AmountIncludesVATBefore <> AmountIncludesVAT)
		OR (VATIncludeInCostBeforeChange <> IncludeVATInPrice)
		OR (ExchangeRateBeforeChange <> ExchangeRate)
		OR (MultiplicityBeforeChange <> Multiplicity)
		OR (DocumentCurrencyBeforeChange <> DocumentCurrency) 
		OR ChangesVATTaxation Then

        WereMadeChanges = True;

	EndIf; 
	
	Return WereMadeChanges;

EndFunction // CheckIfFormWasModified()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initializing the form parameters.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GetFormValuesOfParameters();
	FillCurrencyRatesTable();
		
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// Procedure - event handler of clicking the Cancel button.
//
Procedure CancelExecute()
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("DialogReturnCode", DialogReturnCode.Cancel);
	ReturnStructure.Insert("WereMadeChanges", False);
	Close(ReturnStructure);

EndProcedure // CancelExecute()

&AtClient
// Procedure - event handler of clicking the OK button.
//
Procedure ButtOKExecute()
	
	Cancel = False;

	CheckFillOfFormAttributes(Cancel);
	If Not Cancel Then
		WereMadeChanges = CheckIfFormWasModified();
		ReturnStructure = New Structure();
		ReturnStructure.Insert("DocumentCurrency", DocumentCurrency);
		ReturnStructure.Insert("ExchangeRate", ExchangeRate);
		ReturnStructure.Insert("Multiplicity", Multiplicity);
		ReturnStructure.Insert("AmountIncludesVAT", AmountIncludesVAT);
		ReturnStructure.Insert("IncludeVATInPrice", IncludeVATInPrice);
		ReturnStructure.Insert("RecalculatePricesByCurrency", RecalculatePricesByCurrency);
		ReturnStructure.Insert("VATTaxation", VATTaxation);
		ReturnStructure.Insert("PrevVATTaxation", VATTaxationOnOpen);
		ReturnStructure.Insert("WereMadeChanges", WereMadeChanges);
		ReturnStructure.Insert("DialogReturnCode", DialogReturnCode.OK);
		Close(ReturnStructure);
	EndIf;

EndProcedure // ButtOKExecute()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - event handler OnChange of the Currency input field.
//
Procedure CurrencyOnChange(Item)
	
	FillRateRepetitionOfDocumentCurrency();
	If ValueIsFilled(DocumentCurrency) 
	   AND DocumentCurrencyBeforeChange <> DocumentCurrency Then
  		RecalculatePricesByCurrency = True;
		FillRateRepetitionOfDocumentCurrency();
  	Else
  		RecalculatePricesByCurrency = False;
	EndIf;
	
EndProcedure // CurrencyOnChange()

&AtClient
// Procedure - OnChange event handler of the DocumentCurrencyRate entry field.
//
Procedure DocumentCurrencyRateOnChange(Item)
	
	If ValueIsFilled(ExchangeRate) 
	   AND ExchangeRateBeforeChange <> ExchangeRate Then
		RecalculatePricesByCurrency = True;
	Else
		RecalculatePricesByCurrency = False;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the DocumentCurrencyRatio entry field.
//
Procedure RepetitionDocumentCurrenciesOnChange(Item)
	
	If ValueIsFilled(Multiplicity) 
	   AND MultiplicityBeforeChange <> Multiplicity Then
		RecalculatePricesByCurrency = True;
	Else
		RecalculatePricesByCurrency = False;
	EndIf;
	
EndProcedure