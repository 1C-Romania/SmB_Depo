#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure fills out the tabular section with the list of currencies. Only the currencies with rate that does not depend on the other currencies' rate are included into the list.
// 
Procedure FillCurrencyList() Export
	
	CurrenciesList.Clear();
	
	ExportableCurrencies = WorkWithCurrencyRates.GetImportCurrenciesArray();
	
	For Each CurrencyItem IN ExportableCurrencies Do
		NewRow = CurrenciesList.Add();
		NewRow.CurrencyCode = CurrencyItem.Code;
		NewRow.Currency    = CurrencyItem;
	EndDo;
	
EndProcedure

// Procedure requests file with rates for each exported currency.
// After import, the rates complying with the period are written to the data register.
//
Function CurrencyRatesImport(ErrorsOccuredOnImport = False) Export
	
	Return WorkWithCurrencyRates.CurrencyRatesImportByParameters(
		CurrenciesList,
		ImportBeginOfPeriod,
		ImportEndOfPeriod,
		ErrorsOccuredOnImport);
	
EndFunction

#EndRegion

#EndIf
