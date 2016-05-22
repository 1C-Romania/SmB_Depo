////////////////////////////////////////////////////////////////////////////////
// Subsystem integration with each other.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Integration with Object Attribute No-Edit Order subsystem.

// Define metadata objects in the managers modules of which
// the ability to edit attributes is restricted using the GetLockedOjectAttributes export function.
//
// Parameters:
//   Objects - Map - specify the full name of the metadata
//                            object as a key connected to the Deny editing objects attributes subsystem. 
//                            As a value - empty row.
//
Procedure OnDetermineObjectsWithLockedAttributes(Objects) Export 
	
	If CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("ContactInformationManagementService");
		ModuleContactInformationManagementService.OnDetermineObjectsWithLockedAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Properties") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("PropertiesManagementService");
		ModuleContactInformationManagementService.OnDetermineObjectsWithLockedAttributes(Objects);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Integration with Object Group Changing subsystem.

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
	
	StandardSubsystemsServer.WhenDefiningObjectsWithEditableAttributes(Objects);
	
	If CommonUse.SubsystemExists("StandardSubsystems.Questioning") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("Questioning");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("WorkWithBanks");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("BusinessProcessesAndTasksServer");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("Interactions");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("WorkWithCurrencyRates");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("ReportsVariants");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
		
	If CommonUse.SubsystemExists("StandardSubsystems.UserNotes") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("UserNotesCall");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("ContactInformationManagementService");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("DataExchangeServer");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("CompaniesService");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Users") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("UsersService");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("FileOperationsService");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsMailing") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("ReportMailing");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("EmailOperationsService");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Properties") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("PropertiesManagementService");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("MessageExchange");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;

	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("AccessManagementService");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileFunctions") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("FileFunctionsService");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("DigitalSignatureService");
		ModuleContactInformationManagementService.WhenDefiningObjectsWithEditableAttributes(Objects);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Integration with Data Importing from File subsystem.

// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  Handlers - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      Author presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	StandardSubsystemsServer.OnDetermineCatalogsForDataImport(ImportedCatalogs);
	
	If CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("ContactInformationManagementService");
		ModuleContactInformationManagementService.OnDetermineCatalogsForDataImport(ImportedCatalogs);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleWorkWithCurrencyRates = CommonUse.CommonModule("WorkWithCurrencyRates");
		ModuleWorkWithCurrencyRates.OnDetermineCatalogsForDataImport(ImportedCatalogs);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Users") Then
		ModuleUsersService = CommonUse.CommonModule("UsersService");
		ModuleUsersService.OnDetermineCatalogsForDataImport(ImportedCatalogs);
	EndIf;

	If CommonUse.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = CommonUse.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDetermineCatalogsForDataImport(ImportedCatalogs);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleWorkWithBanks = CommonUse.CommonModule("WorkWithBanks");
		ModuleWorkWithBanks.OnDetermineCatalogsForDataImport(ImportedCatalogs);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ModuleJobQueueService = CommonUse.CommonModule("JobQueueService");
		ModuleJobQueueService.OnDetermineCatalogsForDataImport(ImportedCatalogs);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.BasicFunctionalitySaaS") Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
		ModuleSaaSOperations.OnDetermineCatalogsForDataImport(ImportedCatalogs);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
		ModuleReportsVariants.OnDetermineCatalogsForDataImport(ImportedCatalogs);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureService = CommonUse.CommonModule("DigitalSignatureService");
		ModuleDigitalSignatureService.OnDetermineCatalogsForDataImport(ImportedCatalogs);
	EndIf;

	If CommonUse.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = CommonUse.CommonModule("Interactions");
		ModuleInteractions.OnDetermineCatalogsForDataImport(ImportedCatalogs);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileFunctions") Then
		ModuleFileFunctionsService = CommonUse.CommonModule("FileFunctionsService");
		ModuleFileFunctionsService.OnDetermineCatalogsForDataImport(ImportedCatalogs);
	EndIf;
	
EndProcedure

#EndRegion

