////////////////////////////////////////////////////////////////////////////////
// Digital signature subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Opens a form of data certificate view.
//
// Parameters:
//  CertificateData - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - reference to certificate.
//                    - CryptoCertificate - available certificate.
//                    - BinaryData - certificate binary data.
//                    - String - address of a temporary storage containing certificate BinaryData.
//                    - String - certificate thumbprint to search in all storages.
//
//  OpenData     - Boolean - open certificate data not catalog item form.
//                      If a reference to the catalog item is sent, and the catalog item is not found by a thumbprint, then the certificate data will be opened. 
 
Procedure OpenCertificate(CertificateData, OpenData = False) Export
	
	Context = New Structure;
	Context.Insert("CertificateData", CertificateData);
	Context.Insert("OpenData", OpenData);
	Context.Insert("CertificateAddress", Undefined);
	
	If TypeOf(CertificateData) = Type("CryptoCertificate") Then
		Context.CryptoCertificate.BeginUnloading(New NotifyDescription(
			"OpenCertificateAfterCertificateExport", ThisObject, Context));
	Else
		OpenCertificateContinuation(Context);
	EndIf;
	
EndProcedure

// Continue the OpenCertificate procedure.
Procedure OpenCertificateAfterCertificateExport(ExportedData, Context) Export
	
	Context.CertificateAddress = PutToTempStorage(ExportedData);
	
	OpenCertificateContinuation(Context);
	
EndProcedure

// Continue the OpenCertificate procedure.
Procedure OpenCertificateContinuation(Context)
	
	If Context.CertificateAddress <> Undefined Then
		// Certificate prepared.
		
	ElsIf TypeOf(Context.CertificateData) = Type("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates") Then
		Refs = Context.CertificateData;
		
	ElsIf TypeOf(Context.CertificateData) = Type("BinaryData") Then
		Context.CertificateAddress = PutToTempStorage(Context.CertificateData);
		
	ElsIf TypeOf(Context.CertificateData) <> Type("String") Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='An error occurred calling the OpenCertificate procedure
		|of the DigitalSignatureClient general module: Incorrect value of the  %1 CertificateData parameter.';ru='Ошибка при вызове процедуры ОткрытьСертификат общего модуля ЭлектроннаяПодписьКлиент: Некорректное значение параметра ДанныеСертификата ""%1"".'"), String(Context.CertificateData));
	
	ElsIf IsTempStorageURL(Context.CertificateData) Then
		Context.CertificateAddress = Context.CertificateData;
	Else
		Imprint = Context.CertificateData;
	EndIf;
	
	If Not Context.OpenData Then
		If Refs = Undefined Then
			Refs = DigitalSignatureServiceServerCall.ReferenceToCertificate(Imprint, Context.CertificateAddress);
		EndIf;
		If ValueIsFilled(Refs) Then
			ShowValue(, Refs);
			Return;
		EndIf;
	EndIf;
	
	Context.Insert("Ref", Refs);
	Context.Insert("Imprint", Imprint);
	
	If Context.CertificateAddress = Undefined
	   AND Refs = Undefined Then
		
		GetCertificateByImprint(New NotifyDescription(
			"OpenCertificateAfterCertificateSearch", ThisObject, Context), Imprint, False);
	Else
		OpenCertificateEnd(Context);
	EndIf;
	
EndProcedure

// Continue the OpenCertificate procedure.
Procedure OpenCertificateAfterCertificateSearch(Result, Context) Export
	
	If TypeOf(Result) = Type("CryptoCertificate") Then
		Result.BeginUnloading(New NotifyDescription(
			"OpenCertificateAfterExportFoundCertificate", ThisObject, Context));
	Else
		OpenCertificateEnd(Context);
	EndIf;
	
EndProcedure

// Continue the OpenCertificate procedure.
Procedure OpenCertificateAfterExportFoundCertificate(ExportedData, Context) Export
	
	Context.CertificateAddress = PutToTempStorage(ExportedData);
	
	OpenCertificateEnd(Context);
	
EndProcedure

// Continue the OpenCertificate procedure.
Procedure OpenCertificateEnd(Context)
	
	FormParameters = New Structure;
	FormParameters.Insert("Ref",           Context.Ref);
	FormParameters.Insert("CertificateAddress", Context.CertificateAddress);
	FormParameters.Insert("Imprint",        Context.Imprint);
	
	OpenForm("CommonForm.Certificate", FormParameters);
	
EndProcedure


// Saves the certificate in the file on disk.
// 
// Parameters:
//   Notification - NotifyDescription - called after saving.
//              - Undefined - no need to continue.
//
//   Certificate - CryptoCertificate - certificate.
//              - BinaryData - certificate binary data.
//              - String - address of a temporary storage containing certificate binary data.
//
Procedure SaveCertificate(Notification, Certificate, FileDescriptionWithoutExtension = "") Export
	
	Context =  New Structure;
	Context.Insert("Notification",            Notification);
	Context.Insert("Certificate",            Certificate);
	Context.Insert("FileDescriptionWithoutExtension", FileDescriptionWithoutExtension);
	Context.Insert("CertificateAddress",      Undefined);
	
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(
		New NotifyDescription("SaveCertificateAfterExpansionSetting", ThisObject, Context));
	
EndProcedure

// Continue the SaveCertificate procedure.
Procedure SaveCertificateAfterExpansionSetting(ExtensionAttached, Context) Export
	
	Context.Insert("ExtensionAttached", ExtensionAttached);
	
	If TypeOf(Context.Certificate) = Type("CryptoCertificate") Then
		Context.Certificate.BeginUnloading(New NotifyDescription(
			"SaveCertificateAfterExportCertificate", ThisObject, Context));
	Else
		SaveCertificateContinuation(Context);
	EndIf;
	
EndProcedure

// Continue the SaveCertificate procedure.
Procedure SaveCertificateAfterExportCertificate(ExportedData, Context) Export
	
	Context.CertificateAddress = PutToTempStorage(ExportedData);
	
	SaveCertificateContinuation(Context);
	
EndProcedure

// Continue the SaveCertificate procedure.
Procedure SaveCertificateContinuation(Context)
	
	If Context.CertificateAddress <> Undefined Then
		// Certificate prepared.
		
	ElsIf TypeOf(Context.Certificate) = Type("BinaryData") Then
		Context.CertificateAddress = PutToTempStorage(Context.Certificate);
		
	ElsIf TypeOf(Context.Certificate) = Type("String")
	        AND IsTempStorageURL(Context.Certificate) Then
		
		Context.CertificateAddress = Context.Certificate;
	Else
		If Context.Notification <> Undefined Then
			ExecuteNotifyProcessing(Context.Notification, False);
		EndIf;
		Return;
	EndIf;
	
	If Not ValueIsFilled(Context.FileDescriptionWithoutExtension) Then
		Context.FileDescriptionWithoutExtension = DigitalSignatureServiceServerCall.CertificatePresentation(
			Context.CertificateAddress);
	EndIf;
	
	FileName = PrepareRowForFileName(Context.FileDescriptionWithoutExtension) + ".cer";
	
	If Not Context.ExtensionAttached Then
		GetFile(Context.CertificateAddress, FileName);
		If Context.Notification <> Undefined Then
			ExecuteNotifyProcessing(Context.Notification);
		EndIf;
		Return;
	EndIf;
	
	Dialog = New FileDialog(FileDialogMode.Save);
	Dialog.Title = NStr("en='Select a file to save the certificate to';ru='Выберите файл для сохранения сертификата'");
	Dialog.Filter    = NStr("en='Certificate files (*.cer)|*.cer|All files (*.*)|*.*';ru='Файлы сертификатов (*.cer)|*.cer|Все файлы (*.*)|*.*'");
	Dialog.Multiselect = False;
	
	FilesToReceive = New Array;
	FilesToReceive.Add(New TransferableFileDescription(FileName, Context.CertificateAddress));
	
	BeginGettingFiles(New NotifyDescription(
		"SaveCertificateAfterReceivingFiles", ThisObject, Context), FilesToReceive, Dialog);
	
EndProcedure

// Continue the SaveCertificate procedure.
Procedure SaveCertificateAfterReceivingFiles(ReceivedFiles, Context) Export
	
	If ReceivedFiles = Undefined
	 Or ReceivedFiles.Count() = 0 Then
		
		HasReceivedFiles = False;
	Else
		HasReceivedFiles = True;
		ShowUserNotification(NStr("en='Certificate is saved to file:';ru='Сертификат сохранен в файл:'"),,
			ReceivedFiles[0].Name);
	EndIf;
	
	If Context.Notification <> Undefined Then
		ExecuteNotifyProcessing(Context.Notification, HasReceivedFiles);
	EndIf;
	
EndProcedure


// Saves the certificate query to the file on disk.
// 
// Parameters:
//   Notification - NotifyDescription - called after saving.
//              - Undefined - no need to continue.
//
//   CertificateQuery    - BinaryData - query for certificate data.
//                         - String - address of a temporary storage containing certificate query data.
//   FileDescriptionWithoutExtension - String - initial attachment file name without extension.
//
Procedure SaveCertificateQuery(Notification, CertificateQuery, FileDescriptionWithoutExtension = "") Export
	
	Context =  New Structure;
	Context.Insert("Notification",            Notification);
	Context.Insert("CertificateQuery",    CertificateQuery);
	Context.Insert("FileDescriptionWithoutExtension", FileDescriptionWithoutExtension);
	
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(
		New NotifyDescription("SaveCertificateQueryAfterSettingExpansion", ThisObject, Context));
	
EndProcedure

// Continue the SaveQueryToCertificate procedure.
Procedure SaveCertificateQueryAfterSettingExpansion(ExtensionAttached, Context) Export
	
	CertificateQuery    = Context.CertificateQuery;
	FileDescriptionWithoutExtension = Context.FileDescriptionWithoutExtension;
	
	If TypeOf(CertificateQuery) = Type("BinaryData") Then
		RequestAddressForCertificate = PutToTempStorage(CertificateQuery);
		
	ElsIf TypeOf(CertificateQuery) = Type("String")
	        AND IsTempStorageURL(CertificateQuery) Then
		
		RequestAddressForCertificate = CertificateQuery;
	Else
		If Context.Notification <> Undefined Then
			ExecuteNotifyProcessing(Context.Notification, False);
		EndIf;
		Return;
	EndIf;
	
	FileName = PrepareRowForFileName(FileDescriptionWithoutExtension + ".p10");
	
	If Not ExtensionAttached Then
		GetFile(RequestAddressForCertificate, FileName);
		If Context.Notification <> Undefined Then
			ExecuteNotifyProcessing(Context.Notification);
		EndIf;
		Return;
	EndIf;
	
	Dialog = New FileDialog(FileDialogMode.Save);
	Dialog.Title = NStr("en='Select a file to save the certificate request to';ru='Выберите файл для сохранения запроса на сертификат'");
	Dialog.Filter    = NStr("en='Certificate files (*.p10)|*.p10|All files (*.*)|*.*';ru='Файлы сертификатов (*.p10)|*.p10|Все файлы (*.*)|*.*'");
	Dialog.Multiselect = False;
	
	FilesToReceive = New Array;
	FilesToReceive.Add(New TransferableFileDescription(FileName, RequestAddressForCertificate));
	
	BeginGettingFiles(New NotifyDescription(
		"SaveCertificateQueryAfterReceivingFiles", ThisObject, Context), FilesToReceive, Dialog);
	
EndProcedure

// Continue the SaveQueryToCertificate procedure.
Procedure SaveCertificateQueryAfterReceivingFiles(ReceivedFiles, Context) Export
	
	If ReceivedFiles = Undefined
	 Or ReceivedFiles.Count() = 0 Then
		
		HasReceivedFiles = False;
	Else
		HasReceivedFiles = True;
		ShowUserNotification(NStr("en='Certificate request is saved to file:';ru='Запрос на сертификат сохранен в файл:'"),,
			ReceivedFiles[0].Name);
	EndIf;
	
	If Context.Notification <> Undefined Then
		ExecuteNotifyProcessing(Context.Notification, HasReceivedFiles);
	EndIf;
	
EndProcedure


// Saves signature to disk
Procedure SaveSignature(SignatureAddress) Export
	
	Context = New Structure;
	Context.Insert("SignatureAddress", SignatureAddress);
	
	BeginAttachingFileSystemExtension(New NotifyDescription(
		"SaveSignatureAfterConnectingFileOperationsExtension", ThisObject, Context));
	
EndProcedure

// Continue the SaveSignature procedure.
Procedure SaveSignatureAfterConnectingFileOperationsExtension(Attached, Context) Export
	
	If Not Attached Then
		GetFile(Context.SignatureAddress);
		Return;
	EndIf;
	
	ExtensionForSignatureFiles = DigitalSignatureClientServer.PersonalSettings().ExtensionForSignatureFiles;
	
	FileOpeningDialog = New FileDialog(FileDialogMode.Save);
	
	Filter = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Digital signature files (*.%1)|*.%1|All files (*.*)|*.*';ru='Файлы электронных подписей (*.%1)|*.%1|Все файлы (*.*)|*.*'"),
		ExtensionForSignatureFiles);
	
	FileOpeningDialog.Filter = Filter;
	FileOpeningDialog.Multiselect = False;
	FileOpeningDialog.Title = NStr("en='Select a file to save the signature to';ru='Выберите файл для сохранения подписи'");
	
	FilesToTransfer = New Array;
	FilesToTransfer.Add(New TransferableFileDescription("", Context.SignatureAddress));
	
	// Save File from infobase to disk.
	BeginGettingFiles(New NotifyDescription(
		"SaveSignatureAfterGettingFile", ThisObject, Context), FilesToTransfer, FileOpeningDialog);
	
EndProcedure

// Continue the SaveSignature procedure.
Procedure SaveSignatureAfterGettingFile(ReceivedFiles, Context) Export
	
	If ReceivedFiles = Undefined
	 Or ReceivedFiles.Count() = 0 Then
		
		Return;
	EndIf;
	
	ShowUserNotification(NStr("en='Digital signature is saved to file:';ru='Электронная подпись сохранена в файл:'"),,
		ReceivedFiles[0].Name);
	
EndProcedure

// Finds a certificate on the computer by the thumbprint row.
//
// Parameters:
//   Notification - NotifyDescription - notification about a result of performing the following types:
//     CryptoCertificate - found certificate.
//     Undefined           - certificate is not found in the storage.
//     String                 - error text of creating cryptography manager (or another error).
//     Structure              - error description in the form of structure.
//
//   Imprint              - String - Base64 encoded thumbprint of certificate.
//   InPersonalStorageOnly - Boolean - if True, then search the personal storage, otherwise, everywhere.
//                          - CryptoCertificateStoreType - specified storage type.
//
//   ShowError - Boolean - show error of cryptography manager creation.
//                  - Undefined - do not show an error and
//                    return an error structure and also add the CertificateNotFound property.
//
//   Application  - Undefined - search using any application.
//              - CatalogRef.DigitalSignatureAndEncryptionApplications - search
//                   using a specified application.
//              - CryptoManager - initialize
//                   cryptographic manager that should be used for search.
//
Procedure GetCertificateByImprint(Notification, Imprint, InPersonalStorageOnly,
			ShowError = True, Application = Undefined) Export
	
	Context = New Structure;
	Context.Insert("Notification",             Notification);
	Context.Insert("Imprint",              Imprint);
	Context.Insert("InPersonalStorageOnly", InPersonalStorageOnly);
	Context.Insert("ShowError",         ShowError);
	
	If TypeOf(Application) = Type("CryptoManager") Then
		GetCertificateByThumbprintAfterCreatingCryptographyManager(Application, Context);
	Else
		CreateCryptoManager(New NotifyDescription(
			"GetCertificateByThumbprintAfterCreatingCryptographyManager", ThisObject, Context),
			"GetCertificates", ShowError, Application);
	EndIf;
	
