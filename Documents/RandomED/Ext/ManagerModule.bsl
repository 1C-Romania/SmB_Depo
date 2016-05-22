////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Info base update

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Handler update
// BED 1.1.14.2 Fills the document type
//
Procedure FillDocumentType() Export
	
	ItemRef = Documents.RandomED.Select();
	
	While ItemRef.Next() Do
		If Not ValueIsFilled(ItemRef.DocumentType) Then
			Try
				ItemObject = ItemRef.GetObject();
				ItemObject.DocumentType = Enums.EDTypes.Other;
				InfobaseUpdate.WriteObject(ItemObject);
			Except
			EndTry;
		EndIf;
	EndDo;
	
EndProcedure

Function ObjectStatusReady(Object) Export
	
	Result = (Object.DocumentStatus = Enums.EDStatuses.ConfirmationPrepared
		OR Object.DocumentStatus = Enums.EDStatuses.PreparedToSending
		OR Object.DocumentStatus = Enums.EDStatuses.DigitallySigned);
		
	Return Result;
	
EndFunction

Function ObjectStatusIsNotReady(Object) Export
	
	Result = (Object.DocumentStatus = Enums.EDStatuses.Received
		OR Object.DocumentStatus = Enums.EDStatuses.Created);
		
	Return Result;
		
EndFunction

Function ObjectStatusPassed(Object) Export
	
	Result = (Object.DocumentStatus = Enums.EDStatuses.TransferedToOperator
		OR Object.DocumentStatus = Enums.EDStatuses.Sent
		OR Object.DocumentStatus = Enums.EDStatuses.ConfirmationReceived
		OR Object.DocumentStatus = Enums.EDStatuses.ConfirmationSent
		OR Object.DocumentStatus = Enums.EDStatuses.ConfirmationDelivered);
		
	Return Result;
	
EndFunction

Function ObjectStatusRejected(Object) Export
	
	Result = (Object.DocumentStatus = Enums.EDStatuses.Rejected
		OR Object.DocumentStatus = Enums.EDStatuses.RejectedByReceiver);
		
	Return Result;
	
EndFunction

Function YouCanSign(EDObject) Export
	
	DirectionOutgoing = (EDObject.EDDirection = Enums.EDDirections.Outgoing);
	ConfirmationRequired = EDObject.FileOwner.ConfirmationRequired;
	StatusPassed = ObjectStatusPassed(EDObject.FileOwner);
	StatusRejected = ObjectStatusRejected(EDObject.FileOwner);
	
	Result = (NOT (StatusPassed OR StatusRejected) AND (DirectionOutgoing OR ConfirmationRequired));
	
	Return Result;
	
EndFunction

Function YouCanSend(EDObject) Export
	
	DirectionOutgoing = (EDObject.EDDirection = Enums.EDDirections.Outgoing);
	ConfirmationRequired = EDObject.FileOwner.ConfirmationRequired;
	StatusReady = ObjectStatusReady(EDObject.FileOwner);
	
	Result = (StatusReady AND (DirectionOutgoing OR ConfirmationRequired));
	
	Return Result;
	
EndFunction


#EndIf