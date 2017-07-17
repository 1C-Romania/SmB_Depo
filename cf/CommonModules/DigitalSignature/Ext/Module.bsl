////////////////////////////////////////////////////////////////////////////////
// Digital signature subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// Returns the current setting of using digital signatures.
Function UseDigitalSignatures() Export
	
	Return DigitalSignatureClientServer.CommonSettings().UseDigitalSignatures;
	
EndFunction

// Returns the current setting of encryption use.
Function UseEncryption() Export
	
	Return DigitalSignatureClientServer.CommonSettings().UseEncryption;
	
EndFunction

// Returns the current setting of checking digital signatures on server.
Function VerifyDigitalSignaturesAtServer() Export
	
	Return DigitalSignatureClientServer.CommonSettings().VerifyDigitalSignaturesAtServer;
	
EndFunction

// Returns the current setting of creating digital signatures on server.
// Setting also includes encryption and decryption on server.
//
Function CreateDigitalSignaturesAtServer() Export
	
	Return DigitalSignatureClientServer.CommonSettings().CreateDigitalSignaturesAtServer;
	
EndFunction


// Returns cryptography manager (on server) for a specified application.
//
// Parameters:
//  Operation       - String - if it is not empty, it should contain one of
//                   the rows that define the operation to insert into
//                   the description of error: SignatureCheck, Encryption, Decryption, CertificateCheck, ReceiveCertificates.
//
//  ShowError - Boolean - if True, then an exception will be invoked containing an error description.
//
//  ErrorDescription - String - return error description when a function returned the Undefined value.
//
//  Application      - Undefined - returns the cryptography
//                   manager of the first application from the catalog created for it.
//                 - CatalogRef.DigitalSignatureAndEncryptionApplications - application
//                   for which you need to create and return the cryptography manager.
//
// Returns:
//   CryptoManager - cryptography manager .
//   Undefined - an error occurred, description of which is located in the ErrorDescription parameter.
//
Function CryptoManager(Operation, ShowError = True, ErrorDescription = "", Application = Undefined) Export
	
	Error = "";
	Result = DigitalSignatureService.CryptoManager(Operation, ShowError, Error, Application);
	
	If Result = Undefined Then
		ErrorDescription = Error;
	EndIf;
	
	Return Result;
	
EndFunction

// Checks if a signature and a certificate are valid.
// 
// Parameters:
//   CryptoManager - Undefined - get cryptography manager
//                          to check digital signatures as the administrator set.
//                        - CryptoManager - use specified cryptography manager
// 
//   SourceData       - BinaryData - binary data that was signed.
//                        - String         - address of a temporary storage containing binary data.
//                        - String         - full name of the
//                                           file containing signed binary data
// 
//   Signature              - BinaryData - binary data of digital signature.
//                        - String         - address of a temporary storage containing binary data.
//                        - String         - full name of the file
//                                           containing binary data of the digital signature.
// 
//   ErrorDescription       - Null - cause exception on check error.
//                        - String - contains an error description if an error occurred.
// 
// Returns:
//  Boolean - True if check was completed successfully.
//         - False   if you were unable to receive cryptography manager
//                   (when not specified) or an error specified in the ErrorDescription parameter occurred.
//
Function VerifySignature(CryptoManager, SourceData, Signature, ErrorDescription = Null) Export
	
	CryptographyManagerForCheck = CryptoManager;
	If CryptographyManagerForCheck = Undefined Then
		CryptographyManagerForCheck = CryptoManager("SignatureCheck", ErrorDescription = Null, ErrorDescription);
		If CryptographyManagerForCheck = Undefined Then
			Return False;
		EndIf;
	EndIf;
	
	SourceDataForChecking = SourceData;
	If TypeOf(SourceData) = Type("String") AND IsTempStorageURL(SourceData) Then
		SourceDataForChecking = GetFromTempStorage(SourceData);
	EndIf;
	
	SignatureForCheck = Signature;
	If TypeOf(Signature) = Type("String") AND IsTempStorageURL(Signature) Then
		SignatureForCheck = GetFromTempStorage(Signature);
	EndIf;
	
	Certificate = Undefined;
	Try
		CryptographyManagerForCheck.VerifySignature(SourceDataForChecking, SignatureForCheck, Certificate);
	Except
		If ErrorDescription = Null Then
			Raise;
		EndIf;
		ErrorDescription = BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	If Not CheckCertificate(CryptographyManagerForCheck, Certificate, ErrorDescription) Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Checks the validity of a cryptography certificate.
//
// Parameters:
//   CryptoManager - Undefined - get the cryptography manager automatically.
//                        - CryptoManager - use specified cryptography manager
//
//   Certificate           - CryptoCertificate - certificate.
//                        - BinaryData - certificate binary data.
//                        - String - address of a temporary storage containing certificate binary data.
//
//   ErrorDescription       - Null - cause exception on check error.
//                        - String - contains an error description if an error occurred.
//
// Returns:
//  Boolean - True if check was completed successfully,
//         - False if you were unable to receive a cryptography manager (when not specified).
//
Function CheckCertificate(CryptoManager, Certificate, ErrorDescription = Null) Export
	
	CryptographyManagerForCheck = CryptoManager;
	
	If CryptographyManagerForCheck = Undefined Then
		CryptographyManagerForCheck = CryptoManager("CertificateCheck", ErrorDescription = Null, ErrorDescription);
		If CryptographyManagerForCheck = Undefined Then
			Return False;
		EndIf;
	EndIf;
	
	CertificateForCheck = Certificate;
	
	If TypeOf(Certificate) = Type("String") Then
		CertificateForCheck = GetFromTempStorage(Certificate);
	EndIf;
	
	If TypeOf(CertificateForCheck) = Type("BinaryData") Then
		CertificateForCheck = New CryptoCertificate(CertificateForCheck);
	EndIf;
	
	CertificateCheckModes = DigitalSignatureServiceClientServer.CertificateCheckModes();
	
	Try
		CryptographyManagerForCheck.CheckCertificate(CertificateForCheck, CertificateCheckModes);
	Except
		ErrorDescription = BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

// Finds a certificate on the computer by the thumbprint row.
//
// Parameters:
//   Imprint              - String - Base64 encoded thumbprint of certificate.
//   InPersonalStorageOnly - Boolean - if True, then search the personal storage, otherwise, everywhere.
//
// Returns:
//   CryptoCertificate - certificate of digital signature and encryption.
//   Undefined - certificate is not found in the storage.
//
Function GetCertificateByImprint(Imprint, InPersonalStorageOnly) Export
	
	Return DigitalSignatureService.GetCertificateByImprint(Imprint, InPersonalStorageOnly);
	
EndFunction

