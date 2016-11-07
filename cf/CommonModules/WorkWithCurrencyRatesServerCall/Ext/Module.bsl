////////////////////////////////////////////////////////////////////////////////
// Subsystem "Currencies"
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Imports data on currency exchange rate.
//
Function ImportCurrencyRateFromFile(Currency, PathToFile, ImportBeginOfPeriod, ImportEndOfPeriod) Export
	Return WorkWithCurrencyRates.ImportCurrencyRateFromFile(Currency, PathToFile, ImportBeginOfPeriod, ImportEndOfPeriod);
EndFunction

// Checks the exchange rates relevance of all the currencies.
//
Function ExchangeRatesAreRelevant() Export
	Return WorkWithCurrencyRates.ExchangeRatesAreRelevant();
EndFunction

#EndRegion
