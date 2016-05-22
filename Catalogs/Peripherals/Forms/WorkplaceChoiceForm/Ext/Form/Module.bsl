
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Workplace = EquipmentManagerServerCall.GetClientWorkplace();
	
	ClientID = Parameters.ClientID;
	
	If Not IsBlankString(ClientID) Then
		NewArray = New Array();
		NewArray.Add(New ChoiceParameter("Filter.DeletionMark", False));
		NewArray.Add(New ChoiceParameter("Filter.Code", ClientID));
		NewFixedArray = New FixedArray(NewArray);
		Items.Workplace.ChoiceParameters = NewFixedArray;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ChooseAndClose(Command)
	
	ClearMessages();
		
	If ValueIsFilled(Workplace) Then
		Parameters.Workplace = Workplace;
		ClearMessages();
		ReturnStructure = New Structure("Workplace", Workplace);
		Close(ReturnStructure);
	Else
		
		CommonUseClientServer.MessageToUser(NStr("en='Select work place'"), Workplace, "Workplace");
		
	EndIf;
	
EndProcedure

#EndRegion