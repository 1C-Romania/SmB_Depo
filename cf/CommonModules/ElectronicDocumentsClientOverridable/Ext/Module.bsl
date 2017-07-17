////////////////////////////////////////////////////////////////////////////////
// ElectronicDocumentsClientOverridable: e-documents exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

 // It overrides the message about the limitation of the access rights
//
// Parameters:
//  MessageText - Message string
//
Procedure PrepareMessageTextAboutAccessRightsViolation(MessageText) Export
	
	// If necessary you can override or add the message text
	
EndProcedure

// It fills the form attributes by the passed values 
//
// Parameters:
//  Source - Managed form
//  FillValue - Ref to a storage
//
Procedure OpenUsersChoiceForm(ThisObject, CurrentUser) Export
	
	Parameters = New Structure("Key", CurrentUser);
	Parameters.Insert("ChoiceMode",             True);
	Parameters.Insert("CurrentRow",           CurrentUser);
	Parameters.Insert("UserGroupChoice", False);
	OpenForm("Catalog.Users.ChoiceForm", Parameters, ThisObject);
	
EndProcedure

// Checks whether an object is modified for a standard application.
//
// Parameters:
//  Object - object which modification should be checked;
//  Form - form of the object which modification should be checked.
//  Result - Boolean - check result of the object form modification.
//
Procedure ObjectModified(Object, Form, Result) Export
	
EndProcedure

// Checks whether online user support library is used in the application solution.
//
// Parameters:
//  Use - Boolean - flag of using WFP library..
//
Procedure CheckUsingUsersInternetSupport(Use) Export
	
	Connection1CTaxcomServerCall.Available1CTaxcomServiceUse();
	
EndProcedure

// Auxiliary procedure to call a method from the online user support library.
//
Procedure StartWorkWithEDFOperatorMechanism(SubscriberCertificate,
												 Company,
												 BusinessProcessOption,
												 CompanyID = "",
												 DSCertificatePassword = Undefined,
												 FormUUID = Undefined) Export
	
	Connection1CTaxcomClient.StartWorkWithEDFOperatorMechanism(SubscriberCertificate, Company, BusinessProcessOption,
			CompanyID, DSCertificatePassword, FormUUID);
	
EndProcedure

// Checks whether required automatic conditions for signing the document are fulfilled.
// 
// Parameters:
//  ElectronicDocument - references to attached file.
//
Function ElectronicDocumentReadyForSigning(ElectronicDocument) Export
	
	Result = True;
	
	Return Result;
	
EndFunction

// Outdated. It is recommended
// to use procedure OpenProductsSelectionForm Fills out a storage address with the values table - products directory
//
// Parameters:
//  AddressInTemporaryStorage - product catalog storage address;
//  FormID - unique  identifier of the form that called the function.
//
Procedure PutGoodsCatalogIntoTemporaryStorage(AddressInTemporaryStorage, FormID) Export
	
	AddressInTemporaryStorage = Undefined;
	
EndProcedure

// It fills the storage address with the value table - products directory
//
// Parameters:
//  FormID - unique  identifier of the form that called the function.
//  ContinuationProcessor - NotifyDescription - contains description
//                          of the procedure that will be called once the selection form is closed.
//
Procedure OpenProductSelectionForm(FormID, ContinuationProcessor) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("FormID", FormID);
	
	OpenForm("DataProcessor.ElectronicDocumentsSendDirectory.Form.Form", FormParameters, , , , , ContinuationProcessor);
	
EndProcedure

// Outdated. It is recommended to use procedure OpenProductsSelectionForm
// Interactively posts documents before generating ED.
// If there are unprocessed documents, it offers to process them. Prompts
// user about the continuation if any of the documents are not processed and there are processed ones.
//
// Parameters 
//  DocumentsArray - Array           - references to documents required to process before printing.
//                                     After execution of the function from the array unprocessed documents are excluded.
//  DocumentsPosted - Boolean - a return parameter, shows that documents are posted
//  FormSource      - ManagedForm - form from which the command was called.
//
// Returns:
//  Boolean - there are documents for printing in parameter DocumentsArray.
//
Procedure CheckDocumentsPosted(DocumentsArray, DocumentsPosted, FormSource = Undefined) Export
	
	ClearMessages();
	PostingDocuments = ElectronicDocumentsServiceCallServer.PostingDocumentsArray(DocumentsArray);
	DocumentsRequiredPosting = CommonUseServerCall.CheckThatDocumentsArePosted(PostingDocuments);
	UnpostedDocumentsCount = DocumentsRequiredPosting.Count();
	
	If UnpostedDocumentsCount > 0 Then
		
		If UnpostedDocumentsCount = 1 Then
			QuestionText = NStr("en='To generate an e-document version, post it. Do you want to post the document and continue?';ru='Для того чтобы сформировать электронную версию документа, его необходимо предварительно провести. Выполнить проведение документа и продолжить?'");
		Else
			QuestionText = NStr("en='To generate e-document versions, post them. Do you want to post the documents and continue?';ru='Для того чтобы сформировать электронные версии документов, их необходимо предварительно провести. Выполнить проведение документов и продолжить?'");
		EndIf;
		
		ResponseCode = DoQueryBox(QuestionText, QuestionDialogMode.YesNo);
		If ResponseCode <> DialogReturnCode.Yes Then
			DocumentsPosted = False;
			Return;
		EndIf;
		
		DataAboutUnpostedDocuments = CommonUseServerCall.PostDocuments(DocumentsRequiredPosting);
		
		// inform about the documents that were not processed
		MessagePattern = NStr("en='Document %1 is not posted: %2 Cannot generate ED.';ru='Документ %1 не проведен: %2 Формирование ЭД невозможно.'");
		UnpostedDocuments = New Array;
		For Each InformationAboutDocument IN DataAboutUnpostedDocuments Do
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
																	MessagePattern,
																	String(InformationAboutDocument.Ref),
																	InformationAboutDocument.ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText, InformationAboutDocument.Ref);
			UnpostedDocuments.Add(InformationAboutDocument.Ref);
		EndDo;
		
		UnpostedDocumentsCount = UnpostedDocuments.Count();
		
		// Notify open forms that documents were posted
		PostedDocuments = CommonUseClientServer.ReduceArray(DocumentsRequiredPosting,
																			UnpostedDocuments);
		PostedDocumentsTypes = New Map;
		For Each PostedDocument IN PostedDocuments Do
			PostedDocumentsTypes.Insert(TypeOf(PostedDocument));
		EndDo;
		For Each Type IN PostedDocumentsTypes Do
			NotifyChanged(Type.Key);
		EndDo;
		
		// If command is called from form, then read an actual (posted) copy from base to form.
		If TypeOf(FormSource) = Type("ManagedForm") Then
			Try
				FormSource.Read();
			Except
				// If the Read method does not exist, then it was generated not from the object form.
			EndTry;
		EndIf;
		
		// Update initial array of documents
		DocumentsArray = CommonUseClientServer.ReduceArray(DocumentsArray, UnpostedDocuments);
		
	EndIf;
	
	IsDocumentsReadyForEDFormation = DocumentsArray.Count() > 0;
	
	Cancel = False;
	If UnpostedDocumentsCount > 0 Then
		
		// Prompt a user whether it is required to continue printing if there are unposted documents
		
		DialogText = NStr("en='Cannot post one or several documents.';ru='Не удалось провести один или несколько документов.'");
		DialogButtons = New ValueList;
		
		If IsDocumentsReadyForEDFormation Then
			DialogText = DialogText + " " + NStr("en='Continue?';ru='Продолжить?'");
			DialogButtons.Add(DialogReturnCode.Ignore, NStr("en='Continue';ru='Продолжить'"));
			DialogButtons.Add(DialogReturnCode.Cancel);
		Else
			DialogButtons.Add(DialogReturnCode.OK);
		EndIf;
		
		Response = DoQueryBox(DialogText, DialogButtons);
		If Response <> DialogReturnCode.Ignore Then
			Cancel = True;
		EndIf;
	EndIf;
	
	DocumentsPosted = Not Cancel;
	
EndProcedure

