
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	CommonUseClientServer.SetFilterItem(
		List.Filter,
		"Ref",
		Parameters.Filter,
		DataCompositionComparisonType.NotInList
	);
	
	CommonUseClientServer.SetFilterItem(
		List.Filter,
		"DeletionMark",
		False,
		DataCompositionComparisonType.Equal
	);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceResult = Undefined;
	TD = Items.List.CurrentData;
	If TD <> Undefined Then
		ChoiceResult = New Structure("KeyOperation, Priority, TargetTime");
		ChoiceResult.KeyOperation = TD.Ref;
		ChoiceResult.Priority = TD.Priority;
		ChoiceResult.TargetTime = TD.TargetTime;
	EndIf;
	
	NotifyChoice(ChoiceResult);
	
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
