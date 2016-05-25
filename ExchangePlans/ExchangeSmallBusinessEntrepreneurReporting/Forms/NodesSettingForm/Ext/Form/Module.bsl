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
		DocumentsDumpStartDateDetails = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Data will be synchronized, starting from %1'"),
			Format(DocumentsDumpStartDate, "DLF=DD")
		);
	Else
		DocumentsDumpStartDateDetails = NStr("en = 'Data will be synchronizing for all the period of the accounting in the applications'");
	EndIf;
	
	// filter by Companies
	If UseCompaniesFilter Then
		CompanyDescription = NStr("en = 'Only on the companies:'") + Chars.LF + UsedItems("Companies");
	Else
		CompanyDescription = NStr("en = 'By all companies.'");
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
