////////////////////////////////////////////////////////////////////////////////
// Digital signature subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Only for internal use.
Function CommonSettings() Export
	
	CommonSettings = New Structure;
	
	SetPrivilegedMode(True);
	
	CommonSettings.Insert("UseDigitalSignatures",
		Constants.UseDigitalSignatures.Get());
	
	CommonSettings.Insert("UseEncryption",
		Constants.UseEncryption.Get());
	
	If CommonUseReUse.DataSeparationEnabled()
	 Or CommonUse.FileInfobase()
	   AND Not CommonUseClientServer.ClientConnectedViaWebServer() Then
		
		CommonSettings.Insert("VerifyDigitalSignaturesAtServer", False);
		CommonSettings.Insert("CreateDigitalSignaturesAtServer", False);
	Else
		CommonSettings.Insert("VerifyDigitalSignaturesAtServer",
			Constants.VerifyDigitalSignaturesAtServer.Get());
		
		CommonSettings.Insert("CreateDigitalSignaturesAtServer",
			Constants.CreateDigitalSignaturesAtServer.Get());
	EndIf;
	
	// Use subsystems.
	// 1. Contact information subsystem  - Russian address.
	// 2. Subsystem Address Classifier - state code by name.
	// 3. Print subsystem - standard printed form for the certificate issue application.
	// 4. Subsystem Work with counterparties - check TIN, OGRN, personal accounts by BIC, INILA.
	
	CommonSettings.Insert("CertificateIssueApplicationAvailable",
		  CommonUse.SubsystemExists("StandardSubsystems.ContactInformation")
		AND CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier")
		AND CommonUse.SubsystemExists("StandardSubsystems.Print")
		AND CommonUse.SubsystemExists("StandardSubsystems.WorkWithCounterparties"));
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	application.Ref,
	|	application.Description AS Description,
	|	application.ApplicationName,
	|	application.ApplicationType,
	|	application.SignAlgorithm,
	|	application.HashAlgorithm,
	|	application.EncryptionAlgorithm
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionApplications AS application
	|WHERE
	|	Not application.DeletionMark
	|
	|ORDER BY
	|	Description";
	
	Selection = Query.Execute().Select();
	ApplicationsDescription = New Array;
	SuppliedSettings = Catalogs.DigitalSignatureAndEncryptionApplications.SuppliedApllicationSettings();
	
	While Selection.Next() Do
		Filter = New Structure("ApplicationName, ApplicationType", Selection.ApplicationName, Selection.ApplicationType);
		Rows = SuppliedSettings.FindRows(Filter);
		ID = ?(Rows.Count() = 0, "", Rows[0].ID);
		
		Description = New Structure;
		Description.Insert("Ref",              Selection.Ref);
		Description.Insert("Description",        Selection.Description);
		Description.Insert("ApplicationName",        Selection.ApplicationName);
		Description.Insert("ApplicationType",        Selection.ApplicationType);
		Description.Insert("SignAlgorithm",     Selection.SignAlgorithm);
		Description.Insert("HashAlgorithm", Selection.HashAlgorithm);
		Description.Insert("EncryptionAlgorithm",  Selection.EncryptionAlgorithm);
		Description.Insert("ID",       ID);
		ApplicationsDescription.Add(New FixedStructure(Description));
	EndDo;
	
	CommonSettings.Insert("ApplicationsDescription", New FixedArray(ApplicationsDescription));
	
	Return New FixedStructure(CommonSettings);
	
EndFunction

#EndRegion
