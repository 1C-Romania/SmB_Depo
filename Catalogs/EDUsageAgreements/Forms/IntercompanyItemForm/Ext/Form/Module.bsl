// Electronic document flow (for Intercompany) is required
// to keep track of legal interactions (transfer/return of goods between companies).
// Accordingly, any ED generated within Intercompany should be digitally signed.
// Therefore, it is enough to specify an ED kind in the ED usage agreement. 
// That will automatically mean that it is necessary to sign ED
// and receive a signature confirmation from another side.

#Region ServiceProceduresAndFunctions

&AtServer
Function ObjectFilled()
	
	Return FormAttributeToValue("Object").CheckFilling();
	
EndFunction

&AtServer
Procedure SetIdentifier(IdentificatorSource, Data)
	
	If IdentificatorSource = "Company" Then
		RowFill = String(Data.TIN)+"_"+String(Data.KPP);
		If Right(RowFill, 1) = "_" Then
			RowFill = StrReplace(RowFill, "_", "");
		EndIf;
		Object.CompanyID = TrimAll(RowFill);
	Else
		RowFill = String(Data.TIN)+"_"+String(Data.KPP);
		If Right(RowFill, 1) = "_" Then
			RowFill = StrReplace(RowFill, "_", "");
		EndIf;
		Object.CounterpartyID = TrimAll(RowFill);
	EndIf;
	
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
			If (EnumValue = Enums.EDExchangeFileFormats.XML
				OR EnumValue = Enums.EDExchangeFileFormats.HTML) AND Object.Ref.IsEmpty() Then
				NewRow.Use  = True;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillEDTypesAvailableValues()
	
	EDActualKinds = ElectronicDocumentsReUse.GetEDActualKinds();
	
	For Each EnumValue IN EDActualKinds Do
		If EnumValue = Enums.EDKinds.ProductsReturnBetweenCompanies
			OR EnumValue = Enums.EDKinds.GoodsTransferBetweenCompanies Then
			
			RowArray = Object.IncomingDocuments.FindRows(New Structure("IncomingDocument", EnumValue));
			If RowArray.Count() = 0 Then
				NewRow = Object.IncomingDocuments.Add();
				NewRow.IncomingDocument = EnumValue;
			EndIf;
			
			RowArray = Object.OutgoingDocuments.FindRows(New Structure("OutgoingDocument", EnumValue));
			If RowArray.Count() = 0 Then
				NewRow = Object.OutgoingDocuments.Add();
				NewRow.OutgoingDocument = EnumValue;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure DetermineAvailabilitySignaturesCertificates()
	
	Items.CounterpartySignaturesCertificates.Enabled = Object.VerifySignatureCertificates;
	
EndProcedure

&AtServer
Procedure SetValuesOfExchangeStepsBySettings(ParametersStructure)
	
	StatusesArray = ElectronicDocumentsService.ReturnEDStatusesArray(ParametersStructure);
	If StagesTableOutgoing <> Undefined Then
		StagesTableOutgoing.Clear();
		
		For Each Item IN StatusesArray Do
			StagesTableOutgoing.Add(Item);
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillStructureParameters(DataStructure)
	
	ParametersStructure = EDKindParametersStructure();
	If DataStructure.ToForm Then
		FillPropertyValues(ParametersStructure, DataStructure);
		ParametersStructure.ExchangeMethod = Object.EDExchangeMethod;
		ParametersStructure.Direction = Enums.EDDirections.Outgoing;
		ParametersStructure.PackageFormatVersion = Undefined;
	EndIf;
	SetValuesOfExchangeStepsBySettings(ParametersStructure);
	
EndProcedure

&AtServer
Procedure AddCertificatesOfTabularSection(AddressInStorage, RowIndex, CertificateParameters)
	
	FileData              = GetFromTempStorage(AddressInStorage);
	AddDateByTabularSection(RowIndex, FileData, CertificateParameters);
	
