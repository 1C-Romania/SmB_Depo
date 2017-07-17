&AtClient
Var RefreshInterface;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	// Visible settings on launch.
	
	// StandardSubsystems.MarkedObjectDeletion
	If Not RunMode.SaaS AND RunMode.ThisIsSystemAdministrator Then
		ScheduledJob = ScheduledJobsFindPredefined("DeleteMarked");
		If ScheduledJob <> Undefined Then
			DeleteMarkedID = ScheduledJob.UUID;
			DeleteMarkedUse = ScheduledJob.Use;
			DeleteMarkedSchedule    = ScheduledJob.Schedule;
		Else
			Items.GroupMarkedObjectDeletionOnSchedule.Visible = False;
		EndIf;
	Else
		Items.GroupMarkedObjectDeletionOnSchedule.Visible = False;
	EndIf;
	// End StandardSubsystems.MarkedObjectDeletion
	
	
	// StandardSubsystems.ScheduledJobs
	Items.DataProcessorScheduledAndBackgroundJobs.Visible = RunMode.ThisIsSystemAdministrator;
	// End StandardSubsystems.ScheduledJobs
	
	// StandardSubsystems.TotalAndAggregateManagement
	Items.DataProcessorManagingTotalsAndAggregatesOpen.Visible = RunMode.IsApplicationAdministrator;
	// End StandardSubsystems.TotalAndAggregateManagement
	
	// StandardSubsystems.FullTextSearch
	Items.FullTextSearchAndTextsExtractionManagement.Visible = RunMode.ThisIsSystemAdministrator;
	// End StandardSubsystems.FullTextSearch
	
	// StandardSubsystems.InfobaseBackup
	BackupSupportSaaS = True;
	// StandardSubsystems.SaaS.DataAreasBackup
	BackupSupportSaaS = DataAreasBackup.BackupInUse();
	// End StandardSubsystems.SaaS.DataAreasBackup
	Items.GroupBackupAndRecovery.Visible        = ((RunMode.Local Or RunMode.Standalone) AND RunMode.ThisIsSystemAdministrator
		AND Not RunMode.ThisIsWebClient) OR (RunMode.SaaS AND RunMode.IsApplicationAdministrator AND BackupSupportSaaS);
	RefreshSettingsBackup();
	Items.RecoveryFromBackup.Visible               = (RunMode.Local Or RunMode.Standalone) AND RunMode.ThisIsSystemAdministrator;
	Items.GroupRestorationBackupCopiesSaaS.Visible = RunMode.SaaS AND RunMode.IsApplicationAdministrator 
		AND BackupSupportSaaS;
	// End StandardSubsystems.IBBackup
	
	Items.GroupClassifiers.Visible = RunMode.Local Or RunMode.Standalone;
	
	// StandardSubsystems.AddressClassifier
	GroupVisible = RunMode.Local Or RunMode.Standalone;
	Items.GroupAddressClassifierSettings.Visible = GroupVisible;
	Items.GroupAddressCommandClassifier.Visible   = GroupVisible;
	// End StandardSubsystems.AddressClassifier
	
	// StandardSubsystems.Currencies
	Items.DataProcessorCurrencyRatesImportProcess.Visible = RunMode.Local;
	// End StandardSubsystems.Currencies
	
	// StandardSubsystems.ConfigurationUpdate
	Items.DataProcessorConfigurationUpdate.Visible = RunMode.Local AND RunMode.ThisIsSystemAdministrator AND Not RunMode.IsLinuxClient;
	Items.ApplicationUpdateSetup.Visible = RunMode.Local AND RunMode.ThisIsSystemAdministrator AND Not RunMode.IsLinuxClient;
	UpdateConfigurationUpdateSettings();
	// End StandardSubsystems.ConfigurationUpdate
	
	// StandardSubsystems.InfobaseVersionUpdate
	Items.DetailInfobaseUpdateInEventLogMonitor.Visible = RunMode.ThisIsSystemAdministrator;
	// End StandardSubsystems.IBVersionUpdate
	
	// Items state update.
	SetEnabled();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.InfobaseBackup
	If EventName = "BackupSettingsSessionFormClosed" Then
		RefreshSettingsBackup();
	EndIf;
	// End StandardSubsystems.IBBackup
	
	// StandardSubsystems.ConfigurationUpdate
	If EventName = "ConfigurationUpdateSettingFormIsClosed" Then
		UpdateConfigurationUpdateSettings();
	EndIf;
	// End StandardSubsystems.ConfigurationUpdate
	
	// SB. OnlineUserSupport
	If EventName = "CheckOnlineSupportParametersFormOpening" Then
		If TypeOf(Parameter) = Type("Structure") AND Parameter.Property("FormIsOpened") Then
			Parameter.FormIsOpened = IsOpen();
		EndIf;
	EndIf;
	// SB. End OnlineUserSupport
	
