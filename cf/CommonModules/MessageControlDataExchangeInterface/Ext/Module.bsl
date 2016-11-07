////////////////////////////////////////////////////////////////////////////////
// DATA EXCHANGE CONTROL MESSAGE INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the namespace of current version (used by the calling code) of message interface
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/Exchange/Control";
	
EndFunction

// Returns current version (used by the calling code) of message interface
Function Version() Export
	
	Return "2.1.2.1";
	
EndFunction

// Returns the name of the messages applicationming interface
Function ProgramInterface() Export
	
	Return "ExchangeControl";
	
EndFunction

// Registers message handlers as handlers of message exchange channels
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessageChanelProcessors(Val ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessagesExchangeDataControlHandlerMessages_2_1_2_1);
	
EndProcedure

// Registers handlers of message translation.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessagesTranslationHandlers(Val ArrayOfHandlers) Export
	
EndProcedure

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}SetupExchangeStep1Completed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageExchangeSettingStep1CompletedSuccessfully(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SetupExchangeStep1Completed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}SetupExchangeStep2Completed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageExchangeSettingStep2CompletedSuccessfully(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SetupExchangeStep2Completed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}SetupExchangeStep1Failed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageExchangeSettingErrorStep1(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SetupExchangeStep1Failed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}SetupExchangeStep2Failed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageExchangeSettingErrorStep2(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SetupExchangeStep2Failed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}ExportMessageCompleted
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageExchangeMessageImportingCompletedSuccessfully(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExportMessageCompleted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}ExportMessageFailed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageExchangeMessageImportingError(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "MessageExportFailed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingDataCompleted
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageCorrespondentDataGettingCompletedSuccessfully(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "GettingDataCompleted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingCommonNodsDataCompleted
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageCorrespondentNodesCommonDataGettingCompletedSuccessfully(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "GettingCommonNodsDataCompleted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingDataFailed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageCorrespondentDataGettingError(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "GettingDataFailed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingCommonNodsDataFailed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageCorrespondentNodesCommonDataGettingError(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "GettingCommonNodsDataFailed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingCorrespondentParamsCompleted
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageCorrespondentAccountingParametersGettingCompletedSuccessfully(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "GettingCorrespondentParamsCompleted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingCorrespondentParamsFailed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageCorrespondentAccountingParametersGettingError(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "GettingCorrespondentParamsFailed");
	
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
