//////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtClient
Procedure SetPagesVisibleAtClient()
	
	DescriptionCurrentPagesCompanies = "CompaniesPage" + ?(UseCompaniesFilter, "available", "NotAvailable");
	
	Items.TabularSections.CurrentPage = Items[DescriptionCurrentPagesCompanies];
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	DataExchangeServer.CorrespondentInfobaseNodeSettingsFormOnCreateAtServer(
		ThisForm,
		"ExchangeSmallBusinessAccounting30"
	);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetPagesVisibleAtClient();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	DataExchangeClient.SettingFormBeforeClose(Cancel, ThisForm);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure UseFilterOnChange(Item)
	
	SetPagesVisibleAtClient();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EVENTS HANDLERS OF FORM TABLES Companies

&AtClient
Procedure CompaniesCompanyStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.CorrespondentInfobaseObjectSelectionHandlerStartChoice("Company", "Catalog.Companies", Items.Companies, StandardProcessing, ExternalConnectionParameters);
	
EndProcedure

&AtClient
Procedure CompaniesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	DataExchangeClient.CorrespondentInfobaseObjectSelectionProcessingHandler(Item, ValueSelected, Companies);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure CommandOK(Command)
	
	DataExchangeClient.NodeConfigurationFormCommandCloseForm(ThisForm);
	
EndProcedure

&AtClient
Procedure FillCompanies(Command)
	
	DataExchangeClient.CorrespondentInfobaseObjectSelectionHandlerFill("Company", "Catalog.Companies", Items.Companies, ExternalConnectionParameters);
	
EndProcedure














