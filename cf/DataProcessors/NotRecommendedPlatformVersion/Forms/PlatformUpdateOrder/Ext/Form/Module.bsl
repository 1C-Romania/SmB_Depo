
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	BaseFile = CommonUse.FileInfobase();
	If BaseFile Then
		TemplateOrderUpdate = DataProcessors.NotRecommendedPlatformVersion.GetTemplate("FileBaseUpdateOrder");
	Else
		TemplateOrderUpdate = DataProcessors.NotRecommendedPlatformVersion.GetTemplate("ClientServerBaseUpdateOrder");
	EndIf;
	
	ApplicationUpdateMethod = TemplateOrderUpdate.GetText();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ApplicationUpdateMethodOnClick(Item, EventData, StandardProcessing)
	If EventData.Href <> Undefined Then
		StandardProcessing = False;
		GotoURL(EventData.Href);
	EndIf;
EndProcedure

&AtClient
Procedure PrintInstructions(Command)
	Items.ApplicationUpdateMethod.Document.execCommand("Print");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ApplicationUpdateOrderDocumentCreated(Item)
	// Print command visible
	If Not Item.Document.queryCommandSupported("Print") Then
		Items.PrintInstructions.Visible = False;
	EndIf;
EndProcedure

#EndRegion













