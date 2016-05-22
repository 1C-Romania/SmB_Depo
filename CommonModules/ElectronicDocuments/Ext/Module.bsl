////////////////////////////////////////////////////////////////////////////////
// ElectronicDocuments: mechanism of electronic documents exchange.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// It generates a last name and initials from the passed string.
//
// Parameters
//  FullDescr - String with the name.
//
// Returns:
//  String - last name and initials in one string.
//  Calculated parts are written to parameters Last name, Name, and Patronymic.
//
// Example:
//  Result = SurnameInitialsOfIndividual("Ivanov Ivan Ivanovich"); Result = "Ivanov I. I."
//
Function SurnameInitialsOfIndividual(FullDescr, Surname = " ", Name = " ", Patronymic = " ") Export
	
	ElectronicDocumentsOverridable.ParseIndividualDescription(FullDescr, Surname, Name, Patronymic);
	If Not ValueIsFilled(Surname) AND Not ValueIsFilled(Name) AND Not ValueIsFilled(Patronymic) Then
		
		Initials = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(TrimAll(FullDescr), " ");
		
		CountSubstrings = Initials.Count();
		Surname            = ?(CountSubstrings > 0, Initials[0], "");
		Name                = ?(CountSubstrings > 1, Initials[1], "");
		Patronymic           = ?(CountSubstrings > 2, Initials[2], "");
	EndIf;
	
	Return ?(NOT IsBlankString(Surname), Surname + ?(NOT IsBlankString(Name), " " + Left(Name, 1) + "."
		+ ?(NOT IsBlankString(Patronymic), Left(Patronymic, 1) + ".", ""), ""), "");
	
EndFunction

// Determines whether an actual e-document Customer invoice note exists for the passed owner.
//
// Parameters
//  RefToOwner - DocumentRef, - electronic document owner
//
// Returns:
//  Boolean - True - whether an actual document exists, otherwise, False.
//
Function IsWorkingESF(RefToOwner) Export
	
	Return ElectronicDocumentsServiceCallServer.IsWorkingESF(RefToOwner);
	
EndFunction

// Receives the value of the functional option.
//
// Parameters:
//  FODescription - String, functional option name
//
// Returns:
//  ReturnValue - Boolean, FO inclusion result.
//
Function GetFunctionalOptionValue(FODescription) Export
	
	ReturnValue = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(FODescription);
	Return ReturnValue;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with the electronic document versions

// Gets a presentation (text or structure) of document states by owners.
//
// Parameters:
// RefsArrayToOwners - array of references to e-document owners which data it is required to get.
// PlaceIntoStructure - Boolean if true, then presentations of
//                      e-documents states (EDVersionState,
//                      ActionsFromOurSide, ActionsFromOtherPartySide) will be placed in the structure for further parsing in the client.
//
// Returns:
// Map - matching the IB document references and ED states. Key - IB document
//                ref, Value - the text (ED state) or structure - depending on the PlaceIntoStructure parameter.
//
Function GetTextOfEDStateByOwners(RefsArrayToOwners, PlaceIntoStructure = False) Export
		
	DataTable = ElectronicDocumentsServiceCallServer.GetDataEDByOwners(RefsArrayToOwners);
	Map = New Map;
	For Each CurRow IN DataTable Do
		
		If PlaceIntoStructure Then
			EDVersionState = New Structure("EDVersionState, ActionsFromOurSide, ActionsFromOtherPartySide");
			FillPropertyValues(EDVersionState, CurRow);
		Else
			EDVersionState = String(CurRow.EDVersionState);
		EndIf;
		Map.Insert(CurRow.EDOwner, EDVersionState);
	EndDo;
	
	Return Map;
	
EndFunction

// Receives an issue date of the electronic customer invoice note.
//
// Parameters:
// CustomerInvoiceNote - DocumentRef - ref to an outgoing customer invoice note in the applied solution.
//
// Returns:
//  DateOfExtension - Date - electronic customer invoice note date.
//
Function DateOfExtensionInvoice(CustomerInvoiceNote) Export
	
	DateOfExtension = Undefined;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDStates.ElectronicDocument
	|FROM
	|	InformationRegister.EDStates AS EDStates
	|WHERE
	|	EDStates.ObjectReference = &ObjectReference";
	Query.SetParameter("ObjectReference", CustomerInvoiceNote);
	
	Result = Query.Execute().Select();
	Result.Next();
	
	If ValueIsFilled(Result.ElectronicDocument) Then
		Query = New Query;
		Query.Text =
		"SELECT
		|	EDAttachedFiles.SenderDocumentDate
		|FROM
		|	Catalog.EDAttachedFiles AS EDAttachedFiles
		|WHERE
		|	EDAttachedFiles.ElectronicDocumentOwner = &ElectronicDocumentOwner
		|	AND EDAttachedFiles.VersionPointTypeED = VALUE(Enum.EDVersionElementTypes.EIRDC)";
		Query.SetParameter("ElectronicDocumentOwner", Result.ElectronicDocument);
		
		Result = Query.Execute().Select();
		Result.Next();
		DateOfExtension = Result.SenderDocumentDate;
	EndIf;
	
	Return DateOfExtension
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Processing the electronic documents

