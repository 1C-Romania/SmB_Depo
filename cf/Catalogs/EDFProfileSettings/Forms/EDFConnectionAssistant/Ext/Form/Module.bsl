
&AtClient
Var InternalData, PasswordValue, DataDescription, ObjectForm, PresentationsList;

&AtClient
Var ProcessingAfterWarning, PasswordExplanationsProcessing;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.AssistantPages.PagesRepresentation = FormPagesRepresentation.None;
	
	SetPrivilegedMode(True);
	AuthorizationContext  = Constants.AuthorizationContext.Get();
	CryptographyContext = Constants.CreateDigitalSignaturesAtServer.Get();
	SetPrivilegedMode(False);
	
	If Parameters.Property("Company") Then
		Company = Parameters.Company;
	EndIf;
	
	EDExchangeMethods = "";
	If Parameters.Property("EDExchangeMethods", EDExchangeMethods) AND ValueIsFilled(EDExchangeMethods) Then
		If EDExchangeMethods.Count() = 1 Then
			EDExchangeMethod = EDExchangeMethods[0];
			Items.EDExchangeMethod.ChoiceList.Add(EDExchangeMethod);
			Items.AssistantPages.CurrentPage = Items.Connection1CTaxcomPage;
			ThisObject.Title = Items.Connection1CTaxcomPage.Title;
		Else
			For Each String IN EDExchangeMethods Do
				Items.EDExchangeMethod.ChoiceList.Add(String);
			EndDo;
			Items.AssistantPages.CurrentPage = Items.PageDirectExchangeSettings;
			EDExchangeMethod = Enums.EDExchangeMethods.ThroughEMail;
			ThisObject.Title = Items.PageDirectExchangeSettings.Title;
		EndIf;
	EndIf;
	
	SetDefaultValues();
	FormManagement(ThisForm);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom") Then
		
		AgreeWithConditions = True;
		ElectronicDocumentsClientOverridable.ToRequestConsentToTermsOfLicenseAgreements(AgreeWithConditions);
		If AgreeWithConditions <> True Then
			Cancel = True;
			Return;
		EndIf;
	EndIf;
	
	If ElectronicDocumentsServiceClient.CheckUsingUsersInternetSupport() Then
		Items.GroupIDFillingWithoutOUS.Visible = False;
	Else
		Items.GroupIDWithOUSFilling.Visible = False;
	EndIf;
	
	ElectronicDocumentsServiceClient.FillDataServiceSupport(ServiceSupportPhoneNumber, ServiceSupportEmailAddress);
	
	#If WebClient Then
		Items.IncomingDocumentsDir.ChoiceButton = False;
	#EndIf
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	// Ask a question only in case of early closing of the assistant.
	If CloseForm <> True AND Not ValueIsFilled(SettingsProfileRef) Then
		QuestionText = NStr("en='Entered data will not be saved.
		|Are you sure you want to close the wizard?';ru='Введенные данные не будут сохранены.
		|Прервать работу помощника?'");
		NotifyDescription = New NotifyDescription("CompleteBeforeClosing", ThisObject);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// OnlineUserSupport
	
	// The mechanism of receiving a unique
	// identifier passes the unique identifier in the form of
	// rows in the notification parameter with the event name "NotificationReceivedUUIDEDFExchangeParticipant"
	If EventName = "NotificationOfReceiptOfParticipantsUniqueIdEdExchange" Then
		CompanyID = TrimAll(Parameter);
		
		Items.CaptionIDOfParticipantExchangeED.Title = CompanyID;
		Items.CaptionIDOfParticipantExchangeED.Hyperlink = False;
		ElementFont = Items.CaptionIDOfParticipantExchangeED.Font;
		Items.CaptionIDOfParticipantExchangeED.Font = New Font(ElementFont, , , True);
	EndIf;
	// End OnlineUserSupport
	
EndProcedure

#EndRegion

#Region FieldsFormEventsHandlers

&AtClient
Procedure CompanyOnChange(Item)
	
	If EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom") Then
		CompanyID = "";
		Items.CaptionIDOfParticipantExchangeED.Title = NStr("en='Obtain a unique identifier of the ED exchange participant';ru='Получить уникальный идентификатор участника обмена ЭД.'");
		ElementFont = Items.CaptionIDOfParticipantExchangeED.Font;
		Items.CaptionIDOfParticipantExchangeED.Font = New Font(ElementFont, , , False);
		Items.CaptionIDOfParticipantExchangeED.Hyperlink = True;
		CompanyOnChangeComplete(Undefined, Undefined);
	Else
		If ValueIsFilled(CompanyID) Then
			NotifyDescription = New NotifyDescription("CompanyOnChangeComplete", ThisObject);
			QuestionText = NStr("en='The company was modified. Do you want to change the exchange ID of the company?';ru='Была изменена организация. Изменить идентификатор обмена организации?'");
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		Else
			CompanyOnChangeComplete(DialogReturnCode.Yes, Undefined);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure EDExchangeMethodOnChange(Item)
	
	FormManagement(ThisForm);
	
EndProcedure

&AtClient
Procedure UseDSOnChange(Item)
	
	If ValueIsFilled(CryptoCertificate) Then
		NotifyDescription = New NotifyDescription("UseDSOnChangeComplete", ThisObject);
		QuestionText = NStr("en='Data on the certificate will be cleared. Continue?';ru='Данные по сертификату будут очищены. Продолжить?'");
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	Else
		UseDSOnChangeComplete(Undefined, Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure DSCertificateChoiceBegin(Item, ChoiceData, StandardProcessing)
	
	DigitalSignatureClient.CertificateStartChoiceWithConfirmation(Item,
		CryptoCertificate, StandardProcessing);
		
EndProcedure

&AtClient
Procedure CaptionEDExchangeParticipantIDPress(Item)
	
	If Not ValueIsFilled(CryptoCertificate) Then
		CommonUseClientServer.MessageToUser(
			ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Certificate of digital signature key"),
			,
			"CryptoCertificate");
		Return;
	EndIf;
	ElectronicDocumentsClientOverridable.StartWorkWithEDFOperatorMechanism(CryptoCertificate,
																					  Company,
																					  "taxcomGetID",
																					  CompanyID,
																					  Undefined,
																					  ThisObject.UUID);
	
EndProcedure

&AtClient
Procedure DecorationCreateAccountClick(Item)
	
	OpenForm("Catalog.EmailAccounts.Form.ItemForm");
	
EndProcedure

&AtClient
Procedure IncomingDocumentsDirBeginChoice(Item, ChoiceData, StandardProcessing)
	
#If Not WebClient Then
	ExchangeDirectory(IncomingDocumentsDir);
#EndIf
	
EndProcedure

&AtClient
Procedure FTPIncomingDocumentsDirStartChoice(Item, ChoiceData, StandardProcessing)
	
	ExchangeDirectory(FTPIncomingDocumentsDir);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Done(Command)
	
	ClearMessages();
	
	EDFProfileSettingsTest();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure OpenDSToolTip(Command)
	
	OpenForm("Catalog.EDFProfileSettings.Form.DSToolTipForm");
	
EndProcedure

&AtClient
Procedure OpenLinkTo1CBuhphoneItem(Command)
	
	ElectronicDocumentsServiceClient.OpenStatement1CBuhphone();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClientAtServerNoContext
Procedure FormManagement(Form)
	
	Items = Form.Items;
	
	ValueFOUseDS = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseDigitalSignatures");
	Items.GroupThroughEMailCryptographySetup.Visible = ValueFOUseDS;
	Items.GroupThroughCatalogCryptographySetup.Visible          = ValueFOUseDS;
	Items.GroupThroughFTPCryptographySetup.Visible              = ValueFOUseDS;
	
	Items.DSCertificateThroughEMail.Enabled = Form.UseDS;
	Items.DSCertificateThroughCatalog.Enabled          = Form.UseDS;
	Items.DSCertificateThroughFTP.Enabled              = Form.UseDS;
	
	If Form.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEMail") Then
		Items.GroupParticipantSettings.CurrentPage = Items.ParticipantSettingsGroupThroughEMail;
	ElsIf Form.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughDirectory") Then
		Items.GroupParticipantSettings.CurrentPage = Items.ParticipantSettingsGroupThroughCatalog;
	ElsIf Form.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughFTP") Then
		Items.GroupParticipantSettings.CurrentPage = Items.ParticipantSettingsGroupThroughFTP;
	EndIf;
	
	If CommonUseClientServer.IsPlatform83() Then
		Items.DSCertificateThroughOperator.CreateButton = False;
		Items.DSCertificateThroughEMail.CreateButton = False;
		Items.DSCertificateThroughCatalog.CreateButton = False;
		Items.DSCertificateThroughFTP.CreateButton = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetDefaultValues()
	
	UseDS = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseDigitalSignatures");
	CryptoCertificate = Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef();
	
	If EDExchangeMethod = Enums.EDExchangeMethods.ThroughEMail
		AND Not ValueIsFilled(CompanyEmail) Then
		
		Query = New Query(
		"SELECT ALLOWED TOP 2
		|	EmailAccounts.Ref
		|FROM
		|	Catalog.EmailAccounts AS EmailAccounts
		|WHERE
		|	Not EmailAccounts.DeletionMark
		|	AND EmailAccounts.UseForSending
		|	AND EmailAccounts.UseForReceiving");
		Selection = Query.Execute().Select();
		
		If Selection.Count() = 1 AND Selection.Next() Then
			CompanyEmail = Selection.Ref;
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(AuthorizationContext) Then
		AuthorizationContext = PredefinedValue("Enum.WorkContextsWithED.AtClient");
	EndIf;
	
	If Not ValueIsFilled(CryptographyContext) Then
		CryptographyContext = False;
	EndIf;
	
	If UseDS AND ValueIsFilled(Company) Then
		Query = New Query;
		Query.Text =
		"SELECT
		|	Certificates.Ref
		|FROM
		|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
		|WHERE
		|	Certificates.Company = &Company
		|	AND Not Certificates.DeletionMark
		|	AND Not Certificates.Revoked";
		Query.SetParameter("Company", Company);
		
		Selection = Query.Execute().Select();
		If Selection.Count() = 1 AND Selection.Next() Then
			CryptoCertificate = Selection.Ref;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeDirectory(PathToDirectory)
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("PathToDirectory", PathToDirectory);
	
	FolderDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	FolderDialog.Title = NStr("en='Select network directory for exchange';ru='Выберите сетевой каталог для обмена'");
	FolderDialog.Directory = PathToDirectory;
	DirectorySelectionDescription = New NotifyDescription("AfterSelectingDirectory", ThisObject);
		
	FolderDialog.Show(DirectorySelectionDescription);
	
EndProcedure

&AtServer
Procedure SetIdentifier(CatalogName, IdentifierSourceRef)
	
	If CatalogName = "Companies" Then
		AttributeNameCompanyTIN = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CompanyTIN");
		AttributeNameCompanyKPP = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CompanyKPP");
		
		ParametersCompany = CommonUse.ObjectAttributesValues(IdentifierSourceRef,
			AttributeNameCompanyTIN + ", " + AttributeNameCompanyKPP);
		
		RowFill = String(ParametersCompany[AttributeNameCompanyTIN])
			+ "_" + String(ParametersCompany[AttributeNameCompanyKPP]);
		If Right(RowFill, 1) = "_" Then
			RowFill = StrReplace(RowFill, "_", "");
		EndIf;
		CompanyID = TrimAll(RowFill);
		
	ElsIf CatalogName = "Counterparties" Then
		AttributeNameCounterpartyTIN = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyTIN");
		AttributeNameCounterpartyKPP = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyCRR");
		
		CounterpartyParameters = CommonUse.ObjectAttributesValues(IdentifierSourceRef,
			AttributeNameCounterpartyTIN + ", " + AttributeNameCounterpartyKPP);
		
		RowFill = String(CounterpartyParameters[AttributeNameCounterpartyTIN])
			+ "_" + String(CounterpartyParameters[AttributeNameCounterpartyKPP]);
		If Right(RowFill, 1) = "_" Then
			RowFill = StrReplace(RowFill, "_", "");
		EndIf;
		CounterpartyID = TrimAll(RowFill);
	EndIf;
	
EndProcedure

// EDF settings profile

&AtClient
Procedure EDFProfileSettingsTest()
	
	Cancel = False;
	// Testing the form occupancy
	If Not ValueIsFilled(Company) Then
		CommonUseClientServer.MessageToUser(
		ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Company"),
		,
		"Company",
		,
		Cancel);
	EndIf;
	If Not ValueIsFilled(CompanyID)
		AND EDExchangeMethod <> PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom") Then
		
		CommonUseClientServer.MessageToUser(
			ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Company ID"),
			,
			"CompanyID",
			,
			Cancel);
	EndIf;

	If Not ValueIsFilled(EDExchangeMethod) Then
		CommonUseClientServer.MessageToUser(
			ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "ED exchange method"),
			,
			"EDExchangeMethod",
			,
			Cancel);
	EndIf;
	
	If EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEMail") Then
		If Not ValueIsFilled(CompanyEmail) Then
			CommonUseClientServer.MessageToUser(
			ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Company email"),
			,
			"CompanyEmail",
			,
			Cancel);
		EndIf;
		If Not ValueIsFilled(CryptoCertificate) AND UseDS Then
			CommonUseClientServer.MessageToUser(
				ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Certificate of digital signature key"),
				,
				"CryptoCertificate",
				,
				Cancel);
		EndIf;

	ElsIf EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughDirectory") Then
		If Not ValueIsFilled(IncomingDocumentsDir) Then
			CommonUseClientServer.MessageToUser(
			ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Incoming documents catalog"),
			,
			"IncomingDocumentsDir",
			,
			Cancel);
		EndIf;
		If Not ValueIsFilled(CryptoCertificate) AND UseDS Then
			CommonUseClientServer.MessageToUser(
				ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Certificate of digital signature key"),
				,
				"CryptoCertificate",
				,
				Cancel);
		EndIf;

	ElsIf EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughFTP") Then
		If Not ValueIsFilled(FTPServerAddress) Then
			CommonUseClientServer.MessageToUser(
			ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Server address"),
			,
			"FTPServerAddress",
			,
			Cancel);
		EndIf;
		
		If Not ValueIsFilled(FTPIncomingDocumentsDir) Then
			CommonUseClientServer.MessageToUser(
			ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Incoming documents catalog"),
			,
			"FTPIncomingDocumentsDir",
			,
			Cancel);
		EndIf;
		If Not ValueIsFilled(CryptoCertificate) AND UseDS Then
			CommonUseClientServer.MessageToUser(
				ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Certificate of digital signature key"),
				,
				"CryptoCertificate",
				,
				Cancel);
		EndIf;
		
	EndIf;
	
	If EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom") Then
		If Not ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
				"UseDigitalSignatures") Then
		
			MessageText = ElectronicDocumentsServiceCallServer.MessageTextAboutSystemSettingRequirement(
				"SettingCryptography");
			CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
		EndIf;
		
		If Not ValueIsFilled(CryptoCertificate) Then
			CommonUseClientServer.MessageToUser(
				ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Certificate of digital signature key"),
				,
				"CryptoCertificate",
				,
				Cancel);
		EndIf;
		
		If Not ValueIsFilled(CompanyID) Then
			
			If ElectronicDocumentsServiceClient.CheckUsingUsersInternetSupport() Then
				CommonUseClientServer.MessageToUser(
					NStr("en='You need to obtain a unique identifier of the ED exchange participant.';ru='Необходимо получить уникальный идентификатор участника обмена ЭД.'"), , , , Cancel);
			Else
				CommonUseClientServer.MessageToUser(
					ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Company ID"),
					,
					"CompanyID",
					,
					Cancel);
			EndIf;
		Else
			CompanyID = TrimAll(CompanyID);
			IdentifierLength = StrLen(CompanyID);
			If IdentifierLength <> 46 Then
				CommonUseClientServer.MessageToUser(
					ElectronicDocumentsClientServer.GetMessageText("Field", "CORRECTNESS", "Company ID", , ,
						NStr("en='Field length is not equal 46.';ru='Длина поля не равна 46.'")),
					,
					"CompanyID",
					,
					Cancel);
			EndIf;
		EndIf;
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	CommunicationsTestPass = True;
	If EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom") Then
		
		Status(NStr("en='Creating an EDF settings profile.';ru='Создание профиля настроек ЭДО.'"),
			,
			NStr("en='Testing the connection with the operator. Please wait...';ru='Выполняется тестирование связи с оператором. Пожалуйста, подождите..'"));
		CertificateTest(CommunicationsTestPass, True);
		
	Else
		If EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEMail") Then
			
			Status(NStr("en='Creating an EDF settings profile.';ru='Создание профиля настроек ЭДО.'"),
				,
				NStr("en='Testing ED exchange through electronic mail. Please wait...';ru='Выполняется тестирование обмена ЭД через электронную почту. Пожалуйста, подождите..'"));
			
			ErrorInfo = "";
			AdditionalMessage = "";
			EmailOperationsServerCall.CheckPossibilityOfSendingAndReceivingOfEmails(
					CompanyEmail, Undefined, ErrorInfo, AdditionalMessage);
			
			If ValueIsFilled(ErrorInfo) Then
				CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Verification of the account parameters
		|is complete with errors: %1';ru='Проверка параметров учетной записи завершилась с ошибками:
		|%1'"), ErrorInfo ),,
					NStr("en='Check email account';ru='Проверка учетной записи'"));
				CommunicationsTestPass = False;
			EndIf;
			
		ElsIf EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughDirectory") Then
			
			Status(NStr("en='Creating an EDF settings profile.';ru='Создание профиля настроек ЭДО.'"),
				,
				NStr("en='Testing ED exchange through directory. Please wait...';ru='Выполняется тестирование обмена ЭД через каталог. Пожалуйста, подождите..'"));
			TestLinksDirectExchangeAtServer(IncomingDocumentsDir, CommunicationsTestPass);
			
		ElsIf EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughFTP") Then
			
			Status(NStr("en='Creating an EDF settings profile.';ru='Создание профиля настроек ЭДО.'"),
				,
				NStr("en='Testing ED exchange through FTP. Please wait...';ru='Выполняется тестирование обмена ЭД через FTP. Пожалуйста, подождите..'"));
			ExchangeConnectionTestThroughFTPOnServer(CommunicationsTestPass);
			
		EndIf;
		
		// Testing cryptography
		If UseDS Then
			CertificateTest(Cancel);
		Else	
			CreateNewProfile();
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure SaveParameters(DataSaved)
	
	Try
		BeginTransaction();
		NewSettingsProfile = Catalogs.EDFProfileSettings.CreateItem();
		
		PatternName = NStr("en='%1, %2';ru='%1, %2'");
		NewSettingsProfile.Description = StringFunctionsClientServer.SubstituteParametersInString(PatternName,
			Company, EDExchangeMethod);
			
		NewSettingsProfile.Company              = Company;
		NewSettingsProfile.CompanyID = TrimAll(CompanyID);
		NewSettingsProfile.EDExchangeMethod           = EDExchangeMethod;
		
		// Certificate settings
		If ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseDigitalSignatures") Then
			If EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
				OR UseDS Then
				
				If Not CommonUseReUse.DataSeparationEnabled() Then
					Constants.AuthorizationContext.Set(AuthorizationContext);
					Constants.CreateDigitalSignaturesAtServer.Set(CryptographyContext);
				EndIf;
				
				NewRow = NewSettingsProfile.CompanySignatureCertificates.Add();
				NewRow.Certificate = CryptoCertificate;
			EndIf;
		EndIf;
		
		// Importing PM from the EDF settings profile.
		EDActualKinds = ElectronicDocumentsReUse.GetEDActualKinds();
		For Each EnumValue IN EDActualKinds Do
			If EnumValue <> Enums.EDKinds.Confirmation
				AND EnumValue <> Enums.EDKinds.ProductsReturnBetweenCompanies
				AND EnumValue <> Enums.EDKinds.GoodsTransferBetweenCompanies
				AND EnumValue <> Enums.EDKinds.Confirmation
				AND EnumValue <> Enums.EDKinds.NotificationAboutClarification
				AND EnumValue <> Enums.EDKinds.Error
				AND EnumValue <> Enums.EDKinds.NotificationAboutReception
				AND EnumValue <> Enums.EDKinds.PaymentOrder
				AND EnumValue <> Enums.EDKinds.QueryStatement
				AND EnumValue <> Enums.EDKinds.BankStatement
				AND EnumValue <> Enums.EDKinds.CancellationOffer Then
				
				NewRow = NewSettingsProfile.OutgoingDocuments.Add();
				NewRow.ToForm = True;
				NewRow.OutgoingDocument = EnumValue;
				
				If ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
					"UseDigitalSignatures") Then
					NewRow.UseDS = True;
				EndIf;
				
				If (EnumValue = Enums.EDKinds.CustomerInvoiceNote
					OR EnumValue = Enums.EDKinds.CorrectiveInvoiceNote)
					AND EDExchangeMethod <> Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
					
					NewRow.ToForm = False;
					NewRow.UseDS = False;
					
				EndIf;
				// Put the exchange format version in the new EDF settings.
				FormatVersion = "CML 2.08";
				If EnumValue = Enums.EDKinds.RandomED Then
					FormatVersion = "";
				ElsIf EnumValue = Enums.EDKinds.ActCustomer
					OR EnumValue = Enums.EDKinds.ActPerformer
					OR EnumValue = Enums.EDKinds.TORG12Customer
					OR EnumValue = Enums.EDKinds.TORG12Seller
					OR EnumValue = Enums.EDKinds.AgreementAboutCostChangeSender
					OR EnumValue = Enums.EDKinds.AgreementAboutCostChangeRecipient
					OR EnumValue = Enums.EDKinds.CustomerInvoiceNote
					OR EnumValue = Enums.EDKinds.CorrectiveInvoiceNote Then
					FormatVersion = "Federal Tax Service 5.01";
				EndIf;
				NewRow.FormatVersion = FormatVersion;
			EndIf;
		EndDo;
		
		NewSettingsProfile.OutgoingDocuments.Sort("OutgoingDocument");
		
		// ED exchange settings
		If EDExchangeMethod = Enums.EDExchangeMethods.ThroughDirectory Then
			NewSettingsProfile.IncomingDocumentsResource = IncomingDocumentsDir;
			
		ElsIf EDExchangeMethod = Enums.EDExchangeMethods.ThroughEMail Then
			NewSettingsProfile.IncomingDocumentsResource = CompanyEmail;
		
		ElsIf EDExchangeMethod = Enums.EDExchangeMethods.ThroughFTP Then
			NewSettingsProfile.ServerAddress             = FTPServerAddress;
			NewSettingsProfile.Port                     = FTPPort;
			NewSettingsProfile.PassiveConnection      = PassiveFTPConnection;
			NewSettingsProfile.Login                    = FTPUser;
			NewSettingsProfile.Password                   = FTPPassword;
			NewSettingsProfile.IncomingDocumentsResource = FTPIncomingDocumentsDir;
		EndIf;
		
		If NewSettingsProfile.EDFProfileSettingsIsUnique() Then
			NewSettingsProfile.Write();
		Else
			RollbackTransaction();
			DataSaved = False;
			Return;
		EndIf;
		SettingsProfileRef = NewSettingsProfile.Ref;
		CommitTransaction();
		
		SetDateExchangeStatus(SettingsProfileRef);
		
		RefreshReusableValues();
	Except
		RollbackTransaction();
		DataSaved = False;
		CommonUseClientServer.MessageToUser(ErrorDescription());
	EndTry
	
EndProcedure

&AtServer
Procedure SetDateExchangeStatus(SettingsProfileRef)
	
	If Not EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
		Return;
	EndIf;
	
	RecordSet = InformationRegisters.EDExchangeStatesThroughEDFOperators.CreateRecordSet();
	RecordSet.Filter.EDFProfileSettings.Set(SettingsProfileRef);
	RecordSet.Read();
	
	NewRecord = RecordSet.Add();
	NewRecord.EDDateReceived = BegOfDay(CurrentSessionDate());
	NewRecord.EDFProfileSettings = SettingsProfileRef;
	RecordSet.Write();
	
EndProcedure

&AtClient
Procedure CertificateTest(Cancel, ValidateAuthorization = False)
	
	AdditionalParameters = New Structure;
	CompletionProcessing = New NotifyDescription("ActionsAfterCertificateTest", ThisObject, AdditionalParameters);
	
	ElectronicDocumentsServiceClient.CertificateValidationSettingsTest(CryptoCertificate,
		CompletionProcessing, ValidateAuthorization, ThisForm, True, True);
	
EndProcedure

&AtClient
Procedure ActionsAfterCertificateTest(Result, AdditParameters = Undefined) Export
	
	ResultStructure = Undefined;
	If Result = True Then
		CreateNewProfile();
	EndIf;
	
EndProcedure

// Exchange through directory

&AtServerNoContext
Procedure TestLinksDirectExchangeAtServer(IncomingDocumentsDir, Cancel)
	
	// Block of checking the access to directories.
	Try
		If Not ElectronicDocumentsServiceCallServer.ValidateCatalogAvailabilityForDirectExchange(IncomingDocumentsDir) Then
			ErrorText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("107");
			CommonUseClientServer.MessageToUser(ErrorText);
			Cancel = True;
		EndIf;
	Except
		ErrorText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("107");
		CommonUseClientServer.MessageToUser(ErrorText);
		Cancel = True;
	EndTry;
	
EndProcedure

// Exchange via FTP

&AtServer
Procedure ExchangeConnectionTestThroughFTPOnServer(Cancel)
	
	UseProxy = False;
	
	ProxyServerSetting = GetFilesFromInternet.ProxySettingsOnServer();
	If ProxyServerSetting <> Undefined Then
		ParameterUseProxy = ProxyServerSetting.Get("UseProxy");
		If Not ParameterUseProxy=Undefined Then
			UseProxy = ParameterUseProxy;
		EndIf;
	EndIf;
	
	If UseProxy Then
		If ProxyServerSetting.Get("UseSystemSettings") Then
			// System proxy settings.
			Proxy = New InternetProxy(True);
		Else
			// Manual proxy settings.
			Proxy = New InternetProxy;
			Proxy.Set("ftp", ProxyServerSetting["Server"], ProxyServerSetting["Port"]);
			Proxy.BypassProxyOnLocal = ProxyServerSetting["BypassProxyOnLocal"];
			Proxy.User = ProxyServerSetting["User"];
			Proxy.Password = ProxyServerSetting["Password"];
		EndIf;
	Else
		Proxy = New InternetProxy(False);
	EndIf;
	
	Try
		FTPConnection = New FTPConnection(FTPServerAddress,
											FTPPort,
											FTPUser,
											FTPPassword,
											Proxy,
											PassiveFTPConnection);
	Except
		ErrorText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("121");
		CommonUseClientServer.MessageToUser(ErrorText);
		Cancel = True;
		Return;
	EndTry;
	
	Try
		ElectronicDocumentsService.PrepareFTPPath(FTPIncomingDocumentsDir);
		FTPConnection.SetCurrentDirectory(FTPIncomingDocumentsDir);
	Except
		CreateFTPDirectories(FTPConnection, FTPIncomingDocumentsDir, True, ErrorText);
	EndTry;
	
	If ValueIsFilled(ErrorText) Then
		CommonUseClientServer.MessageToUser(ErrorText);
		Cancel = True;
		Return;
	EndIf;
	
	CheckFile(FTPConnection, ErrorText);
	If ValueIsFilled(ErrorText) Then
		CommonUseClientServer.MessageToUser(ErrorText);
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckFile(FTPConnection, ErrorText)
	
	TempFile = GetTempFileName();
	TextDocument = New TextDocument();
	TestString = "Test row 1C:Enterprise";
	TextDocument.SetText(TestString);
	TextDocument.Write(TempFile);
	FileTest = New File(TempFile);
		
	WriteFileOnFTP(FTPConnection, TempFile, FileTest.Name, True, ErrorText);
	DeleteFiles(TempFile);
	If ValueIsFilled(ErrorText) Then
		Return;
	EndIf;
	
	FileRecipient = GetTempFileName();
	
	GetFileFromFTP(FTPConnection, FileTest.Name, FileRecipient, True, ErrorText);
	
	If ValueIsFilled(ErrorText) Then
		DeleteFiles(FileRecipient);
		Return;
	EndIf;
		
	TextDocument = New TextDocument;
	TextDocument.Read(FileRecipient);
	ResultRow = TextDocument.GetText();
	DeleteFiles(FileRecipient);
	If Not ResultRow = TestString Then
		MessagePattern = NStr("en='%1 %2.';ru='%1 %2.'");
		MessageText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("126");
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, MessageText,
			FTPConnection.GetCurrentDirectory());
		Return;
	EndIf;
	
	DeleteFileFTP(FTPConnection, FileTest.Name, True, ErrorText);
	
