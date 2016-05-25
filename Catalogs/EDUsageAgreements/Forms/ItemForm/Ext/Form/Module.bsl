
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("WindowOpeningMode") Then
		ThisObject.WindowOpeningMode = Parameters.WindowOpeningMode;
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		SetFormModified = True;
		
		Object.AgreementState = Enums.EDAgreementStates.CoordinationExpected;
		Object.PackageFormatVersion = Enums.EDPackageFormatVersions.Version30;
		
		If ValueIsFilled(Object.Counterparty) Then
			Object.Description = String(Object.Counterparty);
		EndIf;
		
		If Parameters.Property("Company") Then
			Object.Company = Parameters.Company;
		EndIf;
		
		// Fill in default EDF profile settings.
		If Not ValueIsFilled(Object.EDFProfileSettings) Then
			SetDefaultValues();
		EndIf;
		// When creating from EDF settings profile, it is passed to the setting.
		If ValueIsFilled(Object.EDFProfileSettings) Then
			EDFProfileSettingsOnChangeAtServer();
		EndIf;
		
		PrepareForm();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// If an object - is Intercompany agreement,
	// then do nothing on the server and when navigating to the on open procedure, open the required form.
	If Object.IsIntercompany OR Object.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource Then
		Return;
	EndIf;
	
	PrepareForm();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// When filling out EDF settings on the server, specify modification manually.
	If SetFormModified Then
		ThisObject.Modified = true;
	EndIf;
	
	#If WebClient Then
		Items.IncomingDocumentsDir.ChoiceButton = False;
		Items.OutgoingDocumentsDir.ChoiceButton = False;
	#EndIf
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		Read();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	CounterpartyIdUsageUnique(Cancel);
	
EndProcedure

#EndRegion

#Region FieldsFormEventsHandlers

