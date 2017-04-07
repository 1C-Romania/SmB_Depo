
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	CommonUseClientServer.SetFilterDynamicListItem(List, "IsFolder", True);
	
EndProcedure

#EndRegion
