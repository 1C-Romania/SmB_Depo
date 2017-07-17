////////////////////////////////////////////////////////////////////////////////
// Subsystem "Logging off users".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Opens entry form of the infobase and/or cluster administration parameters.
//
// Parameters:
// OnCloseNotifyDescription - NotifyDescription - Handler that will be called after
//                                                    you enter administration parameters.
// RequestInfobaseAdministrationParameters - Boolean - Shows that it is
//                                                    necessary to enter infobase administration parameters.
// QueryClusterAdministrationParameters - Boolean - Shows that it is
//                                                          necessary to enter cluster administration parameters.
// AdministrationParameters - Structure - Administration parameters that were entered earlier.
// Title - String - Form title that describes the reason why administration parameters are requested.
// ExplanatoryInscription - String - Explanation for the executed action in the context of which parameters are requested.
//
Procedure ShowAdministrationParameters(OnCloseNotifyDescription, RequestInfobaseAdministrationParameters,
	QueryClusterAdministrationParameters, AdministrationParameters = Undefined,
	Title = "", ExplanatoryInscription = "") Export
	
	FormParameters = New Structure;
	FormParameters.Insert("RequestInfobaseAdministrationParameters", RequestInfobaseAdministrationParameters);
	FormParameters.Insert("QueryClusterAdministrationParameters", QueryClusterAdministrationParameters);
	FormParameters.Insert("AdministrationParameters", AdministrationParameters);
	FormParameters.Insert("Title", Title);
	FormParameters.Insert("ExplanatoryInscription", ExplanatoryInscription);
	
	OpenForm("CommonForm.ApplicationAdministrationParameters", FormParameters,,,,,OnCloseNotifyDescription);
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// Executes actions before the system work start.
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If Not ClientParameters.Property("DataAreaSessionsLocked") Then
		Return;
	EndIf;
	
	Parameters.InteractiveDataProcessor = New NotifyDescription(
		"OnlineDataProcessorBeforeStart", ThisObject);
	
EndProcedure

// Executes actions during the system work start.
Procedure AfterSystemOperationStart() Export
	
	WorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If Not WorkParameters.CanUseSeparatedData Then
		Return;
	EndIf;
	
	If GetClientConnectionSpeed() <> ClientConnectionSpeed.Normal Then
		Return;
	EndIf;
	
	LockMode = WorkParameters.SessionLockParameters;
	CurrentTime = LockMode.CurrentSessionDate;
	If LockMode.Use 
		 AND (NOT ValueIsFilled(LockMode.Begin) OR CurrentTime >= LockMode.Begin) 
		 AND (NOT ValueIsFilled(LockMode.End) OR CurrentTime <= LockMode.End) Then
		// If user logged in the base where lock mode is set, key / UC was used.
		// You should not end this user work.
		Return;
	EndIf;
	
	AttachIdleHandler("ControlOfUserSessionTerminationMode", 60);
	
EndProcedure

// Process start parameters connected to the IB connections end and permission.
//
// Parameters:
//  LaunchParameterValue  - String - main start parameter.
//  LaunchParameters          - Array - start additional parameters
//                                       separated by the ";" character.
//
// Returns:
//   Boolean   - True if it is required to stop executing system start.
//
Function ProcessStartParameters(Val LaunchParameterValue, Val LaunchParameters) Export

	WorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If Not WorkParameters.CanUseSeparatedData Then
		Return False;
	EndIf;
	
	// Process application start parameters - 
	// ProhibitUsersWork and AllowUsersWork.
	If LaunchParameterValue = Upper("AllowUsersWork") Then
		
		If Not InfobaseConnectionsServerCall.AllowUsersWork() Then
			MessageText = NStr("en='Launch parameter AllowUsersWork is not processed. You are not authorized to administer the infobase.';ru='Параметр запуска РазрешитьРаботуПользователей не отработан. Нет прав на администрирование информационной базы.'");
			ShowMessageBox(,MessageText);
			Return False;
		EndIf;
		
		EventLogMonitorClient.AddMessageForEventLogMonitor(InfobaseConnectionsClientServer.EventLogMonitorEvent(),,
			NStr("en='Started with the ""AllowUsersWork"" parameter. The application will be closed.';ru='Выполнен запуск с параметром ""РазрешитьРаботуПользователей"". Работа программы будет завершена.'"), ,True);
		Exit(False);
		Return True;
		
	// Parameter may contain two additional parts separated by the ";" character - 
	// IB administrator name and password on behalf of which you are
	// connecting to servers cluster in client-server option of system deployment. They should be passed if the current user is not IB administrator.For
	// the usage, see the EndUsersWork() procedure.
	ElsIf LaunchParameterValue = Upper("TerminateUserSessions") Then
		
		// As lock is not set, then when you log
		// in the system, work end waiting handler is enabled for the current user.
		// Disable it. As for this user the "EndUsersWork" specialized
		// waiting handler is enabled that focuses on the
		// fact that this user should be enabled last.
		DetachIdleHandler("ControlOfUserSessionTerminationMode");
		
		If Not InfobaseConnectionsServerCall.SetConnectionLock() Then
			MessageText = NStr("en='The EndUsersWork launch parameter is not processed. You are not authorized to administer the infobase.';ru='Параметр запуска ЗавершитьРаботуПользователей не отработан. Нет прав на администрирование информационной базы.'");
			ShowMessageBox(,MessageText);
			Return False;
		EndIf;
		
		AttachIdleHandler("TerminateUserSessions", 60);
		TerminateUserSessions();
		Return False; // Continue application start.
		
	EndIf;
	Return False;
	
EndFunction

// Enable the UsersWorkModeEndControl waiting handler or.
// EndUsersWork depending on the SetConnectionsLock parameter.
//
Procedure SetIdleHandlerOfUserSessionsTermination(Val SetConnectionLock) Export
	
	SetUserTerminationInProgressFlag(SetConnectionLock);
	If SetConnectionLock Then
		// As lock is not set, then when you log
		// in the system, work end waiting handler is enabled for the current user.
		// Disable it. As for this user the "EndUsersWork" specialized
		// waiting handler is enabled that focuses on the
		// fact that this user should be enabled last.
		
		DetachIdleHandler("ControlOfUserSessionTerminationMode");
		AttachIdleHandler("TerminateUserSessions", 60);
		TerminateUserSessions();
	Else
		DetachIdleHandler("TerminateUserSessions");
		AttachIdleHandler("ControlOfUserSessionTerminationMode", 60);
	EndIf;
	
EndProcedure

// Completes work of the (last) administer session that initialized users work end.
//
Procedure TerminateThisSession(ShowQuestion = True) Export
	
	SetUserTerminationInProgressFlag(False);
	DetachIdleHandler("TerminateUserSessions");
	
	If EndAllSessionsExceptCurrent() Then
		Return;
	EndIf;
	
	If Not ShowQuestion Then 
		Exit(False);
		Return;
	EndIf;
	
	Notification = New NotifyDescription("EndThisSessionWorkEnd", ThisObject);
	MessageText = NStr("en='User operation in the application is prohibited. Close this session?';ru='Работа пользователей с программой запрещена. Завершить работу этого сеанса?'");
	Title = NStr("en='End the current session';ru='Завершение работы текущего сеанса'");
	ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes, Title, DialogReturnCode.Yes);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into this subsystem.

// Called if an attempt to set the exclusive mode in the file base failed.
//
// Parameters:
//  Notification - NotifyDescription - describes where to pass management after form is closed.
//
Procedure OnOpenFormsErrorInstallationExclusiveMode(Notification, FormParameters = Undefined) Export
	
	If FormParameters = Undefined Then
		FormParameters = New Structure;
	EndIf;
	
	OpenForm("DataProcessor.UserWorkBlocking.Form.ExclusiveModeSetupError", FormParameters,
		, , , , Notification);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Called when starting interactive operation of user with data area.
//
// Parameters:
//  FirstParameter   - String - first value of
//                     the start parameter, up to the first ; character in the upper register.
//  LaunchParameters - Array - array of rows separated by the ;
//                     character in the start parameter passed to the configuration using command bar key /C.
//  Cancel            - Boolean (return value) if you
//                     set True OnStart, the OnStart event processor will be aborted.
//
Procedure OnProcessingParametersLaunch(FirstParameter, LaunchParameters, Cancel) Export
	
	Cancel = Cancel Or ProcessStartParameters(FirstParameter, LaunchParameters);
	
EndProcedure

// Overrides the standard warning by opening of arbitrary form of active users.
//
// Parameters:
//  FormName - String (return value).
//
Procedure WhenDefiningFormsActiveUsers(FormName) Export
	
	FormName = "DataProcessor.ActiveUsers.Form.ActiveUsersListForm";
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Handlers of the BaseFunctionality subsystem events.

// Sets value of the UserSessionss variable to the Value value.
//
// Parameters:
//   Value - Boolean - set value.
//
Procedure SetUserTerminationInProgressFlag(Value) Export
	
	ParameterName = "StandardSubsystems.UserWorkEndParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Structure);
	EndIf;
	
	ApplicationParameters["StandardSubsystems.UserWorkEndParameters"].Insert("SessionTerminationInProgress", Value);
	
