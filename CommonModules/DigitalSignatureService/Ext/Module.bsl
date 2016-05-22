////////////////////////////////////////////////////////////////////////////////
// Digital signature subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceApplicationInterface

////////////////////////////////////////////////////////////////////////////////
// Add handlers of the service events (subsriptions).

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ModuleName = "DigitalSignatureService";
	
	EventName = "StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers";
	ServerHandlers[EventName].Add(ModuleName);
	
	EventName = "StandardSubsystems.BasicFunctionality\OnAddMetadataObjectsRenaming";
	ServerHandlers[EventName].Add(ModuleName);
	
	EventName = "StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems";
	ServerHandlers[EventName].Add(ModuleName);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of service events.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//   Handlers - ValueTable - see InfobaseUpdate.UpdateHandlersNewTable().
//
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "Catalogs.DigitalSignatureAndEncryptionApplications.FillInitialSettings";
	Handler.PerformModes = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.4.7";
	Handler.Procedure = "DigitalSignatureService.TransferCryptographyManagerSettings";
	Handler.PerformModes = "Exclusive";
	
EndProcedure

// Fills those metadata objects renaming that can not be automatically found by type, but the references to which are to be stored in the database (for example, subsystems, roles).
//
// See also:
//   CommonUse.AddRenaming().
//
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	OldName = "Role.EDSUse";
	NewName  = "Role.DSUsage";
	CommonUse.AddRenaming(Total, "2.2.1.7", OldName, NewName, Library);
	
	OldName = "Subsystem.StandardSubsystems.Subsystem.ElectronicDigitalSignature";
	NewName  = "Subsystem.StandardSubsystems.Subsystem.DigitalSignature";
	CommonUse.AddRenaming(Total, "2.2.1.7", OldName, NewName, Library);
	
EndProcedure

// Defines the parameters of client work.
//
// Parameters:
//   Parameters - Structure - All client work parameters.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystems(Parameters) Export
	
	If CommonUseReUse.CanUseSeparatedData() Then
		SubsystemSettings = New Structure;
		SubsystemSettings.Insert("PersonalSettings", DigitalSignature.PersonalSettings());
		SubsystemSettings.Insert("CommonSettings",        DigitalSignature.CommonSettings());
		SubsystemSettings = New FixedStructure(SubsystemSettings);
		Parameters.Insert("DigitalSignature", SubsystemSettings);
	EndIf;
	
EndProcedure

// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  ImportedCatalogs - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      Author presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	// Import to the DigitalSignatureAndEncryptionApplications catalog is forbidden.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.DigitalSignatureAndEncryptionApplications.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
	// Import to the DigitalSignaturesAndEncryptionKeyCertificates catalog is forbidden.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
EndProcedure

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.DigitalSignatureAndEncryptionApplications.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.FullName(), "NotEditableInGroupProcessingAttributes");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

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
//                 - Structure - contains errors accessing the applications if Undefined is returned.
//                    * ErrorDescription   - String - full description of an error when it is returned as a row.
//                    * ErrorTitle  - String - error title corresponding to the operation.
//                    *ComputerName    - String - name of the computer while receiving a cryptography manager.
//                    *Description         - String - general error description.
//                    *Common            - Boolean - if true, then it contains an error description
//                                                  for all applications, else alternative description to the Errors array.
//                    * ToAdmin  - Boolean - to correct a common error you must be an administrator.
//                    *Errors           - Array - contains structures of applications errors description with properties.:
//                         * Application       - CatalogRef.DigitalSignatureAndEncryptionApplications.
//                         *Description        - String - contains error presentation.
//                         * FromException    - Boolean - description contains a brief presentation of information about error.
//                         * PathNotSpecified    - Boolean - description contains an error on an unspecified way for OC Linux.
//                         * ToAdmin - Boolean - to correct an error you must be an administrator.
//
//  Application      - Undefined - returns the cryptography
//                   manager of the first application from the catalog created for it.
//                 - CatalogRef.DigitalSignatureAndEncryptionApplications - application
//                   for which you need to create and return the cryptography manager.
//
// Returns:
//   CryptoManager - cryptography manager .
//   Undefined - an error occurred which description is located in the ErrorDescription parameter.
//
Function CryptoManager(Operation, ShowError = True, ErrorDescription = "", Application = Undefined) Export
	
	ComputerName = ComputerName();
	
	Errors = New Array;
	Manager = NewCryptographyManager(Application, Errors, ComputerName);
	
	If Manager <> Undefined Then
		Return Manager;
	EndIf;
	
	If Operation = "Signing" Then
		ErrorTitle = NStr("en = 'Unable to sign data on the %1 server because:'");
		
	ElsIf Operation = "SignatureCheck" Then
		ErrorTitle = NStr("en = 'Unable to check a signature on the %1 server because:'");
		
	ElsIf Operation = "Encryption" Then
		ErrorTitle = NStr("en = 'Unable to encrypt data on the %1 server because:'");
		
	ElsIf Operation = "Details" Then
		ErrorTitle = NStr("en = 'Unable to decrypt data on the %1 server because:'");
		
	ElsIf Operation = "CertificateCheck" Then
		ErrorTitle = NStr("en = 'Unable to check certificate on the %1 server because:'");
		
	ElsIf Operation = "GetCertificates" Then
		ErrorTitle = NStr("en = 'Unable to get certificates on %1 server because:'");
		
	ElsIf Operation <> "" Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Error in the CryptographyManager function.
			           |Wrong of the %1 Operation parameter value.'"), Operation);
		
	ElsIf TypeOf(ErrorDescription) = Type("Structure")
	        AND ErrorDescription.Property("ErrorTitle") Then
		
		ErrorTitle = ErrorDescription.ErrorTitle;
	Else
		ErrorTitle = NStr("en = 'Unable to run an operation on the %1 server because:'");
	EndIf;
	
	ErrorTitle = StringFunctionsClientServer.PlaceParametersIntoString(ErrorTitle, ComputerName);
	
	ErrorProperties = New Structure;
	ErrorProperties.Insert("ErrorTitle", ErrorTitle);
	ErrorProperties.Insert("ComputerName", ComputerName);
	ErrorProperties.Insert("ToAdmin", True);
	ErrorProperties.Insert("Common", False);
	ErrorProperties.Insert("Errors", Errors);
	
	If Errors.Count() = 0 Then
		ErrorText = NStr("en = 'Use of no application is expected.'");
		ErrorProperties.Common = True;
		ErrorProperties.Insert("Instruction", True);
		ErrorProperties.Insert("ApplicationsSetting", True);
		
	ElsIf ValueIsFilled(Application) Then
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = '%1 application is not available or installed.'"), Application);
	Else
		ErrorText = NStr("en = 'No application is available or installed.'");
	EndIf;
	ErrorProperties.Insert("Description", ErrorText);
	
	If Not Users.InfobaseUserWithFullAccess(,, False) Then
		ErrorText = ErrorText + Chars.LF + Chars.LF
			+ NStr("en = 'Contact your administrator.'");
	EndIf;
	
	ErrorProperties.Insert("ErrorDescription", ErrorTitle + Chars.LF + ErrorText);
	
	If TypeOf(ErrorDescription) = Type("Structure") Then
		ErrorDescription = ErrorProperties;
	Else
		ErrorDescription = ErrorProperties.ErrorDescription;
	EndIf;
	
	If ShowError Then
		Raise ErrorText;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Finds a certificate on the computer by the thumbprint row.
//
// Parameters:
//   Imprint              - String - Base64 encoded thumbprint of certificate.
//   InPersonalStorageOnly - Boolean - if True, then search the personal storage, otherwise, everywhere.
//
// Returns:
//   CryptoCertificate - certificate of digital signature and encryption.
//   Undefined - certificate is not found.
//
Function GetCertificateByImprint(Imprint, InPersonalStorageOnly,
			ShowError = True, Application = Undefined, ErrorDescription = "") Export
	
	CryptoManager = CryptoManager("GetCertificates",
		ShowError, ErrorDescription, Application);
	
	If CryptoManager = Undefined Then
		Return Undefined;
	EndIf;
	
	StorageType = DigitalSignatureServiceClientServer.StorageTypeToSearchCertificates(InPersonalStorageOnly);
	
	Try
		BinaryDataImprint = Base64Value(Imprint);
	Except
		If ShowError Then
			Raise;
		EndIf;
		ErrorInfo = ErrorInfo();
		ErrorPresentation = BriefErrorDescription(ErrorInfo);
	EndTry;
	
	If Not ValueIsFilled(ErrorPresentation) Then
		Try
			StorageOfCertificates = CryptoManager.GetCertificateStore(StorageType);
		Except
			If ShowError Then
				Raise;
			EndIf;
			ErrorInfo = ErrorInfo();
			ErrorPresentation = BriefErrorDescription(ErrorInfo);
		EndTry;
	EndIf;
	
	If Not ValueIsFilled(ErrorPresentation) Then
		Try
			Certificate = StorageOfCertificates.FindByThumbprint(BinaryDataImprint);
		Except
			If ShowError Then
				Raise;
			EndIf;
			ErrorInfo = ErrorInfo();
			ErrorPresentation = BriefErrorDescription(ErrorInfo);
		EndTry;
	EndIf;
	
	If TypeOf(Certificate) = Type("CryptoCertificate") Then
		Return Certificate;
	EndIf;
	
	If ValueIsFilled(ErrorPresentation) Then
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Certificate is not found
			           |on the server because: %1
			           |'"),
			ErrorPresentation);
	Else
		ErrorText = NStr("en = 'Certificate is not found on server.'");
	EndIf;
		
	If Not Users.InfobaseUserWithFullAccess(,, False) Then
		ErrorText = ErrorText + Chars.LF + NStr("en = 'Contact your administrator.'")
	EndIf;
	
	ErrorText = TrimR(ErrorText);
	
	If TypeOf(ErrorDescription) = Type("Structure") Then
		ErrorDescription = New Structure;
		ErrorDescription.Insert("ErrorDescription", ErrorText);
	Else
		ErrorDescription = ErrorPresentation;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Saves the settings of the current user to work with digital signature.
Procedure SavePersonalSettings(PersonalSettings) Export
	
	SubsystemKey = SettingsStorageKey();
	
	For Each KeyAndValue IN PersonalSettings Do
		CommonUse.CommonSettingsStorageSave(SubsystemKey, KeyAndValue.Key,
			KeyAndValue.Value);
	EndDo;
	
EndProcedure

// Key used to store subsystem settings.
Function SettingsStorageKey() Export
	
	Return "EDS"; // Do not replace with DS. Used for the reverse compatibility.
	
EndFunction

// Only for internal use.
Procedure BeforeEditKeyCertificate(Refs, Certificate, AttributesParameters) Export
	
	Table = New ValueTable;
	Table.Columns.Add("AttributeName",       New TypeDescription("String"));
	Table.Columns.Add("ReadOnly",     New TypeDescription("Boolean"));
	Table.Columns.Add("FillChecking", New TypeDescription("Boolean"));
	Table.Columns.Add("Visible",          New TypeDescription("Boolean"));
	Table.Columns.Add("FillValue");
	
	DigitalSignatureOverridable.BeforeEditKeyCertificate(Refs, Certificate, Table);
	
	AttributesParameters = New Structure;
	
	For Each String IN Table Do
		Parameters = New Structure;
		Parameters.Insert("ReadOnly",     String.ReadOnly);
		Parameters.Insert("FillChecking", String.FillChecking);
		Parameters.Insert("Visible",          String.Visible);
		Parameters.Insert("FillValue", String.FillValue);
		AttributesParameters.Insert(String.AttributeName, Parameters);
	EndDo;
	
EndProcedure

