#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	MessageChannel = Description;
	
	BodyContent = MessageBody.Get();
	
	// StandardSubsystems.SaaS.BasicFunctionalitySaaS
	MessagesSaaS.BeforeMessageSending(MessageChannel, BodyContent);
	// End StandardSubsystems.SaaS.BasicFunctionalitySaaS
	
	MessageBody = New ValueStorage(BodyContent);
	
EndProcedure

#EndRegion

#EndIf