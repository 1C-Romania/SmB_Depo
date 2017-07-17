#Region FormEventsHandlers

&AtClient
Var Cryptography, WorkWithBinaryData, PagesCurrentPage, ProgressPagesCurrentPage;

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
		Items.Company.Visible = False;
	EndIf;
	
	InfobaseUserWithFullAccess = Users.InfobaseUserWithFullAccess();
	IsSubordinateDIBNode = CommonUse.IsSubordinateDIBNode();
	
	FillAttributesHeaders();
	
	OnChangingDocumentTypeOnServer();
	
	If ValueIsFilled(Parameters.CertificatRef) Then
		ImportStatement();
	Else
		SetAgreement();
		Object.RequestStatus = Enums.CertificateIssueRequestState.NotPrepared;
		If ValueIsFilled(Parameters.Company) Then
			Company = Parameters.Company;
			Items.Company.ReadOnly = True;
		EndIf;
	EndIf;
	
	FillApplicationsList();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// On change of content or settings of applications.
	If Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionApplications")
	 Or Upper(EventName) = Upper("Write_PathsToDigitalSignatureAndEncryptionFilesAtServersLinux") Then
		
		AttachIdleHandler("WhenApplicationContentOrSettings", 0.1, True);
	EndIf;
	
	If Left(EventName, StrLen("Record_")) <> "Record_" Then
		Return;
	EndIf;
	
	If Source = Company Then
		AttachIdleHandler("WaitHandlerCompanyDetailsOnChanging", 0.1, True);
	EndIf;
	
	If Source = Chiefexecutive
	 Or Source = ChiefAccountant
	 Or Source = Employee Then
		
		If Items.Pages.CurrentPage = Items.PageCertificateOwner Then
			AttachIdleHandler("WaitHandlerOwnerDetailsOnChanging", 0.1, True);
		EndIf;
	EndIf;
	
	If Source = DocumentsPartnerRef
	   AND Items.Pages.CurrentPage = Items.PageRequestSending Then
		
		AttachIdleHandler("WaitHandlerPartnerDetailsOnChanging", 0.1, True);
	EndIf;
	
	If Source = DocumentsHeadRef
	   AND Items.Pages.CurrentPage = Items.PageRequestSending Then
		
		AttachIdleHandler("WaitHandlerManagerAttributesOnChanging", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
#If WebClient Then
	AttachIdleHandler("UpdateCurrentPages", 0.1, True);
	
	PagesCurrentPage = Items.Pages.CurrentPage;
	ProgressPagesCurrentPage = Items.ProgressPages.CurrentPage;
	
	Items.Pages.CurrentPage = Items.PageAgreement;
	Items.ProgressPages.CurrentPage = Items.PageProgressAgreement;
#EndIf

EndProcedure

&AtClient
Procedure UpdateCurrentPages()
	
	Items.Pages.CurrentPage = PagesCurrentPage;
	Items.ProgressPages.CurrentPage = ProgressPagesCurrentPage;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Object.RequestStatus = PredefinedValue("Enum.CertificateIssueRequestState.Prepared")
	 Or Object.RequestStatus = PredefinedValue("Enum.CertificateIssueRequestState.NotPrepared")
	   AND Items.Pages.CurrentPage = Items.PagePreparationCertificateQuery Then
		
		WriteAndUnlockObject();
		AfterWrite();
		
	ElsIf ValueIsFilled(Object.Ref) Then
		UnlockObject(Object.Ref, UUID);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

&AtClient
Procedure DecorationCertifyingCenterNameClick(Item)
	
	GotoURL("http://v8.1c.ru/learn/");
	
EndProcedure

&AtClient
Procedure AgreementApprovalOnChange(Item)
	
	Items.FormNext.Enabled = AgreementApproval;
	
EndProcedure

// Company details.

&AtClient
Procedure CompanyOnChange(Item)
	
	ClearCompanyDetails();
	OnChangingCompanyOnServer();
	
EndProcedure

&AtClient
Procedure CompanyClearing(Item, StandardProcessing)
	
	ClearCompanyDetails();
	
EndProcedure

&AtClient
Procedure LegalAddressStartChoice(Item, ChoiceData, StandardProcessing)
	
	AddressPresentationSelectionStart(ThisObject, Item, ChoiceData, StandardProcessing,
		"LegalAddress", NStr("en='Counterparty legal address';ru='Юридический адрес контрагента'"));
	
EndProcedure

&AtClient
Procedure LegalAddressClearing(Item, StandardProcessing)
	
	AddressPresentationClearance(ThisObject, Item, StandardProcessing, "LegalAddress");
	
EndProcedure

&AtClient
Procedure LegalAddressChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AddressPresentationChoiceProcessing(ThisObject, Item, ValueSelected, StandardProcessing, "LegalAddress");
	
EndProcedure

&AtClient
Procedure ActualAddressStartChoice(Item, ChoiceData, StandardProcessing)
	
	AddressPresentationSelectionStart(ThisObject, Item, ChoiceData, StandardProcessing,
		"ActualAddress", NStr("en='Physical address of the counterparty';ru='Фактический адрес контрагента'"));
	
EndProcedure

&AtClient
Procedure ActualAddressClearing(Item, StandardProcessing)
	
	AddressPresentationClearance(ThisObject, Item, StandardProcessing, "ActualAddress");
	
EndProcedure

&AtClient
Procedure ActualAddressChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	 AddressPresentationChoiceProcessing(ThisObject, Item, ValueSelected, StandardProcessing, "ActualAddress");
	
EndProcedure

&AtClient
Procedure AddressWarningClick(Item)
	
	ShowMessageBox(, Item.ToolTip);
	
EndProcedure

&AtClient
Procedure PhoneStartChoice(Item, ChoiceData, StandardProcessing)
	
	PhonePresentationSelectionStart(ThisObject, Item, ChoiceData, StandardProcessing,
		"Phone", NStr("en='Company phone';ru='Телефон организации'"));
	
EndProcedure

&AtClient
Procedure PhoneClearing(Item, StandardProcessing)
	
	PresentationPhoneClearance(ThisObject, Item, StandardProcessing, "Phone");
	
EndProcedure

&AtClient
Procedure PhoneChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	 PhonePresentationSelectionProcessing(ThisObject, Item, ValueSelected, StandardProcessing, "Phone");
	
EndProcedure

// Employee details (official of the company).

&AtClient
Procedure OwnerKindOnChange(Item)
	
	ClearOwnerAttributes();
	OnChangingCertificateOwnerOnServer();
	
EndProcedure

&AtClient
Procedure EmployeeStartChoice(Item, ChoiceData, StandardProcessing)
	
	ValueSelectionStart(Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure EmployeeClearing(Item, StandardProcessing)
	
	If EmployeeType <> Undefined
	   AND EmployeeType.Count() = 1
	   AND Employee = Undefined Then
		
		TypeDescription = New TypeDescription(EmployeeType.UnloadValues());
		Employee = TypeDescription.AdjustValue(Undefined);
	EndIf;
	
	If OwnerKind = "Employee" Then
		ClearOwnerAttributes();
	EndIf;
	
EndProcedure

&AtClient
Procedure EmployeeSelectionDataProcessor(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	Employee = ValueSelected;
	
	OnChangingCertificateOwnerOnServer();
	
EndProcedure

&AtClient
Procedure InsuranceNumberRPFOnChange(Item)
	
	InsuranceNumberRPF = OnlyDigits(InsuranceNumberRPF);
	
EndProcedure

&AtClient
Procedure DocumentKindOnChange(Item)
	
	OnChangingDocumentTypeOnServer();
	
EndProcedure

&AtClient
Procedure DocumentKindClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure DocumentNumberOnChange(Item)
	
	DocumentNumber = OnlyDigits(DocumentNumber);
	
EndProcedure

// Key creation attributes.

&AtClient
Procedure ApplicationStartChoice(Item, ChoiceData, StandardProcessing)
	
	FillApplicationSelectionData(ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ApplicationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(ValueSelected) = Type("String") Then
		Presentation = SuppliedApplicationPresentation(ApplicationsList, ValueSelected);
		
		If Not InfobaseUserWithFullAccess Then
			ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Application %1 is not added to the list of used applications yet.
		|Contact your administrator.';ru='Программа %1 еще не добавлена в список используемых программ.
		|Обратитесь к администратору.'"),
					Presentation));
			
		ElsIf IsSubordinateDIBNode Then
			ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Application %1 is not added to the list of used applications yet.
		|Add to infobase main node.';ru='Программа %1 еще не добавлена в список используемых программ.
		|Выполните добавление в главном узле информационной базы.'"),
					Presentation));
		Else
			Buttons = New ValueList;
			Buttons.Add("Add",    NStr("en='Add';ru='Добавить'"));
			Buttons.Add("DoNotAdd", NStr("en='Do not add';ru='Не добавлять'"));
			ShowQueryBox(
				New NotifyDescription("ApplicationSelectionProcessingContinuation", ThisObject, ValueSelected),
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Application %1 is not added to the list of used applications yet.
		|Add?';ru='Программа %1 еще не добавлена в список используемых программ.
		|Добавить?'"),
					Presentation),
				Buttons,, "DoNotAdd");
		EndIf;
		
		Return;
	EndIf;
	
	Object.Application = ValueSelected;
	
	AfterSelectingApplication(True);
	
EndProcedure

