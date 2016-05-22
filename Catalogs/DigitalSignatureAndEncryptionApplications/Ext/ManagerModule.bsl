#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns a list of
// attributes that can be edited using the objects batch change data processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	EditableAttributes = New Array;
	Return EditableAttributes;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Function SuppliedApllicationSettings(OnlyForInitialFill = False) Export
	
	Settings = New ValueTable;
	Settings.Columns.Add("Presentation");
	Settings.Columns.Add("ApplicationName");
	Settings.Columns.Add("ApplicationType");
	Settings.Columns.Add("SignAlgorithm");
	Settings.Columns.Add("HashAlgorithm");
	Settings.Columns.Add("EncryptionAlgorithm");
	Settings.Columns.Add("ID");
	
	If Not OnlyForInitialFill Then
		Settings.Columns.Add("SignAlgorithms",     New TypeDescription("Array"));
		Settings.Columns.Add("HashAlgorithms", New TypeDescription("Array"));
		Settings.Columns.Add("EncryptAlgorithms",  New TypeDescription("Array"));
	EndIf;
	
	// ViPNet CSP
	Setting = Settings.Add();
	Setting.Presentation       = NStr("en = 'ViPNet CSP'");
	Setting.ApplicationName        = "Infotecs Cryptographic Service Provider";
	Setting.ApplicationType        = 2;
	// Options: GOST R 34.10-2001, GOST 34.10-2012 256, GOST 34.11-2012 512.
	Setting.SignAlgorithm     = "GOST R 34.10-2001";
	// Options: GOST R 34.11-94,   GOST 34.11-2012 256, GOST 34.11-2012 512.
	Setting.HashAlgorithm = "GOST R 34.11-94";
	Setting.EncryptionAlgorithm  = "GOST 28147-89";     // One option.
	Setting.ID       = "VipNet";
	
	If Not OnlyForInitialFill Then
		Setting.SignAlgorithms.Add("GOST R 34.10-2001");
		Setting.SignAlgorithms.Add("GOST 34.10-2012 256");
		Setting.SignAlgorithms.Add("GOST 34.10-2012 512");
		Setting.HashAlgorithms.Add("GOST R 34.11-94");
		Setting.HashAlgorithms.Add("GOST 34.11-2012 256");
		Setting.HashAlgorithms.Add("GOST 34.11-2012 512");
		Setting.EncryptAlgorithms.Add("GOST 28147-89");
	EndIf;
	
	// CryptoPro CSP
	Setting = Settings.Add();
	Setting.Presentation       = NStr("en = 'CryptoPro CSP'");
	Setting.ApplicationName        = "Crypto-Pro GOST R 34.10-2001 Cryptographic Service Provider";
	Setting.ApplicationType        = 75;
	Setting.SignAlgorithm     = "GOST R 34.10-2001";
	Setting.HashAlgorithm = "GOST R 34.11-94";
	Setting.EncryptionAlgorithm  = "GOST 28147-89";
	Setting.ID       = "CryptoPro";
	
	If OnlyForInitialFill Then
		Return Settings;
	EndIf;
	
	Setting.SignAlgorithms.Add("GOST R 34.10-2001");
	Setting.HashAlgorithms.Add("GOST R 34.11-94");
	Setting.EncryptAlgorithms.Add("GOST 28147-89");
	
	// LISSI CSP
	Setting = Settings.Add();
	Setting.Presentation       = NStr("en = 'LISSI CSP'");
	Setting.ApplicationName        = "LISSI-CSP";
	Setting.ApplicationType        = 75;
	Setting.SignAlgorithm     = "GOST R 34.10-2001";
	Setting.HashAlgorithm = "GOST R 34.11-94";
	Setting.EncryptionAlgorithm  = "GOST 28147-89";
	Setting.ID       = "Lissi";
	
	Setting.SignAlgorithms.Add("GOST R 34.10-2001");
	Setting.HashAlgorithms.Add("GOST R 34.11-94");
	Setting.EncryptAlgorithms.Add("GOST 28147-89");
	
	// SignalCOM CSP (RFC 4357)
	Setting = Settings.Add();
	Setting.Presentation       = NStr("en = 'SignalCOM CSP (RFC 4357)'");
	Setting.ApplicationName        = "Signal-COM CPGOST Cryptographic Provider";
	Setting.ApplicationType        = 75;
	Setting.SignAlgorithm     = "ECR3410-CP";
	Setting.HashAlgorithm = "RUS-HASH-CP";
	Setting.EncryptionAlgorithm  = "GOST28147";
	Setting.ID       = "SignalComCPGOST";
	
	Setting.SignAlgorithms.Add("ECR3410-CP");
	Setting.HashAlgorithms.Add("RUS-HASH-CP");
	Setting.EncryptAlgorithms.Add("GOST28147");
	
	// SignalCOM CSP (ITUT X.509 v.3).
	Setting = Settings.Add();
	Setting.Presentation       = NStr("en = 'Signal-COM CSP (ITU-T X.509 v.3)'");
	Setting.ApplicationName        = "Signal-COM ECGOST Cryptographic Provider";
	Setting.ApplicationType        = 129;
	Setting.SignAlgorithm     = "ECR3410";
	Setting.HashAlgorithm = "RUS-HASH";
	Setting.EncryptionAlgorithm  = "GOST28147";
	Setting.ID       = "SignalComECGOST";
	
	Setting.SignAlgorithms.Add("ECR3410");
	Setting.HashAlgorithms.Add("RUS-HASH");
	Setting.EncryptAlgorithms.Add("GOST28147");
	
	// Microsoft Enhanced CSP
	Setting = Settings.Add();
	Setting.Presentation       = NStr("en = 'Microsoft Enhanced CSP'");
	Setting.ApplicationName        = "Microsoft Enhanced Cryptographic Provider v1.0";
	Setting.ApplicationType        = 1;
	Setting.SignAlgorithm     = "RSA_SIGN"; // One option.
	Setting.HashAlgorithm = "MD5";      // Options: SHA1, MD2, MD4, MD5.
	Setting.EncryptionAlgorithm  = "RC2";      // Options: RC2, RC4, DES, 3DES.
	Setting.ID       = "MicrosoftEnhanced";
	
	Setting.SignAlgorithms.Add("RSA_SIGN");
	Setting.HashAlgorithms.Add("SHA-1");
	Setting.HashAlgorithms.Add("MD2");
	Setting.HashAlgorithms.Add("MD4");
	Setting.HashAlgorithms.Add("MD5");
	Setting.EncryptAlgorithms.Add("RC2");
	Setting.EncryptAlgorithms.Add("RC4");
	Setting.EncryptAlgorithms.Add("DES");
	Setting.EncryptAlgorithms.Add("3DES");
	
	Return Settings;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Info base update.

