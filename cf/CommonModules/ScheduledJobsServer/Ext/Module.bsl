////////////////////////////////////////////////////////////////////////////////
// "Scheduled jobs" subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns scheduled job usage.
//  Before calling it is required to have Administration right or SetPrivilegedMode.
//
// Parameters:
//  ID - MetadataObject - metadata object of scheduled job for predefined scheduled job search.    
//     - UUID           - scheduled  job ID.
//     - String         - scheduled job unique ID string.
//     - ScheduledJob   - scheduled job.
//
// Returns:
//  Boolean - If True the scheduled job is used.
// 
Function GetScheduledJobUse(Val ID) Export
	
	ScheduledJobsService.CallExceptionIfNoAdminPrivileges();
	SetPrivilegedMode(True);
	
	Task = GetScheduledJob(ID);
	
	Return Task.Use;
	
EndFunction

// Sets scheduled job usage.
//  Before calling it is required to have Administration right or SetPrivilegedMode.
//
// Parameters:
//  ID - MetadataObject - metadata object of scheduled job for predefined scheduled job search.
//     - UUID           - scheduled  job ID.
//     - String         - scheduled job unique ID string.
//     - ScheduledJob   - scheduled job.
//
// Use  - Boolean - usage value which is necessary to install.
// 
Procedure SetUseScheduledJob(Val ID, Val Use) Export
	
	ScheduledJobsService.CallExceptionIfNoAdminPrivileges();
	SetPrivilegedMode(True);
	
	Task = GetScheduledJob(ID);
	
	If Task.Use <> Use Then
		Task.Use = Use;
	EndIf;
	
	Task.Write();
	
EndProcedure

// Returns scheduled job schedule.
//  Before calling it is required to have Administration right or SetPrivilegedMode.
// 
// Parameters:
//  ID - MetadataObject - metadata object of scheduled job
//                        for predefined scheduled job search.
//     - UUID           - scheduled  job ID.
//     - String         - scheduled job unique ID string.
//     - ScheduledJob   - scheduled job.
// 
//  InStructure         - Boolean - If True then the schedule
//                        will be converted into a structure which you can pass on the client.
// 
// Returns:
//  ScheduledJobSchedule, Structure - structure contains the same properties as schedule.
// 
Function GetJobSchedule(Val ID, Val InStructure = False) Export
	
	ScheduledJobsService.CallExceptionIfNoAdminPrivileges();
	SetPrivilegedMode(True);
	
	Task = GetScheduledJob(ID);
	
	If InStructure Then
		Return CommonUseClientServer.ScheduleIntoStructure(Task.Schedule);
	EndIf;
	
	Return Task.Schedule;
	
EndFunction

// Sets scheduled job schedule.
//  Before calling it is required to have Administration right or SetPrivilegedMode.
//
// Parameters:
//  ID - MetadataObject - metadata object of scheduled job
//                        for predefined scheduled job search.
//     - UUID           - scheduled  job ID.
//     - String         - scheduled job unique ID string.
//     - ScheduledJob   - scheduled job.
//
//  Schedule      - JobSchedule - schedule.
//                - Structure   - returned value by
//                  function ScheduleIntoStructure common module CommonUseClientServer.
// 
Procedure SetJobSchedule(Val ID, Val Schedule) Export
	
	ScheduledJobsService.CallExceptionIfNoAdminPrivileges();
	SetPrivilegedMode(True);
	
	Task = GetScheduledJob(ID);
	
	If TypeOf(Schedule) = Type("JobSchedule") Then
		Task.Schedule = Schedule;
	Else
		Task.Schedule = CommonUseClientServer.StructureIntoSchedule(Schedule);
	EndIf;
	
	Task.Write();
	
EndProcedure

// Returns ScheduledJob from infobase.
// 
// Parameters:
//  ID - MetadataObject - metadata object of scheduled job
//                        for predefined scheduled job search.
//     - UUID           - scheduled  job ID.
//     - String         - scheduled job unique ID string.
//     - ScheduledJob   - scheduled job from
//                        which need to get unique identifier for get fresh copy of scheduled job.
// 
// Returns:
//  ScheduledJob - it is read from database.
//
Function GetScheduledJob(Val ID) Export
	
	ScheduledJobsService.CallExceptionIfNoAdminPrivileges();
	SetPrivilegedMode(True);
	
	If TypeOf(ID) = Type("ScheduledJob") Then
		ID = ID.UUID;
	EndIf;
	
	If TypeOf(ID) = Type("String") Then
		ID = New UUID(ID);
	EndIf;
	
	If TypeOf(ID) = Type("MetadataObject") Then
		ScheduledJob = ScheduledJobs.FindPredefined(ID);
	Else
		ScheduledJob = ScheduledJobs.FindByUUID(ID);
	EndIf;
	
	If ScheduledJob = Undefined Then
		Raise( NStr("en='Scheduled job is not found.
		|Perhaps, it has been deleted by another user.';ru='Регламентное задание не найдено.
		|Возможно, оно удалено другим пользователем.'") );
	EndIf;
	
	Return ScheduledJob;
	
EndFunction

#EndRegion
