#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnWrite(Cancel)
	
	WorkInSafeModeService.OnWriteServiceData(ThisObject);
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Value Then
		
		WorkInSafeModeService.OnSwitchUsingSecurityProfiles();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
