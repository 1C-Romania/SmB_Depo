
#Region ServiceHandlers

&AtClient
// Procedure for filling the exchange rate and document currency multiplicity.
//
Procedure FillExchangeRateMultiplicityCurrencies(IsDocumentCurrency)
	
	If IsDocumentCurrency Then
		
		If DocumentCurrency = SettlementsCurrency Then
			
			RateDocumentCurrency = ExchangeRate;
			RepetitionDocumentCurrency = Multiplicity;
		
		ElsIf ValueIsFilled(SettlementsCurrency) Then
			
			ArrayCourseRepetition = CurrencyRates.FindRows(New Structure("Currency", DocumentCurrency));
			
			If ArrayCourseRepetition.Count() > 0 Then
				
				RateDocumentCurrency = ArrayCourseRepetition[0].ExchangeRate;
				RepetitionDocumentCurrency = ArrayCourseRepetition[0].Multiplicity;
				
			Else
				
				RateDocumentCurrency = 0;
				RepetitionDocumentCurrency = 0;
				
			EndIf;
			
		EndIf;
		
	Else
		
		If ValueIsFilled(DocumentCurrency) Then
			
			ArrayCourseRepetition = CurrencyRates.FindRows(New Structure("Currency", SettlementsCurrency));
			
			If ArrayCourseRepetition.Count() > 0 Then
				
				ExchangeRate = ArrayCourseRepetition[0].ExchangeRate;
				Multiplicity = ArrayCourseRepetition[0].Multiplicity;
				
			Else
				
				ExchangeRate = 0;
				Multiplicity = 0;
				
			EndIf;
			
		EndIf;
		
		If DocumentCurrency = SettlementsCurrency Then
			
			RateDocumentCurrency = ExchangeRate;
			RepetitionDocumentCurrency = Multiplicity;
		
		EndIf;
		
	EndIf;
	
EndProcedure // FillRateRepetitionOfDocumentCurrency()

&AtClient
// Procedure checks the correctness of the form attributes filling.
//
Procedure CheckFillOfFormAttributes(Cancel)
	
	If Not ValueIsFilled(DocumentCurrency) Then
		Message = New UserMessage();
		Message.Text = NStr("en='Currency has not been selected!';ru='Не выбрана валюта для заполнения!'");
		Message.Field = "DocumentCurrency";
		Message.Message();
		Cancel = True;
	EndIf;
	
	If Not ValueIsFilled(ExchangeRate) Then
		Message = New UserMessage();
		Message.Text = NStr("en='Settlements currency exchange rate is equal to zero!';ru='Обнаружен нулевой курс валюты расчетов!'");
		Message.Field = "ExchangeRate";
		Message.Message();
		Cancel = True;
	EndIf;
	
	If Not ValueIsFilled(Multiplicity) Then
		Message = New UserMessage();
		Message.Text = NStr("en='Settlements currency exchange rate multiplicity is equal to zero! ';ru='Обнаружена нулевая кратность курса валюты документа!'");
		Message.Field = "SettlementsMultiplicity";
		Message.Message();
		Cancel = True;
	EndIf;
	
	If Not ValueIsFilled(SettlementsCurrency) Then
		Message = New UserMessage();
		Message.Text = NStr("en='Currency to fill in has not been selected!';ru='Не выбрана валюта расчетов для заполнения!'");
		Message.Field = "SettlementsCurrency";
		Message.Message();
		Cancel = True;
	EndIf;
	
EndProcedure // CheckFillFormAttributes()

&AtClient
// Procedure checks if the form was modified.
//
Function CheckIfFormWasModified()
	
	WereMadeChanges = False;
	
	If RecalculatePricesByCurrency
		OR (ExchangeRateBeforeChange <> ExchangeRate)
		OR (MultiplicityBeforeChange <> Multiplicity)
		OR (ExchangeRateDocumentCurrencyBeforeChange <> RateDocumentCurrency)
		OR (MultiplicityDocumentCurrencyBeforeChange <> RepetitionDocumentCurrency)
		OR (SettlementsCurrencyBeforeChange <> SettlementsCurrency)
		OR (DocumentCurrencyBeforeChange <> DocumentCurrency) Then
		
		WereMadeChanges = True;
		
	EndIf; 
	
	Return WereMadeChanges;

EndFunction // CheckIfFormWasModified()

