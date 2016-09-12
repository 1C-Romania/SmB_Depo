&AtClient
Var ContituationParameters;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	IBVersionUpdateIsExecuted = True;
	UpdateBeginTime = CurrentSessionDate();
	
	BeginStepProgress = 5;
	ProgressStepLength  = 5;
	PerformanceProgress = BeginStepProgress;
	
	DataUpdateMode = InfobaseUpdateService.DataUpdateMode();
	
	OnlyApplicationWorkParametersUpdate =
		Not InfobaseUpdate.InfobaseUpdateRequired();
	
	If OnlyApplicationWorkParametersUpdate Then
		Title = NStr("en='Update application parameters';ru='Обновление параметров работы программы'");
		Items.RunMode.CurrentPage = Items.ApplicationWorkParametersUpdate;
		ProgressStepLength = 95;
		
	ElsIf DataUpdateMode = "InitialFilling" Then
		Title = NStr("en='Initial data filling';ru='Начальное заполнение данных'");
		Items.RunMode.CurrentPage = Items.InitialFilling;
		
	ElsIf DataUpdateMode = "TransitionFromAnotherApplication" Then
		Title = NStr("en='Transition from another application';ru='Переход с другой программы'");
		Items.RunMode.CurrentPage = Items.TransitionFromAnotherApplication;
		Items.MessageTextTransitionFromAnotherApplication.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			Items.MessageTextTransitionFromAnotherApplication.Title, Metadata.Synonym);
	Else
		Title = NStr("en='Application version update';ru='Обновление версии программы'");
		Items.RunMode.CurrentPage = Items.ApplicationVersionUpdate;
		Items.MessageTextUpdatedConfiguration.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			Items.MessageTextUpdatedConfiguration.Title, Metadata.Synonym, Metadata.Version);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If IBVersionUpdateIsExecuted Then
		Cancel = True;
	ElsIf ExclusiveModeIsInstalled Then
		SwitchOffSoleMode();
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure TechnicalInformationClick(Item)
	FilterParameters = New Structure;
	FilterParameters.Insert("RunNotInBackground", True);
	
	OpenForm("DataProcessor.EventLogMonitor.Form.EventLogMonitor", FilterParameters);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Update application work parameters and undivided data in service.

&AtServerNoContext
Procedure SwitchOffSoleMode()
	
	If ExclusiveMode() Then
		SetExclusiveMode(False);
	EndIf;
	
	ExclusiveModeIsInstalled = False;
	
EndProcedure

&AtClient
Procedure ImportRefreshApplicationWorkParameters(Parameters) Export
	
	ContituationParameters = Parameters;
	
	AttachIdleHandler("ImportUpdateApplicationWorkParametersStart", 0.1, True);
	
EndProcedure

&AtClient
Procedure ImportUpdateApplicationWorkParametersStart()
	
	// Long operation handler parameters.
	HandlerParameters = New Structure;
	HandlerParameters.Insert("MinInterval", 1);
	HandlerParameters.Insert("MaxInterval", 15);
	HandlerParameters.Insert("CurrentInterval", 1);
	HandlerParameters.Insert("IntervalIncreaseCoefficient", 1.4);
	
	BackgroundJobStorageAddress = Undefined;
	BackgroundJobID  = Undefined;
	
	ExecutionResult = ImportUpdateApplicationWorkInBackgroundParameters();
	
	If ExecutionResult.JobCompleted
	 Or ExecutionResult.AShortErrorMessage <> Undefined Then
		
		ImportUpdateApplicationWorkParametersProcessResult(
			ExecutionResult.AShortErrorMessage,
			ExecutionResult.DetailedErrorMessage);
	Else
		AttachIdleHandler("UpdateApplicationWorkParametersCheckOnClient", 1, True);
	EndIf;
	
EndProcedure

