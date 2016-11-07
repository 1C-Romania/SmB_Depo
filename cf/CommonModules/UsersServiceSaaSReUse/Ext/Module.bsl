///////////////////////////////////////////////////////////////////////////////////
// Users in the service model subsystem.
// 
///////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// It returns the subsystem name, which should
//  be used in the names of the registration log events.
//
// Return value: String.
//
Function SubsystemNameForEventLogMonitorEvents() Export
	
	Return Metadata.Subsystems.StandardSubsystems.Subsystems.SaaS.Subsystems.UsersSaaS.Name;
	
EndFunction

#EndRegion