EndProcedure

// Continue the GetCertificateByThumbprint procedure.
Procedure GetCertificateByThumbprintAfterCreatingCryptographyManager(Result, Context) Export
	
	If TypeOf(Result) <> Type("CryptoManager") Then
		ExecuteNotifyProcessing(Context.Notification, Result);
		Return;
	EndIf;
	Context.Insert("CryptoManager", Result);
	
	StorageType = DigitalSignatureServiceClientServer.StorageTypeToSearchCertificates(
		Context.InPersonalStorageOnly);
	
	Try
		Context.Insert("BinaryDataImprint", Base64Value(Context.Imprint));
	Except
		If Context.ShowError = True Then
			Raise;
		EndIf;
		ErrorInfo = ErrorInfo();
		ErrorPresentation = BriefErrorDescription(ErrorInfo);
		GetCertificateByThumbprintEnd(, ErrorPresentation, Context);
		Return;
	EndTry;
	
	Context.CryptoManager.StartGettingCertificatesStorage(
		New NotifyDescription(
			"GetCertificateByThumbprintAfterReceivingStorage", ThisObject, Context,
			"GetCertificateByThumbprintAfterGettingStorageError", ThisObject),
		StorageType);
	
EndProcedure

// Continue the GetCertificateByThumbprint procedure.
Procedure GetCertificateByThumbprintAfterGettingStorageError(ErrorInfo, StandardProcessing, Context) Export
	
	If Context.ShowError Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	ErrorPresentation = BriefErrorDescription(ErrorInfo);
	GetCertificateByThumbprintEnd(, ErrorPresentation, Context);
	
EndProcedure

// Continue the GetCertificateByThumbprint procedure.
Procedure GetCertificateByThumbprintAfterReceivingStorage(StorageOfCertificates, Context) Export
	
	StorageOfCertificates.StartSearchByThumbprint(New NotifyDescription(
			"GetCertificateByThumbprintAfterSearch", ThisObject, Context,
			"GetCertificateByThumbprintAfterSearchError", ThisObject),
		Context.BinaryDataImprint);
	
EndProcedure

// Continue the GetCertificateByThumbprint procedure.
Procedure GetCertificateByThumbprintAfterSearchError(ErrorInfo, StandardProcessing, Context) Export
	
	If Context.ShowError Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	ErrorPresentation = BriefErrorDescription(ErrorInfo);
	
	GetCertificateByThumbprintEnd(, ErrorPresentation, Context);
	
EndProcedure

// Continue the GetCertificateByThumbprint procedure.
Procedure GetCertificateByThumbprintAfterSearch(Certificate, Context) Export
	
	GetCertificateByThumbprintEnd(Certificate, , Context);
	
EndProcedure

// Continue the GetCertificateByThumbprint procedure.
Procedure GetCertificateByThumbprintEnd(Certificate, ErrorPresentation, Context)
	
	If TypeOf(Certificate) = Type("CryptoCertificate") Then
		ExecuteNotifyProcessing(Context.Notification, Certificate);
		Return;
	EndIf;
	
	If ValueIsFilled(ErrorPresentation) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Certificate is not found
		|on the computer as: %1';ru='Сертификат
		|не найден на компьютере по причине: %1'"),
			ErrorPresentation);
	Else
		ErrorText = NStr("en='Certificate is not found on the computer.';ru='Сертификат не найден на компьютере.'");
	EndIf;
	
	If Context.ShowError = Undefined Then
		Result = New Structure;
		Result.Insert("ErrorDescription", ErrorText);
		If Not ValueIsFilled(ErrorPresentation) Then
			Result.Insert("CertificateNotFound");
		EndIf;
	ElsIf Not ValueIsFilled(ErrorPresentation) Then
		Result = Undefined;
	Else
		Result = ErrorPresentation;
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure


// Gets the certificates thumbprints of OC user on the computer.
//
// Parameters:
//  Notification     - AlertDescription - called to transfer a return value:
//                   * Map - Key - thumbprint in the Base64 row format, and Value - True;
//                   * String - error text of creating cryptography manager (or another error).
//
//  PersonalOnly   - Boolean - If False, then the receivers certificates are added to the personal certificates.
//
//  ShowError - Boolean - show error of cryptography manager creation.
//
Procedure GetCertificatesThumbprints(Notification, PersonalOnly, ShowError = True) Export
	
	Context = New Structure;
	Context.Insert("Notification",     Notification);
	Context.Insert("PersonalOnly",   PersonalOnly);
	Context.Insert("ShowError", ShowError = True);
	
	GetCertificatesPropertiesOnClient(New NotifyDescription(
			"GetCertificateThumbprintsAfterExecuting", ThisObject, Context),
		PersonalOnly, False, True, ShowError);
	
EndProcedure

// Continue the GetCertificateThumbprints procedure.
Procedure GetCertificateThumbprintsAfterExecuting(Result, Context) Export
	
	If ValueIsFilled(Result.ErrorReceivingCertificatesOnClient) Then
		ExecuteNotifyProcessing(Context.Notification, Result.ErrorReceivingCertificatesOnClient);
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, Result.CertificatesPropertiesOnClient);
	
EndProcedure


// Checks if a signature and a certificate are valid.
// Certificate is always checked on
// server if the administrator set check of the digital signatures on server.
//
// Parameters:
//   Notification           - NotifyDescription - notification about a result of performing the following types:
//     Boolean       - True if check was completed successfully.
//     String       - description of the signature check error.
//     Undefined - unable to receive cryptography manager (when not specified).
//
//   SourceData       - BinaryData - binary data that was signed.
//                          Mathematical check is executed by a
//                          client even when the administrator set a
//                          check of digital signatures on server if the cryptography manager is specified and you failed to obtain it without error.
//                          It increases productivity and safety during a
//                          password check in the decrypted file (it will not be sent to a server).
//                        - String - address of a temporary storage containing source binary data.
//
//   Signature              - BinaryData - binary data of digital signature.
//                        - String         - address of a temporary storage containing binary data.
//
//   CryptoManager - Undefined - receive a default
//                          cryptography manager (manager of a first application on the list like the administrator has set it).
//                        - CryptoManager - use specified cryptography manager
//
Procedure VerifySignature(Notification, SourceData, Signature, CryptoManager = Undefined) Export
	
	Context = New Structure;
	Context.Insert("Notification",         Notification);
	Context.Insert("SourceData",     SourceData);
	Context.Insert("Signature",            Signature);
	Context.Insert("CheckOnServer",
		DigitalSignatureClientServer.CommonSettings().VerifyDigitalSignaturesAtServer);
	
	If CryptoManager = Undefined Then
		CreateCryptoManager(New NotifyDescription(
				"CheckSignatureAfterCreatingCryptographyManager", ThisObject, Context),
			"SignatureCheck", Not Context.CheckOnServer);
	Else
		CheckSignatureAfterCreatingCryptographyManager(CryptoManager, Context);
	EndIf;
	
EndProcedure

// Continue the CheckSignature procedure.
Procedure CheckSignatureAfterCreatingCryptographyManager(Result, Context) Export
	
	If TypeOf(Result) = Type("CryptoManager") Then
		CryptoManager = Result;
	Else
		CryptoManager = Undefined;
	EndIf;
	
	Context.Insert("CryptoManager", CryptoManager);
	
	If Not DigitalSignatureClientServer.CommonSettings().VerifyDigitalSignaturesAtServer Then
		// Check signature and certificate on client side.
		If CryptoManager = Undefined Then
			ExecuteNotifyProcessing(Context.Notification, Undefined);
			Return;
		EndIf;
		
		If TypeOf(Context.SourceData) = Type("String")
		   AND IsTempStorageURL(Context.SourceData) Then
			
			Context.SourceData = GetFromTempStorage(Context.SourceData);
		EndIf;
		
		Context.Insert("CheckCertificateOnClient");
		
		CheckSignatureOnClient(Context);
		Return;
	EndIf;
	
	If CryptoManager <> Undefined
	   AND Not (  TypeOf(Context.SourceData) = Type("String")
	         AND IsTempStorageURL(Context.SourceData)) Then
		// Mathematical check of the sign on the
		// client part to increase productivity and safety in case if ItitialData is a result of decryption of a secret file.
		
		// Certificate is checked on server and on client.
		CheckSignatureOnClient(Context);
		Return;
	EndIf;
	
	// Check signature and certificate on server.
	If TypeOf(Context.SourceData) = Type("String")
	   AND IsTempStorageURL(Context.SourceData) Then
		
		SourceDataAddress = Context.SourceData;
		
	ElsIf TypeOf(Context.SourceData) = Type("BinaryData") Then
		SourceDataAddress = PutToTempStorage(Context.SourceData);
	EndIf;
	
	If TypeOf(Context.Signature) = Type("String")
	   AND IsTempStorageURL(Context.Signature) Then
		
		SignatureAddress = Context.Signature;
		
	ElsIf TypeOf(Context.Signature) = Type("BinaryData") Then
		SignatureAddress = PutToTempStorage(Context.Signature);
	EndIf;
	
	ErrorDescription = "";
	Result = DigitalSignatureServiceServerCall.VerifySignature(
		SourceDataAddress, SignatureAddress, ErrorDescription);
	
	If Result <> True Then
		Result = ErrorDescription;
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

// Continue the CheckSignature procedure.
Procedure CheckSignatureOnClient(Context)
	
	Signature = Context.Signature;
	
	If TypeOf(Signature) = Type("String") AND IsTempStorageURL(Signature) Then
		Signature = GetFromTempStorage(Signature);
	EndIf;
	
	Context.CryptoManager.StartCheckingSignature(New NotifyDescription(
		"CheckSignatureOnClientAfterSignatureCheck", ThisObject, Context,
		"CheckSignatureOnClientAfterSignatureCheckError", ThisObject),
		Context.SourceData, Signature);
	
EndProcedure

// Continue the CheckSignature procedure.
Procedure CheckSignatureOnClientAfterSignatureCheckError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	ExecuteNotifyProcessing(Context.Notification, BriefErrorDescription(ErrorInfo));
	
EndProcedure

// Continue the CheckSignature procedure.
Procedure CheckSignatureOnClientAfterSignatureCheck(Certificate, Context) Export
	
	If Certificate = Undefined Then
		ExecuteNotifyProcessing(Context.Notification,
			NStr("en='Certificate is not found in signature data.';ru='Сертификат не найден в данных подписи.'"));
		Return;
	EndIf;
	
	If Context.Property("CheckCertificateOnClient") Then
		CryptoManager = Context.CryptoManager;
	Else
		// Check certificate on server and on client.
		CryptoManager = Undefined;
	EndIf;
	
	CheckCertificate(Context.Notification, Certificate, CryptoManager);
	
EndProcedure


// Checks the validity of a cryptography certificate.
//
// Parameters:
//   Notification           - NotifyDescription - notification about a result of performing the following types:
//     Boolean       - True if check was completed successfully.
//     String       - error of certificate check description
//     Undefined - unable to receive cryptography manager (when not specified).
//
//   Certificate           - CryptoCertificate - certificate.
//                        - BinaryData - certificate binary data.
//                        - String - address of a temporary storage containing certificate binary data.
//
//   CryptoManager - Undefined - get the cryptography manager automatically.
//                        - CryptoManager - use the specified
//                          cryptography manager (check on server will not executed).
//
Procedure CheckCertificate(Notification, Certificate, CryptoManager = Undefined) Export
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("Certificate", Certificate);
	Context.Insert("CryptoManager", CryptoManager);
	Context.Insert("ErrorDescriptionOnServer", Undefined);
	
	If Context.CryptoManager = Undefined
	   AND DigitalSignatureClientServer.CommonSettings().VerifyDigitalSignaturesAtServer Then
		
		// Check on server before check on client.
		If TypeOf(Certificate) = Type("CryptoCertificate") Then
			
			Certificate.BeginUnloading(New NotifyDescription(
				"CheckCertificateAfterExportCertificate", ThisObject, Context));
		Else
			CheckCertificateAfterExportCertificate(Certificate, Context);
		EndIf;
	Else
		// When the cryptography manager is specified, the check is run only on client.
		CheckCertificateOnClient(Context);
	EndIf;
	
EndProcedure

// Continue the procedure CheckCertificate.
Procedure CheckCertificateAfterExportCertificate(Certificate, Context) Export
	
	// Certificate check on server.
	If TypeOf(Certificate) = Type("BinaryData") Then
		CertificateAddress = PutToTempStorage(Certificate);
	Else
		CertificateAddress = Certificate;
	EndIf;
	
	If DigitalSignatureServiceServerCall.CheckCertificate(CertificateAddress,
			Context.ErrorDescriptionOnServer) Then
		
		ExecuteNotifyProcessing(Context.Notification, True);
	Else
		CheckCertificateOnClient(Context);
	EndIf;
	
EndProcedure

// Continue the procedure CheckCertificate.
Procedure CheckCertificateOnClient(Context)
	
	If Context.CryptoManager = Undefined Then
		CreateCryptoManager(New NotifyDescription(
				"CheckCertificateAfterCreatingCryptographyManager", ThisObject, Context),
			"CertificateCheck", Context.ErrorDescriptionOnServer = Undefined);
	Else
		CheckCertificateAfterCreatingCryptographyManager(Context.CryptoManager, Context);
	EndIf;
	
EndProcedure

// Continue the procedure CheckCertificate.
Procedure CheckCertificateAfterCreatingCryptographyManager(Result, Context) Export
	
	If TypeOf(Result) <> Type("CryptoManager") Then
		ExecuteNotifyProcessing(Context.Notification, Context.ErrorDescriptionOnServer);
		Return;
	EndIf;
	
	Context.CryptoManager = Result;
	
	CertificateForCheck = Context.Certificate;
	
	If TypeOf(CertificateForCheck) = Type("String") Then
		CertificateForCheck = GetFromTempStorage(CertificateForCheck);
	EndIf;
	
	If TypeOf(CertificateForCheck) = Type("BinaryData") Then
		CryptoCertificate = New CryptoCertificate;
		CryptoCertificate.BeginInitialization(New NotifyDescription(
				"CheckCertificateAfterCertificateInitialization", ThisObject, Context),
			CertificateForCheck);
	Else
		CheckCertificateAfterCertificateInitialization(CertificateForCheck, Context)
	EndIf;
	
EndProcedure

// Continue the procedure CheckCertificate.
Procedure CheckCertificateAfterCertificateInitialization(CryptoCertificate, Context) Export
	
	CertificateCheckModes = DigitalSignatureServiceClientServer.CertificateCheckModes();
	
	Context.CryptoManager.StartCertificateCheck(New NotifyDescription(
		"CheckCertificateOnClientAfterCheck", ThisObject, Context,
		"CheckCertificateOnClientAfterErrorChecks", ThisObject),
		CryptoCertificate, CertificateCheckModes);
	
EndProcedure

// Continue the procedure CheckCertificate.
Procedure CheckCertificateOnClientAfterErrorChecks(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	ErrorDescription = BriefErrorDescription(ErrorInfo);
	
	If Context.ErrorDescriptionOnServer <> Undefined Then
		ErrorDescription = Context.ErrorDescriptionOnServer + " " + NStr("en='(on server)';ru='(на сервере)'") + Chars.LF
			+ ErrorDescription + " " + NStr("en='(on client)';ru='(на клиенте)'");
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, ErrorDescription);
	
EndProcedure

// Continue the procedure CheckCertificate.
Procedure CheckCertificateOnClientAfterCheck(Context) Export
	
	ExecuteNotifyProcessing(Context.Notification, True);
	