// Adds a signature to an object tabular section and writes it.
// Sets the True value for the DSDigitallySigned attribute.
// 
// Parameters:
//  Object - Refs - by reference the object will be received, locked, changed, written.
//                    Object should have the DigitalSignatures tabular section and the DigitallySignedDS attribute.
//         - Object - object will be changed without lock and without writing.
//
//  SignatureProperties - Array - array of structures described below and structures addresses.
//                  - String - address of a temporary storage containing a structure described below.
//                  - Structure - expanded signature description:
//     * Signature             - BinaryData - signing result.
//     * SetSignature - CatalogRef.Users - a
//                                user who signed an object of the infobase.
//     * Comment         - String - comment if it was put during signing.
//     * SignatureFileName     - String - if signature is added from file.
//     * SignatureDate         - Date   - date when the signature was made. This only makes
//                                      sense in case when date can not be extracted from signature data. If
//                                      it is not specified or empty, then the current session date is used.
//     Derived properties:
//     * Certificate          - BinaryData - contains
//                                export of the certificate that was used for signing (contained in a signature).
//     * Thumbprint           - String - certificate thumbprint in the Base64 row format.
//     * CertificateIsIssuedTo - String - subject presentation received from the certificate binary data.
//
//  FormID - UUID - form identifier used
//                       for locking if the ref to object was sent.
//
//  ObjectVersioning      - String - version of object data if the reference to object was passed. Used
//                       to lock object before write, taking into account that signing
//                       is executed on client and during signing an object could be changed.
//
//  WrittenObject   - Object - object that was received and recorded if a reference was transferred.
//
Procedure AddSignature(Object, Val SignatureProperties, FormID = Undefined,
			ObjectVersioning = Undefined, WrittenObject = Undefined) Export
	
	If TypeOf(SignatureProperties) = Type("String") Then
		SignatureProperties = GetFromTempStorage(SignatureProperties);
		
	ElsIf TypeOf(SignatureProperties) = Type("Array") Then
		LastIndex = SignatureProperties.Count()-1;
		For IndexOf = 0 To LastIndex Do
			If TypeOf(SignatureProperties[IndexOf]) = Type("String") Then
				SignatureProperties[IndexOf] = GetFromTempStorage(SignatureProperties[IndexOf]);
			EndIf;
		EndDo;
	EndIf;
	
	BeginTransaction();
	Try
		If CommonUse.IsReference(TypeOf(Object)) Then
			LockDataForEdit(Object, ObjectVersioning, FormID);
			ObjectData = Object.GetObject();
		Else
			ObjectData = Object;
		EndIf;
		
		If TypeOf(SignatureProperties) = Type("Array") Then
			For Each CurrentProperties IN SignatureProperties Do
				AddSignatureRow(ObjectData, CurrentProperties);
			EndDo;
		Else
			AddSignatureRow(ObjectData, SignatureProperties);
		EndIf;
		
		ObjectData.DigitallySigned = True;
		
		If CommonUse.IsReference(TypeOf(Object)) Then
			// To define that this record is to add/remove signature.
			ObjectData.AdditionalProperties.Insert("DigitallySignedObjectRecord", True);
			ObjectData.Write();
			UnlockDataForEdit(Object.Ref, FormID);
			WrittenObject = ObjectData;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Puts the encryption certificates in the object tabular section and writes it.
// Sets the Encrypted attribute according to rows in the tabular section.
// 
// Parameters:
//  Object - Refs - by reference the object will be received, locked, changed, written.
//                    Object should have the  EncryptionCertificates tabular section and the Encrypted attribute.
//         - Object - object will be changed without lock and without writing.
//
//  EncryptionCertificates - String - address of a temporary storage containing the array described below.
//                        - Array - array of the structures described below:
//                             * Thumbprint     - String - certificate thumbprint in the Base64 row format.
//                             * Presentation String - saved subject
//                                                  presentation received from the certificate binary data.
//                             * Certificate    - BinaryData - contains
//                                                  export of a certificate used for encryption
//
//  FormID - UUID - form identifier used
//                       for locking if the ref to object was sent.
//
//  ObjectVersioning      - String - version of object data if the reference to object was passed. Used
//                       to lock object before write, taking into account that signing
//                       is executed on client and during signing an object could be changed.
//
//  WrittenObject   - Object - object that was received and recorded if a reference was transferred.
//
Procedure WriteEncryptionCertificates(Object, Val EncryptionCertificates, FormID = Undefined,
			ObjectVersioning = Undefined, WrittenObject = Undefined) Export
	
	If TypeOf(EncryptionCertificates) = Type("String") Then
		EncryptionCertificates = GetFromTempStorage(EncryptionCertificates);
	EndIf;
	
	BeginTransaction();
	Try
		If CommonUse.IsReference(TypeOf(Object)) Then
			LockDataForEdit(Object, ObjectVersioning, FormID);
			ObjectData = Object.GetObject();
		Else
			ObjectData = Object;
		EndIf;
		
		ObjectData.EncryptionCertificates.Clear();
		
		For Each EncryptionCertificate IN EncryptionCertificates Do
			FillPropertyValues(ObjectData.EncryptionCertificates.Add(), EncryptionCertificate);
		EndDo;
		
		ObjectData.Encrypted = ObjectData.EncryptionCertificates.Count() > 0;
		
		If CommonUse.IsReference(TypeOf(Object)) Then
			// To define that the record is for decryption/encryption.
			ObjectData.AdditionalProperties.Insert("RecordOnDecryptingEncryptingObject", True);
			ObjectData.Write();
			UnlockDataForEdit(Object.Ref, FormID);
			WrittenObject = ObjectData;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Removes a signature from tabular section and writes it.
