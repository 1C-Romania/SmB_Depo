
#Region FormItemEvents

Procedure ContactInformationPanelDataSelection(Form, Item, SelectedRow, Field, StandardProcessing) Export
	
	StandardProcessing = False;
	
	RowCI = Form.ContactInformationPanelData.FindByID(SelectedRow);
	
	If RowCI.TypeShowingData = "ValueCI" Then
		
		If RowCI.IconIndex = 20 Then // Skype
			Parameters = New Structure("LoginSkype");
			Parameters.LoginSkype = RowCI.PresentationCI;
			List = New ValueList;
			List.Add("Call", NStr("ru = 'Позвонить'; en = 'Call'"));
			List.Add("StartChat", NStr("ru = 'Начать чат'; en = 'Start chat'"));
			NotifyDescription = New NotifyDescription("AfterSelectionFromMenuSkype", ContactInformationSBClient, Parameters);
			Form.ShowChooseFromMenu(NotifyDescription, List);
			Return;
		EndIf;
		
		FillBasis = New Structure("Contact", RowCI.OwnerCI);
		
		FillingValues = New Structure("EventType,FillBasis", 
			EventTypeByContactInformationType(RowCI.IconIndex),
			FillBasis);
			
		FormParameters = New Structure("FillingValues", FillingValues);
		OpenForm("Document.Event.ObjectForm", FormParameters, Form);
		
	ElsIf RowCI.TypeShowingData = "ContactPerson" Then
		
		ShowValue(,RowCI.OwnerCI);
		
	EndIf;
	
EndProcedure

Procedure ContactInformationPanelDataOnActivateRow(Form, Item) Export
	
	RowCI = Form.Items.ContactInformationPanelData.CurrentData;
	If RowCI = Undefined Then
		Return;
	EndIf;
	
	ButtonGoogle = Form.Items.Find("ContextMenuPanelMapGoogle");
	If ButtonGoogle <> Undefined Then
		ButtonGoogle.Enabled = RowCI.TypeShowingData = "ValueCI"
			And RowCI.IconIndex = 12; // address
	EndIf;
	
EndProcedure

Procedure ExecuteCommand(Form, Command) Export
	
	RowCI = Form.Items.ContactInformationPanelData.CurrentData;
	If RowCI = Undefined Then
		Return;
	EndIf;
	
	If Command.Имя = "ContextMenuPanelMapGoogle" Then
		ContactInformationManagementClient.ShowAddressOnMap(RowCI.PresentationCI, "GoogleMaps");
	EndIf;
	
EndProcedure

#EndRegion

#Region Interface

Function ProcessNotifications(Form, EventName, Parameter) Export
	
	Result = EventName = "Write_Counterparty"
			Or EventName = "Write_ContactPerson";
		
	Return Result;
	
EndFunction
	
#EndRegion

#Region ServiceProceduresAndFunctions

Function EventTypeByContactInformationType(IconIndex)
	
	If IconIndex = 12 Then
		EventType = PredefinedValue("Enum.EventTypes.PersonalMeeting");
	ElsIf IconIndex = 8 Then
		EventType = PredefinedValue("Enum.EventTypes.Email");
	ElsIf IconIndex = 9 Then
		EventType = PredefinedValue("Enum.EventTypes.Other");
	ElsIf IconIndex = 20 Then
		EventType = PredefinedValue("Enum.EventTypes.Other");
	ElsIf IconIndex = 11 Then
		EventType = PredefinedValue("Enum.EventTypes.Other");
	ElsIf IconIndex = 7 Then
		EventType = PredefinedValue("Enum.EventTypes.PhoneCall");
	ElsIf IconIndex = 10 Then
		EventType = PredefinedValue("Enum.EventTypes.PhoneCall");
	Else
		EventType = PredefinedValue("Enum.EventTypes.EmptyRef");
	EndIf;
	
	Return EventType;
	
EndFunction

#EndRegion