&AtClient
Procedure StatusOnChange(Item)
	
	If Object.AgreementState = PredefinedValue("Enum.EDAgreementStates.Closed")
		OR Object.AgreementState = PredefinedValue("Enum.EDAgreementStates.CoordinationExpected") Then
		
		If ThroughEDFOperator Then
			
			QuestionText = NStr("en = 'When cancelling the agreement validity, reject an invitation.
				|Reject?'");
			NotifyDescription = New NotifyDescription("FinishStateChange", ThisObject);
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		Else
			Object.ConnectionStatus = PredefinedValue("Enum.EDExchangeMemberStatuses.Disconnected");
		EndIf;
	Else
		Object.ConnectionStatus = PredefinedValue("Enum.EDExchangeMemberStatuses.Connected");
	EndIf;
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure EDFProfileSettingsOnChange(Item)
	
	EDFProfileSettingsOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure CounterpartyAgreementOnChange(Item)
	
	Object.Description = String(Object.Counterparty) + ?(ValueIsFilled(Object.CounterpartyContract),
		", " + String(Object.CounterpartyContract), "");
	
EndProcedure

// Exchange settings through operator

&AtClient
Procedure CounterpartyIDOnChange(Item)
	
	Object.CounterpartyID = TrimAll(Object.CounterpartyID);
	GetUsedEDExchangeMethods(Undefined, Object.CounterpartyID);
	
EndProcedure

// Direct exchange settings
&AtClient
Procedure IncomingDocumentsDirBeginChoice(Item, ChoiceData, StandardProcessing)
	
	ChooseDirectoryHandle(Object.IncomingDocumentsDir);
	
EndProcedure

&AtClient
Procedure OutgoingDocumentsDirBeginChoice(Item, ChoiceData, StandardProcessing)
	
	ChooseDirectoryHandle(Object.OutgoingDocumentsDir);
	
EndProcedure

&AtClient
Procedure EncryptEDPackageDataOnChange(Item)
	
	NotifyDescription = New NotifyDescription("FinishDataEncryptionChange", ThisObject);
	If ValueIsFilled(Object.CompanyCertificateForDetails)
		OR ValueIsFilled(ThisObject.CounterpartyEncryptionCertificatePresentation) Then
		QuestionText = NStr("en = 'Encryption settings will be cleared. Continue?'");
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	Else
		ExecuteNotifyProcessing(NOTifyDescription);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeEDPackageFormatOnChange(Item)
	
	ExchangeFileStringArray = Object.ExchangeFilesFormats.FindRows(New Structure("Use", True));
	NotifyDescription = New NotifyDescription("FinishPackageFormatChange", ThisObject);
	If ExchangeFileStringArray.Count() > 1 Then
		QuestionText = NStr("en = 'Changes of the e-document package format will be cleared. Continue?'");
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	Else
		ExecuteNotifyProcessing(NOTifyDescription);
	EndIf;
	
EndProcedure

&AtClient
Procedure VerifySignatureCertificatesOnChange(Item)
	
	NotifyDescription = New NotifyDescription("FinishChangeChecksCertificates", ThisObject);
	If Object.CounterpartySignaturesCertificates.Count() <> 0 Then
		QuestionText = NStr("en = 'Settings of the counterparty signature certificates check will be cleared. Continue?'");
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	Else
		ExecuteNotifyProcessing(NOTifyDescription);
	EndIf;
	
EndProcedure

&AtClient
Procedure CounterpartyCertificateForEncryptionOnChange(Item)
	
	If Not ValueIsFilled(Item.EditText) Then
		PutInCertificateRepositoryConfiguration();
	EndIf;
	
EndProcedure

&AtClient
Procedure CounterpartyCertificateForEncryptionBeginChoice(Item, ChoiceData, StandardProcessing)
	
	Handler = New NotifyDescription("SelectionProcessEncryptionCertificateFile", ThisObject);
	BeginPutFile(Handler, , , True, UUID);
	
EndProcedure

&AtClient
Procedure CounterpartyCertificateForEncryptionCleaning(Item, StandardProcessing)
	
	PutInCertificateRepositoryConfiguration();
	
EndProcedure

#EndRegion

#Region FormCommandsActionsHandlers

&AtClient
Procedure SendInvitation(Command)
	
	NotifyDescription = New NotifyDescription("FinishInvitationsProcessing", ThisObject);
	If Modified Then
		QuestionText = NStr("en = 'Changes are made to the current EDF setting. Record?'");
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	Else
		ExecuteNotifyProcessing(NOTifyDescription);
	EndIf;
	
EndProcedure

&AtClient
Procedure AcceptInvitation(Command)
	
	AdditParameters = New Structure("Action", "Accept");
	NotifyDescription = New NotifyDescription("FinishInvitationsProcessing", ThisObject, AdditParameters);
	If Modified Then
		QuestionText = NStr("en = 'Changes are made to the current EDF setting. Record?'");
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	Else
		ExecuteNotifyProcessing(NOTifyDescription);
	EndIf;
	
EndProcedure

&AtClient
Procedure RejectInvitation(Command)
	
	AdditParameters = New Structure("Action", "Reject");
	NotifyDescription = New NotifyDescription("FinishInvitationsProcessing", ThisObject, AdditParameters);
	If Modified Then
		QuestionText = NStr("en = 'Changes are made to the current EDF setting. Record?'");
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	Else
		ExecuteNotifyProcessing(NOTifyDescription);
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingsTest(Command)
	
	ClearMessages();
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("CompleteSettingsTest", ThisObject);
	If Modified Then
		QuestionText = NStr("en = 'Changes are made to the current EDF setting. Do you want to continue the test?'");
		ButtonList = New ValueList();
		ButtonList.Add("Execute", NStr("en = 'Save and perform test'"));
		ButtonList.Add("Cancel", NStr("en = 'Cancel test'"));
		ShowQueryBox(NOTifyDescription, QuestionText, ButtonList, , "Execute", NStr("en = 'Test settings'"));
	Else
		CompleteSettingsTest("Execute", Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableAgreementSetupExtendedMode(Command)
	
	NotifyDescription = New NotifyDescription("CompleteInclusionAdvancedModeSettings", ThisObject);
	If Object.AgreementSetupExtendedMode Then
		QuestionText = NStr("en = 'Changes of the extended mode will be cleared.
			|Continue?'");
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	Else
		Object.AgreementSetupExtendedMode = Not Object.AgreementSetupExtendedMode;
		ExecuteNotifyProcessing(NOTifyDescription);
	EndIf;
	
EndProcedure

&AtServer
Procedure EnableAgreementSetupExtendedModeAtServer()
	
	OutgoingDocumentsProfileSettings = CommonUse.ObjectAttributeValue(Object.EDFProfileSettings,
		"OutgoingDocuments");
	
	// Importing PM from the EDF settings profile.
	Object.OutgoingDocuments.Load(OutgoingDocumentsProfileSettings.Unload());
	
	If Object.EDExchangeMethod <> Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
		SetIdentifier("Counterparties", Object.Counterparty, Object.CounterpartyID);
	EndIf;
	
	GetUsedEDExchangeMethods(Object.EDFProfileSettings, Object.CounterpartyID);
	
EndProcedure

#EndRegion

#Region EventHandlersTableFieldsOutgoingDocuments

&AtClient
Procedure OutgoingDocumentsBeforeStartChanging(Item, Cancel)
	
	ClearMessages();
	
	OutgoingDocumentsBeforeStartChangingAtServer(Cancel);
	
EndProcedure

&AtServer
Procedure OutgoingDocumentsBeforeStartChangingAtServer(Cancel)
	
	If Not Object.AgreementSetupExtendedMode Then
		MessageText = NStr("en = 'You can change tabular section
		|""Electronic documents"" as follows: ""group"" -
		|in EDF Profile settings, ""individual"" - in the extended settings mode.'");
		CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
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
		OR Item.CurrentData.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom") Then
		
		Item.CurrentData.UseDS = Item.CurrentData.ToForm;
	ElsIf Item.CurrentData.OutgoingDocument = PredefinedValue("Enum.EDKinds.ProductsDirectory") Then
		
		InAgreementCatalogIsUsed = Item.CurrentData.ToForm;
	EndIf;
	
	If (Item.CurrentData.OutgoingDocument = PredefinedValue("Enum.EDKinds.CustomerInvoiceNote")
		OR Item.CurrentData.OutgoingDocument = PredefinedValue("Enum.EDKinds.CorrectiveInvoiceNote"))
		AND Item.CurrentData.EDExchangeMethod <> PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom") Then
		
		Item.CurrentData.ToForm = False;
		Item.CurrentData.UseDS = False;
		
		MessagePattern = NStr("en='You can send the %1 document through the EDF operator only.'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
			Item.CurrentData.OutgoingDocument);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure OutgoingDocumentsEDFProfileSettingsOnChange(Item)
	
	SelectedRow = Items.OutgoingDocuments.CurrentRow;
	OutgoingDocumentsEDFProfileSettingsOnChangeAtServer(SelectedRow);
	
EndProcedure

#EndRegion

#Region EventsHandlersTablesSignatureCertificatesFields

&AtClient
Procedure CounterpartySignaturesCertificatesCounterpartyCertificatePresentationOnChange(Item)
	
	If Not ValueIsFilled(Item.EditText) Then
		SelectedRow = Items.CounterpartySignaturesCertificates.CurrentRow;
		AddDateByTabularSection(SelectedRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure CounterpartySignaturesCertificatesCounterpartyCertificatePresentationBeginChoice(Item, ChoiceData, StandardProcessing)
	
	Handler = New NotifyDescription("FileChoiceProcessing", ThisObject);
	BeginPutFile(Handler, , , True, UUID);
	
EndProcedure

&AtClient
Procedure CounterpartySignaturesCertificatesCounterpartyCertificatePresentationClearing(Item, StandardProcessing)
	
	SelectedRow = Items.CounterpartySignaturesCertificates.CurrentRow;
	AddDateByTabularSection(SelectedRow);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure PrepareForm()
	
	GetUsedEDExchangeMethods();
	
	If ThroughDirectory OR ThroughEMail OR ThroughFTP Then
		FillFileFormatsAvailableValues();
		
		If ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
			"UseDigitalSignatures") Then
			
			If Object.EncryptEDPackageData Then
				
				DocumentObject = FormAttributeToValue("Object");
				CertificateBinaryData  = DocumentObject.CounterpartyCertificateForEncryption.Get();
				If CertificateBinaryData <> Undefined Then
					CryptoCertificate = New CryptoCertificate(CertificateBinaryData);
					CertificatePresentation = DigitalSignatureClientServer.SubjectPresentation(CryptoCertificate);
					CounterpartyEncryptionCertificatePresentation = CertificatePresentation;
				EndIf;
			EndIf;
			
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(Object.Counterparty) Then
		AppliedCatalogName = ElectronicDocumentsReUse.GetAppliedCatalogName("Counterparties");
		Object.Counterparty = ElectronicDocumentsReUse.GetEmptyRef(AppliedCatalogName);
	EndIf;
	
	UsedAdditionalAnalyticsPartners = ElectronicDocumentsReUse.UseAdditionalAnalyticsOfCompaniesCatalogPartners();
	If UsedAdditionalAnalyticsPartners AND ValueIsFilled(Object.Counterparty) Then
		
		AttributeNamePartnerCounterparty = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyPartner");
		Partner = CommonUse.ObjectAttributeValue(Object.Counterparty, AttributeNamePartnerCounterparty);
	EndIf;
	
	ActualEDs = ElectronicDocumentsReUse.GetEDActualKinds();
	If Not ActualEDs.Find(Enums.EDKinds.ProductsDirectory) = Undefined Then
		
		DirectoryUseInApplication = True;
		FilterParameters = New Structure("OutgoingDocument, ToForm", Enums.EDKinds.ProductsDirectory, True);
		If Object.OutgoingDocuments.FindRows(FilterParameters).Count() > 0 Then
			InAgreementCatalogIsUsed = True;
		EndIf;
	EndIf;
	
	For Each EnumValue IN Enums.EDExchangeFileFormats Do
		If EnumValue = Enums.EDExchangeFileFormats.CompoundFormat Then
			Continue;
		EndIf;
		RowArray = Object.ExchangeFilesFormats.FindRows(New Structure("FileFormat", EnumValue));
		If RowArray.Count() = 0 Then
			NewRow = Object.ExchangeFilesFormats.Add();
			NewRow.FileFormat  = EnumValue;
			// Default value for new
			If EnumValue = Enums.EDExchangeFileFormats.XML Then
				NewRow.Use = True;
			EndIf;
		EndIf;
	EndDo;
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure FormManagement(Form)
	
	Items = Form.Items;
	Object   = Form.Object;
	
	Items.Partner.Visible = False;
	If Form.UsedAdditionalAnalyticsPartners
		AND ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
		"UsePartnersAndCounterparties") Then
		
		Items.Partner.Visible = True;
	EndIf;
	
	If Not Form.CommandBar.ChildItems.FormED.ChildItems.Find(
			"FormCatalogAgreementForUseOfEDSendFolderByAgreement") = Undefined Then
		Form.CommandBar.ChildItems.FormED.ChildItems.FormCatalogAgreementForUseOfEDSendFolderByAgreement.Visible = Form.DirectoryUseInApplication;
		Form.CommandBar.ChildItems.FormED.ChildItems.FormCatalogAgreementForUseOfEDSendFolderByAgreement.Enabled = Form.InAgreementCatalogIsUsed;
	EndIf;
	If Not Form.CommandBar.ChildItems.FormED.ChildItems.Find(
			"FormProcessingElectronicDocumentsReshipED") = Undefined Then
		Form.CommandBar.ChildItems.FormED.ChildItems.FormProcessingElectronicDocumentsReshipED.Visible = Form.DirectoryUseInApplication;
		Form.CommandBar.ChildItems.FormED.ChildItems.FormProcessingElectronicDocumentsReshipED.Enabled = Form.InAgreementCatalogIsUsed;
	EndIf;
	
	If Form.ThroughDirectory Then
		CaptionPattern = NStr("en = 'Full path: %1'");
		Items.ExplanationDirectoryInboxDocuments.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			CaptionPattern, CommonUseClientServer.GetFullFileName(
			Form.PathToParentDirectoryEDFProfileSettings, Object.IncomingDocumentsDir));
		Items.OutgoingDocumentsDirClarification.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			CaptionPattern, CommonUseClientServer.GetFullFileName(
			Form.PathToParentDirectoryEDFProfileSettings, Object.OutgoingDocumentsDir));
	EndIf;
	
	Items.SendInvitation.Visible                              = Form.ThroughEDFOperator
		AND (Object.ConnectionStatus  = PredefinedValue("Enum.EDExchangeMemberStatuses.InvitationRequired")
		OR Object.ConnectionStatus = PredefinedValue("Enum.EDExchangeMemberStatuses.Disconnected")
		OR Object.ConnectionStatus = PredefinedValue("Enum.EDExchangeMemberStatuses.Error"));
	Items.AcceptInvitation.Visible                                = Form.ThroughEDFOperator
		AND Object.ConnectionStatus   = PredefinedValue("Enum.EDExchangeMemberStatuses.ApprovalRequired");
	Items.RejectInvitation.Visible                              = Form.ThroughEDFOperator
		AND Object.ConnectionStatus   = PredefinedValue("Enum.EDExchangeMemberStatuses.ApprovalRequired");
	
	// Direct exchange
	Items.GroupSettingsDirectExchangeThroughDirectory.Visible          = Form.ThroughDirectory;
	Items.GroupSettingsDirectExchangeThroughEMail.Visible = Form.ThroughEMail;
	Items.GroupSettingsDirectExchangeThroughFTP.Visible              = Form.ThroughFTP;
	Items.SettingsGroupDirectExchange.Visible                      = Form.ThroughDirectory OR Form.ThroughEMail OR Form.ThroughFTP;
	Items.GroupSettingsDirectExchangeEncryption.Visible            = Form.ThroughDirectory OR Form.ThroughEMail OR Form.ThroughFTP;
	Items.SettingsGroupDirectExchangeEDPackageFormat.Visible        = Form.ThroughDirectory OR Form.ThroughEMail OR Form.ThroughFTP;
	Items.GroupSettingsDirectExchangeTrustedCertificates.Visible = Form.ThroughDirectory OR Form.ThroughEMail OR Form.ThroughFTP;
	
	// AgreementSetupExtendedMode
	Items.FormEnableAgreementSetupExtendedMode.Title = NStr("en = 'Enable extended mode of EDF settings'");
	If Object.AgreementSetupExtendedMode Then
		Items.FormEnableAgreementSetupExtendedMode.Title = NStr("en = 'Disable extended mode of EDF settings'");
	EndIf;
	
	Items.EDFProfileSettings.Visible                         = Not Object.AgreementSetupExtendedMode;
	Items.CompanyID.Visible                   = Not Object.AgreementSetupExtendedMode;
	Items.CounterpartyID.Visible                   = Not Object.AgreementSetupExtendedMode;
	
	Items.OutgoingDocumentsCounterpartyID.Visible = Object.AgreementSetupExtendedMode;
	Items.OutgoingDocumentsCompanyID.Visible = Object.AgreementSetupExtendedMode;
	Items.OutgoingDocumentsEDFProfileSettings.Visible       = Object.AgreementSetupExtendedMode;
	
	Items.DecorationConnectionStatus.Width = ?(Object.AgreementSetupExtendedMode, 14, 17);
	
	// Using digital signature
	Items.OutgoingDocumentsUseDS.Visible      = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
		"UseDigitalSignatures") AND (Form.ThroughDirectory OR Form.ThroughEMail OR Form.ThroughFTP);
	Items.GroupSettingsDirectExchangeEncryption.Visible = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
		"UseDigitalSignatures");
	
	Items.GroupEDPackageDataEncryption.Visible                          = Object.EncryptEDPackageData;
	Items.GroupEDPackageFormat.Visible                                    = Object.ChangeEDPackageFormat;
	Items.GroupSettingsDirectExchangeTrustedCertificatesList.Visible = Object.VerifySignatureCertificates;
	
	// Available agreement states.
	Items.State.Enabled = Not Form.ThroughEDFOperator
		OR Object.ConnectionStatus = PredefinedValue("Enum.EDExchangeMemberStatuses.Connected");
	
