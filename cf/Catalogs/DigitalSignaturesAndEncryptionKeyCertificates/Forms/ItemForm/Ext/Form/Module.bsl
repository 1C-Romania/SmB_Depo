#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Ref) Then
		Return;
	EndIf;
	
	OnCreateAtServerOnReadAtServer();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ValueIsFilled(Object.Ref) Then
		Cancel = True;
		AttachIdleHandler("WaitHandlerAddCertificate", 0.1, True);
		Return;
		
	ElsIf ValueIsFilled(Object.RequestStatus)
	        AND Object.RequestStatus
	           <> PredefinedValue("Enum.CertificateIssueRequestState.Executed") Then
		
		Cancel = True;
		AttachIdleHandler("WaitHandlerOpenStatement", 0.1, True);
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If CertificateAddress <> Undefined Then
		OnCreateAtServerOnReadAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Record_DigitalSignaturesAndEncryptionKeyCertificates", New Structure, Object.Ref);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// Check for name uniqueness.
	If Not Items.Description.ReadOnly Then
		DigitalSignatureService.CheckPresentationUniqueness(
			Object.Description, Object.Ref, "Object.Description", Cancel);
	EndIf;
	
	If TypeOf(AttributesParameters) <> Type("Structure") Then
		Return;
	EndIf;
	
	For Each KeyAndValue IN AttributesParameters Do
		AttributeName = KeyAndValue.Key;
		Properties     = KeyAndValue.Value;
		
		If Not Properties.ReadOnly.FillChecking
		 Or ValueIsFilled(Object[AttributeName]) Then
			
			Continue;
		EndIf;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Field %1 is not filled.';ru='Поле %1 не заполнено.'"), Items[AttributeName].Title);
		
		CommonUseClientServer.MessageToUser(MessageText,, AttributeName,, Cancel);
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ShowAutofilledAttributes(Command)
	
	Show = Not Items.FormShowAutofilledAttributes.Check;
	
	Items.FormShowAutofilledAttributes.Check = Show;
	Items.AutoFieldsHeadersFromCertificateData.Visible = Show;
	Items.AutoFieldsFromCertificateData.Visible = Show;
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.Companies") Then
		Items.CompanyHeader.Visible = Show;
		Items.Company.Visible = Show;
	EndIf;
	
	
	
EndProcedure

&AtClient
Procedure ShowCertificateData(Command)
	
	DigitalSignatureClient.OpenCertificate(CertificateAddress, True);
	
EndProcedure

&AtClient
Procedure ShowRequestForCertificateIssue(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("CertificatRef", Object.Ref);
	OpenForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.RequestForNewQualifiedCertificateIssue",
		FormParameters);
	
EndProcedure

