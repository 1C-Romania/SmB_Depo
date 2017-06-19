&AtClient
Var InternalData, PasswordProperties;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.InsertIntoList Then
		InsertIntoList = True;
		Items.Select.Title = NStr("en='Add';ru='Добавить'");
		
		Items.ExplanationEnhancedPassword.Title =
			NStr("en='Click Add to go to password entry.';ru='Нажмите Добавить, чтобы перейти к вводу пароля.'");
		
		PersonalListOnAdd = Parameters.PersonalListOnAdd;
		Items.ShowAll.ToolTip =
			NStr("en='Show all certificates without filter (for example including the added and expired ones)';ru='Показать все сертификаты без отбора (например, включая добавленные и просроченные)'");
	EndIf;
	
	ForEncryptionAndDecryption = Parameters.ForEncryptionAndDecryption;
	ReturnPassword = Parameters.ReturnPassword;
	
	If ForEncryptionAndDecryption = True Then
		If Parameters.InsertIntoList Then
			Title = NStr("en='Addition of a certificate for data encryption and decryption';ru='Добавление сертификата для шифрования и расшифровки данных'");
		Else
			Title = NStr("en='Select certificate for data encryption and decryption';ru='Выбор сертификата для шифрования и расшифровки данных'");
		EndIf;
	ElsIf ForEncryptionAndDecryption = False Then
		If Parameters.InsertIntoList Then
			Title = NStr("en='Addition of a certificate for data signing';ru='Добавление сертификата для подписания данных'");
		EndIf;
	ElsIf DigitalSignature.UseEncryption() Then
		Title = NStr("en='Addition of a certificate for signing and encrypting data';ru='Добавление сертификата для подписания и шифрования данных'");
	Else
		Title = NStr("en='Addition of a certificate for data signing';ru='Добавление сертификата для подписания данных'");
	EndIf;
	
	CreateDigitalSignaturesAtServer = DigitalSignatureClientServer.CommonSettings(
		).CreateDigitalSignaturesAtServer;
	
	If CreateDigitalSignaturesAtServer Then
		Items.GroupCertificates.Title =
			NStr("en='Personal certificates on computer and server';ru='Личные сертификаты на компьютере и сервере'");
	EndIf;
	
	AreCompanies = Not Metadata.DefinedTypes.Company.Type.ContainsType(Type("String"));
	Items.CertificateCompany.Visible = AreCompanies;
	
	Items.CertificateUser.ToolTip =
		Metadata.Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.Attributes.User.ToolTip;
	
	Items.CertificateCompany.ToolTip =
		Metadata.Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.Attributes.Company.ToolTip;
	
	
	If ValueIsFilled(Parameters.SelectedCertificateImprint) Then
		SelectedCertificateImprintNotFound = False;
		SelectedCertificateImprint = Parameters.SelectedCertificateImprint;
	Else
		SelectedCertificateImprint = CommonUse.ObjectAttributeValue(
			Parameters.SelectedCertificate, "Imprint");
	EndIf;
	
	ErrorReceivingCertificatesOnClient = Parameters.ErrorReceivingCertificatesOnClient;
	UpdateCertificatesListOnServer(Parameters.CertificatesPropertiesOnClient);
	
	If ValueIsFilled(Parameters.SelectedCertificateImprint)
	   AND Parameters.SelectedCertificateImprint <> SelectedCertificateImprint Then
		
		SelectedCertificateImprintNotFound = True;
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
	
	If Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionApplications")
	 Or Upper(EventName) = Upper("Write_PathsToDigitalSignatureAndEncryptionFilesAtServersLinux") Then
		
		RefreshReusableValues();
		UpdateCertificatesList();
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
		
	// Company completion check.
	If Items.CertificateCompany.Visible
	   AND Not Items.CertificateCompany.ReadOnly
	   AND Items.CertificateCompany.AutoMarkIncomplete = True
	   AND Not ValueIsFilled(CertificateCompany) Then
		
		MessageText = NStr("en='Field Company is not filled.';ru='Поле Организация не заполнено.'");
		CommonUseClientServer.MessageToUser(MessageText,, "CertificateCompany",, Cancel);
	EndIf;
	
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

&AtClient
Procedure CertificateEnhancedProtectionPrivateKeyOnChange(Item)
	
	DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, New Structure("WhenChangingCertificateProperties", True));
	
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
	
	GoToCurrentCertificateChoice(New NotifyDescription(
		"NextAfterTransitionToCurrentCertificateChoice", ThisObject));
	
