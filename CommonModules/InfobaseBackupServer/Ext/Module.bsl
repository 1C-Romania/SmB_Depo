////////////////////////////////////////////////////////////////////////////////
// Subsystem "IB backup".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\OnGetListOfWarningsToCompleteJobs"].Add(
			"InfobaseBackupClient");
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\OnStart"].Add(
			"InfobaseBackupClient");
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\WhenVerifyingBackupPossibilityInUserMode"].Add(
			"InfobaseBackupClient");
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\WhenUserIsOfferedToBackup"].Add(
			"InfobaseBackupClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsOnComplete"].Add(
		"InfobaseBackupServer");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsRunning"].Add(
		"InfobaseBackupServer");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
		"InfobaseBackupServer");
		
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"InfobaseBackupServer");
		
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSwitchUsingSecurityProfiles"].Add(
		"InfobaseBackupServer");
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ServerHandlers["StandardSubsystems.CurrentWorks\AtFillingToDoList"].Add(
			"InfobaseBackupServer");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns the parameters of IBBackup subsystem required
// on user operation end.
//
// Returns:
// Structure - Parameters.
//
Function ParametersOnWorkCompletion()
	
	BackupSettings = BackupSettings();
	ExecuteOnWorkCompletion = ?(BackupSettings = Undefined, False,
		BackupSettings.ExecuteAutomaticBackup
		AND BackupSettings.ExecutionVariant = "OnWorkCompletion");
	
	ParametersOnComplete = New Structure;
	ParametersOnComplete.Insert("NotificationRolesAvailability",   HasRightsToAlertAboutBackupConfiguration());
	ParametersOnComplete.Insert("ExecuteOnWorkCompletion", ExecuteOnWorkCompletion);
	
	Return ParametersOnComplete;
	
EndFunction

// Returns period value for specified time interval.
//	
// Parameters:
// TimeInterval - Number - time interval in seconds.
//	
// Returns - Structure with fields:
// PeriodType - String - period type: Day, Week, Month, Year.
// PeriodValue - Number - period length for specified type.
//
Function PeriodValueForTimeInterval(TimeInterval)
	
	ReturnedStructure = New Structure("PeriodType, PeriodValue", "Month", 1);
	
	If TimeInterval = Undefined Then 
		Return ReturnedStructure;
	EndIf;	
	
	If Int(TimeInterval / (3600 * 24 * 365)) > 0 Then 
		ReturnedStructure.PeriodType		= "Year";
		ReturnedStructure.PeriodValue	= TimeInterval / (3600 * 24 * 365);
		Return ReturnedStructure;
	EndIf;
	
	If Int(TimeInterval / (3600 * 24 * 30)) > 0 Then 
		ReturnedStructure.PeriodType		= "Month";
		ReturnedStructure.PeriodValue	= TimeInterval / (3600 * 24 * 30);
		Return ReturnedStructure;
	EndIf;
	
	If Int(TimeInterval / (3600 * 24 * 7)) > 0 Then 
		ReturnedStructure.PeriodType		= "Week";
		ReturnedStructure.PeriodValue	= TimeInterval / (3600 * 24 * 7);
		Return ReturnedStructure;
	EndIf;
	
	If Int(TimeInterval / (3600 * 24)) > 0 Then 
		ReturnedStructure.PeriodType		= "Day";
		ReturnedStructure.PeriodValue	= TimeInterval / (3600 * 24);
		Return ReturnedStructure;
	EndIf;
	
	Return ReturnedStructure;
	
EndFunction

// Returns saved backup parameters.
//
// Returns - Structure - backup parameters.
//
Function BackupParameters() Export
	
	Parameters = CommonUse.CommonSettingsStorageImport("BackupParameters");
	If Parameters = Undefined Then
		Parameters = InitialBackupSettingsFilling();
	Else
		BringBackupParameters(Parameters);
	EndIf;
	Return Parameters;
	
EndFunction