// Returns the query text for electronic documents of the signature.
// Variants - for workplace of documents
// to be signed or indicator in the desktop (UT 11)
//
// Parameters:
//  ForDesktop - Boolean, a flag showing that a query text is generated for indicator in the desktop (UT 11)
//
Function GetTextOfElectronicDocumentsQueryOnSigning(ForDesktop = True, AddFiltersStructure = Undefined) Export

	QueryText =
		"SELECT ALLOWED
		|	EDAttachedFiles.Ref AS ED,
		|	EDAttachedFiles.DocumentAmount,
		|	EDAttachedFiles.SenderDocumentDate,
		|	CASE
		|		WHEN EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.ProductsDirectory)
		|				OR EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.CustomerInvoiceNote)
		|				OR EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.CorrectiveInvoiceNote)
		|				OR EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.NotificationAboutReception)
		|				OR EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.Confirmation)
		|				OR EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.NotificationAboutClarification)
		|				OR EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.Error)
		|			THEN """"""""
		|		WHEN EDAttachedFiles.EDFormingDateBySender = DATETIME(1, 1, 1, 0, 0, 0)
		|			THEN EDAttachedFiles.EDVersionNumber
		|		ELSE EDAttachedFiles.EDFormingDateBySender
		|	END AS Version,
		|	EDAttachedFiles.EDKind,
		|	EDAttachedFiles.EDDirection,
		|	EDAttachedFiles.Company,
		|	EDAttachedFiles.Counterparty,
		|	EDAttachedFiles.EDFProfileSettings,
		|	EDAttachedFiles.EDAgreement,
		|	EDAttachedFiles.EDStatus,
		|	EDAttachedFiles.Changed
		|INTO EDForSigning
		|FROM
		|	InformationRegister.EDStates AS EDStates
		|		LEFT JOIN Catalog.EDAttachedFiles AS EDAttachedFiles
		|		ON EDStates.ElectronicDocument = EDAttachedFiles.Ref
		|WHERE
		|	EDStates.EDVersionState = VALUE(Enum.EDVersionsStates.OnSigning)
		|	AND Not EDAttachedFiles.DeletionMark
		|
		|UNION ALL
		|
		|SELECT
		|	EDAttachedFiles.Ref,
		|	0,
		|	EDAttachedFiles.SenderDocumentDate,
		|	"""",
		|	EDAttachedFiles.EDKind,
		|	EDAttachedFiles.EDDirection,
		|	EDAttachedFiles.Company,
		|	EDAttachedFiles.Counterparty,
		|	EDAttachedFiles.EDFProfileSettings,
		|	EDAttachedFiles.EDAgreement,
		|	EDAttachedFiles.EDStatus,
		|	EDAttachedFiles.Changed
		|FROM
		|	Catalog.EDAttachedFiles AS EDAttachedFiles
		|WHERE
		|	EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.RandomED)
		|	AND (EDAttachedFiles.EDStatus = VALUE(Enum.EDStatuses.Created)
		|			OR EDAttachedFiles.EDStatus = VALUE(Enum.EDStatuses.Approved)
		|			OR EDAttachedFiles.EDStatus = VALUE(Enum.EDStatuses.DigitallySigned)
		|			OR EDAttachedFiles.EDStatus = VALUE(Enum.EDStatuses.PreparedToSending)
		|			OR EDAttachedFiles.EDStatus = VALUE(Enum.EDStatuses.Received)
		|				AND CAST(EDAttachedFiles.FileOwner AS Document.RandomED).ConfirmationRequired)
		|	AND Not EDAttachedFiles.DeletionMark
		|
		|UNION ALL
		|
		|SELECT
		|	ServiceED.Ref,
		|	ServiceED.DocumentAmount,
		|	ServiceED.SenderDocumentDate,
		|	CASE
		|		WHEN ServiceED.EDKind = VALUE(Enum.EDKinds.ProductsDirectory)
		|				OR ServiceED.EDKind = VALUE(Enum.EDKinds.CustomerInvoiceNote)
		|				OR ServiceED.EDKind = VALUE(Enum.EDKinds.CorrectiveInvoiceNote)
		|				OR ServiceED.EDKind = VALUE(Enum.EDKinds.NotificationAboutReception)
		|				OR ServiceED.EDKind = VALUE(Enum.EDKinds.Confirmation)
		|				OR ServiceED.EDKind = VALUE(Enum.EDKinds.NotificationAboutClarification)
		|				OR ServiceED.EDKind = VALUE(Enum.EDKinds.Error)
		|			THEN """"""""
		|		WHEN ServiceED.EDFormingDateBySender = DATETIME(1, 1, 1, 0, 0, 0)
		|			THEN ServiceED.EDVersionNumber
		|		ELSE ServiceED.EDFormingDateBySender
		|	END,
		|	ServiceED.EDKind,
		|	ServiceED.EDDirection,
		|	ServiceED.Company,
		|	ServiceED.Counterparty,
		|	ServiceED.EDFProfileSettings,
		|	ServiceED.EDAgreement,
		|	ServiceED.EDStatus,
		|	ServiceED.Changed
		|FROM
		|	Catalog.EDAttachedFiles AS EDAttachedFiles
		|		INNER JOIN Catalog.EDAttachedFiles AS ServiceED
		|		ON EDAttachedFiles.Ref = ServiceED.ElectronicDocumentOwner
		|WHERE
		|	ServiceED.EDStatus = VALUE(Enum.EDStatuses.Approved)
		|	AND Not ServiceED.DeletionMark
		|	AND Not(ServiceED.VersionPointTypeED = VALUE(Enum.EDVersionElementTypes.PrimaryED)
		|				OR ServiceED.VersionPointTypeED = VALUE(Enum.EDVersionElementTypes.ESF))
		|	AND EDAttachedFiles.EDDirection = VALUE(Enum.EDDirections.Incoming)
		|
		|INDEX BY
		|	EDAttachedFiles.EDAgreement,
		|	EDAttachedFiles.Company,
		|	EDAttachedFiles.EDKind
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	NestedSelect.Certificate,
		|	NestedSelect.ED
		|INTO TU_CertificatesFromSettingsAndProfiles
		|FROM
		|	(SELECT DISTINCT
		|		EDFProfilesCertificates.Certificate AS Certificate,
		|		EDForSigning.ED AS ED
		|	FROM
		|		EDForSigning AS EDForSigning
		|			LEFT JOIN Catalog.EDFProfileSettings.CompanySignatureCertificates AS EDFProfilesCertificates
		|			ON EDForSigning.EDFProfileSettings = EDFProfilesCertificates.Ref
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		AgreementsEDCertificates.Certificate,
		|		EDForSigning.ED
		|	FROM
		|		EDForSigning AS EDForSigning
		|			LEFT JOIN Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsEDCertificates
		|			ON EDForSigning.EDAgreement = AgreementsEDCertificates.Ref) AS NestedSelect
		|		INNER JOIN Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS ESCertificates
		|			INNER JOIN InformationRegister.DigitallySignedEDKinds AS DigitallySignedEDKinds
		|			ON ESCertificates.Ref = DigitallySignedEDKinds.DSCertificate
		|		ON NestedSelect.Certificate = ESCertificates.Ref
		|WHERE
		|	(ESCertificates.User = &CurrentUser
		|			OR ESCertificates.User = VALUE(Catalog.Users.EmptyRef)
		|			OR ESCertificates.User IS NULL )
		|	AND Not ESCertificates.Revoked
		|	AND Not ESCertificates.DeletionMark
		|	AND DigitallySignedEDKinds.Use
		|	AND DigitallySignedEDKinds.EDKind = NestedSelect.ED.EDKind
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	*
		|FROM
		|	EDForSigning AS EDForSigning
		|		INNER JOIN Catalog.EDUsageAgreements AS AgreementsED
		|		ON EDForSigning.EDAgreement = AgreementsED.Ref
		|			AND (AgreementsED.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
		|					AND AgreementsED.AgreementStatus = VALUE(Enum.EDAgreementsStatuses.Acts)
		|				OR AgreementsED.EDExchangeMethod <> VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
		|					AND AgreementsED.ConnectionStatus = VALUE(Enum.EDExchangeMemberStatuses.Connected))
		|		INNER JOIN TU_CertificatesFromSettingsAndProfiles AS ESCertificates
		|		ON EDForSigning.ED = ESCertificates.ED
		|WHERE
		|	Not AgreementsED.DeletionMark
		|	AND Not ESCertificates.Certificate.Imprint In
		|				(SELECT DISTINCT
		|					ED_DS.Imprint
		|				FROM
		|					Catalog.EDAttachedFiles.DigitalSignatures AS ED_DS
		|				WHERE
		|					ED_DS.Ref = EDForSigning.ED)";
		
	If ForDesktop Then
		QueryText = StrReplace(QueryText, "*", "
			|	ESCertificates.Certificate.Imprint AS Imprint,
			|	ESCertificates.Certificate.Presentation AS Certificate,
			|	COUNT(DISTINCT ESCertificates.Certificate) AS IndicatorValue
			|");
		
		If AddFiltersStructure <> Undefined AND TypeOf(AddFiltersStructure) = Type("Structure")
			AND AddFiltersStructure.Count() > 0 AND AddFiltersStructure.Property("FilterByPerformers") Then
			QueryText = QueryText + " And EDForSigning.Changed IN (&PerformersContent)";
		EndIf;
		QueryText = QueryText + "
			|	GROUP BY DSCertificates.Certificate.Thumbprint, DSCertificates.Certificate.Presentation";
	Else
		QueryText = StrReplace(QueryText, "*", "
			|	EDForSigning.ED
			|	AS
			|	ElectronicDocument,
			|	EDForSigning.DocumentAmount, EDForSigning.Version, EDForSigning.SenderDocumentDate
			|	AS DocumentDate, EDForSigning.EDKind
			|	AS EDKind, DSCertificates.Certificate AS Certificate
			|");
		
		If AddFiltersStructure <> Undefined AND TypeOf(AddFiltersStructure) = Type("Structure")
			AND AddFiltersStructure.Count() > 0 Then
			
			If AddFiltersStructure.Property("FilterByPerformers") Then
				QueryText = QueryText + " And EDForSigning.Changed IN (&PerformersContent)";
			EndIf;
			If AddFiltersStructure.Property("Counterparty") Then
				QueryText = QueryText + " And EDForSigning.Counterparty = &Counterparty";
			EndIf;
			If AddFiltersStructure.Property("EDKind") Then
				QueryText = QueryText + " And EDForSigning.EDKind = &EDKind";
			EndIf;
			If AddFiltersStructure.Property("EDDirection") Then
				QueryText = QueryText + " And EDForSigning.EDForward = &EDForward";
			EndIf;
		EndIf;
		QueryText = QueryText + " ARRANGE BY DocumentDate";
	EndIf;
	
	Return QueryText;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Transfer of electronic documents to Federal Tax Service

// Receives a match of IB documents and actual e-documents.
// The function is intended to be used with library "Scheduled reporting".
//
// Parameters:
//  DocumentsIB - array(ref), array of references to infobase documents;
//  UUID - uniqueIdentifier, flag of uniqueness for the document selection form
//
Function GetMapIBDocumentsElectronicDocumentsKits(DocumentsIB, UUID) Export
	
	Map = New Map;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CASE
	|		WHEN Not EDAttachedFiles.ElectronicDocumentOwner = VALUE(Catalog.EDAttachedFiles.EmptyRef)
	|			THEN EDAttachedFiles.ElectronicDocumentOwner.Ref
	|		ELSE EDAttachedFiles.Ref
	|	END AS AttachedFile,
	|	CASE
	|		WHEN Not EDAttachedFiles.ElectronicDocumentOwner = VALUE(Catalog.EDAttachedFiles.EmptyRef)
	|			THEN EDAttachedFiles.ElectronicDocumentOwner.FileOwner
	|		ELSE EDAttachedFiles.FileOwner
	|	END AS IBDocument
	|FROM
	|	InformationRegister.EDStates AS EDStates
	|		LEFT JOIN Catalog.EDAttachedFiles AS EDAttachedFiles
	|		ON EDStates.ElectronicDocument = EDAttachedFiles.Ref
	|WHERE
	|	EDAttachedFiles.FileOwner IN(&FileOwner)
	|	AND EDStates.EDVersionState IN (&ExchangeCompleted)";
	Query.SetParameter("FileOwner", DocumentsIB);
	ExchangeCompleted = New Array;
	ExchangeCompleted.Add(Enums.EDVersionsStates.ExchangeCompleted);
	ExchangeCompleted.Add(Enums.EDVersionsStates.ExchangeCompletedWithCorrection);
	Query.SetParameter("ExchangeCompleted", ExchangeCompleted);
	
	Result = Query.Execute().Select();
	While Result.Next() Do
		
		FileArrayED = New Array;
		
		FileData = ElectronicDocumentsService.GetFileData(Result.AttachedFile,
			UUID);
			
		// Edit attachment file name for CORESF - remove after dimension check in the name 150.
		If Result.AttachedFile.EDKind = Enums.EDKinds.CorrectiveInvoiceNote Then
			StringAtID = Result.AttachedFile.UniqueId;
			Description = FileData.Description;
			UIDPosition = Find(Description, "_" + Left(StringAtID, 35));
			If UIDPosition > 0 Then
				FileData.Description = Left(Description, UIDPosition) + StringAtID;
				FileData.FileName = FileData.Description + "." + FileData.Extension;
			EndIf;
		EndIf;
		
		EDParametersStructure = New Structure;
		EDParametersStructure.Insert("FileType", "ExportFile");
		EDParametersStructure.Insert("FileName", FileData.FileName);
		EDParametersStructure.Insert("TemporaryStorageAddress", FileData.FileBinaryDataRef);
		
		FileArrayED.Add(EDParametersStructure);
		
		SignsStructuresArray = ElectronicDocumentsService.GetAllSignatures(Result.AttachedFile,
			UUID);
		
		If TypeOf(SignsStructuresArray) = Type("Array") AND SignsStructuresArray.Count() > 0 Then
			
			For Each SignStructure IN SignsStructuresArray Do
				SignatureFileName = SignStructure.SignatureFileName;
				If Not ValueIsFilled(SignatureFileName) Then
					SignatureFileName = FileData.Description + ".p7s";
				EndIf;
				
				EDParametersStructure = New Structure;
				EDParametersStructure.Insert("FileType", "DS");
				EDParametersStructure.Insert("FileName", SignatureFileName);
				EDParametersStructure.Insert("TemporaryStorageAddress", SignStructure.SignatureAddress);
				
				FileArrayED.Add(EDParametersStructure);
			EndDo;
		EndIf;
		
		Map.Insert(Result.IBDocument, FileArrayED);
	EndDo;
	
	Return Map;
	
EndFunction

// Generates ED info that will be shown in a
// unified list of documents that are submitted to FTS on demand. E-documents exchanges must be
// complete, they should not be marked for deletion and to be of the following ED kinds:
// CustomerInvoiceNote
// CorrectiveInvoiceNote
// TORG12Seller
// ActPerformer
//
// Parameters:
//
//    EDProperties - Map:
//       Key     - CatalogRef.EDAttachedFiles.
//       Value - structure, Structure fields:
//          ED              - CatalogRef.EDAttachedFiles
//          EDOwner      - DocumentRef - ref to metadata object - FTSDocumentKind
//          file owner - String, an e-document kind
//                       to be converted into a string presentation of a particular format. Possible values:
//                       "AcceptanceCertificate"
//                       "CustomerInvoiceNote"
//                       "CorrectiveInvoiceNote"
//                       "GoodsConsignmentTORG12"
//    EDArray - Array, array of references to the electronic documents.
//             If the array is filled out, it is required to fill in ED properties from the array.
//             If the array is empty, it is required to
//             fill in all ED properties that correspond to the properties specified above.
//
Procedure GetEDPropertiesForDocumentsSubmittedToMagazineBroadcastsOnFTS(EDProperties, EDKindsArray) Export
	
	Query = New Query;
	QueryText = "SELECT ALLOWED
	               |	ISNULL(EDAttachedFilesOwners.Ref, EDAttachedFiles.Ref) AS ED,
	               |	ISNULL(EDAttachedFilesOwners.FileOwner, EDAttachedFiles.FileOwner) AS EDOwner,
	               |	CASE
	               |		WHEN ISNULL(EDAttachedFilesOwners.EDKind, EDAttachedFiles.EDKind) = VALUE(Enum.EDKinds.ActPerformer)
	               |			THEN ""AcceptanceCertificate""
	               |		WHEN ISNULL(EDAttachedFilesOwners.EDKind, EDAttachedFiles.EDKind) = VALUE(Enum.EDKinds.CorrectiveInvoiceNote)
	               |			THEN ""CorrectiveInvoiceNote""
	               |		WHEN ISNULL(EDAttachedFilesOwners.EDKind, EDAttachedFiles.EDKind) = VALUE(Enum.EDKinds.CustomerInvoiceNote)
	               |			THEN ""CustomerInvoiceNote""
	               |		WHEN ISNULL(EDAttachedFilesOwners.EDKind, EDAttachedFiles.EDKind) = VALUE(Enum.EDKinds.TORG12Seller)
	               |			THEN ""TORG12DeliveryNote""
	               |		ELSE """"
	               |	END AS FTSDocumentKind
	               |FROM
	               |	InformationRegister.EDStates AS EDStates
	               |		INNER JOIN Catalog.EDAttachedFiles AS EDAttachedFiles
	               |			LEFT JOIN Catalog.EDAttachedFiles AS EDAttachedFilesOwners
	               |			ON EDAttachedFiles.ElectronicDocumentOwner = EDAttachedFilesOwners.Ref
	               |		ON EDStates.ElectronicDocument = EDAttachedFiles.Ref
	               |WHERE
	               |	EDStates.EDVersionState = VALUE(Enum.EDVersionsStates.ExchangeCompleted)
	               |	AND (ISNULL(EDAttachedFilesOwners.EDKind, EDAttachedFiles.EDKind) IN (&EDKinds))
	               |	AND ISNULL(EDAttachedFilesOwners.DigitallySigned, EDAttachedFiles.DigitallySigned)
	               |	AND Not ISNULL(EDAttachedFilesOwners.DeletionMark, EDAttachedFiles.DeletionMark)";
	
	If ValueIsFilled(EDKindsArray) Then
		QueryText = QueryText + "
			| And ISNULL(EDAttachedFilesOwners.Refs, EDAttachedFiles.Refs) IN (&EDKindsArray)";
		Query.SetParameter("EDKindsArray", EDKindsArray);
	EndIf;
	
	EDKindsArray = New Array;
	EDKindsArray.Add(Enums.EDKinds.CustomerInvoiceNote);
	EDKindsArray.Add(Enums.EDKinds.ActPerformer);
	EDKindsArray.Add(Enums.EDKinds.TORG12Seller);
	EDKindsArray.Add(Enums.EDKinds.CorrectiveInvoiceNote);
	Query.SetParameter("EDKinds", EDKindsArray);
	Query.Text = QueryText;
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		PropertyStructure = New Structure;
		PropertyStructure.Insert("FTSDocumentKind", Selection.FTSDocumentKind);
		PropertyStructure.Insert("EDOwner", Selection.EDOwner);
		PropertyStructure.Insert("ED", Selection.ED);
		
		EDProperties.Insert(Selection.ED, PropertyStructure);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Errors processor

// Handles exceptions of electronic documents.
//
// Parameters:
// OperationKind - String - kind of operations where the exception occurred.
// DetailErrorText - String - error description.
// MessageText - String - error text.
//
Procedure ProcessExceptionByEDOnServer(OperationKind, DetailErrorText, MessageText = "", EventCode = 2) Export
	
	ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(OperationKind,
		DetailErrorText, MessageText, EventCode);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Object filling

// The procedure adds data from DataStructure to the values table "AddDataTable".
// Parameters:
//  LegallyMeaningful - Boolean - if True - then current data shall be put in default ED if possible.
//  LineNumber - String/Undefined - if it is filled, it shows the current data belonging to the tabular section.
//    The parameter value shows to which row of tabular section the data belongs. It may be of "1" or "1.1" kind.
//    If a value is of kind "1.1", then the current data refers to the first row
// of the tabular section that is located in the first row of the owner table. (for more information, see HDTO
//    scheme "PerformerActTitle", list "WorksInventory", nested list "Work").
//
Procedure AddDataToAdditDataTree(ParametersStructure, DataStructure, OwnerItemName, LegallyMeaningful = False, LineNumber = Undefined) Export
	
	AdditDataTree = ParametersStructure.AdditDataTree;
	If TypeOf(AdditDataTree) = Type("ValueTree") Then
		TSItem = (LineNumber <> Undefined);
		FilterSt = New Structure("AttributeValue, CWT", OwnerItemName, TSItem);
		TreeRows = AdditDataTree.Rows.FindRows(FilterSt, True);
		
		If TreeRows.Count() = 0 Then
			TreeRow = AdditDataTree.Rows.Add();
			TreeRow.AttributeName = ?(TSItem, "List", "Set");
			TreeRow.AttributeValue = OwnerItemName;
			TreeRow.CWT = TSItem;
		Else
			TreeRow = TreeRows[0];
		EndIf;
		
		If TSItem Then
			FilterSt = New Structure("AttributeName, AttributeValue", "NPP", String(LineNumber));
			ListRows = TreeRow.Rows.FindRows(FilterSt);
			If ListRows.Count() = 0 Then
				TreeRow = TreeRow.Rows.Add();
				TreeRow.AttributeName = "NPP";
				TreeRow.CWT = TSItem;
				TreeRow.AttributeValue = String(LineNumber);
			Else
				TreeRow = ListRows[0];
			EndIf;
		EndIf;
		
		AvailableCharacters = 0;
		If LegallyMeaningful Then
			If LineNumber = Undefined Then
				AvailableCharacters = ParametersStructure.AllowedLengthOfExtraDataCaps;
			Else
				AvailableCharacters = ParametersStructure.StringAdditDataAllowedLength;
			EndIf;
		EndIf;
		
		AppendDataRecursively(TreeRow,
								 DataStructure,
								 AvailableCharacters,
								 LegallyMeaningful,
								 TSItem,
								 LineNumber);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Object filling

