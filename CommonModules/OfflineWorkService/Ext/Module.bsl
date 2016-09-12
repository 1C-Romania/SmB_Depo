////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data exchange in the service model".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Handlers of conditional calls from SSL.

// Declares service events of the DataExchange subsystem:
//
// Server events:
//   DuringDataExport,
//   OnDataImport.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Called at the beginning of the creation of an offline work place by a user.
	// IN the event handlers additional checks of possibility
	// to create offline work place can be implemented (if it is impossible - exception is generated).
	//
	// Syntax:
	// Procedure OnCreateOfflineWorkplace() Export
	//
	ServerEvents.Add("ServiceTechnology.SaaS.DataExchangeSaaS\OnCreatingIndependentWorkingPlace");
	
EndProcedure

// Sets offline work place during the first start.
// Fills in users content and other settings.
// Called before user authorization. Restart may be required.
// 
Function ContinueOfflineWorkplaceSetting(Parameters) Export
	
	If Not NeedToExecuteOfflineWorkplaceSettingAtFirstStart() Then
		Return False;
	EndIf;
		
	Try
		ExecuteConfigurationOfAutonomousWorkWhenYouFirstStart();
		Parameters.Insert("RestartAfterOfflineWorkplaceSettings");
	Except
		ErrorInfo = ErrorInfo();
		
		WriteLogEvent(EventLogMonitorEventCreatingOfflineWorkplace(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo));
		
		Parameters.Insert("OfflineWorkplaceSettingsError",
			BriefErrorDescription(ErrorInfo));
	EndTry;
	
	Return True;
	
EndFunction

// Reads and sets the setting alert on
// continuous synchronization AWP Parameters:
//     ValueOfFlag     - Boolean - set value
//     of the SettingDescription check box - Structure - takes a value to for setting description
//
// For internal use
//
Function QuestionAboutLongSynchronizationSettingCheckBox(ValueOfFlag = Undefined, SettingDetails = Undefined) Export
	SettingDetails = New Structure;
	
	SettingDetails.Insert("ObjectKey",  "ApplicationSettings");
	SettingDetails.Insert("SettingsKey", "ShowAlertOnLongSynchronizationAWP");
	SettingDetails.Insert("Presentation", NStr("en='Show alert on long synchronization';ru='Показывать предупреждение о длительной синхронизации'"));
	
	SettingsDescription = New SettingsDescription;
	FillPropertyValues(SettingsDescription, SettingDetails);
	
	If ValueOfFlag = Undefined Then
		// Read
		Return CommonUse.CommonSettingsStorageImport(SettingsDescription.ObjectKey, SettingsDescription.SettingsKey, True);
	EndIf;
	
	// Record
	CommonUse.CommonSettingsStorageSave(SettingsDescription.ObjectKey, SettingsDescription.SettingsKey, ValueOfFlag, SettingsDescription);
EndFunction

// For internal use
// 
Function AddressForAccountPasswordRecovery() Export
	
	SetPrivilegedMode(True);
	
	Return TrimAll(Constants.AddressForAccountPasswordRecovery.Get());
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS USED ON THE SERVICE SIDE

// For internal use
// 
Procedure CreateOfflineWorkplaceInitialImage(Parameters,
			InitialImageTemporaryStorageAddress,
			InformationAboutSettingPackageTemporaryStorageAddress
	) Export
	
	OfflineWorkplaceCreationAssistant = DataProcessors.OfflineWorkplaceCreationAssistant.Create();
	
	FillPropertyValues(OfflineWorkplaceCreationAssistant, Parameters);
	
	OfflineWorkplaceCreationAssistant.CreateOfflineWorkplaceInitialImage(
				Parameters.FilterSsettingsAtNode,
				Parameters.SelectedUsersSynchronization,
				InitialImageTemporaryStorageAddress,
				InformationAboutSettingPackageTemporaryStorageAddress);
	
EndProcedure

// For internal use
// 
Procedure DeleteOfflineWorkplace(Parameters, StorageAddress) Export
	
	DataExchangeServer.CheckExchangesAdministrationPossibility();
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// ============================ {for compatibility From SSL 2.1.3}
		User = InformationRegisters.InfobasesNodesCommonSettings.UserForDataSynchronization(Parameters.OfflineWorkplace);
		
		If User <> Undefined Then
			
			UserObject = User.GetObject();
			
			If UserObject <> Undefined Then
				
				UserObject.Delete();
				
			EndIf;
			
		EndIf;
		// ============================ {for compatibility From SSL 2.1.3}
		
		OfflineWorkplaceObject = Parameters.OfflineWorkplace.GetObject();
		
		If OfflineWorkplaceObject <> Undefined Then
			
			OfflineWorkplaceObject.Delete();
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// For internal use
// 
Function OfflineWorkSupported() Export
	
	Return DataExchangeReUse.OfflineWorkSupported();
	
EndFunction

// For internal use
// 
Function OfflineWorkplaceCount() Export
	
	QueryText = "
	|SELECT
	|	COUNT(*) AS Count
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS Table
	|WHERE
	|	Table.Ref <> &ApplicationInService
	|	AND Not Table.DeletionMark";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]", OfflineWorkExchangePlan());
	
	Query = New Query;
	Query.SetParameter("ApplicationInService", ApplicationInService());
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.Count;
EndFunction

// For internal use
// 
Function ApplicationInService() Export
	
	SetPrivilegedMode(True);
	
	If DataExchangeServer.MasterNode() <> Undefined Then
		
		Return DataExchangeServer.MasterNode();
		
	Else
		
		Return ExchangePlans[OfflineWorkExchangePlan()].ThisNode();
		
	EndIf;
	
EndFunction

// For internal use
// 
Function OfflineWorkplace() Export
	
	QueryText =
	"SELECT TOP 1
	|	Table.Ref AS OfflineWorkplace
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS Table
	|WHERE
	|	Table.Ref <> &ApplicationInService
	|	AND Not Table.DeletionMark";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]", OfflineWorkExchangePlan());
	
	Query = New Query;
	Query.SetParameter("ApplicationInService", ApplicationInService());
	Query.Text = QueryText;
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	
	Return Selection.OfflineWorkplace;
EndFunction

// For internal use
// 
Function OfflineWorkExchangePlan() Export
	
	Return DataExchangeReUse.OfflineWorkExchangePlan();
	
EndFunction

// For internal use
// 
Function ThisIsNodeOfOfflineWorkplace(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeReUse.ThisIsNodeOfOfflineWorkplace(InfobaseNode);
	
EndFunction

// For internal use
// 
Function LastSuccessfulSynchronizationDate(OfflineWorkplace) Export
	
	QueryText =
	"SELECT
	|	MIN(SuccessfulDataExchangeStatus.EndDate) AS SynchronizationDate
	|FROM
	|	[SuccessfulDataExchangeStatus] AS SuccessfulDataExchangeStatus
	|WHERE
	|	SuccessfulDataExchangeStatus.InfobaseNode = &OfflineWorkplace";
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		QueryText = StrReplace(QueryText, "[SuccessfulDataExchangeStates]", "InformationRegister.DataAreasSuccessfulDataExchangeStatus");
	Else
		QueryText = StrReplace(QueryText, "[SuccessfulDataExchangeStates]", "InformationRegister.SuccessfulDataExchangeStatus");
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("OfflineWorkplace", OfflineWorkplace);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return ?(ValueIsFilled(Selection.SynchronizationDate), Selection.SynchronizationDate, Undefined);
EndFunction

// For internal use
// 
Function GenerateOfflineWorkplaceDescriptionByDefault() Export
	
	QueryText = "
	|SELECT
	|	COUNT(*) AS Count
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS Table
	|WHERE
	|	Table.Description LIKE &NamePattern";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]", OfflineWorkExchangePlan());
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("NamePattern", OfflineWorkplaceDescriptionByDefault() + "%");
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Count = Selection.Count;
	
	If Count = 0 Then
		
		Return OfflineWorkplaceDescriptionByDefault();
		
	Else
		
		Result = "[Name] ([Quantity])";
		Result = StrReplace(Result, "[Description]", OfflineWorkplaceDescriptionByDefault());
		Result = StrReplace(Result, "[Count]", Format(Count + 1, "NG=0"));
		
		Return Result;
	EndIf;
	
