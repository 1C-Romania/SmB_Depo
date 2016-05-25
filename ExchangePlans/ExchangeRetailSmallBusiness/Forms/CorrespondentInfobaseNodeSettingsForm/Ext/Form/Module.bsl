////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
    Data = New Map;
    Data.Insert("Catalog.Companies");
    Data.Insert("Catalog.Shops");
	
	DataExchangeServer.CorrespondentInfobaseNodeSettingsFormOnCreateAtServer(
		ThisForm,
		Metadata.ExchangePlans.ExchangeRetailSmallBusiness.Name,
		Data);
	
	CompanySubsidiaryAttributeSynchronizationMode =
		?(UseCompaniesFilter, "SynchronizeDataBySelectedCompaniesOnly", "SynchronizeDataByAllCompanies")
	;
	
	UpdateDataToFormTable(Data["Catalog.Companies"], CompanySubsidiaryAttribute, "Company");
	
	CancelSelectedTableItems("Companies", "CompanySubsidiaryAttribute", "Company_Key");
	
	ExchangePlans.ExchangeRetailSmallBusiness.DefineDocumentsSynchronizationVariant(SynchronizingDocumentsVariant, ThisForm);
	ExchangePlans.ExchangeRetailSmallBusiness.DefineCatalogsSynchronizationVariant(CatalogsSynchronizingVariant, ThisForm);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SynchronizationModeCompanyOnValueChange();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	DataExchangeClient.SettingFormBeforeClose(Cancel, ThisForm);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM ITEMS EVENTS HANDLERS

&AtClient
Procedure SupportAttributeCompaniesSynchronizationModeOnChange(Item)
	
	SynchronizationModeCompanyOnValueChange();
	
EndProcedure

&AtClient
Procedure CompanySupportAttributeUseOnChange(Item)
	
	GenerateCompanyTableTitle();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure WriteAndClose(Command)
	
	WriteAndCloseOnServer();
	
	DataExchangeClient.NodeConfigurationFormCommandCloseForm(ThisForm);
	
EndProcedure

&AtClient
Procedure EnableAllCompanies(Command)
	
	EnableDisableAllItemsInTable(True, "CompanySubsidiaryAttribute");
	
EndProcedure

&AtClient
Procedure DisableAllCompanies(Command)
	
	EnableDisableAllItemsInTable(False, "CompanySubsidiaryAttribute");
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure WriteAndCloseOnServer()
	
	UseCompaniesFilter =
		(CompanySubsidiaryAttributeSynchronizationMode = "SynchronizeDataBySelectedCompaniesOnly")
	;
	
	
	If UseCompaniesFilter Then
		
		Companies.Load(CompanySubsidiaryAttribute.Unload(New Structure("Use", True), "Company, Company_Key"));
		
	Else
		
		Companies.Clear();
		
	EndIf;
	
	ExchangePlans.ExchangeRetailSmallBusiness.DefineImportDocumentsMode(SynchronizingDocumentsVariant, ThisForm);
	ExchangePlans.ExchangeRetailSmallBusiness.DefineCatalogsImportMode(CatalogsSynchronizingVariant, ThisForm);
	
EndProcedure

&AtClient
Procedure EnableDisableAllItemsInTable(Enable, TableName)
	
	For Each CollectionItem IN ThisForm[TableName] Do
		
		CollectionItem.Use = Enable;
		
	EndDo;
	
	GenerateCompanyTableTitle();
	
EndProcedure

&AtClient
Procedure SynchronizationModeCompanyOnValueChange()
	
	Items.CompanySubsidiaryAttribute.Enabled =
		(CompanySubsidiaryAttributeSynchronizationMode = "SynchronizeDataBySelectedCompaniesOnly")
	;
	
	GenerateCompanyTableTitle();
	
EndProcedure

&AtServer
Procedure CancelSelectedTableItems(TableName, HelperTableName, AttributeName)
	
	For Each TableRow IN ThisForm[TableName] Do
		
		Rows = ThisForm[HelperTableName].FindRows(New Structure(AttributeName, TableRow[AttributeName]));
		
		If Rows.Count() > 0 Then
			
			Rows[0].Use = True;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure GenerateCompanyTableTitle()
	
	If CompanySubsidiaryAttributeSynchronizationMode = "SynchronizeDataBySelectedCompaniesOnly" Then
		
		PageTitle = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en = 'By companies (%1)'"),
			SelectedRowsQuantity("CompanySubsidiaryAttribute")
		);
	Else
		
		PageTitle = NStr("en = 'By all companies'");
	EndIf;
	
	Items.CompaniesPage.Title = PageTitle;
	
EndProcedure

&AtClient
Function SelectedRowsQuantity(TableName)
	
	Result = 0;
	
	For Each CollectionItem IN ThisForm[TableName] Do
		
		If CollectionItem.Use Then
			
			Result = Result + 1;
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Procedure UpdateDataToFormTable(Source, Receiver, AttributeName)
	
	Receiver.Clear();
	
	For Each SourceRow IN Source Do
		
		TargetRow = Receiver.Add();
		TargetRow[AttributeName] = SourceRow.Presentation;
		TargetRow[AttributeName + "_Key"] = SourceRow.ID;
		
	EndDo;
	
EndProcedure



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
