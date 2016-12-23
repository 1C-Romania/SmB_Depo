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
	
	ShowUserNotification(NStr("en='Rules update has been successfully completed.';ru='Обновление правил успешно завершено.'"));
	
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
	ShowUserNotification(NStr("en='Rules update has been successfully completed.';ru='Обновление правил успешно завершено.'"));
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