EndProcedure

// Continue the procedure Next.
&AtClient
Procedure NextAfterTransitionToCurrentCertificateChoice(Result, Context) Export
	
	If Result = True Then
		Return;
	EndIf;
	
	Context = Result;
	
	If Context.UpdateCertificatesList Then
		UpdateCertificatesList(New NotifyDescription(
			"NextAfterCertificatesListUpdate", ThisObject, Context));
	Else
		NextAfterCertificatesListUpdate(, Context);
	EndIf;
	
EndProcedure

// Continue the procedure Next.
&AtClient
Procedure NextAfterCertificatesListUpdate(Result, Context) Export
	
	ShowMessageBox(, Context.ErrorDescription);
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	Items.MainPages.CurrentPage = Items.PageCertificateChoice;
	Items.Next.DefaultButton = True;
	
	UpdateCertificatesList();
	
EndProcedure

&AtClient
Procedure Select(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("ErrorOnServer", New Structure);
	Context.Insert("ErrorOnClient", New Structure);
	
	CertificateRecorded = False;
	
	If CertificateAtServer
	   AND CheckCertificateAndWriteInCatalog(PasswordProperties.Value, Context.ErrorOnServer) Then
		
		SelectAfterCertificateCheck(Context.ErrorOnClient, Context);
	Else
		CheckCertificate(New NotifyDescription("SelectAfterCertificateCheck", ThisObject, Context));
	EndIf;
	
EndProcedure

// Continue the procedure Select.
&AtClient
Procedure SelectAfterCertificateCheck(Result, Context) Export
	
	If Result.Property("Application") Then
		WriteCertificateToCatalog(Result.Application);
	EndIf;
	
	If Result.Property("ErrorDescription") Then
		ErrorOnClient = Result;
		
		If ForEncryptionAndDecryption = True Then
			FormTitle = NStr("en='Encryption and decryption check';ru='Проверка шифрования и расшифровки'");
		Else
			FormTitle = NStr("en='Validation of digital signature setting';ru='Проверка установки электронной подписи'");
		EndIf;
		DigitalSignatureServiceClient.ShowRequestToApplicationError(
			FormTitle, "", ErrorOnClient, Context.ErrorOnServer);
		
		Return;
	EndIf;
	
	DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, New Structure("WhenOperationIsSuccessful", True));
	
	NotifyChanged(Certificate);
	
	If ReturnPassword Then
		InternalData.Insert("SelectedCertificate", Certificate);
		If Not RememberPassword Then
			InternalData.Insert("SelectedCertificatePassword", PasswordProperties.Value);
		EndIf;
		NotifyChoice(True);
	Else
		NotifyChoice(Certificate);
	EndIf;
	
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

&AtClient
Procedure ContinueOpen(Notification, CommonInternalData) Export
	
	InternalData = CommonInternalData;
	ContinuationProcessor = New NotifyDescription("ContinueOpen", ThisObject);
	DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject, InternalData, PasswordProperties);
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	
	If SelectedCertificateImprintNotFound = Undefined
	 Or SelectedCertificateImprintNotFound = True Then
		
		ContinueOpeningAfterTransitionToCurrentCertificateChoice(, Context);
	Else
		GoToCurrentCertificateChoice(New NotifyDescription(
			"ContinueOpeningAfterTransitionToCurrentCertificateChoice", ThisObject, Context));
	EndIf;
	
EndProcedure

// Continue the procedure ContinueOpening.
&AtClient
Procedure ContinueOpeningAfterTransitionToCurrentCertificateChoice(Result, Context) Export
	
	If TypeOf(Result) = Type("Structure") Then
		NotifyChoice(False);
	Else
		Open();
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification);
	
EndProcedure

&AtServer
Function FillInCurrentCertificatePropertiesOnServer(Val Imprint, SavedProperties);
	
	CryptoCertificate = DigitalSignatureService.GetCertificateByImprint(Imprint, False);
	If CryptoCertificate = Undefined Then
		Return False;
	EndIf;
	
	CertificateAddress = PutToTempStorage(CryptoCertificate.Unload(),
		UUID);
	
	CertificateThumbprint = Imprint;
	
	DigitalSignatureClientServer.FillCertificateDataDescription(CertificateDataDescription,
		CryptoCertificate);
	
	SavedProperties = CerfiticateSavedProperties(Imprint,
		CertificateAddress, CertificateAttributesParameters);
	
	Return True;
	
