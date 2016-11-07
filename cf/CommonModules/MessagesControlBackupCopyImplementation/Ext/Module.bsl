////////////////////////////////////////////////////////////////////////////////
// COMMON IMPLEMENTATION OF MANAGEMENT MESSAGE DATA PROCESSOR BY BACKUP
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// DataProcessor incoming messages with type {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}PlanZoneBackup.
//
// Parameters:
//  DataAreaCode - number(7,0),
//  BackupID - UUID,
//  BackupTimepoint - date (date and time),
//  Forced - a Boolean, flag forced backup creation.
//
Procedure PlanAreaBackupCreating(Val DataAreaCode,
		Val IDBackupCopies, Val TimeBackupCopies,
		Val Force) Export
	
	ExportParameters = DataAreasBackup.CreateBlankExportingParameters();
	ExportParameters.DataArea = DataAreaCode;
	ExportParameters.CopyID = IDBackupCopies;
	ExportParameters.StartedAt = ToLocalTime(TimeBackupCopies, // !Convert universal into local -
		// Local must be on the input in the queues.
		SaaSOperations.GetDataAreaTimeZone(DataAreaCode));
	ExportParameters.Force = Force;
	ExportParameters.OnDemand = False;
	
	DataAreasBackup.ScheduleArchivingQueue(ExportParameters);
	
EndProcedure

// DataProcessor incoming messages with type {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}CancelZoneBackup.
//
// Parameters:
//  DataAreaCode - number(7,0),
//  BackupID - UUID
//
Procedure CancelZoneBackupCreating(Val DataAreaCode, Val IDBackupCopies) Export
	
	CancellationParameters = New Structure("DataArea, CopyID", DataAreaCode, IDBackupCopies);
	DataAreasBackup.CancelZoneBackupCreating(CancellationParameters);
	
EndProcedure

// DataProcessor incoming messages
// with type {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}UpdateScheduledZoneBackupSettings.
//
// Parameters:
//  DataArea - Number - data area separator value.
//  Settings - Structure - new backup settings.
Procedure RefreshSettingsPeriodicBackup(Val DataArea, Val Settings) Export
	
	CreationParameters = New Structure;
	CreationParameters.Insert("CreateDaily");
	CreationParameters.Insert("CreateMonthly");
	CreationParameters.Insert("CreateAnnual");
	CreationParameters.Insert("OnlyWhenActiveUsers");
	CreationParameters.Insert("DayOfMonth");
	CreationParameters.Insert("MonthOfCreationAnnual");
	CreationParameters.Insert("DayOfAnnual");
	FillPropertyValues(CreationParameters, Settings);
	
	StateBuilding = New Structure;
	StateBuilding.Insert("CreationDateOfLastDaily");
	StateBuilding.Insert("CreationDateOfLastMonthly");
	StateBuilding.Insert("CreationDateOfLastAnnual");
	FillPropertyValues(StateBuilding, Settings);
	
	MethodParameters = New Array;
	MethodParameters.Add(New FixedStructure(CreationParameters));
	MethodParameters.Add(New FixedStructure(StateBuilding));
	
	Schedule = New JobSchedule;
	Schedule.BeginTime = Settings.BeginOfIntervalOfCopiesFormation;
	Schedule.EndTime = Settings.EndOfIntervalFormationCopies;
	Schedule.DaysRepeatPeriod = 1;
	
	JobParameters = New Structure;
	JobParameters.Insert("Parameters", MethodParameters);
	JobParameters.Insert("Schedule", Schedule);
	
	JobFilter = New Structure;
	JobFilter.Insert("DataArea", DataArea);
	JobFilter.Insert("MethodName", "DataAreasBackup.CopiesCreation");
	JobFilter.Insert("Key", "1");
	
	BeginTransaction();
	Try
		Jobs = JobQueue.GetJobs(JobFilter);
		If Jobs.Count() > 0 Then
			JobQueue.ChangeTask(Jobs[0].ID, JobParameters);
		Else
			JobParameters.Insert("DataArea", DataArea);
			JobParameters.Insert("MethodName", "DataAreasBackup.CopiesCreation");
			JobParameters.Insert("Key", "1");
			JobParameters.Insert("RestartCountOnFailure", 3);
			JobParameters.Insert("RestartIntervalOnFailure", 600); // 10 minutes
			JobQueue.AddJob(JobParameters);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// DataProcessor incoming messages with type {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}CancelScheduledZoneBackup.
//
// Parameters:
//  DataArea - Number - data area separator value.
Procedure CancelRecurringBackupCopy(Val DataArea) Export
	
	JobFilter = New Structure;
	JobFilter.Insert("DataArea", DataArea);
	JobFilter.Insert("MethodName", "DataAreasBackup.CopiesCreation");
	JobFilter.Insert("Key", "1");
	
	BeginTransaction();
	Try
		Jobs = JobQueue.GetJobs(JobFilter);
		If Jobs.Count() > 0 Then
			JobQueue.DeleteJob(Jobs[0].ID);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion
