////////////////////////////////////////////////////////////////////////////////
// HANDLER OF MESSAGES INTERFACE FOR PERMISSIONS CONTROL
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// Returns the namespace of current version (used by the calling code) of message interface
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/Application/Permissions/Control/" + Version();
	
EndFunction

// Returns current version (used by the calling code) of message interface
Function Version() Export
	
	Return "1.0.0.1";
	
EndFunction

// Returns the name of the messages application interface
Function ApplicationInterface() Export
	
	Return "ApplicationPermissionsControl";
	
EndFunction

// Returns the name of the messages application interface
Function ProgramInterface() Export
	
	Return "ApplicationPermissionsControl";
	
EndFunction

// Registers message handlers as handlers of message exchange channels
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessageChanelProcessors(Val ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessagesPermissionsManagementControlMessageHandler_1_0_0_1);
	
EndProcedure

// Registers handlers of message translation.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessagesTranslationHandlers(Val ArrayOfHandlers) Export
	
	
	
EndProcedure

// Returns message type {http://www.1c.ru/1CFresh/Application/Permissions/Control/a.b.c.d}InfobasePermissionsRequestProcessed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageQueryOnInfobasePermissionsProcessed(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "InfobasePermissionsRequestProcessed");
	
EndFunction

// Returns message type {http://www.1c.ru/1CFresh/Application/Permissions/Control/a.b.c.d}ApplicationPermissionsRequestProcessed
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function MessageQueryOnDataAreasPermissionsProcessed(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ApplicationPermissionsRequestProcessed");
	
EndFunction

// Dictionary for conversion of scheme
// enumeration items {http:www.1c.ru/1cFresh/Application/Permissions/Control/1.0.0.1}
// PermissionRequestProcessingResultTypes items in enumeration items QueryProcessingResultsForExternalResourcesUseSaaS.
//
// Return value - Structure:
//  * Key - name of the enumeration
//  item in the scheme, *Value - Enumeration value in metadata.
//
Function QueryProcessingResultTypesDictionary() Export
	
	Result = New Structure();
	
	Result.Insert("Approved", Enums.QueryProcessingResultsForExternalResourcesUseSaaS.QueryApproved);
	Result.Insert("Rejected", Enums.QueryProcessingResultsForExternalResourcesUseSaaS.QueryRejected);
	
	Return New FixedStructure(Result);
	
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
