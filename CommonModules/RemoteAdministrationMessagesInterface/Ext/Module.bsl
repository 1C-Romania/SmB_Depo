////////////////////////////////////////////////////////////////////////////////
// REMOTE ADMINISTRATION MESSAGE INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the namespace of the current (used by calling code) version of message interface.
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/RemoteAdministration/App/" + Version();
	
EndFunction

// Returns the current (used by calling code) version of message interface.
Function Version() Export
	
	Return "1.0.3.4";
	
EndFunction

// Returns the name of the messages application interface.
Function ProgramInterface() Export
	
	Return "RemoteAdministrationApp";
	
EndFunction

// Registers message handlers as handlers of message exchange channel.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessageChanelProcessors(Val ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(RemoteAdministrationMessagesHandlerMessage_1_0_3_1);
	ArrayOfHandlers.Add(RemoteAdministrationMessagesHandlerMessage_1_0_3_2);
	ArrayOfHandlers.Add(RemoteAdministrationMessagesHandlerMessage_1_0_3_3);
	ArrayOfHandlers.Add(RemoteAdministrationMessagesHandlerMessage_1_0_3_4);
	ArrayOfHandlers.Add(RemoteAdministrationMessagesHandlerMessage_1_0_3_5);
	
EndProcedure

// Registers handlers of message translation.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessagesTranslationHandlers(Val ArrayOfHandlers) Export
	
EndProcedure

// Returns message type {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}UpdateUser.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageUpdateUser(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "UpdateUser");
	
EndFunction

// Returns message type {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}SetFullControl.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSetDataAreaFullAccess(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SetFullControl");
	
EndFunction

// Returns message type {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}SetApplicationAccess.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSetAccessToDataArea(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SetApplicationAccess");
	
EndFunction

// Returns message type {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}SetDefaultUserRights.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSetDefaultUserRights(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SetDefaultUserRights");
	
EndFunction

// Returns message type {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}PrepareApplication.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessagePrepareDataArea(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "PrepareApplication");
	
EndFunction

// Returns message type {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}BindApplication.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageDataAreaAttach(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "BindApplication");
	
EndFunction

// Returns message type {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}UsersList.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageUsersList(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "UsersList");
	
EndFunction

// Returns message type {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}PrepareCustomApplication.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessagePrepareDataAreaFromExporting(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "PrepareCustomApplication");
	
EndFunction

// Returns message type {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}DeleteApplication.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageDeleteDataArea(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "DeleteApplication");
	
EndFunction

// Returns message type {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}SetApplicationParams.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSetDataAreaParameters(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SetApplicationParams");
	
EndFunction

// Returns message type {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}SetIBParams.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSetInfobaseParameters(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SetIBParams");
	
EndFunction

// Returns message type {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}SetServiceManagerEndPoint.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSetServiceManagerEndPoint(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SetServiceManagerEndPoint");
	
EndFunction

// Returns message type {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}ApplicationsRating.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function DataAreasRatingType(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ApplicationRating");
	
EndFunction

// Returns message type {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}SetApplicationsRating.
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSetDataAreaRating(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SetApplicationsRating");
	
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