EndProcedure

&AtServer
Procedure AddDateByTabularSection(RowIndex, BinaryData, StructureOfResultParameters)
	
	If RowIndex < 0 Then
		Return ;
	EndIf;
	
	If BinaryData <> Undefined Then
		
		SignatureCertificate = New CryptoCertificate(BinaryData);
		CertificatePresentation = DigitalSignatureClientServer.SubjectPresentation(SignatureCertificate);
		Imprint = Base64String(SignatureCertificate.Imprint);
		
		ValueStorage  = New ValueStorage(BinaryData);
		Document = FormAttributeToValue("Object");
		Document.CounterpartySignaturesCertificates[RowIndex].Certificate = ValueStorage;
		Document.CounterpartySignaturesCertificates[RowIndex].Imprint  = Imprint;
		Document.Write();
		
		ValueToFormAttribute(Document, "Object");
		Read();
		ReReadDataByCertificate(Document);
		
		StructureOfResultParameters.Presentation = CertificatePresentation;
		StructureOfResultParameters.Imprint     = Imprint;
	EndIf;
		
EndProcedure

&AtServer
Procedure ReReadDataByCertificate(DocumentObject)
	
	For Each ItemRow IN DocumentObject.CounterpartySignaturesCertificates Do
		CertificateBinaryData = ItemRow.Certificate.Get();
		If CertificateBinaryData <> Undefined Then
			
			Try
				SignatureCertificate = New CryptoCertificate(CertificateBinaryData);
				CertificatePresentation = DigitalSignatureClientServer.SubjectPresentation(SignatureCertificate);
				Object.CounterpartySignaturesCertificates[DocumentObject.CounterpartySignaturesCertificates.IndexOf(ItemRow)].CounterpartyCertificatePresentation = CertificatePresentation;
			Except
			EndTry;
			
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshDataDocument()
	
	Document = FormAttributeToValue("Object");
	ReReadDataByCertificate(Document);
	
EndProcedure

&AtServer
Procedure CheckRelevanceDataAgreement(TextActualityError)
	
	QueryByAgreements = New Query;
	QueryByAgreements.SetParameter("AgreementStatus",  Enums.EDAgreementsStatuses.Acts);
	QueryByAgreements.SetParameter("CurrentAgreement", Object.Ref);
	QueryByAgreements.SetParameter("Company",       Object.Company);
	QueryByAgreements.SetParameter("Counterparty",        Object.Counterparty);
	QueryByAgreements.Text =
	"SELECT ALLOWED
	|	EDUsageAgreementsIncomingDocuments.IncomingDocument AS DocumentType,
	|	TRUE AS Incoming,
	|	EDUsageAgreementsIncomingDocuments.Ref AS Agreement
	|FROM
	|	Catalog.EDUsageAgreements.IncomingDocuments AS EDUsageAgreementsIncomingDocuments
	|WHERE
	|	EDUsageAgreementsIncomingDocuments.Ref.AgreementStatus = &AgreementStatus
	|	AND EDUsageAgreementsIncomingDocuments.Ref.DeleteIsTypical = FALSE
	|	AND EDUsageAgreementsIncomingDocuments.ToForm = TRUE
	|	AND EDUsageAgreementsIncomingDocuments.Ref.DeletionMark = FALSE
	|	AND EDUsageAgreementsIncomingDocuments.Ref <> &CurrentAgreement
	|	AND EDUsageAgreementsIncomingDocuments.Ref.Company = &Company
	|	AND EDUsageAgreementsIncomingDocuments.Ref.Counterparty = &Counterparty
	|
	|UNION ALL
	|
	|SELECT
	|	EDUsageAgreementsOutgoingDocuments.OutgoingDocument,
	|	FALSE,
	|	EDUsageAgreementsOutgoingDocuments.Ref
	|FROM
	|	Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
	|WHERE
	|	EDUsageAgreementsOutgoingDocuments.ToForm = TRUE
	|	AND EDUsageAgreementsOutgoingDocuments.Ref.DeleteIsTypical = FALSE
	|	AND EDUsageAgreementsOutgoingDocuments.Ref.AgreementStatus = &AgreementStatus
	|	AND EDUsageAgreementsOutgoingDocuments.Ref.DeletionMark = FALSE
	|	AND EDUsageAgreementsOutgoingDocuments.Ref <> &CurrentAgreement
	|	AND EDUsageAgreementsOutgoingDocuments.Ref.Company = &Company
	|	AND EDUsageAgreementsOutgoingDocuments.Ref.Counterparty = &Counterparty";
	
	Result = QueryByAgreements.Execute().Unload();
	
	OutboxErrorText = "";
	InboxErrorText = "";
	CheckDocumentsUniqueness(Object.OutgoingDocuments, Result, OutboxErrorText);
	CheckDocumentsUniqueness(Object.IncomingDocuments, Result, InboxErrorText, True);
	
	TextActualityError = OutboxErrorText + InboxErrorText;
	
