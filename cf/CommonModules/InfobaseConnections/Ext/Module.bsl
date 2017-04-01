////////////////////////////////////////////////////////////////////////////////
// Subsystem "Logging off users".
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

////////////////////////////////////////////////////////////////////////////////
// Lock and end of connections with IB.

// Sets IB connection lock.
// If it is called from session with
// established divider values that it sets the data area session lock.
//
// Parameters:
//  MessageText  - String - text which will be a error
//                             message part when trying to set
//                             connection with locked infobase.
// 
//  KeyCode - String -   string which should be added
//                             to the command string parameter "/uc" connection
//                             string parameter "uc" to set connection
//                             with infobase despite of lock.
//                             It isn't applicable for data area session lock.
//
// Returns:
//   Boolean   - True if lock is set successfully.
//              False if the rights are not sufficient for locking.
//
Function SetConnectionLock(Val MessageText = "",
	Val KeyCode = "KeyCode") Export
	
	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		
		If Not Users.InfobaseUserWithFullAccess() Then
			Return False;
		EndIf;
		
		Block = NewLockConnectionParameters();
		Block.Use = True;
		Block.Begin = CurrentSessionDate();
		Block.Message = GenerateLockMessage(MessageText, KeyCode);
		Block.Exclusive = Users.InfobaseUserWithFullAccess(, True);
		SetDataAreaSessionLock(Block);
		Return True;
	Else
		If Not Users.InfobaseUserWithFullAccess(, True) Then
			Return False;
		EndIf;
		
		Block = New SessionsLock;
		Block.Use = True;
		Block.Begin = CurrentSessionDate();
		Block.KeyCode = KeyCode;
		Block.Message = GenerateLockMessage(MessageText, KeyCode);
		SetSessionsLock(Block);
		Return True;
	EndIf;
	
EndFunction

// Determine whether the connections lock on infobase configuration pack update is set.
//
// Parameters:
// LockParameters - Structure - sessions lock parameters.See descriptions
//                                   in SessionsLockParametersStructure().
//
// Returns:
// Boolean - True if it is set, false - Else.
//
Function ConnectionsBlockIsSet(LockParameters = Undefined) Export
	
	If LockParameters = Undefined Then
		LockParameters = SessionLocksParametersStructure();
	EndIf;
	
	Return LockParameters.ConnectionsBlockIsSet;
		
EndFunction

// Get IB connection lock parameters for use on the client side.
//
// Parameters:
// GetSessionCount - Boolean - if True that the
//                                       returned structure filed NumberOfSessions is filled.
// LockParameters - Structure - sessions lock parameters.See descriptions
//                                   in SessionsLockParametersStructure().
//
// Returns:
//   Structure - with properties:
//     * Set       - Boolean - True if lock is set, False - Else. 
//     * Begin            - Date   - lock start data. 
//     * End             - Date   - lock end date. 
//     * Message         - String - message to user. 
//     * UsersWorkEndTimeoutTimeout - Number - interval in seconds.
//     * SessionsQuantity - Number  - 0 if the parameter GetSessionCount = False.
//     * CurrentSessionDate - Date   - current session date.
//
Function SessionLockParameters(Val GetSessionCount = False, LockParameters = Undefined) Export
	
	If LockParameters = Undefined Then
		LockParameters = SessionLocksParametersStructure();
	EndIf;
	
	If LockParameters.InstalledLockingConnectionsAndUsedToDate Then
		CurrentMode = LockParameters.CurrentInfobaseMode;
	ElsIf LockParameters.InstalledLockingConnectionsDataAreasToDate Then
		CurrentMode = LockParameters.CurrentDataAreaMode;
	ElsIf LockParameters.CurrentInfobaseMode.Use Then
		CurrentMode = LockParameters.CurrentInfobaseMode;
	Else
		CurrentMode = LockParameters.CurrentDataAreaMode;
	EndIf;
	
	SetPrivilegedMode(True);
	Return New Structure(
		"Use,Begin,End,Message,SessionTerminationTimeout,NumberOfSessions,CurrentSessionDate",
		CurrentMode.Use,
		CurrentMode.Begin,
		CurrentMode.End,
		CurrentMode.Message,
		15 * 60, // M5 minutes; timeout of users end before
		         // setting infobase lock (in seconds).
		?(GetSessionCount, InfobaseSessionCount(), 0),
		LockParameters.CurrentDate);

EndFunction

// Remove infobase lock.
//
// Returns:
//   Boolean   - True if the operation is completed successfully.
//              False if there are not enough rights to perform operation.
//
Function AllowUsersWork() Export
	
	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		
		If Not Users.InfobaseUserWithFullAccess() Then
			Return False;
		EndIf;
		
		CurrentMode = GetDataAreaSessionLock();
		If CurrentMode.Use Then
			NewMode = NewLockConnectionParameters();
			NewMode.Use = False;
			SetDataAreaSessionLock(NewMode);
		EndIf;
		Return True;
		
	Else
		If Not Users.InfobaseUserWithFullAccess(, True) Then
			Return False;
		EndIf;
		
		CurrentMode = GetSessionsLock();
		If CurrentMode.Use Then
			NewMode = New SessionsLock;
			NewMode.Use = False;
			SetSessionsLock(NewMode);
		EndIf;
		Return True;
	EndIf;
	
EndFunction	

////////////////////////////////////////////////////////////////////////////////
// Data area sessions lock.

// Receive empty structure with parameters of data areas sessions lock.
// 
// Returns:
//   Structure        - with fields:
//     Begin         - Date   - lock action start time.
//     End          - Date   - lock action timeout.
//     Message      - String - message for users that log in the locked data area.
//     Use    - Boolean - shows that lock is set.
//     Exclusive   - Boolean - lock can not be changed by application administrator.
//
Function NewLockConnectionParameters() Export
	
	Return New Structure("End,Begin,Message,Use,Exclusive",
		Date(1,1,1), Date(1,1,1), "", False, False);
		
EndFunction

// Set data area session lock.
// 
// Parameters:
//   Parameters         - Structure - see NewConnectionLockParameters.
//   LocalTime - Boolean - start and end lock time are specified in local session time.
//                                If False then in the universal time.
//   DataArea - Number(7,0) - data area number for which lock is set.
//     On call from session where separators values are specified, only the value
//       that matches separator value in the session (or omitted) can be passed.
//     On call from session where separators values are not specified, parameter value can not be omitted.
//
Procedure SetDataAreaSessionLock(Parameters, Val LocalTime = True, Val DataArea = -1) Export
	
	If Not Users.InfobaseUserWithFullAccess() Then
		Raise NStr("en='Insufficient rights to perform operation';ru='Недостаточно прав для выполнения операции'");
	EndIf;
	
	Exclusive = False;
	If Not Parameters.Property("Exclusive", Exclusive) Then
		Exclusive = False;
	EndIf;
	If Exclusive AND Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise NStr("en='Insufficient rights to perform operation';ru='Недостаточно прав для выполнения операции'");
	EndIf;
	
	If CommonUseReUse.CanUseSeparatedData() Then
		
		If DataArea = -1 Then
			DataArea = CommonUse.SessionSeparatorValue();
		ElsIf DataArea <> CommonUse.SessionSeparatorValue() Then
			Raise NStr("en='Out of the session with the used separators values is impossible to lock the data areas sessions different from the used in a session!';ru='Из сеанса с используемыми значениями разделителей нельзя установить блокировку сеансов области данных, отличной от используемой в сеансе!'");
		EndIf;
		
	Else
		
		If DataArea = -1 Then
			Raise NStr("en='Cannot lock the data areas sessions - a data area is not specified.';ru='Невозможно установить блокировку сеансов области данных - не указана область данных!'");
		EndIf;
		
	EndIf;
	
	SettingsStructure = Parameters;
	If TypeOf(Parameters) = Type("SessionsLock") Then
		SettingsStructure = NewLockConnectionParameters();
		FillPropertyValues(SettingsStructure, Parameters);
	EndIf;

	SetPrivilegedMode(True);
	LockSet = InformationRegisters.DataAreasSessionsLocks.CreateRecordSet();
	LockSet.Filter.DataAreaAuxiliaryData.Set(DataArea);
	LockSet.Read();
	LockSet.Clear();
	If Parameters.Use Then 
		Block = LockSet.Add();
		Block.DataAreaAuxiliaryData = DataArea;
		Block.LockPeriodStart = ?(LocalTime AND ValueIsFilled(SettingsStructure.Begin), 
			ToUniversalTime(SettingsStructure.Begin), SettingsStructure.Begin);
		Block.LockEndOfPeriod = ?(LocalTime AND ValueIsFilled(SettingsStructure.End), 
			ToUniversalTime(SettingsStructure.End), SettingsStructure.End);
		Block.LockMessage = SettingsStructure.Message;
		Block.Exclusive = SettingsStructure.Exclusive;
	EndIf;
	LockSet.Write();
	