EndProcedure

&AtServer
Procedure SetDefaultValues()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDFProfileSettings.Ref
	|FROM
	|	Catalog.EDFProfileSettings AS EDFProfileSettings
	|WHERE
	|	&Company";
	
	QueryTextCompany = "TRUE";
	If ValueIsFilled(Object.Company) Then
		QueryTextCompany = "EDFProfileSettings.Company = &Company";
		Query.SetParameter("Company", Object.Company);
	EndIf;
	Query.Text = StrReplace(Query.Text, "&Company", QueryTextCompany);
	
	Selection = Query.Execute().Select();
	
	If Selection.Count() = 1 Then
		Selection.Next();
		Object.EDFProfileSettings = Selection.Ref;
	EndIf;
	
EndProcedure

&AtServer
Procedure CounterpartyOnChangeAtServer()
	
	Object.Description = String(Object.Counterparty) + ?(ValueIsFilled(Object.CounterpartyContract),
		", " + String(Object.CounterpartyContract), "");
		
	If Object.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom") Then
		Object.CounterpartyID = "";
		Object.ConnectionStatus   = Enums.EDExchangeMemberStatuses.InvitationRequired;
		Object.AgreementState = Enums.EDAgreementStates.CoordinationExpected;
	Else
		SetIdentifier("Counterparties", Object.Counterparty, Object.CounterpartyID);
	EndIf;
	GetUsedEDExchangeMethods(Undefined, Object.CounterpartyID);
	
	If UsedAdditionalAnalyticsPartners AND ValueIsFilled(Object.Counterparty) Then
		AttributeNamePartnerCounterparty = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyPartner");
		Partner = CommonUse.ObjectAttributeValue(Object.Counterparty, AttributeNamePartnerCounterparty);
	EndIf;
	
