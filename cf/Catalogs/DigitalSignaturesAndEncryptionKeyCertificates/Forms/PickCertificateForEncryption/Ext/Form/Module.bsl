#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DigitalSignatureService.SetConditionalCertificatesListAppearance(List);
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	CloseOnChoice = False;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Record_DigitalSignaturesAndEncryptionKeyCertificates")
	   AND Parameter.Property("IsNew") Then
		
		Items.List.Refresh();
		Items.List.CurrentRow = Source;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure UsersGroupUseOnChange(Item)
	
	UsersGroupOnChangingOnServer();
	
EndProcedure

&AtClient
Procedure UsersGroupOnChange(Item)
	
	UsersGroupOnChangingOnServer();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group, Parameter)
	
	Cancel = True;
	
	If Not Copy Then
		DigitalSignatureServiceClient.AddCertificateAfterSelectingDesignation(
			"ForEncryptionOnly", New Structure("ToPersonalList", True));
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Add(Command)
	
	Items.List.AddRow();
	
EndProcedure

&AtClient
Procedure AddFromFile(Command)
	
	DigitalSignatureServiceClient.AddCertificateForEncryptionOnlyFromFile(True);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure UsersGroupOnChangingOnServer()
	
	If UsersGroupUse Then
		List.QueryText =
		"SELECT
		|	Certificates.Ref,
		|	Certificates.DeletionMark,
		|	Certificates.Description,
		|	Certificates.IssuedToWhom,
		|	Certificates.firm,
		|	Certificates.Surname,
		|	Certificates.Name,
		|	Certificates.Patronymic,
		|	Certificates.Position,
		|	Certificates.WhoIssued,
		|	Certificates.ValidUntil,
		|	Certificates.Signing,
		|	Certificates.Encryption,
		|	Certificates.Imprint,
		|	Certificates.CertificateData,
		|	Certificates.Application,
		|	Certificates.Revoked,
		|	Certificates.EnhancedProtectionPrivateKey,
		|	Certificates.Company,
		|	Certificates.User,
		|	Certificates.UserNotifiedOnValidityInterval,
		|	Certificates.AddedBy,
		|	Certificates.Predefined,
		|	Certificates.PredefinedDataName
		|FROM
		|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
		|WHERE
		|	Certificates.RequestStatus IN (VALUE(Enum.CertificateIssueRequestState.EmptyRef), VALUE(Enum.CertificateIssueRequestState.Executed))
		|	AND TRUE In
		|			(SELECT TOP 1
		|				TRUE
		|			IN
		|				InformationRegister.UsersGroupsContents AS UsersGroupsContents
		|			WHERE
		|				UsersGroupsContents.User = Certificates.User
		|				AND UsersGroupsContents.UsersGroup IN (&UsersGroup))";
		CommonUseClientServer.SetDynamicListParameter(
			List, "UsersGroup", UsersGroup);
	Else
		List.QueryText =
		"SELECT
		|	Certificates.Ref,
		|	Certificates.DeletionMark,
		|	Certificates.Description,
		|	Certificates.IssuedToWhom,
		|	Certificates.firm,
		|	Certificates.Surname,
		|	Certificates.Name,
		|	Certificates.Patronymic,
		|	Certificates.Position,
		|	Certificates.WhoIssued,
		|	Certificates.ValidUntil,
		|	Certificates.Signing,
		|	Certificates.Encryption,
		|	Certificates.Imprint,
		|	Certificates.CertificateData,
		|	Certificates.Application,
		|	Certificates.Revoked,
		|	Certificates.EnhancedProtectionPrivateKey,
		|	Certificates.Company,
		|	Certificates.User,
		|	Certificates.UserNotifiedOnValidityInterval,
		|	Certificates.AddedBy,
		|	Certificates.Predefined,
		|	Certificates.PredefinedDataName
		|FROM
		|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
		|WHERE
		|	Certificates.RequestStatus IN (VALUE(Enum.CertificateIssueRequestState.EmptyRef), VALUE(Enum.CertificateIssueRequestState.Executed))";
	EndIf;
	
EndProcedure

#EndRegion














