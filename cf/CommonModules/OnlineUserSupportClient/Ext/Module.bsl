
////////////////////////////////////////////////////////////////////////////////
// Subsystem "Online User Support".
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// A handler called at start of system operation.
//
Procedure OnStart() Export
	
	OUSParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart().OnlineUserSupport;
	
	// Calling handlers of AtSystemOperationStart subsystems()
	Handlers = OUSParameters.OnStart;
	For Each ModuleName IN Handlers Do
		HandlerModule = CommonUseClient.CommonModule(ModuleName);
		If HandlerModule <> Undefined Then
			HandlerModule.OnStart();
		EndIf;
	EndDo;
	
EndProcedure

// Connects the user to the
// online user support service: user
// authentication, password recovery by the user,
// new user registration, software product registration.
// When connection to online support is
// completed successfully, the login and password entered by the user are returned through the NotificationDescription object.
//
// Parameters:
// CompletionNotificationDescription - NotifyDescription - handler of
// 	online support connection completion notification. Notification
// 	handler returns the following value as a result: Undefined -
// 	if the connection to online support is
// 	not completed successfully; If the user
// 	has completed online support connection successfully, the notification handler restores the Structure-type object with the fields as follows:
// 		* Login - String - the entered login;
// 		* Password - the entered password.
//
Procedure ConnectOnlineUserSupport(CompletionNotificationDescription = Undefined) Export
	
	LaunchLocation = "connectIPP";
	
	If CompletionNotificationDescription = Undefined Then
		ResultHandlers = Undefined;
	Else
		ResultHandlers = NewBusinessProcessCompletionHandler(LaunchLocation);
		ResultHandlers.Insert("NotificationsAboutAuthorization", New Array);
		ResultHandlers.NotificationsAboutAuthorization.Add(CompletionNotificationDescription);
	EndIf;
	
	RunScript(LaunchLocation, , , , ResultHandlers);
	
EndProcedure

// Opens the form of setting online user support parameters.
// Parameters:
// FormOwner - ManagedForm, Undefined - owner of
// the LockOwnerWindow form being opened - Boolean - True if the form
// 	has to be opened in the owner window blocking mode.
//
// Returns:
// ManagedForm - open form of
// 	online user support parameters.
//
Function OpenConnectionParametersSettingsForm(
	FormOwner = Undefined,
	LockOwnerWindow = True) Export
	
	WindowOpeningMode = ?(LockOwnerWindow,
		FormWindowOpeningMode.LockOwnerWindow,
		FormWindowOpeningMode.Independent);
	
	Return OpenForm("CommonForm.OnlineSupportConnectionParameters",
		,
		FormOwner,
		False,
		,
		,
		,
		WindowOpeningMode);
	
EndFunction

// Determines whether the current configuration is
// registered in the online support service or not.
//
// Parameters:
// WebServiceCallError - Boolean - True is returned
// 	in the parameter if an error occurred while accessing
// 	the OUS service and it was not possible to check that the configuration was registered;
//
// Returns:
// Boolean - True if the configuration is registered
// 	in the OUS service, False - if not registered or if an error occurred while
// 		accessing OUS service;
//
Function ConfigurationIsRegisteredInOUSService(WebServiceCallError = False) Export
	
	CallFromServer = False;
	OUSParameters      = Undefined;
	ConfigurationIsRegistered = OnlineUserSupportServerCall.ConfigurationIsRegisteredInOUSService(
		CallFromServer,
		OUSParameters,
		WebServiceCallError);
	
	If CallFromServer Then
		
		Return ConfigurationIsRegistered;
		
	Else
		
		// Calling the OUS web-service from 1C:Enterprise client
		Return OnlineUserSupportClientServer.ConfigurationIsRegisteredInOUSService(
			WebServiceCallError,
			,
			OUSParameters);
		
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Outdated application interface

// Outdated. It will be deleted in the next library version.
// Use
// OnlineSupportMonitorClient.OpenOnlineSuportMonitor()
// Open the online support monitor from the menu.
//
// Parameters:
// LaunchParameters - Structure - transferred
// start parameters, structure key - parameter name, value - value of the parameter.
//
Procedure StartMechanismFromMenu(LaunchParameters = Undefined) Export
	
	If Not CommonUseClient.SubsystemExists("OnlineUserSupport.OnlineSupportMonitor") Then
		
		Raise NStr("en='Embedding error. The ""Online user support dashboard"" subsystem is missing.';ru='Ошибка встраивания. Отсутствует подсистема ""Монитор Интернет-поддержки пользователей"".'");
		
	Else
		
		CommonModuleOUSMonitor = CommonUseClient.CommonModule("OnlineSupportMonitorClient");
		CommonModuleOUSMonitor.OpenOnlineSupportMonitor(LaunchParameters);
		
	EndIf;
	
EndProcedure

// Outdated. It will be deleted in the next library version.
// Use the
// ConnectOnlineUserSupport() procedure.
// It will be deleted from the application interface in the next library version.
// Online user support connection (or change
// of the OUS user) from the OUS settings form.
//
// Parameters:
// LaunchParameters - Structure - transferred
// start parameters, structure key - parameter name, value - value of the parameter.
//
Procedure EnableInternetSupport(LaunchParameters = Undefined) Export
	
	LaunchLocation = "connectIPP";
	
	// Execution of online support script.
	RunScript(LaunchLocation, LaunchParameters);
	
EndProcedure

// Outdated. It will be deleted in the next library version.
// Use
// Connection1CTaxcomClient.StartMechanismOfWorkingWithEDFOperator().
// Running the mechanism of working with EDF operator service.
//
// Parameters:
// DSCertificate - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - DS certificate;
// Company - Arbitrary - company, company associated
// 	with the certificate;
// BusinessProcessOption - String - name of EDF action.Possible values:
// 	taxcomGetID  - launch the receiving (registration)
// 	of a new taxcomPrivat identifier - enter EDF subscriber's personal account.
// CompanyID - String - company identifier in the EDF system;
// DSCertificatePassword - String, Undefined - password
// 	of a password used to avoid repeated input;
// FormUUID (UUID) - identifier
// of the form from which the method was called. Used as an
// event source when alerting the form initiator about the result.
//
Procedure StartWorkWithEDFOperatorMechanism(
	DSCertificate,
	Company,
	BusinessProcessOption,
	CompanyID = "",
	DSCertificatePassword = Undefined,
	FormUUID = Undefined) Export
	
	If Not CommonUseClient.SubsystemExists("OnlineUserSupport.1CTaxcomConnection") Then
		
		Raise NStr("en='Embedding error. The ""Connection to 1C Taxcom"" subsystem is unavailable.';ru='Ошибка встраивания. Отсутствует подсистема ""Подключение 1С-Такском"".'");
		
	Else
		
		CommonModule1CTaxcom = CommonUseClient.CommonModule("Connection1CTaxcomClient");
		CommonModule1CTaxcom.StartWorkWithEDFOperatorMechanism(
			DSCertificate,
			Company,
			BusinessProcessOption,
			CompanyID,
			DSCertificatePassword,
			FormUUID);
		
	EndIf;
	
EndProcedure