// Displays backup parameters.
// If in current backup parameters there is no parameter which exists in function "BackupSettingsInitialFilling" then it is added with default value.
//
// Parameters:
// BackupParameters - Structure - parameters of IB backup.
//
Procedure BringBackupParameters(BackupParameters)
	
	ParametersChanged = False;
	
	Parameters = InitialBackupSettingsFilling(False);
	For Each StructureItem IN Parameters Do
		FoundValue = Undefined;
		If BackupParameters.Property(StructureItem.Key, FoundValue) Then
			If FoundValue = Undefined AND StructureItem.Value <> Undefined Then
				BackupParameters.Insert(StructureItem.Key, StructureItem.Value);
				ParametersChanged = True;
			EndIf;
		Else
			If StructureItem.Value <> Undefined Then
				BackupParameters.Insert(StructureItem.Key, StructureItem.Value);
				ParametersChanged = True;
			EndIf;
		EndIf;
	EndDo;
	
	If Not ParametersChanged Then 
		Return;
	EndIf;
	
	SetBackupParameters(BackupParameters);
	
EndProcedure

// Saves backup parameters.
//
// Parameters:
// ParametersStructure - Structure - backup parameters.
//
Procedure SetBackupParameters(ParametersStructure, CurrentUser = Undefined) Export
	CommonUse.CommonSettingsStorageSave("BackupParameters", , ParametersStructure);
	If CurrentUser <> Undefined Then
		ParametersOfCopying = New Structure("User", CurrentUser);
		Constants.BackupParameters.Set(New ValueStorage(ParametersOfCopying));
	EndIf;
EndProcedure

// Checks if it is time for automatic backup.
//
// Returns:
//   Boolean - True if it is time to back up.
//
Function NecessityOfAutomaticBackup() Export
	
	If Not CommonUse.FileInfobase() Then
		Return False;
	EndIf;
	
	Parameters = BackupParameters();
	If Parameters = Undefined Then
		Return False;
	EndIf;
	Schedule = Parameters.CopyingSchedule;
	If Schedule = Undefined Then
		Return False;
	EndIf;
	
	If Parameters.Property("ProcessIsRunning") Then 
		If Parameters.ProcessIsRunning Then 
			Return False;
		EndIf;
	EndIf;
	
	CheckDate = CurrentSessionDate();
	If Parameters.MinimumDateOfNextAutomaticBackup > CheckDate Then
		Return False;
	EndIf;
	
	CheckStartDate = Parameters.DateOfLastBackup;
	ScheduleValue = CommonUseClientServer.StructureIntoSchedule(Schedule);
	Return ScheduleValue.ExecutionRequired(CheckDate, CheckStartDate);
	
EndFunction

// Generates the dates of nearest automatic backup according to the schedule.
//
// Parameters:
// InitialSetting - Boolean - flag of initial setup.
//
Function GenerateDatesOfNextAutomaticCopy(InitialSetting = False) Export
	
	Result = New Structure;
	BackupSettings = BackupSettings();
	
	CurrentDate = CurrentSessionDate();
	If InitialSetting Then
		Result.Insert("MinimumDateOfNextAutomaticBackup", CurrentDate);
		Result.Insert("DateOfLastBackup", CurrentDate);
	Else
		CopyingSchedule = BackupSettings.CopyingSchedule;
		RepeatPeriodInDay = CopyingSchedule.RepeatPeriodInDay;
		DaysRepeatPeriod = CopyingSchedule.DaysRepeatPeriod;
		
		If RepeatPeriodInDay <> 0 Then
			Value = CurrentDate + RepeatPeriodInDay;
		ElsIf DaysRepeatPeriod <> 0 Then
			Value = CurrentDate + DaysRepeatPeriod * 3600 * 24;
		Else
			Value = BegOfDay(EndOfDay(CurrentDate) + 1);
		EndIf;
		Result.Insert("MinimumDateOfNextAutomaticBackup", Value);
	EndIf;
	
	FillPropertyValues(BackupSettings, Result);
	SetBackupParameters(BackupSettings);
	
	Return Result;
	
EndFunction

// Returns the value of setting "Backup status" in result part.
// Used at system start to show the forms with backup results.
//
Procedure SetBackupResult() Export
	
	ParametersStructure = BackupSettings();
	ParametersStructure.CopyingHasBeenPerformed = False;
	SetBackupParameters(ParametersStructure);
	
