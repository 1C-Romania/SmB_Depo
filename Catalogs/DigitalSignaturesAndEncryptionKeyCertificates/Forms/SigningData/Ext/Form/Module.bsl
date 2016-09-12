&AtClient
Var InternalData, PasswordProperties, DataDescription, ObjectForm, ProcessingAfterWarning, CurrentPresentationsList;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	DigitalSignatureService.ConfigureSigningEncryptionDecryptionForm(ThisObject);
	
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
	FormParameters.Insert("ForEncryptionAndDecryption", False);
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
	
EndProcedure

&AtClient
Procedure RememberPasswordOnChange(Item)
	
	DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, New Structure("WhenChangingAttributeRememberPassword", True));
	
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
Procedure Sign(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	SignData(New NotifyDescription("SignEnding", ThisObject));
	
EndProcedure

// Continue the procedure Sign.
&AtClient
Procedure SignEnding(Result, Context) Export
	
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
		"ContinueOpeningAfterStart", ThisObject, Context), ThisObject, ClientParameters);
	
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
	
	If WithoutConfirmation
	   AND (    AdditionalParameters.PasswordSpecified
	      Or AdditionalParameters.EnhancedProtectionPrivateKey) Then
		
		ProcessingAfterWarning = Undefined;
		SignData(New NotifyDescription("ContinueOpeningAfterDataSignature", ThisObject, Context));
		Return;
	EndIf;
	
	Open();
	
	ExecuteNotifyProcessing(Context.Notification);
	
EndProcedure

// Continue the procedure ContinueOpening.
&AtClient
Procedure ContinueOpeningAfterDataSignature(Result, Context) Export
	
	If Result = True Then
		ExecuteNotifyProcessing(Context.Notification, True);
	Else
		ExecuteNotifyProcessing(Context.Notification);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteSigning(ClientParameters, CompletionProcessing) Export
	
	DigitalSignatureServiceClient.UpdateFormBeforeUsingAgain(ThisObject, ClientParameters);
	
	DataDescription             = ClientParameters.DataDescription;
	ObjectForm               = ClientParameters.Form;
	CurrentPresentationsList = ClientParameters.CurrentPresentationsList;
	
	ProcessingAfterWarning = CompletionProcessing;
	ContinuationProcessor = New NotifyDescription("ExecuteSigning", ThisObject);
	
	Context = New Structure("CompletionProcessing", CompletionProcessing);
	SignData(New NotifyDescription("ExecuteSigningEnd", ThisObject, Context));
	
EndProcedure

// Continue the procedure ExecuteSigning.
&AtClient
Procedure ExecuteSigningEnd(Result, Context) Export
	
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
	
	DigitalSignatureService.CertificateOnChangeAtServer(ThisObject, CertificateThumbprintsAtClient);
	
EndProcedure

&AtClient
Procedure SignData(Notification)
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("ErrorOnClient", New Structure);
	Context.Insert("ErrorOnServer", New Structure);
	
	If CertificateValidUntil < CommonUseClient.SessionDate() Then
		Context.ErrorOnClient.Insert("ErrorDescription",
			NStr("en='Selected certificate has expired."
"Select another certificate.';ru='У выбранного сертификата истек срок действия."
"Выберите другой сертификат.'"));
		ShowError(Context.ErrorOnClient, Context.ErrorOnServer);
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	If Not ValueIsFilled(CertificateApplication) Then
		Context.ErrorOnClient.Insert("ErrorDescription",
			NStr("en='Selected certificate has no indicated application for a closed key."
"Select another certificate.';ru='У выбранного сертификата не указана программа для закрытого ключа."
"Выберите другой сертификат.'"));
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
			"SignDataAfterProcessingBeforeExecution", ThisObject, Context));
		
		ExecuteNotifyProcessing(DataDescription.BeforeExecution, ExecuteParameters);
	Else
		SignDataAfterProcessingBeforeExecution(New Structure, Context);
	EndIf;
	
EndProcedure

// Continue the procedure SignData.
&AtClient
Procedure SignDataAfterProcessingBeforeExecution(Result, Context) Export
	
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
			SignDataAfterExecutionOnServerSide(Result, Context);
		Else
			// Attempt to sign on server.
			DigitalSignatureServiceClient.ExecuteOnSide(New NotifyDescription(
					"SignDataAfterExecutionOnServerSide", ThisObject, Context),
				"Signing", "OnServerSide", Context.ExecuteParameters);
		EndIf;
	Else
		SignDataAfterExecutionOnServerSide(Undefined, Context);
	EndIf;
	
EndProcedure

// Continue the procedure SignData.
&AtClient
Procedure SignDataAfterExecutionOnServerSide(Result, Context) Export
	
	If Result <> Undefined Then
		SignDataAfterExecution(Result);
	EndIf;
	
	If Result <> Undefined AND Not Result.Property("Error") Then
		SignDataAfterExecutionOnClientSide(New Structure, Context);
	Else
		If Result <> Undefined Then
			Context.ErrorOnServer = Result.Error;
		EndIf;
		
		// Attempt to sign at client.
		DigitalSignatureServiceClient.ExecuteOnSide(New NotifyDescription(
				"SignDataAfterExecutionOnClientSide", ThisObject, Context),
			"Signing", "OnClientSide", Context.ExecuteParameters);
	EndIf;
	
EndProcedure

// Continue the procedure SignData.
&AtClient
Procedure SignDataAfterExecutionOnClientSide(Result, Context) Export
	
	SignDataAfterExecution(Result);
	
	If Result.Property("Error") Then
		Context.ErrorOnClient = Result.Error;
		ShowError(Context.ErrorOnClient, Context.ErrorOnServer);
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	If ValueIsFilled(DataPresentation)
	   AND (NOT DataDescription.Property("NotifyAboutCompletion")
	      Or DataDescription.NotifyAboutCompletion <> False) Then
		
		DigitalSignatureClient.InformAboutSigningAnObject(
			DigitalSignatureServiceClient.FullDataPresentation(ThisObject),
			CurrentPresentationsList.Count() > 1);
	EndIf;
	
	If DataDescription.Property("OperationContext") Then
		DataDescription.OperationContext = ThisObject;
	EndIf;
	
	If NotifyAboutExpiration Then
		FormParameters = New Structure("Certificate", Certificate);
		OpenForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.UpcomingExpirationDateNotification",
			FormParameters);
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, True);
	
EndProcedure

// Continue the procedure SignData.
&AtClient
Procedure SignDataAfterExecution(Result)
	
	If Result.Property("OperationBegan") Then
		DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject, InternalData,
			PasswordProperties, New Structure("WhenOperationIsSuccessful", True));
	EndIf;
	
	If Result.Property("ThereAreProcessedDataItems") Then
		// After signature of a certificate has
		// started, it is impossible to change it, otherwise the data set will be processed differently.
		Items.Certificate.ReadOnly = True;
		Items.Comment.ReadOnly = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowError(ErrorOnClient, ErrorOnServer)
	
	If Not IsOpen() AND ProcessingAfterWarning = Undefined Then
		Open();
	EndIf;
	
	DigitalSignatureServiceClient.ShowRequestToApplicationError(
		NStr("en='Failed to sign data';ru='Не удалось подписать данные'"), "",
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
