////////////////////////////////////////////////////////////////////////////////
// IB version update subsystem
// Server procedures and functions of
// the infobase update on configuration version change.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceApplicationInterface

// Announces events of the IBVersionUpdate subsystem:
//
// Server events:
//   OnAddUpdateHandlers,
//   BeforeInfobaseUpdate,
//   AfterInfobaseUpdate.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Adds the update procedure-handlers necessary for the subsystem.
	//
	// Parameters:
	//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
	//
	// Syntax:
	// Procedure OnAddUpdateHandlers(Handlers) Export
	//
	// For use in other libraries.
	//
	// (Analog of the InfobaseUpdateOverridable function.UpdateHandlers).
	ServerEvents.Add(
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers");
	
	// Called before the handlers of IB data update.
	//
	// Syntax:
	// Procedure BeforeInfobaseUpdate()  Export
	//
	// (same thing as InfobaseUpdateOverridable.BeforeInfobaseUpdate).
	//
	ServerEvents.Add("StandardSubsystems.InfobaseVersionUpdate\BeforeInformationBaseUpdating");
	
	// Called after exclusive update of the IB version.
	// 
	// Parameters:
	//   PreviousVersion       - String - subsystem version before update. 0.0.0.0 for an empty IB.
	//   CurrentVersion          - String - subsystem version after update.
	//   ExecutedHandlers - ValueTree - list of the
	//                                             executed procedures-processors of updating the subsystem grouped by the version number.
	//                            Procedure of completed handlers bypass:
	//
	// For Each Version From ExecutedHandlers.Rows Cycle
	//		
	// 	If Version.Version =
	// 		 * Then Ha//ndler that can be run every time the version changes.
	// 	Otherwise, Handler runs for a definite version.
	// 	EndIf;
	//		
	// 	For Each Handler From Version.Rows
	// 		Cycle ...
	// 	EndDo;
	//		
	// EndDo;
	//
	//   PutSystemChangesDescription - Boolean (return value)- if you set True, then display the form with updates description.
	//   ExclusiveMode           - Boolean - shows that the update was executed in an exclusive mode.
	//                                True - update was executed in the exclusive mode.
	//
	// Syntax:
	// Procedure AfterInfobaseUpdate (Val PreviousVersion,
	// 		Val CurrentVersion, Val ExecutedHandlers, EnterUpdatesDescription, ExclusiveMode) Export
	//
	// (same thing as InfobaseUpdateOverridable.AfterInfobaseUpdate).
	//
	ServerEvents.Add("StandardSubsystems.InfobaseVersionUpdate\AfterInformationBaseUpdate");
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers["StandardSubsystems.BasicFunctionality\AfterSystemOperationStart"].Add(
		"InfobaseUpdateClient");
	
	ClientHandlers["StandardSubsystems.BasicFunctionality\OnStart"].Add(
		"InfobaseUpdateClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"InfobaseUpdateService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSendDataToSubordinate"].Add(
		"InfobaseUpdateService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSendDataToMaster"].Add(
		"InfobaseUpdateService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsRunning"].Add(
		"InfobaseUpdateService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObligatoryExchangePlanObjects"].Add(
		"InfobaseUpdateService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGetPrimaryImagePlanExchangeObjects"].Add(
		"InfobaseUpdateService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddSessionSettingsSetupHandler"].Add(
		"InfobaseUpdateService");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\ListOfTemplatesOnGet"].Add(
				"InfobaseUpdateService");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObjectExceptionsOfExchangePlan"].Add(
		"InfobaseUpdateService");
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ServerHandlers["StandardSubsystems.CurrentWorks\AtFillingToDoList"].Add(
			"InfobaseUpdateService");
	EndIf;
	
EndProcedure

// Initializes the InfobaseUpdateInProgress session parameter.
//
Procedure SessionParametersSetting(Val ParameterName, SpecifiedParameters) Export
	
	If ParameterName <> "InfobaseUpdateIsExecute" Then
		Return;
	EndIf;
	
	SessionParameters.InfobaseUpdateIsExecute = InfobaseUpdate.InfobaseUpdateRequired();
	SpecifiedParameters.Add("InfobaseUpdateIsExecute");
	
EndProcedure

// Check if it is required to
// update undivided data of the infobase during the configuration version change.
//
Function ShouldUpdateUndividedDataInformationBase() Export
	
	SetPrivilegedMode(True);
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		MetadataVersion = Metadata.Version;
		If IsBlankString(MetadataVersion) Then
			MetadataVersion = "0.0.0.0";
		EndIf;
		
		SharedDataVersion = IBVersion(Metadata.Name, True);
		
		If NeedToDoUpdate(MetadataVersion, SharedDataVersion) Then
			Return True;
		EndIf;
		
		If Not CommonUseReUse.CanUseSeparatedData() Then
			
			SetPrivilegedMode(True);
			Run = SessionParameters.ClientParametersOnServer.Get("RunInfobaseUpdate");
			SetPrivilegedMode(False);
			
			If Run <> Undefined AND AreRightsForInfobaseUpdate() Then
				Return True;
			EndIf;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Returns a text of the lock reason if the IB update is required and the current user does not have sufficient rights, otherwise, returns an empty string.
