////////////////////////////////////////////////////////////////////////////////
// Additional Reports And Data Processors in Service Models
// subsystem, procedures and functions to manage queue jobs.
// 
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// It creates a job of the job queue.
//
// Return value: CatalogRef.JobQueueDataAreas.
//
Function CreateNewJob() Export
	
	SetPrivilegedMode(True);
	
	JobParameters = New Structure();
	JobParameters.Insert("Use", False);
	JobParameters.Insert("MethodName", Metadata.ScheduledJobs.LaunchAdditionalDataProcessors.MethodName);
	
	Return JobQueue.AddJob(JobParameters);
	
EndFunction

// It returns the queue job ID (to save in the infobase data).
//
// Task - CatalogRef.JobQueueDataAreas.
//
// Return value: UUID.
//
Function GetIDTasks(Val Task) Export
	
	SetPrivilegedMode(True);
	Return Task.UUID();
	
EndFunction

// It sets the job parameters of the job queue.
//
// Parameters:
//  Task - CatalogRef.JobQueueDataAreas,
//  Use - Boolean, flag of using the scheduled job,
//  Parameters - Array(Arbitrary), scheduled job parameters,
//  Schedule - ScheduledJobSchedule.
//
Procedure SetJobParameters(Task, Use, Parameters, Schedule) Export
	
	If Not Constants.AllowAdditionalReportsAndDataProcessorsPerformByProceduralTasksSaaS.Get() Then
		Raise NStr("en = 'Service administration prohibited the regular execution of additional data processors commands as jobs!'");
	EndIf;
	
	MinInterval = Constants.AdditionalReportsAndDataProcessorsProceduralTasksMinIntervalSaaS.Get();
	OriginalDate = CurrentSessionDate();
	ChackedDate = OriginalDate + MinInterval - 1;
	If Schedule.ExecutionRequired(ChackedDate, OriginalDate) Then
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Schedule specified for the execution of additional report or data processor commands as jobs, should not be more than once in %1 seconds!'"), MinInterval);
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	JobParameters = New Structure();
	JobParameters.Insert("Use", Use);
	JobParameters.Insert("MethodName", Metadata.ScheduledJobs.LaunchAdditionalDataProcessors.MethodName);
	JobParameters.Insert("Parameters", Parameters);
	JobParameters.Insert("Key", Metadata.ScheduledJobs.LaunchAdditionalDataProcessors.Key);
	JobParameters.Insert("Schedule", Schedule);
	
	JobQueue.ChangeTask(Task, JobParameters);
	
EndProcedure

// It returns the job parameters of the job queue.
//
// Parameters:
//  Task - CatalogRef.JobQueueDataAreas.
//
// Return value: Structure, key description - see returned value
//  description for the JobQueue.GetJobs() function.
//
Function GetJobParameters(Val Task) Export
	
	SetPrivilegedMode(True);
	Return JobQueue.GetJobs(New Structure("ID", Task))[0];
	
EndFunction

// It performs the queue job searching by the
// identifier (probably, saved in the infobase data).
//
// Parameters: Identifier - UUID
//
// Return value: CatalogRef.JobQueueDataAreas.
//
Function FindJob(Val ID) Export
	
	SetPrivilegedMode(True);
	
	Task = Catalogs.JobQueueDataAreas.GetRef(ID);
	If CommonUse.RefExists(Task) Then
		Return Task;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// It deletes a job of the job queue.
//
// Parameters:
// Task - CatalogRef.JobQueueDataAreas.
//
Procedure DeleteJob(Val Task) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(Task) = Type("CatalogRef.JobQueueDataAreas") Then
		JobQueue.DeleteJob(Task);
	EndIf;
	
EndProcedure
