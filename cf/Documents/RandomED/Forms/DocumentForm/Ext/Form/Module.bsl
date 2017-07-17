////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Object") Then
		ValueToFormAttribute(Parameters.Object.GetObject(), "Object");
	EndIf;
		
	If Parameters.Key.IsEmpty() Then
		Object.DocumentStatus = Enums.EDStatuses.Created;
		Object.Direction     = Enums.EDDirections.Outgoing;
	EndIf;
	
	If Not Object.WasRead AND Not Object.Ref.IsEmpty()
		AND Object.Direction = Enums.EDDirections.Incoming Then
		Document = FormAttributeToValue("Object");
		Document.WasRead = True;
		Document.Write();
		ValueToFormAttribute(Document, "Object");
		StatusChanged = True;
	EndIf;
	
	UpdateTableAttachment();
	
	UpdateFooterInformation();
	SetEnabledOfItems();
	RefreshFormTitle();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	RefreshFormTitle();
	SetEnabledOfItems();
	UpdateFooterInformation();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not IsAgreement(CurrentObject) Then
		Cancel = True;
	ElsIf Not ValueIsFilled(Object.Ref) Then
		RequiredToSetConfirmationByAgreement(CurrentObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		ExecuteNotificationProcessingAtServer();
		RefreshDataRepresentation();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM FIELD EVENT HANDLERS

&AtClient
Procedure DateOnChange(Item)
	
	RefreshFormTitle();
	
EndProcedure

&AtClient
Procedure AttachmentsBeforeAdd(Item, Cancel, Copy, Parent, Group)
	
	If Not CheckFilling() Then
		Cancel = True;
		Return;
	EndIf;
	
	ContinuationProcessor = New NotifyDescription("FinishAddingFile", ThisObject);
	CheckDocumentRecord(ContinuationProcessor);
	Cancel = True;
	
EndProcedure

&AtClient
Procedure AttachmentsAfterDeleteRow(Item)
	
	ProcessAttachmentDeletion();
	
EndProcedure

&AtClient
Procedure ProcessAttachmentDeletion()
	
	If ElectronicDocumentsServiceCallServer.IsRightToProcessED() Then
		DeleteUnnecessaryFilesAttached();
		SetEnabledOfItems();
	EndIf;
	
EndProcedure

&AtClient
Procedure AttachmentsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	// Restriction - the Attachments table can not have more than one row.
	ED = Attachments[0].Ref;
	// Open an attachment by the standard mechanism
	FileData = ElectronicDocumentsServiceCallServer.GetFileData(ED, UUID);
	AttachedFilesClient.OpenFile(FileData, False);
	
EndProcedure

&AtClient
Procedure AttachmentsBeforeDelete(Item, Cancel)
	
	If Not (Object.DocumentStatus = PredefinedValue("Enum.EDStatuses.PreparedToSending")
		OR Object.DocumentStatus = PredefinedValue("Enum.EDStatuses.Created")) Then
		Cancel = True;
	Else
		QuestionText = NStr("en='Delete document attachment?';ru='Удалить вложение из документа?'");
		If DS.Count() > 0 Then
			QuestionText = NStr("en='If you delete the attachment, the signatures will be deleted as well.';ru='При удалении вложения будут удалены установленные подписи.'") + Chars.LF + QuestionText;
		EndIf;
		NotifyDescription = New NotifyDescription("ProcessDeletionQuestionAnswerAttachments", ThisObject);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure NumberOnChange(Item)
	
	RefreshFormTitle();
	
EndProcedure

&AtClient
Procedure ConfirmationRequiredOnChange(Item)
	
	UpdateEDStatus();
	
EndProcedure

&AtClient
Procedure DSChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If Find(Field.Name, "DSCertificateIsIssuedTo")>0 Then
		AddCertificateToTrusted(Item.CurrentData);
		If Item.CurrentData <> Undefined AND Not Item.CurrentData.MissingInList Then
			ShowCertificate(Item.CurrentData.LineNumber, Item.CurrentData.Imprint);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure DSOnActivateRow(Item)
	
	If Items.DS.CurrentData <> Undefined Then
		Items.TrustCertificate.Enabled = Items.DS.CurrentData.MissingInList;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - Form commands actions

&AtClient
Procedure CancelRejection(Command)
	
	If EDRefused Then
		ContinuationProcessor = New NotifyDescription("ProcessEDRejectionCancelation", ThisObject);
		CheckDocumentRecord(ContinuationProcessor);
	EndIf;
	
EndProcedure

&AtClient
Procedure SignAndSend(Command)
	
	ClearMessages();
	
	If CheckFilling() Then
		
		Cancel = False;
		DocumentParameters = GetEDArrayToSend(Cancel);
		If Not Cancel Then
			ProcessSelectedDocuments(DocumentParameters);
		EndIf;
		
	EndIf;
	
EndProcedure


&AtClient
Procedure SignDocument(Command)
	
	// Restriction - the Attachments table can not have more than one row.
	If Attachments.Count() = 0 Then
		Return;
	EndIf;
	
	ContinuationProcessor = New NotifyDescription("DocumentSigningEnd", ThisObject);
	CheckDocumentRecord(ContinuationProcessor);
	
EndProcedure

&AtClient
Procedure DocumentSigningEnd(NOTSpecified, AdditionalParameters) Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("SignaturesArray", ThumbprintArray());
	
	NotificationHandler = New NotifyDescription("SigningEndNotification", ThisObject, AdditionalParameters);
	EDKindsArray = New Array;
	EDKindsArray.Add(Attachments[0].Ref);
	ElectronicDocumentsServiceClient.ProcessED(New Array, "ApproveSign", , EDKindsArray, NotificationHandler);
	
EndProcedure

&AtServer
Function ThumbprintArray()
	
	Signatures = FormAttributeToValue("DS");
	ThumbprintArray = Signatures.UnloadColumn("Imprint");
	
	Return ThumbprintArray;
	
EndFunction

&AtClient
Function CompareSignatures(ThumbprintsArrayBefore)
	
	DocumentSigned = False;
	
	ThumbprintsArrayAfter = ThumbprintArray();
	
	For Each Imprint IN ThumbprintsArrayAfter Do
		
		If ThumbprintsArrayBefore.Find(Imprint) = Undefined Then
			DocumentSigned = True;
		EndIf;
		
	EndDo;
	
	Return DocumentSigned;
	
EndFunction

&AtClient
Procedure SigningEndNotification(Result, AdditionalParameters) Export
	
	DigitallySigned = CompareSignatures(AdditionalParameters.SignaturesArray);
	
	Read();
	ShowSignatureResult(DigitallySigned);
	
EndProcedure

&AtClient
Procedure ShowSignatureResult(DigitallySigned)
	
	StatusText = NStr("en='Signed: (0)';ru='Подписано: (0)'");
	HeaderText = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
	If DigitallySigned Then
		DocumentParameters = New Structure;
		DocumentParameters.Insert("DigitallySigned", True);
		
		UpdateStatusDocument(DocumentParameters);
		
		Read();
		SetEnabledOfItems();
		
		StatusText = NStr("en='Signed: (1)';ru='Подписано: (1)'");
	EndIf;
	
	Notify("RefreshStateED");
	
	ShowUserNotification(HeaderText, , StatusText);
	
EndProcedure


&AtClient
Procedure Reject(Command)
	
	If Not EDRefused AND Attachments.Count() > 0 Then
		ContinuationProcessor = New NotifyDescription("CancelRejectED", ThisObject, True);
		CheckDocumentRecord(ContinuationProcessor);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckSignatures(Command)
	
	ClearMessages();
	
	If Attachments.Count() > 0 Then
		If ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer() Then
			ElectronicDocumentsServiceCallServer.DetermineSignaturesStatuses(Attachments[0].Ref, True);
		Else
			ElectronicDocumentsServiceClient.DetermineSignaturesStatuses(Attachments[0].Ref);
		EndIf;
		
		RefreshDataRepresentation();
		FillTableDS();
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenCertificate(Command)
	
	If Items.DS.CurrentData <> Undefined Then
		ShowCertificate(Items.DS.CurrentData.LineNumber, Items.DS.CurrentData.Imprint);
	Else
		ClearMessages();
		ErrorText = NStr("en='Select a certificate in the signature list.';ru='Выберите сертификат в списке установленных подписей.'");
		CommonUseClientServer.MessageToUser(ErrorText);
	EndIf;
	
EndProcedure

&AtClient
Procedure TrustThisCertificate(Command)
	
	AddCertificateToTrusted(Items.DS.CurrentData);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
Procedure SetEnabledOfItems()
	
	DirectionOutgoing = (Object.Direction = Enums.EDDirections.Outgoing);
	
	StatusReady = Documents.RandomED.ObjectStatusReady(Object);
	
	StatusIsNotReady = Documents.RandomED.ObjectStatusIsNotReady(Object);
	
	StatusPassed = Documents.RandomED.ObjectStatusPassed(Object);
	
	EDRefused = (Object.DocumentStatus = Enums.EDStatuses.Rejected
		OR Object.DocumentStatus = Enums.EDStatuses.RejectedByReceiver
		OR Object.DocumentStatus = Enums.EDStatuses.TransferError);
	
	HasAttachments = (Attachments.Count() > 0);
	ConfirmationRequired = Object.ConfirmationRequired;
	
	Items.Attachments.ReadOnly  = Not DirectionOutgoing;
	Items.Message.ReadOnly = Not DirectionOutgoing;
	
	Items.Attachments.CommandBar.ChildItems.Add.Visible = DirectionOutgoing;
	Items.Attachments.CommandBar.ChildItems.Delete.Visible  = DirectionOutgoing;
	
	Items.Sign.Enabled             = (NOT (StatusPassed OR EDRefused) AND HasAttachments AND (DirectionOutgoing OR ConfirmationRequired));
	Items.SignAndSendED.Enabled = (StatusReady AND HasAttachments AND (DirectionOutgoing OR ConfirmationRequired));
	
	CommandBar.ChildItems.SignAndSendED.Title = NStr(
		?(DirectionOutgoing, "en = 'Send document'", "en = 'Send the response signature'"));
	
	If Not (StatusReady OR StatusIsNotReady) Then
		Items.Add.Enabled  = False;
		Items.Delete.Enabled   = False;
		Items.Message.Enabled = False;
	Else
		Items.Add.Enabled  = Not HasAttachments;
		Items.Delete.Enabled   = HasAttachments;
	EndIf;
	
	If ValueIsFilled(Object.Ref) AND DirectionOutgoing
		AND (Object.DocumentStatus = Enums.EDStatuses.Created
			OR Object.DocumentStatus = Enums.EDStatuses.DigitallySigned
			OR Object.DocumentStatus = Enums.EDStatuses.PreparedToSending) AND Not EDRefused Then
		Items.ConfirmationRequired.ReadOnly = False;
	Else
		Items.ConfirmationRequired.ReadOnly = True;
	EndIf;
	
	Items.FormCancelRejection.Visible = DirectionOutgoing;
	
	If EDRefused Then
		RejectionReasons.Clear();
		NewRow = RejectionReasons.Add();
		NewRow.RejectionReason = Attachments[0].Ref.RejectionReason;
		Items.FolderPagesFooter.CurrentPage = Items.FolderPagesFooter.ChildItems.GroupPageRejection;
		Items.FormReject.Enabled = False;
		Items.FormCancelRejection.Enabled = (Object.DocumentStatus = Enums.EDStatuses.Rejected);
	Else
		RejectionReasons.Clear();
		Items.FolderPagesFooter.CurrentPage = Items.FolderPagesFooter.ChildItems.GroupStatusesAndStates;
		Items.FormReject.Enabled = ?(StatusPassed OR Not HasAttachments, False, True);
		Items.FormCancelRejection.Enabled = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshFormTitle()
	
	If Object.Direction = Enums.EDDirections.Outgoing Then
		HeaderText = NStr("en='Outgoing document %1 from %2';ru='Исходящий документ %1 от %2'");
		Title = StringFunctionsClientServer.SubstituteParametersInString(
			HeaderText, Object.Number, Object.Date);
	Else
		HeaderText = NStr("en='Incoming document %1 from %2';ru='Входящий документ %1 от %2'");
		Title = StringFunctionsClientServer.SubstituteParametersInString(
			HeaderText, Object.Number, Object.Date);
	EndIf;

EndProcedure

&AtServer
Procedure RecordNewDocument(RecordFlag)
	
	ObjectDocument = FormAttributeToValue("Object");
	If IsAgreement(ObjectDocument) Then
		ObjectDocument.Date = CurrentSessionDate();
		ObjectDocument.Write();
		ValueToFormAttribute(ObjectDocument, "Object");
		UpdateFooterInformation();
		
		RecordFlag = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure AddAttachedFilesToPost(StructuresArray)
	
	ReturnArray = New Array;
	AgreementParameters = ElectronicDocumentsService.DetermineEDExchangeSettingsBySource(Object.Ref);
	If ValueIsFilled(AgreementParameters) Then
		CompanyID = AgreementParameters.CompanyID;
		CounterpartyID = AgreementParameters.CounterpartyID;
		EDAgreement             = AgreementParameters.EDAgreement;
	EndIf;
	
	If Not ValueIsFilled(AgreementParameters) AND Not ValueIsFilled(EDAgreement) Then
		Return;
	EndIf;
	
	For Each FileStructure IN StructuresArray Do
		FileWithoutExtension = Undefined;
		FileExtension = Undefined;
		AddressInTemporaryStorage = Undefined;
		If Not FileStructure.Property("FileWithoutExtension", FileWithoutExtension)
			OR Not FileStructure.Property("FileExtension", FileExtension)
			OR Not FileStructure.Property("AddressInTemporaryStorage", AddressInTemporaryStorage) Then
			Continue;
		EndIf;
		AddedFile = AttachedFiles.AddFile(Object.Ref,
														   FileWithoutExtension,
														   CommonUseClientServer.ExtensionWithoutDot(FileExtension),
														   CurrentSessionDate(),
														   CurrentSessionDate(),
														   AddressInTemporaryStorage,
														   ,
														   ,
														   Catalogs.EDAttachedFiles.GetRef());
			
		ReturnArray.Add(AddedFile);
		
		DocumentNumber = ElectronicDocumentsInternal.ReturnEDId(
			AddedFile, CompanyID, Undefined);
		
		DocumentStructure =  New Structure(
			"Author, EDOwner, Company,
			|Counterparty, EDKind, EDDirection, EDNumber,
			|UniqueId, Sender, Recipient, SenderDocumentNumber, SenderDocumentDate, EDVersionNumber, EDFProfileSettings,
			|EDAgreement, VersionPointTypeED, EDStatus, FileDescription",
			Users.AuthorizedUser(), Object.Ref, Object.Company, Object.Counterparty,
			Enums.EDKinds.RandomED, Enums.EDDirections.Outgoing, DocumentNumber, DocumentNumber,
			CompanyID, CounterpartyID, Object.Number, Object.Date, 0, EDFProfileSettings, EDAgreement,
			Enums.EDVersionElementTypes.PrimaryED, Enums.EDStatuses.Created, FileWithoutExtension);
			
		ElectronicDocumentsService.ChangeByRefAttachedFile(AddedFile, DocumentStructure);
	EndDo;
	
	Read();
	
EndProcedure

&AtServer
Procedure UpdateTableAttachment()
	
	QueryAttachment = New Query;
	QueryAttachment.SetParameter("FileOwner", Object.Ref);
	QueryAttachment.Text =
	"SELECT
	|	EDAttachedFiles.Ref AS Ref,
	|	EDAttachedFiles.Description AS FileName,
	|	EDAttachedFiles.Extension AS Extension
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.FileOwner = &FileOwner
	|	AND EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.RandomED)
	|	AND Not EDAttachedFiles.DeletionMark";
	Result = QueryAttachment.Execute().Unload();
	
	Result.Columns.Add("PictureIndex");
	Result.Columns.Add("FileDescription");
	
	For Each ResultsItem IN Result Do
		
		ResultsItem.PictureIndex = FileFunctionsServiceClientServer.GetFileIconIndex(
			ResultsItem.Extension);
		ResultsItem.FileDescription = ResultsItem.FileName + "." + ResultsItem.Extension;
		
	EndDo;
	
	ValueToFormAttribute(Result, "Attachments");
	