EndProcedure

&AtServer
Procedure EDFProfileSettingsOnChangeAtServer()
	
	SettingsProfileParameters = CommonUse.ObjectAttributesValues(Object.EDFProfileSettings,
		"Company, CompanyID, EDExchangeMethod, InvitationsTextTemplate, OutgoingDocuments");
		
	Object.Company                 = SettingsProfileParameters.Company;
	Object.EDExchangeMethod              = SettingsProfileParameters.EDExchangeMethod;
	Object.CompanyID    = SettingsProfileParameters.CompanyID;
	
	// Importing PM from the EDF settings profile.
	Object.OutgoingDocuments.Load(SettingsProfileParameters.OutgoingDocuments.Unload());
	
	Object.ConnectionStatus = Enums.EDExchangeMemberStatuses.Connected;
	If SettingsProfileParameters.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
		Object.CounterpartyID = "";
		Object.InvitationText    = SettingsProfileParameters.InvitationsTextTemplate;
		Object.ConnectionStatus   = Enums.EDExchangeMemberStatuses.InvitationRequired;
		Object.AgreementState = Enums.EDAgreementStates.CoordinationExpected;
	Else
		Object.AgreementState = Enums.EDAgreementStates.CheckingTechnicalCompatibility;
		SetIdentifier("Counterparties", Object.Counterparty, Object.CounterpartyID);
	EndIf;
	GetUsedEDExchangeMethods(Object.EDFProfileSettings, Object.CounterpartyID);
	
	FormManagement(ThisObject);
	
EndProcedure

&AtServer
Procedure OutgoingDocumentsEDFProfileSettingsOnChangeAtServer(ValueSelected)
	
	If ValueSelected = Undefined Then
		Return;
	EndIf;
	
	RowData = Object.OutgoingDocuments.FindByID(ValueSelected);
	
	SettingsProfileParameters = CommonUse.ObjectAttributesValues(RowData.EDFProfileSettings,
		"CompanyID, EDExchangeMethod, InvitationsTextTemplate");
		
	RowData.CompanyID = SettingsProfileParameters.CompanyID;
	RowData.EDExchangeMethod           = SettingsProfileParameters.EDExchangeMethod;
	RowData.CounterpartyID = "";
	
	If SettingsProfileParameters.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
		If ThroughEDFOperator Then
			
			Filter = New Structure;
			Filter.Insert("EDExchangeMethod", Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom);
			FoundStrings = Object.OutgoingDocuments.FindRows(Filter);
			For Each String IN FoundStrings Do
				
				If ValueIsFilled(String.CounterpartyID) Then
					RowData.CounterpartyID = String.CounterpartyID;
				EndIf;
			EndDo;
		Else
			Object.InvitationText    = SettingsProfileParameters.InvitationsTextTemplate;
			Object.ConnectionStatus   = Enums.EDExchangeMemberStatuses.InvitationRequired;
			Object.AgreementState = Enums.EDAgreementStates.CoordinationExpected;
		EndIf;
	Else
		SetIdentifier("Counterparties", Object.Counterparty, RowData.CounterpartyID);
	EndIf;
	
	GetUsedEDExchangeMethods();
	
	FormManagement(ThisForm);
	
EndProcedure

