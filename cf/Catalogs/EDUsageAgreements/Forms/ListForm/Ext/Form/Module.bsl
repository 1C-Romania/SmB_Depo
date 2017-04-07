////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseEDExchange") Then
		MessageText = ElectronicDocumentsServiceCallServer.MessageTextAboutSystemSettingRequirement("WorkWithED");
		CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
		Return;
	EndIf;
	
	If Parameters.Property("WindowOpeningMode") Then
		ThisForm.WindowOpeningMode = Parameters.WindowOpeningMode;
	EndIf;
	
	If Parameters.Property("DoNotShowQuickFilters") Then
		Items.GroupQuickFilters.Visible = False;
	EndIf;
	
	CatalogsNameBanks = ElectronicDocumentsReUse.GetAppliedCatalogName("Banks");
	If ValueIsFilled(CatalogsNameBanks) Then
		AgreementsWithBanksList.QueryText = StrReplace(AgreementsWithBanksList.QueryText,
			"Agreement.Counterparty", "CAST(Agreement.Counterparty AS Catalog." + CatalogsNameBanks + ")");
	EndIf;
	
	Counterparty         = Parameters.Counterparty;
	EDFProfileSettings = Parameters.EDFProfileSettings;
	Company        = Parameters.Company;
	
	If ValueIsFilled(Counterparty) Then
		CommonUseClientServer.SetFilterItem(AgreementsWithCounterpartiesList.Filter, "Counterparty",
			Counterparty, DataCompositionComparisonType.Equal);
			
		ThisForm.AutoTitle = False;
		ThisForm.Title = NStr("en='EDF with counterparties settings';ru='Настройки ЭДО с контрагентами'");
		Items.AgreementsGroup.PagesRepresentation = FormPagesRepresentation.None;
		Items.AgreementsGroup.CurrentPage = Items.SettingsGroup;
	EndIf;
	
	If ValueIsFilled(EDFProfileSettings) Then
		CommonUseClientServer.SetFilterItem(AgreementsWithCounterpartiesList.Filter, "EDFProfileSettings",
			EDFProfileSettings, DataCompositionComparisonType.Equal);
			
		ThisForm.AutoTitle = False;
		ThisForm.Title = NStr("en='EDF with counterparties settings';ru='Настройки ЭДО с контрагентами'");
		Items.AgreementsGroup.PagesRepresentation = FormPagesRepresentation.None;
		Items.AgreementsGroup.CurrentPage = Items.SettingsGroup;
	EndIf;
	
	If ElectronicDocumentsReUse.UseAdditionalAnalyticsOfCompaniesCatalogPartners() Then
		
		AgreementsWithCounterpartiesList.QueryText = StrReplace(
			AgreementsWithCounterpartiesList.QueryText, """Partner""", "Agreement.Counterparty.Partner");
		If ValueIsFilled(Parameters.Partner) Then
			CommonUseClientServer.SetFilterItem(AgreementsWithCounterpartiesList.Filter, "Partner",
				Parameters.Partner, DataCompositionComparisonType.InHierarchy);
				
			ThisForm.AutoTitle = False;
			ThisForm.Title = NStr("en='Settings EDF with counterparties';ru='Настройки ЭДО с контрагентами'");
			Items.AgreementsGroup.PagesRepresentation = FormPagesRepresentation.None;
			Items.AgreementsGroup.CurrentPage = Items.SettingsGroup;
		EndIf;
	Else
		AgreementsWithCounterpartiesList.QueryText = StrReplace(
			AgreementsWithCounterpartiesList.QueryText, """Partner"" AS Partner,", "");
	EndIf;
	
	If ValueIsFilled(Counterparty)
		OR ValueIsFilled(EDFProfileSettings)
		OR ValueIsFilled(Parameters.Partner)
		OR Parameters.SettingsEDFWithCounterparties Then
		
		ThisForm.AutoTitle = False;
		ThisForm.Title = NStr("en='EDF with counterparties settings';ru='Настройки ЭДО с контрагентами'");
		Items.AgreementsGroup.PagesRepresentation = FormPagesRepresentation.None;
		Items.AgreementsGroup.CurrentPage    = Items.SettingsGroup;
	EndIf;
	
	If ValueIsFilled(Parameters.Bank) Then
		CommonUseClientServer.SetFilterItem(AgreementsWithBanksList.Filter, "Bank",
			Parameters.Bank, DataCompositionComparisonType.Equal);
			
		ThisForm.AutoTitle = False;
		ThisForm.Title = NStr("en='EDF settings with banks';ru='Настройки ЭДО с банками'");
		Items.AgreementsGroup.PagesRepresentation = FormPagesRepresentation.None;
		Items.AgreementsGroup.CurrentPage = Items.GroupAgreementsWithBanksList;
	EndIf;
	
	If ValueIsFilled(Company) Then
		CommonUseClientServer.SetFilterItem(
			AgreementsWithBanksList.Filter, "Company", Company, DataCompositionComparisonType.Equal);
		CommonUseClientServer.SetFilterItem(
			AgreementsWithCounterpartiesList.Filter, "Company", Company, DataCompositionComparisonType.Equal);
		CommonUseClientServer.SetFilterItem(
			ListAgreementsBetweenCompanies.Filter, "Company", Company, DataCompositionComparisonType.Equal);
	EndIf;
	
	// Hide group "All agreements" from users with limited rights or forced.
	HideAllAgreementsBookmark = Not Users.InfobaseUserWithFullAccess()
									OR ValueIsFilled(Parameters.Counterparty)
									OR ValueIsFilled(Parameters.Company)
									OR ValueIsFilled(Parameters.Bank)
									OR ValueIsFilled(Parameters.EDFProfileSettings)
									OR ValueIsFilled(Parameters.Partner)
									OR Parameters.SettingsEDFWithCounterparties;
	
	Items.GroupAllAgreements.Visible = Not HideAllAgreementsBookmark;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ElectronicDocumentsServiceClient.FillDataServiceSupport(ServiceSupportPhoneNumber, ServiceSupportEmailAddress);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		Items.AgreementsWithCounterpartiesList.Refresh();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure LoadSettings(Command)
	
	AddressInStorage = Undefined;
	Handler = New NotifyDescription("SettingFileChoiceProcessing", ThisObject);
	BeginPutFile(Handler, AddressInStorage, "*.xml", True, UUID);

EndProcedure

&AtClient
Procedure OpenLinkTo1CBuhphoneItem(Command)
	
	ElectronicDocumentsServiceClient.OpenStatement1CBuhphone();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM FIELD EVENT HANDLERS

&AtClient
Procedure CounterpartyOnChange(Item)
	SetFilterOnCounterparty(ThisObject, Counterparty);
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	SetFilterByCompany(ThisObject, Company);
EndProcedure

&AtClient
Procedure StatusOnChange(Item)
	SetFilterByConnectionStatus(ThisObject, ConnectionStatus);
EndProcedure

&AtClient
Procedure AgreementStateOnChange(Item)
	SetFilterByAgreementState(ThisObject, AgreementState);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABLE FIELD EVENT HANDLERS SettingListWithCounterparties

&AtClient
Procedure CreateListItemSettingsWithContractors(Command)
	
	FormParameters = New Structure;
	FillingValues = New Structure;
	FillingValues.Insert("Company",        Company);
	FillingValues.Insert("EDFProfileSettings", EDFProfileSettings);
	FillingValues.Insert("Counterparty",         Counterparty);
	
	FormParameters.Insert("FillingValues", FillingValues);
	OpenForm("Catalog.EDUsageAgreements.Form.ItemForm", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABLE FIELD EVENT HANDLERS ListIntercompany

&AtClient
Procedure IntercompanyListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	Parameter = ?(Copy, New Structure("CopyingValue", Items.ListIntercompany.CurrentRow),
		New Structure);
	
	OpenForm("Catalog.EDUsageAgreements.Form.IntercompanyItemForm", Parameter,
		Items.ListIntercompany);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABLE FIELD EVENT HANDLERS AgreementsWithBanksList

&AtClient
Procedure AgreementsWithBanksListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	Parameter = ?(Copy, New Structure("CopyingValue", Items.AgreementsWithBanksList.CurrentRow), New Structure);
	Parameter.Insert("Company", Company);
	Parameter.Insert("Counterparty", Parameters.Bank);
	OpenForm(
		"Catalog.EDUsageAgreements.Form.ItemFormBank", Parameter, Items.AgreementsWithBanksList);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtClientAtServerNoContext
Procedure SetFilterOnCounterparty(Form, FilterValue)
	
	UseFilter = ValueIsFilled(FilterValue);
	
	CommonUseClientServer.SetFilterItem(
										Form.AgreementsWithCounterpartiesList.Filter,
										"Counterparty",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
EndProcedure

&AtClientAtServerNoContext
Procedure SetFilterByCompany(Form, FilterValue)
	
	UseFilter = ValueIsFilled(FilterValue);
	
	CommonUseClientServer.SetFilterItem(
										Form.AgreementsWithCounterpartiesList.Filter,
										"Company",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
EndProcedure

&AtClientAtServerNoContext
Procedure SetFilterByConnectionStatus(Form, FilterValue)
	
	UseFilter = ValueIsFilled(FilterValue);
	
	CommonUseClientServer.SetFilterItem(
										Form.AgreementsWithCounterpartiesList.Filter,
										"ConnectionStatus",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
EndProcedure

&AtClientAtServerNoContext
Procedure SetFilterByAgreementState(Form, FilterValue)
	
	UseFilter = ValueIsFilled(FilterValue);
	
	CommonUseClientServer.SetFilterItem(
										Form.AgreementsWithCounterpartiesList.Filter,
										"AgreementState",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
EndProcedure

&AtClient
Procedure SettingFileChoiceProcessing(Result, Address, FileName, AdditionalParameters) Export
	
	If Result = True Then
		FormParameters = New Structure("CompletingSettings", Address);
		OpenForm("Catalog.EDUsageAgreements.Form.ItemFormBank", FormParameters);
	EndIf;
	
EndProcedure