// 
// Parameters:
//  Object - Refs - by reference the object will be received, locked, changed, written.
//                    Object should have the DigitalSignatures tabular section and the DigitallySignedDS attribute.
//         - Object - object will be changed without lock and without writing.
// 
//  SignatureIdentifier - Number - index of the tablular section row.
//                       - Array - values of the type specified above.
//
//  FormID - UUID - form identifier used
//                       for locking if the ref to object was sent.
//
//  ObjectVersioning      - String - version of object data if the reference to object was passed. Used
//                       to lock object before write, taking into account that signing
//                       is executed on client and during signing an object could be changed.
//
//  WrittenObject   - Object - object that was received and recorded if a reference was transferred.
//
Procedure DeleteSignature(Object, SignatureIdentifier, FormID = Undefined,
			ObjectVersioning = Undefined, WrittenObject = Undefined) Export
	
	BeginTransaction();
	Try
		If CommonUse.IsReference(TypeOf(Object)) Then
			LockDataForEdit(Object, ObjectVersioning, FormID);
			ObjectData = Object.GetObject();
		Else
			ObjectData = Object;
		EndIf;
		
		If TypeOf(SignatureIdentifier) = Type("Array") Then
			List = New ValueList;
			List.LoadValues(SignatureIdentifier);
			List.SortByValue(SortDirection.Desc);
			For Each ItemOfList IN List Do
				DeleteSignatureRow(ObjectData, ItemOfList.Value);
			EndDo;
		Else
			DeleteSignatureRow(ObjectData, SignatureIdentifier);
		EndIf;
		
		ObjectData.DigitallySigned = ObjectData.DigitalSignatures.Count() <> 0;
		
		If CommonUse.IsReference(TypeOf(Object)) Then
			// To define that this record is to add/remove signature.
			ObjectData.AdditionalProperties.Insert("DigitallySignedObjectRecord", True);
			ObjectData.Write();
			UnlockDataForEdit(Object.Ref, FormID);
			WrittenObject = ObjectData;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Returns the date extracted from signature binary data or Undefined.
//
// Parameters:
//  Signature - BinaryData - signature data, from which date should be removed.
//  LeadToSessionTimeZone - Boolean - convert universal time to session time
//
// Returns:
//  Date - signing date is successfully extracted.
//  Undefined - unable to extract date from signature data.
//
Function SigningDate(Signature, LeadToSessionTimeZone = True) Export
	
	SigningDate = Undefined;
	
	TempFileName = GetTempFileName();
	Signature.Write(TempFileName);
	
	TextReader = New TextReader(TempFileName);
	Char = TextReader.Read(1);
	
	While Char <> Undefined Do
		If CharCode(Char) = 15 Then
			Char = TextReader.Read(2);
			If CharCode(Char, 1) = 23 AND CharCode(Char, 2) = 13 Then
				DateString = TextReader.Read(12);
				SigningDate = Date("20" + DateString);
				If LeadToSessionTimeZone Then
					SigningDate = ToLocalTime(SigningDate, SessionTimeZone());
				EndIf;
				Break;
			EndIf;
		EndIf;
		Char = TextReader.Read(1);
	EndDo;
	
	TextReader.Close();
	DeleteFiles(TempFileName);
	
	Return SigningDate;
	
EndFunction

