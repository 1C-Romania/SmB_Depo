
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	MappingFieldList = Parameters.MappingFieldList;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshExplanationLabelText();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure MappingFieldListOnChange(Item)
	
	RefreshExplanationLabelText();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure PerformMapping(Command)
	
	NotifyChoice(MappingFieldList.Copy());
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure RefreshExplanationLabelText()
	
	MarkedListItemArray = CommonUseClientServer.GetArrayOfMarkedListItems(MappingFieldList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		ExplanatoryInscription = NStr("en='Matching will be performed only by the internal object IDs.';ru='Сопоставление будет выполнено только по внутренним идентификаторам объектов.'");
		
	Else
		
		ExplanatoryInscription = NStr("en='Matching can be performed by the internal objects ID and by the selected fields.';ru='Сопоставление будет выполнено по внутренним идентификаторам объектов и по выбранным полям.'");
		
	EndIf;
	
EndProcedure

#EndRegion














