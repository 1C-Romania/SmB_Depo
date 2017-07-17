////////////////////////////////////////////////////////////////////////////////
// JobQueue: Work with jobs queue.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Calculates the next time of job start. 
// 
// Parameters: 
// Schedule                  - JobSchedule - schedule 
//                               for which it is required to calculate next start moment.
// TimeZone				   - String.
// LastStartDate - Date - Start date of last scheduled job. 
//                               If date is specified, then it is used to check such conditions as.
//                               DaysRepetitionPeriod, WeeksPeriod, RepetitionPeriodDuringDay 
//                               If date is not specified, it
// is assumed that job has not been executed once and these conditions are not checked.
// 
// Returns: 
// Date - Calculated next time of job start. 
// 
Function GetScheduledJobStartTime(Val Schedule, Val TimeZone, 
		Val LastStartDate = '00010101', Val CompletionDateLastRun = '00010101') Export
	
	If IsBlankString(TimeZone) Then
		TimeZone = Undefined;
	EndIf;
	
	If ValueIsFilled(LastStartDate) Then 
		LastStartDate = ToLocalTime(LastStartDate, TimeZone);
	EndIf;
	
	If ValueIsFilled(CompletionDateLastRun) Then
		CompletionDateLastRun = ToLocalTime(CompletionDateLastRun, TimeZone);
	EndIf;
	
	CalculationDate = ToLocalTime(CurrentUniversalDate(), TimeZone);
	
	FoundDate = NextExecutionDateSchedule(Schedule, CalculationDate, LastStartDate, CompletionDateLastRun);
	
	If ValueIsFilled(FoundDate) Then
		Return ToUniversalTime(FoundDate, TimeZone);
	Else
		Return FoundDate;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Declare service events to which SSL handlers can be attached.

// Declares the events of the JobQueue subsystem:
//
// Server events:
//   OnReceiveTemplateList
//   OnDefineHandlersAlias
//   OnDefineErrorsHandlers
//   OnDefineScheduledJobsUse.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Forms a list of queue jobs templates
	//
	// Parameters:
	//  Patterns - String array. You should add the names
	//   of predefined undivided scheduled jobs in the parameter
	//   that should be used as a template for setting a queue.
	//
	// Syntax:
	// Procedure OnReceiveTemplatesList(Templates) Export
	//
	// (Same as JobQueueOverridable.FillInSeparatedScheduledJobsList).
	ServerEvents.Add(
		"StandardSubsystems.SaaS.JobQueue\ListOfTemplatesOnGet");
	
	// Fills in the match of methods names and their aliases for call from the jobs queue.
	//
	// Parameters:
	//  AccordanceNamespaceAliases - Map
	//   key - Method alias, for example, ClearDataArea.
	//   Value - Method name for call, for example, SaaSOperations.ClearDataArea.
	//    You can specify Undefined as a value, in this case, it is
	// considered that name matches the alias.
	//
	// Syntax:
	// Procedure OnDefineHandlersAliases(AliasToNamesMatch) Export
	//
	// (Same as JobQueueOverridable.GetJobQueueAllowedMethods).
	ServerEvents.Add(
		"StandardSubsystems.SaaS.JobQueue\WhenYouDefineAliasesHandlers");
		
	// Fills in match of errors handlers methods to
	// methods aliases when errors in which they are called occur.
	//
	// Parameters:
	//  ErrorHandlers - Map
	//   key - Method alias, for example, ClearDataArea.
	//   Value - Method name - errors handler to call if an error occurs. 
	//    Errors handler is called when the initial
	//    job is executed with an error. Errors handler is called in the same data
	//    area that the initial job.
	//    Errors handler method is considered to be enabled for a call by the queue mechanisms. 
	//    Error handler parameters.:
	//     JobParameters - Structure - Job queue parameters.
	//      Parameters
	//      AttemptNumber
	//      RestartQuantityOnFailure
	//      LastStartDate.
	//     ErrorInfo - ErrorInfo - description of
	//      an error that occurred while executing a job.
	//
	// Syntax:
	// Procedure OnDefineErrorsHandlers(ErrorsHandlers) Export
	//
	// (Same as JobQueueOverridable.WhenDefiningErrorHandlers).
	ServerEvents.Add(
		"StandardSubsystems.SaaS.JobQueue\WhenDefiningHandlersErrors");
	
	// Generates scheduled jobs table with the flag of usage in the service model.
	//
	// Parameters:
	// UsageTable - ValueTable - table that
	//  should be filled in with the scheduled jobs a flag of usage, columns:
	//  ScheduledJob - String - name of the predefined scheduled job.
	//  Use - Boolean - True if scheduled job
	//   should be executed in the service model. False - if it should not.
	//
	// Syntax:
	// Procedure OnDefineSceduledJobsUsage (UsageTable) Export
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaS.JobQueue\OnDefenitionOfUsageOfScheduledJobs");
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"JobQueueService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnEnableSeparationByDataAreas"].Add(
		"JobQueueService");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Called up at enabling data classification into data fields.
//
Procedure OnEnableSeparationByDataAreas() Export
	
	SetScheduledJobsUsage();
	
	If Constants.ActiveBackgroundJobMaxExecutionTime.Get() = 0 Then
		Constants.ActiveBackgroundJobMaxExecutionTime.Set(600);
	EndIf;
	
	If Constants.ActiveBackgroundJobMaxCount.Get() = 0 Then
		Constants.ActiveBackgroundJobMaxCount.Set(1);
	EndIf;
	
EndProcedure

// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  ImportedCatalogs - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      * Presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	// Import to catalog JobQueue is prohibited.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.JobQueue.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
	// Import to catalog QueueJobsTemplates is prohibited.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.QueueJobsTemplates.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
EndProcedure


#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export service procedures and functions.

// Plans scheduled jobs from IR JobQueue.
// 
Procedure JobProcessingPlanning() Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	// Call OnBeginScheduledJobExecution
	// is not used as required actions are executed privately.
	
	// Select events in the Executed, Completed, NotPlanned, ExecutionError states.
	Query = New Query;
	
	CatalogsJobs = JobQueueServiceReUse.GetCatalogsJobs();
	QueryText = "";
	For Each CatalogJobs IN CatalogsJobs Do
		
		If Not IsBlankString(QueryText) Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
			
		EndIf;
		
		If CommonUseReUse.IsSeparatedConfiguration() AND CommonUseReUse.IsSeparatedMetadataObject(CatalogJobs.CreateItem().Metadata().FullName(), CommonUseReUse.SupportDataSplitter()) Then
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
			"SELECT
			|	Queue.DataAreaAuxiliaryData AS DataArea,
			|	Queue.Ref AS ID,
			|	ISNULL(Queue.Pattern, UNDEFINED) AS Pattern,
			|	ISNULL(TimeZone.Value, """") AS TimeZone,
			|	CASE
			|		WHEN Queue.Pattern = VALUE(Catalog.QueueJobsTemplates.EmptyRef)
			|			THEN Queue.Schedule
			|		ELSE Queue.Pattern.Schedule
			|	END AS Schedule,
			|	CASE
			|		WHEN Queue.Pattern = VALUE(Catalog.QueueJobsTemplates.EmptyRef)
			|			THEN Queue.RestartCountOnFailure
			|		ELSE Queue.Pattern.RestartCountOnFailure
			|	END AS RestartCountOnFailure,
			|	CASE
			|		WHEN Queue.Pattern = VALUE(Catalog.QueueJobsTemplates.EmptyRef)
			|			THEN Queue.RestartIntervalOnFailure
			|		ELSE Queue.Pattern.RestartIntervalOnFailure
			|	END AS RestartIntervalOnFailure
			|FROM
			|	%1 AS Queue
			|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZone
			|		ON Queue.DataAreaAuxiliaryData = TimeZone.DataAreaAuxiliaryData
			|WHERE
			|	Queue.JobState IN (VALUE(Enum.JobStates.Running), VALUE(Enum.JobStates.Completed), VALUE(Enum.JobStates.NotPlanned), VALUE(Enum.JobStates.ExecutionError))"
			, CatalogJobs.EmptyRef().Metadata().FullName());
			
		Else
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
			"SELECT
			|	-1 AS DataArea,
			|	Queue.Ref AS ID,
			|	UNDEFINED AS Pattern,
			|	"""" AS TimeZone,
			|	Queue.Schedule AS Schedule,
			|	Queue.RestartCountOnFailure AS RestartCountOnFailure,
			|	Queue.RestartIntervalOnFailure AS RestartIntervalOnFailure
			|FROM
			|	%1 AS Queue
			|WHERE
			|	Queue.JobState IN (VALUE(Enum.JobStates.Running), VALUE(Enum.JobStates.Completed), VALUE(Enum.JobStates.NotPlanned), VALUE(Enum.JobStates.ExecutionError))"
			, CatalogJobs.EmptyRef().Metadata().FullName());
			
		EndIf;
		
	EndDo;
	
	Query.Text = QueryText;
	Result = CommonUse.ExecuteQueryBeyondTransaction(Query);
	Selection = Result.Select();
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
	Else
		ModuleSaaSOperations = Undefined;
	EndIf;
	
	While Selection.Next() Do
		
		Try
			LockDataForEdit(Selection.ID);
		Except
			// The record is locked, go to next.
			Continue;
		EndTry;
		
		// Checks whether the data area is locked on.
		If ModuleSaaSOperations <> Undefined
			AND Selection.DataArea <> -1 
			AND ModuleSaaSOperations.DataAreaBlocked(Selection.DataArea) Then
			
			// The area is locked, move to the next record.
			Continue;
		EndIf;
		
		// Replan completed scheduled jobs and abnormally closed background jobs, delete the executed background jobs.
		ScheduleSchTask(Selection);
		
	EndDo;

	// Count the quantity of required background jobs executors.
	BackgroundJobsToStartCount = ActiveBackgroundJobCountToStart();
	
	// Start of executing background jobs.
	StartActiveBackgroundJob(BackgroundJobsToStartCount);
	
EndProcedure

// Procedure executes the jobs from IR JobQueue.
// 
// Parameters: 
// BackgroundJobKey - UUID - the key
// is required for the search of current background job.
//
Procedure ProcessJobQueue(BackgroundJobKey) Export
	
	// Call OnBeginScheduledJobExecution
	// is not used as required actions are executed privately.
	
	FoundBackgroundJob = BackgroundJobs.GetBackgroundJobs(New Structure("Key", BackgroundJobKey));
	If FoundBackgroundJob.Count() = 1 Then
		ActiveBackgroundJob = FoundBackgroundJob[0];
	Else
		Return;
	EndIf;
	
	CanExecute = True;
	ExecutionStarted = CurrentUniversalDate();
	
	ActiveBackgroundJobMaxExecutionTime = 
		Constants.ActiveBackgroundJobMaxExecutionTime.Get();
	ActiveBackgroundJobMaxCount =
		Constants.ActiveBackgroundJobMaxCount.Get();
	
	Query = New Query;
	
	CatalogsJobs = JobQueueServiceReUse.GetCatalogsJobs();
	QueryText = "";
	For Each CatalogJobs IN CatalogsJobs Do
		
		FirstRow = IsBlankString(QueryText);
		
		If Not FirstRow Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
			
		EndIf;
		
		If CommonUseReUse.IsSeparatedConfiguration() AND CommonUse.IsSeparatedMetadataObject(CatalogJobs.CreateItem().Metadata().FullName(), CommonUseReUse.SupportDataSplitter()) Then
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
			"SELECT
			|	Queue.DataAreaAuxiliaryData AS DataArea,
			|	Queue.Ref AS ID,
			|	Queue.Use,
			|	Queue.ScheduledStartTime AS ScheduledStartTime,
			|	Queue.JobState,
			|	Queue.ActiveBackgroundJob,
			|	Queue.ExclusiveExecution AS ExclusiveExecution,
			|	Queue.TryNumber,
			|	Queue.Pattern AS Pattern,
			|	ISNULL(Queue.Pattern.Ref, UNDEFINED) AS RefsTemplate,
			|	ISNULL(TimeZone.Value, """") AS TimeZone,
			|	CASE
			|		WHEN Queue.Pattern = VALUE(Catalog.QueueJobsTemplates.EmptyRef)
			|			THEN Queue.Schedule
			|		ELSE Queue.Pattern.Schedule
			|	END AS Schedule,
			|	CASE
			|		WHEN Queue.Pattern = VALUE(Catalog.QueueJobsTemplates.EmptyRef)
			|			THEN Queue.MethodName
			|		ELSE Queue.Pattern.MethodName
			|	END AS MethodName,
			|	Queue.Parameters,
			|	Queue.LastStartDate,
			|	Queue.CompletionDateLastRun
			|FROM %1 AS Queue LEFT JOIN InformationRegister.DataAreasSessionsLocks AS Locks
			|		ON Queue.DataAreaAuxiliaryData = Locks.DataAreaAuxiliaryData
			|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZone
			|		ON Queue.DataAreaAuxiliaryData = TimeZone.DataAreaAuxiliaryData
			|WHERE
			|	Queue.Use
			|	AND Queue.ScheduledStartTime <= &CurrentUniversalDate
			|	AND Queue.JobState = VALUE(Enum.JobStates.Planned)
			|	AND (Queue.ExclusiveExecution
			|			OR Locks.DataAreaAuxiliaryData IS NULL 
			|			OR Locks.LockPeriodStart > &CurrentUniversalDate
			|			OR Locks.LockEndOfPeriod < &CurrentUniversalDate)"
			, CatalogJobs.EmptyRef().Metadata().FullName());
			
		Else
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
			"SELECT
			|	-1 AS DataArea,
			|	Queue.Ref AS ID,
			|	Queue.Use,
			|	Queue.ScheduledStartTime AS ScheduledStartTime,
			|	Queue.JobState,
			|	Queue.ActiveBackgroundJob,
			|	Queue.ExclusiveExecution AS ExclusiveExecution,
			|	Queue.TryNumber,
			|	UNDEFINED AS Pattern,
			|	UNDEFINED AS RefsTemplate,
			|	"""" AS TimeZone,
			|	Queue.Schedule AS Schedule,
			|	Queue.MethodName AS MethodName,
			|	Queue.Parameters,
			|	Queue.LastStartDate,
			|	Queue.CompletionDateLastRun
			|FROM %1 AS Queue
			|WHERE
			|	Queue.Use
			|	AND Queue.ScheduledStartTime <= &CurrentUniversalDate
			|	AND Queue.JobState = VALUE(Enum.JobStates.Planned)"
			, CatalogJobs.EmptyRef().Metadata().FullName());
			
		EndIf;
		
	EndDo;
	
	QueryText = "SELECT TOP 111
	|	NestedSelect.DataArea,
	|	NestedSelect.ID AS ID,
	|	NestedSelect.Use,
	|	NestedSelect.ScheduledStartTime AS ScheduledStartTime,
	|	NestedSelect.ActiveBackgroundJob,
	|	NestedSelect.ExclusiveExecution AS ExclusiveExecution,
	|	NestedSelect.TryNumber,
	|	NestedSelect.Pattern,
	|	NestedSelect.RefsTemplate,
	|	NestedSelect.TimeZone,
	|	NestedSelect.Schedule,
	|	NestedSelect.MethodName,
	|	NestedSelect.Parameters,
	|	NestedSelect.LastStartDate,
	|	NestedSelect.CompletionDateLastRun
	|FROM
	|(SELECT TOP 111
	|	NestedSelect.DataArea,
	|	NestedSelect.ID AS ID,
	|	NestedSelect.Use,
	|	NestedSelect.ScheduledStartTime AS ScheduledStartTime,
	|	NestedSelect.ActiveBackgroundJob,
	|	NestedSelect.ExclusiveExecution AS ExclusiveExecution,
	|	NestedSelect.TryNumber,
	|	NestedSelect.Pattern,
	|	NestedSelect.RefsTemplate,
	|	NestedSelect.TimeZone,
	|	NestedSelect.Schedule,
	|	NestedSelect.MethodName,
	|	NestedSelect.Parameters,
	|	NestedSelect.LastStartDate,
	|	NestedSelect.CompletionDateLastRun
	|FROM
	|	(" +  QueryText + ") AS
	|
	|NestedSelect ORDER
	|	BY ExclusiveExecution
	|	DESC,
	|	PlannedStartMoment, Identifier";
	
	Query.Text = QueryText;
	SelectionSizeText = Format(ActiveBackgroundJobMaxCount * 3, "NZ=; NG=");
	Query.Text = StrReplace(Query.Text, "111", SelectionSizeText);
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
	Else
		ModuleSaaSOperations = Undefined;
	EndIf;
	
	While CanExecute Do 
		Query.SetParameter("CurrentUniversalDate", CurrentUniversalDate());
		
		Selection = CommonUse.ExecuteQueryBeyondTransaction(Query).Select();
		
		Locked = False;
		While Selection.Next() Do 
			Try
				
				LockDataForEdit(Selection.ID);
				
				// Checks whether the data area is locked on.
				If ModuleSaaSOperations <> Undefined
					AND Selection.DataArea <> -1 
					AND ModuleSaaSOperations.DataAreaBlocked(Selection.DataArea) Then
					
					UnlockDataForEdit(Selection.ID);
					
					// The area is locked, move to the next record.
					Continue;
				EndIf;
				
				If ValueIsFilled(Selection.Pattern)
						AND Selection.RefsTemplate = Undefined Then
					
					MessagePattern = NStr("en='Job template of queue with ID %1 is not found';ru='На найден шаблон задания очереди с идентификатором %1'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Selection.Pattern);
					WriteLogEvent(NStr("en='Job queue.Execution';ru='Очередь заданий.Выполнение'", 
						CommonUseClientServer.MainLanguageCode()), 
						EventLogLevel.Error,
						,
						,
						MessageText);
					
					UnlockDataForEdit(Selection.ID);
					Continue;
				EndIf;
				
				Locked = True;
				Break;
			Except
				// Failed to set a lock.
			EndTry;
		EndDo;
		
		If Not Locked Then 
			Return;
		EndIf;
		
		Schedule = Selection.Schedule.Get();
		If Schedule <> Undefined Then
			// Check if fitting into acceptable intervals of the queue.
			TimeZone = Selection.TimeZone;
			
			If IsBlankString(TimeZone) Then
				TimeZone = Undefined;
			EndIf;
			
			TimeAreas = ToLocalTime(CurrentUniversalDate(), TimeZone);
			Overdue = Not Schedule.ExecutionRequired(TimeAreas);
		Else
			Overdue = False;
		EndIf;
		
		If Overdue Then
			// It is required to reschedule the job.
			BeginTransaction();
			Try
				Block = New DataLock;
				LockItem = Block.Add(Selection.ID.Metadata().FullName());
				LockItem.SetValue("Ref", Selection.ID);
				
				If Selection.DataArea <> -1 Then
					CommonUse.SetSessionSeparation(True, Selection.DataArea);
				EndIf;
				Block.Lock();
				
				Task = Selection.ID.GetObject();
				Task.JobState = Enums.JobStates.NotPlanned;
				CommonUse.AuxilaryDataWrite(Task);
				CommitTransaction();
			Except
				CommonUse.SetSessionSeparation(False);
				RollbackTransaction();
				Raise;
			EndTry;
			CommonUse.SetSessionSeparation(False);
		Else
			ExecuteJobQueue(Selection.ID, ActiveBackgroundJob, Selection.Pattern, Selection.MethodName);
		EndIf;
		
		UnlockDataForEdit(Selection.ID);
		
		// Checking the possibility of further execution.
		ExecutionTime = CurrentUniversalDate() - ExecutionStarted;
		If ExecutionTime > ActiveBackgroundJobMaxExecutionTime Then
			CanExecute = False;
		EndIf;
	EndDo;
	
EndProcedure

// Service procedure that is called to execute job errors
// handler if the process that executes the job can not complete by itself.
//
// Parameters:
// Task - CatalogRef - ref to job error handler of which should be executed.
// ErrorInfoExecutionJobs - ErrorInfo - information about the error with which the job was completed.
//
Procedure HandleError(Val Task, Val ErrorInfoExecutionJobs = Undefined) Export
	
	Try
		
		LockDataForEdit(Task);
		
		HandlerErrorsParameters = GetErrorHandlerParameters(Task, ErrorInfoExecutionJobs);
		If HandlerErrorsParameters.ProcessorExist Then
			ExecuteConfigurationMethod(HandlerErrorsParameters.MethodName, HandlerErrorsParameters.HandlerCallParameters);
		EndIf;
		
	Except
		
		CommentTemplate = NStr("en='An error occurred while
		|executing errors handler
		|Method alias: %1 Errors
		|processor method:
		|%2 As: %3';ru='Ошибка при выполнении
		|обработчика ошибок
		|Псевдоним метода: %1 Метод
		|обработчика ошибок:
		|%2 По причине: %3'");
		TextOfComment = StringFunctionsClientServer.SubstituteParametersInString(
			CommentTemplate,
			HandlerErrorsParameters.JobMethodName,
			HandlerErrorsParameters.MethodName,
			DetailErrorDescription(ErrorInfo()));
			
		WriteLogEvent(
			NStr("en='Scheduled job queue. An error of the error handler occurred';ru='Очередь регламентных заданий.Ошибка обработчика ошибок'", 
				CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,
			,
			,
			TextOfComment);
			
	EndTry;
	
	If CommonUse.RefExists(Task)
		AND Task.JobState = Enums.JobStates.ErrorProcessingOnAbort Then
	
		TaskObject = Task.GetObject();
		TaskObject.JobState = Enums.JobStates.ExecutionError;
		CommonUse.AuxilaryDataWrite(TaskObject);
	
	EndIf;
	
	UnlockDataForEdit(Task);
	
EndProcedure

// Service procedure that clears errors handler jobs and its own ones. It it needed
// when "ProcessError" execution job can not be completed.
//
// Parameters:
// CallParameters - Array - Parameters array that was passed to job execution error
//                            of which you process is used only to determine job execution error of which you process.
// ErrorInfo - ErrorDescription - It is not used, it is needed only
//                                       because this parameter should be present in the errors handler.
// RecursionCounter - Number - Used to count created jobs of jobs clearance.
//
Procedure RemoveErrorDataProcessorsJobs(Val CallParameters, Val ErrorInfo = Undefined, Val RecursionCounter = 1) Export
	
	BeginTransaction();
	Try
		
		TaskRef = CallParameters.Parameters[0];
		
		If Not CommonUse.RefExists(TaskRef) Then
		
			RollbackTransaction();
			Return;
		
		EndIf;
		
		Task = TaskRef.GetObject();
		
		LockDataForEdit(TaskRef);
		
		Task.JobState = Enums.JobStates.ExecutionError;
		CommonUse.AuxilaryDataWrite(Task);
		
		HandlerErrorsParameters = GetErrorHandlerParameters(Task);
		If HandlerErrorsParameters.MethodName = "JobQueueService.RemoveErrorDataProcessorsJobs" Then
			
			RemoveErrorDataProcessorsJobs(HandlerErrorsParameters.HandlerCallParameters[0], ErrorInfo, RecursionCounter + 1);
			
		Else
			
			CommentTemplate = NStr("en='Jobs removal handler was executed.
		|Method alias:
		|%1 Level of recursion: %2';ru='Был выполнен обработчик снятие заданий.
		|Псевдоним
		|метода: %1 Уровень рекурсии: %2'");
			TextOfComment = StringFunctionsClientServer.SubstituteParametersInString(
				CommentTemplate,
				HandlerErrorsParameters.JobMethodName,
				RecursionCounter);
				
			WriteLogEvent(
				NStr("en='Scheduled job queue. End jobs of error processing';ru='Очередь регламентных заданий.Снятие заданий обработки ошибок'",
					CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Information,
				,
				,
				TextOfComment);
			
		EndIf;
			
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
	
	EndTry;
	
	UnlockDataForEdit(TaskRef);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local service procedures and functions.

// Method is designed to call job and errors handlers methods.
//
// Parameters: 
// MethodName - String - Name of called method.
// Parameters - Array - Value of the parameters passed
//                       to method in the order they appear in the called method.
//
Procedure ExecuteConfigurationMethod(MethodName, Parameters = Undefined)

	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		DelimiterSet = True;
		SeparatorValue = SaaSOperations.SessionSeparatorValue();
	Else
		DelimiterSet = False;
	EndIf;
	
	If TransactionActive() Then
		
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='There are active transactions before the handler %1 can start.';ru='Перед стартом выполнения обработчика %1 есть активные транзакции!'"),
				MethodName);
			
		WriteLogEvent(NStr("en='Scheduled job queue.Fulfillment';ru='Очередь регламентных заданий.Выполнение'", 
			CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,
			,
			,
			ErrorMessageText);
			
		Raise ErrorMessageText;
		
	EndIf;
	
	Try
		
		WorkInSafeMode.ExecuteConfigurationMethod(MethodName, Parameters);
		
		If TransactionActive() Then
		
			While TransactionActive() Do
				RollbackTransaction();
			EndDo;
			
			MessagePattern = NStr("en='Transaction was not closed after the handler %1 finished';ru='По завершении выполнения обработчика %1 не была закрыта транзакция'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, MethodName);
			WriteLogEvent(NStr("en='Scheduled job queue.Fulfillment';ru='Очередь регламентных заданий.Выполнение'", 
				CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error, 
				,
				, 
				MessageText);
			
		EndIf;
		
		If Not(DelimiterSet) AND CommonUse.UseSessionSeparator() Then
			
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Session separation was not disabled after the handler %1 finished.';ru='По завершении выполнения обработчика %1 не было выключено разделение сеанса!'"),
				MethodName);
			
			WriteLogEvent(NStr("en='Scheduled job queue.Fulfillment';ru='Очередь регламентных заданий.Выполнение'", 
				CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				,
				,
				ErrorMessageText);
			
			CommonUse.SetSessionSeparation(False);
			
		ElsIf DelimiterSet AND SeparatorValue <> SaaSOperations.SessionSeparatorValue() Then
			
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Session separator value was changed after the handler %1 finished.';ru='По завершении выполнения обработчика %1 было изменено значение разделителя сеанса!'"),
				MethodName);
			
			WriteLogEvent(NStr("en='Scheduled job queue.Fulfillment';ru='Очередь регламентных заданий.Выполнение'", 
				CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				,
				,
				ErrorMessageText);
			
			CommonUse.SetSessionSeparation(True,SeparatorValue);
			
		EndIf;
		
		
	Except
		
		While TransactionActive() Do
			RollbackTransaction();
		EndDo;
		
		If Not(DelimiterSet) AND CommonUse.UseSessionSeparator() Then
			CommonUse.SetSessionSeparation(False);
		ElsIf DelimiterSet AND SeparatorValue <> SaaSOperations.SessionSeparatorValue() Then
			CommonUse.SetSessionSeparation(True,SeparatorValue);
		EndIf;
		
		Raise;
		
	EndTry;
	
EndProcedure

// Generates and returns information about error by the text of its description.
Function ErrorInformationAssistant(ErrorText)

	Try
			
		Raise ErrorText;
			
	Except
		Information = ErrorInfo();
	EndTry;
	
	Return Information;

EndFunction

// Receives errors handler start parameters for specification by the reference.
//
// Parameters:
//  Task  - CatalogRef.JobsSchedule or CatalogRef.DataAreasJobsSchedule - 
//             Ref to job by which you should get errors handler parameters.
//
// Returns:
//   Structure - Parameters for error handler launch.
//      MethodName - String, errors handler method name that should be started.
//      JobMethodName - String, job method name that had
//      to be executed, HandlerCallParameters - array with parameters that will be passed to the errors processor procedure.
//      ProcessorExist - Boolean, error handler for this job exists.
//      Task - CatalogRef.JobsSchedule or CatalogRef.DataAreasJobsSchedule -
//                Ref to job that was passed as an incoming parameter.
//
Function GetErrorHandlerParameters(Val Task,Val ErrorInfoExecutionJobs = Undefined)

	Result = New Structure("MethodName,JobMethodName,HandlerCallParameters,ProcessorExist,Task");
	Result.Task = Task.Ref;
	
	If CommonUseReUse.IsSeparatedMetadataObject(Task.Metadata().FullName(), 
			CommonUseReUse.SupportDataSplitter()) 
		AND ValueIsFilled(Task.Pattern) Then
		
		Result.JobMethodName = Task.Pattern.MethodName;
		
	Else
		
		Result.JobMethodName = Task.MethodName;
		
	EndIf;
	
	ErrorHandlerMethodName = 
		JobQueueServiceReUse.MapHandlersErrorsAliases().Get(Upper(Result.JobMethodName));
	Result.MethodName = ErrorHandlerMethodName;
	Result.ProcessorExist = ValueIsFilled(Result.MethodName);
	If Result.ProcessorExist Then
		JobParameters = New Structure;
		JobParameters.Insert("Parameters", Task.Parameters.Get());
		JobParameters.Insert("TryNumber", Task.TryNumber);
		JobParameters.Insert("RestartCountOnFailure", Task.RestartCountOnFailure);
		JobParameters.Insert("LastStartDate", Task.LastStartDate);
		
		If ErrorInfoExecutionJobs = Undefined Then
			
			ActiveBackgroundJob = BackgroundJobs.FindByUUID(Task.ActiveBackgroundJob);
			
			If ActiveBackgroundJob <> Undefined AND ActiveBackgroundJob.ErrorInfo <> Undefined Then
				
				ErrorInfoExecutionJobs = ActiveBackgroundJob.ErrorInfo;
				
			EndIf;
			
		EndIf;
		
		If ErrorInfoExecutionJobs = Undefined Then
			
			ErrorInfoExecutionJobs = ErrorInformationAssistant(NStr("en='Job was completed with an unknown error, it could have been caused by the process failure.';ru='Задание завершилось с неизвестной ошибкой, возможно вызванной падением рабочего процесса.'"));
			
		EndIf;
		
		HandlerCallParameters = New Array;
		HandlerCallParameters.Add(JobParameters);
		HandlerCallParameters.Add(ErrorInfoExecutionJobs);
		
		Result.HandlerCallParameters = HandlerCallParameters;
	Else
		Result.HandlerCallParameters = Undefined;
	EndIf;

	Return Result;
	
EndFunction

// Generates and returns scheduled jobs names table with a usage flag.
//
// Returns:
// ValueTable - table that should
// 	be filled in with the scheduled jobs and usage flag.
//
Function GetScheduledJobUsageTable()
	
	UsageTable = New ValueTable;
	UsageTable.Columns.Add("ScheduledJob", New TypeDescription("String"));
	UsageTable.Columns.Add("Use", New TypeDescription("Boolean"));
	
	// Mandatory for this subsystem.
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "JobProcessingPlanning";
	NewRow.Use       = True;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.SaaS.JobQueue\OnDefenitionOfUsageOfScheduledJobs");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnDefenitionOfUsageOfScheduledJobs(UsageTable);
	EndDo;
	
	JobQueueOverridable.OnDefenitionOfUsageOfScheduledJobs(UsageTable);
	
	Return UsageTable;
	
EndFunction

Function ActiveBackgroundJobCount()
	
	Filter = New Structure("Description, Status", GetActiveBackgroundJobDescription(), BackgroundJobState.Active); 
	ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter); 
	
	ActiveBackgroundJobCount = ActiveBackgroundJobs.Count();
	
	Return ActiveBackgroundJobCount;
	
EndFunction

// Counts required quantity of the background jobs executors.
// 
Function ActiveBackgroundJobCountToStart()
	
	ActiveBackgroundJobCount = ActiveBackgroundJobCount();
	
	ActiveBackgroundJobCountToStart = 
		Constants.ActiveBackgroundJobMaxCount.Get() - ActiveBackgroundJobCount;
	
	If ActiveBackgroundJobCountToStart < 0 Then
		ActiveBackgroundJobCountToStart = 0;
	EndIf;

	Return ActiveBackgroundJobCountToStart;
	
EndFunction

// Starts the specified quantity of background jobs.
// 
// Parameters: 
// BackgroundJobsToStartCount - Number - quantity
//                                       of background jobs that should be started.
//
Procedure StartActiveBackgroundJob(BackgroundJobsToStartCount) 
	
	For IndexOf = 1 To BackgroundJobsToStartCount Do
		Key = New UUID;
		Parameters = New Array;
		Parameters.Add(Key);
		BackgroundJobs.Execute("JobQueueService.ProcessJobQueue", Parameters, Key, GetActiveBackgroundJobDescription());
	EndDo;
	
EndProcedure

Function GetActiveBackgroundJobDescription()
	
	Return "ActiveBackgroundJobs_5340185be5b240538bc73d9f18ef8df1";
	
EndFunction

Procedure WriteExecutionControlEventLogMonitor(Val EventName, Val WritingJob, Val Comment = "")
	
	If Not IsBlankString(Comment) Then
		Comment = Comment + Chars.LF;
	EndIf;
	
	WriteLogEvent(EventName, EventLogLevel.Information, ,
		String(WritingJob.UUID()), Comment + WritingJob.MethodName + ";" + 
			?(CommonUseReUse.IsSeparatedConfiguration() AND CommonUse.IsSeparatedMetadataObject(WritingJob.Metadata().FullName(),
				CommonUseReUse.SupportDataSplitter()),
				Format(WritingJob.DataAreaAuxiliaryData, "NZ=0; NG="), "-1"));
	
EndProcedure

// Executes job handler created without using the template.
// 
// Parameters: 
// Alias - String - Alias of a method to be executed.
// Parameters - Array - parameters are passed to MethodName in order array items are located.
// 
Procedure ExecuteHandlerTasks(Pattern, Alias, Parameters)
	
	MethodName = JobQueueServiceReUse.AccordanceMethodNamesToAliases().Get(Upper(Alias));
	If MethodName = Undefined Then
		MessagePattern = NStr("en='Method %1 cannot be called via the job queue.';ru='Метод %1 не разрешен к вызову через очередь заданий.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Alias);
		Raise(MessageText);
	EndIf;
	
	ExecuteConfigurationMethod(MethodName,Parameters);
	
EndProcedure

// Returns the next date of schedule execution.
//
// Parameters:
//  Schedule - JobSchedule - schedule
//   according to which the date will be calculated.
//  DateForChecks - Date (DateTime) - min date to
//   which execution can be planned.
//  LastStartDate - Date (DateTime) - Start date of
// last job launch. If date is specified, then it is used
// to check such conditions as DaysRepetitionPeriod, PeriodWeeks, RepetitionPeriodDuringDay. 
//   If date is not specified, it is assumed that job has not
// been executed once and these conditions are not checked. 
//  CompletionDateLastRun - Date (DateTime) - End date
// of last job launch. If date is specified, then it
// is used to check the RepetitionPause condition. If date is not specified, then it
// is considered that job has not been completed once and this condition is not checked. 
//  MaximumPlanningHorizon - Number - Max possible
//   quantity of seconds relatively to DateForCheck to which planning can be executed.
//   If you increase value, calculation may be slowed
//   down in the complex schedules.
//
Function NextExecutionDateSchedule(Val Schedule, Val DateForChecks, 
	Val LastStartDate = Undefined, Val CompletionDateLastRun = Undefined, 
	Val MaximumPlanningHorizon = Undefined) Export
	
	If MaximumPlanningHorizon = Undefined Then
		MaximumPlanningHorizon = 366 * 86400 * 10;
	EndIf;
	
	SourceDateForVerification = DateForChecks;
	BeginTimeOfLastLaunch = '00010101' + (LastStartDate - BegOfDay(LastStartDate));
	
	// Limits by date
	If ValueIsFilled(Schedule.EndDate)
		AND DateForChecks > Schedule.EndDate Then
		
		// Interval of execution by day ended.
		Return '00010101';
	EndIf;
		
	If DateForChecks < Schedule.StartDate Then
		DateForChecks = Schedule.StartDate;
	EndIf;
	
	CanChangeDay = True;
	
	// Frequency tracking
	If ValueIsFilled(LastStartDate) Then
		
		// Weeks period
		If Schedule.WeeksPeriod > 1
			AND (BegOfWeek(DateForChecks) - BegOfWeek(LastStartDate)) / (7 * 86400) < Schedule.WeeksPeriod Then
		
			DateForChecks = BegOfWeek(LastStartDate) + 7 * 86400 * Schedule.WeeksPeriod;
		EndIf;
		
		// Days period
		If Schedule.DaysRepeatPeriod = 0 Then
			If BegOfDay(DateForChecks) <> BegOfDay(LastStartDate) Then
				// Repetition is not set and the job was already completed.
				Return '00010101';
			EndIf;
			
			CanChangeDay = False;
		EndIf;
		
		If Schedule.DaysRepeatPeriod > 1
			AND BegOfDay(DateForChecks) - BegOfDay(LastStartDate) < (Schedule.DaysRepeatPeriod - 1)* 86400 Then
			
			DateForChecks = BegOfDay(LastStartDate) + Schedule.DaysRepeatPeriod * 86400;
		EndIf;
		
		// If job is repeated once a day (but no more often), then move it to the next day after the last start.
		If Schedule.DaysRepeatPeriod = 1 AND Schedule.RepeatPeriodInDay = 0 Then
			DateForChecks = Max(DateForChecks, BegOfDay(LastStartDate+86400));
		EndIf;

	EndIf;
	
	// Accounting of acceptable launch intervals.
	ChangeMonth = False;
	ChangeDay = False;
	While True Do
		
		If DateForChecks - SourceDateForVerification > MaximumPlanningHorizon Then
			// Postpone planning
			Return '00010101';
		EndIf;
		
		If Not CanChangeDay
			AND (ChangeDay OR ChangeMonth) Then
			
			// Repetition is not set and the job was already completed.
			Return '00010101';
		EndIf;
		
		// Months
		While ChangeMonth
			OR Schedule.Months.Count() > 0 
			AND Schedule.Months.Find(Month(DateForChecks)) = Undefined Do
			
			ChangeMonth = False;
			
			// Transition to next month
			DateForChecks = BegOfMonth(AddMonth(DateForChecks, 1));
		EndDo;
		
		// Day of the month
		DaysInMonth = Day(EndOfMonth(DateForChecks));
		If Schedule.DayInMonth <> 0 Then
			
			CurrentDay = Day(DateForChecks);
			
			If Schedule.DayInMonth > 0 
				AND (DaysInMonth < Schedule.DayInMonth OR CurrentDay > Schedule.DayInMonth)
				OR Schedule.DayInMonth < 0 
				AND (DaysInMonth < -Schedule.DayInMonth OR CurrentDay > DaysInMonth - -Schedule.DayInMonth) Then
				
				// There is no such date in this month or it has already passed.
				ChangeMonth = True;
				Continue;
			EndIf;
			
			If Schedule.DayInMonth > 0 Then
				DateForChecks = BegOfMonth(DateForChecks) + (Schedule.DayInMonth - 1) * 86400;
			EndIf;
			
			If Schedule.DayInMonth < 0 Then
				DateForChecks = BegOfDay(EndOfMonth(DateForChecks)) - (-Schedule.DayInMonth -1) * 86400;
			EndIf;
		EndIf;
		
		// Weekday in month
		If Schedule.WeekDayInMonth <> 0 Then
			If Schedule.WeekDayInMonth > 0 Then
				BeginningDayOfWeek = (Schedule.WeekDayInMonth - 1) * 7 + 1;
			EndIf;
			If Schedule.WeekDayInMonth < 0 Then
				BeginningDayOfWeek = DaysInMonth - (-Schedule.WeekDayInMonth) * 7 + 1;
			EndIf;
			
			DayEndOfWeek = min(BeginningDayOfWeek + 6, DaysInMonth);
			
			If Day(DateForChecks) > DayEndOfWeek 
				OR BeginningDayOfWeek > DaysInMonth Then
				// IN this month the required week has already passed (or it didn't exist)
				ChangeMonth = True;
				Continue;
			EndIf;
			
			If Day(DateForChecks) < BeginningDayOfWeek Then
				If Schedule.DayInMonth <> 0 Then
					
					// Day is fixed and it is not suitable.
					ChangeMonth = True;
					Continue;
				EndIf;
				DateForChecks = BegOfMonth(DateForChecks) + (BeginningDayOfWeek - 1) * 86400;
			EndIf;
		EndIf;
		
		// Day of the week
		While ChangeDay
			OR Schedule.WeekDays.Find(WeekDay(DateForChecks)) = Undefined
			AND Schedule.WeekDays.Count() > 0 Do
			
			ChangeDay = False;
			
			If Schedule.DayInMonth <> 0 Then
				// Day is fixed and it is not suitable.
				ChangeMonth = True;
				Break;
			EndIf;
			
			If Day(DateForChecks) = DaysInMonth Then
				// The month is over
				ChangeMonth = True;
				Break;
			EndIf;
			
			If Schedule.WeekDayInMonth <> 0
				AND Day(DateForChecks) = DayEndOfWeek Then
				
				// Required week ended
				ChangeMonth = True;
				Break;
			EndIf;
			
			DateForChecks = BegOfDay(DateForChecks) + 86400;
		EndDo;
		If ChangeMonth Then
			Continue;
		EndIf;
		
		// Time tracking
		TimeForChecks = '00010101' + (DateForChecks - BegOfDay(DateForChecks));
		
		If Schedule.DetailedDailySchedules.Count() = 0 Then
			DetailedSchedule = New Array;
			DetailedSchedule.Add(Schedule);
		Else
			DetailedSchedule = Schedule.DetailedDailySchedules;
		EndIf;
		
		// If you have intervals with transitions through midnight, then divide them into two intervals.
		IndexOf = 0;
		While IndexOf < DetailedSchedule.Count() Do
			
			DailySchedule = DetailedSchedule[IndexOf];
			
			If Not ValueIsFilled(DailySchedule.BeginTime) OR Not ValueIsFilled(DailySchedule.EndTime) Then
				IndexOf = IndexOf + 1;
				Continue;
			EndIf;
			
			If DailySchedule.BeginTime > DailySchedule.EndTime Then
				
				DailyScheduleBeforeNoon = New JobSchedule();
				FillPropertyValues(DailyScheduleBeforeNoon,DailySchedule);
				DailyScheduleBeforeNoon.BeginTime = BegOfDay(DailyScheduleBeforeNoon.BeginTime);
				DetailedSchedule.Add(DailyScheduleBeforeNoon);
				
				DailyScheduleAfternoon = New JobSchedule();
				FillPropertyValues(DailyScheduleAfternoon,DailySchedule);
				DailyScheduleAfternoon.EndTime = EndOfDay(DailyScheduleAfternoon.BeginTime);
				DetailedSchedule.Add(DailyScheduleAfternoon);
				
				DetailedSchedule.Delete(IndexOf);
				
			Else
				
				IndexOf = IndexOf + 1;
				
			EndIf;
		
		EndDo;
		
		For IndexOf = 0 To DetailedSchedule.UBound() Do
			DailySchedule = DetailedSchedule[IndexOf];
			
			// Limits by time
			If ValueIsFilled(DailySchedule.BeginTime)
				AND TimeForChecks < DailySchedule.BeginTime Then
				
				TimeForChecks = DailySchedule.BeginTime;
			EndIf;
			
			If ValueIsFilled(DailySchedule.EndTime)
				AND TimeForChecks > DailySchedule.EndTime Then
				
				If IndexOf < DetailedSchedule.UBound() Then
					// There are more daily schedules
					Continue;
				EndIf;
				
				// A suitable time has already passed on this day.
				ChangeDay = True;
				Break;
			EndIf;
			
			// Retry period within one day.
			If ValueIsFilled(LastStartDate) Then
				
				If DailySchedule.RepeatPeriodInDay = 0
					AND BegOfDay(DateForChecks) = BegOfDay(LastStartDate)
					AND (NOT ValueIsFilled(DailySchedule.BeginTime) 
						OR ValueIsFilled(DailySchedule.BeginTime) AND BeginTimeOfLastLaunch >= DailySchedule.BeginTime)
					AND (NOT ValueIsFilled(DailySchedule.EndTime) 
						OR ValueIsFilled(DailySchedule.EndTime) AND BeginTimeOfLastLaunch <= DailySchedule.EndTime) Then
					
					// Job has already been executed in this interval (day schedule) and repetitions are not set.
					If IndexOf < DetailedSchedule.UBound() Then
						Continue;
					EndIf;
					
					ChangeDay = True;
					Break;
				EndIf;
				
				If BegOfDay(DateForChecks) = BegOfDay(LastStartDate)
					AND TimeForChecks - BeginTimeOfLastLaunch < DailySchedule.RepeatPeriodInDay Then
					
					NewTimeForChecks = BeginTimeOfLastLaunch + DailySchedule.RepeatPeriodInDay;
					
					If ValueIsFilled(DailySchedule.EndTime) AND NewTimeForChecks > DailySchedule.EndTime
						OR BegOfDay(NewTimeForChecks) <> BegOfDay(TimeForChecks) Then
						
						// Time interval is expired
						If IndexOf < DetailedSchedule.UBound() Then
							Continue;
						EndIf;
						
						ChangeDay = True;
						Break;
					EndIf;
					
					TimeForChecks = NewTimeForChecks;
					
				EndIf;
				
			EndIf;
			
			// Pause
			If ValueIsFilled(CompletionDateLastRun) 
				AND ValueIsFilled(DailySchedule.RepeatPause) Then
				
				CompletionTimeOfLastLaunch = '00010101' + (CompletionDateLastRun - BegOfDay(CompletionDateLastRun));
				
				If BegOfDay(DateForChecks) = BegOfDay(LastStartDate)
					AND TimeForChecks - CompletionTimeOfLastLaunch < DailySchedule.RepeatPause Then
					
					NewTimeForChecks = CompletionTimeOfLastLaunch + DailySchedule.RepeatPause;
					
					If ValueIsFilled(DailySchedule.EndTime) AND NewTimeForChecks > DailySchedule.EndTime
						OR BegOfDay(NewTimeForChecks) <> BegOfDay(TimeForChecks) Then
						
						// Time interval is expired
						If IndexOf < DetailedSchedule.UBound() Then
							Continue;
						EndIf;
						
						ChangeDay = True;
						Break;
					EndIf;
					
					TimeForChecks = NewTimeForChecks;
					
				EndIf;
			EndIf;
			
			// Found a suitable time
			Break;
			
		EndDo;
		
		If ChangeDay Then
			Continue;
		EndIf;
		
		If ValueIsFilled(Schedule.CompletionTime)
			AND TimeForChecks > Schedule.CompletionTime Then
			// It is too late to execute on this day.
			ChangeDay = True;
			Continue;
		EndIf;
		
		DateForChecks = BegOfDay(DateForChecks) + (TimeForChecks - BegOfDay(TimeForChecks));
		
		Return DateForChecks;
		
	EndDo;
	
EndFunction

Procedure ScheduleSchTask(Val Selection)
	
	If ValueIsFilled(Selection.TimeZone) Then
		TimeZone = Selection.TimeZone;
	Else
		TimeZone = Undefined;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		If Selection.DataArea <> -1 Then
			CommonUse.SetSessionSeparation(True, Selection.DataArea);
		EndIf;
		
		Block = New DataLock;
		LockItem = Block.Add(Selection.ID.Metadata().FullName());
		LockItem.SetValue("Ref", Selection.ID);
		Block.Lock();
		
		If Not CommonUse.RefExists(Selection.ID) Then
			Block.Lock();
			UnlockDataForEdit(Selection.ID);
			RollbackTransaction();
			Return;
		EndIf;
		
		Task = Selection.ID.GetObject();
		
		If CommonUseReUse.IsSeparatedConfiguration() AND CommonUseReUse.IsSeparatedMetadataObject(Task.Metadata().FullName(), CommonUseReUse.SupportDataSplitter()) Then
			
			If ValueIsFilled(Task.Pattern)
				AND Selection.Pattern = Undefined Then
				
				MessagePattern = NStr("en='The %1 queue job template is not found';ru='На найден шаблон задания очереди %1'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Task.Pattern);
				
				WriteLogEvent(NStr("en='Job queue.Planning';ru='Очередь заданий.Планирование'", 
					CommonUseClientServer.MainLanguageCode()), 
					EventLogLevel.Error,
					,
					,
					MessageText);
				
				CommonUse.SetSessionSeparation(False);
				UnlockDataForEdit(Selection.ID);
				RollbackTransaction();
				Return;
				
			EndIf;
			
		EndIf;
			
		If Task.JobState = Enums.JobStates.ExecutionError
			AND Task.TryNumber < Selection.RestartCountOnFailure Then // Attempting to restart
			
			If ValueIsFilled(Task.CompletionDateLastRun) Then
				StartingPointRestart = Task.CompletionDateLastRun;
			Else
				StartingPointRestart = Task.LastStartDate;
			EndIf;
			
			Task.ScheduledStartTime = StartingPointRestart + Selection.RestartIntervalOnFailure;
			Task.TryNumber                 = Task.TryNumber + 1;
			Task.JobState             = Enums.JobStates.Planned;
			Task.ActiveBackgroundJob    = Undefined;
			CommonUse.AuxilaryDataWrite(Task);
			
		// Job was not executed, plan error handler.
		ElsIf Task.JobState = Enums.JobStates.Running Then
			
			WriteExecutionControlEventLogMonitor(NStr("en='Scheduled job queue. Completed with errors';ru='Очередь регламентных заданий.Завершено с ошибками'", 
				CommonUseClientServer.MainLanguageCode()), Selection.ID, 
				NStr("en='Active job was forcibly terminated';ru='Исполняющее задание было принудительно завершено'"));
				
			// Plan a one-time job to execute error handler.
			HandlerParameters = GetErrorHandlerParameters(Task);
			If HandlerParameters.ProcessorExist Then
				
				NewJob = Catalogs[Task.Metadata().Name].CreateItem();
				NewJob.ScheduledStartTime = CurrentUniversalDate();
				NewJob.Use = True;
				NewJob.JobState = Enums.JobStates.Planned;
				CallParameters = New Array;
				CallParameters.Add(Task.Ref);
				NewJob.Parameters = New ValueStorage(CallParameters);
				NewJob.MethodName = "JobQueueService.ProcessError";
				If CommonUse.IsSeparatedMetadataObject(Task.Metadata(),"DataAreaAuxiliaryData") Then
					NewJob.DataAreaAuxiliaryData = Task.DataAreaAuxiliaryData;
				EndIf;
				CommonUse.AuxilaryDataWrite(NewJob);
				
				// Abort job execution until errors processor is executed.
				Task.JobState = Enums.JobStates.ErrorProcessingOnAbort;
				
			Else
				
				Task.JobState = Enums.JobStates.ExecutionError;
				
			EndIf;
			
				CommonUse.AuxilaryDataWrite(Task);
			
		Else
			Schedule = Selection.Schedule.Get();
			If Schedule <> Undefined Then
				
				Task.ScheduledStartTime = GetScheduledJobStartTime(
					Schedule, TimeZone, Task.LastStartDate, Task.CompletionDateLastRun);
				Task.TryNumber = 0;
				If ValueIsFilled(Task.ScheduledStartTime) Then
					Task.JobState = Enums.JobStates.Planned;
				Else
					Task.JobState = Enums.JobStates.NotActive;
				EndIf;
				Task.ActiveBackgroundJob = Undefined;
				CommonUse.AuxilaryDataWrite(Task);
				
			Else // No schedule
				
				If CommonUseReUse.IsSeparatedConfiguration() AND CommonUseReUse.IsSeparatedMetadataObject(
							Task.Metadata().FullName(),
							CommonUseReUse.SupportDataSplitter()
						) Then
					If ValueIsFilled(Task.Pattern) Then // Job by template without schedule.
						
						MessagePattern = NStr("en='The schedule was not found for the %1 queue job template';ru='Для шаблон заданий очереди %1 не найдено расписание'");
						MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Task.Pattern);
						WriteLogEvent(NStr("en='Job queue.Planning';ru='Очередь заданий.Планирование'", 
							CommonUseClientServer.MainLanguageCode()), 
							EventLogLevel.Error,
							,
							,
							MessageText);
						
						CommonUse.SetSessionSeparation(False);
						RollbackTransaction();
						UnlockDataForEdit(Selection.ID);
						Return;
						
					EndIf;
				EndIf;
				
				// One-time job
				Task.DataExchange.Load = True;
				Task.Delete();
				
			EndIf;
		EndIf;
		
		CommonUse.SetSessionSeparation(False);
		CommitTransaction();
		UnlockDataForEdit(Selection.ID);
		
	Except
		
		CommonUse.SetSessionSeparation(False);
		RollbackTransaction();
		UnlockDataForEdit(Selection.ID);
		Raise;
		
	EndTry;
	
EndProcedure

Procedure ExecuteJobQueue(Val Ref, Val ActiveBackgroundJob, 
		Val Pattern, Val MethodName)
	
	DataArea = Undefined;
	If CommonUseReUse.IsSeparatedConfiguration() Then
		ModuleJobQueueServiceDataSeparation = CommonUse.CommonModule("JobQueueServiceDataSeparation");
		OverriddenDataArea = ModuleJobQueueServiceDataSeparation.IdentifyDataAreaForTask(Ref);
		If OverriddenDataArea <> Undefined Then
			DataArea = OverriddenDataArea;
		EndIf;
	EndIf;
	
	If DataArea = Undefined Then
		DataArea = -1;
	EndIf;
	
	BeginTransaction();
	Try
		
		If DataArea <> -1 Then
			CommonUse.SetSessionSeparation(True, DataArea);
		EndIf;
		
		Block = New DataLock;
		LockItem = Block.Add(Ref.Metadata().FullName());
		LockItem.SetValue("Ref", Ref);
		Block.Lock();
		
		Task = Ref.GetObject();
		
		If Task.JobState = Enums.JobStates.Planned
			AND Task.Use
			AND Task.ScheduledStartTime <= CurrentUniversalDate() Then 
			
			Task.JobState = Enums.JobStates.Running;
			Task.ActiveBackgroundJob = ActiveBackgroundJob.UUID;
			Task.LastStartDate = CurrentUniversalDate();
			Task.CompletionDateLastRun = Undefined;
			CommonUse.AuxilaryDataWrite(Task);
			
			CommitTransaction();
			
		Else
			
			CommonUse.SetSessionSeparation(False);
			CommitTransaction();
			Return;
			
		EndIf;
		
	Except
		
		CommonUse.SetSessionSeparation(False);
		RollbackTransaction();
		Raise;
		
	EndTry;
	
	// Job execution
	CompletedSuccessfully = False;
	ErrorInfoExecutionJobs = Undefined;
	Try
		WriteExecutionControlEventLogMonitor(NStr("en='Scheduled job queue.Start';ru='Очередь регламентных заданий.Старт'", 
			CommonUseClientServer.MainLanguageCode()), Ref);
		
		If ValueIsFilled(Pattern) Then
			ExecuteConfigurationMethod(MethodName);
		Else
			ExecuteHandlerTasks(Pattern, MethodName, Task.Parameters.Get());
		EndIf;
		
		CompletedSuccessfully = True;
		
		WriteExecutionControlEventLogMonitor(NStr("en='Scheduled job queue. Successfully completed';ru='Очередь регламентных заданий.Завершено успешно'", 
			CommonUseClientServer.MainLanguageCode()), Ref);
		
	Except
		
		ErrorInfoExecutionJobs = ErrorInfo();
		
		WriteExecutionControlEventLogMonitor(NStr("en='Scheduled job queue. Completed with errors';ru='Очередь регламентных заданий.Завершено с ошибками'", 
			CommonUseClientServer.MainLanguageCode()), Ref, 
			DetailErrorDescription(ErrorInfoExecutionJobs));
		
		WriteLogEvent(NStr("en='Scheduled job queue.Fulfillment';ru='Очередь регламентных заданий.Выполнение'", 
			CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error, 
			,
			ActiveBackgroundJob, 
			DetailErrorDescription(ErrorInfoExecutionJobs)); 
			
		
	EndTry;
		
	If Not CompletedSuccessfully Then
		
		// Calling error handlers
		HandleError(Ref, ErrorInfoExecutionJobs);
		
	EndIf;
	
	BeginTransaction();
	Try
		
		If CommonUse.RefExists(Ref) Then // Else - the job could have been deleted inside the handler.
			
			Block = New DataLock;
			LockItem = Block.Add(Ref.Metadata().FullName());
			LockItem.SetValue("Ref", Ref);
			Block.Lock();
			
			Task = Ref.GetObject();
			Task.CompletionDateLastRun = CurrentUniversalDate();
			
			If CompletedSuccessfully Then
				Task.JobState = Enums.JobStates.Completed;
			Else
				Task.JobState = Enums.JobStates.ExecutionError;
			EndIf;
			CommonUse.AuxilaryDataWrite(Task);
			
		EndIf;
		
		CommitTransaction();
		
	Except
		
		CommonUse.SetSessionSeparation(False);
		RollbackTransaction();
		Raise;
		
	EndTry;
	
	CommonUse.SetSessionSeparation(False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable
//                                  function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "JobQueueService.SetScheduledJobsUsage";
	Handler.SharedData = True;
	Handler.Priority = 50;
	Handler.ExclusiveMode = False;
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.9";
	Handler.Procedure = "JobQueueService.TransferJobsToQueuesToUndividedData";
	Handler.SharedData = True;
	Handler.ExecuteUnderMandatory = True;
	Handler.Priority = 80;
	Handler.ExclusiveMode = True;
	
EndProcedure

// Disables scheduled jobs that are used only in
// the local mode and enables the ones used only in the service model.
//
Procedure SetScheduledJobsUsage() Export
	
	ScheduledJobsUsageTableSaaS = GetScheduledJobUsageTable();
	
	For Each String IN ScheduledJobsUsageTableSaaS Do
		
		If CommonUseReUse.DataSeparationEnabled() Then
			
			// Enable scheduled jobs designed for using in the service model.
			// Disable scheduled jobs designed for using in the local mode.
			RequiredUse = String.Use;
			
		Else
			
			If String.Use Then
				// Disable scheduled jobs designed for using in the service model.
				RequiredUse = False;
			Else
				// Do not change jobs settings designed to use in the local mode.
				Continue;
			EndIf;
			
		EndIf;
		
		Filter = New Structure("Metadata", Metadata.ScheduledJobs[String.ScheduledJob]);
		FoundScheduledJobs = ScheduledJobs.GetScheduledJobs(Filter);
		
		For Each ScheduledJob IN FoundScheduledJobs Do
			
			If ScheduledJob.Use <> RequiredUse Then
				ScheduledJob.Use = RequiredUse;
				ScheduledJob.Write();
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Transfers jobs from IR JobQueue to the JobQueue catalog.
Procedure TransferJobsToQueuesToUndividedData() Export
	
	BeginTransaction();
	
	Try
		
		Block = New DataLock();
		LockingCatalog = Block.Add("Catalog.JobQueue");
		LockingCatalog.Mode = DataLockMode.Exclusive;
		Block.Lock();
		
		QueryText = 
		"SELECT
		|	DeleteJobQueue.Use,
		|	DeleteJobQueue.ScheduledStartTime,
		|	DeleteJobQueue.JobState,
		|	DeleteJobQueue.ActiveBackgroundJob,
		|	DeleteJobQueue.ExclusiveExecution,
		|	DeleteJobQueue.Pattern,
		|	DeleteJobQueue.TryNumber,
		|	DeleteJobQueue.DeleteScheduledJob,
		|	DeleteJobQueue.MethodName,
		|	DeleteJobQueue.Parameters,
		|	DeleteJobQueue.LastStartDate,
		|	DeleteJobQueue.Key,
		|	DeleteJobQueue.RestartIntervalOnFailure,
		|	DeleteJobQueue.Schedule,
		|	DeleteJobQueue.RestartCountOnFailure,
		|	DeleteJobQueue.ID
		|FROM
		|	InformationRegister.DeleteJobQueue AS DeleteJobQueue
		|WHERE
		|	DeleteJobQueue.DataArea = -1";
		Query = New Query(QueryText);
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			RefTask = Catalogs.JobQueue.GetRef(
				New UUID(Selection.ID));
			
			If CommonUse.RefExists(RefTask) Then
				NewJob = RefTask.GetObject();
			Else
				NewJob = Catalogs.JobQueue.CreateItem();
			EndIf;
			
			FillPropertyValues(NewJob, Selection);
			CommonUse.AuxilaryDataWrite(NewJob);
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion
