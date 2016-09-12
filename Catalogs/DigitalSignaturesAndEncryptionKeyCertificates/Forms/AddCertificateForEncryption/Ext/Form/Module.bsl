#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.CertificateDataAddress) Then
		CertificateData = GetFromTempStorage(Parameters.CertificateDataAddress);
		
		CryptoCertificate = DigitalSignatureService.BinaryDataCertificate(CertificateData);
		If CryptoCertificate = Undefined Then
			Cancel = True;
			Return;
		EndIf;
		
		ShowPageCertificatePropertiesAdjustment(ThisObject,
			CryptoCertificate, CryptoCertificate.Unload());
		Items.Back.Visible = False;
	Else
		If DigitalSignatureClientServer.CommonSettings().CreateDigitalSignaturesAtServer Then
			Items.GroupCertificates.Title =
				NStr("en='Personal certificates on computer and server';ru='Личные сертификаты на компьютере и сервере'");
		EndIf;
		
		ErrorReceivingCertificatesOnClient = Parameters.ErrorReceivingCertificatesOnClient;
		UpdateCertificatesListOnServer(Parameters.CertificatesPropertiesOnClient);
	EndIf;
	
	Items.CertificateUser.ToolTip =
		Metadata.Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.Attributes.User.ToolTip;
	
	Items.CertificateCompany.ToolTip =
		Metadata.Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.Attributes.Company.ToolTip;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(Certificate) Then
		Cancel = True;
		Return;
	EndIf;
	
	If ValueIsFilled(CertificateAddress) Then
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionApplications")
	 Or Upper(EventName) = Upper("Write_PathsToDigitalSignatureAndEncryptionFilesAtServersLinux") Then
		
		RefreshReusableValues();
		If Items.Back.Visible Then
			UpdateCertificatesList();
		EndIf;
		Return;
	EndIf;
	
	If Upper(EventName) = Upper("Record_DigitalSignaturesAndEncryptionKeyCertificates") Then
		UpdateCertificatesList();
		Return;
	EndIf;
	
	If Upper(EventName) = Upper("Set_ExpandedWorkWithCryptography") Then
		UpdateCertificatesList();
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// Check for name uniqueness.
	DigitalSignatureService.CheckPresentationUniqueness(
		CertificateName, Certificate, "CertificateName", Cancel);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure CertificatesNotAvailableOnClientLabelClick(Item)
	
	DigitalSignatureServiceClient.ShowRequestToApplicationError(
		NStr("en='Certificates on computer';ru='Сертификаты на компьютере'"), "", ErrorReceivingCertificatesOnClient, New Structure);
	
EndProcedure

&AtClient
Procedure CertificatesNotAvailableAtServerLabelClick(Item)
	
	DigitalSignatureServiceClient.ShowRequestToApplicationError(
		NStr("en='Certificates on server';ru='Сертификаты на сервере'"), "", ErrorReceivingCertificatesAtServer, New Structure);
	
EndProcedure

&AtClient
Procedure ShowAllOnChange(Item)
	
	UpdateCertificatesList();
	
EndProcedure

&AtClient
Procedure InstructionClick(Item)
	
	DigitalSignatureServiceClient.OpenInstructionForWorkWithApplications();
	
EndProcedure

#EndRegion

#Region ItemEventsHandlersFormTablesCertificates

&AtClient
Procedure CertificatesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	Next(Undefined);
	
EndProcedure

&AtClient
Procedure CertificatesOnActivateRow(Item)
	
	If Items.Certificates.CurrentData = Undefined Then
		SelectedCertificateImprint = "";
	Else
		SelectedCertificateImprint = Items.Certificates.CurrentData.Imprint;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Refresh(Command)
	
	UpdateCertificatesList();
	
EndProcedure

&AtClient
Procedure ShowDataCurrentCertificate(Command)
	
	CurrentData = Items.Certificates.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DigitalSignatureClient.OpenCertificate(CurrentData.Imprint, Not CurrentData.ThisRequest);
	
EndProcedure

&AtClient
Procedure Next(Command)
	
	If Items.Certificates.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en='Select the certificates to be added.';ru='Выделите сертификаты, которые требуется добавить.'"));
		Return;
	EndIf;
	
	CurrentData = Items.Certificates.CurrentData;
	
	If CurrentData.ThisRequest Then
		ShowMessageBox(,
			NStr("en='For this certificate a statement for issue is not yet executed."
"Open the statement for the certificate issue and perform the required steps.';ru='Для этого сертификата заявление на выпуск еще не исполнено."
"Откройте заявление на выпуск сертификата и выполните требуемые шаги.'"));
		UpdateCertificatesList();
		Return;
	EndIf;
	
	DigitalSignatureServiceClient.GetCertificateByImprint(New NotifyDescription(
		"NextAfterCertificateSearch", ThisObject), CurrentData.Imprint, False, Undefined);
	
EndProcedure

// Continue the procedure Next.
&AtClient
Procedure NextAfterCertificateSearch(Result, NotSpecified) Export
	
	If TypeOf(Result) = Type("CryptoCertificate") Then
		Result.BeginUnloading(New NotifyDescription(
			"NextAfterCertificateExport", ThisObject, Result));
		Return;
	EndIf;
	
	Context = New Structure;
	
	If Result.Property("CertificateNotFound") Then
		Context.Insert("ErrorDescription", NStr("en='Certificate is not found on the computer (may be deleted).';ru='Сертификат не найден на компьютере (возможно удален).'"));
	Else
		Context.Insert("ErrorDescription", Result.ErrorDescription);
	EndIf;
	
	UpdateCertificatesList(New NotifyDescription(
		"NextAfterCertificatesListUpdate", ThisObject, Context));
	
	
