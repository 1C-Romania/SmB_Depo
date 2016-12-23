&AtClient
Var JobActive;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	StorageAddress = PutToTempStorage(Undefined, New UUID);
	StorageAddressStates = PutToTempStorage(Undefined, New UUID);
	
	Items.Close.Enabled = Not Parameters.CheckMode;
	
	StartRequestsProcessing(
		Parameters.IDs,
		Parameters.ConnectMode,
		Parameters.DisconnectMode,
		Parameters.RecoveryMode,
		Parameters.CheckMode);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	JobActive = True;
	CheckIteration = 1;
	EnableRequestsProcessingAwaitingHandler(3);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If JobActive Then
		
		CancelRequestsProcessing(JobID);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function StartRequestsProcessing(Val Queries, Val ConnectMode, DisconnectMode, Val RecoveryMode, Val UsageCheckMode)
	
	If ConnectMode Then
		
		JobParameters = New Array();
		JobParameters.Add(StorageAddress);
		JobParameters.Add(StorageAddressStates);
		
		MethodCallParameters = New Array();
		MethodCallParameters.Add("DataProcessors.PermissionSettingsForExternalResourcesUse.ProcessUpdateRequests");
		MethodCallParameters.Add(JobParameters);
		
	ElsIf DisconnectMode Then
		
		JobParameters = New Array();
		JobParameters.Add(StorageAddress);
		JobParameters.Add(StorageAddressStates);
		
		MethodCallParameters = New Array();
		MethodCallParameters.Add("DataProcessors.PermissionSettingsForExternalResourcesUse.ProcessDisconnectionRequests");
		MethodCallParameters.Add(JobParameters);
		
	ElsIf RecoveryMode Then
		
		JobParameters = New Array();
		JobParameters.Add(StorageAddress);
		JobParameters.Add(StorageAddressStates);
		
		MethodCallParameters = New Array();
		MethodCallParameters.Add("DataProcessors.PermissionSettingsForExternalResourcesUse.ProcessRecoveryRequests");
		MethodCallParameters.Add(JobParameters);
		
	Else
		
		JobParameters = New Array();
		JobParameters.Add(Queries);
		JobParameters.Add(StorageAddress);
		JobParameters.Add(StorageAddressStates);
		
		MethodCallParameters = New Array();
		MethodCallParameters.Add("DataProcessors.PermissionSettingsForExternalResourcesUse.ProcessRequests");
		MethodCallParameters.Add(JobParameters);
		
	EndIf;
	
	Task = BackgroundJobs.Execute("WorkInSafeMode.ExecuteConfigurationMethod",
			MethodCallParameters,
			,
			NStr("en='Processing requests to use external resources...';ru='Обработка запросов на использование внешних ресурсов...'"));
	
	JobID = Task.UUID;
	
	Return StorageAddress;
	
EndFunction

&AtClient
Procedure ValidateRequestsProcessing()
	
	Try
		Readiness = RequestsProcessed(JobID);
	Except
		JobActive = False;
		Result = New Structure();
		Result.Insert("ReturnCode", DialogReturnCode.Cancel);
		Close(Result);
		Raise;
	EndTry;
	
	If Readiness Then
		JobActive = False;
		EndRequestsProcessing();
	Else
		
		CheckIteration = CheckIteration + 1;
		
		If CheckIteration = 2 Then
			EnableRequestsProcessingAwaitingHandler(5);
		ElsIf CheckIteration = 3 Then
			EnableRequestsProcessingAwaitingHandler(8);
		Else
			EnableRequestsProcessingAwaitingHandler(10);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function RequestsProcessed(Val JobID)
	
	Task = BackgroundJobs.FindByUUID(JobID);
	
	If Task <> Undefined
		AND Task.State = BackgroundJobState.Active Then
		
		Return False;
	EndIf;
	
	If Task = Undefined Then
		Raise(NStr("en='An error occurred while processing requests. A job to process the requests is not found.';ru='При обработке запросов произошла ошибка - не найдено задание обработки запросов.'"));
	EndIf;
	
	If Task.State = BackgroundJobState.Failed Then
		JobError = Task.ErrorInfo;
		If JobError <> Undefined Then
			Raise(DetailErrorDescription(JobError));
		Else
			Raise(NStr("en='An error occurred while processing requests. A job to process the requests is terminated with an unknown error.';ru='При обработке запросов произошла ошибка - задание обработки запросов завершилось с неизвестной ошибкой.'"));
		EndIf;
	ElsIf Task.State = BackgroundJobState.Canceled Then
		Raise(NStr("en='An error occurred while processing requests. A job to process the requests is terminated by administrator.';ru='При обработке запросов произошла ошибка - задание обработки запросов было отменено администратором.'"));
	Else
		JobID = Undefined;
		Return True;
	EndIf;
	
EndFunction

&AtClient
Procedure EndRequestsProcessing()
	
	JobActive = False;
	
	If IsOpen() Then
		
		Result = New Structure();
		Result.Insert("ReturnCode", DialogReturnCode.OK);
		Result.Insert("StorageAddressStates", StorageAddressStates);
		
		Close(Result);
		
	Else
		
		NotifyDescription = ThisObject.OnCloseNotifyDescription;
		If NotifyDescription <> Undefined Then
			ExecuteNotifyProcessing(NOTifyDescription, DialogReturnCode.OK);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure CancelRequestsProcessing(Val JobID)
	
	Task = BackgroundJobs.FindByUUID(JobID);
	
	If Task = Undefined OR Task.State <> BackgroundJobState.Active Then
		Return;
	EndIf;
	
	Try
		Task.Cancel();
	Except
		// The job might end at the moment and there is no error.
		WriteLogEvent(NStr("en='Configure permissions to use external resources. Cancel background job';ru='Настройка разрешений на использование внешних ресурсов.Отмена выполнения фонового задания'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

&AtClient
Procedure EnableRequestsProcessingAwaitingHandler(Val Interval)
	
	AttachIdleHandler("ValidateRequestsProcessing", Interval, True);
	
EndProcedure

#EndRegion













