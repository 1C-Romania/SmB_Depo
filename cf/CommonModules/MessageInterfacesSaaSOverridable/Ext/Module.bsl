////////////////////////////////////////////////////////////////////////////////
// Subsystem "Message interfaces in service
//  model", overridable procedures and functions.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Fills the transferred array with common modules which
//  are the handlers of the received messages interfaces.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure FillReceivedMessageHandlers(ArrayOfHandlers) Export
	
EndProcedure

// Fills the transferred array with common modules which
//  are the handlers of sent messages interfaces.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure FillSendingMessageHandlers(ArrayOfHandlers) Export
	
EndProcedure

// The procedure is called when defining the messages interface
//  version which is supported both by IB-correspondent and current IB. IN this procedure it is assumed to implement
//  the mechanisms supporting the reverse compatibility with older versions of IB-correspondents.
//
// Parameters:
//  InterfaceMessages - String, the name of the software message interface for which the version is defined.
//  ConnectionParameters - structure, the parameters of connection to IB-correspondent.
//  RecipientPresentation - String, the presentation of IB-correspondent.
//  Result - String, defined version. You can change the value of this parameter in this procedure.
//
Procedure OnDeterminingVersionOfCorrespondingInterface(Val InterfaceMessages, Val ConnectionParameters, Val RecipientPresentation, Result) Export
	
EndProcedure

#EndRegion
