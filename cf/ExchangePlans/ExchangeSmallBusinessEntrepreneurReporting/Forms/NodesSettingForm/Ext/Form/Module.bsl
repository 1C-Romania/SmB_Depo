//////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DataExchangeServer.NodesSettingFormOnCreateAtServer(ThisForm, Cancel);
	
	If Not ValueIsFilled(DocumentsDumpStartDate) Then
		DocumentsDumpStartDate = BegOfYear(CurrentSessionDate());
	EndIf;
	
	CompaniesSyncMode =
		?(UseCompaniesFilter, "SynchronizeDataBySelectedCompaniesOnly", "SynchronizeDataByAllCompanies")
	;
	
	GetContextDetails();
	
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
// FORM COMMAND HANDLERS

&AtClient
Procedure WriteAndClose(Command)
	
	UseCompaniesFilter =
		(CompaniesSyncMode = "SynchronizeDataBySelectedCompaniesOnly")
	;
	
	If Not UseCompaniesFilter Then
		Companies.Clear();
	EndIf;
	
	GetContextDetails();
	
	DataExchangeClient.SetupOfNodesFormCloseFormCommand(ThisForm);
	
EndProcedure

&AtClient
Procedure EnableAllCompanies(Command)
	
	EnableDisableAllItemsInTable(True, "Companies");
	
EndProcedure

&AtClient
Procedure DisableAllCompanies(Command)
	
	EnableDisableAllItemsInTable(False, "Companies");
	
EndProcedure

&AtClient
Procedure SynchronizationModeCompanyOnChange(Item)
	
	SynchronizationModeCompanyOnValueChange();
	
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
Procedure GetContextDetails()
	
	// Document export start date
	If ValueIsFilled(DocumentsDumpStartDate) Then
		DocumentsDumpStartDateDetails = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Data will be synchronized, starting from %1';ru='Данные будут синхронизироваться, начиная с %1'"),
			Format(DocumentsDumpStartDate, "DLF=DD")
		);
	Else
		DocumentsDumpStartDateDetails = NStr("en='Data will be synchronized for all the period of the accounting in the applications';ru='Данные будут синхронизироваться за весь период ведения учета в программах'");
	EndIf;
	
	// filter by Companies
	If UseCompaniesFilter Then
		CompanyDescription = NStr("en='Only by companies:';ru='Только по организациям:'") + Chars.LF + UsedItems("Companies");
	Else
		CompanyDescription = NStr("en='By all companies.';ru='По всем организациям.'");
	EndIf;
	
	ContextDetails = (""
		+ DocumentsDumpStartDateDetails
		+ Chars.LF
		+ Chars.LF
		+ CompanyDescription
	);
	
EndProcedure

&AtServer
Function UsedItems(TableName)
	
	Return StringFunctionsClientServer.GetStringFromSubstringArray(
			ThisForm[TableName].Unload(New Structure("Use", True)).UnloadColumn("Presentation"),
			Chars.LF
	);
	
EndFunction

&AtClient
Procedure SynchronizationModeCompanyOnValueChange()
	
	Items.Companies.Enabled =
		(CompaniesSyncMode = "SynchronizeDataBySelectedCompaniesOnly")
	;
	
EndProcedure