// Interactively posts documents before generating ED.
// If there are unprocessed documents, it offers to process them. Prompts
// user about the continuation if any of the documents are not processed and there are processed ones.
//
// Parameters 
//  DocumentsArray - Array           - references to documents required to process before printing.
//                                     After execution of the function from the array unprocessed documents are excluded.
//  ContinuationProcessor - NotifyDescription - contains description
//                          of the procedure that will be called once the documents are checked.
//  FormSource   - ManagedForm - form from which the command was called.
//
Procedure RunDocumentsPostingCheck(DocumentsArray, ContinuationProcessor, FormSource = Undefined) Export
	
	ClearMessages();
	PostingDocuments = ElectronicDocumentsServiceCallServer.PostingDocumentsArray(DocumentsArray);
	DocumentsRequiredPosting = CommonUseServerCall.CheckThatDocumentsArePosted(PostingDocuments);
	UnpostedDocumentsCount = DocumentsRequiredPosting.Count();
	
	If UnpostedDocumentsCount > 0 Then
		
		If UnpostedDocumentsCount = 1 Then
			QuestionText = NStr("en='To generate an e-document version, post it. Do you want to post the document and continue?';ru='Для того чтобы сформировать электронную версию документа, его необходимо предварительно провести. Выполнить проведение документа и продолжить?'");
		Else
			QuestionText = NStr("en='To generate e-document versions, post them. Do you want to post the documents and continue?';ru='Для того чтобы сформировать электронные версии документов, их необходимо предварительно провести. Выполнить проведение документов и продолжить?'");
		EndIf;
		AdditParameters = New Structure("ContinuationProcessor, DocumentsRequiredPosting, FormSource, DocumentsArray",
										ContinuationProcessor, DocumentsRequiredPosting, FormSource, DocumentsArray);
		Handler = New NotifyDescription("DocumentsCheckPostingRunContinue", ThisObject, AdditParameters);
		ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
	Else
		ExecuteNotifyProcessing(ContinuationProcessor, DocumentsArray);
	EndIf;

EndProcedure

#EndRegion

#Region ProductsAndServicesMatching

// Depending on the application solution, determines opening of products and services match form
//
//  Parameters:
//  ToCompareProductsAndServices - <Boolean> - True - open a match form before filling out a document, False - in reverse order 
//  True for SCP, PSU
//  False for UT
//
Procedure CompareProductsAndServicesBeforeDocumentFilling(ToCompareProductsAndServices) Export
	
	ToCompareProductsAndServices = True;
	
EndProcedure

// Finds supplier's products and services item and opens a form for viewing
//
// Parameters:
//  ID - unique object identifier
//
Procedure OpenSupplierProductsAndServicesElement(ID) Export
	
	AdditionalAttributes = New Structure;
	AdditionalAttributes.Insert("ID", ID);
	
	SupplierProductsAndServices = ElectronicDocumentsServiceCallServer.FindRefToObject("SuppliersProductsAndServices",
																						   ,
																						   AdditionalAttributes);
	If ValueIsFilled(SupplierProductsAndServices) Then
		ShowValue(, SupplierProductsAndServices);
	EndIf;
	
EndProcedure

// It overrides a standard selection form of products and services in the products and services mapping form.
//
// Parameters:
//  Item - item form 
//  Parameters - Parameters structure, contains item "Counterparty" 
//  StandardProcessing - Boolean, it is required to disable standard processing when overriding a selection form
Procedure ProductsAndServicesMappingFormOpen(Item, Parameters, StandardProcessing = Undefined) Export
	
	StandardProcessing = False;
	Parameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	OpenForm("Catalog.ProductsAndServices.Form.ChoiceForm", Parameters, Item);
	
EndProcedure

#EndRegion

#Region MethodsOfClientBank

// Parses the passed text file of a statement.
//
// Parameters 
//  ED - CatalogRef.EDAttachedFiles - Electronic document 
//  FileRef - String, ref to a temporary storage 
//  Company - CatalogRef.Companies - company.
//  AccountsArray - Array, contains references to accounts of companies
//  EDAgreement - CatalogRef.EDUsageAgreements
//
Procedure ParseStatementFile(ED, FileRef, Company, AccountsArray, EDAgreement) Export
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Company",             Company);
	OpenParameters.Insert("BankElectronicStatement", ED);
	OpenParameters.Insert("DirectExchangeWithBanksAgreement", EDAgreement);
	If AccountsArray.Count()>0 Then
		OpenParameters.Insert("BankAccountOfTheCompany", AccountsArray[0]);
	EndIf;
	
	OpenForm("DataProcessor.ClientBank.Form.FormImport", OpenParameters);
	
EndProcedure

#EndRegion

#Region LicenseAgreement

