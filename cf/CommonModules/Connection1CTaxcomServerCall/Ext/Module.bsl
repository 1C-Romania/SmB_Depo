
////////////////////////////////////////////////////////////////////////////////
// 1C Taxcom Connection subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Determines whether the current user
// is exposed to 1C Taxcom service use according to the current work mode and user rights.
//
// Returns:
// Boolean - True - use is available, False - otherwise.
//
Function Available1CTaxcomServiceUse() Export
	
	Return (OnlineUserSupport.UseOnlineSupportAllowedInCurrentOperationMode()
		AND Users.RolesAvailable("Use1CTaxcomService", , False));
	
EndFunction

#EndRegion

#Region ServiceProgramInterface

// Returns thumbprint of the specified certificate.
//
// Parameters:
// Certificate - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates
// 	certificates catalog reference.
//
// Returns:
// String - Thumbprint of the specified certificate;
// Undefined - if the certificate is not found in the certificates catalogs.
//
Function CertificateThumbprint(Certificate) Export
	
	Return CommonUse.ObjectAttributeValue(Certificate, "Imprint");
	
EndFunction

#EndRegion