// Gets a bank statement in a text format and also an array of references to company bank accounts in the statement
//
// ED
//  parameters - CatalogRef.EDAttachedFiles - contains the
//  file of the StorageRef bank statement - String - contains a reference to
//  the storage of test data AccountsArray - Array - contains references to the company bank accounts
//
Procedure GetBankStatementDataTextFormat(ED, LinksToRepository, AccountsArray) Export

	AccountsArray = New Array;
	AdditInformationAboutED = ElectronicDocumentsService.GetFileData(ED);
	If AdditInformationAboutED.Property("FileBinaryDataRef")
			AND ValueIsFilled(AdditInformationAboutED.FileBinaryDataRef) Then
		
		EDData = GetFromTempStorage(AdditInformationAboutED.FileBinaryDataRef);

		FileName = GetTempFileName("xml");
				
		If FileName = Undefined Then
			ErrorText = NStr("en = 'Failed to read electronic document. Verify the work directory setting'");
			CommonUseClientServer.MessageToUser(ErrorText);
			Return;
		EndIf;
		
		EDData.Write(FileName);
		EDAttributes = CommonUse.ObjectAttributesValues(ED, "EDForward, Company");
		DataStructure = ElectronicDocumentsInternal.GenerateParseTree(FileName, EDAttributes.EDDirection);
		
		DeleteFiles(FileName);
		If DataStructure = Undefined Then
			Return;
		EndIf;
		
		ParseTree = DataStructure.ParseTree;
		ObjectString = DataStructure.ObjectString;
			
		Text = New TextDocument();

		Text.AddLine("1CClientBankExchange");
		Text.AddLine("FormatVersion=1.02");
		Text.AddLine("Encoding=Windows");
		AddNotBlankParameter(ParseTree, ObjectString, Text, "Sender");
		Recipient = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					ObjectString,
																					"Recipient");
		Text.AddLine("Recipient=" + Recipient);
		CreationDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					ObjectString,
																					"CreationDate");
		If ValueIsFilled(CreationDate) Then
			Text.AddLine("CreationDate=" + Format(CreationDate, "DF=dd.MM.yyyy"));
		EndIf;
		CreationTime = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					ObjectString,
																					"CreationTime");
		If ValueIsFilled(CreationTime) Then
			Text.AddLine("CreationTime=" + Format(CreationTime, "DF=dd.MM.yyyy"));
		EndIf;
		
		FilterStructure = New Structure("Attribute", "BankAccountsOfTheCompany");
		BankAccountsOfTheCompany = ObjectString.Rows.FindRows(FilterStructure);
		StartDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					ObjectString,
																					"StartDate");
		EndDate  = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					ObjectString,
																					"EndDate");
																					
		Text.AddLine("StartDate=" + Format(StartDate, "DF=dd.MM.yyyy"));
		Text.AddLine("EndDate="  + Format(EndDate,  "DF=dd.MM.yyyy"));
		
		For Each StringBankAccount IN BankAccountsOfTheCompany Do
			AccountNo = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					StringBankAccount,
																					"BankAcc.SettlemAccount");
			Text.AddLine("BankAcc=" + AccountNo);
		EndDo;
		
		For Each StringBankAccount IN BankAccountsOfTheCompany Do
			Text.AddLine("SECTIONBANKACC");
			Text.AddLine("StartDate=" + Format(StartDate, "DF=dd.MM.yyyy"));
			Text.AddLine("EndDate="  + Format(EndDate,  "DF=dd.MM.yyyy"));
			AccountNo = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					StringBankAccount,
																					"BankAcc.SettlemAccount");
			AdditionalAttributes = New Structure("Owner", EDAttributes.Company);
			CompanyAccount = ElectronicDocumentsOverridable.FindRefToObject(
						"BankAccountsOfTheCompany", AccountNo, AdditionalAttributes);
			AccountsArray.Add(CompanyAccount);
			Text.AddLine("BankAcc=" + AccountNo);
			
			OpeningBalance = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					StringBankAccount,
																					"BankAccount.OpeningBalance");
			If ValueIsFilled(OpeningBalance) Then
				Text.AddLine("OpeningBalance=" + Format(OpeningBalance, "NDS=.; NG="));
			EndIf;
			DebitedTotal = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					StringBankAccount,
																					"BankAccount.TotalReceived");
			If ValueIsFilled(DebitedTotal) Then
				Text.AddLine("DebitedTotal=" + Format(DebitedTotal, "NDS=.; NG="));
			EndIf;
			CreditedTotal = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					StringBankAccount,
																					"BankAccount.TotalDebited");
			If ValueIsFilled(CreditedTotal) Then
				Text.AddLine("CreditedTotal=" + Format(CreditedTotal, "NDS=.; NG="));
			EndIf;
			ClosingBalance = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					StringBankAccount,
																					"BankAccount.ClosingBalance");
			If ValueIsFilled(ClosingBalance) Then
				Text.AddLine("ClosingBalance=" + Format(ClosingBalance, "NDS=.; NG="));
			EndIf;
			
			Text.AddLine("ENDBANKACC");
			
		EndDo;
			
		TSRows = ObjectString.Rows.FindRows(New Structure("Attribute", "TSRow"));
		For Each TSRow IN TSRows Do
			SectionDocument = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					TSRow,
																					"SectionDocument");
			Text.AddLine("SectionDocument=" + SectionDocument);
			Number = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					TSRow,
																					"Number");
			Text.AddLine("Number=" + Number);
			Date = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					TSRow,
																					"Date");
			Text.AddLine("Date=" + Format(Date, "DF=dd.MM.yyyy"));
			Amount = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					TSRow,
																					"Amount");
			Text.AddLine("Amount=" + Format(Amount, "NDS=.; NG="));
			StatementDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					TSRow,
																					"StatementDate");
			If ValueIsFilled(StatementDate) Then
				Text.AddLine("StatementDate=" + Format(StatementDate, "DF=dd.MM.yyyy"));
			EndIf;
			StatementTime = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					TSRow,
																					"StatementTime");
			If ValueIsFilled(StatementTime) Then
				Text.AddLine("StatementTime=" + Format(StatementTime, "DLF=T"));
			EndIf;
			AddNotBlankParameter(ParseTree, TSRow, Text, "StatementContent");
			
			PayerAccount = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree, TSRow, "PayerAccount");
			Text.AddLine("PayerAccount=" + PayerAccount);
			DateCredited = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					TSRow,
																					"DateCredited");
			If ValueIsFilled(DateCredited) Then
				Text.AddLine("DateCredited=" + Format(DateCredited, "DF=dd.MM.yyyy"));
			EndIf;
			AddNotBlankParameter(ParseTree, TSRow, Text, "Payer", "PayerDescription");
			PayerTIN = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree, TSRow, "PayerTIN");
			Text.AddLine("PayerTIN=" + PayerTIN);
			AddNotBlankParameter(ParseTree, TSRow, Text, "PayerKPP");
			
			PayerIndirectPayments = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree, TSRow, "PayerIndirectPayments");

			If PayerIndirectPayments Then
				AddNotBlankParameter(ParseTree, TSRow, Text, "Payer1", "PayerNameIndirectSettlements");
				AddNotBlankParameter(ParseTree, TSRow, Text, "Payer2", "PayerAccountIndirectSettlements");
				AddNotBlankParameter(ParseTree, TSRow, Text, "Payer3", "PayerBankNameIndirectSettlements");
				AddNotBlankParameter(ParseTree, TSRow, Text, "Payer4", "PayerBankCityIndirectSettlements");
			EndIf;
			
			AddNotBlankParameter(ParseTree, TSRow, Text, "PayerBankAcc", "PayerBankCorrAccount");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PayerBank1", "PayerBankName");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PayerBank2", "PayerBankCity");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PayerBIC", "PayerBankBIC");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PayerBalancedAccount");
			PayeeAccount = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree, TSRow, "PayeeAccount");
			Text.AddLine("PayeeAccount=" + PayeeAccount);
			Date_Received = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					TSRow,
																					"Date_Received");
			If ValueIsFilled(Date_Received) Then
				Text.AddLine("Date_Received=" + Format(Date_Received, "DF=dd.MM.yyyy"));
			EndIf;
			AddNotBlankParameter(ParseTree, TSRow, Text, "Recipient", "RecipientDescription");
			PayeeTIN = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																					ParseTree,
																					TSRow,
																					"PayeeTIN");
			Text.AddLine("PayeeTIN=" + PayeeTIN);
			AddNotBlankParameter(ParseTree, TSRow, Text, "PayeeKPP");
			
			RecipientIndirectSettlements = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree, TSRow, "RecipientIndirectSettlements");
			If RecipientIndirectSettlements Then
				AddNotBlankParameter(ParseTree, TSRow, Text, "Payee1",  "RecipientNameIndirectSettlements");
				AddNotBlankParameter(ParseTree, TSRow, Text, "Payee2", "RecipientAccountIndirectSettlements");
				AddNotBlankParameter(ParseTree, TSRow, Text, "Payee3", "RecipientBankNameIndirectSettlements");
				AddNotBlankParameter(ParseTree, TSRow, Text, "Payee4", "RecipientBankCityIndirectSettlements");
			EndIf;
			AddNotBlankParameter(ParseTree, TSRow, Text, "PayeeBankAcc", "RecipientBankCorrAccount");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PayeeBank1", "RecipientBankName");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PayeeBank2", "PayeeBankCity");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PayeeBIK", "PayeeBankBIC");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PayeeBalancedAccount");
			
			AddNotBlankParameter(ParseTree, TSRow, Text, "PaymentKind");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PayKind");
			AddNotBlankParameter(ParseTree, TSRow, Text, "Code");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PaymentDestination");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PaymentDestination1");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PaymentDestination2");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PaymentDestination3");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PaymentDestination4");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PaymentDestination5");
			AddNotBlankParameter(ParseTree, TSRow, Text, "PaymentDestination6");
				
			IsPaymentsToBudget = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																						ParseTree,
																						TSRow,
																						"IsPaymentsToBudget");
			If IsPaymentsToBudget = True Then
				AddNotBlankParameter(ParseTree, TSRow, Text, "AuthorStatus");
				AddNotBlankParameter(ParseTree, TSRow, Text, "KBKIndicator");
				AddNotBlankParameter(ParseTree, TSRow, Text, "OKATO", "OKTMO");
				AddNotBlankParameter(ParseTree, TSRow, Text, "BasisIndicator");
				AddNotBlankParameter(ParseTree, TSRow, Text, "PeriodIndicator");
				AddNotBlankParameter(ParseTree, TSRow, Text, "NumberIndicator");
				AddNotBlankParameter(ParseTree, TSRow, Text, "DateIndicator");
				AddNotBlankParameter(ParseTree, TSRow, Text, "TypeIndicator");
			EndIf;
				
			AddNotBlankParameter(ParseTree, TSRow, Text, "OrderOfPriority");
			AcceptanceTerm = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																						ParseTree,
																						TSRow,
																						"AcceptanceTerm");
			If ValueIsFilled(AcceptanceTerm) Then
				Text.AddLine("AcceptanceTerm=" + Format(AcceptanceTerm,"NFD=0; NG="));
			EndIf;
			AddNotBlankParameter(ParseTree, TSRow, Text, "LetterOfCreditType");
			PaymentDueDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																						ParseTree,
																						TSRow,
																						"PaymentDueDate");
			If ValueIsFilled(PaymentDueDate) Then
				Text.AddLine("PaymentDueDate=" + Format(PaymentDueDate, "DF=dd.MM.yyyy"));
			EndIf;
			PaymentCondition1 = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																						ParseTree,
																						TSRow,
																						"PaymentCondition");
			If ValueIsFilled(PaymentCondition1) Then
				Text.AddLine("PaymentCondition1="+ PaymentCondition1);
			EndIf;
			AddNotBlankParameter(ParseTree, TSRow, Text, "PaymentByRepr");
			AddNotBlankParameter(ParseTree, TSRow, Text, "AdditionalConditions");
			AddNotBlankParameter(ParseTree, TSRow, Text, "NumberVendorAccount");
			DocSendingDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																						ParseTree,
																						TSRow,
																						"DocSendingDate");
			If ValueIsFilled(DocSendingDate) Then
				Text.AddLine("DocSendingDate="+ Format(DocSendingDate, "DF=dd.MM.yyyy"));
			EndIf;
			Text.AddLine("EndDocument");
		EndDo;
	
		Text.AddLine("EndFile");
		
		StatementText = Text.GetText();
		
		FileName = GetTempFileName();
		TextDocument = New TextDocument();
		TextDocument.SetText(StatementText);
		TextDocument.Write(FileName, TextEncoding.ANSI);
		FileData = New BinaryData(FileName);
		LinksToRepository = PutToTempStorage(FileData, New UUID());
		DeleteFiles(FileName);
		
	EndIf;
	