// Auxiliary procedure to launch a mechanism of user approval of license agreement terms.
//
Procedure ToRequestConsentToTermsOfLicenseAgreements(AgreeWithConditions) Export
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure DocumentsCheckPostingRunContinue(Val Result, Val AdditionalParameters) Export
	
	DocumentsArray = Undefined;
	ContinuationProcessor = Undefined;
	DocumentsRequiredPosting = Undefined;
	If Result = DialogReturnCode.Yes
		AND TypeOf(AdditionalParameters) = Type("Structure")
		AND AdditionalParameters.Property("DocumentsArray", DocumentsArray)
		AND AdditionalParameters.Property("ContinuationProcessor", ContinuationProcessor)
		AND AdditionalParameters.Property("DocumentsRequiredPosting", DocumentsRequiredPosting) Then
		
		FormSource = Undefined;
		AdditionalParameters.Property("FormSource", FormSource);
		
		DataAboutUnpostedDocuments = CommonUseServerCall.PostDocuments(DocumentsRequiredPosting);
		
		// inform about the documents that were not processed
		MessagePattern = NStr("en='Document %1 is not posted: %2 Cannot generate ED.';ru='Документ %1 не проведен: %2 Формирование ЭД невозможно.'");
		UnpostedDocuments = New Array;
		For Each InformationAboutDocument IN DataAboutUnpostedDocuments Do
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
																	MessagePattern,
																	String(InformationAboutDocument.Ref),
																	InformationAboutDocument.ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText, InformationAboutDocument.Ref);
			UnpostedDocuments.Add(InformationAboutDocument.Ref);
		EndDo;
		
		UnpostedDocumentsCount = UnpostedDocuments.Count();
		
		// Notify open forms that documents were posted
		PostedDocuments = CommonUseClientServer.ReduceArray(DocumentsRequiredPosting,
																			UnpostedDocuments);
		PostedDocumentsTypes = New Map;
		For Each PostedDocument IN PostedDocuments Do
			PostedDocumentsTypes.Insert(TypeOf(PostedDocument));
		EndDo;
		For Each Type IN PostedDocumentsTypes Do
			NotifyChanged(Type.Key);
		EndDo;
		
		// If command is called from form, then read an actual (posted) copy from base to form.
		If TypeOf(FormSource) = Type("ManagedForm") Then
			Try
				FormSource.Read();
			Except
				// If the Read method does not exist, then it was generated not from the object form.
			EndTry;
		EndIf;
		
		// Update initial array of documents
		DocumentsArray = CommonUseClientServer.ReduceArray(DocumentsArray, UnpostedDocuments);
		IsDocumentsReadyForEDFormation = DocumentsArray.Count() > 0;
		If UnpostedDocumentsCount > 0 Then
			// Prompt a user whether it is required to continue printing if there are unposted documents
			QuestionText = NStr("en='Cannot post one or several documents.';ru='Не удалось провести один или несколько документов.'");
			DialogButtons = New ValueList;
			
			If IsDocumentsReadyForEDFormation Then
				QuestionText = QuestionText + " " + NStr("en='Continue?';ru='Продолжить?'");
				DialogButtons.Add(DialogReturnCode.Ignore, NStr("en='Continue';ru='Продолжить'"));
				DialogButtons.Add(DialogReturnCode.Cancel);
			Else
				DialogButtons.Add(DialogReturnCode.OK);
			EndIf;
			AdditParameters = New Structure("ContinuationProcessor, DocumentsArray", ContinuationProcessor, DocumentsArray);
			Handler = New NotifyDescription("RunDocumentsPostingCheckComplete", ThisObject, AdditParameters);
			ShowQueryBox(Handler, QuestionText, DialogButtons);
		Else
			ExecuteNotifyProcessing(ContinuationProcessor, DocumentsArray);
		EndIf;
	EndIf;
	
EndProcedure

Procedure RunDocumentsPostingCheckComplete(Val Result, Val AdditionalParameters) Export
	
	DocumentsArray = Undefined;
	ContinuationProcessor = Undefined;
	If Result = DialogReturnCode.Ignore
		AND TypeOf(AdditionalParameters) = Type("Structure")
		AND AdditionalParameters.Property("DocumentsArray", DocumentsArray)
		AND AdditionalParameters.Property("ContinuationProcessor", ContinuationProcessor) Then
		ExecuteNotifyProcessing(ContinuationProcessor, DocumentsArray);
	EndIf;
	
EndProcedure

#EndRegion
