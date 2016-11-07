////////////////////////////////////////////////////////////////////////////////
// Subsystem "Banks".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// It is called once the configuration is launched, activates the wait handler.
//
Procedure AfterSystemOperationStart() Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If ClientParameters.Property("Banks") AND ClientParameters.Banks.StaleAlertOutput Then
		AttachIdleHandler("WorkWithBanksWithdrawNotificationOfIrrelevance", 45, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Update of the banks classifier.

// Displays an appropriate notification.
//
Procedure NotifyClassifierOutOfDate() Export
	
	ShowUserNotification(
		NStr("en='Banks classifier is outdated';ru='Классификатор банков устарел'"),
		URLFormsExport(),
		NStr("en='Update the banks clasifier';ru='Обновить классификатор банков'"),
		PictureLib.Warning32);
	
EndProcedure

// Displays an appropriate notification.
//
Procedure NotifyClassifierUpdatedSuccessfully() Export
	
	ShowUserNotification(
		NStr("en='Banks classifier has been successfully updated';ru='Классификатор банков успешно обновлен'"),
		URLFormsExport(),
		NStr("en='Banks classifier is updated';ru='Классификатор банков обновлен'"),
		PictureLib.Information32);
	
EndProcedure

// Displays an appropriate notification.
//
Procedure NotifyClassifierIsActual() Export
	
	ShowMessageBox(,NStr("en='Banks classifier is relevant.';ru='Классификатор банков актуален.'"));
	
EndProcedure

// Returns the navigational link for the notifications.
//
Function URLFormsExport()
	Return "e1cib/data/Catalog.RFBankClassifier.Form.ImportClassifier";
EndFunction

#EndRegion