EndProcedure

&AtServer
Procedure CheckDocumentsUniqueness(TabularSectionDocuments, CheckResult, ErrorText, ChecksIncomingDocuments = False)
	
	FilterExistingDocuments = New Structure("Incoming", ChecksIncomingDocuments);
	DocumentsTypesOtherAgreements = CheckResult.FindRows(FilterExistingDocuments);
	If DocumentsTypesOtherAgreements.Count() = 0 Then
		Return;
	EndIf;
	
	For Each CurrentDocumentOfAgreement IN TabularSectionDocuments Do
		If CurrentDocumentOfAgreement.ToForm Then
			For Each DocumentInOtherAgreements IN DocumentsTypesOtherAgreements Do
				If CurrentDocumentOfAgreement[?(ChecksIncomingDocuments, "IncomingDocument", "OutgoingDocument")] = DocumentInOtherAgreements.DocumentType Then
					ErrorText = NStr("en='For a kind of documents %1"
"%2 a valid agreement already exists between parties %3"
"- %4: %5."
"';ru='По виду электронных документов"
"%1 %2 уже существует действующее соглашение между"
"участниками %3 - %4: %5."
"'");
					ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
						ErrorText, DocumentInOtherAgreements.DocumentType,
						?(ChecksIncomingDocuments, "Incoming", "Outgoing"),
						Object.Company, 
						Object.Counterparty, 
						DocumentInOtherAgreements.Agreement);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure ValidateWriteAgreement(ContinuationHandler)
	
	If Not Parameters.Key.IsEmpty() Then
		ExecuteNotifyProcessing(ContinuationHandler);
	EndIf;
	
	AdditParameters = New Structure("ContinuationHandler", ContinuationHandler);
	If Not Object.DeleteIsTypical Then
		QuestionText = NStr("en='External certificates can be selected only in the written agreement."
"Write agreement?';ru='Внешние сертификаты можно выбирать только в записанном соглашении."
"Записать соглашение?'");
		NotifyDescription = New NotifyDescription("FinishCheckingAgreement", ThisObject, AdditParameters);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	Else
		FinishCheckingAgreement(DialogReturnCode.Yes, AdditParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeCaptionDirectionDocuments()
	
	MessagePattern = NStr("en='From: %1, to: %2';ru='От кого: %1, кому: %2'");
	TitleDocumentsDirection = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, 
		Object.Company, Object.Counterparty);
	
EndProcedure

&AtServer
Function CompaniesList(ExcludedElement)
	
	DescriptionCompanyCatalog = ElectronicDocumentsReUse.GetAppliedCatalogName("Companies");
	If Not ValueIsFilled(DescriptionCompanyCatalog) Then
		DescriptionCompanyCatalog = "Companies";
	EndIf; 
	
	CompaniesArray = New Array;
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Companies.Ref,
	|	Companies.Description
	|FROM
	|	Catalog."+ DescriptionCompanyCatalog +" AS
	|Companies
	|	WHERE Companies.Ref <> &Ref";
	Query.SetParameter("Ref", ExcludedElement);
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		CompaniesArray = Result.Unload().UnloadColumn("Ref");
	EndIf;
	
	Return CompaniesArray;
	
