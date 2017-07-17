////////////////////////////////////////////////////////////////////////////////
// Subsystem "Currencies"
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Converts the Amount from Current currency to New currency according to the parameters of their exchange rates. 
//   You can use the function to get the exchange rates parameters.
//   WorkWithExchangeRates.GetCurrencyRate(Currency, ExchangeRateDate).
//
// Parameters:
//   Amount                - Number     - The amount to be converted.
//   CurrentRateParameters - Structure  - Exchange rate parameters of the currency to be converted.
//       * Currency        - CatalogRef.Currencies - Ref of the currency being converted.
//       * ExchangeRate    - Number - The exchange rate of the currency being converted.
//       * Multiplicity    - Number - The multiplicity of the currency being converted.
//   NewRateParameters - Structure - Exchange rate parameters of the currency to be converted to.
//       * Currency        - CatalogRef.Currencies - Ref of the currency which is being converted to.
//       * ExchangeRate    - Number - Exchange rate of the currency which is being converted to.
//       * Multiplicity    - Number - Multiplicity of the currency which is being converted to.
//
// Returns: 
//   Number - The amount converted according to new exchange rate.
//
Function RecalculateByRate(Amount, CurrentRateParameters, NewRateParameters) Export
	If CurrentRateParameters.Currency = NewRateParameters.Currency
		OR (
			CurrentRateParameters.ExchangeRate = NewRateParameters.ExchangeRate 
			AND CurrentRateParameters.Multiplicity = NewRateParameters.Multiplicity
		) Then
		
		Return Amount;
		
	EndIf;
	
	If CurrentRateParameters.ExchangeRate = 0
		OR CurrentRateParameters.Multiplicity = 0
		OR NewRateParameters.ExchangeRate = 0
		OR NewRateParameters.Multiplicity = 0 Then
		
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='When converting into currency %1, sum %2 was set to null because the currency rate was not specified.';ru='При пересчете в валюту %1 сумма %2 установлена в нулевое значение, т.к. курс валюты не задан.'"), 
				NewRateParameters.Currency, 
				Format(Amount, "NFD=2; NZ=0")));
		
		Return 0;
		
	EndIf;
	
	Return Round((Amount * CurrentRateParameters.ExchangeRate * NewRateParameters.Multiplicity) / (NewRateParameters.ExchangeRate * CurrentRateParameters.Multiplicity), 2);
EndFunction

// Obsolete: You should use the ConvertByRate function.
//
// Calculates the amount of the CurrencyBeg currency at the rate of ByRateBeg in the CurrencyEnd currency at the rate of ByRateEnd.
//
// Parameters:
//   Amount          - Number - The amount to be converted.
//   CurrencyBeg     - CatalogRef.Currencies - The currency to be converted from.
//   CurrencyEnd     - CatalogRef.Currencies - The currency to be converted to.
//   ByRateBeg       - Number - The exchange rate to be converted from.
//   ByRateEnd       - Number - The exchange rate to be converted to.
//   ByRepetitionBeg - Number - The multiplicity to be converted from (by default = 1).
//   ByRepetitionEnd - Number - The multiplicity to be converted to (by default = 1).
//
// Returns: 
//   Number - The amount converted to another currency.
//
Function RecalculateFromCurrencyToCurrency(Amount, CurrencyBeg, CurrencyEnd, ByRateBeg, ByRateEnd, 
	ByRepetitionBeg = 1, ByRepetitionEnd = 1) Export
	
	Return RecalculateByRate(
		Amount, 
		New Structure("Currency, ExchangeRate, multiplicity", CurrencyBeg, ByRateBeg, ByRepetitionBeg),
		New Structure("Currency, ExchangRate, multiplicity", CurrencyEnd, ByRateEnd, ByRepetitionEnd));
	
EndFunction

#EndRegion