EndFunction

&AtServerNoContext
Function CerfiticateSavedProperties(Val Imprint, Val Address, AttributesParameters)
	
	Return DigitalSignatureService.CerfiticateSavedProperties(Imprint, Address, AttributesParameters);
	
EndFunction

&AtClient
Procedure UpdateCertificatesList(Notification = Undefined)
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	
	DigitalSignatureServiceClient.GetCertificatesPropertiesOnClient(New NotifyDescription(
		"UpdateCertificatesListContinue", ThisObject, Context), True, ShowAll);
	
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
		InsertIntoList, True, ErrorReceivingCertificatesAtServer, ShowAll);
	
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
	
	If Items.Certificates.CurrentRow = Undefined Then
		SelectedCertificateImprint = "";
	Else
		String = Certificates.FindByID(Items.Certificates.CurrentRow);
		SelectedCertificateImprint = ?(String = Undefined, "", String.Imprint);
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToCurrentCertificateChoice(Notification)
	
	Result = New Structure;
	Result.Insert("ErrorDescription", "");
	Result.Insert("UpdateCertificatesList", False);
	
	If Items.Certificates.CurrentData = Undefined Then
		Result.ErrorDescription = NStr("en='Select the certificate that will be used.';ru='Выделите сертификат, который будет использоваться.'");
		ExecuteNotifyProcessing(Notification, Result);
		Return;
	EndIf;
	
	CurrentData = Items.Certificates.CurrentData;
	
	If CurrentData.ThisRequest Then
		Result.UpdateCertificatesList = True;
		Result.ErrorDescription =
			NStr("en='For this certificate a statement for issue is not yet executed.
		|Open the statement for the certificate issue and perform the required steps.';ru='Для этого сертификата заявление на выпуск еще не исполнено.
		|Откройте заявление на выпуск сертификата и выполните требуемые шаги.'");
		ExecuteNotifyProcessing(Notification, Result);
		Return;
	EndIf;
	
	CertificateOnClient = CurrentData.AtClient;
	CertificateAtServer = CurrentData.AtServer;
	
	Context = New Structure;
	Context.Insert("Notification",          Notification);
	Context.Insert("Result",           Result);
	Context.Insert("CurrentData",       CurrentData);
	Context.Insert("SavedProperties", Undefined);
	
	If CertificateAtServer Then
		If FillInCurrentCertificatePropertiesOnServer(CurrentData.Imprint, Context.SavedProperties) Then
			GoToCurrentCertificateChoiceAfterFillingCertificateProperties(Context);
		Else
			Result.ErrorDescription = NStr("en='Certificate is not found on server (may be deleted).';ru='Сертификат не найден на сервере (возможно удален).'");
			Result.UpdateCertificatesList = True;
			ExecuteNotifyProcessing(Notification, Result);
		EndIf;
		Return;
	EndIf;
	
	// CertificateOnClient.
	DigitalSignatureServiceClient.GetCertificateByImprint(
		New NotifyDescription("GoToCurrentCertificateChoiceAfterCertificateSearch", ThisObject, Context),
		CurrentData.Imprint, False, Undefined);
	
EndProcedure

// Continue the procedure GoToCurrentCertificateChoice.
&AtClient
Procedure GoToCurrentCertificateChoiceAfterCertificateSearch(SearchResult, Context) Export
	
	If TypeOf(SearchResult) <> Type("CryptoCertificate") Then
		If SearchResult.Property("CertificateNotFound") Then
			Context.Result.ErrorDescription = NStr("en='Certificate is not found on the computer (may be deleted).';ru='Сертификат не найден на компьютере (возможно удален).'");
		Else
			Context.Result.ErrorDescription = SearchResult.ErrorDescription;
		EndIf;
		Context.Result.UpdateCertificatesList = True;
		ExecuteNotifyProcessing(Context.Notification, Context.Result);
		Return;
	EndIf;
	
	Context.Insert("CryptoCertificate", SearchResult);
	
	Context.CryptoCertificate.BeginUnloading(New NotifyDescription(
		"GoToCurrentCertificateChoiceAfterCertificateExport", ThisObject, Context));
	
EndProcedure

// Continue the procedure GoToCurrentCertificateChoice.
&AtClient
Procedure GoToCurrentCertificateChoiceAfterCertificateExport(ExportedData, Context) Export
	
	CertificateAddress = PutToTempStorage(ExportedData, UUID);
	
	CertificateThumbprint = Context.CurrentData.Imprint;
	
	DigitalSignatureClientServer.FillCertificateDataDescription(CertificateDataDescription,
		Context.CryptoCertificate);
	
	Context.SavedProperties = CerfiticateSavedProperties(Context.CurrentData.Imprint,
		CertificateAddress, CertificateAttributesParameters);
	
	GoToCurrentCertificateChoiceAfterFillingCertificateProperties(Context);
	
EndProcedure

// Continue the procedure GoToCurrentCertificateChoice.
&AtClient
Procedure GoToCurrentCertificateChoiceAfterFillingCertificateProperties(Context)
	
	If CertificateAttributesParameters.Property("Description") Then
		If CertificateAttributesParameters.Description.ReadOnly Then
			Items.CertificateName.ReadOnly = True;
		EndIf;
	EndIf;
	
	If AreCompanies Then
		If CertificateAttributesParameters.Property("Company") Then
			If Not CertificateAttributesParameters.Company.Visible Then
				Items.CertificateCompany.Visible = False;
			ElsIf CertificateAttributesParameters.Company.ReadOnly Then
				Items.CertificateCompany.ReadOnly = True;
			ElsIf CertificateAttributesParameters.Company.FillChecking Then
				Items.CertificateCompany.AutoMarkIncomplete = True;
			EndIf;
		EndIf;
	EndIf;
	
	If CertificateAttributesParameters.Property("EnhancedProtectionPrivateKey") Then
		If Not CertificateAttributesParameters.EnhancedProtectionPrivateKey.Visible Then
			Items.CertificateEnhancedProtectionPrivateKey.Visible = False;
		ElsIf CertificateAttributesParameters.EnhancedProtectionPrivateKey.ReadOnly Then
			Items.CertificateEnhancedProtectionPrivateKey.ReadOnly = True;
		EndIf;
	EndIf;
	
	Certificate             = Context.SavedProperties.Ref;
	CertificateUser = Context.SavedProperties.User;
	CertificateCompany  = Context.SavedProperties.Company;
	CertificateName = Context.SavedProperties.Description;
	CertificateEnhancedProtectionPrivateKey = Context.SavedProperties.EnhancedProtectionPrivateKey;
	
	DigitalSignatureServiceClient.ProcessPasswordInForm(ThisObject, InternalData, PasswordProperties);
	
	Items.MainPages.CurrentPage = Items.PageRefinementCertificateProperties;
	Items.Select.DefaultButton = True;
	
	If InsertIntoList Then
		String = ?(ValueIsFilled(Certificate), NStr("en='Refresh';ru='Обновить календарь'"), NStr("en='Add';ru='Добавить'"));
		If Items.Select.Title <> String Then
			Items.Select.Title = String;
		EndIf;
	EndIf;
	
	AttachIdleHandler("WaitHandlerActivateItemPassword", 0.1, True);
	
	ExecuteNotifyProcessing(Context.Notification, True);
	
EndProcedure

&AtClient
Procedure WaitHandlerActivateItemPassword()
	
	CurrentItem = Items.Password;
	
EndProcedure


&AtClient
Procedure CheckCertificate(Notification)
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	
	DigitalSignatureServiceClient.CreateCryptoManager(New NotifyDescription(
		"CheckCertificateAfterCreatingCryptographyManager", ThisObject, Context), "", Undefined);
	
EndProcedure

// Continue the procedure CheckCertificate.
&AtClient
Procedure CheckCertificateAfterCreatingCryptographyManager(Result, Context) Export
	
	If TypeOf(Result) <> Type("CryptoManager")
	   AND Result.Common Then
		
		If ForEncryptionAndDecryption = True Then
			Result.Insert("ErrorTitle", NStr("en='Failed to pass the encryption check for the following reason:';ru='Не удалось пройти проверку шифрования по причине:'"));
		Else
			Result.Insert("ErrorTitle", NStr("en='Failed to pass the signing check for the following reason:';ru='Не удалось пройти проверку подписания по причине:'"));
		EndIf;
		ExecuteNotifyProcessing(Parameters.Notification, Result);
		Return;
	EndIf;
	
	Context.Insert("CertificateBinaryData", GetFromTempStorage(CertificateAddress));
	
	CryptoCertificate = New CryptoCertificate;
	CryptoCertificate.BeginInitialization(New NotifyDescription(
			"CheckCertificateAfterCertificateInitialization", ThisObject, Context),
		Context.CertificateBinaryData);
	
EndProcedure

// Continue the procedure CheckCertificate.
&AtClient
Procedure CheckCertificateAfterCertificateInitialization(CryptoCertificate, Context) Export
	
	Context.Insert("CryptoCertificate", CryptoCertificate);
	
	Context.Insert("ErrorDescription", "");
	Context.Insert("ErrorOnClient", New Structure);
	
	Context.ErrorOnClient.Insert("ErrorDescription", "");
	Context.ErrorOnClient.Insert("Errors", New Array);
	
	Context.Insert("ApplicationsDescription", DigitalSignatureClientServer.CommonSettings().ApplicationsDescription);
	Context.Insert("IndexOf", -1);
	
	CheckCertificateCycleBeginning(Context);
	
EndProcedure

// Continue the procedure CheckCertificate.
&AtClient
Procedure CheckCertificateCycleBeginning(Context)
	
	If Context.ApplicationsDescription.Count() <= Context.IndexOf + 1 Then
		Context.ErrorOnClient.Insert("ErrorDescription", TrimAll(Context.ErrorDescription));
		ExecuteNotifyProcessing(Context.Notification, Context.ErrorOnClient);
		Return;
	EndIf;
	Context.IndexOf = Context.IndexOf + 1;
	Context.Insert("ApplicationDescription", Context.ApplicationsDescription[Context.IndexOf]);
	
	DigitalSignatureServiceClient.CreateCryptoManager(New NotifyDescription(
			"CheckCertificateCycleAfterCreatingCryptographyManager", ThisObject, Context),
		"", Undefined, Context.ApplicationDescription.Ref);
	
EndProcedure

// Continue the procedure CheckCertificate.
&AtClient
Procedure CheckCertificateCycleAfterCreatingCryptographyManager(Result, Context) Export
	
	If TypeOf(Result) <> Type("CryptoManager") Then
		If Result.Errors.Count() > 0 Then
			Context.ErrorOnClient.Errors.Add(Result.Errors[0]);
		EndIf;
		CheckCertificateCycleBeginning(Context);
		Return;
	EndIf;
	Context.Insert("CryptoManager", Result);
	
	Context.CryptoManager.PrivateKeyAccessPassword = PasswordProperties.Value;
	
	If ForEncryptionAndDecryption = True Then
		Context.CryptoManager.StartEncryption(New NotifyDescription(
				"CheckCertificateCycleAfterEncryption", ThisObject, Context,
				"CheckCertificateCycleAfterEncryptionError", ThisObject),
			Context.CertificateBinaryData, Context.CryptoCertificate);
	Else
		Context.CryptoManager.StartSigning(New NotifyDescription(
				"CheckCertificateCycleAfterSigning", ThisObject, Context,
				"CheckCertificateCycleAfterSigningError", ThisObject),
			Context.CertificateBinaryData, Context.CryptoCertificate);
	EndIf;
	
EndProcedure

// Continue the procedure CheckCertificate.
&AtClient
Procedure CheckCertificateCycleAfterSigningError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	FillSignatureError(Context.ErrorOnClient, Context.ErrorDescription, Context.ApplicationDescription,
		BriefErrorDescription(ErrorInfo), False);
	
	CheckCertificateCycleBeginning(Context);
	
EndProcedure

// Continue the procedure CheckCertificate.
&AtClient
Procedure CheckCertificateCycleAfterSigning(SignatureData, Context) Export
	
	ErrorPresentation = "";
	Try
		DigitalSignatureServiceClientServer.EmptySignatureData(SignatureData, ErrorPresentation);
	Except
		ErrorInfo = ErrorInfo();
		ErrorPresentation = BriefErrorDescription(ErrorInfo);
	EndTry;
	
	If ValueIsFilled(ErrorPresentation) Then
		FillSignatureError(Context.ErrorOnClient, Context.ErrorDescription, Context.ApplicationDescription,
			ErrorPresentation, ErrorInfo = Undefined);
		CheckCertificateCycleBeginning(Context);
		Return;
	EndIf;
	
	Result = New Structure("Application", Context.ApplicationDescription.Ref);
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

// Continue the procedure CheckCertificate.
&AtClient
Procedure CheckCertificateCycleAfterEncryptionError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	FillEncryptionError(Context.ErrorOnClient, Context.ErrorDescription, Context.ApplicationDescription,
		BriefErrorDescription(ErrorInfo));
	
	CheckCertificateCycleBeginning(Context);
	
EndProcedure

// Continue the procedure CheckCertificate.
&AtClient
Procedure CheckCertificateCycleAfterEncryption(EncryptedData, Context) Export
	
	Context.CryptoManager.StartDecryption(New NotifyDescription(
			"CheckCertificateCycleAfterDecryption", ThisObject, Context,
			"CheckCertificateCycleAfterDecryptionError", ThisObject),
		EncryptedData);
	
EndProcedure

// Continue the procedure CheckCertificate.
&AtClient
Procedure CheckCertificateCycleAfterDecryptionError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	FillDecryptionError(Context.ErrorOnClient, Context.ErrorDescription, Context.ApplicationDescription,
		BriefErrorDescription(ErrorInfo));
	
	CheckCertificateCycleBeginning(Context);
	
EndProcedure

// Continue the procedure CheckCertificate.
&AtClient
Procedure CheckCertificateCycleAfterDecryption(DecryptedData, Context) Export
	
	ErrorPresentation = "";
	Try
		DigitalSignatureServiceClientServer.EmptyDecryptedData(DecryptedData, ErrorPresentation);
	Except
		ErrorInfo = ErrorInfo();
		ErrorPresentation = BriefErrorDescription(ErrorInfo);
	EndTry;
	
	If ValueIsFilled(ErrorPresentation) Then
		FillDecryptionError(Context.ErrorOnClient, Context.ErrorDescription, Context.ApplicationDescription,
			ErrorPresentation);
		CheckCertificateCycleBeginning(Context);
		Return;
	EndIf;
	
	Result = New Structure("Application", Context.ApplicationDescription.Ref);
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure


&AtServer
Function CheckCertificateAndWriteInCatalog(Val PasswordValue, ErrorOnServer)
	
	If DigitalSignatureService.CryptoManager("", False, ErrorOnServer) = Undefined
	   AND ErrorOnServer.Common Then
		
		If ForEncryptionAndDecryption = True Then
			ErrorOnServer.Insert("ErrorTitle", NStr("en='Failed to pass the encryption check for the following reason:';ru='Не удалось пройти проверку шифрования по причине:'"));
		Else
			ErrorOnServer.Insert("ErrorTitle", NStr("en='Failed to pass the signing check for the following reason:';ru='Не удалось пройти проверку подписания по причине:'"));
		EndIf;
		Return False;
	EndIf;
	
	CertificateBinaryData = GetFromTempStorage(CertificateAddress);
	CryptoCertificate = New CryptoCertificate(CertificateBinaryData);
	
	ErrorOnServer = New Structure;
	ErrorOnServer.Insert("ErrorDescription", "");
	ErrorOnServer.Insert("Errors", New Array);
	
	ErrorDescription = "";
	
	ApplicationsDescription = DigitalSignatureClientServer.CommonSettings().ApplicationsDescription;
	For Each ApplicationDescription IN ApplicationsDescription Do
		ManagerError = New Structure;
		
		CryptoManager = DigitalSignatureService.CryptoManager("",
			False, ManagerError, ApplicationDescription.Ref);
		
		If CryptoManager = Undefined Then
			If ManagerError.Errors.Count() > 0 Then
				ErrorOnServer.Errors.Add(ManagerError.Errors[0]);
			EndIf;
			Continue;
		EndIf;
		
		CryptoManager.PrivateKeyAccessPassword = PasswordValue;
		
		If ForEncryptionAndDecryption = True Then
			Success = CheckEncryptionAndDecryptionOnServer(CryptoManager, CertificateBinaryData,
				CryptoCertificate, ApplicationDescription, ErrorOnServer, ErrorDescription);
		Else
			Success = CheckSigningOnServer(CryptoManager, CertificateBinaryData,
				CryptoCertificate, ApplicationDescription, ErrorOnServer, ErrorDescription);
		EndIf;
		
		If Success Then
			WriteCertificateToCatalog(ApplicationDescription.Ref);
			Return True;
		EndIf;
	EndDo;
	
	ErrorOnServer.Insert("ErrorDescription", TrimAll(ErrorDescription));
	
	Return False;
	
EndFunction

&AtServer
Function CheckEncryptionAndDecryptionOnServer(CryptoManager, CertificateBinaryData,
			CryptoCertificate, ApplicationDescription, ErrorOnServer, ErrorDescription)
	
	ErrorPresentation = "";
	Try
		EncryptedData = CryptoManager.Encrypt(CertificateBinaryData, CryptoCertificate);
	Except
		ErrorInfo = ErrorInfo();
		ErrorPresentation = BriefErrorDescription(ErrorInfo);
	EndTry;
	
	If ValueIsFilled(ErrorPresentation) Then
		FillEncryptionError(ErrorOnServer, ErrorDescription, ApplicationDescription, ErrorPresentation);
		Return False;
	EndIf;
	
	ErrorPresentation = "";
	Try
		DecryptedData = CryptoManager.Decrypt(EncryptedData);
		DigitalSignatureServiceClientServer.EmptyDecryptedData(DecryptedData, ErrorPresentation);
	Except
		ErrorInfo = ErrorInfo();
		ErrorPresentation = BriefErrorDescription(ErrorInfo);
	EndTry;
	
	If ValueIsFilled(ErrorPresentation) Then
		FillDecryptionError(ErrorOnServer, ErrorDescription, ApplicationDescription, ErrorPresentation);
		Return False;
	EndIf;
		
	Return True;
	
EndFunction

&AtServer
Function CheckSigningOnServer(CryptoManager, CertificateBinaryData,
			CryptoCertificate, ApplicationDescription, ErrorOnServer, ErrorDescription)
	
	ErrorPresentation = "";
	Try
		SignatureData = CryptoManager.Sign(CertificateBinaryData, CryptoCertificate);
		DigitalSignatureServiceClientServer.EmptySignatureData(SignatureData, ErrorPresentation);
	Except
		ErrorInfo = ErrorInfo();
		ErrorPresentation = BriefErrorDescription(ErrorInfo);
	EndTry;
	If ValueIsFilled(ErrorPresentation) Then
		FillSignatureError(ErrorOnServer, ErrorDescription, ApplicationDescription,
			ErrorPresentation, ErrorInfo <> Undefined);
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Procedure WriteCertificateToCatalog(Application)
	
	DigitalSignatureService.WriteCertificateToCatalog(ThisObject, Application);
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillEncryptionError(Error, ErrorDescription, ApplicationDescription, ErrorPresentation)
	
	CurrentError = New Structure;
	CurrentError.Insert("Description", ErrorPresentation);
	CurrentError.Insert("Instruction", True);
	CurrentError.Insert("ApplicationsSetting", True);
	
	Error.Errors.Add(CurrentError);
	
	ErrorDescription = ErrorDescription + Chars.LF + Chars.LF
		+ StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to pass the encryption check using the appliaction %1
		|for the following reason: %2';ru='Не удалось пройти проверку шифрования с помощью программы %1 по причине:
		|%2'"),
			ApplicationDescription.Description,
			ErrorPresentation);
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillDecryptionError(Error, ErrorDescription, ApplicationDescription, ErrorPresentation)
	
	CurrentError = New Structure;
	CurrentError.Insert("Description", ErrorPresentation);
	CurrentError.Insert("Instruction", True);
	CurrentError.Insert("ApplicationsSetting", True);
	
	Error.Errors.Add(CurrentError);
	
	ErrorDescription = ErrorDescription + Chars.LF + Chars.LF
		+ StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to pass the decryption check using the application %1
		|for the following reason: %2';ru='Не удалось пройти проверку расшифровки с
		|помощью программы %1 по причине: %2'"),
			ApplicationDescription.Description,
			ErrorPresentation);
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillSignatureError(Error, ErrorDescription, ApplicationDescription, ErrorPresentation, EmptyData)
	
	CurrentError = New Structure;
	CurrentError.Insert("Description", ErrorPresentation);
	
	If Not EmptyData Then
		CurrentError.Insert("ApplicationsSetting", True);
		CurrentError.Insert("Instruction", True);
	EndIf;
	
	Error.Errors.Add(CurrentError);
	
	ErrorDescription = ErrorDescription + Chars.LF + Chars.LF
		+ StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Unable to check the signing using the %1 application because
		|of: %2';ru='Не удалось пройти проверку подписания с помощью
		|программы %1 по причине: %2'"),
			ApplicationDescription.Description,
			ErrorPresentation);
	
EndProcedure

#EndRegion
