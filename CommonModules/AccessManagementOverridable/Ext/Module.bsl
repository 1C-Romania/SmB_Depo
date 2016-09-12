////////////////////////////////////////////////////////////////////////////////
// Subsystem "Access management".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Fills kinds of access used by access rights restriction.
// Access types Users and ExternalUsers are complete.
// They can be deleted if they are not used for access rights restriction.
//
// Parameters:
//  AccessKinds - ValueTable - with columns:
//   * Name                    - String - a name used in
//                                       the description of delivered access groups profiles and ODD texts.
//   * Presentation          - String - introduces an access type in profiles and access groups.
//   * ValuesType            - Type    - Type of access values reference.       For
//                                       example, Type("CatalogRef.ProductsAndServices").
//   * ValueGroupType       - Type    - Reference type of access values groups. For
//                                       example, Type("CatalogRef.ProductsAndServicesAccessGroups").
//   * SeveralValueGroups - Boolean - True shows that for access value
//                                       (ProductsAndServices) several value groups can be selected (Products and services access group).
//
Procedure OnFillAccessKinds(AccessKinds) Export

	AccessKind = AccessKinds.Add();
	AccessKind.Name = "PettyCashes";
	AccessKind.Presentation    = NStr("en='PettyCashes';ru='Кассы'");
	AccessKind.ValuesType      = Type("CatalogRef.PettyCashes");
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name = "CounterpartiesGroup";
	AccessKind.Presentation    = NStr("en='Counterparty groups';ru='Группы контрагентов'");
	AccessKind.ValuesType      = Type("CatalogRef.Counterparties");
	AccessKind.ValueGroupType = Type("CatalogRef.CounterpartiesAccessGroups");

EndProcedure

// Fills in descriptions of substituted profiles
// of the access groups and redefines the parameters of profiles and access groups update.
//
// To prepare the procedure content automatically, the
// developer tools for subsystem Access Management shall be used.
//
// Parameters:
//  ProfileDescriptions    - Array - structures array to which descriptions should be added.
//                        Empty structure should be received using the function.
//                        AccessManagement.AccessGroupsProfileNewDescription.
//
//  UpdateParameters - Structure - structure with properties:
//   * UpdateChangedProfiles - Boolean - initial value is True.
//   * ProhibitProfilesChange - Boolean - initial value is True.
//       If you set False, then provided profiles can not only be seen, but also edited.
//   * UpdateAccessGroups     - Boolean - initial value is True.
//   * UpdateAccessGroupsWithOutdatedSettings - Boolean - Initial value is False.
//       If you set True, values settings executed by
//       the administrator for the access kind that was removed from the profile will also be removed from the access groups.
//
Procedure WhenFillingOutProfileGroupsAccessProvided(ProfileDescriptions, UpdateParameters) Export
	
#Region Sales
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "Sales, Service" profile filling.
	//
	ProfileDescription = AccessManagement.AccessGroupProfileNewDescription();
	ProfileDescription.Name           = "Sales";
	ProfileDescription.ID = "76337576-bff4-11df-9174-e0cb4ed5f4c3";	
	ProfileDescription.Description = NStr("en = 'Sales'");
	ProfileDescription.Definition = NStr("en='Use this profile to work with the Sales and Service sections.';ru='Под профилем осуществляется работа с разделами Продажи и Сервис.'"
	);
	
	// SSL
	ProfileDescription.Roles.Add("BasicRights");
	ProfileDescription.Roles.Add("OutputToPrinterClipboardFile");
	ProfileDescription.Roles.Add("ExchangeDataWithSitesProcessing");
	ProfileDescription.Roles.Add("DataSynchronization");
	ProfileDescription.Roles.Add("AddChangeBasicReferenceData");
	ProfileDescription.Roles.Add("AddChangeReportsVariants");
	ProfileDescription.Roles.Add("AddChangeIndividualsPersonalData");
	ProfileDescription.Roles.Add("AddEditCountries");
	ProfileDescription.Roles.Add("AddChangeIndividuals");
	ProfileDescription.Roles.Add("RunWebClient");
	ProfileDescription.Roles.Add("RunThinClient");
	ProfileDescription.Roles.Add("SaveUserData");
	ProfileDescription.Roles.Add("AdditionalInformationChange");
	ProfileDescription.Roles.Add("ChangePrintFormsTemplates");
	ProfileDescription.Roles.Add("EditCurrentUser");
	ProfileDescription.Roles.Add("IntegrationWith1CBuhphone");
	ProfileDescription.Roles.Add("ReportsVariantsUsage");
	ProfileDescription.Roles.Add("UseGlobalAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("UseAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("UseInformationCenter");
	ProfileDescription.Roles.Add("RemindersUse");
	ProfileDescription.Roles.Add("UseSubordinationStructure");
	ProfileDescription.Roles.Add("UseEMailAccounts");
	ProfileDescription.Roles.Add("DSUsage");
	ProfileDescription.Roles.Add("ViewEventLogMonitor");
	ProfileDescription.Roles.Add("EditObjectAttributes");
	ProfileDescription.Roles.Add("ReadBasicReferenceData");
	ProfileDescription.Roles.Add("ReadAdditionalInformation");
	ProfileDescription.Roles.Add("ReadIndividualsPersonalData");
	ProfileDescription.Roles.Add("ReadIndividuals");
	ProfileDescription.Roles.Add("ViewApplicationChangesDescription");
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		ProfileDescription.Roles.Add("RunThickClient");
	EndIf;
	
	// Electronic document exchange
	ProfileDescription.Roles.Add("BasicRightsOfED");
	ProfileDescription.Roles.Add("EDExchangeExecution");
	ProfileDescription.Roles.Add("EDReading");
	
	// Online user support
	ProfileDescription.Roles.Add("BasicRightsIUS");
	ProfileDescription.Roles.Add("ConnectionToOnlineSupportService");
	ProfileDescription.Roles.Add("UseUOSMonitor");
	ProfileDescription.Roles.Add("Use1CTaxcomService");
	
	// SB
	ProfileDescription.Roles.Add("SBBasicRights");
	ProfileDescription.Roles.Add("AddChangeEventsAndTasks");
	ProfileDescription.Roles.Add("AddChangeCounterparties");
	ProfileDescription.Roles.Add("AddChangeInventoryMovements");
	ProfileDescription.Roles.Add("AddChangeBankAccounts");
	ProfileDescription.Roles.Add("ReadDocumentsByBankAndPettyCash");
	ProfileDescription.Roles.Add("ReadInventoryAndSettlementsBalances");
	ProfileDescription.Roles.Add("ReadSettlementsDocuments");
	ProfileDescription.Roles.Add("UsePeripherals");
	ProfileDescription.Roles.Add("DataExchangeWithMobileApplication");
	
	// SB Work with files
	ProfileDescription.Roles.Add("FileFolderOperations");
	ProfileDescription.Roles.Add("FileOperations");
	
	// SB Sales
	ProfileDescription.Roles.Add("AddChangeSalesSubsystem");
	ProfileDescription.Roles.Add("AddChangeMarketingSubsystem");
	ProfileDescription.Roles.Add("AddChangeRetailSalesSubsystem");
	ProfileDescription.Roles.Add("UseSalesReports");
	
	// SB Service
	ProfileDescription.Roles.Add("AddChangeServiceSubsystem");
	ProfileDescription.Roles.Add("UseServiceReports");
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("CounterpartiesGroup", "InitiallyAllAllowed");
	ProfileDescription.AccessKinds.Add("PettyCashes", "InitiallyAllAllowed");
	
	ProfileDescriptions.Add(ProfileDescription);
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for filling the "Edit document prices (additionally)" service profile.
	//
	ProfileDescription = AccessManagement.AccessGroupProfileNewDescription();
	ProfileDescription.Name           = "EditDocumentPrices";
	ProfileDescription.ID = "76337579-bff4-11df-9174-e0cb4ed5f4c3";	
	ProfileDescription.Description = NStr("en='Edit document prices (additionally)';ru='Редактирование цен документов (дополнительно)'");
	ProfileDescription.Definition = NStr("en='Service profile that determines whether it is possible to edit prices in documents for managers.';ru='Служебный профиль, определяющий возможность редактирования цен в документах для менеджеров.'"
	);
	
	ProfileDescription.Roles.Add("UseDataImportFromExternalSources");
	ProfileDescription.Roles.Add("EditDocumentPrices");
	
	ProfileDescriptions.Add(ProfileDescription);
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for the "Products and services editing (additionally)" service profile filling.
	//
	ProfileDescription = AccessManagement.AccessGroupProfileNewDescription();
	ProfileDescription.Name           = "ProductsAndServicesEditing";
	ProfileDescription.ID = "76337580-bff4-11df-9174-e0cb4ed5f4c3";	
	ProfileDescription.Description = NStr("en='Products and services (additionally)';ru='Редактирование номенклатуры (дополнительно)'");
	ProfileDescription.Definition = NStr("en='Service profile that determines whether it is possible to edit products and services for managers.';ru='Служебный профиль, определяющий возможность редактирования номенклатуры для менеджеров.'"
	);
	
	ProfileDescription.Roles.Add("AddChangeProductsAndServices");
	
	ProfileDescriptions.Add(ProfileDescription);
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for the "Returns from customers (additionally)" service profile filling.
	//
	ProfileDescription = AccessManagement.AccessGroupProfileNewDescription();
	ProfileDescription.Name           = "ReturnsFromCustomers";
	ProfileDescription.ID = "76337581-bff4-11df-9174-e0cb4ed5f4c3";	
	ProfileDescription.Description = NStr("en='Returns from customers (additionally)';ru='Возвраты от покупателей (дополнительно)'");
	ProfileDescription.Definition = NStr("en='Service profile that determines whether it is possible to work with returns from customers.';ru='Служебный профиль, определяющий возможность работы с возвратами от покупателей.'"
	);
	
	ProfileDescription.Roles.Add("AdditionChangeOfReturnsFromBuyers");
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("CounterpartiesGroup", "InitiallyAllProhibited");
	
	ProfileDescriptions.Add(ProfileDescription);
	
#EndRegion
	
#Region Purchases

	////////////////////////////////////////////////////////////////////////////////
	// Description for the "Purchases" profile filling.
	//
	ProfileDescription = AccessManagement.AccessGroupProfileNewDescription();
	ProfileDescription.Name           = "Purchases";
	ProfileDescription.ID = "76337577-bff4-11df-9174-e0cb4ed5f4c3";	
	ProfileDescription.Description = NStr("en='Purchases';ru='Закупки'");
	ProfileDescription.Definition = NStr("en='Use this profile to work with the Purchases section.';ru='Под профилем осуществляется работа с разделом Закупки.'"
	);
	
	// SSL
	ProfileDescription.Roles.Add("BasicRights");
	ProfileDescription.Roles.Add("OutputToPrinterClipboardFile");
	ProfileDescription.Roles.Add("ExchangeDataWithSitesProcessing");
	ProfileDescription.Roles.Add("DataSynchronization");
	ProfileDescription.Roles.Add("AddChangeBasicReferenceData");
	ProfileDescription.Roles.Add("AddChangeReportsVariants");
	ProfileDescription.Roles.Add("AddChangeIndividualsPersonalData");
	ProfileDescription.Roles.Add("AddEditCountries");
	ProfileDescription.Roles.Add("AddChangeIndividuals");
	ProfileDescription.Roles.Add("RunWebClient");
	ProfileDescription.Roles.Add("RunThinClient");
	ProfileDescription.Roles.Add("SaveUserData");
	ProfileDescription.Roles.Add("AdditionalInformationChange");
	ProfileDescription.Roles.Add("ChangePrintFormsTemplates");
	ProfileDescription.Roles.Add("EditCurrentUser");
	ProfileDescription.Roles.Add("IntegrationWith1CBuhphone");
	ProfileDescription.Roles.Add("ReportsVariantsUsage");
	ProfileDescription.Roles.Add("UseGlobalAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("UseAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("UseInformationCenter");
	ProfileDescription.Roles.Add("RemindersUse");
	ProfileDescription.Roles.Add("UseSubordinationStructure");
	ProfileDescription.Roles.Add("UseEMailAccounts");
	ProfileDescription.Roles.Add("DSUsage");
	ProfileDescription.Roles.Add("ViewEventLogMonitor");
	ProfileDescription.Roles.Add("EditObjectAttributes");
	ProfileDescription.Roles.Add("ReadBasicReferenceData");
	ProfileDescription.Roles.Add("ReadAdditionalInformation");
	ProfileDescription.Roles.Add("ReadIndividualsPersonalData");
	ProfileDescription.Roles.Add("ReadIndividuals");
	ProfileDescription.Roles.Add("ViewApplicationChangesDescription");
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		ProfileDescription.Roles.Add("RunThickClient");
	EndIf;
	
	// Electronic document exchange
	ProfileDescription.Roles.Add("BasicRightsOfED");
	ProfileDescription.Roles.Add("EDExchangeExecution");
	ProfileDescription.Roles.Add("EDReading");
	
	// Online user support
	ProfileDescription.Roles.Add("BasicRightsIUS");
	ProfileDescription.Roles.Add("ConnectionToOnlineSupportService");
	ProfileDescription.Roles.Add("UseUOSMonitor");
	ProfileDescription.Roles.Add("Use1CTaxcomService");
	
	// SB
	ProfileDescription.Roles.Add("SBBasicRights");
	ProfileDescription.Roles.Add("AddChangeEventsAndTasks");
	ProfileDescription.Roles.Add("AddChangeProductsAndServices");
	ProfileDescription.Roles.Add("AddChangeCounterparties");
	ProfileDescription.Roles.Add("AddChangeBankAccounts");
	ProfileDescription.Roles.Add("UseDataImportFromExternalSources");
	ProfileDescription.Roles.Add("ReadDocumentsByBankAndPettyCash");
	ProfileDescription.Roles.Add("ReadInventoryAndSettlementsBalances");
	ProfileDescription.Roles.Add("ReadSettlementsDocuments");
	ProfileDescription.Roles.Add("ReadDocumentsMovementsOnInventory");
	ProfileDescription.Roles.Add("UsePeripherals");
	ProfileDescription.Roles.Add("DataExchangeWithMobileApplication");
	
	// SB Work with files
	ProfileDescription.Roles.Add("FileFolderOperations");
	ProfileDescription.Roles.Add("FileOperations");
	
	// SB Purchases
	ProfileDescription.Roles.Add("AddChangePurchasesSubsystem");
	ProfileDescription.Roles.Add("AddChangeProcessingSubsystem");
	ProfileDescription.Roles.Add("AddChangeInventoryAndWarehouseSubsystem");
	ProfileDescription.Roles.Add("AddChangeSurplusesAndShortagessSubsystem");
	ProfileDescription.Roles.Add("UsePurchasesReports");
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("PettyCashes", "InitiallyAllAllowed");
	
	ProfileDescriptions.Add(ProfileDescription);
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for the "Returns to vendors (additionally)" service profile filling.
	//
	ProfileDescription = AccessManagement.AccessGroupProfileNewDescription();
	ProfileDescription.Name           = "ReturnsToVendors";
	ProfileDescription.ID = "76337582-bff4-11df-9174-e0cb4ed5f4c3";	
	ProfileDescription.Description = NStr("en='Returns to vendors (additionally)';ru='Возвраты поставщикам (дополнительно)'");
	ProfileDescription.Definition = NStr("en='Service profile that determines whether it is possible to work with returns to vendors.';ru='Служебный профиль, определяющий возможность работы с возвратами поставщикам.'"
	);
	
	ProfileDescription.Roles.Add("AddChangeReturnsToVendors");
	
	ProfileDescriptions.Add(ProfileDescription);
	
#EndRegion

#Region Production
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "Production" profile filling.
	//
	ProfileDescription = AccessManagement.AccessGroupProfileNewDescription();
	ProfileDescription.Name           = "Production";
	ProfileDescription.ID = "76337578-bff4-11df-9174-e0cb4ed5f4c3";	
	ProfileDescription.Description = NStr("en='Production';ru='Производство'");
	ProfileDescription.Definition = NStr("en='Use this profile to work with the Production section.';ru='Под профилем осуществляется работа с разделом Производство.'"
	);
	
	// SSL
	ProfileDescription.Roles.Add("BasicRights");
	ProfileDescription.Roles.Add("OutputToPrinterClipboardFile");
	ProfileDescription.Roles.Add("ExchangeDataWithSitesProcessing");
	ProfileDescription.Roles.Add("DataSynchronization");
	ProfileDescription.Roles.Add("AddChangeBasicReferenceData");
	ProfileDescription.Roles.Add("AddChangeReportsVariants");
	ProfileDescription.Roles.Add("AddChangeIndividualsPersonalData");
	ProfileDescription.Roles.Add("AddEditCountries");
	ProfileDescription.Roles.Add("AddChangeIndividuals");
	ProfileDescription.Roles.Add("RunWebClient");
	ProfileDescription.Roles.Add("RunThinClient");
	ProfileDescription.Roles.Add("SaveUserData");
	ProfileDescription.Roles.Add("AdditionalInformationChange");
	ProfileDescription.Roles.Add("ChangePrintFormsTemplates");
	ProfileDescription.Roles.Add("EditCurrentUser");
	ProfileDescription.Roles.Add("IntegrationWith1CBuhphone");
	ProfileDescription.Roles.Add("ReportsVariantsUsage");
	ProfileDescription.Roles.Add("UseGlobalAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("UseAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("UseInformationCenter");
	ProfileDescription.Roles.Add("RemindersUse");
	ProfileDescription.Roles.Add("UseSubordinationStructure");
	ProfileDescription.Roles.Add("UseEMailAccounts");
	ProfileDescription.Roles.Add("DSUsage");
	ProfileDescription.Roles.Add("ViewEventLogMonitor");
	ProfileDescription.Roles.Add("EditObjectAttributes");
	ProfileDescription.Roles.Add("ReadBasicReferenceData");
	ProfileDescription.Roles.Add("ReadAdditionalInformation");
	ProfileDescription.Roles.Add("ReadIndividualsPersonalData");
	ProfileDescription.Roles.Add("ReadIndividuals");
	ProfileDescription.Roles.Add("ViewApplicationChangesDescription");
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		ProfileDescription.Roles.Add("RunThickClient");
	EndIf;
	
	// Electronic document exchange
	ProfileDescription.Roles.Add("BasicRightsOfED");
	ProfileDescription.Roles.Add("EDExchangeExecution");
	ProfileDescription.Roles.Add("EDReading");
	
	// Online user support
	ProfileDescription.Roles.Add("BasicRightsIUS");
	ProfileDescription.Roles.Add("ConnectionToOnlineSupportService");
	ProfileDescription.Roles.Add("UseUOSMonitor");
	ProfileDescription.Roles.Add("Use1CTaxcomService");
	
	// SB
	ProfileDescription.Roles.Add("SBBasicRights");
	ProfileDescription.Roles.Add("AddChangeEventsAndTasks");
	ProfileDescription.Roles.Add("AddChangeProductsAndServices");
	ProfileDescription.Roles.Add("ReadDocumentsByBankAndPettyCash");
	ProfileDescription.Roles.Add("ReadInventoryAndSettlementsBalances");
	ProfileDescription.Roles.Add("ReadDocumentsMovementsOnInventory");
	ProfileDescription.Roles.Add("UsePeripherals");
	ProfileDescription.Roles.Add("DataExchangeWithMobileApplication");
	
	// SB Work with files
	ProfileDescription.Roles.Add("FileFolderOperations");
	ProfileDescription.Roles.Add("FileOperations");
	
	// SB Production
	ProfileDescription.Roles.Add("AddChangeProductionSubsystem");
	ProfileDescription.Roles.Add("AddChangeTasksSubsystem");
	ProfileDescription.Roles.Add("AddChangeProcessingProductionSubsystem");
	ProfileDescription.Roles.Add("UseProductionReports");
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("PettyCashes", "InitiallyAllAllowed");
	
	ProfileDescriptions.Add(ProfileDescription);
	
#EndRegion

#Region Funds
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "Funds" profile filling.
	//
	ProfileDescription = AccessManagement.AccessGroupProfileNewDescription();
	ProfileDescription.Name           = "Funds";
	ProfileDescription.ID = "76337575-bff4-11df-9174-e0cb4ed5f4c3";
	ProfileDescription.Description = NStr("en='Funds';ru='Деньги'");
	ProfileDescription.Definition = NStr("en='Use this profile to work with the Funds section: bank, petty cash and payment schedule  section.';ru='Под профилем осуществляется работа с разделом Деньги: банк, касса и платежный календарь.'"
	);
	
	// SSL
	ProfileDescription.Roles.Add("BasicRights");
	ProfileDescription.Roles.Add("OutputToPrinterClipboardFile");
	ProfileDescription.Roles.Add("DataSynchronization");
	ProfileDescription.Roles.Add("AddChangeBasicReferenceData");
	ProfileDescription.Roles.Add("AddChangeReportsVariants");
	ProfileDescription.Roles.Add("AddEditCountries");
	ProfileDescription.Roles.Add("RunWebClient");
	ProfileDescription.Roles.Add("RunThinClient");
	ProfileDescription.Roles.Add("SaveUserData");
	ProfileDescription.Roles.Add("AdditionalInformationChange");
	ProfileDescription.Roles.Add("ChangePrintFormsTemplates");
	ProfileDescription.Roles.Add("EditCurrentUser");
	ProfileDescription.Roles.Add("IntegrationWith1CBuhphone");
	ProfileDescription.Roles.Add("ReportsVariantsUsage");
	ProfileDescription.Roles.Add("UseGlobalAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("UseAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("UseInformationCenter");
	ProfileDescription.Roles.Add("RemindersUse");
	ProfileDescription.Roles.Add("UseSubordinationStructure");
	ProfileDescription.Roles.Add("UseEMailAccounts");
	ProfileDescription.Roles.Add("EditObjectAttributes");
	ProfileDescription.Roles.Add("ReadBasicReferenceData");
	ProfileDescription.Roles.Add("ReadAdditionalInformation");
	ProfileDescription.Roles.Add("ReadIndividuals");
	ProfileDescription.Roles.Add("ViewApplicationChangesDescription");
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		ProfileDescription.Roles.Add("RunThickClient");
	EndIf;
	
	// Electronic document exchange
	ProfileDescription.Roles.Add("BasicRightsOfED");
	ProfileDescription.Roles.Add("EDExchangeExecution");
	ProfileDescription.Roles.Add("EDReading");
	
	// Online user support
	ProfileDescription.Roles.Add("BasicRightsIUS");
	ProfileDescription.Roles.Add("ConnectionToOnlineSupportService");
	ProfileDescription.Roles.Add("UseUOSMonitor");
	
	// SB
	ProfileDescription.Roles.Add("SBBasicRights");
	ProfileDescription.Roles.Add("AddChangeEventsAndTasks");
	ProfileDescription.Roles.Add("AddChangeCounterparties");
	ProfileDescription.Roles.Add("ReadCashBalances");
	ProfileDescription.Roles.Add("ReadOrdersAndPaidBillsBalances");
	ProfileDescription.Roles.Add("ReadSettlementsBalances");
	ProfileDescription.Roles.Add("ReadSettlementsDocuments");
	ProfileDescription.Roles.Add("AddChangeBankSubsystem");
	ProfileDescription.Roles.Add("AddChangePettyCashSubsystem");
	ProfileDescription.Roles.Add("AddChangeFundsPlanningSubsystem");
	ProfileDescription.Roles.Add("AddCurrenciesChange");
	ProfileDescription.Roles.Add("AddChangeCashFlowItems");
	ProfileDescription.Roles.Add("UseFundsReports");
	ProfileDescription.Roles.Add("UsePeripherals");
	ProfileDescription.Roles.Add("DataExchangeWithMobileApplication");
	
	// SB Work with files
	ProfileDescription.Roles.Add("FileFolderOperations");
	ProfileDescription.Roles.Add("FileOperations");
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("CounterpartiesGroup", "InitiallyAllAllowed");
	ProfileDescription.AccessKinds.Add("PettyCashes", "InitiallyAllAllowed");
	
	ProfileDescriptions.Add(ProfileDescription);
	
#EndRegion

#Region Salary
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "Salary" profile filling.
	//
	ProfileDescription = AccessManagement.AccessGroupProfileNewDescription();
	ProfileDescription.Name           = "Salary";
	ProfileDescription.ID = "76337574-bff4-11df-9174-e0cb4ed5f4c3";
	ProfileDescription.Description = NStr("en='Salary';ru='Зарплата'");
	ProfileDescription.Definition = NStr("en='Use this profile to work with section Payroll: HR management and payroll management.';ru='Под профилем осуществляется работа с разделом Зарплата: кадровый учет и расчет зарплаты.'"
	);
	
	// SSL
	ProfileDescription.Roles.Add("BasicRights");
	ProfileDescription.Roles.Add("OutputToPrinterClipboardFile");
	ProfileDescription.Roles.Add("AddChangeBasicReferenceData");
	ProfileDescription.Roles.Add("AddChangeReportsVariants");
	ProfileDescription.Roles.Add("AddChangeIndividualsPersonalData");
	ProfileDescription.Roles.Add("AddEditCountries");
	ProfileDescription.Roles.Add("AddChangeIndividuals");
	ProfileDescription.Roles.Add("RunWebClient");
	ProfileDescription.Roles.Add("RunThinClient");
	ProfileDescription.Roles.Add("SaveUserData");
	ProfileDescription.Roles.Add("AdditionalInformationChange");
	ProfileDescription.Roles.Add("ChangePrintFormsTemplates");
	ProfileDescription.Roles.Add("EditCurrentUser");
	ProfileDescription.Roles.Add("IntegrationWith1CBuhphone");
	ProfileDescription.Roles.Add("ReportsVariantsUsage");
	ProfileDescription.Roles.Add("UseGlobalAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("UseAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("UseInformationCenter");
	ProfileDescription.Roles.Add("RemindersUse");
	ProfileDescription.Roles.Add("UseSubordinationStructure");
	ProfileDescription.Roles.Add("UseEMailAccounts");
	ProfileDescription.Roles.Add("PersonalDataProcessingConsentPreparation");
	ProfileDescription.Roles.Add("EditObjectAttributes");
	ProfileDescription.Roles.Add("ReadBasicReferenceData");
	ProfileDescription.Roles.Add("ReadAdditionalInformation");
	ProfileDescription.Roles.Add("ReadIndividualsPersonalData");
	ProfileDescription.Roles.Add("ReadIndividuals");
	ProfileDescription.Roles.Add("ViewApplicationChangesDescription");
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		ProfileDescription.Roles.Add("RunThickClient");
	EndIf;
	
	// Electronic document exchange
	ProfileDescription.Roles.Add("BasicRightsOfED");
	ProfileDescription.Roles.Add("EDExchangeExecution");
	ProfileDescription.Roles.Add("EDReading");
	
	// Online user support
	ProfileDescription.Roles.Add("BasicRightsIUS");
	ProfileDescription.Roles.Add("ConnectionToOnlineSupportService");
	ProfileDescription.Roles.Add("UseUOSMonitor");
	
	// SB
	ProfileDescription.Roles.Add("SBBasicRights");
	ProfileDescription.Roles.Add("UsePeripherals");
	ProfileDescription.Roles.Add("AddChangeEventsAndTasks");
	ProfileDescription.Roles.Add("AddChangeHumanResourcesSubsystem");
	ProfileDescription.Roles.Add("AddChangePayrollSubsystem");
	ProfileDescription.Roles.Add("ReadAccrualsAndTimesheetBalances");
	ProfileDescription.Roles.Add("UsePayrollReports");
	
	// SB Work with files
	ProfileDescription.Roles.Add("FileFolderOperations");
	ProfileDescription.Roles.Add("FileOperations");
	
	ProfileDescriptions.Add(ProfileDescription);
	
#EndRegion
	
EndProcedure

// Fills in the dependencies of access rights of
// "subordinate" object, for example, tasks PerformerTask from "leading" object, such as business process Job, that differ from the standard one.
//
// Rights dependencies are used in the standard template of access restriction for access kind "Object":
// 1) normally when reading "subordinate"
//    object the right for reading of
//    "leading" object and the absence of restriction for "leading" object reading is checked;
// 2) normally when you add, edit or
//    delete "subordinate" object the existence of
//    the right on "leading" object change is checked as well as the absence of restriction on "leading" object change.
//
// Only one reassignment is allowed compared to standard one:
// in paragraph "2)" instead of check of right on
// "leading" object change set check of right on "leading" object reading.
//
// Parameters:
//  DependenciesRight - ValueTable - with columns:
//   * LeadingTable     - String - for example, "BusinessProcess.Job".
//   * SubordinateTable - String - for example, "Job.ExecutiveJob".
//
Procedure WhenFillingOutAccessRightDependencies(DependenciesRight) Export
	
	
	
EndProcedure

// Fills in descriptions of possible rights appointed for objects, specified types.
// 
// Parameters:
//  PossibleRights - ValueTable - with columns, for the description of
//                   which, see comments to the InformationRegisters.ObjectRightSettings.PossibleRights() function.
//
Procedure OnFillingInPossibleRightsForObjectRightsSettings(PossibleRights) Export
	
EndProcedure

// Determines used user interface kind for the access setting.
//
//  Simplified interface is suitable for configurations
// with a small amount of users as many functions are not required and they can
// be hidden (they can not be hidden only with the
// functional option as revision of the access groups and profiles content is required).
//
// Parameters:
//  SimplifiedInterface - Boolean (return value). Initial value is False.
//
Procedure OnDefineAccessSettingInterface(SimplifiedInterface) Export
	
	SimplifiedInterface = True;
	
EndProcedure

// Fills in the use of access kinds depending on
// functional options of the configuration, for example, UseProductsAndServicesAccessGroups.
//
// Parameters:
//  AccessKind    - String - access kind name specified in the OnFillingAccessKinds procedure.
//  Use - Boolean - initial value is True.
// 
Procedure OnFillingAccessTypeUse(AccessKind, Use) Export
	
	If AccessKind = "CounterpartiesGroup" Then
		Use = Constants.UseCounterpartiesAccessGroups.Get();
	EndIf;
	
EndProcedure

// Fills the content of access kinds used when metadata objects rights are restricted.
// If the content of access kinds is not filled, "Access rights" report will show incorrect information.
//
// Only the access types clearly used in access restriction templates
// must be filled, while the access types used in access values sets may
// be received from the current data register AccessValueSets.
//
//  To prepare the procedure content automatically, the
// developer tools for subsystem Access Management shall be used.
//
// Parameters:
//  Definition     - String - multiline string as <Table>.<Right>.<AccessKind>[.Object table].
//                 For
//                           example,
//                           Document.SupplierInvoice.Read.Company
//                           Document.SupplierInvoice.Read.Counterparties
//                           Document.SupplierInvoice.Change.Companies
//                           Document.SupplierInvoice.Change.Counterparties
//                           Document.EMails.Read.Object.Document.EMails
//                           Document.EMails.Change.Object.Document.EMails
//                           Document.Files.Read.Object.Catalog.FileFolders
//                           Document.Files.Read.Object.Document.EMail
//                 Document.Files.Change.Object.Catalog.FileFolders Document.Files.Change.Object.Document.EMail Access kind Object predefined as literal. This access kind is
//                 used in the access limitations templates as "ref" to another
//                 object according to which the current table object is restricted.
//                 When the Object access kind is specified, you should
//                 also specify tables types that are used for this
//                 access kind. I.e. enumerate types that correspond to
//                 the field used in the access limitation template in the pair with the Object access kind. While enumerating types by the "Object" access kind, you need to list only those field types that the field has.
//                 InformationRegisters.AccessValueSets.Object, the rest types are extra.
// 
Procedure OnFillingKindsOfRestrictionsRightsOfMetadataObjects(Definition) Export
	
	Definition = Definition + "
	|Catalog.FileVersions.Reading.Object.Document.ExpenseReport Catalog.FileVersions.Reading.Object.Document.WorkOrder Catalog.FileVersions.Reading.Object.Document.CustomerOrder Catalog.FileVersions.Reading.Object.Document.PurchaseOrder Catalog.FileVersions.Reading.Object.Document.InventoryReconciliation Catalog.FileVersions.Reading.Object.Document.PaymentReceipt Catalog.FileVersions.Reading.Object.Document.SupplierInvoice Catalog.FileVersions.Reading.Object.Document.PaymentExpense Catalog.FileVersions.Reading.Object.Document.Event Catalog.FileVersions.Reading.Object.Document.SupplierInvoiceForPayment Catalog.FileVersions.Reading.Object.Document.CustomerInvoiceNote Catalog.FileVersions.Reading.Object.Document.SupplierInvoiceNote Catalog.FileVersions.Reading.Object.Catalog.CounterpartyContracts Catalog.FileVersions.Reading.Object.Catalog.Counterparties Catalog.FileVersions.Reading.Object.Catalog.ProductsAndServices Catalog.FileVersions.Reading.Object.Catalog.Companies Catalog.FileVersions.Reading.Object.Catalog.Specifications Catalog.FileVersions.Change.Object.Document.ExpenseReport Catalog.FileVersions.Change.Object.Document.WorkOrder Catalog.FileVersions.Change.Object.Document.CustomerOrder Catalog.FileVersions.Change.Object.Document.PurchaseOrder Catalog.FileVersions.Change.Object.Document.InventoryReconciliation Catalog.FileVersions.Change.Object.Document.PaymentReceipt Catalog.FileVersions.Change.Object.Document.SupplierInvoice Catalog.FileVersions.Change.Object.Document.PaymentExpense Catalog.FileVersions.Change.Object.Document.Event Catalog.FileVersions.Change.Object.Document.SupplierInvoiceForPayment Catalog.FileVersions.Change.Object.Document.CustomerInvoiceNote Catalog.FileVersions.Change.Object.Document.SupplierInvoiceNote Catalog.FileVersions.Change.Object.Catalog.CounterpartyContracts Catalog.FileVersions.Change.Object.Catalog.Counterparties Catalog.FileVersions.Change.Object.Catalog.ProductsAndServices Catalog.FileVersions.Change.Object.Catalog.Companies Catalog.FileVersions.Change.Object.Catalog.Specifications Catalog.CounterpartiesAccessGroups.Reading.CounterpartiesGroup Catalog.PettyCashes.Reading.PettyCashes Catalog.PettyCashes.Change.PettyCashes Catalog.Counterparties.Reading.CounterpartiesGroup Catalog.Counterparties.Change.CounterpartiesGroup Catalog.Files.Reading.Object.Document.ExpenseReport Catalog.Files.Reading.Object.Document.WorkOrder Catalog.Files.Reading.Object.Document.CustomerOrder Catalog.Files.Reading.Object.Document.PurchaseOrder Catalog.Files.Reading.Object.Document.InventoryReconciliation Catalog.Files.Reading.Object.Document.PaymentReceipt Catalog.Files.Reading.Object.Document.SupplierInvoice Catalog.Files.Reading.Object.Document.PaymentExpense Catalog.Files.Reading.Object.Document.Event Catalog.Files.Reading.Object.Document.SupplierInvoiceForPayment Catalog.Files.Reading.Object.Document.CustomerInvoiceNote Catalog.Files.Reading.Object.Document.SupplierInvoiceNote Catalog.Files.Reading.Object.Catalog.CounterpartyContracts Catalog.Files.Reading.Object.Catalog.Counterparties Catalog.Files.Reading.Object.Catalog.ProductsAndServices Catalog.Files.Reading.Object.Catalog.Companies Catalog.Files.Reading.Object.Catalog.Specifications Catalog.Files.Change.Object.Document.ExpenseReport Catalog.Files.Change.Object.Document.WorkOrder Catalog.Files.Change.Object.Document.CustomerOrder Catalog.Files.Change.Object.Document.PurchaseOrder Catalog.Files.Change.Object.Document.InventoryReconciliation Catalog.Files.Change.Object.Document.PaymentReceipt Catalog.Files.Change.Object.Document.SupplierInvoice Catalog.Files.Change.Object.Document.PaymentExpense Catalog.Files.Change.Object.Document.Event Catalog.Files.Change.Object.Document.SupplierInvoiceForPayment Catalog.Files.Change.Object.Document.CustomerInvoiceNote Catalog.Files.Change.Object.Document.SupplierInvoiceNote Catalog.Files.Change.Object.Catalog.CounterpartyContracts Catalog.Files.Change.Object.Catalog.Counterparties Catalog.Files.Change.Object.Catalog.ProductsAndServices Catalog.Files.Change.Object.Catalog.Companies Catalog.Files.Change.Object.Catalog.Specifications Document.ExpenseReport.Reading.CounterpartiesGroup Document.ExpenseReport.Change.CounterpartiesGroup Document.AcceptanceCertificate.Reading.CounterpartiesGroup Document.AcceptanceCertificate.Change.CounterpartiesGroup Document.CustomerOrder.Reading.CounterpartiesGroup Document.CustomerOrder.Change.CounterpartiesGroup Document.CashTransfer.Reading.PettyCashes Document.CashTransfer.Change.PettyCashes Document.CashTransferPlan.Reading.PettyCashes Document.CashTransferPlan.Change.PettyCashes Document.PaymentOrder.Reading.CounterpartiesGroup Document.PaymentOrder.Change.CounterpartiesGroup Document.CashReceipt.Reading.CounterpartiesGroup Document.CashReceipt.Reading.PettyCashes Document.CashReceipt.Change.CounterpartiesGroup Document.CashReceipt.Change.PettyCashes Document.PaymentReceiptPlan.Reading.CounterpartiesGroup Document.PaymentReceiptPlan.Change.CounterpartiesGroup Document.PaymentReceipt.Reading.CounterpartiesGroup Document.PaymentReceipt.Change.CounterpartiesGroup Document.SupplierInvoice.Reading.CounterpartiesGroup Document.SupplierInvoice.Change.CounterpartiesGroup Document.CashOutflowPlan.Reading.CounterpartiesGroup Document.CashOutflowPlan.Change.CounterpartiesGroup Document.CashPayment.Reading.CounterpartiesGroup Document.CashPayment.Reading.PettyCashes Document.CashPayment.Change.CounterpartiesGroup Document.CashPayment.Change.PettyCashes Document.CustomerInvoice.Reading.CounterpartiesGroup Document.CustomerInvoice.Change.CounterpartiesGroup Document.PaymentExpense.Reading.CounterpartiesGroup Document.PaymentExpense.Change.CounterpartiesGroup Document.Event.Reading.CounterpartiesGroup Document.Event.Change.CounterpartiesGroup Document.InvoiceForPayment.Reading.CounterpartiesGroup Document.InvoiceForPayment.Change.CounterpartiesGroup Document.CustomerInvoiceNote.Reading.CounterpartiesGroup Document.CustomerInvoiceNote.Change.CounterpartiesGroup Document.SupplierInvoiceNote.Reading.CounterpartiesGroup Document.SupplierInvoiceNote.Change.CounterpartiesGroup DocumentJournal.FundsPlanningDocuments.Reading.CounterpartiesGroup DocumentJournal.BankDocuments.Reading.CounterpartiesGroup DocumentJournal.CashDocuments.Reading.CounterpartiesGroup DocumentJournal.CashDocuments.Reading.PettyCashes DocumentJournal.SalesDocuments.Reading.CounterpartiesGroup DocumentJournal.CashReceiptDocuments.Reading.CounterpartiesGroup DocumentJournal.CashReceiptDocuments.Reading.PettyCashes DocumentJournal.CashExpenseDocuments.Reading.CounterpartiesGroup DocumentJournal.CashExpenseDocuments.Reading.PettyCashes InformationRegister.VersionStoredFiles.Reading.Object.Document.ExpenseReport InformationRegister.VersionStoredFiles.Reading.Object.Document.WorkOrder InformationRegister.VersionStoredFiles.Reading.Object.Document.CustomerOrder InformationRegister.VersionStoredFiles.Reading.Object.Document.PurchaseOrder InformationRegister.VersionStoredFiles.Reading.Object.Document.InventoryReconciliation InformationRegister.VersionStoredFiles.Reading.Object.Document.PaymentReceipt InformationRegister.VersionStoredFiles.Reading.Object.Document.SupplierInvoice InformationRegister.VersionStoredFiles.Reading.Object.Document.PaymentExpense InformationRegister.VersionStoredFiles.Reading.Object.Document.Event InformationRegister.VersionStoredFiles.Reading.Object.Document.SupplierInvoiceForPayment InformationRegister.VersionStoredFiles.Reading.Object.Document.CustomerInvoiceNote InformationRegister.VersionStoredFiles.Reading.Object.Document.SupplierInvoiceNote InformationRegister.VersionStoredFiles.Reading.Object.Catalog.CounterpartyContracts InformationRegister.VersionStoredFiles.Reading.Object.Catalog.Counterparties InformationRegister.VersionStoredFiles.Reading.Object.Catalog.ProductsAndServices InformationRegister.VersionStoredFiles.Reading.Object.Catalog.Companies InformationRegister.VersionStoredFiles.Reading.Object.Catalog.Specifications AccumulationRegister.InventoryTransferSchedule.Reading.CounterpartiesGroup AccumulationRegister.CashAssets.Reading.PettyCashes AccumulationRegister.CustomerOrders.Reading.CounterpartiesGroup AccumulationRegister.PaymentCalendar.Reading.PettyCashes AccumulationRegister.OrdersPlacement.Reading.CounterpartiesGroup AccumulationRegister.AccountsReceivable.Reading.CounterpartiesGroup AccumulationRegister.AccountsPayable.Reading.CounterpartiesGroup
	|";
	
EndProcedure

// Allows to rewrite dependent sets of access values of other objects.
//
//  Called from procedures:
// AccessManagementService.WriteAccessValuesSets(),
// AccessManagementService.WriteDependentAccessValuesSets().
//
// Parameters:
//  Ref       - CatalogRef, DocumentRef, ... - reference to the
//                 object for which sets of access values are recorded.
//
//  RefsOnDependentObjects - Array - items array of the type CatalogRef, DocumentRef, ...
//                 Contains references to objects with dependent sets of access values.
//                 Initial value - empty array.
//
Procedure OnChangeSetsOfAccessValues(Ref, RefsOnDependentObjects) Export
	
	
	
EndProcedure

#EndRegion
