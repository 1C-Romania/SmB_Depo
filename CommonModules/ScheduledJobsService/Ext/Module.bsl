////////////////////////////////////////////////////////////////////////////////
// "Scheduled jobs" subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ServerHandlers["StandardSubsystems.SaaS\WhenCompletingTablesOfParametersOfIB"].Add(
			"ScheduledJobsService");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Throws exception if a user does not have administrative rights.
Procedure CallExceptionIfNoAdminPrivileges() Export
	
	If Not PrivilegedMode() Then
		VerifyAccessRights("Administration", Metadata);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Generates a list of IB parameters.
//
// Parameters:
// ParameterTable - ValueTable - parameters description table.
// Description columns content - see SaaSOperations.GetInfobaseParameterTable().
//
Procedure WhenCompletingTablesOfParametersOfIB(Val ParameterTable) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
		ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "ActiveBackgroundJobMaxExecutionTime");
		ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "ActiveBackgroundJobMaxCount");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for work with scheduled jobs.

// Designed for the "manual" immediate execution
// of the scheduled job procedure or in the client session (file IB) or in the background job on server (in the server IB).
// Applied in any connection mode.
// "WithManual" start mode does not influence execution of
// the scheduled job by the failure and main schedule as ref to the scheduled job is not specified in the background job.
// BackgroundJob type does not allow installation of this ref, that is
// why the same rule is applied to the file mode.
// 
// Parameters:
//  Task             - ScheduledJob, String - ScheduledJob unique ID.
//
// Returns:
//  Structure - with
//    properties * StartMoment -   Undefined, Date - for the file IB sets passed moment as
//                        a moment of scheduled job method start.
//                        For server IB - returns background job start moment by fact.
//    * BackgroundJobID - String - for the server IB returns started background job ID.
//
Function ExecuteScheduledJobManually(Val Task) Export
	
	CallExceptionIfNoAdminPrivileges();
	SetPrivilegedMode(True);
	
	ExecuteParameters = ScheduledJobExecutionParameters();
	ExecuteParameters.ProcedureAlreadyExecuting = False;
	Task = ScheduledJobsServer.GetScheduledJob(Task);
	
	ExecuteParameters.Started = False;
	LastBackgroundJobProperties = GetScheduledJobExecutionLastBackgroundJobProperties(Task);
	
	If LastBackgroundJobProperties <> Undefined
	   AND LastBackgroundJobProperties.State = BackgroundJobState.Active Then
		
		ExecuteParameters.StartedAt  = LastBackgroundJobProperties.Begin;
		If ValueIsFilled(LastBackgroundJobProperties.Description) Then
			ExecuteParameters.BackgroundJobPresentation = LastBackgroundJobProperties.Description;
		Else
			ExecuteParameters.BackgroundJobPresentation = ScheduledJobPresentation(Task);
		EndIf;
	Else
		BackgroundJobDescription = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en = 'Launch manually: %1'"), ScheduledJobPresentation(Task));
		BackgroundJob = BackgroundJobs.Execute(Task.Metadata.MethodName, Task.Parameters, String(Task.UUID), BackgroundJobDescription);
		ExecuteParameters.BackgroundJobID = String(BackgroundJob.UUID);
		ExecuteParameters.StartedAt = BackgroundJobs.FindByUUID(BackgroundJob.UUID).Begin;
		ExecuteParameters.Started = True;
	EndIf;
	
	ExecuteParameters.ProcedureAlreadyExecuting = Not ExecuteParameters.Started;
	Return ExecuteParameters;
	
EndFunction

Function ScheduledJobExecutionParameters() 
	
	Result = New Structure;
	Result.Insert("StartedAt");
	Result.Insert("BackgroundJobID");
	Result.Insert("BackgroundJobPresentation");
	Result.Insert("ProcedureAlreadyExecuting");
	Result.Insert("Started");
	Return Result;
	
EndFunction

// Returns the scheduled
// job presentation, it is in the order of unfilled attributes exclusion.:
// Description, Metadata.Synonym, Metadata.Name.
//
// Parameters:
//  Task      - ScheduledJob, String - if a string, then UUID as a string.
//
// Returns:
//  Row.
//
Function ScheduledJobPresentation(Val Task) Export
	
	CallExceptionIfNoAdminPrivileges();
	SetPrivilegedMode(True);
	
	If TypeOf(Task) = Type("ScheduledJob") Then
		ScheduledJob = Task;
	Else
		ScheduledJob = ScheduledJobs.FindByUUID(New UUID(Task));
	EndIf;
	
	If ScheduledJob <> Undefined Then
		Presentation = ScheduledJob.Description;
		
		If IsBlankString(ScheduledJob.Description) Then
			Presentation = ScheduledJob.Metadata.Synonym;
			
			If IsBlankString(Presentation) Then
				Presentation = ScheduledJob.Metadata.Name;
			EndIf
		EndIf;
	Else
		Presentation = TextUndefined();
	EndIf;
	
	Return Presentation;
	
EndFunction

// Returns text "<undefined>".
Function TextUndefined() Export
	
	Return NStr("en = '<not defined>'");
	
EndFunction

// Returns a multi-line String containing Messages
// and ErrorIndormationDescription, last background job is found by
// an identifier of scheduled job and there are messages/errors.
//
// Parameters:
//  Task      - ScheduledJob, String - UUID
//                 of ScheduledJob as a string.
//
// Returns:
//  Row.
//
Function MessagesAndDescriptionsOfScheduledJobErrors(Val Task) Export
	
	CallExceptionIfNoAdminPrivileges();
	SetPrivilegedMode(True);

	ScheduledJobID = ?(TypeOf(Task) = Type("ScheduledJob"), String(Task.UUID), Task);
	LastBackgroundJobProperties = GetScheduledJobExecutionLastBackgroundJobProperties(ScheduledJobID);
	Return ?(LastBackgroundJobProperties = Undefined,
	          "",
	          MessagesAndDescriptionsOfBackgroundJobErrors(LastBackgroundJobProperties.ID) );
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for work with background jobs.

// Cancels background job if it is possible, namely if it is executed on server and actively.
//
// Parameters:
//  ID  - BackgroundJob unique ID string.
// 
Procedure CancelBackgroundJob(ID) Export
	
	CallExceptionIfNoAdminPrivileges();
	SetPrivilegedMode(True);
	
	Filter = New Structure("UUID", New UUID(ID));
	BackgroundJobArray = BackgroundJobs.GetBackgroundJobs(Filter);
	If BackgroundJobArray.Count() = 1 Then
		BackgroundJob = BackgroundJobArray[0];
	Else
		Raise NStr("en = 'Background task is not found on the server.'");
	EndIf;
	
	If BackgroundJob.State <> BackgroundJobState.Active Then
		Raise NStr("en = 'Task is not performed, it can not be canceled.'");
	EndIf;
	
	BackgroundJob.Cancel();
	
EndProcedure

// Returns table of background jobs properties.
//  For the table structure, see the BackgroundJobsPropertiesEmptyTable() function.
// 
// Parameters:
//  Filter        - Structure - allowed fields:
//                 ID, Key, State,
//                 Begin, End, Name, MethodName, ScheduledJob. 
//
// Returns:
//  ValueTable  - table is returned after filter.
//
Function GetBackgroundJobsPropertiesTable(Filter = Undefined) Export
	
	CallExceptionIfNoAdminPrivileges();
	SetPrivilegedMode(True);
	
	Table = EmptyTableOfBackgroundJobProperties();
	
	If ValueIsFilled(Filter) AND Filter.Property("GetLastBackgroundJobOfScheduledJob") Then
		Filter.Delete("GetLastBackgroundJobOfScheduledJob");
		GetLast = True;
	Else
		GetLast = False;
	EndIf;
	
	ScheduledJob = Undefined;
	
	// Add history of the background jobs received from server.
	If ValueIsFilled(Filter) AND Filter.Property("ScheduledJobID") Then
		If Filter.ScheduledJobID <> "" Then
			ScheduledJob = ScheduledJobs.FindByUUID(
				New UUID(Filter.ScheduledJobID));
			CurrentFilter = New Structure("Key", Filter.ScheduledJobID);
			BackgroundJobsRunManually = BackgroundJobs.GetBackgroundJobs(CurrentFilter);
			If ScheduledJob <> Undefined Then
				LastBackgroundJob = ScheduledJob.LastJob;
			EndIf;
			If Not GetLast OR LastBackgroundJob = Undefined Then
				CurrentFilter = New Structure("ScheduledJob", ScheduledJob);
				AutoBackgroundJobs = BackgroundJobs.GetBackgroundJobs(CurrentFilter);
			EndIf;
			If GetLast Then
				If LastBackgroundJob = Undefined Then
					LastBackgroundJob = LastBackgroundJobInArray(AutoBackgroundJobs);
				EndIf;
				
				LastBackgroundJob = LastBackgroundJobInArray(
					BackgroundJobsRunManually, LastBackgroundJob);
				
				If LastBackgroundJob <> Undefined Then
					BackgroundJobArray = New Array;
					BackgroundJobArray.Add(LastBackgroundJob);
					AddBackgroundJobsProperties(BackgroundJobArray, Table);
				EndIf;
				Return Table;
			EndIf;
			AddBackgroundJobsProperties(BackgroundJobsRunManually, Table);
			AddBackgroundJobsProperties(AutoBackgroundJobs, Table);
		Else
			BackgroundJobArray = New Array;
			ScheduledJobsAllIDs = New Map;
			For Each CurrentJob IN ScheduledJobs.GetScheduledJobs() Do
				ScheduledJobsAllIDs.Insert(
					String(CurrentJob.UUID), True);
			EndDo;
			AllBackgroundJobs = BackgroundJobs.GetBackgroundJobs();
			For Each CurrentJob IN AllBackgroundJobs Do
				If CurrentJob.ScheduledJob = Undefined
				   AND ScheduledJobsAllIDs[CurrentJob.Key] = Undefined Then
				
					BackgroundJobArray.Add(CurrentJob);
				EndIf;
			EndDo;
			AddBackgroundJobsProperties(BackgroundJobArray, Table);
		EndIf;
	Else
		If Not ValueIsFilled(Filter) Then
			BackgroundJobArray = BackgroundJobs.GetBackgroundJobs();
		Else
			If Filter.Property("ID") Then
				Filter.Insert("UUID", New UUID(Filter.ID));
				Filter.Delete("ID");
			EndIf;
			BackgroundJobArray = BackgroundJobs.GetBackgroundJobs(Filter);
			If Filter.Property("UUID") Then
				Filter.Insert("ID", String(Filter.UUID));
				Filter.Delete("UUID");
			EndIf;
		EndIf;
		AddBackgroundJobsProperties(BackgroundJobArray, Table);
	EndIf;
	
	If ValueIsFilled(Filter) AND Filter.Property("ScheduledJobID") Then
		ScheduledJobsForProcessing = New Array;
		If Filter.ScheduledJobID <> "" Then
			If ScheduledJob = Undefined Then
				ScheduledJob = ScheduledJobs.FindByUUID(
					New UUID(Filter.ScheduledJobID));
			EndIf;
			If ScheduledJob <> Undefined Then
				ScheduledJobsForProcessing.Add(ScheduledJob);
			EndIf;
		EndIf;
	Else
		ScheduledJobsForProcessing = ScheduledJobs.GetScheduledJobs();
	EndIf;
	
	Table.Sort("Begin Desc, End Desc");
	
	// Background jobs filter.
	If ValueIsFilled(Filter) Then
		Begin    = Undefined;
		End     = Undefined;
		State = Undefined;
		If Filter.Property("Begin") Then
			Begin = ?(ValueIsFilled(Filter.Begin), Filter.Begin, Undefined);
			Filter.Delete("Begin");
		EndIf;
		If Filter.Property("End") Then
			End = ?(ValueIsFilled(Filter.End), Filter.End, Undefined);
			Filter.Delete("End");
		EndIf;
		If Filter.Property("State") Then
			If TypeOf(Filter.State) = Type("Array") Then
				State = Filter.State;
				Filter.Delete("State");
			EndIf;
		EndIf;
		
		If Filter.Count() <> 0 Then
			Rows = Table.FindRows(Filter);
		Else
			Rows = Table;
		EndIf;
		// Additional filter execution by period and state (if the filter is defined).
		ItemNumber = Rows.Count() - 1;
		While ItemNumber >= 0 Do
			If Begin    <> Undefined AND Begin > Rows[ItemNumber].Begin OR
				 End     <> Undefined AND End  < ?(ValueIsFilled(Rows[ItemNumber].End), Rows[ItemNumber].End, CurrentSessionDate()) OR
				 State <> Undefined AND State.Find(Rows[ItemNumber].State) = Undefined Then
				Rows.Delete(ItemNumber);
			EndIf;
			ItemNumber = ItemNumber - 1;
		EndDo;
		// Delete extra rows from table.
		If TypeOf(Rows) = Type("Array") Then
			LineNumber = Table.Count() - 1;
			While LineNumber >= 0 Do
				If Rows.Find(Table[LineNumber]) = Undefined Then
					Table.Delete(Table[LineNumber]);
				EndIf;
				LineNumber = LineNumber - 1;
			EndDo;
		EndIf;
	EndIf;
	
	Return Table;
	
EndFunction

// Returns the BackgroundJob properties by the unique ID string.
// 
// Parameters:
//  ID - String - BackgroundJob unique ID.
//  PropertyNames  - String if it is filled in, the structure with the specified properties is returned.
// 
// Returns:
//  ValueTableRow, Structure - BackgroundJob properties.
//
Function GetBackgroundJobProperties(ID, PropertyNames = "") Export
	
	CallExceptionIfNoAdminPrivileges();
	SetPrivilegedMode(True);
	
	Filter = New Structure("ID", ID);
	BackgroundJobPropertyTable = GetBackgroundJobsPropertiesTable(Filter);
	
	If BackgroundJobPropertyTable.Count() > 0 Then
		If ValueIsFilled(PropertyNames) Then
			Result = New Structure(PropertyNames);
			FillPropertyValues(Result, BackgroundJobPropertyTable[0]);
		Else
			Result = BackgroundJobPropertyTable[0];
		EndIf;
	Else
		Result = Undefined;
	EndIf;
	
	Return Result;
	
EndFunction

// Returns properties of the last background job completed while executing scheduled job if any.
// Procedure works in the file-server mode as well as in the client-server one.
//
// Parameters:
//  ScheduledJob - ScheduledJob, String - ScheduledJob unique identifier string.
//
// Returns:
//  ValueTableRow, Undefined.
//
Function GetScheduledJobExecutionLastBackgroundJobProperties(ScheduledJob) Export
	
	CallExceptionIfNoAdminPrivileges();
	SetPrivilegedMode(True);
	
	ScheduledJobID = ?(TypeOf(ScheduledJob) = Type("ScheduledJob"), String(ScheduledJob.UUID), ScheduledJob);
	Filter = New Structure;
	Filter.Insert("ScheduledJobID", ScheduledJobID);
	Filter.Insert("GetLastBackgroundJobOfScheduledJob");
	BackgroundJobPropertyTable = GetBackgroundJobsPropertiesTable(Filter);
	BackgroundJobPropertyTable.Sort("End Asc");
	
	If BackgroundJobPropertyTable.Count() = 0 Then
		BackgroundJobProperties = Undefined;
	ElsIf Not ValueIsFilled(BackgroundJobPropertyTable[0].End) Then
		BackgroundJobProperties = BackgroundJobPropertyTable[0];
	Else
		BackgroundJobProperties = BackgroundJobPropertyTable[BackgroundJobPropertyTable.Count()-1];
	EndIf;
	
	Return BackgroundJobProperties;
	
EndFunction

