
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