EndProcedure

// It receives the bank statement in the value tree form
//
// ED
//  parameters - CatalogRef.EDAttachedFiles - contains file
//  statement bank StatementData - ValueTree - contains the statement data tree
//
Procedure GetBankStatementDataValueTree(ED, StatementData) Export
	
	AdditInformationAboutED = ElectronicDocumentsService.GetFileData(ED);
	If AdditInformationAboutED.Property("FileBinaryDataRef")
			AND ValueIsFilled(AdditInformationAboutED.FileBinaryDataRef) Then
		
		EDData = GetFromTempStorage(AdditInformationAboutED.FileBinaryDataRef);

		FileName = GetTempFileName("xml");
				
		If FileName = Undefined Then
			ErrorText = NStr("en = 'Failed to read electronic document. Verify the work directory setting'");
			CommonUseClientServer.MessageToUser(ErrorText);
			Return;
		EndIf;
		
		EDData.Write(FileName);
		
		DataStructure = ElectronicDocumentsInternal.GenerateParseTree(FileName, ED.EDDirection);
		
		DeleteFiles(FileName);
		If DataStructure = Undefined Then
			Return;
		EndIf;
		
		StatementData = DataStructure.ParseTree;
		
	EndIf;
	
EndProcedure

// Receives a parse tree that contains the statement data
//
// Parameters:
// TextForParsing - String - statement text.
//
// Returns:
//  ValueTree - DS statement.
//
Function ParsingTreeBankStatements(TextForParsing) Export
	
	Return ElectronicDocumentsInternal.ParsingTreeBankStatements(TextForParsing);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

 // Procedure used to create an additional data tree.
// Data from the received structure, recursively adds to the additional data tree.
//
// Parameters:
//  RowTreaExtraData - Value tree string - tree string where the data are added.
//  DataStructure - Structure - structure with the data added to the tree. The structure items can be
//    the following: data of a simple type, values array, nested data structures.
//  AvailableCharacters - Number - number of characters that can be used to place data in the main ED file.
//  LegallyMeaningful - Boolean - True - mark data that should be moved from the additional
//    data tree to the main ED file afterwards. False - the data will be forwarded to the additional data file.
//  TSItem - Boolean - data belongs to a tabular section row of IB document.
//  LineNumber - String - String number of the IB document tabular section.
//
Procedure AppendDataRecursively(RowTreaExtraData,
								   DataStructure,
								   AvailableCharacters,
								   LegallyMeaningful,
								   TSItem,
								   LineNumber)
	
	For Each Item IN DataStructure Do
		If ValueIsFilled(Item.Value) Then
			If TypeOf(Item.Value) = Type("Structure") Then
				FilterSt = New Structure("AttributeValue, CWT", Item.Key, TSItem);
				TreeRows = RowTreaExtraData.Rows.FindRows(FilterSt, True);
				If TreeRows.Count() = 0 Then
					TreeRow = RowTreaExtraData.Rows.Add();
					TreeRow.AttributeName = "Set";
					
					TreeRow.AttributeValue = Item.Key;
					TreeRow.CWT = TSItem;
					
					
					
				Else
					TreeRow = TreeRows[0];
				EndIf;
				AppendDataRecursively(TreeRow, Item.Value, AvailableCharacters, LegallyMeaningful, TSItem,
					LineNumber);
			ElsIf TypeOf(Item.Value) = Type("ValueTable") AND Item.Value.Count() > 0 Then
				FilterSt = New Structure("AttributeValue, CWT", Item.Key, True);
				TreeRows = RowTreaExtraData.Rows.FindRows(FilterSt, True);
				If TreeRows.Count() = 0 Then
					TreeRow = RowTreaExtraData.Rows.Add();
					TreeRow.AttributeName = "List";
					TreeRow.AttributeValue = Item.Key;
					TreeRow.CWT = True;
					
					LocationIsPossible = PerhapsAccommodationMainlyFile("List", Item.Key, AvailableCharacters);
					If LegallyMeaningful AND Not LocationIsPossible Then
						LegallyMeaningful = False;
					EndIf;
					TreeRow.LegallyMeaningful = LegallyMeaningful;

					LocationIsPossible = PerhapsAccommodationMainlyFile(Item.Key, "", AvailableCharacters);
					If LegallyMeaningful AND Not LocationIsPossible Then
						LegallyMeaningful = False;
					EndIf;
					TreeRow.LegallyMeaningful = LegallyMeaningful ;
					
				Else
					TreeRow = TreeRows[0];
				EndIf;
				VT = Item.Value;
				FieldsStructureOfVT = "";
				For Each ColumnOfTV IN VT.Columns Do
					FieldsStructureOfVT = FieldsStructureOfVT + ?(ValueIsFilled(FieldsStructureOfVT), ", ", "") + ColumnOfTV.Name;
				EndDo;
				LegalTo = LegallyMeaningful;
				For Each VTRow IN VT Do
					NPPTreeRow = TreeRow.Rows.Add();
					
					NPPTreeRow.AttributeName = "NPP";
					NPPTreeRow.CWT = True;
					NPPTreeRow.AttributeValue = String(VT.IndexOf(VTRow));
					
					LocationIsPossible = PerhapsAccommodationMainlyFile("NPP", "", AvailableCharacters);
					If LegallyMeaningful AND Not LocationIsPossible Then
						LegallyMeaningful = False;
					EndIf;
					NPPTreeRow.LegallyMeaningful = LegallyMeaningful;
					
					DataStructureOfVT = New Structure(FieldsStructureOfVT);
					FillPropertyValues(DataStructureOfVT, VTRow);
					AppendDataRecursively(NPPTreeRow, DataStructureOfVT, AvailableCharacters, LegallyMeaningful,
						TSItem, VT.IndexOf(VTRow));
					
				EndDo;
				If Not LegalTo = LegallyMeaningful Then
					TreeRow.LegallyMeaningful = LegallyMeaningful;
					UpdateTreeStrings(TreeRow,LegallyMeaningful);
				EndIf;
				
			Else
				NewRow = RowTreaExtraData.Rows.Add();
				PerhapsAccommodationMainlyFile = PerhapsAccommodationMainlyFile(Item.Key,
																					Item.Value,
																					AvailableCharacters);
				If LegallyMeaningful AND Not PerhapsAccommodationMainlyFile Then
					LegallyMeaningful = False;
				EndIf;
				NewRow.LegallyMeaningful = LegallyMeaningful;
				If TypeOf(Item.Value) = Type("Array") Then
					NewRow.AttributeName = "Array";
					NewRow.AttributeValue = Item.Key;
					NewRow.CWT = TSItem;
					For Each Value IN Item.Value Do
						StringZn = NewRow.Rows.Add();
						StringZn.AttributeName = "Item" + Item.Value.Find(Value);
						StringZn.CWT = TSItem;
						StringZn.LegallyMeaningful = NewRow.LegallyMeaningful;
						If TypeOf(Value) = Type("Structure") Then
							StringZn.AttributeValue = "Structure";
							AppendDataRecursively(StringZn, Value, AvailableCharacters, LegallyMeaningful, TSItem, LineNumber);
						Else
							
							StringZn.AttributeValue = Value;
						EndIf
					EndDo;
				Else
					NewRow.AttributeName = Item.Key;
					NewRow.AttributeValue = Item.Value;
					NewRow.CWT = TSItem;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Procedure UpdateTreeStrings(TreeRow, LegallyMeaningful);
	
	For Each CurRow IN TreeRow.Rows Do
		
		CurRow.LegallyMeaningful = LegallyMeaningful;
		If CurRow.Rows.Count()> 0 Then
			UpdateTreeStrings(CurRow, LegallyMeaningful);
		EndIf;
		
	EndDo;
	
