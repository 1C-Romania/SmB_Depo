&AtClient
Var ExternalResourcesAllowed;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ExportDirectories = PerformanceEstimationService.ExportDirectoriesPerformance();
	If TypeOf(ExportDirectories) <> Type("Structure")
		OR
		 ExportDirectories.Count() = 0
	Then
		Return;
	EndIf;
	
	PerformExportToFTP = ExportDirectories.PerformExportToFTP;
	FTPExportDirectory = ExportDirectories.FTPExportDirectory;
	PerformExportInLocalDirectory = ExportDirectories.PerformExportInLocalDirectory;
	LocalExportDirectory = ExportDirectories.LocalExportDirectory;
	
	ToDoExport = PerformExportToFTP Or PerformExportInLocalDirectory;
	
EndProcedure

&AtClient
Procedure ToExportDataIfYouChange(Item)
	ExportIsAllowed = ToDoExport;
	PerformExportInLocalDirectory = ExportIsAllowed;
	PerformExportToFTP = ExportIsAllowed;
EndProcedure	

&AtClient
Procedure ToExportCatalogIfYouChange(Item)
	ToDoExport = PerformExportInLocalDirectory OR PerformExportToFTP;
EndProcedure	

&AtClient
Procedure LocalDirectoryExportFilesBeginningSelection(Item, ChoiceData, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("SelectExportDirectoryItIsProposed", ThisObject);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NOTifyDescription);
	
EndProcedure

&AtServer
Function FillCheckProcessingAtServer()
	ItemsOnControl = New Map;
	ItemsOnControl.Insert(Items.PerformExportInLocalDirectory, Items.LocalExportDirectory);
	ItemsOnControl.Insert(Items.PerformExportToFTP, Items.FTPExportDirectory);
	
	NoErrors = True;	
	For Each SelectPath IN ItemsOnControl Do
		Perform = ThisObject[SelectPath.Key.DataPath];
		PathElement = SelectPath.Value;
		If Perform AND IsBlankString(TrimAll(ThisObject[PathElement.DataPath])) Then
			MessageText = NStr("en='The ""%1"" field is not filled in';ru='Поле ""%1"" не заполнено'");
			MessageText = StrReplace(MessageText, "%1", PathElement.Title);
			CommonUseClientServer.MessageToUser(
				MessageText,
				,
				PathElement.Name,
				PathElement.DataPath);
			NoErrors = False;
		EndIf;
	EndDo;
	
	Return NoErrors;	
EndFunction

&AtServer
Procedure SaveOnServer()
	
	PerformLocalDirectory = New Array;
	PerformLocalDirectory.Add(PerformExportInLocalDirectory);
	PerformLocalDirectory.Add(TrimAll(ThisObject.LocalExportDirectory));
	
	PerformFTPDirectory = New Array;
	PerformFTPDirectory.Add(PerformExportToFTP);
	PerformFTPDirectory.Add(TrimAll(ThisObject.FTPExportDirectory));
	
	SetDirectoryExport(PerformLocalDirectory, PerformFTPDirectory);  

	SetUseScheduledJob(ToDoExport);
	Modified = False;
	
EndProcedure

&AtClient
Procedure LocalExportDirectoryOnChange(Item)
	
	ExternalResourcesAllowed = False;
	
EndProcedure

&AtClient
Procedure FTPExportDirectoryOnChange(Item)
	
	ExternalResourcesAllowed = False;
	
EndProcedure

///////////////////////////////////////////////////////////////////////
// COMMAND HANDLERS

&AtClient
Procedure ConfigureExportSchedule(Command)
	
	JobSchedule = ExportPerformanceSchedule();
	
	Notification = New NotifyDescription("ConfigureExportScheduleEnd", ThisObject);
	Dialog = New ScheduledJobDialog(JobSchedule);
	Dialog.Show(Notification);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SelectExportDirectoryItIsProposed(FileOperationsExtensionConnected, AdditionalParameters) Export
	
	If FileOperationsExtensionConnected Then
		
		FileChoice = New FileDialog(FileDialogMode.ChooseDirectory);
		FileChoice.Multiselect = False;
		FileChoice.Title = NStr("en='Select export directory';ru='Выбор каталога экспорта'");
		
		NotifyDescription = New NotifyDescription("ActionAfterExportDirectorySelection", ThisObject);
		FileChoice.Show(NOTifyDescription);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ActionAfterExportDirectorySelection(Result, AdditionalParameters) Export
	
	If ValueIsFilled(Result) Then
		
		SelectedDirectory = Result;
		LocalExportDirectory = Result;
		ThisObject.Modified = True;
		
	EndIf;
	
EndProcedure

// Changes data export directory.
//
// Parameters:
//  ExportDirectory - A string, new export directory.
//
&AtServerNoContext
Procedure SetDirectoryExport(PerformLocalDirectoryExport, PerformFTPDirectoryExport)
	
	Task = PerformanceEstimationService.PerformanceEstimationExportScheduledJob();
	
	Directories = New Structure();
	Directories.Insert(PerformanceEstimationClientServer.LocalExportDirectoryTaskKey(), PerformLocalDirectoryExport);
	Directories.Insert(PerformanceEstimationClientServer.FTPExportDirectoryTaskKey(), PerformFTPDirectoryExport);
	
	JobParameters = New Array;	
	JobParameters.Add(Directories);
	Task.Parameters = JobParameters;
	FixRoutineJob(Task);
	
EndProcedure

// Changes usage flag of scheduled job.
//
// Parameters:
//  NewValue - A Boolean, new usage value.
//
// Returns:
//  Boolean - state before change (previous state).
//
&AtServerNoContext
Function SetUseScheduledJob(NewValue)
	
	Task = PerformanceEstimationService.PerformanceEstimationExportScheduledJob();
	CurrentState = Task.Use;
	If CurrentState <> NewValue Then
		Task.Use = NewValue;
		FixRoutineJob(Task);
	EndIf;
	
	Return CurrentState;
	
EndFunction

// Returns the current schedule of scheduled job.
//
// Returns:
//  JobSchedule - current schedule.
//
&AtServerNoContext
Function ExportPerformanceSchedule()
	
	Task = PerformanceEstimationService.PerformanceEstimationExportScheduledJob();
	Return Task.Schedule;
	
EndFunction

// Sets the new schedule for scheduled job.
//
// Parameters:
//  NewSchedule - ScheduledJobSchedule which is to be enabled.
//
&AtServerNoContext
Procedure SetSchedule(Val NewSchedule)
	
	Task = PerformanceEstimationService.PerformanceEstimationExportScheduledJob();
	Task.Schedule = NewSchedule;
	FixRoutineJob(Task);
	
EndProcedure

// Saves the scheduled job settings.
//
// Parameters:
//  Task - ScheduledJob.EstimationPerformanceExport
//
&AtServerNoContext
Procedure FixRoutineJob(Task)
	
	SetPrivilegedMode(True);
	Task.Write();
	
EndProcedure

&AtClient
Procedure ConfigureExportScheduleEnd(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		SetSchedule(Schedule);
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveSettings(Command)
	
	If FillCheckProcessingAtServer() Then
		CheckPermissionsOnAccessToExternalResources(False);
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveClose(Command)
	
	If FillCheckProcessingAtServer() Then
		CheckPermissionsOnAccessToExternalResources(True);
	EndIf;
	
EndProcedure

&AtClient
Function CheckPermissionsOnAccessToExternalResources(CloseForm)
	
	If ExternalResourcesAllowed <> True Then
		If CloseForm Then
			ClosingAlert = New NotifyDescription("AllowExternalResourceSaveAndClose", ThisObject);
		Else
			ClosingAlert = New NotifyDescription("AllowExternalResourceSave", ThisObject);
		EndIf;
		
		Directories = New Structure;
		Directories.Insert("PerformExportToFTP", PerformExportToFTP);
		
		URLStructure = CommonUseClientServer.URLStructure(FTPExportDirectory);
		Directories.Insert("FTPExportDirectory", URLStructure.ServerName);
		If ValueIsFilled(URLStructure.Port) Then
			Directories.Insert("ExportDirectoryFTPPort", URLStructure.Port);
		EndIf;
		
		Directories.Insert("PerformExportInLocalDirectory", PerformExportInLocalDirectory);
		Directories.Insert("LocalExportDirectory", LocalExportDirectory);
		
		Query = QueryOnExternalResourcesUse(Directories);
		
		WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(
			CommonUseClientServer.ValueInArray(Query), ThisObject, ClosingAlert);
			
	ElsIf CloseForm Then
		SaveOnServer();
		ThisObject.Close();
		
	Else
		SaveOnServer();
	EndIf;
	
EndFunction

&AtServerNoContext
Function QueryOnExternalResourcesUse(Directories)
	
	Return PerformanceEstimationService.QueryOnExternalResourcesUse(Directories);
	
EndFunction

&AtClient
Procedure AllowExternalResourceSaveAndClose(Result, NotSpecified) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		SaveOnServer();
		ThisObject.Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowExternalResourceSave(Result, NotSpecified) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		SaveOnServer();
	EndIf;
	
EndProcedure

#EndRegion
