////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

///////////////////////////////////////////////////////////////////////////////
// Initialize session parameters.

// To call the session module from the SessionParameterSetting handler.
//
// Parameters:
//  SessionParameterNames - Array, Undefined - in the array names of the session parameters for initialization.
//
//  Returns an array of the specified session parameters names.
//
Function SessionParametersSetting(SessionParameterNames) Export
	
	// Session parameters initialization of which requires calling to the
	// same data it is required to initialize it by group. To prevent its re-initialization,
	// the names of the set session parameters are saved to the SetParameters array.
	SpecifiedParameters = New Array;
	
	If SessionParameterNames = Undefined Then
		SessionParameters.ClientParametersOnServer = New FixedMap(New Map);
		
		// During setting the connection with the infobase before calling the rest handlers.
		BeforeApplicationStart();
		Return SpecifiedParameters;
	EndIf;
	
	// Initialization of the session parameters required for work before the application work parameters are updated.
	If SessionParameterNames.Find("ClientParametersOnServer") <> Undefined Then
		SessionParameters.ClientParametersOnServer = New FixedMap(New Map);
		SpecifiedParameters.Add("ClientParametersOnServer");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = CommonUse.CommonModule("DataExchangeServer");
		Handlers = New Map;
		ModuleDataExchangeServer.OnAddSessionSettingsSetupHandler(Handlers);
		ExecuteHandlersSetSessionParameters(SessionParameterNames, Handlers, SpecifiedParameters);
	EndIf;
	
	UnknownParameters = CommonUseClientServer.ReduceArray(SessionParameterNames, SpecifiedParameters);
	If UnknownParameters.Count() = 0 Then
		Return SpecifiedParameters;
	EndIf;
	
	// Initialization of the rest of the session parameters (at the time of
	// the service events call application work parameters are already updated).
	Handlers = New Map;
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnAddSessionSettingsSetupHandler");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnAddSessionSettingsSetupHandler(Handlers);
	EndDo;
	
	CustomHandlers = CommonUseOverridable.SessionParameterInitHandlers();
	For Each Record IN CustomHandlers Do
		Handlers.Insert(Record.Key, Record.Value);
	EndDo;
	
	CustomHandlers = New Map;
	CommonUseOverridable.OnAddSessionSettingsSetupHandler(CustomHandlers);
	For Each Record IN CustomHandlers Do
		Handlers.Insert(Record.Key, Record.Value);
	EndDo;
	
	ExecuteHandlersSetSessionParameters(SessionParameterNames, Handlers, SpecifiedParameters);
	Return SpecifiedParameters;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Additional procedures and functions.

// Returns the flag showing whether the configuration is a basic one.
//
// Returns:
//   Boolean   - True if configuration - basic.
//
Function ThisIsBasicConfigurationVersion() Export
	
	Return Find(Upper(Metadata.Name), "BASE") > 0;
	
EndFunction

// Checks if execution takes place
// on the training platform on which, for example, getting the OSUser property is unavailable.
//
Function IsEducationalPlatform() Export
	
	SetPrivilegedMode(True);
	
	CurrentUser = InfobaseUsers.CurrentUser();
	
	Try
		OSUser = CurrentUser.OSUser;
	Except
		CurrentUser = Undefined;
	EndTry;
	
	Return CurrentUser = Undefined;
	
EndFunction

// Updates the metadata properties
// caches that allow to accelerate the session opening and IB update especially  in the service model.
// They are updated before IB is updated.
//
// To use in other libraries and configurations.
//
Procedure UpdateAllApplicationWorkParameters() Export
	
	UpdateApplicationWorkParameters();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Parameters of infobase administration and servers cluster.

// Receives the infobase administration parameters and servers cluster.
// But there are no passwords.
// Returns:
// Structure - Contains properties
//             of two structures ClusterAdministrationClientServer.ClusterAdministrationParameters(). and ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters()
//
Function AdministrationParameters() Export
	
	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		
		If Not Users.InfobaseUserWithFullAccess() Then
			Raise NStr("en='Insufficient rights to perform operation';ru='Недостаточно прав для выполнения операции'");
		EndIf;
		
	Else
		
		If Not Users.InfobaseUserWithFullAccess(, True) Then
			Raise NStr("en='Insufficient rights to perform operation';ru='Недостаточно прав для выполнения операции'");
		EndIf;
		
	EndIf;
	
	SetPrivilegedMode(True);
	InfobaseAdministrationParameters = Constants.InfobaseAdministrationParameters.Get().Get();
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = DefaultAdministrationParameters();
	EndIf;
	
	If Not CommonUse.FileInfobase() Then
		ReadParametersFromConnectionRow(InfobaseAdministrationParameters);
	EndIf;
	
	Return InfobaseAdministrationParameters;
	
EndFunction

// Sets parameters of the infobase administration and servers cluster.
// Parameters:
// InfobaseAdministrationParameters - Structure - see procedure return value AdministrationParameters().
// 
Procedure SetAdministrationParameters(InfobaseAdministrationParameters) Export
	
	InfobaseAdministrationParameters.ClusterAdministratorPassword = "";
	InfobaseAdministrationParameters.PasswordAdministratorInfobase = "";
	Constants.InfobaseAdministrationParameters.Set(New ValueStorage(InfobaseAdministrationParameters));
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Work with events of the service application interface.
// Use only within the library and separately from other libraries.

// Defines the list of service events.
// Each subsystem can provide custom set of its
// events for the external code to be subscribed to events (using the OnAddServiceEventsHandlers procedure). 
// Depending on the work context, events can be called from client or from the server code.
// Full list of these events is specified in the ServerEvents and ClientEvents parameters.
// Names of events should be specified in
// following the form: name_subsystem\name_event, for example: StandardSubsystems.BasicFunctionality\OnDefineActiveUsersForm.
//
// Parameters:
//  ClientEvents - Array - array of client events full names (String).
//  ServerEvents  - Array - array of server events full names (String).
//
// Useful example:
//
// // Defines the event that appears when you open
//   the active users form that belongs to the StandardSubsystems.BaseFunctionality subsystem.
//   It is possible to redefine the standard behavior in this event handlers.
//
//  Parameters:
// //  FormName - String - return value.
//
//  Syntax//:
// // Procedure OnOpenActiveUsersForm(FormName)
//
// Export
// 	ServerEvents.Add(StandardSubsystems.BasicFunctionality\OnDefineActiveUsersForm);
//
// You can copy the comment while creating a new handler.
// The Syntax section: used to create a new handler procedure.
//
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	WhenAddingOfficeEventBasicFunctionality(ClientEvents, ServerEvents);
	WorkInSafeModeService.OnAddOfficeEvent(ClientEvents, ServerEvents);
	
	If CommonUse.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = CommonUse.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
		ModuleReportsVariants.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.UserSessions") Then
		DBModuleConnections = CommonUse.CommonModule("InfobaseConnections");
		DBModuleConnections.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		CalendarSchedulesModule = CommonUse.CommonModule("CalendarSchedules");
		CalendarSchedulesModule.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.UserReminders") Then
		ModuleUserRemindersService = CommonUse.CommonModule("UserRemindersService");
		ModuleUserRemindersService.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = CommonUse.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	InfobaseUpdateService.OnAddOfficeEvent(ClientEvents, ServerEvents);
	
	UsersService.OnAddOfficeEvent(ClientEvents, ServerEvents);
	
	If CommonUse.SubsystemExists("StandardSubsystems.AttachedFiles") Then
		ModuleAttachedFilesService = CommonUse.CommonModule("AttachedFilesService");
		ModuleAttachedFilesService.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
		ModuleSaaSOperations.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ModuleMessageExchange = CommonUse.CommonModule("MessageExchange");
		ModuleMessageExchange.OnAddOfficeEvent(ClientEvents, ServerEvents);
		ModuleMessageInterfacesSaaS = CommonUse.CommonModule("MessageInterfacesSaaS");
		ModuleMessageInterfacesSaaS.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ModuleJobQueueService = CommonUse.CommonModule("JobQueueService");
		ModuleJobQueueService.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.SuppliedData") Then
		ModuleProvidedData = CommonUse.CommonModule("SuppliedData");
		ModuleProvidedData.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ModuleCurrentWorksService = CommonUse.CommonModule("CurrentWorksService");
		ModuleCurrentWorksService.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.MarkedObjectDeletion") Then
		ModuleMarkedObjectDeletionService = CommonUse.CommonModule("MarkedObjectDeletionService");
		ModuleMarkedObjectDeletionService.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementService = CommonUse.CommonModule("AccessManagementService");
		ModuleAccessManagementService.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileFunctions") Then
		ModuleFileFunctionsService = CommonUse.CommonModule("FileFunctionsService");
		ModuleFileFunctionsService.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
EndProcedure

// Defines the list of service events handlers (declared in OnAddServiceEvents - see above).
//
// Parameters:
//  ClientHandlers - Map - handlers list:
//   * Key     - String - event
//   full name, * Value - Array - array of the client common modules names with the procedure-handler of the event.
//
//  ServerHandlers  - Map - handlers list:
//   * Key     - String - event
//   full name, * Value - Array - array of the server common modules with the procedure-handler of the event.
//
// Name of the procedure-handler of the event matches the event name.
//
// Example of subscription to the OnDefineActiveUsersForm event of the BasicFunctionality subsystem:
//
// ServerHandlers[StandardSubsystems.BasicFunctionality\OnDefineActiveUsersForm].Add(InfobaseConnections);
// However, the OnDefineActiveUserForm procedure-handler
// should be defined in the InfobaseConnections common module with the parameters that match the events parameters.
//
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	OnAddHandlersOfServiceEventsOfBasicFunctionality(ClientHandlers, ServerHandlers);
	WorkInSafeModeService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
		ModuleAddressClassifierService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.EventsLogAnalysis") Then
		ModuleAnalysisOfLogCall = CommonUse.CommonModule("EventLogMonitorAnalysisService");
		ModuleAnalysisOfLogCall.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Questioning") Then
		ModuleSurvey = CommonUse.CommonModule("Questioning");
		ModuleSurvey.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleWorkWithBanks = CommonUse.CommonModule("WorkWithBanks");
		ModuleWorkWithBanks.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = CommonUse.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleWorkWithCurrencyRates = CommonUse.CommonModule("WorkWithCurrencyRates");
		ModuleWorkWithCurrencyRates.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
		ModuleReportsVariants.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = CommonUse.CommonModule("Interactions");
		ModuleInteractions.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		ModuleEmailManagement = CommonUse.CommonModule("EmailManagement");
		ModuleEmailManagement.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		ObjectVersioningModule = CommonUse.CommonModule("ObjectVersioning");
		ObjectVersioningModule.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
		WorkSchedulesModule.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ChangeProhibitionDates") Then
		ChangeProhibitionDateModuleService = CommonUse.CommonModule("ChangeProhibitionDatesService");
		ChangeProhibitionDateModuleService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		ModuleAdditionalReportsAndDataProcessorsInSafeModeService = CommonUse.CommonModule("AdditionalReportsAndDataProcessorsInSafeModeService");
		ModuleAdditionalReportsAndDataProcessorsInSafeModeService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.UserSessions") Then
		DBModuleConnections = CommonUse.CommonModule("InfobaseConnections");
		DBModuleConnections.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.UserNotes") Then
		ModuleUserNotesService = CommonUse.CommonModule("UserNotesCall");
		ModuleUserNotesService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.IntegrationWith1CBuhphone") Then
		IntegrationModule1CBuhphone = CommonUse.CommonModule("IntegrationWith1CBuhphone");
		IntegrationModule1CBuhphone.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.InformationOnStart") Then
		ModuleInformationOnLaunch = CommonUse.CommonModule("InformationOnStart");
		ModuleInformationOnLaunch.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		CalendarSchedulesModule = CommonUse.CommonModule("CalendarSchedules");
		CalendarSchedulesModule.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactInformationManagementService = CommonUse.CommonModule("ContactInformationManagementService");
		ModuleContactInformationManagementService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.UserReminders") Then
		ModuleUserRemindersService = CommonUse.CommonModule("UserRemindersService");
		ModuleUserRemindersService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.InfobaseVersionUpdate") Then
		ModuleDataBaseUpdate = CommonUse.CommonModule("InfobaseUpdateService");
		ModuleDataBaseUpdate.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = CommonUse.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleConfigurationUpdate = CommonUse.CommonModule("ConfigurationUpdate");
		ModuleConfigurationUpdate.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
		CompaniesServiceModule = CommonUse.CommonModule("CompaniesService");
		CompaniesServiceModule.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SendingSMS") Then
		CompaniesServiceModule = CommonUse.CommonModule("SendingSMS");
		CompaniesServiceModule.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.PerformanceEstimation") Then
		ModulePerformanceEstimationService = CommonUse.CommonModule("PerformanceEstimationService");
		ModulePerformanceEstimationService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Print") Then
		PrintManagementModule = CommonUse.CommonModule("PrintManagement");
		PrintManagementModule.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SearchAndDeleteDuplicates") Then
		ModuleSearchAndDeleteDuplicates = CommonUse.CommonModule("SearchAndDeleteDuplicates");
		ModuleSearchAndDeleteDuplicates.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.FullTextSearch") Then
		ModuleFullTextSearchServer = CommonUse.CommonModule("FullTextSearchServer");
		ModuleFullTextSearchServer.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleGetFilesFromInternetService = CommonUse.CommonModule("GetFilesFromInternetService");
		ModuleGetFilesFromInternetService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Users") Then
		ModuleUsersService = CommonUse.CommonModule("UsersService");
		ModuleUsersService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AttachedFiles") Then
		ModuleAttachedFilesService = CommonUse.CommonModule("AttachedFilesService");
		ModuleAttachedFilesService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
		ModuleSaaSOperations.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.AddressClassifierSaaS") Then
		ModuleAddressClassifierSaaSService = CommonUse.CommonModule("AddressClassifierSaaSService");
		ModuleAddressClassifierSaaSService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.BanksSaaS") Then
		ModuleBanksServiceSaaS = CommonUse.CommonModule("BanksServiceSaaS");
		ModuleBanksServiceSaaS.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.CurrenciesSaaS") Then
		ModuleCurrencyRatesServiceSaaS = CommonUse.CommonModule("CurrencyRatesServiceSaaS");
		ModuleCurrencyRatesServiceSaaS.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.CalendarSchedulesSaaS") Then
		ModuleCalendarSchedulesServiceSaaS = CommonUse.CommonModule("CalendarSchedulesServiceSaaS");
		ModuleCalendarSchedulesServiceSaaS.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ModuleMessageExchange = CommonUse.CommonModule("MessageExchange");
		ModuleMessageExchange.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		ModuleMessageInterfacesSaaS = CommonUse.CommonModule("MessageInterfacesSaaS");
		ModuleMessageInterfacesSaaS.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.InfobaseVersionUpdateSaaS") Then
		ModuleInfobaseUpdateServiceSaaS = CommonUse.CommonModule("InfobaseUpdateServiceSaaS");
		ModuleInfobaseUpdateServiceSaaS.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		
		ModuleJobQueueService = CommonUse.CommonModule("JobQueueService");
		ModuleJobQueueService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		
		If CommonUseReUse.IsSeparatedConfiguration() Then
			ModuleJobQueueServiceDataSeparation = CommonUse.CommonModule("JobQueueServiceDataSeparation");
			ModuleJobQueueServiceDataSeparation.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		EndIf;
		
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.SuppliedData") Then
		ModuleProvidedData = CommonUse.CommonModule("SuppliedData");
		ModuleProvidedData.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.DataAreasBackup") Then
		ModuleDataAreasBackup = CommonUse.CommonModule("DataAreasBackup");
		ModuleDataAreasBackup.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.RemoteAdministration") Then
		ModuleRemoteAdministrationService = CommonUse.CommonModule("RemoteAdministrationService");
		ModuleRemoteAdministrationService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.AccessManagementSaaS") Then
		AccessControlModuleServiceSaaS = CommonUse.CommonModule("AccessManagementServiceSaaS");
		AccessControlModuleServiceSaaS.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.FileFunctionsSaaS") Then
		ModuleFileFunctionsAuxilarySaaS = CommonUse.CommonModule("FileFunctionsServiceSaaS");
		ModuleFileFunctionsAuxilarySaaS.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperations = CommonUse.CommonModule("EmailOperationsService");
		ModuleEmailOperations.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		ModuleFileOperationsService = CommonUse.CommonModule("FileOperationsService");
		ModuleFileOperationsService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsMailing") Then
		ReportSendingModule = CommonUse.CommonModule("ReportMailing");
		ReportSendingModule.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsService = CommonUse.CommonModule("ScheduledJobsService");
		ModuleScheduledJobsService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.InfobaseBackup") Then
		ModuleInfobaseBackupServer = CommonUse.CommonModule("InfobaseBackupServer");
		ModuleInfobaseBackupServer.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagementService = CommonUse.CommonModule("PropertiesManagementService");
		ModulePropertyManagementService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementService = CommonUse.CommonModule("AccessManagementService");
		ModuleAccessManagementService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.TotalAndAggregateManagement") Then
		ModuleTotalsAndAggregateManagementService = CommonUse.CommonModule("TotalsAndAggregateManagementService");
		ModuleTotalsAndAggregateManagementService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileFunctions") Then
		ModuleFileFunctionsService = CommonUse.CommonModule("FileFunctionsService");
		ModuleFileFunctionsService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureService = CommonUse.CommonModule("DigitalSignatureService");
		ModuleDigitalSignatureService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.WorkWithCounterparties") Then
		ModuleCheckCounterparties = CommonUse.CommonModule("CounterpartiesCheck");
		ModuleCheckCounterparties.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	EndIf;
	
EndProcedure

// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  ImportedCatalogs - ValueTable - list of catalogs, to which the data can be imported.
//      *FullName          - String - full name of the catalog (as in the metadata).
//      Author presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	// Import to the MetadataObjectIDs catalog is prohibited.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.MetadataObjectIDs.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
EndProcedure

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.MetadataObjectIDs.FullName(), "EditedAttributesInGroupDataProcessing");
EndProcedure

// Receives the infobase identifier.
// If the identifier is not filled in, then it sets its value.
// The InfobaseIdentifier constant should not be included to exchange plans
// contents and have different values in each infobase.
//
Function InfobaseIdentifier() Export
	
	InfobaseIdentifier = Constants.InfobaseIdentifier.Get();
	
	If IsBlankString(InfobaseIdentifier) Then
		
		InfobaseIdentifier = New UUID();
		Constants.InfobaseIdentifier.Set(String(InfobaseIdentifier));
		
	EndIf;
	
	Return InfobaseIdentifier;
	
EndFunction

// It returns online support user login and password saved in the infobase.
//
// Returns:
//   Structure    - current value:
//     * Login     - String - Internet Support user login;
//     * Password    - String - password of the online support user.
//   Undefined - if the parameters have not been entered yet.
//
Function AuthenticationParametersOnSite() Export
	
	If CommonUse.SubsystemExists("OnlineUserSupport") Then
		ModuleOnlineUserSupport = CommonUse.CommonModule("OnlineUserSupport");
		Return ModuleOnlineUserSupport.OnlineSupportUserAuthenticationData();
	Else
		Result = New Structure("Login,Password");
		Result.Login = CommonUse.CommonSettingsStorageImport("AuthenticationAtUsersWebsite", "UserCode", "");
		Result.Password = CommonUse.CommonSettingsStorageImport("AuthenticationAtUsersWebsite", "Password", "");
		Return ?(Result.Login <> "", Result, Undefined);
	EndIf;
	
EndFunction

// Saves user authentication parameters (login and password) on 1C custom website.
//
// Parameters:
//     SavedParameters - Structure - saved values:
//         * Login  - String - Internet Support user login;
//         * Password - String - password of the online support user.
// 
Procedure SaveAuthenticationParametersOnSite(SavedParameters) Export
	
	CommonUseClientServer.Validate(NOT CommonUse.SubsystemExists("OnlineUserSupport"), 
		NStr("en='Invalid procedure call.';ru='Недопустимый вызов процедуры.'"), "AddressClassifierService.SaveAuthenticationParametersOnSite");
		
	If SavedParameters <> Undefined Then
		CommonUse.CommonSettingsStorageSave("AuthenticationAtUsersWebsite", "UserCode", SavedParameters.Login);
		CommonUse.CommonSettingsStorageSave("AuthenticationAtUsersWebsite", "Password", SavedParameters.Password);
	Else	
		CommonUse.CommonSettingsStorageDelete("AuthenticationAtUsersWebsite", "UserCode", UserName());
		CommonUse.CommonSettingsStorageDelete("AuthenticationAtUsersWebsite", "Password", UserName());
	EndIf;
			
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional basic functionality for analysis of client parameters on server.

// Returns a fixed match containing some client parameters:
//  LaunchParameter                    - String,
//  InfobaseConnectionString - String - connection row received on client.
//
// Returns an empty fixed match if CurrentStartMode() = Undefined.
//
Function ClientParametersOnServer() Export
	
	SetPrivilegedMode(True);
	ClientParameters = SessionParameters.ClientParametersOnServer;
	SetPrivilegedMode(False);
	
	If ClientParameters.Count() = 0
	   AND CurrentRunMode() <> Undefined Then
		
		Raise NStr("en='Client parameters at server are not filled.';ru='Не заполнены параметры клиента на сервере.'");
	EndIf;
	
	Return ClientParameters;
	
EndFunction

// Run background job with the client context. For example, ClientParametersOnServer are passed.
// Start is executed using the ExecuteConfigurationMethod procedure of the WorkInSafeMode common module.
//
// Parameters:
//  MethodName    - String - as in the Execute background jobs manager function.
//  Parameters    - Array - as in the Execute background jobs manager function.
//  Key         - String - as in the Execute background jobs manager function.
//  Description - String - as in the Execute background jobs manager function.
//
// Returns:
//  BackgroundJob.
//
Function RunBackgroundJobWithClientContext(MethodName, Parameters = Undefined, Key = "", Description = "") Export
	
	If CurrentRunMode() = Undefined Then
		Raise NStr("en='Run the background job with the client context is possible only when there is the client.';ru='Запуск фонового задания с контекстом клиента возможен только при наличии клиента.'");
	EndIf;
	
	AllParameters = New Structure;
	AllParameters.Insert("MethodName",    MethodName);
	AllParameters.Insert("Parameters",    Parameters);
	AllParameters.Insert("ClientParametersOnServer", ClientParametersOnServer());
	
	BackgroundJobProcedureParameters = New Array;
	BackgroundJobProcedureParameters.Add(AllParameters);
	
	Return BackgroundJobs.Execute("StandardSubsystemsServer.BeforeRunBackgroundJobWithClientContext",
		BackgroundJobProcedureParameters, Key, Description);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Additional basic functionality of the infobase update.

// Only for internal use.
// For the external calls you should use the UpdateAllApplicationWorkParameters procedure.
//
Procedure UpdateApplicationWorkParameters(FindChanges = False,
                                           ExclusiveModeSetupError = Undefined,
                                           InBackground = False) Export
	
	HasChanges  = False;
	CheckOnly = False;
	SwitchOffSoleMode = False;
	
	If FindChanges Then
		CheckOnly = True;
		
	ElsIf Not ExclusiveMode() Then
		Try
			SetExclusiveMode(True);
			SwitchOffSoleMode = True;
		Except
			SwitchOffSoleMode = False;
			CheckOnly = True;
		EndTry;
	EndIf;
	
	WithoutChanges = New Structure;
	Try
		CheckUpdateApplicationWorkParameters(HasChanges, CheckOnly, WithoutChanges, InBackground);
	Except
		If SwitchOffSoleMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If SwitchOffSoleMode Then
		SetExclusiveMode(False);
	EndIf;
	
	If Not FindChanges AND CheckOnly Then
		If HasChanges Then
			Try
				SetExclusiveMode(True);
			Except
				ErrorText =
					NStr("en='Unable to update the
		|infobase: - Unable to set
		|the exclusive mode - Configuration version does not include update without setting the exclusive mode.';ru='Невозможно выполнить
		|обновление информационной
		|базы: - Невозможно установить монопольный режим - Версия конфигурации не предусматривает обновление без установки монопольного режима.'");
				
				If ExclusiveModeSetupError = Undefined Then
					Raise ErrorText;
				Else
					ExclusiveModeSetupError = ErrorText;
					Return;
				EndIf;
			EndTry;
			Try
				UpdateApplicationWorkParameters(HasChanges);
			Except
				SetExclusiveMode(False);
				Raise;
			EndTry;
			SetExclusiveMode(False);
		Else
			// Exclusive mode is not required.
			CheckUpdateApplicationWorkParameters(HasChanges, False, WithoutChanges, InBackground);
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures for setting/update/receiving parameters of application work (caches).

// Returns parameters of application work for
// use (fixed data) that are, for example, a cache.
//
// Parameters:
//  ConstantName - String - constant name (group name of the application work parameters).
//
Function ApplicationWorkParameters(ConstantName) Export
	
	Return StandardSubsystemsReUse.ApplicationWorkParameters(ConstantName);
	
EndFunction

// Checks application work parameters for use
// (fixed data) that are, for example, a cache.
//
// Parameters:
//  ConstantName    - String - constant name (group name of the application work parameters).
//  ParameterNames - String - List of parameters names that should be in the constant.
//                    It is required when the updated data is
//                    received via the repeated use module to lock obtaining if not all  group parameters (constants) are updated.
//                    It is not required while receiving data in order to update it.
//  Cancel           - Undefined - call the exception if parameters are not updated.
//                  - Boolean - the return value - do not
//                    call an exception if the auto parameters are not updated and set True.
//
Procedure CheckForUpdatesApplicationWorkParameters(ConstantName, ParameterNames = "", Cancel = Undefined) Export
	
	If ParameterNames <> "" Then
		UpdateNeeded = False;
		
		If CommonUseReUse.DataSeparationEnabled() Then
			UpdateNeeded =
				InfobaseUpdateService.ShouldUpdateUndividedDataInformationBase();
		Else
			UpdateNeeded =
				InfobaseUpdate.InfobaseUpdateRequired();
		EndIf;
		
		If UpdateNeeded Then
			
			SetPrivilegedMode(True);
			AllUpdatedParameters = SessionParameters.ClientParametersOnServer.Get(
				"AllUpdatedApplicationWorkParameters");
			SetPrivilegedMode(False);
			
			If AllUpdatedParameters <> Undefined Then
				If AllUpdatedParameters.Get("*") <> Undefined Then
					UpdateNeeded = False;
				Else
					UpdatedParameters = AllUpdatedParameters.Get(ConstantName);
					If UpdatedParameters <> Undefined Then
						UpdateNeeded = False;
						RequiredParameters = New Structure(ParameterNames);
						For Each KeyAndValue IN RequiredParameters Do
							If UpdatedParameters.Get(KeyAndValue.Key) = Undefined Then
								UpdateNeeded = True;
								Break;
							EndIf;
						EndDo;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
		If UpdateNeeded Then
			If Cancel <> Undefined Then
				Cancel = True;
				Return;
			EndIf;
			If CurrentRunMode() = Undefined Then
				Raise
					NStr("en='Entrance to the application is temporarily impossible due to the update to the new version.';ru='Вход в программу временно невозможен в связи с обновлением на новую версию'");
			Else
				Raise
					NStr("en='Invalid access to non-updated application
		|work parameters (for example, to
		|some session parameters): - if they are accessed from the
		|form on the initial page (desktop) , then you need to make
		|sure there is the CommonUse procedure call in it.OnCreateAtServer;
		|- otherwise, it is required to
		|  transfer the applied code call after the update of application work parameters.';ru='Недопустимое обращение к необновленным параметрам работы программы (например, к некоторым параметрам сеанса): - если это обращение выполняется из формы на начальной странице (рабочем столе), то необходимо убедиться, что в ней имеется вызов процедуры ОбщегоНазначения.ПриСозданииНаСервере; - в остальных случаях необходимо перенести вызов прикладного кода после обновления параметров работы программы.'");
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Returns the application work parameter change considering the
// configuration current version and IB current version.
//
// Parameters:
//  Parameters    - value retrieved from the constant,
//                 name that was passed to the AddProgrammWorkParametersChanges procedure.
//
//  ParameterName - String that was passed as
//                 the ParameterName parameter to the AddChangesToProgrammWorkParameters procedure.
//
// Returns:
//  Undefined - means that everything has changed. Returned
//                 during IB or data area initial filling.
//  Array       - contains changes values. There may be
//                 several, for example, when the data area has not been updated for a long time.
//
Function ApplicationPerformenceParameterChanging(Parameters, ParameterName) Export
	
	LastChanges = Parameters["ChangesParameter" + ParameterName].Get();
	
	Version = Metadata.Version;
	NextVersion = NextVersion(Version);
	
	If CommonUseReUse.DataSeparationEnabled()
	   AND Not CommonUseReUse.CanUseSeparatedData() Then
		
		// Areas update plan is built only
		// for areas that have version not less then version of the undivided data.
		// All update handlers are run for the rest of the areas.
		
		// Version of undivided (common) data.
		IBVersion = InfobaseUpdateService.IBVersion(Metadata.Name, True);
	Else
		IBVersion = InfobaseUpdateService.IBVersion(Metadata.Name);
	EndIf;
	
	// Application work parameters change is not defined during the initial filling.
	If CommonUseClientServer.CompareVersions(IBVersion, "0.0.0.0") = 0 Then
		Return Undefined;
	EndIf;
	
	UpdateOutsideIBUpdate = CommonUseClientServer.CompareVersions(IBVersion, Version) = 0;
	
	// Changes to more major version
	// are not required except when the update is
	// executed outside IB update i.e. IB version equals to configuration version.
	// IN this case, changes to the next version are selected additionally.
	
	IndexOf = LastChanges.Count()-1;
	While IndexOf >=0 Do
		VarsionOfChange = LastChanges[IndexOf].ConfigurationVersion;
		
		If CommonUseClientServer.CompareVersions(IBVersion, VarsionOfChange) >= 0
		   AND Not (  UpdateOutsideIBUpdate
		         AND CommonUseClientServer.CompareVersions(NextVersion, VarsionOfChange) = 0) Then
			
			LastChanges.Delete(IndexOf);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Return LastChanges.UnloadColumn("Changes");
	
EndFunction

// Sets the helper data for application work stored in the undivided constants.
//
// Parameters:
//  ConstantName      - String - name of the undivided constant where the parameter value is saved.
//  ParameterName      - String - name of the parameter that needs to be set (without the ParameterChanges prefix).
//  ParameterValue - fixed data that is set as the parameter value.
//
Procedure SetApplicationPerformenceParameter(ConstantName, ParameterName, ParameterValue) Export
	
	Block = New DataLock;
	LockItem = Block.Add("Constant." + ConstantName);
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Parameters = Constants[ConstantName].Get().Get();
		If TypeOf(Parameters) <> Type("Structure") Then
			Parameters = New Structure;
		EndIf;
		
		Parameters.Insert(ParameterName, ParameterValue);
		
		ValueManager = Constants[ConstantName].CreateValueManager();
		ValueManager.DataExchange.Load = True;
		ValueManager.DataExchange.Recipients.AutoFill = False;
		ValueManager.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
		ValueManager.Value = New ValueStorage(Parameters);
		ValueManager.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	RefreshReusableValues();
	
EndProcedure

// Add change subsidiary data for works applicatione held in undivided constants.
//
// Parameters:
//  ConstantName       - String - name of the undivided constant where the parameter value is saved.
//  ParameterName       - String - name of the parameter that should be set.
//  ChangesParameter - fixed data that is registered as the parameter changes.
//                       Changes are not added if the ParameterChange value is not filled in.
//
//  Note: adding of parameters changes is
//         skipped during IB or unseparated data initial filling.
//
Procedure AddChangesToApplicationPerformenceParameters(ConstantName, ParameterName, Val ChangesParameter) Export
	
	// Receiving IB version or undivided data.
	IBVersion = InfobaseUpdateService.IBVersion(Metadata.Name);
	
	// Adding of parameters changes is skipped during an initial filling.
	If CommonUseClientServer.CompareVersions(IBVersion, "0.0.0.0") = 0 Then
		ChangesParameter = Undefined;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("Constant." + ConstantName);
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		UpdateChangesContent = False;
		Parameters = StandardSubsystemsReUse.ApplicationWorkParameters(ConstantName);
		
		ChangesStoringParameterName = "ChangesParameter" + ParameterName;
		
		If Parameters.Property(ChangesStoringParameterName) Then
			LastChanges = Parameters[ChangesStoringParameterName].Get();
			
			If TypeOf(LastChanges)              <> Type("ValueTable")
			 OR LastChanges.Columns.Count() <> 2
			 OR LastChanges.Columns[0].Name       <> "ConfigurationVersion"
			 OR LastChanges.Columns[1].Name       <> "Changes" Then
				
				LastChanges = Undefined;
			EndIf;
		Else
			LastChanges = Undefined;
		EndIf;
		
		If LastChanges = Undefined Then
			UpdateChangesContent = True;
			LastChanges = New ValueTable;
			LastChanges.Columns.Add("ConfigurationVersion");
			LastChanges.Columns.Add("Changes");
		EndIf;
		
		If ValueIsFilled(ChangesParameter) Then
			
			// If the update is executed
			// not in the IB update, then it
			// is required to add changes to the
			// next version. IN this case, updates executed not in the IB update will be considered during the transition to the next change version.
			Version = Metadata.Version;
			
			UpdateOutsideIBUpdate =
				CommonUseClientServer.CompareVersions(IBVersion , Version) = 0;
			
			If UpdateOutsideIBUpdate Then
				Version = NextVersion(Version);
			EndIf;
			
			UpdateChangesContent = True;
			String = LastChanges.Add();
			String.Changes          = ChangesParameter;
			String.ConfigurationVersion = Version;
		EndIf;
		
		MinimumIBVersion = InfobaseUpdateServiceReUse.MinimumIBVersion();
		
		// Delete changes for IB version that
		// are lower then the minimum version instead of
		// lower or equal version to provide the update outside the IB update.
		IndexOf = LastChanges.Count()-1;
		While IndexOf >=0 Do
			VarsionOfChange = LastChanges[IndexOf].ConfigurationVersion;
			
			If CommonUseClientServer.CompareVersions(MinimumIBVersion, VarsionOfChange) > 0 Then
				LastChanges.Delete(IndexOf);
				UpdateChangesContent = True;
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		
		If UpdateChangesContent Then
			SetApplicationPerformenceParameter(
				ConstantName,
				ChangesStoringParameterName,
				New ValueStorage(LastChanges));
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Registers the completion of application
// work parameters update for a possible use of their update in session.
//
Procedure ConfirmUpdatingApplicationWorkParameter(ConstantName, ParameterName) Export
	
	SetPrivilegedMode(True);
	
	SetPrivilegedMode(True);
	ClientParametersOnServer = New Map(SessionParameters.ClientParametersOnServer);
	
	AllUpdatedParameters = ClientParametersOnServer.Get("AllUpdatedApplicationWorkParameters");
	If AllUpdatedParameters = Undefined Then
		AllUpdatedParameters = New Map;
		UpdatedParameters = New Map;
	Else
		UpdatedParameters = AllUpdatedParameters.Get(ConstantName);
		AllUpdatedParameters = New Map(AllUpdatedParameters);
		If UpdatedParameters = Undefined Then
			UpdatedParameters = New Map;
		Else
			UpdatedParameters = New Map(UpdatedParameters);
		EndIf;
	EndIf;
	UpdatedParameters.Insert(ParameterName, True);
	AllUpdatedParameters.Insert(ConstantName, New FixedMap(UpdatedParameters));
	
	ClientParametersOnServer.Insert("AllUpdatedApplicationWorkParameters",
		New FixedMap(AllUpdatedParameters));
	
	SessionParameters.ClientParametersOnServer = New FixedMap(ClientParametersOnServer);
	
EndProcedure

// Deletes helper data for application work stored in the undivided constants.
//
// Parameters:
//  ConstantName - String - name of the undivided constant where the parameter value is saved.
//  ParameterName - String - name of the parameter that needs to be set (without the ParameterChanges prefix).
//
Procedure DeleteApplicationWorkParameter(ConstantName, ParameterName) Export
	
	Block = New DataLock;
	LockItem = Block.Add("Constant." + ConstantName);
	LockItem.Mode = DataLockMode.Exclusive;
	
	Write = False;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Parameters = Constants[ConstantName].Get().Get();
		If TypeOf(Parameters) <> Type("Structure") Then
			Return;
		EndIf;
		
		If Parameters.Property(ParameterName) Then
			Parameters.Delete(ParameterName);
			Write = True;
		EndIf;
		
		ChangesStoringParameterName = "ChangesParameter" + ParameterName;
		
		If Parameters.Property(ChangesStoringParameterName) Then
			Parameters.Delete(ChangesStoringParameterName);
			Write = True;
		EndIf;
		
		If Write Then
			ValueManager = Constants[ConstantName].CreateValueManager();
			ValueManager.DataExchange.Load = True;
			ValueManager.DataExchange.Recipients.AutoFill = False;
			ValueManager.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
			ValueManager.Value = New ValueStorage(Parameters);
			ValueManager.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Write Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional basic functionality for the data exchange.

// Checks if the content of exchange plan has mandatory
// metadata objects and objects-exceptions from the exchange plan content.
//
// Parameters:
//  ExchangePlanName - String, ExchangePlanRef. Exchange plan name or reference to the
//  exchange plan node for which it is required to execute the check.
//
Procedure ValidateExchangePlanContent(Val ExchangePlanName) Export
	
	If TypeOf(ExchangePlanName) <> Type("String") Then
		ExchangePlanName = ExchangePlanName.Metadata().Name;
	EndIf;
	
	DistributedInfobase = Metadata.ExchangePlans[ExchangePlanName].DistributedInfobase;
	ExchangePlanContent = Metadata.ExchangePlans[ExchangePlanName].Content;
	
	EnableContent = New Array;
	ExcludeFromComposition = New Array;
	DisableAutoregistration = New Array;
	
	// Receive the list of mandatory objects and objects-exceptions.
	MandatoryObjects = New Array;
	ExceptionObjects = New Array;
	ObjectsOfPrimaryImage = New Array;
	
	// Receive mandatory objects.
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnGettingObligatoryExchangePlanObjects");
	For Each Handler IN EventHandlers Do
		
		SignDistributedInfobase = DistributedInfobase;
		
		Handler.Module.OnGettingObligatoryExchangePlanObjects(MandatoryObjects, SignDistributedInfobase);
	EndDo;
	
	// Receive objects-exceptions.
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnGettingObjectExceptionsOfExchangePlan");
	For Each Handler IN EventHandlers Do
		
		SignDistributedInfobase = DistributedInfobase;
		
		Handler.Module.OnGettingObjectExceptionsOfExchangePlan(ExceptionObjects, SignDistributedInfobase);
	EndDo;
	
	If SignDistributedInfobase Then
		
		// Receive objects of an initial image.
		EventHandlers = CommonUse.ServiceEventProcessor(
			"StandardSubsystems.BasicFunctionality\OnGetPrimaryImagePlanExchangeObjects");
		For Each Handler IN EventHandlers Do
			
			Handler.Module.OnGetPrimaryImagePlanExchangeObjects(ObjectsOfPrimaryImage);
			
		EndDo;
		
		For Each Object IN ObjectsOfPrimaryImage Do
			
			MandatoryObjects.Add(Object);
			
		EndDo;
		
	EndIf;
	
	// Check the list of mandatory objects to compose the exchange plan.
	For Each Object IN MandatoryObjects Do
		
		If ExchangePlanContent.Find(Object) = Undefined Then
			
			EnableContent.Add(Object);
			
		EndIf;
		
	EndDo;
	
	// Check the list of objects-exceptions from the exchange plan content.
	For Each Object IN ExceptionObjects Do
		
		If ExchangePlanContent.Find(Object) <> Undefined Then
			
			ExcludeFromComposition.Add(Object);
			
		EndIf;
		
	EndDo;
	
	// Check the flag of auto-registration.
	// Auto-registration should be disabled in all initial image objects.
	For Each ContentItem IN ExchangePlanContent Do
		
		If ObjectsOfPrimaryImage.Find(ContentItem.Metadata) <> Undefined
			AND ContentItem.AutoRecord <> AutoChangeRecord.Deny Then
			
			DisableAutoregistration.Add(ContentItem.Metadata);
			
		EndIf;
		
	EndDo;
	
	// Generate and output exception text if needed.
	If EnableContent.Count() <> 0
		OR ExcludeFromComposition.Count() <> 0
		OR DisableAutoregistration.Count() <> 0 Then
		
		If EnableContent.Count() <> 0 Then
			
			DetailsExceptions1 = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='The %1 exchange plan must include the following metadata objects: %2';ru='В состав плана обмена %1 должны входить следующие объекты метаданных: %2'"),
				ExchangePlanName,
				StringFunctionsClientServer.RowFromArraySubrows(PresentationMetadataObjects(EnableContent), ", "));
			
		EndIf;
		
		If ExcludeFromComposition.Count() <> 0 Then
			
			DetailsExceptions2 = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='The exchange plan %1 must NOT include the following metadata objects: %2';ru='В состав плана обмена %1 НЕ должны входить следующие объекты метаданных: %2'"),
				ExchangePlanName,
				StringFunctionsClientServer.RowFromArraySubrows(PresentationMetadataObjects(ExcludeFromComposition), ", "));
			
		EndIf;
		
		If DisableAutoregistration.Count() <> 0 Then
			
			ExceptionDescription3 = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='There should be no objects with the set auto-registration flag in the %1 exchange plan content.
		|It is required to prohibit the auto-registration for the following metadata objects: %2';ru='В составе плана обмена %1 не должно быть объектов с установленным признаком авторегистрации.
		|Требуется запретить авторегистрацию для следующих объектов метаданных: %2'"),
				ExchangePlanName,
				StringFunctionsClientServer.RowFromArraySubrows(PresentationMetadataObjects(DisableAutoregistration), ", "));
			
		EndIf;
		
		DetailsExceptions = "[ExceptionDescription1] [ExceptionDescription2]  [ExceptionDescription3]
		|";
		
		DetailsExceptions = StrReplace(DetailsExceptions, "[ExceptDescription1]", DetailsExceptions1);
		DetailsExceptions = StrReplace(DetailsExceptions, "[ExceptDescription2]", DetailsExceptions2);
		DetailsExceptions = StrReplace(DetailsExceptions, "[ExceptDescription3]", ExceptionDescription3);
		
		Raise TrimAll(DetailsExceptions);
		
	EndIf;
	
