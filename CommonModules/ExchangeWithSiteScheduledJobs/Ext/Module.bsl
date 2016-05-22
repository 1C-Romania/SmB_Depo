
// It creates a job of the job queue.
//
// Parameters
//  NodeCode - String - The NodeName
//  exchange plan node code - String - Schedule exchange
//  plan node name - JobSchedule - Schedule.
//
// Return value: UUID.
//
Function CreateNewJob(NodeCode, NodeName, Schedule) Export
	
	SetPrivilegedMode(True);
	
	Parameters = New Array;
	Parameters.Add(NodeCode);
	
	ScheduledJobID = Undefined;
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		
		Task = ScheduledJobs.CreateScheduledJob("ExchangeWithSite");
		Task.Use = True;
		Task.Key = String(New UUID);
		Task.Description = NodeName;
		Task.Parameters = Parameters;
		Task.Schedule = Schedule;
		Task.Write();
		
		ScheduledJobID = Task.UUID;
		
	Else
		
		JobParameters = New Structure();
		JobParameters.Insert("Use", True);
		JobParameters.Insert("MethodName" ,Metadata.ScheduledJobs.ExchangeWithSite.MethodName);
		JobParameters.Insert("Parameters" ,Parameters);
		JobParameters.Insert("Schedule",Schedule);
		
		Task = JobQueue.AddJob(JobParameters);
		ScheduledJobID = Task.UUID();
		
	EndIf;
	
	Return ScheduledJobID;
	
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

// Sets the background job parameters or jobs queue job.
//
// Parameters:
//  Task - CatalogRef.JobQueueDataAreas,
//  Use - Boolean, check box
//  of using the scheduled job, NodeCode - String - The NodeName
//  exchange plan node code - String - Schedule exchange
//  plan node name - ScheduledJobSchedule.
//
Procedure SetJobParameters(Task, Use, NodeCode, NodeName, Schedule) Export
	
	SetPrivilegedMode(True);
	
	Parameters = New Array;
	Parameters.Add(NodeCode);
	
	If TypeOf(Task) = Type("ScheduledJob") Then
		
		Task.Use = True;
		Task.Key = String(New UUID);
		Task.Description = NodeName;
		Task.Parameters = Parameters;
		Task.Schedule = Schedule;
		Task.Write();
		
	Else
		
		If Task = Undefined Then
			Return;
		EndIf;
		
		JobParameters = New Structure();
		JobParameters.Insert("Use", Use);
		JobParameters.Insert("MethodName", Metadata.ScheduledJobs.ExchangeWithSite.MethodName);
		JobParameters.Insert("Parameters", Parameters);
		JobParameters.Insert("Key", Metadata.ScheduledJobs.ExchangeWithSite.Key);
		JobParameters.Insert("Schedule", Schedule);
		
		JobQueue.ChangeTask(Task, JobParameters);
		
	EndIf;
	
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
// Return value: CatalogRef.JobQueueDataAreas, ScheduledJob.
//
Function FindJob(Val ID) Export
	
	SetPrivilegedMode(True);
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		
		Task = ScheduledJobs.FindByUUID(ID);
		Return Task;
		
	Else
		
		Task = Catalogs.JobQueueDataAreas.GetRef(ID);
		If CommonUse.RefExists(Task) Then
			Return Task;
		Else
			Return Undefined;
		EndIf;
		
	EndIf;
	
EndFunction

// Deletes the scheduled job or jobs queue job.
//
// Parameters:
// Task - ScheduledJob, CatalogRef.JobQueueDataAreas.
//
Procedure DeleteJob(Val Task) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(Task) = Type("ScheduledJob") Then
		Task.Delete();
	ElsIf TypeOf(Task) = Type("CatalogRef.JobQueueDataAreas") Then
		JobQueue.DeleteJob(Task);
	EndIf;
	
EndProcedure