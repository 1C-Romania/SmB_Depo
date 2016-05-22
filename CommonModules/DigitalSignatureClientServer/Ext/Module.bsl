////////////////////////////////////////////////////////////////////////////////
// Digital signature subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the certificate presentation in catalog, formed
// - either from surname, name, company, position, validation.
// L or from the common name and validity (if surname and name are not defined).
//
// Parameters:
//   Certificate   - CryptoCertificate - Cryptography manager.
//   Patronymic     - Boolean - include patronymic into the presentation.
//   ValidityPeriod - Boolean - include validity into the presentation.
//
// Returns:
//  String - certificate presentation in the catalog.
//
Function CertificatePresentation(Certificate, Patronymic = False, ValidityPeriod = True) Export
	
	Return SubjectPresentation(Certificate, Patronymic) + ", "
		+ StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'up to %1'"), Format(Certificate.EndDate, "DF=MM.yyyy"));
	
EndFunction

// Returns the certificate subject presentation (IssuedToWhom).
//
// Parameters:
//   Certificate - CryptoCertificate - Cryptography manager.
//
//   Patronymic - Boolean - include patronymic into the presentation.
//
// Returns:
//   String   - presentation of the subject in the Surname Name, Company, Division, Position format.
//              If it is impossible to define full name, then it is replaced with CommonName.
//              Company, Division and Position may be missing if
//              they are not specified or it was impossible to define them.
//
Function SubjectPresentation(Certificate, Patronymic = True) Export
	
	Subject = CertificateSubjectProperties(Certificate);
	
	Presentation = "";
	
	If ValueIsFilled(Subject.Surname)
	   AND ValueIsFilled(Subject.Name) Then
		
		Presentation = Subject.Surname + " " + Subject.Name;
		
	ElsIf ValueIsFilled(Subject.Surname) Then
		Presentation = Subject.Surname;
		
	ElsIf ValueIsFilled(Subject.Name) Then
		Presentation = Subject.Name;
	EndIf;
	
	If Patronymic AND ValueIsFilled(Subject.Patronymic) Then
		Presentation = Presentation + " " + Subject.Patronymic;
	EndIf;
	
	If ValueIsFilled(Presentation) Then
		If ValueIsFilled(Subject.Company) Then
			Presentation = Presentation + ", " + Subject.Company;
		EndIf;
		If ValueIsFilled(Subject.Division) Then
			Presentation = Presentation + ", " + Subject.Division;
		EndIf;
		If ValueIsFilled(Subject.Position) Then
			Presentation = Presentation + ", " + Subject.Position;
		EndIf;
		
	ElsIf ValueIsFilled(Subject.CommonName) Then
		Presentation = Subject.CommonName;
	EndIf;
	
	Return Presentation;
	
EndFunction

// Returns the presentation of issuer certificate (IssuingAuthority).
//
// Parameters:
//   Certificate - CryptoCertificate - Cryptography manager.
//
// Returns:
//   String - presentation of an issuer
//            in the CommonName, Company, Division format Company and Division may be missing if they are not specified.
//
Function PublisherRepresentation(Certificate) Export
	
	Issuer = CertificateIssuerProperties(Certificate);
	
	Presentation = "";
	
	If ValueIsFilled(Issuer.CommonName) Then
		Presentation = Issuer.CommonName;
	EndIf;
	
	If ValueIsFilled(Issuer.CommonName)
	   AND ValueIsFilled(Issuer.Company)
	   AND Find(Issuer.CommonName, Issuer.Company) = 0 Then
		
		Presentation = Issuer.CommonName + ", " + Issuer.Company;
	EndIf;
	
	If ValueIsFilled(Issuer.Division) Then
		Presentation = Presentation + ", " + Issuer.Division;
	EndIf;
	
	Return Presentation;
	
EndFunction

// Fills the structure with certificate fields.
//
// Parameters:
//   Certificate - CryptoCertificate - Cryptography manager.
//
// Returns:
//   Structure - Structure with certificate fields.
//
Function FillCertificateStructure(Certificate) Export
	
	Properties = New Structure;
	Properties.Insert("Imprint",      Base64String(Certificate.Imprint));
	Properties.Insert("Presentation",  CertificatePresentation(Certificate));
	Properties.Insert("IssuedToWhom",      SubjectPresentation(Certificate));
	Properties.Insert("WhoIssued",       PublisherRepresentation(Certificate));
	Properties.Insert("ValidUntil", Certificate.EndDate);
	Properties.Insert("Purpose",     GetPurpose(Certificate));
	
	Return Properties;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns a structure containing various common settings.
