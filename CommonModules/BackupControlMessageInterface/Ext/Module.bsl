////////////////////////////////////////////////////////////////////////////////
// HANDLER OF THE BACKUP CONTROL MESSAGES INTERFACE
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the namespace of the current (used by calling code) version of message interface.
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ControlZonesBackup/" + Version();
	
EndFunction

// Returns the current (used by calling code) version of message interface.
Function Version() Export
	
	Return "1.0.3.1";
	
EndFunction

// Returns the name of the messages application interface.
Function ProgramInterface() Export
	
	Return "ControlZonesBackup";
	
EndFunction

// Registers message handlers as handlers of message exchange channel.
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
	
	ArrayOfHandlers.Add(MessagesBackupControlTranslationHandler_1_0_2_1);
	
EndProcedure

// Returns message type {http://www.1c.ru/SaaS/ControlZonesBackup/a.b.c.d}ZoneBackupSuccessfull.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageAreaBackupCopyIsCreated(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ZoneBackupSuccessfull");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ControlZonesBackup/a.b.c.d}ZoneBackupFailed.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageZoneBackupFailed(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ZoneBackupFailed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ControlZonesBackup/a.b.c.d}ZoneBackupSkipped.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageZoneBackupSkipped(Val UsingPackage = Undefined) Export
	
	If UsingPackage = Undefined Then
		UsingPackage = "http://www.1c.ru/SaaS/ControlZonesBackup/1.0.2.1";
	EndIf;
	
	Return CreateMessageType(UsingPackage, "ZoneBackupSkipped");
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Function CreateMessageType(Val UsingPackage, Val Type)
	
	If UsingPackage = Undefined Then
		UsingPackage = Package();
	EndIf;
	
	Return XDTOFactory.Type(UsingPackage, Type);
	
EndFunction

#EndRegion
