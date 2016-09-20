
////////////////////////////////////////////////////////////////////////////////
// ElectronicDocumentsServiceClient: mechanism of electronic documents exchange.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// For internal use only
Function CheckUsingUsersInternetSupport() Export
	
	Use = Undefined;
	ElectronicDocumentsClientOverridable.CheckUsingUsersInternetSupport(Use);
	If Use = Undefined Then
		Use = False;
		#If ThickClientOrdinaryApplication Then
			If Metadata.Constants.Find("UsersInternetSupportProcessorFile") <> Undefined Then
				Use = True;
			EndIf;
		#EndIf
	EndIf;
	
	Return Use;
	
EndFunction

// Opens the form for viewing an electronic document.
//
// Parameters:
//  LinkToED        - reference to electronic document opened
//  for viewing OpeningParameters - structure, additional
//  view parameters FormOwner     - Managed form
//
Procedure OpenEDForViewing(LinkToED, OpenParameters = Undefined, FormOwner = Undefined) Export
	
	If Not ValueIsFilled(LinkToED) Then
		Return;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("LinkToED", LinkToED);
	Parameters.Insert("OpenParameters", OpenParameters);
	Parameters.Insert("FormOwner", FormOwner);
	
	Notification = New NotifyDescription("AfterObtainingPrintsOpenEDForViewing", ThisObject, Parameters);
	
	DigitalSignatureClient.GetCertificatesThumbprints(Notification, True, False);

EndProcedure

Procedure GetAgreementsAndCertificatesParametersMatch(NotificationHandler, AgreementsArray = Undefined, EDKindsArray = Undefined) Export
	
	Cancel = False;
	
	CertificateStructuresArray = New Array;
	ServerAuthorizationPerform = ElectronicDocumentsServiceCallServer.ServerAuthorizationPerform();
	StCertificateStructuresArrays = New Structure;
	
	AdditionalParameters = New Structure();
	AdditionalParameters.Insert("NotificationHandler", NotificationHandler);
	AdditionalParameters.Insert("AgreementsArray", AgreementsArray);
	AdditionalParameters.Insert("EDKindsArray", EDKindsArray);
	
	If Not ServerAuthorizationPerform Then
	
		NotifyDescription = New NotifyDescription(
			"AfterObtainingCertificatesPrints", ThisObject, AdditionalParameters);
		DigitalSignatureClient.GetCertificatesThumbprints(NOTifyDescription, True);
		Return;
			
	EndIf;
	
	AfterObtainingCertificatesPrints(New Array, AdditionalParameters);
	
EndProcedure

// Displays the message to user about the lack of access rights.
Procedure MessageToUserAboutViolationOfRightOfAccess() Export
	
	ClearMessages();
	MessageText = NStr("en='Access violation';ru='Нарушение прав доступа'");
	ElectronicDocumentsClientOverridable.PrepareMessageTextAboutAccessRightsViolation(MessageText);
	CommonUseClientServer.MessageToUser(MessageText);
	
EndProcedure

// Fills in the data about the ways to get technical support for EDF.
//
//
Procedure FillDataServiceSupport(ServiceSupportPhoneNumber, ServiceSupportEmailAddress) Export

	// Contact information of CJSC "Kaluga Astral"
	ServiceSupportPhoneNumber = "8-800-333-9313";
	ServiceSupportEmailAddress = "edo@1c.ru";

EndProcedure

Procedure OpenStatement1CBuhphone() Export
	
	GotoURL("");
	
EndProcedure

#EndRegion

#Region Certificates

Procedure AfterReceivingCertificatesAddInformationAboutSignature(SignatureCertificates, Parameters) Export
	
	If SignatureCertificates.Count() <> 0 Then
		Certificate = SignatureCertificates[0];
		Parameters.Insert("ReceivedCertificate", Certificate);
		Notification = New NotifyDescription("AfterCertificateExportingAddInformationAboutSignature", ThisObject, Parameters);
		Certificate.BeginUnloading(Notification);
	EndIf
	
EndProcedure

Procedure AfterObtainingCertificatesPrints(Prints, Parameters) Export
		
	ThumbprintArray = New Array;
	If TypeOf(Prints) = Type("Map") Then
		For Each KeyValue IN Prints Do
			ThumbprintArray.Add(KeyValue.Key);
		EndDo;
	EndIf;
	
	NotificationHandler = Parameters.NotificationHandler;
	AgreementsArray = Parameters.AgreementsArray;
	EDKindsArray = Parameters.EDKindsArray;
	
	StCertificateStructuresArrays = New Structure;
	StCertificateStructuresArrays.Insert("StampArrayClient", ThumbprintArray);
	
	AccordancesSt = ElectronicDocumentsServiceCallServer.MatchesAgreementsAndAuthorizationCertificatesStructure(
		AgreementsArray, EDKindsArray, StCertificateStructuresArrays);
	
	AccordancesSt.Insert("ProfilesAndCertificatesParametersMatch", New Map);
	
	AgreementsAndCertificatesCorrespondence = Undefined;
	If AccordancesSt.Property("AuthorizationCertificatesArrayAndAgreementsMatch", AgreementsAndCertificatesCorrespondence) Then
		ID_Parameters = String(New UUID);
		ApplicationParameters.Insert("ElectronicInteraction." + ID_Parameters, AccordancesSt);
		Parameters = New Structure;
		Parameters.Insert("ID_Parameters", ID_Parameters);
		Parameters.Insert("NotificationHandler", NotificationHandler);
		Parameters.Insert("AgreementsAndCertificatesCorrespondence", AgreementsAndCertificatesCorrespondence);
		
		DecryptMarker(, Parameters);
	Else
		NotificationParameters = New Structure;
		NotificationParameters.Insert("ProfilesAndCertificatesParametersMatch",
			AccordancesSt.ProfilesAndCertificatesParametersMatch);
		
		ExecuteNotifyProcessing(NotificationHandler, NotificationParameters);
	EndIf;
	
EndProcedure

Procedure AfterCertificateExportingAddInformationAboutSignature(ExportedData, Parameters) Export
	
	Certificate = Parameters.ReceivedCertificate;
	
	PrintInString = Base64String(Certificate.Imprint);
	SubjectPresentation = DigitalSignatureClientServer.SubjectPresentation(Certificate);
	ElectronicDocumentsServiceCallServer.AddInformationAboutSignature(Parameters.ElectronicDocument,
		Parameters.SignatureData, PrintInString, CommonUseClient.SessionDate(), "", , SubjectPresentation,
		ExportedData);
	DetermineSignaturesStatuses(Parameters.ElectronicDocument);
	
EndProcedure

// Receives the password to the certificate if it is available for current user.
//
// Parameters:
//  DSCertificate       - CatalogRef.DSCertificates - DS certificate.
//  UserPassword - String - password to DS certificate received from global variable.
//
// Returns:
//  Boolean - True - if a password for DS certificate is received, otherwise - False.
//
Function CertificatePasswordReceived(DSCertificate, UserPassword, ForSessionPeriod = False) Export
	
	UserPassword = Undefined;
	CertificateAndPasswordMatching = ApplicationParameters["ElectronicInteraction.CertificateAndPasswordMatching"];
	If TypeOf(CertificateAndPasswordMatching) = Type("FixedMap") Then
		UserPassword = CertificateAndPasswordMatching.Get(DSCertificate);
		ForSessionPeriod = (UserPassword <> Undefined);
	EndIf;
	
	If UserPassword = Undefined Then
		UserPassword = ElectronicDocumentsServiceCallServer.PasswordToCertificate(DSCertificate);
	EndIf;
	
	Return (UserPassword <> Undefined);
	
EndFunction

// Opens the CheckCertificate form and returns check result.
//
// Parameters:
//  Certificate - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - certificate being checked.
//
//  CompletionProcessing  - NotifyDescription - called when closing the form.
//  ValidateAuthorization - Boolean - If True, then a test of connection with Taxcom
//                            server will be added to the certificate checks.
//  FormOwner        - ManagedForm - another form.
//  CheckOnSelection    - Boolean - if True, then the Check button
//                            will be called Check and continue and the Close button will be called Cancel.
//  WithoutConfirmation     - Boolean - If you set True, then with
//                            a password a check will be executed immediately without opening a form.
//                            If there is the CheckOnSelection mode and
//                            the ResultProcessing parameter is set, then a form will not be opened if the ChecksComplete parameter is set to True.
//
Procedure CertificateValidationSettingsTest(
					Certificate,
					CompletionProcessing = Undefined,
					ValidateAuthorization = False,
					FormOwner = Undefined,
					CheckOnSelection = False,
					WithoutConfirmation = False) Export
	
	AdditionalParameters = New Structure;
	ResultProcessing = New NotifyDescription("CertificateTestResultProcessor",
		ElectronicDocumentsServiceClient, AdditionalParameters);
	AdditionalParameters.Insert("FormOwner",       FormOwner);
	AdditionalParameters.Insert("CheckOnSelection",   CheckOnSelection);
	AdditionalParameters.Insert("ResultProcessing", ResultProcessing);
	AdditionalParameters.Insert("WithoutConfirmation",    WithoutConfirmation);
	AdditionalParameters.Insert("AdditionalChecksParameters", New Structure);
	AdditionalChecksParameters = AdditionalParameters.AdditionalChecksParameters;
	AdditionalChecksParameters.Insert("ValidateAuthorization", ValidateAuthorization);
	
	FormTitle = NStr("en='Checking certificate %1';ru='Проверка сертификата %1'");
	FormTitle = StrReplace(FormTitle, "%1", Certificate);
	AdditionalParameters.Insert("FormTitle", FormTitle);
	If TypeOf(CompletionProcessing) = Type("NotifyDescription") Then
		AdditionalParameters.Insert("CompletionProcessing", CompletionProcessing);
	EndIf;
	
	DigitalSignatureClient.CheckCatalogCertificate(Certificate, AdditionalParameters);
	
EndProcedure

Procedure CertificateTestResultProcessor(Result, AdditionalParameters) Export
	
	If Not Result Then
		
		// Authorization check
		ValidateAuthorization = Undefined;
		If AdditionalParameters.AdditionalChecksParameters.Property("ValidateAuthorization", ValidateAuthorization)
			AND ValidateAuthorization = True Then
			If ElectronicDocumentsServiceCallServer.ServerAuthorizationPerform() Then
				CertificateChecksStructure = AdditionalParameters.Result.ChecksOnServer;
			Else
				CertificateChecksStructure = AdditionalParameters.Result.ChecksOnClient;
			EndIf;
		Else
			// Checking cryptooperations
			If ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer() Then
				CertificateChecksStructure = AdditionalParameters.Result.ChecksOnServer;
			Else
				CertificateChecksStructure = AdditionalParameters.Result.ChecksOnClient;
			EndIf;
		EndIf;
		
		Result = True;
		For Each StructureItem IN CertificateChecksStructure Do
			If Not StructureItem.Value Then
				Result = False;
				Break;
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillInPasswords(CertificateParameters, Result) Export
	
	CertificateParameters.UserPassword = Result.UserPassword;
	If CertificateParameters.Property("User") AND Result.Property("User") Then
		CertificateParameters.User = Result.User;
	EndIf;
	CertificateParameters.PasswordReceived = True;

EndProcedure

// Checks certificate validity
//
// Parameters:
//  Certificate - CatalogRef.DSCertificates - reference  to checked certificate
//
Procedure ValidateCertificateValidityPeriod(Certificate) Export
	
	CertificateAttributes = ElectronicDocumentsServiceCallServer.CertificateAttributes(Certificate);
	DATEDIFF = CertificateAttributes.ValidUntil - CommonUseClient.SessionDate();
	If Not CertificateAttributes.UserNotifiedOnValidityInterval AND DATEDIFF > 0 AND DATEDIFF < 60*60*24*31 Then
		FormID = Certificate.UUID();
		FormParameters = New Structure("Certificate", Certificate);
		OpenForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.UpcomingExpirationDateNotification",
			FormParameters);
		Operation = NStr("en='Certificate validity period verification';ru='Проверка срока действия сертификата'");
		ErrorText = NStr("en='Certificate validity period is getting expired';ru='Заканчивается срок действия сертификата'")+ " " + Certificate
					+ Chars.LF + NStr("en='It is necessary to receive a new';ru='Необходимо получить новый'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText);
	EndIf;
	
EndProcedure

// Outdated.Uses modal call. Use
// "RequestPasswordToCertificate" Function receives user password for DS certificates. If several certificates were
// transferred to AccCertificatesAndTheirStructures, then after request for password from user in this parameter one
// certificate and its parameters are placed instead of the list.
//
// Parameters:
//  AccCertificatesAndTheirStructures - Map - contains the correspondence of certificates and their parameters:
//    * Key     - CatalogRef.DSCertificates - DS certificate.
//    * Value - Structure - contains certificate parameters.
//  OperationKind                    - String - kind of operation for which user password is requested.
//  ObjectsForProcessings - Array, CatalogRef.EDAttachedFiles - one object or list of IB objects for processing;
//  WriteToIB - Boolean - True - if the password is requested for saving to catalog attribute.
//
// Returns:
//  Boolean - True - if a password for DS certificate is received, otherwise - False.
//
Function CertificatePasswordReceivedModal(AccCertificatesAndTheirStructures, OperationKind,
	ObjectsForProcessings = Undefined, WriteToIB = False) Export
	
	PasswordReceived = False;
	
	If TypeOf(AccCertificatesAndTheirStructures) = Type("Map") Then
		CertificatesCount = AccCertificatesAndTheirStructures.Count();
		Map = New Map;
		For Each KeyAndValue IN AccCertificatesAndTheirStructures Do
			Certificate = KeyAndValue.Key;
			CertificateParameters = KeyAndValue.Value;
			BankApplication = Undefined;
			If Not ValueIsFilled(CertificateParameters) Then
				CertificateParameters = ElectronicDocumentsServiceCallServer.CertificateAttributes(Certificate);
			EndIf;
			If CertificateParameters.Property("BankApplication")
				AND CertificateParameters.BankApplication = PredefinedValue("Enum.BankApplications.SberbankOnline") Then
				PasswordReceived = True;
				Break;
			EndIf;
			UserPassword = Undefined;
			If Not WriteToIB AND CertificatesCount = 1
				AND (CertificateParameters.Property("PasswordReceived", PasswordReceived) AND PasswordReceived
				OR CertificatePasswordReceived(Certificate, UserPassword)) Then
				If Not PasswordReceived Then
					PasswordReceived = True;
					CertificateParameters.Insert("PasswordReceived", PasswordReceived);
					CertificateParameters.Insert("UserPassword", UserPassword);
				EndIf;
				Break;
			ElsIf BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor")
					AND Not ObjectsForProcessings = Undefined
					AND RelevantCertificatePasswordCacheThroughAdditionalProcessing(CertificateParameters, ObjectsForProcessings) Then
				PasswordReceived = True;
				Break;
			ElsIf BankApplication = PredefinedValue("Enum.BankApplications.iBank2")
					AND Not ObjectsForProcessings = Undefined
					AND iBank2CertificatePasswordCacheIsRelevant(CertificateParameters, ObjectsForProcessings) Then
				PasswordReceived = True;
				Break;
			EndIf;
			// IN the query password form 3 parameters from the certificate structure are used:
			// UserPassword, PasswordReceived, RememberCertificatePassword. Pass them into the form.
			Structure = New Structure("UserPassword, PasswordReceived, RememberCertificatePassword");
			FillPropertyValues(Structure, CertificateParameters);
			Map.Insert(Certificate, Structure);
		EndDo;
		
		If Map.Count() > 0 Then
			FormParameters = New Structure();
			FormParameters.Insert("OperationKind",   OperationKind);
			FormParameters.Insert("WriteToIB",  WriteToIB);
			FormParameters.Insert("Map",  Map);
			If ObjectsForProcessings <> Undefined Then
				If TypeOf(ObjectsForProcessings) <> Type("Array") Then
					ObjectsArray = New Array;
					ObjectsArray.Add(ObjectsForProcessings);
				Else
					ObjectsArray = ObjectsForProcessings;
				EndIf;
				FormParameters.Insert("ObjectsForProcessings", ObjectsArray);
			EndIf;
		EndIf;
	EndIf;
	
	Return PasswordReceived;
	
EndFunction

// Procedure adds a password to global variable "CertificateAndPasswordMatch".
//
// Parameters:
//  DSCertificate       - CatalogRef.DSCertificates - DS certificate.
//  UserPassword - String - password to DS certificate.
//
Procedure AddPasswordToGlobalVariable(DSCertificate, UserPassword) Export
	
	Map = New Map;
	CertificateAndPasswordMatching = ApplicationParameters["ElectronicInteraction.CertificateAndPasswordMatching"];
	If TypeOf(CertificateAndPasswordMatching) = Type("FixedMap") Then
		For Each Item IN CertificateAndPasswordMatching Do
			Map.Insert(Item.Key, Item.Value);
		EndDo;
	EndIf;
	
	Map.Insert(DSCertificate, UserPassword);
	
	ApplicationParameters.Insert("ElectronicInteraction.CertificateAndPasswordMatching",
		New FixedMap(Map));
	
EndProcedure

// Procedure removes the password from global variable "CertificateAndPasswordMatch".
//
// Parameters:
//  DSCertificate - CatalogRef.DSCertificates - DS certificate.
//
Procedure DeletePasswordFromGlobalVariable(DSCertificate) Export
	
	CertificateAndPasswordMatching = ApplicationParameters["ElectronicInteraction.CertificateAndPasswordMatching"];
	If TypeOf(CertificateAndPasswordMatching) = Type("FixedMap")
		AND CertificateAndPasswordMatching.Get(DSCertificate) <> Undefined Then
		Map = New Map;
		For Each Item IN CertificateAndPasswordMatching Do
			If Item.Key <> DSCertificate Then
				Map.Insert(Item.Key, Item.Value);
			EndIf;
		EndDo;
		
		CertificateAndPasswordMatching = New FixedMap(Map);
	EndIf;
	
EndProcedure

Procedure HandleEDDeviationCancellation(LinkToED, EDParameters, RejectCancellation = False) Export
	
	If EDParameters.Reject Then
		GenerateED = False;
		ContinueProcessing = ElectronicDocumentsServiceCallServer.CanRejectThisED(LinkToED, GenerateED);
		If RejectCancellation Then
			Title = NStr("en='Specify the reasons of cancellation offer rejection';ru='Укажите причины отклонения предложения об аннулировании'");
		Else
			
			If ElectronicDocumentsServiceCallServer.ThisIsInvoiceReceived(LinkToED) Then
				Title = NStr("en='Specify the text of query for refinement';ru='Укажите текст запроса на уточнение'");
			Else
				Title = NStr("en='Specify reasons of the document rejection';ru='Укажите причины отклонения документа'");
			EndIf;
			
		EndIf;
	Else
		GenerateED = True;
		ContinueProcessing = ElectronicDocumentsServiceCallServer.CanVoidThisED(LinkToED);
		Title = NStr("en='Specify the reasons for document cancellation';ru='Укажите причины аннулирования документа'");
	EndIf;
	If ContinueProcessing Then
		CorrectionText = "";
		EDParameters.Insert("LinkToED", LinkToED);
		EDParameters.Insert("GenerateED", GenerateED);
		NotifyDescription = New NotifyDescription("HandleEDDeviationCancellationComplete", ThisObject, EDParameters);
		ShowInputString(NOTifyDescription, CorrectionText, Title, , True);
	EndIf;
	
EndProcedure

Procedure HandleCancellationOffer(PrimaryED, RejectCancellation = False) Export
	
	EDStructure = ElectronicDocumentsServiceCallServer.GetReferencesToEDForPOA(PrimaryED);
	EDStructure.Insert("Reject", RejectCancellation);
	If ValueIsFilled(EDStructure) Then
		If RejectCancellation Then
			NotifyDescription = New NotifyDescription("HandleCancellationOfferComplete", ThisObject);
			EDStructure.Insert("NotifyDescription", NotifyDescription);
			HandleEDDeviationCancellation(EDStructure.ATA, EDStructure, RejectCancellation);
		Else
			SendEDConfirmation(EDStructure.FileOwner, EDStructure.ATA);
		EndIf;
	EndIf;
	
EndProcedure

Procedure GenerateSignServiceED(LinkToED,
	EDKind, CorrectionText = "", AdditParameters = Undefined, NotifyDescription = Undefined) Export
	
	If TypeOf(LinkToED) <> Type("Array") Then
		EDKindsArray = New Array;
		EDKindsArray.Add(LinkToED);
	Else
		EDKindsArray = LinkToED;
	EndIf;
	
	ElectronicDocumentsClientServer.GenerateSignAndSendServiceED(EDKindsArray, EDKind,
		CorrectionText, AdditParameters, NotifyDescription);
	
EndProcedure

#EndRegion

#Region WorkWithDS

Procedure CheckDS(Result, Parameters) Export
	
	If Result = Undefined AND Parameters.SignatureCheckIndex >= 0 Then
		AfterProcessingNotificationsProcessEDPackageData(Parameters);
		Return; //  Failed to create cryptography manager, further check has no effect
	EndIf;
	
	Parameters.SignatureCheckIndex = Parameters.SignatureCheckIndex + 1;
	
	If TypeOf(Result) = Type("String") Then
		OperationKind = NStr("en='Signature check';ru='Проверка подписи'");
		MessageText = NStr("en='When verifying the signature
		|of electronic
		|document: %1 error occurred: %2';ru='При проверке подписи
		|электронного
		|документа: %1 произошла ошибка: %2'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
								MessageText, Parameters.CheckedED, Result);
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
									OperationKind, MessageText, MessageText, 0);
		Parameters.Insert("IncorrectSignature");
		AfterProcessingNotificationsProcessEDPackageData(Parameters);
		Return;
	EndIf;
	
	If Parameters.DataForCheckingES.Count() > Parameters.SignatureCheckIndex Then
		Notification = New NotifyDescription("CheckDS", ThisObject, Parameters);
		FileBinaryData = Parameters.DataForCheckingES[Parameters.CheckIndex].FileBinaryData;
		BinaryDataSignatures = Parameters.DataForCheckingES[Parameters.CheckIndex].BinaryDataSignatures;
		DigitalSignatureClient.VerifySignature(Notification, FileBinaryData, BinaryDataSignatures);
		Return;
	ElsIf Not Parameters.Property("IncorrectSignature") Then
			AddedFilesArray = ElectronicDocumentsServiceCallServer.AddDataByEDPackage(Parameters.EDPackage,
				Parameters.DataForCheckingES, Parameters.DataStructure, Parameters.UnpackingData.MapFileParameters,
				Parameters.UnpackingData.PackageFiles);
			Parameters.TotalUnpacked = Parameters.TotalUnpacked + AddedFilesArray.Count();
	EndIf;

	HandleNextNotification(Parameters);
	
EndProcedure

Procedure AfterObtainingCryptographyManagerAddInformationAboutSignature(CryptoManager, Parameters) Export
	
	If Not TypeOf(CryptoManager) = Type("CryptoManager") Then
		Return;
	EndIf;
	
	For Each Item IN Parameters.EDAndSignaturesData Do
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ElectronicDocument", Item.ElectronicDocument);
		AdditionalParameters.Insert("SignatureData", Item.SignatureData);
		Notification = New NotifyDescription(
			"AfterReceivingCertificatesAddInformationAboutSignature", ThisObject, AdditionalParameters);
		Try
			CryptoManager.StartGettingCertificatesFromSignature(Notification, Item.SignatureData);
		Except
			OperationKind = NStr("en='Extraction of certificate from signature';ru='Извлечение сертификата из подписи'");
			BriefErrorDescription = BriefErrorDescription(ErrorInfo());
			DetailErrorDescription = DetailErrorDescription(ErrorInfo());
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
				OperationKind, DetailErrorDescription, BriefErrorDescription, 0);
		EndTry
	EndDo;
	
EndProcedure

Procedure GetNextSignatureStatus(Result, Parameters) Export
	
	If Result = Undefined AND Parameters.Property("CheckResult") Then
		Return; //  Failed to create cryptography manager, further check has no effect
	EndIf;
	
	Parameters.CheckIndex = Parameters.CheckIndex + 1;
	
	If Not Parameters.Property("CheckResult") Then
		CheckResult = New Array;
		Parameters.Insert("CheckResult", CheckResult);
	EndIf;
	
	RecordStructure = New Structure("LineNumber", Parameters.CheckIndex);
	
	If Result = True Then
		RecordStructure.Insert("Result", True);
		Parameters.CheckResult.Add(RecordStructure);
	ElsIf TypeOf(Result) = Type("String") Then
		OperationKind = NStr("en='Signature check';ru='Проверка подписи'");
		MessageText = NStr("en='When verifying the signature
		|of electronic
		|document: %1 error occurred: %2';ru='При проверке подписи
		|электронного
		|документа: %1 произошла ошибка: %2'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
								MessageText, Parameters.CheckedED, Result);
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
									OperationKind, MessageText, MessageText, 0);
		RecordStructure.Insert("Result", False);
		Parameters.CheckResult.Add(RecordStructure);
		Parameters.Insert("IncorrectSignature");
	EndIf;

	If Parameters.Signatures.Count() > Parameters.CheckIndex Then
		Notification = New NotifyDescription("GetNextSignatureStatus", ThisObject, Parameters);
		DigitalSignatureClient.VerifySignature(
			Notification, Parameters.EDData, Parameters.Signatures[Parameters.CheckIndex].Signature);
		Return;
	EndIf;

	If Parameters.Property("CheckedED") Then
		ElectronicDocumentsServiceCallServer.SaveResultsChecksSignatures(
								Parameters.CheckedED, Parameters.CheckResult);
	EndIf;
	
	If Parameters.Property("AlertAfterChecksingSignature") Then
		ExecuteNotifyProcessing(Parameters.AlertAfterChecksingSignature, Parameters.Property("IncorrectSignature"));
	EndIf;
	
EndProcedure

// Saves signatures in electronic document
//
// Parameters:
//  EDAndSignaturesData  - Array - there are data structures
//     * SignatureData in the items - BinaryData - digital
//     signature * ElectronicDocument  - CatalogRef.EDAttachedFiles - reference to electronic document
//
Procedure AddInformationAboutSignature(EDAndSignaturesData) Export
	
	If TypeOf(EDAndSignaturesData) = Type("Array") AND EDAndSignaturesData.Count() > 0 Then
		Parameters = New Structure("EDAndSignaturesData", EDAndSignaturesData);
		
		Notification = New NotifyDescription(
			"AfterObtainingCryptographyManagerAddInformationAboutSignature", ThisObject, Parameters);
			
		DigitalSignatureClient.CreateCryptoManager(Notification, "GetCertificates");
	EndIf;
	
EndProcedure

#EndRegion

#Region DataProcessorElectronicDocuments

Procedure AfterObtainingPrintsOpenEDForViewing(Prints, Parameters) Export
	
	ThumbprintArray = New Array;
	If TypeOf(Prints) = Type("Map") Then
		For Each KeyValue IN Prints Do
			ThumbprintArray.Add(KeyValue.Key);
		EndDo;
	EndIf;
	
	LinkToED = Parameters.LinkToED;
	OpenParameters = Parameters.OpenParameters;
	FormOwner = Parameters.FormOwner;
	
	FormParameters = New Structure("Key, PrintsArray", LinkToED, ThumbprintArray);
	EDParameters = ElectronicDocumentsServiceCallServer.EDKindAndOwner(LinkToED);
	If EDParameters.EDKind = PredefinedValue("Enum.EDKinds.RandomED") Then
		ShowValue(, EDParameters.FileOwner);
	ElsIf FormOwner = Undefined Then
		OpenForm("Catalog.EDAttachedFiles.Form.EDViewForm", FormParameters, , LinkToED);
	Else
		If OpenParameters = Undefined Then
			OpenForm("Catalog.EDAttachedFiles.Form.EDViewForm", FormParameters, FormOwner, LinkToED);
		Else
			Window = Undefined;
			If TypeOf(OpenParameters) = Type("CommandExecuteParameters")
				OR TypeOf(OpenParameters) = Type("Structure")
				AND OpenParameters.Property("Window") AND TypeOf(OpenParameters.Window) = Type("ClientApplicationWindow") Then
				
				Window = OpenParameters.Window;
			EndIf;
			OpenForm("Catalog.EDAttachedFiles.Form.EDViewForm", FormParameters,
				FormOwner, OpenParameters.Uniqueness, Window);
		EndIf;
	EndIf;
	
EndProcedure

Procedure AfterObtainingPrintsProcessED(CertificatesPrints, Parameters) Export
	
	CountTotalNewED = 0;
	TotalNumberOfConfirmedED = 0;
	TotalDigitallySignedCnt = 0;
	TotalPreparedCnt = 0;
	TotalSentCnt = 0;
	
	RefsToObjectArray = Parameters.RefsToObjectArray;
	Action = Parameters.Action;
	AdditParameters = Parameters.AdditParameters;
	ED = Parameters.ED;
	NotifyDescription = Parameters.NotifyDescription;
	
	CertificateTumbprintsArray = New Array;
	CryptographySettingsError =False;
	
	If TypeOf(CertificatesPrints) = Type("String") Then
		CertificateTumbprintsArray = New Array;
		CryptographySettingsError = True;
		AdditParameters.Insert("CryptographySettingsError", CryptographySettingsError);
	ElsIf TypeOf(CertificatesPrints) = Type("Map") Then
		For Each KeyValue IN CertificatesPrints Do
			CertificateTumbprintsArray.Add(KeyValue.Key);
		EndDo
	EndIf;
	
	If ValueIsFilled(ED) AND Not CryptographySettingsError Then
		If Not ElectronicDocumentsServiceCallServer.ThereAreAvailableCertificates(CertificateTumbprintsArray, ED) Then
			AdditParameters.Insert("CertificateSetupError", True);
		EndIf;
	EndIf;
	
	CertificateAndPasswordMatching = New Map;
	
	Result = ElectronicDocumentsServiceCallServer.PerformActionsByED(RefsToObjectArray,
																				CertificateTumbprintsArray,
																				Action,
																				AdditParameters,
																				ED,
																				CertificateAndPasswordMatching);
	
	ServerAuthorizationPerform = Undefined;
	PerformCryptoOperationsAtServer = Undefined;
	ImmediateEDSending = Undefined;
	ExecuteAlert = True;
	If TypeOf(Result) = Type("Structure") Then
		Result.Property("ServerAuthorizationPerform", ServerAuthorizationPerform);
		Result.Property("PerformCryptoOperationsAtServer", PerformCryptoOperationsAtServer);
		Result.Property("ImmediateEDSending", ImmediateEDSending);
		
		If Not Result.Property("DigitallySignedCnt", TotalDigitallySignedCnt) Then
			TotalDigitallySignedCnt = 0;
		EndIf;
		
		If Not Result.Property("PreparedCnt", TotalPreparedCnt) Then
			TotalPreparedCnt = 0;
		EndIf;
		
		If Not Result.Property("SentCnt", TotalSentCnt) Then
			TotalSentCnt = 0;
		EndIf;
		
		If Not Result.Property("NewEDCount", CountTotalNewED) Then
			CountTotalNewED = 0;
		EndIf;
		
		If TotalNumberOfConfirmedED = 0 AND Result.Property("CountOfApprovedED") Then
			TotalNumberOfConfirmedED = Result.CountOfApprovedED;
		EndIf;
		
		// ED signing:
		
		MapOfEDCertificatesAndArraysToSignatures = New Map;
		
		EDArrayToBeDeletedFromSending = New Array;
		StructuStructuresEDArraysAndCertificates = Undefined;
		MatchEDAndAgreements = Undefined;
		AccCertificatesAndTheirStructures = Undefined;
		
		ContextParameters = New Structure();
		ContextParameters.Insert("Result", Result);
		ContextParameters.Insert("NotifyDescription", NotifyDescription);
		ContextParameters.Insert("ServerAuthorizationPerform", ServerAuthorizationPerform);
		ContextParameters.Insert("PerformCryptoOperationsAtServer", PerformCryptoOperationsAtServer);
		ContextParameters.Insert("ImmediateEDSending", ImmediateEDSending);
		ContextParameters.Insert("TotalSentCnt", TotalSentCnt);
		ContextParameters.Insert("TotalPreparedCnt", TotalPreparedCnt);
		ContextParameters.Insert("CountTotalNewED", CountTotalNewED);
		ContextParameters.Insert("TotalNumberOfConfirmedED", TotalNumberOfConfirmedED);
		ContextParameters.Insert("TotalDigitallySignedCnt", TotalDigitallySignedCnt);
		ContextParameters.Insert("Action", Action);
		ContextParameters.Insert("RefsToObjectArray", RefsToObjectArray);
		ContextParameters.Insert("EDArrayToBeDeletedFromSending", EDArrayToBeDeletedFromSending);
		ContextParameters.Insert("MapOfEDCertificatesAndArraysToSignatures", MapOfEDCertificatesAndArraysToSignatures);
		ContextParameters.Insert("AccCertificatesAndTheirStructures", AccCertificatesAndTheirStructures);
		If ValueIsFilled(AdditParameters) AND AdditParameters.Property("NotifyAboutCreatingNotifications") Then
			ContextParameters.Insert("NotifyAboutCreatingNotifications", AdditParameters.NotifyAboutCreatingNotifications);
		EndIf;

		If Result.Property("AccCertificatesAndTheirStructures", AccCertificatesAndTheirStructures)
			AND Result.Property("StructuStructuresEDArraysAndCertificates", StructuStructuresEDArraysAndCertificates)
			AND Result.Property("MatchEDAndAgreements", MatchEDAndAgreements) Then
			
			ProfilesAndCertificatesCorrespondence = Undefined;
			If AdditParameters.Property("CompatibleCertificates", ProfilesAndCertificatesCorrespondence) AND ValueIsFilled(ProfilesAndCertificatesCorrespondence) Then
				CompatibleCertificates = CertificatesParameters(ProfilesAndCertificatesCorrespondence);
				For Each KeyValue IN AccCertificatesAndTheirStructures Do
					CertificateParameters = CompatibleCertificates.Get(KeyValue.Key);
					FillInPasswords(KeyValue.Value, CertificateParameters);
				EndDo;
			EndIf;
			
			ContextParameters.Insert("StructuStructuresEDArraysAndCertificates", StructuStructuresEDArraysAndCertificates);
			ContextParameters.Insert("AccCertificatesAndTheirStructures", AccCertificatesAndTheirStructures);
			ContextParameters.Insert("FirstIterationIndex", 0);
			ContextParameters.Insert("SecondIterationIndex", 0);
			ContextParameters.Insert("ThirdIterationIndex", 0);
			ExecuteAlert = False;
			SignED(Undefined, ContextParameters);
		Else
			If AccCertificatesAndTheirStructures = Undefined Then
				AccCertificatesAndTheirStructures = New Map;
			EndIf;
			ContextParameters.Insert("AccCertificatesAndTheirStructures", AccCertificatesAndTheirStructures);
			// Send ED:
			ExecuteAlert = False;
			EDSending(ContextParameters);
		EndIf;
	ElsIf Result <> Undefined Then
		Notify("RefreshStateED");
	EndIf;
	
	If ExecuteAlert AND TypeOf(NOTifyDescription) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(NOTifyDescription);
	EndIf;
	
EndProcedure

Procedure AfterProcessingNotificationsProcessEDPackageData(Parameters) Export
	
	NotifyDescription               = Parameters.ContinuationHandler;
	UnpackingData                 = Parameters.UnpackingData;
	TotalUnpacked                 = Parameters.TotalUnpacked;
	
	IsCryptofacilityOnClient      = Parameters.IsCryptofacilityOnClient;
	EDPackage                          = Parameters.EDPackage;
	
	BinaryDataArray = UnpackingData.StructureOfBinaryData;
	
	ExecuteAlertDescription = True;
	IsUnpackingError = Parameters.Property("IncorrectSignature");

	If Not IsUnpackingError Then
		If BinaryDataArray.Count() = 0 Then
			EDAndSignaturesDataArray = New Array;
			ElectronicDocumentsServiceCallServer.ProcessDocumentsConfirmationsAtServer(
															UnpackingData.MapFileParameters,
															EDPackage,
															UnpackingData.PackageFiles,
															EDAndSignaturesDataArray);
			If EDAndSignaturesDataArray.Count() > 0 Then
				AddInformationAboutSignature(EDAndSignaturesDataArray);
			EndIf;
			TotalUnpacked = TotalUnpacked + EDAndSignaturesDataArray.Count();
		Else
			EDArrayForNoticeGeneration = New Array;
			For Each DataStructure IN BinaryDataArray Do
				SignsStructuresArray = ElectronicDocumentsServiceCallServer.GetSignaturesDataCorrespondence(
																						DataStructure.FileName,
																						UnpackingData.PackageFiles,
																						DataStructure.BinaryData,
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
																						
				If AddedFilesArray <> Undefined AND AddedFilesArray.Count() > 0
					AND Not ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer() Then
					If AccordanceOfEdAndSignatures.Count() > 0 Then
						EDandSignaturesArray = New Array;
						For Each Item IN AccordanceOfEdAndSignatures Do
							For Each SignatureData IN Item.Value Do
								DataStructure = New Structure;
								DataStructure.Insert("ElectronicDocument", Item.Key);
								DataStructure.Insert("SignatureData", SignatureData);
								EDandSignaturesArray.Add(DataStructure);
							EndDo;
						EndDo
					EndIf;
					AddInformationAboutSignature(EDandSignaturesArray);
					TotalUnpacked = TotalUnpacked + AddedFilesArray.Count();
				EndIf;
				If Not IsUnpackingError Then
					If (ValueIsFilled(Parameters.DataType)
							AND UnpackingData.MapFileParameters.Get("IsArbitraryED") = Undefined
							AND ElectronicDocumentsServiceCallServer.GetEDExchangeMethodOfEDPackage(EDPackage)
								= PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom"))
						Or (ElectronicDocumentsServiceCallServer.PackageFormatVersion(EDPackage)
							= PredefinedValue("Enum.EDPackageFormatVersions.Version30")) Then
						//
						For Each ED IN AddedFilesArray Do
							EDArrayForNoticeGeneration.Add(ED);
						EndDo;
					EndIf;
				EndIf;
			EndDo;
			If EDArrayForNoticeGeneration.Count() > 0 Then
				EDKind = PredefinedValue("Enum.EDKinds.NotificationAboutReception");
				AdditParameters= New Structure;
				GenerateSignServiceED(AddedFilesArray, EDKind, , AdditParameters, NotifyDescription);
				ExecuteAlertDescription = False;
			EndIf;
		EndIf;
	EndIf;
		
	If Not IsUnpackingError Then
		ElectronicDocumentsServiceCallServer.SetPackageStatus(EDPackage,
			PredefinedValue("Enum.EDPackagesStatuses.Unpacked"));
	EndIf;
	If ExecuteAlertDescription Then
		ExecuteNotifyProcessing(NOTifyDescription, TotalUnpacked);
	EndIf;
	
EndProcedure

// For internal use only
Procedure SendEDConfirmation(CommandParameter, ED = Undefined) Export
	
	RefArray = GetParametersArray(CommandParameter);
	If RefArray = Undefined Then
		If ED = Undefined Then
			Return;
		Else
			RefArray = New Array;
		EndIf;
	EndIf;
	
	ProcessED(RefArray, "ConfirmSignSend", , ED);
	Notify("RefreshStateED");
	
EndProcedure

// For internal use only
Procedure ConfirmED(CommandParameter, ED = Undefined, SendingFlag = True, NewED = Undefined) Export
	
	#If ThickClientOrdinaryApplication Then
		If Not (ElectronicDocumentsOverridable.IsRightToProcessED()) Then
			MessageToUserAboutViolationOfRightOfAccess();
			Return;
		EndIf;
	#EndIf
	
	RefArray = GetParametersArray(CommandParameter);
	If RefArray = Undefined Then
		If ED = Undefined Then
			Return;
		Else
			RefArray = New Array;
		EndIf;
	EndIf;
	
	If SendingFlag Then
		CommandName = "ApproveSend";
	Else
		CommandName = "Approve";
	EndIf;
	AdditParameters = New Structure;
	ProcessED(RefArray, CommandName, AdditParameters, ED);
	
	AdditParameters.Property("NewED", NewED);
	
	Notify("RefreshStateED");
	
EndProcedure

// Function receives the array of references to objects.
//
// Parameters:
//  CommandParameter - object reference or array
//
// Returns:
//  RefArray - if an array is passed to the parameter,
//                 it returns the same one; if an empty reference is passed, returns undefined
//
Function GetParametersArray(CommandParameter) Export
	
	If TypeOf(CommandParameter) = Type("Array") Then
		If CommandParameter.Count() = 0 Then
			Return Undefined;
		EndIf;
		RefArray = CommandParameter;
	#If ThickClientOrdinaryApplication Then
		ElsIf TypeOf(CommandParameter) = Type("TableBoxSelectedRows") Then
			RefArray = New Array;
			For Each Item IN CommandParameter Do
				RefArray.Add(Item);
			EndDo
	#EndIf
	Else // single object reference is received
		If Not ValueIsFilled(CommandParameter) Then
			Return Undefined;
		EndIf;
		RefArray = New Array;
		RefArray.Add(CommandParameter);
	EndIf;
	
	Return RefArray;
	
EndFunction

// Called from procedure PrepareAndSendEDPContinue(...).
// Calls procedure ExecuteActionsAfterSendingEDPComplete(AdditParameters).
//
// Parameters:
//   Result - CryptoManager - initialized cryptography manager.
//               String - error description while creating a cryptography manager.
//               Undefined - First method call

//   AdditParameters - Structure:
//      Parameters                                   - Structure - incoming parameters for ED sending.
//      EDPSendingResult                        - Structure:
//         ArrayOfPackagesForDataProcessorsAtClient - Array - items - DocumentRef.EDPackages.
//         SentCnt                    - Number.
//      ProfilesAndCertificatesParametersMatch - Matching.
//
Procedure ExecuteActionsAfterSendingEDP(Result, AdditParameters) Export
	
	Parameters = Undefined;
	EDPSendingResult = Undefined;
	HandlerAfterSendingEDP = Undefined;
	ProfilesAndCertificatesParametersMatch = Undefined;
	AdditParameters.Property("Parameters", Parameters);
	AdditParameters.Property("EDPSendingResult", EDPSendingResult);
	AdditParameters.Property("ProfilesAndCertificatesParametersMatch", ProfilesAndCertificatesParametersMatch);
	
	GotoToSendingCompletion = True;
	ArrayOfPackagesForDataProcessorsAtClient = Undefined;
	If TypeOf(EDPSendingResult) = Type("Structure")
		AND EDPSendingResult.Property("ArrayOfPackagesForDataProcessorsAtClient", ArrayOfPackagesForDataProcessorsAtClient)
		AND ArrayOfPackagesForDataProcessorsAtClient.Count() > 0 Then
		
		If Result = Undefined Then
			NotifyDescription = New NotifyDescription("ExecuteActionsAfterSendingEDP", ThisObject, AdditParameters);
			DigitalSignatureClient.CreateCryptoManager(NOTifyDescription, "Encryption");

			GotoToSendingCompletion = False;
		ElsIf TypeOf(Result) = Type("CryptoManager") Then
			GotoToSendingCompletion = False;
			// By BED concept there is one electronic document in the package.
			AccordanceDataPackages = ElectronicDocumentsServiceCallServer.AccordanceDataPackages(
													EDPSendingResult.ArrayOfPackagesForDataProcessorsAtClient);
													
			Parameters.Insert("AccordanceDataPackages", AccordanceDataPackages);
			Parameters.Insert("CryptoManager", Result);
			PreparePackagesForSending(AdditParameters);
		EndIf;
	EndIf;
	
	If GotoToSendingCompletion Then
		ExecuteActionsAfterSendingEDPComplete(AdditParameters);
	EndIf;
	
EndProcedure

// Called from procedure ExecuteActionsAfterSendingEDP(...).
// Calls the procedure StartSendingPackagesThroughAdditionalDataProcessor(...),
//   or ConnectExternalComponentiBank2(...),
//   or describes the notification sent in parameter HandlerAfterSendingEDP.
//
// Parameters:
//   AdditParameters - Structure:
//      EDPSendingResult       - Structure:
//         
//      Parameters                  - Structure - optional parameter, additional
//                                     parameters passed from the method which initiated EDP sending.
//      HandlerAfterSendingEDP - NotifyDescription - optional parameter, handling of EDP sending result.
//
Procedure ExecuteActionsAfterSendingEDPComplete(AdditParameters)
	
	Parameters = Undefined;
	EDPSendingResult = Undefined;
	HandlerAfterSendingEDP = Undefined;
	AdditParameters.Property("Parameters", Parameters);
	AdditParameters.Property("EDPSendingResult", EDPSendingResult);
	AdditParameters.Property("HandlerAfterSendingEDP", HandlerAfterSendingEDP);
	
	ExecuteHandlerAfterSending = True;
	If TypeOf(EDPSendingResult) = Type("Structure") Then
		If EDPSendingResult.Property("DataForSendingViaAddDataProcessor")
			AND EDPSendingResult.DataForSendingViaAddDataProcessor.Count() > 0 Then
			
			Structure = New Structure;
			Structure.Insert("DataForSending", EDPSendingResult.DataForSendingViaAddDataProcessor);
			Structure.Insert("HandlerAfterSendingEDP", HandlerAfterSendingEDP);
			Structure.Insert("PreparedCnt", EDPSendingResult.PreparedCnt);
			Structure.Insert("SentCnt",   EDPSendingResult.SentCnt);
			SendThroughAdditionalDataProcessor(Undefined, Structure);
			ExecuteHandlerAfterSending = False;
		ElsIf EDPSendingResult.Property("DataForiBank2Sending")
			AND EDPSendingResult.DataForiBank2Sending.Count() > 0 Then
			
			Parameters.Insert("DataStructure", EDPSendingResult);
			If EDPSendingResult.Property("PreparedCnt") Then
				Parameters.TotalPreparedCnt = Parameters.TotalPreparedCnt + EDPSendingResult.PreparedCnt;
			EndIf;
			
			HandlerAfterConnecting = New NotifyDescription("StartSendingiBank2Packages", ThisObject, Parameters);
			Parameters.Insert("HandlerAfterConnectingComponents", HandlerAfterConnecting);
			EnableExternalComponentiBank2(Parameters);
			ExecuteHandlerAfterSending = False;
		EndIf;
	EndIf;
	
	If ExecuteHandlerAfterSending
		AND TypeOf(HandlerAfterSendingEDP) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(HandlerAfterSendingEDP, EDPSendingResult);
	EndIf;
	
EndProcedure

// Called from procedure PrepareAndSendEDP(...).
// Calls procedure ExecuteActionsAfterSendingEPD(Result, AdditParameters).
//
// Parameters:
//   Result    - Structure:
//      ProfilesAndCertificatesParametersMatch - Matching.
//   AdditParameters - Structure:
//      Parameters                  - Structure.
//      SignatureSign             - Boolean.
//      AddedFiles           - CatalogRef.EDAttachedFiles.
//      HandlerAfterSendingEDP - NotificationDescription.
//
Procedure PrepareAndSendEDPContinue(Result, AdditParameters) Export
	
	ProfilesAndCertificatesParametersMatch = Undefined;
	If Not (TypeOf(Result) = Type("Structure")
		AND Result.Property("ProfilesAndCertificatesParametersMatch", ProfilesAndCertificatesParametersMatch)
		AND TypeOf(ProfilesAndCertificatesParametersMatch) = Type("Map")) Then
		
		ProfilesAndCertificatesParametersMatch = New Map;
	EndIf;
	
	Parameters = Undefined;
	SignatureSign = Undefined;
	AddedFiles = Undefined;
	HandlerAfterSendingEDP = Undefined;
	AdditParameters.Property("Parameters", Parameters);
	AdditParameters.Property("SignatureSign", SignatureSign);
	AdditParameters.Property("AddedFiles", AddedFiles);
	AdditParameters.Property("HandlerAfterSendingEDP", HandlerAfterSendingEDP);
	
	EDPSendingResult = ElectronicDocumentsServiceCallServer.CreateAndSendDocumentsPED(AddedFiles,
																								SignatureSign,
																								ProfilesAndCertificatesParametersMatch);
	AdditParameters = New Structure;
	AdditParameters.Insert("Parameters", Parameters);
	AdditParameters.Insert("EDPSendingResult", EDPSendingResult);
	AdditParameters.Insert("HandlerAfterSendingEDP", HandlerAfterSendingEDP);
	AdditParameters.Insert("ProfilesAndCertificatesParametersMatch", ProfilesAndCertificatesParametersMatch);
	
	ExecuteActionsAfterSendingEDP(Undefined, AdditParameters);
	
EndProcedure

// Prepares ED for sending and SENDS (prepared electronic documents).
//
// Parameters:
//  AddedFiles - Array of references to electronic documents that shall be placed
//  in ED packages, SignatureFlag - Boolean, a flag showing that electronic documents
//  are signed with DS PasswordsAndMarkersStructure - contains data about the passwords
//  of certificates and markers Parameters - additional data processor parameters
//
Procedure PrepareAndSendPED(
	AddedFiles,
	SignatureSign,
	ProfilesAndCertificatesParametersMatch = Undefined,
	Parameters = Undefined,
	HandlerAfterSendingEDP = Undefined) Export
	
	AdditParameters = New Structure;
	AdditParameters.Insert("AddedFiles", AddedFiles);
	AdditParameters.Insert("SignatureSign", SignatureSign);
	AdditParameters.Insert("Parameters", Parameters);
	AdditParameters.Insert("HandlerAfterSendingEDP", HandlerAfterSendingEDP);
	NotifyDescription = New NotifyDescription("PrepareAndSendEDPContinue", ThisObject, AdditParameters);
	If ProfilesAndCertificatesParametersMatch = Undefined Then
		GetAgreementsAndCertificatesParametersMatch(NOTifyDescription, , AddedFiles);
	Else
		NotificationParameters = New Structure;
		NotificationParameters.Insert("ProfilesAndCertificatesParametersMatch", ProfilesAndCertificatesParametersMatch);
		ExecuteNotifyProcessing(NOTifyDescription, NotificationParameters);
	EndIf;
	
EndProcedure

// For internal use only
Procedure SendEDPackagesArray(Val ArrayPED, NotificationProcessing = Undefined) Export
	
	AdditParameters = New Structure;
	AdditParameters.Insert("NotificationProcessing", NotificationProcessing);
	AdditParameters.Insert("ArrayPED", ArrayPED);
	
	Notification = New NotifyDescription("SendPackagesArrayAlert", ThisObject, AdditParameters);
	
	GetAgreementsAndCertificatesParametersMatch(Notification, , ArrayPED);
	
EndProcedure

// Checks whether electronic document
// signatures are valid and fills in the Status and SignaturesCheckDate attributes in the DigitalSignatures tabular section.
//
// Parameters:
//  ED - CatalogRef.EDAttachedFiles
//
Procedure DetermineSignaturesStatuses(ED) Export

	CheckResult = New Array;
	
	EDContentStructure = ElectronicDocumentsServiceCallServer.EDContentStructure(ED);
	EDContentStructure.Insert("CheckIndex", -1);
	EDContentStructure.Insert("CheckedED", ED);
	GetNextSignatureStatus(Undefined, EDContentStructure);
	
EndProcedure

// Displays information about processed electronic documents to a user.
//
// Parameters:
//  GeneratedCnt - number, quantity of generated
//  electronic documents, NumberSigned - number, quantity of signed
//  electronic documents, NumberSent - number, quantity of sent electronic documents.
//
Procedure OutputInformationAboutProcessedED(GeneratedCnt, ConfirmedCnt, DigitallySignedCnt, PreparedCnt, SentCnt = 0) Export
	
	If PreparedCnt + SentCnt > 0 Then
		AdditText = ?(SentCnt > 0, "sent", "prepared for sending");
		Quantity = ?(SentCnt > 0, SentCnt, PreparedCnt);
		If DigitallySignedCnt > 0 Then
			If ConfirmedCnt > 0 Then
				If GeneratedCnt > 0 Then
					Text = NStr("en='Generated: (%1), approved: (%2), signed: (%3), %4 packages: (%5)';ru='Сформировано: (%1), утверждено: (%2), подписано: (%3), %4 пакетов: (%5)'");
					Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, GeneratedCnt, ConfirmedCnt,
						DigitallySignedCnt, AdditText, PreparedCnt);
				Else
					Text = NStr("en='Approved: (%1), signed: (%2), %3 packages: (%4)';ru='Утверждено: (%1), подписано: (%2), %3 пакетов: (%4)'");
					Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, ConfirmedCnt, DigitallySignedCnt, AdditText,
						PreparedCnt);
				EndIf;
			Else
				Text = NStr("en='Signed: (%1), %2 packages: (%3)';ru='Подписано: (%1), %2 пакетов: (%3)'");
				Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, DigitallySignedCnt, AdditText, PreparedCnt);
			EndIf;
		Else
			If ConfirmedCnt > 0 Then
				If GeneratedCnt > 0 Then
					Text = NStr("en='Generated: (%1), approved: (%2), %3 packages: (%4)';ru='Сформировано: (%1), утверждено: (%2), %3 пакетов: (%4)'");
					Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, GeneratedCnt,
						ConfirmedCnt, AdditText, PreparedCnt);
				Else
					Text = NStr("en='Approved: (%1), %2 packages: (%3)';ru='Утверждено: (%1), %2 пакетов: (%3)'");
					Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, ConfirmedCnt, AdditText, PreparedCnt);
				EndIf;
			Else
				Text = NStr("en='%1 of packages: (%2)';ru='%1 пакетов: (%2)'");
				Quantity = Max(PreparedCnt, SentCnt);
				Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, AdditText, Quantity);
			EndIf;
		EndIf;
	Else
		If DigitallySignedCnt > 0 Then
			If ConfirmedCnt > 0 Then
				If GeneratedCnt > 0 Then
					Text = NStr("en='Generated: (%1), approved: (%2), signed: (%3)';ru='Сформировано: (%1), утверждено: (%2), подписано: (%3)'");
					Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, GeneratedCnt, ConfirmedCnt,
						DigitallySignedCnt);
				Else
					Text = NStr("en='Approved: (%1), signed: (%2)';ru='Утверждено: (%1), подписано: (%2)'");
					Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, ConfirmedCnt, DigitallySignedCnt);
				EndIf;
			Else
				Text = NStr("en='Signed: (%1)';ru='Подписано: (%1)'");
				Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, DigitallySignedCnt);
			EndIf;
		Else
			If ConfirmedCnt > 0 Then
				If GeneratedCnt > 0 Then
					Text = NStr("en='Generated: (%1), approved: (%2)';ru='Сформировано: (%1), утверждено: (%2)'");
					Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, GeneratedCnt, ConfirmedCnt);
				Else
					Text = NStr("en='Approved: (%1)';ru='Утверждено: (%1)'");
					Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, ConfirmedCnt);
				EndIf;
			Else
				If GeneratedCnt > 0 Then
					Text = NStr("en='Generated: (%1)';ru='Сформировано: (%1)'");
					Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, GeneratedCnt);
				Else
					Text = NStr("en='There are no processed documents...';ru='Обработанных документов нет...'");
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	HeaderText = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
	ShowUserNotification(HeaderText, ,Text);
		
EndProcedure

// Processes sent IB documents in electronic documents exchange system in compliance with parameters.
//
// Parameters:
//  RefsToObjectArray - array of references to IB objects or
//  ED to be processed, Action - String, presentation of the action to be executed
//  with electronic documents, AdditParameters - structure, additional parameters of electronic documents processor.
//  ED - CatalogRef.EDAttachedFiles,
//       reference to catalog item EDAttachedFiles if it is required to handle only one ED
//
Procedure ProcessED(Val RefsToObjectArray,
	Action, AdditParameters = "", Val ED = Undefined, NotifyDescription = Undefined) Export
			
	If TypeOf(AdditParameters) <> Type("Structure") Then
		AdditParameters = New Structure;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("RefsToObjectArray", RefsToObjectArray);
	Parameters.Insert("Action", Action);
	Parameters.Insert("AdditParameters", AdditParameters);
	Parameters.Insert("ED", ED);
	Parameters.Insert("NotifyDescription", NotifyDescription);
	
	CryptographySettingsError = False;
	CertificateTumbprintsArray = New Array;
	If (ElectronicDocumentsClientServer.IsAction(Action, "Sign")
			OR ElectronicDocumentsClientServer.IsAction(Action, "Send"))
		AND DigitalSignatureClient.UseDigitalSignatures() Then
		Notification = New NotifyDescription("AfterObtainingPrintsProcessED", ThisObject, Parameters);
		DigitalSignatureClient.GetCertificatesThumbprints(Notification, True, False);
		Return;
	EndIf;
		
	AfterObtainingPrintsProcessED(Undefined, Parameters)
	
EndProcedure

Function CertificatesParameters(ProfilesCorrespondence)
	
	Result = New Map;
	For Each KeyValue IN ProfilesCorrespondence Do
		Result.Insert(KeyValue.Value.SignatureCertificate, KeyValue.Value);
	EndDo;
	
	Return Result;
	
EndFunction

Procedure HandleSigningResult(ExecutionResult, Parameters) Export
	
	DataDescription = Undefined;
	If TypeOf(ExecutionResult) = Type("Structure")
		AND ExecutionResult.Property("DataDescription", DataDescription)
		AND TypeOf(DataDescription) = Type("Structure") Then
		
		SignatureProperties = Undefined;
		If DataDescription.Property("SignatureProperties", SignatureProperties) Then
			ED = Undefined;
			If DataDescription.Property("CurrentDataSetItem", ED)
				OR DataDescription.Property("Object", ED) Then
				
				AccordanceOfEdAndSignatures = Undefined;
				If TypeOf(Parameters) = Type("Structure")
					AND Parameters.Property("AccordanceOfEdAndSignatures", AccordanceOfEdAndSignatures)
					AND TypeOf(AccordanceOfEdAndSignatures) = Type("Map") Then
					AccordanceOfEdAndSignatures.Insert(ED, SignatureProperties);
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure GetBinaryDataForED(Result, AdditionalParameters) Export
	
	ED = Undefined;
	DataDescription = Undefined;
	If TypeOf(AdditionalParameters) = Type("Structure")
		AND AdditionalParameters.Property("ED", ED)
		AND TypeOf(ED) = Type("CatalogRef.EDAttachedFiles") Then
		
		SelectedCertificate = Undefined;
		If Not (AdditionalParameters.Property("DataDescription", DataDescription)
			AND TypeOf(DataDescription) = Type("Structure")
			AND DataDescription.Property("SelectedCertificate", SelectedCertificate)
			AND TypeOf(SelectedCertificate) = Type("Structure")
			AND SelectedCertificate.Property("Ref", SelectedCertificate)
			AND TypeOf(SelectedCertificate) = Type("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates")) Then
			
			SelectedCertificate = Undefined;
		EndIf;
		BinaryDataED = ElectronicDocumentsServiceCallServer.GetFileBinaryData(ED, SelectedCertificate);
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("Data", BinaryDataED);
	
	ExecuteNotifyProcessing(Result.Notification, Parameters);
	
EndProcedure

// Signs ED and goes to procedure ActionsAfterSigningED(Parameters).
//
// Parameters:
//   ExecutionResult - Undefined - does not participate in the logic of the procedure.
//   Parameters - Structure:
//      Result                    - Structure:
//         StructuStructuresEDArraysAndCertificates - Structure:
//            CertificatesArray - Array - one or several certificates with which ED
//               can be signed are located in the following parameter of the structure.
//            MatchEDAndDD  - Map:
//               Key     - CatalogRef.EDAttachedFiles - reference to signed ED.
//               Value - Undefined, Row - Address of temporary storage referencing
//                  to the binary data of ED. If the value is empty, then binary data of
//                  ED will be determined directly before signing ED in the
//                  procedure specified in alert handler, for example: GetBinaryDataForED.
//            DataForSpecProcessor - Map - data for bank ED signing.
//         EDArrayForStatusUpdate            - Array - array of ED for which you
//            should update the statuses after signing all documents.
//      AccordanceOfEdAndSignatures      - Matching.
//      AccCertificatesAndTheirStructures - Map:
//         Key     - CatalogRef.DigitalSignatureAndEncryptionKeyCertificates.
//         Value - Structure - certificate parameters.
//
Procedure SignED(ExecutionResult = Undefined, Parameters) Export
	
	StructuStructuresEDArraysAndCertificates = Undefined;
	InputStructure = Parameters.Result;
	
	If TypeOf(ExecutionResult) = Type("Structure") Then
		TotalDigitallySignedCnt = 0;
		If ExecutionResult.Property("TotalDigitallySignedCnt", TotalDigitallySignedCnt)
			AND TypeOf(TotalDigitallySignedCnt) = Type("Number") Then
			
			Parameters.TotalDigitallySignedCnt = Parameters.TotalDigitallySignedCnt + TotalDigitallySignedCnt;
		EndIf;
		
		// Alert appeared from SSL procedure
		If ExecutionResult.Property("DataSet") Then
			// If Success, it is required to enumerate
			// the items of Data set array in signed ED, property "Signature properties"
			// will be a structure in array item; such ED shall be added to array "EDArray" for update of their statuses.
			EDKindsArray = Undefined;
			If Not (Parameters.Property("EDArrayForStatusUpdate", EDKindsArray)
						OR TypeOf(EDKindsArray) = Type("Array")) Then
						
				Parameters.Insert("EDArrayForStatusUpdate", New Array);
				EDKindsArray = Parameters.EDArrayForStatusUpdate;
				
			EndIf;

			For Each DigitallySignedData IN ExecutionResult.DataSet Do
				If Not DigitallySignedData.Property("SignatureProperties") Then
					Continue;
				EndIf;
				EDKindsArray.Add(DigitallySignedData.Object);
			EndDo;
		EndIf;
		
	EndIf;
	
	If InputStructure.Property("StructuStructuresEDArraysAndCertificates", StructuStructuresEDArraysAndCertificates)
		AND StructuStructuresEDArraysAndCertificates.Count() > 0 Then
		
		AccordanceOfEdAndSignatures = Undefined;
		If Not (Parameters.Property("AccordanceOfEdAndSignatures", AccordanceOfEdAndSignatures)
			OR TypeOf(AccordanceOfEdAndSignatures) = Type("Map")) Then
			
			Parameters.Insert("AccordanceOfEdAndSignatures", New Map);
		EndIf;
		
		For Each Item IN StructuStructuresEDArraysAndCertificates Do
			
			Structure = Item.Value;
			StructuStructuresEDArraysAndCertificates.Delete(Item.Key);
			
			CertificatesArray = Structure.CertificatesArray;
			DescriptionSignED = New NotifyDescription("SignED", ThisObject, Parameters);
			DataForSpecProcessor = Undefined;
			MatchEDAndDD = Undefined;
			If Structure.Property("MatchEDAndDD", MatchEDAndDD)
				AND TypeOf(MatchEDAndDD) = Type("Map") Then
				
				If MatchEDAndDD.Count() = 1 Then
					Operation = NStr("en='Electronic document signing';ru='Подписание электронного документа'");
				Else
					Operation = NStr("en='Electronic documents signing';ru='Подписание электронных документов'");
				EndIf;
				
				DataDescription = New Structure;
				DataDescription.Insert("Operation",            Operation);
				DataDescription.Insert("FilterCertificates",   CertificatesArray);
				DataDescription.Insert("ShowComment", False);
				DataDescription.Insert("DataSet",         New Array);
				DataDescription.Insert("DataTitle",     NStr("en='Document';ru='документ'"));
				DataDescription.Insert("WithoutConfirmation",    True);
				
				DataSet = DataDescription.DataSet;
				EDArrayForPresentation = New Array;
				For Each DataItem IN MatchEDAndDD Do
					ED = DataItem.Key;
					Data = New Structure;
					If DataItem.Value = Undefined OR Not IsTempStorageURL(DataItem.Value) Then
						ParametersForReceivingDD = New Structure("ED, DataDescription", ED, DataDescription);
						RefOnDD = New NotifyDescription("GetBinaryDataForED", ThisObject, ParametersForReceivingDD);
					Else
						RefOnDD = DataItem.Value;
					EndIf;
					Data.Insert("Data", RefOnDD);
					Data.Insert("Object", ED);
					
					DataSet.Add(Data);
					EDArrayForPresentation.Add(ED);
				EndDo;
				
				If EDArrayForPresentation.Count() = 1 Then
					EDPresentation = ElectronicDocumentsServiceCallServer.EDPresentation(EDArrayForPresentation[0]);
					DataSet[0].Insert("Presentation", EDPresentation);
				Else
					EDPresentation = NStr("en='Electronic documents (%1)';ru='Электронные документы (%1)'");
					EDPresentation = StrReplace(EDPresentation, "%1", EDArrayForPresentation.Count());
					EDPresentation = CommonUseClientServer.ReplaceProhibitedCharsInFileName(EDPresentation);
					EDPresentationsList = ElectronicDocumentsServiceCallServer.EDPresentationsList(EDArrayForPresentation);
					DataDescription.Insert("PresentationsList", EDPresentationsList);
					DataDescription.Insert("SetPresentation", EDPresentation);
				EndIf;
				
				DigitalSignatureClient.Sign(DataDescription, , DescriptionSignED);
			ElsIf Structure.Property("DataForSpecProcessor", DataForSpecProcessor)
				AND TypeOf(DataForSpecProcessor) = Type("Map") Then
				
				Structure.Insert("ContinuationHandler", DescriptionSignED);
				Structure.Insert("AccCertificatesAndTheirStructures", Parameters.AccCertificatesAndTheirStructures);
				StartSigningBankingED(Structure);
			Else
				SignED(, Parameters);
			EndIf;
			Break;
		EndDo;
	Else
		
		ActionsAfterSigningED(Parameters);
		
	EndIf;
	
EndProcedure

Procedure ActionsAfterSigningED(Parameters)
	
	EDArrayForStatusUpdate = Undefined;
	If TypeOf(Parameters) = Type("Structure")
		AND Parameters.Property("EDArrayForStatusUpdate", EDArrayForStatusUpdate)
		AND TypeOf(EDArrayForStatusUpdate) = Type("Array") Then
		
		ElectronicDocumentsServiceCallServer.ActionsAfterSigningEDOnServer(EDArrayForStatusUpdate);
		
		For Each ED IN EDArrayForStatusUpdate Do
			DetermineSignaturesStatuses(ED);
		EndDo;
	EndIf;
	
	EDSending(Parameters);
	
EndProcedure

Procedure StartSigningBankingED(Structure)
	
	AccCertificatesAndTheirStructures = Undefined;
	CertificatesArray = Undefined;
	DataForSpecProcessor = Undefined;
	DescriptionSignED = Undefined;
	Structure.Property("ContinuationHandler", DescriptionSignED);
	If Structure.Property("AccCertificatesAndTheirStructures", AccCertificatesAndTheirStructures)
		AND TypeOf(AccCertificatesAndTheirStructures) = Type("Map")
		AND Structure.Property("CertificatesArray", CertificatesArray)
		AND TypeOf(CertificatesArray) = Type("Array")
		AND Structure.Property("DataForSpecProcessor", DataForSpecProcessor)
		AND TypeOf(DataForSpecProcessor) = Type("Map") Then
		
		Map = New Map;
		For Each Certificate IN CertificatesArray Do
			ValidateCertificateValidityPeriod(Certificate);
			CertificateParameters = AccCertificatesAndTheirStructures.Get(Certificate);
			If TypeOf(CertificateParameters) = Type("Structure") Then
				Map.Insert(Certificate, CertificateParameters);
			EndIf;
		EndDo;
		
		EDArrayForSignature = New Array;
		OperationKind = NStr("en='Electronic documents signing';ru='Подписание электронных документов'");
		// DataForSpecProcessor - Map:
		//   Key     - BankApplicationm.
		//   Value - Map:
		//     Key     - EDAgreement.
		//     Value - EDArray.
		// As this match is generated in terms of signature certificate, then it is definite:
		// array of signature certificates for 1 bank application and
		// 1 ED agreement (in each regarded match one item at most):
		For Each KeyAndValue IN DataForSpecProcessor Do
			Structure.Insert("BankApplication", KeyAndValue.Key);
			For Each AgreementAndED IN KeyAndValue.Value Do
				Structure.Insert("EDAgreement", AgreementAndED.Key);
				For Each ED IN AgreementAndED.Value Do
					EDArrayForSignature.Add(ED);
				EndDo;
			EndDo;
		EndDo;
		CallNotification = New NotifyDescription("ContinueSigningBankED", ThisObject, Structure);
		Structure.Insert("CallNotification", CallNotification);
		Structure.Insert("EDArrayForSignature", EDArrayForSignature);
		GetPasswordToSertificate(Map, OperationKind, EDArrayForSignature, False, Structure);
	ElsIf TypeOf(DescriptionSignED) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(DescriptionSignED);
	EndIf;
	
EndProcedure

// Called from GetPasswordToCertificate to execute notification description.
//
// Parameters:
//    Result - Structure - the result of signature certificate selection and password input for it:
//       SelectedCertificate - CatalogRef.DigitalSignatureAndEncryptionKeyCertificates.
//       UserPassword  - String - password to certificate.
//    Parameters - Structure:
//       AccCertificatesAndTheirStructures - Matching.
//       BankApplication               - EnumRef.BankApplications.
//       ContinuationHandler        - NotifyDescription - description
//                                    that must be executed after completion of data processor of current ED.
//
Procedure ContinueSigningBankED(Result, Parameters) Export
	
	SelectedCertificate = Undefined;
	DescriptionSignED = Undefined;
	BreakProcessing = True;
	If TypeOf(Result) = Type("Structure") AND Result.Property("SelectedCertificate", SelectedCertificate)
		AND TypeOf(SelectedCertificate) = Type("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates") Then
		
		CertificateParameters = Parameters.AccCertificatesAndTheirStructures[SelectedCertificate];
		CertificateParameters.Insert("PasswordReceived", True);
		CertificateParameters.Insert("UserPassword", Result.UserPassword);
		CertificateParameters.Insert("SelectedCertificate", SelectedCertificate);
		CertificateParameters.Insert("Comment", Result.Comment);
		Parameters.Insert("CertificateStructure", CertificateParameters);
		
		If Parameters.BankApplication = PredefinedValue("Enum.BankApplications.SberbankOnline") Then
			Parameters.Insert("ProcessedEDAgreementsArray", New Array);
			Parameters.Insert("SendForSigningAfterProcessing");
			//StartSigningSberbankED(MapItem.Value, Parameters);
			BreakProcessing = False;
		ElsIf Parameters.BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
			HandlerAfterConnecting = New NotifyDescription("CheckNeedToSetPinCode",
				ThisObject, Parameters);
			Structure = New Structure;
			Structure.Insert("RunTryReceivingModule", False);
			Structure.Insert("AfterObtainingDataProcessorModule", HandlerAfterConnecting);
			Structure.Insert("EDAgreement", Parameters.EDAgreement);
			// If you manage to get external module, DataProcessorIfSuccess handler will be executed.
			// Otherwise, it will return to signing of other ED (DataProcessorIfFailure).
			GetExternalModuleThroughAdditionalProcessing(Structure);
			BreakProcessing = False;
		ElsIf Parameters.BankApplication = PredefinedValue("Enum.BankApplications.iBank2") Then
			HandlerAfterConnecting = New NotifyDescription("StartSigningiBank2", ThisObject, Parameters);
			Parameters.Insert("HandlerAfterConnectingComponents", HandlerAfterConnecting);
			EnableExternalComponentiBank2(Parameters);
			BreakProcessing = False;
		EndIf;
	EndIf;
	
	If BreakProcessing AND Parameters.Property("ContinuationHandler", DescriptionSignED)
		AND TypeOf(DescriptionSignED) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(DescriptionSignED);
	EndIf;
	
EndProcedure

Procedure EDSending(Parameters) Export
	
	Result = Parameters.Result;
	EDArrayToBeDeletedFromSending = Parameters.EDArrayToBeDeletedFromSending;
	ServerAuthorizationPerform = Parameters.ServerAuthorizationPerform;
	ImmediateEDSending = Parameters.ImmediateEDSending;
	AccCertificatesAndTheirStructures = Parameters.AccCertificatesAndTheirStructures;
	AccAgreementsAndCertificatesOfAuthorization = Undefined;
	CorrAgreementsArraysAndEDForDispatch = Undefined;
	StructureToSend = Undefined;
	If Result.Property("StructureToSend", StructureToSend) Then
		Parameters.Insert("AccAgreementsAndStructuresOfCertificates", New Map);
		AccAgreementsAndStructuresOfCertificates = Parameters.AccAgreementsAndStructuresOfCertificates;
		If StructureToSend.Property("WithAuthorizationLoginPassword", CorrAgreementsArraysAndEDForDispatch)
			AND TypeOf(CorrAgreementsArraysAndEDForDispatch) = Type("Map")
			AND CorrAgreementsArraysAndEDForDispatch.Count() > 0 Then
			
			Parameters.Insert("CurrentIndexForEDSendingToBankWithAuthorizationLoginPassword", 0);
			StartSendingEDToBankWithAuthorizationLoginPassword(Undefined, Parameters);
		Else
			EDKindsArray = Undefined;
			If StructureToSend.Property("WithoutSignatures", EDKindsArray) AND TypeOf(EDKindsArray) = Type("Array")
				AND EDKindsArray.Count() > 0 Then
				
				Parameters.Insert("ArrayToBeSentWithoutSignature", EDKindsArray);
			EndIf;
			
			If StructureToSend.Property("WithSignature", EDKindsArray) AND TypeOf(EDKindsArray) = Type("Array") Then
				If EDArrayToBeDeletedFromSending.Count() > 0 AND EDKindsArray.Count() > 0 Then
					For Each DeletedED IN EDArrayToBeDeletedFromSending Do
						CurIndex = EDKindsArray.Find(DeletedED);
						If CurIndex <> Undefined Then
							EDKindsArray.Delete(CurIndex);
						EndIf;
					EndDo;
				EndIf;
			Else
				EDKindsArray = New Array;
			EndIf;
			
			Parameters.Insert("ArrayToBeSent", EDKindsArray);
			ArrayToBeSent = Parameters.ArrayToBeSent;
			
			If Not (Result.Property("AccAgreementsAndCertificatesOfAuthorization", AccAgreementsAndCertificatesOfAuthorization)
				AND TypeOf(AccAgreementsAndCertificatesOfAuthorization) = Type("Map")) Then
				AccAgreementsAndCertificatesOfAuthorization = New Map;
			EndIf;
			
			DecryptMarker = False;
			If StructureToSend.Property("WithAuthorization", CorrAgreementsArraysAndEDForDispatch)
				AND TypeOf(CorrAgreementsArraysAndEDForDispatch) = Type("Map") Then
				For Each CurItm IN CorrAgreementsArraysAndEDForDispatch Do
					EDAgreement = CurItm.Key;
					ThereIsEDForSending = False;
					For Each SentED IN CurItm.Value Do
						If EDArrayToBeDeletedFromSending.Find(SentED) = Undefined Then
							ArrayToBeSent.Add(SentED);
							ThereIsEDForSending = True;
						EndIf;
					EndDo;
					If ThereIsEDForSending Then
						CertificatesArray = AccAgreementsAndCertificatesOfAuthorization.Get(EDAgreement);
						If ImmediateEDSending AND ValueIsFilled(CertificatesArray) Then
							// ED array for sending via OEDF can only come to the client
							// if there was no possibility to send these ED from the server (no password for certificate)
							ThereIsMarker = False;
							For Each Certificate IN CertificatesArray Do
								CertificateStructure = AccCertificatesAndTheirStructures.Get(Certificate);
								MarkerTranscribed = Undefined;
								If CertificateStructure.Property("MarkerTranscribed", MarkerTranscribed)
									AND ValueIsFilled(MarkerTranscribed) Then
									
									AccAgreementsAndStructuresOfCertificates.Insert(EDAgreement, CertificateStructure);
									ThereIsMarker = True;
									Break;
								EndIf;
							EndDo;
							If Not ThereIsMarker Then
								// Sending will be continued after decryption of markers.
								DecryptMarker = True;
							EndIf;
						EndIf;
					EndIf;
				EndDo;
			EndIf;
			
			If DecryptMarker Then
				NotificationHandler = New NotifyDescription("ContinueSendingEDAfterMarkerDecryption", ThisObject, Parameters);
				ID_Parameters = String(New UUID);
				ApplicationParameters.Insert("ElectronicInteraction." + ID_Parameters, Parameters);
				AdditParameters = New Structure;
				AdditParameters.Insert("ID_Parameters", ID_Parameters);
				AdditParameters.Insert("NotificationHandler", NotificationHandler);
				AdditParameters.Insert("AgreementsAndCertificatesCorrespondence", AccAgreementsAndCertificatesOfAuthorization);
				
				DecryptMarker(, AdditParameters);
			Else
				CompleteSendingED(Undefined, Parameters);
			EndIf;
		EndIf;
	Else
		ExecuteActionsAfterSending(Parameters);
	EndIf;
	
EndProcedure

// Called from procedure DecryptMarker() according to execution
// of Alert Description created in procedure EDSending(Parameters).
//
// Parameters:
//   Result - Structure:
//               ProfilesAndCertificatesParametersMatch - Map:
//                                   Key     - CatalogRef.EDFSettingsParameters.
//                                   Value - Structure:
//                                              MarkerTranscribed - BinaryData - decrypted marker.
//                                              other certificate attributes (optional).
//
//   Parameters - Structure:
//               AccAgreementsAndStructuresOfCertificates - Map
//                                                      key     - CatalogRef.EDFSettingsParameters.
//                                                      Value - Structure - Certificate parameters.
//               ArrayToBeSent - Array - ED prepared for sending.
//
Procedure ContinueSendingEDAfterMarkerDecryption(Result, Parameters) Export
	
	AccAgreementsAndStructuresOfCertificates = Undefined;
	If Not (Parameters.Property("AccAgreementsAndStructuresOfCertificates", AccAgreementsAndStructuresOfCertificates)
			 AND TypeOf(AccAgreementsAndStructuresOfCertificates) = Type("Map")) Then
		
		Parameters.Insert("AccAgreementsAndStructuresOfCertificates", New Map);
		AccAgreementsAndStructuresOfCertificates = Parameters.AccAgreementsAndStructuresOfCertificates;
	EndIf;
	
	ReturnAccordance = Undefined;
	If TypeOf(Result) = Type("Structure")
		AND Result.Property("ProfilesAndCertificatesParametersMatch", ReturnAccordance)
		AND TypeOf(ReturnAccordance) = Type("Map") Then
		
		For Each KeyAndValue IN ReturnAccordance Do
			AccAgreementsAndStructuresOfCertificates.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
	EndIf;
	
	CompleteSendingED(Undefined, Parameters);
	
EndProcedure

// Handles the results of ED sending iterations, when necessary (in incoming
// parameters there are ED which were not sent) starts the next ED sending iteration.
//
// Parameters:
//    Result - Structure, Undefined - the result of previous ED sending iteration is returned in the structure:
//       PreparedCnt - Number.
//       SentCnt   - Number.
//    Parameters - Structure:
//    ArrayToBeSent           - Array.
//    ArrayToBeSentWithoutSignature - Array.
//    Other parameters.
//
Procedure CompleteSendingED(Result, Parameters) Export
	
	AccAgreementsAndStructuresOfCertificates = Parameters.AccAgreementsAndStructuresOfCertificates;
	ContinueExecuteActionsAfterSending = True;
	If TypeOf(Result) = Type("Structure") Then
		PreparedCnt = 0;
		SentCnt = 0;
		If Not(Result.Property("PreparedCnt", PreparedCnt)
				AND TypeOf(PreparedCnt) = Type("Number")) Then
			
			PreparedCnt = 0;
		EndIf;
		If Not(Result.Property("SentCnt", SentCnt)
				AND TypeOf(SentCnt) = Type("Number")) Then
			
			SentCnt = 0;
		EndIf;
		Parameters.TotalPreparedCnt = Parameters.TotalPreparedCnt + PreparedCnt;
		Parameters.TotalSentCnt = Parameters.TotalSentCnt + SentCnt;
	EndIf;
	
	EDKindsArray = Undefined;
	ArrayToBeSent = Undefined;
	ArrayToBeSentWithoutSignature = Undefined;
	If Parameters.Property("ArrayToBeSent", ArrayToBeSent)
		AND TypeOf(ArrayToBeSent) = Type("Array")
		AND ArrayToBeSent.Count() > 0 Then
		
		EDKindsArray = ArrayToBeSent;
		Parameters.Delete("ArrayToBeSent");
		SignatureSign = True;
	ElsIf Parameters.Property("ArrayToBeSentWithoutSignature", ArrayToBeSentWithoutSignature)
		AND TypeOf(ArrayToBeSentWithoutSignature) = Type("Array")
		AND ArrayToBeSentWithoutSignature.Count() > 0 Then
		
		EDKindsArray = ArrayToBeSentWithoutSignature;
		Parameters.Delete("ArrayToBeSentWithoutSignature");
		SignatureSign = False;
	EndIf;
	
	If EDKindsArray <> Undefined Then
		NotifyDescription = New NotifyDescription("CompleteSendingED", ThisObject, Parameters);
		PrepareAndSendPED(EDKindsArray, SignatureSign, AccAgreementsAndStructuresOfCertificates, Parameters, NotifyDescription);
		ContinueExecuteActionsAfterSending = False;
	EndIf;
	
	If ContinueExecuteActionsAfterSending Then
		ExecuteActionsAfterSending(Parameters);
	EndIf;
	
EndProcedure

Procedure StartSendingEDToBankWithAuthorizationLoginPassword(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		// Call after execution of PrepareAndSendEDP method(...).
		PreparedCnt = 0;
		SentCnt = 0;
		If Result.Property("PreparedCnt", PreparedCnt) AND TypeOf(PreparedCnt) = Type("Number") Then
			//
			Parameters.TotalPreparedCnt = Parameters.TotalPreparedCnt + PreparedCnt;
		EndIf;
		If Result.Property("SentCnt", SentCnt) AND TypeOf(SentCnt) = Type("Number") Then
			//
			Parameters.TotalSentCnt = Parameters.TotalSentCnt + SentCnt;
		EndIf;
	EndIf;
	StructureToSend = Parameters.Result.StructureToSend;
	CorrAgreementsArraysAndEDForDispatch = StructureToSend.WithAuthorizationLoginPassword;
	ImmediateEDSending = Parameters.ImmediateEDSending;
	AccAgreementsAndStructuresOfCertificates = Parameters.AccAgreementsAndStructuresOfCertificates;
	
	ArrayToBeSentWithoutSignature = New Array;
	CurrentIndex = 0;
	For Each CurItm IN CorrAgreementsArraysAndEDForDispatch Do
		CurrentIndex = CurrentIndex + 1;
		If CurrentIndex <= Parameters.CurrentIndexForEDSendingToBankWithAuthorizationLoginPassword Then
			Continue;
		EndIf;
		Parameters.CurrentIndexForEDSendingToBankWithAuthorizationLoginPassword = CurrentIndex;

		EDAgreement = CurItm.Key;
		If ImmediateEDSending Then
			Parameters.Insert("EDAgreement", EDAgreement);
			Parameters.Insert("EDArrayForSendingToBankWithAuthorizationLoginPassword", CurItm.Value);
			AuthorizationParameters = Undefined;
			If ReceivedAuthorizationData(CurItm.Key, AuthorizationParameters) Then
				SendEDToBankWithAuthenticationLoginPassword(AuthorizationParameters, Parameters);
			Else
				OOOZ = New NotifyDescription("SendEDToBankWithAuthenticationLoginPassword", ThisObject, Parameters);
				GetAuthenticationData(CurItm.Key, OOOZ);
				Return;
			EndIf;
		Else
			CommonUseClientServer.SupplementArray(ArrayToBeSentWithoutSignature, CurItm.Value);
		EndIf;
	EndDo;
	If ArrayToBeSentWithoutSignature.Count() > 0 Then
		NotifyDescription = New NotifyDescription("CompleteSendingED", ThisObject, Parameters);
		PrepareAndSendPED(ArrayToBeSentWithoutSignature, False, AccAgreementsAndStructuresOfCertificates,, NotifyDescription);
	Else
		CompleteSendingED(Undefined, Parameters);
	EndIf;
	
EndProcedure

Procedure ExecuteActionsAfterSending(Parameters)
	
	Var Action, CountTotalNewED, TotalNumberOfConfirmedED, TotalDigitallySignedCnt, TotalPreparedCnt, TotalSentCnt;
	
	If Not Parameters.Property("CountTotalNewED", CountTotalNewED) Then
		CountTotalNewED = 0;
	EndIf;
	If Not Parameters.Property("TotalNumberOfConfirmedED", TotalNumberOfConfirmedED) Then
		TotalNumberOfConfirmedED = 0;
	EndIf;
	If Not Parameters.Property("TotalDigitallySignedCnt", TotalDigitallySignedCnt) Then
		TotalDigitallySignedCnt = 0;
	EndIf;
	If Not Parameters.Property("TotalPreparedCnt", TotalPreparedCnt) Then
		TotalPreparedCnt = 0;
	EndIf;
	If Not Parameters.Property("TotalSentCnt", TotalSentCnt) Then
		TotalSentCnt = 0;
	EndIf;

	Notify("RefreshStateED");

	If Parameters.Property("Action")
		AND ElectronicDocumentsClientServer.IsAction(Parameters.Action, "Show") Then
		Result = Parameters.Result;
		ProcessingArray = "";
		If Result.Property("NewEDArray", ProcessingArray) AND ProcessingArray <> Undefined Then
			For Each CurItm IN ProcessingArray Do
				OpenEDForViewing(CurItm);
			EndDo;
		EndIf;
	EndIf;
	
	If Not Parameters.Property("DoNotDisplayInformationAboutProcessedED") Then
		OutputInformationAboutProcessedED(
			CountTotalNewED, TotalNumberOfConfirmedED, TotalDigitallySignedCnt, TotalPreparedCnt, TotalSentCnt);
	EndIf;
	
	
	TotallyProcessed = CountTotalNewED + TotalNumberOfConfirmedED + TotalDigitallySignedCnt + TotalPreparedCnt
					+ TotalSentCnt;
	
	If Parameters.Property("NotifyAboutCreatingNotifications") AND TotallyProcessed > 0 Then
		Notify("NotificationCreated", Parameters.NotifyAboutCreatingNotifications);
	EndIf;
	
	NotifyDescription = Undefined;
	If Parameters.Property("NotifyDescription", NotifyDescription)
		AND TypeOf(NOTifyDescription) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(NOTifyDescription, (TotallyProcessed > 0));
	EndIf;
	
EndProcedure

Procedure PreparePackagesForSending(Parameters)
	
	If Not Parameters.Property("PackagesEnumerationIndex") Then
		Parameters.Insert("PackagesEnumerationIndex", 0);
	EndIf;
	
	If Not Parameters.Property("PackagesEnumerationIndex") Then
		Parameters.Insert("DataEnumerationIndex", -1);
	EndIf;
	
	If Parameters.AccordanceDataPackages.Count() > Parameters.PackagesEnumerationIndex Then
		PackageCurIndex = -1;
		// Determine current processed package
		For Each KeyValue IN Parameters.AccordanceDataPackages Do
			PackageCurIndex = PackageCurIndex + 1;
			If PackageCurIndex = Parameters.PackagesEnumerationIndex Then
				Break;
			EndIf;
		EndDo;
		
		EDDataArray = KeyValue.Value;
		
		If Parameters.DataEnumerationIndex + 1 < EDDataArray.Count() Then
			Parameters.DataEnumerationIndex = Parameters.DataEnumerationIndex + 1;
			
			EDData = EDDataArray[Parameters.DataEnumerationIndex];
			
			If EDData.IsConfirmationSending Then
				PreparePackagesForSending(Parameters);
			EndIf;
					
			EncryptionParameters = EDData.EncryptionParameters;
			If EncryptionParameters = Undefined Then
				PreparePackagesForSending(Parameters);
			EndIf;
					
			CertificatesArray = New Array;
			For Each StringCertificate IN EncryptionParameters Do
				CertificateBinaryData = GetFromTempStorage(StringCertificate);
				Certificate = New CryptoCertificate(CertificateBinaryData);
				CertificatesArray.Add(Certificate);
			EndDo;
			NotEncryptedData = GetFromTempStorage(EDData.FileData.FileBinaryDataRef);
			
			Notification = New NotifyDescription("AfterEncryptionCreateEDPackage", ThisObject, Parameters);
			
			Try
				Parameters.CryptoManager.StartEncryption(Notification, NotEncryptedData, CertificatesArray);
			Except
				OperationKind = NStr("en='Data encryption';ru='Шифрование данных'");
				MessageText = NStr("An error occurred when encrypting data: %1");
				BriefErrorDescription = BriefErrorDescription(ErrorDescription());
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
												MessageText, BriefErrorDescription);
				DetailErrorDescription = DetailErrorDescription(ErrorInfo());
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
								OperationKind, DetailErrorDescription, MessageText, 0);
				PreparePackagesForSending(Parameters);
			EndTry
			
		Else
			Parameters.DataEnumerationIndex = -1;
			Parameters.PackagesEnumerationIndex = Parameters.PackagesEnumerationIndex + 1; // go to next package processor
			PreparePackagesForSending(Parameters);
		EndIf;
		Return
	EndIf;
	
	Parameters.Delete("PackagesEnumerationIndex");
	Parameters.Delete("DataEnumerationIndex");
	
	SentCnt = 0;
	ElectronicDocumentsServiceCallServer.SaveAndSendEncryptedData(
			Parameters.AccordanceDataPackages, Parameters.ProfilesAndCertificatesParametersMatch, SentCnt);
	Parameters.EDPSendingResult.SentCnt = Parameters.EDPSendingResult.SentCnt + SentCnt;
	
	ExecuteActionsAfterSendingEDPComplete(Parameters);
	
EndProcedure

// Send and receive e-documents by one command.
Procedure SendReceiveElectronicDocuments() Export
	
	ClearMessages();
	
	#If ThickClientOrdinaryApplication Then
		If Not ElectronicDocumentsOverridable.IsRightToProcessED() Then
			MessageToUserAboutViolationOfRightOfAccess();
			Return;
		EndIf;
		If Not ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseEDExchange") Then
			MessageText = ElectronicDocumentsServiceCallServer.MessageTextAboutSystemSettingRequirement("WorkWithED");
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		EndIf;
	#EndIf
	
	
	AdditParameters = New Structure;
	
	NotificationProcessing = New NotifyDescription("SendGetEDExecute", ThisObject, AdditParameters);
	
	GetAgreementsAndCertificatesParametersMatch(NotificationProcessing);
	
EndProcedure

Procedure SendGetEDExecute(Result, AdditionalParameters) Export
	
	AccAgreementsAndStructuresOfCertificates = Undefined;
	If TypeOf(Result) <> Type("Structure")
		OR Not Result.Property("ProfilesAndCertificatesParametersMatch", AccAgreementsAndStructuresOfCertificates) Then
		Return;
	EndIf;
	
	// Block of EDF settings statuses update and receipt of new invitations.
	MessageText = NStr("en='Receiving information about invitations. Please wait...';ru='Выполняется получение информации о приглашениях. Пожалуйста, подождите..'");
	Status(NStr("en='Get.';ru='Получить.'"), , MessageText);
	ElectronicDocumentsServiceCallServer.UpdateEDFSettingsConnectionStatuses(AccAgreementsAndStructuresOfCertificates);
	
	// Block of ED sending and receiving.
	MessageText = NStr("en='Sending and receiving packages of electronic documents in progress. Please wait...';ru='Выполняется отправка и получение пакетов электронных документов. Пожалуйста, подождите..'");
	Status(NStr("en='Send and get.';ru='Отправка и получение.'"), , MessageText);
	
	// Receiving and sending the documents.
	
	RequiredToRetryReceipt = False;
	ReturnStructure = ElectronicDocumentsServiceCallServer.SendAndReceiveDocuments(
		AccAgreementsAndStructuresOfCertificates,
		RequiredToRetryReceipt);

	NewDocuments = ReturnStructure.NewDocuments;
	ReturnStructure.Insert("NewEDCount", NewDocuments.ReturnArray.Count());
	
	If NewDocuments.UnpackingParameters.Count() > 0 Then
		// Unpack received packages with electronic documents.
		MessageText = NStr("en='Packages of electronic documents are being unpacked. Please wait...';ru='Выполняется распаковка пакетов электронных документов. Пожалуйста, подождите..'");
		Status(NStr("en='Unboxing.';ru='Распаковка.'"), , MessageText);
		NotifyDescription = New NotifyDescription("SendGetEDComplete", ThisObject, ReturnStructure);
		NewDocuments.Insert("ContinuationHandler", NotifyDescription);
		NewDocuments.Insert("TotalUnpacked", 0);
		
		Notification = New NotifyDescription("UnpackEDPackagesArrayContinue", ThisObject, NewDocuments);
		DigitalSignatureClient.CreateCryptoManager(Notification, "GetCertificates", False);
	Else
		SendGetEDComplete(Result, ReturnStructure);
	EndIf;
	
	// If the use of marker exceeds 5 minutes, it shall be received again.
	If RequiredToRetryReceipt Then
		SendReceiveElectronicDocuments();
	EndIf;
	
EndProcedure

Procedure UnpackEDPackagesArrayContinue(Result, EDPackagesStructure) Export
	
	IsCryptofacilityOnClient = TypeOf(Result) = Type("CryptoManager");
	ApplicationParameters.Insert("ElectronicInteraction.ThereIsCryptofacilityOnClient", IsCryptofacilityOnClient);
	HandleNextEDPackage(, EDPackagesStructure);
	
EndProcedure

// Called from SendGetEDExecute and according to the description of notification, from HandleNextEDPackage.
// Displays a notification of the results of sending, receiving and unpacking of EDP to a user.
//
// Parameters:
//    Result - Number, Undefined - number of unpacked EDP.
//    Parameters - Structure - results of sending and receiving EDP.
//
Procedure SendGetEDComplete(Result, Parameters) Export
	
	// Prepare message display for user on sending/receiving ED packages.
	SentPackagesCnt = Parameters.SentPackagesCnt;
	NewEDCount = Parameters.NewEDCount;
	NotificationTemplate = NStr("en='Packages sent: (%1), packages received: (%2).';ru='Отправлено пакетов: (%1), получено пакетов: (%2).'");
	NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(NotificationTemplate,
		SentPackagesCnt, NewEDCount);
	If TypeOf(Result) = Type("Number") Then
		NotificationText = NotificationText + Chars.LF + NStr("en='Unpacked packages: %1.';ru='Распаковано пакетов: %1.'");
		NotificationText = StrReplace(NotificationText, "%1", Result);
	EndIf;
	Notify("RefreshStateED");
	
	NotificationTitle = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
	ShowUserNotification(NotificationTitle, , NotificationText);
	
EndProcedure

Procedure HandleNextEDPackage(Result, EDPackagesStructure) Export
	
	If TypeOf(Result) = Type("Number") Then
		EDPackagesStructure.TotalUnpacked = EDPackagesStructure.TotalUnpacked + Result;
	EndIf;
	Complete = True;
	If TypeOf(EDPackagesStructure) = Type("Structure") Then
		UnpackingParameters = Undefined;
		If EDPackagesStructure.Property("UnpackingParameters", UnpackingParameters)
			AND TypeOf(UnpackingParameters) = Type("Array") AND UnpackingParameters.Count() > 0 Then
			
			// As packages are unpacked asynchronously, take one item from the array
			// of parameters, unpack it and remove from the array. The result of unpacking is added to EDParametersStructure:
			UnpackingStructure = UnpackingParameters[0];
			UnpackingParameters.Delete(0);
			EncryptionStructure = Undefined;
			
			NotifyDescription = New NotifyDescription("HandleNextEDPackage", ThisObject, EDPackagesStructure);
			
			If UnpackingStructure.Property("EDExchangeMethod") Then
				ReturnData = New Structure("DSData");
				Complete = False;
				UnpackBankEDPackageOnClient(UnpackingStructure.EDPackage, ReturnData, NotifyDescription);
			Else
				UnpackingData = Undefined;
				If Not UnpackingStructure.Property("UnpackingData", UnpackingData)
					OR TypeOf(UnpackingData) <> Type("Structure") Then
					UnpackingData = ElectronicDocumentsServiceCallServer.ReturnArrayBinaryDataPackage(
																						UnpackingStructure.EDPackage);
				EndIf;
				
				If TypeOf(UnpackingData) = Type("Structure") Then
					
					PropertyName = "ElectronicInteraction.ThereIsCryptofacilityOnClient";
					IsCryptofacilityOnClient = ApplicationParameters.Get(PropertyName);
					If TypeOf(IsCryptofacilityOnClient) <> Type("Boolean") Then
						IsCryptofacilityOnClient = False;
					EndIf;

					AdditParameters = New Structure;
					AdditParameters.Insert("EDPackage", UnpackingStructure.EDPackage);
					AdditParameters.Insert("ContinuationHandler", NotifyDescription);
					AdditParameters.Insert("IsCryptofacilityOnClient", IsCryptofacilityOnClient);
					AdditParameters.Insert("DataType", Undefined);
					If UnpackingStructure.Property("EncryptionStructure", EncryptionStructure)
						AND TypeOf(EncryptionStructure) = Type("Structure") Then
						
						AdditParameters.Insert("Certificate", EncryptionStructure.Certificate);
						AdditParameters.Insert("UnpackingData", New Array);
						AdditParameters.Insert("EncryptedUnpackingData", UnpackingData);
						DecryptEDData(, AdditParameters)
					Else
						AdditParameters.Insert("UnpackingData", UnpackingData);
						DataType = AdditParameters.DataType;
						If UnpackingData.Property("DataType", DataType) AND DataType <> "ED" AND DataType <> "Signature" Then
							HandleReceivedServiceED(AdditParameters);
						Else
							HandleEDPackageDataOnClient(AdditParameters);
						EndIf;
					EndIf;
				Else
					HandleNextEDPackage(Undefined, EDPackagesStructure);
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	If Complete Then
		ContinuationHandler = Undefined;
		If EDPackagesStructure.Property("ContinuationHandler", ContinuationHandler)
			AND TypeOf(ContinuationHandler) = Type("NotifyDescription") Then
			
			ExecuteNotifyProcessing(ContinuationHandler, EDPackagesStructure.TotalUnpacked);
		Else
			InformEDPackagesUnpackingResults(EDPackagesStructure.TotalUnpacked);
		EndIf;
	EndIf;
	
EndProcedure

// Called from HandleNextEDPackage and, according to the description of the notification, from DigitalSignatureClient.Decrypt
//
Procedure DecryptEDData(Result, AdditionalParameters) Export
	
	UnpackingData = AdditionalParameters.UnpackingData;
	// As a result decrypted marker data arrive, put it to ReturnMatch:
	If TypeOf(Result) = Type("Structure") Then
		DecryptedData = Undefined;
		ProcessedStructure = Undefined;
		If Result.Property("DecryptedData", DecryptedData)
			AND TypeOf(DecryptedData) = Type("BinaryData")
			AND AdditionalParameters.Property("ProcessedStructure", ProcessedStructure) Then
			
			ProcessedStructure.BinaryData = DecryptedData;
			UnpackingData.StructureOfBinaryData.Add(ProcessedStructure);
		EndIf;
	EndIf;
	RunFinalAlertHandler = True;
	
	BinaryDataArray = AdditionalParameters.EncryptedUnpackingData;
	If BinaryDataArray.Count() > 0 Then
		DataStructure = BinaryDataArray[0];
		CertificatesArray = New Array;
		CertificatesArray.Add(AdditionalParameters.Certificate);
		
		DataDescription = New Structure;
		DataDescription.Insert("FilterCertificates", CertificatesArray);
		DataDescription.Insert("WithoutConfirmation",  True);
		DataDescription.Insert("ItIsAuthentication", False);
		DataDescription.Insert("Data", DataStructure.BinaryData);
		
		
		ProcessedStructure = New Structure("BinaryData, FileDescriptionWithoutExtension, FileName");
		FillPropertyValues(ProcessedStructure, DataStructure);
		AdditionalParameters.Insert("ProcessedStructure", ProcessedStructure);
		AdditionalParameters.Insert("DataDescription", DataDescription);
		
		// Delete processed item from the match:
		RunFinalAlertHandler = False;
		BinaryDataArray.Delete(0);
		NotifyDescription = New NotifyDescription("DecryptEDData", ThisObject, AdditionalParameters);
		DigitalSignatureClient.Decrypt(DataDescription, , NotifyDescription);
	EndIf;
	
	If RunFinalAlertHandler Then
		HandleEDPackageDataOnClient(AdditionalParameters);
	EndIf;
	
EndProcedure

// Called from HandleNextEDPackage and DecryptEDData
//
Procedure HandleEDPackageDataOnClient(Parameters)
	
	UnpackingData = Parameters.UnpackingData;
	NotificationsBinaryDataArray = UnpackingData.StructureOfBinaryDataAnnouncements;
	Parameters.Insert("TotalUnpacked", 0);

	If NotificationsBinaryDataArray.Count() > 0 Then
		Parameters.Insert("NotificationProcessingIndex", -1);
		Parameters.Delete("IncorrectSignature");
		HandleNextNotification(Parameters);
		Return;
	EndIf;

	AfterProcessingNotificationsProcessEDPackageData(Parameters);
	
EndProcedure

Procedure HandleNextNotification(Parameters) Export
	
	Parameters.NotificationProcessingIndex = Parameters.NotificationProcessingIndex + 1;
	UnpackingData = Parameters.UnpackingData;
	NotificationsBinaryDataArray = UnpackingData.StructureOfBinaryDataAnnouncements;
	If Parameters.NotificationProcessingIndex < NotificationsBinaryDataArray.Count() Then
		// Process notifications from
		// the operator It can be if we receive notifications from the customer about ESF receipt
		DataStructure = NotificationsBinaryDataArray[Parameters.NotificationProcessingIndex];
		SignsStructuresArray = ElectronicDocumentsServiceCallServer.GetSignaturesDataCorrespondence(
				DataStructure.FileName, UnpackingData.PackageFiles, DataStructure.BinaryData,
				UnpackingData.MapFileParameters, True);
			
		If SignsStructuresArray <> Undefined Then
			Parameters.Insert("DataStructure", DataStructure);
			Parameters.Insert("DataForCheckingES", SignsStructuresArray);
			Parameters.Insert("SignatureCheckIndex", -1);
			CheckDS(Undefined, Parameters);
			Return;
		EndIf;
	EndIf;
		
EndProcedure

Procedure HandleReceivedServiceED(Parameters) Export
	
	NotifyDescription               = Parameters.ContinuationHandler;
	UnpackingData                 = Parameters.UnpackingData;
	IsCryptofacilityOnClient      = Parameters.IsCryptofacilityOnClient;
	EDPackage                          = Parameters.EDPackage;
	PerformCryptoOperationsAtServer = ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer();
		
	ReturnStructure       = New Structure;
	AccordanceOfEdAndSignatures = New Map;
	ProcessedDocumentsCount = ElectronicDocumentsServiceCallServer.HandleBinaryDataPackageOperatorOfEDO(
						EDPackage, UnpackingData, IsCryptofacilityOnClient, AccordanceOfEdAndSignatures, ReturnStructure);
	AddedFilesArray             = ReturnStructure.AddedFilesArray;
	AddedFilesArrayForNotifications = ReturnStructure.AddedFilesArrayForNotifications;
	ArrayOfOwners                    = ReturnStructure.ArrayOfOwners;
	If TypeOf(AddedFilesArray) = Type("Array") AND AddedFilesArray.Count() > 0
		AND Not PerformCryptoOperationsAtServer Then
		
		If AccordanceOfEdAndSignatures.Count() > 0 Then
			EDAndSignaturesArray = New Array;
			For Each Item IN AccordanceOfEdAndSignatures Do
				For Each SignatureData IN Item.Value Do
					DataStructure = New Structure;
					DataStructure.Insert("ElectronicDocument", Item.Key);
					DataStructure.Insert("SignatureData", SignatureData);
					EDAndSignaturesArray.Add(DataStructure);
				EndDo;
			EndDo;
			AddInformationAboutSignature(EDAndSignaturesArray);
		EndIf;
	EndIf;
	
	If ProcessedDocumentsCount > 0 Then
		Notify("UpdateIBDocumentAfterFilling", ArrayOfOwners);
	EndIf;
	
	// ReceivedData from EDF operator
	If AddedFilesArrayForNotifications.Count() > 0 Then
		EDKind = PredefinedValue("Enum.EDKinds.NotificationAboutReception");
		GenerateSignServiceED(AddedFilesArrayForNotifications, EDKind, , , NotifyDescription);
	Else
		ExecuteNotifyProcessing(NOTifyDescription, ProcessedDocumentsCount);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// For internal use only
Procedure UnpackEDPackagesArray(ArrayPED) Export
	
	// Unpack received packages with electronic documents.
	MessageText = NStr("en='Packages of electronic documents are being unpacked. Please wait...';ru='Выполняется распаковка пакетов электронных документов. Пожалуйста, подождите..'");
	Status(NStr("en='Unboxing.';ru='Распаковка.'"), , MessageText);

	UnpackingParameters = ElectronicDocumentsServiceCallServer.DefineUnpackingParameters(ArrayPED);
	If UnpackingParameters = Undefined Then
		Return;
	EndIf;
	
	EDPackagesStructure = New Structure;
	EDPackagesStructure.Insert("UnpackingParameters", UnpackingParameters);
	EDPackagesStructure.Insert("TotalUnpacked", 0);
	
	Notification = New NotifyDescription("UnpackEDPackagesArrayContinue", ThisObject, EDPackagesStructure);
	DigitalSignatureClient.CreateCryptoManager(Notification, "GetCertificates", False);
	
EndProcedure

// Generates and outputs the message that can be connected to form managing item.
//
//  Parameters
//  MessageTextToUser - String - message type.
//  TargetID - UUID - to which form a message should be associated with
//
Procedure MessageToUser(MessageToUserText, TargetID);
	
	Message = New UserMessage;
	Message.Text = MessageToUserText;
	Message.TargetID = TargetID;
	Message.Message();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Unpacking ED packages (decryption, verification, signatures)

Procedure InformEDPackagesUnpackingResults(TotalUnpacked)
	
	If Not ValueIsFilled(TotalUnpacked) Then
		TotalUnpacked = 0;
	EndIf;
	
	NotificationTitle = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
	NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(
	NStr("en='Electronic documents unpacked: (%1)';ru='Распаковано электронных документов: (%1)'"), TotalUnpacked);
	ShowUserNotification(NotificationTitle, , NotificationText);
	
	Notify("RefreshStateED");
	
EndProcedure

#EndRegion

#Region CallsFromOverridableDSModules

// Called
// from DigitalSignatureOverridableClient, from the procedures of the same name which in
// turn are called from form CertificateCheck if additional checks were added during form creation.
//
// Parameters:
//  Parameters - Structure - with properties:
//  * WaitContituation   - Boolean - (return value) - if True, additional checking
//                             will occur asynchronously, the continuation will be resumed after an alert.
//                            Initial value is False.
//  * Alert           - NotifyDescription - data processor to call
//                              to continue after asynchronous execution of additional check.
//  * Certificate           - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - certificate being checked.
//  * Check             - String - name of the checking added
//                              in the OnCreateFormCertificateChecking procedure of the DigitalSignatureOverridable common module.
//  * CryptographyManager - CryptoManager - prepared cryptography
//                              manager to perform checking.
//  * ErrorDescription       - String - (return value) - description of an error received during checking.
//                              Users see this description after they click the result picture.
//  * IsWarning    - Boolean - (return value) - picture kind Error/Warning
// initial value False
//
Procedure OnAdditionalCertificateVerification(Parameters) Export
	
	// Authorization on Taxcom server
	If Parameters.Checking = "ConnectionTestWithOperator" Then
		ServerAuthorizationPerform = ElectronicDocumentsServiceCallServer.ServerAuthorizationPerform();
		If Not ServerAuthorizationPerform Then
			Parameters.WaitContinuation = True;
			Structure = New Structure;
			Structure.Insert("SignatureCertificate", Parameters.Certificate);
			EncryptedData = ElectronicDocumentsServiceCallServer.EncryptedMarker(Structure);
			// Details
			Notification = New NotifyDescription("AfterTheCompleteTestMarkerDetails", ThisObject, Parameters);
			Try
				DecryptedData = Parameters.CryptoManager.StartDecryption(Notification, EncryptedData);
			Except
				ErrorInfo = ErrorInfo();
				ErrorDescription = BriefErrorDescription(ErrorInfo);
				Parameters.WaitContinuation = False;
			EndTry;
		EndIf;
	EndIf;
	
EndProcedure
#EndRegion

#Region AsynchronousDialogsHandlers

Procedure EmptyProcessor(Result, AdditionalParameters = Undefined) Export
	
EndProcedure

Procedure AfterTheCompleteTestMarkerDetails(Result, Parameters) Export
	
	DigitalSignatureServiceClientServer.EmptyDecryptedData(Result, Parameters.ErrorDescription);
	ExecuteNotifyProcessing(Parameters.Notification);
	
EndProcedure

Procedure AfterEncryptionCreateEDPackage(EncryptedData, Parameters) Export

	PackageCurIndex = -1;
	For Each KeyValue IN Parameters.AccordanceDataPackages Do
		PackageCurIndex = PackageCurIndex + 1;
		If PackageCurIndex = Parameters.PackagesEnumerationIndex Then
			Break;
		EndIf;
	EndDo;

	EDDataArray = KeyValue.Value;
	EDData = EDDataArray[Parameters.DataEnumerationIndex];
	
	EDData.FileData.FileBinaryDataRef = PutToTempStorage(EncryptedData);
	
	PreparePackagesForSending(Parameters)
	
EndProcedure

Procedure GenerateNewEDDirectoryComplete(Val Result, Val AdditionalParameters) Export
	
	Company = Undefined;
	If ValueIsFilled(Result)
		AND TypeOf(AdditionalParameters) = Type("Structure")
		AND AdditionalParameters.Property("Company", Company) Then
		
		StructureDirectory = New Structure;
		StructureDirectory.Insert("Company", Company);
		StructureDirectory.Insert("ProductsDirectory", Result);
		Parameters = New Structure("StructureDirectory", StructureDirectory);
		OpenForm("DataProcessor.ElectronicDocuments.Form.EDExportFormToFile", Parameters);
	EndIf;
	
EndProcedure

Procedure GenerateSignSendDirectoryComplete(Val Result, Val AdditionalParameters) Export
	
	EDAgreement = Undefined;
	OpenEDForms = Undefined;
	If ValueIsFilled(Result)
		AND TypeOf(AdditionalParameters) = Type("Structure")
		AND AdditionalParameters.Property("AgreementAboutEDUsage", EDAgreement) Then
		
		ElectronicDocumentsServiceCallServer.SetEDNewVersion(EDAgreement);
		
		RefArray = ElectronicDocumentsServiceClient.GetParametersArray(EDAgreement);
		If RefArray = Undefined Then
			Return;
		EndIf;
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("ProductsDirectory", Result);
		
		ElectronicDocumentsServiceClient.ProcessED(RefArray, "GenerateConfirmSignSend",
			ParametersStructure);
		
		Notify("RefreshStateED");
		If AdditionalParameters.Property("OpenEDForms", OpenEDForms)
			AND OpenEDForms = True Then
			ElectronicDocumentsClient.OpenActualED(EDAgreement);
		EndIf;
	EndIf;
	
EndProcedure
	
Procedure GetEncryptedMarkerData(Result, AdditionalParameters) Export
	
	ID_Parameters = Undefined;
	If TypeOf(AdditionalParameters) = Type("Structure")
		AND AdditionalParameters.Property("ID_Parameters", ID_Parameters) Then
		
		// Parameters - Structure("AuthorizationCertificatesArrayAndAgreementsMatch, AccCertificatesAndTheirStructures, ReturnAccordance").
		// ReturnAccordance - parameter that is passed to the method
		// specified in notification processor (AditionalParameters.NotificationProcessing).
		AccCertificatesAndTheirStructures = Undefined;
		Parameters = ApplicationParameters["ElectronicInteraction." + ID_Parameters];
		If TypeOf(Parameters) = Type("Structure")
			AND Parameters.Property("AccCertificatesAndTheirStructures", AccCertificatesAndTheirStructures) Then
			
			// Result - structure - DataDescription that was
			// passed to method Decrypt() with parameter SelectedCertificate on SSL side:
			DataDescription = Undefined;
			SelectedCertificate = Undefined;
			If AdditionalParameters.Property("DataDescription", DataDescription)
				AND TypeOf(DataDescription) = Type("Structure")
				AND DataDescription.Property("SelectedCertificate", SelectedCertificate)
				AND TypeOf(SelectedCertificate) = Type("Structure")
				AND SelectedCertificate.Property("Ref", SelectedCertificate)
				AND AccCertificatesAndTheirStructures.Get(SelectedCertificate) <> Undefined Then
				
				CertificateParameters = Parameters.AccCertificatesAndTheirStructures[SelectedCertificate];
				CertificateParameters.Property("MarkerEncrypted", Result);
			EndIf;
		EndIf;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("Data", Result);
	ExecuteNotifyProcessing(Result.Notification, Parameters);
	
EndProcedure

Procedure DecryptMarker(Result, AdditionalParameters) Export
	
	ID_Parameters = Undefined;
	If TypeOf(AdditionalParameters) = Type("Structure")
		AND AdditionalParameters.Property("ID_Parameters", ID_Parameters) Then
		
		// Parameters - Structure("AuthorizationCertificatesArrayAndAgreementsMatch,
		//   AccCertificatesAndTheirStructures, ProfilesAndCertificatesParametersMatch").
		// ReturnAccordance - parameter that is passed to the method
		// specified in notification processor (AditionalParameters.NotificationProcessing).
		ReturnAccordance = Undefined;
		Parameters = ApplicationParameters["ElectronicInteraction." + ID_Parameters];
		If Not (TypeOf(Parameters) = Type("Structure")
			AND Parameters.Property("ProfilesAndCertificatesParametersMatch", ReturnAccordance)
			AND TypeOf(ReturnAccordance) = Type("Map")) Then
			
			Parameters.Insert("ProfilesAndCertificatesParametersMatch", New Map);
			ReturnAccordance = Parameters.ProfilesAndCertificatesParametersMatch;
		EndIf;
		
		// As a result decrypted marker data arrive, put it to ReturnMatch:
		If TypeOf(Result) = Type("Structure") Then
			Success = False;
			DecryptedData = Undefined;
			EDFProfileSettings = Undefined;
			If Result.Property("DecryptedData", DecryptedData) Then
				If IsTempStorageURL(DecryptedData) Then
					DecryptedData = GetFromTempStorage(DecryptedData);
				EndIf;
				If TypeOf(DecryptedData) = Type("BinaryData")
					AND AdditionalParameters.Property("EDFProfileSettings", EDFProfileSettings) Then
					
					SelectedCertificate = Undefined;
					If Result.Property("SelectedCertificate", SelectedCertificate)
						AND TypeOf(SelectedCertificate) = Type("Structure")
						AND SelectedCertificate.Property("Ref", SelectedCertificate)
						AND Parameters.AccCertificatesAndTheirStructures.Get(SelectedCertificate) <> Undefined Then
						
						CertificateParameters = Parameters.AccCertificatesAndTheirStructures[SelectedCertificate];
						CertificateParameters.Insert("MarkerTranscribed", DecryptedData);
						ReturnAccordance.Insert(EDFProfileSettings, CertificateParameters);
					Else
						ReturnAccordance.Insert(EDFProfileSettings, New Structure("MarkerTranscribed", DecryptedData));
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		RunFinalAlertHandler = True;
		NotificationHandler = Undefined;
		AgreementsAndCertificatesCorrespondence = Undefined;
		If AdditionalParameters.Property("AgreementsAndCertificatesCorrespondence", AgreementsAndCertificatesCorrespondence)
			AND TypeOf(AgreementsAndCertificatesCorrespondence) = Type("Map")
			AND AgreementsAndCertificatesCorrespondence.Count() > 0 Then
			
			For Each Item IN AgreementsAndCertificatesCorrespondence Do
				EDFProfileSettings = Item.Key;
				Certificates = Item.Value;
				
				If Not (TypeOf(Certificates) = Type("Array") AND ValueIsFilled(EDFProfileSettings))Then
					Continue;
				EndIf;
				
				Marker = Undefined;
				CertificatesArray = New Array;
				For Each Certificate IN Certificates Do
					ParametersStructure = Parameters.AccCertificatesAndTheirStructures.Get(Certificate);
					If ParametersStructure.Property("MarkerTranscribed", Marker) Then
						ReturnAccordance.Insert(EDFProfileSettings, ParametersStructure);
						CertificatesArray = New Array;
						Break;
					Else
						ParametersStructure.Property("MarkerEncrypted", Marker);
						If ParametersStructure.PasswordReceived Then
							// You can log on the operator server with
							// any certificate registered in the agreement. So if there are some certificates available for
							// authorization and among them there is at least one with the saved (in the certificate
							// or session) password, then return it not to open the certificate selection dialog.
							CertificatesArray = New Array;
							CertificatesArray.Add(Certificate);
							Break;
						Else
							CertificatesArray.Add(Certificate);
						EndIf;
					EndIf;
				EndDo;
				// If a certificate array is empty, it means that either there is
				// a decrypted marker already, or there are no certificates. IN any case, go to processing of the next EDF Setting.
				If CertificatesArray.Count() > 0 Then
					DataDescription = New Structure;
					DataDescription.Insert("FilterCertificates", CertificatesArray);
					DataDescription.Insert("WithoutConfirmation",  True);
					DataDescription.Insert("ItIsAuthentication", True);
					DataDescription.Insert("Operation", NStr("en='Authentication on EDF operator server';ru='Аутентификация на сервере оператора ЭДО'"));
					DataDescription.Insert("EnableRememberPassword", True);
					If Marker = Undefined Then
						MarkerQueryParameters = New Structure("ID_Parameters, DataDescription", ID_Parameters, DataDescription);
						Marker = New NotifyDescription("GetEncryptedMarkerData", ThisObject, MarkerQueryParameters);
					EndIf;
					
					DataDescription.Insert("Data", Marker);
					
					AdditionalParameters.Insert("EDFProfileSettings", EDFProfileSettings);
					AdditionalParameters.Insert("DataDescription", DataDescription);
					
					// Delete processed item from the match:
					AgreementsAndCertificatesCorrespondence.Delete(EDFProfileSettings);
					NotifyDescription = New NotifyDescription("DecryptMarker", ThisObject, AdditionalParameters);
					
					RunFinalAlertHandler = False;
					DigitalSignatureClient.Decrypt(DataDescription, , NotifyDescription);
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		If RunFinalAlertHandler
			AND AdditionalParameters.Property("NotificationHandler", NotificationHandler)
			AND TypeOf(NotificationHandler) = Type("NotifyDescription") Then
			
			NotificationParameters = New Structure;
			NotificationParameters.Insert("ProfilesAndCertificatesParametersMatch", ReturnAccordance);
			
			If ApplicationParameters["ElectronicInteraction." + ID_Parameters] <> Undefined Then
				ApplicationParameters.Delete("ElectronicInteraction." + ID_Parameters);
			EndIf;
			
			ExecuteNotifyProcessing(NotificationHandler, NotificationParameters);
		EndIf;
	EndIf;
	
EndProcedure

Procedure SendPackagesArrayAlert(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	AccAgreementsAndStructuresOfCertificates = Result.ProfilesAndCertificatesParametersMatch;
	ArrayPED = AdditionalParameters.ArrayPED;
	
	Result = ElectronicDocumentsServiceCallServer.EDPackagesSending(ArrayPED, AccAgreementsAndStructuresOfCertificates);
	
	Notify("RefreshStateED");
	
	NotificationProcessing = AdditionalParameters.NotificationProcessing;
		
	If Not NotificationProcessing = Undefined Then
		
		ExecuteNotifyProcessing(NotificationProcessing, Result);
		
	EndIf;
	
EndProcedure

Procedure HandleCancellationOfferComplete(Val Result, Val AdditionalParameters) Export
	
	Notify("RefreshStateED");
	
EndProcedure

Procedure HandleEDDeviationCancellationComplete(Val Result, Val AdditionalParameters) Export
	
	If ValueIsFilled(Result) Then
		Text = NStr("en='%1, %2: %3';ru='%1, %2: %3'");
		CorrectionText = StringFunctionsClientServer.PlaceParametersIntoString(Text,
			AdditionalParameters.Company, UsersClientServer.CurrentUser(), Result);
		
		If AdditionalParameters.Reject Then
			ServiceEDKind = PredefinedValue("Enum.EDKinds.NotificationAboutClarification");
		Else
			ServiceEDKind = PredefinedValue("Enum.EDKinds.CancellationOffer");
		EndIf;
		// On cancelling parameter GenerateED always has value
		// True, on deviation it can have value True, as well as False.
		NotifyDescription = Undefined;
		AdditionalParameters.Property("NotifyDescription", NotifyDescription);
		GenerateED = False;
		If Not (AdditionalParameters.Property("GenerateED", GenerateED) AND GenerateED = True) Then
			NewEDStatus = PredefinedValue("Enum.EDStatuses.Rejected");
			ParametersStructure = New Structure("EDStatus, RejectionReason", NewEDStatus, Result);
			LinkToED = AdditionalParameters.LinkToED;
			ElectronicDocumentsServiceCallServer.ChangeByRefAttachedFile(AdditionalParameters.LinkToED, ParametersStructure, False);
			If TypeOf(NOTifyDescription) = Type("NotifyDescription") Then
				ExecuteNotifyProcessing(NOTifyDescription, True);
			EndIf;
		Else
			GenerateSignServiceED(AdditionalParameters.LinkToED,
				ServiceEDKind, CorrectionText, NotifyDescription);
		EndIf;
	ElsIf Result <> Undefined Then
		MessageText = NStr("en='Reason is not specified, the action is cancelled.';ru='Причина не указана, действие отменено.'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

Procedure SendEDToBankWithAuthenticationLoginPassword(AuthorizationParameters, Parameters) Export
	
	EDAgreement = Parameters.EDAgreement;
	EDFSettingAttributes = ElectronicDocumentsServiceCallServer.EDFSettingAttributes(EDAgreement);
	AsynchronousExchange = PredefinedValue("Enum.BankApplications.AsynchronousExchange");
	If EDFSettingAttributes.BankApplication = AsynchronousExchange Then
		Parameters.Insert("ProcedureHandler", "SendEDToBankAfterReceivingMarker");
		Parameters.Insert("ObjectHandler", ElectronicDocumentsServiceClient);
		GetBankMarker(AuthorizationParameters, Parameters);
	Else
		SendEDToBankAfterReceivingMarker(AuthorizationParameters, Parameters);
	EndIf;
	
EndProcedure

Procedure SendEDToBankAfterReceivingMarker(Result, Parameters) Export
	
	If Result <> Undefined Then
		// Call from SendEDToBankWithAuthenticationLoginPassword(...), Result = AuthorizationParameters.
		AuthenticationParameters = Result;
	Else
		// Call from GetBankMarker.
		AuthenticationParameters = New Structure;
		
		If Parameters.Property("BankSessionID") Then // user entered authentication data
			AuthenticationParameters.Insert("MarkerTranscribed", Parameters.BankSessionID);
		EndIf;
	EndIf;
	DispatchEDArray = Parameters.EDArrayForSendingToBankWithAuthorizationLoginPassword;
	AccAgreementsAndStructuresOfCertificates = Parameters.AccAgreementsAndStructuresOfCertificates;
	AccAgreementsAndStructuresOfCertificates.Insert(Parameters.EDAgreement, AuthenticationParameters);
	
	NotifyDescription = New NotifyDescription("StartSendingEDToBankWithAuthorizationLoginPassword", ThisObject, Parameters);
	PrepareAndSendPED(DispatchEDArray, False, AccAgreementsAndStructuresOfCertificates, , NotifyDescription);
	
EndProcedure

#EndRegion

#Region ElectronicDocumentsExchangeWithBanks

Procedure AfterObtainingPrintsGetBankStatement(Prints, Parameters) Export
	
	ThumbprintArray = New Array;
	If TypeOf(Prints) = Type("Map") Then
		For Each KeyValue IN Prints Do
			ThumbprintArray.Add(KeyValue.Key);
		EndDo
	EndIf;
	
	EDAgreement = Parameters.EDAgreement;
	StartDate = Parameters.StartDate;
	EndDate = Parameters.EndDate;
	EDFSettingAttributes = Parameters.EDFSettingAttributes;
	AccountNo = Parameters.AccountNo;
	
	ExchangeSettings = Undefined;
	EDKindsArray = ElectronicDocumentsServiceCallServer.StatementsQueries(
		EDAgreement, StartDate, EndDate, AccountNo, ThumbprintArray, ExchangeSettings);
		
	If Not EDKindsArray.Count() OR ExchangeSettings = Undefined Then
		Return;
	EndIf;
	
	Parameters.Insert("EDKindsArray", EDKindsArray);
	
	If ExchangeSettings.ToSign Then
		If Not ValueIsFilled(ExchangeSettings.CompanyCertificateForSigning)
				OR Not ExchangeSettings.CertificateAvailable Then
			MessageText = NStr("en='Failed to find a suitable certificate for signature of the document Statement request';ru='Не найден подходящий сертификат для подписи документа Запрос выписки'");
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		EndIf;
			
		CertificateParameters = ElectronicDocumentsServiceCallServer.CertificateAttributes(
				ExchangeSettings.CompanyCertificateForSigning);
		Map = New Map;
		Map.Insert(ExchangeSettings.CompanyCertificateForSigning, CertificateParameters);
		OperationKind = NStr("en='Electronic documents signing';ru='Подписание электронных документов'");
		ProcessingParameters = New Structure;
		ProcessingParameters.Insert("AccCertificatesAndTheirStructures", Map);
		ProcessingParameters.Insert("EDKindsArray", EDKindsArray);
		ProcessingParameters.Insert("FormParameters", Parameters);
		SignStatementsRequests(Undefined, ProcessingParameters);
		Return;
	EndIf;
		
	AuthorizationParameters = New Structure;
	
	If Not EDFSettingAttributes.CryptographyIsUsed Then
		If Not ReceivedAuthorizationData(EDAgreement, AuthorizationParameters) Then
			OOOZ = New NotifyDescription("OpenStatementRequestForm", ThisObject, Parameters);
			GetAuthenticationData(EDAgreement, OOOZ);
			Return;
		EndIf;
	EndIf;
	
	OpenStatementRequestForm(AuthorizationParameters, Parameters);
	
EndProcedure

Procedure AfterConnectingBankExternalComponent(Result, Parameters) Export
	
	CRParameters = Parameters.CRParameters;
	If Result Then
		Try
			AttachableModule = New(Parameters.CRParameters.ModuleName);
			If CRParameters.Property("servicePort") Then
				AttachableModule.servicePort = 28016;
			EndIf;
			ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
			ExchangeWithBanksSubsystemsParameters.Insert(CRParameters.ModuleName, AttachableModule);
		Except
			MessageText = NStr("en='An error occurred when connecting an external component of the bank.';ru='Ошибка подключения внешней компоненты банка.'");
			Operation = NStr("en='Connecting external component of the bank';ru='Подключение внешней компоненты банка'");
			DetailErrorDescription = DetailErrorDescription(ErrorInfo());
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
				Operation, DetailErrorDescription, MessageText, 1);
		EndTry;
	ElsIf Not Parameters.CRParameters.Property("ExternalComponentSettingWasRunning") Then
		Parameters.CRParameters.Insert("TriedToInstallComponent");
		ND = New NotifyDescription("ConnectBankExternalComponent", ThisObject, Parameters);
		BeginInstallAddIn(ND, Parameters.CRParameters.Address);
		Return;
	EndIf;
	
	ExecutionHandler = Parameters.CRParameters.HandlerAfterConnectingComponents;
	
	ExecuteNotifyProcessing(ExecutionHandler, AttachableModule);
	
EndProcedure

Procedure SignStatementsRequests(Result, ProcessingParameters) Export
	
	AccCertificatesAndTheirStructures = ProcessingParameters.AccCertificatesAndTheirStructures;
	EDKindsArray = ProcessingParameters.EDKindsArray;
	
	CertificatesArray = New Array;
	For Each KeyAndValue IN AccCertificatesAndTheirStructures Do
		CertificatesArray.Add(KeyAndValue.Key);
	EndDo;
	
	If EDKindsArray.Count() = 1 Then
		Operation = NStr("en='Electronic document signing';ru='Подписание электронного документа'");
	Else
		Operation = NStr("en='Electronic documents signing';ru='Подписание электронных документов'");
	EndIf;
	
	DataDescription = New Structure;
	DataDescription.Insert("Operation",            Operation);
	DataDescription.Insert("FilterCertificates",   CertificatesArray);
	DataDescription.Insert("ShowComment", False);
	DataDescription.Insert("WithoutConfirmation",    True);
	
	DataSet = New Array;
	For Each ED IN EDKindsArray Do
		Data = New Structure;
		ParametersForReceivingDD = New Structure("ED, DataDescription", ED, DataDescription);
		RefOnDD = New NotifyDescription("GetBinaryDataForED", ThisObject, ParametersForReceivingDD);
		Data.Insert("Data", RefOnDD);
		Data.Insert("Object", ED);
		
		DataSet.Add(Data);
	EndDo;
	
	DataDescription.Insert("DataSet", DataSet);
	ProcessingParameters.Insert("DataDescription", DataDescription);
	NotifyDescription = New NotifyDescription("SignStatementsQueriesComplete", ThisObject, ProcessingParameters);
	DigitalSignatureClient.Sign(DataDescription, , NotifyDescription);
	
EndProcedure

Procedure SignStatementsQueriesComplete(Result, ProcessingParameters) Export
	
	DigitallySignedCnt = 0;
	DataSet = Undefined;
	If TypeOf(Result) = Type("Structure") Then
		If Result.Property("DataSet", DataSet)
			AND TypeOf(DataSet) = Type("Array") Then
			For Each Structure IN DataSet Do
				SignatureProperties = Undefined;
				Signature = Undefined;
				If Structure.Property("SignatureProperties", SignatureProperties)
					AND TypeOf(SignatureProperties) = Type("Structure")
					AND SignatureProperties.Property("Signature", Signature) Then
					DigitallySignedCnt = DigitallySignedCnt + 1;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	FormOwner = ProcessingParameters.FormParameters.Owner;
	ProcessingParameters.FormParameters.Delete("Owner");
	
	If DigitallySignedCnt > 0 Then
		OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.RequestToBank", ProcessingParameters.FormParameters,
			FormOwner);
	EndIf;
	
EndProcedure

Procedure UnpackBankEDPackageOnClient(EDPackage, Structure, NotifyDescription)
	
	ElectronicDocumentsServiceCallServer.UnpackEDBankPack(EDPackage, Structure);
	ExecuteNotifyProcessing(NOTifyDescription, Undefined);
	
EndProcedure

//Deserializes data
//
// Parameters:
// XMLPresentation - String - serialized data
//
// Returns:
//  Arbitrary - deserialized data
//
Function DeSerializedData(Val XMLPresentation) Export

	#If Not WebClient Then
	
		XMLReader = New XMLReader;
		XMLReader.SetString(XMLPresentation);
		XMLReader.Read();

		Serializer = New XDTOSerializer(XDTOFactory);
		Return Serializer.ReadXML(XMLReader);
	#Else
		
		Return ElectronicDocumentsServiceCallServer.DeSerializedData(XMLPresentation);
		
	#EndIf

EndFunction

Procedure OpenStatementRequestForm(AuthorizationParameters, Parameters) Export
	
	If AuthorizationParameters = Undefined Then
		Return;
	EndIf;
	
	AgreementAttributes = ElectronicDocumentsServiceCallServer.EDFSettingAttributes(Parameters.EDAgreement);
	
	AsynchronousExchange = PredefinedValue("Enum.BankApplications.AsynchronousExchange");
	
	FormOwner = Parameters.Owner;
	If AuthorizationParameters.Count() Then
		Parameters.Insert("User", AuthorizationParameters.User);
		Parameters.Insert("Password", AuthorizationParameters.UserPassword);
	EndIf;
	
	If AgreementAttributes.BankApplication = AsynchronousExchange Then
		Parameters.Insert("ProcedureHandler", "RequestStatementAfterReceivingBankMarker");
		Parameters.Insert("ObjectHandler", ElectronicDocumentsServiceClient);
		GetBankMarker(AuthorizationParameters, Parameters);
		Return;
	EndIf;
	
	Parameters.Delete("Owner");
	OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.RequestToBank", Parameters, FormOwner);
	
EndProcedure


// Called from
//
// Parameters:
//    Result - Structure, Undefined - in the structure results of next
//              finished iteration for sending banking ED to the bank are returned:
//       TotalPreparedCnt - Number.
//       TotalSentCnt   - Number.
//    Parameters - Structure:
//       EDFSettingsWithBanks - Array.
//       TotalPreparedCnt - Number.
//       TotalSentCnt   - Number.
//
Procedure RunExchangeWithBanks(Result, Parameters) Export
	
	TotalPreparedCnt = 0;
	TotalSentCnt = 0;
	TotalNumberReceived = 0;
	If TypeOf(Result) = Type("Structure") Then
		If Result.Property("TotalPreparedCnt", TotalPreparedCnt) Then
			PreparedCnt = 0;
			If Not (Parameters.Property("TotalPreparedCnt", PreparedCnt)
					AND TypeOf(PreparedCnt) = Type("Number")) Then
				
				PreparedCnt = 0;
			EndIf;
			PreparedCnt = PreparedCnt + TotalPreparedCnt;
			Parameters.Insert("TotalPreparedCnt", PreparedCnt);
		EndIf;
		If Result.Property("TotalSentCnt", TotalSentCnt) Then
			SentCnt = 0;
			If Not (Parameters.Property("TotalSentCnt", SentCnt)
					AND TypeOf(SentCnt) = Type("Number")) Then
				
				SentCnt = 0;
			EndIf;
			SentCnt = SentCnt + TotalSentCnt;
			Parameters.Insert("TotalSentCnt", SentCnt);
		EndIf;
		If Result.Property("TotalNumberReceived", TotalNumberReceived) Then
			ReceivedNumber = 0;
			If Not (Parameters.Property("TotalNumberReceived", ReceivedNumber)
					AND TypeOf(ReceivedNumber) = Type("Number")) Then
				
				ReceivedNumber = 0;
			EndIf;
			ReceivedNumber = ReceivedNumber + TotalNumberReceived;
			Parameters.Insert("TotalNumberReceived", ReceivedNumber);
		EndIf;
	EndIf;
	
	EDFSettingsWithBanks = Undefined;
	If Not Parameters.Property("EDFSettingsWithBanks", EDFSettingsWithBanks)
		OR EDFSettingsWithBanks.Count() = 0 Then
		
		ExecuteActionsAfterSending(Parameters);
	Else
		EDFSetup = EDFSettingsWithBanks[0];
		Parameters.EDFSettingsWithBanks.Delete(0);
		NotifyDescription = New NotifyDescription("RunExchangeWithBanks", ThisObject, Parameters);
		Structure = New Structure("ContinuationHandler, EDAgreement, TotalPreparedCnt, TotalSentCnt",
			NotifyDescription, EDFSetup, 0, 0);
		RunExchangeWithBank(Structure);
	EndIf;
	
EndProcedure

// Send and receive e-documents by one command.
//
// Parameters:
//    Parameters - Structure:
//       ContinuationHandler - NotificationDescription.
//       EDAgreement          - CatalogRef.EDExchangeAgreements.
//       TotalPreparedCnt - Number.
//       TotalSentCnt   - Number.
//
Procedure RunExchangeWithBank(Parameters)
	
	// Block of ED sending and receiving.
	MessageText = NStr("en='sending the packages of electronic documents to the bank. Please wait...';ru='Отправка пакетов электронных документов в банк. Пожалуйста, подождите..'");
	Status(NStr("en='sending.';ru='отправка.'"), , MessageText);
		
	AuthorizationParameters = New Map;
	Parameters.Insert("AuthorizationParameters", AuthorizationParameters);
	
	AgreementAttributes = ElectronicDocumentsServiceCallServer.EDFSettingAttributes(Parameters.EDAgreement);
	
	SynchronousExchange = PredefinedValue("Enum.BankApplications.AlphaBankOnline");
	ExchangeThroughTheAdditionalInformationProcessor = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor");
	Parameters.Insert("WantedAuthorization", True);
	DataAuthorization = Undefined;
	SberbankOnline = PredefinedValue("Enum.BankApplications.SberbankOnline");
	
	If AgreementAttributes.BankApplication = SberbankOnline Then
		ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	Else
		If AgreementAttributes.BankApplication = SynchronousExchange AND AgreementAttributes.CryptographyIsUsed
			OR AgreementAttributes.BankApplication = ExchangeThroughTheAdditionalInformationProcessor
			OR CertificatePasswordReceived(Parameters.EDAgreement, DataAuthorization) Then
			
			If DataAuthorization = Undefined Then
				Parameters.Insert("WantedAuthorization", False);
			EndIf;
			SendDocumentsToBank(DataAuthorization, Parameters);
		Else
			OOOZ = New NotifyDescription("SendDocumentsToBank", ThisObject, Parameters);
			GetAuthenticationData(Parameters.EDAgreement, OOOZ);
		EndIf;
	EndIf;
	
EndProcedure

// Send and receive e-documents by one command.
//
// Parameters:
//    DataAuthorization - Structure, Undefined.
//    Parameters         - Structure:
//       ContinuationHandler - NotificationDescription.
//       EDAgreement          - CatalogRef.EDExchangeAgreements.
//       TotalPreparedCnt - Number.
//       TotalSentCnt   - Number.
//       AuthorizationParameters  - Matching.
//       WantedAuthorization  - Boolean.
//
Procedure SendDocumentsToBank(DataAuthorization, Parameters) Export
	
	ExecuteAlert = False;
	If Not Parameters.WantedAuthorization OR ValueIsFilled(DataAuthorization) Then
		EDFSettingAttributes = ElectronicDocumentsServiceCallServer.EDFSettingAttributes(Parameters.EDAgreement);
		AsynchronousExchange = PredefinedValue("Enum.BankApplications.AsynchronousExchange");
		If EDFSettingAttributes.BankApplication = AsynchronousExchange Then
			Parameters.Insert("DataAuthorization", DataAuthorization);
			Parameters.Insert("ProcedureHandler", "SendAndReceiveDocumentsInBankAfterReceivingMarker");
			Parameters.Insert("ObjectHandler", ElectronicDocumentsServiceClient);
			GetBankMarker(DataAuthorization, Parameters);
		Else
			AuthorizationParameters = Parameters.AuthorizationParameters;
			EDAgreement = Parameters.EDAgreement;
			AuthorizationParameters.Insert(EDAgreement, DataAuthorization);
			
			ReturnStructure = Undefined;
			ElectronicDocumentsServiceCallServer.SendEDToBank(EDAgreement, AuthorizationParameters, ReturnStructure);
			
			If ReturnStructure.Property("SentPackagesCnt") Then
				Parameters.TotalSentCnt = Parameters.TotalSentCnt + ReturnStructure.SentPackagesCnt;
			EndIf;
			// T.k. sending is executed according to specific agreement, matches
			// in ReturnStructure (DataForSendingThroughAdditDataProcessor, DataForSendingiBank2) with key EDAgreement can
			// not have more than one item. Therefore you can immediately retrieve data to be sent from the match in order to avoid confusion.
			If ReturnStructure.Property("DataForSendingViaAddDataProcessor")
				AND ReturnStructure.DataForSendingViaAddDataProcessor.Count() > 0 Then
				
				DataForSending = ReturnStructure.DataForSendingViaAddDataProcessor.Get(EDAgreement);
				Parameters.Insert("DataForSending", DataForSending);
				HandlerAfterConnecting = New NotifyDescription("StartSendingPackagesThroughAdditionalDataProcessor",
					ThisObject, Parameters);
				Parameters.Insert("RunTryReceivingModule", False);
				Parameters.Insert("AfterObtainingDataProcessorModule", HandlerAfterConnecting);
				GetExternalModuleThroughAdditionalProcessing(Parameters);
			ElsIf ReturnStructure.Property("DataForiBank2Sending")
				AND ReturnStructure.DataForiBank2Sending.Count() > 0 Then
				
				Parameters.Insert("DataStructure", ReturnStructure);
				HandlerAfterConnecting = New NotifyDescription("StartSendingiBank2Packages", ThisObject, Parameters);
				Parameters.Insert("HandlerAfterConnectingComponents", HandlerAfterConnecting);
				EnableExternalComponentiBank2(Parameters);
			Else
				ExecuteAlert = True;
			EndIf;
		EndIf;
	Else
		ExecuteAlert = True;
	EndIf;
	
	If ExecuteAlert Then
		ExecuteNotifyProcessing(Parameters.ContinuationHandler, Parameters.TotalSentCnt);
	EndIf;
	
EndProcedure

// For internal use only
Function ConnectionWithAsyncBankTest(Result, Parameters) Export
	
	BankSessionID = Parameters.BankSessionID;
	If Not ValueIsFilled(BankSessionID) Then
		Return False;
	EndIf;
	
	TargetID = Parameters.TargetID;
	EDAgreement = Parameters.EDAgreement;
	
	Test = NStr("en='Sending test package to the bank.';ru='Отправка тестового пакета в банк.'");
	ElectronicDocumentsClientServer.MessageToUser(Test, TargetID);
	
	QueryPosted = False;
	ElectronicDocumentsServiceCallServer.SendQueryProbeToBank(
				EDAgreement, BankSessionID, QueryPosted);
	
	TestResult = NStr("en='is not passed.';ru='Не пройден.'");
	PassedSuccessfully = False;
	If QueryPosted Then
		TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
		PassedSuccessfully = True;
	EndIf;
	ElectronicDocumentsClientServer.MessageToUser(TestResult, TargetID);
	
	Return PassedSuccessfully;
	
EndFunction

Procedure AsyncAgreementTest(EDAgreement, Parameters)
	
	// Block of communication test with bank.
	Status(NStr("en='Agreement settings test.';ru='Тест настроек соглашения.'"), ,
		NStr("en='Testing the connection with the bank. Please wait...';ru='Выполняется тестирование связи с банком. Пожалуйста, подождите..'"));
		
	TestsComplete = False;
	// Block for checking the completion of company identifier.
	Parameters.Insert("EDAgreement", EDAgreement);
	Parameters.Insert("ProcedureHandler", "ConnectionWithAsyncBankTest");
	Parameters.Insert("ObjectHandler", ElectronicDocumentsServiceClient);
	OOOZ = New NotifyDescription("GetBankMarker", ThisObject, Parameters);
	GetAuthenticationData(EDAgreement, OOOZ, True);

EndProcedure

Procedure GetBankMarker(AuthenticationData, Parameters) Export
	
	If AuthenticationData = Undefined Then
		NotifyDescription = New NotifyDescription(Parameters.ProcedureHandler, Parameters.ObjectHandler, Parameters);
		ExecuteNotifyProcessing(NOTifyDescription);
		Return;
	EndIf;
	
	EDAgreement = Parameters.EDAgreement;
	SMSAuthorizationData = Undefined;
	BankSessionID = ElectronicDocumentsServiceCallServer.BankSessionID(
											EDAgreement, AuthenticationData, SMSAuthorizationData);
	If ValueIsFilled(SMSAuthorizationData) Then
		Parameters.Insert("BankSessionID", BankSessionID);
		FormParameters = New Structure();
		FormParameters.Insert("SessionID", BankSessionID);
		FormParameters.Insert("Phone", SMSAuthorizationData.PhoneMask);
		FormParameters.Insert("EDAgreement", EDAgreement);
		ND = New NotifyDescription("SendOneTimePasswordToBankAsynchronousExchange", ThisObject, Parameters);
		OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.ExtendedAuthenticationBySMS", FormParameters, , , , , ND);
	Else
		Parameters.Insert("BankSessionID", BankSessionID);
		NotifyDescription = New NotifyDescription(Parameters.ProcedureHandler, Parameters.ObjectHandler, Parameters);
		ExecuteNotifyProcessing(NOTifyDescription);
	EndIf;
	
EndProcedure

Procedure SendOneTimePasswordToBankAsynchronousExchange(OneTimePassword, Parameters) Export
	
	If ValueIsFilled(OneTimePassword) Then
		BankSessionID = ElectronicDocumentsServiceCallServer.BankSessionIDBySMS(
						Parameters.EDAgreement, Parameters.BankSessionID, OneTimePassword);
		Parameters.Insert("BankSessionID", BankSessionID);
	Else
		Parameters.Insert("BankSessionID", Undefined);
	EndIf;
	
	NotifyDescription = New NotifyDescription(Parameters.ProcedureHandler, Parameters.ObjectHandler, Parameters);
	ExecuteNotifyProcessing(NOTifyDescription);

EndProcedure

Procedure RequestStatementAfterReceivingBankMarker(Result, Parameters) Export
	
	If Not ValueIsFilled(Parameters.BankSessionID) Then
		Return;
	EndIf;
	
	FormOwner = Parameters.Owner;
	Parameters.Delete("Owner");
	Parameters.Delete("ProcedureHandler");
	Parameters.Delete("ObjectHandler");
	OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.RequestToBank", Parameters, FormOwner);
	
EndProcedure

Procedure SendAndReceiveDocumentsInBankAfterReceivingMarker(Result, Parameters) Export
	
	If ValueIsFilled(Parameters.BankSessionID) Then
		AuthorizationParameters = Parameters.AuthorizationParameters;
		DataAuthorization = Parameters.DataAuthorization;
		DataAuthorization.Insert("MarkerTranscribed", Parameters.BankSessionID);
		EDAgreement = Parameters.EDAgreement;
		AuthorizationParameters.Insert(EDAgreement, DataAuthorization);
		
		ReturnStructure = Undefined;
		ElectronicDocumentsServiceCallServer.SendEDToBank(EDAgreement, AuthorizationParameters, ReturnStructure);
		ElectronicDocumentsServiceCallServer.GetEDFromBankAsynchronousExchange(AuthorizationParameters, ReturnStructure);
		
		// Prepare message display for user on sending/receiving ED packages.
		SentPackagesCnt = ReturnStructure.SentPackagesCnt;
		ReceivedPacksQuantity = ReturnStructure.ReceivedPacksQuantity;
		NotificationTemplate = NStr("en='Packages sent: (%1), packages received: (%2).';ru='Отправлено пакетов: (%1), получено пакетов: (%2).'");
		NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(
					NotificationTemplate, SentPackagesCnt, ReceivedPacksQuantity);
		
		Notify("RefreshStateED");
			
		NotificationTitle = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
		ShowUserNotification(NotificationTitle, , NotificationText);
		
		Structure = New Structure("TotalNumberSent, TotalNumberReceived", SentPackagesCnt, ReceivedPacksQuantity);
		Parameters.TotalSentCnt = Parameters.TotalSentCnt + ReturnStructure.SentPackagesCnt;
		ExecuteNotifyProcessing(Parameters.ContinuationHandler, Structure);
	EndIf;
	
EndProcedure

Procedure SendEDStatusQueryToBankAfterReceivingMarker(DataAuthorization, Parameters) Export
	
	If Not ValueIsFilled(Parameters.BankSessionID) Then
		Return;
	EndIf;
	
	Parameters.Delete("ObjectHandler");
	
	OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.RequestToBank", Parameters);
	
EndProcedure

// Procedure interactively requests login and
// password from user Parameters:
//  EDAgreement - CatalogRef.EDUsageAgreements - reference to the
//  agreement with the bank OnCloseNotifyDescription - NotifyDescription - where Parameters application operation
//  will continue - additional parameters of data processor
//
Procedure GetAuthenticationData(EDAgreement, OnCloseNotifyDescription, IsTest = False) Export
	
	FormParameters = New Structure();
	FormParameters.Insert("OperationKind", NStr("en='Authentication on the bank server';ru='Аутентификация на сервере банка'"));
	FormParameters.Insert("WriteToIB", IsTest);
	AgreementParameters = New Map;
	AgreementParameters.Insert(EDAgreement);
	FormParameters.Insert("Map", AgreementParameters);
	OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.PasswordToCertificateQuery",
		FormParameters, , , , , OnCloseNotifyDescription, FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure

//Executes data serialization
//
// Parameters:
// Value - Arbitrary - data for serialization
//
// Returns:
//  String - serialized data
//
Function SerializedData(Val Value) Export

	#If Not WebClient Then

		If Value = Undefined Then
			Return Undefined;
		EndIf;

		Serializer = New XDTOSerializer(XDTOFactory);
		XDTODataObject = Serializer.WriteXDTO(Value);
		XMLWriter = New XMLWriter;
		XMLWriter.SetString();
		XDTOFactory.WriteXML(XMLWriter, XDTODataObject);

		Return XMLWriter.Close();
		
	#Else
		
		Return ElectronicDocumentsServiceCallServer.SerializedData(Value);

	#EndIf

EndFunction

Procedure ExtendedAuthentication(EDAgreement, Val Certificate, Val ExtendedAuthenticationParameters, OOOZ)

	FormParameters = New Structure();
	FormParameters.Insert("Certificate",   Certificate);
	FormParameters.Insert("Session",       ExtendedAuthenticationParameters.Session);
	FormParameters.Insert("EDAgreement", EDAgreement);

	OpenForm(
		"DataProcessor.ElectronicDocumentsExchangeWithBank.Form.ExtendedAuthenticationBySMS", FormParameters, , , , , OOOZ);


EndProcedure

#EndRegion

#Region iBank2

Function iBankName2ComponentName() Export
	
	Return "AddIn.iBank2DX.iBank2ProviderDX_v_1_0";
	
EndFunction

// Sets the password for connection with the bank
//
// Parameters:
//  XMLCertificate  - String - Contains
//  certificate data Password  - String - certificate password
//
// Returns:
//   Boolean   - is password correct or not
//
Function SetiBank2CertificatePassword(XMLCertificate, Password) Export
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
		ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()), Undefined);

	Try
		ExternalAttachableModule.SetCertificatePassword(XMLCertificate, Password);
	Except
		ErrorTemplate = NStr("en='Error setting certificate password.
		|Error code:
		|%1 %2';ru='Ошибка установки пароля сертификата.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = InformationAboutErroriBank2();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Setting certificate password';ru='Установка пароля сертификата'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
							Operation, DetailErrorDescription, MessageText, 1);
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

// Connecting with bank
//
// Parameters:
//  EDAgreement - CatalogRef.EDUsageAgreements - agreement
//  with bank XMLCertificate  - String - data
//  of certificate Parameters  - Structure - Contains the context
//  of AuthenticationCompleted method execution - Boolean - True - connection established, otherwise False
//
Procedure EstablishConnectioniBank2(EDAgreement, XMLCertificate, NotifyDescription) Export
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
		ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()), Undefined);
	
	ProxyServerSettings = StandardSubsystemsClientReUse.ClientWorkParameters().ProxyServerSettings;
	
	ExecuteAlert = True;
	AuthenticationCompleted = True;
	If ValueIsFilled(ProxyServerSettings) Then
	
		ProxySettings = New Structure;

		ProxySettings.Insert("ConnectionType", 0);

		If ProxyServerSettings["UseProxy"] Then
			ProxySettings.ConnectionType = ?(ProxyServerSettings["UseSystemSettings"], 1, 2);
		EndIf;

		ProxySettings.Insert("Server",       ProxyServerSettings["Server"]);
		ProxySettings.Insert("Port",         Format(ProxyServerSettings["Port"], "NG=0"));
		ProxySettings.Insert("User", ProxyServerSettings["User"]);
		ProxySettings.Insert("Password",       ProxyServerSettings["Password"]);

		XMLProxySettings = SerializedData(ProxySettings);
		
		Try
			ExternalAttachableModule.SetProxy(XMLProxySettings);
		Except
			ErrorTemplate = NStr("en='An error occurred when setting proxy server settings.
		|Error code:
		|%1 %2';ru='Ошибка установки настроек прокси-сервера.
		|Код
		|ошибки: %1 %2'");
			ErrorDetails = InformationAboutErroriBank2();
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
								ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
			Operation = NStr("en='Setting proxy server settings';ru='Установка настроек прокси сервера'");
			DetailErrorDescription = DetailErrorDescription(ErrorInfo());
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
								Operation, DetailErrorDescription, MessageText, 1);
			AuthenticationCompleted = False;
		EndTry;
		
	EndIf;
	
	If AuthenticationCompleted Then
		ID = String(EDAgreement.UUID());
		Try

			If Not ExternalAttachableModule.Connect(XMLCertificate, ID) Then
				XMLExtendedAuthenticationParameters = Undefined;
				ExtendedAuthenticationRequired = ExternalAttachableModule.RequiredToExecuteExtendedAuthentication(
																						XMLExtendedAuthenticationParameters);
				If ExtendedAuthenticationRequired Then
					ExtendedAuthenticationParameters = DeSerializedData(XMLExtendedAuthenticationParameters);
					If ExtendedAuthenticationParameters.Ways.Count() = 0 Then
						Raise NStr("en='Methods of extended authentication are not defined.';ru='Не определены способы расширенной аутентификации.'");
					EndIf;
					If Not ExtendedAuthenticationParameters.Ways.Property("SMS") Then
						Raise NStr("en='Extended authentication by SMS is not supported.';ru='Расширенная аутентификация по SMS не поддерживается.'");
					EndIf;
					OneTimePassword = Undefined;
					ExtendedAuthentication(EDAgreement, XMLCertificate, ExtendedAuthenticationParameters, NotifyDescription);
					ExecuteAlert = False;
				Else
					Raise NStr("en='Connection setup error.';ru='Ошибка установки соединения'");
				EndIf;
			EndIf;
			
		Except
			ErrorTemplate = NStr("en='An error occurred while connecting.
		|Error code:
		|%1 %2';ru='Ошибка установки соединения.
		|Код
		|ошибки: %1 %2'");
			ErrorDetails = InformationAboutErroriBank2();
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
								ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
			Operation = NStr("en='Making a connection';ru='Установка соединения'");
			DetailErrorDescription = DetailErrorDescription(ErrorInfo());
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
								Operation, DetailErrorDescription, MessageText, 1);
			AuthenticationCompleted = False;
		EndTry;
	EndIf;
	
	If ExecuteAlert Then
		ExecuteNotifyProcessing(NOTifyDescription, AuthenticationCompleted);
	EndIf;
	
EndProcedure

// Sets PIN code for access to bank key
//
// Parameters
//  StorageIdentifier  - String - identifier
//  of storage PinCode  - String - PIN code
//
// Returns:
//  Boolean -  PIN code is set successfully or not
//
Function SetStoragePINCodeiBank2(StorageIdentifier, PinCode) Export
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
		ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()), Undefined);
	PinCodeSet = True;
	
	Try
		ExternalAttachableModule.SetStoragePINCode(StorageIdentifier, PinCode);
	Except
		ErrorTemplate = NStr("en='PIN code setup error.
		|Error code:
		|%1 %2';ru='PIN code setup error.
		|Error code:
		|%1 %2'");
		ErrorDetails = InformationAboutErroriBank2();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
			ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Setting PIN-code';ru='Установка PIN-кода'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
			Operation, DetailErrorDescription, MessageText, 1);
		PinCodeSet = False;
	EndTry;
	
	Return PinCodeSet;
	
EndFunction

Function iBank2CertificatePasswordSet(XMLCertificate) Export
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
		ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()), Undefined);

	Try
		CertificatePasswordSet = ExternalAttachableModule.RequiredToSetCertificatePassword(XMLCertificate) = False;
	Except
		CertificatePasswordSet = False;
	EndTry;

	Return CertificatePasswordSet;
	
EndFunction

// Called after setting
// iBank2 component Parameters:
//    Parameters - Structure
//     * OO - NotifyDescription - description of
//     further processing procedure * EDAgreement - CatalogRef.EDUsageAgreements - agreement with bank
//
Procedure AfteriBank2ComponentInstallation(Parameters) Export
	
	ExecuteNotifyProcessing(Parameters.ND, Parameters.Result);
	
EndProcedure

Procedure GetBankStatementiBank2(ExternalAttachableModule, Parameters) Export

	If ExternalAttachableModule = Undefined Then
		Return;
	EndIf;
	
	EDAgreement = Parameters.EDAgreement;
	CertificatesData = ElectronicDocumentsServiceCallServer.BankCertificatesData(EDAgreement);
	
	Device = ConnectediBank2Storages();
	
	ChoiceList = New Array;
	Map = New Map;
	CertificatePasswordSet = False;

	If Device.Count() > 0 Then
		For Each CertificateData IN CertificatesData Do
			iBank2CertificateData = iBank2CertificateData(CertificateData.CertificateBinaryData);
			If Device.Find(iBank2CertificateData.StorageIdentifier) <> Undefined Then
				Map.Insert(CertificateData.Certificate, CertificateData);
			EndIf;
		EndDo
	Else
		MessageText = NStr("en='It is required to connect bank key to your computer to execute the operation';ru='Для выполнения операции необходимо подключить банковский ключ к компьютеру'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return
	EndIf;
	
	Parameters.Insert("AccCertificatesAndTheirStructures", Map);
	Parameters.Insert("CertificatesData", CertificatesData);
	
	OperationKind = NStr("en='Authentication on bank resource';ru='Аутентификация на ресурсе банка.'");
	If Not CertificatePasswordSet Then
		If Map.Count() > 0 Then
			If Not PasswordToCertificateReceived2(Map, OperationKind) Then
				ND = New NotifyDescription("ContinueReceivingStatementAfterEnteringiBank2CertificatePassword", ThisObject, Parameters);
				Parameters.Insert("CallNotification", ND);
				GetPasswordToSertificate(Map, OperationKind, , , Parameters);
				Return;
			EndIf;
		Else
			MessageText = NStr("en='Unsuitable bank key is connected to the computer';ru='К компьютеру подключен не подходящий банковский ключ'");
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		EndIf;
	EndIf;
	
	ContinueReceivingStatementAfterEnteringiBank2CertificatePassword(Undefined, Parameters)
	
EndProcedure


//Receives the array of storages identifiers connected to the computer
//
// Returns:
//  Array - storages identifiers
//
Function ConnectediBank2Storages() Export
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
		ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()), Undefined);
	
	Try
		XMLDevices = ExternalAttachableModule.CertificatesStorages();
		Device = DeSerializedData(XMLDevices);
	Except
		ErrorTemplate = NStr("en='An error occurred when searching for connected storages.
		|Error code:
		|%1 %2';ru='Ошибка при поиске подключенных хранилищ.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = InformationAboutErroriBank2();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Search for storages';ru='Поиск хранилищ'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
							Operation, DetailErrorDescription, MessageText, 1);
		Return Undefined;
	EndTry;
	
	If Device.Count() = 0 Then
		MessageText = NStr("en='No storage is found.
		|Verify that your device is connected to your computer and then try again';ru='Не найдено ни одного хранилища.
		|Убедитесь, что устройство подключено к компьютеру и повторите операцию'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return Device;
	
EndFunction

Procedure SendiBank2Packages(AuthenticationCompleted, Parameters) Export
	
	If AuthenticationCompleted = True Then
		DocumentsToBeSent = New Array;
		SentEDArray = New Array;
		
		For Each Document IN Parameters.SentiBank2Packages Do
			SendingStructure = New Structure;
			SendingStructure.Insert("Key",                Document.Value.Key);
			SendingStructure.Insert("ElectronicDocument", Document.Value.PaymentOrder);
			SendingStructure.Insert("DataSchema",         GetFromTempStorage(Document.Value.ServiceData));
			SendingStructure.Insert("Signatures",             New Array);
		
			For Each StringSignatureData IN Document.Value.Signatures Do
				Signature = GetFromTempStorage(StringSignatureData.SignatureAddress);
				SignatureData = New Structure("Certificate, Signature", StringSignatureData.Certificate, Signature);
				SendingStructure.Signatures.Add(SignatureData);
			EndDo;
			DocumentsToBeSent.Add(SendingStructure);
		EndDo;
		
		SendingStructure = New Structure();
		SendingStructure.Insert("Documents",         DocumentsToBeSent);
		SendingStructure.Insert("DataSchemeVersion", "1.07");

		Result = SendQueryiBank2("3", SendingStructure);
		
		If Not Result = Undefined Then
			CountSent = Result.Count();
			ElectronicDocumentsServiceCallServer.ProcessBankResponse(Parameters.SentiBank2Packages, Result);
			Parameters.TotalSentCnt = Parameters.TotalSentCnt + CountSent;
		EndIf;
	EndIf;
	
	ContinueSendingiBank2PackagesRecursively(Parameters);
	
EndProcedure

// Sends a request to bank
//
// Parameters
//  RequestType  - String - request
//  type SendingData  - Structure - data to be sent
//
// Returns:
//  Map or Undefined - Execution result
//
Function SendQueryiBank2(TypeQuery, SendingData) Export
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
		ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()), Undefined);
	
	Try
		XMLSendingData = SerializedData(SendingData);
		ResultXML = ExternalAttachableModule.SendRequest(TypeQuery, XMLSendingData);
		Result = DeSerializedData(ResultXML);
	Except
		ErrorTemplate = NStr("en='Data sending error.
		|Error code:
		|%1 %2';ru='Ошибка отправки данных.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = InformationAboutErroriBank2();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Data sending';ru='Отправка данных'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
							Operation, DetailErrorDescription, MessageText, 1);
	EndTry;
	
	Return Result

EndFunction 

// Checks the need to set PIN code
//
// Parameters:
//  StorageIdentifier  - String - storage identifier
//
// Returns:
//   Boolean, Undefined - True - pin code is already set
//                          or not required, False - pin code is required and
//                          it is not set, Undefined - an error occurred when determining the need for pin code
//
Function RequiredToSetStoragePINCodeiBank2(StorageIdentifier) Export
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
		ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()), Undefined);
	
	Try
		PINRequired = ExternalAttachableModule.RequiredToSetStoragePINCode(StorageIdentifier);
	Except
		ClearMessages();
		ErrorTemplate = NStr("en='An error occurred when checking the need to input PIN code.
		|Error code:
		|%1 %2';ru='Ошибка проверки необходимости ввода PIN-кода.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = InformationAboutErroriBank2();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Check the need to enter PIN code';ru='Проверка необходимости ввода PIN-кода'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
			Operation, DetailErrorDescription, MessageText, 1);
		Return Undefined;
	EndTry;
	
	Return PINRequired;
		
EndFunction

Procedure SetPINCode(PINCode, Parameters) Export
	
	AbortSigning = True;
	If PINCode <> Undefined Then
		If SetStoragePINCodeiBank2(Parameters.StorageIdentifier, PINCode) Then
			AbortSigning = False;
			ContinueSigningiBank2(Parameters)
		EndIf;
	EndIf;
	
	DescriptionSignED = Undefined;
	If AbortSigning
		AND Parameters.Property("ContinuationHandler", DescriptionSignED)
		AND TypeOf(DescriptionSignED) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(DescriptionSignED);
	EndIf;
	
EndProcedure

Procedure StartSigningiBank2(ExternalAttachableModule, Parameters) Export
	
	If Parameters.Property("CRParameters") Then
		// Delete the parameters from the structure that were used for connection of external component:
		Parameters.Delete("CRParameters");
	EndIf;
	DescriptionSignED = Undefined;
	Parameters.Property("ContinuationHandler", DescriptionSignED);
	AbortSigning = False;
	If ExternalAttachableModule <> Undefined Then
		CertificateStructure = Parameters.CertificateStructure;
		
		EDArrayForCheck = New Array;
		
		CertificateAttributes = ElectronicDocumentsServiceCallServer.CertificateAttributes(
														CertificateStructure.SignatureCertificate);
		XMLCertificate = CertificateAttributes.CertificateBinaryData;
		Parameters.Insert("CertificateXMLiBank2", XMLCertificate);
		
		CertificateData = iBank2CertificateData(XMLCertificate);
		If CertificateData = Undefined Then
			AbortSigning = True;
		Else
			Parameters.Insert("StorageIdentifier", CertificateData.StorageIdentifier);
			
			PINCodeRequired = RequiredToSetStoragePINCodeiBank2(Parameters.StorageIdentifier);
			If PINCodeRequired = True Then
				FormParameters = New Structure;
				FormParameters.Insert("EDAgreement", Parameters.EDAgreement);
				FormParameters.Insert("StorageIdentifier", Parameters.StorageIdentifier);
				FormName = "DataProcessor.ElectronicDocumentsExchangeWithBank.Form.PINCodeRequest";
				NotifyDescription = New NotifyDescription("SetPINCode", ThisObject, Parameters);
				OpenForm(FormName, FormParameters, , , , , NotifyDescription);
			ElsIf PINCodeRequired <> Undefined Then
				ContinueSigningiBank2(Parameters);
			Else
				AbortSigning = True;
			EndIf;
		EndIf;
	EndIf;
	
	If AbortSigning AND TypeOf(DescriptionSignED) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(DescriptionSignED);
	EndIf;
	
EndProcedure

Procedure ContinueSigningiBank2(Parameters)
	
	XMLCertificate = Parameters.CertificateXMLiBank2;
	CertificateStructure = Parameters.CertificateStructure;
	EDAgreement = Parameters.EDAgreement;
	EDArrayForiBank2Signature = Parameters.EDArrayForSignature;
	
	PasswordIsSet = SetiBank2CertificatePassword(XMLCertificate, CertificateStructure.UserPassword);
	
	AbortSigning = True;
	If PasswordIsSet Then
		DataProcessorData = ElectronicDocumentsServiceCallServer.DataForDSGenerationThroughAdditDataProcessor(
																					EDArrayForiBank2Signature);
		Parameters.Insert("DataForiBank2Signature", DataProcessorData);
		
		AuthenticationRequired = (DataProcessorData.EDArrayWithoutSchemas.Count() > 0);
		If AuthenticationRequired Then
			NotifyDescription = New NotifyDescription("SigningEDiBank2", ThisObject, Parameters);
			EstablishConnectioniBank2(EDAgreement, XMLCertificate, NotifyDescription);
		Else
			SigningEDiBank2(True, Parameters);
		EndIf;
		AbortSigning = False;
	EndIf;
	
	DescriptionSignED = Undefined;
	If AbortSigning AND Parameters.Property("ContinuationHandler", DescriptionSignED)
		AND TypeOf(DescriptionSignED) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(DescriptionSignED);
	EndIf;
	
EndProcedure

Procedure SigningEDiBank2(AuthenticationCompleted, Parameters) Export
	
	AbortSigning = False;
	If AuthenticationCompleted = True Then
		ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
		
		//Parameters.Delete("DoNotDisplayInformationAboutProcessedED");
		EDAgreement = Parameters.EDAgreement;
		CertificateStructure = Parameters.CertificateStructure;
		XMLCertificate = Parameters.CertificateXMLiBank2;
		DataProcessorData = Parameters.DataForiBank2Signature;

		ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
			ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()), Undefined);
		
		If DataProcessorData.TextDataEDArray.Count() > 0 Then
			Try
				XMLEDTextDataArray = SerializedData(DataProcessorData.TextDataEDArray);
				NewXMLDataSchemesArray = ExternalAttachableModule.DataSchema(XMLEDTextDataArray);
				NewDataSchemesArray = DeSerializedData(NewXMLDataSchemesArray);
				ElectronicDocumentsServiceCallServer.SaveDataSchemas(
					EDAgreement, DataProcessorData.EDArrayWithoutSchemas, NewDataSchemesArray);
				CommonUseClientServer.SupplementArray(DataProcessorData.SchemasDataArray,  NewDataSchemesArray);
				CommonUseClientServer.SupplementArray(DataProcessorData.EDArrayWithSchemas, DataProcessorData.EDArrayWithoutSchemas);
			Except
				ErrorTemplate = NStr("en='Data scheme receiving error.
		|Error code:
		|%1 %2';ru='Ошибка получения схемы данных.
		|Код
		|ошибки: %1 %2'");
				ErrorDetails = InformationAboutErroriBank2();
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
									ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
				Operation = NStr("en='Receiving data scheme';ru='Получение схемы данных'");
				DetailErrorDescription = DetailErrorDescription(ErrorInfo());
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
									Operation, DetailErrorDescription, MessageText, 1);
				AbortSigning = True;
			EndTry;
		EndIf;
		
		If Not AbortSigning Then
			SignaturesData = New Map;
			CountED = DataProcessorData.EDArrayWithSchemas.Count();
			Try
				XMLSchemeDataArray = SerializedData(DataProcessorData.SchemasDataArray);
				XMLSignaturesArray = ExternalAttachableModule.Sign(XMLCertificate, XMLSchemeDataArray);
				SignaturesArray = DeSerializedData(XMLSignaturesArray);
				
				ElectronicDocumentsServiceCallServer.SaveSignaturesData(
					DataProcessorData.EDArrayWithSchemas, SignaturesArray, CertificateStructure.SignatureCertificate);
				
				Parameters.Insert("TotalDigitallySignedCnt", SignaturesArray.Count());
				
				Parameters.Insert("EDArrayForCheckiBank2", Parameters.EDArrayForSignature);
				
				StartCheckingSignartureStatusesiBank2(Parameters);
			Except
				ErrorTemplate = NStr("en='An error occurred when signing documents.
		|Error code:
		|%1 %2';ru='Ошибка подписания документов.
		|Код
		|ошибки: %1 %2'");
				ErrorDetails = InformationAboutErroriBank2();
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
									ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
				Operation = NStr("en='Signing the documents';ru='Подписание документов'");
				DetailErrorDescription = DetailErrorDescription(ErrorInfo());
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
									Operation, DetailErrorDescription, MessageText, 1);
				AbortSigning = True;
			EndTry;
		EndIf;
	EndIf;
	
	DescriptionSignED = Undefined;
	If (AbortSigning OR AuthenticationCompleted <> True)
		AND Parameters.Property("ContinuationHandler", DescriptionSignED)
		AND TypeOf(DescriptionSignED) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(DescriptionSignED);
	EndIf;
	
EndProcedure

// Checks the validity of signatures
//
// Parameters
//  Parameters - Structure - contains data processor parameters
//
Procedure StartCheckingSignartureStatusesiBank2(Parameters) Export
	
	AvailableStorage = AvailableiBank2Storage();
	If Not ValueIsFilled(AvailableStorage) Then
		ND = New NotifyDescription("CheckiBank2SignaturesStatuses", ThisObject, Parameters);
		ChooseiBank2Storage(Parameters.EDAgreement, ND);
	Else
		CheckiBank2SignaturesStatuses(AvailableStorage, Parameters);
	EndIf;
	
EndProcedure

Procedure CheckiBank2SignaturesStatuses(AvailableStorage, Parameters) Export
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	
	ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
		ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()), Undefined);
	
	EDKindsArray = Parameters.EDArrayForCheckiBank2;
	EDArrayStructure = ElectronicDocumentsServiceCallServer.EDContentStructuresArray(EDKindsArray);
	ResultsMatch = New Map;
	For Each EDStructure IN EDArrayStructure Do
		CheckResult = New Array;
		For Each DSRow IN EDStructure.Signatures Do
			RecordStructure = New Structure("LineNumber", DSRow.LineNumber);
			Try
				DSBinaryData = DSRow.Signature;
				XMLCertificate = DSRow.Certificate;
				AdditParameters = New Structure("StorageIdentifier", AvailableStorage);
				DataEDXML = SerializedData(EDStructure.EDData);
				BinaryDataEPXML = SerializedData(DSBinaryData);
				AdditXMLParameters = SerializedData(AdditParameters);
				SignatureValid = ExternalAttachableModule.VerifySignature(
					XMLCertificate, DataEDXML, BinaryDataEPXML, AdditXMLParameters);
				RecordStructure.Insert("Result", SignatureValid);
				CheckResult.Add(RecordStructure);
			Except
				ErrorTemplate = NStr("en='Signature check error.
		|Error code:
		|%1 %2';ru='Ошибка проверки подписи.
		|Код
		|ошибки: %1 %2'");
				ErrorDetails = InformationAboutErroriBank2();
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
									ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
				Operation = NStr("en='Signature check';ru='Проверка подписи'");
				DetailErrorDescription = DetailErrorDescription(ErrorInfo());
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
									Operation, DetailErrorDescription, MessageText, 1);
			EndTry;
		EndDo;
		ResultsMatch.Insert(EDStructure.ED, CheckResult);
	EndDo;
	
	If ResultsMatch.Count() > 0 Then
		ElectronicDocumentsServiceCallServer.HandleSignaturesCheckResultsArray(ResultsMatch);
	EndIf;
	
	DescriptionSignED = Undefined;
	If Parameters.Property("ContinuationHandler", DescriptionSignED)
		AND TypeOf(DescriptionSignED) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(DescriptionSignED);
	EndIf;
	
	If Parameters.Property("NotifyAboutESCheck") Then
		Notify("DSCheckCompleted", EDKindsArray);
	EndIf;
	
EndProcedure

//Receives external interface of external component
//
// Parameters:
//   Parameters - Structure:
//     CRParameters - Structure:
//       TriedToInstallComponent - Boolean - a flag showing previous attempt to set the component.
//       HandlerAfterConnectingComponents  - NotifyDescription - executed after an attempt to connect the component.
//                                               As first parameter (Result)
//                                               AttachableModule of the component is passed in case of successful connection, otherwise - Undefined.
//                                               As the first parameter
//       (Result) AttachableModule Address is passed                                 - String - address of connected component in temporary storage.
//       Name                                   - String - name of connected component.
//       Type                                   - ExternalComponentType.
//       ModuleName                             - String - name of connected component module.
//
Procedure ConnectBankExternalComponent(Parameters) Export
	
	CRParameters = Undefined;
	If Parameters.Property("CRParameters", CRParameters) AND TypeOf(CRParameters) = Type("Structure") Then

		
		ConnectionCompleted = False;
		AttachableModule = Undefined;
		ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
		If ExchangeWithBanksSubsystemsParameters = Undefined Then
			ApplicationParameters.Insert("ExchangeWithBanks.Parameters", New Map);
			ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
		Else
			AttachableModule = ExchangeWithBanksSubsystemsParameters.Get(CRParameters.ModuleName);
		EndIf;
		
		If AttachableModule = Undefined Then
			ExternalComponentAddress = ElectronicDocumentsServiceCallServer.BankExternalComponentAddress(CRParameters.BankApplication);
			NotifyDescription = New NotifyDescription("AfterConnectingBankExternalComponent", ThisObject, Parameters);
			BeginAttachingAddIn(NOTifyDescription, ExternalComponentAddress, CRParameters.Name, CRParameters.Type);
			Return;
		EndIf;
		
		ExecuteNotifyProcessing(CRParameters.HandlerAfterConnectingComponents, AttachableModule);
		
	EndIf;
	
EndProcedure

Procedure EnableExternalComponentiBank2(Parameters) Export
	
	NotifyDescription = Undefined;
	If TypeOf(Parameters) = Type("Structure")
		AND Parameters.Property("HandlerAfterConnectingComponents", NotifyDescription) Then
		Parameters.Delete("HandlerAfterConnectingComponents");
		CRParameters = New Structure;
		CRParameters.Insert("HandlerAfterConnectingComponents", NotifyDescription);
		CRParameters.Insert("ModuleName", iBankName2ComponentName());
		CRParameters.Insert("Name", "iBank2DX");
		CRParameters.Insert("Type", AddInType.Native);
		CRParameters.Insert("BankApplication", PredefinedValue("Enum.BankApplications.iBank2"));
		
		Parameters.Insert("CRParameters", CRParameters);
		ConnectBankExternalComponent(Parameters);
	EndIf;
	
EndProcedure

// Receives the information about the last error from the component
//
// Returns:
//  Structure - contains data:
//    * Code - String - error
//    code * Message - String - Error message for user
//
Function InformationAboutErroriBank2() Export
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	If ExchangeWithBanksSubsystemsParameters <> Undefined
		AND ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()) <> Undefined Then
		
		ExternalAttachableModule = ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName());
		XMLErrorDetails = ExternalAttachableModule.ErrorDetails();
		Return DeSerializedData(XMLErrorDetails);
	EndIf;
	
EndFunction

//Offers user to select the storage and returns the result of the selection
//
// Parameters:
//  EDAgreement  - CatalogRef.EDUsageAgreements - reference to the
//  agreement with bank GS - NotifyDescription - description of application module procedure call that will be executed after storage choice
//
Procedure ChooseiBank2Storage(EDAgreement, ND) Export
	
	Storages = ConnectediBank2Storages();
	
	If Not Storages = Undefined AND Storages.Count() > 0 Then
		ParametersStructure = New Structure("Storages, EDAgreement", Storages, EDAgreement);
		OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.StorageSelection", ParametersStructure, , , , , ND);
	Else
		MessageText = NStr("en='It is required to connect bank key to your computer to execute the operation';ru='Для выполнения операции необходимо подключить банковский ключ к компьютеру'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf
	
EndProcedure

// Receives certificate data as a structure
//
// Parameters
//  XMLCertificate  - String - certificate as a string
//
// Returns:
//  Structure or Undefined -  Certificate data as a structure
//
Function iBank2CertificateData(XMLCertificate) Export
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
		ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()), Undefined);
	
	Try
		XMLCertificateData = ExternalAttachableModule.CertificateData(XMLCertificate);
		CertificateData = DeSerializedData(XMLCertificateData);
	Except
		ErrorTemplate = NStr("en='An error occurred when receiving the certificate data.
		|Error code:
		|%1 %2';ru='Ошибка получения данных сертификата.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = InformationAboutErroriBank2();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Receiving certificate data';ru='Получение данных сертификата'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
			Operation, DetailErrorDescription, MessageText, 1);
		Return Undefined;
	EndTry;
	
	Return CertificateData;
	
EndFunction

Procedure StartSendingiBank2Packages(ExternalAttachableModule, Parameters) Export
	
	If Parameters.Property("CRParameters") Then
		// Delete the parameters from the structure that were used for connection of external component:
		Parameters.Delete("CRParameters");
	EndIf;
	ContinuationHandler = Undefined;
	Parameters.Property("ContinuationHandler", ContinuationHandler);
	AbortSending = True;
	If ExternalAttachableModule <> Undefined Then
		Device = ConnectediBank2Storages();
		If Device.Count() = 0 Then
			MessageText = NStr("en='Bank key is not connected for data sending by EDF setting: %1';ru='К компьютеру не подключен банковский ключ для отправки данных по настройке ЭДО: %1'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, Parameters.EDAgreement);
		Else
			Parameters.Insert("Device", Device);
			ContinueSendingiBank2PackagesRecursively(Parameters);
			AbortSending = False;
		EndIf;
	EndIf;
	
	If AbortSending AND TypeOf(ContinuationHandler) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(ContinuationHandler);
	EndIf;
	
EndProcedure

Procedure ContinueSendingiBank2PackagesRecursively(Parameters)
	
	SendingData = Parameters.DataStructure.DataForiBank2Sending;
	If SendingData.Count() > 0 Then
		Device = Parameters.Device;
		For Each KeyValue IN SendingData Do
			Parameters.Insert("CurrentiBank2SendingData", KeyValue.Value);
			Certificates = KeyValue.Value.Certificates;
			CertificateChoiceList = New Array;
			
			For Each CertificateData IN KeyValue.Value.Certificates Do
				PasswordIsSet = iBank2CertificatePasswordSet(CertificateData.CertificateBinaryData);
				
				If PasswordIsSet Then
					SelectedCertificate = CertificateData.CertificatRef;
					Map = New Map;
					Map.Insert(SelectedCertificate, CertificateData);
					CertificateData.Insert("SelectedCertificate", SelectedCertificate);
					Parameters.Insert("AccCertificatesAndTheirStructures", Map);
					Break;
				EndIf;
			
				iBank2CertificateData = iBank2CertificateData(CertificateData.CertificateBinaryData);
				If Device.Find(iBank2CertificateData.StorageIdentifier) <> Undefined Then
					CertificateChoiceList.Add(CertificateData.CertificatRef);
				EndIf;
			EndDo;
			
			If Not PasswordIsSet Then
				If CertificateChoiceList.Count() = 0 Then
					For Each CertificateData IN Certificates Do
						CertificateChoiceList.Insert(CertificateData.CertificatRef);
					EndDo;
				EndIf;
				Map = New Map;
				For Each Certificate IN CertificateChoiceList Do
					CertificateStructure = ElectronicDocumentsServiceCallServer.CertificateAttributes(Certificate);
					Map.Insert(Certificate, CertificateStructure);
				EndDo;
				
				Parameters.Insert("AccCertificatesAndTheirStructures", Map);
				
				If Not PasswordToCertificateReceived2(Map, NStr("en='Authentication on bank resource';ru='Аутентификация на ресурсе банка.'")) Then
					OOOZ = New NotifyDescription(
						"ContinueSendingPackagesAfterEnteringPasswordToCertificateiBank2", ThisObject, Parameters);
					Parameters.Insert("CallNotification", OOOZ);
					GetPasswordToSertificate(Map, NStr("en='Authentication on bank resource';ru='Аутентификация на ресурсе банка.'"), , , Parameters);
				Else
					// IN PasswordToCertificateReceived2() function the variable
					// Match is overridden, that's why we take the first item of the match - This will be the certificate to which the password is received:
					For Each Item IN Map Do
						CertificateData = Item.Value;
						Break;
					EndDo;
					PasswordIsSet = True;
				EndIf;
			EndIf;
			If PasswordIsSet Then
				ContinueSendingPackagesAfterEnteringPasswordToCertificateiBank2(CertificateData, Parameters);
			EndIf;
			Parameters.DataStructure.DataForiBank2Sending.Delete(KeyValue.Key);
			Break;
		EndDo;
	Else
		ContinuationHandler = Undefined;
		Parameters.Property("ContinuationHandler", ContinuationHandler);
		
		If TypeOf(ContinuationHandler) = Type("NotifyDescription") Then
			ExecuteNotifyProcessing(ContinuationHandler);
		EndIf;
	EndIf;
	
EndProcedure

// Starts the test of agreement after the connection of an external component
//
// Parameters:
//  ExternalComponent - bank external
//  component Parameters  - Structure - contains the parameters
//    of method execution * PurposeIdentifier - Unique identifier - identifier of the
//    form for messages display * EDAgreement - CatalogRef.EDUsageAgreements - agreement with bank
//
Procedure StartiBank2AgreementTest(ExternalComponent, Parameters) Export

	If ExternalComponent = Undefined Then
		Return
	EndIf;

	TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
	
	TargetID = Parameters.TargetID;
	TestDescription = NStr("en='Test. Initialization of bank external component.';ru='Тест. Инициализация внешней компоненты банка.'");
	MessageToUser(TestDescription, TargetID);
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	If ExchangeWithBanksSubsystemsParameters <> Undefined
		AND ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()) <> Undefined Then
		
		MessageToUser(TestResult, TargetID);

		EDAgreement = Parameters.EDAgreement;
		AvailableCertificates = ElectronicDocumentsServiceCallServer.AvailableCertificates(EDAgreement);
		
		Parameters = New Structure;
		Parameters.Insert("CertificateTestIndex", 0);
		Parameters.Insert("AvailableCertificates", AvailableCertificates);
		Parameters.Insert("TargetID", TargetID);
		Parameters.Insert("EDAgreement", EDAgreement);
		
		StartiBank2CertificatesTest(Parameters);
	EndIf;

EndProcedure

Procedure ContinueSendingPackagesAfterEnteringPasswordToCertificateiBank2(Result, Parameters) Export
	
	SelectedCertificate = Undefined;
	BreakProcessing = False;
	If TypeOf(Result) = Type("Structure") AND Result.Property("SelectedCertificate", SelectedCertificate)
		AND TypeOf(SelectedCertificate) = Type("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates") Then
		
		CertificateParameters = Parameters.AccCertificatesAndTheirStructures[SelectedCertificate];
		CertificateParameters.Insert("PasswordReceived", True);
		CertificateParameters.Insert("UserPassword", Result.UserPassword);
		CertificateParameters.Insert("SelectedCertificate", SelectedCertificate);
		CertificateParameters.Insert("Comment", "");
		Result.Property("Comment", CertificateParameters.Comment);
		Parameters.Insert("CertificateStructure", CertificateParameters);
		CurrentiBank2SendingData = Parameters.CurrentiBank2SendingData;
		For Each CertificateData IN CurrentiBank2SendingData.Certificates Do
			If CertificateData.CertificatRef = SelectedCertificate Then
				Break;
			EndIf;
		EndDo;
		
		iBank2CertificateData = iBank2CertificateData(CertificateData.CertificateBinaryData);
		If iBank2CertificateData <> Undefined Then
			Parameters.Insert("SentiBank2Packages", CurrentiBank2SendingData.PacksData);
			Parameters.Insert("ProcedureName", "SendiBank2Packages");
			Parameters.Insert("Module", ThisObject);
			Parameters.Insert("StorageIdentifier", iBank2CertificateData.StorageIdentifier);

			RequiredToSetStoragePINCodeiBank2 = RequiredToSetStoragePINCodeiBank2(
													iBank2CertificateData.StorageIdentifier);
														
			If RequiredToSetStoragePINCodeiBank2 = Undefined Then
				BreakProcessing = True;
			ElsIf RequiredToSetStoragePINCodeiBank2 Then
				OnCloseNotifyDescription = New NotifyDescription(
					"ContinueSendingPackagesAfterEnteringPINCodeiBank2", ThisObject, Parameters);
				StartInstallationPINStorages(
					Parameters.EDAgreement, iBank2CertificateData.StorageIdentifier, OnCloseNotifyDescription);
				Return;
			Else
				ContinueSendingiBank2Packages(Parameters);
			EndIf;
		Else
			BreakProcessing = True;
		EndIf;
	EndIf;
	If BreakProcessing Then
		ContinueSendingiBank2PackagesRecursively(Parameters);
	EndIf;
	
EndProcedure

Procedure ContinueSendingPackagesAfterEnteringPINCodeiBank2(PINCode, Parameters) Export
	
	If PINCode <> Undefined Then
		PINIsSet = SetStoragePINCodeiBank2(Parameters.StorageIdentifier, PINCode);
		If PINIsSet Then
			ContinueSendingiBank2Packages(Parameters);
		Else
			ContinueSendingiBank2PackagesRecursively(Parameters);
		EndIf;
	Else
		ContinueSendingiBank2PackagesRecursively(Parameters);
	EndIf;
	
EndProcedure

Procedure ContinueReceivingStatementAfterEnteringPINCodeiBank2(PINCode, Parameters) Export
	
	If PINCode = Undefined Then
		Return;
	EndIf;
	
	PINIsSet = SetStoragePINCodeiBank2(Parameters.StorageIdentifier, PINCode);
	
	If Not PINIsSet Then
		Return;
	EndIf;
	
	ContinueReceivingiBank2Statement(Parameters);
	
EndProcedure

Procedure ContinueReceivingStatementAfterEnteringiBank2CertificatePassword(Result, Parameters) Export
	
	SelectedCertificate = Undefined;
	AccCertificatesAndTheirStructures = Undefined;
	If TypeOf(Result) = Type("Structure") AND Result.Property("SelectedCertificate", SelectedCertificate)
		AND TypeOf(SelectedCertificate) = Type("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates") Then
		
		CertificatesData = Parameters.CertificatesData;
		
		For Each CertificateData IN CertificatesData Do
			If CertificateData.Certificate = SelectedCertificate Then
				CertificateData.Insert("PasswordReceived", True);
				CertificateData.Insert("UserPassword", Result.UserPassword);
				CertificateData.Insert("SelectedCertificate", SelectedCertificate);
				CertificateData.Insert("Comment", "");
				Result.Property("Comment", CertificateData.Comment);
				Break;
			EndIf;
		EndDo;
		
		iBank2CertificateData = iBank2CertificateData(CertificateData.CertificateBinaryData);
		If iBank2CertificateData <> Undefined Then
			Parameters.Insert("ProcedureName", "ContinueReceivingStatement");
			Parameters.Insert("Module", ThisObject);
			Parameters.Insert("CertificateData", CertificateData);
			Parameters.Insert("UserPassword", Result.UserPassword);
			Parameters.Insert("StorageIdentifier", iBank2CertificateData.StorageIdentifier);
			
			PINCodeRequired = RequiredToSetStoragePINCodeiBank2(iBank2CertificateData.StorageIdentifier);
				
			If PINCodeRequired = False Then
				ContinueReceivingiBank2Statement(Parameters)
			ElsIf PINCodeRequired Then
				OnCloseNotifyDescription = New NotifyDescription(
					"ContinueReceivingStatementAfterEnteringPINCodeiBank2", ThisObject, Parameters);
				StartInstallationPINStorages(
					Parameters.EDAgreement, iBank2CertificateData.StorageIdentifier, OnCloseNotifyDescription);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure ContinueiBank2AgreementTest(Parameters)
	
	TargetID = Parameters.TargetID;
	XMLCertificate = Parameters.XMLCertificate;
	UserPassword = Parameters.UserPassword;
	EDAgreement = Parameters.EDAgreement;
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
		ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()), Undefined);
	
	TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
	
	If Parameters.Property("PINCodeSet") Then
		MessageToUser(TestResult, TargetID);
	EndIf;
	
	// Block of authorization check on bank resource.
	TestDescription = NStr("en='Test. Authentication on bank resource.';ru='Тест. Аутентификация на ресурсе банка.'");
	MessageToUser(TestDescription, TargetID);
	OperationKind = NStr("en='Authentication on bank resource';ru='Аутентификация на ресурсе банка.'");
	Try
		ExternalAttachableModule.SetCertificatePassword(XMLCertificate, UserPassword);
	Except
		ErrorTemplate = NStr("en='Authorization error on bank resource.
		|Error code:
		|%1 %2';ru='Ошибка авторизации на ресурсе банка.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = InformationAboutErroriBank2();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Authentication on bank resource';ru='Аутентификация на ресурсе банка.'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
			Operation, DetailErrorDescription, MessageText, 1);
		Return;
	EndTry;
	MessageToUser(TestResult, TargetID);
	
	// Block of check of connection with bank.
	TestDescription = NStr("en='Test. Connecting with bank.';ru='Тест. Установка соединения с банком.'");
	MessageToUser(TestDescription, TargetID);
	
	NotifyDescription = New NotifyDescription("ContinueAgreementTestAfterAutenticationiBank2", ThisObject, Parameters);
	EstablishConnectioniBank2(EDAgreement, XMLCertificate, NotifyDescription);
	
EndProcedure

Procedure ContinueAgreementTestAfterAutenticationiBank2(AuthenticationCompleted, Parameters) Export
	
	TargetID = Parameters.TargetID;
	CertificateParameters = Parameters.CertificateParameters;
	XMLCertificate = Parameters.XMLCertificate;
	CertificateData = Parameters.CertificateData;
	
	If Not AuthenticationCompleted = True Then
		Return;
	EndIf;
	
	TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");

	MessageToUser(TestResult, TargetID);
		
	// Block for checking the setting of signature for data.
	TestDescription = NStr("en='Test. Setting the signature.';ru='Тест. Установка подписи.'");
	MessageToUser(TestDescription, TargetID);
	PrintBase64 = ElectronicDocumentsServiceCallServer.Base64StringWithoutBOM(CertificateParameters.Imprint);
	BinaryData = Base64Value(PrintBase64);
	SignatureArray = New Array;
	SignatureArray.Add(BinaryData);
	ParametersSignatures = New Structure("Password", CertificateParameters.UserPassword);
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
		ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()), Undefined);
		
	Try
		XMLSignatureArray = SerializedData(SignatureArray);
		XMLSignaturesArray = ExternalAttachableModule.Sign(XMLCertificate, XMLSignatureArray);
		SignaturesArray = DeSerializedData(XMLSignaturesArray);
	Except
		ErrorTemplate = NStr("en='Signature setup error.
		|Error code:
		|%1 %2';ru='Ошибка установки подписи.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = InformationAboutErroriBank2();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Setting the signature';ru='Установка подписии'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
							Operation, DetailErrorDescription, MessageText, 1);
		Return;
	EndTry;
	MessageToUser(TestResult, TargetID);
	
	// Signature check module.
	TestDescription = NStr("en='Test. Signature checkup.';ru='Тест. Проверка подписи.'");
	MessageToUser(TestDescription, TargetID);
	Try
		AdditParameters = New Structure("StorageIdentifier", CertificateData.StorageIdentifier);
		AdditXMLParameters = SerializedData(AdditParameters);
		XMLBinaryData = SerializedData(BinaryData);
		SignatureXML = SerializedData(SignaturesArray[0]);
		SignatureValid = ExternalAttachableModule.VerifySignature(
			XMLCertificate, XMLBinaryData, SignatureXML, AdditXMLParameters);
	Except
		ErrorTemplate = NStr("en='Signature check error.
		|Error code:
		|%1 %2';ru='Ошибка проверки подписи.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = InformationAboutErroriBank2();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
			ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Signature check';ru='Проверка подписи'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
							Operation, DetailErrorDescription, MessageText, 1);
		Return;
	EndTry;
	If Not SignatureValid Then
		MessageToUser(NStr("en='Signature is not valid';ru='Подпись не валидна'"), TargetID);
		Return;
	EndIf;
	MessageToUser(TestResult, TargetID);

	StartiBank2CertificatesTest(Parameters);
	
EndProcedure

Procedure ContinueAgreementTestAfterEnteringPINCodeiBank2(PINCode, Parameters) Export

	If PINCode = Undefined Then
		Return;
	EndIf;
	
	PinCodeSet = SetStoragePINCodeiBank2(Parameters.StorageIdentifier, PINCode);
	
	If Not PinCodeSet Then
		Return;
	EndIf;
	
	ContinueiBank2AgreementTest(Parameters)
	
EndProcedure

Procedure ContinueAgreementTestAfterEnteringPasswordToiBank2Certificate(ReturnParameter, Parameters) Export
	
	TargetID = Parameters.TargetID;
	
	If Parameters.AccCertificatesAndTheirStructures.Count() = 0 Then
		MessageText = NStr("en='Password for certificate is not provided.
		|Test is interrupted.';ru='Не введен пароль для сертификата.
		|Тест прерван.'");
		MessageToUser(MessageText, TargetID);
		Return;
	EndIf;
	
	For Each KeyAndValue IN Parameters.AccCertificatesAndTheirStructures Do
		CertificateParameters = KeyAndValue.Value;
		UserPassword = CertificateParameters.UserPassword;
		SelectedCertificate = KeyAndValue.Key;
		Break;
	EndDo;

	EDAgreement = Parameters.EDAgreement;
	
	TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
	
	XMLCertificate = CertificateParameters.CertificateBinaryData;
		
	// Block of certificate data reading.
	TestDescription = NStr("en='Test. Certificate data reading.';ru='Тест. Чтение данных сертификата.'");
	MessageToUser(TestDescription, TargetID);
	CertificateData = iBank2CertificateData(XMLCertificate);
	If CertificateData = Undefined Then
		Return;
	EndIf;
	MessageToUser(TestResult, TargetID);
	
	// Block for checking the existence of set PIN code.
	TestDescription = NStr("en='Test. Check the existence of PIN code in the storage.';ru='Тест. Проверка наличия PIN-кода на хранилище.'");
	MessageToUser(TestDescription, TargetID);
	PINRequired = RequiredToSetStoragePINCodeiBank2(CertificateData.StorageIdentifier);
	If PINRequired = Undefined Then
		Return;
	EndIf;
	MessageToUser(TestResult, TargetID);
	
	Parameters.Insert("XMLCertificate", XMLCertificate);
	Parameters.Insert("UserPassword", UserPassword);
	Parameters.Insert("CertificateData", CertificateData);
	Parameters.Insert("ProcedureName", "ContinueAgreementTestAfterAutenticationiBank2");
	Parameters.Insert("Module", ThisObject);
	Parameters.Insert("CertificateParameters", CertificateParameters);
	Parameters.Insert("StorageIdentifier", CertificateData.StorageIdentifier);
	
	// Block of PIN code setting check.
	If PINRequired Then
		TestDescription = NStr("en='Test. Setting PIN code to the storage.';ru='Тест. Установка PIN-кода на хранилище.'");
		MessageToUser(TestDescription, TargetID);
		FormParameters = New Structure;
		FormParameters.Insert("StorageIdentifier", CertificateData.StorageIdentifier);
		FormParameters.Insert("EDAgreement", EDAgreement);
		Parameters.Insert("PINCodeSet");
		OOOZ = New NotifyDescription("ContinueAgreementTestAfterEnteringPINCodeiBank2", ThisObject, Parameters);
		OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.PINCodeRequest", FormParameters, , , , , OOOZ);
		Return;
	EndIf;
	ContinueiBank2AgreementTest(Parameters);
	
EndProcedure

Procedure ContinueReceivingiBank2Statement(Parameters)
	
	CertificateData = Parameters.CertificateData;
	UserPassword = Parameters.UserPassword;
	
	PasswordIsSet = SetiBank2CertificatePassword(CertificateData.CertificateBinaryData, UserPassword);
	If Not PasswordIsSet Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("ContinueReceivingStatement", ThisObject, Parameters);
	EstablishConnectioniBank2(Parameters.EDAgreement, CertificateData.CertificateBinaryData, NotifyDescription);
	
EndProcedure

Procedure ContinueSendingiBank2Packages(Parameters)
	
	CertificateStructure = Parameters.CertificateStructure;
	UserPassword = CertificateStructure.UserPassword;
	EDAgreement = Parameters.EDAgreement;
	CertificateXMLiBank2 = CertificateStructure.CertificateBinaryData;
	
	PasswordIsSet = SetiBank2CertificatePassword(CertificateXMLiBank2, UserPassword);
	If PasswordIsSet Then
		NotifyDescription = New NotifyDescription("SendiBank2Packages", ThisObject, Parameters);
		EstablishConnectioniBank2(EDAgreement, CertificateXMLiBank2, NotifyDescription);
	Else
		ContinueSendingiBank2PackagesRecursively(Parameters);
	EndIf;
	
EndProcedure

Procedure StartiBank2CertificatesTest(Parameters)
	
	AvailableCertificates = Parameters.AvailableCertificates;
	TargetID = Parameters.TargetID;
	EDAgreement = Parameters.EDAgreement;
	TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
	
	CurrentIndex = 0;
	For Each Item IN AvailableCertificates Do
		
		CurrentIndex = CurrentIndex + 1;
		If CurrentIndex <= Parameters.CertificateTestIndex Then
			Continue;
		EndIf;
		Parameters.CertificateTestIndex = CurrentIndex;
		
		CertificateParameters = Item.Value;
		
		MessageText = NStr("en='Checking the certificate: %1';ru='Проверка сертификата: %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, Item.Key);
		MessageToUser(MessageText, TargetID);
		
		Map = New Map;
		Map.Insert(Item.Key, CertificateParameters);
		
		Parameters.Insert("AccCertificatesAndTheirStructures", Map);
		
		If Not PasswordToCertificateReceived2(Map, NStr("en='Authentication on bank resource';ru='Аутентификация на ресурсе банка.'")) Then
			OOOZ = New NotifyDescription("ContinueAgreementTestAfterEnteringPasswordToiBank2Certificate", ThisObject);
			Parameters.Insert("CallNotification", OOOZ);
			GetPasswordToSertificate(Map, NStr("en='Authentication on bank resource';ru='Аутентификация на ресурсе банка.'"), , , Parameters);
			Return;
		EndIf;
		
		ContinueAgreementTestAfterEnteringPasswordToiBank2Certificate(Undefined, Parameters);
		Return;
	EndDo;
	
	If AvailableCertificates.Count() = 0 Then
		MessageText = NStr("en='Check is not completed due to there are no signature certificates in the agreement';ru='Проверка проведена не полностью, т.к. в соглашении отсутствуют сертификаты подписи'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	// Block of test request sending check.
	TestDescription = NStr("en='Test. Sending test request.';ru='Тест. Отправка тестового запроса.'");
	MessageToUser(TestDescription, TargetID);
	
	XMLCertificate = Parameters.XMLCertificate;
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
		ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()), Undefined);
	
	Try
		ExternalAttachableModule.SendRequest("1", Undefined);
	Except
		ErrorTemplate = NStr("en='An error occurred when sending a test request.
		|Error code:
		|%1 %2';ru='Ошибка отправки тестового запроса.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = InformationAboutErroriBank2();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Sending a test request';ru='Отправка тестового запроса'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
			Operation, DetailErrorDescription, MessageText, 1);
		Return;
	EndTry;
	MessageToUser(TestResult, TargetID);
	
EndProcedure

Function iBank2CertificatePasswordCacheIsRelevant(CertificateData, EDKindsArray)
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
		ExchangeWithBanksSubsystemsParameters.Get(iBankName2ComponentName()), Undefined);

	CertificateAttributes = ElectronicDocumentsServiceCallServer.CertificateAttributes(
													CertificateData.SignatureCertificate);
	
	CertificateServiceData = iBank2CertificateData(CertificateAttributes.CertificateBinaryData);
		
	If CertificateServiceData = Undefined Then
		Return False;
	EndIf;

	RequiredToSetPINCodeForiBank2Storage = RequiredToSetStoragePINCodeiBank2(
										CertificateServiceData.StorageIdentifier);
	If Not RequiredToSetPINCodeForiBank2Storage = False Then
		Return False;
	EndIf;
	
	Try
		XMLCertificateData = SerializedData(CertificateAttributes.CertificateBinaryData);
		RequiredToSetCertificatePassword = ExternalAttachableModule.RequiredToSetCertificatePassword(
																							XMLCertificateData);
		Return RequiredToSetCertificatePassword = False;
	Except
		Return False;
	EndTry;

EndFunction

Function AvailableiBank2Storage()
	
	Storages = ConnectediBank2Storages();
	
	If Storages = Undefined Then
		Return Undefined;
	EndIf;
	
	For Each StorageIdentifier IN Storages Do
		
		If Not RequiredToSetStoragePINCodeiBank2(StorageIdentifier) Then
			
			Return StorageIdentifier;
			
		EndIf;
		
	EndDo
	
EndFunction

Function AvailableStorageThroughAdditionalDataProcessor(ExternalAttachableModule)
	
	Storages = ConnectedStoragesThroughAdditionalDataProcessor(ExternalAttachableModule);
	
	If Storages = Undefined Then
		Return Undefined;
	EndIf;
	
	For Each StorageIdentifier IN Storages Do
		
		If Not RequiredToSetStoragePINCodeThroughAdditionalDataProcessor(ExternalAttachableModule, StorageIdentifier)
			OR StoragePINCodeIsSetThroughAdditionalDataProcessor(ExternalAttachableModule, StorageIdentifier) Then
			
			Return StorageIdentifier;
			
		EndIf;
		
	EndDo
	
EndFunction

#EndRegion

#Region ExchangeWithBanksThroughAdditDataProcessor

// Called from ContinueSigningBankED, ElectronicDocumentsClient.GetBankStatement,
// StartCheckingSignaturesStatusesThroughAdditionalDataProcessor,
// SendThroughAdditionalDataProcessor, SendDocumentsToBank, EDAttachedFiles.EDViewForm
// and by alert processor from BeginInstallAddIn.
// Receives external module to sign ED through additional data processor and goes to ED signing.
//
// Parameters:
//    Parameters - Structure:
//       EDAgreement                        - CatalogRef.EDUsageAgreements - EDF
//                                           setting by which the signing is executed.
//       RunTryReceivingModule   - Boolean - True if the procedure is
//                                           called recursively after an attempt to get external plugin module.
//       AfterObtainingDataProcessorModule       - NotifyDescription - description to be
//                                           executed after receiving external connected module.
//
Procedure GetExternalModuleThroughAdditionalProcessing(Parameters) Export
	
	BreakProcessing = True;
	ExternalAttachableModule = ExternalConnectedModuleThroughAdditionalDataProcessor(Parameters.EDAgreement);
	If ExternalAttachableModule = Undefined Then
		TriedToConnect = Parameters.RunTryReceivingModule;
		If TriedToConnect = False Then
			ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
			If ExchangeWithBanksSubsystemsParameters <> Undefined Then
				AgreementParameters = ExchangeWithBanksSubsystemsParameters.Get(Parameters.EDAgreement);
				If ValueIsFilled(AgreementParameters) AND AgreementParameters.Property("ComponentAddress") Then
					AbortSigning = False;
					Parameters.RunTryReceivingModule = True;
					ND = New NotifyDescription("GetExternalModuleThroughAdditionalProcessing", ThisObject, Parameters);
					BeginInstallAddIn(ND, AgreementParameters.ComponentAddress);
					BreakProcessing = False;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	NotificationProcessing = Undefined;
	If BreakProcessing AND Parameters.Property("AfterObtainingDataProcessorModule", NotificationProcessing)
		AND TypeOf(NotificationProcessing) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(NotificationProcessing, ExternalAttachableModule);
	EndIf;
	
EndProcedure

// Checks the need to set PIN code
//
// Parameters:
//  ExternalAttachableModule  - Managed Form - external managed
//  form StorageIdentifier  - String - storage identifier
//
// Returns:
//   Boolean, Undefined - True - pin code is already set or not required, False - required to set
//                          up pin code, Undefined - an error occurred when determining the need for pin code
//
Function NeedToSetStoragePINCodeThroughAdditionalDataProcessor(ExternalAttachableModule, StorageIdentifier) Export
	
	PINRequired = RequiredToSetStoragePINCodeThroughAdditionalDataProcessor(
								ExternalAttachableModule, StorageIdentifier);
	
	If PINRequired = Undefined Then
		Return Undefined;
	EndIf;
	
	If PINRequired Then
		
		StoragePINCodeIsSet = StoragePINCodeIsSetThroughAdditionalDataProcessor(
										ExternalAttachableModule, StorageIdentifier);
	
		If StoragePINCodeIsSet = Undefined Then
			Return Undefined;
		EndIf;
		
		Return Not StoragePINCodeIsSet;
		
	EndIf;
	
	Return False;
	
EndFunction

Function CertificatePasswordIsSetThroughAdditionalDataProcessor(ExternalAttachableModule, XMLCertificate) Export
	
	Try
		CertificatePasswordSet = ExternalAttachableModule.CertificatePasswordSet(XMLCertificate) = True;
	Except
		CertificatePasswordSet = False;
	EndTry;

	Return CertificatePasswordSet;
	
EndFunction

// Sets PIN code for access to bank key
//
// Parameters
//  ExternalAttachableModule - ManagedForm - external application
//  interface StorageIdentifier  - String - identifier
//  of storage PinCode  - String - PIN code
//
// Returns:
//  Boolean -  PIN code is set successfully or not
//
Function SetStoragePINCodeThroughAdditionalDataProcessor(ExternalAttachableModule, StorageIdentifier, PinCode) Export
	
	PinCodeSet = True;
	
	Try
		ExternalAttachableModule.SetStoragePINCode(StorageIdentifier, PinCode);
	Except
		ErrorTemplate = NStr("en='PIN code setup error.
		|Error code:
		|%1 %2';ru='PIN code setup error.
		|Error code:
		|%1 %2'");
		ErrorDetails = ExternalAttachableModule.ErrorDetails();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorTemplate,
		                                                                         ErrorDetails.Code,
		                                                                         ErrorDetails.Message);
		Operation = NStr("en='Setting PIN-code';ru='Установка PIN-кода'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation,
		                                                                            DetailErrorDescription,
		                                                                            MessageText,
		                                                                            1);
		PinCodeSet = False;
	EndTry;
	
	Return PinCodeSet;
	
EndFunction


/////////////////////////////////////////
// Receiving statement through additional data processor:


// Called from ElectronicDocumentsClient.GetBankStatement
// and by notification processor, from GetExternalModuleThroughAdditionalProcessing.
// Receives external module for ED signing through additional data processor and goes to obtain bank statement.
//
// Parameters:
//    ExternalAttachableModule - External plugin.
//    Parameters                 - Structure:
//       EDAgreement - CatalogRef.EDUsageAgreements - EDF
//                    setting with which the statement is received.
//       AccountNo   - String - company bank account number. If it is not specified, then a request for all accounts.
//       StartDate    - Date.
//       EndDate - Date.
//       Owner      - Form or form item - notification recipient of an item selection - Bank .
//
Procedure GetStatementThroughAdditionalDataProcessor(ExternalAttachableModule, Parameters) Export
	
	If ExternalAttachableModule <> Undefined Then
		EDAgreement = Parameters.EDAgreement;
		CertificatesData = ElectronicDocumentsServiceCallServer.BankCertificatesData(EDAgreement);
		
		Device = ConnectedStoragesThroughAdditionalDataProcessor(ExternalAttachableModule);
		
		ChoiceList = New Array;
		Map = New Map;
		CertificatePasswordSet = False;
		If Device.Count() > 0 Then
			For Each CertificateData IN CertificatesData Do
				CertificateDataThroughAdditionalDataProcessor = CertificateDataThroughAdditionalDataProcessor(
													ExternalAttachableModule, CertificateData.CertificateBinaryData);
				If Device.Find(CertificateDataThroughAdditionalDataProcessor.StorageIdentifier) <> Undefined Then
					Map.Insert(CertificateData.Certificate, CertificateData);
					CertificatePasswordSet = CertificatePasswordIsSetThroughAdditionalDataProcessor(
											ExternalAttachableModule, CertificateData.CertificateBinaryData);
					If CertificatePasswordSet Then
						Break;
					EndIf
				EndIf;
			EndDo
		Else
			MessageText = NStr("en='It is required to connect bank key to your computer to execute the operation';ru='Для выполнения операции необходимо подключить банковский ключ к компьютеру'");
			CommonUseClientServer.MessageToUser(MessageText);
			Return
		EndIf;
		
		Parameters.Insert("AccCertificatesAndTheirStructures", Map);
		Parameters.Insert("CertificatesData", CertificatesData);
		Parameters.Insert("ExternalAttachableModule", ExternalAttachableModule);
		
		OperationKind = NStr("en='Authentication on bank resource';ru='Аутентификация на ресурсе банка.'");
		If CertificatePasswordSet Then
			SelectedCertificate = Undefined;
			If Not (CertificateData.Property("SelectedCertificate")
				AND TypeOf(SelectedCertificate) = Type("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates")) Then
				
				CertificateData.Insert("SelectedCertificate", CertificateData.Certificate);
			EndIf;
			ContinueReceivingStatementAfterEnteringCertificatePasswordThroughAdditionalDataProcessor(CertificateData, Parameters)
		Else
			If Map.Count() > 0 Then
				If Not PasswordToCertificateReceived2(Map, OperationKind) Then
					ND = New NotifyDescription(
						"ContinueReceivingStatementAfterEnteringCertificatePasswordThroughAdditionalDataProcessor", ThisObject, Parameters);
					Parameters.Insert("CallNotification", ND);
					GetPasswordToSertificate(Map, OperationKind, , , Parameters);
					Return;
				EndIf;
			Else
				MessageText = NStr("en='Unsuitable bank key is connected to the computer';ru='К компьютеру подключен не подходящий банковский ключ'");
				CommonUseClientServer.MessageToUser(MessageText);
				Return;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Called from ElectronicDocumentsClient.GetBankStatement
// and by notification processor, from GetExternalModuleThroughAdditionalProcessing.
// Receives external module for ED signing through additional data processor and goes to obtain bank statement.
//
// Parameters:
//    Result - Structure, Undefined - if
//              the structure, then the procedure was called after the receipt of password for the certificate:
//       SelectedCertificate - CatalogRef.DigitalSignatureAndEncryptionKeyCertificates.
//       Comment         - String.
//       UserPassword  - String.
//       User        - CatalogRef.Users, Undefined.
//    Parameters - Structure:
//       AccCertificatesAndTheirStructures - Matching.
//       CertificatesData           - Structure.
//       ExternalAttachableModule    - External plugin.
//       EDAgreement                 - CatalogRef.EDUsageAgreements - EDF
//                                    setting with which the statement is received.
//       AccountNo                   - String - company bank account number. If it is not specified, then a request for all accounts.
//       Owner                     - Form or form item - notification recipient of an item selection - Bank .
//       StartDate                   - Date.
//       EndDate                - Date.
//
Procedure ContinueReceivingStatementAfterEnteringCertificatePasswordThroughAdditionalDataProcessor(Result, Parameters) Export
	
	SelectedCertificate = Undefined;
	If TypeOf(Result) = Type("Structure") AND Result.Property("SelectedCertificate", SelectedCertificate)
		AND TypeOf(SelectedCertificate) = Type("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates") Then
		
		AccCertificatesAndTheirStructures = Parameters.AccCertificatesAndTheirStructures;
		EDAgreement = Parameters.EDAgreement;
		
		If AccCertificatesAndTheirStructures.Count() > 0 Then
			CertificatesData = Parameters.CertificatesData;
			ExternalAttachableModule = Parameters.ExternalAttachableModule;
			
			For Each CertificateData IN CertificatesData Do
				If CertificateData.Certificate = SelectedCertificate Then
					Break;
				EndIf;
			EndDo;
			
			CertificateDataThroughAdditionalDataProcessor = CertificateDataThroughAdditionalDataProcessor(
											ExternalAttachableModule, CertificateData.CertificateBinaryData);
			If CertificateDataThroughAdditionalDataProcessor <> Undefined Then
				Parameters.Insert("ProcedureName", "ContinueReceivingStatement");
				Parameters.Insert("Module", ThisObject);
				Parameters.Insert("CertificateData", CertificateData);
				Parameters.Insert("UserPassword", Result.UserPassword);
				Parameters.Insert("StorageIdentifier", CertificateDataThroughAdditionalDataProcessor.StorageIdentifier);
				
				PINCodeRequired = NeedToSetStoragePINCodeThroughAdditionalDataProcessor(
					ExternalAttachableModule, CertificateDataThroughAdditionalDataProcessor.StorageIdentifier);
					
				If PINCodeRequired = False Then
					ContinueReceivingStatementThroughAdditionalDataProcessor(Parameters);
				ElsIf PINCodeRequired = True Then
					OnCloseNotifyDescription = New NotifyDescription(
						"ContinueReceivingStatementAfterEnteringPINCodeThroughAdditionalDataProcessor", ThisObject, Parameters);
					StartInstallationPINStorages(
						EDAgreement, CertificateDataThroughAdditionalDataProcessor.StorageIdentifier, OnCloseNotifyDescription);
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure ContinueReceivingStatementAfterEnteringPINCodeThroughAdditionalDataProcessor(PINCode, Parameters) Export
	
	ExternalAttachableModule = Parameters.ExternalAttachableModule;
	
	If PINCode = Undefined Then
		Return;
	EndIf;
	
	PINSet = SetStoragePINCodeThroughAdditionalDataProcessor(
		ExternalAttachableModule, Parameters.StorageIdentifier, PINCode);
		
	If Not PINSet Then
		Return;
	EndIf;
	
	EDAgreement = Parameters.EDAgreement;
	
	CertificateData = Parameters.CertificateData;
	UserPassword = Parameters.UserPassword;
	
	PasswordIsSet = SetCertificatePasswordThroughAdditionalDataProcessor(
		ExternalAttachableModule, CertificateData.CertificateBinaryData, UserPassword);
	If Not PasswordIsSet Then
		Return;
	EndIf;
	
	ConnectionEstablished = False;
	EstablishConnectionThroughAdditionalDataProcessor(EDAgreement, ExternalAttachableModule,
							CertificateData.CertificateBinaryData, Parameters, ConnectionEstablished);
	If Not ConnectionEstablished Then
		Return;
	EndIf;
	
	ContinueReceivingStatement(ConnectionEstablished, Parameters);
	
EndProcedure

Procedure ContinueReceivingStatement(AuthenticationCompleted, Parameters) Export
	
	FormParameters = New Structure;
	
	FormParameters.Insert("EDAgreement", Parameters.EDAgreement);
	FormParameters.Insert("CertificateData", Parameters.CertificateData);
	FormParameters.Insert("StartDate", Parameters.StartDate);
	FormParameters.Insert("EndDate", Parameters.EndDate);

	OpenForm(
		"DataProcessor.ElectronicDocumentsExchangeWithBank.Form.RequestToBank", FormParameters, Parameters.Owner);
	
EndProcedure


//////////////////////////////////////////////////////////////
// Sending the packages of banking documents through additional data processor:


// Called from ExecuteActionsAfterSendingEDPComplete.
// Recursive processing (sending) of banking documents.
//
// Parameters:
//    Result - Number, Undefined.
//    Parameters - Structure:
//       HandlerAfterSendingEDP - NotifyDescription - description to be
//                                  executed when all data for sending will be processed (DataForSending).
//       DataForSending          - Map
//          key     - CatalogRef.EDUsageAgreements - EDF
//                   setting by which the documents shall be sent.
//          Value - Structure:
//             Packagesdata - Matching.
//             Certificates   - Array - structure of certificates data.
//       PreparedCnt - Number.
//       SentCnt   - Number.
//
Procedure SendThroughAdditionalDataProcessor(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Number") Then
		Parameters.SentCnt = Parameters.SentCnt + Result;
	EndIf;
	
	DataForSending = Undefined;
	If Not Parameters.Property("DataForSending", DataForSending)
		OR DataForSending.Count() = 0 Then
		
		ExecuteNotifyProcessing(Parameters.HandlerAfterSendingEDP, Parameters);
	Else
		For Each KeyAndValue IN DataForSending Do
			// SendingStructure will
			// be transferred to procedure StartSendingPackagesThroughAdditionalDataProcessor after receiving external module.
			SendingStructure = New Structure;
			SendingStructure.Insert("EDAgreement",          KeyAndValue.Key);
			SendingStructure.Insert("DataForSending",     KeyAndValue.Value);
			SendingStructure.Insert("TotalSentCnt",   0);
			SendingStructure.Insert("TotalPreparedCnt", 0);
			
			Parameters.DataForSending.Delete(KeyAndValue.Key);
			// ContinuationHandler - recursive call of current
			// procedure to continue sending the next item DataForSending.
			ContinuationHandler = New NotifyDescription("SendThroughAdditionalDataProcessor", ThisObject, Parameters);
			SendingStructure.Insert("ContinuationHandler", ContinuationHandler);
			
			// ConnectionStructure is required to get an external module.
			ConnectionStructure = New Structure;
			ConnectionStructure.Insert("EDAgreement",      KeyAndValue.Key);
			ConnectionStructure.Insert("RunTryReceivingModule", False);
			
			HandlerAfterConnecting = New NotifyDescription("StartSendingPackagesThroughAdditionalDataProcessor",
				ThisObject, SendingStructure);
			ConnectionStructure.Insert("AfterObtainingDataProcessorModule", HandlerAfterConnecting);
			
			GetExternalModuleThroughAdditionalProcessing(ConnectionStructure);
		EndDo;
	EndIf;
	
EndProcedure

// Called from GetExternalModuleThroughAdditionalDataProcessor by notification description,
// 
// 
// Parameters:
//    ExternalAttachableModule - External plugin.
//    Parameters - Structure:
//       ContinuationHandler - NotificationDescription.
//       DataForSending     - Structure:
//          PacksData - Matching.
//          Certificates   - Array.
//       EDAgreement          - CatalogRef.EDExchangeAgreements.
//       TotalPreparedCnt - Number.
//       TotalSentCnt   - Number.
//       AuthorizationParameters  - Matching.
//       WantedAuthorization  - Boolean.
//
Procedure StartSendingPackagesThroughAdditionalDataProcessor(ExternalAttachableModule, Parameters) Export
	
	BreakProcessing = True;
	If ExternalAttachableModule <> Undefined Then
		SendingData = Parameters.DataForSending;
		
		Parameters.Insert("ExternalAttachableModule", ExternalAttachableModule);
		Device = ConnectedStoragesThroughAdditionalDataProcessor(ExternalAttachableModule);
		
		CertificateChoiceList = New Array;
		
		If Device.Count() > 0 Then
			For Each CertificateData IN SendingData.Certificates Do
				PasswordIsSet = CertificatePasswordIsSetThroughAdditionalDataProcessor(
								ExternalAttachableModule, CertificateData.CertificateBinaryData);
				If PasswordIsSet Then
					Map = New Map;
					CertificateStructure = ElectronicDocumentsServiceCallServer.CertificateAttributes(
																		CertificateData.CertificatRef);
					Map.Insert(CertificateData.CertificatRef, CertificateStructure);
					Parameters.Insert("AccCertificatesAndTheirStructures", Map);
					Break;
				EndIf;
			
				CertificateContent = CertificateDataThroughAdditionalDataProcessor(
						ExternalAttachableModule, CertificateData.CertificateBinaryData);
				If Device.Find(CertificateContent.StorageIdentifier) <> Undefined Then
					CertificateChoiceList.Add(CertificateData.CertificatRef);
				EndIf;
			EndDo;
			
			Parameters.Insert("CertificateData", CertificateData);
			
			If Not PasswordIsSet Then
				If CertificateChoiceList.Count() = 0 Then
					For Each CertificateData IN SendingData.Certificates Do
						CertificateChoiceList.Insert(CertificateData.CertificatRef);
					EndDo;
				EndIf;
				Map = New Map;
				For Each Certificate IN CertificateChoiceList Do
					CertificateStructure = ElectronicDocumentsServiceCallServer.CertificateAttributes(Certificate);
					Map.Insert(Certificate, CertificateStructure);
				EndDo;
				
				Parameters.Insert("AccCertificatesAndTheirStructures", Map);
				
				If PasswordToCertificateReceived2(Map, NStr("en='Authentication on bank resource';ru='Аутентификация на ресурсе банка.'")) Then
					// IN PasswordToCertificateReceived2() function the variable
					// Match is overridden, that's why we take the first item of the match - This will be the certificate to which the password is received:
					For Each Item IN Map Do
						CertificateData = Item.Value;
						Break;
					EndDo;
					PasswordIsSet = True;
				Else
					OOOZ = New NotifyDescription(
						"ContinueSendingPackagesAfterEnteringCertificatePasswordThroughAdditionalDataProcessor", ThisObject, Parameters);
					Parameters.Insert("CallNotification", OOOZ);
					GetPasswordToSertificate(Map, NStr("en='Authentication on bank resource';ru='Аутентификация на ресурсе банка.'"), , , Parameters);
					BreakProcessing = False;
				EndIf;
			EndIf;
			If PasswordIsSet Then
				SelectedCertificate = Undefined;
				If Not (CertificateData.Property("SelectedCertificate")
					AND TypeOf(SelectedCertificate) = Type("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates")) Then
					
					CertificateData.Insert("SelectedCertificate", CertificateData.CertificatRef);
				EndIf;
				ContinueSendingPackagesAfterEnteringCertificatePasswordThroughAdditionalDataProcessor(CertificateData, Parameters);
				BreakProcessing = False;
			EndIf;
		Else
			MessageText = NStr("en='Bank key is not connected for data sending by EDF setting: %1';ru='К компьютеру не подключен банковский ключ для отправки данных по настройке ЭДО: %1'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, Parameters.EDAgreement);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	
	ContinuationHandler = Undefined;
	If BreakProcessing AND Parameters.Property("ContinuationHandler", ContinuationHandler)
		AND TypeOf(ContinuationHandler) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(ContinuationHandler, Parameters.TotalSentCnt);
	EndIf;
	
EndProcedure

// Called from
// StartSendingPackagesThroughAdditionalDataProcessor and according to the description of the alert from GetPasswordToCertificate
// 
//
// Parameters:
//    Result - Undefined, Structure - if Undefined - password to certificate was not received.
//    Parameters - Structure:
//       ExternalAttachableModule - External plugin.
//       AccCertificatesAndTheirStructures - Structure.
//       ContinuationHandler - NotificationDescription.
//       DataForSending     - Structure:
//          PacksData - Matching.
//          Certificates   - Array - array of certificates structures.
//       EDAgreement          - CatalogRef.AgreementsOnEDExchange.
//
//       TotalPreparedCnt - Number.
//       TotalSentCnt   - Number.
//       AuthorizationParameters  - Matching.
//       WantedAuthorization  - Boolean.
//
Procedure ContinueSendingPackagesAfterEnteringCertificatePasswordThroughAdditionalDataProcessor(Result, Parameters) Export
	
	SelectedCertificate = Undefined;
	BreakProcessing = True;
	If TypeOf(Result) = Type("Structure") AND Result.Property("SelectedCertificate", SelectedCertificate)
		AND TypeOf(SelectedCertificate) = Type("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates") Then
		
		CertificateParameters = Parameters.AccCertificatesAndTheirStructures[SelectedCertificate];
		CertificateParameters.Insert("PasswordReceived", True);
		CertificateParameters.Insert("UserPassword", Result.UserPassword);
		CertificateParameters.Insert("SelectedCertificate", SelectedCertificate);
		CertificateParameters.Insert("Comment", "");
		Result.Property("Comment", CertificateParameters.Comment);
		Parameters.Insert("CertificateStructure", CertificateParameters);
		
		ExternalAttachableModule = Parameters.ExternalAttachableModule;
		Certificates = Parameters.DataForSending.Certificates;
		CertificateData = Undefined;
		For Each CertificateStructure IN Certificates Do
			If CertificateStructure.CertificatRef = SelectedCertificate Then
				CertificateData = CertificateStructure;
				Break;
			EndIf;
		EndDo;
		If CertificateData <> Undefined Then
			Parameters.Insert("CertificateData", CertificateData);
			CertificateDataThroughAdditionalDataProcessor = CertificateDataThroughAdditionalDataProcessor(
				ExternalAttachableModule, CertificateData.CertificateBinaryData);
			StorageIdentifier = CertificateDataThroughAdditionalDataProcessor.StorageIdentifier;
			
			If CertificateDataThroughAdditionalDataProcessor <> Undefined Then
				Parameters.Insert("PackagesSentThroughAdditDataProcessor", Parameters.DataForSending.PacksData);
				Parameters.Insert("ProcedureName", "SendPackagesThroughAdditionalDataProcessor");
				Parameters.Insert("Module", ThisObject);
				Parameters.Insert("PasswordIsSet", True);
				Parameters.Insert("UserPassword", Result.UserPassword);
				Parameters.Insert("StorageIdentifier", StorageIdentifier);

				RequiredStoragePINCodeSetting = NeedToSetStoragePINCodeThroughAdditionalDataProcessor(
																	ExternalAttachableModule, StorageIdentifier);
				If RequiredStoragePINCodeSetting = True Then
					OnCloseNotifyDescription = New NotifyDescription(
						"ContinueSendingPackageAfterEnteringPINCodeThroughAdditionalDataProcessor", ThisObject, Parameters);
					StartInstallationPINStorages(Parameters.EDAgreement, StorageIdentifier, OnCloseNotifyDescription);
					BreakProcessing = False;
				ElsIf RequiredStoragePINCodeSetting = False Then
					ContinueSendingPackageThroughAdditionalDataProcessor(Parameters);
					BreakProcessing = False;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	ContinuationHandler = Undefined;
	If BreakProcessing AND Parameters.Property("ContinuationHandler", ContinuationHandler)
		AND TypeOf(ContinuationHandler) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(ContinuationHandler, Parameters.TotalSentCnt);
	EndIf;
	
EndProcedure

Procedure ContinueSendingPackageAfterEnteringPINCodeThroughAdditionalDataProcessor(PINCode, Parameters) Export
	
	ExternalAttachableModule = Parameters.ExternalAttachableModule;
	BreakProcessing = True;
	If PINCode <> Undefined Then
		PINSet = SetStoragePINCodeThroughAdditionalDataProcessor(
			ExternalAttachableModule, Parameters.StorageIdentifier, PINCode);
		If PINSet Then
			ContinueSendingPackageThroughAdditionalDataProcessor(Parameters)
		EndIf;
	EndIf;
	
	ContinuationHandler = Undefined;
	If BreakProcessing AND Parameters.Property("ContinuationHandler", ContinuationHandler)
		AND TypeOf(ContinuationHandler) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(ContinuationHandler, Parameters.TotalSentCnt);
	EndIf;
	
EndProcedure

// Called from
// ContinueSendingPackagesAfterEnteringCertificatePasswordThroughAdditionalDataProcessor and according to the description of the alert from ContinueSendingPackageAfterEnteringPINCodeThroughAdditionalDataProcessor.
// 
//
// Parameters:
//    Parameters - Structure:
//       ExternalAttachableModule    - External plugin.
//       EDAgreement                 - CatalogRef.EDExchangeAgreements.
//       PasswordIsSet             - Boolean.
//       CertificateData            - Structure.
//       UserPassword           - String.
//       ContinuationHandler        - NotificationDescription.
//
//       AccCertificatesAndTheirStructures - Structure.
//       DataForSending            - Structure:
//          PacksData - Matching.
//          Certificates   - Array.
//       TotalPreparedCnt        - Number.
//       TotalSentCnt          - Number.
//       AuthorizationParameters         - Matching.
//       WantedAuthorization         - Boolean.
//
Procedure ContinueSendingPackageThroughAdditionalDataProcessor(Parameters)
	
	ExternalAttachableModule = Parameters.ExternalAttachableModule;
	
	PasswordIsSet = Parameters.PasswordIsSet;
	CertificateData = Parameters.CertificateData;
	UserPassword = Parameters.UserPassword;
	EDAgreement = Parameters.EDAgreement;
	
	BreakProcessing = True;
	If PasswordIsSet Then
		PasswordIsCorrect = SetCertificatePasswordThroughAdditionalDataProcessor(
			ExternalAttachableModule, CertificateData.CertificateBinaryData, UserPassword);
		If PasswordIsCorrect Then
			ConnectedToBank = False;
			EstablishConnectionThroughAdditionalDataProcessor(EDAgreement, ExternalAttachableModule,
					CertificateData.CertificateBinaryData, Parameters, ConnectedToBank);
			If ConnectedToBank Then
				SendPackagesThroughAdditionalDataProcessor(ConnectedToBank, Parameters);
				BreakProcessing = False;
			EndIf;
		EndIf;
	EndIf;
	
	ContinuationHandler = Undefined;
	If BreakProcessing AND Parameters.Property("ContinuationHandler", ContinuationHandler)
		AND TypeOf(ContinuationHandler) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(ContinuationHandler, Parameters.TotalSentCnt);
	EndIf;
	
EndProcedure

Procedure SendPackagesThroughAdditionalDataProcessor(AuthenticationCompleted, Parameters) Export
	
	If AuthenticationCompleted = True Then
		DocumentsToBeSent = New Array;
		SentEDArray = New Array;
		
		For Each Document IN Parameters.PackagesSentThroughAdditDataProcessor Do
			SendingStructure = New Structure;
			SendingStructure.Insert("Key",                Document.Value.Key);
			SendingStructure.Insert("ElectronicDocument", Document.Value.PaymentOrder);
			SendingStructure.Insert("DataSchema",         GetFromTempStorage(Document.Value.ServiceData));
			SendingStructure.Insert("Signatures",             New Array);
		
			For Each StringSignatureData IN Document.Value.Signatures Do
				Signature = GetFromTempStorage(StringSignatureData.SignatureAddress);
				SignatureData = New Structure("Certificate, Signature", StringSignatureData.Certificate, Signature);
				SendingStructure.Signatures.Add(SignatureData);
			EndDo;
			DocumentsToBeSent.Add(SendingStructure);
		EndDo;
		
		SendingStructure = New Structure();
		SendingStructure.Insert("Documents",         DocumentsToBeSent);
		SendingStructure.Insert("DataSchemeVersion", "1.07");

		Result = SendQueryThroughAdditionalDataProcessor(
			Parameters.ExternalAttachableModule, Parameters.CertificateData.CertificateBinaryData, 3, SendingStructure);
		
		If Not Result = Undefined Then
			CountSent = Result.Count();
			ElectronicDocumentsServiceCallServer.ProcessBankResponse(
					Parameters.PackagesSentThroughAdditDataProcessor, Result);
			Parameters.TotalSentCnt = Parameters.TotalSentCnt + CountSent;
		EndIf;
	EndIf;
	
	ContinuationHandler = Undefined;
	If Parameters.Property("ContinuationHandler", ContinuationHandler)
		AND TypeOf(ContinuationHandler) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(ContinuationHandler, Parameters.TotalSentCnt);
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////
// Signing banking documents through additional data processor:

// Called from GetExternalModuleThroughAdditionalDataProcessor by notification processor.
// Fills out missing data necessary for ED signing and goes to ED signing.
//
// Parameters:
//    ExternalAttachableModule - External plugin.
//    Parameters                 - Structure:
//       EDAgreement          - CatalogRef.EDUsageAgreements - EDF setting
//                             by which the signing is executed.
//       EDArrayForSignature      - Array - signed ED.
//       CertificateStructure  - Structure - parameters of the certificate
//                             for which the query for password was executed upstream.
//       ContinuationHandler - NotifyDescription - description to be executed
//                             after completion of current ED refining (EDArrayToSignature).
//
Procedure CheckNeedToSetPinCode(ExternalAttachableModule, Parameters) Export
	
	AbortSigning = True;
	If ExternalAttachableModule <> Undefined Then
		Parameters.Insert("ExternalAttachableModule", ExternalAttachableModule);
		CertificatRef = Parameters.CertificateStructure.SignatureCertificate;
		CertificateAttributes = ElectronicDocumentsServiceCallServer.CertificateAttributes(CertificatRef);
		
		XMLCertificate = CertificateAttributes.CertificateBinaryData;
		Parameters.Insert("XMLCertificateThroughAdditProcessing", XMLCertificate);
		
		CertificateData = CertificateDataThroughAdditionalDataProcessor(ExternalAttachableModule, XMLCertificate);
		
		If CertificateData <> Undefined Then
			Parameters.Insert("StorageIdentifier", CertificateData.StorageIdentifier);
			
			PINCodeRequired = NeedToSetStoragePINCodeThroughAdditionalDataProcessor(
				ExternalAttachableModule, CertificateData.StorageIdentifier);
			
			If PINCodeRequired = True Then
				ND = New NotifyDescription(
					"ContinueSigningAfterEnteringPINCodeThroughAdditionalDataProcessor", ThisObject, Parameters);
				StartInstallationPINStorages(Parameters.EDAgreement, CertificateData.StorageIdentifier, ND);
				AbortSigning = False;
			ElsIf PINCodeRequired = False Then
				ContinueSigningThroughAdditionalDataProcessor(Parameters);
				AbortSigning = False;
			EndIf;
		EndIf;
	EndIf;
	
	DescriptionSignED = Undefined;
	If AbortSigning AND Parameters.Property("ContinuationHandler", DescriptionSignED)
		AND TypeOf(DescriptionSignED) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(DescriptionSignED);
	EndIf;
	
EndProcedure

Procedure ContinueSigningAfterEnteringPINCodeThroughAdditionalDataProcessor(PINCode, Parameters) Export
	
	AbortSigning = True;
	ExternalAttachableModule = Parameters.ExternalAttachableModule;
	If PINCode <> Undefined Then
		PINSet = SetStoragePINCodeThroughAdditionalDataProcessor(
			ExternalAttachableModule, Parameters.StorageIdentifier, PINCode);
			
		If PINSet Then
			AbortSigning = False;
			ContinueSigningThroughAdditionalDataProcessor(Parameters)
		EndIf;
	EndIf;
	
	DescriptionSignED = Undefined;
	If AbortSigning AND Parameters.Property("ContinuationHandler", DescriptionSignED)
		AND TypeOf(DescriptionSignED) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(DescriptionSignED);
	EndIf;
	
EndProcedure

Procedure ContinueSigningThroughAdditionalDataProcessor(Parameters) Export
	
	ExternalAttachableModule = Parameters.ExternalAttachableModule;
	
	XMLCertificate = Parameters.XMLCertificateThroughAdditProcessing;
	CertificateStructure = Parameters.CertificateStructure;
	EDAgreement = Parameters.EDAgreement;
	
	PasswordIsSet = SetCertificatePasswordThroughAdditionalDataProcessor(
		ExternalAttachableModule, XMLCertificate, CertificateStructure.UserPassword);
	
	AbortSigning = True;
	If PasswordIsSet Then
		AbortSigning = False;
		AuthenticationCompleted = False;
		Parameters.Insert("ProcedureName", "SigningEDThroughAdditDataProcessor");
		Parameters.Insert("Module", ThisObject);
		EstablishConnectionThroughAdditionalDataProcessor(
			EDAgreement, ExternalAttachableModule, XMLCertificate, Parameters, AuthenticationCompleted);
		
		If AuthenticationCompleted Then
			SigningEDThroughAdditDataProcessor(AuthenticationCompleted, Parameters);
		EndIf;
	EndIf;
	
	DescriptionSignED = Undefined;
	If AbortSigning AND Parameters.Property("ContinuationHandler", DescriptionSignED)
		AND TypeOf(DescriptionSignED) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(DescriptionSignED);
	EndIf;
	
EndProcedure

Procedure SigningEDThroughAdditDataProcessor(AuthenticationCompleted, Parameters) Export
	
	ExternalAttachableModule = Parameters.ExternalAttachableModule;
	EDArrayForCheck = New Array;
	EDAgreement = Parameters.EDAgreement;
	CertificateStructure = Parameters.CertificateStructure;
	EDArrayForSignature = Parameters.EDArrayForSignature;
	AbortSigning = False;
	If AuthenticationCompleted = True Then
		XMLCertificate = Parameters.XMLCertificateThroughAdditProcessing;
		DataProcessorData = ElectronicDocumentsServiceCallServer.DataForDSGenerationThroughAdditDataProcessor(
																Parameters.EDArrayForSignature);

		If DataProcessorData.TextDataEDArray.Count() > 0 Then
			Try
				NewDataSchemesArray = ExternalAttachableModule.DataSchema(
						XMLCertificate, DataProcessorData.TextDataEDArray);
			Except
				ErrorTemplate = NStr("en='Data scheme receiving error.
		|Error code:
		|%1 %2';ru='Ошибка получения схемы данных.
		|Код
		|ошибки: %1 %2'");
				ErrorDetails = ExternalAttachableModule.ErrorDetails();
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
									ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
				Operation = NStr("en='Receiving data scheme';ru='Получение схемы данных'");
				DetailErrorDescription = DetailErrorDescription(ErrorInfo());
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
					Operation, DetailErrorDescription, MessageText, 1);
				AbortSigning = True;
			EndTry;
			If Not AbortSigning Then
				ElectronicDocumentsServiceCallServer.SaveDataSchemas(
					EDAgreement, DataProcessorData.EDArrayWithoutSchemas, NewDataSchemesArray);
				CommonUseClientServer.SupplementArray(DataProcessorData.SchemasDataArray,  NewDataSchemesArray);
				CommonUseClientServer.SupplementArray(DataProcessorData.EDArrayWithSchemas, DataProcessorData.EDArrayWithoutSchemas);
			EndIf;
		EndIf;
		
		If Not AbortSigning Then
			SignaturesData = New Map;
			CountED = DataProcessorData.EDArrayWithSchemas.Count();
			ParametersSignatures = New Structure("Password", CertificateStructure.UserPassword);
			Try
				SignaturesArray = ExternalAttachableModule.Sign(
					XMLCertificate, DataProcessorData.SchemasDataArray, ParametersSignatures);
			Except
				ErrorTemplate = NStr("en='An error occurred when signing documents.
		|Error code:
		|%1 %2';ru='Ошибка подписания документов.
		|Код
		|ошибки: %1 %2'");
				ErrorDetails = ExternalAttachableModule.ErrorDetails();
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
									ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
				Operation = NStr("en='Signing the documents';ru='Подписание документов'");
				DetailErrorDescription = DetailErrorDescription(ErrorInfo());
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
									Operation, DetailErrorDescription, MessageText, 1);
				AbortSigning = True;
			EndTry;
			If Not AbortSigning Then
				ElectronicDocumentsServiceCallServer.SaveSignaturesData(
					DataProcessorData.EDArrayWithSchemas, SignaturesArray, CertificateStructure.SignatureCertificate);
				For Each CurDocument IN EDArrayForSignature Do
					EDArrayForCheck.Add(CurDocument);
				EndDo;
				Parameters.Insert("SigningResult", New Structure("TotalDigitallySignedCnt", SignaturesArray.Count()));
			EndIf;
		EndIf;
	EndIf;
	
	DescriptionSignED = Undefined;
	Parameters.Property("ContinuationHandler", DescriptionSignED);
	If Not AbortSigning Then
		Parameters.Insert("CurrentSignaturesCheckIndexThroughAdditionalDataProcessor", 0);
		Parameters.Insert("EDArrayForCheckThroughAdditionalDataProcessor", EDArrayForCheck);
		StartCheckingSignaturesStatusesThroughAdditionalDataProcessor(ExternalAttachableModule, Parameters);
	ElsIf TypeOf(DescriptionSignED) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(DescriptionSignED);
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////
// Checking the statuses of set signatures through additional data processor:

// Called from
// EDSigningThroughAdditionalDataProcessor, Catalogs.EDAttachedFiles.EDViewForm form module, DataProcessors.ElectronicDocumentsExchangeWithBank.RequestToBank form module.
// Checks the validity of signatures
//
// Parameters
//    ExternalAttachableModule - External plugin.
//    Parameters                 - Structure:
//       EDAgreement                        - CatalogRef.EDUsageAgreements - EDF setting
//                                           by which the signing is executed.
//       ContinuationHandler     - NotifyDescription - (optional) description to be
//                                           executed after completion of current ED refining (EDArrayToSignature).
//       ExternalAttachableModule           - (optional) external plugin.
//       EDArrayForCheckThroughAdditionalDataProcessor - Array - signed ED.
//       NotifyAboutESCheck               - String - (optional) flag of need to execute "Alert()".
//
Procedure StartCheckingSignaturesStatusesThroughAdditionalDataProcessor(ExternalAttachableModule, Parameters) Export
	
	If ExternalAttachableModule = Undefined Then
		ND = New NotifyDescription("GetAvailableStorageThroughAdditionalDataProcessor", ThisObject, Parameters);
		Structure = New Structure;
		Structure.Insert("RunTryReceivingModule", False);
		Structure.Insert("AfterObtainingDataProcessorModule", ND);
		Structure.Insert("EDAgreement", Parameters.EDAgreement);
		// If you manage to get external module, DataProcessorIfSuccess handler will be executed.
		// Otherwise, it will return to signing of other ED (DataProcessorIfFailure).
		GetExternalModuleThroughAdditionalProcessing(Structure);
	Else
		GetAvailableStorageThroughAdditionalDataProcessor(ExternalAttachableModule, Parameters);
	EndIf;
	
EndProcedure

Procedure GetAvailableStorageThroughAdditionalDataProcessor(ExternalAttachableModule, Parameters) Export
	
	If ExternalAttachableModule = Undefined Then
		NotifyDescription = Undefined;
		If Parameters.Property("ContinuationHandler", NotifyDescription)
			AND TypeOf(NOTifyDescription) = Type("NotifyDescription") Then
			
			Result = Undefined;
			Parameters.Property("SigningResult", Result);
			ExecuteNotifyProcessing(NOTifyDescription, Result);
		EndIf;
	Else
		Parameters.Insert("ExternalAttachableModule", ExternalAttachableModule);
		AvailableStorage = AvailableStorageThroughAdditionalDataProcessor(ExternalAttachableModule);
		If ValueIsFilled(AvailableStorage) Then
			CheckSignaturesStatusesThroughAdditionalDataProcessor(AvailableStorage, Parameters);
		Else
			ND = New NotifyDescription("CheckSignaturesStatusesThroughAdditionalDataProcessor", ThisObject, Parameters);
			ChooseStorageThroughAdditionalDataProcessor(Parameters.EDAgreement, ND, Parameters);
		EndIf;
	EndIf;
	
EndProcedure

//Offers user to select the storage and returns the result of the selection
//
// Parameters:
//  EDAgreement  - CatalogRef.EDUsageAgreements - reference to the
//  agreement with bank GS - NotifyDescription - description of application module procedure call that will be
//  executed after storage choice Parameters  - structure - ED processor parameters
//
Procedure ChooseStorageThroughAdditionalDataProcessor(EDAgreement, ND, Parameters) Export
	
	Storages = ConnectedStoragesThroughAdditionalDataProcessor(Parameters.ExternalAttachableModule);
	
	If Not Storages = Undefined AND Storages.Count() > 0 Then
		ParametersStructure = New Structure("Storages, EDAgreement", Storages, EDAgreement);
		OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.StorageSelection", ParametersStructure, , , , , ND);
	Else
		MessageText = NStr("en='It is required to connect bank key to your computer to execute the operation';ru='Для выполнения операции необходимо подключить банковский ключ к компьютеру'");
		CommonUseClientServer.MessageToUser(MessageText);
		ExecuteNotifyProcessing(ND);
	EndIf
	
EndProcedure

// Called from
// StartCheckingSignaturesStatusesThroughAdditionalDataProcessor and on alert processor from ChooseStorageThroughAdditionalDataProcessor.
// Checks the validity of signatures.
//
// Parameters
//    AvailableStorage - certificates storage.
//    Parameters                 - Structure:
//       ExternalAttachableModule           - External plugin.
//       EDArrayForCheckThroughAdditionalDataProcessor - Array - ED in which the statuses of signatures shall be checked.
//       ContinuationHandler     - NotifyDescription - (optional) description
//                                           to be executed after completion of current ED refining (EDArrayToSignature).
//       NotifyAboutESCheck               - String - (optional) flag of need to execute "Alert()".
//
Procedure CheckSignaturesStatusesThroughAdditionalDataProcessor(AvailableStorage, Parameters) Export
	
	If AvailableStorage <> Undefined Then
		ExternalAttachableModule = Parameters.ExternalAttachableModule;
		EDKindsArray = Parameters.EDArrayForCheckThroughAdditionalDataProcessor;
		For Each ED IN EDKindsArray Do
			EDContentStructure = ElectronicDocumentsServiceCallServer.EDContentStructure(ED);
			
			CheckResult = New Array;
			For Each DSRow IN EDContentStructure.Signatures Do
				RecordStructure = New Structure("LineNumber", DSRow.LineNumber);
				Try
					DSBinaryData = DSRow.Signature;
					XMLCertificate = DSRow.Certificate;
					AdditParameters = New Structure("StorageIdentifier", AvailableStorage);
					SignatureValid = ExternalAttachableModule.VerifySignature(
						XMLCertificate, EDContentStructure.EDData, DSBinaryData, AdditParameters);
					RecordStructure.Insert("Result", SignatureValid);
					CheckResult.Add(RecordStructure);
				Except
					ErrorTemplate = NStr("en='Signature check error.
		|Error code:
		|%1 %2';ru='Ошибка проверки подписи.
		|Код
		|ошибки: %1 %2'");
					ErrorDetails = ExternalAttachableModule.ErrorDetails();
					MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
										ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
					Operation = NStr("en='Signature check';ru='Проверка подписи'");
					DetailErrorDescription = DetailErrorDescription(ErrorInfo());
					ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
										Operation, DetailErrorDescription, MessageText, 1);
				EndTry;
			EndDo;
			
			ElectronicDocumentsServiceCallServer.SaveResultsChecksSignatures(ED, CheckResult);
		EndDo;
		
		If Parameters.Property("NotifyAboutESCheck") Then
			Notify("DSCheckCompleted", EDKindsArray);
		EndIf;
	EndIf;
	
	NotifyDescription = Undefined;
	If Parameters.Property("ContinuationHandler", NotifyDescription)
		AND TypeOf(NOTifyDescription) = Type("NotifyDescription") Then
		
		Result = Undefined;
		Parameters.Property("SigningResult", Result);
		ExecuteNotifyProcessing(NOTifyDescription, Result);
	EndIf;
	
EndProcedure


Procedure ContinueAgreementTestAfterEnteringPasswordToCertificateThroughAdditionalDataProcessor(ReturnParameter, Parameters) Export
	
	TargetID = Parameters.TargetID;
	
	If Parameters.AccCertificatesAndTheirStructures.Count() = 0 Then
		MessageText = NStr("en='Password for certificate is not provided.
		|Test is interrupted.';ru='Не введен пароль для сертификата.
		|Тест прерван.'");
		MessageToUser(MessageText, TargetID);
		Return;
	EndIf;
	
	
	UserPassword = Undefined;
	SelectedCertificate = Undefined;
	ReturnParameter.Property("UserPassword", UserPassword);
	//ReturnParameter.Property("SelectedCertificate", SelectedCertificate);
	For Each KeyAndValue IN Parameters.AccCertificatesAndTheirStructures Do
		CertificateParameters = KeyAndValue.Value;
		CertificateParameters.UserPassword = UserPassword;
		//SelectedCertificate = KeyAndValue.Key;
		Break;
	EndDo;
	
	ExternalAttachableModule = Parameters.ExternalAttachableModule;
	EDAgreement = Parameters.EDAgreement;
	
	TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
	
	XMLCertificate = CertificateParameters.CertificateData;
		
	// Block of certificate data reading.
	TestDescription = NStr("en='Test. Certificate data reading.';ru='Тест. Чтение данных сертификата.'");
	MessageToUser(TestDescription, TargetID);
	CertificateData = CertificateDataThroughAdditionalDataProcessor(ExternalAttachableModule, XMLCertificate);
	If CertificateData = Undefined Then
		Return;
	EndIf;
	MessageToUser(TestResult, TargetID);
	
	// Block for checking the existence of set PIN code.
	TestDescription = NStr("en='Test. Check the existence of PIN code in the storage.';ru='Тест. Проверка наличия PIN-кода на хранилище.'");
	MessageToUser(TestDescription, TargetID);
	PINRequired = RequiredToSetStoragePINCodeThroughAdditionalDataProcessor(ExternalAttachableModule,
	                                                  CertificateData.StorageIdentifier);
	If PINRequired = Undefined Then
		Return;
	EndIf;
	MessageToUser(TestResult, TargetID);
	
	Parameters.Insert("XMLCertificate", XMLCertificate);
	Parameters.Insert("UserPassword", UserPassword);
	Parameters.Insert("CertificateData", CertificateData);
	Parameters.Insert("ProcedureName", "ContinueAgreementTestThroughAdditionalDataProcessorAfterAuthentication");
	Parameters.Insert("Module", ThisObject);
	Parameters.Insert("CertificateParameters", CertificateParameters);
	Parameters.Insert("StorageIdentifier", CertificateData.StorageIdentifier);
	
	// Block of PIN code setting check.
	If PINRequired Then
		TestDescription = NStr("en='Test. Setting PIN code to the storage.';ru='Тест. Установка PIN-кода на хранилище.'");
		MessageToUser(TestDescription, TargetID);
		FormParameters = New Structure;
		FormParameters.Insert("StorageIdentifier", CertificateData.StorageIdentifier);
		FormParameters.Insert("EDAgreement", EDAgreement);
		Parameters.Insert("PINCodeSet");
		OOOZ = New NotifyDescription(
			"ContinueAgreementTestThroughAdditionalDataProcessorAfterEnteringPINCode", ThisObject, Parameters);
		OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.PINCodeRequest", FormParameters, , , , , OOOZ);
		Return;
	EndIf;
	ContinueAgreementTestThroughAdditionalDataProcessor(Parameters);
	
EndProcedure

//Receives external interface of additional data processors
//
// Parameters:
//  EDAgreement  - CatalogRef.EDUsageAgreements - ref to agreement
//
// Returns:
//  Form - form of external data processor or Undefined if failed to get external interface
//
Function ExternalConnectedModuleThroughAdditionalDataProcessor(EDAgreement) Export

	Var NewDataProcessorVersion;
	Var ObjectName;
	Var FileURL;
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	If ExchangeWithBanksSubsystemsParameters = Undefined Then
		ApplicationParameters.Insert("ExchangeWithBanks.Parameters", New Map);
		ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	Else
		ExchangeParameters = ExchangeWithBanksSubsystemsParameters.Get(EDAgreement);
		If ExchangeParameters <> Undefined AND ExchangeParameters.Property("Version") Then
			ProcessorEnabled = ElectronicDocumentsServiceCallServer.ConnectExternalDataProcessor(
					EDAgreement, ExchangeParameters.Version, NewDataProcessorVersion, ObjectName, FileURL);
			If Not ProcessorEnabled Then
				Return Undefined;
			EndIf;
			If ExchangeParameters.Version <> NewDataProcessorVersion Then
				DataProcessorInitialized = InitializeAdditionalDataProcessorInterface(
									EDAgreement, NewDataProcessorVersion, ObjectName, FileURL);
				If Not DataProcessorInitialized Then
					Return Undefined;
				EndIf;
				ExchangeParameters = ExchangeWithBanksSubsystemsParameters.Get(EDAgreement);
			EndIf;
			Return ExchangeParameters.AttachableModule;
		EndIf;
	EndIf;
	
	ExternalDataProcessorEnabled = ElectronicDocumentsServiceCallServer.ConnectExternalDataProcessor(
								EDAgreement, Undefined, NewDataProcessorVersion, ObjectName, FileURL);
	
	If Not ExternalDataProcessorEnabled Then
		Return Undefined;
	EndIf;
	
	DataProcessorInitialized = InitializeAdditionalDataProcessorInterface(
						EDAgreement, NewDataProcessorVersion, ObjectName, FileURL);
	
	If Not DataProcessorInitialized Then
		Return Undefined;
	EndIf;
	
	ExchangeParameters = ExchangeWithBanksSubsystemsParameters.Get(EDAgreement);
	
	Return ExchangeParameters.AttachableModule;
	
EndFunction

// Sets the password for connection with the bank
//
// Parameters:
//  ExternalAttachableModule  - Managed Form - external managed
//  form XMLCertificate  - String - Contains
//  certificate data Password  - String - certificate password
//
// Returns:
//   Boolean   - is password correct or not
//
Function SetCertificatePasswordThroughAdditionalDataProcessor(ExternalAttachableModule, XMLCertificate, Password) Export
	
	Try
		CertificatePasswordSet = ExternalAttachableModule.CertificatePasswordSet(XMLCertificate) = True;
	Except
		CertificatePasswordSet = False;
	EndTry;
	
	If Not CertificatePasswordSet Then
		Try
			ExternalAttachableModule.SetCertificatePassword(XMLCertificate, Password);
		Except
			ErrorTemplate = NStr("en='Error setting certificate password.
		|Error code:
		|%1 %2';ru='Ошибка установки пароля сертификата.
		|Код
		|ошибки: %1 %2'");
			ErrorDetails = ExternalAttachableModule.ErrorDetails();
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
																ErrorTemplate,
																ErrorDetails.Code,
																ErrorDetails.Message);
			Operation = NStr("en='Setting certificate password';ru='Установка пароля сертификата'");
			DetailErrorDescription = DetailErrorDescription(ErrorInfo());
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation,
																						DetailErrorDescription,
																						MessageText,
																						1);
			Return False;
		EndTry;
	EndIf;
	
	Return True;
	
EndFunction

// Checks the existence of already set PIN code for the storage
//
// Parameters:
//  ExternalAttachableModule  - Managed Form - external managed
//  form StorageIdentifier  - String - storage identifier
//
// Returns:
//   Boolean, Undefined - True - pin code was set earlier, False - PIN code
//                          is not set, Undefined - error occurred
//
Function StoragePINCodeIsSetThroughAdditionalDataProcessor(ExternalAttachableModule, StorageIdentifier) Export
	
	Try
		StoragePINCodeIsSet = ExternalAttachableModule.StoragePINCodeIsSet(StorageIdentifier);
	Except
		ErrorTemplate = NStr("en='An error occurred when checking the set PIN code.
		|Error code:
		|%1 %2';ru='Ошибка проверки установленного PIN-кода.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = ExternalAttachableModule.ErrorDetails();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorTemplate,
		                                                                         ErrorDetails.Code,
		                                                                         ErrorDetails.Message);
		Operation = NStr("en='Checking the existence of set PIN code';ru='Проверка наличия установленного PIN-кода'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation,
		                                                                            DetailErrorDescription,
		                                                                            MessageText,
		                                                                            1);
		Return Undefined;
	EndTry;
	
	Return StoragePINCodeIsSet;
	
EndFunction

// Opens pin code entry form
//
// Parameters:
//  EDAgreement  - CatalogRef.EDUsageAgreements - reference to setup of
//  the exchange with bank StorageIdentifier  - String - identifier
//  of OnCloseNotifyDescription storage - NotifyDescription - return after PIN code input
//
Procedure StartInstallationPINStorages(EDAgreement, StorageIdentifier, OnCloseNotifyDescription) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("EDAgreement", EDAgreement);
	FormParameters.Insert("StorageIdentifier", StorageIdentifier);
	OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.PINCodeRequest", FormParameters, , , , ,
																				OnCloseNotifyDescription);
	
EndProcedure

// Sends a request to bank
//
// Parameters
//  ExternalAttachableModule  - Managed Form - external managed
//  form XMLCertificate  - String - data
//  of certificate QueryType  - Number - request
//  type SendingData  - Structure - data to be sent
//
// Returns:
//  Map or Undefined -  Execution result
//
Function SendQueryThroughAdditionalDataProcessor(ExternalAttachableModule, XMLCertificate, TypeQuery, SendingData) Export

	Try
		Result = ExternalAttachableModule.SendRequest(XMLCertificate, TypeQuery, SendingData);
	Except
		ErrorTemplate = NStr("en='Data sending error.
		|Error code:
		|%1 %2';ru='Ошибка отправки данных.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = ExternalAttachableModule.ErrorDetails();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorTemplate,
		                                                                         ErrorDetails.Code,
		                                                                         ErrorDetails.Message);
		Operation = NStr("en='Data sending';ru='Отправка данных'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation,
																					DetailErrorDescription,
																					MessageText,
																					1);
	EndTry;
	
	Return Result

EndFunction 

// Receives certificate data as data structure
//
// Parameters
//  ExternalAttachableModule  - Managed Form - external managed
//  form XMLCertificate  - String - certificate as a string
//
// Returns:
//  Structure or Undefined -  Certificate data as a structure
//
Function CertificateDataThroughAdditionalDataProcessor(ExternalAttachableModule, XMLCertificate) Export
	
	Try
		CertificateData = ExternalAttachableModule.CertificateData(XMLCertificate);
	Except
		ErrorTemplate = NStr("en='An error occurred when receiving the certificate data.
		|Error code:
		|%1 %2';ru='Ошибка получения данных сертификата.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = ExternalAttachableModule.ErrorDetails();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
															ErrorTemplate,
															ErrorDetails.Code,
															ErrorDetails.Message);
		Operation = NStr("en='Receiving certificate data';ru='Получение данных сертификата'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation,
																					DetailErrorDescription,
																					MessageText,
																					1);
		Return Undefined;
	EndTry;
	
	Return CertificateData;
	
EndFunction

Procedure StartAgreementTestThroughAdditionalDataProcessor(Parameters) Export
	
	AvailableCertificates = Parameters.AvailableCertificates;
	EDAgreement = Parameters.EDAgreement;
	TargetID = Parameters.TargetID;
	TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
	
	ExternalAttachableModule = ExternalConnectedModuleThroughAdditionalDataProcessor(EDAgreement);
	
	If ExternalAttachableModule = Undefined Then
		MessageText = NStr("en='Test is not passed.';ru='Тест не пройден.'");
		MessageToUser(MessageText, TargetID);
		Return;
	EndIf;
	
	If Parameters.Property("ExternalComponentSet") Then
		MessageToUser(TestResult, TargetID);
		Parameters.Delete("ExternalComponentSet");
	EndIf;
	
	Parameters.Insert("ExternalAttachableModule", ExternalAttachableModule);
	
	CurrentIndex = 0;
	For Each Item IN AvailableCertificates Do
		
		CurrentIndex = CurrentIndex + 1;
		If CurrentIndex <= Parameters.CertificateTestIndex Then
			Continue;
		EndIf;
		Parameters.CertificateTestIndex = CurrentIndex;
		
		CertificateParameters = Item.Value;
		
		MessageText = NStr("en='Checking the certificate: %1';ru='Проверка сертификата: %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, Item.Key);
		MessageToUser(MessageText, TargetID);
		
		Map = New Map;
		Map.Insert(Item.Key, CertificateParameters);
		
		Parameters.Insert("AccCertificatesAndTheirStructures", Map);
		
		If Not PasswordToCertificateReceived2(Map, NStr("en='Authentication on bank resource';ru='Аутентификация на ресурсе банка.'")) Then
			OOOZ = New NotifyDescription(
				"ContinueAgreementTestAfterEnteringPasswordToCertificateThroughAdditionalDataProcessor", ThisObject, Parameters);
			Parameters.Insert("CallNotification", OOOZ);
			GetPasswordToSertificate(Map, NStr("en='Authentication on bank resource';ru='Аутентификация на ресурсе банка.'"), , , Parameters);
			Return;
			
		EndIf;
		
		ContinueAgreementTestAfterEnteringPasswordToCertificateThroughAdditionalDataProcessor(Undefined, Parameters);
		Return;
	EndDo;
	
	If AvailableCertificates.Count() = 0 Then
		MessageText = NStr("en='Check is not completed due to there are no signature certificates in the agreement';ru='Проверка проведена не полностью, т.к. в соглашении отсутствуют сертификаты подписи'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	// Block of test request sending check.
	TestDescription = NStr("en='Test. Sending test request.';ru='Тест. Отправка тестового запроса.'");
	MessageToUser(TestDescription, TargetID);
	
	XMLCertificate = Parameters.XMLCertificate;
	
	Try
		ExternalAttachableModule.SendRequest(XMLCertificate, 1);
	Except
		ErrorTemplate = NStr("en='An error occurred when sending a test request.
		|Error code:
		|%1 %2';ru='Ошибка отправки тестового запроса.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = ExternalAttachableModule.ErrorDetails();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Sending a test request';ru='Отправка тестового запроса'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
			Operation, DetailErrorDescription, MessageText, 1);
		Return;
	EndTry;
	MessageToUser(TestResult, TargetID);
	
EndProcedure

//Receives the array of storages identifiers connected to the computer
//
// Parameters:
//  ExternalAttachableModule  - Managed Form - external managed form
//
// Returns:
//  Array - identifiers of storages or Undefined in case of error
//
Function ConnectedStoragesThroughAdditionalDataProcessor(ExternalAttachableModule) Export
	
	Try
		Device = ExternalAttachableModule.CertificatesStorages();
	Except
		ErrorTemplate = NStr("en='An error occurred when searching for connected storages.
		|Error code:
		|%1 %2';ru='Ошибка при поиске подключенных хранилищ.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = ExternalAttachableModule.ErrorDetails();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Search for storages';ru='Поиск хранилищ'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
							Operation, DetailErrorDescription, MessageText, 1);
		Return Undefined;
	EndTry;
	
	If Device.Count() = 0 Then
		MessageText = NStr("en='No storage is found.
		|Verify that your device is connected to your computer and then try again';ru='Не найдено ни одного хранилища.
		|Убедитесь, что устройство подключено к компьютеру и повторите операцию'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return Device;
	
EndFunction

// Connecting with bank
//
// Parameters:
//  EDAgreement - CatalogRef.EDUsageAgreements - agreement
//  with bank ExternalAttachableModule  - Managed Form - external managed
//  form XMLCertificate  - String - Contains
//  certificate data Parameters - Structure - context of
//  AuthenticationCompleted method execution - Boolean - True - connection established, otherwise False
//
Procedure EstablishConnectionThroughAdditionalDataProcessor(EDAgreement, ExternalAttachableModule, XMLCertificate, Parameters, AuthenticationCompleted) Export
	
	AuthenticationCompleted = False;
	Try
		
		If Not ExternalAttachableModule.Connect(XMLCertificate) Then
			ExtendedAuthenticationParameters = Undefined;
			ExtendedAuthenticationRequired = ExternalAttachableModule.ExtendedAuthenticationRequired(
															XMLCertificate, ExtendedAuthenticationParameters);
			If ExtendedAuthenticationRequired Then
				If ExtendedAuthenticationParameters.Ways.Count() = 0 Then
					Raise NStr("en='Methods of extended authentication are not defined.';ru='Не определены способы расширенной аутентификации.'");
				EndIf;
				If Not ExtendedAuthenticationParameters.Ways.Property("SMS") Then
					Raise NStr("en='Extended authentication by SMS is not supported.';ru='Расширенная аутентификация по SMS не поддерживается.'");
				EndIf;
				OneTimePassword = Undefined;
				OOOZ = New NotifyDescription(Parameters.ProcedureName, Parameters.Module, Parameters);
				ExtendedAuthentication(EDAgreement, XMLCertificate, ExtendedAuthenticationParameters, OOOZ);

			Else
				Raise NStr("en='Connection setup error.';ru='Ошибка установки соединения'");
			EndIf;
		Else
			AuthenticationCompleted = True;

		EndIf;
		
	Except
		ErrorTemplate = NStr("en='An error occurred while connecting.
		|Error code:
		|%1 %2';ru='Ошибка установки соединения.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = ExternalAttachableModule.ErrorDetails();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Making a connection';ru='Установка соединения'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
							Operation, DetailErrorDescription, MessageText, 1);
		NotifyDescription = Undefined;
		If Parameters.Property("ContinuationHandler", NotifyDescription)
			AND TypeOf(NOTifyDescription) = Type("NotifyDescription") Then
			
			ExecuteNotifyProcessing(NOTifyDescription);
		EndIf;
	EndTry;
	
EndProcedure

// Checks if it is required to set a pin code
//
// Parameters
//  ExternalAttachableModule  - Managed Form - external managed
//  form StorageIdentifier - String - storage identifier
//
// Returns:
//  Boolean or Undefined - required to set PIN or Undefined when an error occurs
//
Function RequiredToSetStoragePINCodeThroughAdditionalDataProcessor(ExternalAttachableModule, StorageIdentifier) Export
	
	Try
		PINRequired = ExternalAttachableModule.SettingStoragePINCodeRequired(StorageIdentifier);
	Except
		ClearMessages();
		ErrorTemplate = NStr("en='An error occurred when checking the need to input PIN code.
		|Error code:
		|%1 %2';ru='Ошибка проверки необходимости ввода PIN-кода.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = ExternalAttachableModule.ErrorDetails();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorTemplate,
		                                                                         ErrorDetails.Code,
		                                                                         ErrorDetails.Message);
		Operation = NStr("en='Check the need to enter PIN code';ru='Проверка необходимости ввода PIN-кода'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation,
		                                                                            DetailErrorDescription,
		                                                                            MessageText,
		                                                                            1);
		Return Undefined;
	EndTry;
	
	Return PINRequired;
	
EndFunction

// Function checks whether the password was previously received for authorization on bank server.
// Parameters:
//  EDAgreement - CatalogRef.EDUsageAgreements - reference to the
//  agreement with bank AuthorizationData - Structure contains
//    the following records * User - String - user
//    name * Password - String - user's password
//
// Returns:
//  Boolean - True - if the password for DS certificate was previously received, otherwise - False.
//
Function ReceivedAuthorizationData(EDAgreement, DataAuthorization) Export
	
	If Not ValueIsFilled(EDAgreement) Then
		Return False;
	EndIf;
	
	CertificateAndPasswordMatching = ApplicationParameters["ElectronicInteraction.CertificateAndPasswordMatching"];
	If TypeOf(CertificateAndPasswordMatching) = Type("FixedMap") Then
		DataAuthorization = CertificateAndPasswordMatching.Get(EDAgreement);
		If ValueIsFilled(DataAuthorization) Then
			Return True;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

Procedure ContinueAgreementTestThroughAdditionalDataProcessorAfterAuthentication(AuthenticationCompleted, Parameters) Export
	
	If Not AuthenticationCompleted = True Then
		Return;
	EndIf;

	TargetID = Parameters.TargetID;
	CertificateParameters = Parameters.CertificateParameters;
	ExternalAttachableModule = Parameters.ExternalAttachableModule;
	XMLCertificate = Parameters.XMLCertificate;
	CertificateData = Parameters.CertificateData;
	
	TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");

	MessageToUser(TestResult, TargetID);
		
	// Block for checking the setting of signature for data.
	TestDescription = NStr("en='Test. Setting the signature.';ru='Тест. Установка подписи.'");
	MessageToUser(TestDescription, TargetID);
	PrintBase64 = ElectronicDocumentsServiceCallServer.Base64StringWithoutBOM(CertificateParameters.Imprint);
	BinaryData = Base64Value(PrintBase64);
	SignatureArray = New Array;
	SignatureArray.Add(BinaryData);
	ParametersSignatures = New Structure("Password", CertificateParameters.UserPassword);
	Try
		SignaturesArray = ExternalAttachableModule.Sign(XMLCertificate, SignatureArray, ParametersSignatures);
	Except
		ErrorTemplate = NStr("en='Signature setup error.
		|Error code:
		|%1 %2';ru='Ошибка установки подписи.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = ExternalAttachableModule.ErrorDetails();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
															ErrorTemplate,
															ErrorDetails.Code,
															ErrorDetails.Message);
		Operation = NStr("en='Setting the signature';ru='Установка подписии'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation,
																					DetailErrorDescription,
																					MessageText,
																					1);
		Return;
	EndTry;
	MessageToUser(TestResult, TargetID);
	
	// Signature check module.
	TestDescription = NStr("en='Test. Signature checkup.';ru='Тест. Проверка подписи.'");
	MessageToUser(TestDescription, TargetID);
	Try
		AdditParameters = New Structure("StorageIdentifier", CertificateData.StorageIdentifier);
		SignatureValid = ExternalAttachableModule.VerifySignature(XMLCertificate,
		                                                            BinaryData,
		                                                            SignaturesArray[0],
		                                                            AdditParameters);
	Except
		ErrorTemplate = NStr("en='Signature check error.
		|Error code:
		|%1 %2';ru='Ошибка проверки подписи.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = ExternalAttachableModule.ErrorDetails();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
															ErrorTemplate,
															ErrorDetails.Code,
															ErrorDetails.Message);
		Operation = NStr("en='Signature check';ru='Проверка подписи'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation,
																					DetailErrorDescription,
																					MessageText,
																					1);
		Return;
	EndTry;
	If Not SignatureValid Then
		MessageToUser(NStr("en='Signature is not valid';ru='Подпись не валидна'"), TargetID);
		Return;
	EndIf;
	MessageToUser(TestResult, TargetID);

	StartAgreementTestThroughAdditionalDataProcessor(Parameters);
	
EndProcedure

Procedure ContinueAgreementTestThroughAdditionalDataProcessorAfterEnteringPINCode(PINCode, Parameters) Export
	
	EDAgreement = Parameters.EDAgreement;
	
	If Not PINCode = Undefined Then
		Return;
	EndIf;
	
	ExternalAttachableModule = ExternalConnectedModuleThroughAdditionalDataProcessor(EDAgreement);
	If ExternalAttachableModule = Undefined Then
		Return;
	EndIf;
	PinCodeSet = SetStoragePINCodeThroughAdditionalDataProcessor(
			ExternalAttachableModule, Parameters.StorageIdentifier, PINCode);
			
	If Not PinCodeSet Then
		Return;
	EndIf;
		
	ContinueAgreementTestThroughAdditionalDataProcessor(Parameters)
	
EndProcedure

Procedure AgreementTestThroughAdditDataProcessor(EDAgreement, TargetID)
	
	Var VersionHandling, ObjectName, FileURL;
		
	TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
	
	// Block for checking the existence of external data processor for exchange with the bank
	TestDescription = NStr("en='Test. Checking the existence of external data processor for exchange with the bank.';ru='Тест. Проверка наличия внешней обработки для обмена с банком.'");
	MessageToUser(TestDescription, TargetID);
	ExternalDataProcessorEnabled = ElectronicDocumentsServiceCallServer.ConnectExternalDataProcessor(
								EDAgreement, VersionHandling, VersionHandling, ObjectName, FileURL);
	If Not ExternalDataProcessorEnabled Then
		Return;
	EndIf;
	MessageToUser(TestResult, TargetID);
	
	// Block of interface initialization.
	TestDescription = NStr("en='Test. Initialization of service interface.';ru='Тест. Инициализация служебного интерфейса.'");
	MessageToUser(TestDescription, TargetID);
	
	AvailableCertificates = ElectronicDocumentsServiceCallServer.AvailableCertificates(EDAgreement);
	
	Parameters = New Structure;
	Parameters.Insert("CertificateTestIndex", 0);
	Parameters.Insert("AvailableCertificates", AvailableCertificates);
	Parameters.Insert("TargetID", TargetID);
	Parameters.Insert("EDAgreement", EDAgreement);
	
	ExternalAttachableModule = ExternalConnectedModuleThroughAdditionalDataProcessor(EDAgreement);
	
	If ExternalAttachableModule = Undefined Then
		ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
		If ExchangeWithBanksSubsystemsParameters <> Undefined Then
			AgreementParameters = ExchangeWithBanksSubsystemsParameters.Get(EDAgreement);
			If ValueIsFilled(AgreementParameters) AND AgreementParameters.Property("ComponentAddress") Then
				Parameters.Insert("CurrentEDAgreementThroughAdditionalDataProcessor", EDAgreement);
				Parameters.Insert("ExternalComponentSet");
				ND = New NotifyDescription("StartAgreementTestThroughAdditionalDataProcessor", ThisObject, Parameters);
				BeginInstallAddIn(ND, AgreementParameters.ComponentAddress);
				Return;
			EndIf;
		EndIf;
		Return;
	EndIf;
	
	StartAgreementTestThroughAdditionalDataProcessor(Parameters);
	
EndProcedure

Function RelevantCertificatePasswordCacheThroughAdditionalProcessing(CertificateData, EDKindsArray) Export
	
	EDAgreement = ElectronicDocumentsServiceCallServer.EDAgreement(EDKindsArray[0]);
	ExternalAttachableModule = ExternalConnectedModuleThroughAdditionalDataProcessor(EDAgreement);
	If ExternalAttachableModule = Undefined Then
		Return False;
	EndIf;
	CertificateAttributes = ElectronicDocumentsServiceCallServer.CertificateAttributes(
													CertificateData.SignatureCertificate);
	
	CertificateServiceData = CertificateDataThroughAdditionalDataProcessor(ExternalAttachableModule,
												CertificateAttributes.CertificateBinaryData);
		
	If CertificateServiceData = Undefined Then
		Return False;
	EndIf;

	RequiredToSetStoragePINCodeThroughAdditionalDataProcessor = RequiredToSetStoragePINCodeThroughAdditionalDataProcessor(
														ExternalAttachableModule, CertificateServiceData.StorageIdentifier);
	If Not RequiredToSetStoragePINCodeThroughAdditionalDataProcessor = False Then
		Return False;
	EndIf;
	
	Try
		CertificatePasswordSet = ExternalAttachableModule.CertificatePasswordSet(
												CertificateAttributes.CertificateBinaryData);
		Return CertificatePasswordSet = True;
	Except
		Return False;
	EndTry;

EndFunction

Function InitializeAdditionalDataProcessorInterface(EDAgreement, VersionHandling, ObjectName, FileURL)
	
	If ValueIsFilled(FileURL) Then
		#If ThickClientOrdinaryApplication Then
			TempFile = GetTempFileName("epf");
			DataProcessorBinaryData = GetFromTempStorage(FileURL);
			DataProcessorBinaryData.Write(TempFile);
			AttachableModule = ExternalDataProcessors.GetForm(TempFile);
		#EndIf
	Else
		FormName = "ExternalDataProcessor." + ObjectName + ".Form";
		AttachableModule = GetForm(FormName, New Structure("EDFMode", True), , New UUID);
	EndIf;
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	If ExchangeWithBanksSubsystemsParameters = Undefined Then
		ApplicationParameters.Insert("ExchangeWithBanks.Parameters", New Map);
		ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	EndIf;

	Try
		DataProcessorDescription = AttachableModule.DataProcessorDescription();
		VersionAPI = DataProcessorDescription.VersionAPI;
	Except
		VersionAPI = 1;
	EndTry;
		
	If VersionAPI = 1 Then
		Try
			AttachableModule.Initialize();
		Except
			ErrorTemplate = NStr("en='Error of additional data processor initialization.
		|Error code:
		|%1 %2';ru='Ошибка инициализации дополнительной обработки.
		|Код
		|ошибки: %1 %2'");
			ErrorDetails = AttachableModule.ErrorDetails();
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
								ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
			Operation = NStr("en='Initialization of external data processor';ru='Инициализация внешней обработки'");
			DetailErrorDescription = DetailErrorDescription(ErrorInfo());
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
								Operation, DetailErrorDescription, MessageText, 1);
			Return False;
		EndTry;
	Else
		Try
			ComponentAddress = "";
			InitializationExecuted = AttachableModule.BeginInitialization(ComponentAddress);
		Except
			ErrorTemplate = NStr("en='Error of additional data processor initialization.
		|Error code:
		|%1 %2';ru='Ошибка инициализации дополнительной обработки.
		|Код
		|ошибки: %1 %2'");
			ErrorDetails = AttachableModule.ErrorDetails();
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
								ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
			Operation = NStr("en='Initialization of external data processor';ru='Инициализация внешней обработки'");
			DetailErrorDescription = DetailErrorDescription(ErrorInfo());
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
								Operation, DetailErrorDescription, MessageText, 1);
			Return False;
		EndTry;
		
		If Not InitializationExecuted Then
			If ValueIsFilled(ExchangeWithBanksSubsystemsParameters) Then
				AgreementParameters = ExchangeWithBanksSubsystemsParameters.Get(EDAgreement);
				If ValueIsFilled(AgreementParameters) AND AgreementParameters.Property("ComponentAddress") Then
					DeleteFromTempStorage(AgreementParameters.ComponentAddress);
					ExchangeWithBanksSubsystemsParameters.Delete(EDAgreement);
					Return False;
				EndIf;
			EndIf;
			If ValueIsFilled(ComponentAddress) Then
				Parameters = New Structure;
				Parameters.Insert("ComponentAddress", ComponentAddress);
				ExchangeWithBanksSubsystemsParameters.Insert(EDAgreement, Parameters);
			EndIf;
			Return False;
		Else
			Try
				AttachableModule.CompleteInitialization();
			Except
				ErrorTemplate = NStr("en='Initialization completion error.
		|Error code:
		|%1 %2';ru='Ошибка завершения инициализации.
		|Код
		|ошибки: %1 %2'");
				ErrorDetails = AttachableModule.ErrorDetails();
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
									ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
				Operation = NStr("en='Completion of external data processor initialization';ru='Завершение инициализации внешней обработки'");
				DetailErrorDescription = DetailErrorDescription(ErrorInfo());
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
									Operation, DetailErrorDescription, MessageText, 1);
				Return False;
			EndTry;
		EndIf;

	EndIf;
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	If ExchangeWithBanksSubsystemsParameters = Undefined Then
		ApplicationParameters.Insert("ExchangeWithBanks.Parameters", New Map);
		ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("AttachableModule", AttachableModule);
	Parameters.Insert("Version",             VersionHandling);
	ExchangeWithBanksSubsystemsParameters.Insert(EDAgreement, Parameters);
	
	Return True;
	
EndFunction

Procedure ContinueReceivingStatementThroughAdditionalDataProcessor(Parameters)
	
	ExternalAttachableModule = Parameters.ExternalAttachableModule;
	EDAgreement = Parameters.EDAgreement;
	
	CertificateData = Parameters.CertificateData;
	UserPassword = Parameters.UserPassword;
	
	PasswordIsSet = SetCertificatePasswordThroughAdditionalDataProcessor(
		ExternalAttachableModule, CertificateData.CertificateBinaryData, UserPassword);
	If Not PasswordIsSet Then
		Return;
	EndIf;
	
	ConnectionEstablished = False;
	EstablishConnectionThroughAdditionalDataProcessor(EDAgreement, ExternalAttachableModule, CertificateData.CertificateBinaryData,
																					Parameters, ConnectionEstablished);
	If Not ConnectionEstablished Then
		Return;
	EndIf;
	
	ContinueReceivingStatement(ConnectionEstablished, Parameters);
	
EndProcedure

Procedure ContinueAgreementTestThroughAdditionalDataProcessor(Parameters)
	
	EDAgreement = Parameters.EDAgreement;
	
	TargetID = Parameters.TargetID;
	ExternalAttachableModule = Parameters.ExternalAttachableModule;
	XMLCertificate = Parameters.XMLCertificate;
	UserPassword = Parameters.UserPassword;
		
	TestResult = NStr("en='Passed successfully.';ru='Пройден успешно.'");
	
	If Parameters.Property("PINCodeSet") Then
		MessageToUser(TestResult, TargetID);
	EndIf;
	
	// Block of authorization check on bank resource.
	TestDescription = NStr("en='Test. Authentication on bank resource.';ru='Тест. Аутентификация на ресурсе банка.'");
	MessageToUser(TestDescription, TargetID);
	OperationKind = NStr("en='Authentication on bank resource';ru='Аутентификация на ресурсе банка.'");
	Try
		ExternalAttachableModule.SetCertificatePassword(XMLCertificate, UserPassword);
	Except
		ErrorTemplate = NStr("en='Authorization error on bank resource.
		|Error code:
		|%1 %2';ru='Ошибка авторизации на ресурсе банка.
		|Код
		|ошибки: %1 %2'");
		ErrorDetails = ExternalAttachableModule.ErrorDetails();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Authentication on bank resource';ru='Аутентификация на ресурсе банка.'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
			Operation, DetailErrorDescription, MessageText, 1);
		Return;
	EndTry;
	MessageToUser(TestResult, TargetID);
	
	// Block of check of connection with bank.
	TestDescription = NStr("en='Test. Connecting with bank.';ru='Тест. Установка соединения с банком.'");
	MessageToUser(TestDescription, TargetID);
	AuthenticationCompleted = False;
	
	EstablishConnectionThroughAdditionalDataProcessor(
		EDAgreement, ExternalAttachableModule, XMLCertificate, Parameters, AuthenticationCompleted);
	If AuthenticationCompleted Then
		ContinueAgreementTestThroughAdditionalDataProcessorAfterAuthentication(AuthenticationCompleted, Parameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region Sberbank
	
Procedure AfterConnecting1CComponentSetVirtualChannelSberbank(ExternalComponent, Parameters) Export
	
	If ExternalComponent = Undefined Then
		CasheSberbankParameter("ChannelSet", False);
		Return;
	EndIf;

	EDFSetup = Parameters.EDFSetup;
	
	ChannelCreated = False;
	If ValueFromCache("ChannelSet") = True AND ValueFromCache("CurrentEDAgreement") = EDFSetup Then
		ChannelCreated = True;
		Return;
	EndIf;
	
	ND = Parameters.AlertAfterInstallingVirtualChannel;
	
	If Not ValueIsFilled(ValueFromCache("NumberContainer")) Then
		FormParameters = New Structure("EDAgreement", EDFSetup);
		OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.DataAuthenticationQuerySberbank",
						FormParameters, , , , , ND);
		Return;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("AuthorizationCompleted", False);
	Parameters.Insert("ND", ND);
	
	AuthorizationCompleted = False;
	ExecuteAuthenticationOnSberbankToken(EDFSetup, Parameters);
	If Not Parameters.AuthorizationCompleted Then
		Return;
	EndIf;
	
	FinishSettingVirtualChannelWithSberbank(EDFSetup, ND);
	
EndProcedure

Procedure AfterConnectingExternalComponentSendQueryOnNightAccountStatementsSberbank(AttachableModule, Parameters)
	
	If AttachableModule = Undefined Then
		Return;
	EndIf;
	
	EDFSetup = Parameters.EDFSetup;
	NumberContainer = ValueFromCache("NumberContainer");
	
	SignatureCertificate = ElectronicDocumentsServiceCallServer.CertificateFromEDAgreement(EDFSetup, NumberContainer);
	If Not ValueIsFilled(SignatureCertificate) Then
		Return;
	EndIf;
	
	ChannelCreated = FALSE;
	ND = New NotifyDescription("SendQueriesForNightStatementsSberbank", ThisObject, Parameters);
	SetVirtualChannelWithSberbank(EDFSetup, ChannelCreated, ND);
	If Not ChannelCreated Then
		Return;
	EndIf;
		
	IDRequest = String(New UUID);
	EDFSettingAttributes = ElectronicDocumentsServiceCallServer.EDFSettingAttributes(EDFSetup);
	CompanyID = EDFSettingAttributes.CompanyID;
	SignatureRow = "ATTRIBUTES" + Char(10) + "OrgId=" + CompanyID + Char(10)
					+ "RequestId=" + IDRequest;

	SignatureRowBase64 = ElectronicDocumentsServiceCallServer.Base64StringWithoutBOM(SignatureRow);

	Operation = NStr("en='Generating of request for the night statement';ru='Формирование запроса на ночную выписку'");
	DS = "";
	
	CertificateParameters = ElectronicDocumentsServiceCallServer.CertificateAttributes(SignatureCertificate);
	IDCertificate = SberbankCertificateIdentifier(
		AttachableModule, CertificateParameters.CertificateBinaryData);
	If IsBlankString(IDCertificate) Then
		Return;
	EndIf;
	
	Try
		Res = AttachableModule.SignDataThroughVPNKeyTLS(SignatureRowBase64, IDCertificate, DS);
		If Res <> 0 Then
			MessageText = NStr("en='An error occurred when
		|signing DS See details in the event log';ru='При подписании ЭП
		|произошла ошибка Подробности в журнале регистрации'");
			ErrorText = NStr("en='AddIn.Bicrypt component has returned an error code at the signing';ru='Компонента AddIn.Bicrypt при подписании вернула код ошибки'") + " " + Res;
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
			ClearAuthorizationDataSberbank();
			Return;
		EndIf;
	Except
		ClearMessages();
		MessageText = NStr("en='An error occurred when
		|signing DS See details in the event log';ru='При подписании ЭП
		|произошла ошибка Подробности в журнале регистрации'");
		ErrorText = ErrorDescription();
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
		Return;
	EndTry;

	QueryString = ElectronicDocumentsServiceCallServer.QueryTextNightIssue(
					IDRequest, CompanyID, DS, SignatureCertificate);
		
	If Not ValueIsFilled(QueryString) Then
		Return;
	EndIf;
	
	Try
		
		AttachableModule1C = ValueFromCache("AttachableModule1CForSberbank");

		Response = AttachableModule1C.sendRequests(QueryString);
		
		ElectronicDocumentsServiceCallServer.WriteEventToLogAudit(
														EDFSetup,
														NStr("en='Request for the night statement has been sent to the bank';ru='Запрос на ночную выписку отправлен в банк'"),
														QueryString);
		
		ArrayOfIDs = New Array;
	
		If Mid(Response, 1, 23) = "00000000-0000-0000-0000" Then
			TypeQuery = NStr("en='Request night account statements';ru='Запрос ночных выписок'");
			DetermineErrorAndInformUser(
				EDFSetup, TypeQuery, IDRequest, CompanyID, Response);
		Else
			ArrayOfIDs.Add(Response);
		EndIf;
	
	
		ElectronicDocumentsServiceCallServer.SaveIdentifiers(
														ArrayOfIDs,
														EDFSetup,
														PredefinedValue("Enum.EDKinds.QueryNightStatements"));
				
		ElectronicDocumentsServiceCallServer.WriteEventToLogAudit(
														EDFSetup,
														NStr("en='Request sending ID for the night statement has been received';ru='Получен идентификатор отправки запроса на ночную выписку'"),
														Response);
		
	Except

		OperationKind = NStr("en='Request of the night bank statement';ru='Запрос ночной выписки банка'");
		MessageText = NStr("en='There is no connection with the bank server';ru='Нет связи с сервером банка'") + Chars.LF
							+ NStr("en='details in the event log';ru='Подробности в журнале регистрации'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(OperationKind,
																					ErrorDescription(),
																					MessageText,
																					1);
	EndTry;
	
	If ValueIsFilled(Parameters) AND Parameters.Property("GetStatementsQueryDataProcessorsResults") Then
		EDKind = PredefinedValue("Enum.EDKinds.QueryStatement");
		GetSberbankQueriesDataProcessorsResults(EDFSetup, EDKind, Parameters);
	EndIf

	
EndProcedure

Procedure AfterConnectingComponentDetermineSberbankSignaturesStatuses(AttachableModule, Parameters) Export
	
	If AttachableModule = Undefined Then
		Return;
	EndIf;

	ND = New NotifyDescription("DetermineStatusOfSignaturesFromSberbank", ThisObject, Parameters);
	ChannelSet = False;
	SetVirtualChannelWithSberbank(Parameters.EDFSetup, ChannelSet, ND);
	If Not ChannelSet Then
		Return;
	EndIf;
	
	CurrentIndex = 0;
	For Each ED IN Parameters.EDArrayForCheckingSberbankDS Do
		CurrentIndex = CurrentIndex + 1;
		If CurrentIndex <= Parameters.SberbankDSCheckIndex Then
			Continue;
		Else
			Parameters.SberbankDSCheckIndex = CurrentIndex;
		EndIf;
		
		AdditInformationAboutED = ElectronicDocumentsServiceCallServer.GetFileData(ED);
		DocumentBinaryData = GetFromTempStorage(AdditInformationAboutED.FileBinaryDataRef);
		
		MapOfSignaturesAndCertificates = ElectronicDocumentsServiceCallServer.DataSetSignaturesAndCertificates(ED);
		
		FormatStringBase64 = ElectronicDocumentsServiceCallServer.DigitallySignedDataBase64(ED);
		
		CheckResult = New Array();
			
		For Each Item IN MapOfSignaturesAndCertificates Do
			StringCertificate = Item.Value;
			Signature = Item.Key;
			Try
				ReturnCode = AttachableModule.VerifyDataSignatureThroughVPNKeyTLS(
										FormatStringBase64, Signature, StringCertificate);
				If ReturnCode = 0 Then
					CheckResult.Add(True);
				Else
					CheckResult.Add(False);
				EndIf;
				TextForLog = NStr("en='Executing the operation: Signature check.
		|Signature for electronic document
		|verified: %1 Verification result: signature %2.';ru='Выполнение операции: Проверка подписи.
		|Проверена подпись
		|для электронного документа: %1 Результат проверки: подпись %2.'");
				TextForLog = StringFunctionsClientServer.PlaceParametersIntoString(TextForLog,
					ED, ?(ReturnCode = 0, "correct","incorrect"));
				ElectronicDocumentsServiceCallServer.WriteToEventLogMonitor(TextForLog, 1, "Information", ED);
			Except
				ErrorDescription = NStr("en='Verification of digital signature validity.
		|An error occurred during the verification of electronic signature.
		|Additional
		|description: %AdditionalDetails%';ru='Проверка валидности электронной подписи.
		|Во время проверки валидности электронной подписи произошла ошибка.
		|Дополнительное
		|описание: %ДополнительноеОписание%'");
				ErrorDescription = StrReplace(ErrorDescription, "%AdditionalDetails%", ErrorInfo().Definition);
				ElectronicDocumentsServiceCallServer.WriteToEventLogMonitor(ErrorDescription, 1, "Error");
				CheckResult.Add(Undefined);
			EndTry;
		EndDo;
		
		ElectronicDocumentsServiceCallServer.FixDSCheckResult(ED, CheckResult);
		
	EndDo;
	
	If Parameters.Property("SendForSigningAfterProcessing") Then
		StartSigningBankingED(Parameters);
	EndIf;
	
	If Parameters.Property("NotifyAboutESCheck") Then
		Notify("DSCheckCompleted", Parameters.EDArrayForCheckingSberbankDS);
	EndIf;
	
	If Parameters.Property("ThisIsStatementQuery") Then
		SendQueryOnSberbankStatement(Parameters.EDFSetup, Parameters);
	EndIf;
	
EndProcedure

Procedure AfterConnectingComponentSignSberbankED(AttachableModule, Parameters) Export
	
	EDFSetup = Parameters.EDFSetup;
	
	If AttachableModule = Undefined Then
		Return;
	EndIf;

	ChannelSet = False;
	ND = New NotifyDescription("SignSberbankED", ThisObject, Parameters);
	SetVirtualChannelWithSberbank(EDFSetup, ChannelSet, ND);
	
	If Not ChannelSet Then
		Return;
	EndIf;
	
	NumberContainer = ValueFromCache("NumberContainer");
	SignatureCertificate = ElectronicDocumentsServiceCallServer.CertificateFromEDAgreement(EDFSetup, NumberContainer);
	If Not ValueIsFilled(SignatureCertificate) Then
		Return;
	EndIf;
		
	CertificateParameters = ElectronicDocumentsServiceCallServer.CertificateAttributes(SignatureCertificate);
	
	IDCertificate = SberbankCertificateIdentifier(
		AttachableModule, CertificateParameters.CertificateBinaryData);
		
	If IsBlankString(IDCertificate) Then
		Return;
	EndIf;
		
	Operation = NStr("en='Electronic document signing';ru='Подписание электронного документа'");
	
	For Each ED IN Parameters.AddedFiles Do
				
		SignatureRowBase64 = ElectronicDocumentsServiceCallServer.DigitallySignedDataBase64(ED);
		DS="";
		Try
			Res = AttachableModule.SignDataThroughVPNKeyTLS(SignatureRowBase64, IDCertificate, DS);
			If Res <> 0 Then
				MessageText = NStr("en='An error occurred when signing DS';ru='При подписании ЭП произошла ошибка'") + Chars.LF
								+ NStr("en='details in the event log';ru='Подробности в журнале регистрации'");
				ErrorText = NStr("en='AddIn.Bicrypt component has returned an error code at the signing';ru='Компонента AddIn.Bicrypt при подписании вернула код ошибки'")+ " " + Res;
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
				ClearAuthorizationDataSberbank();
				Return;
			EndIf;
		Except
			ClearMessages();
			MessageText = NStr("en='An error occurred when signing DS';ru='При подписании ЭП произошла ошибка'") + Chars.LF
							+ NStr("en='details in the event log';ru='Подробности в журнале регистрации'");
			ErrorText = ErrorDescription();
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
			Return;
		EndTry;
		
		DSBinaryData = Base64Value(DS);
		
		SignatureData = New Structure("NewSignatureBinaryData, Thumbprint, SignatureDate,
										|Comment, SignatureFileName, CertificateIsIssuedTo, CertificateBinaryData");
		
		SignatureData.Imprint                  = CertificateParameters.Imprint;
		SignatureData.SignatureDate                = CommonUseClient.SessionDate();
		SignatureData.CertificateBinaryData  = CertificateParameters.CertificateBinaryData;
		SignatureData.NewSignatureBinaryData = DSBinaryData;
		SignatureData.CertificateIsIssuedTo        = CertificateParameters.Description;

		ElectronicDocumentsServiceCallServer.AddSignature(ED, SignatureData);
		
		Comment = NStr("en='Running: %1.
		|Set the signature: %2, certificate: %3';ru='Выполнение операции: %1.
		|Установил подпись: %2, сертификат: %3'");
		Comment = StringFunctionsClientServer.PlaceParametersIntoString(
														Comment,
														Operation,
														UsersClientServer.AuthorizedUser(),
														SignatureCertificate);
		
		ElectronicDocumentsServiceCallServer.WriteToEventLogMonitor(Comment, 1, "Information", ED);
		
		ElectronicDocumentsServiceCallServer.RefreshEDVersion(ED);
		
		Parameters.TotalDigitallySignedCnt = Parameters.TotalDigitallySignedCnt + 1;
		
	EndDo;
	
	Parameters.Insert("EDArrayForCheckingSberbankDS", Parameters.AddedFiles);
	Parameters.Insert("SberbankDSCheckIndex", 0);

	DetermineStatusOfSignaturesFromSberbank(EDFSetup, Parameters);
	
EndProcedure

Procedure AfterConnectingComponentExecuteAuthenticationOnSberbankToken(AttachableModule, Parameters) Export
	
	If AttachableModule = Undefined Then
		Return;
	EndIf;
	
	If Parameters.Property("ForcedAuthentication") Then
		ForcedAuthentication = Parameters.ForcedAuthentication;
	Else
		ForcedAuthentication = False;
	EndIf;
	
	EDFSetup = Parameters.EDFSetup;
	
	If ForcedAuthentication OR Not (ValueIsFilled(ValueFromCache("NumberContainer"))
												AND ValueFromCache("CurrentEDAgreement") = EDFSetup) Then
					
		If ValueIsFilled(ValueFromCache("NumberContainer")) Then
			SessionCompleted = False;
			CompleteSessionOnToken(SessionCompleted);
			If Not SessionCompleted Then
				Return;
			EndIf;
		EndIf;
		FormParameters = New Structure("EDAgreement", EDFSetup);
		AdditionalParameters = New Structure("ND", Parameters.ND);
		Handler = New NotifyDescription(
			"HandleSberbankAuthenticationDataEntry", ThisObject, AdditionalParameters);
		OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.DataAuthenticationQuerySberbank",
						FormParameters, , , , , Handler);
		Return;
	EndIf;
	
	If Parameters.Property("ReAuthorization") Then
		ReAuthorization = Parameters.ReAuthorization;
	Else
		ReAuthorization = False;
	EndIf;
	
	CompleteAuthenticationOnSberbankToken(
		EDFSetup, Parameters.AuthorizationCompleted, Parameters.ND, ReAuthorization);
	
EndProcedure

Procedure AfterConnectingComponentSetVirtualChannelSberbank(ExternalComponent, Parameters) Export
	
	If ExternalComponent = Undefined Then
		CasheSberbankParameter("ChannelSet", False);
		Return
	EndIf;
	
	ProcessingDetails = New NotifyDescription(
		"AfterConnecting1CComponentSetVirtualChannelSberbank", ThisObject, Parameters);

	CRParameters = New Structure;
	CRParameters.Insert("HandlerAfterConnectingComponents", ProcessingDetails);
	CRParameters.Insert("ModuleName", "SBRF");
	CRParameters.Insert("Name", "AddIn.SBRF.SBRFServiceProxy");
	CRParameters.Insert("Type", AddInType.Native);
	CRParameters.Insert("BankApplication", "1CComponentForSberbank");
	CRParameters.Insert("servicePort");
	Parameters.Insert("CRParameters", CRParameters);
	
	ConnectBankExternalComponent(Parameters);

EndProcedure

Procedure StartSigningSberbankED(SignatureData, Parameters) Export
	
	ProcessedEDAgreementsArray = Parameters.ProcessedEDAgreementsArray;
	SignatureCertificate = Parameters.SignatureCertificate;
	CurrentIndex = 0;
	
	For Each AgreementAndED IN SignatureData Do
		
		CurrentIndex = CurrentIndex + 1;
		If CurrentIndex <= Parameters.ThirdIterationIndex Then
			Continue;
		Else
			Parameters.ThirdIterationIndex = CurrentIndex;
		EndIf;
		
		If Not ProcessedEDAgreementsArray.Find(AgreementAndED.Key) = Undefined Then
			Continue;
		EndIf;
		ProcessedEDAgreementsArray.Add(AgreementAndED.Key);
		BankEDArray = AgreementAndED.Value;
		If BankEDArray.Count() > 0 Then

			SignEDOfSpecificCertificate(
				AgreementAndED.Key, BankEDArray, SignatureCertificate, Parameters);
			Return;
		EndIf;
	EndDo;
	
	//StartSigningED(Parameters);

EndProcedure

Procedure AgreementTestSberbank(EDAgreement, Parameters = Undefined) Export
		
	ChannelCreated = False;
	ND = New NotifyDescription("AgreementTestSberbank", ThisObject, Parameters);
	SetVirtualChannelWithSberbank(EDAgreement, ChannelCreated, ND);
	
	If Not ChannelCreated Then
		Return;
	EndIf;
		
	Try
		
		AttachableModule1C = ValueFromCache("AttachableModule1CForSberbank");

		TestString = "Test from 1C";
		
		XDTOResult = AttachableModule1C.sendRequests(TestString);
		
		MessageText = NStr("en='Test is executed successfully !';ru='Тест выполнен успешно !'");

		CommonUseClientServer.MessageToUser(MessageText);

	Except
		
		OperationKind = NStr("en='Connection test';ru='Тест соединения'");
		MessageText = NStr("en='There is no connection with the bank server';ru='Нет связи с сервером банка'") + Chars.LF
						+ NStr("en='details in the event log';ru='Подробности в журнале регистрации'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
									OperationKind, ErrorDescription(), MessageText, 1);
		
	EndTry;
	
EndProcedure

// Sends payment orders to the bank
//
// Parameters
//  EDAgreement  - CatalogRef.EDUsageAgreement - agreement on electronic
//  documents exchange Parameters - Structure - documents sending parameters
//
Procedure SendPaymentOrdersSberbank(EDAgreement, Parameters) Export

	If Not ValueIsFilled(EDAgreement) Then
		Return;
	EndIf;
	
	ChannelCreated = False;
	ND = New NotifyDescription("SendPaymentOrdersSberbank", ThisObject, Parameters);
	
	SetVirtualChannelWithSberbank(EDAgreement, ChannelCreated, ND);
	If Not ChannelCreated Then
		Return;
	EndIf;
	
	AttachableModule1C = ValueFromCache("AttachableModule1CForSberbank");

	EDKindsArray = Parameters.ArraySend;
	
	If EDKindsArray.Count() = 0 Then
		Return;
	EndIf;
	
	SentCnt = 0;
	
	SentEDArray = New Array;
	
	For Each ED IN EDKindsArray Do
		Try
			
			IDRequest = Undefined;
			CompanyID = Undefined;
			DataStructureOfED = ElectronicDocumentsServiceCallServer.GetPackageFileSberBank(
										ED, EDAgreement, IDRequest, CompanyID);
			XMLString = DataStructureOfED.XMLString;
			
			Response = AttachableModule1C.sendRequests(XMLString);
			
			DetailsEvents = NStr("en='Sending payment order';ru='Отправка платежного поручения'");
			ElectronicDocumentsServiceCallServer.WriteEventToLogAudit(EDAgreement, DetailsEvents, XMLString);
			Event = NStr("en='Received the ticket for payment order sending';ru='Получен тикет на отправку платежного поручения'");

			ElectronicDocumentsServiceCallServer.WriteEventToLogAudit(EDAgreement, Event, Response);
			
			ArrayOfIDs = New Array;
			If Mid(Response, 1, 23) = "00000000-0000-0000-0000" Then
				DetermineErrorAndInformUser(EDAgreement, ED, IDRequest, CompanyID, Response);
			Else
				SentEDArray.Add(ED);
				ArrayOfIDs.Add(Response);
				SentCnt = SentCnt + 1;
			EndIf;
			ElectronicDocumentsServiceCallServer.SaveIdentifiers(
					ArrayOfIDs,
					EDAgreement,
					PredefinedValue("Enum.EDKinds.PaymentOrder"));
		
		Except
		
			OperationKind = NStr("en='Sending of payment orders to the bank';ru='Отправка платежных поручений в банк'");
			MessageText = NStr("en='There is no connection with the bank server';ru='Нет связи с сервером банка'") + Chars.LF
							+ NStr("en='details in the event log';ru='Подробности в журнале регистрации'");
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
																		OperationKind,
																		ErrorDescription(),
																		MessageText,
																		1);
		EndTry;
	EndDo;
	Parameters.SentCnt = Parameters.SentCnt + SentCnt;
	ElectronicDocumentsServiceCallServer.SetEDStatuses(
			SentEDArray,
			PredefinedValue("Enum.EDStatuses.Sent"));
			
	DocumentsSendingDataProcessorSberbank(EDAgreement, Parameters);
	
EndProcedure

Procedure DocumentsSendingDataProcessorSberbank(EDAgreement, ParametersOO) Export
	
	NotificationTitle = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
	
	If ParametersOO.SentCnt > 0 Then
		NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(
															NStr("en='Documents sent: (%1)';ru='Отправлено документов: (%1)'"),
															ParametersOO.SentCnt);
		PaymentOrder = PredefinedValue("Enum.EDKinds.PaymentOrder");
		GetSberbankQueriesDataProcessorsResults(EDAgreement, PaymentOrder);
		
	Else
		NotificationText = NStr("en='The sent packages are not present';ru='Отправленных пакетов нет'");
	EndIf;
	
	Notify("RefreshStateED");
	
	ShowUserNotification(NotificationTitle, , NotificationText);
	
EndProcedure

// Requests night statements from the bank
//
// Parameters
//  <EDFSetup>  - <CatalogRef.EDUsageAgreements> - EDF setup
//  with Sberbank Parameters - Structure - data for data processor
//
Procedure SendQueryOnNightAccountStatementsSberbank(EDFSetup, Parameters) Export
	
	CurrentEDAgreement = ValueFromCache("CurrentEDAgreement");
	If Not EDFSetup = CurrentEDAgreement AND ValueIsFilled(CurrentEDAgreement) Then
		SessionCompleted = False;
		CompleteSessionOnToken(SessionCompleted);
		If Not SessionCompleted Then
			Return;
		EndIf;
	EndIf;
	
	If Not (ValueIsFilled(ValueFromCache("CurrentEDAgreement"))
				AND ValueIsFilled(ValueFromCache("NumberContainer"))) Then
		FormParameters = New Structure("EDAgreement", EDFSetup);
		Notification = New NotifyDescription("SendQueriesForNightStatementsSberbank", ThisObject);
		OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.DataAuthenticationQuerySberbank",
						FormParameters, , , , , Notification);
	Else
		SendQueriesForNightStatementsSberbank(EDFSetup, Parameters);
	EndIf;
		
EndProcedure

// Requests night statements from Sberbank after authorization
//
// Parameters
//  <EDFSetup>  - <CatalogRef.EDUsageAgreements> - Agreement
//
Procedure SendQueriesForNightStatementsSberbank(EDFSetup, Parameters = Undefined) Export

	If Not ValueIsFilled(EDFSetup) Then
		Return;
	EndIf;
	
	Parameters.Insert("EDFSetup", EDFSetup);
	ProcessingDetails = New NotifyDescription(
		"AfterConnectingExternalComponentSendQueryOnNightAccountStatementsSberbank", ThisObject, Parameters);
	CRParameters = New Structure;
	CRParameters.Insert("HandlerAfterConnectingComponents", ProcessingDetails);
	CRParameters.Insert("ModuleName", "AddIn.CryptoExtension.VPNKeyTLS");
	CRParameters.Insert("Name", "CryptoExtension");
	CRParameters.Insert("Type", AddInType.Native);
	CRParameters.Insert("BankApplication", PredefinedValue("Enum.BankApplications.SberbankOnline"));
	Parameters.Insert("CRParameters", CRParameters);
	
	ConnectBankExternalComponent(Parameters);
	
EndProcedure

// Receives statuses and identifiers of payment documents sent
//
// Parameters
//  EDFSetup  - CatalogRef.EDUsageAgreement - EDF setting
//  with Sberbank EDKind  - Enum.EDKinds - electronic document
//  kind Parameters - Structure - additional parameters
//
Procedure GetSberbankQueriesDataProcessorsResults(EDFSetup, EDKind, Parameters = Undefined) Export
	
	QueryString = "";
	IDRequest = "";
	ArrayOfIDs = ElectronicDocumentsServiceCallServer.ArrayOfQueryIDs(EDFSetup, EDKind);
	AgreementAttributes = ElectronicDocumentsServiceCallServer.EDFSettingAttributes(EDFSetup);
	
	AttachableModule1C = ValueFromCache("AttachableModule1CForSberbank");
	
	EDArrayForCheck = New Array;
	
	For Each ID IN ArrayOfIDs Do
	
		Try
			
			Response = AttachableModule1C.getRequestStatus(ID, AgreementAttributes.CompanyID);
			If EDKind = PredefinedValue("Enum.EDKinds.PaymentOrder") Then
				DetailsSend = NStr("en='Identifier of the sent payment order has been sent';ru='Отправлен идентификатор отправленного платежного поручения'");
				DetailsGet = NStr("en='Status for processing the sent payment calendar has been received';ru='Получен статус обработки отправленного платежного поручения'");
			ElsIf EDKind = PredefinedValue("Enum.EDKinds.QueryStatement") Then
				DetailsSend = NStr("en='Sent request ID of the banking statement has been sent';ru='Отправлен идентификатор отправленного запроса банковской выписки'");
				DetailsGet = NStr("en='Obtained the processing status of the sent bank statement request';ru='Получен статус обработки отправленного запроса банковской выписки'");
			ElsIf EDKind = PredefinedValue("Enum.EDKinds.QueryNightStatements") Then
				DetailsSend = NStr("en='Identifier of the sent night statement request has been sent';ru='Отправлен идентификатор отправленного запроса ночной выписки'");
				DetailsGet = NStr("en='Received a processing status of the sent night statement request';ru='Получен статус обработки отправленного запроса ночной выписки'");
			ElsIf EDKind = PredefinedValue("Enum.EDKinds.BankStatement") Then
				DetailsSend = NStr("en='Request ID of the completed banking statements has been sent';ru='Отправлен идентификатор запроса готовой выписки банка'");
				DetailsGet = NStr("en='Banking statement is received';ru='Получена банковская выписка'");
			EndIf;
			ElectronicDocumentsServiceCallServer.WriteEventToLogAudit(
										EDFSetup, DetailsSend, ID);
			ElectronicDocumentsServiceCallServer.WriteEventToLogAudit(
										EDFSetup, DetailsGet, Response);
			
			NewEDArray = New Array;
			If Response = "<!--NOT PROCESSED YET-->" OR Response = "<!--NOT_PROCESSED_YET-->" Then
				Continue; // Query is not processed yet
			ElsIf Response = "<!--REQUEST NOT FOUND-->" OR Response = "<!--REQUEST_NOT_FOUND-->" Then
				ElectronicDocumentsServiceCallServer.DeleteIDRequest(EDFSetup, ID, EDKind);
				Continue; // identifier is not found in bank base
			EndIf;
				
			ElectronicDocumentsServiceCallServer.HandleSberbankResponse(
						Response, EDFSetup, EDKind, NewEDArray, ID);
			CommonUseClientServer.SupplementArray(EDArrayForCheck, NewEDArray);
		
		Except
			
			OperationKind = NStr("en='Obtaining of information on the documents processing results';ru='Получение информации о результатах обработки документов'");
			MessageText = NStr("en='There is no connection with the bank server';ru='Нет связи с сервером банка'") + Chars.LF
							+ NStr("en='details in the event log';ru='Подробности в журнале регистрации'");
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
				OperationKind, ErrorDescription(), MessageText, 1);
			Break;
			
		EndTry;
		
	EndDo;
	
	If EDKind = PredefinedValue("Enum.EDKinds.BankStatement") Then
		Notify("StatementsReceived");
	EndIf;
	
	Notify("RefreshStateED");
	
	If ValueIsFilled(Parameters) Then
		If Parameters.Property("GetBankStatementsDataProcessorsResults") Then
			Parameters.Delete("GetBankStatementsDataProcessorsResults");
			GetSberbankQueriesDataProcessorsResults(
				EDFSetup, PredefinedValue("Enum.EDKinds.BankStatement"), Parameters);
			Return;
		ElsIf Parameters.Property("GetNightStatementsQueryDataProcessorsResults") Then
			Parameters.Delete("GetNightStatementsQueryDataProcessorsResults");
			GetSberbankQueriesDataProcessorsResults(
				EDFSetup, PredefinedValue("Enum.EDKinds.QueryNightStatements"), Parameters);
			Return;
		ElsIf Parameters.Property("SendQueryToGetReadyAccountStatementsSberbank") Then
				Parameters.Delete("SendQueryToGetReadyAccountStatementsSberbank");
			SendQueryToGetReadyAccountStatementsSberbank(EDFSetup);
		EndIf;
	EndIf;
	
	CheckParameters = New Structure("EDArrayForCheckingSberbankDS", EDArrayForCheck);
	CheckParameters.Insert("SberbankDSCheckIndex", 0);
	DetermineStatusOfSignaturesFromSberbank(EDFSetup, CheckParameters);
	
EndProcedure

// for internal use only
Procedure QueryExtractSberbank(EDAgreement, Company, StartDate, EndDate, Night = False, ED = Undefined) Export
	
	CurrentEDAgreement = ValueFromCache("CurrentEDAgreement");
	If Not EDAgreement = CurrentEDAgreement AND ValueIsFilled(CurrentEDAgreement) Then
		SessionCompleted = False;
		CompleteSessionOnToken(SessionCompleted);
		If Not SessionCompleted Then
			Return;
		EndIf;
	EndIf;
	
	ED = "";
	QueryString = "";
	
	AvailableCertificates = ElectronicDocumentsServiceCallServer.GetAvailableBankCertificates(
													EDAgreement,
													PredefinedValue("Enum.EDKinds.QueryStatement"));
	If AvailableCertificates.Count()=0 Then
		MessageText = NStr("en='The proper signature certificate for <%1> company and <Statement request> document type is not found';ru='Не найден подходящий сертификат подписи для организации <%1> и вида документа <Запрос выписки>'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, Company);
		Message(MessageText, MessageStatus.Important);
		Return;
	EndIf;
	
	ElectronicDocumentsServiceCallServer.GenerateEDQueryAccountstatements(
								EDAgreement, StartDate, EndDate, ED);
			
	If Not ValueIsFilled(ED) Then
		Return;
	EndIf;
	
	EDKindsArray = New Array;
	EDKindsArray.Add(ED);
	Parameters = New Structure;
	Parameters.Insert("AddedSberbankFiles", EDKindsArray);
	Parameters.Insert("TotalDigitallySignedCnt", 0);
	Parameters.Insert("ThisIsStatementQuery");
	SignSberbankED(EDAgreement, Parameters);
	
EndProcedure


// Adds signature for Sberbank document with the use of token
//
// Parameters
//  <AddedFiles>  - <Array> - contains the references
//  to electronic documents <SignatureCertificate>  - <CatalogRef.DSCertificates> - reference to
//  signature certificate <SignedEDNumber>  - <Number> - number of successfully signed ED
//
Procedure SignEDOfSpecificCertificate(EDAgreement, AddedFiles, SignatureCertificate, Parameters) Export
	
	Parameters.Insert("AddedSberbankFiles", AddedFiles);
	
	CurrentEDAgreement = ValueFromCache("CurrentEDAgreement");
	If Not EDAgreement = CurrentEDAgreement AND ValueIsFilled(CurrentEDAgreement) Then
		SessionCompleted = False;
		CompleteSessionOnToken(SessionCompleted);
		If Not SessionCompleted Then
			Return;
		EndIf;
	EndIf;
	
	If ValueIsFilled(SignatureCertificate) Then
		ValidateCertificateValidityPeriod(SignatureCertificate);
		NumberContainer = ElectronicDocumentsServiceCallServer.NumberContainer(SignatureCertificate, EDAgreement);
		If Not NumberContainer = ValueFromCache("NumberContainer") Then
			FormParameters = New Structure("ContainerNumber, EDAgreement", NumberContainer, EDAgreement);
		
			Notification = New NotifyDescription("SignSberbankED", ThisObject, Parameters);
			
			OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.DataAuthenticationQuerySberbank",
							FormParameters, , , , , Notification);
			Return;
		EndIf;
	ElsIf Not ValueIsFilled(ValueFromCache("CurrentEDAgreement"))
		OR Not ValueIsFilled(ValueFromCache("NumberContainer")) Then
		
		FormParameters = New Structure("EDAgreement", EDAgreement);
				
		Notification = New NotifyDescription("SignSberbankED", ThisObject, Parameters);
		
		OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.DataAuthenticationQuerySberbank",
					FormParameters, , , , , Notification);
		Return;
	EndIf;
		
	SignSberbankED(EDAgreement, Parameters)
	
EndProcedure

// Adds the signature to Sberbank document after authorization
//
// Parameters
//  EDAgreement  - CatalogRef.EDFUsageAgreements - agreement
//  with bank AddedFiles  - Array - contains references to Catalog.EDAttachedFiles
//
Procedure SignSberbankED(EDFSetup, Parameters) Export
	
	AddedFiles = Parameters.AddedSberbankFiles;
	
	If Not ValueIsFilled(EDFSetup) Then
		Return;
	EndIf;

	Parameters.Insert("EDFSetup", EDFSetup);
	ProcessingDetails = New NotifyDescription(
		"AfterConnectingComponentSignSberbankED", ThisObject, Parameters);
	CRParameters = New Structure;
	CRParameters.Insert("HandlerAfterConnectingComponents", ProcessingDetails);
	CRParameters.Insert("ModuleName", "AddIn.CryptoExtension.VPNKeyTLS");
	CRParameters.Insert("Name", "CryptoExtension");
	CRParameters.Insert("Type", AddInType.Native);
	CRParameters.Insert("BankApplication", PredefinedValue("Enum.BankApplications.SberbankOnline"));
	Parameters.Insert("CRParameters", CRParameters);
	
	ConnectBankExternalComponent(Parameters);
	
EndProcedure


// Determines validity of set signatures and saves the result in ED
//
// Parameters:
// EDAgreement - CatalogRef.EDUsageAgreements - agreement
// with Sberbank Parameters - Structure - contains data for data processor
//
Procedure DetermineStatusOfSignaturesFromSberbank(EDFSetup, Parameters) Export

	Parameters.Insert("EDFSetup", EDFSetup);
	ProcessingDetails = New NotifyDescription(
		"AfterConnectingComponentDetermineSberbankSignaturesStatuses", ThisObject, Parameters);

	CRParameters = New Structure;
	CRParameters.Insert("HandlerAfterConnectingComponents", ProcessingDetails);
	CRParameters.Insert("ModuleName", "AddIn.CryptoExtension.VPNKeyTLS");
	CRParameters.Insert("Name", "CryptoExtension");
	CRParameters.Insert("Type", AddInType.Native);
	CRParameters.Insert("BankApplication", PredefinedValue("Enum.BankApplications.SberbankOnline"));
	Parameters.Insert("CRParameters", CRParameters);
	
	ConnectBankExternalComponent(Parameters);

EndProcedure


Function SberbankCertificateIdentifier(AttachableModule, CertificateBinaryData)
	
	IDCertificate = "";
	Try
		DSCertificate = New CryptoCertificate(CertificateBinaryData);
		SerialNumber = Base64String(DSCertificate.SerialNumber);
		AttachableModule.FindCertificate(SerialNumber, 0, 0, 0, 0, 0, 0, 0, 0, IDCertificate);
		If IsBlankString(IDCertificate) Then
			Operation = NStr("en='Search for signature certificate on bank key by serial number';ru='Поиск сертификата подписи на банковском ключе по серийному номеру'");
			MessageText = NStr("en='Signature certificate is not found
		|on bank key See details in the event log';ru='Не найден сертификат подписи
		|на банковском ключе Подробности в журнале регистрации'");
			ErrorText = NStr("en='Certificate signature is not found on bank key';ru='Не найден сертификат подписи на банковском ключе'");
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
												Operation, ErrorText, MessageText, 1);
			ClearAuthorizationDataSberbank();
		EndIf;
	Except
		ClearMessages();
		MessageText = NStr("en='When searching for certificate on bank key,
		|an error occurred See details in the event log';ru='При поиске сертификата на банковском
		|ключе произошла ошибка Подробности в журнале регистрации'");
		ErrorText = ErrorDescription();
		ClearAuthorizationDataSberbank();
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
											Operation, ErrorText, MessageText, 1);
	EndTry;

	Return IDCertificate;
	
EndFunction

// Sets encrypted channel with the bank through a token
//
// Parameters
//  <EDAgreement>  - <CatalogRef.AgreementAboutEDUsage> - agreement on electronic
//  documents exchange <ChannelCreated>  - <Boolean> - a flag showing that the channel is created
//
Procedure SetVirtualChannelWithSberbank(EDFSetup, ChannelCreated, ND) Export
	
	If Not ValueIsFilled(EDFSetup) Then
		Return;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("EDFSetup", EDFSetup);
	Parameters.Insert("AlertAfterInstallingVirtualChannel", ND);
	
	ProcessingDetails = New NotifyDescription(
		"AfterConnectingComponentSetVirtualChannelSberbank", ThisObject, Parameters);

	CRParameters = New Structure;
	CRParameters.Insert("HandlerAfterConnectingComponents", ProcessingDetails);
	CRParameters.Insert("ModuleName", "AddIn.CryptoExtension.VPNKeyTLS");
	CRParameters.Insert("Name", "CryptoExtension");
	CRParameters.Insert("Type", AddInType.Native);
	CRParameters.Insert("BankApplication", PredefinedValue("Enum.BankApplications.SberbankOnline"));
	Parameters.Insert("CRParameters", CRParameters);
	
	ConnectBankExternalComponent(Parameters);

EndProcedure

// Executes data caching after authorization on Sberbank server
//
// Parameters
//  Name  - String - cached parameter
//  name Value  - Arbitrary - value of cached parameter
//
Procedure CasheSberbankParameter(Description, Value) Export
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	If TypeOf(ExchangeWithBanksSubsystemsParameters) <> Type("Map") Then
		ApplicationParameters.Insert("ExchangeWithBanks.Parameters", New Map);
		ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	EndIf;
	
	ExchangeParametersSberbank = ExchangeWithBanksSubsystemsParameters.Get("Sberbank");
	
	If ExchangeParametersSberbank = Undefined Then
		ExchangeParametersSberbank = New Structure;
	EndIf;
	
	ExchangeParametersSberbank.Insert(Description, Value);
	ExchangeWithBanksSubsystemsParameters.Insert("Sberbank", ExchangeParametersSberbank);
	
EndProcedure

// Completes an open session on the token of Sberbank
//
// Parameters:
//  SessionCompleted  - Boolean - If you manage to finish the session, True is returned, otherwise, False
//
Procedure CompleteSessionOnToken(SessionCompleted) Export
	
	AttachableModule = ValueFromCache("AttachableModule");
	Res = AttachableModule.CompleteSession();
	ClearAuthorizationDataSberbank();
	IsError = Not (Res = 0);
	If IsError Then
		ClearMessages();
		MessageText = NStr("en='Failed to complete the session on token.
		|Token restart is required';ru='Не удалось завершить сессию на токене.
		|Необходим перезапуск токена'");
		ErrorText = NStr("en='AddIn.Bicrypt component at the completion of the session on the token has returned an error code';ru='Компонента AddIn.Bicrypt при завершении сессии на токене вернула код ошибки'") + Res;
		Operation = NStr("en='Session completion on token';ru='Завершение сессии на токене.'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
	Else
		CasheSberbankParameter("ChannelSet", False);
	EndIf;
	
	SessionCompleted = Not IsError;
	
EndProcedure

// Returns cached parameter of exchange with Sberbank
//
// Parameters
//  ParameterName  - String - parameter name.
//
// Returns:
// Arbitrary - parameter value
//
Function ValueFromCache(ParameterName) Export
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	If TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map") Then
		ExchangeParametersSberbank = ExchangeWithBanksSubsystemsParameters.Get("Sberbank");
		If ExchangeParametersSberbank <> Undefined AND ExchangeParametersSberbank.Property(ParameterName) Then
			Return ExchangeParametersSberbank[ParameterName];
		EndIf;
	EndIf;
	
EndFunction
// Clears cached parameters of exchange with Sberbank
//
Procedure ClearAuthorizationDataSberbank() Export
	
	ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
	If TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map") Then
		ExchangeWithBanksSubsystemsParameters.Delete("Sberbank");
	EndIf;
	
EndProcedure

Procedure HandleSberbankAuthenticationDataEntry(EDAgreement, Parameters) Export
	
	If Not ValueIsFilled(EDAgreement) Then
		Return
	EndIf;

	AuthorizationCompleted = False;
	CompleteAuthenticationOnSberbankToken(EDAgreement, AuthorizationCompleted, Parameters.ND, False);
	If AuthorizationCompleted Then
		FinishSettingVirtualChannelWithSberbank(EDAgreement, Parameters.ND);
	EndIf;
	
EndProcedure

// Executes authentication procedure in bank key
//
// Parameters
//  EDAgreement  - CatalogRef.EDUsageAgreements - reference to the
//  agreement with bank Parameters - Structure - contains additional
//    parameters * AuthorizationCompleted - Boolean - flag of
//    successful authentication * ForcedAuthentication - Boolean - True if proceed with the authentication even it was
//                                              completed earlier; False, proceed with the authentication only if it was not completed yet
//
Procedure ExecuteAuthenticationOnSberbankToken(EDFSetup, Parameters) Export
	
	Parameters.Insert("EDFSetup", EDFSetup);
	ProcessingDetails = New NotifyDescription(
		"AfterConnectingComponentExecuteAuthenticationOnSberbankToken", ThisObject, Parameters);
	CRParameters = New Structure;
	CRParameters.Insert("HandlerAfterConnectingComponents", ProcessingDetails);
	CRParameters.Insert("ModuleName", "AddIn.CryptoExtension.VPNKeyTLS");
	CRParameters.Insert("Name", "CryptoExtension");
	CRParameters.Insert("Type", AddInType.Native);
	CRParameters.Insert("BankApplication", PredefinedValue("Enum.BankApplications.SberbankOnline"));
	Parameters.Insert("CRParameters", CRParameters);

	ConnectBankExternalComponent(Parameters);

EndProcedure

Procedure CompleteAuthenticationOnSberbankToken(EDAgreement, AuthorizationCompleted, ND, ReAuthorization)
	
	AttachableModule = ValueFromCache("AttachableModule");
	AuthorizationResult = AttachableModule.ShowPin(ValueFromCache("NumberContainer"), ValueFromCache("PinCode"));
	If Not (AuthorizationResult = 0) Then
		If Not ReAuthorization AND AuthorizationResult = 24 Then
			SessionCompleted = False;
			If ValueFromCache("AuthorizationCompleted") = True Then
				CompleteSessionOnToken(SessionCompleted);
			Else
				ClearMessages();
				MessageText = NStr("en='Failed to get authorized on the token.';ru='Не удалось авторизоваться на токене.'") + Chars.LF
					+ NStr("en='It is necessary to restart of the banking key';ru='Необходимо выполнить перезапуск банковского ключа'");
				ErrorText = NStr("en='AddIn.Bicrypt component has returned an error code at the registration on the token';ru='Компонента AddIn.Bicrypt при авторизации на токене вернула код ошибки'")
					+ " " + AuthorizationResult;
				Operation = NStr("en='Log in on token';ru='Авторизация на токене'");
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
			EndIf;
			If SessionCompleted Then
				Parameters = New Structure;
				Parameters.Insert("AuthorizationCompleted", AuthorizationCompleted);
				Parameters.Insert("ND", ND);
				Parameters.Insert("ReAuthorization", True);
				ExecuteAuthenticationOnSberbankToken(EDAgreement, Parameters);
				Return;
			EndIf;
		ElsIf AuthorizationResult = 28 Then
			MessagePattern = NStr("en='PIN%1 is blocked';ru='PIN%1 заблокирован'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
								MessagePattern, ValueFromCache("NumberContainer"));
			CommonUseClientServer.MessageToUser(MessageText);
		ElsIf AuthorizationResult = 27 Then
			MessagePattern = NStr("en='PUK%1 is blocked';ru='PUK%1 заблокирован'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
								MessagePattern, ValueFromCache("NumberContainer"));
			CommonUseClientServer.MessageToUser(MessageText);
		ElsIf AuthorizationResult = 25 Then
			CommonUseClientServer.MessageToUser(NStr("en='User is locked';ru='Пользователь заблокирован'"));
		ElsIf AuthorizationResult = 29 OR AuthorizationResult = 30 Then
			CommonUseClientServer.MessageToUser(NStr("en='Incorrect authorization data';ru='Неверные данные авторизации'"));
		ElsIf Not (ValueFromCache("AuthorizationCompleted") = True) Then
			ClearMessages();
			MessageText = NStr("en='Failed to get authorized on the token.';ru='Не удалось авторизоваться на токене.'") + Chars.LF
				+ NStr("en='It is necessary to restart of the banking key';ru='Необходимо выполнить перезапуск банковского ключа'");
			ErrorText = NStr("en='AddIn.Bicrypt component has returned an error code at the registration on the token';ru='Компонента AddIn.Bicrypt при авторизации на токене вернула код ошибки'")
				+ " " + AuthorizationResult;
			Operation = NStr("en='Log in on token';ru='Авторизация на токене'");
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
			ClearAuthorizationDataSberbank();
			CasheSberbankParameter("AuthorizationCompleted", False);
		EndIf;
		Return
	EndIf;
	CasheSberbankParameter("AuthorizationCompleted", True);
	AuthorizationCompleted = True;
	
EndProcedure

Procedure FinishSettingVirtualChannelWithSberbank(EDAgreement, ND)
	
	NumberBusinessSystem = GetBusinessSystemNumber();
	
	If NumberBusinessSystem = -1 Then //failed to determine business system
		Return;
	EndIf;
	
	AttachableModule = ValueFromCache("AttachableModule");
	
	ConnectionResult = AttachableModule.InstallTLSChannelWithBusinessSystem(NumberBusinessSystem);
	
	If Not ConnectionResult = 0 Then
		ClearMessages();
		Operation = NStr("en='Virtual channel installation';ru='Установка виртуального канала'");
		MessageText = NStr("en='Failed to install connection to the server.
		|It is necessary to verify the TLS VPN Key work.';ru='Не удалось установить связь с сервером.
		|Необходимо проверить работу TLS VPN Key.'");
		ErrorText = NStr("en='AddIn.Bicrypt component has returned an error code at installation of the virtual channel';ru='Компонента AddIn.Bicrypt при установке виртуального канала вернула код ошибки'")
							+ " " + ConnectionResult;
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
											Operation, ErrorText, MessageText, 1);
		ClearAuthorizationDataSberbank();
		Return;
	EndIf;
	
	CasheSberbankParameter("ChannelSet", True);
	
	ExecuteNotifyProcessing(ND, EDAgreement);
	
EndProcedure

Function GetBusinessSystemNumber()
	
	NumberBusinessSystem = -1;
	NameBusinessSystem = """Test SBBOL2_upg_internet""";
	AttachableModule = ValueFromCache("AttachableModule");
	BusinessSystem = "";
	Res = AttachableModule.GetListBusinessSystemsVPNKeyTLS(BusinessSystem);
	If Res <> 0 Then
		ClearMessages();
		MessageText = NStr("en='An error occurred when receiving a list of business systems.
		|Details in the event log.';ru='Ошибка при получении списка бизнес систем.
		|Подробности в журнале регистрации.'");
		ErrorText = NStr("en='When receving the list of business systems, component AddIn.Bicrypt returned %1 error code';ru='Компонента AddIn.Bicrypt при получении списка бизнес систем вернула код ошибки %1'");
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorText, Res);
		Operation = NStr("en='Receiving the business system list.';ru='Получение списка бизнес систем.'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
		ClearAuthorizationDataSberbank();
		Return NumberBusinessSystem;
	EndIf;
	Try
		RowArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(BusinessSystem, Chars.LF);
		For Each String in RowArray Do
			If Find(Upper(String), Upper(NameBusinessSystem)) > 0 Then
				FirstQuotePos = Find(String, """");
				BusinessSystemString = Mid(String, FirstQuotePos + 1);
				SecondQuatationPos = Find(BusinessSystemString, """");
				BusinessSystemString = Mid(BusinessSystemString, 1 , SecondQuatationPos - 1);
				NumberBusinessSystem = Number(BusinessSystemString);
				Break;
			EndIf;
		EndDo;
	Except
		ClearMessages();
		MessageText = NStr("en='An error occurred when reading a list of business systems.
		|Details in the event log.';ru='Ошибка чтения списка бизнес систем.
		|Подробности в журнале регистрации.'");
		ErrorText = NStr("en='AddIn.Bicrypt component has returned an error code at business systems list receiving';ru='Компонента AddIn.Bicrypt при получении списка бизнес систем код ошибки'") + Res
						+ Chars.LF + NStr("en='Return list content:';ru='Содержимое списка возврата:'") + " " + Chars.LF + BusinessSystem + "'";
		Operation = NStr("en='Receiving the business system list.';ru='Получение списка бизнес систем.'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
	EndTry;

	If NumberBusinessSystem = -1 Then
		MessageText = NStr("en='Business system is not found in bank key.
		|It is necessary to verify the TLS VPN Key work.';ru='Не найдена бизнес система на банковском ключе.
		|Необходимо проверить работу TLS VPN Key.'");
		Operation = NStr("en='Search of the business system on the electronic key.';ru='Поиск бизнес системы на электронном ключе.'");
		ErrorText = NStr("en='Business system has not been found on the electronic key:';ru='На электронном ключе не найдена бизнес система:'") + " " + NameBusinessSystem 
					+ Chars.LF
					+ NStr("en='Return list content:';ru='Содержимое списка возврата:'") + " " + Chars.LF + BusinessSystem + "'";
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation, ErrorText, MessageText, 1);
	EndIf;
	
	Return NumberBusinessSystem;
	
EndFunction

Procedure AfterInstallingSberbankExternalComponent(Parameters) Export
	
	ExecuteNotifyProcessing(Parameters.ND, Parameters.EDAgreement);
	
EndProcedure

// Sends the query for receipt of ready account statements to the bank
//
// Parameters
//  <EDAgreement>  - <CatalogRef.AgreementAboutEDUsage> - agreement on electronic documents exchange
//
Procedure SendQueryToGetReadyAccountStatementsSberbank(EDAgreement) Export
	
	Try
		
		RowValue = ElectronicDocumentsServiceCallServer.QueryTextQueryStatusBankStatements(EDAgreement);
		
		If IsBlankString(RowValue) Then
			Return;
		EndIf;
		
		AttachableModule1C = ValueFromCache("AttachableModule1CForSberbank");
		Response = AttachableModule1C.sendRequests(RowValue);
		Definition = NStr("en='Request for the final statement on receipt has been sent';ru='Оправлен запрос на получение готовой выписки'");
		ElectronicDocumentsServiceCallServer.WriteEventToLogAudit(
										EDAgreement, Definition, RowValue);
		ArrayOfIDs = New Array;
		ArrayOfIDs.Add(Response);
		EDTypeBankStatement = PredefinedValue("Enum.EDKinds.BankStatement");
		ElectronicDocumentsServiceCallServer.SaveIdentifiers(
					ArrayOfIDs, EDAgreement, EDTypeBankStatement);
					
		Definition = NStr("en='Bank statement identifiers are received';ru='Получены идентификаторы банковских выписок'");
		ElectronicDocumentsServiceCallServer.WriteEventToLogAudit(
													EDAgreement, Definition, Response);
		EDKind = PredefinedValue("Enum.EDKinds.BankStatement");
		GetSberbankQueriesDataProcessorsResults(EDAgreement, EDKind);

	Except
		
		OperationKind = NStr("en='Receiving the banking statements';ru='Получение банковских выписок'");
		MessageText = NStr("en='There is no connection with the bank server';ru='Нет связи с сервером банка'") + Chars.LF
						+ NStr("en='details in the event log';ru='Подробности в журнале регистрации'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
									OperationKind, ErrorDescription(), MessageText, 1);
		
	EndTry;
	
EndProcedure

Procedure SendQueryOnSberbankStatement(EDAgreement, Parameters) Export
	
	ChannelCreated = False;
	ND = New NotifyDescription("SendQueryOnSberbankStatement", ThisObject, Parameters);
	SetVirtualChannelWithSberbank(EDAgreement, ChannelCreated, ND);
	
	If Not ChannelCreated Then
		Return;
	EndIf;
	
	ED = Parameters.AddedSberbankFiles[0];
	
	Try
		
		AttachableModule1C = ValueFromCache("AttachableModule1CForSberbank");

		IDRequest = Undefined;
		CompanyID = Undefined;
		DataStructureOfED = ElectronicDocumentsServiceCallServer.GetPackageFileSberBank(
									ED, EDAgreement, IDRequest, CompanyID);
		XMLString = DataStructureOfED.XMLString;
			
		Response = AttachableModule1C.sendRequests(XMLString);
		Definition = NStr("en='Request for statement has been sent to the bank';ru='Запрос на выписку отправлен в банк'");
		ElectronicDocumentsServiceCallServer.WriteEventToLogAudit(
												EDAgreement, Definition, XMLString);
		Definition = NStr("en='Received an ID for sending of request for the statement';ru='Получен идентификатор отправки запроса на выписку'");
		ElectronicDocumentsServiceCallServer.WriteEventToLogAudit(
												EDAgreement, Definition, Response);
		ArrayOfIDs = New Array;
		IsError = False;
		
		If Mid(Response, 1, 23) = "00000000-0000-0000-0000" Then
			DetermineErrorAndInformUser(EDAgreement, ED, IDRequest, CompanyID, Response);
			IsError = True;
		Else
			ArrayOfIDs.Add(Response);
		EndIf;
				
		If IsError Then
			Return;
		EndIf;
				
		ElectronicDocumentsServiceCallServer.SaveIdentifiers(
				ArrayOfIDs,
				EDAgreement,
				PredefinedValue("Enum.EDKinds.QueryStatement"));
						
		ElectronicDocumentsServiceCallServer.SetEDStatus(
			ED, PredefinedValue("Enum.EDStatuses.Sent"));
				
	Except
		
		OperationKind = NStr("en='Bank statement request';ru='Запрос выписки банка'");
		MessageText = NStr("en='There is no connection with the bank server';ru='Нет связи с сервером банка'") + Chars.LF + NStr("en='details in the event log';ru='Подробности в журнале регистрации'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(OperationKind, ErrorDescription(), MessageText, 1);
	EndTry;
	
	Notify("RefreshStateED");
	
EndProcedure

Procedure DetermineErrorAndInformUser(EDAgreement, TypeQuery, IDRequest, CompanyID, Ticket)
	
	If Ticket = "00000000-0000-0000-0000-000000000000" OR Ticket = "00000000-0000-0000-0000-000000000006" Then
		MessageText = NStr("en='Connection error. Bank service is not available. Try again or contact your bank.';ru='Ошибка связи. Сервис банка недоступен. Повторите попытку или обратитесь в свой банк.'");
		If TypeOf(TypeQuery) = Type("CatalogRef.EDAttachedFiles")
			AND ElectronicDocumentsServiceCallServer.EDKindAndOwner(TypeQuery).EDKind = PredefinedValue(
				"Enum.EDKinds.QueryStatement") Then
			TransferError = PredefinedValue("Enum.EDStatuses.TransferError");
			ChangingParameters = New Structure;
			ChangingParameters.Insert("EDStatus", TransferError);
			ChangingParameters.Insert("RejectionReason", MessageText);
			ElectronicDocumentsServiceCallServer.ChangeByRefAttachedFile(TypeQuery, ChangingParameters, False);
		EndIf;
		CommonUseClientServer.MessageToUser(MessageText);
	ElsIf Ticket = "00000000-0000-0000-0000-000000000007" Then
		MessageText = NStr("en='Invalid company identifier.
		|Check EDF settings with the bank or contact your bank';ru='Неверный идентификатор организации.
		|Проверьте настройки ЭДО с банком или обратитесь в свой банк'");
		If TypeOf(TypeQuery) = Type("CatalogRef.EDAttachedFiles") Then
			RejectedByBank = PredefinedValue("Enum.EDStatuses.RejectedByBank");
			ChangingParameters = New Structure;
			ChangingParameters.Insert("EDStatus", RejectedByBank);
			ChangingParameters.Insert("RejectionReason", MessageText);
			ElectronicDocumentsServiceCallServer.ChangeByRefAttachedFile(TypeQuery, ChangingParameters, False);
		EndIf;
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		MessageText = NStr("en='Bank server returned unknown error code.
		|Repeat session or contact your bank.';ru='Сервер банка вернул неизвестный код ошибки.
		|Повторите сеанс связи или обратитесь в свой банк.'");
	EndIf;
	
	//TODO
	//AdditionalInformationTemplate = NStr("en = 'Additional info for technical support:
	//											|Query from client - %1
	//											|Client query identifier - %2
	//											|Client company identifier - %3
	//											|Code of bank response:
	//											%4 |Bank response message: %5'");
	//											
	//Try
	//	
	//	AttachableModule1C = ValueFromCache("AttachableModule1CForSberbank");
	//	Response = AttachableModule1C.sendRequests(Ticket);
	//	DetailsSend = NStr("en='Error identifier sent';ru='Отправлен идентификатор ошибки'");
	//	DetailsGet = NStr("en='Error description received';ru='Получено описание ошибки'");
	//		
	//	ElectronicDocumentsServiceServerCall.WriteEventToAuditLog
	//									(ED Agreement, SendingDescription, Ticket);
	//		
	//	ElectronicDocumentsServiceServerCall.WriteEventToAuditLog
	//									(ED Agreement, ReceiptDescription, Response);
	//	
	//	ResponsesArray = New Array;
	//	
	//	XMLReader = New XMLReader;
	//	XMLReading.SetString(Response);
	//	ED = XDTOFactory.ReadXML(XMLReader, XDTOFactory.Type("http://www.bssys.com/en/", "Response"));
	//	ED.Validate();
	//	
	//	If Not ED.Errors =
	//		Undefined Then For Each Error From
	//		ED.Errors.Error Cycle AdditionalInformation
	//		= StringFunctionsClientServer.InsertParametersIntoString( AdditionalInformationTemplate, QueryType,
	//		QueryIdentifier, CompanyIdentifier, Error.Code, Error.Desc);
	//			CommonUseClientServer.InformUser(MessageText + Symbols.LF + AdditionalInformation);
	//		EndDo;
	//	EndIf;
	//	
	//Except
	//	OperationKind = NStr("en='Receiving information about the error';ru='Получение информации об ошибке'");
	//	MessageText = NStr("en = 'Error in data exchange
	//								|with the bank See details in the event log'");
	//	ElectronicDocumentsServiceServerCall.ProcessExceptionByEDOnServer(
	//		OperationKind, ErrorDescription(), MessageText, 1);
	//TryEnd;
	
EndProcedure

// Displays the notification on responsible person change
Procedure NotifyUserAboutResponsibleChange(Responsible, CountTotal, NumberOfProcessed) Export
	
	If NumberOfProcessed > 0 Then
			
		MessageText = NStr("en='For %NumberProcessed% from %TotalNumber% of
		|selected electronic documents responsible ""%Responsible%"" is set';ru='Для %КоличествоОбработанных% из %КоличествоВсего% выделенных эл.документов установлен ответственный ""%Ответственный%""'");
		MessageText = StrReplace(MessageText, "%NumberSelected%", NumberOfProcessed);
		MessageText = StrReplace(MessageText, "%CountTotal%",        CountTotal);
		MessageText = StrReplace(MessageText, "%Responsible%",          Responsible);
		HeaderText = NStr("en='Responsible ""%Responsible%"" is set';ru='Ответственный ""%Ответственный%"" установлен'");
		HeaderText = StrReplace(HeaderText, "%Responsible%", Responsible);
		ShowUserNotification(HeaderText, , MessageText, PictureLib.Information32);
		
	Else
		
		MessageText = NStr("en='Responsible ""%Responsible%"" is not set for any electronicdocument.';ru='Ответственный ""%Ответственный%"" не установлен ни для одного эл.документа.'");
		MessageText = StrReplace(MessageText, "%Responsible%", Responsible);
		HeaderText = NStr("en='Responsible ""%Responsible%"" is not set';ru='Ответственный ""%Ответственный%"" не установлен'");
		HeaderText = StrReplace(HeaderText, "%Responsible%", Responsible);
		ShowUserNotification(HeaderText,, MessageText, PictureLib.Information32);
		
	EndIf;
	
EndProcedure

Procedure ChangeResponsiblePerson(Val EDKindsArray, Val NotificationProcessing) Export
	
	If Not ElectronicDocumentsServiceCallServer.IsRightToProcessED(True) Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ED", EDKindsArray);
	
	OpenForm("DataProcessor.ElectronicDocuments.Form.RedirectED", FormParameters, , , , , NotificationProcessing);
	
EndProcedure

//for internal use only
Procedure AnalyzeEtDBankStatement(ED) Export
	
	Var LinksToRepository, Company, EDAgreement, AccountsArray;
	
	ElectronicDocumentsServiceCallServer.GetStatementData(ED,
																	LinksToRepository,
																	AccountsArray,
																	Company,
																	EDAgreement);
	If Not ValueIsFilled(LinksToRepository) Then
		Return;
	EndIf;
	ElectronicDocumentsClientOverridable.ParseStatementFile(ED,
																	LinksToRepository,
																	Company,
																	AccountsArray,
																	EDAgreement);
	
EndProcedure

// Checks the existence of connection with the bank and displays the message about result
//
//
Procedure ValidateExistenceOfLinksWithBank(EDAgreement, TargetID) Export
	
	AgreementAttributes = ElectronicDocumentsServiceCallServer.EDFSettingAttributes(EDAgreement);
	BankApplication = AgreementAttributes.BankApplication;
	
	If BankApplication = PredefinedValue("Enum.BankApplications.SberbankOnline") Then
		AgreementTestSberbank(EDAgreement);


	ElsIf BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
		AgreementTestThroughAdditDataProcessor(EDAgreement, TargetID);
	ElsIf BankApplication = PredefinedValue("Enum.BankApplications.iBank2") Then
		Parameters = New Structure;
		Parameters.Insert("TargetID", TargetID);
		Parameters.Insert("EDAgreement", EDAgreement);
		
		ND = New NotifyDescription("StartiBank2AgreementTest", ElectronicDocumentsServiceClient, Parameters);
		Parameters.Insert("HandlerAfterConnectingComponents", ND);
		ElectronicDocumentsServiceClient.EnableExternalComponentiBank2(Parameters);
	ElsIf BankApplication = PredefinedValue("Enum.BankApplications.AsynchronousExchange") Then
		AgreementAttributes.Insert("TargetID", TargetID);
		AsyncAgreementTest(EDAgreement, AgreementAttributes);
	EndIf;

EndProcedure

// Outdated.Uses modal call. Use
// "RequestPasswordToCertificate" Function receives user password for DS certificates. If several certificates were
// transferred to AccCertificatesAndTheirStructures, then after request for password from user in this parameter one
// certificate and its parameters are placed instead of the list.
//
// Parameters:
//  AccCertificatesAndTheirStructures - Map - contains the correspondence of certificates and their parameters:
//    * Key     - CatalogRef.DSCertificates - DS certificate.
//    * Value - Structure - contains certificate parameters.
//  OperationKind                    - String - kind of operation for which user password is requested.
//  ObjectsForProcessings - Array, CatalogRef.EDAttachedFiles - one object or list of IB objects for processing;
//  WriteToIB - Boolean - True - if the password is requested for saving to catalog attribute.
//
// Returns:
//  Boolean - True - if a password for DS certificate is received, otherwise - False.
//
Function PasswordToCertificateReceived2(AccCertificatesAndTheirStructures, ObjectsForProcessings = Undefined) Export
	
	PasswordReceived = False;
	
	If TypeOf(AccCertificatesAndTheirStructures) = Type("Map") Then
		CertificatesCount = AccCertificatesAndTheirStructures.Count();
		For Each KeyAndValue IN AccCertificatesAndTheirStructures Do
			Certificate = KeyAndValue.Key;
			CertificateParameters = KeyAndValue.Value;
			BankApplication = Undefined;
			If Not ValueIsFilled(CertificateParameters) Then
				CertificateParameters = ElectronicDocumentsServiceCallServer.CertificateAttributes(Certificate);
			EndIf;
			If CertificateParameters.Property("BankApplication")
				AND CertificateParameters.BankApplication = PredefinedValue("Enum.BankApplications.SberbankOnline") Then
				PasswordReceived = True;
				Break;
			EndIf;
			UserPassword = Undefined;
			If CertificatesCount = 1 AND (CertificateParameters.Property("PasswordReceived", PasswordReceived) AND PasswordReceived
												OR CertificatePasswordReceived(Certificate, UserPassword)) Then
				If Not PasswordReceived Then
					PasswordReceived = True;
					CertificateParameters.Insert("PasswordReceived", PasswordReceived);
					CertificateParameters.Insert("UserPassword", UserPassword);
					CertificateParameters.Insert("SelectedCertificate", Certificate);
				EndIf;
				Break;
			ElsIf (BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor")
						OR BankApplication = PredefinedValue("Enum.BankApplications.iBank2"))
					AND Not ObjectsForProcessings = Undefined
					AND RelevantCertificatePasswordCacheThroughAdditionalProcessing(CertificateParameters, ObjectsForProcessings) Then
				CertificateParameters.Insert("SelectedCertificate", Certificate);
				PasswordReceived = True;
				Break;
			EndIf;
		EndDo;
		If PasswordReceived Then
			AccCertificatesAndTheirStructures = New Map;
			AccCertificatesAndTheirStructures.Insert(Certificate, CertificateParameters);
		EndIf;
	EndIf;
	
	Return PasswordReceived;

EndFunction

Procedure GetPasswordToSertificate(AccCertificatesAndTheirStructures, OperationKind, ObjectsForProcessings = Undefined, WriteToIB = False, Parameters) Export
	
	If TypeOf(AccCertificatesAndTheirStructures) = Type("Map")
		AND AccCertificatesAndTheirStructures.Count() > 0 Then
		
		NotifyDescription = Undefined;
		If Not Parameters.Property("CallNotification", NotifyDescription)
			OR TypeOf(NOTifyDescription) <> Type("NotifyDescription") Then
			
			NotifyDescription = New NotifyDescription("HandleUserPasswordEntryResult", ThisObject, Parameters);
		EndIf;
		PasswordReceived = False;
		If AccCertificatesAndTheirStructures.Count() = 1 Then
			For Each Item IN AccCertificatesAndTheirStructures Do
				If Item.Value.PasswordReceived = True Then
					Item.Value.Insert("SelectedCertificate", Item.Key);
					ExecuteNotifyProcessing(NOTifyDescription, Item.Value);
					PasswordReceived = True;
				EndIf;
				Break;
			EndDo;
		EndIf;
		If Not PasswordReceived Then
			FormParameters = New Structure();
			FormParameters.Insert("OperationKind",   OperationKind);
			FormParameters.Insert("WriteToIB",  WriteToIB);
			FormParameters.Insert("Map",  AccCertificatesAndTheirStructures);
			If ObjectsForProcessings <> Undefined Then
				If TypeOf(ObjectsForProcessings) <> Type("Array") Then
					ObjectsArray = New Array;
					ObjectsArray.Add(ObjectsForProcessings);
				Else
					ObjectsArray = ObjectsForProcessings;
				EndIf;
				FormParameters.Insert("ObjectsForProcessings", ObjectsArray);
			EndIf;
			OpenForm("DataProcessor.ElectronicDocumentsExchangeWithBank.Form.PasswordToCertificateQuery",
				FormParameters, , , , , NotifyDescription, FormWindowOpeningMode.LockWholeInterface);
		EndIf;
	EndIf;
	
EndProcedure

Procedure HandleUserPasswordEntryResult(ReturnStructure, Parameters) Export
	
	If TypeOf(ReturnStructure) = Type("Structure") Then
		SelectedCertificate = Undefined;
		If ReturnStructure.Property("SelectedCertificate", SelectedCertificate)
				AND ValueIsFilled(SelectedCertificate) Then
			CertificateParameters = Parameters.AccCertificatesAndTheirStructures[SelectedCertificate];
			CertificateParameters.Insert("PasswordReceived", True);
			CertificateParameters.Insert("UserPassword", ReturnStructure.UserPassword);
			CertificateParameters.Insert("SelectedCertificate", SelectedCertificate);
			CertificateParameters.Insert("Comment", ReturnStructure.Comment);
			Parameters.AccCertificatesAndTheirStructures.Clear();
			Parameters.AccCertificatesAndTheirStructures.Insert(SelectedCertificate, CertificateParameters);
		Else
			Parameters.AccCertificatesAndTheirStructures.Clear();
		EndIf;
	Else
		Parameters.AccCertificatesAndTheirStructures.Clear();
	EndIf;
	
	If Parameters.Property("CallNotification") Then
		ExecuteNotifyProcessing(Parameters.CallNotification);
	EndIf;
	
EndProcedure

#EndRegion
