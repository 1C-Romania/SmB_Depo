
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Key.IsEmpty() Then
		CatalogObject = Parameters.Key.GetObject();
		ValueToFormAttribute(CatalogObject, "Object");
	EndIf;
	
	If ValueIsFilled(Parameters.ThumbprintArray) Then
		ThumbprintArrayReference = PutToTempStorage(Parameters.ThumbprintArray, UUID);
	EndIf;
	
	BankApplication = CommonUse.ObjectAttributeValue(Object.EDAgreement, "BankApplication");
	
	If ValueIsFilled(Object.Ref) Then
		EDRefused = EDRefused();
		SignatureRequired = RequiredToSign();
		UpdateEDStatus();
		Title = ElectronicDocumentsService.GetEDPresentation(Object.Ref);
		FillTableDS();
		
		If Not Cancel Then
			ExecuteViewEDFromIBServer(Cancel);
		EndIf;
	EndIf;
	
	RefillComments();

	Try
		If ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer() Then
			ThumbprintArray = ElectronicDocumentsServiceCallServer.CertificateTumbprintsArray();
			ThumbprintArrayReference = PutToTempStorage(ThumbprintArray, UUID);
		EndIf;
	Except
	EndTry;
	
	ChangeVisibleEnabled();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not Cancel AND ValueIsFilled(Object.Ref) Then
		If IsTempStorageURL(FileAddressAtRepository) Then
			#If WebClient Then
				PathToViewingFile = FileAddressAtRepository;
			#Else
				PathToViewingFile = GetTempFileName(FileExtension);
				QQFile = GetFromTempStorage(FileAddressAtRepository);
				QQFile.Write(PathToViewingFile);
			#EndIf
			If Find("HTML PDF DOCX XLSX", Upper(FileExtension)) > 0 Then
				Items.DocumentContentGroup.CurrentPage = Items.PageOtherFormat;
			Else
				#If Not WebClient Then
					RunApp(PathToViewingFile);
				#EndIf
				Cancel = True;
				Return;
			EndIf;
		EndIf;
		Else
		Cancel = True;
	EndIf;
	
	If Object.EDKind = PredefinedValue("Enum.EDKinds.AddData") Then
		SaveEDToDisc(Undefined);
		Cancel = True;
	EndIf;
	
	If Not Cancel AND Not ValueIsFilled(ThumbprintArrayReference) Then
		Definition = New NotifyDescription("AfterObtainingPrints", ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		ExecuteNotificationProcessingAtServer();
		RefreshDataRepresentation();
	ElsIf EventName = "NotifyAboutCreatingNotifications" AND Parameter = Object.Ref Then
		PlaceTextRefinementsInObjec(CorrectionText);
		ChangeVisibleEnabled();
		EDRefused = True;
		ChangeStatusReject();
		Notify("RefreshStateED");
	ElsIf EventName = "DSCheckCompleted" Then
		For Each ED IN Parameter Do
			If ED = Object.Ref Then
				RefreshDataRepresentation();
				FillTableDS();
				Break;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	HideAdditionalInformation(DisableOutputAdditionalInformation);
	
EndProcedure

#EndRegion

#Region FieldsFormEventsHandlers

&AtClient
Procedure DocumentTextIBPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(, Object.FileOwner);
	
EndProcedure

&AtClient
Procedure RejectionReasonsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ShowValue(, Item.CurrentData.RejectionReason);
	
EndProcedure

&AtClient
Procedure DisableOutputAdditionalInformationOnChange(Item)
	
	HideAdditionalInformation(DisableOutputAdditionalInformation);
	RefreshDataRepresentation();
	
EndProcedure

&AtClient
Procedure ReceiptPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	If TypeOf(STATEMENT) = Type("CatalogRef.EDAttachedFiles") Then
		FormParameters = New Structure("Key", STATEMENT);
		OpenForm("Catalog.EDAttachedFiles.Form.EDViewForm", FormParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure ObjectAdditionalInformationOnChange(Item)
	
	ChangeAccompanyingNoteText(Object.AdditionalInformation);
	
EndProcedure


#EndRegion

#Region EventsHandlersDSTablesFields

&AtClient
Procedure DSOnActivateRow(Item)
	
	If Items.DS.CurrentData <> Undefined Then
		Items.TrustCertificate.Enabled = Items.DS.CurrentData.MissingInList;
	EndIf;
	
EndProcedure

&AtClient
Procedure DSChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If Find(Field.Name, "DSCertificateIsIssuedTo") > 0 Then
		AddCertificateToTrusted(Item.CurrentData);
		If Item.CurrentData <> Undefined AND Not Item.CurrentData.MissingInList
				AND Not BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor")
				AND Not BankApplication = PredefinedValue("Enum.BankApplications.iBank2") Then
			ShowCertificate(Item.CurrentData.LineNumber, Item.CurrentData.Imprint);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RefillDocument(Command)
	
	ElectronicDocumentsClient.RefillDocument(Object.FileOwner, ThisObject, , Object.Ref);
	
EndProcedure

&AtClient
Procedure Reject(Command)
	
	CancelRejectED(True);
	
EndProcedure

&AtClient
Procedure ChooseDocument(Command)
	
	Modified = False;
	QuestionText = NStr("en = 'Warning! It is not recommended to select a document to be registered for manual accounting. Continue?'");
	NotifyDescription = New NotifyDescription("ChooseDocumentContinue", ThisObject);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure SaveEDToDisc(Command)
	
	If BankApplication = PredefinedValue("Enum.BankApplications.SberbankOnline") Then
		SaveBankDocumentsSberBank(Object.Ref);
		Return;
	EndIf;
	
	AttachedFile = Object.Ref;
	FileData = ElectronicDocumentsServiceCallServer.GetFileData(AttachedFile, UUID);
	
	AttachedFilesClient.SaveWithDS(AttachedFile, FileData, UUID);
	If Not ValueIsFilled(BankApplication) Then
		Return;
	EndIf;
	
	GetFile(FileData.FileBinaryDataRef, FileData.FileName);
	
	If Object.EDKind = PredefinedValue("Enum.EDKinds.BankStatement") Then
		LinksToRepository = "";
		ElectronicDocumentsServiceCallServer.GetStatementData(AttachedFile, LinksToRepository);
		If ValueIsFilled(LinksToRepository) Then
			GetFile(LinksToRepository, FileData.Description + ".txt");
		EndIf;
	EndIf;
	
	If (BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor")
				OR BankApplication = PredefinedValue("Enum.BankApplications.iBank2"))
			AND Object.EDKind = PredefinedValue("Enum.EDKinds.PaymentOrder") Then
		FileData = DataServiceEDBank(AttachedFile, UUID);
		If Not FileData = Undefined Then
			GetFile(FileData.FileBinaryDataRef, FileData.FileName);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure TrustThisCertificate(Command)
	
	AddCertificateToTrusted(Items.DS.CurrentData);
	
EndProcedure

&AtClient
Procedure GOTOEDLogEvent(Command)
	
	FormParameters = New Structure;
	
	Filter = New Structure;
	Filter.Insert("AttachedFile", Object.Ref);
	
	FormParameters.Insert("Filter", Filter);
	FormParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	OpenForm("InformationRegister.EDEventsLog.ListForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure OpenCertificate(Command)
	
	If Items.DS.CurrentData <> Undefined Then
		ShowCertificate(Items.DS.CurrentData.LineNumber, Items.DS.CurrentData.Imprint);
	Else
		ClearMessages();
		ErrorText = NStr("en = 'Select the certificates in the installed signatures list.'");
		CommonUseClientServer.MessageToUser(ErrorText);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckSignatures(Command)
	
	ClearMessages();
	
	If BankApplication = PredefinedValue("Enum.BankApplications.SberbankOnline") Then
		#If WebClient Then
			MessageText = NStr("en = 'Verification of signatures from WEB browser is impossible'");
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		#Else
			CheckParameters = New Structure;
			EDKindsArray = New Array;
			EDKindsArray.Add(Object.Ref);
			CheckParameters.Insert("EDArrayForCheckingSberbankDS", EDKindsArray);
			CheckParameters.Insert("SberbankDSCheckIndex", 0);
			CheckParameters.Insert("NotifyAboutESCheck");
			ElectronicDocumentsServiceClient.DetermineStatusOfSignaturesFromSberbank(Object.EDAgreement, CheckParameters);
			Return;
		#EndIf
	ElsIf BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
		ArrayChecks = New Array;
		ArrayChecks.Add(Object.Ref);
		CheckParameters = New Structure;
		CheckParameters.Insert("EDAgreement", Object.EDAgreement);
		CheckParameters.Insert("EDArrayForCheckThroughAdditionalDataProcessor", ArrayChecks);
		CheckParameters.Insert("CurrentSignaturesCheckIndexThroughAdditionalDataProcessor", 0);
		CheckParameters.Insert("NotifyAboutESCheck");
		ElectronicDocumentsServiceClient.StartCheckingSignaturesStatusesThroughAdditionalDataProcessor(
			Undefined, CheckParameters);
		Return;
	ElsIf BankApplication = PredefinedValue("Enum.BankApplications.iBank2") Then
		CheckParameters = New Structure;
		ND = New NotifyDescription("ValidateiBankSignatures2", ThisObject, CheckParameters);
		CheckParameters.Insert("HandlerAfterConnectingComponents", ND);
		ElectronicDocumentsServiceClient.EnableExternalComponentiBank2(CheckParameters);
		Return;
	Else
		If ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer() Then
			ElectronicDocumentsServiceCallServer.DetermineSignaturesStatuses(Object.Ref, True);
		Else
			ElectronicDocumentsServiceClient.DetermineSignaturesStatuses(Object.Ref);
		EndIf;
	EndIf;
	
	RefreshDataRepresentation();
	FillTableDS();
	
EndProcedure

&AtClient
Procedure SendEDConfirmation(Command)
	
	ElectronicDocumentsServiceClient.SendEDConfirmation(Object.FileOwner, Object.Ref);
	
EndProcedure

&AtClient
Procedure ConfirmED(Command)
	
	NewED = Undefined;
	ElectronicDocumentsServiceClient.ConfirmED(Object.FileOwner, Object.Ref, , NewED);
	RefreshDataRepresentation();

	If NewED <> Undefined Then
		
		OpenForm("Catalog.EDAttachedFiles.Form.EDViewForm", New Structure("Key", NewED),
			FormOwner, UUID, Window);
	EndIf;
	
EndProcedure

&AtClient
Procedure SendED(Command)
	
	ClearMessages();
	ElectronicDocumentsClient.GenerateSignSendED(Object.FileOwner, Object.Ref);
	
EndProcedure

&AtClient
Procedure Resend(Command)
	
	ElectronicDocumentsClient.ResendED(Object.FileOwner, Object.Ref);
	
EndProcedure

&AtClient
Procedure SignED(Command)
	
	ClearMessages();
	ElectronicDocumentsClient.GenerateSignSendED(Object.FileOwner, Object.Ref);
	
EndProcedure

&AtClient
Procedure ConfirmPayment(Command)
	
	If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
		ConnectionStructure = New Structure;
		ConnectionStructure.Insert("EDAgreement", Object.EDAgreement);
		ConnectionStructure.Insert("RunTryReceivingModule", False);
		
		HandlerAfterConnecting = New NotifyDescription("ConfirmPaymentThroughAdditionalProcessing", ThisObject);
		ConnectionStructure.Insert("AfterObtainingDataProcessorModule", HandlerAfterConnecting);
		
		ElectronicDocumentsServiceClient.GetExternalModuleThroughAdditionalProcessing(ConnectionStructure);
	Else
		ProcessingParameters = New Structure;
		ND = New NotifyDescription("ConfirmPaymentiBank2", ThisObject, ProcessingParameters);
		ProcessingParameters.Insert("HandlerAfterConnectingComponents", ND);
		ElectronicDocumentsServiceClient.EnableExternalComponentiBank2(Parameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure CancelED(Command)
	
	CancelRejectED();
	
EndProcedure

&AtClient
Procedure AcceptCancellation(Command)
	
	RejectCancellation = False;
	HandleCancellationOffer(RejectCancellation);
	
EndProcedure

&AtClient
Procedure RejectCancellation(Command)
	
	RejectCancellation = True;
	HandleCancellationOffer(RejectCancellation);
	
EndProcedure

&AtClient
Procedure AddComment(Command)
	
	ParametersStructure = New Structure("Definition", Comment);
	ChangeAttributeValuesOnServer(Object.Ref, ParametersStructure);
	Comment = "";
	Notify("RefreshStateED");
	
EndProcedure

&AtClient
Procedure Forward(Command)
	
	HandleEDRedirection();
	
EndProcedure

&AtClient
Procedure ClearNote(Command)
	
	If ValueIsFilled(Object.AdditionalInformation) Then
		ParametersStructure = New Structure("AdditionalInformation", "");
		ChangeAttributeValuesOnServer(Object.Ref, ParametersStructure);
		Notify("RefreshStateED");
	EndIf;
	
EndProcedure

&AtClient
Procedure RequestEDStatus(Command)
	
	Var DataAuthorization;
	
	If ElectronicDocumentsServiceClient.ReceivedAuthorizationData(Object.EDAgreement, DataAuthorization) Then
		SendEDStatusRequestToBank(DataAuthorization)
	Else
		OOOZ = New NotifyDescription("SendEDStatusRequestToBank", ThisObject);
		ElectronicDocumentsServiceClient.GetAuthenticationData(Object.EDAgreement, OOOZ);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ChangeAccompanyingNoteText(TextScraps)
	
	ParametersStructure = New Structure("AdditionalInformation", TextScraps);
	ChangeAttributeValuesOnServer(Object.Ref, ParametersStructure);
	ThisForm.Modified = False;
	
EndProcedure

&AtServerNoContext
Procedure ChangeAttributeValuesOnServer(Val Ref, Val ParametersStructure)
	
	If ParametersStructure.Property("Definition") AND ValueIsFilled(Ref.Responsible) Then
		ParametersStructure.Insert("Responsible", Ref.Responsible);
	EndIf;
	ElectronicDocumentsService.ChangeByRefAttachedFile(Ref, ParametersStructure, False);
	
	
EndProcedure

&AtClient
Procedure HandleEDRedirection()
	
	EDKindsArray = New Array;
	EDKindsArray.Add(Object.Ref);
	ElectronicDocumentsServiceClient.ChangeResponsiblePerson(EDKindsArray, Undefined);
	
EndProcedure

&AtServer
Procedure RefillComments()
	
	AllComments = "";
	Query = New Query;
	Query.Text =
		"SELECT
		|	EDEventsLog.User.Presentation AS User,
		|	EDEventsLog.Date AS Date,
		|	EDEventsLog.EDStatus,
		|	EDEventsLog.Responsible.Presentation AS Responsible,
		|	EDEventsLog.Comment
		|FROM
		|	InformationRegister.EDEventsLog AS EDEventsLog
		|WHERE
		|	EDEventsLog.AttachedFile = &Ref
		|	AND EDEventsLog.Comment <> &IsBlankString
		|
		|ORDER BY
		|	Date";
		
	Query.SetParameter("Ref", Object.Ref);
	Query.SetParameter("IsBlankString", "");
	Result = Query.Execute();
	Selection = Result.Select();
	CommentTemplate = NStr("en = '%1, %2 (status - %3, responsible person - %4): %5'");
	PreviousComment = "";
	FirstComment = True;
	Array = New Array;
	While Selection.Next() Do
		CurrentComment = TrimAll(Selection.Comment);
		If PreviousComment = CurrentComment Then
			Continue;
		EndIf;
		PreviousComment = CurrentComment;
		CommentString = StringFunctionsClientServer.PlaceParametersIntoString(CommentTemplate,
				Selection.Date, Selection.User, Selection.EDStatus, Selection.Responsible, CurrentComment);
		Array.Add(CommentString);
		FirstComment = False;
	EndDo;
	If Array.Count() > 0 Then
		FirstComment = True;
		For Ct = -Array.Count() + 1 To 0 Do
			CommentString = Array[-Ct];
			AllComments = AllComments
				+ CommentString
				+ ?(FirstComment, Chars.LF + "------------------------------------", "")
				+ Chars.LF
				+ Chars.LF;
			FirstComment = False;
		EndDo;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function UUIDExternal(ED)
	
	Return CommonUse.ObjectAttributeValue(ED, "UUIDExternal");
	
EndFunction

&AtServerNoContext
Procedure SetStatusDelivered(ED)
	
	EDStructure = New Structure("EDStatus", Enums.EDStatuses.Delivered);
	ElectronicDocumentsService.ChangeByRefAttachedFile(ED, EDStructure, False);
	
EndProcedure


&AtServerNoContext
Function SberbankFileArray(ED)
	
	ReturnArray = New Array;
	
	DigestStructure = New Structure;
	FileBasisName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(ED.Description);
	
	StringBase64 = ElectronicDocumentsServiceCallServer.DigitallySignedDataBase64(ED);
	DataFileName = "doc_" + FileBasisName + ".txt";
	BinaryData = Base64Value(StringBase64);
	DigestReference =  PutToTempStorage(BinaryData);
	DigestStructure = New Structure("FileReference, FileName", DigestReference, DataFileName);
	ReturnArray.Add(DigestStructure);
	
	For Each DS in ED.DigitalSignatures Do
		DSBinaryData = DS.Signature.Get();
		DataFileName = "sign_" + FileBasisName+ "_" + DS.LineNumber + ".txt";
		ReferenceToSign = PutToTempStorage(DSBinaryData);
		ReturnArray.Add(New Structure("FileReference, FileName", ReferenceToSign, DataFileName));
				
		CertificateBinaryData = DS.Certificate.Get();
		DataFileName = "cert_" + FileBasisName + "_" + DS.LineNumber + ".cer";
		ReferenceToCertificate = PutToTempStorage(CertificateBinaryData);
		ReturnArray.Add(New Structure("FileReference, FileName", ReferenceToCertificate, DataFileName));
	EndDo;

	FileData = ElectronicDocumentsService.GetFileData(ED);
	DataFileName = FileBasisName + ".xml";
	FileStructure = New Structure("FileReference, FileName", FileData.FileBinaryDataRef, DataFileName);
	ReturnArray.Add(FileStructure);
	
	Return ReturnArray;
	
EndFunction

&AtServer
Procedure ChangeStatusReject()
	
	ObjectDocument = FormAttributeToValue("Object");
	ParametersStructure = New Structure("EDStatus", Enums.EDStatuses.Rejected);
	ElectronicDocumentsService.ChangeByRefAttachedFile(Object.Ref, ParametersStructure, False);
	ValueToFormAttribute(ObjectDocument, "Object");
	
EndProcedure

&AtServer
Procedure ChangeVisibleEnabled()
	
	If ValueIsFilled(ThumbprintArrayReference) Then
		ThumbprintArray = GetFromTempStorage(ThumbprintArrayReference);
	Else
		ThumbprintArray = New Array;
	EndIf;
	
	ThisExchangeThroughAdditionalProcessor = Object.EDKind = Enums.EDKinds.PaymentOrder
								AND BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor;

	ThereIsPossibilityOfSigning = (ValueIsFilled(ThumbprintArray)
								  OR BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
								  OR BankApplication = Enums.BankApplications.iBank2
								  OR BankApplication = Enums.BankApplications.SberbankOnline)
								AND AvailableForSigningCertificates(ThumbprintArray);
	
	If ValueIsFilled(Object.ElectronicDocumentOwner) Then
		LinkToED = Object.ElectronicDocumentOwner;
	Else
		LinkToED = Object.Ref;
	EndIf;
	CanRejectThisED = ElectronicDocumentsServiceCallServer.CanRejectThisED(LinkToED);
	CanVoidThisED = ElectronicDocumentsServiceCallServer.CanVoidThisED(LinkToED);
	
	// Page representation:
	Items.DocumentContentGroup.PagesRepresentation = FormPagesRepresentation.None;
	Items.GroupToRight.ChildItems.CommandsPages.PagesRepresentation = FormPagesRepresentation.None;
	
	
	If Not Object.EDKind = Enums.EDKinds.BankStatement AND Not Items.Find("ReadCommand") = Undefined Then
		Items.ReadCommand.Visible = False;
	EndIf;
	
	EDRefused = ElectronicDocumentsServiceCallServer.EDRefused(Object.EDStatus);
	IsService = ElectronicDocumentsServiceCallServer.ThisIsServiceDocument(Object.Ref);
	
	EDTitleSeller = (Object.EDKind = Enums.EDKinds.TORG12Seller
					OR Object.EDKind = Enums.EDKinds.ActPerformer
					OR Object.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender);
	EDCustomerInvoiceNote = Object.EDKind = Enums.EDKinds.CustomerInvoiceNote
					OR Object.EDKind = Enums.EDKinds.CorrectiveInvoiceNote;
					
	CryptographyIsUsed = CommonUse.ObjectAttributeValue(Object.EDAgreement, "CryptographyIsUsed");
	If Not ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseDigitalSignatures")
		OR Not (CryptographyIsUsed = True)
		AND CommonUse.ObjectAttributeValue(Object.EDAgreement, "EDExchangeMethod") = Enums.EDExchangeMethods.ThroughBankWebSource
		AND ElectronicDocumentsService.ImmediateEDSending() Then
		Items.CommandApproveED.Title = NStr("en = 'Approve and send'");
	EndIf;
	
	If ElectronicDocumentsService.ImmediateEDSending() Then
		CommandSignaturesSend = Items.SendEDCommand;
	Else
		CommandSignaturesSend = Items.CommandSign;
	EndIf;
	
	If Object.EDDirection = Enums.EDDirections.Incoming Then
		
		Items.GroupToRight.ChildItems.CommandsPages.CurrentPage = Items.InboxCommandsGroup;
		
		If Object.EDKind = Enums.EDKinds.NotificationAboutReception
			OR Object.EDKind = Enums.EDKinds.Confirmation
			OR Object.EDKind = Enums.EDKinds.NotificationAboutClarification
			OR Object.EDKind = Enums.EDKinds.CancellationOffer
			OR Object.EDKind = Enums.EDKinds.BankStatement
			OR Object.EDKind = Enums.EDKinds.STATEMENT Then
			
			Items.RefillDocument.Visible = False;
		ElsIf Object.EDKind = Enums.EDKinds.ProductsDirectory Then
			Items.RefillDocument.Title = NStr("en = 'Compare ProductsAndServices'");
		ElsIf Object.EDKind = Enums.EDKinds.TORG12Customer
			OR Object.EDKind = Enums.EDKinds.ActCustomer
			OR Object.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient
			OR Object.Ref.EDKind = Enums.EDKinds.NotificationOnStatusOfED Then
			
			Items.RefillDocument.Visible = False;
		EndIf;
		
		IsReceivedProductsDirectory = Object.EDKind = Enums.EDKinds.ProductsDirectory
										AND Object.EDStatus = Enums.EDStatuses.Received;
		Items.RefillDocument.Enabled = Not EDRefused AND Not(IsReceivedProductsDirectory);
		
		ExchangeViaTaxcom = ExchangeThroughOperator();
		PackageFormatVersion = ElectronicDocumentsService.EDPackageVersion(Object.Ref);
		ThisAccountVersions30 = (Object.EDKind = Enums.EDKinds.InvoiceForPayment)
			AND (ExchangeViaTaxcom
				Or (PackageFormatVersion = Enums.EDPackageFormatVersions.Version30
					AND Not ExchangeViaTaxcom));
		
		// SendEDConfirmationCommand visible and accessibility:
		Items.SendEDConfirmationCommand.Visible = ThereIsPossibilityOfSigning
			AND Not EDCustomerInvoiceNote
			AND Not EDTitleSeller
			AND Object.EDKind <> Enums.EDKinds.TORG12Customer
			AND Object.EDKind <> Enums.EDKinds.ActCustomer
			AND Object.EDKind <> Enums.EDKinds.AgreementAboutCostChangeRecipient
			AND Not ThisAccountVersions30;
		
		Items.SendEDConfirmationCommand.Enabled = ThereIsPossibilityOfSigning
			AND Not EDRefused AND (Object.EDStatus = Enums.EDStatuses.Received
				OR Object.EDStatus = Enums.EDStatuses.Approved)
			AND (ReflectedInAccounting OR IsReceivedProductsDirectory);
		//
		
		// CommandApproveED visible and accessibility:
		Items.CommandApproveED.Visible = Object.EDKind <> Enums.EDKinds.TORG12Customer
			AND Object.EDKind <> Enums.EDKinds.ActCustomer
			AND Object.EDKind <> Enums.EDKinds.AgreementAboutCostChangeRecipient
			AND Object.EDKind <> Enums.EDKinds.BankStatement
			AND Object.EDKind <> Enums.EDKinds.STATEMENT
			AND Object.EDKind <> Enums.EDKinds.NotificationOnStatusOfED
			AND (NOT ThereIsPossibilityOfSigning OR EDCustomerInvoiceNote
				OR EDTitleSeller Or ThisAccountVersions30);
		
		Items.CommandApproveED.Enabled = (Object.EDStatus = Enums.EDStatuses.Received
			AND Not(Object.EDKind = Enums.EDKinds.NotificationAboutReception
				OR Object.EDKind = Enums.EDKinds.Confirmation
				OR Object.EDKind = Enums.EDKinds.CancellationOffer
				OR Object.EDKind = Enums.EDKinds.NotificationAboutClarification));
		//
		
		Items.TitleReflectedInAccounting.Enabled = Not EDRefused;
		
		If Object.EDKind = Enums.EDKinds.BankStatement Then
			Items.CommandChooseDocument.Visible = False;
		EndIf;
		
		// For incoming customer invoice note button Reject has its name and image
		If Object.Ref.EDKind = Enums.EDKinds.CustomerInvoiceNote
			Or Object.Ref.EDKind = Enums.EDKinds.CorrectiveInvoiceNote Then
			
			Items.RejectCommand.Title = NStr("en = 'Request clarification on the e-document'");
			Items.RejectCommand.Picture = PictureLib.UserWithoutNecessaryProperties;
		EndIf;
		
	ElsIf Object.EDDirection = Enums.EDDirections.Outgoing Then
		
		Items.GroupToRight.ChildItems.CommandsPages.CurrentPage = Items.GroupOutgCommands;
		
		Items.SendEDConfirmationCommand.Visible = False;
		Items.CommandChooseDocument.Visible          = False;
		
		If Object.EDKind = Enums.EDKinds.PaymentOrder Then
			UnidentifiedSignaturesNumber =  GetUnidentifiedSignaturesNumber();
			ISTransferError = (Object.EDStatus = Enums.EDStatuses.TransferError);
			If BankApplication = Enums.BankApplications.SberbankOnline Then
				Items.SendEDCommand.Visible = False;
				Items.CommandSign.Visible = UnidentifiedSignaturesNumber > 0 AND ThereIsPossibilityOfSigning;
				Items.Resend.Visible = False;
			Else
				Items.SendEDCommand.Visible = (UnidentifiedSignaturesNumber = 1) AND ThereIsPossibilityOfSigning;
				Items.CommandSign.Visible   = UnidentifiedSignaturesNumber > 1 AND ThereIsPossibilityOfSigning;
				Items.Resend.Visible = ISTransferError;
			EndIf;
		Else
			CommandSignaturesSend.Visible   = ThereIsPossibilityOfSigning AND SignatureRequired;
			CommandSignaturesSend.Enabled = Not EDRefused
				AND (ReflectedInAccounting OR Object.EDKind = Enums.EDKinds.TORG12Customer
					OR Object.EDKind = Enums.EDKinds.ActCustomer
					OR Object.EDKind = Enums.EDKinds.RightsDelegationAct
					OR Object.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient
					OR Object.EDKind = Enums.EDKinds.CancellationOffer
					OR Object.EDKind = Enums.EDKinds.NotificationAboutReception)
				AND (Object.EDStatus = Enums.EDStatuses.Created OR Object.EDStatus = Enums.EDStatuses.Approved);
			//
			
			If Object.EDFProfileSettings.EDExchangeMethod <> Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
				Items.Resend.Visible = True;
				Items.Resend.Enabled = Not EDRefused
					AND ReflectedInAccounting
					OR (Object.EDKind = Enums.EDKinds.NotificationAboutReception
						OR Object.EDKind = Enums.EDKinds.Confirmation
						OR Object.EDKind = Enums.EDKinds.CancellationOffer
						OR Object.EDKind = Enums.EDKinds.NotificationAboutClarification);
			EndIf;
			
			NoteAvailable = (NOT IsService
				AND (Object.EDStatus = Enums.EDStatuses.Created
					OR Object.EDStatus = Enums.EDStatuses.Approved
					OR Object.EDStatus = Enums.EDStatuses.DigitallySigned
					OR Object.EDStatus = Enums.EDStatuses.PreparedToSending));
			Items.ObjectAdditionalInformation.ReadOnly = Not NoteAvailable;
			Items.ClearNote.Enabled = NoteAvailable;
		EndIf;
		
		// CommandApproveED visible and accessibility:
		Items.CommandApproveED.Visible = Not (ThereIsPossibilityOfSigning AND SignatureRequired)
												AND Not Object.Ref.EDKind = Enums.EDKinds.QueryProbe;
		Items.CommandApproveED.Enabled = Object.EDStatus = Enums.EDStatuses.Created;
		//
	ElsIf Object.EDDirection = Enums.EDDirections.Intercompany Then
		
		Items.GroupToRight.ChildItems.CommandsPages.CurrentPage = Items.GroupOutgCommands;
		
		Items.SendEDConfirmationCommand.Visible = False;
		Items.CommandChooseDocument.Visible          = False;
		
		Items.CommandSign.Visible     = ThereIsPossibilityOfSigning;
		Items.CommandSign.Enabled   = (ThereIsPossibilityOfSigning
			AND Not EDRefused AND Object.EDStatus <> Enums.EDStatuses.FullyDigitallySigned);
		
		Items.CommandApproveED.Visible   = Not ThereIsPossibilityOfSigning;
		Items.CommandApproveED.Enabled = (Object.EDStatus = Enums.EDStatuses.Created);
		
	EndIf;
	
	Items.FormCancelED.Enabled = CanVoidThisED;
	Items.RejectCommand.Enabled = Not (EDRefused OR IsService) AND CanRejectThisED;
	Items.FormGroupCancellation.Visible = False;
	Items.FolderPagesFooter.CurrentPage = Items.GroupStatusesAndStates;
	
	If EDRefused Then
		RejectionReasons.Clear();
		NewRow = RejectionReasons.Add();
		NewRow.RejectionReason = Object.Ref.RejectionReason;
		Items.FolderPagesFooter.CurrentPage = Items.FolderPagesFooter.ChildItems.GroupPageRejection;
		
		If Object.EDStatus = Enums.EDStatuses.TransferError Then
			Items.RejectionReasonsRejectionReason.Title = NStr("en = 'Exchange error'");
			NewRow.RejectionReason = Object.RejectionReason;
		EndIf;
		
		If Object.EDKind = Enums.EDKinds.PaymentOrder
			AND BankApplication = Enums.BankApplications.SberbankOnline Then
			Items.FolderPagesFooter.CurrentPage = Items.ReceiptGroup;
			STATEMENT = ElectronicDocumentsInternal.SubordinateDocument(Object.Ref, Enums.EDKinds.STATEMENT);
		EndIf;
	ElsIf UNTILCanceledOrInProcess() Then
		RejectionReasons.Clear();
		NewRow = RejectionReasons.Add();
		NewRow.RejectionReason = LinkToED.RejectionReason;
		
		Items.FolderPagesFooter.CurrentPage = Items.FolderPagesFooter.ChildItems.GroupPageRejection;
		Items.RejectionReasonsRejectionReason.Title = NStr("en = 'Cancellation reason'");
		Items.RejectCommand.Enabled = False;
		If Object.EDStatus = Enums.EDStatuses.CancellationOfferReceived
			OR Object.EDKind = Enums.EDKinds.CancellationOffer
			AND Object.EDStatus = Enums.EDStatuses.Received
			OR ValueIsFilled(Object.ElectronicDocumentOwner)
			AND CommonUse.ObjectAttributeValue(Object.ElectronicDocumentOwner, "EDStatus") = Enums.EDStatuses.CancellationOfferReceived Then
			Items.FormGroupCancellation.Visible = True;
			Items.SendEDConfirmationCommand.Visible = False;
			Items.SendEDCommand.Visible = False;
			Items.RejectCommand.Visible = False;
			Items.FormCancelED.Visible = False;
			Items.FormAcceptCancellation.OnlyInAllActions = Not (Object.EDKind = Enums.EDKinds.CancellationOffer);
			Items.FormRejectCancellation.OnlyInAllActions = Not (Object.EDKind = Enums.EDKinds.CancellationOffer);
		EndIf;
	EndIf;
	
	If Not IsAllowedToDeclineED() Then
		Items.RejectCommand.Visible = False;
	EndIf;
	
	Items.FormForward.Visible = Not IsService AND Not ValueIsFilled(BankApplication);
	
	ClearNotificationOfIrrelevant();
	SetFormTitle();
	
	Items.GroupPageFooterComments.Picture = CommonUse.GetCommentPicture(AllComments);
	Items.GroupPageFooterNote.Picture = CommonUse.GetCommentPicture(Object.AdditionalInformation);
	
	Items.RequestEDStatus.Visible = (BankApplication = Enums.BankApplications.AsynchronousExchange)
		AND (Object.EDStatus = Enums.EDStatuses.Accepted OR Object.EDStatus = Enums.EDStatuses.Sent
			OR Object.EDStatus = Enums.EDStatuses.Delivered OR Object.EDStatus = Enums.EDStatuses.Suspended
			OR Object.EDStatus = Enums.EDStatuses.CardFile2);
		
	Items.GroupPageFooterNote.Visible = Not ValueIsFilled(BankApplication);
	
	Items.CommandConfirmPayment.Visible = (BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
													OR BankApplication = Enums.BankApplications.iBank2)
												AND Object.Ref.EDStatus = Enums.EDStatuses.Sent;
	
EndProcedure

&AtServer
Function ExchangeThroughOperator()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EDUsageAgreementsOutgoingDocuments.EDExchangeMethod AS EDExchangeMethod
	|FROM
	|	Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
	|WHERE
	|	EDUsageAgreementsOutgoingDocuments.Ref = &Ref
	|	AND EDUsageAgreementsOutgoingDocuments.OutgoingDocument = &OutgoingDocument";
	Query.SetParameter("Ref", Object.EDAgreement);
	Query.SetParameter("OutgoingDocument", Object.EDKind);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return False;
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	If Selection.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
		Return True
	Else
		Return False;
	EndIf;
	
	
EndFunction

&AtServer
Function IsAllowedToDeclineED()
	
	If Object.EDKind = Enums.EDKinds.PaymentOrder Then
		If Object.EDStatus = Enums.EDStatuses.NotSent 
			OR Object.EDStatus = Enums.EDStatuses.DigitallySigned
			OR Object.EDStatus = Enums.EDStatuses.Created
			OR Object.EDStatus = Enums.EDStatuses.Approved
			OR Object.EDStatus = Enums.EDStatuses.PartlyDigitallySigned Then
				Return True;
		Else
			Return False;
		EndIf;
	EndIf;
	Return True;
	
EndFunction

&AtServer
Procedure SetFormTitle()
	
	If Not ReflectedInAccounting AND Not (Object.Ref.EDKind = Enums.EDKinds.NotificationAboutReception
								OR Object.Ref.EDKind = Enums.EDKinds.Confirmation
								OR Object.Ref.EDKind = Enums.EDKinds.NotificationAboutClarification
								OR Object.Ref.EDKind = Enums.EDKinds.CancellationOffer
								OR Object.Ref.EDKind = Enums.EDKinds.BankStatement
								OR Object.Ref.EDKind = Enums.EDKinds.STATEMENT
								OR Object.Ref.EDKind = Enums.EDKinds.QueryStatement
								OR Object.Ref.EDKind = Enums.EDKinds.EDStateQuery
								OR Object.Ref.EDKind = Enums.EDKinds.NotificationOnStatusOfED
								OR Object.Ref.EDKind = Enums.EDKinds.QueryProbe) Then
		
		If Not ValueIsFilled(EDVersion) OR Object.Ref.EDFormingDateBySender <= EDVersion Then
			Title = Title + NStr("en = ' - out of date'");
		ElsIf Object.EDFormingDateBySender > EDVersion Then
			Title = Title + NStr("en = ' - new'");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ClearNotificationOfIrrelevant()
	
	Title = StrReplace(Title, NStr("en = ' - out of date'"), "");
	Title = StrReplace(Title, NStr("en = ' - new'"), "");
	
EndProcedure

&AtServer
Procedure UpdateEDStatus(EDStatus = Undefined, EDStatusChangeDate = Undefined)
	
	If Not ValueIsFilled(EDStatus) Then
		EDStatus = Object.Ref.EDStatus;
	EndIf;
	If Not ValueIsFilled(EDStatusChangeDate) Then
		EDStatusChangeDate = Object.Ref.EDStatusChangeDate;
	EndIf;
	
	EDStatusText = " " +  EDStatus + ", " + Format(EDStatusChangeDate, "DLF=");
	StatusText = ElectronicDocumentsClientServer.GetTextOfEDState(Object.FileOwner);
	TextIBDocument = String(Object.FileOwner);
	
	QueryByReflection = New Query;
	QueryByReflection.SetParameter("ObjectReference", Object.FileOwner);
	
	QueryByReflection.Text =
	"SELECT
	|	EDStates.ObjectReference,
	|	EDStates.ElectronicDocument
	|FROM
	|	InformationRegister.EDStates AS EDStates
	|WHERE
	|	EDStates.ObjectReference = &ObjectReference";
	
	Selection = QueryByReflection.Execute().Select();
	If Selection.Next() Then
		EDVersion = CommonUse.ObjectAttributeValue(Selection.ElectronicDocument, "EDFormingDateBySender");
		ReflectedInAccounting = (Object.Ref = Selection.ElectronicDocument);
	EndIf;
	
	StatusTable = GetEDStatusTable(Object.Ref);
	If ValueIsFilled(StatusTable) Then
		ValueToFormAttribute(StatusTable, "EDStatuses");
	EndIf;
	
EndProcedure

&AtServer
Procedure FillTableDS()
	
	If Not ValueIsFilled(Object.Ref.EDAgreement)
		OR Not Object.Ref.EDAgreement.VerifySignatureCertificates Then
		
		TableDS = FormAttributeToValue("DS");
		TableDS.Clear();
		
		For Each CurRow IN Object.Ref.DigitalSignatures Do
			NewRow = TableDS.Add();
			FillPropertyValues(NewRow, CurRow);
			FillSignatureStatus(NewRow, CurRow);
		EndDo;
		
		ValueToFormAttribute(TableDS, "DS");
		Return;
	EndIf;
	
	ExpectedCertificateTumbprintsArray = ElectronicDocumentsService.ExpectedCertificateThumbprints(Object.Ref);
	
	TableDS = FormAttributeToValue("DS");
	TableDS.Clear();
	
	For Each CurRow IN Object.Ref.DigitalSignatures Do
		NewRow = TableDS.Add();
		FillPropertyValues(NewRow, CurRow);
		If ExpectedCertificateTumbprintsArray.Find(CurRow.Imprint) = Undefined Then
			NewRow.MissingInList = True;
			NewRow.OutputImages = 1;
		Else
			NewRow.OutputImages = 0;
		EndIf;
		FillSignatureStatus(NewRow, CurRow);
	EndDo;
	ValueToFormAttribute(TableDS, "DS");
	
EndProcedure

&AtServer
Procedure FillSignatureStatus(NewRow, CurRow)
	
	If ValueIsFilled(CurRow.SignatureVerificationDate) Then
		NewRow.SignatureIsCorrect = ?(CurRow.SignatureIsCorrect, NStr("en = 'Correct'"), NStr("en = 'Wrong'"))
			+" (" + CurRow.SignatureVerificationDate + ")";
	Else
		NewRow.SignatureIsCorrect = NStr("en = 'Not checked'");
	EndIf
	
EndProcedure

&AtServer
Function RequiredToSign()
	
	SignatureFlag = False;
	// Order response a customer never signs or the document is rejected.
	If Not EDRefused Then
		
		If Object.Ref.EDFProfileSettings.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
			SignatureFlag = True;
		Else
			
			SetPrivilegedMode(True);
			
			If Object.Ref.EDDirection = Enums.EDDirections.Incoming Then
				SignatureFlag = Object.Ref.DigitallySigned;
			ElsIf Object.Ref.EDDirection = Enums.EDDirections.Outgoing
				OR Object.Ref.EDDirection = Enums.EDDirections.Intercompany Then
				
				If Object.EDKind = Enums.EDKinds.NotificationAboutReception Then
					
					SignatureFlag = Object.ElectronicDocumentOwner.DigitallySigned;
					
				Else
					
					Query = New Query;
					Query.Text =
					"SELECT
					|	EDUsageAgreementsOutgoingDocuments.UseDS
					|FROM
					|	Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
					|WHERE
					|	EDUsageAgreementsOutgoingDocuments.OutgoingDocument = &EDKind
					|	AND (&EDDirection = VALUE(Enum.EDDirections.Outgoing)
					|			OR &EDDirection = VALUE(Enum.EDDirections.Intercompany))
					|	AND EDUsageAgreementsOutgoingDocuments.Ref = &Ref";
					Query.SetParameter("Ref",        Object.Ref.EDAgreement);
					Query.SetParameter("EDKind",         Object.Ref.EDKind);
					Query.SetParameter("EDDirection", Object.Ref.EDDirection);
					
					Result = Query.Execute().Select();
					Result.Next();
					
					SignatureFlag = Result.UseDS;
					
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return SignatureFlag;
	
EndFunction

&AtServer
Function AvailableForSigningCertificates(ThumbprintArray)
	
	QueryByCertificates = New Query;
	QueryByCertificates.Text =
	"SELECT ALLOWED DISTINCT
	|	Certificates.Ref
	|FROM
	|	InformationRegister.DigitallySignedEDKinds AS EDEPKinds
	|		INNER JOIN Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
	|			INNER JOIN (SELECT DISTINCT
	|				EDFProfilesCertificates.Certificate AS Certificate
	|			FROM
	|				Catalog.EDAttachedFiles AS EDAttachedFiles
	|					LEFT JOIN Catalog.EDFProfileSettings.CompanySignatureCertificates AS EDFProfilesCertificates
	|					ON EDAttachedFiles.EDFProfileSettings = EDFProfilesCertificates.Ref
	|			WHERE
	|				EDAttachedFiles.Ref = &Ref
			
	|			UNION ALL
			
	|			SELECT
	|				AgreementsEDCertificates.Certificate
	|			FROM
	|				Catalog.EDAttachedFiles AS EDAttachedFiles
	|					LEFT JOIN Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsEDCertificates
	|					ON EDAttachedFiles.EDAgreement = AgreementsEDCertificates.Ref
	|			WHERE
	|				EDAttachedFiles.Ref = &Ref) AS CertificatesFromSettingsAndProfiles
	|			ON CertificatesFromSettingsAndProfiles.Certificate = Certificates.Ref
	|		ON EDEPKinds.DSCertificate = Certificates.Ref
	|WHERE
	|	Not Certificates.Revoked
	|	AND (Certificates.User = &CurrentUser
	|			OR Certificates.User = VALUE(Catalog.Users.EmptyRef))
	|	AND Not Certificates.DeletionMark
	|	AND EDEPKinds.EDKind = &DocumentKind
	|	AND EDEPKinds.Use
	|	AND TRUE";
	
	If Object.EDKind = Enums.EDKinds.PaymentOrder
			AND (BankApplication = Enums.BankApplications.SberbankOnline
				OR BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
				OR BankApplication = Enums.BankApplications.iBank2) Then

		CertificatesArrayRequiredSignatures = Object.EDAgreement.CompanySignatureCertificates.UnloadColumn(
																										"Certificate");
		AdditionalCondition = " Certificates.Refs IN(&CertificatesArrayRequiredSignatures)";
		QueryByCertificates.SetParameter("CertificatesArrayRequiredSignatures",
												CertificatesArrayRequiredSignatures);
	Else
		
		QueryByCertificates.SetParameter("ThumbprintArray", ThumbprintArray);
		AdditionalCondition = " Certificates.Thumbprint IN(&ThumbprintArray)";
	EndIf;
	
	QueryByCertificates.Text = StrReplace(QueryByCertificates.Text, "TRUE", AdditionalCondition);
	
	QueryByCertificates.SetParameter("CurrentUser", Users.AuthorizedUser());
	QueryByCertificates.SetParameter("DocumentKind",        Object.EDKind);
	QueryByCertificates.SetParameter("Ref",              Object.Ref);

	IsUsedES = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
																	"UseDigitalSignatures")
						OR BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
						OR BankApplication = Enums.BankApplications.SberbankOnline
						OR BankApplication = Enums.BankApplications.iBank2;
	
	ReturnedParameter = IsUsedES AND Not QueryByCertificates.Execute().IsEmpty() AND SignatureRequired;
		
	Return ReturnedParameter;
	
EndFunction

&AtServer
Function EDDataFile(LinkToED = Undefined, Val SubordinatedEDFileName = Undefined)
	
	If LinkToED = Undefined Then
		LinkToED = Object.Ref;
	EndIf;
	
	AdditInformationAboutED = ElectronicDocumentsService.GetFileData(LinkToED, LinkToED.UUID(), True);
	
	If AdditInformationAboutED.Property("FileBinaryDataRef")
		AND ValueIsFilled(AdditInformationAboutED.FileBinaryDataRef) Then
		
		EDData = GetFromTempStorage(AdditInformationAboutED.FileBinaryDataRef);
		
		If ValueIsFilled(AdditInformationAboutED.Extension) Then
			FileName = ElectronicDocumentsService.TemporaryFileCurrentName(AdditInformationAboutED.Extension);
		Else
			FileName = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
		EndIf;
		
		If FileName = Undefined Then
			ErrorText = NStr("en = 'Unable to view electronic document. Verify the work directory setting'");
			CommonUseClientServer.MessageToUser(ErrorText);
			Return Undefined;
		EndIf;
		
		SelectionEDAddData = ElectronicDocumentsService.SelectionAdditDataED(LinkToED);
		If SelectionEDAddData.Next() Then
			AdditDataED = ElectronicDocumentsService.GetFileData(SelectionEDAddData.Ref,
				SelectionEDAddData.Ref.UUID(), True);
			RefToDDAdditDataED = "";
			If AdditDataED.Property("FileBinaryDataRef", RefToDDAdditDataED)
				AND ValueIsFilled(RefToDDAdditDataED) Then
				AdditFileData = GetFromTempStorage(RefToDDAdditDataED);
			
				If ValueIsFilled(AdditDataED.Extension) Then
					AdditDataFileName = ElectronicDocumentsService.TemporaryFileCurrentName(AdditDataED.Extension);
				Else
					AdditDataFileName = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
				EndIf;
			
				If AdditDataFileName = Undefined Then
					ErrorText = NStr("en = 'Unable to get additional data of the electronic document. Verify the work directory setting'");
					CommonUseClientServer.MessageToUser(ErrorText);
					Return Undefined;
				EndIf;
				AdditFileData.Write(AdditDataFileName);
			EndIf;
		EndIf;
		
		EDData.Write(FileName);
		
		If LinkToED.EDKind = Enums.EDKinds.TORG12Customer
			OR LinkToED.EDKind = Enums.EDKinds.ActCustomer
			OR LinkToED.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient Then
			
			SpreadsheetDocument = EDDataFile(LinkToED.ElectronicDocumentOwner, FileName);
			Return SpreadsheetDocument;
		ElsIf Find(AdditInformationAboutED.Extension, "zip") > 0 Then
			
			ZIPReading = New ZipFileReader(FileName);
			FolderForUnpacking = ElectronicDocumentsService.WorkingDirectory(,LinkToED.UUID());
			
			If FolderForUnpacking = Undefined Then
				ErrorText = NStr("en = 'Unable to view electronic document. Verify the work directory setting'");
				CommonUseClientServer.MessageToUser(ErrorText);
				Return Undefined;
			EndIf;
			
			Try
				ZipReading.ExtractAll(FolderForUnpacking);
			Except
				ErrorText = BriefErrorDescription(ErrorInfo());
				If Not ElectronicDocumentsService.PossibleToExtractFiles(ZipReading, FolderForUnpacking) Then
					MessageText = ElectronicDocumentsReUse.GetMessageAboutError("006");
				EndIf;
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en = 'ED package Unpacking'"),
					ErrorText, MessageText);
				DeleteFiles(FolderForUnpacking);
				Return Undefined;
			EndTry;
			
			ViewingFlag = False;
			
			If LinkToED.EDKind = Enums.EDKinds.RightsDelegationAct Then
				PDFArchiveFiles = FindFiles(FolderForUnpacking, "*.pdf");
				For Each UnpackedFile IN PDFArchiveFiles Do
					FileBinaryData = New BinaryData(UnpackedFile.FullName);
					FileReference = PutToTempStorage(FileBinaryData, UUID);
					DeleteFiles(FolderForUnpacking);
					Return FileReference;
				EndDo;
			EndIf;
			
			XMLArchiveFiles = FindFiles(FolderForUnpacking, "*.xml");
			
			For Each UnpackedFile IN XMLArchiveFiles Do
				
				DataFileName = UnpackedFile.FullName;
				If Find(UnpackedFile.Name, "packageDescription") Then
					FileBinaryData = New BinaryData(FileName);
					FileReference = PutToTempStorage(FileBinaryData, UUID);
					DeleteFiles(FolderForUnpacking);
					Return FileReference;
				EndIf;
				
				SpreadsheetDocument = ElectronicDocumentsInternal.GenerateEDPrintForm(UnpackedFile.FullName,
																								LinkToED.EDDirection,
																								LinkToED.UUID(),
																								,
																								AdditInformationAboutED.Description,
																								AdditDataFileName);
					
				If TypeOf(SpreadsheetDocument) = Type("SpreadsheetDocument") Then
					DeleteFiles(FolderForUnpacking);
					Return SpreadsheetDocument;
				EndIf;
				
			EndDo;
			
			MXLArchiveFiles = FindFiles(FolderForUnpacking, "*.mxl");
			For Each UnpackedFile IN MXLArchiveFiles Do
				DataFileName = UnpackedFile.FullName;
				SpreadsheetDocument = New SpreadsheetDocument;
				SpreadsheetDocument.Read(DataFileName);
				DeleteFiles(FolderForUnpacking);
				Return SpreadsheetDocument;
			EndDo;
			
			HTMLArchiveFiles = FindFiles(FolderForUnpacking, "*.html");
			For Each UnpackedFile IN HTMLArchiveFiles Do
				FileBinaryData = New BinaryData(UnpackedFile.FullName);
				FileReference = PutToTempStorage(FileBinaryData, UUID);
				DeleteFiles(FolderForUnpacking);
				Return FileReference;
			EndDo;
			
			DOCXArchiveFiles = FindFiles(FolderForUnpacking, "*.docx");
			For Each UnpackedFile IN DOCXArchiveFiles Do
				FileBinaryData = New BinaryData(UnpackedFile.FullName);
				FileReference = PutToTempStorage(FileBinaryData, UUID);
				DeleteFiles(FolderForUnpacking);
				Return FileReference;
			EndDo;
			
			XLSArchiveFiles = FindFiles(FolderForUnpacking, "*.xls");
			For Each UnpackedFile IN XLSArchiveFiles Do
				FileBinaryData = New BinaryData(UnpackedFile.FullName);
				FileReference = PutToTempStorage(FileBinaryData, UUID);
				DeleteFiles(FolderForUnpacking);
				Return FileReference;
			EndDo;
			
			XMLArchiveFiles = FindFiles(FolderForUnpacking, "*.xml");
			For Each UnpackedFile IN XMLArchiveFiles Do
				FileBinaryData = New BinaryData(UnpackedFile.FullName);
				FileReference = PutToTempStorage(FileBinaryData, UUID);
				DeleteFiles(FolderForUnpacking);
				Return FileReference;
			EndDo;
			
		ElsIf Find(AdditInformationAboutED.Extension, "xml") > 0 Then
			If LinkToED.EDKind = Enums.EDKinds.Confirmation
				OR LinkToED.EDKind = Enums.EDKinds.NotificationAboutReception
				OR LinkToED.EDKind = Enums.EDKinds.NotificationAboutClarification
				OR LinkToED.EDKind = Enums.EDKinds.CancellationOffer
				OR LinkToED.EDKind = Enums.EDKinds.TORG12Seller
				OR LinkToED.EDKind = Enums.EDKinds.ActPerformer
				OR LinkToED.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender
				OR LinkToED.EDKind = Enums.EDKinds.CustomerInvoiceNote
				OR LinkToED.EDKind = Enums.EDKinds.CorrectiveInvoiceNote
				OR LinkToED.EDKind = Enums.EDKinds.EDStateQuery
				OR LinkToED.EDKind = Enums.EDKinds.NotificationOnStatusOfED
				OR LinkToED.EDKind = Enums.EDKinds.QueryProbe Then
			
				DataFileName = FileName;
				SpreadsheetDocument = ElectronicDocumentsInternal.GenerateEDPrintForm(
																			FileName,
																			LinkToED.EDDirection,
																			LinkToED.UUID(),
																			SubordinatedEDFileName,
																			AdditInformationAboutED.Description,
																			AdditDataFileName);
			
				If TypeOf(SpreadsheetDocument) = Type("SpreadsheetDocument") Then
					Return SpreadsheetDocument;
				EndIf;
			
			ElsIf LinkToED.EDKind = Enums.EDKinds.PaymentOrder
				OR LinkToED.EDKind = Enums.EDKinds.QueryStatement
				OR LinkToED.EDKind = Enums.EDKinds.BankStatement
				OR LinkToED.EDKind = Enums.EDKinds.STATEMENT Then
			
				DataFileName = FileName;
				SpreadsheetDocument = ElectronicDocumentsInternal.GenerateEDPrintForm(
																			FileName,
																			LinkToED.EDDirection,
																			LinkToED.UUID(),
																			SubordinatedEDFileName,
																			LinkToED.UUID());
			
				If TypeOf(SpreadsheetDocument)=Type("SpreadsheetDocument") Then
					Return SpreadsheetDocument;
				EndIf;

			EndIf;
		Else
			FileBinaryData = New BinaryData(FileName);
			FileReference = PutToTempStorage(FileBinaryData, UUID);
			Return FileReference;
		EndIf;
		
	EndIf;
	
EndFunction

&AtServer
Procedure ExecuteViewEDFromIBServer(Cancel = False)
	
	EDData = EDDataFile();
	If EDData = Undefined Then
		Return;
	EndIf;
	If TypeOf(EDData) = Type("SpreadsheetDocument") Then
		FormTableDocument = EDData;
		OriginalTableDocument = EDData;
		DeterminePresenceOfAdditionalInformationHideFlag();
		If AdditionalInformationExists Then
			HideAdditionalInformation(DisableOutputAdditionalInformation);
		EndIf;
		Items.DocumentContentGroup.CurrentPage = Items.PageTableDocument;
	Else
		If TypeOf(EDData) = Type("String") Then
			FileAddressAtRepository = EDData;
		Else
			Cancel = True;
			Return;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteNotificationProcessingAtServer()
	
	ExecuteViewEDFromIBServer();
	ValueToFormAttribute(Object.Ref.GetObject(), "Object");
	FillTableDS();
	UpdateEDStatus();
	RefillComments();
	ChangeVisibleEnabled();
	
EndProcedure

&AtServer
Procedure RebindElectronicDocument(ValueSelected)
	
	ElectronicDocument = FormAttributeToValue("Object");
	OldOwner = ElectronicDocument.FileOwner;
	ElectronicDocument.FileOwner = ValueSelected;
	If Not ValueIsFilled(ElectronicDocument.Author) Then
		ElectronicDocument.Author = Users.AuthorizedUser();
	EndIf;
	ElectronicDocument.Write();
	
	UpdateOwnersEDState(ElectronicDocument.Ref, OldOwner, ValueSelected);
	ValueToFormAttribute(ElectronicDocument, "Object");
	
	TextIBDocument = String(Object.FileOwner.Ref);
	
EndProcedure

&AtServer
Procedure UpdateOwnersEDState(ED, OldOwner, NewOwner)
	
	SetPrivilegedMode(True);
	
	Query = New Query();
	Query.Text =
	"SELECT TOP 1
	|	EDStates.ObjectReference
	|FROM
	|	InformationRegister.EDStates AS EDStates
	|WHERE
	|	EDStates.ElectronicDocument = &ElectronicDocument
	|	AND EDStates.ObjectReference = &LinkToOldDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	EDStates.ObjectReference
	|FROM
	|	InformationRegister.EDStates AS EDStates
	|WHERE
	|	(NOT EDStates.ElectronicDocument = VALUE(Catalog.EDAttachedFiles.EmptyRef))
	|	AND EDStates.ObjectReference = &LinkToNewDocument";
	
	Query.SetParameter("ElectronicDocument", ED);
	Query.SetParameter("LinkToOldDocument", OldOwner);
	Query.SetParameter("LinkToNewDocument", NewOwner);
	
	Selection = Query.ExecuteBatch();
	
	ElectronicDocumentsServiceCallServer.SetEDNewVersion(OldOwner, Undefined);
	
	Result2 = Selection[1].Select();
	If Not Result2.Next() Then
		ElectronicDocumentsServiceCallServer.SetEDNewVersion(NewOwner, ED);
	EndIf;
	
EndProcedure

&AtServer
Procedure AddStatus(EDStatusMap, Status, Value = False)
	
	NewRow = EDStatusMap.Add();
	NewRow.Status = Status;
	NewRow.Passed = Value;
	
EndProcedure

&AtServer
Procedure FillEDStatusMap(EDStatusMap, ED)
	
	EDParameters = CommonUse.ObjectAttributesValues(ED.Ref,
		"EDKind, EDDirection, EDFScheduleVersion, Company, Counterparty, EDAgreement, EDFProfileSettings, DigitallySigned");
	
	StatusSettings = New ValueTable;
	StatusSettings.Columns.Add("ExchangeMethod");
	StatusSettings.Columns.Add("Direction");
	StatusSettings.Columns.Add("EDKind");
	StatusSettings.Columns.Add("UseSignature");
	StatusSettings.Columns.Add("UseReceipt");
	StatusSettings.Columns.Add("UsedFewSignatures");
	StatusSettings.Columns.Add("EDFScheduleVersion");
	StatusSettings.Columns.Add("BankApplication");
	StatusSettings.Columns.Add("PackageFormatVersion");
	
	DSUsed = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
															"UseDigitalSignatures");
	
	If EDParameters.EDKind = Enums.EDKinds.NotificationAboutReception
		OR EDParameters.EDKind = Enums.EDKinds.Confirmation
		OR EDParameters.EDKind = Enums.EDKinds.PaymentOrder
		OR EDParameters.EDKind = Enums.EDKinds.QueryStatement
		OR ((EDParameters.EDKind = Enums.EDKinds.TORG12Customer
			OR EDParameters.EDKind = Enums.EDKinds.TORG12Seller
			OR EDParameters.EDKind = Enums.EDKinds.ActPerformer
			OR EDParameters.EDKind = Enums.EDKinds.ActCustomer
			OR EDParameters.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender
			OR EDParameters.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient)
			AND EDParameters.EDDirection = Enums.EDDirections.Incoming)
		OR EDParameters.EDKind = Enums.EDKinds.CancellationOffer
		OR EDParameters.EDKind = Enums.EDKinds.NotificationAboutClarification Then
		
		AgreementAttributes = CommonUse.ObjectAttributesValues(EDParameters.EDAgreement,
			"EDExchangeMethod, BankApplication, CryptographyIsUsed");
		EDFProfileSettingsAttributes = CommonUse.ObjectAttributesValues(EDParameters.EDFProfileSettings,
			"EDExchangeMethod");
		
		NewRow = StatusSettings.Add();
		If AgreementAttributes.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource Then
			NewRow.ExchangeMethod = AgreementAttributes.EDExchangeMethod;
		Else
			NewRow.ExchangeMethod = EDFProfileSettingsAttributes.EDExchangeMethod;
		EndIf;
		NewRow.Direction         = EDParameters.EDDirection;
		NewRow.EDKind               = EDParameters.EDKind;
		If AgreementAttributes.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource Then
			NewRow.UseSignature = AgreementAttributes.CryptographyIsUsed;
		Else
			NewRow.UseSignature = DSUsed;
		EndIf;
		NewRow.UseReceipt = False;
		NewRow.UsedFewSignatures = EDParameters.EDAgreement.CompanySignatureCertificates.Count() > 1;
		NewRow.EDFScheduleVersion   = EDParameters.EDFScheduleVersion;
		NewRow.BankApplication        = AgreementAttributes.BankApplication;
	Else
		
		AgreementAttributes = CommonUse.ObjectAttributesValues(EDParameters.EDAgreement, "BankApplication");
		
		EDExchangeMethod = ExchangeMethodToPMAgreements(EDParameters.EDAgreement, EDParameters.EDKind);
		
		AgreementAttributes.Insert("EDExchangeMethod", EDExchangeMethod);
		
		If EDParameters.EDDirection = Enums.EDDirections.Incoming Then
			
			
			NewRow = StatusSettings.Add();
			NewRow.ExchangeMethod        = AgreementAttributes.EDExchangeMethod;
			NewRow.Direction         = EDParameters.EDDirection;
			NewRow.EDKind               = EDParameters.EDKind;
			NewRow.UseSignature = SignatureRequired;
			
			EDPackageVersion = ElectronicDocumentsService.EDPackageVersion(ED);
			
			NewRow.PackageFormatVersion = EDPackageVersion;
			
			If EDPackageVersion = Enums.EDPackageFormatVersions.Version30 Then
				UseReceipt = False;
			Else
				UseReceipt = True;
			EndIf;
			NewRow.UseReceipt = UseReceipt;
			
			NewRow.UsedFewSignatures = EDParameters.EDAgreement.CompanySignatureCertificates.Count() > 1;
			NewRow.EDFScheduleVersion   = EDParameters.EDFScheduleVersion;
			NewRow.BankApplication        = AgreementAttributes.BankApplication;
			
		Else
			
			Query = New Query;
			Query.SetParameter("EDKind",           EDParameters.EDKind);
			Query.SetParameter("EDDirection",   EDParameters.EDDirection);
			Query.SetParameter("Counterparty",      EDParameters.Counterparty);
			Query.SetParameter("Company",     EDParameters.Company);
			Query.SetParameter("DSUsed", DSUsed);
			Query.Text =
			"SELECT
			|	CASE
			|		WHEN &DSUsed
			|			THEN Agreement.UseSignature
			|		ELSE FALSE
			|	END AS UseSignature,
			|	Agreement.UseReceipt,
			|	Agreement.EDKind,
			|	Agreement.Direction,
			|	Agreement.ExchangeMethod,
			|	Agreement.PackageFormatVersion,
			|	Agreement.BankApplication
			|FROM
			|	
			|	(SELECT
			|		EDUsageAgreementsOutgoingDocuments.UseDS AS UseSignature,
			|		True AS UseReceipt,
			|		CASE
			|			WHEN &EDDirection = VALUE(Enum.EDDirections.Intercompany)
			|				THEN VALUE(Enum.EDDirections.Intercompany)
			|			ELSE VALUE(Enum.EDDirections.Outgoing)
			|		END AS Direction,
			|		EDUsageAgreementsOutgoingDocuments.OutgoingDocument AS EDKind,
			|		EDUsageAgreementsOutgoingDocuments.EDExchangeMethod AS ExchangeMethod,
			|		0 AS Priority,
			|		EDUsageAgreementsOutgoingDocuments.Ref.PackageFormatVersion AS PackageFormatVersion,
			|		EDUsageAgreementsOutgoingDocuments.Ref.BankApplication AS BankApplication
			|	FROM
			|		Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
			|	WHERE
			|		EDUsageAgreementsOutgoingDocuments.Ref.Company = &Company
			|		AND EDUsageAgreementsOutgoingDocuments.Ref.Counterparty = &Counterparty
			|		AND EDUsageAgreementsOutgoingDocuments.OutgoingDocument = &EDKind
			|		AND EDUsageAgreementsOutgoingDocuments.Ref.ConnectionStatus = VALUE(Enum.EDExchangeMemberStatuses.Connected)
			|		AND EDUsageAgreementsOutgoingDocuments.ToForm
			|		AND Not EDUsageAgreementsOutgoingDocuments.Ref.DeletionMark
			|	
			|	UNION ALL
			|	
			|	SELECT
			|		EDUsageAgreementsOutgoingDocuments.UseDS,
			|		True AS UseReceipt,
			|		CASE
			|			WHEN &EDDirection = VALUE(Enum.EDDirections.Intercompany)
			|				THEN VALUE(Enum.EDDirections.Intercompany)
			|			ELSE VALUE(Enum.EDDirections.Incoming)
			|		END AS Direction,
			|		&EDKind AS EDKind,
			|		EDUsageAgreementsOutgoingDocuments.EDExchangeMethod AS ExchangeMethod,
			|		0 AS Priority,
			|		NULL,
			|		NULL
			|	FROM
			|		Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
			|	WHERE
			|		EDUsageAgreementsOutgoingDocuments.Ref.Company = &Company
			|		AND EDUsageAgreementsOutgoingDocuments.Ref.Counterparty = &Counterparty
			|		AND EDUsageAgreementsOutgoingDocuments.OutgoingDocument = &EDKind
			|		AND EDUsageAgreementsOutgoingDocuments.Ref.ConnectionStatus = VALUE(Enum.EDExchangeMemberStatuses.Connected)
			|		AND EDUsageAgreementsOutgoingDocuments.ToForm
			|		AND Not EDUsageAgreementsOutgoingDocuments.Ref.DeletionMark) AS Agreement";
			
			Result = Query.Execute().Select();
			
			If Result.Next() Then
				NewRow = StatusSettings.Add();
				NewRow.ExchangeMethod          = Result.ExchangeMethod;
				NewRow.Direction           = Result.Direction;
				NewRow.EDKind                 = Result.EDKind;
				NewRow.UseSignature   = Result.UseSignature;
				NewRow.UseReceipt = Result.UseReceipt;
				
				NewRow.EDFScheduleVersion   = EDParameters.EDFScheduleVersion;
				NewRow.BankApplication        = Result.BankApplication;
				NewRow.PackageFormatVersion   = Result.PackageFormatVersion;
				
			EndIf;
			
		EndIf;

	EndIf;
	
	If StatusSettings.Count() > 0 Then
		SetStatuses(EDStatusMap, StatusSettings[0]);
	EndIf;

EndProcedure

&AtServer
Procedure SetStatuses(EDStatusMap, StatusSettings)
	
	StatusesArray = ElectronicDocumentsService.ReturnEDStatusesArray(StatusSettings);
	For Each Item IN StatusesArray Do
		AddStatus(EDStatusMap, Item);
	EndDo;
	
EndProcedure

&AtServer
Function GetEDStatusTable(ED)
	
	EDStatusMap = New ValueTable;
	EDStatusMap.Columns.Add("Status");
	EDStatusMap.Columns.Add("Passed");
	
	If ED.EDStatus = Enums.EDStatuses.Rejected OR ED.EDStatus = Enums.EDStatuses.RejectedByReceiver Then
		
		If ED.EDDirection = Enums.EDDirections.Incoming Then
		
			Str = EDStatusMap.Add();
			Str.Status = Enums.EDStatuses.Received;
			
			Str = EDStatusMap.Add();
			Str.Status = Enums.EDStatuses.Rejected;
		Else
			
			Str = EDStatusMap.Add();
			Str.Status = Enums.EDStatuses.Created;
			
			Str = EDStatusMap.Add();
			Str.Status = ED.EDStatus;
		EndIf;
		
		EDStatusMap.FillValues(True, "Passed");
		
	Else
		
		FillEDStatusMap(EDStatusMap, ED);
		PassedSign = True;
		For Each CurRow IN EDStatusMap Do 
			CurRow.Passed = PassedSign;
			If CurRow.Status = Enums.EDStatuses.Approved
				AND (ED.EDStatus = Enums.EDStatuses.Rejected OR ED.EDStatus = Enums.EDStatuses.RejectedByReceiver) Then
				CurRow.Status = Enums.EDStatuses.Rejected;
				Break;
			EndIf;
			If ED.EDStatus = CurRow.Status Then
				Break;
			EndIf;
		EndDo;
		
	EndIf;
	
	Return EDStatusMap;
	
EndFunction

&AtClient
Procedure ShowCertificate(LineNumber, Imprint)
	
	CertificateDataAddress = CertificateDataAddress(LineNumber);
	CertificateBinaryData = GetFromTempStorage(CertificateDataAddress);
	
	SelectedCertificate = New CryptoCertificate(CertificateBinaryData);
	If SelectedCertificate=Undefined Then
		CommonUseClientServer.MessageToUser(NStr("Certificate is not found"));
		Return;
	EndIf;
	
	CertificateStructure = DigitalSignatureClientServer.FillCertificateStructure(SelectedCertificate);
	If CertificateStructure <> Undefined Then
		FormParameters = New Structure("CertificateStructure,Thumbprint, CertificateAddress",
			CertificateStructure, Imprint, CertificateDataAddress);
		OpenForm("CommonForm.Certificate", FormParameters);
	EndIf;
	
EndProcedure

&AtServer
Function CertificateDataAddress(LineNumber)
	
	CertificateBinaryData = Object.Ref.DigitalSignatures[LineNumber-1].Certificate.Get();
	LinksToCertificateDataRepository = PutToTempStorage(CertificateBinaryData, UUID);
	
	Return LinksToCertificateDataRepository;
	
EndFunction

&AtServer
Procedure AddSigningCertificateInAgreement(Imprint, CertificateAdded)
	
	If Not ValueIsFilled(Object.Ref.EDAgreement) Then
		Return ;
	EndIf;
	
	EDObject = FormAttributeToValue("Object");
	FoundString = EDObject.DigitalSignatures.Find(Imprint, "Imprint");
	If Not FoundString = Undefined Then
		AgreementObject = Object.Ref.EDAgreement.GetObject();
		
		NewRow = AgreementObject.CounterpartySignaturesCertificates.Add();
		NewRow.Certificate = FoundString.Certificate;
		NewRow.Imprint  = Imprint;
		AgreementObject.Write();
		
		CertificateAdded = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure AddCertificateToTrusted(SignatureData)
	
	If SignatureData <> Undefined AND SignatureData.MissingInList Then 
		QuestionText = NStr("en = 'Do you want to add the %1 certificate to the list of expected counterparty certificates?'");
		QuestionText = StrReplace(QuestionText, "%1", SignatureData.CertificateIsIssuedTo);
		AddData = New Structure("SignatureData", SignatureData);
		NotifyDescription = New NotifyDescription("AddCertificateToTrustedComplete", ThisObject, AddData);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

&AtServer
Procedure PlaceTextRefinementsInObjec(CorrectionText)
	
	ElectronicDocument = Object.Ref.GetObject();
	ElectronicDocument.RejectionReason = CorrectionText;
	ElectronicDocument.Write();
	ValueToFormAttribute(ElectronicDocument, "Object");
	
EndProcedure

&AtServer
Function GetUnidentifiedSignaturesNumber()
	
	Query = New Query();
	Query.Text = "SELECT DISTINCT
	               |	EDAttachedFilesDigitalSignatures.Imprint
	               |INTO SetSignatures
	               |FROM
	               |	Catalog.EDAttachedFiles.DigitalSignatures AS EDAttachedFilesDigitalSignatures
	               |WHERE
	               |	EDAttachedFilesDigitalSignatures.Ref = &LinkToED
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	COUNT(DISTINCT AgreementsOnUseOfEDCertificatesCompanySignatures.Certificate) AS NumberOfRequiredSignatures
	               |FROM
	               |	Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsOnUseOfEDCertificatesCompanySignatures
	               |WHERE
	               |	Not AgreementsOnUseOfEDCertificatesCompanySignatures.Certificate.Imprint In
	               |				(SELECT
	               |					SetSignatures.Imprint
	               |				FROM
	               |					SetSignatures AS SetSignatures)
	               |	AND AgreementsOnUseOfEDCertificatesCompanySignatures.Ref = &EDAgreement";
	Query.SetParameter("LinkToED", Object.Ref);
	Query.SetParameter("EDAgreement", Object.Ref.EDAgreement);
	QueryResult = Query.Execute().Select();
	QueryResult.Next();
	
	Return QueryResult.NumberOfRequiredSignatures;
	
EndFunction

&AtServer
Function EDRefused()
	
	EDRefused = (Object.Ref.EDStatus = Enums.EDStatuses.Rejected
					OR Object.Ref.EDStatus = Enums.EDStatuses.RejectedByReceiver
					OR Object.Ref.EDStatus = Enums.EDStatuses.RejectedByBank
					OR Object.Ref.EDStatus = Enums.EDStatuses.TransferError
					OR Object.Ref.EDStatus = Enums.EDStatuses.RefusedABC
					OR Object.Ref.EDStatus = Enums.EDStatuses.ESNotCorrect
					OR Object.Ref.EDStatus = Enums.EDStatuses.AttributesError);
	Return EDRefused
	
EndFunction

&AtServer
Function HideAreaSpreadsheetDocument(AreaName)
	
	// Find an additional data area and hide it.
	// If a DD area has a left and/or right border, then it is a vertical area, otherwise, it is a horizontal one.
	// Horizontal area is displayed in the low part of the table so
	// find a header of the DD horizontal area and hide rows from the DD header up to the end of the table.
	// Vertical area is added to the main data table. If the table does not
	// fit a page, then a named area will appear only on the last page. IN this case, an algorithm
	// of defining an area to be hidden is the following:
	// 1. find a named DD area (for example, AreaDD).
	// 2. calculate a top border of the DD area: find a header area, the next row after the header area - will
	//  be a top row of the DD area, so take the header area bottom + 1.
	// 3.asadditional data is added to the main one from the right, then you can take a tabular document height as a bottom border.
	//
	// If the Header area does not exist, then the DD area may be hidden incorrectly/partially.
	AreaHasDD = FormTableDocument.Areas.Find(AreaName);
	If AreaHasDD <> Undefined Then
		TableAreaDD = FormTableDocument.Area(AreaName);
		HeaderArea = FormTableDocument.Areas.Find("Header");
		Top = ?(TableAreaDD.Left = 0 AND TableAreaDD.Right = 0 OR HeaderArea = Undefined,
			TableAreaDD.Top, HeaderArea.Bottom + 1);
		DeletingArea = FormTableDocument.Area(Top, TableAreaDD.Left,
			FormTableDocument.TableHeight, TableAreaDD.Right);
		FormTableDocument.DeleteArea(DeletingArea);
	EndIf;
	
EndFunction

&AtServer
Procedure HideAdditionalInformation(Hide)
	
	If Hide Then
		HideAreaSpreadsheetDocument("AreaDD");
		HideAreaSpreadsheetDocument("DDAreaWithDS");
		HideAreaSpreadsheetDocument("DDAreaWithoutDS");
		
		HideAreaSpreadsheetDocument("DDAreaWithDS_YC");
		HideAreaSpreadsheetDocument("DDAreaWithDS_U");
		HideAreaSpreadsheetDocument("DDAreaWithDS_From");
		
		HideAreaSpreadsheetDocument("AdditionalHeaderData_Header");
	Else
		FormTableDocument = OriginalTableDocument.GetArea();
	EndIf;
	
EndProcedure

&AtServer
Procedure DeterminePresenceOfAdditionalInformationHideFlag()
	
	LinkToED = Object.Ref;
	
	If LinkToED.EDKind = Enums.EDKinds.ActCustomer 
		OR LinkToED.EDKind = Enums.EDKinds.ActPerformer
		OR LinkToED.EDKind = Enums.EDKinds.TORG12Customer
		OR LinkToED.EDKind = Enums.EDKinds.TORG12Seller
		OR LinkToED.EDKind = Enums.EDKinds.CustomerInvoiceNote
		OR LinkToED.EDKind = Enums.EDKinds.CorrectiveInvoiceNote
		OR LinkToED.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender
		OR LinkToED.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient
		
		OR LinkToED.EDKind = Enums.EDKinds.ProductOrder
		OR LinkToED.EDKind = Enums.EDKinds.ResponseToOrder
		OR LinkToED.EDKind = Enums.EDKinds.InvoiceForPayment
		OR LinkToED.EDKind = Enums.EDKinds.PriceList
		OR LinkToED.EDKind = Enums.EDKinds.ProductsDirectory
		OR LinkToED.EDKind = Enums.EDKinds.ComissionGoodsSalesReport
		OR LinkToED.EDKind = Enums.EDKinds.ComissionGoodsWriteOffReport
		
		Then
		
		AdditionalInformationExists = True;
	Else
		
		AdditionalInformationExists = False;
	EndIf;
	Items.DisableOutputAdditionalInformation.Visible = AdditionalInformationExists;
	
EndProcedure

&AtClient
Procedure SaveBankDocumentsSberBank(ED)
	
	CountNotExportedDocuments = 0;
	
	SberbankFileArray = SberbankFileArray(ED);
	
	For Each Item IN SberbankFileArray Do
		GetFile(Item.FileReference, Item.FileName);
		CountNotExportedDocuments = CountNotExportedDocuments + 1;
	EndDo;
	
	NotificationText = NStr ("ru = 'Files imported: (" + CountNotExportedDocuments + ")'");
	ShowUserNotification(NotificationText);
	
EndProcedure

&AtServerNoContext
Function DataServiceEDBank(Val ED, Val UUID)

	FileData = Undefined;
	ServiceBankED = ElectronicDocumentsService.ServiceBankED(ED);
	If ValueIsFilled(ServiceBankED) Then
		FileData = ElectronicDocumentsService.GetFileData(ServiceBankED, UUID);
	EndIf;
	Return FileData;
	
EndFunction

&AtServer
Function UNTILCanceledOrInProcess()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	TRUE AS Field1
		|FROM
		|	Catalog.EDAttachedFiles AS EDEDOwner
		|		Full JOIN Catalog.EDAttachedFiles AS EDAttachedFiles
		|		ON EDEDOwner.Ref = EDAttachedFiles.ElectronicDocumentOwner
		|WHERE
		|	EDAttachedFiles.Ref = &ED
		|	AND CASE
		|			WHEN EDEDOwner.Ref IS NULL 
		|				THEN EDAttachedFiles.EDStatus IN (&StatusListWithCancellation)
		|			ELSE EDEDOwner.EDStatus IN (&StatusListWithCancellation)
		|		END";
	StateArray = New Array;
	StateArray.Add(Enums.EDStatuses.Canceled);
	StateArray.Add(Enums.EDStatuses.CancellationOfferSent);
	StateArray.Add(Enums.EDStatuses.CancellationOfferCreated);
	StateArray.Add(Enums.EDStatuses.CancellationOfferReceived);
	Query.SetParameter("StatusListWithCancellation", StateArray);
	Query.SetParameter("ED", Object.Ref);
	Result = Query.Execute();
	If Result.IsEmpty() Then
		ReturnValue = False;
	Else
		ReturnValue = True;
	EndIf;
	
	Return ReturnValue;
	
EndFunction

&AtClient
Procedure HandleCancellationOffer(RejectCancellation)
	
	If ValueIsFilled(Object.ElectronicDocumentOwner) Then
		LinkToED = Object.ElectronicDocumentOwner;
	Else
		LinkToED = Object.Ref;
	EndIf;
	ElectronicDocumentsServiceClient.HandleCancellationOffer(LinkToED, RejectCancellation);
	
	ChangeVisibleEnabled();
	
EndProcedure

&AtClient
Procedure CancelRejectED(Reject = False)
	
	NotifyDescription = New NotifyDescription("CancelRejectEDContinue", ThisObject);
	If ValueIsFilled(Object.ElectronicDocumentOwner) Then
		LinkToED = Object.ElectronicDocumentOwner;
	Else
		LinkToED = Object.Ref;
	EndIf;
	EDParameters = New Structure("Company, Reject, NotificationDescription",
		Object.Company, Reject, NotifyDescription);
	ElectronicDocumentsServiceClient.HandleEDDeviationCancellation(LinkToED, EDParameters);
	
EndProcedure

#EndRegion

#Region AsynchronousDialogsHandlers

&AtClient
Procedure AfterObtainingPrints(Prints, Parameters = Undefined) Export
	
	ThumbprintArray = New Array;
	If TypeOf(Prints) = Type("Map") Then
		For Each KeyValue IN Prints Do
			ThumbprintArray.Add(KeyValue.Key);
		EndDo
	EndIf;
	
	ThumbprintArrayReference = PutToTempStorage(ThumbprintArray, UUID);
	
	ChangeVisibleEnabled();
	
EndProcedure

&AtClient
Procedure ConfirmPaymentEndiBank2(Val Result, Val AdditionalParameters) Export
	
	Session = Undefined;
	XMLCertificate = Undefined;
	
	If Result <> Undefined
		AND TypeOf(AdditionalParameters) = Type("Structure") AND AdditionalParameters.Property("Session", Session)
		AND AdditionalParameters.Property("XMLCertificate", XMLCertificate) Then
		Password = Result;
		QueryParameters = New Structure("Method, Password, Session");
		QueryParameters.Method = "SMS";
		QueryParameters.Password = Password;
		QueryParameters.Session = Session;
		
		Result = ElectronicDocumentsServiceClient.SendQueryiBank2("5", QueryParameters);
		
		If Not ValueIsFilled(Result) Then
			Return;
		EndIf;
		
		If Not IsBlankString(Result.ErrorText) OR Result.Status = "30" Then
			MessageText = NStr("en = 'An error occurred when confirming a payment order: '") + Result.ErrorText;
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		EndIf;
		
		SetStatusDelivered(Object.Ref);
		
		Notify("RefreshStateED");
		
		ShowUserNotification(NStr("en = 'The document is confirmed'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ConfirmPaymentCompleteThroughAdditionalProcessing(Val Result, Val AdditionalParameters) Export
	
	Session = Undefined;
	ExternalAttachableModule = Undefined;
	XMLCertificate = Undefined;
	If Result <> Undefined
		AND TypeOf(AdditionalParameters) = Type("Structure")
		AND AdditionalParameters.Property("Session", Session)
		AND AdditionalParameters.Property("ExternalAttachableModule", ExternalAttachableModule)
		AND AdditionalParameters.Property("XMLCertificate", XMLCertificate) Then
		Password = Result;
		QueryParameters = New Structure("Method, Password, Session");
		QueryParameters.Method = "SMS";
		QueryParameters.Password = Password;
		QueryParameters.Session = Session;
			
		Try
			Result = ExternalAttachableModule.SendRequest(XMLCertificate, 5, QueryParameters);
		Except
			ErrorTemplate = NStr("en = 'Error of a payment order confirmation.
									|Error code:
									|%1 %2'");
			ErrorDetails = ExternalAttachableModule.ErrorDetails();
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
																ErrorTemplate,
																ErrorDetails.Code,
																ErrorDetails.Message);
			Operation = NStr("en = 'Payment order confirmation'");
			DetailErrorDescription = DetailErrorDescription(ErrorInfo());
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation,
				DetailErrorDescription, MessageText, 1);
			Return;
		EndTry;
		
		If Result.Count() = 0 Then
			ShowUserNotification(NStr("en = 'No data for confirmation'"));
		EndIf;
		
		If Not IsBlankString(Result[0].ErrorText) Then
			MessageText = NStr("en = 'An error occurred when confirming a payment order: '") + Result[0].ErrorText;
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		EndIf;
		
		SetStatusDelivered(Object.Ref);
		
		Notify("RefreshStateED");
		
		ShowUserNotification(NStr("en = 'The document is confirmed'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ConfirmPaymentThroughAdditionalProcessing(ExternalAttachableModule, AdditionalParameters = Undefined) Export
	
	ClearMessages();
	If ExternalAttachableModule <> Undefined Then
		PasswordIsSetPreviously = False;
		CertificatesArray = New Array;
		AvailableCertificates = ElectronicDocumentsServiceCallServer.AvailableCertificates(Object.EDAgreement);
		
		CertificateData = Undefined;
		For Each Item IN AvailableCertificates Do
			PasswordIsSetPreviously = ElectronicDocumentsServiceClient.CertificatePasswordIsSetThroughAdditionalDataProcessor(
																	ExternalAttachableModule, Item.Value.CertificateData);
			If PasswordIsSetPreviously Then
				SelectedCertificate = Item.Key;
				CertificateData = Item.Value;
				CertificateData.Insert("SelectedCertificate", SelectedCertificate);
				XMLCertificate = Item.Value.CertificateData;
				Break;
			EndIf;
			CertificatesArray.Add(Item.Key);
		EndDo;
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("PasswordIsSetPreviously", PasswordIsSetPreviously);
		AdditionalParameters.Insert("AccCertificatesAndTheirStructures", AvailableCertificates);
		AdditionalParameters.Insert("ExternalAttachableModule", ExternalAttachableModule);
		
		If PasswordIsSetPreviously Then
			ContinueConfirmationPaymentAfterEnteringPasswordCertificateThroughAdditionalProcessing(CertificateData,
				AdditionalParameters);
		Else
			OperationKind = NStr("en = 'Authentication on bank resource'");
			If ElectronicDocumentsServiceClient.PasswordToCertificateReceived2(AvailableCertificates, OperationKind) Then
				AdditionalParameters.Insert("AccCertificatesAndTheirStructures", AvailableCertificates);
			Else
				AdditionalParameters.Insert("AccCertificatesAndTheirStructures", AvailableCertificates);
				OOOZ = New NotifyDescription(
					"ContinueConfirmationPaymentAfterEnteringPasswordCertificateThroughAdditionalProcessing", ThisObject,
					AdditionalParameters);
				AdditionalParameters.Insert("CallNotification", OOOZ);
				ElectronicDocumentsServiceClient.GetPasswordToSertificate(AvailableCertificates,
					OperationKind, , , AdditionalParameters);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChooseDocumentComplete(Val Result, Val AdditionalParameters) Export
	
	If ValueIsFilled(Result) Then
		RebindElectronicDocument(Result);
		Notify("RefreshStateED");
	EndIf;
	
EndProcedure

&AtClient
Procedure ChooseDocumentContinue(Val Result, Val AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		SelValue = Object.FileOwner;
		NotifyDescription = New NotifyDescription("ChooseDocumentComplete", ThisObject);
		ToolTip = NStr("en = 'Specify a document to be registered in accounting'");
		ShowInputValue(NOTifyDescription, SelValue, ToolTip);
	EndIf;
	
EndProcedure

&AtClient
Procedure AddCertificateToTrustedComplete(Val Result, Val AdditionalParameters) Export
	
	SignatureData = Undefined;
	If Result = DialogReturnCode.No Then
		ShowCertificate(Items.DS.CurrentData.LineNumber,Items.DS.CurrentData.Imprint);
	ElsIf TypeOf(AdditionalParameters) = Type("Structure")
		AND AdditionalParameters.Property("SignatureData", SignatureData)
		AND ValueIsFilled(SignatureData) Then
		// Add a certificate to the Agreement.
		CertificateAdded = False;
		AddSigningCertificateInAgreement(SignatureData.Imprint, CertificateAdded);
		If Not CertificateAdded Then 
			MessageText = NStr("en = 'Error of adding the signature certificate to the list of the expected certificates!'");
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			FillTableDS();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure CancelRejectEDContinue(Val Result, Val AdditionalParameters) Export
	
	If Result = True Then
		ChangeVisibleEnabled();
		Notify("RefreshStateED");
	EndIf;
	
EndProcedure

&AtClient
Procedure ValidateiBankSignatures2(ExternalAttachableModule, AdditionalParameters = Undefined) Export
	
	If ExternalAttachableModule = Undefined Then
		Return;
	EndIf;
	
	ArrayChecks = New Array;
	ArrayChecks.Add(Object.Ref);
	CheckParameters = New Structure;
	CheckParameters.Insert("EDArrayForCheckiBank2", ArrayChecks);
	CheckParameters.Insert("CurrentSignaturesCheckIndexiBank2", 0);
	CheckParameters.Insert("NotifyAboutESCheck");
	ElectronicDocumentsServiceClient.StartCheckingSignartureStatusesiBank2(CheckParameters);
		
EndProcedure

&AtClient
Procedure ConfirmPaymentiBank2(ExternalAttachableModule, AdditionalParameters = Undefined) Export
	
	If ExternalAttachableModule = Undefined Then
		Return;
	EndIf;
	
	ClearMessages();
	AvailableCertificates = ElectronicDocumentsServiceCallServer.AvailableCertificates(Object.EDAgreement);
	PasswordIsSetPreviously = False;
	CertificatesArray = New Array;
	
	For Each Item IN AvailableCertificates Do
		PasswordIsSetPreviously = ElectronicDocumentsServiceClient.iBank2CertificatePasswordSet(
																		Item.Value.CertificateBinaryData);
		If PasswordIsSetPreviously Then
			SelectedCertificate = Item.Key;
			XMLCertificate = Item.Value.CertificateBinaryData;
			Break;
		EndIf;
		CertificatesArray.Add(Item.Key);
	EndDo;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("PasswordIsSetPreviously", PasswordIsSetPreviously);
	AdditionalParameters.Insert("AccCertificatesAndTheirStructures", AvailableCertificates);
	
	If Not PasswordIsSetPreviously Then
		OperationKind = NStr("en = 'Authentication on bank resource'");
		
		If Not ElectronicDocumentsServiceClient.PasswordToCertificateReceived2(AvailableCertificates, OperationKind) Then
			
			AdditionalParameters.Insert("AccCertificatesAndTheirStructures", AvailableCertificates);
			OOOZ = New NotifyDescription(
					"ContinueConfirmationPaymentAfterEnteringPasswordToiBank2Certificate", ThisObject);
			AdditionalParameters.Insert("CallNotification", OOOZ);
			ElectronicDocumentsServiceClient.GetPasswordToSertificate(
				AvailableCertificates, OperationKind, , , AdditionalParameters);
			Return;
		EndIf;
		AdditionalParameters.Insert("AccCertificatesAndTheirStructures", AvailableCertificates);
	EndIf;

	ContinueConfirmationPaymentAfterEnteringPasswordToiBank2Certificate(Undefined, AdditionalParameters)
	
EndProcedure

&AtClient
Procedure ContinueConfirmationPaymentAfterEnteringPasswordCertificateThroughAdditionalProcessing(Result, AdditionalParameters) Export
	
	SelectedCertificate = Undefined;
	If TypeOf(Result) = Type("Structure") AND Result.Property("SelectedCertificate", SelectedCertificate)
		AND TypeOf(SelectedCertificate) = Type("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates") Then
		
		AvailableCertificates = AdditionalParameters.AccCertificatesAndTheirStructures;
		PasswordIsSetPreviously = AdditionalParameters.PasswordIsSetPreviously;
		ExternalAttachableModule = AdditionalParameters.ExternalAttachableModule;
		
		UserPassword = Result.UserPassword;
		If AvailableCertificates.Count() > 0 Then
			For Each KeyAndValue IN AvailableCertificates Do
				If KeyAndValue.Key = SelectedCertificate Then
					CertificateParameters = KeyAndValue.Value;
					XMLCertificate = CertificateParameters.CertificateData;
					Break;
				EndIf;
			EndDo;
			CertificateData = ElectronicDocumentsServiceClient.CertificateDataThroughAdditionalDataProcessor(
																			ExternalAttachableModule, XMLCertificate);

			If CertificateData <> Undefined Then
				ExecuteParameters = New Structure;
				ExecuteParameters.Insert("ProcedureName", "ExecuteConfirmPaymentThroughAdditionalProcessing");
				ExecuteParameters.Insert("Module",                    ThisObject);
				ExecuteParameters.Insert("XMLCertificate",             XMLCertificate);
				ExecuteParameters.Insert("PasswordIsSetPreviously",     PasswordIsSetPreviously);
				ExecuteParameters.Insert("UserPassword",        UserPassword);
				ExecuteParameters.Insert("ExternalAttachableModule", ExternalAttachableModule);
				
				PINCodeRequired = ElectronicDocumentsServiceClient.NeedToSetStoragePINCodeThroughAdditionalDataProcessor(
					ExternalAttachableModule, CertificateData.StorageIdentifier);
					
				If PINCodeRequired = False Then
					ContinueConfirmationPaymentAfterEnteringPINCodeThroughAdditionalProcessing(True, ExecuteParameters);
				ElsIf PINCodeRequired = True Then
					OnCloseNotifyDescription = New NotifyDescription(
						"ContinueConfirmationPaymentAfterEnteringPINCodeThroughAdditionalProcessing", ThisObject, ExecuteParameters);
					ElectronicDocumentsServiceClient.StartInstallationPINStorages(
						Object.EDAgreement, CertificateData.StorageIdentifier, OnCloseNotifyDescription);
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SendEDStatusRequestToBank(DataAuthorization, Parameters = Undefined) Export
	
	If Not ValueIsFilled(DataAuthorization) Then
		Return;
	EndIf;
	ReceivingParameters = New Structure;
	ReceivingParameters.Insert("DataAuthorization", DataAuthorization);
	ReceivingParameters.Insert("ProcedureHandler", "SendEDStatusQueryToBankAfterReceivingMarker");
	ReceivingParameters.Insert("ObjectHandler", ElectronicDocumentsServiceClient);
	ReceivingParameters.Insert("EDAgreement", Object.EDAgreement);
	ReceivingParameters.Insert("ElectronicDocument", Object.Ref);
	ElectronicDocumentsServiceClient.GetBankMarker(DataAuthorization, ReceivingParameters);
	
EndProcedure

&AtClient
Procedure ConfirmiBank2Payment(AuthenticationCompleted, Parameters) Export
	
	If Not AuthenticationCompleted = True Then
		Return;
	EndIf;
	
	XMLCertificate = Parameters.XMLCertificate;
	
	ExternalIDs = New Array;
	ExternalIDs.Add(UUIDExternal(Object.Ref));
	QueryParameters = New Structure("DocumentIDs", ExternalIDs);
	
	Result = ElectronicDocumentsServiceClient.SendQueryiBank2("4", QueryParameters);
	
	If Not ValueIsFilled(Result) Then
		Return;
	EndIf;
	
	If Not Result.Ways.Property("SMS") Then
		ErrorText = NStr("en = 'Payment confirmation by SMS is not supported.'");
		Operation = NStr("en = 'Initializing a payment confirmation procedure'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
												Operation, ErrorText, ErrorText, 1);
		Return;
	EndIf;
		
	Session = Result.Session;
	
	FormParameters = New Structure();
	FormParameters.Insert("Certificate", XMLCertificate);
	FormParameters.Insert("Session", Session);
	FormParameters.Insert("ElectronicDocument", Object.Ref);
	FormParameters.Insert("EDAgreement", Object.EDAgreement);
	FormParameters.Insert("BankApplication", BankApplication);

	AddData = New Structure("Session, XMLCertificate", Session, XMLCertificate);
	NotifyDescription = New NotifyDescription("ConfirmPaymentEndiBank2", ThisObject, AddData);
	OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.PaymentOrdersConfirmationBySMS",
					FormParameters, ThisObject, UUID, , , NotifyDescription);
	
EndProcedure

&AtClient
Procedure ExecuteConfirmPaymentThroughAdditionalProcessing(AuthenticationCompleted, Parameters) Export
	
	ExternalAttachableModule = Parameters.ExternalAttachableModule;
	XMLCertificate = Parameters.XMLCertificate;
	
	ExternalIDs = New Array;
	ExternalIDs.Add(UUIDExternal(Object.Ref));
	QueryParameters = New Structure("DocumentIDs", ExternalIDs);
	
	Try
		Result = ExternalAttachableModule.SendRequest(XMLCertificate, 4, QueryParameters);
	Except
		ErrorTemplate = NStr("en = 'An error occurred while initializing the confirmation session.
							|Error code:
							|%1 %2'");
		ErrorDetails = ExternalAttachableModule.ErrorDetails();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
															ErrorTemplate,
															ErrorDetails.Code,
															ErrorDetails.Message);
		Operation = NStr("en = 'Initializing the confirmation session'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation,
			DetailErrorDescription, MessageText, 1);
		Return;
	EndTry;
	
	Session = Result.Session;
	
	FormParameters = New Structure();
	FormParameters.Insert("Certificate", XMLCertificate);
	FormParameters.Insert("Session", Session);
	FormParameters.Insert("ElectronicDocument", Object.Ref);
	FormParameters.Insert("EDAgreement", Object.EDAgreement);
	FormParameters.Insert("BankApplication", BankApplication);
	
	AddData = New Structure("Session, ExternalConnectedModule, XMLCertificate",
		Session, ExternalAttachableModule, XMLCertificate);
	NotifyDescription = New NotifyDescription(
		"ConfirmPaymentCompleteThroughAdditionalProcessing", ThisObject, AddData);
	OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.PaymentOrdersConfirmationBySMS",
					FormParameters, ThisObject, UUID, , , NotifyDescription);
	
EndProcedure


&AtClient
Procedure ContinuePaymentConfirmationAfterEnteringiBank2PINCode(PinCodeSet, ExecuteParameters) Export
	
	If Not PinCodeSet = True Then
		Return;
	EndIf;
	
	PasswordIsSetPreviously = ExecuteParameters.PasswordIsSetPreviously;
	XMLCertificate = ExecuteParameters.XMLCertificate;
	UserPassword = ExecuteParameters.UserPassword;

	If Not PasswordIsSetPreviously Then
		PasswordIsSet = ElectronicDocumentsServiceClient.SetiBank2CertificatePassword(
																XMLCertificate, UserPassword);
		If Not PasswordIsSet Then
			Return;
		EndIf;
	EndIf;
	
	ConnectionEstablished = False;
	ElectronicDocumentsServiceClient.EstablishConnectioniBank2(
		Object.EDAgreement, XMLCertificate, ExecuteParameters, ConnectionEstablished);
	If Not ConnectionEstablished Then
		Return;
	EndIf;
	
	ConfirmiBank2Payment(ConnectionEstablished, ExecuteParameters);
	
EndProcedure

&AtClient
Procedure ContinueConfirmationPaymentAfterEnteringPINCodeThroughAdditionalProcessing(PinCodeSet, ExecuteParameters) Export
	
	If Not PinCodeSet = True Then
		Return;
	EndIf;
	
	PasswordIsSetPreviously = ExecuteParameters.PasswordIsSetPreviously;
	ExternalAttachableModule = ExecuteParameters.ExternalAttachableModule;
	XMLCertificate = ExecuteParameters.XMLCertificate;
	UserPassword = ExecuteParameters.UserPassword;

	If Not PasswordIsSetPreviously Then
		PasswordIsSet = ElectronicDocumentsServiceClient.SetCertificatePasswordThroughAdditionalDataProcessor(
															ExternalAttachableModule, XMLCertificate, UserPassword);
		If Not PasswordIsSet Then
			Return;
		EndIf;
	EndIf;
	
	ConnectionEstablished = False;
	ElectronicDocumentsServiceClient.EstablishConnectionThroughAdditionalDataProcessor(
		Object.EDAgreement, ExternalAttachableModule, XMLCertificate, ExecuteParameters, ConnectionEstablished);
	If Not ConnectionEstablished Then
		Return;
	EndIf;
	
	ExecuteConfirmPaymentThroughAdditionalProcessing(ConnectionEstablished, ExecuteParameters);
	
EndProcedure

&AtClient
Procedure ContinueConfirmationPaymentAfterEnteringPasswordToiBank2Certificate(Result, AdditionalParameters) Export
	
	AvailableCertificates = AdditionalParameters.AccCertificatesAndTheirStructures;
	PasswordIsSetPreviously = AdditionalParameters.PasswordIsSetPreviously;
	
	If AvailableCertificates.Count() > 0 Then
		For Each KeyAndValue IN AvailableCertificates Do
			CertificateParameters = KeyAndValue.Value;
			UserPassword = CertificateParameters.UserPassword;
			SelectedCertificate = KeyAndValue.Key;
			XMLCertificate = CertificateParameters.CertificateBinaryData;
			Break;
		EndDo;
	Else
		Return;
	EndIf;
	
		
	CertificateData = ElectronicDocumentsServiceClient.iBank2CertificateData(XMLCertificate);

	If CertificateData = Undefined Then
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ProcedureName", "ConfirmiBank2Payment");
	ExecuteParameters.Insert("Module", ThisObject);
	ExecuteParameters.Insert("XMLCertificate", XMLCertificate);
	ExecuteParameters.Insert("PasswordIsSetPreviously", PasswordIsSetPreviously);
	ExecuteParameters.Insert("UserPassword", UserPassword);
	
	PINCodeRequired = ElectronicDocumentsServiceClient.RequiredToSetStoragePINCodeiBank2(
																		CertificateData.StorageIdentifier);
		
	If PINCodeRequired = Undefined Then
		Return;
	ElsIf PINCodeRequired Then
		OnCloseNotifyDescription = New NotifyDescription("ContinuePaymentConfirmationAfterEnteringiBank2PINCode",
																				ThisObject, ExecuteParameters);
		ElectronicDocumentsServiceClient.StartInstallationPINStorages(
			Object.EDAgreement, CertificateData.StorageIdentifier, OnCloseNotifyDescription);
		Return;
	EndIf;
	
	ContinuePaymentConfirmationAfterEnteringiBank2PINCode(True, ExecuteParameters);
	
EndProcedure

&AtServer
Function ExchangeMethodToPMAgreements(EDAgreement, EDKind)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDUsageAgreementsOutgoingDocuments.EDExchangeMethod As EDExchangeMethod
	|FROM
	|	Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
	|WHERE
	|	EDUsageAgreementsOutgoingDocuments.Ref = &EDAgreement
	|	AND EDUsageAgreementsOutgoingDocuments.OutgoingDocument = &EDKind";
	
	Query.SetParameter("EDAgreement", EDAgreement);
	Query.SetParameter("EDKind", EDKind);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	ExchangeMethod = Undefined;
	If Selection.Next() Then
	
		ExchangeMethod = Selection.EDExchangeMethod;
	EndIf;
	
	Return ExchangeMethod;
	
EndFunction

#EndRegion