EndProcedure

// Get data area session lock information.
// 
// Parameters:
//   LocalTime - Boolean - start and end lock time it
// is necessary to return in local session time. If False that
// it is returned in universal time.
//
// Returns:
//   Structure - see NewConnectionLockParameters.
//
Function GetDataAreaSessionLock(Val LocalTime = True) Export
	
	Result = NewLockConnectionParameters();
	If Not CommonUseReUse.DataSeparationEnabled() Or Not CommonUseReUse.CanUseSeparatedData() Then
		Return Result;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess() Then
		Raise NStr("en='Insufficient rights to perform operation';ru='Недостаточно прав для выполнения операции'");
	EndIf;
	
	SetPrivilegedMode(True);
	LockSet = InformationRegisters.DataAreasSessionsLocks.CreateRecordSet();
	LockSet.Filter.DataAreaAuxiliaryData.Set(CommonUse.SessionSeparatorValue());
	LockSet.Read();
	If LockSet.Count() = 0 Then
		Return Result;
	EndIf;
	Block = LockSet[0];
	Result.Begin = ?(LocalTime AND ValueIsFilled(Block.LockPeriodStart), 
		ToLocalTime(Block.LockPeriodStart), Block.LockPeriodStart);
	Result.End = ?(LocalTime AND ValueIsFilled(Block.LockEndOfPeriod), 
		ToLocalTime(Block.LockEndOfPeriod), Block.LockEndOfPeriod);
	Result.Message = Block.LockMessage;
	Result.Exclusive = Block.Exclusive;
	CurrentDate = CurrentSessionDate();
	Result.Use = True;
	// Refine the results by the lock period.
	Result.Use = Not ValueIsFilled(Block.LockEndOfPeriod) 
		Or Block.LockEndOfPeriod >= CurrentDate 
		Or ConnectionsLockedForDate(Result, CurrentDate);
	Return Result;
	
EndFunction

#EndRegion

#Region ServiceApplicationInterface

// Fills the structure of the parameters required
// for the client configuration code. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure AddClientWorkParameters(Parameters) Export
	Parameters.Insert("SessionLockParameters", New FixedStructure(SessionLockParameters()));
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Declaring service events to which handlers can be attached.

// Declares events of the UserSessions subsystem:
//
// Client events:
//   OnCompleteSession.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// CLIENT EVENTS.
	
	// Called during completing the session using the UserSessions subsystem.
	// 
	// Parameters:
	//  OwnerForm - ManagedForm from which
	//  the session end is executed, SessionNumber - Digit (8,0,+) - number of the session
	//  that will be ended, StandardProcessor - Boolean, shows that a standard
	//    processor of the session end is processed (connection to the
	//    server agent via COM-connection or administer server with the query of connection parameters to the cluster of the current user). May
	//    be set to the False value inside the event processor, in
	//    this case the standard processor of
	//  the session end will not be executed, AlertAfterSessionEnd - NotifyDescription - description of
	//    the alert that should be called after the session is
	//    over (for an auto update of the active users list). If you set the value of
	//    the StandardProcessor parameter as False, after the session is complete
	//    successfully, a processor for the passed description of an
	//    alert should be executed using the ExecuteAlertProcessor method
	//    (you should pass DialogReturnCode.OK  as a value of the Result parameter if the session is completed successfully). Parameter can be omitted - in this case do not process
	//    the alert.
	//
	// Syntax:
	// Procedure OnSessionEnd(FormOwner Val SessionNumber, StandardDataProcessor, Val  AlertAfterSessionEnd = Undefined) Export
	//
	ClientEvents.Add("StandardSubsystems.UserSessions\OnSessionEnd");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Add events handlers.

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\AfterSystemOperationStart"].Add(
			"InfobaseConnectionsClient");
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\OnProcessingParametersLaunch"].Add(
			"InfobaseConnectionsClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsRunning"].Add(
		"InfobaseConnections");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
		"InfobaseConnections");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ServerHandlers["StandardSubsystems.SaaS\WhenCompletingTablesOfParametersOfIB"].Add(
			"InfobaseConnections");
	EndIf;
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"InfobaseConnections");
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers[
			"ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport"].Add(
				"InfobaseConnections");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ServerHandlers["StandardSubsystems.CurrentWorks\AtFillingToDoList"].Add(
			"InfobaseConnections");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Generates a list of IB parameters.
//
// Parameters:
// ParameterTable - ValueTable - parameters description table.
// Description columns content - see SaaSOperations.GetInfobaseParameterTable().
//
Procedure WhenCompletingTablesOfParametersOfIB(Val ParameterTable) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
		ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "LockMessageOnConfigurationUpdate");
	EndIf;
	
EndProcedure

// Fill in structure of parameters required for
// work of this subsystem client code on configuration start, i.e. in events handlers.
// - BeforeSystemWorkStart,
// - OnStart
//
// Parameters:
//   Parameters - Structure - structure of the start parameters.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystemsRunning(Parameters) Export
	
	LockParameters = SessionLocksParametersStructure();
	Parameters.Insert("SessionLockParameters", New FixedStructure(SessionLockParameters(, LockParameters)));
	
	If Not LockParameters.ConnectionsBlockIsSet
		Or Not CommonUseReUse.DataSeparationEnabled()
		Or Not CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	// Further code is relevant only for data area with the set lock.
	If InfobaseUpdate.InfobaseUpdateInProgress() 
		AND Users.InfobaseUserWithFullAccess() Then
		// Application administrator can log in despite incomplete area update (and data area lock).
		// It initiates the area update.
		Return; 
	EndIf;	
	
	CurrentMode = LockParameters.CurrentDataAreaMode;
	
	If ValueIsFilled(CurrentMode.End) Then
		LockPeriod = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='for period from %1 to %2';ru='на период с %1 по %2'"),
			CurrentMode.Begin, CurrentMode.End);
	Else
		LockPeriod = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='from %1';ru='с %1'"), CurrentMode.Begin);
	EndIf;
	If ValueIsFilled(CurrentMode.Message) Then
		LockReason = NStr("en='by reason of:';ru='по причине:'") + Chars.LF + CurrentMode.Message;
	Else
		LockReason = NStr("en='to post the scheduled works';ru='для проведения регламентных работ'");
	EndIf;
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Application administator set %1 %2 users work lock.
		|
		|Application is temporarily unavailable.';ru='Администратором приложения установлена блокировка работы пользователей %1 %2.
		|
		|Приложение временно недоступно.'"),
		LockPeriod, LockReason);
	Parameters.Insert("DataAreaSessionsLocked", MessageText);
	MessageText = "";
	If Users.InfobaseUserWithFullAccess() Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Application administator set %1 %2 users work lock.
		|
		|Do you want to enter to the locked application?';ru='Администратором приложения установлена блокировка работы пользователей %1 %2.
		|
		|Войти в заблокированное приложение?'"),
			LockPeriod, LockReason);
	EndIf;
	Parameters.Insert("OfferLogOn", MessageText);
	If (Users.InfobaseUserWithFullAccess() AND Not CurrentMode.Exclusive) 
		Or Users.InfobaseUserWithFullAccess(, True) Then
		
		Parameters.Insert("CanRemoveLock", True);
	Else
		Parameters.Insert("CanRemoveLock", False);
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

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.9";
	Handler.Procedure = "InfobaseConnections.TransferDataAreaSessionLocksToAuxiliaryData";
	Handler.SharedData = True;
	
EndProcedure

// Fills the array of types excluded from the import and export of data.
//
// Parameters:
//  Types - Array(Types).
//
Procedure WhenFillingTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.InformationRegisters.DataAreasSessionsLocks);
	
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
	
	ModuleCurrentWorksService = CommonUse.CommonModule("CurrentWorksService");
	If Not AccessRight("DataAdministration", Metadata)
		Or ModuleCurrentWorksService.WorkDisabled("SessionsLock") Then
		Return;
	EndIf;
	ModuleCurrentWorksServer = CommonUse.CommonModule("CurrentWorksServer");
	
	// The procedure is called only if there is the
	// To-do lists subsystem, that is why here is no checking of subsystem existence.
	Sections = ModuleCurrentWorksServer.SectionsForObject(Metadata.DataProcessors.UserWorkBlocking.FullName());
	
	If Sections = Undefined Then
		Return; 
	EndIf;
	
	LockParameters = SessionLockParameters(False);
	CurrentSessionDate = CurrentSessionDate();
	
	If LockParameters.Use Then
		If CurrentSessionDate < LockParameters.Begin Then
			If LockParameters.End <> Date(1, 1, 1) Then
				Message = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Planned from %1 to %2';ru='Запланирована с %1 по %2'"), 
					Format(LockParameters.Begin, "DLF=DT"), Format(LockParameters.End, "DLF=DT"));
			Else
				Message = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Planned from %1';ru='Запланирована с %1'"), 
					Format(LockParameters.Begin, "DLF=DT"));
			EndIf;
			Importance = False;
		ElsIf LockParameters.End <> Date(1, 1, 1) AND CurrentSessionDate > LockParameters.End AND LockParameters.Begin <> Date(1, 1, 1) Then
			Importance = False;
			Message = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Invalid (expired %1)';ru='Не действует (истек срок %1)'"), 
				Format(LockParameters.End, "DLF=DT"));
		Else
			If LockParameters.End <> Date(1, 1, 1) Then
				Message = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='from %1 to %2';ru='с %1 по %2'"), 
					Format(LockParameters.Begin, "DLF=DT"), Format(LockParameters.End, "DLF=DT"));
			Else
				Message = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='from %1';ru='с %1'"), 
					Format(LockParameters.Begin, "DLF=DT"));
			EndIf;
			Importance = True;
		EndIf;
	Else
		Message = NStr("en='Invalid';ru='Ошибочный'");
		Importance = False;
	EndIf;

	
	For Each Section IN Sections Do
		
		WorkIdentifier = "SessionsLock" + StrReplace(Section.FullName(), ".", "");
		
		Work = CurrentWorks.Add();
		Work.ID  = WorkIdentifier;
		Work.ThereIsWork       = LockParameters.Use;
		Work.Presentation  = NStr("en='User work locking';ru='Блокировка работы пользователей'");
		Work.Form          = "DataProcessor.UserWorkBlocking.Form";
		Work.Important         = Importance;
		Work.Owner       = Section;
		
		Work = CurrentWorks.Add();
		Work.ID  = "SessionsLockDetails";
		Work.ThereIsWork       = LockParameters.Use;
		Work.Presentation  = Message;
		Work.Owner       = WorkIdentifier; 
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE HANDLERS

// Transfers data from the DelteDataAreasSessionLocks information
//  register to the DataAreasSessionLocks information register.
Procedure MoveDataAreasSessionsLocksInAuxiliaryData() Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		Block = New DataLock();
		RegisterBlock = Block.Add("InformationRegister.DataAreasSessionsLocks");
		RegisterBlock.Mode = DataLockMode.Exclusive;
		Block.Lock();
		
		QueryText =
		"SELECT
		|	ISNULL(DataAreasSessionsLocks.DataAreaAuxiliaryData, DeleteDataAreasSessionsBlockings.DataArea) AS DataAreaAuxiliaryData,
		|	ISNULL(DataAreasSessionsLocks.LockPeriodStart, DeleteDataAreasSessionsBlockings.LockPeriodStart) AS LockPeriodStart,
		|	ISNULL(DataAreasSessionsLocks.LockEndOfPeriod, DeleteDataAreasSessionsBlockings.LockEndOfPeriod) AS LockEndOfPeriod,
		|	ISNULL(DataAreasSessionsLocks.LockMessage, DeleteDataAreasSessionsBlockings.LockMessage) AS LockMessage,
		|	ISNULL(DataAreasSessionsLocks.Exclusive, DeleteDataAreasSessionsBlockings.Exclusive) AS Exclusive
		|FROM
		|	InformationRegister.DeleteDataAreasSessionsBlockings AS DeleteDataAreasSessionsBlockings
		|		LEFT JOIN InformationRegister.DataAreasSessionsLocks AS DataAreasSessionsLocks
		|		ON DeleteDataAreasSessionsBlockings.DataArea = DataAreasSessionsLocks.DataAreaAuxiliaryData";
		Query = New Query(QueryText);
		
		Set = InformationRegisters.DataAreasSessionsLocks.CreateRecordSet();
		Set.Load(Query.Execute().Unload());
		InfobaseUpdate.WriteData(Set);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other.

// Returns sessions lock message text.
//
// Parameters:
// Message - String - message for lock.
//  KeyCode - String - login permission code to the infobase.
//
// Returns:
//   String - lock message.
//
Function GenerateLockMessage(Val Message, Val KeyCode) Export
	
	AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
	FileModeFlag = False;
	PathToInfobase = InfobaseConnectionsClientServer.InformationBasePath(FileModeFlag, AdministrationParameters.ClusterPort);
	InfobasePathString = ?(FileModeFlag = True, "/F", "/S") + PathToInfobase;
	MessageText = "";
	If Not IsBlankString(Message) Then
		MessageText = Message + Chars.LF + Chars.LF;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		MessageText = MessageText +
		    NStr("en='%1
		|To allow uses work you can open application with the AllowUsersWork parameter. For
		|example: http://<server web address>/?C=AllowUsersWork';ru='%1
		|Для разрешения работы пользователей можно открыть приложение с параметром РазрешитьРаботуПользователей. Например:
		|http://<веб-адрес сервера>/?C=РазрешитьРаботуПользователей'");
	Else
		MessageText = MessageText +
		    NStr("en='%1
		|To allow users work, use servers cluster console or start ""1C:Enterprise"" with parameters:
		|ENTERPRISE %2 /AllowUsersWork /UC%3';ru='%1
		|Для того чтобы разрешить работу пользователей, воспользуйтесь консолью кластера серверов или запустите
		|""1С:Предприятие"" с параметрами: ENTERPRISE %2 /CРазрешитьРаботуПользователей /UC%3'");
	EndIf;
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText,
		InfobaseConnectionsClientServer.TextForAdministrator(), InfobasePathString, 
		NStr("en='<permission code>';ru='<код разрешения>'"));
	
	Return MessageText;
	
EndFunction

// Returns a text string with a list of active IB connections.
// Connections names are separated by line break character.
//
// Parameters:
// Message - String - passed string.
//
// Returns:
//   String - connections names.
//
Function EnabledSessionsMessage() Export
	
	Message = NStr("en='Unable to disable sessions:';ru='Не удалось отключить сеансы:'");
	CurrentSessionNumber = InfobaseSessionNumber();
	For Each Session IN GetInfobaseSessions() Do
		If Session.SessionNumber <> CurrentSessionNumber Then
			Message = Message + Chars.LF + "• " + Session;
		EndIf;
	EndDo;
	
	Return Message;
	
EndFunction

// Receive IB active sessions quantity.
//
// Parameters:
//   IncludingConsole - Boolean - if False, then exclude servers cluster sessions.
//                               Servers cluster console sessions do not
// interfere with execution of administrative operations (setting of the exclusive mode etc.).
//
// Returns:
//   Number - quantity of IB active sessions.
//
Function InfobaseSessionCount(IncludingConsole = True, ConsiderBackgroundJobs = True) Export
	
	InfobaseSessions = GetInfobaseSessions();
	If IncludingConsole AND ConsiderBackgroundJobs Then
		Return InfobaseSessions.Count();
	EndIf;
	
	Result = 0;
	
	For Each InfobaseSession IN InfobaseSessions Do
		
		If Not IncludingConsole AND InfobaseSession.ApplicationName = "SrvrConsole"
			Or Not ConsiderBackgroundJobs AND InfobaseSession.ApplicationName = "BackgroundJob" Then
			Continue;
		EndIf;
		
		Result = Result + 1;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Returns whether connection lock is set to the current date.
//
// Parameters:
// CurrentMode - SessionsLock - sessions lock.
// CurrentDate - Date - date on which it should be checked.
//
// Returns:
// Boolean - True if set.
//
Function ConnectionsLockedForDate(CurrentMode, CurrentDate)
	
	Return (CurrentMode.Use AND CurrentMode.Begin <= CurrentDate 
		AND (NOT ValueIsFilled(CurrentMode.End) Or CurrentDate <= CurrentMode.End));
		
EndFunction

Function SessionLocksParametersStructure()
	
	SetPrivilegedMode(True);
	
	CurrentDate = CurrentSessionDate();
	CurrentInfobaseMode = GetSessionsLock();
	CurrentDataAreaMode = GetDataAreaSessionLock();
	InstalledLockingConnectionsAndUsedToDate = ConnectionsLockedForDate(CurrentInfobaseMode, CurrentDate);
	InstalledLockingConnectionsDataAreasToDate = ConnectionsLockedForDate(CurrentDataAreaMode, CurrentDate);
	
	SessionLockParameters = New Structure;
	SessionLockParameters.Insert("CurrentDate", CurrentDate);
	SessionLockParameters.Insert("CurrentInfobaseMode", CurrentInfobaseMode);
	SessionLockParameters.Insert("CurrentDataAreaMode", CurrentDataAreaMode);
	SessionLockParameters.Insert("InstalledLockingConnectionsAndUsedToDate", ConnectionsLockedForDate(CurrentInfobaseMode, CurrentDate));
	SessionLockParameters.Insert("InstalledLockingConnectionsDataAreasToDate", ConnectionsLockedForDate(CurrentDataAreaMode, CurrentDate));
	SessionLockParameters.Insert("ConnectionsBlockIsSet", InstalledLockingConnectionsAndUsedToDate Or InstalledLockingConnectionsDataAreasToDate);
	
	Return SessionLockParameters;
	
EndFunction

// Returns information about the current connections to the infobase.
// Writes message to the events log monitor if needed.
//
Function ConnectionInformation(ReceiveConnectionString = False,
	MessagesForEventLogMonitor = Undefined, ClusterPort = 0) Export
	
	SetPrivilegedMode(True);
	
	Result = New Structure();
	Result.Insert("ActiveConnectionsExist", False);
	Result.Insert("COMConnectionsExist", False);
	Result.Insert("DesignerConnectionExists", False);
	Result.Insert("AreActiveUsers", False);
	
	If InfobaseUsers.GetUsers().Count() > 0 Then
		Result.AreActiveUsers = True;
	EndIf;
	
	If ReceiveConnectionString Then
		Result.Insert("InfobaseConnectionString",
			InfobaseConnectionsClientServer.GetInformationBaseConnectionString());
	EndIf;
		
	EventLogMonitor.WriteEventsToEventLogMonitor(MessagesForEventLogMonitor);
	
	SessionsArray = GetInfobaseSessions();
	If SessionsArray.Count() = 1 Then
		Return Result;
	EndIf;
	
	Result.ActiveConnectionsExist = True;
	
	For Each Session IN SessionsArray Do
		If Upper(Session.ApplicationName) = Upper("COMConnection") Then // COM connection
			Result.COMConnectionsExist = True;
		ElsIf Upper(Session.ApplicationName) = Upper("Designer") Then // Configurator
			Result.DesignerConnectionExists = True;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Determines the number of infobase sessions and
// the availability of sessions that can not be disabled forcibly. Generates
// error message text.
//
Function InformationAboutLockingSessions(MessageText = "") Export
	
	InformationAboutLockingSessions = New Structure;
	
	CurrentSessionNumber = InfobaseSessionNumber();
	InfobaseSessions = GetInfobaseSessions();
	
	LockSessionsPresent = False;
	If CommonUse.FileInfobase() Then
		ActiveSessionNames = "";
		For Each Session IN InfobaseSessions Do
			If Session.SessionNumber <> CurrentSessionNumber
				AND Session.ApplicationName <> "1CV8"
				AND Session.ApplicationName <> "1CV8C"
				AND Session.ApplicationName <> "WebClient" Then
				ActiveSessionNames = ActiveSessionNames + Chars.LF + "• " + Session;
				LockSessionsPresent = True;
			EndIf;
		EndDo;
	EndIf;
	
	InformationAboutLockingSessions.Insert("LockSessionsPresent", LockSessionsPresent);
	InformationAboutLockingSessions.Insert("NumberOfSessions", InfobaseSessions.Count());
	
	If LockSessionsPresent Then
		Message = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='There are active sessions
		|of work with application that can not
		|be
		|completed forcibly: %1 %2';ru='Имеются активные
		|сеансы работы с программой, которые не
		|могут
		|быть завершены принудительно: %1 %2'"),
			ActiveSessionNames, MessageText);
		InformationAboutLockingSessions.Insert("MessageText", Message);
		
	EndIf;
	
	Return InformationAboutLockingSessions;
	
EndFunction

#EndRegion
