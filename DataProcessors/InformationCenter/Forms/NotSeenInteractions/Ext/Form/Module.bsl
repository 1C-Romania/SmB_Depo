////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SupportRequestID = Parameters.SupportRequestID;
	
	FillInNotSeenInteractions();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure NotSeenInteractionsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	InformationCenterClient.OpenInteractionToSupport(SupportRequestID, CurrentData.ID, CurrentData.Type, CurrentData.Incoming, False);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure FillInNotSeenInteractions()
	
	For Each ItemOfList IN Parameters.ListNotSeenInteractions Do 
		UnviewedInteraction = ItemOfList.Value;
		NewRowVT = NotSeenInteractions.Add();
		FillPropertyValues(NewRowVT, UnviewedInteraction);
		NewRowVT.PictureNumber = InformationCenterServer.PictureNumberByInteraction(NewRowVT.Type, NewRowVT.Incoming);
		NewRowVT.ExplanationToPicture = ?(NewRowVT.Incoming, NStr("en='inc.';ru='вкл.'"), NStr("en='Source.';ru='Источник.'"));
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
