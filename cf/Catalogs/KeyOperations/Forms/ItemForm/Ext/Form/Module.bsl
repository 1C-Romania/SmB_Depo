
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ItemGeneralPerformance = PerformanceEstimationService.GetItemGeneralSystemPerformance();
	If Object.Ref = ItemGeneralPerformance Then
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure

#EndRegion
