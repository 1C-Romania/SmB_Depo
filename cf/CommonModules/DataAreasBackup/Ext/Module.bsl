////////////////////////////////////////////////////////////////////////////////
// DataAreasBackup.
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Message exchange

// Returns the state of using data areas backup.
//
// Return value: Boolean.
//
Function BackupInUse() Export
	
	SetPrivilegedMode(True);
	Return Constants.BackupSupport.Get();
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\WhenVerifyingBackupPossibilityInUserMode"].Add(
			"DataAreasBackupClient");
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\WhenUserIsOfferedToBackup"].Add(
			"DataAreasBackupClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
		"DataAreasBackup");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\WhenYouDefineAliasesHandlers"].Add(
				"DataAreasBackup");
	EndIf;
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
			"DataAreasBackup");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnDefenitionSupportedVersionsOfSoftwareInterfaces"].Add(
			"DataAreasBackup");
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers[
			"ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport"].Add(
				"DataAreasBackup");
	EndIf;
	
	ServerHandlers[
		"StandardSubsystems.SaaS\WhenCompletingTablesOfParametersOfIB"].Add(
			"DataAreasBackup");
			
	ServerHandlers[
		"StandardSubsystems.SaaS.JobQueue\WhenDefiningHandlersErrors"].Add(
			"DataAreasBackup");
	
	ServerHandlers[
		"StandardSubsystems.SaaS.MessageExchange\RegistrationOfReceivedMessageInterfaces"].Add(
			"DataAreasBackup");
	
	ServerHandlers[
		"StandardSubsystems.SaaS.MessageExchange\RegistrationSendingMessageInterfaces"].Add(
			"DataAreasBackup");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of SSL subsystems internal events.

// Fills the structure of the parameters required
// for the client configuration code.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystems(Parameters) Export
	
	Parameters.Insert("DataAreasBackup", GetFunctionalOption("BackupSupport"));
	
EndProcedure

// Fills in the match of methods names and their aliases for call from the jobs queue.
//
// Parameters:
//  AccordanceNamespaceAliases - Correspondence
//   Key - Method alias, for example, ClearDataArea.
//   Value - Method name for call, for example, SaaSOperations.ClearDataArea.
//    You can specify Undefined as a value, in this case, it is
// considered that name matches the alias.
//
Procedure WhenYouDefineAliasesHandlers(AccordanceNamespaceAliases) Export
	
	AccordanceNamespaceAliases.Insert("DataAreasBackup.ExportAreaToMSStorage");
	AccordanceNamespaceAliases.Insert("DataAreasBackup.CopiesCreation");
	
EndProcedure

// Fills the structure with the arrays of supported
// versions of all subsystems subject to versioning and uses subsystems names as keys.
// Provides the functionality of InterfaceVersion Web-service.
// during the implementation the body of the procedure shall be changed so it will return relevant version sets (see ex.below).
//
// Parameters:
// SupportedVersionStructure - Structure: 
// - Keys = Names of the subsystems. 
// - Values = Arrays of supported version names.
//
// Example of implementation:
//
// // FileTransferServer
// VersionsArray = New Array;
// VersionsArray.Add("1.0.1.1");	
// VersionsArray.Add("1.0.2.1"); 
// SupportedVersionsStructure.Insert("FileTransferServer", VersionsArray);
// // End FileTransferService
//
Procedure OnDefenitionSupportedVersionsOfSoftwareInterfaces(Val SupportedVersionStructure) Export
	
	VersionArray = New Array;
	VersionArray.Add("1.0.1.1");
	VersionArray.Add("1.0.1.2");
	SupportedVersionStructure.Insert("DataAreasBackup", VersionArray);
	
EndProcedure

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.9";
	Handler.Procedure = "DataAreasBackup.TransferBackupPlanningStateToAuxiliaryData";
	Handler.SharedData = True;
	
EndProcedure

