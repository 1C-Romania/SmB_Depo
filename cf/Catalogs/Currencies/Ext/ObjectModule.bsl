#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If SetRateMethod = Enums.CurrencyRateSetMethods.CalculationByFormula Then
		QueryText =
		"SELECT
		|	Currencies.Description AS SymbolicCode
		|FROM
		|	Catalog.Currencies AS Currencies
		|WHERE
		|	(Currencies.SetRateMethod = VALUE(Enum.CurrencyRateSetMethods.MarkupOnExchangeRateOfOtherCurrencies)
		|			OR Currencies.SetRateMethod = VALUE(Enum.CurrencyRateSetMethods.CalculationByFormula))";
		
		Query = New Query(QueryText);
		DependentCurrencies = Query.Execute().Unload().UnloadColumn("SymbolicCode");
		
		For Each Currency IN DependentCurrencies Do
			If Find(RateCalculationFormula, Currency) > 0 Then
				Cancel = True;
			EndIf;
		EndDo;
	EndIf;
	
	If ValueIsFilled(MainCurrency.MainCurrency) Then
		Cancel = True;
	EndIf;
	
	If Cancel Then
		CommonUseClientServer.MessageToUser(
			NStr("en='The currency exchange rate can be linked to the rate of the independent currency only.';ru='Курс валюты можно связать только с курсом независимой валюты.'"));
	EndIf;
	
	If SetRateMethod <> Enums.CurrencyRateSetMethods.MarkupOnExchangeRateOfOtherCurrencies Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("MainCurrency");
		AttributesToExclude.Add("Markup");
		CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, AttributesToExclude);
	EndIf;
	
	If SetRateMethod <> Enums.CurrencyRateSetMethods.CalculationByFormula Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("RateCalculationFormula");
		CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, AttributesToExclude);
	EndIf;
	
	If Not IsNew()
		AND SetRateMethod = Enums.CurrencyRateSetMethods.MarkupOnExchangeRateOfOtherCurrencies
		AND WorkWithCurrencyRates.DependentCurrenciesList(Ref).Count() > 0 Then
		CommonUseClientServer.MessageToUser(
			NStr("en='The currency can not be subordinate, as it is the main currency for other currencies.';ru='Валюта не может быть подчиненной, так как она является основной для других валют.'"));
		Cancel = True;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	WorkWithCurrencyRates.CheckRateOn01Correctness_01_1980(Ref);
	
	If AdditionalProperties.Property("UpdateRates") Then
		If CommonUseReUse.DataSeparationEnabled() Then
			WorkWithCurrencyRates.OnUpdatingCurrencyRatesSaaS(ThisObject);
		Else
			UpdateExchangeRate(ThisObject);
		EndIf;
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsNew() Then
		AdditionalProperties.Insert("UpdateRates");
	Else
		PreviousValues = CommonUse.ObjectAttributesValues(Ref, "Code,SetRateMethod,MainCurrency,Markup,RateCalculationFormula");
		If (PreviousValues.SetRateMethod <> SetRateMethod)
			Or (SetRateMethod = Enums.CurrencyRateSetMethods.ExportFromInternet 
				AND PreviousValues.Code <> Code)
			Or (SetRateMethod = Enums.CurrencyRateSetMethods.MarkupOnExchangeRateOfOtherCurrencies
				AND (PreviousValues.MainCurrency <> MainCurrency Or PreviousValues.Markup <> Markup))
			Or (SetRateMethod = Enums.CurrencyRateSetMethods.CalculationByFormula
				AND PreviousValues.RateCalculationFormula <> RateCalculationFormula) Then
			AdditionalProperties.Insert("UpdateRates");
		EndIf;
	EndIf;
	
	If SetRateMethod <> Enums.CurrencyRateSetMethods.MarkupOnExchangeRateOfOtherCurrencies Then
		MainCurrency = Catalogs.Currencies.EmptyRef();
		Markup = 0;
	EndIf;
	
	If SetRateMethod <> Enums.CurrencyRateSetMethods.CalculationByFormula Then
		RateCalculationFormula = "";
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure UpdateExchangeRate(SubordinateCurrency) 
	
	If SetRateMethod = Enums.CurrencyRateSetMethods.MarkupOnExchangeRateOfOtherCurrencies Then
		Query = New Query;
		Query.Text = 
		"SELECT
		|	CurrencyRates.Period,
		|	CurrencyRates.Currency,
		|	CurrencyRates.ExchangeRate,
		|	CurrencyRates.Multiplicity
		|FROM
		|	InformationRegister.CurrencyRates AS CurrencyRates
		|WHERE
		|	CurrencyRates.Currency = &CurrencySource";
		Query.SetParameter("CurrencySource", SubordinateCurrency.MainCurrency);
		
		Selection = Query.Execute().Select();
		
		RecordSet = InformationRegisters.CurrencyRates.CreateRecordSet();
		RecordSet.Filter.Currency.Set(SubordinateCurrency.Ref);
		
		Markup = SubordinateCurrency.Markup;
		
		While Selection.Next() Do
			
			NewCurrencySetRecord = RecordSet.Add();
			NewCurrencySetRecord.Currency    = SubordinateCurrency.Ref;
			NewCurrencySetRecord.Multiplicity = Selection.Multiplicity;
			NewCurrencySetRecord.ExchangeRate      = Selection.ExchangeRate + Selection.ExchangeRate * Markup / 100;
			NewCurrencySetRecord.Period    = Selection.Period;
			
		EndDo;
		
		RecordSet.AdditionalProperties.Insert("DisableDependentCurrenciesControl", True);
		RecordSet.Write();
		
	ElsIf SetRateMethod = Enums.CurrencyRateSetMethods.CalculationByFormula Then
		
		// Receive the main currencies for the SubordinateCurrency.
		Query = New Query;
		Query.Text = 
		"SELECT
		|	Currencies.Ref AS Ref
		|FROM
		|	Catalog.Currencies AS Currencies
		|WHERE
		|	&RateCalculationFormula LIKE ""%"" + Currencies.Description + ""%""";
		
		Query.SetParameter("RateCalculationFormula", SubordinateCurrency.RateCalculationFormula);
		MainCurrencies = Query.Execute().Unload();
		
		If MainCurrencies.Count() = 0 Then
			ErrorText = NStr("en='Formula must contain at least one main currency.';ru='В формуле должна быть использована хотя бы одна основная валюта.'");
			CommonUseClientServer.MessageToUser(ErrorText, , "Object.RateCalculationFormula");
			Raise ErrorText;
		EndIf;
		
		UpdatedPeriods = New Map; // Cache for single recalculation of exchange rate within the same period.
		// Rewrite the exchange rates of the main currencies to update the exchange rate of the SubordinateCurrency.
		For Each RecordMainCurrency IN MainCurrencies Do
			RecordSet = InformationRegisters.CurrencyRates.CreateRecordSet();
			RecordSet.Filter.Currency.Set(RecordMainCurrency.Ref);
			RecordSet.Read();
			RecordSet.AdditionalProperties.Insert("UpdateDependentCurrencyRate", SubordinateCurrency.Ref);
			RecordSet.AdditionalProperties.Insert("UpdatedPeriods", UpdatedPeriods);
			RecordSet.Write();
		EndDo
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
