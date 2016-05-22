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



