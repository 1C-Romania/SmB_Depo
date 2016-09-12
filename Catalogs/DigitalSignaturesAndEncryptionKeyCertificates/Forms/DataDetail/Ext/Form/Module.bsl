&AtClient
Var InternalData, PasswordProperties, DataDescription, ObjectForm, ProcessingAfterWarning, CurrentPresentationsList;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	DigitalSignatureService.ConfigureSigningEncryptionDecryptionForm(ThisObject, , True);
	
	EnableRememberPassword = Parameters.EnableRememberPassword;
	ItIsAuthentication = Parameters.ItIsAuthentication;
	
	If ItIsAuthentication Then
		Items.FormDrillDown.Title = NStr("en='OK';ru='Ок'");
		Items.ExplanationEnhancedPassword.Title = NStr("en='Click OK to proceed to enter the password.';ru='Нажмите ОК, чтобы перейти к вводу пароля.'");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If InternalData = Undefined Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Record_DigitalSignaturesAndEncryptionKeyCertificates") Then
		AttachIdleHandler("OnChangeCertificatesList", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DataPresentationClick(Item, StandardProcessing)
	
	DigitalSignatureServiceClient.DataPresentationClick(ThisObject,
		Item, StandardProcessing, CurrentPresentationsList);
	
EndProcedure

&AtClient
Procedure CertificateOnChange(Item)
	
	DigitalSignatureServiceClient.GetCertificatePrintsAtClient(
		New NotifyDescription("CertificateOnChangeEnd", ThisObject));
	
EndProcedure

// Continue the procedure CertificateOnChange.
&AtClient
Procedure CertificateOnChangeEnd(CertificateThumbprintsAtClient, Context) Export
	
	CertificateOnChangeAtServer(CertificateThumbprintsAtClient);
	
	DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject, InternalData, PasswordProperties);
	
EndProcedure

&AtClient
Procedure CertificateStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If FilterCertificates.Count() > 0 Then
		DigitalSignatureServiceClient.StartSelectingCertificateWhenFilterIsSet(ThisObject);
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("SelectedCertificate", Certificate);
	FormParameters.Insert("ForEncryptionAndDecryption", True);
	FormParameters.Insert("ReturnPassword", True);
	
	DigitalSignatureServiceClient.CertificateChoiceForSigningOrDecoding(FormParameters, Item);
	
EndProcedure

&AtClient
Procedure CertificateOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	If ValueIsFilled(Certificate) Then
		DigitalSignatureClient.OpenCertificate(Certificate);
	EndIf;
	
EndProcedure

&AtClient
Procedure CertificateChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If ValueSelected = True Then
		Certificate = InternalData["SelectedCertificate"];
		InternalData.Delete("SelectedCertificate");
		
	ElsIf ValueSelected = False Then
		Certificate = Undefined;
		
	ElsIf TypeOf(ValueSelected) = Type("String") Then
		FormParameters = New Structure;
		FormParameters.Insert("SelectedCertificateImprint", ValueSelected);
		FormParameters.Insert("ForEncryptionAndDecryption", True);
		FormParameters.Insert("ReturnPassword", True);
		
		DigitalSignatureServiceClient.CertificateChoiceForSigningOrDecoding(FormParameters, Item);
		Return;
	Else
		Certificate = ValueSelected;
	EndIf;
	
	DigitalSignatureServiceClient.GetCertificatePrintsAtClient(
		New NotifyDescription("CertificateChoiceProcessingEnd", ThisObject, ValueSelected));
	
EndProcedure

// Continue the procedure CertificateChoiceProcessing.
&AtClient
Procedure CertificateChoiceProcessingEnd(CertificateThumbprintsAtClient, ValueSelected) Export
	
	CertificateOnChangeAtServer(CertificateThumbprintsAtClient);
	
	If ValueSelected = True
	   AND InternalData["SelectedCertificatePassword"] <> Undefined Then
		
		DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject,
			InternalData, PasswordProperties,, InternalData["SelectedCertificatePassword"]);
		InternalData.Delete("SelectedCertificatePassword");
		Items.RememberPassword.ReadOnly = False;
	Else
		DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject, InternalData, PasswordProperties);
	EndIf;
	
EndProcedure