EndProcedure

// Sets the value of setting "LastBackupDate".
//
// Parameters: 
//   CopyingDate - date and time of last backup.
//
Procedure SetLastCopyingDate(CopyingDate) Export
	
	ParametersStructure = BackupParameters();
	ParametersStructure.DateOfLastBackup = CopyingDate;
	SetBackupParameters(ParametersStructure);
	
EndProcedure

// Sets the date of last notification of user.
//
// Parameters: 
// DateReminders - Date - date and time of last user notification about
//                          the need to back up.
//
Procedure SetLastReminderDate(DateReminders) Export
	
	NotificationParameters = BackupParameters();
	NotificationParameters.LastNotificationDate = DateReminders;
	SetBackupParameters(NotificationParameters);
	
EndProcedure

// Sets the setting to backup parameters. 
// 
// Parameters: 
// ItemName - String - parameter name.
// 	ItemValue - Arbitrary type - value of the parameter.
//
Procedure SetSettingValue(ItemName, ItemValue) Export
	
	SettingsStructure = BackupParameters();
	SettingsStructure.Insert(ItemName, ItemValue);
	SetBackupParameters(SettingsStructure);
	
EndProcedure

// Returns the structure with backup parameters.
// 
// Parameters: 
// OperationStart - Boolean - flag of call at application start.
//
// Returns:
//  Structure - backup parameters.
//
Function BackupSettings(OperationStart = False) Export
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		Return Undefined; // Cannot log on to the data area.
	EndIf;
	
	If Not HasRightsToAlertAboutBackupConfiguration() Then
		Return Undefined; // Current user does not have necessary rights.
	EndIf;
	
	Result = BackupParameters();
	
	VariantNotifications = VariantNotifications();
	
	Result.Insert("NotificationParameter", VariantNotifications);
	If Result.CopyingHasBeenPerformed AND Result.CopyingResult  Then
		CurrentSessionDate = CurrentSessionDate();
		Result.DateOfLastBackup = CurrentSessionDate;
		// Saving the date of last backup in common settings storage.
		SetLastCopyingDate(CurrentSessionDate);
	EndIf;
	
	If Result.RecoverHasBeenPerformed Then
		UpdateRecoverResult();
	EndIf;
	
	If OperationStart AND Result.ProcessIsRunning Then
		Result.ProcessIsRunning = False;
		SetSettingValue("ProcessIsRunning", False);
	EndIf;
	
	Return Result;
	
EndFunction

// Updates the result of restoration and the structure of backup parameters. 
//
Procedure UpdateRecoverResult()
	
	ReturnStructure = BackupParameters();
	ReturnStructure.RecoverHasBeenPerformed = False;
	SetBackupParameters(ReturnStructure);
	
EndProcedure

