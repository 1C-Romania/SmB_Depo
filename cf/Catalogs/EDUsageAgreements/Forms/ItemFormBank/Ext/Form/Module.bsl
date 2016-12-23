

#Region FormEventsHandlers
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("WindowOpeningMode") Then
		WindowOpeningMode = Parameters.WindowOpeningMode;
	EndIf;
	
	ElementObject = FormAttributeToValue("Object");
	
	If Not ValueIsFilled(Object.Ref) Then // New
		Object.AgreementStatus = Enums.EDAgreementsStatuses.NotAgreed;
		Object.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource;
		Object.IncomingDocumentsResource = "";
		Object.BankApplication = Enums.BankApplications.AsynchronousExchange;
		Object.CryptographyIsUsed = False;
		IsNew = True;
		FillPropertyValues(Object, Parameters);
		If ValueIsFilled(Object.Counterparty) Then
			BankApplication = GetBankApplication(Object.Counterparty);
			If ValueIsFilled(BankApplication) Then
				Object.BankApplication = BankApplication;
				Items.TypeOfBankingSystem.Visible = False;
			EndIf;
			Object.CryptographyIsUsed = CryptographyIsUsed(Object.BankApplication);
			FillEDTypesAvailableValues();
			RefreshTabularSections(Object.CryptographyIsUsed, Object.IncomingDocuments, Object.OutgoingDocuments);
		EndIf;
	ElsIf Object.BankApplication = Enums.BankApplications.SberbankOnline Then
		DocumentObject = FormAttributeToValue("Object");
		Try
			CertificateBinaryData  = DocumentObject.CounterpartyCertificateForEncryption.Get();
			If CertificateBinaryData <> Undefined Then
				CryptoCertificate = New CryptoCertificate(CertificateBinaryData);
				BankSertificates = DigitalSignatureClientServer.SubjectPresentation(CryptoCertificate);
			EndIf;
		Except
			MessageText = BriefErrorDescription(ErrorInfo())
							+ NStr("en=' (see details in Event log monitor).';ru=' (подробности см. в Журнале регистрации).'");
			ErrorText = DetailErrorDescription(ErrorInfo());
			Operation = NStr("en='the agreement form opening';ru='открытие формы соглашения'");
			ElectronicDocuments.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
		EndTry;
		Items.TypeOfBankingSystem.Visible = False;
	ElsIf ValueIsFilled(Object.Counterparty) Then
		BankApplication = GetBankApplication(Object.Counterparty);
		Items.TypeOfBankingSystem.Visible = Not ValueIsFilled(BankApplication);
	EndIf;
	
	If ValueIsFilled(Parameters.CompletingSettings) Then
		FillAgreementSettings(Parameters.CompletingSettings);
		FillEDTypesAvailableValues();
		RefreshTabularSections(Object.CryptographyIsUsed, Object.IncomingDocuments, Object.OutgoingDocuments);
		Items.TypeOfBankingSystem.Visible = False;
	EndIf;
	
	If Not ValueIsFilled(Object.Counterparty) Then
		Object.Counterparty = ElectronicDocumentsReUse.GetEmptyRef("Banks");
	EndIf;
	
	Items.PagesKindsOfBankingSystems.PagesRepresentation = FormPagesRepresentation.None;
			
	AuthorizationVariant = Number(Object.CryptographyIsUsed);
	
	IncorporatedAdditionalReportsAndDataProcessors = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
																			"UseAdditionalReportsAndDataProcessors");
	
	Items.AdditionalInformationProcessor.Enabled = IncorporatedAdditionalReportsAndDataProcessors;
	
	PageSelector(ThisObject, Object.BankApplication, Object.CryptographyIsUsed);
	Items.AuthorizationVariant.ReadOnly = ThisObject.ReadOnly;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	PageSelector(ThisObject, Object.BankApplication, Object.CryptographyIsUsed);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(Parameters.CompletingSettings) Then
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	ClearMessages();
	
	If Object.AgreementStatus = PredefinedValue("Enum.EDAgreementsStatuses.Acts") Then
		TextActualityError = "";
		CheckRelevanceDataAgreement(TextActualityError);
		If Not IsBlankString(TextActualityError) Then
			CommonUseClientServer.MessageToUser(TextActualityError, , , , Cancel);
		EndIf;
	EndIf;
	
	Object.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughBankWebSource");
	
	If ValueIsFilled(Object.ServerAddress) AND Not CorrectAddressFormat()
		AND Object.AgreementStatus = PredefinedValue("Enum.EDAgreementsStatuses.Acts") Then
		
		MessageText = NStr("en='Bank server address must start with """"https://"""" or """"http://""""';ru='Адрес сервера банка должен начинаться с """"https://"""" или """"http://""""'");
		CommonUseClientServer.MessageToUser(MessageText, , "ServerAddress", "Object", Cancel);
		
	EndIf;
	
	RemoveEmptyLinesTables();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("ChangedAgreementED", Object.Ref);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If IsNew Then
		
		Manager = InformationRegisters.BankEDExchangeStates.CreateRecordManager();
		Manager.EDFSetup = Object.Ref;
		Manager.LastEDDateReceived = CurrentSessionDate();
		Manager.Write();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure BankOnChange(Item)
	
	If ValueIsFilled(Object.Counterparty) Then
		BankApplication = GetBankApplication(Object.Counterparty);
	EndIf;
	If ValueIsFilled(BankApplication) Then
		Object.BankApplication = BankApplication;
		Items.TypeOfBankingSystem.Visible = False;
		TypeOfBankingSystemOnChange(Undefined)
	Else
		Items.TypeOfBankingSystem.Visible = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure TypeOfBankingSystemOnChange(Item)
	
	Object.CryptographyIsUsed = CryptographyIsUsed(Object.BankApplication);
	PageSelector(ThisObject, Object.BankApplication, Object.CryptographyIsUsed);
	
	If Object.BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
		IncorporatedAdditionalReportsAndDataProcessors = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
																			"UseAdditionalReportsAndDataProcessors");
		If Not IncorporatedAdditionalReportsAndDataProcessors Then
			MessageText = ElectronicDocumentsServiceCallServer.MessageTextAboutSystemSettingRequirement(
																					"ADDITIONALREPORTSANDDATAPROCESSORS");
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	FillEDTypesAvailableValues();
	RefreshTabularSections(Object.CryptographyIsUsed, Object.IncomingDocuments, Object.OutgoingDocuments);
	