EndProcedure


// The function checks the following: a length of the string received once the structure
// data is converted (considering service characters) shall not exceed a number of allowed chracters.
//
// Parameters:
//  DataStructure - Structure - filled structure.
//  Key - String - key of the item to be added.
//  Value - Structure, primitive type or array (array items are of the primitive type) - value of the item to be added.
//  AvailableCharacters - Number - number of available characters of the resulting string.
//
// Returns:
//  Boolean - True - item is added to the structure, False - the item is not added.
//
Function PerhapsAccommodationMainlyFile(Key, Value, AvailableCharacters)
	
	PlacementIsPossible = False;
	
	ServiceCharacters = 0;
	LengthStrValues = 0;
	
	// 41 and 31 numbers represent the number of service characters and are calculated as follows:
	// 1) if the string with the subordinate strings is added to ValueTree, this xml string will
	// be displayed as an item having attached (subordinate) items, so the number of
	// service characters = 41 (without the length of the name and the attribute value) and calculation is based on the formula:
	// StrLen("<Attribute Name="""" Value=""""></Attribute>") + 1;
	// 2) if the string without subordinate strings is added to ValueTree, the number of
	// service characters = 31 (without the length of the name and the attribute value) and the calculation is based on the formula:
	// StrLen("<Attribute Name="""" Value=""""/>") + 1;
	
	If TypeOf(Value) = Type("Array") Then
		For Each Item IN Value Do
			ServiceCharacters = ServiceCharacters + StrLen("Item" + Value.Find(Item)) + StrLen(Item) + 31;
		EndDo;
		
		ServiceCharacters = ServiceCharacters + StrLen("Array") + StrLen(Key) + 41;
	ElsIf TypeOf(Value) = Type("Structure") Then
		For Each Item IN Value Do
			PlacementIsPossible = PerhapsAccommodationMainlyFile(Item.Key, Item.Value, AvailableCharacters);
			If Not PlacementIsPossible Then
				Return False;
			EndIf;
		EndDo;
		
		ServiceCharacters = StrLen("Set") + StrLen(Key) + 41;
	Else // simple type.
		ServiceCharacters = StrLen(Key) + StrLen(Value) + 31;
	EndIf;
	
	If AvailableCharacters >= ServiceCharacters Then
		AvailableCharacters = AvailableCharacters - ServiceCharacters;
		PlacementIsPossible = True;
	EndIf;
	
	Return PlacementIsPossible;
	
EndFunction

Procedure AddNotBlankParameter(ParseTree, ObjectString, Text, ParameterName, TreeAttributeName = "")
	
	If TreeAttributeName = "" Then
		TreeAttributeName = ParameterName;
	EndIf;
	
	ParameterValue = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
													ParseTree, ObjectString, TreeAttributeName);
	If ValueIsFilled(ParameterValue) Then
		ParameterValue = StrReplace(ParameterValue, Chars.LF, "");
		ParameterValue = StrReplace(ParameterValue, Chars.CR, "");
		Text.AddLine(ParameterName + "=" + ParameterValue);
	EndIf;

EndProcedure
