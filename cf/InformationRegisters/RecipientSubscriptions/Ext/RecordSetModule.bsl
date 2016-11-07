#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Recipient = Filter["Recipient"].Value;
	
	If Recipient <> Undefined
		AND Recipient = MessageExchangeInternal.ThisNode() Then
		
		Recipients = MessageExchangeInternal.AllRecipients();
		
		DataExchange.Recipients.Clear();
		
		For Each Node IN Recipients Do
			
			DataExchange.Recipients.Add(Node);
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf