////////////////////////////////////////////////////////////////////////////////
// The Deleted administration subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceApplicationInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS.
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnDefenitionSupportedVersionsOfSoftwareInterfaces"].Add(
			"RemoteAdministrationSTLService");
	
	// CLIENT HANDLERS.
	
	ClientHandlers["StandardSubsystems.UserSessions\OnSessionEnd"].Add(
		"RemoteAdministrationSTLClient");
	
EndProcedure

// Fills the structure with the arrays of supported
// versions of all subsystems subject to versioning and uses subsystems names as keys.
// Provides the functionality of InterfaceVersion Web-service.
// during the implementation the body of the procedure shall be changed so it will return relevant version sets (see ex.below).
//
// Parameters:
// SupportedVersionStructure - Structure: 
// - Keys = Names of the subsystems. 
// - Values = Arrays of supported version names.
//
// Example of implementation:
//
// // FileTransferServer
// VersionsArray = New Array;
// VersionsArray.Add("1.0.1.1");	
// VersionsArray.Add("1.0.2.1"); 
// SupportedVersionsStructure.Insert("FileTransferServer", VersionsArray);
// // End FileTransferService
//
Procedure OnDefenitionSupportedVersionsOfSoftwareInterfaces(Val SupportedVersionStructure) Export
	
	VersionArray = New Array;
	VersionArray.Add("1.0.0.1");
	SupportedVersionStructure.Insert("ManagedApplication", VersionArray);
	
EndProcedure

// Returns web-service proxy for synchronization of administrative actions in service.
// 
// Returns: 
// WSProxy.
// Proxy of service manager.
// 
Function ManagingApplicationServiceProxy(Val UserPassword = "") Export
	
	UtilizedVersion = ManagingApplicationServiceUtilizedVersion(UserPassword);
	
	ConnectionParameters = New Structure;
	SetPrivilegedMode(True);
	ConnectionParameters.Insert("URL", SaaSOperations.InternalServiceManagerURL());
	SetPrivilegedMode(False);
	
	If ValueIsFilled(UserPassword) Then
		ConnectionParameters.Insert("UserName", UserName());
		ConnectionParameters.Insert("Password", UserPassword);
	Else
		ConnectionParameters.Insert("UserName", SaaSOperations.ServiceManagerOfficeUserName());
		ConnectionParameters.Insert("Password", SaaSOperations.ServiceManagerOfficeUserPassword());
	EndIf;
	
	Proxy = CommonUseReUse.WSProxy(
		ConnectionParameters.URL + "/ws/ManageApplication_" + StrReplace(UtilizedVersion, ".", "_") + "?wsdl",
		"http://www.1c.ru/SaaS/ManageApplication/" + UtilizedVersion,
		"ManagementApplication_" + StrReplace(UtilizedVersion, ".", "_"),
		,
		ConnectionParameters.UserName,
		ConnectionParameters.Password,
		60);
	
	Return Proxy;
	
EndFunction

// Returns utilized version of managing application service.
//
// Parameters:
//  UserPassword - String, user password.
//
// Returns - String, maximum version of managing application
//  service that can be used by current infobase.
//
Function ManagingApplicationServiceUtilizedVersion(Val UserPassword = "") Export
	
	InterfaceName = "ManagementApplication"; // Not localized
	MinimalVersion = "1.0.3.1";
	
	ConnectionParameters = New Structure;
	SetPrivilegedMode(True);
	ConnectionParameters.Insert("URL", SaaSOperations.InternalServiceManagerURL());
	ConnectionParameters.Insert("UserName", SaaSOperations.ServiceManagerOfficeUserName());
	ConnectionParameters.Insert("Password", SaaSOperations.ServiceManagerOfficeUserPassword());
	SetPrivilegedMode(False);
	
	SupportedVersions = CommonUse.GetInterfaceVersions(ConnectionParameters, InterfaceName);
	
	If SupportedVersions.Count() > 0 Then
		
		MaximalVersion = Undefined;
		
		For Each SupportedVersion IN SupportedVersions Do
			If (CommonUseClientServer.CompareVersions(SupportedVersion, MinimalVersion) >= 0) AND (MaximalVersion = Undefined Or (CommonUseClientServer.CompareVersions(SupportedVersion, MaximalVersion) > 0)) Then
				MaximalVersion = SupportedVersion;
			EndIf;
		EndDo;
		
		Return MaximalVersion;
		
	Else
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Correspondent %1 does not support interface %2!';ru='Корреспондент %1 не поддерживает интерфейс %2!'"),
			ConnectionParameters.URL,
			InterfaceName
		);
		
	EndIf;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns the name of managing application interface.
//
// Returns - String - interface name.
//
Function ManagingApplicationServiceInterface() Export
	
	Return "ManagementApplication"; // Not localized
	
EndFunction

// Ends the session of data area user.
//
// Parameters:
//  SessionNumber - Number - Session
//  number, UserPassword - String - password of current user of data area,
//
Procedure DataAreaSessionEnd(Val SessionNumber, Val UserPassword) Export
	
	ManagingApplicationServiceVersion = ManagingApplicationServiceUtilizedVersion(UserPassword);
	
	If CommonUseClientServer.CompareVersions(ManagingApplicationServiceVersion, "1.0.3.3") >= 0 Then
		
		ErrorInfo = Undefined;
		
		Proxy = ManagingApplicationServiceProxy(UserPassword);
		
		SetPrivilegedMode(True);
		CurrentDataArea = CommonUse.SessionSeparatorValue();
		DataAreaCurrentKey = Constants.DataAreaKey.Get();
		SetPrivilegedMode(False);
		
		Proxy.TerminateSession(
			CurrentDataArea,
			DataAreaCurrentKey,
			SessionNumber,
			ErrorInfo
		);
		
		SaaSOperations.ProcessInformationAboutWebServiceError(
			ErrorInfo,
			Metadata.Subsystems.ServiceTechnology.Subsystems.SaaS.Subsystems.RemoteAdministrationSaaS,
			ManagingApplicationServiceInterface(),
			"TerminateSession");
		
	Else
		
		Raise NStr("en='Current version of managing application does not support finishing of the session from applications. It is required to update the managing application.';ru='Текущая версия управляющего приложения не поддерживает завершение сеанса из приложений. Необходимо обновить управлящее приложение.'");
		
	EndIf;
	
EndProcedure

// Sends requests for external resources use (for infobase) to service manager.
//
// Parameters:
//  RequestsSerialization - XDTOObject {http://www.1c.ru/1CFresh/Application/Permissions/Management/a.b.c.d}PermissionsRequestsList.
//
Procedure SendQueriesForExternalResourcesUse(Val RequestsSerialization) Export
	
	ManagingApplicationServiceVersion = ManagingApplicationServiceUtilizedVersion();
	
	If CommonUseClientServer.CompareVersions(ManagingApplicationServiceVersion, "1.0.3.3") >= 0 Then
		
		ErrorInfo = Undefined;
		
		Proxy = ManagingApplicationServiceProxy();
		
		Proxy.ProcessInfobasePermissionsRequests(
			RequestsSerialization,
			ErrorInfo
		);
		
		SaaSOperations.ProcessInformationAboutWebServiceError(
			ErrorInfo,
			Metadata.Subsystems.ServiceTechnology.Subsystems.SaaS.Subsystems.RemoteAdministrationSaaS,
			ManagingApplicationServiceInterface(),
			"TerminateSession");
		
	Else
		
		Raise NStr("en='Current version of managing application does not support requests for permissions to use external resources. It is required to update the managing application.';ru='Текущая версия управляющего приложения не поддерживает запросы разрешений на использование внешних ресурсов. Необходимо обновить управлящее приложение.'");
		
	EndIf;
	
EndProcedure

// Sends requests for external resources use (for data area) to service manager.
//
// Parameters:
//  UserPassword - String - current user
//  password, QueriesSerialization - XDTOObject {http://www.1c.ru/1CFresh/Application/Permissions/Management/a.b.c.d}PermissionsRequestsList.
//
Procedure SendQueriesForDataAreasExternalResourcesUse(Val RequestsSerialization, UserPassword) Export
	
	ManagingApplicationServiceVersion = ManagingApplicationServiceUtilizedVersion(UserPassword);
	
	If CommonUseClientServer.CompareVersions(ManagingApplicationServiceVersion, "1.0.3.3") >= 0 Then
		
		ErrorInfo = Undefined;
		
		Proxy = ManagingApplicationServiceProxy(UserPassword);
		
		Proxy.ProcessZonePermissionsRequests(
			CommonUse.SessionSeparatorValue(),
			Constants.DataAreaKey.Get(),
			RequestsSerialization,
			ErrorInfo
		);
		
		SaaSOperations.ProcessInformationAboutWebServiceError(
			ErrorInfo,
			Metadata.Subsystems.ServiceTechnology.Subsystems.SaaS.Subsystems.RemoteAdministrationSaaS,
			ManagingApplicationServiceInterface(),
			"TerminateSession");
		
	Else
		
		Raise NStr("en='Current version of managing application does not support requests for permissions to use external resources. It is required to update the managing application.';ru='Текущая версия управляющего приложения не поддерживает запросы разрешений на использование внешних ресурсов. Необходимо обновить управлящее приложение.'");
		
	EndIf;
	
EndProcedure

// Checks the membership of current data area session.
//
// Parameters:
//  SessionNumber - Number, number of session which membership is checked.
//
// Returns - Boolean, membership sign
//  of the current data area session.
//
Function ValidateCurrentDataAreaSessionMembership(Val SessionNumber) Export
	
	AreaSessions = GetInfobaseSessions();
	For Each AreaSession IN AreaSessions Do
		If AreaSession.SessionNumber = SessionNumber Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

#EndRegion