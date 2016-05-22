////////////////////////////////////////////////////////////////////////////////
// Subsystem "Performance estimation".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers["StandardSubsystems.BasicFunctionality\BeforeExit"].Add(
		"PerformanceEstimationClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddSessionSettingsSetupHandler"].Add(
		"PerformanceEstimationService");
		
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources"].Add(
			"PerformanceEstimationService");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Returns a match of session parameters and handlers parameters to initialize them.
//
Procedure OnAddSessionSettingsSetupHandler(Handlers) Export
	
	Handlers.Insert("CurrentTimeMeasurement", "PerformanceEstimationServerCall.SessionParameterSetting");
	
EndProcedure

// Fills out a list of queries for external permissions
// that must be provided when creating an infobase or updating a application.
//
// Parameters:
//  PermissionsQueries - Array - list of values returned by the function.
//                      WorkInSafeMode.QueryOnExternalResourcesUse().
//
Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	ExportDirectories = ExportDirectoriesPerformance();
	If ExportDirectories = Undefined Then
		Return;
	EndIf;
	
	URLStructure = CommonUseClientServer.URLStructure(ExportDirectories.FTPExportDirectory);
	ExportDirectories.Insert("FTPExportDirectory", URLStructure.ServerName);
	If ValueIsFilled(URLStructure.Port) Then
		ExportDirectories.Insert("ExportDirectoryFTPPort", URLStructure.Port);
	EndIf;
	
	PermissionsQueries.Add(
		WorkInSafeMode.QueryOnExternalResourcesUse(
			PermissionsOnServerResources(ExportDirectories), 
				CommonUse.MetadataObjectID("Constant.ExecutePerformanceMeasurements")));
	
EndProcedure

// Only for internal use.
Function QueryOnExternalResourcesUse(Directories) Export
	
	Return WorkInSafeMode.QueryOnExternalResourcesUse(
				PermissionsOnServerResources(Directories), 
					CommonUse.MetadataObjectID("Constant.ExecutePerformanceMeasurements"));
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Export service procedures and functions.

// Finds and returns time measurement export scheduled job.
//
// Returns:
//  ScheduledJob - ScheduledJob.PerformanceEstimationExport, found job.
//
Function PerformanceEstimationExportScheduledJob() Export
	
	SetPrivilegedMode(True);
	Jobs = ScheduledJobs.GetScheduledJobs(
		New Structure("Metadata", "ExportPerformanceEstimation"));
	If Jobs.Count() = 0 Then
		Job = ScheduledJobs.CreateScheduledJob(
			Metadata.ScheduledJobs.ExportPerformanceEstimation);
		Job.Write();
		Return Job;
	Else
		Return Jobs[0];
	EndIf;
		
EndFunction

// Returns file export directories with measurement results.
//
// Parameters:
// No
//
// Returns:
//    Structure
//        "ExecuteExportOnFTP"            - Boolean - Execution flag of export to FTP
//        "FTPExportDirectory"            - String - FTP-directory of export
//        "ExecuteExportToLocalDirectory" - Boolean - Flag of export to local directory
//        "LocalExportDirectory"          - String - Local export directory.
//
Function ExportDirectoriesPerformance() Export
	
	Task = PerformanceEstimationExportScheduledJob();
	Directories = New Structure;
	If Task.Parameters.Count() > 0 Then
		Directories = Task.Parameters[0];
	EndIf;
	
	If TypeOf(Directories) <> Type("Structure") OR Directories.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	ReturnValue = New Structure;
	ReturnValue.Insert("PerformExportToFTP");
	ReturnValue.Insert("FTPExportDirectory");
	ReturnValue.Insert("PerformExportInLocalDirectory");
	ReturnValue.Insert("LocalExportDirectory");
	
	KeyElementsOf = New Structure;
	FTPItems = New Array;
	FTPItems.Add("PerformExportToFTP");
	FTPItems.Add("FTPExportDirectory");
	
	LocalItems = New Array;
	LocalItems.Add("PerformExportInLocalDirectory");
	LocalItems.Add("LocalExportDirectory");
	
	KeyElementsOf.Insert(PerformanceEstimationClientServer.FTPExportDirectoryTaskKey(), FTPItems);
	KeyElementsOf.Insert(PerformanceEstimationClientServer.LocalExportDirectoryTaskKey(), LocalItems);
	ToDoExport = False;
	For Each KeyNameItems IN KeyElementsOf Do
		KeyName = KeyNameItems.Key;
		EditingElements = KeyNameItems.Value;
		ItemNumber = 0;
		For Each ElementName IN EditingElements Do
			Value = Directories[KeyName][ItemNumber];
			ReturnValue[ElementName] = Value;
			If ItemNumber = 0 Then 
				ToDoExport = ToDoExport OR Value;
			EndIf;
			ItemNumber = ItemNumber + 1;
		EndDo;
	EndDo;
	
	Return ReturnValue;
	
EndFunction

// Returns reference to item "Total performance",
// if predefined item "GeneralSystemPerformance" exists, then this item is returned.
// Otherwise empty reference is returned.
//
// Parameters:
//  No
// Return value:
//  CatalogRef.KeyOperations
//
Function GetItemGeneralSystemPerformance() Export
	
	PredeterminedTo = Metadata.Catalogs.KeyOperations.GetPredefinedNames();
	ThereIsPredefinedItem = ?(PredeterminedTo.Find("OverallSystemPerformance") <> Undefined, True, False);
	
	QueryText = 
	"SELECT TOP 1
	|	KeyOperations.Ref,
	|	2 AS Priority
	|FROM
	|	Catalog.KeyOperations AS KeyOperations
	|WHERE
	|	KeyOperations.Name = ""OverallSystemPerformance""
	|	AND Not KeyOperations.DeletionMark
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	VALUE(Catalog.KeyOperations.EmptyRef),
	|	3
	|
	|ORDER BY
	|	Priority";
	
	If ThereIsPredefinedItem Then
		QueryText = 
		"SELECT TOP 1
		|	KeyOperations.Ref,
		|	1 AS Priority
		|FROM
		|	Catalog.KeyOperations AS KeyOperations
		|WHERE
		|	KeyOperations.PredefinedDataName = ""OverallSystemPerformance""
		|	AND Not KeyOperations.DeletionMark
		|
		|UNION ALL
		|" + QueryText;
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("KeyOperations", PredeterminedTo);
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return Selection.Ref;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local service procedures and functions.

// Generates the array of permission for export of measurement data.
// 
// Parameters - ExportDirectories - Structure
//
// Returns:
//	Array
Function PermissionsOnServerResources(Directories)
	
	permissions = New Array;
	
	If Directories <> Undefined Then
		If Directories.Property("PerformExportInLocalDirectory") AND Directories.PerformExportInLocalDirectory = True Then
			If Directories.Property("LocalExportDirectory") AND ValueIsFilled(Directories.LocalExportDirectory) Then
				Item = WorkInSafeMode.PermissionToUseFileSystemDirectory(
					Directories.LocalExportDirectory,
					True,
					True,
					NStr("en = 'Network directory for export of performance measurement results.'"));
				permissions.Add(Item);
			EndIf;
		EndIf;
		
		If Directories.Property("PerformExportToFTP") AND Directories.PerformExportToFTP = True Then
			If Directories.Property("FTPExportDirectory") AND ValueIsFilled(Directories.FTPExportDirectory) Then
				Item = WorkInSafeMode.PermissionForWebsiteUse(
					"FTP",
					Directories.FTPExportDirectory,
					?(Directories.Property("ExportDirectoryFTPPort"), Directories.ExportDirectoryFTPPort, Undefined),
					NStr("en = 'FTP-resource for export of performance measurement results.'"));
				permissions.Add(Item);
			EndIf;
		EndIf;
	EndIf;
	
	Return permissions;
EndFunction

#EndRegion
