////////////////////////////////////////////////////////////////////////////////
// ElectronicDocumentsServiceServerCall: mechanism of electronic documents exchange.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceApplicationInterface

////////////////////////////////////////////////////////////////////////////////
// Work with the electronic document versions

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
	
	ElectronicDocumentsService.ChangeByRefAttachedFile(AddedFile,
		EDStructure, CheckRequiredAttributes);
	
EndProcedure

// Receives match of owners to the current EDs
//
// Parameters:
//  RefsArrayToOwners - array of references to e-document owners which data it is required to get.
//
Function GetCorrespondenceOwnersAndED(RefsArrayToOwners = Undefined, RefsArrayOnED = Undefined) Export
	
	SetPrivilegedMode(True);
	
	AccordanceOfEDIOwners = New Map;
	
	Query = New Query;
	If Not RefsArrayToOwners = Undefined Then
		Query.Text =
		"SELECT
		|	EDStates.ObjectReference AS EDOwner,
		|	EDStates.ElectronicDocument AS LinkToED
		|FROM
		|	InformationRegister.EDStates AS EDStates
		|WHERE
		|	EDStates.ObjectReference IN(&RefsArrayToOwners)";
		Query.SetParameter("RefsArrayToOwners", RefsArrayToOwners);
	ElsIf Not RefsArrayOnED = Undefined Then
		Query.Text =
		"SELECT
		|	EDAttachedFiles.Ref AS LinkToED,
		|	EDAttachedFiles.FileOwner AS EDOwner
		|FROM
		|	Catalog.EDAttachedFiles AS EDAttachedFiles
		|WHERE
		|	EDAttachedFiles.Ref IN(&EDKindsArray)";
		Query.SetParameter("EDKindsArray", RefsArrayOnED);
	Else
		Return AccordanceOfEDIOwners;
	EndIf;
	
	Result = Query.Execute().Select();
	
	AccordanceOfEDIOwners = New Map;
	While Result.Next() Do
		AccordanceOfEDIOwners.Insert(Result.EDOwner, Result.LinkToED);
	EndDo;
	
	Return AccordanceOfEDIOwners;
	
EndFunction

// Changes the electronic document version state.
//
// Parameters:
//  ElectronicDocument - CatalogRef.EDAttachedFiles, Array - electronic documents version of which should be updated.
//  ForcedVersionStateChange - Boolean, shows that version is changed despite conditions.
//
Procedure RefreshEDVersion(ElectronicDocument, ForcedVersionStateChange = False, PackageFormatVersion = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(ElectronicDocument) = Type("Array") Then
		For Each ArrayElement IN ElectronicDocument Do
			RefreshEDVersion(ArrayElement);
		EndDo;
	ElsIf Not ThisIsServiceDocument(ElectronicDocument) Then
		RecordSet = InformationRegisters.EDStates.CreateRecordSet();
		RecordSet.Filter.ObjectReference.Set(ElectronicDocument.FileOwner);
		RecordSet.Read();
		
		If RecordSet.Count() <> 0 Then
			NewSetRecord = RecordSet.Get(0);
			
			If ElectronicDocument = NewSetRecord.ElectronicDocument
				
				OR (ElectronicDocument.EDKind = Enums.EDKinds.TORG12Customer
				AND NewSetRecord.ElectronicDocument.EDKind = Enums.EDKinds.TORG12Seller)
				
				OR (ElectronicDocument.EDKind = Enums.EDKinds.ActCustomer
				AND NewSetRecord.ElectronicDocument.EDKind = Enums.EDKinds.ActPerformer)
				
				OR (ElectronicDocument.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient
				AND NewSetRecord.ElectronicDocument.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender)
				
				OR ((ElectronicDocument.EDDirection = Enums.EDDirections.Outgoing
				OR ElectronicDocument.EDDirection = Enums.EDDirections.Intercompany)
				AND NewSetRecord.ElectronicDocument.IsEmpty())
				
				OR (ElectronicDocument.EDDirection = Enums.EDDirections.Incoming //a new directory makes an old one irrelevant
						AND ElectronicDocument.EDKind = Enums.EDKinds.ProductsDirectory)
				
				OR ForcedVersionStateChange Then

				NewSetRecord.EDVersionState = ElectronicDocumentsService.DetermineVersionStateByEDStatus(ElectronicDocument, PackageFormatVersion);
				SummaryInfByStatusStructure = DetermineSummaryInformationByEDStatus(ElectronicDocument);
				If (NewSetRecord.EDVersionState = Enums.EDVersionsStates.ExchangeCompleted
						Or NewSetRecord.EDVersionState = Enums.EDVersionsStates.ExchangeCompletedWithCorrection)
					AND Not(SummaryInfByStatusStructure.FromOurSide = Enums.EDConsolidatedStates.AllExecuted
						AND SummaryInfByStatusStructure.FromOtherPartySide = Enums.EDConsolidatedStates.AllExecuted) Then
					NewSetRecord.EDVersionState = Enums.EDVersionsStates.ConfirmationExpected;
				EndIf;
				
				If NewSetRecord.EDVersionState = Enums.EDVersionsStates.ExchangeCompleted
					OR NewSetRecord.EDVersionState = Enums.EDVersionsStates.ExchangeCompletedWithCorrection
					OR NewSetRecord.EDVersionState = Enums.EDVersionsStates.PaymentExecuted Then
					SummaryInfByStatusStructure = New Structure;
					SummaryInfByStatusStructure.Insert("FromOurSide", Enums.EDConsolidatedStates.AllExecuted);
					SummaryInfByStatusStructure.Insert("FromOtherPartySide", Enums.EDConsolidatedStates.AllExecuted);
				EndIf;
				NewSetRecord.ActionsFromOurSide = SummaryInfByStatusStructure.FromOurSide;
				NewSetRecord.ActionsFromOtherPartySide = SummaryInfByStatusStructure.FromOtherPartySide;
				NewSetRecord.ElectronicDocument = ElectronicDocument;
				RecordSet.Write();
			ElsIf ElectronicDocument.EDKind = Enums.EDKinds.ResponseToOrder
				AND ElectronicDocument.EDDirection = Enums.EDDirections.Incoming
				AND Not NewSetRecord.ElectronicDocument = ElectronicDocument
				AND NewSetRecord.EDVersionState = Enums.EDVersionsStates.NotFormed Then
				
				NewSetRecord.EDVersionState = Enums.EDVersionsStates.DocumentClarificationNeeded;
				RecordSet.Write();
			ElsIf (ElectronicDocument.EDKind = Enums.EDKinds.TORG12Seller
				AND NewSetRecord.ElectronicDocument.EDKind = Enums.EDKinds.TORG12Customer
				OR ElectronicDocument.EDKind = Enums.EDKinds.ActPerformer
				AND NewSetRecord.ElectronicDocument.EDKind = Enums.EDKinds.ActCustomer
				OR ElectronicDocument.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender
				AND NewSetRecord.ElectronicDocument.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient) Then
				
				NewSetRecord.EDVersionState = ElectronicDocumentsService.DetermineVersionStateByEDStatus(ElectronicDocument);
				RecordSet.Write();
			EndIf;
		EndIf;
	ElsIf CommonUse.ObjectAttributeValue(ElectronicDocument, "EDKind") = Enums.EDKinds.NotificationAboutReception Then
		RecordSet = InformationRegisters.EDStates.CreateRecordSet();
		EDOwner = CommonUse.ObjectAttributeValue(ElectronicDocument, "FileOwner");
		RecordSet.Filter.ObjectReference.Set(EDOwner);
		RecordSet.Read();
		
		If RecordSet.Count() <> 0 Then
			NewSetRecord = RecordSet.Get(0);
			NewSetRecord.EDVersionState = ElectronicDocumentsService.DetermineVersionStateByEDStatus(
																						NewSetRecord.ElectronicDocument);
			SummaryInfByStatusStructure = DetermineSummaryInformationByEDStatus(NewSetRecord.ElectronicDocument);
			NewSetRecord.ActionsFromOurSide = SummaryInfByStatusStructure.FromOurSide;
			NewSetRecord.ActionsFromOtherPartySide = SummaryInfByStatusStructure.FromOtherPartySide;
			RecordSet.Write();
		EndIf
	
	EndIf;
	
EndProcedure

// Sets a new version of the electronic document for the owner.
//
// Parameters:
//  ObjectReference - Ref to the database document, electronic document version number of
//  which should be changed, AttachedFile - ref to electronic document that is relevant at the moment
//
Procedure SetEDNewVersion(ObjectReference, AttachedFile = Undefined, DeleteOldVersion = False) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.EDStates.CreateRecordSet();
	RecordSet.Filter.ObjectReference.Set(ObjectReference);
	RecordSet.Read();
	
	If RecordSet.Count() = 0 Then
		NewSetRecord = RecordSet.Add();
		NewSetRecord.ObjectReference      = ObjectReference;
		NewSetRecord.ElectronicDocument = ?(AttachedFile = Undefined,
		Catalogs.EDAttachedFiles.EmptyRef(), AttachedFile);
		NewSetRecord.EDVersionState = ElectronicDocumentsService.GetFirstEDVersionStateForOwner(
																					ObjectReference,
																					ValueIsFilled(AttachedFile));
		If NewSetRecord.EDVersionState = Enums.EDVersionsStates.OnApproval Then
			NewSetRecord.ActionsFromOurSide = Enums.EDConsolidatedStates.ActionsNeeded;
		EndIf;
	Else
		
		NewSetRecord = RecordSet.Get(0);
		If DeleteOldVersion Then
			DeleteOldEDVersion(NewSetRecord);
		EndIf;
		If ObjectReference.DeletionMark Then
			NewSetRecord.EDVersionState = Enums.EDVersionsStates.EmptyRef();
		Else
			NewSetRecord.EDVersionState = ElectronicDocumentsService.GetFirstEDVersionStateForOwner(
																					ObjectReference,
																					ValueIsFilled(AttachedFile));
		EndIf;
		If AttachedFile = Undefined OR AttachedFile.EDDirection = Enums.EDDirections.Outgoing
			OR AttachedFile.EDDirection = Enums.EDDirections.Intercompany Then
			NewSetRecord.ElectronicDocument = ?(AttachedFile = Undefined,
			Catalogs.EDAttachedFiles.EmptyRef(), AttachedFile);
		EndIf;
	EndIf;
	
	If NewSetRecord.EDVersionState = Enums.EDVersionsStates.NotFormed Then
		NewSetRecord.ActionsFromOurSide             = Enums.EDConsolidatedStates.ActionsNeeded;
		NewSetRecord.ActionsFromOtherPartySide = Enums.EDConsolidatedStates.NoActionsNeeded;
	ElsIf NewSetRecord.EDVersionState = Enums.EDVersionsStates.NotReceived Then
		NewSetRecord.ActionsFromOurSide             = Enums.EDConsolidatedStates.EmptyRef();
		NewSetRecord.ActionsFromOtherPartySide = Enums.EDConsolidatedStates.EmptyRef();
	EndIf;
	
	RecordSet.Write();
	
EndProcedure

// For internal use only
Procedure UpdateEDFSettingsConnectionStatuses(AccAgreementsAndStructuresOfCertificates) Export
	
	InvitationsTable = ElectronicDocumentsInternal.DataTableComponentExchangeParticipants(AccAgreementsAndStructuresOfCertificates);
	ElectronicDocumentsService.SaveInvitation(InvitationsTable);
	
EndProcedure

// For internal use only
Function EDExchangeMethodsArray(DirectExchangeFlag = True) Export
	
	MethodsOED = New Array;
	If DirectExchangeFlag Then
		MethodsOED.Add(Enums.EDExchangeMethods.ThroughDirectory);
		MethodsOED.Add(Enums.EDExchangeMethods.ThroughEMail);
		MethodsOED.Add(Enums.EDExchangeMethods.ThroughFTP);
	Else
		MethodsOED.Add(Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom);
	EndIf;
	
	Return MethodsOED;
	
EndFunction

// For internal use only
Function GetCurrentEDFConfiguration(RefToOwner, EDParameters = Undefined, EDKind = Undefined) Export
	
	Result = True;
	
	EDParameters = ElectronicDocumentsService.FillEDParametersBySource(RefToOwner);
	If Not ValueIsFilled(EDParameters.EDKind) Then
		
		If ValueIsFilled(EDKind) Then
			
			EDParameters.EDKind = EDKind;
		Else
			RefArray = New Array;
			RefArray.Add(RefToOwner);
			
			AccordanceOfEDIOwners = GetCorrespondenceOwnersAndED(RefArray);
			For Each CurItm IN RefArray Do
				
				LinkToED = AccordanceOfEDIOwners.Get(CurItm);
				If ValueIsFilled(LinkToED) Then
					EDParameters.EDKind = CommonUse.GetAttributeValue(LinkToED, "EDKind");
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	ExchangeParameters = ElectronicDocumentsService.DetermineEDExchangeSettings(EDParameters, Undefined);
	
	If Not ValueIsFilled(ExchangeParameters) Then
		Result = False;
		
		If ValueIsFilled(EDParameters.Counterparty) AND ValueIsFilled(EDParameters.Company) Then
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	EDUsageAgreements.Ref
			|FROM
			|	Catalog.EDUsageAgreements AS EDUsageAgreements
			|WHERE
			|	EDUsageAgreements.Counterparty = &Counterparty
			|	AND EDUsageAgreements.CounterpartyContract = &CounterpartyContract
			|	AND EDUsageAgreements.Company = &Company
			|	AND Not EDUsageAgreements.DeletionMark";
			Query.SetParameter("Counterparty",         EDParameters.Counterparty);
			Query.SetParameter("CounterpartyContract", EDParameters.CounterpartyContract);
			Query.SetParameter("Company",        EDParameters.Company);
			
			// Receive EDF settings unconditionally
			SetPrivilegedMode(True);
			
			Selection = Query.Execute().Select();
			If Not Selection.Next() Then
				Query = New Query;
				Query.Text =
				"SELECT
				|	EDUsageAgreements.Ref
				|FROM
				|	Catalog.EDUsageAgreements AS EDUsageAgreements
				|WHERE
				|	EDUsageAgreements.Counterparty = &Counterparty
				|	AND EDUsageAgreements.Company = &Company
				|	AND Not EDUsageAgreements.DeletionMark";
				Query.SetParameter("Counterparty",         EDParameters.Counterparty);
				Query.SetParameter("Company",        EDParameters.Company);
				Selection = Query.Execute().Select();
				Selection.Next();
			EndIf;
			
			EDParameters.Insert("EDFSetup", Selection.Ref);
		EndIf;
	Else
		EDParameters.Insert("EDFSetup", ExchangeParameters.EDAgreement);
	
	EndIf;
	
	Return Result;
	
EndFunction

// For internal use only
Function CanOpenInEDTreeForm(Val ObjectReference, CheckForAgreement, OpenAgreementForm, EDParameters) Export
	
	OpenInTree = False;
	If CheckForAgreement AND Not GetCurrentEDFConfiguration(ObjectReference, EDParameters) Then
		OpenAgreementForm = True;
	Else
		ObjectType = TypeOf(ObjectReference);
		OpenInTree = Metadata.DataProcessors.ElectronicDocuments.Commands.EDTree.CommandParameterType.ContainsType(ObjectType);
	EndIf;
	
	Return OpenInTree;
	
EndFunction

 // Sets the electronic document status
 //
 // Parameters
 //  <ED>  - <CatalogRef.EdAttachedFiles> - reference to
 //  electronic document <EDStatus>  - <EnumRef.EDStatuses> - new status of electronic document
 //
Procedure SetEDStatus(ED, EDStatus) Export
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("EDStatus", EDStatus);
	ElectronicDocumentsService.ChangeByRefAttachedFile(ED, ParametersStructure, False);
	
EndProcedure

 // Sets the electronic document status
 //
 // Parameters
 //  EDArray  - Array - refs to
 //  electronic documents EDStatus  - EnumRef.EDStatuses - new status of electronic document
 //
Procedure SetEDStatuses(EDKindsArray, EDStatus) Export
	
	For Each ED IN EDKindsArray Do
		SetEDStatus(ED, EDStatus);
	EndDo;
	
EndProcedure

// Returns password to the certificate if it is available to the current user.
// If the call is in the exclusive mode, the current user is not considered.
//
// Parameters:
//  Certificate - Undefined - return the passwords to all certificates that are accessible to the current user.
//             - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - return
//                 password to the specified certificate.
//              
// Returns:
//  Undefined - password for the specified certificate is not specified.
//  String       - password for the specified certificate.
//  Map - all specified passwords available to
//                 the current user as a key - certificate and value - password.
//
Function PasswordToCertificate(Certificate = Undefined) Export
	
	SetPrivilegedMode(True);
	Data = Constants.EDOperationContext.Get().Get();
	SetPrivilegedMode(False);
	
	If Not Users.RolesAvailable("DSUsage") Then
		If Certificate <> Undefined Then
			Return Undefined;
		EndIf;
		Return New ValueList;
	EndIf;
	
	If Certificate <> Undefined Then
		If TypeOf(Data) <> Type("Map") Then
			Return Undefined;
		EndIf;
		
		Properties = Data.Get(Certificate);
		
		If TypeOf(Properties) = Type("Structure")
		   AND Properties.Property("Password")
		   AND TypeOf(Properties.Password) = Type("String")
		   AND Properties.Property("User")
		   AND TypeOf(Properties.User) = Type("CatalogRef.Users") Then
			
		   If Properties.User = Users.CurrentUser()
			   OR Properties.User = Catalogs.Users.EmptyRef() Then
				
				Return Properties.Password;
			EndIf;
		EndIf;
		
		Return Undefined;
	EndIf;
	
	CertificatesPasswords = New Map;
	
	If TypeOf(Data) <> Type("Map") Then
		Return CertificatesPasswords;
	EndIf;
	
	
	For Each KeyAndValue IN Data Do
		Properties = KeyAndValue.Value;
		
		If TypeOf(Properties) = Type("Structure")
		   AND Properties.Property("Password")
		   AND TypeOf(Properties.Password) = Type("String")
		   AND Properties.Property("User")
		   AND TypeOf(Properties.User) = Type("CatalogRef.Users") Then
			
		   If Properties.User = Users.CurrentUser()
			   OR Properties.User = Catalogs.Users.EmptyRef()
			 Or PrivilegedMode() Then
				CertificatesPasswords.Insert(KeyAndValue.Key, Properties.Password);
			EndIf;
		EndIf;
	EndDo;
	
	Return CertificatesPasswords;
	
EndFunction

// From ED pack additional data, it finds base IDED, finds a ref
// to ED by it and puts it to array. Then again it searches for pack and Parameters
// ED base by the found ref:
//* EDBasesArray - Array - filled in
//with found bases * AddedFile - Ref - ED for which bases
//are searched * EDDirection - Enum - Parameter required for base search
//
Procedure FillInGroundsED(EDBasesArray, AddedFile, EDDirection) Export
	
	If Not TypeOf(AddedFile) = Type("Array") Then
		EDAdded = New Array;
		EDAdded.Add(AddedFile);
	Else
		EDAdded = AddedFile;
	EndIf;
	
	For Each ArrayElement IN EDAdded Do
		CurrentED = ArrayElement;
		While ValueIsFilled(CurrentED) Do
			BasisED = BasisED(CurrentED, EDDirection);
			If ValueIsFilled(BasisED) Then
				EDBasesArray.Add(BasisED);
			EndIf;
			CurrentED = BasisED;
		EndDo;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Unpacking electronic documents packages

// Returns an array of binary data of electronic documents package contents.
//
// Parameters:
//  EDPackage - DocumentRef.EDPackage - reviewed package of electronic documents.
//  EncryptionParameters - Structure, encryption settings applicable to the package of electronic documents.
//
Function ReturnArrayBinaryDataPackage(EDPackage) Export
	
	SetPrivilegedMode(True);
		
	If Not DetermineEDPackageBinaryDataReadingPossibility(EDPackage) Then
		Return Undefined;
	EndIf;
	
	EDPackageParameters = CommonUse.ObjectAttributesValues(EDPackage, "EDFSetting, EDExchangeMethod, PackFormatVersion");
	If EDPackageParameters.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
		OR EDPackageParameters.PackageFormatVersion <> Enums.EDPackageFormatVersions.Version10 Then
		
		Return ElectronicDocumentsInternal.ReturnArrayBinaryDataPackageOperatorOfEDO(EDPackage);
	EndIf;
	
	// As this process potentially generates a lot of errors and is executed in the cycle, take
	// it to attempt-exception. This way if an error occurs in one container, the rest can be correctly unpacked
	
	FileOfArchive = "";
	EncryptedArchiveFile = "";
	
	Try
		// Check whether the agreement specified in the pack is still relevant.
		If Not ValueIsFilled(EDPackageParameters.EDFSetup)
			OR CommonUse.ObjectAttributeValue(EDPackageParameters.EDFSetup, "ConnectionStatus")
			<> Enums.EDExchangeMemberStatuses.Connected Then
			
			ExceptionMessage = NStr("en='There is no current EDF setup for this package of electronic documents.
		|Unpacking is impossible.';ru='По данному пакету электронных документов нет действующей настройки ЭДО.
		|Распаковка невозможна.'");
			Raise(ExceptionMessage);
			Return Undefined;
		EndIf;
		
		// It is required to get the pack archive from the files attached to the document
		FilterStructure = New Structure("FileOwner", EDPackage);
		AttachedFilesSelection = ElectronicDocumentsService.GetEDSelectionByFilter(FilterStructure);
		If Not ValueIsFilled(AttachedFilesSelection) OR Not AttachedFilesSelection.Next() Then
			Return Undefined;
		EndIf;
		
		// For each pack it is required to determine file with data
		DataParameters = ElectronicDocumentsService.GetFileData(AttachedFilesSelection.Ref);
		FileBinaryData = GetFromTempStorage(DataParameters.FileBinaryDataRef);
		FileOfArchive = ElectronicDocumentsService.TemporaryFileCurrentName("zip");
		FileBinaryData.Write(FileOfArchive);
		
		ZIPReading = New ZipFileReader(FileOfArchive);
		FolderForUnpacking = ElectronicDocumentsService.WorkingDirectory("Ext", EDPackage.Ref.UUID());

		Try
			ZIPReading.ExtractAll(FolderForUnpacking);
		Except
			ErrorText = BriefErrorDescription(ErrorInfo());
			If Not ElectronicDocumentsService.PossibleToExtractFiles(ZIPReading, FolderForUnpacking) Then
				MessageText = ElectronicDocumentsReUse.GetMessageAboutError("006");
			EndIf;
			ProcessExceptionByEDOnServer(NStr("en='ED package Unpacking';ru='распаковка пакета ЭД'"), ErrorText, MessageText);
			ZIPReading.Close();
			DeleteFiles(FileOfArchive);
			DeleteFiles(FolderForUnpacking);
			Return Undefined;
		EndTry;
		ZIPReading.Close();
		DeleteFiles(FileOfArchive);
		
		ArchiveFiles = FindFiles(FolderForUnpacking, "*");
		
		// Data file is also stored as .zip-archive.
		// IN a single pack there can be several data files, assemble it into an array.
		
		DataFileArray = FindFiles(FolderForUnpacking, "*.zip");
		NotificationFilesArray = FindFiles(FolderForUnpacking, "*NotificationAboutReceivingDocument*.xml");
		
		// Decrypt file
		// with data Find file with information about the document encryption
		InformationFile = Undefined;
		For Each File IN ArchiveFiles Do
			If Find(File.Name, "packageDescription") > 0 Then
				InformationFile = File;
			ElsIf File.Extension <> ".p7s" AND File.Extension <> ".zip" Then
				DataFileArray.Add(File);
			EndIf;
		EndDo;
		
		// For the subsequent actions determine agreement 
		
		InformationText = New TextDocument;
		InformationText.Read(InformationFile.FullName);
		
		If PerformCryptoOperationsAtServer() Then
			CryptoManager = GetCryptoManager();
		Else
			CryptoManager = Undefined;
		EndIf;
		
		MapFileParameters = GetCorrespondingFileParameters(InformationFile);
		
		PackageEDObject = EDPackage.GetObject();
		
		AddedFilesArray = New Array;
		
		If Not MapFileParameters.Get("Text") = Undefined Then
			MapFileParameters.Insert("IsArbitraryED", True);
		EndIf;
		
		ReturnStructure = New Structure;
		ReturnStructure.Insert("MapFileParameters",        MapFileParameters);
		ReturnStructure.Insert("StructureOfBinaryData",          ConvertFilesArrayIntoBinaryData(
			DataFileArray));
		ReturnStructure.Insert("StructureOfBinaryDataAnnouncements", ConvertFilesArrayIntoBinaryData(
			NotificationFilesArray));
			
		AllFilesArray = FindFiles(FolderForUnpacking, "*.*", True);
		DataFiles = New Map;
		For Each File IN AllFilesArray Do
			FileBinaryData = New BinaryData(File.FullName);
			RefToFileData = PutToTempStorage(FileBinaryData, New UUID);
			DataFiles.Insert(File.Name, RefToFileData);
		EndDo;
		DeleteFiles(FolderForUnpacking);
		ReturnStructure.Insert("PackageFiles", DataFiles);

		Return ReturnStructure;
		
	Except
		MessageText = BriefErrorDescription(ErrorInfo())
			+ NStr("en=' (see details in Event log monitor).';ru=' (подробности см. в Журнале регистрации).'");
		ErrorText = DetailErrorDescription(ErrorInfo());
		ProcessExceptionByEDOnServer(NStr("en='ED package Unpacking';ru='распаковка пакета ЭД'"), ErrorText, MessageText);
		
		Return Undefined;
	EndTry;
	
EndFunction

// Function that adds data by the unpacked pack of electronic documents.
//
// Parameters:
//  EDPackage - DocumentRef.EDPack, electronic documents pack according to which it is required to add data. 
//  SignaturesDataStructure - Structure that connects binary data of data file and binary data of electronic digital signature.
//  DataStructure - Structure linking files names to their binary data.
//  MapFileParameters - Match connecting the data attachment file names and electronic digital signatures attachment file names.
//  PackageFiles - Map - Contains pack
//    files data * Key - String - File
//    name * Value - String - Refs to temporary storage of file binary data
//
Function AddDataByEDPackage(EDPackage,
								SignaturesDataStructure,
								DataStructure,
								MapFileParameters,
								PackageFiles,
								ErrorFlag = False,
								IsCryptofacilityOnClient = Undefined,
								AccordanceOfEdAndSignatures = Undefined) Export
								
	SetPrivilegedMode(True);
	
	IsArbitraryED = MapFileParameters.Get("IsArbitraryED");
	
	EDPackageParameters = CommonUse.ObjectAttributesValues(EDPackage, "EDFProfileSettings,
		|EDExchangeMethod, EDFSetting, Sender, Receiver, Company, Counterparty, PackFormatVersion");
	
	HasCryptoToolAtServer = EDPackageParameters.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
			 						AND (ServerAuthorizationPerform());
	
	AddedFilesArray = New Array;
	// Try to obtain cryptography settings.
	// If it fails, then the cryptography tools are not installed on AWP
	If PerformCryptoOperationsAtServer() OR HasCryptoToolAtServer Then
		CryptoManager = GetCryptoManager();
	Else
		CryptoManager = Undefined;
	EndIf;
	
	If Not IsCryptofacilityOnClient = True AND SignaturesDataStructure.Count() > 0
		AND CryptoManager = Undefined Then
		
		MessageText = NStr("en='Package unpacking
		|failed:
		|%1 Package contains electronic digital signatures. The cryptofacility is required to be on the computer to unpack';ru='Ошибка
		|распаковки
		|пакета: %1 Пакет содержит электронные цифровые подписи. Для распаковки требуется наличие криптосредства на компьютере.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, EDPackage);

		If Not IsCryptofacilityOnClient = Undefined Then
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		ElectronicDocumentsService.WriteEventOnEDToEventLogMonitor(MessageText, 2, EventLogLevel.Information);
		ErrorFlag = True;
		Return Undefined;
	EndIf;
	
	SignaturesStructure = MapFileParameters.Get(DataStructure.FileName);
	Try
		BeginTransaction();
		PackageEDObject = EDPackage.GetObject();
		FolderForDetails = ElectronicDocumentsService.WorkingDirectory("Dec", EDPackage.Ref.UUID());
		
		If GetDataFileForProcessing(DataStructure, FolderForDetails, IsArbitraryED) Then
		
			If IsArbitraryED <> True Then
				EncryptionFiles = FindFiles(FolderForDetails, "*.xml");
				If EncryptionFiles.Count() > 0 Then
					IsArbitraryED = False;
					FileWithData = EncryptionFiles[0];
					Try
						EDFileStructure = ElectronicDocumentsInternal.ReadCMLFileHeaderByXDTO(FileWithData.FullName);
						// Xsd-schema of the Customer invoice
						// note does not allow to pass EDNumber, in this case, take EDNumber from transport information card.
						RegulationsCode = "";
						If SignaturesStructure.Property("RegulationsCode", RegulationsCode) AND ValueIsFilled(RegulationsCode) Then
							EDFileStructure.EDNumber = SignaturesStructure.EDNumber;
						EndIf;
						
						EDFileStructure.Insert("EDDirection", DetermineDirection(EDFileStructure));
						
						// Take company and counterparty from pack as for incoming and outgoing files they switch places
						EDFileStructure.Insert("Company", EDPackageParameters.Company);
						EDFileStructure.Insert("Counterparty",  EDPackageParameters.Counterparty);
						
					Except
						IsArbitraryED = True;
					EndTry;
				Else
					IsArbitraryED = True;
				EndIf;
			EndIf;
			
			ParametersStructure = New Structure;
			
			AddData = "";
			AdditParameters = "";
			AddInformation = Undefined;
			If SignaturesStructure.Property("AddData", AddData) AND TypeOf(AddData) = Type("Structure") AND AddData.Count() > 0 Then
				AdditDataFileName = "";
				If AddData.Property("AdditDataFile", AdditDataFileName) Then
					ParametersStructure.Insert("AdditDataFile", PackageFiles.Get(AdditDataFileName));
				EndIf;
				If AddData.Property("AdditParameters", AdditParameters) AND TypeOf(AdditParameters) = Type("Structure") Then
					AdditParameters.Property("Comment", AddInformation);
				EndIf;
			EndIf;
			
			// Put a data file and its signature to the attached files to
			// the DB document, specify it in the tabular section of the transport pack.
			SearchParametersStructure = New Structure;
			SearchParametersStructure.Insert("UniqueId",  SignaturesStructure.UniqueId);
			SearchParametersStructure.Insert("EDDirection", Enums.EDDirections.Incoming);
			SearchParametersStructure.Insert("EDKind",
				?(IsArbitraryED, Enums.EDKinds.RandomED, EDFileStructure.EDKind));
			
			AddedFile = ElectronicDocumentsService.DetermineElectronicDocument(SearchParametersStructure);
			
			If Not IsArbitraryED Then
				FileBinaryData = New BinaryData(FileWithData.FullName);
				FileWithDataRef = PutToTempStorage(FileBinaryData, New UUID);
				ParametersStructure.Insert("DataFileRef", FileWithDataRef);
				OwnerObject = ?(EDFileStructure.EDKind = Enums.EDKinds.ProductsDirectory, EDPackageParameters.EDFSetup,
					DetermineBindingObject(EDFileStructure));
				
				If ElectronicDocumentsReUse.UseAdditionalAnalyticsOfCompaniesCatalogPartners() Then
					Partner = CommonUse.ObjectAttributeValue(EDPackageParameters.Counterparty, "Partner");
					EDFileStructure.Insert("Partner", Partner);
				EndIf;
			
				If OwnerObject <> Undefined Then
					ParametersStructure.Insert("EDOwner", OwnerObject);
				EndIf;
				EDStructure = ElectronicDocumentsInternal.ParseDataFile(ParametersStructure);
				
				// Xsd-schema of the customer invoice
				// note does not allow to pass EDNumber, in this case, take EDNumber from transport information card.
				RegulationsCode = "";
				If SignaturesStructure.Property("RegulationsCode", RegulationsCode) AND ValueIsFilled(RegulationsCode) Then
					EDStructure.Insert("EDNumber", SignaturesStructure.EDNumber);
				EndIf;
				
				NewDocument = Undefined;
				If Not (EDStructure.Property("EDOwner", NewDocument) AND ValueIsFilled(NewDocument)) Then
					ErrorFlag = True;
				EndIf;
			Else
				DataFileMask = StrReplace(DataStructure.FileName, DataStructure.FileDescriptionWithoutExtension, "*");
				EncryptionFiles = FindFiles(FolderForDetails, DataFileMask);
				If EncryptionFiles.Count() > 0 Then
					FileWithData = EncryptionFiles[0];
					EDFileStructure = New Structure;
					EDFileStructure.Insert("EDKind",                          Enums.EDKinds.RandomED);
					EDFileStructure.Insert("EDNumber",                        SignaturesStructure.EDNumber);
					EDFileStructure.Insert("Company",                    EDPackageParameters.Company);
					EDFileStructure.Insert("Counterparty",                     EDPackageParameters.Counterparty);
					EDFileStructure.Insert("EDVersionNumber",                  0);
					EDFileStructure.Insert("SenderDocumentNumber",      "");
					EDFileStructure.Insert("SenderDocumentDate",       "");
					EDFileStructure.Insert("EDFormingDateBySender", "");
					
					MessageString = MapFileParameters.Get("Text");
					Try
						If TypeOf(AddedFile) = Type("CatalogRef.EDAttachedFiles")
							AND ValueIsFilled(AddedFile) AND ValueIsFilled(AddedFile.FileOwner) Then
							DocumentMessage = AddedFile.FileOwner.GetObject();
						Else
							DocumentMessage = Documents.RandomED.CreateDocument();
							DocumentMessage.Direction     = Enums.EDDirections.Incoming;
							DocumentMessage.DocumentStatus = Enums.EDStatuses.Received;
							DocumentMessage.Date            = CurrentSessionDate();
							DocumentMessage.WasRead        = False;
						EndIf;
						DocumentMessage.Counterparty      = EDPackageParameters.Counterparty;
						DocumentMessage.Company     = EDPackageParameters.Company;
						DocumentMessage.Text           = MessageString;
						UniqueGroundsID = Undefined;
						If ValueIsFilled(AdditParameters) AND AdditParameters.Property("UniqueGroundsID", UniqueGroundsID)
							AND ValueIsFilled(UniqueGroundsID) Then
							Query = New Query;
							Query.Text =
								"SELECT DISTINCT
								|	RandomED.Ref
								|FROM
								|	Catalog.EDAttachedFiles AS EDAttachedFiles
								|		INNER JOIN Document.RandomED AS RandomED
								|		ON EDAttachedFiles.FileOwner = RandomED.Ref
								|WHERE
								|	EDAttachedFiles.UniqueId = &UniqueGroundsID
								|	AND EDAttachedFiles.Counterparty = &Counterparty
								|	AND EDAttachedFiles.Company = &Company";
							Query.SetParameter("UniqueGroundsID", UniqueGroundsID);
							Query.SetParameter("Counterparty", EDPackageParameters.Counterparty);
							Query.SetParameter("Company", EDPackageParameters.Company);
							Selection = Query.Execute().Select();
							If Selection.Next() Then
								DocumentMessage.BasisDocument = Selection.Ref;
							EndIf;
						EndIf;
						If SignaturesStructure.Property("DocumentType") Then
							DocumentMessage.DocumentType = SignaturesStructure.DocumentType;
						Else
							DocumentMessage.DocumentType = Enums.EDTypes.Other;
						EndIf;
						ConfirmationRequired = True;
						If SignaturesStructure.Property("ConfirmationRequired") Then
							ConfirmationRequired = SignaturesStructure.ConfirmationRequired;
						EndIf;
						DocumentMessage.ConfirmationRequired = ConfirmationRequired;
						DocumentMessage.Write();
						
						OwnerObject = DocumentMessage.Ref;
						EDStructure = New Structure;
						EDStructure.Insert("EDOwner", OwnerObject);
						EDStructure.Insert("EDKind", Enums.EDKinds.RandomED);
						EDStructure.Insert("EDDirection", Enums.EDDirections.Incoming);
						If Not ValueIsFilled(AddedFile) Then
							NewDocument = OwnerObject;
						EndIf;
					Except
						MessagePattern = NStr("en='%1 (for more information, see Event log)';ru='%1 (подробности см. в Журнале регистрации)'");
						MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
						BriefErrorDescription(ErrorInfo()));
						ProcessExceptionByEDOnServer(NStr("en='create arbitrary ED';ru='создание произвольного ЭД'"),
							DetailErrorDescription(ErrorInfo()), MessageText);
						ErrorFlag = True;
					EndTry;
				Else
					ErrorFlag = true;
				EndIf;
			EndIf;
			
			If EDPackageParameters.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
				AND Not Find(EDPackageParameters.Recipient, Char(65) + Char(76)) > 0 Then
				ErrorFlag = true;
			EndIf;
			
			If Not ErrorFlag Then
				If Not ValueIsFilled(AddedFile) Then
					
					AddressInTemporaryStorage = PutToTempStorage(DataStructure.BinaryData);
					EDFileStructure.Insert("UniqueId", SignaturesStructure.UniqueId);
					
					DataFileSignatures = SignaturesStructure.Signatures;
					FileStructure = ElectronicDocumentsService.GetFileStructure(DataStructure.FileName);
					
					AddedFile = AttachedFiles.AddFile(
																NewDocument,
																FileStructure.BaseName,
																FileStructure.Extension,
																CurrentSessionDate(),
																CurrentSessionDate(),
																AddressInTemporaryStorage,
																Undefined,
																,
																Catalogs.EDAttachedFiles.GetRef());
					
					Responsible = ElectronicDocumentsOverridable.GetResponsibleByED(EDPackageParameters.Counterparty,
						EDPackageParameters.EDFSetup);
					
					EDOwner = "";
					If ValueIsFilled(AddedFile) Then
						VersionPointTypeED = Enums.EDVersionElementTypes.PrimaryED;
						
						// Determine 1C schedule version by the schedule code.
						EDFScheduleVersion = Enums.Exchange1CRegulationsVersion.Version10;
						If RegulationsCode = "Formalized" OR RegulationsCode = "Invoice" Then
							EDFScheduleVersion = Enums.Exchange1CRegulationsVersion.Version20;
						EndIf;
						
						EDStructure.Insert("Sender",                     EDPackageParameters.Sender);
						EDStructure.Insert("Recipient",                      EDPackageParameters.Recipient);
						EDStructure.Insert("Responsible",                   Responsible);
						EDStructure.Insert("EDFProfileSettings",              EDPackageParameters.EDFProfileSettings);
						EDStructure.Insert("EDAgreement",                    EDPackageParameters.EDFSetup);
						EDStructure.Insert("UniqueId",                    EDFileStructure.UniqueId);
						EDStructure.Insert("VersionPointTypeED",             VersionPointTypeED);
						EDStructure.Insert("EDFScheduleVersion",             EDFScheduleVersion);
						EDStructure.Insert("EDFormingDateBySender",  EDFileStructure.EDFormingDateBySender);
						EDStructure.Insert("FileDescription",               FileStructure.BaseName);
						EDStructure.Insert("PackageFormatVersion",             EDPackageParameters.PackageFormatVersion);
						EDStructure.Insert("AdditionalInformation",        AddInformation);
						If EDFileStructure.Property("ElectronicDocumentOwner", EDOwner) Then
							EDStructure.Insert("ElectronicDocumentOwner", EDOwner);
							EDStructure.Insert("SenderDocumentNumber", EDOwner.SenderDocumentNumber);
							EDStructure.Insert("SenderDocumentDate", EDOwner.SenderDocumentDate);
						EndIf;
						Company = Undefined;
						If Not (EDStructure.Property("Company", Company) AND ValueIsFilled(Company)) Then
							EDStructure.Insert("Company", EDPackageParameters.Company);
						EndIf;
						Counterparty = Undefined;
						If Not (EDStructure.Property("Counterparty", Counterparty) AND ValueIsFilled(Counterparty)) Then
							EDStructure.Insert("Counterparty", EDPackageParameters.Counterparty);
						EndIf;
						EDStatus = Undefined;
						If Not (EDStructure.Property("EDStatus", EDStatus) AND ValueIsFilled(EDStatus)) Then
							EDStructure.Insert("EDStatus", Enums.EDStatuses.Received);
						EndIf;
						SetEDNewVersion(NewDocument, AddedFile);
						ElectronicDocumentsService.ChangeByRefAttachedFile(AddedFile, EDStructure);
						
						AdditDataFileRef = "";
						If ParametersStructure.Property("AdditDataFile", AdditDataFileRef)
							AND ValueIsFilled(AdditDataFileRef) Then
							
							FileStructure = CommonUseClientServer.SplitFullFileName(AdditDataFileName);
													
							AddedAdditFile = AttachedFiles.AddFile(
																			NewDocument,
																			FileStructure.BaseName,
																			StrReplace(FileStructure.Extension, ".", ""),
																			CurrentSessionDate(),
																			CurrentSessionDate(),
																			AdditDataFileRef,
																			Undefined,
																			,
																			Catalogs.EDAttachedFiles.GetRef());
							
							If ValueIsFilled(AddedAdditFile) Then
								SecondaryStructure = New Structure;
								SecondaryStructure.Insert("EDKind", Enums.EDKinds.AddData);
								SecondaryStructure.Insert("Counterparty", EDPackageParameters.Counterparty);
								SecondaryStructure.Insert("Company", EDPackageParameters.Company);
								SecondaryStructure.Insert("EDOwner", NewDocument);
								SecondaryStructure.Insert("EDFProfileSettings", EDPackageParameters.EDFProfileSettings);
								SecondaryStructure.Insert("EDAgreement", EDPackageParameters.EDFSetup);
								SecondaryStructure.Insert("EDNumber",      EDStructure.EDNumber);
								SecondaryStructure.Insert("UniqueId", EDFileStructure.UniqueId);
								SecondaryStructure.Insert("EDDirection", Enums.EDDirections.Incoming);
								SecondaryStructure.Insert("VersionPointTypeED", Enums.EDVersionElementTypes.AdditionalED);
								SecondaryStructure.Insert("ElectronicDocumentOwner", AddedFile);
								SecondaryStructure.Insert("EDFormingDateBySender", EDStructure.SenderDocumentDate);
								SecondaryStructure.Insert("FileDescription", FileStructure.BaseName);
								SecondaryStructure.Insert("EDStatus", Enums.EDStatuses.Received);
								
								ElectronicDocumentsService.ChangeByRefAttachedFile(AddedAdditFile, SecondaryStructure);
							EndIf;
						EndIf;
					EndIf;
					
					If ValueIsFilled(EDOwner)
						AND (AddedFile.EDKind = Enums.EDKinds.TORG12Customer
							OR AddedFile.EDKind = Enums.EDKinds.ActCustomer
							OR AddedFile.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient)
						AND EDOwner.EDStatus <> Enums.EDStatuses.ConfirmationReceived Then
						
						EDOwnerParametersStructure = New Structure;

						ValidEDStatus = ElectronicDocumentsService.GetAdmissibleEDStatus(
							Enums.EDStatuses.ConfirmationReceived, EDOwner);
						EDOwnerParametersStructure.Insert("EDStatus", ValidEDStatus);
						ElectronicDocumentsService.ChangeByRefAttachedFile(EDOwner, EDOwnerParametersStructure, False);
					EndIf;
					
					If ValueIsFilled(DataFileSignatures) Then
						SignaturesArray = New Array;
						For Each SignatureFileName IN DataFileSignatures Do
							BinaryDataSignatures = GetFromTempStorage(PackageFiles.Get(SignatureFileName));
							SignaturesArray.Add(BinaryDataSignatures);
							If PerformCryptoOperationsAtServer() OR HasCryptoToolAtServer Then
								SignatureCertificates = CryptoManager.GetCertificatesFromSignature(BinaryDataSignatures);
								If SignatureCertificates.Count() <> 0 Then
									Certificate = SignatureCertificates[0];
									SignatureInstallationDate = ElectronicDocumentsService.SignatureInstallationDate(BinaryDataSignatures);
									SignatureInstallationDate = ?(ValueIsFilled(SignatureInstallationDate), SignatureInstallationDate, CurrentSessionDate());
									PrintBase64 = Base64String(Certificate.Imprint);
									UserPresentation = DigitalSignatureClientServer.SubjectPresentation(Certificate);
									AddInformationAboutSignature(
																	AddedFile,
																	BinaryDataSignatures,
																	PrintBase64,
																	SignatureInstallationDate,
																	"",
																	SignatureFileName,
																	UserPresentation,
																	Certificate.Unload());
								EndIf;
							EndIf;
						EndDo;
						If PerformCryptoOperationsAtServer() OR HasCryptoToolAtServer Then
							DetermineSignaturesStatuses(AddedFile);
						ElsIf Not AccordanceOfEdAndSignatures = Undefined Then
							AccordanceOfEdAndSignatures.Insert(AddedFile, SignaturesArray);
						EndIf;
					EndIf;
					
					//If the Torg-12 document kind (seller title)
					// has an incoming direction, it has the EDOwner attribute filled in and document status is - exchange
					// is complete, then it is required in the documents based on which it is input - to set the "Exchange is completed with correction" status
					
					If (ValidEDStatus = Enums.EDStatuses.ConfirmationReceived) Then
						
						SetCompletedState(AddedFile, Enums.EDDirections.Outgoing);
						
					EndIf;
					
					AddedFilesArray.Add(AddedFile);
				EndIf;
				
				// Add information about the attached file to the document of electronic documents pack
				For Each AddedFile IN AddedFilesArray Do
					
					NewElectronicDocument = PackageEDObject.ElectronicDocuments.Add();
					NewElectronicDocument.ElectronicDocument = AddedFile;
					NewElectronicDocument.OwnerObject      = AddedFile.FileOwner;
					
				EndDo;
				
				If CryptoManager <> Undefined AND Not IsArbitraryED Then
					ConfirmedDocuments = ElectronicDocumentsService.ProcessDocumentConfirmations(PackageFiles,
																											  MapFileParameters,
																											  PackageEDObject);
				EndIf;
				
				PackageEDObject.Write();
			EndIf;
		Else
			ErrorFlag = True;
		EndIf;
		If ErrorFlag Then
			RollbackTransaction();
			
			AddedFilesArray = Undefined;
		Else
			CommitTransaction();
		EndIf;
		
	Except
		RollbackTransaction();
		
		MessageText = BriefErrorDescription(ErrorInfo())
			+ NStr("en=' (see details in Event log monitor).';ru=' (подробности см. в Журнале регистрации).'");
		ProcessExceptionByEDOnServer(NStr("en='ED package Unpacking';ru='распаковка пакета ЭД'"),
										  DetailErrorDescription(ErrorInfo()),
										  MessageText);
		ErrorFlag = True;
		AddedFilesArray = Undefined;
	EndTry;
	DeleteFiles(FolderForDetails);
	
	Return AddedFilesArray;
	
EndFunction

// Sets the EDPack document status.
//
// Parameters:
//  Package - Ref to
//  the EDPack document PackStatus - ref to enumeration EDPacksStatuses
//
Procedure SetPackageStatus(Package, PackageStatus) Export
	
	SetPrivilegedMode(True);
	PackageEDObject = Package.GetObject();
	PackageEDObject.PackageStatus = PackageStatus;
	PackageEDObject.Write();
	
EndProcedure

// For internal use only
Procedure GetStatementData(Val ED, LinksToRepository, AccountsArray = Undefined, Company = Undefined, EDAgreement = Undefined) Export
	
	Var StatementText;
	
	If Not ElectronicDocumentsService.SetSignaturesValid(ED) Then
		Return;
	EndIf;
	
	EDAttributes = CommonUse.ObjectAttributesValues(ED, "Company, EDAgreement, EDKind");
	
	If Not EDAttributes.EDKind = PredefinedValue("Enum.EDKinds.BankStatement") Then
		Return
	EndIf;
	
	Company  = EDAttributes.Company;
	EDAgreement = EDAttributes.EDAgreement;
	
	ElectronicDocuments.GetBankStatementDataTextFormat(ED, LinksToRepository, AccountsArray);
	
EndProcedure

// Adds DS to electronic document.
//
// Parameters:
//  AttachedFile - Ref to catalog item containing electronic document,
//  SignatureData - DS parameters structure.
//
Procedure AddSignature(AttachedFile, SignatureData) Export
	
	SetPrivilegedMode(True);
	
	EDExchangeMethod = CommonUse.ObjectAttributeValue(AttachedFile.EDFProfileSettings, "EDExchangeMethod");
	HasCryptoToolAtServer = EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
									AND ServerAuthorizationPerform();
	Try
		BeginTransaction();
		AttachedFiles.AddInformationOfOneSignature(AttachedFile, SignatureData);
		If PerformCryptoOperationsAtServer() OR HasCryptoToolAtServer Then
			DetermineSignaturesStatuses(AttachedFile);
		EndIf;
		If ElectronicDocumentFullyDigitallySigned(AttachedFile) Then
			
			EDDirection = CommonUse.ObjectAttributeValue(AttachedFile, "EDDirection");
			If EDDirection = Enums.EDDirections.Intercompany Then
				NewEDStatus = ElectronicDocumentsService.GetAdmissibleEDStatus(
																		Enums.EDStatuses.FullyDigitallySigned,
																		AttachedFile);
			Else
				NewEDStatus = ElectronicDocumentsService.GetAdmissibleEDStatus(
																		Enums.EDStatuses.DigitallySigned,
																		AttachedFile);
			EndIf;
			
			ParametersStructure = New Structure("EDStatus", NewEDStatus);
			ElectronicDocumentsService.ChangeByRefAttachedFile(AttachedFile, ParametersStructure, False);
			ElectronicDocumentsOverridable.AssignedStatusDigitallySigned(AttachedFile);
			
		Else
			
			// Within intercompany document should have 2
			// signatures as electronic document is not fully signed,
			// it is enough to check that DS quantity differs from 0.
			DocumentIntercompanyPartlyDigitallySigned = (AttachedFile.EDDirection = Enums.EDDirections.Intercompany
													AND AttachedFile.DigitalSignatures.Count() > 0);
			IsEDPaymentOrder = AttachedFile.EDKind = Enums.EDKinds.PaymentOrder;
			
			If DocumentIntercompanyPartlyDigitallySigned OR IsEDPaymentOrder Then
				
				NewEDStatus = ElectronicDocumentsService.GetAdmissibleEDStatus(
																		Enums.EDStatuses.PartlyDigitallySigned,
																		AttachedFile);
				
				ParametersStructure = New Structure();
				ParametersStructure.Insert("EDStatus", NewEDStatus);
				ParametersStructure.Insert("Changed", Users.AuthorizedUser());
				ElectronicDocumentsService.ChangeByRefAttachedFile(AttachedFile, ParametersStructure, False);
				
			EndIf;
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		ErrorInfo = DetailErrorDescription(ErrorInfo());
		MessagePattern = NStr("en='An error occurred while signing electronic document %1';ru='Ошибка подписи электронного документа %1'");
		MessageText = StrReplace(MessagePattern, "%1", AttachedFile);
		OperationKind = NStr("en='digitally sign';ru='установка подписи ЭП'");
		ProcessExceptionByEDOnServer(OperationKind, ErrorInfo, MessageText);
		Raise BriefErrorDescription(ErrorInfo);
	EndTry;
	
EndProcedure

// Executes actions with ED after you digitally sign.
//
// Parameters:
//   EDArrayForStatusUpdate - Array - items - CatalogRef.EDAttachedFiles.
//
Procedure ActionsAfterSigningEDOnServer(EDArrayForStatusUpdate) Export
	
	SetPrivilegedMode(True);
	
	For Each AttachedFile IN EDArrayForStatusUpdate Do
		EDExchangeMethod = CommonUse.ObjectAttributeValue(AttachedFile.EDFProfileSettings, "EDExchangeMethod");
		HasCryptoToolAtServer = EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
										AND ServerAuthorizationPerform();
		Try
			BeginTransaction();
			If PerformCryptoOperationsAtServer() OR HasCryptoToolAtServer Then
				DetermineSignaturesStatuses(AttachedFile);
			Else
				// Signature set now is valid by default
				SetLatestSignaturesStatus(AttachedFile); 
			EndIf;
			If ElectronicDocumentFullyDigitallySigned(AttachedFile) Then
				
				EDDirection = CommonUse.ObjectAttributeValue(AttachedFile, "EDDirection");
				If EDDirection = Enums.EDDirections.Intercompany Then
					NewEDStatus = ElectronicDocumentsService.GetAdmissibleEDStatus(
																			Enums.EDStatuses.FullyDigitallySigned,
																			AttachedFile);
				Else
					NewEDStatus = ElectronicDocumentsService.GetAdmissibleEDStatus(
																			Enums.EDStatuses.DigitallySigned,
																			AttachedFile);
				EndIf;
				
				ParametersStructure = New Structure("EDStatus", NewEDStatus);
				ElectronicDocumentsService.ChangeByRefAttachedFile(AttachedFile, ParametersStructure, False);
				ElectronicDocumentsOverridable.AssignedStatusDigitallySigned(AttachedFile);
				
			Else
				
				// Within intercompany document should have 2
				// signatures as electronic document is not fully signed,
				// it is enough to check that DS quantity differs from 0.
				DocumentIntercompanyPartlyDigitallySigned = (AttachedFile.EDDirection = Enums.EDDirections.Intercompany
														AND AttachedFile.DigitalSignatures.Count() > 0);
				IsEDPaymentOrder = AttachedFile.EDKind = Enums.EDKinds.PaymentOrder;
				
				If DocumentIntercompanyPartlyDigitallySigned OR IsEDPaymentOrder Then
					
					NewEDStatus = ElectronicDocumentsService.GetAdmissibleEDStatus(
																			Enums.EDStatuses.PartlyDigitallySigned,
																			AttachedFile);
					
					ParametersStructure = New Structure();
					ParametersStructure.Insert("EDStatus", NewEDStatus);
					ParametersStructure.Insert("Changed", Users.AuthorizedUser());
					ElectronicDocumentsService.ChangeByRefAttachedFile(AttachedFile, ParametersStructure, False);
					
				EndIf;
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			ErrorInfo = ErrorInfo();
			MessagePattern = NStr("en='An error occurred while signing electronic document %1';ru='Ошибка подписи электронного документа %1'");
			MessageText = StrReplace(MessagePattern, "%1", AttachedFile);
			ProcessExceptionByEDOnServer(NStr("en='digitally sign';ru='установка подписи ЭП'"),
																						DetailErrorDescription(ErrorInfo),
																						MessageText);
			Continue;
		EndTry;
	EndDo;
	
EndProcedure

// For internal use only
Function CreateAndSendDocumentsPED(Val AddedFiles,
									  Val SignatureSign,
									  Val CertificatesAgreementsAndParametersMatch = Undefined) Export
	
	EDPackagesStructuresArray = ElectronicDocumentsService.CreateEDPackageDocuments(AddedFiles, SignatureSign);
	ResultStructure = New Structure;
	ResultStructure.Insert("PreparedCnt", EDPackagesStructuresArray.Count());
	SentCnt = 0;
	ArrayOfPackagesForDataProcessorsAtClient = New Array;
	PacksArrayForSendingFromClient   = New Array;
	If EDPackagesStructuresArray.Count() > 0 Then
		For Each StructurePED IN EDPackagesStructuresArray Do
			If StructurePED.Property("SendingFromClient") Then
				PacksArrayForSendingFromClient.Add(StructurePED.EDP);
				Continue;
			EndIf;
			If StructurePED.RequiredEncryptionAtClient Then
				ArrayOfPackagesForDataProcessorsAtClient.Add(StructurePED.EDP);
				Continue;
			EndIf;
			If ElectronicDocumentsService.ImmediateEDSending() Then
				ArrayPED = New Array;
				ArrayPED.Add(StructurePED.EDP);
				SentCnt = SentCnt + EDPackagesSending(ArrayPED, CertificatesAgreementsAndParametersMatch);
			EndIf;
		EndDo;
	EndIf;
	ResultStructure.Insert("SentCnt",                    SentCnt);
	ResultStructure.Insert("ArrayOfPackagesForDataProcessorsAtClient", ArrayOfPackagesForDataProcessorsAtClient);
	If ElectronicDocumentsService.ImmediateEDSending() AND PacksArrayForSendingFromClient.Count() > 0 Then
		DataForSendingViaAddDataProcessor = DataForSendingToBank(
			PacksArrayForSendingFromClient, Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor);
		ResultStructure.Insert("DataForSendingViaAddDataProcessor", DataForSendingViaAddDataProcessor);
		DataForiBank2Sending = DataForSendingToBank(
			PacksArrayForSendingFromClient, Enums.BankApplications.iBank2);
		ResultStructure.Insert("DataForiBank2Sending", DataForiBank2Sending);
	EndIf;
	Return ResultStructure;
	
EndFunction

// For internal use only
Function EDPackagesSending(Val ArrayPackageED, Val CertificatesAgreementsAndParametersMatch, MessageText = "") Export
	
	SetPrivilegedMode(True);
	
	SendingResult = 0;
	For Each EDPackage IN ArrayPackageED Do
		// If electronic document can not be sent for some reasons,
		// it is not necessary to suspend the entire chain.
		
		BeginTransaction();
		
		ElectronicDocumentsService.UpdateEDPackageDocumentsStatuses(EDPackage,
																		Enums.EDPackagesStatuses.Sent,
																		CurrentSessionDate());
		If Not EDPackage.PackageStatus = Enums.EDPackagesStatuses.Sent Then
			RollbackTransaction();
			Continue;
			
		EndIf;
		
		Try
			
			EDPackageAttributes = CommonUse.ObjectAttributesValues(EDPackage,
				"EDFProfileSettings, EDFSetting, EDExchangeMethod, CounterpartyResourceAddress, ElectronicDocuments");
			
			EDFSettingProfilesArray = New Array;
			EDFSettingProfilesArray.Add(EDPackageAttributes.EDFProfileSettings);
			
			SendingType = EDPackageAttributes.EDExchangeMethod;
			SendingDirectoryAddress = GenerateFilesForSending(EDPackage);
			If IsBlankString(SendingDirectoryAddress) Then
				RollbackTransaction();
				Continue;
			EndIf;
			If SendingType = Enums.EDExchangeMethods.ThroughEMail Then
				CurrentPackageSent = SendByEmail(EDPackage, SendingDirectoryAddress);
				SendingResult = SendingResult + CurrentPackageSent;
				If CurrentPackageSent = 0 Then
					RollbackTransaction();
					DeleteFiles(SendingDirectoryAddress);
					Continue;
				EndIf;
				
				ChangeBaseDocumentsEDState(EDPackageAttributes);
				
			ElsIf SendingType =  Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
				CorrAgreements = Undefined;
				If TypeOf(CertificatesAgreementsAndParametersMatch) = Type("Map")
					AND CertificatesAgreementsAndParametersMatch.Count() > 0 Then
					CertificateParameters = CertificatesAgreementsAndParametersMatch.Get(EDPackageAttributes.EDFProfileSettings);
				ElsIf ParametersAvailableForAuthorizationOnOperatorServer(EDFSettingProfilesArray, CorrAgreements) Then
					CertificateParameters = CorrAgreements.Get(EDPackageAttributes.EDFProfileSettings);
				Else
					RollbackTransaction();
					DeleteFiles(SendingDirectoryAddress);
					Continue;
				EndIf;
				Marker = Undefined;
				If Not (DecryptMarkerFromStructureOfCertificateAtServer(CertificateParameters)
					AND CertificateParameters.Property("MarkerTranscribed", Marker) AND ValueIsFilled(Marker)) Then
					RollbackTransaction();
					DeleteFiles(SendingDirectoryAddress);
					Continue;
				EndIf;
				FilesOfSending = FindFiles(SendingDirectoryAddress, "*");
				CountToSend = FilesOfSending.Count();
				
				Selection = EDPackageAttributes.ElectronicDocuments.Select();
				If Selection.Count() > 0 AND Selection.Next() Then
					ElectronicDocument = Selection.ElectronicDocument;
					EDParameters = CommonUse.ObjectAttributesValues(ElectronicDocument, "EDKind, Name");
					If Not Find(EDParameters.Description, "AL") > 0 Then
						
						SendingResult = SendingResult + CountToSend;
						RollbackTransaction();
						DeleteFiles(SendingDirectoryAddress);
						Continue;
					EndIf;
				EndIf;
				CountSent = ElectronicDocumentsInternal.SendThroughEDFOperator(
																	Marker,
																	SendingDirectoryAddress,
																	"SendMessage",
																	EDPackageAttributes.EDFProfileSettings);
																	
				If CountSent <> CountToSend Then
					MessagePattern = NStr("en='Unable to send to EDF provider ""%1"".';ru='Не удалось отправить оператору ЭДО ""%1"".'");

					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, EDPackage);
					
					CommonUseClientServer.MessageToUser(MessageText);
					RollbackTransaction();
					Continue;
				Else
					SendingResult = SendingResult + CountSent;
				EndIf;
				
				If ValueIsFilled(ElectronicDocument) Then
					If Not ElectronicDocument.EDKind = Enums.EDKinds.NotificationAboutReception Then
						SetCompletedState(ElectronicDocument, Enums.EDDirections.Incoming);
					EndIf;
				EndIf;
				
			ElsIf SendingType = Enums.EDExchangeMethods.ThroughDirectory Then
				
				DirectoryAddress = EDPackageAttributes.CounterpartyResourceAddress
					+ ?(Right(EDPackageAttributes.CounterpartyResourceAddress, 1) <> "\", "\", "");
				DirectoryOnHardDisk = New File(DirectoryAddress);
				If Not DirectoryOnHardDisk.Exist() Then
					CreateDirectory(DirectoryAddress);
				EndIf;
				
				FilesOfSending = FindFiles(SendingDirectoryAddress, "*");
				For Each File IN FilesOfSending Do
					FileCopy(File.FullName, DirectoryAddress + File.Name);
					SendingResult = SendingResult + 1;
				EndDo;
				
				ChangeBaseDocumentsEDState(EDPackageAttributes);
				
			ElsIf SendingType = Enums.EDExchangeMethods.ThroughFTP Then
				FTPConnection = ElectronicDocumentsService.GetFTPConnection(EDPackageAttributes.EDFProfileSettings);
				If FTPConnection = Undefined Then
					RollbackTransaction();
					DeleteFiles(SendingDirectoryAddress);
					Continue;
				EndIf;
				SendingDirectory = EDPackageAttributes.CounterpartyResourceAddress;
				ElectronicDocumentsService.PrepareFTPPath(SendingDirectory);
				ErrorText = "";
				Try
					FTPConnection.SetCurrentDirectory(SendingDirectory);
				Except
					ElectronicDocumentsService.CreateFTPDirectories(FTPConnection, SendingDirectory, , ErrorText);
				EndTry;
				If ValueIsFilled(ErrorText) Then
					RollbackTransaction();
					DeleteFiles(SendingDirectoryAddress);
					Continue;
				EndIf;
				FilesOfSending = FindFiles(SendingDirectoryAddress, "*");
				For Each File IN FilesOfSending Do
					ElectronicDocumentsService.WriteFileOnFTP(FTPConnection, File.FullName, File.Name, , ErrorText);
					If ValueIsFilled(ErrorText) Then 
						Break;
					EndIf;
					SendingResult = SendingResult + 1;
				EndDo;
				If ValueIsFilled(ErrorText) Then
					RollbackTransaction();
					DeleteFiles(SendingDirectoryAddress);
					Continue;
				EndIf;
				
				ChangeBaseDocumentsEDState(EDPackageAttributes);
				
			ElsIf SendingType = Enums.EDExchangeMethods.ThroughBankWebSource Then
				
				EDFSettingAttributes = CommonUse.ObjectAttributesValues(EDPackageAttributes.EDFSetup,
					"ServerAddress, OutgoingDocumentsResource, IncomingDocumentsResource,
					|CryptographyIsUsed, BankApplication, CompanyID");
					
				If Not EDFSettingAttributes.CryptographyIsUsed
					AND (CertificatesAgreementsAndParametersMatch = Undefined
						OR CertificatesAgreementsAndParametersMatch.Get(EDPackageAttributes.EDFSetup) = Undefined) Then
					RollbackTransaction();
					DeleteFiles(SendingDirectoryAddress);
					Continue;
				EndIf;
				
				If EDFSettingAttributes.BankApplication = Enums.BankApplications.SberbankOnline
						OR EDFSettingAttributes.BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
						OR EDFSettingAttributes.BankApplication = Enums.BankApplications.iBank2 Then
					RollbackTransaction();
					DeleteFiles(SendingDirectoryAddress);
					Continue;
				EndIf;
				
				Settings = New Structure("Address", EDFSettingAttributes.ServerAddress);
				
				If Not EDFSettingAttributes.CryptographyIsUsed
					AND EDFSettingAttributes.BankApplication = Enums.BankApplications.AlphaBankOnline Then
					AuthorizationParameters = CertificatesAgreementsAndParametersMatch.Get(EDPackageAttributes.EDFSetup);
					AuthorizationHash = Base64StringWithoutBOM(
						AuthorizationParameters.User + ":" + AuthorizationParameters.UserPassword);
					Settings.Insert("Hash", AuthorizationHash);
				EndIf;
				
				Selection = EDPackageAttributes.ElectronicDocuments.Select();
				If Selection.Count() > 0 AND Selection.Next() Then
					ED = Selection.ElectronicDocument;
					Data = AttachedFiles.GetFileBinaryData(ED);
					If EDFSettingAttributes.BankApplication = Enums.BankApplications.AsynchronousExchange Then
						Settings.Insert("Resource", "SendPack");
						AuthorizationParameters = CertificatesAgreementsAndParametersMatch.Get(EDPackageAttributes.EDFSetup);
						If AuthorizationParameters = Undefined OR Not AuthorizationParameters.Property("MarkerTranscribed")
							OR Not ValueIsFilled(AuthorizationParameters.MarkerTranscribed) Then
								RollbackTransaction();
								DeleteFiles(SendingDirectoryAddress);
								Continue;
						EndIf;
						SessionID = AuthorizationParameters.MarkerTranscribed;
						Settings.Insert("SessionID", SessionID);
						Settings.Insert("CompanyID", EDFSettingAttributes.CompanyID);
					Else
						Settings.Insert("Resource", EDFSettingAttributes.OutgoingDocumentsResource);
					EndIf;
					FilesOfSending = FindFiles(SendingDirectoryAddress, "*");
					PathToSendingFile = FilesOfSending[0].FullName;
					
					BankResponse = "";
					ErrorText = "";
					ElectronicDocumentsService.SendPackageThroughBankResource(Settings, PathToSendingFile, BankResponse, ErrorText);
					
					If ValueIsFilled(ErrorText) Then
						OperationKindTemplate = NStr("en='Sending ED package under agreement: %1, exchange method: %2';ru='Отправка пакета ЭД по соглашению: %1, способ обмена %2'");
						OperationKind = StringFunctionsClientServer.SubstituteParametersInString(
							OperationKindTemplate, EDPackageAttributes.EDFSetup, EDPackageAttributes.EDExchangeMethod);
						MessageText = ErrorText;
						ElectronicDocumentsService.ProcessBankPackSendingError(ED, OperationKind, ErrorText, MessageText);
						RollbackTransaction();
						DeleteFiles(SendingDirectoryAddress);
						Continue;
					EndIf;
					
					DeleteFiles(PathToSendingFile);
					
					If EDFSettingAttributes.BankApplication = Enums.BankApplications.AlphaBankOnline Then
						ElectronicDocumentsService.ProcessBankResponse(BankResponse, ED);
					Else
						ProcessBankResponseOnSendingDocumentAsync(BankResponse, ED, EDPackage);
					EndIf;
					SendingResult = SendingResult + 1;
					
					RefreshEDVersion(ED);
				EndIf;
			EndIf;
			
			CommitTransaction();
		Except
			
			MessagePattern = NStr("en='An error occurred while sending pack by setting:
		|%1, exchange method: %2 %3 (for more information, see The events log monitor).';ru='Ошибка отправки пакета по настройке:
		|%1, способ обмена: %2 %3 (подробности см. в Журнале регистрации).'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
																MessagePattern,
																EDPackageAttributes.EDFSetup,
																EDPackageAttributes.EDExchangeMethod,
																BriefErrorDescription(ErrorInfo()));
			OperationKindTemplate = NStr("en='sending ED package under agreement: %1, exchange method: %2';ru='отправка пакета ЭД по соглашению: %1, способ обмена %2'");
			OperationKind = StringFunctionsClientServer.SubstituteParametersInString(
																OperationKindTemplate,
																EDPackageAttributes.EDFSetup,
																EDPackageAttributes.EDExchangeMethod);
			DetailErrorDescription = DetailErrorDescription(ErrorInfo());
			
			If SendingType = Enums.EDExchangeMethods.ThroughBankWebSource Then
				ProcessExceptionByEDOnServer(OperationKind, DetailErrorDescription, MessageText, 1);
			Else
				ProcessExceptionByEDOnServer(OperationKind, DetailErrorDescription, MessageText);
			EndIf;
			
			If SendingType = Enums.EDExchangeMethods.ThroughBankWebSource Then
				
				ErrorText = BriefErrorDescription(ErrorInfo());
				EDStructure = New Structure;
				EDStructure.Insert("EDStatus", Enums.EDStatuses.TransferError);
				EDStructure.Insert("CorrectionText", ErrorText);
				ElectronicDocumentsService.ChangeByRefAttachedFile(ED, EDStructure, False);

				ElectronicDocumentsService.UpdateEDPackageDocumentsStatuses(EDPackage,
																				Enums.EDPackagesStatuses.Canceled,
																				CurrentSessionDate());
				CommitTransaction();
			Else
				RollbackTransaction();
			EndIf;
		EndTry;
		If ValueIsFilled(SendingDirectoryAddress) Then
			DeleteFiles(SendingDirectoryAddress);
		EndIf;
	EndDo;
	
	Return SendingResult;
	
EndFunction

// Returns match with files
// binary data and electronic digital signatures to them.
//
// Parameters:
//  FileName - String, path to data file.
//  PackageFiles - Map - Contains pack
//    files data * Key - String - file
//    name * Value - String - ref to the temporary storage
//  of file binary data DecryptedBinaryData - BinaryData, binary data of the data file.
//  MapFileParameters - Match, binds the data attachment file names and electronic digital signatures.
//  IsXMLFile - Boolean, shows that the passed file is xml-file.
//
Function GetSignaturesDataCorrespondence(FileName,
										   PackageFiles,
										   DecryptedBinaryData,
										   MapFileParameters,
										   IsXMLFile = False) Export
	
	ReturnArray = New Array;
	EncryptedArchiveFile = ?(IsXMLFile,
								  ElectronicDocumentsService.TemporaryFileCurrentName("xml"),
								  ElectronicDocumentsService.TemporaryFileCurrentName("zip"));
	DecryptedBinaryData.Write(EncryptedArchiveFile);
	EncryptedDataFile = New File(EncryptedArchiveFile);
	
	// Determine signature to the file, check the signature
	
	DataFileSignatures  = MapFileParameters.Get(FileName).Signatures;
	DataFileBinaryData = New BinaryData(EncryptedDataFile.FullName);
	DeleteFiles(EncryptedDataFile.FullName);
	
	If DataFileSignatures = Undefined OR DataFileSignatures.Count() = 0 Then
		// If there are no signatures, then continue but there may be an error
	Else
		For Each SignatureFileName IN DataFileSignatures Do
			BinaryDataSignatures = GetFromTempStorage(PackageFiles.Get(SignatureFileName));
			ReturnStructure = New Structure("FileBinaryData, SignatureBinaryData",
				DataFileBinaryData, BinaryDataSignatures);
			
			ReturnArray.Add(ReturnStructure);
		EndDo;
	EndIf;
	
	Return ReturnArray;
	
EndFunction

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
	
	If Not IsBlankString(MessageText) Then
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	ErrorText = NStr("en='Execute operation:';ru='Выполнение операции:'")+ " " + OperationKind + Chars.LF + DetailErrorText;
	ElectronicDocumentsService.WriteEventOnEDToEventLogMonitor(ErrorText, EventCode);
	
EndProcedure

// Returns a user message text by an error code.
//
// Parameters:
//  ErrorCode - String, error code;
//  ThirdPartyErrorDescription - String, error description passed to another system.
//
// Returns:
//  MessageText - String - overridden error description.
//
Function GetMessageAboutError(ErrorCode, ThirdPartyErrorDescription = "") Export
	
	Return ElectronicDocumentsReUse.GetMessageAboutError(ErrorCode, ThirdPartyErrorDescription);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// File operations

// For internal use only
Function TemporaryFilesCurrentDirectory() Export
	
	GetCurrentDirectory = "";
	ElectronicDocumentsOverridable.TemporaryFilesCurrentDirectory(GetCurrentDirectory);
	If Not ValueIsFilled(GetCurrentDirectory) Then
		GetCurrentDirectory = TempFilesDir();
	EndIf;
	
	Return GetCurrentDirectory;
	
EndFunction

// Function is used to check whether directory that is specified in agreement on exchange settings (via directory) is available:
// on client file is written to the directory, on server an attempt is executed to read it by the same path. This is
// due to the fact that this directory should be available both from client, and from server.
//
// Parameters:
//  FullNameOfTestFile - String - full path to the text file written from the client session;
//
// Return parameter:
//  Boolean - True - file by the specified path exists, otherwise, - False.
//
Function ReadTestFileAtServer(FullNameOfTestFile) Export
	
	TestFile = New File(FullNameOfTestFile);
	
	Return TestFile.Exist();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Rights

// For internal use only
Function IsRightToProcessED(OutputMessage = True) Export
	
	IsRight = ElectronicDocumentsOverridable.IsRightToProcessED();
	If TypeOf(IsRight) <> Type("Boolean") Then
		IsRight = Users.RolesAvailable("EDExchangeExecution");
	EndIf;
	If Not IsRight AND OutputMessage Then
		ElectronicDocumentsService.MessageToUserAboutViolationOfRightOfAccess();
	EndIf;
	
	Return IsRight;
	
EndFunction

// For internal use only
Function IsRightToReadED(OutputMessage = True) Export
	
	IsRight = ElectronicDocumentsOverridable.IsRightToReadED();
	If TypeOf(IsRight) <> Type("Boolean") Then
		IsRight = Users.RolesAvailable("EDExchangeExecution, EDReading");
	EndIf;	
	If Not IsRight AND OutputMessage Then
		ElectronicDocumentsService.MessageToUserAboutViolationOfRightOfAccess();
	EndIf;
		
	Return IsRight;
		
EndFunction

// Marks for deletion the EDAttachedFiles catalog items with filter by owner
//
// Parameters: 
//  Ref -  object reference.
//
Procedure MarkElectronicDocumentsForDeletionByOwner(Ref) Export
	
	SetPrivilegedMode(True);
	
	DeletionMark = CommonUse.ObjectAttributeValue(Ref, "DeletionMark");
	
	QueryText =
	"SELECT
	|	Files.Ref AS Ref,
	|	Files.DeletionMark
	|FROM
	|	Catalog.EDAttachedFiles AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner
	|	AND (Files.EDStatus = VALUE(Enum.EDStatuses.Created)
	|			OR Files.EDStatus = VALUE(Enum.EDStatuses.EmptyRef))";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("FileOwner", Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		If Not Selection.DeletionMark = DeletionMark Then
			FileObject = Selection.Ref.GetObject();
			Try
				FileObject.Lock();
			Except
				Pattern = NStr("en='Unable to lock object %1';ru='Не удалось заблокировать объект %1'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(Pattern, FileObject);
				DetailErrorDescription = DetailErrorDescription(ErrorInfo());
				OperationKind = NStr("en='Mark electronic documents for deletion';ru='Пометка на удаление электронных документов'");
				ProcessExceptionByEDOnServer(OperationKind, DetailErrorDescription, MessageText, 5);
				Continue;
			EndTry;
			FileObject.SetDeletionMark(DeletionMark);
			FileObject.Unlock();
		EndIf;
	EndDo;
	
EndProcedure

// Determines by parameters whether there is a current agreement
// 
// Parameters:
//  EDParameters - structure containing agreement search parameters
//
// Returns:
//  Boolean True or False
//
Function IsActualAgreement(EDParameters) Export
	
	ExchangeSettings = ElectronicDocumentsService.DetermineEDExchangeSettings(EDParameters);
	
	Return ValueIsFilled(ExchangeSettings);
	
EndFunction

// It returns the structure for opening the form of ProductsAndServices matching
//
// Parameters:
//  LinkToED - CatalogRef.EDAttachedFiles
//
// Returns:
//  Structure containing FormName and FormOpenParameters
//
Function GetProductsAndServicesComparingFormParameters(LinkToED) Export
	
	ParametersStructure = ElectronicDocumentsOverridable.GetProductsAndServicesComparingFormParameters(
																								LinkToED);
	If TypeOf(ParametersStructure) = Type("Structure") AND ParametersStructure.Property("FormOpenParameters") Then
		ParametersStructure.FormOpenParameters.Insert("WindowOpeningMode",
															FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	Return ParametersStructure;
	
EndFunction

// By reference to document determines whether it has e.d.
//
// Parameters:
//  RefToOwner - DocumentRef
//
// Returns:
//  Boolean, document existence fact
//
Function IsWorkingESF(RefToOwner) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDStates.ElectronicDocument
	|FROM
	|	InformationRegister.EDStates AS EDStates
	|WHERE
	|	EDStates.ObjectReference = &RefToOwner
	|	AND EDStates.ElectronicDocument <> VALUE(Catalog.EDAttachedFiles.EmptyRef)
	|	AND EDStates.ElectronicDocument.EDStatus <> VALUE(Enum.EDStatuses.Rejected)";
	
	Query.SetParameter("RefToOwner", RefToOwner);
	
	SetPrivilegedMode(True);
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

// Returns an applied catalog name by the library catalog name.
//
// Parameters:
//  CatalogName - String - catalog name from the library.
//
// Returns:
//  AppliedCatalogName - String name of the applied catalog.
//
Function GetAppliedCatalogName(CatalogName) Export
	
	Return ElectronicDocumentsReUse.GetAppliedCatalogName(CatalogName);
	
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
	
	CorrespondenceFO = New Map;
	
	// Electronic documents
	CorrespondenceFO.Insert("UseEDExchange",                    "UseEDExchange");
	CorrespondenceFO.Insert("UseEDExchangeBetweenCompanies",  "UseEDExchangeBetweenCompanies");
	CorrespondenceFO.Insert("UseEDExchangeWithBanks",            "UseEDExchangeWithBanks");
	
	// Library of standard subsystems
	CorrespondenceFO.Insert("UseDigitalSignatures",     "UseDigitalSignatures");
	CorrespondenceFO.Insert("UseAdditionalReportsAndDataProcessors", "UseAdditionalReportsAndDataProcessors");
	
	ElectronicDocumentsOverridable.GetFunctionalOptionsCorrespondence(CorrespondenceFO);
	
	NameSOfAppliedSolution = CorrespondenceFO.Get(FODescription);
	If NameSOfAppliedSolution = Undefined Then // match is not specified
		Result = False;
	Else
		Result = GetFunctionalOption(NameSOfAppliedSolution)
	EndIf;
	
	Return Result;
	
EndFunction

// Gets a text presentation of the e-document version.
//
// Parameters:
//  RefToOwner - Ref to an IB object which e-document version state it is required to get.
//  Hyperlink - Boolean, True - it is required to make "EDState" form attribute a hyperlink.
//
Function EDStateText(RefToOwner, Hyperlink) Export
	
	SetPrivilegedMode(True);
	EDStateText = "";
	If ValueIsFilled(RefToOwner) Then
		If GetFunctionalOptionValue("UseEDExchange") Then
			
			If TypeOf(RefToOwner) = Type("CatalogRef.EDUsageAgreements") Then
				Hyperlink = True;
				Return EDStateText;
			Else
				EDCurrentState = EDVersionState(RefToOwner);
				EDStateText = String(EDCurrentState);
			EndIf;
			
			EDParameters = Undefined;
			If GetCurrentEDFConfiguration(RefToOwner, EDParameters) Then
				
				Hyperlink = True;
				If Not ValueIsFilled(EDStateText) Then
					Hyperlink = False;
					If EDParameters.EDDirection = Enums.EDDirections.Outgoing Then
						EDStateText = NStr("en='Not generated';ru='Не сформирован'");
					Else
						EDStateText = NStr("en='Not received';ru='Не поступившие'");
					EndIf;
				EndIf;
				// Show a user the exchange mode "check technical compatibility".
				AgreementState = CommonUse.GetAttributeValue(EDParameters.EDFSetup, "AgreementState");
				If AgreementState = Enums.EDAgreementStates.CheckingTechnicalCompatibility Then
					TemplateEDState = NStr("en='%1 (technical compatibility check)';ru='%1 (проверка технической совместимости)'");
					EDStateText = StringFunctionsClientServer.SubstituteParametersInString(TemplateEDState, EDStateText);
				EndIf;
			Else
				
				If ValueIsFilled(EDStateText) Then
					TemplateEDState = NStr("en='%1 (EDF setting is not connected)';ru='%1 (настройка ЭДО не подключена)'");
					EDStateText = StringFunctionsClientServer.SubstituteParametersInString(TemplateEDState, EDStateText);
					Hyperlink = True;
				Else
					
					If EDParameters.EDKind = Enums.EDKinds.PaymentOrder Then
						EDStateText = NStr("en='No valid EDF setting with bank';ru='Нет действующей настройки ЭДО с банком'");
					ElsIf EDParameters.EDKind = Enums.EDKinds.GoodsTransferBetweenCompanies
						Or EDParameters.EDKind = Enums.EDKinds.ProductsReturnBetweenCompanies Then
						EDStateText = NStr("en='No valid EDF setting with a receiving company';ru='Нет действующей настройки ЭДО с организацией-получателем'");
					Else
						EDStateText = NStr("en='Set up EDF with counterparty';ru='Настроить ЭДО с контрагентом'");
						Hyperlink = True;
					EndIf;
				EndIf;
			EndIf;
		Else
			EDStateText = NStr("en='Electronic document exchange is disabled';ru='Обмен электронными документами отключен'");
		EndIf;
	EndIf;
	
	Return EDStateText;
	
EndFunction

// Checks whether ED passed to the parameter is a service one or not.
//
Function ThisIsServiceDocument(ElectronicDocument) Export
	
	If ValueIsFilled(ElectronicDocument.VersionPointTypeED) Then
		ReturnValue = Not (ElectronicDocument.VersionPointTypeED = Enums.EDVersionElementTypes.PrimaryED
			OR ElectronicDocument.VersionPointTypeED = Enums.EDVersionElementTypes.ESF);
	Else
		ReturnValue = Not (ElectronicDocument.EDKind = Enums.EDKinds.NotificationAboutReception
			OR ElectronicDocument.EDKind = Enums.EDKinds.NotificationAboutClarification
			OR ElectronicDocument.EDKind = Enums.EDKinds.CancellationOffer
			OR ElectronicDocument.EDKind = Enums.EDKinds.Confirmation
			OR ElectronicDocument.EDKind = Enums.EDKinds.Error
			OR ElectronicDocument.EDKind = Enums.EDKinds.AddData);
	EndIf;
	
	Return ReturnValue;
	
EndFunction

// Checks whether electronic document
// signatures are valid and fills in the Status and SignaturesCheckDate attributes in the DigitalSignatures tabular section.
//
// Parameters:
//  ED - CatalogRef
//  EDAttachedFiles OutputMessages - Boolean, whether it is required to output messages.
//
Procedure DetermineSignaturesStatuses(ED, OutputMessages = False) Export
	
	SetPrivilegedMode(True);
	
	AgreementAttributes = CommonUse.ObjectAttributesValues(ED.EDAgreement, "BankApplication, EDExchangeMethod");
	
	If AgreementAttributes.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource
			AND (AgreementAttributes.BankApplication = Enums.BankApplications.SberbankOnline
				OR AgreementAttributes.BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
				OR AgreementAttributes.BankApplication = Enums.BankApplications.iBank2) Then
		Return;
	EndIf;
	
	Cancel = False;
	Try
		CryptoManager = GetCryptoManager(Cancel);
	Except
		Cancel = True;
	EndTry;
	If Cancel Then
		If OutputMessages Then
			MessageText = GetMessageAboutError("110");
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		Return;
	EndIf;
	
	AdditInformationAboutED = ElectronicDocumentsService.GetFileData(ED);
	DocumentBinaryData = GetFromTempStorage (AdditInformationAboutED.FileBinaryDataRef);
		
	EDObject = ED.GetObject();
	
	For Each DSRow in EDObject.DigitalSignatures Do
		Try
			DSBinaryData = DSRow.Signature.Get();
			ElectronicDocumentsService.VerifySignature(CryptoManager, DocumentBinaryData, DSBinaryData);
			DSRow.SignatureVerificationDate = CurrentSessionDate();
			DSRow.SignatureIsCorrect = True;
		Except
			DSRow.SignatureVerificationDate = CurrentSessionDate();
			DSRow.SignatureIsCorrect = False;
			
			MessageText = GetMessageAboutError("114");
			DetailErrorDescription = DetailErrorDescription(ErrorInfo());
			OperationKind = NStr("en='Digital signature verification';ru='проверка электронной подписи'");
			ProcessExceptionByEDOnServer(OperationKind, DetailErrorDescription, MessageText);
		EndTry;
	EndDo;
	
	EDObject.Write();
	
EndProcedure

// For internal use only
Procedure RefillIBDocumentsByED(IBDocument, Val ED, MetadataObject = Undefined, DocumentImported = False) Export
	
	// Warning! For a single transaction in ED there will be Structure.
	
	If ED.EDKind = Enums.EDKinds.TORG12Customer
		OR ED.EDKind = Enums.EDKinds.ActCustomer
		OR ED.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient Then
		
		ED = ED.ElectronicDocumentOwner;
	EndIf;
	
	FillDocumentIBByEd(IBDocument, ED, DocumentImported);
	
	MetadataObject = Metadata.FindByType(TypeOf(IBDocument)).FullName();
	
EndProcedure

// Returns binary data of the electronic document
//
// Parameters: 
// ED - CatalogRef.EDAttachedFiles, reference to electronic document.
// SignatureCertificate  - ref - ref to the DS Certificates catalog item
//
Function GetFileBinaryData(ED, SignatureCertificate) Export
	
	BinaryDataED = AttachedFiles.GetFileBinaryData(ED);
	
	If ValueIsFilled(SignatureCertificate) Then
		
		EDParameters = CommonUse.ObjectAttributesValues(ED, "EDKind, Company, EDDirection");
		IsEDBankKind = EDParameters.EDKind = Enums.EDKinds.BankStatement
			OR EDParameters.EDKind = Enums.EDKinds.QueryStatement OR EDParameters.EDKind = Enums.EDKinds.QueryProbe
			OR EDParameters.EDKind = Enums.EDKinds.EDReturnQuery
			OR EDParameters.EDKind = Enums.EDKinds.QueryNightStatements
			OR EDParameters.EDKind = Enums.EDKinds.EDStateQuery
			OR EDParameters.EDKind = Enums.EDKinds.NotificationOnStatusOfED
			OR EDParameters.EDKind = Enums.EDKinds.STATEMENT OR EDParameters.EDKind = Enums.EDKinds.Error
			OR EDParameters.EDKind = Enums.EDKinds.PaymentOrder;
		
		// Check whether full name fields in the certificate are filled in
		If Not IsEDBankKind
			AND (NOT ValueIsFilled(SignatureCertificate.Surname) OR Not ValueIsFilled(SignatureCertificate.Name)) Then
			MessageText = NStr("en='Operation is canceled. It is required to
		|fill in fields: ""Surname"", ""Name"" in the %1 certificate';ru='Операция отменена. Необходимо заполнить поля: ""Фамилия"", ""Имя""
		|в сертификате %1.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, SignatureCertificate);
			Raise MessageText;
		EndIf;
		
		DataFileChanged = False;
		If EDParameters.EDKind = Enums.EDKinds.ActPerformer
			OR EDParameters.EDKind = Enums.EDKinds.ActCustomer
			OR EDParameters.EDKind = Enums.EDKinds.TORG12Seller
			OR EDParameters.EDKind = Enums.EDKinds.TORG12Customer
			OR EDParameters.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender
			OR EDParameters.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient Then
			
			FileName = GetTempFileName("xml");
			BinaryDataED.Write(FileName);
			FillEDSigerData(FileName, EDParameters.Company, SignatureCertificate, EDParameters.EDKind);
			DataFileChanged = True;
			
		ElsIf EDParameters.EDKind = Enums.EDKinds.NotificationAboutReception
			OR EDParameters.EDKind = Enums.EDKinds.NotificationAboutClarification Then
			
			FileName = GetTempFileName("xml");
			BinaryDataED.Write(FileName);
			FillServiceEDSigerData(FileName, EDParameters.Company, SignatureCertificate);
			
			DataFileChanged = True;
			
		ElsIf EDParameters.EDDirection = Enums.EDDirections.Outgoing
			AND (EDParameters.EDKind = Enums.EDKinds.ProductsDirectory
			OR EDParameters.EDKind = Enums.EDKinds.PriceList
			OR EDParameters.EDKind = Enums.EDKinds.ProductOrder
			OR EDParameters.EDKind = Enums.EDKinds.ResponseToOrder
			OR EDParameters.EDKind = Enums.EDKinds.InvoiceForPayment
			OR EDParameters.EDKind = Enums.EDKinds.ComissionGoodsSalesReport
			OR EDParameters.EDKind = Enums.EDKinds.ComissionGoodsWriteOffReport
			OR EDParameters.EDKind = Enums.EDKinds.RightsDelegationAct) Then
			
			FileName = GetTempFileName("zip");
			BinaryDataED.Write(FileName);
			
			ZIPReading = New ZipFileReader(FileName);
			FolderForUnpacking =  ElectronicDocumentsService.WorkingDirectory("DSSignature", ED.UUID());
			
			Try
				ZipReading.ExtractAll(FolderForUnpacking);
			Except
				ErrorText = BriefErrorDescription(ErrorInfo());
				If Not ElectronicDocumentsService.PossibleToExtractFiles(ZipReading, FolderForUnpacking) Then
					MessageText = ElectronicDocumentsReUse.GetMessageAboutError("006");
				EndIf;
				ProcessExceptionByEDOnServer(NStr("en='Extract ED CML from archive while signing';ru='Извлечение ЭД CML из архива при подписи'"),
				ErrorText, MessageText);
			EndTry;
			ZIPReading.Close();
			
			EDFiles = FindFiles(FolderForUnpacking, "*.xml");
			If EDFiles.Count() > 0 Then
				FileWithData = EDFiles[0];
				FillEDSigerDataCML_206(FileWithData.FullName, EDParameters.Company, SignatureCertificate);
				DataFileChanged = True;
			EndIf;
			
			DeleteFiles(FileName);
			FileName = GetTempFileName("zip");
			ZipContainer = New ZipFileWriter(FileName);
			
			ArchiveFiles = FindFiles(FolderForUnpacking, "*");
			For Each File IN ArchiveFiles Do
				ZipContainer.Add(File.FullName);
			EndDo;
			
			Try
				ZipContainer.Write();
			Except
				ErrorText = BriefErrorDescription(ErrorInfo());
				ProcessExceptionByEDOnServer(NStr("en='Generation of ED CML archive while signing';ru='Формирование архива ЭД CML при подписи'"),
				ErrorText, MessageText);
			EndTry;
			DeleteFiles(FolderForUnpacking);
		EndIf;
		
		If DataFileChanged Then
			
			BinaryDataED = New BinaryData(FileName);
			
			InformationAboutFile = New Structure;
			InformationAboutFile.Insert("FileAddressInTemporaryStorage", PutToTempStorage(BinaryDataED));
			InformationAboutFile.Insert("TextTemporaryStorageAddress", "");
			AttachedFiles.UpdateAttachedFile(ED, InformationAboutFile);
			DeleteFiles(FileName);
		EndIf;
	EndIf;
	
	Return BinaryDataED;
	
EndFunction

// Executes actions sequence for electronic documents.
//
// Parameters:
//  RefsToObjectArray - Array of refs to electronic documents for which it is
//  required to determine the sequence of actions, CryptographyClientSettings - Available certificates
//  array Actions - String presentation of
//  required actions, AdditionalParameters - Structure, additional parameters that determine the sequence of actions with electronic documents.
//  ED - CatalogRef.EDAttachedFiles,
//  ref to the EDAttachedFiles catalog item CertificatesAndDuplicatesMatch - Map - Key - DSCertificate, value - password to certificate;
//
// Returns:
//  Structure.
//
Function PerformActionsByED(Val RefsToObjectArray,
							  Val CertificateTumbprintsArray,
							  Val Actions,
							  AdditParameters = "",
							  Val ED = Undefined,
							  Val CertificatesAndPasswordsMatch) Export
	
	If Not IsRightToProcessED(True) Then
		Return Undefined;
	EndIf;
	
	If Not GetFunctionalOptionValue("UseEDExchange") Then
		MessageText = MessageTextAboutSystemSettingRequirement("WorkWithED");
		CommonUseClientServer.MessageToUser(MessageText);
		Return Undefined;
	EndIf;
	
	ServerAuthorizationPerform = ServerAuthorizationPerform();
	PerformCryptoOperationsAtServer = PerformCryptoOperationsAtServer();
	ImmediateEDSending = ElectronicDocumentsService.ImmediateEDSending();
	
	If ElectronicDocumentsClientServer.IsAction(Actions, "Sign")
		OR ElectronicDocumentsClientServer.IsAction(Actions, "Send") Then
		StampArrayClient = CertificateTumbprintsArray;
		If PerformCryptoOperationsAtServer Then
			Try
				CertificateTumbprintsArray = CertificateTumbprintsArray();
			Except
				CertificateTumbprintsArray = New Array;
				AdditParameters.Insert("CryptographySettingsError", True);
			EndTry;
		EndIf;
		
		AvailableCertificatesTable = ElectronicDocumentsService.AvailableForSigningCertificatesTable(
																				CertificateTumbprintsArray);
																				
		ThumbprintArray = AvailableCertificatesTable.UnloadColumn("Imprint");

	EndIf;
	
	SetPrivilegedMode(True);
	
	If TypeOf(ED) <> Type("Array")
		AND Not (ValueIsFilled(ED) AND (ED.EDDirection = Enums.EDDirections.Incoming
										OR ED.EDKind = Enums.EDKinds.TORG12Customer
										OR ED.EDKind = Enums.EDKinds.ActCustomer
										OR ED.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient
										OR ThisIsServiceDocument(ED))) Then
		ElectronicDocumentsOverridable.CheckSourcesReadiness(RefsToObjectArray);
	EndIf;
	
	If TypeOf(ED) <> Type("Array")
		AND RefsToObjectArray.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	ReturnStructure = New Structure;
	// Return structure keys:
	// ExecuteAuthorizationOnServer, ExecuteCryptoOperationsOnServer, ImmediateEDSending - type Boolean;
	// NewEDQuantity, ApprovedEDQuantity, SignedQuantity, PreparedQuantity, SentQuantity - type Number;
	// NewEDArray - type Array;
	// MapOfEDCertificatesAndArraysToSignatures - type Match (key - DSCertificate, value - EDArray for signature
	// on client) StructureForSending - Structure type with keys:
	//                   WithoutSignature, WithSignature - type Array, EDArray (for preparation) for sending, not signed and signed respectively;
	//                   WithAuthorization - type Match (key - EDAgreement, value - EDArray for sending).
	ReturnStructure.Insert("ServerAuthorizationPerform", ServerAuthorizationPerform);
	ReturnStructure.Insert("PerformCryptoOperationsAtServer", PerformCryptoOperationsAtServer);
	ReturnStructure.Insert("ImmediateEDSending", ImmediateEDSending);
	
	ArrayOfUncultivatedObjects = New Array;
	
	// Generate ED:
	
	NewEDCnt = 0;
	If ED = Undefined AND ElectronicDocumentsClientServer.IsAction(Actions, "Generate") Then
		If Actions = "Generate" OR Actions = "GenerateShow" Then
			DeleteInaccessibleForGeneratingEDObjects(RefsToObjectArray);
		EndIf;
		
		ObjectsSettings = New Map;
		For Ct = -RefsToObjectArray.Count() + 1 To 0 Do
			ObjectReference = RefsToObjectArray[-Ct];
			
			// For case of determining ED kind by user
			EDKind = "";
			If ValueIsFilled(AdditParameters) Then
				AdditParameters.Property("EDKind", EDKind);
			EndIf;
			
			ExchangeSettings = ElectronicDocumentsService.DetermineEDExchangeSettingsBySource(ObjectReference,
																								   ,
																								   ,
																								   ,
																								   EDKind);
			If Not ValueIsFilled(ExchangeSettings) Then
				RefsToObjectArray.Delete(-Ct);
			Else
				ObjectsSettings.Insert(ObjectReference, ExchangeSettings);
			EndIf;
		EndDo;
		If RefsToObjectArray.Count() = 0 Then
			Return Undefined;
		EndIf;
		
		Query = New Query;
		QueryTextCreateED =
		"SELECT
		|	RefArray.ObjectRef
		|INTO RefArray
		|FROM
		|	&RefArray AS RefArray
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RefArray.ObjectRef AS EDOwner
		|FROM
		|	RefArray AS RefArray
		|		LEFT JOIN InformationRegister.EDStates AS EDStates
		|		ON RefArray.ObjectRef = EDStates.ObjectReference";
		
		If Actions = "GenerateConfirmSignSend" Then
			DetermineUnprocessedObjects(ObjectsSettings, ArrayOfUncultivatedObjects);
			QueryTextCreateED = QueryTextCreateED + " WHERE
			|(EDStates.ObjectReference IS NULL 
			|OR EDStates.EDVersionState = VALUE(Enum.EDVersionsState.NotFormed)) 
			|OR (EDStates.ElectronicDocument.EDKind = VALUE(Enum.EDKinds.PaymentOrder) 
			|AND (EDStates.EDVersionState = VALUE(Enum.EDVersionsState.Rejected) 
			|OR EDStates.EDVersionsState = VALUE(Enum.EDVersionsState.TransferError))))";
			
		EndIf;
				
		Query.Text = QueryTextCreateED;
		Dimension = Metadata.InformationRegisters.EDStates.Dimensions.Find("ObjectReference");
		VT_Refs = New ValueTable;
		ColumnOfTV = VT_Refs.Columns.Add("ObjectRef", Dimension.Type);
		For Each Item IN RefsToObjectArray Do
			String = VT_Refs.Add();
			String.ObjectRef = Item;
		EndDo;
		Query.SetParameter("RefArray", VT_Refs);
		VT_ED = Query.Execute().Unload();
		
		If VT_ED.Count() > 0 Then
			NewEDArray = ElectronicDocumentsService.GenerateAttachedFiles(VT_ED.UnloadColumn("EDOwner"),
																						  ObjectsSettings,
																						  AdditParameters);
			NewEDCnt = NewEDArray.Count();
		EndIf;
		ReturnStructure.Insert("NewEDCount", NewEDCnt);
		If Actions = "Generate" OR Actions = "GenerateShow" Then
			ReturnStructure.Insert("NewEDArray", NewEDArray);
		EndIf;
	EndIf;
	
	If TypeOf(ED) <> Type("Array")
		AND RefsToObjectArray.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	
	// Generate temporary tables - processed ED, generated TT are used at all stages:
	If ValueIsFilled(ED) Then
		MainQueryText =
			"SELECT
			|	EDAttachedFiles.Ref,
			|	EDAttachedFiles.EDKind,
			|	EDAttachedFiles.FileOwner,
			|	EDAttachedFiles.Counterparty,
			|	EDAttachedFiles.EDDirection,
			|	EDAttachedFiles.Company,
			|	EDAttachedFiles.EDFProfileSettings,
			|	EDAttachedFiles.EDAgreement,
			|	EDAttachedFiles.ElectronicDocumentOwner,
			|	EDAttachedFiles.DigitallySigned,
			|	EDAttachedFiles.EDStatus
			|INTO TU_ED
			|FROM
			|	Catalog.EDAttachedFiles AS EDAttachedFiles
			|WHERE
			|	EDAttachedFiles.Ref IN(&EDRefsArray)
			|";
		If TypeOf(ED) <> Type("Array") Then
			EDRefsArray = New Array;
			EDRefsArray.Add(ED);
		Else
			EDRefsArray = ED;
		EndIf;
		
		Query.SetParameter("EDRefsArray", EDRefsArray);
	Else
		MainQueryText =
			"SELECT
			|	EDAttachedFiles.Ref,
			|	EDAttachedFiles.EDKind,
			|	EDAttachedFiles.FileOwner,
			|	EDAttachedFiles.Counterparty,
			|	EDAttachedFiles.EDDirection,
			|	EDAttachedFiles.Company,
			|	EDAttachedFiles.EDFProfileSettings,
			|	EDAttachedFiles.EDAgreement,
			|	EDAttachedFiles.ElectronicDocumentOwner,
			|	EDAttachedFiles.DigitallySigned,
			|	EDAttachedFiles.EDStatus
			|INTO TU_ED
			|FROM
			|	InformationRegister.EDStates AS EDStates
			|		INNER JOIN Catalog.EDAttachedFiles AS EDAttachedFiles
			|		ON EDStates.ElectronicDocument = EDAttachedFiles.Ref
			|WHERE
			|	EDStates.ObjectReference IN(&RefArray)
			|	AND EDStates.EDVersionState <> VALUE(Enum.EDVersionsStates.ClosedForce)
			|";
		If ArrayOfUncultivatedObjects.Count() > 0 Then
			AdditionalCondition = " AND NOT (EDAttachedFiles.Ref IN (&UnprocessedObjectsArray))";
			Query.SetParameter("ArrayOfUncultivatedObjects", ArrayOfUncultivatedObjects);
			MainQueryText = MainQueryText + AdditionalCondition;
		EndIf;
		Query.SetParameter("RefArray", RefsToObjectArray);
	EndIf;
	
	// Approve ED:
	
	ConfirmedCntED = 0;
	If ElectronicDocumentsClientServer.IsAction(Actions, "Approve") Then
		QueryText =
			"
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	TU_ED.FileOwner AS EDOwner,
			|	TU_ED.Ref AS LinkToED,
			|	TU_ED.EDStatus,
			|	TU_ED.EDKind,
			|	TU_ED.EDAgreement AS EDAgreement
			|FROM
			|	TU_ED AS TU_ED
			|WHERE
			|	TU_ED.EDStatus IN(&StatusesArray)";
		StatusesArray = New Array;
		StatusesArray.Add(Enums.EDStatuses.Created);
		StatusesArray.Add(Enums.EDStatuses.Approved);
		StatusesArray.Add(Enums.EDStatuses.Received);
		StatusesArray.Add(Enums.EDStatuses.PartlyDigitallySigned);
		Query.SetParameter("StatusesArray", StatusesArray);
		Query.Text = MainQueryText + ";" + QueryText;
		VT_ED = Query.Execute().Unload();
		ConfirmedEarlierCnt = 0;
		NewED = Undefined;
		ApprovedCIN = New Array;
		For Each CurRow IN VT_ED Do
			If CurRow.EDStatus = Enums.EDStatuses.Created OR CurRow.EDStatus = Enums.EDStatuses.Received Then
				LinkToED = CurRow.LinkToED;
				BeginTransaction();
				SetSignConfirmed(LinkToED, NewED);
				If TransactionActive() Then
					CurRow.EDStatus = LinkToED.EDStatus;
					ConfirmedCntED = ConfirmedCntED + 1;
					CommitTransaction();
				EndIf;
				
				If LinkToED.EDDirection = Enums.EDDirections.Incoming Then
					ApprovedCIN.Add(LinkToED);
				EndIf;
				
			Else
				ConfirmedEarlierCnt = ConfirmedEarlierCnt + 1;
			EndIf;
			
		EndDo;
		If ValueIsFilled(NewED) Then
			AdditParameters.Insert("NewED", NewED);
		EndIf;
		
		// Change the previous incoming s.f. state
		If ApprovedCIN.Count() > 0 Then
			ElectronicDocumentsInternal.ChangeGroundsIRState(ApprovedCIN, Enums.EDDirections.Incoming);
		EndIf;
		
		ReturnStructure.Insert("CountOfApprovedED", ConfirmedCntED);
	EndIf;
	
	// Incoming ED of the TORG12Salesperson and CertificateExecutive kind - are never signed and
	// sent, exclude them from the subsequent selections:
	MainQueryText = MainQueryText + "
		|AND (CASE WHEN EDAttachedFiles.EDDirection
		|		= &DirectionIncomingED AND EDAttachedFiles.EDKind
		|	IN (&EDExcludedKindsArray)
		|	Then False
		|	Otherwise True End)";
	ArrayOfExcludedTypesOfED = New Array;
	ArrayOfExcludedTypesOfED.Add(Enums.EDKinds.TORG12Seller);
	ArrayOfExcludedTypesOfED.Add(Enums.EDKinds.ActPerformer);
	ArrayOfExcludedTypesOfED.Add(Enums.EDKinds.AgreementAboutCostChangeSender);
	Query.SetParameter("IncomingDirectionOfED", Enums.EDDirections.Incoming);
	Query.SetParameter("ArrayOfExcludedTypesOfED", ArrayOfExcludedTypesOfED);
	
	// Get CertificatesAndStructuresMatch from the incoming parameters.
	AccCertificatesAndTheirStructures = New Map;
	ReturnStructure.Insert("AccCertificatesAndTheirStructures", AccCertificatesAndTheirStructures);
	CertificatesWithPasswords = PasswordToCertificate();
	CurrentUser = Users.CurrentUser();
	For Each Item IN CertificatesWithPasswords Do
		Structure = New Structure("UserPassword, PasswordReceived, RememberCertificatePassword",
			Item.Value, True, False);
		AccCertificatesAndTheirStructures.Insert(Item.Key, Structure);
	EndDo;
	
	// This match will be returned to the client side and on the client an attempt
	// to get certificates passwords and sign ED arrays will be made.
	CorrespondingCertificatesAndArraysOfED = New Map;
	ReturnStructure.Insert("CorrespondingCertificatesAndArraysOfED", CorrespondingCertificatesAndArraysOfED);
	
	CorrAgreementsArraysAndEDForDispatch = New Map;
	EDArraysAndAgreementsMatchForSendingWithAuthorization = New Map;
	ReturnStructure.Insert("CorrAgreementsArraysAndEDForDispatch", CorrAgreementsArraysAndEDForDispatch);
	ReturnStructure.Insert("EDArraysAndAgreementsMatchForSendingWithAuthorization",
		EDArraysAndAgreementsMatchForSendingWithAuthorization);
	
	// ED signing:
	
	// Each signed ED should undergo the process of sending which includes preparation for
	// sending (PED generation) and PED sending (if ImmediateSending is set). Preparation (sending)
	// is divided into sending of not signed EDs, sending of the signed EDs, sending with authorization (on EDFO server).
	// Due to the facts mentioned above, generate structure with ED arrays for sending to pass it to client:
	// Structure in the first 2 items (WithoutSignature, WithSignature) contains ED arrays for sending.
	// IN the 3rd item - map: key - ED agreement, value - ED array sent within agreement.
	// the third item is filled in only if an immediate ED sending is set in the system.
	StructureToSend = New Structure("WithoutSignature, WithSignature, WithAuthorization, WithAuthorizationLoginPassword",
										New Array, New Array, New Map, New Map);
	
	DigitallySignedCnt = 0;
	If ElectronicDocumentsClientServer.IsAction(Actions, "Sign") Then
		// Generate selection for signing:
		// Select EDs to the virtual table that ARE REQUIRED and COULD be signed i.e. that meet the following conditions:
		// - ED is included to the list for the data processor (either passed as "ED" parameter, or
		//     received from "EDStates" Register selected by the owners array, the "RefsToObjectArray" parameter);
		// - ED status is either "Approved", or "Partially signed";
		// - ED SHOULD be signed (determined by the agreement specified in ED): or "Via EDFO" exchange
		//     method or "This is intercompany", or if ED - is an incoming one, then in the agreement on the "Incoming"
		//     tab ED kind is marked for exchange that matches signed ED kind and "Use DS" option is selected or if ED - is an
		//     outgoing one, then in the agreement on the "Outgoing" tab ED kind is marked for exchange
		//     that matches the signed ED and "Use DS" option is selected;
		// - certificate for ED signing exists:
		//     - Company in certificate matches to the company in ED;
		//     - ED kind is marked in the certificate that corresponds to signed ED kind;
		//     - certificate is valid (marked for deletion, not revoked);
		//     - available for use (not limited by a user or the current user
		//         matches user specified in the certificate. Certificate thumbprint is included in thumbprints array received
		//         from the client or server personal storage depending on the cryptography use settings);
		//     - if "Via EDFO" exchange method, then certificate must be registered at EDFO (added to the tab.section
		//         "CompanySignaturesCertificates" of ED exchange agreement).
		//
		// If all described conditions are met, then ED is put to the virtual table together with
		// data required for ED signing: signature certificate, signature parameters, signatures already set to ED, agreement.
		// Then 3 selections are made from the temporary table: ED for signing, certificates for ED signing, set signatures.
		// Take signed ED from the first selection, from the second and the third one - select certificates according to conditions:
		// there should be no thumbprint among the signatures set to ED.
		
		
		// Main query - selection from the temporary tables:
		QueryText =
			"SELECT
			|	Certificates.Ref AS SignatureCertificate,
			|	Certificates.Imprint,
			|	Certificates.Revoked,
			|	Certificates.CertificateData,
			|	Certificates.Company AS CompanyInCertificate,
			|	EDEPKinds.EDKind AS DocumentKind,
			|	BankApplications.BankApplication AS BankApplication,
			|	Certificates.Description,
			|	TU_ED.Ref AS LinkToED
			|INTO TU_Certificates
			|FROM
			|	InformationRegister.DigitallySignedEDKinds AS EDEPKinds
			|		INNER JOIN TU_ED AS TU_ED
			|		ON (EDEPKinds.Use)
			|			AND (TU_ED.EDKind = EDEPKinds.EDKind)
			|		INNER JOIN Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
			|			LEFT JOIN InformationRegister.BankApplications AS BankApplications
			|			ON (BankApplications.DSCertificate = Certificates.Ref)
			|			INNER JOIN (SELECT DISTINCT
			|				EDFProfilesCertificates.Certificate AS Certificate
			|			FROM
			|				TU_ED AS TU_ED
			|					LEFT JOIN Catalog.EDFProfileSettings.CompanySignatureCertificates AS EDFProfilesCertificates
			|					ON TU_ED.EDFProfileSettings = EDFProfilesCertificates.Ref
			|			
			|			UNION ALL
			|			
			|			SELECT
			|				AgreementsEDCertificates.Certificate
			|			FROM
			|				TU_ED AS TU_ED
			|					LEFT JOIN Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsEDCertificates
			|					ON TU_ED.EDAgreement = AgreementsEDCertificates.Ref) AS CertificatesFromSettingsAndProfiles
			|			ON Certificates.Ref = CertificatesFromSettingsAndProfiles.Certificate
			|		ON EDEPKinds.DSCertificate = Certificates.Ref
			|WHERE
			|	Not Certificates.Revoked
			|	AND Not Certificates.DeletionMark
			|	AND (Certificates.User = &EmptyUser
			|			OR Certificates.User = &CurrentUser)
			|	AND (Certificates.Imprint IN (&ThumbprintArray)
			|			OR BankApplications.BankApplication IN (&BankApplicationsList))
			|
			|INDEX BY
			|	SignatureCertificate,
			|	CompanyInCertificate
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	ED_DS.Imprint AS SetSignatures,
			|	TU_ED.Ref AS LinkToED,
			|	AgreementsED.Ref AS EDAgreement,
			|	ISNULL(TU_ED.EDFProfileSettings.EDExchangeMethod, AgreementsED.Ref.EDExchangeMethod) AS EDExchangeMethod,
			|	TU_ED.EDFProfileSettings AS EDFProfileSettings,
			|	TU_Certificates.SignatureCertificate AS SignatureCertificate,
			|	TU_Certificates.Imprint,
			|	TU_Certificates.Revoked,
			|	TU_ED.Company,
			|	TU_ED.Counterparty,
			|	TU_Certificates.CompanyInCertificate AS CompanyInCertificate,
			|	AgreementsED.IsIntercompany,
			|	CASE
			|		WHEN TU_ED.EDFProfileSettings.EDExchangeMethod IN (&ExchangeWithAuthorizationMethods)
			|			THEN TRUE
			|		ELSE FALSE
			|	END AS WantedAuthorization,
			|	CASE
			|		WHEN TU_ED.EDKind IN (&ServiceEDKinds)
			|			THEN ISNULL(TU_ED.ElectronicDocumentOwner.DigitallySigned, FALSE)
			|		ELSE TRUE
			|	END AS EDOwnerSigned,
			|	ISNULL(TU_Certificates.BankApplication, AgreementsED.BankApplication) AS BankApplication,
			|	TU_Certificates.Description AS NameOfCertificate,
			|	TU_ED.EDKind,
			|	TU_Certificates.CertificateData
			|INTO TU
			|FROM
			|	TU_Certificates AS TU_Certificates
			|		INNER JOIN TU_ED AS TU_ED
			|			INNER JOIN Catalog.EDUsageAgreements AS AgreementsED
			|			ON TU_ED.EDAgreement = AgreementsED.Ref
			|			LEFT JOIN Catalog.EDUsageAgreements.OutgoingDocuments AS AgreementsEDOutgoing
			|			ON TU_ED.EDAgreement = AgreementsEDOutgoing.Ref
			|			LEFT JOIN Catalog.EDAttachedFiles.DigitalSignatures AS ED_DS
			|			ON TU_ED.Ref = ED_DS.Ref
			|		ON (TU_ED.EDKind = TU_Certificates.DocumentKind)
			|			AND TU_Certificates.LinkToED = TU_ED.Ref
			|WHERE
			|	CASE
			|			WHEN AgreementsED.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
			|				THEN AgreementsED.CryptographyIsUsed
			|			WHEN AgreementsED.IsIntercompany
			|				THEN TRUE
			|			WHEN TU_ED.Ref.EDDirection = &DirectionIncoming
			|				THEN TU_ED.DigitallySigned
			|			WHEN TU_ED.Ref.EDDirection = &DirectionOutgoing
			|					AND Not TU_ED.EDKind IN (&ServiceEDKinds)
			|				THEN TU_ED.Ref.EDKind = AgreementsEDOutgoing.OutgoingDocument
			|						AND AgreementsEDOutgoing.ToForm
			|						AND AgreementsEDOutgoing.UseDS
			|						AND &UseDS
			|			WHEN TU_ED.EDKind IN (&ServiceEDKinds)
			|				THEN TU_ED.EDKind = TU_Certificates.DocumentKind
			|			ELSE FALSE
			|		END
			|	AND Not AgreementsED.DeletionMark
			|	AND CASE
			|			WHEN AgreementsED.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
			|				THEN AgreementsED.AgreementStatus = &AgreementStatus
			|			ELSE AgreementsED.ConnectionStatus = VALUE(Enum.EDExchangeMemberStatuses.Connected)
			|		END
			|	AND TU_ED.EDStatus IN(&StatusesArray)
			|	AND CASE
			|			WHEN TU_ED.Ref.EDDirection = &DirectionIncoming
			|					AND TU_ED.Ref.EDKind IN (&EDKindsAccountsInvoice)
			|				THEN FALSE
			|			ELSE TRUE
			|		END
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT DISTINCT
			|	TU.LinkToED,
			|	TU.EDExchangeMethod,
			|	TU.Company,
			|	TU.Counterparty,
			|	TU.IsIntercompany,
			|	TU.WantedAuthorization,
			|	TU.EDAgreement,
			|	TU.EDFProfileSettings,
			|	TU.EDOwnerSigned,
			|	TU.EDKind,
			|	TU.BankApplication
			|FROM
			|	TU AS TU
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	TU.LinkToED,
			|	TU.SignatureCertificate,
			|	TU.Imprint,
			|	TU.Revoked,
			|	TU.CompanyInCertificate AS Company,
			|	TU.CertificateData AS CertificateData,
			|	TU.BankApplication,
			|	TU.NameOfCertificate AS NameOfCertificate,
			|	FALSE AS PasswordReceived,
			|	UNDEFINED AS UserPassword
			|FROM
			|	TU AS TU
			|
			|ORDER BY
			|	NameOfCertificate
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	TU.LinkToED,
			|	TU.SetSignatures,
			|	Certificates.Company
			|FROM
			|	TU AS TU
			|		INNER JOIN Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
			|		ON TU.SetSignatures = Certificates.Imprint
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TU";
		
		StatusesArray = New Array;
		StatusesArray.Add(Enums.EDStatuses.Approved);
		StatusesArray.Add(Enums.EDStatuses.PartlyDigitallySigned);
		UseDS = GetFunctionalOptionValue("UseDigitalSignatures");
		Query.SetParameter("StatusesArray",       StatusesArray);
		Query.SetParameter("AgreementStatus",     Enums.EDAgreementsStatuses.Acts);
		Query.SetParameter("DirectionIncoming",  Enums.EDDirections.Incoming);
		Query.SetParameter("DirectionOutgoing", Enums.EDDirections.Outgoing);
		Query.SetParameter("ThumbprintArray",     ThumbprintArray);
		Query.SetParameter("CurrentUser",  Users.AuthorizedUser());
		Query.SetParameter("EmptyUser",   Catalogs.Users.EmptyRef());
		Query.SetParameter("UseDS",      UseDS);
		EDKindsArray = New Array;
		Query.SetParameter("EDKindsAccountsInvoice", EDKindsArray);
		ExchangeWithAuthorization = New Array;
		ExchangeWithAuthorization.Add(Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom);
		ExchangeWithAuthorization.Add(Enums.BankApplications.AsynchronousExchange);
		Query.SetParameter("ExchangeWithAuthorizationMethods", ExchangeWithAuthorization);
		ServiceEDKinds = New Array;
		ServiceEDKinds.Add(Enums.EDKinds.NotificationAboutReception);
		ServiceEDKinds.Add(Enums.EDKinds.NotificationAboutClarification);
		ServiceEDKinds.Add(Enums.EDKinds.CancellationOffer);
		Query.SetParameter("ServiceEDKinds", ServiceEDKinds);
		BankApplicationsList = New Array;
		BankApplicationsList.Add(Enums.BankApplications.iBank2);
		BankApplicationsList.Add(Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor);
		BankApplicationsList.Add(Enums.BankApplications.SberbankOnline);
		Query.SetParameter("BankApplicationsList", BankApplicationsList);
		
		Query.Text = MainQueryText +
			";
			 |////////////////
			 |" + QueryText;

		// After you approve some EDs, new ED is
		// generated in response, that is why send new ED for signing
		If TypeOf(ED) = Type("CatalogRef.EDAttachedFiles") Then
			EDKind = CommonUse.ObjectAttributeValue(ED, "EDKind");
			If (EDKind = Enums.EDKinds.ActPerformer
					OR EDKind = Enums.EDKinds.AgreementAboutCostChangeSender
					OR EDKind = Enums.EDKinds.TORG12Seller)
				AND ValueIsFilled(NewED) Then
				
				EDRefsArray = New Array;
				EDRefsArray.Add(NewED);
				Query.SetParameter("EDRefsArray", EDRefsArray);
			EndIf;
		EndIf;
		
		Result = Query.ExecuteBatch();
		AvailableCertificates = Result[2].Unload();
		VT_Certificates = Result[4].Unload();
		VT_SetSignatures = Result[5].Unload();
		Selection = Result[3].Select();
		VT_ED = New ValueTable;
		VT_ED.Columns.Add("LinkToED");
		VT_ED.Columns.Add("EDFProfileSettings");
		VT_ED.Columns.Add("SignatureCertificates");
		VT_ED.Columns.Add("WantedAuthorization");
		
		If VT_Certificates.Count() = 0 AND ValueIsFilled(ED) Then
			CryptographySettingsError = False;
			CertificateSetupError = False;
			If AvailableCertificates[0].Quantity > 0 Then
				EDFProfileSettings   = CommonUse.ObjectAttributeValue(ED,           "EDFProfileSettings");
				EDExchangeMethod = CommonUse.ObjectAttributeValue(EDFProfileSettings, "EDExchangeMethod");
				If EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
					MessagePattern = NStr("en='In EDF settings profile: %1 no available DS certificate is found.';ru='В профиле настроек ЭДО: %1 не найден ни один из доступных сертификатов ЭП.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, EDFProfileSettings);
					CommonUseClientServer.MessageToUser(MessageText);
				EndIf;
			ElsIf AdditParameters.Property("CryptographySettingsError", CryptographySettingsError)
				AND CryptographySettingsError Then
				MessageText = NStr("en='An error occurred while signing electronic document.
		|Check cryptography settings.';ru='Ошибка подписания электронного документа.
		|Проверьте настройки криптографии.'");
				CommonUseClientServer.MessageToUser(MessageText);                 
				
			ElsIf AdditParameters.Property("CertificateSetupError", CertificateSetupError)
				AND CertificateSetupError Then
				MessageText = NStr("en='An error occurred while signing electronic document.
		|Check certificates settings.';ru='Ошибка подписания электронного документа.
		|Проверьте настройки сертификатов.'");
				CommonUseClientServer.MessageToUser(MessageText);
	
			EndIf;
		EndIf;
		
		// To link ED, Agreement and Certificate, among others
		// match is needed, key of which is ref to ED, value - Agreement on exchange.
		// For example, 2 ED can be signed with 2
		// certificates (i.e. user should choose with which certificate they will sign these ED). EDs
		// correspond to different agreements (for example, one - is a direct exchange, another is - executed via operator) if a
		// user refuses to sign these EDs, then ED that corresponds to the agreement via operator should be
		// removed from the array for sending. For this you should find its agreement in the match (ED - Agreements), find this ED according
		// to the agreement in the match Agreements - Arrays ED for sending and delete the required ED from array.
		MatchEDAndAgreements = New Map;
		
		// Key - String (Amount UID certificates: String(Certificate1.UUID())
		// + String(Certificate2.UUID()) + ...), Value - Arrays structure
		// (CertificatesArray and EDArray).
		// The meaning of this structure is that to sign different EDs the
		// same set of certificates may be available. For example: GaSI can be signed with
		// Certificate1 and Certificate2 certificates, CIN can also be signed with Certificate1 and Certificate2 certificates
		// and GaSI is generated by agreement1 (direct exchange) and CIN - according to the agreement2 (via EDFO). INCORRECT ask a
		// user 2 times with which of the 2 certificates they want to sign documents,
		// therefore you should generate ED array for this pair of certificates. This pair of certificates is available to sign them.
		// To create a record in the unique structure and be able to search
		// for a new record by key, key is made as composed (in the query results, certificates are ordered by name).
		StructuStructuresEDArraysAndCertificates = New Structure;
		
		// If an immediate sending is set in the system and there is
		// the Send action, then you should select from the signed ED those EDs that require authorization (exchange via OEDO) and are signed on client.
		// For this VT_ED process in 2 passes (1- EDs that require authorization, 2-EDs that do not require authorization).
		AllocateEDToSendWithAuthorization = (ElectronicDocumentsClientServer.IsAction(Actions, "Send")
											AND ImmediateEDSending);
		
		If Selection.Count() > 0 Then
			While Selection.Next() Do
				LinkToED = Selection.LinkToED;
				Filter = New Structure("LinkToED", LinkToED);
				CopyOfVT = VT_Certificates.Copy(Filter);
				ImprintArrayExceptions = New Array;
				CertificatesArray = New Array;
				If Selection.IsIntercompany Then
					VT_Prints = VT_SetSignatures.Copy(Filter);
					If VT_Prints.Count() = 0 Then
						If CopyOfVT.Count() > 0 Then
							For Each StringCertificate IN CopyOfVT Do
								CertificateStructure = New Structure("SignatureCertificate,
									|BankApplication, PasswordReceived, UserPassword, Thumbprint, Revoked, CertificateData, RememberCertificatePassword");
								FillPropertyValues(CertificateStructure, StringCertificate);
								CertificatesArray.Add(StringCertificate.SignatureCertificate);
								ParametersInMatch = AccCertificatesAndTheirStructures.Get(StringCertificate.SignatureCertificate);
								If ParametersInMatch <> Undefined AND ParametersInMatch.PasswordReceived Then
									FillPropertyValues(CertificateStructure, ParametersInMatch, "PasswordReceived, UserPassword");
								EndIf;
								AccCertificatesAndTheirStructures.Insert(StringCertificate.SignatureCertificate, CertificateStructure);
							EndDo;
							NewRow = VT_ED.Add();
							NewRow.LinkToED = LinkToED;
							NewRow.EDFProfileSettings = Selection.EDFProfileSettings;
							NewRow.SignatureCertificates = CertificatesArray;
							NewRow.WantedAuthorization = Selection.WantedAuthorization;
							Company2Sides = ?(StringCertificate.Company = Selection.Company, Selection.Counterparty, Selection.Company);
							Filter.Insert("Company", Company2Sides);
							CopyOfVT = CopyOfVT.Copy(Filter);
						EndIf;
					Else
						ImprintArrayExceptions = VT_Prints.UnloadColumn("SetSignatures");
						VT_Prints.GroupBy("Company");
						ImprintRow = VT_Prints[0];
						If ValueIsFilled(ImprintRow.Company) Then
							Company2Sides = ?(ImprintRow.Company = Selection.Company, Selection.Counterparty, Selection.Company);
							Filter.Insert("Company", Company2Sides);
							CopyOfVT = CopyOfVT.Copy(Filter);
						EndIf;
					EndIf;
				ElsIf Selection.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource Then
					VT_Prints = VT_SetSignatures.Copy(Filter);
					If VT_Prints.Count() > 0 Then
						ImprintArrayExceptions = VT_Prints.UnloadColumn("SetSignatures");
					EndIf;
				EndIf;
				IsService = ThisIsServiceDocument(LinkToED);
				DSArrayID = "y";
				StandardSigning = True;
				If Selection.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource 
					AND (Selection.BankApplication = Enums.BankApplications.SberbankOnline
						OR Selection.BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
						OR Selection.BankApplication = Enums.BankApplications.iBank2) Then
					// Depending on agreement, to sign banking ED, you can use
					// algorithms that are different from the standard ones, that is why you should add agreements to UI identifier structure:
					StandardSigning = False;
					DSArrayID = DSArrayID + String(Selection.EDAgreement.UUID());
				EndIf;
				PasswordReceived = False;
				For Each StringCertificate IN CopyOfVT Do
					If ImprintArrayExceptions.Find(StringCertificate.Imprint) <> Undefined
						OR CertificatesArray.Find(StringCertificate.SignatureCertificate) <> Undefined Then
						Continue;
					EndIf;
					CertificatesArray.Add(StringCertificate.SignatureCertificate);
					DSArrayID = DSArrayID + String(StringCertificate.SignatureCertificate.UUID());
					
					CertificateStructure = New Structure("SignatureCertificate,
						|BankApplication, PasswordReceived, UserPassword, Thumbprint, Revoked, CertificateData, RememberCertificatePassword");
					FillPropertyValues(CertificateStructure, StringCertificate);
					ParametersInMatch = AccCertificatesAndTheirStructures.Get(StringCertificate.SignatureCertificate);
					If ParametersInMatch <> Undefined AND ParametersInMatch.PasswordReceived Then
						PasswordReceived = True;
						FillPropertyValues(CertificateStructure, ParametersInMatch, "PasswordReceived, UserPassword");
					EndIf;
					AccCertificatesAndTheirStructures.Insert(StringCertificate.SignatureCertificate, CertificateStructure);
					// If the service document is processed, it can be
					// signed with any certificate where password is saved.
					If IsService AND PasswordReceived Then
						CertificatesArray = New Array;
						CertificatesArray.Add(StringCertificate.SignatureCertificate);
						Break;
					EndIf;
				EndDo;
				If CertificatesArray.Count() > 0 Then
					DigitallySigned = 0;
					
					If Not Selection.EDOwnerSigned Then
						Continue;
					EndIf;
					
					If PasswordReceived AND (PerformCryptoOperationsAtServer
							OR Selection.EDKind = Enums.EDKinds.NotificationAboutReception AND ServerAuthorizationPerform) Then
						DigitallySigned = SignEDWithAppointedCertificate(LinkToED, CertificatesArray[0], CertificateStructure);
						If DigitallySigned > 0 Then
							DigitallySignedCnt = DigitallySignedCnt + DigitallySigned;
							// If EDs are signed, then to determine authorization certificate and
							// to send it, they will be received with the query in the next step (ED sending).
							Continue;
						EndIf;
					EndIf;
					NewRow = VT_ED.Add();
					NewRow.LinkToED = LinkToED;
					NewRow.EDFProfileSettings = Selection.EDFProfileSettings;
					NewRow.SignatureCertificates = CertificatesArray;
					NewRow.WantedAuthorization = Selection.WantedAuthorization;
					
					MatchEDAndAgreements.Insert(LinkToED, Selection.EDFProfileSettings);
					ArraysStructure = "";
					DSArrayID = StrReplace(DSArrayID, "-", "_");
					If Not StructuStructuresEDArraysAndCertificates.Property(DSArrayID, ArraysStructure)
						OR TypeOf(ArraysStructure) <> Type("Structure") Then
						StructuStructuresEDArraysAndCertificates.Insert(DSArrayID,
							New Structure("CertificatesArray", CertificatesArray));
						ArraysStructure = StructuStructuresEDArraysAndCertificates[DSArrayID];
					EndIf;
					If StandardSigning Then
						MatchEDAndDD = Undefined;
						If Not ArraysStructure.Property("MatchEDAndDD", MatchEDAndDD)
							OR TypeOf(MatchEDAndDD) <> Type("Map") Then
							ArraysStructure.Insert("MatchEDAndDD", New Map);
							MatchEDAndDD = ArraysStructure.MatchEDAndDD;
						EndIf;
						If CertificatesArray.Count() = 1 AND StandardSigning Then
							Value = PutToTempStorage(GetFileBinaryData(LinkToED, CertificatesArray[0]),
								LinkToED.UUID());
						Else
							Value = Undefined;
						EndIf;
						MatchEDAndDD.Insert(LinkToED, Value);
					Else
						DataForSpecProcessor = Undefined;
						If Not StructuStructuresEDArraysAndCertificates[DSArrayID].Property("DataForSpecProcessor",DataForSpecProcessor)
							OR TypeOf(DataForSpecProcessor) <> Type("Map") Then
							
							StructuStructuresEDArraysAndCertificates[DSArrayID].Insert("DataForSpecProcessor", New Map);
							DataForSpecProcessor = StructuStructuresEDArraysAndCertificates[DSArrayID].DataForSpecProcessor;
						EndIf;
						AgreementsANDED = DataForSpecProcessor.Get(Selection.BankApplication);
						If TypeOf(AgreementsANDED) <> Type("Map") Then
							DataForSpecProcessor.Insert(Selection.BankApplication, New Map);
							AgreementsANDED = DataForSpecProcessor[Selection.BankApplication];
						EndIf;
						BankEDArray = AgreementsANDED.Get(Selection.EDAgreement);
						If TypeOf(BankEDArray) <> Type("Array") Then
							AgreementsANDED.Insert(Selection.EDAgreement, New Array);
							BankEDArray = AgreementsANDED[Selection.EDAgreement];
						EndIf;
						BankEDArray.Add(LinkToED);
					EndIf;
					If AllocateEDToSendWithAuthorization AND Selection.WantedAuthorization Then
						// ED array will be signed according to the current certificate on client,
						// that is why you should try to send it after signing when you receive authorization certificate by ED agreement beforehand.
						EDKindsArray = CorrAgreementsArraysAndEDForDispatch.Get(Selection.EDFProfileSettings);
						If EDKindsArray = Undefined Then
							EDKindsArray = New Array;
						EndIf;
						If EDKindsArray.Find(LinkToED) = Undefined Then
							EDKindsArray.Add(LinkToED);
						EndIf;
						CorrAgreementsArraysAndEDForDispatch.Insert(Selection.EDFProfileSettings, EDKindsArray);
					Else
						// ED array by the current certificate is signed on client, therefore, after
						// signing you will have to prepare them for shipment and send if necessary.
						If StandardSigning Then
							For Each Item IN MatchEDAndDD Do
								If StructureToSend.WithSignature.Find(Item.Key) = Undefined Then
									StructureToSend.WithSignature.Add(Item.Key);
								EndIf;
							EndDo;
						Else
							For Each Item IN BankEDArray Do
								If StructureToSend.WithSignature.Find(Item) = Undefined Then
									StructureToSend.WithSignature.Add(Item);
								EndIf;
							EndDo;
						EndIf;
					EndIf;
				EndIf;
			EndDo;
		EndIf;
		
		If DigitallySignedCnt > 0 Then
			ReturnStructure.Insert("DigitallySignedCnt", DigitallySignedCnt);
		EndIf;
		If MatchEDAndAgreements.Count() > 0 Then
			ReturnStructure.Insert("MatchEDAndAgreements", MatchEDAndAgreements);
		EndIf;
		If StructuStructuresEDArraysAndCertificates.Count() > 0 Then
			ReturnStructure.Insert("StructuStructuresEDArraysAndCertificates", StructuStructuresEDArraysAndCertificates);
		EndIf;
	EndIf;
	
	// Send ED:
	
	AccAgreementsAndCertificatesOfAuthorization = New Map;
	ReturnStructure.Insert("AccAgreementsAndCertificatesOfAuthorization", AccAgreementsAndCertificatesOfAuthorization);
	
	SentCnt = 0;
	PreparedCnt = 0;
	If ElectronicDocumentsClientServer.IsAction(Actions, "Send") Then
		
		StCertificateStructuresArrays = New Structure("StampArrayClient", StampArrayClient);
		// Process ED arrays (generated at the stage of ED signing) that
		// will be signed later and for sending of which you need authorization certificates:
		If CorrAgreementsArraysAndEDForDispatch.Count() > 0 Then
			EDFSettingProfilesArray = New Array;
			For Each Item IN CorrAgreementsArraysAndEDForDispatch Do
				EDFSettingProfilesArray.Add(Item.Key);
			EndDo;
			AgreementsAndCertificatesAndParametersMatch = AgreementsAndCertificatesAndParametersMatchMatchForAuthorizationServer(
				EDFSettingProfilesArray,
				StCertificateStructuresArrays,
				CertificatesAndPasswordsMatch);
			// If there is authorization certificate, after you sign EDarray on client,
			// try to immediately send ED, otherwise, after signing pack ED and put in a queue for sending.
			For Each Item IN CorrAgreementsArraysAndEDForDispatch Do
				EDFProfileSettings = Item.Key;
				CertificatesAndParametersMatch = AgreementsAndCertificatesAndParametersMatch.Get(EDFProfileSettings);
				For Each KeyAndValue IN CertificatesAndParametersMatch Do
					CertificateStructure = KeyAndValue.Value;
					MarkerTranscribed = Undefined;
					MarkerEncrypted = Undefined;
					If TypeOf(CertificateStructure) = Type("Structure")
						AND (CertificateStructure.Property("MarkerTranscribed", MarkerTranscribed)
							OR CertificateStructure.Property("MarkerEncrypted", MarkerEncrypted))
						AND (ValueIsFilled(MarkerTranscribed) OR ValueIsFilled(MarkerEncrypted)) Then
						AccCertificatesAndTheirStructures.Insert(KeyAndValue.Key, CertificateStructure);
						CertificatesArray = AccAgreementsAndCertificatesOfAuthorization.Get(EDFProfileSettings);
						If CertificatesArray = Undefined Then
							CertificatesArray = New Array;
							AccAgreementsAndCertificatesOfAuthorization.Insert(EDFProfileSettings, CertificatesArray);
						EndIf;
						CertificatesArray.Add(KeyAndValue.Key);
					EndIf;
				EndDo;
			EndDo;
		EndIf;
		
		QueryText =
		"SELECT
		|	TU_ED.Ref AS LinkToED,
		|	TU_ED.EDStatus,
		|	TU_ED.EDFProfileSettings,
		|	AgreementsED.Ref AS EDAgreement,
		|	AgreementsEDOutgoing.EDExchangeMethod,
		|	CASE
		|		WHEN AgreementsEDOutgoing.EDExchangeMethod = &ExchangeMethodThroughOEDOLINE
		|				OR AgreementsEDOutgoing.Ref.BankApplication = VALUE(Enum.BankApplications.AsynchronousExchange)
		|					AND AgreementsEDOutgoing.Ref.CryptographyIsUsed
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS WantedAuthorization,
		|	CASE
		|		WHEN AgreementsED.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
		|				AND Not AgreementsED.CryptographyIsUsed
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS AuthorizationRequiredLoginPassword,
		|	CASE
		|		WHEN AgreementsEDOutgoing.EDExchangeMethod = &ExchangeMethodThroughOEDOLINE
		|				OR AgreementsED.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
		|					AND AgreementsED.CryptographyIsUsed
		|				OR AgreementsED.IsIntercompany
		|				OR TU_ED.EDDirection = &DirectionIncoming
		|					AND TU_ED.DigitallySigned
		|				OR TU_ED.EDDirection = &DirectionOutgoing
		|					AND AgreementsEDOutgoing.UseDS
		|					AND &UseDS
		|			THEN TRUE
		|		WHEN TU_ED.EDKind = VALUE(Enum.EDKinds.NotificationAboutReception)
		|				OR TU_ED.EDKind = VALUE(Enum.EDKinds.NotificationAboutClarification)
		|			THEN CASE
		|					WHEN ISNULL(EDEDOwner.DigitallySigned, FALSE)
		|						THEN Not TU_ED.DigitallySigned
		|					ELSE FALSE
		|				END
		|		ELSE FALSE
		|	END AS SignatureRequired,
		|	CASE
		|		WHEN AgreementsEDOutgoing.EDExchangeMethod <> &ExchangeMethodThroughOEDOLINE
		|				AND Not AgreementsED.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
		|				AND Not AgreementsED.IsIntercompany
		|				AND Not AgreementsED.CompanyCertificateForDetails = &EmptyReferenceToCertificate
		|				AND &UseDS
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS EncriptionRequired
		|FROM
		|	TU_ED AS TU_ED
		|		INNER JOIN Catalog.EDUsageAgreements AS AgreementsED
		|		ON TU_ED.EDAgreement = AgreementsED.Ref
		|		LEFT JOIN Catalog.EDUsageAgreements.OutgoingDocuments AS AgreementsEDOutgoing
		|		ON TU_ED.EDAgreement = AgreementsEDOutgoing.Ref
		|			AND TU_ED.EDKind = AgreementsEDOutgoing.OutgoingDocument
		|		LEFT JOIN Catalog.EDAttachedFiles AS EDEDOwner
		|		ON TU_ED.ElectronicDocumentOwner = EDEDOwner.Ref
		|WHERE
		|	CASE
		|			WHEN AgreementsEDOutgoing.EDExchangeMethod = &ExchangeMethodThroughOEDOLINE
		|					OR AgreementsED.IsIntercompany
		|					OR TU_ED.EDDirection = &DirectionIncoming
		|						AND TU_ED.DigitallySigned
		|					OR TU_ED.EDDirection = &DirectionOutgoing
		|						AND Not TU_ED.EDKind IN (&ServiceEDKinds)
		|						AND AgreementsEDOutgoing.UseDS
		|						AND &UseDS
		|						AND Not TU_ED.EDKind IN (&ServiceEDKinds)
		|				THEN TU_ED.EDStatus IN (&StatusesToSendWithSignature)
		|			WHEN TU_ED.EDDirection = &DirectionOutgoing
		|					AND Not AgreementsEDOutgoing.UseDS
		|					AND (&UseDS
		|						OR Not AgreementsED.CryptographyIsUsed)
		|				THEN TU_ED.EDStatus IN (&StatusesToBeSentWithoutSignatures)
		|			WHEN TU_ED.EDDirection = &DirectionIncoming
		|					AND Not TU_ED.DigitallySigned
		|				THEN TU_ED.EDStatus IN (&StatusesToBeSentWithoutSignatures)
		|			WHEN TU_ED.EDDirection = &DirectionOutgoing
		|					AND TU_ED.EDKind IN (&ServiceEDKinds)
		|				THEN CASE
		|						WHEN EDEDOwner.DigitallySigned
		|							THEN TU_ED.EDStatus IN (&StatusesToSendWithSignature)
		|						ELSE TU_ED.EDStatus IN (&StatusesToBeSentWithoutSignatures)
		|					END
		|			ELSE TU_ED.EDStatus IN (&StatusesToBeSentWithoutSignatures)
		|		END";
		StatusesArrayWithSignature = New Array;
		StatusesArrayWithSignature.Add(Enums.EDStatuses.DigitallySigned);
		
		StatusesArrayWithoutSignatures = New Array;
		StatusesArrayWithoutSignatures.Add(Enums.EDStatuses.Approved);
			
		If Actions = "Resend" Then
			StatusesArrayWithSignature.Add(Enums.EDStatuses.PreparedToSending);
			StatusesArrayWithoutSignatures.Add(Enums.EDStatuses.PreparedToSending);
			StatusesArrayWithSignature.Add(Enums.EDStatuses.Sent);
			StatusesArrayWithoutSignatures.Add(Enums.EDStatuses.Sent);
			StatusesArrayWithSignature.Add(Enums.EDStatuses.Delivered);
			StatusesArrayWithoutSignatures.Add(Enums.EDStatuses.Delivered);
			StatusesArrayWithSignature.Add(Enums.EDStatuses.TransferedToOperator);
			StatusesArrayWithoutSignatures.Add(Enums.EDStatuses.TransferedToOperator);
			StatusesArrayWithSignature.Add(Enums.EDStatuses.ReceivedOperatorConfirmation);
			StatusesArrayWithoutSignatures.Add(Enums.EDStatuses.ReceivedOperatorConfirmation);
		EndIf;
		
		UseDS = GetFunctionalOptionValue("UseDigitalSignatures");
		
		Query.SetParameter("ExchangeMethodThroughOEDOLINE",      Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom);
		Query.SetParameter("DirectionIncoming",        Enums.EDDirections.Incoming);
		Query.SetParameter("DirectionOutgoing",       Enums.EDDirections.Outgoing);
		Query.SetParameter("StatusesToBeSentWithoutSignatures", StatusesArrayWithoutSignatures);
		Query.SetParameter("StatusesToSendWithSignature",  StatusesArrayWithSignature);
		Query.SetParameter("UseDS",             UseDS);
		Query.SetParameter("EmptyReferenceToCertificate",
			Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef());
		ServiceEDKinds = New Array;
		ServiceEDKinds.Add(Enums.EDKinds.NotificationAboutReception);
		ServiceEDKinds.Add(Enums.EDKinds.NotificationAboutClarification);
		ServiceEDKinds.Add(Enums.EDKinds.CancellationOffer);
		Query.SetParameter("ServiceEDKinds", ServiceEDKinds);
		
		// After the incoming ED approval of the "Torg12Seller"
		// type, a new ED is generated that should be sent to the other side.
		
		If TypeOf(ED) = Type("CatalogRef.EDAttachedFiles") Then
			EDKind = CommonUse.ObjectAttributeValue(ED, "EDKind");
			If (EDKind = Enums.EDKinds.ActPerformer
					OR EDKind = Enums.EDKinds.AgreementAboutCostChangeSender
					OR EDKind = Enums.EDKinds.TORG12Seller)
				AND ValueIsFilled(NewED) Then
				
				EDRefsArray = New Array;
				EDRefsArray.Add(NewED);
				Query.SetParameter("EDRefsArray", EDRefsArray);
			EndIf;
		EndIf;
		
		Query.Text = MainQueryText 
						+ "
						|;
						|//////////
						|" + QueryText;

		Vt_Ed_ToBeSent = Query.Execute().Unload();
		
		SentCnt = 0;
		PreparedCnt = 0;
		If Vt_Ed_ToBeSent.Count() > 0 Then
			Vt_Ed_WithEncryption = Vt_Ed_ToBeSent.CopyColumns();
			If Not PerformCryptoOperationsAtServer Then
				// Copy ED to a separate table that need
				// to be encrypted on client and delete these rows from ED table for sending:
				Filter = New Structure("EncriptionRequired", True);
				Vt_Ed_WithEncryption = VT_ED_ToBeSent.Copy(Filter);
				Filter = New Structure("EncriptionRequired", False);
				Vt_Ed_ToBeSent = VT_ED_ToBeSent.Copy(Filter);
			EndIf;
			Filter = New Structure("SignatureRequired, AuthorizationRequiredLoginPassword", False, False);
			TempVT = Vt_Ed_ToBeSent.Copy(Filter);
			StructureToSend.Insert("WithoutSignatures", TempVT.UnloadColumn("LinkToED"));
			
			If Not ImmediateEDSending Then
				// If you use delayed sending, then authorization on EDFO server at this stage it is not required.
				// Therefore, ED passed via EDFO are passed to AER generating without authorization certificates.
				Filter = New Structure("SignatureRequired", True);
				TempVT = Vt_Ed_ToBeSent.Copy(Filter);
				ArrayOfDigitallySignedEDForDispatch = TempVT.UnloadColumn("LinkToED");
				For Each Item IN ArrayOfDigitallySignedEDForDispatch Do
					StructureToSend.WithSignature.Add(Item);
				EndDo;
				
				// For exchange with bank prepare pack for sending according to the login-password schema
				Filter = New Structure("AuthorizationRequiredLoginPassword", True);
				TempVT = Vt_Ed_ToBeSent.Copy(Filter);
				EDArrayForSendingPreparation = TempVT.UnloadColumn("LinkToED");
				For Each Item IN EDArrayForSendingPreparation Do
					StructureToSend.WithoutSignatures.Add(Item);
				EndDo;
			Else
				Filter = New Structure("AuthorizationRequired, SignatureRequired", False, True);
				TempVt = Vt_Ed_ToBeSent.Copy(Filter);
				ArrayOfDigitallySignedEDForDispatch = TempVt.UnloadColumn("LinkToED");
				For Each Item IN ArrayOfDigitallySignedEDForDispatch Do
					If StructureToSend.WithSignature.Find(Item) = Undefined Then
						StructureToSend.WithSignature.Add(Item);
					EndIf;
				EndDo;
				
				Filter = New Structure("WantedAuthorization", True);
				TempVt = Vt_Ed_ToBeSent.Copy(Filter);
				VtEDFProfileSettings = TempVt.Copy();
				VtEDFProfileSettings.GroupBy("EDFProfileSettings");
				EDFSettingProfilesArray = VtEDFProfileSettings.UnloadColumn("EDFProfileSettings");
				If EDFSettingProfilesArray.Count() > 0 Then
					AgreementsAndCertificatesMatchMatch = AgreementsAndCertificatesAndParametersMatchMatchForAuthorizationServer(
					                                                                 EDFSettingProfilesArray,
					                                                                 StCertificateStructuresArrays,
					                                                                 CertificatesAndPasswordsMatch);
				EndIf;
				// If there are decrypted markers by
				// the authorization certificates, send ED according to the given certificates.
				EDArrayToSendFromServer = New Array;
				LocalCorrAgreementsAndStructures = New Map;
				
				For Each EDFProfileSettings IN EDFSettingProfilesArray Do
					CertificatesMap = AgreementsAndCertificatesMatchMatch.Get(EDFProfileSettings);
					Filter = New Structure("EDFProfileSettings", EDFProfileSettings);
					TempVTByEDFProfileSettings = TempVt.Copy(Filter);
					If TempVTByEDFProfileSettings.Count() = 0 Then
						Continue;
					EndIf;
					EDKindsArray = TempVTByEDFProfileSettings.UnloadColumn("LinkToED");
					If CertificatesMap.Count() = 0 Then
						// If there is no authorization certificate, then pass ED array
						// for AER generation, then AER joins the sending queue (postponed sending).
						For Each LinkToED IN EDKindsArray Do
							StructureToSend.WithSignature.Add(LinkToED);
						EndDo;
						Continue;
					EndIf;
					
					SendingFromServer = False;
					For Each KeyAndValue IN CertificatesMap Do
						MarkerTranscribed = Undefined;
						MarkerEncrypted = Undefined;
						CertificateStructure = KeyAndValue.Value;
						If TypeOf(CertificateStructure) = Type("Structure")
							AND (CertificateStructure.Property("MarkerTranscribed", MarkerTranscribed)
								OR CertificateStructure.Property("MarkerEncrypted", MarkerEncrypted))
							AND (ValueIsFilled(MarkerTranscribed) OR ValueIsFilled(MarkerEncrypted)) Then
							Certificate = KeyAndValue.Key;
							If ValueIsFilled(MarkerTranscribed) Then
								For Each LinkToED IN EDKindsArray Do
									EDArrayToSendFromServer.Add(LinkToED);
								EndDo;
								LocalCorrAgreementsAndStructures.Insert(EDFProfileSettings, CertificateStructure);
								SendingFromServer = True;
								Break;
							Else
								AccCertificatesAndTheirStructures.Insert(Certificate, CertificateStructure);
								CertificatesArray = AccAgreementsAndCertificatesOfAuthorization.Get(EDFProfileSettings);
								If CertificatesArray = Undefined Then
									CertificatesArray = New Array;
									AccAgreementsAndCertificatesOfAuthorization.Insert(EDFProfileSettings, CertificatesArray);
								EndIf;
								CertificatesArray.Add(KeyAndValue.Key);
							EndIf;
						EndIf;
					EndDo;
					
					If SendingFromServer Then
						Continue;
					Else
						// There may be an array according to this agreement that wait for signature on client, ED.
						// This situation can take place when IB documents group with different
						// ED statuses (approved and signed) is selected in the documents journal. Then ED
						// array for signing comes from the previous stage (ED signing) in the agreements and
						// arrays match and in the current stage ED array for sending is generated.
						// Not to delete ED array for signature, add ED for sending to the existing array:
						EDExpectingSignatureArray = CorrAgreementsArraysAndEDForDispatch.Get(EDFProfileSettings);
						If EDExpectingSignatureArray = Undefined Then
							EDExpectingSignatureArray = New Array;
						EndIf;
						For Each ItemToBeSend IN EDKindsArray Do
							EDExpectingSignatureArray.Add(ItemToBeSend);
						EndDo;
						CorrAgreementsArraysAndEDForDispatch.Insert(EDFProfileSettings, EDExpectingSignatureArray);
					EndIf;
				EndDo;
				
				// Used to send documents to bank according to the login-password schema
				EDArrayForSendingFromServerWithoutSignature = New Array;
				Filter = New Structure("AuthorizationRequiredLoginPassword", True);
				TempVt = Vt_Ed_ToBeSent.Copy(Filter);
				AgreementsVT = TempVt.Copy();
				AgreementsVT.GroupBy("EDAgreement");
				AgreementsArray = AgreementsVT.UnloadColumn("EDAgreement");
				For Each EDAgreement IN AgreementsArray Do
					Filter = New Structure("EDAgreement", EDAgreement);
					TempVTByAgreement = TempVt.Copy(Filter);
					If TempVTByAgreement.Count() = 0 Then
						Continue;
					EndIf;
					EDKindsArray = TempVTByAgreement.UnloadColumn("LinkToED");
					If ValueIsFilled(CertificatesAndPasswordsMatch)
						AND Not CertificatesAndPasswordsMatch.Get(EDAgreement) = Undefined
						AND Not CommonUse.ObjectAttributeValue(EDAgreement, "BankApplication") = Enums.BankApplications.AsynchronousExchange Then
						LocalCorrAgreementsAndStructures.Insert(EDAgreement, CertificatesAndPasswordsMatch.Get(EDAgreement));
						CommonUseClientServer.SupplementArray(EDArrayForSendingFromServerWithoutSignature, EDKindsArray);
					Else
						EDArraysAndAgreementsMatchForSendingWithAuthorization.Insert(EDAgreement, EDKindsArray);
					EndIf;
				EndDo;
				
				If EDArrayForSendingFromServerWithoutSignature.Count() > 0 Then
					StResult = CreateAndSendDocumentsPED(
						EDArrayForSendingFromServerWithoutSignature, False, LocalCorrAgreementsAndStructures);
					SentCnt = SentCnt + StResult.SentCnt;
					PreparedCnt = PreparedCnt + StResult.PreparedCnt;
				EndIf;
				
				If EDArrayToSendFromServer.Count() > 0 Then
					StResult = CreateAndSendDocumentsPED(EDArrayToSendFromServer, True, LocalCorrAgreementsAndStructures);
					SentCnt = SentCnt + StResult.SentCnt;
					PreparedCnt = PreparedCnt + StResult.PreparedCnt;
				EndIf;
			EndIf;
			For Each Item IN StructureToSend Do
				SignatureSign = (Item.Key = "WithSignature");
				EDKindsArray = Item.Value;
				If TypeOf(EDKindsArray) = Type("Array") AND EDKindsArray.Count() > 0 Then
					StResult = CreateAndSendDocumentsPED(EDKindsArray, SignatureSign);
					SentCnt = SentCnt + StResult.SentCnt;
					PreparedCnt = PreparedCnt + StResult.PreparedCnt;
				EndIf;
				EDKindsArray = New Array;
				// Add EDs to structure that should be encrypted on client:
				If VT_ED_WithEncryption.Count() > 0 Then
					Filter = New Structure("SignatureRequired", SignatureSign);
					TempVT = VT_ED_WithEncryption.Copy(Filter);
					EDKindsArray = TempVT.UnloadColumn("LinkToED");
				EndIf;
				StructureToSend.Insert(Item.Key, EDKindsArray);
			EndDo;
		EndIf;
		StructureToSend.Insert("WithAuthorization", CorrAgreementsArraysAndEDForDispatch);
		StructureToSend.Insert("WithAuthorizationLoginPassword", EDArraysAndAgreementsMatchForSendingWithAuthorization);
		
		ReturnStructure.Insert("SentCnt", SentCnt);
		ReturnStructure.Insert("PreparedCnt", PreparedCnt);
		ReturnStructure.Insert("StructureToSend", StructureToSend);
	EndIf;
	
	If Not ValueIsFilled(RefsToObjectArray) Then
		AdditParameters.Insert("ISProcessedED",
			(NewEDCnt + ConfirmedCntED + DigitallySignedCnt + PreparedCnt + SentCnt) > 0);
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

// For internal use only
Function SendAndReceiveDocuments(AccAgreementsAndStructuresOfCertificates, Readmission = False) Export
	
	ReturnStructure = New Structure;
	If Not Readmission Then
		SentPackagesCnt = ElectronicDocumentsService.SendingCompletedED(
													AccAgreementsAndStructuresOfCertificates);
		ReturnStructure.Insert("SentPackagesCnt", SentPackagesCnt);
	EndIf;
	
	NewDocuments = ElectronicDocumentsService.GetNewED(
												AccAgreementsAndStructuresOfCertificates,
												Readmission);
	ReturnStructure.Insert("NewDocuments", NewDocuments);
	
	// If the marker has lost relevance (more than 5 minutes
	// have passed since it was received), receive it again to decrypt on client.
	If Readmission Then
		For Each Item IN AccAgreementsAndStructuresOfCertificates Do
			Item.Value.Insert("MarkerEncrypted", EncryptedMarker(Item.Value));
		EndDo
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

// Processes documents confirmation consisting of an electronic digital signature.
//
// Parameters:
//  MapFileParameters - Match connecting the data attachment file names and attachment file names of
//                              digital signatures to them.
//  PackageEDRef - DocumentRef.EDPack, reference to electronic documents pack containing confirmation.
//  PackageFiles - Map - pack files
//     data * Key - String - pack file
//     name * Value - String - ref to the binary data
//  storage of the EDAndSignaturesDataArray file - Array, array items is a structure containing a ref to ED
//                            and signature binary data for further data processor on client
//
Function ProcessDocumentsConfirmationsAtServer(
				MapFileParameters,
				PackageEDRef,
				PackageFiles,
				EDAndSignaturesDataArray = Undefined) Export
	
	SetPrivilegedMode(True);
	EDAndSignaturesDataArray = New Array;
	
	ReturnArray = New Array;
	PackageEDObject = PackageEDRef.GetObject();
	// Try to obtain cryptography settings.
	PerformCryptoOperationsAtServer = PerformCryptoOperationsAtServer();
	
	If PerformCryptoOperationsAtServer Then
		Cancel = False;
		CryptoManager = GetCryptoManager(Cancel);
		If Cancel Then
			MessageText = BriefErrorDescription(ErrorInfo())
				+ NStr("en=' (see details in Event log monitor).';ru=' (подробности см. в Журнале регистрации).'");
			ErrorText = DetailErrorDescription(ErrorInfo());
			ProcessExceptionByEDOnServer(NStr("en='ED confirmation processing';ru='обработка подтверждений ЭД'"), ErrorText, MessageText);
			Return ReturnArray;
		EndIf;
	EndIf;
	
	// Consider signature without file to be confirmation (according to - key with signature file)
	For Each ItemMap IN MapFileParameters Do
		If Find(ItemMap.Key, ".p7s") > 0 Then
			RequiredDocumentDirection = Enums.EDDirections.Outgoing;
			
			FileReference = PackageFiles.Get(ItemMap.Key);
			
			If FileReference = Undefined Then
				Continue;
			EndIf;
			
			BinaryDataSignatures = GetFromTempStorage(FileReference);
			
			UniqueId = Undefined;
			If Not ItemMap.Value.Property("EDTINumber", UniqueId) Then
				ItemMap.Value.Property("UniqueId", UniqueId);
			EndIf;
			SearchParametersStructure = New Structure;
			SearchParametersStructure.Insert("UniqueId",        UniqueId);
			SearchParametersStructure.Insert("EDDirection",       RequiredDocumentDirection);
			TransactionCode = "";
			If ItemMap.Value.Property("TransactionCode", TransactionCode)
				AND TransactionCode = "CancellationOfferResign" Then
				SearchParametersStructure.Insert("EDKind", Enums.EDKinds.CancellationOffer);
			Else
				SearchParametersStructure.Insert("VersionPointTypeED", Enums.EDVersionElementTypes.PrimaryED);
			EndIf;
			ElectronicDocument = ElectronicDocumentsService.DetermineElectronicDocument(SearchParametersStructure);
			If Not ValueIsFilled(ElectronicDocument) AND TypeOf(ItemMap.Value) = Type("Structure")
				AND ItemMap.Value.Property("RegulationsCode") AND StrLen(UniqueId) = 36 Then
				ElectronicDocument = Catalogs.EDAttachedFiles.GetRef(New UUID(UniqueId));
			EndIf;
			
			If Not ValueIsFilled(ElectronicDocument) OR ElectronicDocument.GetObject() = Undefined
				OR ElectronicDocumentsService.IsSuchSignature(BinaryDataSignatures, ElectronicDocument) Then
				Continue;
			EndIf;
			
			CurrentDocumentsAddress = ElectronicDocumentsService.GetFileData(ElectronicDocument).FileBinaryDataRef;
			DocumentBinaryData = GetFromTempStorage(CurrentDocumentsAddress);
			
			If PerformCryptoOperationsAtServer Then
				// Determine cryptography certificates from signature.
				SignatureCertificates = CryptoManager.GetCertificatesFromSignature(BinaryDataSignatures);
				If SignatureCertificates.Count() <> 0 Then
					Certificate = SignatureCertificates[0];
					SignatureInstallationDate = ElectronicDocumentsService.SignatureInstallationDate(BinaryDataSignatures);
					SignatureInstallationDate = ?(ValueIsFilled(SignatureInstallationDate), SignatureInstallationDate, CurrentSessionDate());
					PrintBase64 = Base64String(Certificate.Imprint);
					UserPresentation = DigitalSignatureClientServer.SubjectPresentation(Certificate);
					AddInformationAboutSignature(
													ElectronicDocument,
													BinaryDataSignatures,
													PrintBase64,
													SignatureInstallationDate,
													"",
													ItemMap.Key,
													UserPresentation,
													Certificate.Unload());
				EndIf;
				DetermineSignaturesStatuses(ElectronicDocument);
			Else
				EDStructureAndSignatureData = New Structure;
				EDStructureAndSignatureData.Insert("ElectronicDocument", ElectronicDocument);
				EDStructureAndSignatureData.Insert("SignatureData",       BinaryDataSignatures);
				EDAndSignaturesDataArray.Add(EDStructureAndSignatureData);
			EndIf;
			
			Try
				BeginTransaction();
				
				
				NewEDStatus = ElectronicDocumentsService.GetAdmissibleEDStatus(
																		Enums.EDStatuses.ConfirmationReceived,
																		ElectronicDocument);
				ParametersStructure = New Structure("EDStatus", NewEDStatus);
				ElectronicDocumentsService.ChangeByRefAttachedFile(ElectronicDocument, ParametersStructure, False);
																						 
																						 
				EDOwner = CommonUse.ObjectAttributeValue(ElectronicDocument, "FileOwner");
				If TypeOf(EDOwner) = Type("DocumentRef.RandomED") Then
					RandomEDObject = EDOwner.GetObject();
					RandomEDObject.DocumentStatus = NewEDStatus;
					RandomEDObject.Write();
				EndIf;
				CommitTransaction();
			Except
				RollbackTransaction();
				MessageText = BriefErrorDescription(ErrorInfo())
					+ NStr("en=' (see details in Event log monitor).';ru=' (подробности см. в Журнале регистрации).'");
				ErrorText = DetailErrorDescription(ErrorInfo());
				ProcessExceptionByEDOnServer(NStr("en='ED confirmation receipt';ru='получение подтверждения ЭД'"), ErrorText, MessageText);
			EndTry;
			
			EDPackageRow = PackageEDObject.ElectronicDocuments.Add();
			EDPackageRow.ElectronicDocument = "Confirmation";
			EDPackageRow.OwnerObject = EDOwner;
			ReturnArray.Add(EDOwner);
		EndIf;
	EndDo;
	PackageEDObject.PackageStatus = Enums.EDPackagesStatuses.Unpacked;
	PackageEDObject.Write();
	
	Return ReturnArray;
	
EndFunction

// Returns structure containing information about counterparty legal address.
//
// Parameters:
//  ParametersStructure - structure - contains references to catalog items.;
//  CounterpartyKind      - String - Catalog metadata name;
//  AddressKind           - String - Fact or Legal;
//  ErrorText         - String - error description;
//
// Returns:
//  StructureOfAddress - structure - information about legal address.
//
Function GetAddressAsStructure(ParametersStructure = Undefined,
								CounterpartyKind = Undefined,
								AddressKind = Undefined,
								ErrorText = "") Export
	
	StructureOfAddress = New Structure;
	// Structure field for RF address.
	StructureOfAddress.Insert("AddressRF");
	StructureOfAddress.Insert("IndexOf");
	StructureOfAddress.Insert("CodeState");
	StructureOfAddress.Insert("District");
	StructureOfAddress.Insert("City");
	StructureOfAddress.Insert("Settlement");
	StructureOfAddress.Insert("Street");
	StructureOfAddress.Insert("Building");
	StructureOfAddress.Insert("Section");
	StructureOfAddress.Insert("Qart");
	// Structure fields for the foreign address or RF address as a string.
	StructureOfAddress.Insert("StrCode");
	StructureOfAddress.Insert("AdrText");
	ElectronicDocumentsOverridable.GetAddressAsStructure(StructureOfAddress, ParametersStructure, CounterpartyKind,
		AddressKind, ErrorText);
	
	Return StructureOfAddress;
	
EndFunction

// Checks whether there are
// company catalog items and returns item if there is only one.
//
// Parameters:
//  Company - CatalogRef.Companies - ref to the catalog
//                single item Companies Undefined - if there are no companies or there are several ones
//
Procedure DetermineCompany(Company) Export
	
	DescriptionCompanyCatalog = ElectronicDocumentsReUse.GetAppliedCatalogName("Companies");
	
	If Not ValueIsFilled(DescriptionCompanyCatalog) Then
		DescriptionCompanyCatalog = "Companies";
	EndIf;

	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Companies.Ref
	|FROM
	|	Catalog."+DescriptionCompanyCatalog+" AS Companies";
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		If Selection.Count() = 1 Then
			Selection.Next();
			Company = Selection.Ref;
		EndIf;
	EndIf;
	
EndProcedure

// It finds a reference to IB object by the type, ID and additional attributes
// 
// Parameters:
//  ObjectType - String, identifier of the object
//  type to be found, ObjectID - String, object identifier of
//  the specified type, AdditionalAttributes - Structure, set of object additional fields for searching.
//
Function FindRefToObject(ObjectType,
							IDObject = "",
							AdditionalAttributes = Undefined,
							IDED = Undefined) Export
	
	Result = ElectronicDocumentsOverridable.FindRefToObject(ObjectType,
																		 IDObject,
																		 AdditionalAttributes,
																		 IDED);

EndFunction

// It fills the storage address with the value table - products directory
//
// Parameters:
//  AddressInTemporaryStorage - product catalog storage address;
//  FormID - unique  identifier of the form that called the function.
//
Procedure PutGoodsCatalogIntoTemporaryStorage(AddressInTemporaryStorage, FormID) Export
	
	ElectronicDocumentsOverridable.PutGoodsCatalogIntoTemporaryStorage(
												AddressInTemporaryStorage,
												FormID);
	
EndProcedure

// It changes the behavior of the controlled or standard form items.
//
// Parameters:
//  Form - <Managed or standard form> - managed or standard form to be changed.
//  ParametersStructure - <Structure> - procedure parameters
//
Procedure ChangeFormItemsProperties(Form, ParametersStructure) Export
	
	ElectronicDocumentsOverridable.ChangeFormItemsProperties(Form, ParametersStructure)
	
EndProcedure

// Returns text of message to user about the need of system settings.
//
// Parameters:
//  <OperationKind> - String - sign of the performed operation
//
// Returns:
//  MessageText - <String> - Message string
//
Function MessageTextAboutSystemSettingRequirement(OperationKind) Export
	
	MessageText = "";
	ElectronicDocumentsOverridable.MessageTextAboutSystemSettingRequirement(OperationKind, MessageText);
	If Not ValueIsFilled(MessageText) Then
		If Upper(OperationKind) = "WorkWithED" Then
			MessageText = NStr("en='To work with electronic documents,
		|it is required to enable elecronic documents exchange in the system settings.';ru='Для работы с электронными
		|документами необходимо в настройках системы включить использование обмена электронными документами.'");
		ElsIf Upper(OperationKind) = "SigningOfED" Then
			MessageText = NStr("en='To sign ED, it
		|is required to enable option of using electronic digital signatures in the system settings.';ru='Для возможности
		|подписания ЭД необходимо в настройках системы включить опцию использования электронных цифровых подписей.'");
		ElsIf Upper(OperationKind) = "SettingCryptography" Then
			MessageText = NStr("en='To configure cryptography, enable the option of digital signature usage in the application settings.';ru='Для возможности настройки криптографии необходимо в настройках системы включить опцию использования электронных цифровых подписей.'");
		ElsIf Upper(OperationKind) = "BANKOPERATIONS" Then
			MessageText = NStr("en='To exchange ED with banks, select the option of direct interaction with banks in the application settings.';ru='Для возможности обмена ЭД с банками необходимо в настройках системы включить опцию использования прямого взаимодействия с банками.'");
		ElsIf Upper(OperationKind) = "ADDITIONALREPORTSANDDATAPROCESSORS" Then
			MessageText = NStr("en='For possibility of a direct exchange with the
		|bank via additional data processor it is required to enable the option of additional reports and data processors usage in system settings.';ru='Для возможности прямого обмена с
		|банком через дополнительную обработку необходимо в настройках системы включить опцию использования дополнительных отчетов и обработок.'");
		Else
			MessageText = NStr("en='Operation cannot be performed. Required application settings are not executed.';ru='Операция не может быть выполнена. Не выполнены необходимые настройки системы.'");
		EndIf;
	EndIf;
	
	Return MessageText;
	
EndFunction

// Returns - Number (number of processed documents)
Function HandleBinaryDataPackageOperatorOfEDO(EDPackage, UnpackingData, IsCryptofacilityOnClient, AccordanceOfEdAndSignatures, ReturnStructure) Export
	
	Return ElectronicDocumentsInternal.HandleBinaryDataPackageOperatorOfEDO(
		EDPackage, UnpackingData, IsCryptofacilityOnClient, AccordanceOfEdAndSignatures, ReturnStructure);
	
EndFunction

// Gets values table with data by electronic documents.
//
// Parameters:
// RefsArrayToOwners - array of references to e-document owners which data it is required to get.
//
Function GetDataEDByOwners(RefsArrayToOwners) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDStates.ObjectReference AS EDOwner,
	|	EDStates.EDVersionState AS EDVersionState,
	|	EDStates.ActionsFromOurSide AS ActionsFromOurSide,
	|	EDStates.ActionsFromOtherPartySide AS ActionsFromOtherPartySide
	|FROM
	|	InformationRegister.EDStates AS EDStates
	|WHERE
	|	EDStates.ObjectReference IN(&RefsArrayToOwners)";
	
	Query.SetParameter("RefsArrayToOwners", RefsArrayToOwners);
	Result = Query.Execute().Unload();
	
	Return Result;
	
EndFunction

// It fills the form attributes by the passed values 
//
// Parameters:
//  FormData - Managed form data;
//  FillValue - references for the data in a temporary storage.
//
Procedure FillSource(FormData, ReturnValue) Export
	
	ElectronicDocumentsOverridable.FillSource(FormData, ReturnValue);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Direct exchange with bank

Function StatementsQueries(Val EDFSetup, Val StartDate, Val EndDate, Val AccountNo, CertificateTumbprintsArray, ExchangeSettings) Export
	
	EDFSettingAttributes = CommonUse.ObjectAttributesValues(
		EDFSetup, "Company, Counterparty, BankApplication, CompanyID");
	
	BankAccountsArray = New Array;
	If ValueIsFilled(AccountNo) Then
		BankAccountsArray.Add(AccountNo);
	Else
		ElectronicDocumentsOverridable.GetBankAccountNumbers(
			EDFSettingAttributes.Company, EDFSettingAttributes.Counterparty, BankAccountsArray);
	EndIf;
		
	If EDFSettingAttributes.BankApplication = Enums.BankApplications.AlphaBankOnline Then
		EDKindsArray = StatementQueriesArray(EDFSetup, EDFSettingAttributes.Company, EDFSettingAttributes.Counterparty,
										StartDate, EndDate, BankAccountsArray);
	Else
		EDKindsArray = StatementQueriesArrayAsync(EDFSetup, EDFSettingAttributes.Company,
			EDFSettingAttributes.Counterparty, EDFSettingAttributes.CompanyID, StartDate, EndDate,
			BankAccountsArray);
	EndIf;
		
	If Not EDKindsArray.Count() Then
		Return EDKindsArray;
	EndIf;
	
	PerformCryptoOperationsAtServer = PerformCryptoOperationsAtServer();
	
	If PerformCryptoOperationsAtServer Then
		Try
			CertificateTumbprintsArray = CertificateTumbprintsArray();
		Except
			CertificateTumbprintsArray = New Array;
		EndTry;
	EndIf;
	
	ExchangeSettings = ElectronicDocumentsService.DetermineEDExchangeSettingsBySource(
					EDFSetup, True, CertificateTumbprintsArray, EDKindsArray[0]);
	
	Return EDKindsArray;
	
EndFunction

Function BankCertificatesData(EDAgreement) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ESCertificates.Ref AS Certificate,
	|	ESCertificates.CertificateData,
	|	FALSE AS RememberCertificatePassword,
	|	UNDEFINED AS UserPassword,
	|	EDUsageAgreements.BankApplication AS BankApplication
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|		LEFT JOIN Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsEDCertificatesDS
	|			INNER JOIN Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS ESCertificates
	|			ON AgreementsEDCertificatesDS.Certificate = ESCertificates.Ref
	|		ON (EDUsageAgreements.Ref = &EDAgreement)
	|			AND AgreementsEDCertificatesDS.Ref = EDUsageAgreements.Ref
	|WHERE
	|	(ESCertificates.User = &CurrentUser
	|			OR ESCertificates.User = &EmptyUser)";
	Query.SetParameter("EDAgreement", EDAgreement);
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("EmptyUser", Catalogs.Users.EmptyRef());
	QueryResult = Query.Execute();
	CertificatesSelection = QueryResult.Select();
	CertificatesData = New Array;
	While CertificatesSelection.Next() Do
		CertificateData = New Structure(
			"Certificate, CertificateBinaryData, RememberCertificatePassword, UserPassword, BankApplication, PasswordReceived");
		FillPropertyValues(CertificateData, CertificatesSelection);
		CertificateData.CertificateBinaryData = CertificatesSelection.CertificateData.Get();
		CertificateData.PasswordReceived = CertificateData.RememberCertificatePassword;
		CertificatesData.Add(CertificateData);
	EndDo;
	
	Return CertificatesData;
	
EndFunction

//Executes data serialization
//
// Parameters:
// Value - Arbitrary - data for serialization
//
// Returns:
//  String - serialized data
//
Function SerializedData(Val Value) Export

	If Value = Undefined Then
		Return Undefined;
	EndIf;

	Serializer = New XDTOSerializer(XDTOFactory);
	XDTODataObject = Serializer.WriteXDTO(Value);
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XDTOFactory.WriteXML(XMLWriter, XDTODataObject);

	Return XMLWriter.Close();

EndFunction

//Deserializes data
//
// Parameters:
// XMLPresentation - String - serialized data
//
// Returns:
//  Arbitrary - deserialized data
//
Function DeSerializedData(Val XMLPresentation) Export

	XMLReader = New XMLReader;
	XMLReader.SetString(XMLPresentation);
	XMLReader.Read();

	Serializer = New XDTOSerializer(XDTOFactory);
	Return Serializer.ReadXML(XMLReader);
	
EndFunction

// Processes bank response to the payment documents sending
//
// Parameters
//  EDPacks - Map - in key ref to the
//  document EDPack ResponseData  - Map - bank response data
//
Procedure ProcessBankResponse(Val EDPackages, Val ResponseData) Export
	
	For Each Response IN ResponseData Do
		
		Try
			BeginTransaction();
			ParametersStructure = New Structure;
			If ValueIsFilled(Response.Value.ID) Then
				If Response.Value.Status = "30" Then
					ParametersStructure.Insert("EDStatus", Enums.EDStatuses.Sent);
				Else
					ParametersStructure.Insert("EDStatus", Enums.EDStatuses.Delivered);
				EndIf;
				ParametersStructure.Insert("UUIDExternal", Response.Value.ID);
			Else
				ParametersStructure.Insert("EDStatus", Enums.EDStatuses.RejectedByBank);
				ParametersStructure.Insert("RejectionReason", Response.Value.ErrorText);
			EndIf;
			ED = Catalogs.EDAttachedFiles.GetRef(Response.Key);
			ElectronicDocumentsService.ChangeByRefAttachedFile(ED, ParametersStructure, False);
			CommitTransaction();
		Except
			RollbackTransaction();
		EndTry;
	
	EndDo;
	
	CurrentSessionDate = CurrentSessionDate();
	
	For Each Item IN EDPackages Do
		ElectronicDocumentsService.UpdateEDPackageDocumentsStatuses(
			Item.Key, Enums.EDPackagesStatuses.Sent, CurrentSessionDate);
	EndDo;

EndProcedure

// Transfers items from EDArray that are related to the exchange with bank
//and require specific data processor in EDBankArray
//
// Parameters:
// EDKindsArray - Array - contains refs to
// the DataForSpecDataProcessor electronic documents - Map - contains ED banks arrays for a special data processor
//
Procedure SeparateEDForSpecialDataProcessor(EDKindsArray, DataForSpecProcessor) Export
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	EDAttachedFiles.Ref AS ED
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.Ref IN(&EDKindsArray)
	|	AND Not(EDAttachedFiles.EDAgreement.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
	|				AND EDAttachedFiles.EDAgreement.BankApplication IN (VALUE(Enum.BankApplications.SberbankOnline), VALUE(Enum.BankApplications.iBank2), VALUE(Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor)))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EDAttachedFiles.Ref AS ED,
	|	EDAttachedFiles.EDAgreement.BankApplication AS BankApplication,
	|	EDAttachedFiles.EDAgreement AS EDAgreement
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.Ref IN(&EDKindsArray)
	|	AND EDAttachedFiles.EDAgreement.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
	|	AND EDAttachedFiles.EDAgreement.BankApplication IN (VALUE(Enum.BankApplications.SberbankOnline), VALUE(Enum.BankApplications.iBank2), VALUE(Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor))
	|TOTALS BY
	|	BankApplication,
	|	EDAgreement";
	
	Query.SetParameter("EDKindsArray", EDKindsArray);
	
	QueryResult = Query.ExecuteBatch();
	
	EDKindsArray = QueryResult[0].Unload().UnloadColumn("ED");
	BankApplicationsSelection = QueryResult[1].Select(QueryResultIteration.ByGroups);
	DataForSpecProcessor = New Map;
	AgreementsANDED = New Map;
	While BankApplicationsSelection.Next() Do
		AgreementsSelection = BankApplicationsSelection.Select(QueryResultIteration.ByGroups);
		While AgreementsSelection.Next() Do
			ArraySpecED = New Array;
			SelectionSpecED = AgreementsSelection.Select();
			While SelectionSpecED.Next() Do
				ArraySpecED.Add(SelectionSpecED.ED);
			EndDo;
			AgreementsANDED.Insert(AgreementsSelection.EDAgreement, ArraySpecED);
		EndDo;
		DataForSpecProcessor.Insert(BankApplicationsSelection.BankApplication, AgreementsANDED);
	EndDo;
	
EndProcedure

// Changes status and state of executed payment orders by the bank statement
//
// Parameters:
//  EDStatement - CatalogRef.EDAttachedFiles - bank statement electronic document,
//
Procedure DeterminePerformedPaymentOrders(Val EDStatement) Export
	
	ExternalIdentifiersArray = IdentifiersArrayBankStatements(EDStatement);
	
	BankApplication = CommonUse.ObjectAttributeValue(EDStatement.EDAgreement, "BankApplication");
	
	If BankApplication = Enums.BankApplications.AlphaBankOnline
		OR BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
		OR BankApplication = Enums.BankApplications.iBank2 Then
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	EDAttachedFiles.Ref
		|FROM
		|	Catalog.EDAttachedFiles AS EDAttachedFiles
		|WHERE
		|	EDAttachedFiles.UUIDExternal IN (&ArrayOfIDs)
		|	AND EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.PaymentOrder)
		|	AND EDAttachedFiles.EDAgreement = &EDAgreement";
		Query.SetParameter("ArrayOfIDs", ExternalIdentifiersArray);
		Query.SetParameter("EDAgreement", CommonUse.ObjectAttributeValue(EDStatement, "EDAgreement"));
		TabED = Query.Execute().Unload();
		For Each RowED IN TabED Do
			ParametersStructure = New Structure("EDStatus", Enums.EDStatuses.Executed);
			ElectronicDocumentsService.ChangeByRefAttachedFile(RowED.Ref, ParametersStructure, False);
		EndDo;
	Else
		For Each ID IN ExternalIdentifiersArray Do
			If Not ValueIsFilled(ID) Then
				Continue;
			EndIf;
			Try
				DocumentID = New UUID(ID);
			Except
				Continue;
			EndTry;
			ED = Catalogs.EDAttachedFiles.GetRef(DocumentID);
			If ED.GetObject() <> Undefined Then
				SetEDStatus(ED, Enums.EDStatuses.Confirmed);
			EndIf;
		EndDo
	EndIf
		
EndProcedure

Function BankExternalComponentAddress(BankApplication) Export
	
	If BankApplication = PredefinedValue("Enum.BankApplications.SberbankOnline") Then
		TemplateName = "infocrypt_sbrf_native";
	ElsIf BankApplication = PredefinedValue("Enum.BankApplications.iBank2") Then
		TemplateName = "iBank2Library";
	Else
		TemplateName = "SBRFServiceProxy";
	EndIf;
	TemplateEC = DataProcessors.ElectronicDocumentsExchangeWithBank.GetTemplate(TemplateName);
	Return PutToTempStorage(TemplateEC, New UUID);

EndFunction

// Returns Base64 string containing string data as binary file data as UTF8 without BOM.
//
// Parameters:
//  DataRow  - String - String of conversion to BASE64
//
// Returns:
//   String   - String in BASE64
//
Function Base64StringWithoutBOM(DataRow) Export

	TempFile = GetTempFileName();
	TextDocument = New TextDocument;
	TextDocument.SetText(DataRow);
	TextDocument.Write(TempFile, TextEncoding.UTF8, Chars.LF);
	BinaryData = New BinaryData(TempFile);
	FormatStringBase64 = Base64String(BinaryData);
	FormatStringBase64 = Mid(FormatStringBase64, 5); // remove BOM
	FormatStringBase64 = StrReplace(FormatStringBase64, Chars.CR, ""); // remove EC
	FormatStringBase64 = StrReplace(FormatStringBase64, Chars.LF, ""); // remove PS
	DeleteFiles(TempFile);
	Return FormatStringBase64;

EndFunction

// Gets EDF valid settings list with banks. If parameters are not passed, returns all settings
//
// Parameters:
//  Company  - CatalogRef.Companies - company
//  in the Bank setting  - CatalogRef.RFBankClassifier - bank in setting
//
// Returns:
//   Array - contains references to the AgreementOnEDUse catalog
//
Function EDFSettingsWithBanks(Company, Bank) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDUsageAgreements.Ref
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|WHERE
	|	TRUE
	|	AND EDUsageAgreements.AgreementStatus = VALUE(Enum.EDAgreementsStatuses.Acts)
	|	AND EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
	|	AND Not EDUsageAgreements.DeletionMark";
	
	If ValueIsFilled(Company) AND ValueIsFilled(Bank) Then
		Query.Text = StrReplace(Query.Text, "TRUE", "AgreementsOnEDUsage.Company
														|	= &Company AND AgreementsOnEDUsage.Counterparty = &Bank");
		Query.SetParameter("Company", Company);
		Query.SetParameter("Bank", Bank);
	EndIf;
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Asynchronous exchange with bank

Procedure UnpackEDBankPack(EDPackage, ReturnData) Export
	
	ReceivedEDSelection = ElectronicDocumentsService.GetEDSelectionByFilter(New Structure("FileOwner", EDPackage));
	TargetNamespace = ElectronicDocumentsService.AsynchronousExchangeWithBanksNamespace();
	PerformCryptoOperationsAtServer = PerformCryptoOperationsAtServer();
	PackAttributes = CommonUse.ObjectAttributesValues(EDPackage, "EDFSetting, Counterparty, Company");
	EDAgreement = PackAttributes.EDFSetup;
	Bank = PackAttributes.Counterparty;
	CryptographyIsUsed = CommonUse.ObjectAttributeValue(EDAgreement, "CryptographyIsUsed");
	
	If CryptographyIsUsed AND PerformCryptoOperationsAtServer Then
		Try
			CryptoManager = GetCryptoManager();
		Except
			MessageText = GetMessageAboutError("110");
			CommonUseClientServer.MessageToUser(MessageText);
			ReturnData.Insert("IsError", True);
			ReturnData.Insert("MessageText", MessageText);
			Return;
		EndTry;
	EndIf;
	
	Try
		While ReceivedEDSelection.Next() Do
			ReceivedED = ReceivedEDSelection.Ref;
			FileBinaryData = AttachedFiles.GetFileBinaryData(ReceivedED);
			PackageFile = ElectronicDocumentsService.TemporaryFileCurrentName();
			FileBinaryData.Write(PackageFile);
					
			XMLPack = New XMLReader;
			XMLPack.OpenFile(PackageFile);
			PackType = ElectronicDocumentsInternal.GetCMLValueType("ResultBank", TargetNamespace);
			ResultBank = XDTOFactory.ReadXML(XMLPack, PackType);
			XMLPack.Close();
			DeleteFiles(PackageFile);

			XMLObject = New XMLReader;
			
			If Not ResultBank.Success = Undefined 
				AND Not ResultBank.Success.GetPacketResponse = Undefined 
				AND Not ResultBank.Success.GetPacketResponse.Document = Undefined Then
				
				For Each Document IN ResultBank.Success.GetPacketResponse.Document Do
					If Document.compressed = True Then
						FileOfArchive = ElectronicDocumentsService.TemporaryFileCurrentName();
						Document.data.__content.Write(FileOfArchive);
						ZIPReading = New ZipFileReader(FileOfArchive);
						FolderForUnpacking = ElectronicDocumentsService.WorkingDirectory(
														"Ext", New UUID);
						Try
							ZIPReading.ExtractAll(FolderForUnpacking);
						Except
							ErrorText = BriefErrorDescription(ErrorInfo());
							If Not ElectronicDocumentsService.PossibleToExtractFiles(ZIPReading, FolderForUnpacking) Then
								MessageText = ElectronicDocumentsReUse.GetMessageAboutError("006");
							EndIf;
							ProcessExceptionByEDOnServer(NStr("en='ED package Unpacking';ru='распаковка пакета ЭД'"), ErrorText, MessageText);
						EndTry;
						ZIPReading.Close();
						DeleteFiles(FileOfArchive);
						EDFiles = FindFiles(FolderForUnpacking, "*");
						If EDFiles.Count() > 0 Then
							FileAttachment = EDFiles[0].FullName;
						Else
							DeleteFiles(FolderForUnpacking);
							Continue;
						EndIf;
					Else
						FileAttachment = ElectronicDocumentsService.TemporaryFileCurrentName();
						Document.data.__content.Write(FileAttachment);
					EndIf;
					
					If Document.dockind = "02" Then // Notification of the electronic document state
						XMLObject.OpenFile(FileAttachment);
						NotificationOnStateType = ElectronicDocumentsInternal.GetCMLValueType(
										"StatusDocNotice", TargetNamespace);
						StatusDocNotice = XDTOFactory.ReadXML(XMLObject, NotificationOnStateType);
						XMLObject.Close();
						If ValueIsFilled(FolderForUnpacking) Then
							DeleteFiles(FolderForUnpacking);
						Else
							DeleteFiles(FileAttachment);
						EndIf;
						
						IDQuery = StatusDocNotice.ExtIDStatusRequest;
						IsResponseToQuery = ValueIsFilled(IDQuery);
						IsResponseToReview = False;
						
						If IsResponseToQuery Then
							IDRequest = New UUID(IDQuery);
							EdQuery = Catalogs.EDAttachedFiles.GetRef(IDRequest);
						EndIf;
						
						IDOwner = New UUID(StatusDocNotice.ExtID);
						EDOwner = Catalogs.EDAttachedFiles.GetRef(IDOwner);
						ElectronicDocumentOwner = EDOwner;
						If IsResponseToQuery AND EDQuery.GetObject() <> Undefined Then
							ElectronicDocumentOwner = EDQuery;
							QueryKind = CommonUse.ObjectAttributeValue(EdQuery, "EDKind");
							IsResponseToReview = QueryKind = Enums.EDKinds.EDReturnQuery;
							IsResponseToProbe = QueryKind = Enums.EDKinds.QueryProbe;
						EndIf;
						
						If Not EDOwner.GetObject() = Undefined Then
							
							FileOwner = CommonUse.ObjectAttributeValue(EDOwner, "FileOwner");
							AddressInStorage = PutToTempStorage(Document.data.__content);
							DocumentName = NStr("en='Notification of electronic document state';ru='Извещение о состоянии электронного документа'");
							AttachedFile = AttachedFiles.AddFile(FileOwner, DocumentName, "xml", CurrentSessionDate(),
													CurrentSessionDate(), AddressInStorage, , , Catalogs.EDAttachedFiles.GetRef());
							AttributesStructure = New Structure;
							AttributesStructure.Insert("ElectronicDocumentOwner", ElectronicDocumentOwner);
							AttributesStructure.Insert("EDStatus", Enums.EDStatuses.Received);
							AttributesStructure.Insert("EDKind", Enums.EDKinds.NotificationOnStatusOfED);
							AttributesStructure.Insert("Counterparty", Bank);
							AttributesStructure.Insert("Company", PackAttributes.Company);
							AttributesStructure.Insert("EDDirection", Enums.EDDirections.Incoming);
							AttributesStructure.Insert("EDAgreement", EDAgreement);
							AttributesStructure.Insert(
								"FileDescription", StringFunctionsClientServer.StringInLatin(DocumentName));
							ElectronicDocumentsService.ChangeByRefAttachedFile(AttachedFile, AttributesStructure, False);
							
							If PerformCryptoOperationsAtServer AND Document.signature.Count() Then
								For Each signature IN Document.signature Do
									SignatureCertificates = CryptoManager.GetCertificatesFromSignature(signature.signedData);
									If SignatureCertificates.Count() > 0 Then
										Certificate = SignatureCertificates[0];
									Else
										Continue;
									EndIf;
									UserPresentation = DigitalSignatureClientServer.SubjectPresentation(Certificate);
									Imprint = Base64String(Certificate.Imprint);
									CertificateBinaryData = Certificate.Unload();
									AddInformationAboutSignature(AttachedFile, signature.signedData, Imprint, CurrentSessionDate(), "", ,
										UserPresentation, CertificateBinaryData);
								EndDo;
								DetermineSignaturesStatuses(AttachedFile);
							ElsIf Document.signature.Count() Then
								SignaturesArray = New Array;
								For Each DS IN Document.signature Do
									SignaturesArray.Add(DS.signedData);
								EndDo;
								ReturnData.DSData.Insert(AttachedFile, SignaturesArray);
							EndIf;
							
							If Not StatusDocNotice.Result.Status = Undefined Then
								StatusCode = StatusDocNotice.Result.Status.Code;
								AttributesForChange = New Structure;
								If StatusCode = "01" Then
									AttributesForChange.Insert("EDStatus", Enums.EDStatuses.Accepted);
								ElsIf StatusCode = "02" Then
									AttributesForChange.Insert("EDStatus", Enums.EDStatuses.Executed);
								ElsIf StatusCode = "03" Then
									AttributesForChange.Insert("EDStatus", Enums.EDStatuses.RejectedByBank);
									AttributesForChange.Insert("RejectionReason", StatusDocNotice.Result.Status.MoreInfo);
								ElsIf StatusCode = "04" Then
									AttributesForChange.Insert("EDStatus", Enums.EDStatuses.Suspended);
								ElsIf StatusCode = "05" Then
									AttributesForChange.Insert("EDStatus", Enums.EDStatuses.Canceled);
									If IsResponseToReview Then
										SetEDStatus(EdQuery, Enums.EDStatuses.Processed);
									EndIf;
								EndIf;
								AttributesForChange.Insert("UUIDExternal", StatusDocNotice.id);
								ElectronicDocumentsService.ChangeByRefAttachedFile(EDOwner, AttributesForChange, False);
								If IsResponseToQuery AND EDQuery.GetObject() <> Undefined Then
									EDQueryAttributes = New Structure("EDStatus", Enums.EDStatuses.NotificationReceived);
									ElectronicDocumentsService.ChangeByRefAttachedFile(EDQuery, EDQueryAttributes, False);
								EndIf;
							ElsIf Not StatusDocNotice.Result.Error = Undefined Then
								If IsResponseToProbe AND StatusDocNotice.Result.Code = "9999" Then
									AttributesForChange.Insert("EDStatus", Enums.EDStatuses.Executed);
									ElectronicDocumentsService.ChangeByRefAttachedFile(EDOwner, AttributesForChange, False);
								Else
									ErrorText = BankResponseErrorMessageText(StatusDocNotice.Result.Error);
									AttributesForChange = New Structure;
									AttributesForChange.Insert("EDStatus", Enums.EDStatuses.RejectedByBank);
									AttributesForChange.Insert("RejectionReason", ErrorText);
									ElectronicDocumentsService.ChangeByRefAttachedFile(EDOwner, AttributesForChange, False);
								EndIf;
							EndIf;
						Else
							OperationKind = NStr("en='Read notification of electronic document state';ru='Чтение извещения о состоянии электронного документа'");
							Problem = NStr("en='Electronic document is not found by ID: %1';ru='Не найден электронный документ по идентификатору: %1'");
							Problem = StringFunctionsClientServer.SubstituteParametersInString(Problem, IDOwner);
							ProcessExceptionByEDOnServer(OperationKind, Problem, , 1);
							Continue;
						EndIf;
					ElsIf Document.dockind = "01" Then // Alert about pack state
						XMLObject.OpenFile(FileAttachment);
						PackStatusNotificationType = ElectronicDocumentsInternal.GetCMLValueType(
											"StatusPacketNotice", TargetNamespace);
						StatusPacketNotice = XDTOFactory.ReadXML(XMLObject, PackStatusNotificationType);
						XMLObject.Close();
						If ValueIsFilled(FolderForUnpacking) Then
							DeleteFiles(FolderForUnpacking);
						Else
							DeleteFiles(FileAttachment);
						EndIf;
						If Not StatusPacketNotice.Result.Error = Undefined Then
							EDPackage = FindEDPack(EDAgreement, StatusPacketNotice.IDResultSuccessResponse);
							If ValueIsFilled(EDPackage) Then
								ErrorText = BankResponseErrorMessageText(StatusPacketNotice.Result.Error);
								EDStructure = New Structure;
								EDStructure.Insert("EDStatus", Enums.EDStatuses.TransferError);
								EDStructure.Insert("CorrectionText", ErrorText);
								ElectronicDocumentsService.UpdateEDPackageDocumentsStatuses(
									EDPackage, Enums.EDPackagesStatuses.Canceled, CurrentSessionDate());
								For Each String IN EDPackage.ElectronicDocuments Do
									ElectronicDocumentsService.ChangeByRefAttachedFile(
										String.ElectronicDocument, EDStructure, False);
								EndDo;
							EndIf;
						ElsIf Not StatusPacketNotice.Result.Status = Undefined Then
							SourceEDPack = FindEDPack(EDAgreement, StatusPacketNotice.IDResultSuccessResponse);
							If ValueIsFilled(SourceEDPack) Then
								If StatusPacketNotice.Result.Status.Code = "01" Then
									ElectronicDocumentsService.UpdateEDPackageDocumentsStatuses(
										SourceEDPack, Enums.EDPackagesStatuses.Delivered, CurrentSessionDate());
								EndIf;
							EndIf;
						EndIf;
					ElsIf Document.dockind = "15" Then // Bank statement
						XMLObject.OpenFile(FileAttachment);
						StatementType = ElectronicDocumentsInternal.GetCMLValueType(
											"Statement", TargetNamespace);
						Statement = XDTOFactory.ReadXML(XMLObject, StatementType);
						XMLObject.Close();
						If ValueIsFilled(FolderForUnpacking) Then
							DeleteFiles(FolderForUnpacking);
						Else
							DeleteFiles(FileAttachment);
						EndIf;
						
						QueryID = Statement.ExtIDStatementRequest;
						IDOwner = New UUID(QueryID);
						EDOwner = Catalogs.EDAttachedFiles.GetRef(IDOwner);
						
						If Not EDOwner.GetObject() = Undefined Then
							
							SetEDStatus(EDOwner, Enums.EDStatuses.Processed);
							
							FileOwner = CommonUse.ObjectAttributeValue(EDOwner, "FileOwner");
							
							AddressInStorage = PutToTempStorage(Document.data.__content);
							If ValueIsFilled(EDOwner) Then
								QueryName = CommonUse.ObjectAttributeValue(EDOwner, "Description");
								DocumentName = StrReplace(QueryName, NStr("en='Statement request';ru='Запрос выписки'"), NStr("en='Bank statement for period';ru='Выписка банка за период'"));
							Else
								DocumentName = NStr("en='Bank statement dated %1';ru='Выписка банка от %1'");
								DocumentName = StringFunctionsClientServer.SubstituteParametersInString(
													DocumentName, Format(CurrentSessionDate(), "DLF=D"));
							EndIf;
							AttachedFile = AttachedFiles.AddFile(FileOwner, DocumentName, "xml",
								CurrentSessionDate(), CurrentSessionDate(), AddressInStorage, , ,
								Catalogs.EDAttachedFiles.GetRef());
							AttributesStructure = New Structure;
							AttributesStructure.Insert("ElectronicDocumentOwner", EDOwner);
							AttributesStructure.Insert("EDStatus", Enums.EDStatuses.Received);
							AttributesStructure.Insert("EDKind", Enums.EDKinds.BankStatement);
							AttributesStructure.Insert("Counterparty", Bank);
							AttributesStructure.Insert("Company", PackAttributes.Company);
							AttributesStructure.Insert("EDDirection", Enums.EDDirections.Incoming);
							AttributesStructure.Insert("EDAgreement", EDAgreement);
							AttributesStructure.Insert(
								"FileDescription", StringFunctionsClientServer.StringInLatin(DocumentName));
							ElectronicDocumentsService.ChangeByRefAttachedFile(AttachedFile, AttributesStructure, False);
							
							If PerformCryptoOperationsAtServer AND Document.signature.Count() Then
								For Each signature IN Document.signature Do
									SignatureCertificates = CryptoManager.GetCertificatesFromSignature(signature.signedData);
									If SignatureCertificates.Count() > 0 Then
										Certificate = SignatureCertificates[0];
									Else
										Continue;
									EndIf;
									UserPresentation = DigitalSignatureClientServer.SubjectPresentation(Certificate);
									Imprint = Base64String(Certificate.Imprint);
									CertificateBinaryData = Certificate.Unload();
									AddInformationAboutSignature(AttachedFile, signature.signedData, Imprint, CurrentSessionDate(), "", ,
										UserPresentation, CertificateBinaryData);
								EndDo;
								DetermineSignaturesStatuses(AttachedFile);
							ElsIf Document.signature.Count() Then
								SignaturesArray = New Array;
								For Each signature IN Document.signature Do
									SignaturesArray.Add(signature.signedData);
								EndDo;
								ReturnData.DSData.Insert(AttachedFile, SignaturesArray);
							EndIf;
							SaveBankStamps(AttachedFile);
							DeterminePerformedPaymentOrders(AttachedFile);
						Else
							OperationKind = NStr("en='Read bank statement';ru='Чтение выписки банка'");
							Problem = NStr("en='Statement request was not found by ID: %1';ru='Не найден запрос выписки по идентификатору: %1'");
							Problem = StringFunctionsClientServer.SubstituteParametersInString(Problem, IDOwner);
							ProcessExceptionByEDOnServer(OperationKind, Problem, , 1);
							Continue;
						EndIf;
					EndIf;
				EndDo;
			ElsIf Not ResultBank.Error = Undefined Then
				ErrorText = BankResponseErrorMessageText(ResultBank.Error);
				CommonUseClientServer.MessageToUser(ErrorText);
				ReturnData.Insert("IsError", True);
				ReturnData.Insert("MessageText", ErrorText);
				Return;
			EndIf;
		EndDo;
		SetPackageStatus(EDPackage, Enums.EDPackagesStatuses.Unpacked);
	Except
		
		If Users.InfobaseUserWithFullAccess( , , False) Then
			MessagePattern = NStr("en='An error occurred while parsing
		|the %1 pack (for more information, see Events log monitor).';ru='Возникла ошибка при
		|разборе пакета %1 (подробности см. в Журнале регистрации).'");
			BriefErrorDescription = BriefErrorDescription(ErrorInfo());
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
								MessagePattern, EDPackage, BriefErrorDescription);
		EndIf;
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		OperationKind = NStr("en='ED reading.';ru='Чтение ЭД.'");
		ProcessExceptionByEDOnServer(OperationKind, DetailErrorDescription, MessageText, 1);
		ReturnData.Insert("IsError", True);
		ReturnData.Insert("MessageText", MessageText);
		
	EndTry;
	
EndProcedure

// For internal use only
Function ConnectionWithAsyncBankTest(EDAgreement, TokenRequestParametersStructure) Export
	
	TargetID = TokenRequestParametersStructure.TargetID;
	EncryptedMarker = EncryptedBankMarker(EDAgreement, TokenRequestParametersStructure);
	If EncryptedMarker <> Undefined Then
		CryptographyManagerCreated = True;
		Try
			CryptoManager = GetCryptoManager();
			CryptoManager.PrivateKeyAccessPassword = TokenRequestParametersStructure.UserPassword;
		Except
			MessageText = GetMessageAboutError("100");
			ElectronicDocumentsClientServer.MessageToUser(MessageText, TargetID);
			CryptographyManagerCreated = False;
		EndTry;
		If CryptographyManagerCreated Then
			DataDecrypted = True;
			Try
				DecryptedBinaryData = CryptoManager.Decrypt(EncryptedMarker);
			Except
				MessageText = GetMessageAboutError("103");
				ElectronicDocumentsClientServer.MessageToUser(MessageText, TargetID);
				DataDecrypted = False;
			EndTry;
			If DataDecrypted Then
				Marker = AStringOfBinaryData(DecryptedBinaryData);
			Else
				Return False;
			EndIf;
		Else
			Return False;
		EndIf;
	EndIf;
	TestResult = NStr("en='Failed.';ru='Не пройден.'");
	PassedSuccessfully = False;
	If ValueIsFilled(Marker) Then
		TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
		PassedSuccessfully = True;
	EndIf;
	ElectronicDocumentsClientServer.MessageToUser(TestResult, TargetID);

	If Not PassedSuccessfully Then
		Return False;
	EndIf;
	Test = NStr("en='Sending test package to the bank.';ru='Отправка тестового пакета в банк.'");
	ElectronicDocumentsClientServer.MessageToUser(Test, TargetID);
	
	QueryPosted = False;
	
	SendQueryProbeToBank(EDAgreement, Marker, QueryPosted);
	
	If Not QueryPosted Then
		TestResult = NStr("en='Failed.';ru='Не пройден.'");
		PassedSuccessfully = False;
	EndIf;
	ElectronicDocumentsClientServer.MessageToUser(TestResult, TargetID);
	
	Return PassedSuccessfully;
	
EndFunction

// For internal use only
Function EncryptedBankMarker(EDAgreement, TokenRequestParametersStructure) Export
	
	ElectronicDocumentsInternal.GetBankMarker(EDAgreement, TokenRequestParametersStructure, False)
	
EndFunction

// Authorized on bank server and receives a session identifier
//
// Parameters
//  EDAgreement  - CatalogRef.EDUsageAgreements - agreement
//  with bank AuthorizationParameters  - Structure - contains data:
//     * User - String - user
//     name * Password - String - user
//  password SMSAuthorizationData - Structure - return parameter - contains data for additional authorization
// via SMS Return value:
//   String   - bank session identifier, Undefined - if an error occurs while getting ID
//
Function BankSessionID(Val EDAgreement, Val AuthenticationParameters, SMSAuthenticationData) Export
	
	AgreementAttributes = CommonUse.ObjectAttributesValues(
				EDAgreement, "ServerAddress, CompanyIdentifier");
	
	Join = ElectronicDocumentsService.GetConnection(AgreementAttributes.ServerAddress);
	
	ResultFileName = GetTempFileName();
	
	Headers = New Map;
	Headers.Insert("User-Agent", "1C:Enterprise/8");
	Headers.Insert("Content-Type", "application/xml; charset=utf-8");
	Headers.Insert("CustomerID", AgreementAttributes.CompanyID);
	HASH = Base64StringWithoutBOM(AuthenticationParameters.User + ":" + AuthenticationParameters.UserPassword);
	Headers.Insert("Authorization", "Basic " + Hash);
	
	HTTPRequest = New HTTPRequest("Logon", Headers);
	
	Try
		Response = Join.Post(HTTPRequest, ResultFileName);
	Except
		MessageText = NStr("en='An error occurred while sending authentication
		|data to the bank server (for more information, see Events log monitor).';ru='Ошибка отправки данных аутентификации
		|на сервер банка (подробности см. в Журнале регистрации).'");
		OperationDescription = NStr("en='Authentication on the bank server';ru='Аутентификация на сервере банка'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ProcessExceptionByEDOnServer(OperationDescription, DetailErrorDescription, MessageText, 1);
		DeleteFiles(ResultFileName);
		Return Undefined;
	EndTry;
	
	HTTPRequest = Undefined;
	
	If Response.StateCode <> 200 Then
		Pattern = NStr("en='An error occurred while working with the Internet (%1)';ru='Ошибка работы с Интернет (%1)'");
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(Pattern, Response.StateCode);
		CommonUseClientServer.MessageToUser(ErrorMessage);
		DeleteFiles(ResultFileName);
		Return Undefined;
	EndIf;
	
	Read = New XMLReader;
	URI = ElectronicDocumentsService.AsynchronousExchangeWithBanksNamespace();
	
	Try
		Read.OpenFile(ResultFileName);
		ResultBank = XDTOFactory.ReadXML(Read, XDTOFactory.Type(URI, "ResultBank"));
		ResultBank.Validate();
		If Not ResultBank.Success = Undefined Then
			If Not ResultBank.Success.LogonResponse = Undefined Then
				If Not ResultBank.Success.LogonResponse.ExtraAuth = Undefined Then
					SMSAuthenticationData = New Structure;
					SMSAuthenticationData.Insert("SMSAuthorizationRequired");
					SMSAuthenticationData.Insert("PhoneMask", ResultBank.Success.LogonResponse.ExtraAuth.OTP.phoneMask);
				EndIf;
				Read.Close();
				DeleteFiles(ResultFileName);
				Return ResultBank.Success.LogonResponse.SID;
			EndIf
		ElsIf Not ResultBank.Error = Undefined Then
			ErrorText = BankResponseErrorMessageText(ResultBank.Error);
			CommonUseClientServer.MessageToUser(ErrorText);
		EndIf;
	Except
		MessageText = NStr("en='An error occurred
		|while reading bank response (for more information, see Events log monitor).';ru='Ошибка
		|чтения ответа банка (подробности см. в Журнале регистрации).'");
		OperationDescription = NStr("en='Authentication on the bank server';ru='Аутентификация на сервере банка'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ProcessExceptionByEDOnServer(OperationDescription, DetailErrorDescription, MessageText, 1);
	EndTry;
	
	Read.Close();
	DeleteFiles(ResultFileName);
	
EndFunction

// for internal use only
Procedure GetEDFromBankAsynchronousExchange(Val AuthorizationParameters, ReturnData) Export
	
	ReturnData.Insert("DSData", New Map);
	ReturnData.Insert("ReceivedPacksQuantity", 0);
	
	For Each KeyValue IN AuthorizationParameters Do
		EDAgreement = KeyValue.Key;
		Parameters = KeyValue.Value;
		Break;
	EndDo;
	
	If Parameters = Undefined Then
		ReturnData.Insert("IsError", True);
		ReturnData.Insert("MessageText", NStr("en='Unknown error';ru='Неизвестная ошибка'"));
		Return;
	EndIf;
	
	Filter = New Structure("EDFSetup", EDAgreement);
	DataAboutState = InformationRegisters.BankEDExchangeStates.Get(Filter);
	
	AgreementAttributes = CommonUse.ObjectAttributesValues(
		EDAgreement, "ServerAddress, Counterparty, CompanyID");
		
	Join = ElectronicDocumentsService.GetConnection(AgreementAttributes.ServerAddress);
	
	Headers = New Map;
	If Parameters.Property("MarkerTranscribed") Then
		Headers.Insert("SID", Parameters.MarkerTranscribed);
	Else
		Pattern = NStr("en='An error occurred during authentication on the service by address (%1)';ru='Ошибка аутентификации на сервисе по адресу (%1)'");
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(Pattern, AgreementAttributes.ServerAddress);
		CommonUseClientServer.MessageToUser(ErrorMessage);
		ReturnData.Insert("IsError", True);
		ReturnData.Insert("MessageText", ErrorMessage);
		Return;
	EndIf;
	
	Headers.Insert("CustomerId", AgreementAttributes.CompanyID);

	ResultFileName = ElectronicDocumentsService.TemporaryFileCurrentName();
	
	EDReceiptStartDate = DataAboutState.LastEDDateReceived;
	LastEDDateReceived = EDReceiptStartDate;
	
	QueryParameter = ?(ValueIsFilled(EDReceiptStartDate), "?date=" + EDReceiptStartDate, "");
	
	ResourceAddress = "GetPackList" + QueryParameter;
	
	HTTPRequest = New HTTPRequest(ResourceAddress, Headers);
	
	Try
		Response = Join.Get(HTTPRequest, ResultFileName);
	Except
		BriefErrorDescription = BriefErrorDescription(ErrorInfo());
		MessageText = NStr("en='An error occurred while getting new documents list from bank.
		|%1';ru='При получении списка новых документов из банка произошла ошибка.
		|%1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, BriefErrorDescription);
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		OperationKind = NStr("en='Get a new document list from the bank';ru='Получение списка новых документов из банка'");
		ProcessExceptionByEDOnServer(OperationKind, DetailErrorDescription, MessageText, 1);
		ReturnData.Insert("IsError", True);
		ReturnData.Insert("MessageText", MessageText);
	EndTry;
	
	HTTPRequest = Undefined;
	
	If Response.StateCode <> 200 Then
		If Response.StateCode = 401 Then
			ReturnData.Insert("ReauthenticationIsRequired");
			ReturnData.Insert("IsError", True);
		Else
			Pattern = NStr("en='An error occurred while working with the Internet (%1)';ru='Ошибка работы с Интернет (%1)'");
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(Pattern, Response.StateCode);
			DeleteFiles(ResultFileName);
			CommonUseClientServer.MessageToUser(ErrorMessage);
			ReturnData.Insert("IsError", True);
			ReturnData.Insert("MessageText", ErrorMessage);
		EndIf;
		DeleteFiles(ResultFileName);
		Return;
	EndIf;
		
	TargetNamespace = ElectronicDocumentsService.AsynchronousExchangeWithBanksNamespace();
		
	XMLObject = New XMLReader;
		
	Try
		XMLObject.OpenFile(ResultFileName);
		PacksListType = ElectronicDocumentsInternal.GetCMLValueType("ResultBank", TargetNamespace);
		ResultBank = XDTOFactory.ReadXML(XMLObject, PacksListType);
		ResultBank.Validate();
	Except
		BriefErrorDescription = BriefErrorDescription(ErrorInfo());
		MessageText = NStr("en='An error occurred while reading document from bank.
		|%1';ru='При чтении документа из банка произошла ошибка.
		|%1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, BriefErrorDescription);
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		OperationKind = NStr("en='Read new document list';ru='Чтение списка новых документов'");
		ProcessExceptionByEDOnServer(OperationKind, DetailErrorDescription, MessageText, 1);
		ReturnData.Insert("IsError", True);
		ReturnData.Insert("MessageText", MessageText);
		XMLObject.Close();
		DeleteFiles(ResultFileName);
		Return;
	EndTry;
	
	XMLObject.Close();
	DeleteFiles(ResultFileName);
		
	If Not ResultBank.Success = Undefined Then
		If Not ResultBank.Success.GetPacketListResponse = Undefined Then
			ArrayOfIDs = New Array;
			For Each ID IN ResultBank.Success.GetPacketListResponse.PacketID Do
				ArrayOfIDs.Add(ID);
			EndDo;
			LastEDDateReceived = ResultBank.Success.GetPacketListResponse.TimeStampLastPacket;
		Else
			Return;
		EndIf;
	ElsIf Not ResultBank.Error = Undefined Then
		ErrorText = BankResponseErrorMessageText(ResultBank.Error);
		CommonUseClientServer.MessageToUser(ErrorText);
		ReturnData.Insert("IsError", True);
		ReturnData.Insert("MessageText", ErrorText);
		Return;
	EndIf;
 		
	SQ = New StringQualifiers(80);
	Array = New Array;
	Array.Add(Type("String"));
	TypeDescriptionWith = New TypeDescription(Array, , SQ);
	
	TableIdentifiers = New ValueTable;
	TableIdentifiers.Columns.Add("ID", TypeDescriptionWith);
	
	For Each ID IN ArrayOfIDs Do
		NewRow = TableIdentifiers.Add();
		NewRow.ID = ID;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TableIdentifiers.ID
	|INTO TableIdentifiers
	|FROM
	|	&TableIdentifiers AS TableIdentifiers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EDPackage.ExternalUID
	|INTO ImportedPacks
	|FROM
	|	Document.EDPackage AS EDPackage
	|WHERE
	|	EDPackage.ExternalUID In
	|			(SELECT
	|				TableIdentifiers.ID
	|			FROM
	|				TableIdentifiers)
	|	AND EDPackage.EDFSetup = &EDFSetup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TableIdentifiers.ID
	|FROM
	|	TableIdentifiers AS TableIdentifiers
	|WHERE
	|	Not TableIdentifiers.ID In
	|				(SELECT
	|					ImportedPacks.ExternalUID
	|				FROM
	|					ImportedPacks)";
	Query.SetParameter("TableIdentifiers", TableIdentifiers);
	Query.SetParameter("EDFSetup", EDAgreement);
	ArrayOfIDs = Query.Execute().Unload().UnloadColumn("ID");
	
	CurrentSessionDate = CurrentSessionDate();
	ReceivedPacksArray = New Array;
	For Each ID IN ArrayOfIDs Do
		ResourceAddress = "GetPack?id=" + ID;
		HTTPRequest = New HTTPRequest(ResourceAddress, Headers);
		ResultFileName = ElectronicDocumentsService.TemporaryFileCurrentName();
		Try
			Response = Join.Get(HTTPRequest, ResultFileName);
		Except
			BriefErrorDescription = BriefErrorDescription(ErrorInfo());
			MessageText = NStr("en='An error occurred while getting document from bank.
		|%1';ru='При получении документа из банка произошла ошибка.
		|%1'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, BriefErrorDescription);
			DetailErrorDescription = DetailErrorDescription(ErrorInfo());
			OperationKind = NStr("en='Receive new package from bank by ID';ru='Получение нового пакета из банка по идентификатору'");
			ProcessExceptionByEDOnServer(OperationKind, DetailErrorDescription, MessageText, 1);
			ReturnData.Insert("IsError", True);
			ReturnData.Insert("MessageText", MessageText);
			DeleteFiles(ResultFileName);
			Return;
		EndTry;
		
		If Response.StateCode <> 200 Then
			Pattern = NStr("en='An error occurred while working with the Internet (%1)';ru='Ошибка работы с Интернет (%1)'");
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(Pattern, Response.StateCode);
			DeleteFiles(ResultFileName);
			ReturnData.Insert("IsError", True);
			ReturnData.Insert("MessageText", ErrorMessage);
			DeleteFiles(ResultFileName);
			Return;
		EndIf;
			
		ParametersStructure = IncomingEDBankData(EDAgreement, ResultFileName);
		DeleteFiles(ResultFileName);
		If ValueIsFilled(ParametersStructure) Then
			If ParametersStructure.Property("ErrorData") Then
				CommonUseClientServer.ExpandStructure(ReturnData, ParametersStructure.ErrorData, True);
				Return;
			EndIf;
			EDPackage = ElectronicDocumentsService.GenerateNewEDPackage(ParametersStructure);
			If ValueIsFilled(EDPackage) Then
				FileName = "EDI_" + ParametersStructure.ExternalUID;
				ItemBinaryData = New BinaryData(ParametersStructure.PackageFileName);
				DeleteFiles(ParametersStructure.PackageFileName);
				AddressInStorage = PutToTempStorage(ItemBinaryData);
				AttachedFile = AttachedFiles.AddFile(EDPackage, FileName, "xml", CurrentSessionDate,
								CurrentSessionDate, AddressInStorage, , , Catalogs.EDAttachedFiles.GetRef());
				AttributesStructure = New Structure;
				AttributesStructure.Insert("EDStatus", Enums.EDStatuses.Received);
				AttributesStructure.Insert("Counterparty", AgreementAttributes.Counterparty);
				AttributesStructure.Insert("EDDirection", Enums.EDDirections.Incoming);
				AttributesStructure.Insert("EDAgreement", EDAgreement);
				ElectronicDocumentsService.ChangeByRefAttachedFile(AttachedFile, AttributesStructure, False);
				ReceivedPacksArray.Add(EDPackage);
			EndIf;
			UnpackEDBankPack(EDPackage, ReturnData);
		EndIf;
	EndDo;
		
	If ValueIsFilled(LastEDDateReceived) AND LastEDDateReceived > EDReceiptStartDate Then // shift date to IR
		BeginTransaction();
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.BankEDExchangeStates");
		LockItem.SetValue("EDFSetup", EDAgreement);
		Try
			Block.Lock();
		Except
			BriefErrorDescription = BriefErrorDescription(ErrorInfo());
			MessageText = NStr("en='An error occurred while writing documents receipt date.
		|%1';ru='При записи даты получения документов произошла ошибка:.
		|%1'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, BriefErrorDescription);
			DetailErrorDescription = DetailErrorDescription(ErrorInfo());
			OperationKind = NStr("en='Save the last document receipt date';ru='Сохранение последней даты получения документов'");
			ProcessExceptionByEDOnServer(OperationKind, DetailErrorDescription, MessageText, 1);
			ReturnData.Insert("IsError", True);
			ReturnData.Insert("MessageText", MessageText);
			Return;
		EndTry;
		RecordManager = InformationRegisters.BankEDExchangeStates.CreateRecordManager();
		RecordManager.LastEDDateReceived = LastEDDateReceived;
		RecordManager.EDFSetup = EDAgreement;
		RecordManager.Write();
		CommitTransaction();
	EndIf;
		
	ReturnData.ReceivedPacksQuantity = ReceivedPacksArray.Count();
	
EndProcedure

// Authorized on bank server and receives a session identifier
//
// Parameters
//  EDAgreement  - CatalogRef.EDUsageAgreements - agreement
//  with bank SessionID  - String - unauthorized
//  session identifier OneTimePassword - String - password received by user
// as SMS Return value:
//   String   - bank session identifier, Undefined - if an error occurs while getting ID
//
Function BankSessionIDBySMS(Val EDAgreement, Val SessionID, OneTimePassword) Export
	
	AgreementAttributes = CommonUse.ObjectAttributesValues(
				EDAgreement, "ServerAddress, CompanyIdentifier");
	
	Join = ElectronicDocumentsService.GetConnection(AgreementAttributes.ServerAddress);
	
	ResultFileName = GetTempFileName();
	
	Headers = New Map;
	Headers.Insert("User-Agent", "1C:Enterprise/8");
	Headers.Insert("Content-Type", "application/xml; charset=utf-8");
	Headers.Insert("CustomerID", AgreementAttributes.CompanyID);
	Headers.Insert("SID", SessionID);
	Headers.Insert("OTP", OneTimePassword);
	
	HTTPRequest = New HTTPRequest("LogonOTP", Headers);
	
	Try
		Response = Join.Post(HTTPRequest, ResultFileName);
	Except
		MessageText = NStr("en='Authentication error on
		|the bank server (for more information, see Events log monitor).';ru='Ошибка
		|аутентификации на сервере банка (подробности см. в Журнале регистрации).'");
		OperationDescription = NStr("en='Authentication on the bank server';ru='Аутентификация на сервере банка'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ProcessExceptionByEDOnServer(OperationDescription, DetailErrorDescription, MessageText, 1);
		DeleteFiles(ResultFileName);
		Return Undefined;
	EndTry;
	
	HTTPRequest = Undefined;
	
	If Response.StateCode <> 200 Then
		Pattern = NStr("en='An error occurred while working with the Internet (%1)';ru='Ошибка работы с Интернет (%1)'");
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(Pattern, Response.StateCode);
		CommonUseClientServer.MessageToUser(ErrorMessage);
		DeleteFiles(ResultFileName);
		Return Undefined;
	EndIf;
	
	Read = New XMLReader;
	URI = ElectronicDocumentsService.AsynchronousExchangeWithBanksNamespace();
	
	Try
		Read.OpenFile(ResultFileName);
		ResultBank = XDTOFactory.ReadXML(Read, XDTOFactory.Type(URI, "ResultBank"));
		ResultBank.Validate();
		If Not ResultBank.Success = Undefined Then
			If Not ResultBank.Success.LogonResponse = Undefined Then
				Read.Close();
				DeleteFiles(ResultFileName);
				Return ResultBank.Success.LogonResponse.SID;
			EndIf
		ElsIf Not ResultBank.Error = Undefined Then
			ErrorText = BankResponseErrorMessageText(ResultBank.Error);
			CommonUseClientServer.MessageToUser(ErrorText);
		EndIf;
	Except
		MessageText = NStr("en='An error occurred
		|while reading bank response (for more information, see Events log monitor).';ru='Ошибка
		|чтения ответа банка (подробности см. в Журнале регистрации).'");
		OperationDescription = NStr("en='Authentication on the bank server';ru='Аутентификация на сервере банка'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ProcessExceptionByEDOnServer(OperationDescription, DetailErrorDescription, MessageText, 1);
	EndTry;
	
	Read.Close();
	DeleteFiles(ResultFileName);
	
EndFunction

Function SendEDStatusQuery(Val AuthorizationParameters, ED) Export
	
	EDAttributes = CommonUse.ObjectAttributesValues(ED, "EDAgreement, FileOwner");
	
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
	CompanyAttributes = CommonUse.ObjectAttributesValues(AgreementAttributes.Company, "TIN");
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
		ElectronicDocumentsInternal.FillXDTOProperty(EDStateQuery, "Sender", Sender, True, ErrorText);
		
		Recipient = ElectronicDocumentsInternal.GetCMLObjectType("BankPartyType", TargetNamespace);
		ElectronicDocumentsInternal.FillXDTOProperty(Recipient, "bic", BankingDetails.Code, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			Recipient, "name", BankingDetails.Description, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			EDStateQuery, "Recipient", Recipient, True, ErrorText);
		EDStateQuery.Validate();
		
		If ValueIsFilled(ErrorText) Then
			CommonUseClientServer.MessageToUser(ErrorText);
			FileIsFormed = False;
		Else
			TempFile = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
			ElectronicDocumentsInternal.ExportEDtoFile(EDStateQuery, TempFile, False, "UTF-8");
			FileIsFormed = True;
		EndIf;

	Except
		BriefErrorDescription = BriefErrorDescription(ErrorInfo());
		MessagePattern = NStr("en='%1 (for more information, see Event log).';ru='%1 (подробности см. в Журнале регистрации).'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
										MessagePattern, BriefErrorDescription);
		Operation = NStr("en='ED generation';ru='Формирование ЭД'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ProcessExceptionByEDOnServer(Operation, DetailErrorDescription, MessageText, 1);
		FileIsFormed = False;
	EndTry;
		
	If Not FileIsFormed Then
		Return 0;
	EndIf;
	
	BinaryData = New BinaryData(TempFile);
	FileURL = PutToTempStorage(BinaryData);

	DeleteFiles(TempFile);
	
	EDName = NStr("en='ED state query';ru='Запрос состояния ЭД'");

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
	
	ElectronicDocumentsService.ChangeByRefAttachedFile(EDQuery, ParametersStructure, False);
	
	StructurePED = New Structure;
	
	StructurePED.Insert("Company", AgreementAttributes.Company);
	StructurePED.Insert("Counterparty", AgreementAttributes.Counterparty);
	StructurePED.Insert("Sender", AgreementAttributes.Company);
	StructurePED.Insert("Recipient", AgreementAttributes.Counterparty);
	StructurePED.Insert("EDFSetup", EDAttributes.EDAgreement);
	StructurePED.Insert("EDExchangeMethod", Enums.EDExchangeMethods.ThroughBankWebSource);
	TabularSectionData = New Array;
	TabularSectionData.Add(EDQuery);
	
	EDP = ElectronicDocumentsService.CreateEDPack(StructurePED, TabularSectionData);
	
	If Not ValueIsFilled(EDP) Then
		Return 0;
	EndIf;
	
	ElectronicDocumentsService.CreateEDPackAsync(EDP);
	
	PacksArray = New Array;
	PacksArray.Add(EDP);
	Return EDPackagesSending(PacksArray, AuthorizationParameters);
	
EndFunction

// Generates and sends a request-probe to bank
//
// Parameters
//  EDAgreement  - CatalogRef.EDUsageAgreements - Agreement on
//  exchange with bank DecryptedMarker  - String - encrypted
//  marker of the QuerySent bank  - Boolean - Shows that the request is sent successfully
//
Procedure SendQueryProbeToBank(Val EDAgreement, Val SessionID, QueryPosted) Export
	
	QueryPosted = False;
	AgreementAttributes = CommonUse.ObjectAttributesValues(
		EDAgreement, "Company, Counterparty, CompanyID");
	Responsible = ElectronicDocumentsOverridable.GetResponsibleByED(
										AgreementAttributes.Counterparty, EDAgreement);
	
	AttributeCompanyName = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
																		"ShortDescriptionOfTheCompany");
	If Not ValueIsFilled(AttributeCompanyName) Then
		AttributeCompanyName = "Description";
	EndIf;
	SenderName = CommonUse.GetAttributeValue(
		AgreementAttributes.Company, AttributeCompanyName);
	ClientApplicationVersion = ElectronicDocumentsReUse.ClientApplicationVersionForBank();
	CompanyAttributes = CommonUse.ObjectAttributesValues(AgreementAttributes.Company, "TIN");
	BankingDetails = CommonUse.ObjectAttributesValues(AgreementAttributes.Counterparty, "Code, description");
	TargetNamespace = ElectronicDocumentsService.AsynchronousExchangeWithBanksNamespace();
	
	ErrorText = "";
	Try
			
		UnIdED = New UUID;
		
		QueryProbe = ElectronicDocumentsInternal.GetCMLObjectType("Probe", TargetNamespace);
		ElectronicDocumentsInternal.FillXDTOProperty(QueryProbe, "id", String(UnIdED), True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(QueryProbe, "formatVersion",
			ElectronicDocumentsService.AsynchronousExchangeWithBanksSchemeVersion(), True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			QueryProbe, "creationDate", CurrentSessionDate(), True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(QueryProbe, "userAgent", ClientApplicationVersion, , ErrorText);
		Sender = ElectronicDocumentsInternal.GetCMLObjectType("CustomerPartyType", TargetNamespace);
		ElectronicDocumentsInternal.FillXDTOProperty(
			Sender, "id", AgreementAttributes.CompanyID, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			Sender, "name", SenderName, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			Sender, "tin", CompanyAttributes.TIN, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(QueryProbe, "Sender", Sender, True, ErrorText);
		
		Recipient = ElectronicDocumentsInternal.GetCMLObjectType("BankPartyType", TargetNamespace);
		ElectronicDocumentsInternal.FillXDTOProperty(Recipient, "bic", BankingDetails.Code, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(
			Recipient, "name", BankingDetails.Description, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(QueryProbe, "Recipient", Recipient, True, ErrorText);
		QueryProbe.Validate();
		
		If ValueIsFilled(ErrorText) Then
			CommonUseClientServer.MessageToUser(ErrorText);
			FileIsFormed = False;
		Else
			TempFile = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
			ElectronicDocumentsInternal.ExportEDtoFile(QueryProbe, TempFile, False, "UTF-8");
			FileIsFormed = True;
		EndIf;

	Except
		BriefErrorDescription = BriefErrorDescription(ErrorInfo());
		MessagePattern = NStr("en='%1 (for more information, see Event log).';ru='%1 (подробности см. в Журнале регистрации).'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
										MessagePattern, BriefErrorDescription);
		Operation = NStr("en='ED generation';ru='Формирование ЭД'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ProcessExceptionByEDOnServer(Operation, DetailErrorDescription, MessageText, 1);
		FileIsFormed = False;
	EndTry;
		
	If Not FileIsFormed Then
		Return;
	EndIf;
	
	BinaryData = New BinaryData(TempFile);
	FileURL = PutToTempStorage(BinaryData);

	DeleteFiles(TempFile);
	
	EDName = NStr("en='Probe query';ru='Запрос-зонд'");

	CurrentSessionDate = CurrentSessionDate();
	ED = AttachedFiles.AddFile(EDAgreement, EDName, "xml", CurrentSessionDate, CurrentSessionDate,
										FileURL, , , Catalogs.EDAttachedFiles.GetRef(UnIdED));

	ParametersStructure = New Structure();
	ParametersStructure.Insert("Author", Users.AuthorizedUser());
	ParametersStructure.Insert("EDDirection", Enums.EDDirections.Outgoing);
	ParametersStructure.Insert("EDKind", Enums.EDKinds.QueryProbe);
	ParametersStructure.Insert("EDStatus", Enums.EDStatuses.Created);
	ParametersStructure.Insert("Responsible", Responsible);
	ParametersStructure.Insert("Company", AgreementAttributes.Company);
	ParametersStructure.Insert("Counterparty", AgreementAttributes.Counterparty);
	ParametersStructure.Insert("EDAgreement", EDAgreement);
	ParametersStructure.Insert("SenderDocumentDate", CurrentSessionDate);
	ParametersStructure.Insert("FileDescription", EDName);
	ParametersStructure.Insert("EDOwner", EDAgreement);

	ElectronicDocumentsService.ChangeByRefAttachedFile(ED, ParametersStructure);
	
	StructurePED = New Structure;
	
	StructurePED.Insert("Company", AgreementAttributes.Company);
	StructurePED.Insert("Counterparty", AgreementAttributes.Counterparty);
	StructurePED.Insert("Sender", AgreementAttributes.Company);
	StructurePED.Insert("Recipient", AgreementAttributes.Counterparty);
	StructurePED.Insert("EDFSetup", EDAgreement);
	StructurePED.Insert("EDExchangeMethod", Enums.EDExchangeMethods.ThroughBankWebSource);
	TabularSectionData = New Array;
	TabularSectionData.Add(ED);
	
	EDP = ElectronicDocumentsService.CreateEDPack(StructurePED, TabularSectionData);
	
	If Not ValueIsFilled(EDP) Then
		Return;
	EndIf;
	
	ElectronicDocumentsService.CreateEDPackAsync(EDP);
	
	AuthorizationParameters = New Map;
	AuthorizationParameters.Insert(EDAgreement, New Structure("MarkerTranscribed", SessionID));
	PacksArray = New Array;
	PacksArray.Add(EDP);
	QueryPosted = EDPackagesSending(PacksArray, AuthorizationParameters) = 1;
	
EndProcedure

#Region ExchangeWithBankViaAdditionalDataProcessor

// Receives the electronic documents data structure to generate DS later
//
// Parameters
//  <EDArray>  - <array> - references to electronic documents array
//
// Returns:
// Structure, contains data for data processor on client
//
Function DataForDSGenerationThroughAdditDataProcessor(Val EDKindsArray) Export
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("EDArrayWithoutSchemas",         New Array);
	ReturnStructure.Insert("EDArrayWithSchemas",       New Array);
	ReturnStructure.Insert("TextDataEDArray", New Array);
	ReturnStructure.Insert("SchemasDataArray",        New Array);
	
	TempFile = GetTempFileName();
	
	For Each ED IN EDKindsArray Do
		EDSchema = ElectronicDocumentsService.ServiceBankED(ED);
		If ValueIsFilled(EDSchema) Then
			ReturnStructure.EDArrayWithSchemas.Add(ED);
			BinaryData = AttachedFiles.GetFileBinaryData(EDSchema);
			ReturnStructure.SchemasDataArray.Add(BinaryData);
		Else
			ReturnStructure.EDArrayWithoutSchemas.Add(ED);
			BinaryData = AttachedFiles.GetFileBinaryData(ED);
			BinaryData.Write(TempFile);
			TextDocument = New TextDocument;
			TextDocument.Read(TempFile);
			XMLString = TextDocument.GetText();
			ReturnStructure.TextDataEDArray.Add(XMLString);
		EndIf;
	EndDo;
		
	DeleteFiles(TempFile);
	
	Return ReturnStructure;
	
EndFunction

// Saves electronic documents data schemas
//
// Parameters
//  EDAgreement - CatalogRef.EDUsageAgreements - ref to the agreement
//  with bank EDArray  - Array - contains refs
//  to ED DataSchemasArray  - Array - contains ED text data
//
Procedure SaveDataSchemas(Val EDAgreement, Val EDKindsArray, Val DataSchemasArray) Export
	
	TempFile = GetTempFileName();
	
	IndexOf = 0;
	CountED = EDKindsArray.Count();
	
	For IndexOf = 0 To CountED - 1 Do
		
		FileOwner = CommonUse.ObjectAttributeValue(EDKindsArray[IndexOf], "FileOwner");
		StorageAddress = PutToTempStorage(DataSchemasArray[IndexOf]);
		AdditFile = AttachedFiles.AddFile(
						FileOwner,
						"DataSchema",
						,
						,
						,
						StorageAddress,
						,
						,
						Catalogs.EDAttachedFiles.GetRef());
		FileParameters = New Structure;
		FileParameters.Insert("EDAgreement",                EDAgreement);
		FileParameters.Insert("EDKind",                       Enums.EDKinds.AddData);
		FileParameters.Insert("ElectronicDocumentOwner", EDKindsArray[IndexOf]);
		FileParameters.Insert("FileDescription",           "DataSchema");
		FileParameters.Insert("EDStatus",                    Enums.EDStatuses.Received);
		ElectronicDocumentsService.ChangeByRefAttachedFile(AdditFile, FileParameters, False);
		
	EndDo;
	
	DeleteFiles(TempFile);

EndProcedure

// Saves electronic document signatures
//
// Parameters
//  <EDArray>  - <Array> - contains
//  ED array <SignaturesArray>  - <Array> - contains signatures
//  data array <Certificate> - <CatalogRef.DSCertificates> - ref to the signature certificate
//
Procedure SaveSignaturesData(Val EDKindsArray, Val SignaturesArray, Val Certificate) Export
	
	CertificateAttributes = CommonUse.ObjectAttributesValues(
								Certificate,
								"Thumbprint, CertificateData, IssuedToWhom");
	RowOwner = "Owner: " + CertificateAttributes.IssuedToWhom;
	
	CountED = EDKindsArray.Count();
	
	For IndexOf = 0 To CountED - 1 Do
		SignatureData = New Structure;
		SignatureData.Insert("Signature", SignaturesArray[IndexOf]);
		SignatureData.Insert("Imprint",                  CertificateAttributes.Imprint);
		SignatureData.Insert("SignatureDate",                CurrentSessionDate());
		SignatureData.Insert("Comment",                "");
		SignatureData.Insert("SignatureFileName",            "");
		SignatureData.Insert("CertificateIsIssuedTo",        RowOwner);
		SignatureData.Insert("Certificate",  CertificateAttributes.CertificateData.Get());
		SignatureData.Insert("CertificateBinaryData",  CertificateAttributes.CertificateData.Get());
		SignatureData.Insert("NewSignatureBinaryData",  SignaturesArray[IndexOf]);
		
		AddSignature(EDKindsArray[IndexOf], SignatureData);
	EndDo

EndProcedure

// Connects external data processor 
//
// Parameters:
//  EDAgreement - CatalogRef.EDAttachedFiles - ref to
//  the CurrentVersion agreement  - String - current version of already connected data processor - to exclude repeated
//  connection NewVersion  - String - data processor new version, version of
//  connected data processor is returned ObjectName  - String - external
//  data processor ID FileAddress - Temporary storage address to which data processor binary data is put
//
// Returns:
//  Boolean - True if data processor is connected
//
Function ConnectExternalDataProcessor(Val EDAgreement, Val CurrentVersion = Undefined, NewVersion = Undefined, ObjectName = "", FileURL = "") Export

	ProcessorEnabled = False;
	
	Query = New Query;
	Query.Text = "SELECT
	               |	EDUsageAgreements.AdditionalInformationProcessor.Version AS Version,
	               |	EDUsageAgreements.AdditionalInformationProcessor,
	               |	EDUsageAgreements.AdditionalInformationProcessor.ObjectName AS ObjectName,
	               |	EDUsageAgreements.AdditionalInformationProcessor.DataProcessorStorage AS DataProcessorStorage
	               |FROM
	               |	Catalog.EDUsageAgreements AS EDUsageAgreements
	               |WHERE
	               |	EDUsageAgreements.Ref = &Ref";
	Query.SetParameter("Ref", EDAgreement);
	Result = Query.Execute().Select();
	
	If Result.Next() Then
		If CurrentVersion = Result.Version Then
			NewVersion = CurrentVersion;
		Else
			#If ThickClientOrdinaryApplication Then
				BinaryData = Result.DataProcessorStorage.Get();
				FileURL = PutToTempStorage(BinaryData, New UUID);
			#Else
				URL = GetURL(Result.AdditionalInformationProcessor, "DataProcessorStorage");
				ExternalDataProcessors.Connect(URL, , False);
			#EndIf
			NewVersion = Result.Version;
		EndIf;
		ObjectName = Result.ObjectName;
		ProcessorEnabled = True;
	EndIf;
	
	If Not ProcessorEnabled Then
		MessageText = NStr("en='Additional data processor is not selected in the agreement on using the direct exchange with bank: %1.';ru='Не выбрана дополнительная обработка в соглашении об использовании прямого обмена с банком: %1.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, EDAgreement);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return ProcessorEnabled;
	
EndFunction

// for internal use only
Procedure SendEDToBank(Val EDAgreement, Val AuthorizationParameters, ReturnData) Export
	
	ReturnData = New Structure;
	
	SentPackagesCnt = SendGeneratedEDToBank(EDAgreement, AuthorizationParameters);
	ReturnData.Insert("SentPackagesCnt", SentPackagesCnt);
	
	DataForSendingViaAddDataProcessor = DataForSendingToBank(EDAgreement, Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor);
	If DataForSendingViaAddDataProcessor.Count() > 0 Then
		ReturnData.Insert("DataForSendingViaAddDataProcessor", DataForSendingViaAddDataProcessor);
	EndIf;
	DataForiBank2Sending = DataForSendingToBank(EDAgreement, Enums.BankApplications.iBank2);
	If DataForiBank2Sending.Count() > 0 Then
		ReturnData.Insert("DataForiBank2Sending", DataForiBank2Sending);
	EndIf;
	
EndProcedure

#EndRegion

#Region Sberbank

//Deletes identifier from the register not to execute state query by it in the future
//
// Parameters:
//   EDAgreement - CatalogRef.EDUsageAgreement - agreement
//   with Sberbank Identifier - String - EDKind
//   query ID - EnumRef.EDKinds - Electronic document kind
//
Procedure DeleteIDRequest(EDAgreement, ID, EDKind) Export

	RecordManager = InformationRegisters.BankRequestsIdentifiers.CreateRecordManager();
	RecordManager.EDAgreement = EDAgreement;
	RecordManager.ID = ID;
	RecordManager.EDKind = EDKind;
	Try
		RecordManager.Delete();
	Except
		MessagePattern = NStr("en='%1. (for more information, see Event log).';ru='%1. (подробности см. в Журнале регистрации).'");
		BriefErrorDescription = BriefErrorDescription(ErrorInfo());
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
										MessagePattern, BriefErrorDescription);
		Operation = NStr("en='Delete ID bank request';ru='Удаление идентификатора запроса банка'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ProcessExceptionByEDOnServer(Operation, DetailErrorDescription, MessageText, 1);
	EndTry;
	
EndProcedure

// for internal use only
Function PublisherRepresentation(DataStructure) Export
	
	ReturnString = "";
	
	For Each Item IN DataStructure Do
		ReturnString = ReturnString + Item.Key + "=" + Item.Value + ", ";
	EndDo;
	
	ReturnString = Mid(ReturnString, 1, StrLen(ReturnString) - 2);
	
	Return ReturnString;
	
EndFunction

// Returns certificate data structure
//
// Parameters:
// Imprint - certificate thumbprint
//
// Returns:
// Structure, contains certificate data
//
Function InformationAboutSignatureCertificateSberbank(Imprint)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Certificates.CertificateData
	|FROM
	|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
	|WHERE
	|	Certificates.Imprint = &Imprint";
	Query.SetParameter("Imprint", Imprint);
	SelectionOfCertificates = Query.Execute().Select();
	If SelectionOfCertificates.Next() Then
		ReturnStructure = New Structure;
		Certificate = New CryptoCertificate(SelectionOfCertificates.CertificateData.Get());
		
		//Issuer = "EMAILADDRESS=%1, OID.2.5.4.33=%2, CN=%3, OU=%4, O=%5, C=%6";  // TODO
		Issuer = "EMAILADDRESS=%1, OID.2.5.4.33=Testing, CN=%2, OU=%3, O=%4, C=%5";
		Issuer = StringFunctionsClientServer.SubstituteParametersInString(Issuer, Certificate.Issuer.E,// Testing,
						Certificate.Issuer.CN, Certificate.Issuer.OU, Certificate.Issuer.O, Certificate.Issuer.C);
		
		ReturnStructure.Insert("SN", Certificate.SerialNumber);
		ReturnStructure.Insert("Issuer", Issuer);
		
		ReturnStructure.Insert("CertificateData", SelectionOfCertificates.CertificateData);
		Return ReturnStructure;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Fills in signatures in schema and Generates pack file to send to bank
//
// Parameters
//  EDRef - CatalogRef.EDAttachedFiles - ref to
//  electronic document EDAgreement - CatalogRef.EDUsageAgreement - agreement
//  with bank QueryID - String - query return
//  ID CompanyID - String - bank client ID
//
// Returns:
// Structure with file data or Undefined
//
Function GetPackageFileSberBank(Val EDRef, Val EDAgreement, IDRequest, CompanyID) Export

	FileData = ElectronicDocumentsService.GetFileData(EDRef);
	FileBinaryData = GetFromTempStorage(FileData.FileBinaryDataRef);
	TempFile = GetTempFileName();
	PackageFile = GetTempFileName();
	FileBinaryData.Write(TempFile);
		
	XMLObject = New XMLReader;
	TargetNamespace = "http://www.bssys.com/en/";
	
	Try
		XMLObject.OpenFile(TempFile);
		
		ED = XDTOFactory.ReadXML(XMLObject);
		
		If ED.Type() = ElectronicDocumentsInternal.GetCMLValueType("PayDocRu", TargetNamespace) Then
			ErrorText = "";
			CompanyID = CommonUse.ObjectAttributeValue(EDAgreement, "CompanyID");
			Request = ElectronicDocumentsInternal.GetCMLObjectType("Request",TargetNamespace);
			IDRequest = CommonUse.ObjectAttributeValue(EDRef, "UniqueId");
			ElectronicDocumentsInternal.FillXDTOProperty(
				Request, "requestId", IDRequest, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(
				Request, "orgId", CompanyID, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(Request, "version",  "1.0",               True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(Request, "sender",   "1C:Enterprise 8", True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(Request, "receiver", "SBBOL_DBO",         True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(Request, "PayDocRu", ED,                  True, ErrorText);
			For Each DS in EDRef.DigitalSignatures Do  
				Signature = DS.Signature.Get();
				CertificateData = InformationAboutSignatureCertificateSberbank(DS.Imprint);
				If CertificateData = Undefined Then
					XMLObject.Close();
					Raise NStr("en='Signature certificate is not found';ru='Не найден сертификат установленной подписи'");
				EndIf;
				DigitalSign = ElectronicDocumentsInternal.GetCMLObjectType("DigitalSign", "http://www.bssys.com/en/");
				ElectronicDocumentsInternal.FillXDTOProperty(DigitalSign, "Issuer", CertificateData.Issuer, True);
				RowSerialNumber = String(CertificateData.SN);
				RowSerialNumber = StrReplace(RowSerialNumber, " ", "");
				ElectronicDocumentsInternal.FillXDTOProperty(DigitalSign, "SN", RowSerialNumber, True);
				ElectronicDocumentsInternal.FillXDTOProperty(DigitalSign, "Value", Signature, True);
				Request.Sign.Add(DigitalSign);
			EndDo;
			Request.Validate();
		ElsIf ED.Type() = ElectronicDocumentsInternal.GetCMLValueType("StmtReqType", TargetNamespace) Then
			ErrorText = "";
			CompanyID = CommonUse.ObjectAttributeValue(EDAgreement, "CompanyID");
			Request = ElectronicDocumentsInternal.GetCMLObjectType("Request", TargetNamespace);
			IDRequest = CommonUse.ObjectAttributeValue(EDRef, "UniqueId");
			ElectronicDocumentsInternal.FillXDTOProperty(
				Request, "requestId", IDRequest, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(
				Request, "orgId", CompanyID, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(Request, "version",  "1.0",               True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(Request, "sender",   "1C:Enterprise 8", True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(Request, "receiver", "SBBOL_DBO",         True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(Request, "StmtReq",  ED,                  True, ErrorText);
			For Each DS in EDRef.DigitalSignatures Do
				Signature = DS.Signature.Get();
				CertificateData = InformationAboutSignatureCertificateSberbank(DS.Imprint);
				If CertificateData = Undefined Then
					XMLObject.Close();
					Raise NStr("en='Signature certificate is not found';ru='Не найден сертификат установленной подписи'");
				EndIf;
				DigitalSign = ElectronicDocumentsInternal.GetCMLObjectType("DigitalSign", "http://www.bssys.com/en/");
				ElectronicDocumentsInternal.FillXDTOProperty(DigitalSign, "Issuer", CertificateData.Issuer, True);
				RowSerialNumber = String(CertificateData.SN);
				RowSerialNumber = StrReplace(RowSerialNumber, " ", "");
				ElectronicDocumentsInternal.FillXDTOProperty(DigitalSign, "SN",    RowSerialNumber, True);
				ElectronicDocumentsInternal.FillXDTOProperty(DigitalSign, "Value", Signature,             True);
				Request.Sign.Add(DigitalSign);
			EndDo;
			Request.Validate();
		Else
			XMLObject.Close();
			Raise NStr("en='Unknown file format';ru='Неизвестный формат файла'");
		EndIf;
		If ValueIsFilled(ErrorText) Then
			Raise ErrorText;
		EndIf;

		XMLObject.Close();
		DeleteFiles(TempFile);
		ElectronicDocumentsInternal.ExportEDtoFile(Request, PackageFile, , "UTF-8");
		TextDocument = New TextDocument;
		TextDocument.Read(PackageFile);
		XMLString = TextDocument.GetText();
		DeleteFiles(PackageFile);
		FileData.Insert("XMLString", XMLString);

	Except
		XMLObject.Close();
		ErrorText = NStr("en='An error occurred when generating the data package of the bank';ru='Возникла ошибка при формировании пакета данных банка'");
		CommonUseClientServer.MessageToUser(ErrorText + Chars.LF + ErrorDescription());
		DeleteFiles(TempFile);
		DeleteFiles(PackageFile);
		Return Undefined;
	EndTry;
	
	Return FileData;

EndFunction

// Writes an event to the audit journal
//
// Parameters
//  <EDAgreement>  - <CatalogRef.AgreementAboutEDUsage> - agreement on electronic
//  documents exchange <EventDescription>  - <string> - event text description to be
//  displayed in the journal <MessageText>  - <string> - text with data
//
Procedure WriteEventToLogAudit(EDAgreement, DetailsEvents, MessageText) Export
		
	ID = String(New UUID);

	NewRecord = InformationRegisters.AuditLogbookSberbank.CreateRecordManager();
	NewRecord.EventID = ID;
	NewRecord.Definition = DetailsEvents;
	NewRecord.Period = CurrentSessionDate();
	NewRecord.User = SessionParameters.CurrentUser;
	NewRecord.EDAgreement = EDAgreement;
	NewRecord.MessageText = MessageText;
	NewRecord.Write();
	
EndProcedure // WriteEventToAuditJournal()

// Saves query IDs for the further statuses query
//
// Parameters
//  <IdentifiersArray>  - <Array> - received identifiers query
//  array <EDAgreement>  - <CatalogRef.AgreementAboutEDUsage> - agreement on electronic
//  documents exchange <EDKind>  - <Enums.EDKinds> - Electronic document kind
//
Procedure SaveIdentifiers(ArrayOfIDs, EDAgreement, EDKind) Export
	
	For Each ID IN ArrayOfIDs Do
		NewRecord = InformationRegisters.BankRequestsIdentifiers.CreateRecordManager();
		NewRecord.ID = ID;
		NewRecord.EDAgreement = EDAgreement;
		NewRecord.EDKind = EDKind;
		NewRecord.Write();
	EndDo;
	
EndProcedure

// Prepares the request text to get night statement
//
// Parameters
//  <QueryID>  - <string> - query unique
//  ID <CompanyID>  - <string> - company unique ID in the
//  banking system <DS>  - <string> - digest digital
//  signature <SignatureCertificate>  - <CatalogRef.DSCertificates> - ref to a set signature certificate
//
// Returns:
// <String> - night statement request text
//
Function QueryTextNightIssue(IDRequest, CompanyID, DS, SignatureCertificate) Export

	TargetNamespace = "http://www.bssys.com/en/";
	
	ErrorText = "";
	
	Try

		Request = ElectronicDocumentsInternal.GetCMLObjectType("Request", TargetNamespace);
		ElectronicDocumentsInternal.FillXDTOProperty(
											Request,
											"requestId",
											IDRequest,
											True,
											ErrorText);
		
		ElectronicDocumentsInternal.FillXDTOProperty(
											Request,
											"orgId",
											CompanyID,
											True,
											ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(Request, "version",  "1.0",               True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(Request, "sender",   "1C:Enterprise 8", True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(Request, "receiver", "SBBOL_DBO",         True, ErrorText);
		Incoming = ElectronicDocumentsInternal.GetCMLObjectType("Request.Incoming", TargetNamespace);
		ElectronicDocumentsInternal.FillXDTOProperty(Request, "Incoming", Incoming, True, ErrorText);
		
		Imprint = CommonUse.ObjectAttributeValue(SignatureCertificate, "Imprint");
		
		CertificateData = InformationAboutSignatureCertificateSberbank(Imprint);
		If CertificateData = Undefined Then
			Raise NStr("en='Signature certificate is not found';ru='Не найден сертификат установленной подписи'");
		EndIf;
		DigitalSign = ElectronicDocumentsInternal.GetCMLObjectType("DigitalSign","http://www.bssys.com/en/");
		ElectronicDocumentsInternal.FillXDTOProperty(DigitalSign, "Issuer", CertificateData.Issuer, True);
		RowSerialNumber = String(CertificateData.SN);
		RowSerialNumber = StrReplace(RowSerialNumber," ","");
		ElectronicDocumentsInternal.FillXDTOProperty(DigitalSign, "SN",    RowSerialNumber, True);
		ElectronicDocumentsInternal.FillXDTOProperty(DigitalSign, "Value", DS,                 True);
		Request.Sign.Add(DigitalSign);
				
		Request.Validate();
		
		If ValueIsFilled(ErrorText) Then
			Raise NStr("en='Error generating night statement request';ru='Ошибка формирования запроса ночной выписки'");
		EndIf;
		
		Record = New XMLWriter;
		Record.SetString();
		XDTOFactory.WriteXML(Record, Request);
		QueryText = Record.Close();
		
	Except
		
		MessagePattern = NStr("en='%1. (for more information, see Event log).';ru='%1. (подробности см. в Журнале регистрации).'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
															MessagePattern,
															BriefErrorDescription(ErrorInfo()));
		ProcessExceptionByEDOnServer(
				NStr("en='ED generation';ru='Формирование ЭД'"),
				DetailErrorDescription(ErrorInfo()),
				MessageText,
				1);
		Return "";
		
	EndTry;
	Return QueryText;
	
EndFunction

// Receives IDs array for futher generation of bank requests 
//         
// Parameters
//  <EDAgreement>  - <CatalogRef.AgreementAboutEDUsage> - agreement on electronic
//  documents exchange <EDKind>  - <Enums.EDKinds> - Type of the electronic document
//
Function ArrayOfQueryIDs(EDAgreement, EDKind) Export
	
	ArrayOfIDs = New Array;
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	BankRequestsIdentifiers.ID
	|FROM
	|	InformationRegister.BankRequestsIdentifiers AS BankRequestsIdentifiers
	|WHERE
	|	BankRequestsIdentifiers.EDAgreement = &EDAgreement
	|	AND BankRequestsIdentifiers.EDKind = &EDKind";
	Query.SetParameter("EDAgreement", EDAgreement);
	Query.SetParameter("EDKind", EDKind);
	IdentifiersSelection = Query.Execute().Select();
	
	While IdentifiersSelection.Next() Do
		ArrayOfIDs.Add(IdentifiersSelection.ID);
	EndDo;
	
	Return ArrayOfIDs;

EndFunction

// Executes required actions to parse bank response
//
// Parameters
//  Response - String - text
//  with the EDFSetting response - CatalogRef.EDUsageAgreement - EDF setting
//  with the bank EDKind - EnumRef.EDKinds - the NewEDsArray
//  electronic document kind - Array - new received EDs
//  array Identifier - String - request ID to which response was received
//
Procedure HandleSberbankResponse(Response, EDFSetup, EDKind, NewEDArray, ID = Undefined) Export
	
	XMLReader = New XMLReader;
	XMLReader.SetString(Response);
	Try
		ResponseType = ElectronicDocumentsInternal.GetCMLValueType("Response", "http://www.bssys.com/en/");
		ED = XDTOFactory.ReadXML(XMLReader, ResponseType);
		ED.Validate();
		SaveSberbankResponse(ED, EDFSetup, ID, EDKind, NewEDArray);
	Except
		DeleteIDRequest(EDFSetup, ID, EDKind);
		XMLReader.Close();
		MessageText = NStr("en = 'An error occurred while reading data received from bank" + Chars.LF
						+ "For more information, see events log monitor'");
		ErrorText = DetailErrorDescription(ErrorInfo());
		ProcessExceptionByEDOnServer(NStr("en='Receive data from bank';ru='Получение данных из банка'"), ErrorText, MessageText, 1);
	EndTry;
	
EndProcedure

// Generates match of signatures set to ED to certificates data
//
// Parameters:
// ED - CatalogRef.EDAttachedFiles
//
// Returns:
// Map - contains data strings of set signatures and certificates data strings as BASE64
//
Function DataSetSignaturesAndCertificates(ED) Export
	
	ConformityOfReturn = New Map;

	Query = New Query;
	Query.Text =
	"SELECT
	|	EDAttachedFilesDigitalSignatures.Signature,
	|	EDAttachedFilesDigitalSignatures.Certificate
	|FROM
	|	Catalog.EDAttachedFiles.DigitalSignatures AS EDAttachedFilesDigitalSignatures
	|WHERE
	|	EDAttachedFilesDigitalSignatures.Ref = &Ref";
	Query.SetParameter("Ref", ED);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		BinaryDataSignatures = Selection.Signature.Get();
		DSRow = Base64String(BinaryDataSignatures);
		DSRow = StrReplace(DSRow, Chars.LF, "");
		DSRow = StrReplace(DSRow, Chars.CR, "");
		StringCertificate = CertificateInFormatBase64(Selection.Certificate);
		ConformityOfReturn.Insert(DSRow, StringCertificate);
	EndDo;
	
	Return ConformityOfReturn;
	
EndFunction

// Prepares string (digest) for futher signing as Base64
//
// Parameters:
// FileName - String - path to data file
//
// Returns:
//String
//
Function Digest(FileName, EDAgreement) Export
	
	CompanyID = CommonUse.ObjectAttributeValue(EDAgreement, "CompanyID");
	Result = ElectronicDocumentsInternal.GenerateParseTree(FileName);
	
	If Result = Undefined Then
		Return Undefined;
	EndIf;

	ParseTree = Result.ParseTree;
	ObjectString = Result.ObjectString;
	

	FillingData = New ValueList;

	EDKind = ObjectString.EDKind;
	
	If EDKind = Enums.EDKinds.PaymentOrder Then
		
		DocumentID = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "DocumentID");
		ReturnString = "ATTRIBUTES" + Char(10) + "OrgId=" + CompanyID + Char(10)
			+ "Sender = 1C: Enterprise 8" + Char(10) + "ExtId=" + DocumentID + Char(10) + "FIELDS" + Char(10);
		
		DocumentNumber = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree, ObjectString, "Number");
		FillingData.Add(DocumentNumber, "AccDoc.AccDocNo");
		CodeTypeOfCurrencyOperations = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "CodeTypeOfCurrencyOperations");
		FillingData.Add(CodeTypeOfCurrencyOperations, "AccDoc.CodeVO");
		DocumentDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree, ObjectString, "Date");
		FillingData.Add(Format(DocumentDate, "DF=yyyy-MM-dd"), "AccDoc.DocDate");
		Amount = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "Amount");
		FillingData.Add(Format(Amount, "NFD=2; NDS=.; NG="), "AccDoc.DocSum");
		PaymentKind = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "PaymentKind");
		FillingData.Add(PaymentKind, "AccDoc.PaytKind");
		OrderOfPriority = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "OrderOfPriority");
		FillingData.Add(OrderOfPriority, "AccDoc.Priority");
		PaymentDestination = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "PaymentDestination");
		FillingData.Add(PaymentDestination, "AccDoc.Purpose");
		OperationKind = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "OperationKind");
		FillingData.Add(OperationKind, "AccDoc.TransKind");
		AdditionalService = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "AdditionalService");
		FillingData.Add(AdditionalService, "AccDoc.UrgentSBRF");
		NumberOfCreditAgreement = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "NumberOfCreditAgreement");
		FillingData.Add(NumberOfCreditAgreement, "Credit.CredConNum");
		TargetAssignment = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "TargetAssignment");
		FillingData.Add(TargetAssignment, "Credit.FlagTargetAssignment");
		UseYourOwnTools = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "UseYourOwnTools");
		FillingData.Add(UseYourOwnTools, "Credit.FlagUseOwnMeans");
		KBKIndicator = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "KBKIndicator");
		FillingData.Add(KBKIndicator, "DepartmentalInfo.CBC");
		DateIndicator = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "DateIndicator");
		FillingData.Add(DateIndicator, "DepartmentalInfo.DocDate");
		NumberIndicator = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "NumberIndicator");
		FillingData.Add(NumberIndicator, "DepartmentalInfo.DocNo");
		AuthorStatus = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "AuthorStatus");
		FillingData.Add(AuthorStatus, "DepartmentalInfo.DrawerStatus");
		OKTMO = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "OKTMO");
		FillingData.Add(OKTMO, "DepartmentalInfo.OKATO");
		BasisIndicator = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "BasisIndicator");
		FillingData.Add(BasisIndicator, "DepartmentalInfo.PaytReason");
		TypeIndicator = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "TypeIndicator");
		FillingData.Add(TypeIndicator, "DepartmentalInfo.TaxPaytKind");
		PeriodIndicator = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "PeriodIndicator");
		FillingData.Add(PeriodIndicator, "DepartmentalInfo.TaxPeriod");
		PayeeBankDescription = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "RecipientBankName");
		FillingData.Add(PayeeBankDescription, "Payee.Bank.Name");
		SettlementRecipientBank = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "SettlementRecipientBank");
		FillingData.Add(SettlementRecipientBank, "Payee.Bank.BankCity");
		TypeLocalityOfBeneficiarysBank = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "TypeLocalityOfBeneficiarysBank");
		FillingData.Add(TypeLocalityOfBeneficiarysBank, "Payee.Bank.SettlementType");
		RecipientBankBIC = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "PayeeBankBIC");
		FillingData.Add(RecipientBankBIC, "Payee.Bank.Bic");
		PayeeBankAcc = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "RecipientBankCorrAccount");
		FillingData.Add(PayeeBankAcc, "Payee.Bank.CorrespAcc");
		BranchOfBankOfBeneficiary = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "BranchOfBankOfBeneficiary");
		FillingData.Add(BranchOfBankOfBeneficiary, "Payee.Filial");
		PayeeTIN = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "PayeeTIN");
		FillingData.Add(PayeeTIN, "Payee.TIN");
		PayeeText = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "RecipientDescription");
		FillingData.Add(PayeeText, "Payee.Name");
		RecipientAccountNumber = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "PayeeBankAcc");
		FillingData.Add(RecipientAccountNumber, "Payee.PersonalAcc");
		PayerBankDescription = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "PayerBankName");
		FillingData.Add(PayerBankDescription, "Payer.Bank.Name");
		SettlementPayerBank = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "SettlementPayerBank");
		FillingData.Add(SettlementPayerBank, "Payer.Bank.BankCity");
		TypeLocalityOfBankOfPayer = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "TypeLocalityOfBankOfPayer");
		FillingData.Add(TypeLocalityOfBankOfPayer, "Payer.Bank.SettlementType");
		PayerBankBIC = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "PayerBankBIC");
		FillingData.Add(PayerBankBIC, "Payer.Bank.Bic");
		PayerBankAcc = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "PayerBankCorrAccount");
		FillingData.Add(PayerBankAcc, "Payer.Bank.CorrespAcc");
		PayersBankBranch = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "PayersBankBranch");
		FillingData.Add(PayersBankBranch, "Payer.Filial");
		PayerTIN = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "PayerTIN");
		FillingData.Add(PayerTIN, "Payer.TIN");
		PayerText = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "PayerDescription");
		FillingData.Add(PayerText, "Payer.Name");
		PayerAccountNumber = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "PayerBankAcc");
		FillingData.Add(PayerAccountNumber, "Payer.PersonalAcc");
	ElsIf EDKind = Enums.EDKinds.QueryStatement Then
		
		DocumentID = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "DocumentID");
		
		ReturnString = "ATTRIBUTES" + Char(10) + "OrgId=" + CompanyID + Char(10)
			+ "Sender = 1C: Enterprise 8" + Char(10) + "ExtId=" + DocumentID + Char(10) + "FIELDS" + Char(10);
		
		PeriodOpenDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(ParseTree,
																										ObjectString,
																										"StartDate");
		FillingData.Add(Format(PeriodOpenDate, "DF=yyyy-MM-dd"), "BeginDate");
		EndDateOfPeriod = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"EndDate");
		FillingData.Add(Format(EndDateOfPeriod, "DF=yyyy-MM-dd"), "EndDate");
		TypeQuery = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"TypeQuery");
		FillingData.Add(TypeQuery, "StmtType");
	ElsIf EdKind = Enums.EDKinds.BankStatement Then
		ReturnString = "ATTRIBUTES" + Char(10) + "OrgId=" + CompanyID + Char(10) + "FIELDS"
							+ Char(10);
		UserAccount = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(ParseTree,
																									ObjectString,
																									"UserAccount");
		FillingData.Add(UserAccount, "AccountName");
		Performer = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"Performer");
		FillingData.Add(Performer, "Author");
		AccountNo = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"BankAcc");
		FillingData.Add(AccountNo, "ComRests.Acc");
		StartDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"StartDate");
		StartDate = Format(StartDate, "DF=yyyy-MM-dd");
		FillingData.Add(StartDate, "ComRests.BeginDate");
		FillingData.Add(
			ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(ParseTree, ObjectString, "BIN"),
			"ComRests.Bic");
		DateOfPreviousOperations = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"DateOfPreviousOperations");
		DateOfPreviousOperations = Format(DateOfPreviousOperations, "DF=yyyy-MM-dd");
		FillingData.Add(DateOfPreviousOperations, "ComRests.DatePLast");
		EndDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(ParseTree,
																									ObjectString,
																									"EndDate");
		EndDate = Format(EndDate, "DF=yyyy-MM-dd");
		FillingData.Add(EndDate, "ComRests.EndDate");
		IncomingBalance = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"OpeningBalance");
		IncomingBalance = Format(IncomingBalance, "NFD=2; NDS=.; NZ=0.00; NG=");
		FillingData.Add(IncomingBalance, "ComRests.EnterBal");
		AnIncomingBalanceInNationalCurrency = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"AnIncomingBalanceInNationalCurrency");
		AnIncomingBalanceInNationalCurrency = Format(AnIncomingBalanceInNationalCurrency, "NFD=2; NDS=.; NZ=0.00; NG=");
		FillingData.Add(AnIncomingBalanceInNationalCurrency, "ComRests.EnterBalNat");
		DateOfLastOperations = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(ParseTree,
																											ObjectString,
																											"DateOfLastOperations");
		DateOfLastOperations = Format(DateOfLastOperations, "DF=yyyy-MM-dd");
		FillingData.Add(DateOfLastOperations, "ComRests.LastMovetDate");
		PlannedOutgoingBalance = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"PlannedOutgoingBalance");
		PlannedOutgoingBalance = Format(PlannedOutgoingBalance, "NFD=2; NDS=.; NZ=0.00; NG=");
		FillingData.Add(PlannedOutgoingBalance, "ComRests.PlanOutBal");
		WellPlannedOutgoingBalanceInNationalCurrency = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"WellPlannedOutgoingBalanceInNationalCurrency");
		WellPlannedOutgoingBalanceInNationalCurrency = Format(
															WellPlannedOutgoingBalanceInNationalCurrency,
															"NFD=3; NDS=.; NZ=0.00; NG=");
		FillingData.Add(WellPlannedOutgoingBalanceInNationalCurrency, "ComRests.PlanOutBalNat");
		RateAtBeginningOfPeriod = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"RateAtBeginningOfPeriod");
		RateAtBeginningOfPeriod = Format(RateAtBeginningOfPeriod, "NFD=4; NDS=.; NG=");
		FillingData.Add(RateAtBeginningOfPeriod, "ComRests.RateIn");
		RateAtEndOfPeriod = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"RateAtEndOfPeriod");
		RateAtEndOfPeriod = Format(RateAtEndOfPeriod, "NFD=4; NDS=.; NG=");
		FillingData.Add(RateAtEndOfPeriod, "ComRests.RateOut");
		OutgoingBalance = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"ClosingBalance");
		OutgoingBalance = Format(OutgoingBalance, "NFD=2; NDS=.; NZ=0.00; NG=");
		FillingData.Add(OutgoingBalance, "ComRests.OutBal");
		OutgoingBalanceInNationalCurrency = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"OutgoingBalanceInNationalCurrency");
		OutgoingBalanceInNationalCurrency = Format(OutgoingBalanceInNationalCurrency, "NFD=2; NDS=.; NZ=0.00; NG=");
		FillingData.Add(OutgoingBalanceInNationalCurrency, "ComRests.OutBalNat");
		StatementCompletionDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"StatementCompletionDate");
		StatementCompletionDate = Format(StatementCompletionDate, "DF=yyyy-MM-ddTHH:mm:cc");
		FillingData.Add(StatementCompletionDate, "ComRests.StmtDateTime");
		TypeQueryStatements = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(ParseTree,
																										ObjectString,
																										"TypeQueryStatements");
		FillingData.Add(TypeQueryStatements, "ComRests.StmtType");
		Credit = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"DebitedTotal");
		Credit = Format(Credit, "NFD=2; NDS=.; NZ=0.00; NG=");
		FillingData.Add(Credit, "CreditSum");
		CreditInNationalCurrency = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"CreditInNationalCurrency");
		CreditInNationalCurrency = Format(CreditInNationalCurrency, "NFD=2; NDS=.; NZ=0.00; NG=");
		FillingData.Add(CreditInNationalCurrency, "CreditSumNat");
		CreditedTotal = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"CreditedTotal");
		Debit = Format(CreditedTotal, "NFD=2; NDS=.; NZ=0.00; NG=");
		FillingData.Add(Debit, "DebetSum");
		DebitInNationalCurrency = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"DebitInNationalCurrency");
		DebitInNationalCurrency = Format(DebitInNationalCurrency, "NFD=2; NDS=.; NZ=0.00; NG=");
		FillingData.Add(DebitInNationalCurrency, "DebetSumNat");
		AddInformation = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(ParseTree,
																									ObjectString,
																									"AddInformation");
		FillingData.Add(AddInformation, "DocComment");
		ExtractsStatements = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"ExtractsStatements");
		FillingData.Add(ExtractsStatements, "DocId");
		DocumentNumber = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"DocumentNumber");
		FillingData.Add(DocumentNumber, "DocNum");
		CompanyDescription = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																ObjectString,
																"CompanyDescription");
		FillingData.Add(CompanyDescription, "OrgName");
	ElsIf EDKind = Enums.EDKinds.STATEMENT Then
		DocumentID = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "TicketSBBOL");
		CreationDateKvitka = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "CreationDateKvitka");
		DateInFormat = Format(CreationDateKvitka, "DF=yyyy-MM-dd");
		ReturnString = "ATTRIBUTES" + Char(10) + "CreateTime=" + DateInFormat + Char(10)
						+ "DocId=" + DocumentID + Char(10)
						+ "FIELDS" + Char(10);
		DateWriteOffAccountOfPayer = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "DateWriteOffAccountOfPayer");
		DateWriteOffAccountOfPayer = Format(DateWriteOffAccountOfPayer, "DF=yyyy-MM-dd");
		FillingData.Add(DateWriteOffAccountOfPayer, "Info.BankDate.ChargeOffDate");
		DatePaymentEnums = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "DatePaymentEnums");
		DatePaymentEnums = Format(DatePaymentEnums, "DF=yyyy-MM-dd");
		FillingData.Add(DatePaymentEnums, "Info.BankDate.DPP");
		DateOfFiling = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "DateOfFiling");
		DateOfFiling = Format(DateOfFiling, "DF=yyyy-MM-dd");
		FillingData.Add(DateOfFiling, "Info.BankDate.FileDate");
		MarkByRecipientBankDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "MarkByRecipientBankDate");
		MarkByRecipientBankDate = Format(MarkByRecipientBankDate, "DF=yyyy-MM-dd");
		FillingData.Add(MarkByRecipientBankDate, "Info.BankDate.RecDate");
		ReceiptDateInPayersBank = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "ReceiptDateInPayersBank");
		ReceiptDateInPayersBank = Format(ReceiptDateInPayersBank, "DF=yyyy-MM-dd");
		FillingData.Add(ReceiptDateInPayersBank, "Info.BankDate.ReceiptDate");
		PayersBankStampDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "PayersBankStampDate");
		PayersBankStampDate = Format(PayersBankStampDate, "DF=yyyy-MM-dd");
		FillingData.Add(PayersBankStampDate, "Info.BankDate.SignDate");
		AuthorOfMessage = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "AuthorOfMessage");
		//FillingData.Add(MessageAuthor, "Info.MsgFromBank.Author");
		MessageFromBank = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "MessageFromBank");
		FillingData.Add(MessageFromBank, "Info.MsgFromBank.Message");
		CodeDocumentStatus = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
														ParseTree, ObjectString, "CodeDocumentStatus");
		FillingData.Add(CodeDocumentStatus, "Info.StatusStateCode");
	EndIf;
	
	TotalRecords = FillingData.Count();
	IndexOf = 0;
	For Each Item in FillingData Do
		IndexOf = IndexOf + 1;
		If ValueIsFilled(Item.Value) Then
				ReturnString= ReturnString + Item.Presentation + "=" + Item.Value
								+ ?(IndexOf <> TotalRecords, Char(10), "");
		EndIf;
	EndDo;

	If EDKind = Enums.EDKinds.QueryStatement Then
		
		ReturnString = ReturnString + Char(10) + "TABLES" + Char(10) + "Table=Accounts" + Char(10);
		TSRows = ObjectString.Rows.FindRows(New Structure("Attribute", "TSRow"));
		IndexOf = 0;
		TotalRecords = TSRows.Count();
		For Each TSRow IN TSRows Do
			IndexOf=IndexOf + 1;
			BIN = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(ParseTree, TSRow, "BIN");
			AccountNo = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																TSRow,
																"AccountNo");
			ReturnString = ReturnString + "Bic=" + BIN + Char(10) + "Account=" + AccountNo + Char(10)+ "#"
							+ ?(IndexOf <> TotalRecords, Char(10), "");
		EndDo;
	ElsIf EDKind = Enums.EDKinds.BankStatement Then
		ReturnString = ReturnString + Char(10) + "TABLES";
		TSRows = ObjectString.Rows.FindRows(New Structure("Attribute", "TSRow"));
		IndexOf = 0;
		TotalRecords = TSRows.Count();
		If TotalRecords > 0 Then
			ReturnString = ReturnString + Char(10) + "Table=TransInfo" + Char(10);
		EndIf;
		For Each TSRow IN TSRows Do
			IndexOf=IndexOf + 1;
			FillingDataRows = New ValueList;
			DateWriteOff = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"DateWriteOff");
			DateWriteOff = Format(DateWriteOff, "DF=yyyy-MM-dd");
			FillingDataRows.Add(DateWriteOff, "BankDate.ChargeOffDate=");
			DateEnums = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"DateEnums");
			DateEnums = Format(DateEnums, "DF=yyyy-MM-dd");
			FillingDataRows.Add(DateEnums, "BankDate.Dpp=");
			DateOfFiling = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"DateOfFiling");
			DateOfFiling = Format(DateOfFiling, "DF=yyyy-MM-dd");
			FillingDataRows.Add(DateOfFiling, "BankDate.FileDate=");
			DateStampOfBeneficiarysBank = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"DateStampOfBeneficiarysBank");
			DateStampOfBeneficiarysBank = Format(DateStampOfBeneficiarysBank, "DF=yyyy-MM-dd");
			FillingDataRows.Add(DateStampOfBeneficiarysBank, "BankDate.RecDate=");
			ReceiptDateInPayersBank = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"ReceiptDateInPayersBank");
			ReceiptDateInPayersBank = Format(ReceiptDateInPayersBank, "DF=yyyy-MM-dd");
			FillingDataRows.Add(ReceiptDateInPayersBank, "BankDate.ReceiptDate=");
			PayersBankStampDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"PayersBankStampDate");
			PayersBankStampDate =  Format(PayersBankStampDate, "DF=yyyy-MM-dd");
			FillingDataRows.Add(PayersBankStampDate, "BankDate.SignDate=");
			BankDocumentNumber = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"BankDocumentNumber");
			FillingDataRows.Add(BankDocumentNumber, "ComTransInfo.BankNumDoc=");
			DepartmentCode = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"DepartmentCode");
			DepartmentCode = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"DepartmentCode");
			FillingDataRows.Add(DepartmentCode, "ComTransInfo.BranchCode=");
			PostingDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"DateCredited");
			PostingDate = Format(PostingDate, "DF=yyyy-MM-ddTHH:mm:cc");
			FillingDataRows.Add(PostingDate, "ComTransInfo.CarryDate=");
			ApplicationSign = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(ParseTree,
																											TSRow,
																											"ApplicationSign");
			ApplicationSign = Format(ApplicationSign, "BF=0; BT=1");
			FillingDataRows.Add(ApplicationSign, "ComTransInfo.Dc=");
			PaymentCurrency = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(ParseTree,
																										TSRow,
																										"PaymentCurrency");
			FillingDataRows.Add(PaymentCurrency, "ComTransInfo.DocCurr=");
			DateAccountingDocument = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"Date");
			DateAccountingDocument = Format(DateAccountingDocument, "DF=yyyy-MM-dd");
			FillingDataRows.Add(DateAccountingDocument, "ComTransInfo.DocDate=");
			NumberOfAccountsDocument = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"Number");
			FillingDataRows.Add(NumberOfAccountsDocument, "ComTransInfo.DocNum=");
			DocumentAmount = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"Amount");
			DocumentAmount = Format(DocumentAmount, "NFD=2; NDS=.; NZ=0.00; NG=");
			FillingDataRows.Add(DocumentAmount, "ComTransInfo.DocSum=");
			DocumentAmountInNationalCurrency = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"DocumentAmountInNationalCurrency");
			DocumentAmountInNationalCurrency = Format(DocumentAmountInNationalCurrency, "NFD=2; NDS=.; NZ=0.00; NG=");
			FillingDataRows.Add(DocumentAmountInNationalCurrency, "ComTransInfo.DocSumNat=");
			PaymentPriority = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"OrderOfPriority");
			PaymentPriority = Format(PaymentPriority, "NFD=0; NG=");
			FillingDataRows.Add(PaymentPriority, "ComTransInfo.PaymentOrder=");
			PaymentKind = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"PaymentKind");
			FillingDataRows.Add(PaymentKind, "ComTransInfo.PaytKind=");
			PaymentDestination = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(ParseTree,
																											TSRow,
																											"PaymentDestination");
			FillingDataRows.Add(PaymentDestination, "ComTransInfo.Purpose=");
			OperationKind = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"PayKind");
			FillingDataRows.Add(OperationKind, "ComTransInfo.TransKind=");
			AddService = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(ParseTree,
																									TSRow,
																									"AddService");
			FillingDataRows.Add(AddService, "ComTransInfo.UrgentSBRF=");
			DocumentID = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"DocumentID");
			FillingDataRows.Add(DocumentID, "DocId=");
			DescriptionRecipient = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"Recipient");
			FillingDataRows.Add(DescriptionRecipient, "Payee.Name=");
			RecipientAccount = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"PayeeAccount");
			FillingDataRows.Add(RecipientAccount, "Payee.PayeeAcc=");
			PayeeTIN = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(ParseTree,
																										TSRow,
																										"PayeeTIN");
			FillingDataRows.Add(PayeeTIN, "Payee.PayeeTIN=");
			RecipientBankBIC = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"PayeeBIK");
			FillingDataRows.Add(RecipientBankBIC, "PayeeBank.PayeeBankBic=");
			PayeeBankAcc = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"PayeeBankAcc");
			FillingDataRows.Add(PayeeBankAcc, "PayeeBank.PayeeBankCorrAcc=");
			PayeeBankDescription = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"RecipientBankName");
			FillingDataRows.Add(PayeeBankDescription, "PayeeBank.PayeeBankName=");
			PayerDescription = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"Payer1");
			FillingDataRows.Add(PayerDescription, "Payer.Name=");
			PayerAccount = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"PayerAccount");
			FillingDataRows.Add(PayerAccount, "Payer.PayerAcc=");
			PayerTIN = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"PayerTIN");
			FillingDataRows.Add(PayerTIN, "Payer.PayerTIN=");
			PayerBankBIC = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"PayerBIC");
			FillingDataRows.Add(PayerBankBIC, "PayerBank.PayerBankBic=");
			PayerBankAcc = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"PayerBankAcc");
			FillingDataRows.Add(PayerBankAcc, "PayerBank.PayerBankCorrAcc=");
			PayerBankDescription = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"PayerBankName");
																	
			FillingDataRows.Add(PayerBankDescription, "PayerBank.PayerBankName=");
			Revaluation = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"Revaluation");
			FillingDataRows.Add(Revaluation, "s_TI=");
			CodeFiscalClassifications = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"KBKIndicator");
			FillingDataRows.Add(CodeFiscalClassifications, "DepartmentalInfo.Cbc=");
			TaxDocumentDate = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"DateIndicator");
			FillingDataRows.Add(TaxDocumentDate, "DepartmentalInfo.DocDate=");
			TaxDocumentNumber = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"NumberIndicator");
			FillingDataRows.Add(TaxDocumentNumber, "DepartmentalInfo.DocNo=");
			IndicatorStatusOfTaxpayer = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"AuthorStatus");
			FillingDataRows.Add(IndicatorStatusOfTaxpayer, "DepartmentalInfo.DrawerStatus=");
			IndicatorPaymentReasons = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"BasisIndicator");
			FillingDataRows.Add(IndicatorPaymentReasons, "DepartmentalInfo.PaytReason=");
			TypeOfTaxPayment = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"TypeIndicator");
			FillingDataRows.Add(TypeOfTaxPayment, "DepartmentalInfo.TaxPaytKind=");
			TaxablePeriod = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"PeriodIndicator");
			FillingDataRows.Add(TaxablePeriod, "DepartmentalInfo.TaxPeriod=");
			DocumentDateFileCabinet = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"DocSendingDate");
			DocumentDateFileCabinet = Format(DocumentDateFileCabinet, "DF=yyyy-MM-dd");
			FillingDataRows.Add(DocumentDateFileCabinet, "DiffDoc.DocDateCard=");
			NumberDocumentFile = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"NumberDocumentFile");
			FillingDataRows.Add(NumberDocumentFile, "DiffDoc.DocNumberCard=");
			CodeDocumentFileCabinet = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"CodeDocumentFileCabinet");
			FillingDataRows.Add(CodeDocumentFileCabinet, "DiffDoc.DocShifr=");
			AcceptanceTerm = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"AcceptanceTerm");
			AcceptanceTerm = Format(AcceptanceTerm, "NFD=0; NG=");
			FillingDataRows.Add(AcceptanceTerm, "DiffDoc.LetterOfCreditAcceptDate=");
			AdditionalConditionsLetterOfCredit = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"AdditionalConditions");
			FillingDataRows.Add(AdditionalConditionsLetterOfCredit, "DiffDoc.LetterOfCreditAddCond=");
			RequiredDocuments = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"PaymentByRepr");
			FillingDataRows.Add(RequiredDocuments, "DiffDoc.LetterOfCreditDemandDocs=");
			NumberVendorAccount = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"NumberVendorAccount");
			FillingDataRows.Add(NumberVendorAccount, "DiffDoc.LetterOfCreditPayAcc=");
			ConditionsPaymentLetterOfCredit = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"Condition1");
			FillingDataRows.Add(ConditionsPaymentLetterOfCredit, "DiffDoc.LetterOfCreditPaymCond=");
			ValidityPeriodLetterOfCredit = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"PaymentDueDate");
			ValidityPeriodLetterOfCredit = Format(ValidityPeriodLetterOfCredit, "DF=yyyy-MM-dd");
			FillingDataRows.Add(ValidityPeriodLetterOfCredit, "DiffDoc.LetterOfCreditPeriodVal=");
			LetterOfCreditType = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"LetterOfCreditType");
			FillingDataRows.Add(LetterOfCreditType, "DiffDoc.LetterOfCreditType=");
			NumberOfPayment = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"NumberOfPayment");
			FillingDataRows.Add(NumberOfPayment, "DiffDoc.NumPaymentCard=");
			ContentOperations = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"ContentOperations");
			FillingDataRows.Add(ContentOperations, "DiffDoc.OperContent=");
			PaymentCondition = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(ParseTree,
																										TSRow,
																										"PaymentCondition");
			FillingDataRows.Add(PaymentCondition, "DiffDoc.PayingCondition=");
			AmountOfBalanceOfPayment = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"AmountOfBalanceOfPayment");
			If Not AmountOfBalanceOfPayment = Undefined Then
				AmountOfBalanceOfPaymentString = Format(AmountOfBalanceOfPayment, "NFD=2; NDS=.; NZ=0.00; NG=");
				FillingDataRows.Add(AmountOfBalanceOfPaymentString, "DiffDoc.SumRestCard=");
			EndIf;
			AdditionalInformation = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree,
																	TSRow,
																	"AdditionalInformation");
			FillingDataRows.Add(AdditionalInformation, "Info=");
			For Each Item in FillingDataRows Do
				If ValueIsFilled(Item.Value) Then
					ReturnString= ReturnString + Item.Presentation + Item.Value + Char(10);
				EndIf;
			EndDo;
			ReturnString = ReturnString + "#" + ?(IndexOf <> TotalRecords, Char(10), "");
		EndDo;
		
	EndIf;
		
	Return Base64StringWithoutBOM(ReturnString);
	
EndFunction

// Returns signed data string as Base64
//
// Parameters
//  <ED> - <CatalogRef.EDAttachedFiles> - reference to electronic document
//
// Returns:
//   <String>   - data in base64 format
//
Function DigitallySignedDataBase64(ED) Export
	
	ServiceED = ElectronicDocumentsService.ServiceBankED(ED);
	EDData = AttachedFiles.GetFileBinaryData(ServiceED);
	Return Base64String(EDData);
	
EndFunction

// Writes event to the events log monitor
//
// Parameters
//  <EventName> - <String> - Event
//  name <Level> - <String> - Level importance events, possible values: "Information", "Error", "Warning", "Note"
//  <Data> - <Custom> - Data to which
//  event is connected <Comment> - <String> - Random comment to event string.
//
Procedure WriteToEventLogMonitor(DetailsEvents, EventCode, Level, Data = Undefined) Export
	
	MetadataObject = Metadata.FindByType(TypeOf(Data));
	
	ElectronicDocumentsService.WriteEventOnEDToEventLogMonitor(DetailsEvents,
		EventCode, EventLogLevel[Level], MetadataObject, Data);
	
EndProcedure

// Saves signatures validity checking result
//
// Parameters
//  <ED>  - <CatalogRef.EDAttachedFiles> - electronic
//  document <CheckResult>  - <Array> - contains signatures checking results by indexes
//
Procedure FixDSCheckResult(ED, CheckResult) Export

	EDObject = ED.GetObject();
	For Each SignatureRow IN EDObject.DigitalSignatures Do
		If Not (CheckResult[SignatureRow.LineNumber - 1] = Undefined) Then
			SignatureRow.SignatureVerificationDate = CurrentSessionDate();
			SignatureRow.SignatureIsCorrect = CheckResult[SignatureRow.LineNumber - 1];
		EndIf;
	EndDo;
	EDObject.Write();
	
EndProcedure

// Returns an array containing the tests of electronic documents state queries on processing
//
// Parameters
//  <EDAgreement> - <CatalogRef.AgreementsOnEDUsage> - agreement
//  with Sberbank <EDKind> - <EnumRef.EDKinds> - Electronic document kind
//
// Returns:
//   <Array> - contains query texts
//
Function QueriesOnDocumentsDataProcessorsStatesArray(EDAgreement, EDKind) Export
	
	ReturnArray = New Array;
	
	Query = New Query;
	If EDKind = Enums.EDKinds.PaymentOrder Then
		Query.Text =
			"SELECT
			|	EDAttachedFiles.UUIDExternal,
			|	EDAttachedFiles.EDAgreement.CompanyID AS CompanyID
			|FROM
			|	Catalog.EDAttachedFiles AS EDAttachedFiles
			|		LEFT JOIN InformationRegister.EDStates AS EDStates
			|		ON (EDStates.ElectronicDocument = EDAttachedFiles.Ref)
			|WHERE
			|	EDAttachedFiles.EDAgreement = &EDAgreement
			|	AND EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.PaymentOrder)
			|	AND (EDStates.EDVersionState = VALUE(Enum.EDVersionsStates.ExpectedPerformance)
			|			OR EDStates.EDVersionState = VALUE(Enum.EDVersionsStates.NotificationAboutReceivingExpected))
			|	AND Not EDAttachedFiles.UUIDExternal = """"
			|	AND Not EDAttachedFiles.DeletionMark
			|	AND Not EDAttachedFiles.EDStatus = VALUE(Enum.EDStatuses.Rejected)";
	ElsIf EDKind = Enums.EDKinds.QueryStatement Then
		Query.Text =
			"SELECT
			|	EDAttachedFiles.UUIDExternal,
			|	EDAttachedFiles.EDAgreement.CompanyID AS CompanyID
			|FROM
			|	Catalog.EDAttachedFiles AS EDAttachedFiles
			|		LEFT JOIN InformationRegister.EDStates AS EDStates
			|		ON (EDStates.ElectronicDocument = EDAttachedFiles.Ref)
			|WHERE
			|	EDAttachedFiles.EDAgreement = &EDAgreement
			|	AND EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.QueryStatement)
			|	AND Not EDAttachedFiles.UUIDExternal = """"
			|	AND Not EDAttachedFiles.DeletionMark
			|	AND (EDAttachedFiles.EDStatus = VALUE(Enum.EDStatuses.Sent)
			|			OR EDAttachedFiles.EDStatus = VALUE(Enum.EDStatuses.Accepted)
			|			OR EDAttachedFiles.EDStatus = VALUE(Enum.EDStatuses.Delivered))";
	EndIf;
	
	Query.SetParameter("EDAgreement", EDAgreement);
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return ReturnArray;
	EndIf;

	Selection = QueryResult.Select();
	
	While Selection.Next() Do
	
		Try
			Request = ElectronicDocumentsInternal.GetCMLObjectType("Request", "http://www.bssys.com/en/");
			IDRequest = New UUID;
			ErrorText = "";
			ElectronicDocumentsInternal.FillXDTOProperty(
													Request,
													"requestId",
													String(IDRequest),
													True,
													ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(
													Request,
													"orgId",
													Selection.CompanyID,
													True,
													ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(Request, "version", "1.0", True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(Request, "sender", "1C:Enterprise 8", True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(Request, "receiver", "SBBOL_DBO", True, ErrorText);
			
			DocIds = ElectronicDocumentsInternal.GetCMLObjectType("Request.DocIds", "http://www.bssys.com/en/");
			DocId = ElectronicDocumentsInternal.GetCMLObjectType("Request.DocIds.DocId", "http://www.bssys.com/en/");
			ElectronicDocumentsInternal.FillXDTOProperty(
													DocId,
													"docid",
													Selection.UUIDExternal,
													True,
													ErrorText);
			DocIds.DocId.Add(DocId);
			
			ElectronicDocumentsInternal.FillXDTOProperty(Request, "DocIds", DocIds, True, ErrorText);
			
			Request.Validate();
			
			Record = New XMLWriter;
			Record.SetString();
			XDTOFactory.WriteXML(Record, Request);
			QueryText = Record.Close();
			
			If Not IsBlankString(QueryText) Then
				ReturnArray.Add(QueryText);
			EndIf;
			
		Except
			
			MessagePattern = NStr("en='%1. (for more information, see Event log).';ru='%1. (подробности см. в Журнале регистрации).'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
															MessagePattern,
															BriefErrorDescription(ErrorInfo()));
			ProcessExceptionByEDOnServer(
							NStr("en='Generation of electronic document status request';ru='Формирование запроса статуса электроного документа'"),
							DetailErrorDescription(ErrorInfo()),
							MessageText,
							1);

		EndTry
		
	EndDo;
	
	Return ReturnArray;
	
EndFunction

// Returns container number to which certificate is bound in the bank token
//
// Parameters
//  <Certificate>  - <CatalogRef.DSCertificates> - signature
//  certificate <EDAgreement>  - <CatalogRef.EDUsageAgreements> - agreement with Sberbank
//
// Returns:
//   <Number> - Number of the container if -1 - this certificate is not specified in the agreement
//
Function NumberContainer(Certificate, EDAgreement) Export
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	AgreementsOnUseOfEDCertificatesCompanySignatures.NumberContainer
	|FROM
	|	Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsOnUseOfEDCertificatesCompanySignatures
	|WHERE
	|	AgreementsOnUseOfEDCertificatesCompanySignatures.Certificate = &Certificate
	|	AND Not AgreementsOnUseOfEDCertificatesCompanySignatures.Ref.DeletionMark
	|	AND AgreementsOnUseOfEDCertificatesCompanySignatures.Ref.AgreementStatus = VALUE(Enum.EDAgreementsStatuses.Acts)
	|	AND AgreementsOnUseOfEDCertificatesCompanySignatures.Ref = &EDAgreement";
	query.SetParameter("Certificate",   Certificate);
	query.SetParameter("EDAgreement", EDAgreement);
	Result = Query.Execute().Select();
	If Result.Count() = 1 Then
		Result.Next();
		Return Result.NumberContainer;
	EndIf;
	
	Return -1; //the RequiredFieldsCertificates tabular field is not filled in
	
EndFunction

// Determines signature certificate by agreement and container number
//
// Parameters
//  <EDAgreement>  - <CatalogRef.EDUsageAgreements> - agreement
//  with Sberbank <ContainerNumber>  - <Number> - container number
//
// Returns:
//   <CatalogRef.EDSCertificates> or Undefined - found certificate
//
Function CertificateFromEDAgreement(EDAgreement, NumberContainer) Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	AgreementsOnUseOfEDCertificatesCompanySignatures.Certificate
	|FROM
	|	Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsOnUseOfEDCertificatesCompanySignatures
	|WHERE
	|	AgreementsOnUseOfEDCertificatesCompanySignatures.Ref = &EDAgreement
	|	AND AgreementsOnUseOfEDCertificatesCompanySignatures.NumberContainer = &NumberContainer";
	Query.SetParameter("EDAgreement",    EDAgreement);
	Query.SetParameter("NumberContainer", NumberContainer);
	Result = Query.Execute().Select();
	If Result.Next() Then
		Return Result.Certificate;
	EndIf;
	Return Undefined;
	
EndFunction

// Generates a request text of data processor state of bank statement requests that were sent earlier
//
// Parameters:
//  EDAgreement - CatalogRef.AgreementOnEDUse, reference to agreement with bank
//
// Returns:
//  String - text for sending to the bank
//
Function QueryTextQueryStatusBankStatements(EDAgreement) Export
	
	ArrayOfIDs = ArrayOfIDsDocumentsBank(EDAgreement);
	
	If ArrayOfIDs.Count() = 0 Then
		Return "";
	EndIf;
		
	
	Request = ElectronicDocumentsInternal.GetCMLObjectType("Request", "http://www.bssys.com/en/");
	IDRequest = New UUID;
	ErrorText = "";
	ElectronicDocumentsInternal.FillXDTOProperty(
											Request,
											"requestId",
											String(IDRequest),
											True,
											ErrorText);
	ElectronicDocumentsInternal.FillXDTOProperty(
											Request,
											"orgId",
											CommonUse.ObjectAttributeValue(EDAgreement, "CompanyID"),
											True,
											ErrorText);
	ElectronicDocumentsInternal.FillXDTOProperty(Request, "version",  "1.0",               True, ErrorText);
	ElectronicDocumentsInternal.FillXDTOProperty(Request, "sender",   "1C:Enterprise 8", True, ErrorText);
	ElectronicDocumentsInternal.FillXDTOProperty(Request, "receiver", "SBBOL_DBO",         True, ErrorText);
		
	DocIds = ElectronicDocumentsInternal.GetCMLObjectType("Request.DocIds", "http://www.bssys.com/en/");
	For Each ID IN ArrayOfIDs Do
		DocId = ElectronicDocumentsInternal.GetCMLObjectType("Request.DocIds.DocId", "http://www.bssys.com/en/");
		ElectronicDocumentsInternal.FillXDTOProperty(DocId, "docid", ID, True, ErrorText);
		DocIds.DocId.Add(DocId);
	EndDo;
		
	ElectronicDocumentsInternal.FillXDTOProperty(Request, "DocIds", DocIds, True, ErrorText);
		
	Request.Validate();
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XDTOFactory.WriteXML(XMLWriter, Request);
	
	Return XMLWriter.Close();
	
EndFunction

// Returns references to certificates array with which ED can be signed
//
// Parameters
//  <EDAgreement>  - <CatalogRef.EDUsageAgreements> - agreement
//  <EDKind>  - <Enums.EDKinds> - Electronic document kind
//
// Returns:
//   <Array>   - <Array of fitting required certificates>
//
Function GetAvailableBankCertificates(EDAgreement, EDKind) Export

	Query = New Query;
	Query.Text =  "SELECT DISTINCT
	                |	EDUsageAgreementsOutgoingDocuments.Ref,
	                |	EDUsageAgreementsOutgoingDocuments.EDFProfileSettings,
	                |	EDUsageAgreementsOutgoingDocuments.OutgoingDocument
	                |INTO TU_ProfileAndAgreement
	                |FROM
	                |	Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
	                |WHERE
	                |	EDUsageAgreementsOutgoingDocuments.Ref = &Ref
	                |	AND EDUsageAgreementsOutgoingDocuments.ToForm
	                |	AND EDUsageAgreementsOutgoingDocuments.OutgoingDocument = &EDKind
	                |;
	                |				
	                |////////////////////////////////////////////////////////////////////////////////
	                |SELECT ALLOWED DISTINCT
	                |	DigitallySignedEDKinds.DSCertificate AS Ref
	                |FROM
	                |	TU_ProfileAndAgreement AS TU_ProfileAndAgreement
	                |		INNER JOIN InformationRegister.DigitallySignedEDKinds AS DigitallySignedEDKinds
	                |			INNER JOIN Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
	                |				INNER JOIN (SELECT DISTINCT
	                |					EDFProfilesCertificates.Certificate AS Certificate
	                |				FROM
	                |					TU_ProfileAndAgreement AS TU_ProfileAndAgreement
	                |						LEFT JOIN Catalog.EDFProfileSettings.CompanySignatureCertificates AS EDFProfilesCertificates
	                |						ON TU_ProfileAndAgreement.EDFProfileSettings = EDFProfilesCertificates.Ref
	                |				
	                |				UNION ALL
	                |				
	                |				SELECT
	                |					AgreementsEDCertificates.Certificate
	                |				FROM
	                |					TU_ProfileAndAgreement AS TU_ProfileAndAgreement
	                |						LEFT JOIN Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsEDCertificates
	                |						ON TU_ProfileAndAgreement.Ref = AgreementsEDCertificates.Ref) AS CertificatesFromSettingsAndProfiles
	                |				ON Certificates.Ref = CertificatesFromSettingsAndProfiles.Certificate
	                |			ON DigitallySignedEDKinds.DSCertificate = Certificates.Ref
	                |		ON TU_ProfileAndAgreement.OutgoingDocument = DigitallySignedEDKinds.EDKind
	                |WHERE
	                |	(Certificates.User = &User
	                |			OR Certificates.User = VALUE(Catalog.Users.EmptyRef))
	                |	AND Not Certificates.Revoked
	                |	AND Not Certificates.DeletionMark
	                |	AND DigitallySignedEDKinds.Use";
	Query.SetParameter("Ref",       EDAgreement);
	Query.SetParameter("EDKind",        EDKind);
	Query.SetParameter("User", Users.CurrentUser());
	TVResult = Query.Execute().Unload();
	Return TVResult.UnloadColumn("Ref");

EndFunction

//for internal use only
Procedure GenerateEDQueryAccountstatements(EDAgreement, StartDate, EndDate, ED) Export
	
	QueryFile = GetTempFileName();
	
	IsError = False;
	IDRequest="";
	
	ElectronicDocumentsInternal.SetSubscriptionQuery(
										EDAgreement,
										StartDate,
										EndDate,
										IDRequest,
										QueryFile,
										IsError);
	
	If IsError Then
		DeleteFiles(QueryFile);
		Return;
	EndIf;
	
	FileBinaryData = New BinaryData(QueryFile);
	FileURL = PutToTempStorage(FileBinaryData);
	
	FileName = "Statement request from %1 to %2";
	FileName = StringFunctionsClientServer.SubstituteParametersInString(FileName, Format(StartDate, "DLF=D"), Format(EndDate, "DLF=D"));
	CreationTimeED = CurrentSessionDate();
	
	ED = AttachedFiles.AddFile(
									EDAgreement,
									FileName,
									"xml",
									CreationTimeED,
									CreationTimeED,
									FileURL,
									Undefined,
									,
									Catalogs.EDAttachedFiles.GetRef());
	DigestBase64 = Digest(QueryFile, EDAgreement);
	DeleteFiles(QueryFile);
	DigitallySignedData = Base64Value(DigestBase64);
	
	StorageAddress = PutToTempStorage(DigitallySignedData);
	AdditFile = AttachedFiles.AddFile(
						EDAgreement,
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
	FileParameters.Insert("ElectronicDocumentOwner", ED);
	FileParameters.Insert("FileDescription",           "DataSchema");
	FileParameters.Insert("EDStatus",                    Enums.EDStatuses.Created);
	ElectronicDocumentsService.ChangeByRefAttachedFile(AdditFile, FileParameters, False);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("EDStatus", Enums.EDStatuses.Created);
	ParametersStructure.Insert("EDKind", Enums.EdKinds.QueryStatement);
	ParametersStructure.Insert("UniqueId", IDRequest);
	ParametersStructure.Insert("EDAgreement", EDAgreement);
	ParametersStructure.Insert("EDDirection", Enums.EDDirections.Outgoing);
	ParametersStructure.Insert("FileDescription", FileName);
	
	ElectronicDocumentsService.ChangeByRefAttachedFile(ED, ParametersStructure, False);
	
	StatusRecord = InformationRegisters.EDStates.CreateRecordManager();
	StatusRecord.Period = CurrentSessionDate();
	StatusRecord.EDVersionState = Enums.EDVersionsStates.ExchangeCompleted;
	StatusRecord.ObjectReference = CommonUse.ObjectAttributeValue(ED, "FileOwner");
	StatusRecord.ElectronicDocument = ED;
	StatusRecord.Write();
		
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// Certificates

// Receives an array of personal certificates structures to display in the certificates selection dialog to sign or encrypt
//
// Parameters
//  OnlyPersonal  - Boolean - if False, then recipient certificates are also taken 
//
// Returns:
//   Array  - structures array with certificate fields
Function CertificateTumbprintsArray() Export
	
	ThumbprintArray = New Array;
	
	Cancel = False;
	CryptoManager = GetCryptoManager(Cancel);
	If Cancel Then
		Return ThumbprintArray;
	EndIf;
	
	CurrentDate = CurrentSessionDate(); // Used to detect expired certificates that are stored on the client computer.
	
	Storage = CryptoManager.GetCertificateStore(
		CryptoCertificateStoreType.PersonalCertificates);
	CertificatesRepository = Storage.GetAll();
	
	For Each Certificate IN CertificatesRepository Do
		If Certificate.EndDate < CurrentDate Then
			Continue; // Skip expired certificates.
		EndIf;
		
		CertificateStructure = DigitalSignatureClientServer.FillCertificateStructure(Certificate);
		If CertificateStructure <> Undefined Then
			ImprintRow = Base64String(Certificate.Imprint);
			If ThumbprintArray.Find(ImprintRow) = Undefined Then
				ThumbprintArray.Add(ImprintRow);
			EndIf;
		EndIf;
		
	EndDo;
	
	Return ThumbprintArray;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Certificates

// Function receives data by certificates allowed for use during ED
// signing and authorization on EDF operator server. Search for certificates as arrays intersection set in
// a personal storage (client or server depending on settings in 1 c) with certificates imported to 1c
// and registered at EDF operator (registration at the operator is reflected in tab.parts of the "CompanySignaturesCertificates"
// ED exchange agreement). If necessary, the selection can be limited with arrangements
// array by which it is required to determine the certificates parameters.
//
// Parameters:
//  EDFSettingProfilesArray - references array - references to EDF settings profiles according to which it is required to determine certificates;
//  StCertificateStructuresArrays - arrays structure - may contain two items:
//    CertificateStructureArrayServer and CertificateStructureArrayClient respectively  certificate structures array of the
//    personal storage from the server and the same from the client;
//  EDKind - enumeration ref - ED kind for signing of which it is required to find certificate(s). Makes sense
//    only if there is parameter ForSignature = True;
//  ForSignatures - Boolean - True - it is required to find certificates for signing. It makes sense only
//    if the parameter EDKind is filled in;
//  ForAuthorization - Boolean - True - it is required to find certificates for authorization on EDF operator server.
//
// Returns:
//  Matches structure - empty or contains 3 items:
//    AgreementsAndSignatureCertificatesMatch
//    AgreementsAndAuthorizationCertificatesMatch
//    CertificatesAndTheirStructuresMatch
//
Function MatchesAgreementsAndAuthorizationCertificatesStructure(
	Val EDFSettingProfilesArray = Undefined, Val EDKindsArray = Undefined,
	Val StCertificateStructuresArrays = Undefined, Val CertificatesAndPasswordsMatch = Undefined,
	Val OnlyBanks = False) Export
	
	MapStructure = New Structure;
	
	ServerAuthorizationPerform = ServerAuthorizationPerform();
	PerformCryptoOperationsAtServer = PerformCryptoOperationsAtServer();
	// If the deferred sending is used, then you do not need to search for certificates.
	StampArrayClient = New Array;
	ThumbprintArrayServer = New Array;
	
	UseDS = GetFunctionalOptionValue("UseDigitalSignatures");
	If TypeOf(StCertificateStructuresArrays) = Type("Structure") Then
		StCertificateStructuresArrays.Property("ThumbprintArrayServer", ThumbprintArrayServer);
		StCertificateStructuresArrays.Property("StampArrayClient", StampArrayClient);
		If ServerAuthorizationPerform AND Not ValueIsFilled(ThumbprintArrayServer) AND UseDS Then
			Try
				ThumbprintArrayServer = CertificateTumbprintsArray();
			Except
				ThumbprintArrayServer = New Array;
				MessageText = GetMessageAboutError("115");
				CommonUseClientServer.MessageToUser(MessageText);
			EndTry;
		EndIf;
	EndIf;
	
	If (ThumbprintArrayServer <> Undefined AND ThumbprintArrayServer.Count())
		OR (StampArrayClient <> Undefined AND StampArrayClient.Count()) Then
		Query = New Query;
		Query.TempTablesManager = New TempTablesManager;
		QueryText =
		"SELECT
		|	CertificatesTable.Certificate,
		|	CertificatesTable.UserPassword
		|INTO CertificatesTable
		|FROM
		|	&CertificatesTable AS CertificatesTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	EDFProfileSettings.Ref AS EDFProfileSettings,
		|	Certificates.Ref AS SignatureCertificate,
		|	CertificatesTable.UserPassword AS UserPassword,
		|	CASE
		|		WHEN CertificatesTable.Certificate IS NULL 
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS RememberCertificatePassword,
		|	CASE
		|		WHEN CertificatesTable.Certificate IS NULL 
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS PasswordReceived,
		|	Certificates.Imprint,
		|	Certificates.Revoked,
		|	Certificates.CertificateData AS CertificateData,
		|	Certificates.UserNotifiedOnValidityInterval AS NotifiedOnDurationOfActions,
		|	Certificates.ValidUntil AS EndDate,
		|	BankApplications.BankApplication AS BankApplication
		|FROM
		|	Catalog.EDFProfileSettings AS EDFProfileSettings
		|		INNER JOIN Catalog.EDFProfileSettings.CompanySignatureCertificates AS EDFProfileSettingsCertificates
		|			LEFT JOIN Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
		|				LEFT JOIN CertificatesTable AS CertificatesTable
		|				ON (CertificatesTable.Certificate = Certificates.Ref)
		|				LEFT JOIN InformationRegister.BankApplications AS BankApplications
		|				ON BankApplications.DSCertificate = Certificates.Ref
		|			ON EDFProfileSettingsCertificates.Certificate = Certificates.Ref
		|		ON (EDFProfileSettingsCertificates.Ref = EDFProfileSettings.Ref)
		|WHERE
		|	Not Certificates.DeletionMark
		|	AND Not Certificates.Revoked
		|	AND (Certificates.User = &EmptyUser
		|			OR Certificates.User = &CurrentUser)
		|	AND Certificates.Imprint IN(&ThumbprintArrayForAuthorization)
		|	AND &ExchangeMethod
		|	AND &UseDS
		|	AND Not EDFProfileSettings.DeletionMark
		|	AND EDFProfileSettings.Ref IN(&EDFSettingProfilesArray)
		|	AND CASE
		|			WHEN Certificates.ValidUntil = DATETIME(1, 1, 1)
		|				THEN TRUE
		|			WHEN DATEDIFF(&CurrentDate, Certificates.ValidUntil, Day) > 0
		|				THEN TRUE
		|			ELSE FALSE
		|		END
		|
		|ORDER BY
		|	PasswordReceived DESC";
		
		Query.SetParameter("ThumbprintArrayForAuthorization",
				?(ServerAuthorizationPerform, ThumbprintArrayServer, StampArrayClient));
		Query.SetParameter("EmptyUser",  Catalogs.Users.EmptyRef());
		Query.SetParameter("CurrentUser", Users.AuthorizedUser());
			Query.SetParameter("UseDS",     UseDS);
		Query.SetParameter("CurrentDate",         CurrentSessionDate());
		If OnlyBanks Then
			Query.SetParameter("EDExchangeMethod", Enums.EDExchangeMethods.ThroughBankWebSource);
			QueryText = StrReplace(QueryText, "&ExchangeMethod",
			"EDFProfileSettings.EDExchangeMethod = VALUE(Enumeration.EDExchangeMethods.ViaBankWebSource)");
			QueryText = StrReplace(QueryText, "EDFProfileSettings", "EDUsageAgreements");
		Else
			QueryText = StrReplace(QueryText, "&ExchangeMethod",
			"EDFProfileSettings.EDExchangeMethod = VALUE(Enumeration.EDExchangeMethods.ViaEDFOperatorTaxcom)");
		EndIf;
		
		CertificatesWithPasswords = PasswordToCertificate();
		VT_Certificates = New ValueTable;
		VT_Certificates.Columns.Add("Certificate",
			New TypeDescription("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates"));
		VT_Certificates.Columns.Add("UserPassword", New TypeDescription("String"));
		For Each Item IN CertificatesWithPasswords Do
			NewRow = VT_Certificates.Add();
			NewRow.Certificate = Item.Key;
			NewRow.UserPassword = Item.Value;
		EndDo;
		Query.SetParameter("CertificatesTable", VT_Certificates);
		If Not ValueIsFilled(EDFSettingProfilesArray) Then
			EDFSettingProfilesArray = New Array;
		EndIf;
		If ValueIsFilled(EDKindsArray) Then
			EDFSettingProfilesArray = New Array;
			If TypeOf(EDKindsArray) = Type("Array") AND EDKindsArray.Count() > 0 Then
				EDAndAgreementsStructureCorresp = CommonUse.ObjectAttributeValues(EDKindsArray, "EDFProfileSettings");
				For Each EDOwner IN EDAndAgreementsStructureCorresp Do
					EDFProfileSettings = EDOwner.Value.EDFProfileSettings;
					If EDFSettingProfilesArray.Find(EDFProfileSettings) = Undefined Then
						EDFSettingProfilesArray.Add(EDFProfileSettings);
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		If EDFSettingProfilesArray.Count() > 0 Then
			Query.SetParameter("EDFSettingProfilesArray", EDFSettingProfilesArray);
		Else
			QueryText = StrReplace(QueryText, "And EDFProfileSettings.Ref IN (&EDFProfileSettingsArray)", "");
		EndIf;
		Query.Text = QueryText;
		Selection = Query.Execute().Select();
		
		AuthorizationCertificatesArrayAndAgreementsMatch = New Map;
		AccCertificatesAndTheirStructures = New Map;
		
		// For authorization, in addition to the certificates, try to receive markers decrypted if possible.
		
		CryptoManagerAvailableAtServer = False;
		If ServerAuthorizationPerform Then
			Try
				CryptoManager = GetCryptoManager();
				CryptoManagerAvailableAtServer = True;
			Except
				MessageText = GetMessageAboutError("110");
				CommonUseClientServer.MessageToUser(MessageText);
				CryptoManagerAvailableAtServer = False;
			EndTry;
		EndIf;
	
		CurrentEDFProfileSettings = Undefined;
		While Selection.Next() Do
			If CurrentEDFProfileSettings <> Selection.EDFProfileSettings Then
				CertificatesArray = New Array;
				CurrentEDFProfileSettings = Selection.EDFProfileSettings;
			EndIf;
			CertificatesArray.Add(Selection.SignatureCertificate);
			If AuthorizationCertificatesArrayAndAgreementsMatch.Get(CurrentEDFProfileSettings) = Undefined Then
				AuthorizationCertificatesArrayAndAgreementsMatch.Insert(CurrentEDFProfileSettings, CertificatesArray);
			EndIf;
			CertificateStructure = New Structure("SignatureCertificate, PasswordReceived, UserPassword,
													|Thumbprint, Revoked, CertificateData, NotifiedOnValidityDuration, EndDate, RememberCertificatePassword, BankApplication");
			FillPropertyValues(CertificateStructure, Selection);
		
			// Fill in data for authorization.
			If TypeOf(CertificateStructure.CertificateData) = Type("ValueStorage") Then
				PasswordReceived = Selection.PasswordReceived;
				CertificateStructure.Insert("UserPassword", Selection.UserPassword);
				CertificateStructure.Insert("PasswordReceived", PasswordReceived);
				Decrypt = (PasswordReceived AND CryptoManagerAvailableAtServer);
				If CertificateStructure.BankApplication = Enums.BankApplications.AsynchronousExchange Then
					Marker = ElectronicDocumentsInternal.GetBankMarker(
						CurrentEDFProfileSettings, CertificateStructure, Decrypt);
					If Marker = Undefined Then
						Continue;
					EndIf;
				Else
					Join = ElectronicDocumentsInternal.GetConnection();
					Marker = ElectronicDocumentsInternal.GetMarkerEEDF(CertificateStructure, Join, Decrypt);
				EndIf;
				If TypeOf(Marker) = Type("BinaryData") Then
					If Decrypt Then
						CertificateStructure.Insert("MarkerTranscribed", Marker);
					Else
						CertificateStructure.Insert("MarkerEncrypted", Marker);
					EndIf;
				EndIf;
			EndIf;
		
			AccCertificatesAndTheirStructures.Insert(Selection.SignatureCertificate, CertificateStructure);
			
		EndDo;
		
		MapStructure.Insert("AuthorizationCertificatesArrayAndAgreementsMatch", AuthorizationCertificatesArrayAndAgreementsMatch);
		MapStructure.Insert("AccCertificatesAndTheirStructures", AccCertificatesAndTheirStructures);
	EndIf;
	
	Return MapStructure;
	
EndFunction

// Function checks if there is a decrypted marker in the structure. If
// there is not, try to decrypt the encrypted marker if decryption was successful, then the decrypted marker is put to the structure.
//
// Parameters:
//  CertificateStructure - structure - contains DS certificate and its
//    parameters including the decrypted or encrypted marker.
//
// Returns:
//  Boolean - True - there is a decrypted marker in the structure, otherwise, - False.
//
Function DecryptMarkerFromStructureOfCertificateAtServer(CertificateStructure) Export
	
	Decrypted = False;
	
	If TypeOf(CertificateStructure) = Type("Structure") Then
		MarkerTranscribed = Undefined;
		MarkerEncrypted = Undefined;
		CryptoManager = Undefined;
		If ServerAuthorizationPerform() Then
			Try
				CryptoManager = GetCryptoManager();
			Except
				MessageText = GetMessageAboutError("110");
				CommonUseClientServer.MessageToUser(MessageText);
				CryptoManager = Undefined;
			EndTry;
		EndIf;
		
		If CertificateStructure.Property("MarkerTranscribed", MarkerTranscribed)
			AND ValueIsFilled(MarkerTranscribed) Then
			Decrypted = True;
		ElsIf CertificateStructure.Property("MarkerEncrypted", MarkerEncrypted)
			AND ValueIsFilled(MarkerEncrypted) AND CryptoManager <> Undefined Then
			Try
				ValidateCertificateValidityPeriod(CertificateStructure.SignatureCertificate);
				CertificateStructure.Property("UserPassword", CryptoManager.PrivateKeyAccessPassword);
				Marker = CryptoManager.Decrypt(MarkerEncrypted);
				If ValueIsFilled(Marker) Then
					Decrypted = True;
					CertificateStructure.Insert("MarkerTranscribed", Marker);
				EndIf;
			Except
			EndTry;
		EndIf;
	EndIf;
	
	Return Decrypted;
	
EndFunction

// Function is used to minimize server calls in case there are several
// ED arrays that require signing with certificates and the execution of crypto operations on server is specified in settings.
//
// Parameters:
//  MapOfEDCertificatesAndArraysToSignatures - Map - Key - catalog-ref
//    DSCertificate, value - array of references to the signed EDs. After you sign EDs, you may need
//    to send them, that is why if you failed to sign ED array - , then it is deleted from match.
//  AccCertificatesAndTheirStructures - Map - Key - catalog-ref
//    DSCertificate, value - DS certificate parameters structure.
//  NotSignedEDArray - Array or Undefined, to this variable to the calling procedure
//    ED array is returned, which have not been signed.
//
// Returns:
//  Number - signed EDs quantity.
//
Function SignEDAtServer(MapOfEDCertificatesAndArraysToSignatures,
								Val AccCertificatesAndTheirStructures,
								NotSignedEDArray = Undefined) Export
	
	DigitallySignedCnt = 0;
	If TypeOf(NOTSignedEDArray) <> Type("Array") Then
		NotSignedEDArray = New Array;
	EndIf;
	If TypeOf(MapOfEDCertificatesAndArraysToSignatures) = Type("Map")
		AND MapOfEDCertificatesAndArraysToSignatures.Count() > 0
		AND TypeOf(AccCertificatesAndTheirStructures) = Type("Map")
		AND AccCertificatesAndTheirStructures.Count() > 0 Then
		DeletingArray = New Array;
		For Each Item IN MapOfEDCertificatesAndArraysToSignatures Do
			Certificate = Item.Key;
			EDKindsArray = Item.Value;
			If Not (ValueIsFilled(Certificate) AND ValueIsFilled(EDKindsArray)) Then
				DeletingArray.Add(Certificate.Key);
				For Each NotSignedED IN EDKindsArray Do
					NotSignedEDArray.Add(NOTSignedED);
				EndDo;
				Continue;
			EndIf;
			CertificateStructure = AccCertificatesAndTheirStructures.Get(Certificate);
			If Not ValueIsFilled(CertificateStructure) Then
				DeletingArray.Add(Certificate.Key);
				For Each NotSignedED IN EDKindsArray Do
					NotSignedEDArray.Add(NOTSignedED);
				EndDo;
				Continue;
			EndIf;
			DigitallySigned = SignEDWithAppointedCertificate(EDKindsArray, Certificate, CertificateStructure, NotSignedEDArray);
			If DigitallySigned > 0 Then
				DigitallySignedCnt = DigitallySignedCnt + DigitallySigned;
			EndIf;
		EndDo;
		For Each Item IN DeletingArray Do
			MapOfEDCertificatesAndArraysToSignatures.Delete(Item);
		EndDo;
	EndIf;
	
	Return DigitallySignedCnt;
	
EndFunction

// Before you generate service EDs (ED receipt notification) those ED are
// deleted from array for which the notifications should not be generated (for
// example, during TORG-12 receipt customer title during the exchange by the order 2.0).
//
// Parameters:
//  EDKindsArray - Electronic documents array based on which notifications should be generated.
//
Procedure DeleteNonProcessingEDFromArray(EDKindsArray) Export
	
	ObjectsAttributes = CommonUse.ObjectAttributeValues(EDKindsArray, "EDFScheduleVersion, EDKind, EDAgreement");
	For Each Item IN ObjectsAttributes Do
		Value = Item.Value;
		PackageFormatVersion = CommonUse.ObjectAttributesValues(Value.EDAgreement, "PackageFormatVersion");
		
		If (Value.EDFScheduleVersion = Enums.Exchange1CRegulationsVersion.Version20
			Or PackageFormatVersion = Enums.EDPackageFormatVersions.Version30)
			
			AND (Value.EDKind = Enums.EDKinds.TORG12Customer
				OR Value.EDKind = Enums.EDKinds.ActCustomer
				OR Value.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient) Then
				
			EDKindsArray.Delete(EDKindsArray.Find(Item.Key));
			
		EndIf;
		
		
	EndDo;
	
EndProcedure

// Returns match with available certificates data.
//
// Parameters:
//   CertificateStructuresArrayClient - Array - array of
//      certificates structures set to the personal storage on user computer.
//   EDFSetup - CatalogRef.EDExchangeAgreements - Certificates
//                  will be selected registered in the specified agreement and available to the current user.
//   -----//----- - CatalogRef.EDFProfileSettings - certificates
//                  will be selected registered in the specified profile and available to the current user.
//   -----//----- - Undefined - certificates available to the current user will be selected.
//   ForAuthorization - Boolean - if True - then certificates selection is
//                  executed for authentication on EDF operator server.
//
// Returns:
//  Map:
//     Key - CatalogRef.DigitalSignatureAndEncryptionKeyCertificates.
//     Value - Structure - certificate data.
//
Function MatchAvailableCertificatesAndSettings(Val ClientCertificateTumbprintsArray,
	Val EDFSetup = Undefined, Val ForAuthorization = False) Export
	
	If ForAuthorization Then
		SearchOnServer = ServerAuthorizationPerform();
	Else
		SearchOnServer = PerformCryptoOperationsAtServer();
	EndIf;
	If SearchOnServer Then
		CertificateTumbprintsArray = CertificateTumbprintsArray();
	Else
		CertificateTumbprintsArray = ClientCertificateTumbprintsArray;
	EndIf;
	StructuresArray = ElectronicDocumentsService.ArrayOfStructuresAvailableForSigningCertificates(
														CertificateTumbprintsArray, EDFSetup);
	
	CertificatesAndPasswordsMatch = PasswordToCertificate();
	ReturnData = New Map;
	If TypeOf(StructuresArray) = Type("Array") Then
		For Each Item IN StructuresArray Do
			PasswordToCertificate = CertificatesAndPasswordsMatch.Get(Item.Certificate);
			If PasswordToCertificate <> Undefined Then
				Item.UserPassword = PasswordToCertificate;
				Item.PasswordReceived = True;
			EndIf;
			ReturnData.Insert(Item.Certificate, Item);
		EndDo;
	EndIf;
	
	Return ReturnData;
	
EndFunction



#EndRegion

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Work with versions

Procedure DeleteOldEDVersion(WriteSet)
	
	VersionStructure =  ElectronicDocumentsService.GetEDVersionStructure(WriteSet.ObjectReference);
	
	If ValueIsFilled(VersionStructure.DocumentRef)
		AND (VersionStructure.EDStatus = Enums.EDStatuses.Created
		OR VersionStructure.EDStatus = Enums.EDStatuses.Approved) Then
		
		DocumentObject = VersionStructure.DocumentRef.GetObject();
		DocumentObject.DeletionMark = True;
		DocumentObject.Write();
		
		// Delete subordinate electronic additional files.
		Query = New Query;
		Query.Text =
		"SELECT
		|	EDAttachedFiles.Ref
		|FROM
		|	Catalog.EDAttachedFiles AS EDAttachedFiles
		|WHERE
		|	EDAttachedFiles.ElectronicDocumentOwner = &ElectronicDocumentOwner
		|	AND Not EDAttachedFiles.DeletionMark";
		Query.SetParameter("ElectronicDocumentOwner", VersionStructure.DocumentRef);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			DocumentObject = Selection.Ref.GetObject();
			DocumentObject.DeletionMark = True;
			DocumentObject.Write();
		EndDo;
		
	EndIf;
	
EndProcedure

Function EDVersionState(RefToOwner)
	
	ReturnValue = Enums.EDVersionsStates.EmptyRef();
	EDVersionStructure =  ElectronicDocumentsService.GetEDVersionStructure(RefToOwner);
	
	If EDVersionStructure.Property("EDVersionState") Then
		Comment = Undefined;
		AddClosureReason = (EDVersionStructure.EDVersionState = Enums.EDVersionsStates.ClosedForce);
		If AddClosureReason Then
			EDVersionStructure.Property("CommentIR", Comment);
			Cause = StrReplace(NStr("en='(reason: %1)';ru='(причина: %1)'"), "%1", ?(ValueIsFilled(Comment), Comment, "not specified"));
			ReturnValue = String(EDVersionStructure.EDVersionState) + Chars.NBSp + Cause;
		Else
			ReturnValue = String(EDVersionStructure.EDVersionState);
		EndIf;
	EndIf;
	
	Return ReturnValue;
	
EndFunction

Function GetTextEDSummaryState(RefToOwner)
	
	SetPrivilegedMode(True);
	
	SummaryStateText = "";
	
	RefArray = New Array;
	RefArray.Add(RefToOwner);
	DataTable = GetDataEDByOwners(RefArray);

	If DataTable.Count() > 0 Then
		String = DataTable[0];
		
		TextFromOurSide = "";
		TextFromOtherParticipantSide = "";
		
		If String.EDVersionState = Enums.EDVersionsStates.ClosedForce Then
			SummaryStateText = NStr("en='Closed forcefully.';ru='Закрыт принудительно.'");
		Else
			If ValueIsFilled(String.ActionsFromOurSide)
				AND String.ActionsFromOurSide = Enums.EDConsolidatedStates.ActionsNeeded Then
				
				TextFromOurSide = NStr("en='From our side';ru='с нашей стороны'");
			EndIf;
			If ValueIsFilled(String.ActionsFromOtherPartySide)
				AND String.ActionsFromOtherPartySide = Enums.EDConsolidatedStates.ActionsNeeded Then
				
				TextFromOtherParticipantSide = NStr("en='from other participants';ru='со стороны других участников'");
			EndIf;
			If ValueIsFilled(TextFromOurSide) OR ValueIsFilled(TextFromOtherParticipantSide) Then
				
				SummaryStateText = NStr("en='Actions are required';ru='Требуются действия'")+ " " + TextFromOurSide
					+ ?(ValueIsFilled(TextFromOurSide) AND ValueIsFilled(TextFromOtherParticipantSide), " and ", "")
					+ TextFromOtherParticipantSide;
			ElsIf ValueIsFilled(String.ActionsFromOurSide)
				AND String.ActionsFromOurSide = Enums.EDConsolidatedStates.AllExecuted
				AND ValueIsFilled(String.ActionsFromOtherPartySide)
				AND String.ActionsFromOtherPartySide = Enums.EDConsolidatedStates.AllExecuted Then
				
				If String.EDVersionState = Enums.EDVersionsStates.ExchangeCompleted Then
					SummaryStateText = NStr("en='Exchange completed.';ru='Обмен завершен.'");
				ElsIf String.EDVersionState = Enums.EDVersionsStates.ExchangeCompletedWithCorrection Then
					SummaryStateText = NStr("en='Exchange completed (with correction)';ru='Обмен завершен (с исправлением)'");
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	Return SummaryStateText;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Electronic documents signature 

// Checks whether all necessary signatures are set before sending to counterparty.
// 
// Parameters:
//  ElectronicDocument - references to attached file.
//
Function ElectronicDocumentFullyDigitallySigned(ElectronicDocument)
	
	FlagFullyDigitallySigned = True;
	
	If ElectronicDocument.EDKind = Enums.EDKinds.RandomED Then
		Return FlagFullyDigitallySigned;
	EndIf;
	
	If ElectronicDocument.EDDirection = Enums.EDDirections.Intercompany Then
		VT = ElectronicDocument.DigitalSignatures.Unload(, "Imprint");
		VT.GroupBy("Imprint");
		FlagFullyDigitallySigned = VT.Count() > 1;
	ElsIf ElectronicDocument.EDKind = Enums.EDKinds.PaymentOrder Then
		Query = New Query;
		Query.Text =
		"SELECT
		|	Certificates.Ref AS Certificate,
		|	EDAttachedFilesDigitalSignatures.Imprint AS Imprint
		|INTO SetSignatures
		|FROM
		|	Catalog.EDAttachedFiles.DigitalSignatures AS EDAttachedFilesDigitalSignatures
		|		LEFT JOIN Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
		|		ON EDAttachedFilesDigitalSignatures.Imprint = Certificates.Imprint
		|WHERE
		|	EDAttachedFilesDigitalSignatures.Ref = &ED
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AgreementsOnUseOfEDCertificatesCompanySignatures.Certificate AS Certificate
		|FROM
		|	Catalog.EDUsageAgreements.CompanySignatureCertificates AS AgreementsOnUseOfEDCertificatesCompanySignatures
		|WHERE
		|	AgreementsOnUseOfEDCertificatesCompanySignatures.Ref = &Agreement
		|	AND Not AgreementsOnUseOfEDCertificatesCompanySignatures.Certificate In
		|				(SELECT
		|					SeSig.Certificate
		|				FROM
		|					SetSignatures AS SeSig)";
		
		Query.SetParameter("Agreement", CommonUse.ObjectAttributeValue(ElectronicDocument,"EDAgreement"));
		Query.SetParameter("ED", ElectronicDocument);
		Result = Query.Execute().Select();
		If Result.Next() Then
			FlagFullyDigitallySigned = False;
		EndIf;
	Else
		// Array of all set DS to EDs thumbprints
		CertificateTumbprintsArray = ElectronicDocument.DigitalSignatures.UnloadColumn("Imprint");
		
		// Select all relevant certificates by the currentcompanies and curr.ED
		// kind matching set DS certificates.
		Query = New Query;
		Query.Text =
		"SELECT
		|	Certificates.Ref AS DSCertificate
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
		|	EDEPKinds.EDKind = &DocumentKind
		|	AND Certificates.Imprint IN(&CertificateTumbprintsArray)
		|	AND Not Certificates.Revoked
		|	AND Not Certificates.DeletionMark";
		Query.SetParameter("CertificateTumbprintsArray", CertificateTumbprintsArray);
		Query.SetParameter("Ref",                       ElectronicDocument);
		Query.SetParameter("DocumentKind",                 ElectronicDocument.EDKind);
		
		FlagFullyDigitallySigned = Not Query.Execute().IsEmpty();
		
	EndIf;
	
	ElectronicDocumentsOverridable.ElectronicDocumentFullyDigitallySigned(ElectronicDocument, FlagFullyDigitallySigned);
	
	Return FlagFullyDigitallySigned;
	
EndFunction

Procedure SetLatestSignaturesStatus(ED)
	
	EDObject = ED.GetObject();
	
	DSRow = EDObject.DigitalSignatures[EDObject.DigitalSignatures.Count()-1];
	DSRow.SignatureVerificationDate = CurrentSessionDate();
	DSRow.SignatureIsCorrect = True;
		
	EDObject.Write();

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Exchange via email

Function SendByEmail(PreparedDocuments, DirectoryWithAttachmentsAddress)
	
	AccordanceOfAttachments = GenerateAttachmentsCorrespondence(DirectoryWithAttachmentsAddress);
	Result = TransferLetterWithAttachments(PreparedDocuments, AccordanceOfAttachments);
	DeleteFiles(DirectoryWithAttachmentsAddress);
	
	Return Result;
	
EndFunction

Function GenerateAttachmentsCorrespondence(AttachmentsDirectory, OnlySignatures = False)
	
	AvailableExtensionsList = GenerateCertificatesExtensionsList();
	ConformityOfReturn = New Map;
	AttachmentsList = FindFiles(AttachmentsDirectory, "*");
	For Each AttachmentsFile IN AttachmentsList Do
		If OnlySignatures AND Find(AttachmentsFile.Extension, AvailableExtensionsList) = 0 Then
			Continue;
		EndIf;
		
		If AttachmentsFile.IsFile() Then
			ConformityOfReturn.Insert(AttachmentsFile.Name, New BinaryData(AttachmentsFile.FullName));
		EndIf;
		
	EndDo;
	
	Return ConformityOfReturn;
	
EndFunction

// Sends message with attachments by ED pack.
//
// Parameters:
//  Envelop - Ref to the "EDPack" document - electronic documents pack
//  prepared for sending, AttachmentsMatch - Match, list of files nested to the electronic documents pack.
//
Function TransferLetterWithAttachments(EDPackage, AccordanceOfAttachments)
	
	EDPackageAttributes = CommonUse.ObjectAttributesValues(
							EDPackage,
							"Sender, Receiver, CounterpartyResourceAddress, CompanyResourceAddress, EDFProfileSettings");
	Password = CommonUse.ObjectAttributeValue(EDPackageAttributes.CompanyResourceAddress, "Password");
	
	Recipient  = EDPackageAttributes.Recipient;
	Sender = EDPackageAttributes.Sender;
	
	SendingParameters = New Structure();
	SendingParameters.Insert("Whom",     EDPackageAttributes.CounterpartyResourceAddress);
	SendingParameters.Insert("Subject",     GenerateLetterSubject(Sender, Recipient));
	SendingParameters.Insert("Body",     );
	SendingParameters.Insert("Attachments", AccordanceOfAttachments);
	SendingParameters.Insert("Password",   Password);
	
	Try
		EmailOperations.SendMessage(EDPackageAttributes.CompanyResourceAddress, SendingParameters);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		Text = NStr("en='An error occurred while sending message to email server by %1 EDF settings profile.
		|%2';ru='Ошибка при отправке сообщения на сервер электронной почты по профилю настроек ЭДО %1.
		|%2'");
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
																	Text,
																	EDPackageAttributes.EDFProfileSettings,
																	ErrorText);
		
		MessagePattern = NStr("en='An error occurred while sending e-documents by EDF settings profile: %1, exchange method: %2.
		|(see details in Event log monitor).';ru='Ошибка при отправке эл.документов по профилю настроек ЭДО: %1, способ обмена: %2.
		|(подробности см. в Журнале регистрации).'"); 
								

		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
								MessagePattern,
								EDPackageAttributes.EDFProfileSettings,
								Enums.EDExchangeMethods.ThroughEMail);
		OperationKind = NStr("en='Sending electronic documents';ru='Отправка эл.документов'");
		ProcessExceptionByEDOnServer(
							OperationKind,
							ErrorText,
							MessageText);
 		Return 0;
	EndTry;
	
	Return 1;
	
EndFunction

Function GenerateLetterSubject(Sender, Recipient)
	
	Return NStr("en='Exchange electronic documents:';ru='Обмен эл.документами:'")+ " " + Sender + ?(ValueIsFilled(Recipient), " -> " + Recipient, "");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Processing the electronic documents

// Sets the flag showing that electronic document was approved.
//
// Parameters:
//  AttachedFile - ref to electronic document that should be processed.
//  NewED - ref to electronic document if a new electronic document is created while approving.
//
Procedure SetSignConfirmed(AttachedFile, NewED)
	
	// Check whether all required conditions are met
	If ElectronicDocumentsOverridable.ElectronicDocumentReadyToBeConfirmed(AttachedFile) Then
		Try
			
			NewEDStatus = ElectronicDocumentsService.GetAdmissibleEDStatus(
																	Enums.EDStatuses.Approved,
																	AttachedFile);
			
			ParametersStructure = New Structure;
			ParametersStructure.Insert("EDStatus", NewEDStatus);
			ParametersStructure.Insert("Changed",  Users.AuthorizedUser());
			
			ElectronicDocumentsService.ChangeByRefAttachedFile(AttachedFile, ParametersStructure, False);
			
			ElectronicDocumentsOverridable.ConfirmedStatusApplied(AttachedFile);
		Except
			If TransactionActive() Then
				RollbackTransaction();
			EndIf;
			MessageText = BriefErrorDescription(ErrorInfo())
				+ NStr("en=' (see details in Event log monitor).';ru=' (подробности см. в Журнале регистрации).'");
			ErrorText = DetailErrorDescription(ErrorInfo());
			ProcessExceptionByEDOnServer(NStr("en='ED Approval';ru='утверждение ЭД'"), ErrorText, MessageText);
		EndTry;
	EndIf;
	
	If TransactionActive() AND AttachedFile.EDDirection = Enums.EDDirections.Incoming
		AND (AttachedFile.EDKind = Enums.EDKinds.TORG12Seller
		OR AttachedFile.EDKind = Enums.EDKinds.ActPerformer
		OR AttachedFile.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender) Then
		
		If AttachedFile.EDKind = Enums.EDKinds.TORG12Seller Then
			EDKind = Enums.EDKinds.TORG12Customer;
		ElsIf AttachedFile.EDKind = Enums.EDKinds.ActPerformer Then
			EDKind = Enums.EDKinds.ActCustomer;
		ElsIf AttachedFile.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender Then
			EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient;
		EndIf;
		
		FileOwner = CommonUse.ObjectAttributeValue(AttachedFile, "FileOwner");
		If GetCurrentEDFConfiguration(FileOwner,, EDKind) Then
			
			If EDKind = Enums.EDKinds.TORG12Customer Then
				NewED = ElectronicDocumentsInternal.GenerateEDTorg12Buyer(AttachedFile);
			ElsIf EDKind = Enums.EDKinds.ActCustomer Then
				NewED = ElectronicDocumentsInternal.GenerateEDAct501Customer(AttachedFile);
			ElsIf EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient Then
				NewED = ElectronicDocumentsInternal.GenerateCorDocumentEDRecipient(AttachedFile);
			EndIf;
			
			If NewED = Undefined Then
				RollbackTransaction();
			Else
				EDKindsArray = New Array;
				EDKindsArray.Add(NewED);
				
				ExchangeSettings = ElectronicDocumentsService.EDExchangeSettings(NewED);
				ElectronicDocumentsService.CreateEDPackageDocuments(EDKindsArray, ExchangeSettings.UseSignature);
			EndIf;
			
		Else
			
			If TransactionActive() Then
				RollbackTransaction();
			EndIf;	
		EndIf;
	EndIf;
	
EndProcedure

// Deletes from array objects for which new EDs generating is prohibited.
//
// Parameters
//  RefsArray  - Array - references array
//
Procedure DeleteInaccessibleForGeneratingEDObjects(RefArray)

	Query = New Query;
	Query.Text =
	"SELECT
	|	EDStates.ObjectReference
	|FROM
	|	InformationRegister.EDStates AS EDStates
	|WHERE
	|	EDStates.ObjectReference IN(&RefArray)
	|	AND CASE
	|			WHEN EDStates.ElectronicDocument.EDKind = VALUE(Enum.EDKinds.PaymentOrder)
	|				THEN EDStates.ElectronicDocument.EDStatus <> VALUE(Enum.EDStatuses.Rejected)
	|						AND EDStates.ElectronicDocument.EDStatus <> VALUE(Enum.EDVersionsStates.NotFormed)
	|			ELSE Not(EDStates.ElectronicDocument.EDStatus = VALUE(Enum.EDStatuses.Created)
	|						OR EDStates.ElectronicDocument.EDStatus = VALUE(Enum.EDStatuses.Approved)
	|						OR EDStates.ElectronicDocument.EDStatus = VALUE(Enum.EDStatuses.DigitallySigned)
	|						OR EDStates.ElectronicDocument.EDStatus = VALUE(Enum.EDStatuses.PartlyDigitallySigned)
	|						OR EDStates.ElectronicDocument.EDStatus = VALUE(Enum.EDStatuses.TransferError))
	|		END";
	Query.SetParameter("RefArray", RefArray);
	
	Result = Query.Execute().Select();
	While Result.Next() Do
		IndexOf = RefArray.Find(Result.ObjectReference);
		RefArray.Delete(IndexOf);
		MessagePattern = NStr("en='Relevant electronic document already exists for document %1.';ru='Для документа %1 уже есть актуальный электронный документ.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Result.ObjectReference);
		CommonUseClientServer.MessageToUser(MessageText);
	EndDo;

EndProcedure

// Defines if it is
// necessary to execute an action with electronic document on your
// side or it it is required to wait for customer action based on the current electronic document status.
//
// Parameters:
//  LinkToED - CatalogRef.EDAttachedFiles, reference to electronic document.
//
Function DetermineSummaryInformationByEDStatus(LinkToED) Export
	
	SetPrivilegedMode(True);
	
	EDParameters = CommonUse.ObjectAttributesValues(LinkToED, "EDKind, EDStatus,
	|EDDirection, EDFScheduleVersion, EDAgreement, EDFProfileSettings, ElectronicDocumentOwner, FileOwner");
	
	ActionsStructure = New Structure("FromOurSide, FromOtherPartySide",
		Enums.EDConsolidatedStates.NoActionsNeeded, Enums.EDConsolidatedStates.NoActionsNeeded);
	If LinkToED <> Undefined Then
		
		If EDParameters.EDStatus = Enums.EDStatuses.Created
			OR EDParameters.EDStatus = Enums.EDStatuses.Approved
			OR EDParameters.EDStatus = Enums.EDStatuses.DigitallySigned
			OR EDParameters.EDStatus = Enums.EDStatuses.Received
			OR EDParameters.EDStatus = Enums.EDStatuses.PreparedToSending
			OR EDParameters.EDStatus = Enums.EDStatuses.ConfirmationPrepared Then
			
			ActionsStructure.FromOurSide = Enums.EDConsolidatedStates.ActionsNeeded;
			
			// If exchange is direct and response ED to the sent ED is received, then no actions are required on your part.
			If EDParameters.EDStatus = Enums.EDStatuses.Received
				AND ValueIsFilled(EDParameters.ElectronicDocumentOwner) Then
				
				EDExchangeMethod = CommonUse.ObjectAttributeValue(EDParameters.EDFProfileSettings, "EDExchangeMethod");
				If EDExchangeMethod = Enums.EDExchangeMethods.ThroughDirectory
					OR EDExchangeMethod = Enums.EDExchangeMethods.ThroughFTP Then
					
					ActionsStructure.FromOurSide = Enums.EDConsolidatedStates.NoActionsNeeded;
				EndIf;
			EndIf;
		EndIf;
		
		If EDParameters.EDStatus = Enums.EDStatuses.TransferedToOperator
			OR EDParameters.EDStatus = Enums.EDStatuses.Sent Then
			
			ActionsStructure.FromOtherPartySide = Enums.EDConsolidatedStates.ActionsNeeded;
		EndIf;
		
		If (EDParameters.EDFScheduleVersion = Enums.Exchange1CRegulationsVersion.Version20
			AND (EDParameters.EDKind = Enums.EDKinds.TORG12Customer
			OR EDParameters.EDKind = Enums.EDKinds.ActCustomer
			OR EDParameters.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient))
			OR (NOT EDParameters.EDFScheduleVersion = Enums.Exchange1CRegulationsVersion.Version20
			AND EDParameters.EDKind = Enums.EDKinds.NotificationAboutReception) Then
			
			EDStatus = Undefined;
			If ElectronicDocumentsService.HasUnsentConfirmation(EDParameters.FileOwner, EDStatus) Then
				ActionsStructure.FromOurSide = Enums.EDConsolidatedStates.ActionsNeeded;
			Else
				ActionsStructure.FromOurSide = Enums.EDConsolidatedStates.NoActionsNeeded;
			EndIf;
			
		EndIf;
		
		If EDParameters.EDStatus = Enums.EDStatuses.TransferedToOperator
			AND (EDParameters.EDKind = Enums.EDKinds.ActCustomer
			OR EDParameters.EDKind = Enums.EDKinds.TORG12Customer
			OR EDParameters.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient) Then
			ActionsStructure.FromOtherPartySide = Enums.EDConsolidatedStates.NoActionsNeeded;
		EndIf;
		
		If EDParameters.EDStatus = Enums.EDStatuses.Delivered
			AND EDParameters.EDDirection = Enums.EDDirections.Outgoing
			AND (EDParameters.EDKind = Enums.EDKinds.AcceptanceCertificate
			OR EDParameters.EDKind = Enums.EDKinds.RightsDelegationAct
			OR EDParameters.EDKind = Enums.EDKinds.ProductsReturnBetweenCompanies
			OR EDParameters.EDKind = Enums.EDKinds.ProductsDirectory
			OR EDParameters.EDKind = Enums.EDKinds.ComissionGoodsSalesReport
			OR EDParameters.EDKind = Enums.EDKinds.ComissionGoodsWriteOffReport
			OR EDParameters.EDKind = Enums.EDKinds.GoodsTransferBetweenCompanies
			OR EDParameters.EDKind = Enums.EDKinds.PriceList
			OR EDParameters.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender
			OR EDParameters.EDKind = Enums.EDKinds.ActPerformer
			OR EDParameters.EDKind = Enums.EDKinds.TORG12
			OR EDParameters.EDKind = Enums.EDKinds.TORG12Seller
			OR EDParameters.EDKind = Enums.EDKinds.ProductOrder
			OR EDParameters.EDKind = Enums.EDKinds.ResponseToOrder) Then
			ActionsStructure.FromOtherPartySide = Enums.EDConsolidatedStates.ActionsNeeded;
		EndIf;
		
		If EDParameters.EDStatus = Enums.EDStatuses.CancellationOfferReceived Then
			ActionsStructure.FromOurSide = Enums.EDConsolidatedStates.ActionsNeeded;
		ElsIf EDParameters.EDStatus = Enums.EDStatuses.CancellationOfferCreated
			OR EDParameters.EDStatus = Enums.EDStatuses.CancellationOfferSent Then
			ActionsStructure.FromOtherPartySide = Enums.EDConsolidatedStates.ActionsNeeded;
		EndIf;
			
	EndIf;
	
	If ActionsStructure.FromOtherPartySide = Enums.EDConsolidatedStates.NoActionsNeeded
		AND ActionsStructure.FromOurSide = Enums.EDConsolidatedStates.NoActionsNeeded Then
		
		ActionsStructure.FromOurSide = Enums.EDConsolidatedStates.AllExecuted;
		ActionsStructure.FromOtherPartySide = Enums.EDConsolidatedStates.AllExecuted;
	EndIf;
	
	Return ActionsStructure;
	
EndFunction

// Recursive procedure, receives all subordinate electronic documents with any nesting depth.
//
// Parameters:
//  EDOwnersArray - references array to electronic documents owners (for the current integration - selected EDs owner).
//  EDKindsArray - array of subordinate electronic documents (increased by the quantity of the found ED with each integration ).
//             Electronic document - owner is added to this array separately (before and after this procedure call).
//
Procedure SelectSubordinatedED(Val EDOwnersArray, EDKindsArray)

	Query = New Query;
	Query.Text =
	"SELECT
	|	EDAttachedFiles.Ref
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.ElectronicDocumentOwner IN(&EDOwnersArray)";
	Query.SetParameter("EDOwnersArray", EDOwnersArray);
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		
		EDOwnersArray = Result.Unload().UnloadColumn("Ref");
		For Each Item IN EDOwnersArray Do
			
			EDKindsArray.Add(Item);
			
		EndDo;
		SelectSubordinatedED(EDOwnersArray, EDKindsArray);
		
	EndIf;
	
EndProcedure

Function DetermineDirection(EDFileStructure)
	
	If (EDFileStructure.EDKind = Enums.EDKinds.ProductOrder)
		AND EDFileStructure.SellerSign Then
			Return Enums.EDDirections.Outgoing;
	EndIf;
	
	Return Enums.EDDirections.Incoming;
	
EndFunction

Function CanRejectThisED(LinkToED, GenarateNAR = False) Export
	
	SetPrivilegedMode(True);
	
	EDParameters = CommonUse.ObjectAttributesValues(LinkToED, "EDStatus, EDKind, EDDirection, EDAgreement");
	
	If EDRefused(EDParameters.EDStatus) Then
		ReturnValue = False;
	ElsIf EDParameters.EDKind = Enums.EDKinds.CancellationOffer Then
		ReturnValue = True;
		If EDParameters.EDDirection = Enums.EDDirections.Incoming Then
			GenarateNAR = True;
		EndIf;
	ElsIf EDParameters.EDKind = Enums.EDKinds.QueryStatement Then
		ReturnValue = False;
	ElsIf EDParameters.EDKind = Enums.EDKinds.PaymentOrder Then
		BankApplication = CommonUse.ObjectAttributeValue(EDParameters.EDAgreement, "BankApplication");
		If BankApplication = Enums.BankApplications.AsynchronousExchange Then
			ReturnValue = False;
		Else
			ReturnValue = True;
		EndIf;
	ElsIf ThisIsServiceDocument(LinkToED) Then
		ReturnValue = False;
	Else
		ReturnValue = True;
		
		Query = New Query;
		Query.Text =
		"SELECT DISTINCT
		|	EDAttachedFiles.Ref AS ED
		|FROM
		|	Catalog.EDAttachedFiles AS EDAttachedFiles
		|		LEFT JOIN Catalog.EDAttachedFiles AS ED_ATA
		|		ON EDAttachedFiles.Ref = ED_ATA.ElectronicDocumentOwner
		|			AND (ED_ATA.EDKind = VALUE(Enum.EDKinds.CancellationOffer))
		|		LEFT JOIN Catalog.EDAttachedFiles AS EDSubordinate
		|		ON EDAttachedFiles.Ref = EDSubordinate.ElectronicDocumentOwner
		|			AND (EDSubordinate.EDKind IN (&EDResponseTitlesKinds))
		|WHERE
		|	EDAttachedFiles.Ref = &Ref
		|	AND CASE
		|			WHEN ED_ATA.Ref IS NULL
		|					OR ED_ATA.Ref = &EDAttachedFilesEmptyRef
		|				THEN TRUE
		|			ELSE FALSE
		|		END
		|	AND CASE
		|			WHEN EDAttachedFiles.EDDirection = VALUE(Enum.EDDirections.Incoming)
		|				THEN CASE
		|						WHEN EDAttachedFiles.EDKind IN (&PrimaryTitlesEDKinds)
		|							THEN CASE
		|									WHEN EDSubordinate.Ref IS NULL
		|											OR EDSubordinate.Ref = &EDAttachedFilesEmptyRef
		|											OR EDSubordinate.EDStatus IN (&OutgoingEDAllowingDenialStatuses)
		|										THEN TRUE
		|									ELSE FALSE
		|								END
		|						ELSE EDAttachedFiles.EDStatus IN (&IncomingEDAllowingDenialStatuses)
		|					END
		|			ELSE EDAttachedFiles.EDStatus IN (&OutgoingEDAllowingDenialStatuses)
		|		END";
		
		Query.SetParameter("Ref", LinkToED);
		Query.SetParameter("EDAttachedFilesEmptyRef", Catalogs.EDAttachedFiles.EmptyRef());
		OutgoingEDAllowingDenialStatuses = New Array;
		OutgoingEDAllowingDenialStatuses.Add(Enums.EDStatuses.Created);
		OutgoingEDAllowingDenialStatuses.Add(Enums.EDStatuses.Approved);
		OutgoingEDAllowingDenialStatuses.Add(Enums.EDStatuses.DigitallySigned);
		OutgoingEDAllowingDenialStatuses.Add(Enums.EDStatuses.PreparedToSending);
		Query.SetParameter("OutgoingEDAllowingDenialStatuses", OutgoingEDAllowingDenialStatuses);
		IncomingEDAllowingDenialStatuses = New Array;
		IncomingEDAllowingDenialStatuses.Add(Enums.EDStatuses.Received);
		IncomingEDAllowingDenialStatuses.Add(Enums.EDStatuses.Approved);
		IncomingEDAllowingDenialStatuses.Add(Enums.EDStatuses.DigitallySigned);
		IncomingEDAllowingDenialStatuses.Add(Enums.EDStatuses.PreparedToSending);
		Query.SetParameter("IncomingEDAllowingDenialStatuses", IncomingEDAllowingDenialStatuses);
		EDResponseTitlesKinds = New Array;
		EDResponseTitlesKinds.Add(Enums.EDKinds.TORG12Customer);
		EDResponseTitlesKinds.Add(Enums.EDKinds.ActCustomer);
		EDResponseTitlesKinds.Add(Enums.EDKinds.AgreementAboutCostChangeRecipient);
		Query.SetParameter("EDResponseTitlesKinds", EDResponseTitlesKinds);
		PrimaryTitlesEDKinds = New Array;
		PrimaryTitlesEDKinds.Add(Enums.EDKinds.TORG12Seller);
		PrimaryTitlesEDKinds.Add(Enums.EDKinds.ActPerformer);
		PrimaryTitlesEDKinds.Add(Enums.EDKinds.AgreementAboutCostChangeSender);
		Query.SetParameter("PrimaryTitlesEDKinds", PrimaryTitlesEDKinds);
		Result = Query.Execute();
		
		If Result.IsEmpty() Then
			ReturnValue = False;
		Else
			GenarateNAR = (NOT EDParameters.EDDirection = Enums.EDDirections.Outgoing);
		EndIf;
	EndIf;
	
	Return ReturnValue;
	
EndFunction

Function EDRefused(EDStatus) Export
	
	EDRefused = (EDStatus = Enums.EDStatuses.Rejected
					OR EDStatus = Enums.EDStatuses.RejectedByReceiver
					OR EDStatus = Enums.EDStatuses.RejectedByBank
					OR EDStatus = Enums.EDStatuses.TransferError
					OR EDStatus = Enums.EDStatuses.RefusedABC
					OR EDStatus = Enums.EDStatuses.ESNotCorrect
					OR EDStatus = Enums.EDStatuses.AttributesError);
	Return EDRefused
	
EndFunction

Function GetReferencesToEDForPOA(Val PrimaryED) Export
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	EDAttachedFiles.Ref AS ATA,
		|	EDAttachedFiles.Company,
		|	EDEDOwner.FileOwner
		|FROM
		|	Catalog.EDAttachedFiles AS EDAttachedFiles
		|		INNER JOIN Catalog.EDAttachedFiles AS EDEDOwner
		|		ON EDAttachedFiles.ElectronicDocumentOwner = EDEDOwner.Ref
		|WHERE
		|	EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.CancellationOffer)
		|	AND EDEDOwner.Ref = &Ref";
	
	Query.SetParameter("Ref", PrimaryED);
	Result = Query.Execute();
	Selection = Result.Select();
	If Selection.Next() Then
		ReturnStructure = New Structure;
		ReturnStructure.Insert("ATA", Selection.ATA);
		ReturnStructure.Insert("Company", Selection.Company);
		ReturnStructure.Insert("FileOwner", Selection.FileOwner);
	Else
		ReturnStructure = Undefined;
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

Function CanVoidThisED(Val LinkToED) Export
	
	SetPrivilegedMode(True);
	If Not ValueIsFilled(LinkToED)
		OR ThisIsServiceDocument(LinkToED) Then
		ReturnValue = False;
	Else
		Query = New Query;
		Query.Text =
			"SELECT
			|	EDAttachedFiles.Ref AS ED,
			|	EDSubordinate.Ref AS SubordinateED,
			|	EDAttachedFiles.EDDirection,
			|	EDAttachedFiles.EDStatus,
			|	EDSubordinate.EDStatus AS SubordinateEDStatus
			|FROM
			|	Catalog.EDAttachedFiles AS EDAttachedFiles
			|		LEFT JOIN Catalog.EDAttachedFiles AS ED_ATA
			|		ON (ED_ATA.EDKind = VALUE(Enum.EDKinds.CancellationOffer))
			|			AND EDAttachedFiles.Ref = ED_ATA.ElectronicDocumentOwner
			|		LEFT JOIN Catalog.EDAttachedFiles AS EDSubordinate
			|		ON EDAttachedFiles.Ref = EDSubordinate.ElectronicDocumentOwner
			|			AND (EDSubordinate.EDKind IN (&EDResponseTitlesKinds))
			|WHERE
			|	Not EDAttachedFiles.EDStatus IN (&ExceptionStatusesList)
			|	AND Not EDAttachedFiles.DeletionMark
			|	AND EDAttachedFiles.Ref = &Ref
			|	AND CASE
			|			WHEN ED_ATA.Ref IS NULL 
			|					OR ED_ATA.Ref = &EDAttachedFilesEmptyRef
			|				THEN TRUE
			|			ELSE FALSE
			|		END";
		
		ExceptionStatusesArray = New Array;
		ExceptionStatusesArray.Add(Enums.EDStatuses.CancellationOfferCreated);
		ExceptionStatusesArray.Add(Enums.EDStatuses.CancellationOfferReceived);
		ExceptionStatusesArray.Add(Enums.EDStatuses.Canceled);
		ExceptionStatusesArray.Add(Enums.EDStatuses.Rejected);
		ExceptionStatusesArray.Add(Enums.EDStatuses.RejectedByReceiver);
		Query.SetParameter("Ref", LinkToED);
		Query.SetParameter("ExceptionStatusesList", ExceptionStatusesArray);
		Query.SetParameter("EDAttachedFilesEmptyRef", Catalogs.EDAttachedFiles.EmptyRef());
		EDResponseTitlesKinds = New Array;
		EDResponseTitlesKinds.Add(Enums.EDKinds.TORG12Customer);
		EDResponseTitlesKinds.Add(Enums.EDKinds.ActCustomer);
		EDResponseTitlesKinds.Add(Enums.EDKinds.AgreementAboutCostChangeRecipient);
		Query.SetParameter("EDResponseTitlesKinds", EDResponseTitlesKinds);
		Selection = Query.Execute().Select();
		ReturnValue = False;
		If Selection.Next() Then
			If Selection.EDDirection = Enums.EDDirections.Incoming Then
				If ValueIsFilled(Selection.SubordinateED) Then
					ProcessedED = Selection.SubordinateED;
					EDStatus = Selection.SubordinateEDStatus;
				Else
					ProcessedED = Selection.ED;
					EDStatus = Selection.EDStatus;
				EndIf;
			Else
				ProcessedED = Selection.ED;
				EDStatus = Selection.EDStatus;
			EndIf;
			ExchangeSettings = ElectronicDocumentsService.EDExchangeSettings(ProcessedED);
			StatusesArray = ElectronicDocumentsService.ReturnEDStatusesArray(ExchangeSettings);
			If StatusesArray.UBound() >= 0 AND EDStatus = StatusesArray[StatusesArray.UBound()] Then
				ReturnValue = True;
			EndIf;
		EndIf;
	EndIf;
	
	Return ReturnValue;
	
EndFunction

Function RefEDByID(Description, EDDirection)
	
	If Not ValueIsFilled(Description) Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	
	"SELECT ALLOWED TOP 1
	|	EDAttachedFiles.Ref AS ED
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.FileDescription LIKE &Description
	|	AND EDAttachedFiles.EDDirection = &EDDirection";
	
	Query.SetParameter("Description", Description);
	Query.SetParameter("EDDirection", EDDirection);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	Return Selection.ED;
	
EndFunction

// DS owner - primary ED which received
// the second signature for this ED it is required to find ED pack, retrieve additional data from it - electronic document name based on which
// it was entered by the name find EDFBases, set status in its owner "Exchange completed with correction"
Procedure SetCompletedState(AddedFile, EDDirection) Export
	
	If Not ThisIsCorrectionDocument(AddedFile) Then
		Return;
	EndIf;
	
	EDBasesArray = New Array;
	
	EDOwner = AddedFile.ElectronicDocumentOwner;
	FillInGroundsED(EDBasesArray, EDOwner, EDDirection);
	
	BasisDocuments = ElectronicDocumentsInternal.EDOwners(EDBasesArray);
	
	ElectronicDocumentsInternal.SetStateExchangeFinishedWithCorrection(BasisDocuments);
	
EndProcedure

Function IsResponseDocument(ElectronicDocument) 
	
	Result = False;
	
	Return Result;
		
EndFunction

Procedure ChangeBaseDocumentsEDState(EDPackageAttributes)
	
	Selection = EDPackageAttributes.ElectronicDocuments.Select();
	If Selection.Count() > 0 AND Selection.Next() Then
		ElectronicDocument = Selection.ElectronicDocument;
		If ValueIsFilled(ElectronicDocument) Then
			If IsResponseDocument(ElectronicDocument) Then
				SetCompletedState(ElectronicDocument, Enums.EDDirections.Incoming);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other

// Checking the possibility of ED Package correct reading is running.
// The need for this check appears while working with external infobase data (via the com-connection).
//
// Parameters:
//  EDPackage - DocumentRef.EDPackage - reviewed package of electronic documents.
//
// Returns:
//  Boolean - True - you may read pack data, otherwise, - False.
//
Function DetermineEDPackageBinaryDataReadingPossibility(EDPackage)
	
	PackageReadingPossible = True;
	ElectronicDocumentsOverridable.DetermineEDPackageBinaryDataReadingPossibility(EDPackage, PackageReadingPossible);
	
	Return PackageReadingPossible;
	
EndFunction

Function GetCorrespondingFileParameters(InformationFile)
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(InformationFile.FullName);
	
	DocumentPresentation = "";
	SignaturesPresentations = New Array;
	FoundDocument = False;
	ConformityOfReturn = New Map;
	
	While XMLReader.Read() Do
		
		Parameters = New Structure;
		
		If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.LocalName = "Text" Then
			XMLReader.Read();
			ConformityOfReturn.Insert("Text", XMLReader.Value);
		EndIf;

		If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.LocalName = "Document" Then
			DocumentPresentation = "";
			SignaturesPresentations.Clear();
			XMLReader.Read();
			DocumentPresentation = TrimAll(XMLReader.Value);
			FoundDocument = True;
			UniqueId = "";
			EDNumber = "";
		EndIf;
		
		If Not FoundDocument Then
			Continue;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.LocalName = "Signature" Then
			XMLReader.Read();
			SignaturesPresentations.Add(TrimAll(XMLReader.Value));
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.LocalName = "EDNumber" Then
			XMLReader.Read();
			EDNumber = XMLReader.Value
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.LocalName = "UniqueId" Then
			XMLReader.Read();
			UniqueId = XMLReader.Value;
		EndIf;
		If XMLReader.NodeType = XMLNodeType.EndElement AND XMLReader.LocalName = "Document" Then
			FoundDocument = False;
			NewArray = SignaturesPresentations;
			StructurePresentation = New Structure("Signatures, EDNumber, UUID, RegulationCode",
				ReturnSignaturesPresentationsArray(SignaturesPresentations), EDNumber, UniqueId, "Nonformalized");
			ConformityOfReturn.Insert(DocumentPresentation, StructurePresentation);
		EndIf;
		
	EndDo;
	
	Return ConformityOfReturn;
	
EndFunction

Function ConvertFilesArrayIntoBinaryData(FilesArray)
	
	ReturnArray = New Array;
	For Each DataFile IN FilesArray Do
		ArrayStructure = New Structure;
		ArrayStructure.Insert("BinaryData", New BinaryData(DataFile.FullName));
		ArrayStructure.Insert("FileDescriptionWithoutExtension", DataFile.BaseName);
		ArrayStructure.Insert("FileName", DataFile.Name);	
		ReturnArray.Add(ArrayStructure);
	EndDo;
	
	Return ReturnArray;
	
EndFunction

Function ReturnSignaturesPresentationsArray(PresentationArray)
	
	ReturnArray = New Array;
	For Each Item IN PresentationArray Do
		ReturnArray.Add(Item);
	EndDo;
	
	Return ReturnArray;
	
EndFunction

Function GetDataFileForProcessing(DataStructure, FolderForDetails, IsArbitraryED)
	
	DataFileProcessed = False;
	If ValueIsFilled(FolderForDetails) Then
		
		If FindFiles(FolderForDetails).Count() = 0 Then
			CreateDirectory(FolderForDetails);
		EndIf;
			
		If FindFiles(FolderForDetails).Count() > 0 Then
			
			DeleteFiles(FolderForDetails, "*");
			
			DataFile = DataStructure.BinaryData;
			Extension = StrReplace(DataStructure.FileName, DataStructure.FileDescriptionWithoutExtension, "");
			
			EncryptedArchiveFile = ElectronicDocumentsService.TemporaryFileCurrentName(Extension);
			DataFile.Write(EncryptedArchiveFile);
			
			If Find(Extension, "zip") > 0 AND IsArbitraryED <> True Then
				ZIPReading = New ZipFileReader(EncryptedArchiveFile);
				Try
					ZIPReading.ExtractAll(FolderForDetails);
					DataFileProcessed = True;
				Except
					ErrorText = BriefErrorDescription(ErrorInfo());
					If Not ElectronicDocumentsService.PossibleToExtractFiles(ZIPReading, FolderForDetails) Then
						MessageText = ElectronicDocumentsReUse.GetMessageAboutError("006");
					EndIf;
					ProcessExceptionByEDOnServer(NStr("en='ED package Unpacking';ru='распаковка пакета ЭД'"), ErrorText, MessageText);
				EndTry;
			Else
				BinaryDataFile = New File(EncryptedArchiveFile);
				FileCopy(EncryptedArchiveFile, FolderForDetails + BinaryDataFile.Name);
				DataFileProcessed = True;
			EndIf;
			
			DeleteFiles(EncryptedArchiveFile);
		EndIf;
	EndIf;
	
	Return DataFileProcessed;
	
EndFunction

// Procedure determines by which IB objects is not required
// to execute actions (approval, signing, preparation for sending).
//
// Parameters:
//  ObjectsSettings - match, contains refs to IB
// documents according to which it is supposed to execute actions with ED.
//  ArrayOfUncultivatedObjects - array, returns refs to IB objects to
//                                  the calling procedure according to which you do not need to take any actions.
//
Procedure DetermineUnprocessedObjects(ObjectsSettings, ArrayOfUncultivatedObjects)
	
	FilterArray = New Array;
	For Each Item IN ObjectsSettings Do
		If ValueIsFilled(Item.Value) Then
			FilterArray.Add(Item.Key);
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDStates.ObjectReference,
	|	EDStates.ElectronicDocument,
	|	EDStates.ElectronicDocument.EDAgreement.BankApplication AS BankApplication,
	|	EDStates.EDVersionState,
	|	EDStates.ElectronicDocument.EDFProfileSettings.EDExchangeMethod AS EDExchangeMethod
	|FROM
	|	InformationRegister.EDStates AS EDStates
	|WHERE
	|	EDStates.ObjectReference IN(&RefArray)
	|	AND (EDStates.EDVersionState = VALUE(Enum.EDVersionsStates.SendingExpected)
	|				AND EDStates.ElectronicDocument.EDStatus = VALUE(Enum.EDStatuses.PreparedToSending)
	|			OR EDStates.EDVersionState = VALUE(Enum.EDVersionsStates.ConfirmationExpected)
	|			OR EDStates.EDVersionState = VALUE(Enum.EDVersionsStates.ExchangeCompleted)
	|			OR EDStates.EDVersionState = VALUE(Enum.EDVersionsStates.ExchangeCompletedWithCorrection)
	|			OR EDStates.EDVersionState = VALUE(Enum.EDVersionsStates.PaymentExecuted)
	|			OR EDStates.EDVersionState = VALUE(Enum.EDVersionsStates.NotificationAboutReceivingExpected)
	|			OR &PaymentOrder)";
	
	PaymentOrderName = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
																	"PaymentOrderInMetadata");
	If PaymentOrderName <> Undefined Then
		
		Query.Text = StrReplace(
							Query.Text,
							"&PaymentOrder",
							"EDStates.ObjectRef REFS Document." + PaymentOrderName + "
		|					AND (EDStates.EDVersionState = VALUE(Enumeration.EDVersionsStates.Rejected))");
	Else
		Query.Text = StrReplace(Query.Text, "&PaymentOrder", "FALSE");
	EndIf;
	
	Query.SetParameter("RefArray", FilterArray);
	
	Result = Query.Execute().Select();
	While Result.Next() Do
		ArrayOfUncultivatedObjects.Add(Result.ElectronicDocument);
		
		If Result.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource
				AND Result.BankApplication = Enums.BankApplications.SberbankOnline
				AND Result.EDVersionState = Enums.EDVersionsStates.SendingExpected Then
			MessageText = NStr("en='Processor %1.
		|To send electronic document, it is required to use ""Electronic document exchange with bank"" data processor.';ru='Обработка %1.
		|Для отправки электронного документа необходимо воспользоваться обработкой ""Обмен электронными документами с банком"".'");
		Else
			MessageText = NStr("en='Processor %1.
		|Not required to perform the actions with the electronic document.';ru='Обработка %1.
		|Не требуется выполнения действий с электронным документом.'");
		EndIf;
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, Result.ObjectReference);
		CommonUseClientServer.MessageToUser(MessageText, Result.ObjectReference);
	EndDo;
	
EndProcedure

// Used to get ED presentation from client.
//
// Parameters:
//   LinkToED - CatalogRef.EDAttachedFiles - ED for which it is required to get presentation.
//
// Returns:
//   String - presentation of electronic document.
//
Function EDPresentation(LinkToED) Export
	
	Structure = New Structure;
	Structure.Insert("Presentation", ElectronicDocumentsService.GetEDPresentation(LinkToED));
	Structure.Insert("Value", LinkToED);
	
	Return Structure.Presentation;
	
EndFunction

// Used for get ED presentations list from client.
//
// Parameters:
//   EDKindsArray - Array - CatalogRef.EDAttachedFiles for which you should generate presentations list.
//
// Returns:
//   ValueList:
//      Value - CatalogRef.EDAttachedFiles.
//      Presentation - String - presentation of electronic document.
//
Function EDPresentationsList(EDKindsArray) Export
	
	PresentationsList = New ValueList;
	For Each ED IN EDKindsArray Do
		Presentation = ElectronicDocumentsService.GetEDPresentation(ED);
		PresentationsList.Add(ED, Presentation);
	EndDo;
	
	Return PresentationsList;
	
EndFunction

Function BasisED(LinkToED, EDDirection) Export
	
	DataFileRef = GetEDData(LinkToED);
	If Not ValueIsFilled(DataFileRef) Then
		Return Undefined;
	EndIf;
	
	SelectionAdditData = ElectronicDocumentsService.SelectionAdditDataED(LinkToED);
	If SelectionAdditData.Next() Then
		RefToAdditDataED = SelectionAdditData.Ref;
		AdditDataFileRef = GetEDData(RefToAdditDataED);
		If Not ValueIsFilled(AdditDataFileRef) Then
			Return Undefined;
		EndIf;
	EndIf;

	ParametersStructure = New Structure;
	ParametersStructure.Insert("DataFileRef", DataFileRef);
	ParametersStructure.Insert("EDDirection",	LinkToED.EDDirection);
	If AdditDataFileRef <> Undefined Then
		ParametersStructure.Insert("AdditDataFileRef", AdditDataFileRef);
	EndIf;
	ParametersStructure.Insert("EDOwner", "EDOwner");
	
	EDStructure = ElectronicDocumentsInternal.ParseDataFile(ParametersStructure);
	
	AdditDataTree = Undefined;
	If Not EDStructure.Property("AdditDataTree", AdditDataTree) Then 
		Return Undefined;
	EndIf;
	
	BaseDocumentString = EDStructure.AdditDataTree.Rows.Find("IDEDDocumentFoundation", , True);
	If BaseDocumentString = Undefined Then
		Return Undefined;
	EndIf;
	
	BasisED = RefEDByID(BaseDocumentString.AttributeValue, EDDirection);
	
	Return BasisED;
		
EndFunction

Function ThisIsCorrectionDocument(AddedFile) Export
	
	// Document base of which should change its status should be of type:
	// TORG12Salesperson, TORG12Customer or NotificationAboutReceipt is bound to s.s.
	
	Result = False;
	
	If (AddedFile.EDKind = Enums.EDKinds.TORG12Seller 
			Or AddedFile.EDKind = Enums.EDKinds.TORG12Customer) Then
				
		Result = True;
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Certificates

Function GenerateCertificatesExtensionsList()
	
	ExtensionsList = New ValueList;
	ExtensionsList.Add(".p7s");
	
	Return ExtensionsList;
	
EndFunction

Function GenerateFilesForSending(Envelop)
	
	EDFiles = ElectronicDocumentsService.GetEDSelectionByFilter(New Structure("FileOwner", Envelop));
	DirectoryAddress = ElectronicDocumentsService.WorkingDirectory("Send", Envelop.Ref.UUID());
	If Not EDFiles = Undefined Then
		While EDFiles.Next() Do
			FileData = ElectronicDocumentsService.GetFileData(EDFiles.Ref);
			BinaryData = GetFromTempStorage(FileData.FileBinaryDataRef);
			BinaryData.Write(DirectoryAddress + FileData.FileName);
		EndDo;
	EndIf;
	
	Return DirectoryAddress;
	
EndFunction

// For internal use only
Procedure FillDocumentIBByEd(RefToOwner, LinkToED, DocIsFull =False)
	
	DataFileRef = GetEDData(LinkToED);
	If Not ValueIsFilled(DataFileRef) Then
		Return;
	EndIf;
	SelectionAdditData = ElectronicDocumentsService.SelectionAdditDataED(LinkToED);
	If SelectionAdditData.Next() Then
		RefToAdditDataED = SelectionAdditData.Ref;
		AdditDataFileRef = GetEDData(RefToAdditDataED);
		If Not ValueIsFilled(AdditDataFileRef) Then
			Return;
		EndIf;
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("EDOwner",		RefToOwner);
	ParametersStructure.Insert("DataFileRef",	DataFileRef);
	ParametersStructure.Insert("EDDirection",	LinkToED.EDDirection);
	ParametersStructure.Insert("FillInDocument", True);
	
	If AdditDataFileRef <> Undefined Then
		ParametersStructure.Insert("AdditDataFileRef", AdditDataFileRef);
	EndIf;
	
	EDStructure = ElectronicDocumentsInternal.ParseDataFile(ParametersStructure);
		
	If EDStructure.Imported Then
		BeginTransaction();
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.EDStates");
		LockItem.SetValue("ObjectReference", RefToOwner);
		Block.Lock();
	
		RecordManager = InformationRegisters.EDStates.CreateRecordManager();
		RecordManager.ObjectReference = RefToOwner;
		RecordManager.Read();
		If RecordManager.Selected() AND RecordManager.ElectronicDocument <> LinkToED Then
			RecordManager.ElectronicDocument = LinkToED;
			RecordManager.Write();
		EndIf;
	
		RefreshEDVersion(LinkToED);
	
		CommitTransaction();
	EndIf;
	
	DocIsFull = EDStructure.Imported;
	
EndProcedure

Function GetEDData(LinkToED)
	
	RefToData = "";
	
	AdditInformationAboutED = ElectronicDocumentsService.GetFileData(LinkToED);
	If AdditInformationAboutED.Property("FileBinaryDataRef")
		AND ValueIsFilled(AdditInformationAboutED.FileBinaryDataRef) Then
		
		EDData = GetFromTempStorage(AdditInformationAboutED.FileBinaryDataRef);
		
		If ValueIsFilled(AdditInformationAboutED.Extension) Then
			FileName = ElectronicDocumentsService.TemporaryFileCurrentName(AdditInformationAboutED.Extension);
		Else
			FileName = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
		EndIf;
		
		EDData.Write(FileName);
		
		If Find(AdditInformationAboutED.Extension, "zip") > 0
				AND CommonUse.ObjectAttributeValue(LinkToED, "EDKind") = Enums.EDKinds.ProductsDirectory Then
			RefToData = AdditInformationAboutED.FileBinaryDataRef
		ElsIf Find(AdditInformationAboutED.Extension, "zip") > 0 Then
		
			ZIPReading = New ZipFileReader(FileName);
			FolderForUnpacking = ElectronicDocumentsService.WorkingDirectory( , LinkToED.UUID());
			
			DeleteFiles(FolderForUnpacking, "*.*");
			
			Try
				ZipReading.ExtractAll(FolderForUnpacking);
			Except
				ErrorText = BriefErrorDescription(ErrorInfo());
				If Not ElectronicDocumentsService.PossibleToExtractFiles(ZipReading, FolderForUnpacking) Then
					MessageText = ElectronicDocumentsReUse.GetMessageAboutError("006");
				EndIf;
				ProcessExceptionByEDOnServer(NStr("en='ED package Unpacking';ru='распаковка пакета ЭД'"), ErrorText, MessageText);
				DeleteFiles(FolderForUnpacking);
				Return "";
			EndTry;
			
			XMLArchiveFiles = FindFiles(FolderForUnpacking, "*.xml");
			For Each UnpackedFile IN XMLArchiveFiles Do
				FileBinaryData = New BinaryData(UnpackedFile.FullName);
				RefToData = PutToTempStorage(FileBinaryData, New UUID);
				Break;
			EndDo;
			
			DeleteFiles(FolderForUnpacking);
			
		ElsIf Find(AdditInformationAboutED.Extension, "xml") > 0 Then
			RefToData = AdditInformationAboutED.FileBinaryDataRef;
		EndIf;
		
	EndIf;
	
	Return RefToData;
	
EndFunction

// For internal use only
Function AccordanceDataPackages(ArrayPackageED) Export
	
	ConformityOfReturn = New Map;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PackageEDElectronicDocuments.Ref AS EDPackage,
	|	PackageEDElectronicDocuments.ElectronicDocument AS ElectronicDocument,
	|	PackageEDElectronicDocuments.ElectronicDocument.EDDirection AS EDDirection,
	|	PackageEDElectronicDocuments.ElectronicDocument.EDKind AS EDKind
	|FROM
	|	Document.EDPackage.ElectronicDocuments AS PackageEDElectronicDocuments
	|WHERE
	|	PackageEDElectronicDocuments.Ref IN(&ArrayPackageED)
	|TOTALS BY
	|	EDPackage";
	
	Query.SetParameter("ArrayPackageED", ArrayPackageED);
	QueryResult = Query.Execute();
	SelectionPackages = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While SelectionPackages.Next() Do
		SelectionED = SelectionPackages.Select();
		EDKindsArray = New Array;
		While SelectionED.Next() Do
			FileDataStructure = New Structure;
			FileData = ElectronicDocumentsService.GetFileData(SelectionED.ElectronicDocument);
			FileDataStructure.Insert("ElectronicDocument", SelectionED.ElectronicDocument);
			FileDataStructure.Insert("FileData",         FileData);
			FileDataStructure.Insert(
					"IsConfirmationSending",
					SelectionED.EDDirection = Enums.EDDirections.Incoming);
			EncryptionParameters = ElectronicDocumentsService.GetEncryptionCertificatesAdressesArray(
																			SelectionED.ElectronicDocument);
			FileDataStructure.Insert("EncryptionParameters", EncryptionParameters);
			EDKindsArray.Add(FileDataStructure);
		EndDo;
		ConformityOfReturn.Insert(SelectionPackages.EDPackage, EDKindsArray);
	EndDo;
	
	Return ConformityOfReturn;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Electronic documents signature

// Checks ED signatures, used to minimize the server calls.
//
// Parameters:
//   ResultsMatch - Map:
//                             Key     - CatalogRef.EDAttachedFiles - ref to electronic document.
//                             Value - Array - contains data of the set signatures.
//
Procedure HandleSignaturesCheckResultsArray(ResultsMatch) Export
	
	For Each Item IN ResultsMatch Do
		SaveResultsChecksSignatures(Item.Key, Item.Value);
	EndDo;
	
EndProcedure

// Saves DS check results executed on client
//
// Parameters:
// ED - CatalogRef.EDAttachedFiles - ref to electronic document.
// ResultsArray - Array - contains data of the set signatures.
//
Procedure SaveResultsChecksSignatures(ED, ResultsArray) Export
	
	If ResultsArray.Count() = 0 Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	ObjectCatalog = ED.GetObject();
	
	For Each Item IN ResultsArray Do
		TSRow = ObjectCatalog.DigitalSignatures.Get(Item.LineNumber-1);
		TSRow.SignatureVerificationDate = CurrentSessionDate();
		TSRow.SignatureIsCorrect = Item.Result;
	EndDo;
	
	Try
		ObjectCatalog.Write();
	Except
		CommonUseClientServer.MessageToUser(ErrorDescription());
	EndTry
	
EndProcedure

// Signs electronic documents with the certain cryptography certificate.
// 
// Parameters:
//  AddedFiles - Array of references to electronic documents that
//  should be signed, SignatureCertificate - CryptographyCertificate, certificate using which it
//  is required to sign the passed electronic documents, CertificateParameters - Structure, contains
//  UnsignedArrayED certificate attributes - Array or Undefined, to this variable to the calling procedure
//    ED array is returned, which have not been signed.
//
Function SignEDWithAppointedCertificate(AddedFiles,
											SignatureCertificate,
											CertificateParameters,
											NotSignedEDArray = Undefined) Export
											
	If Not TypeOf(AddedFiles) = Type("Array") Then
		FilesForSignature = New Array;
		FilesForSignature.Add(AddedFiles);
	Else
		FilesForSignature = AddedFiles;
	EndIf;
	
	If TypeOf(NOTSignedEDArray) <> Type("Array") Then
		NotSignedEDArray = New Array;
	EndIf;
	Cancel = False;
	CryptoManager = GetCryptoManager(Cancel);
	If Cancel Then
		MessageText = GetMessageAboutError("110");
		CommonUseClientServer.MessageToUser(MessageText);
		For Each NotSignedED IN FilesForSignature Do
			NotSignedEDArray.Add(NOTSignedED);
		EndDo;
		Return 0;
	EndIf;
	
	ValidateCertificateValidityPeriod(SignatureCertificate);
	
	CryptoManager.IncludeCertificatesInSignature = CryptoCertificateIncludeMode.IncludeSubjectCertificate;
	
	CryptoCertificate = GetCertificateByImprint(CertificateParameters.Imprint);
	
	DigitallySignedEDCount = 0;
	
	If CryptoCertificate <> Undefined Then
		
		Try
			CryptoManager.CheckCertificate(CryptoCertificate,
													 CryptoCertificateCheckMode.AllowTestCertificates);
		Except
			MessageText = GetMessageAboutError("112");
			ProcessExceptionByEDOnServer(NStr("en='verification of certificate for correctness';ru='проверка сертификата на корректность'"),
											  DetailErrorDescription(ErrorInfo()),
											  MessageText);
			For Each NotSignedED IN FilesForSignature Do
				NotSignedEDArray.Add(NOTSignedED);
			EndDo;
			Return 0;
		EndTry;
		
		For Each CurDocument IN FilesForSignature Do
			
			SignatureDataStructure = New Structure("Certificate, UserPassword, Comment", CryptoCertificate, CertificateParameters.UserPassword,
				NStr("en='Sign electronic document';ru='Подписание электронного документа'"));
			Try
				FileBinaryData = GetFileBinaryData(CurDocument, SignatureCertificate);
				SignatureData = GenerateSignatureData(CryptoManager, CurDocument, FileBinaryData,
					SignatureDataStructure);
				
				AddSignature(CurDocument, SignatureData);
				DigitallySignedEDCount = DigitallySignedEDCount + 1;
				DetermineSignaturesStatuses(CurDocument);
			Except
				MessagePattern = NStr("en='An error occurred while signing on server. You should test cryptography certificate for: %1.
		|%2';ru='Ошибка подписи на сервере. Необходимо провести тест сертификата криптографии для: %1.
		|%2'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, SignatureCertificate,
					BriefErrorDescription(ErrorInfo()));
				ProcessExceptionByEDOnServer(
						NStr("en='digitally sign';ru='установка подписи ЭП'"),
						DetailErrorDescription(ErrorInfo()),
						MessageText);
				NotSignedEDArray.Add(CurDocument);
			EndTry;
			
		EndDo;
	EndIf;
	
	Return DigitallySignedEDCount;
	
EndFunction

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
				
	SetPrivilegedMode(True);
	
	SignatureInstallationDate = ElectronicDocumentsService.SignatureInstallationDate(NewSignatureBinaryData);
	SignatureInstallationDate = ?(ValueIsFilled(SignatureInstallationDate), SignatureInstallationDate, CurrentSessionDate());
	
	ElectronicDocumentsService.AddInformationAboutSignature(
										ObjectForSigningRef,
										NewSignatureBinaryData,
										Imprint,
										SignatureInstallationDate,
										Comment,
										SignatureFileName,
										CertificateIsIssuedTo,
										CertificateBinaryData,
										UUID)

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Operations with cryptography

// Creates cryptography manager on server.  Password is not set
//
// Returns:
//   CryptoManager  - cryptography manager
Function GetCryptoManager(Cancel = False,
	Operation = "", ShowError = False, ErrorDescription = "", Application = Undefined) Export
	
	If DigitalSignature.UseDigitalSignatures() Then
		CryptoManager = DigitalSignature.CryptoManager(Operation, ShowError, ErrorDescription, Application);
	Else
		CryptoManager = Undefined;
	EndIf;
	Cancel = (CryptoManager = Undefined);
	
	Return CryptoManager;
	
EndFunction

// Returns decrypted binary data.
//
// Parameters:
//  BinaryData - BinaryData, data that
//  should be encrypted Password - String, password for decryption
//
// Returns:
//  BinaryData or Undefined - encrypted binary data or Undefined if an error occurs.
//
Function DecryptedData(BinaryData, Password) Export
	
	Try
		CryptoManager = GetCryptoManager();
	Except
		MessageText = GetMessageAboutError("110");
		CommonUseClientServer.MessageToUser(MessageText);
		Return Undefined;
	EndTry;
	
	CryptoManager.PrivateKeyAccessPassword = Password;
	// Decryption method generates the exception in case an error occurs.
	Try
		DecryptedBinaryData = CryptoManager.Decrypt(BinaryData);
	Except
		MessageText = GetMessageAboutError("113");
		ProcessExceptionByEDOnServer(
				NStr("en='ED package decryption';ru='расшифровка пакета ЭД'"),
				DetailErrorDescription(ErrorInfo()),
				MessageText);
		Return Undefined;
	EndTry;

	Return DecryptedBinaryData;
	
EndFunction

// Generates object signing data
//
// Parameters
//  CryptographyManager  - CryptoManager - ObjectForSigningRef
//  cryptography manager  - any ref - ref to
//  the BinaryData signed object  - BinaryData - SignatureParametersStructure
//  signature binary data  - Structure - signature information - selected certificate, password, comment
//
// Returns:
//   Structure   - data for writing to the DS tabular section
Function GenerateSignatureData(
				CryptoManager,
				ObjectForSignaturesReference,
				BinaryData,
				StructureOfSignatureParameters) Export
	
	CryptoManager.PrivateKeyAccessPassword = StructureOfSignatureParameters.UserPassword;
	SignatureDate = Date('00010101');
	
	NewSignatureBinaryData = CryptoManager.Sign(BinaryData, StructureOfSignatureParameters.Certificate);
	
	Imprint = Base64String(StructureOfSignatureParameters.Certificate.Imprint);
	CertificateIsIssuedTo = DigitalSignatureClientServer.SubjectPresentation(StructureOfSignatureParameters.Certificate);
	CertificateBinaryData = StructureOfSignatureParameters.Certificate.Unload();
	
	SignatureData = New Structure("ObjectRef, NewSignatureBinaryData, Thumbprint, SignatureDate, Comment, SignatureFileName, CertificateIsIssuedTo, FileAddress, CertificateBinaryData",
							ObjectForSignaturesReference,
							NewSignatureBinaryData,
							Imprint,
							SignatureDate,
							StructureOfSignatureParameters.Comment,
							"", // SignatureFileName
							CertificateIsIssuedTo,
							"", // FileURL
							CertificateBinaryData);
		
	Return SignatureData;
	
EndFunction

// Checks whether there are tools to work with cryptography on server
//
// Returns:
//   Boolean  - true if cryptography manager was created successfully
Function IsCryptofacilitiesAtServer(OutputMessages = True) Export
	
	Cancel = False;
	
	Try
		CryptoManager = GetCryptoManager(Cancel);
	Except
		
		If OutputMessages Then
			MessageText = GetMessageAboutError("110");
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;

		Cancel = True;
	EndTry;
	
	Return Not Cancel;

EndFunction

// Fills in structure with certificate fields.
//
// Parameters
//  Print  - String - base64 encoded certificate thumbprint 
//
// Returns:
//   Structure  - structure with certificate fields
Function FillCertificateStructureByImprint(Imprint) Export
	
	BinaryDataImprint = Base64Value(Imprint);
	
	Cancel = False;
	CryptoManager = GetCryptoManager(Cancel);
	If Cancel Then
		Return Undefined;
	EndIf;
	
	StorageOfCertificates = CryptoManager.GetCertificateStore();
	Certificate = StorageOfCertificates.FindByThumbprint(BinaryDataImprint);
	
	If Certificate = Undefined Then
		Warning = NStr("en='Certificate is not found';ru='Сертификат не найден'");
		CommonUseClientServer.MessageToUser(Warning);
		Return Undefined;
	EndIf;
	
	Return DigitalSignatureClientServer.FillCertificateStructure(Certificate);
	
EndFunction

// Finds certificate by the thumbprint string
//
// Parameters
//  Print  - String - base64 encoded certificate thumbprint
// OnlyInPersonalStorage  - Boolean - search only in the personal storage
//
// Returns:
//   CryptoCertificate  - cryptography certificate 
Function GetCertificateByImprint(Imprint, InPersonalStorageOnly = False) Export
	
	BinaryDataImprint = Base64Value(Imprint);
	
	Cancel = False;
	CryptoManager = GetCryptoManager(Cancel);
	If Cancel Then
		Return Undefined;
	EndIf;
	
	StorageOfCertificates = Undefined;
	If InPersonalStorageOnly Then
		StorageOfCertificates = CryptoManager.GetCertificateStore(
															CryptoCertificateStoreType.PersonalCertificates);
	Else	
		StorageOfCertificates = CryptoManager.GetCertificateStore();
	EndIf;
	
	Certificate = StorageOfCertificates.FindByThumbprint(BinaryDataImprint);
	
	Return Certificate;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other

// Converts binary data to string on server.
//
// Parameters:
//  BinaryData - BinaryData
//
// Returns:
//  <String> - String in UTF8 encoding
//
Function AStringOfBinaryData(BinaryData) Export
	
	If TypeOf(BinaryData) = Type("BinaryData") Then
		TempFile = GetTempFileName();
		BinaryData.Write(TempFile);
		TextDocument = New TextDocument;
		TextDocument.Read(TempFile, TextEncoding.UTF8);
		DeleteFiles(TempFile);
		Result = TextDocument.GetText();
		Return Result;
	Else
		Return BinaryData;
	EndIf;
	
EndFunction

// Creates packs attached files encrypted on client
//
// Parameters:
// DataMap - Map - contains data by packs and
// encrypted files PasswordsForEDFMatch - Map - data about passwords
//
Procedure SaveAndSendEncryptedData(DataMap, AccAgreementsAndStructuresOfCertificates, SentCnt) Export
	
	ArrayPED = New Array;
	For Each ItemPED in DataMap Do
		EDPackage = ItemPED.Key;
		If EDPackage.PackageFormatVersion <> Enums.EDPackageFormatVersions.Version10 Then
			
			ElectronicDocumentsInternal.GenerateEDAttachedFileEDFOperatorPackage(
								EDPackage,
								ItemPED.Value[0].FileData.FileBinaryDataRef);
		Else
			ElectronicDocumentsService.GenerateEDAttachedPackageFile(EDPackage, ItemPED.Value);
		EndIf;
		ArrayPED.Add(EDPackage);
	EndDo;
		
	If DataMap.Count() > 0 AND ElectronicDocumentsService.ImmediateEDSending() Then
		SentCnt = EDPackagesSending(ArrayPED, AccAgreementsAndStructuresOfCertificates);
	EndIf;
	
EndProcedure

// For internal use only
Function EncryptedMarker(TokenRequestParametersStructure) Export
	
	Join = ElectronicDocumentsInternal.GetConnection();
	Return ElectronicDocumentsInternal.GetMarkerEEDF(TokenRequestParametersStructure, Join, False)
	
EndFunction

// Determines where to decrypt EDF operator marker.
//
// Returns:
//  Boolean - True if decryption is executed on server or False - if on client
//
Function ServerAuthorizationPerform() Export
	
	SetPrivilegedMode(True);
	If CommonUseReUse.DataSeparationEnabled()
	 Or CommonUse.FileInfobase()
	   AND Not CommonUseClientServer.ClientConnectedViaWebServer() Then
		
		ReturnValue = False;
	Else
		ReturnValue = (Constants.AuthorizationContext.Get() = Enums.WorkContextsWithED.AtServer);
	EndIf;
	
	Return ReturnValue;
	
EndFunction

// Determines where to execute crypto operations.
//
// Returns:
//  Boolean - True if cryptography is set on server or False - if on client
//
Function PerformCryptoOperationsAtServer() Export
	
	SetPrivilegedMode(True);
	Return Constants.CreateDigitalSignaturesAtServer.Get() = True;
	
EndFunction

// Designed to return to client ED binary data, set signatures and certificates
// for the further check of the signatures validity on client
//
// Parameters:
//   EDKindsArray - Array - array items - CatalogRef.EDAttachedFiles
//
// Returns:
//   Array - items - Structures:
//                       ED           - CatalogRef.EDAttachedFiles.
//                       Signatures      - Array - Structures with signatures data.
//                       EDAgreement - CatalogRef.EDUsageAgreements.
//                       EDData     - BinaryData - DS data.
//
Function EDContentStructuresArray(EDKindsArray) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	EDAttachedFilesDigitalSignatures.LineNumber,
	|	EDAttachedFilesDigitalSignatures.Certificate,
	|	EDAttachedFilesDigitalSignatures.Signature,
	|	EDUsageAgreements.BankApplication AS BankApplication,
	|	EDAttachedFiles.EDKind AS EDKind,
	|	EDUsageAgreements.Ref AS EDAgreement,
	|	EDAttachedFiles.Ref
	|FROM
	|	Catalog.EDAttachedFiles.DigitalSignatures AS EDAttachedFilesDigitalSignatures
	|		INNER JOIN Catalog.EDAttachedFiles AS EDAttachedFiles
	|			INNER JOIN Catalog.EDUsageAgreements AS EDUsageAgreements
	|			ON EDAttachedFiles.EDAgreement = EDUsageAgreements.Ref
	|		ON EDAttachedFilesDigitalSignatures.Ref = EDAttachedFiles.Ref
	|WHERE
	|	EDAttachedFilesDigitalSignatures.Ref IN(&ED)";
	
	Query.SetParameter("ED", EDKindsArray);
	Selection = Query.Execute().Select();
	StructuresArray = New Array;
	CurED = Undefined;
	While Selection.Next() Do
		If CurED <> Selection.Ref Then
			CurED = Selection.Ref;
			StructuresArray.Add(New Structure);
			ReturnStructure = StructuresArray[StructuresArray.Count() - 1];
			ReturnStructure.Insert("ED", CurED);
			ReturnStructure.Insert("Signatures", New Array);
			SignaturesArray = ReturnStructure.Signatures;
			ReturnStructure.Insert("EDAgreement", Selection.EDAgreement);
			EDData = AttachedFiles.GetFileBinaryData(CurED);
			If (Selection.BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
					OR Selection.BankApplication = Enums.BankApplications.iBank2)
				AND Selection.EDKind = Enums.EDKinds.PaymentOrder Then
				
				ServiceED = ElectronicDocumentsService.ServiceBankED(CurED);
				ReturnStructure.Insert("EDData", AttachedFiles.GetFileBinaryData(ServiceED));
			Else
				ReturnStructure.Insert("EDData", AttachedFiles.GetFileBinaryData(CurED));
			EndIf;
		EndIf;
		SignaturesStructure = New Structure;
		SignaturesStructure.Insert("LineNumber", Selection.LineNumber);
		SignaturesStructure.Insert("Certificate",  Selection.Certificate.Get());
		SignaturesStructure.Insert("Signature",     Selection.Signature.Get());
		SignaturesArray.Add(SignaturesStructure);
	EndDo;
	
	Return StructuresArray;
	
EndFunction

// Designed to return to client ED binary data, set signatures and certificates
// for the further check of the signatures validity on client
//
// Parameters:
//  ED - CatalogRef.EDAttachedFiles reference to electronic document
//
// Returns:
//  Structure or undefined - electronic document data, Undefined - if there are no signatures
//
Function EDContentStructure(ED) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	EDAttachedFilesDigitalSignatures.LineNumber,
	|	EDAttachedFilesDigitalSignatures.Certificate,
	|	EDAttachedFilesDigitalSignatures.Signature,
	|	EDAttachedFilesDigitalSignatures.Ref.EDAgreement.BankApplication AS BankApplication,
	|	EDAttachedFilesDigitalSignatures.Ref.EDKind AS EDKind,
	|	EDAttachedFilesDigitalSignatures.Ref.EDAgreement
	|FROM
	|	Catalog.EDAttachedFiles.DigitalSignatures AS EDAttachedFilesDigitalSignatures
	|WHERE
	|	EDAttachedFilesDigitalSignatures.Ref = &ED";
	
	Query.SetParameter("ED", ED);
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	ReturnStructure = New Structure;
	SignaturesArray = New Array;
	While Selection.Next() Do
		SignaturesStructure = New Structure;
		SignaturesStructure.Insert("LineNumber", Selection.LineNumber);
		SignaturesStructure.Insert("Certificate",  Selection.Certificate.Get());
		SignaturesStructure.Insert("Signature",     Selection.Signature.Get());
		SignaturesArray.Add(SignaturesStructure);
	EndDo;
	EDData = AttachedFiles.GetFileBinaryData(ED);
	If Selection.Count() > 0 AND (Selection.BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
										OR Selection.BankApplication = Enums.BankApplications.iBank2)
		AND Selection.EDKind = Enums.EDKinds.PaymentOrder Then
		
		ServiceED = ElectronicDocumentsService.ServiceBankED(ED);
		ReturnStructure.Insert("EDData", AttachedFiles.GetFileBinaryData(ServiceED));
	Else
		ReturnStructure.Insert("EDData", AttachedFiles.GetFileBinaryData(ED));
	EndIf;
	ReturnStructure.Insert("Signatures",  SignaturesArray);
	ReturnStructure.Insert("EDAgreement", Selection.EDAgreement);
	
	Return ReturnStructure;
	
EndFunction

// Function checks availability of the directory specified in the settings of
// the agreements on exchange (via directory) for availability as from client (as directory is selected from client) as well as from server (as work
// with files is executed on server).
//
// Parameters:
//  PathToDirectory - String - full path to the directory availability of which must be checked (from client or server);
//
Function ValidateCatalogAvailabilityForDirectExchange(PathToDirectory) Export
	
	DirectoriesAvailable = False;
	If ValueIsFilled(PathToDirectory) Then
		PathToDirectory = TrimAll(PathToDirectory);
		DeleteDirectoryAfterTest = False;
		Directory = New File(PathToDirectory);
		If Not Directory.Exist() Then
			DeleteDirectoryAfterTest = True;
			CreateDirectory(PathToDirectory);
		EndIf;
		Delimiter = ?(Right(PathToDirectory, 1) = "\", "", "\");
		TestFile = New TextDocument;
		FullNameOfTestFile = PathToDirectory + Delimiter + "EDI_" + String(New UUID) + ".tst";
		TestFile.Write(FullNameOfTestFile);
		DirectoriesAvailable = ReadTestFileAtServer(FullNameOfTestFile);
		If Not DirectoriesAvailable Then
			MessageText = NStr("en='Specified %1 catalog can not be used for exchange as it is not available from server.
		|It is necessary to specify the network directory for exchange.';ru='Указанный каталог %1 не может использоваться для обмена, так как он не доступен с сервера.
		|Необходимо указать сетевой каталог для обмена.'");
			MessageText = StrReplace(MessageText, "%1", """" + PathToDirectory + """");
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		If DeleteDirectoryAfterTest Then
			DeleteFiles(Directory.FullName);
		Else
			DeleteFiles(FullNameOfTestFile);
		EndIf;
	EndIf;
	
	Return DirectoriesAvailable;
	
EndFunction

// Returns documents array that can be posted
//
// Parameters:
//  DocumentArray - Array - references to documents array 
//
// Returns:
//  Array - documents array that can be posted
//
Function PostingDocumentsArray(DocumentArray) Export
	
	ArrayOfWiredDocuments = New Array;
	ArrayOfTypesNonPostingDocuments = New Array;
	For Each Item in DocumentArray Do
		DocumentName = Item.Metadata().FullName();
		If Metadata.Documents.Contains(Metadata.FindByFullName(DocumentName)) Then
			
			If Item.Metadata().Posting = Metadata.ObjectProperties.Posting.Deny Then
				If ArrayOfTypesNonPostingDocuments.Find(TypeOf(Item)) = Undefined Then
					ArrayOfTypesNonPostingDocuments.Add(TypeOf(Item));
				EndIf;
			EndIf;
			
			ArrayOfWiredDocuments.Add(Item)
		EndIf;
	EndDo;
	
	For Each GetUnpostDocumentType IN ArrayOfTypesNonPostingDocuments Do
		CommonUseClientServer.DeleteAllTypeOccurrencesFromArray(ArrayOfWiredDocuments, GetUnpostDocumentType);
	EndDo;
	
	Return ArrayOfWiredDocuments;
	
EndFunction

// Returns a method of electronic documents exchange by the pack.
//
// Parameters:
//  Package - Ref to
// the EDPack
// document Return value EDExchangeMethod - ref to the EDExchangeMethods enumeration
//
Function GetEDExchangeMethodOfEDPackage(Package) Export
	
	Return CommonUse.ObjectAttributeValue(Package, "EDExchangeMethod");
	
EndFunction

// For internal use only
Function DetermineBindingObject(DocumentParametersStructure)
	
	SetPrivilegedMode(True);
	ReturnValue = Undefined;
	
	If DocumentParametersStructure.EDKind = Enums.EDKinds.TORG12Customer
		OR DocumentParametersStructure.EDKind = Enums.EDKinds.ActCustomer
		OR DocumentParametersStructure.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient Then
		EDOwnerRef = Catalogs.EDAttachedFiles.GetRef(
			New UUID(DocumentParametersStructure.OwnerEDId));
		If EDOwnerRef.GetObject() <> Undefined Then
			DocumentParametersStructure.Insert("ElectronicDocumentOwner", EDOwnerRef);
			ReturnValue = EDOwnerRef.FileOwner;
		Else
			ErrorText = NStr("en='Incoming ED (%1) linking object is not found by ID: %2';ru='Не найден объект привязки входящего ЭД(%1) по идентификатору: %2'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
										ErrorText,
										DocumentParametersStructure.EDKind,
										DocumentParametersStructure.OwnerEDId);
			OperationKind = NStr("en='Package unpacking';ru='Распаковка пакета'");
			ProcessExceptionByEDOnServer(OperationKind, ErrorText);
		EndIf;
	Else
		SubstringPos = Find(DocumentParametersStructure.EDNumber, "##") - 1;
		If SubstringPos > 0 Then
			ElectronicDocumentNumber = Left(DocumentParametersStructure.EDNumber, SubstringPos);
		Else
			ElectronicDocumentNumber = DocumentParametersStructure.EDNumber;
		EndIf;
		If ValueIsFilled(ElectronicDocumentNumber) Then
			BasisDocumentsQuery = New Query;
			BasisDocumentsQuery.Text =
			"SELECT TOP 1
			|	EDAttachedFiles.FileOwner.Ref AS Ref
			|FROM
			|	Catalog.EDAttachedFiles AS EDAttachedFiles
			|WHERE
			|	(NOT EDAttachedFiles.FileOwner REFS Document.EDPackage)
			|	AND EDAttachedFiles.DeletionMark = FALSE
			|	AND EDAttachedFiles.EDNumber LIKE &Parameter
			|	AND EDAttachedFiles.EDKind = &EDKind
			|	AND EDAttachedFiles.EDDirection = &EDDirection";
			BasisDocumentsQuery.SetParameter("EDDirection", DocumentParametersStructure.EDDirection);
			BasisDocumentsQuery.SetParameter("Parameter",      ElectronicDocumentNumber + "%");
			BasisDocumentsQuery.SetParameter("EDKind",         DocumentParametersStructure.EDKind);
			
			FoundDocuments = BasisDocumentsQuery.Execute().Select();
			If FoundDocuments.Next() Then
				ReturnValue = FoundDocuments.Ref;
			EndIf;
		EndIf;
	EndIf;
	
	Return ReturnValue;
	
EndFunction

// Procedure closes electronic documents flow for the passed references array to IB documents.
//
// Parameters:
//   RefsArrayToOwners - Array - array of references to IB documents for which it is required to close EDF.
//   ClosingReason - String - EDF closing reason description.
//   ProcessedEDCount - Number - IB documents quantity for which EDF will be closed.
//
Procedure CloseDocumentsForcedly(Val RefsArrayToOwners, Val ClosingReason, ProcessedEDCount) Export
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	EDStates.ObjectReference,
		|	EDStates.ElectronicDocument
		|FROM
		|	InformationRegister.EDStates AS EDStates
		|WHERE
		|	EDStates.ObjectReference IN(&RefArray)";
	Query.SetParameter("RefArray", RefsArrayToOwners);
	VT = Query.Execute().Unload();
	
	ObjectsVT = New ValueTable;
	ObjectsVT.Columns.Add("ObjectReference");
	ObjectsVT.Columns.Add("ElectronicDocument");
	
	For Each Item IN RefsArrayToOwners Do
		ExchangeSettings = ElectronicDocumentsService.DetermineEDExchangeSettingsBySource(Item);
		If ValueIsFilled(ExchangeSettings) Then
			NewRow = ObjectsVT.Add();
			VTRow = VT.Find(Item, "ObjectReference");
			ElectronicDocument = Catalogs.EDAttachedFiles.EmptyRef();
			If VTRow <> Undefined Then
				ElectronicDocument = VTRow.ElectronicDocument;
			EndIf;
			NewRow.ObjectReference = Item;
			NewRow.ElectronicDocument = ElectronicDocument;
		EndIf;
	EndDo;
	
	For Each String IN ObjectsVT Do
		RegisterRecord = InformationRegisters.EDStates.CreateRecordManager();
		RegisterRecord.ObjectReference = String.ObjectReference;
		RegisterRecord.ActionsFromOurSide = Enums.EDConsolidatedStates.NoActionsNeeded;
		RegisterRecord.ActionsFromOtherPartySide = Enums.EDConsolidatedStates.NoActionsNeeded;
		RegisterRecord.EDVersionState = Enums.EDVersionsStates.ClosedForce;
		RegisterRecord.ElectronicDocument = String.ElectronicDocument;
		RegisterRecord.Comment = ClosingReason;
		RegisterRecord.Write();
	EndDo;
	ProcessedEDCount = ObjectsVT.Count();
	
EndProcedure

Function ThereAreAvailableCertificates(CertificateTumbprintsArray, ED) Export
	
	If Not TypeOf(ED) = Type("CatalogRef.EDAttachedFiles") Then
		Return True;
	EndIf;
	
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
	|SELECT ALLOWED DISTINCT
	|	Certificates.Ref
	|FROM
	|	TU_ED AS TU_ED
	|		INNER JOIN InformationRegister.DigitallySignedEDKinds AS EDEPKinds
	|			INNER JOIN Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
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
	|				ON CertificatesFromSettingsAndProfiles.Certificate = Certificates.Ref
	|			ON EDEPKinds.DSCertificate = Certificates.Ref
	|				AND EDEPKinds.DSCertificate = Certificates.Ref
	|		ON TU_ED.EDKind = EDEPKinds.EDKind
	|WHERE
	|	Not Certificates.Revoked
	|	AND (Certificates.User = &CurrentUser
	|			OR Certificates.User = VALUE(Catalog.Users.EmptyRef))
	|	AND Not Certificates.DeletionMark
	|	AND EDEPKinds.Use
	|	AND Certificates.Imprint IN(&ThumbprintArray)";
	
	Query.SetParameter("ThumbprintArray", CertificateTumbprintsArray);
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("Ref", ED);

	HasCertificates = Not Query.Execute().IsEmpty();
	
	Return HasCertificates;
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// Agreements

////////////////////////////////////////////////////////////////////////////////
// Agreements

// Used if user can not be offered to select certificate from the
// list of available ones and/or enter password for certificate (for example, when scheduled job is being executed).
// Returns True if at least one certificate with a password saved to IB is found for incoming variables.
// 
// Parameters:
//  EDFSettingProfilesArray     - Array - contains references to EDF settings profiles according to which it is required to determine certificates;
//  AuthorizationParameters - Map - in this variable match is called to the calling method:
//    * Key     - CatalogRef.EDUsageAgreements - agreement for which authorization certificate is determined.
//    * Value - Map - match of certificate to its parameters:
//       ** Key     - CatalogRef.DSCertificates - authorization certificate.
//       ** Value - Structure - certificate parameters structure:
//           *** SignatureCertificate           - CatalogRef.ESCertificates.
//           *** PasswordReceived               - Boolean.
//           *** UserPassword          - String.
//           *** Imprint                   - String.
//           *** Revoked                     - Boolean.
//           *** CertificateBinaryData             - ValuesStorage.
//           *** NotifiedOnDurationOfActions      - Boolean.
//           *** EndDate               - Date.
//           *** RememberCertificatePassword - Boolean.
//
// Returns:
//  Boolean - True if the certificate(s) are found with the passwords saved to IB, otherwise, False.
//
Function ParametersAvailableForAuthorizationOnOperatorServer(Val EDFSettingProfilesArray = Undefined,
														AuthorizationParameters = Undefined) Export
	
	Try
		CertificateTumbprintsArray = CertificateTumbprintsArray();
	Except
		CertificateTumbprintsArray = New Array;
	EndTry;
	
	ParametersAvailable = False;
	If CertificateTumbprintsArray.Count() > 0 Then
		StCertificateStructuresArrays = New Structure("ThumbprintArrayServer", CertificateTumbprintsArray);
		
		Result = MatchesAgreementsAndAuthorizationCertificatesStructure(EDFSettingProfilesArray, , StCertificateStructuresArrays);
		
		AuthorizationParameters = New Map;
		AuthorizationCertificatesArrayAndAgreementsMatch = Undefined;
		AccCertificatesAndTheirStructures = Undefined;
		If Result.Property("AuthorizationCertificatesArrayAndAgreementsMatch", AuthorizationCertificatesArrayAndAgreementsMatch)
			AND Result.Property("AccCertificatesAndTheirStructures", AccCertificatesAndTheirStructures)
			AND TypeOf(AuthorizationCertificatesArrayAndAgreementsMatch) = Type("Map")
			AND TypeOf(AccCertificatesAndTheirStructures) = Type("Map") Then
			// IN AuthorizationCertificatesArrayAndAgreementsMatch - Key - Agreement, Value - Certificates
			// array by the current agreement. Function should return (in AuthorizationParameters) Match in which Key - Agreement,
			// Value - Match of certificate to its parameters.
			For Each Item IN AuthorizationCertificatesArrayAndAgreementsMatch Do
				CertificatesArray = Item.Value;
				For Each Certificate IN CertificatesArray Do
					CertificateParameters = AccCertificatesAndTheirStructures.Get(Certificate);
					If CertificateParameters.PasswordReceived Then
						AuthorizationParameters.Insert(Item.Key, CertificateParameters);
						ParametersAvailable = True;
						Break;
					EndIf;
				EndDo;
			EndDo;
		EndIf;
	EndIf;
	
	Return ParametersAvailable;
	
EndFunction

// Function returns match to agreement - certificate
// data structure containing ref to certificate and its additional attributes (remember password, user password, decrypted/encrypted marker).
// 
// Parameters:
//  AgreementsArray               - Array    - contains references to agreements according to which it is required to determine certificates;
//  StCertificateStructuresArrays - Structure - contains structure with properties:
//    * CertificateStructuresArrayServer - Array - array of personal storage certificates structure from server.
//    * CertificateStructuresArrayClient - Array - array of personal storage certificates structure from client.
//  CertificatesAndPasswordsMatch      - Fixed map:
//    * Key     - CatalogRef.DSCertificates - authorization certificate.
//    * Value - String - password to certificate.
//
// Returns:
//  Map: key - agreement on ED exchange, value - DS certificate parameters
//    structure ("CertificateForAuthorization, RememberCertificatePassword, UserPassword, DecryptedMarker, EncryptedMarker").
//
Function AgreementsAndCertificatesAndParametersMatchMatchForAuthorizationServer(
		Val EDFSettingProfilesArray = Undefined, Val StCertificateStructuresArrays = Undefined,
		Val CertificatesAndPasswordsMatch = Undefined) Export
	
	Result = MatchesAgreementsAndAuthorizationCertificatesStructure(EDFSettingProfilesArray, ,
											StCertificateStructuresArrays, CertificatesAndPasswordsMatch);
	
	CorrAgreements = New Map;
	AuthorizationCertificatesArrayAndAgreementsMatch = Undefined;
	AccCertificatesAndTheirStructures = Undefined;
	If Result.Property("AuthorizationCertificatesArrayAndAgreementsMatch", AuthorizationCertificatesArrayAndAgreementsMatch)
		AND Result.Property("AccCertificatesAndTheirStructures", AccCertificatesAndTheirStructures)
		AND TypeOf(AuthorizationCertificatesArrayAndAgreementsMatch) = Type("Map")
		AND TypeOf(AccCertificatesAndTheirStructures) = Type("Map") Then
		// IN AuthorizationCertificatesArrayAndAgreementsMatch - Key - Agreement, Value - Certificates
		// array by the current agreement. Function should return Match in which Key - Agreement,
		// Value - Match of certificates to their parameters.
		For Each Item IN AuthorizationCertificatesArrayAndAgreementsMatch Do
			Map = New Map;
			CertificatesArray = Item.Value;
			For Each Certificate IN CertificatesArray Do
				Structure = AccCertificatesAndTheirStructures.Get(Certificate);
				If ValueIsFilled(Structure) AND Structure.PasswordReceived Then
					// You can log on the operator server with
					// any certificate registered in the agreement. So if there are some certificates available for
					// authorization and among them there is at least one with the saved (in the certificate
					// or session) password, then return it not to open the certificate selection dialog.
					Map = New Map;
					Map.Insert(Certificate, Structure);
					Break;
				EndIf;
				Map.Insert(Certificate, Structure);
			EndDo;
			CorrAgreements.Insert(Item.Key, Map);
		EndDo;
	EndIf;
	
	Return CorrAgreements;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Get objects attributes

// for internal use only
Function EDFSettingAttributes(EDAgreement) Export
	
	Return CommonUse.ObjectAttributesValues(EDAgreement,
		"CompanyID, IsIntercompany, EDExchangeMethod, CryptographyIsUsed,
		|BankApplication, AgreementStatus, CounterpartyCertificateForEncryption");
	
EndFunction

// Returns reference to ED agreement for the passed ED
//
// Parameters
//  <ED>  - <CatalogRef.EDAttachedFiles> - electronic document
//
// Returns:
//   <CatalogRef.EDUsageAgreements> - ED agreement
//
Function EDAgreement(Val ED) Export
	
	Return CommonUse.ObjectAttributeValue(ED, "EDAgreement");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Sberbank

Procedure SaveSberbankStatement(ED, EDAgreement, ID, NewEDArray, EDOwner = Undefined)
	
	For Each ExtractXDTO in ED.Statements.Statement Do
		ExternalID = ExtractXDTO.docId;
		If ExtractWasAlreadyReceived(EDAgreement, ExternalID) Then
			Continue;
		EndIf;
		TempFile = GetTempFileName();
		ElectronicDocumentsInternal.ExportEDtoFile(ExtractXDTO, TempFile);
		FileBinaryDataResponse = New BinaryData(TempFile);
		LinksToRepository = PutToTempStorage(FileBinaryDataResponse);
		CurDate = CurrentSessionDate();
		StartDate = ExtractXDTO.beginDate;
		EndDate = ExtractXDTO.endDate;
		DocumentPresentation = NStr("en='Bank statement from';ru='Выписка банка за период с'") + " " + Format(StartDate, "DLF=D")
								+ " " + NStr("en='to';ru='до'") + " " + Format(EndDate, "DLF=D");
		EDBankStatement = AttachedFiles.AddFile(
													EDAgreement,
													DocumentPresentation,
													"xml",
													CurDate,
													CurDate,
													LinksToRepository,
													,
													,
													Catalogs.EDAttachedFiles.GetRef());
		DigestBase64 = Digest(TempFile, EDAgreement);
		DeleteFiles(TempFile);
		
		StorageAddress = PutToTempStorage(Base64Value(DigestBase64));
		AdditFile = AttachedFiles.AddFile(EDAgreement, "DataSchema", , , , StorageAddress, , ,
														Catalogs.EDAttachedFiles.GetRef());
		FileParameters = New Structure;
		FileParameters.Insert("EDKind",                       Enums.EDKinds.AddData);
		FileParameters.Insert("ElectronicDocumentOwner", EDBankStatement);
		FileParameters.Insert("FileDescription",           "DataSchema");
		FileParameters.Insert("EDStatus",                    Enums.EDStatuses.Received);
		ElectronicDocumentsService.ChangeByRefAttachedFile(AdditFile, FileParameters, False);
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("EDAgreement",            EDAgreement);
		ParametersStructure.Insert("EDKind",                   Enums.EDKinds.BankStatement);
		ParametersStructure.Insert("EDStatus",                Enums.EDStatuses.Received);
		ParametersStructure.Insert("EDStatusChangeDate",  CurDate);
		ParametersStructure.Insert("UUIDExternal",     ExternalID);
		ParametersStructure.Insert("EDDirection",           Enums.EDDirections.Incoming);
		ParametersStructure.Insert("FileDescription",       DocumentPresentation);
		ParametersStructure.Insert("AdditionalInformation", ExtractXDTO.acc);
		If Not EDOwner = Undefined Then
			ParametersStructure.Insert("ElectronicDocumentOwner", EDOwner);
			OwnerStructure = New Structure("EDStatus", Enums.EDStatuses.ConfirmationReceived);
			ElectronicDocumentsService.ChangeByRefAttachedFile(EDOwner, OwnerStructure, False);
		EndIf;
		ElectronicDocumentsService.ChangeByRefAttachedFile(EDBankStatement, ParametersStructure, False);
		
		StorageCertificate = CommonUse.ObjectAttributeValue(EDAgreement, "CounterpartyCertificateForEncryption");
		CertificateData = StorageCertificate.Get();
		If Not CertificateData = Undefined Then
			Certificate = New CryptoCertificate(CertificateData);
			OwnerSignatures = ExtractXDTO.Sign.issuer;
			BinaryDataSignatures = ExtractXDTO.Sign.value;
			SignatureInstallationDate = ElectronicDocumentsService.SignatureInstallationDate(BinaryDataSignatures);
			SignatureInstallationDate = ?(ValueIsFilled(SignatureInstallationDate), SignatureInstallationDate, CurrentSessionDate());
			AddInformationAboutSignature(EDBankStatement, BinaryDataSignatures, Certificate.Imprint,
													SignatureInstallationDate, "", "", OwnerSignatures, CertificateData);
			NewEDArray.Add(EDBankStatement);
		EndIf;
		SaveSberbankThumbprints(ExtractXDTO);
	EndDo;
	DeleteIDRequest(EDAgreement, ID, Enums.EDKinds.QueryNightStatements);
	
EndProcedure

Procedure SaveSberbankThumbprints(ExtractXDTO)
	
	If ExtractXDTO.Docs = Undefined Then
		Return;
	EndIf;
	
	StampsData = New Map;
	
	ExternalIdentifiersArray = New Array;
	For Each PaymentOrderXDTO IN ExtractXDTO.Docs.TransInfo Do
		If Not PaymentOrderXDTO.Params = Undefined Then
			ExternalIdentifier = PaymentOrderXDTO.docid;
			StampData = New Structure;
			For Each Param IN PaymentOrderXDTO.Params.Param Do
				If Param.Name = "StampBankName" Then
					StampData.Insert("BankDescription", Param.Value);
				ElsIf Param.Name = "StampBranch" Then
					StampData.Insert("Department", Param.Value);
				ElsIf Param.Name = "StampSubBranch" Then
					StampData.Insert("Office", Param.Value);
				ElsIf Param.Name = "StampDate" Then
					StampData.Insert("OperationDate", Param.Value);
				ElsIf Param.Name = "StampBIC" Then
					StampData.Insert("BIN", Param.Value);
				ElsIf Param.Name = "StampStatus" Then
					StampData.Insert("Status", Param.Value);
				EndIf;
			EndDo;
			ExternalIdentifiersArray.Add(ExternalIdentifier);
			StampsData.Insert(ExternalIdentifier, StampData);
		EndIf;
	EndDo;
	
	If ExternalIdentifiersArray.Count() = 0 Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDAttachedFiles.Ref AS EDPaymentOrder,
	|	EDAttachedFiles.UUIDExternal
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.UUIDExternal IN(&ExternalIdentifiersArray)
	|	AND EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.PaymentOrder)";
	Query.SetParameter("ExternalIdentifiersArray", ExternalIdentifiersArray);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		AdditionalAttributes = New Structure("StampData", StampsData.Get(Selection.UUIDExternal));
		ElectronicDocumentsService.ChangeByRefAttachedFile(
			Selection.EDPaymentOrder, AdditionalAttributes, False);
	EndDo;
	
EndProcedure

Procedure SaveSberbankResponse(ED, EDAgreement, ID, EDKind, NewEDArray)
	
	DeleteIDRequest(EDAgreement, ID, EDKind);
	
	If EDKind = Enums.EDKinds.QueryNightStatements AND Not ED.Statements = Undefined Then
		SaveSberbankStatement(ED, EDAgreement, ID, NewEDArray);
		Return;
	EndIf;
		
	If ED.Tickets = Undefined Then
		Return;
	EndIf;
	
	EDQuery = New Query;
	EDQuery.Text =
	"SELECT TOP 1
	|	EDAttachedFiles.Ref
	|INTO EDOwner
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.UniqueId = &UniqueId
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	EDAttachedFiles.Ref
	|INTO BankResponseED
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.ElectronicDocumentOwner In
	|			(SELECT
	|				EDOwner.Ref
	|			FROM
	|				EDOwner AS EDOwner)
	|	AND EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.STATEMENT)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	EDAttachedFiles.Ref
	|INTO DigestReceipts
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.AddData)
	|	AND EDAttachedFiles.ElectronicDocumentOwner In
	|			(SELECT
	|				EDOwner.Ref
	|			FROM
	|				BankResponseED AS EDOwner)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BankResponseED.Ref AS EDBankResponse,
	|	EDOwner.Ref AS EDOwner,
	|	DigestReceipts.Ref AS EDDigestReceipts
	|FROM
	|	EDOwner AS EDOwner
	|		LEFT JOIN BankResponseED AS BankResponseED
	|		ON (TRUE)
	|		LEFT JOIN DigestReceipts AS DigestReceipts
	|		ON (TRUE)";

	For Each Ticket IN ED.Tickets.Ticket Do
		If Ticket.Info = Undefined OR Ticket.Info.docExtId = Undefined AND ValueIsFilled(Ticket.docId) Then
			UUIDExternal = Ticket.docId;
			EDQuery.Text = StrReplace(EDQuery.Text, "UniqueId", "UUIDExternal");
			EDQuery.SetParameter("UUIDExternal", UUIDExternal);
		ElsIf ValueIsFilled(Ticket.Info.docExtId) Then
			UniqueId = Ticket.Info.docExtId;
			EDQuery.SetParameter("UniqueId", UniqueId);
		ElsIf ValueIsFilled(ED.RequestId) Then
			UniqueId = ED.RequestId;
			EDQuery.SetParameter("UniqueId", UniqueId);
		EndIf;
		SelectionED = EDQuery.Execute().Select();
		If SelectionED.Next() Then
			If Not ValueIsFilled(SelectionED.EDOwner) Then
				Return;
			EndIf;
			If  Not ED.Statements = Undefined Then
				SaveSberbankStatement(ED, EDAgreement, ID, NewEDArray, SelectionED.EDOwner);
				Return;
			EndIf;
			TempFile = GetTempFileName();
			ElectronicDocumentsInternal.ExportEDtoFile(Ticket, TempFile);
			FileBinaryDataResponse = New BinaryData(TempFile);
			LinksToRepository = PutToTempStorage(FileBinaryDataResponse);
			
			FileOwner = CommonUse.ObjectAttributeValue(SelectionED.EDOwner, "FileOwner");
			OwnerStructure = New Structure;
			
			CurDate = CurrentSessionDate();
			If Not ValueIsFilled(SelectionED.EDBankResponse) Then
				EDName = NStr("en='Receipt from';ru='Квитанция от'")+ " " + Format(CurDate, "DLF=DDT");
				EDBankResponse = AttachedFiles.AddFile(FileOwner, EDName, "xml", CurDate, CurDate,
										LinksToRepository, , , Catalogs.EDAttachedFiles.GetRef());
				StructureResponseBank = New Structure;
				StructureResponseBank.Insert("ElectronicDocumentOwner", SelectionED.EDOwner);
				StructureResponseBank.Insert("EDAgreement",                EDAgreement);
				StructureResponseBank.Insert("UniqueId",                ED.responseId);
				StructureResponseBank.Insert("EDKind",                       Enums.EDKinds.STATEMENT);
				StructureResponseBank.Insert("EDStatus",                    Enums.EDStatuses.Received);
				StructureResponseBank.Insert("EDDirection",               Enums.EDDirections.Incoming);
				StructureResponseBank.Insert("FileDescription",           NStr("en='Receipt from';ru='Квитанция от'")+ " " + Format(CurDate, "DLF=DDT"));
				ElectronicDocumentsService.ChangeByRefAttachedFile(EDBankResponse, StructureResponseBank, False);
				OwnerStructure.Insert("UUIDExternal", Ticket.docId);
			Else
				AttachedFilesService.WriteFileToInformationBase(SelectionED.EDBankResponse, FileBinaryDataResponse);
				
				StructureResponseBank = New Structure;
				StructureResponseBank.Insert("Description", NStr("en='Receipt from';ru='Квитанция от'") + " " + Format(CurDate, "DLF=DDT"));
				StructureResponseBank.Insert("Extension",                   "xml");
				StructureResponseBank.Insert("ModificationDateUniversal", CurDate);
				StructureResponseBank.Insert("CreationDate",                 CurDate);
				StructureResponseBank.Insert("EDStatusChangeDate",       CurrentSessionDate());
				StructureResponseBank.Insert("UniqueId",                 ED.responseId);
				StructureResponseBank.Insert("DeleteDS");
				ElectronicDocumentsService.ChangeByRefAttachedFile(
								SelectionED.EDBankResponse, StructureResponseBank, False);
				EDBankResponse = SelectionED.EDBankResponse;
			EndIf;
			DigestBase64 = Digest(TempFile, EDAgreement);
			DeleteFiles(TempFile);
			
			DigestBinaryData = Base64Value(DigestBase64);
			
			If Not ValueIsFilled(SelectionED.EDDigestReceipts) Then
				StorageAddress = PutToTempStorage(DigestBinaryData);
				AdditFile = AttachedFiles.AddFile(
					EDAgreement, "DataSchema", , , , StorageAddress, , , Catalogs.EDAttachedFiles.GetRef());
				FileParameters = New Structure;
				FileParameters.Insert("EDKind",                       Enums.EDKinds.AddData);
				FileParameters.Insert("ElectronicDocumentOwner", EDBankResponse);
				FileParameters.Insert("FileDescription",           "DataSchema");
				FileParameters.Insert("EDStatus",                    Enums.EDStatuses.Received);
				ElectronicDocumentsService.ChangeByRefAttachedFile(AdditFile, FileParameters, False);
			Else
				AttachedFilesService.WriteFileToInformationBase(SelectionED.EDDigestReceipts, DigestBinaryData);
			EndIf;
			
			If Not Ticket.Sign = Undefined Then
				StorageCertificate = CommonUse.ObjectAttributeValue(EDAgreement, "CounterpartyCertificateForEncryption");
				CertificateData = StorageCertificate.Get();
				If Not CertificateData = Undefined Then
					Certificate = New CryptoCertificate(CertificateData);
					OwnerSignatures = Ticket.Sign.issuer;
					BinaryDataSignatures = Ticket.Sign.value;
					SignatureInstallationDate = ElectronicDocumentsService.SignatureInstallationDate(BinaryDataSignatures);
					SignatureInstallationDate = ?(ValueIsFilled(SignatureInstallationDate), SignatureInstallationDate, CurrentSessionDate());
					AddInformationAboutSignature(EDBankResponse, BinaryDataSignatures, Certificate.Imprint,
															SignatureInstallationDate, "", "", OwnerSignatures, CertificateData);
					NewEDArray.Add(EDBankResponse);
				EndIf;
			EndIf;
		
			Information = Ticket.Info;
			If Not Information=Undefined Then
				StatusSBBOL = Upper(Information.statusStateCode);
				If StatusSBBOL = "ACCEPTED" Then
					NewEDStatus = Enums.EDStatuses.Accepted
				ElsIf StatusSBBOL = "IMPLEMENTED" Then
					NewEDStatus = Enums.EDStatuses.Executed
				ElsIf StatusSBBOL = "DELIVERED" Then
					NewEDStatus = Enums.EDStatuses.Delivered
				ElsIf StatusSBBOL = "CARD2" Then
					NewEDStatus = Enums.EDStatuses.CardFile2
				ElsIf StatusSBBOL = "FORMAT_ERROR"
						OR StatusSBBOL = "RQUID_DUPLIC"
						OR StatusSBBOL = "ORG_NOT_FOUND"
						OR StatusSBBOL = "SERT_NOT_FOUND"
						OR StatusSBBOL = "DECLINED_BY_BANK"
						OR StatusSBBOL = "DECLINED"
						OR StatusSBBOL = "FAIL"
						OR StatusSBBOL = "DOCUMENT_NOT_FOUND" Then
					NewEDStatus = Enums.EDStatuses.RejectedByBank
				ElsIf StatusSBBOL = "INVALIDEDS" Then
					NewEDStatus = Enums.EDStatuses.ESNotCorrect
				ElsIf StatusSBBOL = "REQUISITE_ERROR" Then
					NewEDStatus = Enums.EDStatuses.AttributesError
				ElsIf StatusSBBOL = "DECLINED_BY_ABS" Then
					NewEDStatus = Enums.EDStatuses.RefusedABC
				ElsIf StatusSBBOL = "DELAYED" Then
					NewEDStatus = Enums.EDStatuses.Suspended
				ElsIf StatusSBBOL = "RECALL" Then
					NewEDStatus = Enums.EDStatuses.Rejected
				ElsIf StatusSBBOL = "PROCESSED" Then
					NewEDStatus = Enums.EDStatuses.Processed
				EndIf;
				If ValueIsFilled(NewEDStatus) Then
					OwnerStructure.Insert("EDStatus", NewEDStatus);
				EndIf
			EndIf;
			
			If OwnerStructure.Count() > 0 Then
				ElectronicDocumentsService.ChangeByRefAttachedFile(SelectionED.EDOwner, OwnerStructure, False);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Function ExtractWasAlreadyReceived(EDAgreement, ExternalIdentifier)
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	EDAttachedFiles.Ref
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.EDAgreement = &EDAgreement
	|	AND EDAttachedFiles.UUIDExternal = &UUIDExternal";
	Query.SetParameter("EDAgreement", EDAgreement);
	Query.SetParameter("UUIDExternal", ExternalIdentifier);
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Procedure SaveBankStamps(StatementDS)

	BinaryDataED = AttachedFiles.GetFileBinaryData(StatementDS);
	FileName = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
	BinaryDataED.Write(FileName);
	StructureFileParser = ElectronicDocumentsInternal.GenerateParseTree(FileName);
	DeleteFiles(FileName);
	ParseTree = StructureFileParser.ParseTree;
	ObjectString = StructureFileParser.ObjectString;
	TSRows = ObjectString.Rows.FindRows(New Structure("Attribute", "TSRow"));
	For Each TSRow IN TSRows Do
		DateCredited = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
															ParseTree, TSRow, "DateCredited");
		BankStampStatus = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
															ParseTree, TSRow, "BankStampStatus");
		PaymentId = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
															ParseTree, TSRow, "PaymentId");
		If ValueIsFilled(DateCredited) AND ValueIsFilled(BankStampStatus) AND ValueIsFilled(PaymentId) Then
			ED = Catalogs.EDAttachedFiles.GetRef(New UUID(PaymentId));
			If ED.GetObject() <> Undefined Then
				BankStampName = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree, TSRow, "BankStampName");
				BankStampBranch = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree, TSRow, "BankStampBranch");
				BankStampBIC = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																	ParseTree, TSRow, "BankStampBIC");
				StampData = New Structure();
				StampData.Insert("BankDescription", BankStampName);
				StampData.Insert("Department", BankStampBranch);
				StampData.Insert("BIN", BankStampBIC);
				StampData.Insert("Status", BankStampStatus);
				StampData.Insert("OperationDate", DateCredited);
				Stamp = New Structure("StampData", StampData);
				StructureChanges = New Structure("AdditionalAttributes", Stamp);
				ElectronicDocumentsService.ChangeByRefAttachedFile(ED, StructureChanges, False);
			EndIf;
		EndIf;
	EndDo
	
EndProcedure

// Returns string with the certificate content as Base64
//
// Parameters
//  <RefToStorage>  - <String> - ref to storage with certificate binary data
//
// Returns:
//   <String>   - String contains certificate data as Base64
//
Function CertificateInFormatBase64(LinksToRepository)

	CertificateBinaryData = LinksToRepository.Get();
	
	StringBase64 = Base64String(CertificateBinaryData);
	StringBase64 = "-----BEGIN CERTIFICATE-----" + Chars.LF + StringBase64 + Chars.LF + "-----END CERTIFICATE-----";

	Return StringBase64;

EndFunction // CertificateAsBase64()

// Returns an array of sent statement request IDs to which statement was not received
//
// Parameters:
// EDAgreement - CatalogRef.AgreementsED
//
// Returns:
// Array or Undefined
//
Function ArrayOfIDsDocumentsBank(EDAgreement)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDAttachedFiles.UUIDExternal AS ID,
	|	EDAttachedFiles.Ref AS ED
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.EDAgreement = &EDAgreement
	|	AND EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.QueryStatement)
	|	AND Not EDAttachedFiles.UUIDExternal = """"
	|	AND (EDAttachedFiles.EDStatus = VALUE(Enum.EDStatuses.Delivered)
	|			OR EDAttachedFiles.EDStatus = VALUE(Enum.EDStatuses.Accepted))
	|	AND Not EDAttachedFiles.DeletionMark";
	Query.SetParameter("EDAgreement", EDAgreement);
	QueryResult = Query.Execute();
	
	ResultTab = QueryResult.Unload();
	
	Return ResultTab.UnloadColumn("ID");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Generate electronic documents

Function PackageFormatVersion(Package) Export
	
	Return CommonUse.ObjectAttributeValue(Package, "PackageFormatVersion");
	
EndFunction

// Determines whether there is an available agreement and if you want to receive documents by it, you will need cryptography
// 
// Returns:
//  Boolean - whether there is at least one agreement or not
//
Function HasAgreementsRequiringDS() Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	AgreementsEDOutgoing.Ref
	|FROM
	|	Catalog.EDUsageAgreements.OutgoingDocuments AS AgreementsEDOutgoing
	|WHERE
	|	AgreementsEDOutgoing.Ref.ConnectionStatus = VALUE(Enum.EDExchangeMemberStatuses.Connected)
	|	AND (AgreementsEDOutgoing.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom)
	|			OR (AgreementsEDOutgoing.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughDirectory)
	|				OR AgreementsEDOutgoing.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEMail)
	|				OR AgreementsEDOutgoing.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughFTP))
	|				AND Not AgreementsEDOutgoing.Ref.CompanyCertificateForDetails = VALUE(Catalog.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef))";
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Returns match with available certificates data.
//
// Parameters:
//  <EDAgreement> - CatalogRef.EDUsageAgreement - ref to agreement
//
// Returns:
//  Map - Key - ref to the DSCertificates catalog item, value - certificate binary data
//
Function AvailableCertificates(EDAgreement) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Certificates.Ref,
	|	Certificates.CertificateData AS CertificateData,
	|	UNDEFINED AS UserPassword,
	|	FALSE AS RememberCertificatePassword,
	|	FALSE AS PasswordReceived,
	|	Certificates.Imprint,
	|	BankApplications.BankApplication
	|FROM
	|	Catalog.EDUsageAgreements.CompanySignatureCertificates AS CompanySignatureCertificates
	|		LEFT JOIN Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
	|			LEFT JOIN InformationRegister.BankApplications AS BankApplications
	|			ON Certificates.Ref = BankApplications.DSCertificate
	|		ON CompanySignatureCertificates.Certificate = Certificates.Ref
	|WHERE
	|	CompanySignatureCertificates.Ref = &EDAgreement
	|	AND (Certificates.User = &CurrentUser
	|			OR Certificates.User = &EmptyUser)";
	Query.SetParameter("EDAgreement", EDAgreement);
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("EmptyUser", Catalogs.Users.EmptyRef());
	Result = Query.Execute().Select();
	ReturnData = New Map;
	While Result.Next() Do
		Structure = New Structure("UserPassword, Thumbprint, CertificateData, PasswordReceived, RememberCertificatePassword, BankApplication");
		FillPropertyValues(Structure, Result);
		Structure.Insert("CertificateData", Result.CertificateData.Get());
		ReturnData.Insert(Result.Ref, Structure);
	EndDo;
	Return ReturnData;
	
EndFunction

// See this function in the ElectronicDocumentsService module.
Function GetFileData(Val AttachedFile,
                            Val FormID = Undefined,
                            Val GetRefToBinaryData = True) Export
	
	Return ElectronicDocumentsService.GetFileData(
		AttachedFile, FormID, GetRefToBinaryData);
	
EndFunction

Function EDKindAndOwner(LinkToED) Export
	
	Return CommonUse.ObjectAttributesValues(LinkToED, "EDKind, FileOwner");
	
EndFunction

// Procedure is used to minimize server calls
// if it is required to get on client all or several values listed in the constants parameters.
//
Procedure VariablesInitialise(PerformCryptoOperationsAtServer = Undefined,
									 ServerAuthorizationPerform = Undefined,
									 ImmediateEDSending = Undefined,
									 IsCryptofacilitiesAtServer = Undefined) Export
	
	ImmediateEDSending = ElectronicDocumentsService.ImmediateEDSending();
	ServerAuthorizationPerform = ServerAuthorizationPerform();
	PerformCryptoOperationsAtServer = PerformCryptoOperationsAtServer();
	IsCryptofacilitiesAtServer = IsCryptofacilitiesAtServer(PerformCryptoOperationsAtServer);
	
EndProcedure

// Returns posted documents array
//
// Parameters:
//  DocumentArray - Array - references to documents array 
//
// Returns:
//  Array - array of references to documents that are posted
//
Function PostedDocumentsArray(Val DocumentArray) Export
	
	PostedDocumentsArray = New Array;
	PostingDocumentsArray = PostingDocumentsArray(DocumentArray);
	
	For Each Document IN PostingDocumentsArray Do
		If CommonUse.ObjectAttributeValue(Document, "Posted") Then
			PostedDocumentsArray.Add(Document);
		EndIf;
	EndDo;
	
	Return PostedDocumentsArray;
	
EndFunction

Procedure FillEDSigerData(FileName, Company, SignatureCertificate, EDKind)
	
	XMLObject = New XMLReader;
	XMLObject.OpenFile(FileName);
	
	// Read content of XML file
	DOMBuilder = New DOMBuilder();
	DOMDocument = DOMBuilder.Read(XMLObject);
	
	// Clear temporary file for recording
	XMLObject.Close();
	
	// Get the Signer tag data processor.
	SignerDOM = DOMDocument.GetElementByTagName("Signer");
	
	SignatoryIE = SignerDOM[0].GetElementByTagName("CO");
	If SignatoryIE.Count() > 0 Then
		SignerDOM[0].RemoveChild(SignatoryIE[0]);
	EndIf;

	SignatoryLP = SignerDOM[0].GetElementByTagName("LegalEntity");
	If SignatoryLP.Count() > 0 Then
		SignerDOM[0].RemoveChild(SignatoryLP[0]);
	EndIf;
	
	// Expand full name from the certificate.
	CertificateParameters = CertificateAttributes(SignatureCertificate);
	SurnameCertificate   = CertificateParameters.Surname;
	CertificateName       = CertificateParameters.Name;
	CertificatePatronimic  = CertificateParameters.Patronymic;
	
	PositionByCertificate = "---";
	If ValueIsFilled(CertificateParameters.Position) Then
		PositionByCertificate = CertificateParameters.Position;
	EndIf;
	
	ThisIsInd = ElectronicDocumentsOverridable.ThisIsInd(Company);
	DataLegalIndividual = ElectronicDocumentsOverridable.GetDataLegalIndividual(Company);

	SignerSNP = DOMDocument.CreateElement("Initials");
	
	SignerSNP.SetAttribute("Surname",  SurnameCertificate);
	SignerSNP.SetAttribute("Name",      CertificateName);
	If ValueIsFilled(CertificatePatronimic) Then
		SignerSNP.SetAttribute("Patronymic", CertificatePatronimic);
	EndIf;
	
	If ThisIsInd Then
		SignerAndSLP = DOMDocument.CreateElement("CO");
		
		// Check whether TIN mandatory field is filled in for SP
		If Not DataLegalIndividual.Property("TIN") OR StrLen(DataLegalIndividual.TIN) <> 12 Then
			MessagePattern = NStr("en='Operation is canceled. TIN is filled in incorrectly in the %1 company.';ru='Операция отменена. Не корректно заполнено поле ""ИИН"" в организации %1.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Company);
			
			Raise MessageText;
		EndIf;
		
		SignerAndSLP.SetAttribute("TINInd", DataLegalIndividual.TIN);
		
		LicenceData = "";
		ElectronicDocumentsOverridable.CertificateAboutRegistrationIPData(Company, LicenceData);
		SignerAndSLP.SetAttribute("PrFedRegSN", LicenceData);
	Else
		SignerAndSLP = DOMDocument.CreateElement("LegalEntity");
		
		// Check whether TIN mandatory field is filled in for LE
		If Not DataLegalIndividual.Property("TIN") OR StrLen(DataLegalIndividual.TIN) <> 10 Then
			MessagePattern = NStr("en='Operation is canceled. TIN is filled in incorrectly in the %1 company.';ru='Операция отменена. Не корректно заполнено поле ""ИИН"" в организации %1.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Company);
			
			Raise MessageText;
		EndIf;
		
		SignerAndSLP.SetAttribute("TINLP", DataLegalIndividual.TIN);
		SignerAndSLP.SetAttribute("Posit", PositionByCertificate);
	EndIf;
	
	SignerAndSLP.AppendChild(SignerSNP);
	SignerDOM[0].AppendChild(SignerAndSLP);
	
	If EDKind = Enums.EDKinds.TORG12Seller
		OR EDKind = Enums.EDKinds.AgreementAboutCostChangeSender Then
		
		ReleaseCargoDOM = DOMDocument.GetElementByTagName("ReleaseCargo");
		If ReleaseCargoDOM.Count() > 0 Then
			
			// Delete extra Tags
			Accountant = ReleaseCargoDOM[0].GetElementByTagName("Accountant");
			If Accountant.Count() > 0 Then
				ReleaseCargoDOM[0].RemoveChild(Accountant[0]);
			EndIf;
			ReleaseMade = ReleaseCargoDOM[0].GetElementByTagName("ReleaseMad");
			If ReleaseMade.Count() > 0 Then
				ReleaseCargoDOM[0].RemoveChild(ReleaseMade[0]);
			EndIf;
			
			ReleasePermitted = ReleaseCargoDOM[0].GetElementByTagName("ReleasePerm");
			If ReleasePermitted.Count() > 0 Then
				ReleaseCargoDOM[0].RemoveChild(ReleasePermitted[0]);
			EndIf;
			ReleasePermitted = DOMDocument.CreateElement("ReleasePerm");
			
			DescriptionFullRespPersonType = DOMDocument.CreateElement("Initials");
			
			DescriptionFullRespPersonType.SetAttribute("Surname",  SurnameCertificate);
			DescriptionFullRespPersonType.SetAttribute("Name",      CertificateName);
			If ValueIsFilled(CertificatePatronimic) Then
				DescriptionFullRespPersonType.SetAttribute("Patronymic", CertificatePatronimic);
			EndIf;
			If ValueIsFilled(PositionByCertificate) Then
				ReleasePermitted.SetAttribute("Position", PositionByCertificate);
			EndIf;
			ReleasePermitted.AppendChild(DescriptionFullRespPersonType);
			
			ReleaseCargoDOM[0].AppendChild(ReleasePermitted);
		EndIf;
	
	ElsIf EDKind = Enums.EDKinds.TORG12Customer
		OR EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient Then
		
		ReceivedCargoDOM = DOMDocument.GetElementByTagName("ReceiveCargo");
		If ReceivedCargoDOM.Count() > 0 Then
			
			CargoTaken = ReceivedCargoDOM[0].GetElementByTagName("CargoTaken");
			If CargoTaken.Count() > 0 Then
				ReceivedCargoDOM[0].RemoveChild(CargoTaken[0]);
			EndIf;
			CargoTaken = DOMDocument.CreateElement("CargoTaken");
			
			DescriptionFullRespPersonType = DOMDocument.CreateElement("Initials");
			
			DescriptionFullRespPersonType.SetAttribute("Surname",  SurnameCertificate);
			DescriptionFullRespPersonType.SetAttribute("Name",      CertificateName);
			If ValueIsFilled(CertificatePatronimic) Then
				DescriptionFullRespPersonType.SetAttribute("Patronymic", CertificatePatronimic);
			EndIf;
			If ValueIsFilled(PositionByCertificate) Then
				CargoTaken.SetAttribute("Position", PositionByCertificate);
			EndIf;
			CargoTaken.AppendChild(DescriptionFullRespPersonType);
			
			ReceivedCargoDOM[0].AppendChild(CargoTaken);
		EndIf;
		
	ElsIf EDKind = Enums.EDKinds.ActPerformer Then
		
		DeliveredDOM = DOMDocument.GetElementByTagName("Delivered");
		If DeliveredDOM.Count() > 0 Then
			
			// Delete extra Tags
			ExecutivePowerOfAttorney = DeliveredDOM[0].GetElementByTagName("ExecPowOfAtt");
			If ExecutivePowerOfAttorney.Count() > 0 Then
				DeliveredDOM[0].RemoveChild(ExecutivePowerOfAttorney[0]);
			EndIf;
			
			ExecutantSignature = DeliveredDOM[0].GetElementByTagName("ExecutSignature");
			If ExecutantSignature.Count() > 0 Then
				DeliveredDOM[0].RemoveChild(ExecutantSignature[0]);
			EndIf;
			ExecutantSignature = DOMDocument.CreateElement("ExecutSignature");
			
			DescriptionFullRespPersonType = DOMDocument.CreateElement("Initials");
			
			DescriptionFullRespPersonType.SetAttribute("Surname",  SurnameCertificate);
			DescriptionFullRespPersonType.SetAttribute("Name",      CertificateName);
			If ValueIsFilled(CertificatePatronimic) Then
				DescriptionFullRespPersonType.SetAttribute("Patronymic", CertificatePatronimic);
			EndIf;
			If ValueIsFilled(PositionByCertificate) Then
				ExecutantSignature.SetAttribute("Position", PositionByCertificate);
			EndIf;
			ExecutantSignature.AppendChild(DescriptionFullRespPersonType);
			
			DeliveredDOM[0].AppendChild(ExecutantSignature);
		EndIf;
		
	ElsIf EDKind = Enums.EDKinds.ActCustomer Then
		
		ReceivedDOM = DOMDocument.GetElementByTagName("Accepted");
		If ReceivedDOM.Count() > 0 Then
			
			// Delete extra Tags
			CustomerPowerOfAttorney = ReceivedDOM[0].GetElementByTagName("PowOfAttornOrder");
			If CustomerPowerOfAttorney.Count() > 0 Then
				ReceivedDOM[0].RemoveChild(CustomerPowerOfAttorney[0]);
			EndIf;
			
			SignatureOfCustomer = ReceivedDOM[0].GetElementByTagName("SignatureOrder");
			If SignatureOfCustomer.Count() > 0 Then
				ReceivedDOM[0].RemoveChild(SignatureOfCustomer[0]);
			EndIf;
			SignatureOfCustomer = DOMDocument.CreateElement("SignatureOrder");
			
			DescriptionFullRespPersonType = DOMDocument.CreateElement("Initials");
			
			DescriptionFullRespPersonType.SetAttribute("Surname",  SurnameCertificate);
			DescriptionFullRespPersonType.SetAttribute("Name",      CertificateName);
			If ValueIsFilled(CertificatePatronimic) Then
				DescriptionFullRespPersonType.SetAttribute("Patronymic", CertificatePatronimic);
			EndIf;
			If ValueIsFilled(PositionByCertificate) Then
				SignatureOfCustomer.SetAttribute("Position", PositionByCertificate);
			EndIf;
			SignatureOfCustomer.AppendChild(DescriptionFullRespPersonType);
			
			ReceivedDOM[0].AppendChild(SignatureOfCustomer);
		EndIf;
		
	EndIf;
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(FileName, "windows-1251");
	DOMWriter = New DOMWriter;
	DOMWriter.Write(DOMDocument, XMLWriter);
	XMLWriter.Close();
	
EndProcedure

Procedure FillEDSigerDataCML_206(FileName, Company, SignatureCertificate)
	
	XMLObject = New XMLReader;
	XMLObject.OpenFile(FileName);
	
	// Read content of XML file
	DOMBuilder = New DOMBuilder();
	DOMDocument = DOMBuilder.Read(XMLObject);
	
	// Clear temporary file for recording
	XMLObject.Close();
	
	BusinessInformationDOM = DOMDocument.GetElementByTagName("BusinessInformation");
	If BusinessInformationDOM.Count() > 0 AND BusinessInformationDOM[0].HasAttribute("SchemaVersion") Then
		SchemaVersion = BusinessInformationDOM[0].GetAttributeNode("SchemaVersion").NodeValue;
		
		// Get the Signers tag for data processor.
		SignersDOM = DOMDocument.GetElementByTagName("Signatories");
		If SignersDOM.Count() > 0
			AND SchemaVersion = TrimAll(StrReplace(ElectronicDocumentsReUse.CML2SchemeVersion(), "CML", "")) Then
			
			//SignersDOM = DOMDocument.CreateItem("Signatories");
			Signer = SignersDOM[0].GetElementByTagName("Signer");
			If Signer.Count() > 0 Then
				SignersDOM[0].RemoveChild(Signer[0]);
			EndIf;
			Signer = DOMDocument.CreateElement("Signer");
			
			// Expand full name from the certificate.
			CertificateParameters = CertificateAttributes(SignatureCertificate);
			SurnameCertificate   = CertificateParameters.Surname;
			CertificateName       = CertificateParameters.Name;
			CertificatePatronimic  = CertificateParameters.Patronymic;
			
			PositionByCertificate = "---";
			If ValueIsFilled(CertificateParameters.Position) Then
				PositionByCertificate = CertificateParameters.Position;
			EndIf;
			
			Surname = DOMDocument.CreateElement("Surname");
			SurnameText = DOMDocument.CreateTextNode(SurnameCertificate);
			Surname.AppendChild(SurnameText);
			Signer.AppendChild(Surname);
			
			Name = DOMDocument.CreateElement("Name");
			NameText = DOMDocument.CreateTextNode(CertificateName);
			Name.AppendChild(NameText);
			Signer.AppendChild(Name);
			
			If ValueIsFilled(CertificatePatronimic) Then
				Patronymic = DOMDocument.CreateElement("Patronymic");
				PatronymicText = DOMDocument.CreateTextNode(CertificatePatronimic);
				Patronymic.AppendChild(PatronymicText);
				Signer.AppendChild(Patronymic);
			EndIf;
			
			If Not ElectronicDocumentsOverridable.ThisIsInd(Company) Then
				Position = DOMDocument.CreateElement("Position");
				PositionText = DOMDocument.CreateTextNode(PositionByCertificate);
				Position.AppendChild(PositionText);
				Signer.AppendChild(Position);
			EndIf;
			SignersDOM[0].AppendChild(Signer);
			
			XMLWriter = New XMLWriter;
			XMLWriter.OpenFile(FileName, "windows-1251");
			DOMWriter = New DOMWriter;
			DOMWriter.Write(DOMDocument, XMLWriter);
			XMLWriter.Close();
		EndIf;
		
	EndIf;

EndProcedure

Procedure FillServiceEDSigerData(FileName, Company, SignatureCertificate)
	
	XMLObject = New XMLReader;
	XMLObject.OpenFile(FileName);
	
	// Read content of XML file
	DOMBuilder = New DOMBuilder();
	DOMDocument = DOMBuilder.Read(XMLObject);
	
	// Clear temporary file for writing.
	XMLObject.Close();
	
	// Determine your names space.
	SignerDOM = DOMDocument.GetElementByTagName("Signer");
	
	// Expand full name from the certificate.
	CertificateParameters= CertificateAttributes(SignatureCertificate);
	SurnameCertificate  = CertificateParameters.Surname;
	CertificateName      = CertificateParameters.Name;
	CertificatePatronimic = CertificateParameters.Patronymic;
	
	PositionByCertificate = "---";
	If ValueIsFilled(CertificateParameters.Position) Then
		PositionByCertificate = CertificateParameters.Position;
	EndIf;
	
	SignerDOM[0].SetAttribute("Position", PositionByCertificate);
	
	SignerSNP = SignerDOM[0].GetElementByTagName("Initials");
	
	SignerSNP[0].SetAttribute("Surname", SurnameCertificate);
	SignerSNP[0].SetAttribute("Name",     CertificateName);
	If ValueIsFilled(CertificatePatronimic) Then
		SignerSNP[0].SetAttribute("Patronymic", CertificatePatronimic);
	EndIf;
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(FileName, "windows-1251");
	DOMWriter = New DOMWriter;
	DOMWriter.Write(DOMDocument, XMLWriter);
	XMLWriter.Close();
	
EndProcedure

// For internal use only
Procedure ValidateCertificateValidityPeriod(Certificate) Export
	
	If Not (ValueIsFilled(Certificate)
			AND TypeOf(Certificate) = Type("CatalogList.DigitalSignaturesAndEncryptionKeyCertificates")) Then
		Return;
	EndIf;
	
	CertificateAttributes = CertificateAttributes(Certificate);
	DATEDIFF = CertificateAttributes.ValidUntil - CurrentSessionDate();
	If Not CertificateAttributes.UserNotifiedOnValidityInterval AND DATEDIFF > 0 AND DATEDIFF < 60*60*24*31 Then
		Operation = NStr("en='Certificate validity period check';ru='Проверка срока действия сертификата'");
		ErrorText = NStr("en='The certificate validity period
		|is being expired %1 It is required to get a new one';ru='Заканчивается срок
		|действия сертификата %1 Необходимо получить новый'");
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, String(Certificate));
		ProcessExceptionByEDOnServer(Operation, ErrorText);
	EndIf;
	
EndProcedure

// For internal use only
Procedure SetResponsibleED(Val ObjectList, Val NewResponsible, ProcessedEDCount, RedirectionReason = "") Export
	
	EDKindsArray = New Array;
	ProcessedEDCount = 0;
	
	For Each ListIt IN ObjectList Do
		If TypeOf(ListIt) = Type("DynamicalListGroupRow") Then
			Continue;
		EndIf;
		EDKindsArray.Add(ListIt.Ref);
	EndDo;
	
	If EDKindsArray.Count() = 0 Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED
	|	EDAttachedFiles.Ref,
	|	EDAttachedFiles.Responsible,
	|	EDAttachedFiles.EDStatus
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.Ref IN(&EDKindsArray)
	|	AND (EDAttachedFiles.Responsible <> &Responsible
	|			OR &DescriptionRecord)");
	
	Query.SetParameter("EDKindsArray",      EDKindsArray);
	Query.SetParameter("Responsible", NewResponsible);
	Query.SetParameter("DescriptionRecord", ?(ValueIsFilled(RedirectionReason), True, False));
	
	Selection = Query.Execute().Select();
	
	BeginTransaction();
	ErrorCommonText = "";
	
	While Selection.Next() Do
		
		Try
			LockDataForEdit(Selection.Ref);
		Except
			ErrorText = NStr("en='Failed to lock electronic document (%Object%). %ErrorDescription%';ru='Не удалось заблокировать электронный документ (%Объект%). %ОписаниеОшибки%'");
			ErrorText = StrReplace(ErrorText, "%Object%",         Selection.Ref);
			ErrorText = StrReplace(ErrorText, "%ErrorDescription%", BriefErrorDescription(ErrorInfo()));
			ErrorCommonText = ErrorCommonText + Chars.LF + ErrorText;
			RollbackTransaction();
			Raise ErrorText;
		EndTry;
	
		Try
			ParametersStructure = New Structure("Responsible", NewResponsible);
			ParametersStructure.Insert("Definition", RedirectionReason);
			ElectronicDocumentsService.ChangeByRefAttachedFile(Selection.Ref, ParametersStructure, False);
			ProcessedEDCount = ProcessedEDCount + 1;
		Except
			ErrorText = NStr("en='Failed to write the electronic document.';ru='Не удалось выполнить запись электронного документа'") + " (%Object%). %ErrorDescription%'";
			ErrorText = StrReplace(ErrorText, "%Object%",         Selection.Ref);
			ErrorText = StrReplace(ErrorText, "%ErrorDescription%", BriefErrorDescription(ErrorInfo()));
			ErrorCommonText = ErrorCommonText + Chars.LF + ErrorText;
			RollbackTransaction();
			Raise ErrorText;
		EndTry
		
	EndDo;
	
	CommitTransaction();
	
EndProcedure

// Allows to get DS certificate attribute values.
//
// Parameters:
//  DS certificate - catalog-ref - ref to the "DS certificates" catalog item.
//
// Returns:
//  Attribute values structure.
//
Function CertificateAttributes(DSCertificate) Export
	
	CertificateParameters = CommonUse.ObjectAttributesValues(DSCertificate,
		"Revoked, Thumbprint, ValidUntil,
		|UserNotifiedOnValidityTerm, Surname, Name, Patronymic, Position,
		|Company, CertificateData, Name, User");
	CertificateParameters.Insert("CertificateBinaryData", CertificateParameters.CertificateData.Get());
	CertificateParameters.Insert("SelectedCertificate", DSCertificate);
	CertificateParameters.Insert("PasswordReceived", False);
	CertificateParameters.Insert("UserPassword", Undefined);
	
	// Parameter is required in SSL methods
	CertificateParameters.Insert("Comment", "");
	
	Return CertificateParameters;
	
EndFunction

// For internal use only
Function GenerateServiceED(EDKindsArray, EDKind, CorrectionText = "") Export
	
	SetPrivilegedMode(True);
	
	ReturnArray = New Array;
	
	EDData = CommonUse.ObjectAttributeValues(EDKindsArray, "EDDirection, Counterparty,
	                      |EDKind, EDStatus, UUID, EDFProfileSettings, EDAgreement, EDFScheduleVersion, EDVersionPointType, FileOwner, EDNumber");
	
	For Each LinkToED IN EDKindsArray Do
	
		EDParameters = EDData.Get(LinkToED);
		
		IsNotification = Not ValueIsFilled(CorrectionText);
		
		If IsNotification Then
			// Do not generate notification on receiving 20 schedule for version in the formalized documents.
			If EDParameters.EDFScheduleVersion = Enums.Exchange1CRegulationsVersion.Version20
				AND (EDParameters.EDKind = Enums.EDKinds.TORG12Customer
				OR EDParameters.EDKind = Enums.EDKinds.ActCustomer
				OR EDParameters.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient) Then
				
				Return "";
			EndIf;

			If Not (EDParameters.VersionPointTypeED = Enums.EDVersionElementTypes.EISDC
				OR EDParameters.VersionPointTypeED = Enums.EDVersionElementTypes.EIRDC
				OR EDParameters.VersionPointTypeED = Enums.EDVersionElementTypes.ESF
				OR EDParameters.VersionPointTypeED = Enums.EDVersionElementTypes.SDANAREIC
				OR EDParameters.VersionPointTypeED = Enums.EDVersionElementTypes.NAEIC
				OR EDParameters.VersionPointTypeED = Enums.EDVersionElementTypes.PrimaryED) Then
				
				MessagePattern = NStr("en='Notification of receipt generation is not provided for ED type %1.';ru='Для типа ЭД %1 не предусмотрено формирование Извещения о получении.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
					EDParameters.VersionPointTypeED);
				CommonUseClientServer.MessageToUser(MessageText);
				Return "";
			EndIf;
		EndIf;
		
		AddressInTemporaryStorage = "";
		
		EDStructure = ElectronicDocumentsInternal.GenerateServiceDocumentFileByED(LinkToED, EDKind, CorrectionText);
		If Not ValueIsFilled(EDStructure)
			OR Not EDStructure.Property("AddressInTemporaryStorage", AddressInTemporaryStorage) Then
			
			Return "";
		EndIf;
		FileCreationDate = CurrentSessionDate();
		Try
			BeginTransaction();
			AddedFile = AttachedFiles.AddFile(
														EDParameters.FileOwner,
														EDStructure.FileID,
														"xml",
														FileCreationDate,
														ToUniversalTime(CurrentSessionDate()),
														AddressInTemporaryStorage,
														Undefined,
														,
														Catalogs.EDAttachedFiles.GetRef());
			
			ParametersStructure = New Structure;
			ParametersStructure.Insert("EDDirection",               Enums.EDDirections.Outgoing);
			ParametersStructure.Insert("EDStatus",                    Enums.EDStatuses.Approved);
			ParametersStructure.Insert("EDKind",                       EDStructure.EDKind);
			ParametersStructure.Insert("Recipient",                  EDStructure.RecipientID);
			ParametersStructure.Insert("Sender",                 EDStructure.SenderId);
			ParametersStructure.Insert("EDNumber",                     EDParameters.EDNumber);
			ParametersStructure.Insert("Company",                 EDStructure.Sender);
			ParametersStructure.Insert("Counterparty",                  EDStructure.Recipient);
			ParametersStructure.Insert("EDFProfileSettings",          EDParameters.EDFProfileSettings);
			ParametersStructure.Insert("EDAgreement",                EDParameters.EDAgreement);
			ParametersStructure.Insert("EDOwner",                  EDParameters.FileOwner);
			ParametersStructure.Insert("UniqueId",                EDParameters.UniqueId);
			ParametersStructure.Insert("FileDescription",           EDStructure.FileID);
			If IsNotification Then
				VersionPointTypeED = ElectronicDocumentsInternal.DetermineEDTypeByOwnerEDType(LinkToED);
			ElsIf EDKind = Enums.EDKinds.CancellationOffer Then
				VersionPointTypeED = Enums.EDVersionElementTypes.ATA;
			Else
				VersionPointTypeED = Enums.EDVersionElementTypes.NAC;
			EndIf;
			ParametersStructure.Insert("VersionPointTypeED",         VersionPointTypeED);
			ParametersStructure.Insert("SenderDocumentDate",    FileCreationDate);
			ParametersStructure.Insert("ElectronicDocumentOwner", LinkToED);
			ParametersStructure.Insert("EDFScheduleVersion",         LinkToED.EDFScheduleVersion);
			
			ElectronicDocumentsService.ChangeByRefAttachedFile(AddedFile, ParametersStructure);
			
			If Not IsNotification Then
				If EDKind = Enums.EDKinds.NotificationAboutClarification Then
					NewEDStatus = Enums.EDStatuses.Rejected;
					Query = New Query;
					Query.Text =
						"SELECT
						|	EDSubordinate.Ref
						|FROM
						|	Catalog.EDAttachedFiles AS EDSubordinate
						|		LEFT JOIN Catalog.EDAttachedFiles AS EDAttachedFiles
						|		ON EDAttachedFiles.Ref = EDSubordinate.ElectronicDocumentOwner
						|WHERE
						|	EDSubordinate.VersionPointTypeED = VALUE(Enum.EDVersionElementTypes.PrimaryED)
						|	AND EDSubordinate.EDStatus <> VALUE(Enum.EDStatuses.Rejected)
						|	AND EDAttachedFiles.Ref = &Ref";
					Query.SetParameter("Ref", LinkToED);
					Result = Query.Execute();
					Selection = Result.Select();
					While Selection.Next() Do
						EDObject = Selection.Ref.GetObject();
						EDObject.EDStatus = NewEDStatus;
						EDObject.Write();
					EndDo;
				Else
					NewEDStatus = Enums.EDStatuses.CancellationOfferCreated;
				EndIf;
				
				ParametersStructure = New Structure("EDStatus, RejectionReason", NewEDStatus, CorrectionText);
				ElectronicDocumentsService.ChangeByRefAttachedFile(LinkToED, ParametersStructure, False);
			EndIf;
			CommitTransaction();
			ReturnArray.Add(AddedFile);
		Except
			RollbackTransaction();
		EndTry;
	EndDo;
	
	Return ReturnArray;
	
EndFunction

// Determines encryption flag and electronic documents pack status.
//
// Parameters:
// RefsToDocumentsArray - array of references to electronic documents pack which parameters should be determined.
//
Function DefineUnpackingParameters(Val RefsToDocumentsArray) Export
	
	SetPrivilegedMode(True);
	
	ReturnArray = New Array;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDPackage.Ref AS DocumentRef,
	|	EDPackage.EDFSetup.CompanyCertificateForDetails AS CompanyCertificateForDetails,
	|	EDAttachedFiles.Ref,
	|	EDPackage.PackageStatus,
	|	EDPackage.EDExchangeMethod
	|FROM
	|	Document.EDPackage AS EDPackage
	|		LEFT JOIN Catalog.EDAttachedFiles AS EDAttachedFiles
	|		ON (EDAttachedFiles.FileOwner = EDPackage.Ref)
	|WHERE
	|	EDPackage.Ref IN(&RefArray)";
	
	Query.SetParameter("RefArray", RefsToDocumentsArray);
	
	SelectionPackages = Query.Execute().Select();
	
	While SelectionPackages.Next() Do
		
		If Not ValueIsFilled(SelectionPackages.Ref) Then
			Continue;
		EndIf;
		
		If SelectionPackages.PackageStatus <> Enums.EDPackagesStatuses.ToUnpacking Then
			
			MessagePattern = NStr("en = '%1 pack status differs from ""For unpacking"" value.");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, SelectionPackages.Ref);
			CommonUseClientServer.MessageToUser(MessageText);
			Continue;
		EndIf;
		
		If SelectionPackages.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource Then
			UnpackingStructure = New Structure;
			UnpackingStructure.Insert("EDPackage", SelectionPackages.DocumentRef);
			UnpackingStructure.Insert("EDExchangeMethod", SelectionPackages.EDExchangeMethod);
			ReturnArray.Add(UnpackingStructure);
			Continue;
		EndIf;
		
		
		DataParameters = ElectronicDocumentsService.GetFileData(SelectionPackages.Ref);
		FileBinaryData = GetFromTempStorage(DataParameters.FileBinaryDataRef);
		FileOfArchive = ElectronicDocumentsService.TemporaryFileCurrentName("zip");
		
		FileBinaryData.Write(FileOfArchive);
		
		ZIPReading = New ZipFileReader(FileOfArchive);
		FolderForUnpacking = ElectronicDocumentsService.WorkingDirectory("Ext",
																		  SelectionPackages.Ref.UUID());
		
		Try
			ZipReading.ExtractAll(FolderForUnpacking, ZIPRestoreFilePathsMode.DontRestore);
			DeleteFiles(FileOfArchive);
		Except
			ErrorText = BriefErrorDescription(ErrorInfo());
			If Not ElectronicDocumentsService.PossibleToExtractFiles(ZipReading, FolderForUnpacking) Then
				MessageText = ElectronicDocumentsReUse.GetMessageAboutError("006");
			EndIf;
			ProcessExceptionByEDOnServer(NStr("en='ED package Unpacking';ru='распаковка пакета ЭД'"), ErrorText, MessageText);
			DeleteFiles(FolderForUnpacking);
			DeleteFiles(FileOfArchive);
			Break;
		EndTry;

		ArchiveFiles = FindFiles(FolderForUnpacking, "*");
		InformationFile = Undefined;
		CardFile   = Undefined;
		Encrypted     = False;
		
		For Each CurFile IN ArchiveFiles Do
			If Find(CurFile.Name, "packageDescription") > 0 Then
				InformationFile = CurFile;
				Break;
			ElsIf Find(CurFile.Name, "card") > 0 Then
				CardFile = CurFile;
				Break;
			EndIf;
		EndDo;
		
		UnpackingStructure = New Structure;
		UnpackingStructure.Insert("EDPackage", SelectionPackages.DocumentRef);
		
		If InformationFile <> Undefined Then
			
			XMLReader = New XMLReader;
			XMLReader.OpenFile(InformationFile.FullName);
			FoundEncryption = False;
			Document = Undefined;
			Certificate = "";
			While XMLReader.Read() Do
				If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.LocalName = "EncriptionSettings" Then
					FoundEncryption = True;
				EndIf;
				
				If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.LocalName = "EncryptionDocument" Then
					XMLReader.Read();
					Document = XMLReader.Value;
				EndIf;
				
				If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.LocalName = "Encrypted" Then
					XMLReader.Read();
					Encrypted = Boolean(XMLReader.Value);
					Certificate = SelectionPackages.CompanyCertificateForDetails;
				EndIf;
				
				If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.LocalName = "EncryptionCertificate" Then
					XMLReader.Read();
					Certificate = XMLReader.Value;
				EndIf;
				
				If XMLReader.NodeType = XMLNodeType.EndElement AND XMLReader.LocalName = "EncryptionDocument" Then
					
					If Encrypted Then
						EncryptionStructure = New Structure;
						EncryptionStructure.Insert("PackageFormatVersion", Enums.EDPackageFormatVersions.Version10);
						
						If ValueIsFilled(SelectionPackages.CompanyCertificateForDetails) Then
							EncryptionStructure.Insert("Certificate", SelectionPackages.CompanyCertificateForDetails);
							EncryptionStructure.Insert(
								"CertificateParameters", CertificateAttributes(SelectionPackages.CompanyCertificateForDetails));
						Else
							MessagePattern = NStr("en='Decryption certificate is not specified for: %1.';ru='Не указан сертификат расшифровки для: %1.'");
							MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, SelectionPackages.Ref);
							Continue;
						EndIf;
						
						UnpackingStructure.Insert("EncryptionStructure", EncryptionStructure);
					EndIf;
					
					Document = Undefined;
					Encrypted = False;
					Certificate = "";
				EndIf;
				
				If XMLReader.NodeType = XMLNodeType.EndElement AND XMLReader.LocalName = "EncriptionSettings" Then
					Continue;
				EndIf;
				
			EndDo;
			XMLReader.Close();
		EndIf;
		
		If CardFile <> Undefined Then
			
			XMLObject = New XMLReader;
			
			Try
				XMLObject.OpenFile(CardFile.FullName);
				ED = XDTOFactory.ReadXML(XMLObject);
				XMLObject.Close();
				
				If ED.Properties().Get("Description") <> Undefined
					AND ED.Description <> Undefined
					AND ED.Description.Properties().Get("AdditionalInformation") <> Undefined
					AND ED.Description.AdditionalInformation <> Undefined
					AND ED.Description.AdditionalInformation.Properties().Get("AdditionalParameter") <> Undefined
					AND ED.Description.AdditionalInformation.AdditionalParameter <> Undefined Then
					
					If TypeOf(ED.Description.AdditionalInformation.AdditionalParameter) = Type("XDTOList") Then
						For Each Property IN ED.Description.AdditionalInformation.AdditionalParameter Do
							If Property.Name = "Encrypted" Then
								Encrypted = Boolean(Property.Value);
								Break;
							EndIf;
						EndDo;
						
					ElsIf TypeOf(ED.Description.AdditionalInformation.AdditionalParameter) = Type("XDTODataObject") Then
						If ED.Description.AdditionalInformation.AdditionalParameter.Name = "Encrypted" Then
							Encrypted = Boolean(ED.Description.AdditionalInformation.AdditionalParameter.Value);
						EndIf;
					EndIf;
					
					If Encrypted Then
						
						EncryptionStructure = New Structure;
						EncryptionStructure.Insert("PackageFormatVersion", Enums.EDPackageFormatVersions.Version20);
						
						If ValueIsFilled(SelectionPackages.CompanyCertificateForDetails) Then
							EncryptionStructure.Insert("Certificate", SelectionPackages.CompanyCertificateForDetails);
							EncryptionStructure.Insert("CertificateParameters", CertificateAttributes(
							SelectionPackages.CompanyCertificateForDetails));
						Else
							MessagePattern = NStr("en='Decryption certificate is not specified for: %1.';ru='Не указан сертификат расшифровки для: %1.'");
							MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, SelectionPackages.Ref);
							DeleteFiles(FolderForUnpacking);
							Continue;
						EndIf;
						
						UnpackingStructure.Insert("EncryptionStructure", EncryptionStructure);
					EndIf;
					
				EndIf;
			Except
				XMLObject.Close();
				
				MessagePattern = NStr("en='An error occurred when reading the data from file %1: %2 (see details in Event log).';ru='Возникла ошибка при чтении данных из файла %1: %2 (подробности см. в Журнале регистрации).'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
					CardFile.FullName, BriefErrorDescription(ErrorInfo()));
					ProcessExceptionByEDOnServer(NStr("en='ED reading.';ru='Чтение ЭД.'"), DetailErrorDescription(ErrorInfo()),
						MessageText);
			EndTry;
		EndIf;
		
		DeleteFiles(FolderForUnpacking);
		
		ReturnArray.Add(UnpackingStructure);
	EndDo;
	
	Return ReturnArray;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Direct exchange with bank

Function StatementQueryCMLXDTO(StartDate, EndDate, BankAccountsArray, Bank)
	
	Try
		URI = "urn:1C.ru:ClientBankExchange";
		
		Package = XDTOFactory.Create(XDTOFactory.Type(URI,"ClientBankExchange"));
		Package.FormatVersion = "1.06";
		Package.Recipient = Bank.Description;
		Package.Sender = "1C: Enterprise";
		Package.CreationDate = CurrentSessionDate();
		Package.CreationTime = CurrentSessionDate();
		
		FilterConditions = XDTOFactory.Create(XDTOFactory.Type(URI,"FilterConditions"));
		FilterConditions.StartDate = StartDate;
		FilterConditions.EndDate = EndDate;
		For Each AccountNo IN BankAccountsArray Do
			FilterConditions.BankAcc.Add(AccountNo);
		EndDo;
		
		Package.FilterConditions = FilterConditions;
		
		Package.Validate();
		
	Except
		MessagePattern = NStr("en='%1 (for more information, see Event log).';ru='%1 (подробности см. в Журнале регистрации).'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
			BriefErrorDescription(ErrorInfo()));
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='ED generation';ru='Формирование ЭД'"),
			DetailErrorDescription(ErrorInfo()), MessageText, 1);
		
		Return Undefined;
	EndTry;
	
	Return Package;
	
EndFunction

Function StatementQueriesArray(EDAgreement, Company, Bank, StartDate, EndDate, BankAccountsArray)
	
	Responsible = ElectronicDocumentsOverridable.GetResponsibleByED(Bank, EDAgreement);
	
	XDTOPackage = StatementQueryCMLXDTO(StartDate, EndDate, BankAccountsArray, Bank);
		
	If XDTOPackage=Undefined Then
		Return Undefined
	EndIf;
	
	FullFileName = GetTempFileName("xml");
	Record = New XMLWriter;
	Record.OpenFile(FullFileName);
	Record.WriteXMLDeclaration();

	XDTOFactory.WriteXML(
		Record, XDTOPackage, "ClientBankExchange", "urn:1C.ru:ClientBankExchange", , XMLTypeAssignment.Explicit);
	
	Record.Close();
	
	BinaryData = New BinaryData(FullFileName);
	DeleteFiles(FullFileName);
	FileURL = PutToTempStorage(BinaryData);
	
	MessagePattern = NStr("en='Statement request from %1 to %2';ru='Запрос выписки с %1 по %2'");
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		MessagePattern, Format(StartDate, "DLF=D"), Format(EndDate, "DLF=D"));
		
	FileName = StringFunctionsClientServer.StringInLatin(MessageText);
	
	ED = AttachedFiles.AddFile(EDAgreement, MessageText, "xml", CurrentSessionDate(), CurrentSessionDate(),
											FileURL, , , Catalogs.EDAttachedFiles.GetRef());

	ParametersStructure = New Structure();
	ParametersStructure.Insert("Author", Users.AuthorizedUser());
	ParametersStructure.Insert("EDDirection", Enums.EDDirections.Outgoing);
	ParametersStructure.Insert("EDKind", Enums.EDKinds.QueryStatement);
	ParametersStructure.Insert("EDStatus", Enums.EDStatuses.Created);
	ParametersStructure.Insert("Responsible", Responsible);
	ParametersStructure.Insert("Company", Company);
	ParametersStructure.Insert("Counterparty", Bank);
	ParametersStructure.Insert("EDOwner", EDAgreement);
	ParametersStructure.Insert("EDAgreement", EDAgreement);
	ParametersStructure.Insert("SenderDocumentDate", CurrentSessionDate());
	ParametersStructure.Insert("FileDescription", FileName);
	ParametersStructure.Insert("VersionPointTypeED", Enums.EDVersionElementTypes.PrimaryED);
	
	ChangeByRefAttachedFile(ED, ParametersStructure);
	
	ReturnArray = New Array;
	ReturnArray.Add(ED);
	
	Return ReturnArray;
	
EndFunction

Function StatementQueriesArrayAsync(EDAgreement, Company, Bank, CompanyID, StartDate, EndDate, BankAccountsArray)
	
	Responsible = ElectronicDocumentsOverridable.GetResponsibleByED(Bank, EDAgreement);
	EDKindsArray = New Array;
		
	AttributeCompanyName = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
																		"ShortDescriptionOfTheCompany");
	If Not ValueIsFilled(AttributeCompanyName) Then
		AttributeCompanyName = "Description";
	EndIf;
	SenderName = CommonUse.GetAttributeValue(Company, AttributeCompanyName);
	CompanyAttributes = CommonUse.ObjectAttributesValues(Company, "TIN");
	BankingDetails = CommonUse.ObjectAttributesValues(Bank, "Code, description");
	TargetNamespace = ElectronicDocumentsService.AsynchronousExchangeWithBanksNamespace();
	
	For Each AccountNo IN BankAccountsArray Do
	
		ErrorText = "";
		Try
			
			UnIdED = New UUID;
			
			ED = ElectronicDocumentsInternal.GetCMLObjectType("StatementRequest", TargetNamespace);
			ElectronicDocumentsInternal.FillXDTOProperty(ED, "id", String(UnIdED), True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(ED, "formatVersion", 
				ElectronicDocumentsService.AsynchronousExchangeWithBanksSchemeVersion(), True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(ED, "creationDate", CurrentSessionDate(), True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(ED, "userAgent", 
				ElectronicDocumentsReUse.ClientApplicationVersionForBank(), , ErrorText);
			
			Sender = ElectronicDocumentsInternal.GetCMLObjectType("CustomerPartyType", TargetNamespace);
			ElectronicDocumentsInternal.FillXDTOProperty(Sender, "id", CompanyID, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(Sender, "name", SenderName, , ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(Sender, "tin", CompanyAttributes.TIN, , ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(ED, "Sender", Sender, True, ErrorText);
			
			Recipient = ElectronicDocumentsInternal.GetCMLObjectType("BankPartyType", TargetNamespace);
			ElectronicDocumentsInternal.FillXDTOProperty(Recipient, "bic", BankingDetails.Code, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(Recipient, "name", BankingDetails.Description, , ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(ED, "Recipient", Recipient, True, ErrorText);
			
			QueryData = ElectronicDocumentsInternal.GetCMLObjectType("StatementRequest.Data", TargetNamespace);
			ElectronicDocumentsInternal.FillXDTOProperty(QueryData, "StatementType", "0", True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(QueryData, "DateFrom", StartDate, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(QueryData, "DateTo", EndDate, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(QueryData, "Account", AccountNo, True, ErrorText);
			
			BankOfAccount = ElectronicDocumentsInternal.GetCMLObjectType("BankType", TargetNamespace);
			ElectronicDocumentsInternal.FillXDTOProperty(BankOfAccount, "BIC", BankingDetails.Code, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(BankOfAccount, "Name", BankingDetails.Description, , ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(QueryData, "Bank", BankOfAccount, True, ErrorText);
			
			ElectronicDocumentsInternal.FillXDTOProperty(ED, "Data", QueryData, True, ErrorText);
			
			ED.Validate();
		
			If ValueIsFilled(ErrorText) Then
				CommonUseClientServer.MessageToUser(ErrorText);
				FileIsFormed = False;
			Else
				TempFile = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
				ElectronicDocumentsInternal.ExportEDtoFile(ED, TempFile, False, "UTF-8");
				FileIsFormed = True;
			EndIf;

		Except
			BriefErrorDescription = BriefErrorDescription(ErrorInfo());
			MessagePattern = NStr("en='%1 (for more information, see Event log).';ru='%1 (подробности см. в Журнале регистрации).'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
										MessagePattern, BriefErrorDescription);
			Operation = NStr("en='ED generation';ru='Формирование ЭД'");
			DetailErrorDescription = DetailErrorDescription(ErrorInfo());
			ProcessExceptionByEDOnServer(Operation, DetailErrorDescription, MessageText, 1);
			FileIsFormed = False;
		EndTry;
		
		If Not FileIsFormed Then
			Continue;
		EndIf;
		
		BinaryData = New BinaryData(TempFile);
		DeleteFiles(TempFile);
		FileURL = PutToTempStorage(BinaryData);
		
		MessagePattern = NStr("en='Statement request from %1 to %2';ru='Запрос выписки с %1 по %2'");
	
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			MessagePattern, Format(StartDate, "DLF=D"), Format(EndDate, "DLF=D"));
	
		ED = AttachedFiles.AddFile(EDAgreement, MessageText, "xml", CurrentSessionDate(), CurrentSessionDate(),
												FileURL, , , Catalogs.EDAttachedFiles.GetRef(UnIdED));

		FileName = StringFunctionsClientServer.StringInLatin(MessageText);
		ParametersStructure = New Structure();
		ParametersStructure.Insert("Author", Users.AuthorizedUser());
		ParametersStructure.Insert("EDDirection", Enums.EDDirections.Outgoing);
		ParametersStructure.Insert("EDKind", Enums.EDKinds.QueryStatement);
		If CommonUse.ObjectAttributeValue(EDAgreement, "CryptographyIsUsed") Then
			ParametersStructure.Insert("EDStatus", Enums.EDStatuses.Created);
		Else
			ParametersStructure.Insert("EDStatus", Enums.EDStatuses.PreparedToSending);
		EndIf;
		ParametersStructure.Insert("Responsible", Responsible);
		ParametersStructure.Insert("Company", Company);
		ParametersStructure.Insert("Counterparty", Bank);
		ParametersStructure.Insert("EDOwner", EDAgreement);
		ParametersStructure.Insert("EDAgreement", EDAgreement);
		ParametersStructure.Insert("SenderDocumentDate", CurrentSessionDate());
		ParametersStructure.Insert("FileDescription", FileName);
		ParametersStructure.Insert("VersionPointTypeED", Enums.EDVersionElementTypes.PrimaryED);
	
		ChangeByRefAttachedFile(ED, ParametersStructure);
		EDKindsArray.Add(ED);
	EndDo;
	
	Return EDKindsArray;
	
EndFunction

Function SignaturesData(ObjectReference)
	
	ReturnArray = New Array;
	
	QueryText = "SELECT ALLOWED
	               |	DigitalSignatures.Signature AS Signature,
	               |	DigitalSignatures.Certificate
	               |FROM
	               |	Catalog.EDAttachedFiles.DigitalSignatures AS DigitalSignatures
	               |WHERE
	               |	DigitalSignatures.Ref = &ObjectReference";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.Parameters.Insert("ObjectReference", ObjectReference);
	
	QuerySelection = Query.Execute().Select();
	
	While QuerySelection.Next() Do
		BinaryData = QuerySelection.Signature.Get();
		SignatureAddress = PutToTempStorage(BinaryData, New UUID);
		CertificateData = QuerySelection.Certificate.Get();
		ReturnStructure = New Structure("SignatureAddress, Certificate", SignatureAddress, CertificateData);
		ReturnArray.Add(ReturnStructure);
	EndDo;
	
	Return ReturnArray;
	
EndFunction

Function SendGeneratedEDToBank(EDAgreement, AuthorizationParameters = Undefined)

	Result = 0;
	ReadyToBeSentPackages = PreparedEDToBeSentToBank(EDAgreement);
	If ValueIsFilled(ReadyToBeSentPackages) Then
		Result = EDPackagesSending(ReadyToBeSentPackages, AuthorizationParameters);
	EndIf;
	
	Return Result;
	
EndFunction

Function PreparedEDToBeSentToBank(EDFSetup)
	
	PreparedEDQuery = New Query;
	PreparedEDQuery.Text =
	"SELECT ALLOWED
	|	EDPackage.Ref AS Ref
	|FROM
	|	Document.EDPackage AS EDPackage
	|WHERE
	|	Not EDPackage.DeletionMark
	|	AND EDPackage.PackageStatus = VALUE(Enum.EDPackagesStatuses.PreparedToSending)
	|	AND EDPackage.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughBankWebSource)
	|	AND EDPackage.EDFSetup = &EDFSetup";
	PreparedEDQuery.SetParameter("PackageStatus", Enums.EDPackagesStatuses.PreparedToSending);
	PreparedEDQuery.SetParameter("EDFSetup", EDFSetup);
	
	SubsystemSberbankOnline = "ElectronicInteraction.ElectronicDocuments.ExchangeWithBanks.SberbankOnline";
	
	If CommonUseClientServer.SubsystemExists(SubsystemSberbankOnline) Then
		PreparedEDQuery.Text = PreparedEDQuery.Text + "
				|				AND NOT(EDPack.EDFSetting.EDExchangeMethod = VALUE(Enumeration.EDExchangeMethods.ViaBankWebResource) AND EDPack.EDFSetting.BankApplication = VALUE(Enumeration.BankApplications.SberbankOnline))";
	EndIf;
	
	Result = PreparedEDQuery.Execute().Unload().UnloadColumn("Ref");
	
	Return Result;
	
EndFunction

Procedure ProcessBankResponseOnSendingDocumentAsync(BankResponse, ED, EDPackage)
	
	SetEDStatus(ED, Enums.EDStatuses.Sent);
	FileContent = New Map;
	Read = New XMLReader;
	URI = ElectronicDocumentsService.AsynchronousExchangeWithBanksNamespace();
	
	Read.SetString(BankResponse);
	ResultBank = XDTOFactory.ReadXML(Read, XDTOFactory.Type(URI, "ResultBank"));
	ResultBank.Validate();
	If Not ResultBank.Success = Undefined Then
		If Not ResultBank.Success.SendPacketResponse = Undefined Then
			PackageObject = EDPackage.GetObject();
			PackageObject.ExternalUID = ResultBank.Success.SendPacketResponse.ID;
			PackageObject.Write();
			Return;
		EndIf
	ElsIf Not ResultBank.Error = Undefined AND Not ResultBank.Error.Code = "9999" Then
		ErrorText = BankResponseErrorMessageText(ResultBank.Error);
		Raise ErrorText;
	EndIf;
	
EndProcedure

Function IncomingEDBankData(EDAgreement, FileName)
	
	SetPrivilegedMode(True);
	EDFSettingAttributes = CommonUse.ObjectAttributesValues(EDAgreement, "Company, Counterparty");
	
	ParametersStructure = Undefined;
	TargetNamespace = ElectronicDocumentsService.AsynchronousExchangeWithBanksNamespace();
	
	XMLObject = New XMLReader;
	
	Try
		XMLObject.OpenFile(FileName);
		ResultBank = ElectronicDocumentsInternal.GetCMLValueType("ResultBank", TargetNamespace);
		
		ResultBank = XDTOFactory.ReadXML(XMLObject, ResultBank);
		ResultBank.Validate();
		XMLObject.Close();
		
		If Not ResultBank.Error = Undefined Then
			ErrorText = BankResponseErrorMessageText(ResultBank.Error);
			ErrorData = New Structure;
			ErrorData.Insert("IsError", True);
			ErrorData.Insert("MessageText", ErrorText);
			ParametersStructure = New Structure;
			ParametersStructure.Insert("ErrorData", ErrorData);
			Return ParametersStructure;
		EndIf;
		
		If Not ResultBank.Success.GetPacketResponse = Undefined Then
			ParametersStructure = New Structure;
			ParametersStructure.Insert("Recipient",          ResultBank.Success.GetPacketResponse.Recipient.Customer.name);
			ParametersStructure.Insert("Sender",         ResultBank.Success.GetPacketResponse.Sender.Bank.name);
			ParametersStructure.Insert("Company",         EDFSettingAttributes.Company);
			ParametersStructure.Insert("Counterparty",          EDFSettingAttributes.Counterparty);
			ParametersStructure.Insert("EDFSetup",        EDAgreement);
			ParametersStructure.Insert("SenderAddress",    Undefined);
			ParametersStructure.Insert("RecipientAddress",     Undefined);
			ParametersStructure.Insert("Encrypted",          False);
			ParametersStructure.Insert("CompanyCertificateForDetails", Undefined);
			ParametersStructure.Insert("PackageFormatVersion", Enums.EDPackageFormatVersions.EmptyRef());
			ParametersStructure.Insert("ExternalUID",          ResultBank.Success.GetPacketResponse.id);
			ParametersStructure.Insert("PackageStatus",        Enums.EDPackagesStatuses.ToUnpacking);
			ParametersStructure.Insert("EDDirections",       Enums.EDDirections.Incoming);
			ParametersStructure.Insert("EDExchangeMethod",      Enums.EDExchangeMethods.ThroughBankWebSource);
			TempFile = GetTempFileName("xml");
			ElectronicDocumentsInternal.ExportEDtoFile(ResultBank, TempFile, False, "utf-8");
			ParametersStructure.Insert("PackageFileName",      TempFile);
		EndIf;
	Except
		If Users.InfobaseUserWithFullAccess( , , False) Then
			MessagePattern = NStr("en='An error occurred when reading the data from file %1: %2 (see details in Event log).';ru='Возникла ошибка при чтении данных из файла %1: %2 (подробности см. в Журнале регистрации).'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
				FileName, BriefErrorDescription(ErrorInfo()));
		EndIf;
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		OperationKind = NStr("en='ED reading.';ru='Чтение ЭД.'");
		ProcessExceptionByEDOnServer(OperationKind, DetailErrorDescription, MessageText);
	EndTry;
	
	Return ParametersStructure;
	
EndFunction

Function BankResponseErrorMessageText(Error)
	
	ErrorTemplate = NStr("en='An error is received from bank (%1). Error code %2.
		|%3: %4';ru='Получена ошибка из банка (%1). Код ошибки %2.
		|%3: %4'");
	Date = Format(CurrentSessionDate(), "DLF=DT");
	ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
		ErrorTemplate, Date, Error.Code, Error.Description, Error.MoreInfo);
	
	Return ErrorText;
	
EndFunction

Function FindEDPack(EDFSetup, ExternalUID)
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	               |	EDPackage.Ref
	               |FROM
	               |	Document.EDPackage AS EDPackage
	               |WHERE
	               |	EDPackage.EDFSetup = &EDFSetup
	               |	AND EDPackage.ExternalUID = &ExternalUID
	               |	AND EDPackage.Direction = VALUE(Enum.EDDirections.Outgoing)";
	Query.SetParameter("EDFSetup", EDFSetup);
	Query.SetParameter("ExternalUID", ExternalUID);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Ref;
	EndIf
	
EndFunction

Function DataForSendingToBank(Refs, BankApplication)
	
	ReturnData = New Map;
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	EDPackage.Ref,
	|	EDPackage.EDFSetup AS EDAgreement
	|INTO packages
	|FROM
	|	Document.EDPackage AS EDPackage
	|WHERE
	|	Not EDPackage.EDFSetup.DeletionMark
	|	AND EDPackage.EDFSetup.AgreementStatus = VALUE(Enum.EDAgreementsStatuses.Acts)
	|	AND EDPackage.EDFSetup.BankApplication = &BankApplication
	|	AND Not EDPackage.DeletionMark
	|	AND EDPackage.PackageStatus = VALUE(Enum.EDPackagesStatuses.PreparedToSending)
	|	AND TRUE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EDPackage.Ref,
	|	EDPackage.ElectronicDocuments.(
	|		ElectronicDocument,
	|		ElectronicDocument.EDKind
	|	),
	|	EDPackage.EDFSetup AS EDAgreement
	|FROM
	|	Document.EDPackage AS EDPackage
	|WHERE
	|	EDPackage.Ref In
	|			(SELECT DISTINCT
	|				packages.Ref
	|			FROM
	|				packages)
	|TOTALS BY
	|	EDAgreement
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	CompanySignatureCertificates.Certificate,
	|	CompanySignatureCertificates.Ref AS EDAgreement
	|INTO Certificates
	|FROM
	|	Catalog.EDUsageAgreements.CompanySignatureCertificates AS CompanySignatureCertificates
	|WHERE
	|	CompanySignatureCertificates.Ref In
	|			(SELECT DISTINCT
	|				packages.EDAgreement
	|			FROM
	|				packages)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ESCertificates.Ref,
	|	ESCertificates.CertificateData AS CertificateData,
	|	FALSE AS RememberCertificatePassword,
	|	FALSE AS PasswordReceived,
	|	UNDEFINED AS UserPassword,
	|	Certificates.EDAgreement AS EDAgreement
	|FROM
	|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS ESCertificates
	|		LEFT JOIN Certificates AS Certificates
	|		ON Certificates.Certificate = ESCertificates.Ref
	|WHERE
	|	(ESCertificates.User = &EmptyUser
	|			OR ESCertificates.User = &CurrentUser)
	|	AND ESCertificates.Ref In
	|			(SELECT
	|				Certificates.Certificate
	|			FROM
	|				Certificates)
	|TOTALS BY
	|	EDAgreement";
	If TypeOf(Refs) = Type("CatalogRef.EDUsageAgreements") Then
		Query.Text = StrReplace(Query.Text, "AND TRUE", "And EDPack.EDFSetting = &EDFSetting");
		Query.SetParameter("EDFSetup", Refs);
	Else
		Query.Text = StrReplace(Query.Text, "AND TRUE", "And EDPack.Ref IN (&EDPacks)");
		Query.SetParameter("EDPackages", Refs);
	EndIf;
	Query.SetParameter("BankApplication", BankApplication);
	Query.SetParameter("EmptyUser", Catalogs.Users.EmptyRef());
	Query.SetParameter("CurrentUser", Users.CurrentUser());
	QueryBatch = Query.ExecuteBatch();
	AgreementSelection = QueryBatch[1].Select(QueryResultIteration.ByGroups);
	SelectionOfCertificates = QueryBatch[3].Select(QueryResultIteration.ByGroups);
	TempFile = GetTempFileName();
	While AgreementSelection.Next() Do
		SelectionPackages = AgreementSelection.Select();
		PacksData = New Map;
		While SelectionPackages.Next() Do
			SelectionED = SelectionPackages.ElectronicDocuments.Select();
			DataStructure = New Structure;
			While SelectionED.Next() Do
				EDData = ElectronicDocumentsService.GetFileData(SelectionED.ElectronicDocument, New UUID);
				If SelectionED.ElectronicDocumentEDKind = Enums.EDKinds.PaymentOrder Then
					BinaryData = GetFromTempStorage(EDData.FileBinaryDataRef);
					BinaryData.Write(TempFile);
					TextDocument = New TextDocument;
					TextDocument.Read(TempFile);
					XMLString = TextDocument.GetText();
					DataStructure.Insert("PaymentOrder", XMLString);
					DataStructure.Insert("Key",               SelectionED.ElectronicDocument.UUID());
					Signatures = SignaturesData(SelectionED.ElectronicDocument);
					SignaturesArray = New Array;
					For Each SignatureData IN Signatures Do
						SignatureDataStructure = New Structure;
						SignatureDataStructure.Insert("SignatureAddress", SignatureData.SignatureAddress);
						SignatureDataStructure.Insert("Certificate",   SignatureData.Certificate);
						SignaturesArray.Add(SignatureDataStructure);
					EndDo;
					DataStructure.Insert("Signatures", SignaturesArray);
				ElsIf SelectionED.ElectronicDocumentEDKind = Enums.EDKinds.AddData Then
					DataStructure.Insert("ServiceData", EDData.FileBinaryDataRef);
				EndIf;
			EndDo;
			PacksData.Insert(SelectionPackages.Ref, DataStructure);
		EndDo;
		SelectionOfCertificates.Reset();
		SearchStructure = New Structure("EDAgreement", AgreementSelection.EDAgreement);
		If SelectionOfCertificates.FindNext(SearchStructure) Then
			CertificatesDataSelection = SelectionOfCertificates.Select();
			Certificates = New Array;
			While CertificatesDataSelection.Next() Do
				CertificateData = New Structure();
				CertificateData.Insert("CertificatRef",            CertificatesDataSelection.Ref);
				CertificateData.Insert("UserPassword",          CertificatesDataSelection.UserPassword);
				CertificateData.Insert("CertificateBinaryData",   CertificatesDataSelection.CertificateData.Get());
				CertificateData.Insert("RememberCertificatePassword", CertificatesDataSelection.RememberCertificatePassword);
				Certificates.Add(CertificateData);
			EndDo;
			DataStructure = New Structure("PacksData, Certificates", PacksData, Certificates);
			ReturnData.Insert(AgreementSelection.EDAgreement, DataStructure);
		Else
			MessagePattern = NStr("en='Certificates are not specified in the agreement on using the direct exchange with the %1 bank';ru='Не указаны сертификаты в соглашении об использовании прямого обмена с банком %1'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
										MessagePattern, AgreementSelection.EDAgreement);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
	EndDo;
	
	Return ReturnData;
	
EndFunction

// For internal use only
Function IdentifiersArrayBankStatements(EDStatement)
	
	ExternalIdentifiersArray = New Array;
		
	AdditInformationAboutED = ElectronicDocumentsService.GetFileData(EDStatement);
	If AdditInformationAboutED.Property("FileBinaryDataRef")
			AND ValueIsFilled(AdditInformationAboutED.FileBinaryDataRef) Then
		
		EDData = GetFromTempStorage(AdditInformationAboutED.FileBinaryDataRef);

		FileName = GetTempFileName("xml");
				
		If FileName = Undefined Then
			ErrorText = NStr("en='Cannot read the electronic document. Check the working directory setting';ru='Не удалось прочитать электронный документ. Проверьте настройку рабочего каталога'");
			CommonUseClientServer.MessageToUser(ErrorText);
			Return ExternalIdentifiersArray;
		EndIf;
		
		EDData.Write(FileName);
		
		DataStructure = ElectronicDocumentsInternal.GenerateParseTree(FileName, Undefined);
		
		DeleteFiles(FileName);
		If DataStructure = Undefined Then
			Return ExternalIdentifiersArray;
		EndIf;
		
		ParseTree = DataStructure.ParseTree;
		ObjectString = DataStructure.ObjectString;
		
		FilterStructure = New Structure("Attribute", "BankAccountsOfTheCompany");
		BankAccountsOfTheCompany = ObjectString.Rows.FindRows(FilterStructure);
		AccountsArray = New Array;
		
		For Each StringBankAccount IN BankAccountsOfTheCompany Do
			AccountNo = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																			ParseTree,
																			StringBankAccount,
																			"BankAcc.SettlemAccount");
			AccountsArray.Add(AccountNo);
		EndDo;
		
		TSRows = ObjectString.Rows.FindRows(New Structure("Attribute", "TSRow"));
				
		For Each TSRow IN TSRows Do
			CurAccountNumber = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																						ParseTree,
																						TSRow,
																						"PayerAccount");
			
			IsOutgoingPayment = AccountsArray.Find(CurAccountNumber) <> Undefined;
			If IsOutgoingPayment Then
				IDExternal = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																							ParseTree,
																							TSRow,
																							"PaymentId");
				ExternalIdentifiersArray.Add(IDExternal);
			EndIf;
		EndDo;
	EndIf;
	
	Return ExternalIdentifiersArray;

EndFunction

#Region _SSL_AttachedFilesServiceServerCall

// Receives all file signatures.
//
// Details - see description DigitalSignature.GetAllSignatures()
//
Function GetAllSignatures(ObjectReference, UUID) Export
	
	Return ElectronicDocumentsService.GetAllSignatures(ObjectReference, UUID);
	
EndFunction

#EndRegion
