#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure SessionParametersSetting(SessionParameterNames)
	
	// StandardSubsystems
	StandardSubsystemsServer.SessionParametersSetting(SessionParameterNames);
	// End StandardSubsystems
	
	// ServiceTechnology
	ServiceTechnology.PerformActionsAtSettingSessionParameters(SessionParameterNames);
	// End ServiceTechnology
	
	// Rise { Popov N 2016-05-26
	RiseTranslation.SessionParametersSetting();
	// Rise } Popov N 2016-05-26

	
EndProcedure

#EndRegion

#EndIf