EndProcedure

Function SessionTerminationInProgress() Export
	
	UserWorkEndParameters = ApplicationParameters["StandardSubsystems.UserWorkEndParameters"];
	
	Return TypeOf(UserWorkEndParameters) = Type("Structure")
		AND UserWorkEndParameters.Property("SessionTerminationInProgress")
		AND UserWorkEndParameters.SessionTerminationInProgress;
	
EndFunction

// Sets the EndAllSessionsExceptCurrent variable value to the Value value.
//
// Parameters:
//   Value - Boolean - set value.
//
Procedure SetCompleteSignAllSessionsExceptCurrent(Value) Export
	
	ParameterName = "StandardSubsystems.UserWorkEndParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Structure);
	EndIf;
	
	ApplicationParameters["StandardSubsystems.UserWorkEndParameters"].Insert("EndAllSessionsExceptCurrent", Value);
	
EndProcedure

Function EndAllSessionsExceptCurrent() Export
	
	UserWorkEndParameters = ApplicationParameters["StandardSubsystems.UserWorkEndParameters"];
	
	Return TypeOf(UserWorkEndParameters) = Type("Structure")
		AND UserWorkEndParameters.Property("EndAllSessionsExceptCurrent")
		AND UserWorkEndParameters.EndAllSessionsExceptCurrent;
	
EndFunction

Function SavedAdministrationParameters() Export
	
	UserWorkEndParameters = ApplicationParameters["StandardSubsystems.UserWorkEndParameters"];
	AdministrationParameters = Undefined;
	
	If TypeOf(UserWorkEndParameters) = Type("Structure")
		AND UserWorkEndParameters.Property("AdministrationParameters") Then
		
		AdministrationParameters = UserWorkEndParameters.AdministrationParameters;
		
	EndIf;
		
	Return AdministrationParameters;
	
EndFunction

Procedure SaveAdministrationParameters(Value) Export
	
	ParameterName = "StandardSubsystems.UserWorkEndParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Structure);
	EndIf;
	
	ApplicationParameters["StandardSubsystems.UserWorkEndParameters"].Insert("AdministrationParameters", Value);

EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Notification handlers.

// Offers to unlock and log in or terminate the system work.
Procedure OnlineDataProcessorBeforeStart(Parameters, NotSpecified) Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	QuestionText   = ClientParameters.OfferLogOn;
	MessageText = ClientParameters.DataAreaSessionsLocked;
	
	If Not IsBlankString(QuestionText) Then
		Buttons = New ValueList();
		Buttons.Add(DialogReturnCode.Yes, NStr("en='Login';ru='Логин'"));
		If ClientParameters.CanRemoveLock Then
			Buttons.Add(DialogReturnCode.No, NStr("en='Unlock and log on';ru='Снять блокировку и войти'"));
		EndIf;
		Buttons.Add(DialogReturnCode.Cancel, NStr("en='Cancel';ru='Отменить'"));
		
		ResponseProcessor = New NotifyDescription(
			"AfterQuestionResponseLogInOrUnlock", ThisObject, Parameters);
		
		ShowQueryBox(ResponseProcessor, QuestionText, Buttons, 15,
			DialogReturnCode.Cancel,, DialogReturnCode.Cancel);
		Return;
	Else
		Parameters.Cancel = True;
		ShowMessageBox(
			StandardSubsystemsClient.AlertWithoutResult(Parameters.ContinuationProcessor),
			MessageText, 15);
	EndIf;
	
EndProcedure

// Continue the previous procedure.
Procedure AfterQuestionResponseLogInOrUnlock(Response, Parameters) Export
	
	If Response = DialogReturnCode.Yes Then // Log in the locked application.
		
	ElsIf Response = DialogReturnCode.No Then // Unlock and log in the application.
		InfobaseConnectionsServerCall.SetDataAreaSessionLock(
			New Structure("Use", False));
	Else
		Parameters.Cancel = True;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

Procedure AskQuestionOnWorkEnd(MessageText) Export
	
	QuestionText = NStr("en='%1 Close?';ru='%1 Завершить работу?'");
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(QuestionText, MessageText);
	NotifyDescription = New NotifyDescription("AskQuestionOnWorkEndEnd", ThisObject);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, 30, DialogReturnCode.Yes);
	
EndProcedure

Procedure AskQuestionOnWorkEndEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(True, False);
	EndIf;
	
EndProcedure

Procedure EndThisSessionWorkEnd(Response, Parameters) Export
	
	If Response <> DialogReturnCode.No Then
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(False);
	EndIf;
	
EndProcedure	

#EndRegion
