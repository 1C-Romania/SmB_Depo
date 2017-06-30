//////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DataExchangeServer.NodeConfigurationFormOnCreateAtServer(ThisForm, "ExchangeSmallBusinessEntrepreneurReporting");
	
	CompaniesSyncMode =
		?(UseCompaniesFilter, "SynchronizeDataBySelectedCompaniesOnly", "SynchronizeDataByAllCompanies")
	;
	
	UsedByCompanies = Companies.Unload();
	Companies.Load(AllCompaniesAddition());
	
	CancelSelectedTableItems(UsedByCompanies);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SynchronizationModeCompanyOnValueChange();
	
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

&AtClient
Procedure WriteAndClose(Command)
	
	UseCompaniesFilter =
		(CompaniesSyncMode = "SynchronizeDataBySelectedCompaniesOnly")
	;
	
	WriteAndCloseServer();
	
	DataExchangeClient.NodeConfigurationFormCommandCloseForm(ThisForm);
	
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

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

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

&AtClient
Procedure EnableDisableAllItemsInTable(Enable, TableName)
	
	For Each CollectionItem IN ThisForm[TableName] Do
		
		CollectionItem.Use = Enable;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure CancelSelectedTableItems(UsedByCompanies)
	
	For Each TableRow IN UsedByCompanies Do
		
		Rows = Companies.FindRows(New Structure("Company", TableRow.Company));
		
		If Rows.Count() > 0 Then
			
			Rows[0].Use = True;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure WriteAndCloseServer()
	
	If UseCompaniesFilter Then
		
		SelectedCompanies = Companies.Unload(New Structure("Use", True), "Company");
		Companies.Load(SelectedCompanies);
		
	Else
		
		Companies.Clear();
		
	EndIf;
	
EndProcedure



