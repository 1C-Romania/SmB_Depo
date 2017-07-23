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
	AccessKind.Presentation    = NStr("en='Cash funds';ru='Кассы'");
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
	ProfileDescription.Description = NStr("en='Sales';ru='Продажи'");
	ProfileDescription.Definition = NStr("en='Use this profile to operate with the Sales and Service sections.';ru='Под профилем осуществляется работа с разделами Продажи и Сервис.'"
	);
	
	// SSL
	ProfileDescription.Roles.Add("BasicRights");
	ProfileDescription.Roles.Add("OutputToPrinterClipboardFile");
	//ProfileDescription.Roles.Add("ExchangeDataWithSitesProcessing");
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
	ProfileDescription.Roles.Add("IntegrationWith1CConnect");
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
	//ProfileDescription.Roles.Add("Use1CTaxcomService");
	
	// SB
	ProfileDescription.Roles.Add("BasicRightsSB");
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
	ProfileDescription.Definition = NStr("en='Service profile that allows you to edit prices in documents for managers.';ru='Служебный профиль, определяющий возможность редактирования цен в документах для менеджеров.'"
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
	ProfileDescription.Description = NStr("en='Edit products and services (additionally)';ru='Редактирование номенклатуры (дополнительно)'");
	ProfileDescription.Definition = NStr("en='Service profile that allows you to edit products and services for managers.';ru='Служебный профиль, определяющий возможность редактирования номенклатуры для менеджеров.'"
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
	ProfileDescription.Definition = NStr("en='Service profile that allows you to work with returns from customers.';ru='Служебный профиль, определяющий возможность работы с возвратами от покупателей.'"
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
	//ProfileDescription.Roles.Add("ExchangeDataWithSitesProcessing");
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
	ProfileDescription.Roles.Add("IntegrationWith1CConnect");
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
	//ProfileDescription.Roles.Add("Use1CTaxcomService");
	
	// SB
	ProfileDescription.Roles.Add("BasicRightsSB");
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
	ProfileDescription.Description = NStr("en='Returns to suppliers (additionally)';ru='Возвраты поставщикам (дополнительно)'");
	ProfileDescription.Definition = NStr("en='Service profile that allows you to work with returns to suppliers.';ru='Служебный профиль, определяющий возможность работы с возвратами поставщикам.'"
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
	ProfileDescription.Definition = NStr("en='Use this profile to operate with the Production section.';ru='Под профилем осуществляется работа с разделом Производство.'"
	);
	
	// SSL
	ProfileDescription.Roles.Add("BasicRights");
	ProfileDescription.Roles.Add("OutputToPrinterClipboardFile");
	//ProfileDescription.Roles.Add("ExchangeDataWithSitesProcessing");
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
	ProfileDescription.Roles.Add("IntegrationWith1CConnect");
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
	//ProfileDescription.Roles.Add("Use1CTaxcomService");
	
	// SB
	ProfileDescription.Roles.Add("BasicRightsSB");
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
	ProfileDescription.Definition = NStr("en='Use this profile to operate with the Funds section: bank, cash fund and payment calendar.';ru='Под профилем осуществляется работа с разделом Деньги: банк, касса и платежный календарь.'"
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
	ProfileDescription.Roles.Add("IntegrationWith1CConnect");
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
	ProfileDescription.Roles.Add("BasicRightsSB");
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
	ProfileDescription.Description = NStr("en='Payroll';ru='Зарплата'");
	ProfileDescription.Definition = NStr("en='Use this profile to operate with the Payroll section: HR recordkeeping and payroll.';ru='Под профилем осуществляется работа с разделом Зарплата: кадровый учет и расчет зарплаты.'"
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
	ProfileDescription.Roles.Add("IntegrationWith1CConnect");
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
	ProfileDescription.Roles.Add("BasicRightsSB");
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
//                           Document.SupplierInvoice.Update.Companies
//                           Document.SupplierInvoice.Update.Counterparties
//                           Document.EMails.Read.Object.Document.EMails
//                           Document.EMails.Update.Object.Document.EMails
//                           Document.Files.Read.Object.Catalog.FileFolders
//                           Document.Files.Read.Object.Document.EMail
//                 Document.Files.Update.Object.Catalog.FileFolders Document.Files.Update.Object.Document.EMail Access kind Object predefined as literal. This access kind is
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
	|Catalog.FileVersions.Read.Object.Document.ExpenseReport
	|Catalog.FileVersions.Read.Object.Document.WorkOrder
	|Catalog.FileVersions.Read.Object.Document.CustomerOrder
	|Catalog.FileVersions.Read.Object.Document.PurchaseOrder
	|Catalog.FileVersions.Read.Object.Document.InventoryReconciliation
	|Catalog.FileVersions.Read.Object.Document.PaymentReceipt
	|Catalog.FileVersions.Read.Object.Document.SupplierInvoice
	|Catalog.FileVersions.Read.Object.Document.PaymentExpense
	|Catalog.FileVersions.Read.Object.Document.Event
	|Catalog.FileVersions.Read.Object.Document.SupplierInvoiceForPayment
	|Catalog.FileVersions.Read.Object.Catalog.CounterpartyContracts
	|Catalog.FileVersions.Read.Object.Catalog.Counterparties
	|Catalog.FileVersions.Read.Object.Catalog.ProductsAndServices
	|Catalog.FileVersions.Read.Object.Catalog.Companies
	|Catalog.FileVersions.Read.Object.Catalog.Specifications
	|Catalog.FileVersions.Update.Object.Document.ExpenseReport
	|Catalog.FileVersions.Update.Object.Document.WorkOrder
	|Catalog.FileVersions.Update.Object.Document.CustomerOrder
	|Catalog.FileVersions.Update.Object.Document.PurchaseOrder
	|Catalog.FileVersions.Update.Object.Document.InventoryReconciliation
	|Catalog.FileVersions.Update.Object.Document.PaymentReceipt
	|Catalog.FileVersions.Update.Object.Document.SupplierInvoice
	|Catalog.FileVersions.Update.Object.Document.PaymentExpense
	|Catalog.FileVersions.Update.Object.Document.Event
	|Catalog.FileVersions.Update.Object.Document.SupplierInvoiceForPayment
	|Catalog.FileVersions.Update.Object.Catalog.CounterpartyContracts
	|Catalog.FileVersions.Update.Object.Catalog.Counterparties
	|Catalog.FileVersions.Update.Object.Catalog.ProductsAndServices
	|Catalog.FileVersions.Update.Object.Catalog.Companies
	|Catalog.FileVersions.Update.Object.Catalog.Specifications
	|Catalog.CounterpartiesAccessGroups.Read.CounterpartiesGroup
	|Catalog.PettyCashes.Read.PettyCashes
	|Catalog.PettyCashes.Update.PettyCashes
	|Catalog.Counterparties.Read.CounterpartiesGroup
	|Catalog.Counterparties.Update.CounterpartiesGroup
	|Catalog.Files.Read.Object.Document.ExpenseReport
	|Catalog.Files.Read.Object.Document.WorkOrder
	|Catalog.Files.Read.Object.Document.CustomerOrder
	|Catalog.Files.Read.Object.Document.PurchaseOrder
	|Catalog.Files.Read.Object.Document.InventoryReconciliation
	|Catalog.Files.Read.Object.Document.PaymentReceipt
	|Catalog.Files.Read.Object.Document.SupplierInvoice
	|Catalog.Files.Read.Object.Document.PaymentExpense
	|Catalog.Files.Read.Object.Document.Event
	|Catalog.Files.Read.Object.Document.SupplierInvoiceForPayment
	|Catalog.Files.Read.Object.Catalog.CounterpartyContracts
	|Catalog.Files.Read.Object.Catalog.Counterparties
	|Catalog.Files.Read.Object.Catalog.ProductsAndServices
	|Catalog.Files.Read.Object.Catalog.Companies
	|Catalog.Files.Read.Object.Catalog.Specifications
	|Catalog.Files.Update.Object.Document.ExpenseReport
	|Catalog.Files.Update.Object.Document.WorkOrder
	|Catalog.Files.Update.Object.Document.CustomerOrder
	|Catalog.Files.Update.Object.Document.PurchaseOrder
	|Catalog.Files.Update.Object.Document.InventoryReconciliation
	|Catalog.Files.Update.Object.Document.PaymentReceipt
	|Catalog.Files.Update.Object.Document.SupplierInvoice
	|Catalog.Files.Update.Object.Document.PaymentExpense
	|Catalog.Files.Update.Object.Document.Event
	|Catalog.Files.Update.Object.Document.SupplierInvoiceForPayment
	|Catalog.Files.Update.Object.Catalog.CounterpartyContracts
	|Catalog.Files.Update.Object.Catalog.Counterparties
	|Catalog.Files.Update.Object.Catalog.ProductsAndServices
	|Catalog.Files.Update.Object.Catalog.Companies
	|Catalog.Files.Update.Object.Catalog.Specifications
	|Document.ExpenseReport.Read.CounterpartiesGroup
	|Document.ExpenseReport.Update.CounterpartiesGroup
	|Document.AcceptanceCertificate.Read.CounterpartiesGroup
	|Document.AcceptanceCertificate.Update.CounterpartiesGroup
	|Document.CustomerOrder.Read.CounterpartiesGroup
	|Document.CustomerOrder.Update.CounterpartiesGroup
	|Document.CashTransfer.Read.PettyCashes
	|Document.CashTransfer.Update.PettyCashes
	|Document.CashTransferPlan.Read.PettyCashes
	|Document.CashTransferPlan.Update.PettyCashes
	|Document.PaymentOrder.Read.CounterpartiesGroup
	|Document.PaymentOrder.Update.CounterpartiesGroup
	|Document.CashReceipt.Read.CounterpartiesGroup
	|Document.CashReceipt.Read.PettyCashes
	|Document.CashReceipt.Update.CounterpartiesGroup
	|Document.CashReceipt.Update.PettyCashes
	|Document.PaymentReceiptPlan.Read.CounterpartiesGroup
	|Document.PaymentReceiptPlan.Update.CounterpartiesGroup
	|Document.PaymentReceipt.Read.CounterpartiesGroup
	|Document.PaymentReceipt.Update.CounterpartiesGroup
	|Document.SupplierInvoice.Read.CounterpartiesGroup
	|Document.SupplierInvoice.Update.CounterpartiesGroup
	|Document.CashOutflowPlan.Read.CounterpartiesGroup
	|Document.CashOutflowPlan.Update.CounterpartiesGroup
	|Document.CashPayment.Read.CounterpartiesGroup
	|Document.CashPayment.Read.PettyCashes
	|Document.CashPayment.Update.CounterpartiesGroup
	|Document.CashPayment.Update.PettyCashes
	|Document.CustomerInvoice.Read.CounterpartiesGroup
	|Document.CustomerInvoice.Update.CounterpartiesGroup
	|Document.PaymentExpense.Read.CounterpartiesGroup
	|Document.PaymentExpense.Update.CounterpartiesGroup
	|Document.Event.Read.CounterpartiesGroup
	|Document.Event.Update.CounterpartiesGroup
	|Document.InvoiceForPayment.Read.CounterpartiesGroup
	|Document.InvoiceForPayment.Update.CounterpartiesGroup
	|DocumentJournal.FundsPlanningDocuments.Read.CounterpartiesGroup
	|DocumentJournal.BankDocuments.Read.CounterpartiesGroup
	|DocumentJournal.CashDocuments.Read.CounterpartiesGroup
	|DocumentJournal.CashDocuments.Read.PettyCashes
	|DocumentJournal.SalesDocuments.Read.CounterpartiesGroup
	|DocumentJournal.CashReceiptDocuments.Read.CounterpartiesGroup
	|DocumentJournal.CashReceiptDocuments.Read.PettyCashes
	|DocumentJournal.CashExpenseDocuments.Read.CounterpartiesGroup
	|DocumentJournal.CashExpenseDocuments.Read.PettyCashes
	|InformationRegister.VersionStoredFiles.Read.Object.Document.ExpenseReport
	|InformationRegister.VersionStoredFiles.Read.Object.Document.WorkOrder
	|InformationRegister.VersionStoredFiles.Read.Object.Document.CustomerOrder
	|InformationRegister.VersionStoredFiles.Read.Object.Document.PurchaseOrder
	|InformationRegister.VersionStoredFiles.Read.Object.Document.InventoryReconciliation
	|InformationRegister.VersionStoredFiles.Read.Object.Document.PaymentReceipt
	|InformationRegister.VersionStoredFiles.Read.Object.Document.SupplierInvoice
	|InformationRegister.VersionStoredFiles.Read.Object.Document.PaymentExpense
	|InformationRegister.VersionStoredFiles.Read.Object.Document.Event
	|InformationRegister.VersionStoredFiles.Read.Object.Document.SupplierInvoiceForPayment
	|InformationRegister.VersionStoredFiles.Read.Object.Catalog.CounterpartyContracts
	|InformationRegister.VersionStoredFiles.Read.Object.Catalog.Counterparties
	|InformationRegister.VersionStoredFiles.Read.Object.Catalog.ProductsAndServices
	|InformationRegister.VersionStoredFiles.Read.Object.Catalog.Companies
	|InformationRegister.VersionStoredFiles.Read.Object.Catalog.Specifications
	|AccumulationRegister.InventoryTransferSchedule.Read.CounterpartiesGroup
	|AccumulationRegister.CashAssets.Read.PettyCashes
	|AccumulationRegister.CustomerOrders.Read.CounterpartiesGroup
	|AccumulationRegister.PaymentCalendar.Read.PettyCashes
	|AccumulationRegister.OrdersPlacement.Read.CounterpartiesGroup
	|AccumulationRegister.AccountsReceivable.Read.CounterpartiesGroup
	|AccumulationRegister.AccountsPayable.Read.CounterpartiesGroup
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
