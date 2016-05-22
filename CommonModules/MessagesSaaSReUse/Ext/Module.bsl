
#Region ProgramInterface

// Returns XDTO type - message.
//
// Returns:
//  XDTOObjectType - message type.
//
Function TypeMessage() Export
	
	Return XDTOFactory.Type(MessagesSaaSReUse.MessagePackage(), "Message");
	
EndFunction

// Returns type which is basic for all
// message body types in service model.
//
// Returns:
//  XDTOObjectType - base type of message bodies in service model.
//
Function TypeBody() Export
	
	Return XDTOFactory.Type(MessagesSaaSReUse.MessagePackage(), "Body");
	
EndFunction

// Returns type which is basic for all message body types belonging to data areas in service model.
//
// Returns:
//  XDTOObjectType - base type of data area message bodies in service model.
//
Function TypeAreaBody() Export
	
	Return XDTOFactory.Type(MessagesSaaSReUse.MessagePackage(), "ZoneBody");
	
EndFunction

// Returns type which is basic for all message body types sending from data areas with area authentication in service model.
//
// Returns:
//  XDTOObjectType - base type of data area message bodies
// with authentication in service model.
//
Function TypeAuthenticatedZoneBody() Export
	
	Return XDTOFactory.Type(MessagesSaaSReUse.MessagePackage(), "AuthenticatedZoneBody");
	
EndFunction

// Returns type - message heading.
//
// Returns:
//  XDTOObjectType - type message heading in service model.
//
Function TypeMessageTitle() Export
	
	Return XDTOFactory.Type(MessagesSaaSReUse.MessagePackage(), "Header");
	
EndFunction

// Returns type - message exchange node in service model.
//
// Returns:
//  XDTOObjectType - type message exchange node in service model.
//
Function TypeMessagesExchangeNode() Export
	
	Return XDTOFactory.Type(MessagesSaaSReUse.MessagePackage(), "Node");
	
EndFunction

// Returns the XDTO objects types
// that are contained in the given package, message type remote administration.
//
// Parameters:
//  PackageURL - String - XDTO package URI, from which the
//   message types are to be obtained.
//
// Returns:
//  FixedArray(XDTOObjectType) - message types found in the package.
//
Function GetPackageMessageTypes(Val PackageURL) Export
	
	BaseType = MessagesSaaSReUse.TypeBody();
	Result = MessageInterfacesSaaS.GetPackageMessageTypes(PackageURL, BaseType);
	Return New FixedArray(Result);
	
EndFunction

// Returns the names of the message channels from the specified package.
//
// Parameters:
//  PackageURL - String - XDTO package URI, from which the
//   message types are to be obtained.
//
// Returns:
//  FixedArray(String) - channel names that are found in the package.
//
Function GetPackageChannels(Val PackageURL) Export
	
	Result = New Array;
	
	PackageMessageTypes = 
		MessagesSaaSReUse.GetPackageMessageTypes(PackageURL);
	
	For Each MessageType IN PackageMessageTypes Do
		Result.Add(MessagesSaaS.ChannelNameByMessageType(MessageType));
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

// Returns uri of message package with base types.
//
// Returns:
// Row.
//
Function MessagePackage() Export
	
	Return "http://www.1c.ru/SaaS/Messages";
	
EndFunction

#EndRegion