//  
// Parameters:
//  ForPrivilegedMode - Boolean - if you select False, then during the checking of rights of the current user the presence of the privileged mode will be ignored.
//  
// Returns:
//  String - if the base is not locked, then an empty row, otherwise, a message about lock reason.
// 
Function InfobaseLockedForUpdate(ForPrivilegedMode = True) Export
	
	Message = "";
	
	CurrentInfobaseUser = InfobaseUsers.CurrentUser();
	
	// To access a locked base you need only an administration right.
	If ForPrivilegedMode Then
		IsRightAdministration = AccessRight("Administration", Metadata);
	Else
		IsRightAdministration = AccessRight("Administration", Metadata, CurrentInfobaseUser);
	EndIf;
	
	MessageToSystemAdministrator =
		NStr("en='Entrance to the application is temporarily impossible due to the update to the new version.
		|To finish the update of application version
		|you must be an administrator (the System administrator and Full rights roles).';ru='Вход в программу временно невозможен в связи с обновлением на новую версию
		|Для завершения обновления версии
		|программы требуются административные права (роли ""Администратор системы"" и ""Полные права"").'");
	
	SetPrivilegedMode(True);
	DataSeparationEnabled = CommonUseReUse.DataSeparationEnabled();
	CanUseSeparatedData = CommonUseReUse.CanUseSeparatedData();
	SetPrivilegedMode(False);
	
	If ShouldUpdateUndividedDataInformationBase() Then
		
		MessageAdministratorDataAreas =
			NStr("en='Access to the application is temporarily impossible due to the update to a new version.
		|Contact the service administrator for the details.';ru='Вход в приложение временно невозможен в связи с обновлением на новую версию.
		|Обратитесь к администратору сервиса за подробностями.'");
		
		If CanUseSeparatedData Then
			Message = MessageAdministratorDataAreas;
			
		ElsIf Not AreRightsForInfobaseUpdate(ForPrivilegedMode, False) Then
			
			If IsRightAdministration Then
				Message = MessageToSystemAdministrator;
			Else
				Message = MessageAdministratorDataAreas;
			EndIf;
		EndIf;
		
		Return Message;
	EndIf;
	
	// Message to service administrator is not displayed.
	If DataSeparationEnabled AND Not CanUseSeparatedData Then
		Return "";
	EndIf;
		
	If AreRightsForInfobaseUpdate(ForPrivilegedMode, True) Then
		Return "";
	EndIf;
	
	WantedRetryDataExportExchangeMessagesBeforeStart = False;
	If CommonUse.IsSubordinateDIBNode()
	   AND CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		ModuleDataExchangeServerCalling = CommonUse.CommonModule("DataExchangeServerCall");
		If ModuleDataExchangeServerCalling.RetryDataExportExchangeMessagesBeforeStart() Then
			WantedRetryDataExportExchangeMessagesBeforeStart = True;
		EndIf;
	EndIf;
	
	If Not InfobaseUpdate.InfobaseUpdateRequired()
	   AND Not WantedToValidateLegalityOfUpdateGetting()
	   AND Not WantedRetryDataExportExchangeMessagesBeforeStart Then
		Return "";
	EndIf;
	
	If IsRightAdministration Then
		Return MessageToSystemAdministrator;
	EndIf;

	If DataSeparationEnabled Then
		// Message to the service user.
		Message =
			NStr("en='Access to the application is temporarily impossible due to the update to a new version.
		|Contact the service administrator for the details.';ru='Вход в приложение временно невозможен в связи с обновлением на новую версию.
		|Обратитесь к администратору сервиса за подробностями.'");
	Else
		// Message to user of a local mode.
		Message =
			NStr("en='Entrance to the application is temporarily impossible due to the update to the new version.
		|Contact administrator for the details.';ru='Вход в программу временно невозможен в связи с обновлением на новую версию
		|Обратитесь к администратору за подробностями.'");
	EndIf;
	
	Return Message;
	
EndFunction

// Execute a non-interactive update of IB data .
// 
// Parameters:
// 
//  UpdateParameters - Structure - properties:
//    * ExceptionOnIBLockFail - Boolean - if False, then during
//                 a failed setting attempt of an exclusive
//                 mode exception is not called but the ExclusiveModeSettingError row returns.
// 
//    *OnLaunchClientApplication - Boolean - Initial value is False. If select
//                 True, then the parameters of the application work will not be updated as during
//                 the client launch they are updated at the beginning (before users and IB update authorization).
//                 The parameter is required to optimize the client launch mode not to update the application parameters twice.
//                 During an external call, for example, in the session
//                 of an external connection, work parameters should be updated to continue updating the IB.
//    *Restart             - Boolean    - (return value) restart is required, in some cases OnApplicationLaunch, for example, when you return to the data base configuration of the RIB subnode, see general module DataExchangeServer procedure.
//                                  SynchronizeWhenNoInfobaseUpdate.
//    *SetIBLock - Structure - structure with properties see IBLock().
//    *InBackground                     - Boolean    - if the infobase update is executed in the background, then you need to select True, otherwise, False.
// 
// Returns:
//  String -  shows that the update handlers are in progress:
//           Successfully, NotRequired, ExclusiveModeSettingError
//
Function RunInfobaseUpdate(UpdateParameters) Export
	
	If Not UpdateParameters.ClientApplicationsOnStart Then
		Try
			StandardSubsystemsServer.ImportRefreshApplicationWorkParameters();
		Except
			WriteError(DetailErrorDescription(ErrorInfo()));
			Raise;
		EndTry;
	EndIf;
	
	// Define fact of changing configuration name.
	
	DataUpdateMode = DataUpdateMode();
	MetadataVersion = Metadata.Version;
	If IsBlankString(MetadataVersion) Then
		MetadataVersion = "0.0.0.0";
	EndIf;
	DataVersion = IBVersion(Metadata.Name);
	
	// Before the infobase update.
	//
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.InfobaseVersionUpdateSaaS") Then
		ModuleInfobaseUpdateServiceSaaS = CommonUse.CommonModule("InfobaseUpdateServiceSaaS");
		ModuleInfobaseUpdateServiceSaaS.BeforeInformationBaseUpdating();
		
		// Set a privileged mode to update IB in a
		// service model when administrator of the data field enters the field to finish updating it.
		If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
			SetPrivilegedMode(True);
		EndIf;
		
	EndIf;
	
	// Import and export of the exchange message after restart due to receiving configuration changes.
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = CommonUse.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.BeforeInformationBaseUpdating(UpdateParameters.ClientApplicationsOnStart, UpdateParameters.Restart);
	EndIf;
		
	If Not InfobaseUpdate.InfobaseUpdateRequired() Then
		Return "NotNeeded";
	EndIf;
	
	If UpdateParameters.InBackground Then
		CommonUseClientServer.MessageToUser("ProgressStep=15/5");
	EndIf;
	
	SubsystemDescriptions  = StandardSubsystemsreuse.SubsystemDescriptions();
	For Each SubsystemName IN SubsystemDescriptions.Order Do
		SubsystemDescription = SubsystemDescriptions.ByNames.Get(SubsystemName);
		If Not ValueIsFilled(SubsystemDescription.MainServerModule) Then
			Continue;
		EndIf;
		Module = CommonUse.CommonModule(SubsystemDescription.MainServerModule);
		Module.BeforeInformationBaseUpdating();
	EndDo;
	InfobaseUpdateOverridable.BeforeInformationBaseUpdating();
	
	// Checks if there are sufficient rights to update the infobase.
	If Not AreRightsForInfobaseUpdate() Then
		Message = NStr("en='Insufficient rights to update the application version.';ru='Недостаточно прав для обновления версии программы.'");
		WriteError(Message);
		Raise Message;
	EndIf;
	
	If DataUpdateMode = "TransitionFromAnotherApplication" Then
		Message = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Change configuration name to %1.
		|You will be transited from another application.';ru='Изменилось имя конфигурации на ""%1"".
		|Будет выполнен переход с другой программы.'"),
			Metadata.Name);
	ElsIf DataUpdateMode = "VersionUpdate" Then
		Message = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Number of the configuration version: from %1 to %2.
		|Infobase update will be performed.';ru='Изменился номер версии конфигурации: с ""%1"" на ""%2"".
		|Будет выполнено обновление информационной базы.'"),
			DataVersion, MetadataVersion);
	Else 
		Message = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Initial data population up to version ""%1"" is in progress.';ru='Выполняется начальное заполнение данных до версии ""%1"".'"),
			MetadataVersion);
	EndIf;
	WriteInformation(Message);
	
	// Setting an infobase lock.
	LockSetEarlier = UpdateParameters.SetIBBlock <> Undefined 
		AND UpdateParameters.SetIBBlock.Use;
	If LockSetEarlier Then
		IterationsUpdate = IterationsUpdate();
		IBBlock = UpdateParameters.SetIBBlock;
	Else
		IBBlock = Undefined;
		IterationsUpdate = LockInfobase(IBBlock, UpdateParameters.ExceptWhenImpossibleLockIB);
		If IBBlock.Error <> Undefined Then
			Return IBBlock.Error;
		EndIf;
	EndIf;
	
	OperationalUpdate = IBBlock.OperationalUpdate;
	RecordKey = IBBlock.RecordKey;
	
	Try
		
		If DataUpdateMode = "TransitionFromAnotherApplication" Then
			
			GoFromAnotherApplication();
			
			DataUpdateMode = DataUpdateMode();
			OperationalUpdate = False;
			IterationsUpdate = IterationsUpdate();
		EndIf;
		
	Except
		
		If Not LockSetEarlier Then
			UnlockInfobase(IBBlock);
		EndIf;
		
		Raise;
	EndTry;
	
	If UpdateParameters.InBackground Then
		CommonUseClientServer.MessageToUser("ProgressStep=20/75");
	EndIf;
	
	If Not CommonUseReUse.DataSeparationEnabled()
		Or CommonUseReUse.CanUseSeparatedData() Then
		FormListDelayedUpdateHandlers(IterationsUpdate);
	EndIf;
	
	Try
		
		Parameters = New Structure;
		Parameters.Insert("HandlersExecutionProcess", CountHandlersToCurrentVersion(IterationsUpdate));
		Parameters.Insert("OperationalUpdate", OperationalUpdate);
		Parameters.Insert("InBackground", UpdateParameters.InBackground);
		
		// Execute all update handlers for configuration subsystems.
		For Each IterationUpdate IN IterationsUpdate Do
			IterationUpdate.ExecutedHandlers = RunUpdateIteration(IterationUpdate,	Parameters);
		EndDo;
		
		// Clear the list of new subsystems.
		DataAboutUpdate = DataOnUpdatingInformationBase();
		DataAboutUpdate.NewSubsystems = New Array;
		WriteDataOnUpdatingInformationBase(DataAboutUpdate);
		
		If UpdateParameters.InBackground Then
			CommonUseClientServer.MessageToUser("ProgressStep=95/5");
		EndIf;
		
		// For a file base the delayed handlers are executed in the main update center.
		If CommonUse.FileInfobase() AND
			(NOT CommonUseReUse.DataSeparationEnabled()
			Or CommonUseReUse.CanUseSeparatedData()) Then
			
			LaunchParameterClient = SessionParameters.ClientParametersOnServer.Get("LaunchParameter");
			If Find(Lower(LaunchParameterClient), Lower("DebuggingDeferredUpdate")) = 0 Then
				PerformPostponedUpdateNow();
			EndIf;
			
		EndIf;
		
	Except
		
		If Not LockSetEarlier Then
			UnlockInfobase(IBBlock);
		EndIf;
		
		Raise;
	EndTry;
	
	// Disable exclusive mode.
	If Not LockSetEarlier Then
		UnlockInfobase(IBBlock);
	EndIf;

	Message = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Infobase is successfully updated to version ""%1"".';ru='Обновление информационной базы на версию ""%1"" выполнено успешно.'"), MetadataVersion);
	WriteInformation(Message);
	
	PutSystemChangesDescription = (DataUpdateMode <> "InitialFilling");
	
	RefreshReusableValues();
	
	// After the infobase update.
	//
	ExecuteHandlersAfterInfobaseUpdate(
		IterationsUpdate,
		Constants.DetailInfobaseUpdateInEventLogMonitor.Get(),
		PutSystemChangesDescription,
		OperationalUpdate);
	
	InfobaseUpdateOverridable.AfterInformationBaseUpdate(
		DataVersion,
		MetadataVersion,
		IterationsUpdate,
		PutSystemChangesDescription,
		Not OperationalUpdate);
	
	// Export an exchange message after restart due to receiving the configuration changes.
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = CommonUse.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.AfterInformationBaseUpdate();
	EndIf;
	
	// Plan execution of the delayed update handlers for a client server base.
	If Not CommonUse.FileInfobase() Then
		
		If Not CommonUseReUse.DataSeparationEnabled()
			Or CommonUseReUse.CanUseSeparatedData() Then
			SchedulePostponedUpdate();
		EndIf;
		
	EndIf;
	
	DefineUpdatesDescriptionOutput(PutSystemChangesDescription);
	
	// Reset unsuccessful status of the configuration update during completing the update manually (without script).
	If CommonUse.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleConfigurationUpdate = CommonUse.CommonModule("ConfigurationUpdate");
		ModuleConfigurationUpdate.AfterInformationBaseUpdate();
	EndIf;
	
	RefreshReusableValues();
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		SessionParameters.InfobaseUpdateIsExecute = False;
	EndIf;
	
	SetPrivilegedMode(True);
	StandardSubsystemsServer.SetStartUpdatingInfobase(False);
	
	Return "Successfully";
	
EndFunction

// Get the version of configuration or
// parent configuration (library) that is stored in the infobase.
//
// Parameters:
//  LibraryID   - String - configuration name and library identifier.
//  GetCommonDataVersion - Boolean - if you select True, then during the work in the
// service model the common data version will be returned in the service model.
//
// Returns:
//   String   - version.
//
// Useful example:
//   IBConfigurationVersion = IBVersion(Metadata.Name);
//
Function IBVersion(Val LibraryID, Val GetCommonDataVersion = False) Export
	
	SetPrivilegedMode(True);
	
	StandardProcessing = True;
	Result = "";
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.InfobaseVersionUpdateSaaS") Then
		
		ModuleInfobaseUpdateServiceSaaS = CommonUse.CommonModule("InfobaseUpdateServiceSaaS");
		ModuleInfobaseUpdateServiceSaaS.OnDBVersionDefinition(LibraryID, GetCommonDataVersion,
			StandardProcessing, Result);
		
	EndIf;
	
	If StandardProcessing Then
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	SubsystemVersions.Version
		|FROM
		|	InformationRegister.SubsystemVersions AS SubsystemVersions
		|WHERE
		|	SubsystemVersions.SubsystemName = &SubsystemName";
		
		Query.SetParameter("SubsystemName", LibraryID);
		ValueTable = Query.Execute().Unload();
		Result = "";
		If ValueTable.Count() > 0 Then
			Result = TrimAll(ValueTable[0].Version);
		EndIf;
		
		If IsBlankString(Result) Then
			
			// Support update with SSL 2.1.2.
			QueryText =
				"SELECT
				|	DeleteVersionSubsystems.Version
				|FROM
				|	InformationRegister.DeleteVersionSubsystems AS DeleteVersionSubsystems
				|WHERE
				|	DeleteVersionSubsystems.SubsystemName = &SubsystemName
				|	AND DeleteVersionSubsystems.DataArea = &DataArea";
			Query = New Query(QueryText);
			Query.SetParameter("SubsystemName", LibraryID);
			If CommonUseReUse.DataSeparationEnabled() Then
				Query.SetParameter("DataArea", -1);
			Else
				Query.SetParameter("DataArea", 0);
			EndIf;
			ValueTable = Query.Execute().Unload();
			If ValueTable.Count() > 0 Then
				Result = TrimAll(ValueTable[0].Version);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return ?(IsBlankString(Result), "0.0.0.0", Result);
	
EndFunction

// Writes into the infobase version of configuration or parent configuration (library).
//
// Parameters:
//  LibraryID - String - name of the configuration or
//  the parent configuration (library), VersionNumber             - String - version number.
//  ThisMainConfiguration - Boolean - shows that LibraryIdentifier corresponds to the configuration name.
//
Procedure SetIBVersion(Val LibraryID, Val VersionNumber, Val ThisMainConfiguration) Export
	
	StandardProcessing = True;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.InfobaseVersionUpdateSaaS") Then
		
		ModuleInfobaseUpdateServiceSaaS = CommonUse.CommonModule("InfobaseUpdateServiceSaaS");
		ModuleInfobaseUpdateServiceSaaS.OnDBVersionInstallation(LibraryID, VersionNumber, StandardProcessing);
		
	EndIf;
	
	If Not StandardProcessing Then
		Return;
	EndIf;
		
	RecordSet = InformationRegisters.SubsystemVersions.CreateRecordSet();
	RecordSet.Filter.SubsystemName.Set(LibraryID);
	
	NewRecord = RecordSet.Add();
	NewRecord.SubsystemName = LibraryID;
	NewRecord.Version = VersionNumber;
	NewRecord.ThisMainConfiguration = ThisMainConfiguration;
	
	RecordSet.Write();
	
EndProcedure

// Returns the mode of the infobase data update.
// It is allowed to call only before the infobase starts updating (or returns VersionUpdate).
// 
// Returns:
//   String   - InitialFilling if it is a first launch of an empty base (data fields);
//              VersionUpdate if it is the first launch after the update of data base configuration;
//              TransferFromAnotherApplication if the first launch is in
// progress after updating an infobase configuration with a changed name of a main configuration.
//
Function DataUpdateMode() Export
	
	SetPrivilegedMode(True);
	
	StandardProcessing = True;
	DataUpdateMode = "";
	
	MainConfigurationName = Metadata.Name;
	SubsystemDescriptions  = StandardSubsystemsreuse.SubsystemDescriptions();
	For Each SubsystemName IN SubsystemDescriptions.Order Do
		SubsystemDescription = SubsystemDescriptions.ByNames.Get(SubsystemName);
		If Not ValueIsFilled(SubsystemDescription.MainServerModule) Then
			Continue;
		EndIf;
		
		If SubsystemDescription.Name <> MainConfigurationName Then
			Continue;
		EndIf;
		
		Module = CommonUse.CommonModule(SubsystemDescription.MainServerModule);
		Module.OnDefineDataUpdateMode(DataUpdateMode, StandardProcessing);
	EndDo;
	
	If Not StandardProcessing Then
		CommonUseClientServer.CheckParameter("OnDefineDataUpdateMode", "DataUpdateMode",
			DataUpdateMode, Type("String"));
		Message = NStr("en='Invalid value of the %1 parameter in %2. 
		|Expected: %3; sent value: %4 (%5 type).';ru='Недопустимое значение параметра %1 в %2. 
		|Ожидалось: %3; передано значение: %4 (тип %5).'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message,
			"DataUpdateMode", "OnDefineDataUpdateMode", 
			NStr("en='InitialFilling, VersionUpdate or TransferFromAnotherApplication';ru='НачальноеЗаполнение, ОбновлениеВерсии или ПереходСДругойПрограммы'"), 
			DataUpdateMode, TypeOf(DataUpdateMode));
		CommonUseClientServer.Validate(DataUpdateMode = "InitialFilling" Or 
			DataUpdateMode = "VersionUpdate" Or DataUpdateMode = "TransitionFromAnotherApplication", Message);
		Return DataUpdateMode;
	EndIf;

	Result = Undefined;
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.InfobaseVersionUpdateSaaS") Then
		ModuleInfobaseUpdateServiceSaaS = CommonUse.CommonModule("InfobaseUpdateServiceSaaS");
		ModuleInfobaseUpdateServiceSaaS.OnDetermingFirstEntryInDataArea(StandardProcessing, Result);
	EndIf;
	
	If Not StandardProcessing Then
		Return ?(Result = True, "InitialFilling", "VersionUpdate");
	EndIf;
	
	Return DataUpdateModeInLocalWorkMode();
	
EndFunction

// Fills the structure of the parameters required
// for the client configuration code. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure AddClientWorkParameters(Parameters) Export
	
EndProcedure

// Checks if there are handlers in the current update plan.
//
// Parameters:
//  LibraryID  - String - configuration name and library identifier.
//
// Returns:
//   Boolean - True - current update plan is empty, False - else.
//
Function CurrentEmptyUpdatePlan(Val LibraryID) Export
	
	RecordManager = InformationRegisters.SubsystemVersions.CreateRecordManager();
	RecordManager.SubsystemName = LibraryID;
	RecordManager.Read();
	If Not RecordManager.Selected() Then
		Return True;
	EndIf;
	
	PlanDescription = RecordManager.UpdatePlan.Get();
	
	If PlanDescription = Undefined Then
		Return True;
	EndIf;
	
	Return PlanDescription.Plan.Rows.Count() = 0;
	
EndFunction

// For an internal use.
Function UpdateHandlersInInterval(Val SourceTableHandlers, Val VersionFrom, 
	Val VersionBefore, Val ReceiveSplit = False, Val Filter = "Exclusive") Export
	
	// Add number in a table to order according to adding.
	AllHandlers = SourceTableHandlers.Copy();
	
	AllHandlers.Columns.Add("SerialNumber", New TypeDescription("Number", New NumberQualifiers(10, 0)));
	For IndexOf = 0 To AllHandlers.Count() - 1 Do
		HandlerLine = AllHandlers[IndexOf];
		HandlerLine.SerialNumber = IndexOf + 1;
	EndDo;
	
	// List of new subsystems objects.
	NewSubsystemObjects = New Array;
	For Each SubsystemName IN DataOnUpdatingInformationBase().NewSubsystems Do
		Subsystem = Metadata.FindByFullName(SubsystemName);
		If Subsystem = Undefined Then
			Continue;
		EndIf;
		For Each MetadataObject IN Subsystem.Content Do
			NewSubsystemObjects.Add(MetadataObject.FullName());
		EndDo;
	EndDo;
	
	// Define handlers of new subsystems.
	AllHandlers.Columns.Add("ThisNewSubsystem", New TypeDescription("Boolean"));
	For Each ProcessingDetails IN AllHandlers Do
		Position = StringFunctionsClientServer.FindCharFromEnd(ProcessingDetails.Procedure, ".");
		ManagerName = Left(ProcessingDetails.Procedure, Position - 1);
		If NewSubsystemObjects.Find(MetadataObjectNameByManagerName(ManagerName)) <> Undefined Then
			ProcessingDetails.ThisNewSubsystem = True;
		EndIf;
	EndDo;
	
	// Parameters preparation
	ChooseSeparatedHandlers = True;
	ChooseUnseparatedHandlers = True;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		If ReceiveSplit Then
			ChooseUnseparatedHandlers = False;
		Else
			If CommonUseReUse.CanUseSeparatedData() Then
				ChooseUnseparatedHandlers = False;
			Else
				ChooseSeparatedHandlers = False;
			EndIf;
		EndIf;
	EndIf;
	
	// Form handlers tree.
	Schema = GetCommonTemplate("GetTreeHandlersUpdate");
	Schema.Parameters.Find("ChooseSeparatedHandlers").Value = ChooseSeparatedHandlers;
	Schema.Parameters.Find("ChooseUnseparatedHandlers").Value = ChooseUnseparatedHandlers;
	Schema.Parameters.Find("VersionFrom").Value = VersionFrom;
	Schema.Parameters.Find("VersionBefore").Value = VersionBefore;
	Schema.Parameters.Find("VersionWeightFrom").Value = WeightVersion(Schema.Parameters.Find("VersionFrom").Value);
	Schema.Parameters.Find("VersionWeightBefore").Value = WeightVersion(Schema.Parameters.Find("VersionBefore").Value);
	Schema.Parameters.Find("OperationalUpdate").Value = (Filter = "Promptly");
	Schema.Parameters.Find("PostponedUpdate").Value = (Filter = "Delay");
	
	Composer = New DataCompositionTemplateComposer;
	Template = Composer.Execute(Schema, Schema.DefaultSettings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(Template, New Structure("Handlers", AllHandlers), , True);
	
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	OutputProcessor.SetObject(New ValueTree);
	
	HandlersToExecute = OutputProcessor.Output(CompositionProcessor);
	
	HandlersToExecute.Columns.Version.Name = "VersionRegistration";
	HandlersToExecute.Columns.GroupVersion.Name = "Version";
	
	Return HandlersToExecute;
	
EndFunction

// Returns True if the user has not disabled the
// displaying of system changes description after the update and there are unshown changes.
//
Function ShowSystemChangesDescription() Export
	
	DataAboutUpdate = DataOnUpdatingInformationBase();
	If DataAboutUpdate.PutSystemChangesDescription = False Then
		Return False;
	EndIf;
	
	If Not AccessRight("SaveUserData", Metadata) Then
		// Do not show the new in the version to anonymous users.
		Return False;
	EndIf;
	
	If Not Users.RolesAvailable("ViewApplicationChangesDescription") Then
		Return False;
	EndIf;
	
	OutputSystemChangesDescriptionForAdministrator = CommonUse.CommonSettingsStorageImport("UpdateInfobase", "OutputSystemChangesDescriptionForAdministrator",,, UserName());
	If OutputSystemChangesDescriptionForAdministrator = True Then
		Return True;
	EndIf;
	
	LastVersion = LastDisplayedVersionSystemChanges();
	If LastVersion = Undefined Then
		Return True;
	EndIf;
	
	Sections = SectionsDescribingChanges();
	
	If Sections = Undefined Then
		Return False;
	EndIf;
	
	Return GreaterSpecifiedGetVersions(Sections, LastVersion).Count() > 0;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls into these subsystems.

// Called during execution of the update script from the ConfigurationUpdate procedure.FinishUpdate().
Procedure AfterUpdatingCompletion() Export
	
	WriteUpdatesReceiveLegalityConfirmation();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Common use

// For an internal use.
//
Function NeedToDoUpdate(Val MetadataVersion, Val DataVersion) Export
	Return Not IsBlankString(MetadataVersion) AND DataVersion <> MetadataVersion;
EndFunction

// Returns a digital size of a version to compare the versions.
//
// Parameters:
//  Version - String - Version in a row format.
//
// Returns:
//  Number - version size
//
Function WeightVersion(Val Version) Export
	
	If Version = "" Then
		Return 0;
	EndIf;
	
	Return VersionWeightFromRowsArray(StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Version, "."));
	
EndFunction

// For an internal use.
//
Function IterationUpdate(ConfigurationOrLibraryName, Version, Handlers, ThisMainConfiguration = Undefined) Export
	
	IterationUpdate = New Structure;
	IterationUpdate.Insert("Subsystem",  ConfigurationOrLibraryName);
	IterationUpdate.Insert("Version",      Version);
	IterationUpdate.Insert("ThisMainConfiguration", 
		?(ThisMainConfiguration <> Undefined, ThisMainConfiguration, ConfigurationOrLibraryName = Metadata.Name));
	IterationUpdate.Insert("Handlers", Handlers);
	IterationUpdate.Insert("ExecutedHandlers", Undefined);
	IterationUpdate.Insert("ServerModuleName", "");
	IterationUpdate.Insert("MainServerModule", "");
	IterationUpdate.Insert("PreviousVersion", "");
	Return IterationUpdate;
	
EndFunction

// For an internal use.
//
Function IterationsUpdate() Export
	
	MainConfigurationName = Metadata.Name;
	IterationUpdateMainSubsystem = Undefined;
	
	IterationsUpdate = New Array;
	SubsystemDescriptions  = StandardSubsystemsreuse.SubsystemDescriptions();
	For Each SubsystemName IN SubsystemDescriptions.Order Do
		SubsystemDescription = SubsystemDescriptions.ByNames.Get(SubsystemName);
		If Not ValueIsFilled(SubsystemDescription.MainServerModule) Then
			Continue;
		EndIf;
		Module = CommonUse.CommonModule(SubsystemDescription.MainServerModule);
		
		IterationUpdate = IterationUpdate(SubsystemDescription.Name, SubsystemDescription.Version, 
			InfobaseUpdate.NewUpdateHandlersTable(), SubsystemDescription.Name = MainConfigurationName);
		IterationUpdate.ServerModuleName = SubsystemDescription.MainServerModule;
		IterationUpdate.MainServerModule = Module;
		IterationUpdate.PreviousVersion = IBVersion(SubsystemDescription.Name);
		IterationsUpdate.Add(IterationUpdate);
		
		Module.OnAddUpdateHandlers(IterationUpdate.Handlers);
		
		If SubsystemDescription.Name = MainConfigurationName Then
			IterationUpdateMainSubsystem = IterationUpdate;
		EndIf;
		
		ValidateHandlersProperties(IterationUpdate);
	EndDo;
	
	// For the backward compatibility.
	If IterationUpdateMainSubsystem = Undefined Then
		
		IterationUpdate = IterationUpdate(MainConfigurationName, Metadata.Version, 
			InfobaseUpdateOverridable.UpdateHandlers(), True);
		IterationUpdate.ServerModuleName = "InfobaseUpdateOverridable";
		IterationUpdate.MainServerModule = InfobaseUpdateOverridable;
		IterationUpdate.PreviousVersion = IBVersion(MainConfigurationName);
		IterationsUpdate.Add(IterationUpdate);
		
		ValidateHandlersProperties(IterationUpdate);
	EndIf;
	
	Return IterationsUpdate;
	
EndFunction

// For an internal use.
//
Function RunUpdateIteration(Val IterationUpdate, Val Parameters) Export
	
	LibraryID = IterationUpdate.Subsystem;
	MetadataIBVersion      = IterationUpdate.Version;
	UpdateHandlers   = IterationUpdate.Handlers;
	
	CurrentIBVersion = IterationUpdate.PreviousVersion;
	
	NewInfobaseVersion = CurrentIBVersion;
	MetadataVersion = MetadataIBVersion;
	If IsBlankString(MetadataVersion) Then
		MetadataVersion = "0.0.0.0";
	EndIf;
	
	If CurrentIBVersion <> "0.0.0.0"
		AND CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		
		// Get the list of handlers formed during execution of the undivided handlers.
		HandlersToExecute = GetUpdatePlan(LibraryID, CurrentIBVersion, MetadataVersion);
		If HandlersToExecute = Undefined Then
			If IterationUpdate.ThisMainConfiguration Then 
				MessagePattern = NStr("en='Update plan of configuration %1 from version %2 to version %3 is not found';ru='Не найден план обновления конфигурации %1 с версии %2 на версию %3'");
			Else
				MessagePattern = NStr("en='Update plan of library %1 from version %2 to version %3 is not found';ru='Не найден план обновления библиотеки %1 с версии %2 на версию %3'");
			EndIf;
			Message = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, LibraryID,
				CurrentIBVersion, MetadataVersion);
			WriteInformation(Message);
			
			HandlersToExecute = UpdateHandlersInInterval(UpdateHandlers, CurrentIBVersion, MetadataVersion);
		EndIf;
	Else
		HandlersToExecute = UpdateHandlersInInterval(UpdateHandlers, CurrentIBVersion, MetadataVersion);
	EndIf;
	
	DisableUpdateHandlers(LibraryID, HandlersToExecute, MetadataVersion, Parameters.HandlersExecutionProcess);
	
	RequiredSeparateHandlers = InfobaseUpdate.NewUpdateHandlersTable();
	OriginalVersionOfDB = CurrentIBVersion;
	ToWriteInJournal = Constants.DetailInfobaseUpdateInEventLogMonitor.Get();
	
	For Each Version IN HandlersToExecute.Rows Do
		
		If Version.Version = "*" Then
			Message = NStr("en='Required procedures of infobase update are in progress.';ru='Выполняются обязательные процедуры обновления информационной базы.'");
		Else
			NewInfobaseVersion = Version.Version;
			If CurrentIBVersion = "0.0.0.0" Then
				Message = NStr("en='Initial data population is in progress.';ru='Выполняется начальное заполнение данных.'");
			ElsIf IterationUpdate.ThisMainConfiguration Then 
				Message = NStr("en='Updating the infobase from version %1 to version %2.';ru='Выполняется обновление информационной базы с версии %1 на версию %2.'");
			Else
				Message = NStr("en='Updating data of library %3 from version %1 to version %2.';ru='Выполняется обновление данных библиотеки %3 с версии %1 на версию %2.'");
			EndIf;
			Message = StringFunctionsClientServer.SubstituteParametersInString(Message,
				CurrentIBVersion, NewInfobaseVersion, LibraryID);
		EndIf;
		WriteInformation(Message);
		
		For Each Handler IN Version.Rows Do
			
			HandlerParameters = Undefined;
			If Handler.VersionRegistration = "*" Then
				
				If Handler.HandlersManagement Then
					HandlerParameters = New Structure;
					HandlerParameters.Insert("SeparatedHandlers", RequiredSeparateHandlers);
				EndIf;
				
				If Handler.ExclusiveMode = True Then
					If Parameters.OperationalUpdate Then
						// Checkings are executed in OperativeUpdatePossible and the
						// update for such handlers is executed only during an offline update.
						Continue;
					EndIf;
					
					If HandlerParameters = Undefined Then
						HandlerParameters = New Structure;
					EndIf;
					HandlerParameters.Insert("ExclusiveMode", True);
				EndIf;
			EndIf;
			
			AdditionalParameters = New Structure("ToWriteInJournal, LibraryID, HandlersExecutionProcess, InBackground",
				ToWriteInJournal, LibraryID, Parameters.HandlersExecutionProcess, Parameters.InBackground);
			ExecuteHandlerUpdate(Handler, HandlerParameters, AdditionalParameters);
		EndDo;
		
		If Version.Version = "*" Then
			Message = NStr("en='Required procedures of infobase update are performed.';ru='Выполнены обязательные процедуры обновления информационной базы.'");
		Else
			If IterationUpdate.ThisMainConfiguration Then 
				Message = NStr("en='Infobase update from version %1 to version %2 is completed.';ru='Выполнено обновление информационной базы с версии %1 на версию %2.'");
			Else
				Message = NStr("en='Data of library %3 is updated from version %1 to version %2.';ru='Выполнено обновление данных библиотеки %3 с версии %1 на версию %2.'");
			EndIf;
			
			Message = StringFunctionsClientServer.SubstituteParametersInString(Message,
			  CurrentIBVersion, NewInfobaseVersion, LibraryID);
		EndIf;
		WriteInformation(Message);
		
		If Version.Version <> "*" Then
			// Set the number of infobase version.
			SetIBVersion(LibraryID, NewInfobaseVersion, IterationUpdate.ThisMainConfiguration);
			CurrentIBVersion = NewInfobaseVersion;
		EndIf;
		
	EndDo;
	
	// Set the number of infobase version.
	If IBVersion(LibraryID) <> MetadataIBVersion Then
		SetIBVersion(LibraryID, MetadataIBVersion, IterationUpdate.ThisMainConfiguration);
	EndIf;
	
	If CurrentIBVersion <> "0.0.0.0" Then
		
		If CommonUse.SubsystemExists("StandardSubsystems.SaaS.InfobaseVersionUpdateSaaS") Then
			
			ModuleInfobaseUpdateServiceSaaS = CommonUse.CommonModule("InfobaseUpdateServiceSaaS");
			ModuleInfobaseUpdateServiceSaaS.GenerateDataAreaUpdatePlan(LibraryID, UpdateHandlers,
				RequiredSeparateHandlers, OriginalVersionOfDB, MetadataIBVersion);
			
		EndIf;
		
	EndIf;
	
	Return HandlersToExecute;
	
EndFunction

// Check the rights of the current user to update infobase.
Function AreRightsForInfobaseUpdate(ForPrivilegedMode = True, SeparatedData = Undefined) Export
	
	CheckSystemAdministrationRights = True;
	
	If SeparatedData = Undefined Then
		SeparatedData = Not CommonUseReUse.DataSeparationEnabled()
			OR CommonUseReUse.CanUseSeparatedData();
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled()
	   AND SeparatedData Then
		
		If Not CommonUseReUse.CanUseSeparatedData() Then
			Return False;
		EndIf;
		CheckSystemAdministrationRights = False;
	EndIf;
	
	Return Users.InfobaseUserWithFullAccess(
		, CheckSystemAdministrationRights, ForPrivilegedMode);
	
EndFunction

// For an internal use.
//
Function RefreshInfobaseInBackground(FormUUID, IBBlock) Export
	
	ErrorInfo = Undefined;
	
	// Background job launch
	IBUpdateParameters = New Structure;
	IBUpdateParameters.Insert("ExceptWhenImpossibleLockIB", False);
	IBUpdateParameters.Insert("IBBlock", IBBlock);
	IBUpdateParameters.Insert("ClientParametersOnServer", SessionParameters.ClientParametersOnServer);
	
	// Setting of the exclusive mode before launching the background update.
	Try
		LockInfobase(IBUpdateParameters.IBBlock, False);
	Except
		ErrorInfo = ErrorInfo();
		Result = New Structure;
		Result.Insert("JobCompleted", False);
		Result.Insert("IBBlock", IBUpdateParameters.IBBlock);
		Result.Insert("AShortErrorMessage", BriefErrorDescription(ErrorInfo));
		Result.Insert("DetailedErrorMessage", DetailErrorDescription(ErrorInfo));
		Return Result;
	EndTry;
	
	IBUpdateParameters.Insert("InBackground", Not IBUpdateParameters.IBBlock.DebugMode);
	
	Try
		
		If Not IBUpdateParameters.InBackground Then
			IBUpdateParameters.Delete("ClientParametersOnServer");
		EndIf;
		Result = LongActions.ExecuteInBackground(
			FormUUID,
			"InfobaseUpdateService.UpdateInfobaseInBackground",
			IBUpdateParameters,
			NStr("en='Background update of the infobase';ru='Фоновое обновление информационной базы'"));
		
		Result.Insert("IBBlock", IBUpdateParameters.IBBlock);
		Result.Insert("AShortErrorMessage", Undefined);
		Result.Insert("DetailedErrorMessage", Undefined);
	Except
		ErrorInfo = ErrorInfo();
		Result = New Structure;
		Result.Insert("JobCompleted", False);
		Result.Insert("IBBlock", IBUpdateParameters.IBBlock);
		Result.Insert("AShortErrorMessage", BriefErrorDescription(ErrorInfo));
		Result.Insert("DetailedErrorMessage", DetailErrorDescription(ErrorInfo));
	EndTry;
	
	// If the IB update was already executed - unlock IB.
	If Result.JobCompleted = True Or ErrorInfo <> Undefined Then
		UnlockInfobase(IBUpdateParameters.IBBlock);
	EndIf;
	
	Return Result;
	
EndFunction