&AtServer
Procedure GetUsedEDExchangeMethods(EDFProfileSettings = Undefined, CounterpartyID = Undefined)
	
	ThroughEDFOperator     = False;
	ThroughDirectory          = False;
	ThroughEMail = False;
	ThroughFTP              = False;
	
	// When changing EDF Profile settings in the Settings header.
	If EDFProfileSettings <> Undefined Then
		SettingsProfileParameters = CommonUse.ObjectAttributesValues(EDFProfileSettings,
			"Company, CompanyID, EDExchangeMethod");
	EndIf;
	
	For Each TableRow IN Object.OutgoingDocuments Do
		
		If EDFProfileSettings <> Undefined Then
			TableRow.EDFProfileSettings       = EDFProfileSettings;
			TableRow.EDExchangeMethod           = SettingsProfileParameters.EDExchangeMethod;
			TableRow.CompanyID = SettingsProfileParameters.CompanyID;
		EndIf;
			
		If CounterpartyID <> Undefined Then
			TableRow.CounterpartyID = CounterpartyID;
		EndIf;
		
		If TableRow.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom") Then
			ThroughEDFOperator = True;
		EndIf;
		If TableRow.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEMail") Then
			ThroughEMail = True;
			
			If Not ValueIsFilled(Object.CounterpartyEmail) Then
				Object.CounterpartyEmail = ElectronicDocumentsOverridable.CounterpartyEMailAddress(
					Object.Counterparty);
			EndIf;
		EndIf;
		
		If TableRow.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughDirectory") Then
			ThroughDirectory = True;
			
			PathToParentDirectoryEDFProfileSettings = CommonUse.ObjectAttributeValue(
				TableRow.EDFProfileSettings, "IncomingDocumentsResource");
			
			PatternName = NStr("en = '%1_%2'");
			AttributeNameCounterpartyName = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
				"CounterpartyDescription");
			CounterpartyDescription = CommonUse.ObjectAttributeValue(Object.Counterparty, AttributeNameCounterpartyName);
			
			AttributeNameCompanyName = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
				"CompanyDescription");
			CompanyDescription = CommonUse.ObjectAttributeValue(Object.Company, AttributeNameCompanyName);
			If Not ValueIsFilled(Object.IncomingDocumentsDir) Then
				Object.IncomingDocumentsDir = StrReplace(StringFunctionsClientServer.PlaceParametersIntoString(
					PatternName,
					CommonUseClientServer.ReplaceProhibitedCharsInFileName(CounterpartyDescription, ""),
					CommonUseClientServer.ReplaceProhibitedCharsInFileName(CompanyDescription, ""))," ", "");
			EndIf;
			
			If Not ValueIsFilled(Object.OutgoingDocumentsDir) Then
				Object.OutgoingDocumentsDir = StrReplace(StringFunctionsClientServer.PlaceParametersIntoString(
					PatternName,
					CommonUseClientServer.ReplaceProhibitedCharsInFileName(CompanyDescription, ""),
					CommonUseClientServer.ReplaceProhibitedCharsInFileName(CounterpartyDescription, ""))," ", "");
			EndIf;
		EndIf;
		
		If TableRow.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughFTP") Then
			ThroughFTP = True;
			
			PathToParentDirectoryEDFProfileSettings = CommonUse.ObjectAttributeValue(
				TableRow.EDFProfileSettings, "IncomingDocumentsResource");
			
			PatternName = NStr("en = '%1_%2'");
			AttributeNameCounterpartyName = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
				"CounterpartyDescription");
			CounterpartyDescription = CommonUse.ObjectAttributeValue(Object.Counterparty, AttributeNameCounterpartyName);
			
			AttributeNameCompanyName = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
				"CompanyDescription");
			CompanyDescription = CommonUse.ObjectAttributeValue(Object.Company, AttributeNameCompanyName);
			
			If Not ValueIsFilled(Object.IncomingDocumentsDirFTP) Then
				Object.IncomingDocumentsDirFTP = StrReplace(StringFunctionsClientServer.PlaceParametersIntoString(
					PatternName,
					CommonUseClientServer.ReplaceProhibitedCharsInFileName(CounterpartyDescription, ""),
					CommonUseClientServer.ReplaceProhibitedCharsInFileName(CompanyDescription, ""))," ", "");
			EndIf;
			
			If Not ValueIsFilled(Object.OutgoingDocumentsDirFTP) Then
				Object.OutgoingDocumentsDirFTP = StrReplace(StringFunctionsClientServer.PlaceParametersIntoString(
					PatternName,
					CommonUseClientServer.ReplaceProhibitedCharsInFileName(CompanyDescription, ""),
					CommonUseClientServer.ReplaceProhibitedCharsInFileName(CounterpartyDescription, ""))," ", "");
			EndIf;
		EndIf;
		
		If TableRow.OutgoingDocument = Enums.EDKinds.ProductsDirectory Then
		
			DirectoryUseInApplication = True;
			If TableRow.ToForm Then
				InAgreementCatalogIsUsed = True;
			EndIf;
		EndIf;

	EndDo;
	
EndProcedure

&AtClient
Procedure ChooseDirectoryHandle(PathToDirectory)
	
#If Not WebClient Then
		
	FolderDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	FolderDialog.Title = NStr("en = 'Specify a directory for ED exchange'");
	
	FolderDialog.Directory = ?(ValueIsFilled(PathToDirectory),
		CommonUseClientServer.GetFullFileName(PathToParentDirectoryEDFProfileSettings, PathToDirectory), PathToParentDirectoryEDFProfileSettings);
	If FolderDialog.Choose() Then
		FileStructure = CommonUseClientServer.SplitFullFileName(FolderDialog.Directory, True);
		PathToDirectory = FileStructure.Name;
	EndIf;
	
	FormManagement(ThisObject);
	
#EndIf
	
EndProcedure

&AtServer
Procedure AddDateByTabularSection(ValueSelected, AddressInStorage = Undefined)
	
	If ValueSelected = Undefined Then
		Return;
	EndIf;
	
	Imprint = "";
	BinaryData = Undefined;
	CertificatePresentation = "";
	
	If AddressInStorage <> Undefined Then
		BinaryData = GetFromTempStorage(AddressInStorage);
		Try
			CryptoCertificate = New CryptoCertificate(BinaryData);
		Except
			MessageText = NStr("en = 'File certificate should be in the DER X format.509, operation aborted.'");
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		EndTry;
		
		Imprint = Base64String(CryptoCertificate.Imprint);
		CertificatePresentation = DigitalSignatureClientServer.SubjectPresentation(CryptoCertificate);
	EndIf;
	
	RowData = Object.CounterpartySignaturesCertificates.FindByID(ValueSelected);
	RowData.Imprint  = Imprint;
	RowData.CounterpartyCertificatePresentation = CertificatePresentation;
	
	ValueStorage  = New ValueStorage(BinaryData);
	
	CatalogObject = FormAttributeToValue("Object");
	CatalogObject.CounterpartySignaturesCertificates[RowData.LineNumber - 1].Certificate = ValueStorage;
	CatalogObject.Write();
	ValueToFormAttribute(CatalogObject, "Object");
	
EndProcedure

&AtServer
Procedure PutInCertificateRepositoryConfiguration(AddressInStorage = Undefined)
	
	CertificatePresentation = "";
	
	If AddressInStorage <> Undefined Then
		BinaryData = GetFromTempStorage(AddressInStorage);
		
		Try
			CryptoCertificate = New CryptoCertificate(BinaryData);
		Except
			MessageText = NStr("en = 'File certificate should be in the DER X format.509, operation aborted.'");
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		EndTry;
		
		CertificatePresentation = DigitalSignatureClientServer.SubjectPresentation(CryptoCertificate);
		
	EndIf;
	CounterpartyEncryptionCertificatePresentation = CertificatePresentation;
	
	ValueStorage  = New ValueStorage(BinaryData);
	CatalogObject = FormAttributeToValue("Object");
	CatalogObject.CounterpartyCertificateForEncryption = ValueStorage;
	CatalogObject.Write();
	
	ValueToFormAttribute(CatalogObject, "Object");
	ThisObject.Read();
	
EndProcedure

&AtServer
Procedure FillFileFormatsAvailableValues()
	
	For Each EnumValue IN Enums.EDExchangeFileFormats Do
		If EnumValue = Enums.EDExchangeFileFormats.CompoundFormat Then
			Continue;
		EndIf;
		RowArray = Object.ExchangeFilesFormats.FindRows(New Structure("FileFormat", EnumValue));
		If RowArray.Count() = 0 Then
			NewRow = Object.ExchangeFilesFormats.Add();
			NewRow.FileFormat  = EnumValue;
			// Default value for new
			If EnumValue = Enums.EDExchangeFileFormats.XML AND Object.Ref.IsEmpty() Then
				NewRow.Use = True;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetIdentifier(CatalogName, IdentifierSourceRef, SearchIdentifier)
	
	If CatalogName = "Counterparties" Then
		AttributeNameCounterpartyTIN = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyTIN");
		AttributeNameCounterpartyKPP = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyCRR");
		
		CounterpartyParameters = CommonUse.ObjectAttributesValues(IdentifierSourceRef,
			AttributeNameCounterpartyTIN + ", " + AttributeNameCounterpartyKPP);
		
		RowFill = String(CounterpartyParameters[AttributeNameCounterpartyTIN])
			+ "_" + String(CounterpartyParameters[AttributeNameCounterpartyKPP]);
		If Right(RowFill, 1) = "_" Then
			RowFill = StrReplace(RowFill, "_", "");
		EndIf;
		SearchIdentifier = TrimAll(RowFill);
	EndIf;
	
EndProcedure

&AtServer
Procedure CounterpartyIdUsageUnique(Cancel)
	
	// Checking for exceptional use of the EDF setting by attributes: CounterpartyID.
	Filter = New Structure;
	Filter.Insert("ToForm", True);
	Table = Object.OutgoingDocuments.Unload(Filter);
	
	CounterpartiesIdArray = Table.UnloadColumn("CounterpartyID");
	
	QueryByID = New Query;
	QueryByID.SetParameter("CurrentSetting",     Object.Ref);
	QueryByID.SetParameter("Company",          Object.Company);
	QueryByID.SetParameter("Counterparty",           Object.Counterparty);
	QueryByID.SetParameter("CounterpartiesIdArray", CounterpartiesIdArray);
	QueryByID.Text =
	"SELECT ALLOWED
	|	EDFSettingsOutgoingDocuments.Ref.Counterparty AS Counterparty,
	|	EDFSettingsOutgoingDocuments.Ref.Company AS Company,
	|	EDFSettingsOutgoingDocuments.CounterpartyID AS CounterpartyID
	|FROM
	|	Catalog.EDUsageAgreements.OutgoingDocuments AS EDFSettingsOutgoingDocuments
	|WHERE
	|	Not EDFSettingsOutgoingDocuments.Ref.DeletionMark
	|	AND EDFSettingsOutgoingDocuments.Ref <> &CurrentSetting
	|	AND EDFSettingsOutgoingDocuments.Ref.Company = &Company
	|	AND EDFSettingsOutgoingDocuments.Ref.Counterparty = &Counterparty
	|	AND EDFSettingsOutgoingDocuments.ToForm
	|	AND EDFSettingsOutgoingDocuments.CounterpartyID IN (&CounterpartiesIdArray)
	|
	|GROUP BY
	|	EDFSettingsOutgoingDocuments.Ref.Counterparty,
	|	EDFSettingsOutgoingDocuments.Ref.Company,
	|	EDFSettingsOutgoingDocuments.CounterpartyID";
	
	Result = QueryByID.Execute();
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		While Selection.Next() Do
			MessagePattern = NStr("en = 'Counterparty
			|identifier %1 is already used in EDF setting between counterparty %2 and company %3'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, Selection.CounterpartyID,
			Selection.Counterparty, Selection.Company);
			CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
		EndDo;
	EndIf;
	
EndProcedure

// Testing EDF settings
&AtServer
Function EDFProfileSettingsParameters(EDFProfileSettings)
	
	EDFProfileSettingsParameters = CommonUse.ObjectAttributesValues(EDFProfileSettings,
		"IncomingDocumentsResource, CompanySignatureCertificates");
	SelectionOfCertificates = EDFProfileSettingsParameters.CompanySignatureCertificates.Select();
	AccCertificatesAndTheirStructures = New Map;
	If SelectionOfCertificates.Count() > 0 Then
		While SelectionOfCertificates.Next() Do
			If Not ValueIsFilled(SelectionOfCertificates.Certificate.User)
				OR SelectionOfCertificates.Certificate.User = SessionParameters.CurrentUser Then
				Certificate = SelectionOfCertificates.Certificate;
				CertificateParameters = ElectronicDocumentsServiceCallServer.CertificateAttributes(Certificate);
				CertificateParameters.Insert("SignatureCertificate", Certificate);
				AccCertificatesAndTheirStructures.Insert(Certificate, CertificateParameters);
			EndIf;
		EndDo;
	EndIf;
	EDFProfileSettingsParameters.Insert("CompanySignatureCertificates", AccCertificatesAndTheirStructures);
	
	Return EDFProfileSettingsParameters;
	