EndProcedure


// Creates and returns the cryptography manager (on client) for the specified application.
//
// Parameters:
//  Notification     - NotifyDescription - notification about a result of performing the following types:
//    CryptoManager - initialized cryptography manager.
//    String - error description while creating a cryptography manager.
//    Structure - if ShowError = Undefined. Contains errors invoking applications.
//      * ErrorDescription   - String - description of an error when it returns with a row.
//      * ErrorTitle  - String - error title corresponding to the operation.
//      *Description         - String - general error description.
//      *Common            - Boolean - if true, then it contains an error description
//                               for all applications, else alternative description to the Errors array.
//      * ToAdmin  - Boolean - to correct a common error you must be an administrator.
//      *Errors           - Array - contains structures of applications errors description with properties.:
//           * Application       - CatalogRef.DigitalSignatureAndEncryptionApplications.
//           *Description        - String - contains error presentation.
//           * FromException    - Boolean - description contains a brief presentation of information about error.
//           * PathNotSpecified    - Boolean - description contains an error on an unspecified way for OC Linux.
//           * ToAdmin - Boolean - to correct an error you must be an administrator.
//
//  Operation       - String - if it is not empty, it should contain one of
//                   the rows that define the operation to insert into
//                   the description of error: SignatureCheck, Encryption, Decryption, CertificateCheck, ReceiveCertificates.
//
//  ShowError - Boolean - if True, then the ApplicationAccessError form will be opened, from which you can go to the list of installed applications to the form of personal settings on the Installed applications page. There you can see why you did not manage to use the application e installation guide.

//                 - Undefined - return all errors invoking applications (see above).
//
//  Application      - Undefined - returns the cryptography
//                   manager of the first application from the catalog created for it.
//                 - CatalogRef.DigitalSignatureAndEncryptionApplications - application
//                   for which you need to create and return the cryptography manager.
//
Procedure CreateCryptoManager(Notification, Operation, ShowError = True, Application = Undefined) Export
	
	Context = New Structure;
	Context.Insert("Notification",     Notification);
	Context.Insert("Operation",       Operation);
	Context.Insert("ShowError", ShowError);
	Context.Insert("Application",      Application);
	
	BeginAttachingCryptoExtension(New NotifyDescription(
		"CreateCryptographyManagerAfterWorkWithCryptographyExpansionConnection", ThisObject, Context));
	
EndProcedure

// Continue the CreateCryptographyManager procedure.
Procedure CreateCryptographyManagerAfterWorkWithCryptographyExpansionConnection(Attached, Context) Export
	
	FormTitle = NStr("en='Digital signature and encryption application is required';ru='Требуется программа электронной подписи и шифрования'");
	Operation       = Context.Operation;
	
	If Operation = "Signing" Then
		ErrorTitle = NStr("en='Cannot sign data due to:';ru='Не удалось подписать данные по причине:'");
		
	ElsIf Operation = "SignatureCheck" Then
		ErrorTitle = NStr("en='Cannot check the signature due to:';ru='Не удалось проверить подпись по причине:'");
		
	ElsIf Operation = "Encryption" Then
		ErrorTitle = NStr("en='Cannot encrypt data due to:';ru='Не удалось зашифровать данные по причине:'");
		
	ElsIf Operation = "Details" Then
		ErrorTitle = NStr("en='Cannot decrypt data due to:';ru='Не удалось расшифровать данные по причине:'");
		
	ElsIf Operation = "CertificateCheck" Then
		ErrorTitle = NStr("en='Cannot check the certificate due to:';ru='Не удалось проверить сертификат по причине:'");
		
	ElsIf Operation = "GetCertificates" Then
		ErrorTitle = NStr("en='Cannot receive certificates due to:';ru='Не удалось получить сертификаты по причине:'");
		
	ElsIf Operation = Null AND Context.ShowError <> True Then
		ErrorTitle = "";
		
	ElsIf Operation <> "" Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Error in the CryptographyManager function.
		|Wrong of the %1 Operation parameter value.';ru='Ошибка в функции МенеджерКриптографии.
		|Неверное значение параметра Операция ""%1"".'"), Operation);
	Else
		ErrorTitle = NStr("en='Cannot execute the operation due to:';ru='Не удалось выполнить операцию по причине:'");
	EndIf;
	
	ErrorProperties = New Structure;
	ErrorProperties.Insert("ErrorTitle", ErrorTitle);
	ErrorProperties.Insert("Common", False);
	ErrorProperties.Insert("ToAdmin", False);
	
	If Not Attached Then
		ErrorText =
			NStr("en='Install an Internet browser extension to work with digital signature and encryption.';ru='В обозреватель интернет требуется установить расширение для работы с электронной подписью и шифрованием.'");
		
		ErrorProperties.Insert("Description", ErrorText);
		ErrorProperties.Insert("Common",  True);
		ErrorProperties.Insert("Errors", New Array);
		ErrorProperties.Insert("Extension", True);
		
		ErrorProperties.Insert("ErrorDescription", TrimAll(ErrorTitle + Chars.LF + ErrorText));
		If Context.ShowError = Undefined Then
			ErrorDescription = ErrorProperties;
		Else
			ErrorDescription = ErrorProperties.ErrorDescription;
		EndIf;
		If Context.ShowError = True Then
			ShowRequestToApplicationError(
				FormTitle, ErrorTitle, ErrorProperties, New Structure);
		EndIf;
		ExecuteNotifyProcessing(Context.Notification, ErrorDescription);
		Return;
	EndIf;
	
	Context.Insert("FormTitle",  FormTitle);
	Context.Insert("ErrorTitle", ErrorTitle);
	Context.Insert("ErrorProperties",  ErrorProperties);
	Context.Insert("IsLinux", CommonUseClientServer.IsLinuxClient());
	
	ErrorProperties.Insert("Errors", New Array);
	
	ApplicationsDescription = DigitalSignatureServiceClientServer.CryptographyManagerApplicationsDescription(
		Context.Application, ErrorProperties.Errors);
	
	Context.Insert("Manager", Undefined);
	
	If ApplicationsDescription = Undefined Or ApplicationsDescription.Count() = 0 Then
		CreateCryptographyManagerAfterCycle(Context);
		Return;
	EndIf;
	
	Context.Insert("ApplicationsDescription",  ApplicationsDescription);
	Context.Insert("IndexOf", -1);
	
	CreateCryptographyManagerCycleBegin(Context);
	
EndProcedure

// Continue the CreateCryptographyManager procedure.
Procedure CreateCryptographyManagerCycleBegin(Context) Export
	
	If Context.ApplicationsDescription.Count() <= Context.IndexOf + 1 Then
		CreateCryptographyManagerAfterCycle(Context);
		Return;
	EndIf;
	Context.IndexOf = Context.IndexOf + 1;
	Context.Insert("ApplicationDescription", Context.ApplicationsDescription[Context.IndexOf]);
	
	ApplicationProperties = DigitalSignatureServiceClientServer.CryptographyManagerApplicationProperties(
		Context.ApplicationDescription,
		Context.IsLinux,
		Context.ErrorProperties.Errors,
		False);
	
	If ApplicationProperties = Undefined Then
		CreateCryptographyManagerCycleBegin(Context);
		Return;
	EndIf;
	
	Context.Insert("ApplicationProperties", ApplicationProperties);
	
	CryptoTools.BeginGettingCryptoModuleInformation(New NotifyDescription(
			"CreateCryptographyManagerCycleAfterReceivingInformation", ThisObject, Context,
			"CreateCryptographyManagerCycleAfterObtainingInformationError", ThisObject),
		Context.ApplicationProperties.ApplicationName,
		Context.ApplicationProperties.PathToApplication,
		Context.ApplicationProperties.ApplicationType);
	
EndProcedure

// Continue the CreateCryptographyManager procedure.
Procedure CreateCryptographyManagerCycleAfterObtainingInformationError(ErrorInfo, StandardProcessing, Context) Export
	
	CreateCryptographyManagerCycleOnInitializationError(ErrorInfo, StandardProcessing, Context);
	
EndProcedure

// Continue the CreateCryptographyManager procedure.
Procedure CreateCryptographyManagerCycleAfterReceivingInformation(ModuleInformation, Context) Export
	
	If ModuleInformation = Undefined Then
		DigitalSignatureServiceClientServer.CryptographyManagerApplicationNotFound(
			Context.ApplicationDescription, Context.ErrorProperties.Errors, False);
		
		Context.Manager = Undefined;
		CreateCryptographyManagerCycleBegin(Context);
		Return;
	EndIf;
	
	If Not Context.IsLinux Then
		ApplicationNameReceived = ModuleInformation.Name;
		
		ApplicationNameMatches = DigitalSignatureServiceClientServer.CryptographyManagerApplicationNameMatch(
			Context.ApplicationDescription, ApplicationNameReceived, Context.ErrorProperties.Errors, False);
		
		If Not ApplicationNameMatches Then
			Context.Manager = Undefined;
			CreateCryptographyManagerCycleBegin(Context);
			Return;
		EndIf;
	EndIf;
	
	Context.Manager = New CryptoManager;
	
	Context.Manager.BeginInitialization(New NotifyDescription(
			"CreateCryptographyManagerCycleAfterInitializing", ThisObject, Context,
			"CreateCryptographyManagerCycleOnInitializationError", ThisObject),
		Context.ApplicationProperties.ApplicationName,
		Context.ApplicationProperties.PathToApplication,
		Context.ApplicationProperties.ApplicationType);
	
EndProcedure

// Continue the CreateCryptographyManager procedure.
Procedure CreateCryptographyManagerCycleOnInitializationError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	Context.Manager = Undefined;
	
	DigitalSignatureServiceClientServer.CryptographyManagerAddError(
		Context.ErrorProperties.Errors,
		Context.ApplicationDescription.Ref,
		BriefErrorDescription(ErrorInfo),
		False, True, True);
	
	CreateCryptographyManagerCycleBegin(Context);
	
EndProcedure

// Continue the CreateCryptographyManager procedure.
Procedure CreateCryptographyManagerCycleAfterInitializing(NOTSpecified, Context) Export
	
	AlgorithmsSet = DigitalSignatureServiceClientServer.CryptographyManagerAlgorithmsSet(
		Context.ApplicationDescription,
		Context.Manager,
		Context.ErrorProperties.Errors);
	
	If Not AlgorithmsSet Then
		CreateCryptographyManagerCycleBegin(Context);
		Return;
	EndIf;
	
	// Required cryptography manager is received.
	CreateCryptographyManagerAfterCycle(Context);
	
EndProcedure

// Continue the CreateCryptographyManager procedure.
Procedure CreateCryptographyManagerAfterCycle(Context) Export
	
	If Context.Manager <> Undefined Or Not Context.Property("ErrorTitle") Then
		ExecuteNotifyProcessing(Context.Notification, Context.Manager);
		Return;
	EndIf;
	
	ErrorProperties = Context.ErrorProperties;
	
	If ErrorProperties.Errors.Count() = 0 Then
		ErrorText = NStr("en='Usage of no application is possible.';ru='Не предусмотрено использование ни одной программы.'");
		ErrorProperties.Insert("Description", ErrorText);
		ErrorProperties.Common = True;
		ErrorProperties.ToAdmin = True;
		If Not StandardSubsystemsClientReUse.ClientWorkParameters().InfobaseUserWithFullAccess Then
			ErrorText = ErrorText + Chars.LF + Chars.LF + NStr("en='Contact administrator.';ru='Обратитесь к администратору.'");
		EndIf;
		ErrorProperties.Insert("Instruction", True);
		ErrorProperties.Insert("ApplicationsSetting", True);
	Else
		If ValueIsFilled(Context.Application) Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Application %1 is not available or installed on the computer.';ru='Программа %1 не доступна или не установлена на компьютере.'"), Context.Application);
		Else
			ErrorText = NStr("en='None of the applications are available or installed on computer.';ru='Ни одна из программ не доступна или не установлена на компьютере.'");
		EndIf;
		ErrorProperties.Insert("Description", ErrorText);
	EndIf;
	
	ErrorProperties.Insert("ErrorDescription", Context.ErrorTitle + Chars.LF + ErrorText);
	If Context.ShowError = Undefined Then
		ErrorDescription = ErrorProperties;
	Else
		ErrorDescription = ErrorProperties.ErrorDescription;
	EndIf;
	
	If Context.ShowError = True Then
		ShowRequestToApplicationError(
			Context.FormTitle, Context.ErrorTitle, ErrorProperties, New Structure);
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, ErrorDescription);
	
EndProcedure


