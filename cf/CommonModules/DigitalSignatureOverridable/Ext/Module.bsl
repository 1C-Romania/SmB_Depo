////////////////////////////////////////////////////////////////////////////////
// Digital signature subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Called in the form of adding applications for a new certificate for filling company attributes and their selection.
//
// Parameters:
//  Parameters - Structure - with properties:
//
//    *Company - CatalogRef.Companies - company that needs to be filled.
//                    If the company is already filled, you need
//                    to refill its properties, for example, on repeated call when a user has selected another organization.
//                  - Is undefined if the StandardSubsystems subsystem.Companies not integrated.
//                    User can not select company.
//
//    * IsEntrepreneur - Boolean - (return value):
//                    False   - Initial value - specified company is
//                    a legal entity, True - specified company is an entrepreneur.
//
//    * ShortName  - String - (return value) company short name.
//    * DescriptionFull       - String - (return value) company short name.
//    * TIN                      - String - (return value) company TIN.
//    * OGRN                     - String - (return value) company OGRN.
//    * BankAccount            - String - (return value) main account of company for contract.
//    * BIC                      - String - (return value) account bank BIC.
//    * CorrespondentAccount    - String - (return value) correspondent account of account bank.
//    * Phone                  - String - (return value) company phone in the XML format
//                                 as it is returned by
//                                 the ContactInformationInXML function of the ContactInformationManagement common module.
//
//    * LegalAddress - String - (return value) company legal address in the XML format
//                         as it is returned by the ContactInformationInXML function of the ContactInformationManagement common module.
//
//    * ActualAddress  - String - (return value) company actual address in the XML format
//                         as it is returned by the ContactInformationInXML function of the ContactInformationManagement common module.
//
Procedure OnFillCompanyAttributesInApplicationForCertificate(Parameters) Export
	
	
	
EndProcedure

// Called in the form of adding applications for a new certificate for filling owner attributes and their selection.
//
// Parameters:
//  Parameters - Structure - with properties:
//    *Company  - CatalogRef.Companies - selected company, in which the certificate is titled.
//                   - Is undefined if the StandardSubsystems subsystem.Companies not integrated.
//
//    * OwnerType  - TypeDescription - (return value) contains reference types to select from.
//                    - Undefined  - (return value) owner selection is not supported.
//
//    * OwnerKind - String - one of the rows:
//                     Director, ChiefAccountant, Employee that shows who is currently selected by a user as certificate owner.
//                     For this owner it is required to fill out the Initials attributes, ...
//                     For an entrepreneur always Employee. IN this
//                     case, the Employee attribute can not be changed by the user even if it is not filled.
//
//    * Director     - OwnerType - (return value) - this director who can be
//                     selected as the owner of the certificate.
//                   - Undefined - Initial value - hide the director attribute.
//
//    * ChiefAccountant - OwnerType - (return value) this is chief accountant that
//                     can be selected as a certificate owner.
//                   - Undefined - Initial value - hide the chief accountant attribute.
//
//    * Employee    - OwnerType - (return value) - this is certificate owner who needs to be filled.
//                     If it is already filled (selected by a user), it should not be changed.
//                   - Undefined - OwnerType is not defined - attribute is unavailable for a user.
//
//    * User - CatalogRef.Users - (return value) user owner of the certificate.
//                     Generally, may not be filled. Required to fill if you can.
//                     It is written to the certificate to the User field, can be changed later.
//
//    * Last name            - String - (return value) employee's last name.
//    (actual name                - String - (return value) employee name.
//    * Patronymic           - String - (return value) employee patronymic.
//    * InsuranceNumberRPF  - String - (return value) employee INILA.
//    * Position          - String - (return value) employee position in the company.
//
//    * Department      - String - (return value) separate
//                           company department where employee works.
//
//    * DocumentKind        - String - (return value) 21 or 91 rows. 21 - password,
//                           91 - other document provided by the regulation of the Russian Federation (according to SPDUL).
//
//    * DocumentNumber      - String - (return value) employee document
//                           number (passport serial number).
//
//    * DocumentIssuingAuthority   - String - (return value) issuing authority of employee document.
//    * DocumentIssueDate - Date   - (return value) issue date of employee document.
//
//    * Email   - String - (return value) employee email address in the XML format as
//                           it is returned by the ContactInformationInXML function of the ContactInformationManagement common module.
//
Procedure OnFillAttributesInOwnerCertificateApplication(Parameters) Export
	
	
	
EndProcedure

