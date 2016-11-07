#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnWrite(Cancel)
	
	WorkInSafeModeService.OnWriteServiceData(ThisObject);
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Value Then
		
		DataProcessors.PermissionSettingsForExternalResourcesUse.ClearGivenPermissions();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf