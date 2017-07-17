////////////////////////////////////////////////////////////////////////////////
// ElectronicDocumentsClient: mechanism of e-documents exchange.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Work with electronic documents

// The procedure opens a management form of e-documents exchange.
//
// Parameters:
//  CommandParameter - ObjectReference - ref to an IB object which e-documents should be sent,
//  OpenParameters - structure of additional view parameters.
//
Procedure OpenElectronicDocumentsExchangeForm(CommandParameter, CommandExecuteParameters) Export
	
	FormName = "ElectronicDocumentsExchange";
	
	FormParameters = New Structure("CurrentSection", FormName);
	
	#If WebClient Then
	PanelOpeningWindow = CommandExecuteParameters.Window;
	#Else
	PanelOpeningWindow = CommandExecuteParameters.Source;
	#EndIf

	OpenForm(
		"DataProcessor.AdministrationPanelED.Form.ElectronicDocumentsExchange",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		PanelOpeningWindow);
	
EndProcedure

// Opens a form with e-documents of the owner.
//
// Parameters:
//  ObjectReference - ref to an IB object which e-documents should be seen.
//  OpenParameters - structure, additional parameters of viewing e-documents.
//
Procedure OpenEDList(ObjectReference, OpenParameters = Undefined) Export
	
	If Not ElectronicDocumentsServiceCallServer.IsRightToReadED() Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(ObjectReference) Then
		Return;
	EndIf;
	
	EDParameters = Undefined;
	OpenAgreementForm = False;
	CheckForAgreement = (OpenParameters = Undefined);
	If ElectronicDocumentsServiceCallServer.CanOpenInEDTreeForm(ObjectReference,
		CheckForAgreement, OpenAgreementForm, EDParameters) Then
		
		OpenEDTree(ObjectReference, OpenParameters, False);
	ElsIf OpenAgreementForm Then
		FormParameters = New Structure;
		FillingValues = New Structure;
		
		If EDParameters.Property("EDFSetup") Then
			FormParameters.Insert("Key", EDParameters.EDFSetup);
		EndIf;
		FillingValues.Insert("Counterparty", EDParameters.Counterparty);
		FillingValues.Insert("Company", EDParameters.Company);
		FormParameters.Insert("FillingValues", FillingValues);
		OpenForm("Catalog.EDUsageAgreements.Form.ItemForm", FormParameters, , ObjectReference.UUID());
		
	Else
		
		FormParameters = New Structure("FilterObject", ObjectReference);
		If OpenParameters = Undefined Then
			OpenForm("DataProcessor.ElectronicDocuments.Form.EDList", FormParameters);
		Else
			Window = Undefined;
			If TypeOf(OpenParameters) = Type("CommandExecuteParameters") Then
				Window = OpenParameters.Window;
			EndIf;
			OpenForm("DataProcessor.ElectronicDocuments.Form.EDList", FormParameters,
			OpenParameters.Source, OpenParameters.Uniqueness, Window);
		EndIf;
	EndIf;
	
EndProcedure