// Only for internal use.
Procedure CheckPresentationUniqueness(Presentation, CertificatRef, Field, Cancel) Export
	
	If Not ValueIsFilled(Presentation) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref",       CertificatRef);
	Query.SetParameter("Description", Presentation);
	
	Query.Text =
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
	|WHERE
	|	Certificates.Ref <> &Refs
	|	AND Certificates.Description = &Description";
	
	If Not Query.Execute().IsEmpty() Then
		MessageText = NStr("en = 'Certificate with this presentation already exists.'");
		CommonUseClientServer.MessageToUser(MessageText,, Field,, Cancel);
	EndIf;
	
EndProcedure


// Only for internal use.
Procedure UpdateCertificatesList(Certificates, CertificatesPropertiesOnClient, ExceptAlreadyAdded,
				Pesonal, Error, WithoutFilter) Export
	
	CertificatesPropertiesTable = New ValueTable;
	CertificatesPropertiesTable.Columns.Add("Imprint", New TypeDescription("String",,,, New StringQualifiers(255)));
	CertificatesPropertiesTable.Columns.Add("WhoIssued");
	CertificatesPropertiesTable.Columns.Add("Presentation");
	CertificatesPropertiesTable.Columns.Add("AtClient",    New TypeDescription("Boolean"));
	CertificatesPropertiesTable.Columns.Add("AtServer",    New TypeDescription("Boolean"));
	CertificatesPropertiesTable.Columns.Add("ThisRequest", New TypeDescription("Boolean"));
	
	For Each CertificateProperties IN CertificatesPropertiesOnClient Do
		NewRow = CertificatesPropertiesTable.Add();
		FillPropertyValues(NewRow, CertificateProperties);
		NewRow.AtClient = True;
	EndDo;
	
	CertificatesPropertiesTable.Indexes.Add("Imprint");
	
	If DigitalSignature.CommonSettings().CreateDigitalSignaturesAtServer Then
		
		CryptoManager = CryptoManager("GetCertificates", False, Error);
		If CryptoManager <> Undefined Then
			
			CertificatesArray = CryptoManager.GetCertificateStore(
				CryptoCertificateStoreType.PersonalCertificates).GetAll();
			
			If Not Pesonal Then
				Array = CryptoManager.GetCertificateStore(
					CryptoCertificateStoreType.RecipientCertificates).GetAll();
				
				For Each Certificate IN Array Do
					CertificatesArray.Add(Certificate);
				EndDo;
			EndIf;
			
			DigitalSignatureServiceClientServer.AddCertificatesProperties(
				CertificatesPropertiesTable, CertificatesArray, WithoutFilter);
		EndIf;
	EndIf;
	
	ProcessAddedCertificates(CertificatesPropertiesTable, Not WithoutFilter AND ExceptAlreadyAdded);
	
	CertificatesPropertiesTable.Indexes.Add("Presentation");
	CertificatesPropertiesTable.Sort("Presentation Asc");
	
	RowsProcessed  = New Map;
	IndexOf = 0;
	Filter = New Structure("Imprint", "");
	
	For Each CertificateProperties IN CertificatesPropertiesTable Do
		Filter.Imprint = CertificateProperties.Imprint;
		Rows = Certificates.FindRows(Filter);
		If Rows.Count() = 0 Then
			If Certificates.Count()-1 < IndexOf Then
				String = Certificates.Add();
			Else
				String = Certificates.Insert(IndexOf);
			EndIf;
		Else
			String = Rows[0];
			RowIndex = Certificates.IndexOf(String);
			If RowIndex <> IndexOf Then
				Certificates.Move(RowIndex, IndexOf - RowIndex);
			EndIf;
		EndIf;
		// Update only the changed values not to update the form table once again.
		UpdateValue(String.Imprint,      CertificateProperties.Imprint);
		UpdateValue(String.Presentation,  CertificateProperties.Presentation);
		UpdateValue(String.WhoIssued,       CertificateProperties.WhoIssued);
		UpdateValue(String.AtClient,      CertificateProperties.AtClient);
		UpdateValue(String.AtServer,      CertificateProperties.AtServer);
		UpdateValue(String.ThisRequest,   CertificateProperties.ThisRequest);
		RowsProcessed.Insert(String, True);
		IndexOf = IndexOf + 1;
	EndDo;
	
	IndexOf = Certificates.Count()-1;
	While IndexOf >=0 Do
		String = Certificates.Get(IndexOf);
		If RowsProcessed.Get(String) = Undefined Then
			Certificates.Delete(IndexOf);
		EndIf;
		IndexOf = IndexOf-1;
	EndDo;
	
EndProcedure

// Only for internal use.
Procedure FillExistingUserCertificates(ChoiceList, CertificateThumbprintsAtClient,
			FilterCertificates, PrintsFilter = Undefined) Export
	
	ChoiceList.Clear();
	
	If DigitalSignature.CommonSettings().CreateDigitalSignaturesAtServer Then
		
		CryptoManager = CryptoManager("GetCertificates", False);
		
		If CryptoManager <> Undefined Then
			StorageType = CryptoCertificateStoreType.PersonalCertificates;
			CertificatesArray = CryptoManager.GetCertificateStore(StorageType).GetAll();
			
			DigitalSignatureServiceClientServer.AddCertificatesPrints(
				CertificateThumbprintsAtClient, CertificatesArray);
		EndIf;
	EndIf;
	
	If FilterCertificates.Count() > 0 Then
		For Each ItemOfList IN FilterCertificates Do
			Properties = CommonUse.ObjectAttributesValues(
				ItemOfList.Value, "Reference, Name, Thumbprint");
			
			If CertificateThumbprintsAtClient.Find(Properties.Imprint) <> Undefined Then
				ChoiceList.Add(Properties.Ref, Properties.Description);
			EndIf;
		EndDo;
		Return;
	EndIf;
	
	If PrintsFilter <> Undefined Then
		Filter = GetFromTempStorage(PrintsFilter);
		Prints = New Array;
		For Each Imprint IN CertificateThumbprintsAtClient Do
			If Filter[Imprint] = Undefined Then
				Continue;
			EndIf;
			ChoiceList.Add(Imprint, Filter[Imprint]);
		EndDo;
		Query = New Query;
		Query.Parameters.Insert("Prints", ChoiceList.UnloadValues());
		Query.Text =
		"SELECT
		|	Certificates.Ref AS Ref,
		|	Certificates.Description AS Description,
		|	Certificates.Imprint
		|FROM
		|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
		|WHERE
		|	Certificates.Imprint IN(&Prints)";
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			ItemOfList = ChoiceList.FindByValue(Selection.Imprint);
			If ItemOfList <> Undefined Then
				ItemOfList.Value = Selection.Ref;
				ItemOfList.Presentation = Selection.Description;
			EndIf;
		EndDo;
		ChoiceList.SortByPresentation();
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("User", UsersClientServer.CurrentUser());
	Query.Parameters.Insert("Prints", CertificateThumbprintsAtClient);
	Query.Text =
	"SELECT
	|	Certificates.Ref AS Ref,
	|	Certificates.Description AS Description
	|FROM
	|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
	|WHERE
	|	Certificates.Application <> VALUE(Catalog.DigitalSignatureAndEncryptionApplications.EmptyRef)
	|	AND Certificates.User = &User
	|	AND Certificates.Revoked = FALSE
	|	AND Certificates.Imprint IN(&Prints)
	|
	|ORDER BY
	|	Description";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ChoiceList.Add(Selection.Ref, Selection.Description);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions of the managed forms.

// Only for internal use.
Procedure ConfigureSigningEncryptionDecryptionForm(Form, Encryption = False, Details = False) Export
	
	Items  = Form.Items;
	Parameters = Form.Parameters;
	
	Form.Title = Parameters.Operation;
	
	Form.PerformAtServer = Parameters.PerformAtServer;
	
	If Encryption Then
		If Form.SpecifiedCertificatesSet Then
			Form.WithoutConfirmation = Parameters.WithoutConfirmation;
		EndIf;
	Else
		If TypeOf(Parameters.FilterCertificates) = Type("Array") Then
			Form.FilterCertificates.LoadValues(Parameters.FilterCertificates);
		EndIf;
		Form.WithoutConfirmation = Parameters.WithoutConfirmation;
	EndIf;
	
	If ValueIsFilled(Parameters.DataTitle) Then
		Items.DataPresentation.Title = Parameters.DataTitle;
	Else
		Items.DataPresentation.TitleLocation = FormItemTitleLocation.None;
	EndIf;
	
	Form.DataPresentation = Parameters.DataPresentation;
	Items.DataPresentation.Hyperlink = Parameters.DataPresentationOpens;
	
	If Not ValueIsFilled(Form.DataPresentation) Then
		Items.DataPresentation.Visible = False;
	EndIf;
	
	If Details Then
		FillThumbprintsFilter(Form);
	ElsIf Not Encryption Then // Signing
		Items.CommentGroup.Visible = Parameters.ShowComment AND Not Form.WithoutConfirmation;
	EndIf;
	
	FillExistingUserCertificates(Form.CertificateChoiceList,
		Parameters.CertificateThumbprintsAtClient, Form.FilterCertificates, Form.PrintsFilter);
	
	Certificate = Undefined;
	
	If Details Then
		For Each ItemOfList IN Form.CertificateChoiceList Do
			If TypeOf(ItemOfList.Value) = Type("String") Then
				Continue;
			EndIf;
			Certificate = ItemOfList.Value;
			Break;
		EndDo;
		
	ElsIf AccessRight("SaveUserData", Metadata) Then
		If Encryption Then
			Certificate = CommonSettingsStorage.Load("Cryptography", "CertificateForEncryption");
		Else
			Certificate = CommonSettingsStorage.Load("Cryptography", "CertificateForSigning");
		EndIf;
	EndIf;
	
	If Form.FilterCertificates.Count() > 1 Then
		Certificate = Undefined;
	ElsIf Form.FilterCertificates.Count() = 1 Then
		Certificate = Form.FilterCertificates[0].Value;
	EndIf;
	
	Form.Certificate = Certificate;
	
	If ValueIsFilled(Form.Certificate)
	   AND CommonUse.ObjectAttributeValue(Form.Certificate, "Ref") <> Form.Certificate Then
		
		Form.Certificate = Undefined;
	EndIf;
	
	If ValueIsFilled(Form.Certificate) Then
		If Encryption Then
			Items.EncryptionCertificates.DefaultItem = True;
		Else
			Items.Password.DefaultItem = True;
		EndIf;
	Else
		Items.Certificate.DefaultItem = True;
	EndIf;
	
	FillCertificateAdditionalProperties(Form);
	
	Form.CryptoManagerAtServerErrorDescription = New Structure;
	If DigitalSignatureClientServer.CommonSettings().CreateDigitalSignaturesAtServer Then
		CryptoManager("GetCertificates",
			False, Form.CryptoManagerAtServerErrorDescription);
	EndIf;
	
	If Not Encryption Then
		DigitalSignatureOverridable.BeforeOperationBeginning(?(Details, "Details", "Signing"),
			Parameters.AdditionalActionsParameters, Form.WeekendsAdditionalActionsParameters);
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure CertificateOnChangeAtServer(Form, CertificateThumbprintsAtClient, Encryption = False, Details = False) Export
	
	If Form.FilterCertificates.Count() = 0
	   AND AccessRight("SaveUserData", Metadata) Then
		
		If Encryption Then
			CommonSettingsStorage.Save("Cryptography", "CertificateForEncryption", Form.Certificate);
		ElsIf Not Details Then
			CommonSettingsStorage.Save("Cryptography", "CertificateForSigning", Form.Certificate);
		EndIf;
	EndIf;
	
	FillExistingUserCertificates(Form.CertificateChoiceList,
		CertificateThumbprintsAtClient, Form.FilterCertificates, Form.PrintsFilter);
	
	FillCertificateAdditionalProperties(Form);
	
EndProcedure

// Only for internal use.
Function CerfiticateSavedProperties(Imprint, Address, AttributesParameters, ForEncryption = False) Export
	
	SavedProperties = New Structure;
	SavedProperties.Insert("Ref");
	SavedProperties.Insert("Description");
	SavedProperties.Insert("User");
	SavedProperties.Insert("Company");
	SavedProperties.Insert("EnhancedProtectionPrivateKey");
	
	Query = New Query;
	Query.SetParameter("Imprint", Imprint);
	Query.Text =
	"SELECT
	|	Certificates.Ref AS Ref,
	|	Certificates.Description AS Description,
	|	Certificates.User,
	|	Certificates.Company,
	|	Certificates.EnhancedProtectionPrivateKey,
	|	Certificates.CertificateData
	|FROM
	|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
	|WHERE
	|	Certificates.Imprint = &Imprint";
	
	CryptoCertificate = New CryptoCertificate(GetFromTempStorage(Address));
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(SavedProperties, Selection);
	Else
		SavedProperties.Ref = Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef();
		If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
			CompaniesServiceModule = CommonUse.CommonModule("CompaniesService");
			If Not ForEncryption Then
				SavedProperties.Company = CompaniesServiceModule.CompanyByDefault();
			EndIf;
		EndIf;
		SavedProperties.Description = DigitalSignatureClientServer.CertificatePresentation(CryptoCertificate);
		If Not ForEncryption Then
			SavedProperties.User = UsersClientServer.CurrentUser();
		EndIf;
	EndIf;
	
	BeforeEditKeyCertificate(
		SavedProperties.Ref, CryptoCertificate, AttributesParameters);
	
	If Not ValueIsFilled(SavedProperties.Ref) Then
		FillAttribute(SavedProperties, AttributesParameters, "Description");
		FillAttribute(SavedProperties, AttributesParameters, "User");
		FillAttribute(SavedProperties, AttributesParameters, "Company");
		FillAttribute(SavedProperties, AttributesParameters, "EnhancedProtectionPrivateKey");
	EndIf;
	
	Return SavedProperties;
	
EndFunction

// Only for internal use.
Procedure WriteCertificateToCatalog(Form, Application = Undefined, ForEncryption = False) Export
	
	CertificateBinaryData = GetFromTempStorage(Form.CertificateAddress);
	CryptoCertificate = New CryptoCertificate(CertificateBinaryData);
	
	If ValueIsFilled(Form.Certificate) Then
		CertificateObject = Form.Certificate.GetObject();
	Else
		CertificateObject = Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.CreateItem();
		CertificateObject.CertificateData = New ValueStorage(CertificateBinaryData);
		CertificateObject.Imprint = Form.CertificateThumbprint;
		
		CertificateObject.AddedBy = UsersClientServer.CurrentUser();
	EndIf;
	
	If Not ForEncryption Then
		UpdateValue(CertificateObject.Application, Application);
	EndIf;
	
	If CertificateObject.CertificateData.Get() <> CertificateBinaryData Then
		CertificateObject.CertificateData = New ValueStorage(CertificateBinaryData);
	EndIf;
	
	UpdateValue(CertificateObject.Signing, CryptoCertificate.UseToSign);
	UpdateValue(CertificateObject.Encryption, CryptoCertificate.UseForEncryption);
	
	UpdateValue(CertificateObject.Description, Form.CertificateName);
	UpdateValue(CertificateObject.Company,  Form.CertificateCompany);
	UpdateValue(CertificateObject.User, Form.CertificateUser);
	
	If Not ForEncryption Then
		UpdateValue(CertificateObject.EnhancedProtectionPrivateKey, Form.CertificateEnhancedProtectionPrivateKey);
	EndIf;
	
	CertificateStructure = DigitalSignatureClientServer.FillCertificateStructure(CryptoCertificate);
	UpdateValue(CertificateObject.IssuedToWhom,      CertificateStructure.IssuedToWhom);
	UpdateValue(CertificateObject.WhoIssued,       CertificateStructure.WhoIssued);
	UpdateValue(CertificateObject.ValidUntil, CertificateStructure.ValidUntil);
	
	SubjectProperties = DigitalSignatureClientServer.CertificateSubjectProperties(CryptoCertificate);
	UpdateValue(CertificateObject.Surname,   SubjectProperties.Surname,     True);
	UpdateValue(CertificateObject.Name,       SubjectProperties.Name,         True);
	UpdateValue(CertificateObject.Patronymic,  SubjectProperties.Patronymic,    True);
	UpdateValue(CertificateObject.Position, SubjectProperties.Position,   True);
	UpdateValue(CertificateObject.firm,     SubjectProperties.Company, True);
	
	If CertificateObject.IsNew() Then
		SkippedAttributes = New Map;
		SkippedAttributes.Insert("Ref",       True);
		SkippedAttributes.Insert("Description", True);
		SkippedAttributes.Insert("Company",  True);
		SkippedAttributes.Insert("EnhancedProtectionPrivateKey", True);
		If Not ForEncryption AND Form.PersonalListOnAdd Then
			SkippedAttributes.Insert("User",  True);
		EndIf;
		For Each KeyAndValue IN Form.CertificateAttributesParameters Do
			AttributeName = KeyAndValue.Key;
			Properties     = KeyAndValue.Value;
			If SkippedAttributes.Get(AttributeName) <> Undefined Then
				Continue;
			EndIf;
			UpdateValue(CertificateObject[AttributeName], Properties.FillValue, True);
		EndDo;
	EndIf;
	
	If CertificateObject.Modified() Then
		CertificateObject.Write();
		Form.Certificate = CertificateObject.Ref;
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure SetConditionalCertificatesListAppearance(List, RemoveApplications = False) Export
	
	ConditionalAppearanceItem = List.ConditionalAppearance.Items.Add();
	
	ItemColorsDesign = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	ItemColorsDesign.Value = Metadata.StyleItems.InaccessibleDataColor.Value;
	ItemColorsDesign.Use = True;
	
	If RemoveApplications Then
		ListOfState = New ValueList;
		ListOfState.Add(Enums.CertificateIssueRequestState.EmptyRef());
		ListOfState.Add(Enums.CertificateIssueRequestState.Executed);
		
		DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue  = New DataCompositionField("RequestStatus");
		DataFilterItem.ComparisonType   = DataCompositionComparisonType.InList;
		DataFilterItem.RightValue = ListOfState;
		DataFilterItem.Use  = True;
	EndIf;
	
	FilterItemGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemGroup.GroupType = DataCompositionFilterItemsGroupType.NotGroup;
	
	DataFilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Revoked");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False;
	DataFilterItem.Use  = True;
	
	DataFilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("ValidUntil");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Greater;
	DataFilterItem.RightValue = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisDay);
	DataFilterItem.Use  = True;
	
	ItemProcessedFields = ConditionalAppearanceItem.Fields.Items.Add();
	ItemProcessedFields.Field = New DataCompositionField("");
	ItemProcessedFields.Use = True;
	
EndProcedure

// Only for internal use.
Function BinaryDataCertificate(CertificateData) Export
	
	If TypeOf(CertificateData) <> Type("BinaryData") Then
		Return Undefined;
	EndIf;
	
	Try
		CryptoCertificate = New CryptoCertificate(CertificateData);
	Except
		CryptoCertificate = Undefined;
	EndTry;
	
	If CryptoCertificate <> Undefined Then
		Return CryptoCertificate;
	EndIf;
	
	TempFileFullName = GetTempFileName("cer");
	CertificateData.Write(TempFileFullName);
	Text = New TextDocument;
	Text.Read(TempFileFullName);
	
	If Text.LineCount() < 3
	 Or Text.GetLine(1) <> "-----BEGIN CERTIFICATE-----"
	 Or Text.GetLine(Text.LineCount()) <> "-----END CERTIFICATE-----" Then
		
		Return Undefined;
	EndIf;
	
	Text.DeleteLine(1);
	Text.DeleteLine(Text.LineCount());
	StringBase64 = Text.GetText();
	
	Try
		CertificateData = Base64Value(StringBase64);
	Except
		Return Undefined;
	EndTry;
	
	If TypeOf(CertificateData) <> Type("BinaryData") Then
		Return Undefined;
	EndIf;
	
	Try
		CryptoCertificate = New CryptoCertificate(CertificateData);
	Except
		CryptoCertificate = Undefined;
	EndTry;
	
	Return CryptoCertificate;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// Data conversion handler while starting to use support of several applications of digital signature and encryption in one IB.
//
Procedure TranferCryptographyManagerSettings() Export
	
	ApplicationObject = OldApplication();
	Application = Undefined;
	
	BeginTransaction();
	Try
		If ApplicationObject <> Undefined Then
			If Not CommonUse.IsSubordinateDIBNode() Then
				InfobaseUpdate.WriteData(ApplicationObject);
			EndIf;
			Application = ApplicationObject.Ref;
		EndIf;
		
		If Constants.UseDigitalSignatures.Get() = True
		   AND Constants.UseEncryption.Get() = False Then
		
			ValueManager = Constants.UseEncryption.CreateValueManager();
			ValueManager.Value = True;
			InfobaseUpdate.WriteData(ValueManager);
		EndIf;
		
		ClearConstant(Constants.DeleteDSProvider);
		ClearConstant(Constants.DeleteDSProviderType);
		ClearConstant(Constants.DeleteSignAlgorithm);
		ClearConstant(Constants.DeleteHashAlgorithm);
		ClearConstant(Constants.DeleteEncryptionAlgorithm);
		ProcessPathsOnLinuxServers(Application);
		ProcessPathsOnLinuxClients(Application);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// For the TransferCryptographyManagerSettings update procedure.
Procedure ClearConstant(Constant)
	
	If Not ValueIsFilled(Constant.Get()) Then
		Return;
	EndIf;
	
	ValueManager = Constant.CreateValueManager();
	ValueManager.Value = Undefined;
	InfobaseUpdate.WriteData(ValueManager);
	
EndProcedure

// For the TransferCryptographyManagerSettings update procedure.
Procedure ProcessPathsOnLinuxServers(Application)
	
	// Server paths processing
	RecordSet = InformationRegisters.PathToDigitalSignaturesAndEncryptionApplicationsOnLinuxServers.CreateRecordSet();
	RecordSet.Filter.Application.Set(Catalogs.DigitalSignatureAndEncryptionApplications.EmptyRef());
	RecordSet.Read();
	
	If RecordSet.Count() = 0 Then
		Return;
	EndIf;
	
	If ValueIsFilled(Application) Then
		ApplicationRecordSet = InformationRegisters.PathToDigitalSignaturesAndEncryptionApplicationsOnLinuxServers.CreateRecordSet();
		ApplicationRecordSet.Filter.Application.Set(Application);
		ApplicationRecordSet.Read();
		Table = ApplicationRecordSet.Unload(, "ComputerName, PathToApplication");
		Filter = New Structure("ComputerName, PathToApplication");
		
		For Each Record IN RecordSet Do
			FillPropertyValues(Filter, Record);
			Rows = Table.FindRows(Filter);
			If Rows.Count() = 0 Then
				NewRecord = ApplicationRecordSet.Add();
				FillPropertyValues(NewRecord, Record);
				NewRecord.Application = Application;
			EndIf;
		EndDo;
		If ApplicationRecordSet.Modified() Then
			InfobaseUpdate.WriteData(ApplicationRecordSet);
		EndIf;
	EndIf;
	
	RecordSet.Clear();
	InfobaseUpdate.WriteData(RecordSet);
	
EndProcedure

// For the TransferCryptographyManagerSettings update procedure.
Procedure ProcessPathsOnLinuxClients(Application)
	
	// Process clients paths
	IBUsers = InfobaseUsers.GetUsers();
	SubsystemKey = "EDS"; // Do not replace with DS. Used for the reverse compatibility.
	OldSettingsKey = "CryptographyModulePath";
	NewSettingsKey  = "PathToDigitalSignatureAndEncryptionApplications";
	For Each IBUser IN IBUsers Do
		Path = CommonUse.CommonSettingsStorageImport(SubsystemKey, OldSettingsKey,,,
			IBUser.Name);
		If Not ValueIsFilled(Path) Then
			Continue;
		EndIf;
		Settings = New Map;
		Settings.Insert(Application, Path);
		CommonUse.CommonSettingsStorageSave(SubsystemKey, NewSettingsKey, Settings,,
			IBUser.Name)
	EndDo;
	
