&AtClient
Var InternalData, PasswordProperties;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Key.IsEmpty() Then
		PrepareForm();
	EndIf;

EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	PrepareForm();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ElectronicDocumentsServiceClient.CheckUsingUsersInternetSupport() Then
		Items.PrivateOfficeOfParticipantExchangeED.Visible = False;
	EndIf;
#If WebClient Then
	Items.IncomingDocumentsDir.ChoiceButton = False;
#EndIf

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If MonitorEDSettingsContent Then
		CurrentObject.MarkToDeleteAssociatedEDFSettings(CurrentObject, Cancel)
	EndIf;
	
	If CurrentObject.EDExchangeMethod = Enums.EDExchangeMethods.ThroughFTP Then
		CurrentObject.IncomingDocumentsResource  = FTPIncomingDocumentsDir;
	ElsIf CurrentObject.EDExchangeMethod = Enums.EDExchangeMethods.ThroughDirectory Then
		CurrentObject.IncomingDocumentsResource  = IncomingDocumentsDir;
	ElsIf CurrentObject.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEMail Then
		CurrentObject.IncomingDocumentsResource  = CompanyEmail;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshStateED");
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If EDExchangeInitialSetup Then
		QuestionText = NStr("en='Do you want to enable the counterparty to exchange electronic documents?';ru='Подключить контрагента к обмену электронными документами?'");
		NotifyDescription = New NotifyDescription("ContinueBeforeClosing", ThisObject);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ValueIsFilled(ValueSelected) Then
		If ValueSelected = True Then
			Certificate = InternalData["SelectedCertificate"];
			PasswordProperties = New Structure("Value", InternalData["SelectedCertificatePassword"]);
			InternalData.Delete("SelectedCertificate");
			InternalData.Delete("SelectedCertificatePassword");
		Else
			Certificate = ValueSelected;
		EndIf;
		TypeSelectValues = TypeOf(Certificate);
		If TypeSelectValues = Type("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates") Then
			
			// First you need to check if the selected certificate is already in the list
			RowArray = Object.CompanySignatureCertificates.FindRows(New Structure("Certificate", Certificate));
			If RowArray.Count() > 0 Then
				WarningText = NStr("en='Selected certificate is already registered in the agreement';ru='Выбранный сертификат уже зарегистрирован в соглашении'");
				ShowMessageBox(, WarningText, 30);
				Return;
			EndIf;
			
			If ElectronicDocumentsServiceClient.CheckUsingUsersInternetSupport()
				AND Object.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom") Then
				
				AddingCertificate = Certificate;
				RegisterCertificate(AddingCertificate);
				// Add certificate is activated in the notification handler
			Else
				AddCertificateSignaturesInList(Certificate);
				Items.CompanySignatureCertificates.Refresh();
			EndIf;
		EndIf;
		PasswordProperties = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// OnlineUserSupport
	
	// The mechanism of receiving a unique
	// identifier passes the unique identifier in the form of
	// rows in the notification parameter with the event name "NotificationReceivedUUIDEDFExchangeParticipant"
	If EventName = "NotificationOfReceiptOfParticipantsUniqueIdEdExchange" Then
		
		If ValueIsFilled(Source) AND Source <> ThisForm.UUID Then
			// This is not the correct form
			Return;
		EndIf;
		
		DataChanged = False;
		CompanyID = TrimAll(Parameter);
		If TrimAll(Object.CompanyID) <> CompanyID Then
			DataChanged = True;
			Object.CompanyID = CompanyID;
		EndIf;
		
		// AddingCertificate is initialized in ChoiceProcessing(...)
		If ValueIsFilled(AddingCertificate) Then
			DataChanged = True;
			AddCertificateSignaturesInList(AddingCertificate);
			Items.CompanySignatureCertificates.Refresh();
			AddingCertificate = Undefined;
		EndIf;
		
		ThisForm.Modified = DataChanged;
		AvailabilityManagementOfPersonalCabinet();
	EndIf;
	
	// End OnlineUserSupport
	
EndProcedure

#EndRegion

#Region FieldsFormEventsHandlers

&AtClient
Procedure EDExchangeMethodOnChange(Item)
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure CompanyIDOnChange(Item)
	
	Object.CompanyID = TrimAll(Object.CompanyID);
EndProcedure

&AtClient
Procedure IncomingDocumentsDirBeginChoice(Item, ChoiceData, StandardProcessing)
	
#If Not WebClient Then
	ExchangeDirectory(IncomingDocumentsDir);
#EndIf

EndProcedure

&AtClient
Procedure InscriptionPrivateOfficeExchangeEDMemberPress(Item)
	
	// If the agreement contains more than one
	// certificate, it is assumed that all certificates were previously
	// registered with the EDF operator You can access your personal area by the current or the first certificate
	
	If Object.CompanySignatureCertificates.Count() = 0 Then
		WarningText = NStr("en='To enter the private office at least one certificate must be registered';ru='Для входа в личный кабинет должен быть зарегистрирован хотя бы один сертификат'");
		ShowMessageBox(, WarningText, 30);
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("GotoInPersonalArea", ThisObject);
	If Modified Then
		QuestionText = NStr("en='You can perform this action only in a recorded EDF settings profile.
		|Record?';ru='Выполнить действие можно только в записанном профиле настроек ЭДО.
		|Записать?'");
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	Else
		ExecuteNotifyProcessing(NOTifyDescription, DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

&AtClient
Procedure InvitationsTextStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	Notification = New NotifyDescription("EndInvitationTextEditing", ThisObject);
	FormTitle = NStr("en='Text pattern for counterparty invitations';ru='Шаблон текста для приглашений контрагентов'");
	CommonUseClient.ShowMultilineTextEditingForm(
		Notification, Items.InvitationsText.EditText, FormTitle);
	
EndProcedure

&AtClient
Procedure CompanyIDTextEnterEnd(Item, Text, ChoiceData, Parameters, StandardProcessing)
	
	If Not MonitorEDSettingsContent Then
		QuestionText = NStr("en='Changes of ""EDF settings profile"" will be applied to all related ""EDF settings"".
		|Continue?';ru='Изменения ""Профиля настроек ЭДО"" будут применены для всех связанных с ним ""Настроек ЭДО"".
		|Продолжить?'");
		NotificationParameters = New Structure;
		NotificationParameters.Insert("OldCompanyID", Object.CompanyID);
		NotifyDescription = New NotifyDescription("AllowEditingCompanyIDComplete", ThisObject, NotificationParameters);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SettingsProfileTest(Command)
	
	ClearMessages();
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("CompleteSettingsProfileTest", ThisObject);
	If Modified Then
		QuestionText = "The current EDF settings profile has been changed. Do you want to continue the test?";
		ButtonList = New ValueList();
		ButtonList.Add("Execute", "Save and perform test");
		ButtonList.Add("Cancel", "Cancel test");
		ShowQueryBox(NOTifyDescription, QuestionText, ButtonList, , "Execute", "Test settings");
	Else
		CompleteSettingsProfileTest("Execute", Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure AddCertificate(Command)
	
	If Not ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
		"UseDigitalSignatures") Then
		
		MessageText = ElectronicDocumentsServiceCallServer.MessageTextAboutSystemSettingRequirement("SigningOfED");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	OpenChoiceFormDSCertificate();
	
EndProcedure

&AtClient
Procedure BeginningDateQueryDataFromOperator(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("EDFProfileSettings", Object.Ref);
	FormParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	OpenForm(
			"InformationRegister.EDExchangeStatesThroughEDFOperators.Form.EditForm",
			FormParameters,
			ThisObject);
	
EndProcedure

#EndRegion

#Region EventHandlersTableFieldsCompanySignatures

&AtClient
Procedure SignatureCertificatesBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	ShowValue(, Item.CurrentData.Certificate);
	
EndProcedure

#EndRegion

#Region EventHandlersTableFieldsOutgoingDocuments

&AtClient
Procedure OutgoingDocumentsBeforeStartChanging(Item, Cancel)
	
	If Not MonitorEDSettingsContent Then
		QuestionText = NStr("en='Changes of ""EDF settings profile"" will be applied to all related ""EDF settings"".
		|Continue?';ru='Изменения ""Профиля настроек ЭДО"" будут применены для всех связанных с ним ""Настроек ЭДО"".
		|Продолжить?'");
		NotificationParameters = New Structure;
		NotificationParameters.Insert("RowID", Item.CurrentData.GetID());
		NotificationParameters.Insert("FormatVersion",       Item.CurrentData.FormatVersion);
		NotificationParameters.Insert("UseDS",      Item.CurrentData.UseDS);
		NotificationParameters.Insert("OutgoingDocument",   Item.CurrentData.OutgoingDocument);
		NotificationParameters.Insert("ToForm",         Item.CurrentData.ToForm);
		
		NotifyDescription = New NotifyDescription("AllowEditingAttributeListEDKindsComplete", ThisObject, NotificationParameters);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

&AtClient
Procedure OutgoingDocumentsOnChange(Item)
	
	ClearMessages();
	
	If Item.CurrentItem.Name = "OutgoingDocumentsToForm" Then
		ItemValue = Item.CurrentData.ToForm;
		If Not ItemValue Then
			Item.CurrentData.UseDS = ItemValue;
		EndIf;
	EndIf;
	
	If Item.CurrentData.UseDS AND Not Item.CurrentData.ToForm Then
		If Item.CurrentItem.Name = "OutgoingDocumentsUseDS" Then
			Item.CurrentData.ToForm = True;
		Else
			Item.CurrentData.UseDS = False;
		EndIf;
	EndIf;
	
	If Item.CurrentData.OutgoingDocument = PredefinedValue("Enum.EDKinds.RandomED")
		OR Object.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom") Then
		
		Item.CurrentData.UseDS = Item.CurrentData.ToForm;
	EndIf;
	
	If (Item.CurrentData.OutgoingDocument = PredefinedValue("Enum.EDKinds.CustomerInvoiceNote")
		OR Item.CurrentData.OutgoingDocument = PredefinedValue("Enum.EDKinds.CorrectiveInvoiceNote"))
		AND Object.EDExchangeMethod <> PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom") Then
		
		Item.CurrentData.ToForm = False;
		Item.CurrentData.UseDS = False;
		
		MessagePattern = NStr("en='You can send the %1 document through the EDF operator only.';ru='Отправка документа %1 возможна только через оператора ЭДО.'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
			Item.CurrentData.OutgoingDocument);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	FormManagement(ThisObject);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure PrepareForm()
	
	If Object.EDExchangeMethod = Enums.EDExchangeMethods.ThroughFTP Then
		FTPIncomingDocumentsDir = Object.IncomingDocumentsResource;
	ElsIf Object.EDExchangeMethod  = Enums.EDExchangeMethods.ThroughDirectory Then
		IncomingDocumentsDir    = Object.IncomingDocumentsResource;
	ElsIf Object.EDExchangeMethod  = Enums.EDExchangeMethods.ThroughEMail Then
		CompanyEmail  = Object.IncomingDocumentsResource;
	EndIf;
	
	// Assistant of EDF settings creation
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDUsageAgreementsOutgoingDocuments.Ref
	|FROM
	|	Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
	|WHERE
	|	EDUsageAgreementsOutgoingDocuments.EDExchangeMethod = &EDExchangeMethod
	|	AND EDUsageAgreementsOutgoingDocuments.Ref.Company = &Company
	|	AND Not EDUsageAgreementsOutgoingDocuments.Ref.DeletionMark";
	Query.SetParameter("EDExchangeMethod", Object.EDExchangeMethod);
	Query.SetParameter("Company", Object.Company);
	EDExchangeInitialSetup = Query.Execute().IsEmpty();
	
	MarkNotValidCertificatesInList();
	
	UseDS = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
																	"UseDigitalSignatures");

	// Using digital signature
	Items.OutgoingDocumentsUseDS.Visible = UseDS
		AND Object.EDExchangeMethod <> PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom");
	Items.GroupCompanySignatureCertificates.Visible = UseDS;
	Items.EDFProfileSettingsPages.PagesRepresentation = ?(UseDS,
		FormPagesRepresentation.TabsOnTop, FormPagesRepresentation.None);
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure FormManagement(Form)
	
	Items = Form.Items;
	Object   = Form.Object;
	
	Items.GroupExchangeThroughOperatorInformation.Visible = Object.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom");
	Items.GroupDirectExchangeThroughEMailInformation.Visible = Object.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEMail");
	Items.GroupDirectExchangeThroughCatalogInformation.Visible = Object.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughDirectory");
	Items.GroupDirectExchangeThroughFTPInformation.Visible = Object.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughFTP");
	Items.BeginningDateQueryDataFromOperator.Visible = Object.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom");
	
EndProcedure

&AtClient
Procedure RegisterCertificate(DSCertificate)
	
	// Testing signature certificate settings suppressing the output of successful results.
	ClearMessages();
	
	Cancel = False;
	If Not ValueIsFilled(DSCertificate) Then
		CommonUseClientServer.MessageToUser(
											ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Certificate"),
											Object.Ref,
											"CompanySignatureCertificates",
											,
											Cancel);
	EndIf;
	If Not ValueIsFilled(Object.Company) Then
		CommonUseClientServer.MessageToUser(
											ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Company"),
											Object.Ref,
											"Company",
											,
											Cancel);
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("DSCertificate", DSCertificate);
	
	NotificationProcessing = New NotifyDescription("RegisterCertificateAlert", ThisObject, AdditionalParameters);
	
	ElectronicDocumentsServiceClient.CertificateValidationSettingsTest(DSCertificate,
		NotificationProcessing, True, ThisForm, True, True);

EndProcedure

&AtClient
Procedure RegisterCertificateAlert(Result, AdditionalParameters) Export
	
	If Result = True Then
		DSCertificate = AdditionalParameters.DSCertificate;
		
		ElectronicDocumentsClientOverridable.StartWorkWithEDFOperatorMechanism(DSCertificate,
																						  Object.Company,
																						  "taxcomGetID",
																						  Object.CompanyID,
																						  Result.UserPassword,
																						  ThisObject.UUID);
	EndIf;
	
EndProcedure

&AtClient
Procedure AvailabilityManagementOfPersonalCabinet()
	
	Items.PrivateOfficeOfParticipantExchangeED.Enabled = Not IsBlankString(Object.CompanyID);
	
EndProcedure

&AtServer
Procedure AddCertificateSignaturesInList(DSCertificate)
	
	String = Object.CompanySignatureCertificates.Add();
	String.Certificate = DSCertificate;
	Modified = True;
	MarkNotValidCertificatesInList();
	
EndProcedure

&AtServer
Procedure MarkNotValidCertificatesInList()
	
	For Each String IN Object.CompanySignatureCertificates Do
		String.Acts = Not (String.Certificate.DeletionMark OR String.Certificate.Revoked);
	EndDo;
	
EndProcedure

&AtClient
Procedure ExchangeDirectory(PathToDirectory)
	
#If Not WebClient Then
	FolderDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	FolderDialog.Title = NStr("en='Select network directory for exchange';ru='Выберите сетевой каталог для обмена'");
	FolderDialog.Folder   = PathToDirectory;
	If FolderDialog.Choose() Then
		PathToDirectory = FolderDialog.Folder;
		ElectronicDocumentsServiceCallServer.ValidateCatalogAvailabilityForDirectExchange(PathToDirectory);
	EndIf;
#EndIf
	
EndProcedure

&AtClient
Procedure OpenChoiceFormDSCertificate()
	
	If Object.DeletionMark Then
		MessageText = NStr("en='To perform an action it is required to uncheck the deletion mark.';ru='Для выполнения действия необходимо снять пометку удаления.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	If ElectronicDocumentsServiceClient.CheckUsingUsersInternetSupport() Then
		// OUS library handler
		
		If IsBlankString(Object.CompanyID)
			AND Object.CompanySignatureCertificates.Count() > 0 Then
			// This operation is prohibited. Since the agreement already has at least
			// one certificate, but the identifier is not received yet
			WarningText = NStr("en='Before adding new certificates to
		|the agreement, you need to get an EDF exchange participant ID';ru='Перед добавлением новых
		|сертификатов в соглашение необходимо получить идентификатор участника обмена ЭДО'");
			ShowMessageBox(, WarningText, 30);
			Return;
			
			// Otherwise
			// there are cases left when
			// the first certificate is added and when you
			// need to register the added certificate in 1C-Taxcom both these cases are processed in the event handler of the form ChoiceProcessing 
			
		EndIf;
	EndIf;
	// End of OUS library handler
	
	Form = GetForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.ChoiceForm", , ThisObject);
	CommonUseClientServer.SetFilterDynamicListItem(Form.List, "Company", Object.Company,
		DataCompositionComparisonType.Equal, , True, DataCompositionSettingsItemViewMode.Inaccessible);
	Form.Open();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Office handlers for asynchronous dialogs

&AtClient
Procedure CompleteSettingsProfileTest(Val Result, Val AdditionalParameters) Export
	
	If Result <> Undefined Then
		If Result = "Cancel" Then
			Return;
		ElsIf Modified Then
			Write();
		EndIf;
	EndIf;
	
	If Object.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEMail") Then
		Status(NStr("en='Settings test.';ru='Тест настроек.'"),
			,
			NStr("en='Testing ED exchange through electronic mail. Please wait...';ru='Выполняется тестирование обмена ЭД через электронную почту. Пожалуйста, подождите..'"));
			
		UserAccount = Object.IncomingDocumentsResource;
		
		If EmailOperationsServerCall.PasswordIsAssigned(UserAccount) Then
			EmailOperationsClient.CheckPossibilityOfSendingAndReceivingOfEmails(Undefined, UserAccount, Undefined);
		Else
			FormParameters = New Structure;
			FormParameters.Insert("UserAccount", UserAccount);
			FormParameters.Insert("CheckAbilityToSendAndReceive", True);
			OpenForm("CommonForm.AccountPasswordConfirmation", FormParameters);
		EndIf;
		
	EndIf;
	
	If Object.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughDirectory") Then
		Status(NStr("en='Settings test.';ru='Тест настроек.'"),
			,
			NStr("en='Testing ED exchange through directory. Please wait...';ru='Выполняется тестирование обмена ЭД через каталог. Пожалуйста, подождите..'"));
		
		PathToParentDirectoryEDFProfileSettings = Object.IncomingDocumentsResource;
		
		// Block of checking the access to directories.
		MessagePattern = NStr("en='Test. Check of access to the shared directory for ED exchange.
		|%1';ru='Тест. Проверка доступа к общему каталогу для обмена ЭД.
		|%1'");
		Try
			If ElectronicDocumentsServiceCallServer.ValidateCatalogAvailabilityForDirectExchange(
				PathToParentDirectoryEDFProfileSettings) Then
				
				TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
			Else
				TestResult = ElectronicDocumentsServiceCallServer.GetMessageAboutError("107");
			EndIf;
		Except
			ResultTemplate = NStr("en='%1 %2';ru='%1 %2'");
			ErrorText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("107");
			TestResult = StringFunctionsClientServer.PlaceParametersIntoString(ResultTemplate, ErrorText,
			BriefErrorDescription(ErrorInfo()));
		EndTry;
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, TestResult);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	If Object.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughFTP") Then
		Status(NStr("en='Settings test.';ru='Тест настроек.'"),
			,
			NStr("en='Testing ED exchange through FTP. Please wait...';ru='Выполняется тестирование обмена ЭД через FTP. Пожалуйста, подождите..'"));
		
		PathToParentDirectoryEDFProfileSettings = Object.IncomingDocumentsResource;
		
		// Block of checking the access to directories.
		MessagePattern = NStr("en='Test. Check of access to the shared directory for ED exchange.
		|%1';ru='Тест. Проверка доступа к общему каталогу для обмена ЭД.
		|%1'");
		Try
			If ElectronicDocumentsServiceCallServer.ValidateCatalogAvailabilityForDirectExchange(
				PathToParentDirectoryEDFProfileSettings) Then
				
				TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
			Else
				TestResult = ElectronicDocumentsServiceCallServer.GetMessageAboutError("107");
			EndIf;
		Except
			ResultTemplate = NStr("en='%1 %2';ru='%1 %2'");
			ErrorText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("107");
			TestResult = StringFunctionsClientServer.PlaceParametersIntoString(ResultTemplate, ErrorText,
			BriefErrorDescription(ErrorInfo()));
		EndTry;
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, TestResult);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	Notification = New NotifyDescription("AfterGettingYourPrintsValidateCertificates", ThisObject);
	
	DigitalSignatureClient.GetCertificatesThumbprints(Notification, True, False);
	
EndProcedure

&AtClient
Procedure AfterGettingYourPrintsValidateCertificates(Prints, Parameters = Undefined) Export
	
	CertificateTumbprintsArray = New Array;
	For Each KeyValue IN Prints Do
		CertificateTumbprintsArray.Add(KeyValue.Key);
	EndDo;
		
	ForAuthorization = (Object.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom"));
	Map = ElectronicDocumentsServiceCallServer.MatchAvailableCertificatesAndSettings(
												CertificateTumbprintsArray, Object.Ref, ForAuthorization);
	
	Certificate = Undefined;
	PasswordReceived = False;
	For Each KeyValue IN Map Do
		CurCertificate = KeyValue.Key;
		If Certificate = Undefined Then
			// If the match does not contain certificates with a saved password, for test take the first certificate from the list.
			Certificate = CurCertificate;
		EndIf;
		If KeyValue.Value.Property("PasswordReceived", PasswordReceived) AND PasswordReceived = True Then
			Certificate = CurCertificate;
			Break;
		EndIf;
	EndDo;
	If ValueIsFilled(Certificate) Then
		ElectronicDocumentsServiceClient.CertificateValidationSettingsTest(Certificate, , ForAuthorization, ThisForm);
	ElsIf ForAuthorization Then
		MessageText = NStr("en='There are no available certificates. Test not executed.';ru='Нет доступных сертификатов. Тест не выполнен.'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

&AtClient
Procedure ContinueBeforeClosing(Val Result, Val AdditionalParameters) Export
	
	NotifyDescription = New NotifyDescription("CompleteBeforeClosing", ThisObject);
	If Result = DialogReturnCode.Yes Then
		ChoiceFormParameters = New Structure;
		ChoiceFormParameters.Insert("ChoiceMode",        True);
		ChoiceFormParameters.Insert("CloseOnChoice", True);
		ChoiceFormParameters.Insert("Multiselect", FALSE);
		
		OpenForm("Catalog.Counterparties.ChoiceForm",
			ChoiceFormParameters, ThisObject, UUID, , , NotifyDescription);
	Else
		ExecuteNotifyProcessing(NOTifyDescription);
	EndIf;
	
EndProcedure

&AtClient
Procedure CompleteBeforeClosing(Val Counterparty, Val AdditionalParameters) Export
	
	If ValueIsFilled(Counterparty) Then
		FormParameters = New Structure;
		FillingValues = New Structure;
		FillingValues.Insert("Counterparty",         Counterparty);
		FillingValues.Insert("EDFProfileSettings", Object.Ref);
		
		FormParameters.Insert("FillingValues", FillingValues);
		OpenForm("Catalog.EDUsageAgreements.Form.ItemForm", FormParameters, ThisObject);
	EndIf;
	
	EDExchangeInitialSetup = False;
	Close();
	
EndProcedure

&AtClient
Procedure GotoInPersonalArea(Val Result, Val AdditionalParameters) Export
	
	If Not Result = DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Write();
	Array = New Array;
	Array.Add(Object.Ref);
	
	NotificationProcessing = New NotifyDescription("GoToPersonalAreaAlert", ThisObject);
	
	ElectronicDocumentsServiceClient.GetAgreementsAndCertificatesParametersMatch(NotificationProcessing, Array);
	
EndProcedure

&AtClient
Procedure GoToPersonalAreaAlert(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	ProfilesAndCertificatesParametersMatch = "";
	SignatureCertificate  = Undefined;
	UserPassword = Undefined;
	If Result.Property("ProfilesAndCertificatesParametersMatch", ProfilesAndCertificatesParametersMatch)
		AND Not ValueIsFilled(ProfilesAndCertificatesParametersMatch) Then
		
		MessageText = NStr("en='No available certificates among the registered in this EDF settings profile.';ru='Нет доступных сертификатов, среди зарегистрированных по данному профилю настроек ЭДО.'");
		CommonUseClientServer.MessageToUser(MessageText,
			,
			"CompanySignatureCertificates",
			"Object.CompanySignatureCertificates",
			);
	Else
		For Each StructureItem IN ProfilesAndCertificatesParametersMatch Do
			CertificateStructure = StructureItem.Value;
			If TypeOf(CertificateStructure) = Type("Structure") Then
				CertificateStructure.Property("SignatureCertificate", SignatureCertificate);
				CertificateStructure.Property("UserPassword", UserPassword);
			EndIf;
			Break;
		EndDo;
	EndIf;
	If ValueIsFilled(SignatureCertificate) Then
		ElectronicDocumentsClientOverridable.StartWorkWithEDFOperatorMechanism(SignatureCertificate,
		Object.Company,
		"taxcomPrivat",
		Object.CompanyID,
		UserPassword,
		UUID);
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowEditingAttributeListEDKindsComplete(Val Result, Val AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		MonitorEDSettingsContent = True;
	Else
		
		FillPropertyValues(Object.OutgoingDocuments.FindByID(AdditionalParameters.RowID),
			AdditionalParameters);
		ThisForm.CurrentItem = Items.CompanyID;
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowEditingCompanyIDComplete(Val Result, Val AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		MonitorEDSettingsContent = True;
	Else
		Object.CompanyID = TrimAll(AdditionalParameters.OldCompanyID);
	EndIf;
	
EndProcedure

&AtClient
Procedure EndInvitationTextEditing(Result, AdditionalParameters) Export
	
	Object.InvitationsTextTemplate = Result;
	
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
