////////////////////////////////////////////////////////////////////////////////
// Subsystem "Logging off users".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns a structure with parameters for forced session disconnection.
//
Function SessionTerminationParameters() Export
	
	ServerPlatformType = CommonUseReUse.ServerPlatformType();
	
	Return New Structure("InfobaseSessionNumber,WindowsPlatformAtServer",
		InfobaseSessionNumber(),
		ServerPlatformType = PlatformType.Windows_x86
			Or ServerPlatformType = PlatformType.Windows_x86_64);
	
EndFunction

#EndRegion
