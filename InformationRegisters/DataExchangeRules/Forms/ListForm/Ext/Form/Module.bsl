#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ExchangePlansWithRulesFromFile") Then
		
		Items.RulesSource.Visible = False;
		CommonUseClientServer.SetFilterDynamicListItem(
			List,
			"RulesSource",
			Enums.RuleSourcesForDataExchange.File,
			DataCompositionComparisonType.Equal);
		
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure UpdateAllTypicalRules(Command)
	
	UpdateAllTypicalRulesAtServer();
	Items.List.Refresh();
	
	ShowUserNotification(NStr("en = 'Rules update has been successfully completed.'"));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure UpdateAllTypicalRulesAtServer()
	
	DataExchangeServer.ExecuteUpdateOfDataExchangeRules();
	
	RefreshReusableValues();
	
EndProcedure

&AtClient
Procedure UseStandardRules(Command)
	UseStandardRulesAtServer();
	Items.List.Refresh();
	ShowUserNotification(NStr("en = 'Rules update has been successfully completed.'"));
EndProcedure

&AtServer
Procedure UseStandardRulesAtServer()
	
	For Each Record IN Items.List.SelectedRows Do
		RecordManager = InformationRegisters.DataExchangeRules.CreateRecordManager();
		FillPropertyValues(RecordManager, Record);
		RecordManager.Read();
		RecordManager.RulesSource = Enums.RuleSourcesForDataExchange.ConfigurationTemplate;
		HasErrors = False;
		InformationRegisters.DataExchangeRules.ImportRules(HasErrors, RecordManager);
		If Not HasErrors Then
			RecordManager.Write();
		EndIf;
	EndDo;
	
	DataExchangeServerCall.ResetCacheMechanismForRegistrationOfObjects();
	RefreshReusableValues();
	
EndProcedure

#EndRegion



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
