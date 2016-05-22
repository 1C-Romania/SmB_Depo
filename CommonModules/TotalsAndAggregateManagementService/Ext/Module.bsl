///////////////////////////////////////////////////////////////////////////////////
// Subsystem "Management of totals and aggregates".
//
///////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Add handlers of the service events (subsriptions).

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"TotalsAndAggregateManagementService");
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\AfterInformationBaseUpdate"].Add(
		"TotalsAndAggregateManagementService");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers["StandardSubsystems.SaaS.JobQueue\ListOfTemplatesOnGet"].Add(
			"TotalsAndAggregateManagementService");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ServerHandlers["StandardSubsystems.CurrentWorks\AtFillingToDoList"].Add(
			"TotalsAndAggregateManagementService");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of service events.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.7";
	Handler.Procedure = "TotalsAndAggregateManagementService.SetScheduledJobsUse";
	Handler.SharedData = True;
	Handler.ExecuteUnderMandatory = True;
	Handler.Priority = 75;
	
EndProcedure

// Called after IB data exclusive update is complete.
// 
// Parameters:
//   PreviousVersion       - String - subsystem version before update. 0.0.0.0 for an empty IB.
//   CurrentVersion          - String - subsystem version after update.
//   ExecutedHandlers - ValueTree - list of the
//                                             executed procedures-processors of updating the subsystem grouped by the version number.
//                            Procedure of completed handlers bypass:
//
// For Each Version From ExecutedHandlers.Rows Cycle
//		
// 	If Version.Version =
// 		 * Then Handler that can be run every time the version changes.
// 	Otherwise,
// 		 Handler runs for a definite version.
// 	EndIf;
//		
// 	For Each Handler From Version.Rows
// 		Cycle ...
// 	EndDo;
//		
// EndDo;
//
//   PutSystemChangesDescription - Boolean (return value)-if set
//                                True, then display the form with updates description.
//   ExclusiveMode           - Boolean - shows that the update was executed in an exclusive mode.
//                                True - update was executed in the exclusive mode.
//
Procedure AfterInformationBaseUpdate(Val PreviousVersion, Val CurrentVersion,
		Val ExecutedHandlers, PutSystemChangesDescription, ExclusiveMode) Export
	
	If Not OperatingModeLocalFile() Then
		Return;
	EndIf;
	
	GenerateTotalsAndAggregatesParameters();
	
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
	
	Patterns.Add("AggregatesUpdate");
	Patterns.Add("RebuildAggregates");
	Patterns.Add("TotalsPeriodSetup");
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//   CurrentWorks - ValueTable - see return value CurrentWorksService.UserToDoList().
//
Procedure AtFillingToDoList(CurrentWorks) Export
	If Not OperatingModeLocalFile() Then
		Return;
	EndIf;
	
	DataProcessorMetadata = Metadata.DataProcessors.TotalBoundaryShift;
	If Not AccessRight("Use", DataProcessorMetadata) Then
		Return;
	EndIf;
	
	DataProcessorFullName = DataProcessorMetadata.FullName();
	
	ModuleCurrentWorksServer = CommonUse.CommonModule("CurrentWorksServer");
	Sections = ModuleCurrentWorksServer.SectionsForObject(DataProcessorFullName);
	If Sections = Undefined Or Sections.Count() = 0 Then
		Return;
	EndIf;
	
	Prototype = New Structure("ThereIsWork, Important, Form, Presentation, ToolTip");
	Prototype.ThereIsWork = MustMoveBorderTotals();
	Prototype.Important   = True;
	Prototype.Form    = DataProcessorFullName + ".Form";
	Prototype.Presentation = NStr("en = 'Optimize the application'");
	Prototype.ToolTip     = NStr("en = 'Speed up documents processing and reports generation.
		|Mandatory monthly procedure, can take some time.'");
	
	For Each Section IN Sections Do
		Work = CurrentWorks.Add();
		Work.ID  = StrReplace(Prototype.Form, ".", "") + StrReplace(Section.FullName(), ".", "");
		Work.Owner       = Section;
		FillPropertyValues(Work, Prototype);
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Execution of scheduled jobs.

// Handler of scheduled job "TotalsPeriodSetup".
Procedure TotalsPeriodSetupHandlerTasks() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	SetTotalsPeriod();
	
EndProcedure

// Handler of scheduled job "AggregatesUpdate".
Procedure AggregatesUpdateTaskHandler() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	UpdateAggregates();
	
EndProcedure

// Handler of scheduled job "AggregatesRecomposition".
Procedure RebuildAggregatesTaskHandler() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	RebuildAggregates();
	
EndProcedure

// For an internal use.
Procedure SetTotalsPeriod() Export
	
	SessionDate = CurrentSessionDate();
	AccumulationRegisterPeriod  = EndOfMonth(AddMonth(SessionDate, -1)); // End of last month.
	AccountingRegisterPeriod = EndOfMonth(SessionDate); // End of current month.
	
	Cache = DivisionCheckCache();
	
	// Calculation of totals for accumulation registers.
	KindBalance = Metadata.ObjectProperties.AccumulationRegisterType.Balance;
	For Each RegisterMetadata IN Metadata.AccumulationRegisters Do
		If RegisterMetadata.RegisterType <> KindBalance Then
			Continue;
		EndIf;
		If Not MetadataObjectAvailableByDivision(Cache, RegisterMetadata) Then
			Continue;
		EndIf;
		AccumulationRegisterManager = AccumulationRegisters[RegisterMetadata.Name];
		If AccumulationRegisterManager.GetMaxTotalsPeriod() >= AccumulationRegisterPeriod Then
			Continue;
		EndIf;
		AccumulationRegisterManager.SetMaxTotalsPeriod(AccumulationRegisterPeriod);
		If Not AccumulationRegisterManager.GetPresentTotalsUsing() Then
			Continue;
		EndIf;
		AccumulationRegisterManager.RecalcPresentTotals();
	EndDo;
	
	// Calculation of totals for accounting registers.
	For Each RegisterMetadata IN Metadata.AccountingRegisters Do
		If Not MetadataObjectAvailableByDivision(Cache, RegisterMetadata) Then
			Continue;
		EndIf;
		AccountingRegisterManager = AccountingRegisters[RegisterMetadata.Name];
		If AccountingRegisterManager.GetMaxTotalsPeriod() >= AccountingRegisterPeriod Then
			Continue;
		EndIf;
		AccountingRegisterManager.SetMaxTotalsPeriod(AccountingRegisterPeriod);
		If Not AccountingRegisterManager.GetPresentTotalsUsing() Then
			Continue;
		EndIf;
		AccountingRegisterManager.RecalcPresentTotals();
	EndDo;
	
	// Date registration.
	If OperatingModeLocalFile() Then
		TotalParameters = TotalsAndAggregatesParameters();
		TotalParameters.CalculationTotalsDate = BegOfMonth(SessionDate);
		WriteParametersTotalsAndAggregates(TotalParameters);
	EndIf;
EndProcedure

// For an internal use.
Procedure UpdateAggregates() Export
	
	Cache = DivisionCheckCache();
	
	// Aggregates update for working accumulation registers.
	KindTurnovers = Metadata.ObjectProperties.AccumulationRegisterType.Turnovers;
	For Each RegisterMetadata IN Metadata.AccumulationRegisters Do
		If RegisterMetadata.RegisterType <> KindTurnovers Then
			Continue;
		EndIf;
		If Not MetadataObjectAvailableByDivision(Cache, RegisterMetadata) Then
			Continue;
		EndIf;
		AccumulationRegisterManager = AccumulationRegisters[RegisterMetadata.Name];
		If Not AccumulationRegisterManager.GetAggregatesMode()
			Or Not AccumulationRegisterManager.GetAggregatesUsing() Then
			Continue;
		EndIf;
		// Aggregates update.
		AccumulationRegisterManager.UpdateAggregates();
	EndDo;
EndProcedure

// For an internal use.
Procedure RebuildAggregates() Export
	
	Cache = DivisionCheckCache();
	
	// Recomposition of aggregates for working accumulation registers.
	KindTurnovers = Metadata.ObjectProperties.AccumulationRegisterType.Turnovers;
	For Each RegisterMetadata IN Metadata.AccumulationRegisters Do
		If RegisterMetadata.RegisterType <> KindTurnovers Then
			Continue;
		EndIf;
		If Not MetadataObjectAvailableByDivision(Cache, RegisterMetadata) Then
			Continue;
		EndIf;
		AccumulationRegisterManager = AccumulationRegisters[RegisterMetadata.Name];
		If Not AccumulationRegisterManager.GetAggregatesMode()
			Or Not AccumulationRegisterManager.GetAggregatesUsing() Then
			Continue;
		EndIf;
		// Aggregates recomposition.
		AccumulationRegisterManager.RebuildAggregatesUsing();
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For work in file mode.

// Returns True if the IB works in file mode and division is disabled.
Function OperatingModeLocalFile()
	Return CommonUse.FileInfobase() AND Not CommonUseReUse.DataSeparationEnabled();
EndFunction

// Determines the relevance of totals and aggregates. If there are no registers, returns True.
Function MustMoveBorderTotals() Export
	Parameters = TotalsAndAggregatesParameters();
	Return Parameters.IsRegistersOfTotals AND AddMonth(Parameters.CalculationTotalsDate, 2) < CurrentSessionDate();
EndFunction

// Receives the value of constant "TotalsAndAggregatesParameters".
Function TotalsAndAggregatesParameters()
	SetPrivilegedMode(True);
	Parameters = Constants.TotalsAndAggregatesParameters.Get().Get();
	If TypeOf(Parameters) <> Type("Structure") OR Not Parameters.Property("IsRegistersOfTotals") Then
		Parameters = GenerateTotalsAndAggregatesParameters();
	EndIf;
	Return Parameters;
EndFunction

// Repopulates constant "TotalsAndAggregatesParameters".
Function GenerateTotalsAndAggregatesParameters()
	Parameters = New Structure;
	Parameters.Insert("IsRegistersOfTotals", False);
	Parameters.Insert("CalculationTotalsDate",  '39991231235959'); // M1.12.3999 23:59:59, maximum date.
	
	KindBalance = Metadata.ObjectProperties.AccumulationRegisterType.Balance;
	For Each RegisterMetadata IN Metadata.AccumulationRegisters Do
		If RegisterMetadata.RegisterType = KindBalance Then
			Date = AccumulationRegisters[RegisterMetadata.Name].GetMaxTotalsPeriod() + 1;
			Parameters.IsRegistersOfTotals = True;
			Parameters.CalculationTotalsDate  = min(Parameters.CalculationTotalsDate, Date);
		EndIf;
	EndDo;
	
	If Not Parameters.IsRegistersOfTotals Then
		Parameters.Insert("CalculationTotalsDate", '00010101');
	EndIf;
	
	WriteParametersTotalsAndAggregates(Parameters);
	
	Return Parameters;
EndFunction

// Writes the value of constant "TotalsAndAggregatesParameters".
Procedure WriteParametersTotalsAndAggregates(Parameters) Export
	Constants.TotalsAndAggregatesParameters.Set(New ValueStorage(Parameters));
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// Sets schedules and use of
// scheduled jobs of the subsystem in default values. Used only during transition to library version 2.1.3.
//
Procedure SetScheduledJobsUsage() Export
	
	EmptySchedule = ScheduleTasks1Default("");
	
	VerifyUse = Not CommonUseReUse.DataSeparationEnabled();
	
	NamesJobs = New Array;
	NamesJobs.Add("AggregatesUpdate");
	NamesJobs.Add("RebuildAggregates");
	NamesJobs.Add("TotalsPeriodSetup");
	
	For Each TaskName IN NamesJobs Do
		Task = ScheduledJobs.FindPredefined(TaskName);
		
		If VerifyUse AND Task.Use Then
			Continue;
		EndIf;
		
		If Not CommonUseClientServer.SchedulesAreEqual(EmptySchedule, Task.Schedule) Then
			Continue;
		EndIf;
		
		Task.Schedule = ScheduleTasks1Default(TaskName);
		If VerifyUse Then
			Task.Use = True;
		EndIf;
		
		Task.Write();
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other

Function ScheduleTasks1Default(Val Name)
	Schedule = New JobSchedule;
	If Name = "" Then
		Return Schedule;
	EndIf;
	Schedule.DaysRepeatPeriod = 1;
	
	If Name = "AggregatesUpdate" Then
		Schedule.BeginTime = Date(1, 1, 1, 01, 00, 00);
		AddDetailedSchedule(Schedule, "BeginTime", Date(1, 1, 1, 01, 00, 00));
		AddDetailedSchedule(Schedule, "BeginTime", Date(1, 1, 1, 14, 00, 00));
	ElsIf Name = "RebuildAggregates" Then
		Schedule.BeginTime = Date(1, 1, 1, 03, 00, 00);
		SetWeekDays(Schedule, "6");
	ElsIf Name = "TotalsPeriodSetup" Then
		Schedule.BeginTime = Date(1, 1, 1, 01, 00, 00);
		Schedule.DayInMonth = 5;
	Else
		MessagePattern = NStr("en = 'Unknown name of a task %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, Name);
		Raise(MessageText);
	EndIf;
	
	Return Schedule;
EndFunction

Procedure AddDetailedSchedule(Schedule, Key, Value)
	DetailedSchedule = New JobSchedule;
	FillPropertyValues(DetailedSchedule, New Structure(Key, Value));
	Array = Schedule.DetailedDailySchedules;
	Array.Add(DetailedSchedule);
	Schedule.DetailedDailySchedules = Array;
EndProcedure

Procedure SetWeekDays(Schedule, WeekDaysAtRow)
	WeekDays = New Array;
	RowArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(WeekDaysAtRow);
	For Each StringWeekDayNumber IN RowArray Do
		WeekDays.Add(Number(StringWeekDayNumber));
	EndDo;
	Schedule.WeekDays = WeekDays;
EndProcedure

Function DivisionCheckCache()
	Cache = New Structure;
	Cache.Insert("SaaS", CommonUseReUse.DataSeparationEnabled());
	If Cache.SaaS Then
		Cache.Insert("InDataArea", CommonUse.UseSessionSeparator());
		Cache.Insert("MainDataSeparator",        CommonUseReUse.MainDataSeparator());
		Cache.Insert("SupportDataSplitter", CommonUseReUse.SupportDataSplitter());
	EndIf;
	Return Cache;
EndFunction

Function MetadataObjectAvailableByDivision(Cache, MetadataObject) Export
	If Not Cache.SaaS Then
		Return True;
	EndIf;
	MetadataObjectDivided =
		CommonUse.IsSeparatedMetadataObject(MetadataObject, Cache.MainDataSeparator)
		Or CommonUse.IsSeparatedMetadataObject(MetadataObject, Cache.SupportDataSplitter);
	Return Cache.InDataArea = MetadataObjectDivided;
EndFunction

#EndRegion