EndFunction

// For internal use
// 
Function GenerateOfflineWorkplacePrefix(Val LastPrefix = "") Export
	
	AllowedChars = OfflineWorkplacePrefixAllowedSymbols();
	
	SymbolLastOfflineWorkplace = Left(LastPrefix, 1);
	
	CharPosition = Find(AllowedChars, SymbolLastOfflineWorkplace);
	
	If CharPosition = 0 OR IsBlankString(SymbolLastOfflineWorkplace) Then
		
		Char = Left(AllowedChars, 1); // Use first character
		
	ElsIf CharPosition >= StrLen(AllowedChars) Then
		
		Char = Right(AllowedChars, 1); // Use the last character
		
	Else
		
		Char = Mid(AllowedChars, CharPosition + 1, 1); // Use the following character
		
	EndIf;
	
	ApplicationPrefix = Right(GetFunctionalOption("InfobasePrefix"), 1);
	
	Result = "[Char][ApplicationPrefix]";
	Result = StrReplace(Result, "[Char]", Char);
	Result = StrReplace(Result, "[ApplicationPrefix]", ApplicationPrefix);
	
	Return Result;
EndFunction

// For internal use
// 
Function SetupPackageFileName() Export
	
	Return NStr("en='Offline work.zip';ru='Автономная работа.zip'");
	
EndFunction

// For internal use
// 
Function DataTransferRestrictionsDescriptionFull(OfflineWorkplace) Export
	
	OfflineWorkExchangePlan = OfflineWorkExchangePlan();
	
	FilterSsettingsAtNode = DataExchangeServer.FilterSsettingsAtNode(OfflineWorkExchangePlan, "");
	
	If FilterSsettingsAtNode.Count() = 0 Then
		Return "";
	EndIf;
	
	Attributes = New Array;
	
	For Each Item IN FilterSsettingsAtNode Do
		
		Attributes.Add(Item.Key);
		
	EndDo;
	
	Attributes = StringFunctionsClientServer.RowFromArraySubrows(Attributes);
	
	AttributeValues = CommonUse.ObjectAttributesValues(OfflineWorkplace, Attributes);
	
	For Each Item IN FilterSsettingsAtNode Do
		
		If TypeOf(Item.Value) = Type("Structure") Then
			
			Table = AttributeValues[Item.Key].Unload();
			
			For Each NestedItem IN Item.Value Do
				
				FilterSsettingsAtNode[Item.Key][NestedItem.Key] = Table.UnloadColumn(NestedItem.Key);
				
			EndDo;
			
		Else
			
			FilterSsettingsAtNode[Item.Key] = AttributeValues[Item.Key];
			
		EndIf;
		
	EndDo;
	
	Return DataExchangeServer.DataTransferRestrictionsDescriptionFull(OfflineWorkExchangePlan, FilterSsettingsAtNode, "");
EndFunction