EndProcedure

&AtClient
Procedure BankSertificatesOnChange(Item)
	
	If IsBlankString(Item.EditText) Then
		PutInCertificateRepositoryConfiguration();
	EndIf;
	
EndProcedure

&AtClient
Procedure BankSertificatesStartChoice(Item, ChoiceData, StandardProcessing)
	
	If RecordedAgreement("ExecuteBankCertificateImport") Then
		ExecuteBankCertificateImport(DialogReturnCode.Yes);
	EndIf;

EndProcedure

&AtClient
Procedure BankSertificateClear(Item, StandardProcessing)
	
	PutInCertificateRepositoryConfiguration();
	
EndProcedure

&AtClient
Procedure AuthorizationVariantOnChange(Item)
	
	Object.CryptographyIsUsed = Boolean(AuthorizationVariant);
	PageSelector(ThisObject, Object.BankApplication, Object.CryptographyIsUsed);
	RefreshTabularSections(Object.CryptographyIsUsed, Object.IncomingDocuments, Object.OutgoingDocuments);
	
EndProcedure

#EndRegion

#Region ItemEventsHandlersFormTablesCertificatesSignaturesCompaniesDataProcessor

&AtClient
Procedure CertificatesCompanySignatureDataProcessorChoiceProcessing(Item, ValueSelected, StandardProcessing)

	ExternalAttachableModule = ElectronicDocumentsServiceClient.ExternalConnectedModuleThroughAdditionalDataProcessor(
																											Object.Ref);
	If ExternalAttachableModule = Undefined Then
		Return;
	EndIf;
	CertificateData = ElectronicDocumentsServiceClient.CertificateDataThroughAdditionalDataProcessor(
															ExternalAttachableModule, ValueSelected);
	
	If Not ValueIsFilled(CertificateData) Then
		Return;
	EndIf;
	
	NewCertificate = NewCertificate(ValueSelected, CertificateData, Object.Company, Object.BankApplication);
	
	AgreementLine = Object.CompanySignatureCertificates.Add();
	AgreementLine.Certificate = NewCertificate;
	Modified = True;
	
EndProcedure

#EndRegion

#Region ItemEventsHandlersFormTablesCertificatesSignaturesCompaniesComponent

&AtClient
Procedure CertificatesCompanySignaturesComponentChoiceDataProcessor(Item, ValueSelected, StandardProcessing)
	
	CertificateData = ElectronicDocumentsServiceClient.iBank2CertificateData(ValueSelected);
		
	If Not ValueIsFilled(CertificateData) Then
		Return;
	EndIf;
	
	NewCertificate = NewCertificate(ValueSelected, CertificateData, Object.Company, Object.BankApplication);
	
	AgreementLine = Object.CompanySignatureCertificates.Add();
	AgreementLine.Certificate = NewCertificate;
	Modified = True;

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure AuditLog(Command)

	OpenForm("InformationRegister.AuditLogbookSberbank.ListForm", New Structure("EDAgreement", Object.Ref));
	
EndProcedure

&AtClient
Procedure ImportCertificate(Command)
	
	Cancel = False;
	
	If Not ValueIsFilled(Object.Company) Then
		MessageText = NStr("en='Select a company';ru='Необходимо выбрать организацию'");
		CommonUseClientServer.MessageToUser(MessageText, , "Object.Company", , Cancel);
	EndIf;
	
	If Object.BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor")
			AND Not ValueIsFilled(Object.AdditionalInformationProcessor) Then
		MessageText = NStr("en='Select an additional data processor';ru='Необходимо выбрать дополнительную обработку'");
		CommonUseClientServer.MessageToUser(MessageText, , "Object.AdditionalInformationProcessor", , Cancel);
	EndIf;

	If Cancel OR Not RecordedAgreement("ExecuteCertificateImport") Then
		Return;
	Else
		ExecuteCertificateImport(DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingsTest(Command)
	
	ClearMessages();
	
	If Object.BankApplication = PredefinedValue("Enum.BankApplications.SberbankOnline") Then
		#If WebClient Then
			MessageText = NStr("en='Test is not possible in Web client';ru='Тест не возможен в веб-клиенте'");
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		#EndIf
	EndIf;
	
	NotifyDescription = New NotifyDescription("TestEDFSettings", ThisObject);
	If Modified OR Not ValueIsFilled(Object.Ref) Then
		QuestionText = NStr("en='Save the current EDF setting. Do you want to continue the test?';ru='Необходимо сохранить текущую настройку ЭДО. Продолжить выполнение теста?'");
		ButtonList = New ValueList();
		ButtonList.Add(True, NStr("en='Save and perform the test';ru='Сохранить и выполнить тест'"));
		ButtonList.Add(False, NStr("en='Cancel the test';ru='Отменить тест'"));
		ShowQueryBox(NOTifyDescription, QuestionText, ButtonList, , True, NStr("en='Test settings';ru='Тест настроек'"));
	Else
		TestEDFSettings();
	EndIf;

EndProcedure

&AtClient
Procedure DataRequestStartDate(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("EDAgreement", Object.Ref);
	FormParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	OpenForm("InformationRegister.BankEDExchangeStates.Form.EditRecord", FormParameters, ThisForm);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure TestEDFSettings(Result = Undefined, AdditionalParameters = Undefined) Export
	
	If Result = True Then
		Write();
	ElsIf Result = False Then
		Return;
	EndIf;
	
	If Not ElectronicDocumentsClientServer.FilledAttributesSettingsEDFWithBanks(Object, True) Then
		Return;
	EndIf;
		
	If Object.BankApplication = PredefinedValue("Enum.BankApplications.SberbankOnline") Then
		#If WebClient Then
			MessageText = NStr("en='Test is not possible in WEB client';ru='Тест не возможен в WEB-клиенте'");
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		#EndIf
	EndIf;
	
	ElectronicDocumentsServiceClient.ValidateExistenceOfLinksWithBank(
		Object.Ref, UUID);

EndProcedure

&AtClient
Procedure ExecuteCertificateImport(Result, Parameters = Undefined) Export
	
	If Result = DialogReturnCode.Yes Then
		WriteAgreement();
		If Object.BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
			StartImportCertificateThroughAdditionalProcessing();
		ElsIf Object.BankApplication = PredefinedValue("Enum.BankApplications.iBank2") Then
			AdditionalParameters = New Structure("EDAgreement", Object.Ref);
			ND = New NotifyDescription("StartImportiBank2Certificate", ThisObject, AdditionalParameters);
			AdditionalParameters.Insert("HandlerAfterConnectingComponents", ND);
			ElectronicDocumentsServiceClient.EnableExternalComponentiBank2(AdditionalParameters);
		ElsIf Object.BankApplication = PredefinedValue("Enum.BankApplications.SberbankOnline") Then
			GetCertificateDataOnSberbankToken();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure StartImportiBank2Certificate(ExternalAttachableModule, Parameters = Undefined) Export
	
	If ExternalAttachableModule = Undefined Then
		Return;
	EndIf;
	
	Device = ElectronicDocumentsServiceClient.ConnectediBank2Storages();
	If Device=Undefined OR Device.Count() = 0 Then
		Return;
	EndIf;
	
	If Device.Count() = 1 Then
		StorageIdentifier = Device[0];
		ProcessingiBank2StorageSelection(StorageIdentifier);
	Else
		ND = New NotifyDescription("ProcessingiBank2StorageSelection", ThisObject);
		ElectronicDocumentsServiceClient.ChooseiBank2Storage(Object.Ref, ND);
	EndIf;

EndProcedure

&AtClient
Procedure StartImportCertificateThroughAdditionalProcessing(ProcessingParameters = Undefined) Export
	
	ExternalAttachableModule = ElectronicDocumentsServiceClient.ExternalConnectedModuleThroughAdditionalDataProcessor(
																										Object.Ref);
	If ExternalAttachableModule = Undefined Then
		ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
		If ExchangeWithBanksSubsystemsParameters <> Undefined Then
			AgreementParameters = ExchangeWithBanksSubsystemsParameters.Get(Object.Ref);
			If ValueIsFilled(AgreementParameters) AND AgreementParameters.Property("ComponentAddress") Then
				ProcessingParameters = New Structure;
				ProcessingParameters.Insert("CurrentEDAgreementThroughAdditionalDataProcessor", Object.Ref);
				ND = New NotifyDescription(
					"StartImportCertificateThroughAdditionalProcessing", ThisObject, ProcessingParameters);
				BeginInstallAddIn(ND, AgreementParameters.ComponentAddress);
				Return;
			EndIf;
		EndIf;
		Return;
	EndIf;
	
	Device = ElectronicDocumentsServiceClient.ConnectedStoragesThroughAdditionalDataProcessor(
																			ExternalAttachableModule);
	If Device=Undefined OR Device.Count() = 0 Then
		Return;
	EndIf;

	TokenSelectionParameters = New Structure;
	TokenSelectionParameters.Insert("ExternalAttachableModule", ExternalAttachableModule);
	
	If Device.Count() = 1 Then
		StorageIdentifier = Device[0];
		ChoiceStoragesProcessingThroughAdditionalProcessing(StorageIdentifier, TokenSelectionParameters);
	Else
		ND = New NotifyDescription("ChoiceStoragesProcessingThroughAdditionalProcessing", ThisObject, TokenSelectionParameters);
		ElectronicDocumentsServiceClient.ChooseStorageThroughAdditionalDataProcessor(Object.Ref, ND, TokenSelectionParameters);
	EndIf;

EndProcedure

&AtClient
Procedure ChoiceStoragesProcessingThroughAdditionalProcessing(StorageIdentifier, ProcessingParameters) Export
	
	If Not ValueIsFilled(StorageIdentifier) Then
		Return;
	EndIf;
		
	ProcessingParameters.Insert("StorageIdentifier", StorageIdentifier);
	
	ExternalAttachableModule = ProcessingParameters.ExternalAttachableModule;
	
	PINCodeRequired = ElectronicDocumentsServiceClient.NeedToSetStoragePINCodeThroughAdditionalDataProcessor(
		ExternalAttachableModule, StorageIdentifier);
		
	If PINCodeRequired = Undefined Then
		Return;
	ElsIf PINCodeRequired Then
		OnCloseNotifyDescription = New NotifyDescription(
			"ContinueReceivingCertificateAfterEnteringPinCode", ThisObject, ProcessingParameters);
		ElectronicDocumentsServiceClient.StartInstallationPINStorages(
			Object.Ref, StorageIdentifier, OnCloseNotifyDescription);
		Return;
	EndIf;
	
	ContinueReceivingCertificate(ProcessingParameters)
	
EndProcedure

&AtClient
Procedure ExecuteBankCertificateImport(Result, Parameters = Undefined) Export
	
	If Result = DialogReturnCode.Yes Then
		WriteAgreement();
		
		AddressInStorage = Undefined;
		Handler = New NotifyDescription("ProcessingFileCertificateChoiceBank", ThisObject);
		BeginPutFile(Handler, AddressInStorage, "*.cer", True, UUID);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessingFileCertificateChoiceBank(Result, Address, FileName, AdditionalParameters) Export
	
	If Result = True Then
		PlaceCertificateInAgreement(Address);
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillEDTypesAvailableValues()
	
	EDActualKinds = ElectronicDocumentsReUse.GetEDActualKinds();
	
	EDKindsArray = New Array;
	CommonUseClientServer.SupplementArray(EDKindsArray, EDActualKinds);
	
	EDKindsArray.Add(Enums.EDKinds.EDReturnQuery);
	EDKindsArray.Add(Enums.EDKinds.QueryProbe);
	EDKindsArray.Add(Enums.EDKinds.EDStateQuery);
	
	For Each EnumValue IN EDKindsArray Do
		If EnumValue = Enums.EDKinds.PaymentOrder
			OR EnumValue = Enums.EDKinds.QueryStatement
			OR EnumValue = Enums.EDKinds.QueryProbe
			OR EnumValue = Enums.EDKinds.EDReturnQuery
			OR EnumValue = Enums.EDKinds.EDStateQuery Then
				RowArray = Object.OutgoingDocuments.FindRows(New Structure("OutgoingDocument", EnumValue));
				If RowArray.Count() = 0 Then 
					NewRow = Object.OutgoingDocuments.Add();
					NewRow.OutgoingDocument = EnumValue;
					NewRow.ToForm = True;
					NewRow.UseDS = Object.CryptographyIsUsed;
				EndIf;
			ElsIf EnumValue = Enums.EDKinds.BankStatement
				OR EnumValue = Enums.EDKinds.NotificationOnStatusOfED Then
				RowArray = Object.IncomingDocuments.FindRows(New Structure("IncomingDocument", EnumValue));
				If RowArray.Count() = 0 Then 
					NewRow = Object.IncomingDocuments.Add();
					NewRow.IncomingDocument = EnumValue;
					NewRow.ToForm = True;
					NewRow.UseDS = Object.CryptographyIsUsed;
				EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure CheckRelevanceDataAgreement(TextActualityError)
	
	QueryByAgreements = New Query;
	QueryByAgreements.SetParameter("AgreementStatus",  Enums.EDAgreementsStatuses.Acts);
	QueryByAgreements.SetParameter("CurrentAgreement", Object.Ref);
	QueryByAgreements.SetParameter("Company",       Object.Company);
	QueryByAgreements.SetParameter("Counterparty",        Object.Counterparty);
	QueryByAgreements.Text = "SELECT
	                            |	EDUsageAgreementsOutgoingDocuments.OutgoingDocument AS DocumentType,
	                            |	EDUsageAgreementsOutgoingDocuments.Ref AS Agreement
	                            |FROM
	                            |	Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
	                            |WHERE
	                            |	EDUsageAgreementsOutgoingDocuments.ToForm = TRUE
	                            |	AND EDUsageAgreementsOutgoingDocuments.Ref.AgreementStatus = &AgreementStatus
	                            |	AND EDUsageAgreementsOutgoingDocuments.Ref.DeletionMark = FALSE
	                            |	AND EDUsageAgreementsOutgoingDocuments.Ref <> &CurrentAgreement
	                            |	AND EDUsageAgreementsOutgoingDocuments.Ref.Company = &Company
	                            |	AND EDUsageAgreementsOutgoingDocuments.Ref.Counterparty = &Counterparty
	                            |	AND EDUsageAgreementsOutgoingDocuments.Ref.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)";
	Result = QueryByAgreements.Execute().Unload();
	
	CheckDocumentsUniqueness(Object.OutgoingDocuments, Result, TextActualityError);
		
EndProcedure

&AtServer
Procedure CheckDocumentsUniqueness(TabularSectionDocuments, CheckResult, ErrorText)
			
	For Each CurrentDocumentOfAgreement IN TabularSectionDocuments Do
		If CurrentDocumentOfAgreement.ToForm Then
			For Each DocumentInOtherAgreements IN CheckResult Do
				If CurrentDocumentOfAgreement.OutgoingDocument = DocumentInOtherAgreements.DocumentType Then
					ErrorText = NStr("en='For a kind of documents %1
		|%2 a valid agreement already exists between parties %3
		|- %4: %5.
		|';ru='По виду электронных документов
		|%1 %2 уже существует действующее соглашение между
		|участниками %3 - %4: %5.
		|'");
					ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
						ErrorText, 
						DocumentInOtherAgreements.DocumentType, 
						"Outgoing", 
						Object.Company, 
						Object.Counterparty, 
						DocumentInOtherAgreements.Agreement
						);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Function CorrectAddressFormat()
	
	If Lower(Left(Object.ServerAddress, 7)) = "http://"
			OR Lower(Left(Object.ServerAddress, 8)) = "https://" Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

&AtClientAtServerNoContext
Procedure PageSelector(Form, Val BankApplication, Val CryptographyIsUsed)
	
	ThisSberbank = BankApplication = PredefinedValue("Enum.BankApplications.SberbankOnline");
	ThisExchangeThroughAdditionalProcessor = BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor");
	ThisAsynchronousExchange = BankApplication = PredefinedValue("Enum.BankApplications.AsynchronousExchange");
	ThisSynchronousExchange = BankApplication = PredefinedValue("Enum.BankApplications.AlphaBankOnline");
	ThisExchangeWithiBank2 = BankApplication = PredefinedValue("Enum.BankApplications.iBank2");
	
	Form.Items.DataExchangeSettings.ShowTitle = True;
	Form.Items.DataExchangeSettings.Representation = UsualGroupRepresentation.WeakSeparation;
	
	If ThisSynchronousExchange Then
		Form.Items.PagesKindsOfBankingSystems.CurrentPage = Form.Items.PageSynchronous;
		Form.Items.Login.Visible = Not Form.AuthorizationVariant;
		Form.Items.GroupCertificates.Visible = Form.AuthorizationVariant;
	ElsIf ThisSberbank Then
		Form.Items.PagesKindsOfBankingSystems.CurrentPage = Form.Items.SberBankPage;
	ElsIf ThisAsynchronousExchange Then
		Form.Items.PagesKindsOfBankingSystems.CurrentPage = Form.Items.PageAsynchronous;
	ElsIf ThisExchangeThroughAdditionalProcessor Then
		Form.Items.PagesKindsOfBankingSystems.CurrentPage = Form.Items.PageDataProcessor;
		IncorporatedAdditionalReportsAndDataProcessors = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
																				"UseAdditionalReportsAndDataProcessors");
		Form.Items.AdditionalInformationProcessor.Enabled = IncorporatedAdditionalReportsAndDataProcessors;
	ElsIf ThisExchangeWithiBank2 Then
		Form.Items.PagesKindsOfBankingSystems.CurrentPage = Form.Items.PageComponent;
		Form.Items.DataExchangeSettings.ShowTitle = False;
		Form.Items.DataExchangeSettings.Representation = UsualGroupRepresentation.None;
	EndIf;
	
	Form.Items.SettingsTest.Visible = Not ThisSynchronousExchange;
	Form.Items.AuditLog.Visible = ThisSberbank;
	Form.Items.DataRequestStartDate.Visible = ThisAsynchronousExchange;
	Form.AuthorizationVariant = CryptographyIsUsed;
	
