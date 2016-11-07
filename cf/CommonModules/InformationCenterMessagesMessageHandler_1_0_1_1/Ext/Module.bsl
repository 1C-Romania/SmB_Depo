////////////////////////////////////////////////////////////////////////////////
// HandlerMessagesInformationCenter.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Returns namespace for message interface version
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter/Messages/" + Version();
	
EndFunction

// Returns a message interface version served by the handler
Function Version() Export
	
	Return "1.0.1.1";
	
EndFunction

// Returns default type for version messages
Function BaseType() Export
	
	Return ServiceTechnologyIntegrationWithSSL.TypeBody();
	
EndFunction

// Processes incoming messages in service model
//
// Parameters:
//  Message - ObjectXDTO,
//  incoming message, Sender - ExchangePlanRef.Messaging, exchange plan
//  node, corresponding to message sender MessageProcessed - Boolean, a flag showing that the message is successfully processed. The value of
//    this parameter shall be set as equal to True if the message was successfully read in this handler
//
Procedure ProcessSaaSMessage(Val Message, Val Sender, MessageHandled) Export
	
	MessageHandled = True;
	
	Dictionary = InformationCenterMessagesInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.MessageNotificationsWishes() Then
		AddNotificationOfWish(Message);
	Else
		MessageHandled = False;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

Procedure AddNotificationOfWish(Message)
	
	MessageBody = Message.Body;
	InformationCenterMessagesSales.AddNotificationOfWish(MessageBody);
	
EndProcedure