// Refills an IB document according to the actual ED.
//
// Parameters:
//  CommandParameter - ref to object 
//  Source - Managed form
//
Procedure RefillDocument(CommandParameter, Source = Undefined, MappingAlreadyCompleted = False, ED = Undefined) Export
	
	If Not ElectronicDocumentsServiceCallServer.IsRightToProcessED() Then
		ElectronicDocumentsServiceClient.MessageToUserAboutViolationOfRightOfAccess();
		Return;
	EndIf;
	
	RefArray = ElectronicDocumentsServiceClient.GetParametersArray(CommandParameter);
	If RefArray = Undefined Then
		Return;
	EndIf;
	
	PostedDocumentsArray = ElectronicDocumentsServiceCallServer.PostedDocumentsArray(RefArray);
	Pattern = NStr("en='Processing document %1.
		|The operation is available only for unposted documents.';ru='Обработка документа %1.
		|Операция возможна только для непроведенных документов!'");
	For Each Document IN PostedDocumentsArray Do
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(Pattern, Document);
		CommonUseClientServer.MessageToUser(ErrorText);
	EndDo;
	
	RefArray = CommonUseClientServer.ReduceArray(RefArray, PostedDocumentsArray);
	
	If RefArray.Count() = 0 Then
		Return;
	EndIf;
	
	CompareProductsAndServicesBeforeDocumentFilling = False;
	ElectronicDocumentsClientOverridable.CompareProductsAndServicesBeforeDocumentFilling(
												CompareProductsAndServicesBeforeDocumentFilling);
	
	If ValueIsFilled(ED) Then
		AccordanceOfEDIOwners = New Map;
		AccordanceOfEDIOwners.Insert(CommandParameter, ED);
	Else
		AccordanceOfEDIOwners = ElectronicDocumentsServiceCallServer.GetCorrespondenceOwnersAndED(
																									RefArray);
	EndIf;
	
	If AccordanceOfEDIOwners.Count() = 0 Then
		For Each CurrentDocument IN RefArray Do
			Pattern = NStr("en='Electronic document for %1 is not found';ru='Электронный документ для %1 не найден'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(Pattern, CurrentDocument);
			CommonUseClientServer.MessageToUser(ErrorText);
		EndDo;
		Return;
	EndIf;
	
	ArrayChangedOwners = New Array;
	
	// Command "RefillDocument" is in the use command mode. - SingleRow.
	LinkToED = AccordanceOfEDIOwners.Get(CommandParameter);
	
	If Not ValueIsFilled(LinkToED) Then
		Return;
	EndIf;
	
	MetadataObject = "";
	DocumentImported = False;
	
	If CompareProductsAndServicesBeforeDocumentFilling AND Not MappingAlreadyCompleted Then
		ParametersStructure = ElectronicDocumentsServiceCallServer.GetProductsAndServicesComparingFormParameters(
			LinkToED);
		If ValueIsFilled(ParametersStructure) Then
			OpenForm(ParametersStructure.FormName, ParametersStructure.FormOpenParameters, Source);
			Return;
		EndIf;
	EndIf;
	
	ElectronicDocumentsServiceCallServer.RefillIBDocumentsByED(
		CommandParameter,
		LinkToED,
		MetadataObject,
		DocumentImported);
	
	If DocumentImported Then
			
		ArrayChangedOwners.Add(CommandParameter);
		
		Notify("RefreshStateED");
		Notify("UpdateIBDocumentAfterFilling", ArrayChangedOwners);
		
		
		If Not CompareProductsAndServicesBeforeDocumentFilling Then
			
			ParametersStructure = ElectronicDocumentsServiceCallServer.GetProductsAndServicesComparingFormParameters(
			LinkToED);
			If ValueIsFilled(ParametersStructure) Then
				
				AdditParameters = New Structure;
				AdditParameters.Insert("MetadataObject", MetadataObject);
				AdditParameters.Insert("FormKey", CommandParameter);
				
				Handler = New NotifyDescription("FillDocumentByED", ThisObject, AdditParameters);
				Mode = FormWindowOpeningMode.LockOwnerWindow;
				
				OpenForm(ParametersStructure.FormName, ParametersStructure.FormOpenParameters,,,,,Handler, Mode);
				
			EndIf;
				
		EndIf;
	EndIf;
		
	If ArrayChangedOwners.Count() > 0 Then
		
		StateTextOutput = NStr("en='Document is refilled.';ru='Документ перезаполнен.'");
		HeaderText = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
		ShowUserNotification(HeaderText, , StateTextOutput);
		
	EndIf;

EndProcedure

Procedure FillDocumentByED(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	MetadataObject = AdditionalParameters.MetadataObject;
	FormKey = AdditionalParameters.FormKey;
	
	DocumentForm = GetForm(MetadataObject + ".ObjectForm", New Structure("Key", FormKey));
	
	If TypeOf(DocumentForm) = Type("ManagedForm") Then
		FormData = DocumentForm.Object;
	Else
		FormData = DocumentForm.DocumentObject;
	EndIf;
	
	ElectronicDocumentsServiceCallServer.FillSource(FormData, Result);
	
	If TypeOf(DocumentForm) = Type("ManagedForm") Then
		CopyFormData(FormData, DocumentForm.Object);
	Else
		DocumentForm.DocumentObject = FormData;
	EndIf;
	
	DocumentForm.Open();
	DocumentForm.Modified = True;
	
EndProcedure

// Opens an actual ED by IB document
//
// Parameters:
//  CommandParameter - ref to IB document;
//  Source - Managed form;
//  OpenParameters - structure of additional view parameters.
//
Procedure OpenActualED(CommandParameter, Source = Undefined, OpenParameters = Undefined) Export
	
	ClearMessages();
	
	#If ThickClientOrdinaryApplication Then
		If Not ElectronicDocumentsServiceCallServer.IsRightToReadED() Then
			Return;
		EndIf;
	#EndIf
	
	RefArray = ElectronicDocumentsServiceClient.GetParametersArray(CommandParameter);
	If RefArray = Undefined Then
		Return;
	EndIf;
	
	AccordanceOfEDIOwners = ElectronicDocumentsServiceCallServer.GetCorrespondenceOwnersAndED(RefArray);
	For Each CurItm IN RefArray Do
		
		LinkToED = AccordanceOfEDIOwners.Get(CurItm);
		If ValueIsFilled(LinkToED) Then
			If TypeOf(OpenParameters) = Type("CommandExecuteParameters") Then
				
				ElectronicDocumentsServiceClient.OpenEDForViewing(LinkToED,
																		  OpenParameters,
																		  OpenParameters.Source);
			Else
				ElectronicDocumentsServiceClient.OpenEDForViewing(LinkToED, , Source);
			EndIf;
			
		Else
			TemplateText = NStr("en='%1. Relevant electronic document was not found.';ru='%1. Актуальный электронный документ не найден!'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(TemplateText, CurItm);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
	EndDo;
	
EndProcedure

// Opens a form with e-document tree of the owner.
//
// Parameters:
//  ObjectReference - ref to an IB object which e-documents are to be seen, 
//  OpenParameters - structure, additional parameters of viewing the e-document tree.
//  CheckAgreement - Boolean - used to exclude an
//    unnecessary server call, when calling this procedure from procedure OpenEDList(...) as this check has already been run.
//
Procedure OpenEDTree(ObjectReference, OpenParameters = Undefined, CheckAgreement = True) Export
	
	If Not ElectronicDocumentsServiceCallServer.IsRightToReadED() Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(ObjectReference) Then
		Return;
	EndIf;
	
	EDParameters = Undefined;
	If CheckAgreement
		AND Not ElectronicDocumentsServiceCallServer.GetCurrentEDFConfiguration(ObjectReference, EDParameters) Then
		
		FormParameters = New Structure;
		FillingValues = New Structure;
		
		If EDParameters.Property("EDFSetup") Then
			FormParameters.Insert("Key", EDParameters.EDFSetup);
		EndIf;
		FillingValues.Insert("Counterparty", EDParameters.Counterparty);
		FillingValues.Insert("Company", EDParameters.Company);
		FormParameters.Insert("FillingValues", FillingValues);
		OpenForm("Catalog.EDUsageAgreements.Form.ItemForm", FormParameters, , ObjectReference.UUID());
		
	Else
		
		FormParameters = New Structure("FilterObject", ObjectReference);
		If OpenParameters = Undefined Then
			OpenForm("DataProcessor.ElectronicDocuments.Form.EDTree", FormParameters, , ObjectReference.UUID());
		Else
			Window = Undefined;
			If TypeOf(OpenParameters) = Type("CommandExecuteParameters")
				OR TypeOf(OpenParameters) = Type("Structure")
				AND OpenParameters.Property("Window") AND TypeOf(OpenParameters.Window) = Type("ClientApplicationWindow") Then
				
				Window = OpenParameters.Window;
			EndIf;
			
			If TypeOf(OpenParameters) = Type("Structure") Then
				If OpenParameters.Property("InitialDocument") Then
					FormParameters.Insert("InitialDocument", OpenParameters.InitialDocument)
				EndIf;
			EndIf;

			OpenForm("DataProcessor.ElectronicDocuments.Form.EDTree", FormParameters,
				OpenParameters.Source, OpenParameters.Uniqueness, Window);
		EndIf;
	EndIf;
	
EndProcedure

Procedure RunCommandDocumentForms(Object, Form, CommandName) Export
	
	#If ThickClientOrdinaryApplication Then
		CheckResult = Undefined;
		ElectronicDocumentsClientOverridable.ObjectModified(Object, Form, CheckResult);
		If CheckResult = Undefined Then
			
			If Form.Modified OR Not ValueIsFilled(Object.Ref) Then
				
				Posted    = Metadata.Documents.Contains(Object.Metadata()) AND Object.Posted;
				StrPosted = ?(Posted, "write and post.
				|Write and post?", "write. Write?");
				
				MessagePattern = NStr("en='The document was changed. To generate an electronic document, you should %1 it';ru='Документ изменен. Для формирования электронного документа его необходимо %1'");
				QuestionText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, StrPosted);
				
				AdditionalParameters = New Structure();
				AdditionalParameters.Insert("ObjectReference", Object.Ref);
				AdditionalParameters.Insert("CommandName", CommandName);
				AdditionalParameters.Insert("Form", Form);
				AdditionalParameters.Insert("Posted", Posted);
				
				Handler = New NotifyDescription( "WriteInForm", ThisObject, AdditionalParameters);
				
				ShowQueryBox( Handler, QuestionText, QuestionDialogMode.OKCancel, , DialogReturnCode.Cancel, NStr("en='Document is changed.';ru='Документ изменен.'"));
				
			EndIf;
		EndIf;
	#EndIf
	
	ExecuteEDFCommand(Object.Ref, CommandName);
	
EndProcedure

Procedure WriteInForm(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.OK Then
		
		Posted = AdditionalParameters.Posted;
		Form = AdditionalParameters.Form;
		
		If Posted Then
			Try
				Cancel = Not Form.WriteInForm(DocumentWriteMode.Posting);
			Except
				ShowMessageBox(, NStr("en='Operation failed:';ru='Операция не выполнена:'"));
				Cancel = True;
			EndTry;
		Else
			Cancel = Not Form.WriteInForm();
		EndIf;
		
		If Cancel Then
			Return;
		EndIf;
	Else
		Return;
	EndIf;
	
	ObjectReference = AdditionalParameters.ObjectReference;
	CommandName = AdditionalParameters.CommandName;
	
	ExecuteEDFCommand(ObjectReference, CommandName);
	
	
EndProcedure

Procedure ExecuteEDFCommand(ObjectReference, CommandName)
	
	If CommandName = "GenerateSignSendED" Then
		GenerateSignSendED(ObjectReference);
		
	ElsIf CommandName = "GenerateNewED" Then
		GenerateNewED(ObjectReference);
		
	ElsIf CommandName = "Resend" Then
		ResendED(ObjectReference);
		
	ElsIf CommandName = "OpenActualED" Then
		OpenActualED(ObjectReference);
		
	ElsIf CommandName = "QuickExchangeGenerateNewED" Then
		 QuickExchangeGenerateNewED(ObjectReference);
		
	EndIf;
		
EndProcedure

// The procedure creates, signs, and sends an e-document.
//
// Parameters:
//  CommandParameter - ObjectReference - ref to an IB object which e-documents are to be sent, 
//  ED - electronic document to be signed and sent.
//
Procedure GenerateSignSendED(CommandParameter, ED = Undefined) Export
	
	RefArray = ElectronicDocumentsServiceClient.GetParametersArray(CommandParameter);
	If RefArray = Undefined Then
		If ED = Undefined Then
			Return;
		Else
			RefArray = New Array;
		EndIf;
	EndIf;
	
	ElectronicDocumentsServiceClient.ProcessED(RefArray, "GenerateConfirmSignSend", , ED);
	
EndProcedure

// The procedure creates a new electronic document.
//
// Parameters:
//  CommandParameter - ObjectReference - ref to an IB object which documents are to be sent,
//
Procedure GenerateNewED(CommandParameter, Show=True) Export
	
	RefArray = ElectronicDocumentsServiceClient.GetParametersArray(CommandParameter);
	If RefArray = Undefined Then
		Return;
	EndIf;
	If Show Then
		ElectronicDocumentsServiceClient.ProcessED(RefArray, "GenerateShow");
	Else
		ElectronicDocumentsServiceClient.ProcessED(RefArray, "Generate");
	EndIf;
	
EndProcedure

// Runs a assistant to connect the company to a direct counterparty exchange.
//
// Parameters:
//  Object - object which modification should be checked;
//  Form - form of the object which modification should be checked.
//
// Returns:
//  Result - Boolean - check result of the object form modification.
//
Procedure DirectExchangeConnectionAssistant() Export
	
	FormParameters = New Structure;
	FormParameters.Insert("EDExchangeMethods", ElectronicDocumentsServiceCallServer.EDExchangeMethodsArray());
	OpenForm("Catalog.EDFProfileSettings.Form.EDFConnectionAssistant", FormParameters);
	
EndProcedure

// Runs a assistant to connect the company to 1C Taxcom service.
//
Procedure ConnectionAssistant1CTaxcomService() Export
	
	FormParameters = New Structure;
	FormParameters.Insert("EDExchangeMethods", ElectronicDocumentsServiceCallServer.EDExchangeMethodsArray(False));
	OpenForm("Catalog.EDFProfileSettings.Form.EDFConnectionAssistant", FormParameters);
	
EndProcedure

// The procedure creates a new electronic document.
//
// Parameters:
//  CommandParameter - ObjectReference - ref to an IB object which documents are to be sent,
//
Procedure QuickExchangeGenerateNewED(CommandParameter) Export
	
	RefArray = ElectronicDocumentsServiceClient.GetParametersArray(CommandParameter);
	If RefArray = Undefined Then
		Return;
	EndIf;
	
	Parameters = New Structure("EDStructure", RefArray);
	EDViewForm = OpenForm("DataProcessor.ElectronicDocuments.Form.EDExportFormToFile", Parameters);
	
EndProcedure

// The procedure creates a new electronic directory.
//
Procedure QuickExchangeGenerateNewEDDirectory() Export
	
	DescriptionCompanyCatalog = ElectronicDocumentsServiceCallServer.GetAppliedCatalogName("Companies");
	If Not ValueIsFilled(DescriptionCompanyCatalog) Then
		DescriptionCompanyCatalog = "Companies";
	EndIf;
	
	
	Handler = New NotifyDescription("GenerateNewEDDirectory", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	
	OpenForm("Catalog." + DescriptionCompanyCatalog + ".ChoiceForm",,,,,, Handler, Mode);
	
EndProcedure

// Notification description for procedure "QuickExchangeGenerateNewEDDirectory"
Procedure GenerateNewEDDirectory(Company, AdditionalParameters) Export
	
	If Company = Undefined Then
		Return;
	EndIf;
	
	AdditParameters = New Structure("Company", Company);
	NotifyDescription = New NotifyDescription(
		"GenerateNewEDDirectoryComplete", ElectronicDocumentsServiceClient, AdditParameters);
	ElectronicDocumentsClientOverridable.OpenProductSelectionForm(New UUID(),
		NotifyDescription);
	
EndProcedure

// The procedure resends an electronic document.
//
// Parameters:
//  CommandParameter - ObjectReference - ref to an IB object which e-documents are to be sent, 
//  ED - electronic document to be signed and sent.
//
Procedure ResendED(CommandParameter, ED = Undefined) Export
	
	RefArray = ElectronicDocumentsServiceClient.GetParametersArray(CommandParameter);
	If RefArray = Undefined Then
		If ED = Undefined Then
			Return;
		Else
			RefArray = New Array;
		EndIf;
	EndIf;
	
	ElectronicDocumentsServiceClient.ProcessED(RefArray, "Resend", , ED);
	
EndProcedure

// Send and receive e-documents by one command.
//
//
Procedure SendReceiveElectronicDocuments() Export
	
	ElectronicDocumentsServiceClient.SendReceiveElectronicDocuments();
	
EndProcedure

// Imports an e-document file to IB document.
//
// Parameters:
//  DocumentRef - Ref to an IB object which data is to be refilled.
//
Procedure QuickExchangeImportED(DocumentRef = Undefined) Export
	
	File = Undefined;
	AddressInStorage = Undefined;
	UUID = New UUID;
	
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("DocumentRef", DocumentRef);
	AdditionalParameters.Insert("UUID", UUID);
	
	Handler = New NotifyDescription("ProcessFilePlacingResult", ThisObject, AdditionalParameters);
	BeginPutFile(Handler, AddressInStorage, File, True, UUID);
		
EndProcedure

Procedure ProcessFilePlacingResult(SelectionComplete, FileURL, SelectedFileName, AdditionalParameters) Export
	
	If Not SelectionComplete Then
		Return;
	EndIf;
	
	Extension = Right(SelectedFileName, 3);
	DocumentRef = AdditionalParameters.DocumentRef;
	UUID = AdditionalParameters.UUID;
	
	If Not (Upper(Extension) = Upper("zip") Or Upper(Extension) = Upper("xml")) Then
		MessageText = NStr("en='Invalid file format.
		|Select a file with extension ""zip"" or ""xml"".';ru='Не корректный формат файла.
		|Выберите файл с расширением ""zip"" или ""xml"".'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	ExchangeStructure = New Structure("EDDirection, UUID, StorageAddress, DocumentRef, FileName, FileOfArchive",
		PredefinedValue("Enum.EDDirections.Incoming"), UUID, FileURL,
		DocumentRef, SelectedFileName, Upper(Extension) = Upper("zip"));
	
	Parameters = New Structure("EDStructure", ExchangeStructure);
	
	OpenForm("DataProcessor.ElectronicDocuments.Form.EDViewImportForm", Parameters, ,
		ExchangeStructure.UUID);
	
	
EndProcedure

// Imports an electronic document file to IB data, it is used to show a command in interface.
//
Procedure QuickExchangeImportEDFromFile() Export
	
	QuickExchangeImportED();
	
EndProcedure

// The procedure forcibly closes EDF for an array of references to documents.
//
// Parameters:
//   EDOwnersArray - Array - contains refs to IB documents for
//      which it is required to close EDF.
//
Procedure CloseEDFForcibly(EDOwnersArray) Export
	
	RefArray = ElectronicDocumentsServiceClient.GetParametersArray(EDOwnersArray);
	If RefArray = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("RefArray", RefArray);
	
	Handler = New NotifyDescription("CloseForciblyRowInputResult", ThisObject, AdditionalParameters);
	
	ClosingReason = "";
	ShowInputString(Handler, ClosingReason, NStr("en='Specify the reason for closing EDF';ru='Укажите причину закрытия документооборота'"),,True);
	
	
EndProcedure

Procedure CloseForciblyRowInputResult(ClosingReason, AdditionalParameters) Export
	
	If Not ValueIsFilled(ClosingReason) Then
		
		MessageText = NStr("en='To close EDF by the selected EDs, specify a closure reason.';ru='Для закрытия документооборота по выбранным ЭД необходимо указать причину закрытия!'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	RefArray = AdditionalParameters.RefArray;
	ProcessedEDCount = 0;
	ElectronicDocumentsServiceCallServer.CloseDocumentsForcedly(RefArray, ClosingReason, ProcessedEDCount);
	
	NotificationText = NStr("en='ED document states are changed to ""Closed forcefully"": (%1)';ru='Изменено состояние ЭД документов на ""Закрыт принудительно"": (%1)'");
	NotificationText = StrReplace(NotificationText, "%1", ProcessedEDCount);
	ShowUserNotification(NStr("en='Document processing';ru='Обработка документов'"), , NotificationText);
	If ProcessedEDCount > 0 Then
		Notify("RefreshStateED");
	EndIf;
	
EndProcedure

// A list form appears with tab "Settings of EDF with counterparties".
//
Procedure OpenFormSettingsVISITORSOfCounterparties() Export
	
	FormParameters = New Structure;
	FormParameters.Insert("SettingsEDFWithCounterparties", True);
	OpenForm("Catalog.EDUsageAgreements.Form.ListForm", FormParameters);
	
EndProcedure

// Starts processing "Current EDF works".
//
Procedure OpenCurrentWorksEDF() Export
	
	OpenForm("DataProcessor.CurrentWorksOnEDF.Form");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Select e-documents to be passed to FTS.

// Gets info base documents by set filter conditions.
// The procedure is used with library "Scheduled reporting".
//
// Parameters:
//  FilterStructure - structure, filter parameters for IB document selection form;
//
Procedure GetDocumentsForTransferOfIBPropertiesFTS(FilterStructure = Undefined) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("VersionCall", 3);
	
	If FilterStructure <> Undefined Then
		If FilterStructure.Property("DocumentKind") Then
			FormParameters.Insert("DocumentKind", FilterStructure.DocumentKind);
		EndIf;
		
		If FilterStructure.Property("Company") Then
			FormParameters.Insert("Company", FilterStructure.Company);
		EndIf;
		
		If FilterStructure.Property("Counterparty") Then
			FormParameters.Insert("Counterparty", FilterStructure.Counterparty);
		EndIf;
	EndIf;
	OpenForm("DataProcessor.ElectronicDocuments.Form.EDChoiceFormForFTSTransfer", FormParameters);
	
EndProcedure

// Outdated. It is recommended to use procedure GetIBDocumentsPropertiesToTransferFTS
// Gets info base documents by set filter conditions.
// The function is intended to be used with library "Scheduled reporting".
//
// Parameters:
//  FilterStructure - structure, filter parameters for IB document selection form;
//  Multiselect - Boolean, selection form property.
//
Function GetIBDocumentsToTransferFTS(FilterStructure, Multiselect) Export
	
	
EndFunction

#Region DirectExchangeWithBank

// Requests a bank statement, once the statement is received, calls
// a selection notification for the form and form item specified in the Owner parameter
//
// Parameters:
//   EDAgreement - CatalogRef.EDUsageAgreement, current agreement;
//   StartDate - date, query start date
//   EndDate - date, query period end 
//   Owner - Form or form item - notification recipient of an item selection - bank statements 
//   AccountNo - String, company bank account number. If it is not specified, then a request by all accounts;
//
Procedure GetBankStatement(EDAgreement, StartDate, Val EndDate, Owner, AccountNo = Undefined) Export
	
	If Not ValueIsFilled(EDAgreement) Then
		Return;
	EndIf;
	
	CurrentSessionDate = CommonUseClient.SessionDate();
	If StartDate > CurrentSessionDate OR EndDate > EndOfDay(CurrentSessionDate) Then
		MessageText = NStr("en='Query period is specified incorrectly';ru='Период запроса указан неверно'");
		CommonUseClientServer.MessageToUser(MessageText, , "Period");
		Return;
	EndIf;
	
	If EndOfDay(EndDate) = EndOfDay(CurrentSessionDate) Then
		EndDate = CurrentSessionDate;
	Else
		EndDate = EndOfDay(EndDate);
	EndIf;
	
	EDFSettingAttributes = ElectronicDocumentsServiceCallServer.EDFSettingAttributes(EDAgreement);
	
	StatusUsed = PredefinedValue("Enum.EDAgreementsStatuses.Acts");
	If Not EDFSettingAttributes.AgreementStatus = StatusUsed Then
		MessageText = NStr("en='EDF setting is invalid, cannot execute the operation';ru='Настройка ЭДО не действует, операция невозможна'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	Parameters = New Structure;
	
	Parameters.Insert("EDAgreement", EDAgreement);
	Parameters.Insert("AccountNo", AccountNo);
	Parameters.Insert("StartDate", StartDate);
	Parameters.Insert("EndDate", EndDate);
	Parameters.Insert("Owner", Owner);
	Parameters.Insert("EDFSettingAttributes", EDFSettingAttributes);
	
	ExchangeThroughTheAdditionalInformationProcessor = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor");
	If EDFSettingAttributes.BankApplication = ExchangeThroughTheAdditionalInformationProcessor Then
		// ConnectionStructure is required to get an external module.
		ConnectionStructure = New Structure;
		ConnectionStructure.Insert("EDAgreement", EDAgreement);
		ConnectionStructure.Insert("RunTryReceivingModule", False);
		
		HandlerAfterConnecting = New NotifyDescription("GetStatementThroughAdditionalDataProcessor",
			ElectronicDocumentsServiceClient, Parameters);
		ConnectionStructure.Insert("AfterObtainingDataProcessorModule", HandlerAfterConnecting);
		
		ElectronicDocumentsServiceClient.GetExternalModuleThroughAdditionalProcessing(ConnectionStructure);
		Return;
	ElsIf EDFSettingAttributes.BankApplication = PredefinedValue("Enum.BankApplications.iBank2") Then
		ND = New NotifyDescription("GetBankStatementiBank2", ElectronicDocumentsServiceClient, Parameters);
		Parameters.Insert("HandlerAfterConnectingComponents", ND);
		ElectronicDocumentsServiceClient.EnableExternalComponentiBank2(Parameters);
		Return;
	EndIf;
	
	If EDFSettingAttributes.CryptographyIsUsed Then
		Notification = New NotifyDescription(
			"AfterObtainingPrintsGetBankStatement", ElectronicDocumentsServiceClient, Parameters);
		DigitalSignatureClient.GetCertificatesThumbprints(Notification, True, False);
		Return;
	Else
		CertificateTumbprintsArray = New Array;
	EndIf;
	
	ElectronicDocumentsServiceClient.AfterObtainingPrintsGetBankStatement(
											CertificateTumbprintsArray, Parameters);
	
EndProcedure

// Sends prepared documents to the bank and receives the new ones.
// If parameters are not passed, then all settings are synchronized with banks
//
// Parameters:
//  Company - CatalogRef.Companies, company
//  from the bank account Bank - CatalogRef.RFBankClassifier - bank from account
//
Procedure SynchronizeWithBank(Company = Undefined, Bank = Undefined) Export
	
	#If ThickClientOrdinaryApplication Then
		If Not ElectronicDocumentsOverridable.IsRightToProcessED() Then
			ElectronicDocumentsServiceClient.MessageToUserAboutViolationOfRightOfAccess();
			Return;
		EndIf;
		If Not ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseEDExchange") Then
			MessageText = ElectronicDocumentsServiceCallServer.MessageTextAboutSystemSettingRequirement("WorkWithED");
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		EndIf;
	#EndIf
	
	SettingArrayEDF = ElectronicDocumentsServiceCallServer.EDFSettingsWithBanks(Company, Bank);
	
	SynchronizationParameters = New Structure;
	SynchronizationParameters.Insert("EDFSettingsWithBanks", SettingArrayEDF);
	SynchronizationParameters.Insert("TotalPreparedCnt", 0);
	SynchronizationParameters.Insert("TotalSentCnt", 0);
	
	ElectronicDocumentsServiceClient.RunExchangeWithBanks(Undefined, SynchronizationParameters);

EndProcedure

#EndRegion
