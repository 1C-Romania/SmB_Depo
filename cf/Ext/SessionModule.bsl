#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure SessionParametersSetting(SessionParameterNames)
	
	// StandardSubsystems
	StandardSubsystemsServer.SessionParametersSetting(SessionParameterNames);
	// End StandardSubsystems
	
	// ServiceTechnology
	ServiceTechnology.PerformActionsAtSettingSessionParameters(SessionParameterNames);
	// End ServiceTechnology
	
EndProcedure

#EndRegion

#EndIf