// Outdated. You should use the DeleteSignature procedure.
Procedure DeleteSignatures(ObjectRef, TableSelectedRows, AttributeDigitallySignedChanged,
		NumberOfSignatures, UUID = Undefined) Export
	
	AttributeDigitallySignedChanged = False;
	
	// Sort row numbers by descending - in the beginning will be last rows.
	TableSelectedRows.Sort("LineNumber Desc");
	
	DigitallySignedObject = ObjectRef.GetObject();
	LockDataForEdit(ObjectRef, , UUID);
	
	For Each SignatureData IN TableSelectedRows Do
		DeleteSignature2(DigitallySignedObject, SignatureData);
	EndDo;
	
	NumberOfSignatures = DigitallySignedObject.DigitalSignatures.Count();
	DigitallySignedObject.DigitallySigned = (NumberOfSignatures <> 0);
	AttributeDigitallySignedChanged = Not DigitallySignedObject.DigitallySigned;
	
	// To record a previously signed object.
	DigitallySignedObject.AdditionalProperties.Insert("DigitallySignedObjectRecord", True);
	SetPrivilegedMode(True);
	DigitallySignedObject.Write();
	UnlockDataForEdit(ObjectRef, UUID);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns the common settings of all users to work with a digital signature.
//
// Returns: 
//   Structure - General settings of a subsystem to work with a digital signature.
//     * UseDigitalSignatures       - Boolean - if True, then digital signatures are used.
//     * UseEncryption               - Boolean - if True, then encryption is used.
//     * ExecuteEncryptionOnServer         - Boolean - If True, then encryption is being executed on server.
//     * CheckDigitalSignaturesOnServer - Boolean - If True, then digital signatures
//                                                       and certificates are checked on server.
//     * CreateDigitalSignaturesOnServer - Boolean - if True, then digital signatures
//                                                       are created first on server and if it fails - on client.
//
// See also:
//   DigitalSignatureClientServer.CommonSettings() - unified enter point.
//   CommonForm.DigitalSignaturesAndEncryptionSettings - place where parameters data
//   and their text descriptions are defined.
//
Function CommonSettings() Export
	
	Return DigitalSignatureServiceReUse.CommonSettings();
	
EndFunction

// Returns settings of a current user to work with a digital signature.
//
// Returns:
//   Structure - Personal settings to work with a digital signature.
//       * ActionsOnSaveWithDS - String - What to do when files with digital signature are being saved:
//           ** Ask - Show a dialog of signatues selection for saving.
//           ** SaveAllSignatures - Always all signatures.
//       * PathToDigitalSignatureAndEncryptionApplications - Map - where:
//           ** Key     - CatalogRef.DigitalSignatureAndEncryptionApplications - application.
//           ** Value - String - path to application on user's computer.
//       * ExtensionForSignatureFiles - String - Extension for DS files.
//       * ExtensionForDecryptedFiles - String - Extension for decrypted files.
//
// See also:
//   DigitalSignatureClientServer.PersonalSettings() - applicationmatic interface for getting.
//   CommonForm.DSPersonalSettings - place of the current parameters input and their custom presentations.
//
Function PersonalSettings() Export
	
	PersonalSettings = New Structure;
	// Initials values.
	PersonalSettings.Insert("ActionsOnSavingDS", "Ask");
	PersonalSettings.Insert("PathToDigitalSignatureAndEncryptionApplications", New Map);
	PersonalSettings.Insert("ExtensionForSignatureFiles", "p7s");
	PersonalSettings.Insert("ExtensionForEncryptedFiles", "p7m");
	
	SubsystemKey = DigitalSignatureService.SettingsStorageKey();
	
	For Each KeyAndValue IN PersonalSettings Do
		SavedValue = CommonUse.CommonSettingsStorageImport(SubsystemKey,
			KeyAndValue.Key);
		
		If ValueIsFilled(SavedValue)
		   AND TypeOf(KeyAndValue.Value) = TypeOf(SavedValue) Then
			
			PersonalSettings.Insert(KeyAndValue.Key, SavedValue);
		EndIf;
	EndDo;
	
	Return PersonalSettings;
	
EndFunction

