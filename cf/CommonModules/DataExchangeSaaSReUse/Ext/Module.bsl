////////////////////////////////////////////////////////////////////////////////
// DataExchangeSaaSReUse: data exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns a reference to the WSProxy object of the exchange service version 1.0.6.5.
//
// Returns:
// WSProxy.
//
Function GetExchangeServiceWSProxy() Export
	
	TransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(
		SaaSReUse.ServiceManagerEndPoint());
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("WSURLWebService",   TransportSettings.WSURLWebService);
	SettingsStructure.Insert("WSUserName", TransportSettings.WSUserName);
	SettingsStructure.Insert("WSPassword",          TransportSettings.WSPassword);
	SettingsStructure.Insert("WSServiceName",      "ManageApplicationExchange_1_0_6_5");
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SaaS/1.0/WS/ManageApplicationExchange_1_0_6_5");
	SettingsStructure.Insert("WSTimeout", 20);
	
	Result = DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure);
	
	If Result = Undefined Then
		Raise NStr("en='Error of receiving of the data exchange web service of the managing application.';ru='Ошибка получения web-сервиса обмена данными управляющего приложения.'");
	EndIf;
	
	Return Result;
EndFunction

// Returns a reference to the WSProxy object of the correspondent that is identified by the exchange plan node.
//
// Parameters:
// InfobaseNode       - ExchangePlanRef.
// ErrorMessageString - String - Error message text.
//
// Returns:
// WSProxy.
//
Function GetCorrespondentWSProxy(InfobaseNode, ErrorMessageString = "") Export
	
	SettingsStructure = InformationRegisters.DataAreaTransportExchangeSettings.TransportSettingsWS(InfobaseNode);
	SettingsStructure.Insert("WSServiceName", "RemoteAdministrationOfExchange");
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SaaS/1.0/WS/RemoteAdministrationOfExchange");
	SettingsStructure.Insert("WSTimeout", 20);
	
	Return DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
	
EndFunction

// Returns a reference to the WSProxy object version 2.0.1.6 correspondent, identified by the node exchange plan.
//
// Parameters:
// InfobaseNode       - ExchangePlanRef.
// ErrorMessageString - String - Error message text.
//
// Returns:
// WSProxy.
//
Function GetCorrespondentWSProxy_2_0_1_6(InfobaseNode, ErrorMessageString = "") Export
	
	SettingsStructure = InformationRegisters.DataAreaTransportExchangeSettings.TransportSettingsWS(InfobaseNode);
	SettingsStructure.Insert("WSServiceName", "RemoteAdministrationOfExchange_2_0_1_6");
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SaaS/1.0/WS/RemoteAdministrationOfExchange_2_0_1_6");
	SettingsStructure.Insert("WSTimeout", 20);
	
	Return DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
EndFunction

// Returns True if the data synchronization in the service model is supported
//
Function DataSynchronizationSupported() Export
	
	Return DataSynchronizationExchangePlans().Count() > 0;
	
EndFunction

// Exchange plan for data synchronization in the service model must:
// - be connected to the SSL data exchange subsystem
// - be separated
// - NOT be the DIB exchange plan
// - used for exchange in service model (ExchangePlanUsedSaaS = True)
//
Function DataSynchronizationExchangePlans() Export
	
	Result = New Array;
	
	For Each ExchangePlan IN Metadata.ExchangePlans Do
		
		If Not ExchangePlan.DistributedInfobase
			AND DataExchangeReUse.ExchangePlanUsedSaaS(ExchangePlan.Name)
			AND DataExchangeServer.IsSeparatedExchangePlanSSL(ExchangePlan.Name) Then
			
			Result.Add(ExchangePlan.Name);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// Returns True if this exchange plan is used for data synchronization in service model.
//
Function IsDataSynchronizationExchangePlan(Val ExchangePlanName) Export
	
	Return DataSynchronizationExchangePlans().Find(ExchangePlanName) <> Undefined;
	
EndFunction

#EndRegion