// Fills the array of types excluded from the import and export of data.
//
// Parameters:
//  Types - Array(Types).
//
Procedure WhenFillingTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.Constants.ExecuteBackupDataArea);
	Types.Add(Metadata.Constants.LastClientSessionStartDate);
	
EndProcedure

// Generates a list of IB parameters.
//
// Parameters:
// ParameterTable - ValueTable - parameters description table.
// Description columns content - see SaaSOperations.GetInfobaseParameterTable().
//
Procedure WhenCompletingTablesOfParametersOfIB(ParameterTable) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
		CurParameterString = ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "BackupSupport");
	EndIf;
	
EndProcedure

// Fills in match of errors handlers methods to
// methods aliases when errors in which they are called occur.
//
// Parameters:
//  ErrorHandlers - Correspondence
//   Key - Method alias, for example, ClearDataArea.
//   Value - Method name - errors handler to call if an error occurs. 
//    Errors handler is called when the initial job is executed with an error. Errors handler is called in the same data
//    area that the initial job.
//    Errors handler method is considered to be enabled for a call by the queue mechanisms. 
//    Error handler parameters.:
//     JobParameters - Structure - Job queue parameters.
//      Parameters
//      AttemptNumber
//      RestartQuantityOnFailure
//      LastStartDate.
//     ErrorInfo - ErrorInfo - error description occurred
//      while executing a job.
//
Procedure WhenDefiningHandlersErrors(ErrorHandlers) Export
	
	ErrorHandlers.Insert(
		"DataAreasBackup.CopiesCreation",
		"DataAreasBackup.ErrorCreatingCopies");
	
EndProcedure

// Fills the transferred array with common modules which
//  are the handlers of the received messages interfaces.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure RegistrationOfReceivedMessageInterfaces(ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessagesManageBackupInterface);
	
EndProcedure

// Fills the transferred array with common modules which
//  are the handlers of sent messages interfaces.
//
// Parameters:
//  ArrayOfHandlers - array.
//
//
Procedure RegistrationSendingMessageInterfaces(ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(BackupControlMessageInterface);
	
EndProcedure

// Users activities in data area.

// Sets a flag showing that user is active in the current area.
// Shows that there is a value of the jointly separated constant ClientSessionLastStartDate.
//
Procedure SetUserActivityFlagInZone() Export
	
	If Not CommonUseReUse.IsSeparatedConfiguration()
		OR Not CommonUseReUse.CanUseSeparatedData()
		OR CurrentRunMode() = Undefined
		OR Not GetFunctionalOption("BackupSupport")
		OR SaaSOperations.DataAreaBlocked(CommonUse.SessionSeparatorValue()) Then
		
		Return;
		
	EndIf;
	
	SetActivityFlagInZone(); // For the return compatibility
	
	DateOfLaunch = CurrentUniversalDate();
	
	If DateOfLaunch - Constants.LastClientSessionStartDate.Get() < 3600 Then
		Return;
	EndIf;
	
	Constants.LastClientSessionStartDate.Set(DateOfLaunch);
	
EndProcedure

// Selects or clears a flag showing whether a user is active in the current area.
// Shows that there is a value of the jointly separated constant ExecuteDataAreaBackup.
// Outdated.
//
// Parameters:
// DataArea - Number; Undefined - Separator value. Undefined means the
//                 value of the current data area separator.
// Status - Boolean - True if the flag should be selected; False if it should be cleared.
//
Procedure SetActivityFlagInZone(Val DataArea = Undefined, Val Status = True)
	
	If DataArea = Undefined Then
		If CommonUseReUse.CanUseSeparatedData() Then
			DataArea = CommonUse.SessionSeparatorValue();
		Else
			Raise NStr("en='When calling the SetActivityFlagInZone procedure out of the unseparated session the DataArea parameter is obligatory!';ru='При вызове процедуры УстановитьФлагАктивностиВОбласти из неразделенного сеанса параметр ОбластьДанных является обязательным!'");
		EndIf;
	Else
		If Not CommonUseReUse.SessionWithoutSeparator()
				AND DataArea <> CommonUse.SessionSeparatorValue() Then
			
			Raise(NStr("en='Prohibited to work with the area data except the current';ru='Запрещено работать с данными области кроме текущей'"));
			
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Status Then
		ValueManager = Constants.ExecuteBackupDataArea.CreateValueManager();
		ValueManager.DataAreaAuxiliaryData = DataArea;
		ValueManager.Read();
		If ValueManager.Value Then
			Return;
		EndIf;
	EndIf;
	
	ActivityFlag = Constants.ExecuteBackupDataArea.CreateValueManager();
	ActivityFlag.DataAreaAuxiliaryData = DataArea;
	ActivityFlag.Value = Status;
	CommonUse.AuxilaryDataWrite(ActivityFlag);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Export data areas.

// Creates area backup according to the
// area backup settings.
//
// Parameters:
//  CreationParameters - FixedStructure - backup creation
//   parameters correspond to the backup settings.
//  StateBuilding - FixedStructure - state of
//   the backup creation process in the area.
//
Procedure CopiesCreation(Val CreationParameters, Val StateBuilding) Export
	
	ExecutionStarted = CurrentUniversalDate();
	
	ConditionsCreateCopies = New Array;
	
	Parameters = New Structure;
	Parameters.Insert("Type", "Everyday");
	Parameters.Insert("incorporated", "CreateDaily");
	Parameters.Insert("Periodicity", "Day");
	Parameters.Insert("CreationDate", "CreationDateOfLastDaily");
	Parameters.Insert("Day", Undefined);
	Parameters.Insert("Month", Undefined);
	ConditionsCreateCopies.Add(Parameters);
	
	Parameters = New Structure;
	Parameters.Insert("Type", "Monthly");
	Parameters.Insert("incorporated", "CreateMonthly");
	Parameters.Insert("Periodicity", "Month");
	Parameters.Insert("CreationDate", "CreationDateOfLastMonthly");
	Parameters.Insert("Day", "DayOfMonth");
	Parameters.Insert("Month", Undefined);
	ConditionsCreateCopies.Add(Parameters);
	
	Parameters = New Structure;
	Parameters.Insert("Type", "Annual");
	Parameters.Insert("incorporated", "CreateAnnual");
	Parameters.Insert("Periodicity", "Year");
	Parameters.Insert("CreationDate", "CreationDateOfLastAnnual");
	Parameters.Insert("Day", "DayOfAnnual");
	Parameters.Insert("Month", "MonthOfCreationAnnual");
	ConditionsCreateCopies.Add(Parameters);
	
	RequiredCreating = False;
	CurrentDate = CurrentUniversalDate();
	
	LastSession = Constants.LastClientSessionStartDate.Get();
	
	CreateCourse = Not CreationParameters.OnlyWhenActiveUsers;
	
	PeriodicityFlags = New Structure;
	For Each ParametersFrequency IN ConditionsCreateCopies Do
		
		PeriodicityFlags.Insert(ParametersFrequency.Type, False);
		
		If Not CreationParameters[ParametersFrequency.incorporated] Then
			// Copy creation of this frequency is disabled in the settings.
			Continue;
		EndIf;
		
		CreationDateOfPrevious = StateBuilding[ParametersFrequency.CreationDate];
		
		If Year(CurrentDate) = Year(CreationDateOfPrevious) Then
			If ParametersFrequency.Periodicity = "Year" Then
				// Year is not changed yet
				Continue;
			EndIf;
		EndIf;
		
		If Month(CurrentDate) = Month(CreationDateOfPrevious) Then
			If ParametersFrequency.Periodicity = "Month" Then
				// Month is not changed yet
				Continue;
			EndIf;
		EndIf;
		
		If Day(CurrentDate) = Day(CreationDateOfPrevious) Then
			// Day is not changed yet
			Continue;
		EndIf;
		
		If ParametersFrequency.Day <> Undefined
			AND Day(CurrentDate) < CreationParameters[ParametersFrequency.Day] Then
			
			// It is not the required day yet.
			Continue;
		EndIf;
		
		If ParametersFrequency.Month <> Undefined
			AND Month(CurrentDate) < CreationParameters[ParametersFrequency.Month] Then
			
			// It is not the required month yet.
			Continue;
		EndIf;
		
		If Not CreateCourse
			AND ValueIsFilled(CreationDateOfPrevious)
			AND LastSession < CreationDateOfPrevious Then
			
			// Users did not enter the area after the backup was created.
			Continue;
		EndIf;
		
		RequiredCreating = True;
		PeriodicityFlags.Insert(ParametersFrequency.Type, True);
		
	EndDo;
	
	If Not RequiredCreating Then
		WriteLogEvent(
			EventLogMonitorEvent() + "." 
				+ NStr("en='Skip the creation';ru='Пропуск создания'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Information);
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataAreasExportImport") Then
		
		SaaSOperations.CallExceptionNotAvailableSTLSubsystem("ServiceTechnology.SaaS.DataAreasExportImport");
		
	EndIf;
	
	ModuleDataAreasExportImport = CommonUse.CommonModule("DataAreasExportImport");
	
	ArchiveName = Undefined;	
	ArchiveName = ModuleDataAreasExportImport.ExportCurrentDataAreaToArchive();
	
	CreationDateCopies = CurrentUniversalDate();
	
	ArchiveDescription = New File(ArchiveName);
	FileSize = ArchiveDescription.Size();
	
	FileID = SaaSOperations.PlaceFileIntoServiceManagerStorage(ArchiveDescription);
	
	Try
		DeleteFiles(ArchiveName);
	Except
		// If it is impossible to delete file, execution should not be aborted.
	EndTry;
	
	CopyID = New UUID;
	
	MessageParameters = New Structure;
	MessageParameters.Insert("DataArea", CommonUse.SessionSeparatorValue());
	MessageParameters.Insert("CopyID", CopyID);
	MessageParameters.Insert("FileID", FileID);
	MessageParameters.Insert("CreationDate", CreationDateCopies);
	For Each KeyAndValue IN PeriodicityFlags Do
		MessageParameters.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	SendMessageZoneBackupCreated(MessageParameters);
	
	// State update in parameters.
	JobsFilter = New Structure;
	JobsFilter.Insert("MethodName", "DataAreasBackup.CopiesCreation");
	JobsFilter.Insert("Key", "1");
	Jobs = JobQueue.GetJobs(JobsFilter);
	If Jobs.Count() > 0 Then
		Job = Jobs[0].ID;
		
		MethodParameters = New Array;
		MethodParameters.Add(CreationParameters);
		
		UpdatedState = New Structure;
		For Each ParametersFrequency IN ConditionsCreateCopies Do
			If PeriodicityFlags[ParametersFrequency.Type] Then
				DateStatus = CreationDateCopies;
			Else
				DateStatus = StateBuilding[ParametersFrequency.CreationDate];
			EndIf;
			
			UpdatedState.Insert(ParametersFrequency.CreationDate, DateStatus);
		EndDo;
		
		MethodParameters.Add(New FixedStructure(UpdatedState));
		
		JobParameters = New Structure;
		JobParameters.Insert("Parameters", MethodParameters);
		JobQueue.ChangeTask(Job, JobParameters);
	EndIf;
	
	ParametersEvents = New Structure;
	For Each KeyAndValue IN PeriodicityFlags Do
		ParametersEvents.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	ParametersEvents.Insert("CopyID", CopyID);
	ParametersEvents.Insert("FileID", FileID);
	ParametersEvents.Insert("Size", FileSize);
	ParametersEvents.Insert("Duration", CurrentUniversalDate() - ExecutionStarted);
	
	WriteEventToLog(
		NStr("en='Creating';ru='Создание'", CommonUseClientServer.MainLanguageCode()),
		ParametersEvents);
	
EndProcedure

// If there are no more attempts to create backup,
// writes a message that a backup is not created to events log monitor.
//
// Parameters:
//  JobParameters - Structure - description see event description.
//   StandardSubsystems.SaaS.JobQueue\WhenDefiningHandlersErrors.
//
Procedure ErrorCreatingCopies(Val JobParameters, Val ErrorInfo) Export
	
	If JobParameters.TryNumber < JobParameters.RestartCountOnFailure Then
		CommentTemplate = NStr("en='An error occurred while creating area backup %1.
		|Attempt number:
		|%2
		|Because: %3';ru='При создании резервной копии области %1 произошла ошибка.
		|Номер
		|попытки:
		|%2 По причине: %3'");
		Level = EventLogLevel.Warning;
		Event = NStr("en='Creation iteration error';ru='Ошибка итерации создания'", CommonUseClientServer.MainLanguageCode());
	Else
		CommentTemplate = NStr("en='An unrecoverable error occurred while creating area backup %1.
		|Attempt number:
		|%2
		|Because: %3';ru='При создании резервной копии области %1 произошла невосстановимая ошибка.
		|Номер
		|попытки:
		|%2 По причине: %3'");
		Level = EventLogLevel.Error;
		Event = NStr("en='Creating Error';ru='Ошибка создания'", CommonUseClientServer.MainLanguageCode());
	EndIf;
	
	TextOfComment = StringFunctionsClientServer.PlaceParametersIntoString(
		CommentTemplate,
		Format(CommonUse.SessionSeparatorValue(), "NZ=0; NG="),
		JobParameters.TryNumber,
		DetailErrorDescription(ErrorInfo));
		
	WriteLogEvent(
		EventLogMonitorEvent() + "." + Event,
		Level,
		,
		,
		TextOfComment);
	
EndProcedure

// Plans to create data area backup.
// 
// Parameters:
//  ExportParameters - Structure, for the keys structure, see CreateEmptyExportParameters().
//   
Procedure ScheduleArchivingQueue(Val ExportParameters) Export
	
	If Not Users.InfobaseUserWithFullAccess() Then
		Raise(NStr("en='Insufficient rights to perform operation';ru='Недостаточно прав для выполнения операции'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	MethodParameters = New Array;
	MethodParameters.Add(ExportParameters);
	MethodParameters.Add(Undefined);
	
	JobParameters = New Structure;
	JobParameters.Insert("MethodName", DataAreasBackupReUse.BackgroundBackupMethodName());
	JobParameters.Insert("Key", "" + ExportParameters.CopyID);
	JobParameters.Insert("DataArea", ExportParameters.DataArea);
	
	// Search for active jobs with the same key.
	ActiveTasks1 = JobQueue.GetJobs(JobParameters);
	
	If ActiveTasks1.Count() = 0 Then
		
		// Plan execution of a new one.
		
		JobParameters.Insert("Parameters", MethodParameters);
		JobParameters.Insert("ScheduledStartTime", ExportParameters.StartedAt);
		
		JobQueue.AddJob(JobParameters);
	Else
		If ActiveTasks1[0].JobState <> Enums.JobStates.Planned Then
			// Job is already executed or being executed.
			Return;
		EndIf;
		
		JobParameters.Delete("DataArea");
		
		JobParameters.Insert("Use", True);
		JobParameters.Insert("Parameters", MethodParameters);
		JobParameters.Insert("ScheduledStartTime", ExportParameters.StartedAt);
		
		JobQueue.ChangeTask(ActiveTasks1[0].ID, JobParameters);
	EndIf;
	
EndProcedure

// Creates the specified area export file and puts it to the Service manager storage.
//
// Parameters:
// ExportParameters - Structure:
// 	- DataArea - Number.
// - CopyID - UUID; Undefined.
//  - StartedAt - Date - area archiving start moment.
// - Force - Boolean - Flag from MS: the need to createa backup regardless of the users activity.
// - OnDemand - Boolean - check box of the archiving interactive start. If from MS - always False.
// - FileID - UUID - Export to MS storage file ID.
// - TryNumber - Number - Counter attempts. Initial value: 1.
//
Procedure ExportAreaToMSStorage(Val ExportParameters, StorageAddress = Undefined) Export
	
	If Not Users.InfobaseUserWithFullAccess() Then
		Raise(NStr("en='Access violation';ru='Нарушение прав доступа'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not ExportingRequired(ExportParameters) Then
		SendMessageZoneBackupSkipped(ExportParameters);
		Return;
	EndIf;
	
	If Not CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataAreasExportImport") Then
		
		SaaSOperations.CallExceptionNotAvailableSTLSubsystem("ServiceTechnology.SaaS.DataAreasExportImport");
		
	EndIf;
	
	ModuleDataAreasExportImport = CommonUse.CommonModule("DataAreasExportImport");
	
	ArchiveName = Undefined;
	
	Try
		
		ArchiveName = ModuleDataAreasExportImport.ExportCurrentDataAreaToArchive();
		FileID = SaaSOperations.PlaceFileIntoServiceManagerStorage(New File(ArchiveName));
		Try
			DeleteFiles(ArchiveName);
		Except
			// If it is impossible to delete file, execution should not be aborted.
		EndTry;
		
		BeginTransaction();
		
		Try
			
			ExportParameters.Insert("FileID", FileID);
			ExportParameters.Insert("CreationDate", CurrentUniversalDate());
			SendMessageZoneBackupCreated(ExportParameters);
			If ValueIsFilled(StorageAddress) Then
				PutToTempStorage(FileID, StorageAddress);
			EndIf;
			SetActivityFlagInZone(ExportParameters.DataArea, False);
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			Raise;
			
		EndTry;
		
	Except
		
		WriteLogEvent(NStr("en='Data area backup creation';ru='Создание резервной копии области данных'", CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Try
			If ArchiveName <> Undefined Then
				DeleteFiles(ArchiveName);
			EndIf;
		Except
			// If it is impossible to delete file, execution should not be aborted.
		EndTry;
		If ExportParameters.OnDemand Then
			Raise;
		Else	
			If ExportParameters.TryNumber > 3 Then
				SendMessageZoneBackupError(ExportParameters);
			Else	
				// Replan: current area time + 10 minutes.
				ExportParameters.TryNumber = ExportParameters.TryNumber + 1;
				ReLaunch = ZoneCurrentDate(ExportParameters.DataArea); // Now in field.
				ReLaunch = ReLaunch + 10 * 60; // 10 minutes after.
				ExportParameters.Insert("StartedAt", ReLaunch);
				ScheduleArchivingQueue(ExportParameters);
			EndIf;
		EndIf;
	EndTry;
	
EndProcedure

Function ZoneCurrentDate(Val DataArea)
	
	TimeZone = SaaSOperations.GetDataAreaTimeZone(DataArea);
	Return ToLocalTime(CurrentUniversalDate(), TimeZone);
	
EndFunction

Function ExportingRequired(Val ExportParameters)
	
	If Not CommonUseReUse.SessionWithoutSeparator()
		AND ExportParameters.DataArea <> CommonUse.SessionSeparatorValue() Then
		
		Raise(NStr("en='Prohibited to work with the area data except the current';ru='Запрещено работать с данными области кроме текущей'"));
	EndIf;
	
	Result = ExportParameters.Force;
	
	If Not Result Then
		
		Manager = Constants.ExecuteBackupDataArea.CreateValueManager();
		Manager.DataAreaAuxiliaryData = ExportParameters.DataArea;
		Manager.Read();
		Result = Manager.Value;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Creates an unfilled structure of the required format.
//
// Returns:
// Structure:
// 	- DataArea - Number.
// - CopyID - UUID; Undefined.
//  - StartedAt - Date - area archiving start moment.
// - Force - Boolean - Flag from MS: the need to createa backup regardless of the users activity.
// - OnDemand - Boolean - check box of the archiving interactive start. If from MS - always False.
// - FileID - UUID - Export to MS storage file ID.
// - TryNumber - Number - Counter attempts. Initial value: 1.
//
Function CreateBlankExportingParameters() Export
	
	ExportParameters = New Structure;
	ExportParameters.Insert("DataArea");
	ExportParameters.Insert("CopyID");
	ExportParameters.Insert("StartedAt");
	ExportParameters.Insert("Force");
	ExportParameters.Insert("OnDemand");
	ExportParameters.Insert("FileID");
	ExportParameters.Insert("TryNumber", 1);
	Return ExportParameters;
	
EndFunction

// Cancels backup creation planned earlier.
//
// CancellationParameters - Structure
//  DataArea - Number - data area create backup in which it is required to cancel.
//  CopyID - UUID - copy identifier creation of which should be canceled.
//
Procedure CancelZoneBackupCreating(Val CancellationParameters) Export
	
	If Not Users.InfobaseUserWithFullAccess() Then
		Raise(NStr("en='Insufficient rights to perform operation';ru='Недостаточно прав для выполнения операции'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	MethodName = DataAreasBackupReUse.BackgroundBackupMethodName();
	
	Filter = New Structure("MethodName, Key, DataArea", 
		MethodName, "" + CancellationParameters.CopyID, CancellationParameters.DataArea);
	Jobs = JobQueue.GetJobs(Filter);
	
	For Each Task IN Tasks Do
		JobQueue.DeleteJob(Task.ID);
	EndDo;
	
EndProcedure

// Report about successful archiving of the current area.
//
Procedure SendMessageZoneBackupCreated(Val MessageParameters)
	
	BeginTransaction();
	
	Try
		
		Message = MessagesSaaS.NewMessage(
			BackupControlMessageInterface.MessageAreaBackupCopyIsCreated());
		
		Body = Message.Body;
		
		Body.Zone = MessageParameters.DataArea;
		Body.BackupId = MessageParameters.CopyID;
		Body.FileId = MessageParameters.FileID;
		Body.Date = MessageParameters.CreationDate;
		If MessageParameters.Property("Everyday") Then
			Body.Daily = MessageParameters.Everyday;
			Body.Monthly = MessageParameters.Monthly;
			Body.Yearly = MessageParameters.Annual;
		Else
			Body.Daily = False;
			Body.Monthly = False;
			Body.Yearly = False;
		EndIf;
		Body.ConfigurationVersion = Metadata.Version;
		
		MessagesSaaS.SendMessage(
			Message,
			SaaSReUse.ServiceManagerEndPoint());
			
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Plan area archiving in the applied base.
//
Procedure SendMessageZoneBackupError(Val MessageParameters)
	
	BeginTransaction();
	Try
		
		Message = MessagesSaaS.NewMessage(
			BackupControlMessageInterface.MessageZoneBackupFailed());
		
		Message.Body.Zone = MessageParameters.DataArea;
		Message.Body.BackupId = MessageParameters.CopyID;
		
		MessagesSaaS.SendMessage(
			Message,
			SaaSReUse.ServiceManagerEndPoint());
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Plan area archiving in the applied base.
//
Procedure SendMessageZoneBackupSkipped(Val MessageParameters)
	
	BeginTransaction();
	Try
		
		Message = MessagesSaaS.NewMessage(
			BackupControlMessageInterface.MessageZoneBackupSkipped());
		
		Message.Body.Zone = MessageParameters.DataArea;
		Message.Body.BackupId = MessageParameters.CopyID;
		
		MessagesSaaS.SendMessage(
			Message,
			SaaSReUse.ServiceManagerEndPoint());
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

Function EventLogMonitorEvent()
	
	Return NStr("en='Applications backup';ru='Резервное копирование приложений'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

Procedure WriteEventToLog(Val Event, Val Parameters)
	
	WriteLogEvent(
		EventLogMonitorEvent() + "." + Event,
		EventLogLevel.Information,
		,
		,
		CommonUse.ValueToXMLString(Parameters));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with backup settings.

// Returns settings structure of the data area backup settings.
//
// Parameters:
// DataArea - Number; Undefined - If Undefined, then system settings are returned.
//
// Returns:
// Structure - settings structure. See
// DataAreasBackupReUse.MatchRussianNamesSettingsFieldsToEnglish().
//
Function GetZoneBackupSettings(Val DataArea = Undefined) Export
	
	If Not CommonUseReUse.SessionWithoutSeparator()
		AND DataArea <> CommonUse.SessionSeparatorValue() 
		AND DataArea <> Undefined Then
		
		Raise(NStr("en='Prohibited to work with the area data except the current';ru='Запрещено работать с данными области кроме текущей'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	Proxy = DataAreasBackupReUse.BackupControlProxy();
	
	XDTOSettings = Undefined;
	ErrorInfo = Undefined;
	If DataArea = Undefined Then
		OperationExecuted = Proxy.GetDefaultSettings(XDTOSettings, ErrorInfo);
	Else
		OperationExecuted = Proxy.GetSettings(DataArea, XDTOSettings, ErrorInfo);
	EndIf;
	
	If Not OperationExecuted Then
		MessagePattern = NStr("en='An error occurred while receiving
		|backup: %1.';ru='Ошибка при получении настроек
		|резервного копирования: %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, ErrorInfo);
		Raise(MessageText);
	EndIf;
	
	Return XDTOSettingsToStructure(XDTOSettings);
	
EndFunction	

// Writes data area backup settings to service manager storage.
//
// Parameters:
// DataArea - Number.
// BackupSettings - Structure.
//
// Returns:
// Boolean - success of the record. 
//
Procedure SetZoneBackupSettings(Val DataArea, Val BackupSettings) Export
	
	If Not CommonUseReUse.SessionWithoutSeparator()
		AND DataArea <> CommonUse.SessionSeparatorValue() Then
		
		Raise(NStr("en='Prohibited to work with the area data except the current';ru='Запрещено работать с данными области кроме текущей'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	Proxy = DataAreasBackupReUse.BackupControlProxy();
	
	Type = Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/1.0/XMLSchema/ZoneBackupControl", "Settings");
	XDTOSettings = Proxy.XDTOFactory.Create(Type);
	
	MapOfNames = DataAreasBackupReUse.RussianSettingsFieldsNamesToEnglishMap();
	For Each SettingsNamesPair IN MapOfNames Do
		XDTOSettings[SettingsNamesPair.Key] = BackupSettings[SettingsNamesPair.Value];
	EndDo;
	
	ErrorInfo = Undefined;
	If Not Proxy.SetSettings(DataArea, XDTOSettings, ErrorInfo) Then
		MessagePattern = NStr("en='An error occurred while saving
		|backup settings: %1.';ru='Ошибка при сохранении настроек
		|резервного копирования: %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, ErrorInfo);
		Raise(MessageText);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Types conversions

Function XDTOSettingsToStructure(Val XDTOSettings)
	
	If XDTOSettings = Undefined Then
		Return Undefined;
	EndIf;	
	
	Result = New Structure;
	MapOfNames = DataAreasBackupReUse.RussianSettingsFieldsNamesToEnglishMap();
	For Each SettingsNamesPair IN MapOfNames Do
		If XDTOSettings.IsSet(SettingsNamesPair.Key) Then
			Result.Insert(SettingsNamesPair.Value, XDTOSettings[SettingsNamesPair.Key]);
		EndIf;
	EndDo;
	Return  Result; 
	
EndFunction	

////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE HANDLERS

// Transfers data from the DeleteAreasForBackup
// register to values of the ExecuteBackupDataArea separated constant.
//
Procedure TransferBackupPlanningStateToAuxiliaryData() Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		QueryText = 
		"SELECT
		|	DeleteAreasForBackup.DataArea
		|FROM
		|	InformationRegister.DeleteAreasForBackup AS DeleteAreasForBackup";
		Query = New Query(QueryText);
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			PlanningState = Constants.ExecuteBackupDataArea.CreateValueManager();
			PlanningState.DataAreaAuxiliaryData = Selection.DataArea;
			PlanningState.Value = True;
			PlanningState.Write();
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion
