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


// Creates and returns the cryptography manager (on client) for the specified application.
//
// Parameters:
//  Notification     - NotifyDescription - notification about a result of executing the following types.
//                   CryptoManager - initialized cryptography manager.
//                   String - error description while creating a cryptography manager.
//
//  Operation       - String - if it is not empty, it should contain one of
//                   the rows that define the operation to insert into
//                   the description of error: SignatureCheck, Encryption, Decryption, CertificateCheck, ReceiveCertificates.
//
//  ShowError - Boolean - if True, then the ApplicationAccessError form will be opened, form which you can go to the list of installed applications to the form of personal settings in the Installed applications page. There you can see why you did not manage to use the application and also open the installation guide.
//
//  Application      - Undefined - returns the cryptography
//                   manager of the first application from the catalog created for it.
//                 - CatalogRef.DigitalSignatureAndEncryptionApplications - application
//                   for which you need to create and return the cryptography manager.
//
Procedure CreateCryptoManager(Notification, Operation, ShowError = True, Application = Undefined) Export
	
	If TypeOf(Operation) <> Type("String") Then
		Operation = "";
	EndIf;
	
	If ShowError <> True Then
		ShowError = False;
	EndIf;
	
	DigitalSignatureServiceClient.CreateCryptoManager(Notification, Operation, ShowError, Application);
	
EndProcedure

// Signs the data, returns the signature and adds a signature to the object if specified.
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
//    * Operation            - String - title of data signing form, for example, File signing.
//    * DataTitle     - String - title of an item or set of data, for example, File.
//    * TellAboutEnd - Boolean - (optional) - if False, then an alert on successful
//                              operation for data presentation specified near the title will not be shown.
//    * ShowComment - Boolean - (optional) - allows an input
//                              of comment in data signing form. If not specified, then False.
//    * CertificatesFilter  - Array - (optional) - contains references to catalog items.
//                              DigitalSignatureAndEncryptionCertificates
//                              that can be selected by users. The filter locks the possibility
//                              to select other certificates from the personal storage.
//    * WithoutConfirmation   - Boolean - (optional) - skip user confirmation
//                              if there is only one certificate in the FilterCertificates property and:
//                              a) either certificate is issued with a strong
//                              protection of a private key, b)or a user remembered a
//                              password to the certificate at the time of a session, c) or a password was set earlier using the SetCertificatePassword method.
//                              If an error occurred during signing, then the form
//                              with the ability to specify a password will be opened. The ShowComment parameter is ignored.
//    * BeforeExecution   - NotifyDescription - (optional) - description of
//                              an additional data preparation handler after selecting the certificate using which the data will be signed.
//                              IN this handler, you can fill the Data parameter
//                              if it depends on the certificate that at the time
//                              of the call is already inserted into DataDescription, as SelectedCertificate (see below). A common approach should be taken into account (see above).
//    * ExecuteAtServer - Undefined, Boolean - (optional) - when it is
//                              not specified or Undefined, then the execution will be defined
//                              automatically: if there is a server, then first on server and later on client was unsuccessful and then a message about two errors.
//                             When True: if the execution is allowed on server, then the execution is only on server if it fails, one error message on server.
//                              When False: execution is only on the client as if there is no server.
//    * AdditionalActionsParameters - Arbitrary - (optional) - If specified, it
//                              is transferred to the server in the BeforeOperationBeginning procedure of the common module.
//                              DigitalSignaturePredefined as InputParameters.
//    * OperationContext   - Undefined - (optional) - if it is specified, then
//                              a certain value of a custom type
//                              will be set into the property that allows you to
//                              perform an action with that same certificate once again (user is asked neither for a password, nor for action confirmation).
//    * ------//  ------   - Arbitrary - (optional) - if it is defined, then
//                              the action will be executed with the same certificate without password or confirmation.
//                              The WithoutConfirmation parameter is assumed to be True.
//                              Operation, DataTitle, ShowComment,
//                              CertificatesSelection and ExecuteOnServer parameters are ignored, their values remain as during first call.
//                              The AdditionalActionsParameters parameter is ignored.
//                              The BeforeOperationBegin procedure is not called.
//                              If you pass the context returned
//                              by the Decrypt procedure, then the password entered for a
//                              certificate can be used as if the password was saved at the time of the session. Otherwise the context is ignored.
//    Variant 1:
//    *Data                - BinaryData - data for signing.
//    * --  --  //            - String - address of a temporary storage containing binary data.
//    * --  -//-              - NotifyDescription - data receiving handler which
//                                 returns it in the Data property (see above general approach). During the
//                                 call in DataDescription the SelectedCertificate parameter is already inserted (see below).
//    (prohibition is set for the object                - Refs - (optional) - ref to object with the tabular section.
//                                 DigitalSignatures, in which a signature needs to be added.
//                                 If not specified, you are not required to add signatur//e.
//    * --  --              - NotifyDescription - (optional) - handler of adding
//                                 a signature to the tabular section DigitalSignatures. A common approach should be taken into account (see above).
//                                 At the time of call, the SignatureProperties parameter is already inserted into DataDescription.
//                                 IN the case of the DataSet
//                                 parameter, the DataSetCurrentItem is inserted into DataDescription containing the SignatureProperties parameter.
//    * ObjectVersioning         - String - (optional) - version of object data
//                                 to check and lock object before adding a signature.
//    Author presentation         - Ref, String, Structure - (optional), if
//                                 it is not specified, then the presentation is calculated according to value of the Object property.
//                                 Structure contains properties Value and Presentation.
//    Variant 2:
//    * DataSet           - Array - structure with the properties described in Option 1.
//    * SetPresentation   - String - presentations of several items of data set, for example, Files (%1).
//                                 IN this presentation, the %1 parameter is filled out with the quantity of items.
//                                 You can open list by a hyperlink.
//                                 If in the data set there is
//                                 1 item, then a value as a Property presentation
//                                 DataSet is used if not specified, then the presentation is calculated according to the Item object of data set property value.
//    * PresentationsList   - ValuesList, Array - (optional) - random
//                                 list of items or array with values as in
//                                 the Presentation property that a user can open. If it is not specified,
//                                 then it is filled from the Presentation and Object properties in the DataSet property.
//
//  Form - ManagedForm - form, from which you need to receive
//                                a unique identifier that will be used during object locking.
//        - Undefined     - use standard form.
//
//  ResultProcessing - NotifyDescription - optional parameter.
//     It is required for a nonstandard result processing, for example if the Object and/or Form parameter is not specified.
//     The DataDescription input parameter is passed to the result, to which properties are added:
//     * Success - Boolean - True if all succeeded. If Success = False, then
//               partial completion is determined by the availability of the SignatureProperties property. If there is, the step is executed.
//     * SelectedCertificate - Structure - contains certificate properties:
//         * Ref    - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - reference to certificate.
//         * Thumbprint - String - certificate thumbprint in the Base64 row format.
//         *Data    - String - address of a temporary storage containing certificate binary data.
//     * SignatureProperties - String - address of a temporary storage containing structure described below.
//                         When transferring the DataSet parameter, property needs to be checked in it.
//                       - Structure - expanded signature description:
//         * Signature             - BinaryData - signing result.
//         * SetSignature - CatalogRef.Users - a
//                                    user who signed an object of the infobase.
//         * Comment         - String - comment if it was put during signing.
//         * SignatureFileName     - String - empty row as Signature added not from file.
//         * SignatureDate         - Date   - date when the signature was made. This only makes
//                                          sense in case when date can not be extracted from signature data. If
//                                          it is not specified or empty, then the current session date is used.
//         Derived properties:
//         * Certificate          - BinaryData - contains
//                                    export of the certificate that was used for signing (contained in a signature).
//         * Thumbprint           - String - certificate thumbprint in the Base64 row format.
//         * CertificateIsIssuedTo - String - subject presentation received from the certificate binary data.
//
Procedure Sign(DataDescription, Form = Undefined, ResultProcessing = Undefined) Export
	
	ClientParameters = New Structure;
	ClientParameters.Insert("DataDescription", DataDescription);
	ClientParameters.Insert("Form", Form);
	ClientParameters.Insert("ResultProcessing", ResultProcessing);
	
	CompletionProcessing = New NotifyDescription("StandardEnd",
		DigitalSignatureServiceClient, ClientParameters);
	
	If DataDescription.Property("OperationContext")
	   AND TypeOf(DataDescription.OperationContext) = Type("ManagedForm") Then
		
		DigitalSignatureServiceClient.ExtendOperationContextStorage(DataDescription);
		FormNameBegin = "Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.";
		
		If DataDescription.OperationContext.FormName = FormNameBegin + "SigningData" Then
			DataDescription.OperationContext.ExecuteSigning(ClientParameters, CompletionProcessing);
			Return;
		EndIf;
		If DataDescription.OperationContext.FormName = FormNameBegin + "DataDetail" Then
			ClientParameters.Insert("OtherOperationContextIsSpecified");
		EndIf;
	EndIf;
	
	ServerParameters = New Structure;
	ServerParameters.Insert("Operation",            NStr("en='Data signing';ru='Подписание данных'"));
	ServerParameters.Insert("DataTitle",     NStr("en='Data';ru='Данные'"));
	ServerParameters.Insert("ShowComment", False);
	ServerParameters.Insert("FilterCertificates");
	ServerParameters.Insert("PerformAtServer");
	ServerParameters.Insert("AdditionalActionsParameters");
	FillPropertyValues(ServerParameters, DataDescription);
	
	DigitalSignatureServiceClient.OpenNewForm("SigningData",
		ClientParameters, ServerParameters, CompletionProcessing);
	
EndProcedure

// It offers a user to select signature files to add to an object and adds them.
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
//    (prohibition is set for the object             - Refs - (optional) - ref to object with the tabular section.
//                              DigitalSignatures, in which a signature needs to be added.
//    //* --  --           - NotifyDescription - (optional) - handler of adding
//                              a signature to the tabular section DigitalSignatures. A common approach should be taken into account (see above).
//                              At the time of the call, the Signatures parameter has already been inserted into DataDescription.
//    * ObjectVersioning      - String - (optional) - version of object data
//                              to check and lock object before adding a signature.
//    Author presentation      - Ref, Row - (optional), if
//                                it is not specified, then the presentation is calculated according to value of the Object property.
//
//  Form - ManagedForm - form, from which you need to receive
//                                a unique identifier that will be used during object locking.
//        - Undefined     - use standard form.
//
//  ResultProcessing - NotifyDescription - optional parameter.
//     It is required for a nonstandard result processing, for example if the Object and/or Form parameter is not specified.
//     The DataDescription input parameter is passed to the result, to which properties are added:
//     * Success - Boolean - True if all succeeded.
//     * Signatures - Array - which contains items:
//       * SignatureProperties - String - address of a temporary storage containing structure described below.
//                         - Structure - expanded signature description:
//           * Signature             - BinaryData - signing result.
//           * SetSignature - CatalogRef.Users - a
//                                      user who signed an object of the infobase.
//           * Comment         - String - comment if it was put during signing.
//           * SignatureFileName     - String - name of the file, from which the signature is added.
//           * SignatureDate         - Date   - date when the signature was made. This only makes
//                                            sense in case when date can not be extracted from signature data. If
//                                            it is not specified or empty, then the current session date is used.
//           Derived properties:
//           * Certificate          - BinaryData - contains
//                                      export of the certificate that was used for signing (contained in a signature).
//           * Thumbprint           - String - certificate thumbprint in the Base64 row format.
//           * CertificateIsIssuedTo - String - subject presentation received from the certificate binary data.
//
Procedure AddSignatureFromFile(DataDescription, Form = Undefined, ResultProcessing = Undefined) Export
	
	DataDescription.Insert("Success", False);
	
	ServerParameters = New Structure;
	ServerParameters.Insert("DataTitle", NStr("en='Data';ru='Данные'"));
	ServerParameters.Insert("ShowComment", False);
	FillPropertyValues(ServerParameters, DataDescription);
	
	ClientParameters = New Structure;
	ClientParameters.Insert("DataDescription",      DataDescription);
	ClientParameters.Insert("Form",               Form);
	ClientParameters.Insert("ResultProcessing", ResultProcessing);
	DigitalSignatureServiceClient.SetDataPresentation(ClientParameters, ServerParameters);
	
	Handler = New NotifyDescription("StandardEnd",
		DigitalSignatureServiceClient, ClientParameters);
	
	AddingForm = OpenForm("CommonForm.AddDigitalSignatureFromFile", ServerParameters,,,,, 
		New NotifyDescription("StandardEnd", DigitalSignatureServiceClient, ClientParameters));
	
	If AddingForm = Undefined Then
		If ResultProcessing <> Undefined Then
			ExecuteNotifyProcessing(ResultProcessing, DataDescription);
		EndIf;
		Return;
	EndIf;
	
	AddingForm.ClientParameters = ClientParameters;
	
	CommonSettings = DigitalSignatureClientServer.CommonSettings();
	
	Context = New Structure;
	Context.Insert("ResultProcessing", ResultProcessing);
	Context.Insert("AddingForm", AddingForm);
	Context.Insert("CheckCryptographyManagerOnClient", True);
	Context.Insert("DataDescription", DataDescription);
	
	If (    CommonSettings.VerifyDigitalSignaturesAtServer
	      Or CommonSettings.CreateDigitalSignaturesAtServer)
	   AND Not ValueIsFilled(AddingForm.CryptoManagerAtServerErrorDescription) Then
		
		Context.CheckCryptographyManagerOnClient = False;
		DigitalSignatureServiceClient.AddSignatureFromFileAfterCreatingCryptographyManager(, Context);
	Else
		DigitalSignatureServiceClient.CreateCryptoManager(New NotifyDescription(
				"AddSignatureFromFileAfterCreatingCryptographyManager",
				DigitalSignatureServiceClient, Context),
			"", Undefined);
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
//                              the DigitalSignature tabular section, from which you should receive a users list.
// //   * --  --           - String - address of a temporary storage of the
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
	
	DigitalSignatureServiceClient.SaveDataWithSignature(DataDescription, ResultProcessing);
	
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
	
	DigitalSignatureServiceClient.VerifySignature(Notification, SourceData, Signature, CryptoManager);
	
EndProcedure

// Encrypts data, returns the encryption certificates and adds their object if specified.
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
//    * Operation           - String - title of data encryption form, for example, File encryption.
//    * DataTitle    - String - title of an item or set of data, for example, File.
//    * TellAboutEnd - Boolean - (optional) - if False, then an alert on successful
//                              operation for data presentation specified near the title will not be shown.
//    * CertificatesSet  - String - (optional) address of a temporary storage containing an array described below.
//                         - Array - (optional)
//                              contains values of
//                              the CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates type or the BinaryData type (export certificate).
//                         - Refs - (optional) - ref to an object
//                              with the EncryptionCertificates tabular section, from which they need to be received.
//    * ChangeSet      - Boolean - if True and CertificatesSet is set and contains
//                              only refs to certificates, then you will be able to change the content of certificates.
//    * WithoutConfirmation   - Boolean - (optional) - skip user
//                              confirmation if the CertificatesFilter property is specified.
//    * ExecuteAtServer - Undefined, Boolean - (optional) - when it is
//                              not specified or Undefined, then the execution will be defined
//                              automatically: if there is a server, then first on server and later on client was unsuccessful and then a message about two errors.
//                              When True: if the execution is allowed on server, then the execution is only on server if it fails, one error message on server.

//                              When False: execution is only on the client as if there is no server.
//    * OperationContext   - Undefined - (optional) - if it is specified, then
//                              a certain value of a custom type
//                              will be set into the property that allows you to
//                              perform an action with that same encryption certificates once again (user is asked to confirm an action).
//    * ------  ------  // - Arbitrary - (optional) - if it is defined, then
//                              the action will be complete with the same encryption certificates.
//                              The WithoutConfirmation parameter is assumed to be True.
//                              Operation, DataTitle, CertificatesSet,
//                              ChangeSet and ExecuteOnServer parameters are ignored, their values remain as during first call.
//
//    Variant 1:
//    *Data                - BinaryData - data for encryption.
//    * --  -//-              - String - address of a temporary storage containing binary data.
//    * --  -//-              - NotifyDescription - data receiving handler which
//                                 returns it in the Data property (see above general approach).
//    * ResultPlacement  - Undefined - (optional) - describes where to put the encrypted data.
//                                 If it is not specified or Undefined, then using the ResultProcessing parameter.
//    * --//  --               - NotifyDescription - handler of encrypted data saving.
//                                 A common approach should be taken into account (see above).
//                                 At the time of call, the EncryptedData parameter is already inserted into DataDescription.
//                                 IN the case of the DataSet
//                                 parameter, the DataSetCurrentItem is inserted into DataDescription containing the EncryptedData parameter.
//    (prohibition is set for the object                - Refs - (optional) - ref to object with the tabular section.
//                                 EncryptionCertificates, to which you need to add them after encryption.
//                                 If it is not specified, then the encryption certificates are not required to be added.
//    * ObjectVersioning         - String - (optional) - version of the object data
//                                 to check and lock object before adding encryption certificates.
//    Author presentation         - Ref, String, Structure - (optional), if
//                                 it is not specified, then the presentation is calculated according to value of the Object property.
//                                 Structure contains properties Value and Presentation.
//    Variant 2:
//    * DataSet           - Array - structure with the properties described in Option 1.
//    * SetPresentation   - String - presentations of several items of data set, for example, Files (%1).
//                                 IN this presentation, the %1 parameter is filled out with the quantity of items.
//                                 You can open list by a hyperlink.
//                                 If in the data set there is
//                                 1 item, then a value as a Property presentation
//                                 DataSet is used if not specified, then the presentation is calculated according to the Item object of data set property value.
//    * PresentationsList   - ValuesList, Array - (optional) - random
//                                 list of items or array with values as in
//                                 the Presentation property that a user can open. If it is not specified,
//                                 then it is filled from the Presentation and Object properties in the DataSet property.
//
//  Form - ManagedForm  - form, from which a unique identifier should
//                                be received that will be used during putting encrypted data into a temporary storage.
//        - Undefined      - use standard form.
//
//  ResultProcessing - NotifyDescription - optional parameter.
//     It is required for nonstandard result processing if the Form or ResultPlacement parameter is not specified.
//     The DataDescription input parameter is passed to the result, to which properties are added:
//     * Success - Boolean - True if all succeeded. If Success = False, then
//               a partial completion is defined by the presence of the EncryptedData property. If there is, the step is executed.
//     * DecryptionCertificates - String - address of a temporary storage containing an array described below.
//                             - Array - it is placed before encryption and is not changed after that.
//                                 Contains values of the Structure type with properties:
//                                 * Thumbprint     - String - certificate thumbprint in the Base64 row format.
//                                 * Presentation String - saved subject
//                                                      presentation received from the certificate binary data.
//                                 * Certificate    - BinaryData - contains
//                                                      export of a certificate used for encryption
//     * EncryptedData - BinaryData - encryption result.
//                             When transferring the DataSet parameter, property needs to be checked in it.
//                           - String - address of a temporary storage containing the encryption result.
//
Procedure Encrypt(DataDescription, Form = Undefined, ResultProcessing = Undefined) Export
	
	ClientParameters = New Structure;
	ClientParameters.Insert("DataDescription", DataDescription);
	ClientParameters.Insert("Form", Form);
	ClientParameters.Insert("ResultProcessing", ResultProcessing);
	
	CompletionProcessing = New NotifyDescription("StandardEnd",
		DigitalSignatureServiceClient, ClientParameters);
	
	If DataDescription.Property("OperationContext")
	   AND TypeOf(DataDescription.OperationContext) = Type("ManagedForm") Then
		
		DigitalSignatureServiceClient.ExtendOperationContextStorage(DataDescription);
		FormNameBegin = "Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.";
		
		If DataDescription.OperationContext.FormName = FormNameBegin + "DataEncryption" Then
			DataDescription.OperationContext.ExecuteEncryption(ClientParameters, CompletionProcessing);
			Return;
		EndIf;
	EndIf;
	
	ServerParameters = New Structure;
	ServerParameters.Insert("Operation",            NStr("en='Data encryption';ru='Шифрование данных'"));
	ServerParameters.Insert("DataTitle",     NStr("en='Data';ru='Данные'"));
	ServerParameters.Insert("CertificatesSet");
	ServerParameters.Insert("ChangeSet");
	ServerParameters.Insert("PerformAtServer");
	FillPropertyValues(ServerParameters, DataDescription);
	
	DigitalSignatureServiceClient.OpenNewForm("DataEncryption",
		ClientParameters, ServerParameters, CompletionProcessing);
	
EndProcedure

// Decrypts data, returns it, and puts into the object if specified.
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
//    * Operation           - String - title of data details form, for example, file detail.
//    * DataTitle    - String - title of an item or set of data, for example, File.
//    * TellAboutEnd - Boolean - (optional) - if False, then an alert on successful
//                              operation for data presentation specified near the title will not be shown.
//    * CertificatesFilter  - Array - (optional) - contains references to catalog items.
//                              DigitalSignatureAndEncryptionCertificates
//                              that can be selected by users. The filter locks the possibility
//                              to select other certificates from the personal storage.
//    * WithoutConfirmation   - Boolean - (optional) - skip user confirmation
//                              if there is only one certificate in the FilterCertificates property and:
//                              a) either certificate is issued with a strong
//                              protection of a private key, b)or a user remembered a
//                              password to the certificate at the time of a session, c) or a password was set earlier using the SetCertificatePassword method.
//                              If an error occurred during decryption, then the form
//                              with the ability to specify a password will be opened.
//    * IsAuthentication  - Boolean - (optional) - if True is specified, then instead
//                              of the Decrypt button the OK button will be shown. Also some labels are corrected.
//                              IN addition, the AlertAboutCompletion parameter is set to False.
//    * BeforeExecution   - NotifyDescription - (optional) - description of
//                              an additional data preparation handler after selecting the certificate using which the data will be decrypted.
//                              IN this handler you can fill the Data parameter if it is required.
//                              During the call in the DataDescription the selected
//                              certificate is already  as SelectedCertificate (see below). A common approach should be taken into account (see above).
//    * ExecuteAtServer - Undefined, Boolean - (optional) - when it is
//                              not specified or Undefined, then the execution will be defined
//                              automatically: if there is a server, then first on server and later on client was unsuccessful and then a message about two errors.
//                              When True: if the execution is allowed on server, then the execution is only on server if it fails, one error message on server.

//                              When False: execution is only on the client as if there is no server.
//    * AdditionalActionsParameters - Arbitrary - (optional) - If specified, it
//                              is transferred to the server in the BeforeOperationBeginning procedure of the common module.
//                              DigitalSignaturePredefined as InputParameters.
//    * OperationContext   - Undefined - (optional) - if it is specified, then
//                              a certain value of a custom type
//                              will be set into the property that allows you to
//                              perform an action with that same certificate once again (user is asked neither for a password, nor for action confirmation).
//    * ------//  ------   - Arbitrary - (optional) - if it is defined, then
//                              the action will be executed with the same certificate without password or confirmation.
//                              The WithoutConfirmation parameter is assumed to be True.
//                              Operation, DataTitle, CertificatesSelection,
//                              IsAuthentification and ExecuteOnServer parameters are ignored, their values remain as during first call.
//                              The AdditionalActionsParameters parameter is ignored.
//                              The BeforeOperationBegin procedure is not called.
//                              If you pass the context returned
//                              by the Sign procedure, then the password entered for a
//                              certificate can be used as if the password was saved at the time of the session. Otherwise the context is ignored.
// 
//    Variant 1:
//    *Data                - BinaryData - data for decryption.
//    * --  --//              - String - address of a temporary storage containing binary data.
//    * --  -//-              - NotifyDescription - data receiving handler which
//                                 returns it in the Data property (see above general approach). During the
//                                 call in DataDescription the SelectedCertificate parameter is already inserted (see below).
//    * ResultPlacement  - Undefined - (optional) - describes where to put the decrypted data.
//                                 If it is not specified or Undefined, then using the ResultProcessing parameter.
//    * -- // --              - NotifyDescription - handler of decrypted data saving.
//                                 A common approach should be taken into account (see above).
//                                 At the time of call, the DecryptedData parameter is already inserted into DataDescription.
//                                 IN the case of the DataSet
//                                 parameter, the DataSetCurrentItem is inserted into DataDescription containing the DecryptedData parameter.
//    (prohibition is set for the object                - Refs - (optional) - ref to object with the tabular section.
//                                 EncryptionCertificates, from
//                                 which you need to obtain certificates and also clear after a successful decryption completion.
//                                 If it is not specified, then the certificates are not required to be received //from an object and cleared.
//    * --  --              - String - address of a temporary storage
//                                 containing an array of encryption certificates in the form of structures with properties:
//                                 * Thumbprint     - String - certificate thumbprint in the Base64 row format.
//                                 * Presentation String - saved subject
//                                                      presentation received from the certificate binary data.
//                                 * Certificate    - BinaryData - contains
//                                                      export of a certificate used for encryption
//    Author presentation         - Ref, String, Structure - (optional), if
//                                 it is not specified, then the presentation is calculated according to value of the Object property.
//                                 Structure contains properties Value and Presentation.
//    Variant 2:
//    * DataSet           - Array - structure with the properties described in Option 1.
//    * SetPresentation   - String - presentations of several items of data set, for example, Files (%1).
//                                 IN this presentation, the %1 parameter is filled out with the quantity of items.
//                                 You can open list by a hyperlink.
//                                 If in the data set there is
//                                 1 item, then a value as a Property presentation
//                                 DataSet is used if not specified, then the presentation is calculated according to the Item object of data set property value.
//    * PresentationsList   - ValuesList, Array - (optional) - random
//                                 list of items or array with values as in
//                                 the Presentation property that a user can open. If it is not specified,
//                                 then it is filled from the Presentation and Object properties in the DataSet property.
//    * DecryptionCertificates - Array - (optional) values as the Object parameter has. Used
//                                 to extract encryption certificates lists for items specified
//                                 in the PresentationsList parameter (order should match).
//                                 If specified, the Object parameter is not used.
//
//  Form - ManagedForm  - form, from which a unique identifier should
//                                be received that will be used during putting decrypted data into a temporary storage.
//        - Undefined      - use standard form.
//
//  ResultProcessing - NotifyDescription - optional parameter.
//     It is required for nonstandard result processing if the Form or ResultPlacement parameter is not specified.
//     The DataDescription input parameter is passed to the result, to which properties are added:
//     * Success - Boolean - True if all succeeded. If Success = False, then
//               a partial completion is defined by the presence of the DecryptedData property. If there is, the step is executed.
//     * SelectedCertificate - Structure - contains certificate properties:
//         * Ref    - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - reference to certificate.
//         * Thumbprint - String - certificate thumbprint in the Base64 row format.
//         *Data    - String - address of a temporary storage containing certificate binary data.
//     * DecryptedData - BinaryData - decryption result.
//                              When transferring the DataSet parameter, property needs to be checked in it.
//                            - String - address of a temporary storage containing the decryption result.
//
Procedure Decrypt(DataDescription, Form = Undefined, ResultProcessing = Undefined) Export
	
	ClientParameters = New Structure;
	ClientParameters.Insert("DataDescription", DataDescription);
	ClientParameters.Insert("Form", Form);
	ClientParameters.Insert("ResultProcessing", ResultProcessing);
	
	CompletionProcessing = New NotifyDescription("StandardEnd",
		DigitalSignatureServiceClient, ClientParameters);
	
	If DataDescription.Property("OperationContext")
	   AND TypeOf(DataDescription.OperationContext) = Type("ManagedForm") Then
		
		DigitalSignatureServiceClient.ExtendOperationContextStorage(DataDescription);
		FormNameBegin = "Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.";
		
		If DataDescription.OperationContext.FormName = FormNameBegin + "DataDetail" Then
			DataDescription.OperationContext.ExecuteDecryption(ClientParameters, CompletionProcessing);
			Return;
		EndIf;
		If DataDescription.OperationContext.FormName = FormNameBegin + "SigningData" Then
			ClientParameters.Insert("OtherOperationContextIsSpecified");
		EndIf;
	EndIf;
	
	ServerParameters = New Structure;
	ServerParameters.Insert("Operation",            NStr("en='Data decryption';ru='Расшифровка данных'"));
	ServerParameters.Insert("DataTitle",     NStr("en='Data';ru='Данные'"));
	ServerParameters.Insert("FilterCertificates");
	ServerParameters.Insert("EncryptionCertificates");
	ServerParameters.Insert("ItIsAuthentication");
	ServerParameters.Insert("PerformAtServer");
	ServerParameters.Insert("AdditionalActionsParameters");
	ServerParameters.Insert("EnableRememberPassword");
	FillPropertyValues(ServerParameters, DataDescription);
	
	If DataDescription.Property("Data") Then
		If TypeOf(ServerParameters.EncryptionCertificates) <> Type("Array")
		   AND DataDescription.Property("Object") Then
			
			ServerParameters.Insert("EncryptionCertificates", DataDescription.Object);
		EndIf;
		
	ElsIf TypeOf(ServerParameters.EncryptionCertificates) <> Type("Array") Then
		
		ServerParameters.Insert("EncryptionCertificates", New Array);
		For Each DataItem IN DataDescription.DataSet Do
			If DataItem.Property("Object") Then
				ServerParameters.EncryptionCertificates.Add(DataItem.Object);
			Else
				ServerParameters.EncryptionCertificates.Add(Undefined);
			EndIf;
		EndDo;
	EndIf;
	
	DigitalSignatureServiceClient.OpenNewForm("DataDetail",
		ClientParameters, ServerParameters, CompletionProcessing);
	
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
//                          cryptography manager (check on server will not be executed).
//
Procedure CheckCertificate(Notification, Certificate, CryptoManager = Undefined) Export
	
	DigitalSignatureServiceClient.CheckCertificate(Notification, Certificate, CryptoManager);
	
