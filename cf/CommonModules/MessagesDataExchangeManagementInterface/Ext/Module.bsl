////////////////////////////////////////////////////////////////////////////////
// DATA EXCHANGE MANAGEMENT MESSAGE INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the namespace of current version (used by the calling code) of message interface
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/Exchange/Manage";
	
EndFunction

// Returns current version (used by the calling code) of message interface
Function Version() Export
	
	Return "2.1.2.1";
	
EndFunction

// Returns the name of the messages applicationming interface
Function ProgramInterface() Export
	
	Return "ExchangeManage";
	
EndFunction

// Registers message handlers as handlers of message exchange channels
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessageChanelProcessors(Val ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessagesDataExchangeManagementMessageHandler_2_1_2_1);
	
EndProcedure

// Registers handlers of message translation.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessagesTranslationHandlers(Val ArrayOfHandlers) Export
	
EndProcedure

// Returns message type {http://www.1c.ru/SaaS/Exchange/Manage/a.b.c.d}SetupExchangeStep1
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSetExchangeStep1(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SetupExchangeStep1");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Manage/a.b.c.d}SetupExchangeStep2
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageSetExchangeStep2(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SetupExchangeStep2");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Manage/a.b.c.d}ExportMessage
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageImportExchangeMessage(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExportMessage");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Manage/a.b.c.d}GetData
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageGetCorrespondentData(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "GetData");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Manage/a.b.c.d}GetCommonNodsData
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageGetCorrespondentNodesCommonData(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "GetCommonNodeData");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Manage/a.b.c.d}GetCorrespondentParams
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageGetCorrespondentAccountingParameters(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "GetCorrespondentParams");
	
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
