
#Region CommonUseProceduresAndFunctions

&AtServer
Procedure FillTabularSectionByDocumentType()
	
	ActualEDs = ElectronicDocumentsReUse.GetEDActualKinds();
	
	For Each EnumValue IN ActualEDs Do
		If EnumValue = Enums.EDKinds.Error
				OR EnumValue = Enums.EDKinds.Confirmation
				OR EnumValue = Enums.EDKinds.AddData
				OR EnumValue = Enums.EDKinds.BankStatement
				OR EnumValue = Enums.EDKinds.STATEMENT Then
			Continue;
		EndIf;
		
		If Object.BankApplication = Enums.BankApplications.SberbankOnline
			AND Not (EnumValue = Enums.EDKinds.PaymentOrder
					OR EnumValue = Enums.EDKinds.QueryStatement
					OR EnumValue = Enums.EDKinds.QueryNightStatements) Then
				Continue;
		EndIf;
		
		If (Object.BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor")
				OR  Object.BankApplication = PredefinedValue("Enum.BankApplications.iBank2"))
			AND Not EnumValue = Enums.EDKinds.PaymentOrder Then
			Continue;
		EndIf;
		
			
		If Not Object.BankApplication = Enums.BankApplications.SberbankOnline
			AND EnumValue = Enums.EDKinds.QueryNightStatements Then
				Continue;
		EndIf;
		
		RowArray = Object.DocumentKinds.FindRows(New Structure("DocumentKind", EnumValue));
		If RowArray.Count() = 0 Then
			TSNewRow = Object.DocumentKinds.Add();
			TSNewRow.DocumentKind = EnumValue;
			TSNewRow.UseToSign = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure DetermineAvailabilityCompositionPerformers()
	
	Items.PerformersContent.Enabled = Object.CheckPerformersContent;
	
EndProcedure

&AtServer
Procedure SetEnabledVisible()
	
	Items.HeaderGroup.Enabled 				= Not Object.Revoked;
	Items.DocumentsKindsAndPerformers.Enabled = Not Object.Revoked;
	Items.CertificateTestForm.Enabled 		= Not Object.Revoked;
	Items.CertificateTestForm.Enabled 		= Not ReadOnly;
	Items.FormWithdrawnButton.Check 			= Object.Revoked;
	Items.User.Enabled				= Object.RestrictAccessToCertificate;
	Items.User.AutoMarkIncomplete = Object.RestrictAccessToCertificate;
	Items.ButtonPassword.Enabled				= Object.RememberCertificatePassword;
	DetermineAvailabilityCompositionPerformers();
	FillHeadingsHyperlinks();
	
	// Verification of the certificate for compliance to the Federal Law No. 63.
	SystemInfo = New SystemInfo;
	If Object.BankApplication <> Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
			AND Object.BankApplication <> Enums.BankApplications.iBank2
			AND CommonUseClientServer.CompareVersions(SystemInfo.AppVersion, "8.2.18.108") >= 0 Then
		CertificateFileData = Object.Ref.CertificatFile.Get();
		NewCertificate = New CryptoCertificate(CertificateFileData);
		
		// Work correctly only with certificates in order to sign standard structure.
		If (NewCertificate.Subject.Property("SN") OR NewCertificate.Subject.Property("CN"))
			AND NewCertificate.Subject.Property("T") AND NewCertificate.Subject.Property("ST") Then
			
			NameAndSurnameOfOwner = "";
			If NewCertificate.Subject.Property("SN") Then
				TemplateOwnerNameAndSurname = NStr("en='%1 %2';ru='%1 %2'");
				NameAndSurnameOfOwner = StringFunctionsClientServer.PlaceParametersIntoString(TemplateOwnerNameAndSurname,
				NewCertificate.Subject.SN, NewCertificate.Subject.GN);
			ElsIf NewCertificate.Subject.Property("CN") Then
				
				NameAndSurnameOfOwner = NewCertificate.Subject.CN;
			EndIf;
			
			If ValueIsFilled(NameAndSurnameOfOwner) Then
				Surname      = "";
				Name          = "";
				Patronymic     = "";
				
				ElectronicDocuments.SurnameInitialsOfIndividual(NameAndSurnameOfOwner, Surname, Name, Patronymic);
			EndIf;
			Position = NewCertificate.Subject.T;
			
			WriteCertificate = False;
			If ValueIsFilled(Surname) AND Object.Surname <> Surname Then
				Object.Surname  = Surname;
				WriteCertificate = True;
			EndIf;
			If ValueIsFilled(Name) AND Object.Name <> Name Then
				Object.Name      = Name;
				WriteCertificate = True;
			EndIf;
			If ValueIsFilled(Patronymic) AND Object.Patronymic <> Patronymic Then
				Object.Patronymic = Patronymic;
				WriteCertificate = True;
			EndIf;
			If ValueIsFilled(Position) AND Object.PositionByCertificate <> Position Then
				Object.PositionByCertificate = Position;
				WriteCertificate = True;
			EndIf;
			
			If WriteCertificate Then
				Write();
			EndIf;
			
			Items.Surname.Enabled  = False;
			Items.Name.Enabled      = False;
			Items.Patronymic.Enabled = False;
			Items.PositionByCertificate.Enabled = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillHeadingsHyperlinks()
	
	If Object.RememberCertificatePassword Then
		HyperlinksTextOfPassword = NStr("en='Change password.';ru='Изменить пароль.'");
	Else
		HyperlinksTextOfPassword = NStr("en='Password is not saved.';ru='Пароль не сохранен.'");
	EndIf;
	
	Items.ButtonPassword.Title       = HyperlinksTextOfPassword;
	
