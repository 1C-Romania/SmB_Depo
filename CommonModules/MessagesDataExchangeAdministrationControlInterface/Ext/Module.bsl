////////////////////////////////////////////////////////////////////////////////
// CONTROL MESSAGE INTERFACE HANDLER BY DATA EXCHANGE ADMINISTRATION
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the namespace of current version (used by the calling code) of message interface
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ExchangeAdministration/Control";
	
EndFunction

// Returns current version (used by the calling code) of message interface
Function Version() Export
	
	Return "2.1.2.1";
	
EndFunction

// Returns the name of the messages applicationming interface
Function ProgramInterface() Export
	
	Return "ExchangeAdministrationControl";
	
EndFunction

// Registers message handlers as handlers of message exchange channels
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessageChanelProcessors(Val ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessagesDataExchangeAdministrationControlMessageHandler_2_1_2_1);
	
EndProcedure

// Registers handlers of message translation.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessagesTranslationHandlers(Val ArrayOfHandlers) Export
	
EndProcedure

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}CorrespondentConnectionCompleted
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//                 for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageCorrespondentConnectedSuccessfully(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "CorrespondentConnectionExecuted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}CorrespondentConnectionFailed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//                 for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageCorrespondentConnectingError(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "CorrespondentConnectionFailed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}GettingSyncSettingsCompleted
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//                 for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageDataSynchronizationSettingsReceived(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "GettingSyncSettingsCommandIsExecuted");
	
EndFunction

// Returns message type  {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}GettingSyncSettingsFailed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//                 for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageDataSynchronizationSettingsGettingError(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "GettingSyncSettingsFailed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}EnableSyncCompleted
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//                 for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSynchronizationEnablingCompletedSuccessfully(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "EnableSyncExecuted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}DisableSyncCompleted
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//                 for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSynchronizationDisabledSuccessfully(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "DisableSyncExecuted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}EnableSyncFailed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//                 for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSynchronizationEnablingError(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "EnableSyncFailed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}DisableSyncFailed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSynchronizationDisablingError(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "DisableSyncFailed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}SyncCompleted
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//                 for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSynchronizationCompleted(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SyncExecuted");
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// For internal use
//
Function CreateMessageType(Val UsingPackage, Val Type)
	
	If UsingPackage = Undefined Then
		UsingPackage = Package();
	EndIf;
	
	Return XDTOFactory.Type(UsingPackage, Type);
	
EndFunction

#EndRegion
