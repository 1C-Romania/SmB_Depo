////////////////////////////////////////////////////////////////////////////////
// Subsystem "Receiving files from the Internet".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Add handlers of the service events (subsriptions).

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"GetFilesFromInternetService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
		"GetFilesFromInternetService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSwitchUsingSecurityProfiles"].Add(
		"GetFilesFromInternetService");
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of service events.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version    = "1.2.1.4";
	Handler.Procedure = "GetFilesFromInternetService.RefreshStoredProxySettings";
	
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystems(Parameters) Export
	
	Parameters.Insert("ProxyServerSettings", GetFilesFromInternet.GetProxyServerSetting());
	
EndProcedure

// Appears when you enable the use of the infobase for security profiles.
//
Procedure OnSwitchUsingSecurityProfiles() Export
	
	// Reset proxy server settings on the system.
	SaveProxySettingsAt1CEnterpriseServer(Undefined);
	
	WriteLogEvent(GetFilesFromInternetClientServer.EventLogMonitorEvent(),
		EventLogLevel.Warning, Metadata.Constants.ProxyServerSetting,,
		NStr("en='Proxy server settings are reset to system settings when enabling the security profiles.';ru='При включении профилей безопасности настройки прокси-сервера сброшены на системные.'"));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Saves the proxy server settings on the side of 1C:Enterprise server.
//
Procedure SaveProxySettingsAt1CEnterpriseServer(Val Settings) Export
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise(NStr("en='Insufficient rights to perform operation';ru='Недостаточно прав для выполнения операции'"));
	EndIf;
	
	SetPrivilegedMode(True);
	Constants.ProxyServerSetting.Set(New ValueStorage(Settings));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// Initializes new proxy
// server settings "UseProxy" and "UseSystemSettings".
//
Procedure RefreshStoredProxySettings() Export
	
	InfobaseUserArray = InfobaseUsers.GetUsers();
	
	For Each IBUser IN InfobaseUserArray Do
		
		ProxyServerSetting = CommonUse.CommonSettingsStorageImport(
			"ProxyServerSetting", ,	, ,	IBUser.Name);
		
		If TypeOf(ProxyServerSetting) = Type("Map") Then
			
			SaveUserSettings = False;
			If ProxyServerSetting.Get("UseProxy") = Undefined Then
				ProxyServerSetting.Insert("UseProxy", False);
				SaveUserSettings = True;
			EndIf;
			If ProxyServerSetting.Get("UseSystemSettings") = Undefined Then
				ProxyServerSetting.Insert("UseSystemSettings", False);
				SaveUserSettings = True;
			EndIf;
			If SaveUserSettings Then
				CommonUse.CommonSettingsStorageSave(
					"ProxyServerSetting", , ProxyServerSetting, , IBUser.Name);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	ProxyServerSetting = GetFilesFromInternet.ProxySettingsOnServer();
	
	If TypeOf(ProxyServerSetting) = Type("Map") Then
		
		SaveServerSettings = False;
		If ProxyServerSetting.Get("UseProxy") = Undefined Then
			ProxyServerSetting.Insert("UseProxy", False);
			SaveServerSettings = True;
		EndIf;
		If ProxyServerSetting.Get("UseSystemSettings") = Undefined Then
			ProxyServerSetting.Insert("UseSystemSettings", False);
			SaveServerSettings = True;
		EndIf;
		If SaveServerSettings Then
			SaveProxySettingsAt1CEnterpriseServer(ProxyServerSetting);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
