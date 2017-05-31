#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure SessionParametersSetting(SessionParameterNames)
	
	// StandardSubsystems
	StandardSubsystemsServer.SessionParametersSetting(SessionParameterNames);
	// End StandardSubsystems
	
	// ServiceTechnology
	ServiceTechnology.PerformActionsAtSettingSessionParameters(SessionParameterNames);
	// End ServiceTechnology
	
	// by Jack 28.03.2017
	SessionParameters.IsBookkeepingAvailable = Constants.BookkeepingFunctionalityConstant.Get();

	
EndProcedure

#EndRegion

#EndIf