EndProcedure

&AtClient
Procedure SetPassword(RememberPassword = False)
	
	CertificateParameters = ElectronicDocumentsServiceCallServer.CertificateAttributes(Object.Ref);
	CertificateParameters.PasswordReceived = False;
	
	Map = New Map;
	Map.Insert(Object.Ref, CertificateParameters);
	OperationKind = NStr("en='Saving the password in certificate';ru='Сохранение пароля в сертификате'");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ForWrite", True);
	AdditionalParameters.Insert("RememberPassword", RememberPassword);
	
	NotificationHandler = New NotifyDescription("SetPasswordNotification", ThisObject, AdditionalParameters);
	
	RequestPasswordToCertificateAtServer(Map, NotificationHandler, OperationKind, , True);
	
EndProcedure

&AtClient
Procedure RequestPasswordToCertificateAtServer(CertificatesMap,
										NotificationHandler,
										OperationKind = Undefined,
										ObjectsForProcessings = Undefined,
										WriteToIB = False) Export
	
	CertificatesParameters = New Structure;
	If Not NeedPassword(CertificatesMap, CertificatesParameters, ObjectsForProcessings) Then
		ExecuteNotifyProcessing(NotificationHandler, CertificatesParameters);
		
		Return;
	EndIf;
	
	// Fill the opening of the form parameters
	FormParameters = New Structure();
	FormParameters.Insert("OperationKind",   OperationKind);
	FormParameters.Insert("WriteToIB",  WriteToIB);
	FormParameters.Insert("Map",  CertificatesMap);
	If ObjectsForProcessings <> Undefined Then
		If TypeOf(ObjectsForProcessings) <> Type("Array") Then
			ObjectsArray = New Array;
			ObjectsArray.Add(ObjectsForProcessings);
		Else
			ObjectsArray = ObjectsForProcessings;
		EndIf;
	EndIf;
	FormParameters.Insert("ObjectsForProcessings", ObjectsArray);
	
	// Open the password query form
	Form = "Catalog.DeleteDSCertificates.Form.StoragePasswordQuery";
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(Form, FormParameters,,,,, NotificationHandler, Mode);
	
EndProcedure

