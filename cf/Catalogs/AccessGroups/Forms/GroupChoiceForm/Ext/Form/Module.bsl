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
