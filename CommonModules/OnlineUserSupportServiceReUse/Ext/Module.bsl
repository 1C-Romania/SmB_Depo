
////////////////////////////////////////////////////////////////////////////////
// User Internet Support subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns handlers of the library subsystems events.
//
// Returns:
//	Structure - handlers description.
//		* Server - Structure - server handlers;
//			** ClientWorkParametersOnLaunch - Array - the Row type elements -
//				name of the modules that process the filling of the client work parameters at launch;
//			** ClearOUSUserSettings - the Row type elements -
//				name of modules that process users
//				settings removal when an authorized user exits UOS;
//			** BusinessProcesses - Map - server
//				handlers of business processes:
//				*** Key - String - business process entry point;
//				*** Value - String - name of the
//					server mode realising business process handler;
//		* Client - Structure - client handlers;
//			** OnSystemWorkStart - the Row type elements -
//				names of the client
//				modules that implement processor of
//			the On system startup event ** BusinessProcesses - Map - client
//				handlers of business processes:
//				*** Key - String - <Entry point of business-process>\<Event name>;
//				*** Value - String - name of the
//					client mode realising business process handler;
//
// Implement filling of the events handlers description.
// Filled in the
// procedure <SubsystemModule>.AddEventsHandlers(ServerHandlers, ClientHandlers) <SubsystemModule> - module name is returned by function OnlineUserSupport.SubsystemModules()
// Parameters ServerHandlers, ClientHandlers correspond to fields *Server and *Client of the return value.
//
// 1. Server events:
// 1) ClientWorkParametersOnLaunch - description of handlers that fill in the parameters of client work on launch.
// ServerHandlers.ClientWorkParametersOnLaunch.Add(<ModuleName>);
// name of the module is added that implements the export procedure of the service application interface:
//
//// It adds parameters necessary for the client work at starting.
// Added parameters
// available in StandardSubsystemsClientReUse.ClientWorkParametersOnLaunch().UserOnlineSupport.<ParameterName>;
//// Used in case the subsystem implements the
// script executed on start of the system work.
//
// Parameters:
////	Parameters - Structure - Filled parameters;
////
////Procedure ClientWorkParametersOnLaunch(Parameters) Export
//
// Called from UsersOnlineSupport.ClientWorkParametersOnLaunch()
//
// 2) ClearOUSUserSettings - description of handlers
//	that clear custom settings when an authorized user logs off the online support.
//
// ServerHandlers.ClearUserOUSSettings.Add(<ModuleName>);
// name of the module is added that implements the export procedure of the service application interface:
//
//// Called during the logoff of
// an authorized user from the online support after clicking Logoff.
// Clears user settings implemented by the subsystem.
//
////Procedure ClearOUSUserSettings() Export
//
// Called from UsersOnlineSupportServerCall.ClearUserOSSettings()
//
//
// 3) BusinessProcesses - description of business processes handlers in
//	1C:Enterprise server context implemented by the subsystem.
//
// ServerHandlers.BusinessProcesses.Insert("<LaunchLocation>\<EventName>", <ModuleName>);
//		LaunchLocation - entry point processed by the subsystem;
//		EventName - String name of event;
//		ModuleName - name of the module that implements
//			the export procedure of the service interface for the event processor.
//
// Names of events and methods description of the service application interface:
//
// - ContextCreationParameters
// Ca//lled while filling in the parameters of the business process context creation.
//See the OnlineUserSupportServerCall.ContextCreationParameters() procedure.
//
// Parameters:
////	Parameters - Structure - refilled parameters:
////	*LaunchPlace - String - business process entry point;
////	* OnStartSystemWork - Boolean - True if
//		business processor is laun//ched at the system start;
////	* UseOnlineSupport - Boolean - True if
//		you are allow//ed to use OUS for the current IB mode;
////	* StartAllowed - Boolean - True if the current
//		user is allowed to lau//nch IPP;
////	BreakProcessing - Boolean - shows that further processing
//		is returned //in the parameter if you know
//		that further processing is not required.
//
////Procedure ContextCreationParameters(Parameters, BreakProessor) Export
//
//
//
// - DefineLaunchPossibility
// Additi//onally checks if
// it is possible to launch the business process by the entry point and parameters of creating the interaction context.
// Called
//
// from OnlineUserSupportClientServer.GetLaunchByLocationAndParametersPossibility() Parameters:
////	LaunchLocation - String - Business process entry point.//
//	InternetSupportParameters - see function//
//		OnlineUserSupport.ContextCreationParameters();
////	ActionsDetails - Structure - in the structure
//		Description of //the action executed is returned if business process launch is prohibited.
//	see	OnlineUserSupportClientServer.GetLaunchByDirectionAndParametersPossibility().
//
////Procedure
//	DefineLaunchPossibility(
//	LaunchLocation,
//	OnlineSupportParameters, ActionDescription) Export
//
//
//
//
//
//
// - OnCreateInteraction
// Adds required pa//rameters to
// created context of business process execution.
// Called
//
// from OnlineUserSupportServerCall.NewInteractionContext() Parameters:
////	Context - see the
//		On//lineUserSupportServerCall.NewInteractionContext()
//
// function Parameters:
////	Context - see the
//		fu//nction
//OnlineUserSupportServerCall.NewInteractionContext() //Procedure OnCreateInteractionContext(Context) Export
//
//
//
//
// - CommandRunContext
// Defines t//he context of the
// online support service command running: client or 1C:Enterprise server.
// Called
//
// from OnlineUserSupportClientServer.CommandType() Parameters:
////	CommandName - String - name of the executed command;
////	ConnectionOnServer - Boolean - True if connection with
//		UOS service i//s set on 1C:Enterprise server.
//	ExecutionContext - Number - the context of command
//		execution returns in// the parameter: 0 - server of 1C:Enterprise, 1 - client, -1 - unknown command.
//
////P//rocedure CommandRunContext(CommandName, ConnectionOnServer, ExecutionContext) Export
//
//
//
//-
// RunServerCommand Run OUS //service command on the side of 1C:Enterprise server.
// Called
// from UsersOnlineSupportServerCall.RunServiceCommand() Parameters:
////	COPContext - see description
//		of //the UsersOnlineSupportServerCall.NewInteractionContext() function;
////	CommandStructure - see description
//		of //the UsersOnlineSupportClientServer.OutlineServerAnswer() function;
////	HandlerContext - see description
//		of
////
//function OnlineUserSupportClientServer.NewCommandsHandlerContext() //Procedure RunServiceCommand(COPContext, CommandStructure, HandlerContext) Export
//
//
//
//
// - StructureServiceCommand
// Called //while structuring the command
// of the online support service on the side of 1C:Enterprise.
// For more information, see the OnlineSupportMonitorClientServer.OutlineServerAnswer() function.
//
////Procedure StructureServiceCommand(CommandName, ServiceCommand, CommandStructure) Export
//
//
//
//
//
// - FillInternalFormParameters
// Called i//f it is required to
// define form parameters by its index on the 1C:Enterprise server side.
// Called
// from UsersOnlineSupportClientServer.InternalFormParameters()Parameters:
////	FormIndex - String - index of the business process //form.
//	Parameters - Structure - form parameters. Fields are added to the structure:
////		* OpenedFormName - String - full name of the form
//			by its //index, additional parameters of opening a form.
//
////Procedure FillInternalFormParameters(FormIndex, Parameters) Export
//
//
//
// 2. Client handlers
//
// 1) OnStartup - description of handlers that fill in the parameters of client work on launch.
// ClientHandlers.OnStartup.Add(<ModuleName>);
// module name is added that implements an
// export procedure of the service application interface run when the system launches:
//
//// Called when the system
// launches from UsersOnlineSupportClient.OnSystemLaunch().
//
////Procedure OnStartup() Export
//
//
// 2) BusinessProcesses - description of business processes handlers in
//	1C:Enterprise server context implemented by the subsystem.
//
// ClientHandlers.BusinessProcesses.Insert("<LaunchLocation>\<EventName>", <ModuleName>);
//		LaunchLocation - entry point processed by the subsystem;
//		EventName - String name of event;
//		ModuleName - name of the module that implements
//			the export procedure of the service interface for the event processor.
//
// Names of events and methods description of the service application interface:
//
// - DefineLaunchPossibility
// - DefineLaunchPossibility
// Additi//onally checks if
// it is possible to launch the business process by the entry point and parameters of creating the interaction context.
// Called
//
// from OnlineUserSupportClientServer.GetLaunchByLocationAndParametersPossibility() Parameters:
////	LaunchLocation - String - Business process entry point.//
//	InternetSupportParameters - see function//
//		OnlineUserSupport.ContextCreationParameters();
////	ActionsDetails - Structure - in the structure
//		Description of //the action executed is returned if business process launch is prohibited.
//	see	OnlineUserSupportClientServer.GetLaunchByDirectionAndParametersPossibility().
//
////Procedure
//	DefineLaunchPossibility(
//	LaunchLocation,
//	OnlineSupportParameters, ActionDescription) Export
//
//
//
//
// - CommandRunContext
// Defines t//he context of the
// online support service command running: client or 1C:Enterprise server.
// Called
//
// from OnlineUserSupportClientServer.CommandType() Parameters:
////	CommandName - String - name of the executed command;
////	ConnectionOnServer - Boolean - True if connection with
//		UOS service i//s set on 1C:Enterprise server.
//	ExecutionContext - Number - the context of command
//		execution returns in// the parameter: 0 - server of 1C:Enterprise, 1 - client, -1 - unknown command.
//
////P//rocedure CommandRunContext(CommandName, ConnectionOnServer, ExecutionContext) Export
//
//
//
//
//
// - RunServiceCommand
// Run the// command of the OUS service on the side of 1C:Enterprise server.
// Called
//
// from OnlineUserSupportClient.RunServiceCommand() Parameters:
////	InteractionContext - see description
//		of //the UsersOnlineSupportServerCall.NewInteractionContext() function;
////	CommandStructure - see description
//		of //the UsersOnlineSupportClientServer.OutlineServerAnswer() function;
////	HandlerContext - see description
//		of
////	the UsersOnlineSupportClientServer.NewCommandsHandlerContext() BreakCommandsProcessing function - Boolean - returns a flag
//		indicating that //you need to stop running commands if an asynchronous action appears.
//
////Procedure
//	ExecuteServiceCommand(
//	InteractionContext,
//	CurrentForm,
//	CommandStructure,
//	HandlerContext, BreakCommandsProcessor) Export
//
//
//
//
// - GenerateFormOpeningParameters
// Ca//lled while the parameters of
// the business process form opening passed to the GetForm() method are being generated.
// Called
//
// from OnlineUserSupportClient.GenerateGenerateFormOpeningParameters()Parameters:
////	COPContext - see the
//		Us//ersOnlineSupportServerCall.NewInteractionContext()
//	function OpeningFormName - String - full name of opened form;
////	Parameters - Structure - filled in form opening parameters
//
////P//rocedure GenerateFormOpeningParameters(SCContext, OpenedFormName, Parameters) Export
//
//
//
//
// - StructureServiceCommand
// Called //while structuring the command
// of the online support service on the side of 1C:Enterprise.
// For more information, see the OnlineSupportMonitorClientServer.OutlineServerAnswer() function.
//
////Procedure StructureServiceCommand(CommandName, ServiceCommand, CommandStructure) Export
//
//
//
//
// - FillInternalFormParameters
// Called i//f it is required to
// define form parameters by its index on the 1C:Enterprise server side.
// Called
// from UsersOnlineSupportClientServer.InternalFormParameters()Parameters:
////	FormIndex - String - index of the business process //form.
//	Parameters - Structure - form parameters. Fields are added to the structure:
////		* OpenedFormName - String - full name of the form
//			by its //index, additional parameters of opening a form.
//
////Procedure FillInternalFormParameters(FormIndex, Parameters) Export
//
Function EventsHandlers() Export
	
	Result = New Structure;
	
	SubsystemsModuleNames = OnlineUserSupport.SubsystemModules();
	
	// Add events handlers
	
	Server = New Structure;
	Server.Insert("ClientWorkParametersOnStart", New Array);
	Server.Insert("ClientWorkParameters"          , New Array);
	Server.Insert("ClearUserUOSSettings", New Array);
	Server.Insert("BusinessProcesses"                  , New Map);
	
	Client = New Structure;
	Client.Insert("OnStart", New Array);
	Client.Insert("BusinessProcesses"        , New Map);
	
	For Each ModuleName IN SubsystemsModuleNames Do
		
		SubsystemModule = CommonUse.CommonModule(ModuleName);
		If SubsystemModule = Undefined Then
			Continue;
		EndIf;
		
		// Add events handlers using the subsystem
		SubsystemModule.AddEventsHandlers(Server, Client);
		
	EndDo;
	
	Result.Insert("Server", Server);
	Result.Insert("Client", Client);
	
	Return Result;
	
EndFunction

#EndRegion