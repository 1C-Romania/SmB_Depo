////////////////////////////////////////////////////////////////////////////////
// Subsystem "Messages interfaces in service models".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns supported versions of message interface
//  that are supported by current infobase.
//
// Parameters:
//  InterfaceName - String, software message interface name.
//
// Returns:
//  Array (items - String), numbers of supported versions in format RR.{P|PP}.ZZ.SS.
//
Function InterfaceVersionsCurrentIB(Val InterfaceName) Export
	
	Result = Undefined;
	
	SenderInterfaces = New Structure;
	RegisterSentMessagesVersions(SenderInterfaces);
	SenderInterfaces.Property(InterfaceName, Result);
	
	If Result = Undefined OR Result.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Current infobase does not support the interface %1!';ru='Текущая информационная база не поддерживает интерфейс %1!'"), InterfaceName);
	Else
		Return Result;
	EndIf;
	
EndFunction

// Returns message interface versions that are supported by IB-reporter.
//
// Parameters:
//  InterfaceMessages - String, software message interface name.
//  ConnectionParameters - structure, the parameters of connection to IB-correspondent.
//  RecipientPresentation - String, the presentation of IB-correspondent.
//  InterfaceOfCurrentDB - String, name of the software
//    interface of the current IB (is used for reverse compatibility with previous versions of SSL).
//
// Returns:
//  String, maximum interface version supported by the IB-correspondent as well as by current IB.
//
Function InterfaceVersionCorrespondent(Val InterfaceMessages, Val ConnectionParameters, Val RecipientPresentation, Val InterfaceOfCurrentDB = "") Export
	
	CorrespondentVersions = CommonUse.GetInterfaceVersions(ConnectionParameters, InterfaceMessages);
	If InterfaceOfCurrentDB = "" Then
		CorrespondentVersion = ChoiceOfCorrespondingVersion(InterfaceMessages, CorrespondentVersions);
	Else
		CorrespondentVersion = ChoiceOfCorrespondingVersion(InterfaceOfCurrentDB, CorrespondentVersions);
	EndIf;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.SaaS.MessageExchange\OnDeterminingVersionOfCorrespondingInterface");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnDeterminingVersionOfCorrespondingInterface(
			InterfaceMessages,
			ConnectionParameters,
			RecipientPresentation,
			CorrespondentVersion);
	EndDo;
	
	MessageInterfacesSaaSOverridable.OnDeterminingVersionOfCorrespondingInterface(
		InterfaceMessages,
		ConnectionParameters,
		RecipientPresentation,
		CorrespondentVersion);
	
	Return CorrespondentVersion;
	
EndFunction

// Returns the names of the message channels from the specified package.
//
// Parameters:
//  PackageURL - String - XDTO package URI, from which the
//   message types are to be obtained.
//  BaseType - XDTOType, base type.
//
// Returns:
//  FixedArray(String) - channel names that are found in the package.
//
Function GetPackageChannels(Val PackageURL, Val BaseType) Export
	
	Result = New Array;
	
	PackageMessageTypes = 
		GetPackageMessageTypes(PackageURL, BaseType);
	
	For Each MessageType IN PackageMessageTypes Do
		Result.Add(MessagesSaaS.ChannelNameByMessageType(MessageType));
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

// Returns the XDTO objects types
// that are contained in the given package, message type remote administration.
//
// Parameters:
//  PackageURL - String - XDTO package URI, from which the
//   message types
//  are to be obtained, BaseType - XDTOType, base type.
//
// Returns:
//  Array(XDTOObjectType) - message types found in the package.
//
Function GetPackageMessageTypes(Val PackageURL, Val BaseType) Export
	
	Result = New Array;
	
	PackageModels = XDTOFactory.ExportXDTOModel(PackageURL);
	
	For Each PackageModel IN PackageModels.package Do
		For Each ObjectTypeModel IN PackageModel.objectType Do
			ObjectType = XDTOFactory.Type(PackageURL, ObjectTypeModel.name);
			If Not ObjectType.Abstract
				AND BaseType.IsDescendant(ObjectType) Then
				
				Result.Add(ObjectType);
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns a fixed array filled with
//  common modules which are the interface handlers of the messages being sent.
//
// Returns:
//  FixedArray.
//
Function GetInterfaceHandlersSentMessages() Export
	
	ArrayOfHandlers = New Array();
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.SaaS.MessageExchange\RegistrationSendingMessageInterfaces");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.RegistrationSendingMessageInterfaces(ArrayOfHandlers);
	EndDo;
	
	MessageInterfacesSaaSOverridable.FillSendingMessageHandlers(
		ArrayOfHandlers);
	
	Return New FixedArray(ArrayOfHandlers);
	
EndFunction

// Returns a fixed array filled with
//  common modules which are the interface handlers of the messages being received.
//
// Returns:
//  FixedArray.
//
Function GetInterfaceHandlersOfMessages() Export
	
	ArrayOfHandlers = New Array();
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.SaaS.MessageExchange\RegistrationOfReceivedMessageInterfaces");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.RegistrationOfReceivedMessageInterfaces(ArrayOfHandlers);
	EndDo;
	
	MessageInterfacesSaaSOverridable.FillReceivedMessageHandlers(
		ArrayOfHandlers);
	
	Return New FixedArray(ArrayOfHandlers);
	
EndFunction

// Returns the compliance of names of the messages software interfaces and their handlers.
//
// Returns:
//  FixedMap:
//    Key - String, name
//    of the software, Value - CommonModule
//
Function GetInterfacesAreSentMessages() Export
	
	Result = New Map();
	ArrayOfHandlers = GetInterfaceHandlersSentMessages();
	For Each Handler IN ArrayOfHandlers Do
		Result.Insert(Handler.Package(), Handler.ProgramInterface());
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

// Returns the compliance of names of the software interfaces and their
//  current versions (the messages of which are created in the calling code).
//
// Returns:
//  FixedMap:
//    Key - String, name of the interface
//    Value - String, version number.
//
Function GetVersionsSentMessages() Export
	
	Result = New Map();
	ArrayOfHandlers = GetInterfaceHandlersSentMessages();
	For Each Handler IN ArrayOfHandlers Do
		Result.Insert(Handler.ProgramInterface(), Handler.Version());
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

// Returns the array of translation handlers for service model messages.
//
// Returns:
//  Array(CommonModule).
//
Function GetTranslationHandlersMessages() Export
	
	Result = New Array();
	
	InterfaceHandlers = GetInterfaceHandlersSentMessages();
	
	For Each HandlerInterface IN InterfaceHandlers Do
		
		TranslationHandlers = New Array();
		HandlerInterface.MessagesTranslationHandlers(TranslationHandlers);
		CommonUseClientServer.SupplementArray(Result, TranslationHandlers);
		
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

#EndRegion

#Region ServiceProgramInterface

// Declares the events of the JobQueue subsystem:
//
// Server events:
//   ReceivedMessageInterfacesRegistration
//   SendingMessageInterfacesRegistration
//   OnDeterminingCorrespondentInterfaceVersion.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Fills the transferred array with common modules which
	//  are the handlers of the received messages interfaces.
	//
	// Parameters:
	//  ArrayOfHandlers - array.
	//
	// Syntax:
	// Procedure RecievedMessageInterfacesRegistration (ProcessorsArray) Export
	//
	// (The same as MessageInterfacesSaaSOverridable.FillReceivedMessageHandlers).
	ServerEvents.Add(
		"StandardSubsystems.SaaS.MessageExchange\RegistrationOfReceivedMessageInterfaces");
	
	// Fills the transferred array with common modules which
	//  are the interface handlers of messages being sent.
	//
	// Parameters:
	//  ArrayOfHandlers - array.
	//
	//
	// Syntax:
	// Procedure SentMessageInterfacesRegistration (ProcessorsArray) Export
	//
	// (The same as MessageInterfacesSaaSOverridable.FillSentMessagesHandlers).
	ServerEvents.Add(
		"StandardSubsystems.SaaS.MessageExchange\RegistrationSendingMessageInterfaces");
	
	// Called when determining the message interface version
	//  supported by IB-correspondent as well as by current IB. IN this procedure it is assumed to implement
	//  the mechanisms supporting the reverse compatibility with older versions of IB-correspondents.
	//
	// Parameters:
	//  InterfaceMessages - String, the name of the software message interface for which the version is defined.
	//  ConnectionParameters - structure, the parameters of connection to IB-correspondent.
	//  RecipientPresentation - String, the presentation of IB-correspondent.
	//  Result - String, defined version. You can change the value of this parameter in this procedure.
	//
	//
	// Syntax:
	// Procedure OnDeterminingCorrespondentInterfaceVersion (Val MessageInterface, Val ConnectionParameters, Val RecipientPresentation, Result) Export
	//
	// (The same as MessageInterfacesSaaSOverridable.OnDeterminingCorrespondentInterfaceVersion).
	ServerEvents.Add(
		"StandardSubsystems.SaaS.MessageExchange\OnDeterminingVersionOfCorrespondingInterface");
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers[
			"StandardSubsystems.SaaS.MessageExchange\OnDefenitionMessagesFeedHandlers"].Add(
				"MessageInterfacesSaaS");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnDefenitionSupportedVersionsOfSoftwareInterfaces"].Add(
			"MessageInterfacesSaaS");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Gets the list of message handlers that handle library subsystems.
// 
// Parameters:
//  Handlers - ValueTable - see field content in MessageExchange.NewMessageHandlersTable.
// 
Procedure OnDefenitionMessagesFeedHandlers(Handlers) Export
	
	InterfaceHandlers = GetInterfaceHandlersOfMessages();
	
	For Each HandlerInterface IN InterfaceHandlers Do
		
		InterfaceChannelsHandlers  = New Array();
		HandlerInterface.MessageChanelProcessors(InterfaceChannelsHandlers);
		
		For Each InterfaceChannelHandler IN InterfaceChannelsHandlers Do
			
			Package = InterfaceChannelHandler.Package();
			BaseType = InterfaceChannelHandler.BaseType();
			
			ChannelNames = GetPackageChannels(Package, BaseType);
			
			For Each ChannelName IN ChannelNames Do
				Handler = Handlers.Add();
				Handler.Channel = ChannelName;
				Handler.Handler = MessagesSaaSMessagesHandler;
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Fills the structure with the arrays of supported
// versions of all subsystems subject to versioning and uses subsystems names as keys.
// Provides the functionality of InterfaceVersion Web-service.
// during the implementation the body of the procedure shall be changed so it will return relevant version sets (see ex.below).
//
// Parameters:
// SupportedVersionStructure - Structure: 
// - Keys = Names of the subsystems. 
// - Values = Arrays of supported version names.
//
// Example of implementation:
//
// // FileTransferServer
// VersionsArray = New Array;
// VersionsArray.Add("1.0.1.1");	
// VersionsArray.Add("1.0.2.1"); 
// SupportedVersionsStructure.Insert("FileTransferServer", VersionsArray);
// // End FileTransferService
//
Procedure OnDefenitionSupportedVersionsOfSoftwareInterfaces(Val SupportedVersionStructure) Export
	
	RegisterTakenMessageVersions(SupportedVersionStructure);
	
EndProcedure

// Fills the sent structure of supported versions
//  by supported versions of recieved messages.
//
// Parameters:
//  SupportedVersionStructure - Structure:
//    Key - subsystem
//    names, Value - arrays of supported versions names.
//
Procedure RegisterTakenMessageVersions(SupportedVersionStructure)
	
	InterfaceHandlers = GetInterfaceHandlersOfMessages();
	
	For Each HandlerInterface IN InterfaceHandlers Do
		
		ChannelHandlers = New Array();
		HandlerInterface.MessageChanelProcessors(ChannelHandlers);
		
		SupportedVersions = New Array();
		
		For Each VersionProcessor IN ChannelHandlers Do
			
			SupportedVersions.Add(VersionProcessor.Version());
			
		EndDo;
		
		SupportedVersionStructure.Insert(
			HandlerInterface.ProgramInterface(),
			SupportedVersions);
		
	EndDo;
	
EndProcedure

// Fills the sent structure of supported versions
//  by supported versions of sent messages.
//
// Parameters:
//  SupportedVersionStructure - Structure:
//    Key - subsystem
//    names, Value - arrays of supported versions names.
//
Procedure RegisterSentMessagesVersions(SupportedVersionStructure)
	
	InterfaceHandlers = GetInterfaceHandlersSentMessages();
	
	For Each HandlerInterface IN InterfaceHandlers Do
		
		TranslationHandlers = New Array();
		HandlerInterface.MessagesTranslationHandlers(TranslationHandlers);
		
		SupportedVersions = New Array();
		
		For Each VersionProcessor IN TranslationHandlers Do
			
			SupportedVersions.Add(VersionProcessor.ResultingVersion());
			
		EndDo;
		
		SupportedVersions.Add(HandlerInterface.Version());
		
		SupportedVersionStructure.Insert(
			HandlerInterface.ProgramInterface(),
			SupportedVersions);
		
	EndDo;
	
EndProcedure

// Chooses an interface version which is
// supported by current infobase as well as by the infobase- - correspondent.
//
// Parameters:
//  Interface - String, message
//  interface name, CorrespondentVersions - Array(String),
//    versions of the message interface that are supported by the infobase - correspondent.
//
Function ChoiceOfCorrespondingVersion(Val Interface, Val CorrespondentVersions)
	
	SenderVersions = InterfaceVersionsCurrentIB(Interface);
	
	SelectedVersion = Undefined;
	
	For Each CorrespondentVersion IN CorrespondentVersions Do
		
		If SenderVersions.Find(CorrespondentVersion) <> Undefined Then
			
			If SelectedVersion = Undefined Then
				SelectedVersion = CorrespondentVersion;
			Else
				SelectedVersion = ?(CommonUseClientServer.CompareVersions(
						CorrespondentVersion, SelectedVersion) > 0, CorrespondentVersion,
						SelectedVersion);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return SelectedVersion;
	
EndFunction

#EndRegion
