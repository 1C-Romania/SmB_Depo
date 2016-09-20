
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	If Not CommonUse.OnCreateAtServer(ThisObject, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not OfflineWorkService.ThisIsOfflineWorkplace() Then
		Raise NStr("en='This infobase is not an offline workplace.';ru='Эта информационная база не является автономным рабочим местом.'");
	EndIf;
	
	ApplicationInService = OfflineWorkService.ApplicationInService();
	
	ScheduledJob = ScheduledJobsServer.GetScheduledJob(
		Metadata.ScheduledJobs.DataSynchronizationWithApplicationInInternet);
	
	SynchronizeDataBySchedule = ScheduledJob.Use;
	DataSynchronizationSchedule      = ScheduledJob.Schedule;
	
	OnChangeScheduleDataSynchronization();
	
	SynchronizeDataOnApplicationStart = Constants.SynchronizeDataWithApplicationInInternetOnApplicationStart.Get();
	SynchronizeDataOnApplicationExit = Constants.SynchronizeDataWithApplicationInInternetOnApplicationEnd.Get();
	
	AddressForAccountPasswordRecovery = OfflineWorkService.AddressForAccountPasswordRecovery();
	
	SetPrivilegedMode(False);
	
	RefreshVisibleAtServer();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("RefreshVisible", 60);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "DataExchangeCompleted" Then
		RefreshVisible();
		
	ElsIf EventName = "UserSettingsChanged" Then
		RefreshVisible();
		
	ElsIf EventName = "Record_SetUpTransportExchange" Then
		
		If Parameter.Property("AutomaticSynchronizationSetting") Then
			SynchronizeDataBySchedule = True;
			SynchronizedataOnScheduleWhenChangingValues();
		EndIf;
		
	ElsIf EventName = "ClosedFormDataExchangeResults" Then
		UpdateTransitionToConflictsTitle();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowSynchronizationLongTimeWarningOnChange(Item)
	
	SwitchWarningAboutLongSynchronization(ShowSynchronizationLongTimeWarning);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ExecuteDataSynchronization(Command)
	
	DataExchangeClient.ExecuteDataExchangeCommandProcessing(ApplicationInService, ThisObject, AddressForAccountPasswordRecovery);
	
EndProcedure

&AtClient
Procedure ChangeDataSynchronizationSchedule(Command)
	
	Dialog = New ScheduledJobDialog(DataSynchronizationSchedule);
	NotifyDescription = New NotifyDescription("ChangeScheduleDataSynchronizationEnd", ThisObject);
	Dialog.Show(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure ChangeScheduleDataSynchronizationEnd(Schedule, AdditionalParameters)
	
	If Schedule <> Undefined Then
		
		DataSynchronizationSchedule = Schedule;
		
		ChangeDataSynchronizationScheduleOnServer();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InstallUpdate(Command)
	
	DataExchangeClient.SetConfigurationUpdate();
	
EndProcedure

&AtClient
Procedure SynchronizedataOnScheduleWhenChanging(Item)
	
	If SynchronizeDataBySchedule AND Not UserPasswordIsSaving Then
		
		SynchronizeDataBySchedule = False;
		
		CustomizeConnectionToService(True);
		
	Else
		
		SynchronizedataOnScheduleWhenChangingValues();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DataSynchronizationScheduleVariantOnChange(Item)
	
	DataSynchronizationScheduleVariantOnChangeOnServer();
	
EndProcedure

&AtClient
Procedure SynchronizeDataOnApplicationStartOnChange(Item)
	
	SetValueOfConstant_SynchronizeDataWithApplicationInInternetOnApplicationStart(
		SynchronizeDataOnApplicationStart);
EndProcedure

&AtClient
Procedure SynchronizeDataOnApplicationEndOnChange(Item)
	
	SetValueOfConstant_SynchronizeDataWithApplicationInInternetOnApplicationEnd(
		SynchronizeDataOnApplicationExit);
		
	ParameterName = "StandardSubsystems.OfferToSynchronizeDataWithApplicationOnTheInternetOnSessionExit";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;

	ApplicationParameters["StandardSubsystems.OfferToSynchronizeDataWithApplicationOnTheInternetOnSessionExit"] =
		SynchronizeDataOnApplicationExit;
	
EndProcedure

&AtClient
Procedure CustomizeConnection(Command)
	
	CustomizeConnectionToService();
	
EndProcedure

&AtClient
Procedure GoToConflicts(Command)
	
	ExchangeNodes = New Array;
	ExchangeNodes.Add(ApplicationInService);
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ExchangeNodes", ExchangeNodes);
	OpenForm("InformationRegister.DataExchangeResults.Form.Form", OpenParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure RefreshVisible()
	
	RefreshVisibleAtServer();
	
EndProcedure

&AtServer
Procedure RefreshVisibleAtServer()
	
	SetPrivilegedMode(True);
	
	SynchronizationDatePresentation = DataExchangeServer.SynchronizationDatePresentation(
		OfflineWorkService.LastSuccessfulSynchronizationDate(ApplicationInService));
	Items.InformationAboutLastSynchronization.Title = SynchronizationDatePresentation + ".";
	Items.InformationAboutLastSynchronization1.Title = SynchronizationDatePresentation + ".";
	
	UpdateTransitionToConflictsTitle();
	
	UpdateSettingRequired = DataExchangeServer.UpdateSettingRequired();
	
	Items.OfflineWork.CurrentPage = ?(UpdateSettingRequired,
		Items.ConfigurationUpdateReceived,
		Items.DataSynchronization);
	
	Items.ExecuteDataSynchronization.DefaultButton         = Not UpdateSettingRequired;
	Items.ExecuteDataSynchronization.DefaultControl = Not UpdateSettingRequired;
	
	Items.InstallUpdate.DefaultButton         = UpdateSettingRequired;
	Items.InstallUpdate.DefaultControl = UpdateSettingRequired;
	
	TransportSettingsWS = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(ApplicationInService);
	UserPasswordIsSaving = TransportSettingsWS.WSRememberPassword;
	
	ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.DataSynchronizationWithApplicationInInternet);
	SynchronizeDataBySchedule = ScheduledJob.Use;
	
	Items.CustomizeConnection.Enabled = SynchronizeDataBySchedule;
	Items.DataSynchronizationScheduleVariant.Enabled = SynchronizeDataBySchedule;
	Items.ChangeDataSynchronizationSchedule.Enabled = SynchronizeDataBySchedule;
	
	SetPrivilegedMode(False);
	
	// Set the visible by roles
	IsInRoleSynchronizationSettingData = Users.RolesAvailable("DataSynchronizationSetting");
	Items.DataSynchronizationSetting.Visible = IsInRoleSynchronizationSettingData;
	Items.InstallUpdate.Visible = IsInRoleSynchronizationSettingData;
	
	If IsInRoleSynchronizationSettingData Then
		Items.InformationLabelReceivedRefreshEnabled.Title = NStr("en='Software update has been exported from the Internet.
		|It is necessary to install the received update after which the synchronization will be continued.';ru='Получено обновление программы из Интернета.
		|Необходимо установить полученное обновление, после чего синхронизация будет продолжена.'");
	Else
		Items.InformationLabelReceivedRefreshEnabled.Title = NStr("en='Software update has been exported from the Internet.
		|Contact the infobase administrator to install the received update.';ru='Получено обновление программы из Интернета.
		|Обратитесь к администратору информационной базы для установки полученного обновления.'");
	EndIf;
	
	ShowSynchronizationLongTimeWarning = OfflineWorkService.QuestionAboutLongSynchronizationSettingCheckBox();
EndProcedure

&AtServer
Procedure UpdateTransitionToConflictsTitle()
	
	If DataExchangeReUse.UseVersioning() Then
		
		HeaderStructure = DataExchangeServer.HeaderStructureHyperlinkMonitorProblems(ApplicationInService);
		
		FillPropertyValues (Items.GoToConflicts, HeaderStructure);
		FillPropertyValues (Items.GoToConflicts1, HeaderStructure);
		
	Else
		
		Items.GoToConflicts.Visible = False;
		Items.GoToConflicts1.Visible = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DataSynchronizationScheduleVariantOnChangeOnServer()
	
	NewDataSynchronizationSchedule = "";
	
	If DataSynchronizationScheduleVariant = 1 Then
		
		NewDataSynchronizationSchedule = PredefinedScheduleOption1();
		
	ElsIf DataSynchronizationScheduleVariant = 2 Then
		
		NewDataSynchronizationSchedule = PredefinedScheduleOption2();
		
	ElsIf DataSynchronizationScheduleVariant = 3 Then
		
		NewDataSynchronizationSchedule = PredefinedScheduleOption3();
		
	Else // 4
		
		NewDataSynchronizationSchedule = UserDataSynchronizationSchedule;
		
	EndIf;
	
	If String(DataSynchronizationSchedule) <> String(NewDataSynchronizationSchedule) Then
		
		DataSynchronizationSchedule = NewDataSynchronizationSchedule;
		
		ScheduledJobsServer.SetJobSchedule(
			Metadata.ScheduledJobs.DataSynchronizationWithApplicationInInternet,
			DataSynchronizationSchedule);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SwitchWarningAboutLongSynchronization(Val Flag)
	
	OfflineWorkService.QuestionAboutLongSynchronizationSettingCheckBox(Flag);
	
EndProcedure

&AtServer
Procedure OnChangeScheduleDataSynchronization()
	
	Items.DataSynchronizationScheduleVariant.ChoiceList.Clear();
	Items.DataSynchronizationScheduleVariant.ChoiceList.Add(1, NStr("en='Every 15 minutes';ru='Каждые 15 минут'"));
	Items.DataSynchronizationScheduleVariant.ChoiceList.Add(2, NStr("en='Every hour';ru='Каждый час'"));
	Items.DataSynchronizationScheduleVariant.ChoiceList.Add(3, NStr("en='Each day at 10:00, except Sa and Su';ru='Каждый день в 10:00, кроме сб. и вс.'"));
	
	// Define the current schedule variant of the data synchronization execution
	TypesOfSchedulingDataSynchronization = New Map;
	TypesOfSchedulingDataSynchronization.Insert(String(PredefinedScheduleOption1()), 1);
	TypesOfSchedulingDataSynchronization.Insert(String(PredefinedScheduleOption2()), 2);
	TypesOfSchedulingDataSynchronization.Insert(String(PredefinedScheduleOption3()), 3);
	
	DataSynchronizationScheduleVariant = TypesOfSchedulingDataSynchronization[String(DataSynchronizationSchedule)];
	
	If DataSynchronizationScheduleVariant = 0 Then
		
		DataSynchronizationScheduleVariant = 4;
		Items.DataSynchronizationScheduleVariant.ChoiceList.Add(4, String(DataSynchronizationSchedule));
		UserDataSynchronizationSchedule = DataSynchronizationSchedule;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeDataSynchronizationScheduleOnServer()
	
	ScheduledJobsServer.SetJobSchedule(
		Metadata.ScheduledJobs.DataSynchronizationWithApplicationInInternet,
		DataSynchronizationSchedule);
	
	OnChangeScheduleDataSynchronization();
	
EndProcedure

&AtServerNoContext
Procedure SetValueOfConstant_SynchronizeDataWithApplicationInInternetOnApplicationStart(Val Value)
	
	SetPrivilegedMode(True);
	
	Constants.SynchronizeDataWithApplicationInInternetOnApplicationStart.Set(Value);
	
EndProcedure

&AtServerNoContext
Procedure SetValueOfConstant_SynchronizeDataWithApplicationInInternetOnApplicationEnd(Val Value)
	
	SetPrivilegedMode(True);
	
	Constants.SynchronizeDataWithApplicationInInternetOnApplicationEnd.Set(Value);
	
EndProcedure

&AtClient
Procedure CustomizeConnectionToService(AutomaticSynchronizationSetting = False)
	
	Filter              = New Structure("Node", ApplicationInService);
	FillingValues = New Structure("Node", ApplicationInService);
	FormParameters     = New Structure;
	FormParameters.Insert("AddressForAccountPasswordRecovery", AddressForAccountPasswordRecovery);
	FormParameters.Insert("AutomaticSynchronizationSetting", AutomaticSynchronizationSetting);
	
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "ExchangeTransportSettings",
		ThisObject, "ConnectionToServiceSetting", FormParameters);
	
	RefreshVisibleAtServer();
	
EndProcedure

&AtClient
Procedure SynchronizedataOnScheduleWhenChangingValues()
	
	SetUseScheduledJob(SynchronizeDataBySchedule);
	
	Items.CustomizeConnection.Enabled = SynchronizeDataBySchedule;
	Items.DataSynchronizationScheduleVariant.Enabled = SynchronizeDataBySchedule;
	Items.ChangeDataSynchronizationSchedule.Enabled = SynchronizeDataBySchedule;
	
EndProcedure

&AtServerNoContext
Procedure SetUseScheduledJob(Val SynchronizeDataBySchedule)
	
	ScheduledJobsServer.SetUseScheduledJob(
		Metadata.ScheduledJobs.DataSynchronizationWithApplicationInInternet,
		SynchronizeDataBySchedule);
	
EndProcedure

// Predefined schedules of data synchronization

&AtServerNoContext
Function PredefinedScheduleOption1() // Every 15 minutes
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.Months                   = Months;
	Schedule.WeekDays                = WeekDays;
	Schedule.RepeatPeriodInDay = 60*15; // 15 minutes
	Schedule.DaysRepeatPeriod        = 1; // every day
	
	Return Schedule;
EndFunction

&AtServerNoContext
Function PredefinedScheduleOption2() // Every hour
	
	Return OfflineWorkService.DataSynchronizationScheduleByDefault();
	
EndFunction

&AtServerNoContext
Function PredefinedScheduleOption3() // Each day at 10:00, except Sa and Su
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	
	Schedule = New JobSchedule;
	Schedule.Months            = Months;
	Schedule.WeekDays         = WeekDays;
	Schedule.BeginTime       = Date('00010101100000'); // 10:00
	Schedule.DaysRepeatPeriod = 1; // every day
	
	Return Schedule;
EndFunction

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
