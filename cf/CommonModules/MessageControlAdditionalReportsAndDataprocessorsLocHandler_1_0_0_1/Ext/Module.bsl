///////////////////////////////////////////////////////////////////////////////
// ADDITIONAL REPORTS AND DATA PROCESSORS CONTROL MESSAGES
//  TRANSLATION HANDLER FROM VERSION 1.0.1.1 TO REMOTE ADMINISTRATION CONTROL MESSAGES VERSION 1.0.2.4
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Returns the version number for translation with which handler is required
Function OriginalVersion() Export
	
	Return "1.0.1.1";
	
EndFunction

// Returns the version names area for translation with which handler is required
Function SourceVersionPackage() Export
	
	Return "http://www.1c.ru/1cFresh/ApplicationExtensions/Control/" + OriginalVersion();
	
EndFunction

// Returns the version number for translation to which handler is required
Function ResultingVersion() Export
	
	Return "1.0.0.1";
	
EndFunction

// Returns the version names area for translation to which handler is required
Function PackageResultingVersions() Export
	
	Return "http://www.1c.ru/1cFresh/RemoteAdministration/Control/1.0.2.4";
	
EndFunction

// Checking handler of the standard translation processor execution.
//
// Parameters:
//  OriginalMessage - ObjectXDTO, message
//  being translated, StandardProcessing - Boolean, to cancel the execution
//    of the translation standard data processor, it is required to set this parameter to False inside this procedure.
//    At the same time, instead of a standard data
//    processor the MessageTranslation()function of the translation handler will be called.
//
Procedure BeforeTranslation(Val OriginalMessage, StandardProcessing) Export
	
	
	
EndProcedure

// Message arbtitrary translation handler. It is called only
//  in that case if during the execution of
//  the BeforeTranslation procedure, the StandardProcessing parameter was set to False.
//
// Parameters:
//  OriginalMessage - ObjectXDTO, message being translated.
//
// Returns:
//  ObjectXDTO, the result of message arbitrary translation.
//
Function BroadcastMessage(Val OriginalMessage) Export
	
	
	
EndFunction













