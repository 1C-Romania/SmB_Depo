////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and data processors", procedures
// and functions for managing scheduled jobs.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Creates a new scheduled job in the infobase.
//
// Parameters:
//  Description - a string, scheduled job description.
//
// Return value: ScheduledJob.
//
Function CreateNewJob(Val Description) Export
	
	If CommonUseReUse.DataSeparationEnabled() AND
			CommonUse.SubsystemExists("ServiceTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsMaintenanceTasksSaaS = CommonUse.CommonModule("AdditionalReportsAndDataProcessorsScheduledJobsSaaS");
		Return ModuleAdditionalReportsAndDataProcessorsMaintenanceTasksSaaS.CreateNewJob();
	EndIf;
	
	Task = ScheduledJobs.CreateScheduledJob("LaunchAdditionalDataProcessors");
	Task.Use = False;
	Task.Description  = Description;
	Task.Write();
	
	Return Task;
	
EndFunction

// Returns the identifier of the scheduled job (to save data in the infobase).
//
// Task - ScheduledJob.
//
// Return value: UUID.
//
Function GetIDTasks(Val Task) Export
	
	If CommonUseReUse.DataSeparationEnabled() AND 
			CommonUse.SubsystemExists("ServiceTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsMaintenanceTasksSaaS = CommonUse.CommonModule("AdditionalReportsAndDataProcessorsScheduledJobsSaaS");
		Return ModuleAdditionalReportsAndDataProcessorsMaintenanceTasksSaaS.GetIDTasks(Task);
	EndIf;
	
	Return Task.UUID;
	
EndFunction

// Sets the parameters of a scheduled job.
//
// Parameters:
//  Task - ScheduledJob,
//  Usage - Boolean, flag showing
//  the usage of a scheduled job, Name - String, name of
//  a scheduled job, Parameters - Array(Arbitrary), scheduled
//  job parameters, Schedule - ScheduledJobSchedule.
//
Procedure SetJobParameters(Task, Use, Description, Parameters, Schedule) Export
	
	If CommonUseReUse.DataSeparationEnabled() AND
			CommonUse.SubsystemExists("ServiceTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsMaintenanceTasksSaaS = CommonUse.CommonModule("AdditionalReportsAndDataProcessorsScheduledJobsSaaS");
		ModuleAdditionalReportsAndDataProcessorsMaintenanceTasksSaaS.SetJobParameters(Task, Use, Parameters, Schedule);
		Return;
	EndIf;
	
	Task.Use = Use;
	Task.Description  = Description;
	Task.Parameters     = Parameters;
	Task.Schedule    = Schedule;
	
	Task.Write();
	
EndProcedure

// Returns scheduled job parameters.
//
// Parameters:
//  Task - ScheduledJob.
//
// Return value: Structure, keys:
//  Use - Boolean, flag showing
//  the usage of a scheduled job, Name - String, name of
//  a scheduled job, Parameters - Array(Arbitrary), scheduled
//  job parameters, Schedule - ScheduledJobSchedule.
//
Function GetJobParameters(Val Task) Export
	
	If CommonUseReUse.DataSeparationEnabled() AND
			CommonUse.SubsystemExists("ServiceTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsMaintenanceTasksSaaS = CommonUse.CommonModule("AdditionalReportsAndDataProcessorsScheduledJobsSaaS");
		Return ModuleAdditionalReportsAndDataProcessorsMaintenanceTasksSaaS.GetJobParameters(Task);
	EndIf;
	
	Result = New Structure();
	Result.Insert("Use", Task.Use);
	Result.Insert("Description", Task.Description);
	Result.Insert("Parameters", Task.Parameters);
	Result.Insert("Schedule", Task.Schedule);
	
	Return Result;
	
EndFunction

// Searches for a job by ID
// (presumably stored in the infobase data).
//
// Parameters: Identifier - UUID
//
// Return value: ScheduledJob.
//
Function FindJob(Val ID) Export
	
	If CommonUseReUse.DataSeparationEnabled()
			AND CommonUse.SubsystemExists("ServiceTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsMaintenanceTasksSaaS = CommonUse.CommonModule("AdditionalReportsAndDataProcessorsScheduledJobsSaaS");
		Return ModuleAdditionalReportsAndDataProcessorsMaintenanceTasksSaaS.FindJob(ID);
	EndIf;
	
	If Not ValueIsFilled(ID) Then
		Return Undefined;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Task = ScheduledJobs.FindByUUID(ID);
	
	Return Task;
	
EndFunction

// Deletes the scheduled job from the infobase.
//
// Parameters:
// Task - ScheduledJob.
//
Procedure DeleteJob(Val Task) Export
	
	If CommonUseReUse.DataSeparationEnabled() AND
			CommonUse.SubsystemExists("ServiceTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsMaintenanceTasksSaaS = CommonUse.CommonModule("AdditionalReportsAndDataProcessorsScheduledJobsSaaS");
		ModuleAdditionalReportsAndDataProcessorsMaintenanceTasksSaaS.DeleteJob(Task);
		Return;
	EndIf;
	
	If TypeOf(Task) = Type("ScheduledJob") Then
		Task.Delete();
	EndIf;
	
EndProcedure

#EndRegion