EndProcedure

// For the TransferCryptographyManagerSettings update procedure.
Function OldApplication()
	
	ApplicationName = TrimAll(Constants.DeleteDSProvider.Get());
	ApplicationType = Constants.DeleteDSProviderType.Get();
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.PathToDigitalSignaturesAndEncryptionApplicationsOnLinuxServers AS Paths
	|WHERE
	|	Paths.Application = VALUE(Catalog.DigitalSignaturesAndEncryptionKeyCertificates.EmptyRef)";
	
	If Not ValueIsFilled(ApplicationName)
	   AND Not ValueIsFilled(ApplicationType)
	   AND Query.Execute().IsEmpty() Then
	
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("ApplicationName", ApplicationName);
	Query.SetParameter("ApplicationType", ApplicationType);
	Query.Text =
	"SELECT
	|	application.Ref AS Ref
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionApplications AS application
	|WHERE
	|	application.ApplicationName = &ApplicationName
	|	AND application.ApplicationType = &ApplicationType";
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		ApplicationObject = Catalogs.DigitalSignatureAndEncryptionApplications.CreateItem();
		ApplicationObject.Description = ApplicationName;
		ApplicationObject.ApplicationName = ApplicationName;
		ApplicationObject.ApplicationType = ApplicationType;
	Else
		ApplicationObject = QueryResult.Unload()[0].Ref.GetObject();
	EndIf;
	
	ApplicationObject.SignAlgorithm     = Constants.DeleteSignAlgorithm.Get();
	ApplicationObject.HashAlgorithm = Constants.DeleteHashAlgorithm.Get();
	ApplicationObject.EncryptionAlgorithm  = Constants.DeleteEncryptionAlgorithm.Get();
	
	Return ApplicationObject;
	
EndFunction

// For the UpdateCertificatesList procedure.
Procedure ProcessAddedCertificates(CertificatesPropertiesTable, ExceptAlreadyAdded)
	
	Query = New Query;
	Query.SetParameter("Prints", CertificatesPropertiesTable.Copy(, "Imprint"));
	Query.Text =
	"SELECT
	|	Prints.Imprint
	|INTO Prints
	|FROM
	|	&Prints AS Prints
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Certificates.Imprint,
	|	Certificates.Description AS Presentation,
	|	CASE
	|		WHEN Certificates.RequestStatus = VALUE(Enum.CertificateIssueRequestState.EmptyRef)
	|			THEN FALSE
	|		WHEN Certificates.RequestStatus = VALUE(Enum.CertificateIssueRequestState.Executed)
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS ThisRequest
	|FROM
	|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
	|		INNER JOIN Prints AS Prints
	|		ON Certificates.Imprint = Prints.Imprint";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		String = CertificatesPropertiesTable.Find(Selection.Imprint, "Imprint");
		If ExceptAlreadyAdded Then
			If String <> Undefined Then // Protection from an error in data (duplicates of certificates).
				CertificatesPropertiesTable.Delete(String);
			EndIf;
		Else
			String.Presentation = Selection.Presentation;
			String.ThisRequest  = Selection.ThisRequest;
		EndIf;
	EndDo;
	
EndProcedure

// For procedure UpdateCertificatesList, RecordCertificateIntoCatalog.
Procedure UpdateValue(OldValue, NewValue, SkipUndefinedValues = False)
	
	If NewValue = Undefined AND SkipUndefinedValues Then
		Return;
	EndIf;
	
	If OldValue <> NewValue Then
		OldValue = NewValue;
	EndIf;
	
EndProcedure

// For the SavedCertificateProperties procedure.
Procedure FillAttribute(SavedProperties, AttributesParameters, AttributeName)
	
	If AttributesParameters.Property(AttributeName)
	   AND AttributesParameters[AttributeName].FillValue <> Undefined Then
		
		SavedProperties[AttributeName] = AttributesParameters[AttributeName].FillValue;
	EndIf;
	
EndProcedure

// For the SetSigningAndEncryptionDecryptionForm procedure.
Procedure FillThumbprintsFilter(Form)
	
	Parameters = Form.Parameters;
	
	Filter = New Map;
	
	If TypeOf(Parameters.EncryptionCertificates) = Type("Array") Then
		description = New Map;
		Prints = New Map;
		ThumbprintsPresentations = New Map;
		
		For Each Description IN Parameters.EncryptionCertificates Do
			If description[Description] <> Undefined Then
				Continue;
			EndIf;
			description.Insert(Description, True);
			Certificates = EncryptionCertificatesFromDescription(Description);
			
			For Each Properties IN Certificates Do
				Value = Prints[Properties.Imprint];
				Value = ?(Value = Undefined, 1, Value + 1);
				Prints.Insert(Properties.Imprint, Value);
				ThumbprintsPresentations.Insert(Properties.Imprint, Properties.Presentation);
			EndDo;
		EndDo;
		DataItemsQuantity = Parameters.EncryptionCertificates.Count();
		For Each KeyAndValue IN Prints Do
			If KeyAndValue.Value = DataItemsQuantity Then
				Filter.Insert(KeyAndValue.Key, ThumbprintsPresentations[KeyAndValue.Key]);
			EndIf;
		EndDo;
		
	ElsIf Parameters.EncryptionCertificates <> Undefined Then
		
		Certificates = EncryptionCertificatesFromDescription(Parameters.EncryptionCertificates);
		For Each Properties IN Certificates Do
			Filter.Insert(Properties.Imprint, Properties.Presentation);
		EndDo;
	EndIf;
	
	Form.PrintsFilter = PutToTempStorage(Filter, Form.UUID);
	
EndProcedure