//
// Returns:
//  See EmailCommonSettings().
//
// See also:
//   CommonForm.DigitalSignaturesAndEncryptionSettings - place where parameters data
//   and their text descriptions are defined.
//
Function CommonSettings() Export
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		Return DigitalSignature.CommonSettings();
	#Else
		Return StandardSubsystemsClientReUse.ClientWorkParameters().DigitalSignature.CommonSettings;
	#EndIf
EndFunction

// Returns the structure containing personal settings.
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
//   CommonForm.DigitalSignaturesAndEncryptionSettings - place of the current
//   parameters input and their custom presentations.
//
Function PersonalSettings() Export
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		Return DigitalSignature.PersonalSettings();
	#Else
		Return StandardSubsystemsClientReUse.ClientWorkParameters().DigitalSignature.PersonalSettings;
	#EndIf
EndFunction

// Returns properties of the cryptography certificate subject taking into account their content (LE,SE,Ind).
//
// Parameters:
//   Certificate - CryptoCertificate - for which subject properties need to be returned.
//
// Returns:
//  Structure - return value, with properties:
//     * Common name         - String(64) - retrieved from the CN field.
//                          LE: Depending on the type of the SKPEP target owner
//                              - company name;
//                              - name of the automated system;
//                              - other display name according to the requirements of the information system.
//                          Ind: Full name.
//                        - Undefined - required certificate property is not found.
//
//     * Country           - String(2) - retrieved from the C field - Country
//                          two-character code according to GOST 7.67-2003 (ISO 3166-1:1997).
//                        - Undefined - required certificate property is not found.
//
//     * State           - String(128) - retrieved from the S field - RF territorial entity name.
//                          LE: By the location address.
//                          Ind: By the registration address.
//                        - Undefined - required certificate property is not found.
//
//     * Settlement  - String(128) - retrieved from the L field - locality name.
//                          LE: By the location address.
//                          Ind: By the registration address.
//                        - Undefined - required certificate property is not found.
//
//     * Street            - String(128) - retrieved from the Street field - street, house, office name.
//                          LE: By the location address.
//                          Ind: By the registration address.
//                        - Undefined - required certificate property is not found.
//
//     *Company      - String(64) - retrieved from the O field.
//                          LP: Full or short company name.
//                        - Undefined - required certificate property is not found.
//
//     * Division    - String(64) - retrieved from the OU field.
//                          LE: in case of SKPEP release for the official - company division.
//                              Division - this is a territorial entity
//                              of a large company that is usually not filled in the certificate.
//                        - Undefined - required certificate property is not found.
//
//     * Position        - String(64) - retrieved from the T field.
//                          LE: in case of SKPEP release for the official - their position.
//                        - Undefined - required certificate property is not found.
//
//     * Email - String(128) - retrieved from the E field - email address.
//                          LE: email address of the official.
//                          Ind: email address of an individual.
//                        - Undefined - required certificate property is not found.
//
//     * OGRN             - String(13) - retrieved from the OGRN field.
//                          LE: company OGRN.
//                        - Undefined - required certificate property is not found.
//
//     * OGRNIP           - String(15) - retrieved from the OGRNIP field.
//                          Ind: OGRN of an entrepreneur.
//                        - Undefined - required certificate property is not found.
//
//     * INILA            - String(11) - retrieved from the SNILS field.
//                          Ind:
//                          INILA LE: Optional, in the case of SKPEP release on the official - their INILA.
//                        - Undefined - required certificate property is not found.
//
//     * TIN              - String(12) - retrieved from the TIN field.
//                          Ind: TIN.
//                          Ent: TIN.
//                          LE: Optional but could be filled to interact with FTS.
//                        - Undefined - required certificate property is not found.
//
//     * Last name          - String(64) - retrieved from the SN field if it is filled.
//                        - Undefined - required certificate property is not found.
//
//     (actual name              - String(64) - retrieved from the GN field if it is filled.
//                        - Undefined - required certificate property is not found.
//
//     * Patronymic         - String(64) - retrieved from the GN field if it is filled.
//                        - Undefined - required certificate property is not found.
//
Function CertificateSubjectProperties(Certificate) Export
	
	Subject = Certificate.Subject;
	
	Properties = New Structure;
	Properties.Insert("CommonName");
	Properties.Insert("Country");
	Properties.Insert("Region");
	Properties.Insert("Settlement");
	Properties.Insert("Street");
	Properties.Insert("Company");
	Properties.Insert("Division");
	Properties.Insert("Position");
	Properties.Insert("Email");
	Properties.Insert("OGRN");
	Properties.Insert("OGRNIP");
	Properties.Insert("INILA");
	Properties.Insert("TIN");
	Properties.Insert("Surname");
	Properties.Insert("Name");
	Properties.Insert("Patronymic");
	
	If Subject.Property("CN") Then
		Properties.CommonName = PrepareString(Subject.CN);
	EndIf;
	
	If Subject.Property("C") Then
		Properties.Country = PrepareString(Subject.C);
	EndIf;
	
	If Subject.Property("ST") Then
		Properties.Region = PrepareString(Subject.ST);
	EndIf;
	
	If Subject.Property("L") Then
		Properties.Settlement = PrepareString(Subject.L);
	EndIf;
	
	If Subject.Property("Street") Then
		Properties.Street = PrepareString(Subject.Street);
	EndIf;
	
	If Subject.Property("O") Then
		Properties.Company = PrepareString(Subject.O);
	EndIf;
	
	If Subject.Property("OU") Then
		Properties.Division = PrepareString(Subject.OU);
	EndIf;
	
	If Subject.Property("E") Then
		Properties.Email = PrepareString(Subject.E);
	EndIf;
	
	If Subject.Property("OGRN")Then
		Properties.OGRN = PrepareString(Subject.OGRN);
	EndIf;
	
	If Subject.Property("OGRNIP") Then
		Properties.OGRNIP = PrepareString(Subject.OGRNIP);
	EndIf;
	
	If Subject.Property("SNILS") Then
		Properties.INILA = PrepareString(Subject.SNILS);
	EndIf;
	
	If Subject.Property("TIN") Then
		Properties.TIN = PrepareString(Subject.TIN);
	EndIf;
	
	If Subject.Property("SN") Then // Surname (usually for the official).
		
		// Retrieve full name from the SN and GN field.
		Properties.Surname = PrepareString(Subject.SN);
		
		If Subject.Property("GN") Then
			GivenName = PrepareString(Subject.GN);
			Position = Find(GivenName, " ");
			If Position = 0 Then
				Properties.Name = GivenName;
			Else
				Properties.Name = Left(GivenName, Position - 1);
				Properties.Patronymic = PrepareString(Mid(GivenName, Position + 1));
			EndIf;
		EndIf;
		
		If Subject.Property("T") Then
			Properties.Position = PrepareString(Subject.T);
		EndIf;
	
	ElsIf Subject.Property("OGRNIP") // Shows that there is an entrepreneur.
	      Or Subject.Property("SNILS")  // Shows that there is an individual.
	      Or IsTINIndividuals(Subject.Property("TIN")) Then // Shows that there is an individual.
		
		If Properties.CommonName <> Properties.Company
		   AND Not (Subject.Property("T") AND Properties.CommonName = PrepareString(Subject.T)) Then
			
			// Retrieve full name from the CN field.
			Array = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(
				Properties.CommonName, " ", True, True);
			
			If Array.Count() < 4 Then
				If Array.Count() > 0 Then
					Properties.Surname = Array[0];
				EndIf;
				If Array.Count() > 1 Then
					Properties.Name = Array[1];
				EndIf;
				If Array.Count() > 2 Then
					Properties.Patronymic = Array[2];
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	Return Properties;
	
EndFunction

// Returns the properties of cryptography certificate issuer.
//
// Parameters:
//   Certificate - CryptoCertificate - for which issuer properties need to be returned.
//
// Returns:
//  Structure - return value, with properties:
//     * Common name         - String(64) - retrieved from the CN field - alias of the certification center.
//                        - Undefined - required certificate property is not found.
//
//     * Country           - String(2) - retrieved from the C field - Country
//                          two-character code according to GOST 7.67-2003 (ISO 3166-1:1997).
//                        - Undefined - required certificate property is not found.
//
//     * State           - String(128) - retrieved from the S field - RF territorial
//                          entity name on PAK CC location address.
//                        - Undefined - required certificate property is not found.
//
//     * Settlement  - String(128) - retrieved from the L field - locality name
//                          by the PAK CC location address.
//                        - Undefined - required certificate property is not found.
//
//     * Street            - String(128) - retrieved from the Street field - name of the
//                          street, house, office by PAK CC location address.
//                        - Undefined - required certificate property is not found.
//
//     *Company      - String(64) - retrieved
//                          from the O full or short company name field.
//                        - Undefined - required certificate property is not found.
//
//     * Division    - String(64) - retrieved from the OU company division field.
//                            Division - this is a territorial entity
//                            of a large company that is usually not filled in the certificate.
//                        - Undefined - required certificate property is not found.
//
//     * Email - String(128) - retrieved from the E field - email address of the certification center.
//                        - Undefined - required certificate property is not found.
//
//     * OGRN             - String(13) - retrieved from the OGRN - OGRN company certification centre field.
//                        - Undefined - required certificate property is not found.
//
//     * TIN              - String(12) - retrieved from the TIN field - Certification center company TIN.
//                        - Undefined - required certificate property is not found.
//
Function CertificateIssuerProperties(Certificate) Export
	
	Issuer = Certificate.Issuer;
	
	Properties = New Structure;
	Properties.Insert("CommonName");
	Properties.Insert("Country");
	Properties.Insert("Region");
	Properties.Insert("Settlement");
	Properties.Insert("Street");
	Properties.Insert("Company");
	Properties.Insert("Division");
	Properties.Insert("Email");
	Properties.Insert("OGRN");
	Properties.Insert("TIN");
	
	If Issuer.Property("CN") Then
		Properties.CommonName = PrepareString(Issuer.CN);
	EndIf;
	
	If Issuer.Property("C") Then
		Properties.Country = PrepareString(Issuer.C);
	EndIf;
	
	If Issuer.Property("ST") Then
		Properties.Region = PrepareString(Issuer.ST);
	EndIf;
	
	If Issuer.Property("L") Then
		Properties.Settlement = PrepareString(Issuer.L);
	EndIf;
	
	If Issuer.Property("Street") Then
		Properties.Street = PrepareString(Issuer.Street);
	EndIf;
	
	If Issuer.Property("O") Then
		Properties.Company = PrepareString(Issuer.O);
	EndIf;
	
	If Issuer.Property("OU") Then
		Properties.Division = PrepareString(Issuer.OU);
	EndIf;
	
	If Issuer.Property("E") Then
		Properties.Email = PrepareString(Issuer.E);
	EndIf;
	
	If Issuer.Property("OGRN") Then
		Properties.OGRN = PrepareString(Issuer.OGRN);
	EndIf;
	
	If Issuer.Property("TIN") Then
		Properties.TIN = PrepareString(Issuer.TIN);
	EndIf;
	
	Return Properties;
	