// For internal use
// 
Function OfflineWorkplacesMonitor() Export
	
	QueryText = "
	|SELECT
	|	SuccessfulDataExchangeStatus.InfobaseNode AS OfflineWorkplace,
	|	MIN(SuccessfulDataExchangeStatus.EndDate) AS SynchronizationDate
	|INTO SuccessfulDataExchangeStatus
	|FROM
	|	InformationRegister.DataAreasSuccessfulDataExchangeStatus AS SuccessfulDataExchangeStatus
	|
	|GROUP BY
	|	SuccessfulDataExchangeStatus.InfobaseNode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangePlan.Ref AS OfflineWorkplace,
	|	ISNULL(SuccessfulDataExchangeStatus.SynchronizationDate, Undefined) AS SynchronizationDate
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
	|
	|	LEFT JOIN SuccessfulDataExchangeStatus AS SuccessfulDataExchangeStatus
	|	BY ExchangePlan.Ref = SuccessfulDataExchangeStatus.OfflineWorkplace
	|
	|WHERE
	|	ExchangePlan.Ref <> &ApplicationInService
	|	AND Not ExchangePlan.DeletionMark
	|
	|ORDER BY
	|	ExchangePlan.Presentation";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]", OfflineWorkExchangePlan());
	
	Query = New Query;
	Query.SetParameter("ApplicationInService", ApplicationInService());
	Query.Text = QueryText;
	
	SynchronizationSettings = Query.Execute().Unload();
	SynchronizationSettings.Columns.Add("SynchronizationDatePresentation");
	
	For Each SynchronizationSetting IN SynchronizationSettings Do
		
		If ValueIsFilled(SynchronizationSetting.SynchronizationDate) Then
			SynchronizationSetting.SynchronizationDatePresentation =
				DataExchangeServer.RelativeSynchronizationDate(SynchronizationSetting.SynchronizationDate);
		Else
			SynchronizationSetting.SynchronizationDatePresentation = NStr("en='were not executed';ru='не выполнялась'");
		EndIf;
		
	EndDo;
	
	Return SynchronizationSettings;
EndFunction

// For internal use
// 
Function EventLogMonitorEventCreatingOfflineWorkplace() Export
	
	Return NStr("en='Offline work. Offline workplace creation';ru='Автономная работа.Создание автономного рабочего места'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// For internal use
// 
Function EventLogMonitorEventDeletionOfflineWorkplace() Export
	
	Return NStr("en='Offline work. Offline workplace deletion';ru='Автономная работа.Удаление автономного рабочего места'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// For internal use
// 
Function InstructionTextFromTemplate(Val TemplateName) Export
	
	Result = DataProcessors.OfflineWorkplaceCreationAssistant.GetTemplate(TemplateName).GetText();
	Result = StrReplace(Result, "[ApplicationName]", Metadata.Synonym);
	Result = StrReplace(Result, "[PlatformVersion]", DataExchangeSaaS.RequiredPlatformVersion());
	Return Result;
EndFunction

// For internal use
// 
Function ReplaceInadmissibleSymbolsInUserName(Val Value, Val ReplacementChar = "_") Export
	
	ProhibitedChars = DataExchangeClientServer.InadmissibleSymbolsInUserNameWSProxy();
	
	For IndexOf = 1 To StrLen(ProhibitedChars) Do
		
		DisallowedChar = Mid(ProhibitedChars, IndexOf, 1);
		
		Value = StrReplace(Value, DisallowedChar, ReplacementChar);
		
	EndDo;
	
	Return Value;
EndFunction

//

// For internal use
// 
Function OfflineWorkplaceDescriptionByDefault()
	
	Result = NStr("en='Offline work - %1';ru='Автономная работа - %1'");
	
	Return StringFunctionsClientServer.PlaceParametersIntoString(Result, UserFullName());
EndFunction

// For internal use
// 
Function OfflineWorkplacePrefixAllowedSymbols()
	
	Return NStr("en='ABCDEFGCHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';ru='АБВГДЕЖЗИКЛМНОПРСТУФХЦЧШЭЮЯабвгдежзиклмнопрстуфхцчшэюя'"); // 54 characters
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS USED ON THE SIDE OF OFFLINE WORK PLACE

// For internal use
// 
Procedure SynchronizeDataWithApplicationInInternet() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	SetPrivilegedMode(True);
	
	If Not ThisIsOfflineWorkplace() Then
		
		MainLanguageCode = CommonUseClientServer.MainLanguageCode();
		
		DetailedErrorReprasentationForEventLogMonitor =
			NStr("en='This infobase is not an offline workplace. Data synchronization is cancelled.';ru='Эта информационная база не является автономным рабочим местом. Синхронизация данных отменена.'",
			CommonUseClientServer.MainLanguageCode())
		;
		DetailErrorDescription =
			NStr("en='This infobase is not an offline workplace. Data synchronization is cancelled.';ru='Эта информационная база не является автономным рабочим местом. Синхронизация данных отменена.'")
		; // String is written to Events log monitor
		
		WriteLogEvent(EventLogMonitorEventDataSynchronization(),
			EventLogLevel.Error,,, DetailedErrorReprasentationForEventLogMonitor);
		Raise DetailErrorDescription;
		
	EndIf;
	
	Cancel = False;
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Cancel, ApplicationInService(), True, True,
		Enums.ExchangeMessagesTransportKinds.WS);
	
	If Cancel Then
		Raise NStr("en='Error occurred while data synchronization with the application on the Internet (see. events log monitor).';ru='В процессе синхронизации данных с приложением в Интернете возникли ошибки (см. журнал регистрации).'");
	EndIf;
	
EndProcedure

// For internal use
// 
Procedure ExecuteConfigurationOfAutonomousWorkWhenYouFirstStart() Export
	
	If Not CommonUse.FileInfobase() Then
		Raise NStr("en='First start of offline work place"
"should be executed in the file work mode of infobase.';ru='Первый запуск автономного рабочего"
"места должен выполняться в файловом режиме работы информационной базы.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Exchange plans do not migrate to DIB, that is why import rules
	DataExchangeServer.ExecuteUpdateOfDataExchangeRules();
	ImportInitialImageData();
	ImportParametersFromInitialImage();
	
	SetPrivilegedMode(False);
	
	OnContinuingOfflineWorkplaceSetting();
	
EndProcedure

Procedure OnContinuingOfflineWorkplaceSetting()
	SetPrivilegedMode(True);
	UsersService.ClearNonExistentInfobaseUserIDs();
	If CommonUse.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleWorkWithPostalMessagesService = CommonUse.CommonModule("EmailOperationsService");
		ModuleWorkWithPostalMessagesService.DisableAccountsUse();
	EndIf;
EndProcedure

// For internal use
// 
Procedure DisableAutomaticDataSynchronizationWithApplicationInInternet(Source) Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		
		DisableAutomaticSynchronization = False;
		
		For Each SetRow IN Source Do
			
			If SetRow.ExchangeMessageTransportKindByDefault = Enums.ExchangeMessagesTransportKinds.WS
				AND Not SetRow.WSRememberPassword Then
				
				DisableAutomaticSynchronization = True;
				Break;
				
			EndIf;
			
		EndDo;
		
		If DisableAutomaticSynchronization Then
			
			SetPrivilegedMode(True);
			
			ScheduledJobsServer.SetUseScheduledJob(
				Metadata.ScheduledJobs.DataSynchronizationWithApplicationInInternet, False);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// For internal use
// 
Function NeedToExecuteOfflineWorkplaceSettingAtFirstStart() Export
	
	SetPrivilegedMode(True);
	Return Not Constants.SubordinatedDIBNodeSettingsFinished.Get() AND ThisIsOfflineWorkplace();
	
EndFunction

// For internal use
// 
Function SynchronizeDataWithApplicationInInternetOnWorkStart() Export
	
	Return ThisIsOfflineWorkplace()
		AND Constants.SubordinatedDIBNodeSettingsFinished.Get()
		AND Constants.SynchronizeDataWithApplicationInInternetOnApplicationStart.Get()
		AND SynchronizationWithServiceHasNotBeenExecutedLongAgo()
		AND DataExchangeServer.DataSynchronizationIsEnabled()
	;
EndFunction

// For internal use
// 
Function SynchronizeDataWithApplicationInInternetOnExit() Export
	
	Return ThisIsOfflineWorkplace()
		AND Constants.SubordinatedDIBNodeSettingsFinished.Get()
		AND Constants.SynchronizeDataWithApplicationInInternetOnApplicationEnd.Get()
		AND DataExchangeServer.DataSynchronizationIsEnabled()
	;
EndFunction

// For internal use
// 
Function DataSynchronizationScheduleByDefault() Export // Every hour
	
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
	Schedule.RepeatPeriodInDay = 60*60; // 60 minutes
	Schedule.DaysRepeatPeriod        = 1; // every day
	
	Return Schedule;
EndFunction

// For internal use
// 
Function ThisIsOfflineWorkplace() Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeReUse.ThisIsOfflineWorkplace();
	
EndFunction

// For internal use
// 
Function FormParametersDataExchange() Export
	
	Return New Structure("InfobaseNode, AddressForAccountPasswordRecovery, CloseOnSuccessfulSynchronization",
		ApplicationInService(), AddressForAccountPasswordRecovery(), True);
EndFunction

// For internal use
// 
Function SynchronizationWithServiceHasNotBeenExecutedLongAgo(Val Period = 3600) Export // 1 hour by default
	
	Return True;
	
EndFunction

// Determines whether it is possible
// to change the object Object can not be written in the Offline work place if it corresponds to the following conditions at the same time:
// 1. It is offline work place.
// 2. This is undivided metadata object.
// 3. This object is part of the offline work exchange plan.
// 4. It is not included in the exceptions list.
//
// Parameters:
// MetadataObject - Checked object
// metadata View only - Boolean - If True, object is available for view only.
//
Procedure DetermineWhetherChangesData(MetadataObject, ReadOnly) Export
	
	SetPrivilegedMode(True);
	
	ReadOnly = ThisIsOfflineWorkplace()
		AND (NOT CommonUseReUse.IsSeparatedMetadataObject(MetadataObject.FullName(),
			CommonUseReUse.MainDataSeparator())
			AND Not CommonUseReUse.IsSeparatedMetadataObject(MetadataObject.FullName(),
				CommonUseReUse.SupportDataSplitter()))
		AND Not MetadataObjectIsExclusion(MetadataObject)
		AND Metadata.ExchangePlans[OfflineWorkExchangePlan()].Content.Contains(MetadataObject);
	
EndProcedure

//

// For internal use
// 
Procedure ImportParametersFromInitialImage()
	
	Parameters = GetParametersFromInitialImage();
	
	Try
		ExchangePlans.SetMasterNode(Undefined);
	Except
		WriteLogEvent(EventLogMonitorEventCreatingOfflineWorkplace(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise NStr("en='Infobase may have been opened in the configurator mode."
"Exit the designer and restart the application.';ru='Возможно, информационная база открыта в режиме конфигуратора."
"Завершите работу конфигуратора и повторите запуск программы.'");
	EndTry;
	
	// Create exchange plan nodes of offline work place in the zero dara area
	NodeOfOfflineWorkplace = ExchangePlans[OfflineWorkExchangePlan()].ThisNode().GetObject();
	NodeOfOfflineWorkplace.Code          = Parameters.CodeOfOfflineWorkplace;
	NodeOfOfflineWorkplace.Description = Parameters.OfflineWorkplaceDescription;
	NodeOfOfflineWorkplace.AdditionalProperties.Insert("GettingExchangeMessage");
	NodeOfOfflineWorkplace.Write();
	
	ApplicationInServiceNode = ExchangePlans[OfflineWorkExchangePlan()].CreateNode();
	ApplicationInServiceNode.Code          = Parameters.ApplicationInServiceCode;
	ApplicationInServiceNode.Description = Parameters.ApplicationNameInService;
	ApplicationInServiceNode.AdditionalProperties.Insert("GettingExchangeMessage");
	ApplicationInServiceNode.Write();
	
	// Appoint created node as the main one.
	ExchangePlans.SetMasterNode(ApplicationInServiceNode.Ref);
	StandardSubsystemsServer.SaveMasterNode();
	
	BeginTransaction();
	Try
		
		Constants.UseDataSynchronization.Set(True);
		Constants.SubordinatedDIBNodeSetup.Set("");
		Constants.DistributedInformationBaseNodePrefix.Set(Parameters.Prefix);
		Constants.SynchronizeDataWithApplicationInInternetOnApplicationStart.Set(True);
		Constants.SynchronizeDataWithApplicationInInternetOnApplicationEnd.Set(True);
		Constants.SystemTitle.Set(Parameters.SystemTitle);
		
		Constants.ThisIsOfflineWorkplace.Set(True);
		Constants.UseSeparationByDataAreas.Set(False);
		
		// constant influences the assistant opening by the offline work place setting
		Constants.SubordinatedDIBNodeSettingsFinished.Set(True);
		
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", ApplicationInService());
		RecordStructure.Insert("ExchangeMessageTransportKindByDefault", Enums.ExchangeMessagesTransportKinds.WS);
		
		RecordStructure.Insert("WSUseLargeDataTransfer", True);
		
		RecordStructure.Insert("WSURLWebService", Parameters.URL);
		
		// add record to the information register
		InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
		
		// Set the initial image creation date as the date of the first successful data synchronization.
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", ApplicationInService());
		RecordStructure.Insert("ActionOnExchange", Enums.ActionsAtExchange.DataExport);
		RecordStructure.Insert("EndDate", Parameters.DateOfInitialImage);
		InformationRegisters.SuccessfulDataExchangeStatus.AddRecord(RecordStructure);
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", ApplicationInService());
		RecordStructure.Insert("ActionOnExchange", Enums.ActionsAtExchange.DataImport);
		RecordStructure.Insert("EndDate", Parameters.DateOfInitialImage);
		InformationRegisters.SuccessfulDataExchangeStatus.AddRecord(RecordStructure);
		
		// Set default synchronization schedule.
		// Disable schedule as user password is not specified.
		ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.DataSynchronizationWithApplicationInInternet);
		ScheduledJob.Use = False;
		ScheduledJob.Schedule = DataSynchronizationScheduleByDefault();
		ScheduledJob.Write();
		
		// Create IB user and link it to user from users catalog.
		Roles = New Array;
		Roles.Add("SystemAdministrator");
		Roles.Add("FullRights");
		
		IBUserDescription = New Structure;
		IBUserDescription.Insert("Action", "Write");
		IBUserDescription.Insert("Name",       Parameters.OwnerName);
		IBUserDescription.Insert("Roles",      Roles);
		IBUserDescription.Insert("StandardAuthentication", True);
		IBUserDescription.Insert("ShowInList", True);
		
		User = Catalogs.Users.GetRef(New UUID(Parameters.Owner)).GetObject();
		
		If User = Undefined Then
			Raise NStr("en='User identification is not complete."
"Perhaps, the users catalog is not included to the offline exchange plan.';ru='Идентификация пользователя не выполнена."
"Возможно, справочник пользователей не включен в состав плана обмена автономной работы.'");
		EndIf;
		
		SetUserPasswordMinLength(0);
		SetUserPasswordStrengthCheck(False);
		
		User.Service = False;
		User.AdditionalProperties.Insert("IBUserDescription", IBUserDescription);
		User.Write();
		
		ExchangePlans.DeleteChangeRecords(ApplicationInServiceNode.Ref);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogMonitorEventCreatingOfflineWorkplace(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// For internal use
// 
Procedure ImportInitialImageData()
	
	InfobaseDirectory = CommonUseClientServer.FileInformationBaseDirectory();
	
	InitialImageDataFileName = CommonUseClientServer.GetFullFileName(
		InfobaseDirectory,
		"data.xml");
	
	InitialImageDataFile = New File(InitialImageDataFileName);
	If Not InitialImageDataFile.Exist() Then
		Return; // Initial image data were successfully imported earlier
	EndIf;
	
	InitialImageData = New XMLReader;
	InitialImageData.OpenFile(InitialImageDataFileName);
	InitialImageData.Read();
	InitialImageData.Read();
	
	BeginTransaction();
	Try
		
		While CanReadXML(InitialImageData) Do
			
			DataItem = ReadXML(InitialImageData);
			DataItem.AdditionalProperties.Insert("CreatingInitialImage");
			
			ItemReceive = DataItemReceive.Auto;
			StandardSubsystemsServer.OnReceiveDataFromMaster(DataItem, ItemReceive, False);
			
			If ItemReceive = DataItemReceive.Ignore Then
				Continue;
			EndIf;
			
			DataItem.DataExchange.Load = True;
			DataItem.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
			DataItem.Write();
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogMonitorEventCreatingOfflineWorkplace(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		
		InitialImageData = Undefined;
		Raise;
	EndTry;
	
	InitialImageData.Close();
	
	Try
		DeleteFiles(InitialImageDataFileName);
	Except
		WriteLogEvent(EventLogMonitorEventCreatingOfflineWorkplace(), EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// For internal use
// 
Function GetParametersFromInitialImage()
	
	XMLString = Constants.SubordinatedDIBNodeSetup.Get();
	
	If IsBlankString(XMLString) Then
		Raise NStr("en='Settings were not found in the offline work place."
"Work with the offline worplace is impossible.';ru='В автономное рабочее место не были переданы настройки."
"Работа с автономным рабочим место невозможна.'");
	EndIf;
	
	XMLReader = New XMLReader;
	XMLReader.SetString(XMLString);
	
	XMLReader.Read(); // Parameters
	FormatVersion = XMLReader.GetAttribute("FormatVersion");
	
	XMLReader.Read(); // OfflineWorkplaceParameters
	
	Result = CalculateDataToStructure(XMLReader);
	
	XMLReader.Close();
	
	Return Result;
EndFunction

// For internal use
// 
Function CalculateDataToStructure(XMLReader)
	
	// Return value
	Result = New Structure;
	
	If XMLReader.NodeType <> XMLNodeType.StartElement Then
		Raise NStr("en='XML reading error';ru='Ошибка чтения XML'");
	EndIf;
	
	XMLReader.Read();
	
	While XMLReader.NodeType <> XMLNodeType.EndElement Do
		
		Key = XMLReader.Name;
		
		Result.Insert(Key, ReadXML(XMLReader));
		
	EndDo;
	
	XMLReader.Read();
	
	Return Result;
EndFunction

// For internal use
// 
Function EventLogMonitorEventDataSynchronization()
	
	Return NStr("en='Offline work.Data synchronization';ru='Автономная работа.Синхронизация данных'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls to other subsystems

// Checks whether object is included to the exceptions list
Function MetadataObjectIsExclusion(Val MetadataObject)
	
	// ServiceEventsParameters constant is an object of
	// initial DIB node but should be checked without calling service events.
	If MetadataObject = Metadata.Constants.ServiceEventsParameters Then
		Return True;
	EndIf;
	
	// MetadataObjectsIDs catalog is an initial DIB node object.
	// It is possible to update many catalog attributes in the
	// subordinate DIB nodes by metadata properties values according to the main node (it is required for exceptions).
	// Change is controlled in catalog in the BeforeWrite procedure of the object module.
	If MetadataObject = Metadata.Catalogs.MetadataObjectIDs Then
		Return True;
	EndIf;
	
	Return StandardSubsystemsServer.ThisIsObjectOfPrimaryImageNodeRIB(MetadataObject);
	
EndFunction

#EndRegion
