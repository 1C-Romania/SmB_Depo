&AtClient
Var CheckIteration;

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		FormHeaderText = NStr("en='Donwload data to local version';ru='Выгрузить данные в локальную версию'");
		MessageText      = NStr("en='Data from the service will be exported to the
		|file for its following import and use in the local version.';ru='Данные из сервиса будут выгружены в файл
		|для последующей их загрузки и использования в локальной версии.'");
	Else
		FormHeaderText = NStr("en='Export data for migration to service';ru='Выгрузить данные для перехода в сервис'");
		MessageText      = NStr("en='Data from the local version will be exported to the
		|file for its following import and use in the service mode.';ru='Данные из локальной версии будут выгружены в
		|файл для последующей их загрузки и использования в режиме сервиса.'");
	EndIf;
	Items.WarningDecoration.Title = MessageText;
	Title = FormHeaderText;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure OpenActiveUsersForm(Command)
	
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ExportData(Command)
	
	StartDataExportAtServer();
	
	Items.GroupPages.CurrentPage = Items.Export;
	
	CheckIteration = 1;
	
	AttachIdleHandler("CheckExportReadyState", 15);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient 
Procedure SaveExportFile()
	
	FileName = "data_dump.zip";
	
	DialogueParameters = New Structure;
	DialogueParameters.Insert("Filter", "ZIP archive(*.zip)|*.zip");
	DialogueParameters.Insert("Extension", "zip");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("FileName", FileName);
	AdditionalParameters.Insert("DialogueParameters", DialogueParameters);
	
	AlertFileOperationsConnectionExtension = New NotifyDescription(
		"SelectAndSaveFileAfterConnectionFileOperationsExtension",
		ThisForm, AdditionalParameters);
	
	BeginAttachingFileSystemExtension(AlertFileOperationsConnectionExtension);
	
EndProcedure

&AtClient 
Procedure SelectAndSaveFileAfterConnectionFileOperationsExtension(Attached, AdditionalParameters) Export
	
	If Attached Then
		
		FileDialog = New FileDialog(FileDialogMode.Save);
		FillPropertyValues(FileDialog, AdditionalParameters.DialogueParameters);
		
		FilesToReceive = New Array;
		FilesToReceive.Add(New TransferableFileDescription(AdditionalParameters.FileName, StorageAddress));
		
		FilesReceiptAlertDescription = New NotifyDescription(
			"SelectAndSaveFile",
			ThisForm, AdditionalParameters);
		
		BeginGettingFiles(FilesReceiptAlertDescription, FilesToReceive, FileDialog, True);
		
	Else
		
		GetFile(StorageAddress, AdditionalParameters.FileName, True);
		Close();
		
	EndIf;
	
EndProcedure

&AtClient 
Procedure SelectAndSaveFile(ReceivedFiles, AdditionalParameters) Export
	
	Close();
	
EndProcedure

&AtServerNoContext
Procedure SwitchOffExclusiveModeAfterExport()
	
	SetExclusiveMode(False);
	
EndProcedure

&AtClient
Procedure CheckExportReadyState()
	
	Try
		ExportReadyState = ExportDataReady();
	Except
		
		ErrorInfo = ErrorInfo();
		
		DetachIdleHandler("CheckExportReadyState");
		SwitchOffExclusiveModeAfterExport();
		
		HandleError(
			BriefErrorDescription(ErrorInfo),
			DetailErrorDescription(ErrorInfo));
		
	EndTry;
	
	If ExportReadyState Then
		SwitchOffExclusiveModeAfterExport();
		DetachIdleHandler("CheckExportReadyState");
		SaveExportFile();
	Else
		
		CheckIteration = CheckIteration + 1;
		
		If CheckIteration = 3 Then
			DetachIdleHandler("CheckExportReadyState");
			AttachIdleHandler("CheckExportReadyState", 30);
		ElsIf CheckIteration = 4 Then
			DetachIdleHandler("CheckExportReadyState");
			AttachIdleHandler("CheckExportReadyState", 60);
		EndIf;
			
	EndIf;
	
EndProcedure

&AtServerNoContext
Function FindJobByID(ID)
	
	Task = BackgroundJobs.FindByUUID(ID);
	
	Return Task;
	
EndFunction

&AtServer
Function ExportDataReady()
	
	Task = FindJobByID(JobID);
	
	If Task <> Undefined
		AND Task.State = BackgroundJobState.Active Then
		
		Return False;
	EndIf;
	
	Items.GroupPages.CurrentPage = Items.Warning;
	
	If Task = Undefined Then
		Raise(NStr("en='During the export preparation an error has occurred - job that prepares the exporting has not been found.';ru='При подготовке выгрузки произошла ошибка - не найдено задание подготавливающее выгрузку.'"));
	EndIf;
	
	If Task.State = BackgroundJobState.Failed Then
		JobError = Task.ErrorInfo;
		If JobError <> Undefined Then
			Raise(DetailErrorDescription(JobError));
		Else
			Raise(NStr("en='When getting prepared for export an error has occurred - the job preparing the export has been terminated with the unknown error.';ru='При подготовке выгрузки произошла ошибка - задание подготавливающее выгрузку завершилось с неизвестной ошибкой.'"));
		EndIf;
	ElsIf Task.State = BackgroundJobState.Canceled Then
		Raise(NStr("en='During the export preparation an error has occurred - the job preparing the export has been cancelled by the administrator.';ru='При подготовке выгрузки произошла ошибка - задание подготавливающее выгрузку было отменено администратором.'"));
	Else
		JobID = Undefined;
		Return True;
	EndIf;
	
EndFunction

&AtServer
Procedure StartDataExportAtServer()
	
	SetExclusiveMode(True);
	
	Try
		
		StorageAddress = PutToTempStorage(Undefined, UUID);
		
		JobParameters = New Array;
		JobParameters.Add(StorageAddress);
		
		Task = BackgroundJobs.Execute("DataAreasExportImport.ExportCurrentDataAreaIntoTemporaryStorage", 
			JobParameters,
			,
			NStr("en='Data area export preparation';ru='Подготовка выгрузки области данных'"));
			
		JobID = Task.UUID;
		
	Except
		
		ErrorInfo = ErrorInfo();
		SetExclusiveMode(False);
		HandleError(
			BriefErrorDescription(ErrorInfo),
			DetailErrorDescription(ErrorInfo));
		
	EndTry;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If ValueIsFilled(JobID) Then
		CancelInitializationJob(JobID);
		SwitchOffExclusiveModeAfterExport();
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure CancelInitializationJob(Val JobID)
	
	Task = FindJobByID(JobID);
	If Task = Undefined
		OR Task.State <> BackgroundJobState.Active Then
		
		Return;
	EndIf;
	
	Try
		Task.Cancel();
	Except
		// The job might end at the moment and there is no error.
		WriteLogEvent(NStr("en='Cancelling the job of preparation to data area export';ru='Отмена выполнения задания подготовки выгрузки области данных'", 
			CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

&AtServerNoContext
Procedure HandleError(Val ShortPresentation, Val DetailedPresentation)
	
	WriteLogEventTemplate = NStr("en='An error occurred while exporting the data: ----------------------------------------- %1 -----------------------------------------';ru='При выгрузке данных произошла ошибка: ----------------------------------------- %1 -----------------------------------------'");
	WriteLogEventText = StringFunctionsClientServer.SubstituteParametersInString(WriteLogEventTemplate, DetailedPresentation);
	
	WriteLogEvent(
		NStr("en='Data export';ru='Экспорт данных'"),
		EventLogLevel.Error,
		,
		,
		WriteLogEventText);
	
	ExceptionPattern = NStr("en='An error occurred while exporting the data: %1.
		|
		|Detailed information for support service is written to the events log monitor. If you do not know the reason of error, you are recommended to contact the technical support service providing to them the infobase and exported event log monitor for investigation.';ru='При выгрузке данных произошла ошибка: %1.
		|
		|Расширенная информация для службы поддержки записана в журнал регистрации. Если Вам неизвестна причина ошибки - рекомендуется обратиться в службу технической поддержки, предоставив для расследования информационную базу и выгрузку журнала регистрации.'");
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(ExceptionPattern, ShortPresentation);
	
EndProcedure