EndProcedure

&AtServer
Procedure UpdateStatusDocument(DocumentParameters)
	
	DocumentObject = FormAttributeToValue("Object");
	
	If DocumentParameters.Property("ArrayToSend") AND DocumentParameters.ArrayToSend.Count() > 0 Then
		ED = DocumentParameters.ArrayToSend[0];
		DocumentObject.DocumentStatus = ED.EDStatus;
	EndIf;
	
	If DocumentParameters.Property("DigitallySigned") AND DocumentParameters.DigitallySigned Then
		If DocumentObject.Direction = Enums.EDDirections.Incoming Then
			DocumentObject.DocumentStatus = Enums.EDStatuses.ConfirmationPrepared;
		Else
			DocumentObject.DocumentStatus = Enums.EDStatuses.PreparedToSending;
		EndIf;
	EndIf;
	
	If (AgreementWasDefined AND ValueIsFilled(EDAgreement))
		OR (NOT AgreementWasDefined AND IsAgreement(DocumentObject)) Then
		DocumentObject.Write();
		UpdateFooterInformation();
		ValueToFormAttribute(DocumentObject, "Object");
		Read();
		RefreshFormTitle();
	EndIf;
	
EndProcedure


&AtServer
Function GetEDArrayToSend(Cancel)
	
	DocumentObject = FormAttributeToValue("Object");
	If Modified AND IsAgreement(DocumentObject) Then
		DocumentObject.Write();
		ValueToFormAttribute(DocumentObject, "Object");
	EndIf;
	
	If EDFProfileSettings.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
		AND DS.Count() = 0 Then
		MessageText = NStr("en='Operation is canceled. Sign the attachment.';ru='Операция отменена. Необходимо подписать вложение.'");
		CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
	EndIf;
	ReturnStructure = "";
	If Not Cancel Then
		TableAttachment = FormAttributeToValue("Attachments");

		ArrayAttachment = TableAttachment.UnloadColumn("Ref");
		ThisIsOutgoingDocument = Object.Direction = Enums.EDDirections.Outgoing;
		
		ReturnStructure = New Structure("ArrayToSend, ThisIsOutgoingDocument", ArrayAttachment, ThisIsOutgoingDocument);
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