&AtClient
Procedure CheckCertificate(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		ShowMessageBox(, NStr("en='Certificate is not written yet.';ru='Сертификат еще не записан.'"));
		Return;
	EndIf;
	
	If Modified AND Not Write() Then
		Return;
	EndIf;
	
	DigitalSignatureClient.CheckCatalogCertificate(Object.Ref,
		New Structure("WithoutConfirmation", True));
	
EndProcedure

&AtClient
Procedure SaveCertificateDataInFile(Command)
	
	DigitalSignatureServiceClient.SaveCertificate(, CertificateAddress);
	
EndProcedure

&AtClient
Procedure CertificateRevoked(Command)
	
	Object.Revoked = Not Object.Revoked;
	Items.FormCertificateRevoked.Check = Object.Revoked;
	
	If Object.Revoked Then
		ShowMessageBox(, NStr("en='After recording the call can not be canceled.';ru='После записи отменить отзыв будет невозможно.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure OnCreateAtServerOnReadAtServer()
	
	If ValueIsFilled(Object.RequestStatus) Then
		If Object.RequestStatus = Enums.CertificateIssueRequestState.Executed Then
			Items.FormShowRequestForCertificateIssue.Enabled = True;
			Items.ShowRequestForCertificateIssue.Enabled = True;
		Else
			Return;
		EndIf;
	EndIf;
	
	CertificateBinaryData = CommonUse.ObjectAttributeValue(
		Object.Ref, "CertificateData").Get();
	
	If TypeOf(CertificateBinaryData) = Type("BinaryData") Then
		Certificate = New CryptoCertificate(CertificateBinaryData);
		If ValueIsFilled(CertificateAddress) Then
			PutToTempStorage(CertificateBinaryData, CertificateAddress);
		Else
			CertificateAddress = PutToTempStorage(CertificateBinaryData, UUID);
		EndIf;
		DigitalSignatureClientServer.FillCertificateDataDescription(CertificateDataDescription, Certificate);
	Else
		CertificateAddress = "";
		Items.ShowCertificateData.Enabled  = False;
		Items.FormCheckCertificate.Enabled = False;
		Items.FormSaveCertificateDataInFile.Enabled = False;
		Items.AutoFieldsFromCertificateData.Visible = True;
		Items.AutoFieldsHeadersFromCertificateData.Visible = True;
		Items.FormShowAutofilledAttributes.Check = True;
	EndIf;
	
	Items.FormCertificateRevoked.Check = Object.Revoked;
	If Object.Revoked Then
		Items.FormCertificateRevoked.Enabled = False;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess() Then
		If Object.AddedBy      <> Users.CurrentUser()
		   AND Object.User <> Users.CurrentUser() Then
			// Regular users can change only their certificates.
			ReadOnly = True;
		Else
			// A regular user can not change the access rights.
			Items.AddedBy.ReadOnly = True;
			If Object.AddedBy <> Users.CurrentUser() Then
				// A regular user can not change
				// the attribute User if they didn't add a certificate.
				Items.User.ReadOnly = True;
			EndIf;
		EndIf;
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
		CompaniesServiceModule = CommonUse.CommonModule("CompaniesService");
		CompanyByDefault = CompaniesServiceModule.CompanyByDefault();
		
		If ValueIsFilled(CompanyByDefault)
		   AND Object.Company = CompanyByDefault
		   AND Not CompaniesServiceModule.SeveralCompaniesAreUsed() Then
			
			Items.CompanyHeader.Visible = False;
			Items.Company.Visible = False;
		EndIf;
	EndIf;
	If Not CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
		Items.CompanyHeader.Visible = False;
		Items.Company.Visible = False;
	EndIf;
	
	If Not ValueIsFilled(CertificateAddress) Then
		Return; // Certificate = Undefined.
	EndIf;
	
	SubjectProperties = DigitalSignatureClientServer.CertificateSubjectProperties(Certificate);
	If SubjectProperties.Surname <> Undefined Then
		Items.Surname.ReadOnly = True;
	EndIf;
	If SubjectProperties.Name <> Undefined Then
		Items.Name.ReadOnly = True;
	EndIf;
	If SubjectProperties.Patronymic <> Undefined Then
		Items.Patronymic.ReadOnly = True;
	EndIf;
	If SubjectProperties.Company <> Undefined Then
		Items.firm.ReadOnly = True;
	EndIf;
	If SubjectProperties.Position <> Undefined Then
		Items.Position.ReadOnly = True;
	EndIf;
	
	AttributesParameters = Undefined;
	DigitalSignatureService.BeforeEditKeyCertificate(
		Object.Ref, Certificate, AttributesParameters);
	
	For Each KeyAndValue IN AttributesParameters Do
		AttributeName = KeyAndValue.Key;
		Properties     = KeyAndValue.Value;
		
		If Not Properties.Visible Then
			Items[AttributeName].Visible = False;
			
		ElsIf Properties.ReadOnly Then
			Items[AttributeName].ReadOnly = True
		EndIf;
		If Properties.ReadOnly.FillChecking Then
			Items[AttributeName].AutoMarkIncomplete = True;
		EndIf;
	EndDo;
	
	Items.AutoFieldsFromCertificateData.Visible =
		    Not Items.Surname.ReadOnly   AND Not ValueIsFilled(Object.Surname)
		Or Not Items.Name.ReadOnly       AND Not ValueIsFilled(Object.Name)
		Or Not Items.Patronymic.ReadOnly  AND Not ValueIsFilled(Object.Patronymic);
	
	Items.DescriptionHeader.Visible = Items.Description.Visible;
	Items.CompanyHeader.Visible  = Items.Company.Visible;
	Items.UserHeader.Visible = Items.User.Visible;
	
	Items.AutoFieldsHeadersFromCertificateData.Visible =
		Items.AutoFieldsFromCertificateData.Visible;
	
	Items.FormShowAutofilledAttributes.Check =
		Items.AutoFieldsFromCertificateData.Visible;
	
EndProcedure

&AtClient
Procedure WaitHandlerAddCertificate()
	
	CreationParameters = New Structure;
	CreationParameters.Insert("ToPersonalList", True);
	CreationParameters.Insert("Company", Object.Company);
	CreationParameters.Insert("HideApplication", False);
	
	DigitalSignatureServiceClient.AddCertificate(CreationParameters);
	
EndProcedure

&AtClient
Procedure WaitHandlerOpenStatement()
	
	FormParameters = New Structure;
	FormParameters.Insert("CertificatRef", Object.Ref);
	OpenForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.RequestForNewQualifiedCertificateIssue",
		FormParameters);
	
EndProcedure

#EndRegion