// Selects notification option to show to user.
// Called from the form of backup assistant to determine start form.
//
// Returns: 
//   String:
//     "Configured" - automatic backup is configured.
//     "Overdue" - automatic backup is overdue.
//     "NotConfiguredYet" - Backup is not configured yet.
//     "DoNotNotify" - do not notify of necessity to back up (for
//                     example if executed by third-party tools).
//
Function VariantNotifications()
	
	Result = "DoNotNotify";
	If Not HasRightsToAlertAboutBackupConfiguration() Then
		Return Result;
	EndIf;
	
	NotificationParameterAboutCopying = BackupParameters();
	NotifyAboutBackupNecessity = CurrentSessionDate() >= (NotificationParameterAboutCopying.LastNotificationDate + 3600 * 24);
	
	If NotificationParameterAboutCopying.ExecuteAutomaticBackup Then
		
		If NecessityOfAutomaticBackup() Then
			Result = "Overdue";
		Else
			Result = "Configured";
		EndIf;
		
	ElsIf Not NotificationParameterAboutCopying.BackupIsConfigured Then
		
		If NotifyAboutBackupNecessity Then
			
			BackupSettings = Constants.BackupParameters.Get().Get();
			If BackupSettings <> Undefined
				AND BackupSettings.User <> UsersClientServer.CurrentUser() Then
				Result = "DoNotNotify";
			Else
				Result = "YetNotConfigured";
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Returns initial filling of automatic backup settings.
//
// Parameters:
// SaveParameters - save parameters in settings storage or not.
//
// Returns - Structure - initial filling of backup parameters.
//
Function InitialBackupSettingsFilling(SaveParameters = True) Export
	
	Parameters = New Structure;
	
	Parameters.Insert("ExecuteAutomaticBackup", False);
	Parameters.Insert("BackupIsConfigured", False);
	
	Parameters.Insert("LastNotificationDate", '00010101');
	Parameters.Insert("DateOfLastBackup", '00010101');
	Parameters.Insert("MinimumDateOfNextAutomaticBackup", '29990101');
	
	Parameters.Insert("CopyingSchedule", CommonUseClientServer.ScheduleIntoStructure(New JobSchedule));
	Parameters.Insert("DirectoryStorageOfBackupCopies", "");
	Parameters.Insert("BackupStorageDirectoryOnManualLaunch", ""); // On manual execution
	Parameters.Insert("CopyingHasBeenPerformed", False);
	Parameters.Insert("RecoverHasBeenPerformed", False);
	Parameters.Insert("CopyingResult", Undefined);
	Parameters.Insert("BackupFileName", "");
	Parameters.Insert("ExecutionVariant", "OnSchedule");
	Parameters.Insert("ProcessIsRunning", False);
	Parameters.Insert("InfobaseAdministrator", "");
	Parameters.Insert("IBAdministratorPassword", "");
	Parameters.Insert("DeletionParameters", DefaultParametersForBackupDeletion());
	Parameters.Insert("LastBackupManualLaunch", True);
	
	If SaveParameters Then
		SetBackupParameters(Parameters);
	EndIf;
	
	Return Parameters;
	
EndFunction

// Returns the flag showing that the user has full rights.
//
// Returns - Boolean - True if this is a full user.
//
Function HasRightsToAlertAboutBackupConfiguration() Export
	Return Users.InfobaseUserWithFullAccess(,True);
EndFunction

// Procedure called from script through com connection.
// Writes backup result to the settings.
// 
// Parameters:
// Result - Boolean - result of copying.
// BackupFileName - String - backup attachment file name.
//
Procedure CompleteBackup(Result, BackupFileName =  "") Export
	
	ResultStructure = BackupSettings();
	ResultStructure.CopyingHasBeenPerformed = True;
	ResultStructure.CopyingResult = Result;
	ResultStructure.BackupFileName = BackupFileName;
	SetBackupParameters(ResultStructure);
	
EndProcedure

// Called from the script
// through com connection to record the result of IB restoration into the settings.
//
// Parameters:
// Result - Boolean - result of restoration.
//
Procedure CompleteRecovering(Result) Export
	
	ResultStructure = BackupSettings();
	ResultStructure.RecoverHasBeenPerformed = True;
	SetBackupParameters(ResultStructure);
	
EndProcedure

// Returns current backup setting in a string.
// Two options of function use - or with passing of all parameters or without parameters.
//
Function CurrentBackupSetting() Export
	
	BackupSettings = BackupSettings();
	If BackupSettings = Undefined Then
		Return NStr("en = 'Contact administrator to configure backup.'");
	EndIf;
	
	CurrentSetting = NStr("en = 'The backup is not configured, infobase is under the data loss risk.'");
	
	If CommonUse.FileInfobase() Then
		
		If BackupSettings.ExecuteAutomaticBackup Then
			
			If BackupSettings.ExecutionVariant = "OnWorkCompletion" Then
				CurrentSetting = NStr("en = 'Backups are performed regularly at exit.'");
			ElsIf BackupSettings.ExecutionVariant = "OnSchedule" Then // On schedule
				Schedule = CommonUseClientServer.StructureIntoSchedule(BackupSettings.CopyingSchedule);
				If Not IsBlankString(Schedule) Then
					CurrentSetting = NStr("en = 'Backup is executed on a regular basis according to the schedule: %1'");
					CurrentSetting = StringFunctionsClientServer.PlaceParametersIntoString(CurrentSetting, Schedule);
				EndIf;
			EndIf;
			
		Else
			
			If BackupSettings.BackupIsConfigured Then
				CurrentSetting = NStr("en = 'No backup in progress (organized by third-party applications).'");
			EndIf;
			
		EndIf;
		
	Else
		
		CurrentSetting = NStr("en = 'No backup in progress (organized with DBMS tools).'");
		
	EndIf;
	
	Return CurrentSetting;
	