&AtClient
Function NeedPassword(AccCertificatesAndTheirStructures, CertificateParameters, ObjectsForProcessings = Undefined, WriteToIB = False)
	
	RequestPassword = False;
	CertificatesCount = AccCertificatesAndTheirStructures.Count();
	PasswordReceived = False;
	
	Map = New Map;

	For Each KeyAndValue IN AccCertificatesAndTheirStructures Do
		
		Certificate = KeyAndValue.Key;
		CertificateParameters = KeyAndValue.Value;
		BankApplication = Undefined;
		
		If Not ValueIsFilled(CertificateParameters) Then
			CertificateParameters = ElectronicDocumentsServiceCallServer.CertificateAttributes(Certificate);
		EndIf;
		
		If CertificateParameters.Property("BankApplication")
			AND CertificateParameters.BankApplication = PredefinedValue("Enum.BankApplications.SberbankOnline") Then
			Break;
		EndIf;
		
		UserPassword = Undefined;
		If Not WriteToIB
			AND CertificatesCount = 1
			AND ((CertificateParameters.Property("PasswordReceived", PasswordReceived)
				AND PasswordReceived
				OR ElectronicDocumentsServiceClient.CertificatePasswordReceived(Certificate, UserPassword))) Then
			
			If Not PasswordReceived Then
				PasswordReceived = True;
				CertificateParameters.Insert("PasswordReceived", PasswordReceived);
				CertificateParameters.Insert("UserPassword", UserPassword);
				CertificateParameters.Insert("SelectedCertificate", Certificate);
			EndIf;
			
			Break;
			
			ElsIf (BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor")
					OR BankApplication = PredefinedValue("Enum.BankApplications.iBank2"))
				AND Not ObjectsForProcessings = Undefined
				AND ElectronicDocumentsServiceClient.RelevantCertificatePasswordCacheThroughAdditionalProcessing(
					CertificateParameters, ObjectsForProcessings) Then
			
			Break;
			
		EndIf;
		
		// If you have already received a certificate etc..
		If CertificateParameters.Property("Processed") Then
			Break;
		EndIf;
		
		// IN the query password form 3 parameters from the certificate structure are used:
		// UserPassword, PasswordReceived, RememberCertificatePassword. Pass them into the form.
		
		Structure = New Structure("UserPassword, PasswordReceived, RememberCertificatePassword");
		FillPropertyValues(Structure, CertificateParameters);
		Map.Insert(Certificate, Structure);
		
		RequestPassword = True
		
	EndDo;
	
	AccCertificatesAndTheirStructures = Map;
	
	Return RequestPassword;
	
EndFunction

#EndRegion

#Region CommandsActionsForms

&AtClient
Procedure SelectAll(Command)
	
	For Each TableElement IN Object.DocumentKinds Do
		TableElement.UseToSign = True;
	EndDo;
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	For Each TableElement IN Object.DocumentKinds Do
		TableElement.UseToSign = False;
	EndDo;
	
EndProcedure

&AtClient
Procedure CertificateRevoked(Command)
	
	Object.Revoked = Not Object.Revoked;
	SetEnabledVisible();
	
EndProcedure

&AtClient
Procedure RestrictAccessToCertificateOnChange(Item)
	
	SetEnabledVisible();
	
	If Not Object.RestrictAccessToCertificate AND ValueIsFilled(Object.User) Then
		Object.User = Undefined;
	ElsIf Object.RestrictAccessToCertificate Then
		CurrentItem = Items.User;
	EndIf;
	
EndProcedure

&AtClient
Procedure CommandSetPassword(Command)
	
	SetPassword(True);
	
EndProcedure

&AtClient
Procedure CertificateSettingsTest(Command)
	
	ClearMessages();
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	If Modified Then
		
		QuestionText = NStr("en='Certificate settings have been changed. Do you want to continue the test?';ru='Изменены настройки сертификата. Продолжить выполнение теста?'");
		ButtonList = New ValueList();
		ButtonList.Add("Execute", NStr("en='Save and perform the test';ru='Сохранить и выполнить тест'"));
		ButtonList.Add("Cancel", NStr("en='Cancel the test';ru='Отменить тест'"));
		
		NotificationHandler = New NotifyDescription("PerformNotificationTextSettings", ThisObject);
		
		ShowQueryBox(NotificationHandler, QuestionText, ButtonList, , "Execute", NStr("en='Certificate settings test';ru='Тест настроек сертификата'"));
		
		
	Else
		PerformCertificateTestSettings();
	EndIf;
	
		
