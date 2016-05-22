////////////////////////////////////////////////////////////////////////////////
// Subsystem "Exchange of messages".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Executes sending and receiving of system messages.
//
// Parameters:
//  Cancel - Boolean. Cancelation flag. Rises in case of errors when executing the operation.
//
Procedure SendAndReceiveMessages(Cancel) Export
	
	DataExchangeServer.CheckIfExchangesPossible();
	
	MessageExchangeInternal.SendAndReceiveMessages(Cancel);
	
EndProcedure

#EndRegion
