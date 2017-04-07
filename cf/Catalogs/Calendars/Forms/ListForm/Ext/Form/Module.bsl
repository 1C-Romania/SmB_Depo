
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		Items.List.ChoiceMode = True;
	EndIf;
	
	List.Parameters.SetParameterValue("CurrentDate", CurrentSessionDate());
	
	CommonUseClientServer.SetFilterDynamicListItem(
		List, "ScheduleOwner", , DataCompositionComparisonType.NotFilled, , ,
		DataCompositionSettingsItemViewMode.Normal);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ChangeSelected(Command)
	ModuleBatchObjectChangingClient = CommonUseClient.CommonModule("GroupObjectsChangeClient");
	ModuleBatchObjectChangingClient.ChangeSelected(Items.List);
EndProcedure

#EndRegion
