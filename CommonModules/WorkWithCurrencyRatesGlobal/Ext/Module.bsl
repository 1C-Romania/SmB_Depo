////////////////////////////////////////////////////////////////////////////////
// Subsystem "Currencies".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Shows message on the necessity to update currency exchange rates.
//
Procedure ExchangeRateOperationsShowNotificationAboutNonActuality() Export
	If Not WorkWithCurrencyRatesServerCall.ExchangeRatesAreRelevant() Then
		WorkWithCurrencyRatesClient.NotifyRatesOutdated();
	EndIf;
	
	CurrentDate = CommonUseClient.SessionDate();
	PeriodNextDaysHandler = EndOfDay(CurrentDate) - CurrentDate + 59;
	AttachIdleHandler("ExchangeRateOperationsShowNotificationAboutNonActuality", PeriodNextDaysHandler, True);
EndProcedure

#EndRegion
