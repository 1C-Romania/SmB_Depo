////////////////////////////////////////////////////////////////////////////////
// ADDITIONAL REPORTS AND DATA PROCESSORS PERMISSION INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// Returns the namespace of the current (used by calling code) version of message interface.
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/" + Version();
	
EndFunction

// Returns the current (used by calling code) version of message interface.
Function Version() Export
	
	Return "1.0.0.1";
	
EndFunction

// Returns the name of the messages application interface.
Function ApplicationInterface() Export
	
	Return "ApplicationExtensionsPermissions";
	
EndFunction

// Registers the supported versions of messages interface.
//
// Parameters:
//  SupportedVersionStructure - structure:
//    Key - name of the application interface.
//    Value - array of supported versions.
//
Procedure RegisterInterface(Val SupportedVersionStructure) Export
	
	VersionArray = New Array;
	VersionArray.Add("1.0.0.1");
	SupportedVersionStructure.Insert(ApplicationInterface(), VersionArray);
	
EndProcedure

// Registers message handlers as handlers of message exchange channel.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure MessageChanelProcessors(Val ArrayOfHandlers) Export
	
EndProcedure

// Returns the action type identifier corresponding to a call for configuration method.
//
Function TypeActionsCallConfigurationMethod() Export
	
	Return "MethodOfConfiguration"; // Not localized
	
EndFunction

// Returns the action type identifier corresponding to a call for the data processor method.
//
Function TypeActionsCallMethodDataProcessors() Export
	
	Return "MethodDataProcessors"; // Not localized
	
EndFunction

// Returns the parameter type identifier corresponding to the launch key.
//
Function TypeOfKeyParameterSession() Export
	
	Return "SessionKey"; // Not localized
	
EndFunction

// Returns the parameter type identifier corresponding to the fixed value.
//
Function TypeOfValueParameter() Export
	
	Return "FixedValue"; // Not localized
	
EndFunction

// Returns the parameter type identifier corresponding to the saved value.
//
Function TypeOfParameterValueToBeStored() Export
	
	Return "ValueToStore"; // Not localized
	
EndFunction

// Returns the parameter type identifier corresponding to the saved value collection.
//
Function TypeParameterValuesAreSavedCollection() Export
	
	Return "CollectionSavingValues"; // Not localized
	
EndFunction

// Returns the parameter type identifier corresponding to the command completion parameter.
//
Function TypeParameterCommandsPerformParameter() Export
	
	Return "ParameterCommandsRun"; // Not localized
	
EndFunction

// Returns the parameter type identifier corresponding to the function objects collection.
//
Function TypeParameterObjectsAssigned() Export
	
	Return "DestinationObjects"; // Not localized
	
EndFunction

// Constructor of an empty values table that is
// used as a description for the script in a safe mode.
//
// Return value: ValuesTable.
//
Function NewScript() Export
	
	Result = New ValueTable();
	Result.Columns.Add("ActionKind", New TypeDescription("String"));
	Result.Columns.Add("MethodName", New TypeDescription("String"));
	Result.Columns.Add("Parameters", New TypeDescription("ValueTable"));
	Result.Columns.Add("SaveResult", New TypeDescription("String"));
	
	Return Result;
	
EndFunction

// Adds to the data processor completion script in safe
// mode the step containing configuration method.
//
// Parameters:
//  Script, ValuesTable, structure of columns should match the returned result.
//    Function
//  NewScript(),  MethodName - String, configuration method name the call of
//    which is
//  assumed at the script execution stage, SaveResult - String, name for the saved value script,
//    in which method result will be saved, method that is passed as the MethodName parameter value.
//
// Return value: StringValuesTable.
//
Function AddConfigurationMethod(Script, Val MethodName, Val SaveResult = "") Export
	
	Return AddStage(Script, TypeActionsCallConfigurationMethod(), MethodName, SaveResult);
	
EndFunction

// Adds to the script data processor in safe mode
// script step containing data processor method.
//
// Parameters:
//  Script, ValuesTable, structure of columns should match the returned result.
//    Function
//  NewScript(),  MethodName - String, configuration method name the call of
//    which is
//  assumed at the script execution stage, SaveResult - String, name for the saved value script,
//    in which method result will be saved, method that is passed as the MethodName parameter value.
//
// Return value: StringValuesTable.
//
Function AddMethodOfProcessings(Script, Val MethodName, Val SaveResult = "") Export
	
	Return AddStage(Script, TypeActionsCallMethodDataProcessors(), MethodName, SaveResult);
	
EndFunction

// Constructor of an empty values table that
// is used as a description of items parameters of the script in a safe mode.
//
// Return value: ValuesTable.
//
Function NewParametersTable() Export
	
	Result = New ValueTable();
	Result.Columns.Add("Kind", New TypeDescription("String"));
	Result.Columns.Add("Value");
	
	Return Result;
	
EndFunction

// Adds a startup key of the current data processors to the parameter table.
//
// Parameters:
//  stage - StringValuesTable returned
//    by AddConfigurationMethod or AddDataProcessorMethod methods.
//
Procedure AddSessionKey(stage) Export
	
	AddParameter(stage, TypeOfKeyParameterSession());
	
EndProcedure

// Adds a fixed value to the parameter table.
//
// Parameters:
//  stage - StringValuesTable, returned by AddConfigurationMethod methods.
//    or
//  AddDataProcessorMethod, Value - Arbitrary, fixed value.
//
Procedure AddValue(stage, Val Value) Export
	
	AddParameter(stage, TypeOfValueParameter(), Value);
	
EndProcedure

// Adds a fixed value to the parameter table.
//
// Parameters:
//  stage - StringValuesTable, returned by AddConfigurationMethod methods.
//    or
//  AddDataProcessorMethod, SavedValue - String, variable name of the value saved in the script.
//
Procedure AddStoredValue(stage, Val ValueToStore) Export
	
	AddParameter(stage, TypeOfParameterValueToBeStored(), ValueToStore);
	
EndProcedure

// Adds a stored value collection to the parameter table.
//
// Parameters:
//  stage - StringValuesTable returned
//    by AddConfigurationMethod or AddDataProcessorMethod methods.
//
Procedure AddCollectionOfSavedValues(stage) Export
	
	AddParameter(stage, TypeParameterValuesAreSavedCollection());
	
EndProcedure

// Adds a parameter of running the command to the parameter table.
//
// Parameters:
//  stage - StringValuesTable, returned by AddConfigurationMethod methods.
//    or
//  AddDataProcessorMethod, ParameterName - String, command parameter name.
//
Procedure AddParameterCommandsExecution(stage, Val ParameterName) Export
	
	AddParameter(stage, TypeParameterCommandsPerformParameter(), ParameterName);
	
EndProcedure

// Adds an object destination collection to the parameter table.
//
// Parameters:
//  stage - StringValuesTable returned
//    by AddConfigurationMethod or AddDataProcessorMethod methods.
//
Procedure AddDestinationObject(stage) Export
	
	AddParameter(stage, TypeParameterObjectsAssigned());
	
EndProcedure

// Returns type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}CreateComObject
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeCreatingCOMObject(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "CreateComObject");
	
EndFunction

// Returns object {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}CreateComObject
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTODataObject
//
Function PermissionCreatingCOMObject(Val ProgId, Val UsingPackage = Undefined) Export
	
	Type = TypeCreatingCOMObject(UsingPackage);
	Resolution = XDTOFactory.Create(Type);
	Resolution.ProgId = ProgId;
	
	Return Resolution;
	
EndFunction

// Returns type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}AttachAddin
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeOfConnectionOfExternalComponents(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "AttachAddin");
	
EndFunction

// Returns object {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}AttachAddin
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTODataObject
//
Function PermissionConnectionOfExternalComponentsOfGeneralTemplateConfiguration(Val CommonTemplateName, Val UsingPackage = Undefined) Export
	
	Type = TypeOfConnectionOfExternalComponents(UsingPackage);
	Resolution = XDTOFactory.Create(Type);
	Resolution.TemplateName = "CommonTemplate." + CommonTemplateName;
	
	Return Resolution;
	
EndFunction

// Returns object {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}AttachAddin
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTODataObject
//
Function PermissionConnectionOfExternalComponentsFromTemplateConfiguration(Val MetadataObject, Val TemplateName, Val UsingPackage = Undefined) Export
	
	Type = TypeOfConnectionOfExternalComponents(UsingPackage);
	Resolution = XDTOFactory.Create(Type);
	Resolution.TemplateName = MetadataObject.FullName() + ".Template" + TemplateName;
	
	Return Resolution;
	
EndFunction

// Returns type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}GetFileFromExternalSoftware
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function GetFileTypeFromExternalObject(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "GetFileFromExternalSoftware");
	
EndFunction

// Returns object {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}GetFileFromExternalSoftware
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTODataObject
//
Function PermissionGetFileFromExternalObject(Val UsingPackage = Undefined) Export
	
	Type = GetFileTypeFromExternalObject(UsingPackage);
	Resolution = XDTOFactory.Create(Type);
	
	Return Resolution;
	
EndFunction

// Returns type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}SendFileToExternalSoftware
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeFileTransferIntoExternalObject(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SendFileToExternalSoftware");
	
EndFunction

// Returns object {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}SendFileToExternalSoftware
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTODataObject
//
Function PermissionFileTransferIntoExternalObject(Val UsingPackage = Undefined) Export
	
	Type = TypeFileTransferIntoExternalObject(UsingPackage);
	Resolution = XDTOFactory.Create(Type);
	
	Return Resolution;
	
EndFunction

// Returns type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}GetFileFromInternet
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function GetDataTypeOfInternet(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "GetFileFromInternet");
	
EndFunction

// Returns object {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}GetFileFromInternet
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTODataObject
//
Function PermissionDataGetFromInternet(Val Protocol, Val Server, Val Port, Val UsingPackage = Undefined) Export
	
	Type = GetDataTypeOfInternet(UsingPackage);
	Resolution = XDTOFactory.Create(Type);
	Resolution.Protocol = Upper(Protocol);
	Resolution.Host = Server;
	Resolution.Port = Port;
	
	Return Resolution;
	
EndFunction

// Returns type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}SendFileToInternet
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeOfTransferDataOnInternet(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SendFileToInternet");
	
EndFunction

// Returns object {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}SendFileToInternet
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTODataObject
//
Function PermissionTransferDataToInternet(Val Protocol, Val Server, Val Port, Val UsingPackage = Undefined) Export
	
	Type = TypeOfTransferDataOnInternet(UsingPackage);
	Resolution = XDTOFactory.Create(Type);
	Resolution.Protocol = Upper(Protocol);
	Resolution.Host = Server;
	Resolution.Port = Port;
	
	Return Resolution;
	
EndFunction

// Returns type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}SoapConnect
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypeWSConnection(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "SoapConnect");
	
EndFunction

// Returns object {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}SoapConnect
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTODataObject
//
Function PermissionWSConnection(Val WSDLAddress, Val UsingPackage = Undefined) Export
	
	Type = TypeWSConnection(UsingPackage);
	Resolution = XDTOFactory.Create(Type);
	Resolution.WsdlDestination = WSDLAddress;
	
	Return Resolution;
	
EndFunction

// Returns type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}DocumentPosting
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function TypePostingDocuments(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "DocumentPosting");
	
EndFunction

// Returns object {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}DocumentPosting
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTODataObject
//
Function PermissionPostingDocuments(Val MetadataObject, Val WriteMode, Val UsingPackage = Undefined) Export
	
	Type = TypePostingDocuments(UsingPackage);
	Resolution = XDTOFactory.Create(Type);
	Resolution.DocumentType = MetadataObject.FullName();
	If WriteMode = DocumentWriteMode.Posting Then
		Resolution.Action = "Posting";
	Else
		Resolution.Action = "UndoPosting";
	EndIf;
	
	Return Resolution;
	
EndFunction

// Returns type {http://www.1c.ru/1CFresh/ApplicationExtensions/Core/a.b.c.d}InternalFileHandler
//
// Parameters:
//  UsingPackage - String, namespace of the message interface version
//    for which the type of message is received.
//
// Returns:
//  XDTOType
//
Function ParameterTransferredFile(Val UsingPackage = Undefined) Export
	
	Return CreateMessageType(UsingPackage, "InternalFileHandler");
	
EndFunction

// Returns a value corresponding to any limiter
// value (*) when registring the permissions requested by the additional data processor.
//
// Return value: Not specified.
//
Function AnyValue() Export
	
	Return Undefined;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Function CreateMessageType(Val UsingPackage, Val Type)
		
	If UsingPackage = Undefined Then
		UsingPackage = Package();
	EndIf;
	
	Return XDTOFactory.Type(UsingPackage, Type);
	
EndFunction

Function AddStage(Script, Val StageKind, Val MethodName, Val SaveResult = "")
	
	stage = Script.Add();
	stage.ActionKind = StageKind;
	stage.MethodName = MethodName;
	stage.Parameters = NewParametersTable();
	If Not IsBlankString(SaveResult) Then
		stage.SaveResult = SaveResult;
	EndIf;
	
	Return stage;
	
EndFunction

Procedure AddParameter(stage, Val ParameterKind, Val Value = Undefined)
	
	Parameter = stage.Parameters.Add();
	Parameter.Type = ParameterKind;
	If Value <> Undefined Then
		Parameter.Value = Value;
	EndIf;
	
EndProcedure

// Converts the permissions from 2.1.3 format in the 2.2.2 format.
//
Function ConvertVersionPermissions_2_1_3_InVersionPermissions_2_2_2(Val AdditionalReportOrDataProcessor, Val permissions) Export
	
	Result = New Array();
	
	// If data processor have commands that are script - add rights to work with
	// temporary files catalog.
	
	FilterScripts = New Structure("StartVariant", Enums.AdditionalDataProcessorsCallMethods.ScriptInSafeMode);
	ThereAreScripts = AdditionalReportOrDataProcessor.Commands.FindRows(FilterScripts).Count() > 0;
	If ThereAreScripts Then
		Result.Add(WorkInSafeMode.PermissionToUseTemporaryFilesDirectory(True, True));
	EndIf;
	
	// Convert the permissions in the notation "extensions" of the safe mode.
	For Each Resolution IN permissions Do
		
		If Resolution.Type() = GetDataTypeOfInternet(Package()) Then
			
			Result.Add(
				WorkInSafeMode.PermissionForWebsiteUse(
					Resolution.Protocol,
					Resolution.Host,
					Resolution.Port));
			
		ElsIf Resolution.Type() = TypeOfTransferDataOnInternet(Package()) Then
			
			Result.Add(
				WorkInSafeMode.PermissionForWebsiteUse(
					Resolution.Protocol,
					Resolution.Host,
					Resolution.Port));
			
		ElsIf Resolution.Type() = TypeWSConnection(Package()) Then
			
			URLStructure = CommonUseClientServer.URLStructure(Resolution.WsdlDestination);
			
			Result.Add(
				WorkInSafeMode.PermissionForWebsiteUse(
					URLStructure.Schema,
					URLStructure.ServerName,
					Number(URLStructure.Port)));
			
		ElsIf Resolution.Type() = TypeCreatingCOMObject(Package()) Then
			
			Result.Add(
				WorkInSafeMode.PermissionForCOMClassCreation(
					Resolution.ProgId,
					COMClassIdentifierInBackwardCompatibilityMode(Resolution.ProgId)));
			
		ElsIf Resolution.Type() = TypeOfConnectionOfExternalComponents(Package()) Then
			
			Result.Add(
				WorkInSafeMode.PermissionToUseExternalComponent(
					Resolution.TemplateName));
			
		ElsIf Resolution.Type() = GetFileTypeFromExternalObject(Package()) Then
			
			Result.Add(
				WorkInSafeMode.PermissionToUseTemporaryFilesDirectory(True, True));
			
		ElsIf Resolution.Type() = TypeFileTransferIntoExternalObject(Package()) Then
			
			Result.Add(
				WorkInSafeMode.PermissionToUseTemporaryFilesDirectory(True, True));
			
		ElsIf Resolution.Type() = TypePostingDocuments(Package()) Then
			
			Result.Add(WorkInSafeMode.PermissionToUsePrivelegedMode());
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function COMClassIdentifierInBackwardCompatibilityMode(Val ProgId)
	
	SupportedIdentifiers = COMClassesIdentifiersInBackwardCompatibilityMode();
	CLSID = SupportedIdentifiers.Get(ProgId);
	
	If CLSID = Undefined Then
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Permission to use the COM class %1 can not be given to the additional data processor that runs in backward compatibility mode with permission mechanism implemented in the version SSL 2.1.3."
"To use the COM class, it is required to process additional data processor to work without backward compatibility mode';ru='Разрешение на использование COM-класса %1 не может быть предоставлено дополнительной обработке, работающей в режиме обратной совместимости с механизмом разрешений, реализованным в версии БСП 2.1.3."
"Для использования COM-класса требуется переработать дополнительную обработку для работы без режима обратной совместимости'"),
				  ProgId
		);
		
	Else
		
		Return CLSID;
		
	EndIf;
	
EndFunction

Function COMClassesIdentifiersInBackwardCompatibilityMode()
	
	Result = New Map();
	
	// V83.ComConnector
	Result.Insert(CommonUseClientServer.COMConnectorName(), CommonUse.COMConnectorIdentifier(CommonUseClientServer.COMConnectorName()));
	// Word.Application
	Result.Insert("Word.Application", "000209FF-0000-0000-C000-000000000046");
	// Excel.Application
	Result.Insert("Excel.Application", "00024500-0000-0000-C000-000000000046");
	
	Return Result;
	
EndFunction

#EndRegion
