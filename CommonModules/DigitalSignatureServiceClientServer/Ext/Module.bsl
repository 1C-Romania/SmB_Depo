////////////////////////////////////////////////////////////////////////////////
// Digital signature subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceApplicationInterface

// The function is trying to match
// data files and data signatures by the sent attachment file names.
// Match based on the rule of forming
// signature name and the extension of signature file (p7s).
// ForExample:
// Name of the data file: example.txt
// name of the signature file: example-Ivanov Petr.p7s
// name of the signature file: example-Ivanov Petr (1).p7s.
//
// Returns the map, in which:
// Key - value
// attachment file name - array of found matches - signatures.
// 
Function GetFilesAndSignaturesCorrespondence(FileNames) Export
	
	ExtensionForSignatureFiles = DigitalSignatureClientServer.PersonalSettings(
		).ExtensionForSignatureFiles;
	
	Result = New Map;
	
	// Separate files by extension.
	DataFileNames = New Array;
	SignatureFileNames = New Array;
	
	For Each FileName IN FileNames Do
		If Right(FileName, 3) = ExtensionForSignatureFiles Then
			SignatureFileNames.Add(FileName);
		Else
			DataFileNames.Add(FileName);
		EndIf;
	EndDo;
	
	// Sort the names of data files in descending order of character number in a row.
	
	For IndexA = 1 To DataFileNames.Count() Do
		MaxIndex = IndexA; // The current file is supposed to have the biggest number of characters.
		For IndexB = IndexA+1 To DataFileNames.Count() Do
			If StrLen(DataFileNames[MaxIndex-1]) > StrLen(DataFileNames[IndexB-1]) Then
				MaxIndex = IndexB;
			EndIf;
		EndDo;
		svop = DataFileNames[IndexA-1];
		DataFileNames[IndexA-1] = DataFileNames[MaxIndex-1];
		DataFileNames[MaxIndex-1] = svop;
	EndDo;
	
	// Search for attachment file names matches.
	For Each DataFileName IN DataFileNames Do
		Result.Insert(DataFileName, FindSignatureFileNames(DataFileName, SignatureFileNames));
	EndDo;
	
	// The remaining signature files are not recognized as the signature of a file.
	For Each SignatureFileName IN SignatureFileNames Do
		Result.Insert(SignatureFileName, New Array);
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Only for internal use.
Function CryptographyManagerApplicationsDescription(Application, Errors) Export
	
	ApplicationsDescription = DigitalSignatureClientServer.CommonSettings().ApplicationsDescription;
	
	If Application <> Undefined Then
		ApplicationNotFound = True;
		For Each ApplicationDescription IN ApplicationsDescription Do
			If ApplicationDescription.Ref = Application Then
				ApplicationNotFound = False;
				Break;
			EndIf;
		EndDo;
		If ApplicationNotFound Then
			CryptographyManagerAddError(Errors, Application,
				NStr("en='Not intended for use.';ru='Не предусмотрена для использования.'"), True);
			Return Undefined;
		EndIf;
		ApplicationsDescription = New Array;
		ApplicationsDescription.Add(ApplicationDescription);
	EndIf;
	
	Return ApplicationsDescription;
	
EndFunction

// Only for internal use.
Function CryptographyManagerApplicationProperties(ApplicationDescription, IsLinux, Errors, IsServer,
			PathsToApplicationsOnLinuxServers = Undefined) Export
	
	If Not ValueIsFilled(ApplicationDescription.ApplicationName) Then
		CryptographyManagerAddError(Errors, ApplicationDescription.Ref,
			NStr("en='Application name is not specified.';ru='Не указано имя программы.'"), True);
		Return Undefined;
	EndIf;
	
	If Not ValueIsFilled(ApplicationDescription.ApplicationType) Then
		CryptographyManagerAddError(Errors, ApplicationDescription.Ref,
			NStr("en='Application type is not specified.';ru='Не указан тип программы.'"), True);
		Return Undefined;
	EndIf;
	
	ApplicationProperties = New Structure("ApplicationName, PathToApplication, ApplicationType");
	
	If IsLinux Then
		If PathsToApplicationsOnLinuxServers = Undefined Then
			PathToApplication = DigitalSignatureClientServer.PersonalSettings(
				).PathToDigitalSignatureAndEncryptionApplications.Get(ApplicationDescription.Ref);
		Else
			PathToApplication = PathsToApplicationsOnLinuxServers.Get(ApplicationDescription.Ref);
		EndIf;
		
		If Not ValueIsFilled(PathToApplication) Then
			CryptographyManagerAddError(Errors, ApplicationDescription.Ref,
				NStr("en='Not intended for use.';ru='Не предусмотрена для использования.'"), IsServer, , , True);
			Return Undefined;
		EndIf;
	Else
		PathToApplication = "";
	EndIf;
	
	ApplicationProperties = New Structure;
	ApplicationProperties.Insert("ApplicationName",   ApplicationDescription.ApplicationName);
	ApplicationProperties.Insert("PathToApplication", PathToApplication);
	ApplicationProperties.Insert("ApplicationType",   ApplicationDescription.ApplicationType);
	
	Return ApplicationProperties;
	
EndFunction

// Only for internal use.
Function CryptographyManagerAlgorithmsSet(ApplicationDescription, Manager, Errors) Export
	
	SignAlgorithm = String(ApplicationDescription.SignAlgorithm);
	Try
		Manager.SignAlgorithm = SignAlgorithm;
	Except
		Manager = Undefined;
		// The platform uses the general Unknown cryptography algorithm message. Required more specific.
		CryptographyManagerAddError(Errors, ApplicationDescription.Ref, StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Unknown %1 signature algorithm is selected.';ru='Выбран неизвестный алгоритм подписи ""%1"".'"), SignAlgorithm), True);
		Return False;
	EndTry;
	
	HashAlgorithm = String(ApplicationDescription.HashAlgorithm);
	Try
		Manager.HashAlgorithm = HashAlgorithm;
	Except
		Manager = Undefined;
		// The platform uses the general Unknown cryptography algorithm message. Required more specific.
		CryptographyManagerAddError(Errors, ApplicationDescription.Ref, StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Unknown %1 hashing algorithm is selected.';ru='Выбран неизвестный алгоритм хеширования ""%1"".'"), HashAlgorithm), True);
		Return False;
	EndTry;
	
	EncryptionAlgorithm = String(ApplicationDescription.EncryptionAlgorithm);
	Try
		Manager.EncryptionAlgorithm = EncryptionAlgorithm;
	Except
		Manager = Undefined;
		// The platform uses the general Unknown cryptography algorithm message. Required more specific.
		CryptographyManagerAddError(Errors, ApplicationDescription.Ref, StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Unknown %1 encryption algorithm is selected.';ru='Выбран неизвестный алгоритм шифрования ""%1"".'"), EncryptionAlgorithm), True);
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

// Only for internal use.
Procedure CryptographyManagerApplicationNotFound(ApplicationDescription, Errors, IsServer) Export
	
	CryptographyManagerAddError(Errors, ApplicationDescription.Ref,
		NStr("en='The application is not found on the computer.';ru='Программа не найдена на компьютере.'"), IsServer, True);
	
EndProcedure

// Only for internal use.
Function CryptographyManagerApplicationNameMatch(ApplicationDescription, ApplicationNameReceived, Errors, IsServer) Export
	
	If ApplicationNameReceived <> ApplicationDescription.ApplicationName Then
		CryptographyManagerAddError(Errors, ApplicationDescription.Ref, StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Another application with the %1 name is received.';ru='Получена другая программа с именем ""%1"".'"), ApplicationNameReceived), IsServer, True);
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Only for internal use.
Procedure CryptographyManagerAddError(Errors, Application, Description,
			ToAdmin, Instruction = False, FromException = False, PathNotSpecified = False) Export
	
	ErrorProperties = New Structure;
	ErrorProperties.Insert("Application",         Application);
	ErrorProperties.Insert("Description",          Description);
	ErrorProperties.Insert("ToAdmin",   ToAdmin);
	ErrorProperties.Insert("Instruction",        Instruction);
	ErrorProperties.Insert("FromException",      FromException);
	ErrorProperties.Insert("PathNotSpecified",      PathNotSpecified);
	ErrorProperties.Insert("ApplicationsSetting", True);
	
	Errors.Add(ErrorProperties);
	
EndProcedure

// Only for internal use.
Function CertificateCheckModes() Export
	
	ArrayOfVerificationModes = New Array;
	ArrayOfVerificationModes.Add(CryptoCertificateCheckMode.IgnoreTimeValidity);
	ArrayOfVerificationModes.Add(CryptoCertificateCheckMode.AllowTestCertificates);
	
	Return ArrayOfVerificationModes;
	
EndFunction

// Only for internal use.
Function StorageTypeToSearchCertificates(InPersonalStorageOnly) Export
	
	If TypeOf(InPersonalStorageOnly) = Type("CryptoCertificateStoreType") Then
		StorageType = InPersonalStorageOnly;
	ElsIf InPersonalStorageOnly Then
		StorageType = CryptoCertificateStoreType.PersonalCertificates;
	Else
		StorageType = Undefined; // Storage containing certificates of all available types.
	EndIf;
	
	Return StorageType;
	
EndFunction

// Only for internal use.
Procedure AddCertificatesProperties(Table, CertificatesArray, WithoutFilter, PrintsOnly = False) Export
	
	#If WebClient Or ThinClient Then
		UniversalDate = CommonUseClient.UniversalDate();
	#Else
		UniversalDate = CurrentUniversalDate();
	#EndIf
	
	If PrintsOnly Then
		PrintsAlreadyAddedCertificates = Table;
		AtServer = False;
	Else
		PrintsAlreadyAddedCertificates = New Map; // To skip duplicates.
		AtServer = TypeOf(Table) <> Type("Array");
	EndIf;
	
	For Each CurrentCertificate IN CertificatesArray Do
		Imprint = Base64String(CurrentCertificate.Imprint);
		
		If CurrentCertificate.EndDate <= UniversalDate Then
			If Not WithoutFilter Then
				Continue; // Skip expired certificates.
			EndIf;
		EndIf;
		
		If PrintsAlreadyAddedCertificates.Get(Imprint) <> Undefined Then
			Continue;
		EndIf;
		PrintsAlreadyAddedCertificates.Insert(Imprint, True);
		
		If PrintsOnly Then
			Continue;
		EndIf;
		
		If AtServer Then
			String = Table.Find(Imprint, "Imprint");
			If String <> Undefined Then
				Continue; // Skip already added on client.
			EndIf;
		EndIf;
		
		CertificateProperties = New Structure;
		CertificateProperties.Insert("Imprint", Imprint);
		
		CertificateProperties.Insert("Presentation",
			DigitalSignatureClientServer.CertificatePresentation(CurrentCertificate));
		
		CertificateProperties.Insert("WhoIssued",
			DigitalSignatureClientServer.PublisherRepresentation(CurrentCertificate));
		
		If TypeOf(Table) = Type("Array") Then
			Table.Add(CertificateProperties);
		Else
			If AtServer Then
				CertificateProperties.Insert("AtServer", True);
			EndIf;
			FillPropertyValues(Table.Add(), CertificateProperties);
		EndIf;
	EndDo;
	
EndProcedure

// Only for internal use.
Procedure AddCertificatesPrints(Array, CertificatesArray) Export
	
	#If WebClient Or ThinClient Then
		UniversalDate = CommonUseClient.UniversalDate();
	#Else
		UniversalDate = CurrentUniversalDate();
	#EndIf
	
	For Each CurrentCertificate IN CertificatesArray Do
		Imprint = Base64String(CurrentCertificate.Imprint);
		
		If CurrentCertificate.EndDate <= UniversalDate Then
			Continue; // Skip expired certificates.
		EndIf;
		
		Array.Add(Imprint);
	EndDo;
	
EndProcedure

// Only for internal use.
Function SignatureProperties(BinaryDataSignatures, CertificateProperties, Comment, SignatureFileName = "") Export
	
	SignatureProperties = New Structure;
	SignatureProperties.Insert("Signature",             BinaryDataSignatures);
	SignatureProperties.Insert("Signer", UsersClientServer.AuthorizedUser());
	SignatureProperties.Insert("Comment",         Comment);
	SignatureProperties.Insert("SignatureFileName",     SignatureFileName);
	SignatureProperties.Insert("SignatureDate",         Date('00010101')); // Set before record.
	// Derived properties:
	SignatureProperties.Insert("Certificate",          CertificateProperties.BinaryData);
	SignatureProperties.Insert("Imprint",           CertificateProperties.Imprint);
	SignatureProperties.Insert("CertificateIsIssuedTo", CertificateProperties.IssuedToWhom);
	
	Return SignatureProperties;
	
EndFunction

// Only for internal use.
Function DataReceiveErrorTitle(Operation) Export
	
	If Operation = "Signing" Then
		Return NStr("en='An error occurred receiving data for signing:';ru='При получении данных для подписания возникла ошибка:'");
		
	ElsIf Operation = "Encryption" Then
		Return NStr("en='An error occurred receiving data for encryption:';ru='При получении данных для шифрования возникла ошибка:'");
	Else
		Return NStr("en='An error occurred receiving data for decryption:';ru='При получении данных для расшифровки возникла ошибка:'");
	EndIf;
	
EndFunction

// Only for internal use.
Function EmptySignatureData(SignatureData, ErrorDescription) Export
	
	If Not ValueIsFilled(SignatureData) Then
		ErrorDescription = NStr("en='Empty cignature is formed.';ru='Сформирована пустая подпись.'");
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Only for internal use.
Function EmptyEncryptedData(EncryptedData, ErrorDescription) Export
	
	If Not ValueIsFilled(EncryptedData) Then
		ErrorDescription = NStr("en='Empty data is formed.';ru='Сформированы пустые данные.'");
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Only for internal use.
Function EmptyDecryptedData(DecryptedData, ErrorDescription) Export
	
	If Not ValueIsFilled(DecryptedData) Then
		ErrorDescription = NStr("en='Empty data is formed.';ru='Сформированы пустые данные.'");
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// For the ReceiveMatchFilesAndSignatures function.
Function FindSignatureFileNames(DataFileName, SignatureFileNames)
	
	SignatureNames = New Array;
	
	NameStructure = CommonUseClientServer.SplitFullFileName(DataFileName);
	BaseName = NameStructure.BaseName;
	
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

#EndRegion
