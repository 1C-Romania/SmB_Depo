
////////////////////////////////////////////////////////////////////////////////
// Subsystem "InternetSupport Monitor"
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Adds description of events handlers realized by the subsystem.
//
// Description of the procedures-processers format
// see in the description of the OnlineUserSupportServiceReUse function.EventsHandlers().
//
// Parameters:
// ServerHandlers - Structure - server handlers;
// 	* ClientWorkParametersOnStart - Array - the Row type elements -
// 		name of the modules that process
// 		<STRONG>the filling client work parameters at launch</STRONG>;
// 	* ClearIPPUserSettings - the Row type elements -
// 		name of modules that process users
// 		settings removal when an authorized user exits UOS;
// 	*BusinessProcesses - Map - server
// 		handlers of business processes:
// 		** Key - String - <Entry point of business process>\<Event name>;
// 		** Value - String - name of the
// 			server mode realising business process handler;
// ClientHandlers - Structure - client handlers;
// 	* OnStartSystemWork - the Row type elements -
// 		name of the client
// 		modules processing the On begin
// 	of system work event *BusinessProcesses - Map - client
// 		handlers of business processes:
// 		** Key - String - <Entry point of business process>\<Event name>;
// 		** Value - String - name of the
// 			client mode realising business process handler;
//
Procedure AddEventsHandlers(ServerHandlers, ClientHandlers) Export
	
	ServerHandlers.ClientWorkParametersOnStart.Add("OnlineSupportMonitor");
	ServerHandlers.ClearUserUOSSettings.Add("OnlineSupportMonitor");
	ClientHandlers.OnStart.Add("OnlineSupportMonitorClient");
	
	// Server handlers of business processes
	BusinessProcessesServer = ServerHandlers.BusinessProcesses;
	BusinessProcessesServer.Insert("systemStartNew\ContextCreationParameters",
		"OnlineSupportMonitor");
	BusinessProcessesServer.Insert("systemStartNew\DefineLaunchPossibility",
		"OnlineSupportMonitorClientServer");
	BusinessProcessesServer.Insert("systemStartNew\OnCreateInteractionContext",
		"OnlineSupportMonitor");
	BusinessProcessesServer.Insert("systemStartNew\CommandRunContext",
		"OnlineSupportMonitorClientServer");
	BusinessProcessesServer.Insert("systemStartNew\RunServiceCommand",
		"OnlineSupportMonitor");
	BusinessProcessesServer.Insert("systemStartNew\StructureServiceCommand",
		"OnlineSupportMonitorClientServer");
	BusinessProcessesServer.Insert("systemStartNew\FillInternalFormParameters",
		"OnlineSupportMonitorClientServer");
	
	BusinessProcessesServer.Insert("handStartNew\ContextCreationParameters",
		"OnlineSupportMonitor");
	BusinessProcessesServer.Insert("handStartNew\DefineLaunchPossibility",
		"OnlineSupportMonitorClientServer");
	BusinessProcessesServer.Insert("handStartNew\OnCreateInteractionContext",
		"OnlineSupportMonitor");
	BusinessProcessesServer.Insert("handStartNew\CommandRunContext",
		"OnlineSupportMonitorClientServer");
	BusinessProcessesServer.Insert("handStartNew\RunServiceCommand",
		"OnlineSupportMonitor");
	BusinessProcessesServer.Insert("handStartNew\StructureServiceCommand",
		"OnlineSupportMonitorClientServer");
	BusinessProcessesServer.Insert("handStartNew\FillInternalFormParameters",
		"OnlineSupportMonitorClientServer");
	
	
	// Client handlers of business processes
	
	BusinessProcessesClient = ClientHandlers.BusinessProcesses;
	BusinessProcessesClient.Insert("systemStartNew\DefineLaunchPossibility",
		"OnlineSupportMonitorClientServer");
	BusinessProcessesClient.Insert("systemStartNew\CommandRunContext",
		"OnlineSupportMonitorClientServer");
	BusinessProcessesClient.Insert("systemStartNew\FormOpenParameters",
		"OnlineSupportMonitorClient");
	BusinessProcessesClient.Insert("systemStartNew\StructureServiceCommand",
		"OnlineSupportMonitorClientServer");
	BusinessProcessesClient.Insert("systemStartNew\FillInternalFormParameters",
		"OnlineSupportMonitorClientServer");
	
	BusinessProcessesClient.Insert("handStartNew\DefineLaunchPossibility",
		"OnlineSupportMonitorClientServer");
	BusinessProcessesClient.Insert("handStartNew\CommandRunContext",
		"OnlineSupportMonitorClientServer");
	BusinessProcessesClient.Insert("handStartNew\FormOpenParameters",
		"OnlineSupportMonitorClient");
	BusinessProcessesClient.Insert("handStartNew\StructureServiceCommand",
		"OnlineSupportMonitorClientServer");
	BusinessProcessesClient.Insert("handStartNew\FillInternalFormParameters",
		"OnlineSupportMonitorClientServer");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Common use

// It adds parameters necessary for the client work at starting.
// Added parameters
// available in StandardSubsystemsClientReUse.ClientWorkParametersOnLaunch().UserOnlineSupport.<ParameterName>;
// Used in case the subsystem implements the
// script executed on start of the system work.
// Called from UsersOnlineSupport.ClientWorkParametersOnLaunch()
//
// Parameters:
// Parameters - Structure - Filled parameters;
//
Procedure ClientWorkParametersOnStart(Parameters) Export
	
	// Create context to
	// launch a business process of displaying the online support monitor.
	
	InteractionContext = OnlineUserSupportServerCall.NewInteractionContext(
		"systemStartNew",
		False,
		Undefined,
		True);
	
	Parameters.Insert("OnlineSupportMonitor", InteractionContext);
	
EndProcedure

// Called during the logoff of
// an authorized user from the online support after clicking Logoff.
// Clears user settings implemented by the subsystem.
// Called from UsersOnlineSupportServerCall.ClearUserOSSettings()
//
Procedure ClearUserUOSSettings() Export
	
	CommonUse.CommonSettingsStorageSave(
		"OnlineUserSupport",
		"InformationWindowUpdateHash",
		Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Business processes handlers

// Called during filling of business process context creation parameters.See
// the UsersOnlineSupportServeerCall procedure.ContextCreationParameters().
//
// Parameters:
// Parameters - Structure - refilled parameters:
// *LaunchPlace - String - business process entry point;
// * OnStartSystemWork - Boolean - True if
// 	business processor is launched at the system start;
// * UseOnlineSupport - Boolean - True if
// 	you are allowed to use OUS for the current IB mode;
// * StartAllowed - Boolean - True if the current
// 	user is allowed to launch IPP;
// BreakProcessing - Boolean - shows that further processing
// 	is returned in the parameter if you know
// 	that further processing is not required.
//
Procedure ContextCreationParameters(Parameters, BreakProcessing) Export
	
	If Not Users.RolesAvailable("UseUOSMonitor", , False) Then
		Parameters.LaunchAllowed = False;
		Return;
	EndIf;
	
	Cancel = False;
	OnlineSupportMonitorOverridable.UseOnlineSupportMonitor(Cancel);
	UseMonitor = (Cancel <> True);
	
	Parameters.Insert("UseMonitor", UseMonitor);
	
	If UseMonitor Then
		Parameters.Insert("ShowMonitorOnStart",
			ShowMonitorOnApplicationStart());
	Else
		Parameters.Insert("ShowMonitorOnStart", False);
	EndIf;
	
	If Parameters.OnStart
		AND Not Parameters.ShowMonitorOnStart Then
		BreakProcessing = True;
	EndIf;
	
EndProcedure

// Adds required parameters to a
// created context of business process.
// Called from UsersOnlineSupportServerCall.NewInteractionContext()
//
// Parameters:
// Context - see the
//		UsersOnlineSupportServerCall.NewInteractionContext() function
Procedure OnCreateInteractionContext(Context) Export
	
	Context.COPContext.Insert("HashInformationMonitor", "");
	Context.Insert("MessageActionsUnavailable",
		NStr("en='Displaying of the online support dashboard is not available for this configuration.';ru='Отображение монитора Интернет-поддержки недоступно для этой конфигурации.'"));
	
EndProcedure

// Execute IPP server command on 1C:Enterprise server side.
// Called
// from UsersOnlineSupportServerCall.RunServiceCommand() Parameters:
// COPContext - see description
// 	of the UsersOnlineSupportServerCall.NewInteractionContext() function;
// CommandStructure - see description
// 	of the UsersOnlineSupportClientServer.OutlineServerAnswer() function;
// HandlerContext - see description
// 	of the UsersOnlineSupportClientServer.NewCommandsHandlerProcess() function
//
Procedure RunServiceCommand(COPContext, CommandStructure, HandlerContext) Export
	
	If CommandStructure.CommandName = "check.updatehash" Then
		CheckUpdateHash(COPContext, CommandStructure, HandlerContext);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Executes the command to compare a
// hash of information update of online support monitor.
//
Procedure CheckUpdateHash(COPContext, CommandStructure, HandlerContext)
	
	MainParameters = COPContext.MainParameters;
	
	If MainParameters.LaunchLocation <> "systemStartNew"
		AND MainParameters.LaunchLocation <> "handStartNew" Then
		// If OUS monitor is not shown, then do not process the command
		Return;
	EndIf;
	
	UpdateHashSaved = CommonUse.CommonSettingsStorageImport(
		"OnlineUserSupport",
		"InformationWindowUpdateHash");
	
	COPContext.HashInformationMonitor = CommandStructure.UpdateHash;
	
	HasUpdateHashChanges = (UpdateHashSaved <> COPContext.HashInformationMonitor);
	
	If Not COPContext.OnStart Then
		Return;
	Else
		
		// If OnStartSystemWork, then the setting of showing on launch
		// is set to True Read the setting of displaying
		// on change and show information window if required
		
		SettingShowOnUpdate = CommonUse.CommonSettingsStorageImport(
			"OnlineUserSupport",
			"ShowOnStartOnlyOnChange");
		If SettingShowOnUpdate = True
			AND Not HasUpdateHashChanges Then
			
			HandlerContext.MakeStop = True;
			HandlerContext.Insert("StopCauseDescription",
				NStr("en='There is no new information on the Online user support server.';ru='Новой информации на сервере Интернет-поддержки пользователей нет.'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Defines if the mechanism is required
// to be launched on starting the application
// according to the custom settings and the implementation of the predefined modules.
// 
// Returns:
// Boolean - True if you launch it on start, False - otherwise.
//
Function ShowMonitorOnApplicationStart() Export
	
	RequiredLaunchOnStart = False;
	OnlineSupportMonitorOverridable.UseMonitorDisplayOnWorkStart(
		RequiredLaunchOnStart);
	
	If RequiredLaunchOnStart <> True Then
		Return False;
	EndIf;
	
	AlwaysShowOnApplicationStart = CommonUse.CommonSettingsStorageImport(
		"OnlineUserSupport",
		"AlwaysShowOnApplicationStart",
		True);
	
	AlwaysShowOnApplicationStart = (AlwaysShowOnApplicationStart = True);
	
	Return AlwaysShowOnApplicationStart
		AND CurrentSessionDate() >= OnlineUserSupportServerCall.SettingValueDoNotRemindAboutAuthorizationBefore();
	
EndFunction

#EndRegion