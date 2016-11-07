////////////////////////////////////////////////////////////////////////////////
// Digital signature subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Called after creation on server but before opening of the DataSigning, DataDetails forms.
// Used for additional actions which need the server
// call not to call the server once again.
//
// Parameters:
//  Operation          - String - Signing or Details row.
//
//  InputParameters  - Arbitrary - the AdditionalActionsParameters property value of the DataDescription parameter of the Sign, Decrypt method of the DigitalSignatureClient common module.
//                      
//  Output_Parameters - Arbitrary - random data returned
//                      from the server of the eponymous procedure of common module.
//                      DigitalSignatureOverridable.
//
Procedure BeforeOperationBeginning(Operation, InputParameters, Output_Parameters) Export
	
	
	
EndProcedure

// Called from the CertificateCheck form if additional checkings were added during form creation.
//
// Parameters:
//  Parameters - Structure - with properties:
//  * WaitContituation   - Boolean - (return value) - if True, additional checking
//                             will occur asynchronously, the continuation will be resumed after an alert.
//                            Initial value Lie
//  * Alert           - NotifyDescription - processing which needs to
//                              be called for continuation after an additional asynchronous checking.
//  * Certificate           - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - certificate being checked.
//  * Check             - String - name of the checking added
//                              in the OnCreateFormCertificateChecking procedure of the DigitalSignatureOverridable common module.
//  * CryptographyManager - CryptoManager - prepared cryptography
//                              manager to perform checking.
//  * ErrorDescription       - String - (return value) - description of an error received during checking.
//                              A user sees this description after they click on the result picture.
//  * IsWarning    - Boolean - (return value) - picture kind
// Error/Warning initial value Lie
//
Procedure OnAdditionalCertificateVerification(Parameters) Export
	
	
	
EndProcedure

// Called during opening the instruction on working with the digital signatures and encryption applications.
//
// Parameters:
//  Section - String - the AccountingAndTaxAccounting
//                     initial value, AccountingInPublicInstitutions may be specified
//
Procedure OnDefineItemSectionOnITS(Section) Export
	
	
	
EndProcedure

#EndRegion
