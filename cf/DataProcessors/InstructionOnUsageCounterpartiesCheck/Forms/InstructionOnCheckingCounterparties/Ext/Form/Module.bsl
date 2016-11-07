
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ServiceDescription = DataProcessors.InstructionOnUsageCounterpartiesCheck.GetTemplate("InstructionOnCheckingCounterparties").GetText();
	
EndProcedure

&AtClient
Procedure ServiceDescriptionOnClick(Item, EventData, StandardProcessing)
	
	If Find(EventData.Href, "#Administration") > 0 Then
		StandardProcessing = False;
		CounterpartiesCheckClient.OpenServiceSettings();
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