EndProcedure

&AtClient
Procedure ContinueReceivingCertificate(ReceivingParameters)
	
	If Items.PagesKindsOfBankingSystems.CurrentPage = Items.PageComponent Then
		NotificationItem = Items.CompanySignatureCertificatesComponent;
	ElsIf Items.PagesKindsOfBankingSystems.CurrentPage = Items.PageDataProcessor Then
		NotificationItem = Items.CompanySignatureCertificatesDataProcessor;
	Else
		Return;
	EndIf;
	StorageIdentifier = ReceivingParameters.StorageIdentifier;
	
	OpenParameters = New Structure("EDAgreement, StorageIdentifier", Object.Ref, StorageIdentifier);
	OpenForm(
		"DataProcessor.ElectronicDocumentsExchangeWithBank.Form.ObtainingCertificate", OpenParameters, NotificationItem);
	
EndProcedure

&AtClient
Procedure ContinueReceivingCertificateAfterEnteringPinCode(PINCode, ReceivingParameters) Export
	
	StorageIdentifier = ReceivingParameters.StorageIdentifier;
	
	If PINCode = Undefined Then
		Return;
	EndIf;
	
	If Object.BankApplication = PredefinedValue("Enum.BankApplications.iBank2") Then
		PINIsSet = ElectronicDocumentsServiceClient.SetStoragePINCodeiBank2(StorageIdentifier, PINCode);
	Else
		ExternalAttachableModule = ElectronicDocumentsServiceClient.ExternalConnectedModuleThroughAdditionalDataProcessor(
																												Object.Ref);
		PINIsSet = ElectronicDocumentsServiceClient.SetStoragePINCodeThroughAdditionalDataProcessor(
														ExternalAttachableModule, StorageIdentifier, PINCode);
	EndIf;
	
	If Not PINIsSet Then
		Return;
	EndIf;
	
	ContinueReceivingCertificate(ReceivingParameters);
	
