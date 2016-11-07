
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Cancel = True;
	EndIf;
	
	PersonalDataProtection.OnEventsRegistrationSettingsFormCreation(ThisObject);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Notification = New NotifyDescription("ChooseAndClose", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndClose(Command)
	ChooseAndClose();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure WriteAtServer()
	PersonalDataProtection.OnEventsRegistrationSettingsFormWrite(ThisObject);
	Modified = False;
EndProcedure

&AtClient
Procedure ChooseAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	WriteAtServer();
	Modified = False;
	Close();
	
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