&AtClient
Procedure CertificateAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	DigitalSignatureServiceClient.CertificatePickFromChoiceList(ThisObject, Text, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure CertificateTextEntryEnd(Item, Text, ChoiceData, Parameters, StandardProcessing)
	
	DigitalSignatureServiceClient.CertificatePickFromChoiceList(ThisObject, Text, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure PasswordOnChange(Item)
	
	DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, New Structure("WhenChangingAttributePassword", True));
	
	If Not EnableRememberPassword
	   AND Not RememberPassword
	   AND Not PasswordProperties.PasswordChecked Then
		
		Items.RememberPassword.ReadOnly = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure RememberPasswordOnChange(Item)
	
	DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, New Structure("WhenChangingAttributeRememberPassword", True));
	
	If Not EnableRememberPassword
	   AND Not RememberPassword
	   AND Not PasswordProperties.PasswordChecked Then
		
		Items.RememberPassword.ReadOnly = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExplanationSetPasswordClick(Item)
	
	DigitalSignatureServiceClient.ExplanationSetPasswordClick(ThisObject, Item, PasswordProperties);
	
EndProcedure

&AtClient
Procedure ExplanationSetPasswordExtendedTooltipNavigationRefDataProcessor(Item, URL, StandardProcessing)
	
	DigitalSignatureServiceClient.SetPasswordExplanationNavigationRefProcessing(
		ThisObject, Item, URL, StandardProcessing, PasswordProperties);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Decrypt(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	DecryptData(New NotifyDescription("DecryptEnd", ThisObject));
	
EndProcedure

// Continue the procedure Decrypt.
&AtClient
Procedure DecryptEnd(Result, Context) Export
	
	If Result = True Then
		Close(True);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ContinueOpen(Notification, CommonInternalData, ClientParameters) Export
	
	If ClientParameters = InternalData Then
		ClientParameters = New Structure("Certificate, PasswordProperties", Certificate, PasswordProperties);
		Return;
	EndIf;
	
	If ClientParameters.Property("OtherOperationContextIsSpecified") Then
		CertificateProperties = CommonInternalData;
		ClientParameters.DataDescription.OperationContext.ContinueOpen(,, CertificateProperties);
		If CertificateProperties.Certificate = Certificate Then
			PasswordProperties = CertificateProperties.PasswordProperties;
		EndIf;
	EndIf;
	
	DataDescription             = ClientParameters.DataDescription;
	ObjectForm               = ClientParameters.Form;
	CurrentPresentationsList = ClientParameters.CurrentPresentationsList;
	
	InternalData = CommonInternalData;
	Context = New Structure("Notification", Notification);
	Notification = New NotifyDescription("ContinueOpen", ThisObject);
	
	DigitalSignatureServiceClient.ContinueOpenBeginning(New NotifyDescription(
		"ContinueOpeningAfterStart", ThisObject, Context), ThisObject, ClientParameters,, True);
	
EndProcedure

// Continue the procedure ContinueOpening.
&AtClient
Procedure ContinueOpeningAfterStart(Result, Context) Export
	
	If Result <> True Then
		ExecuteNotifyProcessing(Context.Notification);
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	If PasswordProperties <> Undefined Then
		AdditionalParameters.Insert("WhenInstallingPasswordFromOtherOperation", True);
	EndIf;
	DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, AdditionalParameters);
	
	If Not EnableRememberPassword
	   AND Not RememberPassword
	   AND Not PasswordProperties.PasswordChecked Then
		
		Items.RememberPassword.ReadOnly = True;
	EndIf;
	
	If WithoutConfirmation
	   AND (    AdditionalParameters.PasswordSpecified
	      Or AdditionalParameters.EnhancedProtectionPrivateKey) Then
	
		ProcessingAfterWarning = Undefined;
		DecryptData(New NotifyDescription("ContinueOpeningAfterDataDetail", ThisObject, Context));
		Return;
	EndIf;
	
	Open();
	
	ExecuteNotifyProcessing(Context.Notification);
	
EndProcedure

// Continue the procedure ContinueOpening.
&AtClient
Procedure ContinueOpeningAfterDataDetail(Result, Context) Export
	
	If Result = True Then
		ExecuteNotifyProcessing(Context.Notification, True);
	Else
		ExecuteNotifyProcessing(Context.Notification);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteDecryption(ClientParameters, CompletionProcessing) Export
	
	DigitalSignatureServiceClient.UpdateFormBeforeUsingAgain(ThisObject, ClientParameters);
	
	DataDescription             = ClientParameters.DataDescription;
	ObjectForm               = ClientParameters.Form;
	CurrentPresentationsList = ClientParameters.CurrentPresentationsList;
	
	ProcessingAfterWarning = CompletionProcessing;
	ContinuationProcessor = New NotifyDescription("ExecuteDecryption", ThisObject);
	
	Context = New Structure("CompletionProcessing", CompletionProcessing);
	DecryptData(New NotifyDescription("ExecuteDecryptionEnd", ThisObject, Context));
	
EndProcedure

