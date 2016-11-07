////////////////////////////////////////////////////////////////////////////////
// CHANNEL HANDLER MESSAGES FOR VERSION 1.0.3.4
//  REMOTE ADMINISTRATION MESSAGE INTERFACE
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns version name space of message interface.
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ManageZonesBackup/" + Version();
	
EndFunction

// Returns message interface version, served by the handler.
Function Version() Export
	
	Return "1.0.2.1";
	
EndFunction

// Returns default type for version messages.
Function BaseType() Export
	
	Return MessagesSaaSReUse.TypeBody();
	
EndFunction

// Processes incoming messages in service model.
//
// Parameters:
//  Message - ObjectXDTO, incoming message,
//  Sender - ExchangePlanRef.MessageExchange, exchange node plan corresponding to the message sender.
//  MessageHandled - Boolean, a flag showing that the message is successfully processed.
//    The value of this parameter shall be set to True if the message was successfully read in this handler.
//
Procedure ProcessSaaSMessage(Val Message, Val Sender, MessageHandled) Export
	
	MessageHandled = True;
	
	Dictionary = MessagesManageBackupInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.MessagePlanZoneBackup(Package()) Then
		PlanAreaArchiving(Message, Sender);
	ElsIf MessageType = Dictionary.MessageCancelZoneBackup(Package()) Then
		CancelBackupAreas(Message, Sender);
	Else
		MessageHandled = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure PlanAreaArchiving(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	MessagesControlBackupCopyImplementation.PlanAreaBackupCreating(
		MessageBody.Zone,
		MessageBody.BackupId,
		MessageBody.Date,
		MessageBody.Forced);
	
EndProcedure

Procedure CancelBackupAreas(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	MessagesControlBackupCopyImplementation.CancelZoneBackupCreating(
		MessageBody.Zone,
		MessageBody.BackupId);
	
EndProcedure

#EndRegion
