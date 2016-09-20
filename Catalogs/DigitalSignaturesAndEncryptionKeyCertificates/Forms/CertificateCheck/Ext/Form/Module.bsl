&AtClient
Var InternalData, ClientParameters, PasswordProperties;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Certificate        = Parameters.Certificate;
	CheckOnSelection = Parameters.CheckOnSelection;
	
	If ValueIsFilled(Parameters.FormTitle) Then
		AutoTitle = False;
		Title = Parameters.FormTitle;
	EndIf;
	
	If CheckOnSelection Then
		Items.FormCheck.Title = NStr("en='Check and continue';ru='Проверить и продолжить'");
		Items.FormClose.Title   = NStr("en='Cancel';ru='Отменить'");
	EndIf;
	
	Checks = New ValueTable;
	Checks.Columns.Add("Name",           New TypeDescription("String"));
	Checks.Columns.Add("Presentation", New TypeDescription("String"));
	Checks.Columns.Add("ToolTip",     New TypeDescription("String"));
	
	DigitalSignatureOverridable.OnCreatingFormCertificateCheck(Parameters.Certificate,
		Checks, Parameters.AdditionalChecksParameters);
	
	For Each Checking IN Checks Do
		Group = Items.Add("Group" + Checking.Name, Type("FormGroup"), Items.GroupAdditionalChecks);
		Group.Type = FormGroupType.UsualGroup;
		Group.Group = ChildFormItemsGroup.Horizontal;
		Group.ShowTitle = False;
		Group.Representation = UsualGroupRepresentation.None;
		
		Picture = Items.Add(Checking.Name + "OnClientPicture", Type("FormDecoration"), Group);
		Picture.Type = FormDecorationType.Picture;
		Picture.Picture = New Picture;
		Picture.PictureSize = PictureSize.AutoSize;
		Picture.Width = 3;
		Picture.Height = 1;
		Picture.Hyperlink = True;
		Picture.SetAction("Click", "PictureClick");
		
		Picture = Items.Add(Checking.Name + "OnServerPicture", Type("FormDecoration"), Group);
		Picture.Type = FormDecorationType.Picture;
		Picture.Picture = New Picture;
		Picture.PictureSize = PictureSize.AutoSize;
		Picture.Width = 3;
		Picture.Height = 1;
		Picture.Hyperlink = True;
		Picture.SetAction("Click", "PictureClick");
		
		Label = Items.Add(Checking.Name + "Label", Type("FormDecoration"), Group);
		Label.Title = Checking.Presentation;
		Label.ToolTipRepresentation = ToolTipRepresentation.Button;
		Label.ExtendedTooltip.Title = Checking.ToolTip;
		
		AdditionalChecks.Add(Checking.Name);
	EndDo;
	
	
	CertificateProperties = CommonUse.ObjectAttributesValues(Certificate,
		"CertificateData, Application, EnhancedProtectionPrivateKey");
	
	Application = CertificateProperties.Application;
	CertificateAddress = PutToTempStorage(CertificateProperties.CertificateData.Get(), UUID);
	CertificateEnhancedProtectionPrivateKey = CertificateProperties.EnhancedProtectionPrivateKey;
	
	RefreshVisibleAtServer();
	
	If Items.GroupLegalCertificate.Visible Then
		FirstCheckName = "LegitimateCertificate";
	Else
		FirstCheckName = "CertificateAvailability";
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
	
	// On change of usage settings.
	If Upper(EventName) <> Upper("Record_ConstantsSet") Then
		Return;
	EndIf;
	
	If Upper(Source) = Upper("VerifyDigitalSignaturesAtServer")
	 Or Upper(Source) = Upper("CreateDigitalSignaturesAtServer") Then
		
		AttachIdleHandler("OnChangeSigningOrEncryptionUsage", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure PictureClick(Item)
	
	If ValueIsFilled(Item.ToolTip) Then
		ShowMessageBox(, Item.ToolTip);
	EndIf;
	
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
Procedure Validate(Command)
	
	CheckCertificate(New NotifyDescription("CheckEnd", ThisObject));
	
EndProcedure

// Continue the Check procedure.
&AtClient
Procedure CheckEnd(NOTSpecified, Context) Export
	
	If Not CheckOnSelection Then
		Return;
	EndIf;
	
	If ClientParameters.Result.ChecksCompleted Then
		Close(True);
	Else
		ShowAlertOnFailureToContinue();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ContinueOpen(Notification, CommonInternalData, IncomingClientParameters) Export
	
	InternalData = CommonInternalData;
	ClientParameters = IncomingClientParameters;
	ClientParameters.Insert("Result");
	ContinuationProcessor = New NotifyDescription("ContinueOpen", ThisObject);
	
	AdditionalParameters = New Structure;
	DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, AdditionalParameters);
	
	If Not Items.Password.Enabled Then
		CurrentItem = Items.FormCheck;
	EndIf;
	
	If ClientParameters.Property("WithoutConfirmation")
	   AND ClientParameters.WithoutConfirmation
	   AND (    AdditionalParameters.PasswordSpecified
	      Or AdditionalParameters.EnhancedProtectionPrivateKey) Then
	
		
		If Not ClientParameters.Property("ResultProcessing")
		 Or TypeOf(ClientParameters.ResultProcessing) <> Type("NotifyDescription") Then
			Open();
		EndIf;
		
		Context = New Structure("Notification", Notification);
		CheckCertificate(New NotifyDescription("ContinueOpeningAfterCertificateCheck", ThisObject, Context));
		Return;
	EndIf;
	
	Open();
	
	ExecuteNotifyProcessing(Notification);
	
EndProcedure

// Continue the procedure ContinueOpening.
&AtClient
Procedure ContinueOpeningAfterCertificateCheck(Result, Context) Export
	
	If ClientParameters.Result.ChecksCompleted Then
		ExecuteNotifyProcessing(Context.Notification, True);
		Return;
	EndIf;
	
	If Not IsOpen() Then
		Open();
	EndIf;
	
	If CheckOnSelection Then
		ShowAlertOnFailureToContinue();
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification);
	
EndProcedure

&AtClient
Procedure OnChangeSigningOrEncryptionUsage()
	
	RefreshVisibleAtServer()
	
EndProcedure

&AtServer
Procedure RefreshVisibleAtServer()
	
	CheckOnServer = DigitalSignatureClientServer.CommonSettings().VerifyDigitalSignaturesAtServer;
	CreateOnServer = DigitalSignatureClientServer.CommonSettings().CreateDigitalSignaturesAtServer;
	
	OperationsOnServer = CheckOnServer Or CreateOnServer;
	
	Items.OnServerPicture.Visible                   = OperationsOnServer;
	Items.LegalCertificateOnServerPicture.Visible = OperationsOnServer;
	Items.CertificateExistenceOnServerPicture.Visible = OperationsOnServer;
	Items.CertificateDataOnServerPicture.Visible  = OperationsOnServer;
	Items.ApplicationExistenceOnServerPicture.Visible   = OperationsOnServer;
	Items.SigningOnServerPicture.Visible         = OperationsOnServer;
	Items.SignatureCheckOnServerPicture.Visible    = OperationsOnServer;
	Items.EncryptionOnServerPicture.Visible         = OperationsOnServer;
	Items.DecryptionOnServerPicture.Visible        = OperationsOnServer;
	
	For Each ItemOfList IN AdditionalChecks Do
		Items[ItemOfList.Value + "OnServerPicture"].Visible = OperationsOnServer;
	EndDo;
	
EndProcedure

&AtClient
Procedure ShowAlertOnFailureToContinue()
	
	ShowMessageBox(,
		NStr("en='Failed to continue as not all required checks are completed.';ru='Не удалось продолжить, т.к. пройдены не все требуемые проверки.'"));
	
EndProcedure

&AtClient
Procedure CheckCertificate(Notification)
	
	PasswordAccepted = False;
	ChecksOnClient = New Structure;
	ChecksOnServer = New Structure;
	
	// Clearance of previous validation results.
	MainChecks = New Structure(
		"LegitimateCertificate, CertificateAvailability,
		|CertificateData, ApplicationAvailability, Signing, SignatureCheck, Encryption, Decryption");
	
	For Each KeyAndValue IN MainChecks Do
		SetItem(ThisObject, KeyAndValue.Key, False);
		SetItem(ThisObject, KeyAndValue.Key, True);
	EndDo;
	
	For Each ItemOfList IN AdditionalChecks Do
		SetItem(ThisObject, ItemOfList.Value, False);
		SetItem(ThisObject, ItemOfList.Value, True);
	EndDo;
	
	Context = New Structure("Notification", Notification);
	
	CheckOnClientSide(New NotifyDescription(
		"CheckCertificateAfterCheckOnClient", ThisObject, Context));
	
EndProcedure

// Continue the procedure CheckCertificate.
&AtClient
Procedure CheckCertificateAfterCheckOnClient(Result, Context) Export
	
	If OperationsOnServer Then
		CheckOnServerSide(PasswordProperties.Value);
	Else
		ChecksOnServer = Undefined;
	EndIf;
	
	If PasswordAccepted Then
		DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject,
			InternalData, PasswordProperties, New Structure("WhenOperationIsSuccessful", True));
	EndIf;
	
	Result = New Structure;
	Result.Insert("ChecksCompleted", False);
	Result.Insert("ChecksOnClient", ChecksOnClient);
	Result.Insert("ChecksOnServer", ChecksOnServer);
	
	ClientParameters.Insert("Result", Result);
	
	If ClientParameters.Property("ResultProcessing")
	   AND TypeOf(ClientParameters.ResultProcessing) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(ClientParameters.ResultProcessing, Result.ChecksCompleted);
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification);
	
EndProcedure


&AtClient
Procedure CheckOnClientSide(Notification)
	
	Context = New Structure("Notification", Notification);
	
	BeginAttachingCryptoExtension(New NotifyDescription(
		"CheckOnClientSideAfterConnectingCryptographyExtension", ThisObject, Context));
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterConnectingCryptographyExtension(Attached, Context) Export
	
	If Not Attached Then
		DigitalSignatureClient.CreateCryptoManager(New NotifyDescription(
				"CheckOnClientSideAfterAttemptToCreateCryptographyManager", ThisObject, Context),
			"CertificateCheck", False);
		Return;
	EndIf;
	
	// Certificate data validation.
	Context.Insert("CertificateData", GetFromTempStorage(CertificateAddress));
	
	CryptoCertificate = New CryptoCertificate;
	CryptoCertificate.BeginInitialization(New NotifyDescription(
			"CheckOnClientSideAfterCertificateInitialization", ThisObject, Context,
			"CheckOnClientSideAfterCertificateInitializationError", ThisObject),
		Context.CertificateData);
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterAttemptToCreateCryptographyManager(Result, Context) Export
	
	SetItem(ThisObject, FirstCheckName, False, Result, False);
	ExecuteNotifyProcessing(Context.Notification);
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterCertificateInitializationError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	ErrorDescription = BriefErrorDescription(ErrorInfo);
	SetItem(ThisObject, FirstCheckName, False, ErrorDescription, True);
	
	ExecuteNotifyProcessing(Context.Notification);
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterCertificateInitialization(CryptoCertificate, Context) Export
	
	Context.Insert("CryptoCertificate", CryptoCertificate);
	
	// Legitimate certificate
	If Context.CryptoCertificate.Subject.Property("SN") Then
		ErrorDescription = "";
	Else
		ErrorDescription = NStr("en='In the description of the subject of the certificate field ""SN"" is not found.';ru='В описании субъекта сертификата не найдено поле ""SN"".'");
	EndIf;
	SetItem(ThisObject, "LegitimateCertificate", False, ErrorDescription);
	
	// Certificate availability in personal list.
	DigitalSignatureServiceClient.GetCertificateByImprint(New NotifyDescription(
			"CheckOnClientSideAfterCertificateSearch", ThisObject, Context),
		Base64String(Context.CryptoCertificate.Imprint), True, Undefined);
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterCertificateSearch(Result, Context) Export
	
	If TypeOf(Result) <> Type("CryptoCertificate") Then
		ErrorDescription = Result.ErrorDescription + Chars.LF + Chars.LF
			+ NStr("en='Signing, the created signature and decryption can not be checked.';ru='Проверка подписания, созданной подписи и расшифровки не могут быть выполнены.'");
	Else
		ErrorDescription = "";
	EndIf;
	SetItem(ThisObject, "CertificateAvailability", False, ErrorDescription);
	
	// Certificate data validation.
	DigitalSignatureClient.CreateCryptoManager(New NotifyDescription(
			"CheckOnClientSideAfterCreatingAnyCryptographyManager", ThisObject, Context),
		"CertificateCheck", False);
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterCreatingAnyCryptographyManager(Result, Context) Export
	
	If TypeOf(Result) = Type("CryptoManager") Then
		DigitalSignatureClient.CheckCertificate(New NotifyDescription(
				"CheckOnClientSideAfterCertificateCheck", ThisObject, Context),
			Context.CryptoCertificate, Result);
	Else
		CheckOnClientSideAfterCertificateCheck(Result, Context)
	EndIf;
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterCertificateCheck(Result, Context) Export
	
	If Result = True Then
		ErrorDescription = "";
	Else
		ErrorDescription = Result;
	EndIf;
	SetItem(ThisObject, "CertificateData", False, ErrorDescription, True);
	
	// Application availability
	If ValueIsFilled(Application) Then
		DigitalSignatureClient.CreateCryptoManager(New NotifyDescription(
				"CheckOnClientSideAfterCreatingCryptographyManager", ThisObject, Context),
			"CertificateCheck", False, Application);
	Else
		ErrorDescription = NStr("en='Application for private key use is not indicated in a certificate.';ru='Программа для использования закрытого ключа не указана в сертификате.'");
		CheckOnClientSideAfterCreatingCryptographyManager(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterCreatingCryptographyManager(Result, Context) Export
	
	Context.Insert("CryptoManager", Undefined);
	
	If TypeOf(Result) = Type("CryptoManager") Then
		Context.CryptoManager = Result;
		ErrorDescription = "";
	Else
		ErrorDescription = Result + Chars.LF + Chars.LF
			+ NStr("en='Signing, the created signature, encryption
		|and decryption can not be checked.';ru='Проверка подписания, созданной
		|подписи, шифрования и расшифровки не могут быть выполнены.'");
	EndIf;
	SetItem(ThisObject, "ApplicationAvailability", False, ErrorDescription, True);
	
	If Context.CryptoManager = Undefined Then
		ExecuteNotifyProcessing(Context.Notification);
		Return;
	EndIf;
	
	Context.CryptoManager.PrivateKeyAccessPassword = PasswordProperties.Value;
	
	// Signing.
	If ChecksOnClient.CertificateAvailability Then
		Context.CryptoManager.StartSigning(New NotifyDescription(
				"CheckOnClientSideAfterSigning", ThisObject, Context,
				"CheckOnClientSideAfterSigningError", ThisObject),
			Context.CertificateData, Context.CryptoCertificate);
	Else
		CheckOnClientSideAfterSigning(Null, Context);
	EndIf;
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterSigningError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	CheckOnClientSideAfterSigning(BriefErrorDescription(ErrorInfo), Context);
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterSigning(SignatureData, Context) Export
	
	If SignatureData <> Null Then
		If TypeOf(SignatureData) = Type("String") Then
			ErrorDescription = SignatureData;
		Else
			ErrorDescription = "";
			DigitalSignatureServiceClientServer.EmptySignatureData(SignatureData, ErrorDescription);
		EndIf;
		If Not ValueIsFilled(ErrorDescription) Then
			PasswordAccepted = True;
		EndIf;
		SetItem(ThisObject, "Signing", False, ErrorDescription, True);
	EndIf;
	
	// Signature checkup.
	If ChecksOnClient.CertificateAvailability AND Not ValueIsFilled(ErrorDescription) Then
		Context.CryptoManager.StartCheckingSignature(New NotifyDescription(
				"CheckOnClientSideAfterSignatureCheck", ThisObject, Context,
				"CheckOnClientSideAfterSignatureCheckError", ThisObject),
			Context.CertificateData, SignatureData);
	Else
		CheckOnClientSideAfterSignatureCheck(Null, Context);
	EndIf;
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterSignatureCheckError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	CheckOnClientSideAfterSignatureCheck(BriefErrorDescription(ErrorInfo), Context);
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterSignatureCheck(Certificate, Context) Export
	
	If Certificate <> Null Then
		If TypeOf(Certificate) = Type("String") Then
			ErrorDescription = Certificate;
		Else
			ErrorDescription = "";
		EndIf;
		SetItem(ThisObject, "SignatureCheck", False, ErrorDescription, True);
	EndIf;
	
	// Encryption.
	Context.CryptoManager.StartEncryption(New NotifyDescription(
			"CheckOnClientSideAfterEncryption", ThisObject, Context,
			"CheckOnClientSideAfterEncryptionError", ThisObject),
		Context.CertificateData, Context.CryptoCertificate);
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterEncryptionError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	CheckOnClientSideAfterEncryption(BriefErrorDescription(ErrorInfo), Context);
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterEncryption(EncryptedData, Context) Export
	
	If TypeOf(EncryptedData) = Type("String") Then
		ErrorDescription = EncryptedData;
	Else
		ErrorDescription = "";
	EndIf;
	SetItem(ThisObject, "Encryption", False, ErrorDescription, True);
	
	// Decryption.
	If ChecksOnClient.CertificateAvailability AND Not ValueIsFilled(ErrorDescription) Then
		Context.CryptoManager.StartDecryption(New NotifyDescription(
				"CheckOnClientSideAfterDecryption", ThisObject, Context,
				"CheckOnClientSideAfterDecryptionError", ThisObject),
			EncryptedData);
	Else
		CheckOnClientSideAfterDecryption(Null, Context);
	EndIf;
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterDecryptionError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	CheckOnClientSideAfterDecryption(BriefErrorDescription(ErrorInfo), Context);
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterDecryption(DecryptedData, Context) Export
	
	If DecryptedData <> Null Then
		If TypeOf(DecryptedData) = Type("String") Then
			ErrorDescription = DecryptedData;
		Else
			ErrorDescription = "";
		EndIf;
		DigitalSignatureServiceClientServer.EmptyDecryptedData(DecryptedData, ErrorDescription);
		SetItem(ThisObject, "Details", False, ErrorDescription, True);
	EndIf;
	
	// Additional checks.
	Context.Insert("IndexOf", -1);
	
	CheckOnClientSideCycleBeginning(Context);
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideCycleBeginning(Context)
	
	If AdditionalChecks.Count() <= Context.IndexOf + 1 Then
		ExecuteNotifyProcessing(Context.Notification);
		Return;
	EndIf;
	Context.IndexOf = Context.IndexOf + 1;
	Context.Insert("ItemOfList", AdditionalChecks[Context.IndexOf]);
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("Certificate",           Certificate);
	ExecuteParameters.Insert("Checking",             Context.ItemOfList.Value);
	ExecuteParameters.Insert("CryptoManager", Context.CryptoManager);
	ExecuteParameters.Insert("ErrorDescription",       "");
	ExecuteParameters.Insert("IsWarning",    False);
	ExecuteParameters.Insert("WaitContinuation",   False);
	ExecuteParameters.Insert("Notification",           New NotifyDescription(
		"CheckOnClientSideAfterAdditionalCheck", ThisObject, Context));
	
	Context.Insert("ExecuteParameters", ExecuteParameters);
	
	Try
		DigitalSignatureOverridableClient.OnAdditionalCertificateVerification(ExecuteParameters);
	Except
		ErrorInfo = ErrorInfo();
		ExecuteParameters.WaitContinuation = False;
		ExecuteParameters.ErrorDescription = BriefErrorDescription(ErrorInfo);
	EndTry;
	
	If ExecuteParameters.WaitContinuation <> True Then
		CheckOnClientSideAfterAdditionalCheck(, Context);
	EndIf;
	
EndProcedure

// Continue the procedure CheckOnClientSide.
&AtClient
Procedure CheckOnClientSideAfterAdditionalCheck(NOTSpecified, Context) Export
	
	SetItem(ThisObject, Context.ItemOfList.Value, False,
		Context.ExecuteParameters.ErrorDescription,
		Context.ExecuteParameters.IsWarning <> True);
	
	CheckOnClientSideCycleBeginning(Context);
	
EndProcedure


&AtServer
Procedure CheckOnServerSide(Val PasswordValue)
	
	CertificateData = GetFromTempStorage(CertificateAddress);
	
	Try
		CryptoCertificate = New CryptoCertificate(CertificateData);
		ErrorDescription = "";
	Except
		ErrorInfo = ErrorInfo();
		ErrorDescription = BriefErrorDescription(ErrorInfo);
	EndTry;
	
	If ValueIsFilled(ErrorDescription) Then
		SetItem(ThisObject, FirstCheckName, True, ErrorDescription, True);
		Return;
	EndIf;
	
	// Legitimate certificate
	If CryptoCertificate.Subject.Property("SN") Then
		ErrorDescription = "";
	Else
		ErrorDescription = NStr("en='In the description of the subject of the certificate field ""SN"" is not found.';ru='В описании субъекта сертификата не найдено поле ""SN"".'");
	EndIf;
	SetItem(ThisObject, "LegitimateCertificate", True, ErrorDescription);
	
	// Certificate availability in personal list.
	Result = New Structure;
	DigitalSignatureService.GetCertificateByImprint(Base64String(CryptoCertificate.Imprint),
		True, False, , Result);
	If ValueIsFilled(Result) Then
		ErrorDescription = Result.ErrorDescription + Chars.LF + Chars.LF
			+ NStr("en='Signing, the created signature and decryption can not be checked.';ru='Проверка подписания, созданной подписи и расшифровки не могут быть выполнены.'");
	Else
		ErrorDescription = "";
	EndIf;
	SetItem(ThisObject, "CertificateAvailability", True, ErrorDescription);
	
	// Certificate data validation.
	ErrorDescription = "";
	CryptoManager = DigitalSignatureService.CryptoManager("CertificateCheck",
		False, ErrorDescription);
	
	If Not ValueIsFilled(ErrorDescription) Then
		DigitalSignature.CheckCertificate(CryptoManager, CryptoCertificate, ErrorDescription);
	EndIf;
	SetItem(ThisObject, "CertificateData", True, ErrorDescription, True);
	
	// Application availability
	If ValueIsFilled(Application) Then
		ErrorDescription = "";
		CryptoManager = DigitalSignatureService.CryptoManager("",
			False, ErrorDescription, Application);
	Else
		CryptoManager = Undefined;
		ErrorDescription = NStr("en='Application for private key use is not indicated in a certificate.';ru='Программа для использования закрытого ключа не указана в сертификате.'");
	EndIf;
	If ValueIsFilled(ErrorDescription) Then
		ErrorDescription = ErrorDescription + Chars.LF + Chars.LF
			+ NStr("en='Signing, the created signature, encryption
		|and decryption can not be checked.';ru='Проверка подписания, созданной
		|подписи, шифрования и расшифровки не могут быть выполнены.'");
	EndIf;
	SetItem(ThisObject, "ApplicationAvailability", True, ErrorDescription, True);
	
	If CryptoManager = Undefined Then
		Return;
	EndIf;
	
	CryptoManager.PrivateKeyAccessPassword = PasswordValue;
	
	// Signing.
	If ChecksOnServer.CertificateAvailability Then
		ErrorDescription = "";
		Try
			SignatureData = CryptoManager.Sign(CertificateData, CryptoCertificate);
			DigitalSignatureServiceClientServer.EmptySignatureData(SignatureData, ErrorDescription);
		Except
			ErrorInfo = ErrorInfo();
			ErrorDescription = BriefErrorDescription(ErrorInfo);
		EndTry;
		If Not ValueIsFilled(ErrorDescription) Then
			PasswordAccepted = True;
		EndIf;
		SetItem(ThisObject, "Signing", True, ErrorDescription, True);
	EndIf;
	
	// Signature checkup.
	If ChecksOnServer.CertificateAvailability AND Not ValueIsFilled(ErrorDescription) Then
		ErrorDescription = "";
		Try
			CryptoManager.VerifySignature(CertificateData, SignatureData);
		Except
			ErrorInfo = ErrorInfo();
			ErrorDescription = BriefErrorDescription(ErrorInfo);
		EndTry;
		SetItem(ThisObject, "SignatureCheck", True, ErrorDescription, True);
	EndIf;
	
	// Encryption.
	ErrorDescription = "";
	Try
		EncryptedData = CryptoManager.Encrypt(CertificateData, CryptoCertificate);
	Except
		ErrorInfo = ErrorInfo();
		ErrorDescription = BriefErrorDescription(ErrorInfo);
	EndTry;
	SetItem(ThisObject, "Encryption", True, ErrorDescription, True);
	
	// Decryption.
	If ChecksOnServer.CertificateAvailability AND Not ValueIsFilled(ErrorDescription) Then
		ErrorDescription = "";
		Try
			DecryptedData = CryptoManager.Decrypt(EncryptedData);
			DigitalSignatureServiceClientServer.EmptyDecryptedData(DecryptedData, ErrorDescription);
		Except
			ErrorInfo = ErrorInfo();
			ErrorDescription = BriefErrorDescription(ErrorInfo);
		EndTry;
		SetItem(ThisObject, "Details", True, ErrorDescription, True);
	EndIf;
	
	// Additional checks.
	For Each ItemOfList IN AdditionalChecks Do
		ErrorDescription = "";
		IsWarning = False;
		Try
			DigitalSignatureOverridable.OnAdditionalCertificateVerification(Certificate,
				ItemOfList.Value, CryptoManager, ErrorDescription, IsWarning);
		Except
			ErrorInfo = ErrorInfo();
			ErrorDescription = BriefErrorDescription(ErrorInfo);
		EndTry;
		SetItem(ThisObject, ItemOfList.Value, True, ErrorDescription, IsWarning <> True);
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetItem(Form, StartElement, AtServer, ErrorDescription = Undefined, IsError = False)
	
	ItemPicture = Form.Items[StartElement + ?(AtServer, "AtServer", "AtClient") + "Picture"];
	Checks = Form["Checks" + ?(AtServer, "AtServer", "AtClient")];
	
	Try
		Value = ItemPicture.Picture;
	Except
		Form.SetItemThroughServer(StartElement, AtServer, ErrorDescription, IsError);
		Return;
	EndTry;
	
	If ErrorDescription = Undefined Then
		ItemPicture.Picture    = New Picture;
		ItemPicture.ToolTip   = NStr("en='Check was not performed.';ru='Проверка не выполнялась.'");
		Checks.Insert(StartElement, Undefined);
		
	ElsIf ValueIsFilled(ErrorDescription) Then
		ItemPicture.Picture    = ?(IsError, PictureLib.Error32, PictureLib.Warning32);
		ItemPicture.ToolTip   = ErrorDescription;
		Checks.Insert(StartElement, False);
	Else
		ItemPicture.Picture    = PictureLib.Successfully32;
		ItemPicture.ToolTip   = NStr("en='The validation is completed successfully.';ru='Проверка выполнена успешно.'");;
		Checks.Insert(StartElement, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetItemThroughServer(StartElement, AtServer, ErrorDescription, IsError)
	
	SetItem(ThisObject, StartElement, AtServer, ErrorDescription, IsError);
	
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
