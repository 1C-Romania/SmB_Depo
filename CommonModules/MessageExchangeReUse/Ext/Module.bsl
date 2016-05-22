////////////////////////////////////////////////////////////////////////////////
// MessageExchangeReUse: message exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Return a reference to the WSProxy object for the specified exchange node.
//
// Parameters:
// EndPoint - ExchangePlanRef.
//
Function WSEndPointProxy(EndPoint, Timeout) Export
	
	SettingsStructure = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(EndPoint);
	
	ErrorMessageString = "";
	
	Result = MessageExchangeInternal.GetWSProxy(SettingsStructure, ErrorMessageString, Timeout);
	
	If Result = Undefined Then
		Raise ErrorMessageString;
	EndIf;
	
	Return Result;
EndFunction

// Return an array of catalogs managers, that
// can be used to store messages.
//
Function GetMessagesCatalogs() Export
	
	ArrayCatalog = New Array();
	
	If CommonUseReUse.IsSeparatedConfiguration() Then
		ModuleMessageSaaSDataSeparation = CommonUse.CommonModule("MessagesSaaSDataSeparation");
		ModuleMessageSaaSDataSeparation.WhenFillingCatalogsMessages(ArrayCatalog);
	EndIf;
	
	ArrayCatalog.Add(Catalogs.SystemMessages);
	
	Return ArrayCatalog;
	
EndFunction

#EndRegion
