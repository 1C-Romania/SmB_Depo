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
		NStr("en = 'Currency rates are outdated'"),
		ProcessorsURL(),
		NStr("en = 'Update currency rates'"),
		PictureLib.Warning32);
	
EndProcedure

// Displays an appropriate notification.
//
Procedure NotifyCurrencyRatesSuccessfullyUpdated() Export
	
	ShowUserNotification(
		NStr("en = 'Currency rates have been successfully updated'"),
		,
		NStr("en = 'Currency rates are updated'"),
		PictureLib.Information32);
	
EndProcedure

// Displays an appropriate notification.
//
Procedure NotifyCoursesAreActual() Export
	
	ShowMessageBox(,NStr("en = 'Currency rates are actual.'"));
	
EndProcedure

// Returns the navigational link for the notifications.
//
Function ProcessorsURL()
	Return "e1cib/app/DataProcessor.CurrencyRatesImportProcess";
EndFunction

#EndRegion