// Continue the procedure ExecuteDecryption.
&AtClient
Procedure ExecuteDecryptionEnd(Result, Context) Export
	
	If Result = True Then
		ExecuteNotifyProcessing(Context.CompletionProcessing, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeCertificatesList()
	
	DigitalSignatureServiceClient.GetCertificatePrintsAtClient(
		New NotifyDescription("OnChangeCertificatesListEnd", ThisObject));
	
EndProcedure

// Continue the procedure OnChangeCertificatesList.
&AtClient
Procedure OnChangeCertificatesListEnd(CertificateThumbprintsAtClient, Context) Export
	
	CertificateOnChangeAtServer(CertificateThumbprintsAtClient, True);
	
	DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, New Structure("WhenChangingCertificateProperties", True));
	
EndProcedure

&AtServer
Procedure CertificateOnChangeAtServer(CertificateThumbprintsAtClient, CheckLink = False)
	
	If CheckLink
	   AND ValueIsFilled(Certificate)
	   AND CommonUse.ObjectAttributeValue(Certificate, "Ref") <> Certificate Then
		
		Certificate = Undefined;
	EndIf;
	
	DigitalSignatureService.CertificateOnChangeAtServer(ThisObject, CertificateThumbprintsAtClient,, True);
	
EndProcedure

&AtClient
Procedure DecryptData(Notification)
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("ErrorOnClient", New Structure);
	Context.Insert("ErrorOnServer", New Structure);
	
	If Not ValueIsFilled(CertificateApplication) Then
		Context.ErrorOnClient.Insert("ErrorDescription",
			NStr("en='Selected certificate has no indicated application for a closed key."
"Select the certificate again from the"
"full list or open the certificate and specify the application manually.';ru='У выбранного сертификата не указана программа для закрытого ключа."
"Выберите сертификат повторно"
"из полного списка или откройте сертификат и укажите программу вручную.'"));
		ShowError(Context.ErrorOnClient, Context.ErrorOnServer);
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	SelectedCertificate = New Structure;
	SelectedCertificate.Insert("Ref",    Certificate);
	SelectedCertificate.Insert("Imprint", CertificateThumbprint);
	SelectedCertificate.Insert("Data",    CertificateAddress);
	DataDescription.Insert("SelectedCertificate", SelectedCertificate);
	
	If DataDescription.Property("BeforeExecution")
	   AND TypeOf(DataDescription.BeforeExecution) = Type("NotifyDescription") Then
		
		ExecuteParameters = New Structure;
		ExecuteParameters.Insert("DataDescription", DataDescription);
		ExecuteParameters.Insert("Notification", New NotifyDescription(
			"DecryptDataAfterProcessingBeforeExecution", ThisObject, Context));
		
		ExecuteNotifyProcessing(DataDescription.BeforeExecution, ExecuteParameters);
	Else
		DecryptDataAfterProcessingBeforeExecution(New Structure, Context);
	EndIf;
	
EndProcedure

// Continue the procedure DecryptData.
&AtClient
Procedure DecryptDataAfterProcessingBeforeExecution(Result, Context) Export
	
	If Result.Property("ErrorDescription") Then
		ShowError(New Structure("ErrorDescription", Result.ErrorDescription), New Structure);
		Return;
	EndIf;
	
	Context.Insert("FormID", UUID);
	If TypeOf(ObjectForm) = Type("ManagedForm") Then
		Context.FormID = ObjectForm.UUID;
	ElsIf TypeOf(ObjectForm) = Type("UUID") Then
		Context.FormID = ObjectForm;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("DataDescription",     DataDescription);
	ExecuteParameters.Insert("Form",              ThisObject);
	ExecuteParameters.Insert("FormID", Context.FormID);
	ExecuteParameters.Insert("PasswordValue",     PasswordProperties.Value);
	Context.Insert("ExecuteParameters", ExecuteParameters);
	
	If DigitalSignatureClientServer.CommonSettings().CreateDigitalSignaturesAtServer Then
		If ValueIsFilled(CertificateAtServerErrorDescription) Then
			Result = New Structure("Error", CertificateAtServerErrorDescription);
			CertificateAtServerErrorDescription = New Structure;
			DecryptDataAfterExecutionOnServerSide(Result, Context);
		Else
			// Attempt to encrypt on server.
			DigitalSignatureServiceClient.ExecuteOnSide(New NotifyDescription(
					"DecryptDataAfterExecutionOnServerSide", ThisObject, Context),
				"Details", "OnServerSide", Context.ExecuteParameters);
		EndIf;
	Else
		DecryptDataAfterExecutionOnServerSide(Undefined, Context);
	EndIf;
	
	
EndProcedure

