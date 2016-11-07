////////////////////////////////////////////////////////////////////////////////
// Subsystem "Group object change".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "NotEditableInGroupProcessingAttributes",
//                            "EditableInGroupProcessingAttributes"
//                            each name must begin with a new row.
//                            If "*" is specified, then both functions are defined in the manager module.
//
// Example: 
//   Objects.Insert(Metadata.Documents.CustomerOrder.FullName(), "*"); defined// both functions.
//   Objects.Insert(Metadata.BusinessProcesses.RoleAddressingTask.FullName(), "EditableInGroupProcessingAttributes");
//   Objects.Insert(Metadata.Catalogs.Partners.FullName(),
// 	"EditableInGroupProcessingAttributes|NotEditableInGroupProcessingAttributes");
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	
	Objects.Insert(Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInformation.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.ExpenseReportAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.Currencies.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.ReportsVariants.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.FileVersions.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.ContactInformationTypes.FullName(), "NotEditableInGroupProcessingAttributes");
	Objects.Insert(Metadata.Catalogs.ExternalUsers.FullName(), "NotEditableInGroupProcessingAttributes");
	Objects.Insert(Metadata.Catalogs.ExternalUsersGroups.FullName(), "NotEditableInGroupProcessingAttributes");
	Objects.Insert(Metadata.Catalogs.AccessGroups.FullName(), "NotEditableInGroupProcessingAttributes");
	Objects.Insert(Metadata.Catalogs.CounterpartyContractsAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.AdditionalReportsAndDataProcessors.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.WorkOrderAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.CustomerOrderAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.PurchaseOrderAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.ObjectsPropertiesValues.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.ObjectsPropertiesValuesHierarchy.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.MetadataObjectIDs.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.InventoryReconciliationAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.RFBankClassifier.FullName(), "NotEditableInGroupProcessingAttributes");
	Objects.Insert(Metadata.Catalogs.Counterparties.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.CounterpartiesAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.AdditionalAttributesAndInformationSets.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.ProductsAndServices.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.ProductsAndServicesAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.Companies.FullName(), "NotEditableInGroupProcessingAttributes");
	Objects.Insert(Metadata.Catalogs.CompaniesAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.FileFolders.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.FileFoldersAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.Users.FullName(), "NotEditableInGroupProcessingAttributes");
	Objects.Insert(Metadata.Catalogs.UserReportsSettings.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.PaymentReceiptAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.PredefinedReportsVariants.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.SupplierInvoiceAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.AccessGroupsProfiles.FullName(), "NotEditableInGroupProcessingAttributes");
	Objects.Insert(Metadata.Catalogs.PaymentExpenseAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.EventAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.SystemMessages.FullName(), "NotEditableInGroupProcessingAttributes");
	Objects.Insert(Metadata.Catalogs.SpecificationsAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.WorldCountries.FullName(), "NotEditableInGroupProcessingAttributes");
	Objects.Insert(Metadata.Catalogs.DataExchangeScripts.FullName(), "NotEditableInGroupProcessingAttributes");
	Objects.Insert(Metadata.Catalogs.SupplierInvoiceForPaymentAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.SupplierInvoiceNoteAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.CustomerInvoiceNoteAttachedFiles.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.FileStorageVolumes.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.EmailAccounts.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.Files.FullName(), "EditedAttributesInGroupDataProcessing");
	
EndProcedure

#EndRegion