Procedure FillInitialSettings() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Applications.Ref AS Ref
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionApplications AS Applications
	|WHERE
	|	Applications.ApplicationName = &ApplicationName
	|	AND Applications.ApplicationType = &ApplicationType";
	
	SuppliedSettings = SuppliedApllicationSettings(True);
	For Each SuppliedSetting IN SuppliedSettings Do
		
		Query.SetParameter("ApplicationName", SuppliedSetting.ApplicationName);
		Query.SetParameter("ApplicationType", SuppliedSetting.ApplicationType);
		
		If Not Query.Execute().IsEmpty() Then
			Continue;
		EndIf;
		
		ApplicationObject = Catalogs.DigitalSignatureAndEncryptionApplications.CreateItem();
		FillPropertyValues(ApplicationObject, SuppliedSetting);
		ApplicationObject.Description = SuppliedSetting.Presentation;
		InfobaseUpdate.WriteData(ApplicationObject);
	EndDo;
	
EndProcedure

#EndRegion

#EndIf

#Region EventsHandlers

Procedure FormGetProcessing(FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormKind = "ListForm" Then
		StandardProcessing = False;
		Parameters.Insert("ShowApplicationPage");
		SelectedForm = Metadata.CommonForms.DigitalSignaturesAndEncryptionSettings;
	EndIf;
	
EndProcedure

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	Parameters.Filter.Insert("DeletionMark", False);
	
EndProcedure

#EndRegion
