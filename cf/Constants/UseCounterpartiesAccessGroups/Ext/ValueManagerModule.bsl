#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AccessManagement.RefreshAllowedValuesOnChangeAccessKindsUsage();
	
EndProcedure

#EndRegion

#EndIf