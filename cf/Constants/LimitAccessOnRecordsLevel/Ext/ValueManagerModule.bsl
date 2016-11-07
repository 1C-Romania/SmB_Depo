#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var RecordLevelSecurityEnabled; // Check box of changing constant from False to True.
//                                                  Used in the OnWrite event handler.

Var LimitAccessOnRecordsLevelChanged; // Check box of changing constant value.
//                                                  Used in the OnWrite event handler.

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	RecordLevelSecurityEnabled
		= Value AND Not Constants.LimitAccessOnRecordsLevel.Get();
	
	LimitAccessOnRecordsLevelChanged
		= Value <>   Constants.LimitAccessOnRecordsLevel.Get();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If LimitAccessOnRecordsLevelChanged Then
		
		AccessManagementService.OnChangeLimitAccessOnRecordsLevel(
			RecordLevelSecurityEnabled);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf