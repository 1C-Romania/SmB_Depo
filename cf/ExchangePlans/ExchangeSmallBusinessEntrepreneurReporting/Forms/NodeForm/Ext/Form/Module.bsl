// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
		
		Items.Office.Visible 			 = False;
		Items.Office.Enabled			 = False;
		
	EndIf;
	
	CompaniesSyncMode =
		?(Object.UseCompaniesFilter, "SynchronizeDataBySelectedCompaniesOnly", "SynchronizeDataByAllCompanies")
	;
	
	Companies.Load(AllCompaniesAddition());
	
	CancelSelectedTableItems("Companies", "Company");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SynchronizationModeCompanyOnValueChange();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.UseCompaniesFilter =
		(CompaniesSyncMode = "SynchronizeDataBySelectedCompaniesOnly")
	;
	
	If CurrentObject.UseCompaniesFilter Then
		
		CurrentObject.Companies.Load(Companies.Unload(New Structure("Use", True), "Company"));
		
	Else
		
		CurrentObject.Companies.Clear();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	Notify("NodeExchangePlanFormClosed");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure EnableAllCompanies(Command)
	
	EnableDisableAllItemsInTable(True, "Companies");
	
EndProcedure

&AtClient
Procedure DisableAllCompanies(Command)
	
	EnableDisableAllItemsInTable(False, "Companies");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure EnableDisableAllItemsInTable(Enable, TableName)
	
	For Each CollectionItem IN ThisForm[TableName] Do
		
		CollectionItem.Use = Enable;
		
	EndDo;
	
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
Procedure CancelSelectedTableItems(TableName, AttributeName)
	
	For Each TableRow IN Object[TableName] Do
		
		Rows = ThisForm[TableName].FindRows(New Structure(AttributeName, TableRow[AttributeName]));
		
		If Rows.Count() > 0 Then
			
			Rows[0].Use = True;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SynchronizationModeCompanyOnChange(Item)
	
	SynchronizationModeCompanyOnValueChange();
	
EndProcedure

&AtClient
Procedure SynchronizationModeCompanyOnValueChange()
	
	Items.Companies.Enabled =
		(CompaniesSyncMode = "SynchronizeDataBySelectedCompaniesOnly")
	;
	
EndProcedure