EndProcedure

// Defines whether the passed object is an object of the initial image of the subordinate DIB node.
// 
// Parameters:
//  Object - MetadataObject - checked object.
// 
//  Returns:
//   Boolean - True if the object is used in DIB only when the initial image of the subordinate node is being created.
// 
Function ThisIsObjectOfPrimaryImageNodeRIB(Val Object) Export
	
	Return StandardSubsystemsReUse.ObjectsOfPrimaryImage(
		).Get(Object.FullName()) <> Undefined;
	
EndFunction

// Registers object changes on all exchange plan nodes.
// The following conditions should be met for the divided configurations:
//  exchange plan must
//  be divided, registered object must be undivided.
//
//  Parameters:
// Object - Data object (CatalogObject, DocumentObject etc.). Object that is required to be registered.
// Object should be undivided or an exception will be given.
//
// ExchangePlanName - String. Name of the exchange plan on all nodes of which it is required to register object.
// Exchange plan should be divided or an exception will be given.
//
Procedure RegisterObjectInAllNodes(Val Object, Val ExchangePlanName) Export
	
	If Metadata.ExchangePlans[ExchangePlanName].Content.Find(Object.Metadata()) = Undefined Then
		Return;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		If CommonUseReUse.CanUseSeparatedData() Then
			Raise NStr("en='Registration of the unseparated data modifications in the divided mode.';ru='Регистрация изменений неразделенных данных в разделенном режиме.'");
		EndIf;
		
		If Not CommonUseReUse.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName,
				CommonUseReUse.MainDataSeparator())
			Then
			Raise NStr("en='Registration of modifications for undivided exchange plans is not supported.';ru='Регистрация изменений для неразделенных планов обмена не поддерживается.'");
		EndIf;
		
		If CommonUseReUse.IsSeparatedMetadataObject(Object.Metadata().FullName(),
				CommonUseReUse.MainDataSeparator())
			Then
			Raise NStr("en='Registration of modifications for the separated objects is not supported.';ru='Регистрация изменений для разделенных объектов не поддерживается.'");
		EndIf;
		
		QueryText =
		"SELECT
		|	ExchangePlan.Ref AS Recipient
		|FROM
		|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
		|WHERE
		|	ExchangePlan.RegisterChanges
		|	AND Not ExchangePlan.DeletionMark";
		
		QueryText = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlanName);
		
		Query = New Query;
		Query.Text = QueryText;
		
		Recipients = Query.Execute().Unload().UnloadColumn("Recipient");
		
		For Each Recipient IN Recipients Do
			
			Object.DataExchange.Recipients.Add(Recipient);
			
		EndDo;
		
	Else
		
		QueryText =
		"SELECT
		|	ExchangePlan.Ref AS Recipient
		|FROM
		|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
		|WHERE
		|	ExchangePlan.Ref <> &ThisNode
		|	AND Not ExchangePlan.DeletionMark";
		
		QueryText = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlanName);
		
		Query = New Query;
		Query.SetParameter("ThisNode", ExchangePlans[ExchangePlanName].ThisNode());
		Query.Text = QueryText;
		
		Recipients = Query.Execute().Unload().UnloadColumn("Recipient");
		
		For Each Recipient IN Recipients Do
			
			Object.DataExchange.Recipients.Add(Recipient);
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Stores a reference to the main node in the MainNode constant for the restoration possibility.
Procedure SaveMasterNode() Export
	
	MainNodeManager = Constants.MasterNode.CreateValueManager();
	MainNodeManager.Value = ExchangePlans.MasterNode();
	InfobaseUpdate.WriteData(MainNodeManager);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of sending and receiving data for exchange in the distributed IB.

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see description of the OnSendDataToSubordinate event handler in the syntax helper.
// 
Procedure OnSendDataToSubordinate(DataItem, ItemSend, Val CreatingInitialImage, Val Recipient = Undefined) Export
	
	SendObjectsIgnoreInitialImage(DataItem, ItemSend, CreatingInitialImage);
	
	If ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
	
	// Metadata objects identifiers are sent in another section of the exchange message.
	IgnoreMetadataIdsSendObjects(DataItem, ItemSend, CreatingInitialImage);
	
	If ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
	
	// Insertion of the code from the data exchange subsystem should be the first.
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeEvents = CommonUse.CommonModule("DataExchangeEvents");
		ModuleDataExchangeEvents.OnDataSendingToCorrespondent(DataItem, ItemSend, CreatingInitialImage, Recipient, False);
		
		If ItemSend = DataItemSend.Ignore Then
			Return;
		EndIf;
	EndIf;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnSendDataToSubordinate");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnSendDataToSubordinate(
			DataItem, ItemSend, CreatingInitialImage, Recipient);
		If ItemSend = DataItemSend.Ignore Then
			Return;
		EndIf;
	EndDo;
	
	// Insertion of the code from the exchange data subsystem to service models should be the last.
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = CommonUse.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnSendDataToSubordinate(DataItem, ItemSend, CreatingInitialImage, Recipient);
		
		If ItemSend = DataItemSend.Ignore Then
			Return;
		EndIf;
	EndIf;
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see description of the OnSendDataMain() event handler in the syntax helper.
// 
Procedure OnSendDataToMaster(DataItem, ItemSend, Val Recipient = Undefined) Export
	
	SendObjectsIgnoreInitialImage(DataItem, ItemSend);
	
	If ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
	
	// Metadata objects identifiers are sent in another section of the exchange message.
	IgnoreMetadataIdsSendObjects(DataItem, ItemSend);
	
	If ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
	
	// Insertion of the code from the data exchange subsystem should be the first.
	// Do not call the handler during
	// sending data to the main one as restricting of migration "from top to bottom" in DIB by default is not provided.
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnSendDataToMaster");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnSendDataToMaster(DataItem, ItemSend, Recipient);
		If ItemSend = DataItemSend.Ignore Then
			Return;
		EndIf;
	EndDo;
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of the event handler WhenDataIsReceivedFromSecondary() in the syntax helper.
// 
Procedure OnReceiveDataFromSubordinate(DataItem, ItemReceive, SendBack, Val Sender = Undefined) Export
	
	IgnoreGetObjectsOfPrimaryImage(DataItem, ItemReceive);
	
	If ItemReceive = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnReceiveDataFromSubordinate");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnReceiveDataFromSubordinate(
			DataItem, ItemReceive, SendBack, Sender);
		If ItemReceive = DataItemReceive.Ignore Then
			Return;
		EndIf;
	EndDo;
	
	// Insertion of the code from the exchange data subsystem should be the last.
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeEvents = CommonUse.CommonModule("DataExchangeEvents");
		ModuleDataExchangeEvents.OnReceiveDataFromSubOrdinateEOF(DataItem, ItemReceive, Sender);
	EndIf;
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of event handler WhenDataIsReceivedFromMain() in syntax helper.
// 
Procedure OnReceiveDataFromMaster(DataItem, ItemReceive, SendBack, Val Sender = Undefined) Export
	
	IgnoreGetObjectsOfPrimaryImage(DataItem, ItemReceive);
	
	If ItemReceive = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	// Insertion of the code from the data exchange subsystem should be the first.
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeEvents = CommonUse.CommonModule("DataExchangeEvents");
		ModuleDataExchangeEvents.OnReceiveDataFromMasterAtStart(DataItem, ItemReceive, SendBack, Sender);
		
		If ItemReceive = DataItemReceive.Ignore Then
			Return;
		EndIf;
		
	EndIf;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnReceiveDataFromMaster");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnReceiveDataFromMaster(
			DataItem, ItemReceive, SendBack, Sender);
		If ItemReceive = DataItemReceive.Ignore Then
			Return;
		EndIf;
	EndDo;
	
	// Insertion of the code from the exchange data subsystem should be the last.
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange")
		AND Not CreatingInitialImage(DataItem) Then
		
		ModuleDataExchangeEvents = CommonUse.CommonModule("DataExchangeEvents");
		ModuleDataExchangeEvents.OnReceiveDataFromMasterAtTheEnd(DataItem, ItemReceive, Sender);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Service event handlers with basic functionality.

// Fills those metadata objects renaming that can not be automatically found by type, but the references to which are to be stored in the database (for example, subsystems, roles).
//
// For more see: CommonUse.AddRenaming().
//
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ApplicationSettings") Then
		ProcessorModuleAdministrationPanelSSL = CommonUse.CommonModule("DataProcessors.AdministrationPanelSSL");
		ProcessorModuleAdministrationPanelSSL.OnAddMetadataObjectsRenaming(Total);
	EndIf;
	
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystems(Parameters) Export
	
	AddClientWorkParameters(Parameters);
	
EndProcedure

// Fill the array of undivided data types for which
// matching refs during data import to another info base is supported.
//
// Parameters:
//  Types - Array(MetadataObject)
//
Procedure WhenFillingCommonDataTypesSupportingMatchingRefsOnImport(Types) Export
	
	Types.Add(Metadata.Catalogs.MetadataObjectIDs);
	
EndProcedure

// Used to receive metadata objects mandatory for an exchange plan.
// If the subsystem has metadata objects that have to be included
// in the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
//  Objects - Array - list of the configuration metadata objects that should be included to the exchange plan content.
//  DistributedInfobase - Boolean - (read only) Shows that objects for DIB exchange plan are received.
//                                               True - need to receive a list of RIB exchange plan;
//                                               False - it is required to receive a list for an exchange plan NOT RIB.
//
Procedure OnGettingObligatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Catalogs.MetadataObjectIDs);
		
	EndIf;
	
EndProcedure

// Used to receive metadata objects that should not be included into the exchange plan content.
// If the subsystem has metadata objects that should not be included in
// the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
//  Objects - Array - list of the configuration metadata objects that should not be included to the exchange plan content.
//  DistributedInfobase - Boolean - (read only) Shows that objects for DIB exchange plan are received.
//                                              True - required to get the list of the exception objects of the DIB exchange plan;
//                                              False - it is required to receive a list for an exchange plan NOT RIB.
//
Procedure OnGettingObjectExceptionsOfExchangePlan(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Constants.SystemTitle);
		Objects.Add(Metadata.Constants.UseSeparationByDataAreas);
		Objects.Add(Metadata.Constants.DontUseSeparationByDataAreas);
		Objects.Add(Metadata.Constants.ThisIsOfflineWorkplace);
		
		Objects.Add(Metadata.InformationRegisters.ProgramInterfaceCache);
		
	EndIf;
	
EndProcedure

// Used to receive metadata objects that should be included in the
// content of the exchange plan and should NOT be included in the content of subscriptions to the events of changes registration for this plan.
// These metadata objects are used only at the time of creation
// of the initial image of the subnode and do not migrate during the exchange.
// If the subsystem has metadata objects that take part in creating an initial
// image of the subnode, the <Object> parameter needs to be added to these metadata objects.
//
// Parameters:
// Objects - Array - list of configuration metadata objects.
//
Procedure OnGetPrimaryImagePlanExchangeObjects(Objects) Export
	
	Objects.Add(Metadata.Constants.ServiceEventsParameters);
	
EndProcedure

// Fills out a list of queries for external permissions that must be provided when creating an infobase or updating a application.
//
// Parameters:
//  PermissionsQueries - Array - list of values returned by the function.
//                      WorkInSafeMode.QueryOnExternalResourcesUse().
//
Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	permissions = New Array();
	
	permissions.Add(WorkInSafeMode.PermissionToUseTemporaryFilesDirectory(True, True,
		NStr("en='For the application to work.';ru='Для возможности работы программы.'")));
	permissions.Add(WorkInSafeMode.PermissionToUseExternalComponent("CommonTemplate.DeclinationComponentFullName", 
		NStr("en='To use functions by the full name declension.';ru='Для использования функций по склонению ФИО.'")));
	permissions.Add(WorkInSafeMode.PermissionToUsePrivelegedMode());
	
	PermissionsQueries.Add(
		WorkInSafeMode.QueryOnExternalResourcesUse(permissions));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional functions for work with types.

// Returns the reference type or key of the specified metadata object record.
// 
// Parameters:
//  MetadataObject - MetadataObject - register or reference object.
// 
//  Returns:
//   Type.
//
Function TypeOfRefOrRecordKeyOfMetadataObject(MetadataObject) Export
	
	If CommonUse.ThisIsRegister(MetadataObject) Then
		
		If CommonUse.ThisIsInformationRegister(MetadataObject) Then
			RegisterType = "InformationRegister";
			
		ElsIf CommonUse.ThisIsAccumulationRegister(MetadataObject) Then
			RegisterType = "AccumulationRegister";
			
		ElsIf CommonUse.ThisIsAccountingRegister(MetadataObject) Then
			RegisterType = "AccountingRegister";
			
		ElsIf CommonUse.ThisIsCalculationRegister(MetadataObject) Then
			RegisterType = "CalculationRegister";
		EndIf;
		Type = Type(RegisterType + "RecordKey." + MetadataObject.Name);
	Else
		Manager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
		Type = TypeOf(Manager.EmptyRef());
	EndIf;
	
	Return Type;
	
EndFunction

// Returns the type of object or the set of specified metadata object records.
// 
// Parameters:
//  MetadataObject - MetadataObject - register or reference object.
// 
//  Returns:
//   Type.
//
Function ObjectTypeOrSetOfMetadataObject(MetadataObject) Export
	
	If CommonUse.ThisIsRegister(MetadataObject) Then
		
		If CommonUse.ThisIsInformationRegister(MetadataObject) Then
			RegisterType = "InformationRegister";
			
		ElsIf CommonUse.ThisIsAccumulationRegister(MetadataObject) Then
			RegisterType = "AccumulationRegister";
			
		ElsIf CommonUse.ThisIsAccountingRegister(MetadataObject) Then
			RegisterType = "AccountingRegister";
			
		ElsIf CommonUse.ThisIsCalculationRegister(MetadataObject) Then
			RegisterType = "CalculationRegister";
		EndIf;
		Type = Type(RegisterType + "RecordSet." + MetadataObject.Name);
	Else
		Manager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
		ObjectKind = CommonUse.ObjectKindByKind(TypeOf(Manager.EmptyRef()));
		Type = Type(ObjectKind + "Object." + MetadataObject.Name);
	EndIf;
	
	Return Type;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of work with forms.

// Sets the font size of form group titles for the correct display in intrface 8.2.
//
// Parameters:
//  Form - ManagedForm - Form for changing the font of group titles;
//  GroupNames - String - List of form group names separated by commas.
//
Procedure SetGroupHeadersDisplay(Form, GroupNames = "") Export
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		BoldFont = New Font(,, True);
		If Not ValueIsFilled(GroupNames) Then 
			For Each Item IN Form.Items Do 
				If Type(Item) = Type("FormGroup") AND
					Item.Type = FormGroupType.UsualGroup AND
					Item.ShowTitle = True AND ( 
					Item.Representation = UsualGroupRepresentation.NormalSeparation OR 
					Item.Representation = UsualGroupRepresentation.None ) Then 
						Item.TitleFont = BoldFont;
				EndIf;
			EndDo;
		Else
			TitlesArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(GroupNames,,, True);
			For Each NameHeader IN TitlesArray Do
				Item = Form.Items[NameHeader];
				If Item.Representation = UsualGroupRepresentation.NormalSeparation OR Item.Representation = UsualGroupRepresentation.None Then 
					Item.TitleFont = BoldFont;
				EndIf;
			EndDo;
		EndIf;
	EndIf;

EndProcedure

// Sets the form destination key (use
// destination key and window position saving key). Copies the current form settings
// if needed if they have not been written for the corresponding new key yet.
//
// Parameters:
//  Form - ManagedForm - The OnCreateAtServer form to which the key is set.
//  Key  - String - new key of the form destination.
//
Procedure SetFormPurposeKey(Form, Key, PositionKey = "") Export
	
	SetFormUsePurposeKey(Form, Key);
	SetFormWindowSavingPositionKey(Form, ?(PositionKey = "", Key, PositionKey));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of work with the file system.

// Adds new directory of temporary files.
//   Used in conjunction with ClearTempFilesDirectory.
//
// Parameters:
//   Extension - String - Directory extension.
//       It is useful to specify subsystem abbreviation as an extension to understand "who didn't clean up after themselves".
//       It is recommended to specify in English to eliminate OS errors.
//
// Returns:
//   String - Full path to directory with the last slash.
//
Function CreateTempFilesDirectory(Extension) Export
	PathToDirectory = CommonUseClientServer.AddFinalPathSeparator(GetTempFileName(Extension));
	CreateDirectory(PathToDirectory);
	Return PathToDirectory;
EndFunction

// Adds new directory of temporary files.
//   Used in the bundle with CreateTempFilesDirectory.
//
// Parameters:
//   PathToDirectory - String - Full path to directory.
//
Procedure ClearTempFilesDirectory(PathToDirectory) Export
	Try
		DeleteFiles(PathToDirectory);
	Except
		WriteLogEvent(
			NStr("en='Standard subsystems';ru='Стандартные подсистемы'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Warning,
			,
			,
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='An error occurred while clearing the directory of temporary files %1:%2';ru='Ошибка очистки каталога временных файлов ""%1"":%2'"),
				PathToDirectory,
				Chars.LF + DetailErrorDescription(ErrorInfo())));
	EndTry;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedure and function.

// Returns refiner if problems with application work parameters occur.
Function SpecificationOfErrorParametersWorkApplicationForDeveloper() Export
	
	Return Chars.LF + Chars.LF +
		NStr("en = 'For developer: you may need to
		           |update the helper data that influence the application work. 
		           |To update, you can: 
		           |- use the external data processor ""Developer tools: Update subordinate data"",
		           |- start the application with the command bar parameter 1C:Enterprise 8
		           |  ""/C RunInfobaseUpdate"",
		           |- increase the number of configuration version
		           |  to update infobase data during the next start.'");
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns the number of the Standard subsystems library version.
//
Function LibraryVersion() Export
	
	Return StandardSubsystemsReUse.SubsystemDescriptions().ByNames["StandardSubsystems"].Version;
	
EndFunction

// Fills in the parameters structure that are
// required for work of the client code of the current subsystem while the configuration start i.e. in the events handlers.
// - BeforeSystemWorkStart,
// - OnStart
//
// Important: when starting you can not use
// cache reset command for reused modules otherwise
// the start can lead to unpredictable errors and excess server calls.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
// Returns:
//   Boolean   - False if the subsequent parameters filling should be aborted.
//
Function AddClientWorkParametersOnStart(Parameters) Export
	
	// Mandatory parameters to continue work.
	Parameters.Insert("DataSeparationEnabled", CommonUseReUse.DataSeparationEnabled());
	
	Parameters.Insert("CanUseSeparatedData", 
		CommonUseReUse.CanUseSeparatedData());
	
	Parameters.Insert("IsSeparatedConfiguration", CommonUseReUse.IsSeparatedConfiguration());
	Parameters.Insert("HasAccessForUpdateVersionsOfPlatform", Users.InfobaseUserWithFullAccess(,True));
	
	Parameters.Insert("NamesSubsystems", StandardSubsystemsReUse.NamesSubsystems());
	
	CommonParameters = CommonUse.GeneralBasicFunctionalityParameters();
	Parameters.Insert("MinimallyRequiredPlatformVersion", CommonParameters.MinimallyRequiredPlatformVersion);
	Parameters.Insert("MustExit",            CommonParameters.MustExit);
	
	If Parameters.ReceivedClientParameters <> Undefined
	   AND Parameters.ReceivedClientParameters.Count() = 0 Then
	
		SetPrivilegedMode(True);
		LaunchParameterClient = SessionParameters.ClientParametersOnServer.Get("LaunchParameter");
		If Find(Lower(LaunchParameterClient), Lower("RunInfobaseUpdate")) > 0 Then
			SetStartUpdatingInfobase(True);
		EndIf;
		SetPrivilegedMode(False);
	EndIf;
	
	If Parameters.ReceivedClientParameters <> Undefined Then
		Parameters.Insert("InterfaceOptions", CommonUseReUse.InterfaceOptions());
	EndIf;
	
	If Parameters.ReceivedClientParameters <> Undefined
	   AND Not Parameters.ReceivedClientParameters.Property("ShowNonrecommendedPlatformVersion")
	   AND ShowNonrecommendedPlatformVersion(Parameters) Then
		
		Parameters.Insert("ShowNonrecommendedPlatformVersion");
		StandardSubsystemsServerCall.HideDesktopOnStart();
		Return False;
	EndIf;
	
	// Check the work continuation.
	ErrorDescription = InfobaseUpdateService.InfobaseLockedForUpdate();
	If ValueIsFilled(ErrorDescription) Then
		Parameters.Insert("InfobaseLockedForUpdate", ErrorDescription);
		// Work will be complete.
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	If Parameters.ReceivedClientParameters <> Undefined
	   AND Not Parameters.ReceivedClientParameters.Property("RestoreConnectionWithMainNode")
	   AND Not CommonUseReUse.DataSeparationEnabled()
	   AND ExchangePlans.MasterNode() = Undefined
	   AND ValueIsFilled(Constants.MasterNode.Get()) Then
		
		SetPrivilegedMode(False);
		Parameters.Insert("RestoreConnectionWithMainNode", Users.InfobaseUserWithFullAccess());
		StandardSubsystemsServerCall.HideDesktopOnStart();
		Return False;
	EndIf;
	SetPrivilegedMode(False);
	
	If Parameters.ReceivedClientParameters <> Undefined
	   AND Not (Parameters.DataSeparationEnabled AND Not Parameters.CanUseSeparatedData)
	   AND CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
		ErrorDescription = "";
		ModuleSaaSOperations.WhenCheckingLockDataAreasOnRun(ErrorDescription);
		If ValueIsFilled(ErrorDescription) Then
			Parameters.Insert("DataAreaBlocked", ErrorDescription);
			// Work will be complete.
			Return False;
		EndIf;
	EndIf;
	
	If InfobaseUpdateService.WantedToValidateLegalityOfUpdateGetting() Then
		Parameters.Insert("CheckSoftwareUpdateLegality");
	EndIf;
	
	If Parameters.ReceivedClientParameters <> Undefined
	   AND Not Parameters.ReceivedClientParameters.Property("RetryDataExportExchangeMessagesBeforeStart")
	   AND CommonUse.IsSubordinateDIBNode()
	   AND CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		ModuleDataExchangeServerCalling = CommonUse.CommonModule("DataExchangeServerCall");
		If ModuleDataExchangeServerCalling.RetryDataExportExchangeMessagesBeforeStart() Then
			Parameters.Insert("RetryDataExportExchangeMessagesBeforeStart");
			Try
				Parameters.Insert("ClientEventHandlers", StandardSubsystemsReUse.ProgramEventsParameters(
					).EventsHandlers.AtClient);
			Except
				// There will be an exception after the first call.
				// During the second call parameters of service events are updated in the form.
				// DataResynchronizeBeforeStart
				// to support setting of data synchronization connection parameters (including for security profiles work).
			EndTry;
			Return False;
		EndIf;
	EndIf;
	
	// Check if it is required to preliminary update application work parameters.
	If Parameters.ReceivedClientParameters <> Undefined
	   AND Not Parameters.ReceivedClientParameters.Property("ShouldUpdateApplicationWorkParameters") Then
		
		If ShouldUpdateApplicationWorkParameters() Then
			// Preliminary update will be executed.
			Parameters.Insert("ShouldUpdateApplicationWorkParameters");
			Parameters.Insert("FileInfobase", CommonUse.FileInfobase());
			Return False;
		Else
			ConfirmUpdatingApplicationWorkParameter("*", "");
		EndIf;
	EndIf;
	
	// Mandatory parameters for all work modes.
	Parameters.Insert("ClientEventHandlers", StandardSubsystemsReUse.ProgramEventsParameters(
		).EventsHandlers.AtClient);
	
	Parameters.Insert("DetailedInformation", Metadata.DetailedInformation);
	
	If InfobaseUpdateService.ShouldUpdateUndividedDataInformationBase() Then
		Parameters.Insert("ShouldUpdateUndividedDataInformationBase");
	EndIf;
	
	Parameters.Insert("InterfaceOptions", CommonUseReUse.InterfaceOptions());
	
	WorkInSafeModeService.AddClientWorkParametersOnStart(Parameters);
	
	If Parameters.DataSeparationEnabled AND Not Parameters.CanUseSeparatedData Then
		Return False;
	EndIf;
	
	// Parameters for work in
	// the local mode or in session with the set separators values in the service model.
	
	If InfobaseUpdate.InfobaseUpdateRequired() Then
		Parameters.Insert("InfobaseUpdateRequired");
		StandardSubsystemsServerCall.HideDesktopOnStart();
	EndIf;
	
	If Not Parameters.DataSeparationEnabled
		AND CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		ModuleDataExchangeServer = CommonUse.CommonModule("DataExchangeServer");
		If ModuleDataExchangeServer.ImportDataExchangeMessage() Then
			Parameters.Insert("ImportDataExchangeMessage");
		EndIf;
	EndIf;
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataExchangeSaaS") Then
		ModuleOfflineWorkService = CommonUse.CommonModule("OfflineWorkService");
		If ModuleOfflineWorkService.ContinueOfflineWorkplaceSetting(Parameters) Then
			Return False;
		EndIf;
	EndIf;
	
	// SB. Creating first administrator for undivided base
	If Not Parameters.DataSeparationEnabled Then
		
		If Not UsersOverridable.AllowInfobaseStartWithoutUsers() Then
			
			If IsBlankString(InfobaseUsers.CurrentUser().Name) Then
				
				Users.CreateAdministrator();
				Parameters.Insert("FirstApplicationAdministratorAdded", True);
				Return False;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	// End SB.
	
	AuthorizationError = UsersService.AuthenticateCurrentUser(True);
	If AuthorizationError <> "" Then
		Parameters.Insert("AuthorizationError", AuthorizationError);
		Return False;
	EndIf;
	
	AddCommonClientParameters(Parameters);
	
	Return True;
	
EndFunction

// Sets the start state of infobase update.
// The privilege mode is required.
//
// Parameters:
//  Start - Boolean - If you set True, the
//           state will be selected if you set False, the state will be cleared.
//
Procedure SetStartUpdatingInfobase(Start) Export
	
	CurrentParameters = New Map(SessionParameters.ClientParametersOnServer);
	
	If Start = True Then
		CurrentParameters.Insert("RunInfobaseUpdate", True);
		
	ElsIf CurrentParameters.Get("RunInfobaseUpdate") <> Undefined Then
		CurrentParameters.Delete("RunInfobaseUpdate");
	EndIf;
	
	SessionParameters.ClientParametersOnServer = New FixedMap(CurrentParameters);
	
EndProcedure

// Fills in the structure of parameters required
// for the work of the current subsystem client code. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure AddClientWorkParameters(Parameters) Export
	
	Parameters.Insert("NamesSubsystems", StandardSubsystemsReUse.NamesSubsystems());
	Parameters.Insert("CanUseSeparatedData",
		CommonUseReUse.CanUseSeparatedData());
	Parameters.Insert("DataSeparationEnabled", CommonUseReUse.DataSeparationEnabled());
	
	Parameters.Insert("InterfaceOptions", CommonUseReUse.InterfaceOptions());
	
	AddCommonClientParameters(Parameters);
	
	Parameters.Insert("ConfigurationName",     Metadata.Name);
	Parameters.Insert("ConfigurationSynonym", Metadata.Synonym);
	Parameters.Insert("ConfigurationVersion",  Metadata.Version);
	Parameters.Insert("DetailedInformation", Metadata.DetailedInformation);
	Parameters.Insert("MainLanguageCode", Metadata.DefaultLanguage.LanguageCode);
	
	Parameters.Insert("AskConfirmationOnExit",
		AskConfirmationOnExit());
	
	// Parameters for external users connections.
	Parameters.Insert("UserInfo", GetInformationAboutUser());
	Parameters.Insert("COMConnectorName", CommonUseClientServer.COMConnectorName());
	
	SessionDate = CurrentSessionDate();
	UniversalSessionDate = ToUniversalTime(SessionDate, SessionTimeZone());
	// Write the server time for the subsequent its replacement for difference with the client.
	Parameters.Insert("SessionTimeOffset", SessionDate);
	Parameters.Insert("AdjustmentToUniversalTime", UniversalSessionDate - SessionDate);
	
EndProcedure

// Fills in the parameters structure that are
// required for work of the client code during the configuration start and later when you work with it. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure AddCommonClientParameters(Parameters) 
	
	If Not Parameters.DataSeparationEnabled Or Parameters.CanUseSeparatedData Then
		
		SetPrivilegedMode(True);
		Parameters.Insert("AuthorizedUser", Users.AuthorizedUser());
		Parameters.Insert("UserPresentation", String(Parameters.AuthorizedUser));
		Parameters.Insert("ApplicationCaption", TrimAll(Constants.SystemTitle.Get()));
		SetPrivilegedMode(False);
		
	EndIf;
	
	Parameters.Insert("IsMasterNode", Not CommonUse.IsSubordinateDIBNode());
	Parameters.Insert("FileInfobase", CommonUse.FileInfobase());
	
	Parameters.Insert("SiteConfigurationUpdateRequiredRIB",
		CommonUse.ConfigurationUpdateOfSlaveNodeWantedADB());
	
	Parameters.Insert("ThisIsBasicConfigurationVersion", ThisIsBasicConfigurationVersion());
	
EndProcedure

// Returns an array of names of versions numbers supported by the SubsystemName subsystem.
//
// Parameters:
// SubsystemName - String - Subsystem name.
//
// Returns:
//  Array - values list of the String type.
//
Function SupportedVersions(SubsystemName) Export
	
	VersionArray = Undefined;
	SupportedVersionStructure = New Structure;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnDefenitionSupportedVersionsOfSoftwareInterfaces");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnDefenitionSupportedVersionsOfSoftwareInterfaces(SupportedVersionStructure);
	EndDo;
	
	SupportedVersionStructure.Property(SubsystemName, VersionArray);
	
	If VersionArray = Undefined Then
		Return CommonUse.ValueToXMLString(New Array);
	Else
		Return CommonUse.ValueToXMLString(VersionArray);
	EndIf;
	
EndFunction

// Returns the match of events names to arrays of their handlers.
// 
// Returns:
//  Structure - information about events handlers:
//   * AtClient - Map -
//     ** Key     - String - event
//     full name, * Value - Array - list of structures with properties:
//        *** Version - String - version handler (empty if Not was specified),
//        *** Module - String - module name where the handler is located.
//   * AtServer - Map -
//     ** Key     - String - event
//     full name, * Value - Array - list of structures with properties:
//        *** Version - String - version handler (empty if Not was specified),
//        *** Module - String - module name where the handler is located.
//
Function EventsHandlers() Export
	
	SubsystemDescriptions = StandardSubsystemsReUse.SubsystemDescriptions();
	
	// Define all available application events.
	ClientEvents = New Array;
	ServerEvents  = New Array;
	ClientServiceEvents = New Array;
	ServerServiceEvents  = New Array;
	
	For Each Subsystem IN SubsystemDescriptions.Order Do
		Description = SubsystemDescriptions.ByNames[Subsystem];
		
		If Not Description.AddEvents
		   AND Not Description.AddInternalEvents Then
			
			Continue;
		EndIf;
		
		Module = CommonUse.CommonModule(
			Description.MainServerModule);
		
		If Description.Name = "StandardSubsystems" Then
			Module = StandardSubsystemsServer;
		EndIf;
		
		If Description.AddEvents Then
			Module.OnAddEvent(ClientEvents, ServerEvents);
		EndIf;
		
		If Description.AddInternalEvents Then
			Module.OnAddOfficeEvent(ClientServiceEvents, ServerServiceEvents);
		EndIf;
	EndDo;
	
	CheckUniquenessOfEventNames(ClientEvents);
	CheckUniquenessOfEventNames(ServerEvents);
	CheckUniquenessOfEventNames(ClientServiceEvents);
	CheckUniquenessOfEventNames(ServerServiceEvents);
	
	// Preparation of new arrays for adding handlers.
	HandlersForClientEventsBySubsystems = New Map;
	ServerSideEventHandlersBySubsystems  = New Map;
	ServiceClientEventHandlersBySubsystems = New Map;
	HandlersOfServerServiceEventsBySubsystems  = New Map;
	
	RequiredClientEvents = New Map;
	AreRequiredServerEvents  = New Map;
	AreRequiredClientServiceEvents = New Map;
	RequiredServerServiceEvents  = New Map;
	
	For Each Subsystem IN SubsystemDescriptions.Order Do
		
		HandlersForClientEventsBySubsystems.Insert(Subsystem,
			TemplateHandlersEvent(ClientEvents, RequiredClientEvents));
		
		ServerSideEventHandlersBySubsystems.Insert(Subsystem,
			TemplateHandlersEvent(ServerEvents, AreRequiredServerEvents));
		
		ServiceClientEventHandlersBySubsystems.Insert(Subsystem,
			TemplateHandlersEvent(ClientServiceEvents, AreRequiredClientServiceEvents));
		
		HandlersOfServerServiceEventsBySubsystems.Insert(Subsystem,
			TemplateHandlersEvent(ServerServiceEvents, RequiredServerServiceEvents));
		
	EndDo;
	
	// Add all handlers for the required application events.
	For Each Subsystem IN SubsystemDescriptions.Order Do
		Description = SubsystemDescriptions.ByNames[Subsystem];
		
		If Not Description.AdditHandlersEvent
		   AND Not Description.AdditHandlersOfficeEvents Then
			
			Continue;
		EndIf;
		
		Module = CommonUse.CommonModule(
			Description.MainServerModule);
		
		If Description.Name = "StandardSubsystems" Then
			Module = StandardSubsystemsServer;
		EndIf;
		
		If Description.AdditHandlersEvent Then
			Module.OnAddHandlersEvent(
				HandlersForClientEventsBySubsystems[Subsystem],
				ServerSideEventHandlersBySubsystems[Subsystem]);
		EndIf;
		
		If Description.AdditHandlersOfficeEvents Then
			Module.OnAddHandlersOfServiceEvents(
				ServiceClientEventHandlersBySubsystems[Subsystem],
				HandlersOfServerServiceEventsBySubsystems[Subsystem]);
		EndIf;
	EndDo;
	
	// Check mandatory events.
	AreRequiredEventsWithoutHandlers = New Array;
	
	AddAreRequiredEventsWithoutHandlers(AreRequiredEventsWithoutHandlers,
		RequiredClientEvents, HandlersForClientEventsBySubsystems);
	
	AddAreRequiredEventsWithoutHandlers(AreRequiredEventsWithoutHandlers,
		AreRequiredServerEvents, ServerSideEventHandlersBySubsystems);
	
	AddAreRequiredEventsWithoutHandlers(AreRequiredEventsWithoutHandlers,
		AreRequiredClientServiceEvents, ServiceClientEventHandlersBySubsystems);
	
	AddAreRequiredEventsWithoutHandlers(AreRequiredEventsWithoutHandlers,
		RequiredServerServiceEvents, HandlersOfServerServiceEventsBySubsystems);
	
	If AreRequiredEventsWithoutHandlers.Count() > 0 Then
		EventName  = NStr("en='EVENT HANDLERS';ru='Обработчики событий'", CommonUseClientServer.MainLanguageCode());
		
		Comment = NStr("en='Handlers have not been determined for the following obligatory events:';ru='Для следующих обязательных событий не определены обработчики:'")
			+ Chars.LF + StringFunctionsClientServer.RowFromArraySubrows(AreRequiredEventsWithoutHandlers, Chars.LF);
		
		WriteLogEvent(EventName, EventLogLevel.Error,,, Comment);
		Raise NStr("en='The handlers are not defined for the mandatory events.
		|Look for details in event log.';ru='Для обязательных событий не определены обработчики.
		|Подробности см. в журнале регистрации.'");
	EndIf;
	
	// Formatting the descriptions of application events handlers.
	AllEventHandlers = New Structure;
	AllEventHandlers.Insert("AtClient", New Structure);
	AllEventHandlers.Insert("AtServer", New Structure);
	
	AllEventHandlers.AtClient.Insert("EventsHandlers", StandardDetailsEventHandlers(
		SubsystemDescriptions, HandlersForClientEventsBySubsystems));
	
	AllEventHandlers.AtServer.Insert("EventsHandlers", StandardDetailsEventHandlers(
		SubsystemDescriptions, ServerSideEventHandlersBySubsystems));
	
	AllEventHandlers.AtClient.Insert("ServiceEventHandlers", StandardDetailsEventHandlers(
		SubsystemDescriptions, ServiceClientEventHandlersBySubsystems));
	
	AllEventHandlers.AtServer.Insert("ServiceEventHandlers", StandardDetailsEventHandlers(
		SubsystemDescriptions, HandlersOfServerServiceEventsBySubsystems));
	
	Return New FixedStructure(AllEventHandlers);
	
EndFunction

// Only for internal use.
Function ShouldUpdateApplicationWorkParameters(RunImport = True) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		// Update in the service model.
		If Not CommonUseReUse.CanUseSeparatedData()
			AND InfobaseUpdateService.ShouldUpdateUndividedDataInformationBase() Then
			
			Return True;
		EndIf;
	Else
		// Update in the local mode.
		If InfobaseUpdate.InfobaseUpdateRequired() Then
			Return True;
		EndIf;
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = CommonUse.CommonModule("DataExchangeServer");
		
		// Import is not required during the start
		// of created initial image of DIB subordinate node and the update needs to be executed.
		If ModuleDataExchangeServer.SettingADBSlaveNode() Then
			RunImport = False;
			Return True;
		EndIf;
	EndIf;
	
	// During the transition from the previous version in which
	// it was no SSL or from SSL version 2.1.1 (and earlier) that had no application work parameters.
	Try
		UsersServiceReUse.Parameters();
	Except
		RunImport = False;
		Return True;
	EndTry;
	
	Return False;
	
EndFunction

// Only for internal use.
Procedure ImportRefreshApplicationWorkParameters(ExclusiveModeSetupError = Undefined, InBackground = False) Export
	
	RunImport = True;
	
	If Not ShouldUpdateApplicationWorkParameters(RunImport) Then
		Return;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled()
	   AND CommonUseReUse.CanUseSeparatedData() Then
		Raise
			NStr("en='Program work parameters can not
		|be updated in the divided mode of the service model.';ru='Обновление параметров работы программы не может
		|быть выполнено в разделенном режиме модели сервиса.'");
	EndIf;
	
	If StandardSubsystemsReUse.DisableCatalogMetadataObjectIDs() Then
		RunImport = False;
	EndIf;
	
	SetPrivilegedMode(True);
	SwitchOffSoleMode = False;
	Try
		If CommonUse.IsSubordinateDIBNode() Then
			// There are DIB-data exchange and the update in the subordinate IB node.
			
			// Preliminary update of service events cache.
			Constants.ServiceEventsParameters.CreateValueManager().Refresh();
			
			If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
				ModuleDataExchangeServer = CommonUse.CommonModule("DataExchangeServer");
			EndIf;
			
			If RunImport Then
				
				StandardProcessing = True;
				CommonUseOverridable.BeforeExportingIDsMetadataObjectsInSubordinatedADBNode(
					StandardProcessing);
				
				If StandardProcessing = True
				   AND CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
					
					If Not ExclusiveMode() Then
						Try
							SetExclusiveMode(True);
							SwitchOffSoleMode = True;
						Except
							If ExclusiveModeSetupError <> Undefined Then
								ExclusiveModeSetupError =
									NStr("en='Unable to update the
		|infobase: - Unable to set
		|the exclusive mode - Configuration version does not include update without setting the exclusive mode.';ru='Невозможно выполнить
		|обновление информационной
		|базы: - Невозможно установить монопольный режим - Версия конфигурации не предусматривает обновление без установки монопольного режима.'");
							EndIf;
							Raise ExclusiveModeSetupError;
						EndTry;
					EndIf;
					
					// Import identifiers of metadata objects from the main node.
					ModuleDataExchangeServer.BeforeCheckingIdentifiersOfMetadataObjectsInSubordinateNodeDIB();
				EndIf;
				
				If InBackground Then
					CommonUseClientServer.MessageToUser("IncreaseInProgressStep=5");
				EndIf;
			EndIf;
			
			// Check the import of metadata objects identifiers from the main node.
			CriticalChangesList = "";
			Try
				Catalogs.MetadataObjectIDs.ExecuteDataRefreshing(False, False, True, , CriticalChangesList);
			Except
				If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
					// Reset cache of exchange message.
					ModuleDataExchangeServer.WhenErrorChecksIdsMetadataObjectsInSubordinateSiteDIB(RunImport);
				EndIf;
				Raise;
			EndTry;
			
			If ValueIsFilled(CriticalChangesList) Then
				
				If RunImport Then
					EventName = NStr("en='Metadata objects identifiers.It is required to import critical changes';ru='Идентификаторы объектов метаданных.Требуется загрузить критичные изменения'",
						CommonUseClientServer.MainLanguageCode());
				Else
					// Setting in the IB subordinate node during the first start.
					EventName = NStr("en='Metadata objects identifiers.It is required to execute critical changes';ru='Идентификаторы объектов метаданных.Требуется выполнить критичные изменения'",
						CommonUseClientServer.MainLanguageCode());
				EndIf;
				WriteLogEvent(EventName, EventLogLevel.Error, , , CriticalChangesList);
				
				If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
					// Reset cache of the exchange message, call exception explaining the further actions.
					ModuleDataExchangeServer.WhenErrorChecksIdsMetadataObjectsInSubordinateSiteDIB(RunImport, True);
				EndIf;
				
				If RunImport Then
					ErrorText =
						NStr("en='Changes of the Metadata objects identifiers catalog are not
		|imported from the main node: verification detected that it is required to
		|import critical changes (for the details, see events log monitor in the event Metadata objects identifiersIt is required to import critical changes).';ru='Из главного узла не загружены изменения справочника ""Идентификаторы объектов метаданных"":
		|при проверке обнаружено, что требуется загрузить критичные изменения (см. подробности в журнале
		|регистрации в событии ""Идентификаторы объектов метаданных.Требуется загрузить критичные изменения"").'");
				Else
					// Setting in the IB subordinate node during the first start.
					ErrorText =
						NStr("en='The Metadata objects identifiers catalog is not
		|updated in the main node: the check showed that you need to
		|execute the critical changes (for etails, see the evens log monitor in the Metadata objects identifiers.It is required to execute critical changes event).';ru='В главном узле не обновлен справочник ""Идентификаторы объектов метаданных"":
		|при проверке обнаружено, что требуется выполнить критичные изменения (см. подробности в журнале
		|регистрации в событии ""Идентификаторы объектов метаданных.Требуется выполнить критичные изменения"").'");
				EndIf;
				
				Raise ErrorText;
			EndIf;
			If InBackground Then
				CommonUseClientServer.MessageToUser("IncreaseInProgressStep=10");
			EndIf;
		EndIf;
		
		// There is
		// no DIB-exchange or the update in
		// the IB main node or update on
		// first start of the subordinate node or update after import of the Metadata objects identifiers catalog from the main node.
		UpdateApplicationWorkParameters(False, ExclusiveModeSetupError, InBackground);
	Except
		If SwitchOffSoleMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
EndProcedure

// Only for internal use.
Procedure ImportUpdateApplicationWorkInBackgroundParameters(ExecuteParameters, StorageAddress) Export
	
	If ExecuteParameters.Property("ClientParametersOnServer") Then
		SessionParameters.ClientParametersOnServer = ExecuteParameters.ClientParametersOnServer;
		InBackground = True;
	Else
		InBackground = False;
	EndIf;
	
	ExecutionResult = New Structure;
	ExecutionResult.Insert("AShortErrorMessage",   Undefined);
	ExecutionResult.Insert("DetailedErrorMessage", Undefined);
	
	ExclusiveModeSetupError = "";
	Try
		ImportRefreshApplicationWorkParameters(ExclusiveModeSetupError, InBackground);
	Except
		ErrorInfo = ErrorInfo();
		ExecutionResult.AShortErrorMessage   = BriefErrorDescription(ErrorInfo);
		ExecutionResult.DetailedErrorMessage = DetailErrorDescription(ErrorInfo);
	EndTry;
	
	If ErrorInfo = Undefined
	   AND ValueIsFilled(ExclusiveModeSetupError)
	   AND CommonUse.FileInfobase() Then
		
		LaunchParameterClient = SessionParameters.ClientParametersOnServer.Get("LaunchParameter");
		If Find(LaunchParameterClient, "ScheduledJobsDisabled") = 0 Then
			ExclusiveModeSetupError = "LockScheduledJobsProcessing";
		EndIf;
	EndIf;
	
	ExecutionResult.Insert("ExclusiveModeSetupError", ExclusiveModeSetupError);
	
	If Not ValueIsFilled(ExecutionResult.AShortErrorMessage)
	   AND ValueIsFilled(ExclusiveModeSetupError)
	   AND ExclusiveModeSetupError <> "LockScheduledJobsProcessing" Then
		
		ExecutionResult.AShortErrorMessage   = ExclusiveModeSetupError;
		ExecutionResult.DetailedErrorMessage = ExclusiveModeSetupError;
	EndIf;
	
	If ExecuteParameters.Property("ClientParametersOnServer") Then
		ExecutionResult.Insert("ClientParametersOnServer", SessionParameters.ClientParametersOnServer);
	EndIf;
	
	PutToTempStorage(ExecutionResult, StorageAddress);
	
EndProcedure

// Returns match of names and server modules.
Function NamesOfServerModules() Export
	
	ServerModules = New Map;
	FileInfobase = CommonUse.FileInfobase();
	
	For Each CommonModule IN Metadata.CommonModules Do
		If CommonModule.Global Then
			Continue;
		EndIf;
		
		If CommonModule.Server
	#If ThickClientManagedApplication Or ThickClientOrdinaryApplication Or ExternalConnection Then
		 Or FileInfobase
	#EndIf
		Then
			ServerModules.Insert(Eval(CommonModule.Name), CommonModule.Name);
		EndIf;
	EndDo;
	
	Return New FixedMap(ServerModules);
	
EndFunction

// Continue the RunBackgroundJobWithClientContext procedure.
Procedure BeforeRunBackgroundJobWithClientContext(AllParameters) Export
	
	SetPrivilegedMode(True);
	SessionParameters.ClientParametersOnServer = AllParameters.ClientParametersOnServer;
	SetPrivilegedMode(False);
	
	WorkInSafeMode.ExecuteConfigurationMethod(AllParameters.MethodName, AllParameters.Parameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// To update the MetadataObjectsIDs catalog.

// Only for internal use.
Function ExchangePlansManager() Export
	
	Return ExchangePlans;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "StandardSubsystemsServer.SetConstantNotUseSeparationByDataAreas";
	Handler.Priority = 99;
	Handler.SharedData = True;
	Handler.ExclusiveMode = True;
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "StandardSubsystemsServer.MarkVersionCacheRecordsObsolete";
	Handler.Priority = 99;
	Handler.SharedData = True;
	Handler.ExclusiveMode = False;
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.10";
	Handler.SharedData = True;
	Handler.Procedure = "StandardSubsystemsServer.UpdateInfobaseAdministrationParameters";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.4.17";
	Handler.SharedData = True;
	Handler.Procedure = "StandardSubsystemsServer.SetMainNodeConstantValue";
	
EndProcedure

// Sets the correct value to the NotUseSeparationByDataAreas constant.
//
Procedure SetConstantNotUseSeparationByDataAreas(Parameters) Export
	
	SetPrivilegedMode(True);
	
	NewValues = New Map;
	
	If Constants.UseSeparationByDataAreas.Get() Then
		
		NewValues.Insert("DontUseSeparationByDataAreas", False);
		NewValues.Insert("ThisIsOfflineWorkplace", False)
		
	ElsIf Constants.ThisIsOfflineWorkplace.Get() Then
		
		NewValues.Insert("DontUseSeparationByDataAreas", False);
		
	Else
		
		NewValues.Insert("DontUseSeparationByDataAreas", True);
		
	EndIf;
	
	For Each KeyAndValues IN NewValues Do
		
		If Constants[KeyAndValues.Key].Get() <> KeyAndValues.Value Then
			
			If Not Parameters.ExclusiveMode Then
				Parameters.ExclusiveMode = True;
				Return; // Change is required
			EndIf;
			
			Constants[KeyAndValues.Key].Set(KeyAndValues.Value);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Resets the update date of all
// cache versions records so all cache records are considered irrelevant.
//
Procedure MarkVersionCacheRecordsObsolete() Export
	
	BeginTransaction();
	
	RecordSet = InformationRegisters.ProgramInterfaceCache.CreateRecordSet();
	
	Block = New DataLock;
	Block.Add("InformationRegister.ProgramInterfaceCache");
	Block.Lock();
	
	RecordSet.Read();
	For Each Record IN RecordSet Do
		Record.UpdateDate = Undefined;
	EndDo;
	InfobaseUpdate.WriteData(RecordSet);
	
	CommitTransaction();
	
EndProcedure

// Deletes the saved passwords and changes the structure of settings storage.
//
Procedure UpdateInfobaseAdministrationParameters() Export
	
	SetPrivilegedMode(True);
	
	ParametersOldValue = Constants.InfobaseAdministrationParameters.Get().Get();
	NewParametersValue = DefaultAdministrationParameters();
	
	If ParametersOldValue <> Undefined Then
		
		If ParametersOldValue.Property("NameAdministratorInfobase") Then
			Return; // Update has already been executed.
		EndIf;
		
		If ParametersOldValue.Property("ServerAgentPort")
			AND ValueIsFilled(ParametersOldValue.ServerAgentPort) Then
			NewParametersValue.ServerAgentPort = ParametersOldValue.ServerAgentPort;
		EndIf;
		
		If ParametersOldValue.Property("ServerClusterPort")
			AND ValueIsFilled(ParametersOldValue.ServerClusterPort) Then
			NewParametersValue.ClusterPort = ParametersOldValue.ServerClusterPort;
		EndIf;
		
		If ParametersOldValue.Property("ClusterAdministratorName")
			AND Not IsBlankString(ParametersOldValue.ClusterAdministratorName) Then
			NewParametersValue.ClusterAdministratorName = ParametersOldValue.ClusterAdministratorName;
		EndIf;
		
		If ParametersOldValue.Property("IBAdministratorName")
			AND Not IsBlankString(ParametersOldValue.IBAdministratorName) Then
			NewParametersValue.NameAdministratorInfobase = ParametersOldValue.IBAdministratorName;
		EndIf;
		
	EndIf;
	
	SetAdministrationParameters(NewParametersValue);
	
EndProcedure

// Updates the constant value Main node in AWP nodes.
//
Procedure SetMainNodeConstantValue() Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		ModuleDataExchangeReUse = CommonUse.CommonModule("DataExchangeReUse");
		
		If ModuleDataExchangeReUse.ThisIsOfflineWorkplace() Then
			SaveMasterNode();
		EndIf;
		
	EndIf;
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Confirmation of application ending.

// Read the setting of application
// work completion confirmation for the current user.
// 
// Returns:
//   Boolean   - setting value.
// 
Function AskConfirmationOnExit() Export
	Result = CommonUse.CommonSettingsStorageImport("UserCommonSettings", "AskConfirmationOnExit");
	
	If Result = Undefined Then
		
		Result = CommonUse.GeneralBasicFunctionalityParameters(
			).AskConfirmationOnExit;
		
		StandardSubsystemsServerCall.SaveExitConfirmationSettings(Result);
	EndIf;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of the subscriptions to events.

// Handler of the BeforeWrite event of the predefined items.
Procedure DisablePredefinedItemsDeletionMarkupBeforeWriting(Source, Cancel) Export
	
	If Source.DataExchange.Load
	 Or Source.PredefinedDataName = ""
	 Or Source.DeletionMark <> True Then
		Return;
	EndIf;
	
	If Source.IsNew() Then
		Raise
			NStr("en='It is unacceptable to create the predefined item marked for deletion.';ru='Недопустимо создавать предопределенный элемент помеченный на удаление.'");
	Else
		OldProperties = CommonUse.ObjectAttributesValues(
			Source.Ref, "DeletionMark, PredefinedDataName");
		
		If OldProperties.PredefinedDataName <> ""
		   AND OldProperties.DeletionMark <> True Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='It is unacceptable to mark
		|the predefined item for deletion: %1';ru='Недопустимо помечать
		|на удаление предопределенный элемент: ""%1"".'"),
				String(Source.Ref));
			
		ElsIf OldProperties.PredefinedDataName = ""
		        AND OldProperties.DeletionMark = True Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='It is unacceptable to connect the item marked
		|for deletion with the name of the predefined: %1.';ru='Недопустимо связывать с именем предопределенного
		|элемент, помеченный на удаление: ""%1"".'"),
				String(Source.Ref));
		EndIf;
	EndIf;
	
EndProcedure

// Handler of the BeforeRemoval event of the predefined items.
Procedure DisablePredefinedItemsDeletionBeforeDeletion(Source, Cancel) Export
	
	If Source.DataExchange.Load
	 Or Source.PredefinedDataName = "" Then
		Return;
	EndIf;
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='It is unacceptable
		|to delete the predefined item %1.';ru='Недопустимо
		|удалять предопределенный элемент ""%1"".'"),
		String(Source.Ref));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Processor of subscriptions to DIB exchange plans events.

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see description of the OnSendDataToSubordinate event handler in the syntax helper.
// 
Procedure OnSendDataToSlaveEvent(Source, DataItem, ItemSend, CreatingInitialImage) Export
	
	OnSendDataToSubordinate(DataItem, ItemSend, CreatingInitialImage, Source);
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see description of the OnSendDataMain() event handler in the syntax helper.
// 
Procedure OnSendDataToMasterEvent(Source, DataItem, ItemSend) Export
	
	OnSendDataToMaster(DataItem, ItemSend, Source);
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of the event handler WhenDataIsReceivedFromSecondary() in the syntax helper.
// 
Procedure OnReceivingDataFromSlaveEvent(Source, DataItem, ItemReceive, SendBack) Export
	
	OnReceiveDataFromSubordinate(DataItem, ItemReceive, SendBack, Source);
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of event handler WhenDataIsReceivedFromMain() in syntax helper.
// 
Procedure OnReceiveDataFromMasterEvent(Source, DataItem, ItemReceive, SendBack) Export
	
	OnReceiveDataFromMaster(DataItem, ItemReceive, SendBack, Source);
	
EndProcedure

// Procedure-handler of subscription to the BeforeWrite event for ExchangePlanObject.
// Used to call the handler of the AfterReceivingData event during the exchange in the distributed IB.
//
Procedure AfterDataGetting(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.Metadata().DistributedInfobase Then
		
		If Source.ReceivedNo <> CommonUse.ObjectAttributeValue(Source.Ref, "ReceivedNo") Then
			
			If ExchangePlans.MasterNode() = Source.Ref Then
				
				EventHandlers = CommonUse.ServiceEventProcessor(
					"StandardSubsystems.BasicFunctionality\AfterDataReceivingFromMain");
				
				For Each Handler IN EventHandlers Do
					Handler.Module.AfterDataReceivingFromMain(Source, Cancel);
				EndDo;
				
			Else
				EventHandlers = CommonUse.ServiceEventProcessor(
					"StandardSubsystems.BasicFunctionality\AfterDataReceivingFromSubordinated");
				
				For Each Handler IN EventHandlers Do
					Handler.Module.AfterDataReceivingFromSubordinated(Source, Cancel);
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure-handler of subscription to the BeforeWrite event for ExchangePlanObject.
// Used to call the handler of the AfterDataSending event during the exchange in the distributed IB.
//
Procedure AfterDataSending(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.Metadata().DistributedInfobase Then
		
		If Source.SentNo <> CommonUse.ObjectAttributeValue(Source.Ref, "SentNo") Then
			
			If ExchangePlans.MasterNode() = Source.Ref Then
				
				EventHandlers = CommonUse.ServiceEventProcessor(
					"StandardSubsystems.BasicFunctionality\AfterDataSendingToMain");
				
				For Each Handler IN EventHandlers Do
					Handler.Module.AfterDataSendingToMain(Source, Cancel);
				EndDo;
				
			Else
				
				EventHandlers = CommonUse.ServiceEventProcessor(
					"StandardSubsystems.BasicFunctionality\AfterDataSendingToSubordinated");
				
				For Each Handler IN EventHandlers Do
					Handler.Module.AfterDataSendingToSubordinated(Source, Cancel);
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

Procedure BeforeApplicationStart()
	
	// Privileged mode (set by a platform).
	
	// Check the main applicationming language installed in configuration.
	If Metadata.ScriptVariant <> Metadata.ObjectProperties.ScriptVariant.English Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Variant of the %1 ultimate fallback language of configuration is not supported.
		|It is required to use %2 language variant.';ru='Вариант встроенного языка конфигурации ""%1"" не поддерживается.
		|Необходимо использовать вариант языка ""%2"".'"),
			Metadata.ScriptVariant,
			Metadata.ObjectProperties.ScriptVariant.English);
	EndIf;
		
	// Check the compatibility settings of configuration with the platform version.
	SystemInfo = New SystemInfo;
	MinimalPlatformVersion = "8.3.5.1443";
	If CommonUseClientServer.CompareVersions(SystemInfo.AppVersion, MinimalPlatformVersion) < 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='To start, 1C:Enterprise platform version should be %1 or greater.';ru='Для запуска необходима версия платформы 1С:Предприятие %1 или выше.'"), MinimalPlatformVersion);
	EndIf;
	
	Modes = Metadata.ObjectProperties.CompatibilityMode;
	CurrentMode = Metadata.CompatibilityMode;
	
	If CurrentMode = Modes.DontUse Then
		UnavailableMode = "";
	ElsIf CurrentMode = Modes.Version8_1 Then
		UnavailableMode = "8.1"
	ElsIf CurrentMode = Modes.Version8_2_13 Then
		UnavailableMode = "8.2.13"
	ElsIf CurrentMode = Modes.Version8_2_16 Then
		UnavailableMode = "8.2.16";
	ElsIf CurrentMode = Modes.Version8_3_1 Then
		UnavailableMode = "8.3.1";
	ElsIf CurrentMode = Modes.Version8_3_2 Then
		UnavailableMode = "8.3.2";
	ElsIf CurrentMode = Modes.Version8_3_3 Then
		UnavailableMode = "8.3.3";
	ElsIf CurrentMode = Modes.Version8_3_4 Then
		UnavailableMode = "8.3.4";
	Else
		UnavailableMode = "";
	EndIf;
	
	If ValueIsFilled(UnavailableMode) Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Configuration compatibility mode with 1C:Enterprise version %1 is not supported.
		|To start it, set the mode of compatibility
		|with 1C:Enterprise version not less then 8 in configuration.3.5 or Do not use.';ru='Режим совместимости конфигурации с 1С:Предприятием версии %1 не поддерживается. Для запуска установите в конфигурации режим совместимости с 1С:Предприятием версии не ниже 8.3.5 или ""Не использовать"".'"),
			UnavailableMode);
	EndIf;
	
	// Check if the configuration version is filled in.
	If IsBlankString(Metadata.Version) Then
		Raise NStr("en='Version configuration property is not filled.';ru='Не заполнено свойство конфигурации Версия.'");
	Else
		Try
			ZeroVersion = CommonUseClientServer.CompareVersions(Metadata.Version, "0.0.0.0") = 0;
		Except
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='The property of the Version configuration is filled in incorrectly: %1
		|Correct format, for example: ""1.2.3.45"".';ru='Не правильно заполнено свойство конфигурации Версия: ""%1"".
		|Правильный формат, например: ""1.2.3.45"".'"),
				Metadata.Version);
		EndTry;
		If ZeroVersion Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='The property of the Version configuration is filled in incorrectly: %1
		|Version can not be the zero.';ru='Не правильно заполнено свойство конфигурации Версия: ""%1"".
		|Версия не может быть нулевой.'"),
				Metadata.Version);
		EndIf;
	EndIf;
	
	If Metadata.DefaultRoles.Count() <> 2
	 Or Not Metadata.DefaultRoles.Contains(Metadata.Roles.SystemAdministrator)
	 Or Not Metadata.DefaultRoles.Contains(Metadata.Roles.FullRights) Then
		Raise
			NStr("en='In configuration in the DefaultRoles property the SystemAdministrator
		|and FullRights standard roles are not specified or extra roles are specified.';ru='В конфигурации в свойстве ОсновныеРоли не
		|указаны стандартные роли АдминистраторСистемы и ПолныеПрава или указаны лишние роли.'");
	EndIf;
	
	// Check if it is possible to execute the handlers of session parameters setting for the application start.
	WorkInSafeMode.CheckPossibilityToExecuteSessionSettingsSetupHandlers();
	
	If Not ValueIsFilled(InfobaseUsers.CurrentUser().Name)
	   AND (NOT CommonUseReUse.DataSeparationEnabled()
	      Or Not CommonUseReUse.CanUseSeparatedData())
	   AND InfobaseUpdateService.IBVersion("StandardSubsystems",
	       CommonUseReUse.DataSeparationEnabled()) = "0.0.0.0" Then
		
		UsersService.SetInitialSettings("");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
		ModuleSaaSOperations.OnCheckingSafeModeDataSharing();
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.DataAreasBackup") Then
		// Select the check box of users activity in the area.
		ModuleDataAreasBackup = CommonUse.CommonModule("DataAreasBackup");
		ModuleDataAreasBackup.SetUserActivityFlagInZone();
	EndIf;
EndProcedure

Procedure ExecuteHandlersSetSessionParameters(SessionParameterNames, Handlers, SpecifiedParameters)
	
	Var MessageText;
	
	// Array with session
	// parameters keys are specified with the initial word in the session parameter name and with * symbol.
	SessionParameterKeys = New Array;
	
	For Each Record IN Handlers Do
		If Find(Record.Key, "*") > 0 Then
			ParameterKey = TrimAll(Record.Key);
			SessionParameterKeys.Add(Left(ParameterKey, StrLen(ParameterKey)-1));
		EndIf;
	EndDo;
	
	For Each ParameterName IN SessionParameterNames Do
		If SpecifiedParameters.Find(ParameterName) <> Undefined Then
			Continue;
		EndIf;
		Handler = Handlers.Get(ParameterName);
		If Handler <> Undefined Then
			
			HandlerParameters = New Array();
			HandlerParameters.Add(ParameterName);
			HandlerParameters.Add(SpecifiedParameters);
			WorkInSafeMode.ExecuteConfigurationMethod(Handler, HandlerParameters);
			Continue;
			
		EndIf;
		For Each ParameterKeyName IN SessionParameterKeys Do
			If Left(ParameterName, StrLen(ParameterKeyName)) = ParameterKeyName Then
				
				Handler = Handlers.Get(ParameterKeyName+"*");
				HandlerParameters = New Array();
				HandlerParameters.Add(ParameterName);
				HandlerParameters.Add(SpecifiedParameters);
				WorkInSafeMode.ExecuteConfigurationMethod(Handler, HandlerParameters);
				
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

Function GetInformationAboutUser()
	
	// Calculate the actual name of the user even if it was previously changed in the current session;
	// For example, to connect to the current IB through the external connection from this session;
	// IN all other cases it is enough to get InfobaseUsers.CurrentUser().
	CurrentUser = InfobaseUsers.FindByUUID(
		InfobaseUsers.CurrentUser().UUID);
	
	If CurrentUser = Undefined Then
		CurrentUser = InfobaseUsers.CurrentUser();
	EndIf;
	
	Information = New Structure;
	Information.Insert("Name",                       CurrentUser.Name);
	Information.Insert("FullName",                 CurrentUser.FullName);
	Information.Insert("PasswordIsSet",          CurrentUser.PasswordIsSet);
	Information.Insert("OpenIDAuthentication",      CurrentUser.OpenIDAuthentication);
	Information.Insert("StandardAuthentication", CurrentUser.StandardAuthentication);
	Information.Insert("OSAuthentication",          CurrentUser.OSAuthentication);
	
	Return Information;
	
EndFunction

Function PresentationMetadataObjects(Objects)
	
	Result = New Array;
	
	For Each Object IN Objects Do
		
		Result.Add(Object.FullName());
		
	EndDo;
	
	Return Result;
EndFunction

Procedure IgnoreMetadataIdsSendObjects(DataItem, ItemSend, Val CreatingInitialImage = False)
	
	If Not CreatingInitialImage
		AND MetadataObject(DataItem) = Metadata.Catalogs.MetadataObjectIDs Then
		
		ItemSend = DataItemSend.Ignore;
		
	EndIf;
	
EndProcedure

Procedure SendObjectsIgnoreInitialImage(DataItem, ItemSend, Val CreatingInitialImage = False)
	
	If Not CreatingInitialImage
		AND ThisIsObjectOfPrimaryImageNodeRIB(MetadataObject(DataItem))
		AND Not ThisIsPredefinedItem(DataItem) Then
		
		ItemSend = DataItemSend.Ignore;
		
	EndIf;
	
EndProcedure

Function IgnoreGetObjectsOfPrimaryImage(DataItem, ItemReceive)
	
	If Not CreatingInitialImage(DataItem)
		AND ThisIsObjectOfPrimaryImageNodeRIB(MetadataObject(DataItem)) Then
		
		ItemReceive = DataItemReceive.Ignore;
		
	EndIf;
	
EndFunction

Function MetadataObject(Val DataItem)
	
	Return ?(TypeOf(DataItem) = Type("ObjectDeletion"), DataItem.Ref.Metadata(), DataItem.Metadata());
	
EndFunction

Function CreatingInitialImage(Val DataItem)
	
	Return ?(TypeOf(DataItem) = Type("ObjectDeletion"), False, DataItem.AdditionalProperties.Property("CreatingInitialImage"));
	
EndFunction

Function ShowNonrecommendedPlatformVersion(Parameters)
	
	If Parameters.DataSeparationEnabled Then
		Return False;
	EndIf;
	
	// Check if the user is not external one.
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("InfobaseUserID",
		InfobaseUsers.CurrentUser().UUID);
	
	Query.Text = 
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.InfobaseUserID = &InfobaseUserID";
	
	If Not Query.Execute().IsEmpty() Then
		Return False;
	EndIf;
	
	SystemInfo = New SystemInfo;
	Return CommonUseClientServer.CompareVersions(SystemInfo.AppVersion,
		Parameters.MinimallyRequiredPlatformVersion) < 0;
	
EndFunction

Function ThisIsPredefinedItem(DataItem)
	
	IsPredefined = False;
	BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(DataItem.Metadata());
	
	If BaseTypeName = CommonUse.TypeNameCatalogs()
		OR BaseTypeName = CommonUse.TypeNameChartsOfCharacteristicTypes()
		OR BaseTypeName = CommonUse.TypeNameChartsOfAccounts()
		OR BaseTypeName = CommonUse.TypeNameChartsOfCalculationTypes() Then
		
		If DataItem.Predefined Then
			
			IsPredefined = True;
			
		EndIf;
		
	EndIf;
	
	Return IsPredefined;
	
EndFunction

Function DefaultAdministrationParameters()
	
	ClusterAdministrationParameters = ClusterAdministrationClientServer.ClusterAdministrationParameters();
	InfobaseAdministrationParameters = ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters();
	
	// Merge structure parameters.
	AdministrationParametersStructure = ClusterAdministrationParameters;
	For Each Item IN InfobaseAdministrationParameters Do
		AdministrationParametersStructure.Insert(Item.Key, Item.Value);
	EndDo;
	
	Return AdministrationParametersStructure;
	
EndFunction

Procedure ReadParametersFromConnectionRow(AdministrationParametersStructure)
	
	ConnectionStringSubstrings = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(
		InfobaseConnectionString(), ";");
	
	RowNameServer = StringFunctionsClientServer.ContractDoubleQuotationMarks(Mid(ConnectionStringSubstrings[0], 7));
	AdministrationParametersStructure.NameInCluster = StringFunctionsClientServer.ContractDoubleQuotationMarks(Mid(ConnectionStringSubstrings[1], 6));
	
	ListClusterServers = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(RowNameServer, ",");
	
	ServerName = ListClusterServers[0];
	PortSeparator = Find(ServerName, ":");
	If PortSeparator > 0 Then
		ServerAgentAddress = Mid(ServerName, 1, PortSeparator - 1);
		ClusterPort = Number(Mid(ServerName, PortSeparator + 1));
		If AdministrationParametersStructure.ClusterPort = 1541 Then
			AdministrationParametersStructure.ClusterPort = ClusterPort;
		EndIf;
	Else
		ServerAgentAddress = ServerName;
	EndIf;
	
	AdministrationParametersStructure.ServerAgentAddress = ServerAgentAddress;
	
EndProcedure

// For the SetFormPurposeKey procedure.
Procedure SetFormUsePurposeKey(Form, Key)
	
	If Not ValueIsFilled(Key)
	 Or Form.PurposeUseKey = Key Then
		
		Return;
	EndIf;
	
	SettingsTypes = New Array;
	// English option.
	SettingsTypes.Add("/CurrentVariantKey");
	SettingsTypes.Add("/CurrentUserSettingsKey");
	SettingsTypes.Add("/CurrentUserSettings");
	SettingsTypes.Add("/CurrentDataSettingsKey");
	SettingsTypes.Add("/CurrentData");
	SettingsTypes.Add("/FormSettings");
	// English option.
	SettingsTypes.Add("/CurrentVariantKey");
	SettingsTypes.Add("/CurrentUserSettingsKey");
	SettingsTypes.Add("/CurrentUserSettings");
	SettingsTypes.Add("/CurrentDataSettingsKey");
	SettingsTypes.Add("/CurrentData");
	SettingsTypes.Add("/FormSettings");
	
	SetSettingsForKey(Key, SettingsTypes, Form.FormName, Form.PurposeUseKey);
	
	Form.PurposeUseKey = Key;
	
EndProcedure

// For the SetFormPurposeKey procedure.
Procedure SetFormWindowSavingPositionKey(Form, Key)
	
	If Not ValueIsFilled(Key)
	 Or Form.WindowOptionsKey = Key Then
		
		Return;
	EndIf;
	
	SettingsTypes = New Array;
	// English option.
	SettingsTypes.Add("/WindowSettings");
	SettingsTypes.Add("/Taxi/WindowSettings");
	SettingsTypes.Add("/WebClientWindowSettings");
	SettingsTypes.Add("/Taxi/WebClientWindowSettings");
	// English option.
	SettingsTypes.Add("/WindowSettings");
	SettingsTypes.Add("/Taxi/WindowSettings");
	SettingsTypes.Add("/WebClientWindowSettings");
	SettingsTypes.Add("/Taxi/WebClientWindowSettings");
	
	SetSettingsForKey(Key, SettingsTypes, Form.FormName, Form.WindowOptionsKey);
	
	Form.WindowOptionsKey = Key;
	
EndProcedure

// For the SetFormUsagePurposeKey, SetFormWindowPositionSavingKey procedures.
Procedure SetSettingsForKey(Key, SettingsTypes, FormName, CurrentKey)
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	NewKey = "/" + Key;
	Filter = New Structure;
	Filter.Insert("User", InfobaseUsers.CurrentUser().Name);
	
	For Each SettingsType IN SettingsTypes Do
		Filter.Insert("ObjectKey", FormName + NewKey + SettingsType);
		Selection = SystemSettingsStorage.Select(Filter);
		If Selection.Next() Then
			Return; // Settings for key have already been set.
		EndIf;
	EndDo;
	
	If ValueIsFilled(CurrentKey) Then
		CurrentKey = "/" + CurrentKey;
	EndIf;
	
	// Set initial settings of key by copying from the current key.
	For Each SettingsType IN SettingsTypes Do
		Filter.Insert("ObjectKey", FormName + CurrentKey + SettingsType);
		Selection = SystemSettingsStorage.Select(Filter);
		ObjectKey = FormName + NewKey + SettingsType;
		While Selection.Next() Do
			SettingsDescription = New SettingsDescription;
			SettingsDescription.Presentation = Selection.Presentation;
			SystemSettingsStorage.Save(ObjectKey, Selection.SettingsKey,
				Selection.Settings, SettingsDescription);
		EndDo;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Declaration of events to which you can add handlers.

// Declares the service events of the BasicFunctionality subsystem:
//
// Client events:
//   BeforeStart,
//   OnStart,
//   OnProcessorStartParameters,
//   BeforeExit,
//   OnGetListJobCompleteWarningsList.
//
// Server events:
//   OnAddSessionParametersSettingHandlers,
//   OnAddRefsSearchExceptions,
//   OnDefineSubjectPresentation,
//   OnAddMetadataObjectsRenaming,
//   OnAddClientWorkParametersOnStart,
//   OnAddClientWorkParameters,
//   OnAddClientWorkParametersOnShutdown,
//   OnEnableSeparationByDataAreas,
//   OnDataSendingToSubordinate,
//   OnDataSendingToMain,
//   OnGetDataFromMain,
//   AfterGettingDataFromSubordinate,
//   AfterGettingDataFromMain,
//   AfterSendingDataToMain,
//   AfterSendingDataToSubordinate,
//   OnDefineSupportedProgrammaticInterfaceVersions.
//
Procedure WhenAddingOfficeEventBasicFunctionality(ClientEvents, ServerEvents) Export
	
	// CLIENT EVENTS.
	
	// Executed before the online work beginning of a user with data area or in the local mode.
	// Corresponds to the event BeforeSystemOperationStart of application modules.
	//
	// For the parameters, see the CommonUseClientOverridable module.
	//
	// Syntax:
	// Procedure BeforeStart(Parameters) Export
	//
	// (The same as CommonUseClientOverridable.BeforeStart).
	ClientEvents.Add(
		"StandardSubsystems.BasicFunctionality\BeforeStart");
	
	// Running on the interactive beginning of user work with data area or in local mode.
	// Corresponds to the OnStart event of application modules.
	//
	// For the parameters, see the CommonUseClientOverridable module.
	//
	// Syntax:
	// Procedure OnStart(Parameters) Export
	//
	// (The same as CommonUseClientOverridable.OnStart).
	ClientEvents.Add(
		"StandardSubsystems.BasicFunctionality\OnStart");
	
	// Running on the interactive beginning of user work with data area or in local mode.
	// Called after the complete OnStart actions.
	// Used to connect wait handlers that should not be called on interactive actions before and during the system start.
	//
	// For the parameters, see the CommonUseClientOverridable module.
	//
	// Syntax:
	// Procedure AfterSystemStart() Export
	//
	// (The same as CommonUseClientOverridable.OnStart).
	ClientEvents.Add(
		"StandardSubsystems.BasicFunctionality\AfterSystemOperationStart");
	
	// Called during the beginning of the interactive user work with the data area or in the local mode.
	//
	// Parameters:
	//  FirstParameter   - String - first value of
	//                     the start parameter, up to the first ; character in the upper register.
	//  LaunchParameters - Array - array of rows separated by the ;
	//                     character in the start parameter passed to the configuration using command bar key /C.
	//  Cancel            - Boolean (return value) if you
	//                     set True OnStart, the OnStart event processor will be aborted.
	//
	// Syntax:
	// Procedure OnProcessorStartParameters (FirstParameter, StartParameters, Denial) Export
	//
	// (The same as CommonUseClientOverridable.OnProcessorStartParameters).
	ClientEvents.Add(
		"StandardSubsystems.BasicFunctionality\OnProcessingParametersLaunch");
	
	// Called before the online completion of the user work with data area or in the local mode.
	// Corresponds to the BeforeExit event of application modules.
	//
	// For the parameters, see the CommonUseClientOverridable module.
	//
	// Syntax:
	// Procedure BeforeExit(Parameters) Export
	//
	// (The same as CommonUseClientOverridable.BeforeExit).
	ClientEvents.Add(
		"StandardSubsystems.BasicFunctionality\BeforeExit");
	
	// Defines the list of warnings to the user before the completion of the system work.
	//
	// Parameters:
	//  Warnings - Array - you can add items of the
	//                            Structure type to the array, for its properties, see  StandardSubsystemsClient.AlertOnWorkEnd.
	//
	// Syntax:
	// Procedure OnReceiveWorkEndWarningList (Warnings) Export
	//
	ClientEvents.Add(
		"StandardSubsystems.BasicFunctionality\OnGetListOfWarningsToCompleteJobs");
	
	// Checks possibility of backup in user mode.
	//
	// Parameters:
	//  Result - Boolean (return value).
	//
	// Syntax:
	// Procedure OnCheckBackupPossibilityInUserMode(Result) Export
	//
	ClientEvents.Add(
		"StandardSubsystems.BasicFunctionality\WhenVerifyingBackupPossibilityInUserMode");
	
	// Appears when the user is offered to create a backup.
	//
	// Syntax:
	// Procedure DuringCreateBackupOfferToUser(Exception) Export
	//
	ClientEvents.Add(
		"StandardSubsystems.BasicFunctionality\WhenUserIsOfferedToBackup");
	
	// SERVER EVENTS.
	
	// Defines the handlers of the session parameters setting.
	//
	// Parameters:
	//  Handlers - Map, where.
	//                Key     - String - <SessionParameterName > or <SessionParameterNameBegin*>
	//                Value - String - full name of the handler.
	//
	//  Note. * character is used in the end of
	//              the session parameter name and indicates that one handler will
	//              be called for initialization of all session parameters with the name that starts with the word SessionParameterNameStart.
	//
	// To specify handlers of session parameters, you should use template:
	// Handlers.Insert("<SessionParameterName>|<SessionParameterNamePrefix*>", "Handler");
	//
	// Syntax:
	// Procedure OnAddSessionParametersSettingHandlers(Handlers) Export
	//
	// (The same as CommonUseOverridable.OnAddSessionParametersSettingHandlers).
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\OnAddSessionSettingsSetupHandler");
	
	// Defines the list of metadata objects content of which should not be considered in the business-logic of application.
	//
	// Description:
	//   The Objects versioning and Properties subsystems are set for the Goods and services implementation document.
	//   The document can be specified in other metadata objects - documents or registers.
	//   Some references are relevant for the business logic (for example, move by registers) and should be shown to a user.
	//   Another part of refs - "technology-generated" refs to document from the
	//   Object versioning and Properties subsystems data should be hidden from a user while searching for refs to object.
	//     For example, in a processor of the marked removal or in a subsystem of key attributes editing prohibition.
	//   List of this "technology-generated" objects should be enumerated in this function.
	//
	// IMPORTANT:
	//   To prevent empty "dead" refs, it is recommended to consider the
	//   procedure of removal of the specified metadata objects.
	//   For dimensions of information registers - using the Leading check
	//     box selection, then the information register record will be deleted at the same time the ref specified in the dimension is deleted.
	//   For other attributes of the specified objects - using subscription to the BeforeRemoval event of
	//   all metadata objects types what can be written to attributes of the specified metadata objects.
	//     It is required to find "technology-generated" objects in the handler in the
	//     attributes of which the ref of the deleted object is specified and select the method of ref clearing: clear attribute value, delete table row or delete the whole object.
	//
	// Parameters:
	//   Array - Metadata objects or their attributes content of which should not be considered in the application business-logic.
	//       * MetadataObject - Metadata object or its attribute.
	//       * String - Full name of the metadata object or its attribute.
	//
	// ForExample:
	// Array.Add(Metadata.InformationRegisters.ObjectsVersions);
	// Array.Add(Metadata.InformationRegisters.ObjectsVersions.Attributes.VersionAuthor);
	// Array.Add(InformationRegister.ObjectsVersions);
	//
	// Syntax:
	// Procedure OnAddRefsSearchExceptions(Exception) Export
	//
	// (The same as CommonUseOverridable.OnAddRefsSearchExceptions).
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\OnAddExceptionsSearchLinks");
	
	// Overrides the text description of a subject.
	//
	// Parameters:
	//  SubjectRef - AnyRef - an object of a reference type.
	//  Presentation   - String (return value) - custom text description.
	//
	// Syntax:
	// Procedure OnDefineSubjectPresentation (RefToSubject, Presentation) Export
	//
	// (The same as CommonUseOverridable.SetSubjectPresentation).
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\WhenDefiningPresentationObject");
	
	// Extends a definition of renaming those
	// metadata objects that can not be automatically found by the
	// type but refs to which should be saved to the data base (for example: subsystems, rules).
	//
	// For the details, see comment to the CommonUse procedure.AddRenaming().
	//
	// Syntax:
	// Procedure OnAddMetadataObjectsRenamings(Total) Export
	//
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\OnAddMetadataObjectsRenaming");
	
	// Defines parameters structure required for client
	// code work during the configuration start i.e. in the events handlers.
	// - BeforeSystemWorkStart,
	// - OnStart.
	//
	// Important: while starting you can not use
	// cache reset commands for the reused modules,
	// otherwise, the start can lead to unpredictable errors or extra server calls.
	//
	// Parameters:
	//   Parameters - Structure to which you can insert the client work parameters during the start.
	//                 Key     - parameter
	//                 name, Value - value of the parameter.
	//
	// Useful example:
	//   Parameters.Insert(<ParameterName>, <Code of receiving the parameter value>);
	//
	// Syntax:
	// Procedure OnAddClientWorkParametersOnStart(Parameters) Export
	//
	// (The same as CommonUseOverridable.ClientWorkParametersOnStart).
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\OnAddWorkParametersClientOnStart");
	
	// Defines the structure of parameters required for
	// the work of the configuration client code.
	//
	// Parameters:
	//   Parameters - Structure to which you can insert the client work parameters during the start.
	//                 Key     - parameter
	//                 name, Value - value of the parameter.
	//
	// Useful example:
	//   Parameters.Insert(<ParameterName>, <Code of receiving the parameter value>);
	//
	// Syntax:
	// Procedure OnAddClientWorkParameters(Exception) Export
	//
	// (The same as CommonUseOverridable.ClientWorkParameters).
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\WorkClientParametersOnAdd");
	
	// Defines parameters structure required for client code
	// work of the configuration during ending start i.e. in the handlers.:
	// - BeforeExit,
	// - OnExit.
	//
	// Parameters:
	//   Parameters - Structure to which you can insert the client work parameters during the start.
	//                 Key     - parameter
	//                 name, Value - value of the parameter.
	//
	// Useful example:
	//   Parameters.Insert(<ParameterName>, <Code of receiving the parameter value>);
	//
	// Syntax:
	// Procedure OnAddClientWorkParametersOnEnd(Parameters) Export
	//
	// (The same as CommonUseOverridable.ClientWorkParametersOnEnd).
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\WorkClientParametersOnAddOnComplete");
	
	// Called up at enabling data classification into data fields.
	//
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\OnEnableSeparationByDataAreas");
	
	// Called during the import of predefined items references in process of the important data import.
	// Allows to execute actions to correct or register information
	// about uniqueness of predefined items and also allows to deny continuing if it is not valid.
	//
	// Parameters:
	//   Object          - CatalogObject, ChartOfCharacteristicTypesObject, ChartOfAccountsObject, ChartOfCalculationTypesObject -
	//                     object of the predefined item after writing of which nonuniqueness is found.
	//   WriteInJournal - Boolean - return value. If you specify False, then information about nonuniqueness will not be added to the event log in general message.
	//                     You need to set False if non-uniqueness is fixed automatically.
	//   Cancel           - Boolean - return value. If you specify True, general exception
	//                     will be called that contains all the reasons of cancelation.
	//   DenialDescription  - String - return value. If Denial is set to True, then the
	//                     description will be added to the list of impossibility of continuing reasons.
	//
	// Syntax:
	// Procedure OnFindPredefinedUniqueness (Object, WriteToLog, Denial, DenialDescription) Export
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\OnDetectPredefinedNonUniqueness");
	
	// The procedure is the handler of an event of the
	// same name that occurs at data exchange in distributed infobase.
	//
	// Parameters:
	// see description of the OnSendDataToSubordinate event handler in the syntax helper.
	//
	// Syntax:
	// Procedure OnSendDataToSubordinate(DataItem, ItemSending, CreateInitialImage, Receiver) Export
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\OnSendDataToSubordinate");
	
	// The procedure is the handler of an event of the
	// same name that occurs at data exchange in distributed infobase.
	//
	// Parameters:
	// see description of the OnSendDataMain() event handler in the syntax helper.
	//
	// Syntax:
	// Procedure OnSendDataToMain (DataItem, ItemSending, Receiver) Export
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\OnSendDataToMaster");
	
	// The procedure is the handler of an event of the
	// same name that occurs at data exchange in distributed infobase.
	//
	// Parameters:
	// see Description of the event handler WhenDataIsReceivedFromSecondary() in the syntax helper.
	//
	// Syntax:
	// Procedure OnReceivingDataFromSubordinate(DataItem, DebitItem, SendBack, Sender) Export
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\OnReceiveDataFromSubordinate");
	
	// The procedure is the handler of an event of the
	// same name that occurs at data exchange in distributed infobase.
	// 
	// Parameters:
	// see Description of event handler WhenDataIsReceivedFromMain() in syntax helper.
	// 
	// Syntax:
	// Procedure OnReceiveDataFromMain (DataItem, DebitItem, SendBack, Sender) Export
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\OnReceiveDataFromMaster");
	
	// Procedure-handler of the event after receiving data in the main node from the subordinate node of distributed IB.
	// Called when exchange message reading is complete when all data from the exchange message
	// are successfully read and written to IB.
	// 
	//  Parameters:
	// Sender - ExchangePlanObject. Exchange plan node from which the data is received.
	// Cancel - Boolean. Cancelation flag. If you set the True
	// value for this parameter, the message will not be considered to be received. Data import transaction will be
	// canceled if all data is imported in one transaction or last data import transaction
	// will be canceled if data is imported batchwise.
	//
	// Syntax:
	// Procedure AfterReceivingDataFromSubordinate(Source = Undefined, DataItem, DebitItem, SendBack) Export
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\AfterDataReceivingFromSubordinated");
	
	// Procedure-handler of the event after receiving data in the subordinate node from the main node of distributed IB.
	// Called when exchange message reading is complete when all data from the exchange message
	// are successfully read and written to IB.
	// 
	//  Parameters:
	// Sender - ExchangePlanObject. Exchange plan node from which the data is received.
	// Cancel - Boolean. Cancelation flag. If you set the True
	// value for this parameter, the message will not be considered to be received. Data import transaction will be
	// canceled if all data is imported in one transaction or last data import transaction
	// will be canceled if data is imported batchwise.
	//
	// Syntax:
	// Procedure AfterReceivingDataFromMain(Receiver, Denial) Export
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\AfterDataReceivingFromMain");
	
	// Procedure-handler of the event after receiving data from the subordinate node to the main node of distributed IB.
	// Called when the exchange message is written, when all registered data
	// changes are successfully exported to the exchange message.
	// 
	//  Parameters:
	// Recipient - ExchangePlanObject. Object of exchange plan node for which the exchange message is generated.
	// Cancel - Boolean. Cancelation flag. If you set the True
	// value for this parameter, then the message will not considered to be generated and sent.
	//
	// Syntax:
	// Procedure AfterSendingDataToMain(Receiver, Denial) Export
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\AfterDataSendingToMain");
	
	// Procedure-handler of the event after receiving data from the main node to the subordinate node of distributed IB.
	// Called when the exchange message is written, when all registered data
	// changes are successfully exported to the exchange message.
	// 
	//  Parameters:
	// Recipient - ExchangePlanObject. Object of exchange plan node for which the exchange message is generated.
	// Cancel - Boolean. Cancelation flag. If you set the True
	// value for this parameter, then the message will not considered to be generated and sent.
	//
	// Syntax:
	// Procedure AfterSendingDataToSubordinate(Receiver, Denial) Export
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\AfterDataSendingToSubordinated");
	
	// Fills the structure with the arrays of supported
	// versions of all subsystems subject to versioning and uses subsystems names as keys.
	// Provides the functionality of InterfaceVersion Web-service.
	// during the implementation the body of the procedure shall be changed so it will return relevant version sets (see ex.below).
	//
	// Parameters:
	// SupportedVersionStructure - Structure: 
	//  - Keys = Subsystems names. 
	//  - Values = Arrays of supported version names.
	//
	// Example of implementation:
	//
	//  // FileTransferServer
	//  VersionsArray = New Array;
	//  VersionsArray.Add("1.0.1.1");
	//  VersionsArray.Add("1.0.2.1");
	//  SupportedVersionsStructure.Insert("FileTransferServer", VersionsArray);
	//  // End FileTransferService
	//
	// Syntax:
	// Procedure OnDefineProgramInterfaceSupportedVersions (Val SupportedVersionsStructure) Export
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\OnDefenitionSupportedVersionsOfSoftwareInterfaces");
	
	// Fills in parameters structure required for client
	// code work during the configuration end i.e. in the handlers.:
	// - BeforeExit,
	// - OnExit
	//
	// Parameters:
	//   Parameters   - Structure - Parameters structure.
	//
	// Syntax:
	// Procedure OnAddStandardSubsystemsClientLogicWorkParametersOnEnd (Parameters) Export
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsOnComplete");
	
	// Fills in the parameters structure required for
	// the client code work when during the configuration start i.e. in the events handlers.
	// - BeforeSystemWorkStart,
	// - OnStart
	//
	// Important: when starting you can not use
	// cache reset command for reused modules otherwise
	// the start can lead to unpredictable errors and excess server calls.
	//
	// Parameters:
	//   Parameters   - Structure - Parameters structure.
	//
	// Returns:
	//   Boolean   - False if the subsequent parameters filling should be aborted.
	//
	// Syntax:
	// Procedure OnAddStandardSubsystemsClientLogicWorkParametersOnStart (Parameters) Export
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsRunning");
	
	// Fills the structure of the parameters required
	// for the client configuration code.
	//
	// Parameters:
	//   Parameters   - Structure - Parameters structure.
	//
	// Syntax:
	// Procedure OnAddStandardSubsystemsClientLogicWorkParameters (Parameters) Export
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems");
	
	// Used to receive metadata objects mandatory for an exchange plan.
	// If the subsystem has metadata objects that have to be included
	// in the exchange plan, then these metadata objects should be added to the <Object> parameter.
	//
	// Parameters:
	// Objects - Array. Array of the configuration metadata objects that should be included into the exchange plan.
	// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
	// True - need to receive a list of RIB exchange plan;
	// False - it is required to receive a list for an exchange plan NOT RIB.
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\OnGettingObligatoryExchangePlanObjects");
	
	// Used to receive metadata objects that should not be included into the exchange plan content.
	// If the subsystem has metadata objects that should not be included in
	// the exchange plan, then these metadata objects should be added to the <Object> parameter.
	//
	// Parameters:
	// Objects - Array. Array of the configuration metadata objects that should not be included into the exchange plan.
	// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
	// True - required to get the list of the exception objects of the DIB exchange plan;
	// False - it is required to receive a list for an exchange plan NOT RIB.
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\OnGettingObjectExceptionsOfExchangePlan");
	
	// Used to receive metadata objects that should be included in the
	// content of the exchange plan and should NOT be included in the content of subscriptions to the events of changes registration for this plan.
	// These metadata objects are used only at the time of creation
	// of the initial image of the subnode and do not migrate during the exchange.
	// If the subsystem has metadata objects that take part in creating an initial
	// image of the subnode, the <Object> parameter needs to be added to these metadata objects.
	//
	// Parameters:
	// Objects - Array. Array of the configuration metadata objects.
	//
	ServerEvents.Add("StandardSubsystems.BasicFunctionality\OnGetPrimaryImagePlanExchangeObjects");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Add events handlers.

// Defines the BasicFunctionality subsystem handlers.
Procedure OnAddHandlersOfServiceEventsOfBasicFunctionality(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\AfterSystemOperationStart"].Add(
			"DynamicUpdateConfigurationControlClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
		"StandardSubsystemsServer");
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"StandardSubsystemsServer");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObligatoryExchangePlanObjects"].Add(
		"StandardSubsystemsServer");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObjectExceptionsOfExchangePlan"].Add(
		"StandardSubsystemsServer");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGetPrimaryImagePlanExchangeObjects"].Add(
		"StandardSubsystemsServer");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddMetadataObjectsRenaming"].Add(
		"StandardSubsystemsServer");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources"].Add(
		"StandardSubsystemsServer");
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers[
			"ServiceTechnology.DataExportImport\WhenFillingCommonDataTypesSupportingMatchingRefsOnImport"].Add(
				"StandardSubsystemsServer");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For the EventsHandlers function.