EndFunction

&AtServer
Procedure TestLinksDirectExchangeAtServer(IncomingDocumentsDir, OutgoingDocumentsDir, EDFProfileSettings)
	
	// Block of checking the access to directories.
	MessagePattern = NStr("en = 'Checking access to exchange directories.
		|%1'");
	Try
		If ElectronicDocumentsServiceCallServer.ValidateCatalogAvailabilityForDirectExchange(IncomingDocumentsDir)
			AND ElectronicDocumentsServiceCallServer.ValidateCatalogAvailabilityForDirectExchange(OutgoingDocumentsDir) Then
			TestResult = NStr("en = 'Passed successfully.'");
		Else
			TestResult = ElectronicDocumentsServiceCallServer.GetMessageAboutError("107");
		EndIf;
	Except
		ResultTemplate = NStr("en = '%1 %2'");
		ErrorText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("107");
		TestResult = StringFunctionsClientServer.PlaceParametersIntoString(ResultTemplate, ErrorText,
			BriefErrorDescription(ErrorInfo()));
	EndTry;
	MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, TestResult);
	MessageText = NStr("en = 'Exchange text by %1 profile.'") + " " + MessageText;
	MessageText = StrReplace(MessageText, "%1", EDFProfileSettings);
	CommonUseClientServer.MessageToUser(MessageText);
	
EndProcedure

&AtServer
Procedure ExchangeConnectionTestThroughFTPOnServer(EDFProfileSettings, IncomingDocumentsDir, OutgoingDocumentsDir)
	
	ElectronicDocumentsService.TestLinksExchangeThroughFTP(EDFProfileSettings, IncomingDocumentsDir, OutgoingDocumentsDir);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Office handlers for asynchronous dialogs

&AtClient
Procedure FinishDataEncryptionChange(Val Result, Val AdditionalParameters) Export
	
	If Result <> Undefined Then
		If Result = DialogReturnCode.Yes Then
			EmptyRef = PredefinedValue("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef");
			Object.CompanyCertificateForDetails = EmptyRef;
			PutInCertificateRepositoryConfiguration();
		Else
			Object.EncryptEDPackageData = Not Object.EncryptEDPackageData;
		EndIf;
	EndIf;
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure FinishPackageFormatChange(Val Result, Val AdditionalParameters) Export
	
	If Result <> Undefined Then
		If Result = DialogReturnCode.Yes Then
			For Each TableRow IN Object.ExchangeFilesFormats Do
				If TableRow.FileFormat <> PredefinedValue("Enum.EDExchangeFileFormats.XML") Then
					TableRow.Use = False;
				EndIf;
			EndDo;
		Else
			Object.ChangeEDPackageFormat = Not Object.ChangeEDPackageFormat;
		EndIf;
	EndIf;
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure FinishChangeChecksCertificates(Val Result, Val AdditionalParameters) Export
	
	If Result <> Undefined Then
		If Result = DialogReturnCode.Yes Then
			Object.CounterpartySignaturesCertificates.Clear();
		Else
			Object.VerifySignatureCertificates = Not Object.VerifySignatureCertificates;
		EndIf;
	EndIf;
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure FinishInvitationsProcessing(Val Result, Val AdditionalParameters) Export
	
	If Result <> Undefined Then
		If Result = DialogReturnCode.Yes Then
			Write();
		Else
			Return;
		EndIf;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("EDFSetup",               Object.Ref);
	FormParameters.Insert("FormIsOpenableFromEDFSetup", True);
	Action = "";
	If TypeOf(AdditionalParameters) = Type("Structure")
		AND AdditionalParameters.Property("Action", Action) Then
		If Action = "Accept" Then
			FormParameters.Insert("Accept", True);
		ElsIf Action = "Reject" Then
			FormParameters.Insert("Reject", True);
		EndIf;
	EndIf;
	
	OpenForm("Catalog.EDUsageAgreements.Form.InvitationForm", FormParameters);
	
EndProcedure

