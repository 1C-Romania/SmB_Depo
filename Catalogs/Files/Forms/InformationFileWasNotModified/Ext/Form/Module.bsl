
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	DontShowAgain = False;
	
	ReminderText = 
	NStr("en = 'The version was not created as file was not change. The comment is not saved.'");
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	If DontShowAgain = True Then
		CommonUseServerCall.CommonSettingsStorageSaveAndRefreshReusableValues(
			"ApplicationSettings",
			"ShowFileNotChangedMessage",
			False);
	EndIf;
	
	Close(DontShowAgain);
	
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
