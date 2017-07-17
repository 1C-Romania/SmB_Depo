////////////////////////////////////////////////////////////////////////////////
// Subsystem "DataAreasBackupDataFormsInterface".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

Function GetFormParametersSettings(Val DataArea) Export
	
	ErrorInfo = Undefined;
	Parameters = Proxy().GetSettingsFormParameters(
		DataArea,
		AreaKey(),
		ErrorInfo);
	// The operation name is not localized.
	ProcessInformationAboutWebServiceError(ErrorInfo, "GetSettingsFormParameters");
	
	Return XDTOSerializer.ReadXDTO(Parameters);
	
EndFunction

Function GetAreaSettings(Val DataArea) Export
	
	ErrorInfo = Undefined;
	Parameters = Proxy().GetZoneSettings(
		DataArea,
		AreaKey(),
		ErrorInfo);
	ProcessInformationAboutWebServiceError(ErrorInfo, "GetZoneSettings"); // The operation name is not localized.
	
	Return XDTOSerializer.ReadXDTO(Parameters);
	
EndFunction

Procedure SetAreasSettings(Val DataArea, Val NewSettings, Val InitialSettings) Export
	
	ErrorInfo = Undefined;
	Proxy().SetZoneSettings(
		DataArea,
		AreaKey(),
		XDTOSerializer.WriteXDTO(NewSettings),
		XDTOSerializer.WriteXDTO(InitialSettings),
		ErrorInfo);
	ProcessInformationAboutWebServiceError(ErrorInfo, "SetZoneSettings"); // The operation name is not localized.
	
EndProcedure

Function GetStandardSettings() Export
	
	ErrorInfo = Undefined;
	Parameters = Proxy().GetDefaultSettings(
		ErrorInfo);
	ProcessInformationAboutWebServiceError(ErrorInfo, "GetDefaultSettings"); // The operation name is not localized.
	
	Return XDTOSerializer.ReadXDTO(Parameters);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

Function AreaKey()
	
	SetPrivilegedMode(True);
	Return Constants.DataAreaKey.Get();
	
EndFunction

Function Proxy()
	
	SetPrivilegedMode(True);
	ServiceManagerAddress = Constants.InternalServiceManagerURL.Get();
	If Not ValueIsFilled(ServiceManagerAddress) Then
		Raise(NStr("en='Parameters of connection with the service manager are not set.';ru='Не установлены параметры связи с менеджером сервиса.'"));
	EndIf;
	
	ServiceAddress = ServiceManagerAddress + "/ws/ZoneBackupControl_1_0_2_1?wsdl";
	UserName = Constants.ServiceManagerOfficeUserName.Get();
	UserPassword = Constants.ServiceManagerOfficeUserPassword.Get();
	
	Proxy = CommonUse.WSProxy(ServiceAddress, "http://www.1c.ru/1cFresh/ZoneBackupControl/1.0.2.1",
		"ZoneBackupControl_1_0_2_1", , UserName, UserPassword, 10);
		
	Return Proxy;
	
EndFunction

// Processes the error details received from the web service.
// If not empty error info is passed, writes the
// detailed error presentation to the events log monitor
// and throws an exception with the brief error presentation text.
//
Procedure ProcessInformationAboutWebServiceError(Val ErrorInfo, Val OperationName)
	
	SaaSOperations.ProcessInformationAboutWebServiceError(
		ErrorInfo,
		DataAreasBackupReUse.SubsystemNameForEventLogMonitorEvents(),
		"ZoneBackupControl", // Not localized
		OperationName);
	
EndProcedure

#EndRegion
