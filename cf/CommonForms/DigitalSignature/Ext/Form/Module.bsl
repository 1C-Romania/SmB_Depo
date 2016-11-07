
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, Parameters.SignatureProperties);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SaveToFile(Command)
	
	DigitalSignatureClient.SaveSignature(SignatureAddress);
	
EndProcedure

&AtClient
Procedure OpenCertificate(Command)
	
	If ValueIsFilled(CertificateAddress) Then
		DigitalSignatureClient.OpenCertificate(CertificateAddress);
		
	ElsIf ValueIsFilled(Imprint) Then
		DigitalSignatureClient.OpenCertificate(Imprint);
	EndIf;
	
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
