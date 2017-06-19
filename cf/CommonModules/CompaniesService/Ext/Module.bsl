////////////////////////////////////////////////////////////////////////////////
// Subsystem "Companies".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Returns company by default.
// If there is only one company in the IB which is not marked for
// deletion and is not predetermined, then a ref to this company will be returned, otherwise an empty ref will be returned.
//
// Returns:
//     CatalogRef.Companies - ref to the company.
//
Function CompanyByDefault() Export
	
	Return Catalogs.Companies.CompanyByDefault();
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"CompaniesService");
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillingKindsOfRestrictionsRightsOfMetadataObjects"].Add(
			"CompaniesService");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillAccessKinds"].Add(
			"CompaniesService");
	EndIf;
	
EndProcedure

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.12";
	Handler.InitialFilling = True;
	Handler.Procedure = "Catalogs.Companies.FillConstantUseSeveralCompanies";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Fills the content of access kinds used when metadata objects rights are restricted.
// If the content of access kinds is not filled, "Access rights" report will show incorrect information.
//
// Only the access types clearly used
// in access restriction templates must be filled, while
// the access types used in access values sets may be
// received from the current data register AccessValueSets.
//
//  To prepare the procedure content
// automatically, you should use the developer tools for subsystem.
// Access management.
//
// Parameters:
//  Definition     - String, multiline string in format <Table>.<Right>.<AccessKind>[.Object table].
//              For example, Document.SupplierInvoice.Read.Companies
//                           Document.SupplierInvoice.Read.Counterparties
//                           Document.SupplierInvoice.Change.Companies
//                           Document.SupplierInvoice.Change.Counterparties
//                           Document.Emails.Read.Object.Document.Emails
//                           Document.Emails.Change.Object.Document.Emails
//                           Document.Files.Read.Object.Catalog.FileFolders
//                           Document.Files.Read.Object.Document.Email
//                           Document.Files.Change.Object.Catalog.FileFolders Document.Files.Change.Object.Document.Email
//                 Access type Object is predefined as literal, it is not included into predefined elements.
//                 ChartsOfCharacteristicTypesRef.AccessKinds. This kind of access is used in
//                 the templates of access restrictions, such as "link" to another object by which the table is limited.
//                 When access type "Object" is assigned, you shall also indicate the
//                 types of tables used for this type of access.I.e. you
//                 shall list the types that correspond to the field used in the template of access restriction and paired with access type "Object".
//                 When listing the types by access type "Object", you should list only
//                 those types of flieds that the field InformationRegisters.AccessValueSets.Object has, the rest of types is irrelevant.
// 
Procedure OnFillingKindsOfRestrictionsRightsOfMetadataObjects(Definition) Export
	
	
	
EndProcedure

// Fills kinds of access used by access rights restriction.
// Access types Users and ExternalUsers are complete.
// They can be deleted if they are not used for access rights restriction.
//
// Parameters:
//  AccessKinds - ValuesTable with fields:
//  - Name                  - String - a name used in the description of delivered 
//                            access groups profiles and ODD texts.
//  - Presentation          - String - introduces an access type in profiles and access groups.
//  - ValuesType            - Type - Type of access values reference.        For example, Type("CatalogRef.ProductsAndServices").
//  - ValueGroupType        - Type - Reference type of access values groups. For example, Type("CatalogRef.ProductsAndServicesAccessGroups").
//  - SeveralGroupsOfValues - Boolean - True shows that for access value (ProductsAndServices) 
//                            several value groups can be selected (Products and services access group).
//
Procedure OnFillAccessKinds(AccessKinds) Export
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name = "Companies";
	AccessKind.Presentation = NStr("en='Companies';ru='Компании'");
	AccessKind.ValuesType   = Type("CatalogRef.Companies");
	
EndProcedure

// Subscription handler to event CheckOptionValueUseSeveralCompanies.
// It is called when writing the item of the "Companies" catalog.
//
Procedure CheckOptionValueUseSeveralCompaniesOnWrite(Source, Cancel) Export
	
	If Not Source.IsFolder
		AND Not GetFunctionalOption("UseSeveralCompanies")
		AND Catalogs.Companies.CompaniesCount() > 1 Then
		
		SetPrivilegedMode(True);
		Constants.UseSeveralCompanies.Set(True);
		SetPrivilegedMode(False);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Conditional calls of the SSL subsystems.

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Match        - as a key specify the full name of the metadata object 
//                            that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.Companies.FullName(), "NotEditableInGroupProcessingAttributes");
EndProcedure

#EndRegion
