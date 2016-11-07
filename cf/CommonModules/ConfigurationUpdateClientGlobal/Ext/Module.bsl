////////////////////////////////////////////////////////////////////////////////
// Subsystem "Configuration update".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Procedure of the configuration on schedule update checking.
Procedure ProcessUpdateCheckOnSchedule() Export
	ConfigurationUpdateClient.CheckUpdateOnSchedule();
EndProcedure

#EndRegion