EndProcedure

// Opens the CheckCertificate form and returns check result.
//
// Parameters:
//  Certificate - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - certificate being checked.
//
//  AdditionalParameters - Undefined - regular certificate checking.
//                          - Structure - with optional properties:
//    * FormOwner          - ManagedForm - another form.
//    * FormTitle         - String - if it is specified, then it replaces the form title.
//    * CheckOnSelection      - Boolean - if True, then the Check button
//                                  will be called Check and continue and the Close button will be called Cancel.
//    * ResultProcessing    - NotifyDescription - called right after the checking,
//                                 Result.ChecksComplete is transferred to the procedure(see below) with the False initial value.
//                                 If you do not set True
//                                 in the CheckOnSelect mode, then the form will not be closed
//                                 after returning from the alert procedure and a warning that it can not continue will be shown.
//    * WithoutConfirmation       - Boolean - If you set True, then with
//                                  a password a check will be executed immediately without opening a form.
//                                  If there is the CheckOnSelection mode and
//                                  the ResultProcessing parameter is set, then a form will not be opened if there is  the ChecksComplete parameter and True is set.
//    * CompletionProcessing    - NotifyDescription - called during closing of
//                                  a form, the Undefined or the ChecksPassed value is transferred as a result (see below).
//    * Result              - Undefined - checking has never been executed.
//                             - Structure - (return value) - inserted before
//         the result processing, contains properties:
//         * ChecksCompleted  - Boolean - (return value) is set in
//                                        the procedure of the ResultProcessing parameter.
//         * ChecksOnServer - Undefined - checking was not executed on server:
//                             - Structure - with the properties as in the following parameter.
//         * ChecksOnClient - Structure - with properties:
//             * CertificateAvailability  - Boolean, Undefined - If True, then the checking was
//                                     successful if False - checking was not successful if Undefined - was not executed.
//             * CertificateData   - Boolean, Undefined - also as specified above.
//             * ApplicationAvailability    - Boolean, Undefined - also as specified above.
//             * Signing          - Boolean, Undefined - also as specified above.
//             * SignatureCheck     - Boolean, Undefined - also as specified above.
//             * Encryption          - Boolean, Undefined - also as specified above.
//             * Decryption         - Boolean, Undefined - also as specified above.
//             * <Name of additional check> - Boolean, Undefined - also as specified above.
//
//    * AdditionalChecksParameters - Arbitrary - parameters that are passed to a procedure.
//        OnCreateCertificateCheckForm of the DigitalSignatureOverridable common module.
//
Procedure CheckCatalogCertificate(Certificate, AdditionalParameters = Undefined) Export
	
	DigitalSignatureServiceClient.CheckCatalogCertificate(Certificate, AdditionalParameters);
	
EndProcedure

// Finds a certificate on the computer by the thumbprint row.
//
// Parameters:
//   Notification           - NotifyDescription - notification about a result of performing the following types:
//     CryptoCertificate - found certificate.
//     Undefined           - certificate is not found in the storage.
//     String                 - error text of creating cryptography manager (or another error).
//
//   Imprint              - String - Base64 encoded thumbprint of certificate.
//   InPersonalStorageOnly - Boolean - if True, then search the personal storage, otherwise, everywhere.
//   ShowError         - Boolean - if False, then error, text that will be returned will not be shown.
//
Procedure GetCertificateByImprint(Notification, Imprint, InPersonalStorageOnly, ShowError = True) Export
	
	If TypeOf(ShowError) <> Type("Boolean") Then
		ShowError = True;
	EndIf;
	
	DigitalSignatureServiceClient.GetCertificateByImprint(Notification,
		Imprint, InPersonalStorageOnly, ShowError);
	
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
	
	DigitalSignatureServiceClient.GetCertificatesThumbprints(Notification, PersonalOnly, ShowError);
	
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
	
	DigitalSignatureServiceClient.SetExtension(WithoutQuestion, ResultHandler, QuestionText, QuestionTitle);
	
EndProcedure

// Opens or activates the form of digital signature and encryption settings.
// 
// Parameters:
//  Page - String - Certificates, Settings, Applications rows are allowed.
//
Procedure OpenDigitalSignaturesAndEncryptionSettings(Page = "Certificates") Export
	
	FormParameters = New Structure;
	If Page = "Certificates" Then
		FormParameters.Insert("ShowPageCertificates");
		
	ElsIf Page = "Settings" Then
		FormParameters.Insert("ShowSettingPage");
		
	ElsIf Page = "application" Then
		FormParameters.Insert("ShowApplicationPage");
	EndIf;
	
	Form = OpenForm("CommonForm.DigitalSignaturesAndEncryptionSettings", FormParameters);
	
	// When you reopen the form, it requires additional actions.
	If Page = "Certificates" Then
		Form.Items.Pages.CurrentPage = Form.Items.PageCertificates;
		
	ElsIf Page = "Settings" Then
		Form.Items.Pages.CurrentPage = Form.Items.SettingsPage;
		
	ElsIf Page = "application" Then
		Form.Items.Pages.CurrentPage = Form.Items.ApplicationPage;
	EndIf;
	
	Form.Open();
	
EndProcedure

// Sets a password into passwords storage on client for a time of session.
// Setting a password allows a user not to
// enter it during another operation which is useful when you have a range of operations.
// If a password is set for a
// certificate, then the RememberPassword check box becomes invisible in the DataSigning and DataDetail forms.
// To cancel a set password, it is enough to install the Undefined password value.
//
// Parameters:
//  CertificatRef - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - certificate
//                        for which a password is being set.
//
//  Password           - String - set password. May be empty.
//                   - Undefined - reset password if it was set.
//
//  PasswordExplanation   - Structure - with the properties describing an explanation that will be written under the password instead of the RememberPassword check box.:
//     * ExplanationText       - String - only text;
//     * ExplanationHyperlink - Boolean - if True, then when you click the explanation, call ActionProcessing.
//     * ToolTipText       - String, FormattedString - text or text with refs.
//     * ActionProcessing    - NotifyDescription - calls a procedure, to
//          which a structure is transferred with properties:
//          * Certificate - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - reference
//                         to a selected certificate;
//          * Action   - String - ExplanationClick or tooltip navigational reference.
// 
Procedure SetCertificatePassword(CertificatRef, Password, PasswordExplanation = Undefined) Export
	
	DigitalSignatureServiceClient.SetCertificatePassword(CertificatRef, Password, PasswordExplanation);
	
EndProcedure

// Redirects a regular certificate selection from a
// catalog to a catalog selection from the personal storage with a
// confirmed password and automatic adding to the catalog if there is no certificate in the catalog.
//  
// Parameters:
//  Item    - FormField - form item, to which selected value was transferred.
//  Certificate - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - the
//               current job selected in the Item field helps to highlight a corresponding list row.
//  
//  StandardProcessing - Boolean - standerd parameter of the SelectionBegin event which needs to be put to False.
//  
//  ForEncryptionAndDecryption - Boolean - manages selection form title. Initial value is False.
//                              False - for signing, True - for encryption and decryption,
//                            - Undefined - for signing and encryption.
//
Procedure CertificateStartChoiceWithConfirmation(Item, Certificate, StandardProcessing, ForEncryptionAndDecryption = False) Export
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("SelectedCertificate", Certificate);
	FormParameters.Insert("ForEncryptionAndDecryption", True);
	
	DigitalSignatureServiceClient.CertificateChoiceForSigningOrDecoding(FormParameters, Item);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Outdated procedures and functions.