Procedure CheckUniquenessOfEventNames(Events)
	
	AllEvents    = New Map;
	
	For Each Event IN Events Do
		
		If AllEvents.Get(Event) = Undefined Then
			AllEvents.Insert(Event, True);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='An error occurred while preparing the events list.
		|
		|Event
		|%1 is already added.';ru='Ошибка при подготовке списка событий.
		|
		|Событие
		|""%1"" уже добавлено.'"),
				Event);
		EndIf;
		
	EndDo;
	
EndProcedure

Function TemplateHandlersEvent(Events, RequiredEvents)
	
	EventsHandlers  = New Map;
	
	For Each Event IN Events Do
		
		If TypeOf(Event) = Type("String") Then // Name of event in form of a row.
			EventsHandlers.Insert(Event, New Array);
			
		Else// Event description in the form of structure - see CommonUse.NewEvent().
			EventsHandlers.Insert(Event.Name, New Array);
			If Event.Required Then
				If RequiredEvents.Get(Event.Name) = Undefined Then
					RequiredEvents.Insert(Event.Name, True);
				EndIf;
			EndIf;
		EndIf;
		
	EndDo;
	
	Return EventsHandlers;
	
EndFunction

Procedure AddAreRequiredEventsWithoutHandlers(AreRequiredEventsWithoutHandlers,
                                                     RequiredEvents,
                                                     HandlersEventsBySubsystems)
	
	For Each MandatoryEvent IN RequiredEvents Do
		
		HandlerIsFound = False;
		For Each HandlersEventSubsystems IN HandlersEventsBySubsystems Do
			
			If HandlersEventSubsystems.Value.Get(MandatoryEvent.Key).Count() <> 0 Then
				HandlerIsFound = True;
				Break;
			EndIf;
			
		EndDo;
		
		If Not HandlerIsFound Then
			AreRequiredEventsWithoutHandlers.Add(MandatoryEvent.Key);
		EndIf;
	EndDo;
	
EndProcedure

Function StandardDetailsEventHandlers(SubsystemDescriptions, HandlersEventsBySubsystems)
	
	EventsHandlers  = New Map;
	ModulesHandlers  = New Map;
	HandlersEvents = New Map;
	
	For Each Subsystem IN SubsystemDescriptions.Order Do
		HandlersEventSubsystems = HandlersEventsBySubsystems[Subsystem];
		
		For Each KeyAndValue IN HandlersEventSubsystems Do
			Event              = KeyAndValue.Key;
			HandlersDescription = KeyAndValue.Value;
			
			Handlers = EventsHandlers[Event];
			If Handlers = Undefined Then
				Handlers = New Array;
				EventsHandlers.Insert(Event, Handlers);
				ModulesHandlers.Insert(Event, New Map);
			EndIf;
			
			For Each ProcessingDetails IN HandlersDescription Do
				If TypeOf(ProcessingDetails) = Type("Structure") Then
					Handler = ProcessingDetails;
				Else
					Handler = New Structure;
					Handler.Insert("Module", ProcessingDetails);
				EndIf;
				If Not Handler.Property("Version") Then
					Handler.Insert("Version", "");
				EndIf;
				Handler.Insert("Subsystem", Subsystem);
				
				// Check the full name of the event handler procedure module.
				If TypeOf(Handler.Module) <> Type("String")
				 OR Not ValueIsFilled(Handler.Module) Then
					
					Raise StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='AN error occurred while
		|preparing %1 event handlers.
		|
		|Error in %2 module name.';ru='Ошибка при
		|подготовке обработчиков события ""%1"".
		|
		|Ошибка в имени модуля ""%2"".'"),
						Event,
						Handler.Module);
				EndIf;
				
				// Check if the same module is specified for the event only once.
				If ModulesHandlers[Event].Get(Handler.Module) = Undefined Then
					ModulesHandlers[Event].Insert(Handler.Module, True);
				Else
					Raise StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='AN error occurred while
		|preparing %1 event handlers.
		|
		|Module %2 is already added.';ru='Ошибка при
		|подготовке обработчиков события ""%1"".
		|
		|Модуль ""%2"" уже добавлен.'"),
						Event,
						Handler.Module);
				EndIf;
				Handlers.Add(New FixedStructure(Handler));
				
				// Check if the same handler is specified for events only once.
				ProcedureName = Mid(Event, Find(Event, "\") + 1);
				HandlerName = Handler.Module + "." + ProcedureName;
				
				If HandlersEvents [HandlerName] = Undefined Then
					HandlersEvents .Insert(HandlerName, Event);
				Else
					Raise StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='AN error occurred while
		|preparing %1 event handlers.
		|
		|%2 handler is already
		|added for %3 event.';ru='Ошибка при
		|подготовке обработчиков события ""%1"".
		|
		|Обработчик ""%2""
		|уже добавлен для события ""%3"".'"),
						Event,
						HandlerName,
						HandlersEvents [HandlerName]);
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	// Write handlers arrays.
	For Each KeyAndValue IN EventsHandlers Do
		EventsHandlers[KeyAndValue.Key] = New FixedArray(KeyAndValue.Value);
	EndDo;
	
	Return New FixedMap(EventsHandlers);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// For the UpdateApplicationWorkParameters fuction.

Procedure CheckUpdateApplicationWorkParameters(HasChanges, CheckOnly, WithoutChanges, InBackground)
	
	If TypeOf(WithoutChanges) <> Type("Structure") Then
		WithoutChanges = New Structure;
	EndIf;
	
	If Not WithoutChanges.Property("BaseFunctionalityServiceEvents") Then
		IsCurrentChanges = False;
		Constants.ServiceEventsParameters.CreateValueManager().Refresh(IsCurrentChanges, CheckOnly);
		If IsCurrentChanges Then
			HasChanges = True;
			If CheckOnly Then
				Return;
			EndIf;
		Else
			WithoutChanges.Insert("BaseFunctionalityServiceEvents");
		EndIf;
		If InBackground Then
			CommonUseClientServer.MessageToUser("IncreaseInProgressStep=20");
		EndIf;
	EndIf;
	
	If Not WithoutChanges.Property("BasicFunctionalityMetadataObjectIDs") Then
		
		If StandardSubsystemsReUse.DisableCatalogMetadataObjectIDs() Then
			WithoutChanges.Insert("BasicFunctionalityMetadataObjectIDs");
		Else
			IsCurrentChanges = False;
			If CheckOnly Then
				// Check only critical changes: add, delete or rename metadata objects.
				Catalogs.MetadataObjectIDs.ExecuteDataRefreshing(False, IsCurrentChanges, CheckOnly, IsCurrentChanges);
			Else
				Catalogs.MetadataObjectIDs.ExecuteDataRefreshing(IsCurrentChanges, False);
			EndIf;
			If IsCurrentChanges Then
				HasChanges = True;
				If CheckOnly Then
					Return;
				EndIf;
			Else
				WithoutChanges.Insert("BasicFunctionalityMetadataObjectIDs");
			EndIf;
		EndIf;
		If InBackground Then
			CommonUseClientServer.MessageToUser("IncreaseInProgressStep=50");
		EndIf;
	EndIf;
	
	If Not WithoutChanges.Property("UsersWorkParameters") Then
		
		IsCurrentChanges = False;
		UsersService.UpdateUsersWorkParameters(IsCurrentChanges, CheckOnly);
		If IsCurrentChanges Then
			HasChanges = True;
			If CheckOnly Then
				Return;
			EndIf;
		Else
			WithoutChanges.Insert("UsersWorkParameters");
		EndIf;
		If InBackground Then
			CommonUseClientServer.MessageToUser("IncreaseInProgressStep=80");
		EndIf;
	EndIf;
	
	If Not WithoutChanges.Property("AccessManagementAccessLimitationParameters") Then
		
		If Not CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
			WithoutChanges.Insert("AccessManagementAccessLimitationParameters");
		Else
			ModuleAccessManagementService = CommonUse.CommonModule("AccessManagementService");
			
			IsCurrentChanges = False;
			ModuleAccessManagementService.UpdateAccessLimitationParameters(IsCurrentChanges, CheckOnly);
			If IsCurrentChanges Then
				HasChanges = True;
				If CheckOnly Then
					Return;
				EndIf;
			Else
				WithoutChanges.Insert("AccessManagementAccessLimitationParameters");
			EndIf;
		EndIf;
		If InBackground Then
			CommonUseClientServer.MessageToUser("IncreaseInProgressStep=100");
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For the ChangeApplicationFormParameters function.

Function NextVersion(Version)
	
	Array = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Version, ".");
	
	Return CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(
		Version) + "." + Format(Number(Array[3]) + 1, "NG=");
	
EndFunction

#EndRegion
