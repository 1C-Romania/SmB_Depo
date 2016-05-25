////////////////////////////////////////////////////////////////////////////////
// Infobase update (SB)
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Information about library (or configuration).

// Fills out basic information about the library or default configuration.
// Library which name matches configuration name in metadata is defined as default configuration.
// 
// Parameters:
//  Definition - Structure - information about the library:
//
//   Name                 - String - name of the library, for example, "StandardSubsystems".
//   Version              - String - version in the format of 4 digits, for example, "2.1.3.1".
//
//   RequiredSubsystems - Array - names of other libraries (String) on which this library depends.
//                                  Update handlers of such libraries should
//                                  be called before update handlers of this library.
//                                  IN case of circular dependencies or, on
//                                  the contrary, absence of any dependencies, call out
//                                  procedure of update handlers is defined by the order of modules addition in procedure WhenAddingSubsystems of common module ConfigurationSubsystemsOverridable.
//
Procedure OnAddSubsystem(Definition) Export
	
	Definition.Name	= "SmallBusiness";
	Definition.Version = "1.5.3.37";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update handlers

// Adds to the list of
// procedures (IB data update handlers) for all supported versions of the library or configuration.
// Appears before the start of IB data update to build up the update plan.
//
// Parameters:
//  Handlers - ValueTable - See description
// of the fields in the procedure InfobaseUpdate.UpdateHandlersNewTable
//
// Example of adding the procedure-processor to the list:
//  Handler = Handlers.Add();
//  Handler.Version              = "1.0.0.0";
//  Handler.Procedure           = "IBUpdate.SwitchToVersion_1_0_0_0";
//  Handler.ExclusiveMode    = False;
//  Handler.Optional        = True;
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.0.1";
	Handler.InitialFilling = True;
	Handler.Procedure = "InfobaseUpdateSB.FirstLaunch";
	
	Handler = Handlers.Add();
	Handler.PerformModes = "Delay";
	Handler.Version = "1.5.3.6";
	Handler.Procedure = "InfobaseUpdateSB.ChangesProhibitionsSectionsDatesUpdate";
	Handler.Comment = NStr("en = 'Update changes ban dates sections. 
		|Starting with version 1.5.3 an ability appeared to separately manage the dates of the ban to change the documents Customer order, Vendor order.'");
		
	Handler = Handlers.Add();
	Handler.PerformModes = "Delay";
	Handler.Version = "1.5.3.13";
	Handler.InitialFilling = True;
	Handler.Procedure = "InfobaseUpdateSB.UpdateContractForms";
	Handler.Comment = NStr("en = 'Update contracts forms.'");
	
	Handler = Handlers.Add();
	Handler.PerformModes = "Delay";
	Handler.Version = "1.5.3.26";
	Handler.Procedure = "InfobaseUpdateSB.TransferDataFromRemoteObjects";
	Handler.Comment = NStr("en = 'Transfers data from remote metadata objects of alcoholic products account.'");
	
EndProcedure

// Called before the procedures-handlers of IB data update.
//
Procedure BeforeInformationBaseUpdating() Export
	
	
	
EndProcedure

// Called after the completion of IB data update.
//		
// Parameters:
//   PreviousVersion       - String - version before update. 0.0.0.0 for an empty IB.
//   CurrentVersion          - String - version after update.
//   ExecutedHandlers - ValueTree - list of completed
//                                             update procedures-handlers grouped by version number.
//   PutSystemChangesDescription - Boolean - (return value) if
//                                you set True, then form with events description will be output. By default True.
//   ExclusiveMode           - Boolean - True if the update was executed in the exclusive mode.
//		
// Example of bypass of executed update handlers:
//		
// For Each Version From ExecutedHandlers.Rows Cycle
//		
// 	If Version.Version =
// 		 * Then Ha//ndler that can be run every time the version changes.
// 	Otherwise,
// 		 Handler runs for a definite version.
// 	EndIf;
//		
// 	For Each Handler From Version.Rows
// 		Cycle ...
// 	EndDo;
//		
// EndDo;
//
Procedure AfterInformationBaseUpdate(Val PreviousVersion, Val CurrentVersion,
		Val ExecutedHandlers, PutSystemChangesDescription, ExclusiveMode) Export
	
	
	
EndProcedure

// Called when you prepare a tabular document with description of changes in the application.
//
// Parameters:
//   Template - SpreadsheetDocument - description of update of all libraries and the configuration.
//           You can append or replace the template.
//          See also common template SystemChangesDescription.
//
Procedure OnPreparationOfUpdatesDescriptionTemplate(Val Template) Export
	
EndProcedure

// Adds procedure-processors of transition from another application to the list (with another configuration name).
// For example, for the transition between different but related configurations: base -> prof -> corp.
// Called before the beginning of the IB data update.
//
// Parameters:
//  Handlers - ValueTable - with columns:
//    * PreviousConfigurationName - String - name of the configuration, with which the transition is run;
//    * Procedure                 - String - full name of the procedure-processor of the transition from the PreviousConfigurationName application. 
//                                  ForExample, UpdatedERPInfobase.FillExportPolicy
//                                  is required to be export.
//
// Example of adding the procedure-processor to the list:
//  Handler = Handlers.Add();
//  Handler.PreviousConfigurationName  = TradeManagement;
//  Handler.Procedure                  = ERPInfobaseUpdate.FillAccountingPolicy;
//
Procedure OnAddTransitionFromAnotherApplicationHandlers(Handlers) Export
	
	
	
EndProcedure // OnAddHandlersOnTransitionFromAnotherApplication()

// Helps to override mode of the infobase data update.
// To use in rare (emergency) cases of transition that
// do not happen in a standard procedure of the update mode.
//
// Parameters:
//   DataUpdateMode - String - you can set one of the values in the handler:
//              InitialFilling     - if it is the first launch of an empty base (data field);
//              VersionUpdate        - if it is the first launch after the update of the data base configuration;
//              TransitionFromAnotherApplication - if first launch is run after the update of
// the data base configuration with changed name of the main configuration.
//
//   StandardProcessing  - Boolean - if you set False, then
//                                    a standard procedure of the update
//                                    mode fails and the DataUpdateMode value is used.
//
Procedure OnDefineDataUpdateMode(DataUpdateMode, StandardProcessing) Export
	
EndProcedure

// Called after all procedures-processors of transfer from another application (with another
// configuration name) and before beginning of the IB data update.
//
// Parameters:
//  PreviousConfigurationName    - String - name of configuration before transition.
//  PreviousConfigurationVersion - String - name of the previous configuration (before transition).
//  Parameters                    - Structure - 
//    * UpdateFromVersion   - Boolean - True by default. If you set
// False, only the mandatory handlers of the update will be run (with the * version).
//    * ConfigurationVersion           - String - version No after transition. 
//        By default it equals to the value of the configuration version in the metadata properties.
//        To run, for example, all update handlers from the PreviousConfigurationVersion version,
// you should set parameter value in PreviousConfigurationVersion.
//        To process all updates, set the 0.0.0.1 value.
//    * ClearInformationAboutPreviousConfiguration - Boolean - True by default. 
//        For cases when the previous configuration matches by name with the subsystem of the current configuration, set False.
//
Procedure OnEndTransitionFromAnotherApplication(Val PreviousConfigurationName, Val PreviousConfigurationVersion, Parameters) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE INTERFACE 

// Procedures supporting the first start (<step number on the first start>)

//(1) Procedure imports accounts management plan from layout.
//
Procedure ImportManagerialChartOfAccountsFirstLaunch()
	
	// 00.
	Account = ChartsOfAccounts.Managerial.Service.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.AccountsGroup;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 01.
	Account = ChartsOfAccounts.Managerial.FixedAssets.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.FixedAssets;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 02.
	Account = ChartsOfAccounts.Managerial.DepreciationFixedAssets.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.DepreciationFixedAssets;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 08.
	Account = ChartsOfAccounts.Managerial.InvestmentsInFixedAssets.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.OtherFixedAssets;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 10.
	Account = ChartsOfAccounts.Managerial.RawMaterialsAndMaterials.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.Inventory;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 20.
	Account = ChartsOfAccounts.Managerial.UnfinishedProduction.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.UnfinishedProduction;
	Account.ClosingAccount = ChartsOfAccounts.Managerial.ProductsFinishedProducts;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 25.
	Account = ChartsOfAccounts.Managerial.IndirectExpenses.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses;
	Account.ClosingAccount = ChartsOfAccounts.Managerial.UnfinishedProduction;
	Account.MethodOfDistribution = Enums.CostingBases.ProductionVolume;
	Account.Write();
	
	// 41.
	Account = ChartsOfAccounts.Managerial.ProductsFinishedProducts.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.Inventory;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 42.
	Account = ChartsOfAccounts.Managerial.TradeMarkup.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.TradeMarkup;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 50.
	Account = ChartsOfAccounts.Managerial.PettyCash.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.CashAssets;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 51.
	Account = ChartsOfAccounts.Managerial.Bank.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.CashAssets;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 57.
	Account = ChartsOfAccounts.Managerial.TransfersInProcess.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.CashAssets;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 58.
	Account = ChartsOfAccounts.Managerial.FinancialInvestments.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.CashAssets;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 60.
	Account = ChartsOfAccounts.Managerial.AccountsPayableAndContractors.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.AccountsGroup;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
		// 60.01
		Account = ChartsOfAccounts.Managerial.AccountsPayable.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.AccountsPayableAndContractors;
		Account.TypeOfAccount = Enums.GLAccountsTypes.Creditors;
		Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
		Account.Write();
		
		// 60.02
		Account = ChartsOfAccounts.Managerial.SettlementsByAdvancesIssued.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.AccountsPayableAndContractors;
		Account.TypeOfAccount = Enums.GLAccountsTypes.Debitors;
		Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
		Account.Write();
		
	// 62.
	Account = ChartsOfAccounts.Managerial.AccountsReceivableAndCustomers.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.AccountsGroup;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
		// 62.01
		Account = ChartsOfAccounts.Managerial.AccountsReceivable.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.AccountsReceivableAndCustomers;
		Account.TypeOfAccount = Enums.GLAccountsTypes.Debitors;
		Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
		Account.Write();
		
		// 62.02
		Account = ChartsOfAccounts.Managerial.AccountsByAdvancesReceived.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.AccountsReceivableAndCustomers;
		Account.TypeOfAccount = Enums.GLAccountsTypes.Creditors;
		Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
		Account.Write();
		
	// 66.
	Account = ChartsOfAccounts.Managerial.SettlementsByShorttermCreditsAndLoans.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.CreditsAndLoans;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 67.
	Account = ChartsOfAccounts.Managerial.AccountsByLongtermCreditsAndLoans.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.LongtermObligations;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 68.
	Account = ChartsOfAccounts.Managerial.TaxesSettlements.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.AccountsGroup;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
		// 68.01
		Account = ChartsOfAccounts.Managerial.Taxes.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.TaxesSettlements;
		Account.TypeOfAccount = Enums.GLAccountsTypes.Creditors;
		Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
		Account.Write();
		
		// 68.02
		Account = ChartsOfAccounts.Managerial.TaxesToRefund.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.TaxesSettlements;
		Account.TypeOfAccount = Enums.GLAccountsTypes.Debitors;
		Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
		Account.Write();
	
	// 70.
	Account = ChartsOfAccounts.Managerial.PayrollPaymentsOnPay.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.Creditors;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 71.
	Account = ChartsOfAccounts.Managerial.SettlementsWithAdvanceHolders.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.AccountsGroup;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
		// 71.01
		Account = ChartsOfAccounts.Managerial.AdvanceHolderPayments.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.SettlementsWithAdvanceHolders;
		Account.TypeOfAccount = Enums.GLAccountsTypes.Debitors;
		Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
		Account.Write();
		
		// 71.02
		Account = ChartsOfAccounts.Managerial.OverrunOfAdvanceHolders.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.SettlementsWithAdvanceHolders;
		Account.TypeOfAccount = Enums.GLAccountsTypes.Creditors;
		Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
		Account.Write();
		
	// 80.
	Account = ChartsOfAccounts.Managerial.StatutoryCapital.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.Capital;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 82.
	Account = ChartsOfAccounts.Managerial.ReserveAndAdditionalCapital.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.ReserveAndAdditionalCapital;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 84.
	Account = ChartsOfAccounts.Managerial.UndistributedProfit.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.UndistributedProfit;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();

	// 90.
	Account = ChartsOfAccounts.Managerial.Sales.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.AccountsGroup;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
		// 90.01
		Account = ChartsOfAccounts.Managerial.SalesRevenue.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.Sales;
		Account.TypeOfAccount = Enums.GLAccountsTypes.Incomings;
		Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
		Account.Write();
		
		// 90.02
		Account = ChartsOfAccounts.Managerial.CostOfGoodsSold.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.Sales;
		Account.TypeOfAccount = Enums.GLAccountsTypes.CostOfGoodsSold;
		Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
		Account.Write();
		
		// 90.07
		Account = ChartsOfAccounts.Managerial.CommercialExpenses.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.Sales;
		Account.TypeOfAccount = Enums.GLAccountsTypes.Expenses;
		Account.MethodOfDistribution = Enums.CostingBases.SalesVolume;
		Account.Write();
		
		// 90.08
		Account = ChartsOfAccounts.Managerial.AdministrativeExpenses.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.Sales;
		Account.TypeOfAccount = Enums.GLAccountsTypes.Expenses;
		Account.MethodOfDistribution = Enums.CostingBases.SalesVolume;
		Account.Write();
		
	// 91.
	Account = ChartsOfAccounts.Managerial.OtherIncomeAndExpenses.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.AccountsGroup;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
		// 91.01
		Account = ChartsOfAccounts.Managerial.OtherIncome.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.OtherIncomeAndExpenses;
		Account.TypeOfAccount = Enums.GLAccountsTypes.OtherIncome;
		Account.MethodOfDistribution = Enums.CostingBases.SalesVolume;
		Account.Write();
		
		// 91.02
		Account = ChartsOfAccounts.Managerial.OtherExpenses.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.OtherIncomeAndExpenses;
		Account.TypeOfAccount = Enums.GLAccountsTypes.OtherExpenses;
		Account.MethodOfDistribution = Enums.CostingBases.SalesVolume;
		Account.Write();
		
		// 91.03
		Account = ChartsOfAccounts.Managerial.CreditInterestRates.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.OtherIncomeAndExpenses;
		Account.TypeOfAccount = Enums.GLAccountsTypes.CreditInterestRates;
		Account.MethodOfDistribution = Enums.CostingBases.SalesVolume;
		Account.Write();
		
	// 94.
	Account = ChartsOfAccounts.Managerial.DeficiencyAndLossFromPropertySpoilage.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.OtherCurrentAssets;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 97.
	Account = ChartsOfAccounts.Managerial.CostsOfFuturePeriods.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.OtherCurrentAssets;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
	// 99.
	Account = ChartsOfAccounts.Managerial.ProfitsAndLosses.GetObject();
	Account.TypeOfAccount = Enums.GLAccountsTypes.AccountsGroup;
	Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
	Account.Write();
	
		// 99.01
		Account = ChartsOfAccounts.Managerial.ProfitsAndLossesWithoutProfitTax.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.ProfitsAndLosses;
		Account.TypeOfAccount = Enums.GLAccountsTypes.ProfitLosses;
		Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
		Account.Write();
		
		// 99.02
		Account = ChartsOfAccounts.Managerial.ProfitsAndLosses_ProfitTax.GetObject();
		Account.Parent = ChartsOfAccounts.Managerial.ProfitsAndLosses;
		Account.TypeOfAccount = Enums.GLAccountsTypes.ProfitTax;
		Account.MethodOfDistribution = Enums.CostingBases.DoNotDistribute;
		Account.Write();		
		
EndProcedure // ImportManagerialChartOfAccountsFirstLaunch()

//(3) Procedure fills in “Taxes kinds” catalog to IB.
//
Procedure FillTaxTypesFirstLaunch()

	// 1. VAT.
	TaxKind = Catalogs.TaxTypes.CreateItem();
	TaxKind.Description = "VAT";
	TaxKind.GLAccount = ChartsOfAccounts.Managerial.Taxes;
	TaxKind.GLAccountForReimbursement = ChartsOfAccounts.Managerial.TaxesToRefund;
	TaxKind.Write();

	// 2. Profit Tax.
	TaxKind = Catalogs.TaxTypes.CreateItem();
	TaxKind.Description = "Income tax";
	TaxKind.GLAccount = ChartsOfAccounts.Managerial.Taxes;
	TaxKind.GLAccountForReimbursement = ChartsOfAccounts.Managerial.TaxesToRefund;
	TaxKind.Write();

EndProcedure // FillTaxTypesFirstLaunch()

//(4) Function creates Currencies catalog item if there is no any.
//
// Parameters:
//  Code -                     - value of the
//  corresponding catalog item, Name              - value of the
//  corresponding attribute, DescriptionFull        - value of the
//  catalog corresponding attribute, SignatureParametersInRussian - value of the corresponding catalog attribute.
//
// Returns:
//  Ref to added or existing item.
//
Function FindCreateCurrency(Code, Description, DescriptionFull, WritingParametersInEnglish) Export

	Ref = Catalogs.Currencies.FindByCode(Code);

	If Ref.IsEmpty() Then

		CatalogObject = Catalogs.Currencies.CreateItem();

		CatalogObject.Code                       = Code;
		CatalogObject.Description              = Description;
		CatalogObject.DescriptionFull        = DescriptionFull;
		CatalogObject.WritingParametersInEnglish = WritingParametersInEnglish;

		WriteCatalogObject(CatalogObject);

		Ref = CatalogObject.Ref;
		
	ElsIf Ref.Predefined 
		AND IsBlankString(Ref.DescriptionFull) Then
		
		// It is the first call to the predefined item
		CatalogObject = Ref.GetObject();

		CatalogObject.Description              = Description;
		CatalogObject.DescriptionFull        = DescriptionFull;
		CatalogObject.WritingParametersInEnglish = WritingParametersInEnglish;

		WriteCatalogObject(CatalogObject);

		Ref = CatalogObject.Ref;

	EndIf;
	
	// set rate and frequency = 1 to January 1, 1980
	WorkWithCurrencyRates.CheckRateOn01Correctness_01_1980(Ref);
	
	Return Ref;

EndFunction // FindCreateCurrency()

//(5) The function fills in "VAT rates" IB
// catalog and returns a reference to 18% VAT rate for the future use.
//
Function FillVATRatesFirstLaunch()

	// 10%
	VATRate = Catalogs.VATRates.CreateItem();
	VATRate.Description = "10%";
	VATRate.Rate = 10;
	VATRate.Write();
	
	// 18% / 118%
	VATRate = Catalogs.VATRates.CreateItem();
	VATRate.Description = "18% / 118%";
	VATRate.Calculated = True;
	VATRate.Rate = 18;
	VATRate.Write();
	
	// 10% / 110%
	VATRate = Catalogs.VATRates.CreateItem();
	VATRate.Description = "10% / 110%";
	VATRate.Calculated = True;
	VATRate.Rate = 10;
	VATRate.Write();
	
	// 0%
	VATRate = Catalogs.VATRates.CreateItem();
	VATRate.Description = "0%";
	VATRate.Rate = 0;
	VATRate.Write();
	
	// Without VAT
	VATRate = Catalogs.VATRates.CreateItem();
	VATRate.Description = "Without VAT";
	VATRate.NotTaxable = True;
	VATRate.Rate = 0;
	VATRate.Write(); 
	
	// 18%
	VATRate = Catalogs.VATRates.CreateItem();
	VATRate.Description = "18%";
	VATRate.Rate = 18;	
	VATRate.Write();

	Return VATRate.Ref;

EndFunction // FillVATRatesFirstLaunch()

//(7) Procedure creates a work schedule based on the business calendar of the Russian Federation according to the "Five-day working week" template
// 
Procedure CreateRussianFederationFiveDaysCalendar() Export
	
	BusinessCalendar = CalendarSchedules.BusinessCalendarOfRussiaFederation();
	If BusinessCalendar = Undefined Then 
		Return;
	EndIf;
	
	If Not Catalogs.Calendars.FindByAttribute("BusinessCalendar", BusinessCalendar).IsEmpty() Then
		Return;
	EndIf;
	
	NewWorkSchedule = Catalogs.Calendars.CreateItem();
	NewWorkSchedule.Description = CommonUse.GetAttributeValue(BusinessCalendar, "Description");
	NewWorkSchedule.BusinessCalendar = BusinessCalendar;
	NewWorkSchedule.FillMethod = Enums.WorkScheduleFillingMethods.ByWeeks;
	NewWorkSchedule.StartDate = BegOfYear(CurrentSessionDate());
	NewWorkSchedule.ConsiderHolidays = True;
	
	// Fill in week cycle as five-day working week
	For DayNumber = 1 To 7 Do
		NewWorkSchedule.FillTemplate.Add().DayIncludedInSchedule = DayNumber <= 5;
	EndDo;
	
	InfobaseUpdate.WriteData(NewWorkSchedule, True, True);
	
EndProcedure // CreateRussianFederationFiveDaysCalendar()

//(13) Procedure fills in "Planning ObjectPeriod" catalog to IB.
//
Procedure FillPlanningPeriodFirstLaunch()

	Period = Catalogs.PlanningPeriods.Actual;
	ObjectPeriod = Period.GetObject();
	ObjectPeriod.Periodicity = Enums.Periodicity.Month;
	ObjectPeriod.Write();

EndProcedure // FillPlanningPeriodFirstLaunch()

//(14) Procedure fills in classifier of using the work time.
//
Procedure FillClassifierOfWorkingTimeUsage()

    // B.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.Disease;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Temporary incapacity to labor with benefit assignment according to the law";
    WorkingHoursKinds.Write();

    // V.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.WeekEnd;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Weekends (weekly leave) and public holidays";
    WorkingHoursKinds.Write();

    // VP.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.DowntimeByEmployeeFault;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Dead time by the employees fault";
    WorkingHoursKinds.Write();

	// VCH.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.WorkEveningClock;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Working hours in the evenings";
    WorkingHoursKinds.Write();

    // G.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.PublicResponsibilities;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Absenteeism at the time of state or public duties according to the law";
    WorkingHoursKinds.Write();

    // DB.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.UnpaidAdditionalVacation;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Annual additional leave without salary";
    WorkingHoursKinds.Write();

    // TO.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.UnpaidVacationByEmployerPermission;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Leave without pay provided to employee with employer permission";
    WorkingHoursKinds.Write();

    // ZB.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.Strike;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Strike (in conditions and order provided by legislation)";
    WorkingHoursKinds.Write();

    // TO.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.BusinessTrip;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Business trip";
    WorkingHoursKinds.Write();

    // N.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.WorkNightHours;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Working hours at night time";
    WorkingHoursKinds.Write();

    // NB.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.RemovalFromWorkWithoutPayments;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Suspension from work (disqualification) as required by the Law, without payroll";
    WorkingHoursKinds.Write();

    // NV.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.AdditionalWeekEndDaysNotPaid;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Additional days off (without salary)";
    WorkingHoursKinds.Write();

    // NZ.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.SalaryPayoffDelay;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Suspension of work in case of delayed salary";
    WorkingHoursKinds.Write();

    // NN.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.NotAppearsByUnknownReasons;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Unjustified absence from work (until the circumstances are clarified)";
    WorkingHoursKinds.Write();

    // NO.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.RemovalFromJobsWithPayment;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Suspension from work (disqualification) with payment (benefit) according to the law";
    WorkingHoursKinds.Write();

    // NP.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.Simple;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Downtime due to reasons regardless of the employer and the employee";
    WorkingHoursKinds.Write();

    // OV.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.AdditionalWeekEndDaysPaid;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Additional days-off (paid)";
    WorkingHoursKinds.Write();

    // OD.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.AdditionalVacation;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Annual additional paid leave";
    WorkingHoursKinds.Write();

    // OZH.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.VacationByCareForBaby;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Maternity leave up to the age of three";
    WorkingHoursKinds.Write();

    // OZ.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.UnpaidVacationByLegislation;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Leave without pay in cases provided by law";
    WorkingHoursKinds.Write();

    // OT.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.MainVacation;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Annual paid leave";
    WorkingHoursKinds.Write();

    // PV.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.ForcedTruancy;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Time of the forced absenteeism in case of the dismissal recognition, transition to another work place or dismissal from work with reemployment on the former one";
    WorkingHoursKinds.Write();

    // PK.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.QualificationRaise;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "On-the-job further training";
    WorkingHoursKinds.Write();

    // PM.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.QualificationRaiseInAnotherTerrain;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Further training off-the-job in other area";
    WorkingHoursKinds.Write();

    // PR.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.Truancies;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Absenteeism (absence from work place without valid reasons within the time fixed by the law)";
    WorkingHoursKinds.Write();

    // R.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.VacationByPregnancyAndChildbirth;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Maternity leave (vacation because of newborn baby adoption)";
    WorkingHoursKinds.Write();

    // RV.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.Holidays;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Working hours at weekends and non-work days, holidays";
    WorkingHoursKinds.Write();

    // RP.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.DowntimeByEmployerFault;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Dead time by employers fault";
	WorkingHoursKinds.Write();

    // C.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.Overtime;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Overtime duration";
    WorkingHoursKinds.Write();

    // T.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.DiseaseWithoutPay;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Temporary incapacity to labor without benefit assignment in cases provided by the law";
	WorkingHoursKinds.Write();

    // Y.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.VacationForTraining;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Additional leave due to training with an average pay, combining work and training";
	WorkingHoursKinds.Write();

	// YD.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.VacationForTrainingUnpaid;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Additional leave because of the training without salary";
	WorkingHoursKinds.Write();

	// I.
	WorkingHoursKindsReference = Catalogs.WorkingHoursKinds.Work;
    WorkingHoursKinds = WorkingHoursKindsReference.GetObject();
    WorkingHoursKinds.FullDescr = "Working hours in the daytime";
	WorkingHoursKinds.Write();

EndProcedure // FillWorkingTimeUsageClassifier()

//(15) Procedure fills in "Calculation parameters" and "Accruals and deductions kinds" catalogs.
//
Procedure FillCalculationParametersAndAccrualKinds()
	
	// Calculation parameters.
	
	// Sales amount by responsible (SAR)
	If Not SmallBusinessServer.SettlementsParameterExist("SalesAmountForResponsible") Then
		
		SARCalculationsParameters = Catalogs.CalculationsParameters.CreateItem();
		
		SARCalculationsParameters.Description 		 = "Sales amount by responsible";
		SARCalculationsParameters.ID 	 = "SalesAmountForResponsible"; 
		SARCalculationsParameters.CustomQuery = True;
		SARCalculationsParameters.SpecifyValueAtPayrollCalculation = False;
		
		NewQueryParameter 						 = SARCalculationsParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "AccountingCurrencyExchangeRate";
		NewQueryParameter.Presentation 			 = "AccountingCurrencyExchangeRate";
		
		NewQueryParameter 						 = SARCalculationsParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "DocumentCurrencyMultiplicity";
		NewQueryParameter.Presentation 			 = "DocumentCurrencyMultiplicity";
		
		NewQueryParameter 						 = SARCalculationsParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "DocumentCurrencyRate";
		NewQueryParameter.Presentation 			 = "DocumentCurrencyRate";
		
		NewQueryParameter 						 = SARCalculationsParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "AccountingCurrecyFrequency";
		NewQueryParameter.Presentation 			 = "AccountingCurrecyFrequency";
		
		NewQueryParameter 						 = SARCalculationsParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "RegistrationPeriod";
		NewQueryParameter.Presentation 			 = "RegistrationPeriod";
		
		NewQueryParameter 						 = SARCalculationsParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "Company";
		NewQueryParameter.Presentation 			 = "Company";
		
		NewQueryParameter 						 = SARCalculationsParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "Division";
		NewQueryParameter.Presentation 			 = "Division";
		
		NewQueryParameter 						 = SARCalculationsParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "Employee";
		NewQueryParameter.Presentation 			 = "Employee";
		
		
		SARCalculationsParameters.Query 			 = 
		"SELECT ALLOWED
		|	SUM(ISNULL(Sales.Amount * &AccountingCurrencyExchangeRate * &DocumentCurrencyMultiplicity / (&DocumentCurrencyRate * &AccountingCurrecyFrequency), 0)) AS SalesAmount
		|FROM
		|	AccumulationRegister.Sales AS Sales
		|WHERE
		|	Sales.Amount >= 0
		|	AND Sales.Period between BEGINOFPERIOD(&RegistrationPeriod, MONTH) AND ENDOFPERIOD(&RegistrationPeriod, MONTH)
		|	AND Sales.Company = &Company
		|	AND Sales.Division = &Division
		|	AND Sales.Document.Responsible = &Employee
		|	AND (CAST(Sales.Recorder AS Document.AcceptanceCertificate) REFS Document.AcceptanceCertificate
		|			OR CAST(Sales.Recorder AS Document.CustomerOrder) REFS Document.CustomerOrder
		|			OR CAST(Sales.Recorder AS Document.ProcessingReport) REFS Document.ProcessingReport
		|			OR CAST(Sales.Recorder AS Document.RetailReport) REFS Document.RetailReport
		|			OR CAST(Sales.Recorder AS Document.CustomerInvoice) REFS Document.CustomerInvoice
		|			OR CAST(Sales.Recorder AS Document.ReceiptCR) REFS Document.ReceiptCR)
		|
		|GROUP BY
		|	Sales.Document.Responsible";
		
		SARCalculationsParameters.Write();
		
	EndIf;
	
	// Fixed amount
	If Not SmallBusinessServer.SettlementsParameterExist("FixedAmount") Then
		
		ParameterCalculationsFixedAmount = Catalogs.CalculationsParameters.CreateItem();
		ParameterCalculationsFixedAmount.Description 				= "Fixed amount";
		ParameterCalculationsFixedAmount.ID 	 			= "FixedAmount";
		ParameterCalculationsFixedAmount.CustomQuery 			= False;
		ParameterCalculationsFixedAmount.SpecifyValueAtPayrollCalculation = True;
		ParameterCalculationsFixedAmount.Write();
		
	EndIf;
	
	// Norm of days
	If Not SmallBusinessServer.SettlementsParameterExist("NormDays") Then
		
		SettlementsParameterNormDays = Catalogs.CalculationsParameters.CreateItem();
		SettlementsParameterNormDays.Description 		 = "Norm of days";
		SettlementsParameterNormDays.ID 	 = "NormDays";
		SettlementsParameterNormDays.CustomQuery = True;
		SettlementsParameterNormDays.SpecifyValueAtPayrollCalculation = False;
		NewQueryParameter 						 = SettlementsParameterNormDays.QueryParameters.Add();
		NewQueryParameter.Name 					 = "Company";
		NewQueryParameter.Presentation 			 = "Company";
		NewQueryParameter 						 = SettlementsParameterNormDays.QueryParameters.Add();
		NewQueryParameter.Name 					 = "RegistrationPeriod";
		NewQueryParameter.Presentation 			 = "Registration period";
		SettlementsParameterNormDays.Query 			 = 
		"SELECT
		|	SUM(1) AS NormDays
		|FROM
		|	InformationRegister.CalendarSchedules AS CalendarSchedules
		|		INNER JOIN Catalog.Companies AS Companies
		|		ON CalendarSchedules.Calendar = Companies.BusinessCalendar
		|			AND (Companies.Ref = &Company)
		|WHERE
		|	CalendarSchedules.Year = YEAR(&RegistrationPeriod)
		|	AND CalendarSchedules.ScheduleDate between BEGINOFPERIOD(&RegistrationPeriod, MONTH) AND ENDOFPERIOD(&RegistrationPeriod, MONTH)
		|	AND CalendarSchedules.DayIncludedInSchedule";
		
		SettlementsParameterNormDays.Write();
		
	EndIf;
	
	// Norm of hours
	If Not SmallBusinessServer.SettlementsParameterExist("NormHours") Then
		
		ParameterCalculationsNormHours = Catalogs.CalculationsParameters.CreateItem();
		ParameterCalculationsNormHours.Description 	  = "Norm of hours";
		ParameterCalculationsNormHours.ID 	  = "NormHours";
		ParameterCalculationsNormHours.CustomQuery = True;
		ParameterCalculationsNormHours.SpecifyValueAtPayrollCalculation = False;
		NewQueryParameter 						 = ParameterCalculationsNormHours.QueryParameters.Add();
		NewQueryParameter.Name 					 = "Company";
		NewQueryParameter.Presentation 			 = "Company";
		NewQueryParameter 						 = ParameterCalculationsNormHours.QueryParameters.Add();
		NewQueryParameter.Name 					 = "RegistrationPeriod";
		NewQueryParameter.Presentation 			 = "Registration period";
		ParameterCalculationsNormHours.Query 			 = 
		"SELECT
		|	SUM(8) AS NormHours
		|FROM
		|	InformationRegister.CalendarSchedules AS CalendarSchedules
		|		INNER JOIN Catalog.Companies AS Companies
		|		ON CalendarSchedules.Calendar = Companies.BusinessCalendar
		|			AND (Companies.Ref = &Company)
		|WHERE
		|	CalendarSchedules.Year = YEAR(&RegistrationPeriod)
		|	AND CalendarSchedules.ScheduleDate between BEGINOFPERIOD(&RegistrationPeriod, MONTH) AND ENDOFPERIOD(&RegistrationPeriod, MONTH)
		|	AND CalendarSchedules.DayIncludedInSchedule";
		ParameterCalculationsNormHours.Write();
		
	EndIf;
	
	// Days worked
	If Not SmallBusinessServer.SettlementsParameterExist("DaysWorked") Then
		
		ParameterCalculationsDaysWorked = Catalogs.CalculationsParameters.CreateItem();
		ParameterCalculationsDaysWorked.Description 	  = "Days worked";
		ParameterCalculationsDaysWorked.ID	  = "DaysWorked";
		ParameterCalculationsDaysWorked.CustomQuery = False;
		ParameterCalculationsDaysWorked.SpecifyValueAtPayrollCalculation = True;
		ParameterCalculationsDaysWorked.Write();
		
	EndIf;
	
	// Hours worked
	If Not SmallBusinessServer.SettlementsParameterExist("HoursWorked") Then
		
		ParameterCalculationsHoursWorked = Catalogs.CalculationsParameters.CreateItem();
		ParameterCalculationsHoursWorked.Description 	   = "Hours worked";
		ParameterCalculationsHoursWorked.ID 	   = "HoursWorked";
		ParameterCalculationsHoursWorked.CustomQuery = False;
		ParameterCalculationsHoursWorked.SpecifyValueAtPayrollCalculation = True;
		ParameterCalculationsHoursWorked.Write();
		
	EndIf;
	
	// Tariff rate
	If Not SmallBusinessServer.SettlementsParameterExist("TariffRate") Then
		
		CalculationsParameterTariffRate = Catalogs.CalculationsParameters.CreateItem();
		CalculationsParameterTariffRate.Description 	  = "Tariff rate";
		CalculationsParameterTariffRate.ID 	  = "TariffRate";
		CalculationsParameterTariffRate.CustomQuery = False;
		CalculationsParameterTariffRate.SpecifyValueAtPayrollCalculation = True;
		CalculationsParameterTariffRate.Write();
		
	EndIf;
	
	// Worked by jobs
	If Not SmallBusinessServer.SettlementsParameterExist("HoursWorkedByJobs") Then
		
		ParameterCalculationsPieceDevelopment = Catalogs.CalculationsParameters.CreateItem();
		ParameterCalculationsPieceDevelopment.Description 	= "Hours worked by jobs";
		ParameterCalculationsPieceDevelopment.ID = "HoursWorkedByJobs";
		ParameterCalculationsPieceDevelopment.CustomQuery = True;
		ParameterCalculationsPieceDevelopment.SpecifyValueAtPayrollCalculation = False;
		
		NewQueryParameter = ParameterCalculationsPieceDevelopment.QueryParameters.Add();
		NewQueryParameter.Name = "BeginOfPeriod"; 
		NewQueryParameter.Presentation = "Begin of period"; 
		
		NewQueryParameter = ParameterCalculationsPieceDevelopment.QueryParameters.Add();
		NewQueryParameter.Name = "EndOfPeriod";
		NewQueryParameter.Presentation = "End of period";
		
		NewQueryParameter = ParameterCalculationsPieceDevelopment.QueryParameters.Add();
		NewQueryParameter.Name = "Employee";
		NewQueryParameter.Presentation = "Employee";
		
		NewQueryParameter = ParameterCalculationsPieceDevelopment.QueryParameters.Add();
		NewQueryParameter.Name = "Company"; 
		NewQueryParameter.Presentation = "Company"; 
		
		NewQueryParameter = ParameterCalculationsPieceDevelopment.QueryParameters.Add();
		NewQueryParameter.Name = "Division";
		NewQueryParameter.Presentation = "Division";

		ParameterCalculationsPieceDevelopment.Query =
		"SELECT
		|	Source.ImportActualTurnover
		|FROM
		|	AccumulationRegister.WorkOrders.Turnovers(&BeginOfPeriod, &EndOfPeriod, Auto, ) AS Source
		|WHERE
		|	Source.Employee = &Employee
		|	AND Source.StructuralUnit = &Division
		|	AND Source.Company = &Company";
		
		ParameterCalculationsPieceDevelopment.Write();
		
	EndIf;

	// Accruals kinds
	If Not SmallBusinessServer.AccrualAndDeductionKindsInitialFillingPerformed() Then
		
		// Groups
		NewAccrual 			 = Catalogs.AccrualAndDeductionKinds.CreateFolder();
		NewAccrual.Description = "accrual";
		NewAccrual.Write(); 

		GroupAccrual 			 = NewAccrual.Ref;

		NewAccrual 			 = Catalogs.AccrualAndDeductionKinds.CreateFolder();
		NewAccrual.Description = "Deductions";
		NewAccrual.Write();

		// Salary by days
		NewAccrual 					= Catalogs.AccrualAndDeductionKinds.CreateItem();
		NewAccrual.Parent 			= GroupAccrual;
		NewAccrual.Description 		= "Salary by days";
		NewAccrual.Type 				= Enums.AccrualAndDeductionTypes.Accrual;
		NewAccrual.GLExpenseAccount			= ChartsOfAccounts.Managerial.AdministrativeExpenses;
		NewAccrual.Formula				= "[TariffRate] * [DaysWorked] / [NormDays]";
		NewAccrual.Write();
		
		// Salary by hours
		NewAccrual 					= Catalogs.AccrualAndDeductionKinds.CreateItem();
		NewAccrual.Parent 			= GroupAccrual;
		NewAccrual.Description 		= "Salary by hours";
		NewAccrual.Type 				= Enums.AccrualAndDeductionTypes.Accrual;
		NewAccrual.GLExpenseAccount			= ChartsOfAccounts.Managerial.IndirectExpenses;
		NewAccrual.Formula 			= "[TariffRate] * [HoursWorked] / [NormHours]";
		NewAccrual.Write();

		// Payment by jobs
		NewAccrual 					= Catalogs.AccrualAndDeductionKinds.CreateItem();
		NewAccrual.Parent 			= GroupAccrual;
		NewAccrual.Description 		= "Payment by jobs";
		NewAccrual.Type 				= Enums.AccrualAndDeductionTypes.Accrual;
		NewAccrual.GLExpenseAccount			= ChartsOfAccounts.Managerial.UnfinishedProduction;
		NewAccrual.Formula 			= "[TariffRate] * [HoursProcessedByJobs]";
		NewAccrual.Write();
		
		// Sales fee by responsible
		NewAccrual 					= Catalogs.AccrualAndDeductionKinds.CreateItem();
		NewAccrual.Parent 			= GroupAccrual;
		NewAccrual.Description 		= "Sales fee by responsible";
		NewAccrual.Type 				= Enums.AccrualAndDeductionTypes.Accrual;
		NewAccrual.GLExpenseAccount			= ChartsOfAccounts.Managerial.UnfinishedProduction;
		NewAccrual.Formula 			= "[SalesAmountByResponsible]  /  100 * [TariffRate]";
		NewAccrual.Write();
		
		// Payment by job sheets
		NewAccrualReference				= Catalogs.AccrualAndDeductionKinds.PieceRatePayment;
		NewAccrual						= NewAccrualReference.GetObject();
		NewAccrual.Parent 			= GroupAccrual;
		NewAccrual.Description 		= "Accord payment (tariff)";
		NewAccrual.Type 				= Enums.AccrualAndDeductionTypes.Accrual;
		NewAccrual.GLExpenseAccount			= ChartsOfAccounts.Managerial.UnfinishedProduction;
		NewAccrual.Formula 			= "";
		NewAccrual.Write();
		
		// Accord payment in percent
		NewAccrualReference				= Catalogs.AccrualAndDeductionKinds.PieceRatePaymentPercent;
		NewAccrual						= NewAccrualReference.GetObject();
		NewAccrual.Parent 			= GroupAccrual;
		NewAccrual.Description 		= "Accord payment (% from amount)";
		NewAccrual.Type 				= Enums.AccrualAndDeductionTypes.Accrual;
		NewAccrual.GLExpenseAccount			= ChartsOfAccounts.Managerial.UnfinishedProduction;
		NewAccrual.Formula 			= "";
		NewAccrual.Write();
		
		//Fixed amount
		NewAccrualReference				= Catalogs.AccrualAndDeductionKinds.FixedAmount;
		NewAccrual						= NewAccrualReference.GetObject();
		NewAccrual.Code					= "";
		NewAccrual.Parent 			= GroupAccrual;
		NewAccrual.Description 		= "Accord payment (fixed amount)";
		NewAccrual.Type 				= Enums.AccrualAndDeductionTypes.Accrual;
		NewAccrual.GLExpenseAccount			= ChartsOfAccounts.Managerial.UnfinishedProduction;
		NewAccrual.Formula 			= "[FixedAmount]";
		NewAccrual.SetNewCode();
		NewAccrual.Write();
		
	EndIf;
	
EndProcedure // FillCalculationAndAccrualKindsParameters()

//(24) Procedure fills in the selection settings on the first start
//
Procedure FillFilterUserSettings()
	
	CurrentUser = Users.CurrentUser();
	
	SmallBusinessServer.SetStandardFilterSettings(CurrentUser);
	
EndProcedure // FillCustomSelectionSettings()

//(25) Procedure updates/fills in the predefined CI kinds.
// 
// For catalogs:
// - Counterparty
// - Ind. person
// - Contact persons
// 
// "Companies" catalog is updated/filled in with SSL mechanism.
//
Procedure RefreshPredefinedKindsOfContact()
	
	// Update CI kinds
	SmallBusinessServer.RefreshPredefinedKindsOfContractualPartnerContactInformation();
	SmallBusinessServer.RefreshPredefinedKindsOfContactInformationOfIndividual();
	SmallBusinessServer.RefreshPredefinedKindsOfContactInformationContactPerson();
	SmallBusinessServer.UpdatePredefinedStructuralUnitsContactInformationTypes();
	
	EnableMultipleContactInformationSSLInput();
	
EndProcedure

//(27) Procedure removes the registration of the basic qualifiers
// changes that must be exported only if they are assigned with references to them in other exported object.
//
Procedure DeleteChangeRegistrationOfBaseClassifiers()

	Query = New Query;
	Query.Text =
	"SELECT
	|	ExchangeSmallBusinessAccounting20.Ref AS ExchangeNode
	|FROM
	|	ExchangePlan.ExchangeSmallBusinessAccounting20 AS ExchangeSmallBusinessAccounting20
	|WHERE
	|	ExchangeSmallBusinessAccounting20.Ref <> &ThisNodeBP20
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangeSmallBusinessAccounting30.Ref AS ExchangeNode
	|FROM
	|	ExchangePlan.ExchangeSmallBusinessAccounting30 AS ExchangeSmallBusinessAccounting30
	|WHERE
	|	ExchangeSmallBusinessAccounting30.Ref <> &ThisNodeBP30";
	
	Query.SetParameter("ThisNodeBP20", ExchangePlans.ExchangeSmallBusinessAccounting20.ThisNode());
	Query.SetParameter("ThisNodeBP30", ExchangePlans.ExchangeSmallBusinessAccounting30.ThisNode());
	
	ResultsArray = Query.ExecuteBatch();
	NodesExchangeSBP20 = ResultsArray[0].Unload().UnloadColumn("ExchangeNode");
	NodesExchangeWithBP30 = ResultsArray[1].Unload().UnloadColumn("ExchangeNode");
	
	Try
		ExchangePlans.DeleteChangeRecords(NodesExchangeSBP20, Metadata.Catalogs.Banks);
		ExchangePlans.DeleteChangeRecords(NodesExchangeSBP20, Metadata.Catalogs.Currencies);
		ExchangePlans.DeleteChangeRecords(NodesExchangeSBP20, Metadata.Catalogs.UOMClassifier);
		ExchangePlans.DeleteChangeRecords(NodesExchangeSBP20, Metadata.Catalogs.WorldCountries);
	Except
	EndTry;
	
	Try
		ExchangePlans.DeleteChangeRecords(NodesExchangeWithBP30, Metadata.Catalogs.Banks);
		ExchangePlans.DeleteChangeRecords(NodesExchangeWithBP30, Metadata.Catalogs.Currencies);
		ExchangePlans.DeleteChangeRecords(NodesExchangeWithBP30, Metadata.Catalogs.UOMClassifier);
		ExchangePlans.DeleteChangeRecords(NodesExchangeWithBP30, Metadata.Catalogs.WorldCountries);
	Except
	EndTry;

EndProcedure // DeleteBasicClassifiersChangeRegistration()

//(29) procedure fills in contracts forms from layout.
//
Procedure FillContractsForms()
	
	LeaseAgreementTemplate 			= Catalogs.ContractForms.GetTemplate("LeaseAgreementTemplate");
	PurchaseAndSaleContractTemplate 	= Catalogs.ContractForms.GetTemplate("PurchaseAndSaleContractTemplate");
	ServicesContractTemplate 	= Catalogs.ContractForms.GetTemplate("ServicesContractTemplate");
	SupplyContractTemplate 		= Catalogs.ContractForms.GetTemplate("SupplyContractTemplate");
	
	Templates = New Array(4);
	Templates[0] = LeaseAgreementTemplate;
	Templates[1] = PurchaseAndSaleContractTemplate;
	Templates[2] = ServicesContractTemplate;
	Templates[3] = SupplyContractTemplate;
	
	LayoutNames = New Array(4);
	LayoutNames[0] = "LeaseAgreementTemplate";
	LayoutNames[1] = "PurchaseAndSaleContractTemplate";
	LayoutNames[2] = "ServicesContractTemplate";
	LayoutNames[3] = "SupplyContractTemplate";
	
	Forms = New Array(4);
	Forms[0] = Catalogs.ContractForms.LeaseAgreement.Ref.GetObject();
	Forms[1] = Catalogs.ContractForms.PurchaseAndSaleContract.Ref.GetObject();
	Forms[2] = Catalogs.ContractForms.ServicesContract.Ref.GetObject();
	Forms[3] = Catalogs.ContractForms.SupplyContract.Ref.GetObject();
	
	Iterator = 0;
	While Iterator < Templates.Count() Do 
		
		ContractTemplate = Catalogs.ContractForms.GetTemplate(LayoutNames[Iterator]);
		
		TextHTML = ContractTemplate.GetText();
		Attachments = New Structure;
		
		EditableParametersNumber = StrOccurrenceCount(TextHTML, "{FilledField");
		
		Forms[Iterator].EditableParameters.Clear();
		ParameterNumber = 1;
		While ParameterNumber <= EditableParametersNumber Do 
			NewRow = Forms[Iterator].EditableParameters.Add();
			NewRow.Presentation = "{FilledField" + ParameterNumber + "}";
			NewRow.ID = "parameter" + ParameterNumber;
			
			ParameterNumber = ParameterNumber + 1;
		EndDo;
		
		FormattedDocumentStructure = New Structure;
		FormattedDocumentStructure.Insert("HTMLText", TextHTML);
		FormattedDocumentStructure.Insert("Attachments", Attachments);
		
		Forms[Iterator].Form = New ValueStorage(FormattedDocumentStructure);
		Forms[Iterator].PredefinedFormTemplate = LayoutNames[Iterator];
		Forms[Iterator].EditableParametersNumber = EditableParametersNumber;
		Forms[Iterator].Write();
		
		Iterator = Iterator + 1;
		
	EndDo;
	
EndProcedure

// Procedure fills in the passed object catalog and outputs message.
// It is intended to invoke from procedures of filling and processing the infobase directories.
//
// Parameters:
//  CatalogObject - an object that required record.
//
Procedure WriteCatalogObject(CatalogObject, Inform = False) Export

	If Not CatalogObject.Modified() Then
		Return;
	EndIf;

	If CatalogObject.IsNew() Then
		If CatalogObject.IsFolder Then
			MessageStr = NStr("en = 'Created catalog group ""%1"", code: ""%2"", description: ""%3""'") ;
		Else
			MessageStr = NStr("en = 'Created catalog element ""%1"", code: ""%2"", description: ""%3""'") ;
		EndIf; 
	Else
		If CatalogObject.IsFolder Then
			MessageStr = NStr("en = 'Processed catalog group ""%1"", code: ""%2"", description: ""%3""'") ;
		Else
			MessageStr = NStr("en = 'Processed catalog element ""%1"", code: ""%2"", description: ""%3""'") ;
		EndIf; 
	EndIf;

	If CatalogObject.Metadata().CodeLength > 0 Then
		FullCode = CatalogObject.FullCode();
	Else
		FullCode = NStr("en = '<without code>'");
	EndIf; 
	MessageStr = StringFunctionsClientServer.PlaceParametersIntoString(MessageStr, CatalogObject.Metadata().Synonym, FullCode, CatalogObject.Description);

	Try
		CatalogObject.Write();
		If Inform = True Then
			CommonUseClientServer.MessageToUser(MessageStr, CatalogObject);
		EndIf;

	Except

		MessageText = NStr("en='Failed to complete action: %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, MessageStr);

		CommonUseClientServer.MessageToUser(MessageText);

		ErrorDescription = ErrorInfo();
		WriteLogEvent(MessageText, EventLogLevel.Error,,, ErrorDescription.Definition);

	EndTry;

EndProcedure

// Procedure updates CI kinds and allows to enter multiple values for some CI kinds.
//
Procedure EnableMultipleContactInformationSSLInput()
	
	// Companies
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationTypes.CompanyPhone,			Enums.ContactInformationTypes.Phone,
		NStr("en='Company''s phone'"), True, False, False, 3, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationTypes.CompanyFax,				Enums.ContactInformationTypes.Fax,
		NStr("en='Company''s fax'"), True, False, False, 4, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationTypes.CompanyEmail,				Enums.ContactInformationTypes.EmailAddress,
		NStr("en='Counterparty email address'"), True, False, False, 5, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationTypes.CompanyOtherInformation,	Enums.ContactInformationTypes.Another,
		NStr("en='Any other contact information'"), True, False, False, 7, False);
	
EndProcedure // EnableMultipleContactInformationInput()

// End. Procedures supporting the first start

//Procedure checks whether TIN and KPP
//are entered correctly Takes
//the Pass parameters structure - structure
// Mandatory
//	structure
//	keys
//	TIN
//	KPP
//	IsLegalEntity NoTINErrors NoKPPErrors
//
//Returns a structure with variable set of keys only with the values corresponding to the check result.
Function CheckTINKPPCorrectness(Val ParametersStructure) Export
	
	ReturnStructure = New Structure;
	
	If ParametersStructure.CheckTIN Then
		
		ReturnStructure.Insert("TINEnteredCorrectly",               True);
		ReturnStructure.Insert("ExtendedTINPresentation",      ParametersStructure.TIN);
		ReturnStructure.Insert("LabelExplanationsOfIncorrectTIN", "");
		ReturnStructure.Insert("EmptyTIN",                        False);
		ReturnStructure.Insert("NoErrorsByTIN",                   ParametersStructure.CheckTIN);
		
		TIN      = TrimR(ParametersStructure.TIN);
		TINLength = StrLen(TIN);
	
		If Not ValueIsFilled(TIN) Then
			
			ReturnStructure.TINEnteredCorrectly = False;
			
			ReturnStructure.EmptyTIN = True;
			
			ReturnStructure.NoErrorsByTIN = False;
			
		EndIf;
		
		If ReturnStructure.NoErrorsByTIN Then
		
			If ParametersStructure.ThisIsLegalEntity = Undefined Then
				
				ReturnStructure.TINEnteredCorrectly = False;
				ReturnStructure.LabelExplanationsOfIncorrectTIN = NStr("en = 'Unknown counterparty kind. Specify counterparty kind'");
				
				ReturnStructure.NoErrorsByTIN = False;
				
			EndIf;
			
			If ReturnStructure.NoErrorsByTIN Then
				
				If ParametersStructure.ThisIsLegalEntity AND TINLength <> 10 Then
					
					ReturnStructure.TINEnteredCorrectly = False;
					
					ReturnStructure.LabelExplanationsOfIncorrectTIN = NStr("en = 'TIN of legal entity should consist of 10 digits'");
					
					TextForIncorrectTIN = NStr("en = '%
					|TIN does not contain 10 digits'");
					
					ReturnStructure.ExtendedTINPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectTIN, TIN);
					
					ReturnStructure.NoErrorsByTIN = False;
					
				ElsIf Not ParametersStructure.ThisIsLegalEntity AND TINLength <> 12 Then
					
					ReturnStructure.TINEnteredCorrectly = False;
					
					ReturnStructure.LabelExplanationsOfIncorrectTIN = NStr("en = 'Individual’s TIN should consist of 12 digits.'");
					
					TextForIncorrectTIN = NStr("en = '%
					|TIN does not contain 12 digits'");
					
					ReturnStructure.ExtendedTINPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectTIN, TIN);
					
					ReturnStructure.NoErrorsByTIN = False;
					
				EndIf;
				
				If ReturnStructure.NoErrorsByTIN Then
				
					If Not StringFunctionsClientServer.OnlyNumbersInString(TIN) Then
						
						ReturnStructure.TINEnteredCorrectly = False;
						
						ReturnStructure.LabelExplanationsOfIncorrectTIN = NStr("en = 'TIN should include only digits'");
						
						TextForIncorrectTIN = NStr("en = '%
						|TIN includes not only digits'");
						
						ReturnStructure.ExtendedTINPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectTIN, TIN);
						
						ReturnStructure.NoErrorsByTIN = False;
						
					EndIf;
					
					If ReturnStructure.NoErrorsByTIN Then
					
						If ParametersStructure.ThisIsLegalEntity Then
							
							CheckSum = 0;
							
							For N = 1 To 9 Do
								
								If N = 1 Then
									Factor = 2;
								ElsIf N = 2 Then
									Factor = 4;
								ElsIf N = 3 Then
									Factor = 10;
								ElsIf N = 4 Then
									Factor = 3;
								ElsIf N = 5 Then
									Factor = 5;
								ElsIf N = 6 Then
									Factor = 9;
								ElsIf N = 7 Then
									Factor = 4;
								ElsIf N = 8 Then
									Factor = 6;
								ElsIf N = 9 Then
									Factor = 8;
								EndIf;
								
								Digit = Number(Mid(TIN, N, 1));
								CheckSum = CheckSum + Digit * Factor;
								
							EndDo;
							
							CheckDigit = (CheckSum %11) %10;
							
							If CheckDigit <> Number(Mid(TIN, 10, 1)) or CheckSum = 0 Then
								
								ReturnStructure.TINEnteredCorrectly = False;
								
								ReturnStructure.LabelExplanationsOfIncorrectTIN = NStr("en = 'Legal entity''s TIN is incorrect'");
								
								TextForIncorrectTIN = NStr("en = '%1
								|TIN does not correspond to the format'");
								
								ReturnStructure.ExtendedTINPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectTIN, TIN);
								
								ReturnStructure.NoErrorsByTIN = False;
								
							EndIf;
							
						Else
							
							CheckSum11 = 0;
							CheckSum12 = 0;
							
							For N=1 To 11 Do
								
								// Calculation of multipliers for 11th and 12th digits
								If N = 1 Then
									Factor11 = 7;
									Factor12 = 3;
								ElsIf N = 2 Then
									Factor11 = 2;
									Factor12 = 7;
								ElsIf N = 3 Then
									Factor11 = 4;
									Factor12 = 2;
								ElsIf N = 4 Then
									Factor11 = 10;
									Factor12 = 4;
								ElsIf N = 5 Then
									Factor11 = 3;
									Factor12 = 10;
								ElsIf N = 6 Then
									Factor11 = 5;
									Factor12 = 3;
								ElsIf N = 7 Then
									Factor11 = 9;
									Factor12 = 5;
								ElsIf N = 8 Then
									Factor11 = 4;
									Factor12 = 9;
								ElsIf N = 9 Then
									Factor11 = 6;
									Factor12 = 4;
								ElsIf N = 10 Then
									Factor11 = 8;
									Factor12 = 6;
								ElsIf N = 11 Then
									Factor11 = 0;
									Factor12 = 8;
								EndIf;
								
								Digit = Number(Mid(TIN, N, 1));
								CheckSum11 = CheckSum11 + Digit * Factor11;
								CheckSum12 = CheckSum12 + Digit * Factor12;
								
							EndDo;
							
							CheckDigit11 = (CheckSum11 %11) %10;
							CheckDigit12 = (CheckSum12 %11) %10;
							
							If CheckDigit11 <> Number(Mid(TIN,11,1)) OR CheckDigit12 <> Number(Mid(TIN,12,1)) or (CheckSum11 = 0 and CheckSum12 = 0) Then
								
								ReturnStructure.TINEnteredCorrectly = False;
								
								ReturnStructure.LabelExplanationsOfIncorrectTIN = NStr("en = 'Individual''s TIN is incorrect'");
								
								TextForIncorrectTIN = NStr("en = '%1
								|TIN does not correspond to the format'");
								
								ReturnStructure.ExtendedTINPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectTIN, TIN);
								
								ReturnStructure.NoErrorsByTIN = False;
								
							EndIf;
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;	
		
	EndIf;
	
	If ParametersStructure.CheckKPP Then
		
		ReturnStructure.Insert("KPPEnteredCorrectly",               True);
		ReturnStructure.Insert("ExtendedKPPPresentation",      ParametersStructure.KPP);
		ReturnStructure.Insert("LabelExplanationsOfIncorrectKPP", "");
		ReturnStructure.Insert("EmptyKPP",                        False);
		ReturnStructure.Insert("NoErrorsByKPP",                   ParametersStructure.CheckKPP);
		
		If ParametersStructure.ThisIsLegalEntity = Undefined Then
			
			ReturnStructure.KPPEnteredCorrectly = False;
			
			ReturnStructure.LabelExplanationsOfIncorrectKPP = NStr("en = 'Unknown counterparty kind. Specify counterparty kind'");
			
			ReturnStructure.NoErrorsByKPP = False;
			
		ElsIf Not ParametersStructure.ThisIsLegalEntity Then
			ReturnStructure.NoErrorsByKPP = False;
		EndIf;
		
		If ReturnStructure.NoErrorsByKPP Then
		
			KPP = TrimR(ParametersStructure.KPP);
			KPPLength = StrLen(KPP);
			
			If Not ValueIsFilled(KPP) Then
				
				ReturnStructure.KPPEnteredCorrectly = False;
				
				ReturnStructure.EmptyKPP = True;
				
				ReturnStructure.NoErrorsByKPP = False;
				
			EndIf;
			
			If ReturnStructure.NoErrorsByKPP Then
			
				If KPPLength <> 9 Then
					
					ReturnStructure.KPPEnteredCorrectly = False;
					
					ReturnStructure.LabelExplanationsOfIncorrectKPP  = NStr("en = 'KPP should contain 9 digits'");
					
					TextForIncorrectKPP = NStr("en = '&1
					|KPP does not contain 9 digits'");
					
					ReturnStructure.ExtendedKPPPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectKPP, KPP);
					
					ReturnStructure.NoErrorsByKPP = False;
					
				EndIf;
				
				If ReturnStructure.NoErrorsByKPP Then
				
					If Not StringFunctionsClientServer.OnlyNumbersInString(KPP) Then
						
						ReturnStructure.KPPEnteredCorrectly = False;
						
						ReturnStructure.LabelExplanationsOfIncorrectKPP = NStr("en = 'KPP should include only digits'");
						
						TextForIncorrectKPP = NStr("en = '%
						|KPP includes not only digits'");
						
						ReturnStructure.ExtendedKPPPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectKPP, KPP);
						
						ReturnStructure.NoErrorsByKPP = False;
						
					EndIf;
					
					If ReturnStructure.NoErrorsByKPP Then
					
						ControlPart = Mid(KPP, 5, 2);
						
						SeparateDivisionFlag = ControlPart = "02"
						//Registration with the taxpayer - a Russian company at the location of its separate division depending on the division type 
							or ControlPart = "03" //Registration with the taxpayer - a Russian company at the location of its branch that does not act as taxes and receipts payment organization 
							or ControlPart = "04" //Registration with the taxpayer - a Russian company at the location of its separate division depending on the division type 
							or ControlPart = "05" //Registration with the taxpayer - a Russian company at the location of its separate division depending on the division type
							or ControlPart = "30" //Russian company - the tax agent not considered as a taxpayer
							or ControlPart = "31" //Registration with the taxpayer - a Russian company at the location of a separate subdivision in respect of which no registration procedure is not executed under paragraph 3 of Article 55 of the Russian Federation Civil Code that acts as taxes and receipts payment organization 
							or ControlPart = "32" //Registration with the taxpayer - a Russian company at the location of a separate subdivision in respect of which no registration procedure is executed under paragraph 3 of Article 55 of the Russian Federation Civil Code that does not act as taxes and receipts payment organization 
							or ControlPart = "43" //Registration with the Russian company at the location of its branch (similar to the old codes "02", "03" - Ministry of Finance Notification dated 6/2/2008 No. BH-6-6/396@ "Concerning the application of "SPPUNO" directory code) 
							or ControlPart = "44" //Registration with the Russian company at the location of its representative office (similar to the old codes "04", "05" - Ministry of Finance Notification dated 6/2/2008 No. BH-6-6/396@ "Concerning the application of "SPPUNO" directory code) 
							or ControlPart = "45";//Registration with the Russian company at the location of its separate division (similar to the old codes "31", "32" - Ministry of Finance Notification dated 6/2/2008 No. BH-6-6/396@ "Concerning the application of "SPPUNO" directory code)
							
						MainDivisionFlag = ControlPart = "01" 
							or ControlPart = "50" //At the place of registration as the largest taxpayer
							or ControlPart = "51" //Registration with foreign companies’ branches 
							or ControlPart = "52" //Registration with foreign companies divisions in the Russian Federation established by the foreign organization branch in a foreign country 
							or ControlPart = "60" //Registration with foreign embassies
							or ControlPart = "61" //Registration with the foreign countries consulates
							or ControlPart = "62" //Registration with the representative office similar to diplomatic
							or ControlPart = "63" //Registration with the international companies
							or ControlPart = "70" //Registration with foreign and international companies that own real estate in the Russian Federation, except for vehicles belonging to the real estate
							or ControlPart = "71" //Registration with foreign and international companies with vehicles in the Russian Federation not related to the real estate
							or ControlPart = "72" //Registration with foreign and international companies with marine transport in the Russian Federation
							or ControlPart = "73" //Registration with foreign and international companies with river transport in the Russian Federation
							or ControlPart = "74" //Registration with foreign and international companies with aerial vehicles in the Russian Federation
							or ControlPart = "75" //Registration with foreign and international companies with space crafts in the Russian Federation
							or ControlPart = "80" //Registration of foreign and international companies as rouble accounts of the "C" (current) types are opened in banks
							or ControlPart = "81" //Registration of foreign and international companies as accounts of the "I" (investment) types are opened in banks
							or ControlPart = "82" //registration of foreign and international companies as accounts of the "S" (special) types are opened in banks
							or ControlPart = "83" //Registration of foreign and international companies as accounts of the "C" (current) types in the foreign currency are opened in the banks
							or ControlPart = "84";//Registration of foreign and international companies as correspondent accounts are opened in the banks 
						
						If Not MainDivisionFlag and Not SeparateDivisionFlag Then
							
							ReturnStructure.KPPEnteredCorrectly = False;
							
							ReturnStructure.LabelExplanationsOfIncorrectKPP = NStr("en = 'KPP does not correspond to format'");
							
							TextForIncorrectKPP = NStr("en = '%
							|KPP does not correspond to the format'");
							
							ReturnStructure.ExtendedKPPPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectKPP, KPP);
							
							ReturnStructure.NoErrorsByKPP = False;
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;	
		
	EndIf;
	
	Return ReturnStructure;
	
EndFunction	

///////////////////////////////////////////////////////////////////////////////
// First start handlers (SB)

// Procedure fills in empty IB.
//
Procedure FirstLaunch() Export
	
	BeginTransaction();
	
	// 1. We will load chart of accounts.
	ImportManagerialChartOfAccountsFirstLaunch();
	
	// 2. Fill in kind and area of business.
	Constants.ActivityKind.Set(Enums.CompanyActivityKinds.TradeAndServices);
	Constants.FunctionalOptionUseWorkSubsystem.Set(True);
	
	OthersBusinessActivityRefs = Catalogs.BusinessActivities.Other;
	OthersBusinessActivity = OthersBusinessActivityRefs.GetObject();
	OthersBusinessActivity.GLAccountRevenueFromSales = ChartsOfAccounts.Managerial.OtherIncome;
	OthersBusinessActivity.GLAccountCostOfSales = ChartsOfAccounts.Managerial.OtherExpenses;
	OthersBusinessActivity.ProfitGLAccount = ChartsOfAccounts.Managerial.ProfitsAndLossesWithoutProfitTax;
	OthersBusinessActivity.Write();
	
	IsMainBusinessActivityReference = Catalogs.BusinessActivities.MainActivity;
	IsMainBusinessActivity = IsMainBusinessActivityReference.GetObject();
	IsMainBusinessActivity.GLAccountRevenueFromSales = ChartsOfAccounts.Managerial.SalesRevenue;
	IsMainBusinessActivity.GLAccountCostOfSales = ChartsOfAccounts.Managerial.CostOfGoodsSold;
	IsMainBusinessActivity.ProfitGLAccount = ChartsOfAccounts.Managerial.ProfitsAndLossesWithoutProfitTax;
	IsMainBusinessActivity.Write();
	
	// 3. Fill in taxes kinds.
	FillTaxTypesFirstLaunch();
	
	// 4. Fill in currencies.
	USDRef = FindCreateCurrency("643", "rub.", "Russian ruble", "ruble, ruble, rubles, M, kopek, kopek, kopeks, F, 2");
	
	// 5. Fill in VAT rates.
	RateVAT18 = FillVATRatesFirstLaunch();
	
	// 6. Fill petty cashes.
	PettyCashRouble = Catalogs.PettyCashes.CreateItem();
	PettyCashRouble.Description = "Main petty cash";
	PettyCashRouble.CurrencyByDefault = USDRef;
	PettyCashRouble.GLAccount = ChartsOfAccounts.Managerial.PettyCash;
	PettyCashRouble.Write();
	
	// 7. Fill the Calendar under BusinessCalendar.
	Calendar = SmallBusinessServer.GetCalendarByProductionCalendaRF(); 
	If Calendar = Undefined Then
		
		CreateRussianFederationFiveDaysCalendar();
		Calendar = SmallBusinessServer.GetCalendarByProductionCalendaRF(); 
		
	EndIf;
	
	// 8. Fill in companies.
	OurCompanyRef = Catalogs.Companies.MainCompany;
	OurCompany = OurCompanyRef.GetObject();
	OurCompany.DescriptionFull	  = "LLC ""Our company""";
	OurCompany.Prefix				  = "OF-";
	OurCompany.LegalEntityIndividual			  = Enums.LegalEntityIndividual.LegalEntity;
	OurCompany.IncludeVATInPrice = True;
	OurCompany.PettyCashByDefault	  = PettyCashRouble.Ref;
	OurCompany.DefaultVATRate  = RateVAT18;
	OurCompany.BusinessCalendar = Calendar;
	OurCompany.Write();
	
	// 9. Fill in divisions.
	MainDivisionReference = Catalogs.StructuralUnits.MainDivision;
	MainDivision = MainDivisionReference.GetObject();
	MainDivision.Company = OurCompany.Ref;
	MainDivision.StructuralUnitType = Enums.StructuralUnitsTypes.Division;
	MainDivision.Write();
	
	// 10. Fill in the main warehouse.
	MainWarehouseReference = Catalogs.StructuralUnits.MainWarehouse;
	MainWarehouse = MainWarehouseReference.GetObject();
	MainWarehouse.StructuralUnitType = Enums.StructuralUnitsTypes.Warehouse;
	MainWarehouse.Company = OurCompany.Ref;
	MainWarehouse.Write();
	
	// 11. Fill in prices kinds.
	// Wholesale.
	WholesaleRef = Catalogs.PriceKinds.Wholesale;
	Wholesale = WholesaleRef.GetObject();
	Wholesale.PriceCurrency = USDRef;
	Wholesale.PriceIncludesVAT = True;
	Wholesale.RoundingOrder = Enums.RoundingMethods.Round1;
	Wholesale.RoundUp = False;
	Wholesale.PriceFormat = "ND=15; NFD=2";
	Wholesale.Write();
	
	// Accountable.
	AccountingReference = Catalogs.PriceKinds.Accounting;
	Accounting = AccountingReference.GetObject();
	Accounting.PriceCurrency = USDRef;
	Accounting.PriceIncludesVAT = True;
	Accounting.RoundingOrder = Enums.RoundingMethods.Round1;
	Accounting.RoundUp = False;
	Accounting.PriceFormat = "ND=15; NFD=2";
	Accounting.Write();
	
	// 12. Fill in constants.
	Constants.AccountingCurrency.Set(USDRef);
	Constants.NationalCurrency.Set(USDRef);
	Constants.ControlBalancesOnPosting.Set(true);
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		
		Constants.ExtractFileTextsAtServer.Set(true);
		
	EndIf;
	
	Constants.DoNotPostDocumentsWithIncorrectContracts.Set(False);
	Constants.ExchangeRateDifferencesCalculationFrequency.Set(Enums.ExchangeRateDifferencesCalculationFrequency.OnlyOnPeriodClosure);
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Constants.DistributedInformationBaseNodePrefix.Set(DataExchangeOverridable.InfobasePrefixByDefault());
	EndIf;
	
	// 13. Fill in planning period.
	FillPlanningPeriodFirstLaunch();
	
	// 14. Fill in classifier of the working time use.
	FillClassifierOfWorkingTimeUsage();
	
	// 15. Fill in calculation and accruals kinds parameters.
	FillCalculationParametersAndAccrualKinds();
	
	// 16. Fill in properties sets.
	MainNYReference = Catalogs.ProductsAndServicesCategories.MainGroup;
	MainNG = MainNYReference.GetObject();
	MainNG.Write();
	
	// 17. Fill in attributes of the predefined measurement units.
		
	// Piece.
	PcsRefs = Catalogs.UOMClassifier.pcs;
	PcsObject = PcsRefs.GetObject();
	PcsObject.DescriptionFull = "Piece";
	PcsObject.InternationalAbbreviation = "PCE";
	PcsObject.Write();
	
	// Hour.
	hRef = Catalogs.UOMClassifier.h;
	chObject = hRef.GetObject();
	chObject.DescriptionFull = "Hour";
	chObject.InternationalAbbreviation = "HUR";
	chObject.Write();
	
	// 18. Fill in customer orders states.
	OpenOrderState = Catalogs.CustomerOrderStates.Open;
	OpenOrderStateObject = OpenOrderState.GetObject();
	OpenOrderStateObject.OrderStatus = Enums.OrderStatuses.Open;
	OpenOrderStateObject.Write();
	
	PlannedObjectOrderStatus = Catalogs.CustomerOrderStates.CreateItem();
	PlannedObjectOrderStatus.Description = "In process";
	PlannedObjectOrderStatus.OrderStatus = Enums.OrderStatuses.InProcess;
	PlannedObjectOrderStatus.Write();
	
	Constants.CustomerOrdersInProgressStatus.Set(PlannedObjectOrderStatus.Ref);
	
	CompletedOrderStateObject = Catalogs.CustomerOrderStates.CreateItem();
	CompletedOrderStateObject.Description = "Completed";
	CompletedOrderStateObject.OrderStatus = Enums.OrderStatuses.Completed;
	Color = StyleColors.PastEvent;
	CompletedOrderStateObject.Color = New ValueStorage(Color);
	CompletedOrderStateObject.Write();
	
	Constants.CustomerOrdersCompletedStatus.Set(CompletedOrderStateObject.Ref);
	
	// 19. Purchase orders.
	OpenOrderState = Catalogs.PurchaseOrderStates.Open;
	OpenOrderStateObject = OpenOrderState.GetObject();
	OpenOrderStateObject.OrderStatus = Enums.OrderStatuses.Open;
	OpenOrderStateObject.Write();
	
	PlannedObjectOrderStatus = Catalogs.PurchaseOrderStates.CreateItem();
	PlannedObjectOrderStatus.Description = "In process";
	PlannedObjectOrderStatus.OrderStatus = Enums.OrderStatuses.InProcess;
	PlannedObjectOrderStatus.Write();
	
	Constants.PurchaseOrdersInProgressStatus.Set(PlannedObjectOrderStatus.Ref);
	
	CompletedOrderStateObject = Catalogs.PurchaseOrderStates.CreateItem();
	CompletedOrderStateObject.Description = "Completed";
	CompletedOrderStateObject.OrderStatus = Enums.OrderStatuses.Completed;
	Color = StyleColors.PastEvent;
	CompletedOrderStateObject.Color = New ValueStorage(Color);
	CompletedOrderStateObject.Write();
	
	Constants.PurchaseOrdersCompletedStatus.Set(CompletedOrderStateObject.Ref);
	
	// 20. Fill in production orders states.
	OpenOrderState = Catalogs.ProductionOrderStates.Open;
	OpenOrderStateObject = OpenOrderState.GetObject();
	OpenOrderStateObject.OrderStatus = Enums.OrderStatuses.Open;
	OpenOrderStateObject.Write();
	
	PlannedObjectOrderStatus = Catalogs.ProductionOrderStates.CreateItem();
	PlannedObjectOrderStatus.Description = "In process";
	PlannedObjectOrderStatus.OrderStatus = Enums.OrderStatuses.InProcess;
	PlannedObjectOrderStatus.Write();
	
	Constants.ProductionOrdersInProgressStatus.Set(PlannedObjectOrderStatus.Ref);
	
	CompletedOrderStateObject = Catalogs.ProductionOrderStates.CreateItem();
	CompletedOrderStateObject.Description = "Completed";
	CompletedOrderStateObject.OrderStatus = Enums.OrderStatuses.Completed;
	Color = StyleColors.PastEvent;
	CompletedOrderStateObject.Color = New ValueStorage(Color);
	CompletedOrderStateObject.Write();

	Constants.ProductionOrdersCompletedStatus.Set(CompletedOrderStateObject.Ref);
	
	// 21. Set the date of movements change by order warehouse.
	Constants.UpdateDateToRelease_1_2_1.Set("19800101");
	
	// 22. Set a balances control flag when the CR receipts are given.
	Constants.ControlBalancesDuringCreationCRReceipts.Set(True);
	
	// 23. Selection settings
	FillFilterUserSettings();
	
	// 24. Constant PlannedTotalsOptimizationDate
	Constants.PlannedTotalsOptimizationDate.Set(EndOfMonth(AddMonth(CurrentSessionDate(), 1)));
	
	// 25. Contact information
	RefreshPredefinedKindsOfContact();
	
	// 26. Price-list constants.
	Constants.PriceListShowCode.Set(Enums.YesNo.Yes);
	Constants.PriceListShowFullDescr.Set(Enums.YesNo.No);
	Constants.PriceListUseProductsAndServicesHierarchy.Set(True);
	Constants.FormPriceListByAvailabilityInWarehouses.Set(False);
	
	// 28. Registration
	DeleteChangeRegistrationOfBaseClassifiers();
	
	// 29. Fill in contracts forms.
	FillContractsForms();

	// 30. Constant.CustomerInvoiceNote1137UsageBegin
	Constants.CustomerInvoiceNote1137UsageBegin.Set(Date(2012, 04, 01));
	
	// 31. Constant.OffsetAdvancesDebtsAutomatically
	Constants.OffsetAdvancesDebtsAutomatically.Set(Enums.YesNo.No);
	
	// 32. BPO
	EquipmentManagerServerCallOverridable.RefreshSuppliedDrivers();
	
	CommitTransaction();
	
EndProcedure // FirstLaunch()

///////////////////////////////////////////////////////////////////////////////
// Versions update handlers (SB)

#Region Update_1_5_3_6

Procedure UpdateChangesProhibitionDatesSections(ParametersStructure = Undefined) Export
	
	ChangeProhibitionDatesOverridable.UpdateChangesProhibitionDatesSections(ParametersStructure.DataProcessorCompleted);
	
EndProcedure

#EndRegion

#Region Update_1_5_3_13

Procedure UpdateContractForms(ParametersStructure = Undefined) Export
	
	BeginTransaction();
	Try
	
		Selection = Catalogs.ContractForms.Select();
		
		While Selection.Next() Do
			
			ReceivedObject = Selection.GetObject();
			ReceivedObject.InfobaseParameters.Clear();
			Form = ReceivedObject.Form.Get();
			
			TextHTML = Form.HTMLText;
			
			Cases = New Array;
			Cases.Add(Undefined);
			Cases.Add("nominative");
			Cases.Add("genitive");
			Cases.Add("dative");
			Cases.Add("accusative");
			Cases.Add("instrumental");
			Cases.Add("prepositional");
			
			For Each ParameterEnumeration IN Enums.ContractsWithCounterpartiesTemplatesParameters Do
				
				For Each Case IN Cases Do
					If Case = Undefined Then
						PresentationCase = "";
					Else
						PresentationCase = " (" + Case + ")";
					EndIf;
					
					Parameter = "{" + String(ParameterEnumeration) + PresentationCase + "}";
					OccurrenceCount = StrOccurrenceCount(TextHTML, Parameter);
					For ParameterNumber = 1 To OccurrenceCount Do
						If ParameterNumber = 1 Then
							Presentation = "{" + String(ParameterEnumeration) + PresentationCase + "%deleteSymbols%" + "}";
							ID = "infoParameter" + String(ParameterEnumeration) + ParameterNumber;
						Else
							Presentation = "{" + String(ParameterEnumeration) + ParameterNumber + PresentationCase + "}";
							ID = "infoParameter" + String(ParameterEnumeration) + ParameterNumber;
						EndIf;
						
						FirstOccurence = Find(TextHTML, Parameter);
						
						TextHTML = Left(TextHTML, FirstOccurence - 1) + Presentation + Mid(TextHTML, FirstOccurence + StrLen(Parameter));
						
						NewRow = ReceivedObject.InfobaseParameters.Add();
						NewRow.Presentation = StrReplace(Presentation, "%deleteSymbols%", "");
						NewRow.ID = ID;
						NewRow.Parameter = ParameterEnumeration;
						
					EndDo;
					TextHTML = StrReplace(TextHTML, "%deleteSymbols%", "");
				EndDo;
			EndDo;
			
			AdditionalAttributesOwners = New Array;
			AdditionalAttributesOwners.Add(Documents.CustomerOrder.EmptyRef());
			AdditionalAttributesOwners.Add(Documents.InvoiceForPayment.EmptyRef());
			AdditionalAttributesOwners.Add(Catalogs.CounterpartyContracts.EmptyRef());
			AdditionalAttributesOwners.Add(Catalogs.Counterparties.EmptyRef());
			
			For Each Item IN AdditionalAttributesOwners Do
				AdditionalAttributes = PropertiesManagement.GetListOfProperties(Item, True, False);
				
				For Each Attribute IN AdditionalAttributes Do
					Parameter = "{" + String(Attribute.Description) + "}";
					OccurrenceCount = StrOccurrenceCount(TextHTML, Parameter);
					For ParameterNumber = 1 To OccurrenceCount Do
						If ParameterNumber = 1 Then
							Presentation = "{" + String(Attribute.Description) + "}";
						Else
							Presentation = "{" + String(Attribute.Description) + ParameterNumber + "}";
						EndIf;
						
						ParameterNamePresentation = StrReplace(Attribute.Description, " ", "");
						ParameterNamePresentation = StrReplace(ParameterNamePresentation, "(", "");
						ParameterNamePresentation = StrReplace(ParameterNamePresentation, ")", "");
						ID = "additionalParameter" + ParameterNamePresentation + ParameterNumber;
						
						FirstOccurence = Find(TextHTML, Parameter);
						
						TextHTML = Left(TextHTML, FirstOccurence - 1) + Presentation + Mid(TextHTML, FirstOccurence + StrLen(Parameter));
						
						NewRow = ReceivedObject.InfobaseParameters.Add();
						NewRow.Presentation = StrReplace(Presentation, "%deleteSymbols%", "");
						NewRow.ID = ID;
						NewRow.Parameter = Attribute;
						
					EndDo;
					TextHTML = StrReplace(TextHTML, "%deleteSymbols%", "");
				EndDo;
			EndDo;
			
			FormattedDocumentStructure = New Structure;
			FormattedDocumentStructure.Insert("HTMLText", TextHTML);
			FormattedDocumentStructure.Insert("Attachments", New Structure);
			
			ReceivedObject.Form = New ValueStorage(FormattedDocumentStructure);
			ReceivedObject.Write();
			
		EndDo;
		
		ParametersStructure.DataProcessorCompleted = True;
		CommitTransaction();
		
	Except
		
		ParametersStructure.DataProcessorCompleted = False;
		RollbackTransaction();
		
	EndTry;
	
EndProcedure

#EndRegion

#Region Update_1_5_3_26

Procedure TransferDataFromDeletedObjects(ParametersStructure = Undefined) Export

	SetPrivilegedMode(True);
	
	BeginTransaction();
	
	Try
		
		If Constants.DeleteEnterInformationForDeclarationsOnAlcoholicProducts.Get() Then
			Constants.EnterInformationForDeclarationsOnAlcoholicProducts.Set(True);
		EndIf;
		
		Query = New Query;
		Query.Text = 
		"SELECT DISTINCT
		|	DeleteAlcoholicProductsKinds.Description,
		|	DeleteAlcoholicProductsKinds.LicenseKind,
		|	DeleteAlcoholicProductsKinds.Code
		|FROM
		|	Catalog.DeleteAlcoholicProductsKinds AS DeleteAlcoholicProductsKinds
		|WHERE
		|	Not DeleteAlcoholicProductsKinds.DeletionMark
		|	AND Not DeleteAlcoholicProductsKinds.Description In
		|				(SELECT
		|					AlcoholicProductsKinds.Description
		|				FROM
		|					Catalog.AlcoholicProductsKinds AS AlcoholicProductsKinds
		|				WHERE
		|					Not AlcoholicProductsKinds.DeletionMark)";
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			NewItem = Catalogs.AlcoholicProductsKinds.CreateItem();
			FillPropertyValues(NewItem, Selection);
			If ValueIsFilled(Selection.LicenseKind) Then
				If Selection.LicenseKind = Enums.DeleteLicenseKindsOnAlcoholicProducts.AlcoholicProducts Then
					NewItem.LicenseKind = Enums.LicenseKindsOnAlcoholicProducts.AlcoholicProducts;
				ElsIf Selection.LicenseKind = Enums.DeleteLicenseKindsOnAlcoholicProducts.Beer Then
					NewItem.LicenseKind = Enums.LicenseKindsOnAlcoholicProducts.Beer;		
				ElsIf Selection.LicenseKind = Enums.DeleteLicenseKindsOnAlcoholicProducts.AlcoholContainingNonFoodProducts Then
					NewItem.LicenseKind = Enums.LicenseKindsOnAlcoholicProducts.AlcoholContainingNonFoodProducts;
				ElsIf Selection.LicenseKind = Enums.DeleteLicenseKindsOnAlcoholicProducts.AlcoholContainingFoodProducts Then
					NewItem.LicenseKind = Enums.LicenseKindsOnAlcoholicProducts.AlcoholContainingFoodProducts;
				EndIf;
			EndIf;
			InfobaseUpdate.WriteData(NewItem, True);
			
		EndDo;
		
		Query = New Query;
		Query.Text =
		"SELECT DISTINCT
		|	DeleteAlcoholVendorsLicenses.Owner,
		|	DeleteAlcoholVendorsLicenses.Description,
		|	DeleteAlcoholVendorsLicenses.LicenseKind,
		|	DeleteAlcoholVendorsLicenses.StartDate,
		|	DeleteAlcoholVendorsLicenses.EndDate,
		|	DeleteAlcoholVendorsLicenses.IssuedBy
		|FROM
		|	Catalog.DeleteAlcoholVendorsLicenses AS DeleteAlcoholVendorsLicenses
		|WHERE
		|	Not DeleteAlcoholVendorsLicenses.DeletionMark
		|	AND Not DeleteAlcoholVendorsLicenses.Description In
		|				(SELECT
		|					AlcoholicProductsVendorLicenses.Description
		|				FROM
		|					Catalog.AlcoholicProductsVendorLicenses AS AlcoholicProductsVendorLicenses
		|				WHERE
		|					Not AlcoholicProductsVendorLicenses.DeletionMark)
		|	AND DeleteAlcoholVendorsLicenses.Owner <> VALUE(Catalog.Counterparties.EmptyRef)";
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			NewItem = Catalogs.AlcoholicProductsVendorLicenses.CreateItem();
			FillPropertyValues(NewItem, Selection);
			If ValueIsFilled(Selection.LicenseKind) Then
				If Selection.LicenseKind = Enums.DeleteLicenseKindsOnAlcoholicProducts.AlcoholicProducts Then
					NewItem.LicenseKind = Enums.LicenseKindsOnAlcoholicProducts.AlcoholicProducts;
				ElsIf Selection.LicenseKind = Enums.DeleteLicenseKindsOnAlcoholicProducts.Beer Then
					NewItem.LicenseKind = Enums.LicenseKindsOnAlcoholicProducts.Beer;		
				ElsIf Selection.LicenseKind = Enums.DeleteLicenseKindsOnAlcoholicProducts.AlcoholContainingNonFoodProducts Then
					NewItem.LicenseKind = Enums.LicenseKindsOnAlcoholicProducts.AlcoholContainingNonFoodProducts;
				ElsIf Selection.LicenseKind = Enums.DeleteLicenseKindsOnAlcoholicProducts.AlcoholContainingFoodProducts Then
					NewItem.LicenseKind = Enums.LicenseKindsOnAlcoholicProducts.AlcoholContainingFoodProducts;
				EndIf;
			EndIf;
			InfobaseUpdate.WriteData(NewItem, True);
			
		EndDo;
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ProductsAndServicesCategories.Ref,
		|	AlcoholicProductsKinds.Ref AS AlcoProductsKind
		|FROM
		|	Catalog.ProductsAndServicesCategories AS ProductsAndServicesCategories
		|		LEFT JOIN Catalog.AlcoholicProductsKinds AS AlcoholicProductsKinds
		|		ON ProductsAndServicesCategories.DeleteAlcoholicProductsKind.Description = AlcoholicProductsKinds.Description
		|WHERE
		|	ProductsAndServicesCategories.AlcoholicProductsKind = VALUE(Catalog.AlcoholicProductsKinds.EmptyRef)
		|	AND ProductsAndServicesCategories.DeleteAlcoholicProductsKind <> VALUE(Catalog.DeleteAlcoholicProductsKinds.EmptyRef)";
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			// Lock object from change by other sessions.
			Block = New DataLock;
			LockItem = Block.Add("Catalog.ProductsAndServicesCategories");
			LockItem.SetValue("Ref", Selection.Ref);
			Block.Lock();
			
			ProductsAndServicesCategoryObject = Selection.Ref.GetObject();
			ProductsAndServicesCategoryObject.AlcoholicProductsKind = Selection.AlcoProductsKind;
			ProductsAndServicesCategoryObject.ImportedAlcoholicProducts = ProductsAndServicesCategoryObject.DeleteImportedAlcoholicProducts;
			
			// If object is deleted, skip it.
			If ProductsAndServicesCategoryObject = Undefined Then
				Continue;
			EndIf;
			
			// Write the processed object.
			InfobaseUpdate.WriteData(ProductsAndServicesCategoryObject, True);
			
		EndDo;
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ProductsAndServices.Ref,
		|	AlcoholicProductsKinds.Ref AS AlcoProductsKind
		|FROM
		|	Catalog.ProductsAndServices AS ProductsAndServices
		|		LEFT JOIN Catalog.AlcoholicProductsKinds AS AlcoholicProductsKinds
		|		ON ProductsAndServices.DeleteAlcoholicProductsKind.Description = AlcoholicProductsKinds.Description
		|WHERE
		|	(ProductsAndServices.DeleteAlcoholicProductsKind <> VALUE(Catalog.DeleteAlcoholicProductsKinds.EmptyRef)
		|			OR ProductsAndServices.DeleteImportedAlcoholicProducts
		|			OR ProductsAndServices.DeleteAlcoholicProductsManufacturerImporter <> VALUE(Catalog.Counterparties.EmptyRef)
		|			OR ProductsAndServices.DeleteVolumeDAL <> 0)";
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			// Lock object from change by other sessions.
			Block = New DataLock;
			LockItem = Block.Add("Catalog.ProductsAndServices");
			LockItem.SetValue("Ref", Selection.Ref);
			Block.Lock();
			
			ProductsAndServicesObject = Selection.Ref.GetObject();
			
			If ValueIsFilled(ProductsAndServicesObject.DeleteAlcoholicProductsKind)
				AND Not ValueIsFilled(ProductsAndServicesObject.AlcoholicProductsKind)
				AND ValueIsFilled(Selection.AlcoProductsKind) Then
				ProductsAndServicesObject.AlcoholicProductsKind = Selection.AlcoProductsKind;
			EndIf;
			
			If ValueIsFilled(ProductsAndServicesObject.DeleteAlcoholicProductsManufacturerImporter)
				AND Not ValueIsFilled(ProductsAndServicesObject.AlcoholicProductsManufacturerImporter) Then
				ProductsAndServicesObject.AlcoholicProductsManufacturerImporter = ProductsAndServicesObject.DeleteAlcoholicProductsManufacturerImporter;
			EndIf;
			
			If ValueIsFilled(ProductsAndServicesObject.DeleteVolumeDAL)
				AND Not ValueIsFilled(ProductsAndServicesObject.VolumeDAL) Then
				ProductsAndServicesObject.VolumeDAL = ProductsAndServicesObject.DeleteVolumeDAL;
			EndIf;
			
			ProductsAndServicesObject.ImportedAlcoholicProducts = ProductsAndServicesObject.CountryOfOrigin <> Catalogs.WorldCountries.Russia;
			
			// If object is deleted, skip it.
			If ProductsAndServicesObject = Undefined Then
				Continue;
			EndIf;
			
			// Write the processed object.
			InfobaseUpdate.WriteData(ProductsAndServicesObject, True);
			
		EndDo;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Unable to convert data on alcoholic products as: '"), DetailErrorDescription(ErrorInfo()));
		WriteLogEvent(InfobaseUpdate.EventLogMonitorEvent(), EventLogLevel.Error,,, MessageText);
	EndTry;
	
EndProcedure

#EndRegion