#EndRegion


#Region ServiceApplicationInterface

// Execution of the online user support mechanism start script.
//
// Parameters:
// LaunchLocation - String - location of mechanism start, from
// 	which the required business process is determined.
// LaunchParameters - Structure - start parameters of the mechanism.
// 	the structure key corresponds to the parameter name, and value - to
// 	the parameter value. Content of the parameters is arbitrary;
// Again - Boolean - indicates that the mechanism is initiated
// 	from the
// 	connection error form (OnlineUserSupportInternetAccessError) with the Return Connection button.;
// InteractionContext - Structure, FixedStructure, Undefined
// 	- ready context to start the business process.
// BusinessProcessCompletionHandlers - Structure - Notifications
// 	on the HANDLERS end
// 	business process see the function NewBusinessProcessCompletionHandler())
//
Procedure RunScript(
	LaunchLocation,
	LaunchParameters = Undefined,
	Again = False,
	InteractionContext = Undefined,
	BusinessProcessCompletionHandlers = Undefined) Export
	
	If InteractionContext <> Undefined Then
		
		If InteractionContext.Property("StartManagementStructure") Then
			HandleIUSStartStructure(LaunchLocation, InteractionContext.StartManagementStructure);
			NotifyOfBusinessProcessCompletion(BusinessProcessCompletionHandlers, Undefined);
			Return;
		EndIf;
		
		ContextCreationParameters = Undefined;
		
	Else
		
		ContextCreationParameters = New Structure(
			"StartLocation, SecondStart, StartParameters",
			LaunchLocation,
			Again,
			LaunchParameters);
		
	EndIf;
	
	Try
		
		ServiceCall(InteractionContext, ContextCreationParameters, BusinessProcessCompletionHandlers);
		
	Except
		
		If InteractionContext <> Undefined Then
			OnStart = InteractionContext.COPContext.OnStart;
		Else
			OnStart = False;
		EndIf;
		
		OnlineUserSupportServerCall.WriteErrorInEventLogMonitor(
			DetailErrorDescription(ErrorInfo()));
		OpenForm("CommonForm.OnlineUserSupportInternetAccessError",
			New Structure("StartLocation, StartParameters, ErrorDescription, AtSystemOperationStart",
				LaunchLocation,
				LaunchParameters,
				NStr("en='Unknown error. For more details see event log.';ru='Неизвестная ошибка. Подробнее см. в журнале регистрации.'"),
				OnStart));
		
	EndTry;
	
EndProcedure

#EndRegion


#Region ServiceProceduresAndFunctions

// Returns the client business process handler.
// Parameters:
// LaunchLocation - String - Entry point to the business process;
// EventName - String - name of the event under processing.
//
// Returns:
// CommonModule - module implementing the business process handler.
// Undefined - if the business process handler is not available.
//
Function BusinessProcessClientHandler(LaunchLocation, EventName) Export
	
	If OnlineUserSupportClientServer.ThisIsBaseBusinessProcess(LaunchLocation) Then
		Return Undefined;
	EndIf;
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters().OnlineUserSupport;
	ClientHandlers  = ClientWorkParameters.BusinessProcessesClientHandlers;
	
	ModuleName = ClientHandlers.Get(LaunchLocation + "\" + EventName);
	
	If ModuleName = Undefined Then
		Return Undefined;
	EndIf;
	
	Return CommonUseClient.CommonModule(ModuleName);
	
EndFunction

// Performs actions when start of OUS is disabled for some reason.
// Parameters:
// LaunchLocation - String - name of the OUS start button;
// StartStructure - Structure - management start structure.
// 	(see the DefineStartPossibilityByLocationAndParameters()
// 	function of the OnlineUserSupportClientServer common module)
//
Procedure HandleIUSStartStructure(LaunchLocation, Val StartStructure) Export
	
	If StartStructure = Undefined Then
		Return;
	EndIf;
	
	If StartStructure.Action = "Return" Then
		
		Status();
		
	ElsIf StartStructure.Action = "ShowMessage" Then
		
		Status();
		
		If StartStructure.OnStart Then
			ShowUserNotification(NStr("en='Online user support';ru='Интернет-поддержка пользователей'"),
				,
				StartStructure.Message,
				PictureLib.OnlineUserSupport);
		Else
			ShowMessageBox(,
				StartStructure.Message,
				,
				NStr("en='Online user support';ru='Интернет-поддержка пользователей'"));
		EndIf;
		
	EndIf;
	
EndProcedure

// Common (universal) procedure of
// starting the online user support business process.
//
// Parameters:
// LaunchLocation - String - mechanism start location (name of the button);
// LaunchParameters - Structure - start parameters of the mechanism.
// 	the structure key corresponds to the parameter name, and value - to
// 	the parameter value.
// Again - Boolean - indicates that the mechanism is initiated
// 	from the
// 	connection error form (OnlineUserSupportInternetAccessError) with the Return Connection button.
//
Procedure LaunchMechanism(LaunchLocation, LaunchParameters = Undefined, Again = False) Export
	
	// Execution of online support script.
	RunScript(LaunchLocation, LaunchParameters, Again);
	
EndProcedure

// Opens the Web page in a browser.
//
// Parameters:
// PageAddress - String - URL-address of the page being opened;
// WindowTitle - String - heading of
// 	the page being opened if an internal configuration form is used for page opening.
//
Procedure OpenInternetPage(PageAddress, WindowTitle) Export
	
	StandardDataProcessor = True;
	OnlineUserSupportClientOverridable.OpenInternetPage(
		PageAddress,
		WindowTitle,
		StandardDataProcessor);
	
	If StandardDataProcessor = True Then
		// Opening a Web page in a standard way
		CommonUseClient.NavigateToLink(PageAddress);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OUS service commands data processor

// It is called by the start mechanism
// to perform the first OUS Web-service call and obtain
// commands from the Web-service for their further execution.
//
// Parameters:
// PreparedInteractionContext - Structure,
// 	FixedStructure, Undefined - prepared context;
// ContextCreationParameters - Structure - parameters
// 	of creating a new interaction context if the context does not exist;
// BusinessProcessCompletionHandlers - Structure - Notifications
// 	on the HANDLERS end
// 	business process see the function NewBusinessProcessCompletionHandler())
//
Procedure ServiceCall(
	PreparedInteractionContext,
	ContextCreationParameters,
	BusinessProcessCompletionHandlers)
	
	If PreparedInteractionContext = Undefined Then
		
		InteractionContext = Undefined;
		
	Else
		
		If TypeOf(PreparedInteractionContext) = Type("FixedStructure") Then
			InteractionContext = ValueFromFixedType(PreparedInteractionContext);
		Else
			InteractionContext = PreparedInteractionContext;
		EndIf;
		
		InteractionContext.Insert("BusinessProcessCompletionHandlers",
			BusinessProcessCompletionHandlers);
		
	EndIf;
	
	// Parameters passed to the service at first call
	// and saved on OUS server in session variables.
	AdditionalStartParameters = New Array;
	AdditionalStartParameters.Add("libraryVersion");
	AdditionalStartParameters.Add("APIVersion");
	AdditionalStartParameters.Add("versionConfiguration");
	AdditionalStartParameters.Add("versionPlatform");
	AdditionalStartParameters.Add("nameConfiguration");
	AdditionalStartParameters.Add("language");
	AdditionalStartParameters.Add("enterPoint");
	
	ServiceCommandsDataProcessor(
		InteractionContext,
		Undefined,
		Undefined,
		,
		,
		AdditionalStartParameters,
		,
		ContextCreationParameters,
		BusinessProcessCompletionHandlers);
	
EndProcedure

// The procedure receives commands from the Web-service and executes these
// commands at client side or passes the control to the 1C:Enterprise server.
//
// Parameters:
// InteractionContext - Structure - interaction context
// 	with the OUS service (see the OnlineUserSupportServerCall.NewInteractionContext() function).
// CurrentForm - ManagedForm - form which called the
// 	method for service commands execution;
// QueryParameters - Array - array of Structure-type items:
// 	* Name - String - parameter name;
// 	* Value - Arbitrary - parameter value;
// 	* BusinessProcess - String - name of the business process to which the parameter refers;
// HandlerContext - Structure - commands handler context
// 	(see the OnlineUserSupporClientServer.CommandsHandlerNewContext() function;
// OUSServiceCallParameters - Structure - additional
// 	parameters of OUS service call:
// * HandleResponse - Boolean - True if it is
// 		required to process the service response;
// * DisplayCallStatus - Boolean - True if it
// 		is necessary to represent the status of OUS service call;
// * ClearSessionBeforeExecutionOfQuery - Boolean - True,
// 		if prior to query execution it is required to delete session parameters;
// ContinueExecution - Boolean - True if it is
// 	necessary to continue the running without calling the OUS service;
// BusinessProcessCompletionHandlers - Structure - Notifications
// 	on the HANDLERS end
// 	business process see the function NewBusinessProcessCompletionHandler())
//
Procedure ServiceCommandsDataProcessor(
	InteractionContext,
	CurrentForm,
	QueryParameters,
	HandlerContext = Undefined,
	OUSServiceCallParameters = Undefined,
	AdditionalQueryParameters = Undefined,
	ContinueExecution = False,
	ContextCreationParameters = Undefined,
	BusinessProcessCompletionHandlers = Undefined) Export
	
	DisplayCallStatus = True;
	HandleResponse              = True;
	ItIsRequiredToClearSession     = False;
	
	If TypeOf(OUSServiceCallParameters) = Type("Structure") Then
		
		If OUSServiceCallParameters.Property("HandleResponse") Then
			HandleResponse = OUSServiceCallParameters.HandleResponse;
		EndIf;
		
		If OUSServiceCallParameters.Property("DisplayCallStatus") Then
			DisplayCallStatus = OUSServiceCallParameters.DisplayCallStatus;
		EndIf;
		
		If OUSServiceCallParameters.Property("ClearSessionBeforeExecutionOfQuery") Then
			ItIsRequiredToClearSession = OUSServiceCallParameters.ClearSessionBeforeExecutionOfQuery;
		EndIf;
		
	EndIf;
	
	If DisplayCallStatus = True Then
		DisplayStatusServiceCall();
	EndIf;
	
	If ItIsRequiredToClearSession = True AND InteractionContext <> Undefined Then
		ClearSession(InteractionContext);
	EndIf;
	
	// If the command handler context is not specified, it is necessary to prepare its structure.
	If HandlerContext = Undefined Then
		// Creating commands handler context
		HandlerContext = OnlineUserSupportClientServer.NewCommandsHandlerContext();
	EndIf;
	
	If InteractionContext = Undefined Then
		MainParameters = Undefined;
	Else
		MainParameters = InteractionContext.COPContext.MainParameters;
	EndIf;
	
	If Not ContinueExecution Then
		
		If QueryParameters = Undefined Then
			QueryParameters = New Array;
		EndIf;
		
		// If the first call is
		// executed, web-service commands have to be received
		
		If InteractionContext = Undefined Then
			
			// Processing the first start when
			// the interaction context is not specified Creating the interaction
			// context at infobase server side and first call to the OUS service (to minimize client-server calls)
			OnlineUserSupportServerCall.ServiceCommandsDataProcessor(
				Undefined,
				QueryParameters,
				HandlerContext,
				False,
				OUSServiceCallParameters,
				AdditionalQueryParameters,
				InteractionContext,
				ContextCreationParameters);
			
			If InteractionContext.Property("StartManagementStructure") Then
				HandleIUSStartStructure(ContextCreationParameters.LaunchLocation,
					InteractionContext.StartManagementStructure);
				NotifyOfBusinessProcessCompletion(BusinessProcessCompletionHandlers, Undefined);
				Return;
			EndIf;
			
			InteractionContext.Insert("BusinessProcessCompletionHandlers",
				BusinessProcessCompletionHandlers);
			
			MainParameters = InteractionContext.COPContext.MainParameters;
			If Not MainParameters.CallFromServer Then
				
				OnlineUserSupportClientServer.AddSessionParametersToQuery(
					InteractionContext.COPContext,
					AdditionalQueryParameters,
					QueryParameters);
				
				AddServiceCommands(
					InteractionContext,
					QueryParameters,
					HandlerContext);
				
			EndIf;
			
		Else
			
			// At subsequent starts, everything runs in the standard mode
			
			If MainParameters.CallFromServer Then
				
				OnlineUserSupportServerCall.ServiceCommandsDataProcessor(
					InteractionContext.COPContext,
					QueryParameters,
					HandlerContext,
					False,
					OUSServiceCallParameters,
					AdditionalQueryParameters);
				
			Else
				
				OnlineUserSupportClientServer.AddSessionParametersToQuery(
					InteractionContext.COPContext,
					AdditionalQueryParameters,
					QueryParameters);
				
				AddServiceCommands(
					InteractionContext,
					QueryParameters,
					HandlerContext);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If server response handling is not required, then return
	If HandleResponse <> True Then
		Return;
	EndIf;
	
	BreakCommandProcessing = False;
	Try
		
		While HandlerContext.Commands.Count() > 0
			AND Not HandlerContext.ErrorOccurred
			AND Not HandlerContext.MakeStop
			AND Not BreakCommandProcessing Do
			
			CurrentCommand = HandlerContext.Commands[0];
			CommandType = OnlineUserSupportClientServer.CommandType(
				CurrentCommand,
				MainParameters.CallFromServer,
				MainParameters.LaunchLocation);
			
			If CommandType = -1 Then
				// If the command type (a client or server)
				// can not be determined, skip the command
				HandlerContext.Commands.Delete(0);
				Continue;
				
			ElsIf CommandType = 1 Then
				
				// Executing the command on client
				HandlerContext.Commands.Delete(0);
				RunServiceCommand(
					InteractionContext,
					CurrentForm,
					CurrentCommand,
					HandlerContext,
					BreakCommandProcessing);
				
			Else
				// If it is a server command, then
				// pass control to the 1C:Enterprise server At next
				// call the web-service is not addressed, therefore session parameters are not transferred
				OnlineUserSupportServerCall.ServiceCommandsDataProcessor(
					InteractionContext.COPContext,
					Undefined,
					HandlerContext,
					True);
				
			EndIf;
			
		EndDo;
		
	Except
		
		HandlerContext.ErrorOccurred = True;
		HandlerContext.ActionsOnErrorForServer.Add("CreateLogRegistrationRecord");
		HandlerContext.ActionsOnErrorForServer.Add("BreakBusinessProcess");
		HandlerContext.FullErrorDescription = NStr("en='Non-handled exception is thrown:';ru='Произошло необрабатываемое исключение:'")
			+ " " + DetailErrorDescription(ErrorInfo());
		
		HandlerContext.UserErrorDescription =
			NStr("en='Unknown error. For more details see event log.';ru='Неизвестная ошибка. Подробнее см. в журнале регистрации.'");
		HandlerContext.ActionOnErrorForClient = "ShowMessage";
		
	EndTry;
	
	If DisplayCallStatus = True Then
		Status();
	EndIf;
	
	AdditProperties = HandlerContext.AdditProperties;
	If AdditProperties.Property("UserLoginChanged") Then
		
		COPContext = InteractionContext.COPContext;
		IIPUserLogin = AdditProperties.UserLoginChanged;
		AdditProperties.Delete("UserLoginChanged");
		COPContext.Login = IIPUserLogin;
		Notify("OnlineSupportChangeAuthorizationData",
			New Structure("Login", IIPUserLogin));
		
		If IsBlankString(IIPUserLogin) Then
			
			// User exit
			If InteractionContext.Property("LoginAndPasswordEntered") Then
				InteractionContext.Delete("LoginAndPasswordEntered");
			EndIf;
			
		Else
			
			LoginAndPasswordEntered = New Structure("Login, Password",
				IIPUserLogin,
				OnlineUserSupportClientServer.SessionParameterValue(COPContext, "password"));
			
			InteractionContext.Insert("LoginAndPasswordEntered", LoginAndPasswordEntered);
			
		EndIf;
		
	EndIf;
	
	If BreakCommandProcessing AND Not HandlerContext.ErrorOccurred Then
		// When an asynchronous action occurs, it
		// is necessary to terminate service commands handling. The execution will be
		// initiated by completion of an asynchronous action.
		Return;
	EndIf;
	
	// If an error ocurred while running the process, then process the error
	If HandlerContext.ErrorOccurred Then
		
		CloseAllForms(InteractionContext);
		
		NotifyOfBusinessProcessCompletion(InteractionContext.BusinessProcessCompletionHandlers,
			InteractionContext);
		
		// Terminate session
		If HandlerContext.ActionsOnErrorForServer.Count() > 0 Then
			
			// Terminating a session on the infobase server
			OnlineUserSupportServerCall.EndOnlineSupportSession(
				InteractionContext.COPContext,
				HandlerContext);
			
			If HandlerContext.ActionsOnErrorForServer.Count() > 0 Then
				// Only the session closure action is left,
				// i.e. it is required to send the business process completion command from the client application
				EndBusinessProcess(InteractionContext);
			EndIf;
			
		EndIf;
		
		If HandlerContext.ActionOnErrorForClient = "DisplayFormConnectionNotAvailable" Then
			
			FormParameters = CallErrorFormParameters(InteractionContext);
			FormParameters.Insert("ErrorDescription",
				HandlerContext.UserErrorDescription);
			OpenForm("CommonForm.OnlineUserSupportInternetAccessError",
				FormParameters);
			
		ElsIf HandlerContext.ActionOnErrorForClient = "ShowMessage"
			AND Not IsBlankString(HandlerContext.UserErrorDescription) Then
			
			ShowMessageBox(,
				HandlerContext.UserErrorDescription,
				,
				NStr("en='Online user support';ru='Интернет-поддержка пользователей'"));
			Return;
			
		EndIf;
		
	ElsIf HandlerContext.MakeStop Then
		
		NotifyOfBusinessProcessCompletion(InteractionContext.BusinessProcessCompletionHandlers,
			InteractionContext);
		
		If HandlerContext.Property("StopCauseDescription") Then
			ShowUserNotification(NStr("en='Online user support';ru='Интернет-поддержка пользователей'"),
				,
				HandlerContext.StopCauseDescription,
				PictureLib.OnlineUserSupport);
		EndIf;
		
		EndBusinessProcess(InteractionContext);
		
	ElsIf InteractionContext.Property("BusinessProcessIsCompletedSuccessfully")
		AND InteractionContext.BusinessProcessIsCompletedSuccessfully = True Then
		
		NotifyOfBusinessProcessCompletion(InteractionContext.BusinessProcessCompletionHandlers,
			InteractionContext);
		
	EndIf;
	
EndProcedure

// Adds commands to the commands stack of the commands handler context
//
Procedure AddServiceCommands(
	InteractionContext,
	AdditionalParameters,
	HandlerContext = Undefined) Export
	
	#If Not WebClient Then
	
	MainParameters = InteractionContext.COPContext.MainParameters;
	
	Try
		
		If InteractionContext.OUSServiceDescription = Undefined Then
			InteractionContext.OUSServiceDescription = OnlineUserSupportClientServer.NewOUSServiceDescription(
				MainParameters.WSDefinitionName,
				InteractionContext.OUSNetworkParameters);
		EndIf;
		
		OUSServiceDescription = InteractionContext.OUSServiceDescription;
		
	Except
		
		If TypeOf(HandlerContext) = Type("Structure") Then
			HandlerContext.ErrorOccurred      = True;
			HandlerContext.FullErrorDescription = DetailErrorDescription(ErrorInfo());
			HandlerContext.ActionsOnErrorForServer.Add("CreateLogRegistrationRecord");
			HandlerContext.ActionOnErrorForClient = "DisplayFormConnectionNotAvailable";
			HandlerContext.UserErrorDescription =
				NStr("en='An error occurred while connecting to the online support service.';ru='Ошибка при подключении к сервису Интернет-поддержки.'");
		EndIf;
		
		Return;
		
	EndTry;
	
	Try
		
		OnlineUserSupportClientServer.AddServiceCommands(
			OUSServiceDescription,
			AdditionalParameters,
			HandlerContext,
			MainParameters);
		
		// After the first call, disable the network timeout, because
		// the checking of call by timeout is already completed
		If InteractionContext.OUSNetworkParameters.NetworkTimeout <> 0 Then
			InteractionContext.OUSNetworkParameters.NetworkTimeout = 0;
			OnlineUserSupportClientServer.ChangeCallTimeout(OUSServiceDescription, 0);
		EndIf;
		
	Except
		
		If TypeOf(HandlerContext) = Type("Structure") Then
			HandlerContext.ErrorOccurred      = True;
			HandlerContext.FullErrorDescription = DetailErrorDescription(ErrorInfo());
			HandlerContext.ActionsOnErrorForServer.Add("CreateLogRegistrationRecord");
			HandlerContext.ActionOnErrorForClient = "DisplayFormConnectionNotAvailable";
			HandlerContext.UserErrorDescription = NStr("en='An error occurred while retrieving data from the online support server.';ru='Ошибка при получении данных с сервера Интернет-поддержки.'");
		EndIf;
		
	EndTry;
	
	#EndIf
	
EndProcedure

// Executes the specified service command.
//
Procedure RunServiceCommand(
	InteractionContext,
	CurrentForm,
	CommandStructure,
	HandlerContext,
	BreakCommandProcessing)
	
	CommandName = Undefined;
	CommandStructure.Property("CommandName", CommandName);
	
	If TypeOf(CommandName) <> Type("String") Then
		Return;
	EndIf;
	
	CommandName = Lower(TrimAll(CommandName));
	
	If CommandName = "store.put" Then
		OnlineUserSupportClientServer.ParametersRecordCommandExecution(
			InteractionContext.COPContext,
			CommandStructure,
			HandlerContext);
		
	ElsIf CommandName = "store.get" Then
		OnlineUserSupportClientServer.ReadParametersCommandExecution(
			InteractionContext,
			CommandStructure,
			HandlerContext,
			False);
		
	ElsIf CommandName = "store.delete" Then
		OnlineUserSupportClientServer.DeleteContextParameters(
			InteractionContext.COPContext,
			CommandStructure,
			HandlerContext);
		
	ElsIf CommandName = "launchservice" Then
		ChangeBusinessProcess(InteractionContext, CommandStructure, HandlerContext);
		
	ElsIf CommandName = "ui.open" Then
		OpenInternalForm(InteractionContext, CurrentForm, CommandStructure);
		
	ElsIf CommandName = "ui.close" Then
		CloseInternalForm(InteractionContext, CommandStructure);
		
	ElsIf CommandName = "system.halt" Then
		StopMechanism(InteractionContext, CommandStructure);
		
	ElsIf CommandName = "message.show" Then
		ShowMessageToUser(
			CommandStructure,
			InteractionContext,
			CurrentForm,
			HandlerContext,
			BreakCommandProcessing);
		
	ElsIf CommandName = "question.show" Then
		AskQuestionToUser(InteractionContext, CurrentForm, CommandStructure);
		
	ElsIf CommandName = "input.field" Then
		EnterData(InteractionContext, CurrentForm, CommandStructure);
		
	ElsIf CommandName = "store.putorganizations" Then
		OnlineUserSupportClientServer.WriteCompaniesList(
			InteractionContext.COPContext,
			CommandStructure);
		
	ElsIf CommandName = "store.putadressclassifier" Then
		OnlineUserSupportClientServer.WriteAddressClassifier(
			InteractionContext.COPContext,
			CommandStructure);
		
	Else
		
		// Data processor in the additional business process handler
		AdditHandler = OnlineUserSupportClient.BusinessProcessClientHandler(
			InteractionContext.COPContext.MainParameters.LaunchLocation,
			"RunServiceCommand");
		
		If AdditHandler <> Undefined Then
			
			AdditHandler.RunServiceCommand(
				InteractionContext,
				CurrentForm,
				CommandStructure,
				HandlerContext,
				BreakCommandProcessing);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Execution of the form opening command.
//
Procedure OpenInternalForm(InteractionContext, CurrentForm, CommandStructure)
	
	MainParameters = InteractionContext.COPContext.MainParameters;
	
	FormParameters = Undefined;
	CommandStructure.Property("FormParameters", FormParameters);
	
	URL = Undefined;
	CommandStructure.Property("URL", URL);
	
	FormText = Undefined;
	CommandStructure.Property("Text", FormText);
	
	// Replacement of parameters in the form text
	If FormText <> Undefined Then
		If Find(FormText, "%Login%") Then
			ReplacementString = OnlineUserSupportClientServer.SessionParameterValue(
				InteractionContext.COPContext,
				"login");
			FormText = StrReplace(FormText, "%Login%", ReplacementString);
		EndIf;
	EndIf;
	
	If FormParameters <> Undefined Then
		
		OpenableFormName = Undefined;
		FormParameters.Property("OpenableFormName", OpenableFormName);
		
		Title = Undefined;
		FormParameters.Property("Title", Title);
		
		Text = Undefined;
		FormParameters.Property("Text", Text);
		
		If OpenableFormName = "Question" Then
			
			WarningText = ?(Text = Undefined, FormText, Text);
			
			AdditParameters = New Structure("InteractionContext, Form", InteractionContext, CurrentForm);
			NotifyDescription = New NotifyDescription("OnClickOKInStaticWarningForm",
				ThisObject,
				AdditParameters);
			
			ShowMessageBox(NOTifyDescription, WarningText, , Title);
			
		ElsIf OpenableFormName = "PopupToolTip" Then
			ShowUserNotification(
				Title,
				,
				FormText,
				PictureLib.OnlineUserSupport);
			
		Else
			
			If CurrentForm <> Undefined Then
				PerformSoftwareFormClosing(CurrentForm);
			EndIf;
			
			FormOpenParameters = GenerateFormOpeningParameters(
				InteractionContext.COPContext,
				OpenableFormName);
			
			If URL <> Undefined Then
				FormOpenParameters.Insert("URL", URL);
			EndIf;
			
			FormBeingOpened = GetForm(OpenableFormName, FormOpenParameters);
			
			Try
				FormBeingOpened.InteractionContext = InteractionContext;
			Except
			EndTry;
			
			FormBeingOpened.Open();
			
		EndIf;
		
		If FormParameters.Property("BusinessProcessSuccessfulCompletion") Then
			InteractionContext.Insert("BusinessProcessIsCompletedSuccessfully", True);
		EndIf;
		
	EndIf;
	
EndProcedure

// Preparing parameters for internal form opening.
//
Function GenerateFormOpeningParameters(COPContext, OpenableFormName) Export
	
	MainParameters = COPContext.MainParameters;
	
	NewFormParameters = New Structure;
	
	// The value of the login parameter is transferred to each form
	NewFormParameters.Insert("login",
		OnlineUserSupportClientServer.SessionParameterValue(COPContext, "login"));
	
	If OpenableFormName = "DataProcessor.OnlineSupportBasicFunctions.Form.CommonAuthorization"
		OR OpenableFormName = "DataProcessor.OnlineSupportBasicFunctions.Form.SimplifiedAuthorization" Then
		
		NewFormParameters.Insert("LaunchLocation", COPContext.MainParameters.LaunchLocation);
		NewFormParameters.Insert("password",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"password"));
		NewFormParameters.Insert("savePassword",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"savePassword"));
		
		NewFormParameters.Insert("OnStart", COPContext.OnStart);
		
	ElsIf OpenableFormName = "DataProcessor.OnlineSupportBasicFunctions.Form.CommonRegNumber" Then
		NewFormParameters.Insert("regnumber",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"regnumber"));
		
		NewFormParameters.Insert("OnStart", COPContext.OnStart);
		
	ElsIf OpenableFormName = "DataProcessor.OnlineSupportBasicFunctions.Form.CommonPinCode" Then
		NewFormParameters.Insert("regnumber",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"regnumber"));
		NewFormParameters.Insert("pincode",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"pincode"));
		
	ElsIf OpenableFormName = "DataProcessor.OnlineSupportBasicFunctions.Form.PasswordRecovery" Then
		NewFormParameters.Insert("login",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"login"));
		NewFormParameters.Insert("email",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"email"));
		
	ElsIf OpenableFormName = "DataProcessor.OnlineSupportBasicFunctions.Form.NewUserRegistration" Then
		NewFormParameters.Insert("login",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"login"));
		NewFormParameters.Insert("password",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"password"));
		NewFormParameters.Insert("email",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"email"));
		NewFormParameters.Insert("SecondName",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"SecondName"));
		NewFormParameters.Insert("FirstName",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"FirstName"));
		NewFormParameters.Insert("MiddleName",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"MiddleName"));
		NewFormParameters.Insert("City",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"City"));
		NewFormParameters.Insert("PhoneNumber",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"PhoneNumber"));
		NewFormParameters.Insert("workPlace",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext,"workPlace"));
		
	ElsIf OpenableFormName = "DataProcessor.OnlineSupportBasicFunctions.Form.OnlineSupportProductNotAvailable" Then
		
		If COPContext.Property("OnStart") Then
			NewFormParameters.Insert("OnStart", COPContext.OnStart);
		EndIf;
		
	Else
		
		// Getting form parameters through an additional business process handler
		AdditHandler = OnlineUserSupportClient.BusinessProcessClientHandler(
			MainParameters.LaunchLocation,
			"FormOpenParameters");
		
		If AdditHandler <> Undefined Then
			AdditHandler.FormOpenParameters(COPContext, OpenableFormName, NewFormParameters);
		EndIf;
		
	EndIf;
	
	Return NewFormParameters;
	