EndProcedure

&AtClient
Procedure OnClose()
	RefreshApplicationInterface();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

// StandardSubsystems.BasicFunctionality
&AtClient
Procedure DeleteMarkedUseOnChange(Item)
	ScheduledJobsUseOnChange("DeleteMarked");
EndProcedure
// End of StandardSubsystems BasicFunctionality

// StandardSubsystems.InfobaseBackup
&AtClient
Procedure ApplicationBackupClick(Item)
	
	// StandardSubsystems.SaaS.DataAreasBackup
	If RunMode.SaaS Then
		OpenForm("CommonForm.BackupCreation", , ThisObject);
		Return;
	EndIf;
	// End StandardSubsystems.SaaS.DataAreasBackup
	
	OpenForm("DataProcessor.InfobaseBackup.Form", , ThisObject);
	
EndProcedure

&AtClient
Procedure BackupSettingClick(Item)
	
	// StandardSubsystems.SaaS.DataAreasBackup
	If RunMode.SaaS Then
		OpenForm("DataProcessor.ApplicationBackupSetting.Form", , ThisObject);
		Return;
	EndIf;
	// End StandardSubsystems.SaaS.DataAreasBackup
	
	OpenForm(InfobaseBackupClient.BackupSettingsFormName(),, ThisObject);
	
EndProcedure

&AtClient
Procedure RestoringFromBackupClick(Item)
	
	OpenForm("DataProcessor.InfobaseBackup.Form.RestoreDataFromBackup", , ThisObject);
	
EndProcedure
// End StandardSubsystems.IBBackup

// StandardSubsystems.InfobaseVersionUpdate
&AtClient
Procedure DetailInfobaseUpdateInEventLogMonitorOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure GroupInternetSupportConnectionExtendedTooltipDataProcessorNavigationRefs(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	OnlineUserSupportClient.OpenInternetPage(
		"https://1c-dn.com/user/profile/",
		NStr("en='Support users of 1C:Enterprise 8';ru='Поддержка пользователей системы 1С:Предприятие 8'"));
	
EndProcedure
// SB. End OnlineUserSupport

#EndRegion

#Region FormCommandsHandlers

// StandardSubsystems.AddressClassifier
&AtClient
Procedure AddressClassifierOnChange(Item)
	
	Attachable_OnAttributeChange(Item, False);
	
EndProcedure
// End StandardSubsystems.AddressClassifier

// StandardSubsystems.BasicFunctionality
&AtClient
Procedure DeleteMarkedConfigureSchedule(Command)
	ScheduledJobsClickHyperlink("DeleteMarked");
EndProcedure
// End of StandardSubsystems BasicFunctionality

// StandardSubsystems.BasicFunctionality
&AtClient
Procedure SearchAndDeleteDuplicates(Command)
	
	OpenForm("DataProcessor.SearchAndDeleteDuplicates.Form.SearchDuplicates");
	
EndProcedure
// End of StandardSubsystems BasicFunctionality

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure AdditionalReportsOnAdministration(Command)
	ParametersForm = New Structure;
	ParametersForm.Insert("SectionName", "SetupAndAdministration");
	ParametersForm.Insert("DestinationObjects", New ValueList);
	ParametersForm.Insert("Kind", AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalReport());
	ParametersForm.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	ParametersForm.Insert("Title", NStr("en='Additional administration reports';ru='Дополнительные отчеты по администрированию'"));
	OpenForm("CommonForm.AdditionalReportsAndDataProcessors", ParametersForm, ThisObject);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure AdditionalAdministrativeDataProcessors(Command)
	ParametersForm = New Structure;
	ParametersForm.Insert("SectionName", "SetupAndAdministration");
	ParametersForm.Insert("DestinationObjects", New ValueList);
	ParametersForm.Insert("Kind", AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalInformationProcessor());
	ParametersForm.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	ParametersForm.Insert("Title", NStr("en='Additional data processors for administration';ru='Дополнительные обработки по администрированию'"));
	OpenForm("CommonForm.AdditionalReportsAndDataProcessors", ParametersForm, ThisObject);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Currencies
&AtClient
Procedure DataProcessorCurrencyRatesImportProcess(Command)
	
	OpenForm("DataProcessor.CurrencyRatesImportProcess.Form");
	
EndProcedure
// End StandardSubsystems.Currencies

// StandardSubsystems.FullTextSearch
&AtClient
Procedure ProcessingManagingFullTextSearch(Command)
	
	OpenForm("DataProcessor.AdministrationPanelSSL.Form.FullTextSearchAndTextsExtractionManagement", , ThisObject);
	
EndProcedure
// End StandardSubsystems.FullTextSearch

// StandardSubsystems.InfobaseVersionUpdate
&AtClient
Procedure PostponedProcessingData(Command)
	FormParameters = New Structure("OpenFromAdministrationPanel", True);
	OpenForm("DataProcessor.InfobaseUpdate.Form.InfobaseDelayedUpdateProgressIndication", FormParameters);
EndProcedure
// End StandardSubsystems.IBVersionUpdate

// StandardSubsystems.ConfigurationUpdate
&AtClient
Procedure ApplicationUpdateSetup(Command)
	
	OpenForm("DataProcessor.ConfigurationUpdate.Form.ScheduleSetup");
	
EndProcedure
// End StandardSubsystems.ConfigurationUpdate

// ServiceTechnology.InformationCenter
//
&AtClient 
Procedure InformationAndSupport(Command)
	
	OpenForm("DataProcessor.InformationCenter.Form.InformationCenter");
	
EndProcedure // InformationAndSupport()

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If RefreshingInterface Then
		RefreshInterface = True;
		#If Not WebClient Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		#EndIf
	EndIf;
	
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	#If Not WebClient Then
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	#EndIf
	
EndProcedure

&AtClient
Procedure ScheduledJobsUseOnChange(AttributePrefix)
	AttributeNameUse = AttributePrefix + "Use";
	ID = ThisObject[AttributePrefix + "ID"];
	If ThisObject[AttributeNameUse] Then
		ExecuteParameters = New Structure;
		ExecuteParameters.Insert("ID", ID);
		ExecuteParameters.Insert("AttributeNameSchedule", AttributePrefix + "Schedule");
		ExecuteParameters.Insert("AttributeNameUse", AttributeNameUse);
		
		ScheduledJobsChangeSchedule(ExecuteParameters);
	Else
		Changes = New Structure("Use", False);
		ScheduledJobsSave(ID, Changes, AttributeNameUse);
	EndIf;
EndProcedure

&AtClient
Procedure ScheduledJobsClickHyperlink(AttributePrefix)
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ID", ThisObject[AttributePrefix + "ID"]);
	ExecuteParameters.Insert("AttributeNameSchedule", AttributePrefix + "Schedule");
	
	ScheduledJobsChangeSchedule(ExecuteParameters);
EndProcedure

&AtClient
Procedure ScheduledJobsChangeSchedule(ExecuteParameters)
	Handler = New NotifyDescription("ScheduledJobsAfterScheduleChange", ThisObject, ExecuteParameters);
	Dialog = New ScheduledJobDialog(ThisObject[ExecuteParameters.AttributeNameSchedule]);
	Dialog.Show(Handler);
EndProcedure

&AtClient
Procedure ScheduledJobsAfterScheduleChange(Schedule, ExecuteParameters) Export
	If Schedule = Undefined Then
		If ExecuteParameters.Property("AttributeNameUse") Then
			ThisObject[ExecuteParameters.AttributeNameUse] = False;
		EndIf;
		Return;
	EndIf;
	
	ThisObject[ExecuteParameters.AttributeNameSchedule] = Schedule;
	
	Changes = New Structure("Schedule", Schedule);
	If ExecuteParameters.Property("AttributeNameUse") Then
		ThisObject[ExecuteParameters.AttributeNameUse] = True;
		Changes.Insert("Use", True);
	EndIf;
	ScheduledJobsSave(ExecuteParameters.ID, Changes, ExecuteParameters.AttributeNameSchedule);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Calling the server

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

&AtServer
Procedure ScheduledJobsSave(UUID, Changes, AttributePathToData)
	ScheduledJob = ScheduledJobs.FindByUUID(UUID);
	FillPropertyValues(ScheduledJob, Changes);
	ScheduledJob.Write();
	
	If AttributePathToData <> Undefined Then
		SetEnabled(AttributePathToData);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values, not connected with constants directly.
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// It is used for these form attributes, which connected with constants directly.
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		StandardSubsystemsClientServer.ExecutionResultAddNotificationOfOpenForms(Result, "Record_ConstantsSet", New Structure, ConstantName);
		// StandardSubsystems.ReportsVariants
		ReportsVariants.AddNotificationOnValueChangeConstants(Result, ConstantManager);
		// End StandardSubsystems.ReportsVariants
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If RunMode.ThisIsSystemAdministrator Then
		
		// StandardSubsystems.BasicFunctionality
		If AttributePathToData = "DeleteMarkedSchedule" OR AttributePathToData = "DeleteMarkedUse" OR AttributePathToData = "" Then
			
			Items.DeleteMarkedConfigureSchedule.Enabled = DeleteMarkedUse;
			If DeleteMarkedUse Then
				
				SchedulePresentation = String(DeleteMarkedSchedule);
				Presentation = Upper(Left(SchedulePresentation, 1)) + Mid(SchedulePresentation, 2);
				
			Else
				
				Presentation = NStr("en='<Disabled>';ru='<Отключен>'");
				
			EndIf;
			
			ThisObject.Items.DeleteMarkedConfigureSchedule.ExtendedTooltip.Title = Presentation;
			
		EndIf;
		// End of StandardSubsystems BasicFunctionality
		
	EndIf;
	
	// StandardSubsystems.AddressClassifier
	If AttributePathToData = "ConstantsSet.AddressClassifierDataSource" Or AttributePathToData = "" Then
	 
		Items.GroupAddressCommandClassifier.Enabled = IsBlankString(ConstantsSet.AddressClassifierDataSource);
		
	EndIf 
	// End StandardSubsystems.AddressClassifier
	
EndProcedure

// StandardSubsystems.InfobaseBackup
&AtServer
Procedure RefreshSettingsBackup()
	
	If (RunMode.Local Or RunMode.Standalone) AND RunMode.ThisIsSystemAdministrator Then
		ThisObject.Items.BackupSetup.ExtendedTooltip.Title = InfobaseBackupServer.CurrentBackupSetting();
	EndIf;
	
EndProcedure
// End StandardSubsystems.IBBackup

// StandardSubsystems.ConfigurationUpdate
&AtServer
Procedure UpdateConfigurationUpdateSettings()
	
	ConfigurationUpdateOptions = ConfigurationUpdate.GetSettingsStructureOfAssistant();
	
	ApplicationTitleUpdates = NStr("en='Auto check for updates is disabled.';ru='Автоматическая проверка обновлений отключена.'");
	If ConfigurationUpdateOptions.CheckUpdateExistsOnStart = 2 Then
		ApplicationTitleUpdates = NStr("en='Updates are checked automatically every time the application starts.';ru='Автоматическая проверка обновлений выполняется при каждом запуске программы.'");
	ElsIf ConfigurationUpdateOptions.CheckUpdateExistsOnStart = 1 Then
		ApplicationTitleUpdates = NStr("en='Updates are checked automatically on schedule: %1.';ru='Автоматическая проверка обновлений выполняется по расписанию: %1.'");
		Schedule = CommonUseClientServer.StructureIntoSchedule(ConfigurationUpdateOptions.ScheduleOfUpdateExistsCheck);
		ApplicationTitleUpdates = StringFunctionsClientServer.SubstituteParametersInString(ApplicationTitleUpdates, Schedule);
	EndIf;
	
	ThisObject.Items.ApplicationUpdateSetup.ExtendedTooltip.Title = ApplicationTitleUpdates;
	
EndProcedure
// End StandardSubsystems.ConfigurationUpdate

&AtServer
Function ScheduledJobsFindPredefined(PredefinedName)
	PredefinedMetadata = Metadata.ScheduledJobs.Find(PredefinedName);
	If PredefinedMetadata = Undefined Then
		Return Undefined;
	Else
		Return ScheduledJobs.FindPredefined(PredefinedMetadata);
	EndIf;
EndFunction

#EndRegion
