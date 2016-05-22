
////////////////////////////////////////////////////////////////////////////////
// Subsystem "Online User Support".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// It defines if the current user
// can configure parameters of connection to the online support in the current operation mode.
//
// Returns:
// Boolean - True if the parameter settings are available for the current user;
// 	False - otherwise.
//
Function AvailableOnlineSupportConnectionParametersSetting() Export
	
	Return OnlineUserSupport.UseOnlineSupportAllowedInCurrentOperationMode()
		AND Users.InfobaseUserWithFullAccess(, True, False);
	
EndFunction

// It determines whether the current
// user can connect to the online support: 
// user login/registration, registration of the
// software product taking into account the current operation mode and user rights.
//
// Returns:
// Boolean - True - OnlineSupport connection is available,
// 	False - otherwise.
//
Function AvailableOnlineSupportConnection() Export
	
	If Not OnlineUserSupport.UseOnlineSupportAllowedInCurrentOperationMode() Then
		Return False;
	EndIf;
	
	If Users.RolesAvailable("ConnectionToOnlineSupportService", , False) Then
		Return True;
	EndIf;
	
	// Checking roles giving the right to connect OUS
	If CommonUse.SubsystemExists("OnlineUserSupport.OnlineSupportMonitor")
		AND Users.RolesAvailable("UseUOSMonitor", , False) Then
		Return True;
	EndIf;
	
	If CommonUse.SubsystemExists("OnlineUserSupport.1CTaxcomConnection")
		AND Users.RolesAvailable("Use1CTaxcomService", , False) Then
		Return True;
	EndIf;
	
	Return False;
	
	// Use1CTaxcomService and UseOUSMonitor roles 
	// automatically provide access for connection
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// User settings, connection parameters

// Returns DoNotRemindAboutAuthorizationBefore setting.
//
// Returns:
// Date - date before which it should not be reminded of the authorization in OUS service
// when starting the application.
//
Function SettingValueDoNotRemindAboutAuthorizationBefore() Export
	
	DoNotRemindAboutAuthorizationBefore = CommonUse.CommonSettingsStorageImport(
		"OnlineUserSupport",
		"DoNotRemindAboutAuthorizationBefore",
		'00010101');
	
	Return DoNotRemindAboutAuthorizationBefore;
	
EndFunction

// It configures DoNotRemindAboutAuthorizationBefore setting.
//
// Parameters:
// CustomizeSettings - Boolean - set or clear
// 	the date for DoNotRemindAboutAuthorizationBefore.
//
Procedure CustomizeSettingDoNotRemindAboutAuthorizationBefore(CustomizeSettings) Export
	
	SevenDaysInSeconds = 60 * 60 * 24 * 7;
	AfterSevenDays = BegOfDay(CurrentSessionDate() + SevenDaysInSeconds);
	DoNotRemindAboutAuthorizationBefore = ?(CustomizeSettings, AfterSevenDays, '00010101');
	CommonUse.CommonSettingsStorageSave("OnlineUserSupport",
		"DoNotRemindAboutAuthorizationBefore",
		DoNotRemindAboutAuthorizationBefore);
	
EndProcedure

// It defines the network parameters of online support mechanism.
//
// Returns:
// Structure - structure with properties:
// * NetworkTimeout - Number - OUS service connection timeout;
//
Function OnlineSupportNetworkParameters() Export
	
	Result = New Structure;
	
	SetPrivilegedMode(True);
	Result.Insert("NetworkTimeout", Constants.ConnectionTimeoutToOnlineSupportService.Get());
	
	Return Result;
	
EndFunction

// It specifies the side (1C:Enterprise client or
// server) used to interact with the OUS Web service.
//
// Parameters:
// OUSNetworkParameters - Structure - the OUS network
// parameters are returned in the parameter (see the OnlineSupportNetworkParameters() function)
//
// Returns:
// Boolean - True if the connection is carried out on IB server;
//
Function ConnectionToOUSServiceFrom1CEnterpriseServer(OUSNetworkParameters = Undefined) Export
	
	SetPrivilegedMode(True);
	If CommonUse.FileInfobase() Then
		// IN the file version the call shall be from the 1C:Enterprise client
		CallFromServer = False;
	Else
		CallFromServer = Constants.ConnectionToOUSServiceFromServer.Get();
	EndIf;
	
	If Not CallFromServer Then
		OUSNetworkParameters = OnlineSupportNetworkParameters();
	EndIf;
	
	Return CallFromServer;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Service function to determine whether the
// current configuration is registered in the online support service.
// It is intended for execution on
// the 1C:Enterprise server side in the client-server version
// of work (if interaction with OUS Web service is carried out on the side of the server cluster) or in the Web client mode.
//
// Parameters:
// CallFromServer - Boolean - output parameter - True
// 	if the OUS service call is carried out from 1C:Enterprise server;
// OUSParameters - Structure - If it is called
// 	from the client, then the parameters necessary
// 	to work on the client side are returned in the structure (see OnlineSupportNetworkParameters() function);
// WebServiceCallError - Boolean - output parameter - True
// 	if in the process of OUS service calling
// 	an error occurred and it is not possible to check the configuration "authorization";
//
// Returns:
// Boolean - True if the configuration is registered in the OUS service, 
//   False - if not registered or if an error occurred while
// 	accessing OUS service;
//
Function ConfigurationIsRegisteredInOUSService(
	CallFromServer,
	OUSParameters,
	WebServiceCallError = False) Export
	
	If CommonUseClientServer.ThisIsWebClient() Then
		CallFromServer = True;
	Else
		CallFromServer = ConnectionToOUSServiceFrom1CEnterpriseServer(OUSParameters);
	EndIf;
	
	If CallFromServer Then
		Return OnlineUserSupportClientServer.ConfigurationIsRegisteredInOUSService(
			WebServiceCallError);
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// It creates a context of OUS service interaction within
// which all OUS service commands are executed.
//
// Parameters:
// LaunchLocation - String - command name used
// 	to start OUS mechanism;
// OUSParameters - Structure - see function ContextCreationParameters().
// SecondStart - Boolean - True if the start is repeated.
// LaunchParameters - Structure, Undefined - parameters transferred
// 	at the mechanism start.
// OnStart - Boolean - Sign of the
// 	business process beginning when the system starts working.
//
// Returns:
// Structure - structure with fields:
// * OUSServiceDescription - Structure - see function
// 	OnlineUserSupportClientServer.NewServiceDescriptionOUS()
// * OUSNetworkParameters - Structure - OUS network parameters,
// 		it is available only if connecting from client application;
// 	** NetworkTimeout - Number - OUS service connection timeout;
// * COPContext - Structure - client-server interaction context;
// 	** Basic parameters - Structure - see function NewBasicContextParameters();
// 	** RegistrationContext - Structure, Undefined - software
// 		product registration context;
// 	** Login - String - Login that OUS user used to log in;
// 	** Password - String - password  that the OUS user used to log in;
// 	** SessionParameters - Map - session data stored
// 		in the interaction session with OUS service;
// 	** OUSNetworkParameters - Structure - OUS network parameters,
// 			it is available only if connecting from client application;
// 		*** NetworkTimeout - Number - OUS service connection timeout;
// 	** OnSystemWorkStart - Boolean - start is performed at the beginning of the system work;
// * MechanismStartParameters - Structure - parameters
// 	used to start the mechanism. Copy of StartParameters parameter .
//
Function NewInteractionContext(
	Val LaunchLocation,
	Val SecondStart,
	Val LaunchParameters,
	Val OnStart = False) Export
	
	Result = New Structure;
	
	OUSParameters = ContextCreationParameters(LaunchLocation, OnStart);
	
	StartStructure = OnlineUserSupportClientServer.DefineStartPossibilityByLocationAndParameters(
		LaunchLocation,
		OUSParameters);
	
	If StartStructure <> Undefined Then
		// If start is prohibited, then return
		Result.Insert("StartManagementStructure", StartStructure);
		Return Result;
	EndIf;
	
	// Creating context used on client and on server
	COPContext = New Structure;
	COPContext.Insert("RegistrationContext"   , Undefined);
	COPContext.Insert("Login"                 , "");
	COPContext.Insert("SessionalParameters"   , New Map);
	COPContext.Insert("OnStart", OnStart);
	
	MainParameters = NewBasicContextParameters();
	MainParameters.LaunchLocation          = LaunchLocation;
	MainParameters.WSDefinitionName      = OnlineUserSupportClientServer.WSDefinitionName();
	MainParameters.OfURIService            = OnlineUserSupportClientServer.URIServiceName();
	MainParameters.SecondStart       = SecondStart;
	MainParameters.CallFromServer     = OUSParameters.CallFromServer;
	
	OUSNetworkParameters = New Structure;
	OUSNetworkParameters.Insert("NetworkTimeout", OUSParameters.NetworkTimeout);
	
	If MainParameters.CallFromServer Then
		
		MainParameters.Insert("OUSNetworkParameters", OUSNetworkParameters);
		
		// Creating WSDL descriptions cache. It is necessary for
		// the address from the server as for each call from the server new service
		// connection is created.
		// Cache is cleared while completing the business process.
		MainParameters.Insert("WSDLDescriptionsCache", New Map);
		
	Else
		Result.Insert("OUSServiceDescription" , Undefined);
		Result.Insert("OUSNetworkParameters", OUSNetworkParameters);
	EndIf;
	
	WriteContextStartParameters(LaunchParameters, COPContext);
	WriteContextStartParameters(OUSParameters.CommonStartParameters, COPContext);
	
	COPContext.Insert("MainParameters", MainParameters);
	
	Result.Insert("COPContext"    , COPContext);
	Result.Insert("DataProcessorForms", New Map);
	
	// Saving in the context of the mechanism start parameters interaction.
	// It is necessary to repeat connection from the OUS service call error form
	Result.Insert("MechanismStartParameters", LaunchParameters);
	
	// Add. handler of a business process 
	ServerHandler = OnlineUserSupport.BusinessProcessServerHandler(
		LaunchLocation,
		"OnCreateInteractionContext");
	
	If ServerHandler <> Undefined Then
		ServerHandler.OnCreateInteractionContext(Result);
	EndIf;
	
	Return Result;
	
EndFunction

// It returns all parameters necessary
// to work with the online support service per server call.
// To minimize information transmitted between the client
// and server only necessary parameters are returned depending on
// the call location (client or server).
//
// Parameters:
// LaunchLocation - String - OUS mechanism start button;
// OnStart - Boolean - Sign of the
// 	business process beginning when the system starts working.
//
// Returns:
// Structure - structure with fields:
// *LaunchPlace - String - business process entry point;
// * OnStartSystemWork - Boolean - True if
// 	business process is launched at the system start;
// * UseOnlineSupport - Boolean - True if
// 	you are allowed to use OUS for the current IB mode;
// * StartAllowed - Boolean - True if the current
// 	user is allowed to launch IPP;
// * UseInfoWindow - Boolean - True if
// 	the information window is provided by the configuration;
// * NetworkTimeout - Number - OUS service connection timeout in seconds;
// * CallFromServer - Boolean - True if the OUS
// 	service connection is carried out on the infobase server;
// * DoNotRemindAboutAuthorizationBefore - Date - date until
// 	and including which it is necesary to suppress
// 	the OUS authorization reminder when starting the application
// * CommonStartParameters - Structure - mechanism
// 	start parameters read from the OnlineUserSupportParameters information register.
//
Function ContextCreationParameters(LaunchLocation, OnStart)
	
	Result = New Structure;
	
	Result.Insert("LaunchLocation"          , LaunchLocation);
	Result.Insert("OnStart", OnStart);
	
	// Check OnlineSupport mechanism usage
	UseOnlineSupport = OnlineUserSupport.UseOnlineSupportAllowedInCurrentOperationMode();
	Result.Insert("UseOnlineSupport", UseOnlineSupport);
	
	If OnlineUserSupportClientServer.ThisIsBaseBusinessProcess(LaunchLocation) Then
		
		// Only the business process with
		// "connectIPP" entry point is available in the basic functionality
		Result.Insert("LaunchAllowed", AvailableOnlineSupportConnection());
		
	Else
		
		Result.Insert("LaunchAllowed", True);
		// Call business process handler
		ServerHandler = OnlineUserSupport.BusinessProcessServerHandler(
			LaunchLocation,
			"ContextCreationParameters");
		
		If ServerHandler <> Undefined Then
			BreakProcessing = False;
			ServerHandler.ContextCreationParameters(Result, BreakProcessing);
			If BreakProcessing Then
				Return Result;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Not Result.LaunchAllowed Then
		Return Result;
	EndIf;
	
	ThisIsFileInfobase = CommonUse.FileInfobase();
	
	SetPrivilegedMode(True);
	
	CallFromServer = Undefined;
	
	If CommonUseClientServer.ThisIsWebClient() Then
		// In the Web client the OUS service
		// shall be called only from the 1C:Enterprise server
		CallFromServer = True;
	Else
		If ThisIsFileInfobase Then
			// In the file version it is necessary
			// to call the sevice from the client application
			CallFromServer = False;
		EndIf;
	EndIf;
	
	// Selection of required parameters from IB
	ParametersQuery = New Query(
	"SELECT
	|	CASE
	|		WHEN ConnectionTimeoutToOnlineSupportService.Value = 0 THEN 30
	|		ELSE ConnectionTimeoutToOnlineSupportService.Value
	|	END AS ConnectionTimeoutToOnlineSupportService"
	+ ?(CallFromServer <> Undefined,
		"",
		", ConnectionToOUSServiceFromServer.Value AS ConnectionToOUSServiceFromServer")
	+ " FROM
	|	Constant.ConnectionTimeoutToOnlineSupportService AS ConnectionTimeoutToOnlineSupportService"
	+ ?(CallFromServer <> Undefined,
		"",
		", Constant.ConnectionToOUSServiceFromServer AS ConnectionToOUSServiceFromServer")
	+ ";
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UsersOnlineSupportParameters.Name,
	|	UsersOnlineSupportParameters.Value
	|FROM
	|	InformationRegister.UsersOnlineSupportParameters AS UsersOnlineSupportParameters");
	
	Package = ParametersQuery.ExecuteBatch();
	ConstantsSelection = Package[0].Select();
	ConstantsSelection.Next();
	Result.Insert("NetworkTimeout", ConstantsSelection.ConnectionTimeoutToOnlineSupportService);
	If CallFromServer = Undefined Then
		CallFromServer = ConstantsSelection.ConnectionToOUSServiceFromServer;
	EndIf;
	
	Result.Insert("CallFromServer", CallFromServer);
	
	// Filling common start parameters
	StartParametersSelection = Package[1].Select();
	CommonStartParameters = New Structure;
	While StartParametersSelection.Next() Do
		If Not CommonStartParameters.Property(StartParametersSelection.Name) Then
			CommonStartParameters.Insert(StartParametersSelection.Name, StartParametersSelection.Value);
		EndIf;
	EndDo;
	
	Result.Insert("CommonStartParameters", CommonStartParameters);
	
	Return Result;
	
EndFunction

// It defines the content of the main
// parameters of OUS service context.
//
// Returns:
// Structure - structure with fields:
// * WSDefinitionName - String - OUS service WSDL description address;
// * OfURIService - String - service names space URI;
// * LaunchLocation - String - OUS service call button name;
// * Restart - Boolean - True if OUS
// 	mechanism is restarted;
// * CallFromServer - Boolean - True if the OUS service
// 	connection is held on the IB server;
//
Function NewBasicContextParameters()
	
	Result = New Structure();
	Result.Insert("WSDefinitionName" , "");
	Result.Insert("OfURIService"       , "");
	Result.Insert("LaunchLocation"     , "");
	Result.Insert("SecondStart"  , False);
	Result.Insert("CallFromServer", True);
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for service commands dataprocessors

// Recieving OUS service commands and the service command
// execution or return of the management to the client.
//
// Parameters:
// COPContext - Structure - client-server context
// 	of interaction with OUS service (see NewInteractionContext function);
// QueryParameters - Array - query parameters array
// 	transferred to OUS service;
// HandlerContext - Structure - see
// 	OnlineUserSupportClientServer.NewCommandHandlerContext() function
// Continued - Boolean - True if commands are
// 	executing without OUS service call;
// OUSServiceCallParameters - Structure - additional
// 	parameters of OUS service call;
// SessionQueryParametersArray - Array - array of
// 	session parameters names sent to OUS service;
// CreatedInteractionContext - Structure - the OUS
// 	service interaction context is returned in the parameter if it is not set. It
// 	is used to exclude additional server call at
// 	first OUS service call;
// ContextCreationParameters - Structure - additional
// 	parameters to create OUS service interaction context.
//
Procedure ServiceCommandsDataProcessor(
	COPContext,
	Val QueryParameters,
	HandlerContext,
	Val Continued,
	Val OUSServiceCallParameters = Undefined,
	Val SessionQueryParametersArray = Undefined,
	CreatedInteractionContext = Undefined,
	Val ContextCreationParameters = Undefined) Export
	
	If COPContext = Undefined Then
		
		// Creating context of interaction with the OUS service at first starting
		CreatedInteractionContext = NewInteractionContext(
			ContextCreationParameters.LaunchLocation,
			ContextCreationParameters.SecondStart,
			ContextCreationParameters.LaunchParameters);
		
		If CreatedInteractionContext.Property("StartManagementStructure")
			OR Not CreatedInteractionContext.COPContext.MainParameters.CallFromServer Then
			Return;
		EndIf;
		
		COPContext = CreatedInteractionContext.COPContext;
		
	EndIf;
	
	MainParameters = COPContext.MainParameters;
	
	HandleResponse = True;
	
	If TypeOf(OUSServiceCallParameters) = Type("Structure") Then
		OUSServiceCallParameters.Property("HandleResponse", HandleResponse);
	EndIf;
	
	// when continuing the web service call is not performed
	If Not Continued Then
		
		// There is always at least one query parameter
		If TypeOf(QueryParameters) <> Type("Array") Then
			QueryParameters = New Array;
		EndIf;
		
		OnlineUserSupportClientServer.AddSessionParametersToQuery(
			COPContext,
			SessionQueryParametersArray,
			QueryParameters);
		
		AddServiceCommands(MainParameters, QueryParameters, HandlerContext);
		
		If HandleResponse <> True Then
			Return;
		EndIf;
		
	EndIf;
	
	// If there are no errors preventing
	// continuation of the command execution, perform server commands
	Try
		
		// Until there are commands to be performed
		While HandlerContext.Commands.Count() > 0
			AND Not HandlerContext.ErrorOccurred
			AND Not HandlerContext.MakeStop Do
			
			CurrentCommand = HandlerContext.Commands[0];
			CommandType = OnlineUserSupportClientServer.CommandType(
				CurrentCommand,
				MainParameters.CallFromServer,
				MainParameters.LaunchLocation);
			
			// Definition of context performance - on server or on client
			If CommandType = -1 Then
				
				// If the command type can not be determined, extract it from the
				// stack and continue execution
				HandlerContext.Commands.Delete(0);
				Continue;
				
			ElsIf CommandType = 0 Then
				
				// Command extraction from the stack and its execution on the infobase server
				HandlerContext.Commands.Delete(0);
				RunServiceCommand(COPContext, CurrentCommand, HandlerContext);
				
			Else
				
				// Return of management to the client application
				Return;
				
			EndIf;
			
		EndDo;
		
	Except
		
		HandlerContext.ErrorOccurred = True;
		HandlerContext.ActionsOnErrorForServer.Add("CreateLogRegistrationRecord");
		HandlerContext.ActionsOnErrorForServer.Add("BreakBusinessProcess");
		HandlerContext.FullErrorDescription = NStr("en = 'An unhandled exception occurred.'")
			+ " " + DetailErrorDescription(ErrorInfo());
		
		HandlerContext.UserErrorDescription =
			NStr("en = 'Unknown error. For more details see the event log.'");
		HandlerContext.ActionOnErrorForClient = "ShowMessage";
		
	EndTry;
	
	// If an error occurred, then complete Online Support session with error processing.
	If HandlerContext.ErrorOccurred Then
		EndOnlineSupportSession(COPContext, HandlerContext);
	EndIf;
	
EndProcedure

// OUS service call and adding commands to the command
// stack of the command handler context
//
Procedure AddServiceCommands(
	MainParameters,
	AdditionalParameters,
	HandlerContext = Undefined) Export
	
	WSDLDescriptionsCache = Undefined;
	MainParameters.Property("WSDLDescriptionsCache", WSDLDescriptionsCache);
	
	Try
		
		OUSServiceDescriptionAtServer = OnlineUserSupportClientServer.NewOUSServiceDescription(
			MainParameters.WSDefinitionName,
			MainParameters.OUSNetworkParameters,
			WSDLDescriptionsCache);
		
	Except
		
		If TypeOf(HandlerContext) = Type("Structure") Then
			HandlerContext.ErrorOccurred      = True;
			HandlerContext.FullErrorDescription = DetailErrorDescription(ErrorInfo());
			HandlerContext.ActionsOnErrorForServer.Add("CreateLogRegistrationRecord");
			HandlerContext.ActionOnErrorForClient = "DisplayFormConnectionNotAvailable";
			HandlerContext.UserErrorDescription =
				NStr("en = 'Error at connecting online support service.'");
		EndIf;
		
		Return;
		
	EndTry;
	
	Try
		
		OnlineUserSupportClientServer.AddServiceCommands(
			OUSServiceDescriptionAtServer,
			AdditionalParameters,
			HandlerContext,
			MainParameters);
		
		// After the first call, disable the network timeout, because
		// the checking of call by timeout is already completed
		If MainParameters.OUSNetworkParameters.NetworkTimeout <> 0 Then
			MainParameters.OUSNetworkParameters.NetworkTimeout = 0;
			OnlineUserSupportClientServer.ChangeCallTimeout(OUSServiceDescriptionAtServer, 0);
		EndIf;
		
	Except
		
		If TypeOf(HandlerContext) = Type("Structure") Then
			HandlerContext.ErrorOccurred      = True;
			HandlerContext.FullErrorDescription = DetailErrorDescription(ErrorInfo());
			HandlerContext.ActionsOnErrorForServer.Add("CreateLogRegistrationRecord");
			HandlerContext.ActionOnErrorForClient = "DisplayFormConnectionNotAvailable";
			HandlerContext.UserErrorDescription =
				NStr("en = 'An error occurred while retrieving data from the online support server.'");
		EndIf;
		
	EndTry;
	
EndProcedure

// OUS service command manager at 1C:Enterprise server side
//
Procedure RunServiceCommand(COPContext, CommandStructure, HandlerContext)
	
	CommandName = Undefined;
	CommandStructure.Property("CommandName", CommandName);
	
	If CommandName = Undefined Then
		Return;
	EndIf;
	
	If CommandName = "store.get" Then
		OnlineUserSupportClientServer.ReadParametersCommandExecution(
			New Structure("COPContext", COPContext),
			CommandStructure,
			HandlerContext,
			True);
		
	ElsIf CommandName = "store.put" Then
		OnlineUserSupportClientServer.ParametersRecordCommandExecution(
			COPContext,
			CommandStructure,
			HandlerContext);
		
	ElsIf CommandName = "store.delete" Then
		OnlineUserSupportClientServer.DeleteContextParameters(
			COPContext,
			CommandStructure,
			HandlerContext);
		
	ElsIf CommandName = "launchservice" Then
		ChangeBusinessProcess(COPContext, CommandStructure, HandlerContext);
		
	ElsIf CommandName = "store.putorganizations" Then
		OnlineUserSupportClientServer.WriteCompaniesList(COPContext, CommandStructure);
		
	ElsIf CommandName = "store.putadressclassifier" Then
		OnlineUserSupportClientServer.WriteAddressClassifier(COPContext, CommandStructure);
		
	Else
		
		// Command handling using add. business process handler
		ServerHandler = OnlineUserSupport.BusinessProcessServerHandler(
			COPContext.MainParameters.LaunchLocation,
			"RunServiceCommand");
		
		If ServerHandler <> Undefined Then
			ServerHandler.RunServiceCommand(COPContext, CommandStructure, HandlerContext);
		EndIf;
		
	EndIf;
	
EndProcedure

// Executes the command of changing current OUS service address.
//
Procedure ChangeBusinessProcess(COPContext, CommandStructure, HandlerContext)
	
	MainParameters = COPContext.MainParameters;
	
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
	ParameterValue = OnlineUserSupportClientServer.SessionParameterValue(
		COPContext,
		"session_id");
	
	ValuesStructure = New Structure("Name, BusinessProcess, Value, Scope", 
		"session_id",
		MainParameters.WSDefinitionName,
		ParameterValue,
		"sessionParameter");
	
	QueryParameters.Add(ValuesStructure);
	
	MainParameters = COPContext.MainParameters;
	
	// Business process change on a web server.
	// New service connection will be created
	AddServiceCommands(MainParameters, QueryParameters, HandlerContext);
	
EndProcedure

// Terminate Online Support session on the 1C:Enterprise server side.
//
Procedure EndOnlineSupportSession(COPContext, HandlerContext) Export
	
	MainParameters = COPContext.MainParameters;
	
	CommandsCount = HandlerContext.ActionsOnErrorForServer.Count();
	
	NumberCommands = 0;
	While NumberCommands < HandlerContext.ActionsOnErrorForServer.Count() Do
		
		ActionCompleted = False;
		Action = HandlerContext.ActionsOnErrorForServer[NumberCommands];
		If Action = "CreateLogRegistrationRecord" Then
			
			If Not IsBlankString(HandlerContext.FullErrorDescription) Then
				OnlineUserSupportServerCall.WriteErrorInEventLogMonitor(
					HandlerContext.FullErrorDescription);
			EndIf;
			
			ActionCompleted = True;
			
		ElsIf Action = "BreakBusinessProcess" Then
			
			If MainParameters.CallFromServer Then
				EndBusinessProcess(COPContext);
				ActionCompleted = True;
			EndIf;
			
		EndIf;
		
		If ActionCompleted Then
			HandlerContext.ActionsOnErrorForServer.Delete(NumberCommands);
		Else
			NumberCommands = NumberCommands + 1;
		EndIf;
		
	EndDo;
	
	// If actions were not executed on the server, they will be
	// returned to the client for the further execution.
	
EndProcedure

// Sending notifications of OUS session completion to OUS service.
//
Procedure EndBusinessProcess(COPContext)
	
	Try
		
		MainParameters = COPContext.MainParameters;
		
		BPCloseParameters = New Array;
		BPCloseParameters.Add(New Structure("Name, Value", "CloseBP", "true"));
		
		OnlineUserSupportClientServer.AddSessionParametersToQuery(
			COPContext,
			,
			BPCloseParameters);
		
		AddServiceCommands(
			MainParameters,
			BPCloseParameters,
			Undefined);
		
	Except
		// Service response processing is not required as the server
		// is simply notified of the business process closing to release resources
	EndTry;
	
	WSDLDescriptionsCache = Undefined;
	MainParameters.Property("WSDLDescriptionsCache", WSDLDescriptionsCache);
	ClearWSDLDescriptionsCache(WSDLDescriptionsCache);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with OUS parameters

// Saving start parameters in the session settings when starting OUS
//
Procedure WriteContextStartParameters(Val StartupParametersStructure, COPContext)
	
	If StartupParametersStructure <> Undefined Then
		
		StringType = Type("String");
		For Each ParameterInStructure IN StartupParametersStructure Do
			
			Parameter = OnlineUserSupportClientServer.NewParameterOUS(
				ParameterInStructure.Key,
				ParameterInStructure.Value,
				"startUp");
			
			COPContext.SessionalParameters.Insert(ParameterInStructure.Key, Parameter);
			
		EndDo;
		
	EndIf;
	
EndProcedure

// It records common start parameters to
// the OnlineUserSupportParameters information register
//
Procedure WriteCommonStartParametersVRSOUS(Val CommonStartParameters) Export
	
	For Each KeyValue IN CommonStartParameters Do
		RecordManager = InformationRegisters.UsersOnlineSupportParameters.CreateRecordManager();
		RecordManager.Name          = KeyValue.Key;
		RecordManager.Value     = KeyValue.Value;
		RecordManager.Write(True);
	EndDo;
	
EndProcedure

// Deletion of the parameters
// from the ParametersUserOnlineSupport data register
//
// Parameters:
// DeletedFromRS - Array - String array - names of deleted parameters
//
Procedure DeleteParametersFromRegister(Val DeletedFromRS) Export
	
	For Each KeyValue IN DeletedFromRS Do
		RecordSet = InformationRegisters.UsersOnlineSupportParameters.CreateRecordSet();
		RecordSet.Filter.Name.Set(KeyValue.Key);
		RecordSet.Write();
	EndDo;
	
EndProcedure

// Clearing OUS settings of the current user.
//
Procedure ClearUserUOSSettings() Export
	
	// Call additional subsystem handlers
	ServerHandlers = OnlineUserSupportServiceReUse.EventsHandlers().Server;
	ModuleNames = ServerHandlers.ClearUserUOSSettings;
	
	For Each ModuleName IN ModuleNames Do
		HandlerModule = CommonUse.CommonModule(ModuleName);
		If HandlerModule = Undefined Then
			Continue;
		EndIf;
		HandlerModule.ClearUserUOSSettings();
	EndDo;
	
	// Common user output data prosessor
	Try
		OnlineUserSupportOverridable.WhenUserExitsOnlineSupport();
	Except
		ErrorInfo = NStr("en = 'Error occurred at handling user logout from Online Support. %1'");
		ErrorInfo = StrReplace(ErrorInfo,
			"%1",
			DetailErrorDescription(ErrorInfo()));
		OnlineUserSupportServerCall.WriteErrorInEventLogMonitor();
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional service procedures and functions

// Sending email to the Web IDS technical support.
//
Function SendEmailThroughService(Val MessageStructure, OUSNetworkParameters) Export
	
	Return OnlineUserSupportClientServer.SendEmailThroughService(
		MessageStructure,
		OUSNetworkParameters);
	
EndFunction

// Clear WSDL description cache at the 1C:Enterprise server side. Deleting
// of the saved WSDL descriptions from the temporary storage.
//
Procedure ClearWSDLDescriptionsCache(WSDLDescriptionsCache) Export
	
	If WSDLDescriptionsCache <> Undefined Then
		// Deletion from the temporary storage of WSDL descriptions texts
		For Each KeyValue IN WSDLDescriptionsCache Do
			DeleteFromTempStorage(KeyValue.Value);
		EndDo;
	EndIf;
	
	WSDLDescriptionsCache.Clear();
	
EndProcedure

// It returns log event name to
// record Online User Support errors.
//
// Returns:
// String - Online support error event name.
//
Function LogEventOnlineUserSupportError()
	
	Return NStr("en = 'Online user support. Error'",
		CommonUseClientServer.MainLanguageCode());
	
EndFunction

// It returns the log event name
// to record Online user support information messages.
//
// Returns:
// String - Event name of online support info message.
//
Function LogEventOnlineUserSupportInformation()
	
	Return NStr("en = 'Online user support.Info'",
		CommonUseClientServer.MainLanguageCode());
	
EndFunction

// It records error description
// with the event name "Online user support.Error".
//
// Parameters:
//  Error - String - Error string presentation.
//  Data - Arbitrary - data that the error message is refered to.
//
Procedure WriteErrorInEventLogMonitor(Error, Data = Undefined) Export
	
	WriteLogEvent(LogEventOnlineUserSupportError(),
		EventLogLevel.Error,
		,
		Data,
		Error);
	
EndProcedure

// It records information
// with the event name "Online user support.Information".
//
// Parameters:
//  Message - String - recorded info.
//
Procedure WriteInformationToEventLogMonitor(Message) Export
	
	WriteLogEvent(LogEventOnlineUserSupportInformation(),
		EventLogLevel.Information,
		,
		,
		Message);
	
EndProcedure

#EndRegion