EndFunction

// Executing the command of internal form closure.
//
Procedure CloseInternalForm(InteractionContext, CommandStructure)
	
	DataProcessorForms    = InteractionContext.DataProcessorForms;
	MainParameters = InteractionContext.COPContext.MainParameters;
	
	FormParameters = Undefined;
	CommandStructure.Property("FormParameters", FormParameters);
	
	If FormParameters <> Undefined Then
		
		OpenableFormName = Undefined;
		FormParameters.Property("OpenableFormName", OpenableFormName);
		
		If OpenableFormName = Undefined Then
			Return;
		EndIf;
		
		Form = DataProcessorForms[OpenableFormName];
		
		If Form = Undefined OR Not Form.IsOpen() Then
			Return;
		EndIf;
		
		PerformSoftwareFormClosing(Form);
		
	EndIf;
	
EndProcedure

// Executing the "Ask user a question" service command.
//
Procedure AskQuestionToUser(InteractionContext, Form, CommandStructure)
	
	QuestionType = Undefined;
	CommandStructure.Property("Type", QuestionType);
	
	If QuestionType = "richanswer" Then
		
		ButtonList = CommandStructure.Buttons;
		
	Else
		
		ButtonList = New ValueList;
		For Each ButtonItem IN CommandStructure.Buttons Do
			If ButtonItem.Value = "yes" Then
				ButtonList.Add(DialogReturnCode.Yes);
			ElsIf ButtonItem.Value = "no" Then
				ButtonList.Add(DialogReturnCode.No);
			ElsIf ButtonItem.Value = "cancel" Then
				ButtonList.Add(DialogReturnCode.Cancel);
			ElsIf ButtonItem.Value = "ok" Then
				ButtonList.Add(DialogReturnCode.OK);
			EndIf;
		EndDo;
		
	EndIf;
	
	AddQuestionParameters = New Structure("InteractionContext, QuestionType, Form",
		InteractionContext,
		QuestionType,
		Form);
	
	NotifyDescription = New NotifyDescription("WhenAnsweringQuestionCommandsQuestion",
		ThisObject,
		AddQuestionParameters);
	
	ShowQueryBox(NOTifyDescription, CommandStructure.MessageText, ButtonList, , , CommandStructure.Title);
	
EndProcedure

// Asynchronous handler of user response
// at execution of the AskQuestionToUser() command
//
Procedure WhenAnsweringQuestionCommandsQuestion(QuestionResult, AdditParameters) Export
	
	If AdditParameters.QuestionType = "richanswer" Then
		ResponseToService = QuestionResult;
		
	Else
		ResponseToService = "Cancel";
		If QuestionResult = DialogReturnCode.Yes Then
			ResponseToService = "Yes";
		ElsIf QuestionResult = DialogReturnCode.No Then
			ResponseToService = "No";
		ElsIf QuestionResult = DialogReturnCode.OK Then
			ResponseToService = "OK";
		EndIf;
		
	EndIf;
	
	QueryParameters = New Array;
	QueryParameters.Add(New Structure("Name, Value", "answer", ResponseToService));
	
	ServiceCommandsDataProcessor(AdditParameters.InteractionContext, AdditParameters.Form, QueryParameters);
	
EndProcedure

// Execution of the "Show message to user" service command.
//
Procedure ShowMessageToUser(
	CommandStructure,
	InteractionContext,
	CurrentForm,
	HandlerContext,
	BreakCommandProcessing)
	
	MessageType = Undefined;
	CommandStructure.Property("Type", MessageType);
	
	If MessageType = "usernotification" Then
		
		ShowUserNotification(
			CommandStructure.Title,
			,
			CommandStructure.MessageText,
			PictureLib.OnlineUserSupport);
		
	Else
		
		BreakCommandProcessing = True;
		AdditNotificationParameters = New Structure("InteractionContext, Form, HandlerContext",
			InteractionContext,
			CurrentForm,
			HandlerContext);
		
		NotifyDescription = New NotifyDescription(
			"OnClickOKInUserMessageForm",
			ThisObject,
			AdditNotificationParameters);
		
		ShowMessageBox(NOTifyDescription, CommandStructure.MessageText, , CommandStructure.Title);
		
	EndIf;
	
EndProcedure

// Asynchronous handler of OK click in the
// user message form at execution of the "Show message to user" service command.
//
Procedure OnClickOKInUserMessageForm(AdditParameters) Export
	
	ServiceCommandsDataProcessor(
		AdditParameters.InteractionContext,
		AdditParameters.Form,
		,
		AdditParameters.HandlerContext,
		,
		,
		True);
	
EndProcedure

// Asynchronous handler of OK click by
// the user at executing the command for static form opening.
//
Procedure OnClickOKInStaticWarningForm(AdditParameters) Export
	
	ServiceCommandsDataProcessor(AdditParameters.InteractionContext, AdditParameters.Form, Undefined);
	
EndProcedure

// Execution of the "Enter data" service command. The
// execution opens a universal form
// for entering data - DataProcessor.OnlineSupportBasicFunctions.Form.DataEnter
//
Procedure EnterData(InteractionContext, Form, CommandStructure)
	
	MainParameters = InteractionContext.COPContext.MainParameters;
	
	AdditParameters = New Structure("Form, InteractionContext", Form, InteractionContext);
	
	NotifyDescription = New NotifyDescription(
		"WhenUserEntersData",
		ThisObject,
		AdditParameters);
	
	DataInputFormName = "DataProcessor.OnlineSupportBasicFunctions.Form.DataEntry";
	OpenForm(DataInputFormName,
		CommandStructure.FormParameters,
		,
		,
		,
		,
		NotifyDescription);
	