EndFunction

Function DefaultParametersForBackupDeletion()
	
	DeletionParameters = New Structure;
	
	DeletionParameters.Insert("RestrictionType", "ByPeriod");
	
	DeletionParameters.Insert("CopiesCount", 10);
	
	DeletionParameters.Insert("PeriodMeasurementUnit", "Month");
	DeletionParameters.Insert("ValueInMeasurementUnits", 6);
	
	Return DeletionParameters;
	
EndFunction

// Updates backup settings.
//
Procedure UpdateBackupParameters_2_2_1_15() Export
	
	BackupParameters = BackupSettings();
	
	If BackupParameters = Undefined Then
		Return;
	EndIf;
	
	If Not BackupParameters.Property("PerformBackupOnExit")
		Or Not BackupParameters.Property("SetByUser") Then
		
		Return; // The update was already completed.
		
	EndIf;
	
	CaseOfParagraphSettings = BackupParameters.CaseOfParagraphSettings;
	
	If CaseOfParagraphSettings = 3 Then
		CaseOfParagraphSettings = 0;
	ElsIf CaseOfParagraphSettings = 2 Then
		CaseOfParagraphSettings = 3;
	Else
		If BackupParameters.PerformBackupOnExit Then
			CaseOfParagraphSettings = 2;
		ElsIf BackupParameters.SetByUser AND ValueIsFilled(BackupParameters.CopyingSchedule) Then
			CaseOfParagraphSettings = 1;
		Else
			CaseOfParagraphSettings = 0;
		EndIf;
	EndIf;
	
	BackupParameters.CaseOfParagraphSettings = CaseOfParagraphSettings;
	
	DeletedParametersArray = New Array;
	DeletedParametersArray.Add("HourlyNotification ");
	DeletedParametersArray.Add("SetByUser ");
	DeletedParametersArray.Add("PerformBackupOnExit");
	DeletedParametersArray.Add("AutomaticBackupClone");
	DeletedParametersArray.Add("PostponedBackup");
	
	For Each DeletedParameter IN DeletedParametersArray Do
		
		If BackupParameters.Property(DeletedParameter) Then
			
			BackupParameters.Delete(DeletedParameter);
			
		EndIf;
		
	EndDo;
	
	SetBackupParameters(BackupParameters);
	
EndProcedure

// Updates backup settings.
//
Procedure UpdateBackupParameters_2_2_1_33() Export
	
	BackupParameters = BackupSettings();
	
	If BackupParameters = Undefined Then
		Return;
	EndIf;
	
	If BackupParameters.Property("DeletionParameters") Then
		
		Return; // The update was already completed.
		
	EndIf;
	
	DeletionParameters = DefaultParametersForBackupDeletion();
	DeletionParameters.PerformDeletion = BackupParameters.PerformDeletion;
	DeletionParameters.RestrictionType = ?(BackupParameters.DeleteByPeriod, "ByPeriod", "ByAmount");
	
	If BackupParameters.DeleteByPeriod Then
		DeletionParameters.RestrictionType = "ByPeriod";
		SettingsValuesPeriod = PeriodValueForTimeInterval(BackupParameters.ParameterValue);
		DeletionParameters.PeriodMeasurementUnit = SettingsValuesPeriod.PeriodType;
		DeletionParameters.ValueInMeasurementUnits = SettingsValuesPeriod.PeriodValue;
	Else
		DeletionParameters.RestrictionType = "ByAmount";
		DeletionParameters.CopiesCount = DeletionParameters.ParameterValue;
	EndIf;
	
	BackupParameters.Insert("DeletionParameters", DeletionParameters);
	
	DeletedParametersArray = New Array;
	DeletedParametersArray.Add("PerformDeletion");
	DeletedParametersArray.Add("DeleteByPeriod ");
	DeletedParametersArray.Add("ParameterValue");
	DeletedParametersArray.Add("NotificationPeriod");
	
	For Each DeletedParameter IN DeletedParametersArray Do
		
		If BackupParameters.Property(DeletedParameter) Then
			
			BackupParameters.Delete(DeletedParameter);
			
		EndIf;
		
	EndDo;
	
	SetBackupParameters(BackupParameters);
	
EndProcedure

// Updates backup settings.
//
Procedure UpdateBackupParameters_2_2_2_33() Export
	
	BackupParameters = BackupSettings();
	
	If BackupParameters = Undefined Then
		Return;
	EndIf;
	
	If BackupParameters.Property("ExecuteAutomaticBackup") Then
		
		Return; // The update was already completed.
		
	EndIf;
	
	If BackupParameters.FirstLaunch Then
		
		BackupParameters.DateOfLastBackup = Date(1, 1, 1);
		
	EndIf;
	
	If BackupParameters.CaseOfParagraphSettings = 2 Then
		ExecutionVariant = "OnWorkCompletion";
	Else
		ExecutionVariant = "OnSchedule";
	EndIf;
	
	ExecuteAutomaticBackup = (BackupParameters.CaseOfParagraphSettings = 1 Or BackupParameters.CaseOfParagraphSettings = 2);
	
	BackupParameters.Insert("ExecuteAutomaticBackup", ExecuteAutomaticBackup);
	BackupParameters.Insert("BackupIsConfigured", BackupParameters.CaseOfParagraphSettings <> 0);
	BackupParameters.Insert("ExecutionVariant", ExecutionVariant);
	BackupParameters.Insert("LastBackupManualLaunch", True);
	
	DeletedParametersArray = New Array;
	DeletedParametersArray.Add("CaseOfParagraphSettings");
	DeletedParametersArray.Add("FirstLaunch");
	
	For Each DeletedParameter IN DeletedParametersArray Do
		
		If BackupParameters.Property(DeletedParameter) Then
			
			BackupParameters.Delete(DeletedParameter);
			
		EndIf;
		
	EndDo;
	
	If BackupParameters.Property("DeletionParameters")
		AND BackupParameters.DeletionParameters.Property("PerformDeletion") Then
		
		If Not BackupParameters.DeletionParameters.PerformDeletion Then
			BackupParameters.DeletionParameters.RestrictionType = "StoreAll";
		EndIf;
		
		BackupParameters.DeletionParameters.Delete("PerformDeletion");
		
	EndIf;
	
	SetBackupParameters(BackupParameters);
	
EndProcedure

// Updates backup settings.
//
Procedure UpdateBackupParameters_2_2_4_36() Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	SavedUser = Undefined;
	For Each User IN InfobaseUsers.GetUsers() Do
		Settings = CommonUse.CommonSettingsStorageImport("BackupParameters",,,, User.Name);
		
		If TypeOf(Settings) <> Type("Structure") Then
			Continue;
		EndIf;
		
		If Settings.Property("ExecuteAutomaticBackup")
			AND Settings.ExecuteAutomaticBackup Then
			SavedUser = User;
			Break;
		EndIf;
		
		If Settings.Property("BackupIsConfigured")
			AND Settings.BackupIsConfigured Then
			SavedUser = User;
		EndIf;
		
	EndDo;
	
	If SavedUser <> Undefined Then
		FoundUser = Undefined;
		UsersService.UserByIDExists(SavedUser.UUID,, FoundUser);
		If FoundUser <> Undefined Then
			Parameters = New Structure("User", FoundUser);
			Constants.BackupParameters.Set(New ValueStorage(Parameters));
		EndIf;
	EndIf;
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Fills in parameters structure required for client
// code work during the configuration end i.e. in the handlers.:
// - BeforeExit,
// - OnExit
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystemsOnComplete(Parameters) Export
	
	Parameters.Insert("InfobaseBackup", ParametersOnWorkCompletion());
	
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystemsRunning(Parameters) Export
	
	Parameters.Insert("InfobaseBackup", BackupSettings(True));
	
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystems(Parameters) Export
	
	Parameters.Insert("InfobaseBackup", BackupSettings());
	
