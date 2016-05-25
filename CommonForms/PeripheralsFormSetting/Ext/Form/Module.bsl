////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

//////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure CatalogPeripherals(Command)
	
	If Modified Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Data is not written yet! You can start editing the ""Companies"" catalog only after the data is written!'");
		Message.Message();
		Return;
	EndIf;
	
	EquipmentManagerClient.RefreshClientWorkplace();
	OpenForm("Catalog.Peripherals.ListForm");
	
EndProcedure // CatalogCompanies()

&AtClient
Procedure OpenExchangeRulesWithPeripherals(Command)
	
	If Modified Then
		Mode = QuestionDialogMode.YesNo;
		MessageText = NStr("en = 'Data is not written yet! You can go to settings only after the data is written! Record?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("OpenExchangeRulesWithPeripheralsEnd", ThisObject), MessageText, Mode, 0);
        Return;
	EndIf;
	
	OpenExchangeRulesWithPeripheralsFragment();
EndProcedure

&AtClient
Procedure OpenExchangeRulesWithPeripheralsEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Write();
    Else
        Return;
    EndIf;
    
    OpenExchangeRulesWithPeripheralsFragment();

EndProcedure

&AtClient
Procedure OpenExchangeRulesWithPeripheralsFragment()
    
    RefreshInterface();
    OpenForm("Catalog.ExchangeWithPeripheralsOfflineRules.ListForm", , ThisForm);

EndProcedure

&AtClient
Procedure OpenWorkplaces(Command)
	
	OpenForm("Catalog.Workplaces.ListForm", , ThisForm);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.OpenExchangeRulesWithPeripherals.Enabled = ConstantsSet.UseExchangeWithPeripheralsOffline;
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler AfterWrite form.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	RefreshInterface();
	
EndProcedure // AfterWrite()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
Procedure FunctionalOptionUseExchangeWithPeripheralsOfflineOnChange(Item)
	
	Items.OpenExchangeRulesWithPeripherals.Enabled = ConstantsSet.UseExchangeWithPeripheralsOffline;
	
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