&AtClient
Procedure ProcessSelectedDocuments(ParametersSignatures)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ParametersSignatures", ParametersSignatures);
	
	NotifyDescription = New NotifyDescription("AfterSendingEDP", ThisObject, ParametersSignatures);
	ElectronicDocumentsServiceClient.ProcessED(Undefined, "Send", , ParametersSignatures.ArrayToSend, NotifyDescription);

EndProcedure

&AtClient
Procedure AfterSendingEDP(Result, AdditionalParameters) Export
	
	Read();
	
	Quantity = 0;
	PreparedCnt = 0;
	SentCnt = 0;
	If TypeOf(Result) = Type("Structure") Then
		If Result.Property("SentCnt", SentCnt)
			AND TypeOf(SentCnt) = Type("Number")
			AND SentCnt > 0 Then
			
			StatusText = NStr("en='Sent: (%1)';ru='Отправлено: (%1)'");
			Quantity = SentCnt;
		ElsIf Result.Property("PreparedCnt", PreparedCnt)
			AND TypeOf(PreparedCnt) = Type("Number")
			AND PreparedCnt > 0 Then
			
			StatusText = NStr("en='Prepared for dispatch: (%1)';ru='Подготовлено к отправке: (%1)'");
			Quantity = PreparedCnt;
		EndIf;
	EndIf;
	
	If Quantity > 0 Then
		StatusText = StringFunctionsClientServer.SubstituteParametersInString(StatusText, Quantity);
		HeaderText = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
		ShowUserNotification(HeaderText, , StatusText);
	EndIf;
	
	UpdateStatusDocument(AdditionalParameters);
	Notify("RefreshStateED");
	
EndProcedure


&AtServer
Procedure DeleteUnnecessaryFilesAttached()
	
	ParametersSelections = New Structure("FileOwner", Object.Ref);
	AttachedFilesSelection = ElectronicDocumentsService.GetEDSelectionByFilter(ParametersSelections);
	
	While ValueIsFilled(AttachedFilesSelection) AND AttachedFilesSelection.Next() Do
		FilesArray = Attachments.Unload().UnloadColumn("Ref");
		If FilesArray.Find(AttachedFilesSelection.Ref) = Undefined Then
			AttachedFilesSelection.Ref.GetObject().SetDeletionMark(True, True);
		EndIf;
	EndDo;
	ObjectDocument = FormAttributeToValue("Object");
	If IsAgreement(ObjectDocument) Then
		UpdateEDStatus();
		FillTableDS();
	EndIf;
	
EndProcedure

&AtServer
Function IsAgreement(ObjectDocument)
	
	EDSettings = ElectronicDocumentsService.DetermineEDExchangeSettingsBySource(ObjectDocument);
	AgreementWasDefined = True;
	If ValueIsFilled(EDSettings) Then
		ObjectDocument.AdditionalProperties.Insert("IsAgreement", True);
		EDAgreement = EDSettings.EDAgreement;
		EDFProfileSettings = EDSettings.EDFProfileSettings;
		Return True;
	Else
		EDAgreement = Catalogs.EDUsageAgreements.EmptyRef();
		EDFProfileSettings = Catalogs.EDFProfileSettings.EmptyRef();
	EndIf;
	
	Return False;
	