&AtServer
Function ImportUpdateApplicationWorkInBackgroundParameters()
	
	RefreshReusableValues();
	
	CurrentUser = InfobaseUsers.CurrentUser();
	If AccessRight("Administration", Metadata, CurrentUser) Then
		SetPrivilegedMode(True);
	EndIf;
	
	ErrorInfo = Undefined;
	
	Try
		SetExclusiveMode(True);
		ExclusiveModeIsInstalled = True;
	Except
		// It is not required to call exception as it
		// becomes clear whether it is required to set the exclusive mode only when the background update is executed.
		// That is why the preliminary setting of
		// the exclusive mode reduces the background job extra start when the
		// exclusive mode is required but it can be immediately set without completing user sessions.
	EndTry;
	
	// Background job launch
	DebugMode = CommonUseClientServer.DebugMode();
	ExecuteParameters = New Structure;
	If Not DebugMode Then
		ExecuteParameters.Insert("ClientParametersOnServer", SessionParameters.ClientParametersOnServer);
	EndIf;
	
	Try
		Result = LongActions.ExecuteInBackground(
			UUID,
			"StandardSubsystemsServer.ImportUpdateApplicationWorkInBackgroundParameters",
			ExecuteParameters,
			NStr("en='Background update of the application work parameters.';ru='Фоновое обновление параметров работы программы'"));
		
		Result.Insert("AShortErrorMessage",   Undefined);
		Result.Insert("DetailedErrorMessage", Undefined);
	Except
		ErrorInfo = ErrorInfo();
		Result = New Structure;
		Result.Insert("JobCompleted", False);
		Result.Insert("AShortErrorMessage",   BriefErrorDescription(ErrorInfo));
		Result.Insert("DetailedErrorMessage", DetailErrorDescription(ErrorInfo));
	EndTry;
	
	Result.Property("JobID", BackgroundJobID);
	Result.Property("StorageAddress", BackgroundJobStorageAddress);
	
	Return Result;
	
EndFunction

&AtClient
Procedure ImportUpdateApplicationWorkParametersProcessResult(Val AShortErrorMessage, Val DetailedErrorMessage)
	
	ExclusiveModeSetupError = "";
	
	If AShortErrorMessage = Undefined Then
		ExecutionResult = GetFromTempStorage(BackgroundJobStorageAddress);
		
		If TypeOf(ExecutionResult) = Type("Structure") Then
			AShortErrorMessage   = ExecutionResult.AShortErrorMessage;
			DetailedErrorMessage = ExecutionResult.DetailedErrorMessage;
			ExclusiveModeSetupError = ExecutionResult.ExclusiveModeSetupError;
			
			If ExecutionResult.Property("ClientParametersOnServer") Then
				SetSessionParametersFromBackgroundJob();
			EndIf;
		Else
			AShortErrorMessage =
				NStr("en='An error occurred while receiving"
"result from the background job during the application work parameters.';ru='Ошибка получения результата"
"от фонового задания при обновлении параметров работы программы.'");
			
			DetailedErrorMessage = AShortErrorMessage;
		EndIf;
	EndIf;
	
	If ExclusiveModeSetupError = "LockScheduledJobsProcessing" Then
		RestartWithScheduledJobsExecutionLock();
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("AShortErrorMessage",   AShortErrorMessage);
	AdditionalParameters.Insert("DetailedErrorMessage", DetailedErrorMessage);
	AdditionalParameters.Insert("ExclusiveModeSetupError", ExclusiveModeSetupError);
	
	If ValueIsFilled(ExclusiveModeSetupError) Then
		
		ImportUpdateApplicationWorkParametersOnExclusiveModeSettingError(AdditionalParameters);
		Return;
		
	EndIf;
	
	ImportUpdateApplicationWorkParametersEnd(AdditionalParameters);
	
EndProcedure

