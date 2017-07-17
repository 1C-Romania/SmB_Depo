////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Info base update

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Handler of the
// BED 1.1.13.4 update Fills date of certificate expiration
//
Procedure FillFileDescription() Export
	
	ItemRef = Catalogs.EDAttachedFiles.Select();
	
	While ItemRef.Next() Do
		
		Try
			ItemObject = ItemRef.GetObject();
			If ItemObject.EDKind = Enums.EDKinds.CorrectiveInvoiceNote Then
				StringAtID = ItemObject.UniqueId;
				Description = ItemObject.Description;
				UIDPosition = Find(Description, "_" + Left(StringAtID, 35));
				If UIDPosition > 0 Then
					ItemObject.FileDescription = Left(Description, UIDPosition) + StringAtID;
				EndIf;
			Else
				ItemObject.FileDescription = ItemObject.Description;
			EndIf;
			InfobaseUpdate.WriteObject(ItemObject);
		Except
		EndTry;
		
	EndDo;
	
EndProcedure

// Handler of the
// BED 1.2.4.4 update changes the current status of custom ED from NotSent to Created.
//
Procedure ChangeCustomEDSStatusesNotSentToFormed() Export
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	EDAttachedFiles.Ref
		|FROM
		|	Catalog.EDAttachedFiles AS EDAttachedFiles
		|WHERE
		|	EDAttachedFiles.EDStatus = &StatusNotSent
		|	AND EDAttachedFiles.EDKind = &CustomEDKind";
	
	Query.SetParameter("CustomEDKind", Enums.EDKinds.RandomED);
	Query.SetParameter("StatusNotSent", Enums.EDStatuses.NotSent);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	If ExclusiveMode() Then
		SwitchOffSoleMode = False;
	Else
		SwitchOffSoleMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		Try
			BeginTransaction();
			Object = Selection.Ref.GetObject();
			Object.EDStatus = Enums.EDStatuses.Created;
			InfobaseUpdate.WriteObject(Object);
			CommitTransaction();
		Except
			ShowMessageAboutError(ErrorInfo());
			RollbackTransaction();
		EndTry;
	EndDo;
	
	If SwitchOffSoleMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

// Procedure from universal
// processing of SearchAndReplaceValues Changes:
// - the Report method is replaced with EventLogMonitorWrite(...)
//
Procedure ShowMessageAboutError(Val Description)
	
	If TypeOf(Description) = Type("ErrorInfo") Then
		Description = ?(Description.Cause = Undefined, Description, Description.Cause).Description;
	EndIf;
	
	WriteLogEvent(
		NStr("en='Digital signature certificates. Transfer settings to new metadata object';ru='Сертификаты электронной подписи. Перенос настроек в новый объект метаданных'",
		     CommonUseClientServer.MainLanguageCode()),
		EventLogLevel.Error,
		,
		,
		Description,
		EventLogEntryTransactionMode.Independent);
	
EndProcedure


// Forms printing forms.
//
// Parameters:
//  ObjectsArray  - Array    - references to objects to be printed;
//  PrintParameters - Structure - additional printing settings;
//  PrintFormsCollection - ValueTable - formed table documents (output
//  parameter) PrintObjects         - ValueList  - value - ref to object;
//                                            Presentation - area name in which the object was shown (output parameter);
//  OutputParameters       - Structure       - additional parameters of the formed tablular documents (output parameter).
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	PrintEDCard = PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "EDCard");
	If PrintEDCard Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"EDCard",
			NStr("en='Electronic document card';ru='Карточка электронного документа'"),
			PrintEDCard(ObjectsArray, PrintObjects, "EDCard"),
			,
			"Catalog.EDAttachedFiles.PF_MXL_EDCard");
	EndIf;
	
	PrintED = PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "ED");
	If PrintED Then
		Spreadsheet = EDPrint(ObjectsArray, PrintObjects);
		TemplateSynonym = NStr("en='Electronic document';ru='Электронный документ'");
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "ED", TemplateSynonym, Spreadsheet);
		If TypeOf(Spreadsheet) = Type("String") Then
			DeleteFiles(Spreadsheet);
		EndIf;
	EndIf;

EndProcedure

Function EDPrint(LinkToED, PrintObjects)
	
	Spreadsheet = EDDataFile(LinkToED);
		
	Return Spreadsheet;
	
EndFunction

Function PrintEDCard(ObjectsArray, PrintObjects, TemplateName ="EDCard")
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EDAttachedFiles.Ref,
	|	EDAttachedFiles.FileDescription AS FileDescription,
	|	EDAttachedFiles.EDFrom AS Sender,
	|	EDAttachedFiles.EDRecipient AS Recipient,
	|	EDAttachedFiles.EDKind AS EDKindRef,
	|	PRESENTATION(EDAttachedFiles.EDKind) AS DocumentKind,
	|	"""" AS DocumentType,
	|	EDAttachedFiles.UniqueId AS ID,
	|	"""" AS EDNumber,
	|	"""" AS EDDate,
	|	EDAttachedFiles.AdditionalInformation AS CoveringNote,
	|	EDAttachedFiles.Extension,
	|	EDAttachedFiles.Counterparty,
	|	EDAttachedFiles.Company,
	|	EDAttachedFiles.EDFProfileSettings,
	|	EDAttachedFiles.EDDirection AS EDDirection,
	|	EDAttachedFiles.FileOwner AS FileOwner
	|INTO tED
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.Ref IN(&ObjectsArray)
	|	AND Not EDAttachedFiles.EDKind IN (&ServiceED)
	|
	|UNION ALL
	|
	|SELECT
	|	EDAttachedFiles.Ref,
	|	EDAttachedFiles.FileDescription,
	|	EDAttachedFiles.EDFrom,
	|	EDAttachedFiles.EDRecipient,
	|	EDAttachedFiles.EDKind,
	|	PRESENTATION(EDAttachedFiles.EDKind),
	|	PRESENTATION(RandomED.DocumentType),
	|	EDAttachedFiles.UniqueId,
	|	RandomED.Number,
	|	RandomED.Date,
	|	RandomED.Text,
	|	EDAttachedFiles.Extension,
	|	RandomED.Counterparty,
	|	RandomED.Company,
	|	EDAttachedFiles.EDFProfileSettings,
	|	RandomED.Direction,
	|	EDAttachedFiles.FileOwner
	|FROM
	|	Document.RandomED AS RandomED
	|		INNER JOIN Catalog.EDAttachedFiles AS EDAttachedFiles
	|		ON RandomED.Ref = EDAttachedFiles.FileOwner
	|WHERE
	|	RandomED.Ref IN(&ObjectsArray)
	|	AND Not EDAttachedFiles.EDKind IN (&ServiceED)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EDAttachedFilesDigitalSignatures.Imprint,
	|	EDAttachedFilesDigitalSignatures.SignatureIsCorrect AS SignatureIsCorrect,
	|	EDAttachedFilesDigitalSignatures.SignatureVerificationDate,
	|	EDAttachedFilesDigitalSignatures.CertificateIsIssuedTo,
	|	EDAttachedFilesDigitalSignatures.Ref,
	|	EDAttachedFilesDigitalSignatures.Certificate
	|INTO TPrints
	|FROM
	|	Catalog.EDAttachedFiles.DigitalSignatures AS EDAttachedFilesDigitalSignatures
	|WHERE
	|	EDAttachedFilesDigitalSignatures.Ref In
	|			(SELECT
	|				tED.Ref
	|			IN
	|				tED)
	|
	|UNION ALL
	|
	|SELECT
	|	EDAttachedFilesDigitalSignatures.Imprint,
	|	EDAttachedFilesDigitalSignatures.SignatureIsCorrect,
	|	EDAttachedFilesDigitalSignatures.SignatureVerificationDate,
	|	EDAttachedFilesDigitalSignatures.CertificateIsIssuedTo,
	|	EDAttachedFilesDigitalSignatures.Ref,
	|	EDAttachedFilesDigitalSignatures.Certificate
	|FROM
	|	Catalog.EDAttachedFiles.DigitalSignatures AS EDAttachedFilesDigitalSignatures
	|WHERE
	|	EDAttachedFilesDigitalSignatures.Ref.ElectronicDocumentOwner In
	|			(SELECT
	|				tED.Ref
	|			IN
	|				tED)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EDUsageAgreementsOutgoingDocuments.UseDS AS SignatureRequired,
	|	EDUsageAgreementsOutgoingDocuments.Ref.Company AS CompanySignature,
	|	EDUsageAgreementsOutgoingDocuments.Ref.Counterparty AS CounterpartySignature,
	|	tED.Ref AS Ref,
	|	tED.EDKindRef,
	|	tED.EDDirection AS EDDirection,
	|	FALSE AS RandomED
	|FROM
	|	tED AS tED
	|		INNER JOIN Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
	|		ON tED.EDFProfileSettings = EDUsageAgreementsOutgoingDocuments.EDFProfileSettings
	|WHERE
	|	EDUsageAgreementsOutgoingDocuments.OutgoingDocument In
	|			(SELECT
	|				TED.EDKindRef
	|			IN
	|				TED)
	|	AND EDUsageAgreementsOutgoingDocuments.Ref.Company In
	|			(SELECT
	|				TED.Company
	|			IN
	|				TED)
	|	AND EDUsageAgreementsOutgoingDocuments.Ref.Counterparty In
	|			(SELECT
	|				TED.Counterparty
	|			IN
	|				TED)
	|
	|UNION ALL
	|
	|SELECT
	|	RandomED.ConfirmationRequired,
	|	RandomED.Company,
	|	RandomED.Counterparty,
	|	tED.Ref,
	|	tED.EDKindRef,
	|	tED.EDDirection,
	|	TRUE
	|FROM
	|	tED AS tED
	|		INNER JOIN Document.RandomED AS RandomED
	|		ON tED.FileOwner = RandomED.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	tED.FileDescription,
	|	tED.Sender,
	|	tED.Recipient,
	|	tED.DocumentKind,
	|	tED.EDKindRef,
	|	tED.DocumentType,
	|	tED.ID,
	|	tED.EDNumber,
	|	tED.EDDate,
	|	tED.CoveringNote,
	|	tED.Extension,
	|	tED.Counterparty,
	|	tED.Company,
	|	tED.EDDirection,
	|	tED.Ref
	|FROM
	|	tED AS tED
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TPrints.SignatureIsCorrect,
	|	TPrints.SignatureVerificationDate,
	|	TPrints.CertificateIsIssuedTo,
	|	TPrints.Ref
	|FROM
	|	TPrints AS TPrints";
	
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	ServiceED = New Array;
	ServiceED.Add(Enums.EDKinds.NotificationAboutReception);
	ServiceED.Add(Enums.EDKinds.NotificationAboutClarification);
	Query.SetParameter("ServiceED", ServiceED);
	
	ResultsArray = Query.ExecuteBatch();
	
	PrintingDataArray = New Array;
	
	FillPrintedFormData(ResultsArray, PrintingDataArray);
	
	Template = PrintManagement.GetTemplate("Catalog.EDAttachedFiles.PF_MXL_EDCard");
	Spreadsheet = New SpreadsheetDocument;
	
	For Each PrintedFormData IN PrintingDataArray Do
		
		If Spreadsheet.TableHeight > 0 Then
			Spreadsheet.PutHorizontalPageBreak();
		EndIf;
		
		FirstLineNumber = Spreadsheet.TableHeight + 1;
		
		AreaHeader = Template.GetArea("Header");
		AreaHeader.Parameters.Fill(PrintedFormData);
		Spreadsheet.Put(AreaHeader);
		
		If PrintedFormData.Property("EDNumber") Then
			AreaCustomED = Template.GetArea("RandomED");
			AreaCustomED.Parameters.Fill(PrintedFormData);
			Spreadsheet.Put(AreaCustomED);
		EndIf;
		
		If PrintedFormData.Property("CoveringNote") Then
			AreaCoveringNote = Template.GetArea("CoveringNote");
			AreaCoveringNote.Parameters.Fill(PrintedFormData);
			Spreadsheet.Put(AreaCoveringNote);
		EndIf;
		
		If PrintedFormData.Property("Signatures") Then
			
			AreaCoveringNote = Template.GetArea("RequiredSignatures");
			AreaCoveringNote.Parameters.Fill(PrintedFormData.Signatures);
			Spreadsheet.Put(AreaCoveringNote);
			
		EndIf;
		
		If PrintedFormData.Property("Certificates") Then
			
			AreaCertificates = Template.GetArea("Certificates");
			Spreadsheet.Put(AreaCertificates);
			
			AreaCertificatesRow = Template.GetArea("CertificatesString");
			For Each CurRow IN PrintedFormData.Certificates Do
				AreaCertificatesRow.Parameters.Fill(CurRow);
				Spreadsheet.Put(AreaCertificatesRow);
			EndDo;
			
		EndIf;
		
		AreaSignature = Template.GetArea("Signature");
		AreaSignature.Parameters.Fill(PrintedFormData);
		Spreadsheet.Put(AreaSignature);
		
		PrintManagement.SetDocumentPrintArea(Spreadsheet, FirstLineNumber, PrintObjects, PrintedFormData.Ref);
		
	EndDo;
	
	Return Spreadsheet;
	
EndFunction

Procedure FillPrintedFormData(QueryResultArray, PrintingDataArray)
	
	NeededSignatures = QueryResultArray[2].Unload();
	EDData = QueryResultArray[3].Unload();
	EDCertificates = QueryResultArray[4].Unload();
	
	EDKindsArray = New Array;
	
	CommonUse.FillArrayWithUniqueValues(EDKindsArray, EDData.UnloadColumn("Ref"));
	
	For Each ArrayElement IN EDKindsArray Do
		
		Filter = New Structure;
		Filter.Insert("Ref", ArrayElement);
		
		EDRowArray = EDData.FindRows(Filter);
		EDDataRow = EDRowArray[0];
		
		PrintedFormData = New Structure;
		PrintedFormData.Insert("Ref", ArrayElement);
		
		FileName = EDDataRow.FileDescription +"." + EDDataRow.Extension;
		PrintedFormData.Insert("FileName", FileName);
		
		If EDDataRow.EDDirection = Enums.EDDirections.Outgoing Then
			Sender = LegalEntityIndividualPresentation(EDDataRow.Company);
			Recipient = LegalEntityIndividualPresentation(EDDataRow.Counterparty);
			
		Else
			Sender = LegalEntityIndividualPresentation(EDDataRow.Counterparty);
			Recipient = LegalEntityIndividualPresentation(EDDataRow.Company);
			
		EndIf;
		
		PrintedFormData.Insert("Sender", Sender);
		PrintedFormData.Insert("Recipient", Recipient);
		
		DocumentType = EDDataRow.DocumentKind + " "+ EDDataRow.DocumentType;
		PrintedFormData.Insert("DocumentType", DocumentType);
		
		If ElectronicDocumentsService.IsFTS(EDDataRow.EDKindRef)Then
			ID = EDDataRow.FileDescription;
		Else
			ID = EDDataRow.ID;
		EndIf;
		PrintedFormData.Insert("ID", ID );
		
		If ValueIsFilled(EDDataRow.EDNumber) Then
			
			PrintedFormData.Insert("EDNumber", EDDataRow.EDNumber);
			PrintedFormData.Insert("EDDate", EDDataRow.EDDate);
			
		EndIf;
		If ValueIsFilled(EDDataRow.CoveringNote) Then
			PrintedFormData.Insert("CoveringNote", EDDataRow.CoveringNote);
		EndIf;
		
		PrintedFormData.Insert("CurrentDate", Format(CurrentSessionDate(), "DLF=D"));
		
		// fill in required signatures
		ArrayNeededSignatures = NeededSignatures.FindRows(Filter);
		RequiredSignatures = Undefined;
		
		FillRequiredSignatures(RequiredSignatures, ArrayNeededSignatures);
		If ValueIsFilled(RequiredSignatures) Then
			PrintedFormData.Insert("Signatures", RequiredSignatures);
		EndIf;
		
		// fill in ED certificates table
		
		CertificatesArrayED = EDCertificates.FindRows(Filter);
		
		CertificatesTable = New ValueTable;
		CertificatesTableInitialization(CertificatesTable);

		For Each ArrayRow IN CertificatesArrayED Do
			
			NewRow = CertificatesTable.Add();
			NewRow.IssuedToWhom = ArrayRow.CertificateIsIssuedTo;
			NewRow.Certificate = ArrayRow.CertificateIsIssuedTo;
			NewRow.Status = SignatureStatus(ArrayRow);
		EndDo;

		PrintedFormData.Insert("Certificates", CertificatesTable);
		
		PrintingDataArray.Add(PrintedFormData);
		
	EndDo;
	
EndProcedure

Procedure FillRequiredSignatures(RequiredSignatures, ArrayNeededSignatures)
	
	If ArrayNeededSignatures.Count() = 0 Then
		Return;
	EndIf;
	
	RequiredSignatures = New Structure;
	RequiredSignatures.Insert("SenderPresentation");
	RequiredSignatures.Insert("RecipientPresentation");
	
	For Each ArrayRow IN ArrayNeededSignatures Do
		
		FillSubscribersPresentation(ArrayRow, RequiredSignatures);
		
	EndDo;
	
EndProcedure

Procedure FillSubscribersPresentation(ArrayRow, RequiredSignatures)
	
	If ArrayRow.RandomED Then
				
		If ArrayRow.SignatureRequired Then
			
			If ArrayRow.EDDirection = Enums.EDDirections.Outgoing Then
				RequiredSignatures.SenderPresentation = LegalEntityIndividualPresentation(ArrayRow.CompanySignature);
				RequiredSignatures.RecipientPresentation = LegalEntityIndividualPresentation(ArrayRow.CounterpartySignature);
				
			Else
				RequiredSignatures.SenderPresentation = LegalEntityIndividualPresentation(ArrayRow.CounterpartySignature);
				RequiredSignatures.RecipientPresentation = LegalEntityIndividualPresentation(ArrayRow.CompanySignature);
				
			EndIf;
		Else
			
			If ArrayRow.EDDirection = Enums.EDDirections.Outgoing Then
				
				RequiredSignatures.SenderPresentation = LegalEntityIndividualPresentation(ArrayRow.CompanySignature);
				RequiredSignatures.RecipientPresentation = NStr("en='Not required';ru='Не требуется'");
				
			Else
				RequiredSignatures.SenderPresentation = LegalEntityIndividualPresentation(ArrayRow.CounterpartySignature);
				RequiredSignatures.RecipientPresentation = NStr("en='Not required';ru='Не требуется'");
				
			EndIf;
			
		EndIf;
		
	Else
		
		If ArrayRow.SignatureRequired Then
			
			If ElectronicDocumentsService.IsFTS(ArrayRow.EDKindRef) Then
						
				If ArrayRow.EDDirection = Enums.EDDirections.Outgoing Then
					RequiredSignatures.SenderPresentation = LegalEntityIndividualPresentation(ArrayRow.CompanySignature);
					RequiredSignatures.RecipientPresentation = NStr("en='Not required';ru='Не требуется'");
					
				Else
					RequiredSignatures.SenderPresentation = LegalEntityIndividualPresentation(ArrayRow.CounterpartySignature);
					RequiredSignatures.RecipientPresentation = NStr("en='Not required';ru='Не требуется'");
				
				EndIf;
			
			Else
				
				If ArrayRow.EDDirection = Enums.EDDirections.Outgoing Then
					RequiredSignatures.SenderPresentation = LegalEntityIndividualPresentation(ArrayRow.CompanySignature);
					RequiredSignatures.RecipientPresentation = LegalEntityIndividualPresentation(ArrayRow.CounterpartySignature);
					
				Else
					RequiredSignatures.SenderPresentation = LegalEntityIndividualPresentation(ArrayRow.CounterpartySignature);
					RequiredSignatures.RecipientPresentation = LegalEntityIndividualPresentation(ArrayRow.CompanySignature);
					
				EndIf;
				
			EndIf;
			
		Else
			RequiredSignatures.SenderPresentation = NStr("en='Not required';ru='Не требуется'");
			RequiredSignatures.RecipientPresentation = NStr("en='Not required';ru='Не требуется'");

		EndIf;

	EndIf;
	
EndProcedure

Function LegalEntityIndividualPresentation(LegalEntityIndividual)
	
	LegalEntityIndividualData = ElectronicDocumentsOverridable.GetDataLegalIndividual(LegalEntityIndividual);
	LegalEntityIndividualPresentation = ElectronicDocumentsOverridable.CompaniesDescriptionFull(LegalEntityIndividualData,"FullDescr,TIN");
	
	Return LegalEntityIndividualPresentation;
	
EndFunction

Function SignatureStatus(SelectionED)
	
	If SelectionED.SignatureIsCorrect Then
		SignatureStatus = "True ("+Format(SelectionED.SignatureVerificationDate,"DLF=DT") + ")";
	Else
		SignatureStatus = "Lie ( "+Format(SelectionED.SignatureVerificationDate,"DLF=DT") + ")";
	EndIf;
	
	Return SignatureStatus;
	
EndFunction

Procedure CertificatesTableInitialization(CertificatesTable)
	
	CertificatesTable.Columns.Add("IssuedToWhom");
	CertificatesTable.Columns.Add("Certificate");
	CertificatesTable.Columns.Add("Status");
	
EndProcedure

Function EDDataFile(LinkToED)
	
	If LinkToED.EDKind = Enums.EDKinds.TORG12Customer
			OR LinkToED.EDKind = Enums.EDKinds.ActCustomer
			OR LinkToED.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient Then
			
			SpreadsheetDocument = EDDataFile(LinkToED.ElectronicDocumentOwner);
			Return SpreadsheetDocument;
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
			ErrorText = NStr("en='Unable to view the electronic document. Check a working directory setting';ru='Не удалось просмотреть электронный документ. Проверьте настройку рабочего каталога'");
			CommonUseClientServer.MessageToUser(ErrorText);
			Return Undefined;
		EndIf;
		
		EDData.Write(FileName);
		
		If Find(AdditInformationAboutED.Extension, "zip") > 0 Then
			
			FolderForUnpacking = ElectronicDocumentsService.WorkingDirectory(,LinkToED.UUID());
			
			If FolderForUnpacking = Undefined Then
				ErrorText = NStr("en='Unable to view the electronic document. Check a working directory setting';ru='Не удалось просмотреть электронный документ. Проверьте настройку рабочего каталога'");
				CommonUseClientServer.MessageToUser(ErrorText);
				DeleteFiles(FileName);
				Return Undefined;
			EndIf;
			
			ZIPReading = New ZipFileReader(FileName);
			Try
				ZipReading.ExtractAll(FolderForUnpacking);
			Except
				ErrorText = BriefErrorDescription(ErrorInfo());
				If Not ElectronicDocumentsService.PossibleToExtractFiles(ZipReading, FolderForUnpacking) Then
					MessageText = ElectronicDocumentsReUse.GetMessageAboutError("006");
				EndIf;
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='ED package Unpacking';ru='распаковка пакета ЭД'"),
					ErrorText, MessageText);
				ZipReading.Close();
				DeleteFiles(FileName);
				DeleteFiles(FolderForUnpacking);
				Return Undefined;
			EndTry;
			
			ZipReading.Close();
			DeleteFiles(FileName);
			ViewingFlag = False;
			
			XMLArchiveFiles = FindFiles(FolderForUnpacking, "*.xml");
			
			For Each UnpackedFile IN XMLArchiveFiles Do
				
				SpreadsheetDocument = ElectronicDocumentsInternal.GenerateEDPrintForm(UnpackedFile.DescriptionFull,
																								LinkToED.EDDirection,
																								LinkToED.UUID(),
																								,
																								AdditInformationAboutED.Description);
					
				If TypeOf(SpreadsheetDocument) = Type("SpreadsheetDocument") Then
					DeleteFiles(FolderForUnpacking);
					Return SpreadsheetDocument;
				EndIf;
				
			EndDo;
			DeleteFiles(FolderForUnpacking);
		ElsIf Find(AdditInformationAboutED.Extension, "xml") > 0 Then
			If LinkToED.EDKind = Enums.EDKinds.Confirmation
				OR LinkToED.EDKind = Enums.EDKinds.NotificationAboutReception
				OR LinkToED.EDKind = Enums.EDKinds.NotificationAboutClarification
				OR LinkToED.EDKind = Enums.EDKinds.TORG12Seller
				OR LinkToED.EDKind = Enums.EDKinds.ActPerformer
				OR LinkToED.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender Then
			
				DataFileName = FileName;
				
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
							ErrorText = NStr("en='Unable to get additional data of the electronic document.
		|Verify the work directory setting';ru='Не удалось получить доп. данные электронного документа.
		|Проверьте настройку рабочего каталога'");
							CommonUseClientServer.MessageToUser(ErrorText);
							DeleteFiles(DataFileName);
							Return Undefined;
						EndIf;
						AdditFileData.Write(AdditDataFileName);
					EndIf;
				EndIf;
				SpreadsheetDocument = ElectronicDocumentsInternal.GenerateEDPrintForm(FileName, LinkToED.EDDirection,
										LinkToED.UUID(), , AdditInformationAboutED.Description, AdditDataFileName);
				If Not AdditDataFileName = Undefined Then
					DeleteFiles(DataFileName);
				EndIf;
				If TypeOf(SpreadsheetDocument) = Type("SpreadsheetDocument") Then
					DeleteFiles(DataFileName);
					Return SpreadsheetDocument;
				EndIf;
			
			ElsIf LinkToED.EDKind = Enums.EDKinds.PaymentOrder
				OR LinkToED.EDKind = Enums.EDKinds.QueryStatement
				OR LinkToED.EDKind = Enums.EDKinds.BankStatement
				OR LinkToED.EDKind = Enums.EDKinds.STATEMENT Then
			
				DataFileName = FileName;
				SpreadsheetDocument = ElectronicDocumentsInternal.GenerateEDPrintForm(
					FileName, LinkToED.EDDirection, LinkToED.UUID(), , LinkToED.UUID());
			
				If TypeOf(SpreadsheetDocument)=Type("SpreadsheetDocument") Then
					DeleteFiles(DataFileName);
					Return SpreadsheetDocument;
				EndIf;

			EndIf;
		Else
			
			Return FileName;
		EndIf;
		
	EndIf;
	
EndFunction

#EndIf