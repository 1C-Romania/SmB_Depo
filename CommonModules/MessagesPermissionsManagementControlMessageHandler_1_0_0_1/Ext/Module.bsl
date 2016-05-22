////////////////////////////////////////////////////////////////////////////////
// MESSAGE CHANNELS HANDLER FOR VERSION 1.0.3.5
//  OF MESSAGE INTERFACE FOR REMOTE ADMINISTRATION
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// Returns namespace for message interface version
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/Application/Permissions/Control/" + Version();
	
EndFunction

// Returns a message interface version served by the handler
Function Version() Export
	
	Return "1.0.0.1";
	
EndFunction

// Returns default type for version messages
Function BaseType() Export
	
	Return MessagesSaaSreuse.TypeBody();
	
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
	
	Dictionary = MessagesPermissionsManagementControlInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.MessageQueryOnInfobasePermissionsProcessed(Package()) Then
		UndividedSessionQueryProcessed(Message, Sender);
	ElsIf MessageType = Dictionary.MessageQueryOnDataAreasPermissionsProcessed(Package()) Then
		SplitSessionQueryProcessed(Message, Sender);
	Else
		MessageHandled = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure UndividedSessionQueryProcessed(Val Message, Val Sender)
	
	BeginTransaction();
	
	Try
		
		For Each QueryProcessingResult IN Message.Body.ProcessingResultList.ProcessingResult Do
			
			MessagesPermissionsManagementControlSales.UndividedSessionQueryProcessed(
				QueryProcessingResult.RequestUUID,
				MessagesPermissionsManagementControlInterface.QueryProcessingResultTypesDictionary()[QueryProcessingResult.ProcessingResultType],
				QueryProcessingResult.RejectReason);
				
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

Procedure SplitSessionQueryProcessed(Val Message, Val Sender)
	
	BeginTransaction();
	
	Try
		
		For Each QueryProcessingResult IN Message.Body.ProcessingResultList.ProcessingResult Do
			
			MessagesPermissionsManagementControlSales.SplitSessionQueryProcessed(
				QueryProcessingResult.RequestUUID,
				MessagesPermissionsManagementControlInterface.QueryProcessingResultTypesDictionary()[QueryProcessingResult.ProcessingResultType],
				QueryProcessingResult.RejectReason);
				
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion
