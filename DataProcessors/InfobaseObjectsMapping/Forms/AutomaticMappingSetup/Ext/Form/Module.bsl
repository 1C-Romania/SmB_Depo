
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
		
		ExplanatoryInscription = NStr("en = 'Matching will be performed only by the internal object IDs.'");
		
	Else
		
		ExplanatoryInscription = NStr("en = 'Matching can be performed by the internal objects ID and by the selected fields.'");
		
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
