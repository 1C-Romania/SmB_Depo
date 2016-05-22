////////////////////////////////////////////////////////////////////////////////
// APPLICATION MANAGEMENT MESSAGES INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the namespace of the current (used by calling code) version of message interface.
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/ManageApplication/Messages/1.0";
	
EndFunction

// Returns the current (used by calling code) version of message interface.
Function Version() Export
	
	Return "1.0.0.1";
	
EndFunction

// Returns the name of the messages application interface.
Function ProgramInterface() Export
	
	Return "ManageApplicationMessages";
	
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
	
EndProcedure

// Returns message type {http://www.1c.ru/1cFresh/ManageApplication/Messages/a.b.c.d}RevokeUserAccess.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageRevokeUserAccess(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "RevokeUserAccess");
	
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
