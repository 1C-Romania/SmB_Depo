////////////////////////////////////////////////////////////////////////////////
// MessageExchangeOverridable: message exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Get the list of the message handlers,
// which are processed by this information system.
// 
// Parameters:
//  Handlers - ValueTable - see field content in MessageExchange.NewMessageHandlersTable.
// 
Procedure GetMessageChannelHandlers(Handlers) Export
	
	
	
EndProcedure

// Handler of receiving a dynamic list of the endpoints messages.
//
// Parameters:
//  MessageChannel - String - Identifier of the message channel for which it is required to define endpoints.
//  Recipients     - Array  - Array of the endpoints to which the
//                            message should be addressed, must be filled with items type ExchangePlanRef.MessageExchange.
//                            This parameter must be defined in the body of the handler.
//
Procedure MessageRecipients(Val MessageChannel, Recipients) Export
	
	
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of sending and receiving messages.

// Handler of the event during sending the message.
// The handler of this event is called before putting message into the XML stream.
// Handler is called for each outgoing message.
//
// Parameters:
//  MessageChannel - String - Identifier of the message channel to which the message is sent.
//  MessageBody - Arbitrary - The body of the outgoing message. IN the event handler
//                            the message body can be changed, for example supplemented with information.
//
Procedure OnMessageSending(MessageChannel, MessageBody) Export
	
EndProcedure

// Handler of the event during receiving the message.
// The handler of this event is called when receiving message from the XML stream.
// Handler is called for each received message.
//
// Parameters:
//  MessageChannel - String - Identifier of the message channel from which the message was received.
//  MessageBody - Arbitrary - The body of the received message. IN the event handler
//                            the message body can be changed, for example supplemented with information.
//
Procedure OnMessageReceiving(MessageChannel, MessageBody) Export
	
EndProcedure

#EndRegion