// For the FillThumbprintsFilter procedure.
Function EncryptionCertificatesFromDescription(Description)
	
	If TypeOf(Description) = Type("String") Then
		Return GetFromTempStorage(Description);
	EndIf;
	
	Certificates = New Array;
	
	Selection = CommonUse.ObjectAttributeValue(Description, "EncryptionCertificates").Select();
	While Selection.Next() Do
		CertificateProperties = New Structure("Thumbprint, Presentation, Certificate");
		FillPropertyValues(CertificateProperties, Selection);
		CertificateProperties.Certificate = CertificateProperties.Certificate.Get();
		Certificates.Add(CertificateProperties);
	EndDo;
	
	Return Certificates;
	
EndFunction

// For the SetSigningEncryptionDecryptionForm, CertificateOnChangeOnServer procedures.
Procedure FillCertificateAdditionalProperties(Form)
	
	If Not ValueIsFilled(Form.Certificate) Then
		Return;
	EndIf;
	
	Items = Form.Items;
	
	AttributeValues = CommonUse.ObjectAttributesValues(Form.Certificate,
		"CloseKeyStrongProtection,
		|Thumbprint, Application, ValidUntil, UserIsWarnedAboutValidityTime, CertificateData");
	
	Try
		CertificateBinaryData = AttributeValues.CertificateData.Get();
		CryptoCertificate = New CryptoCertificate(CertificateBinaryData);
	Except
		ErrorInfo = ErrorInfo();
		Certificate = Form.Certificate;
		Form.Certificate = Undefined;
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'An error of the
			           |infobase occurred while receiving %1
			           |certificate data: %2'"),
			Certificate,
			BriefErrorDescription(ErrorInfo));
	EndTry;
	
	Form.CertificateAddress = PutToTempStorage(CertificateBinaryData, Form.UUID);
	
	Form.CertificateThumbprint      = AttributeValues.Imprint;
	Form.CertificateApplication      = AttributeValues.Application;
	Form.CertificateValidUntil = AttributeValues.ValidUntil;
	Form.CertificateEnhancedProtectionPrivateKey = AttributeValues.EnhancedProtectionPrivateKey;
	
	Form.NotifyAboutExpiration =
		Not AttributeValues.UserNotifiedOnValidityInterval
		AND AddMonth(CurrentSessionDate(), 1) > Form.CertificateValidUntil;
	
	Form.CertificateAtServerErrorDescription = New Structure;
	
	If Not DigitalSignatureClientServer.CommonSettings().CreateDigitalSignaturesAtServer Then
		Return;
	EndIf;
	
	GetCertificateByImprint(Form.CertificateThumbprint,
		True, False, Form.CertificateApplication, Form.CertificateAtServerErrorDescription);
	
EndProcedure

// For the CryptographyManager function.
Function NewCryptographyManager(Application, Errors, ComputerName)
	
	ApplicationsDescription = DigitalSignatureServiceClientServer.CryptographyManagerApplicationsDescription(
		Application, Errors);
	
	If ApplicationsDescription = Undefined Then
		Return Undefined;
	EndIf;
	
	IsLinux = CommonUse.ThisLinuxServer();
	
	If IsLinux Then
		Query = New Query;
		Query.SetParameter("ComputerName", ComputerName);
		Query.Text =
		"SELECT
		|	PathsToApplication.Application,
		|	PathsToApplication.PathToApplication
		|FROM
		|	InformationRegister.PathToDigitalSignaturesAndEncryptionApplicationsOnLinuxServers AS PathsToApplication
		|WHERE
		|	PathsToApplication.ComputerName = &ComputerName";
		
		PathsToApplicationsOnLinuxServers = New Map;
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			PathsToApplicationsOnLinuxServers.Insert(Selection.Application, Selection.PathToApplication);
		EndDo;
	Else
		PathsToApplicationsOnLinuxServers = Undefined;
	EndIf;
	
	Manager = Undefined;
	For Each ApplicationDescription IN ApplicationsDescription Do
		
		ApplicationProperties = DigitalSignatureServiceClientServer.CryptographyManagerApplicationProperties(
			ApplicationDescription, IsLinux, Errors, True, PathsToApplicationsOnLinuxServers);
		
		If ApplicationProperties = Undefined Then
			Continue;
		EndIf;
		
		Try
			ModuleInformation = CryptoTools.GetCryptoModuleInformation(
				ApplicationProperties.ApplicationName,
				ApplicationProperties.PathToApplication,
				ApplicationProperties.ApplicationType);
		Except
			DigitalSignatureServiceClientServer.CryptographyManagerAddError(Errors,
				ApplicationDescription.Ref, BriefErrorDescription(ErrorInfo()),
				True, True, True);
			Continue;
		EndTry;
		
		If ModuleInformation = Undefined Then
			DigitalSignatureServiceClientServer.CryptographyManagerApplicationNotFound(
				ApplicationDescription, Errors, True);
			
			Manager = Undefined;
			Continue;
		EndIf;
		
		If Not IsLinux Then
			ApplicationNameReceived = ModuleInformation.Name;
			
			ApplicationNameMatches = DigitalSignatureServiceClientServer.CryptographyManagerApplicationNameMatch(
				ApplicationDescription, ApplicationNameReceived, Errors, True);
			
			If Not ApplicationNameMatches Then
				Manager = Undefined;
				Continue;
			EndIf;
		EndIf;
		
		Try
			Manager = New CryptoManager(
				ApplicationProperties.ApplicationName,
				ApplicationProperties.PathToApplication,
				ApplicationProperties.ApplicationType);
		Except
			DigitalSignatureServiceClientServer.CryptographyManagerAddError(Errors,
				ApplicationDescription.Ref, BriefErrorDescription(ErrorInfo()),
				True, True, True);
			Continue;
		EndTry;
		
		AlgorithmsSet = DigitalSignatureServiceClientServer.CryptographyManagerAlgorithmsSet(
			ApplicationDescription, Manager, Errors);
		
		If Not AlgorithmsSet Then
			Continue;
		EndIf;
		
		Break; // Required cryptography manager is received.
	EndDo;
	
	Return Manager;
	
EndFunction

#EndRegion
