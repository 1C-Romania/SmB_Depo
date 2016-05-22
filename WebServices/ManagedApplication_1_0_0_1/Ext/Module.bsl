#Region ApplicationInterface

// Checks membership of infobase session of specific data area.
//
// Parameters:
//  DataAreaNumber - Number(7,0,+) - data area
//  number, DataAreaKey - String - data area
//  key, SessionNumber - Number - number of infobase session which is
//    checked on belonging to data area.
//  ErrorInfo - XDTOObject {http://www.1c.ru/SaaS/ServiceCommon}ErrorDescription -
//   Description of web service transmission error.
//
Function ValidateDataAreasSessionMembership(DataAreaNumber, DataAreaKey, SessionNumber, ErrorInfo)
	
	Try
		
		If CommonUseReUse.DataSeparationEnabled() Then
			
			If CommonUseReUse.CanUseSeparatedData() Then
				
				Raise NStr("en = 'Operation can not be called in the session which started with indication of separators. Check correctness of web service publication!'");
				
			Else
				
				CommonUse.SetSessionSeparation(True, DataAreaNumber);
				
				If DataAreaKey <> Constants.DataAreaKey.Get() Then
					Raise NStr("en = 'Incorrect key of data area!'");
				EndIf;
				
				SetDataSeparationSafeMode(Metadata.CommonAttributes.DataAreaBasicData.Name, True);
				
				Return RemoteAdministrationSTLService.ValidateCurrentDataAreaSessionMembership(SessionNumber);
				
			EndIf;
			
		Else
			Raise NStr("en = 'Operation can not be executed for infobase in which separation by data areas is disabled!'");
		EndIf;
		
	Except
		
		ErrorInfo = ServiceTechnology.GetWebServiceErrorDescription(ErrorInfo());
		
	EndTry;
	
EndFunction

// Returns permissions to use external resources
//  required for correct operation of IB. Gets called at initial
//  activation of security profiles from service manager.
//
// Parameters:
//  ErrorInfo - XDTOObject {http://www.1c.ru/SaaS/ServiceCommon}ErrorDescription -
//   Description of web service transmission error.
//
// Returns - XDTOObject {http://www.1c.ru/1CFresh/Application/Permissions/Management/a.b.c.d}PermissionsRequestsList -
//  serialization of requests for permissions to use external resources.
//
Function GetRequiredExternalResourcesUsingPermissions(ErrorInfo)
	
	Try
		
		
		
	Except
		
		ErrorInfo = ServiceTechnology.GetWebServiceErrorDescription(ErrorInfo());
		
	EndTry;
	
EndFunction

// Returns requests of permissions to use external resources.
//
// Parameters:
//  SetRequests - UUID - set of queries on external resources use.
//  ErrorInfo - XDTOObject {http://www.1c.ru/SaaS/ServiceCommon}ErrorDescription -
//   Description of web service transmission error.
//
// Returns - XDTOObject {http://www.1c.ru/1CFresh/Application/Permissions/Management/a.b.c.d}PermissionsRequestsList -
//  serialization of requests for permissions to use external resources.
//
Function GetRequestsPermissions(PackageIdentifier, ErrorInfo)
	
	Try
		
		
		
	Except
		
		ErrorInfo = ServiceTechnology.GetWebServiceErrorDescription(ErrorInfo());
		
	EndTry;
	
EndFunction

#EndRegion
