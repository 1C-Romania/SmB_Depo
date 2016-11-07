////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Info base update

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Handler of the update BED 1.1.9.1
// Fills the expiration date of the certificate
//
Procedure FillTimeActions() Export
	
	Certificates = Catalogs.DeleteDSCertificates.Select();
	
	While Certificates.Next() Do
		
		Try
			Certificate = Certificates.GetObject();
			CertificateData = Certificate.CertificatFile.Get();
			If TypeOf(CertificateData) = Type("BinaryData") Then
				CryptoCertificate = New CryptoCertificate(CertificateData);
				Certificate.EndDate = CryptoCertificate.EndDate;
				InfobaseUpdate.WriteObject(Certificate);
			EndIf;
		Except
		EndTry;
		
	EndDo;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for the replacement of references to "old" certificates

// Handler of the update BED 1.2.4.4
// Creates new items of the DigitalSignaturesAndEncryptionKeyCertificates catalog
//  and fills it with the existing data from the certificates.
//
Procedure MoveCertificateSettings() Export
	
	CryptoApplication = Catalogs.DigitalSignatureAndEncryptionApplications.EmptyRef();
	CryptoApplicationsSelection = Catalogs.DigitalSignatureAndEncryptionApplications.Select();
	While CryptoApplicationsSelection.Next() Do
		If ValueIsFilled(CryptoApplication) Then
			CryptoApplication = Catalogs.DigitalSignatureAndEncryptionApplications.EmptyRef();
		EndIf;
		CryptoApplication = CryptoApplicationsSelection.Ref;
	EndDo;
	
	Query = New Query();
	Query.Text = 
	"SELECT DISTINCT
	|	CompanySignatureCertificates.Ref
	|FROM
	|	Catalog.EDFProfileSettings.CompanySignatureCertificates AS CompanySignatureCertificates
	|WHERE
	|	CompanySignatureCertificates.Certificate = VALUE(Catalog.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef)
	|	AND CompanySignatureCertificates.DeleteCertificate <> VALUE(Catalog.DeleteDSCertificates.EmptyRef)";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		EDFProfileSettings = Selection.Ref.GetObject();
		For Each CertificateSignatures IN EDFProfileSettings.CompanySignatureCertificates Do
			If ValueIsFilled(CertificateSignatures.DeleteCertificate)
				AND Not ValueIsFilled(CertificateSignatures.Certificate) Then
				
				NewCertificate = CommonUse.ObjectAttributeValue(CertificateSignatures.DeleteCertificate, "RefNewCertificate");
				If ValueIsFilled(NewCertificate) Then
					CertificateSignatures.Certificate = NewCertificate;
				Else
					CertificateSignatures.Certificate = MoveItemInDigitalSignaturesAndEncryptionKeyCertificates(CertificateSignatures.DeleteCertificate, CryptoApplication);
				EndIf;
				
			EndIf;
		EndDo;
		
		InfobaseUpdate.WriteObject(EDFProfileSettings);
		
	EndDo;
	
	Query = New Query();
	Query.Text = 
	"SELECT DISTINCT
	|	EDUsageAgreements.Ref
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|WHERE
	|	EDUsageAgreements.CompanyCertificateForDetails = VALUE(Catalog.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef)
	|	AND EDUsageAgreements.DeleteCompanyCertificateForDetails <> VALUE(Catalog.DeleteDSCertificates.EmptyRef)
	|
	|UNION
	|
	|SELECT DISTINCT
	|	CompanySignatureCertificates.Ref
	|FROM
	|	Catalog.EDUsageAgreements.CompanySignatureCertificates AS CompanySignatureCertificates
	|WHERE
	|	CompanySignatureCertificates.Certificate = VALUE(Catalog.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef)
	|	AND CompanySignatureCertificates.DeleteCertificate <> VALUE(Catalog.DeleteDSCertificates.EmptyRef)";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Agreement = Selection.Ref.GetObject();
		
		If ValueIsFilled(Agreement.DeleteCompanyCertificateForDetails)
			AND Not ValueIsFilled(Agreement.CompanyCertificateForDetails) Then
			
			NewCertificate = CommonUse.ObjectAttributeValue(Agreement.DeleteCompanyCertificateForDetails, "RefNewCertificate");
			If ValueIsFilled(NewCertificate) Then
				Agreement.CompanyCertificateForDetails = NewCertificate;
			Else
				Agreement.CompanyCertificateForDetails = MoveItemInDigitalSignaturesAndEncryptionKeyCertificates(Agreement.DeleteCompanyCertificateForDetails, CryptoApplication);
			EndIf;
			
		EndIf;
		
		For Each CertificateSignatures IN Agreement.CompanySignatureCertificates Do
			
			If ValueIsFilled(CertificateSignatures.DeleteCertificate)
				AND Not ValueIsFilled(CertificateSignatures.Certificate) Then
				
				NewCertificate = CommonUse.ObjectAttributeValue(CertificateSignatures.DeleteCertificate, "RefNewCertificate");
				If ValueIsFilled(NewCertificate) Then
					CertificateSignatures.Certificate = NewCertificate;
				Else
					CertificateSignatures.Certificate = MoveItemInDigitalSignaturesAndEncryptionKeyCertificates(CertificateSignatures.DeleteCertificate, CryptoApplication);
				EndIf;
				
			EndIf;
			
		EndDo;
		
		InfobaseUpdate.WriteObject(Agreement);
		
	EndDo;
	
EndProcedure

// Only for internal use.
Function MoveItemInDigitalSignaturesAndEncryptionKeyCertificates(OldCertificate, Application)
	
	OldCertificateObject = OldCertificate.GetObject();
	
	CertificateBinaryData = OldCertificateObject.CertificatFile.Get();
	
	If Not ValueIsFilled(CertificateBinaryData) Then
		Return Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef();
	EndIf;
	
	CertificateObject = Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.CreateItem();
	CertificateObject.CertificateData = New ValueStorage(CertificateBinaryData);
	CertificateObject.Imprint = OldCertificateObject.Imprint;
	
	CertificateObject.AddedBy = UsersClientServer.CurrentUser();
	
	If CertificateObject.CertificateData.Get() <> CertificateBinaryData Then
		CertificateObject.CertificateData = New ValueStorage(CertificateBinaryData);
	EndIf;
	
	If TypeOf(CertificateBinaryData) = Type("String") Then
		UpdateValue(CertificateObject.Signing,     True);
		UpdateValue(CertificateObject.Encryption,     True);
		UpdateValue(CertificateObject.IssuedToWhom,      OldCertificateObject.Description);
		UpdateValue(CertificateObject.ValidUntil, OldCertificateObject.EndDate);
		
		Surname   = OldCertificateObject.Surname;
		Name       = OldCertificateObject.Name;
		Patronymic  = OldCertificateObject.Patronymic;
		Position = OldCertificateObject.PositionByCertificate;
		firm     = OldCertificateObject.Company;
	Else
		CryptoCertificate = New CryptoCertificate(CertificateBinaryData);
		UpdateValue(CertificateObject.Signing, CryptoCertificate.UseToSign);
		UpdateValue(CertificateObject.Encryption, CryptoCertificate.UseForEncryption);
		
		CertificateStructure = DigitalSignatureClientServer.FillCertificateStructure(CryptoCertificate);
		UpdateValue(CertificateObject.IssuedToWhom,      CertificateStructure.IssuedToWhom);
		UpdateValue(CertificateObject.WhoIssued,       CertificateStructure.WhoIssued);
		UpdateValue(CertificateObject.ValidUntil, CertificateStructure.ValidUntil);
		
		SubjectProperties = DigitalSignatureClientServer.CertificateSubjectProperties(CryptoCertificate);
		Surname   = ?(SubjectProperties.Surname   = Undefined, OldCertificateObject.Surname, SubjectProperties.Surname);
		Name       = ?(SubjectProperties.Name       = Undefined, OldCertificateObject.Name, SubjectProperties.Name);
		Patronymic  = ?(SubjectProperties.Patronymic  = Undefined, OldCertificateObject.Patronymic, SubjectProperties.Patronymic);
		Position = ?(SubjectProperties.Position = Undefined, OldCertificateObject.PositionByCertificate, SubjectProperties.Position);
		firm     = SubjectProperties.Company;
	EndIf;
	
	UpdateValue(CertificateObject.Description, OldCertificateObject.Description);
	UpdateValue(CertificateObject.Company,  OldCertificateObject.Company);
	UpdateValue(CertificateObject.User, OldCertificateObject.User);
	UpdateValue(CertificateObject.Surname,   Surname,     True);
	UpdateValue(CertificateObject.Name,       Name,         True);
	UpdateValue(CertificateObject.Patronymic,  Patronymic,    True);
	UpdateValue(CertificateObject.Position, Position,   True);
	UpdateValue(CertificateObject.firm,     firm,       True);
	UpdateValue(CertificateObject.Application, Application,   True);
	
	UpdateValue(CertificateObject.DeletionMark, OldCertificateObject.DeletionMark, True);
	UpdateValue(CertificateObject.Revoked,         OldCertificateObject.Revoked,         True);
	
	SkippedAttributes = New Map;
	SkippedAttributes.Insert("Ref",       True);
	SkippedAttributes.Insert("Description", True);
	SkippedAttributes.Insert("Company",  True);
	SkippedAttributes.Insert("EnhancedProtectionPrivateKey", True);
	
	InfobaseUpdate.WriteObject(CertificateObject);
	
	If OldCertificateObject.RememberCertificatePassword Then
		Data = Constants.EDOperationContext.Get().Get();
		If TypeOf(Data) <> Type("Map") Then
			Data = New Map;
		EndIf;
		Properties = New Structure;
		Properties.Insert("Password", OldCertificateObject.UserPassword);
		If OldCertificateObject.RestrictAccessToCertificate Then
			User = OldCertificateObject.User;
		Else
			User = Catalogs.Users.EmptyRef();
		EndIf;
		Properties.Insert("User", User);
		Data.Insert(CertificateObject.Ref, Properties);
		ValueManager = Constants.EDOperationContext.CreateValueManager();
		ValueManager.Value = New ValueStorage(Data);
		InfobaseUpdate.WriteData(ValueManager);
	EndIf;
	
	If ValueIsFilled(OldCertificateObject.BankApplication) Then
		RecordSet = InformationRegisters.BankApplications.CreateRecordSet();
		RecordSet.Filter.DSCertificate.Set(CertificateObject.Ref);
		RecordSet.Read();
		
		NewRecord = RecordSet.Add();
		NewRecord.Active = True;
		NewRecord.BankApplication = OldCertificateObject.BankApplication;
		NewRecord.DSCertificate = CertificateObject.Ref;
		InfobaseUpdate.WriteData(RecordSet);
	EndIf;
	
	EDKinds = OldCertificateObject.DocumentKinds.Unload(New Structure("UseToSign", True));
	If EDKinds.Count() > 0 Then
		EDKinds.Columns.Find("DocumentKind").Name = "EDKind";
		EDKinds.Columns.Find("UseToSign").Name = "Use";
		EDKinds.Columns.Add("DSCertificate");
		EDKinds.FillValues(CertificateObject.Ref, "DSCertificate");
		RecordSet = InformationRegisters.DigitallySignedEDKinds.CreateRecordSet();
		RecordSet.Filter.DSCertificate.Set(CertificateObject.Ref);
		RecordSet.Read();
		RecordSet.Load(EDKinds);
		InfobaseUpdate.WriteData(RecordSet);
	EndIf;
	
	OldCertificateObject.RefNewCertificate = CertificateObject.Ref;
	InfobaseUpdate.WriteObject(OldCertificateObject);
	
	Return CertificateObject.Ref;
	
EndFunction

// For procedure UpdateCertificatesList, RecordCertificateIntoCatalog.
Procedure UpdateValue(OldValue, NewValue, SkipUndefinedValues = False)
	
	If NewValue = Undefined AND SkipUndefinedValues Then
		Return;
	EndIf;
	
	If OldValue <> NewValue Then
		OldValue = NewValue;
	EndIf;
	
EndProcedure

#EndIf