// Outdated. You should use OpenDigitalSignaturesAndEncryptionSettings.
Procedure OpenDSSettingForm() Export
	
	OpenDigitalSignaturesAndEncryptionSettings();
	
EndProcedure

// Outdated. You should you the Sign procedure.
Function GenerateSignatureData(
			CryptoManager,
			ObjectForSignaturesReference,
			BinaryData,
			StructureOfSignatureParameters) Export
	
	CryptoManager.PrivateKeyAccessPassword = StructureOfSignatureParameters.Password;
	SignatureDate = Date('00010101');
	
	NewSignatureBinaryData = CryptoManager.Sign(BinaryData, StructureOfSignatureParameters.Certificate);
	ErrorDescription = "";
	If DigitalSignatureServiceClientServer.EmptySignatureData(NewSignatureBinaryData, ErrorDescription) Then
		Raise ErrorDescription;
	EndIf;
	
	Imprint = Base64String(StructureOfSignatureParameters.Certificate.Imprint);
	IssuedToWhom = DigitalSignatureClientServer.SubjectPresentation(StructureOfSignatureParameters.Certificate);
	CertificateBinaryData = StructureOfSignatureParameters.Certificate.Unload();
	
	SignatureData = New Structure;
	SignatureData.Insert("ObjectRef", ObjectForSignaturesReference);
	SignatureData.Insert("NewSignatureBinaryData", NewSignatureBinaryData);
	SignatureData.Insert("Imprint", Imprint);
	SignatureData.Insert("SignatureDate", SignatureDate);
	SignatureData.Insert("Comment", StructureOfSignatureParameters.Comment);
	SignatureData.Insert("SignatureFileName", "");
	SignatureData.Insert("CertificateIsIssuedTo", IssuedToWhom);
	SignatureData.Insert("FileURL", "");
	SignatureData.Insert("CertificateBinaryData", CertificateBinaryData);
	
	Return SignatureData;
	
EndFunction

#EndRegion

#Region ServiceApplicationInterface

// Opens a form of DS signature view.
Procedure OpenSignature(CurrentData) Export
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CommonUseClientReUse.ThisIsMacOSWebClient() Then
		Return;
	EndIf;
	
	SignatureProperties = New Structure(
		"SignatureDate, Comment,
		|CertificateIsIssuedTo, Thumbprint, SignatureAddress, Signer, CertificateAddress");
	
	FillPropertyValues(SignatureProperties, CurrentData);
	
	FormParameters = New Structure("SignatureProperties", SignatureProperties);
	OpenForm("CommonForm.DigitalSignature", FormParameters);
	
EndProcedure

// Saves signature to disk
Procedure SaveSignature(SignatureAddress) Export
	
	DigitalSignatureServiceClient.SaveSignature(SignatureAddress);
	
EndProcedure

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
	
	DigitalSignatureServiceClient.OpenCertificate(CertificateData, OpenData);
	
EndProcedure

// Informs about completion of signing.
//
// Parameters:
//  DataPresentation - Arbitrary - ref to an
//                          object, in a tabular section of which a digital signature is added.
//  DataSet     - Boolean - specifies the
//                          messages kind the plural or singular number of items.
//  FromFile             - Boolean - specifies the
//                          message kind of adding digital signature or file.
//
Procedure InformAboutSigningAnObject(DataPresentation, DataSet = False, FromFile = False) Export
	
	If FromFile Then
		If DataSet Then
			MessageText = NStr("en='Signatures from files added:';ru='Добавлены подписи из файлов:'");
		Else
			MessageText = NStr("en='Signature from file added:';ru='Добавлена подпись из файла:'");
		EndIf;
	Else
		If DataSet Then
			MessageText = NStr("en='Digitally signed:';ru='Установлены подписи:'");
		Else
			MessageText = NStr("en='Digitally signed:';ru='Установлена подпись:'");
		EndIf;
	EndIf;
	
	ShowUserNotification(MessageText, , DataPresentation);
	
EndProcedure

// Informs about completion of encryption.
//
// Parameters:
//  DataPresentation - Arbitrary - refs
//                          to an object with encrypted data.
//  DataSet     - Boolean - specifies the
//                          messages kind the plural or singular number of items.
//
Procedure InformAboutObjectEncryption(DataPresentation, DataSet = False) Export
	
	MessageText = NStr("en='Encrypted:';ru='Выполнено шифрование:'");
	
	ShowUserNotification(MessageText, , DataPresentation);
	
EndProcedure

// At the end of the decryption reports about completion.
//
// Parameters:
//  DataPresentation - Arbitrary - refs
//                          to the object which data is decrypted.
//  DataSet     - Boolean - specifies the
//                          messages kind the plural or singular number of items.
//
Procedure InformAboutObjectDecryption(DataPresentation, DataSet = False) Export
	
	MessageText = NStr("en='Decrypted:';ru='Выполнена расшифровка:'");
	
	ShowUserNotification(MessageText, , DataPresentation);
	
EndProcedure

#EndRegion