EndProcedure

// Asynchronous handler of data input by
// the user as a result of executing the WhenUserEntersData() command
//
Procedure WhenUserEntersData(EnteredData, AdditParameters) Export
	
	Form = AdditParameters.Form;
	InteractionContext = AdditParameters.InteractionContext;
	
	QueryParameters = New Array;
	If EnteredData <> Undefined AND EnteredData <> DialogReturnCode.Cancel Then
		QueryParameters.Add(New Structure("Name, Value", "value", EnteredData));
	EndIf;
	
	ServiceCommandsDataProcessor(InteractionContext, Form, QueryParameters);
	
EndProcedure

// Executes the command of changing current OUS service address.
//
Procedure ChangeBusinessProcess(InteractionContext, CommandStructure, HandlerContext)
	
	MainParameters = InteractionContext.COPContext.MainParameters;
	
	CommandParameters = Undefined;
	CommandStructure.Property("Parameters", CommandParameters);
	
	BusinessProcess = Undefined;
	NameURI        = Undefined;
	
	For Each CommandParameter IN CommandParameters Do
		
		If CommandParameter.Property("bp", BusinessProcess) Then
			MainParameters.WSDefinitionName = BusinessProcess;
		EndIf;
		
		If CommandParameter.Property("nameURI", NameURI) Then
			MainParameters.OfURIService = NameURI;
		EndIf;
		
	EndDo;
	
	// Adding session number
	QueryParameters = New Array;
	
	OnlineUserSupportClientServer.AddSessionParametersToQuery(
		InteractionContext.COPContext,
		, // only "session_id" is added
		QueryParameters);
	
	// Connection changing
	InteractionContext.OUSServiceDescription = Undefined;
	
	// Call the new web-service for commands and write the commands to the commands stack
	AddServiceCommands(
		InteractionContext,
		QueryParameters,
		HandlerContext);
	
EndProcedure

// Running the command of OUS mechanism stopping. Closing
// all forms; when appropriate, the OUS service call error
// is displayed and recorded in the registration log.
//
Procedure StopMechanism(InteractionContext, CommandStructure)
	
	CloseAllForms(InteractionContext);
	
	CommandParameters = Undefined;
	CommandStructure.Property("Parameters", CommandParameters);
	
	If CommandParameters = Undefined Then
		Return;
	EndIf;
	
	ErrorCode = Undefined;
	For Each CommandParameter IN CommandParameters Do
		
		If CommandParameter.Property("errorCode", ErrorCode) Then
			Break;
		EndIf;
		
	EndDo;
	
	If TrimAll(String(ErrorCode)) <> "0" AND ErrorCode <> Undefined Then
		OnlineUserSupportServerCall.WriteErrorInEventLogMonitor(ErrorCode);
		FormParameters = CallErrorFormParameters(InteractionContext);
		FormParameters.Insert("ErrorDescription", ErrorCode);
		OpenForm("CommonForm.OnlineUserSupportInternetAccessError",
			FormParameters);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for arranging business processes

// Sending a management command for service resources release to the server.
// The service response is not under processing.
//
Procedure EndBusinessProcess(InteractionContext) Export
	
	If InteractionContext = Undefined Then
		Return;
	EndIf;
	
	NotifyOfBusinessProcessCompletion(InteractionContext.BusinessProcessCompletionHandlers,
		InteractionContext);
	
	CloseAllForms(InteractionContext);
	OUSServiceCallParameters = New Structure;
	OUSServiceCallParameters.Insert("HandleResponse"             , False);
	OUSServiceCallParameters.Insert("DisplayCallStatus", False);
	
	ProcessFormCommand(InteractionContext, Undefined, "CloseBP", OUSServiceCallParameters);
	
	WSDLDescriptionsCache = Undefined;
	MainParameters = InteractionContext.COPContext.MainParameters;
	MainParameters.Property("WSDLDescriptionsCache", WSDLDescriptionsCache);
	If WSDLDescriptionsCache <> Undefined Then
		OnlineUserSupportServerCall.ClearWSDLDescriptionsCache(WSDLDescriptionsCache);
	EndIf;
	
EndProcedure

// Access to the OUS service with the specified parameter.
// One parameter with the specified name and "true" value is passed.
//
Procedure ProcessFormCommand(
	InteractionContext,
	Form,
	CommandName,
	OUSServiceCallParameters = Undefined) Export
	
	QueryParameters        = New Array;
	QueryParameters.Add(New Structure("Name, Value", CommandName, "true"));
	
	ServiceCommandsDataProcessor(InteractionContext, Form, QueryParameters, , OUSServiceCallParameters);
	
EndProcedure

// Handling exit of the user from OUS (click Exit on the form).
//
Procedure HandleUserExit(InteractionContext, Form) Export
	
	AdditParameters = New Structure("InteractionContext, Form", InteractionContext, Form);
	
	NotifyDescription = New NotifyDescription("WhenUserRepliesToExitQuestion", ThisObject, AdditParameters);
	
	QuestionText = QuestionWhenAuthorizedUserExits(InteractionContext);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, 0, DialogReturnCode.No);
	
EndProcedure