EndFunction

&AtClient
Procedure FillDescription()
	
	Company = Object.Company;
	Counterparty  = Object.Counterparty;
	If Not ValueIsFilled(Object.Description)
		AND ValueIsFilled(Company)
		AND ValueIsFilled(Counterparty) Then
		Object.Description = "" + Company + " -> " + Counterparty;
	EndIf;
	
EndProcedure

&AtClient
Procedure FillCompaniesChoiceList(ChoiceList, ExcludedElement)
	
	CompaniesArray = CompaniesList(ExcludedElement);
	If CompaniesArray.Count() > 0 Then
		ChoiceList.LoadValues(CompaniesArray);
	EndIf;
	
EndProcedure

&AtServer
Function EDKindParametersStructure()
	
	ReturnStructure = New Structure("ExchangeMethod, Direction,
	|EDKind, UseSignature, UseReceipt, PackageFormatVersion");
	Return ReturnStructure;
	
EndFunction

&AtClient
Function CertificateStructure()
	
	ReturnStructure =  New Structure("Presentation, Thumbprint","","");
	Return ReturnStructure;
	
EndFunction

&AtServer
Procedure RefreshFormTitle()
	
	If Object.DeleteIsTypical Then
		HeaderText = NStr("en='Typical setup of EDF between companies';ru='Типовая настройка ЭДО между организациями'");
	Else
		HeaderText = NStr("en='EDF setup between companies';ru='Настройка ЭДО между организациями'");
	EndIf;
	If Not ValueIsFilled(Object.Ref) Then
		Title = HeaderText + NStr("en=' (creation)';ru=' (создание)'");
	Else
		Title = HeaderText;
	EndIf;
	
EndProcedure

&AtClient
Procedure FillStagesTable()
	
	If Items.Pages.CurrentPage <> Undefined Then
		CurrentData = Undefined;
		If Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupOutgoingDocuments Then
			CurrentData = Items.OutgoingDocuments.CurrentData;
			EDKind = CurrentData.OutgoingDocument;
		EndIf;
		If CurrentData <> Undefined Then
			DataStructure = New Structure("UseSignature, UseReceipt, ToForm, EDKind");
			DataStructure.UseSignature = CurrentData.UseDS;
			DataStructure.UseReceipt = CurrentData.ExpectDeliveryTicket;
			DataStructure.ToForm = CurrentData.ToForm;
			DataStructure.EDKind = EDKind;
			FillStructureParameters(DataStructure);
		EndIf;
	EndIf	

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Office handlers for asynchronous dialogs

&AtClient
Procedure FinishCheckingAgreement(Val Result, Val AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes AND ObjectFilled() Then
		ContinuationHandler = "";
		If TypeOf(AdditionalParameters) = Type("Structure")
			AND AdditionalParameters.Property("ContinuationHandler", ContinuationHandler)
			AND TypeOf(ContinuationHandler) = Type("NotifyDescription") Then
			ExecuteNotifyProcessing(ContinuationHandler);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure HandleChangeSenderRecipient(Val Result, Val AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		ValueSelected = "";
		AttributeName = "";
		If TypeOf(AdditionalParameters) = Type("Structure")
			AND AdditionalParameters.Property("AttributeName", AttributeName)
			AND AdditionalParameters.Property("ValueSelected", ValueSelected) Then
			SetIdentifier(AttributeName, ValueSelected);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure FileChoiceProcessing(Result, Address, FileName, AdditionalParameters) Export
	
	If Result = True Then
		RowIndex = Object.CounterpartySignaturesCertificates.IndexOf(Items.CounterpartySignaturesCertificates.CurrentData);
		OptionsOfAddedCertificate = CertificateStructure();
		AddCertificatesOfTabularSection(Address, RowIndex, OptionsOfAddedCertificate);
		Items.CounterpartySignaturesCertificates.CurrentData.CounterpartyCertificatePresentation = OptionsOfAddedCertificate.Presentation;
		Items.CounterpartySignaturesCertificates.CurrentData.Imprint                           = OptionsOfAddedCertificate.Imprint;
	EndIf;
	
EndProcedure

&AtClient
Procedure HandleChangeFileCertificate(Val NotSpecified, Val AdditionalParameters) Export
	
	EditText = "";
	If TypeOf(AdditionalParameters) = Type("Structure")
		AND AdditionalParameters.Property("EditText", EditText)
		AND IsBlankString(EditText) Then
		ParametersStructure = CertificateStructure();
		AddDateByTabularSection(
			Object.CounterpartySignaturesCertificates.IndexOf(Items.CounterpartySignaturesCertificates.CurrentData),
			Undefined,
			ParametersStructure);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChooseCertificateFile(Val NotSpecified, Val AdditionalParameters) Export
	
	Handler = New NotifyDescription("FileChoiceProcessing", ThisObject);
	BeginPutFile(Handler, , , True, UUID);
	
EndProcedure

#EndRegion

#Region FieldsFormEventsHandlers

&AtClient
Procedure SenderCompanyProcessingOfChoice(Item, ValueSelected, StandardProcessing)
	
	AdditParameters = New Structure("AttributeName, ValueSelected", "Company", ValueSelected);
	NotifyDescription = New NotifyDescription("HandleChangeSenderRecipient", ThisObject, AdditParameters);
	If ValueIsFilled(Object.CompanyID) Then
		If ValueSelected <> Object.Company Then
			QuestionText = NStr("en='The company was modified. Do you want to change the exchange ID of the company?';ru='Была изменена организация. Изменить идентификатор обмена организации?'");
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		EndIf;
	Else
		ExecuteNotifyProcessing(NOTifyDescription, DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

&AtClient
Procedure VerifySignatureCertificatesOnChange(Item)
	
	DetermineAvailabilitySignaturesCertificates();
	
EndProcedure

&AtClient
Procedure SenderCompanyOnChange(Item)
	
	FillDescription();
	ChangeCaptionDirectionDocuments();
	FillCompaniesChoiceList(Items.Counterparty.ChoiceList, Object.Company);
	
EndProcedure

&AtClient
Procedure PayeeChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AdditParameters = New Structure("AttributeName, ValueSelected", "Counterparty", ValueSelected);
	NotifyDescription = New NotifyDescription("HandleChangeSenderRecipient", ThisObject, AdditParameters);
	If ValueIsFilled(Object.CounterpartyID) Then
		If ValueSelected <> Object.Counterparty Then
			QuestionText = NStr("en='Recipient company has been changed. Do you want to change the recipient ID?';ru='Была изменена организация получатель. Изменить идентификатор получателя?'");
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		EndIf;
	Else
		ExecuteNotifyProcessing(NOTifyDescription, DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

&AtClient
Procedure PayeeOnChange(Item)
	
	FillDescription();
	ChangeCaptionDirectionDocuments();
	FillCompaniesChoiceList(Items.CompanySender.ChoiceList, Object.Counterparty);

EndProcedure

&AtClient
Procedure CompanyIDOnChange(Item)
	
	Object.CompanyID = TrimAll(Object.CompanyID);
	
EndProcedure

&AtClient
Procedure CounterpartyIDOnChange(Item)
	
	Object.CounterpartyID = TrimAll(Object.CounterpartyID);
	
EndProcedure

#EndRegion

#Region EventHandlersTableFieldsOutgoingDocuments

&AtClient
Procedure OutgoingDocumentsOnChange(Item)
	
	Item.CurrentData.UseDS = Item.CurrentData.ToForm;
	
	FillStagesTable();
	
EndProcedure

&AtClient
Procedure OutgoingDocumentsOnActivateRow(Item)
	
	FillStagesTable();
	
EndProcedure

&AtClient
Procedure OutgoingDocumentsUseExchangeOnChange(Item)
	
	ItemValue = Item.Parent.CurrentData.ToForm;
	If Not ItemValue Then
		
		Item.Parent.CurrentData.ExpectDeliveryTicket = ItemValue;
		Item.Parent.CurrentData.UseDS           = ItemValue;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventsHandlersTablesSignatureCertificatesFields

&AtClient
Procedure CounterpartySignaturesCertificatesCounterpartyCertificatePresentationOnChange(Item)
	
	AdditParameters = New Structure("EditText", Item.EditText);
	ContinuationHandler = New NotifyDescription("HandleChangeFileCertificate", ThisObject, AdditParameters);
	ValidateWriteAgreement(ContinuationHandler);
	
EndProcedure

&AtClient
Procedure CounterpartySignaturesCertificatesCounterpartyCertificatePresentationBeginChoice(Item, ChoiceData, StandardProcessing)
	
	ContinuationHandler = New NotifyDescription("ChooseCertificateFile", ThisObject);
	ValidateWriteAgreement(ContinuationHandler);
	
EndProcedure

&AtClient
Procedure CounterpartySignaturesCertificatesCounterpartyCertificatePresentationClearing(Item, StandardProcessing)
	
	ParametersStructure = CertificateStructure();
	AddDateByTabularSection(
		Object.CounterpartySignaturesCertificates.IndexOf(Items.CounterpartySignaturesCertificates.CurrentData),
		Undefined,
		ParametersStructure);
	
EndProcedure

&AtClient
Procedure CounterpartySignaturesCertificatesAfterDeleteRow(Item)
	
	RefreshDataDocument();
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("WindowOpeningMode") Then
		WindowOpeningMode = Parameters.WindowOpeningMode;
	EndIf;
	
	FillFileFormatsAvailableValues();
	FillEDTypesAvailableValues();
	
	ElementObject = FormAttributeToValue("Object");
	
	If Not ValueIsFilled(Object.Ref) Then // New
		If Parameters.Property("Typical") AND Parameters.Typical Then
			Object.DeleteIsTypical = True;
		EndIf;
		Object.IsIntercompany  = True;
		Object.AgreementStatus = Enums.EDAgreementsStatuses.NotAgreed;
		If Not ValueIsFilled(Parameters.CopyingValue) Then // Not copying
			Object.Counterparty = ElectronicDocumentsReUse.GetEmptyRef("Companies");
		Else
			// When copying, do not copy encryption settings and reference counterparty certificates
			Object.CompanyCertificateForDetails = Undefined;
			Object.VerifySignatureCertificates        = False;
			Object.CounterpartySignaturesCertificates.Clear();
		EndIf;
	Else
		DocumentObject = FormAttributeToValue("Object");
		Try
			CertificateBinaryData  = DocumentObject.CounterpartyCertificateForEncryption.Get();
			If CertificateBinaryData <> Undefined Then
				CryptoCertificate = New CryptoCertificate(CertificateBinaryData);
				CertificatePresentation = DigitalSignatureClientServer.SubjectPresentation(CryptoCertificate);
				FormCounterpartyCertificateForEncrypting = CertificatePresentation;
			EndIf;
			DetermineAvailabilitySignaturesCertificates();
			ReReadDataByCertificate(DocumentObject);
		Except
			MessageText = BriefErrorDescription(ErrorInfo())
				+ NStr("en=' (see details in Event log monitor).';ru=' (подробности см. в Журнале регистрации).'");
			ErrorText = DetailErrorDescription(ErrorInfo());
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
				NStr("en='the agreement form opening';ru='открытие формы соглашения'"), ErrorText, MessageText);
		EndTry;
	EndIf;
	
	IsUsedES = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseDigitalSignatures");
	If Not IsUsedES Then
		Items.OutgoingDocumentsUseDS.Visible = False;
	EndIf;
	
	Items.GroupHeaderRight.Visible                                 = Not Object.DeleteIsTypical;
	Items.ESCertificates.Visible                                   = Not Object.DeleteIsTypical AND IsUsedES;
	Items.FormED.Visible                                          = Not Object.DeleteIsTypical;
	Items.FormCommandBar.ChildItems.FormED.Visible = False;
	If Object.DeleteIsTypical Then
		For Each Item IN Items.GroupHeaderRight.ChildItems Do
			Item.HorizontalStretch = True;
		EndDo;
	EndIf;
	CurrentEDExchangeMethod = Object.EDExchangeMethod;
	RefreshFormTitle();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	DocumentObject = FormAttributeToValue("Object");
	ReReadDataByCertificate(DocumentObject);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	RowArray = Object.ExchangeFilesFormats.FindRows(New Structure("Use, FileFormat",
		True, PredefinedValue("Enum.EDExchangeFileFormats.XML")));
	If RowArray.Count() = 0 Then
		MessageText = NStr("en='Outgoing document format ""CommerceML(*.xml)"" is mandatory for use.';ru='Формат исходящего документа ""CommerceML(*.xml)"" обязателен к использованию.'");
		CommonUseClientServer.MessageToUser(
			MessageText, Object.Ref, "FilesFormatsExchangeFilesFormats", , Cancel);
	EndIf;
	
	If Not Object.DeleteIsTypical Then
		If Object.AgreementStatus = PredefinedValue("Enum.EDAgreementsStatuses.Acts") Then
			TextActualityError = "";
			CheckRelevanceDataAgreement(TextActualityError);
			If Not IsBlankString(TextActualityError) Then
				CommonUseClientServer.MessageToUser(TextActualityError, , , , Cancel);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ChangeCaptionDirectionDocuments();
	CompaniesArray = CompaniesList(PredefinedValue("Catalog.Companies.EmptyRef"));
	If CompaniesArray.Count() > 0 Then
		Items.CompanySender.ChoiceList.LoadValues(CompaniesArray);
		Items.Counterparty.ChoiceList.LoadValues(CompaniesArray);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DetermineAvailabilitySignaturesCertificates();
	
	If Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupOutgoingDocuments Then
		If  Not Items.OutgoingDocuments.CurrentRow=Undefined Then
			
			ParametersStructure = EDKindParametersStructure();
			ParametersStructure.ExchangeMethod          = Object.EDExchangeMethod;
			ParametersStructure.Direction           = Enums.EDDirections.Intercompany;
			ParametersStructure.UseSignature   = Object.OutgoingDocuments[Items.OutgoingDocuments.CurrentRow].UseDS;
			ParametersStructure.UseReceipt = Object.OutgoingDocuments[Items.OutgoingDocuments.CurrentRow].ExpectDeliveryTicket;
			
			If Not Object.OutgoingDocuments[Items.OutgoingDocuments.CurrentRow].ToForm Then
				ParametersStructure = Undefined;
			EndIf;
			
			SetValuesOfExchangeStepsBySettings(ParametersStructure);
			
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	ListStringForDeletion = New ValueList;
	For Each StringCertificate IN CurrentObject.CounterpartySignaturesCertificates Do
		If Not ValueIsFilled(StringCertificate.Imprint) Then
			ListStringForDeletion.Add(StringCertificate.LineNumber);
		EndIf;
	EndDo;
	
	ListStringForDeletion.SortByValue(SortDirection.Desc);
	
	For Each Record IN ListStringForDeletion Do
		CurrentObject.CounterpartySignaturesCertificates.Delete(Record.Value - 1);
	EndDo
	
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
