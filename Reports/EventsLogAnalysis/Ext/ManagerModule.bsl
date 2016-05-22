#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Placement settings in the report panel.
//
// Parameters:
//   Settings - Collection - Used for the description of report
//       settings and variants, see description to ReportsVariants.ConfigurationReportVariantsSettingTree().
//   ReportSettings - ValueTreeRow - Placement settings of all report variants.
//      See "Attributes for change" of the ReportsVariants function.ConfigurationReportVariantsSetupTree().
//
// Definition:
//  See ReportsVariantsOverridable.SetReportsVariants().
//
// Auxiliary methods:
//   VariantSettings = ReportsVariants.VariantDesc(Settings, ReportSettings, "<VariantName>");
//   ReportsVariants.SetOutputModeInReportPanels
//   False (Settings, ReportSettings,True/False); Repor//t supports only this mode.
//
Procedure ConfigureReportsVariants(Settings, ReportSettings) Export
	ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
	ModuleReportsVariants.SetOutputModeInReportPanels(Settings, ReportSettings, False);
	
	VariantSettings = ModuleReportsVariants.VariantDesc(Settings, ReportSettings, "UsersActivityAnalysis");
	VariantSettings.Definition = 
		NStr("en = 'It allows to monitor
		|users activity in the application (how intense and with which objects users work).'");
	
	VariantSettings = ModuleReportsVariants.VariantDesc(Settings, ReportSettings, "ActiveUser");
	VariantSettings.Definition = 
		NStr("en = 'Detailed information
		|about the objects with which the user worked in the application.'");
	
	VariantSettings = ModuleReportsVariants.VariantDesc(Settings, ReportSettings, "EventLogMonitorControl");
	VariantSettings.Definition = NStr("en = 'List of critical records in the events log monitor.'");
	VariantSettings.SearchSettings.TemplateNames = "ErrorsReportTemplateInEventLogMonitor";
	
	VariantSettings = ModuleReportsVariants.VariantDesc(Settings, ReportSettings, "ScheduledJobsWorkDuration");
	VariantSettings.Definition = NStr("en = 'Outputs schedule of scheduled jobs execution in the application.'");
	VariantSettings.SearchSettings.TemplateNames = "ScheduledJobsWorkDuration, ScheduledJobDetails";
EndProcedure

#EndRegion

#Region ProgramInterface

// The function receives information on the users activity
// from the events log monitor by the passed period.
//
// Parameters:
// ReportParameters - structure - parameters set for report generation:
// 	StartDate    - Date - period start according to which information will be collected.
// 	EndDate - Date - period end according to which information will be collected.
// 	User  - user name according to which analysis will be executed. Two options
//                 of the "Users activity" report.
// 	UsersAndGroups - users group(s) and(or) user(s) according	to which analysis is executed.
// 			   Two options of the "Users activity analysis" report.
// 	ReportVariant - String - "UsersActivity" or "UsersActivityAnalysis".
// 	OutputBusinessProcesses - Boolean - whether to receive or not information on business processes from the events log monitor.
// 	OutputTasks - Boolean - whether to receive or not information on jobs from the events log monitor.
// 	OutputCatalogs - Boolean - whether to receive or not information on catalogs from the events log monitor.
// 	OutputDocuments - Boolean - whether to receive or not documents information from the events log monitor.
//
// Return
// value values table - table containing not grouped information by
// 				the users activity from the events log monitor.
//
Function DataFromEventLog(ReportParameters) Export
	
	// Prepare report parameters.
	StartDate = ReportParameters.StartDate;
	EndDate = ReportParameters.EndDate;
	User = ReportParameters.User;
	UsersAndGroups = ReportParameters.UsersAndGroups;
	ReportVariant = ReportParameters.ReportVariant;
	
	If ReportVariant = "ActiveUser" Then
		OutputBusinessProcesses = ReportParameters.OutputBusinessProcesses;
		OutputTasks = ReportParameters.OutputTasks;
		OutputCatalogs = ReportParameters.OutputCatalogs;
		OutputDocuments = ReportParameters.OutputDocuments;
	Else
		OutputCatalogs = True;
		OutputDocuments = True;
		OutputBusinessProcesses = False;
		OutputTasks = False;
	EndIf;
	
	// Generate source data table.
	SourceData = New ValueTable();
	SourceData.Columns.Add("Date", New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	SourceData.Columns.Add("Week", New TypeDescription("String", , New StringQualifiers(10)));
	SourceData.Columns.Add("User");
	SourceData.Columns.Add("WorkingHours", New TypeDescription("Number", New NumberQualifiers(15,2)));
	SourceData.Columns.Add("StartsCount", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("DocumentsCreated", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("CatalogsCreated", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("DocumentsChanged", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("CreatedBusinessProcesses",	New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("TasksCreated", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("BusinessProcessesChanged", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("TasksChanged", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("CatalogsChanged",	New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("errors", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("Warnings", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("ObjectKind", New TypeDescription("String", , New StringQualifiers(50)));
	SourceData.Columns.Add("ObjectCatalogDocument");
	
	// Calculate the max number of concurrent sessions.
	ConcurrentSessions = New ValueTable();
	ConcurrentSessions.Columns.Add("UsersWorkingSimultaneouslyDate",
		New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	ConcurrentSessions.Columns.Add("UsersWorkingSimultaneously",
		New TypeDescription("Number", New NumberQualifiers(10)));
	ConcurrentSessions.Columns.Add("UsersWorkingSimultaneouslyList");
	
	DataEventLog = New ValueTable;
	
	Levels = New Array;
	Levels.Add(EventLogLevel.Information);
	
	Events = New Array;
	Events.Add("_$Session$_.Start"); //  Session start
	Events.Add("_$Session$_.Finish"); //  Session end  
	Events.Add("_$Data$_.New"); // Add data
	Events.Add("_$Data$_.Update"); // Change data
	
	ApplicationName = New Array;
	ApplicationName.Add("1CV8C");
	ApplicationName.Add("WebClient"); // SB
	ApplicationName.Add("1CV8"); // SB
	
	UserFilter = New Array;
	
	// Get users list.
	If ReportVariant = "ActiveUser" Then
		UserFilter.Add(IBUserName(User));
	ElsIf TypeOf(UsersAndGroups) = Type("ValueList") Then
		
		For Each Item IN UsersAndGroups Do
			UsersForAnalysis(UserFilter, Item.Value);
		EndDo;
		
	Else
		UsersForAnalysis(UserFilter, UsersAndGroups);
	EndIf;
	
	EventLogMonitorFilter = New Structure("StartDate, EndDate, ApplicationName, Level, Event",
											StartDate,
											EndDate,
											ApplicationName,
											Levels,
											Events);
	
	If UserFilter.Count() = 0 Then
		Return New Structure("UsersActivityAnalysis, ConcurrentSessions", SourceData, ConcurrentSessions);
	EndIf;
	
	If UserFilter.Find("AllUsers") = Undefined Then
		EventLogMonitorFilter.Insert("User", UserFilter);
	EndIf;
	
	SetPrivilegedMode(True);
	UnloadEventLog(DataEventLog, EventLogMonitorFilter);
	SetPrivilegedMode(False);

	DataEventLog.Sort("Session, Date");
	
	// Add match UUID-UserRef for further use.
	UserIDs = DataEventLog.UnloadColumn("User");
	MapUsersIDs = UniqueUsersIDs(UserIDs);
	
	CurrentSession        = Undefined;
	WorkingHours         = 0;
	StartsCount  = 0;
	DocumentsCreated   = 0;
	CatalogsCreated = 0;
	DocumentsChanged  = 0;
	CatalogsChanged= 0;
	ObjectKind          = Undefined;
	StringSourceData= Undefined;
	SessionStarted        = Undefined;
	
	// Calculate data required to make a report.
	For Each DataRowEventLog IN DataEventLog Do
		If DataRowEventLog.UserName = "" Then
			Continue;
		EndIf;
		Session = DataRowEventLog.Session; 
		
		If Not ValueIsFilled(DataRowEventLog.Session)
			Or Not ValueIsFilled(DataRowEventLog.Date) Then
			Continue;
		EndIf;
		
		UserNameRef = MapUsersIDs[DataRowEventLog.User];
		
		// Calculate users work duration and application starts quantity.
		If CurrentSession <> Session
			Or DataRowEventLog.Event = "_$Session$_.Start" Then
			If StringSourceData <> Undefined Then
				StringSourceData.WorkingHours  = WorkingHours;
				StringSourceData.StartsCount = StartsCount;
			EndIf;
			StringSourceData = SourceData.Add();
			StringSourceData.Date		  = DataRowEventLog.Date;
			StringSourceData.Week 	  = RowWeekOfYear(DataRowEventLog.Date);
			StringSourceData.User = UserNameRef;
			WorkingHours			= 0;
			StartsCount	= 0; 
			CurrentSession			= Session; 
			SessionStarted		= DataRowEventLog.Date;
		EndIf;
		
		If DataRowEventLog.Event = "_$Session$_.Finish" Then
			
			StartsCount	= StartsCount + 1;
			If SessionStarted <> Undefined Then 
				
				// Check whether user session is over in the same day or the next one.
				If BegOfDay(DataRowEventLog.Date) > BegOfDay(SessionStarted) Then
					// If the session end took place the next day, fill in work hours for the previous day.
					Diff = EndOfDay(SessionStarted) - SessionStarted;
					WorkingHours = Diff/60/60;
					StringSourceData.WorkingHours = WorkingHours;
					DaySession = EndOfDay(SessionStarted) + 86400;
					While EndOfDay(DataRowEventLog.Date) > DaySession Do
						StringSourceData = SourceData.Add();
						StringSourceData.Date = DaySession;
						StringSourceData.Week 	  = RowWeekOfYear(DataRowEventLog.Date);
						StringSourceData.User = UserNameRef;
						WorkingHours = (DaySession - BegOfDay(DaySession))/60/60;
						StringSourceData.WorkingHours  = WorkingHours;
						DaySession = DaySession + 86400;
					EndDo;	
					StringSourceData = SourceData.Add();
					StringSourceData.Date = DataRowEventLog.Date;
					StringSourceData.Week 	  = RowWeekOfYear(DataRowEventLog.Date);
					StringSourceData.User = UserNameRef;
					WorkingHours = (DataRowEventLog.Date - BegOfDay(DaySession))/60/60;
					StringSourceData.WorkingHours  = WorkingHours;
				Else
					Diff =  (DataRowEventLog.Date - SessionStarted)/60/60;
					WorkingHours = WorkingHours + Diff;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		// Calculate the number of created documents and catalogs.
		If DataRowEventLog.Event = "_$Data$_.New" Then
			
			If Find(DataRowEventLog.Metadata, "Document.") > 0 
				AND OutputDocuments Then
				ObjectKind = DataRowEventLog.MetadataPresentation;
				ObjectCatalogDocument = DataRowEventLog.Data;
				DocumentsCreated = DocumentsCreated + 1;
				StringSourceData = SourceData.Add();
				StringSourceData.Date		  = DataRowEventLog.Date;
				StringSourceData.User = UserNameRef;
				StringSourceData.ObjectKind = ObjectKind;
				StringSourceData.DocumentsCreated = DocumentsCreated;
				StringSourceData.ObjectCatalogDocument = ObjectCatalogDocument;
				StringSourceData.Week 	  = RowWeekOfYear(DataRowEventLog.Date); 
			EndIf;
			
			If Find(DataRowEventLog.Metadata, "Catalog.") > 0
				AND OutputCatalogs Then
				ObjectKind = DataRowEventLog.MetadataPresentation;
				ObjectCatalogDocument = DataRowEventLog.Data;
				CatalogsCreated = CatalogsCreated + 1;
				StringSourceData = SourceData.Add();
				StringSourceData.Date		  = DataRowEventLog.Date;
				StringSourceData.User = UserNameRef;
				StringSourceData.ObjectKind = ObjectKind;
				StringSourceData.CatalogsCreated = CatalogsCreated;
				StringSourceData.ObjectCatalogDocument = ObjectCatalogDocument;
				StringSourceData.Week 	  = RowWeekOfYear(DataRowEventLog.Date);
			EndIf;
			
		EndIf;
		
		// Calculate the number of changed documents and catalogs.
		If DataRowEventLog.Event = "_$Data$_.Update" Then
			
			If Find(DataRowEventLog.Metadata, "Document.") > 0
				AND OutputDocuments Then
				ObjectKind = DataRowEventLog.MetadataPresentation;
				ObjectCatalogDocument = DataRowEventLog.Data;
				DocumentsChanged = DocumentsChanged + 1;
				StringSourceData = SourceData.Add();
				StringSourceData.Date		  = DataRowEventLog.Date;
				StringSourceData.User = UserNameRef;
				StringSourceData.DocumentsChanged = DocumentsChanged;  	
				StringSourceData.ObjectKind = ObjectKind;
				StringSourceData.ObjectCatalogDocument = ObjectCatalogDocument;
				StringSourceData.Week 	  = RowWeekOfYear(DataRowEventLog.Date);
			EndIf;
			
			If Find(DataRowEventLog.Metadata, "Catalog.") > 0
				AND OutputCatalogs Then
				ObjectKind = DataRowEventLog.MetadataPresentation;
				ObjectCatalogDocument = DataRowEventLog.Data;
				CatalogsChanged = CatalogsChanged + 1;
				StringSourceData = SourceData.Add();
				StringSourceData.Date		  = DataRowEventLog.Date;
				StringSourceData.User = UserNameRef;
				StringSourceData.CatalogsChanged = CatalogsChanged;
				StringSourceData.ObjectKind = ObjectKind;
				StringSourceData.ObjectCatalogDocument = ObjectCatalogDocument;
				StringSourceData.Week 	  = RowWeekOfYear(DataRowEventLog.Date);
			EndIf;
			
		EndIf;
		
		// Calculate the number of created BusinessProcesses and Jobs.
		If DataRowEventLog.Event = "_$Data$_.New" Then
			
			If Find(DataRowEventLog.Metadata, "BusinessProcess.") > 0 
				AND OutputBusinessProcesses Then
				ObjectKind = DataRowEventLog.MetadataPresentation;
				ObjectCatalogDocument = DataRowEventLog.Data;
				CreatedBusinessProcesses = CreatedBusinessProcesses + 1;
				StringSourceData = SourceData.Add();
				StringSourceData.Date		  = DataRowEventLog.Date;
				StringSourceData.User = UserNameRef;
				StringSourceData.ObjectKind = ObjectKind;
				StringSourceData.CreatedBusinessProcesses = CreatedBusinessProcesses;
				StringSourceData.ObjectCatalogDocument = ObjectCatalogDocument;
				StringSourceData.Week 	  = RowWeekOfYear(DataRowEventLog.Date); 
			EndIf;
			
			If Find(DataRowEventLog.Metadata, "Task.") > 0 
				AND OutputTasks Then
				ObjectKind = DataRowEventLog.MetadataPresentation;
				ObjectCatalogDocument = DataRowEventLog.Data;
				TasksCreated = TasksCreated + 1;
				StringSourceData = SourceData.Add();
				StringSourceData.Date		  = DataRowEventLog.Date;
				StringSourceData.User = UserNameRef;
				StringSourceData.ObjectKind = ObjectKind;
				StringSourceData.TasksCreated = TasksCreated;
				StringSourceData.ObjectCatalogDocument = ObjectCatalogDocument;
				StringSourceData.Week 	  = RowWeekOfYear(DataRowEventLog.Date);
			EndIf;
			
		EndIf;
		
		// Calculate the number of changed BusinessProcesses and Jobs.
		If DataRowEventLog.Event = "_$Data$_.Update" Then
			
			If Find(DataRowEventLog.Metadata, "BusinessProcess.") > 0
				AND OutputBusinessProcesses Then
				ObjectKind = DataRowEventLog.MetadataPresentation;
				ObjectCatalogDocument = DataRowEventLog.Data;
				BusinessProcessesChanged = BusinessProcessesChanged + 1;
				StringSourceData = SourceData.Add();
				StringSourceData.Date		  = DataRowEventLog.Date;
				StringSourceData.User = UserNameRef;
				StringSourceData.ObjectKind = ObjectKind;
				StringSourceData.BusinessProcessesChanged = BusinessProcessesChanged;
				StringSourceData.ObjectCatalogDocument = ObjectCatalogDocument;
				StringSourceData.Week 	  = RowWeekOfYear(DataRowEventLog.Date);
			EndIf;
			
			If Find(DataRowEventLog.Metadata, "Task.") > 0 
				AND OutputTasks Then
				ObjectKind = DataRowEventLog.MetadataPresentation;
				ObjectCatalogDocument = DataRowEventLog.Data;
				TasksChanged = TasksChanged + 1;
				StringSourceData = SourceData.Add();
				StringSourceData.Date		  = DataRowEventLog.Date;
				StringSourceData.User = UserNameRef;
				StringSourceData.ObjectKind = ObjectKind;
				StringSourceData.TasksChanged = TasksChanged;
				StringSourceData.ObjectCatalogDocument = ObjectCatalogDocument;
				StringSourceData.Week 	  = RowWeekOfYear(DataRowEventLog.Date);
			EndIf;
			
		EndIf;
		
		DocumentsCreated       = 0;
		CatalogsCreated     = 0;
		DocumentsChanged      = 0;
		CatalogsChanged    = 0;
		CreatedBusinessProcesses  = 0;
		BusinessProcessesChanged = 0;
		TasksChanged           = 0;
		TasksCreated            = 0;
		ObjectKind              = Undefined;
		
	EndDo; 
	
	If StringSourceData <> Undefined Then
		StringSourceData.WorkingHours  = WorkingHours;
		StringSourceData.StartsCount = StartsCount;
	EndIf;
	
	If ReportVariant = "UsersActivityAnalysis" Then
	
		DataEventLog.Sort("Date");
		
		UserArray 	= New Array;
		MaxUserArray = New Array;
		UsersWorkingSimultaneously  = 0;
		Counter                 = 0;
		CurrentDate             = Undefined;
		TableRow           = Undefined;
		
		For Each DataRowEventLog IN DataEventLog Do
			
			If Not ValueIsFilled(DataRowEventLog.Date)
				Or DataRowEventLog.UserName = "" Then
				Continue;
			EndIf;
			
			UserNameRef = MapUsersIDs[DataRowEventLog.User];
			If UserNameRef = Undefined Then
				Continue;
			EndIf;
			
			UserNameString = IBUserName(UserNameRef);
			
			UsersWorkingSimultaneouslyDate = BegOfDay(DataRowEventLog.Date);
			
			// If you change the day, reset all data on concurrent sessions and fill in data for the previous day.
			If CurrentDate <> UsersWorkingSimultaneouslyDate Then
				If UsersWorkingSimultaneously <> 0 Then
					GenerateStringConcurrentSessions(ConcurrentSessions, MaxUserArray, 
						UsersWorkingSimultaneously, CurrentDate);
				EndIf;
				UsersWorkingSimultaneously = 0;
				Counter    = 0;
				UserArray.Clear();
				CurrentDate = UsersWorkingSimultaneouslyDate;
			EndIf;
			
			If DataRowEventLog.Event = "_$Session$_.Start" Then
				Counter = Counter + 1;
				UserArray.Add(UserNameString);
			ElsIf DataRowEventLog.Event = "_$Session$_.Finish" Then
				IndexOfUser = UserArray.Find(UserNameString);
				If Not IndexOfUser = Undefined Then 
					UserArray.Delete(IndexOfUser);
					Counter = Counter - 1;
				EndIf;
			EndIf;
			
			// Check counter value and compare it with the max value.
			Counter = Max(Counter, 0);
			If Counter > UsersWorkingSimultaneously Then
				MaxUserArray = New Array;
				For Each Item IN UserArray Do
					MaxUserArray.Add(Item);
				EndDo;
			EndIf;
			UsersWorkingSimultaneously = Max(UsersWorkingSimultaneously, Counter);
			
		EndDo;
		
		If UsersWorkingSimultaneously <> 0 Then
			GenerateStringConcurrentSessions(ConcurrentSessions, MaxUserArray, 
				UsersWorkingSimultaneously, CurrentDate);
		EndIf;
		
		// Calculate the number of errors and warnings.
		DataEventLog = Undefined;
		errors 					 = 0;
		Warnings			 = 0;
		DataEventLog = BugEventLogInformation(StartDate, EndDate);
		
		For Each DataRowEventLog IN DataEventLog Do
			
			If DataRowEventLog.UserName = "" Then
				Continue;
			EndIf;
			
			If UserFilter.Find(DataRowEventLog.UserName) = Undefined
				AND UserFilter.Count() <> 0 Then
				Continue;
			EndIf;
			
			UserNameRef = MapUsersIDs[DataRowEventLog.User];
			
			If DataRowEventLog.Level = EventLogLevel.Error Then
				errors = errors + 1;
				StringSourceData = SourceData.Add();
				StringSourceData.Date = DataRowEventLog.Date;
				StringSourceData.Week 	  = RowWeekOfYear(DataRowEventLog.Date);
				StringSourceData.User = UserNameRef;
				StringSourceData.errors = errors;
			EndIf;
			
			If DataRowEventLog.Level = EventLogLevel.Warning Then
				Warnings = Warnings + 1;
				StringSourceData = SourceData.Add();
				StringSourceData.Date = DataRowEventLog.Date;
				StringSourceData.Week 	  = RowWeekOfYear(DataRowEventLog.Date);
				StringSourceData.User = UserNameRef;
				StringSourceData.Warnings = Warnings;
			EndIf;
			
			errors         = 0;
			Warnings = 0;
		EndDo;
		
	EndIf;
	
	Return New Structure("UsersActivityAnalysis, ConcurrentSessions", SourceData, ConcurrentSessions);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure of the report generation.
//
// Parameters:
// ReportParameters - structure - parameters set required to make a report.
// 	StorageAddress - temporary storage address.
Procedure Generate(ReportParameters, StorageAddress) Export
	Result = New Structure;
	DetailsDataObject = New DataCompositionDetailsData;
	ResultDocument = New SpreadsheetDocument;
	ReportObject = Reports.EventsLogAnalysis.Create();
	
	ReportObject.SettingsComposer.LoadSettings(ReportParameters.Settings);
	ReportObject.SettingsComposer.LoadUserSettings(ReportParameters.UserSettings);
	ReportObject.SettingsComposer.LoadFixedSettings(ReportParameters.FixedSettings);
	ReportObject.ComposeResult(ResultDocument, DetailsDataObject);
	DetailsData = PutToTempStorage(DetailsDataObject, ReportParameters.AddressDecoding);
	
	PutToTempStorage(New Structure("Result, DetailsData", 
									ResultDocument, DetailsData), StorageAddress);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Users activity analysis.

Function UsersForAnalysis(UserFilter, Item)
	
	If TypeOf(Item) = Type("CatalogRef.Users") Then
		IBUserName = IBUserName(Item);
		
		If IBUserName <> Undefined Then
			UserFilter.Add(IBUserName);
		EndIf;
		
	ElsIf TypeOf(Item) = Type("CatalogRef.UsersGroups") Then
		
		AllUsers = Catalogs.UsersGroups.AllUsers;
		If Item = AllUsers Then
			UserFilter.Add("AllUsers");
			Return UserFilter;
		EndIf;
		
		For Each GroupsUser IN Item.Content Do
			IBUserName = IBUserName(GroupsUser.User);
			
			If IBUserName <> Undefined Then
				UserFilter.Add(IBUserName);
			EndIf;
		
		EndDo;
		
	EndIf;
	
	Return UserFilter;
EndFunction

Function UniqueUsersIDs(UserIDs)
	ArrayIdentifiersAreUniqueUsers = New Array;
	
	CommonUse.FillArrayWithUniqueValues(ArrayIdentifiersAreUniqueUsers,
															UserIDs);
	MapUID = New Map;
	For Each Item IN ArrayIdentifiersAreUniqueUsers Do
		
		If ValueIsFilled(Item) Then
			UserNameRef = UserRef(Item);
			InfobaseUserID = CommonUse.ObjectAttributeValue(UserNameRef, "InfobaseUserID");
			
			If InfobaseUserID <> Undefined Then
				MapUID.Insert(Item, UserNameRef);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return MapUID;
EndFunction

Function UserRef(UserUID)
	Return Catalogs.Users.FindByAttribute("InfobaseUserID", UserUID);
EndFunction

Function IBUserName(UserRef) Export
	SetPrivilegedMode(True);
	InfobaseUserID = CommonUse.ObjectAttributeValue(UserRef, "InfobaseUserID");
	IBUser = InfobaseUsers.FindByUUID(InfobaseUserID);
	
	If IBUser <> Undefined Then
		Return IBUser.Name; 
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function RowWeekOfYear(DateOfYear)
	Return StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Week %1'"), WeekOfYear(DateOfYear));
EndFunction

Procedure GenerateStringConcurrentSessions(ConcurrentSessions, MaxUserArray,
			UsersWorkingSimultaneously, CurrentDate)
	
	TemporaryArray = New Array;
	IndexOf = 0;
	For Each Item IN MaxUserArray Do
		TemporaryArray.Insert(IndexOf, Item);
		CounterNumberOfSessionsUser = 0;
		
		For Each UserName IN TemporaryArray Do
			If UserName = Item Then
				CounterNumberOfSessionsUser = CounterNumberOfSessionsUser + 1;
				UserAndNumber = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = '%1 (%2)'"), Item, CounterNumberOfSessionsUser);
			EndIf;
		EndDo;
		
		TableRow = ConcurrentSessions.Add();
		TableRow.UsersWorkingSimultaneouslyDate = CurrentDate;
		TableRow.UsersWorkingSimultaneously = UsersWorkingSimultaneously;
		TableRow.UsersWorkingSimultaneouslyList = UserAndNumber;
		IndexOf = IndexOf + 1;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Scheduled jobs work duration.

// Function generates report on scheduled jobs work.
//
// Parameters:
// FillingParameters - structure - parameters set required to make a report:
// 	StartDate    - Date - period start according to which information will be collected.
// 	EndDate - Date - period end according to which information will be collected.
// 	SizeConcurrentSessions	- Number - min number of concurrent
// 		scheduled jobs to display in the table.
// 	ScheduledJobsSessionsMinimumLength - Number - min
// 		duration of scheduled job sessions in seconds.
// 	ShowBackgroundJobs - Boolean - if true, then string with background job session intervals will be displayed in the Gantt chart.
// 	TitleOutput - DataCompositionTextOutputType - designed to disable/enable title.
// 	FilterOutput - DataCompositionTextOutputType - designed to disable/enable filter display.
// 	HideSceduledJobs - ValueList - scheduled jobs list that are required to exclude from the report.
//
Function GenerateReportForDurationJobsOfScheduledJobs(FillingParameters) Export
	
	// Report parameters
	StartDate = FillingParameters.StartDate;
	EndDate = FillingParameters.EndDate;
	SizeConcurrentSessions = FillingParameters.SizeConcurrentSessions;
	ScheduledJobsSessionsMinimumLength = 
		FillingParameters.ScheduledJobsSessionsMinimumLength;
	ShowBackgroundJobs = FillingParameters.ShowBackgroundJobs;
	TitleOutput = FillingParameters.TitleOutput;
	FilterOutput = FillingParameters.FilterOutput;
	ReportHeader = FillingParameters.ReportHeader;
	HideSceduledJobs = FillingParameters.HideSceduledJobs;
	
	Result = New Structure;
	Report = New SpreadsheetDocument;
	
	// Receive data to make a report.
	GetData = DataForReportOnDurationOfWorkScheduledJobs(FillingParameters);
	TableSessionsRoutineMaintenanceJobs = GetData.TableSessionsRoutineMaintenanceJobs;
	ConcurrentSessions = GetData.TotalAmountAtSameTimeRoutineMaintenanceJobs;
	StartsCount = GetData.StartsCount;
	Template = Reports.EventsLogAnalysis.GetTemplate("ScheduledJobsWorkDuration");
	
	// Colors set for chart and table background.
	ColorOfBackground = New Array;
	ColorOfBackground.Add(WebColors.White);
	ColorOfBackground.Add(WebColors.LightYellow);
	ColorOfBackground.Add(WebColors.LemonChiffon);
	ColorOfBackground.Add(WebColors.NavajoWhite);
	
	// Generate report header.
	If TitleOutput.Value = DataCompositionTextOutputType.Output
		AND TitleOutput.Use
		OR Not TitleOutput.Use Then
		Report.Put(Template.GetArea("HeaderReport"));
	EndIf;
	
	If FilterOutput.Value = DataCompositionTextOutputType.Output
		AND FilterOutput.Use
		Or Not FilterOutput.Use Then
		Area = Template.GetArea("Filter");
		If ScheduledJobsSessionsMinimumLength > 0 Then
			DisplayModeIntervals = NStr("en = 'Disabled'");
		Else
			DisplayModeIntervals = NStr("en = 'Enabled'");
		EndIf;
		Area.Parameters.StartDate = StartDate;
		Area.Parameters.EndDate = EndDate;
		Area.Parameters.DisplayModeIntervals = DisplayModeIntervals;
		Report.Put(Area);
	EndIf;
	
	If ValueIsFilled(ConcurrentSessions) Then
	
		Report.Put(Template.GetArea("TableHeader"));
		
		// Generate table of the maximum number of simultaneously started SJ.
		CurrentCountOfSessions = 0; 
		IndexColor = 3;
		For Each StringConcurrentSessions IN ConcurrentSessions Do
			Area = Template.GetArea("Table");
			If CurrentCountOfSessions <> 0 
				AND CurrentCountOfSessions <> StringConcurrentSessions.AmountAtSameTimeRoutineMaintenanceJobs
				AND IndexColor <> 0 Then
				IndexColor = IndexColor - 1;
			EndIf;
			If StringConcurrentSessions.AmountAtSameTimeRoutineMaintenanceJobs = 1 Then
				IndexColor = 0;
			EndIf;
			Area.Parameters.Fill(StringConcurrentSessions);
			BackColorTables = ColorOfBackground.Get(IndexColor);
			Area.Areas.Table.BackColor = BackColorTables;
			Report.Put(Area);
			CurrentCountOfSessions = StringConcurrentSessions.AmountAtSameTimeRoutineMaintenanceJobs;
			ArrayRoutineMaintenanceJobs = StringConcurrentSessions.ScheduledJobList;
			IndexOfScheduledJobs = 0;
			Report.StartRowGroup(, False);
			For Each Item IN ArrayRoutineMaintenanceJobs Do
				If Not TypeOf(Item) = Type("Number")
					AND Not TypeOf(Item) = Type("Date") Then
					Area = Template.GetArea("ScheduledJobList");
					Area.Parameters.ScheduledJobList = StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en = '%1 (session %2)'"), Item, ArrayRoutineMaintenanceJobs.Get(IndexOfScheduledJobs+1));
				ElsIf Not TypeOf(Item) = Type("Date")
					AND Not TypeOf(Item) = Type("String") Then	
					Area.Parameters.DetailsJobs = New Array;
					Area.Parameters.DetailsTasks.Add("DecryptionScheduledJobs");
					Area.Parameters.DetailsTasks.Add(Item);
					NameScheduledJobs = ArrayRoutineMaintenanceJobs.Get(IndexOfScheduledJobs-1);
					Area.Parameters.DetailsTasks.Add(NameScheduledJobs);
					Area.Parameters.DetailsTasks.Add(StartDate);
					Area.Parameters.DetailsTasks.Add(EndDate);
					Report.Put(Area);
				EndIf;
				IndexOfScheduledJobs = IndexOfScheduledJobs + 1;
			EndDo;
			Report.EndRowGroup();
		EndDo;
	EndIf;
	
	Report.Put(Template.GetArea("IsBlankString"));
	
	// Get GanttDiagram and specify parameters required for filling.
	Area = Template.GetArea("Chart");
	GanttChart = Area.Drawings.GanttChart.Object;
	GanttChart.RefreshEnabled = False;  
	
	Series = GanttChart.Series.Add();

	CurrentEvent			 = Undefined;
	CommonDurationOfST = 0;
	Point					 = Undefined;
	DetailsDots		 = Undefined;
	StringStartsCount = Undefined;
	StartingScheduledJobs = 0;
	SignChangeDots        = False;
	
	// Fill in Gantt chart	
	For Each RowScheduledJobs IN TableSessionsRoutineMaintenanceJobs Do
		DurationIntervalJobSchedule = RowScheduledJobs.EndDateJobs - 
													RowScheduledJobs.DateLaunchJobs;
		If DurationIntervalJobSchedule >= ScheduledJobsSessionsMinimumLength Then
			If CurrentEvent <> RowScheduledJobs.NameEvents Then
				If CurrentEvent <> Undefined
					AND SignChangeDots Then
					Point.Details.Add(StartingScheduledJobs);
					Point.Details.Add(CommonDurationOfST);
					Point.Details.Add(StartDate);
					Point.Details.Add(EndDate);
					PointName = StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en = '%1 (%2 from %3)'"), Point.Value, 
						StartingScheduledJobs, String(StringStartsCount.OfLaunches));
					Point.Value = PointName;
				EndIf;
				StringStartsCount = StartsCount.Find(
					RowScheduledJobs.NameEvents, "NameEvents");
				// Do not fill in decryption for background jobs.
				If RowScheduledJobs.EventMetadata <> "" Then 
					PointName = RowScheduledJobs.NameEvents;
					Point = GanttChart.SetPoint(PointName);
					Point.Details = New Array;
					IntervalBegin	  = New Array;
					IntervalEnd	  = New Array;
					SessionScheduledJobs = New Array;
					Point.Details.Add("DetailsDots");
					Point.Details.Add(RowScheduledJobs.EventMetadata);
					Point.Details.Add(RowScheduledJobs.NameEvents);
					Point.Details.Add(StringStartsCount.Canceled);
					Point.Details.Add(StringStartsCount.ExecutionError);                                                             
					Point.Details.Add(IntervalBegin);
					Point.Details.Add(IntervalEnd);
					Point.Details.Add(SessionScheduledJobs);
					Point.Details.Add(ScheduledJobsSessionsMinimumLength);
					CurrentEvent = RowScheduledJobs.NameEvents;
					CommonDurationOfST = 0;				
					StartingScheduledJobs = 0;
					Point.Picture = PictureLib.ScheduledJob;
				ElsIf Not ValueIsFilled(RowScheduledJobs.EventMetadata) Then
					PointName = NStr("en = 'Background jobs'");
					Point = GanttChart.SetPoint(PointName);
					CommonDurationOfST = 0;
				EndIf;
 			EndIf;
			Value = GanttChart.GetValue(Point, Series);
			Interval = Value.Add();
			Interval.Begin = RowScheduledJobs.DateLaunchJobs;
			Interval.End	= RowScheduledJobs.EndDateJobs;
			Interval.Text	= StringFunctionsClientServer.PlaceParametersIntoString(
								NStr("en = '%1 - %2'"), Format(Interval.Begin, "DLF=T"), Format(Interval.End, "DLF=T"));
			SignChangeDots = False;
			// Do not fill in decryption for background jobs.
			If RowScheduledJobs.EventMetadata <> "" Then
				IntervalBegin.Add(RowScheduledJobs.DateLaunchJobs);
				IntervalEnd.Add(RowScheduledJobs.EndDateJobs);
				SessionScheduledJobs.Add(RowScheduledJobs.Session);			
				CommonDurationOfST = DurationIntervalJobSchedule + CommonDurationOfST;
				StartingScheduledJobs = StartingScheduledJobs + 1;
				SignChangeDots = True;
			EndIf;
		EndIf;
	EndDo; 
	
	If StartingScheduledJobs <> 0
		AND ValueIsFilled(Point.Details) Then
		// Assign decryption to the last point.
		Point.Details.Add(StartingScheduledJobs);
		Point.Details.Add(CommonDurationOfST);
		Point.Details.Add(StartDate);
		Point.Details.Add(EndDate);	
		PointName = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = '%1 (%2 from %3)'"), Point.Value, 
				StartingScheduledJobs, String(StringStartsCount.OfLaunches));
		Point.Value = PointName;
	EndIf;
		
	// Set chart display settings.
	ColorOfGanttDiagrams(StartDate, GanttChart, ConcurrentSessions, ColorOfBackground);
	PeriodAnalysis = EndDate - StartDate;
	TimeScaleGanttDiagrams(GanttChart, PeriodAnalysis);
	
	ColumnsCount = GanttChart.Points.Count();
	Area.Drawings.GanttChart.Height				 = 15 + 10 * ColumnsCount;
	Area.Drawings.GanttChart.Width 				 = 450;
	GanttChart.AutoDetectWholeInterval	 = False; 
	GanttChart.IntervalRepresentation   			 = GanttChartIntervalRepresentation.Flat;
	GanttChart.ShowLegend     			 = False;
	GanttChart.VerticalStretch 			 = GanttChartVerticalStretch.StretchRowsAndData;
	GanttChart.SetWholeInterval(StartDate, EndDate);
	GanttChart.RefreshEnabled = True;

	Report.Put(Area);
	
	Result.Insert("Report", Report);  	
	Return Result; 	
EndFunction

// Function receives information on scheduled jobs from the events log monitor.
//
// Parameters:
// FillingParameters - structure - parameters set required to make a report:
// 	StartDate    - Date - period start according to which information will be collected.
// 	EndDate - Date - period end according to which information will be collected.
// 	SizeConcurrentSessions	- Number - min number of concurrent
// 		scheduled jobs to display in the table.
// 	ScheduledJobsSessionsMinimumLength - Number - min
// 		duration of scheduled job sessions in seconds.
// 	ShowBackgroundJobs - Boolean - if true, then string with background job session intervals will be displayed in the Gantt chart.
// 	HideSceduledJobs - ValueList - scheduled jobs list that are required to exclude from the report.
//
// Return
// value values table - table containing information on scheduled
// jobs work from the events log monitor.
//
Function DataForReportOnDurationOfWorkScheduledJobs(FillingParameters)
										
	StartDate = FillingParameters.StartDate;
	EndDate = FillingParameters.EndDate;
	SizeConcurrentSessions = FillingParameters.SizeConcurrentSessions;
	ShowBackgroundJobs = FillingParameters.ShowBackgroundJobs;
	ScheduledJobsSessionsMinimumLength = 
		FillingParameters.ScheduledJobsSessionsMinimumLength;
	HideSceduledJobs = FillingParameters.HideSceduledJobs;
	
	DataEventLog = New ValueTable;
	
	Levels = New Array;
	Levels.Add(EventLogLevel.Information);
	Levels.Add(EventLogLevel.Warning);
	Levels.Add(EventLogLevel.Error);
		
	STEvents = New Array;
	STEvents.Add("_$Job$_.Start"); 
	STEvents.Add("_$Job$_.Cancel");
	STEvents.Add("_$Job$_.Fail");
	STEvents.Add("_$Job$_.Succeed");
	
	SetPrivilegedMode(True);
	UnloadEventLog(DataEventLog,
						   New Structure("Level, StartDate, EndDate, Event",
										   Levels,
										   StartDate,
										   EndDate,
										   STEvents));
										   
	// Generate data for filter by scheduled jobs.
	ListAllScheduledJobs = ScheduledJobs.GetScheduledJobs();
	MapMetadataID = New Map;
	MapMetadataName = New Map;
    MapDescriptionID = New Map;
	SetPrivilegedMode(False);
	
	For Each SchedTask IN ListAllScheduledJobs Do
		MapMetadataID.Insert(SchedTask.Metadata, String(SchedTask.UUID));
		MapDescriptionID.Insert(SchedTask.Description, String(SchedTask.UUID));
		If SchedTask.Description <> "" Then
			MapMetadataName.Insert(SchedTask.Metadata, SchedTask.Description);
		Else 
			MapMetadataName.Insert(SchedTask.Metadata, SchedTask.Metadata.Synonym);
		EndIf;
	EndDo;
	
	// Fill in parameters required to determine concurrent scheduled jobs.
	ParametersConcurrentSessions = New Structure;
	ParametersConcurrentSessions.Insert("DataEventLog", DataEventLog);
	ParametersConcurrentSessions.Insert("MapDescriptionID", MapDescriptionID);
    ParametersConcurrentSessions.Insert("MapMetadataID", MapMetadataID);
    ParametersConcurrentSessions.Insert("MapMetadataName", MapMetadataName);
    ParametersConcurrentSessions.Insert("HideSceduledJobs", HideSceduledJobs);
    ParametersConcurrentSessions.Insert("ScheduledJobsSessionsMinimumLength",
											ScheduledJobsSessionsMinimumLength);
	
	// Max number of	scheduled jobs concurrent sessions.
	ConcurrentSessions = AmountAtSameTimeRoutineMaintenanceJobs(ParametersConcurrentSessions);
	
	// Filter required values from the ConcurrentSessions table.
	ConcurrentSessions.Sort("ConcurrentScheduledJobs Desc");
	
	StringTotalAmountAtSameTimeRoutineMaintenanceJobs = Undefined;
	TotalAmountAtSameTimeRoutineMaintenanceJobs = New ValueTable();
	TotalAmountAtSameTimeRoutineMaintenanceJobs.Columns.Add("DateAmountAtSameTimeScheduledJobs", 
		New TypeDescription("String", , New StringQualifiers(50)));
	TotalAmountAtSameTimeRoutineMaintenanceJobs.Columns.Add("AmountAtSameTimeRoutineMaintenanceJobs", 
		New TypeDescription("Number", New NumberQualifiers(10))); 
	TotalAmountAtSameTimeRoutineMaintenanceJobs.Columns.Add("ScheduledJobList");
	
	For Each StringConcurrentSessions IN ConcurrentSessions Do
		If StringConcurrentSessions.AmountAtSameTimeRoutineMaintenanceJobs >= SizeConcurrentSessions
			AND StringConcurrentSessions.AmountAtSameTimeRoutineMaintenanceJobs >= 2 Then
			StringTotalAmountAtSameTimeRoutineMaintenanceJobs = TotalAmountAtSameTimeRoutineMaintenanceJobs.Add();
			StringTotalAmountAtSameTimeRoutineMaintenanceJobs.DateAmountAtSameTimeScheduledJobs = 
				StringConcurrentSessions.DateAmountAtSameTimeScheduledJobs;
			StringTotalAmountAtSameTimeRoutineMaintenanceJobs.AmountAtSameTimeRoutineMaintenanceJobs = 
				StringConcurrentSessions.AmountAtSameTimeRoutineMaintenanceJobs;
			StringTotalAmountAtSameTimeRoutineMaintenanceJobs.ScheduledJobList = 
				StringConcurrentSessions.ScheduledJobList;
		EndIf;
	EndDo;
										   
	DataEventLog.Sort("Metadata, Data, Date, Session");
	
	// Fill in parameters required to get data on each scheduled jobs session.
	ParametersSessionsRoutineMaintenanceJobs = New Structure;
	ParametersSessionsRoutineMaintenanceJobs.Insert("DataEventLog", DataEventLog);
	ParametersSessionsRoutineMaintenanceJobs.Insert("MapDescriptionID", MapDescriptionID);
    ParametersSessionsRoutineMaintenanceJobs.Insert("MapMetadataID", MapMetadataID);
    ParametersSessionsRoutineMaintenanceJobs.Insert("MapMetadataName", MapMetadataName);
    ParametersSessionsRoutineMaintenanceJobs.Insert("ShowBackgroundJobs", ShowBackgroundJobs);
    ParametersSessionsRoutineMaintenanceJobs.Insert("HideSceduledJobs", HideSceduledJobs);
	 	   
	// Scheduled jobs	
	TableSessionsRoutineMaintenanceJobs = 
		SessionsRoutineMaintenanceJobs(ParametersSessionsRoutineMaintenanceJobs).TableSessionsRoutineMaintenanceJobs;
	StartsCount = SessionsRoutineMaintenanceJobs(ParametersSessionsRoutineMaintenanceJobs).StartsCount;
	
	Return New Structure("TableScheduledJobSessions, TotalCuncurrentScheduledJobs, StartsCount", 
   							TableSessionsRoutineMaintenanceJobs, TotalAmountAtSameTimeRoutineMaintenanceJobs, StartsCount);	
EndFunction   						

Function AmountAtSameTimeRoutineMaintenanceJobs(ParametersConcurrentSessions)
	
	DataEventLog 			  = ParametersConcurrentSessions.DataEventLog;
	MapDescriptionID = ParametersConcurrentSessions.MapDescriptionID;
	MapMetadataID   = ParametersConcurrentSessions.MapMetadataID;
	MapMetadataName 		  = ParametersConcurrentSessions.MapMetadataName;
	HideSceduledJobs 			  = ParametersConcurrentSessions.HideSceduledJobs;
	ScheduledJobsSessionsMinimumLength = ParametersConcurrentSessions.	
		ScheduledJobsSessionsMinimumLength;
										
	ConcurrentSessions = New ValueTable();
	
	ConcurrentSessions.Columns.Add("DateAmountAtSameTimeScheduledJobs",
										New TypeDescription("String", , New StringQualifiers(50)));
	ConcurrentSessions.Columns.Add("AmountAtSameTimeRoutineMaintenanceJobs",
										New TypeDescription("Number", New NumberQualifiers(10)));
	ConcurrentSessions.Columns.Add("ScheduledJobList");
	
	ArrayRoutineMaintenanceJobs = New Array;
	
	AmountAtSameTimeRoutineMaintenanceJobs	  = 0;
	Counter     				  = 0;
	CurrentDate 					  = Undefined;
	TableRow 				  = Undefined;
	MaxArrayScheduledJobs = Undefined;
	
	For Each DataRowEventLog IN DataEventLog Do 
		If Not ValueIsFilled(DataRowEventLog.Date)
			Or Not ValueIsFilled(DataRowEventLog.Metadata) Then
			Continue;
		EndIf;
		
		NameAndUUID = NameAndGUIDScheduledJobsForSession(
			DataRowEventLog, MapDescriptionID,
			MapMetadataID, MapMetadataName);
			
		NameScheduledJobs = NameAndUUID.NameSession;
		ScheduledJobUUID = NameAndUUID.ScheduledJobUUID;
		
		If Not HideSceduledJobs = Undefined
			AND Not TypeOf(HideSceduledJobs) = Type("String") Then
			FilterScheduledJobs = HideSceduledJobs.FindByValue(
				ScheduledJobUUID);
			If Not FilterScheduledJobs = Undefined Then
				Continue;
			EndIf;
		ElsIf Not HideSceduledJobs = Undefined
			AND TypeOf(HideSceduledJobs) = Type("String") Then	
			If ScheduledJobUUID = HideSceduledJobs Then
				Continue;
			EndIf;
		EndIf;	
		
		DateAmountAtSameTimeScheduledJobs = BegOfHour(DataRowEventLog.Date);
		
		If CurrentDate <> DateAmountAtSameTimeScheduledJobs Then              
			If TableRow <> Undefined Then
			   	TableRow.AmountAtSameTimeRoutineMaintenanceJobs = AmountAtSameTimeRoutineMaintenanceJobs;
				TableRow.DateAmountAtSameTimeScheduledJobs = StringFunctionsClientServer.PlaceParametersIntoString(
										NStr("en = '%1 - %2'"), Format(CurrentDate, "DLF=T"), 
										Format(EndOfHour(CurrentDate), "DLF=T"));
				TableRow.ScheduledJobList = MaxArrayScheduledJobs;
			EndIf;
			TableRow = ConcurrentSessions.Add();
			AmountAtSameTimeRoutineMaintenanceJobs = 0;
			Counter    = 0;
			ArrayRoutineMaintenanceJobs.Clear();
			CurrentDate = DateAmountAtSameTimeScheduledJobs;
		EndIf;
		
		If DataRowEventLog.Event = "_$Job$_.Start" Then
			Counter = Counter + 1;
			ArrayRoutineMaintenanceJobs.Add(NameScheduledJobs);
			ArrayRoutineMaintenanceJobs.Add(DataRowEventLog.Session);
			ArrayRoutineMaintenanceJobs.Add(DataRowEventLog.Date);
		Else
			IndexOfScheduledJobs = ArrayRoutineMaintenanceJobs.Find(NameScheduledJobs);
			If IndexOfScheduledJobs = Undefined Then 
				Continue;
			EndIf;
			
			If ValueIsFilled(MaxArrayScheduledJobs) Then
				RowIndexArray = MaxArrayScheduledJobs.Find(NameScheduledJobs);
				If RowIndexArray <> Undefined 
					AND MaxArrayScheduledJobs[RowIndexArray+1] = ArrayRoutineMaintenanceJobs[IndexOfScheduledJobs+1]
					AND DataRowEventLog.Date - MaxArrayScheduledJobs[RowIndexArray+2] <
						ScheduledJobsSessionsMinimumLength Then
					MaxArrayScheduledJobs.Delete(RowIndexArray);
					MaxArrayScheduledJobs.Delete(RowIndexArray);
					MaxArrayScheduledJobs.Delete(RowIndexArray);
					AmountAtSameTimeRoutineMaintenanceJobs = AmountAtSameTimeRoutineMaintenanceJobs - 1;
				EndIf;
			EndIf;    						
			ArrayRoutineMaintenanceJobs.Delete(IndexOfScheduledJobs);
			ArrayRoutineMaintenanceJobs.Delete(IndexOfScheduledJobs); // Delete session value
			ArrayRoutineMaintenanceJobs.Delete(IndexOfScheduledJobs); // Delete date value
			Counter = Counter - 1;
		EndIf;
		
		Counter = Max(Counter, 0);
		If Counter > AmountAtSameTimeRoutineMaintenanceJobs Then
			MaxArrayScheduledJobs = New Array;
			For Each Item IN ArrayRoutineMaintenanceJobs Do
				MaxArrayScheduledJobs.Add(Item);
			EndDo;
		EndIf;
		AmountAtSameTimeRoutineMaintenanceJobs = Max(AmountAtSameTimeRoutineMaintenanceJobs, Counter);
	EndDo;
		
	If AmountAtSameTimeRoutineMaintenanceJobs <> 0 Then
		TableRow.AmountAtSameTimeRoutineMaintenanceJobs  = AmountAtSameTimeRoutineMaintenanceJobs;
		TableRow.DateAmountAtSameTimeScheduledJobs = StringFunctionsClientServer.PlaceParametersIntoString(
								NStr("en = '%1 - %2'"), Format(CurrentDate, "DLF=T"), 
								Format(EndOfHour(CurrentDate), "DLF=T"));
		TableRow.ScheduledJobList = MaxArrayScheduledJobs;
	EndIf;
	
	Return ConcurrentSessions;
EndFunction

Function SessionsRoutineMaintenanceJobs(ParametersSessionsRoutineMaintenanceJobs)

	DataEventLog = ParametersSessionsRoutineMaintenanceJobs.DataEventLog;
	MapDescriptionID = ParametersSessionsRoutineMaintenanceJobs.MapDescriptionID;
	MapMetadataID = ParametersSessionsRoutineMaintenanceJobs.MapMetadataID;
	MapMetadataName = ParametersSessionsRoutineMaintenanceJobs.MapMetadataName;
	HideSceduledJobs = ParametersSessionsRoutineMaintenanceJobs.HideSceduledJobs;
	ShowBackgroundJobs = ParametersSessionsRoutineMaintenanceJobs.ShowBackgroundJobs;  
	
	TableSessionsRoutineMaintenanceJobs = New ValueTable();
	TableSessionsRoutineMaintenanceJobs.Columns.Add("DateLaunchJobs",New TypeDescription("Date", , , New DateQualifiers(DateFractions.DateTime)));
	TableSessionsRoutineMaintenanceJobs.Columns.Add("EndDateJobs",New TypeDescription("Date", , , New DateQualifiers(DateFractions.DateTime)));
    TableSessionsRoutineMaintenanceJobs.Columns.Add("NameEvents",New TypeDescription("String", , New StringQualifiers(100)));
	TableSessionsRoutineMaintenanceJobs.Columns.Add("EventMetadata",New TypeDescription("String", , New StringQualifiers(100)));
	TableSessionsRoutineMaintenanceJobs.Columns.Add("Session",New TypeDescription("Number", 	New NumberQualifiers(10)));
	
	StartsCount = New ValueTable();
	StartsCount.Columns.Add("NameEvents",New TypeDescription("String", , New StringQualifiers(100)));
	StartsCount.Columns.Add("OfLaunches",New TypeDescription("Number", 	New NumberQualifiers(10)));
	StartsCount.Columns.Add("Canceled",New TypeDescription("Number", 	New NumberQualifiers(10)));
	StartsCount.Columns.Add("ExecutionError",New TypeDescription("Number", 	New NumberQualifiers(10))); 	
	
	RowScheduledJobs = Undefined;
	NameEvents			  = Undefined;
	EndDateJobs	  = Undefined;
	DateLaunchJobs		  = Undefined;
	EventMetadata		  = Undefined;
	OfLaunches				  = 0;
	CurrentEvent			  = Undefined;
	StringStartsCount  = Undefined;
	CurrentSession			  = 0;
	Canceled				  = 0;
	ExecutionError		  = 0;
	
	For Each DataRowEventLog IN DataEventLog Do
		If Not ValueIsFilled(DataRowEventLog.Metadata)
			AND ShowBackgroundJobs = False Then
			Continue;
		EndIf;
		
		NameAndUUID = NameAndGUIDScheduledJobsForSession(
			DataRowEventLog, MapDescriptionID,
			MapMetadataID, MapMetadataName);
			
		NameEvents = NameAndUUID.NameSession;
		ScheduledJobUUID = NameAndUUID.
														ScheduledJobUUID;

		If Not HideSceduledJobs = Undefined
			AND Not TypeOf(HideSceduledJobs) = Type("String") Then
			FilterScheduledJobs = HideSceduledJobs.FindByValue(
				ScheduledJobUUID);
			If Not FilterScheduledJobs = Undefined Then
				Continue;
			EndIf;
		ElsIf Not HideSceduledJobs = Undefined
			AND TypeOf(HideSceduledJobs) = Type("String") Then	
			If ScheduledJobUUID = HideSceduledJobs Then
				Continue;
			EndIf;
		EndIf;
	
		Session = DataRowEventLog.Session;
		If CurrentEvent = Undefined Then                             
			CurrentEvent = NameEvents;
			OfLaunches = 0;
		ElsIf CurrentEvent <> NameEvents Then
			StringStartsCount = StartsCount.Add();
			StringStartsCount.NameEvents = CurrentEvent;
			StringStartsCount.OfLaunches = OfLaunches;
			StringStartsCount.Canceled = Canceled;
			StringStartsCount.ExecutionError = ExecutionError;
			OfLaunches = 0; 
			Canceled = 0;
			ExecutionError = 0;
			CurrentEvent = NameEvents;
		EndIf;  
		
		If CurrentSession <> Session Then
			RowScheduledJobs = TableSessionsRoutineMaintenanceJobs.Add();
			DateLaunchJobs = DataRowEventLog.Date;
			RowScheduledJobs.DateLaunchJobs = DateLaunchJobs;    
		EndIf;
		
		If CurrentSession = Session Then
			EndDateJobs = DataRowEventLog.Date;
			EventMetadata = DataRowEventLog.Metadata;
			RowScheduledJobs.NameEvents = NameEvents;
			RowScheduledJobs.EventMetadata = EventMetadata;
			RowScheduledJobs.EndDateJobs = EndDateJobs;
			RowScheduledJobs.Session = CurrentSession;
		EndIf;
		CurrentSession = Session;
		
		If DataRowEventLog.Event = "_$Job$_.Cancel" Then
			Canceled = Canceled + 1;
		ElsIf DataRowEventLog.Event = "_$Job$_.Fail" Then
			ExecutionError = ExecutionError + 1;
		ElsIf DataRowEventLog.Event = "_$Job$_.Start" Then
			OfLaunches = OfLaunches + 1
		EndIf;		
	EndDo;
	
	StringStartsCount = StartsCount.Add();
	StringStartsCount.NameEvents = CurrentEvent;
	StringStartsCount.OfLaunches = OfLaunches;
	StringStartsCount.Canceled = Canceled;
	StringStartsCount.ExecutionError = ExecutionError;
	
	TableSessionsRoutineMaintenanceJobs.Sort("EventMetadata, EventName, TaskStartDate");
	
	Return New Structure("TableScheduledJobSessions, StartsCount",
					TableSessionsRoutineMaintenanceJobs, StartsCount);
EndFunction
 
// Function of report generation by the selected scheduled job.
// Parameters:
// Details - scheduled job decryption.
//
Function DecryptionScheduledJobs(Details) Export
	Result = New Structure;
	Report = New SpreadsheetDocument;
	CanceledJobs = 0;
	ExecutionError = 0;
	TaskMetadata = Details.Get(1);
	
	DateLaunchJobs = Details.Get(5);
	EndDateJobs = Details.Get(6);
	SessionList = Details.Get(7);
	Template = Reports.EventsLogAnalysis.GetTemplate("ScheduledJobDetails");
	
	Area = Template.GetArea("Title");
	StartDate = Details.Get(11);
	EndDate = Details.Get(12);
	Area.Parameters.StartDate = StartDate;
	Area.Parameters.EndDate = EndDate;
	If Details.Get(8) = 0 Then
		DisplayModeIntervals = NStr("en = 'Enabled'");
	Else
		DisplayModeIntervals = NStr("en = 'Disabled'");
	EndIf;
	Area.Parameters.DisplayModeSessions = DisplayModeIntervals;
	Report.Put(Area);
	
	Report.Put(Template.GetArea("IsBlankString"));
	
	Area = Template.GetArea("Table");
	Area.Parameters.TypeJobs = NStr("en = 'Scheduled'");
	Area.Parameters.NameEvents = Details.Get(2);
	Area.Parameters.OfLaunches = Details.Get(9);
	CanceledJobs = Details.Get(3);
	ExecutionError = Details.Get(4);
	If CanceledJobs = 0 Then
		Area.Parameters.Canceled = "0";
	Else
		Area.Parameters.Canceled = CanceledJobs;
	EndIf;
	If ExecutionError = 0 Then 
		Area.Parameters.ExecutionError = "0";
	Else
		Area.Parameters.ExecutionError = ExecutionError;
	EndIf;
	CommonDurationOfST = Details.Get(10);
	CommonDurationOfSTTotal = DurationOfScheduledJobs(CommonDurationOfST);
	Area.Parameters.CommonDurationOfST = CommonDurationOfSTTotal;
	Report.Put(Area);
	
	Report.Put(Template.GetArea("IsBlankString")); 
	
	Report.Put(Template.GetArea("TitleSpacing"));
		
	Report.Put(Template.GetArea("IsBlankString"));
	
	Report.Put(Template.GetArea("TableHeader"));
	
	// Fill in intervals table.
	SizeArray = DateLaunchJobs.Count();
	NumberInterval = 1; 	
    Report.StartRowGroup(, False);
	For IndexOf = 0 To SizeArray-1 Do
		Area = Template.GetArea("IntervalsTable");
		IntervalBegin = DateLaunchJobs.Get(IndexOf);
		IntervalEnd = EndDateJobs.Get(IndexOf);
		SessionScheduledJobs = SessionList.Get(IndexOf);
		DurationOfST = DurationOfScheduledJobs(IntervalEnd - IntervalBegin);
		Area.Parameters.NumberInterval = NumberInterval;
		Area.Parameters.IntervalBegin = Format(IntervalBegin, "DLF=T");
		Area.Parameters.IntervalEnd = Format(IntervalEnd, "DLF=T");
		Area.Parameters.DurationOfST = DurationOfST;
		Area.Parameters.Session = SessionList.Get(IndexOf);
		Area.Parameters.DetailsInterval = New Array;
		Area.Parameters.DetailsInterval.Add(IntervalBegin);
		Area.Parameters.DetailsInterval.Add(IntervalEnd);
		Area.Parameters.DetailsInterval.Add(SessionList.Get(IndexOf));
		Report.Put(Area);
		NumberInterval = NumberInterval + 1;
	EndDo;
	Report.EndRowGroup();
	
	Result.Insert("Report", Report);
	Return Result;
EndFunction

// Procedure to set color of Gantt chart intervals and background.
//
// Parameters:
// StartDate - day on which chart is made.
// GanttChart - Gantt chart, type - TabularDocumentPicture
// ConcurrentSessions - values table with data on quantity
// 		of concurrent scheduled jobs during the day.
// ColorOfBackground - array of colors for the background intervals.
//
Procedure ColorOfGanttDiagrams(StartDate, GanttChart, ConcurrentSessions, ColorOfBackground)
	// Chart interval colors.
	ColorIntervals = New Array;
	ColorBegin = 153;
	ColorEnd = 253;
	While ColorBegin <= ColorEnd Do
		ColorIntervals.Add(ColorBegin);
		ColorBegin = ColorBegin + 10;
	EndDo;
	
	IndexOf = 0;
	For Each GanttChartPoint IN GanttChart.Points Do
		GanttChartPoint.ColorPriority = True;
		BlueColor = ColorIntervals.Get(IndexOf);
		ColorSeries = New Color(204,204,BlueColor);
		GanttChartPoint.Color = ColorSeries;
		IndexOf = IndexOf + 1;
		If IndexOf = 11 Then
			IndexOf = 0;
		EndIf;
	EndDo;
	
	// Add background interval colors.
	CurrentCountOfSessions = 0;
	IndexColor = 3;
	For Each StringConcurrentSessions IN ConcurrentSessions Do
		If StringConcurrentSessions.AmountAtSameTimeRoutineMaintenanceJobs = 1 Then
			Continue
		EndIf;
		DateRow = Left(StringConcurrentSessions.DateAmountAtSameTimeScheduledJobs, 8);
		DateBeginIB =  Date(Format(StartDate,"DLF=D") + " " + DateRow);
		DateEndIB = EndOfHour(DateBeginIB);
		IntervalGC = GanttChart.BackgroundIntervals.Add(DateBeginIB, DateEndIB);
		If CurrentCountOfSessions <> 0 
			AND CurrentCountOfSessions <> StringConcurrentSessions.AmountAtSameTimeRoutineMaintenanceJobs 
			AND IndexColor <> 0 Then
			IndexColor = IndexColor - 1;
		EndIf;
		BackColor = ColorOfBackground.Get(IndexColor);
		IntervalGC.Color = BackColor;
		
		CurrentCountOfSessions = StringConcurrentSessions.AmountAtSameTimeRoutineMaintenanceJobs;
	EndDo;
EndProcedure

// Procedure for generation of the Gantt chart timeline.
//
// Parameters:
// GanttChart - Gantt chart, type - TabularDocumentPicture
//
Procedure TimeScaleGanttDiagrams(GanttChart, PeriodAnalysis)
	TimeScaleItems = GanttChart.PlotArea.TimeScale.Items;
	
	FirstItem = TimeScaleItems[0];
	For IndexOf = 1 To TimeScaleItems.Count()-1 Do
		TimeScaleItems.Delete(TimeScaleItems[1]);
	EndDo; 
		
	FirstItem.Unit = TimeScaleUnitType.Day;
	FirstItem.PointLines = New Line(ChartLineType.Solid, 1);
	FirstItem.DayFormat =  TimeScaleDayFormat.MonthDay;
	
	Item = TimeScaleItems.Add();
	Item.Unit = TimeScaleUnitType.Hour;
	Item.PointLines = New Line(ChartLineType.Dotted, 1);
	
	If PeriodAnalysis <= 3600 Then
		Item = TimeScaleItems.Add();
		Item.Unit = TimeScaleUnitType.Minute;
		Item.PointLines = New Line(ChartLineType.Dotted, 1);
	EndIf;
EndProcedure

Function DurationOfScheduledJobs(DurationOfST)
	If DurationOfST = 0 Then
		 CommonDurationOfST = "0";
	ElsIf DurationOfST <= 60 Then
		CommonDurationOfST = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = '%1 sec'"), DurationOfST);
	ElsIf 60 < DurationOfST <= 3600 Then
		DurationMinutes  = Format(DurationOfST/60, "NFD=0");
		DurationSeconds = Format((Format(DurationOfST/60, "NFD=2") - 
											Int(DurationOfST/60)) * 60, "NFD=0");
		CommonDurationOfST = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = '%1 min %2 sec'"), DurationMinutes, DurationSeconds);
	ElsIf DurationOfST > 3600 Then
		DurationHours	 = Format(DurationOfST/60/60, "NFD=0");
		DurationMinutes  = (Format(DurationOfST/60/60, "NFD=2") - Int(DurationOfST/60/60))*60;
		DurationMinutes	 = Format(DurationMinutes, "NFD=0");
		CommonDurationOfST = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = '%1 h %2 min'"), DurationHours, DurationMinutes);
	EndIf;
	
	Return CommonDurationOfST;
EndFunction

Function ScheduledJobMetadata(DataForJobSchedule)
	If DataForJobSchedule <> "" Then
		Return Metadata.ScheduledJobs.Find(
			StrReplace(DataForJobSchedule, "ScheduledJob." , ""));
	EndIf;
EndFunction

Function NameAndGUIDScheduledJobsForSession(DataRowEventLog,
			MapDescriptionID, MapMetadataID, MapMetadataName)
	If Not DataRowEventLog.Data = "" Then
		ScheduledJobUUID = MapDescriptionID[
														DataRowEventLog.Data];
		NameSession = DataRowEventLog.Data;
	Else 
		ScheduledJobUUID = MapMetadataID[
			ScheduledJobMetadata(DataRowEventLog.Metadata)];
		NameSession = MapMetadataName[ScheduledJobMetadata(
														DataRowEventLog.Metadata)];
	EndIf;
													
	Return New Structure("SessionName, ScheduledJobUUID",
								NameSession, ScheduledJobUUID)
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Events log monitor control.

// Function that generates report on the errors registered in the events log monitor.
//
// Parameters:
// DataEventLog - values table - table exported from the events log monitor.
//
// The following columns should be present:
//                                          Date, UserName, ApplicationPresentation, EventPresentation, Comment, Level
//
Function GenerateReportEventLogMonitorControl(StartDate, EndDate) Export	
	
	Result = New Structure; 	
	Report = New SpreadsheetDocument; 	
	Template = Reports.EventsLogAnalysis.GetTemplate("ErrorsReportTemplateInEventLogMonitor");   	
	DataEventLog = BugEventLogInformation(StartDate, EndDate);
	RecordsCountEventLogMonitor = DataEventLog.Count();
	
	ReportIsEmpty = (RecordsCountEventLogMonitor = 0); // Check report filling.
		
	///////////////////////////////////////////////////////////////////////////////
	// Preliminary data preparation unit.
	//
	
	RollOnComments = DataEventLog.Copy();
	RollOnComments.Columns.Add("TotalForComment");
	RollOnComments.FillValues(1, "TotalForComment");
	RollOnComments.GroupBy("Level, Comment, Event, EventPresentation", "TotalForComment");
	
	RowArray_LevelError = RollOnComments.FindRows(
									New Structure("Level", EventLogLevel.Error));
	
	RowArray_LevelWarning = RollOnComments.FindRows(
									New Structure("Level", EventLogLevel.Warning));
	
	Rollup_Errors         = RollOnComments.Copy(RowArray_LevelError);
	Rollup_Errors.Sort("TotalOnComment Desc");
	Rollup_Warnings = RollOnComments.Copy(RowArray_LevelWarning);
	Rollup_Warnings.Sort("TotalOnComment Desc");
	
	///////////////////////////////////////////////////////////////////////////////
	// Report itself generation box.
	//
	
	Area = Template.GetArea("HeaderReport");
	Area.Parameters.SelectionBeginOfPeriodning    = StartDate;
	Area.Parameters.SelectionEndOfPeriod = EndDate;
	Area.Parameters.InfobasePresentation = CommonUse.GetInfobasePresentation();
	Report.Put(Area);
	
	ResultCompositionTP = GenerateTabularSection(Template, DataEventLog, Rollup_Errors);
	
	Report.Put(Template.GetArea("IsBlankString"));
	Area = Template.GetArea("TitleBlockErrors");
	Area.Parameters.NumberOfErrors = String(ResultCompositionTP.Total);
	Report.Put(Area);
	
	If ResultCompositionTP.Total > 0 Then
		Report.Put(ResultCompositionTP.TabularSection);
	EndIf;
	
	Result.Insert("TotalForErrors", ResultCompositionTP.Total); 	
	ResultCompositionTP = GenerateTabularSection(Template, DataEventLog, Rollup_Warnings);
	
	Report.Put(Template.GetArea("IsBlankString"));
	Area = Template.GetArea("TitleBlockWarnings");
	Area.Parameters.NumberOfWarnings = ResultCompositionTP.Total;
	Report.Put(Area);
	
	If ResultCompositionTP.Total > 0 Then
		Report.Put(ResultCompositionTP.TabularSection);
	EndIf;
	
	Result.Insert("TotalWarnings", ResultCompositionTP.Total);	
	Report.ShowGrid = False; 	
	Result.Insert("Report", Report); 
	Result.Insert("ReportIsEmpty", ReportIsEmpty);
	Return Result;
	
EndFunction

// Function receives information on errors in the events log monitor by a passed period.
//
// Parameters:
// StartDate    - Date - period start according to with information will be collected.
// EndDate - Date - period end according to which information will be collected.
//
// Return
// value values table - record from the events log monitor according to filter:
//                    EventLogLevel - EventLogMonitor.Error
//                    Start and End of the period - from parameters.
//
Function BugEventLogInformation(Val StartDate, Val EndDate)
	
	DataEventLog = New ValueTable;
	
	LevelsRegistrationErrors = New Array;
	LevelsRegistrationErrors.Add(EventLogLevel.Error);
	LevelsRegistrationErrors.Add(EventLogLevel.Warning);
	
	SetPrivilegedMode(True);
	UnloadEventLog(DataEventLog,
							   New Structure("Level, StartDate, EndDate",
											   LevelsRegistrationErrors,
											   StartDate,
											   EndDate));
	SetPrivilegedMode(False);
	
	Return DataEventLog;
	
EndFunction

// Adds tabular section by errors to the report. Errors are
// output grouped by comment.
//
// Parameters:
// Template  - SpreadsheetDocument - formatted areas source that
//                              will be used while generating the report.
// DataEventLog   - ValueTable - data on errors
//                              and warnings from the events log monitor "as it is".
// RolledUpData - ValueTable - rolled by the comments information on their quantity.
//
Function GenerateTabularSection(Template, DataEventLog, RolledUpData)
	
	Report = New SpreadsheetDocument;	
	Total = 0;
	
	If RolledUpData.Count() > 0 Then
		Report.Put(Template.GetArea("IsBlankString"));
		
		For Each Record IN RolledUpData Do
			Total = Total + Record.TotalForComment;
			RowArray = DataEventLog.FindRows(
				New Structure("Level, Comment",
					EventLogLevel.Error,
					Record.Comment));
			
			Area = Template.GetArea("BodyTablePartHeader");
			Area.Parameters.Fill(Record);
			Report.Put(Area);
			
			Report.StartRowGroup(, False);
			For Each String IN RowArray Do
				Area = Template.GetArea("BodyTablePartOfSpecification");
				Area.Parameters.Fill(String);
				Report.Put(Area);
			EndDo;
			Report.EndRowGroup();
			Report.Put(Template.GetArea("IsBlankString"));
		EndDo;
	EndIf;
	
	Result = New Structure("TabularSection, Total", Report, Total);
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf