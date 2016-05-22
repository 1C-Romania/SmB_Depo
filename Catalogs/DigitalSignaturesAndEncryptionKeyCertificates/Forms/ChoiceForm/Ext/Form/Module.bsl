
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DigitalSignatureService.SetConditionalCertificatesListAppearance(List);
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Parameters.Filter.Property("Company", Company);
	
	CommonSettings = DigitalSignature.CommonSettings();
	
	If Not CommonSettings.UseEncryption
	   AND Not CommonSettings.CertificateIssueApplicationAvailable Then
		
		Items.FormCreate.Title = NStr("en = 'Add'");
		Items.ListContextMenuCreate.Title = NStr("en = 'Add'");
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Record_DigitalSignaturesAndEncryptionKeyCertificates")
	   AND Parameter.Property("IsNew") Then
		
		Items.List.Refresh();
		Items.List.CurrentRow = Source;
	EndIf;
	
	// On change of usage settings.
	If Upper(EventName) <> Upper("Record_ConstantsSet") Then
		Return;
	EndIf;
	
	If Upper(Source) = Upper("UseDigitalSignatures")
	 Or Upper(Source) = Upper("UseEncryption") Then
		
		AttachIdleHandler("OnChangeSigningOrEncryptionUsage", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group, Parameter)
	
	Cancel = True;
	If Not Copy Then
		
		CreationParameters = New Structure;
		CreationParameters.Insert("ToPersonalList", True);
		CreationParameters.Insert("Company", Company);
		
		DigitalSignatureServiceClient.AddCertificate(CreationParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure OnChangeSigningOrEncryptionUsage()
	
	CommonSettings = DigitalSignatureClientServer.CommonSettings();
	
	If CommonSettings.UseEncryption
	 Or CommonSettings.CertificateIssueApplicationAvailable Then
		
		Items.FormCreate.Title = NStr("en = 'Add...'");
		Items.ListContextMenuCreate.Title = NStr("en = 'Add...'");
	Else
		Items.FormCreate.Title = NStr("en = 'Add'");
		Items.ListContextMenuCreate.Title = NStr("en = 'Add'");
	EndIf;
	
EndProcedure

#EndRegion