EndProcedure

&AtServer
Procedure CreateFTPDirectories(FTPConnection, FullPath, IsTest = False, ErrorText = Undefined) Export
	
	FullPath = StrReplace(FullPath, "\", "/");
	DirectoriesArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FullPath, "/", True);
	CurrentPath = "/";
	FTPConnection.SetCurrentDirectory(CurrentPath);
	For Each Item IN DirectoriesArray Do
		
		mDirectory = New Array;
		
		FindFilesInFTPDirectory(FTPConnection, Item, Undefined, True, ErrorText, mDirectory);
		
		If ValueIsFilled(ErrorText) Then
			Return;
		EndIf;
		
		If mDirectory.Count() = 1 Then 
			If mDirectory[0].IsFile() Then 
				ErrorText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("122");
				If Not IsTest Then
					CommonUseClientServer.MessageToUser(ErrorText);
				EndIf;
				Return;
			EndIf;
			CreateDirectory = False;
		Else
			CreateDirectory = True;
		EndIf;

		If CreateDirectory Then
			Try
				FTPConnection.CreateDirectory(Item);
				CurrentPath = CurrentPath + Item + "/";
			Except
				ErrorText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("123");
				If Not IsTest Then
					CommonUseClientServer.MessageToUser(ErrorText);
				EndIf;
				Return;
			EndTry
		EndIf;
		
		Try
			FTPConnection.SetCurrentDirectory(CurrentPath);
		Except
			ErrorText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("124");
			If Not IsTest Then
				CommonUseClientServer.MessageToUser(ErrorText);
			EndIf;
		EndTry
		
	EndDo;
	