EndProcedure

&AtServer
Procedure RemoveEmptyLinesTables()
	
	ListStringForDeletion = New ValueList;
	For Each StringCertificate IN Object.CompanySignatureCertificates Do
		If Not ValueIsFilled(StringCertificate.Certificate) Then
			ListStringForDeletion.Add(StringCertificate.LineNumber);
		EndIf;
	EndDo;

	ListStringForDeletion.SortByValue(SortDirection.Desc);
	
	For Each Record IN ListStringForDeletion Do
		Object.CompanySignatureCertificates.Delete(Record.Value-1);
	EndDo

EndProcedure

&AtServer
Procedure PutInCertificateRepositoryConfiguration(BinaryData = Undefined, CertificatePresentation=Undefined)
	
	ValueStorage  = New ValueStorage(BinaryData);
	CatalogObject = FormAttributeToValue("Object");
	CatalogObject.CounterpartyCertificateForEncryption = ValueStorage;
	CatalogObject.Write();
	ValueToFormAttribute(CatalogObject, "Object");
	Read();
	
	If BinaryData <> Undefined Then
		Try
			CryptoCertificate = New CryptoCertificate(BinaryData);
		Except
			TempFile = GetTempFileName();
			Try
				BinaryData.Write(TempFile);
				TextDocument = New TextDocument;
				TextDocument.Read(TempFile);
				StringBase64 = TextDocument.GetText();
				StringBase64 = StrReplace(StringBase64, "-----BEGIN CERTIFICATE-----" + Chars.LF,""); 
				StringBase64 = StrReplace(StringBase64, Chars.LF + "-----END CERTIFICATE-----","");
				CertificateBinaryData = Base64Value(StringBase64);
				ValueStorage  = New ValueStorage(CertificateBinaryData);
				CatalogObject = FormAttributeToValue("Object");
				CatalogObject.CounterpartyCertificateForEncryption = ValueStorage;
				CatalogObject.Write();
				ValueToFormAttribute(CatalogObject, "Object");
				Read();
				CryptoCertificate = New CryptoCertificate(CertificateBinaryData);
			Except
				CatalogObject = FormAttributeToValue("Object");
				CatalogObject.CounterpartyCertificateForEncryption = Undefined;
				CatalogObject.Write();
				ValueToFormAttribute(CatalogObject, "Object");
				Read();
				DeleteFiles(TempFile);
				MessageText = NStr("en='Failed to read the certificate file, operation is terminated.';ru='Не удалось прочитать файл сертификата, операция прервана.'");
				CommonUseClientServer.MessageToUser(MessageText);
				CertificatePresentation = "";
				Return;
			EndTry;
			DeleteFiles(TempFile);
			
		EndTry;
		CertificatePresentation = DigitalSignatureClientServer.SubjectPresentation(CryptoCertificate);
	EndIf;
	
EndProcedure

&AtServer
Procedure WriteAgreement()
	
	CatalogObject = FormAttributeToValue("Object");
	CatalogObject.Write();
	ValueToFormAttribute(CatalogObject, "Object");
	
EndProcedure

