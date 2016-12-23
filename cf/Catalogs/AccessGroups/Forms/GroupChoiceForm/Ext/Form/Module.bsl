#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Selection of groups only.
	CommonUseClientServer.SetFilterDynamicListItem(
		List, "IsFolder", True, , , True);
	
	// Filter of items not marked for deletion.
	CommonUseClientServer.SetFilterDynamicListItem(
		List, "DeletionMark", False, , , True,
		DataCompositionSettingsItemViewMode.Normal);
EndProcedure

#EndRegion