// Extracts certificates from the signature data.
//
// Parameters:
//   Signature - BinaryData - Signature file.
//
// Returns:
//   Undefined - If an error occurred during parsing.
//   Structure - Signature data.
//       * Thumbprint                 - String.
//       * CertificateIsIssuedTo       - String.
//       * CertificateBinaryData - BinaryData.
//       * Signature                   - ValueStorage.
//       * Certificate                - ValueStorage.
//
Function ReadSignatureData(Signature) Export
	
	Result = Undefined;
	
	CryptoManager = CryptoManager("GetCertificates");
	If CryptoManager = Undefined Then
		Return Result;
	EndIf;
	
	Try
		Certificates = CryptoManager.GetCertificatesFromSignature(Signature);
	Except
		Return Result;
	EndTry;
	
	If Certificates.Count() > 0 Then
		Certificate = Certificates[0];
		
		Result = New Structure;
		Result.Insert("Imprint", Base64String(Certificate.Imprint));
		Result.Insert("CertificateIsIssuedTo", DigitalSignatureClientServer.SubjectPresentation(Certificate));
		Result.Insert("CertificateBinaryData", Certificate.Unload());
		Result.Insert("Signature", New ValueStorage(Signature));
		Result.Insert("Certificate", New ValueStorage(Certificate.Unload()));
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// For the AddSignatue procedure.
Procedure AddSignatureRow(ObjectData, SignatureProperties)
	
	NewRecord = ObjectData.DigitalSignatures.Add();
	FillPropertyValues(NewRecord, SignatureProperties,, "Signature, Certificate");
	
	NewRecord.Signature    = New ValueStorage(SignatureProperties.Signature);
	NewRecord.Certificate = New ValueStorage(SignatureProperties.Certificate);
	
	If Not ValueIsFilled(NewRecord.Signer) Then
	 	NewRecord.Signer = Users.AuthorizedUser();
	EndIf;
	
	SignatureDate = SigningDate(SignatureProperties.Signature);
	
	If SignatureDate <> Undefined Then
		NewRecord.SignatureDate = SignatureDate;
	
	ElsIf Not ValueIsFilled(NewRecord.SignatureDate) Then
		NewRecord.SignatureDate = CurrentSessionDate();
	EndIf;
	
EndProcedure

// For the DeleteSignature procedure.
Procedure DeleteSignatureRow(DigitallySignedObject, RowIndex)
	
	If DigitallySignedObject.DigitalSignatures.Count() < RowIndex + 1 Then
		Raise NStr("en='String with signature was not found.';ru='Строка с подписью не найдена.'");
	EndIf;
	
	TabularSectionRow = DigitallySignedObject.DigitalSignatures.Get(RowIndex);
		
	If Not Users.InfobaseUserWithFullAccess() Then 
		If TabularSectionRow.Signer <> Users.CurrentUser() Then
			Raise NStr("en='Insufficient rights to delete the signature.';ru='Недостаточно прав на удаление подписи.'");
		EndIf;
	EndIf;
	
	DigitallySignedObject.DigitalSignatures.Delete(TabularSectionRow);
	
EndProcedure

// For the DeleteSignatures outdated procedure.
Procedure DeleteSignature2(DigitallySignedObject, SignatureData)
	
	LineNumber = SignatureData.LineNumber;
	
	TabularSectionRow = DigitallySignedObject.DigitalSignatures.Find(LineNumber, "LineNumber");
	If TabularSectionRow <> Undefined Then
		
		If Not Users.InfobaseUserWithFullAccess() Then 
			If TabularSectionRow.Signer <> Users.CurrentUser() Then
				Raise NStr("en='Insufficient rights to delete the signature.';ru='Недостаточно прав на удаление подписи.'");
			EndIf;
		EndIf;
		
		DigitallySignedObject.DigitalSignatures.Delete(TabularSectionRow);
	Else	
		Raise NStr("en='String with signature was not found.';ru='Строка с подписью не найдена.'");
	EndIf;
		
EndProcedure

#EndRegion