EndProcedure

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable
//                                  function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.SharedData = True;
	Handler.Procedure = "InfobaseBackupServer.UpdateBackupParameters_2_2_1_15";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.33";
	Handler.SharedData = True;
	Handler.Procedure = "InfobaseBackupServer.UpdateBackupParameters_2_2_1_33";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.33";
	Handler.SharedData = True;
	Handler.Procedure = "InfobaseBackupServer.UpdateBackupParameters_2_2_2_33";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.4.36";
	Handler.SharedData = True;
	Handler.Procedure = "InfobaseBackupServer.UpdateBackupParameters_2_2_4_36";
	
EndProcedure

// Appears when you enable the use of the infobase for security profiles.
//
Procedure OnSwitchUsingSecurityProfiles() Export
	
	BackupParameters = BackupSettings();
	
	If BackupParameters = Undefined Then
		Return;
	EndIf;
	
	If BackupParameters.Property("IBAdministratorPassword") Then
		
		BackupParameters.IBAdministratorPassword = "";
		SetBackupParameters(BackupParameters);
		
	EndIf;
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    * Identifier - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    * Important        - Boolean - If True, the work is marked in red.
//    * Presentation - String - a work presentation displayed to the user.
//    * Count    - Number  - a quantitative indicator of work, it is displayed in the work header string.
//    * Form         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner      - String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip     - String - The tooltip wording.
//
Procedure AtFillingToDoList(CurrentWorks) Export
	
	ThisIsWebClient = CommonUseClientServer.ThisIsWebClient();
	If Not CommonUse.FileInfobase() // Executed by third-party tools in client-server.
		Or ThisIsWebClient Then // Not supported in web client.
		Return;
	EndIf;
	
	ModuleCurrentWorksService = CommonUse.CommonModule("CurrentWorksService");
	NotificationOnBackupConfigurationDisabled = ModuleCurrentWorksService.WorkDisabled("SetupBackup");
	BackupNotificationDisabled = ModuleCurrentWorksService.WorkDisabled("ExecuteBackingUpNow");
	
	If Not AccessRight("view", Metadata.DataProcessors.InfobaseBackupSetup)
		Or (NotificationOnBackupConfigurationDisabled
			AND BackupNotificationDisabled) Then
		Return;
	EndIf;
	ModuleCurrentWorksServer = CommonUse.CommonModule("CurrentWorksServer");
	
	BackupSettings = BackupSettings();
	VariantNotifications = BackupSettings.NotificationParameter;
	
	// The procedure is called only if there is the
	// To-do lists subsystem, that is why here is no checking of subsystem existence.
	Sections = ModuleCurrentWorksServer.SectionsForObject(Metadata.DataProcessors.InfobaseBackupSetup.FullName());
	
	If Sections = Undefined Then
		Return;
	EndIf;
	
	RequiredToBackUp = NecessityOfAutomaticBackup();
	For Each Section IN Sections Do
		
		If Not NotificationOnBackupConfigurationDisabled Then
			Work = CurrentWorks.Add();
			Work.ID  = "SetupBackup" + StrReplace(Section.FullName(), ".", "");
			Work.ThereIsWork       = VariantNotifications = "YetNotConfigured";
			Work.Presentation  = NStr("en = 'Setup backup'");
			Work.Important         = True;
			Work.Form          = "DataProcessor.InfobaseBackupSetup.Form.Form";
			Work.Owner       = Section;
		EndIf;
		
		If Not BackupNotificationDisabled Then
			Work = CurrentWorks.Add();
			Work.ID  = "ExecuteBackingUpNow" + StrReplace(Section.FullName(), ".", "");
			Work.ThereIsWork       = VariantNotifications = "Overdue";
			Work.Presentation  = NStr("en = 'Backup is not completed'");
			Work.Important         = True;
			Work.Form          = "DataProcessor.InfobaseBackup.Form.DataBackup";
			Work.Owner       = Section;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion
