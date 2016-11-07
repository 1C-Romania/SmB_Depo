////////////////////////////////////////////////////////////////////////////////
// MANAGEMENT MESSAGE INTERFACE HANDLER OF ADDITIONAL REPORTS AND DATA PROCESSORS
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Returns the namespace of current version (used by the calling code) of message interface
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/ApplicationExtensions/Management/" + Version();
	
EndFunction

// Returns current version (used by the calling code) of message interface
Function Version() Export
	
	Return "1.0.1.2";
	
EndFunction

// Returns the name of the messages applicationming interface
Function ProgramInterface() Export
	
	Return "ApplicationExtensionsManagement";
	
EndFunction

// Registers message handlers as handlers of message exchange channels
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessageChanelProcessors(Val ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessagesManagementAdditionalReportsAndDataProcessorsMessageHandler_1_0_1_1);
	ArrayOfHandlers.Add(MessagesManagementAdditionalReportsAndDataProcessorsMessageHandler_1_0_1_2);
	
EndProcedure

// Registers handlers of message translation.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessagesTranslationHandlers(Val ArrayOfHandlers) Export
	
	
	
EndProcedure

// Returns message type {http://www.1c.ru/1CFresh/ApplicationExtensions/Management/a.b.c.d}InstallExtension
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSetAdditionalReportOrProcessing(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "InstallExtension");
	
EndFunction

// Returns message type {http://www.1c.ru/1CFresh/ApplicationExtensions/Management/a.b.c.d}ExtensionCommandSettings
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeCommandsAdditionalReportSettingsOrDataProcessors(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExtensionCommandSettings");
	
EndFunction

// Returns message type {http://www.1c.ru/1CFresh/ApplicationExtensions/Management/a.b.c.d}DeleteExtension
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageDeleteAdditionalReportOrProcessing(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "DeleteExtension");
	
EndFunction

// Returns message type {http://www.1c.ru/1CFresh/ApplicationExtensions/Management/a.b.c.d}DisableExtension
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageDisableAdditionalReportOrProcessing(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "DisableExtension");
	
EndFunction

// Returns message type {http://www.1c.ru/1CFresh/ApplicationExtensions/Management/a.b.c.d}EnableExtension
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageEnableAdditionalReportOrProcessing(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "EnableExtension");
	
EndFunction

// Returns message type {http://www.1c.ru/1CFresh/ApplicationExtensions/Management/a.b.c.d}DropExtension
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageRecallAdditionalReportOrProcessing(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "DropExtension");
	
EndFunction

// Returns message type {http://www.1c.ru/1CFresh/ApplicationExtensions/Management/a.b.c.d}SetExtensionSecurityProfile
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSetModeForAdditionalReportExecutionOrProcessingInDataArea(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SetExtensionSecurityProfile");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

Function CreateMessageType(Val UsingPackage, Val Type)
	
	If UsingPackage = Undefined Then
		UsingPackage = Package();
	EndIf;
	
	Return XDTOFactory.Type(UsingPackage, Type);
	
EndFunction