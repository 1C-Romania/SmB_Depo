
////////////////////////////////////////////////////////////////////////////////
// Subsystem "Online User Support"
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// It returns online support user login and password saved in the infobase.
//
// Returns:
// Structure - a structure containing online
// 	support user login and password:
// 	* Login    - String - Internet Support user login;
// 	* Password - String - Online support user
// 		 password is absent if the user did not select "Remember me" check box.
// Undefined - in the absence of saved authorization data.
//
Function OnlineSupportUserAuthenticationData() Export
	
	ParametersQuery = New Query(
	"SELECT
	|	UsersOnlineSupportParameters.Name AS ParameterName,
	|	UsersOnlineSupportParameters.Value AS ParameterValue
	|FROM
	|	InformationRegister.UsersOnlineSupportParameters AS UsersOnlineSupportParameters
	|WHERE
	|	UsersOnlineSupportParameters.Name IN (""login"", ""password"")
	|	AND UsersOnlineSupportParameters.User = &EmptyID");
	
	ParametersQuery.SetParameter("EmptyID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	
	UserLogin  = Undefined;
	UserPassword = Undefined;
	
	SetPrivilegedMode(True);
	ParameterSelection = ParametersQuery.Execute().Select();
	While ParameterSelection.Next() Do
		
		// Character case is not taken into account in the query
		ParameterNameLowerCase = Lower(ParameterSelection.ParameterName);
		If ParameterNameLowerCase = "login" Then
			UserLogin = ParameterSelection.ParameterValue;
			
		ElsIf ParameterNameLowerCase = "password" Then
			UserPassword = ParameterSelection.ParameterValue;
			
		EndIf;
		
	EndDo;
	
	If UserLogin <> Undefined AND UserPassword <> Undefined Then
		Return New Structure("Login, Password", UserLogin, UserPassword);
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// It determines whether online support usage
// is allowed in the current infobase operation mode.
// It defines based on the values: 1) It is local operation mode;
// 2) implementation of the
// OnlineUserSupportOverridable.UseOnlineSupport() procedure
//
// Returns:
// Boolean - True - authorized for use, False - otherwise.
//
Function UseOnlineSupportAllowedInCurrentOperationMode() Export
	
	// Prohibition of operation in the service model
	Cancel = CommonUseReUse.DataSeparationEnabled();
	If Not Cancel Then
		
		// If you work in local mode, then perform additional check of the permission
		OnlineUserSupportOverridable.UseOnlineSupport(Cancel);
		If TypeOf(Cancel) <> Type("Boolean") Then
			Cancel = False;
		EndIf;
		
	EndIf;
	
	Return (Cancel = False);
	
EndFunction

// It adds parameters necessary for the client work at starting.
//
// Parameters:
// Parameters - Structure - Filled parameters;
//
Procedure ClientWorkParametersOnStart(Parameters) Export
	
	OUSParameters = New Structure;
	
	HandlerDescription = OnlineUserSupportServiceReUse.EventsHandlers();
	
	For Each ModuleName IN HandlerDescription.Server.ClientWorkParametersOnStart Do
		HandlerModule = CommonUse.CommonModule(ModuleName);
		If HandlerModule <> Undefined Then
			HandlerModule.ClientWorkParametersOnStart(OUSParameters);
		EndIf;
	EndDo;
	
	OUSParameters.Insert("OnStart", HandlerDescription.Client.OnStart);
	
	Parameters.Insert("OnlineUserSupport", OUSParameters);
	
EndProcedure

// It adds parameters necessary for the client work.
//
// Parameters:
// Parameters - Structure - Filled parameters;
//
Procedure ClientWorkParameters(Parameters) Export
	
	OUSParameters = New Structure;
	
	// Configuration name and version for the client use
	OUSParameters.Insert("ConfigurationName"          , Metadata.Name);
	OUSParameters.Insert("ConfigurationVersion"       , Metadata.Version);
	OUSParameters.Insert("LocaleCode"           , CurrentLocaleCode());
	OUSParameters.Insert("UpdateProcessorVersion", UpdateProcessorVersion());
	
	// Business processes handlers
	OUSParameters.Insert("BusinessProcessesClientHandlers",
		OnlineUserSupportServiceReUse.EventsHandlers().Client.BusinessProcesses);
	
	Parameters.Insert("OnlineUserSupport", OUSParameters);
	
EndProcedure

// see the same procedure
// description in WorkInSafeModeOverridable of StandardSubsystems.BasicFunctionality
// 
// Parameters:
// PermissionsQueries - Filled permissions;
// 
// The example of usage
// in the overridable procedure WorkInSaveModeOverridable.AtFillingPermissionsToExternalResourcesAccess():
// 
// // OnlineUserSupport
// OnlineUserSupport.AtFillingPermissionsToExternalResourcesAccess(Permissions)
// End
// OnlineUserSupport
//
Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	If UseOnlineSupportAllowedInCurrentOperationMode() Then
		
		ResourceDetails = OnlineUserSupportClientServer.OnlineSupportResourceDescription();
		Resolution = WorkInSafeMode.PermissionForWebsiteUse(
			ResourceDetails.Protocol,
			ResourceDetails.Address,
			ResourceDetails.Port,
			ResourceDetails.Description);
		
		PermissionsQueries.Add(Resolution);
		
	EndIf;
	
EndProcedure

// see description of the same procedure in CommonUseOverridable
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	// ISL basic functionality 
	// 2.1.2.1
	CommonUse.AddRenaming(
		Total,
		"2.1.2.1",
		"Role.UsingOUS",
		"Role.ConnectionToOnlineSupportService",
		"OnlineUserSupport");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// It returns DataProcessors version for the configuration update.
Function UpdateProcessorVersion() Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		
		SubsystemStandardSubsystems = New Structure("Name, Version");
		InfobaseUpdateSSL.OnAddSubsystem(SubsystemStandardSubsystems);
		
		Return SubsystemStandardSubsystems.Version;
		
	Else
		
		Return "";
		
	EndIf;
	
EndFunction

// It returns the names of the subsystem modules implementing library event processing.
//
// Returns:
// Array - Item array of the String type - names of
// 	the subsystem modules implementing the description filling for the event handlers.
//
// Subsystem modules description:
//
// Each module which name is returned
// by the function should use export
// procedure of service software interface implementing description filling of the event handlers.
//
// Procedure AddEventHandlers(ServerHandlers, ClientHandlers) Export
//
// EndProcedure
//
// For detailed information of procedure implementation
// see OnlineUserSupportServiceReUse.EventsHandlers function description().
//
Function SubsystemModules() Export
	
	Result = New Array;
	
	If CommonUse.SubsystemExists("OnlineUserSupport.OnlineSupportMonitor") Then
		Result.Add("OnlineSupportMonitor");
	EndIf;
	
	Return Result;
	
EndFunction

// It returns server business process handler.
// Parameters:
// LaunchLocation - String - Entry point to the business process;
// EventName - String - name of the event under processing.
//
// Returns:
// CommonModule - module containing the specified business process handler;
// Undefined - if a business process handler is not defined.
//
Function BusinessProcessServerHandler(LaunchLocation, EventName) Export
	
	If OnlineUserSupportClientServer.ThisIsBaseBusinessProcess(LaunchLocation) Then
		Return Undefined;
	EndIf;
	
	EventsHandlers = OnlineUserSupportServiceReUse.EventsHandlers();
	BusinessProcessesHandlersModules = EventsHandlers.Server.BusinessProcesses;
	ModuleName = BusinessProcessesHandlersModules[LaunchLocation + "\" + EventName];
	
	If ModuleName = Undefined Then
		Return Undefined;
	EndIf;
	
	Return CommonUse.CommonModule(ModuleName);
	
EndFunction

#EndRegion