EndProcedure

#EndRegion

#Region FieldsFormEventsHandlers

&AtClient
Procedure AppointmentOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	Try
		DigitalSignatureClient.OpenCertificate(Object.Imprint);
	Except
		ShowMessageBox(,NStr("en='It is impossible to open the certificate. Perhaps, it has not been installed to the local computer';ru='Невозможно открыть сертификат. Возможно он не установлен на локальный компьютер.'"));
	EndTry;
	
EndProcedure

&AtClient
Procedure CheckPerformersContentOnChange(Item)
	
	DetermineAvailabilityCompositionPerformers();
	
EndProcedure

&AtClient
Procedure SurnameOnChange(Item)
	
	Object.Surname = TrimAll(Object.Surname);
	
EndProcedure

&AtClient
Procedure NameOnChange(Item)
	
	Object.Name = TrimAll(Object.Name);
	
EndProcedure

&AtClient
Procedure PatronymicOnChange(Item)
	
	Object.Patronymic = TrimAll(Object.Patronymic);
	
EndProcedure

&AtClient
Procedure PostCertificateOnChange(Item)
	
	Object.PositionByCertificate = TrimAll(Object.PositionByCertificate);
	
EndProcedure

&AtClient
Procedure RememberCertificatePasswordOnChange(Item)

	If Not Object.RememberCertificatePassword Then
		
		Object.UserPassword = Undefined;
		SetEnabledVisible();

	Else
		
		SetPassword(True);
		
	EndIf;
		
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillTabularSectionByDocumentType();
	DetermineAvailabilityCompositionPerformers();
	
	If Object.BankApplication = Enums.BankApplications.SberbankOnline
		OR Object.BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
		OR Object.BankApplication = Enums.BankApplications.iBank2 Then
		Items.CertificateTestForm.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	SetEnabledVisible();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Object.RestrictAccessToCertificate AND Not ValueIsFilled(Object.User) Then
		Cancel = True;
		ShowMessageBox(,NStr("en='The user to whom the certificate is available is not specified!
		|Specify the user or remove the access restriction.';ru='Не указан пользователь, которому доступен сертификат!
		|Укажите пользователя, либо снимите ограничение доступа.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshStateED", Object.Ref);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure PerformCertificateTestSettings()
	
	If ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer()
		AND Not (Object.BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor"))
		AND Not (Object.BankApplication = PredefinedValue("Enum.BankApplications.iBank2")) Then
			AtClient = False;
			AtServer = True;
	Else
		AtClient = True;
		AtServer = False;
	EndIf;
	
	CertificateParameters = ElectronicDocumentsServiceCallServer.CertificateAttributes(Object.Ref);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("RememberCertificatePassword", CertificateParameters.RememberCertificatePassword);
	
	NotificationProcessing = New NotifyDescription("NotificationSettingsTest", ThisObject, AdditionalParameters);
	
	CheckContext = New Structure;
	CheckContext.Insert("AtClient", AtClient);
	CheckContext.Insert("AtServer", AtServer);
	
	ElectronicDocumentsServiceClient.CertificateValidationSettingsTest(Object.Ref,
																CertificateParameters,
																NotificationProcessing,
																CheckContext);
	
EndProcedure

#EndRegion

#Region AsynchronousProcedures

&AtClient
Procedure PerformNotificationTextSettings(Response, AdditionalParameters) Export
	
	If Response = "Cancel" Then
		Return;
	Else
		Write();
	EndIf;
	
	PerformCertificateTestSettings();
	
EndProcedure

&AtClient
Procedure SetPasswordNotification(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		
		If Not AdditionalParameters.RememberPassword Then
			Object.RememberCertificatePassword = False;
		EndIf;
		
		SetEnabledVisible();
		
		Return;
		
	EndIf;
	
	Object.UserPassword = Result.UserPassword;
	Object.RememberCertificatePassword = True;
	
	Modified = True;
	
	SetEnabledVisible();
	
EndProcedure

&AtClient
Procedure NotificationSettingsTest(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If AdditionalParameters.RememberCertificatePassword <> Object.RememberCertificatePassword Then
		Read();
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
