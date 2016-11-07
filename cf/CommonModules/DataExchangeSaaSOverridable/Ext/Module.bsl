////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data exchange in the service model".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Outdated. You should use OnDefineRequiredApplicationVersion
//
Function RequiredApplicationVersion() Export
	
EndFunction

// Specifies the version of 1C:Enterprise that is required
// for work of the offline workplace. The application of this version must be installed on the user's local computer.
// If a return value of the function is not set, then
// as the required application version the default value will be used:
// the first three numbers of the current application version located in the Internet, for example, "8.3.3".
// Used in the offline workplace assistant.
//
// Parameters:
// Version - String - The version of the 1C:Enterprises
// application in the format as <main version>.<younger version>.<release>.<additional release number>.
// For example, "8.3.3.715".
//
Procedure OnDefineRequiredApplicationVersion(Version) Export
	
EndProcedure

#EndRegion