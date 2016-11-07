#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	// Records set modification is prohibited for not shared nodes in separation mode.
	DataExchangeServer.RunControlRecordsUndividedData(Filter.InfobaseNode.Value);
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
