////////////////////////////////////////////////////////////////////////////////
// HANDLER INTERFACE CONTROL MESSAGES FOR REMOTE ADMINISTRATION
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the namespace of the current (used by calling code) version of message interface.
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/RemoteAdministration/Control/" + Version();
	
EndFunction

// Returns the current (used by calling code) version of message interface.
Function Version() Export
	
	Return "1.0.2.5";
	
EndFunction

// Returns the name of the messages application interface.
Function ProgramInterface() Export
	
	Return "RemoteAdministrationControl";
	
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
	
	ArrayOfHandlers.Add(MessagesRemoteAdministrationControlTranslationHandler_1_0_2_3);
	ArrayOfHandlers.Add(MessagesRemoteAdministrationControlTranslationHandler_1_0_2_4);
	
EndProcedure

// Returns message type {http://www.1c.ru/SaaS/RemoteAdministration/Control/a.b.c.d}ApplicationPrepared.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageDataAreaPrepared(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ApplicationPrepared");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/RemoteAdministration/Control/a.b.c.d}ApplicationDeleted.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageDataAreaDeleted(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ApplicationDeleted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/RemoteAdministration/Control/a.b.c.d}ApplicationPrepareFailed.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageErrorPreparingDataArea(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ApplicationPrepareFailed");
	
EndFunction

// Returns type messages {http://www.1c.ru/SaaS/RemoteAdministration/Control/a.b.c.d}ApplicationPrepareFailedConversionRequired
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function ErrorMessageInDataPreparationAreasRequiredConversion(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ApplicationPrepareFailedConversionRequired");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/RemoteAdministration/Control/a.b.c.d}ApplicationDeleteFailed.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageErrorDeletingDataArea(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ApplicationDeleteFailed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/RemoteAdministration/Control/a.b.c.d}ApplicationReady.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageDataAreaIsReadyForUse(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ApplicationReady");
	
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