EndProcedure

// Continue the procedure Next.
&AtClient
Procedure NextAfterCertificateExport(ExportedData, CryptoCertificate) Export
	
	ShowPageCertificatePropertiesAdjustment(ThisObject, CryptoCertificate, ExportedData);
	
EndProcedure

// Continue the procedure Next.
&AtClient
Procedure NextAfterCertificatesListUpdate(Result, Context) Export
	
	ShowMessageBox(, Context.ErrorDescription);
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	Items.Pages.CurrentPage = Items.PageCertificateChoice;
	Items.Next.DefaultButton = True;
	
	UpdateCertificatesList();
	
EndProcedure

&AtClient
Procedure Add(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	If Not ValueIsFilled(Certificate) Then
		AdditionalParameters.Insert("IsNew");
	EndIf;
	
	WriteCertificateToCatalog();
	
	NotifyChanged(Certificate);
	Notify("Record_DigitalSignaturesAndEncryptionKeyCertificates",
		AdditionalParameters, Certificate);
	
	NotifyChoice(Certificate);
	
EndProcedure

&AtClient
Procedure ShowCertificateData(Command)
	
	If ValueIsFilled(CertificateAddress) Then
		DigitalSignatureClient.OpenCertificate(CertificateAddress, True);
	Else
		DigitalSignatureClient.OpenCertificate(CertificateThumbprint, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClientAtServerNoContext
Procedure ShowPageCertificatePropertiesAdjustment(Form, CryptoCertificate, CertificateData)
	
	Items = Form.Items;
	
	Form.CertificateAddress = PutToTempStorage(CertificateData, Form.UUID);
	
	Form.CertificateThumbprint = Base64String(CryptoCertificate.Imprint);
	
	DigitalSignatureClientServer.FillCertificateDataDescription(
		Form.CertificateDataDescription, CryptoCertificate);
	
	SavedProperties = CerfiticateSavedProperties(
		Form.CertificateThumbprint,
		Form.CertificateAddress,
		Form.CertificateAttributesParameters);
	
	If Form.CertificateAttributesParameters.Property("Description") Then
		If Form.CertificateAttributesParameters.Description.ReadOnly Then
			Items.CertificateName.ReadOnly = True;
		EndIf;
	EndIf;
	
	Form.Certificate             = SavedProperties.Ref;
	Form.CertificateName = SavedProperties.Description;
	Form.CertificateUser = SavedProperties.User;
	Form.CertificateCompany  = SavedProperties.Company;
	
	Items.Pages.CurrentPage  = Items.PageRefinementCertificateProperties;
	Items.Add.DefaultButton = True;
	
	String = ?(ValueIsFilled(Form.Certificate), NStr("en='Refresh';ru='Обновить календарь'"), NStr("en='Add';ru='Добавить'"));
	If Items.Add.Title <> String Then
		Items.Add.Title = String;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CerfiticateSavedProperties(Val Imprint, Address, AttributesParameters)
	
	Return DigitalSignatureService.CerfiticateSavedProperties(Imprint, Address, AttributesParameters, True);
	
EndFunction

&AtClient
Procedure UpdateCertificatesList(Notification = Undefined)
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	
	DigitalSignatureServiceClient.GetCertificatesPropertiesOnClient(New NotifyDescription(
		"UpdateCertificatesListContinue", ThisObject, Context), False, ShowAll);
	
EndProcedure

// Continue the procedure UpdateCertificatesList.
&AtClient
Procedure UpdateCertificatesListContinue(Result, Context) Export
	
	ErrorReceivingCertificatesOnClient = Result.ErrorReceivingCertificatesOnClient;
	
	UpdateCertificatesListOnServer(Result.CertificatesPropertiesOnClient);
	
	If Context.Notification <> Undefined Then
		ExecuteNotifyProcessing(Context.Notification);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateCertificatesListOnServer(Val CertificatesPropertiesOnClient)
	
	ErrorReceivingCertificatesAtServer = New Structure;
	
	DigitalSignatureService.UpdateCertificatesList(Certificates, CertificatesPropertiesOnClient,
		True, False, ErrorReceivingCertificatesAtServer, ShowAll);
	
	If ValueIsFilled(SelectedCertificateImprint)
	   AND (    Items.Certificates.CurrentRow = Undefined
	      Or Certificates.FindByID(Items.Certificates.CurrentRow) = Undefined
	      Or Certificates.FindByID(Items.Certificates.CurrentRow).Imprint
	              <> SelectedCertificateImprint) Then
		
		Filter = New Structure("Imprint", SelectedCertificateImprint);
		Rows = Certificates.FindRows(Filter);
		If Rows.Count() > 0 Then
			Items.Certificates.CurrentRow = Rows[0].GetID();
		EndIf;
	EndIf;
	
	Items.GroupCertificatesNotAvailableOnClient.Visible =
		ValueIsFilled(ErrorReceivingCertificatesOnClient);
	
	Items.GroupCertificatesNotAvailableAtServer.Visible =
		ValueIsFilled(ErrorReceivingCertificatesAtServer);
	
EndProcedure

&AtServer
Procedure WriteCertificateToCatalog()
	
	DigitalSignatureService.WriteCertificateToCatalog(ThisObject, , True);
	
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
