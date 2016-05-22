///////////////////////////////////////////////////////////////////////////////
// HANDLER OF THE REMOTE ADMINISTRATION
//  CONTROL MESSAGES TRANSLATION FROM VERSION 1.0.2.4 TO 1.0.2.3
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the version number for translation from which the handler is intended for.
Function OriginalVersion() Export
	
	Return "1.0.2.4";
	
EndFunction

// Returns the name space version for translation from which the handler is intended for.
Function SourceVersionPackage() Export
	
	Return "http://www.1c.ru/1cFresh/RemoteAdministration/Control/1.0.2.4";
	
EndFunction

// Returns the version number for translation to which the handler is intended for.
Function ResultingVersion() Export
	
	Return "1.0.2.3";
	
EndFunction

// Returns the version number for translation to which the handler is intended for.
Function PackageResultingVersions() Export
	
	Return "http://www.1c.ru/1cFresh/RemoteAdministration/Control/1.0.2.3";
	
EndFunction

// Handler of checking the execution of the standard translation data processor.
//
// Parameters:
//  OriginalMessage - ObjectXDTO the transmitted message,
//  StandardProcessing - Boolean, to cancel standard translation processor
//   this parameter inside this procedure is to be set to False.
//   At that, instead of execution of the translation processor, the function will be called.
//   MessageTranslation() of the translation handler.
//
Procedure BeforeTranslation(Val OriginalMessage, StandardProcessing) Export
	
EndProcedure

// Message arbtitrary translation handler. 
//  It is called only if the StandardProcessing value was set to False
//  when executing the BeforeTranslation procedure.
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
