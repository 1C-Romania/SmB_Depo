////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	CompaniesSyncMode =
		?(Object.UseCompaniesFilter, "SynchronizeDataBySelectedCompaniesOnly", "SynchronizeDataByAllCompanies");
	
	WarehousesSyncMode =
		?(Object.UseFilterByWarehouses, "SynchronizeDataOnlyInSelectedWarehouses", "SynchronizeDataInAllWarehouses");
	
	Companies.Load(AllCompaniesAddition());
	Warehouses.Load(AllApplicationWarehouses());
	
	CancelSelectedTableItems("Companies", "Company");
	CancelSelectedTableItems("Warehouses", "Warehouse");
		
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SynchronizationModeCompanyOnValueChange();
    WarehousesSyncModeOnChangeValue();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.UseCompaniesFilter =
		(CompaniesSyncMode = "SynchronizeDataBySelectedCompaniesOnly")
	;
	
	CurrentObject.UseFilterByWarehouses =
		(WarehousesSyncMode = "SynchronizeDataOnlyInSelectedWarehouses")
	;
	
	If CurrentObject.UseCompaniesFilter Then
		
		CurrentObject.Companies.Load(Companies.Unload(New Structure("Use", True), "Company"));
		
	Else
		
		CurrentObject.Companies.Clear();
		
	EndIf;
	
	If CurrentObject.UseFilterByWarehouses Then
		
		CurrentObject.Warehouses.Load(Warehouses.Unload(New Structure("Use", True), "Warehouse"));
		
	Else
		
		CurrentObject.Warehouses.Clear();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_ExchangePlanNode");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// HANDLERS OF THE FORM COMMANDS EVENTS

&AtClient
Procedure SynchronizationModeCompanyOnChange(Item)
	
	SynchronizationModeCompanyOnValueChange();
	
EndProcedure

&AtClient
Procedure WarehousesSyncModeOnChange(Item)
	
	WarehousesSyncModeOnChangeValue();
	
EndProcedure

&AtClient
Procedure EnableAllCompanies(Command)
	
	EnableDisableAllItemsInTable(True, "Companies");
	
EndProcedure

&AtClient
Procedure EnableAllWarehouses(Command)
	
	EnableDisableAllItemsInTable(True, "Warehouses");
	
EndProcedure

&AtClient
Procedure DisableAllCompanies(Command)
	
	EnableDisableAllItemsInTable(False, "Companies");
	
EndProcedure

&AtClient
Procedure DisableAllWarehouses(Command)
	
	EnableDisableAllItemsInTable(False, "Warehouses");
	
EndProcedure

&AtClient
Procedure CompaniesUseOnChange(Item)
	
	GenerateCompanyTableTitle();
	
EndProcedure

&AtClient
Procedure WarehousesUseOnChange(Item)
	
	GenerateTableTitleWarehouses();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure SynchronizationModeCompanyOnValueChange()
	
	Items.Companies.Enabled =
		(CompaniesSyncMode = "SynchronizeDataBySelectedCompaniesOnly")
	;
	
	GenerateCompanyTableTitle();
	
EndProcedure

&AtClient
Procedure WarehousesSyncModeOnChangeValue()
	
	Items.Warehouses.Enabled =
		(WarehousesSyncMode = "SynchronizeDataOnlyInSelectedWarehouses")
	;
	
	GenerateTableTitleWarehouses();
	
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
Procedure GenerateCompanyTableTitle()
	
	CompaniesCount = SelectedRowsQuantity("Companies");
	If CompaniesCount > 0 Then
		LabelTitle = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en = 'By the selected companies (%1):'"),
			CompaniesCount);
	Else
		LabelTitle = NStr("en = 'In selected companies:'");
	EndIf;
	Items.CompaniesSyncMode.ChoiceList[1].Presentation = LabelTitle;
	
EndProcedure

&AtClient
Procedure GenerateTableTitleWarehouses()
	
	WarehousesQuantity = SelectedRowsQuantity("Warehouses");
	If WarehousesQuantity > 0 Then
		LabelTitle = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en = 'By the selected warehouses (%1)'"),
			WarehousesQuantity);
	Else
		LabelTitle = NStr("en = 'In selected warehouses:'");
	EndIf;
	Items.WarehousesSyncMode.ChoiceList[1].Presentation = LabelTitle;
	
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
Procedure CancelSelectedTableItems(TableName, AttributeName)
	
	For Each TableRow IN Object[TableName] Do
		
		Rows = ThisForm[TableName].FindRows(New Structure(AttributeName, TableRow[AttributeName]));
		
		If Rows.Count() > 0 Then
			
			Rows[0].Use = True;
			
			
		EndIf;
		
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