&AtClient
Function RecordedAgreement(Handler)
	
	If ValueIsFilled(Object.Ref) AND Not Modified Then
		Return True;
	EndIf;
	
	QuestionText = NStr("en='You can export certificates using only the written EDF settings.
		|Record?';ru='Загружать сертификаты можно только в записанных настройках ЭДО.
		|Записать?'");
	
	op = New NotifyDescription(Handler, ThisObject);
	ShowQueryBox(op, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
	Return False;
	
EndFunction

&AtServer
Procedure PlaceCertificateInAgreement(TemporaryStorageAddress)
	
	FileData = GetFromTempStorage(TemporaryStorageAddress);
	CertificatePresentation = Undefined;
	PutInCertificateRepositoryConfiguration(FileData, CertificatePresentation);
	BankSertificates = CertificatePresentation;
	
EndProcedure

&AtClient
Procedure ProcessingiBank2StorageSelection(StorageIdentifier, ProcessingParameters = Undefined) Export
	
	If Not ValueIsFilled(StorageIdentifier) Then
		Return;
	EndIf;
	
	ProcessingParameters = New Structure;
	ProcessingParameters.Insert("StorageIdentifier", StorageIdentifier);
		
	PINCodeRequired = ElectronicDocumentsServiceClient.RequiredToSetStoragePINCodeiBank2(StorageIdentifier);
		
	If PINCodeRequired = Undefined Then
		Return;
	ElsIf PINCodeRequired Then
		OnCloseNotifyDescription = New NotifyDescription(
			"ContinueReceivingCertificateAfterEnteringPinCode", ThisObject, ProcessingParameters);
		ElectronicDocumentsServiceClient.StartInstallationPINStorages(
			Object.Ref, StorageIdentifier, OnCloseNotifyDescription);
		Return;
	EndIf;
	
	ContinueReceivingCertificate(ProcessingParameters)
	
EndProcedure

&AtServerNoContext
Function NewCertificate(Val KeyCertificateXML, Val CertificateData, Val Company, Val BankApplication)
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.SignedEDKinds");
	LockItem = Block.Add("InformationRegister.BankApplications");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
	
		NewCert = Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.CreateItem();
		NewCert.Position = CertificateData.OwnerPosition;
		ElectronicDocuments.SurnameInitialsOfIndividual(CertificateData.OwnerInitials,
													NewCert.Surname,
													NewCert.Name,
													NewCert.Patronymic);
		NewCert.ValidUntil  = CertificateData.EndDate;
		NewCert.Description    = CertificateData.OwnerInitials + " (" + CertificateData.Alias + ")";
		NewCert.Company     = Company;
		NewCert.CertificateData = New ValueStorage(KeyCertificateXML);
		NewCert.Imprint       = CertificateData.Imprint;
		NewCert.AddedBy         = UsersClientServer.CurrentUser();
		NewCert.Signing      = True;
		NewCert.IssuedToWhom       = CertificateData.OwnerInitials;
		NewCert.WhoIssued        = Undefined;
		NewCert.Write();
		
		RecordSet = InformationRegisters.DigitallySignedEDKinds.CreateRecordSet();
		RecordSet.Filter.DSCertificate.Set(NewCert.Ref);
		
		NewRecord = RecordSet.Add();
		NewRecord.Active = True;
		NewRecord.EDKind = Enums.EDKinds.PaymentOrder;
		NewRecord.Use = True;
		NewRecord.DSCertificate = NewCert.Ref;
		RecordSet.Write();
		
		RecordSet = InformationRegisters.BankApplications.CreateRecordSet();
		RecordSet.Filter.DSCertificate.Set(NewCert.Ref);
		RecordSet.Read();
		
		NewRecord = RecordSet.Add();
		NewRecord.Active = True;
		NewRecord.BankApplication = BankApplication;
		NewRecord.DSCertificate = NewCert.Ref;
		RecordSet.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	Return NewCert.Ref;
	
EndFunction

&AtClientAtServerNoContext
Procedure RefreshTabularSections(CryptographyIsUsed, IncomingDocuments, OutgoingDocuments)
	
	For Each String IN IncomingDocuments Do
		String.UseDS = CryptographyIsUsed;
	EndDo;
	
	For Each String IN OutgoingDocuments Do
		String.UseDS = CryptographyIsUsed;
	EndDo;
	
EndProcedure

&AtClient
Procedure GetCertificateDataOnSberbankToken()
	
	AuthorizationCompleted = False;
	ND = New NotifyDescription("GetSberbankCertificateIdentifier", ThisObject);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("AuthorizationCompleted", AuthorizationCompleted);
	HandlerParameters.Insert("ND", ND);
	HandlerParameters.Insert("ForcedAuthentication", True);
	ElectronicDocumentsServiceClient.ExecuteAuthenticationOnSberbankToken(Object.Ref, HandlerParameters);
	If Not HandlerParameters.AuthorizationCompleted Then
		Return;
	EndIf;
	
	GetSberbankCertificateIdentifier(Object.Ref);
	
EndProcedure

&AtClient
Procedure ProcessingSberbankCertificateSelection(IDCertificate, Parameters = Undefined) Export
	
	If Not ValueIsFilled(IDCertificate) Then
		Return;
	EndIf;
	
	CertificateBinaryData = SberbankCertificateBinaryData(IDCertificate);
	
	If CertificateBinaryData = Undefined Then
		Return;
	EndIf;
	
	Try
		NewCertificate = New CryptoCertificate(CertificateBinaryData);
	Except
		ShowMessageBox( , NStr("en='Failed to read the certificate file, operation is terminated.';ru='Не удалось прочитать файл сертификата, операция прервана.'"));
		Return;
	EndTry;
	
	CertificateStructure = DigitalSignatureClientServer.FillCertificateStructure(NewCertificate);
	
	CertificateStructure.Insert("CertificateBinaryData", CertificateBinaryData);
	CertificateStructure.Insert("Company", Object.Company);
	
	ErrorDescription = "";
	NewCertificate = CreateCertificate(CertificateStructure, ErrorDescription);
	If Not ValueIsFilled(NewCertificate) Then
		ShowMessageBox( , ErrorDescription);
		Return;
	EndIf;
	
	AgreementLine = Object.CompanySignatureCertificates.Add();
	AgreementLine.Certificate = NewCertificate;
	AgreementLine.NumberContainer = ElectronicDocumentsServiceClient.ValueFromCache("NumberContainer");
	
	Notify("UpdateCertificatesList");
	
EndProcedure

&AtServerNoContext
Function CreateCertificate(CertificateStructure, ErrorDescription)
	
	NewCertificate = ImportCertificateOnServer(CertificateStructure, ErrorDescription);
	
	If ValueIsFilled(NewCertificate) Then
		CertificateObject = NewCertificate.GetObject();
		NewRow = CertificateObject.DocumentKinds.Add();
		NewRow.DocumentKind = Enums.EDKinds.PaymentOrder;
		NewRow.UseToSign = True;
		NewRow = CertificateObject.DocumentKinds.Add();
		NewRow.DocumentKind = Enums.EDKinds.QueryStatement;
		NewRow.UseToSign = True;
		CertificateObject.BankApplication = Enums.BankApplications.SberbankOnline;
		CertificateObject.Write();
	EndIf;
	
	Return NewCertificate;
	
EndFunction

&AtServerNoContext
// Creates a new
// item in the "DSCertificates" catalog and fills it in with the passed data.
//
// Parameters:
//  CertificateStructure - data structure to fill
//  in a catalog item ErrorDescription - String - error description when it occurs.
//
Function ImportCertificateOnServer(CertificateStructure, ErrorDescription)
	
	NewItem = Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.CreateItem();
	NewItem.Imprint     = CertificateStructure.Imprint;
	NewItem.Description  = CertificateStructure.Company;
	NewItem.Company   = CertificateStructure.Company;
	NewItem.ValidUntil= CertificateStructure.ValidUntil;
	
	// Verification of the certificate for compliance to the Federal Law No. 63.
	SystemInfo = New SystemInfo;
	If CommonUseClientServer.CompareVersions(SystemInfo.AppVersion, "8.2.18.108") >= 0 Then
		NewCertificate = New CryptoCertificate(CertificateStructure.CertificateBinaryData);
		
		// Work correctly only with certificates in order to sign standard structure.
		If (NewCertificate.Subject.Property("SN") OR NewCertificate.Subject.Property("CN"))
			AND NewCertificate.Subject.Property("T") AND NewCertificate.Subject.Property("ST") Then
			
			If NewCertificate.Subject.Property("SN") Then
				
				TemplateOwnerNameAndSurname = NStr("en='%1 %2';ru='%1 %2'");
				NameAndSurnameOfOwner = StringFunctionsClientServer.PlaceParametersIntoString(TemplateOwnerNameAndSurname,
					NewCertificate.Subject.SN, NewCertificate.Subject.GN);
			ElsIf NewCertificate.Subject.Property("CN") Then
				
				NameAndSurnameOfOwner = NewCertificate.Subject.CN;
			EndIf;
			NewItem.Position = NewCertificate.Subject.T;
			
			ElectronicDocuments.SurnameInitialsOfIndividual(NameAndSurnameOfOwner, NewItem.Surname, NewItem.Name,
				NewItem.Patronymic);
			NewItem.Description  = CertificateStructure.IssuedToWhom;
		EndIf;
	EndIf;
	
	If CertificateStructure.Property("CertificateBinaryData")
		AND ValueIsFilled(CertificateStructure.CertificateBinaryData) Then
		
		StorageData = New ValueStorage(CertificateStructure.CertificateBinaryData, New Deflation(9));
		NewItem.CertificateData = StorageData;
		NewItem.Write();
		
		Return NewItem.Ref;
	Else
		ErrorDescription = NStr("en='Error of the signature certificate data receiving!';ru='Ошибка получения данных сертификата подписи!'");
		
		Return Undefined;
	EndIf;
	
EndFunction

&AtClient
Function SberbankCertificateBinaryData(IDCertificate)
	
	CertificateBase64 = "";
	AttachableModule = ElectronicDocumentsServiceClient.ValueFromCache("AttachableModule");
	Res = AttachableModule.GetCertificateVPNKeyTLS(IDCertificate, CertificateBase64);
	If Res <> 0 Then
		ClearMessages();
		MessageText = NStr("en='An error occurred while getting a certificate data.
		|details in the event log';ru='При получении данных сертификата произошла ошибка.
		|подробности в журнале регистрации'");
		ErrorText = NStr("en='AddIn.Bicrypt component has returned an error code at the certificate receiving';ru='Компонента AddIn.Bicrypt при получении сертификата вернула код ошибки'") + Res;
		Operation = NStr("en='Cryptography certificate receiving.';ru='Получение сертификата криптографии.'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
		Return Undefined;
	EndIf;
	CertificateBase64 = StrReplace(CertificateBase64, "-----BEGIN CERTIFICATE-----" + Chars.LF,""); 
	CertificateBase64 = StrReplace(CertificateBase64, Chars.LF + "-----END CERTIFICATE-----","");
	
	CertificateBinaryData = Base64Value(CertificateBase64);
	Return CertificateBinaryData;

EndFunction

&AtClient
Procedure GetSberbankCertificateIdentifier(EDAgreement, Parameters = Undefined) Export

	If Not ValueIsFilled(EDAgreement) Then
		Return;
	EndIf;
	
	IdentifiersCertificates = "";
	AttachableModule = ElectronicDocumentsServiceClient.ValueFromCache("AttachableModule");
	Res = AttachableModule.GetListIdentCertificatesVPNKeyTLS(0, IdentifiersCertificates);
	If Res <> 0 Then
		ClearMessages();
		MessageText = NStr("en='An error occurred while getting a list of available certificates.
		|details in the event log';ru='Ошибка получения списка доступных сертификатов.
		|подробности в журнале регистрации'");
		ErrorText = NStr("en='The AddIn.Bicrypt component has returned an error code when receiving the list of the certificates';ru='Компонента AddIn.Bicrypt при получении списка доступных сертификатов вернула код ошибки'")
						+ Res;
		Operation = NStr("en='Electronic document signing.';ru='Подписание электронного документа.'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
		ElectronicDocumentsServiceClient.ClearAuthorizationDataSberbank();
		Return;
	EndIf;
	
	CertificatesMap = New Map;
	TextDocument = New TextDocument;
	TextDocument.SetText(IdentifiersCertificates);
	IndexOf = 2;
	While IndexOf < TextDocument.LineCount() Do
		Text = TextDocument.GetLine(IndexOf);
		Text = StrReplace(Text, ",", "");
		Text = StrReplace(Text, ";", "");
		CertificatesMap.Insert(Text);
		IndexOf = IndexOf + 1;
	EndDo;
	
	If CertificatesMap.Count() = 1 Then
		ProcessingSberbankCertificateSelection(TextDocument.GetLine(IndexOf - 1));
		Return
	EndIf;
	
	For Each Item IN CertificatesMap Do
		
		IDCertificate = Item.Key;
		CertificateBinaryData = SberbankCertificateBinaryData(IDCertificate);
		
		If CertificateBinaryData = Undefined Then
			Return;
		EndIf;
		
		Try
			Certificate = New CryptoCertificate(CertificateBinaryData);
			CertificatesMap.Insert(
										IDCertificate,
										DigitalSignatureClientServer.SubjectPresentation(Certificate));
		Except
			ClearMessages();
			MessageText = NStr("en='An error occurred when reading a certificate.
		|Look for details in event log.';ru='Ошибка чтения сертификата.
		|Подробности см. в журнале регистрации.'");
			ErrorText = ErrorDescription();
			Operation = NStr("en='Certificate data reading.';ru='Чтение данных сертификата.'");
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
			Return;
		EndTry;
	EndDo;

	ListCertificates = New ValueList;
	For Each Item IN CertificatesMap Do
		ListCertificates.Add(Item.Value, Item.Key);
	EndDo;
	ND = New NotifyDescription("ProcessingSberbankCertificateSelection", ThisObject);
	ParametersStructure = New Structure("Certificates", ListCertificates);
	IDCertificate = OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.CertificateChoice",
													ParametersStructure, ThisObject, UUID, , , ND);
	
EndProcedure

&AtServer
Procedure FillAgreementSettings(CompletingSettings)
	
	FileBinaryData = GetFromTempStorage(CompletingSettings);
	
	TempFile = ElectronicDocumentsService.TemporaryFileCurrentName();
	
	FileBinaryData.Write(TempFile);
	
	XMLObject = New XMLReader;
	
	Try
		XMLObject.OpenFile(TempFile);
		
		AsynchExchangeNamespace = ElectronicDocumentsService.AsynchronousExchangeWithBanksNamespace();
		Settings = ElectronicDocumentsInternal.GetCMLValueType("Settings", AsynchExchangeNamespace);
		ED = XDTOFactory.ReadXML(XMLObject, Settings);
		
		ED.Validate();
		
		Object.AgreementStatus = Enums.EDAgreementsStatuses.Acts;
		
		CompanySearchStructure = New Structure;
		If ValueIsFilled(ED.Recipient.tin) Then
			CompanySearchStructure.Insert("TIN", ED.Recipient.tin);
		EndIf;
		If ValueIsFilled(ED.Recipient.kpp) Then
			CompanySearchStructure.Insert("KPP", ED.Recipient.kpp);
		EndIf;
		If ValueIsFilled(ED.Recipient.name) Then
			CompanySearchStructure.Insert("Description", ED.Recipient.name);
			Object.Description = ED.Recipient.name;
		EndIf;
		
		If CompanySearchStructure.Count() > 0 Then
			CompanyRef = ElectronicDocumentsOverridable.FindRefToObject(
												"Companies", , CompanySearchStructure);
			If ValueIsFilled(CompanyRef) Then
				Object.Company = CompanyRef;
			EndIf;
		EndIf;
		
		BankSearchStructure = New Structure;
		BankSearchStructure.Insert("Code", ED.Sender.bic);
		If ValueIsFilled(ED.Sender.name) Then
			BankSearchStructure.Insert("Description", ED.Sender.name);
			Object.Description = Object.Description + ?(ValueIsFilled(Object.Description), " - ", "") + ED.Sender.name;
		EndIf;
		
		RefOnBank = ElectronicDocumentsOverridable.FindRefToObject(
													"Banks", , BankSearchStructure);
		If ValueIsFilled(RefOnBank) Then
			Object.Counterparty = RefOnBank;
		EndIf;
		
		Object.BankApplication = Enums.BankApplications.AsynchronousExchange;
		Object.CompanyID = ED.Data.CustomerID;
		Object.ServerAddress = ED.Data.BankServerAddress;
		Object.CryptographyIsUsed = False;
		Object.User = ED.Data.Logon.Login.User;

	Except
		MessageText = NStr("en='An error occurred when reading the file data.';ru='Возникла ошибка при чтении данных из файла.'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		OperationKind = NStr("en='Reading EDF settings from the file.';ru='Чтение настроек ЭДО из файла.'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
							OperationKind, DetailErrorDescription, MessageText, 1);
	EndTry;
	
	XMLObject.Close();
	DeleteFiles(TempFile);
	
EndProcedure

&AtServerNoContext
Function GetBankApplication(Bank)
	
	Template = Catalogs.EDUsageAgreements.GetTemplate("BankList");
	
	RecCount = Template.TableHeight;
	SettingsCorrespondence = New Map;
	
	For IndexOf = 1 To RecCount Do
		BIN = Template.Area(IndexOf, 2).Text;
		ConnectionOption = Template.Area(IndexOf, 3).Text;
		If ConnectionOption = "SynchronousExchange" Then
			BankApplication = Enums.BankApplications.AlphaBankOnline;
		ElsIf ConnectionOption = "AsynchronousExchange" Then
			BankApplication = Enums.BankApplications.AsynchronousExchange;
		ElsIf ConnectionOption = "AdditionalInformationProcessor" Then
			BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor;
		ElsIf ConnectionOption = "Sberbank" Then
			BankApplication = Enums.BankApplications.SberbankOnline;
		EndIf;
		SettingsCorrespondence.Insert(BIN, BankApplication);
	EndDo;

	Return SettingsCorrespondence.Get(CommonUse.ObjectAttributeValue(Bank, "Code"));

EndFunction

&AtClientAtServerNoContext 
Function CryptographyIsUsed(BankApplication)
	
	If BankApplication = PredefinedValue("Enum.BankApplications.AsynchronousExchange") Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction
//Procedures and functions code
#EndRegion














