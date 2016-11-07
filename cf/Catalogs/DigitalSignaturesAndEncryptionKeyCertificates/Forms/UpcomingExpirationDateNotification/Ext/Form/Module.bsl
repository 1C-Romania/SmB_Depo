#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Certificate = Parameters.Certificate;
	
	CertificateValidUntil = CommonUse.ObjectAttributeValue(
		Certificate, "ValidUntil");
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If DoNotRemindMore Then
		SetMarkAtServer(Certificate);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure SetMarkAtServer(Certificate)
	
	CertificateObject = Certificate.GetObject();
	CertificateObject.UserNotifiedOnValidityInterval = True;
	CertificateObject.Write();
	
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