&AtClient
Procedure CompleteSettingsTest(Val Result, Val AdditionalParameters) Export
	
	If Result <> Undefined Then
		If Result = "Cancel" Then
			Return;
		ElsIf Modified Then
			Write();
		EndIf;
	EndIf;
	
	CertificatesToVerification = New Structure;
	CertificatesToVerification.Insert("CompanySignatureCertificates", New Map);
	
	If ThroughEDFOperator Then
		
		Filter = New Structure;
		Filter.Insert("EDExchangeMethod", PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom"));
		OutgoingDocumentsTableRow = Object.OutgoingDocuments.FindRows(Filter);
		
		CheckCertificate(OutgoingDocumentsTableRow[0].EDFProfileSettings, True);
		
	EndIf;
	
	If ThroughEMail Then
		Filter = New Structure;
		Filter.Insert("EDExchangeMethod", PredefinedValue("Enum.EDExchangeMethods.ThroughEMail"));
		OutgoingDocumentsTableRow = Object.OutgoingDocuments.FindRows(Filter);

		Status(NStr("en = 'Settings test.'"),
			,
			NStr("en = 'Testing ED exchange through electronic mail. Please wait...'"));
		EDFProfileSettingsParameters = EDFProfileSettingsParameters(OutgoingDocumentsTableRow[0].EDFProfileSettings);
		EmailOperationsClient.CheckAccount(EDFProfileSettingsParameters.IncomingDocumentsResource);
		Filter.Insert("ToForm", True);
		Filter.Insert("UseDS", True);
		BOTProfiles = Object.OutgoingDocuments.FindRows(Filter);
		If BOTProfiles.Count() > 0 Then
			CheckCertificate(BOTProfiles[0].EDFProfileSettings);
		EndIf;
	EndIf;
	
	If ThroughDirectory Then
		Filter = New Structure;
		Filter.Insert("EDExchangeMethod", PredefinedValue("Enum.EDExchangeMethods.ThroughDirectory"));
		OutgoingDocumentsTableRow = Object.OutgoingDocuments.FindRows(Filter);
		Status(NStr("en = 'Settings test.'"),
		,
		NStr("en = 'Testing ED exchange through directory. Please wait...'"));
		EDFProfileSettingsParameters = EDFProfileSettingsParameters(OutgoingDocumentsTableRow[0].EDFProfileSettings);
		
		PathToParentDirectoryEDFProfileSettings = EDFProfileSettingsParameters.IncomingDocumentsResource;
		
		TestLinksDirectExchangeAtServer(
			CommonUseClientServer.GetFullFileName(PathToParentDirectoryEDFProfileSettings,
			Object.IncomingDocumentsDir),
			CommonUseClientServer.GetFullFileName(PathToParentDirectoryEDFProfileSettings,
			Object.OutgoingDocumentsDir),
			OutgoingDocumentsTableRow[0].EDFProfileSettings);
		Filter.Insert("ToForm", True);
		Filter.Insert("UseDS", True);
		BOTProfiles = Object.OutgoingDocuments.FindRows(Filter);
		If BOTProfiles.Count() > 0 Then
			CheckCertificate(BOTProfiles[0].EDFProfileSettings);
		EndIf;
	EndIf;
	
	If ThroughFTP Then
		Filter = New Structure;
		Filter.Insert("EDExchangeMethod", PredefinedValue("Enum.EDExchangeMethods.ThroughFTP"));
		OutgoingDocumentsTableRow = Object.OutgoingDocuments.FindRows(Filter);
		
		Status(NStr("en = 'Settings test.'"),
			,
			NStr("en = 'Testing ED exchange through FTP. Please wait...'"));
		EDFProfileSettingsParameters = EDFProfileSettingsParameters(OutgoingDocumentsTableRow[0].EDFProfileSettings);
		
		PathToParentDirectoryEDFProfileSettings = EDFProfileSettingsParameters.IncomingDocumentsResource;
		
		ExchangeConnectionTestThroughFTPOnServer(OutgoingDocumentsTableRow[0].EDFProfileSettings,
			CommonUseClientServer.GetFullFileName(PathToParentDirectoryEDFProfileSettings,
			Object.IncomingDocumentsDirFTP),
			CommonUseClientServer.GetFullFileName(PathToParentDirectoryEDFProfileSettings,
			Object.OutgoingDocumentsDirFTP));
		Filter.Insert("ToForm", True);
		Filter.Insert("UseDS", True);
		BOTProfiles = Object.OutgoingDocuments.FindRows(Filter);
		If BOTProfiles.Count() > 0 Then
			CheckCertificate(BOTProfiles[0].EDFProfileSettings);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckCertificate(ProfileEDF, ForAuthorization = False)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ProfileEDF", ProfileEDF);
	AdditionalParameters.Insert("ForAuthorization", ForAuthorization);
	Notification = New NotifyDescription(
		"AfterObtainingPrintsExecuteCheckCertificates", ThisObject, AdditionalParameters);
		
	DigitalSignatureClient.GetCertificatesThumbprints(Notification, True, False);
	
EndProcedure

&AtClient
Procedure AfterObtainingPrintsExecuteCheckCertificates(Prints, AdditionalParameters) Export
	
	CertificateTumbprintsArray = New Array;
	
	For Each KeyValue IN Prints Do
		CertificateTumbprintsArray.Add(KeyValue.Key);
	EndDo;
	
	ProfileEDF = AdditionalParameters.ProfileEDF;
	ForAuthorization = AdditionalParameters.ForAuthorization;
	
	Map = ElectronicDocumentsServiceCallServer.MatchAvailableCertificatesAndSettings(
												CertificateTumbprintsArray, ProfileEDF, ForAuthorization);
	
	Certificate = Undefined;
	CertificateParameters = Undefined;
	PasswordReceived = False;
	For Each KeyValue IN Map Do
		CurCertificate = KeyValue.Key;
		If Certificate = Undefined Then
			// If the match does not contain certificates with a saved password, for test take the first certificate from the list.
			Certificate = CurCertificate;
			CertificateParameters = KeyValue.Value;
		EndIf;
		If KeyValue.Value.Property("PasswordReceived", PasswordReceived) AND PasswordReceived = True Then
			Certificate = CurCertificate;
			CertificateParameters = KeyValue.Value;
			Break;
		EndIf;
	EndDo;
	If Certificate = Undefined Then
		MessageText = NStr("en = 'Exchange text by %1 profile. No available certificates in the profile.
			|Test not executed.'");
		MessageText = StrReplace(MessageText, "%1", ProfileEDF);
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		ElectronicDocumentsServiceClient.CertificateValidationSettingsTest(Certificate, , ForAuthorization, ThisForm);
	EndIf;
	
EndProcedure

&AtClient
Procedure CompleteInclusionAdvancedModeSettings(Val Result, Val AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		EnableAgreementSetupExtendedModeAtServer();
		Object.AgreementSetupExtendedMode = Not Object.AgreementSetupExtendedMode;
	EndIf;
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure FileChoiceProcessing(Result, Address, FileName, AdditionalParameters) Export
	
	If Result = True Then
		SelectedRow = Items.CounterpartySignaturesCertificates.CurrentRow;
		AddDateByTabularSection(SelectedRow, Address);
	EndIf;
	
	// To update the certificate presentation on the form
	RowData = Object.CounterpartySignaturesCertificates.FindByID(SelectedRow);
	Items.CounterpartySignaturesCertificates.CurrentData.CounterpartyCertificatePresentation = RowData.CounterpartyCertificatePresentation;
	
EndProcedure

&AtClient
Procedure FinishStateChange(Val Result, Val AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FormParameters = New Structure;
		FormParameters.Insert("EDFSetup",     Object.Ref);
		FormParameters.Insert("FormIsOpenableFromEDFSetup", True);
		FormParameters.Insert("Reject",                  True);
		
		OpenForm("Catalog.EDUsageAgreements.Form.InvitationForm", FormParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectionProcessEncryptionCertificateFile(Result, Address, FileName, AdditionalParameters) Export
	
	If Result = True Then
		PutInCertificateRepositoryConfiguration(Address);
	EndIf;
	
EndProcedure

&AtClient
Procedure CompanyCertificateForDetailsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	Form = GetForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.ChoiceForm", , Item);
	CommonUseClientServer.SetFilterDynamicListItem(Form.List, "Company", Object.Company,
		DataCompositionComparisonType.Equal, , True, DataCompositionSettingsItemViewMode.Inaccessible);
	Form.Open();
	
EndProcedure

&AtClient
Procedure CompanyCertificateForDetailsChoiceDataProcessor(Item, ValueSelected, StandardProcessing)
	
	AddCertificateWH(ValueSelected);
	
EndProcedure

&AtServer
Procedure AddCertificateWH(ValueSelected)
	
	Object.CompanyCertificateForDetails = ValueSelected;
	
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
