////////////////////////////////////////////////////////////////////////////////
// HANDLER INFORMATION CENTER MESSAGES INTERFACE
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Returns the namespace of current version (used by the calling code) of message interface
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter/Messages/" + Version();
	
EndFunction

// Returns current version (used by the calling code) of message interface
Function Version() Export
	
	Return "1.0.1.1";
	
EndFunction

// Returns the name of the messages applicationming interface
Function ProgramInterface() Export
	
	Return "MessageInfoCenter";
	
EndFunction

// Registers message handlers as handlers of message exchange channels
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessageChanelProcessors(Val ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(InformationCenterMessagesMessageHandler_1_0_1_1);
	
EndProcedure

// Return message type {http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter/Messages/a.b.c.d}notificateSuggestion
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageNotificationsWishes(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "notificateSuggestion");
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

Function CreateMessageType(Val UsingPackage = Undefined, Val Type)
	
	If UsingPackage = Undefined Then
		UsingPackage = Package();
	EndIf;
	
	Return XDTOFactory.Type(UsingPackage, Type);
	
EndFunction