&AtClient
Procedure ApplicationAutoPick(Item, Text, ChoiceData, DataReceivingParameters, Wait, StandardProcessing)
	
	FillApplicationSelectionData(ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ApplicationTextInputEnd(Item, Text, ChoiceData, DataReceivingParameters, StandardProcessing)
	
	FillApplicationSelectionData(ChoiceData, StandardProcessing);
	
EndProcedure


&AtClient
Procedure DecorationKeyGenerationNavigationRefProcessing(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	
	If URL = "DigitalSignatureKey" Then
		ShowMessageBox(,
			NStr("en='Digital signature key is a secret information
		|saved to a computer, USB drive, floppy disk or
		|other dara storage device and it is further used to create digital signatures.';ru='Ключ электронной подписи -
		|это секретная информация, которая сохраняется на компьютер, флешку,
		|дискету или другой носитель информации и используется в дальнейшем для создания электронных подписей.'"));
		
	ElsIf URL = "CertificateQuery" Then
		ShowMessageBox(,
			NStr("en='Certificate request is not the secret information. It is created based on the digital signature key, sent together with the certificate issue application and required to issue certificate.';ru='Запрос на сертификат - это не секретная информация, которая создается на основе ключа электронной подписи, отправляется вместе с заявлением на выпуск сертификата и требуется для выпуска сертификата.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure DecorationApplicationCommentNavigationRefProcessing(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	
	DigitalSignatureServiceClient.OpenInstructionForWorkWithApplications();
	
EndProcedure

// Attributes of statement sending.

&AtClient
Procedure DocumentsHeadOnChange(Item)
	
	DocumentsHeadRef = Undefined;
	Items.DocumentsHead.OpenButton = Undefined;
	
EndProcedure

&AtClient
Procedure DocumentsHeadStartChoice(Item, ChoiceData, StandardProcessing)
	
	ValueSelectionStart(Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure DocumentsHeadClearing(Item, StandardProcessing)
	
	DocumentsHeadRef = Undefined;
	Items.DocumentsHead.OpenButton = Undefined;
	ClearAttribute("DocumentsHeadPosition");
	ClearAttribute("DocumentsHeadBasis");
	
EndProcedure

&AtClient
Procedure DocumentsHeadOpen(Item, StandardProcessing)
	
	ValueOpening(Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure DocumentsHeadChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	ValueSelectionProcessing(Item, ValueSelected, StandardProcessing);
	
	OnChangingManagerOnServer();
	
EndProcedure

&AtClient
Procedure InstructionNavigationRefProcessing(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	
	If URL <> "DocumentSet" Then
		Return;
	EndIf;
	
	If ThisIsIndividualEntrepreneur Then
		WarningText =
			NStr("en='Set
		|of documents: 1. Application for certificate issue (prepared in the previous step).
		|2. Copy of the Tax Authority Registration Certificate (TIN).
		|3. Copy of sole proprietor registration certificate (OGRN).
		|4. Copy of the identification document of certificate owner.
		|5. Copy of Personal Insurance Policy Number of the certificate owner.';ru='Комплект
		|документов: 1. Заявление на выпуск сертификата (подготовленное на предыдущем шаге).
		|2. Копия свидетельства о постановке на учет в налоговом органе (ИНН).
		|3. Копия свидетельства о государственной регистрации индивидуального предпринимателя (ОГРН).
		|4. Копия документа, удостоверяющего личность владельца сертификата.
		|5. Копия страхового свидетельства обязательного пенсионного страхования (СНИЛС) владельца сертификата.'");
	Else
		WarningText =
			NStr("en=""Set
		|of documents: 1. Application for certificate issue (prepared in the previous step).
		|2. Copy* of the Tax Authority Registration Certificate (TIN).
		|3. Copy* of Certificate of incorporation (OGRN).
		|4. Copy* of the identification document of company representative indicated for certificate issue.
		|5. Copy* of the insurance policy of mandatory pension
		|   insurance (INILA) of a company representative specified for certificate issue.
		|6. Copy* of the document confirming the authority of
		|   the manager who signed the statement (minutes of founders meeting, decision of the owner, company charter) or relevant extract from the Unified State Register of Legal Entities certified by tax authority.
		|
		|* Copies of documents are certified with manager's signature and company seal."";ru='Комплект
		|документов: 1. Заявление на выпуск сертификата (подготовленное на предыдущем шаге).
		|2. Копия* свидетельства о постановке на учет в налоговом органе (ИНН).
		|3. Копия* свидетельства о государственной регистрации юридического лица (ОГРН).
		|4. Копия* документа, удостоверяющего личность представителя организации, указанного для выпуска сертификата.
		|5. Копия* страхового свидетельства обязательного
		|   пенсионного страхования (СНИЛС) представителя организации, указанного для выпуска сертификата.
		|6. Копия* документа, подтверждающего полномочия
		|   руководителя, подписавшего заявление (протокол собрания учредителей, решение собственника, устав) или актуальная выписка из ЕГРЮЛ, заверенная налоговым органом.
		|
		|* Копии документов заверяются подписью руководителя и печатью организации.'");
	EndIf;
	
	ShowMessageBox(, WarningText);
	
EndProcedure

&AtClient
Procedure DocumentsPartnerOnChange(Item)
	
	DocumentsPartnerRef = Undefined;
	Items.DocumentsPartner.OpenButton = Undefined;
	
EndProcedure

&AtClient
Procedure DocumentsPartnerStartChoice(Item, ChoiceData, StandardProcessing)
	
	ValueSelectionStart(Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure DocumentsPartnerClearing(Item, StandardProcessing)
	
	DocumentsPartnerRef = Undefined;
	Items.DocumentsPartner.OpenButton = Undefined;
	
	ClearPartnerAttributes();
	
EndProcedure

&AtClient
Procedure DocumentsPartnerOpening(Item, StandardProcessing)
	
	ValueOpening(Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure DocumentsPartnerChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	ValueSelectionProcessing(Item, ValueSelected, StandardProcessing);
	
	OnChangingPartnerOnServer();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Next(Command)
	
	If Items.Pages.CurrentPage = Items.PageAgreement Then
		GoToCompanyPage();
		
	ElsIf Items.Pages.CurrentPage = Items.PageCompany Then
		GoToPageCertificateOwner();
		
	ElsIf Items.Pages.CurrentPage = Items.PageCertificateOwner Then
		GoToPageCertificateQueryPreparation();
		
	ElsIf Items.Pages.CurrentPage = Items.PagePreparationCertificateQuery Then
		GoToPageStatementSending();
		
	ElsIf Items.Pages.CurrentPage = Items.PageRequestSending Then
		GoToPageStatementProcessingPending();
		
	ElsIf Items.Pages.CurrentPage = Items.PageRequestProcessingPending Then
		GoToPageCertificateSetup();
		
	ElsIf Items.Pages.CurrentPage = Items.PageCertificateSetup Then
		CloseAssistantAfterCertificateInstallation();
	EndIf;
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	If Items.Pages.CurrentPage = Items.PageCompany Then
		GoToPageAgreement();
		Items.Pages.CurrentPage = Items.PageAgreement;
		
	ElsIf Items.Pages.CurrentPage = Items.PageCertificateOwner Then
		GoToCompanyPage(True);
		
	ElsIf Items.Pages.CurrentPage = Items.PagePreparationCertificateQuery Then
		GoToPageCertificateOwner(True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportCertificateQuery(Command)
	
	DigitalSignatureServiceClient.SaveCertificateQuery(, RequestAddressForCertificate,
		FileDescriptionWithoutExtension());
	
EndProcedure

&AtClient
Procedure ExportRootCertificate(Command)
	
	DigitalSignatureServiceClient.SaveCertificate(, RootCertificateAddress,
		NStr("en='Root certificate of 1C RDC LLC';ru='Корневой сертификат ООО НПЦ 1С'"));
	
EndProcedure

&AtClient
Procedure PrintDocuments(Command)
	
	Document = PreparedDocument();
	
	If Document = Undefined Then
		Return;
	EndIf;
	
	PrintedFormIdentifier = "StatementToIssueCertificate";
	PrintedFormName = NStr("en='Application for certificate issue';ru='Заявление на выпуск сертификата'");
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.Print") Then
		Document.Show(PrintedFormName);
		DocumentsPrinted = True;
		Return;
	EndIf;
	
	PrintManagementModuleClient = CommonUseClient.CommonModule("PrintManagementClient");
	
	PrintFormsCollection = PrintManagementModuleClient.NewPrintedFormsCollection(PrintedFormIdentifier);
	PrintForm = PrintManagementModuleClient.PrintFormDescription(PrintFormsCollection, PrintedFormIdentifier);
	PrintForm.TemplateSynonym = PrintedFormName;
	PrintForm.SpreadsheetDocument = Document;
	PrintForm.FileNamePrintedForm = PrintedFormName;
	
	ObjectAreas = New ValueList;
	PrintManagementModuleClient.PrintingDocuments(PrintFormsCollection, ObjectAreas);
	
	DocumentsPrinted = True;
	
EndProcedure

&AtClient
Procedure ExportCertificate(Command)
	
	DigitalSignatureServiceClient.SaveCertificate(New NotifyDescription(
		"ExportCertificateEnd", ThisObject), CertificateAddress, FileDescriptionWithoutExtension());
	
EndProcedure

// Continue the procedure ExportCertificate.
&AtClient
Procedure ExportCertificateEnd(Result, Context) Export
	
	DigitalSignatureServiceClient.SaveCertificate(, RootCertificateAddress,
		NStr("en='Root certificate of 1C RDC LLC';ru='Корневой сертификат ООО НПЦ 1С'"));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure FillApplicationSelectionData(ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceData = New ValueList;
	
	For Each String IN ApplicationsList Do
		Value = ?(ValueIsFilled(String.Ref), String.Ref, String.ID);
		ChoiceData.Add(Value, String.Presentation);
	EndDo;
	
EndProcedure

&AtClient
Function FileDescriptionWithoutExtension()
	
	If ThisIsIndividualEntrepreneur Then
		FileDescriptionWithoutExtension = Surname + " " + Name + " " + Patronymic;
	Else
		FileDescriptionWithoutExtension = Surname + " " + Name + " " + Patronymic + ", " + AbbreviatedName
			+ ?(ValueIsFilled(Department), ", " + Department, "") + ", " + Position;
	EndIf;
	
	Return FileDescriptionWithoutExtension;
	
EndFunction

&AtServer
Procedure GoToPageAgreement()
	
	Items.FormBack.Visible = False;
	Items.FormPrintAgreement.Visible = True;
	Items.FormClose.Title = NStr("en='Cancel';ru='Отменить'");
	
	SetAgreement();
	
EndProcedure

&AtServer
Procedure GoToCompanyPage(Back = False)
	
	OnChangingCompanyOnServer(Back);
	
	Items.FormBack.Visible = True;
	Items.FormPrintAgreement.Visible = False;
	Items.FormClose.Title = NStr("en='Cancel';ru='Отменить'");
	Items.Pages.CurrentPage = Items.PageCompany;
	Items.ProgressPages.CurrentPage = Items.ProgressPageCompany;
	
EndProcedure

&AtClient
Procedure GoToPageCertificateOwner(Back = False)
	
	GoToPageCertificateOwnerOnServer(Back);
	
	If EmployeeType <> Undefined
	   AND EmployeeType.Count() = 1
	   AND Employee = Undefined Then
		
		TypeDescription = New TypeDescription(EmployeeType.UnloadValues());
		Employee = TypeDescription.AdjustValue(Undefined);
	EndIf;
	
EndProcedure

&AtServer
Procedure GoToPageCertificateOwnerOnServer(Back = False)
	
	If Not Back AND Not CompanyFilled() Then
		Return;
	EndIf;
	
	If Back Then
		WriteStatement();
	EndIf;
	
	OnChangingCertificateOwnerOnServer(Back);
	
	Items.FormClose.Title = NStr("en='Cancel';ru='Отменить'");
	Items.Pages.CurrentPage = Items.PageCertificateOwner;
	Items.ProgressPages.CurrentPage = Items.ProgressPageCertificateOwner;
	
EndProcedure

&AtClient
Procedure GoToPageCertificateQueryPreparation()
	
	FillApplication(New NotifyDescription(
		"GoToPageCertificateQueryPreparationEnd", ThisObject));
	
EndProcedure

// Continue the procedure GoToPageCertificateQueryPreparation.
&AtClient
Procedure GoToPageCertificateQueryPreparationEnd(Result, Context) Export
	
	If GoToPageCertificateQueryPreparationOnServer() Then
		AfterWrite();
	EndIf;
	
EndProcedure

&AtServer
Function GoToPageCertificateQueryPreparationOnServer()
	
	If Not OwnerFilled() Then
		Return False;
	EndIf;
	
	Object.AddedBy = Users.CurrentUser();
	If Not ValueIsFilled(Object.User) Then
		Object.User = Object.AddedBy;
	EndIf;
	
	WriteStatement(); // After recording, the statement will be open on this page.
	
	GoToPageCertificateQueryPreparationOnServerOnImport();
	
	Return True;
	
EndFunction

&AtServer
Procedure GoToPageCertificateQueryPreparationOnServerOnImport()
	
	Items.FormBack.Visible = True;
	Items.FormClose.Title = NStr("en='Close';ru='Закрыть'");
	
	FillAttributesStatements();
	
	If CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactInformationManagement = CommonUse.CommonModule("ContactInformationManagement");
		
		ActualAddressStructure =
			ModuleContactInformationManagement.PreviousStructureOfContactInformationXML(ActualAddressXML);
		
		LegalAddressStructure =
			ModuleContactInformationManagement.PreviousStructureOfContactInformationXML(LegalAddressXML);
	EndIf;
	
	Items.Pages.CurrentPage = Items.PagePreparationCertificateQuery;
	Items.ProgressPages.CurrentPage = Items.ProgressPagePreparationCertificateQuery;
	
EndProcedure

&AtClient
Procedure GoToPageStatementSending()
	
	If Not ValueIsFilled(Object.Application) Then
		CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='The ""Digital signature application"" field is not populated';ru='Поле ""Программа электронной подписи"" не заполнено'")), , "Application");
		
		Return;
	EndIf;
	
	DigitalSignatureServiceClient.CreateCryptoManager(New NotifyDescription(
			"GoToPageStatementSendingAfterCreatingCryptographyManager", ThisObject),
		"", Undefined);
	
EndProcedure

// Continue the procedure GoToPageStatementSending.
&AtClient
Procedure GoToPageStatementSendingAfterCreatingCryptographyManager(Result, Context) Export
	
	If TypeOf(Result) <> Type("CryptoManager") Then
		Object.Application = Undefined;
		DigitalSignatureServiceClient.ShowRequestToApplicationError(
			NStr("en='Create DS key';ru='Создание ключа электронной подписи'"),, Result, New Structure);
		Return;
	EndIf;
	
	ApplicationPresentation = SuppliedApplicationPresentation(ApplicationsList, Object.Application);
	
	CreateKeyAndCertificateQuery(New NotifyDescription(
		"GoToPageStatementSendingAfterCreatingKeyAndCertificateQuery", ThisObject));
	
EndProcedure

// Continue the procedure GoToPageStatementSending.
&AtClient
Procedure GoToPageStatementSendingAfterCreatingKeyAndCertificateQuery(Result, Context) Export
	
	If Result <> True Then
		Return;
	EndIf;
	
	GoToPageStatementSendingOnServer();
	
	AfterWrite();
	
EndProcedure

&AtServer
Procedure GoToPageStatementSendingOnServer()
	
	Object.RequestStatus = Enums.CertificateIssueRequestState.Prepared;
	Object.Company = Company;
	
	WriteStatement();
	
	GoToPageStatementSendingOnServerOnImporting(False);
	
EndProcedure

&AtServer
Procedure GoToPageStatementSendingOnServerOnImporting(Import = True)
	
	AuthenticationParametersOnSite = StandardSubsystemsServer.AuthenticationParametersOnSite();
	
	OnChangingManagerOnServer(Import);
	OnChangingPartnerOnServer(Import);
	
	Items.FormBack.Visible = False;
	Items.FormClose.Title = NStr("en='Close';ru='Закрыть'");
	Items.Pages.CurrentPage = Items.PageRequestSending;
	Items.ProgressPages.CurrentPage = Items.ProgressPageRequestSending;
	
	Items.InstructionIE.Visible       = ThisIsIndividualEntrepreneur;
	Items.InstructionIEPoint4.Visible = ThisIsIndividualEntrepreneur;
	Items.InstructionLE.Visible       = Not ThisIsIndividualEntrepreneur;
	Items.InstructionLEPoint5.Visible = Not ThisIsIndividualEntrepreneur;
	
	UpdatePartnerDetailsAvailability();
	
EndProcedure

&AtServer
Procedure UpdatePartnerDetailsAvailability()
	
	Items.GroupPartner.ReadOnly = ValueIsFilled(DocumentManagementIdentifier);
	
EndProcedure

&AtClient
Procedure GoToPageStatementProcessingPending()
	
	If Not ManagerFilled() Then
		Return;
	EndIf;
	
	If Not PartnerFilled() Then
		Return;
	EndIf;
	
	If DocumentsPrinted
	   AND ValueIsFilled(DocumentsPartnerTIN) Then
		
		GoToPageStatementProcessingPendingContinuation("Send", Undefined);
		Return;
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add("Send",   NStr("en='Send';ru='Отправлять'"));
	Buttons.Add("DoNotSend", NStr("en='Do not send';ru='Не отправлять'"));
	
	Text = "";
	If Not DocumentsPrinted Then
		Text =
			NStr("en='Documents are not yet printed.
		|Statement will not be accepted until printed documents are received.';ru='Документы еще не печатались.
		|Заявление не будет принято пока не будут получены печатные документы.'");
	EndIf;
	
	If DocumentsPartnerIsIE Then
		If Not ValueIsFilled(DocumentsPartnerTIN) Then
			Text = Text + Chars.LF  + Chars.LF +
				NStr("en='TIN of the service company is not specified.
		|Statement might be processed longer than usual.';ru='Не указан ИНН обслуживающей организации.
		|Заявление может обрабатываться дольше обычного.'");
		EndIf;
		
	ElsIf Not ValueIsFilled(DocumentsPartnerTIN) Then
		
		Text = Text + Chars.LF  + Chars.LF +
			NStr("en='TIN of service company is not specified.
		|Statement might be processed longer than usual.';ru='Не указан ИНН обслуживающей организации.
		|Заявление может обрабатываться дольше обычного.'");
	EndIf;
	
	ShowQueryBox(
		New NotifyDescription("GoToPageStatementProcessingPendingContinuation", ThisObject),
		TrimAll(Text),
		Buttons);
	
EndProcedure

&AtClient
Procedure GoToPageStatementProcessingPendingContinuation(Response, NoSpecified) Export
	
	If Response <> "Send" Then
		Return;
	EndIf;
	
	If TypeOf(AuthenticationParametersOnSite) <> Type("Structure") Then
		StandardSubsystemsClient.AuthorizeOnUserSupportSite(ThisObject,
			New NotifyDescription("GoToPageStatementProcessingPendingEnd", ThisObject));
	Else
		GoToPageStatementProcessingPendingEnd(AuthenticationParametersOnSite, Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToPageStatementProcessingPendingEnd(AuthenticationParameters, NoSpecified) Export
	
	If TypeOf(AuthenticationParameters) <> Type("Structure") Then
		AuthenticationParametersOnSite = Undefined;
		// User refused to input username and password.
		Return;
	EndIf;
	
	AuthenticationParametersOnSite = AuthenticationParameters;
	ErrorDescription = "";
	
	If GoToPageStatementProcessingPendingOnServer(ErrorDescription) Then
		AfterWrite();
	Else
		If AuthenticationParametersOnSite <> Undefined Then
			ContinuationProcessor = Undefined;
		Else
			ContinuationProcessor = New NotifyDescription(
				"GoToPagePendingStatementProcessingAfterWarning", ThisObject);
		EndIf;
		ShowMessageBox(ContinuationProcessor,
			SetHyperlink(ErrorDescription, "its.1c.en", ""));
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToPagePendingStatementProcessingAfterDoMessageBox(NoSpecified) Export
	
	GoToPageStatementProcessingPendingContinuation("Send", Undefined);
	
EndProcedure

&AtServer
Function GoToPageStatementProcessingPendingOnServer(ErrorDescription)
	
	If Not SendStatement(ErrorDescription) Then
		Return False;
	EndIf;
	
	Object.RequestStatus = Enums.CertificateIssueRequestState.Sent;
	
	UpdateDateConditions = CurrentSessionDate();
	RequestProcessingState = NStr("en='Application is accepted for processing.';ru='Заявление принято для обработки.'");
	UpdateUpdateDateStatesInTitle(ThisObject);
	
	WriteStatement();
	
	GoToPagePendingStatementProcessingOnServerOnImport();
	
	Return True;
	
EndFunction

&AtServer
Procedure GoToPagePendingStatementProcessingOnServerOnImport()
	
	Items.FormPrintDocuments.Visible = True;
	Items.FormNext.Visible = False;
	Items.FormClose.Title = NStr("en='Close';ru='Закрыть'");
	Items.Pages.CurrentPage = Items.PageRequestProcessingPending;
	Items.ProgressPages.CurrentPage = Items.ProgressPageWaitingForRequestProcessing;
	
	UpdateUpdateDateStatesInTitle(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateUpdateDateStatesInTitle(Form)
	
	Form.Items.RequestProcessingState.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Request processing state (on %1)';ru='Состояние обработки заявления (на %1)'"),
		Format(Form.UpdateDateConditions, "DLF=DT"));
	
EndProcedure

&AtClient
Procedure GoToPageCertificateSetup()
	
	Result = GoToPageCertificateSetupOnServer();
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result <> True Then
		AfterWrite(NStr("en='Application is rejected.';ru='Заявление отклонено.'"));
		Close();
		Return;
	EndIf;
	
	SetCertificate(New NotifyDescription("GoToPageCertificateSetupAfterInstallation", ThisObject));
	
EndProcedure

&AtClient
Procedure GoToPageCertificateSetupAfterInstallation(Installed, NoSpecified) Export
	
	UpdateCertificateInstallationDateInHeader(ThisObject);
	
	If Installed Then
		CloseAssistantAfterCertificateInstallationOnServer();
		AfterWrite(NStr("en='Application is executed.';ru='Заявление исполнено.'"));
		Close();
	Else
		AfterWrite();
		WriteStatement();
	EndIf;
	
EndProcedure

&AtServer
Function GoToPageCertificateSetupOnServer()
	
	Result = GetCertificate();
	If Result = Undefined Then
		UpdateUpdateDateStatesInTitle(ThisObject);
		WriteStatement();
		Return Undefined;
	EndIf;
	
	If Result = True Then
		Object.RequestStatus = Enums.CertificateIssueRequestState.ExecutedCertificateNotInstalled;
	Else
		Object.RequestStatus = Enums.CertificateIssueRequestState.Rejected;
	EndIf;
	
	WriteStatement();
	
	If Result = True Then
		GoToPageCertificateSetupOnServerOnImporting();
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure GoToPageCertificateSetupOnServerOnImporting()
	
	Items.FormPrintDocuments.Visible = False;
	Items.FormBack.Visible = False;
	Items.FormNext.Visible = False;
	Items.FormClose.Title = NStr("en='Close';ru='Закрыть'");
	Items.Pages.CurrentPage = Items.PageCertificateSetup;
	Items.ProgressPages.CurrentPage = Items.ProgressPageCertificateSetup;
	
	UpdateCertificateInstallationDateInHeader(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateCertificateInstallationDateInHeader(Form)
	
	If Not ValueIsFilled(Form.DateCertificateInstallation) Then
		Return;
	EndIf;
	
	Form.Items.ErrorCertificateSetup.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='An error occurred when installing certificate (to %1)';ru='Ошибка установки сертификата (на %1)'"),
		Format(Form.DateCertificateInstallation, "DLF=DT"));
	
EndProcedure

&AtClientAtServerNoContext
Function SetHyperlink(String, Substring, Hyperlink)
	
	Position = Find(String, Substring);
	If Position = 0 Then
		Return New FormattedString(String);
	EndIf;
	
	RowWithReference = New FormattedString(
		Substring,,,, Hyperlink);
	
	Return New FormattedString(Left(String, Position-1),
		RowWithReference, Mid(String, Position + StrLen(Substring)));
	
EndFunction


&AtClient
Procedure CloseAssistantAfterCertificateInstallation()
	
	SetCertificate(New NotifyDescription("CloseAssistantAfterCertificateInstallationEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure CloseAssistantAfterCertificateInstallationEnd(Installed, NoSpecified) Export
	
	UpdateCertificateInstallationDateInHeader(ThisObject);
	
	If Not Installed Then
		WriteStatement();
		Return;
	EndIf;
	
	CloseAssistantAfterCertificateInstallationOnServer();
	
	AfterWrite(NStr("en='Certificate is installed.';ru='Сертификат установлен.'"));
	Close();
	
EndProcedure

&AtServer
Procedure CloseAssistantAfterCertificateInstallationOnServer()
	
	Object.RequestStatus = Enums.CertificateIssueRequestState.Executed;
	
	WriteStatement();
	
	Items.FormNext.Visible = False;
	
EndProcedure

&AtClient
Procedure WaitHandlerCompanyDetailsOnChanging()
	
	If Items.Pages.CurrentPage = Items.PageCompany Then
		OnChangingCompanyOnServer();
		
	ElsIf Items.Pages.CurrentPage = Items.PageCertificateOwner Then
		OnChangingCertificateOwnerOnServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearCompanyDetails()
	
	ClearAttribute("AbbreviatedName");
	ClearAttribute("DescriptionFull");
	ClearAttribute("TIN");
	ClearAttribute("OGRN");
	ClearAttribute("BankAccount");
	ClearAttribute("BIN");
	ClearAttribute("CorrespondentAccount");
	
	ClearAttribute("LegalAddress");
	LegalAddressXML = "";
	
	ClearAttribute("ActualAddress");
	ActualAddressXML = "";
	
	ClearAttribute("Phone");
	PhoneXML = "";
	
	OwnerKind = "";
	Employee = Undefined;
	
EndProcedure

&AtServer
Procedure OnChangingCompanyOnServer(Import = False)
	
	If Not Import Then
		Attributes = New Structure;
		Attributes.Insert("ThisIsIndividualEntrepreneur", False);
		Attributes.Insert("AbbreviatedName");
		Attributes.Insert("DescriptionFull");
		Attributes.Insert("TIN");
		Attributes.Insert("OGRN");
		Attributes.Insert("BankAccount");
		Attributes.Insert("BIN");
		Attributes.Insert("CorrespondentAccount");
		Attributes.Insert("Phone");
		Attributes.Insert("LegalAddress");
		Attributes.Insert("ActualAddress");
		
		If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
			Attributes.Insert("Company",  Company);
		Else
			Attributes.Insert("Company",  Undefined);
		EndIf;
		
		DigitalSignatureOverridable.OnFillCompanyAttributesInApplicationForCertificate(Attributes);
		
		If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
			Company = Attributes.Company;
		EndIf;
		ThisIsIndividualEntrepreneur = Attributes.ThisIsIndividualEntrepreneur;
		
		SetAttribute(Attributes, "AbbreviatedName");
		SetAttribute(Attributes, "DescriptionFull");
		SetAttribute(Attributes, "TIN", True);
		SetAttribute(Attributes, "OGRN", True);
		SetAttribute(Attributes, "BankAccount", True);
		SetAttribute(Attributes, "BIN", True);
		SetAttribute(Attributes, "CorrespondentAccount", True);
		SetAttribute(Attributes, "Phone", , True, False);
		SetAttribute(Attributes, "LegalAddress", , True, True);
		SetAttribute(Attributes, "ActualAddress", , True, True);
		
	EndIf;
	
	If ThisIsIndividualEntrepreneur Then
		Items.OGRN.Title = NStr("en='OGRNIE';ru='ОГРНИП'");
	Else
		Items.OGRN.Title = NStr("en='OGRN';ru='ОГРН'");
	EndIf;
	
EndProcedure

&AtServer
Function CompanyFilled()
	
	Cancel = False;
	
	If Items.Company.Visible
	   AND Not ValidateAttribute(Cancel, "Company") Then
		
		Return False;
	EndIf;
	
	ValidateAttribute(Cancel, "AbbreviatedName");
	ValidateAttribute(Cancel, "DescriptionFull");
	
	If CommonUse.SubsystemExists("StandardSubsystems.WorkWithCounterparties") Then
		ModuleRegulatedDataClientServer =
			CommonUse.CommonModule("RegulatedDataClientServer");
	Else
		ModuleRegulatedDataClientServer = Undefined;
	EndIf;
	
	If ValidateAttribute(Cancel, "TIN") Then
		MessageText = "";
		If ModuleRegulatedDataClientServer <> Undefined Then
			ModuleRegulatedDataClientServer.TINMeetsTheRequirements(TIN,
				Not ThisIsIndividualEntrepreneur, MessageText);
		EndIf;
		If ValueIsFilled(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText, , "TIN", , Cancel);
		EndIf;
	EndIf;
	
	If ValidateAttribute(Cancel, "OGRN") Then
		MessageText = "";
		If ModuleRegulatedDataClientServer <> Undefined Then
			ModuleRegulatedDataClientServer.MSRNMeetsTheRequirements(OGRN,
				Not ThisIsIndividualEntrepreneur, MessageText);
		EndIf;
		If ValueIsFilled(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText, , "OGRN", , Cancel);
		EndIf;
	EndIf;
	
	If ValueIsFilled(BankAccount) Then
		MessageText = "";
		BankAccountMeetsRequirements(BankAccount, MessageText);
		If ValueIsFilled(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText, , "BankAccount", , Cancel);
		EndIf;
	EndIf;
	
	If ValueIsFilled(BIN) Then
		MessageText = "";
		BICMeetsRequirements(BIN, MessageText);
		If ValueIsFilled(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText, , "BIN", , Cancel);
		EndIf;
	EndIf;
	
	If ValueIsFilled(CorrespondentAccount) Then
		MessageText = "";
		CorrespondentBankAccountMeetsRequirements(CorrespondentAccount, MessageText);
		If ValueIsFilled(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText, , "CorrespondentAccount", , Cancel);
		EndIf;
	EndIf;
	
	If ValidateAttribute(Cancel, "LegalAddress") Then
		MessageText = "";
		AddressMeetsRequirements(LegalAddressXML, MessageText);
		If ValueIsFilled(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText, , "LegalAddress", , Cancel);
		EndIf;
	EndIf;
	
	If ValidateAttribute(Cancel, "ActualAddress") Then
		MessageText = "";
		AddressMeetsRequirements(ActualAddressXML, MessageText);
		If ValueIsFilled(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText, , "ActualAddress", , Cancel);
		EndIf;
	EndIf;
	
	If ValidateAttribute(Cancel, "Phone") Then
		MessageText = "";
		PhoneMeetsRequirements(PhoneXML, MessageText);
		If ValueIsFilled(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText, , "Phone", , Cancel);
		EndIf;
	EndIf;
	
	Return Not Cancel;
	
EndFunction

&AtServer
Procedure ValidateAddress(AttributeName)
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Return;
	EndIf;
	
	ModuleContactInformationManagement = CommonUse.CommonModule("ContactInformationManagement");
	
	Message = "";
	Try
		DetailedResult = ModuleContactInformationManagement.ValidateAddress(ThisObject[AttributeName + "XML"]);
		
		If DetailedResult.Result <> "Correct" Then
			For Each ItemOfList IN DetailedResult.ErrorList Do
				Message = Message + Chars.LF + ItemOfList.Presentation;
			EndDo;
			Message = TrimAll(Message);
			If Not ValueIsFilled(Message) Then
				Message = NStr("en='Address is not filled in';ru='Адрес не заполнен'");
			EndIf;
		EndIf;
	Except
		ErrorInfo = ErrorInfo();
		Message = DetailErrorDescription(ErrorInfo);
	EndTry;
	
	If ValueIsFilled(Message) Then
		Items[AttributeName + "Warning"].ToolTip = Message;
		Items[AttributeName + "Warning"].Visible = True;
	Else
		Items[AttributeName + "Warning"].Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Function BankAccountMeetsRequirements(BankAccount, MessageText)
	
	Value = TrimAll(BankAccount);
	
	If Not StringFunctionsClientServer.OnlyNumbersInString(Value) Then
		MessageText = NStr("en='Account number can contain only digits.';ru='Расчетный счет должен состоять только из цифр.'");
		Return False;
	EndIf;
	
	If StrLen(Value) <> 20 Then
		MessageText = NStr("en='Account number consists of 20 digits.';ru='Расчетный счет должен состоять из 20 цифр.'");
		Return False;
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.WorkWithCounterparties") Then
		ModuleRegulatedDataClientServer =
			CommonUse.CommonModule("RegulatedDataClientServer");
		
		If Not ModuleRegulatedDataClientServer.AccountKeyDigitMeetsRequirements(Value, BIN) Then
			MessageText = NStr("en='Check digit of account does not match the calculated value with branch ID taken into account';ru='Контрольное число счета не совпадает с рассчитанным с учетом БИК'");
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Function BICMeetsRequirements(BIN, MessageText)
	
	Value = TrimAll(BIN);
	
	If Not StringFunctionsClientServer.OnlyNumbersInString(Value) Then
		MessageText = NStr("en='Branch ID must contain only digits.';ru='БИК должен состоять только из цифр.'");
		Return False;
	EndIf;
	
	If StrLen(Value) <> 9 Then
		MessageText = NStr("en='Branch ID must consist of 9 digits.';ru='БИК должен состоять из 9 цифр.'");
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Function CorrespondentBankAccountMeetsRequirements(CorrespondentAccount, MessageText)
	
	Value = TrimAll(CorrespondentAccount);

	If Not StringFunctionsClientServer.OnlyNumbersInString(Value) Then
		MessageText = NStr("en='Correspondent account should contain only digits.';ru='Корреспондентский счет должен состоять только из цифр.'");
		Return False;
	EndIf;

	If StrLen(Value) <> 20 Then
		MessageText = NStr("en='Correspondent account should contain  20 digits.';ru='Корреспондентский счет должен состоять из 20 цифр.'");
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Function AddressMeetsRequirements(Val AddressMXL, MessageText)
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Return False;
	EndIf;
	
	ModuleContactInformationManagement = CommonUse.CommonModule("ContactInformationManagement");
	
	MessageText = "";
	AddressStructure = ModuleContactInformationManagement.PreviousStructureOfContactInformationXML(AddressMXL);
	
	// Check if the address is located in Russia.
	If Not AddressStructure.Property("StateCode") Then
		MessageText = MessageText + NStr("en='This is not Russian address';ru='Это не российский адрес'");
		Return False;
	EndIf;
	
	// Check if a state was specified.
	If Not AddressStructure.Property("Region") Or Not ValueIsFilled(AddressStructure.Region) Then
		MessageText = MessageText + NStr("en='Region is not specified';ru='Не указан регион'");
		Return False;
	EndIf;
	
	// Check if the state was specified correctly - state code is defined.
	If Not ValueIsFilled(AddressStructure.StateCode) Then
		MessageText = MessageText + NStr("en='Incorrect region (region code is not defined)';ru='Некорректный регион (код региона не определен)'");
		Return False; 
	EndIf;
	
	// Settlement entirely.
	SettlementEntirely = SettlementEntirely(AddressStructure);
	If Not ValueIsFilled(SettlementEntirely) Then
		MessageText = MessageText + NStr("en='Specify the settlement';ru='Не указан населенный пункт'");
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtClientAtServerNoContext
Function SettlementEntirely(AddressStructure)
	
	// Region RegionShort, City CityShort, Settlement SettlementShort.
	Total = "";
	
	If AddressStructure.Property("Region")
	   AND AddressStructure.Property("StateCode")
	   AND (    AddressStructure.StateCode = "77"
	      Or AddressStructure.StateCode = "78"
	      Or AddressStructure.StateCode = "92"
	      Or AddressStructure.StateCode = "99") Then
		
		Total = TrimAll(AddressStructure.Region);
	EndIf;
	
	If AddressStructure.Property("District")
	   AND ValueIsFilled(AddressStructure.District) Then
		
		Total = Total + ?(ValueIsFilled(Total), ", ", "");
		Total = Total + TrimAll(AddressStructure.District);
	EndIf;
	
	If AddressStructure.Property("City")
	   AND ValueIsFilled(AddressStructure.City) Then
		
		Total = Total + ?(ValueIsFilled(Total), ", ", "");
		Total = Total + TrimAll(AddressStructure.City);
	EndIf;
	
	If AddressStructure.Property("Settlement")
	   AND ValueIsFilled(AddressStructure.Settlement) Then
		
		Total = Total + ?(ValueIsFilled(Total), ", ", "");
		Total = Total + TrimAll(AddressStructure.Settlement);
	EndIf;
	
	Return Total;
	
EndFunction

&AtServer
Function PhoneMeetsRequirements(Val PhoneXML, MessageText)
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Return False;
	EndIf;
	
	ModuleContactInformationManagement = CommonUse.CommonModule("ContactInformationManagement");
	
	MessageText = "";
	PhoneStructure = ModuleContactInformationManagement.PreviousStructureOfContactInformationXML(PhoneXML);
	
	// Check if a phone number has Russian format.
	If StrReplace(PhoneStructure.CountryCode, "+", "") <> "7" Then
		MessageText = MessageText + NStr("en='Country code is not Russian (should be ""7"")';ru='Код страны не российский (должен быть ""7"")'");
		Return False;
	EndIf;
	
	PhoneNumberWithoutCountryCode = PhoneStructure.CityCode + PhoneStructure.PhoneNumber;
	
	If Not ValueIsFilled(PhoneNumberWithoutCountryCode) Then
		MessageText = MessageText + NStr("en='Phone number is not entered';ru='Не заполнен номер телефона'");
		Return False;
	EndIf;
	
	If StrLen(OnlyDigits(PhoneNumberWithoutCountryCode)) <> 10 Then
		MessageText = MessageText + NStr("en='Phone number with the city code should contain 10 digits';ru='Номер телефона с кодом города должен состоять из 10-и цифр'");
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtClient
Procedure WaitHandlerOwnerDetailsOnChanging()
	
	OnChangingCertificateOwnerOnServer();
	
EndProcedure

&AtClient
Procedure ClearOwnerAttributes()
	
	ClearAttribute("Surname");
	ClearAttribute("Name");
	ClearAttribute("Patronymic");
	ClearAttribute("InsuranceNumberRPF");
	ClearAttribute("Position");
	ClearAttribute("Department");
	
	If Items.DocumentKind1.ReadOnly Then
		DocumentKind1 = 21;
	EndIf;
	
	ClearAttribute("DocumentNumber");
	ClearAttribute("DocumentWhoIssued");
	ClearAttribute("DocumentIssueDate");
	ClearAttribute("Email");
	
EndProcedure

&AtServer
Procedure OnChangingCertificateOwnerOnServer(Import = False)
	
	If Not ValueIsFilled(OwnerKind) Then
		OwnerKind = "Chiefexecutive";
	EndIf;
	
	Attributes = New Structure;
	Attributes.Insert("OwnerKind", OwnerKind);
	Attributes.Insert("Chiefexecutive");
	Attributes.Insert("ChiefAccountant");
	Attributes.Insert("Employee", Employee);
	Attributes.Insert("User");
	Attributes.Insert("Surname");
	Attributes.Insert("Name");
	Attributes.Insert("Patronymic");
	Attributes.Insert("InsuranceNumberRPF");
	Attributes.Insert("Position");
	Attributes.Insert("Department");
	Attributes.Insert("DocumentKind1");
	Attributes.Insert("DocumentNumber");
	Attributes.Insert("DocumentWhoIssued");
	Attributes.Insert("DocumentIssueDate");
	Attributes.Insert("Email");
	
	If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
		Attributes.Insert("Company", Company);
	Else
		Attributes.Insert("Company", Undefined);
	EndIf;
	
	If EmployeeType <> Undefined Then
		Attributes.Insert("Employee", Employee);
	Else
		Attributes.Insert("Employee", Undefined);
	EndIf;
	
	Attributes.Insert("OwnerType");
	
	DigitalSignatureOverridable.OnFillAttributesInOwnerCertificateApplication(Attributes);
	
	FillValueTypes(EmployeeType, Items.Employee, Attributes.OwnerType);
	
	If EmployeeType = Undefined Then
		EmployeeType = Undefined;
		Items.SelectionCertificateOwner.Visible = False;
	Else
		List = Items.OwnerKind.ChoiceList;
		List.Clear();
		Items.Chiefexecutive.Visible = False;
		Items.ChiefAccountant.Visible = False;
		
		If ThisIsIndividualEntrepreneur Then
			OwnerKind = "Employee";
		Else
			If Attributes.Chiefexecutive <> Undefined Then
				List.Add("Chiefexecutive", NStr("en='Chiefexecutive';ru='Директор'"));
				Items.Chiefexecutive.Visible = True;
				
			ElsIf OwnerKind = "Chiefexecutive" Then
				OwnerKind = "ChiefAccountant";
			EndIf;
			
			If Attributes.ChiefAccountant <> Undefined Then
				List.Add("ChiefAccountant", NStr("en='Chief accountant';ru='Главный бухгалтер'"));
				Items.ChiefAccountant.Visible = True;
				
			ElsIf OwnerKind = "ChiefAccountant" Then
				OwnerKind = "Employee";
			EndIf;
		EndIf;
		
		If List.Count() = 0 Then
			Items.OwnerKind.Visible = False;
			Items.Employee.TitleLocation = FormItemTitleLocation.Left;
			If ThisIsIndividualEntrepreneur Then
				Items.Employee.Title = NStr("en='Individual entrepreneur';ru='Индивидуальный предприниматель'");
			Else
				Items.Employee.Title = NStr("en='Employee';ru='Сотрудник'");
			EndIf;
		Else
			List.Add("Employee", NStr("en='Employee';ru='Сотрудник'"));
			Items.OwnerKind.Visible = True;
			Items.Employee.TitleLocation = FormItemTitleLocation.None;
		EndIf;
		
		Items.Employee.AutoMarkIncomplete = OwnerKind = "Employee";
	
		Chiefexecutive         = Attributes.Chiefexecutive;
		ChiefAccountant = Attributes.ChiefAccountant;
		Employee        = ?(Import, Employee, Attributes.Employee);
	EndIf;
	
	If ThisIsIndividualEntrepreneur Then
		Items.Position.Visible = False;
		Items.Department.Visible = False;
		Items.Employee.ReadOnly = True;
	Else
		Items.Position.Visible = True;
		Items.Department.Visible = True;
		Items.Employee.ReadOnly = False;
	EndIf;
	
	If Import Then
		OnChangingDocumentTypeOnServer();
		Return;
	EndIf;
	
	Object.User = Attributes.User;
	
	SetAttribute(Attributes, "Surname");
	SetAttribute(Attributes, "Name");
	SetAttribute(Attributes, "Patronymic");
	SetAttribute(Attributes, "InsuranceNumberRPF", True);
	
	If ThisIsIndividualEntrepreneur Then
		Position = "";
		Department = "";
	Else
		SetAttribute(Attributes, "Position");
		SetAttribute(Attributes, "Department");
	EndIf;

	SetAttribute(Attributes, "DocumentKind1", True);
	SetAttribute(Attributes, "DocumentNumber", True);
	SetAttribute(Attributes, "DocumentWhoIssued");
	SetAttribute(Attributes, "DocumentIssueDate", , True);
	
	SetAttribute(Attributes, "Email", , , False);
	
	OnChangingDocumentTypeOnServer();
	
EndProcedure

&AtServer
Procedure OnChangingDocumentTypeOnServer()
	
	If DocumentKind1 = "" Then
		DocumentKind1 = "21";
	EndIf;
	
	If DocumentKind1 = "21" Then
		Items.DocumentNumber.Title = NStr("en='Series and number';ru='Серия и номер'");
		Items.DocumentNumber.Mask = "99 99 999999";
	Else
		Items.DocumentNumber.Title = NStr("en='Number';ru='Number'");
		Items.DocumentNumber.Mask = "";
	EndIf;
	
	If DocumentKind1 = 91 Then
		DocumentKind1 = "";
	EndIf;
	
EndProcedure

&AtServer
Function OwnerFilled()
	
	Cancel = False;
	
	If Items.SelectionCertificateOwner.Visible
	   AND Not ValidateAttribute(Cancel, OwnerKind) Then
		
		Return False;
	EndIf;
		
	ValidateAttribute(Cancel, "Surname");
	ValidateAttribute(Cancel, "Name");
	ValidateAttribute(Cancel, "Patronymic");
	
	If ValidateAttribute(Cancel, "InsuranceNumberRPF") Then
		MessageText = "";
		If CommonUse.SubsystemExists("StandardSubsystems.WorkWithCounterparties") Then
			ModuleRegulatedDataClientServer =
				CommonUse.CommonModule("RegulatedDataClientServer");
			
			ModuleRegulatedDataClientServer.PFRInsuaranceNumberMeetsTheRequirements(
				InsuranceNumberRPF, MessageText);
		EndIf;
		If ValueIsFilled(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText, , "InsuranceNumberRPF", , Cancel);
		EndIf;
	EndIf;
	
	If Not ThisIsIndividualEntrepreneur Then
		ValidateAttribute(Cancel, "Position");
	EndIf;
	
	ValidateAttribute(Cancel, "DocumentKind1");
	
	If DocumentKind1 = "21"
	   AND ValidateAttribute(Cancel, "DocumentNumber") Then
		
		MessageText = "";
		RFPassportNumberMeetsRequirements(DocumentNumber, MessageText);
		If ValueIsFilled(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText, , "DocumentNumber", , Cancel);
		EndIf;
	EndIf;
	
	ValidateAttribute(Cancel, "DocumentWhoIssued");
	ValidateAttribute(Cancel, "DocumentIssueDate");
	
	If ValueIsFilled(Email) Then
		MessageText = "";
		Try
			CommonUseClientServer.ParseStringWithPostalAddresses(Email);
		Except
			ErrorInfo = ErrorInfo();
			MessageText = BriefErrorDescription(ErrorInfo);
		EndTry;
		If ValueIsFilled(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText, , "Email", , Cancel);
		EndIf;
	EndIf;
	
	Return Not Cancel;
	
EndFunction

&AtServer
Function RFPassportNumberMeetsRequirements(Val RFPassportNumber, MessageText)
	
	MessageText = "";
	
	Result = True;
	
	RowOfDigits = StrReplace(RFPassportNumber, ",", "");
	RowOfDigits = StrReplace(RowOfDigits, " ", "");
	
	If IsBlankString(RowOfDigits) Then
		MessageText = MessageText + NStr("en='Passport number is not specified';ru='Номер паспорта не заполнен'");
		Return False;
	EndIf;
	
	If StrLen(RowOfDigits) < 10 Then
		MessageText  =  MessageText + NStr("en='Incorrect passport number';ru='Номер паспорта задан неполностью'");
		Return False;
	EndIf;
	
	If Not StringFunctionsClientServer.OnlyNumbersInString(RowOfDigits) Then
		Result = False;
		MessageText = MessageText + NStr("en='Passport number must contain only digits.';ru='Номер паспорта должен состоять только из цифр.'");
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure OnChangingManagerOnServer(Import = False)
	
	Attributes = New Structure;
	Attributes.Insert("Presentation");
	Attributes.Insert("Position");
	Attributes.Insert("Basis");
	
	If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
		Attributes.Insert("Company", Company);
	Else
		Attributes.Insert("Company", Undefined);
	EndIf;
	
	If DocumentsHeadType <> Undefined Then
		Attributes.Insert("Head", DocumentsHeadRef);
	Else
		Attributes.Insert("Head", Undefined);
	EndIf;
	Attributes.Insert("DirectorType");
	
	DigitalSignatureOverridable.OnFillManagerAttributesInApplicationForCertificate(Attributes);
	
	FillValueTypes(DocumentsHeadType, Items.DocumentsHead, Attributes.DirectorType);
	Items.DocumentsHead.ChoiceButton = DocumentsHeadType <> Undefined;
	
	If Import Then
		Items.DocumentsHead.OpenButton = ValueIsFilled(DocumentsHeadRef);
		Return;
	EndIf;
	
	DocumentsHeadRef = ?(DocumentsHeadType <> Undefined, Attributes.Head, Undefined);
	Items.DocumentsHead.OpenButton = ValueIsFilled(DocumentsHeadRef);
	DocumentsHead = ?(Attributes.Presentation <> Undefined, Attributes.Presentation, Attributes.Head);
	
	DocumentsHeadPosition = Attributes.Position;
	DocumentsHeadBasis = Attributes.Basis;
	
EndProcedure

&AtClient
Procedure WaitHandlerManagerAttributesOnChanging()
	
	OnChangingManagerOnServer();
	
EndProcedure

&AtServer
Function ManagerFilled()
	
	If ThisIsIndividualEntrepreneur Then
		Return True;
	EndIf;
	
	Cancel = False;
	
	ValidateAttribute(Cancel, "DocumentsHead");
	ValidateAttribute(Cancel, "DocumentsHeadPosition");
	ValidateAttribute(Cancel, "DocumentsHeadBasis");
	
	Return Not Cancel;
	
EndFunction


&AtServer
Procedure OnChangingPartnerOnServer(Import = False)
	
	Attributes = New Structure;
	Attributes.Insert("Presentation");
	Attributes.Insert("ThisIsIndividualEntrepreneur", False);
	Attributes.Insert("TIN");
	
	If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
		Attributes.Insert("Company", Company);
	Else
		Attributes.Insert("Company", Undefined);
	EndIf;
	
	If DocumentsPartnerType <> Undefined Then
		Attributes.Insert("Partner", DocumentsPartnerRef);
	Else
		Attributes.Insert("Partner", Undefined);
	EndIf;
	Attributes.Insert("PartnerType");
	
	DigitalSignatureOverridable.OnFillPartnerDetailsInApplicationForCertificate(Attributes);
	
	FillValueTypes(DocumentsPartnerType, Items.DocumentsPartner, Attributes.PartnerType);
	Items.DocumentsPartner.ChoiceButton = DocumentsPartnerType <> Undefined;
	
	If Import Then
		Items.DocumentsPartner.OpenButton = ValueIsFilled(DocumentsPartnerRef);
		Return;
	EndIf;
	
	DocumentsPartnerRef = ?(DocumentsPartnerType <> Undefined, Attributes.Partner, Undefined);
	Items.DocumentsPartner.OpenButton = ValueIsFilled(DocumentsPartnerRef);
	
	DocumentsPartner = ?(Attributes.Presentation <> Undefined, Attributes.Presentation, Attributes.Partner);
	
	DocumentsPartnerIsIE = Attributes.ThisIsIndividualEntrepreneur;
	
	FormAttributes = New Structure;
	FormAttributes.Insert("DocumentsPartnerTIN", Attributes.TIN);
	
	SetAttribute(FormAttributes, "DocumentsPartnerTIN", True);
	
EndProcedure

&AtClient
Procedure WaitHandlerPartnerDetailsOnChanging()
	
	OnChangingPartnerOnServer();
	
EndProcedure

&AtClient
Procedure ClearPartnerAttributes()
	
	ClearAttribute("DocumentsPartnerTIN");
	
EndProcedure

&AtServer
Function PartnerFilled()
	
	Cancel = False;
	
	If CommonUse.SubsystemExists("StandardSubsystems.WorkWithCounterparties") Then
		ModuleRegulatedDataClientServer =
			CommonUse.CommonModule("RegulatedDataClientServer");
	Else
		ModuleRegulatedDataClientServer = Undefined;
	EndIf;
	
	If ValueIsFilled(DocumentsPartnerTIN) Then
		MessageText = "";
		If ModuleRegulatedDataClientServer <> Undefined Then
			ModuleRegulatedDataClientServer.TINMeetsTheRequirements(DocumentsPartnerTIN,
				Not DocumentsPartnerIsIE, MessageText);
		EndIf;
		If ValueIsFilled(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText, , "DocumentsPartnerTIN", , Cancel);
		EndIf;
	EndIf;
	
	Return Not Cancel;
	
EndFunction


&AtClient
Procedure ValueSelectionStart(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(ThisObject[Item.Name]) = Type("String") Then
		AttributeName = Item.Name;
		AttributeNameValues = Item.Name + "Ref";
	Else
		AttributeName = Item.Name;
		AttributeNameValues = Item.Name;
	EndIf;
	
	Context = New Structure;
	Context.Insert("Item", Item);
	Context.Insert("AttributeName", AttributeName);
	Context.Insert("AttributeNameValues", AttributeNameValues);
	
	If TypeOf(ThisObject[AttributeName + "Type"]) <> Type("ValueList") Then
		Return;
	ElsIf ThisObject[AttributeName + "Type"].Count() = 1 Then
		ValueSelectionStartAfterTypeSelection(ThisObject[AttributeName + "Type"][0], Context);
	Else
		TypeChoiceList = New ValueList;
		TypeChoiceList.LoadValues(ThisObject[AttributeName + "Type"].UnloadValues());
		TypeChoiceList.ShowChooseItem(
			New NotifyDescription("ValueSelectionStartAfterTypeSelection", ThisObject, Context),
			NStr("en='Select data type';ru='Выбор типа данных'"),
			ThisObject[AttributeName + "Type"].FindByValue(TypeOf(ThisObject[AttributeNameValues])));
	EndIf;
	
EndProcedure

&AtClient
Procedure ValueSelectionStartAfterTypeSelection(ItemOfList, Context) Export
	
	If ItemOfList = Undefined Then
		Return;
	EndIf;
	
	Item              = Context.Item;
	AttributeName         = Context.AttributeName;
	AttributeNameValues = Context.AttributeNameValues;
	
	TypeArray = New Array;
	TypeArray.Add(ItemOfList.Value);
	TypeDescription = New TypeDescription(TypeArray);
	
	InitialValue = TypeDescription.AdjustValue(ThisObject[AttributeNameValues]);
	
	If AttributeName = AttributeNameValues Then
		ThisObject[AttributeNameValues] = InitialValue;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", InitialValue);
	FormParameters.Insert("CloseOnChoice", True);
	FormParameters.Insert("Multiselect", False);
	
	ChoiceFormName = ThisObject[Item.Name + "Type"].FindByValue(TypeOf(InitialValue)).Presentation
		+ ".ChoiceForm";
	
	OpenForm(ChoiceFormName, FormParameters, Item);
	
EndProcedure

&AtClient
Procedure ValueOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	Value = ThisObject[Item.Name + "Ref"];
	
	If ValueIsFilled(Value) Then
		ShowValue(, Value);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValueSelectionProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	ThisObject[Item.Name + "Ref"] = ValueSelected;
	
EndProcedure

&AtServer
Procedure FillValueTypes(AttributeType, Item, TypeDescription);
	
	If TypeOf(TypeDescription) <> Type("TypeDescription") Then
		AttributeType = Undefined;
	Else
		TypesComposition = New ValueList;
		For Each Type IN TypeDescription.Types() Do
			If CommonUse.IsReference(Type) Then
				TypesComposition.Add(Type, String(Type));
			EndIf;
		EndDo;
		TypesComposition.SortByPresentation();
		For Each ItemOfList IN TypesComposition Do
			ItemOfList.Presentation = Metadata.FindByType(ItemOfList.Value).FullName();
		EndDo;
		
		If TypesComposition.Count() = 0 Then
			AttributeType = Undefined;
		Else
			AttributeType = TypesComposition;
			Item.ChooseType = AttributeType.Count() > 1;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearAttribute(AttributeName)
	
	ThisObject[AttributeName] = Undefined;
	
EndProcedure

&AtServer
Procedure SetAttribute(Attributes, AttributeName, OnlyDigits = False, ChoiceButton = False, IsAddress = Undefined)
	
	If Attributes[AttributeName] = Undefined Then
		ThisObject[AttributeName] = Undefined;
		If IsAddress <> Undefined Then
			ThisObject[AttributeName + "XML"] = "";
			If IsAddress = True Then
				ValidateAddress(AttributeName);
			EndIf;
		EndIf;
	Else
		If IsAddress <> Undefined Then
			ThisObject[AttributeName + "XML"] = Attributes[AttributeName];
			
			If CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
				ModuleContactInformationManagement = CommonUse.CommonModule("ContactInformationManagement");
				
				ThisObject[AttributeName] = ModuleContactInformationManagement.PresentationContactInformation(
					Attributes[AttributeName]);
				
				If IsAddress = True Then
					ValidateAddress(AttributeName);
				EndIf;
			EndIf;
			
		ElsIf OnlyDigits Then
			ThisObject[AttributeName] = OnlyDigits(Attributes[AttributeName]);
		Else
			ThisObject[AttributeName] = Attributes[AttributeName];
		EndIf;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function OnlyDigits(String)
	
	StringLength = StrLen(String);
	
	ProcessedRow = "";
	
	For CharacterNumber = 1 To StringLength Do
		Char = Mid(String, CharacterNumber, 1);
		If Char >= "0" AND Char <= "9" Then
			ProcessedRow = ProcessedRow + Char;
		EndIf;
	EndDo;
	
	Return ProcessedRow;
	
EndFunction

&AtServer
Function ValidateAttribute(Cancel, AttributeName)
	
	Item = Items[AttributeName];
	
	If ValueIsFilled(Item.Title) Then
		TitleFields = Item.Title;
	Else
		TitleFields = AttributesHeaders.FindByValue(AttributeName);
	EndIf;
	
	If Not ValueIsFilled(ThisObject[AttributeName]) Then
		CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='The ""%1"" field is not filled in';ru='Поле ""%1"" не заполнено'"), TitleFields), , AttributeName, , Cancel);
		
		Return False;
	EndIf;
	
	Return True;
	
EndFunction


&AtServer
Function PreparedDocument()
	
	If Not ManagerFilled() Then
		Return Undefined;
	EndIf;
	
	Template = Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.GetTemplate(
		?(ThisIsIndividualEntrepreneur,
			"RequestForIndividualEntrepreneurCertificate",
			"RequestForLegalEntityCertificate"));
	
	Document = New SpreadsheetDocument;
	FillPropertyValues(Template.Parameters, ThisObject);
	FillPropertyValues(Template.Parameters, DocumentsCertificateFields);
	
	Template.Parameters.Phone = Phone;
	
	DocumentViewPresentation = Items.DocumentKind1.ChoiceList.FindByValue(DocumentKind1).Presentation;
	DocumentViewPresentation = Lower(Left(DocumentViewPresentation, 1)) + Mid(DocumentViewPresentation, 2);
	
	DocumentNumberPresentation =
		?(DocumentKind1 = "21", AttributePresentationRFPassportNumber(DocumentNumber), DocumentNumber);
	
	DocumentIssueDatePresentation = AttributePresentationDocumentIssueDate(DocumentIssueDate);
	
	Template.Parameters.IdentityCard = DocumentViewPresentation + " " + DocumentNumberPresentation + " "
		+ NStr("en='from';ru='from'") + " " + DocumentIssueDatePresentation + " "
		+ NStr("en='issued';ru='выданный'") + " " + DocumentWhoIssued;
	
	Document.Put(Template);
	
	Return Document;
	
EndFunction

&AtServer
Function SendStatement(ErrorDescription)
	
	ErrorDescription = "";
	ErrorDescriptionTemplate =
		NStr("en='Failed to send a statement
		|due to: %1';ru='Не удалось отправить
		|заявление по причине: %1'");
	
	Try
		WebService = CCWebService();
	Except
		ErrorInfo = ErrorInfo();
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(ErrorDescriptionTemplate,
			BriefErrorDescription(ErrorInfo));
		Return False;
	EndTry;
	
	Ticket = TicketToSupportSite(ErrorDescription);
	If Not ValueIsFilled(Ticket) Then
		Return False;
	EndIf;
	
	ThisRetrySendingPackage = True;
	If Not ValueIsFilled(DocumentManagementIdentifier) Then
		ThisRetrySendingPackage = False;
		DocumentManagementIdentifier = NewCompressedUUID();
	EndIf;
	
	XMLStatement = XMLStatement(Ticket);
	StatementPackage = StatementPackage(XMLStatement);
	
	UpdatePartnerDetailsAvailability();
	
	Try
		Response = WebService.SendPacket(StatementPackage);
	Except
		ErrorInfo = ErrorInfo();
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(ErrorDescriptionTemplate,
			BriefErrorDescription(ErrorInfo));
		Return False;
	EndTry;
	
	If Not ValueIsFilled(Response) Then
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(ErrorDescriptionTemplate,
			NStr("en='Server returned an empty response.';ru='Сервер вернул пустой ответ.'"));
		Return False;
	EndIf;
	
	XMLReader = New XMLReader;
	XMLReader.SetString(Response);
	DOMBuilder = New DOMBuilder();
	DOMBuilder = DOMBuilder.Read(XMLReader);
	XMLReader.Close();
	
	DOMNode = DOMBuilder.GetElementByTagName("code");
	ResultCode = DOMNode[0].TextContent;
	
	If ResultCode = "0" Then
		SendingDate = CurrentSessionDate();
		Return True;
		
	ElsIf ResultCode = "60" // Document flow is already registered.
	        AND ThisRetrySendingPackage Then
		
		SendingDate = CurrentSessionDate();
		Return True;
	EndIf;
	
	DocumentManagementIdentifier = "";
	
	UpdatePartnerDetailsAvailability();
	
	DOMNode = DOMBuilder.GetElementByTagName("errorMessage");
	If DOMNode.Count() > 0 Then
		ErrorDescription = DOMNode[0].TextContent;
	EndIf;
	
	If ResultCode = "202" Then
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Cannot check the contract for ITS (its.1c.ru) due to: The ticket received for the %1 user is incorrect or obsolete. Try to send the statement again.';ru='Не удалось проверить договор на ИТС (its.1c.ru) по причине: Билет, полученный для пользователя %1, неверный или устарел.  Попробуйте отправить заявление еще раз.'"),
			AuthenticationParametersOnSite.Login);
		
	ElsIf ResultCode = "206" Then
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Statement is not
		|accepted due to: User %1 does not have a valid contract for ITS (its.1c.en).
		|To conclude the contact, please contact the service company.
		|
		|After concluding the contract please send the statement once again.';ru='Заявление не принято по причине: Пользователь %1 не имеет действующего договора на ИТС (its.1c.ru). Для заключения договора обратитесь в обслуживающую организацию.  После заключения договора отправьте заявление еще раз.'"),
			AuthenticationParametersOnSite.Login);
	Else
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(ErrorDescriptionTemplate,
			ErrorDescription);
	EndIf;
	
	Return False;
	
EndFunction

&AtServer
Function TicketToSupportSite(ErrorDescription)
	
	Ticket = "";
	Try
		WebService = CommonUse.WSProxy(
			"",
			"http://api.cas.jasig.org/",
			"TicketApiImplService",
			"TicketApiImplPort",
			AuthenticationParametersOnSite.Login,
			AuthenticationParametersOnSite.Password,
			5,
			False);
		
		Ticket = WebService.getTicket(
			AuthenticationParametersOnSite.Login,
			AuthenticationParametersOnSite.Password,
			"");
	Except
		ErrorInfo = ErrorInfo();
		BriefErrorDescription = BriefErrorDescription(ErrorInfo);
		If Find(BriefErrorDescription, "IncorrectLoginOrPasswordExceptionApi") > 0 Then
			BriefErrorDescription = NStr("en='Incorrect user name or password.';ru='Некорректное имя пользователя или пароль.'");
			AuthenticationParametersOnSite = Undefined;
		EndIf;
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to connect to support website
		|due to:% 1';ru='Не удалось подключиться к
		|сайту поддержки по причине: %1'"),
			BriefErrorDescription);
	EndTry;
	
	Return Ticket;
	
EndFunction

&AtServer
Function XMLStatement(Ticket)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString("windows-1251");
	XMLWriter.WriteXMLDeclaration();
	
	XMLWriter.WriteStartElement("Statement");
	XMLWriter.WriteAttribute("VersForm", "1.3");
	XMLWriter.WriteAttribute("FormationDateTime", XMLString(CurrentSessionDate()));
	XMLWriter.WriteAttribute("VersProg", "1C");
	
		XMLWriterItem(XMLWriter, "StatementType", "1");
		XMLWriterItem(XMLWriter, "LegalEntityCharacteristic", Not ThisIsIndividualEntrepreneur);
		XMLWriterItem(XMLWriter, "TIN");
		
		XMLWriterItem(XMLWriter, "OGRN");
		XMLWriterItem(XMLWriter, "FullDescr",  DescriptionFull);
		XMLWriterItem(XMLWriter, "ShortDescription", AbbreviatedName);
		XMLWriterItem(XMLWriter, "PhoneMain",     Phone);
		
		XMLWriterAddress(XMLWriter, "AddressLegal", LegalAddressXML);
		XMLWriterAddress(XMLWriter, "AddressCurrent", ActualAddressXML);
		
		XMLWriter.WriteStartElement("EDSOwners");
		XMLWriter.WriteStartElement("EDSOwner");
		XMLWriter.WriteAttribute("INILA", AttributePresentationInsuranceNumberRPF(InsuranceNumberRPF));
		
			XMLWriter.WriteStartElement("Initials");
			XMLWriter.WriteAttribute("Surname",  Surname);
			XMLWriter.WriteAttribute("Name",      Name);
			XMLWriter.WriteAttribute("Patronymic", Patronymic);
			XMLWriter.WriteEndElement(); // ItemEnd DescriptionFull.
			
			If DocumentKind1 = "21" Then
				DocumentNumberPresentation = AttributePresentationRFPassportNumber(DocumentNumber);
			Else
				DocumentNumberPresentation = DocumentNumber;
			EndIf;
			DocumentIssueDatePresentation = AttributePresentationDocumentIssueDate(DocumentIssueDate);
			
			XMLWriter.WriteStartElement("IDCard");
			XMLWriter.WriteAttribute("CodeDocKind", DocumentKind1);
			XMLWriter.WriteAttribute("DocSerNum", DocumentNumberPresentation);
			XMLWriter.WriteAttribute("DocDate",   DocumentIssueDatePresentation);
			XMLWriter.WriteAttribute("DocIss",    DocumentWhoIssued);
			XMLWriter.WriteEndElement(); // ItemEnd IDCard.
			
			If Not ThisIsIndividualEntrepreneur Then
				XMLWriterItem(XMLWriter, "Position",  Position);
			EndIf;
			
			XMLWriterItem(XMLWriter, "Email", Email);
			
			Rows = ApplicationsList.FindRows(New Structure("Ref", Object.Application));
			
			XMLWriter.WriteStartElement("CryptographyServiceProvider");
			XMLWriterItem(XMLWriter, "CryptographyServiceProviderType", XMLString(Rows[0].ApplicationType));
			XMLWriterItem(XMLWriter, "CryptographyServiceProviderName", XMLString(Rows[0].ApplicationName));
			XMLWriter.WriteEndElement(); // ItemEnd CryptographyServiceProvider.
			
			XMLWriter.WriteStartElement("CertificateQuery");
			XMLWriter.WriteAttribute("CertifyingCenter", "LLC ""SPC ""1C""");
			XMLWriter.WriteText(QueryForCertificateFileText());
			XMLWriter.WriteEndElement(); // ItemEnd CertificateQuery.
		
		XMLWriter.WriteEndElement(); // ItemEnd EDSOwner.
		XMLWriter.WriteEndElement(); // ItemEnd EDSOwners.
		
		XMLWriterItem(XMLWriter, "PartnerITN", DocumentsPartnerTIN);
		
		XMLWriterItem(XMLWriter, "UserTicket", Ticket);
		
	XMLWriter.WriteEndElement(); // ItemEnd Statement.
	
	XMLString = XMLWriter.Close();
	
	Return XMLString;
	
EndFunction

&AtServer
Function QueryForCertificateFileText()
	
	ErrorText =
		NStr("en='Failed to read a previously created certificate request.
		|Statement can not be sent.
		|Delete it and create a new one.';ru='Не удалось прочитать ранее созданный запрос на сертификат.
		|Заявление не может быть отправлено.
		|Удалите его и создайте новое.'");
	
	If Not ValueIsFilled(RequestAddressForCertificate) Then
		Raise ErrorText;
	EndIf;
	
	FileBinaryData = GetFromTempStorage(RequestAddressForCertificate);
	If TypeOf(FileBinaryData) <> Type("BinaryData") Then
		Raise ErrorText;
	EndIf;
	
	TempFileName = GetTempFileName(".p10");
	FileBinaryData.Write(TempFileName);
	
	TextDocument = New TextDocument;
	TextDocument.Read(TempFileName);
	Text = TrimAll(TextDocument.GetText());
	
	DeleteFiles(TempFileName);
	
	If Not ValueIsFilled(Text) Then
		Raise ErrorText;
	EndIf;
	
	Return Text;
	
EndFunction

&AtServer
Function XMLPackageDescription(StatementFileName)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString("windows-1251");
	XMLWriter.WriteXMLDeclaration();
	
	XMLWriter.WriteStartElement("package");
	XMLWriter.WriteAttribute("formatVersion", "1C:1.0");
	
	XMLWriter.WriteAttribute("progVers", "1.0");
	XMLWriter.WriteAttribute("documentflowType", "EDFSubscriberRegistration");
	XMLWriter.WriteAttribute("transactionType", "Registration");
	XMLWriter.WriteAttribute("documentflowIdentifier", DocumentManagementIdentifier);
	
		XMLWriter.WriteStartElement("sender");
		XMLWriter.WriteAttribute("subjectType", "subscriber");
		XMLWriter.WriteEndElement();
		
		XMLWriter.WriteStartElement("recipient");
		XMLWriter.WriteAttribute("entityIdentifier", "KalugaAstral");
		XMLWriter.WriteAttribute("subjectType", "specialOperator");
		XMLWriter.WriteEndElement();
		
		XMLWriter.WriteStartElement("document");
		XMLWriter.WriteAttribute("documentIdentifier", NewCompressedUUID());
		XMLWriter.WriteAttribute("documentType", "Statement");
		XMLWriter.WriteAttribute("contentType", "xml");
		XMLWriter.WriteAttribute("compressed", "false");
		XMLWriter.WriteAttribute("encrypted", "false");
		
			XMLWriter.WriteStartElement("contents");
			XMLWriter.WriteAttribute("fileName", StatementFileName);
			XMLWriter.WriteEndElement();
		
		XMLWriter.WriteEndElement(); // ItemEnd document.
	
	XMLWriter.WriteEndElement(); // ItemEnd package.
	
	XMLString = XMLWriter.Close();
	
	Return XMLString;
	
EndFunction

&AtServer
Function StatementPackage(XMLStatement)
	
	// Preparation of statement package.
	TemporaryDirectory = CommonUseClientServer.AddFinalPathSeparator(
		TempFilesDir() + NewCompressedUUID());
	
	CreateDirectory(TemporaryDirectory);
	
	StatementFileName = TemporaryDirectory + NewCompressedUUID() + ".bin";
	FileNameDescription  = TemporaryDirectory + "packageDescription.xml";
	PackageFileName    = TemporaryDirectory + DocumentManagementIdentifier + ".zip";
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(StatementFileName, "windows-1251");
	XMLWriter.WriteRaw(XMLStatement);
	XMLWriter.Close();
	
	StatementData = New BinaryData(StatementFileName);
	DeleteFiles(StatementFileName);
	StatementData.Write(StatementFileName);
	
	StatementFile = New File(StatementFileName);
	XMLPackageDescription = XMLPackageDescription(StatementFile.Name);
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(FileNameDescription, "windows-1251");
	XMLWriter.WriteRaw(XMLPackageDescription);
	XMLWriter.Close();
	
	WriteArchive = New ZipFileWriter(PackageFileName, , , , ZIPCompressionLevel.Maximum);
	WriteArchive.Add(FileNameDescription);
	WriteArchive.Add(StatementFileName);
	WriteArchive.Write();
	
	StatementPackage = Base64String(New BinaryData(PackageFileName));
	DeleteFiles(TemporaryDirectory);
	
	Return StatementPackage;
	
EndFunction

&AtServer
Procedure XMLWriterItem(XMLWriter, ItemName, Value = Undefined)
	
	If Value = Undefined Then
		Value = ThisObject[ItemName];
	EndIf;
	
	XMLWriter.WriteStartElement(ItemName);
	XMLWriter.WriteText(XMLString(Value));
	XMLWriter.WriteEndElement();
	
EndProcedure

&AtServer
Procedure XMLWriterAddress(XMLWriter, ItemName, AddressXML)
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Return;
	EndIf;
	
	ModuleContactInformationManagement = CommonUse.CommonModule("ContactInformationManagement");
	
	AddressStructure = ModuleContactInformationManagement.PreviousStructureOfContactInformationXML(AddressXML);
	
	XMLWriter.WriteStartElement(ItemName);
	
	XMLWriter.WriteAttribute("CodeState",  AddressStructure.StateCode);
	XMLWriter.WriteAttribute("Settlement", SettlementEntirely(AddressStructure));
	XMLWriter.WriteAttribute("Street",      AddressStructure.Street);
	XMLWriter.WriteAttribute("Building",        AddressStructure.Building);
	XMLWriter.WriteAttribute("Section",     AddressStructure.Section);
	XMLWriter.WriteAttribute("Qart",      AddressStructure.Apartment);
	
	XMLWriter.WriteEndElement();
	
EndProcedure

&AtServer
Function CCWebService()
	
	WebService = CommonUse.WSProxy("",
		"", "RegService", "RegServiceSoap", , , 5, False);
	
	Return WebService;
	
EndFunction


&AtServer
Function GetCertificate()
	
	ErrorDescriptionTemplate =
		NStr("en='Cannot update the state due to: %1';ru='Не удалось обновить состояние по причине: %1'");
	
	// Query for statement processing status
	
	Try
		WebService = CCWebService();
		Response = WebService.ReceivePacket(String(DocumentManagementIdentifier));
	Except
		ErrorInfo = ErrorInfo();
		UpdateDateConditions = CurrentSessionDate();
		RequestProcessingState = StringFunctionsClientServer.SubstituteParametersInString(
			ErrorDescriptionTemplate, BriefErrorDescription(ErrorInfo));
		Return Undefined;
	EndTry;
	
	UpdateDateConditions = CurrentSessionDate();
	
	If Not ValueIsFilled(Response) Then
		RequestProcessingState = StringFunctionsClientServer.SubstituteParametersInString(
			ErrorDescriptionTemplate, NStr("en='Server returned an empty response.';ru='Сервер вернул пустой ответ.'"));
		Return Undefined;
	EndIf;
	
	ErrorDescription = "";
	XMLReader = New XMLReader;
	XMLReader.SetString(Response);
	DOMBuilder = New DOMBuilder();
	DOMBuilder = DOMBuilder.Read(XMLReader);
	XMLReader.Close();
	
	DOMNode = DOMBuilder.GetElementByTagName("code");
	ResultCode = DOMNode[0].TextContent;
	
	FileNameAnswerPackage = "";
	If ResultCode = "0" Then
		DOMNode = DOMBuilder.GetElementByTagName("packet");
		
		If DOMNode.Count() > 0 Then
			BinaryData = Base64Value(DOMNode[0].TextContent);
			FileNameAnswerPackage = GetTempFileName(".zip");
			BinaryData.Write(FileNameAnswerPackage);
		Else
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(ErrorDescriptionTemplate,
				NStr("en='Server returned empty data.';ru='Сервер вернул пустые данные.'"));
		EndIf;
		
	ElsIf ResultCode = "1" Then
		ErrorDescription = NStr("en='The application has not been processed yet, try again later.';ru='Заявление еще не обработано, попробуйте позже.'");
	Else
		DOMNode = DOMBuilder.GetElementByTagName("errorMessage");
		If DOMNode.Count() > 0 Then
			ErrorDescription = DOMNode[0].TextContent;
		Else
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Server returned error code: %1';ru='Сервер вернул код ошибки: %1'"), String(ResultCode));
		EndIf;
	EndIf;
	
	If ValueIsFilled(ErrorDescription) Then
		RequestProcessingState = ErrorDescription;
		Return Undefined;
	EndIf;
	
	TemporaryDirectory = CommonUseClientServer.AddFinalPathSeparator(
		TempFilesDir() + NewCompressedUUID());
	
	CreateDirectory(TemporaryDirectory);
	
	FileFound = False;
	Try
		Archive1 = New ZipFileReader(FileNameAnswerPackage);
		
		For Counter = 0 To Archive1.Items.Count() - 1 Do
			
			If Archive1.Items[Counter].Extension = "bin" Then
				FileFound = True;
				
				Archive1.Extract(Archive1.Items[Counter], TemporaryDirectory);
				Archive2 = New ZipFileReader(TemporaryDirectory + Archive1.Items[Counter].Name);
				Archive2.ExtractAll(TemporaryDirectory);
				
				XMLReader = New XMLReader;
				XMLReader.OpenFile(TemporaryDirectory + "file");
				DOMBuilder = New DOMBuilder;
				DOMDocument  = DOMBuilder.Read(XMLReader);
				XMLReader.Close();
				
				RegistrationSuccessful = Boolean(XMLNodeValue(DOMDocument, "RegistrationSuccessful"));
				RequestProcessingState = XMLNodeValue(DOMDocument, "Result");
				
				If RegistrationSuccessful Then
					SubscriberIdentifier = XMLNodeValue(DOMDocument, "SubscriberIdentifier");
				EndIf;
			EndIf;
		EndDo;
		
		If Not FileFound Then
			Raise NStr("en='Invalid data format.';ru='Неверный формат данных.'");
		EndIf;
	Except
		ErrorInfo = ErrorInfo();
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to parse server response
		|due to: %1';ru='Не удалось разобрать
		|ответ сервера по причине: %1'"),
			BriefErrorDescription(ErrorInfo));
	EndTry;
	
	DeleteFiles(FileNameAnswerPackage);
	DeleteFiles(TemporaryDirectory);
	
	If ValueIsFilled(ErrorDescription) Then
		RequestProcessingState = ErrorDescription;
		Return Undefined;
	EndIf;
	
	If Not RegistrationSuccessful Then
		Return False;
	EndIf;
	
	// Certificate request.
	
	Response = WebService.ReceiveUpdatedPacket(String(SubscriberIdentifier), Date('00010101'));
	
	ErrorDescription = "";
	XMLReader = New XMLReader;
	XMLReader.SetString(Response);
	DOMBuilder = New DOMBuilder();
	DOMBuilder = DOMBuilder.Read(XMLReader);
	XMLReader.Close();
	
	DOMNode = DOMBuilder.GetElementByTagName("code");
	ResultCode = DOMNode[0].TextContent;
	
	FileNameAnswerPackage = "";
	If ResultCode = "0" Then
		DOMNode = DOMBuilder.GetElementByTagName("packet");
		
		If DOMNode.Count() > 0 Then
			BinaryData = Base64Value(DOMNode[0].TextContent);
			FileNameAnswerPackage = GetTempFileName(".zip");
			BinaryData.Write(FileNameAnswerPackage);
		Else
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(ErrorDescriptionTemplate,
				NStr("en='Server returned empty data.';ru='Сервер вернул пустые данные.'"));
		EndIf;
	Else
		DOMNode = DOMBuilder.GetElementByTagName("errorMessage");
		If DOMNode.Count() > 0 Then
			ErrorDescription = DOMNode[0].TextContent;
		Else
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Server returned error code: %1';ru='Сервер вернул код ошибки: %1'"), String(ResultCode));
		EndIf;
	EndIf;
	
	If ValueIsFilled(ErrorDescription) Then
		RequestProcessingState = ErrorDescription;
		Return Undefined;
	EndIf;
	
	TemporaryDirectory = CommonUseClientServer.AddFinalPathSeparator(
		TempFilesDir() + NewCompressedUUID());
	
	CreateDirectory(TemporaryDirectory);
	
	FileFound = False;
	
	Try
		archive = New ZipFileReader(FileNameAnswerPackage);
		
		For Counter = 0 To archive.Items.Count() - 1 Do
			
			If archive.Items[Counter].Extension = "xml" Then
				FileFound = True;
				
				archive.Extract(Archive1.Items[Counter], TemporaryDirectory);
				
				XMLReader = New XMLReader;
				XMLReader.OpenFile(TemporaryDirectory + Archive1.Items[Counter].Name); 
				DOMBuilder = New DOMBuilder;
				DOMDocument = DOMBuilder.Read(XMLReader);
				XMLReader.Close();
				
				DOMNode = DOMDocument.GetElementByTagName("Certificate");
				If DOMNode.Count() <> 2 Then
					Raise NStr("en='Invalid data format.';ru='Неверный формат данных.'");
				EndIf;
				
				CertificateInRow = "";
				RootCertificateInRow = "";
				
				For Each Node IN DOMNode Do
					Imprint = Node.Attributes.GetNamedItem("Imprint").TextContent;
					Storage = Node.Attributes.GetNamedItem("Storage").TextContent;
					If Storage = "MY" Then
						CertificateInRow = Node.TextContent;
					EndIf;
					If Storage = "ROOT" Then
						RootCertificateInRow = Node.TextContent;
					EndIf;
				EndDo;
				
				If Not ValueIsFilled(CertificateInRow)
				 Or Not ValueIsFilled(RootCertificateInRow) Then
					
					Raise NStr("en='Invalid data format.';ru='Неверный формат данных.'");
				EndIf;
				
				CertificateData          = Base64Value(CertificateInRow);
				RootCertificateData = Base64Value(RootCertificateInRow);
				
				Certificate         = New CryptoCertificate(CertificateData);
				RootCertificate = New CryptoCertificate(RootCertificateData);
			EndIf;
		EndDo;
		
		If Not FileFound Then
			Raise NStr("en='Invalid data format.';ru='Неверный формат данных.'");
		EndIf;
	Except
		ErrorInfo = ErrorInfo();
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to parse server response
		|due to: %1';ru='Не удалось разобрать
		|ответ сервера по причине: %1'"),
			BriefErrorDescription(ErrorInfo));
	EndTry;
	
	DeleteFiles(FileNameAnswerPackage);
	DeleteFiles(TemporaryDirectory);
	
	If ValueIsFilled(ErrorDescription) Then
		RequestProcessingState = ErrorDescription;
		Return Undefined;
	EndIf;
	
	CertificateStructure = DigitalSignatureClientServer.FillCertificateStructure(Certificate);
	SubjectProperties     = DigitalSignatureClientServer.CertificateSubjectProperties(Certificate);
	
	CertificateAddress          = PutToTempStorage(CertificateData, UUID);
	RootCertificateAddress = PutToTempStorage(RootCertificateData, UUID);
	RootCertificateImprint = Base64String(RootCertificate.Imprint);
	
	// It is important to fill the thumbprint in order to eliminate the possibility of adding certificate duplicate.
	Object.Description = DigitalSignatureClientServer.CertificatePresentation(Certificate);
	
	Object.Signing = Certificate.UseToSign;
	Object.Encryption = Certificate.UseForEncryption;
	
	Object.Imprint      = CertificateStructure.Imprint;
	Object.IssuedToWhom      = CertificateStructure.IssuedToWhom;
	Object.WhoIssued       = CertificateStructure.WhoIssued;
	Object.ValidUntil = CertificateStructure.ValidUntil;
	
	Object.Surname   = SubjectProperties.Surname;
	Object.Name       = SubjectProperties.Name;
	Object.Patronymic  = SubjectProperties.Patronymic;
	Object.Position = SubjectProperties.Position;
	Object.firm     = SubjectProperties.Company;
	
	Return True;
	
EndFunction

&AtServerNoContext
Function XMLNodeValue(DOMDocument, NodeName, DefaultValue = "")
	
	DOMNode = DOMDocument.GetElementByTagName(NodeName);
	
	SuitableItemDOM = Undefined;
	
	If DOMNode.Count() > 0 Then
		SuitableItemDOM = DOMNode[0];
	EndIf;
	
	If SuitableItemDOM = Undefined Then
		Return DefaultValue;
		
	ElsIf NodeName = "Imprint" Then
		Return Lower(SuitableItemDOM.TextContent);
	Else
		Return SuitableItemDOM.TextContent;
	EndIf;
	
EndFunction

&AtClient
Procedure SetCertificate(Notification)
	
	DateCertificateInstallation = CommonUseClient.SessionDate();
	
	Context = New Structure("Notification", Notification);
	
	DigitalSignatureServiceClient.CreateCryptoManager(New NotifyDescription(
			"SetCertificateAfterCreatingCryptographyManager", ThisObject, Context),
		"", Undefined);
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterCreatingCryptographyManager(Manager, Context) Export
	
	If TypeOf(Manager) <> Type("CryptoManager") Then
		DigitalSignatureServiceClient.ShowRequestToApplicationError(
			NStr("en='Install the certificate on this computer';ru='Установка сертификата на компьютер'"),, Manager, New Structure);
		
		ErrorCertificateSetup = Manager.ErrorDescription;
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	Context.Insert("CryptoManager", Manager);
	
	If Cryptography <> Undefined Then
		SetCertificateAfterCreatingCryptographyObject(True, Context);
	Else
		CreateCryptographyObject(New NotifyDescription(
			"SetCertificateAfterCreatingCryptographyObject", ThisObject, Context),
			NStr("en='To install a certificate on
		|your computer, it is required to install the extension for the web client 1C:Enterprise.';ru='Для установки сертификата
		|на компьютер требуется установить расширение для веб-клиента 1С:Предприятия.'"),
			NStr("en='To install a certificate on
		|your computer, it is required to install additional external component.';ru='Для установки сертификата
		|на компьютер требуется установить дополнительную внешнюю компоненту.'"));
	EndIf;
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterCreatingCryptographyObject(Result, Context) Export
	
	If Result <> True Then
		ExecuteNotifyProcessing(Context.Notification, False);
		
		BeginAttachingFileSystemExtension(New NotifyDescription(
			"SetCertificateWhenCryptographyObjectCreationErrorAppearsAfterConnectingFilesExtension", ThisObject));
	Else
		SetCertificateAfterCryptographyObjectSuccessfulCreation(Context);
	EndIf;
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateWhenCryptographyObjectCreationErrorAppearsAfterConnectingFilesExtension(Attached, Context) Export
	
	If Not Attached Then
		ErrorCertificateSetup = NStr("en='File operation extension is not installed.';ru='Не установлено расширение для работы с файлами.'");
	Else
		BeginAttachingCryptoExtension(New NotifyDescription(
			"SetCertificateWhenCryptographyObjectCreationErrorAppearsAfterConnectingCryptographyExtension", ThisObject));
	EndIf;
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateWhenCryptographyObjectCreationErrorAppearsAfterConnectingCryptographyExtension(Attached, Context) Export
	
	If Not Attached Then
		ErrorCertificateSetup = NStr("en='Cryptography operation extension is not installed.';ru='Не установлено расширение для работы с криптографией.'");
	Else
		ErrorCertificateSetup = NStr("en='Additional external component is not installed.';ru='Не установлена дополнительная внешняя компонента.'");
	EndIf;
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterCryptographyObjectSuccessfulCreation(Context)
	
	GetTemporaryFilesDirectoryComponents(New NotifyDescription(
		"SetCertificateAfterComponentTemporaryFilesDirectoryReceipt", ThisObject, Context));
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterComponentTemporaryFilesDirectoryReceipt(Folder, Context) Export
	
	Context.Insert("TemporaryDirectory", Folder + NewCompressedUUID());
	
	Context.TemporaryDirectory = CommonUseClientServer.AddFinalPathSeparator(
		Context.TemporaryDirectory);
	
	Context.Insert("CertificateFileName",          "my.cer");
	Context.Insert("RootCertificateFileName", "root.cer");
	
	Context.Insert("FilesToReceive", New Array);
	Context.FilesToReceive.Add(New TransferableFileDescription(
		Context.CertificateFileName, CertificateAddress));
	
	Context.FilesToReceive.Add(New TransferableFileDescription(
		Context.RootCertificateFileName, RootCertificateAddress));
	
	Calls = New Array;
	AddCall(Calls, "BeginGettingFiles", Context.FilesToReceive, Context.TemporaryDirectory, False, , );
	AddCall(Calls, "BeginDeletingFiles",  Context.TemporaryDirectory, , , , );
	
	BeginRequestingUserPermission(New NotifyDescription(
		"SetCertificateAfterGettingPermission", ThisObject, Context), Calls);
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterGettingPermission(PermissionsReceived, Context) Export
	
	If Not PermissionsReceived Then
		ErrorCertificateSetup =
			NStr("en='Saving certificates to the temporary folder is canceled by user.';ru='Сохранение сертификатов во временную папку отменено пользователем.'");
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	BeginCreatingDirectory(New NotifyDescription(
		"SetCertificateAfterCreatingDirectory", ThisObject, Context), Context.TemporaryDirectory);
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterCreatingDirectory(PermissionsReceived, Context) Export
	
	BeginGettingFiles(New NotifyDescription(
			"SetCertificateAfterReceivingFiles", ThisObject, Context),
		Context.FilesToReceive, Context.TemporaryDirectory, False);
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterReceivingFiles(ReceivedFiles, Context) Export
	
	If ReceivedFiles = Undefined
	 Or ReceivedFiles.Count() <> 2 Then
		
		ErrorCertificateSetup = NStr("en='Certificates were not saved into a temporary folder.';ru='Сертификаты не были сохранены во временную папку.'");
		SetCertificateDeleteTemporaryDirectoryAndEnd(False, Context);
		Return;
	EndIf;
	
	CheckKeyContainerExistence(New NotifyDescription(
			"SetCertificateAfterCheckingKeyContainerExistence", ThisObject, Context),
		KeyContainerPath, KeyContainerName);
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterCheckingKeyContainerExistence(Exists, Context) Export
	
	If Not Exists Then
		ErrorCertificateSetup = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to find the key container on the computer.
		|Container name: ""%1"".
		|Path to container: ""%2"".';ru='Не удалось найти контейнер ключа на компьютере.
		|Имя контейнера: ""%1"".
		|Путь к контейнеру: ""%2"".'"),
			KeyContainerName,
			KeyContainerPath);
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	ActiveWindow().Activate();
	ErrorCertificateSetup = "";
	
	Cryptography.StartCallSetCertificateInContainerAndStorage(New NotifyDescription(
			"SetCertificateAfterCallSetCertificateToContainerAndStorage", ThisObject, Context,
			"SetCertificateAfterCallErrorSetCertificateToContainerAndStorage", ThisObject),
		Context.TemporaryDirectory + Context.CertificateFileName, KeyContainerPath);
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterCallErrorSetCertificateToContainerAndStorage(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	ErrorCertificateSetup = BriefErrorDescription(ErrorInfo);
	
	SetCertificateAfterCallSetCertificateToContainerAndStorage( , , Context);
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterCallSetCertificateToContainerAndStorage(Result, CallParameters, Context) Export
	
	ActiveWindow().Activate();
	
	If Result <> True AND Not ValueIsFilled(ErrorCertificateSetup) Then
		ErrorCertificateSetup = NStr("en='Cannot install a personal certificate.';ru='Не удалось установить личный сертификат.'");
	EndIf;
	
	DigitalSignatureServiceClient.GetCertificateByImprint(New NotifyDescription(
			"SetCertificateAfterCertificateSearch", ThisObject, Context),
		Object.Imprint,
		CryptoCertificateStoreType.PersonalCertificates,
		Undefined,
		Context.CryptoManager);
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterCertificateSearch(Result, Context) Export
	
	If TypeOf(Result) <> Type("CryptoCertificate") Then
		If Result.Property("CertificateNotFound") Then
			SearchError =
				NStr("en='Cannot find a personal certificate installed on the computer.';ru='Не удалось найти личный сертификат, установленный на компьютер.'");
		Else
			SearchError = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Failed to find a personal certificate installed on the
		|computer due to: %1';ru='Не удалось найти личный сертификат, установленный
		|на компьютер по причине: %1'"),
				Result.ErrorDescription);
		EndIf;
		ErrorCertificateSetup = TrimL(ErrorCertificateSetup + Chars.LF + Chars.LF) + SearchError;
		SetCertificateDeleteTemporaryDirectoryAndEnd(False, Context);
		Return;
	EndIf;
	ErrorCertificateSetup = "";
	
	Context.Insert("CryptoCertificate", Result);
	
	ActiveWindow().Activate();
	
	Cryptography.StartCallImportCertificate(New NotifyDescription(
			"SetCertificateAfterCallingImportCertificate", ThisObject, Context,
			"SetCertificateAfterCallErrorImportCertificate", ThisObject),
		Context.TemporaryDirectory + Context.RootCertificateFileName, "ROOT");
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterCallErrorImportCertificate(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	ErrorCertificateSetup = BriefErrorDescription(ErrorInfo);
	
	SetCertificateAfterCallingImportCertificate( , , Context);
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterCallingImportCertificate(Result, CallParameters, Context) Export
	
	ActiveWindow().Activate();
	
	If Result <> True AND Not ValueIsFilled(ErrorCertificateSetup) Then
		ErrorCertificateSetup = NStr("en='Cannot install the root certificate.';ru='Не удалось установить корневой сертификат.'");
	EndIf;
	
	ActiveWindow().Activate();
	
	DigitalSignatureServiceClient.GetCertificateByImprint(New NotifyDescription(
			"SetCertificateAfterRootCertificateSearch", ThisObject, Context),
		RootCertificateImprint,
		CryptoCertificateStoreType.RootCertificates,
		Undefined,
		Context.CryptoManager);
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterRootCertificateSearch(Result, Context) Export
	
	If TypeOf(Result) <> Type("CryptoCertificate") Then
		If Result.Property("CertificateNotFound") Then
			SearchError =
				NStr("en='Cannot find a root certificate installed on the computer.';ru='Не удалось найти корневой сертификат, установленный на компьютер.'");
		Else
			SearchError = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Failed to find the root certificate installed on the
		|computer due to: %1';ru='Не удалось найти корневой сертификат, установленный
		|на компьютер по причине: %1'"),
				Result.ErrorDescription);
		EndIf;
		ErrorCertificateSetup = TrimL(ErrorCertificateSetup + Chars.LF + Chars.LF) + SearchError;
		SetCertificateDeleteTemporaryDirectoryAndEnd(False, Context);
		Return;
	EndIf;
	ErrorCertificateSetup = "";
	
	SetCertificateDeleteTemporaryDirectoryAndEnd(
		Not ValueIsFilled(ErrorCertificateSetup), Context);
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateDeleteTemporaryDirectoryAndEnd(Result, Context)
	
	Context.Insert("Result", Result);
	
	BeginDeletingFiles(New NotifyDescription(
			"SetCertificateAfterDeletingTemporaryDirectory", ThisObject, Context),
		Context.TemporaryDirectory);
	
EndProcedure

// Continue the procedure SetCertificate.
&AtClient
Procedure SetCertificateAfterDeletingTemporaryDirectory(Context) Export
	
	ExecuteNotifyProcessing(Context.Notification, Context.Result);
	
EndProcedure

&AtClientAtServerNoContext
Procedure AddCall(Calls, Method, P1, P2, P3, P4, P5)
	
	Call = New Array;
	Call.Add(Method);
	Call.Add(P1);
	Call.Add(P2);
	Call.Add(P3);
	Call.Add(P4);
	Call.Add(P5);
	
	Calls.Add(Call);
	
EndProcedure

// Processing of address entry through the subsystem ContactInformation.

&AtClient
Procedure AddressPresentationSelectionStart(Form, Item, ChoiceData, StandardProcessing, AttributeName, FormTitle)
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Return;
	EndIf;
	
	ModuleContactInformationManagementClient = CommonUseClient.CommonModule(
		"ContactInformationManagementClient");
	
	TypeNameContactInformation = "Enum" + ".ContactInformationTypes.Address";
	
	ContactInformationKind = New Structure;
	ContactInformationKind.Insert("Type", PredefinedValue(TypeNameContactInformation));
	ContactInformationKind.Insert("DomesticAddressOnly",        True);
	ContactInformationKind.Insert("IncludeCountryInPresentation", False);
	ContactInformationKind.Insert("HideObsoleteAddresses",   False);
	
	FormParameters = ModuleContactInformationManagementClient.ContactInformationFormParameters(
		ContactInformationKind, ThisObject[AttributeName + "XML"], ThisObject[AttributeName]);
	
	FormParameters.Insert("Title", FormTitle);
	
	ModuleContactInformationManagementClient.OpenContactInformationForm(FormParameters, Item);
	
EndProcedure

&AtClient
Procedure AddressPresentationClearance(Form, Item, StandardProcessing, AttributeName)
	
	Form[AttributeName + "XML"] = "";
	Form[AttributeName] = "";
	
EndProcedure

&AtClient
Procedure AddressPresentationChoiceProcessing(Form, Item, ValueSelected, StandardProcessing, AttributeName)
	
	StandardProcessing = False;
	If TypeOf(ValueSelected) <> Type("Structure") Then
		// Data is not changed.
		Return;
	EndIf;
	
	Form[AttributeName + "XML"] = ValueSelected.ContactInformation;
	Form[AttributeName] = ValueSelected.Presentation;
	
	ValidateAddress(AttributeName);
	
EndProcedure

// Processing of phone entry through the subsystem ContactInformation.

&AtClient
Procedure PhonePresentationSelectionStart(Form, Item, ChoiceData, StandardProcessing, AttributeName, FormTitle)
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Return;
	EndIf;
	
	ModuleContactInformationManagementClient = CommonUseClient.CommonModule(
		"ContactInformationManagementClient");
	
	TypeNameContactInformation = "Enum" + ".ContactInformationTypes.Phone";
	
	ContactInformationKind = New Structure;
	ContactInformationKind.Insert("Type", PredefinedValue(TypeNameContactInformation));
	
	FormParameters = ModuleContactInformationManagementClient.ContactInformationFormParameters(
		ContactInformationKind, ThisObject[AttributeName + "XML"], ThisObject[AttributeName]);
	
	FormParameters.Insert("Title", FormTitle);
	
	ModuleContactInformationManagementClient.OpenContactInformationForm(FormParameters, Item);
	
EndProcedure

&AtClient
Procedure PresentationPhoneClearance(Form, Item, StandardProcessing, AttributeName)
	
	Form[AttributeName + "XML"] = "";
	Form[AttributeName] = "";
	
EndProcedure

&AtClient
Procedure PhonePresentationSelectionProcessing(Form, Item, ValueSelected, StandardProcessing, AttributeName)
	
	StandardProcessing = False;
	If TypeOf(ValueSelected) <> Type("Structure") Then
		// Data is not changed.
		Return;
	EndIf;
	
	Form[AttributeName + "XML"] = ValueSelected.ContactInformation;
	Form[AttributeName] = ValueSelected.Presentation;
	
EndProcedure


&AtServerNoContext
Function RFStateNameByRecommendationsForDSVKC(StateCode)
	
	// Guidelines for contents of qualified
	// digital signature verification key certificate (Version 1.4).
	//
	// Appendix 2. Format of federal subject name.
	// From the section "Catalog of state codes".
	
	AllRFStatesNames = Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.GetTemplate(
		"RFStatesNamesByRecommendationsForKCDS");
	
	String = AllRFStatesNames.GetLine(Number(StateCode));
	
	If Left(String, 3) <> StateCode + " " Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Region of the Russian Federation with the ""%1"" code does not exist.';ru='Регион РФ с кодом ""%1"" не существует.'"), StateCode);
	EndIf;
	
	String = TrimAll(Mid(String, 4));
	
	If Not ValueIsFilled(String) Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Name recommended for the certificate of DS authentication key is not assigned yet for the RF region with code ""%1"".';ru='Для региона РФ с кодом ""%1"" имя, рекомендованное для СКПЭП, еще не назначено.'"),
			StateCode);
	EndIf;
	
	Return String;
	
EndFunction

&AtClientAtServerNoContext
Function SuppliedApplicationPresentation(ApplicationsList, Application)
	
	If TypeOf(Application) = Type("String") Then
		Rows = ApplicationsList.FindRows(New Structure("ID", Application));
	Else
		Rows = ApplicationsList.FindRows(New Structure("Ref", Application));
	EndIf;
	
	Return Rows[0].Presentation;
	
EndFunction

&AtServer
Procedure ImportStatement()
	
	LockDataForEdit(Parameters.CertificatRef, , UUID);
	CurrentObject = Parameters.CertificatRef.GetObject();
	ValueToFormAttribute(CurrentObject, "Object");
	
	RequestLastStatus = Object.RequestStatus;
	
	Content = CurrentObject.RequestContent.Get();
	If TypeOf(Content) = Type("Structure") Then
		FillPropertyValues(ThisObject, Content);
	EndIf;
	
	If Content.Property("CertificateQuery")
	   AND TypeOf(Content.CertificateQuery) = Type("BinaryData") Then
		
		RequestAddressForCertificate = PutToTempStorage(Content.CertificateQuery, UUID);
	EndIf;
	
	If Content.Property("Certificate")
	   AND TypeOf(Content.Certificate) = Type("BinaryData") Then
		
		CertificateAddress = PutToTempStorage(Content.Certificate, UUID);
	EndIf;

	If Content.Property("RootCertificate")
	   AND TypeOf(Content.RootCertificate) = Type("BinaryData") Then
		
		RootCertificateAddress = PutToTempStorage(Content.RootCertificate, UUID);
	EndIf;
	
	AgreementApproval = True;
	Items.AgreementApproval.ReadOnly = True;
	Items.FormPrintAgreement.Visible = False;
	Items.FormNext.Enabled = True;
	
	If CurrentObject.RequestStatus = Enums.CertificateIssueRequestState.NotPrepared Then
		GoToPageCertificateQueryPreparationOnServerOnImport();
		
	ElsIf CurrentObject.RequestStatus = Enums.CertificateIssueRequestState.Prepared Then
		GoToPageStatementSendingOnServerOnImporting();
		
	ElsIf CurrentObject.RequestStatus = Enums.CertificateIssueRequestState.Sent Then
		GoToPagePendingStatementProcessingOnServerOnImport();
		
	ElsIf CurrentObject.RequestStatus = Enums.CertificateIssueRequestState.ExecutedCertificateNotInstalled Then
		GoToPageCertificateSetupOnServerOnImporting();
		
	ElsIf CurrentObject.RequestStatus = Enums.CertificateIssueRequestState.Rejected Then
		AutoTitle = False;
		Title = NStr("en='The application using which the certificate was not received';ru='Заявление, по которому не удалось получить сертификат'");
		Items.FormNext.Visible = False;
		Items.FormClose.Title = NStr("en='Close';ru='Закрыть'");
		FillAttributesStatements(True);
		Items.Pages.CurrentPage = Items.PageProcessedRequest;
		Items.ProgressPages.CurrentPage = Items.ProgressPageProcessedRequest;
		
	ElsIf CurrentObject.RequestStatus = Enums.CertificateIssueRequestState.Executed Then
		AutoTitle = False;
		Title = NStr("en='Application which was used to get the certificate';ru='Заявление, по которому был получен сертификат'");
		Items.FormExportRootCertificate.Visible = True;
		Items.FormExportCertificateQuery.Visible = True;
		Items.FormNext.Visible = False;
		Items.FormClose.Title = NStr("en='Close';ru='Закрыть'");
		Items.FormClose.DefaultButton = True;
		FillAttributesStatements(True);
		Items.Pages.CurrentPage = Items.PageProcessedRequest;
		Items.ProgressPages.CurrentPage = Items.ProgressPageProcessedRequest;
	EndIf;
	
EndProcedure


&AtServer
Procedure FillAttributesStatements(All = False)
	
	RequestAttributes.Clear();
	
	// Filling of application information.
	If All Then
		String = RequestAttributes.Add();
		String.Attribute = NStr("en='Digital signature application';ru='Программа электронной подписи'");
		String.Value = ApplicationPresentation;
	EndIf;
	
	// Completion of information about company.
	FillAttribute(NStr("en='Company information';ru='Сведения об организации'"),, True);
	
	FillAttribute("AbbreviatedName");
	FillAttribute("DescriptionFull");
	FillAttribute("TIN");
	FillAttribute("OGRN");
	FillAttribute("BankAccount");
	FillAttribute("BIN");
	FillAttribute("CorrespondentAccount");
	FillAttribute("Phone", Phone);
	FillAttribute("LegalAddress", LegalAddress);
	FillAttribute("ActualAddress", ActualAddress);
	
	// Filling of the information about certificate owner.
	FillAttribute(NStr("en='Certificate owner information';ru='Сведения о владельце сертификата'"),, True);
	
	FillAttribute("Surname");
	FillAttribute("Name");
	FillAttribute("Patronymic");
	FillAttribute("InsuranceNumberRPF", AttributePresentationInsuranceNumberRPF(InsuranceNumberRPF));
	
	If Not ThisIsIndividualEntrepreneur Then
		FillAttribute("Position");
		FillAttribute("Department");
	EndIf;
	
	String = RequestAttributes.Add();
	String.Attribute = NStr("en='Identity document';ru='Документ, удостоверяющий личность'");
	String.Value = Items.DocumentKind1.ChoiceList.FindByValue(DocumentKind1).Presentation;
	
	String = RequestAttributes.Add();
	If DocumentKind1 = "21" Then
		String.Attribute = NStr("en='Series and number';ru='Серия и номер'");
		String.Value = AttributePresentationRFPassportNumber(DocumentNumber);
	Else
		String.Attribute = NStr("en='Number';ru='Number'");
		String.Value = DocumentNumber;
	EndIf;
	
	FillAttribute("DocumentWhoIssued");
	FillAttribute("DocumentIssueDate", AttributePresentationDocumentIssueDate(DocumentIssueDate));
	
	FillAttribute("Email");
	
	If Not All Then
		Return;
	EndIf;
	
	If Not ThisIsIndividualEntrepreneur Then
		// Completion of information about printed documents.
		FillAttribute(NStr("en='Information about manager';ru='Сведения о руководителе'"),, True);
		
		String = RequestAttributes.Add();
		String.Attribute = NStr("en='Full name of the manager';ru='ФИО руководителя'");
		String.Value = DocumentsHead;
		
		String = RequestAttributes.Add();
		String.Attribute = NStr("en='Manager position';ru='Должность руководителя'");
		String.Value = DocumentsHeadPosition;
		
		String = RequestAttributes.Add();
		String.Attribute = NStr("en='Manager action basis';ru='Основание действий руководителя'");
		String.Value = DocumentsHeadBasis;
	EndIf;
	
	// Completion of information about printed documents.
	FillAttribute(NStr("en='Information on service company';ru='Сведения об обслуживающей организации'"),, True);
	
	String = RequestAttributes.Add();
	String.Attribute = NStr("en='Partner name';ru='Наименование партнера'");
	String.Value = DocumentsPartner;
	
	String = RequestAttributes.Add();
	String.Attribute = NStr("en='Partner TIN';ru='ИНН партнера'");
	String.Value = DocumentsPartnerTIN;
	
EndProcedure

&AtClientAtServerNoContext
Function AttributePresentationInsuranceNumberRPF(InsuranceNumberRPF)
	
	Return Mid(InsuranceNumberRPF, 1, 3) + "-" + Mid(InsuranceNumberRPF,  4, 3)
	+ "-" + Mid(InsuranceNumberRPF, 7, 3) + " " + Mid(InsuranceNumberRPF, 10, 2);
	
EndFunction

&AtClientAtServerNoContext
Function AttributePresentationDocumentIssueDate(DocumentIssueDate)
	
	Return Format(DocumentIssueDate, "DF=dd.MM.yyyy");
	
EndFunction

&AtClientAtServerNoContext
Function AttributePresentationRFPassportNumber(RFPassportNumber)
	
	Return Left(RFPassportNumber, 2) + " " + Mid(RFPassportNumber, 3, 2) + " " + Right(RFPassportNumber, 6);
	
EndFunction

&AtServer
Procedure FillAttribute(AttributeName, Value = Undefined, ThisIsAttributesGroup = False)
	
	String = RequestAttributes.Add();
	
	If ThisIsAttributesGroup Then
		String.ThisIsAttributesGroup = True;
		String.Attribute = AttributeName;
		Return;
	EndIf;
	
	If ValueIsFilled(Items[AttributeName].Title) Then
		String.Attribute = Items[AttributeName].Title;
	Else
		String.Attribute = AttributesHeaders.FindByValue(AttributeName);
	EndIf;
	
	If Value = Undefined Then
		String.Value = ThisObject[AttributeName];
	Else
		String.Value = Value;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function NewCompressedUUID()
	
	Return Lower(StrReplace(String(New UUID), "-", ""));
	
EndFunction

&AtClient
Procedure ApplicationSelectionProcessingContinuation(Response, SuppliedSettingsID) Export
	
	If Response <> "Add" Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("SuppliedSettingsID", SuppliedSettingsID);
	
	OpenForm("Catalog.DigitalSignatureAndEncryptionApplications.Form.ItemForm", FormParameters);
	
EndProcedure


&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RequestAttributesAttribute.Name);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RequestAttributesValue.Name);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationAttributesAllAttribute.Name);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RequestAttributesAllValue.Name);
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("StatementAttributes.ThisIsAttributesGroup");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;
	
	Item.Appearance.SetParameterValue("BackColor", New Color(220, 220, 220));
	Item.Appearance.SetParameterValue("Font",
		New Font(Items.RequestAttributesAttribute.Font, , , True,,,, 80));
	
EndProcedure

&AtServer
Procedure SetAgreement()
	
	HTMLText = Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.GetTemplate(
		"Agreement").GetText();
	
	HTMLText = StringFunctionsClientServer.SubstituteParametersInString(HTMLText,
		// Name of certifying center.
		NStr("en='Scientific and production center 1C, LLC';ru='Scientific and production center ""1C"", LLC'"),
		// Address of certification center regulations.
		NStr("en='http://ca.1c.en/reglament.pdf';ru='http://ca.1c.en/reglament.pdf'"),
		// Network of authorized certification centers.
		NStr("en='authorized federal authority on the use of digital signature';ru='уполномоченного федерального органа в области использования электронной подписи'"));
	
	Agreement.SetHTML(HTMLText, New Structure);
	
EndProcedure

&AtServer
Procedure FillAttributesHeaders()
	
	Attributes = GetAttributes();
	For Each Attribute IN Attributes Do
		AttributesHeaders.Add(Attribute.Name, Attribute.Title);
	EndDo;
	
EndProcedure

&AtClient
Procedure WhenApplicationContentOrSettings()
	
	FillApplicationsList();
	
	FillApplication();
	
EndProcedure

&AtServer
Procedure FillApplicationsList()
	
	ApplicationsList.Clear();
	Settings = Catalogs.DigitalSignatureAndEncryptionApplications.SuppliedApllicationSettings();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	application.Ref AS Ref
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionApplications AS application
	|WHERE
	|	application.ApplicationName = &ApplicationName
	|	AND application.ApplicationType = &ApplicationType";
	
	For Each Settings IN Settings Do
		If Settings.ID = "VipNet"
		 Or Settings.ID = "CryptoPro" Then
			
			String = ApplicationsList.Add();
			FillPropertyValues(String, Settings);
			
			Query.SetParameter("ApplicationName", Settings.ApplicationName);
			Query.SetParameter("ApplicationType", Settings.ApplicationType);
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				String.Ref = Selection.Ref;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure FillApplication(Notification = Undefined)
	
	If ValueIsFilled(Object.Application) Then
		AfterSelectingApplication(False, Notification);
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("FirstAddedApplication", Undefined);
	Context.Insert("IndexOf", -1);
	
	FillApplicationCycleStart(Context);
	
EndProcedure

// Continue the procedure FillApplication.
&AtClient
Procedure FillApplicationCycleStart(Context)
	
	If ApplicationsList.Count() <= Context.IndexOf + 1 Then
		If Context.FirstAddedApplication = Undefined Then
			Return;
		EndIf;
		Object.Application = Context.FirstAddedApplication;
		AfterSelectingApplication(False, Context.Notification);
		Return;
	EndIf;
	
	Context.IndexOf = Context.IndexOf + 1;
	Context.Insert("String", ApplicationsList[Context.IndexOf]);
	
	If Context.FirstAddedApplication = Undefined
	   AND ValueIsFilled(Context.String.Ref) Then
		
		Context.FirstAddedApplication = Context.String.Ref;
	EndIf;
	
	DigitalSignatureServiceClient.CreateCryptoManager(New NotifyDescription(
			"FillApplicationCycleAfterCreatingCryptographyManager", ThisObject, Context),
		"", False, Context.String.Ref);
	
EndProcedure

// Continue the procedure CheckCertificate.
&AtClient
Procedure FillApplicationCycleAfterCreatingCryptographyManager(Manager, Context) Export
	
	If TypeOf(Manager) <> Type("CryptoManager") Then
		FillApplicationCycleStart(Context);
		Return;
	EndIf;
	
	Object.Application = Context.String.Ref;
	
	If Context.Notification <> Undefined Then
		ExecuteNotifyProcessing(Context.Notification);
	EndIf;
	
EndProcedure


&AtClient
Procedure AfterSelectingApplication(ShowError, Notification = Undefined)
	
	Cryptography = Undefined;
	
	If Not ValueIsFilled(Object.Application) Then
		If Notification <> Undefined Then
			ExecuteNotifyProcessing(Notification);
		EndIf;
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("ShowError", ShowError);
	Context.Insert("Notification", Notification);
	
	DigitalSignatureServiceClient.CreateCryptoManager(New NotifyDescription(
			"AfterSelectingApplicationAfterCreatingCryptographyManager", ThisObject, Context),
		"", Undefined, Object.Application);
	
EndProcedure

// Continue the procedure AfterSelectingApplication.
&AtClient
Procedure AfterSelectingApplicationAfterCreatingCryptographyManager(Manager, Context) Export
	
	If TypeOf(Manager) <> Type("CryptoManager") Then
		Object.Application = Undefined;
		
		If Context.ShowError Then
			DigitalSignatureServiceClient.ShowRequestToApplicationError(
				NStr("en='Select a digital signature application';ru='Выбор программы электронной подписи'"),, Manager, New Structure);
		EndIf;
		
	EndIf;
	
	If Context.Notification <> Undefined Then
		ExecuteNotifyProcessing(Context.Notification);
	EndIf;
	
EndProcedure


&AtServer
Procedure WriteStatement()
	
	ThisIsNewState = RequestLastStatus <> Object.RequestStatus;
	
	CurrentObject = FormAttributeToValue("Object");
	
	Content = CurrentObject.RequestContent.Get();
	If TypeOf(Content) <> Type("Structure") Then
		Content = New Structure;
	EndIf;
	Content.Insert("HasChanges", ThisIsNewState);
	
	If CurrentObject.RequestStatus = Enums.CertificateIssueRequestState.NotPrepared Then
		CurrentObject.Description = Surname + " " + Name + " " + Patronymic + " (" + NStr("en='Application for new certificate';ru='Заявление на новый сертификат'") + ")";
		// Company.
		UpdateValue(Content, "ThisIsIndividualEntrepreneur");
		UpdateValue(Content, "Company");
		UpdateValue(Content, "AbbreviatedName");
		UpdateValue(Content, "DescriptionFull");
		UpdateValue(Content, "TIN");
		UpdateValue(Content, "OGRN");
		UpdateValue(Content, "BankAccount");
		UpdateValue(Content, "BIN");
		UpdateValue(Content, "CorrespondentAccount");
		UpdateValue(Content, "LegalAddress");
		UpdateValue(Content, "LegalAddressXML");
		UpdateValue(Content, "ActualAddress");
		UpdateValue(Content, "ActualAddressXML");
		UpdateValue(Content, "Phone");
		UpdateValue(Content, "PhoneXML");
		// Owner.
		UpdateValue(Content, "OwnerKind");
		UpdateValue(Content, "Chiefexecutive");
		UpdateValue(Content, "ChiefAccountant");
		UpdateValue(Content, "Employee");
		UpdateValue(Content, "Surname");
		UpdateValue(Content, "Name");
		UpdateValue(Content, "Patronymic");
		UpdateValue(Content, "InsuranceNumberRPF");
		UpdateValue(Content, "Position");
		UpdateValue(Content, "DocumentKind1");
		UpdateValue(Content, "DocumentNumber");
		UpdateValue(Content, "DocumentWhoIssued");
		UpdateValue(Content, "DocumentIssueDate");
		UpdateValue(Content, "Email");
		UpdateValue(Content, "Department");
		// Saving of filled values if applicable.
		UpdateValue(Content, "Application", Object.Application);
		UpdateValue(Content, "ApplicationPresentation");
		UpdateValue(Content, "KeyContainerName");
		UpdateValue(Content, "KeyContainerPath");
		
	ElsIf CurrentObject.RequestStatus = Enums.CertificateIssueRequestState.Prepared Then
		If ThisIsNewState Then
			UpdateValue(Content, "Application", Object.Application);
			UpdateValue(Content, "ApplicationPresentation");
			UpdateValue(Content, "KeyContainerName");
			UpdateValue(Content, "KeyContainerPath");
			UpdateValue(Content, "CertificateQuery", GetFromTempStorage(RequestAddressForCertificate));
			UpdateValue(Content, "DSKeyPublicPart");
			UpdateValue(Content, "SubjectKeyIdentifier");
			UpdateValue(Content, "DocumentsCertificateFields");
			UpdateValue(Content, "RequestDate");
		EndIf;
		// Saving of filled values if applicable.
		UpdateValue(Content, "DocumentsHead");
		UpdateValue(Content, "DocumentsHeadRef");
		UpdateValue(Content, "DocumentsHeadPosition");
		UpdateValue(Content, "DocumentsHeadBasis");
		UpdateValue(Content, "DocumentsPartner");
		UpdateValue(Content, "DocumentsPartnerRef");
		UpdateValue(Content, "DocumentsPartnerIsIE");
		UpdateValue(Content, "DocumentsPartnerTIN");
		UpdateValue(Content, "DocumentsPrinted");
		
	ElsIf CurrentObject.RequestStatus = Enums.CertificateIssueRequestState.Sent Then
		If ThisIsNewState Then
			UpdateValue(Content, "DocumentManagementIdentifier");
			UpdateValue(Content, "SendingDate");
			UpdateValue(Content, "DocumentsHead");
			UpdateValue(Content, "DocumentsHeadRef");
			UpdateValue(Content, "DocumentsHeadPosition");
			UpdateValue(Content, "DocumentsHeadBasis");
			UpdateValue(Content, "DocumentsPartner");
			UpdateValue(Content, "DocumentsPartnerRef");
			UpdateValue(Content, "DocumentsPartnerIsIE");
			UpdateValue(Content, "DocumentsPartnerTIN");
		EndIf;
		UpdateValue(Content, "UpdateDateConditions");
		UpdateValue(Content, "RequestProcessingState");
		
	ElsIf CurrentObject.RequestStatus = Enums.CertificateIssueRequestState.ExecutedCertificateNotInstalled Then
		If ThisIsNewState Then
			UpdateValue(Content, "RootCertificateImprint");
			UpdateValue(Content, "Certificate",         GetFromTempStorage(CertificateAddress));
			UpdateValue(Content, "RootCertificate", GetFromTempStorage(RootCertificateAddress));
			UpdateValue(Content, "SubscriberIdentifier");
			UpdateValue(Content, "UpdateDateConditions");
			UpdateValue(Content, "RequestProcessingState");
			If CurrentObject.CertificateData.Get() <> Content.Certificate Then
				CurrentObject.CertificateData = New ValueStorage(Content.Certificate);
				Content.HasChanges = True;
			EndIf;
		EndIf;
		UpdateValue(Content, "ErrorCertificateSetup");
		UpdateValue(Content, "DateCertificateInstallation");
		
	ElsIf CurrentObject.RequestStatus = Enums.CertificateIssueRequestState.Rejected Then
		If ThisIsNewState Then
			UpdateValue(Content, "UpdateDateConditions");
			UpdateValue(Content, "RequestProcessingState");
			NewDescription = Surname + " " + Name + " " + Patronymic + " (" + NStr("en='Delete';ru='Удалить'") + ")";
			If CurrentObject.Description <> NewDescription Then
				CurrentObject.Description = NewDescription;
				Content.HasChanges = True;
			EndIf;
		EndIf;
		
	ElsIf CurrentObject.RequestStatus = Enums.CertificateIssueRequestState.Executed Then
		If ThisIsNewState Then
			UpdateValue(Content, "ErrorCertificateSetup");
			UpdateValue(Content, "DateCertificateInstallation");
			Content.HasChanges = True;
		EndIf;
	EndIf;
	
	If Content.HasChanges Then
		Content.Delete("HasChanges");
		CurrentObject.RequestContent = New ValueStorage(Content);
		IsNew = CurrentObject.IsNew();
		CurrentObject.Write();
		ValueToFormAttribute(CurrentObject, "Object");
		NotifyOnStatementsChange = True;
	EndIf;
	RequestLastStatus = Object.RequestStatus;
	
	Items.AgreementApproval.ReadOnly = True;
	
	If IsNew Then
		LockDataForEdit(CurrentObject.Ref, , UUID);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateValue(Content, PropertyName, Value = null);
	
	If Value = Null Then
		Value = ThisObject[PropertyName];
	EndIf;
	
	If Content.Property(PropertyName) AND Content[PropertyName] = Value Then
		Return;
	EndIf;
	
	Content.HasChanges = True;
	Content.Insert(PropertyName, Value);
	
EndProcedure

&AtClient
Procedure AfterWrite(NotificationText = "")
	
	If Not NotifyOnStatementsChange Then
		Return;
	EndIf;
	
	NotifyChanged(Object.Ref);
	
	Context = New Structure;
	If IsNew Then
		Context.Insert("IsNew");
	EndIf;
	Notify("Record_DigitalSignaturesAndEncryptionKeyCertificates", Context, Object.Ref);
	
	If Not ValueIsFilled(NotificationText) Then
		NotificationText = NStr("en='Application is saved.';ru='Заявление сохранено.'");
	EndIf;
	
	ShowUserNotification(NotificationText);
	
	NotifyOnStatementsChange = False;
	
EndProcedure

&AtServer
Procedure WriteAndUnlockObject()
	
	WriteStatement();
	UnlockObject(Object.Ref, UUID);
	
EndProcedure

&AtServerNoContext
Procedure UnlockObject(Refs, FormID)
	
	UnlockDataForEdit(Refs, FormID);
	
EndProcedure


// Creation of a key and a certificate request.

&AtClient
Procedure CreateKeyAndCertificateQuery(Notification)
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	If Cryptography <> Undefined Then
		CreateKeyAndCertificateQueryAfterCreatingCryptographyObject(True, Context);
	Else
		CreateCryptographyObject(New NotifyDescription(
			"CreateKeyAndCertificateQueryAfterCreatingCryptographyObject", ThisObject, Context),
			NStr("en='To create digital signature key and certificate
		|query, it is required to install extension for web client 1C:Enterprise.';ru='Для создания ключа электронной подписи
		|и запроса на сертификат требуется установить расширение для веб-клиента 1С:Предприятия.'"),
			NStr("en='To create a digital signature key and a certificate request, install an additional external component.';ru='Для создания ключа электронной подписи и запроса на сертификат требуется установить дополнительную внешнюю компоненту.'"));
	EndIf;
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterCreatingCryptographyObject(Result, Context) Export
	
	If Result <> True Then
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	CheckKeyContainerExistence(New NotifyDescription(
			"CreateKeyAndCertificateQueryAfterKeyContainerExistenceCheck", ThisObject, Context),
		KeyContainerPath, KeyContainerName);
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterKeyContainerExistenceCheck(Exists, Context) Export
	
	If Exists Then
		ShowUserNotification(NStr("en='Previously created key container is used:';ru='Используется ранее созданный контейнер ключа:'"),,
			KeyContainerPath);
		
		CreateKeyAndCertificateQueryAfterKeyContainerPreparation(Context);
	Else
		GetNewKeyContainerName(New NotifyDescription(
			"CreateKeyAndCertificateQueryAfterObtainingNewKeyContainerName", ThisObject, Context));
	EndIf;
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterObtainingNewKeyContainerName(KeyContainerNewName, Context) Export
	
	ActiveWindow().Activate();
	
	Context.Insert("KeyContainerNewName", KeyContainerNewName);
	
	Cryptography.StartCallCreateContainer(New NotifyDescription(
			"CreateKeyAndCertificateQueryAfterCallCreateContainer", ThisObject, Context,
			"CreateKeyAndCertificateQueryAfterCallErrorCreateContainer", ThisObject),
		KeyContainerNewName);
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterCallErrorCreateContainer(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	Error = New Structure;
	Error.Insert("ShowInstruction", True);
	Error.Insert("ErrorDescription", StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Operation failed due
		|to:% 1';ru='Не удалось
		|выполнить операцию по причине: %1'"),
		BriefErrorDescription(ErrorInfo)));
	
	DigitalSignatureServiceClient.ShowRequestToApplicationError(
		NStr("en='Create DS key';ru='Создание ключа электронной подписи'"),, Error, New Structure);
	
	ExecuteNotifyProcessing(Context.Notification, False);
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterCallCreateContainer(Path, CallParameters, Context) Export
	
	ActiveWindow().Activate();
	
	If Not ValueIsFilled(Path) Then
		Rows = ApplicationsList.FindRows(New Structure("Ref", Object.Application));
		If Rows[0].ID = "CryptoPro" Then
			ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Digital signature key is not created.
		|
		|It should be taken into account that in order
		|to create a key with application %1, administrator rights of the operating system are required.';ru='Ключ электронной подписи не создан.
		|
		|Следует учитывать, что для создания
		|ключа с помощью программы %1, требуются права администратора операционной системы.'"),
				Rows[0].Presentation));
		Else
			ShowMessageBox(,
				NStr("en='Digital signature key is not created.';ru='Ключ электронной подписи не создан.'"));
		EndIf;
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	KeyContainerName  = Context.KeyContainerNewName;
	KeyContainerPath = Path;
	WriteStatement();
	
	ShowUserNotification(NStr("en='New key container is created:';ru='Создан новый контейнер ключа:'"),, KeyContainerPath);
	
	CreateKeyAndCertificateQueryAfterKeyContainerPreparation(Context);
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterKeyContainerPreparation(Context)
	
	GetTemporaryFilesDirectoryComponents(New NotifyDescription(
		"CreateKeyAndCertificateQueryAfterObtainingComponentTemporaryFilesDirectory", ThisObject, Context));
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterObtainingComponentTemporaryFilesDirectory(Folder, Context) Export
	
	Context.Insert("QueryFileName", Folder + KeyContainerName + ".p10");
	
	Context.Insert("FilesToPlace", New Array);
	Context.FilesToPlace.Add(New TransferableFileDescription(Context.QueryFileName));
	
	Calls = New Array;
	AddCall(Calls, "BeginPuttingFiles", Context.FilesToPlace, , False, UUID, );
	AddCall(Calls, "BeginDeletingFiles",  Context.QueryFileName, , , , );
	
	BeginRequestingUserPermission(New NotifyDescription(
		"CreateKeyAndCertificateQueryAfterObtainingPermissions", ThisObject, Context), Calls);
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterObtainingPermissions(PermissionsReceived, Context) Export
	
	If Not PermissionsReceived Then
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	Context.Insert("CertificateFields", Undefined);
	QueryDescription = QueryDescriptionOnQualifiedCertificate(Context.CertificateFields);
	QualifiedDSFlag = 67108864;
	
	ActiveWindow().Activate();
	
	Context.Insert("QueryCreated", True);
	
	Cryptography.StartCallCreateCertificateQuery(New NotifyDescription(
			"CreateKeyAndCertificateQueryAfterCallCreateCertificateQuery", ThisObject, Context,
			"CreateKeyAndCertificateQueryAfterCallErrorCreateCertificateQuery", ThisObject),
		QueryDescription, KeyContainerPath, Context.QueryFileName, QualifiedDSFlag);
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterCallErrorCreateCertificateQuery(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	CreateKeyAndCertificateQueryEnd(Context, ErrorInfo,
		NStr("en='Cannot execute the operation due to:';ru='Не удалось выполнить операцию по причине:'"));
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterCallCreateCertificateQuery(Result, CallParameters, Context) Export
	
	If Result <> True Then
		Context.QueryCreated = False;
		CreateKeyAndCertificateQueryEnd(Context);
		Return;
	EndIf;
	ActiveWindow().Activate();
	
	File = New File;
	File.BeginInitialization(New NotifyDescription(
			"CreateKeyAndCertificateQueryAfterFileInitialization", ThisObject, Context),
		Context.QueryFileName);
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterFileInitialization(File, Context) Export
	
	Context.Insert("File", File);
	
	Context.File.StartExistenceCheck(New NotifyDescription(
		"CreateKeyAndCertificateQueryAfterFileExistenceCheck", ThisObject, Context));
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterFileExistenceCheck(Exists, Context) Export
	
	If Not Exists Then
		Context.QueryCreated = False;
		CreateKeyAndCertificateQueryEnd(Context);
		Return;
	EndIf;
	
	Context.File.BeginGettingSize(New NotifyDescription(
		"CreateKeyAndCertificateQueryAfterObtainingFileSize", ThisObject, Context));
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterObtainingFileSize(Size, Context) Export
	
	If Size = 0 Then
		Context.QueryCreated = False;
		CreateKeyAndCertificateQueryEnd(Context);
		Return;
	EndIf;
	
	Cryptography.StartCallGetOpenKey(New NotifyDescription(
			"CreateKeyAndCertificateQueryAfterCallGetOpenKey", ThisObject, Context,
			"CreateKeyAndCertificateQueryAfterCallErrorGetOpenKey", ThisObject),
		Context.QueryFileName);
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterCallErrorGetOpenKey(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	CreateKeyAndCertificateQueryEnd(Context, ErrorInfo,
		NStr("en='Cannot receive a public key part due to:';ru='Не удалось получить открытую часть ключа по причине:'"));
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterCallGetOpenKey(Result, CallParameters, Context) Export
	
	Context.Insert("CurrentDSKeyOpenPart", Result);
	
	Cryptography.StartCallCalculateSubjectKeyIdentifier(New NotifyDescription(
			"CreateKeyAndCertificateQueryAfterCallCalculateEntityKeyIdentifier", ThisObject, Context,
			"CreateKeyAndCertificateQueryAfterCallErrorCalculateEntityKeyIdentifier", ThisObject),
		Context.QueryFileName);
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterCallErrorCalculateEntityKeyIdentifier(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	CreateKeyAndCertificateQueryEnd(Context, ErrorInfo,
		NStr("en='Cannot calculate the subject key ID due to:';ru='Не удалось вычислить идентификатор ключа субъекта по причине:'"));
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterCallCalculateEntityKeyIdentifier(Result, CallParameters, Context) Export
	
	Context.Insert("CurrentX", Result);
	
	BeginPuttingFiles(New NotifyDescription(
			"CreateKeyAndCertificateQueryAfterFilesPlacement", ThisObject, Context),
		Context.FilesToPlace, , False, UUID);
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterFilesPlacement(PlacedFiles, Context) Export
	
	If Not ValueIsFilled(PlacedFiles) Then
		Context.QueryCreated = False;
		CreateKeyAndCertificateQueryEnd(Context);
		Return;
	EndIf;
	
	RequestAddressForCertificate   = PlacedFiles[0].Location;
	DSKeyPublicPart       = BinaryDataPresentation(Context.CurrentDSKeyOpenPart);
	SubjectKeyIdentifier = BinaryDataPresentation(Context.CurrentX);
	DocumentsCertificateFields   = Context.CertificateFields;
	RequestDate = Format(CommonUseClient.SessionDate(), "DF=dd.MM.yyyy");
	
	CreateKeyAndCertificateQueryEnd(Context);
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryEnd(Context, ErrorInfo = Undefined, ErrorTitle = "")
	
	If ErrorInfo <> Undefined Then
		Context.QueryCreated = False;
		Error = New Structure;
		Error.Insert("ShowInstruction", True);
		Error.Insert("ErrorDescription", ErrorTitle
			+ Chars.LF + BriefErrorDescription(ErrorInfo));
		
		DigitalSignatureServiceClient.ShowRequestToApplicationError(
			NStr("en='Create certificate request';ru='Создание запроса на сертификат'"),, Error, New Structure);
		
	ElsIf Not Context.QueryCreated Then
		ShowMessageBox(, NStr("en='Certificate request is not created.';ru='Запрос на сертификат не создан.'"));
	EndIf;
	
	If Context.Property("File") Then
		Context.File.StartExistenceCheck(New NotifyDescription(
			"CreateKeyAndCertificateQueryAfterFileForRemovalExistenceCheck", ThisObject, Context));
	Else
		CreateKeyAndCertificateQueryAfterDeletingFiles(Context);
	EndIf;
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterFileForRemovalExistenceCheck(Exists, Context) Export
	
	If Exists Then
		BeginDeletingFiles(New NotifyDescription(
				"CreateKeyAndCertificateQueryAfterDeletingFiles", ThisObject, Context),
			Context.QueryFileName);
	Else
		CreateKeyAndCertificateQueryAfterDeletingFiles(Context);
	EndIf;
	
EndProcedure

// Continue the procedure CreateKeyAndCertificateQuery.
&AtClient
Procedure CreateKeyAndCertificateQueryAfterDeletingFiles(Context) Export
	
	ExecuteNotifyProcessing(Context.Notification, Context.QueryCreated);
	
EndProcedure


&AtClient
Procedure CheckKeyContainerExistence(Notification, PathAfterCreation, NameForCreation)
	
	Context = New Structure;
	Context.Insert("Notification",        Notification);
	Context.Insert("PathAfterCreation", PathAfterCreation);
	Context.Insert("NameForCreation",    NameForCreation);
	
	If Not ValueIsFilled(Context.PathAfterCreation) Then
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	GetKeyContainerNames(New NotifyDescription(
		"CheckKeyContainerExistenceAfterObtainingContainerNames", ThisObject, Context));
	
EndProcedure

// Continue the procedure CheckKeyContainerExistence.
&AtClient
Procedure CheckKeyContainerExistenceAfterObtainingContainerNames(KeyContainerNames, Context) Export
	
	Rows = ApplicationsList.FindRows(New Structure("Ref", Object.Application));
	
	If Rows[0].ID = "CryptoPro" Then
		ExecuteNotifyProcessing(Context.Notification,
			Find(KeyContainerNames, Context.NameForCreation) > 0);
		Return;
	EndIf;
	
	Position = Find(Context.PathAfterCreation, ":.");
	If Position = 0 Then
		ExecuteNotifyProcessing(Context.Notification,
			Find(KeyContainerNames, Context.NameForCreation) > 0);
		Return;
	EndIf;
	
	NameAfterCreation = Left(Context.PathAfterCreation, Position - 1);
	
	If Find(KeyContainerNames, NameAfterCreation) > 0 Then
		ExecuteNotifyProcessing(Context.Notification, True);
		Return;
	EndIf;
	
	Position = Find(NameAfterCreation, "\Infotecs\Containers\");
	If Position = 0 Then
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	// ViPNet 3.2 (main folder of containers is not indicated).
	NameAfterCreation = Mid(NameAfterCreation, Position);
	
	ExecuteNotifyProcessing(Context.Notification,
		Find(KeyContainerNames, NameAfterCreation) > 0);
	
EndProcedure


&AtClient
Procedure GetNewKeyContainerName(Notification)
	
	// Date is used only to create a unique name, that is why computer clock is required.
	Date = CurrentDate(); // Do not change to session current date.
	
	CreationDate = Format(Date, "DF=yyyy-MM-dd") + " " + Format(Date, "DF=HH") + "-" + Format(Date, "DF=mm");
	
	If ThisIsIndividualEntrepreneur Then
		// With<Name>, Sole Proprietor".
		Subject = PrepareRowForContainerName(Surname) + " "
			+ PrepareRowForContainerName(Name) + ", "
			+ NStr("en='Individual entrepreneur';ru='Индивидуальный предприниматель'");
	Else
		// With<Name>, <Company short name>".
		Subject = PrepareRowForContainerName(Surname) + " "
			+ PrepareRowForContainerName(Name) + ", "
			+ PrepareRowForContainerName(AbbreviatedName);
	EndIf;
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("NewName1",  CreationDate + ", " + Left(Subject, 60));
	Context.Insert("NewName2",  CreationDate + "-" + Format(Date, "DF=cc") + ", " + Left(Subject, 57));
	
	GetKeyContainerNames(New NotifyDescription(
		"GetNewKeyContainerNameAfterObtainingContainerNames", ThisObject, Context));
	
EndProcedure

// Continue the procedure GetNewKeyContainerName.
&AtClient
Procedure GetNewKeyContainerNameAfterObtainingContainerNames(KeyContainerNames, Context) Export
	
	NewName = Context.NewName1;
	
	If Find(KeyContainerNames, NewName) > 0 Then
		NewName = Context.NewName2;
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, NewName);
	
EndProcedure


&AtClient
Function PrepareRowForContainerName(String, ReplacementGap = Undefined)
	
	CharactersReplacement = New Map;
	CharactersReplacement.Insert("\", " ");
	CharactersReplacement.Insert("/", " ");
	CharactersReplacement.Insert("*", " ");
	CharactersReplacement.Insert("<", " ");
	CharactersReplacement.Insert(">", " ");
	CharactersReplacement.Insert("|", " ");
	CharactersReplacement.Insert(":", "");
	CharactersReplacement.Insert("""", "");
	CharactersReplacement.Insert("?", "");
	CharactersReplacement.Insert(Chars.CR, "");
	CharactersReplacement.Insert(Chars.LF, " ");
	CharactersReplacement.Insert(Chars.Tab, " ");
	CharactersReplacement.Insert(Chars.NBSp, " ");
	// Replacement of quotation marks characters.
	CharactersReplacement.Insert(Char(171), "");
	CharactersReplacement.Insert(Char(187), "");
	CharactersReplacement.Insert(Char(8195), "");
	CharactersReplacement.Insert(Char(8194), "");
	CharactersReplacement.Insert(Char(8216), "");
	CharactersReplacement.Insert(Char(8218), "");
	CharactersReplacement.Insert(Char(8217), "");
	CharactersReplacement.Insert(Char(8220), "");
	CharactersReplacement.Insert(Char(8222), "");
	CharactersReplacement.Insert(Char(8221), "");
	
	RowPrepared = "";
	
	CharCount = StrLen(String);
	
	For CharacterNumber = 1 To CharCount Do
		Char = Mid(String, CharacterNumber, 1);
		If CharactersReplacement[Char] <> Undefined Then
			Char = CharactersReplacement[Char];
		EndIf;
		RowPrepared = RowPrepared + Char;
	EndDo;
	
	If ReplacementGap <> Undefined Then
		RowPrepared = StrReplace(ReplacementGap, " ", ReplacementGap);
	EndIf;
	
	Return TrimAll(RowPrepared);
	
EndFunction

&AtClientAtServerNoContext
Function BinaryDataPresentation(Val String, ByteInRow = 20)
	
	RemainingString = Lower(StrReplace(String, " ", ""));
	Presentation = "";
	BytesInCurrentRow = 0;
	
	While ValueIsFilled(RemainingString) Do
		Presentation = Presentation + Left(RemainingString, 2) + " ";
		RemainingString = Mid(RemainingString, 3);
		BytesInCurrentRow = BytesInCurrentRow + 1;
		If BytesInCurrentRow = ByteInRow Then
			Presentation = TrimAll(Presentation) + Chars.LF;
			BytesInCurrentRow = 0;
		EndIf;
	EndDo;
	
	Return TrimAll(Presentation);
	
EndFunction

&AtClient
Function QueryDescriptionOnQualifiedCertificate(Fields)
	
	ListOfParameters = New ValueList;
	Fields = New Structure;
	
	If ThisIsIndividualEntrepreneur Then
		Address = LegalAddressStructure; // Sole proprietor registration address.
	Else
		Address = ActualAddressStructure;  // Address of a legal entity.
	EndIf;
	
	// Field CN - common name (company or sole proprietor).
	If ThisIsIndividualEntrepreneur Then
		CN = StrReplace(Surname, " ", "_") + " " + StrReplace(Name, " ", "_") + " " + StrReplace(Patronymic, " ", "_");
	Else
		CN = AbbreviatedName;
	EndIf;
	Fields.Insert("CN", Left(CN, 64));
	ListOfParameters.Add("2.5.4.3", Fields.CN);
		
	
	// Field SN - last name of official or sole proprietor.
	SN = StrReplace(Surname, " ", "_");
	Fields.Insert("SN", Left(SN, 64));
	ListOfParameters.Add("2.5.4.4", Fields.SN);
	
	// Field G - name and patronymic of the official or sole proprietor.
	G = StrReplace(Name, " ", "_") + " " + StrReplace(Patronymic, " ", "_");
	Fields.Insert("G", Left(G, 64));
	ListOfParameters.Add("2.5.4.42", Fields.G);
	
	// Field C - country.
	Fields.Insert("C", "EN");
	ListOfParameters.Add("2.5.4.6", Fields.C);
	
	// Following fields S, L, Street - company address or sole proprietor registrated address.
	
	// Field S (ST) - State (<state code> <state name>) - name of a territorial
	// entity of the RF for DSVKC, for example, "77, Moscow".
	S = Address.StateCode + " " + RFStateNameByRecommendationsForDSVKC(Address.StateCode);
	Fields.Insert("S", Left(S, 128));
	ListOfParameters.Add("2.5.4.8", Fields.S);
	
	// Field L - settlement (<region> and/or <city> and/or <settlement>).
	// For example, "g. Moscow, g. Zelenograd, p. Kryukovo" "g. Moscow, g. Zelenograd, p. Kryukovo".
	L = SettlementEntirely(Address);
	Fields.Insert("L", Left(L, 128));
	ListOfParameters.Add("2.5.4.7", Fields.L);
	
	// Field Street - street, building, office.
	Street = "";
	If CommonUseClient.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactInformationManagementClientServer = CommonUseClient.CommonModule(
			"ContactInformationManagementClientServer");
	
		Structure = New Structure("Street, StreetShort, House, HouseType, Block, BlockType, Apartment, ApartmentType");
		FillPropertyValues(Structure, Address);
		ModuleContactInformationManagementClientServer.GenerateAddressPresentation(Structure, Street);
	EndIf;
	Fields.Insert("Street", Left(Street, 128));
	ListOfParameters.Add("2.5.4.9", Fields.Street);
	
	If ThisIsIndividualEntrepreneur Then
		// Field OGRNIP - PSRNSP of sole proprietor, 15 characters.
		Fields.Insert("OGRNIP", OGRN);
		ListOfParameters.Add("1.2.643.100.5", Fields.OGRNIP);
	Else
		// Field O - company.
		Fields.Insert("O", Left(AbbreviatedName, 64));
		ListOfParameters.Add("2.5.4.10", Fields.O);
		
		// Field OU - a separate department of an official.
		If ValueIsFilled(Department) Then
			Fields.Insert("OU", Left(Department, 64));
			ListOfParameters.Add("2.5.4.11", Fields.OU);
		EndIf;
		
		// Field T - employee position.
		Fields.Insert("T", Left(Position, 64));
		ListOfParameters.Add("2.5.4.12", Fields.T);
		
		// Field OGRN - PSRN of legal entity, 13 characters.
		Fields.Insert("OGRN", OGRN);
		ListOfParameters.Add("1.2.643.100.1", Fields.OGRN);
	EndIf;
	
	// Field SNILS - INILA of official or sole proprietor.
	Fields.Insert("SNILS", InsuranceNumberRPF);
	ListOfParameters.Add("1.2.643.100.3", Fields.SNILS);
	
	// Field TIN - TIN of company or sole proprietor.
	Fields.Insert("TIN", Right("00" + TIN, 12));
	ListOfParameters.Add("1.2.643.3.131.1.1", Fields.TIN);
	
	// Field E - email of company official or sole proprietor.
	Fields.Insert("E", Left(Email, 128));
	ListOfParameters.Add("1.2.840.113549.1.9.1", Fields.E);
	
	// Preparation of query row.
	
	Properties = "";
	For Each Parameter IN ListOfParameters Do 
		Properties = Properties + ",<" + Parameter.Value + "=" + TrimAll(Parameter.Presentation) + ">";
	EndDo;
	Properties = Mid(Properties, 2);
	
	// Key usage - Verification of client authenticity, Protected email.
	KeyUsage = "1.3.6.1.5.5.7.3.2,1.3.6.1.5.5.7.3.4"; 
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		"pRequestInfo:{ CertAttrs:{%1} CertEnhKeyUsage:{%2} CertPolicies:{<1.2.643.100.113.1=>} dwKeyUsage:{240} SignTool:{%3} }",
		Properties,
		KeyUsage,
		ApplicationPresentation);
	
EndFunction


&AtClient
Procedure GetKeyContainerNames(Notification)
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("ListOfNames", New ValueList);
	Context.Insert("FirstPass", True);
	Context.Insert("IndexOf", -1);
	
	GetKeyContainerNamesCycleBeginning(Context);
	
EndProcedure

// Continue the procedure GetKeyContainerNames.
&AtClient
Procedure GetKeyContainerNamesCycleBeginning(Context)
	
	Context.Insert("CurrentName", "");
	
	Cryptography.StartCallGetNextKeyContainer(New NotifyDescription(
			"GetKeyContainerNamesCycleAfterCallGetNextKeyContainer", ThisObject, Context),
		Context.CurrentName, Context.FirstPass);
	
EndProcedure

// Continue the procedure GetKeyContainerNames.
&AtClient
Procedure GetKeyContainerNamesCycleAfterCallGetNextKeyContainer(Result, CallParameters, Context) Export
	
	If Not Result Then
		If Context.FirstPass Then
			Context.FirstPass = False;
			GetKeyContainerNamesCycleBeginning(Context);
		Else
			names = "";
			For Each ItemOfList IN Context.ListOfNames Do
				UniqueName = ItemOfList.Value;
				
				If UniqueName = ItemOfList.Presentation
				   AND Find(UniqueName, "/") = 0
				   AND Find(UniqueName, "\") = 0
				   AND Find(UniqueName, ":") = 0 Then
					
					// ViPNet 3.2 (main folder of containers is not indicated).
					UniqueName = "\Infotecs\Containers\" + UniqueName;
				EndIf;
				
				names = names + Chars.LF + UniqueName;
				names = names + Chars.LF + ItemOfList.Presentation;
				names = names + Chars.LF;
			EndDo;
			ExecuteNotifyProcessing(Context.Notification, TrimAll(names));
		EndIf;
		Return;
	EndIf;
	
	CurrentName = CallParameters[0];
	
	If Context.FirstPass Then
		Context.ListOfNames.Add(CurrentName);
	Else
		Context.IndexOf = Context.IndexOf + 1;
		Context.ListOfNames[Context.IndexOf].Presentation = CurrentName;
	EndIf;
	
	GetKeyContainerNamesCycleBeginning(Context);
	
EndProcedure


&AtClient
Procedure CreateCryptographyObject(ContinuationProcessor, ExtensionPurposeForFileOperations, CryptographyExternalComponentFunction)
	
	Context = New Structure;
	Context.Insert("ContinuationProcessor", ContinuationProcessor);
	Context.Insert("CryptographyExternalComponentFunction", CryptographyExternalComponentFunction);
	
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(
		New NotifyDescription("CreateCryptographyObjectAfterConnectingFilesExtension",
			ThisObject, Context),
		ExtensionPurposeForFileOperations,
		False);
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateCryptographyObjectAfterConnectingFilesExtension(Result, Context) Export
	
	If Result <> True Then
		ExecuteNotifyProcessing(Context.ContinuationProcessor, False);
		Return;
	EndIf;
	
	Context.Insert("Path", "Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Template.ExchangeComponent");
	Context.Insert("Name", "EDFNative");
	
	BeginAttachingAddIn(New NotifyDescription(
			"CreateCryptographyObjectAfterConnectingExternalComponent", ThisObject, Context),
		Context.Path, Context.Name);
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateCryptographyObjectAfterConnectingExternalComponent(Connected, Context) Export
	
	If Connected Then
		CreateCryptographyObjectContinuation(Context);
	Else
		Buttons = New ValueList;
		Buttons.Add("Set",      NStr("en='Set';ru='Установить'"));
		Buttons.Add("DoNotInstall", NStr("en='Do not set';ru='Не устанавливать'"));
		ShowQueryBox(New NotifyDescription(
				"CreateCryptographyObjectAfterAnswerToQuestion", ThisObject, Context),
			Context.CryptographyExternalComponentFunction, Buttons, , "Set");
	EndIf;
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateCryptographyObjectAfterAnswerToDoQueryBox(Response, Context) Export
	
	If Response <> "Set" Then
		ExecuteNotifyProcessing(Context.ContinuationProcessor, False);
		Return;
	EndIf;
	
	BeginInstallAddIn(New NotifyDescription(
			"CreateCryptographyObjectAfterInstallingExternalComponent", ThisObject, Context,
			"CreateCryptographyObjectAfterExternalComponentInstallationError", ThisObject),
		Context.Path);
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateCryptographyObjectAfterExternalComponentInstallationError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	ShowMessageBox(New NotifyDescription(
			"CreateCryptographyObjectAfterErrorWarning", ThisObject, Context),
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to install additional external component
		|due to: %1';ru='Не удалось установить дополнительную внешнюю
		|компоненту по причине: %1'"),
			BriefErrorDescription(ErrorInfo)));
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateCryptographyObjectAfterInstallingExternalComponent(Context) Export
	
	BeginAttachingAddIn(New NotifyDescription(
			"CreateCryptographyObjectAfterConnectingInstalledExternalComponent", ThisObject, Context),
		Context.Path, Context.Name);
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateCryptographyObjectAfterConnectingInstalledExternalComponent(Connected, Context) Export
	
	If Not Connected Then
		ShowMessageBox(
			New NotifyDescription("CreateCryptographyObjectAfterErrorWarning",
				ThisObject, Context),
			NStr("en='Cannot connect an additional external component.';ru='Не удалось подключить дополнительную внешнюю компоненту.'"));
	Else
		CreateCryptographyObjectContinuation(Context);
	EndIf;
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateCryptographyObjectContinuation(Context)
	
	Try
		Cryptography = New("Addin.EDFNative.CryptS");
	Except
		ErrorInfo = ErrorInfo();
		Cryptography = Undefined;
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to create a cryptography object of external component
		|due to:% 1';ru='Не удалось создать объект внешней компоненты для
		|работы с криптографией по причине: %1'"),
			BriefErrorDescription(ErrorInfo)));
		ExecuteNotifyProcessing(Context.ContinuationProcessor, False);
		Return;
	EndTry;
	
	If WorkWithBinaryData = Undefined Then
		Try
			WorkWithBinaryData = New("Addin.EDFNative.BinaryDataS");
		Except
			ErrorInfo = ErrorInfo();
			Cryptography = Undefined;
			ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Failed to create an object of external component for binary data
		|due to: %1';ru='Не удалось создать объект внешней компоненты для работы с
		|двоичными данными по причине: %1'"),
				BriefErrorDescription(ErrorInfo)));
			ExecuteNotifyProcessing(Context.ContinuationProcessor, False);
			Return;
		EndTry;
	EndIf;
	
	Cryptography.StartInstallationDoNotShowErrorMessages(New NotifyDescription(
			"CreateCryptographyObjectAfterInstallationDoNotShowErrorMessages", ThisObject, Context),
		True);
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateCryptographyObjectAfterInstallationDoNotShowErrorMessages(Context) Export
	
	Rows = ApplicationsList.FindRows(New Structure("Ref", Object.Application));
	ApplicationName = Rows[0].ApplicationName;
	ApplicationType = Rows[0].ApplicationType;
	PathToApplication = String(DigitalSignatureClientServer.PersonalSettings(
		).PathToDigitalSignatureAndEncryptionApplications.Get(Object.Application));
	
	Cryptography.StartCallCreateCryptographyManager(New NotifyDescription(
			"CreateCryptographyObjectAfterCallCreateCryptographyManager", ThisObject, Context,
			"CreateCryptographyObjectAfterCallErrorCreateCryptographyManager", ThisObject),
		ApplicationName, PathToApplication, ApplicationType);
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateCryptographyObjectAfterCallErrorCreateCryptographyManager(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	Cryptography = Undefined;
	
	ShowMessageBox(New NotifyDescription(
			"CreateCryptographyObjectAfterErrorWarning", ThisObject, Context),
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Digital signature application is not available through an
		|external component due to: %1';ru='Программа электронной подписи не доступна
		|через внешнюю компоненту по причине: %1'"),
			BriefErrorDescription(ErrorInfo)));
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateCryptographyObjectAfterCallCreateCryptographyManager(Result, CallParameters, Context) Export
	
	ExecuteNotifyProcessing(Context.ContinuationProcessor, True);
	
EndProcedure

// Continue the procedure CreateCryptographyObject.
&AtClient
Procedure CreateCryptographyObjectAfterErrorDoMessageBox(Context) Export
	
	ExecuteNotifyProcessing(Context.ContinuationProcessor, False);
	
EndProcedure

// Creation of temporary files directory for ExtIntgr component.

&AtClient
Procedure GetTemporaryFilesDirectoryComponents(Notification)
	
	Context = New Structure("Notification", Notification);
	
	WorkWithBinaryData.StartCallGetTemporaryFilesDirectory(New NotifyDescription(
			"GetTemporaryFilesDirectoryComponentsAfterCalling", ThisObject, Context));
	
EndProcedure

// Continue the procedure GetTemporaryFilesDirectoryComponents.
&AtClient
Procedure GetTemporaryFilesDirectoryComponentsAfterCalling(Folder, CallParameters, Context) Export
	
	ExecuteNotifyProcessing(Context.Notification,
		CommonUseClientServer.AddFinalPathSeparator(Folder));
	
EndProcedure

#EndRegion
