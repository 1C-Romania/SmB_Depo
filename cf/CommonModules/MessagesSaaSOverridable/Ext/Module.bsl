////////////////////////////////////////////////////////////////////////////////
// Message channel handler for service model
//  messages, overridable procedures and functions.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Handler of the event during receiving the message.
// The handler of this event is called when receiving message from the XML stream.
// Handler is called for each received message.
//
// Parameters:
//  MessageChannel - String - message channel identifier from which the message was received.
//  MessageBody - Arbitrary - The body of the received message. IN the event handler the
//    message body can be changed, for example supplemented with information.
//
Procedure OnMessageReceiving(MessageChannel, MessageBody, MessageObject) Export
	
EndProcedure

// Handler of the event during sending the message.
// The handler of this event is called before putting message into the XML stream.
// Handler is called for each outgoing message.
//
// Parameters:
//  MessageChannel - String - message channel identifier to which the message is sent.
//  MessageBody - Arbitrary - sent message body. IN the event handler
//    the message body can be changed, for example supplemented with information.
//
Procedure OnMessageSending(MessageChannel, MessageBody, MessageObject) Export
	
EndProcedure

// The procedure is called when starting the processing of incoming message.
//
// Parameters:
//  Message - XDTODataObject - incoming message,
//  Sender - ExchangePlanRef.MessageExchange - exchange plan
//    node corresponding to the infobase which sent the message.
//
Procedure MessageOnProcessStart(Val Message, Val Sender) Export
	
EndProcedure

// Procedure is called after processing the incoming message.
//
// Parameters:
//  Message - XDTODataObject - incoming message,
//  Sender - ExchangePlanRef.MessageExchange - exchange plan
//    node corresponding to the infobase which sent the message,
//  MessageHandled - Boolean, flag showing that the message was successfully processed. If
//    value is set to False - an exception will be thrown after execution of this procedure. IN this procedure
//    this parameter value can be changed.
//
Procedure AfterMessageProcessing(Val Message, Val Sender, MessageHandled) Export
	
EndProcedure

// Procedure is called when there is an error in message processor.
//
// Parameters:
//  Message - XDTODataObject - incoming message,
//  Sender - ExchangePlanRef.MessageExchange - exchange plan
//    node corresponding to the infobase which sent the message.
//
Procedure MessageOnProcessError(Val Message, Val Sender) Export
	
EndProcedure

#EndRegion