&AtClient
// The RecalculatePricesByCurrency flag control
Procedure SetAmountsConvertingFlag()
	
	If ValueIsFilled(SettlementsCurrency) AND SettlementsCurrencyBeforeChange <> SettlementsCurrency Then
		
		RecalculatePricesByCurrency = True;
		
	ElsIf ExchangeRate <> ExchangeRateBeforeChange Then
		
		RecalculatePricesByCurrency = True;
		
	ElsIf Multiplicity <> MultiplicityBeforeChange Then
		
		RecalculatePricesByCurrency = True;
		
	ElsIf ValueIsFilled(DocumentCurrency) AND DocumentCurrencyBeforeChange <> DocumentCurrency Then
		
		RecalculatePricesByCurrency = True;
		
	ElsIf RateDocumentCurrency <> ExchangeRateDocumentCurrencyBeforeChange Then
		
		RecalculatePricesByCurrency = True;
		
	ElsIf RepetitionDocumentCurrency <> MultiplicityDocumentCurrencyBeforeChange Then
		
		RecalculatePricesByCurrency = True;
		
	Else
		
		RecalculatePricesByCurrency = False;
		
	EndIf;
	
EndProcedure

&AtServer
// Procedure fills the form parameters.
//
Procedure GetFormValuesOfParameters()
	
	DocumentCurrency							= Parameters.DocumentCurrency;
	DocumentCurrencyBeforeChange			= Parameters.DocumentCurrency;
	RateDocumentCurrency						= Parameters.RateDocumentCurrency;
	ExchangeRateDocumentCurrencyBeforeChange		= Parameters.RateDocumentCurrency;
	RepetitionDocumentCurrency				= Parameters.RepetitionDocumentCurrency;
	MultiplicityDocumentCurrencyBeforeChange	= Parameters.RepetitionDocumentCurrency;
	
	SettlementsCurrency							= Parameters.SettlementsCurrency;
	SettlementsCurrencyBeforeChange			= Parameters.SettlementsCurrency;
	ExchangeRate 									= Parameters.ExchangeRate;
	ExchangeRateBeforeChange			 			= Parameters.ExchangeRate;
	Multiplicity 								= Parameters.Multiplicity;
	MultiplicityBeforeChange 				= Parameters.Multiplicity;
	
	DocumentDate 							= Parameters.DocumentDate;
	
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

#EndRegion

#Region CommandHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initializing the form parameters.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GetFormValuesOfParameters();
	
	FillCurrencyRatesTable();
	
EndProcedure // OnCreateAtServer()

#EndRegion

#Region CommandHandlers

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
		ReturnStructure.Insert("ChangedDocumentCurrency", 	DocumentCurrency <> DocumentCurrencyBeforeChange OR RateDocumentCurrency <> ExchangeRateDocumentCurrencyBeforeChange OR RepetitionDocumentCurrency <> MultiplicityDocumentCurrencyBeforeChange);
		ReturnStructure.Insert("DocumentCurrency", 			DocumentCurrency);
		ReturnStructure.Insert("RateDocumentCurrency", 		RateDocumentCurrency);
		ReturnStructure.Insert("RepetitionDocumentCurrency",	RepetitionDocumentCurrency);
		
		ReturnStructure.Insert("ChangedCurrencySettlements", 	SettlementsCurrency <> SettlementsCurrencyBeforeChange OR ExchangeRate <> ExchangeRateBeforeChange OR Multiplicity <> MultiplicityBeforeChange);
		ReturnStructure.Insert("SettlementsCurrency", 			SettlementsCurrency);
		ReturnStructure.Insert("ExchangeRate", 						ExchangeRate);
		ReturnStructure.Insert("Multiplicity", 				Multiplicity);
		
		ReturnStructure.Insert("RecalculatePricesByCurrency", 	RecalculatePricesByCurrency);
		
		ReturnStructure.Insert("WereMadeChanges", 		WereMadeChanges);
		ReturnStructure.Insert("DialogReturnCode", 		DialogReturnCode.OK);
		
		Close(ReturnStructure);
		
	EndIf;
	
EndProcedure // ButtOKExecute()

#EndRegion

#Region HeaderAttributesHandlers

&AtClient
// Procedure - event handler OnChange of the Currency input field.
//
Procedure CurrencyOnChange(Item)
	
	FillExchangeRateMultiplicityCurrencies(False);
	SetAmountsConvertingFlag();
	
EndProcedure // CurrencyOnChange()

&AtClient
Procedure DocumentCurrencyOnChange(Item)
	
	FillExchangeRateMultiplicityCurrencies(True);
	SetAmountsConvertingFlag();
	
EndProcedure

&AtClient
Procedure SettlementsCurrencyRateOnChange(Item)
	
	SetAmountsConvertingFlag();
	
	If DocumentCurrency = SettlementsCurrency Then
		
		RateDocumentCurrency = ExchangeRate;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SettlementsCurrenciesRatioOnChange(Item)
	
	SetAmountsConvertingFlag();
	
	If DocumentCurrency = SettlementsCurrency Then
		
		RepetitionDocumentCurrency = Multiplicity;
		
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