// Returns a multi-line String containing Messages
// and ErrorIndormationDescription if background job is found by an identifier and there are messages/errors.
//
// Parameters:
//  Task      - String - UnigueID of BackgroundJob as a string.
//
// Returns:
//  Row.
//
Function MessagesAndDescriptionsOfBackgroundJobErrors(ID, BackgroundJobProperties = Undefined) Export
	
	CallExceptionIfNoAdminPrivileges();
	SetPrivilegedMode(True);
	
	If BackgroundJobProperties = Undefined Then
		BackgroundJobProperties = GetBackgroundJobProperties(ID);
	EndIf;
	
	String = "";
	If BackgroundJobProperties <> Undefined Then
		For Each Message IN BackgroundJobProperties.UserMessages Do
			String = String + ?(String = "",
			                    "",
			                    "
			                    |
			                    |") + Message.Text;
		EndDo;
		If ValueIsFilled(BackgroundJobProperties.ErrorDetails) Then
			String = String + ?(String = "",
			                    BackgroundJobProperties.ErrorDetails,
			                    "
			                    |
			                    |" + BackgroundJobProperties.ErrorDetails);
		EndIf;
	EndIf;
	
	Return String;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// Returns new table of background jobs properties.
//
// Returns:
//  ValuesTable.
//
Function EmptyTableOfBackgroundJobProperties()
	
	NewTable = New ValueTable;
	NewTable.Columns.Add("ID",                     New TypeDescription("String"));
	NewTable.Columns.Add("Description",                      New TypeDescription("String"));
	NewTable.Columns.Add("Key",                              New TypeDescription("String"));
	NewTable.Columns.Add("Begin",                            New TypeDescription("Date"));
	NewTable.Columns.Add("End",                             New TypeDescription("Date"));
	NewTable.Columns.Add("ScheduledJobID", New TypeDescription("String"));
	NewTable.Columns.Add("State",                         New TypeDescription("BackgroundJobState"));
	NewTable.Columns.Add("MethodName",                         New TypeDescription("String"));
	NewTable.Columns.Add("Location",                      New TypeDescription("String"));
	NewTable.Columns.Add("ErrorDetails",        New TypeDescription("String"));
	NewTable.Columns.Add("StartAttempt",                    New TypeDescription("Number"));
	NewTable.Columns.Add("UserMessages",             New TypeDescription("Array"));
	NewTable.Columns.Add("SessionNumber",                       New TypeDescription("Number"));
	NewTable.Columns.Add("SessionStarted",                      New TypeDescription("Date"));
	NewTable.Indexes.Add("ID, Begin");
	
	Return NewTable;
	
EndFunction

Procedure AddBackgroundJobsProperties(Val BackgroundJobArray, Val BackgroundJobPropertyTable)
	
	IndexOf = BackgroundJobArray.Count() - 1;
	While IndexOf >= 0 Do
		BackgroundJob = BackgroundJobArray[IndexOf];
		String = BackgroundJobPropertyTable.Add();
		FillPropertyValues(String, BackgroundJob);
		String.ID = BackgroundJob.UUID;
		ScheduledJob = BackgroundJob.ScheduledJob;
		
		If ScheduledJob = Undefined
		   AND StringFunctionsClientServer.ThisIsUUID(BackgroundJob.Key) Then
			
			ScheduledJob = ScheduledJobs.FindByUUID(New UUID(BackgroundJob.Key));
		EndIf;
		String.ScheduledJobID = ?(
			ScheduledJob = Undefined,
			"",
			ScheduledJob.UUID);
		
		String.ErrorDetails = ?(
			BackgroundJob.ErrorInfo = Undefined,
			"",
			DetailErrorDescription(BackgroundJob.ErrorInfo));
		
		IndexOf = IndexOf - 1;
	EndDo;
	
EndProcedure

Function LastBackgroundJobInArray(BackgroundJobArray, LastBackgroundJob = Undefined)
	
	For Each CurrentBackgroundJob IN BackgroundJobArray Do
		If LastBackgroundJob = Undefined Then
			LastBackgroundJob = CurrentBackgroundJob;
			Continue;
		EndIf;
		If ValueIsFilled(LastBackgroundJob.End) Then
			If Not ValueIsFilled(CurrentBackgroundJob.End)
			 OR LastBackgroundJob.End < CurrentBackgroundJob.End Then
				LastBackgroundJob = CurrentBackgroundJob;
			EndIf;
		Else
			If Not ValueIsFilled(CurrentBackgroundJob.End)
			   AND LastBackgroundJob.Begin < CurrentBackgroundJob.Begin Then
				LastBackgroundJob = CurrentBackgroundJob;
			EndIf;
		EndIf;
	EndDo;
	
	Return LastBackgroundJob;
	
EndFunction

#EndRegion
