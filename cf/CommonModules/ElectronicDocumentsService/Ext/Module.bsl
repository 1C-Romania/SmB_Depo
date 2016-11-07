////////////////////////////////////////////////////////////////////////////////
// ElectronicDocumentsService: electronic documents exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROGRAMMING INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Objects registration for electronic documents exchange.

// "BeforeWrite" event handler of electronic document owners.
//
// Parameters:
//  Source        - object - attached file
//  owner, Denial           - Boolean - shows that you
//  denied writing, WriteMode     - DocumentWriteMode - mode of electronic document
//  owner writing, PostingMode - DocumentPostingMode - mode of electronic document owner posting.
//
Procedure ElectronicDocumentsOwnerBeforeWrite(Source, Cancel, WriteMode, PostingMode) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseEDExchange") Then
		Return;
	EndIf;
	
	// Mark for deletion (clear mark) electronic documents connected to a user.
	If Not Source.IsNew() Then
		SourceRefDeletionMark = CommonUse.ObjectAttributeValue(Source.Ref, "DeletionMark");
		If Source.DeletionMark <> SourceRefDeletionMark Then
			ElectronicDocumentsServiceCallServer.MarkElectronicDocumentsForDeletionByOwner(Source.Ref);
		EndIf;
	Else
		Source.AdditionalProperties.Insert("IsNewObject", True);
	EndIf;
	
	SourceType = TypeOf(Source);
	
	// do ED only when there is a relevant agreement on cancelation.
	If (NOT Source.AdditionalProperties.Property("IsAgreement") OR Not Source.AdditionalProperties.IsAgreement)
		AND Not SourceType = Type("DocumentObject.EDPackage") Then
		
		EDParameters = FillEDParametersBySource(Source);
		
		If Not ElectronicDocumentsServiceCallServer.IsActualAgreement(EDParameters) Then
			Return;
		EndIf;
	EndIf;
	
	Source.AdditionalProperties.Insert("IsAgreement", True);
	
	CheckObjectModificationForEDExchange(Source);
	
EndProcedure

// "OnWrite" event handler of electronic document owners.
//
// Parameters:
//  Source - object - attached file
//  owner, Denial    - Boolean - shows that record has been canceled.
//
Procedure ElectronicDocumentsOwnerOnWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseEDExchange") Then
		Return;
	EndIf;
	
	If Not Source.AdditionalProperties.Property("IsAgreement")
		OR Not Source.AdditionalProperties.IsAgreement Then
		
		CheckExistanceAndDeleteDocumentState(Source.Ref);
		Return;
	EndIf;
	
	If Not Source.AdditionalProperties.Property("RegisterObject")
		OR Not Source.AdditionalProperties.RegisterObject Then
		
		Return;
	EndIf;
	
	If Not Source.AdditionalProperties.Property("IsNewObject") Then
		EditAllowed = True;
		ElectronicDocumentsOverridable.CheckObjectEditingPossibility(Source.Ref, EditAllowed);
		If Not EditAllowed Then
			MessageText = NStr("en='Relevant electronic document exists. Prohibited to edit the key attributes of the document.';ru='Существует актуальный электронный документ. Запрещено редактирование ключевых реквизитов документа.'");
			CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
			Return;
		EndIf;
	EndIf;
	
	ElectronicDocumentsServiceCallServer.SetEDNewVersion(Source.Ref);
	
EndProcedure

Procedure FillEDKindsForDSCertificateBeforeWriting(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	ObjectReference = Source.Ref;
	If ObjectReference.IsEmpty() Then
		ObjectReference = Source.GetNewObjectRef();
		If ObjectReference.IsEmpty() Then
			ObjectReference = CommonUse.ObjectManagerByRef(Source.Ref).GetRef();
			Source.SetNewObjectRef(ObjectReference);
		EndIf;
		InformationRegisters.DigitallySignedEDKinds.SaveSignedEDKinds(ObjectReference);
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Change electronic documents

// "BeforeWrite" event handler of electronic documents.
// 
// Parameters:
//  Source - object - electronic
//  document, Denial    - Boolean - shows that record has been canceled.
//
Procedure BeforeElectronicDocumentWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.DeletionMark Then
		ProcessElectronicDocumentDeletion(Source.Ref);
		Return;
	EndIf;
	
	If Not ValueIsFilled(Source.EDDirection)
		OR Not ValueIsFilled(Source.EDKind)
		OR Not ValueIsFilled(Source.FileOwner)
		OR TypeOf(Source.FileOwner) = Type("DocumentRef.RandomED") Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Source.Ref) Then
		Source.AdditionalProperties.Insert("WriteELEvent", False);
		Return;
	ElsIf Source.Ref.EDStatus = Source.EDStatus Then
		If Source.Ref.Responsible <> Source.Responsible OR Source.Ref.Definition <> Source.Definition Then
			Source.AdditionalProperties.Insert("WriteELEvent", True);
		Else
			Source.AdditionalProperties.Insert("WriteELEvent", False);
		EndIf;
		Return;
	EndIf;
	
	Source.AdditionalProperties.Insert("WriteELEvent", True);
	Source.AdditionalProperties.Insert("EDVersionState", DetermineVersionStateByEDStatus(Source.Ref));
	
EndProcedure

// "OnWrite" event handler of electronic documents.
// 
// Parameters:
//  Source - object - electronic
//  document, Denial    - Boolean - shows that record has been canceled.
//
Procedure OnWriteElectronicDocument(Source, Cancel) Export
	
	If Source.AdditionalProperties.Property("WriteELEvent")
		 AND Source.AdditionalProperties.WriteELEvent Then
		WriteEventLogMonitorByEDExchangeEvent(Source.Ref);
	EndIf;
	
	If Source.VersionPointTypeED = Enums.EDVersionElementTypes.SDC
	 OR Source.VersionPointTypeED = Enums.EDVersionElementTypes.RDC Then
		Return;
	EndIf;
	
	EDVersionState = Undefined;
	
	If Source.AdditionalProperties.Property("EDAgreement") Then
		EDVersionState = DetermineVersionStateByEDStatus(Source.Ref);
	EndIf;
	
	If Source.AdditionalProperties.Property("EDVersionState") Then
		
		NexEDVersionState = Source.AdditionalProperties.EDVersionState;
		EDCurVersionStructure  = GetEDVersionStructure(Source.FileOwner);
		If NexEDVersionState <> EDCurVersionStructure.EDVersionState Then
			ElectronicDocumentsServiceCallServer.RefreshEDVersion(Source.Ref)
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Object filling

// Receives the EDAttachedFiles catalog items selection by filter
//
// Parameters:
//  Parameters - Structure, Key - filter attribute name, Value - filter value
//
Function GetEDSelectionByFilter(Parameters) Export
	
	If Not TypeOf(Parameters) = Type("Structure") OR Parameters.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT 
	|	EDAttachedFiles.Description,
	|	EDAttachedFiles.Ref
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE 
	|";
	
	FirstItem = True;
	For Each Item IN Parameters Do
		Query.Text = Query.Text + ?(NOT FirstItem," AND ","") + " EDAttachedFiles." + Item.Key + "=&" + Item.Key;
		FirstItem = False;
		Query.SetParameter(Item.Key, Item.Value);
	EndDo;
	
	Return Query.Execute().Select();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Scheduled jobs

// Executes scheduled job
// on receiving new electronic documents.
//
// Parameters:
//  ErrorDescription - String, error description if it occurs while receiving documents.
//
Procedure NewEDScheduledReceiving() Export
	
	If IsBlankString(UserName()) Then
		SetPrivilegedMode(True);
	EndIf;
	
	Text = NStr("en='Scheduled job on receiving new electronicdocuments is started.';ru='Начато регламентное задание по получению новых эл.документов.'");
	WriteEventOnEDToEventLogMonitor(Text, 4, EventLogLevel.Information);
	
	BeginTransaction();
	Try
		CorrAgreements = Undefined;
		If ElectronicDocumentsServiceCallServer.ParametersAvailableForAuthorizationOnOperatorServer( , CorrAgreements) Then
			
			ElectronicDocumentsServiceCallServer.UpdateEDFSettingsConnectionStatuses(CorrAgreements);
			NewDocuments = GetNewED(CorrAgreements);
			PackagesCount = NewDocuments.ReturnArray.Count();
			For Each UnpackingStructure IN NewDocuments.UnpackingParameters Do
				EncryptionStructure = Undefined;
				UnpackingStructure.Property("EncryptionStructure", EncryptionStructure);
				If EncryptionStructure <> Undefined Then
					If EncryptionStructure.CertificateParameters.RememberCertificatePassword Then
						
						EncryptionStructure.Insert("UserPassword", EncryptionStructure.CertificateParameters.UserPassword);
					EndIf;
				EndIf;
				UnpackingData = Undefined;
				UnpackingStructure.Property("UnpackingData", UnpackingData);
				
				UnpackEDPackageOnServer(UnpackingStructure.EDPackage, EncryptionStructure, UnpackingData);
			EndDo;
			
			CommitTransaction();
			MessagePattern = NStr("en='Scheduled job is complete. Packs received: %1.';ru='Закончено регламентное задание. Получено пакетов: %1.'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, PackagesCount);
			WriteEventOnEDToEventLogMonitor(MessageText, 4, EventLogLevel.Information);
		EndIf;
	Except
		RollbackTransaction();
		
		MessagePattern = NStr("en='An error occurred while scheduled receiving new electronic documents.
		|Additional
		|description: %1';ru='Во время регламентного получения новых эл.документов произошла ошибка.
		|Дополнительное
		|описание: %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, ErrorInfo().Definition);
		WriteEventOnEDToEventLogMonitor(MessageText, 4, EventLogLevel.Error);
	EndTry;
	
EndProcedure

// Executes scheduled job on
// electronic documents actual sending.
//
Procedure CompletedEDScheduledSending() Export
	
	If IsBlankString(UserName()) Then
		SetPrivilegedMode(True);
	EndIf;
	
	Text = NStr("en='Scheduled job is started on sending formed electronicdocuments is started.';ru='Начато регламентное задание по отправке оформленных эл.документов.'");
	WriteEventOnEDToEventLogMonitor(Text, 4, EventLogLevel.Information);
	
	Try
		PackagesCount = SendingCompletedED();
		Text = NStr("en='Scheduled job is complete. Packs sent: %PacksQuantity%.';ru='Закончено регламентное задание. Отправлено пакетов: %КоличествоПакетов%.'");
		Text = StrReplace(Text, "%PackagesCount%", PackagesCount);
		WriteEventOnEDToEventLogMonitor(Text, 4, EventLogLevel.Information);
	Except
		ErrorDescription = NStr("en='An error occurred while scheduled sending of formed electronic documents.
		|Additional
		|description: %AdditionalDetails%';ru='Во время регламентной отправки оформленных эл.документов произошла ошибка.
		|Дополнительное
		|описание: %ДополнительноеОписание%'");
		ErrorDescription = StrReplace(ErrorDescription, "%AdditionalDetails%", ErrorInfo().Definition);
		
		WriteEventOnEDToEventLogMonitor(ErrorDescription, 4, EventLogLevel.Error);
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with ES

// For internal use only
Procedure SaveWithLatestES(AttachedFile,
										FileData,

										DirectoryAddress,
										AccordanceFileED) Export
	
	FullFileName = DirectoryAddress + StrReplace(FileData.FileName, "..",".");
	UUID = New UUID;
	SignsStructuresArray = GetAllSignatures(AttachedFile, UUID);
	
	File = New File(DirectoryAddress);
	If Not File.Exist() Then
		CreateDirectory(DirectoryAddress);
	EndIf;
	
	If TypeOf(SignsStructuresArray) = Type("Array") AND SignsStructuresArray.Count() > 0 Then
		NumberOfSignatures = SignsStructuresArray.Count();
		For Ct = 1 To NumberOfSignatures - 1 Do
			SignsStructuresArray.Delete(0);
		EndDo;
		SaveSignatures(
				AttachedFile,
				FullFileName,
				SignsStructuresArray,
				DirectoryAddress,
				AccordanceFileED,
				True);
	EndIf;
	
EndProcedure

// For internal use only
Procedure SaveWithDS(AttachedFile,
								FileData,
								DirectoryAddress,
								AccordanceFileED,
								IsArbitraryDocument = Undefined) Export
	
	// To confirm it, save only last signature to the files generation directory
	FullFileName = SaveFileAs(FileData, DirectoryAddress, AttachedFile, IsArbitraryDocument, AccordanceFileED);
	If FullFileName = "" Then
		Return;
	EndIf;
	
	UUID = New UUID;
	SignsStructuresArray = GetAllSignatures(AttachedFile, UUID);
	If TypeOf(SignsStructuresArray) = Type("Array") AND SignsStructuresArray.Count() > 0 Then
		SaveSignatures(AttachedFile, FullFileName, SignsStructuresArray, DirectoryAddress,
			AccordanceFileED, , IsArbitraryDocument);
	EndIf;
	
EndProcedure

// Checks whether signature is valid not considering revoked certificates list.
// If an error occurs, generates exception
//
// Parameters
//  CryptographyManager  - CryptoManager - FileBinaryData
//  cryptography manager   - SignatureBinaryData
//  file binary data - signature binary data
//
Procedure VerifySignature(CryptoManager, FileBinaryData, BinaryDataSignatures) Export
	
	CryptoManager.VerifySignature(FileBinaryData, BinaryDataSignatures);
	
EndProcedure

// For internal use only
Function IsSuchSignature(VerificationBinaryData, ElectronicDocument) Export
	
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(ElectronicDocument) Then
		
		Return False;
	EndIf;
	
	For Each DocumentSignature IN ElectronicDocument.DigitalSignatures Do
		BinaryDataSignatures = DocumentSignature.Signature.Get();
		If BinaryDataSignatures = VerificationBinaryData Then
			
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function UseCryptoTools() Export
	
	Cancel = False;
	ElectronicDocumentsServiceCallServer.GetCryptoManager(Cancel);
	Return Not Cancel;
	
EndFunction

// Called from the form Custom ED and 
//
Function ExpectedCertificateThumbprints(ElectronicDocument) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDAttachedFiles.Ref,
	|	EDAttachedFiles.EDKind,
	|	EDAttachedFiles.EDAgreement,
	|	EDAttachedFiles.EDFProfileSettings
	|INTO TU_ED
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ESCertificates.Imprint AS Imprint
	|FROM
	|	TU_ED AS TU_ED
	|		LEFT JOIN InformationRegister.DigitallySignedEDKinds AS DigitallySignedEDKinds
	|			INNER JOIN Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS ESCertificates
	|				INNER JOIN (SELECT DISTINCT
	|					EDFProfilesCertificates.Certificate AS Certificate
	|				FROM
	|					TU_ED AS TU_ED
	|						LEFT JOIN Catalog.EDFProfileSettings.CompanySignatureCertificates AS EDFProfilesCertificates
	|						ON TU_ED.EDFProfileSettings = EDFProfilesCertificates.Ref
	|				
	|				UNION ALL
	|				
	|				SELECT
	|					AgreementsEDCertificates.Certificate
	|				FROM
	|					TU_ED AS TU_ED
	|						LEFT JOIN Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsEDCertificates
	|						ON TU_ED.EDAgreement = AgreementsEDCertificates.Ref) AS CertificatesFromSettingsAndProfiles
	|				ON ESCertificates.Ref = CertificatesFromSettingsAndProfiles.Certificate
	|			ON DigitallySignedEDKinds.DSCertificate = ESCertificates.Ref
	|		ON TU_ED.EDKind = DigitallySignedEDKinds.EDKind
	|WHERE
	|	Not ESCertificates.Revoked
	|	AND Not ESCertificates.DeletionMark
	|	AND DigitallySignedEDKinds.Use
	|
	|UNION ALL
	|
	|SELECT
	|	AgreementsEDCounterpartyCertificates.Imprint
	|FROM
	|	TU_ED AS TU_ED
	|		LEFT JOIN Catalog.EDUsageAgreements.CounterpartySignaturesCertificates AS AgreementsEDCounterpartyCertificates
	|		ON AgreementsEDCounterpartyCertificates.Ref = TU_ED.EDAgreement";
	Query.SetParameter("Ref", ElectronicDocument);
	
	ThumbprintArray = Query.Execute().Unload().UnloadColumn("Imprint");
	
	Return ThumbprintArray;
	
EndFunction

// Electronic documents certificates

// Function returns certificates array intersection set to
// the personal storage with array of certificates registered in 1c (operating and available to the current user).
// If EDAgreement optional parameter is passed, array of certificates registered in
// 1c is additionally limited by a condition of entering the list of certificates registered according to this agreement, certificates.
//
// Parameters:
//  CertificateStructuresArray - array - array of certificate structures set to the
//    storage on Client/Server (depending on settings of work with cryptography).
//  EDFProfileSettings - catalog-ref - ref to EDF settings profile,
//    its list of certificates is required.
//
// Returns - values table.
//
Function AvailableForSigningCertificatesTable(ThumbprintArray, EDFSetup = Undefined) Export
	
	ReturnValue = New ValueTable;
	If TypeOf(ThumbprintArray) = Type("Array") Then
		QueryByCertificates = New Query;
		If TypeOf(EDFSetup) = Type("CatalogRef.EDUsageAgreements") Then
			QueryText =
			"SELECT ALLOWED DISTINCT
			|	Certificates.Ref,
			|	UNDEFINED AS UserPassword,
			|	FALSE AS RememberCertificatePassword,
			|	FALSE AS PasswordReceived,
			|	Certificates.Imprint
			|FROM
			|	Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsEDCertificates
			|		LEFT JOIN Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
			|			INNER JOIN InformationRegister.DigitallySignedEDKinds AS EDEPKinds
			|			ON Certificates.Ref = EDEPKinds.DSCertificate
			|		ON AgreementsEDCertificates.Certificate = Certificates.Ref
			|		INNER JOIN Catalog.EDUsageAgreements AS EDUsageAgreements
			|		ON AgreementsEDCertificates.Ref = EDUsageAgreements.Ref
			|WHERE
			|	EDUsageAgreements.Ref = &EDFSetup
			|	AND (Certificates.Imprint IN (&ThumbprintArray)
			|			OR EDUsageAgreements.BankApplication = VALUE(Enum.BankApplications.SberbankOnline))";
			QueryByCertificates.SetParameter("EDFSetup", EDFSetup);
		ElsIf TypeOf(EDFSetup) = Type("CatalogRef.EDFProfileSettings") Then
			QueryText =
			"SELECT ALLOWED DISTINCT
			|	Certificates.Ref,
			|	UNDEFINED AS UserPassword,
			|	FALSE AS RememberCertificatePassword,
			|	FALSE AS PasswordReceived,
			|	Certificates.Imprint
			|FROM
			|	Catalog.EDFProfileSettings.CompanySignatureCertificates AS EDFProfileSettingsCertificates
			|		LEFT JOIN Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
			|			INNER JOIN InformationRegister.DigitallySignedEDKinds AS EDEPKinds
			|			ON Certificates.Ref = EDEPKinds.DSCertificate
			|		ON EDFProfileSettingsCertificates.Certificate = Certificates.Ref
			|WHERE
			|	EDFProfileSettingsCertificates.Ref = &EDFSetup
			|	AND Certificates.Imprint IN (&ThumbprintArray)";
			QueryByCertificates.SetParameter("EDFSetup", EDFSetup);
		Else
			QueryText =
			"SELECT ALLOWED DISTINCT
			|	Certificates.Ref,
			|	UNDEFINED AS UserPassword,
			|	FALSE AS RememberCertificatePassword,
			|	FALSE AS PasswordReceived,
			|	Certificates.Imprint
			|FROM
			|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
			|WHERE
			|	Not Certificates.Revoked
			|	AND Not Certificates.DeletionMark
			|	AND Certificates.Imprint IN (&ThumbprintArray)";
		EndIf;
		QueryText = QueryText + "
			|	And (Certificates.User
			|			= &CurrentUser OR Certificates.User = &EmptyUser)";
		
		QueryByCertificates.Text = QueryText;
			
		QueryByCertificates.SetParameter("CurrentUser", Users.AuthorizedUser());
		QueryByCertificates.SetParameter("EmptyUser",  Catalogs.Users.EmptyRef());
		QueryByCertificates.SetParameter("ThumbprintArray",    ThumbprintArray);
		ReturnValue = QueryByCertificates.Execute().Unload();
	EndIf;
	
	Return ReturnValue;
	
EndFunction

// Function returns certificates array intersection set to
// the personal storage with array of certificates registered in 1c (operating and available to the current user).
// If EDAgreement optional parameter is passed, array of certificates registered in
// 1c is additionally limited by a condition of entering the list of certificates registered according to this agreement, certificates.
//
// Parameters:
//  CertificateTumbprintsArray - array - array of certificates thumbprints set to the
//    storage on Client/Server (depending on the work with cryptography settings).
//  EDAgreement - catalog-ref - ref to the agreement on ED exchange via EDF operator
//    list of certificates of which is required.
//
// Returns - array of certificates structures.
//
Function ArrayOfStructuresAvailableForSigningCertificates(CertificateTumbprintsArray, EDFSetup = Undefined) Export
	
	AvailableCertificatesStructuresArray = New Array;
	
	AvailableCertificatesTable = AvailableForSigningCertificatesTable(CertificateTumbprintsArray, EDFSetup);
	For Each CurItm IN CertificateTumbprintsArray Do
		TableRow = AvailableCertificatesTable.Find(CurItm, "Imprint");
		If TableRow = Undefined Then
			Continue;
		EndIf;
		CertificateStructure = New Structure;
		CertificateStructure.Insert("Imprint",                   CurItm);
		CertificateStructure.Insert("Certificate",                  TableRow.Ref);
		CertificateStructure.Insert("PasswordReceived",               TableRow.PasswordReceived);
		CertificateStructure.Insert("UserPassword",          TableRow.UserPassword);
		CertificateStructure.Insert("RememberCertificatePassword", TableRow.RememberCertificatePassword);
		CertificateStructure.Insert("Comment",                 "");
		
		AvailableCertificatesStructuresArray.Add(CertificateStructure);
	EndDo;
	
	Return AvailableCertificatesStructuresArray;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with the electronic document versions

// For internal use only
Function DetermineElectronicDocument(SearchParametersStructure) Export
	
	Query = New Query;
	Text =
	"SELECT TOP 1
	|	EDAttachedFiles.Ref
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.DeletionMark = FALSE";
	
	Pattern = "
		|And EDAttachedFiles.%1 = &%1";
	For Each Item IN SearchParametersStructure Do
		If ValueIsFilled(Item.Value) Then
			Text = Text + StrReplace(Pattern, "%1", Item.Key);
			Query.SetParameter(Item.Key, Item.Value);
		EndIf;
	EndDo;
	
	Query.Text = Text;
	
	SetPrivilegedMode(True);
	Result = Query.Execute().Select();
	
	ReturnedParameter = Undefined;
	If Result.Next() Then
		ReturnedParameter = Result.Ref;
	EndIf;
	
	Return ReturnedParameter;
	
EndFunction

// Receives number of the electronic document current version for owner.
// 
// Parameters:
//  RefToOwner - Ref to IB object electronic document version number of which should be received.
//
Function EDVersionNumberByOwner(RefToOwner) Export
	
	EDVersionStructure = GetEDVersionStructure(RefToOwner);
	If ValueIsFilled(EDVersionStructure.EDVersionNumber) Then
		Return EDVersionStructure.EDVersionNumber;
	EndIf;

	Return GetEDLastVersionByOwner(RefToOwner) + 1;
	
EndFunction

// For internal use only
Function GetEDVersionStructure(RefToOwner) Export
	
	SetPrivilegedMode(True);
	
	EDVersionStructure = New Structure;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ISNULL(EDStates.ElectronicDocument.EDVersionNumber, 0) AS EDVersionNumber,
	|	ISNULL(EDStates.ElectronicDocument, VALUE(Catalog.EDAttachedFiles.EmptyRef)) AS ElectronicDocument,
	|	EDStates.EDVersionState,
	|	EDStates.ElectronicDocument.EDStatus AS EDStatus,
	|	EDStates.Comment
	|FROM
	|	InformationRegister.EDStates AS EDStates
	|WHERE
	|	EDStates.ObjectReference = &ObjectReference
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(EDAttachedFiles.EDVersionNumber) AS EDVersionNumber
	|INTO MaxVersion
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.FileOwner = &ObjectReference
	|	AND Not EDAttachedFiles.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EDAttachedFiles.Ref,
	|	EDAttachedFiles.EDVersionNumber,
	|	EDAttachedFiles.EDStatus
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.FileOwner = &ObjectReference
	|	AND EDAttachedFiles.EDVersionNumber In
	|			(SELECT
	|				MaxVersion.EDVersionNumber
	|			FROM
	|				MaxVersion)
	|	AND Not EDAttachedFiles.DeletionMark";
	Query.SetParameter("ObjectReference", RefToOwner);
	
	Result = Query.ExecuteBatch();
	CommentIR = "";
	SelectionOnRegister = Result[0].Select();
	If SelectionOnRegister.Next() Then
		EDVersionNumber     = SelectionOnRegister.EDVersionNumber;
		EDVersionState = SelectionOnRegister.EDVersionState;
		DocumentRef  = SelectionOnRegister.ElectronicDocument;
		EDStatus          = SelectionOnRegister.EDStatus;
		CommentIR     = SelectionOnRegister.Comment;
	Else
		EDVersionNumber     = 0;
		EDVersionState = Enums.EDVersionsStates.EmptyRef();
		DocumentRef  = Catalogs.EDAttachedFiles.EmptyRef();
		EDStatus          = Enums.EDStatuses.EmptyRef();
	EndIf;
	
	If EDVersionNumber = 0 Then
		SelectionOfRepertoire = Result[2].Select();
		If SelectionOfRepertoire.Count() > 0 Then
			SelectionOfRepertoire.Next();
			EDVersionNumber    = SelectionOfRepertoire.EDVersionNumber;
			DocumentRef = SelectionOfRepertoire.Ref;
			EDStatus         = SelectionOfRepertoire.EDStatus;
		EndIf;
	EndIf;
	EDVersionStructure.Insert("EDVersionNumber",     EDVersionNumber);
	EDVersionStructure.Insert("DocumentRef",  DocumentRef);
	EDVersionStructure.Insert("EDVersionState", EDVersionState);
	EDVersionStructure.Insert("EDStatus",          EDStatus);
	EDVersionStructure.Insert("CommentIR",     CommentIR);
	
	Return EDVersionStructure;
	
EndFunction

// For internal use only
Function GetFirstEDVersionStateForOwner(RefToOwner, ReceivingSign = False) Export
	
	EDParameters = FillEDParametersBySource(RefToOwner.Ref);
	
	EDVersionState = Enums.EDVersionsStates.EmptyRef();
	EDDirection = "";
	If EDParameters.Property("EDDirection", EDDirection) AND ValueIsFilled(EDDirection) Then
		If EDDirection = Enums.EDDirections.Outgoing 
			OR EDDirection = Enums.EDDirections.Intercompany Then
			
			EDVersionState = Enums.EDVersionsStates.NotFormed;
		ElsIf EDDirection = Enums.EDDirections.Incoming Then
			If ReceivingSign Then 
				EDVersionState = Enums.EDVersionsStates.OnApproval;
			Else
				EDVersionState = Enums.EDVersionsStates.NotReceived;
			EndIf;
		EndIf;
	EndIf;
	
	Return EDVersionState;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Exchange via FTP

// For internal use only
Function GetFTPConnection(EDFProfileSettings, IsTest = False) Export
	
	If IsTest Then
		MessagePattern = NStr("en='Test. Check whether FTP connection is set.
		|%1';ru='Тест. Проверка установки FTP соединения.
		|%1'");
	Else
		MessagePattern = "%1";
	EndIf;
		
	UseProxy = False;
	
	ProxyServerSetting = GetFilesFromInternet.ProxySettingsOnServer();
	If ProxyServerSetting <> Undefined Then
		ParameterUseProxy = ProxyServerSetting.Get("UseProxy");
		If Not ParameterUseProxy=Undefined Then
			UseProxy = ParameterUseProxy;
		EndIf;
	EndIf;
	
	If UseProxy Then
		If ProxyServerSetting.Get("UseSystemSettings") Then
			// System proxy settings.
			Proxy = New InternetProxy(True);
		Else
			// Manual proxy settings.
			Proxy = New InternetProxy;
			Proxy.Set("ftp", ProxyServerSetting["Server"], ProxyServerSetting["Port"]);
			Proxy.BypassProxyOnLocal = ProxyServerSetting["BypassProxyOnLocal"];
			Proxy.User = ProxyServerSetting["User"];
			Proxy.Password = ProxyServerSetting["Password"];
		EndIf;
	Else
		Proxy = New InternetProxy(False);
	EndIf;
	
	EDFProfileSettingsParameters = CommonUse.ObjectAttributesValues(EDFProfileSettings,
		"ServerAddress, Login, Password, Port, PassiveConnection");
	
	Try
		FTPConnection = New FTPConnection(EDFProfileSettingsParameters.ServerAddress,
											EDFProfileSettingsParameters.Port,
											EDFProfileSettingsParameters.Login,
											EDFProfileSettingsParameters.Password,
											Proxy,
											EDFProfileSettingsParameters.PassiveConnection);
	Except
		ResultTemplate = NStr("en='%1 %2';ru='%1 %2'");
		ErrorText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("121");
		TestResult = StringFunctionsClientServer.PlaceParametersIntoString(ResultTemplate, ErrorText,
			BriefErrorDescription(ErrorInfo()));
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, TestResult);
		CommonUseClientServer.MessageToUser(MessageText);
		Return Undefined;
	EndTry;
	
	If IsTest Then
		TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, TestResult);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return FTPConnection;
	
EndFunction

// For internal use only
Procedure PrepareFTPPath(Path) Export
	Path = StrReplace(Path, "\", "/");
	If ValueIsFilled(Path) Then
		If Not Left(Path, 1) = "/" Then
			Path = "/" + Path;
		EndIf;
		If Not Right(Path, 1) = "/" Then
			Path = Path + "/";
		EndIf;
	EndIf;
EndProcedure

// Procedure is used to test exchange settings via FTP
//
// Parameters:
//  EDFProfileSettings - CatalogRef.Agreement - tested agreement;
//  IncomingDocumentsDir - String - path to the incoming documents exchange directory;
//  OutgoingDocumentsDir - String - path to the outgoing documents exchange directory.
//
Procedure TestLinksExchangeThroughFTP(EDFProfileSettings, IncomingDocumentsDir, OutgoingDocumentsDir) Export
	
	FTPConnection = GetFTPConnection(EDFProfileSettings, True);
	
	If FTPConnection = Undefined Then
		Return;
	EndIf;
	
	MessagePattern = NStr("en='Check the outgoing documents directory.
		|%1';ru='Проверка каталога исходящих документов.
		|%1'");
	
	ErrorText = "";
	Try
		PrepareFTPPath(OutgoingDocumentsDir);
		FTPConnection.SetCurrentDirectory(OutgoingDocumentsDir);
	Except
		CreateFTPDirectories(FTPConnection, OutgoingDocumentsDir, True, ErrorText);
	EndTry;
	
	If ValueIsFilled(ErrorText) Then
		TestResult = ErrorText;
	Else
		TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
	EndIf;
	
	MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, TestResult);
	MessageText = NStr("en='Exchange text by %1 profile.';ru='Тест обмена по профилю %1.'") + " " + MessageText;
	MessageText = StrReplace(MessageText, "%1", EDFProfileSettings);
	CommonUseClientServer.MessageToUser(MessageText);
	
	If Not ValueIsFilled(ErrorText) Then
		MessagePattern = NStr("en='Check files writing and reading in the outgoing documents directory.
		|%1';ru='Проверка записи и чтения файлов в каталоге исходящих документов.
		|%1'");
		CheckFile(MessagePattern, FTPConnection, ErrorText);
		If ValueIsFilled(ErrorText) Then
			TestResult = ErrorText;
		Else
			TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
		EndIf;
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, TestResult);
		MessageText = NStr("en='Exchange text by %1 profile.';ru='Тест обмена по профилю %1.'") + " " + MessageText;
		MessageText = StrReplace(MessageText, "%1", EDFProfileSettings);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	ErrorText = "";
	
	MessagePattern = NStr("en='Check the incoming documents directory.
		|%1';ru='Проверка каталога входящих документов.
		|%1'");
	Try
		PrepareFTPPath(IncomingDocumentsDir);
		FTPConnection.SetCurrentDirectory(IncomingDocumentsDir);
	Except
		CreateFTPDirectories(FTPConnection, IncomingDocumentsDir, True, ErrorText);
	EndTry;
		
	If ValueIsFilled(ErrorText) Then
		TestResult = ErrorText;
	Else
		TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
	EndIf;
	
	MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, TestResult);
	MessageText = NStr("en='Exchange text by %1 profile.';ru='Тест обмена по профилю %1.'") + " " + MessageText;
	MessageText = StrReplace(MessageText, "%1", EDFProfileSettings);
	CommonUseClientServer.MessageToUser(MessageText);
	
	If Not ValueIsFilled(ErrorText) Then
		MessagePattern = NStr("en='Check files writing and reading in the incoming documents directory.
		|%1';ru='Проверка записи и чтения файлов в каталоге входящих документов.
		|%1'");
		CheckFile(MessagePattern, FTPConnection, ErrorText);
		If ValueIsFilled(ErrorText) Then
			TestResult = ErrorText;
		Else
			TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
		EndIf;
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, TestResult);
		MessageText = NStr("en='Exchange text by %1 profile.';ru='Тест обмена по профилю %1.'") + " " + MessageText;
		MessageText = StrReplace(MessageText, "%1", EDFProfileSettings);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// For internal use only
Procedure CreateFTPDirectories(FTPConnection, FullPath, IsTest = False, ErrorText = Undefined) Export
	
	FullPath = StrReplace(FullPath, "\", "/");
	DirectoriesArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FullPath, "/", True);
	CurrentPath = "/";
	FTPConnection.SetCurrentDirectory(CurrentPath);
	For Each Item IN DirectoriesArray Do
		
		mDirectory = New Array;
		
		FindFilesInFTPDirectory(FTPConnection, Item, Undefined, True, ErrorText, mDirectory);
		
		If ValueIsFilled(ErrorText) Then
			Return;
		EndIf;
		
		If mDirectory.Count() = 1 Then 
			If mDirectory[0].IsFile() Then 
				ErrorText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("122");
				If Not IsTest Then
					CommonUseClientServer.MessageToUser(ErrorText);
				EndIf;
				Return;
			EndIf;
			CreateDirectory = False;
		Else
			CreateDirectory = True;
		EndIf;

		If CreateDirectory Then
			Try
				FTPConnection.CreateDirectory(Item);
			Except
				ErrorText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("123");
				If Not IsTest Then
					CommonUseClientServer.MessageToUser(ErrorText);
				EndIf;
				Return;
			EndTry
		EndIf;
		
		CurrentPath = CurrentPath + Item + "/";
		
		Try
			FTPConnection.SetCurrentDirectory(CurrentPath);
		Except
			ErrorText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("124");
			If Not IsTest Then
				CommonUseClientServer.MessageToUser(ErrorText);
			EndIf;
		EndTry
		
	EndDo;
	
EndProcedure

// For internal use only
Procedure WriteFileOnFTP(FTPConnection,
							Source,
							OutgoingFileName,
							IsTest = False,
							TestResult = Undefined) Export
	
	Try
		FTPConnection.Write(Source, OutgoingFileName);
	Except
		TestResult = ElectronicDocumentsServiceCallServer.GetMessageAboutError("127");
		
		If Not IsTest Then
			CommonUseClientServer.MessageToUser(TestResult);
		EndIf;
	EndTry;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Electronic document packs processor

// Creates electronic documents pack.
// 
// Parameters:
//  EDKindsArray - Array of references to electronic documents that should be included in the pack.
//  SignatureSign - Boolean, shows that documents are signed with DS.
//
Function CreateEDPackageDocuments(EDKindsArray, SignatureSign) Export
	
	SetPrivilegedMode(True);
	
	VT_EDP = New ValueTable;
	VT_EDP.Columns.Add("EDP");
	VT_EDP.Columns.Add("EDExchangeMethod");
	VT_EDP.Columns.Add("ReceiverResourceAddress");
	VT_EDP.Columns.Add("RequiredEncryptionAtClient");
	VT_EDP.Columns.Add("PackageFormatVersion");
	VT_EDP.Columns.Add("BankApplication");
	
	PreparedForSendingEDArray = New Array;
	
	For Each ED IN EDKindsArray Do
		EDAttributes = CommonUse.ObjectAttributesValues(ED, "EDStatus, EDAgreement, EDDirection, EDFrom, EDRecipient, FileOwner");
		EDFSettingAttributes = CommonUse.ObjectAttributesValues(EDAttributes.EDAgreement, "EDExchangeMethod, BankApplication");
		
		DocumentNumbertDigitallySigned = EDAttributes.EDStatus = Enums.EDStatuses.Created
						 OR EDAttributes.EDStatus = Enums.EDStatuses.Approved
						 OR EDAttributes.EDStatus = Enums.EDStatuses.PartlyDigitallySigned;
		If (SignatureSign AND DocumentNumbertDigitallySigned)
				OR Not SetSignaturesValid(ED)
				OR (EDFSettingAttributes.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource
					AND EDFSettingAttributes.BankApplication = Enums.BankApplications.SberbankOnline) Then
			Continue;
		EndIf;
		
		If EDFSettingAttributes.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource
			AND (EDFSettingAttributes.BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
				OR EDFSettingAttributes.BankApplication = Enums.BankApplications.iBank2) Then
			ServiceBankED = ServiceBankED(ED);
			If Not ValueIsFilled(ServiceBankED) Then
				MessagePattern = NStr("en='%1 (for more information, see Events log monitor)';ru='%1 (подробности см. в Журнале регистрации)'");
				MessageText = NStr("en='Unable to generate bank pack';ru='Невозможно сформировать пакет банка'");
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, MessageText);
				OperationKind = NStr("en='generate ED pack';ru='формирование пакета ЭД'");
				ErrorText = NStr("en='Additional data for electronic document is not found';ru='Не найдены дополнительные данные для электронного документа'");
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(OperationKind,
					ErrorText, MessageText, 1);
				Continue;
			EndIf;
		EndIf;
		
		// Receive agreement settings for banks by owner.
		If EDFSettingAttributes.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource Then
			EDFSettingParameters = DetermineEDExchangeSettingsBySource(EDAttributes.FileOwner, , , ED);
			If ValueIsFilled(EDFSettingParameters) Then
				EDFSettingParameters.Insert("EDExchangeMethod", EDFSettingAttributes.EDExchangeMethod);
			EndIf;
		Else
			// Search for EDF setting for ED outgoing pack.
			If EDAttributes.EDDirection = Enums.EDDirections.Incoming Then
				EDFSettingParameters = GetEDExchangeSettingsByID(EDAttributes.EDRecipient, EDAttributes.EDFrom);
			ElsIf EDAttributes.EDDirection = Enums.EDDirections.Outgoing Then
				EDFSettingParameters = GetEDExchangeSettingsByID(EDAttributes.EDFrom, EDAttributes.EDRecipient);
			EndIf;
		EndIf;
			
		If Not ValueIsFilled(EDFSettingParameters) Then
			Continue;
		EndIf;
		
		TabularSectionED = New Array;
		TabularSectionED.Add(ED);
		
		If ValueIsFilled(ServiceBankED) Then
			TabularSectionED.Add(ServiceBankED);
		EndIf;

		EDP = CreateEDPack(EDFSettingParameters, TabularSectionED);
			
		If ValueIsFilled(EDP) Then
			NewRow = VT_EDP.Add();
			NewRow.EDP = EDP;
			If EDFSettingParameters.Property("RecipientAddress") Then
				NewRow.ReceiverResourceAddress = EDFSettingParameters.RecipientAddress;
			EndIf;
			NewRow.RequiredEncryptionAtClient = EDFSettingParameters.Property("RequiredEncryptionAtClient")
														AND EDFSettingParameters.RequiredEncryptionAtClient;
			NewRow.PackageFormatVersion = EDFSettingParameters.PackageFormatVersion;
			NewRow.EDExchangeMethod = EDFSettingParameters.EDExchangeMethod;
			If EDFSettingParameters.Property("BankApplication") Then
				NewRow.BankApplication = EDFSettingParameters.BankApplication;
			EndIf;
			PreparedForSendingEDArray.Add(ED);
		EndIf;

	EndDo;
	
	// Generate structures array for processing on client
	StructuresArrayPED = New Array;
	For Each CurRow IN VT_EDP Do
		StructurePED = New Structure;
		StructurePED.Insert("EDP",                    CurRow.EDP);
		StructurePED.Insert("ReceiverResourceAddress", CurRow.ReceiverResourceAddress);
		StructurePED.Insert("RequiredEncryptionAtClient", False);
		If CurRow.RequiredEncryptionAtClient = True Then
			StructurePED.RequiredEncryptionAtClient = True;
			StructuresArrayPED.Add(StructurePED);
			Continue;
		EndIf;
		
		If CurRow.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
			OR (CurRow.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEMail
				OR CurRow.EDExchangeMethod = Enums.EDExchangeMethods.ThroughDirectory
				OR CurRow.EDExchangeMethod = Enums.EDExchangeMethods.ThroughFTP
				AND CurRow.PackageFormatVersion <> Enums.EDPackageFormatVersions.Version10) Then
			
			If ElectronicDocumentsInternal.GenerateEDAttachedFileEDFOperatorPackage(CurRow.EDP) Then
				StructuresArrayPED.Add(StructurePED);
			Else
				For Each ED IN CurRow.EDP.ElectronicDocuments Do
					EDinArray = PreparedForSendingEDArray.Find(ED.ElectronicDocument);
					If EDinArray <> Undefined Then
						PreparedForSendingEDArray.Delete(EDinArray);
					EndIf;
				EndDo;
				EDP = CurRow.EDP.GetObject();
				EDP.PackageStatus    = Enums.EDPackagesStatuses.Canceled;
				EDP.DeletionMark = True;
				EDP.Write();
			EndIf;
		ElsIf CurRow.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource Then
			If CurRow.BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor Then
				StructurePED.Insert("SendingFromClient");
			ElsIf CurRow.BankApplication = Enums.BankApplications.AlphaBankOnline Then
				CreateEDPackCMSDETACHED(CurRow.EDP)
			Else
				CreateEDPackAsync(CurRow.EDP)
			EndIf;
			StructuresArrayPED.Add(StructurePED);
		Else
			GenerateEDAttachedPackageFile(CurRow.EDP);
			StructuresArrayPED.Add(StructurePED);
		EndIf;
	EndDo;
	UpdateEDStatuses(PreparedForSendingEDArray, SignatureSign);
	
	Return StructuresArrayPED;
	
EndFunction


// For internal use only
Function GenerateNewEDPackage(ParametersStructure) Export
	
	SetPrivilegedMode(True);
	
	Try
		EDPackage                         = Documents.EDPackage.CreateDocument();
		EDPackage.Date                    = CurrentSessionDate();
		EDPackage.PackageStatus            = ParametersStructure.PackageStatus;
		
		EDPackage.Direction             = ParametersStructure.EDDirections;
		
		EDPackage.Counterparty              = ParametersStructure.Counterparty;
		EDPackage.Company             = ParametersStructure.Company;
		
		EDPackage.Sender             = ParametersStructure.Sender;
		EDPackage.Recipient              = ParametersStructure.Recipient;
		
		If ParametersStructure.Property("EDFProfileSettings") Then
			EDPackage.EDFProfileSettings      = ParametersStructure.EDFProfileSettings;
		EndIf;
		
		EDPackage.EDFSetup            = ParametersStructure.EDFSetup;
		EDPackage.EDExchangeMethod          = ParametersStructure.EDExchangeMethod;
		
		EDPackage.PackageFormatVersion     = ParametersStructure.PackageFormatVersion;
		
		EDPackage.DataEncrypted       = ParametersStructure.Encrypted;
		If ParametersStructure.CompanyCertificateForDetails <> Undefined Then
			EDPackage.EncryptionCertificate = ParametersStructure.CompanyCertificateForDetails;
		EndIf;
		
		EDPackage.CounterpartyResourceAddress = ParametersStructure.SenderAddress;
		EDPackage.CompanyResourceAddress = ParametersStructure.RecipientAddress;
		
		If ParametersStructure.Property("ExternalUID") Then
			EDPackage.ExternalUID          = ParametersStructure.ExternalUID;
		EndIf;
		EDPackage.Write();
	Except
		MessagePattern = NStr("en='%1 (see details in event log monitor).';ru='%1 (подробности см. в Журнале регистрации).'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
			BriefErrorDescription(ErrorInfo()));
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='New EDPackage creation';ru='создание нового ПакетаЭД'"),
																					DetailErrorDescription(ErrorInfo()),
																					MessageText);
	EndTry;
	
	Return EDPackage.Ref;
	
EndFunction

// For internal use only
Procedure PlaceEDPackageIntoEnvelop(Envelop, ZipContainerAddress) Export
	
	// As there can be multiple documents in one pack now, you should check
	// whether there are files already attached to the pack. If any, - do not do anything.
	
	SetPrivilegedMode(True);
	
	Selection = GetEDSelectionByFilter(New Structure("FileOwner", Envelop));
	
	If ValueIsFilled(Selection) AND Selection.Count() > 0 Then
		Return;
	EndIf;
	
	File = New File(ZipContainerAddress);
	FileBinaryData = New BinaryData(ZipContainerAddress);
	AddressInTemporaryStorage = PutToTempStorage(FileBinaryData);
	AddedFile = AttachedFiles.AddFile(
												Envelop,
												File.BaseName,
												StrReplace(File.Extension,".", ""),
												CurrentSessionDate(),
												CurrentSessionDate(),
												AddressInTemporaryStorage,
												Undefined,
												,
												Catalogs.EDAttachedFiles.GetRef());
	
EndProcedure

// For internal use only
Procedure UpdateEDPackageDocumentsStatuses(EDPackage, EDPackageNewStatus, ChangeDate) Export
	
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(EDPackage) Then
		Return;
	EndIf;
	
	If EDPackage.ElectronicDocuments.Count() = 0 Then
		
		ErrorTemplate = NStr("en='%1 document can not be sent. For more information, see Events log monitor';ru='Документ %1 не был отправлен. Подробнее см. Журнал регистрации'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorTemplate,
					EDPackage );
		ErrorTemplate = NStr("en='%1 document is filled in incorrectly.
		|""ElectronicDocuments"" tabular section is not filled in';ru='Не корректно заполнен документ %1.
		|Не заполнена табличная часть ""ЭлектронныеДокументы""'");
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorTemplate,
					EDPackage );
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
			NStr("en='Send ED pack and update ED statuses';ru='Отправка пакета ЭД и обновление статусов ЭД'"),
			ErrorText,
			MessageText);
		
		Return;
	EndIf;
	
	Try
		
		BeginTransaction();
		
		For Each Document IN EDPackage.ElectronicDocuments Do
			If EDPackageNewStatus = Enums.EDPackagesStatuses.Delivered Then
				WriteDateReceived(Document.ElectronicDocument, ChangeDate);
			ElsIf EDPackageNewStatus = Enums.EDPackagesStatuses.Sent Then
				WriteSendingDate(Document.ElectronicDocument, ChangeDate);
			EndIf;
			ElectronicDocumentsServiceCallServer.RefreshEDVersion(Document.ElectronicDocument);
		EndDo;
		If TypeOf(Document.OwnerObject)=Type("DocumentRef.RandomED")
			AND (EDPackageNewStatus = Enums.EDPackagesStatuses.Sent
			OR EDPackageNewStatus = Enums.EDPackagesStatuses.Delivered) Then
			
			Object = Document.OwnerObject.GetObject();
			If EDPackageNewStatus = Enums.EDPackagesStatuses.Sent Then
				If Object.Direction = Enums.EDDirections.Outgoing Then
					Object.DocumentStatus = GetAdmissibleEDStatus(Enums.EDStatuses.Sent, Document.OwnerObject);
				ElsIf Object.Direction = Enums.EDDirections.Incoming
					AND Document.ElectronicDocument.EDKind <> Enums.EDKinds.NotificationAboutReception Then
					Object.DocumentStatus = GetAdmissibleEDStatus(Enums.EDStatuses.ConfirmationSent, Document.OwnerObject);
				EndIf;
			ElsIf EDPackageNewStatus = Enums.EDPackagesStatuses.Delivered Then
				If Object.Direction = Enums.EDDirections.Outgoing Then
					Object.DocumentStatus = GetAdmissibleEDStatus(Enums.EDStatuses.Delivered, Document.OwnerObject);
				ElsIf Object.Direction = Enums.EDDirections.Incoming Then
					Object.DocumentStatus = GetAdmissibleEDStatus(Enums.EDStatuses.ConfirmationDelivered, Document.OwnerObject);
				EndIf;
			EndIf;
			Object.Write();
		EndIf;
		
		PackageObject = EDPackage.GetObject();
		PackageObject.PackageStatus = EDPackageNewStatus;
		PackageObject.Write();
		
		CommitTransaction();
	Except
		
		RollbackTransaction();
		
		MessageText = BriefErrorDescription(ErrorInfo())
			+ NStr("en=' (see details in Event log monitor).';ru=' (подробности см. в Журнале регистрации).'");
		ErrorText = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
			NStr("en='ED package status modification and ED statuses update';ru='смена статуса пакета ЭД и обновление статусов ЭД'"), ErrorText, MessageText);
	EndTry;
	
EndProcedure

// For internal use only
Function ImmediateEDSending() Export
	
	SetPrivilegedMode(True);
	Return Not Constants.UseElectronicDocumentsDelayedSending.Get();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Unpacking electronic documents packages

////////////////////////////////////////////////////////////////////////////////
// Unpacking electronic documents packages

// Function determines ED exchange
// settings by source - to data base document or by ED
//
Function DetermineEDExchangeSettingsBySource(
				Source,
				OutputMessages = True,
				CertificateTumbprintsArray = Undefined,
				ED = Undefined,
				EDKind = Undefined,
				OperatingAgreementsCheckBox = True) Export
	
	If ValueIsFilled(ED) Then
		
		EDParameters = FillEDParametersBySource(Source, , ED.EDKind);
		
		If ValueIsFilled(ED.EDAgreement) Then
			EDParameters.EDAgreement = ED.EDAgreement;
		EndIf;
		If Not ValueIsFilled(EDParameters.Counterparty) Then
			EDParameters.Counterparty = ED.Counterparty;
		EndIf;
		If Not ValueIsFilled(EDParameters.Company) Then
			EDParameters.Company = ED.Company;
		EndIf;
		
		If Not ValueIsFilled(EDParameters.EDKind) Then
			EDParameters.EDKind = ED.EDKind;
		EndIf;
		
		If ED.EDKind = Enums.EDKinds.NotificationAboutClarification
			OR ED.EDKind = Enums.EDKinds.CancellationOffer
			OR ED.EDKind = Enums.EDKinds.NotificationAboutReception Then
			EDParameters.Insert("OwnerEDKind", ED.ElectronicDocumentOwner.EDKind);
		EndIf;
		
		EDParameters.Insert("SetSignatures", ED.DigitalSignatures.UnloadColumn("Imprint"));
	Else
		EDParameters = FillEDParametersBySource(Source);
	EndIf;
	
	// Fill in EDKind if a user is selected directly.
	If ValueIsFilled(EDKind) Then
		EDParameters.EDKind = EDKind;
	EndIf;
	
	Result = DetermineEDExchangeSettings(EDParameters, CertificateTumbprintsArray, OperatingAgreementsCheckBox);
	
	If Result = Undefined Then
		If OutputMessages Then
			EDParameters.Delete("CompanyAttributeName");
			EDParameters.Delete("CounterpartyAttributeName");
			InformAboutEDAgreementMissing(EDParameters, Source);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// returns ED exchange settings by participants ID.
//
// IDSender
//  parameters - String
//  with sender unique ID, ReceiverID - String with receiver unique ID
//
// Returns:
//  Parameters structure with exchange settings
//
Function GetEDExchangeSettingsByID(SenderID, RecipientID) Export
	
	SetPrivilegedMode(True);
	
	ReturnStructure = Undefined;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDFSettingsOutgoingDocuments.Ref.Company,
	|	EDFSettingsOutgoingDocuments.Ref.Counterparty,
	|	EDFSettingsOutgoingDocuments.Ref AS EDFSetup,
	|	EDFSettingsOutgoingDocuments.EDExchangeMethod AS EDExchangeMethod,
	|	EDFSettingsOutgoingDocuments.EDFProfileSettings AS EDSettingsProfile,
	|	EDFSettingsOutgoingDocuments.EDFProfileSettings.IncomingDocumentsResource AS IncomingDocumentsGeneralResource,
	|	EDFSettingsOutgoingDocuments.Ref.IncomingDocumentsDir,
	|	EDFSettingsOutgoingDocuments.Ref.OutgoingDocumentsDir,
	|	EDFSettingsOutgoingDocuments.Ref.IncomingDocumentsDirFTP,
	|	EDFSettingsOutgoingDocuments.Ref.OutgoingDocumentsDirFTP,
	|	EDFSettingsOutgoingDocuments.Ref.CounterpartyEmail,
	|	EDFSettingsOutgoingDocuments.Ref.IncomingDocumentsResource,
	|	EDFSettingsOutgoingDocuments.Ref.OutgoingDocumentsResource,
	|	EDFSettingsOutgoingDocuments.Ref.CompanyCertificateForDetails,
	|	EDFSettingsOutgoingDocuments.Ref.CounterpartyCertificateForEncryption,
	|	EDFSettingsOutgoingDocuments.Ref.PackageFormatVersion
	|FROM
	|	Catalog.EDUsageAgreements.OutgoingDocuments AS EDFSettingsOutgoingDocuments
	|WHERE
	|	EDFSettingsOutgoingDocuments.CounterpartyID = &CounterpartyID
	|	AND EDFSettingsOutgoingDocuments.CompanyID = &CompanyID
	|	AND Not EDFSettingsOutgoingDocuments.Ref.DeletionMark
	|	AND EDFSettingsOutgoingDocuments.Ref.ConnectionStatus = VALUE(Enum.EDExchangeMemberStatuses.Connected)";
	Query.SetParameter("CounterpartyID", RecipientID);
	Query.SetParameter("CompanyID", SenderID);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		ReturnStructure = New Structure;
		ReturnStructure.Insert("Sender",         SenderID);
		ReturnStructure.Insert("Recipient",          RecipientID);
		ReturnStructure.Insert("Company",         Selection.Company);
		ReturnStructure.Insert("Counterparty",          Selection.Counterparty);
		ReturnStructure.Insert("EDFProfileSettings",  Selection.EDSettingsProfile);
		ReturnStructure.Insert("EDFSetup",        Selection.EDFSetup);
		ReturnStructure.Insert("EDExchangeMethod",      Selection.EDExchangeMethod);
		ReturnStructure.Insert("CompanyCertificateForDetails", Selection.CompanyCertificateForDetails);
		ReturnStructure.Insert("CounterpartyCertificateForEncryption",  Selection.CounterpartyCertificateForEncryption);
		ReturnStructure.Insert("PackageFormatVersion", Selection.PackageFormatVersion);
		
		SenderAddress = Selection.IncomingDocumentsResource;
		RecipientAddress  = Selection.OutgoingDocumentsResource;
		If Selection.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEMail Then
			SenderAddress = Selection.IncomingDocumentsGeneralResource;
			RecipientAddress  = Selection.CounterpartyEmail;
			
		ElsIf Selection.EDExchangeMethod = Enums.EDExchangeMethods.ThroughDirectory Then
			
			SenderAddress = CommonUseClientServer.GetFullFileName(
				Selection.IncomingDocumentsGeneralResource, Selection.IncomingDocumentsDir);
			RecipientAddress = CommonUseClientServer.GetFullFileName(
				Selection.IncomingDocumentsGeneralResource, Selection.OutgoingDocumentsDir);
		
		ElsIf Selection.EDExchangeMethod = Enums.EDExchangeMethods.ThroughFTP Then
			
			SenderAddress = CommonUseClientServer.GetFullFileName(
				Selection.IncomingDocumentsGeneralResource, Selection.IncomingDocumentsDirFTP);
			RecipientAddress = CommonUseClientServer.GetFullFileName(
				Selection.IncomingDocumentsGeneralResource, Selection.OutgoingDocumentsDirFTP)
			
		EndIf;
		ReturnStructure.Insert("SenderAddress", SenderAddress);
		ReturnStructure.Insert("RecipientAddress",  RecipientAddress);
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

// For internal use only
Function ProcessDocumentConfirmations(PackageFiles, MapFileParameters, PackageEDObject) Export
	
	ReturnArray = New Array;
	
	// Try to obtain cryptography settings.
	If ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer() Then
		Cancel = False;
		CryptoManager = ElectronicDocumentsServiceCallServer.GetCryptoManager(Cancel);
		If Cancel Then
			Return ReturnArray;
		EndIf;
	Else
		Return ReturnArray;
	EndIf;
	
	For Each ItemMap IN MapFileParameters Do
		If Find(ItemMap.Key, ".p7s") > 0 Then
			RequiredDocumentDirection = Enums.EDDirections.Outgoing;
			
			FileReference = PackageFiles.Get(ItemMap.Key);
			If FileReference = Undefined Then
				Continue;
			EndIf;
			
			BinaryDataSignatures = GetFromTempStorage(FileReference);
			
			SearchParametersStructure = New Structure;
			SearchParametersStructure.Insert("UniqueId",  ItemMap.Value.UniqueId);
			SearchParametersStructure.Insert("EDDirection", RequiredDocumentDirection);
			ElectronicDocument = DetermineElectronicDocument(SearchParametersStructure);
			If IsSuchSignature(BinaryDataSignatures , ElectronicDocument) Then
				Continue;
			EndIf;
			
			CurrentDocumentsAddress = GetFileData(ElectronicDocument).FileBinaryDataRef;
			DocumentBinaryData = GetFromTempStorage(CurrentDocumentsAddress);
			
			SignatureCertificates = CryptoManager.GetCertificatesFromSignature(BinaryDataSignatures);
			If SignatureCertificates.Count() <> 0 Then
				Certificate = SignatureCertificates[0];
				SignatureInstallationDate = SignatureInstallationDate(BinaryDataSignatures);
				SignatureInstallationDate = ?(ValueIsFilled(SignatureInstallationDate), SignatureInstallationDate, CurrentSessionDate());
				PrintBase64 = Base64String(Certificate.Imprint);
				UserPresentation = DigitalSignatureClientServer.SubjectPresentation(Certificate);
				ElectronicDocumentsServiceCallServer.AddInformationAboutSignature(
												ElectronicDocument,
												BinaryDataSignatures,
												PrintBase64,
												SignatureInstallationDate,
												"",
												ItemMap.Key,
												UserPresentation,
												Certificate.Unload());
			EndIf;
			ElectronicDocumentsServiceCallServer.DetermineSignaturesStatuses(ElectronicDocument);
			
			Try
				BeginTransaction();
				ParametersStructure = New Structure;
				ValidEDStatus = GetAdmissibleEDStatus(Enums.EDStatuses.ConfirmationReceived, ElectronicDocument);
				ParametersStructure.Insert("EDStatus", ValidEDStatus);
				ChangeByRefAttachedFile(ElectronicDocument, ParametersStructure, False);
				CommitTransaction();
			Except
				RollbackTransaction();
				MessageText = BriefErrorDescription(ErrorInfo())
					+ NStr("en=' (see details in Event log monitor).';ru=' (подробности см. в Журнале регистрации).'");
				ErrorText = DetailErrorDescription(ErrorInfo());
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
					NStr("en='receiving ED confirmation';ru='получение подтверждения ЭД'"), ErrorText, MessageText);
			EndTry;
			
			EDPackageRow = PackageEDObject.ElectronicDocuments.Add();
			EDPackageRow.ElectronicDocument = "Confirmation";
			EDPackageRow.OwnerObject = ElectronicDocument.FileOwner;
			ReturnArray.Add(ElectronicDocument.FileOwner);
		EndIf;
	EndDo;
	
	Return ReturnArray;
	
EndFunction

// Receives electronic document test presentation.
//
// Parameters:
//  LinkToED - Ref to electronic document text presentation of which should be received.
//
Function GetEDPresentation(LinkToED) Export
	
	Version = LinkToED.EDVersionNumber;
	If LinkToED.EDDirection = Enums.EDDirections.Incoming
		AND ValueIsFilled(LinkToED.EDFormingDateBySender) Then
		Version = LinkToED.EDFormingDateBySender;
	ElsIf LinkToED.EDDirection = Enums.EDDirections.Outgoing
		AND ValueIsFilled(LinkToED.CreationDate) Then
		Version = LinkToED.CreationDate;
	EndIf;
	VersionText = ?(ValueIsFilled(Version), " (version " + Version + ")", "");
	DateText = ?(ValueIsFilled(LinkToED.SenderDocumentDate),
		" dated " + Format(LinkToED.SenderDocumentDate, "DLF=D"), "");
	
	If LinkToED.EDKind = Enums.EDKinds.ProductsDirectory OR LinkToED.EDKind = Enums.EDKinds.PriceList Then
		
		Presentation = "" + LinkToED.EDKind + DateText + VersionText;
	ElsIf LinkToED.EDKind = Enums.EDKinds.NotificationAboutReception
			OR LinkToED.EDKind = Enums.EDKinds.Confirmation
			OR LinkToED.EDKind = Enums.EDKinds.CancellationOffer
			OR LinkToED.EDKind = Enums.EDKinds.NotificationAboutClarification Then
		
		Presentation = "" + LinkToED.VersionPointTypeED + DateText;
	ElsIf LinkToED.EDKind = Enums.EDKinds.CustomerInvoiceNote
		  OR LinkToED.EDKind = Enums.EDKinds.CorrectiveInvoiceNote Then
		
		Presentation = "" + LinkToED.EDKind + " No " + LinkToED.SenderDocumentNumber + DateText;
		
	ElsIf LinkToED.EDKind = Enums.EDKinds.BankStatement Then
		Presentation = "" + LinkToED.EDKind+" dated " + Format(LinkToED.CreationDate,"DLF=D");
	ElsIf LinkToED.EDKind = Enums.EDKinds.QueryStatement
		OR LinkToED.EDKind = Enums.EDKinds.EDStateQuery
		OR LinkToED.EDKind = Enums.EDKinds.NotificationOnStatusOfED
		OR LinkToED.EDKind = Enums.EDKinds.QueryProbe Then
		Presentation = "" + LinkToED;
	Else
		Presentation = "" + LinkToED.EDKind + " No " + LinkToED.SenderDocumentNumber + DateText + VersionText;
	EndIf;
	
	Return Presentation;
	
EndFunction

// Determines electronic document presentation.
//
// Parameters:
//  EDKind - Kind of electronic document, enumeration.
//  ParametersStructure: OwnerNumber, OwnerDate, EDVersion.
//
Function DetermineEDPresentation(EDKind, ParametersStructure) Export
	
	TextEDKind  = "";
	NumberText = "";
	DateText   = "";
	VersionText = "";
	PropertyValue = Undefined;
	
	If ParametersStructure.Property("OwnerNumber", PropertyValue) AND ValueIsFilled(PropertyValue) Then
		NumberText = "_" + PropertyValue;
		
	EndIf;
	If ParametersStructure.Property("OwnerDate", PropertyValue) AND ValueIsFilled(PropertyValue) Then
		DateText = "_" + Format(PropertyValue, "DF=yyyy-MM-dd");
	EndIf;
	
	If EDKind <> Enums.EDKinds.CustomerInvoiceNote AND EDKind <> Enums.EDKinds.NotificationAboutReception
		AND EDKind <> Enums.EDKinds.Confirmation AND EDKind <> Enums.EDKinds.NotificationAboutClarification
		AND EDKind <> Enums.EDKinds.PaymentOrder AND EDKind <> Enums.EDKinds.STATEMENT
		AND EDKind <> Enums.EDKinds.QueryStatement AND ParametersStructure.Property("EDVersion", PropertyValue)
		AND ValueIsFilled(PropertyValue) Then
		
		VersionTextTemplate = NStr("en=' (version %1)';ru=' (версия %1)'");
		VersionText = StringFunctionsClientServer.PlaceParametersIntoString(VersionTextTemplate, PropertyValue);
		
	EndIf;
	
	If EDKind = Enums.EDKinds.CustomerInvoiceNote OR  EDKind = Enums.EDKinds.CorrectiveInvoiceNote Then
		TextEDKind = NStr("en='IR';ru='IR'");
	ElsIf EDKind = Enums.EDKinds.TORG12 Then
		TextEDKind = NStr("en='TORG-12';ru='ТОРГ-12'");
	ElsIf EDKind = Enums.EDKinds.TORG12Seller OR EDKind = Enums.EDKinds.TORG12Customer Then
		TextEDKind = String(EDKind);
	ElsIf EDKind = Enums.EDKinds.AgreementAboutCostChangeSender OR EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient Then
		TextEDKind = String(EDKind);
	ElsIf EDKind = Enums.EDKinds.AcceptanceCertificate Then
		TextEDKind = NStr("en='Act';ru='Акт'");
	ElsIf EDKind = Enums.EDKinds.RightsDelegationAct Then
		TextEDKind = NStr("en='Act on transfer of rights';ru='Акт на передачу прав'");
	ElsIf EDKind = Enums.EDKinds.ActPerformer OR EDKind = Enums.EDKinds.ActCustomer Then
		TextEDKind = String(EDKind);
	ElsIf EDKind = Enums.EDKinds.InvoiceForPayment Then
		TextEDKind = NStr("en='Account';ru='Счет'");
	ElsIf EDKind = Enums.EDKinds.ProductOrder Then
		TextEDKind = NStr("en='ProductOrder';ru='ЗаказТовара'");
	ElsIf EDKind = Enums.EDKinds.ResponseToOrder Then
		TextEDKind = NStr("en='ResponseToOrder';ru='ОтветНаЗаказ'");
	ElsIf EDKind = Enums.EDKinds.PriceList Then
		TextEDKind = NStr("en='PriceList';ru='PriceList'");
	ElsIf EDKind = Enums.EDKinds.ProductsDirectory Then
		TextEDKind = NStr("en='ProductsDirectory';ru='КаталогТоваров'");
	ElsIf EDKind = Enums.EDKinds.ComissionGoodsSalesReport Then
		TextEDKind = NStr("en='ComissionGoodsSalesReport';ru='ОтчетОПродажахКомиссионногоТовара'");
	ElsIf EDKind = Enums.EDKinds.ComissionGoodsWriteOffReport Then
		TextEDKind = NStr("en='ComissionGoodsWriteOffReport';ru='ОтчетОСписанииКомиссионногоТовара'");
	ElsIf EDKind = Enums.EDKinds.GoodsTransferBetweenCompanies Then
		TextEDKind = NStr("en='TransferringInt';ru='ПередачаИнт'");
	ElsIf EDKind = Enums.EDKinds.ProductsReturnBetweenCompanies Then
		TextEDKind = NStr("en='ReturnInt';ru='ВозвратИнт'");
	ElsIf EDKind = Enums.EDKinds.NotificationAboutReception Then
		TextEDKind = NStr("en='Notification about receiving';ru='Извещение о получении'");
	ElsIf EDKind = Enums.EDKinds.Confirmation Then
		TextEDKind = NStr("en='Confirmation';ru='Подтверждение'");
		EDType = "";
		If ParametersStructure.Property("EDType", EDType) Then
			If EDType = Enums.EDVersionElementTypes.EIRDC
			 OR EDType = Enums.EDVersionElementTypes.RDC Then
				TextEDKind = TextEDKind + " receipt dates";
			Else
				TextEDKind = TextEDKind + " sending dates";
			EndIf;
		EndIf;
	ElsIf EDKind = Enums.EDKinds.NotificationAboutClarification Then
		TextEDKind = NStr("en='Notification about clarification';ru='Уведомление об уточнении'");
	ElsIf EDKind = Enums.EDKinds.CancellationOffer Then
		TextEDKind = NStr("en='Cancellation offer';ru='Предложение об аннулировании'");
	ElsIf EDKind = Enums.EDKinds.PaymentOrder Then
		TextEDKind = NStr("en='Payment order';ru='Порядок платежа'");
	ElsIf EDKind = Enums.EDKinds.STATEMENT Then
		TextEDKind = NStr("en='STATEMENT';ru='Квитанция'");
	ElsIf EDKind = Enums.EDKinds.AddData Then
		TextEDKind = NStr("en='Data schema';ru='Схема данных'");;
	ElsIf EDKind = Enums.EDKinds.NotificationOnStatusOfED Then
		TextEDKind = NStr("en='Notification of the electronic document state';ru='Извещение о состоянии электронного документа'");
	ElsIf EDKind = Enums.EDKinds.EDStateQuery Then
		TextEDKind = NStr("en='Query on electronic document state';ru='Запрос о состоянии электронного документа'");
	ElsIf EDKind = Enums.EDKinds.QueryProbe Then
		TextEDKind = NStr("en='Text query';ru='Тестовый запрос'");
	ElsIf EDKind = Enums.EDKinds.EDReturnQuery Then
		TextEDKind = NStr("en='Query for electronic document revocation';ru='Запрос на отзыв электронного документа'");
	EndIf;
	EDPresentation = TextEDKind + NumberText + DateText + VersionText;
	
	Return EDPresentation;
	
EndFunction

// Determines the electronic document version state on the base of the current electronic document status.
//
// Parameters:
//  LinkToED - CatalogRef.EDAttachedFiles, reference to electronic document.
//
Function DetermineVersionStateByEDStatus(LinkToED, EDPackFormatVersion = Undefined) Export
	
	SetPrivilegedMode(True);
	
	ReturnValue = Undefined;
	
	If LinkToED = Undefined Or LinkToED = Catalogs.EDAttachedFiles.EmptyRef() Then
		ReturnValue = Enums.EDVersionsStates.NotFormed;
	ElsIf ValueIsFilled(LinkToED.EDAgreement) Then
		
		CurrentStatus = LinkToED.EDStatus;
		
		ExchangeSettings = EDExchangeSettings(LinkToED);
		
		If CurrentStatus = Enums.EDStatuses.TransferError Then
			ReturnValue = Enums.EDVersionsStates.TransferError;
		ElsIf CurrentStatus = Enums.EDStatuses.RejectedByBank
				OR CurrentStatus = Enums.EDStatuses.ESNotCorrect
				OR CurrentStatus = Enums.EDStatuses.AttributesError
				OR CurrentStatus = Enums.EDStatuses.RefusedABC Then
			ReturnValue = Enums.EDVersionsStates.Rejected;
		ElsIf CurrentStatus = Enums.EDStatuses.CardFile2
				OR CurrentStatus = Enums.EDStatuses.Suspended Then
			ReturnValue = Enums.EDVersionsStates.ExpectedPerformance;
		ElsIf CurrentStatus = Enums.EDStatuses.Rejected
			OR CurrentStatus = Enums.EDStatuses.RejectedByReceiver Then
				If ExchangeSettings.ExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
					OR ExchangeSettings.Direction = Enums.EDDirections.Incoming Then
					
					If ExchangeSettings.Direction = Enums.EDDirections.Outgoing Then 
						ReturnValue = Enums.EDVersionsStates.DocumentClarificationNeeded;
					Else
						ReturnValue = Enums.EDVersionsStates.CorrectionExpected;
					EndIf;

				Else
					ReturnValue = Enums.EDVersionsStates.DocumentClarificationNeeded;
				EndIf;
		ElsIf CurrentStatus = Enums.EDStatuses.CancellationOfferCreated Then
			ReturnValue = Enums.EDVersionsStates.CancellationExpected;
		ElsIf CurrentStatus = Enums.EDStatuses.CancellationOfferReceived Then
			ReturnValue = Enums.EDVersionsStates.CancellationRequired;
		ElsIf CurrentStatus = Enums.EDStatuses.Canceled Then
			ReturnValue = Enums.EDVersionsStates.Canceled;
		ElsIf ExchangeSettings <> Undefined Then
			
			If EDPackFormatVersion = Undefined Then
				EDPackFormatVersion = EDPackageVersion(LinkToED);
			EndIf;
			
			If EDPackFormatVersion = Enums.EDPackageFormatVersions.Version30
				OR ExchangeSettings.ExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
				
				// If ED owner document has unsent confirmation on
				// receipt, change ED version state.
				
				If (CurrentStatus = Enums.EDStatuses.Sent
						OR CurrentStatus = Enums.EDStatuses.TransferedToOperator
						OR CurrentStatus = Enums.EDStatuses.ConfirmationSent)
					OR (CurrentStatus = Enums.EDStatuses.DigitallySigned
						AND IsResponseTitle(LinkToED)) Then
					
					If HasUnsentConfirmation(LinkToED.FileOwner, ReturnValue) Then
						Return ReturnValue;
					EndIf;
				EndIf;
				
				If (CurrentStatus = Enums.EDStatuses.Received
					AND IsResponseTitle(LinkToED)) 
					Or CurrentStatus = Enums.EDStatuses.Sent
					Or CurrentStatus = Enums.EDStatuses.ConfirmationReceived Then
					If HasNotReceivedConfirmation(LinkToED.FileOwner, ReturnValue) Then
						Return ReturnValue;
					EndIf;
				EndIf;
			EndIf;
			
			StatusesArray = ReturnEDStatusesArray(ExchangeSettings);
			If StatusesArray.Count() > 0 Then
				
				CurrentStatusIndex = StatusesArray.Find(CurrentStatus);
				If CurrentStatusIndex = Undefined Then
				ElsIf CurrentStatusIndex + 1 = StatusesArray.Count() Then
					If CommonUse.ObjectAttributeValue(LinkToED, "EDKind") = Enums.EDKinds.PaymentOrder Then
						ReturnValue = Enums.EDVersionsStates.PaymentExecuted;
					Else
						ReturnValue = Enums.EDVersionsStates.ExchangeCompleted;
					EndIf;
				Else
					NextStatus = StatusesArray[CurrentStatusIndex + 1];
					If NextStatus = Enums.EDStatuses.Approved Then
						
						ReturnValue = Enums.EDVersionsStates.OnApproval;
						
					ElsIf NextStatus = Enums.EDStatuses.DigitallySigned
						OR NextStatus = Enums.EDStatuses.FullyDigitallySigned
						OR NextStatus = Enums.EDStatuses.PartlyDigitallySigned Then
						
						ReturnValue = Enums.EDVersionsStates.OnSigning;
						
					ElsIf NextStatus = Enums.EDStatuses.Sent
						AND CommonUse.ObjectAttributeValue(LinkToED.EDFProfileSettings, "EDExchangeMethod") = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
						
						ReturnValue = Enums.EDVersionsStates.SendingToRecipientExpected;
						
					ElsIf NextStatus = Enums.EDStatuses.TransferedToOperator Then
						
						ReturnValue = Enums.EDVersionsStates.OperatorTransferExpecting;
						
					ElsIf NextStatus = Enums.EDStatuses.Sent
						OR NextStatus = Enums.EDStatuses.ConfirmationSent
						OR NextStatus = Enums.EDStatuses.PreparedToSending Then
						
						ReturnValue = Enums.EDVersionsStates.SendingExpected;
						
					ElsIf NextStatus = Enums.EDStatuses.Delivered
							OR NextStatus = Enums.EDStatuses.ConfirmationDelivered Then
							
						If ExchangeSettings.EDKind = Enums.EDKinds.PaymentOrder
								AND (ExchangeSettings.BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
									OR ExchangeSettings.BankApplication = Enums.BankApplications.iBank2) Then
							ReturnValue = Enums.EDVersionsStates.ConfirmationRequired;
						Else
							ReturnValue = Enums.EDVersionsStates.NotificationAboutReceivingExpected;
						EndIf;
						
					ElsIf NextStatus = Enums.EDStatuses.ConfirmationReceived Then
						
						ReturnValue = Enums.EDVersionsStates.ConfirmationExpected;
						
					ElsIf NextStatus = Enums.EDStatuses.Executed
							OR NextStatus = Enums.EDStatuses.Accepted Then
							
						ReturnValue = Enums.EDVersionsStates.ExpectedPerformance;
					ElsIf NextStatus = Enums.EDStatuses.Confirmed Then
						ReturnValue = Enums.EDVersionsStates.StatementExpected;
					EndIf;
				EndIf;
				
				
				
				
			EndIf;
			
		EndIf;
	EndIf;
	
	Return ReturnValue;
	
EndFunction

// Determines whether all signatures set to ED are valid
//
// Parameters: 
// ED - CatalogRef.EDAttachedFiles, reference to electronic document.
//
Function SetSignaturesValid(ED) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	EDAttachedFilesDigitalSignatures.SignatureIsCorrect
	|FROM
	|	Catalog.EDAttachedFiles.DigitalSignatures AS EDAttachedFilesDigitalSignatures
	|WHERE
	|	EDAttachedFilesDigitalSignatures.Ref = &Ref
	|	AND Not EDAttachedFilesDigitalSignatures.SignatureIsCorrect";
	Query.SetParameter("Ref", ED.Ref);
	
	Result = Query.Execute().Select();
	If Result.Count() > 0 Then
		TextPattern = NStr("en='%1 electronic document processing.
		|Document has not been processed because it contains invalid signatures.';ru='Обработка электронного документа %1.
		|Документ не обработан, так как содержит невалидные подписи.'");
		Text = StringFunctionsClientServer.PlaceParametersIntoString(TextPattern, ED);
		CommonUseClientServer.MessageToUser(Text);
		
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Determines whether it is possible to
// extract files from the archive without error Full name max length in 255 characters is checked
// 
// Parameters:
//  ZipReading - ZipFileReader - opened
//  zip archive UnpackFolder - folder to which data
//  will be extracted CreatedFileName - name of the file that can not be extrected
//
// Returns:
//  Boolean 
//
Function PossibleToExtractFiles(ZipReading, UnpackingDirectory, CreatedFileName="") Export
	
	FolderPathLength = StrLen(UnpackingDirectory);
	
	For Each Item IN ZipReading.Items Do
		FileName = Item.FullName;
		FileNameLength = StrLen(FileName);
		FullLength = FolderPathLength + FileNameLength + 1;
		If FullLength > 255 Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Processing the electronic documents

// For internal use only
Function SendingCompletedED(AccAgreementsAndStructuresOfCertificates = Undefined) Export
	
	Result = 0;
	// Create and fill in documents EDPacks
	ReadyToBeSentPackages = DeterminePreparedToSendED();
	If ValueIsFilled(ReadyToBeSentPackages) Then
		Result = ElectronicDocumentsServiceCallServer.EDPackagesSending(ReadyToBeSentPackages,
																				AccAgreementsAndStructuresOfCertificates);
	EndIf;
	
	Return Result;
	
EndFunction

// Receives new electronic
// documents based on exchange agreements.
//
Function GetNewED(AccAgreementsAndStructuresOfCertificates = Undefined, Readmission = False) Export
	
	SetPrivilegedMode(True);
	
	ReturnStructure = New Structure("UnpackingParameters, ReturnArray, CallNotification",
		New Array, Undefined, False);
	
	ReturnArray = New Array;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	EDFSettingsOutgoingDocuments.EDFProfileSettings AS EDFProfileSettings,
	|	EDFSettingsOutgoingDocuments.EDFProfileSettings.EDExchangeMethod AS EDExchangeMethod,
	|	EDFSettingsOutgoingDocuments.EDFProfileSettings.IncomingDocumentsResource AS IncomingDocumentsGeneralResource,
	|	EDFSettingsOutgoingDocuments.Ref.IncomingDocumentsDir AS IncomingDocumentsDir,
	|	EDFSettingsOutgoingDocuments.Ref.IncomingDocumentsDirFTP AS IncomingDocumentsDirFTP
	|FROM
	|	Catalog.EDUsageAgreements.OutgoingDocuments AS EDFSettingsOutgoingDocuments
	|WHERE
	|	Not EDFSettingsOutgoingDocuments.Ref.DeletionMark
	|	AND EDFSettingsOutgoingDocuments.Ref.ConnectionStatus = VALUE(Enum.EDExchangeMemberStatuses.Connected)";
	
	ResourcesForVerification = Query.Execute().Unload();
	
	EPFilter = New Structure("EDExchangeMethod", Enums.EDExchangeMethods.ThroughEMail);
	EPResourcesArray = ResourcesForVerification.FindRows(EPFilter);

	For Each EPResourcesString IN EPResourcesArray Do
		If IsBlankString(EPResourcesString.IncomingDocumentsGeneralResource) Then
			Continue;
		EndIf;
		
		EPAccount = EPResourcesString.IncomingDocumentsGeneralResource;
		MessageSet = New Array();
		Try
			MessageSet = EmailOperations.ImportEMails(EPAccount);
		Except
			ErrorText = DetailErrorDescription(ErrorInfo());
			Text = NStr("en='Error while receiving messages from the email server
		|%1';ru='Ошибка при получении сообщения с сервера электронной почты.
		|%1'");
			ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(Text, ErrorText);
			
			MessageText = NStr("en='An error occurred while receiving new electronicdocuments is started.
		|(see details in Event log monitor).';ru='Ошибка при получении новых эл.документов.
		|(подробности см. в Журнале регистрации).'");
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
				NStr("en='New electronic documents receiving';ru='Получение новых электронных документов'"), ErrorText, MessageText);
			Continue;
		EndTry;
		
		For Each Message IN MessageSet Do
			ParametersStructure = New Structure;
			If Not NeedToReceive(Message, ParametersStructure) Then
				Continue;
			EndIf;
			
			If Find(Message.Subject, "Confirm that you received electronic documents pack") Then
				ProcessReceivingConfirmation(Message);
				ReturnStructure.CallNotification = True;
				Continue;
			EndIf;
			
			ParametersStructure.Insert("PackageStatus",   Enums.EDPackagesStatuses.ToUnpacking);
			ParametersStructure.Insert("EDDirections",  Enums.EDDirections.Incoming);
			EDPackage = GenerateNewEDPackage(ParametersStructure);
			
			For Each ItemAttachments IN Message.Attachments Do
				ItemBinaryData = ItemAttachments.Value;
				AddressInStorage = PutToTempStorage(ItemBinaryData);
				AttachedFile = AttachedFiles.AddFile(EDPackage, Left(ItemAttachments.Key,
					StrLen(ItemAttachments.Key) -4), Right(ItemAttachments.Key, 3), CurrentSessionDate(),
					CurrentSessionDate(), AddressInStorage, , , Catalogs.EDAttachedFiles.GetRef());
				
				ReturnArray.Add(AttachedFile);
			EndDo;
			
			If Not ParametersStructure.PackageFormatVersion = Enums.EDPackageFormatVersions.Version30 Then
				
				SendConfirmationByPackage(EDPackage, EPAccount, Message.Sender,
												Enums.EDExchangeMethods.ThroughEMail);
			EndIf;
			
			UnpackingStructure = New Structure;
			UnpackingStructure.Insert("EDPackage", EDPackage);
			If ParametersStructure.Encrypted Then
				EncryptionStructure = New Structure;
				
				If ValueIsFilled(ParametersStructure.CompanyCertificateForDetails) Then
					EncryptionStructure.Insert("Certificate", ParametersStructure.CompanyCertificateForDetails);
					EncryptionStructure.Insert("CertificateParameters", ElectronicDocumentsServiceCallServer.CertificateAttributes(
						ParametersStructure.CompanyCertificateForDetails));
				Else
					MessagePattern = NStr("en='Decryption certificate is not specified for: %1.';ru='Не указан сертификат расшифровки для: %1.'");
					MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, EDPackage);
					Continue;
				EndIf;
			
				UnpackingStructure.Insert("EncryptionStructure", EncryptionStructure);
			EndIf;
			UnpackingStructure.Insert("UnpackingData",
				ElectronicDocumentsServiceCallServer.ReturnArrayBinaryDataPackage(EDPackage));
				
			ReturnStructure.UnpackingParameters.Add(UnpackingStructure);
		EndDo;
	EndDo;
	
	FilterDirectory = New Structure("EDExchangeMethod", Enums.EDExchangeMethods.ThroughDirectory);
	ResourcesArrayDirectories = ResourcesForVerification.FindRows(FilterDirectory);
	For Each ResourceRowDirectory IN ResourcesArrayDirectories Do
		DirectoryWithFiles = CommonUseClientServer.GetFullFileName(
			ResourceRowDirectory.IncomingDocumentsGeneralResource, ResourceRowDirectory.IncomingDocumentsDir);
			
		FileNameArray = New Array;
		FilesArray = FindFiles(DirectoryWithFiles, "*");
		For Each ItemFile IN FilesArray Do
			If ItemFile.IsDirectory() Then
				Continue;
			EndIf;
			
			If ItemFile.Extension = ".xml" Then
				ProcessReceivingConfirmation(ItemFile, True);
				ReturnStructure.CallNotification = True;
				Continue;
			EndIf;
			
			If Not ItemFile.Extension = ".zip" Then
				Continue;
			EndIf;
			
			ParametersStructure = New Structure;
			ItemBinaryData = New BinaryData(ItemFile.FullName);
			If Not NeedToGetBinaryData(ItemBinaryData, ItemFile.Name, ParametersStructure) Then
				DeleteFiles(ItemFile.FullName);
				Continue;
			EndIf;
			
			ParametersStructure.Insert("PackageStatus",       Enums.EDPackagesStatuses.ToUnpacking);
			ParametersStructure.Insert("EDDirections",      Enums.EDDirections.Incoming);
			EDPackage = GenerateNewEDPackage(ParametersStructure);
			
			AddressInStorage = PutToTempStorage(ItemBinaryData);
			AttachedFile = AttachedFiles.AddFile(EDPackage, Left(ItemFile.Name,
				StrLen(ItemFile.Name) -4), Right(ItemFile.Name, 3), CurrentSessionDate(), CurrentSessionDate(),
				AddressInStorage, , , Catalogs.EDAttachedFiles.GetRef());
			
			ReturnArray.Add(AttachedFile);
			
			If Not ParametersStructure.PackageFormatVersion = Enums.EDPackageFormatVersions.Version30 Then
				
				SendConfirmationByPackage(EDPackage, ResourceRowDirectory, ParametersStructure.SenderAddress,
											  Enums.EDExchangeMethods.ThroughDirectory);
			EndIf;
			
			DeleteFiles(ItemFile.FullName);
			
			UnpackingStructure = New Structure;
			UnpackingStructure.Insert("EDPackage", EDPackage);
			If ParametersStructure.Encrypted Then
				EncryptionStructure = New Structure;
				
				If ValueIsFilled(ParametersStructure.CompanyCertificateForDetails) Then
					EncryptionStructure.Insert("Certificate", ParametersStructure.CompanyCertificateForDetails);
					EncryptionStructure.Insert("CertificateParameters", ElectronicDocumentsServiceCallServer.CertificateAttributes(
						ParametersStructure.CompanyCertificateForDetails));
				Else
					MessagePattern = NStr("en='Decryption certificate is not specified for: %1.';ru='Не указан сертификат расшифровки для: %1.'");
					MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, EDPackage);
					Continue;
				EndIf;
			
				UnpackingStructure.Insert("EncryptionStructure", EncryptionStructure);
			EndIf;
			UnpackingStructure.Insert("UnpackingData",
				ElectronicDocumentsServiceCallServer.ReturnArrayBinaryDataPackage(EDPackage));
				
			ReturnStructure.UnpackingParameters.Add(UnpackingStructure);
		EndDo;
	EndDo;
	
	FilterFTP = New Structure("EDExchangeMethod", Enums.EDExchangeMethods.ThroughFTP);
	FTPResourcesArray = ResourcesForVerification.FindRows(FilterFTP);
	For Each FTPResourcesString IN FTPResourcesArray Do
		EDFProfileSettings = FTPResourcesString.EDFProfileSettings;
		FTPConnection = GetFTPConnection(EDFProfileSettings);
		If FTPConnection = Undefined Then
			Continue;
		EndIf;
		IncDocumentsDir = CommonUseClientServer.GetFullFileName(
			FTPResourcesString.IncomingDocumentsGeneralResource, FTPResourcesString.IncomingDocumentsDirFTP);
			
		FileNameArray = New Array;
		FTPFilesArray = New Array;
		ErrorText = "";
		PrepareFTPPath(IncDocumentsDir);
		Try
			FTPConnection.SetCurrentDirectory(IncDocumentsDir);
		Except
			Continue;
		EndTry;
		FindFilesInFTPDirectory(FTPConnection, IncDocumentsDir, "*", False, ErrorText, FTPFilesArray);
		If ValueIsFilled(ErrorText) Then
			Continue;
		EndIf;
		
		For Each FileFTP IN FTPFilesArray Do
			If FileFTP.IsDirectory() Then
				Continue;
			EndIf;
			TempDirectory = WorkingDirectory();
			FullFileName = TempDirectory + FileFTP.Name;
			GetFileFromFTP(FTPConnection, FileFTP.FullName, FullFileName, , ErrorText);
			If ValueIsFilled(ErrorText) Then
				DeleteFiles(TempDirectory);
				Continue;
			EndIf;
			ItemFile = New File(FullFileName);
			ItemBinaryData = New BinaryData(ItemFile.FullName);
			ParametersStructure = New Structure;
			
			If ItemFile.Extension = ".xml" Then
				ProcessReceivingConfirmation(ItemFile, True);
				ReturnStructure.CallNotification = True;
				DeleteFileFTP(FTPConnection, FileFTP.FullName);
				DeleteFiles(TempDirectory);
				Continue;
			EndIf;
			
			DeleteFiles(TempDirectory);
			If Not ItemFile.Extension = ".zip" Then
				Continue;
			EndIf;
			
			If Not NeedToGetBinaryData(ItemBinaryData, ItemFile.Name, ParametersStructure) Then
				DeleteFileFTP(FTPConnection, FileFTP.FullName);
				DeleteFiles(TempDirectory);
				Continue;
			EndIf;
			
			ParametersStructure.Insert("PackageStatus",   Enums.EDPackagesStatuses.ToUnpacking);
			ParametersStructure.Insert("EDDirections",  Enums.EDDirections.Incoming);
			EDPackage = GenerateNewEDPackage(ParametersStructure);
			
			AddressInStorage = PutToTempStorage(ItemBinaryData);
			AttachedFile = AttachedFiles.AddFile(EDPackage,
																  Left(ItemFile.Name, StrLen(ItemFile.Name) -4),
																  Right(ItemFile.Name, 3),
																  CurrentSessionDate(),
																  CurrentSessionDate(),
																  AddressInStorage,
																  ,
																  ,
																  Catalogs.EDAttachedFiles.GetRef());
			
			ReturnArray.Add(AttachedFile);
			
			If ParametersStructure.PackageFormatVersion = Enums.EDPackageFormatVersions.Version30 Then
				
				SendConfirmationByPackage(EDPackage, FTPResourcesString, ParametersStructure.SenderAddress,
											   Enums.EDExchangeMethods.ThroughFTP);
				DeleteFileFTP(FTPConnection, FileFTP.FullName);
				
			EndIf;
			
			UnpackingStructure = New Structure;
			UnpackingStructure.Insert("EDPackage", EDPackage);
			If ParametersStructure.Encrypted Then
				EncryptionStructure = New Structure;
				
				If ValueIsFilled(ParametersStructure.CompanyCertificateForDetails) Then
					EncryptionStructure.Insert("Certificate", ParametersStructure.CompanyCertificateForDetails);
					EncryptionStructure.Insert("CertificateParameters", ElectronicDocumentsServiceCallServer.CertificateAttributes(
						ParametersStructure.CompanyCertificateForDetails));
				Else
					MessagePattern = NStr("en='Decryption certificate is not specified for: %1.';ru='Не указан сертификат расшифровки для: %1.'");
					MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, EDPackage);
					Continue;
				EndIf;
			
				UnpackingStructure.Insert("EncryptionStructure", EncryptionStructure);
			EndIf;
			UnpackingStructure.Insert("UnpackingData",
				ElectronicDocumentsServiceCallServer.ReturnArrayBinaryDataPackage(EDPackage));
				
			ReturnStructure.UnpackingParameters.Add(UnpackingStructure);
		EndDo;
	EndDo;

	ReturnStructure.ReturnArray = ReturnArray;
	
	SpecOperatorsFilter = New Structure("EDExchangeMethod", Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom);
	SpecOperatorsResourcesArray = ResourcesForVerification.FindRows(SpecOperatorsFilter);

	If SpecOperatorsResourcesArray.Count() > 0 Then
		ElectronicDocumentsInternal.GetEDFOperatorNewED(
												ReturnStructure,
												AccAgreementsAndStructuresOfCertificates,
												,
												Readmission);
	EndIf;
		
	Return ReturnStructure;
	
EndFunction

// It determines electronic document parameters by the owner type.
//
// Parameters:
//  Source - object or the document/catalog-source reference.
//  FormatCML - Boolean if it is True, then CML (not FTS) diagrams will
//    be used for ED creation, the corresponding ED kinds shall be specified in the parameters.
//
// Returns:
//  EDParameters - structure of the source parameters
//  required to specify the ED exchange settings. Required parameters: EDDirection,
//  EDKind, Counterparty, EDAgreement or Company.
//
Function FillEDParametersBySource(Source, FormatCML = False, EDKind = Undefined) Export
	
	EDParameters = EDParametersStructure();
	
	SourceType = TypeOf(Source);
	If SourceType = Type("DocumentRef.RandomED")
		OR SourceType = Type("DocumentObject.RandomED") Then
		
		EDParameters.EDKind         = Enums.EDKinds.RandomED;
		EDParameters.EDDirection = Source.Direction;
		EDParameters.Counterparty    = Source.Counterparty;
		EDParameters.Company   = Source.Company;
	ElsIf SourceType = Type("CatalogRef.EDUsageAgreements")
		OR SourceType = Type("CatalogObject.EDUsageAgreements") Then
		
		If Source.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource Then
			EDParameters.EDKind     = Enums.EDKinds.QueryStatement;
		Else
			EDParameters.EDKind     = Enums.EDKinds.ProductsDirectory;
		EndIf;
		
		EDParameters.EDDirection = Enums.EDDirections.Outgoing;
		EDParameters.EDAgreement  = Source.Ref;
		If Not Source.IsIntercompany Then
			
			EDParameters.Counterparty  = Source.Counterparty;
			EDParameters.Company = Source.Company;
		EndIf;
		
	ElsIf SourceType = Type("CatalogRef.Companies")
		Or SourceType = Type("CatalogObject.Companies") Then
		
		EDParameters.EDKind = "CompanyAttributes";
		EDParameters.Company = Source;
		EDParameters.Insert("CompanyAttributes", True);
	Else
		
		EDParameters.EDKind = EDKind;
		ElectronicDocumentsOverridable.FillEDParametersBySource(Source, EDParameters, FormatCML);
	EndIf;
	
	Return EDParameters;
	
EndFunction

// Changes EDAttachedFiles catalog item attributes,
//
// Parameters:
//  AddedFile - Ref to catalog item with
//  electronic document, EDStructure - Parameters structure that should be filled in in the catalog.
//
Procedure ChangeByRefAttachedFile(
				AddedFile,
				EDStructure,
				CheckRequiredAttributes = True) Export
	
	SetPrivilegedMode(True);
	BeginTransaction();
	
	If CheckRequiredAttributes Then
		ErrorText = "";
		RequiredFieldsStructure = New Structure("EDOwner, Counterparty, EDKind, EDDirection, EDAgreement");
		If EDStructure.EDKind = Enums.EDKinds.PaymentOrder Then
			RequiredFieldsStructure.Delete("Counterparty");
		EndIf;
		For Each KeyValue IN RequiredFieldsStructure Do
			Value = Undefined;
			If EDStructure.Property(KeyValue.Key, Value) Then
				If Not ValueIsFilled(Value) Then
					Text = NStr("en='Parameter value <%1> is not filled in.';ru='Значение параметра <%1> не заполнено!'");
					Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, KeyValue.Key);
					ErrorText = ?(ValueIsFilled(ErrorText), ErrorText + Chars.LF + Text, Text);
				EndIf;
			Else
				Text = NStr("en='Required parameter <%1> has not been passed.';ru='Не передан обязательный параметр <%1>!'");
				Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, KeyValue.Key);
				ErrorText = ?(ValueIsFilled(ErrorText), ErrorText + Chars.LF + Text, Text);
			EndIf;
		EndDo;
		If ValueIsFilled(ErrorText) Then
			MessageText = NStr("en='An error occurred while filling electronic documents additional properties.
		|%1';ru='Ошибка заполнения доп.свойств электронного документа!
		|%1'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, ErrorText);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	
	ElectronicDocumentsOverridable.OnChangeOfAttachedFile(AddedFile, EDStructure);
	
	FileObject = AddedFile.GetObject();
	
	ForcedVersionStateChange = False;
	
	If EDStructure.Property("Author") Then
		FileObject.Author = EDStructure.Author;
	EndIf;
	
	If EDStructure.Property("EDFScheduleVersion") Then
		FileObject.EDFScheduleVersion = EDStructure.EDFScheduleVersion;
	EndIf;
	
	If EDStructure.Property("EDKind") Then
		FileObject.EDKind = EDStructure.EDKind;
	EndIf;
	
	If EDStructure.Property("SenderDocumentDate") Then
		FileObject.SenderDocumentDate = EDStructure.SenderDocumentDate;
	EndIf;
	
	If EDStructure.Property("EDStatusChangeDate") Then
		FileObject.EDStatusChangeDate = EDStructure.EDStatusChangeDate;
	EndIf;
	
	If EDStructure.Property("ModificationDateUniversal") Then
		FileObject.ModificationDateUniversal = EDStructure.ModificationDateUniversal;
	EndIf;
	
	If EDStructure.Property("CreationDate") Then
		FileObject.CreationDate = EDStructure.CreationDate;
	EndIf;
	
	If EDStructure.Property("EDFormingDateBySender") Then
		FileObject.EDFormingDateBySender = EDStructure.EDFormingDateBySender;
	EndIf;
	
	If EDStructure.Property("AdditionalInformation") Then
		FileObject.AdditionalInformation = EDStructure.AdditionalInformation;
	EndIf;
	
	If EDStructure.Property("AdditionalAttributes") Then
		If ValueIsFilled(FileObject.AdditionalAttributes) Then
			AdditionalAttributes = FileObject.AdditionalAttributes.Get();
			If Not ValueIsFilled(AdditionalAttributes) Then
				AdditionalAttributes = New Structure;
			EndIf;
		Else
			AdditionalAttributes = EDStructure.AdditionalAttributes;
		EndIf;
		
		For Each KeyValue IN EDStructure.AdditionalAttributes Do
			AdditionalAttributes.Insert(KeyValue.Key, KeyValue.Value);
		EndDo;
		
		FileObject.AdditionalAttributes = New ValueStorage(EDStructure.AdditionalAttributes);
	EndIf;
	
	If EDStructure.Property("Changed") Then
		FileObject.Changed = EDStructure.Changed;
	EndIf;
	
	If EDStructure.Property("Counterparty") Then
		FileObject.Counterparty = EDStructure.Counterparty;
	EndIf;
	
	If EDStructure.Property("Description") Then
		FileObject.Description = EDStructure.Description;
	EndIf;
	
	If EDStructure.Property("FileDescription") Then
		FileObject.FileDescription = EDStructure.FileDescription;
	EndIf;
	
	If EDStructure.Property("EDDirection") Then
		FileObject.EDDirection = EDStructure.EDDirection;
	EndIf;
	
	If EDStructure.Property("EDVersionNumber") Then
		FileObject.EDVersionNumber = EDStructure.EDVersionNumber;
	ElsIf EDStructure.Property("EDOwner") Then
		FileObject.EDVersionNumber = EDVersionNumberByOwner(EDStructure.EDOwner);
	EndIf;
	
	If EDStructure.Property("SenderDocumentNumber") Then
		FileObject.SenderDocumentNumber = EDStructure.SenderDocumentNumber;
	EndIf;
	
	If EDStructure.Property("EDNumber") Then 
		FileObject.EDNumber = EDStructure.EDNumber;
	EndIf;
	
	If EDStructure.Property("Definition") Then
		FileObject.Definition = TrimAll(EDStructure.Definition);
	Else
		FileObject.Definition = "";
	EndIf;
	
	If EDStructure.Property("Company") Then
		FileObject.Company = EDStructure.Company;
	EndIf;
	
	If EDStructure.Property("Responsible") Then
		FileObject.Responsible = EDStructure.Responsible;
	EndIf;
	If Not ValueIsFilled(FileObject.Responsible) Then
		FileObject.Responsible = Users.AuthorizedUser();
	EndIf;
	
	If Not ValueIsFilled(FileObject.EDFrom) AND EDStructure.Property("Sender") Then
		FileObject.EDFrom = EDStructure.Sender;
	EndIf;
	
	If EDStructure.Property("DigitallySignedData") Then
		StorageOfDigitallySignedData = New ValueStorage(EDStructure.DigitallySignedData);
		FileObject.DigitallySignedData = StorageOfDigitallySignedData;
	EndIf;
	
	If Not ValueIsFilled(FileObject.EDRecipient) AND EDStructure.Property("Recipient") Then
		FileObject.EDRecipient = EDStructure.Recipient;
	EndIf;
	
	If EDStructure.Property("RejectionReason") Then
		FileObject.RejectionReason = EDStructure.RejectionReason;
	EndIf;
	
	If EDStructure.Property("EDFProfileSettings") Then
		FileObject.EDFProfileSettings = EDStructure.EDFProfileSettings;
	EndIf;
	
	If EDStructure.Property("Extension") Then
		FileObject.Extension = EDStructure.Extension;
	EndIf;
	
	If EDStructure.Property("EDAgreement") Then
		FileObject.EDAgreement = EDStructure.EDAgreement;
		FileObject.AdditionalProperties.Insert("EDAgreement", EDStructure.EDAgreement);
	EndIf;
	
	If EDStructure.Property("EDStatus") Then
		If (EDStructure.EDStatus = Enums.EDStatuses.CancellationOfferCreated
				OR EDStructure.EDStatus = Enums.EDStatuses.CancellationOfferReceived)
			AND FileObject.EDStatus <> EDStructure.EDStatus Then
			ForcedVersionStateChange = True;
		EndIf;
		FileObject.EDStatus = EDStructure.EDStatus;
		FileObject.EDStatusChangeDate = CurrentSessionDate();
	EndIf;
	
	If EDStructure.Property("DocumentAmount") AND ValueIsFilled(EDStructure.DocumentAmount) Then
		FileObject.DocumentAmount = EDStructure.DocumentAmount;
	EndIf;
	
	If EDStructure.Property("CorrectionText") Then
		FileObject.RejectionReason = EDStructure.CorrectionText;
	EndIf;
	
	If EDStructure.Property("VersionPointTypeED") Then
		FileObject.VersionPointTypeED = EDStructure.VersionPointTypeED;
	EndIf;
	
	If EDStructure.Property("DeleteDS") Then
		FileObject.DigitalSignatures.Clear();
	EndIf;
	
	If EDStructure.Property("UniqueId") Then
		FileObject.UniqueId = EDStructure.UniqueId;
	EndIf;
	
	If EDStructure.Property("UUIDExternal") Then
		FileObject.UUIDExternal = EDStructure.UUIDExternal;
	EndIf;
	
	If EDStructure.Property("ElectronicDocumentOwner") Then
		FileObject.ElectronicDocumentOwner = EDStructure.ElectronicDocumentOwner;
		EDStructure.Insert(
				"DocumentAmount",
				CommonUse.ObjectAttributeValue(EDStructure.ElectronicDocumentOwner, "DocumentAmount"));
	EndIf;
	
	FileObject.Write();
	
	If FileObject.EDKind = Enums.EDKinds.RandomED Then
		EDOwner = FileObject.FileOwner.GetObject();
		EDOwner.DocumentStatus = FileObject.EDStatus;
		EDOwner.Write();
	EndIf;
	
	PackageFormatVersion = Undefined;
	EDStructure.Property("PackageFormatVersion", PackageFormatVersion);
		
	ElectronicDocumentsServiceCallServer.RefreshEDVersion(FileObject.Ref,
		ForcedVersionStateChange, PackageFormatVersion);
	
	CommitTransaction();
	
EndProcedure

// Returns file data structure received from the eponymous function of the AttachedFiles general module.
// Changes item value with the Name key in the received structure to
// the full name stored in the FileName catalog item attribute and generates the FileName item value again.
// Used in work with files
// commands both as FileData parameter value of other procedures and functions value.
//
// Parameters:
//  AttachedFile - Ref to the attached file.
//
//  FormID - form
//                 UUID, it is used while receiving attachment binary data.
//
//  GetRefToBinaryData - Boolean - True initial
//                 value if you pass False, then ref to binary data will
//                 not be received. It will speed up execution for big binary data.
//
// Returns:
//  Structure with properties:
//    FileBinaryDataRef        - String - address in the temporary storage.
//    RelativePath                  - String.
//    ModificationDateUniversal       - Date.
//    FileName                           - String.
//    Description                       - String, corresponds to the value of the FileDescription catalog item attribute.
//    Extension                         - String.
//    Size                             - Number.
//    IsEditing                        - CatalogRef.Users.
//    DigitallySigned                        - Boolean.
//    Encrypted                         - Boolean.
//    FileIsEditing                  - Boolean.
//    FileCurrentUserIsEditing - Boolean.
// 
Function GetFileData(Val AttachedFile,
                            Val FormID = Undefined,
                            Val GetRefToBinaryData = True) Export
	
	FileData = AttachedFiles.GetFileData(AttachedFile,
		FormID, GetRefToBinaryData);
	If TypeOf(FileData) = Type("Structure") Then
		ParametersStructure = CommonUse.ObjectAttributesValues(AttachedFile, "EDKind, UUID, FileDescription");
		If ValueIsFilled(ParametersStructure.FileDescription) Then
			FileData.Description = TrimAll(ParametersStructure.FileDescription);
			FileData.FileName = FileData.Description + "." + FileData.Extension;
			NameCorrected = True;
		ElsIf ParametersStructure.EDKind = Enums.EDKinds.CorrectiveInvoiceNote Then
			StringAtID = ParametersStructure.UniqueId;
			Description = FileData.Description;
			UIDPosition = Find(Description, "_" + Left(StringAtID, 35));
			If UIDPosition > 0 Then
				FileData.Description = Left(Description, UIDPosition) + StringAtID;
				FileData.FileName = FileData.Description + "." + FileData.Extension;
			EndIf;
		EndIf;
	EndIf;
	
	Return FileData;
	
EndFunction

// For internal use only
Procedure SaveInvitation(InvitationsTable) Export
	
	If InvitationsTable.Count() = 0 Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Invitation.EDFProfileSettings,
	|	Invitation.InvitationText,
	|	Invitation.ID,
	|	Invitation.ExternalID AS ExternalID,
	|	Invitation.TIN AS TIN,
	|	Invitation.KPP,
	|	Invitation.State,
	|	Invitation.Description,
	|	Invitation.Changed AS Changed,
	|	Invitation.ErrorDescription
	|INTO Invitation
	|FROM
	|	&Invitation AS Invitation
	|
	|INDEX BY
	|	TIN,
	|	ExternalID,
	|	Changed
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Invitation.EDFProfileSettings,
	|	Invitation.TIN AS TIN,
	|	Invitation.KPP,
	|	Invitation.ExternalID AS ExternalID,
	|	MAX(Invitation.Changed) AS Changed
	|INTO RecordsLastChanges
	|FROM
	|	Invitation AS Invitation
	|
	|GROUP BY
	|	Invitation.EDFProfileSettings,
	|	Invitation.TIN,
	|	Invitation.KPP,
	|	Invitation.ExternalID
	|
	|INDEX BY
	|	TIN,
	|	ExternalID,
	|	Changed
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Invitation.EDFProfileSettings,
	|	Invitation.InvitationText,
	|	Invitation.ID,
	|	Invitation.ExternalID,
	|	Invitation.TIN,
	|	Invitation.KPP,
	|	Invitation.Description,
	|	Invitation.Changed AS Changed,
	|	Invitation.ErrorDescription,
	|	Invitation.State AS MemberStatus
	|FROM
	|	RecordsLastChanges AS RecordsLastChanges
	|		INNER JOIN Invitation AS Invitation
	|		ON RecordsLastChanges.EDFProfileSettings = Invitation.EDFProfileSettings
	|			AND RecordsLastChanges.TIN = Invitation.TIN
	|			AND RecordsLastChanges.Changed = Invitation.Changed
	|			AND RecordsLastChanges.ExternalID = Invitation.ExternalID
	|
	|ORDER BY
	|	Changed";
	Query.SetParameter("Invitation", InvitationsTable);
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		LastChangesVT = Result.Unload();
		
		// If an error occurs that is located in
		// the query for counterparty joining, Taxcom returns record with error specification but without KPP. As
		// a result query can return 2 records by one counterparty (TIN and
		// ExternalID match and KPP is empty in one record and filled in in another one). Not to mislead
		// users, one record (the earlier one) should be removed.
		For Ct = -LastChangesVT.Count() + 1 To 0 Do
			VTRow = LastChangesVT[-Ct];
			Filter = New Structure("TIN, ExternalID", VTRow.TIN, VTRow.ExternalID);
			RowArray = LastChangesVT.FindRows(Filter);
			If RowArray.Count() > 1 Then
				FirstItem = RowArray[0];
				SecondItem = RowArray[1];
				If Not ValueIsFilled(FirstItem.KPP) OR Not ValueIsFilled(SecondItem.KPP) Then
					If FirstItem.Changed > SecondItem.Changed Then
						LastChangesVT.Delete(SecondItem);
					Else
						LastChangesVT.Delete(FirstItem);
					EndIf;
				EndIf;
			EndIf;
		EndDo;
		
		MoveDate = True;
		StatusModificationDate = Undefined;
		For Each NewInvitations IN LastChangesVT Do
			Counterparty = Undefined;
			Error = (NewInvitations.MemberStatus = Enums.EDExchangeMemberStatuses.Error);
			If ValueIsFilled(NewInvitations.TIN) Then
				AttributeNameCounterpartyTIN = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyTIN");
				AttributeNameCounterpartyKPP = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyCRR");
				
				Query = New Query;
				QueryText =
				"SELECT ALLOWED
				|	EDFSettings.Counterparty
				|FROM
				|	Catalog.EDUsageAgreements AS EDFSettings
				|WHERE
				|	Not EDFSettings.DeletionMark
				|	AND EDFSettings.Counterparty." + AttributeNameCounterpartyTIN + " = &TIN";
				Query.SetParameter("TIN", NewInvitations.TIN);
				If ValueIsFilled(NewInvitations.KPP) AND AttributeNameCounterpartyKPP <> Undefined Then
					QueryText = QueryText + " AND
					|	EDFSettings.Counterparty." + AttributeNameCounterpartyKPP + " = &KPP";
					Query.SetParameter("KPP", NewInvitations.KPP);
				EndIf;
				Query.Text = QueryText;
				
				Selection = Query.Execute().Select();
				If Selection.Next() Then
					Counterparty = Selection.Counterparty;
				Else
					Counterparty = ElectronicDocumentsOverridable.ObjectRefOnTINKPP("Counterparties", NewInvitations.TIN,
						NewInvitations.KPP);
				EndIf;
			EndIf;
			
			If Counterparty = Undefined Then
				MoveDate = False;
				If Not Error Then
					Text = NStr("en='Exchange by %1 EDF settings profile.
		|Counterparty is
		|not found
		|in base:
		|Name: %2
		|TIN: %3 KPP: %4 Status: %5.';ru='Обмен по профилю настроек ЭДО %1.
		|В
		|базе не
		|найден контрагент:
		|Наименование:
		|%2 ИНН: %3 КПП: %4 Статус: %5.'");
					MessageText = StringFunctionsClientServer.PlaceParametersIntoString(Text, NewInvitations.EDFProfileSettings,
						NewInvitations.Description, NewInvitations.TIN, NewInvitations.KPP, NewInvitations.MemberStatus);
				Else
					ErrorDescription = ?(ValueIsFilled(NewInvitations.ErrorDescription),
						NewInvitations.ErrorDescription, NStr("en='Error';ru='Ошибка'"));
					Description = ?(ValueIsFilled(Counterparty), Counterparty.Description, "");
					Text = NStr("en='Exchange by %1 EDF settings profile.
		|%2 in the
		|invitation for
		|counterparty: Name: %3
		|DS Address:
		|%4 TIN:
		|%5 KPP: %6 Status: %7.';ru='Обмен по профилю настроек ЭДО %1.
		|%2 в
		|приглашении для
		|контрагента: Наименование:
		|%3
		|Адрес ЭП:
		|%4 ИНН: %5 КПП: %6 Статус: %7.'");
					MessageText = StringFunctionsClientServer.PlaceParametersIntoString(Text, NewInvitations.EDFProfileSettings,
						ErrorDescription, Description, NewInvitations.Description, NewInvitations.TIN, NewInvitations.KPP,
						NewInvitations.MemberStatus);
				EndIf;
				CommonUseClientServer.MessageToUser(MessageText);
				Continue;
			EndIf;
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	EDFSettingOutgoingDocuments.Ref AS EDFSetup,
			|	EDFSettingOutgoingDocuments.Ref.AgreementSetupExtendedMode AS ExtendedSettingMode,
			|	EDFSettingOutgoingDocuments.Ref.EDExchangeMethod AS EDExchangeMethod,
			|	EDFSettingOutgoingDocuments.CounterpartyID,
			|	EDFSettingOutgoingDocuments.Ref.ConnectionStatus
			|FROM
			|	Catalog.EDUsageAgreements.OutgoingDocuments AS EDFSettingOutgoingDocuments
			|WHERE
			|	EDFSettingOutgoingDocuments.Ref.Counterparty = &Counterparty
			|	AND EDFSettingOutgoingDocuments.Ref.Company = &Company
			|	AND EDFSettingOutgoingDocuments.CounterpartyID = &CounterpartyID
			|	AND Not EDFSettingOutgoingDocuments.Ref.DeletionMark
			|
			|GROUP BY
			|	EDFSettingOutgoingDocuments.Ref,
			|	EDFSettingOutgoingDocuments.CounterpartyID,
			|	EDFSettingOutgoingDocuments.Ref.EDExchangeMethod,
			|	EDFSettingOutgoingDocuments.Ref.AgreementSetupExtendedMode,
			|	EDFSettingOutgoingDocuments.Ref.ConnectionStatus";
			
			Query.SetParameter("Counterparty",  Counterparty);
			Query.SetParameter("CounterpartyID", NewInvitations.ID);
			Query.SetParameter("Company", NewInvitations.EDFProfileSettings.Company);
			
			If Query.Execute().IsEmpty() Then
				
				Query = New Query;
				Query.Text =
			"SELECT
			|	EDFSettingOutgoingDocuments.Ref AS EDFSetup,
			|	EDFSettingOutgoingDocuments.Ref.AgreementSetupExtendedMode AS ExtendedSettingMode,
			|	EDFSettingOutgoingDocuments.Ref.EDExchangeMethod AS EDExchangeMethod,
			|	EDFSettingOutgoingDocuments.CounterpartyID,
			|	EDFSettingOutgoingDocuments.Ref.ConnectionStatus
			|FROM
			|	Catalog.EDUsageAgreements.OutgoingDocuments AS EDFSettingOutgoingDocuments
			|WHERE
			|	EDFSettingOutgoingDocuments.Ref.Counterparty = &Counterparty
			|	AND EDFSettingOutgoingDocuments.Ref.Company = &Company
			|	AND EDFSettingOutgoingDocuments.CounterpartyID = """"
			|	AND Not EDFSettingOutgoingDocuments.Ref.DeletionMark
			|
			|GROUP BY
			|	EDFSettingOutgoingDocuments.Ref,
			|	EDFSettingOutgoingDocuments.CounterpartyID,
			|	EDFSettingOutgoingDocuments.Ref.EDExchangeMethod,
			|	EDFSettingOutgoingDocuments.Ref.AgreementSetupExtendedMode,
			|	EDFSettingOutgoingDocuments.Ref.ConnectionStatus";
				
				Query.SetParameter("Counterparty",  Counterparty);
				Query.SetParameter("Company", NewInvitations.EDFProfileSettings.Company);
				
			EndIf;
			
			Selection = Query.Execute().Select();
			
			If Selection.Next() Then
				If Selection.ConnectionStatus = NewInvitations.MemberStatus Then
					Continue;
				EndIf;
				
				EDFSetup = Selection.EDFSetup.GetObject();
				
				If Not Selection.ExtendedSettingMode
					AND Selection.EDExchangeMethod <> Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
					
					EDFSetup.AgreementSetupExtendedMode = True;
					
					SettingsProfileParameters = CommonUse.ObjectAttributesValues(NewInvitations.EDFProfileSettings,
						"CompanyID, EDExchangeMethod");
					
					Filter = New Structure;
					Filter.Insert("OutgoingDocument", Enums.EDKinds.CustomerInvoiceNote);
					FoundStrings = EDFSetup.OutgoingDocuments.FindRows(Filter);
					For Each String IN FoundStrings Do
						String.ToForm              = True;
						String.UseDS           = True;
						String.EDFProfileSettings       = NewInvitations.EDFProfileSettings;
						String.EDExchangeMethod           = SettingsProfileParameters.EDExchangeMethod;
						String.CompanyID = SettingsProfileParameters.CompanyID;
						String.CounterpartyID = NewInvitations.ID;
					EndDo;
					
					Filter = New Structure;
					Filter.Insert("OutgoingDocument", Enums.EDKinds.CorrectiveInvoiceNote);
					FoundStrings = EDFSetup.OutgoingDocuments.FindRows(Filter);
					For Each String IN FoundStrings Do
						String.ToForm              = True;
						String.UseDS           = True;
						String.EDFProfileSettings       = NewInvitations.EDFProfileSettings;
						String.EDExchangeMethod           = SettingsProfileParameters.EDExchangeMethod;
						String.CompanyID = SettingsProfileParameters.CompanyID;
						String.CounterpartyID = NewInvitations.ID;
					EndDo;
				Else
					Filter = New Structure;
					Filter.Insert("EDFProfileSettings", NewInvitations.EDFProfileSettings);
					FoundStrings = EDFSetup.OutgoingDocuments.FindRows(Filter);
					For Each String IN FoundStrings Do
						String.CounterpartyID = NewInvitations.ID;
					EndDo;
				EndIf;
			Else
				EDFSetup = Catalogs.EDUsageAgreements.CreateItem();
				// Always write new EDF settings by incoming invitations even if they are not unique.
				EDFSetup.DataExchange.Load = True;
				
				EDFSetup.Counterparty = Counterparty;
				EDFSetup.Description = String(Counterparty);
				
				EDFSetup.EDFProfileSettings = NewInvitations.EDFProfileSettings;
				SettingsProfileParameters = CommonUse.ObjectAttributesValues(NewInvitations.EDFProfileSettings,
					"Company, CompanyID, EDExchangeMethod, InvitationsTextTemplate, OutgoingDocuments");
				
				EDFSetup.Company                 = SettingsProfileParameters.Company;
				EDFSetup.EDExchangeMethod              = SettingsProfileParameters.EDExchangeMethod;
				EDFSetup.CompanyID    = SettingsProfileParameters.CompanyID;
				
				// Importing PM from the EDF settings profile.
				EDSourceTable = SettingsProfileParameters.OutgoingDocuments.Unload();
				EDSourceTable.Columns.Add("EDFProfileSettings");
				EDSourceTable.Columns.Add("EDExchangeMethod");
				EDSourceTable.Columns.Add("CompanyID");
				EDSourceTable.Columns.Add("CounterpartyID");

				EDSourceTable.FillValues(NewInvitations.EDFProfileSettings, "EDFProfileSettings");
				EDSourceTable.FillValues(SettingsProfileParameters.EDExchangeMethod, "EDExchangeMethod");
				EDSourceTable.FillValues(SettingsProfileParameters.CompanyID, "CompanyID");
				EDSourceTable.FillValues(NewInvitations.ID, "CounterpartyID");
				
				EDFSetup.OutgoingDocuments.Load(EDSourceTable);
				
				For Each EnumValue IN Enums.EDExchangeFileFormats Do
					If EnumValue = Enums.EDExchangeFileFormats.CompoundFormat Then
						Continue;
					EndIf;
					RowArray = EDFSetup.ExchangeFilesFormats.FindRows(New Structure("FileFormat", EnumValue));
					If RowArray.Count() = 0 Then
						NewRow = EDFSetup.ExchangeFilesFormats.Add();
						NewRow.FileFormat  = EnumValue;
						// Default value for the new EDF Setting
						If EnumValue = Enums.EDExchangeFileFormats.XML AND EDFSetup.Ref.IsEmpty() Then
							NewRow.Use = True;
						EndIf;
					EndIf;
				EndDo;
				
			EndIf;
			
			EDFSetup.CounterpartyID    = NewInvitations.ID;
			If ValueIsFilled(NewInvitations.InvitationText) Then
				EDFSetup.InvitationText        = NewInvitations.InvitationText;
			EndIf;
			
			EDFSetup.ConnectionStatus           = NewInvitations.MemberStatus;
			
			AgreementState                      = Enums.EDAgreementStates.CoordinationExpected;
			If NewInvitations.MemberStatus = Enums.EDExchangeMemberStatuses.Connected Then
				AgreementState                  = Enums.EDAgreementStates.CheckingTechnicalCompatibility;
				
				// Check whether there is an attached setting by this counterparty.
				Query = New Query;
				Query.Text =
				"SELECT
				|	EDFSettingOutgoingDocuments.Ref AS EDFSetup
				|FROM
				|	Catalog.EDUsageAgreements.OutgoingDocuments AS EDFSettingOutgoingDocuments
				|WHERE
				|	EDFSettingOutgoingDocuments.Ref.Counterparty = &Counterparty
				|	AND EDFSettingOutgoingDocuments.Ref.Company = &Company
				|	AND EDFSettingOutgoingDocuments.Ref.ConnectionStatus = VALUE(Enum.EDExchangeMemberStatuses.Connected)
				|	AND Not EDFSettingOutgoingDocuments.Ref.DeletionMark
				|
				|GROUP BY
				|	EDFSettingOutgoingDocuments.Ref";
				
				Query.SetParameter("Counterparty",  Counterparty);
				Query.SetParameter("Company", NewInvitations.EDFProfileSettings.Company);
				Selection = Query.Execute().Select();
				If Selection.Next() Then
					EDFSetup.DataExchange.Load = True;
					EDFSetup.ConnectionStatus     = Enums.EDExchangeMemberStatuses.ApprovalRequired;
					EDFSetup.Comment           = NStr("en='##Status ""attached"" is automatically cleared. EDF setting by the selected counterparty already exists.';ru='##Автоматически снят статус ""присоединен"". Уже существует настройка ЭДО по выбранному контрагенту.'");
				EndIf;
				
			ElsIf NewInvitations.MemberStatus = Enums.EDExchangeMemberStatuses.Disconnected Then
				AgreementState                  = Enums.EDAgreementStates.Closed;
			EndIf;
			EDFSetup.AgreementState = AgreementState;
			
			ErrorDescriptionText = "";
			If Error Then
				ErrorDescriptionTemplate = NStr("en='%1. Send again.';ru='%1. Повторите отправку.'");
				ErrorDescriptionText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorDescriptionTemplate,
					NewInvitations.ErrorDescription);
			EndIf;
			EDFSetup.ErrorDescription = ErrorDescriptionText;
			
			EDFSetup.Write();
			
			If MoveDate Then
				Record = InformationRegisters.EDExchangeStatesThroughEDFOperators.CreateRecordManager();
				Record.EDFProfileSettings = NewInvitations.EDFProfileSettings;
				Record.Read();
				Record.LastInvitationsDateReceived = NewInvitations.Changed;
				Record.Write();
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Write events to the events log monitor. Errors processor

// This procedure is used to standardize all records of
// the ElectronicInteraction subsystem events to the events log monitor. Records grouping with hierarchy is added to the events log monitor as a result:
//  Electronic
//  interaction
//  |_Error_|_ Common subsystem
//  |_ Exchange with banks
//  |_ Exchange with counterparties
//  |_ Exchange with
//  websites |_ Scheduled jobs
//  |_ Information
//  |_ Common subsystem |_
//  Exchange with banks |_Exchange
//  with counterparties
//  |_ Exchange with websites |_
//  Scheduled jobs
//
// Parameters:
//   DetailsEvents - String - description of event content that is required to be written to the events log monitor.
//   EventCode - Number - event code, it is used to standardize events hierarchy.
//               Can take values: 0 - General subsystem, 1 - Exchange with banks, 2 - Exchange with counterparties.
//                                         3 - Exchange with websites, 4 - Scheduled
//   jobs ImportanceLevel - EventLogLevel - one of the available events log monitor levels (Error, Information, ...).
//   MetadataObject - MetadataObject - metadata object to which event corresponds.
//   DataRef - Arbitrary - data to which event is connected. It is recommended to specify
//                  refs to data objects (catalog items, documents to which event corresponds).
//   TransactionMode - EventLogEntryTransactionMode - specifies record relation to the current transaction.
//
Procedure WriteEventOnEDToEventLogMonitor(DetailsEvents,
														EventCode = 0,
														ImportanceLevel = Undefined,
														MetadataObject = Undefined,
														DataRef = Undefined,
														TransactionMode = Undefined) Export
	
	Level = "General subsystem";
	If EventCode = 1 Then
		Level = "Exchange with banks";
	ElsIf EventCode = 2 Then
		Level = "Exchange with counterparties";
	ElsIf EventCode = 3 Then
		Level = "Exchange with sites";
	ElsIf EventCode = 4 Then
		Level = "Scheduled jobs";
	EndIf;
	EventImportanceLevel = ?(TypeOf(ImportanceLevel) = Type("EventLogLevel"),
		ImportanceLevel, EventLogLevel.Error);
	Pattern = NStr("en='Electronic interaction.%1';ru='Электронное взаимодействие.%1'");
	EventName = StrReplace(Pattern, "%1", Level);
	WriteLogEvent(EventName,
		EventImportanceLevel, MetadataObject, DataRef, DetailsEvents, TransactionMode);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// File operations

// For internal use only
Function GetFileStructure(String) Export
	
	FileName = CorrectFileName(String, True);
	File = New File(FileName);
	
	Return New Structure("BaseName, Extension", File.BaseName, StrReplace(File.Extension, ".",""));
	
EndFunction

// For internal use only
Function FTSFileName(NameStructure) Export
	
	FileName = NameStructure.Prefix + "_" + NameStructure.RecipientID + "_"
		+ NameStructure.SenderID + "_" + NameStructure.YYYYMMDD + "_" + NameStructure.UUID;
	
	Return FileName;
	
EndFunction

// For internal use only
Function TemporaryFileCurrentName(Extension = "") Export
	
	TempFileName = "";
	ElectronicDocumentsOverridable.TemporaryFileCurrentName(TempFileName, Extension);
	If Not ValueIsFilled(TempFileName) Then
		TempFileName = GetTempFileName(Extension);
	EndIf;
	
	Return TempFileName;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// User message

// Outputs user message on access rights shortage.
Procedure MessageToUserAboutViolationOfRightOfAccess() Export
	
	MessageText = NStr("en='Access violation';ru='Нарушение прав доступа'");
	ElectronicDocumentsOverridable.PrepareMessageTextAboutAccessRightsViolation(MessageText);
	CommonUseClientServer.MessageToUser(MessageText);
	
EndProcedure

// For internal use only
Procedure InformAboutEDAgreementMissing(EDParameters, Source) Export
	
	If Not ElectronicDocumentsOverridable.CheckFillingObjectCorrectness(EDParameters) Then
		Return;
	EndIf;
	
	MessagePattern = NStr("en='Processor %1.
		|The operation failed.
		|You should create ""EDF setting"" with attributes:';ru='Обработка %1.
		|Операция не выполнена!
		|Необходимо создать ""Настройку ЭДО"" с реквизитами:'");
	
	Text = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, Source);
	
	ParameterTable = New ValueTable();
	ParameterTable.Columns.Add("Key");
	ParameterTable.Columns.Add("Value");
	ParameterTable.Columns.Add("Order");
	
	IsCustomerInvoiceNote = False;
	If EDParameters.Property("IsCustomerInvoiceNote") AND ValueIsFilled(EDParameters.IsCustomerInvoiceNote) Then
		IsCustomerInvoiceNote = EDParameters.IsCustomerInvoiceNote;
	EndIf;
	
	IsPaymentOrder = False;
	If EDParameters.Property("EDKind") AND EDParameters.EDKind = Enums.EDKinds.PaymentOrder Then
		IsPaymentOrder = True;
	EndIf;
	
	For Each CurParameter IN EDParameters Do
		
		If IsPaymentOrder AND (CurParameter.Key = "CounterpartyContract"
										OR CurParameter.Key = "EDDirection"
										OR CurParameter.Key = "EDDirection"
										OR CurParameter.Key = "EDKind") Then
			Continue;
		EndIf;
		
		Order = 0;
		If Lower(CurParameter.Key) = Lower("Company") Then
			Order = 1;
		ElsIf Lower(CurParameter.Key) = Lower("Partner") AND Not IsCustomerInvoiceNote Then
			Order = 2;
		ElsIf Lower(CurParameter.Key) = Lower("Counterparty") Then
			Order = 3;
		ElsIf Lower(CurParameter.Key) = Lower("CounterpartyContract") Then
			Order = 4;
		ElsIf Lower(CurParameter.Key) = Lower("EDDirection") AND Not IsCustomerInvoiceNote Then
			Order = 5;
		ElsIf Lower(CurParameter.Key) = Lower("EDKind") AND Not IsCustomerInvoiceNote Then
			Order = 6;
		ElsIf Lower(CurParameter.Key) = Lower("IsCustomerInvoiceNote") AND IsCustomerInvoiceNote Then
			Order = 0.5;
		EndIf;
		
		If Order > 0 Then
			ParameterString = ParameterTable.Add();
			FillPropertyValues(ParameterString, CurParameter);
			If IsCustomerInvoiceNote Then
				If Lower(CurParameter.Key) = Lower("IsCustomerInvoiceNote") Then
					ParameterString.Key = "Exchange method";
					ParameterString.Value = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom;
				ElsIf Lower(CurParameter.Key) = Lower("Counterparty") Then
					ParameterString.Key = "Participant";
				EndIf;
			ElsIf EDParameters.EDKind = Enums.EDKinds.PaymentOrder Then
				If CurParameter.Key = "Counterparty" Then
					ParameterString.Key = "Bank";
				EndIf;
			ElsIf EDParameters.EDDirection = Enums.EDDirections.Intercompany Then
				If CurParameter.Key = "Company" Then
					ParameterString.Key = "Company-sender";
				ElsIf CurParameter.Key = "Counterparty" Then
					ParameterString.Key = "Company-recipient";
				EndIf;
			EndIf;
			ParameterString.Order = Order;
		EndIf;
	EndDo;
	
	ParameterTable.Sort("Order");
	For Each ParameterString IN ParameterTable Do
		If ValueIsFilled(ParameterString.Value) Then
			Text = Text + Chars.LF + NStr("en='<%1>: %2';ru='<%1>: %2'");
			Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, ParameterString.Key, ParameterString.Value);
		EndIf;
	EndDo;
	
	CommonUseClientServer.MessageToUser(Text);
	
EndProcedure

Procedure SendPackageThroughBankResource(Settings, Data, Result, ErrorText) Export

	Join = GetConnection(Settings.Address);
	
	ResultFileName = GetTempFileName();
	
	Headers = New Map;
	Headers.Insert("User-Agent", "1C:Enterprise/8");
	Headers.Insert("Content-Type", "application/xml; charset=utf-8");
	
	If Settings.Property("Hash") Then
		Headers.Insert("Authorization", "Basic " + Settings.Hash);
	EndIf;
	
	If Settings.Property("SessionID") Then
		Headers.Insert("SID", Settings.SessionID);
	EndIf;
	
	If Settings.Property("CompanyID") Then
		Headers.Insert("CustomerID", Settings.CompanyID);
	EndIf;
	
	HTTPRequest = New HTTPRequest(Settings.Resource, Headers);
	HTTPRequest.SetBodyFileName(Data);
	
	Response = Join.Post(HTTPRequest, ResultFileName);
	HTTPRequest = Undefined;
	DeleteFiles(Data);
	ResultFile = New TextDocument;
	ResultFile.Read(ResultFileName, TextEncoding.UTF8);
	DeleteFiles(ResultFileName);
	Result = ResultFile.GetText();
	
	If Response.StateCode <> 200 Then
		Pattern = NStr("en='An error occurred while working with the Internet (%1)%2';ru='Ошибка работы с Интернет (%1)%2'");
		If Response.StateCode = 401 Then
			Details = NStr("en=': Access is allowed only for the authenticated users.
		|Check whether login and password are specified correctly.';ru=': Доступ разрешен только для пользователей, прошедших аутентификацию.
		|Проверьте правильность указания логина и пароля.'");
		ElsIf Response.StateCode = 500 Then
			Details = NStr("en=': Internal server error';ru=': Внутренняя ошибка сервера'");
		Else
			Details = "";
		EndIf;
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(Pattern, Response.StateCode, Details);
	EndIf;
	
EndProcedure

// For internal use only
Function GetConnection(ServerAddress) Export
	
	Address = "";
	SecureConnection = False;
	Protocol = "";
	
	DetermineSiteParameters(ServerAddress, SecureConnection, Address, Protocol);
	Proxy = GenerateProxy(Protocol);
	
	If SecureConnection Then
		SecureConnection = New OpenSSLSecureConnection();
		Join = New HTTPConnection(Address, , , ,Proxy, 60, SecureConnection);
	Else
		Join = New HTTPConnection(Address, , , ,Proxy, 60);
	EndIf;

	Return Join;

EndFunction

// For internal use only
Function GetDataFromBankResponse(BankResponse) Export
	
	FileContent = New Map;
	Read = New XMLReader;
	Read.SetString(BankResponse);
		
	URI = "urn:x-obml:1.0";
	Try
		Message = XDTOFactory.ReadXML(Read, XDTOFactory.Type(URI, "CMSDETACHED"));
		FileContent.Insert("Data", Message.data.__content);
		Signatures = New Array;
		For Each Signature IN Message.signature Do
			Signatures.Add(Signature);
		EndDo;
		FileContent.Insert("Signatures", Signatures);
	Except
		TempFile = GetTempFileName();
		TextDocument = New TextDocument;
		TextDocument.SetText(BankResponse);
		TextDocument.Write(TempFile);
		BinaryData = New BinaryData(TempFile);
		FileContent.Insert("Data", BinaryData);
		DeleteFiles(TempFile);
	EndTry;
		
	Return FileContent;

EndFunction

// For internal use only
Procedure ProcessBankResponse(BankResponse, ED, NewED = Undefined, IsError = Undefined) Export
	
	ResponseData = GetDataFromBankResponse(BankResponse);
	IsError = False;
	DataFile = GetTempFileName();
	Message = ResponseData.Get("Data");
	EDAttributes = CommonUse.ObjectAttributesValues(ED, "Company, EDAgreement, EDKind");
	EDKind = EDAttributes.EDKind;
	Message.Write(DataFile);
	XMLReader = New XMLReader;
	XMLReader.OpenFile(DataFile);
	If XMLReader.Read() AND XMLReader.NodeType = XMLNodeType.StartElement
		AND (XMLReader.LocalName = "success" OR XMLReader.LocalName = "error") Then
		XMLReader.OpenFile(DataFile);
		While XMLReader.Read() Do
			If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.LocalName = "success" Then
				XMLReader.Read();
				XMLReader.Read();
				ParametersStructure = New Structure;
				ParametersStructure.Insert("UUIDExternal", XMLReader.Value);
				ParametersStructure.Insert("EDStatus", Enums.EDStatuses.Delivered);
				AdditionalAttributes = New Structure("ReceiptDateInBank", CurrentSessionDate());
				ParametersStructure.Insert("AdditionalAttributes", AdditionalAttributes);
				ChangeByRefAttachedFile(ED, ParametersStructure, False);
				Break;
			ElsIf XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.LocalName = "error" Then
				XMLReader.Read();
				XMLReader.Read();
				ErrorCode = XMLReader.Value;
				XMLReader.Read();
				XMLReader.Read();
				XMLReader.Read();
				ErrorDescription = XMLReader.Value;
				ErrorText = ElectronicDocumentsServiceCallServer.GetMessageAboutError(ErrorCode, ErrorDescription);
				ParametersStructure = New Structure;
				ParametersStructure.Insert("RejectionReason", ErrorText);
				ParametersStructure.Insert("EDStatus", Enums.EDStatuses.RejectedByBank);
				ChangeByRefAttachedFile(ED, ParametersStructure, False);
				If EDKind = Enums.EDKinds.QueryStatement Then
					CommonUseClientServer.MessageToUser(ErrorText);
				EndIf;
				IsError = True;
				Break;
			EndIf;
		EndDo;
	Else
		FileURL = PutToTempStorage(Message);
		QueryDescription = ED.Description;
		StatementName = StrReplace(QueryDescription, NStr("en='Query statement';ru='Запрос выписки'"), NStr("en='Bank statement for period';ru='Выписка банка за период'"));
		AddedFile = AttachedFiles.AddFile(EDAttributes.EDAgreement, StatementName, "xml", CurrentSessionDate(),
			CurrentSessionDate(), FileURL, , , Catalogs.EDAttachedFiles.GetRef());
		If ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer() Then
			Signatures = ResponseData.Get("Signatures");
			CryptoManager = ElectronicDocumentsServiceCallServer.GetCryptoManager(IsError);
			If IsError Then
				MessageText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("110");
				ErrorText = DetailErrorDescription(ErrorInfo());
				Operation = NStr("en='Cryptofacility initializing on the server';ru='Инициализация криптосредства на сервере'");
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation,
																							ErrorText,
																							MessageText,
																							1);
				CryptographyManagerConnected = False;
			EndIf;

			If CryptographyManagerConnected Then
			
				For Each Signature IN Signatures Do
					SignatureCertificates = CryptoManager.GetCertificatesFromSignature(Signature);
					If SignatureCertificates.Count() > 0 Then
						Certificate = SignatureCertificates[0];
					Else
						Continue;
					EndIf;
					UserPresentation = DigitalSignatureClientServer.SubjectPresentation(Certificate);
					Imprint = Base64String(Certificate.Imprint);
					CertificateBinaryData = Certificate.Unload();
					SignatureInstallationDate = SignatureInstallationDate(Signature);
					SignatureInstallationDate = ?(ValueIsFilled(SignatureInstallationDate), SignatureInstallationDate, CurrentSessionDate());
					ElectronicDocumentsServiceCallServer.AddInformationAboutSignature(
												AddedFile,
												Signature,
												Imprint,
												SignatureInstallationDate,
												"",
												,
												UserPresentation,
												CertificateBinaryData);
				EndDo;
				ElectronicDocumentsServiceCallServer.DetermineSignaturesStatuses(AddedFile, True);
			EndIf;
		EndIf;
		
		Counterparty = CommonUse.ObjectAttributeValue(EDAttributes.EDAgreement, "Counterparty");
		Responsible = ElectronicDocumentsOverridable.GetResponsibleByED(Counterparty,
																						EDAttributes.EDAgreement);
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("Author",                       Users.AuthorizedUser());
		ParametersStructure.Insert("EDStatus",                    Enums.EDStatuses.Received);
		ParametersStructure.Insert("EDDirection",               Enums.EDDirections.Incoming);
		ParametersStructure.Insert("EDKind",                       Enums.EDKinds.BankStatement);
		ParametersStructure.Insert("Responsible",               Responsible);
		ParametersStructure.Insert("Company",                 EDAttributes.Company);
		ParametersStructure.Insert("EDAgreement",                EDAttributes.EDAgreement);
		ParametersStructure.Insert("Counterparty",                  Counterparty);
		ParametersStructure.Insert("SenderDocumentDate",    CurrentSessionDate());
		ParametersStructure.Insert("ElectronicDocumentOwner", ED);
		ParametersStructure.Insert("EDOwner",                  EDAttributes.EDAgreement);
		FileDescription = StrReplace(QueryDescription, NStr("en='Query statement';ru='Запрос выписки'"), NStr("en='Bank statement for period';ru='Выписка банка за период'"));
		FileDescriptionInLatin = StringFunctionsClientServer.StringInLatin(FileDescription);
		ParametersStructure.Insert("FileDescription",           FileDescriptionInLatin);
		
		ChangeByRefAttachedFile(AddedFile, ParametersStructure);
		
		ElectronicDocumentsServiceCallServer.DeterminePerformedPaymentOrders(AddedFile);
		NewED = AddedFile;
	EndIf;
	XMLReader.Close();
	
	DeleteFiles(DataFile);

EndProcedure

// Collects pack with statement query and sends it to bank. Receives bank statement as a response.
//
// Parameters:
//  ParametersStructure - structure, contains
//      2 ED items - CatalogRef.EDAttachedFiles - electronic document with
//      statement request, EDAgreement - CatalogRef.EDUsageAgreements - agreement
//  StorageAddress - String, contains storage address containing structure from 2 items:
//      QueryPosted - Boolean, shows that query
//      was sent BankStatement - CatalogRef.EDAttachedFiles - electronic document with
//  bank statement HasError - Boolean - shows that error information is received from bank
//
Procedure SendStatementRequestToBank(ParametersStructure, StorageAddress) Export
	
	Var BankStatement;
	EDAgreement = ParametersStructure.EDAgreement;
	BankApplication = CommonUse.ObjectAttributeValue(EDAgreement, "BankApplication");
	ReturnStructure = New Structure;
	
	If BankApplication = Enums.BankApplications.AsynchronousExchange Then
		RequestBankStatementAsynchronously(ParametersStructure, StorageAddress);
		Return;
	EndIf;
	
	EDKindsArray = ParametersStructure.EDKindsArray;
	ED = EDKindsArray[0];
	
	QueryPosted = False;
	
	AgreementAttributes = CommonUse.ObjectAttributesValues(EDAgreement,
		"ServerAddress, OutgoingDocumentsResource, IncomingDocumentsResource, BankApplication");
	Settings = New Structure("Address", AgreementAttributes.ServerAddress);
	SentCnt = 0;
	
	Data = AttachedFiles.GetFileBinaryData(ED);
	URI = "urn:x-obml:1.0";
	TypeMessage = XDTOFactory.Type("urn:x-obml:1.0", "CMSDETACHED");
	Message = XDTOFactory.Create(TypeMessage);
	TypeData = TypeMessage.Properties[0].Type;
	Data = XDTOFactory.Create(TypeData);
	Data.ContentType = "application/xml";
	Data.__content = Data;
	Message.data = Data;
	
	SignaturesArray = GetAllSignatures(ED, New UUID);
	
	For Each SignatureRow IN SignaturesArray Do
		Message.signature.Add(GetFromTempStorage(SignatureRow.SignatureAddress));
	EndDo;
	
	PathToSendingFile = GetTempFileName();
	Record = New XMLWriter;
	Record.OpenFile(PathToSendingFile);
	Record.WriteXMLDeclaration();

	XDTOFactory.WriteXML(Record, Message, "signed", URI, , XMLTypeAssignment.Explicit);
	
	Record.Close();
	
	Settings.Insert("Resource", AgreementAttributes.IncomingDocumentsResource);
	
	If ValueIsFilled(ParametersStructure.User) Then
		HASH = ElectronicDocumentsServiceCallServer.Base64StringWithoutBOM(
			ParametersStructure.User + ":" + ParametersStructure.Password);
		Settings.Insert("HASH", HASH);
	EndIf;
	
	OperationKind = NStr("en='Sending statement query to the bank';ru='Отправка запроса выписки в банк'");
	
	Try
		BankResponse = "";
		ErrorText = "";
		SendPackageThroughBankResource(Settings, PathToSendingFile, BankResponse, ErrorText);
		
		If Not IsBlankString(ErrorText) Then
			MessageText = ErrorText;
			ProcessBankPackSendingError(ED, OperationKind, ErrorText, MessageText);
			IsError = True;
		Else
			ParametersStructure = New Structure;
			ParametersStructure.Insert("EDStatus", Enums.EDStatuses.Sent);
			ChangeByRefAttachedFile(ED, ParametersStructure, False);
			QueryPosted = True;
			ProcessBankResponse(BankResponse, ED, BankStatement, IsError);
			ResponseData = GetDataFromBankResponse(BankResponse);
			ReturnStructure.Insert("Signatures", ResponseData.Get("Signatures"));
		EndIf;
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		MessageText = NStr("en='An error occurred while sending statement, for more information, see Events log monitor.';ru='При отправке запроса выписки произошла ошибка, подробности см. в Журнале регистрации.'");
		ProcessBankPackSendingError(ED, OperationKind, ErrorText, MessageText);
		IsError = True;
	EndTry;
	DeleteFiles(PathToSendingFile);
	ReturnStructure.Insert("QueryPosted", QueryPosted);
	ReturnStructure.Insert("BankStatement", BankStatement);
	ReturnStructure.Insert("IsError", IsError);
	ReturnStructure.Insert("MessageText", MessageText);

	PutToTempStorage(ReturnStructure, StorageAddress);
	
EndProcedure


// Handler of the passing pack to bank error
//
// Parameters:
//  ED - CatalogRef.EDAttachedFiles - electronic document
//  sent to bank OperationKind - String - executed operation
//  description ErrorText - String - error string for writing to
//  the events log monitor MessageText - String - message output to a user
//
Procedure ProcessBankPackSendingError(ED, OperationKind, ErrorText, MessageText) Export
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("EDStatus", Enums.EDStatuses.TransferError);
	ParametersStructure.Insert("RejectionReason", ErrorText);
	ChangeByRefAttachedFile(ED, ParametersStructure, False);
	
	ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
									OperationKind, ErrorText, MessageText, 1);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Electronic documents comparison

// Prepares MXL tabular document files by electronic documents data.
//
// Parameters:
//  EDKindsArray - array of references to electronic documents that should be processed.
//
// Returns:
//  Array of structures - structure contains data attachment file name and MXL tabular document attachment file name
//
Function PrepareEDViewTemporaryFiles(EDKindsArray) Export
	
	SetPrivilegedMode(True);
	
	TemporaryFilesList = New Array;
	
	For Each ED IN EDKindsArray Do
		
		AdditInformationAboutED = GetFileData(ED, New UUID, True);
		If AdditInformationAboutED.Property("FileBinaryDataRef")
			AND ValueIsFilled(AdditInformationAboutED.FileBinaryDataRef) Then
			
			EDData = GetFromTempStorage(AdditInformationAboutED.FileBinaryDataRef);
			If ValueIsFilled(AdditInformationAboutED.Extension) Then
				FileName = TemporaryFileCurrentName(AdditInformationAboutED.Extension);
			Else
				FileName = TemporaryFileCurrentName("xml");
			EndIf;
			
			EDData.Write(FileName);
			
			If Find(AdditInformationAboutED.Extension, "zip") > 0 Then
				
				ZIPReading = New ZipFileReader(FileName);
				FolderForUnpacking =  WorkingDirectory("Proc", ED.UUID());
				
				Try
					ZipReading.ExtractAll(FolderForUnpacking);
				Except
					ErrorText = BriefErrorDescription(ErrorInfo());
					If Not PossibleToExtractFiles(ZipReading, FolderForUnpacking) Then
						MessageText = ElectronicDocumentsReUse.GetMessageAboutError("006");
					EndIf;
					ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='ED package Unpacking';ru='распаковка пакета ЭД'"),
						ErrorText, MessageText);
					ZIPReading.Close();
					DeleteFiles(FileName);
					DeleteFiles(FolderForUnpacking);
					Return Undefined;
				EndTry;

				ArchiveFiles = FindFiles(FolderForUnpacking, "*.xml");
			ElsIf Find(AdditInformationAboutED.Extension, "xml") > 0 Then
				
				DataFile = New File(FileName);
				
				ArchiveFiles = New Array;
				ArchiveFiles.Add(DataFile);
			Else
				DeleteFiles(FileName);
				Return Undefined;
			EndIf;
			DeleteFiles(FileName);
			For Each UnpackedFile IN ArchiveFiles Do
				SpreadsheetDocument = ElectronicDocumentsInternal.GenerateEDPrintForm(UnpackedFile.FullName,
																								 ED.EDDirection,
																								 ED.UUID());
					
				If TypeOf(SpreadsheetDocument) = Type("SpreadsheetDocument") Then
					DataFileAddress = PutToTempStorage(SpreadsheetDocument, ED.UUID());
					EDName = GetEDPresentation(ED.Ref);
				Else
					Return Undefined;
				EndIf;
				
				FileNamesStructure = New Structure("EDName, DataFileAddress", EDName, DataFileAddress);
				TemporaryFilesList.Add(FileNamesStructure);
				Break; // should contain only one data file
			EndDo;
			If ValueIsFilled(FolderForUnpacking) Then
				DeleteFiles(FolderForUnpacking);
			EndIf;
		EndIf;
	EndDo;

	Return TemporaryFilesList;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other

// For internal use only
Function EDExchangeSettings(LinkToED) Export
	
	ExchangeSettings = Undefined;
	
	If ValueIsFilled(LinkToED) Then
		If TypeOf(LinkToED) = Type("DocumentRef.RandomED") Then
			EDAttributes = DetermineEDExchangeSettingsBySource(LinkToED);
		Else
			EDAttributes = CommonUse.ObjectAttributesValues(LinkToED,
				"EDKind, EDDirection, EDAgreement, EDFProfileSettings, EDFScheduleVersion");
		EndIf;
		If ValueIsFilled(EDAttributes) Then
			ExchangeSettings = New Structure;
			
			EDExchangeMethod = CommonUse.ObjectAttributeValue(EDAttributes.EDAgreement, "EDExchangeMethod");
			If EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource Then
				
				AgreementAttributes = CommonUse.ObjectAttributesValues(EDAttributes.EDAgreement,
					"EDExchangeMethod, CompanySignatureCertificates, BankApplication");
				ExchangeSettings.Insert("ExchangeMethod",          AgreementAttributes.EDExchangeMethod);
				ExchangeSettings.Insert("BankApplication",        AgreementAttributes.BankApplication);
				UsedFewSignatures = False;
				
				If ValueIsFilled(AgreementAttributes.CompanySignatureCertificates) Then
					UsedFewSignatures = AgreementAttributes.CompanySignatureCertificates.Unload().Count() > 1;
				EndIf;
				
				ExchangeSettings.Insert("UsedFewSignatures", UsedFewSignatures);
				
			Else
				
				EDFProfileSettingsAttributes = CommonUse.ObjectAttributesValues(EDAttributes.EDFProfileSettings,
				"EDExchangeMethod");
				
				ExchangeSettings.Insert("ExchangeMethod",          EDFProfileSettingsAttributes.EDExchangeMethod);
			EndIf;
			
			ExchangeSettings.Insert("Direction",           EDAttributes.EDDirection);
			ExchangeSettings.Insert("EDKind",                 EDAttributes.EDKind);
			ExchangeSettings.Insert("UseSignature",   True);
			ExchangeSettings.Insert("UseReceipt", False);
			ExchangeSettings.Insert("EDFScheduleVersion",   EDAttributes.EDFScheduleVersion); 
			
			EDAgreement = EDAttributes.EDAgreement;
			PackageFormatVersion = EDPackageVersion(LinkToED);
			
			ExchangeSettings.Insert("PackageFormatVersion", PackageFormatVersion);
			
			QueryBySettings = New Query;
			QueryBySettings.SetParameter("EDAgreement",    EDAttributes.EDAgreement);
			QueryBySettings.SetParameter("EDDirection",   EDAttributes.EDDirection);
			QueryBySettings.SetParameter("EDKind",           EDAttributes.EDKind);
			UseDS = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
			"UseDigitalSignatures");
			IsExchangeWithBank = EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource;
			QueryBySettings.SetParameter("DSUsed", UseDS OR IsExchangeWithBank);
			
			EDFTSKinds = New Array;
			EDFTSKinds.Add(Enums.EDKinds.TORG12Seller);
			EDFTSKinds.Add(Enums.EDKinds.ActCustomer);
			EDFTSKinds.Add(Enums.EDKinds.AgreementAboutCostChangeSender);
			QueryBySettings.SetParameter("EDFTSKinds", EDFTSKinds);
			
			QueryBySettings.Text =
			"SELECT
			|	CASE
			|		WHEN &DSUsed
			|			THEN Agreement.UseSignature
			|		ELSE FALSE
			|	END AS UseSignature,
			|	Agreement.UseReceipt
			|FROM
			|	(SELECT
			|		EDUsageAgreementsOutgoingDocuments.UseDS AS UseSignature,
			|		CASE
			|			WHEN EDUsageAgreementsOutgoingDocuments.Ref.PackageFormatVersion = VALUE(Enum.EDPackageFormatVersions.Version30)
			|				THEN FALSE
			|			ELSE TRUE
			|		END AS UseReceipt,
			|		CASE
			|			WHEN &EDDirection = VALUE(Enum.EDDirections.Intercompany)
			|				THEN VALUE(Enum.EDDirections.Intercompany)
			|			ELSE CASE
			|					WHEN &EDKind IN (&EDFTSKinds)
			|							AND &EDDirection = VALUE(Enum.EDDirections.Incoming)
			|						THEN VALUE(Enum.EDDirections.Incoming)
			|					ELSE VALUE(Enum.EDDirections.Outgoing)
			|				END
			|		END AS EDDirection
			|	FROM
			|		Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
			|	WHERE
			|		EDUsageAgreementsOutgoingDocuments.OutgoingDocument = &EDKind
			|		AND EDUsageAgreementsOutgoingDocuments.Ref = &EDAgreement
			|		AND EDUsageAgreementsOutgoingDocuments.ToForm) AS Agreement
			|WHERE
			|	Agreement.EDDirection = &EDDirection";
			
			Result = QueryBySettings.Execute();
			
			If Not Result.IsEmpty() Then
				VT = Result.Unload();
				FillPropertyValues(ExchangeSettings, VT[0]);
			EndIf;
		EndIf;
	EndIf;
	
	Return ExchangeSettings;
	
EndFunction

// For internal use only
Function SelectionAdditDataED(EDOwner) Export
	
	// For one ED one ED-addit can be generated.data.
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	EDAttachedFiles.Ref
		|FROM
		|	Catalog.EDAttachedFiles AS EDAttachedFiles
		|WHERE
		|	EDAttachedFiles.ElectronicDocumentOwner = &ElectronicDocumentOwner
		|	AND EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.AddData)";

	Query.SetParameter("ElectronicDocumentOwner", EDOwner);

	Return Query.Execute().Select();
	
EndFunction

// For internal use only
Procedure SaveEDAdditDataFiles(AttachedFile, DirectoryName, StructureFilesED) Export
	
	If ValueIsFilled(AttachedFile) Then
		// For one ED one ED-addit can be generated.data.
		Selection = SelectionAdditDataED(AttachedFile);

		If Selection.Next() Then
			File = New File(DirectoryName);
			If Not File.Exist() Then
				CreateDirectory(DirectoryName);
			EndIf;
			FileData = GetFileData(Selection.Ref);
			ReceivedFileName = StrReplace(FileData.FileName, "..", ".");
			FileBinaryData = GetFromTempStorage(FileData.FileBinaryDataRef);
			FileBinaryData.Write(DirectoryName + ReceivedFileName);
		
			StructureFilesED.Insert("AdditionalFile", ReceivedFileName);
			
			// It is required to consider filling signatures for an additional file in the transport information tree.
		EndIf;
	EndIf;
	
EndProcedure

// Function is designed to check whether attachment file name contains
// incorrect characters Algorithm is taken with little changes from the "FileFunctions" client general module procedure
//
// Parameters:
//  StrFileName - String - checked
//  attachment file name ChBDeleteIncorrect - Boolean - delete or not incorrect characters from
// the passed string Return value:
//  String - attachment file name
//
Function CorrectFileName(Val StrFileName, FlDeleteIncorrect = False) Export
	
	// List of disallowed characters is
	// taken from here: http://support.microsoft.com/kb/100108/ru and disallowed characters for file systems FAT and NTFS are joined
	StrException = """ / \ [ ] : ; | = , ? * < >";
	StrException = StrReplace(StrException, " ", "");
	
	Result = True;
	
	For Ct = 1 to StrLen(StrException) Do
		Char = Mid(StrException, Ct, 1);
		If Find(StrFileName, Char) <> 0 Then
			If FlDeleteIncorrect Then
				StrFileName = StrReplace(StrFileName, Char, "");
			Else
				Result = False;
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If Not Result Then
		Text = NStr("en='The following characters should not be present
		|in the attachment file name: %1 File name: %2';ru='В имени файла не должно быть
		|следующих символов: %1 Имя файла: %2'");
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(Text, StrException, StrFileName);
		Raise ErrorText;
	Else
		Return StrFileName;
	EndIf;
	
EndFunction

// For internal use only
Function WorkingDirectory(Val DataProcessorKind = "", UniqueKey = "") Export
	
	Subdirectory = "";
	If ValueIsFilled(DataProcessorKind) Then
		Subdirectory = CorrectFileName(DataProcessorKind, True) + "\";
	EndIf;
	DirectoryName = ElectronicDocumentsServiceCallServer.TemporaryFilesCurrentDirectory() + Subdirectory
					+ UniqueKey + "\";
	DirectoryOnHardDisk = New File(DirectoryName);
	If DirectoryOnHardDisk.Exist() Then
		DeleteFiles(DirectoryOnHardDisk, "*");
	Else
		CreateDirectory(DirectoryName);
	EndIf;
	
	DeleteUnnecessarySlashInPath(DirectoryName);
	
	Return DirectoryName;
	
EndFunction

// For internal use only
Function GetAdmissibleEDStatus(NewStatus, LinkToED) Export
	
	CurrentStatus = Undefined;
	
	If ValueIsFilled(LinkToED) Then
		If TypeOf(LinkToED) = Type("DocumentRef.RandomED") Then
			CurrentStatus = LinkToED.DocumentStatus;
		Else
			CurrentStatus = LinkToED.EDStatus;
		EndIf;
		
		If NewStatus = Enums.EDStatuses.Rejected OR NewStatus = Enums.EDStatuses.RejectedByReceiver
			OR Not ValueIsFilled(CurrentStatus) OR NewStatus = Enums.EDStatuses.TransferError
			OR NewStatus = Enums.EDStatuses.Canceled
			OR NewStatus = Enums.EDStatuses.CancellationOfferReceived
			OR NewStatus = Enums.EDStatuses.CancellationOfferCreated Then
			CurrentStatus = NewStatus;
		Else
			ExchangeSettings = EDExchangeSettings(LinkToED);
			
			If ExchangeSettings <> Undefined Then
			
				StatusesArray = ReturnEDStatusesArray(ExchangeSettings);
				
				CurrentStatusIndex = StatusesArray.Find(CurrentStatus);
				NewStatusIndex   = StatusesArray.Find(NewStatus);
				If NewStatusIndex <> Undefined AND CurrentStatusIndex <> Undefined Then
					If NewStatusIndex > CurrentStatusIndex Then
						CurrentStatus = NewStatus;
					EndIf;
				EndIf;
				
			EndIf;
		EndIf;
	EndIf;
	
	Return CurrentStatus;
	
EndFunction

// For internal use only
Function ReturnEDStatusesArray(ExchangeSettings) Export
	
	StatusesArray = New Array;
	
	If ValueIsFilled(ExchangeSettings) Then
		RequireConfirmation = True;
		If TypeOf(ExchangeSettings) = Type("Structure") Then
			If Not ExchangeSettings.Property("RequireConfirmation", RequireConfirmation) Then
				RequireConfirmation = True;
			EndIf;
		Else
			If ExchangeSettings.Owner().Columns.Find("RequireConfirmation") = Undefined Then
				RequireConfirmation = True;
			Else
				RequireConfirmation = ExchangeSettings.RequireConfirmation;
			EndIf;
		EndIf;
		If TypeOf(RequireConfirmation) <> Type("Boolean") Then
			RequireConfirmation = True;
		EndIf;
		
		If ExchangeSettings.Direction = Enums.EDDirections.Outgoing Then
			
			If ExchangeSettings.EDKind = Enums.EDKinds.NotificationAboutReception
				OR ExchangeSettings.EDKind = Enums.EDKinds.NotificationAboutClarification Then
				
				StatusesArray.Add(Enums.EDStatuses.Created);
				StatusesArray.Add(Enums.EDStatuses.Approved);
				StatusesArray.Add(Enums.EDStatuses.DigitallySigned);
				StatusesArray.Add(Enums.EDStatuses.PreparedToSending);
				StatusesArray.Add(Enums.EDStatuses.Sent);
				
			ElsIf ExchangeSettings.ExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
				
				StatusesArray.Add(Enums.EDStatuses.Created);
				StatusesArray.Add(Enums.EDStatuses.Approved);
				StatusesArray.Add(Enums.EDStatuses.DigitallySigned);
				StatusesArray.Add(Enums.EDStatuses.PreparedToSending);
				StatusesArray.Add(Enums.EDStatuses.TransferedToOperator);
				If ExchangeSettings.EDKind = Enums.EDKinds.RandomED Then
					StatusesArray.Add(Enums.EDStatuses.Sent);
					If RequireConfirmation Then
						StatusesArray.Add(Enums.EDStatuses.ConfirmationReceived);
					EndIf;
				Else
					
					// ED statuses set is used depending on the schedule version usage.
					If ExchangeSettings.EDFScheduleVersion = Enums.Exchange1CRegulationsVersion.Version20 Then
						
						If ExchangeSettings.EDKind <> Enums.EDKinds.TORG12Customer
							AND ExchangeSettings.EDKind <> Enums.EDKinds.ActCustomer
							AND ExchangeSettings.EDKind <> Enums.EDKinds.AgreementAboutCostChangeRecipient Then
							
							StatusesArray.Add(Enums.EDStatuses.Sent);
							StatusesArray.Add(Enums.EDStatuses.Delivered);
						EndIf;
					Else
						StatusesArray.Add(Enums.EDStatuses.Sent);
						StatusesArray.Add(Enums.EDStatuses.Delivered);
					EndIf;
				
					If ExchangeSettings.EDKind <> Enums.EDKinds.CustomerInvoiceNote
						AND ExchangeSettings.EDKind <> Enums.EDKinds.CorrectiveInvoiceNote
						AND ExchangeSettings.EDKind <> Enums.EDKinds.TORG12Customer
						AND ExchangeSettings.EDKind <> Enums.EDKinds.ActCustomer
						AND ExchangeSettings.EDKind <> Enums.EDKinds.AgreementAboutCostChangeRecipient
						AND ExchangeSettings.EDKind <> Enums.EDKinds.InvoiceForPayment Then
						
						StatusesArray.Add(Enums.EDStatuses.ConfirmationReceived);
					EndIf;
				EndIf;
				
			ElsIf ExchangeSettings.ExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource Then
				If ExchangeSettings.EDKind = Enums.EDKinds.QueryStatement Then
					StatusesArray.Add(Enums.EDStatuses.Created);
					If ExchangeSettings.UseSignature Then
						StatusesArray.Add(Enums.EDStatuses.DigitallySigned);
					EndIf;
					StatusesArray.Add(Enums.EDStatuses.PreparedToSending);
					StatusesArray.Add(Enums.EDStatuses.Sent);
					StatusesArray.Add(Enums.EDStatuses.Delivered);
				Else
					StatusesArray.Add(Enums.EDStatuses.Created);
					StatusesArray.Add(Enums.EDStatuses.Approved);
					If ExchangeSettings.UseSignature Then
						If ExchangeSettings.UsedFewSignatures Then
							StatusesArray.Add(Enums.EDStatuses.PartlyDigitallySigned);
						EndIf;
						StatusesArray.Add(Enums.EDStatuses.DigitallySigned);
					EndIf;
					If Not ExchangeSettings.BankApplication = Enums.BankApplications.SberbankOnline Then
						StatusesArray.Add(Enums.EDStatuses.PreparedToSending);
					EndIf;
					StatusesArray.Add(Enums.EDStatuses.Sent);
					
					If ExchangeSettings.BankApplication = Enums.BankApplications.AsynchronousExchange Then
						StatusesArray.Add(Enums.EDStatuses.Accepted);
					Else
						StatusesArray.Add(Enums.EDStatuses.Delivered);
					EndIf;
					
					If ExchangeSettings.BankApplication = Enums.BankApplications.SberbankOnline Then
						StatusesArray.Add(Enums.EDStatuses.Accepted);
					EndIf;
					StatusesArray.Add(Enums.EDStatuses.Executed);
					If ExchangeSettings.BankApplication = Enums.BankApplications.AsynchronousExchange Then
						StatusesArray.Add(Enums.EDStatuses.Confirmed);
					EndIf;
				EndIf;
			Else
				StatusesArray.Add(Enums.EDStatuses.Created);
				StatusesArray.Add(Enums.EDStatuses.Approved);
				If ExchangeSettings.UseSignature Then
					StatusesArray.Add(Enums.EDStatuses.DigitallySigned);
				EndIf;
				StatusesArray.Add(Enums.EDStatuses.PreparedToSending);
				StatusesArray.Add(Enums.EDStatuses.Sent);
				If ExchangeSettings.EDKind = Enums.EDKinds.RandomED Then
					If RequireConfirmation Then
						StatusesArray.Add(Enums.EDStatuses.ConfirmationReceived);
					EndIf;
				Else
					If ExchangeSettings.PackageFormatVersion = Enums.EDPackageFormatVersions.Version30 Then
						// Do not add the Delivered status for
						// response titles as Notifications should be delivered according to them.
						If Not (ExchangeSettings.EDKind = Enums.EDKinds.TORG12Customer
							Or ExchangeSettings.EDKind = Enums.EDKinds.ActCustomer
							Or ExchangeSettings.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient) Then
							
							StatusesArray.Add(Enums.EDStatuses.Delivered);
							
							If ExchangeSettings.UseSignature
								AND Not ExchangeSettings.EDKind = Enums.EDKinds.InvoiceForPayment Then
								
								StatusesArray.Add(Enums.EDStatuses.ConfirmationReceived);
							EndIf;
						EndIf;
					Else
						// If outgoing documents format 2,0
						If ExchangeSettings.UseReceipt Then
							StatusesArray.Add(Enums.EDStatuses.Delivered);
						EndIf;
						If ExchangeSettings.UseSignature
							AND ExchangeSettings.EDKind <> Enums.EDKinds.TORG12Customer
							AND ExchangeSettings.EDKind <> Enums.EDKinds.ActCustomer
							AND ExchangeSettings.EDKind <> Enums.EDKinds.AgreementAboutCostChangeRecipient Then
							
							StatusesArray.Add(Enums.EDStatuses.ConfirmationReceived);
						EndIf;
					EndIf;
				EndIf
			EndIf;
			
		ElsIf ExchangeSettings.Direction = Enums.EDDirections.Incoming Then
			
			StatusesArray.Add(Enums.EDStatuses.Received);
			
			If Not (ExchangeSettings.EDKind = Enums.EDKinds.NotificationAboutReception
					OR ExchangeSettings.EDKind = Enums.EDKinds.Confirmation
					OR ExchangeSettings.EDKind = Enums.EDKinds.NotificationAboutClarification
					OR ExchangeSettings.EDKind = Enums.EDKinds.TORG12Customer
					OR ExchangeSettings.EDKind = Enums.EDKinds.ActCustomer
					OR ExchangeSettings.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient
					OR ExchangeSettings.EDKind = Enums.EDKinds.BankStatement) Then
					
				If ExchangeSettings.ExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
					If ExchangeSettings.EDKind = Enums.EDKinds.RandomED Then
						If RequireConfirmation Then
							StatusesArray.Add(Enums.EDStatuses.Approved);
							StatusesArray.Add(Enums.EDStatuses.DigitallySigned);
							StatusesArray.Add(Enums.EDStatuses.ConfirmationPrepared);
							StatusesArray.Add(Enums.EDStatuses.ConfirmationSent);
						EndIf;
					Else
						StatusesArray.Add(Enums.EDStatuses.Approved);
						If ExchangeSettings.EDKind <> Enums.EDKinds.CustomerInvoiceNote
							AND ExchangeSettings.EDKind <> Enums.EDKinds.CorrectiveInvoiceNote
							AND ExchangeSettings.EDKind <> Enums.EDKinds.TORG12Seller
							AND ExchangeSettings.EDKind <> Enums.EDKinds.ActPerformer
							AND ExchangeSettings.EDKind <> Enums.EDKinds.AgreementAboutCostChangeSender
							AND ExchangeSettings.EDKind <> Enums.EDKinds.InvoiceForPayment Then
							
							StatusesArray.Add(Enums.EDStatuses.DigitallySigned);
							StatusesArray.Add(Enums.EDStatuses.ConfirmationPrepared);
							StatusesArray.Add(Enums.EDStatuses.TransferedToOperator);
							StatusesArray.Add(Enums.EDStatuses.ConfirmationSent);
						EndIf;
					EndIf;
				Else
					If ExchangeSettings.EDKind = Enums.EDKinds.RandomED Then
						If RequireConfirmation Then
							StatusesArray.Add(Enums.EDStatuses.Approved);
							StatusesArray.Add(Enums.EDStatuses.DigitallySigned);
							StatusesArray.Add(Enums.EDStatuses.ConfirmationPrepared);
							StatusesArray.Add(Enums.EDStatuses.ConfirmationSent);
						EndIf;
					Else
						StatusesArray.Add(Enums.EDStatuses.Approved);
						If ExchangeSettings.UseSignature
							AND ExchangeSettings.EDKind <> Enums.EDKinds.TORG12Seller
							AND ExchangeSettings.EDKind <> Enums.EDKinds.ActPerformer
							AND ExchangeSettings.EDKind <> Enums.EDKinds.AgreementAboutCostChangeSender
							AND Not (ExchangeSettings.EDKind = Enums.EDKinds.InvoiceForPayment
							AND ExchangeSettings.PackageFormatVersion =
							Enums.EDPackageFormatVersions.Version30) Then
							
							StatusesArray.Add(Enums.EDStatuses.DigitallySigned);
							StatusesArray.Add(Enums.EDStatuses.ConfirmationPrepared);
							StatusesArray.Add(Enums.EDStatuses.ConfirmationSent);
							If ExchangeSettings.UseReceipt
								AND Not ExchangeSettings.EDKind = Enums.EDKinds.InvoiceForPayment Then
								StatusesArray.Add(Enums.EDStatuses.ConfirmationDelivered);
							EndIf;
						EndIf;
					EndIf;
				EndIf;
			EndIf;
		ElsIf ExchangeSettings.Direction = Enums.EDDirections.Intercompany Then
			StatusesArray.Add(Enums.EDStatuses.Created);
			StatusesArray.Add(Enums.EDStatuses.Approved);
			StatusesArray.Add(Enums.EDStatuses.PartlyDigitallySigned);
			StatusesArray.Add(Enums.EDStatuses.FullyDigitallySigned);
		EndIf;
	EndIf;
	
	Return StatusesArray;
	
EndFunction

// For internal use only
Procedure DeleteUnnecessarySlashInPath(Path) Export
	
	While Find(Path, "\\") > 0 Do
		
		Path = StrReplace(Path, "\\", "\");
		
	EndDo;
	
EndProcedure

// Procedure is called from the client
// module, deletes folder created on server and passed to client as a parameter.
// 
// Parameters:
// Folder - String, path to the temporary folder on server.
//
Procedure DeleteFolderAtServer(Folder) Export
	
	If ValueIsFilled(Folder) Then
		
		File = New File(Folder);
		If File.Exist() Then
			DeleteFiles(Folder);
		EndIf;
	EndIf;
	
EndProcedure

// Determines settings of the electronic documents exchange by the parameters structure.
Function DetermineEDExchangeSettings(ParametersStructure, CertificateTumbprintsArray = Undefined, OperatingAgreementsCheckBox = True) Export
	
	SetPrivilegedMode(True);
	
	EDExchangeSettings = Undefined;
	
	EDDirection = "";
	EDKind = "";
	Counterparty = "";
	If ParametersStructure.Property("EDDirection", EDDirection)
		AND ParametersStructure.Property("EDKind", EDKind)
		AND ParametersStructure.Property("Counterparty", Counterparty)
		AND ValueIsFilled(EDDirection) AND ValueIsFilled(EDKind) AND ValueIsFilled(Counterparty) Then
		
		DSUseCheckBox = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
			"UseDigitalSignatures");
			
		Query  = New Query;
		Query.SetParameter("User",  Users.AuthorizedUser());
		Query.SetParameter("EDDirection", EDDirection);
		Query.SetParameter("EDKind",         EDKind);
		Query.SetParameter("Counterparty",    Counterparty);
		
		CounterpartyContract = "";
		If ParametersStructure.Property("CounterpartyContract", CounterpartyContract) AND Not ValueIsFilled(CounterpartyContract) Then
			CounterpartyContract = ElectronicDocumentsReUse.GetEmptyRef("CounterpartyContracts");
		EndIf;
		Query.SetParameter("CounterpartyContract", CounterpartyContract);
		
		OwnerEDKind = Undefined;
		If ParametersStructure.Property("OwnerEDKind", OwnerEDKind) Then
			Query.SetParameter("IsVariance",   True);
		Else
			Query.SetParameter("IsVariance",   False);
		EndIf;
		Query.SetParameter("OwnerEDKind",  OwnerEDKind);
		Query.SetParameter("FTSDocument",  IsFTS(OwnerEDKind));
		
		Query.SetParameter("OnlyOperatingAgreements",  OperatingAgreementsCheckBox);
		
		EDAgreement = "";
		Company = "";
		If ParametersStructure.Property("EDAgreement", EDAgreement) AND ValueIsFilled(EDAgreement) Then
			Query.SetParameter("EDAgreement", EDAgreement);
			
			GetExchangeByAgreementSettingsText(Query.Text);
			
		ElsIf ParametersStructure.Property("Company", Company) AND ValueIsFilled(Company) Then
			Query.SetParameter("Company", Company);
			
			If ElectronicDocumentsReUse.UseAdditionalAnalyticsOfCompaniesCatalogPartners() Then
				Partner = "";
				ParametersStructure.Property("Partner", Partner);
				Query.SetParameter("Partner", Partner);
			EndIf;
			
			GetExchangeWithPrioritiesSettingsQueryText(Query.Text);
			QueryResult = Query.ExecuteBatch();
			If QueryResult[2].IsEmpty() Then
				// Search for EDF setting without counterparty agreement specification.
				CounterpartyContract = ElectronicDocumentsReUse.GetEmptyRef("CounterpartyContracts");
				Query.SetParameter("CounterpartyContract", CounterpartyContract);
			EndIf;
			
		EndIf;
		
		If ValueIsFilled(Query.Text) Then
			
			QueryResult = Query.ExecuteBatch();
			VT = QueryResult[2].Unload();
			VTRequiredSignaturesCertificates = QueryResult[3].Unload();
			
			If Not VT.Count() = 0 Then
				CurrentSetting = VT[0];
				
				EDExchangeSettings = New Structure;
				EDExchangeSettings.Insert("CertificateAvailable", False);
				// If set cryptography certificates are passed
				// from client, then you should select setting with this certificates.
				If DSUseCheckBox AND CertificateTumbprintsArray <> Undefined Then

					For Each VTRow IN VT Do
						If VTRow.ToSign Then
							If VTRow.EDKind = Enums.EDKinds.PaymentOrder
								OR VTRow.EDKind = Enums.EDKinds.QueryStatement Then
								FoundAppropriateCertificate = False;
								FilterParameters = New Structure("Agreement, Thumbprint", 
								VTRow.EDAgreement, 
								VTRow.CompanyCertificateForSigning.Imprint);
								RowArray = VTRequiredSignaturesCertificates.FindRows(FilterParameters);
								For Each Item IN RowArray Do
									If (CertificateTumbprintsArray.Find(Item.Imprint) <> Undefined
										OR CurrentSetting.BankApplication = Enums.BankApplications.SberbankOnline)
										AND ParametersStructure.SetSignatures.Find(VTRow.CompanyCertificateForSigning.Imprint) = Undefined Then 
										CurrentSetting = VTRow;
										EDExchangeSettings.Insert("CertificateAvailable", True);
										FoundAppropriateCertificate = True;
										Break;
									EndIf
								EndDo;
								If FoundAppropriateCertificate Then
									Break;
								EndIf;
							ElsIf CertificateTumbprintsArray = Undefined OR CertificateTumbprintsArray.Count() = 0 Then
								Break;
							Else
								If CertificateTumbprintsArray.Find(VTRow.CompanyCertificateForSigning.Imprint) <> Undefined
									OR CertificateTumbprintsArray.Find(VTRow.RecipientCompanyCertificateForSigning.Imprint) <> Undefined
									OR CertificateTumbprintsArray.Find(VTRow.CompanyCertificateForConfirmation.Imprint) <> Undefined Then
									
									CurrentSetting = VTRow;
									EDExchangeSettings.Insert("CertificateAvailable", True);
									Break;
								EndIf;
							EndIf;
						Else
							Break;
						EndIf;
					EndDo;
				EndIf;
				
				For Each CurColumn IN VT.Columns Do
					EDExchangeSettings.Insert(CurColumn.Name, CurrentSetting[CurColumn.Name]);
				EndDo;
				
				If DSUseCheckBox Then
					SignatureFlag = EDExchangeSettings.ToSign;
				Else
					SignatureFlag = False;
				EndIf;
				EDExchangeSettings.Insert("ToSign", SignatureFlag);
			EndIf;
		EndIf;
	Else
		// If not all mandatory attributes are filled in, then you can not claim that there is no exchange agreement.
		EDExchangeSettings = "";
	EndIf;
	
	Return EDExchangeSettings;
	
EndFunction

// Receives query text by exchange settings.
//
// Returns:
//  QueryText - query text.
//
Procedure GetExchangeByAgreementSettingsText(QueryText) Export
	
	QueryText = ElectronicDocumentsOverridable.GetExchangeByAgreementSettingsText();
	If Not ValueIsFilled(QueryText) Then
		QueryText =
		"SELECT
		|	CWT_Agreements.Company AS Company,
		|	CWT_Agreements.Counterparty AS Counterparty,
		|	CWT_Agreements.EDKind,
		|	CWT_Agreements.EDDirection,
		|	CWT_Agreements.UseDS AS ToSign,
		|	CASE
		|		WHEN &IsVariance
		|			THEN UNDEFINED
		|		ELSE CWT_Agreements.Ref.CounterpartyCertificateForEncryption
		|	END AS CounterpartyCertificateForEncryption,
		|	CWT_Agreements.Ref.CompanyCertificateForDetails AS CompanyCertificateForDetails,
		|	CWT_Agreements.EDFProfileSettings.IncomingDocumentsResource AS IncomingDocumentsGeneralResource,
		|	CWT_Agreements.Ref.IncomingDocumentsResource AS IncomingDocumentsResource,
		|	CWT_Agreements.Ref.OutgoingDocumentsResource AS OutgoingDocumentsResource,
		|	CWT_Agreements.Ref.IncomingDocumentsDir AS IncomingDocumentsDir,
		|	CWT_Agreements.Ref.OutgoingDocumentsDir AS OutgoingDocumentsDir,
		|	CWT_Agreements.Ref.IncomingDocumentsDirFTP AS IncomingDocumentsDirFTP,
		|	CWT_Agreements.Ref.OutgoingDocumentsDirFTP AS OutgoingDocumentsDirFTP,
		|	CWT_Agreements.Ref.CounterpartyEmail AS CounterpartyEmail,
		|	CWT_Agreements.CounterpartyID AS CounterpartyID,
		|	CWT_Agreements.CompanyID AS CompanyID,
		|	CWT_Agreements.Ref AS Basis,
		|	CWT_Agreements.EDFProfileSettings AS EDFProfileSettings,
		|	CWT_Agreements.EDExchangeMethod AS EDExchangeMethod,
		|	CWT_Agreements.EDFScheduleVersion,
		|	CWT_Agreements.FormatVersion,
		|	CWT_Agreements.PackageFormatVersion,
		|	CWT_Agreements.Ref.BankApplication AS BankApplication,
		|	CWT_Agreements.EDFSettingWorks
		|INTO TU_CWT_Agreements
		|FROM
		|	(SELECT
		|		EDUsageAgreementsOutgoingDocuments.Ref AS Ref,
		|		EDUsageAgreementsOutgoingDocuments.OutgoingDocument AS EDKind,
		|		EDUsageAgreementsOutgoingDocuments.UseDS AS UseDS,
		|		TRUE AS Field1,
		|		&EDDirection AS EDDirection,
		|		EDUsageAgreementsOutgoingDocuments.Ref.Company AS Company,
		|		EDUsageAgreementsOutgoingDocuments.Ref.Counterparty AS Counterparty,
		|		EDUsageAgreementsOutgoingDocuments.CounterpartyID AS CounterpartyID,
		|		EDUsageAgreementsOutgoingDocuments.CompanyID AS CompanyID,
		|		EDUsageAgreementsOutgoingDocuments.EDExchangeMethod AS EDExchangeMethod,
		|		VALUE(Enum.Exchange1CRegulationsVersion.Version20) AS EDFScheduleVersion,
		|		EDUsageAgreementsOutgoingDocuments.FormatVersion AS FormatVersion,
		|		EDUsageAgreementsOutgoingDocuments.Ref.PackageFormatVersion AS PackageFormatVersion,
		|		EDUsageAgreementsOutgoingDocuments.EDFProfileSettings AS EDFProfileSettings,
		|		CASE
		|			WHEN Not EDUsageAgreementsOutgoingDocuments.Ref.DeletionMark
		|					AND EDUsageAgreementsOutgoingDocuments.Ref.ConnectionStatus = VALUE(Enum.EDExchangeMemberStatuses.Connected)
		|				THEN TRUE
		|			ELSE FALSE
		|		END AS EDFSettingWorks
		|	FROM
		|		Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
		|	WHERE
		|		EDUsageAgreementsOutgoingDocuments.Ref = &EDAgreement
		|		AND CASE
		|				WHEN &IsVariance
		|					THEN EDUsageAgreementsOutgoingDocuments.OutgoingDocument = &OwnerEDKind
		|				ELSE EDUsageAgreementsOutgoingDocuments.OutgoingDocument = &EDKind
		|			END
		|		AND CASE
		|				WHEN &OnlyOperatingAgreements
		|					THEN Not EDUsageAgreementsOutgoingDocuments.Ref.DeletionMark
		|							AND (EDUsageAgreementsOutgoingDocuments.Ref.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
		|									AND EDUsageAgreementsOutgoingDocuments.Ref.AgreementStatus = VALUE(Enum.EDAgreementsStatuses.Acts)
		|								OR EDUsageAgreementsOutgoingDocuments.Ref.EDExchangeMethod <> VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
		|									AND EDUsageAgreementsOutgoingDocuments.Ref.ConnectionStatus = VALUE(Enum.EDExchangeMemberStatuses.Connected))
		|				ELSE TRUE
		|			END) AS CWT_Agreements
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Certificates.Ref AS Ref,
		|	EDEPKinds.EDKind AS DocumentKind,
		|	Certificates.Company AS Company,
		|	FALSE AS RememberCertificatePassword,
		|	FALSE AS PasswordReceived,
		|	UNDEFINED AS UserPassword
		|INTO TU_Certificates
		|FROM
		|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
		|		LEFT JOIN InformationRegister.DigitallySignedEDKinds AS EDEPKinds
		|		ON (EDEPKinds.DSCertificate = Certificates.Ref)
		|		INNER JOIN (SELECT DISTINCT
		|			EDFProfilesCertificates.Certificate AS Certificate
		|		FROM
		|			TU_CWT_Agreements AS TU_CWT_Agreements
		|				LEFT JOIN Catalog.EDFProfileSettings.CompanySignatureCertificates AS EDFProfilesCertificates
		|				ON TU_CWT_Agreements.EDFProfileSettings = EDFProfilesCertificates.Ref
		|		
		|		UNION ALL
		|		
		|		SELECT
		|			AgreementsEDCertificates.Certificate
		|		FROM
		|			TU_CWT_Agreements AS TU_CWT_Agreements
		|				LEFT JOIN Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsEDCertificates
		|				ON TU_CWT_Agreements.Basis = AgreementsEDCertificates.Ref) AS CertificatesFromSettingsAndProfiles
		|		ON Certificates.Ref = CertificatesFromSettingsAndProfiles.Certificate
		|WHERE
		|	Not Certificates.DeletionMark
		|	AND Not Certificates.Revoked
		|	AND EDEPKinds.EDKind = &EDKind
		|	AND (Certificates.User = &User
		|			OR Certificates.User = VALUE(Catalog.Users.EmptyRef))
		|	AND EDEPKinds.Use
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TU_CWT_Agreements.Company,
		|	TU_CWT_Agreements.Counterparty,
		|	TU_CWT_Agreements.EDKind,
		|	TU_CWT_Agreements.EDDirection,
		|	TU_CWT_Agreements.ToSign AS ToSign,
		|	TU_CWT_Agreements.CounterpartyCertificateForEncryption,
		|	TU_CWT_Agreements.CompanyCertificateForDetails,
		|	TU_CWT_Agreements.IncomingDocumentsGeneralResource,
		|	TU_CWT_Agreements.IncomingDocumentsResource AS IncomingDocumentsResource,
		|	TU_CWT_Agreements.OutgoingDocumentsResource AS OutgoingDocumentsResource,
		|	TU_CWT_Agreements.IncomingDocumentsDir,
		|	TU_CWT_Agreements.OutgoingDocumentsDir,
		|	TU_CWT_Agreements.IncomingDocumentsDirFTP,
		|	TU_CWT_Agreements.OutgoingDocumentsDirFTP,
		|	TU_CWT_Agreements.CounterpartyEmail,
		|	TU_CWT_Agreements.CounterpartyID AS CounterpartyID,
		|	TU_CWT_Agreements.CompanyID AS CompanyID,
		|	TU_CWT_Agreements.Basis AS EDAgreement,
		|	TU_CWT_Agreements.EDFProfileSettings AS EDFProfileSettings,
		|	TU_CWT_Agreements.EDExchangeMethod AS EDExchangeMethod,
		|	CASE
		|		WHEN TU_Certificates.Ref IS NULL 
		|			THEN VALUE(Catalog.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef)
		|		ELSE TU_Certificates.Ref
		|	END AS CompanyCertificateForSigning,
		|	CASE
		|		WHEN TU_Certificates.Ref IS NULL 
		|			THEN VALUE(Catalog.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef)
		|		ELSE TU_Certificates.Ref
		|	END AS CompanyCertificateForConfirmation,
		|	CASE
		|		WHEN &EDDirection <> VALUE(Enum.EDDirections.Intercompany)
		|				OR TU_ReceiverCompanyCertificates.Ref IS NULL 
		|			THEN VALUE(Catalog.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef)
		|		ELSE TU_ReceiverCompanyCertificates.Ref
		|	END AS RecipientCompanyCertificateForSigning,
		|	ISNULL(TU_Certificates.RememberCertificatePassword, FALSE) AS RememberCertificatePassword,
		|	ISNULL(TU_Certificates.RememberCertificatePassword, FALSE) AS PasswordReceived,
		|	TU_Certificates.UserPassword,
		|	ISNULL(TU_ReceiverCompanyCertificates.RememberCertificatePassword, FALSE) AS RememberPasswordToRecipEntCertificate,
		|	ISNULL(TU_ReceiverCompanyCertificates.RememberCertificatePassword, FALSE) AS PasswordReceivedByReceipientComp,
		|	TU_ReceiverCompanyCertificates.UserPassword AS RecipEntUserPassword,
		|	TU_CWT_Agreements.EDFScheduleVersion,
		|	TU_CWT_Agreements.FormatVersion,
		|	TU_CWT_Agreements.PackageFormatVersion,
		|	TU_CWT_Agreements.BankApplication,
		|	TU_CWT_Agreements.EDFSettingWorks
		|FROM
		|	TU_CWT_Agreements AS TU_CWT_Agreements
		|		LEFT JOIN TU_Certificates AS TU_Certificates
		|		ON TU_CWT_Agreements.EDKind = TU_Certificates.DocumentKind
		|			AND (TU_Certificates.Company = TU_CWT_Agreements.Company)
		|		LEFT JOIN TU_Certificates AS TU_ReceiverCompanyCertificates
		|		ON TU_CWT_Agreements.EDKind = TU_ReceiverCompanyCertificates.DocumentKind
		|			AND TU_CWT_Agreements.Counterparty = TU_ReceiverCompanyCertificates.Company
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AgreementsOnUseOfEDCertificatesCompanySignatures.Certificate.Imprint AS Imprint,
		|	AgreementsOnUseOfEDCertificatesCompanySignatures.Ref AS Agreement
		|FROM
		|	Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsOnUseOfEDCertificatesCompanySignatures
		|WHERE
		|	Not AgreementsOnUseOfEDCertificatesCompanySignatures.Ref.DeletionMark
		|	AND AgreementsOnUseOfEDCertificatesCompanySignatures.Ref = &EDAgreement";
	EndIf;
	
EndProcedure

// It receives a query text by exchange settings with the priorities.
//
// Parameters:
//  QueryText - query text.
//
Procedure GetExchangeWithPrioritiesSettingsQueryText(QueryText)
	
	QueryText = ElectronicDocumentsOverridable.GetExchangeWithPrioritiesSettingsQueryText();
	If Not ValueIsFilled(QueryText) Then
		
		QueryText =
		"SELECT
		|	CWT_Agreements.Company AS Company,
		|	CWT_Agreements.Counterparty AS Counterparty,
		|	CWT_Agreements.EDKind,
		|	CWT_Agreements.EDDirection,
		|	CWT_Agreements.UseDS AS ToSign,
		|	TRUE AS ExpectDeliveryTicket,
		|	CWT_Agreements.Ref.CounterpartyCertificateForEncryption AS CounterpartyCertificateForEncryption,
		|	CWT_Agreements.Ref.CompanyCertificateForDetails AS CompanyCertificateForDetails,
		|	CWT_Agreements.EDFProfileSettings.IncomingDocumentsResource AS IncomingDocumentsGeneralResource,
		|	CWT_Agreements.Ref.IncomingDocumentsResource AS IncomingDocumentsResource,
		|	CWT_Agreements.Ref.OutgoingDocumentsResource AS OutgoingDocumentsResource,
		|	CWT_Agreements.Ref.IncomingDocumentsDir AS IncomingDocumentsDir,
		|	CWT_Agreements.Ref.OutgoingDocumentsDir AS OutgoingDocumentsDir,
		|	CWT_Agreements.Ref.IncomingDocumentsDirFTP AS IncomingDocumentsDirFTP,
		|	CWT_Agreements.Ref.OutgoingDocumentsDirFTP AS OutgoingDocumentsDirFTP,
		|	CWT_Agreements.Ref.CounterpartyEmail AS CounterpartyEmail,
		|	CWT_Agreements.CounterpartyID AS CounterpartyID,
		|	CWT_Agreements.CompanyID AS CompanyID,
		|	CWT_Agreements.Ref AS Basis,
		|	CWT_Agreements.EDFProfileSettings AS EDFProfileSettings,
		|	CWT_Agreements.EDExchangeMethod AS EDExchangeMethod,
		|	CWT_Agreements.EDFScheduleVersion AS EDFScheduleVersion,
		|	CWT_Agreements.Priority,
		|	CWT_Agreements.FormatVersion,
		|	CWT_Agreements.PackageFormatVersion,
		|	CWT_Agreements.Ref.BankApplication AS BankApplication,
		|	CWT_Agreements.EDFSettingWorks
		|INTO TU_CWT_Agreements
		|FROM
		|	(SELECT
		|		EDUsageAgreementsOutgoingDocuments.Ref AS Ref,
		|		EDUsageAgreementsOutgoingDocuments.OutgoingDocument AS EDKind,
		|		EDUsageAgreementsOutgoingDocuments.UseDS AS UseDS,
		|		TRUE AS Field1,
		|		&EDDirection AS EDDirection,
		|		EDUsageAgreementsOutgoingDocuments.Ref.Company AS Company,
		|		EDUsageAgreementsOutgoingDocuments.Ref.Counterparty AS Counterparty,
		|		EDUsageAgreementsOutgoingDocuments.CounterpartyID AS CounterpartyID,
		|		EDUsageAgreementsOutgoingDocuments.CompanyID AS CompanyID,
		|		EDUsageAgreementsOutgoingDocuments.EDExchangeMethod AS EDExchangeMethod,
		|		VALUE(Enum.Exchange1CRegulationsVersion.Version20) AS EDFScheduleVersion,
		|		EDUsageAgreementsOutgoingDocuments.FormatVersion AS FormatVersion,
		|		EDUsageAgreementsOutgoingDocuments.Ref.PackageFormatVersion AS PackageFormatVersion,
		|		EDUsageAgreementsOutgoingDocuments.EDFProfileSettings AS EDFProfileSettings,
		|		0 AS Priority,
		|		CASE
		|			WHEN Not EDUsageAgreementsOutgoingDocuments.Ref.DeletionMark
		|					AND EDUsageAgreementsOutgoingDocuments.Ref.ConnectionStatus = VALUE(Enum.EDExchangeMemberStatuses.Connected)
		|				THEN TRUE
		|			ELSE FALSE
		|		END AS EDFSettingWorks
		|	FROM
		|		Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
		|	WHERE
		|		CASE
		|				WHEN &OnlyOperatingAgreements
		|					THEN Not EDUsageAgreementsOutgoingDocuments.Ref.DeletionMark
		|							AND (EDUsageAgreementsOutgoingDocuments.Ref.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
		|									AND EDUsageAgreementsOutgoingDocuments.Ref.AgreementStatus = VALUE(Enum.EDAgreementsStatuses.Acts)
		|								OR EDUsageAgreementsOutgoingDocuments.Ref.EDExchangeMethod <> VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
		|									AND EDUsageAgreementsOutgoingDocuments.Ref.ConnectionStatus = VALUE(Enum.EDExchangeMemberStatuses.Connected))
		|				ELSE TRUE
		|			END
		|		AND CASE
		|				WHEN &EDKind = UNDEFINED
		|						AND &EDDirection = UNDEFINED
		|					THEN EDUsageAgreementsOutgoingDocuments.Ref.Company = &Company
		|							AND EDUsageAgreementsOutgoingDocuments.Ref.Counterparty = &Counterparty
		|							AND EDUsageAgreementsOutgoingDocuments.Ref.CounterpartyContract = &CounterpartyContract
		|				WHEN EDUsageAgreementsOutgoingDocuments.Ref.Company = &Company
		|						AND EDUsageAgreementsOutgoingDocuments.Ref.Counterparty = &Counterparty
		|						AND EDUsageAgreementsOutgoingDocuments.Ref.CounterpartyContract = &CounterpartyContract
		|						AND CASE
		|							WHEN &IsVariance
		|								THEN EDUsageAgreementsOutgoingDocuments.OutgoingDocument = &OwnerEDKind
		|							ELSE EDUsageAgreementsOutgoingDocuments.OutgoingDocument = &EDKind
		|						END
		|					THEN EDUsageAgreementsOutgoingDocuments.ToForm
		|				WHEN EDUsageAgreementsOutgoingDocuments.OutgoingDocument = VALUE(Enum.EDKinds.PriceList)
		|						AND EDUsageAgreementsOutgoingDocuments.Ref.Company = &Company
		|						AND &Partner
		|					THEN TRUE
		|				ELSE FALSE
		|			END) AS CWT_Agreements
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Certificates.Ref AS Ref,
		|	EDEPKinds.EDKind AS DocumentKind,
		|	Certificates.Company AS Company,
		|	FALSE AS RememberCertificatePassword,
		|	FALSE AS PasswordReceived,
		|	UNDEFINED AS UserPassword
		|INTO TU_Certificates
		|FROM
		|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
		|		LEFT JOIN InformationRegister.DigitallySignedEDKinds AS EDEPKinds
		|		ON (EDEPKinds.DSCertificate = Certificates.Ref)
		|		INNER JOIN (SELECT DISTINCT
		|			EDFProfilesCertificates.Certificate AS Certificate
		|		FROM
		|			TU_CWT_Agreements AS TU_CWT_Agreements
		|				LEFT JOIN Catalog.EDFProfileSettings.CompanySignatureCertificates AS EDFProfilesCertificates
		|				ON TU_CWT_Agreements.EDFProfileSettings = EDFProfilesCertificates.Ref
		|		
		|		UNION ALL
		|		
		|		SELECT
		|			AgreementsEDCertificates.Certificate
		|		FROM
		|			TU_CWT_Agreements AS TU_CWT_Agreements
		|				LEFT JOIN Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsEDCertificates
		|				ON TU_CWT_Agreements.Basis = AgreementsEDCertificates.Ref) AS CertificatesFromSettingsAndProfiles
		|		ON Certificates.Ref = CertificatesFromSettingsAndProfiles.Certificate
		|WHERE
		|	Not Certificates.DeletionMark
		|	AND Not Certificates.Revoked
		|	AND CASE
		|			WHEN &EDKind = UNDEFINED
		|				THEN TRUE
		|			ELSE EDEPKinds.EDKind = &EDKind
		|		END
		|	AND (Certificates.User = &User
		|			OR Certificates.User = VALUE(Catalog.Users.EmptyRef))
		|	AND EDEPKinds.Use
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TU_CWT_Agreements.Priority AS Priority,
		|	TU_CWT_Agreements.Company,
		|	TU_CWT_Agreements.Counterparty,
		|	TU_CWT_Agreements.EDKind,
		|	TU_CWT_Agreements.EDDirection,
		|	TU_CWT_Agreements.ToSign AS ToSign,
		|	TU_CWT_Agreements.ExpectDeliveryTicket AS ExpectDeliveryTicket,
		|	TU_CWT_Agreements.CounterpartyCertificateForEncryption,
		|	TU_CWT_Agreements.CompanyCertificateForDetails,
		|	TU_CWT_Agreements.IncomingDocumentsGeneralResource,
		|	TU_CWT_Agreements.IncomingDocumentsResource AS IncomingDocumentsResource,
		|	TU_CWT_Agreements.OutgoingDocumentsResource AS OutgoingDocumentsResource,
		|	TU_CWT_Agreements.IncomingDocumentsDir,
		|	TU_CWT_Agreements.OutgoingDocumentsDir,
		|	TU_CWT_Agreements.IncomingDocumentsDirFTP,
		|	TU_CWT_Agreements.OutgoingDocumentsDirFTP,
		|	TU_CWT_Agreements.CounterpartyEmail,
		|	TU_CWT_Agreements.CounterpartyID AS CounterpartyID,
		|	TU_CWT_Agreements.CompanyID AS CompanyID,
		|	TU_CWT_Agreements.Basis AS EDAgreement,
		|	TU_CWT_Agreements.EDFProfileSettings AS EDFProfileSettings,
		|	TU_CWT_Agreements.EDExchangeMethod AS EDExchangeMethod,
		|	CASE
		|		WHEN TU_Certificates.Ref IS NULL 
		|			THEN VALUE(Catalog.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef)
		|		ELSE TU_Certificates.Ref
		|	END AS CompanyCertificateForSigning,
		|	CASE
		|		WHEN TU_Certificates.Ref IS NULL 
		|				OR TU_Certificates.Company <> &Company
		|			THEN VALUE(Catalog.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef)
		|		ELSE TU_Certificates.Ref
		|	END AS CompanyCertificateForConfirmation,
		|	CASE
		|		WHEN Not &EDDirection = VALUE(Enum.EDDirections.Intercompany)
		|				OR TU_ReceiverCompanyCertificates.Ref IS NULL 
		|			THEN VALUE(Catalog.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef)
		|		ELSE TU_ReceiverCompanyCertificates.Ref
		|	END AS RecipientCompanyCertificateForSigning,
		|	ISNULL(TU_Certificates.RememberCertificatePassword, FALSE) AS RememberCertificatePassword,
		|	ISNULL(TU_Certificates.RememberCertificatePassword, FALSE) AS PasswordReceived,
		|	TU_Certificates.UserPassword,
		|	ISNULL(TU_ReceiverCompanyCertificates.RememberCertificatePassword, FALSE) AS RememberPasswordToRecipEntCertificate,
		|	ISNULL(TU_ReceiverCompanyCertificates.RememberCertificatePassword, FALSE) AS PasswordReceivedByReceipientComp,
		|	TU_ReceiverCompanyCertificates.UserPassword AS RecipEntUserPassword,
		|	TU_CWT_Agreements.EDFScheduleVersion,
		|	TU_CWT_Agreements.FormatVersion,
		|	TU_CWT_Agreements.PackageFormatVersion,
		|	TU_CWT_Agreements.BankApplication,
		|	TU_CWT_Agreements.EDFSettingWorks
		|FROM
		|	TU_CWT_Agreements AS TU_CWT_Agreements
		|		LEFT JOIN TU_Certificates AS TU_Certificates
		|		ON TU_CWT_Agreements.EDKind = TU_Certificates.DocumentKind
		|			AND TU_CWT_Agreements.Company = TU_Certificates.Company
		|		LEFT JOIN TU_Certificates AS TU_ReceiverCompanyCertificates
		|		ON TU_CWT_Agreements.EDKind = TU_ReceiverCompanyCertificates.DocumentKind
		|			AND TU_CWT_Agreements.Counterparty = TU_ReceiverCompanyCertificates.Company
		|WHERE
		|	CASE
		|			WHEN &EDKind = UNDEFINED
		|					AND &EDDirection = UNDEFINED
		|				THEN TRUE
		|			ELSE TU_CWT_Agreements.EDDirection = &EDDirection
		|					AND CASE
		|						WHEN &IsVariance
		|							THEN CASE
		|									WHEN &FTSDocument
		|										THEN TRUE
		|									ELSE TU_CWT_Agreements.EDKind = &OwnerEDKind
		|								END
		|						ELSE TU_CWT_Agreements.EDKind = &EDKind
		|					END
		|		END
		|
		|ORDER BY
		|	Priority
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	AgreementsOnUseOfEDCertificatesCompanySignatures.Ref AS Agreement,
		|	AgreementsOnUseOfEDCertificatesCompanySignatures.Certificate.Imprint AS Imprint
		|FROM
		|	Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsOnUseOfEDCertificatesCompanySignatures
		|WHERE
		|	AgreementsOnUseOfEDCertificatesCompanySignatures.Ref.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
		|	AND Not AgreementsOnUseOfEDCertificatesCompanySignatures.Ref.DeletionMark
		|	AND AgreementsOnUseOfEDCertificatesCompanySignatures.Ref.AgreementStatus = VALUE(Enum.EDAgreementsStatuses.Acts)";
		
		QueryTextPartners = "TRUE";
		If ElectronicDocumentsReUse.UseAdditionalAnalyticsOfCompaniesCatalogPartners() Then
			QueryTextPartners = "&Partner <> UNDEFINED And AgreementOnEDUseOutgoingDocuments.Ref.Counterparty.Partner = &Partner";
		EndIf;
		QueryText = StrReplace(QueryText, "&Partner", QueryTextPartners);
		
	EndIf;
	
EndProcedure

// It returns a structure containing attribute values read
// from the infobase by the object link.
// 
//  If there is no access to one of the attributes, access right exception will occur.
//  If it is required to read the attribute
//  regardless of the current user rights, then you should use preliminary transition to the privileged mode.
// 
// Parameters:
//  Ref       - ref to object, - catalog item, document, ...
//  AttributeNames - String or Structure - if String, the attribute names
// listed comma separated in the format of requirements to structure attributes.
//               For example, "Code, Name, Parent".
//               If it is Structure, the field alias is transferred
//               as the key for the returned structure with the result and as the value (optional) 
//               - actual field name in the table. 
//               If the value is not specified, then the field name is taken from the key.
// 
// Returns:
//  Structure    - contains the list of attributes as
//                 the list of names in
//                 AttributeNames string with attribute values read from the infobases.
// 
Function AttributesValuesStructure(Ref, AttributeNames) Export
	
	DataStructure = "";
	ElectronicDocumentsOverridable.GetAttributesValuesStructure(Ref, AttributeNames, DataStructure);
	
	If TypeOf(DataStructure) <> Type("Structure") Then
		DataStructure = CommonUse.ObjectAttributesValues(Ref, AttributeNames);
	EndIf;
	
	Return DataStructure;
	
EndFunction

// Function generates electronic documents and puts them to the attached files catalog
//
// Parameters:
//  ObjectsArray - array of references to objects for which electronic document should be created;
//  AccordanceOfParameters - match containing ED exchange settings for objects.
//
Function GenerateAttachedFiles(ObjectsArray, ExchangeParameters, AdditParameters = "") Export
	
	SetPrivilegedMode(True);
	
	ExchangeStructuresArray = GenerateDocumentsXMLFiles(ObjectsArray, ExchangeParameters, AdditParameters);
	GeneratedFilesArray = New Array;
	For Each ExchangeStructure IN ExchangeStructuresArray Do
	
		FullFileName = GetEDFileFullName(ExchangeStructure);
		
		If Not ValueIsFilled(FullFileName) Then
			Continue;
		EndIf;
		
		CreationTimeED = ExchangeStructure.EDStructure.EDDate;
		EDOwner = ExchangeStructure.EDStructure.EDOwner;
		File = New File(FullFileName);
		BinaryData = New BinaryData(File.FullName);
		FileURL = PutToTempStorage(BinaryData);
		
		EDUUID = "";
		ExchangeStructure.Property("UUID", EDUUID);
		
		ExchangeStructure.EDStructure.Insert("FileDescription", File.BaseName);
		
		AddedFile = AttachedFiles.AddFile(
													EDOwner,
													File.BaseName,
													StrReplace(File.Extension, ".", ""),
													CreationTimeED,
													CreationTimeED,
													FileURL,
													Undefined,
													,
													Catalogs.EDAttachedFiles.GetRef(EDUUID));
		
		ExchangeStructure.EDStructure.Insert("FileDescription", File.BaseName);
		
		If (ExchangeStructure.EDStructure.EDKind = Enums.EDKinds.PaymentOrder
			  OR ExchangeStructure.EDStructure.EDKind = Enums.EDKinds.QueryStatement
			  OR ExchangeStructure.EDStructure.EDKind = Enums.EDKinds.QueryNightStatements)
			AND ExchangeStructure.EDStructure.BankApplication = Enums.BankApplications.SberbankOnline Then
			
			Digest = ElectronicDocumentsServiceCallServer.Digest(FullFileName,
			                                                              ExchangeStructure.EDStructure.EDAgreement);
			StorageAddress = PutToTempStorage(Base64Value(Digest));
			AdditFile = AttachedFiles.AddFile(EDOwner,
			                                           "DataSchema",
			                                           ,
			                                           ,
			                                           ,
			                                           StorageAddress,
			                                           ,
			                                           ,
			                                           Catalogs.EDAttachedFiles.GetRef());
			FileParameters = New Structure;
			FileParameters.Insert("EDKind",                       Enums.EDKinds.AddData);
			FileParameters.Insert("ElectronicDocumentOwner", AddedFile);
			FileParameters.Insert("FileDescription",           "DataSchema");
			FileParameters.Insert("EDStatus",                    Enums.EDStatuses.Created);
			ChangeByRefAttachedFile(AdditFile, FileParameters, False);
		EndIf;
			
		DeleteFiles(File.FullName);
		
		If Not ValueIsFilled(AddedFile) Then
			If ExchangeStructure.Property("AdditFileFullName") Then
				DeleteFiles(ExchangeStructure.AdditFileFullName);
			EndIf;
			Continue;
		ElsIf ExchangeStructure.Property("AdditFileFullName") Then
			AdditFileCreated = CreateAttachedAdditFile(ExchangeStructure, AddedFile);
			DeleteFiles(ExchangeStructure.AdditFileFullName);
			If Not AdditFileCreated Then
				Continue;
			EndIf;
		EndIf;
		
		If ExchangeStructure.Property("FilesArray") AND ExchangeStructure.FilesArray.Count() > 0 Then
			ArchiveAddress = AdditionalFilesArchive(ExchangeStructure.FilesArray);
			If Not ArchiveAddress = Undefined Then
				AdditFile = AttachedFiles.AddFile(
								EDOwner,
								NStr("en='Additional files';ru='Дополнительные файлы'"),
								"zip",
								CreationTimeED,
								CreationTimeED,
								ArchiveAddress,
								Undefined,
								,
								Catalogs.EDAttachedFiles.GetRef());
				ParametersStructure = New Structure;
				ParametersStructure.Insert("ElectronicDocumentOwner", AddedFile);
				ParametersStructure.Insert("EDKind", Enums.EDKinds.AddData);
				ParametersStructure.Insert("EDDirection", Enums.EDDirections.Outgoing);
				ParametersStructure.Insert("EDStatus", Enums.EDStatuses.Created);
				ParametersStructure.Insert("Company", ExchangeStructure.EDStructure.Company);
				ParametersStructure.Insert("Counterparty", ExchangeStructure.EDStructure.Counterparty);
				ParametersStructure.Insert("EDAgreement", ExchangeStructure.EDStructure.EDAgreement);
				ParametersStructure.Insert("EDOwner", ExchangeStructure.EDStructure.EDOwner);
				ChangeByRefAttachedFile(AdditFile, ParametersStructure, False);
			EndIf;
		EndIf;
		
		ExchangeStructure.EDStructure.Insert("UniqueId", String(AddedFile.UUID()));
				
		If ExchangeStructure.EDStructure.EDKind = Enums.EDKinds.CustomerInvoiceNote
		 OR ExchangeStructure.EDStructure.EDKind = Enums.EDKinds.CorrectiveInvoiceNote Then
			VersionPointTypeED = Enums.EDVersionElementTypes.ESF;
		Else
			VersionPointTypeED = Enums.EDVersionElementTypes.PrimaryED;
		EndIf;
		
		ExchangeStructure.EDStructure.Insert("VersionPointTypeED", VersionPointTypeED);
		EDFormingDateBySender = "";
		If Not ExchangeStructure.EDStructure.Property("EDFormingDateBySender", EDFormingDateBySender) Then
			EDFormingDateBySender = CreationTimeED;
		EndIf;
		ExchangeStructure.EDStructure.Insert("EDFormingDateBySender", EDFormingDateBySender);
		EDStatus = Undefined;
		If Not (ExchangeStructure.EDStructure.Property("EDStatus", EDStatus) AND ValueIsFilled(EDStatus)) Then
			ExchangeStructure.EDStructure.Insert("EDStatus", Enums.EDStatuses.Created);
		EndIf;
		
		ChangeByRefAttachedFile(AddedFile, ExchangeStructure.EDStructure);
		SetRefForOwnerInStatesRegister(EDOwner, AddedFile);
		GeneratedFilesArray.Add(AddedFile);
		
	EndDo;
	
	Return GeneratedFilesArray;
	
EndFunction

// For internal use only
Function GetEDFileFullName(ExchangeStructure) Export
	
	// Generate ED as xml if this is:
	// - torg-12 as FTS;
	// - Certificate as FTS;
	// - torg-12 in an old format;
	// - exchange via EDF operator with customer invoice note.
	If ExchangeStructure.EDStructure.Property("EDFProfileSettings") Then
		EDExchangeMethod = ExchangeStructure.EDStructure.EDFProfileSettings.EDExchangeMethod;
	Else
		// Left for exchange with banks.
		EDExchangeMethod = ExchangeStructure.EDStructure.EDAgreement.EDExchangeMethod;
	EndIf;
	
	If (ExchangeStructure.EDKind = Enums.EDKinds.TORG12Seller
		  OR ExchangeStructure.EDKind = Enums.EDKinds.TORG12Customer
		  OR ExchangeStructure.EDKind = Enums.EDKinds.ActPerformer
		  OR ExchangeStructure.EDKind = Enums.EDKinds.ActCustomer
		  OR ExchangeStructure.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender
		  OR ExchangeStructure.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient
		  OR ExchangeStructure.EDKind = Enums.EDKinds.PaymentOrder)
		OR EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
		AND (ExchangeStructure.EDKind = Enums.EDKinds.CustomerInvoiceNote
		   OR ExchangeStructure.EDKind = Enums.EDKinds.CorrectiveInvoiceNote
		   OR ExchangeStructure.EDKind = Enums.EDKinds.TORG12)
		OR ExchangeStructure.EDStructure.EDFProfileSettings.EDExchangeMethod = Enums.EDExchangeMethods.QuickExchange Then
		
		FullFileName = ExchangeStructure.FullFileName;
		
	Else
		Query = New Query;
		Query.Text =
		"SELECT
		|	EDUsageAgreementsExchangeFilesFormats.FileFormat
		|FROM
		|	Catalog.EDUsageAgreements.ExchangeFilesFormats AS EDUsageAgreementsExchangeFilesFormats
		|WHERE
		|	EDUsageAgreementsExchangeFilesFormats.Ref = &EDAgreement
		|	AND EDUsageAgreementsExchangeFilesFormats.Use";
		Query.SetParameter("EDAgreement", ExchangeStructure.EDStructure.EDAgreement);
		
		UsedFormats = Query.Execute().Unload();
		
		If ExchangeStructure.EDKind = Enums.EDKinds.RightsDelegationAct
			AND UsedFormats.Find(Enums.EDExchangeFileFormats.PDF, "FileFormat") = Undefined Then
			NewLine = UsedFormats.Add();
			NewLine.FileFormat = Enums.EDExchangeFileFormats.PDF;
		EndIf;
		
		FilesToSendArray = New Array;
		
		For Each UsedRow IN UsedFormats Do
			If UsedRow.FileFormat = Enums.EDExchangeFileFormats.XML
				OR UsedRow.FileFormat = Enums.EDExchangeFileFormats.CompoundFormat Then
				FileName = ExchangeStructure.FullFileName;
			Else
				FileName = GenerateAdditDocument(ExchangeStructure, UsedRow.FileFormat);
				If FileName = Undefined Then
					MessageText = NStr("en='An error occurred while generating tabular document as %1.';ru='Ошибка формирования табличного документа в формате %1.'");
					MessageText = StrReplace(MessageText, "%1", UsedRow.FileFormat);
					OperationKind = NStr("en='tabular document generation';ru='формирования табличного документа'");
					ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(OperationKind, MessageText);
					Continue;
				EndIf;
			EndIf;
			FilesToSendArray.Add(FileName);
		EndDo;
		FullFileName = GenerateFilesZipArchive(ExchangeStructure.FullFileName, FilesToSendArray);
	EndIf;
	
	Return FullFileName;
	
EndFunction

// For internal use only
Function GenerateDocumentsXMLFiles(ObjectsArrayForExporting, ExchangeParameters, AdditParameters = "") Export
	
	ReturnStructureArray = New Array;
	EDKindsStructure = New Map;
	
	For Each CurItem IN ObjectsArrayForExporting Do
		EDKind = "";
		If Not ValueIsFilled(AdditParameters) OR Not AdditParameters.Property("EDKind", EDKind) Then
			EDParameters = ExchangeParameters.Get(CurItem.Ref);
			EDParameters.Property("EDKind", EDKind);
		EndIf;
	
		ObjectsArrayByEDKind = EDKindsStructure.Get(EDKind);
		If ObjectsArrayByEDKind = Undefined Then
			ObjectsArrayByEDKind = New Array;
		EndIf;
		ObjectsArrayByEDKind.Add(CurItem);
		EDKindsStructure.Insert(EDKind, ObjectsArrayByEDKind);
	EndDo;
	
	For Each CurItem IN EDKindsStructure Do
		GenerateXMLFile(CurItem, ReturnStructureArray, ExchangeParameters, AdditParameters);
	EndDo;
	
	Return ReturnStructureArray;
	
EndFunction

// The function generates a proxy by the proxy settings (passed parameter)
// 
// Parameters:
// 
// ProxyServerSetting - Map:
// 	UseProxy - whether
// 	the DoNotUseProxyForLocalAddresses proxy server shall be used - whether a proxy server
// 	shall be used for the local addresses UseSystemSettings - whether the Server
// 	proxy server system settings are used       - proxy
// 	server address Port         - proxy
// 	server port User - user name for authorization on
// 	the proxy server Password       - user
// password Protocol - String - protocol for which proxy server parameters are set, for example, "http", "https", "ftp"
// 
Function GenerateProxy(Protocol) Export
	
	ProxyServerSetting = GetFilesFromInternet.ProxySettingsOnServer();
	If ProxyServerSetting <> Undefined Then
		UseProxy = ProxyServerSetting.Get("UseProxy");
		UseSystemSettings = ProxyServerSetting.Get("UseSystemSettings");
		If UseProxy Then
			If UseSystemSettings Then
				// System proxy settings.
				Proxy = New InternetProxy(True);
			Else
				// Manual proxy settings.
				Proxy = New InternetProxy;
				Proxy.Set(Protocol, ProxyServerSetting["Server"], ProxyServerSetting["Port"]);
				Proxy.BypassProxyOnLocal = ProxyServerSetting["BypassProxyOnLocal"];
				Proxy.User = ProxyServerSetting["User"];
				Proxy.Password       = ProxyServerSetting["Password"];
			EndIf;
		Else
			// Do not use proxy server.
			Proxy = New InternetProxy(False);
		EndIf;
	Else
		Proxy = Undefined;
	EndIf;
	
	Return Proxy;
	
EndFunction

// Only for internal use.
Procedure CheckAccountNumberLength(AccountNo, MessagePattern, AreFillingErrors, ErrorText) Export
	
	TargetNamespaceSchema = ElectronicDocumentsReUse.CMLNamespace();
	Length = Number(ElectronicDocumentsInternal.GetXDTOschemaFieldProperty(TargetNamespaceSchema, "BankAccount", "AccountNo", XDTOFacetType.Length));

	If Length <> StrLen(TrimAll(AccountNo)) Then
		
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, Length);
		ErrorText = ?(ValueIsFilled(ErrorText), ErrorText + Chars.LF + MessageText, MessageText);
		AreFillingErrors = True;
			
	EndIf;
	
EndProcedure

Function EDFClosedForce(Val ObjectRef) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	EDStates.ObjectReference
		|FROM
		|	InformationRegister.EDStates AS EDStates
		|WHERE
		|	EDStates.ObjectReference = &ObjectReference
		|	AND EDStates.EDVersionState = VALUE(Enum.EDVersionsStates.ClosedForce)";
	Query.SetParameter("ObjectReference", ObjectRef);
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Scheduled jobs

// For internal use only
Procedure GenerateEDAttachedPackageFile(Envelop, ArrayDataStructures = Undefined) Export
	
	PreparedDocuments = Envelop.ElectronicDocuments.UnloadColumn("ElectronicDocument");
	IsArbitraryDocument = IsArbitraryEDPackage(PreparedDocuments);
	
	AccordanceFileED      = New Map;
	
	DirectoryAddress = WorkingDirectory("Send", Envelop.Ref.UUID());
	DeleteFiles(DirectoryAddress, "*");
	For Each RowED IN Envelop.ElectronicDocuments Do
		DocumentToSend = RowED.ElectronicDocument;
		
		FileData = GetFileData(DocumentToSend);
		
		// ED encryption
		If Envelop.DataEncrypted Then
			If ArrayDataStructures <> Undefined Then // Encryption is completed on client
				For Each DataItem IN ArrayDataStructures Do
					If DataItem.ElectronicDocument = RowED.ElectronicDocument Then
						FileData.FileBinaryDataRef = DataItem.FileData.FileBinaryDataRef;
					EndIf;
				EndDo;
			Else
				EncryptionParameters = GetEncryptionCertificatesAdressesArray(DocumentToSend);
				If EncryptionParameters <> Undefined Then
					Cancel = False;
					CryptoManager = ElectronicDocumentsServiceCallServer.GetCryptoManager(Cancel);
					If Cancel Then
						MessageText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("110");
						CommonUseClientServer.MessageToUser(MessageText);
						
						DeleteFiles(DirectoryAddress);
						Return;
					EndIf;
					
					CertificatesArray = New Array;
					For Each StringCertificate IN EncryptionParameters Do
						
						CertificateBinaryData = GetFromTempStorage(StringCertificate);
						Certificate = New CryptoCertificate(CertificateBinaryData);
						CertificatesArray.Add(Certificate);
					EndDo;
					
					FileBinaryData = GetFromTempStorage(FileData.FileBinaryDataRef);
					EncryptedData = CryptoManager.Encrypt(FileBinaryData, CertificatesArray);
					FileData.FileBinaryDataRef = PutToTempStorage(EncryptedData);
				EndIf;
			EndIf;
		EndIf;
		
		If IsConfirmationSending(DocumentToSend) Then
			SaveWithLatestES(DocumentToSend, FileData, DirectoryAddress, AccordanceFileED);
		Else
			SaveWithDS(DocumentToSend, FileData, DirectoryAddress, AccordanceFileED);
		EndIf;
		
	EndDo;
	
	Files = FindFiles(DirectoryAddress, "*");
	If Files.Count() = 0 Then
		DeleteFiles(DirectoryAddress);
		Return;
	EndIf;
	
	FileNameArray = New Array;
	For Each FoundFile IN Files Do
		FileNameArray.Add(FoundFile.Name);
	EndDo;
	
	ZipContainer = New ZipFileWriter();
	FileName = "EDI_" + Envelop.UUID();
	FileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(FileName);
	ZipContainer.Open(DirectoryAddress + FileName + ".zip");
	
	For Each File IN Files Do
		ZipContainer.Add(File.FullName);
	EndDo;
	
	AccordanceOfAttachments    = GetFilesAndSignaturesCorrespondence(FileNameArray);
	ParticipantsDescriptionText = CreateEDInventoryText(
									Envelop,
									AccordanceOfAttachments,
									AccordanceFileED,
									IsArbitraryDocument);
	
	FileCopy(ParticipantsDescriptionText, DirectoryAddress + "packageDescription.xml");
	DeleteFiles(ParticipantsDescriptionText);
	ZipContainer.Add(DirectoryAddress + "packageDescription.xml");
	
	ZipContainer.Write();
	
	PlaceEDPackageIntoEnvelop(Envelop, DirectoryAddress + FileName + ".zip");
	DeleteFiles(DirectoryAddress);
	
EndProcedure

// For internal use only
Function UnpackEDPackageOnServer(EDPackage, EncryptionStructure, UnpackingData = Undefined)
	
	ReturnArray = New Array;
	
	Try
		
		If UnpackingData = Undefined Then
			UnpackingData = ElectronicDocumentsServiceCallServer.ReturnArrayBinaryDataPackage(EDPackage);
		EndIf;
		
		If UnpackingData = Undefined Then
			Return Undefined;
		EndIf;
		
		CryptographyManagerReceived = False;
		PerformCryptoOperationsAtServer = False;
		ServerAuthorizationPerform = False;
		ElectronicDocumentsServiceCallServer.VariablesInitialise(PerformCryptoOperationsAtServer, ServerAuthorizationPerform);
		If PerformCryptoOperationsAtServer OR ServerAuthorizationPerform Then
			Try
				CryptoManager = ElectronicDocumentsServiceCallServer.GetCryptoManager();
				CryptographyManagerReceived = True;
			Except
				CryptoManager = Undefined;
			EndTry;
		EndIf;
	
		IsCryptofacilityOnClient = False;
		DataType = Undefined;
		IsDataType = UnpackingData.Property("DataType", DataType);
		If IsDataType AND DataType <> "ED" AND DataType <> "Signature" Then
			ReturnStructure       = New Structure;
			AccordanceOfEdAndSignatures = New Map;
			ProcessedDocumentsCount = ElectronicDocumentsServiceCallServer.HandleBinaryDataPackageOperatorOfEDO(
																									EDPackage,
																									UnpackingData,
																									IsCryptofacilityOnClient,
																									AccordanceOfEdAndSignatures,
																									ReturnStructure);
			AddedFilesArray             = ReturnStructure.AddedFilesArray;
			AddedFilesArrayForNotifications = ReturnStructure.AddedFilesArrayForNotifications;
			ArrayOfOwners                    = ReturnStructure.ArrayOfOwners;
			If TypeOf(AddedFilesArray) = Type("Array") AND AddedFilesArray.Count() > 0
				AND Not ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer()
				AND CryptographyManagerReceived Then
				
					If AccordanceOfEdAndSignatures.Count() > 0 Then
						For Each Item IN AccordanceOfEdAndSignatures Do
							For Each SignatureData IN Item.Value Do
								SignatureCertificates = CryptoManager.GetCertificatesFromSignature(SignatureData);
								If SignatureCertificates.Count() <> 0 Then
									Certificate = SignatureCertificates[0];
									SignatureInstallationDate = SignatureInstallationDate(SignatureData);
									SignatureInstallationDate = ?(ValueIsFilled(SignatureInstallationDate), SignatureInstallationDate, CurrentSessionDate());
									PrintBase64 = Base64String(Certificate.Imprint);
									UserPresentation = DigitalSignatureClientServer.SubjectPresentation(Certificate);
									ElectronicDocumentsServiceCallServer.AddInformationAboutSignature(
																					Item.Key,
																					SignatureData,
																					PrintBase64,
																					SignatureInstallationDate,
																					"",
																					,
																					UserPresentation,
																					Certificate.Unload());
								EndIf;
							EndDo;
						EndDo
					EndIf;
					
					For Each ED IN AddedFilesArray Do
						ElectronicDocumentsServiceCallServer.DetermineSignaturesStatuses(ED);
					EndDo;
			EndIf;
			
			// ReceivedData from EDF operator
			If AddedFilesArrayForNotifications.Count() > 0 Then
				EDKind = PredefinedValue("Enum.EDKinds.NotificationAboutReception");
				ElectronicDocumentsClientServer.GenerateSignAndSendServiceED(AddedFilesArrayForNotifications, EDKind);
			EndIf;
			
			Return ProcessedDocumentsCount;
		EndIf;
		
		BinaryDataArray = UnpackingData.StructureOfBinaryData;
		NotificationsBinaryDataArray = UnpackingData.StructureOfBinaryDataAnnouncements;
		
		If BinaryDataArray.Count() = 0 Then
			EDAndSignaturesDataArray = New Array;
			ElectronicDocumentsServiceCallServer.ProcessDocumentsConfirmationsAtServer(
															UnpackingData.MapFileParameters,
															EDPackage,
															UnpackingData.PackageFiles,
															EDAndSignaturesDataArray);
			If EDAndSignaturesDataArray.Count() > 0 AND CryptographyManagerReceived Then
				For Each Item IN EDAndSignaturesDataArray Do
					SignatureCertificates = CryptoManager.GetCertificatesFromSignature(Item.SignatureData);
					If SignatureCertificates.Count() <> 0 Then
						Certificate = SignatureCertificates[0];
						SignatureInstallationDate = SignatureInstallationDate(Item.SignatureData);
						SignatureInstallationDate = ?(ValueIsFilled(SignatureInstallationDate), SignatureInstallationDate, CurrentSessionDate());
						PrintBase64 = Base64String(Certificate.Imprint);
						UserPresentation = DigitalSignatureClientServer.SubjectPresentation(Certificate);
						ElectronicDocumentsServiceCallServer.AddInformationAboutSignature(
																		Item.ElectronicDocument,
																		Item.SignatureData,
																		PrintBase64,
																		SignatureInstallationDate,
																		"",
																		,
																		UserPresentation,
																		Certificate.Unload());
					EndIf;
				EndDo
			EndIf;
		EndIf;
		
		If NotificationsBinaryDataArray.Count() > 0 Then
			For Each DataStructure IN NotificationsBinaryDataArray Do
				
				// Process notifications from
				// the operator It can be if we receive notifications from the customer about ESF receipt
				SignsStructuresArray = ElectronicDocumentsServiceCallServer.GetSignaturesDataCorrespondence(
					DataStructure.FileName, UnpackingData.PackageFiles, DataStructure.BinaryData,
					UnpackingData.MapFileParameters, True);
				
				If SignsStructuresArray <> Undefined Then
					ErrorFlag = False;
					For Each SignStructure IN SignsStructuresArray Do
						If SignStructure.BinaryDataSignatures <> Undefined Then
							Try
								VerifySignature(CryptoManager, SignStructure.FileBinaryData,
									SignStructure.BinaryDataSignatures);
							Except
								MessageText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("114");
								ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
									NStr("en='Signature checkup';ru='проверка подписи'"), DetailErrorDescription(ErrorInfo()), MessageText);
								ErrorFlag = True;
								Break;
							EndTry;
						EndIf;
					EndDo;
					
					If ErrorFlag Then
						Return Undefined;
					EndIf;
				EndIf;
				
				AddedFilesArray = ElectronicDocumentsServiceCallServer.AddDataByEDPackage(EDPackage,
					SignsStructuresArray, DataStructure, UnpackingData.MapFileParameters,
					UnpackingData.PackageFiles);
			EndDo;
		EndIf;
		
		IsUnpackingError = False;
		
		For Each DataStructure IN BinaryDataArray Do
			If EncryptionStructure <> Undefined Then
				If EncryptionStructure.Property("UserPassword") Then
					If ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer() Then
						DecryptedBinaryData = ElectronicDocumentsServiceCallServer.DecryptedData(
							DataStructure.BinaryData, EncryptionStructure.UserPassword);
						If DecryptedBinaryData = Undefined Then
							Return Undefined;
						EndIf;
					Else
						// If the crypto operation execution context is "on client", do not decrypt.
						Return Undefined;
					EndIf;
					DataStructure.BinaryData = DecryptedBinaryData;
				Else
					MessagePattern = NStr("en='%1. Password to decryption certificate is not specified: %2.';ru='%1. Не указан пароль к сертификату расшифровки: %2.'");
					DetailedMessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
						ElectronicDocumentsServiceCallServer.GetMessageAboutError("113"), EncryptionStructure.Certificate);
					ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
						NStr("en='ED package details';ru='расшифровка пакета ЭД'"), DetailedMessageText);
					Return Undefined;
				EndIf;
			EndIf;
		
		SignsStructuresArray = ElectronicDocumentsServiceCallServer.GetSignaturesDataCorrespondence(
			DataStructure.FileName, UnpackingData.PackageFiles, DataStructure.BinaryData,
			UnpackingData.MapFileParameters);
		
		AccordanceOfEdAndSignatures = New Map;
		AddedFilesArray = ElectronicDocumentsServiceCallServer.AddDataByEDPackage(
			EDPackage,
			SignsStructuresArray,
			DataStructure,
			UnpackingData.MapFileParameters,
			UnpackingData.PackageFiles,
			IsUnpackingError,
			IsCryptofacilityOnClient,
			AccordanceOfEdAndSignatures);
		
		If Not AddedFilesArray = Undefined AND AddedFilesArray.Count() > 0
			AND CryptographyManagerReceived
			AND Not ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer() Then
			If AccordanceOfEdAndSignatures.Count() > 0 Then
				For Each Item IN AccordanceOfEdAndSignatures Do
					For Each SignatureData IN Item.Value Do
						SignatureCertificates = CryptoManager.GetCertificatesFromSignature(SignatureData);
						If SignatureCertificates.Count() <> 0 Then
							Certificate = SignatureCertificates[0];
							SignatureInstallationDate = SignatureInstallationDate(SignatureData);
							SignatureInstallationDate = ?(ValueIsFilled(SignatureInstallationDate), SignatureInstallationDate, CurrentSessionDate());
							PrintBase64 = Base64String(Certificate.Imprint);
							UserPresentation = DigitalSignatureClientServer.SubjectPresentation(Certificate);
							ElectronicDocumentsServiceCallServer.AddInformationAboutSignature(
																			Item.Key,
																			SignatureData,
																			PrintBase64,
																			SignatureInstallationDate,
																			"",
																			,
																			UserPresentation,
																			Certificate.Unload());
						EndIf;
					EndDo;
				EndDo
			EndIf;
			For Each ED IN AddedFilesArray Do
				ElectronicDocumentsServiceCallServer.DetermineSignaturesStatuses(ED);
			EndDo;
		EndIf;
		If Not IsUnpackingError Then
			If ValueIsFilled(DataType)
				AND UnpackingData.MapFileParameters.Get("IsArbitraryED") = Undefined
				AND ElectronicDocumentsServiceCallServer.GetEDExchangeMethodOfEDPackage(
				EDPackage) = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom") Then
				
				EDKind = PredefinedValue("Enum.EDKinds.NotificationAboutReception");
				ElectronicDocumentsClientServer.GenerateSignAndSendServiceED(AddedFilesArray, EDKind);
			EndIf;
			
			AddArray(ReturnArray, AddedFilesArray);
		EndIf;
	EndDo;
		
		If IsUnpackingError Then
			Return 0;
		EndIf;
		
		ElectronicDocumentsServiceCallServer.SetPackageStatus(EDPackage,
			PredefinedValue("Enum.EDPackagesStatuses.Unpacked"));
		
	Except
		MessagePattern = NStr("en='An error occurred while unpacking incoming ED pack.
		|%1.';ru='Ошибка распаковки входящего пакета ЭД.
		|%1.'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
			BriefErrorDescription(ErrorInfo()));
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
			NStr("en='incoming ED package unpacking';ru='распаковка входящего пакета ЭД'"), DetailErrorDescription(ErrorInfo()), MessageText);
	EndTry;
	
	Return ReturnArray.Count();
	
EndFunction

Function DeterminePreparedToSendED()
	
	PreparedEDQuery = New Query;
	PreparedEDQuery.Text =
	"SELECT ALLOWED
	|	EDPackage.Ref AS Ref
	|FROM
	|	Document.EDPackage AS EDPackage
	|WHERE
	|	EDPackage.DeletionMark = FALSE
	|	AND EDPackage.PackageStatus = &PackageStatus
	|	AND Not EDPackage.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)";
	PreparedEDQuery.SetParameter("PackageStatus", Enums.EDPackagesStatuses.PreparedToSending);
	
	Result = PreparedEDQuery.Execute().Unload().UnloadColumn("Ref");
	
	Return Result;
	
EndFunction

Function IsArbitraryEDPackage(DocumentArray)
	
	For Each Document IN DocumentArray Do
		If TypeOf(Document.FileOwner) = Type("DocumentRef.RandomED")
			AND Document.FileOwner.Direction = Enums.EDDirections.Outgoing Then
			
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function FindSignatureFileNames(DataFileName, SignatureFileNames)
	
	SignatureNames = New Array;
	
	File = New File(DataFileName);
	BaseName = File.BaseName;
	
	For Each SignatureFileName IN SignatureFileNames Do
		If Find(SignatureFileName, BaseName) > 0 Then
			SignatureNames.Add(SignatureFileName);
		EndIf;
	EndDo;
	
	For Each SignatureFileName IN SignatureNames Do
		SignatureFileNames.Delete(SignatureFileNames.Find(SignatureFileName));
	EndDo;
	
	Return SignatureNames;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with DS certificates

Procedure SaveSignatures(FileRef,
							FullFileName,

							SignsStructuresArray,
							DirectoryAddress,
							AccordanceFileED,
							WithoutSourceFile = False,
							IsArbitraryED = False)
	
	MainFile = New File(FullFileName);
	Path = MainFile.Path;
	NameArray = New Array;
	
	ServerPlatformType = CommonUseReUse.ServerPlatformType();
	
	If Not WithoutSourceFile Then
		NameArray.Add(MainFile.Name);
	EndIf;
	
	Ct = 0;
	For Each SignStructure IN SignsStructuresArray Do
		SignatureFileName = SignStructure.SignatureFileName;
		
		Ct = Ct + 1;
		If IsBlankString(SignatureFileName) Then
			If ValueIsFilled(IsArbitraryED) AND IsArbitraryED AND Right(FullFileName, 4) = ".zip" Then
				SignatureFileName = String(FileRef)+"DS" + "-" + String(SignStructure.CertificateIsIssuedTo) + ".p7s";
			Else
				SignatureFileName = String(FileRef) + "-" + Ct + ".p7s";
			EndIf;
		EndIf;
		
		SignatureFileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(SignatureFileName, "");
		
		FullPathOfSignature = Path;
		CommonUseClientServer.AddFinalPathSeparator(FullPathOfSignature, ServerPlatformType);
		FullPathOfSignature = FullPathOfSignature + SignatureFileName;
		
		FileByName = New File(FullPathOfSignature);
		FileExists = FileByName.Exist();
		
		Counter = 0;
		SignatureFileNameWithoutPostfix = FileByName.BaseName;
		While FileExists Do
			Counter = Counter + 1;
			
			SignatureFileName = SignatureFileNameWithoutPostfix + " (" + String(Counter) + ")" + ".p7s";
			SignatureFileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(SignatureFileName, "");
			
			FullPathOfSignature = Path;
			CommonUseClientServer.AddFinalPathSeparator(FullPathOfSignature, ServerPlatformType);
			FullPathOfSignature = FullPathOfSignature + SignatureFileName;
			
			FileForVerification = New File(FullPathOfSignature);
			FileExists = FileForVerification.Exist();
		EndDo;
		
		File = New File(FullPathOfSignature);
		NameArray.Add(File.Name);
		
		If TypeOf(AccordanceFileED) = Type("Map") Then
			EDParametersStructure = New Structure;
			EDParametersStructure.Insert("EDNumber", FileRef.EDNumber);
			EDParametersStructure.Insert("UniqueId", FileRef.UniqueId);
			
			AccordanceFileED.Insert(File.Name, EDParametersStructure);
		Else
			// AccordanceFileED - ED files structure.
			NewRow = AccordanceFileED.MainFileSignatures.Add();
			NewRow.Name = "";
			NewRow.Path = File.Name
		EndIf;
		
		PathToFile = File.Path;
		If Right(PathToFile,1) <> "\" Then
			PathToFile = PathToFile + "\";
		EndIf;
		
		BinaryDataSignatures = GetFromTempStorage(SignStructure.SignatureAddress);
		BinaryDataSignatures.Write(FullPathOfSignature);
		DeleteFromTempStorage(SignStructure.SignatureAddress);
		
	EndDo;
	
EndProcedure

Function GetFilesAndSignaturesCorrespondence(FileNames)
	
	Result = New Map;
	
	SignatureFileNames = New Array;
	DataFileNames   = New Array;
	
	For Each FileName IN FileNames Do
		If Right(FileName, 3) = "p7s" Then
			SignatureFileNames.Add(FileName);
		Else
			DataFileNames.Add(FileName);
		EndIf;
	EndDo;
	
	For IndexA = 1 To DataFileNames.Count() Do
		MaxIndex = IndexA;
		For IndexB = IndexA+1 To DataFileNames.Count() Do
			If StrLen(DataFileNames[MaxIndex - 1]) > StrLen(DataFileNames[IndexB - 1]) Then
				MaxIndex = IndexB;
			EndIf;
		EndDo;
		svop = DataFileNames[IndexA - 1];
		DataFileNames[IndexA - 1] = DataFileNames[MaxIndex - 1];
		DataFileNames[MaxIndex - 1] = svop;
	EndDo;
	
	For Each DataFileName IN DataFileNames Do
		Result.Insert(DataFileName, FindSignatureFileNames(DataFileName, SignatureFileNames));
	EndDo;
	
	For Each SignatureFileName IN SignatureFileNames Do
		Result.Insert(SignatureFileName, New Array);
	EndDo;
	
	Return Result;
	
EndFunction

Function SaveFileAs(FileData,
						DirectoryName,
						AttachedFile = Undefined,
						IsArbitraryED = Undefined,
						AccordanceFileED = Undefined)
	
	File = New File(DirectoryName);
	If Not File.Exist() Then
		CreateDirectory(DirectoryName);
	EndIf;
	
	SizeInMB = FileData.Size / (1024 * 1024);
	
	ReceivedFileName = StrReplace(FileData.FileName, "..", ".");
	FileBinaryData = GetFromTempStorage(FileData.FileBinaryDataRef);
	FileBinaryData.Write(DirectoryName + ReceivedFileName);
	
	If ValueIsFilled(AttachedFile) Then
		If TypeOf(AccordanceFileED) = Type("Map") Then
			EDParametersStructure = New Structure;
			EDParametersStructure.Insert("EDNumber", AttachedFile.EDNumber);
			EDParametersStructure.Insert("UniqueId", AttachedFile.UniqueId);
			
			AccordanceFileED.Insert(FileData.FileName, EDParametersStructure);
		Else
			AccordanceFileED.Insert("MainFile", FileData.FileName);
		EndIf;
		
		PathToFile = File.Path;
		If Right(PathToFile,1) <> "\" Then
			PathToFile = PathToFile + "\";
		EndIf;
	EndIf;
	
	If IsArbitraryED = True Then
		
		FileName      = FileData.Description;
		ContainerName = DirectoryName + FileName + ".zip";
		ArchiveName     = FileName + ".zip";
		
		If FileName + ".zip" = ReceivedFileName Then
			ContainerName = DirectoryName+FileName+"DS.zip";
			ArchiveName     = FileName + "DS.zip";
		EndIf;
		
		ZipContainer = New ZipFileWriter(ContainerName);
		ZipContainer.Add(DirectoryName + ReceivedFileName );
		
		ZipContainer.Write();
		If FileName + ".zip" = ReceivedFileName Then
			DeleteFiles(DirectoryName + ReceivedFileName);
		EndIf;
		If ValueIsFilled(AttachedFile) Then
			EDParametersStructure = New Structure;
			EDParametersStructure.Insert("EDNumber", AttachedFile.EDNumber);
			EDParametersStructure.Insert("UniqueId", AttachedFile.UniqueId);
			
			AccordanceFileED.Insert(ArchiveName, EDParametersStructure);
		EndIf;
	EndIf;
	
	Return DirectoryName + ReceivedFileName;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Add objects to the attached files

Procedure GenerateXMLFile(CurItem, ReturnStructureArray, ExchangeParameters, AdditParameters)
	
	ObjectsArrayForExporting = CurItem.Value;
	
	CML2SchemeVersion = ElectronicDocumentsReUse.CML2SchemeVersion();
	CML402SchemaVersion = ElectronicDocumentsReUse.CML402SchemaVersion();
	
	For Each ObjectForExport IN ObjectsArrayForExporting Do
		
		If CurItem.Key = Enums.EDKinds.ProductsDirectory AND Not AdditParameters.Property("QuickExchange") Then
			EDExchangeSettings = DetermineEDExchangeSettingsBySource(ObjectForExport);
		Else
			EDExchangeSettings = ExchangeParameters.Get(ObjectForExport);
		EndIf;
		If Not ValueIsFilled(EDExchangeSettings) Then
			Continue
		EndIf;
		
		If EDExchangeSettings.EDFProfileSettings.EDExchangeMethod <> Enums.EDExchangeMethods.QuickExchange Then
			ElectronicDocumentsServiceCallServer.SetEDNewVersion(ObjectForExport, , True);
		EndIf;

		If CurItem.Key = Enums.EDKinds.TORG12 Then
			ReturnStructure = ElectronicDocumentsInternal.GenerateInvoiceByDocument(ObjectForExport,
				EDExchangeSettings);
				
		ElsIf CurItem.Key = Enums.EDKinds.TORG12Seller Then
			ReturnStructure = ElectronicDocumentsInternal.FormTORG12SellerFTS(ObjectForExport,
				EDExchangeSettings);
				
		ElsIf CurItem.Key = Enums.EDKinds.AgreementAboutCostChangeSender Then
			ReturnStructure = ElectronicDocumentsInternal.GenerateCorDocumentByDocument(ObjectForExport,
				EDExchangeSettings);
				
		ElsIf CurItem.Key = Enums.EDKinds.InvoiceForPayment Then
			
			If EDExchangeSettings.FormatVersion = CML2SchemeVersion Then
				
				ReturnStructure = ElectronicDocumentsInternal.GenerateInvoiceForPaymentByDocument(ObjectForExport,
																											EDExchangeSettings);
			Else
				ReturnStructure = ElectronicDocumentsInternal.DeleteGenerateInvoiceForPaymentByDocument(ObjectForExport,
																											EDExchangeSettings);

			EndIf;
			
		ElsIf CurItem.Key = Enums.EDKinds.PriceList Then
			
			If EDExchangeSettings.FormatVersion = CML2SchemeVersion Then
				
				ReturnStructure = ElectronicDocumentsInternal.GeneratePriceListByDocument(ObjectForExport,
																									EDExchangeSettings);
			Else
				
				ReturnStructure = ElectronicDocumentsInternal.DeleteGeneratePriceListFromDocument(ObjectForExport,
																									EDExchangeSettings);
				
			EndIf;

		ElsIf CurItem.Key = Enums.EDKinds.ProductOrder Then
			
			If EDExchangeSettings.FormatVersion = CML2SchemeVersion Then
				
				ReturnStructure = ElectronicDocumentsInternal.GenerateOrderToSupplierByDocument(ObjectForExport,
																											EDExchangeSettings);

			Else
				ReturnStructure = ElectronicDocumentsInternal.DeleteGenerateOrderToSupplierByDocument(ObjectForExport,
																											EDExchangeSettings);
			EndIf;
			
		ElsIf CurItem.Key = Enums.EDKinds.ResponseToOrder Then
			
			If EDExchangeSettings.FormatVersion = CML2SchemeVersion Then
				
				ReturnStructure = ElectronicDocumentsInternal.GenerateClientOrderByDocument(ObjectForExport,
																											EDExchangeSettings);
			Else
				ReturnStructure = ElectronicDocumentsInternal.DeleteGenerateCustomerOrderByDocument(ObjectForExport,
																												EDExchangeSettings);
			EndIf;
			
		ElsIf CurItem.Key = Enums.EDKinds.ComissionGoodsSalesReport Then
			
			If EDExchangeSettings.FormatVersion = CML2SchemeVersion Then
				
				ReturnStructure = ElectronicDocumentsInternal.GenerateReportAboutCommissionGoodsSalesByDocument(ObjectForExport,
																									EDExchangeSettings);
			Else
				
				ReturnStructure = ElectronicDocumentsInternal.DeleteGenerateReportOnCommissionGoodsSalesByDocument(ObjectForExport,
																									EDExchangeSettings);
				
			EndIf;
	
		ElsIf CurItem.Key = Enums.EDKinds.ComissionGoodsWriteOffReport Then
			
			If EDExchangeSettings.FormatVersion = CML2SchemeVersion Then
				
				ReturnStructure = ElectronicDocumentsInternal.GenerateComissionGoodsWriteOffReportByDocument(
																						ObjectForExport, EDExchangeSettings);
			Else
				ReturnStructure = ElectronicDocumentsInternal.DeleteGenerateComissionGoodsWriteOffReportByDocument(
																						ObjectForExport, EDExchangeSettings);
																						
			EndIf;
			
		ElsIf CurItem.Key = Enums.EDKinds.ProductsDirectory Then
			
			If EDExchangeSettings.FormatVersion = CML2SchemeVersion Then
				
				ReturnStructure = ElectronicDocumentsInternal.GenerateProductsAndServicesCatalog(EDExchangeSettings, AdditParameters);
			
			ElsIf EDExchangeSettings.FormatVersion = CML402SchemaVersion
					OR Not ValueIsFilled(EDExchangeSettings.FormatVersion) Then
					
				ProductsDirectory = "";
				AdditParameters.Property("ProductsDirectory", ProductsDirectory);
				CatalogProductsList = GetFromTempStorage(ProductsDirectory);
				ReturnStructure = ElectronicDocumentsInternal.DeleteGenerateProductsAndServicesCatalog(ObjectForExport,
				CatalogProductsList, EDExchangeSettings);
			EndIf;
			
		ElsIf CurItem.Key = Enums.EDKinds.AcceptanceCertificate Then
			ReturnStructure = ElectronicDocumentsInternal.GenerateAcceptanceCertificateByDocument(ObjectForExport,
				EDExchangeSettings);
				
		ElsIf CurItem.Key = Enums.EDKinds.ActPerformer Then
			ReturnStructure = ElectronicDocumentsInternal.GenerateAct501PerformerFTS(ObjectForExport,
				EDExchangeSettings);
				
		ElsIf CurItem.Key = Enums.EDKinds.GoodsTransferBetweenCompanies Then
			ReturnStructure = ElectronicDocumentsInternal.GenerateGoodsTransferBetweenCompanies(ObjectForExport,
				EDExchangeSettings);
				
		ElsIf CurItem.Key = Enums.EDKinds.ProductsReturnBetweenCompanies Then
			ReturnStructure = ElectronicDocumentsInternal.GenerateGoodsReturnBetweenCompanies(ObjectForExport,
				EDExchangeSettings);
				
		ElsIf CurItem.Key = Enums.EDKinds.CustomerInvoiceNote
			OR CurItem.Key = Enums.EDKinds.CorrectiveInvoiceNote Then
			ReturnStructure = ElectronicDocumentsInternal.GenerateInvoiceFTS(ObjectForExport, EDExchangeSettings);
			
		ElsIf CurItem.Key = Enums.EDKinds.PaymentOrder Then
			ReturnStructure = ElectronicDocumentsInternal.GeneratePaymentOrder(ObjectForExport, EDExchangeSettings);
			
		ElsIf CurItem.Key = Enums.EDKinds.RightsDelegationAct Then
			ReturnStructure = ElectronicDocumentsInternal.FormTransferOfAuthorityAct(ObjectForExport,
				EDExchangeSettings);
				
		ElsIf Upper(CurItem.Key) = Upper("CompanyAttributes") Then
			ReturnStructure = ElectronicDocumentsInternal.GenerateCompanyInvoice(ObjectForExport,
				EDExchangeSettings);

		EndIf;
		
		If ValueIsFilled(ReturnStructure) Then
			EDFScheduleVersion = "";
			If Not EDExchangeSettings.Property("EDFScheduleVersion", EDFScheduleVersion)
				OR Not ValueIsFilled(EDFScheduleVersion) Then
				EDFScheduleVersion = Enums.Exchange1CRegulationsVersion.Version20;
			EndIf;
			ReturnStructure.EDStructure.Insert("EDFScheduleVersion", EDFScheduleVersion);
			
			ReturnStructureArray.Add(ReturnStructure);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure SetRefForOwnerInStatesRegister(ObjectReference, ElectronicDocument)
	
	SetPrivilegedMode(True);
	
	If Not ElectronicDocumentsServiceCallServer.ThisIsServiceDocument(ElectronicDocument) Then
		RecordSet = InformationRegisters.EDStates.CreateRecordSet();
		RecordSet.Filter.ObjectReference.Set(ObjectReference);
		RecordSet.Read();
		
		If RecordSet.Count()=0 Then
			NewSetRecord = RecordSet.Add();
			NewSetRecord.ObjectReference = ObjectReference;
		Else
			NewSetRecord = RecordSet.Get(0);
		EndIf;
		
		NewSetRecord.ElectronicDocument = ElectronicDocument;
		RecordSet.Write();
	EndIf;
	
EndProcedure

Function GenerateAdditDocument(ExchangeStructure, FormatDescription)  Export
	
	InitialDocumentFile = New File(ExchangeStructure.FullFileName);
	InitialDocumentName = InitialDocumentFile.BaseName;
	
	SpreadsheetDocument = ElectronicDocumentsInternal.GenerateEDPrintForm(
		ExchangeStructure.FullFileName, ExchangeStructure.EDStructure.EDDirection);
	If SpreadsheetDocument <> Undefined Then
		AdditFileProcessingStructure = DetermineSavingTypeByEnumeration(FormatDescription);
		
		FileOfSaving = InitialDocumentFile.Path + InitialDocumentName +"."
			+ AdditFileProcessingStructure.ExtensionPresentation;
		
		SpreadsheetDocument.Write(FileOfSaving,AdditFileProcessingStructure.SavingTypePresentation);
	Else
		MessageText = NStr("en='Unable to generate tabular document (for more information, see Events log monitor).';ru='Не удалось сформировать табличный документ (подробности см. в Журнале регистрации).'");
		CommonUseClientServer.MessageToUser(MessageText);
		FileOfSaving = Undefined;
	EndIf;
	
	Return FileOfSaving;
	
EndFunction

Function DetermineSavingTypeByEnumeration(SavingType)
	
	ReturnStructure = New Structure("ExtensionPresentation, SavingTypePresentation");
	If SavingType = Enums.EDExchangeFileFormats.DOCX Then
		ReturnStructure.ExtensionPresentation = "docx";
		ReturnStructure.SavingTypePresentation = SpreadsheetDocumentFileType.DOCX;
	ElsIf SavingType = Enums.EDExchangeFileFormats.HTML Then
		ReturnStructure.ExtensionPresentation = "html";
		ReturnStructure.SavingTypePresentation = SpreadsheetDocumentFileType.HTML;
	ElsIf SavingType = Enums.EDExchangeFileFormats.XLS Then
		ReturnStructure.ExtensionPresentation = "xls";
		ReturnStructure.SavingTypePresentation = SpreadsheetDocumentFileType.XLS;
	ElsIf SavingType = Enums.EDExchangeFileFormats.MXL Then
		ReturnStructure.ExtensionPresentation = "mxl";
		ReturnStructure.SavingTypePresentation = SpreadsheetDocumentFileType.MXL;
	ElsIf SavingType = Enums.EDExchangeFileFormats.ODS Then
		ReturnStructure.ExtensionPresentation = "ods";
		ReturnStructure.SavingTypePresentation = SpreadsheetDocumentFileType.ODS;
	ElsIf SavingType = Enums.EDExchangeFileFormats.PDF Then
		ReturnStructure.ExtensionPresentation = "pdf";
		ReturnStructure.SavingTypePresentation = SpreadsheetDocumentFileType.PDF;
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

Function GenerateFilesZipArchive(MainFileName, FilesArray)
	
	Try
		File = New File(MainFileName);
		ZipArchiveFile = StrReplace(MainFileName, File.Extension, ".zip");
		ZipRecord = New ZipFileWriter(ZipArchiveFile);
		For Each FileName IN FilesArray Do
			ZipRecord.Add(FileName);
		EndDo;
		ZipRecord.Write();
		Return ZipArchiveFile;
	Except
		MessageText = BriefErrorDescription(ErrorInfo())
			+ NStr("en=' (see details in Event log monitor).';ru=' (подробности см. в Журнале регистрации).'");
		ErrorText = DetailErrorDescription(ErrorInfo()) + Chars.LF
			+ NStr("en='Check whether the English language is present in OS regional
		|settings for non-Unicode applications and there is access to the temporary files directory.';ru='Проверьте поддержку русского языка в региональных настройках ОС для non-Unicode programs
		|и наличие доступа к каталогу временных файлов.'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='the archive file record on a disk';ru='запись файла архива на диск'"),
																					ErrorText,
																					MessageText);
		
		Return "";
	EndTry;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Send messages

Function CreateEDInventoryText(Envelop, AccordanceOfAttachments, AccordanceFileED, IsArbitraryDocument)
	
	AttributesOfEnvelope = CommonUse.ObjectAttributesValues(Envelop, "Sender, Recipient");
	EDExchangeCenter =    AttributesOfEnvelope.Sender;
	EDExchangeParticipant = AttributesOfEnvelope.Recipient;
	
	FileName = TemporaryFileCurrentName("xml");
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(FileName);
	XMLWriter.WriteStartElement("TransportInformation");
	// Document name
	XMLWriter.WriteStartElement("GenerationDateAndTime");
	XMLWriter.WriteText(ConvertDateToCanonicalKind(CurrentSessionDate()));
	XMLWriter.WriteEndElement();
	// Document ID
	XMLWriter.WriteStartElement("ID");
	XMLWriter.WriteText(String(Envelop.UUID()));
	XMLWriter.WriteEndElement();	
	// Date received
	XMLWriter.WriteStartElement("Sender");
	XMLWriter.WriteText(EDExchangeCenter);
	XMLWriter.WriteEndElement();
	XMLWriter.WriteStartElement("Recipient");
	XMLWriter.WriteText(EDExchangeParticipant);
	XMLWriter.WriteEndElement();
	// Random document text
	If IsArbitraryDocument Then 
		Text = Envelop.ElectronicDocuments[0].ElectronicDocument.FileOwner.Text;
		XMLWriter.WriteStartElement("Text");
		XMLWriter.WriteText(Text);
		XMLWriter.WriteEndElement();
	EndIf;	
	
	// Encryption by documents
	
	XMLWriter.WriteStartElement("EncriptionSettings");
	For Each EnclosureDocument IN Envelop.ElectronicDocuments Do
		XMLWriter.WriteStartElement("EncryptionDocument");
		XMLWriter.WriteText(String(EnclosureDocument.ElectronicDocument));
		
		XMLWriter.WriteStartElement("Encrypted");
		If Envelop.DataEncrypted Then
			XMLWriter.WriteText("Yes");
		Else
			XMLWriter.WriteText("No");
		EndIf;
		XMLWriter.WriteEndElement();
		
		If Envelop.DataEncrypted Then
			XMLWriter.WriteStartElement("EncryptionCertificate");
			XMLWriter.WriteText(String(Envelop.EncryptionCertificate));
			XMLWriter.WriteEndElement();
		EndIf;
		XMLWriter.WriteEndElement();
	EndDo;
	XMLWriter.WriteEndElement();
	
	XMLWriter.WriteStartElement("DocumentsAndSignatures");
	For Each Attachment IN AccordanceOfAttachments Do
		XMLWriter.WriteStartElement("Document");
		XMLWriter.WriteText(Attachment.Key);
		
		EDParametersStructure = AccordanceFileED.Get(Attachment.Key);
		EDNumber = ""; UniqueId = "";
		If EDParametersStructure.Property("EDNumber", EDNumber) AND ValueIsFilled(EDNumber) Then
			XMLWriter.WriteStartElement("EDNumber");
			XMLWriter.WriteText(EDNumber);
			XMLWriter.WriteEndElement();
		EndIf;
		If EDParametersStructure.Property("UniqueId", UniqueId) AND ValueIsFilled(UniqueId) Then
			XMLWriter.WriteStartElement("UniqueId");
			XMLWriter.WriteText(UniqueId);
			XMLWriter.WriteEndElement();
		EndIf;
		
		For Each Signature IN Attachment.Value Do
			XMLWriter.WriteStartElement("Signature");
			XMLWriter.WriteText(Signature);
			XMLWriter.WriteEndElement();
		EndDo;
		XMLWriter.WriteEndElement();
	EndDo;
	XMLWriter.WriteEndElement();
	
	XMLWriter.WriteEndElement();
	XMLWriter.Close();
	
	Return FileName;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Receive email

Procedure ProcessReceivingConfirmation(Message, IsFile = False)
	
	If IsFile Then
		XMLReader = New XMLReader;
		XMLReader.OpenFile(Message.FullName);
		While XMLReader.Read() Do
			If XMLReader.LocalName = "ElectronicDocument" AND XMLReader.NodeType = XMLNodeType.StartElement Then
				XMLReader.Read();
				DocumentEDPackage = DetermineConfirmedEDPackage(XMLReader.Value);
			EndIf;
			If XMLReader.LocalName = "DateReceived" AND XMLReader.NodeType = XMLNodeType.StartElement Then
				XMLReader.Read();
				DateReceived = Date(XMLReader.Value);
			EndIf;
		EndDo;
		XMLReader.Close();
		
		If ValueIsFilled(DocumentEDPackage) AND DocumentEDPackage.PackageStatus <> Enums.EDPackagesStatuses.Delivered
			AND DateReceived <> Date('00010101') Then
			UpdateEDPackageDocumentsStatuses(DocumentEDPackage, Enums.EDPackagesStatuses.Delivered, DateReceived);
		EndIf;
		DeleteFiles(Message.FullName);
	Else
		If Find(Message.Subject, "Confirm that you received electronic documents pack") > 0 Then
			For Each Attachment IN Message.Attachments Do
				ConfirmationBinaryData = Attachment.Value;
				FileName = TemporaryFileCurrentName("xml");
				ConfirmationBinaryData.Write(FileName);
				
				XMLReader = New XMLReader;
				XMLReader.OpenFile(FileName);
				While XMLReader.Read() Do
					If XMLReader.LocalName = "ElectronicDocument" AND XMLReader.NodeType = XMLNodeType.StartElement Then
						XMLReader.Read();
						DocumentEDPackage = DetermineConfirmedEDPackage(XMLReader.Value);
					EndIf;
					If XMLReader.LocalName = "DateReceived" AND XMLReader.NodeType = XMLNodeType.StartElement Then
						XMLReader.Read();
						DateReceived = Date(XMLReader.Value);
					EndIf;
				EndDo;
				XMLReader.Close();
				DeleteFiles(FileName);
				If ValueIsFilled(DocumentEDPackage) AND DocumentEDPackage.PackageStatus <> Enums.EDPackagesStatuses.Delivered
					AND DateReceived <> Date('00010101') Then
					
					UpdateEDPackageDocumentsStatuses(DocumentEDPackage, Enums.EDPackagesStatuses.Delivered, DateReceived);
				EndIf;
			EndDo;
		EndIf;
	EndIf;
EndProcedure

Procedure SendConfirmationByPackage(EDPackage, SenderResource, SenderAddress, SendingType)
	
	SetPrivilegedMode(True);
	
	AttachedFilesSelection = GetEDSelectionByFilter(New Structure("FileOwner", EDPackage));
	If ValueIsFilled(AttachedFilesSelection) AND AttachedFilesSelection.Next() Then
		If SendingType = Enums.EDExchangeMethods.ThroughEMail Then
			EDPackageName = AttachedFilesSelection.Description;
			
			XMLFile = GenerateReceivingConfirmationXMLFile(EDPackageName);
			AccordanceOfAttachments = New Map;
			AccordanceOfAttachments.Insert(XMLFile.Name, New BinaryData(XMLFile.FullName));
			SendingParameters = New Structure("ToWhom, Subject, Body, Attachments, Password", SenderAddress,
			"Confirm that you received electronic documents pack: " + EDPackageName, , AccordanceOfAttachments, SenderResource.Password);
			Try
				EmailOperations.SendMessage(SenderResource, SendingParameters);
			Except
				ErrorText = DetailErrorDescription(ErrorInfo());
				Text = NStr("en='An error occurred while sending message to email server.
		|%1';ru='Ошибка при отправке сообщения на сервер электронной почты.
		|%1'");
				ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(Text, ErrorText);
				
				MessageText = NStr("en='An error occurred while sending e-documents is started.
		|(see details in Event log monitor).';ru='Ошибка при получении новых эл.документов.
		|(подробности см. в Журнале регистрации)'");
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='Sending e-documents';ru='Отправка эл.документов'"),
				ErrorText,
				MessageText);
			EndTry;
			DeleteFiles(XMLFile.FullName);
		ElsIf SendingType = Enums.EDExchangeMethods.ThroughFTP Then
			EDFProfileSettings = CommonUse.ObjectAttributeValue(EDPackage, "EDFProfileSettings");
			FTPConnection = GetFTPConnection(EDFProfileSettings);
			If FTPConnection = Undefined Then 
				Return;
			EndIf;
			OutgDocumentsDir = SenderAddress;
			
			PrepareFTPPath(OutgDocumentsDir);
			EDPackageName = AttachedFilesSelection.Description;
			XMLFile = GenerateReceivingConfirmationXMLFile(EDPackageName);
			
			ErrorText = "";
			Try
				FTPConnection.SetCurrentDirectory(OutgDocumentsDir);
			Except
				CreateFTPDirectories(FTPConnection, OutgDocumentsDir, , ErrorText);
			EndTry;
			If ValueIsFilled(ErrorText) Then
				Return;
			EndIf;
			WriteFileOnFTP(FTPConnection, XMLFile.FullName, XMLFile.Name);
			DeleteFiles(XMLFile.FullName);
		ElsIf SendingType = Enums.EDExchangeMethods.ThroughDirectory Then
			EDPackageName = AttachedFilesSelection.Description;
			
			XMLFile = GenerateReceivingConfirmationXMLFile(EDPackageName);
			DirectoryAddress = SenderAddress + ?(Right(SenderAddress, 1) <> "\", "\", "");
			FileCopy(XMLFile.FullName, DirectoryAddress + XMLFile.Name);
			DeleteFiles(XMLFile.FullName);
		EndIf;
	EndIf;
	
EndProcedure

Function GenerateReceivingConfirmationXMLFile(EDPackageName)
	
	FileName = TemporaryFileCurrentName("xml");
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(FileName);
	// Root element
	XMLWriter.WriteStartElement("Confirmation");
	// Document name
	XMLWriter.WriteStartElement("ElectronicDocument");
	XMLWriter.WriteText(EDPackageName);
	XMLWriter.WriteEndElement();
	XMLWriter.WriteStartElement("DateReceived");
	XMLWriter.WriteText(ConvertDateToCanonicalKind(CurrentSessionDate()));
	XMLWriter.WriteEndElement();

	XMLWriter.WriteEndElement();
	XMLWriter.Close();
	
	Return New File(FileName);
	
EndFunction

Function NeedToReceive(Message, ParametersStructure)
	
	If Message.Attachments.Count() = 0 Then
		Return False;
	EndIf;
	
	If Message.Attachments.Count() = 1 Then 
	
		If Find(Message.Subject, "Confirmation") Then
			Return True;
		EndIf;
		
		If Find(Message.Subject, "Exchange e-documents:") Then
			
			For Each Attachment IN Message.Attachments Do
				EnclosureBinaryData = Attachment.Value;
			EndDo;
		
			Result = NeedToGetBinaryData(EnclosureBinaryData, Attachment.Key, ParametersStructure);
			
			Return Result;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

Function NeedToGetBinaryData(BinaryData, FileName, ParametersStructure)
	
	SetPrivilegedMode(True);
	
	// Determine sender and receiver IDs
	// from attachments and save file on disk
	TemporaryZIPFileName = TemporaryFileCurrentName("zip");
	BinaryData.Write(TemporaryZIPFileName);
	
	ZIPReading = New ZipFileReader(TemporaryZIPFileName);
	UniqueKey = New UUID();
	FolderForUnpacking = WorkingDirectory("Input", UniqueKey);
	
	Try
		ZipReading.ExtractAll(FolderForUnpacking);
	Except
		ErrorText = BriefErrorDescription(ErrorInfo());
		If Not PossibleToExtractFiles(ZipReading, FolderForUnpacking) Then
			MessageText = ElectronicDocumentsReUse.GetMessageAboutError("006");
		EndIf;
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='ED package Unpacking';ru='распаковка пакета ЭД'"),
			ErrorText, MessageText);
		ZipReading.Close();
		DeleteFiles(TemporaryZIPFileName);
		DeleteFiles(FolderForUnpacking);
		Return False;
	EndTry;

	ZipReading.Close();
	DeleteFiles(TemporaryZIPFileName);
	UnzippedFiles = FindFiles(FolderForUnpacking, "*");
	
	InformationFile      = Undefined;
	CardFile        = Undefined;
	AgreementSettings = Undefined;
	
	For Each CurFile IN UnzippedFiles Do
		If Find(CurFile.Name, "packageDescription") > 0 Then
			InformationFile = CurFile;
			Break;
		ElsIf Find(CurFile.Name, "card") > 0 Then
			CardFile = CurFile;
			Break;
		EndIf;
	EndDo;
	
	Encrypted = False;
	
	If Not InformationFile = Undefined Then
		// Determine string with sender and
		// receiver in this file and flag of encryption and try to find agreement
		XMLReader = New XMLReader;
		XMLReader.OpenFile(InformationFile.FullName);
		While XMLReader.Read() Do
			If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.LocalName = "Sender" Then
				XMLReader.Read();
				SenderID = XMLReader.Value;
			EndIf;
			
			If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.LocalName = "Encrypted" Then
				XMLReader.Read();
				Encrypted = Encrypted OR Boolean(XMLReader.Value);
			EndIf;
			
			If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.LocalName = "Recipient" Then
				XMLReader.Read();
				RecipientID = XMLReader.Value;
			EndIf;
				
		EndDo;
		
		XMLReader.Close();
		AgreementSettings = GetEDExchangeSettingsByID(RecipientID, SenderID);
		
		PackageFormatVersion = Enums.EDPackageFormatVersions.Version10;
		
	EndIf;
	
	If Not CardFile = Undefined Then
		
		RecipientID  = Undefined;
		SenderID = Undefined;
		
		XMLObject = New XMLReader;
		ValuesStructure = New Structure;
		
		Try
			XMLObject.OpenFile(CardFile.FullName);
			ED = XDTOFactory.ReadXML(XMLObject);
			XMLObject.Close();
			SenderID = ED.Sender.Abonent.ID;
			RecipientID  = ED.Receiver.Abonent.ID;
			If ED.Description <> Undefined
				AND ED.Description.Properties().Get("AdditionalInformation") <> Undefined
				AND ED.Description.AdditionalInformation <> Undefined
				AND ED.Description.AdditionalInformation.Properties().Get("AdditionalParameter") <> Undefined
				AND ED.Description.AdditionalInformation.AdditionalParameter <> Undefined Then
				
				For Each Property IN ED.Description.AdditionalInformation.AdditionalParameter Do
					If Property.Name = "Encrypted" Then
						Encrypted = Boolean(Property.Value);
						Continue;
					EndIf;
					If Property.Name = "PackageFormatVersion" Then
						PackageFormatVersion = FormatVersionFromString(Property.Value);
						Continue;
					EndIf;
					
				EndDo;
			EndIf;
			
			AgreementSettings = GetEDExchangeSettingsByID(RecipientID, SenderID);
			
		Except
			
			XMLObject.Close();
			
			MessagePattern = NStr("en='Data reading from the file %1 failed: %2 (see details in Events log monitor).';ru='Возникла ошибка при чтении данных из файла %1: %2 (подробности см. в Журнале регистрации).'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
				CardFile.FullName, BriefErrorDescription(ErrorInfo()));
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='ED reading';ru='Чтение ЭД.'"),
				DetailErrorDescription(ErrorInfo()),
				MessageText);
		EndTry;
		
	EndIf;
	
	If (InformationFile = Undefined AND CardFile = Undefined)
		OR AgreementSettings = Undefined Then // you did not find file with description or there is no exchange
		
		DeleteFiles(FolderForUnpacking);
		Return False;
	EndIf;
	
	// Now check that there was no transport pack from this sender
	PackageName = Left(FileName, StrLen(FileName)-4);
	
	QueryAttachedFile = New Query;
	QueryAttachedFile.Text =
	"SELECT TOP 1
	|	TRUE AS IsAttachedFile
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.FileOwner REFS Document.EDPackage
	|	AND CAST(EDAttachedFiles.FileOwner AS Document.EDPackage).Direction = &Direction
	|	AND CAST(EDAttachedFiles.FileOwner AS Document.EDPackage).Recipient LIKE &Recipient
	|	AND CAST(EDAttachedFiles.FileOwner AS Document.EDPackage).Sender LIKE &Sender
	|	AND EDAttachedFiles.Description LIKE &Description
	|	AND EDAttachedFiles.DeletionMark = FALSE";
	QueryAttachedFile.SetParameter("Direction",  Enums.EDDirections.Incoming);
	QueryAttachedFile.SetParameter("Recipient",   RecipientID);
	QueryAttachedFile.SetParameter("Sender",  SenderID);
	QueryAttachedFile.SetParameter("Description", PackageName);
	
	ResultIsEmpty = QueryAttachedFile.Execute().IsEmpty();
	
	DeleteFiles(FolderForUnpacking);
	
	If ResultIsEmpty Then
		ParametersStructure.Insert("Recipient",          RecipientID);
		ParametersStructure.Insert("Sender",         SenderID);
		ParametersStructure.Insert("Company",         AgreementSettings.Company);
		ParametersStructure.Insert("Counterparty",          AgreementSettings.Counterparty);
		ParametersStructure.Insert("EDFProfileSettings",  AgreementSettings.EDFProfileSettings);
		ParametersStructure.Insert("EDFSetup",        AgreementSettings.EDFSetup);
		ParametersStructure.Insert("EDExchangeMethod",      AgreementSettings.EDExchangeMethod);
		ParametersStructure.Insert("CompanyCertificateForDetails", AgreementSettings.CompanyCertificateForDetails);
		ParametersStructure.Insert("SenderAddress",    AgreementSettings.SenderAddress);
		ParametersStructure.Insert("RecipientAddress",     AgreementSettings.RecipientAddress);
		ParametersStructure.Insert("Encrypted",          Encrypted);
		ParametersStructure.Insert("PackageFormatVersion", PackageFormatVersion);
	
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function DetermineConfirmedEDPackage(PackagePresentation)
	
	IdentificatorRow = StrReplace(PackagePresentation, "EDI_", "");
	ID = New UUID(IdentificatorRow);
	DocumentPackage = Documents.EDPackage.GetRef(ID);
	If Not CommonUse.RefExists(DocumentPackage) Then
		DocumentPackage = Undefined;
	EndIf;
	
	Return DocumentPackage;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Exchange through directory

// Updates electronic documents statuses.
//
// Parameters: 
//  DocumentArray - array of refs to electronic documents state of
//  which should be updates, SignatureFlag - Boolean, shows that documents were written with DS.
//
Procedure UpdateEDStatuses(DocumentArray, SignatureSign)
	
	SetPrivilegedMode(True);
	
	For Each ElectronicDocument IN DocumentArray Do
			If ((SignatureSign AND ElectronicDocument.EDStatus <> Enums.EDStatuses.DigitallySigned)
			
			OR (ElectronicDocument.EDDirection = Enums.EDDirections.Intercompany
				AND ElectronicDocument.EDStatus = Enums.EDStatuses.DigitallySigned)
				
			OR (ElectronicDocument.EDStatus = Enums.EDStatuses.ConfirmationReceived))
			
			AND Not (ElectronicDocument.EDKind = Enums.EDKinds.NotificationAboutClarification
			 		AND ElectronicDocument.EDStatus = Enums.EDStatuses.Approved) Then
			
			Continue;
		EndIf;
		
		Try
			
			BeginTransaction();
			
			EDDirection = CommonUse.ObjectAttributeValue(ElectronicDocument, "EDDirection");
			
			If EDDirection = Enums.EDDirections.Outgoing Then
				NewEDStatus = GetAdmissibleEDStatus(Enums.EDStatuses.PreparedToSending, ElectronicDocument);
			Else
				NewEDStatus = GetAdmissibleEDStatus(Enums.EDStatuses.ConfirmationPrepared, ElectronicDocument);
			EndIf;
			
			ParametersStructure = New Structure("EDStatus", NewEDStatus);
			
			ChangeByRefAttachedFile(ElectronicDocument, ParametersStructure, False);
			
			ForcedStateChange = False;
			If ElectronicDocument.EDKind = Enums.EDKinds.NotificationAboutReception
				AND ElectronicDocument.EDStatus = Enums.EDStatuses.Sent Then
				
				ForcedStateChange = True;
			EndIf;
			
			ElectronicDocumentsServiceCallServer.RefreshEDVersion(ElectronicDocument, ForcedStateChange);
			CommitTransaction();
		Except
			RollbackTransaction();
			MessagePattern = NStr("en='%1 (see details in event log monitor).';ru='%1 (подробности см. в Журнале регистрации).'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
				BriefErrorDescription(ErrorInfo()));
			ErrorText = DetailErrorDescription(ErrorInfo());
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='preparation for ED sending';ru='подготовка к отправке ЭД'"),
																						ErrorText,
																						MessageText);
		EndTry;
	EndDo;
	
EndProcedure

// Receives encryption certificate address in the data temporary storage.
//
// Parameters:
//  AttachedFile - Ref to electronic document encryption certificate address by which should be received.
//
Function GetEncryptionCertificatesAdressesArray(AttachedFile) Export
	
	AgreementParameters = DetermineEDExchangeSettingsBySource(AttachedFile.FileOwner, , , AttachedFile);
	If Not ValueIsFilled(AgreementParameters)
		OR AgreementParameters.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
		
		Return Undefined;
	EndIf;
	
	CounterpartysEncryptionCertificate = AgreementParameters.CounterpartyCertificateForEncryption;
	EncryptionCompanyCertificate = AgreementParameters.CompanyCertificateForDetails;
	
	If CounterpartysEncryptionCertificate = Undefined OR EncryptionCompanyCertificate = Undefined Then
		Return Undefined;
	EndIf;
	
	ElectronicDocumentsServiceCallServer.ValidateCertificateValidityPeriod(EncryptionCompanyCertificate);
	
	CertificateBinaryData            = CounterpartysEncryptionCertificate.Get();
	CompanyCertificateBinaryData = EncryptionCompanyCertificate.CertificateData.Get();
	
	If CertificateBinaryData = Undefined OR CompanyCertificateBinaryData = Undefined Then
		Return Undefined;
	EndIf;
	
	CertificateAddress = PutToTempStorage(CertificateBinaryData);
	CompanyCertificateAddress = PutToTempStorage(CompanyCertificateBinaryData);
	
	ReturnArray = New Array;
	ReturnArray.Add(CertificateAddress);
	ReturnArray.Add(CompanyCertificateAddress);
	
	Return ReturnArray;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Unpacking electronic documents packages

Procedure AddArray(ArrayReceiver, ArraySource)
	
	If TypeOf(ArraySource) <> Type("Array") Then
		Return;
	EndIf;
	
	For Each ItemSource IN ArraySource Do
		ArrayReceiver.Add(ItemSource)
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Processing the electronic documents

Function IsConfirmationSending(AttachedFile)
	
	Return AttachedFile.EDDirection = Enums.EDDirections.Incoming;
	
EndFunction

Procedure WriteDateReceived(ED, ChangeDate)
	
	CurEDStatus = CommonUse.ObjectAttributeValue(ED, "EDStatus");
	
	Try
		If ED.IsEmpty() OR (CurEDStatus <> Enums.EDStatuses.ConfirmationSent
								AND CurEDStatus <> Enums.EDStatuses.Sent) Then
			Return;
		EndIf;
		NewEDStatus = Undefined;
		If CurEDStatus = Enums.EDStatuses.ConfirmationSent Then
			NewEDStatus = GetAdmissibleEDStatus(Enums.EDStatuses.ConfirmationDelivered, ED);
		ElsIf CurEDStatus = Enums.EDStatuses.Sent Then
			NewEDStatus = GetAdmissibleEDStatus(Enums.EDStatuses.Delivered, ED);
		EndIf;
		If ValueIsFilled(NewEDStatus) Then
			ParametersStructure = New Structure("EDStatus", NewEDStatus);
			ChangeByRefAttachedFile(ED, ParametersStructure, False);
		EndIf;
	Except
		MessageText = BriefErrorDescription(ErrorInfo())
			+ NStr("en=' (see details in Event log monitor).';ru=' (подробности см. в Журнале регистрации).'");
		ErrorText = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='the ED receiving date record';ru='запись даты получения ЭД'"),
																					ErrorText,
																					MessageText);
	EndTry;
	
EndProcedure

Procedure WriteSendingDate(ED, ChangeDate)
	
	EDAttributes = CommonUse.ObjectAttributesValues(ED, "EDStatus, EDKind, EDAgreement, EDFProfileSettings");
	CurEDStatus = EDAttributes.EDStatus;
	EDExchangeMethod = CommonUse.ObjectAttributeValue(EDAttributes.EDFProfileSettings, "EDExchangeMethod");
	
	Try
		
		If ED.IsEmpty() OR (CurEDStatus <> Enums.EDStatuses.ConfirmationPrepared
								AND CurEDStatus <> Enums.EDStatuses.PreparedToSending) Then
			Return;
		EndIf;
		NewEDStatus = Undefined;
		If CurEDStatus = Enums.EDStatuses.ConfirmationPrepared Then
			NewEDStatus = GetAdmissibleEDStatus(Enums.EDStatuses.ConfirmationSent, ED);
		ElsIf CurEDStatus = Enums.EDStatuses.PreparedToSending Then
			If EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
				
				AND EDAttributes.EDKind <> Enums.EDKinds.NotificationAboutReception
				AND EDAttributes.EDKind <> Enums.EDKinds.NotificationAboutClarification Then
				
				NewEDStatus = GetAdmissibleEDStatus(Enums.EDStatuses.TransferedToOperator, ED);
				
			Else
				
				NewEDStatus = GetAdmissibleEDStatus(Enums.EDStatuses.Sent, ED);
				
			EndIf;
		EndIf;
		If ValueIsFilled(NewEDStatus) Then
			ParametersStructure = New Structure("EDStatus", NewEDStatus);
			ChangeByRefAttachedFile(ED, ParametersStructure, False);
		EndIf;
		
	Except
		MessagePattern = NStr("en='%1 (see details in event log monitor).';ru='%1 (подробности см. в Журнале регистрации).'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
			BriefErrorDescription(ErrorInfo()));
		ErrorText = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='ED sending date record';ru='запись даты отправки ЭД'"),
																					ErrorText,
																					MessageText);
	EndTry;
	
EndProcedure

Function EDParametersStructure()
	
	EDParameters = New Structure;
	
	EDParameters.Insert("EDKind",                Undefined);
	EDParameters.Insert("EDDirection",        Undefined);
	EDParameters.Insert("Counterparty",           Undefined);
	EDParameters.Insert("CounterpartyContract",   Undefined);
	EDParameters.Insert("Company",          Undefined);
	EDParameters.Insert("EDAgreement",         Undefined);
	EDParameters.Insert("SetSignatures", New Array);
	
	If ElectronicDocumentsReUse.UseAdditionalAnalyticsOfCompaniesCatalogPartners() Then
		EDParameters.Insert("Partner",          Undefined);
	EndIf;
	
	Return EDParameters;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Electronic document versions

Function GetEDLastVersionByOwner(RefToOwner)
	
	SetPrivilegedMode(True);
	
	EDQuery = New Query;
	EDQuery.SetParameter("RefToOwner", RefToOwner);
	EDQuery.Text =
	"SELECT TOP 1
	|	EDAttachedFiles.EDVersionNumber AS VersionNumber
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.DeletionMark = FALSE
	|	AND EDAttachedFiles.FileOwner = &RefToOwner
	|
	|ORDER BY
	|	EDAttachedFiles.EDVersionNumber DESC";
	
	Result = EDQuery.Execute().Select();
	If Result.Next() Then
		Return Result.VersionNumber;
	EndIf;
	
	Return 0;
	
EndFunction

Procedure DetermineSiteParameters(Val SiteAddress, SecureConnection, Address, Protocol)
	
	SiteAddress = TrimAll(SiteAddress);
	
	SiteAddress = StrReplace(SiteAddress, "\", "/");
	SiteAddress = StrReplace(SiteAddress, " ", "");
		
	If Lower(Left(SiteAddress, 7)) = "http://" Then
		Protocol = "http";
		Address = Mid(SiteAddress, 8);
		SecureConnection = FALSE;
	ElsIf Lower(Left(SiteAddress, 8)) = "https://" Then
		Protocol = "https";
		Address = Mid(SiteAddress, 9);
		SecureConnection = true;
	EndIf;
			
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Exchange through directory

Function CreateAttachedAdditFile(ParametersStructure, EDOwner)
	
	AdditEDCreated = False;
	FullFileName = ParametersStructure.AdditFileFullName;
	
	If ValueIsFilled(FullFileName) Then
		
		CreationTimeED = ParametersStructure.EDStructure.EDDate;
		EDOwner = ParametersStructure.EDStructure.EDOwner;
		File = New File(FullFileName);
		BinaryData = New BinaryData(File.FullName);
		FileURL = PutToTempStorage(BinaryData);
		
		EDUUID = "";
		ParametersStructure.Property("AdditFileIdentifier", EDUUID);
		
		AddedFile = AttachedFiles.AddFile(
													EDOwner,
													File.BaseName,
													StrReplace(File.Extension, ".", ""),
													CreationTimeED,
													CreationTimeED,
													FileURL,
													Undefined,
													,
													Catalogs.EDAttachedFiles.GetRef(EDUUID));
		
		DeleteFiles(FullFileName);
		If ValueIsFilled(AddedFile) Then
			AdditEDCreated = True;
			SecondaryStructure = New Structure;
			SecondaryStructure.Insert("EDKind", Enums.EDKinds.AddData);
			SecondaryStructure.Insert("Company", ParametersStructure.EDStructure.Company);
			SecondaryStructure.Insert("Counterparty", ParametersStructure.EDStructure.Counterparty);
			SecondaryStructure.Insert("EDOwner", EDOwner);
			SecondaryStructure.Insert("EDAgreement", ParametersStructure.EDStructure.EDAgreement);
			SecondaryStructure.Insert("EDNumber", ParametersStructure.EDStructure.EDNumber);
			SecondaryStructure.Insert("UniqueId", ParametersStructure.UUID);
			SecondaryStructure.Insert("EDDirection", Enums.EDDirections.Outgoing);
			SecondaryStructure.Insert("VersionPointTypeED", Enums.EDVersionElementTypes.AdditionalED);
			SecondaryStructure.Insert("ElectronicDocumentOwner", EDOwner);
			SecondaryStructure.Insert("FileDescription", File.BaseName);
			SecondaryStructure.Insert("EDStatus", Enums.EDStatuses.Created);
			
			EDFormingDateBySender = "";
			If Not ParametersStructure.EDStructure.Property("EDFormingDateBySender", EDFormingDateBySender) Then
				EDFormingDateBySender = CreationTimeED;
			EndIf;
			SecondaryStructure.Insert("EDFormingDateBySender", EDFormingDateBySender);
			
			ChangeByRefAttachedFile(AddedFile, SecondaryStructure);
		EndIf;
		
	EndIf;
	
	Return AdditEDCreated;
	
EndFunction

Function ConvertDateToCanonicalKind(RequiredData)
	
	If TypeOf(RequiredData) = Type("Date") Then
		
		CanonicalKindDate = Format(Year(RequiredData),"NG=0") + Format(Month(RequiredData), "ND=2; NLZ=")
			+ Format(Day(RequiredData), "ND=2; NLZ=") + Format(Hour(RequiredData), "ND=2; NZ=; NLZ=")
			+ Format(Minute(RequiredData), "ND=2; NZ=; NLZ=") + Format(Second(RequiredData), "ND=2; NZ=; NLZ=");
	Else
		CanonicalKindDate = RequiredData;
	EndIf;
	
	Return CanonicalKindDate;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Exchange via FTP

Procedure CheckFile(MessagePattern, FTPConnection, ErrorText)
	
	TempFile = GetTempFileName();
	TextDocument = New TextDocument();
	TestString = "Test row 1C:Enterprise";
	TextDocument.SetText(TestString);
	TextDocument.Write(TempFile);
	FileTest = New File(TempFile);
		
	WriteFileOnFTP(FTPConnection, TempFile, FileTest.Name, True, ErrorText);
	
	DeleteFiles(TempFile);
	
	If ValueIsFilled(ErrorText) Then
		Return;
	EndIf;
	
	FileRecipient = GetTempFileName();
	
	GetFileFromFTP(FTPConnection, FileTest.Name, FileRecipient, True, ErrorText);
	
	If ValueIsFilled(ErrorText) Then
		DeleteFiles(FileRecipient);
		Return;
	EndIf;
		
	TextDocument = New TextDocument;
	TextDocument.Read(FileRecipient);
	ResultRow = TextDocument.GetText();
	DeleteFiles(FileRecipient);
	If Not ResultRow = TestString Then
		MessagePattern = NStr("en='%1 %2.';ru='%1 %2.'");
		MessageText = ElectronicDocumentsServiceCallServer.GetMessageAboutError("126");
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, MessageText,
			FTPConnection.GetCurrentDirectory());
		
		Return;
	EndIf;
	
	DeleteFileFTP(FTPConnection, FileTest.Name, True, ErrorText);
	
EndProcedure

Procedure GetFileFromFTP(FTPConnection, Source, OutgoingFileName, IsTest = False, TestResult = Undefined)
	
	Try
		FTPConnection.Get(Source, OutgoingFileName);
	Except
		TestResult = ElectronicDocumentsServiceCallServer.GetMessageAboutError("128");
		
		If Not IsTest Then
			CommonUseClientServer.MessageToUser(TestResult);
		EndIf;
	EndTry;

	
EndProcedure

Procedure FindFilesInFTPDirectory(FTPConnection, Path, Mask, IsTest, TestResult, FilesArray)
	
	Try
		If Mask = Undefined Then
			FilesArray = FTPConnection.FindFiles(Path);
		Else
			FilesArray = FTPConnection.FindFiles(Path, Mask);
		EndIf;
	Except
		TestResult = ElectronicDocumentsServiceCallServer.GetMessageAboutError("125");
		
		If Not IsTest = True Then
			CommonUseClientServer.MessageToUser(TestResult);
		EndIf;
	EndTry;
	
EndProcedure

Procedure DeleteFileFTP(FTPConnection, Path, TestResult = Undefined, IsTest = False)
		
	Try
		FTPConnection.Delete(Path);
	Except
		TestResult = ElectronicDocumentsServiceCallServer.GetMessageAboutError("129");
		
		If Not IsTest Then
			CommonUseClientServer.MessageToUser(TestResult);
		EndIf;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Processing the electronic documents

Procedure ProcessElectronicDocumentDeletion(ObjectReference)
	
	SetPrivilegedMode(True);
	
	If Not ElectronicDocumentsServiceCallServer.ThisIsServiceDocument(ObjectReference) Then
		IBDocumentsQuery = New Query;
		IBDocumentsQuery.SetParameter("ElectronicDocument", ObjectReference);
		IBDocumentsQuery.Text =
		"SELECT
		|	EDStates.ObjectReference
		|FROM
		|	InformationRegister.EDStates AS EDStates
		|WHERE
		|	EDStates.ElectronicDocument = &ElectronicDocument";
		
		DocumentsSelection = IBDocumentsQuery.Execute().Select();
		While DocumentsSelection.Next() Do
			RecordSet = InformationRegisters.EDStates.CreateRecordSet();
			RecordSet.Filter.ObjectReference.Set(DocumentsSelection.ObjectReference);
			RecordSet.Read();
			
			If RecordSet.Count() = 0 Then
				Continue;
			Else
				NewSetRecord = RecordSet.Get(0);
			EndIf;
			NewSetRecord.EDVersionState   = GetFirstEDVersionStateForOwner(DocumentsSelection.ObjectReference);
			NewSetRecord.ElectronicDocument = Catalogs.EDAttachedFiles.EmptyRef();
			RecordSet.Write();
		EndDo;
	EndIf;
	
EndProcedure

Procedure CheckExistanceAndDeleteDocumentState(ObjectReference)
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.EDStates.CreateRecordManager();
	RecordManager.ObjectReference = ObjectReference;
	RecordManager.Read();
	If RecordManager.Selected() Then
		RecordManager.Delete();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Objects registration for electronic documents exchange.

Procedure CheckObjectModificationForEDExchange(Source, ChangeSign = False)
	
	If ChangeSign OR Source.IsNew() Then
		RegisterObject = True;
	Else
		RegisterObject = NeedToRegisterObject(Source, Source.Metadata());
	EndIf;
	
	Source.AdditionalProperties.Insert("RegisterObject", RegisterObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with events log monitor

// Writes ED writing event to the events log monitor.
//
// Parameters:
//  LinkToED - ref to the EDAttachedFiles catalog item.
//
Procedure WriteEventLogMonitorByEDExchangeEvent(LinkToED)
	
	If TypeOf(LinkToED) = Type("CatalogRef.EDAttachedFiles") Then
		
		SetPrivilegedMode(True);
		
		BeginTransaction();
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.EDEventsLog");
		LockItem.SetValue("AttachedFile", LinkToED);
		Block.Lock();
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	ISNULL(MAX(EDEventsLog.RecNo), 0) + 1 AS RecNo
		|FROM
		|	InformationRegister.EDEventsLog AS EDEventsLog
		|WHERE
		|	EDEventsLog.AttachedFile = &AttachedFile";
		Query.SetParameter("AttachedFile", LinkToED);
		RecNo = Query.Execute().Unload()[0].RecNo;
		
		RecordManager                    = InformationRegisters.EDEventsLog.CreateRecordManager();
		RecordManager.AttachedFile = LinkToED;
		RecordManager.RecNo        = RecNo;
		RecordManager.EDOwner         = LinkToED.FileOwner;
		RecordManager.EDStatus           = LinkToED.EDStatus;
		RecordManager.Date               = CurrentSessionDate();
		RecordManager.User       = SessionParameters.CurrentUser;
		RecordManager.Responsible      = LinkToED.Responsible;
		RecordManager.Comment        = LinkToED.Definition;
		RecordManager.Write();
		
		CommitTransaction();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Determine the object's modifications similar to the data exchange subsystem

Function DefineObjectsVersionsChanges(Object, ChangeRecordAttributeTableRow)
	
	If IsBlankString(ChangeRecordAttributeTableRow.TabularSectionName) Then
		
		ChangeRecordAttributeTableObjectVersioningBeforeChanges = GetTableOfHeaderRegistrationAttributesBeforeChange(Object,
			ChangeRecordAttributeTableRow);
		ChangeRecordAttributeTableObjectVersioningAfterChange = GetTableOfHeaderRegistrationAttributesAfterChange(
			Object, ChangeRecordAttributeTableRow);
	Else
		
		ChangeRecordAttributeTableObjectVersioningBeforeChanges = GetTableOfTabularSectionRegistrationAttributesBeforeChange(
			Object, ChangeRecordAttributeTableRow);
		ChangeRecordAttributeTableObjectVersioningAfterChange = GetTableOfTabularSectionRegistrationAttributesAfterChange(
			Object, ChangeRecordAttributeTableRow);
	EndIf;
	
	Return Not ObjectAttributesTablesSame(ChangeRecordAttributeTableObjectVersioningBeforeChanges,
												   ChangeRecordAttributeTableObjectVersioningAfterChange,
												   ChangeRecordAttributeTableRow.ObjectAttributes);
	
EndFunction

Function NeedToRegisterObject(Source, MetadataObject)
	
	ObjectName = MetadataObject.FullName();	
	ChangeRecordAttributeTable = ElectronicDocumentsReUse.GetObjectKeyAttributesTable(ObjectName);
	
	If ChangeRecordAttributeTable.Count() = 0 Then
		
		// If attributes listing is not specified, then consider object to be always modified
		Return True;
	EndIf;
	
	For Each ChangeRecordAttributeTableRow IN ChangeRecordAttributeTable Do
		
		HasObjectVersioningChanges = DefineObjectsVersionsChanges(Source, ChangeRecordAttributeTableRow);
		
		If HasObjectVersioningChanges Then
			
			Return True;
		EndIf;
		
	EndDo;
	
	// If you reached the end, the object did not change by the registration attributes;
	// Registration is not required
	Return False;
	
EndFunction

Function GetTableOfHeaderRegistrationAttributesBeforeChange(Object, ChangeRecordAttributeTableRow)
		
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT " + ChangeRecordAttributeTableRow.ObjectAttributes + " FROM "
	+ ChangeRecordAttributeTableRow.ObjectName + " AS
	|CurrentObject
	|	WHERE CurrentObject.Ref = &Ref";
	Query.SetParameter("Ref", Object.Ref);
	
	Return Query.Execute().Unload();
		
EndFunction

Function GetTableOfTabularSectionRegistrationAttributesBeforeChange(Object, ChangeRecordAttributeTableRow)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT "+ ChangeRecordAttributeTableRow.ObjectAttributes + " FROM "
	+ ChangeRecordAttributeTableRow.ObjectName + "." + ChangeRecordAttributeTableRow.TabularSectionName
	+ " AS
	|CurrentObjectTabularSectionName
	|	WHERE CurrentObjectTabularSectionName.Ref = &Ref";
	Query.SetParameter("Ref", Object.Ref);
	
	Return Query.Execute().Unload();
		
EndFunction

Function GetTableOfHeaderRegistrationAttributesAfterChange(Object, ChangeRecordAttributeTableRow)
	
	ChangeRecordAttributeTable = New ValueTable;
	
	ChangeRecordAttributeStructure = ChangeRecordAttributeTableRow.ObjectAttributesStructure;
	For Each ChangeRecordAttribute IN ChangeRecordAttributeStructure Do
		
		ChangeRecordAttributeTable.Columns.Add(ChangeRecordAttribute.Key);
	EndDo;
	
	TableRow = ChangeRecordAttributeTable.Add();
	For Each ChangeRecordAttribute IN ChangeRecordAttributeStructure Do
		
		TableRow[ChangeRecordAttribute.Key] = Object[ChangeRecordAttribute.Key];
	EndDo;
	
	Return ChangeRecordAttributeTable;
	
EndFunction

Function GetTableOfTabularSectionRegistrationAttributesAfterChange(Object, ChangeRecordAttributeTableRow)
	
	ChangeRecordAttributeTable = Object[ChangeRecordAttributeTableRow.TabularSectionName].Unload(,
		ChangeRecordAttributeTableRow.ObjectAttributes);
		
	Return ChangeRecordAttributeTable;
	
EndFunction

// Checks whether attributes tables match.
//
// Parameters:
//  Table1, Table2 - value tables, attributes that should be checked
//  for match, ObjectAttributes   - String, contains attributes separated
//  by comma, AdditParameters       - structure of additional parameters according to which you should execute connection.
//
Function ObjectAttributesTablesSame(Table1, Table2, ObjectAttributes, AdditParameters = Undefined)
	
	AddIteratorToTable(Table1, +1);
	AddIteratorToTable(Table2, -1);
	
	ResultTable = Table1.Copy();
	
	CommonUseClientServer.SupplementTable(Table2, ResultTable);
	
	ResultTable.GroupBy(ObjectAttributes, "ObjectAttributesTableIterator");
	
	SameRowCount = ResultTable.FindRows(New Structure("ObjectAttributesTableIterator", 0)).Count();
	
	TableRowCount = ResultTable.Count();
	CoincidenceSign = SameRowCount = TableRowCount;
	
	If Not CoincidenceSign AND ValueIsFilled(AdditParameters) Then
		If AdditParameters.Property("TabularSectionName") Then
			TabularSectionName = AdditParameters.TabularSectionName;
		EndIf;
		If AdditParameters.Property("ComparisonTreeRow") Then
			ComparisonTreeRow = AdditParameters.ComparisonTreeRow;
		EndIf;
		
		If TabularSectionName = "Header" Then
			
			TreeNewRowPlace = ComparisonTreeRow.Rows.Add();
			TreeNewRowPlace.place = "Header attributes";
			For Each CurRowTab1 IN Table1 Do
				For Each CurColumn IN Table1.Columns Do
					ColumnName = CurColumn.Name;
					If ColumnName = "ObjectAttributesTableIterator" Then
						Continue;
					EndIf;
					FoundStringTab2 = Table2.Find( - CurRowTab1.ObjectAttributesTableIterator,
						"ObjectAttributesTableIterator");
					If Not ValueIsFilled(FoundStringTab2) 
						OR	FoundStringTab2[ColumnName] = CurRowTab1[ColumnName] Then
						Continue;
					EndIf;
					TreeNewRowAttr = TreeNewRowPlace.Rows.Add();
					TreeNewRowAttr.Attribute  = ColumnName;
					TreeNewRowVal            = TreeNewRowAttr.Rows.Add();
					TreeNewRowVal.DBValue = CurRowTab1[ColumnName];
					TreeNewRowVal.EDValue = FoundStringTab2[ColumnName];
					
				EndDo;
			EndDo;
		Else
			TreeNewRowPlace = ComparisonTreeRow.Rows.Add();
			TreeNewRowPlace.place = "Tabular section <" + TabularSectionName + ">";
			TreeNewRowAttr = TreeNewRowPlace.Rows.Add();
			TreeNewRowAttr.Attribute = "<Changed>";
		EndIf;
	EndIf;
	
	Return CoincidenceSign;
	
EndFunction

Procedure AddIteratorToTable(Table, IteratorValue)
	
	Table.Columns.Add("ObjectAttributesTableIterator");
	Table.FillValues(IteratorValue, "ObjectAttributesTableIterator");
	
EndProcedure


// Receives actual setting date of electronic signature and signature binary data
//
// Parameters:
//  BinaryDataSignatures - BinaryData - signature
//
// Returns - Date or Undefined.
//
Function SignatureInstallationDate(BinaryDataSignatures) Export
	
	TempFileName = GetTempFileName();
	BinaryDataSignatures.Write(TempFileName);
	TextReader = New TextReader(TempFileName);
	Char = TextReader.Read(1);
	While Char <> Undefined Do
		If CharCode(Char) = 15 Then
			Char = TextReader.Read(2);
			If CharCode(Char, 1) = 23 AND CharCode(Char, 2) = 13 Then
				SigningDate = TextReader.Read(12);
				SignatureDateFound = True;
				TextReader.Close();
				DeleteFiles(TempFileName);
				Return ToLocalTime(Date("20" + SigningDate));
			EndIf;
		EndIf;
		Char = TextReader.Read(1);
	EndDo;
	
	TextReader.Close();
	DeleteFiles(TempFileName);
	Return Undefined;

EndFunction

// For internal use only
Function ServiceBankED(ED) Export
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	               |	EDAttachedFiles.Ref
	               |FROM
	               |	Catalog.EDAttachedFiles AS EDAttachedFiles
	               |WHERE
	               |	EDAttachedFiles.ElectronicDocumentOwner = &ElectronicDocumentOwner
	               |	AND EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.AddData)";
	Query.SetParameter("ElectronicDocumentOwner", ED);
	Result = Query.Execute().Select();
	If Result.Next() Then
		Return Result.Ref;
	EndIf
	
EndFunction


// Returns reference to the temporary storage of archive binary data with the directory additional files.
//
// Parameters:
//  FilesArray - array - contain references to additional file temporary storage.
//
// Returns:
//  String - ref to the temporary storage.
//
Function AdditionalFilesArchive(FilesArray) Export
	
	TempFolder = ElectronicDocumentsServiceCallServer.TemporaryFilesCurrentDirectory()
				+ String(New UUID) + "\";
	CreateDirectory(TempFolder);
	DeleteFiles(TempFolder, "*");
	For Each Item IN FilesArray Do
		FileBinaryData = GetFromTempStorage(Item.TemporaryStorageAddress);
		CreateDirectory(TempFolder + Item.ProductId + "\");
		FileBinaryData.Write(TempFolder + Item.ProductId + "\" + Item.FileName);
	EndDo;
	archive = GetTempFileName();
	Zip = New ZipFileWriter(archive);
	Zip.Add(
			TempFolder + "*",
			ZIPStorePathMode.StoreRelativePath,
			ZIPSubDirProcessingMode.ProcessRecursively);
	Try
		Zip.Write();
	Except
		MessageText = BriefErrorDescription(ErrorInfo())
			+ NStr("en=' (see details in Event log monitor).';ru=' (подробности см. в Журнале регистрации).'");
		ErrorText = DetailErrorDescription(ErrorInfo()) + Chars.LF
			+ NStr("en='Check whether the English language is present in OS regional
		|settings for non-Unicode applications and there is access to the temporary files directory.';ru='Проверьте поддержку русского языка в региональных настройках ОС для non-Unicode programs
		|и наличие доступа к каталогу временных файлов.'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='the archive file record on a disk';ru='запись файла архива на диск'"),
																					ErrorText,
																					MessageText);
		DeleteFiles(archive);
		DeleteFiles(TempFolder);
		Return Undefined;
	EndTry;
	ArchiveBinaryData = New BinaryData(archive);
	DeleteFiles(TempFolder);
	DeleteFiles(archive);
	Return PutToTempStorage(ArchiveBinaryData);
	
EndFunction

Function EDPackageVersion(ED) Export
	
	If ED.EDDirection = Enums.EDDirections.Incoming Then
		
		FormatVersion = EDPackFormat(ED);
		
	Else
		
		If ED.EDKind = Enums.EDKinds.TORG12Customer
			Or ED.EDKind = Enums.EDKinds.ActCustomer
			Or ED.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient Then
			
			FormatVersion = EDPackFormat(ED.ElectronicDocumentOwner);
			
		Else
			 
			FormatVersion = ED.EDAgreement.PackageFormatVersion;
			
		EndIf;
		
	EndIf;
	
	Return FormatVersion;
	
EndFunction

Function EDPackFormat(ED)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	PackageEDElectronicDocuments.Ref.PackageFormatVersion AS PackageFormatVersion
	|FROM
	|	Document.EDPackage.ElectronicDocuments AS PackageEDElectronicDocuments
	|WHERE
	|	PackageEDElectronicDocuments.ElectronicDocument = &ElectronicDocument";
	Query.SetParameter("ElectronicDocument", ED);
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		FormatVersion = Undefined;
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	
	FormatVersion = Selection.PackageFormatVersion;
	
	Return FormatVersion;
	
EndFunction

Function FormatVersionFromString(Version)
	If Version = "2" Then
		Result = Enums.EDPackageFormatVersions.Version20;
	ElsIf Version = "3" Then
		Result = Enums.EDPackageFormatVersions.Version30;
	EndIf;
	
	Return Result;
	
EndFunction

Function IsFTS(EDKind) Export
	
	If EDKind = Enums.EDKinds.TORG12
		Or EDKind = Enums.EDKinds.TORG12Customer
		Or EDKind = Enums.EDKinds.TORG12Seller
		Or EDKind = Enums.EDKinds.ActCustomer
		Or EDKind = Enums.EDKinds.ActPerformer
		Or EDKind = Enums.EDKinds.CustomerInvoiceNote
		Or EDKind = Enums.EDKinds.CorrectiveInvoiceNote
		Or EDKind = Enums.EDKinds.AgreementAboutCostChangeSender
		Or EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient Then
		Result = True;
	Else
		Result = False;
	EndIf;
	
	Return Result;
	
EndFunction

Function HasUnsentConfirmation(FileOwner, EDStatus) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EDAttachedFiles.EDStatus,
	|	EDAttachedFiles.DigitallySigned,
	|	ISNULL(EDAttachedFiles.ElectronicDocumentOwner.DigitallySigned, FALSE) AS OwnerSignedDS
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.FileOwner = &FileOwner
	|	AND EDAttachedFiles.EDKind = &EDKind
	|	AND EDAttachedFiles.EDStatus IN(&UnsentEDStatuses)";
	
	UnsentEDStatuses = New Array;
	UnsentEDStatuses.Add(Enums.EDStatuses.Approved);
	UnsentEDStatuses.Add(Enums.EDStatuses.DigitallySigned);
	UnsentEDStatuses.Add(Enums.EDStatuses.PreparedToSending);
	
	Query.SetParameter("UnsentEDStatuses", UnsentEDStatuses);
	Query.SetParameter("EDKind", Enums.EDKinds.NotificationAboutReception);
	Query.SetParameter("FileOwner", FileOwner);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return False;
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	If Selection.EDStatus = Enums.EDStatuses.Approved Then
		EDStatus = Enums.EDVersionsStates.NotificationOnSigning;
		
	ElsIf Selection.EDStatus = Enums.EDStatuses.DigitallySigned Then
		
		If Selection.OwnerSignedDS AND Not Selection.DigitallySigned Then
			EDStatus = Enums.EDVersionsStates.NotificationOnSigning;
		Else
			EDStatus = Enums.EDVersionsStates.NotificationSendingExpected;
		EndIf;
		
	ElsIf Selection.EDStatus = Enums.EDStatuses.PreparedToSending Then
		EDStatus = Enums.EDVersionsStates.NotificationSendingExpected;
		
	EndIf;
	
	Return True;
	
EndFunction

// Function determines whether there is
// a delivery confirmation for FTS documents
Function HasNotReceivedConfirmation(FileOwner, EDStatus)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EDAttachedFiles.Ref
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.FileOwner = &FileOwner
	|	AND EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.NotificationAboutReception)";
	Query.SetParameter("FileOwner", FileOwner);
	Result = Query.Execute();
	If Result.IsEmpty() Then
		EDStatus = Enums.EDVersionsStates.NotificationAboutReceivingExpected;
		Return True;
	EndIf;
	
	
	Return False;
	
EndFunction

Function IsResponseTitle(LinkToED)
	
	Result = False;
	EDKind = CommonUse.ObjectAttributeValue(LinkToED, "EDKind");
	
	If EDKind = Enums.EDKinds.TORG12Customer
		Or EDKind = Enums.EDKinds.ActCustomer
		Or EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient Then
		Result = True;
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Direct exchange with bank

// Returns used schema names space for the asynchronous exchange with bank
Function AsynchronousExchangeWithBanksNamespace() Export
	
	URI = "";
	Return URI;
	
EndFunction

Procedure SendEDStateRequestToBank(ParametersStructure, StorageAddress) Export
	
	ReturnStructure = New Structure;
	
	ED = ParametersStructure.ElectronicDocument;
	
	EDAttributes = CommonUse.ObjectAttributesValues(ED, "EDAgreement, FileOwner");
	
	AuthorizationParameters = New Map;
	DataAuthorization = New Structure("MarkerTranscribed", ParametersStructure.BankSessionID);
	AuthorizationParameters.Insert(EDAttributes.EDAgreement, DataAuthorization);
	
	AgreementAttributes = CommonUse.ObjectAttributesValues(
		EDAttributes.EDAgreement, "Company, Counterparty, CompanyID");
	Responsible = ElectronicDocumentsOverridable.GetResponsibleByED(
										AgreementAttributes.Counterparty, EDAttributes.EDAgreement);
	
	AttributeCompanyName = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
																		"ShortDescriptionOfTheCompany");
	If Not ValueIsFilled(AttributeCompanyName) Then
		AttributeCompanyName = "Description";
	EndIf;
	SenderName = CommonUse.GetAttributeValue(
		AgreementAttributes.Company, AttributeCompanyName);
	ClientApplicationVersion = ElectronicDocumentsReUse.ClientApplicationVersionForBank();
	CompanyAttributes = CommonUse.ObjectAttributesValues(AgreementAttributes.Company, "TIN, KPP");
	BankingDetails = CommonUse.ObjectAttributesValues(AgreementAttributes.Counterparty, "Code, description");
	TargetNamespace = ElectronicDocumentsService.AsynchronousExchangeWithBanksNamespace();
	AsynchronousExchangeWithBanksSchemeVersion = ElectronicDocumentsService.AsynchronousExchangeWithBanksSchemeVersion();
	
	ErrorText = "";
	Try
			
		UnIdED = New UUID;
		IDSourceED = ED.UUID();
			
		EDStateQuery = ElectronicDocumentsInternal.GetCMLObjectType("StatusRequest", TargetNamespace);
		ElectronicDocumentsInternal.FillXDTOProperty(EDStateQuery, "id", String(UnIdED), True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			EDStateQuery, "ExtID", String(IDSourceED), True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			EDStateQuery, "formatVersion", AsynchronousExchangeWithBanksSchemeVersion, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			EDStateQuery, "creationDate", CurrentSessionDate(), True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			EDStateQuery, "userAgent", ClientApplicationVersion, , ErrorText);
		Sender = ElectronicDocumentsInternal.GetCMLObjectType("CustomerPartyType", TargetNamespace);
		ElectronicDocumentsInternal.FillXDTOProperty(
			Sender, "id", AgreementAttributes.CompanyID, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			Sender, "name", SenderName, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			Sender, "tin", CompanyAttributes.TIN, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(Sender, "kpp", CompanyAttributes.KPP, , ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(EDStateQuery, "Sender", Sender, True, ErrorText);
		
		Recipient = ElectronicDocumentsInternal.GetCMLObjectType("BankPartyType", TargetNamespace);
		ElectronicDocumentsInternal.FillXDTOProperty(Recipient, "bic", BankingDetails.Code, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			Recipient, "name", BankingDetails.Description, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			EDStateQuery, "Recipient", Recipient, True, ErrorText);
		EDStateQuery.Validate();
		
		If ValueIsFilled(ErrorText) Then
			MessageText = ErrorText;
			Operation = NStr("en='ED formation';ru='Формирование ЭД'");
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
			FileIsFormed = False;
		Else
			TempFile = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
			ElectronicDocumentsInternal.ExportEDtoFile(EDStateQuery, TempFile, False, "UTF-8");
			FileIsFormed = True;
		EndIf;

	Except
		BriefErrorDescription = BriefErrorDescription(ErrorInfo());
		MessagePattern = NStr("en='%1 (see details in event log monitor).';ru='%1 (подробности см. в Журнале регистрации).'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
										MessagePattern, BriefErrorDescription);
		Operation = NStr("en='ED formation';ru='Формирование ЭД'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
							Operation, DetailErrorDescription, MessageText, 1);
		FileIsFormed = False;
	EndTry;
		
	If Not FileIsFormed Then
		ReturnStructure.Insert("QueryPosted", False);
		ReturnStructure.Insert("IsError", True);
		ReturnStructure.Insert("MessageText", MessageText);
		PutToTempStorage(ReturnStructure, StorageAddress);
		Return;
	EndIf;
	
	BinaryData = New BinaryData(TempFile);
	FileURL = PutToTempStorage(BinaryData);

	DeleteFiles(TempFile);
	
	EDName = NStr("en='ED query status';ru='Запрос состояния ЭД'");

	CurrentSessionDate = CurrentSessionDate();
	EDQuery = AttachedFiles.AddFile(EDAttributes.FileOwner, EDName, "xml", CurrentSessionDate,
		CurrentSessionDate, FileURL, , , Catalogs.EDAttachedFiles.GetRef(UnIdED));

	ParametersStructure = New Structure();
	ParametersStructure.Insert("Author", Users.AuthorizedUser());
	ParametersStructure.Insert("EDDirection", Enums.EDDirections.Outgoing);
	ParametersStructure.Insert("EDKind", Enums.EDKinds.EDStateQuery);
	ParametersStructure.Insert("EDStatus", Enums.EDStatuses.Created);
	ParametersStructure.Insert("Responsible", Responsible);
	ParametersStructure.Insert("Company", AgreementAttributes.Company);
	ParametersStructure.Insert("Counterparty", AgreementAttributes.Counterparty);
	ParametersStructure.Insert("ElectronicDocumentOwner", ED);
	ParametersStructure.Insert("EDAgreement", EDAttributes.EDAgreement);
	ParametersStructure.Insert("SenderDocumentDate", CurrentSessionDate);
	ParametersStructure.Insert("FileDescription", EDName);
	
	ChangeByRefAttachedFile(EDQuery, ParametersStructure, False);
	
	StructurePED = New Structure;
	
	StructurePED.Insert("Company", AgreementAttributes.Company);
	StructurePED.Insert("Counterparty", AgreementAttributes.Counterparty);
	StructurePED.Insert("Sender", AgreementAttributes.Company);
	StructurePED.Insert("Recipient", AgreementAttributes.Counterparty);
	StructurePED.Insert("EDFSetup", EDAttributes.EDAgreement);
	StructurePED.Insert("EDExchangeMethod", Enums.EDExchangeMethods.ThroughBankWebSource);
	TabularSectionData = New Array;
	TabularSectionData.Add(EDQuery);
	
	MessageText = "";
	EDP = CreateEDPack(StructurePED, TabularSectionData, MessageText);
	
	If Not ValueIsFilled(EDP) Then
		ReturnStructure.Insert("QueryPosted", False);
		ReturnStructure.Insert("IsError", True);
		ReturnStructure.Insert("MessageText", MessageText);
		PutToTempStorage(ReturnStructure, StorageAddress);
		Return;
	EndIf;
	
	CreateEDPackAsync(EDP);
	
	PacksArray = New Array;
	PacksArray.Add(EDP);
	QuantitySent = ElectronicDocumentsServiceCallServer.EDPackagesSending(
							PacksArray, AuthorizationParameters, MessageText);
	
	ReturnStructure.Insert("QueryPosted", QuantitySent > 0);
	ReturnStructure.Insert("IsError", QuantitySent = 0);
	ReturnStructure.Insert("MessageText", MessageText);
	ReturnStructure.Insert("EDStateQuery", EDQuery);
	PutToTempStorage(ReturnStructure, StorageAddress);
	
EndProcedure

// Requests bank documents until the required statement is received.
//
// Parameters:
//  ParametersStructure - structure,
//      contains 2 items ArrayED - in the CatalogRef.EDAttachedFiles items, electronic documents
//      of statements request EDAgraament - CatalogRef.EDUsageAgreements - agreement
//  with bank StorageAddres - String, contains storage address containing structure
//
Procedure GetBankStatementAsynchronously(ParametersStructure, StorageAddress) Export
	
	ReturnData = New Structure;
	ReturnData.Insert("IsError", False);
	EDAgreement = ParametersStructure.EDAgreement;
	ParametersStructure.Insert("MarkerTranscribed", ParametersStructure.BankSessionID);
	AuthorizationParameters = New Map;
	AuthorizationParameters.Insert(EDAgreement, ParametersStructure);
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	               |	EDAttachedFiles.Ref
	               |FROM
	               |	Catalog.EDAttachedFiles AS EDAttachedFiles
	               |WHERE
	               |	EDAttachedFiles.ElectronicDocumentOwner IN(&EDQueriesArray)";
	Query.SetParameter("EDQueriesArray", ParametersStructure.EDKindsArray);
	
	While True Do
		
		ElectronicDocumentsServiceCallServer.GetEDFromBankAsynchronousExchange(AuthorizationParameters, ReturnData);
		
		If ReturnData.IsError Then
			Break;
		EndIf;
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			ReturnData.Insert("BankStatement", Selection.Ref);
			Break;
		EndIf;
		
	EndDo;
	PutToTempStorage(ReturnData, StorageAddress);
	
EndProcedure

// Requests bank documents until the required statement is received.
//
// Parameters:
//  ParametersStructure - structure,
//      contains 2 items ArrayED - in the CatalogRef.EDAttachedFiles items, electronic documents
//      of statements request EDAgraament - CatalogRef.EDUsageAgreements - agreement
//  with bank StorageAddres - String, contains storage address containing structure
//
Procedure GetNotificationOnEDStateAsynchronously(ParametersStructure, StorageAddress) Export
	
	ReturnData = New Structure;
	ReturnData.Insert("IsError", False);
	EDAgreement = ParametersStructure.EDAgreement;
	ParametersStructure.Insert("MarkerTranscribed", ParametersStructure.BankSessionID);
	AuthorizationParameters = New Map;
	AuthorizationParameters.Insert(EDAgreement, ParametersStructure);
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	               |	EDAttachedFiles.Ref
	               |FROM
	               |	Catalog.EDAttachedFiles AS EDAttachedFiles
	               |WHERE
	               |	EDAttachedFiles.ElectronicDocumentOwner = ElectronicDocumentOwner";
	Query.SetParameter("ElectronicDocumentOwner", ParametersStructure.ElectronicDocument);
	
	While True Do
		
		ElectronicDocumentsServiceCallServer.GetEDFromBankAsynchronousExchange(AuthorizationParameters, ReturnData);
		
		If ReturnData.IsError Then
			Break;
		EndIf;
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			ReturnData.Insert("Notification", Selection.Ref);
			Break;
		EndIf;
		
	EndDo;
	PutToTempStorage(ReturnData, StorageAddress);
	
EndProcedure

// Creates EDPack document and fills in its attributes
//
// Parameters:
//  DocumentAttributes - Structure - document attributes
//  values EDArray - Array - contains references to the the EDAttachedFiles catalog
//
// Returns:
//   DocumentRef.EDPackage - ref to the created document
//
Function CreateEDPack(DocumentAttributes, EDKindsArray, MessageText = "") Export
	
	SetPrivilegedMode(True);
	
	DataEncrypted = False;
	EncryptionCertificate = Undefined;
	RequiredEncryptionAtClient = False;
	UseDS = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
		"UseDigitalSignatures");
	
	If UseDS Then
		If DocumentAttributes.Property("CounterpartyCertificateForEncryption") 
			AND ValueIsFilled(DocumentAttributes.CounterpartyCertificateForEncryption)
			AND DocumentAttributes.EDExchangeMethod <> Enums.EDExchangeMethods.ThroughBankWebSource
			AND DocumentAttributes.EDExchangeMethod <> Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
			
			EncryptionCertificate = DocumentAttributes.CounterpartyCertificateForEncryption.Get();
			If ValueIsFilled(EncryptionCertificate) Then
				DataEncrypted = True;
				
				CryptoCertificate = New CryptoCertificate(EncryptionCertificate);
				EncryptionCertificate   = DigitalSignatureClientServer.SubjectPresentation(CryptoCertificate);
				
				If Not ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer() Then
					RequiredEncryptionAtClient = True;
					DocumentAttributes.Insert("RequiredEncryptionAtClient", True);
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	EDP = Documents.EDPackage.CreateDocument();
	EDP.Date = CurrentSessionDate();
	If DocumentAttributes.Property("Sender") Then
		EDP.Sender = DocumentAttributes.Sender;
	EndIf;
	If DocumentAttributes.Property("Recipient") Then
		EDP.Recipient = DocumentAttributes.Recipient;
	EndIf;
	EDP.Counterparty = DocumentAttributes.Counterparty;
	EDP.Company = DocumentAttributes.Company;
	
	EDP.PackageStatus = Enums.EDPackagesStatuses.PreparedToSending;
	EDP.Direction = Enums.EDDirections.Outgoing;
	EDP.DataEncrypted = DataEncrypted;
	EDP.EncryptionCertificate = EncryptionCertificate;
	If DocumentAttributes.Property("PackageFormatVersion") Then
		EDP.PackageFormatVersion = DocumentAttributes.PackageFormatVersion;
	EndIf;
	
	If DocumentAttributes.Property("SenderAddress") Then
		EDP.CompanyResourceAddress = DocumentAttributes.SenderAddress;
	EndIf;
	If DocumentAttributes.Property("RecipientAddress") Then
		EDP.CounterpartyResourceAddress = DocumentAttributes.RecipientAddress;
	EndIf;

	If DocumentAttributes.Property("EDAgreement") Then
		EDP.EDFSetup = DocumentAttributes.EDAgreement;
	Else
		EDP.EDFSetup = DocumentAttributes.EDFSetup;
	EndIf;
	
	EDP.EDExchangeMethod = DocumentAttributes.EDExchangeMethod;
	
	If DocumentAttributes.Property("EDFProfileSettings") Then
		EDP.EDFProfileSettings = DocumentAttributes.EDFProfileSettings;
	EndIf;
	
	EDOwners = CommonUse.ObjectsAttributeValue(EDKindsArray, "FileOwner");
	
	For Each ED IN EDKindsArray Do
		NewRow = EDP.ElectronicDocuments.Add();
		NewRow.ElectronicDocument = ED;
		NewRow.OwnerObject = EDOwners.Get(ED);
	EndDo;
	
	Try
		EDP.Write();
	Except
		MessagePattern = NStr("en='%1 (for more information, see Events log monitor)';ru='%1 (подробности см. в Журнале регистрации)'");
		BriefErrorDescription = BriefErrorDescription(ErrorInfo());
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
									MessagePattern, BriefErrorDescription);
		Operation = NStr("en='generate ED pack';ru='формирование пакета ЭД'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
								Operation, DetailErrorDescription, MessageText);
		Return Undefined;
	EndTry;
		
	Return EDP.Ref;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Exchange with banks

// Returns XSD schema version for the asynchronous exchange with bank
Function AsynchronousExchangeWithBanksSchemeVersion() Export
	
	Return "2.01";
	
EndFunction

// Creates electronic document for documents pack
//
// Parameters
//  Envelope  - DocumentRef.EDPackage - ref to pack 
//
Procedure CreateEDPackAsync(Envelop) Export
	
	TargetNamespace = ElectronicDocumentsService.AsynchronousExchangeWithBanksNamespace();
	Try
		ErrorText = "";
		
		IsFirstED = True;
		For Each String IN Envelop.ElectronicDocuments Do
			ED = String.ElectronicDocument;
			EDData = AttachedFiles.GetFileBinaryData(ED);
			FileName = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
			EDData.Write(FileName);
			XMLObject = New XMLReader;
			XMLObject.OpenFile(FileName);
			
			EDKind = CommonUse.ObjectAttributeValue(ED, "EDKind");
			AsynchronousExchangeNamesSpace = ElectronicDocumentsService.AsynchronousExchangeWithBanksNamespace();
			
			If EDKind = Enums.EDKinds.PaymentOrder Then
				ValueType = ElectronicDocumentsInternal.GetCMLValueType(
								"PayDocRu", AsynchronousExchangeNamesSpace);
			ElsIf EDKind = Enums.EDKinds.QueryStatement Then
				ValueType = ElectronicDocumentsInternal.GetCMLValueType(
								"StatementRequest", AsynchronousExchangeNamesSpace);
			ElsIf EDKind = Enums.EDKinds.QueryProbe Then
				ValueType = ElectronicDocumentsInternal.GetCMLValueType(
								"Probe", AsynchronousExchangeNamesSpace);
			ElsIf EDKind = Enums.EDKinds.EDReturnQuery Then
				ValueType = ElectronicDocumentsInternal.GetCMLValueType(
								"CancelationRequest", AsynchronousExchangeNamesSpace);
			ElsIf EDKind = Enums.EDKinds.EDStateQuery Then
				ValueType = ElectronicDocumentsInternal.GetCMLValueType(
								"StatusRequest", AsynchronousExchangeNamesSpace);
			EndIf;
			
			XDTOData = XDTOFactory.ReadXML(XMLObject, ValueType);
			
			If IsFirstED Then
				Packet = ElectronicDocumentsInternal.GetCMLObjectType("Packet", TargetNamespace);
				Sender = ElectronicDocumentsInternal.GetCMLObjectType("ParticipantType", TargetNamespace);
				CustomerPartyType = ElectronicDocumentsInternal.GetCMLObjectType("CustomerPartyType", TargetNamespace);
				id = XDTOData.Sender.id;
				name = XDTOData.Sender.name;
				tin = XDTOData.Sender.tin;
				kpp = XDTOData.Sender.kpp;
				bic = XDTOData.Recipient.bic;
				bankName = XDTOData.Recipient.name;
				docId = XDTOData.id;
				formatVersion = XDTOData.formatVersion;
				
				ElectronicDocumentsInternal.FillXDTOProperty(CustomerPartyType, "id", id, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(CustomerPartyType, "name", name, , ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(CustomerPartyType, "tin", tin, , ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(CustomerPartyType, "kpp", kpp, , ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(
					Sender, "Customer", CustomerPartyType, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(Packet, "Sender", Sender, True, ErrorText);
				
				Recipient = ElectronicDocumentsInternal.GetCMLObjectType("ParticipantType", TargetNamespace);
				BankPartyType = ElectronicDocumentsInternal.GetCMLObjectType("BankPartyType", TargetNamespace);
				ElectronicDocumentsInternal.FillXDTOProperty(BankPartyType, "bic", bic, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(BankPartyType, "name", bankName, , ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(Recipient, "Bank", BankPartyType, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(Packet, "Recipient", Recipient, True, ErrorText);
			EndIf;
			IsFirstED = False;
			DocumentType = ElectronicDocumentsInternal.GetCMLObjectType("DocumentType", TargetNamespace);
			ElectronicDocumentsInternal.FillXDTOProperty(DocumentType, "id", docId, True, ErrorText);
			EDKind = CommonUse.ObjectAttributeValue(ED, "EDKind");
			If EDKind = Enums.EDKinds.PaymentOrder Then
				EDPackKind = "10"
			ElsIf EDKind = Enums.EDKinds.QueryStatement Then
				EDPackKind = "14"
			ElsIf EDKind = Enums.EDKinds.EDStateQuery Then
				EDPackKind = "03"
			ElsIf EDKind = Enums.EDKinds.EDReturnQuery Then
				EDPackKind = "04"
			ElsIf EDKind = Enums.EDKinds.QueryProbe Then
				EDPackKind = "05"
			EndIf;
			ElectronicDocumentsInternal.FillXDTOProperty(DocumentType, "docKind", EDPackKind, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(
				DocumentType, "formatVersion", formatVersion, True, ErrorText);
			
			data = ElectronicDocumentsInternal.GetCMLObjectType("DocumentType.data", TargetNamespace);
			ElectronicDocumentsInternal.FillXDTOProperty(data, "__content", EDData, True, ErrorText);
			
			ElectronicDocumentsInternal.FillXDTOProperty(DocumentType, "data", data, True, ErrorText);
			
			signature = ElectronicDocumentsInternal.GetCMLObjectType("DocumentType.signature", TargetNamespace);
			For Each SignatureRow IN ED.DigitalSignatures Do
				ElectronicDocumentsInternal.FillXDTOProperty(
					signature, "signedData", SignatureRow.Signature.Get(), True, ErrorText);
				Certificate = New CryptoCertificate(SignatureRow.Certificate.Get());
				ElectronicDocumentsInternal.FillXDTOProperty(
					signature, "x509SerialNumber", Certificate.SerialNumber, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(
					signature, "x509Issue", Certificate.Issuer.CN, True, ErrorText);
				DocumentType.signature.Add(signature);
			EndDo;
			
			Packet.Document.Add(DocumentType);
			XMLObject.Close();
			DeleteFiles(FileName);
			
		EndDo;
		
		ElectronicDocumentsInternal.FillXDTOProperty(
			Packet, "id", String(Envelop.UUID()), True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(Packet, "formatVersion",
			ElectronicDocumentsService.AsynchronousExchangeWithBanksSchemeVersion(), True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			Packet, "creationDate", CurrentSessionDate(), True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(Packet, "userAgent",
			ElectronicDocumentsReUse.ClientApplicationVersionForBank(), , ErrorText);
			
		Packet.Validate();

		FileName = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
		ElectronicDocumentsInternal.ExportEDtoFile(Packet, FileName, False, "UTF-8");
		
		If ValueIsFilled(ErrorText) Then
			CommonUseClientServer.MessageToUser(ErrorText);
			ObjectEnvelope = Envelop.GetObject();
			ObjectEnvelope.DeletionMark = True;
			ObjectEnvelope.Write();
		Else
			PlaceEDPackageIntoEnvelop(Envelop, FileName);
		EndIf;
		
	Except
		XMLObject.Close();
		MessagePattern = NStr("en='%1 (see details in event log monitor).';ru='%1 (подробности см. в Журнале регистрации).'");
		BriefErrorDescription = BriefErrorDescription(ErrorInfo());
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
										MessagePattern, BriefErrorDescription);
		OperationKind = NStr("en='ED formation';ru='Формирование ЭД'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
			OperationKind, DetailErrorDescription, MessageText, 1);
	EndTry;
	
	DeleteFiles(FileName);
	
EndProcedure

Procedure CreateEDPackCMSDETACHED(Envelop)
	
	ED = Envelop.ElectronicDocuments[0].ElectronicDocument;
	
	Data = AttachedFiles.GetFileBinaryData(ED);
	URI = "urn:x-obml:1.0";
	TypeMessage = XDTOFactory.Type("urn:x-obml:1.0","CMSDETACHED");
	Message = XDTOFactory.Create(TypeMessage);
	TypeData = TypeMessage.Properties[0].Type;
	Data = XDTOFactory.Create(TypeData);
	Data.ContentType = "application/xml";
	Data.__content = Data;
	Message.data = Data;
		
	For Each SignatureRow IN ED.DigitalSignatures Do
		Message.signature.Add(SignatureRow.Signature.Get());
	EndDo;
	
	PathToSendingFile = GetTempFileName("xml");
	Record = New XMLWriter;
	Record.OpenFile(PathToSendingFile);
	Record.WriteXMLDeclaration();

	XDTOFactory.WriteXML(Record,Message,"signed",URI,,XMLTypeAssignment.Explicit);
	
	Record.Close();
	
	PlaceEDPackageIntoEnvelop(Envelop, PathToSendingFile);
	
	DeleteFiles(PathToSendingFile);
	
EndProcedure

Procedure RequestBankStatementAsynchronously(ParametersStructure, StorageAddress)
	
	EDKindsArray = ParametersStructure.EDKindsArray;
	MessageText = "";
	
	AgreementAttributes = CommonUse.ObjectAttributesValues(
			ParametersStructure.EDAgreement, "Company, Counterparty");
	AgreementAttributes.Insert("EDFSetup", ParametersStructure.EDAgreement);
	AgreementAttributes.Insert("EDExchangeMethod", Enums.EDExchangeMethods.ThroughBankWebSource);
	
	EDPackage = CreateEDPack(AgreementAttributes, EDKindsArray);
	
	ElectronicDocumentsService.CreateEDPackAsync(EDPackage);
	
	PacksArray = New Array;
	PacksArray.Add(EDPackage);
	CertificatesAgreementsAndParametersMatch = New Map;
	ParametersStructure.Insert("MarkerTranscribed", ParametersStructure.BankSessionID);
	CertificatesAgreementsAndParametersMatch.Insert(ParametersStructure.EDAgreement, ParametersStructure);
	QuantitySent = ElectronicDocumentsServiceCallServer.EDPackagesSending(
							PacksArray, CertificatesAgreementsAndParametersMatch, MessageText);
							
	ReturnStructure = New Structure;
	ReturnStructure.Insert("QueryPosted", QuantitySent > 0);
	ReturnStructure.Insert("IsError", ValueIsFilled(MessageText));
	ReturnStructure.Insert("MessageText", MessageText);
	ReturnStructure.Insert("BankStatement", Undefined);
	PutToTempStorage(ReturnStructure, StorageAddress);
	
EndProcedure


#Region CallsFromOverridableDSModules

// Called
// from DigitalSignatureOverridable, from the eponymous procedures that are called from
// the CertificateCheck form if additional checks are added while creating form.
//
// Parameters:
//  Certificate           - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - certificate being checked.
//  Checking             - String - name of the checking added
//                            in the OnCreateFormCertificateChecking procedure of the DigitalSignatureOverridable common module.
//  CryptoManager - CryptoManager - prepared cryptography
//                            manager to perform checking.
//  ErrorDescription       - String - (return value) - description of an error received during checking.
//                            Users see this description after they click the result picture.
//  IsWarning    - Boolean - (return value) - picture kind Error/Warning
// initial value False
// 
Procedure OnAdditionalCertificateVerification(Certificate, CheckKind, CryptoManager, ErrorDescription, IsWarning) Export
	
	// Authorization on Taxcom server
	If CheckKind = "ConnectionTestWithOperator" Then
					
		Structure = New Structure;
		Structure.Insert("SignatureCertificate", Certificate);
		EncryptedData = ElectronicDocumentsServiceCallServer.EncryptedMarker(Structure);
		
		// Details
		ErrorDescription = "";
		Try
			DecryptedData = CryptoManager.Decrypt(EncryptedData);
			DigitalSignatureServiceClientServer.EmptyDecryptedData(DecryptedData, ErrorDescription);
		Except
			ErrorInfo = ErrorInfo();
			ErrorDescription = BriefErrorDescription(ErrorInfo);
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion


#Region _SSL_DigitalSignature

// Writes information about object signing
//
// Parameters
//  SignedObjectRef  - any reference / object - to the tabular section of which information about
//  							DS will be written if the ref - object will be received, lock, record
//  							in IB, in the case of the object, the NewSignatureBinaryData
//  caller code is responsible for locking and recording  - BinaryData - Thumbprint
//  signature binary data  - String - Base64 encoded string with the certificate
//  thumbprint that signed SignatureDate  - Date - Comment
//  signature date  - String - SignatureFileName
//  signature comment  - String - name of the signature file (it is not empty only if the
//  signature is added from a file) IssuedToWhom  - String - IssuedToWhom field
//  presentation of the UUID certificate - UUID - form unique ID
//
Procedure AddInformationAboutSignature(
			ObjectForSigningRef,
			NewSignatureBinaryData,
			Imprint,
			SignatureDate,
			Comment,
			SignatureFileName,
			CertificateIsIssuedTo,
			CertificateBinaryData,
			UUID = Undefined) Export
	
	If CommonUse.IsReference(TypeOf(ObjectForSigningRef)) Then
		ObjectForSigning = ObjectForSigningRef.GetObject();
		ObjectForSigning.Lock();
	Else
		ObjectForSigning = ObjectForSigningRef;
	EndIf;
	
	If SignatureDate = Date('00010101') Then
		SignatureDate = CurrentSessionDate();
	EndIf;	
	
	NewRecord = ObjectForSigning.DigitalSignatures.Add();
	
	NewRecord.CertificateIsIssuedTo = CertificateIsIssuedTo;
	NewRecord.SignatureDate         = SignatureDate;
	NewRecord.SignatureFileName     = SignatureFileName;
	NewRecord.Comment         = Comment;
	NewRecord.Imprint           = Imprint;
	NewRecord.Signature             = New ValueStorage(NewSignatureBinaryData);
	NewRecord.Signer = Users.CurrentUser();
	NewRecord.Certificate          = New ValueStorage(CertificateBinaryData);
	
	ObjectForSigning.DigitallySigned = True;
	ObjectForSigning.AdditionalProperties.Insert("DigitallySignedObjectRecord", True); // to write object signed earlier
	
	If CommonUse.IsReference(TypeOf(ObjectForSigningRef)) Then
		SetPrivilegedMode(True);
		ObjectForSigning.Write();
		ObjectForSigning.Unlock();
	EndIf;
	
EndProcedure

// Converts certificates destination to
// a
// friendly kind Parameters Destination  - String - destination of the certificate as "TLS
//  Web Client Authentication (1.3.6.1.5.5.7.3.2)" NewDestination  - String - understandable destination of certificate as "Check
//     client validity" AddDestinationCode  - Boolean - whether it is required to add destination code to the destination (for example, 1.3.6.1.5.5.7.3.2 to receive "Check client validity (1.3.6.1.5.5.7.3.2)")
Procedure FillCertificatePurpose(Purpose, NewPurpose, AddPurposeCode = False) Export
	
	SetPrivilegedMode(True);
	NewPurpose = "";
	
	For IndexOf = 1 To StrLineCount(Purpose) Do
		
		String = StrGetLine(Purpose, IndexOf); 		
		Presentation = Purpose;
		Code = "";
		
		Position = StringFunctionsClientServer.FindCharFromEnd(String, "(");
		If Position <> 0 Then
			
			Presentation = Left(String, Position - 1);
			Code = Mid(String, Position + 1, StrLen(String) - Position - 1);
			
			If AddPurposeCode Then
				Presentation = Presentation  + " (" + Code + ")";
			EndIf;
			
		EndIf;		
		
		NewPurpose = NewPurpose + Presentation;
		NewPurpose = NewPurpose + Chars.LF;
		
	EndDo;	
	
EndProcedure

// Receives all file signatures.
//
// Parameters
//  ObjectRef  - CatalogRef - ref object tabular section of which
//  contains signatures UUID - UUID - form unique ID
//
// Returns:
//  ReturnArray - Array  - structures array with the return values
//
Function GetAllSignatures(ObjectReference, UUID) Export
	
	ReturnArray = New Array;
	
	//VersionRef = CommonUse.ObjectAttributeValue(FileRef, "CurrentVersion");
	ObjectWithDSFullName = ObjectReference.Metadata().FullName();
	
	QueryText = "SELECT ALLOWED
					|	DigitalSignatures.CertificateIsIssuedTo AS CertificateIsIssuedTo,
					|	DigitalSignatures.Signature             AS Signature,
					|	DigitalSignatures.SignatureFileName     AS SignatureFileName
					|FROM
					|	[ObjectWithDSFullName].DigitalSignatures AS DigitalSignatures
					|WHERE
					|	DigitalSignatures.Ref = &ObjectReference";
	
	QueryText = StrReplace(QueryText, "[ObjectWithDSFullName]", ObjectWithDSFullName);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.Parameters.Insert("ObjectReference", ObjectReference);
	
	QuerySelection = Query.Execute().Select();
	
	While QuerySelection.Next() Do
		BinaryData = QuerySelection.Signature.Get();
		SignatureAddress = PutToTempStorage(BinaryData, UUID);
		ReturnStructure = New Structure("SignatureAddress, CertificateIsIssuedTo, SignatureFileName",
											SignatureAddress,
											QuerySelection.CertificateIsIssuedTo,
											QuerySelection.SignatureFileName);
		ReturnArray.Add(ReturnStructure);
	EndDo;
	
	Return ReturnArray;
	
EndFunction

#EndRegion
