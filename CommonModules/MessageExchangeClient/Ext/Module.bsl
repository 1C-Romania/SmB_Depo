////////////////////////////////////////////////////////////////////////////////
// MessageExchangeClient: the mechanism of the exchange messages.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Executes sending and receiving of system messages.
// 
Procedure SendAndReceiveMessages() Export
	
	Status(NStr("en = 'Messages are being sent and received.'"),,
			NStr("en = 'Please wait...'"), PictureLib.Information32);
	
	Cancel = False;
	
	MessageExchangeServerCall.SendAndReceiveMessages(Cancel);
	
	If Cancel Then
		
		Status(NStr("en = 'Errors occurred when sending and receiving the messages!'"),,
				NStr("en = 'Use the event log to diagnose the errors.'"), PictureLib.Error32);
		
	Else
		
		Status(NStr("en = 'Sending and receiving of messages has been successfully completed.'"),,, PictureLib.Information32);
		
	EndIf;
	
	Notify(EventNameMessagesSendingAndReceivingPerformed());
	
EndProcedure

// Only for internal use.
//
// Returns:
// Row. 
//
Function EndPointAddedEventName() Export
	
	Return "MessageExchange.EndPointAdded";
	
EndFunction

// Only for internal use.
//
// Returns:
// Row. 
//
Function EventNameMessagesSendingAndReceivingPerformed() Export
	
	Return "MessageExchange.SendAndReceiveExecuted";
	
EndFunction

// Only for internal use.
//
// Returns:
// Row. 
//
Function EndPointFormClosedEventName() Export
	
	Return "MessageExchange.EndPointFormClosed";
	
EndFunction

// Only for internal use.
//
// Returns:
// Row. 
//
Function EventNameLeadingEndPointSet() Export
	
	Return "MessageExchange.LeadingEndPointSet";
	
EndFunction

#EndRegion
