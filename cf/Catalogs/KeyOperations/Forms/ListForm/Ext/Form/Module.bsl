
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ItemGeneralPerformance = PerformanceEstimationService.GetItemGeneralSystemPerformance();
	If ValueIsFilled(ItemGeneralPerformance) Then
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "Ref", ItemGeneralPerformance,
			DataCompositionComparisonType.NotEqual, , ,
			DataCompositionSettingsItemViewMode.Normal);
	EndIf;
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
