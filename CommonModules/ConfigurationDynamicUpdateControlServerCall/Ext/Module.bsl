////////////////////////////////////////////////////////////////////////////////
// Subsystem "Dynamic configuration update control".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Check if infobase is updated dynamically.
//
Function DBConfigurationWasChangedDynamically() Export
	
	Return DataBaseConfigurationChangedDynamically();
	
EndFunction

#EndRegion