// Launches update of the infobase in the long operation.
Function UpdateInfobaseInBackground(IBUpdateParameters, StorageAddress) Export
	
	If IBUpdateParameters.InBackground Then
		SessionParameters.ClientParametersOnServer = IBUpdateParameters.ClientParametersOnServer;
	EndIf;
	
	ErrorInfo = Undefined;
	Try
		UpdateParameters = UpdateParameters();
		UpdateParameters.ExceptWhenImpossibleLockIB = IBUpdateParameters.ExceptWhenImpossibleLockIB;
		UpdateParameters.ClientApplicationsOnStart = True;
		UpdateParameters.Restart = False;
		UpdateParameters.SetIBBlock = IBUpdateParameters.IBBlock;
		UpdateParameters.InBackground = IBUpdateParameters.InBackground;
		
		Result = RunInfobaseUpdate(UpdateParameters);
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
	
	If ErrorInfo <> Undefined Then
		UpdateResult = New Structure;
		UpdateResult.Insert("AShortErrorMessage", BriefErrorDescription(ErrorInfo));
		UpdateResult.Insert("DetailedErrorMessage", DetailErrorDescription(ErrorInfo));
	ElsIf Not IBUpdateParameters.InBackground Then
		UpdateResult = Result;
	Else
		UpdateResult = New Structure;
		UpdateResult.Insert("ClientParametersOnServer", SessionParameters.ClientParametersOnServer);
		UpdateResult.Insert("Result", Result);
	EndIf;
	PutToTempStorage(UpdateResult, StorageAddress);
	
EndFunction

// For an internal use.
//
Function LockInfobase(IBBlock, ExceptWhenImpossibleLockIB)
	
	IterationsUpdate = Undefined;
	If IBBlock = Undefined Then
		IBBlock = IBBlock();
	EndIf;
	
	IBBlock.Use = True;
	If CommonUseReUse.DataSeparationEnabled() Then
		IBBlock.DebugMode = False;
	Else
		IBBlock.DebugMode = CommonUseClientServer.DebugMode();
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.InfobaseVersionUpdateSaaS") Then
		ModuleInfobaseUpdateServiceSaaS = CommonUse.CommonModule("InfobaseUpdateServiceSaaS");
		IBBlock.RecordKey = ModuleInfobaseUpdateServiceSaaS.LockDataAreasVersions();
	EndIf;
	
	IterationsUpdate = IterationsUpdate();
	IBBlock.OperationalUpdate = False;
	
	If IBBlock.DebugMode Then
		Return IterationsUpdate;
	EndIf;
	
	// Setting an exclusive mode for infobase update.
	ErrorInfo = Undefined;
	Try
		CommonUse.LockInfobase();
		Return IterationsUpdate;
	Except
		If PerhapsOperationalUpdate(IterationsUpdate) Then
			IBBlock.OperationalUpdate = True;
			Return IterationsUpdate;
		EndIf;
		ErrorInfo = ErrorInfo();
	EndTry;
	
	// Process unsuccessful attempt to set an exclusive mode.
	Message = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Unable to update infobase:
		|- Unable to set an
		|exclusive mode - Configuration version does not include update without setting
		|an
		|exclusive mode
		|More about error: %1';ru='Невозможно выполнить обновление информационной базы:
		|- Невозможно установить монопольный режим
		|- Версия конфигурации не предусматривает обновление без установки монопольного режима
		|
		|Подробности ошибки:
		|%1'"),
		BriefErrorDescription(ErrorInfo));
	
	WriteError(Message);
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.InfobaseVersionUpdateSaaS") Then
		ModuleInfobaseUpdateServiceSaaS = CommonUse.CommonModule("InfobaseUpdateServiceSaaS");
		ModuleInfobaseUpdateServiceSaaS.UnlockDataAreasVersions(IBBlock.RecordKey);
	EndIf;
	
	InUseUserSessionsEnding = False;
	WhenDeterminingUseUserSessionsSubsystems(InUseUserSessionsEnding);
	BaseFile = CommonUse.FileInfobase();
	
	If BaseFile AND Not ExceptWhenImpossibleLockIB
		AND InUseUserSessionsEnding Then
		
		LaunchParameterClient = SessionParameters.ClientParametersOnServer.Get("LaunchParameter");
		If Find(LaunchParameterClient, "ScheduledJobsDisabled") = 0 Then
			IBBlock.Error = "LockScheduledJobsProcessing";
		Else
			IBBlock.Error = "ExclusiveModeSetupError";
		EndIf;
	EndIf;
	
	Raise Message;
	
EndFunction

// For an internal use.
//
Procedure UnlockInfobase(IBBlock) Export
	
	If IBBlock.DebugMode Then
		Return;
	EndIf;
		
	If ExclusiveMode() Then
		While TransactionActive() Do
			RollbackTransaction();
		EndDo;
	EndIf;
		
	CommonUse.UnlockInfobase();
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.InfobaseVersionUpdateSaaS") Then
		ModuleInfobaseUpdateServiceSaaS = CommonUse.CommonModule("InfobaseUpdateServiceSaaS");
		ModuleInfobaseUpdateServiceSaaS.UnlockDataAreasVersions(IBBlock.RecordKey);
	EndIf;
	
EndProcedure

// For an internal use.
//
Function IBBlock()
	
	Result = New Structure;
	Result.Insert("Use", False);
	Result.Insert("Error", Undefined);
	Result.Insert("OperationalUpdate", Undefined);
	Result.Insert("RecordKey", Undefined);
	Result.Insert("DebugMode", Undefined);
	Return Result;
	
EndFunction

// For an internal use.
//
Function UpdateParameters() Export
	
	Result = New Structure;
	Result.Insert("ExceptWhenImpossibleLockIB", True);
	Result.Insert("ClientApplicationsOnStart", False);
	Result.Insert("Restart", False);
	Result.Insert("SetIBBlock", Undefined);
	Result.Insert("InBackground", False);
	Return Result;
	
EndFunction

// For an internal use.
//
Function NewHandlersTableTransferWithAnotherApplication() Export
	
	Handlers = New ValueTable;
	Handlers.Columns.Add("PreviousConfigurationName",	New TypeDescription("String", New StringQualifiers(0)));
	Handlers.Columns.Add("Procedure",					New TypeDescription("String", New StringQualifiers(0)));
	Return Handlers;
	
EndFunction

// For an internal use.
//
Function TransitionHandlersWithAnotherApplication(PreviousConfigurationName) 
	
	TransitionHandlers = NewHandlersTableTransferWithAnotherApplication();
	MainConfigurationName = Metadata.Name;
	
	SubsystemDescriptions  = StandardSubsystemsreuse.SubsystemDescriptions();
	For Each SubsystemName IN SubsystemDescriptions.Order Do
		SubsystemDescription = SubsystemDescriptions.ByNames.Get(SubsystemName);
		If Not ValueIsFilled(SubsystemDescription.MainServerModule) Then
			Continue;
		EndIf;
		
		If SubsystemDescription.Name <> MainConfigurationName Then
			Continue;
		EndIf;
		
		Module = CommonUse.CommonModule(SubsystemDescription.MainServerModule);
		Module.OnAddTransitionFromAnotherApplicationHandlers(TransitionHandlers);
	EndDo;
	
	Filter = New Structure("PreviousConfigurationName", "*");
	Result = TransitionHandlers.FindRows(Filter);
	
	Filter.PreviousConfigurationName = PreviousConfigurationName;
	CommonUseClientServer.SupplementArray(Result, TransitionHandlers.FindRows(Filter), True);
	
	Return Result;
	
EndFunction

Procedure GoFromAnotherApplication()
	
	// Previous configuration name, from which the transition should be run.
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	SubsystemVersions.SubsystemName AS SubsystemName,
	|	SubsystemVersions.Version AS Version
	|FROM
	|	InformationRegister.SubsystemVersions AS SubsystemVersions
	|WHERE
	|	SubsystemVersions.ThisMainConfiguration = TRUE";
	QueryResult = Query.Execute();
	// If for some reason the update handler did not work FillAttributeIsMainConfiguration.
	If QueryResult.IsEmpty() Then 
		Return;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Raise NStr("en='When working in SaaS, transfer from another application is unexpected.';ru='При работе в модели сервиса переход с другой программы не предусмотрен.'");
	EndIf;
	
	QueryResult = Query.Execute().Unload()[0];
	PreviousConfigurationName = QueryResult.SubsystemName;
	PreviousConfigurationVersion = QueryResult.Version;
	Handlers = TransitionHandlersWithAnotherApplication(PreviousConfigurationName);
	
	// Execute all transfer handlers.
	For Each Handler IN Handlers Do
		
		TransactionActiveOnExecutionStart = TransactionActive();
		Try
			WorkInSafeMode.ExecuteConfigurationMethod(Handler.Procedure);
		Except
			
			HandlerName = Handler.Procedure;
			WriteError(StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='An error occurred calling a transition
		|handler
		|from another
		|application %1: %2';ru='При вызове обработчика перехода
		|с
		|другой программы
		|""%1"" произошла ошибка: ""%2"".'"),
				HandlerName,
				DetailErrorDescription(ErrorInfo())));
			
			Raise;
		EndTry;
		ValidateNestedTransaction(TransactionActiveOnExecutionStart, Handler.Procedure);
		
	EndDo;
		
	Parameters = New Structure();
	Parameters.Insert("UpdateFromVersion", True);
	Parameters.Insert("ConfigurationVersion", Metadata.Version);
	Parameters.Insert("ClearInformationAboutPreviousConfiguration", True);
	OnEndTransitionFromAnotherApplication(PreviousConfigurationName, PreviousConfigurationVersion, Parameters);
	
	// Set the current name and configuration version.
	BeginTransaction();
	Try
		If Parameters.ClearInformationAboutPreviousConfiguration Then
			RecordSet = InformationRegisters.SubsystemVersions.CreateRecordSet();
			RecordSet.Filter.SubsystemName.Set(PreviousConfigurationName);
			RecordSet.Write();
		EndIf;
		
		RecordSet = InformationRegisters.SubsystemVersions.CreateRecordSet();
		RecordSet.Filter.SubsystemName.Set(Metadata.Name);
		
		ConfigurationVersion = Metadata.Version; 
		If Parameters.UpdateFromVersion Then
			ConfigurationVersion = Parameters.ConfigurationVersion;
		EndIf;
		NewRecord = RecordSet.Add();
		NewRecord.SubsystemName = Metadata.Name;
		NewRecord.Version = ConfigurationVersion;
		NewRecord.UpdatePlan = Undefined;
		NewRecord.ThisMainConfiguration = True;
		
		RecordSet.Write();
		CommitTransaction();
	Except	
		RollbackTransaction();
		Raise;
	EndTry;
	
	RefreshReusableValues();
	
EndProcedure

Procedure OnEndTransitionFromAnotherApplication(PreviousConfigurationName, PreviousConfigurationVersion, Parameters)
	
	ConfigurationName = Metadata.Name;
	SubsystemDescriptions  = StandardSubsystemsreuse.SubsystemDescriptions();
	For Each SubsystemName IN SubsystemDescriptions.Order Do
		SubsystemDescription = SubsystemDescriptions.ByNames.Get(SubsystemName);
		If Not ValueIsFilled(SubsystemDescription.MainServerModule) Then
			Continue;
		EndIf;
		
		If SubsystemDescription.Name <> ConfigurationName Then
			Continue;
		EndIf;
		
		Module = CommonUse.CommonModule(SubsystemDescription.MainServerModule);
		Module.OnEndTransitionFromAnotherApplication(PreviousConfigurationName, PreviousConfigurationVersion, Parameters);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Protocol the update progress.

// Returns a string constant to form the events log messages.
//
// Returns:
//   String
//
Function EventLogMonitorEvent() Export
	
	Return NStr("en='Infobase update';ru='Обновление информационной базы'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Returns a row constant to form messages
// of the registration log which protocols the process of the update handlers.
//
// Returns:
//   String
//
Function EventLogMonitorMessageTextProtocol() Export
	
	Return EventLogMonitorEvent() + ". " + NStr("en='Execution protocol';ru='Протокол выполнения'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Updates description

// Forms a tabular document with a description
// of changes in the versions that correspond to the transferred list of the Sections versions.
//
Function DocumentSystemChangesDescription(Val Sections) Export
	
	DocumentSystemChangesDescription = New SpreadsheetDocument();
	If Sections.Count() = 0 Then
		Return DocumentSystemChangesDescription;
	EndIf;
	
	TemplateUpdatesDescriptionFull = Metadata.CommonTemplates.Find("SystemChangesDescription");
	If TemplateUpdatesDescriptionFull <> Undefined Then
		TemplateUpdatesDescriptionFull = GetCommonTemplate(TemplateUpdatesDescriptionFull);
	Else
		Return New SpreadsheetDocument();
	EndIf;
	
	For Each Version IN Sections Do
		
		DisplayLongDescChanges(Version, DocumentSystemChangesDescription, TemplateUpdatesDescriptionFull);
		
	EndDo;
	
	Return DocumentSystemChangesDescription;
	
EndFunction

// Returns array of the versions more
// than the last displayed version, for which there are descriptions of the system change.
//
// Returns:
//  Array - contains rows with the versions.
//
Function NonShownSectionsOfChangesDescribing() Export
	
	Sections = SectionsDescribingChanges();
	
	LastVersion = LastDisplayedVersionSystemChanges();
	
	If LastVersion = Undefined Then
		Return New Array;
	EndIf;
	
	Return GreaterSpecifiedGetVersions(Sections, LastVersion);
	
EndFunction

// Selects the check box of
// displaying descriptions of the versions change up to the current version.
//
// Parameters:
//  UserName - String - user name, for
//   which you should select the check box.
//
Procedure SetFlagDisplayDescriptionsForCurrentVersion(Val UserName = Undefined) Export
	
	CommonUse.CommonSettingsStorageSave("UpdateInfobase",
		"LastDisplayedVersionSystemChanges", Metadata.Version, , UserName);
		
	If UserName = Undefined AND Users.InfobaseUserWithFullAccess() Then
		
		CommonUse.CommonSettingsStorageDelete("UpdateInfobase", "OutputSystemChangesDescriptionForAdministrator", UserName());
		
	EndIf;
	
EndProcedure

// Selects a check box of
// displaying description of version changes up to the current
// version if the check box was not selected previously for the user.
//
// Parameters:
//  UserName - String - user name, for
//   which you should select the check box.
//
Procedure SetFlagDisplayDescriptionsForNewUser(Val UserName) Export
	
	If LastDisplayedVersionSystemChanges(UserName) = Undefined Then
		SetFlagDisplayDescriptionsForCurrentVersion(UserName);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Mechanism of a delayed update.

// Forms a tree of delayed handlers and writes it to the InformationAboutIBUpdate constant.
//
Procedure FormListDelayedUpdateHandlers(IterationsUpdate)
	
	HandlerTree = HandlersExecutedLegacy(IterationsUpdate);
	DataAboutUpdate = DataOnUpdatingInformationBase();
	
	// Set an initial fields value.
	DataAboutUpdate.Insert("UpdateBeginTime");
	DataAboutUpdate.Insert("UpdateEndTime");
	DataAboutUpdate.Insert("DurationOfUpdate");
	DataAboutUpdate.Insert("BeginTimeOfPendingUpdate");
	DataAboutUpdate.Insert("EndTimeDeferredUpdate");
	DataAboutUpdate.Insert("SessionNumber", New ValueList());
	DataAboutUpdate.Insert("UpdateHandlerParameters");
	DataAboutUpdate.Insert("DeferredUpdateIsCompletedSuccessfully");
	DataAboutUpdate.Insert("HandlerTree", New ValueTree());
	DataAboutUpdate.Insert("PutSystemChangesDescription", False);
	
	LibraryName = "";
	VersionNumber   = "";
	
	For Each IterationUpdate IN IterationsUpdate Do
		
		LibraryName = IterationUpdate.Subsystem;
		HandlersByVersion = UpdateHandlersInInterval(IterationUpdate.Handlers,
			IterationUpdate.PreviousVersion,
			IterationUpdate.Version,
			True,
			"Delay");
			
		If HandlersByVersion.Rows.Count() = 0 Then
			Continue;
		EndIf;
		
		// Add library row.
		FoundString = HandlerTree.Rows.Find(LibraryName, "LibraryName");
		If FoundString <> Undefined Then
			TreeRowLibrary = FoundString;
		Else
			TreeRowLibrary = HandlerTree.Rows.Add();
			TreeRowLibrary.LibraryName = LibraryName;
		EndIf;
		TreeRowLibrary.Status = "";
		
		For Each RowVersion IN HandlersByVersion.Rows Do
			
			FoundString = TreeRowLibrary.Rows.Find(RowVersion.Version, "VersionNumber");
			HasFailedHandlers = False;
			If FoundString <> Undefined Then
				FoundString.Status = "";
				
				For Each OutstandingHandler IN FoundString.Rows Do
					HasFailedHandlers = True;
					OutstandingHandler.NumberAttempts = 0;
				EndDo;
				TreeRowVersions = FoundString;
			Else
				TreeRowVersions = TreeRowLibrary.Rows.Add();
				TreeRowVersions.VersionNumber   = RowVersion.Version;
				TreeRowVersions.Status = "";
			EndIf;
			
			For Each RowHandlers IN RowVersion.Rows Do
				
				If HasFailedHandlers Then
					FoundString = TreeRowVersions.Rows.Find(RowHandlers.Procedure, "HandlerName");
					If FoundString <> Undefined Then
						Continue; // The handler for this version already exists.
					EndIf;
				EndIf;
				
				If RowHandlers.ExclusiveMode = True Then
					
					ErrorText = NStr("en='The delayed %1
		|handler should not have the ExclusiveMode trait.';ru='У отложенного
		|обработчика ""%1"" не должен быть установлен признак ""МонопольныйРежим"".'");
					ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
						ErrorText, RowHandlers.Procedure);
					WriteError(ErrorText);
					Raise ErrorText;
					
				EndIf;
				
				TreeRowHandlers = TreeRowVersions.Rows.Add();
				TreeRowHandlers.LibraryName = LibraryName;
				TreeRowHandlers.VersionNumber = RowHandlers.Version;
				TreeRowHandlers.VersionRegistration = RowHandlers.VersionRegistration;
				TreeRowHandlers.HandlerName = RowHandlers.Procedure;
				TreeRowHandlers.Comment = RowHandlers.Comment;
				TreeRowHandlers.Status = "NotCompleted";
				TreeRowHandlers.NumberAttempts = 0;
			EndDo;
			
		EndDo;
		
	EndDo;
	
	CheckExecuteTreeCompletedHandlers(HandlerTree);
	DataAboutUpdate.HandlerTree = HandlerTree;
	WriteDataOnUpdatingInformationBase(DataAboutUpdate);
	
EndProcedure

// Plans the execution of a delayed handler in the client server base.
//
Procedure SchedulePostponedUpdate()
	
	// Plan the execution of the scheduled job.
	// During work in the service model - scheduled job is added in queue.
	If Not CommonUse.FileInfobase() Then
		
		If CommonUseReUse.DataSeparationEnabled() Then
			OnEnablePostponedUpdating(True);
		Else
			ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.DeferredInfobaseUpdate);
			ScheduledJob.Use = True;
			ScheduledJob.Write();
		EndIf;
		
	EndIf;
	
EndProcedure

// Manages the process of the deferred update handlers.
// 
Procedure PerformPostponedUpdate() Export
	
	// Call OnBeginScheduledJobExecution
	// is not used as required actions are executed privately.
	
	DataAboutUpdate = DataOnUpdatingInformationBase();
	
	If DataAboutUpdate.EndTimeDeferredUpdate <> Undefined Then
		DisconnectPostponedUpdate();
		Return;
	EndIf;
	
	If DataAboutUpdate.BeginTimeOfPendingUpdate = Undefined Then
		DataAboutUpdate.BeginTimeOfPendingUpdate = CurrentSessionDate();
	EndIf;
	If TypeOf(DataAboutUpdate.SessionNumber) <> Type("ValueList") Then
		DataAboutUpdate.SessionNumber = New ValueList;
	EndIf;
	DataAboutUpdate.SessionNumber.Add(InfobaseSessionNumber());
	WriteDataOnUpdatingInformationBase(DataAboutUpdate);
	
	// IN the scheduled job session the check of restriction date is switched.
	If CommonUse.SubsystemExists("StandardSubsystems.ChangeProhibitionDates") Then
		ChangeProhibitionDateModuleService = CommonUse.CommonModule("ChangeProhibitionDatesService");
		ChangeProhibitionDateModuleService.SkipChangeProhibitionCheck(True);
	EndIf;
	
	If Not ExecutePendingUpdateHandler(DataAboutUpdate)
		Or AllDelayedHandlersExecuted(DataAboutUpdate) Then
		DisconnectPostponedUpdate();
	EndIf;
	
EndProcedure

// Executes all procedures of a delayed update in the cycle in one call.
//
Procedure PerformPostponedUpdateNow() Export
	
	DataAboutUpdate = DataOnUpdatingInformationBase();
	
	If DataAboutUpdate.EndTimeDeferredUpdate <> Undefined Then
		Return;
	EndIf;

	If DataAboutUpdate.BeginTimeOfPendingUpdate = Undefined Then
		DataAboutUpdate.BeginTimeOfPendingUpdate = CurrentSessionDate();
	EndIf;
	
	If TypeOf(DataAboutUpdate.SessionNumber) <> Type("ValueList") Then
		DataAboutUpdate.SessionNumber = New ValueList;
	EndIf;
	DataAboutUpdate.SessionNumber.Add(InfobaseSessionNumber());
	WriteDataOnUpdatingInformationBase(DataAboutUpdate);
	
	HandlersWerePerformed = True;
	StartsCount = 0; // Protection from the infinite loop as a result of possible errors in the update handlers.
	While HandlersWerePerformed AND StartsCount < 10000 Do
		HandlersWerePerformed = ExecutePendingUpdateHandler(DataAboutUpdate);
		StartsCount = StartsCount + 1;
	EndDo;
	
EndProcedure

// Receives information about the infobase update.
Function DataOnUpdatingInformationBase() Export
	
	SetPrivilegedMode(True);
	
	If CommonUseReUse.DataSeparationEnabled()
	   AND Not CommonUseReUse.CanUseSeparatedData() Then
		
		Return NewDataAboutUpdate();
	EndIf;
	
	InfobaseUpdateData = Constants.InfobaseUpdateData.Get().Get();
	If TypeOf(InfobaseUpdateData) <> Type("Structure") Then
		Return NewDataAboutUpdate();
	EndIf;
	If InfobaseUpdateData.Count() = 1 Then
		Return NewDataAboutUpdate();
	EndIf;
		
	InfobaseUpdateData = NewDataAboutUpdate(InfobaseUpdateData);
	Return InfobaseUpdateData;
	
EndFunction

// Writes data on update in the InformationAboutUpdate constant.
Procedure WriteDataOnUpdatingInformationBase(Val DataAboutUpdate) Export
	
	If DataAboutUpdate = Undefined Then
		NewValue = NewDataAboutUpdate();
	Else
		NewValue = DataAboutUpdate;
	EndIf;
	
	ManagerConstants = Constants.InfobaseUpdateData.CreateValueManager();
	ManagerConstants.Value = New ValueStorage(NewValue);
	InfobaseUpdate.WriteData(ManagerConstants);
	
EndProcedure

// Only for internal use.
Function WantedToValidateLegalityOfUpdateGetting() Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.CheckUpdateReceiveLegality") Then
		Return False;
	EndIf;
	
	If StandardSubsystemsServer.ThisIsBasicConfigurationVersion() Then
		Return False;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	If CommonUse.IsSubordinateDIBNode() Then
		Return False;
	EndIf;
	
	LegalVersion = "";
	
	If DataUpdateModeInLocalWorkMode() = "InitialFilling" Then
		LegalVersion = Metadata.Version;
	Else
		DataAboutUpdate = DataOnUpdatingInformationBase();
		LegalVersion = DataAboutUpdate.LegalVersion;
	EndIf;
	
	Return LegalVersion <> Metadata.Version;
	
EndFunction

// Only for internal use.
Procedure WriteUpdatesReceiveLegalityConfirmation() Export
	
	If CommonUseReUse.DataSeparationEnabled()
	   AND Not CommonUseReUse.CanUseSeparatedData()
	   Or StandardSubsystemsServer.ThisIsBasicConfigurationVersion() Then
		
		Return;
	EndIf;
	
	DataAboutUpdate = DataOnUpdatingInformationBase();
	DataAboutUpdate.LegalVersion = Metadata.Version;
	WriteDataOnUpdatingInformationBase(DataAboutUpdate);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see description of the OnSendDataToSubordinate event handler in the syntax helper.
// 
Procedure OnSendDataToSubordinate(DataItem, ItemSend, CreatingInitialImage, Recipient) Export
	
	InfobaseUpdateEvents.OnSubsystemsVersionsSending(DataItem, ItemSend, CreatingInitialImage);
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see description of the OnSendDataMain() event handler in the syntax helper.
// 
Procedure OnSendDataToMaster(DataItem, ItemSend, Recipient) Export
	
	InfobaseUpdateEvents.OnSubsystemsVersionsSending(DataItem, ItemSend);
	
EndProcedure

// Adds parameters of the clients logic work during the system launch for a subsystem of the data exchange in the service model.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystemsRunning(Parameters) Export
	
	Parameters.Insert("InitialDataFilling", DataUpdateMode() = "InitialFilling");
	Parameters.Insert("ShowSystemChangesDescription", ShowSystemChangesDescription());
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	HandlersStatus = FailedHandlersStatus();
	If HandlersStatus = "" Then
		Return;
	EndIf;
	If HandlersStatus = "StatusError"
		AND Users.InfobaseUserWithFullAccess(, True) Then
		Parameters.Insert("ShowMessageAboutErrorHandlers");
	Else
		Parameters.Insert("ShowAlertAboutFailedHandlers");
	EndIf;
	
EndProcedure

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.

// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.CheckUpdateReceiveLegality") Then
		Handler = Handlers.Add();
		Handler.InitialFilling = True;
		Handler.Procedure = "InfobaseUpdateService.WriteUpdatesReceiveLegalityConfirmation";
	EndIf;
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.4";
	Handler.Procedure = "InfobaseUpdateService.SetChangeDescriptionsVersion";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.19";
	Handler.Procedure = "InfobaseUpdateService.TransferSubsystemVersionsInUndividedData";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.7";
	Handler.Procedure = "InfobaseUpdateService.FillAttributeIsMainConfiguration";
	Handler.SharedData = True;
	
EndProcedure

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
Procedure OnGettingObligatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
EndProcedure

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
Procedure OnGetPrimaryImagePlanExchangeObjects(Objects) Export
	
	Objects.Add(Metadata.InformationRegisters.SubsystemVersions);
	
EndProcedure

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
Procedure OnGettingObjectExceptionsOfExchangePlan(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Constants.SystemChangesDescribeSections);
		
	EndIf;
	
EndProcedure

// Handler of the OnReceiveTemplatesList event.
//
// Forms a list of queue jobs templates
//
// Parameters:
//  Patterns - String array. You should add the names
//   of predefined undivided scheduled jobs in the parameter
//   that should be used as a template for setting a queue.
//
Procedure ListOfTemplatesOnGet(Patterns) Export
	
	Patterns.Add("DeferredInfobaseUpdate");
	
EndProcedure

// Returns a match of session parameters and handlers parameters to initialize them.
//
Procedure OnAddSessionSettingsSetupHandler(Handlers) Export
	
	Handlers.Insert("InfobaseUpdateIsExecute", "InfobaseUpdateService.SessionParametersSetting");
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    External ID - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    Commands group important        - Boolean - If True, the work is marked in red.
//    * Presentation String - a work presentation displayed to the user.
//    * Count Number  - a quantitative indicator of work, it is displayed in the work header string.
//    •  For the Inventory writing off  document a print form is added         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip String - The tooltip wording.
//
Procedure AtFillingToDoList(CurrentWorks) Export
	
	ModuleCurrentWorksService = CommonUse.CommonModule("CurrentWorksService");
	If Not Users.InfobaseUserWithFullAccess(, True)
		Or ModuleCurrentWorksService.WorkDisabled("PostponedUpdate") Then
		Return;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	ModuleCurrentWorksServer = CommonUse.CommonModule("CurrentWorksServer");
	
	// The procedure is called only if there is the
	// To-do lists subsystem, that is why here is no checking of subsystem existence.
	Sections = ModuleCurrentWorksServer.SectionsForObject(Metadata.DataProcessors.InfobaseUpdate.FullName());
	
	If Sections = Undefined Then
		Return;
	EndIf;
	
	HandlersStatus           = FailedHandlersStatus();
	HasHandlersWithError      = (HandlersStatus = "StatusError");
	IsNotExecutedHandlers = (HandlersStatus = "StateNotCompleted");
	
	For Each Section IN Sections Do
		ID = "PostponedUpdate" + StrReplace(Section.FullName(), ".", "");
		Work = CurrentWorks.Add();
		Work.ID = ID;
		Work.ThereIsWork      = (HasHandlersWithError Or IsNotExecutedHandlers);
		Work.Important        = HasHandlersWithError;
		Work.Presentation = NStr("en='Application update is not completed';ru='Обновление программы не завершено'");
		Work.Form         = "DataProcessor.InfobaseUpdate.Form.InfobaseDelayedUpdateProgressIndication";
		Work.Owner      = Section;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Defines if the End users
// work subsystem is used in the configuration.
//
// Parameters:
//  Used - Boolean - True if used False - else.
//
Procedure WhenDeterminingUseUserSessionsSubsystems(Used)
	
	If CommonUse.SubsystemExists("StandardSubsystems.UserSessions") Then
		Used = True;
	EndIf;
	
EndProcedure

// Unlocks the file infobase.
//
Procedure WhenRemovingLockFileBase() Export
	
	If Not CommonUse.FileInfobase() Then
		Return;
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.UserSessions") Then
		DBModuleConnections = CommonUse.CommonModule("InfobaseConnections");
		DBModuleConnections.AllowUsersWork();
	EndIf;
	
EndProcedure

// Sets a use of the scheduled job of filling access managing data.
//
// Parameters:
// Use - Boolean - True if the job should be included, otherwise, False.
//
Procedure OnEnablePostponedUpdating(Val Use) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.InfobaseVersionUpdateSaaS") Then
		ModuleInfobaseUpdateServiceSaaS = CommonUse.CommonModule("InfobaseUpdateServiceSaaS");
		ModuleInfobaseUpdateServiceSaaS.OnEnablePostponedUpdating(Use);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE HANDLERS

// Transfers data from the DeleteSubsystemsVersions information register to the SubsystemsVersions information register.
//
Procedure TransferSubsystemVersionsInUndividedData() Export
	
	BeginTransaction();
	
	Try
		
		If CommonUseReUse.DataSeparationEnabled() Then
			AreaForCommonData = -1;
		Else
			AreaForCommonData = 0;
		EndIf;
		
		QueryText =
		"SELECT
		|	DeleteVersionSubsystems.SubsystemName,
		|	DeleteVersionSubsystems.Version,
		|	DeleteVersionSubsystems.UpdatePlan
		|FROM
		|	InformationRegister.DeleteVersionSubsystems AS DeleteVersionSubsystems
		|WHERE
		|	DeleteVersionSubsystems.DataArea = &DataArea";
		
		Query = New Query(QueryText);
		Query.SetParameter("DataArea", AreaForCommonData);
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			Manager = InformationRegisters.SubsystemVersions.CreateRecordManager();
			Manager.SubsystemName = Selection.SubsystemName;
			Manager.Version = Selection.Version;
			Manager.UpdatePlan = Selection.UpdatePlan;
			Manager.Write();
			
		EndDo;
		
		Set = InformationRegisters.DeleteVersionSubsystems.CreateRecordSet();
		Set.Filter.DataArea.Set(AreaForCommonData);
		Set.Write();
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Fills the value if the IsMainConfiguration attribute in the register records of the SubsystemsVersions information.
//
Procedure FillAttributeIsMainConfiguration() Export
	
	SetIBVersion(Metadata.Name, IBVersion(Metadata.Name), True);
	
EndProcedure

// Sets last displayed version of describing changes
// to all data field users in the current version (by the SubsystemsVersions register data).
//
Procedure SetVersionOfDescriptionsOfChanges() Export
	
	CurrentVersion = IBVersion(Metadata.Name);
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.InfobaseUserID AS ID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Service = FALSE
	|	AND Users.InfobaseUserID <> &EmptyID";
	Query.SetParameter("EmptyID", New UUID("00000000-0000-0000-0000-000000000000"));
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		IBUser = InfobaseUsers.FindByUUID(Selection.ID);
		If IBUser = Undefined Then
			Continue;
		EndIf;
		
		LastVersion = LastDisplayedVersionSystemChanges(IBUser.Name);
		If LastVersion <> Undefined Then
			Return;
		EndIf;
		
		LastVersion = CurrentVersion;
		
		ExecutedHandlers = CommonUse.CommonSettingsStorageImport("UpdateInfobase", 
			"ExecutedHandlers", , , IBUser.Name);
			
		If ExecutedHandlers <> Undefined Then
			
			If ExecutedHandlers.Rows.Count() > 0 Then
				Version = ExecutedHandlers.Rows[ExecutedHandlers.Rows.Count() - 1].Version;
				If Version <> "*" Then
					LastVersion = Version;
				EndIf;
			EndIf;
			
		EndIf;
		
		CommonUse.CommonSettingsStorageSave("UpdateInfobase",
			"LastDisplayedVersionSystemChanges", LastVersion, , IBUser.Name);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Common use

Function DataUpdateModeInLocalWorkMode()
	
	SetPrivilegedMode(True);
	Query = New Query;
	Query.Text = 
		"SELECT
		|	1 AS Field1
		|FROM
		|	InformationRegister.SubsystemVersions AS SubsystemVersions
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1
		|FROM
		|	InformationRegister.DeleteVersionSubsystems AS DeleteVersionSubsystems";
	
	PackageExecutionResult = Query.ExecuteBatch();
	If PackageExecutionResult[0].IsEmpty() AND PackageExecutionResult[1].IsEmpty() Then
		Return "InitialFilling";
	ElsIf PackageExecutionResult[0].IsEmpty() AND Not PackageExecutionResult[1].IsEmpty() Then
		Return "VersionUpdate"; // Support update with SSL 2.1.2.
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	1 AS Field1
		|FROM
		|	InformationRegister.SubsystemVersions AS SubsystemVersions
		|WHERE
		|	SubsystemVersions.ThisMainConfiguration = TRUE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Field1
		|FROM
		|	InformationRegister.SubsystemVersions AS SubsystemVersions
		|WHERE
		|	SubsystemVersions.SubsystemName = &MainConfigurationName
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Field1
		|FROM
		|	InformationRegister.SubsystemVersions AS SubsystemVersions
		|WHERE
		|	SubsystemVersions.ThisMainConfiguration = TRUE
		|	AND SubsystemVersions.SubsystemName = &MainConfigurationName";
	Query.SetParameter("MainConfigurationName", Metadata.Name);
	PackageExecutionResult = Query.ExecuteBatch();
	If PackageExecutionResult[0].IsEmpty() AND Not PackageExecutionResult[1].IsEmpty() Then
		Return "VersionUpdate"; // IsMainConfiguration trait was not filled.
	EndIf;
	
	// Define by the previously filled IsMainConfiguratin trait.
	Return ?(PackageExecutionResult[2].IsEmpty(), "TransitionFromAnotherApplication", "VersionUpdate");
	
EndFunction	

Function PerhapsOperationalUpdate(IterationsUpdate)
	
	FiltersHandlersDivision = New Array;
	If Not CommonUseReUse.CanUseSeparatedData() Then
		FiltersHandlersDivision.Add(False);
	EndIf;
	FiltersHandlersDivision.Add(True);
	
	// The parameter is not used in the checking mode.
	RequiredSeparateHandlers = InfobaseUpdate.NewUpdateHandlersTable();
	
	ToWriteInJournal = Constants.DetailInfobaseUpdateInEventLogMonitor.Get();
	
	// Check handlers of the update with the ExclusiveMode check box for configuration subsystems.
	For Each IterationUpdate IN IterationsUpdate Do
		
		For Each DivisionFlag IN FiltersHandlersDivision Do
		
			HandlerTree = UpdateHandlersInInterval(IterationUpdate.Handlers,
				IterationUpdate.PreviousVersion,
				IterationUpdate.Version,
				DivisionFlag,
				"Promptly");
				
			If HandlerTree.Rows.Count() = 0 Then
				Continue;
			EndIf;
				
			If HandlerTree.Rows.Count() > 1 
				OR HandlerTree.Rows[0].Version <> "*" Then
				
				Return False; // There are exclusive handlers of update for a version.
			EndIf;
			
			If DivisionFlag 
				AND CommonUseReUse.DataSeparationEnabled() 
				AND Not CommonUseReUse.CanUseSeparatedData() Then
				
				// During execution of an undivided IB version
				// an exclusive mode is managed by an undivided handler for divided mandatory update handlers.
				Continue;
			EndIf;
			
			If HandlerTree.Rows[0].Rows.FindRows(
					New Structure("ExclusiveMode", Undefined)).Count() > 0 Then
					
				Return False; // There are mandatory handlers with an unconditional exclusive mode.
			EndIf;
			
			// Call mandatory handlers of update in the check mode.
			For Each Handler IN HandlerTree.Rows[0].Rows Do
				If Handler.VersionRegistration <> "*" Then
					Return False; // There are exclusive handlers of update for a version.
				EndIf;
				
				HandlerParameters = New Structure;
				If Handler.HandlersManagement Then
					HandlerParameters.Insert("SeparatedHandlers", RequiredSeparateHandlers);
				EndIf;
				HandlerParameters.Insert("ExclusiveMode", False);
				
				AdditionalParameters = New Structure("ToWriteInJournal, LibraryID, HandlersExecutionProcess, InBackground",
					ToWriteInJournal, IterationUpdate.Subsystem, Undefined, False);
				
				ExecuteHandlerUpdate(Handler, HandlerParameters, AdditionalParameters);
				
				If HandlerParameters.ExclusiveMode = True Then
					Return False; // Update is required in the exclusive mode.
				EndIf;
			EndDo;
			
		EndDo;
	EndDo;
	
	Return True;
	
EndFunction

Procedure CopyRowsToTree(Val TargetRows, Val SourceRows, Val ColumnStructure)
	
	For Each SourceRow IN SourceRows Do
		FillPropertyValues(ColumnStructure, SourceRow);
		FoundStrings = TargetRows.FindRows(ColumnStructure);
		If FoundStrings.Count() = 0 Then
			TargetRow = TargetRows.Add();
			FillPropertyValues(TargetRow, SourceRow);
		Else
			TargetRow = FoundStrings[0];
		EndIf;
		
		CopyRowsToTree(TargetRow.Rows, SourceRow.Rows, ColumnStructure);
	EndDo;
	
EndProcedure

Function GetUpdatePlan(Val LibraryID, Val VersionFrom, Val VersionOn)
	
	RecordManager = InformationRegisters.SubsystemVersions.CreateRecordManager();
	RecordManager.SubsystemName = LibraryID;
	RecordManager.Read();
	If Not RecordManager.Selected() Then
		Return Undefined;
	EndIf;
	
	PlanDescription = RecordManager.UpdatePlan.Get();
	If PlanDescription = Undefined Then
		
		Return Undefined;
		
	Else
		
		If PlanDescription.VersionFrom <> VersionFrom
			OR PlanDescription.VersionOn <> VersionOn Then
			
			// Plan is outdated and does not correspond to the current version.
			Return Undefined;
		EndIf;
		
		Return PlanDescription.Plan;
		
	EndIf;
	
EndFunction

// Disables update handlers filled in the procedure.
// InfobaseUpdateOverridable.OnDisableUpdateHandlers.
//
// Parameters:
//  LibraryID - String - configuration name and library identifier.
//  HandlersToExecute  - ValueTree - IB update handlers.
//  MetadataIBVersion      - String - metadata version. Disable only
//                                     handlers that have the same version as metadata has.
//
Procedure DisableUpdateHandlers(LibraryID, HandlersToExecute, MetadataVersion, HandlersExecutionProcess)
	
	SwitchableHandlers = New ValueTable;
	SwitchableHandlers.Columns.Add("LibraryID");
	SwitchableHandlers.Columns.Add("Procedure");
	SwitchableHandlers.Columns.Add("Version");
	
	InfobaseUpdateOverridable.OnDisableUpdateHandlers(SwitchableHandlers);
	// Call of the outdated procedure for the backward compatibility.
	InfobaseUpdateOverridable.AddDisablingUpdateHandlers(SwitchableHandlers);
	
	// Search for a tree row containing handlers of the update with the * version.
	LibraryHandlers = HandlersToExecute.Rows.Find("*", "Version", False);
	
	For Each DisabledHandler IN SwitchableHandlers Do
		
		// Check if the disabled handler belongs to the transferred library.
		If LibraryID <> DisabledHandler.LibraryID Then
			Continue;
		EndIf;
		
		// Check if the handler is in the exception list.
		RunningHandler = HandlersToExecute.Rows.Find(DisabledHandler.Procedure, "Procedure", True);
		If RunningHandler <> Undefined AND RunningHandler.Version = "*"
			AND DisabledHandler.Version = MetadataVersion Then
			LibraryHandlers.Rows.Delete(RunningHandler);
			HandlersExecutionProcess.HandlersToTotal = HandlersExecutionProcess.HandlersToTotal - 1;
		ElsIf RunningHandler <> Undefined AND RunningHandler.Version <> "*"
			AND DisabledHandler.Version = MetadataVersion Then
			ErrorMessage = NStr("en='The handler of %1 update cannot be disabled as it is executed only when changing to version %2.';ru='Обработчик обновления %1 не может быть отключен, так как он выполняется только при переходе на версию %2'");
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage,
				RunningHandler.Procedure, RunningHandler.Version);
			
			Raise ErrorMessage;
		ElsIf RunningHandler = Undefined Then
			ErrorMessage = NStr("en='Disabled update handler %1 does not exist';ru='Отключаемый обработчик обновления %1 не существует'");
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage,
				DisabledHandler.Procedure);
			
			Raise ErrorMessage;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ExecuteHandlerUpdate(Handler, Parameters, AdditionalParameters)
	
	WriteInformationAboutUpdate(Handler, AdditionalParameters.HandlersExecutionProcess, AdditionalParameters.InBackground);
	If AdditionalParameters.ToWriteInJournal Then
		ProcessingDetails = 
			PrepareDetailedInformationAboutUpdate(Handler, Parameters, AdditionalParameters.LibraryID);
	EndIf;
	
	If Parameters <> Undefined Then
		HandlerParameters = New Array;
		HandlerParameters.Add(Parameters);
	Else
		HandlerParameters = Undefined;
	EndIf;
	
	TransactionActiveOnExecutionStart = TransactionActive();
	
	Try
		WorkInSafeMode.ExecuteConfigurationMethod(Handler.Procedure, HandlerParameters);
	Except
		
		If AdditionalParameters.ToWriteInJournal Then
			WriteDetailedInformationAboutUpdate(ProcessingDetails);
		EndIf;
		
		HandlerName = Handler.Procedure + "(" + ?(HandlerParameters = Undefined, "", "Parameters") + ")";
		
		WriteError(StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='During the call
		|of
		|the update
		|handler: %1 an error occurred: %2';ru='При вызове
		|обработчика
		|обновления:
		|""%1"" произошла ошибка: ""%2"".'"),
			HandlerName,
			DetailErrorDescription(ErrorInfo())));
		
		Raise;
	EndTry;
	
	ValidateNestedTransaction(TransactionActiveOnExecutionStart, Handler.Procedure);
	
	If AdditionalParameters.ToWriteInJournal Then
		WriteDetailedInformationAboutUpdate(ProcessingDetails);
	EndIf;
	
