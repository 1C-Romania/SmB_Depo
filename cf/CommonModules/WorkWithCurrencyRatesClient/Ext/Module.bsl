////////////////////////////////////////////////////////////////////////////////
// Subsystem "Currencies"
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// It is called once the configuration is launched, activates the wait handler.
Procedure AfterSystemOperationStart() Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If ClientParameters.Property("Currencies") AND ClientParameters.Currencies.ExchangeRatesAreRelevantUpdatedByResponsible Then
		AttachIdleHandler("ExchangeRateOperationsShowNotificationAboutNonActuality", 15, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Update of the currency exchange rates

// Displays an appropriate notification.
//
Procedure NotifyRatesOutdated() Export
	
	ShowUserNotification(
		NStr("en='Currency rates are outdated';ru='Курсы валют устарели'"),
		ProcessorsURL(),
		NStr("en='Update currency rates';ru='Обновить курсы валют'"),
		PictureLib.Warning32);
	
EndProcedure

// Displays an appropriate notification.
//
Procedure NotifyCurrencyRatesSuccessfullyUpdated() Export
	
	ShowUserNotification(
		NStr("en='Currency rates have been successfully updated';ru='Курсы валют успешно обновлены'"),
		,
		NStr("en='Currency rates are updated';ru='Курсы валют обновлены'"),
		PictureLib.Information32);
	
EndProcedure

// Displays an appropriate notification.
//
Procedure NotifyCoursesAreActual() Export
	
	ShowMessageBox(,NStr("en='Currency rates are actual.';ru='Курсы валют актуальны.'"));
	
EndProcedure

// Returns the navigational link for the notifications.
//
Function ProcessorsURL()
	Return "e1cib/app/DataProcessor.CurrencyRatesImportProcess";
EndFunction

#EndRegion
