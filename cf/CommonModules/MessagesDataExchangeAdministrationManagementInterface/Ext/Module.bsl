////////////////////////////////////////////////////////////////////////////////
// MESSAGE INTERFACE HANDLER DATA EXCHANGE ADMINISTRATION MANAGEMENT
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the namespace of current version (used by the calling code) of message interface
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ExchangeAdministration/Manage";
	
EndFunction

// Returns current version (used by the calling code) of message interface
Function Version() Export
	
	Return "2.1.2.1";
	
EndFunction

// Returns the name of the messages applicationming interface
Function ProgramInterface() Export
	
	Return "ExchangeAdministrationManage";
	
EndFunction

// Registers message handlers as handlers of message exchange channels
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessageChanelProcessors(Val ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessagesDataExchangeAdministrationManagementMessageHandler_2_1_2_1);
	
EndProcedure

// Registers handlers of message translation.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessagesTranslationHandlers(Val ArrayOfHandlers) Export
	
EndProcedure

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}ConnectCorrespondent
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageConnectCorrespondent(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ConnectCorrespondent");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}SetTransportParams
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSetTransportSettings(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "TransportSetParams");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}GetSyncSettings
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageGetDataSynchronizationSettings(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "GetSyncSettings");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}DeleteSync
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageDeleteSynchronizationSetting(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "DeleteSync");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}EnableSync
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageEnableSynchronization(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "EnableSync");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}DisableSync
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageDisableSynchronization(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "DisableSync");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}PushSync
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessagePushSynchronization(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "PushSync");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}PushTwoApplicationSync
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessagePushTwoApplicationsSynchronization(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "PushTwoApplicationSync");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}ExecuteSync
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessagePerformSynchronization(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExecuteSync");
	
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