EndFunction

&AtServer
Procedure RequiredToSetConfirmationByAgreement(CurrentObject)
	
	Required = False;
	ExchangeMethod = CommonUse.ObjectAttributeValue(EDAgreement, "EDExchangeMethod");
	If ExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
		Required = True;
	Else
		Query = New Query;
		Query.Text =
		"SELECT
		|	EDUsageAgreementsOutgoingDocuments.UseDS
		|FROM
		|	Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
		|WHERE
		|	EDUsageAgreementsOutgoingDocuments.OutgoingDocument = VALUE(Enum.EDKinds.RandomED)
		|	AND EDUsageAgreementsOutgoingDocuments.Ref = &EDAgreement";
		
		Query.SetParameter("EDAgreement", EDAgreement);
		
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			Required = Selection.UseDS;
		EndIf;
	EndIf;
	CurrentObject.ConfirmationRequired = Required;
	
EndProcedure

&AtServer
Procedure FillTableDS()
	
	If Not ValueIsFilled(EDAgreement)
		OR Not EDAgreement.VerifySignatureCertificates Then
		
		TableDS = FormAttributeToValue("DS");
		TableDS.Clear();
		For Each Attachment IN Attachments Do
			For Each CurRow IN Attachment.Ref.DigitalSignatures Do
				NewRow = TableDS.Add();
				FillPropertyValues(NewRow, CurRow);
				FillSignatureStatus(NewRow, CurRow);
			EndDo;
		EndDo;
		
		ValueToFormAttribute(TableDS, "DS");
		Return;
	EndIf;
	
	ExpectedCertificateTumbprintsArray = ElectronicDocumentsService.ExpectedCertificateThumbprints(Attachments[0].Ref);
	
	TableDS = FormAttributeToValue("DS");
	TableDS.Clear();
	
	For Each Attachment IN Attachments Do
		For Each CurRow IN Attachment.Ref.DigitalSignatures Do
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
	EndDo;
	ValueToFormAttribute(TableDS, "DS");
	
EndProcedure

&AtServer
Procedure FillSignatureStatus(NewRow, CurRow)
	
	If ValueIsFilled(CurRow.SignatureVerificationDate) Then
		NewRow.SignatureIsCorrect = ?(CurRow.SignatureIsCorrect, NStr("en='Correct';ru='Исправить'"), NStr("en='Incorrect';ru='Неверна'"))
			+" (" + CurRow.SignatureVerificationDate + ")";
	Else
		NewRow.SignatureIsCorrect = NStr("en='Not checked';ru='Не проверена'");
	EndIf
	
EndProcedure

&AtServer
Procedure UpdateEDStatus()
	
	StatusTable = GetEDStatusTable(Object.Ref);
	If ValueIsFilled(StatusTable) Then
		ValueToFormAttribute(StatusTable, "EDStatuses");
	EndIf;
	
EndProcedure

&AtServer
Function GetEDStatusTable(ED)
	
	EDStatusMap = New ValueTable;
	EDStatusMap.Columns.Add("Status");
	EDStatusMap.Columns.Add("Passed");
	
	FillEDStatusMap(EDStatusMap);
	PassedSign = True;
	For Each CurRow IN EDStatusMap Do
		CurRow.Passed = PassedSign;
		If CurRow.Status = Enums.EDStatuses.Approved
			AND (ED.DocumentStatus = Enums.EDStatuses.Rejected OR ED.DocumentStatus = Enums.EDStatuses.RejectedByReceiver) Then
			CurRow.Status = Enums.EDStatuses.Rejected;
			Break;
		EndIf;
		If ED.DocumentStatus = CurRow.Status Then
			Break;
		EndIf;
	EndDo;
	
	Return EDStatusMap;
	
EndFunction

&AtServer
Procedure AddStatus(EDStatusMap, Status, Value = False)
	
	NewRow = EDStatusMap.Add();
	NewRow.Status = Status;
	NewRow.Passed = Value;
	
EndProcedure

&AtServer
Procedure FillEDStatusMap(EDStatusMap)
	
	EDParameters = New Structure("EDKind, EDDirection, EDFScheduleVersion, Company, Counterparty, EDAgreement",
		Enums.EDKinds.RandomED, Object.Direction, Enums.Exchange1CRegulationsVersion.Version20,
		Object.Company, Object.Counterparty, EDAgreement);
	
	StatusSettings = New ValueTable;
	StatusSettings.Columns.Add("ExchangeMethod");
	StatusSettings.Columns.Add("Direction");
	StatusSettings.Columns.Add("EDKind");
	StatusSettings.Columns.Add("UseSignature");
	StatusSettings.Columns.Add("UseReceipt");
	StatusSettings.Columns.Add("UsedFewSignatures");
	StatusSettings.Columns.Add("EDFScheduleVersion");
	StatusSettings.Columns.Add("BankApplication");
	StatusSettings.Columns.Add("RequireConfirmation");
	DSUsed = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
															"UseDigitalSignatures");
	
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
		|	(SELECT
		|		True AS UseSignature,
		|		True AS UseReceipt,
		|		CASE
		|			WHEN &EDDirection = VALUE(Enum.EDDirections.Outgoing)
		|				THEN VALUE(Enum.EDDirections.Outgoing)
		|			WHEN &EDDirection = VALUE(Enum.EDDirections.Incoming)
		|				THEN VALUE(Enum.EDDirections.Incoming)
		|			ELSE VALUE(Enum.EDDirections.Intercompany)
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
		|		AND Not EDUsageAgreementsOutgoingDocuments.Ref.DeletionMark) AS Agreement";
	Result = Query.Execute().Select();
	
	If Result.Next() Then
		NewRow = StatusSettings.Add();
		NewRow.ExchangeMethod          = Result.ExchangeMethod;
		NewRow.Direction           = Result.Direction;
		NewRow.EDKind                 = Result.EDKind;
		NewRow.UseSignature   = Result.UseSignature;
		NewRow.UseReceipt = Result.UseReceipt;
		NewRow.RequireConfirmation = Object.ConfirmationRequired;

		NewRow.EDFScheduleVersion   = EDParameters.EDFScheduleVersion;
		NewRow.BankApplication        = Result.BankApplication;
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
Procedure UpdateFooterInformation()
	
	If ValueIsFilled(Object.Ref) Then
		If Not (AgreementWasDefined AND ValueIsFilled(EDAgreement)) Then
			DocumentObject = FormAttributeToValue("Object");
			IsAgreement = IsAgreement(DocumentObject);
		Else
			IsAgreement = True;
		EndIf;
		If IsAgreement Then
			UpdateEDStatus();
			FillTableDS();
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeStatusReject()
	
	CurrentStatus = ?(EDRefused, Enums.EDStatuses.Rejected, Enums.EDStatuses.Created);
	ParametersStructure = New Structure("EDStatus", CurrentStatus);
	ElectronicDocumentsService.ChangeByRefAttachedFile(Attachments[0].Ref, ParametersStructure, False);
	Object.DocumentStatus = CurrentStatus;
	
EndProcedure

&AtServer
Function CancelRejectionOnServer()
	
	EDRefused = False;
	ElectronicDocument = Attachments[0].Ref.GetObject();
	ElectronicDocument.RejectionReason = "";
	If Object.Direction = Enums.EDDirections.Outgoing Then
		ElectronicDocument.DigitalSignatures.Clear();
	EndIf;
	ElectronicDocument.Write();
	ChangeStatusReject();
	
	Return True;
	
EndFunction

&AtServer
Procedure ExecuteNotificationProcessingAtServer()
	
	If ValueIsFilled(Object.Ref) Then
		ValueToFormAttribute(Object.Ref.GetObject(), "Object");
	EndIf;
	
	FillTableDS();
	UpdateEDStatus();
	SetEnabledOfItems();
	
EndProcedure

&AtServer
Function CertificateDataAddress(LineNumber)
	
	LinksToCertificateDataRepository = Undefined;
	If Attachments.Count() > 0 Then
		CertificateBinaryData = Attachments[0].Ref.DigitalSignatures[LineNumber-1].Certificate.Get();
		LinksToCertificateDataRepository = PutToTempStorage(CertificateBinaryData, UUID);
	EndIf;
	
	Return LinksToCertificateDataRepository;
	
EndFunction

&AtClient
Procedure ShowCertificate(LineNumber, Imprint)
	
	CertificateDataAddress = CertificateDataAddress(LineNumber);
	CertificateBinaryData = GetFromTempStorage(CertificateDataAddress);
	
	SelectedCertificate = New CryptoCertificate(CertificateBinaryData);
	If SelectedCertificate=Undefined Then
		CommonUseClientServer.MessageToUser(NStr("en='Certificate is not found.';ru='Сертификат не найден.'"));
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
Procedure AddSigningCertificateInAgreement(Imprint, CertificateAdded)
	
	If Not (AgreementWasDefined AND ValueIsFilled(EDAgreement)) OR Attachments.Count() = 0 Then
		Return ;
	EndIf;
	
	FoundString = Attachments[0].Ref.DigitalSignatures.Find(Imprint, "Imprint");
	If Not FoundString = Undefined Then
		AgreementObject = EDAgreement.GetObject();
		
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
		Text = NStr("en='Add certificate %1 to the list of expected certificates of the counterparty?';ru='Добавить сертификат %1 в список ожидаемых сертификатов контрагента?'");
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(Text, SignatureData.CertificateIsIssuedTo);
		AdditParameters = New Structure("CurrentData, SignatureData", Items.DS.CurrentData, SignatureData);
		NotifyDescription = New NotifyDescription("HandleQuestionAnswerByCertificate", ThisObject, AdditParameters);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure


&AtClient
Procedure CancelRejectED(Result, Reject = False) Export
	
	NotifyDescription = New NotifyDescription("ExecuteActionsAfterRefusingED", ThisObject);
	EDParameters = New Structure("Company, Reject, NotificationDescription",
		Object.Company, Reject, NotifyDescription);
	ElectronicDocumentsServiceClient.HandleEDDeviationCancellation(Attachments[0].Ref, EDParameters);
	
EndProcedure

&AtClient
Procedure ExecuteActionsAfterRefusingED(Result, AdditionalParameters) Export
	
	If Result = True Then
		EDRefused = True;
		ChangeStatusReject();
		Notify("RefreshStateED");
	EndIf;
	
EndProcedure


&AtClient
Procedure HandleQuestionAnswerByCertificate(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		CurrentData = AdditionalParameters.CurrentData;
		ShowCertificate(CurrentData.LineNumber,CurrentData.Imprint);
	Else
		// Add a certificate to the Agreement.
		SignatureData = AdditionalParameters.SignatureData;
		CertificateAdded = False;
		AddSigningCertificateInAgreement(SignatureData.Imprint, CertificateAdded);
		If Not CertificateAdded Then 
			MessageText = NStr("en='An error occurred when adding a certificate to the expected certificate list.';ru='Ошибка добавления сертификата подписи в список ожидаемых сертификатов!'");
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			FillTableDS();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessDeletionQuestionAnswerAttachments(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Attachments.Clear();
		ProcessAttachmentDeletion();
	EndIf;
	
EndProcedure

&AtClient
Procedure AddAttachment(FilePlaced, AddressInStorage, SelectedFile, AdditionalParameters) Export
	
	FileStructure  = New Structure;
	StructuresArray  = New Array;
	If FilePlaced Then
		FileStructure = CommonUseClientServer.SplitFullFileName(SelectedFile);
		FileStructure.Insert("FileWithoutExtension",         FileStructure.BaseName);
		FileStructure.Insert("FileExtension",            FileStructure.Extension);
		FileStructure.Insert("AddressInTemporaryStorage", AddressInStorage);
		StructuresArray.Add(FileStructure);
		AddAttachedFilesToPost(StructuresArray);
	EndIf;
	UpdateTableAttachment();
	SetEnabledOfItems();
	
EndProcedure

&AtClient
Procedure EndDocumentWritingCheck(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		RecordFlag = False;
		RecordNewDocument(RecordFlag);
		If RecordFlag Then
			ContinuationProcessor = "";
			If TypeOf(AdditionalParameters) = Type("Structure")
				AND AdditionalParameters.Property("ProcedureName", ContinuationProcessor)
				AND TypeOf(ContinuationProcessor) = Type("NotifyDescription") Then
				ExecuteNotifyProcessing(ContinuationProcessor);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckDocumentRecord(ContinuationProcessor)
	
	If Modified OR Object.Ref.IsEmpty() Then
		QuestionText = NStr("en='To continue operation, it is required to write the document.
		|Write document?';ru='Для продолжения операции необходимо записать документ.
		|Записать документ?'");
		AdditParameters = New Structure("ProcedureName", ContinuationProcessor);
		NotifyDescription = New NotifyDescription("EndDocumentWritingCheck", ThisObject, AdditParameters);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	Else
		ExecuteNotifyProcessing(ContinuationProcessor);
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessEDRejectionCancelation(NOTSpecified, AdditionalParameters) Export
	
	If CancelRejectionOnServer() Then
		Notify("RefreshStateED");
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishAddingFile(NOTSpecified, AdditionalParameters) Export
	
	// Limit the Taxcom operator to the passed attachments quantity.
	If Attachments.Count() > 0 Then
		MessageText = NStr("en='Operation is canceled. You can add only one attachment.';ru='Операция отменена. Добавить возможно только одно вложение.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	AddressInStorage = Undefined;
	SelectedFile   = "";
	
	NotifyDescription = New NotifyDescription("AddAttachment", ThisObject);
	BeginPutFile(NOTifyDescription, AddressInStorage, SelectedFile, True, UUID);
	
EndProcedure