// Prepares a row to use as a attachment file name.
Function PrepareRowForFileName(String, ReplacementGap = Undefined) Export
	
	CharactersReplacement = New Map;
	CharactersReplacement.Insert("\", " ");
	CharactersReplacement.Insert("/", " ");
	CharactersReplacement.Insert("*", " ");
	CharactersReplacement.Insert("<", " ");
	CharactersReplacement.Insert(">", " ");
	CharactersReplacement.Insert("|", " ");
	CharactersReplacement.Insert(":", "");
	CharactersReplacement.Insert("""", "");
	CharactersReplacement.Insert("?", "");
	CharactersReplacement.Insert(Chars.CR, "");
	CharactersReplacement.Insert(Chars.LF, " ");
	CharactersReplacement.Insert(Chars.Tab, " ");
	CharactersReplacement.Insert(Chars.NBSp, " ");
	// replacing quotes characters
	CharactersReplacement.Insert(Char(171), "");
	CharactersReplacement.Insert(Char(187), "");
	CharactersReplacement.Insert(Char(8195), "");
	CharactersReplacement.Insert(Char(8194), "");
	CharactersReplacement.Insert(Char(8216), "");
	CharactersReplacement.Insert(Char(8218), "");
	CharactersReplacement.Insert(Char(8217), "");
	CharactersReplacement.Insert(Char(8220), "");
	CharactersReplacement.Insert(Char(8222), "");
	CharactersReplacement.Insert(Char(8221), "");
	
	RowPrepared = "";
	
	CharCount = StrLen(String);
	
	For CharacterNumber = 1 To CharCount Do
		Char = Mid(String, CharacterNumber, 1);
		If CharactersReplacement[Char] <> Undefined Then
			Char = CharactersReplacement[Char];
		EndIf;
		RowPrepared = RowPrepared + Char;
	EndDo;
	
	If ReplacementGap <> Undefined Then
		RowPrepared = StrReplace(ReplacementGap, " ", ReplacementGap);
	EndIf;
	
	Return TrimAll(RowPrepared);
	
EndFunction


// Only for internal purpose.
//
// Parameters:
//  CreationParameters - Structure - with properties:
//   * ToPersonalList    - Boolean - if not specified, then False.
//                        If True, then the User attribute will be filled by the current user.
//   *Company      - CatalogRef.Companies - default value.
//   * HideApplication  - Boolean - do not offer an application for a certificate issue.
//   * CreateApplication - Boolean - immediately open the application creation form for the certificate issue.
//
Procedure AddCertificate(CreationParameters = Undefined) Export
	
	If TypeOf(CreationParameters) <> Type("Structure") Then
		CreationParameters = New Structure;
	EndIf;
	
	If Not CreationParameters.Property("ToPersonalList") Then
		CreationParameters.Insert("ToPersonalList", False);
	EndIf;
	
	If Not CreationParameters.Property("Company") Then
		CreationParameters.Insert("Company", Undefined);
	EndIf;
	
	If CreationParameters.Property("CreateApplication") AND CreationParameters.CreateApplication = True Then
		AddCertificateAfterSelectingDesignation("RequestForCertificateIssue", CreationParameters);
		Return;
	EndIf;
	
	If Not CreationParameters.Property("HideApplication") Then
		CreationParameters.Insert("HideApplication", True);
	EndIf;
	
	Form = OpenForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.AddCertificate",
		New Structure("HideApplication", CreationParameters.HideApplication),,,,,
		New NotifyDescription("AddCertificateAfterSelectingDesignation", ThisObject, CreationParameters));
	
	If Form = Undefined Then
		AddCertificateAfterSelectingDesignation("ForSigningEncryptionAndDecryption", CreationParameters);
	EndIf;
	
EndProcedure


// Only for internal purpose.
Procedure AddCertificateAfterSelectingDesignation(Purpose, CreationParameters) Export
	
	FormParameters = New Structure;
	
	If Purpose = "RequestForCertificateIssue" Then
		FormParameters.Insert("PersonalListOnAdd", CreationParameters.ToPersonalList);
		FormParameters.Insert("Company", CreationParameters.Company);
		OpenForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.RequestForNewQualifiedCertificateIssue",
			FormParameters);
		Return;
	EndIf;
	
	If Purpose = "ForEncryptionOnlyFromFile" Then
		AddCertificateForEncryptionOnlyFromFile(CreationParameters.ToPersonalList);
		Return;
	EndIf;
	
	If Purpose <> "ForEncryptionOnly" Then
		FormParameters.Insert("ForEncryptionAndDecryption", Undefined);
		
		If Purpose = "ForEncryptionAndDecryption" Then
			FormParameters.Insert("ForEncryptionAndDecryption", True);
		
		ElsIf Purpose <> "ForSigningEncryptionAndDecryption" Then
			Return;
		EndIf;
		
		FormParameters.Insert("InsertIntoList", True);
		FormParameters.Insert("PersonalListOnAdd", CreationParameters.ToPersonalList);
		FormParameters.Insert("Company", CreationParameters.Company);
		CertificateChoiceForSigningOrDecoding(FormParameters);
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("CreationParameters", CreationParameters);
	
	GetCertificatesPropertiesOnClient(New NotifyDescription(
			"AddCertificateAfterReceivingCertificatePropertiesOnClient", ThisObject, Context),
		False, False);
	
EndProcedure

// Continue the AddCertificateAfterDestinationSelection procedure.
Procedure AddCertificateAfterReceivingCertificatePropertiesOnClient(Result, Context) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("CertificatesPropertiesOnClient",        Result.CertificatesPropertiesOnClient);
	FormParameters.Insert("ErrorReceivingCertificatesOnClient", Result.ErrorReceivingCertificatesOnClient);
	FormParameters.Insert("PersonalListOnAdd",            Context.CreationParameters.ToPersonalList);
	Form = OpenForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.AddCertificateForEncryption",
		FormParameters);
	
EndProcedure


// Only for internal purpose.
Procedure GetCertificatesPropertiesOnClient(Notification, Pesonal, WithoutFilter, PrintsOnly = False, ShowError = Undefined) Export
	
	Result = New Structure;
	Result.Insert("ErrorReceivingCertificatesOnClient", New Structure);
	Result.Insert("CertificatesPropertiesOnClient", ?(PrintsOnly, New Map, New Array));
	
	Context = New Structure;
	Context.Insert("Notification",      Notification);
	Context.Insert("Pesonal",          Pesonal);
	Context.Insert("WithoutFilter",       WithoutFilter);
	Context.Insert("PrintsOnly", PrintsOnly);
	Context.Insert("Result",       Result);
	
	CreateCryptoManager(New NotifyDescription(
			"GetCertificatePropertiesOnClientAfterCreatingCryptographyManager", ThisObject, Context),
		"GetCertificates", ShowError);
	
EndProcedure

// Continue the GetCertificatePropertiesOnClient procedures.
Procedure GetCertificatePropertiesOnClientAfterCreatingCryptographyManager(CryptoManager, Context) Export
	
	If TypeOf(CryptoManager) <> Type("CryptoManager") Then
		Context.Result.ErrorReceivingCertificatesOnClient = CryptoManager;
		ExecuteNotifyProcessing(Context.Notification, Context.Result);
		Return;
	EndIf;
	
	Context.Insert("CryptoManager", CryptoManager);
	
	Context.CryptoManager.StartGettingCertificatesStorage(
		New NotifyDescription(
			"GetCertificatePropertiesOnClientAfterReceivingPersonalStorage", ThisObject, Context),
		CryptoCertificateStoreType.PersonalCertificates);
	
EndProcedure

// Continue the GetCertificatePropertiesOnClient procedures.
Procedure GetCertificatePropertiesOnClientAfterReceivingPersonalStorage(Storage, Context) Export
	
	Storage.StartGetAll(New NotifyDescription(
		"GetCertificatePropertiesOnClientAfterReceivingAllPersonalCertificates", ThisObject, Context));
	
EndProcedure

// Continue the GetCertificatePropertiesOnClient procedures.
Procedure GetCertificatePropertiesOnClientAfterReceivingAllPersonalCertificates(Array, Context) Export
	
	Context.Insert("CertificatesArray", Array);
	
	If Context.Pesonal Then
		GetCertificatePropertiesOnClientAfterReceivingAll(Context);
		Return;
	EndIf;
	
	Context.CryptoManager.StartGettingCertificatesStorage(
		New NotifyDescription(
			"GetCertificatePropertiesOnClientAfterReceivingReceiversStorage", ThisObject, Context),
		CryptoCertificateStoreType.RecipientCertificates);
	
EndProcedure

// Continue the GetCertificatePropertiesOnClient procedures.
Procedure GetCertificatePropertiesOnClientAfterReceivingReceiversStorage(Storage, Context) Export
	
	Storage.StartGetAll(New NotifyDescription(
		"GetCertificatePropertiesOnClientAfterReceivingAllCustomerCertificates", ThisObject, Context));
	
EndProcedure

// Continue the GetCertificatePropertiesOnClient procedures.
Procedure GetCertificatePropertiesOnClientAfterReceivingAllCustomerCertificates(Array, Context) Export
	
	For Each Certificate IN Array Do
		Context.CertificatesArray.Add(Certificate);
	EndDo;
	
	GetCertificatePropertiesOnClientAfterReceivingAll(Context);
	
EndProcedure

// Continue the GetCertificatePropertiesOnClient procedures.
Procedure GetCertificatePropertiesOnClientAfterReceivingAll(Context)
	
	DigitalSignatureServiceClientServer.AddCertificatesProperties(
		Context.Result.CertificatesPropertiesOnClient,
		Context.CertificatesArray,
		Context.WithoutFilter,
		Context.PrintsOnly);
	
	ExecuteNotifyProcessing(Context.Notification, Context.Result);
	
EndProcedure


// Only for internal purpose.
Procedure AddCertificateForEncryptionOnlyFromFile(ToPersonalList = False) Export
	
	Context = New Structure("ToPersonalList", ToPersonalList);
	BeginAttachingFileSystemExtension(New NotifyDescription(
		"AddCertificateForEncryptionOnlyFromFileAfterConnectingExtension", ThisObject, Context));
	
EndProcedure

// Continue the AddCertificateForEncryptionOnlyFromFile procedure.
Procedure AddCertificateForEncryptionOnlyFromFileAfterConnectingExtension(Attached, Context) Export
	
	If Not Attached Then
		BeginPutFile(New NotifyDescription(
			"AddCertificateForEncryptionOnlyFromFileOnBeginPostingFile", ThisObject, Context));
		Return;
	EndIf;
	
	Dialog = New FileDialog(FileDialogMode.Open);
	Dialog.Title = NStr("en='Select a certificate file (only for encryption)';ru='Выберите файл сертификата (только для шифрования)'");
	Dialog.Filter = NStr("en='Certificate X.509 (*.cer;*.crt)|*.cer;*.crt|All files(*.*)|*.*';ru='Сертификат X.509 (*.cer;*.crt)|*.cer;*.crt|Все файлы(*.*)|*.*'");
	
	BeginPuttingFiles(New NotifyDescription(
			"AddCertificateForEncryptionOnlyFromFileAfterPostingFiles", ThisObject, Context),
		, Dialog, False);
	
EndProcedure

// Continue the AddCertificateForEncryptionOnlyFromFile procedure.
Procedure AddCertificateForEncryptionOnlyFromFileAfterPostingFiles(PlacedFiles, Context) Export
	
	If Not ValueIsFilled(PlacedFiles) Then
		Return;
	EndIf;
	
	AddCertificateForEncryptionOnlyFromFileAfterPostingFile(PlacedFiles[0].Location, Context);
	
EndProcedure

// Continue the AddCertificateForEncryptionOnlyFromFile procedure.
Procedure AddCertificateForEncryptionOnlyFromFileOnBeginPostingFile(Result, Address, SelectedFileName, Context) Export
	
	If Result <> True Then
		Return;
	EndIf;
	
	AddCertificateForEncryptionOnlyFromFileAfterPostingFile(Address, Context);
	
EndProcedure

// Continue the AddCertificateForEncryptionOnlyFromFile procedure.
Procedure AddCertificateForEncryptionOnlyFromFileAfterPostingFile(Address, Context)
	
	FormParameters = New Structure;
	FormParameters.Insert("CertificateDataAddress", Address);
	FormParameters.Insert("PersonalListOnAdd", Context.ToPersonalList);
	Form = OpenForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.AddCertificateForEncryption",
		FormParameters);
	
	If Form = Undefined Then
		ShowMessageBox(,
			NStr("en='Certificate file must have DER X.509 format, operation aborted.';ru='Файл сертификата должен быть в формате DER X.509, операция прервана.'"));
		Return;
	EndIf;
	
	If Not Form.IsOpen() Then
		Buttons = New ValueList;
		Buttons.Add("Open", NStr("en='Open';ru='Открыть'"));
		Buttons.Add("Cancel",  NStr("en='Cancel';ru='Отменить'"));
		ShowQueryBox(
			New NotifyDescription("AddCertificateForEncryptionOnlyFromFileAfterWarningAboutExisting",
				ThisObject, Form.Certificate),
			NStr("en='Certificate is already added.';ru='Сертификат уже добавлен.'"), Buttons);
	EndIf;
	
EndProcedure

// Continue the AddCertificateForEncryptionOnlyFromFile procedure.
Procedure AddCertificateForEncryptionOnlyFromFileAfterWarningAboutExisting(Response, Certificate) Export
	
	If Response <> "Open" Then
		Return;
	EndIf;
	
	OpenCertificate(Certificate);
	
EndProcedure


// Only for internal use.
Procedure ShowRequestToApplicationError(FormTitle, ErrorTitle, ErrorOnClient, ErrorOnServer,
				AdditionalParameters = Undefined, ContinuationProcessor = Undefined) Export
	
	If TypeOf(ErrorOnClient) <> Type("Structure") Then
		Raise
			NStr("en='For the
		|ShowRequestToApplicationError procedure an incorrect ErrorOnClient parameter type is specified.';ru='Для
		|процедуры ПоказатьОшибкуОбращенияКПрограмме указан некорректный тип параметра ОшибкаНаКлиенте.'");
	EndIf;
	
	If TypeOf(ErrorOnServer) <> Type("Structure") Then
		Raise
			NStr("en='For the
		|ShowRequestToApplicationError procedure an incorrect ErrorOnServer parameter type is specified.';ru='Для
		|процедуры ПоказатьОшибкуОбращенияКПрограмме указан некорректный тип параметра ОшибкаНаСервере.'");
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowInstruction",                False);
	FormParameters.Insert("ShowTransferToApplicationsSetup", False);
	FormParameters.Insert("ShowExtensionInstallation",       False);
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		FillPropertyValues(FormParameters, AdditionalParameters);
	EndIf;
	
	FormParameters.Insert("FormTitle",  FormTitle);
	FormParameters.Insert("ErrorTitle", ErrorTitle);
	
	FormParameters.Insert("ErrorOnClient", ErrorOnClient);
	FormParameters.Insert("ErrorOnServer", ErrorOnServer);
	
	Context = New Structure;
	Context.Insert("FormParameters", FormParameters);
	Context.Insert("ContinuationProcessor", ContinuationProcessor);
	
	BeginAttachingCryptoExtension(New NotifyDescription(
		"ShowRequestToApplicationErrorAfterConnectingExpansions", ThisObject, Context));
	
EndProcedure

// Continue the ShowErrorInvokingApplication procedure.
Procedure ShowRequestToApplicationErrorAfterConnectingExpansions(Attached, Context) Export
	
	Context.FormParameters.Insert("ExtensionAttached", Attached);
	
	Form = OpenForm("Catalog.DigitalSignatureAndEncryptionApplications.Form.ApplicationAccessError",
		Context.FormParameters,,,, , Context.ContinuationProcessor);
	
EndProcedure


// Only for internal use.
Procedure SetCertificatePassword(CertificatRef, Password, PasswordExplanation = Undefined) Export
	
	ParameterTransferForm().SetCertificatePassword(CertificatRef, Password, PasswordExplanation);
	
EndProcedure

// Only for internal use.
Procedure OpenNewForm(FormKind, ClientParameters, ServerParameters, CompletionProcessing) Export
	
	DataDescription = ClientParameters.DataDescription;
	
	ServerParameters.Insert("WithoutConfirmation", False);
	
	If ServerParameters.Property("FilterCertificates")
	   AND TypeOf(ServerParameters.FilterCertificates) = Type("Array")
	   AND ServerParameters.FilterCertificates.Count() = 1
	   AND DataDescription.Property("WithoutConfirmation")
	   AND DataDescription.WithoutConfirmation Then
		
		ServerParameters.Insert("WithoutConfirmation", True);
	EndIf;
	
	If ServerParameters.Property("CertificatesSet")
	   AND DataDescription.Property("WithoutConfirmation")
	   AND DataDescription.WithoutConfirmation Then
		
		ServerParameters.Insert("WithoutConfirmation", True);
	EndIf;
	
	SetDataPresentation(ClientParameters, ServerParameters);
	
	Context = New Structure;
	Context.Insert("FormKind",            FormKind);
	Context.Insert("ClientParameters", ClientParameters);
	Context.Insert("ServerParameters",  ServerParameters);
	Context.Insert("CompletionProcessing", CompletionProcessing);
	
	GetCertificatePrintsAtClient(New NotifyDescription(
		"OpenNewFormEnd", ThisObject, Context));
	
EndProcedure

// Continue the procedure OpenNewForm.
Procedure OpenNewFormEnd(CertificateThumbprintsAtClient, Context) Export
	
	Context.ServerParameters.Insert("CertificateThumbprintsAtClient",
		CertificateThumbprintsAtClient);
	
	ParameterTransferForm().OpenNewForm(
		Context.FormKind,
		Context.ServerParameters,
		Context.ClientParameters,
		Context.CompletionProcessing);
	
EndProcedure

// Only for internal use.
Procedure UpdateFormBeforeUsingAgain(Form, ClientParameters) Export
	
	ServerParameters  = New Structure;
	SetDataPresentation(ClientParameters, ServerParameters);
	
	Form.DataPresentation  = ServerParameters.DataPresentation;
	
EndProcedure

// Only for internal use.
Procedure SetDataPresentation(ClientParameters, ServerParameters) Export
	
	DataDescription = ClientParameters.DataDescription;
	
	If DataDescription.Property("PresentationsList") Then
		PresentationsList = DataDescription.PresentationsList;
	Else
		PresentationsList = New Array;
		
		If DataDescription.Property("Data")
		 Or DataDescription.Property("Object") Then
			
			FillPresentationsList(PresentationsList, DataDescription);
		Else
			For Each DataItem IN DataDescription.DataSet Do
				FillPresentationsList(PresentationsList, DataItem);
			EndDo;
		EndIf;
	EndIf;
	
	CurrentPresentationsList = New ValueList;
	
	For Each ItemOfList IN PresentationsList Do
		If TypeOf(ItemOfList) = Type("String") Then
			Presentation = ItemOfList.Presentation;
			Value = Undefined;
		ElsIf TypeOf(ItemOfList) = Type("Structure") Then
			Presentation = ItemOfList.Presentation;
			Value = ItemOfList.Value;
		Else // Refs
			Presentation = "";
			Value = ItemOfList.Value;
		EndIf;
		If ValueIsFilled(ItemOfList.Presentation) Then
			Presentation = ItemOfList.Presentation;
		Else
			Presentation = String(ItemOfList.Value);
		EndIf;
		CurrentPresentationsList.Add(Value, Presentation);
	EndDo;
	
	If CurrentPresentationsList.Count() > 1 Then
		ServerParameters.Insert("DataPresentationOpens", True);
		ServerParameters.Insert("DataPresentation", StringFunctionsClientServer.SubstituteParametersInString(
			DataDescription.SetPresentation, DataDescription.DataSet.Count()));
	Else
		ServerParameters.Insert("DataPresentationOpens",
			ValueIsFilled(CurrentPresentationsList[0].Value));
		
		ServerParameters.Insert("DataPresentation",
			CurrentPresentationsList[0].Presentation);
	EndIf;
	
	ClientParameters.Insert("CurrentPresentationsList", CurrentPresentationsList);
	
EndProcedure

// Only for internal use.
Procedure StartSelectingCertificateWhenFilterIsSet(Form) Export
	
	AvailableCertificates = "";
	UnavailableCertificates = "";
	
	Text = NStr("en='Certificates that can be used for this operation are limited.';ru='Сертификаты, которые могут быть использованы для этой операции ограничены.'");
	
	For Each ItemOfList IN Form.FilterCertificates Do
		If Form.CertificateChoiceList.FindByValue(ItemOfList.Value) = Undefined Then
			UnavailableCertificates = UnavailableCertificates + Chars.LF + String(ItemOfList.Value);
		Else
			AvailableCertificates = AvailableCertificates + Chars.LF + String(ItemOfList.Value);
		EndIf;
	EndDo;
	
	If ValueIsFilled(AvailableCertificates) Then
		Title = NStr("en='The following trusted certificates are available for selection:';ru='Следующие разрешенные сертификаты доступны для выбора:'");
		Text = Text + Chars.LF + Chars.LF + Title + Chars.LF + TrimAll(AvailableCertificates);
	EndIf;
	
	If ValueIsFilled(UnavailableCertificates) Then
		If DigitalSignatureClientServer.CommonSettings().CreateDigitalSignaturesAtServer Then
			If ValueIsFilled(AvailableCertificates) Then
				Title = NStr("en='The following trusted certificates were not found either on computer, or on server:';ru='Следующие разрешенные сертификаты не найдены ни на компьютере, ни на сервере:'");
			Else
				Title = NStr("en='None of the following trusted certificates was found either on the computer, or on the server:';ru='Ни один из следующих разрешенных сертификатов не найден ни на компьютере, ни на сервере:'");
			EndIf;
		Else
			If ValueIsFilled(AvailableCertificates) Then
				Title = NStr("en='The following trusted certificates were not found on computer:';ru='Следующие разрешенные сертификаты не найдены на компьютере:'");
			Else
				Title = NStr("en='None of the following trusted certificates was found on the computer:';ru='Ни один из следующих разрешенных сертификатов не найден на компьютере:'");
			EndIf;
		EndIf;
		Text = Text + Chars.LF + Chars.LF + Title + Chars.LF + TrimAll(UnavailableCertificates);
	EndIf;
	
	ShowMessageBox(, Text);
	
EndProcedure

// Only for internal use.
Procedure CertificateChoiceForSigningOrDecoding(ServerParameters, NewFormOwner = Undefined) Export
	
	If NewFormOwner = Undefined Then
		NewFormOwner = New UUID;
	EndIf;
	
	Context = New Structure;
	Context.Insert("ServerParameters", ServerParameters);
	Context.Insert("NewFormOwner", NewFormOwner);
	
	GetCertificatesPropertiesOnClient(New NotifyDescription(
		"CertificateChoiceForSigningOrDecryptingContinue", ThisObject, Context), True, False);
	
EndProcedure

// Continue the AddCertificateForSigningAndDecryption procedure.
Procedure CertificateChoiceForSigningOrDecryptingContinue(Result, Context) Export
	
	Context.ServerParameters.Insert("CertificatesPropertiesOnClient",
		Result.CertificatesPropertiesOnClient);
	
	Context.ServerParameters.Insert("ErrorReceivingCertificatesOnClient",
		Result.ErrorReceivingCertificatesOnClient);
	
	ParameterTransferForm().OpenNewForm("CertificateChoiceForSigningOrDecoding",
		Context.ServerParameters, , , Context.NewFormOwner);
	
EndProcedure

// Only for internal use.
Procedure CheckCatalogCertificate(Certificate, AdditionalParameters) Export
	
	ServerParameters = New Structure;
	ServerParameters.Insert("FormTitle");
	ServerParameters.Insert("CheckOnSelection");
	ServerParameters.Insert("AdditionalChecksParameters");
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		FillPropertyValues(ServerParameters, AdditionalParameters);
	EndIf;
	
	ServerParameters.Insert("Certificate", Certificate);
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		ClientParameters = AdditionalParameters;
	Else
		ClientParameters = New Structure;
	EndIf;
	
	FormOwner = Undefined;
	ClientParameters.Property("FormOwner", FormOwner);
	
	CompletionProcessing = Undefined;
	ClientParameters.Property("CompletionProcessing", CompletionProcessing);
	
	ParameterTransferForm().OpenNewForm("CertificateCheck",
		ServerParameters, ClientParameters, CompletionProcessing, FormOwner);
	
EndProcedure


// Only for internal use.
Procedure StandardEnd(Success, ClientParameters) Export
	
	ClientParameters.DataDescription.Insert("Success", Success = True);
	
	If ClientParameters.ResultProcessing <> Undefined Then
		ExecuteNotifyProcessing(ClientParameters.ResultProcessing,
			ClientParameters.DataDescription);
	EndIf;
	
EndProcedure


// Continue the DigitalSignatureClient procedure.AddSignatureFromFile.
Procedure AddSignatureFromFileAfterCreatingCryptographyManager(Result, Context) Export
	
	If Context.CheckCryptographyManagerOnClient
	   AND TypeOf(Result) <> Type("CryptoManager") Then
		
		ShowRequestToApplicationError(
			NStr("en='Digital signature and encryption application is required';ru='Требуется программа электронной подписи и шифрования'"),
			"", Result, Context.AddingForm.CryptoManagerAtServerErrorDescription);
	Else
		Context.AddingForm.Open();
		If Context.AddingForm.IsOpen() Then
			Context.AddingForm.RefreshDataRepresentation();
			Return;
		EndIf;
	EndIf;
	
	If Context.ResultProcessing <> Undefined Then
		ExecuteNotifyProcessing(Context.ResultProcessing, Context.DataDescription);
	EndIf;
	
EndProcedure


// Offers a user to select signatures to save with object data.
//
// A general approach to processing of the properties values with the NotificationDescription type in the DataDescription parameter.
//  During the notification processing the parameters structure is being inserted into it
//  that always has the Notification property of the NotificationDescription type which should be processed to continue.
//  Also there is always the DataDescription property in the structure received during a procedure call.
//  When calling a notification, a structure should be passed as a value. If an error
//  occurs during the asynchronous process, then you should insert the ErrorDescription property of the Row type into a structure.
// 
// Parameters:
//  DataDescription - Structure - with properties:
//    * DataTitle     - String - header of data item, for example, File.
//    * ShowComment - Boolean - (optional) - allows a comment
//                              input in the form of adding signatures. If not specified, then False.
//    Author presentation      - Ref, Row - (optional), if
//                                it is not specified, then the presentation is calculated according to value of the Object property.
//    (prohibition is set for the object             - Refs - reference to an object with
//                              the DigitalSignature tabular section, from which you should receive a users list.//
//    * -- --             - String - address of a temporary storage of the
//                              signatures array with properties content like the AssSignatureFromFile procedure returns.
//    *Data             - NotifyDescription - handler of saving data and receiving
//                              a full name with path (after saving) returned as the
//                              FileDescriptionFull property of the Row for saving digital signatures type (see above a general approach).
//                              If the extension for work with files is not connected,
//                              you need to return the attachment file name without path.
//                              If the property is not inserted or filled - it is
//                              considered to be a denial from continuing, and ResultProcessing will be called with the False result.
//
//  ResultProcessing - NotifyDescription - optional parameter.
//     Parameter is transferred to the result:
//     *Boolean - True if all succeeded.
//
Procedure SaveDataWithSignature(DataDescription, ResultProcessing = Undefined) Export
	
	Context = New Structure;
	Context.Insert("DataDescription", DataDescription);
	Context.Insert("ResultProcessing", ResultProcessing);
	
	SaveAllSignatures = DigitalSignatureClientServer.PersonalSettings(
		).ActionsOnSavingDS = "SaveAllSignatures";
	
	ServerParameters = New Structure;
	ServerParameters.Insert("DataTitle",     NStr("en='Data';ru='Данные'"));
	ServerParameters.Insert("ShowComment", False);
	FillPropertyValues(ServerParameters, DataDescription);
	
	ServerParameters.Insert("SaveAllSignatures", SaveAllSignatures);
	ServerParameters.Insert("Object", DataDescription.Object);
	
	ClientParameters = New Structure;
	ClientParameters.Insert("DataDescription", DataDescription);
	SetDataPresentation(ClientParameters, ServerParameters);
	
	SavingForm = OpenForm("CommonForm.SaveWithDigitalSignature", ServerParameters,,,,,
		New NotifyDescription("SaveDataWithSignatureAfterSignaturesSelection", ThisObject, Context));
	
	Complete = False;
	Context.Insert("Form", SavingForm);
	
	If SavingForm = Undefined Then
		Complete = True;
	Else
		SavingForm.ClientParameters = ClientParameters;
		
		If SaveAllSignatures Then
			SaveDataWithSignatureAfterSignaturesSelection(SavingForm.SignaturesTable, Context);
			Return;
			
		ElsIf Not SavingForm.IsOpen() Then
			Complete = True;
		EndIf;
	EndIf;
	
	If Complete AND Context.ResultProcessing <> Undefined Then
		ExecuteNotifyProcessing(Context.ResultProcessing, False);
	EndIf;
	
EndProcedure

// Continue the DigitalSignatureClient procedure.SaveDataWithSignature.
Procedure SaveDataWithSignatureAfterSignaturesSelection(SignaturesCollection, Context) Export
	
	If TypeOf(SignaturesCollection) <> Type("FormDataCollection") Then
		If Context.ResultProcessing <> Undefined Then
			ExecuteNotifyProcessing(Context.ResultProcessing, False);
		EndIf;
		Return;
	EndIf;
	
	Context.Insert("SignaturesCollection", SignaturesCollection);
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("DataDescription", Context.DataDescription);
	ExecuteParameters.Insert("Notification", New NotifyDescription(
		"SaveDataWithSignatureAfterSavingDataFile", ThisObject, Context));
	
	Try
		ExecuteNotifyProcessing(Context.DataDescription.Data, ExecuteParameters);
	Except
		ErrorInfo = ErrorInfo();
		SaveDataWithSignatureAfterSavingDataFile(
			New Structure("ErrorDescription", BriefErrorDescription(ErrorInfo)), Context);
	EndTry;
	
EndProcedure

// Continue the DigitalSignatureClient procedure.SaveDataWithSignature.
Procedure SaveDataWithSignatureAfterSavingDataFile(Result, Context) Export
	
	If Result.Property("ErrorDescription") Then
		Error = New Structure("ErrorDescription",
			NStr("en='An error occurred when writing file:';ru='При записи файла возникла ошибка:'") + Chars.LF + Result.ErrorDescription);
		
		ShowRequestToApplicationError(
			NStr("en='Cannot save signatures with the file';ru='Не удалось сохранить подписи вместе с файлом'"), "", Error, New Structure);
		Return;
		
	ElsIf Not Result.Property("FullFileName")
	      Or TypeOf(Result.FullFileName) <> Type("String")
	      Or IsBlankString(Result.FullFileName) Then
		
		If Context.ResultProcessing <> Undefined Then
			ExecuteNotifyProcessing(Context.ResultProcessing, False);
		EndIf;
		Return;
	EndIf;
	
	Context.Insert("FullFileName", Result.FullFileName);
	Context.Insert("DataFileNameContent",
		CommonUseClientServer.SplitFullFileName(Context.FullFileName));
	
	If ValueIsFilled(Context.DataFileNameContent.Path) Then
		CommonUseClient.ShowFileSystemExtensionInstallationQuestion(New NotifyDescription(
			"SaveDataWithSignatureAfterFileWorkExtensionConnection", ThisObject, Context));
	Else
		SaveDataWithSignatureAfterFileWorkExtensionConnection(False, Context);
	EndIf;
	
EndProcedure

// Continue the DigitalSignatureClient procedure.SaveDataWithSignature.
Procedure SaveDataWithSignatureAfterFileWorkExtensionConnection(Attached, Context) Export
	
	Context.Insert("Attached", Attached);
	
	Context.Insert("ExtensionForSignatureFiles",
		DigitalSignatureClientServer.PersonalSettings().ExtensionForSignatureFiles);
	
	If Context.Attached Then
		Context.Insert("FilesToReceive", New Array);
		Context.Insert("PathToFiles", CommonUseClientServer.AddFinalPathSeparator(
			Context.DataFileNameContent.Path));
	EndIf;
	
	Context.Insert("FileNames", New Map);
	Context.FileNames.Insert(Context.DataFileNameContent.Name, True);
	
	Context.Insert("IndexOf", -1);
	
	SaveDataWithSignaturCycleBegin(Context);
	
EndProcedure

// Continue the DigitalSignatureClient procedure.SaveDataWithSignature.
Procedure SaveDataWithSignaturCycleBegin(Context)
	
	If Context.SignaturesCollection.Count() <= Context.IndexOf + 1 Then
		SaveDataWithSignatureAfterCycle(Context);
		Return;
	EndIf;
	Context.IndexOf = Context.IndexOf + 1;
	Context.Insert("SignatureDescription", Context.SignaturesCollection[Context.IndexOf]);
	
	If Not Context.SignatureDescription.Check Then
		SaveDataWithSignaturCycleBegin(Context);
	EndIf;
	
	Context.Insert("SignatureFileName", Context.SignatureDescription.SignatureFileName);
	
	If IsBlankString(Context.SignatureFileName) Then 
		Context.SignatureFileName = Context.DataFileNameContent.BaseName + " - "
			+ String(Context.SignatureDescription.CertificateIsIssuedTo) + "." + Context.ExtensionForSignatureFiles;
	EndIf;
	
	Context.SignatureFileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(Context.SignatureFileName);
	SignatureFileNameContent = CommonUseClientServer.SplitFullFileName(Context.SignatureFileName);
	Context.Insert("SignatureFileNameWithoutExpansion", SignatureFileNameContent.BaseName);
	
	Context.Insert("Counter", 1);
	
	SaveDataWithSignatureCycleInternalCycleBegin(Context);
	
EndProcedure

// Continue the DigitalSignatureClient procedure.SaveDataWithSignature.
Procedure SaveDataWithSignatureCycleInternalCycleBegin(Context)
	
	Context.Counter = Context.Counter + 1;
	
	If Context.Attached Then
		Context.Insert("FullNameOfSignatureFile", Context.PathToFiles + Context.SignatureFileName);
	Else
		Context.Insert("FullNameOfSignatureFile", Context.SignatureFileName);
	EndIf;
	
	If Context.FileNames[Context.SignatureFileName] <> Undefined Then
		SaveDataWithSignatureDoInternalDoAfterChecksTheExistenceOfAFile(True, Context);
		
	ElsIf Context.Attached Then
		File = New File;
		File.BeginInitialization(New NotifyDescription(
				"SaveDataWithSignatureCycleInternalCycleAfterFileInitialization", ThisObject, Context),
			Context.FullNameOfSignatureFile);
	Else
		SaveDataWithSignatureDoInternalDoAfterChecksTheExistenceOfAFile(False, Context);
	EndIf;
	
EndProcedure

// Continue the DigitalSignatureClient procedure.SaveDataWithSignature.
Procedure SaveDataWithSignatureCycleInternalCycleAfterFileInitialization(File, Context) Export
	
	File.StartExistenceCheck(New NotifyDescription(
		"SaveDataWithSignatureDoInternalDoAfterChecksTheExistenceOfAFile", ThisObject, Context));
	
EndProcedure

// Continue the DigitalSignatureClient procedure.SaveDataWithSignature.
Procedure SaveDataWithSignatureDoInternalDoAfterChecksTheExistenceOfAFile(Exists, Context) Export
	
	If Not Exists Then
		SaveDataWithSignatureCycleAfterInternalCycle(Context);
		Return;
	EndIf;
	
	Context.SignatureFileName = Context.SignatureFileNameWithoutExpansion
		+ " (" + String(Context.Counter) + ")" + "." + Context.ExtensionForSignatureFiles;
	
	Context.SignatureFileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(Context.SignatureFileName);
	
	SaveDataWithSignatureCycleInternalCycleBegin(Context);
	
EndProcedure

// Continue the DigitalSignatureClient procedure.SaveDataWithSignature.
Procedure SaveDataWithSignatureCycleAfterInternalCycle(Context)
	
	SignatureFileNameContent = CommonUseClientServer.SplitFullFileName(Context.FullNameOfSignatureFile);
	Context.FileNames.Insert(SignatureFileNameContent.Name, False);
	
	If Context.Attached Then
		Description = New TransferableFileDescription(SignatureFileNameContent.Name, Context.SignatureDescription.SignatureAddress);
		Context.FilesToReceive.Add(Description);
	Else
		// Save File from database to disk.
		GetFile(Context.SignatureDescription.SignatureAddress, SignatureFileNameContent.Name);
	EndIf;
	
	SaveDataWithSignaturCycleBegin(Context);
	
EndProcedure

// Continue the DigitalSignatureClient procedure.SaveDataWithSignature.
Procedure SaveDataWithSignatureAfterCycle(Context)
	
	If Not Context.Attached Then
		Return;
	EndIf;
	
	// Save File from database to disk.
	If Context.FilesToReceive.Count() > 0 Then
		ReceivedFiles = New Array;
		Context.Insert("FilesToReceive", Context.FilesToReceive);
		
		Calls = New Array;
		Call = New Array;
		Call.Add("BeginGettingFiles");
		Call.Add(Context.FilesToReceive);
		Call.Add(Context.PathToFiles);
		Call.Add(False);
		Calls.Add(Call);
		BeginRequestingUserPermission(New NotifyDescription(
			"SaveDataWithSignatureAfterGettingPermission", ThisObject, Context), Calls);
	Else
		SaveDataWithSignatureAfterGettingPermission(False, Context);
	EndIf;
	
EndProcedure

// Continue the DigitalSignatureClient procedure.SaveDataWithSignature.
Procedure SaveDataWithSignatureAfterGettingPermission(PermissionsReceived, Context) Export
	
	If PermissionsReceived Then
		BeginGettingFiles(New NotifyDescription(
				"SaveDataWithSignatureAfterGettingFiles", ThisObject, Context),
			Context.FilesToReceive, Context.PathToFiles, False);
	Else
		SaveDataWithSignatureAfterGettingFiles(Undefined, Context);
	EndIf;
	
EndProcedure

// Continue the DigitalSignatureClient procedure.SaveDataWithSignature.
Procedure SaveDataWithSignatureAfterGettingFiles(ReceivedFiles, Context) Export
	
	ReceivedFilesNames = New Map;
	ReceivedFilesNames.Insert(Context.DataFileNameContent.Name, True);
	
	If TypeOf(ReceivedFiles) = Type("Array") Then
		For Each ReceivedFile IN ReceivedFiles Do
			SignatureFileNameContent = CommonUseClientServer.SplitFullFileName(ReceivedFile.Name);
			ReceivedFilesNames.Insert(SignatureFileNameContent.Name, True);
		EndDo;
	EndIf;
	
	Text = NStr("en='Folder with files:';ru='Папка с файлами:'") + Chars.LF;
	Text = Text + Context.PathToFiles;
	Text = Text + Chars.LF + Chars.LF;
	
	Text = Text + NStr("en='Files:';ru='Файлы:'") + Chars.LF;
	
	For Each KeyAndValue IN ReceivedFilesNames Do
		Text = Text + KeyAndValue.Key + Chars.LF;
	EndDo;
	
	FormParameters = New Structure;
	FormParameters.Insert("Text", Text);
	FormParameters.Insert("FolderWithFiles", Context.DataFileNameContent.Path);
	
	OpenForm("CommonForm.DigitalSignatureFilesSavingReport", FormParameters);
	
EndProcedure


// Only for internal use.
Procedure OpenInstructionForWorkWithApplications() Export
	
	Section = "AccountingAndTaxAccounting";
	DigitalSignatureOverridableClient.OnDefineItemSectionOnITS(Section);
	
	If Section = "AccountingInPublicInstitutions" Then
		GotoURL("http://1c-dn.com/1c_enterprise/cryptography/");
	Else
		GotoURL("http://1c-dn.com/1c_enterprise/cryptography/");
	EndIf;
	
EndProcedure


// Shows only the dialog of extension setting to work with digital signature and encryption.
//
// Parameters:
//   WithoutQuestion           - Boolean - if True is specified, then the question will not be shown.
//                                   It is required if a user clicked the Set extension button.
//
//   ResultHandler - NotifyDescription - Description of the procedure receiving selection result.
//   QuestionText         - String - Question text.
//   QuestionTitle     - String - Question title.
//
// Value of a first parameter returnd to the called code handler:
//   ExtensionSet
//       * True - User confirmed setting, after the setting extension was successfully connected.
//       *False   - A user confirmed the installation, however after the installation extension failed to be connected.
//       * Undefined - User refused setting.
//
Procedure SetExtension(WithoutQuestion, ResultHandler = Undefined, QuestionText = "", QuestionTitle = "") Export
	
	Context = New Structure;
	Context.Insert("Notification",       ResultHandler);
	Context.Insert("QuestionText",     QuestionText);
	Context.Insert("QuestionTitle", QuestionTitle);
	Context.Insert("WithoutQuestion",       WithoutQuestion);
	
	BeginAttachingCryptoExtension(New NotifyDescription(
		"SetExtensionAfterWorkWithCryptographyExtansionConnectionCheck", ThisObject, Context));
	
EndProcedure

// Continue the SetExtension procedure.
Procedure SetExtensionAfterWorkWithCryptographyExtansionConnectionCheck(Attached, Context) Export
	
	If Attached Then
		ExecuteNotifyProcessing(Context.Notification, True);
		Return;
	EndIf;
	
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(
		New NotifyDescription("SetExtensionAfterFileOperationsExtensionConnection", ThisObject, Context),
		NStr("en='Before you set decryption to work with a digital
		|signature and encrytion you should set an extension to work with files.';ru='Перед установкой расширения для работы
		|с электронной подписью и шифрованием необходимо установить расширение для работы с файлами.'"),
		False);
	
EndProcedure

// Continue the SetExtension procedure.
Procedure SetExtensionAfterFileOperationsExtensionConnection(Attached, Context) Export
	
	If Not Attached Then
		If Context.Notification <> Undefined Then
			ExecuteNotifyProcessing(Context.Notification, False);
		EndIf;
		Return;
	EndIf;
	
	BeginAttachingCryptoExtension(New NotifyDescription(
		"SetExtensionAfterWorkWithCryptographyExtensionConnection", ThisObject, Context));
	
EndProcedure

// Continue the SetExtension procedure.
Procedure SetExtensionAfterWorkWithCryptographyExtensionConnection(Attached, Context) Export
	
	If Attached Then
		If Context.Notification <> Undefined Then
			ExecuteNotifyProcessing(Context.Notification, True);
		EndIf;
		Return;
	EndIf;
	
	Handler = New NotifyDescription("SetExtensionAfterReply", ThisObject, Context);
	
	If Context.WithoutQuestion Then
		ExecuteNotifyProcessing(Handler, DialogReturnCode.Yes);
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("QuestionTitle", Context.QuestionTitle);
	FormParameters.Insert("QuestionText",     Context.QuestionText);
	
	OpenForm("CommonForm.QuestionOnWorkWithCryptographyExtensionInstallation",
		FormParameters,,,,, Handler);
	
EndProcedure

// Continue the SetExtension procedure.
Procedure SetExtensionAfterReply(Response, Context) Export
	
	If Response = DialogReturnCode.Yes Then
		BeginInstallCryptoExtension(New NotifyDescription(
			"SetExtensionAfterWorkWithCryptographyExtensionSetting", ThisObject, Context));
	Else
		If Context.Notification <> Undefined Then
			ExecuteNotifyProcessing(Context.Notification, Undefined);
		EndIf;
	EndIf;
	
EndProcedure

// Continue the SetExtension procedure.
Procedure SetExtensionAfterWorkWithCryptographyExtensionSetting(Context) Export
	
	BeginAttachingCryptoExtension(New NotifyDescription(
		"SetExtensionAfterConnectionInstalledWorkWithCryptographyExpansion", ThisObject, Context));
	
EndProcedure

// Continue the SetExtension procedure.
Procedure SetExtensionAfterConnectionInstalledWorkWithCryptographyExpansion(Attached, Context) Export
	
	If Attached Then
		Notify("Set_ExpandedWorkWithCryptography");
	EndIf;
	
	If Context.Notification <> Undefined Then
		ExecuteNotifyProcessing(Context.Notification, Attached);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions of the managed forms.

// Only for internal use.
Procedure ContinueOpenBeginning(Notification, Form, ClientParameters, Encryption = False, Details = False) Export
	
	If Not Encryption Then
		InputParameters = Undefined;
		ClientParameters.DataDescription.Property("AdditionalActionsParameters", InputParameters);
		Output_Parameters = Form.WeekendsAdditionalActionsParameters;
		Form.WeekendsAdditionalActionsParameters = Undefined;
		DigitalSignatureOverridableClient.BeforeOperationBeginning(
			?(Details, "Details", "Signing"), InputParameters, Output_Parameters);
	EndIf;
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("ErrorOnServer", New Structure);
	
	If DigitalSignatureClientServer.CommonSettings().CreateDigitalSignaturesAtServer Then
		If Not ValueIsFilled(Form.CryptoManagerAtServerErrorDescription) Then
			ExecuteNotifyProcessing(Notification, True);
			Return;
		EndIf;
		Context.ErrorOnServer = Form.CryptoManagerAtServerErrorDescription;
	EndIf;
	
	CreateCryptoManager(New NotifyDescription(
			"ContinueOpenBeginningAfterCreatingCryptographyManager", ThisObject, Context),
		"GetCertificates", Undefined);
	
EndProcedure

// Continue the ContinueOpenBegin procedure.
Procedure ContinueOpenBeginningAfterCreatingCryptographyManager(Result, Context) Export
	
	If TypeOf(Result) <> Type("CryptoManager") Then
		
		ShowRequestToApplicationError(
			NStr("en='Digital signature and encryption application is required';ru='Требуется программа электронной подписи и шифрования'"),
			"", Result, Context.ErrorOnServer);
		
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, True);
	
EndProcedure


// Only for internal use.
Procedure GetCertificatePrintsAtClient(Notification) Export
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	
	CreateCryptoManager(New NotifyDescription(
			"GetCertificateThumbprintsOnClientAfterCreatingCryptographyManager", ThisObject, Context),
		"GetCertificates", False);
	
EndProcedure

// Continue the GetCertificateThumbprintsOnClient procedure.
Procedure GetCertificateThumbprintsOnClientAfterCreatingCryptographyManager(CryptoManager, Context) Export
	
	If TypeOf(CryptoManager) <> Type("CryptoManager") Then
		ExecuteNotifyProcessing(Context.Notification, New Array);
		Return;
	EndIf;
	
	CryptoManager.StartGettingCertificatesStorage(
		New NotifyDescription(
			"GetCertificateThumbprintsOnClientAfterReceivingStorage", ThisObject, Context),
		CryptoCertificateStoreType.PersonalCertificates);
	
EndProcedure

// Continue the GetCertificateThumbprintsOnClient procedure.
Procedure GetCertificateThumbprintsOnClientAfterReceivingStorage(StorageOfCertificates, Context) Export
	
	StorageOfCertificates.StartGetAll(New NotifyDescription(
		"GetCertificateThumbprintsOnClientAfterReceivingAll", ThisObject, Context));
	
EndProcedure

// Continue the GetCertificateThumbprintsOnClient procedure.
Procedure GetCertificateThumbprintsOnClientAfterReceivingAll(CertificatesArray, Context) Export
	
	CertificateThumbprintsAtClient = New Array;
	
	DigitalSignatureServiceClientServer.AddCertificatesPrints(
		CertificateThumbprintsAtClient, CertificatesArray);
	
	ExecuteNotifyProcessing(Context.Notification, CertificateThumbprintsAtClient);
	
EndProcedure


// Only for internal use.
Procedure ProcessPasswordInForm(Form, InternalData, PasswordProperties, AdditionalParameters = Undefined, NewPassword = Null) Export
	
	If TypeOf(PasswordProperties) <> Type("Structure") Then
		PasswordProperties = New Structure;
		PasswordProperties.Insert("Value", Undefined);
		PasswordProperties.Insert("PasswordExplanationsProcessing", Undefined);
		// The PasswordCheck property allows remembering without check.
		// Enabled when NewPassword is specified and after successful operation. 
		PasswordProperties.Insert("PasswordChecked", False);
	EndIf;
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Structure;
	EndIf;
	
	AdditionalParameters.Insert("Certificate", Form.Certificate);
	AdditionalParameters.Insert("EnhancedProtectionPrivateKey",
		Form.CertificateEnhancedProtectionPrivateKey);
	
	If Not AdditionalParameters.Property("WhenInstallingPasswordFromOtherOperation") Then
		AdditionalParameters.Insert("WhenInstallingPasswordFromOtherOperation", False);
	EndIf;

	If Not AdditionalParameters.Property("WhenChangingAttributePassword") Then
		AdditionalParameters.Insert("WhenChangingAttributePassword", False);
	EndIf;
	
	If Not AdditionalParameters.Property("WhenChangingAttributeRememberPassword") Then
		AdditionalParameters.Insert("WhenChangingAttributeRememberPassword", False);
	EndIf;
	
	If Not AdditionalParameters.Property("WhenOperationIsSuccessful") Then
		AdditionalParameters.Insert("WhenOperationIsSuccessful", False);
	EndIf;
	
	If Not AdditionalParameters.Property("WhenChangingCertificateProperties") Then
		AdditionalParameters.Insert("WhenChangingCertificateProperties", False);
	EndIf;
	
	AdditionalParameters.Insert("PasswordInMemory", False);
	AdditionalParameters.Insert("PasswordIsSetApplicationmatically", False);
	AdditionalParameters.Insert("PasswordExplanation");
	
	ProcessPassword(InternalData, Form.Password, PasswordProperties, Form.RememberPassword,
		AdditionalParameters, NewPassword);
	
	Items = Form.Items;
	
	If Items.Find("Pages") = Undefined
	 Or Items.Find("PageExplanationEnhancedPassword") = Undefined
	 Or Items.Find("PagePasswordRemembering") = Undefined Then
		
		Return;
	EndIf;
	
	If AdditionalParameters.EnhancedProtectionPrivateKey Then
		Items.PasswordTitle.Enabled = False;
		Items.Password.Enabled = False;
		Items.Pages.CurrentPage = Items.PageExplanationEnhancedPassword;
	Else
		Items.PasswordTitle.Enabled = True;
		
		If AdditionalParameters.PasswordIsSetApplicationmatically Then
			Items.Pages.CurrentPage = Items.PageExplanationSetPassword;
			PasswordExplanation = AdditionalParameters.PasswordExplanation;
			Items.ExplanationSetPassword.Title   = PasswordExplanation.ExplanationText;
			Items.ExplanationSetPassword.Hyperlink = PasswordExplanation.ExplanationHyperlink;
			Items.ExplanationSetPasswordExtendedTooltip.Title = PasswordExplanation.ToolTipText;
			PasswordProperties.PasswordExplanationsProcessing = PasswordExplanation.ActionProcessing;
			Items.Password.Enabled = True;
		Else
			Items.Pages.CurrentPage = Items.PagePasswordRemembering;
			Items.Password.Enabled = Not AdditionalParameters.PasswordInMemory;
		EndIf;
	EndIf;
	
	AdditionalParameters.Insert("PasswordSpecified",
		    AdditionalParameters.PasswordIsSetApplicationmatically
		Or AdditionalParameters.PasswordInMemory
		Or AdditionalParameters.WhenInstallingPasswordFromOtherOperation);
	
EndProcedure

// Only for internal use.
Procedure ExplanationSetPasswordClick(Form, Item, PasswordProperties) Export
	
	If TypeOf(PasswordProperties.PasswordExplanationsProcessing) = Type("NotifyDescription") Then
		Result = New Structure;
		Result.Insert("Certificate", Form.Certificate);
		Result.Insert("Action", "ClickExplanation");
		ExecuteNotifyProcessing(PasswordProperties.PasswordExplanationsProcessing, Result);
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure SetPasswordExplanationNavigationRefProcessing(Form, Item, URL,
			StandardProcessing, PasswordProperties) Export
	
	StandardProcessing = False;
	
	If TypeOf(PasswordProperties.PasswordExplanationsProcessing) = Type("NotifyDescription") Then
		Result = New Structure;
		Result.Insert("Certificate", Form.Certificate);
		Result.Insert("Action", URL);
		ExecuteNotifyProcessing(PasswordProperties.PasswordExplanationsProcessing, Result);
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure DataPresentationClick(Form, Item, StandardProcessing, CurrentPresentationsList) Export
	
	StandardProcessing = False;
	
	If CurrentPresentationsList.Count() > 1 Then
		FormParameters = New Structure;
		FormParameters.Insert("ListDataPresentations", CurrentPresentationsList);
		FormParameters.Insert("DataPresentation", Form.DataPresentation);
		OpenForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.DataView",
			FormParameters, Item);
	Else
		ShowValue(, CurrentPresentationsList[0].Value);
	EndIf;
	
EndProcedure

// Only for internal use.
Function FullDataPresentation(Form) Export
	
	Items = Form.Items;
	
	If Items.DataPresentation.TitleLocation <> FormItemTitleLocation.None
	   AND ValueIsFilled(Items.DataPresentation.Title) Then
	
		Return Items.DataPresentation.Title + ": " + Form.DataPresentation;
	Else
		Return Form.DataPresentation;
	EndIf;
	
EndFunction

// Only for internal use.
Procedure CertificatePickFromChoiceList(Form, Text, ChoiceData, StandardProcessing) Export
	
	If Text = "" AND Form.CertificateChoiceList.Count() = 0 Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	ChoiceData = New ValueList;
	
	For Each ItemOfList IN Form.CertificateChoiceList Do
		If Find(Upper(ItemOfList.Presentation), Upper(Text)) > 0 Then
			ChoiceData.Add(ItemOfList.Value, ItemOfList.Presentation);
		EndIf;
	EndDo;
	
EndProcedure


// Only for internal use.
Procedure ExecuteOnSide(Notification, Operation, ExecutionSide, ExecuteParameters) Export
	
	Context = New Structure("DataDescription, Form, FormID, PasswordValue");
	FillPropertyValues(Context, ExecuteParameters);
	
	Context.Insert("Notification",       Notification);
	Context.Insert("Operation",         Operation); // Signing, Encryption, Decryption.
	Context.Insert("OnClientSide", ExecutionSide = "OnClientSide");
	
	If Context.OnClientSide Then
		CreateCryptoManager(New NotifyDescription(
				"ExecuteOnSideAfterCryptographyManagerCreation", ThisObject, Context),
			Null, Undefined, Context.Form.CertificateApplication);
	Else
		ExecuteOnSideCycleLaunch(Context);
	EndIf;
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideAfterCryptographyManagerCreation(Result, Context) Export
	
	If TypeOf(Result) <> Type("CryptoManager") Then
		ExecuteNotifyProcessing(Context.Notification, New Structure("Error", Result));
		Return;
	EndIf;
	Context.Insert("CryptoManager", Result);
	
	GetCertificateByImprint(New NotifyDescription(
			"ExecuteOnSideAfterCertificateSearch", ThisObject, Context),
		Context.Form.CertificateThumbprint, True, Undefined, Context.Form.CertificateApplication);
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideAfterCertificateSearch(Result, Context) Export
	
	If TypeOf(Result) <> Type("CryptoCertificate") Then
		ExecuteNotifyProcessing(Context.Notification, Result);
		Return;
	EndIf;
	Context.Insert("CryptoCertificate", Result);
	
	If Context.Operation = "Signing" Then
		Context.CryptoManager.PrivateKeyAccessPassword = Context.PasswordValue;
		Context.Delete("PasswordValue");
		Context.CryptoCertificate.BeginUnloading(New NotifyDescription(
			"ExecuteOnSideAfterCertificateExport", ThisObject, Context));
		
	ElsIf Context.Operation = "Encryption" Then
		CertificatesProperties = Context.DataDescription.EncryptionCertificates;
		If TypeOf(CertificatesProperties) = Type("String") Then
			CertificatesProperties = GetFromTempStorage(CertificatesProperties);
		EndIf;
		Context.Insert("IndexOf", -1);
		Context.Insert("CertificatesProperties", CertificatesProperties);
		Context.Insert("EncryptionCertificates", New Array);
		ExecuteOnSideCertificatesPreparationCycleBegin(Context);
		Return;
	Else
		Context.CryptoManager.PrivateKeyAccessPassword = Context.PasswordValue;
		Context.Delete("PasswordValue");
		ExecuteOnSideCycleLaunch(Context);
	EndIf;
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideCertificatesPreparationCycleBegin(Context)
	
	If Context.CertificatesProperties.Count() <= Context.IndexOf + 1 Then
		ExecuteOnSideCycleLaunch(Context);
		Return;
	EndIf;
	Context.IndexOf = Context.IndexOf + 1;
	
	CryptoCertificate = New CryptoCertificate;
	CryptoCertificate.BeginInitialization(New NotifyDescription(
			"ExecuteOnSideCertificatesPreparationAfterCertificateInitialization", ThisObject, Context),
		Context.CertificatesProperties[Context.IndexOf].Certificate);
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideCertificatesPreparationAfterCertificateInitialization(CryptoCertificate, Context) Export
	
	Context.EncryptionCertificates.Add(CryptoCertificate);
	
	ExecuteOnSideCertificatesPreparationCycleBegin(Context);
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideAfterCertificateExport(ExportedData, Context) Export
	
	Context.Insert("CertificateProperties", DigitalSignatureClientServer.FillCertificateStructure(
		Context.CryptoCertificate));
	Context.CertificateProperties.Insert("BinaryData", ExportedData);
	
	ExecuteOnSideCycleLaunch(Context);
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideCycleLaunch(Context)
	
	Context.Insert("OperationBegan", False);
	
	If Context.DataDescription.Property("Data") Then
		DataItems = New Array;
		DataItems.Add(Context.DataDescription);
	Else
		DataItems = Context.DataDescription.DataSet;
	EndIf;
	
	Context.Insert("DataItems", DataItems);
	Context.Insert("IndexOf", -1);
	
	ExecuteOnSideCycleBegin(Context);
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideCycleBegin(Context)
	
	If Context.DataItems.Count() <= Context.IndexOf + 1 Then
		ExecuteOnSideAfterCycle(Undefined, Context);
		Return;
	EndIf;
	Context.IndexOf = Context.IndexOf + 1;
	Context.Insert("DataItem", Context.DataItems[Context.IndexOf]);
	
	If Not Context.DataDescription.Property("Data") Then
		Context.DataDescription.Insert("CurrentDataSetItem", Context.DataItem);
	EndIf;
	
	If Context.Operation = "Signing"
	   AND Context.DataItem.Property("SignatureProperties")
	 Or Context.Operation = "Encryption"
	   AND Context.DataItem.Property("EncryptedData")
	 Or Context.Operation = "Details"
	   AND Context.DataItem.Property("DecryptedData") Then
		
		ExecuteOnSideCycleBegin(Context);
		Return;
	EndIf;
	
	GetDataFromDataDescription(New NotifyDescription(
			"ExecuteOnSideCycleAfterGettingData", ThisObject, Context),
		Context.Form, Context.DataDescription, Context.DataItem.Data, Context.OnClientSide);
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideCycleAfterGettingData(Result, Context) Export
	
	If TypeOf(Result) = Type("Structure") Then
		Error = New Structure("ErrorDescription",
			DigitalSignatureServiceClientServer.DataReceiveErrorTitle(Context.Operation)
			+ Chars.LF + Result.ErrorDescription);
		ExecuteOnSideAfterCycle(Error, Context);
		Return;
	EndIf;
	Data = Result;
	
	If Context.OnClientSide Then
		CryptoManager = Context.CryptoManager;
		Notification = New NotifyDescription(
			"ExecuteOnSideCycleAfterOperationOnClient", ThisObject, Context,
			"ExecuteOnSideCycleAfterOperationOnClientError", ThisObject);
		
		If Context.Operation = "Signing" Then
			CryptoManager.StartSigning(Notification, Data, Context.CryptoCertificate);
			
		ElsIf Context.Operation = "Encryption" Then
			CryptoManager.StartEncryption(Notification, Data, Context.EncryptionCertificates);
		Else
			CryptoManager.StartDecryption(Notification, Data);
		EndIf;
		
		Return;
	EndIf;
	
	DataForServerItem = New Structure;
	DataForServerItem.Insert("Data", Data);
	
	ParametersForServer = New Structure;
	ParametersForServer.Insert("Operation", Context.Operation);
	ParametersForServer.Insert("FormID",  Context.FormID);
	ParametersForServer.Insert("CertificateApplication", Context.Form.CertificateApplication);
	ParametersForServer.Insert("CertificateThumbprint", Context.Form.CertificateThumbprint);
	ParametersForServer.Insert("DataForServerItem", DataForServerItem);
	
	ErrorOnServer = New Structure;
	ResultAddress = Undefined;
	
	If Context.Operation = "Signing" Then
		ParametersForServer.Insert("Comment",    Context.Form.Comment);
		ParametersForServer.Insert("PasswordValue", Context.PasswordValue);
		
		If Context.DataItem.Property("Object")
		   AND Not TypeOf(Context.DataItem.Object) = Type("NotifyDescription") Then
			
			DataForServerItem.Insert("Object", Context.DataItem.Object);
			
			If Context.DataItem.Property("ObjectVersioning") Then
				DataForServerItem.Property("ObjectVersioning", Context.DataItem.ObjectVersioning);
			EndIf;
		EndIf;
		
	ElsIf Context.Operation = "Encryption" Then
		ParametersForServer.Insert("CertificatesAddress", Context.DataDescription.EncryptionCertificates);
	Else // Decryption.
		ParametersForServer.Insert("PasswordValue", Context.PasswordValue);
	EndIf;
	
	Success = DigitalSignatureServiceServerCall.ExecuteOnServerSide(ParametersForServer,
		ResultAddress, Context.OperationBegan, ErrorOnServer);
	
	If Not Success Then
		ExecuteOnSideAfterCycle(ErrorOnServer, Context);
		
	ElsIf Context.Operation = "Signing" Then
		ExecuteOnSideCycleAfterSigning(ResultAddress, Context);
		
	ElsIf Context.Operation = "Encryption" Then
		ExecuteOnSideCycleAfterEncryption(ResultAddress, Context);
	Else // Decryption.
		ExecuteOnSideCycleAfterDecryption(ResultAddress, Context);
	EndIf;
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideCycleAfterOperationOnClientError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	ErrorOnClient = New Structure("ErrorDescription", BriefErrorDescription(ErrorInfo));
	ErrorOnClient.Insert("Instruction", True);
	
	ExecuteOnSideAfterCycle(ErrorOnClient, Context);
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideCycleAfterOperationOnClient(BinaryData, Context) Export
	
	ErrorDescription = "";
	If Context.Operation = "Signing"
	   AND DigitalSignatureServiceClientServer.EmptySignatureData(BinaryData, ErrorDescription)
	 Or Context.Operation = "Encryption"
	   AND DigitalSignatureServiceClientServer.EmptyEncryptedData(BinaryData, ErrorDescription) Then

		ErrorOnClient = New Structure("ErrorDescription", ErrorDescription);
		ExecuteOnSideAfterCycle(ErrorOnClient, Context);
		Return;
	EndIf;
	
	Context.OperationBegan = True;
	
	If Context.Operation = "Signing" Then
		SignatureProperties = DigitalSignatureServiceClientServer.SignatureProperties(BinaryData,
			Context.CertificateProperties, Context.Form.Comment);
		ExecuteOnSideCycleAfterSigning(SignatureProperties, Context);
		
	ElsIf Context.Operation = "Encryption" Then
		ExecuteOnSideCycleAfterEncryption(BinaryData, Context);
	Else
		ExecuteOnSideCycleAfterDecryption(BinaryData, Context);
	EndIf;
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideCycleAfterSigning(SignatureProperties, Context)
	
	DataItem = Context.DataItem;
	DataItem.Insert("SignatureProperties", SignatureProperties);
	
	If Not DataItem.Property("Object") Then
		ExecuteOnSideCycleBegin(Context);
		Return;
	EndIf;
	
	If TypeOf(DataItem.Object) <> Type("NotifyDescription") Then
		If Context.OnClientSide Then
			ObjectVersioning = Undefined;
			DataItem.Property("ObjectVersioning", ObjectVersioning);
			Try
				DigitalSignatureServiceServerCall.AddSignature(DataItem.Object,
					SignatureProperties, Context.FormID, ObjectVersioning);
			Except
				ErrorInfo = ErrorInfo();
				DataItem.Delete("SignatureProperties");
				ErrorOnClient = New Structure("ErrorDescription",
					NStr("en='An error occurred when writing the signature:';ru='При записи подписи возникла ошибка:'")
					+ Chars.LF + BriefErrorDescription(ErrorInfo));
				ExecuteOnSideAfterCycle(ErrorOnClient, Context);
				Return;
			EndTry;
		EndIf;
		NotifyChanged(DataItem.Object);
		ExecuteOnSideCycleBegin(Context);
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("DataDescription", Context.DataDescription);
	ExecuteParameters.Insert("Notification", New NotifyDescription(
		"ExecuteOnSideCycleAfterWriteSignature", ThisObject, Context));
	
	Try
		ExecuteNotifyProcessing(DataItem.Object, ExecuteParameters);
	Except
		ErrorInfo = ErrorInfo();
		ExecuteOnSideCycleAfterWriteSignature(New Structure("ErrorDescription",
			BriefErrorDescription(ErrorInfo)), Context);
	EndTry;
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideCycleAfterWriteSignature(Result, Context) Export
	
	If Result.Property("ErrorDescription") Then
		Context.DataItem.Delete("SignatureProperties");
		Error = New Structure("ErrorDescription",
			NStr("en='An error occurred when writing the signature:';ru='При записи подписи возникла ошибка:'") + Chars.LF + Result.ErrorDescription);
		ExecuteOnSideAfterCycle(Error, Context);
		Return;
	EndIf;
	
	ExecuteOnSideCycleBegin(Context);
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideCycleAfterEncryption(EncryptedData, Context)
	
	DataItem = Context.DataItem;
	DataItem.Insert("EncryptedData", EncryptedData);
	
	If Not DataItem.Property("ResultPlacement")
	 Or TypeOf(DataItem.ResultPlacement) <> Type("NotifyDescription") Then
		
		ExecuteOnSideCycleBegin(Context);
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("DataDescription", Context.DataDescription);
	ExecuteParameters.Insert("Notification", New NotifyDescription(
		"ExecuteOnSideCycleAfterWriteEncryptedData", ThisObject, Context));
	
	Try
		ExecuteNotifyProcessing(DataItem.ResultPlacement, ExecuteParameters);
	Except
		ErrorInfo = ErrorInfo();
		ExecuteOnSideCycleAfterWriteEncryptedData(New Structure("ErrorDescription",
			BriefErrorDescription(ErrorInfo)), Context);
	EndTry;
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideCycleAfterWriteEncryptedData(Result, Context) Export
	
	If Result.Property("ErrorDescription") Then
		Context.DataItem.Delete("EncryptedData");
		Error = New Structure("ErrorDescription",
			NStr("en='An error occurred when writing encrypted data:';ru='При записи зашифрованных данных возникла ошибка:'")
			+ Chars.LF + Result.ErrorDescription);
		ExecuteOnSideAfterCycle(Error, Context);
		Return;
	EndIf;
	
	ExecuteOnSideCycleBegin(Context);
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideCycleAfterDecryption(DecryptedData, Context)
	
	DataItem = Context.DataItem;
	DataItem.Insert("DecryptedData", DecryptedData);
	
	If Not DataItem.Property("ResultPlacement")
	 Or TypeOf(DataItem.ResultPlacement) <> Type("NotifyDescription") Then
	
		ExecuteOnSideCycleBegin(Context);
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("DataDescription", Context.DataDescription);
	ExecuteParameters.Insert("Notification", New NotifyDescription(
		"ExecuteOnSideCycleAfterWriteDecryptedData", ThisObject, Context));
	
	Try
		ExecuteNotifyProcessing(DataItem.ResultPlacement, ExecuteParameters);
	Except
		ErrorInfo = ErrorInfo();
		ExecuteOnSideCycleAfterWriteEncryptedData(New Structure("ErrorDescription",
			BriefErrorDescription(ErrorInfo)), Context);
	EndTry;
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideCycleAfterWriteDecryptedData(Result, Context) Export
	
	If Result.Property("ErrorDescription") Then
		Context.DataItem.Delete("DecryptedData");
		Error = New Structure("ErrorDescription",
			NStr("en='An error occurred when writing decrypted data:';ru='При записи расшифрованных данных возникла ошибка:'")
			+ Chars.LF + Result.ErrorDescription);
		ExecuteOnSideAfterCycle(Error, Context);
		Return;
	EndIf;
	
	ExecuteOnSideCycleBegin(Context);
	
EndProcedure

// Continue the ExecuteOnSide procedure.
Procedure ExecuteOnSideAfterCycle(Error, Context)
	
	Result = New Structure;
	If Error <> Undefined Then
		Result.Insert("Error", Error);
	EndIf;
	
	If Context.OperationBegan Then
		Result.Insert("OperationBegan");
		
		If Not Result.Property("Error") AND Context.IndexOf > 0 Then
			Result.Insert("ThereAreProcessedDataItems");
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure


// Only for internal use.
Procedure GetDataFromDataDescription(Notification, Form, DataDescription, DataSource, ForClientPart)
	
	Context = New Structure;
	Context.Insert("Form", Form);
	Context.Insert("Notification", Notification);
	Context.Insert("ForClientPart", ForClientPart);
	
	If TypeOf(DataSource) = Type("NotifyDescription") Then
		ExecuteParameters = New Structure;
		ExecuteParameters.Insert("DataDescription", DataDescription);
		ExecuteParameters.Insert("Notification",  New NotifyDescription(
			"GetDataFromDataFromDescriptionContinue", ThisObject, Context));
		
		Try
			ExecuteNotifyProcessing(DataSource, ExecuteParameters);
		Except
			ErrorInfo = ErrorInfo();
			Result = New Structure("ErrorDescription", BriefErrorDescription(ErrorInfo));
		EndTry;
	Else
		GetDataFromDataFromDescriptionContinue(New Structure("Data", DataSource), Context);
	EndIf;
	
EndProcedure

// Continue the GetDataFromDataDescription procedure.
Procedure GetDataFromDataFromDescriptionContinue(Result, Context) Export
	
	If TypeOf(Result) <> Type("Structure")
	 Or Not Result.Property("Data")
	 Or TypeOf(Result.Data) <> Type("BinaryData")
	   AND TypeOf(Result.Data) <> Type("String") Then
		
		If TypeOf(Result) <> Type("Structure") Or Not Result.Property("ErrorDescription") Then
			Error = New Structure("ErrorDescription", NStr("en='Incorrect data type.';ru='Некорректный тип данных.'"));
		Else
			Error = New Structure("ErrorDescription", Result.ErrorDescription);
		EndIf;
		ExecuteNotifyProcessing(Context.Notification, Error);
		Return;
	EndIf;
	
	Data = Result.Data;
	
	If Context.ForClientPart Then
		// Binary data or path to the file is available from the client.
		
		If TypeOf(Data) = Type("BinaryData") Then
			ExecuteNotifyProcessing(Context.Notification, Data);
			
		ElsIf IsTempStorageURL(Data) Then
			Try
				CurrentResult = GetFromTempStorage(Data);
			Except
				ErrorInfo = ErrorInfo();
				CurrentResult = New Structure("ErrorDescription",
					BriefErrorDescription(ErrorInfo));
			EndTry;
			ExecuteNotifyProcessing(Context.Notification, CurrentResult);
			
		Else // File Path
			ExecuteNotifyProcessing(Context.Notification, Data);
		EndIf;
	Else
		// Server side needs binary data address in the temporary storage.
		
		If TypeOf(Data) = Type("BinaryData") Then
			ExecuteNotifyProcessing(Context.Notification,
				PutToTempStorage(Data, Context.Form.UUID));
		
		ElsIf IsTempStorageURL(Data) Then
			ExecuteNotifyProcessing(Context.Notification, Data);
			
		Else // File Path
			FilesToPlace = New Array;
			Try
				FilesToPlace.Add(New TransferableFileDescription(Data));
				BeginPuttingFiles(New NotifyDescription(
						"GetDataFromDataDescriptionEnd", ThisObject, Context,
						"GetDataFromDataDescriptionEndByError", ThisObject),
					FilesToPlace, , False, Context.Form.UUID);
			Except
				ErrorInfo = ErrorInfo();
				CurrentResult = New Structure("ErrorDescription",
					BriefErrorDescription(ErrorInfo));
				ExecuteNotifyProcessing(Context.Notification, CurrentResult);
			EndTry;
		EndIf;
	EndIf;
	
EndProcedure

// Continue the GetDataFromDataDescription procedure.
Procedure GetDataFromDataDescriptionEndByError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	Result = New Structure("ErrorDescription", BriefErrorDescription(ErrorInfo));
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

// Continue the GetDataFromDataDescription procedure.
Procedure GetDataFromDataDescriptionEnd(PlacedFiles, Context) Export
	
	If PlacedFiles = Undefined Or PlacedFiles.Count() = 0 Then
		Result = New Structure("ErrorDescription",
			NStr("en='User canceled data transfer.';ru='Передача данных отменена пользователем.'"));
	Else
		Result = PlacedFiles[0].Location;
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

// Only for internal use.
Procedure ExtendOperationContextStorage(DataDescription) Export
	
	ParameterTransferForm().ExtendOperationContextStorage(DataDescription.OperationContext);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// For procedures SetCertificatePassword, OpenNewForm,
// SelectCertificateForSigningAndDecryption, CheckCatalogCertificate.
//
Function ParameterTransferForm()
	
	ParameterName = "StandardSubsystems.DigitalSignatureAndEncryptionParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Map);
	EndIf;
	
	Form = ApplicationParameters["StandardSubsystems.DigitalSignatureAndEncryptionParameters"].Get("ParameterTransferForm");
	
	If Form = Undefined Then
		Form = OpenForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.ParameterPassage");
		ApplicationParameters["StandardSubsystems.DigitalSignatureAndEncryptionParameters"].Insert("ParameterTransferForm", Form);
	EndIf;
	
	Return Form;
	
EndFunction

// For the ProcessPasswordInForm procedure.
Procedure ProcessPassword(InternalData, AttributePassword, PasswordProperties,
			AttributeRememberPassword, AdditionalParameters, NewPassword = Null)
	
	Certificate = AdditionalParameters.Certificate;
	
	PasswordsStorage = InternalData.Get("PasswordsStorage");
	If PasswordsStorage = Undefined Then
		PasswordsStorage = New Map;
		InternalData.Insert("PasswordsStorage", PasswordsStorage);
	EndIf;
	
	SetPasswords = InternalData.Get("SetPasswords");
	If SetPasswords = Undefined Then
		SetPasswords = New Map;
		InternalData.Insert("SetPasswords", SetPasswords);
		InternalData.Insert("SetPasswordsExplanations", New Map);
	EndIf;
	
	SetPassword = SetPasswords.Get(Certificate);
	AdditionalParameters.Insert("PasswordIsSetApplicationmatically", SetPassword <> Undefined);
	If SetPassword <> Undefined Then
		AdditionalParameters.Insert("PasswordExplanation",
			InternalData.Get("SetPasswordsExplanations").Get(Certificate));
	EndIf;
	
	If AdditionalParameters.EnhancedProtectionPrivateKey Then
		PasswordProperties.Value = "";
		PasswordProperties.PasswordChecked = False;
		AttributePassword = "";
		Value = PasswordsStorage.Get(Certificate);
		If Value <> Undefined Then
			PasswordsStorage.Delete(Certificate);
			Value = Undefined;
		EndIf;
		AdditionalParameters.Insert("PasswordInMemory", False);
		
		Return;
	EndIf;
	
	Password = PasswordsStorage.Get(Certificate);
	AdditionalParameters.Insert("PasswordInMemory", Password <> Undefined);
	
	If AdditionalParameters.WhenInstallingPasswordFromOtherOperation Then
		AttributePassword = ?(PasswordProperties.Value <> "", "****************", "");
		Return;
	EndIf;
	
	If AdditionalParameters.WhenChangingAttributePassword Then
		PasswordProperties.Value = AttributePassword;
		PasswordProperties.PasswordChecked = False;
		AttributePassword = ?(PasswordProperties.Value <> "", "****************", "");
		
		Return;
	EndIf;
	
	If AdditionalParameters.WhenChangingAttributeRememberPassword Then
		If Not AttributeRememberPassword Then
			Value = PasswordsStorage.Get(Certificate);
			If Value <> Undefined Then
				PasswordsStorage.Delete(Certificate);
				Value = Undefined;
			EndIf;
			AdditionalParameters.Insert("PasswordInMemory", False);
			
		ElsIf PasswordProperties.PasswordChecked Then
			PasswordsStorage.Insert(Certificate, PasswordProperties.Value);
			AdditionalParameters.Insert("PasswordInMemory", True);
		EndIf;
		
		Return;
	EndIf;
	
	If AdditionalParameters.WhenOperationIsSuccessful Then
		If AttributeRememberPassword
		   AND Not AdditionalParameters.PasswordIsSetApplicationmatically Then
			
			PasswordsStorage.Insert(Certificate, PasswordProperties.Value);
			AdditionalParameters.Insert("PasswordInMemory", True);
			PasswordProperties.PasswordChecked = True;
		EndIf;
		
		Return;
	EndIf;
	
	If AdditionalParameters.PasswordIsSetApplicationmatically Then
		If NewPassword <> Null Then
			PasswordProperties.Value = String(NewPassword);
		Else
			PasswordProperties.Value = String(SetPassword);
		EndIf;
		PasswordProperties.PasswordChecked = False;
		AttributePassword = ?(PasswordProperties.Value <> "", "****************", "");
		
		Return;
	EndIf;
	
	If NewPassword <> Null Then
		// Set new password to a new certificate.
		If NewPassword <> Undefined Then
			PasswordProperties.Value = String(NewPassword);
			PasswordProperties.PasswordChecked = True;
			NewPassword = "";
			If PasswordsStorage.Get(Certificate) <> Undefined Or AttributeRememberPassword Then
				PasswordsStorage.Insert(Certificate, PasswordProperties.Value);
				AdditionalParameters.Insert("PasswordInMemory", True);
			EndIf;
		ElsIf PasswordsStorage.Get(Certificate) <> Undefined Then
			// Delete a saved password from the storage.
			AttributeRememberPassword = False;
			PasswordsStorage.Delete(Certificate);
			AdditionalParameters.Insert("PasswordInMemory", False);
		EndIf;
		AttributePassword = ?(PasswordProperties.Value <> "", "****************", "");
		
		Return;
	EndIf;
	
	If AdditionalParameters.WhenChangingCertificateProperties Then
		Return;
	EndIf;
	
	// Get password from the storage.
	Value = PasswordsStorage.Get(Certificate);
	AdditionalParameters.Insert("PasswordInMemory", Value <> Undefined);
	AttributeRememberPassword = AdditionalParameters.PasswordInMemory;
	PasswordProperties.Value = String(Value);
	PasswordProperties.PasswordChecked = AdditionalParameters.PasswordInMemory;
	Value = Undefined;
	AttributePassword = ?(PasswordProperties.Value <> "", "****************", "");
	
EndProcedure

// For the SetDataPresentation procedure.
Procedure FillPresentationsList(PresentationsList, DataItem)
	
	ItemOfList = New Structure("Value,Presentation", Undefined, "");
	PresentationsList.Add(ItemOfList);
	
	If DataItem.Property("Presentation")
	   AND TypeOf(DataItem.Presentation) = Type("Structure") Then
		
		FillPropertyValues(ItemOfList, DataItem.Presentation);
		Return;
	EndIf;
	
	If DataItem.Property("Presentation")
	   AND TypeOf(DataItem.Presentation) <> Type("String") Then
	
		ItemOfList.Value = DataItem.Presentation;
		
	ElsIf DataItem.Property("Object")
	        AND TypeOf(DataItem.Object) <> Type("NotifyDescription") Then
		
		ItemOfList.Value = DataItem.Object;
	EndIf;
	
	If DataItem.Property("Presentation") Then
		ItemOfList.Presentation = DataItem.Presentation;
	EndIf;
	
EndProcedure

#EndRegion
