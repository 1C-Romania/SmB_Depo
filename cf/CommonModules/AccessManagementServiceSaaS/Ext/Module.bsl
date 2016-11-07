///////////////////////////////////////////////////////////////////////////////////
// Subsystem "Access management in service model".
//
///////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
			"AccessManagementServiceSaaS");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\ListOfTemplatesOnGet"].Add(
				"AccessManagementServiceSaaS");
	EndIf;
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers[
			"ServiceTechnology.DataExportImport\AfterDataImportFromOtherMode"].Add(
				"AccessManagementServiceSaaS");
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
	
	Patterns.Add("DataFillingForAccessLimit");
	
EndProcedure

// Sets a flag in jobs queue for
// the use of the job that corresponds to a scheduled job for completion of access restriction data.
//
// Parameters:
//  Use - Boolean - new value of the usage check box.
//
Procedure SetDataFillingForAccessRestriction(Use) Export
	
	Pattern = JobQueue.TemplateByName("DataFillingForAccessLimit");
	
	JobFilter = New Structure;
	JobFilter.Insert("Pattern", Pattern);
	Jobs = JobQueue.GetJobs(JobFilter);
	
	JobParameters = New Structure("Use", Use);
	JobQueue.ChangeTask(Tasks[0].ID, JobParameters);
	
EndProcedure

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.0.4";
	Handler.Procedure = "AccessManagementServiceSaaS.UpdateAdministratorsAccessGroupsSaaS";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.SharedData = True;
	Handler.Procedure = "AccessManagementServiceSaaS.UpdateTemplateScheduleDataFillingForAccessRestriction";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// Transfers all users from access group "Data
// administrators" to access group Administrators.
//  Deletes profile "Data administrator" and access group "Data administrators".
// 
Procedure UpdateAdministratorsAccessGroupsSaaS() Export
	
	SetPrivilegedMode(True);
	
	ProfileDataAdministratorRef = Catalogs.AccessGroupsProfiles.GetRef(
		New UUID("f0254dd0-3558-4430-84c7-154c558ae1c9"));
		
	AccessGroupDataAdministratorsRef = Catalogs.AccessGroups.GetRef(
		New UUID("c7684994-34c9-4ddc-b31c-05b2d833e249"));
	
	Query = New Query;
	Query.SetParameter("ProfileDataAdministratorRef",        ProfileDataAdministratorRef);
	Query.SetParameter("AccessGroupDataAdministratorsRef", AccessGroupDataAdministratorsRef);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Ref = &AccessGroupDataAdministratorsRef
	|	AND AccessGroups.Profile = &ProfileDataAdministratorRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroupsProfiles AS AccessGroupsProfiles
	|WHERE
	|	AccessGroupsProfiles.Ref = &ProfileDataAdministratorRef";
	
	BeginTransaction();
	Try
		
		ResultsOfQuery = Query.ExecuteBatch();
		
		If Not ResultsOfQuery[0].IsEmpty() Then
			GroupAdministrators = Catalogs.AccessGroups.Administrators.GetObject();
			GroupAdministratorsData = AccessGroupDataAdministratorsRef.GetObject();
			
			If GroupAdministratorsData.Users.Count() > 0 Then
				For Each String IN GroupAdministratorsData.Users Do
					If GroupAdministrators.Users.Find(String.User, "User") = Undefined Then
						GroupAdministrators.Users.Add().User = String.User;
					EndIf;
				EndDo;
				InfobaseUpdate.WriteData(GroupAdministrators);
			EndIf;
			InfobaseUpdate.DeleteData(GroupAdministratorsData);
		EndIf;
		
		If Not ResultsOfQuery[1].IsEmpty() Then
			ProfileDataAdministrator = ProfileDataAdministratorRef.GetObject();
			InfobaseUpdate.DeleteData(ProfileDataAdministrator);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Updates settings of scheduled job.
Procedure UpdateTemplateScheduleDataFillingForAccessRestriction() Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	Pattern = JobQueue.TemplateByName("DataFillingForAccessLimit");
	TemplateObject = Pattern.GetObject();
	
	Schedule = New JobSchedule;
	Schedule.WeeksPeriod = 1;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.RepeatPeriodInDay = 300;
	Schedule.RepeatPause = 90;
	
	TemplateObject.Schedule = New ValueStorage(Schedule);
	TemplateObject.Write();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// It is called once data is imported
// from a local version to the service data area or vice versa.
//
Procedure AfterDataImportFromOtherMode() Export
	
	Catalogs.AccessGroupsProfiles.UpdateStandardProfiles(); 
	
EndProcedure

// Called when a message is processed http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetFullControl.
//
// Parameters:
//  DataAreaUser - CatalogRef.Users - user 
//   whose membership in Administrators group should be changed.
//  AccessPermitted - Boolean - True - include user
//   in the group, False - exclude user from the group.
//
Procedure SetUserIdentityToAdministratorsGroup(Val DataAreaUser, Val AccessPermitted) Export
	
	GroupAdministrators = Catalogs.AccessGroups.Administrators;
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.AccessGroups");
	LockItem.SetValue("Ref", GroupAdministrators);
	Block.Lock();
	
	ObjectGroup = GroupAdministrators.GetObject();
	
	UserRow = ObjectGroup.Users.Find(DataAreaUser, "User");
	
	If AccessPermitted AND UserRow = Undefined Then
		
		UserRow = ObjectGroup.Users.Add();
		UserRow.User = DataAreaUser;
		ObjectGroup.Write();
		
	ElsIf Not AccessPermitted AND UserRow <> Undefined Then
		
		ObjectGroup.Users.Delete(UserRow);
		ObjectGroup.Write();
	Else
		AccessManagement.UpdateUsersRoles(DataAreaUser);
	EndIf;
	
EndProcedure

#EndRegion
