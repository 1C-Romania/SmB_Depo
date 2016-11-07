////////////////////////////////////////////////////////////////////////////////
// ADDITIONAL REPORTS MANIFEST INTERFACE HANDLER AND DATA
//  PROCESSOR IN SERVICE MODEL
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Returns the namespace of current version (used by the calling code) of message interface
Function Package(Val Version = "") Export
	
	If IsBlankString(Version) Then
		Version = Version();
	EndIf;
	
	Return "http://www.1c.ru/1cFresh/ApplicationExtensions/Manifest/" + Version;
	
EndFunction

// Returns current version (used by the calling code) of message interface
Function Version() Export
	
	Return "1.0.0.2";
	
EndFunction

// Returns the name of the messages application interface
Function ProgramInterface() Export
	
	Return "ApplicationExtensionsCore";
	
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

// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionAssignmentObject
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeDestinationObject(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExtensionAssignmentObject");
	
EndFunction

// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionAssignmentBase
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeAppointmentBasic(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExtensionAssignmentBase");
	
EndFunction

// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionSubsystemsAssignment
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function SectionPrescriptionType(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExtensionSubsystemsAssignment");
	
EndFunction

// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionCatalogsAndDocumentsAssignment
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypePurposeCatalogsAndDocuments(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExtensionCatalogsAndDocumentsAssignment");
	
EndFunction

// Returns type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionCommand
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeCommand(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExtensionCommand");
	
EndFunction

// Returns type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionReportVariantAssignment
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeReportOptionPurpose(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExtensionReportVariantAssignment");
	
EndFunction

// Returns type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionReportVariant
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeVariantOfReport(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExtensionReportVariant");
	
EndFunction

// Returns type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionCommandSettings
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeSettingsCommands(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExtensionCommandSettings");
	
EndFunction

// Returns type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionManifest
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeManifest(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "ExtensionManifest");
	
EndFunction

// Returns enumeration values match dictionary
//  AdditionalReportsAndDataProcessorsKinds values XDTO-type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionCategory
//
Function DictionaryAdditionalReportAndDataProcessorTypes() Export
	
	Dictionary = New Structure();
	Manager = Enums.AdditionalReportsAndDataProcessorsKinds;
	
	Dictionary.Insert("AdditionalProcessor", Manager.AdditionalInformationProcessor);
	Dictionary.Insert("AdditionalReport", Manager.AdditionalReport);
	Dictionary.Insert("ObjectFilling", Manager.ObjectFilling);
	Dictionary.Insert("Report", Manager.Report);
	Dictionary.Insert("PrintForm", Manager.PrintForm);
	Dictionary.Insert("LinkedObjectCreation", Manager.CreatingLinkedObjects);
	
	Return Dictionary;
	
EndFunction

// Returns enumeration values match dictionary
//  AdditionalDataProcessorsCallMethods values XDTO-type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionStartupType
//
Function DictionaryWaysCallAdditionalReportsAndDataprocessors() Export
	
	Dictionary = New Structure();
	Manager = Enums.AdditionalDataProcessorsCallMethods;
	
	Dictionary.Insert("ClientCall", Manager.CallOfClientMethod);
	Dictionary.Insert("ServerCall", Manager.CallOfServerMethod);
	Dictionary.Insert("FormOpen", Manager.FormOpening);
	Dictionary.Insert("FormFill", Manager.FillForm);
	Dictionary.Insert("SafeModeExtension", Manager.ScriptInSafeMode);
	
	Return Dictionary;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

Function CreateMessageType(Val UsingPackage, Val Type)
		
	If UsingPackage = Undefined Then
		UsingPackage = Package();
	EndIf;
	
	Return XDTOFactory.Type(UsingPackage, Type);
	
EndFunction