////////////////////////////////////////////////////////////////////////////////
// BACKUP MANAGEMENT MESSAGE INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the namespace of the current (used by calling code) version of message interface.
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ManageZonesBackup/" + Version();
	
EndFunction

// Returns the current (used by calling code) version of message interface.
Function Version() Export
	
	Return "1.0.3.1";
	
EndFunction

// Returns the name of the messages application interface.
Function ProgramInterface() Export
	
	Return "ManageZonesBackup";
	
EndFunction

// Registers message handlers as handlers of message exchange channel.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessageChanelProcessors(Val ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessagesControlBackupMessageHandler_1_0_2_1);
	ArrayOfHandlers.Add(MessagesControlBackupMessageHandler_1_0_3_1);
	
EndProcedure

// Registers handlers of message translation.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessagesTranslationHandlers(Val ArrayOfHandlers) Export
	
EndProcedure

// Returns message type {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}PlanZoneBackup.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessagePlanZoneBackup(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "PlanZoneBackup");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}CancelZoneBackup.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageCancelZoneBackup(Val UsingPackage = Undefined) Export
	
	If UsingPackage = Undefined Then
		UsingPackage = "http://www.1c.ru/SaaS/ManageZonesBackup/1.0.2.1";
	EndIf;
	
	Return CreateMessageType(UsingPackage, "CancelZoneBackup");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}UpdateScheduledZoneBackupSettings
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageRefreshSettingsPeriodicBackup(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "UpdateScheduledZoneBackupSettings");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}CancelScheduledZoneBackup
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageCancelPeriodicBackup(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "CancelScheduledZoneBackup");
	
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