EndProcedure

Procedure ExecuteHandlersAfterInfobaseUpdate(Val IterationsUpdate, Val ToWriteInJournal, PutSystemChangesDescription, Val OperationalUpdate)
	
	For Each IterationUpdate IN IterationsUpdate Do
		
		If ToWriteInJournal Then
			Handler = New Structure();
			Handler.Insert("Version", "*");
			Handler.Insert("VersionRegistration", "*");
			Handler.Insert("PerformModes", "Promptly");
			Handler.Insert("Procedure", IterationUpdate.ServerModuleName + ".AfterInfobaseUpdate");
			ProcessingDetails =  PrepareDetailedInformationAboutUpdate(Handler, Undefined, IterationUpdate.Subsystem);
		EndIf;
		
		Try
			
			IterationUpdate.MainServerModule.AfterInformationBaseUpdate(
				IterationUpdate.PreviousVersion,
				IterationUpdate.Version,
				IterationUpdate.ExecutedHandlers,
				PutSystemChangesDescription,
				Not OperationalUpdate);
				
		Except
			
			If ToWriteInJournal Then
				WriteDetailedInformationAboutUpdate(ProcessingDetails);
			EndIf;
			
			Raise;
			
		EndTry;
		
		If ToWriteInJournal Then
			WriteDetailedInformationAboutUpdate(ProcessingDetails);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ExecuteDeferredUpdate() Export
	//TODO: Get function from SL. Check how Catalogs.QueueJobsTemplates element with name "DeferredInfobaseUpdate" should be created.
EndProcedure
	
Function PrepareDetailedInformationAboutUpdate(Handler, Parameters, LibraryID, PostponedHandler = False)
	
	ProcessingDetails = New Structure;
	ProcessingDetails.Insert("Library", LibraryID);
	If PostponedHandler Then
		ProcessingDetails.Insert("Version", Handler.VersionNumber);
		ProcessingDetails.Insert("Procedure", Handler.HandlerName);
	Else
		ProcessingDetails.Insert("Version", Handler.Version);
		ProcessingDetails.Insert("Procedure", Handler.Procedure);
	EndIf;
	ProcessingDetails.Insert("VersionRegistration", Handler.VersionRegistration);
	ProcessingDetails.Insert("Parameters", Parameters);
	
	If PostponedHandler Then
		ProcessingDetails.Insert("PerformModes", "Delay");
	ElsIf ValueIsFilled(Handler.PerformModes) Then
		ProcessingDetails.Insert("PerformModes", Handler.PerformModes);
	Else
		ProcessingDetails.Insert("PerformModes", "Exclusive");
	EndIf;
	
	If CommonUseReUse.IsSeparatedConfiguration()
		AND CommonUse.UseSessionSeparator() Then
		
		ProcessingDetails.Insert("DataAreaValue", CommonUse.SessionSeparatorValue());
		ProcessingDetails.Insert("DataAreasUse", True);
		
	Else
		
		ProcessingDetails.Insert("DataAreaValue", -1);
		ProcessingDetails.Insert("DataAreasUse", False);
		
	EndIf;
	
	ProcessingDetails.Insert("ValueOnBegin", CurrentUniversalDateInMilliseconds());
	
	Return ProcessingDetails;
	
EndFunction

Procedure WriteDetailedInformationAboutUpdate(ProcessingDetails)
	
	Duration = CurrentUniversalDateInMilliseconds() - ProcessingDetails.ValueOnBegin;
	
	ProcessingDetails.Insert("Completed", False);
	ProcessingDetails.Insert("Duration", Duration / 1000); // IN seconds
	
	WriteLogEvent(
		EventLogMonitorMessageTextProtocol(),
		EventLogLevel.Information,
		,
		,
		CommonUse.ValueToXMLString(ProcessingDetails));
	
EndProcedure

Procedure ValidateNestedTransaction(TransactionActiveOnExecutionStart, ProcessorsName)
	
	EventName = EventLogMonitorEvent() + ". " + NStr("en='Executing handlers';ru='Выполнение обработчиков'", CommonUseClientServer.MainLanguageCode());
	If TransactionActiveOnExecutionStart Then
		
		If TransactionActive() Then
			// Check absorbed exceptions in handlers.
			Try
				Constants.UseSeparationByDataAreas.Get();
			Except
				CommentTemplate = NStr("en='An error executing the
		|%1 handler update: Update handler absorbed the exception during the active external transaction.
		|In case of the active transactions opened above of the stack the exception is also to be located above of the stack.';ru='Ошибка выполнения обработчика
		|обновления %1: Обработчиком обновления было поглощено исключение при активной внешней транзакции.
		|При активных транзакциях, открытых выше по стеку, исключение также необходимо пробрасывать выше по стеку.'");
				Comment = StringFunctionsClientServer.SubstituteParametersInString(CommentTemplate, ProcessorsName);
				
				WriteLogEvent(EventName, EventLogLevel.Error,,, Comment);
				Raise(Comment);
			EndTry;
		Else
			CommentTemplate = NStr("en='An error occurred executing
		|the %1 application handler: Handler of the update closed an extra transaction previously opened (up in a stack).';ru='Ошибка выполнения
		|обработчика обновления %1: Обработчиком обновления была закрыта лишняя транзакция, открытая ранее (выше по стеку).'");
			Comment = StringFunctionsClientServer.SubstituteParametersInString(CommentTemplate, ProcessorsName);
			
			WriteLogEvent(EventName, EventLogLevel.Error,,, Comment);
			Raise(Comment);
		EndIf;
	Else
		If TransactionActive() Then
			CommentTemplate = NStr("en='An error occurred executing
		|the %1 application handler: The transaction opened inside the handler remained active (was not closed or canceled).';ru='Ошибка выполнения
		|обработчика обновления %1: Открытая внутри обработчика обновления транзакция осталась активной (не была закрыта или отменена).'");
			Comment = StringFunctionsClientServer.SubstituteParametersInString(CommentTemplate, ProcessorsName);
			
			WriteLogEvent(EventName, EventLogLevel.Error,,, Comment);
			Raise(Comment);
		EndIf;
	EndIf;
	
EndProcedure

Procedure ValidateHandlersProperties(IterationUpdate)
	
	For Each Handler IN IterationUpdate.Handlers Do
		ErrorDescription = "";
		
		If IsBlankString(Handler.Version) Then
			
			If Handler.InitialFilling <> True Then
				ErrorDescription = NStr("en='The Version or InitialFilling property is not filled out in the handler.';ru='У обработчика не заполнено свойство Версия или свойство НачальноеЗаполнение.'");
			EndIf;
			
		ElsIf Handler.Version <> "*" Then
			
			Try
				ZeroVersion = CommonUseClientServer.CompareVersions(Handler.Version, "0.0.0.0") = 0;
			Except
				ZeroVersion = False;
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Handler has filled the Version property wrong: %1.
		|Correct format, for example: 21.3.70.';ru='У обработчика не правильно заполнено свойство Версия: ""%1"".
		|Правильный формат, например: ""2.1.3.70"".'"),
					Metadata.Version);
			EndTry;
			
			If ZeroVersion Then
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Handler has filled the Version property wrong: %1.
		|Version can not be the zero.';ru='У обработчика не правильно заполнено свойство Версия: ""%1"".
		|Версия не может быть нулевой.'"),
					Metadata.Version);
			EndIf;
			
			If Not ValueIsFilled(ErrorDescription)
			   AND Handler.ExecuteUnderMandatory <> True
			   AND Handler.Priority <> 0 Then
				
				ErrorDescription = NStr("en='The Priority property or the ExecuteInMandatoryGroup
		|property is filled wrong in the handler.';ru='У обработчика не правильно заполнено
		|свойство Приоритет или свойство ВыполнятьВГруппеОбязательных.'");
			EndIf;
		EndIf;
		
		If Handler.PerformModes <> ""
			AND Handler.PerformModes <> "Exclusive"
			AND Handler.PerformModes <> "Promptly"
			AND Handler.PerformModes <> "Delay" Then
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en=""Handler's ExecutionMode property is filled wrong in the %1 handler.
		|Allowed value: Exclusive, Deferred, Online."";ru='У обработчика ""%1"" не правильно заполнено свойство РежимВыполнения.
		|Допустимое значение: ""Монопольно"", ""Отложенно"", ""Оперативно"".'"),
				Handler.Procedure);
		EndIf;
		
		If Not ValueIsFilled(ErrorDescription)
		   AND Handler.Optional = True
		   AND Handler.InitialFilling = True Then
			
			ErrorDescription = NStr("en='The Optional or InitialFilling property is
		|filled wrong in the handler.';ru='У обработчика не правильно заполнено
		|свойство Опциональный или свойство НачальноеЗаполнение.'");
		EndIf;
			
		If Not ValueIsFilled(ErrorDescription) Then
			Continue;
		EndIf;
		
		If IterationUpdate.ThisMainConfiguration Then
			ErrorTitle = NStr("en='An error occurred in the property of the configuration update handler';ru='Ошибка в свойстве обработчика обновления конфигурации'");
		Else
			ErrorTitle = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='An error occurred in the property of library update handler %1 of version %2';ru='Ошибка в свойстве обработчика обновления библиотеки %1 версии %2'"),
				IterationUpdate.Subsystem,
				IterationUpdate.Version);
		EndIf;
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			ErrorTitle + Chars.LF
			+ NStr("en='(%1).';ru='(%1).'") + Chars.LF
			+ Chars.LF
			+ ErrorDescription,
			Handler.Procedure);
		
		WriteError(ErrorDescription);
		Raise ErrorDescription;

	EndDo;
	
EndProcedure

Function CountHandlersToCurrentVersion(IterationsUpdate)
	
	HandlersCount = 0;
	For Each IterationUpdate IN IterationsUpdate Do
		
		HandlersByVersion = UpdateHandlersInInterval(
			IterationUpdate.Handlers, IterationUpdate.PreviousVersion, IterationUpdate.Version);
		For Each RowHandlersVersion IN HandlersByVersion.Rows Do
			HandlersCount = HandlersCount + RowHandlersVersion.Rows.Count();
		EndDo;
		
	EndDo;
	
	Message = NStr("en='To update the application to a new version, the following handlers will be executed: %1';ru='Для обновления программы на новую версию будут выполнены обработчики: %1'");
	Message = StringFunctionsClientServer.SubstituteParametersInString(Message, HandlersCount);
	WriteInformation(Message);
	
	Return New Structure("TotalHandlers, CompletedHandlers", HandlersCount, 0);
	
EndFunction

Function MetadataObjectNameByManagerName(ManagerName)
	
	Position = Find(ManagerName, ".");
	If Position = 0 Then
		Return "CommonModule." + ManagerName;
	EndIf;
	ManagerType = Left(ManagerName, Position - 1);
	
	TypesNames = New Map;
	TypesNames.Insert(CommonUse.TypeNameCatalogs(), "Catalog");
	TypesNames.Insert(CommonUse.TypeNameDocuments(), "Document");
	TypesNames.Insert(CommonUse.TypeNameDataProcessors(), "DataProcessor");
	TypesNames.Insert(CommonUse.TypeNameChartsOfCharacteristicTypes(), "ChartOfCharacteristicTypes");
	TypesNames.Insert(CommonUse.TypeNameOfAccountingRegisters(), "AccountingRegister");
	TypesNames.Insert(CommonUse.TypeNameAccumulationRegisters(), "AccumulationRegister");
	TypesNames.Insert(CommonUse.NameKindCalculationRegisters(), "CalculationRegister");
	TypesNames.Insert(CommonUse.TypeNameInformationRegisters(), "InformationRegister");
	TypesNames.Insert(CommonUse.BusinessProcessTypeName(), "BusinessProcess");
	TypesNames.Insert(CommonUse.TypeNameDocumentJournals(), "DocumentJournal");
	TypesNames.Insert(CommonUse.TypeNameTasks(), "Task");
	TypesNames.Insert(CommonUse.TypeNameReports(), "Report");
	TypesNames.Insert(CommonUse.TypeNameConstants(), "Constant");
	TypesNames.Insert(CommonUse.TypeNameEnums(), "Enum");
	TypesNames.Insert(CommonUse.TypeNameChartsOfCalculationTypes(), "ChartOfCalculationTypes");
	TypesNames.Insert(CommonUse.TypeNameExchangePlans(), "ExchangePlan");
	TypesNames.Insert(CommonUse.TypeNameChartsOfAccounts(), "ChartOfAccounts");
	
	TypeName = TypesNames[ManagerType];
	If TypeName = Undefined Then
		Return ManagerName;
	EndIf;
	
	Return TypeName + Mid(ManagerName, Position);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Protocol the update progress.

Procedure WriteInformation(Val Text)
	
	WriteLogEvent(EventLogMonitorEvent(), EventLogLevel.Information,,, Text);
	
EndProcedure

Procedure WriteError(Val Text)
	
	WriteLogEvent(EventLogMonitorEvent(), EventLogLevel.Error,,, Text);
	
EndProcedure

Procedure WriteInformationAboutUpdate(Handler, HandlersExecutionProcess, InBackground)
	
	If HandlersExecutionProcess = Undefined Then
		Return;
	EndIf;
	
	HandlersExecutionProcess.CompletedHandlers = HandlersExecutionProcess.CompletedHandlers + 1;
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Message = NStr("en='Update handler %1 is in progress (%2 of %3).';ru='Выполняется обработчик обновления %1 (%2 из %3).'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(
			Message, Handler.Procedure,
			HandlersExecutionProcess.CompletedHandlers, HandlersExecutionProcess.TotalHandlers);
		WriteInformation(Message);
	EndIf;
	
	If InBackground Then
		Progress = HandlersExecutionProcess.CompletedHandlers / HandlersExecutionProcess.TotalHandlers * 100;
		CommonUseClientServer.MessageToUser("IncreaseInProgressStep=" + Progress);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updates description

// Display changes descriptions in the specified version.
//
// Parameters:
//  VersionNumber  - String - number of version, for which the description
//                          from the template of tabular document TemplateUpdatesDescription into tabular document.
//                          DocumentUpdateDescription.
//
Procedure DisplayLongDescChanges(Val VersionNumber, DocumentSystemChangesDescription, TemplateUpdatesDescriptionFull)
	
	Number = StrReplace(VersionNumber, ".", "_");
	
	If TemplateUpdatesDescriptionFull.Areas.Find("Header" + Number) = Undefined Then
		Return;
	EndIf;
	
	DocumentSystemChangesDescription.Put(TemplateUpdatesDescriptionFull.GetArea("Header" + Number));
	DocumentSystemChangesDescription.StartRowGroup("Version" + Number);
	DocumentSystemChangesDescription.Put(TemplateUpdatesDescriptionFull.GetArea("Version" + Number));
	DocumentSystemChangesDescription.EndRowGroup();
	DocumentSystemChangesDescription.Put(TemplateUpdatesDescriptionFull.GetArea("Indent"));
	
EndProcedure

Function LastDisplayedVersionSystemChanges(Val UserName = Undefined) Export
	
	If UserName = Undefined Then
		UserName = UserName();
	EndIf;
	
	LastVersion = CommonUse.CommonSettingsStorageImport("UpdateInfobase",
		"LastDisplayedVersionSystemChanges", , , UserName);
	
	Return LastVersion;
	
EndFunction

// Gets a list of the versions from the SystemChangesDescription
// common layout and saves it in the SystemChangesSectionsDescription constant.
//
Procedure RefreshSectionsDescribingChanges()
	
	Sections = New ValueList;
	
	TemplateUpdatesDescriptionFull = Metadata.CommonTemplates.Find("SystemChangesDescription");
	If TemplateUpdatesDescriptionFull <> Undefined Then
		VersionsPredicate = "Version";
		PredicateOfHeader = "Header";
		Template = GetCommonTemplate(TemplateUpdatesDescriptionFull);
		
		For Each Area IN Template.Areas Do
			If Find(Area.Name, VersionsPredicate) = 0 Then
				Continue;
			EndIf;
			
			VersionInFormatDescription = Mid(Area.Name, StrLen(VersionsPredicate) + 1);
			
			If Template.Areas.Find(PredicateOfHeader + VersionInFormatDescription) = Undefined Then
				Continue;
			EndIf;
			
			LevelRowVersions = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(VersionInFormatDescription, "_");
			If LevelRowVersions.Count() <> 4 Then
				Continue;
			EndIf;
			
			WeightVersion = VersionWeightFromRowsArray(LevelRowVersions);
			
			Version = ""
				+ Number(LevelRowVersions[0]) + "."
				+ Number(LevelRowVersions[1]) + "."
				+ Number(LevelRowVersions[2]) + "."
				+ Number(LevelRowVersions[3]);
				
			Sections.Add(WeightVersion, Version);
		EndDo;
		
		Sections.SortByValue(SortDirection.Desc);
	EndIf;
	
	Constants.SystemChangesDescribeSections.Set(New ValueStorage(Sections));
	
EndProcedure

Procedure DefineUpdatesDescriptionOutput(PutSystemChangesDescription)
	
	If Not CommonUseReUse.DataSeparationEnabled()
		OR Not CommonUseReUse.CanUseSeparatedData() Then
		
		RefreshSectionsDescribingChanges();
	EndIf;
	
	If PutSystemChangesDescription AND Not CommonUseReUse.DataSeparationEnabled() Then
		CommonUse.CommonSettingsStorageSave("UpdateInfobase", "OutputSystemChangesDescriptionForAdministrator", True, , UserName());
	EndIf;
	
	If CommonUseReUse.CanUseSeparatedData() Then
		InfobaseUpdateData = DataOnUpdatingInformationBase();
		InfobaseUpdateData.PutSystemChangesDescription = PutSystemChangesDescription;
		
		WriteDataOnUpdatingInformationBase(InfobaseUpdateData);
	EndIf;
	
EndProcedure

// Returns the list of system changes description sections
//
// Returns:
//  ListValue - Value - version size (number), Presentation - version row.
//
Function SectionsDescribingChanges()
	
	Return Constants.SystemChangesDescribeSections.Get().Get();
	
EndFunction

Function VersionWeightFromRowsArray(LevelRowVersions)
	
	Return 0
		+ Number(LevelRowVersions[0]) * 1000000000
		+ Number(LevelRowVersions[1]) * 1000000
		+ Number(LevelRowVersions[2]) * 1000
		+ Number(LevelRowVersions[3]);
	
EndFunction

Function GreaterSpecifiedGetVersions(Sections, Version)
	
	Result = New Array;
	
	If Sections = Undefined Then
		RefreshSectionsDescribingChanges();
		Sections = SectionsDescribingChanges();
	EndIf;
	
	WeightVersion = WeightVersion(Version);
	For Each ItemOfList IN Sections Do
		If ItemOfList.Value <= WeightVersion Then
			Continue;
		EndIf;
		
		Result.Add(ItemOfList.Presentation);
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Helper procedures and functions of a deferred update.

// Only for internal use.
//
Function HandlersExecutedLegacy(IterationsUpdate)
	
	DataAboutUpdate = DataOnUpdatingInformationBase();
	If DataAboutUpdate.DeferredUpdateIsCompletedSuccessfully <> True
		AND DataAboutUpdate.HandlerTree <> Undefined
		AND DataAboutUpdate.HandlerTree.Rows.Count() > 0 Then
		
		RequiredSaveFailedHandlers = False;
		For Each Library IN IterationsUpdate Do
			// Reset quantity of attempts by handlers with the Error status.
			FoundsHandlers = DataAboutUpdate.HandlerTree.Rows.FindRows(New Structure("Status, LibraryName", "Error", Library.Subsystem), True);
			For Each TreeItem IN FoundsHandlers Do
				If TreeItem.VersionNumber <> "*"
					AND CommonUseClientServer.CompareVersions(Library.PreviousVersion, TreeItem.VersionNumber) >= 0 Then
					RequiredSaveFailedHandlers = True;
				EndIf;
				TreeItem.NumberAttempts = 0;
			EndDo;
			
			// Search for failed handlers that need to be saved for a restart.
			FoundsHandlers = DataAboutUpdate.HandlerTree.Rows.FindRows(New Structure("Status, LibraryName", "NotCompleted", Library.Subsystem), True);
			For Each TreeItem IN FoundsHandlers Do
				If TreeItem.VersionNumber <> "*"
					AND CommonUseClientServer.CompareVersions(Library.PreviousVersion, TreeItem.VersionNumber) >= 0 Then
					RequiredSaveFailedHandlers = True;
				EndIf;
			EndDo;
			
			If RequiredSaveFailedHandlers Then
				RequiredSaveFailedHandlers = False;
			Else
				RowLibrary = DataAboutUpdate.HandlerTree.Rows.Find(Library.Subsystem, "LibraryName");
				If RowLibrary <> Undefined Then
					DataAboutUpdate.HandlerTree.Rows.Delete(RowLibrary);
				EndIf;
			EndIf;
			
		EndDo;
		
		// Delete successfully completed handlers.
		FoundsHandlers = DataAboutUpdate.HandlerTree.Rows.FindRows(New Structure("Status", "Completed"), True);
		For Each TreeItem IN FoundsHandlers Do
			VersionString = TreeItem.Parent.Rows;
			VersionString.Delete(TreeItem);
		EndDo;
		
		Return DataAboutUpdate.HandlerTree;
		
	EndIf;
	
	Return NewInfoAboutUpdateHandlers();
	
EndFunction

// Only for internal use.
//
Procedure CheckExecuteTreeCompletedHandlers(HandlerTree)
	
	For Each TreeRowLibrary IN HandlerTree.Rows Do
		
		For Each TreeRowVersion IN TreeRowLibrary.Rows Do
			
			If TreeRowVersion.Rows.Count() = 0 Then
				TreeRowVersion.Status = "Completed";
			Else
				TreeRowVersion.Status = "";
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Only for internal use.
//
Procedure DisconnectPostponedUpdate()
	
	If CommonUseReUse.DataSeparationEnabled() Then
		OnEnablePostponedUpdating(False);
	Else
		ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.DeferredInfobaseUpdate);
		ScheduledJob.Use = False;
		ScheduledJob.Write();
	EndIf;
	
EndProcedure

// Only for internal use.
//
Function AllDelayedHandlersExecuted(DataAboutUpdate)
	
	CompletedHandlers = 0;
	TotalHandlers     = 0;
	For Each TreeRowLibrary IN DataAboutUpdate.HandlerTree.Rows Do
		For Each TreeRowVersion IN TreeRowLibrary.Rows Do
			TotalHandlers = TotalHandlers + TreeRowVersion.Rows.Count();
			For Each Handler IN TreeRowVersion.Rows Do
				
				If Handler.Status = "Completed" Then
					CompletedHandlers = CompletedHandlers + 1;
				EndIf;
				
			EndDo;
		EndDo;
	EndDo;
	
	If TotalHandlers = CompletedHandlers Then
		DataAboutUpdate.EndTimeDeferredUpdate = CurrentSessionDate();
		DataAboutUpdate.DeferredUpdateIsCompletedSuccessfully = True;
		WriteDataOnUpdatingInformationBase(DataAboutUpdate);
		
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Only for internal use.
//
Function ExecutePendingUpdateHandler(DataAboutUpdate, ExecuteFailed = False)
	
	HandlersWerePerformed     = False;
	AreFailed              = False;
	IsMissingHandlers = False;
	ToWriteInJournal = Constants.DetailInfobaseUpdateInEventLogMonitor.Get();
	
	For Each HandlerTreeLibrary IN DataAboutUpdate.HandlerTree.Rows Do
		
		If HandlerTreeLibrary.Status = "Completed" Then
			Continue;
		EndIf;
		
		For Each HandlerTreeVersion IN HandlerTreeLibrary.Rows Do
			
			If HandlerTreeVersion.Status = "Completed" Then
				Continue;
			EndIf;
			
			For Each UpdateHandler IN HandlerTreeVersion.Rows Do
				
				If UpdateHandler.Status = "Completed" Then
					Continue;
				EndIf;
				
				If UpdateHandler.NumberAttempts > 0 AND Not ExecuteFailed Then
					AreFailed = True;
					Continue;
				EndIf;
				
				If UpdateHandler.NumberAttempts >= 3 Then
					IsMissingHandlers = True;
					Continue;
				EndIf;
				
				TransactionActiveOnExecutionStart = TransactionActive();
				HandlersWerePerformed = True;
				HandlerName = UpdateHandler.HandlerName;
				Try
					MessageAboutRunningHandler = NStr("en='Updating ""%1"".';ru='Выполняется процедура обновления ""%1"".'");
					MessageAboutRunningHandler = StringFunctionsClientServer.SubstituteParametersInString(
						MessageAboutRunningHandler, HandlerName);
					WriteLogEvent(EventLogMonitorEvent(), 
							EventLogLevel.Information,,, MessageAboutRunningHandler);
					
					Parameters = Undefined;
					If DataAboutUpdate.Property("UpdateHandlerParameters", Parameters) Then
						If TypeOf(Parameters) = Type("Structure") Then
							Parameters.Insert("DataProcessorCompleted", True);
						Else
							Parameters = New Structure("DataProcessorCompleted", True);
						EndIf;
					Else
						Parameters = New Structure("DataProcessorCompleted", True);
					EndIf;
					
					HandlerParameters = New Array;
					HandlerParameters.Add(Parameters);
					
					If ToWriteInJournal Then
						ProcessingDetails = PrepareDetailedInformationAboutUpdate(UpdateHandler, Parameters, UpdateHandler.LibraryName, True);
					EndIf;
					
					UpdateHandler.Status = "Running";
					WorkInSafeMode.ExecuteConfigurationMethod(HandlerName, HandlerParameters);
					
					// Update handler sent parameters for saving.
					If Parameters.Count() > 1 AND Not Parameters.DataProcessorCompleted Then
						DataAboutUpdate.Insert("UpdateHandlerParameters", Parameters);
					EndIf;
					
					If Parameters.DataProcessorCompleted Then
						UpdateHandler.Status = "Completed";
						DataAboutUpdate.Delete("UpdateHandlerParameters");
						WriteDataOnUpdatingInformationBase(DataAboutUpdate);
					EndIf;
					
					If UpdateHandler.Status = "Running" Then
						WriteDataOnUpdatingInformationBase(DataAboutUpdate);
					EndIf;
					
				Except
					
					If ToWriteInJournal Then
						WriteDetailedInformationAboutUpdate(ProcessingDetails);
					EndIf;
					
					While TransactionActive() Do
						RollbackTransaction();
					EndDo;
					
					UpdateHandler.Status = "Error";
					DataAboutUpdate.Delete("UpdateHandlerParameters");
					UpdateHandler.NumberAttempts = UpdateHandler.NumberAttempts + 1;
					ErrorInfo = ErrorInfo();
					UpdateHandler.ErrorInfo = BriefErrorDescription(ErrorInfo());
					WriteDataOnUpdatingInformationBase(DataAboutUpdate);
					WriteError(DetailErrorDescription(ErrorInfo));
				EndTry;
				
				ValidateNestedTransaction(TransactionActiveOnExecutionStart, HandlerName);
				
				If ToWriteInJournal Then
					WriteDetailedInformationAboutUpdate(ProcessingDetails);
				EndIf;
				
				Break;
			EndDo;
			
			If Not HandlersWerePerformed AND AreFailed AND Not ExecuteFailed Then
				Return ExecutePendingUpdateHandler(DataAboutUpdate, True);
			EndIf;
			
			If AreFailed Or HandlersWerePerformed Then
				Break;
			Else
				
				If IsMissingHandlers Then
					HandlerTreeVersion.Status = "IsMissingHandlers";
				Else
					HandlerTreeVersion.Status = "Completed";
				EndIf;
				
			EndIf;
			
		EndDo;
		
		If AreFailed Or HandlersWerePerformed Then
			Break;
		Else
			
			If IsMissingHandlers Then
				HandlerTreeLibrary.Status = "IsMissingHandlers";
				Break;
			EndIf;
			
			HandlerTreeLibrary.Status = "Completed";
		EndIf;
		
	EndDo;
	
	If Not HandlersWerePerformed Then
		
		DataAboutUpdate.EndTimeDeferredUpdate = CurrentSessionDate();
		DataAboutUpdate.DeferredUpdateIsCompletedSuccessfully = Not IsMissingHandlers;
		WriteDataOnUpdatingInformationBase(DataAboutUpdate);
		
	EndIf;
	Return HandlersWerePerformed;
	
EndFunction

// Only for internal use.
//
Function NewDataAboutUpdate(OldInformation = Undefined)
	
	DataAboutUpdate = New Structure;
	DataAboutUpdate.Insert("UpdateBeginTime");
	DataAboutUpdate.Insert("UpdateEndTime");
	DataAboutUpdate.Insert("DurationOfUpdate");
	DataAboutUpdate.Insert("BeginTimeOfPendingUpdate");
	DataAboutUpdate.Insert("EndTimeDeferredUpdate");
	DataAboutUpdate.Insert("SessionNumber", New ValueList());
	DataAboutUpdate.Insert("UpdateHandlerParameters");
	DataAboutUpdate.Insert("DeferredUpdateIsCompletedSuccessfully");
	DataAboutUpdate.Insert("HandlerTree", New ValueTree());
	DataAboutUpdate.Insert("PutSystemChangesDescription", False);
	DataAboutUpdate.Insert("LegalVersion", "");
	DataAboutUpdate.Insert("NewSubsystems", New Array);
	
	If TypeOf(OldInformation) = Type("Structure") Then
		FillPropertyValues(DataAboutUpdate, OldInformation);
	EndIf;
	
	Return DataAboutUpdate;
	
EndFunction

// Only for internal use.
//
Function NewInfoAboutUpdateHandlers()
	
	HandlerTree = New ValueTree;
	HandlerTree.Columns.Add("LibraryName");
	HandlerTree.Columns.Add("VersionNumber");
	HandlerTree.Columns.Add("VersionRegistration");
	HandlerTree.Columns.Add("HandlerName");
	HandlerTree.Columns.Add("Status");
	HandlerTree.Columns.Add("NumberAttempts");
	HandlerTree.Columns.Add("ErrorInfo");
	HandlerTree.Columns.Add("Comment");
	
	Return HandlerTree;
	
EndFunction

// Checks the status of  pending update handlers.
//
Function FailedHandlersStatus()
	
	DataAboutUpdate = DataOnUpdatingInformationBase();
	For Each TreeRowLibrary IN DataAboutUpdate.HandlerTree.Rows Do
		For Each TreeRowVersion IN TreeRowLibrary.Rows Do
			For Each Handler IN TreeRowVersion.Rows Do
				If Handler.Status = "Error" Then
					Return "StatusError";
				ElsIf Handler.Status <> "Completed" Then
					Return "StateNotCompleted";
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	Return "";
	
EndFunction

#EndRegion