// Asynchronous handler of user response to the question on
// exit from OUS in the HandleUserExit() procedure.
//
Procedure WhenUserRepliesToExitQuestion(QuestionResult, AdditParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		CloseAllForms(AdditParameters.InteractionContext);
		OnlineUserSupportServerCall.ClearUserUOSSettings();
		ProcessFormCommand(AdditParameters.InteractionContext, AdditParameters.Form, "exitUser");
	EndIf;
	
EndProcedure

// Opening a dialog for sending a message to the technical service of Online User Support.
//
Procedure OpenDialogForSendingEmail(InteractionContext, EmailParameters) Export
	
	If EmailParameters = Undefined Then
		EmailParameters = New Structure;
	EndIf;
	
	COPContext = InteractionContext.COPContext;
	EmailParameters.Insert("LaunchLocation", COPContext.MainParameters.LaunchLocation);
	EmailParameters.Insert("OnStart",
		InteractionContext.COPContext.OnStart);
	
	EmailParameters.Insert("Login",
		OnlineUserSupportClientServer.SessionParameterValue(COPContext, "login"));
	
	EmailSendingForm = GetForm(
		"DataProcessor.OnlineSupportBasicFunctions.Form.EmailSending",
		EmailParameters);
	
	EmailSendingForm.InteractionContext = InteractionContext;
	EmailSendingForm.Open();
	
EndProcedure

// Directly send an electronic message to the technical service of Online User Support
//
Function SendEmailToSupportService(MessageStructure, InteractionContext) Export
	
	If InteractionContext.COPContext.MainParameters.CallFromServer Then
		Return OnlineUserSupportServerCall.SendEmailThroughService(
			MessageStructure,
			InteractionContext.COPContext.MainParameters.OUSNetworkParameters);
	Else
		Return OnlineUserSupportClientServer.SendEmailThroughService(
			MessageStructure,
			InteractionContext.OUSNetworkParameters);
	EndIf;
	
EndFunction

// Returns an empty list of
// business process completion notification handlers.
//
// Returns:
// Structure - an empty list of business
// 			process completion notification handlers.
// 	* Processed - Boolean - True if the
// 		notification is given, False - otherwise.
// 	*LaunchPlace - business process entry point;
//
Function NewBusinessProcessCompletionHandler(LaunchLocation)
	
	Result = New Structure;
	Result.Insert("Processed"  , False);
	Result.Insert("LaunchLocation", LaunchLocation);
	
	Return Result;
	
EndFunction

// Calls business process completion notification handlers.
//
// Parameters:
// BusinessProcessCompletionHandlers - Structure - business process
// 	completion notification handlers
// 	(see
// the NewBusinessProcessCompletionHandler() function) InteractionContext - Structure, Undefined - business process context.
// see	the
// 	OnlineUserSupportServerCall.NewInteractionContext() function
//
Procedure NotifyOfBusinessProcessCompletion(
	BusinessProcessCompletionHandlers,
	InteractionContext)
	
	If BusinessProcessCompletionHandlers = Undefined
		OR BusinessProcessCompletionHandlers.Processed Then
		Return;
	EndIf;
	
	If BusinessProcessCompletionHandlers.Property("NotificationsAboutAuthorization") Then
		// Notification of authorization
		If InteractionContext = Undefined
			OR Not InteractionContext.Property("BusinessProcessIsCompletedSuccessfully")
			OR Not InteractionContext.BusinessProcessIsCompletedSuccessfully
			OR Not InteractionContext.Property("LoginAndPasswordEntered") Then
			ResultForNotification = Undefined;
		Else
			ResultForNotification = InteractionContext.LoginAndPasswordEntered;
		EndIf;
		For Each Handler IN BusinessProcessCompletionHandlers.NotificationsAboutAuthorization Do
			ExecuteNotifyProcessing(Handler, ResultForNotification);
		EndDo;
		BusinessProcessCompletionHandlers.Processed = True;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with OUS parameters in interaction context

// Deleting context session parameters.
//
Procedure ClearSession(InteractionContext)
	
	SessionalParameters = InteractionContext.COPContext.SessionalParameters;
	CountParameters = SessionalParameters.Count();
	If CountParameters > 0 Then
		For ReverseIndex = 1 To CountParameters Do
			IndexOf = CountParameters - ReverseIndex;
			If SessionalParameters[IndexOf].Scope <> "startUp" Then
				SessionalParameters.Delete(IndexOf);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Interface procedures and functions

// Representation of OUS web-service call status.
//
Procedure DisplayStatusServiceCall()
	
	Status(
		,
		,
		NStr("en='Waiting for response from the online user support server';ru='Ожидание ответа от сервера Интернет-поддержки пользователей'"),
		PictureLib.OnlineUserSupport);
	
EndProcedure

// Closing all context forms.
//
Procedure CloseAllForms(InteractionContext)
	
	DataProcessorForms = InteractionContext.DataProcessorForms;
	If TypeOf(DataProcessorForms) = Type("Map") Then
		TypeControllableForm = Type("ManagedForm");
		For Each KeyValue IN DataProcessorForms Do
			Form = KeyValue.Value;
			If TypeOf(Form) = TypeControllableForm AND Form.IsOpen() Then
				Form.SoftwareClosing = True;
				Form.Close();
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

// Application closure of the OUS context form.
//
Procedure PerformSoftwareFormClosing(FormBeingClosed)
	
	If FormBeingClosed <> Undefined Then
		
		If FormBeingClosed.IsOpen() Then
			
			Try
				FormBeingClosed.SoftwareClosing = True;
			Except
			EndTry;
			
			FormBeingClosed.Close();
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Determines whether the specified context form is opened or not.
//
Function FormIsOpened(InteractionContext, FormBeingCheckedName) Export
	
	DataProcessorForms = InteractionContext.DataProcessorForms;
	
	If TypeOf(DataProcessorForms) <> Type("Map") Then
		DataProcessorForms = New Map;
	EndIf;
	
	FormBeingChecked = DataProcessorForms[FormBeingCheckedName];
	If FormBeingChecked = Undefined Then
		Return False;
	Else
		Return FormBeingChecked.IsOpen();
	EndIf;
	
EndFunction

// Registration of the opened internal OUS form in interaction context.
//
Procedure HandleFormOpening(InteractionContext, OpenedForm) Export
	
	If InteractionContext = Undefined Then
		Return;
	EndIf;
	
	DataProcessorForms = InteractionContext.DataProcessorForms;
	
	If TypeOf(DataProcessorForms) <> Type("Map") Then
		DataProcessorForms = New Map;
	EndIf;
	
	DataProcessorForms[OpenedForm.FormName] = OpenedForm;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other service procedures and functions

// Auxiliary function to convert the value from a fixed type.
// Parameters:
// FixedTypeValue - Arbitrary - fixed type
// 	value from which it is necessary to obtain the value of unfixed type.
//
// Returns:
// Arbitrary - resulting value of a similar unfixed type.
//
Function ValueFromFixedType(FixedTypeValue)
	
	Result = Undefined;
	ValueType = TypeOf(FixedTypeValue);
	
	If ValueType = Type("FixedStructure") Then
		
		Result = New Structure;
		For Each KeyValue IN FixedTypeValue Do
			Result.Insert(KeyValue.Key, ValueFromFixedType(KeyValue.Value));
		EndDo;
		
	ElsIf ValueType = Type("FixedMap") Then
		
		Result = New Map;
		For Each KeyValue IN FixedTypeValue Do
			Result.Insert(KeyValue.Key, ValueFromFixedType(KeyValue.Value));
		EndDo;
		
	Else
		
		Result = FixedTypeValue;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Defines text of the question when an authorized user exits OUS.
//
Function QuestionWhenAuthorizedUserExits(InteractionContext) Export
	
	UserLogin = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"login");
	
	QuestionText = NStr("en='Connection of the user with login
		|%1 to online support will be disabled. For a new connection you need to enter your login and password once again.
		|Go to authorization of a new user?';ru='Подключение пользователя
		|с логином %1 к Интернет-поддержке будет прекращено. Для нового подключения нужно заново ввести логин и пароль.
		|Перейти к авторизации нового пользователя?'");
	QuestionText = StrReplace(QuestionText, "%1", UserLogin);
	
	Return QuestionText;
	
EndFunction

// Iterative copying of a list of values.
//
Procedure CopyValueListIteratively(Source, Receiver) Export
	
	Receiver.Clear();
	For Each SourceItem IN Source Do
		Receiver.Add(SourceItem.Value, SourceItem.Presentation);
	EndDo;
	
EndProcedure

// Returns parameters
// of the "CommonForm.OnlineUserSupportInternetAccessError" form generated based on the OUS service interaction context.
//
Function CallErrorFormParameters(InteractionContext)
	
	COPContext = InteractionContext.COPContext;
	MainParameters = COPContext.MainParameters;
	
	AccessErrorFormParameters = New Structure("StartLocation, StartParameters, AtSystemOperationStart",
		MainParameters.LaunchLocation,
		InteractionContext.MechanismStartParameters,
		COPContext.OnStart);
	
	Return AccessErrorFormParameters;
	
EndFunction

#EndRegion