EndProcedure

&AtServer
Procedure WriteFileOnFTP(FTPConnection,
							Source,
							OutgoingFileName,
							IsTest = False,
							TestResult = Undefined) Export
	
	Try
		FTPConnection.Write(Source, OutgoingFileName);
	Except
		TestResult = ElectronicDocumentsServiceCallServer.GetMessageAboutError("127");
		
		If Not IsTest Then
			CommonUseClientServer.MessageToUser(TestResult);
		EndIf;
	EndTry;

EndProcedure

&AtServer
Procedure GetFileFromFTP(FTPConnection, Source, OutgoingFileName, IsTest = False, TestResult = Undefined)
	
	Try
		FTPConnection.Get(Source, OutgoingFileName);
	Except
		TestResult = ElectronicDocumentsServiceCallServer.GetMessageAboutError("128");
		
		If Not IsTest Then
			CommonUseClientServer.MessageToUser(TestResult);
		EndIf;
	EndTry;
	
EndProcedure

&AtServer
Procedure FindFilesInFTPDirectory(FTPConnection, Path, Mask, IsTest, TestResult, FilesArray)
	
	Try
		If Mask = Undefined Then
			FilesArray = FTPConnection.FindFiles(Path);
		Else
			FilesArray = FTPConnection.FindFiles(Path, Mask);
		EndIf;
	Except
		TestResult = ElectronicDocumentsServiceCallServer.GetMessageAboutError("125");
		
		If Not IsTest = True Then
			CommonUseClientServer.MessageToUser(TestResult);
		EndIf;
	EndTry;
	
EndProcedure

&AtServer
Procedure DeleteFileFTP(FTPConnection, Path, TestResult = Undefined, IsTest = False)
		
	Try
		FTPConnection.Delete(Path);
	Except
		TestResult = ElectronicDocumentsServiceCallServer.GetMessageAboutError("129");
		
		If Not IsTest Then
			CommonUseClientServer.MessageToUser(TestResult);
		EndIf;
	EndTry;
	
EndProcedure


&AtClient
Procedure CreateNewProfile()
	
	DataSaved = True;
	SaveParameters(DataSaved);
	If DataSaved Then
		ShowUserNotification("Creating",
		GetURL(SettingsProfileRef),
			SettingsProfileRef);
		FormParameters = New Structure;
		FormParameters.Insert("Key", SettingsProfileRef);
		OpenForm("Catalog.EDFProfileSettings.Form.ItemForm", FormParameters);
		
		Notify("RefreshStateED");
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region AsynchronousDialogsHandlers

&AtClient
Procedure CompleteBeforeClosing(Val Result, Val AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		CloseForm = True;
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure CompanyOnChangeComplete(Val Result, Val AdditionalParameters) Export
	
	If ValueIsFilled(Result) Then
		If Result = DialogReturnCode.Yes Then
			SetIdentifier("Companies", Company);
		EndIf;
	EndIf;
	
	SetDefaultValues();
	
EndProcedure

&AtClient
Procedure UseDSOnChangeComplete(Val Result, Val AdditionalParameters) Export
	
	If ValueIsFilled(Result) Then
		If Result = DialogReturnCode.Yes Then
			CryptoCertificate = PredefinedValue("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef");
			If EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom")
				AND ElectronicDocumentsServiceClient.CheckUsingUsersInternetSupport() Then
				CompanyID = "";
				Items.CaptionIDOfParticipantExchangeED.Title = NStr("en='Obtain a unique identifier of the ED exchange participant';ru='Получить уникальный идентификатор участника обмена ЭД.'");
				ElementFont = Items.CaptionIDOfParticipantExchangeED.Font;
				Items.CaptionIDOfParticipantExchangeED.Font = New Font(ElementFont, , , False);
				Items.CaptionIDOfParticipantExchangeED.Hyperlink = True;
			EndIf;
		Else
			// Restore all as it was.
			UseDS = Not UseDS;
		EndIf;
	EndIf;
	
	FormManagement(ThisForm);
	
EndProcedure

&AtClient
Procedure AfterSelectingDirectory(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	If EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughDirectory") Then
		IncomingDocumentsDir = SelectedFiles[0];
	ElsIf EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughFTP") Then
		FTPIncomingDocumentsDir = SelectedFiles[0];
	EndIf;
	ElectronicDocumentsServiceCallServer.ValidateCatalogAvailabilityForDirectExchange(SelectedFiles[0]);

EndProcedure

#EndRegion













