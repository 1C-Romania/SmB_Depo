////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	DataExchangeServer.NodeConfigurationFormOnCreateAtServer(ThisForm, Metadata.ExchangePlans.ExchangeRetailSmallBusiness.Name);
	
	CompanySubsidiaryAttributeSynchronizationMode =
		?(UseCompaniesFilter, "SynchronizeDataBySelectedCompaniesOnly", "SynchronizeDataByAllCompanies")
	;
	
	SubsidiaryAttributeWarehousesSyncMode =
		?(UseFilterByWarehouses, "SynchronizeDataOnlyInSelectedWarehouses", "SynchronizeDataInAllWarehouses")
	;
	
	CompanySubsidiaryAttribute.Load(AllCompaniesAddition());
	SubsidiaryAttributeWarehouses.Load(AllApplicationWarehouses());
	
	CancelSelectedTableItems("Companies", "CompanySubsidiaryAttribute", "Company");
	CancelSelectedTableItems("Warehouses", "SubsidiaryAttributeWarehouses", "Warehouse");
	
	ExchangePlans.ExchangeRetailSmallBusiness.DefineDocumentsSynchronizationVariant(SynchronizingDocumentsVariant, ThisForm);
	ExchangePlans.ExchangeRetailSmallBusiness.DefineCatalogsSynchronizationVariant(CatalogsSynchronizingVariant, ThisForm);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SynchronizationModeCompanyOnValueChange();
	WarehousesSyncModeOnChangeValue();
	
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
Procedure SubsidiaryAttributeWarehousesSyncModeOnChange(Item)
	
	WarehousesSyncModeOnChangeValue();
	
EndProcedure

&AtClient
Procedure CompanySupportAttributeUseOnChange(Item)
	
	GenerateCompanyTableTitle();
	
EndProcedure

&AtClient
Procedure SubsidiaryAttributeWarehousesUseOnChange(Item)
	
	GenerateTableTitleWarehouses();
	
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
Procedure EnableAllWarehouses(Command)
	
	EnableDisableAllItemsInTable(True, "SubsidiaryAttributeWarehouses");
	
EndProcedure

&AtClient
Procedure DisableAllCompanies(Command)
	
	EnableDisableAllItemsInTable(False, "CompanySubsidiaryAttribute");
	
EndProcedure

&AtClient
Procedure DisableAllWarehouses(Command)
	
	EnableDisableAllItemsInTable(False, "SubsidiaryAttributeWarehouses");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure WriteAndCloseOnServer()
	
	UseCompaniesFilter =
		(CompanySubsidiaryAttributeSynchronizationMode = "SynchronizeDataBySelectedCompaniesOnly")
	;
	
	UseFilterByWarehouses =
		(SubsidiaryAttributeWarehousesSyncMode = "SynchronizeDataOnlyInSelectedWarehouses")
	;
	
	If UseCompaniesFilter Then
		
		Companies.Load(CompanySubsidiaryAttribute.Unload(New Structure("Use", True), "Company"));
		
	Else
		
		Companies.Clear();
		
	EndIf;
	
	
	If UseFilterByWarehouses Then
		
		Warehouses.Load(SubsidiaryAttributeWarehouses.Unload(New Structure("Use", True), "Warehouse"));
		
	Else
		
		Warehouses.Clear();
		
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
	GenerateTableTitleWarehouses();
	
EndProcedure

&AtClient
Procedure SynchronizationModeCompanyOnValueChange()
	
	Items.CompanySubsidiaryAttribute.Visible =
		(CompanySubsidiaryAttributeSynchronizationMode = "SynchronizeDataBySelectedCompaniesOnly")
	;
	
	GenerateCompanyTableTitle();
	
EndProcedure

&AtClient
Procedure WarehousesSyncModeOnChangeValue()
	
	Items.SubsidiaryAttributeWarehouses.Visible =
		(SubsidiaryAttributeWarehousesSyncMode = "SynchronizeDataOnlyInSelectedWarehouses")
	;
	
	GenerateTableTitleWarehouses();
	
EndProcedure

&AtServer
Function AllCompaniesAddition()
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT
	|	FALSE AS Use,
	|	Companies.Ref AS Company
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	Not Companies.DeletionMark
	|
	|ORDER BY
	|	Companies.Description";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Return Query.Execute().Unload();
EndFunction

&AtServer
Function AllApplicationWarehouses()
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT
    |   FALSE AS Use,
    |   StructuralUnits.Ref AS Warehouse
    |FROM
    |   Catalog.StructuralUnits AS StructuralUnits
    |WHERE
    |   Not StructuralUnits.DeletionMark
    |   AND StructuralUnits.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
    |
    |ORDER BY
    |   StructuralUnits.Description";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Return Query.Execute().Unload();
EndFunction

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
		
		PageTitle = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='By companies (%1)';ru='По организациям (%1)'"),
			SelectedRowsQuantity("CompanySubsidiaryAttribute")
		);
	Else
		
		PageTitle = NStr("en='By all companies';ru='по всем организациям'");
	EndIf;
	
	Items.CompaniesPage.Title = PageTitle;
	
EndProcedure

&AtClient
Procedure GenerateTableTitleWarehouses()
	
	If SubsidiaryAttributeWarehousesSyncMode = "SynchronizeDataOnlyInSelectedWarehouses" Then
		
		PageTitle = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='By warehouses (%1)';ru='По складам (%1)'"),
			SelectedRowsQuantity("SubsidiaryAttributeWarehouses")
		);
	Else
		
		PageTitle = NStr("en='In all warehouses';ru='По всем складам'");
	EndIf;
	
	Items.WarehousesPage.Title = PageTitle;
	
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