EndFunction

// Fills the table of certificate description containing four fields: IssuedToWhom, IssuingAuthority, ValidUntil, Purpose.
Function FillCertificateDataDescription(Table, Certificate) Export
	
	CertificateStructure = FillCertificateStructure(Certificate);
	
	If Certificate.UseToSign AND Certificate.UseForEncryption Then
		Purpose = NStr("en = 'Sign data, Encrypt data'");
		
	ElsIf Certificate.UseToSign Then
		Purpose = NStr("en = 'Data signing'");
	Else
		Purpose = NStr("en = 'Data encryption'");
	EndIf;
	
	Table.Clear();
	String = Table.Add();
	String.Property = NStr("en = 'Issued to:'");
	String.Value = CertificateStructure.IssuedToWhom;
	
	String = Table.Add();
	String.Property = NStr("en = 'Issued by:'");
	String.Value = CertificateStructure.WhoIssued;
	
	String = Table.Add();
	String.Property = NStr("en = 'Valid until:'");
	String.Value = Format(CertificateStructure.ValidUntil, "DF=dd.MM.yyyy");
	
	String = Table.Add();
	String.Property = NStr("en = 'Purpose:'");
	String.Value = Purpose;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// Receives the certificate purpose.
//
// Parameters:
//   Certificate - CryptoCertificate - certificate which appointment you need to receive.
//
Function GetPurpose(Certificate)
	
	If Not Certificate.Extensions.Property("EKU") Then
		Return "";
	EndIf;
	
	PropertiesFixedArray = Certificate.Extensions.EKU;
	
	Purpose = "";
	
	For IndexOf = 0 To PropertiesFixedArray.Count() - 1 Do
		Purpose = Purpose + PropertiesFixedArray.Get(IndexOf);
		Purpose = Purpose + Chars.LF;
	EndDo;
	
	Return PrepareString(Purpose);
	
EndFunction

Function IsTINIndividuals(TIN)
	
	If StrLen(TIN) <> 12 Then
		Return False;
	EndIf;
	
	For CharacterNumber = 1 To 12 Do
		If Find("0123456789", Mid(TIN,CharacterNumber,1)) = 0 Then
			Return False;
		EndIf;
	EndDo;
	
	If Left(TIN,2) = "00" Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function PrepareString(RowFromCertificate)
	
	Return TrimAll(CommonUseClientServer.ReplaceInadmissibleCharsXML(RowFromCertificate));
	
EndFunction

#EndRegion