&AtClient
Procedure ImportUpdateApplicationWorkParametersOnExclusiveModeSettingError(AdditionalParameters)
	
	If ValueIsFilled(AdditionalParameters.ExclusiveModeSetupError) Then
		
		// Open form to disable active sessions.
		Notification = New NotifyDescription(
			"ImportUpdateApplicationWorkParametersOnExclusiveModeInstallationErrorEnd",
			ThisObject,
			AdditionalParameters);
		
		OnOpenFormsErrorInstallationExclusiveMode(Notification, AdditionalParameters);
	Else
		ImportUpdateApplicationWorkParametersEnd(AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportUpdateApplicationWorkParametersOnExclusiveModeInstallationErrorEnd(Cancel, AdditionalParameters) Export
	
	If Cancel <> False Then
		InfobaseUpdateServiceServerCall.RemoveLockFileBase();
		CloseForm(True, False);
		Return;
	EndIf;
	
	ImportUpdateApplicationWorkParametersStart();
	
EndProcedure

&AtClient
Procedure ImportUpdateApplicationWorkParametersEnd(AdditionalParameters)
	
	If AdditionalParameters.AShortErrorMessage <> Undefined Then
		UnsuccessfulUpdateMessage(AdditionalParameters, Undefined);
		Return;
	EndIf;
	
	InfobaseUpdateServiceServerCall.RemoveLockFileBase();
	ContituationParameters.ReceivedClientParameters.Insert("ShouldUpdateApplicationWorkParameters");
	ContituationParameters.Insert("ReceivedClientParametersQuantity",
		ContituationParameters.ReceivedClientParameters.Count());
	RefreshReusableValues();
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If Not OnlyApplicationWorkParametersUpdate
	   AND ClientParameters.CanUseSeparatedData Then
		
		ExecuteNotifyProcessing(ContituationParameters.ContinuationProcessor);
	Else
		If ClientParameters.Property("ShouldUpdateUndividedDataInformationBase") Then
			Try
				InfobaseUpdateServiceServerCall.RunInfobaseUpdate(, True);
			Except
				ErrorInfo = ErrorInfo();
				AdditionalParameters.Insert("AShortErrorMessage",   BriefErrorDescription(ErrorInfo));
				AdditionalParameters.Insert("DetailedErrorMessage", DetailErrorDescription(ErrorInfo));
			EndTry;
			If AdditionalParameters.AShortErrorMessage <> Undefined Then
				UnsuccessfulUpdateMessage(AdditionalParameters, Undefined);
				Return;
			EndIf;
		EndIf;
		CloseForm(False, False);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Result receipt procedures of update handlers execution.

&AtClient
Procedure UpdateApplicationWorkParametersCheckOnClient()
	
	Result = ApplicationWorkParametersUpdateCompleted();
	
	If Result.JobCompleted = True
	 Or Result.AShortErrorMessage <> Undefined Then
		
		ImportUpdateApplicationWorkParametersProcessResult(
			Result.AShortErrorMessage, Result.DetailedErrorMessage);
	Else
		LongActionsClient.UpdateIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("UpdateApplicationWorkParametersCheckOnClient", HandlerParameters.CurrentInterval, True);
	EndIf;
	
EndProcedure

&AtServer
Function ApplicationWorkParametersUpdateCompleted()
	
	ErrorInfo = Undefined;
	JobCompleted = False;
	
	MoveProgressIndicator(JobCompleted, ErrorInfo);
	
	Result = New Structure;
	Result.Insert("JobCompleted", JobCompleted);
	Result.Insert("AShortErrorMessage",   ?(ErrorInfo <> Undefined, BriefErrorDescription(ErrorInfo), Undefined));
	Result.Insert("DetailedErrorMessage", ?(ErrorInfo <> Undefined, DetailErrorDescription(ErrorInfo), Undefined));
	Result.Insert("PerformanceProgress", PerformanceProgress);
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update (all in the local mode and data area in service).

&AtClient
Procedure RefreshDatabase() Export
	
	BeginStepProgress = 10;
	ProgressStepLength  = 5;
	PerformanceProgress = BeginStepProgress;
	
	AttachIdleHandler("UpdateInfobaseStart", 0.1, True);
	
EndProcedure

&AtClient
Procedure UpdateInfobaseStart()
	
	UpdateBeginTime = CommonUseClient.SessionDate();
	
	// Long operation handler parameters.
	HandlerParameters = New Structure;
	HandlerParameters.Insert("MinInterval", 1);
	HandlerParameters.Insert("MaxInterval", 15);
	HandlerParameters.Insert("CurrentInterval", 1);
	HandlerParameters.Insert("IntervalIncreaseCoefficient", 1.4);
	
	BackgroundJobStorageAddress = Undefined;
	BackgroundJobID = Undefined;
	
	IBUpdateResult = RefreshInfobaseInBackground();
	
	If IBUpdateResult.JobCompleted
	 Or IBUpdateResult.AShortErrorMessage <> Undefined Then
		
		InfobaseUpdateProcessResult(
			IBUpdateResult.AShortErrorMessage,
			IBUpdateResult.DetailedErrorMessage);
	Else
		AttachIdleHandler("InfobaseUpdateCheckOnClient", 1, True);
	EndIf;
	
EndProcedure

&AtServer
Function RefreshInfobaseInBackground()
	
	Result = InfobaseUpdateService.RefreshInfobaseInBackground(UUID, IBBlock);
	IBBlock = Result.IBBlock;
	Result.Property("JobID", BackgroundJobID);
	Result.Property("StorageAddress", BackgroundJobStorageAddress);
	Return Result;
	
EndFunction

&AtClient
Procedure InfobaseUpdateProcessResult(Val AShortErrorMessage, Val DetailedErrorMessage)
	
	If BackgroundJobStorageAddress <> "" Then
		UpdateResult = GetFromTempStorage(BackgroundJobStorageAddress);
		
		If TypeOf(UpdateResult) = Type("Structure") Then
			If UpdateResult.Property("AShortErrorMessage")
				AND UpdateResult.Property("DetailedErrorMessage") Then
				AShortErrorMessage = UpdateResult.AShortErrorMessage;
				DetailedErrorMessage = UpdateResult.DetailedErrorMessage;
			Else
				SignExecutionHandlers = UpdateResult.Result;
				SetSessionParametersFromBackgroundJob();
			EndIf;
		Else
			SignExecutionHandlers = UpdateResult;
		EndIf;
	Else
		SignExecutionHandlers = IBBlock.Error;
	EndIf;
	
	If SignExecutionHandlers = "LockScheduledJobsProcessing" Then
		RestartWithScheduledJobsExecutionLock();
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("DocumentSystemChangesDescription", Undefined);
	AdditionalParameters.Insert("AShortErrorMessage", AShortErrorMessage);
	AdditionalParameters.Insert("DetailedErrorMessage", DetailedErrorMessage);
	AdditionalParameters.Insert("UpdateBeginTime", UpdateBeginTime);
	AdditionalParameters.Insert("UpdateEndTime", CommonUseClient.SessionDate());
	AdditionalParameters.Insert("SignExecutionHandlers", SignExecutionHandlers);
	
	If SignExecutionHandlers = "ExclusiveModeSetupError" Then
		
		UpdateInfobaseOnExclusiveModeSettingError(AdditionalParameters);
		Return;
		
	EndIf;
	
	RemoveLockFileBase = False;
	If IBBlock.Property("RemoveLockFileBase", RemoveLockFileBase) Then
		
		If RemoveLockFileBase Then
			InfobaseUpdateServiceServerCall.RemoveLockFileBase();
		EndIf;
		
	EndIf;
	
	UpdateInfobaseEnd(AdditionalParameters);
	
EndProcedure

&AtClient
Procedure UpdateInfobaseOnExclusiveModeSettingError(AdditionalParameters)
	
	If AdditionalParameters.SignExecutionHandlers = "ExclusiveModeSetupError" Then
		
		// Open form to disable active sessions.
		Notification = New NotifyDescription(
			"UpdateInfobaseOnExclusiveModeSettingErrorEnd", ThisObject, AdditionalParameters);
		OnOpenFormsErrorInstallationExclusiveMode(Notification, AdditionalParameters);
		
	Else
		UpdateInfobaseEnd(AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateInfobaseOnExclusiveModeSettingErrorEnd(Cancel, AdditionalParameters) Export
	
	If Cancel <> False Then
		CloseForm(True, False);
		Return;
	EndIf;
	
	SetIBLockParametersOnExclusiveModeSettingError();
	UpdateInfobaseStart();
	
EndProcedure

&AtClient
Procedure SetIBLockParametersOnExclusiveModeSettingError()
	
	IBBlock.Insert("Use", False);
	IBBlock.Insert("RemoveLockFileBase", True);
	IBBlock.Insert("Error", Undefined);
	IBBlock.Insert("OperationalUpdate", Undefined);
	IBBlock.Insert("RecordKey", Undefined);
	IBBlock.Insert("DebugMode", Undefined);
	
EndProcedure

&AtClient
Procedure UpdateInfobaseEnd(AdditionalParameters)
	
	If AdditionalParameters.AShortErrorMessage <> Undefined Then
		UpdateEndTime = CommonUseClient.SessionDate();
		
		UnsuccessfulUpdateMessage(AdditionalParameters, UpdateEndTime);
		Return;
	EndIf;
	
	InfobaseUpdateServiceServerCall.WriteExecutionTimeUpdate(
		AdditionalParameters.UpdateBeginTime, AdditionalParameters.UpdateEndTime);
	
	RefreshReusableValues();
	CloseForm(False, False);
	
EndProcedure

&AtClient
Procedure CloseForm(Cancel, Restart)
	
	IBVersionUpdateIsExecuted = False;
	
	Close(New Structure("Cancel, Restart", Cancel, Restart));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Result receipt procedures of update handlers execution.

&AtClient
Procedure InfobaseUpdateCheckOnClient()
	
	Result = InfobaseUpdateExecuted();
	
	If Result.JobCompleted = True
	 Or Result.AShortErrorMessage <> Undefined Then
		
		InfobaseUpdateProcessResult(
			Result.AShortErrorMessage, Result.DetailedErrorMessage);
	Else
		LongActionsClient.UpdateIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("InfobaseUpdateCheckOnClient", HandlerParameters.CurrentInterval, True);
	EndIf;
	
EndProcedure

&AtServer
Function InfobaseUpdateExecuted()
	
	ErrorInfo = Undefined;
	JobCompleted = False;
	
	MoveProgressIndicator(JobCompleted, ErrorInfo);
	
	// If IB update is complete - unlock IB.
	If JobCompleted = True Then
		InfobaseUpdateService.UnlockInfobase(IBBlock);
	EndIf;
	
	Result = New Structure;
	Result.Insert("JobCompleted", JobCompleted);
	Result.Insert("AShortErrorMessage",   ?(ErrorInfo <> Undefined, BriefErrorDescription(ErrorInfo),   Undefined));
	Result.Insert("DetailedErrorMessage", ?(ErrorInfo <> Undefined, DetailErrorDescription(ErrorInfo), Undefined));
	Result.Insert("PerformanceProgress", PerformanceProgress);
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Called if an attempt to set the exclusive mode in the file base failed.
// 
// Parameters:
//  Cancel - Boolean - if True - completes application work.
//
&AtClient
Procedure OnOpenFormsErrorInstallationExclusiveMode(Notification, AdditionalParameters)
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.UserSessions") Then
		DBModuleConnectionsClient = CommonUseClient.CommonModule("InfobaseConnectionsClient");
		DBModuleConnectionsClient.OnOpenFormsErrorInstallationExclusiveMode(Notification);
	Else
		UnsuccessfulUpdateMessage(AdditionalParameters, Undefined);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Common procedures for all stages.

&AtClient
Procedure StartClosing() Export
	
	AttachIdleHandler("ContinueClosing", 0.1, True);
	
EndProcedure

&AtClient
Procedure ContinueClosing() Export
	
	IBVersionUpdateIsExecuted = False;
	
	CloseForm(False, False);
	
EndProcedure

&AtClient
Procedure UnsuccessfulUpdateMessage(AdditionalParameters, UpdateEndTime)
	
	NotifyDescription = New NotifyDescription("InfobaseUpdateActionsOnError", ThisObject);
	
	FormParameters = New Structure;
	FormParameters.Insert("AShortErrorMessage",   AdditionalParameters.AShortErrorMessage);
	FormParameters.Insert("DetailedErrorMessage", AdditionalParameters.DetailedErrorMessage);
	FormParameters.Insert("UpdateBeginTime",      UpdateBeginTime);
	FormParameters.Insert("UpdateEndTime",   UpdateEndTime);
	
	OpenableFormName = "DataProcessor.InfobaseUpdate.Form.UnsuccessfulUpdateMessage";
	
	If ValueIsFilled(ExchangePlanName) Then
		
		ModuleExchangeDataClient = CommonUseClient.CommonModule("DataExchangeClient");
		ModuleExchangeDataClient.MessageFormNameAboutUnsuccessfulUpdate(OpenableFormName);
		FormParameters.Insert("ExchangePlanName", ExchangePlanName);
		
	EndIf;
	
	OpenForm(OpenableFormName, FormParameters,,,,,NotifyDescription);
	
EndProcedure

&AtClient
Procedure InfobaseUpdateActionsOnError(Done, AdditionalParameters) Export
	
	If Done <> False Then
		CloseForm(True, False);
	Else
		CloseForm(True, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure RestartWithScheduledJobsExecutionLock()
	
	NewLaunchParameter = LaunchParameter + ";ScheduledJobsDisable";
	NewLaunchParameter = "/AllowExecuteScheduledJobs -Off " + "/C """ + NewLaunchParameter + """";
	Terminate(True, NewLaunchParameter);
	
EndProcedure

&AtServer
Procedure MoveProgressIndicator(JobCompleted, ErrorInfo)
	
	If BackgroundJobID <> Undefined Then
		
		Try
			JobCompleted = LongActions.JobCompleted(BackgroundJobID);
			Task = BackgroundJobs.FindByUUID(BackgroundJobID);
			If Task <> Undefined Then
				AllMessage = Task.GetUserMessages(True);
				If AllMessage <> Undefined Then
					IncreaseInProgressStep = 0;
					For Each UserMessage IN AllMessage Do
						AllMessage = Task.GetUserMessages(True);
						If AllMessage = Undefined Then
							AllMessage = New Array;
						EndIf;
						
						BeginRows = "ProgressStep=";
						If Left(UserMessage.Text, StrLen(BeginRows)) = BeginRows Then
							IncreaseInProgressStep = 0;
							NewStepDescription = Mid(UserMessage.Text, StrLen(BeginRows) + 1);
							SeparatorPosition = Find(NewStepDescription, "/");
							If SeparatorPosition > 0 Then
								BeginStepProgress = Number( Left(NewStepDescription, SeparatorPosition - 1));
								ProgressStepLength  = Number(Mid(NewStepDescription, SeparatorPosition + 1));
							EndIf;
						EndIf;
						
						BeginRows = "IncreaseInProgressStep=";
						If Left(UserMessage.Text, StrLen(BeginRows)) = BeginRows Then
							IncreaseInProgressStep = Number(Mid(UserMessage.Text, StrLen(BeginRows) + 1));
						EndIf;
					EndDo;
					// Move progress indicator.
					NewExecutionProgress = BeginStepProgress + IncreaseInProgressStep/100*ProgressStepLength;
					If PerformanceProgress < NewExecutionProgress Then
						PerformanceProgress = NewExecutionProgress;
					EndIf;
				EndIf;
			EndIf;
		Except
			
			Task = BackgroundJobs.FindByUUID(BackgroundJobID);
			If Task <> Undefined Then
				AllMessage = Task.GetUserMessages(True);
				If AllMessage <> Undefined Then
					For Each UserMessage IN AllMessage Do
						
						BeginRows = "DataExchange=";
						If Left(UserMessage.Text, StrLen(BeginRows)) = BeginRows Then
							ExchangePlanName = Mid(UserMessage.Text, StrLen(BeginRows) + 1);
						EndIf;
						
					EndDo;
					
				EndIf;
				
			EndIf;
			
			ErrorInfo = ErrorInfo();
		EndTry;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetSessionParametersFromBackgroundJob()
	UpdateResult = GetFromTempStorage(BackgroundJobStorageAddress);
	SessionParameters.ClientParametersOnServer = UpdateResult.ClientParametersOnServer;
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
