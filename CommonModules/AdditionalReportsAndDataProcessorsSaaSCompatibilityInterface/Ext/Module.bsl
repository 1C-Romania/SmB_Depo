////////////////////////////////////////////////////////////////////////////////
// ADDITIONAL REPORTS AND DATA PROCESSORS IN SERVICE MODEL
//  COMPATIBILITY INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Returns the namespace of current version (used by the calling code) of message interface
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/ApplicationExtensions/Compatibility/" + Version();
	
EndFunction

// Returns current version (used by the calling code) of message interface
Function Version() Export
	
	Return "1.0.0.1";
	
EndFunction

// Returns the name of the messages applicationming interface
Function ProgramInterface() Export
	
	Return "ApplicationExtensionsCompatibility";
	
EndFunction

// Registers the supported versions of messages interface
//
// Parameters:
//  SupportedVersionStructure - structure:
//    Key - name of
//    the software interface Value - supported versions array
//
Procedure RegisterInterface(Val SupportedVersionStructure) Export
	
	VersionArray = New Array;
	VersionArray.Add("1.0.0.1");
	SupportedVersionStructure.Insert(ProgramInterface(), VersionArray);
	
EndProcedure

// Registers message handlers as handlers of message exchange channels
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessageChanelProcessors(Val ArrayOfHandlers) Export
	
EndProcedure

// Return type {http://www.1c.ru/1cFresh/ApplicationExtensions/Compatibility/a.b.c.d}CompatibilityObject
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeObjectCompatibility(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "CompatibilityObject");
	
EndFunction

// Return type {http://www.1c.ru/1cFresh/ApplicationExtensions/Compatibility/a.b.c.d}CompatibilityWithConfiguration
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeCompatibilityWithConfiguration(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "CompatibilityWithConfiguration");
	
EndFunction

// Return type {http://www.1c.ru/1cFresh/ApplicationExtensions/Compatibility/a.b.c.d}CompatibilityWithConfigurationVersion
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeCompatibilityWithVersionOfConfiguration(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "CompatibilityWithConfigurationVersion");
	
EndFunction

// Return type {http://www.1c.ru/1cFresh/ApplicationExtensions/Compatibility/a.b.c.d}CompatibilityList
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeTableOfCompatibility(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "CompatibilityList");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

Function CreateMessageType(Val UsingPackage, Val Type)
		
	If UsingPackage = Undefined Then
		UsingPackage = Package();
	EndIf;
	
	Return XDTOFactory.Type(UsingPackage, Type);
	
EndFunction