// Called in the form of adding applications for a new certificate for filling manager attributes and their selection.
// Only for a legal entity. It is not required for entrepreneur.
//
// Parameters:
//  Parameters - Structure - with properties:
//    *Company   - CatalogRef.Companies - selected company, in which the certificate is titled.
//                    - Is undefined if the StandardSubsystems subsystem.Companies not integrated.
//
//    * DirectorType - TypeDescription - (return value) contains reference types
//                                        to select from.
//                      - Undefined  - (return value) partner selection is not supported.
//
//    * Manager  - DirectorType - this is a value selected by a user, according to which you need to fill the position.
//                    - Undefined - DirectorType is not defined.
//                    - AnyRef - (return value) - manager who will sign documents.
//
//    * Presentation String - (return value) manager presentation.
//                    - Undefined - receive presentation from the Manager value.
//
//    * Position     - String - (return value) - position of the manager who will sign documents.
//    * Basis     - String - (return value) - basis, on which official acts
//                               (charter, power of attorney, ...).
//
Procedure OnFillManagerAttributesInApplicationForCertificate(Parameters) Export
	
	
	
EndProcedure

// Called in the form of adding applications for a new certificate for filling partner attributes and their selection.
//
// Parameters:
//  Parameters - Structure - with properties:
//    *Company   - CatalogRef.Companies - selected company, in which the certificate is titled.
//                    - Is undefined if the StandardSubsystems subsystem.Companies not integrated.
//
//    * PartnerType   - TypeDescription - contains reference types from which you can select.
//                    - Undefined - selection of a partner is not supported.
//
//    * Partner       - PartnerType - this is a counterparty (service
//                      provider) selected by a user, according to which you need to fill the attributes described below.
//                    - Undefined - PartnerType is not defined.
//                    - AnyRef - (return value) - value saved in the application for history.
//
//    * Presentation String - (return value) parameter presentation.
//                    - Undefined - receive presentation from the Partner value.
//
//    * IsEntrepreneur - Boolean - (return value):
//                      False   - Initial value - specified partner is
//                      a legal entity, True - specified partner is an individual entrepreneur.
//
//    * TIN           - String - (return value) partner TIN.
//
Procedure OnFillPartnerDetailsInApplicationForCertificate(Parameters) Export
	
	
	
EndProcedure


// Called in the form of the DigitalSignaturesAndEncryptionKeyCertificates catalog
// items and in other places where certificates are created and updated, for example, in the SelectCertificateForSigningAndDecrypting form.
// Exception call is allowed if you need to stop
// an action and to tell something the user, for example, when you try to create an item-copy of the certificate with a limited access.
//
// Parameters:
//  Refs     - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - empty for a new item.
//
//  Certificate - CryptoCertificate - certificate, for which a catalog item is created or updated.
//
//  AttributesParameters - ValueTable - with columns:
//               * AttributeName       - String - name of attribute, for which you can clarify the parameters.
//               * ViewOnly     - Boolean - if you select True, editing will be prohibited.
//               * FillingCheck - Boolean - If you select True, filling will be checked.
//               * Visible          - Boolean - if you select True, attribute will become invisible.
//               * FillValue - Arbitrary - initial value of new object attribute.
//                                    - Undefined - filling is not needed.
//
Procedure BeforeEditKeyCertificate(Refs, Certificate, AttributesParameters) Export
	
	
	
EndProcedure

// Called when creating the DataSigning, DataDetail forms on server.
// Used for additional actions which need the server
// call not to call the server once again.
//
// Parameters:
//  Operation          - String - Signing or Decryption row.
//
//  InputParameters  - Arbitrary - the AdditionalActionsParameters property value of the DataDescription parameter of the Sign, Decrypt method of the DigitalSignatureClient common module.
//                      
//  Output_Parameters - Arbitrary - random return data
//                      that will be placed in the same procedure in the general module.
//                      DigitalSignatureOverridableClient
//                      after creation of form on server but before its opening.
//
Procedure BeforeOperationBeginning(Operation, InputParameters, Output_Parameters) Export
	
	
	
EndProcedure

// Called for the extension of checkings.
//
// Parameters:
//  Certificate - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - certificate being checked.
// 
//  AdditionalChecks - ValueTable - with fields:
//    (actual name           - String - name of the additional checking, for example, AuthorizationInTaxcom.
//    * Presentation String - custom check name, for example, Authorization on the Taxcom server.
//    * ToolTip String - tooltip that will be shown to user on clicking the question-mark.
//
//  AdditionalChecksParameters - Arbitrary - value of an
//    eponymous parameter specified in the CheckCatalogCertificate function of the DigitalSignatureClient common module.
//
Procedure OnCreatingFormCertificateCheck(Certificate, AdditionalChecks, AdditionalChecksParameters) Export
	
	
	
	
EndProcedure

// Called from the CertificateCheck form if additional checkings were added during form creation.
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
Procedure OnAdditionalCertificateVerification(Certificate, Checking, CryptoManager, ErrorDescription, IsWarning) Export
	
	
	
EndProcedure

#EndRegion
