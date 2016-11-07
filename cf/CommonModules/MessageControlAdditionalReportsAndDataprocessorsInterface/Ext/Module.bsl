////////////////////////////////////////////////////////////////////////////////
// MESSAGE CONTROL ADDITIONAL REPORTS AND DATA PROCESSORS INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Returns the namespace of current version (used by the calling code) of message interface
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/ApplicationExtensions/Control/" + Version();
	
EndFunction

// Returns current version (used by the calling code) of message interface
Function Version() Export
	
	Return "1.0.1.1";
	
EndFunction

// Returns the name of the messages applicationming interface
Function ProgramInterface() Export
	
	Return "ApplicationExtensionsControl";
	
EndFunction

// Registers message handlers as handlers of message exchange channels
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessageChanelProcessors(Val ArrayOfHandlers) Export
	
	
	
EndProcedure

// Registers handlers of message translation.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessagesTranslationHandlers(Val ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessageControlAdditionalReportsAndDataprocessorsLocHandler_1_0_0_1);
	
EndProcedure

// Return message type {http://www.1c.ru/1cFresh/ApplicationExtensions/Control/a.b.c.d}ExtensionInstalled
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageAdditionalReportOrDataProcessorInstalled(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExtensionInstalled");
	
EndFunction

// Return message type {http://www.1c.ru/1cFresh/ApplicationExtensions/Control/a.b.c.d}ExtensionDeleted
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageAdditionalReportOrDataProcessorIsDeleted(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExtensionDeleted");
	
EndFunction

// Return message type {http://www.1c.ru/1cFresh/ApplicationExtensions/Control/a.b.c.d}ExtensionInstallFailed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function ErrorMessageInstallingAdditionalReportOrDataProcessors(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExtensionInstallFailed");
	
EndFunction

// Return message type {http://www.1c.ru/1cFresh/ApplicationExtensions/Control/a.b.c.d}ExtensionDeleteFailed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function ErrorMessageRemoveAdditionalReportOrDataProcessors(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExtensionDeleteFailed");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

Function CreateMessageType(Val UsingPackage, Val Type)
	
	If UsingPackage = Undefined Then
		UsingPackage = Package();
	EndIf;
	
	Return XDTOFactory.Type(UsingPackage, Type);
	
EndFunction
