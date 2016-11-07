
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	HTMLData = FormAttributeToValue("Object").GetTemplate("DetailedDescriptionHTML");
	DetailedDescriptionText = HTMLData.GetText();
	
	TransitionLink = "link_" + Parameters.TransitionLink;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM ITEMS EVENTS HANDLERS

//Procedure-handler of the event of HTML-document generating end of the TextDetailedDescription field
//
&AtClient
Procedure DetailedDescriptionTextDocumentCreated(Item)
	
	If TransitionLink = "" Then
		Return;	
	EndIf;
	
	For Each LinkItem IN Items.DetailedDescriptionText.Document.Links Do
		If LinkItem.name = TransitionLink Then
			LinkItem.Click();
		EndIf;
	EndDo; 	
	
EndProcedure



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
