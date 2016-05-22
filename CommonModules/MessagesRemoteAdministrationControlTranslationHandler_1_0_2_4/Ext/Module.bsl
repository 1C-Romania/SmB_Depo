///////////////////////////////////////////////////////////////////////////////
// HANDLER CONTROL BROADCAST MESSAGES FOR
//  REMOTE ADMINISTRATION FROM VERSION 1.0.2.5 TO VERSION 1.0.2.4
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the version number for translation from which the handler is intended for.
Function OriginalVersion() Export
	
	Return "1.0.2.5";
	
EndFunction

// Returns the name space version for translation from which the handler is intended for.
Function SourceVersionPackage() Export
	
	Return "http://www.1c.ru/1cFresh/RemoteAdministration/Control/" + OriginalVersion();
	
EndFunction

// Returns the version number for translation to which the handler is intended for.
Function ResultingVersion() Export
	
	Return "1.0.2.4";
	
EndFunction

// Returns the version number for translation to which the handler is intended for.
Function PackageResultingVersions() Export
	
	Return "http://www.1c.ru/1cFresh/RemoteAdministration/Control/" + ResultingVersion();
	
EndFunction

// Handler of checking the execution of the standard translation data processor.
//
// Parameters:
//  OriginalMessage - ObjectXDTO the
//  transmitted message, StandardProcessing - Boolean cancel perform DataProcessors standard
//    for broadcast this parameter inside this procedure Required install value False.
//    At that, instead of execution of the translation data processor, the function will be called.
//    MessageTranslation() of the translation handler.
//
Procedure BeforeTranslation(Val OriginalMessage, StandardProcessing) Export
	
EndProcedure

// Message arbtitrary translation handler. socalled only to
//  the volume event if when implementation procedure BeforeTranslation
//  to the value StandardProcessing for the parameter value was set to False.
//
// Parameters:
//  OriginalMessage - ObjectXDTO, message being translated.
//
// Returns:
//  ObjectXDTO, the result of message arbitrary translation.
//
Function BroadcastMessage(Val OriginalMessage) Export
	
EndFunction

#EndRegion
