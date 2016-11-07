////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Certificate = Parameters.Certificate;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If DoNotRemindMore Then
		SetMarkAtServer(Certificate);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServerNoContext
Procedure SetMarkAtServer(Certificate)
	
	CertificateObject = Certificate.GetObject();
	CertificateObject.NotifiedOnDurationOfActions = True;
	CertificateObject.Write();
	
EndProcedure






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