// Continue the procedure DecryptData.
&AtClient
Procedure DecryptDataAfterExecutionOnServerSide(Result, Context) Export
	
	If Result <> Undefined Then
		DecryptDataAfterExecution(Result);
	EndIf;
	
	If Result <> Undefined AND Not Result.Property("Error") Then
		DecryptDataAfterExecutionOnClientSide(New Structure, Context);
	Else
		If Result <> Undefined Then
			Context.ErrorOnServer = Result.Error;
		EndIf;
		
		// Attempt to sign at client.
		DigitalSignatureServiceClient.ExecuteOnSide(New NotifyDescription(
				"DecryptDataAfterExecutionOnClientSide", ThisObject, Context),
			"Details", "OnClientSide", Context.ExecuteParameters);
	EndIf;
	
EndProcedure

// Continue the procedure DecryptData.
&AtClient
Procedure DecryptDataAfterExecutionOnClientSide(Result, Context) Export
	
	DecryptDataAfterExecution(Result);
	
	If Result.Property("Error") Then
		Context.ErrorOnClient = Result.Error;
		ShowError(Context.ErrorOnClient, Context.ErrorOnServer);
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	If Not WriteEncryptionCertificates(Context.FormID, Context.ErrorOnClient) Then
		ShowError(Context.ErrorOnClient, Context.ErrorOnServer);
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	If Not ItIsAuthentication
	   AND ValueIsFilled(DataPresentation)
	   AND (NOT DataDescription.Property("NotifyAboutCompletion")
	      Or DataDescription.NotifyAboutCompletion <> False) Then
		
		DigitalSignatureClient.InformAboutObjectDecryption(
			DigitalSignatureServiceClient.FullDataPresentation(ThisObject),
			CurrentPresentationsList.Count() > 1);
	EndIf;
	
	If DataDescription.Property("OperationContext") Then
		DataDescription.OperationContext = ThisObject;
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, True);
	
EndProcedure

// Continue the procedure DecryptData.
&AtClient
Procedure DecryptDataAfterExecution(Result)
	
	If Result.Property("OperationBegan") Then
		DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject, InternalData,
			PasswordProperties, New Structure("WhenOperationIsSuccessful", True));
	EndIf;
	
EndProcedure

&AtClient
Function WriteEncryptionCertificates(FormID, Error)
	
	ObjectsDescription = New Array;
	If DataDescription.Property("Data") Then
		AddObjectDescription(ObjectsDescription, DataDescription);
	Else
		For Each DataItem IN DataDescription.DataSet Do
			AddObjectDescription(ObjectsDescription, DataDescription);
		EndDo;
	EndIf;
	
	Error = New Structure;
	WriteEncryptionCertificatesAtServer(ObjectsDescription, FormID, Error);
	
	Return Not ValueIsFilled(Error);
	
EndFunction

&AtClient
Procedure AddObjectDescription(ObjectsDescription, DataItem)
	
	If Not DataItem.Property("Object") Then
		Return;
	EndIf;
	
	ObjectVersioning = Undefined;
	DataItem.Property("ObjectVersioning", ObjectVersioning);
	
	ObjectDescription = New Structure;
	ObjectDescription.Insert("Ref", DataItem.Object);
	ObjectDescription.Insert("Version", ObjectVersioning);
	
	ObjectsDescription.Add(ObjectDescription);
	
EndProcedure

&AtServerNoContext
Procedure WriteEncryptionCertificatesAtServer(ObjectsDescription, FormID, Error)
	
	EncryptionCertificates = New Array;
	
	BeginTransaction();
	Try
		For Each ObjectDescription IN ObjectsDescription Do
			DigitalSignature.WriteEncryptionCertificates(ObjectDescription.Ref,
				EncryptionCertificates, FormID, ObjectDescription.Version);
		EndDo;
		CommitTransaction();
	Except
		ErrorInfo = ErrorInfo();
		RollbackTransaction();
		Error.Insert("ErrorDescription", NStr("en='When clearing the encryption certificates, an error occurred:';ru='При очистке сертификатов шифрования возникла ошибка:'")
			+ Chars.LF + BriefErrorDescription(ErrorInfo));
	EndTry;
	
EndProcedure


&AtClient
Procedure ShowError(ErrorOnClient, ErrorOnServer)
	
	If Not IsOpen() AND ProcessingAfterWarning = Undefined Then
		Open();
	EndIf;
	
	DigitalSignatureServiceClient.ShowRequestToApplicationError(
		NStr("en='Failed to decrypt the data';ru='Не удалось расшифровать данные'"), "",
		ErrorOnClient, ErrorOnServer, , ProcessingAfterWarning);
	
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
