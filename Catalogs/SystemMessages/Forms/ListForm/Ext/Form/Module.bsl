
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ThisIsSessionWithEstablishedValuesOfDelimiters = CommonUseReUse.DataSeparationEnabled() 
		AND CommonUseReUse.CanUseSeparatedData();
	
	// Initial group setting.
	DataGrouping = List.SettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	DataGrouping.UserSettingID = "MainGroup";
	DataGrouping.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	GroupFields = DataGrouping.GroupFields;
	
	DataGroupItem = GroupFields.Items.Add(Type("DataCompositionGroupField"));
	DataGroupItem.Field = New DataCompositionField("Recipient");
	DataGroupItem.Use = True;
	
	DataGroupItem = GroupFields.Items.Add(Type("DataCompositionGroupField"));
	DataGroupItem.Field = New DataCompositionField("Sender");
	DataGroupItem.Use = False;
	
	// Conditional group setting.
	GroupVariant = "ByRecipient";
	SetListGrouping();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure GroupVariantOnChange(Item)
	
	SetListGrouping();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SendAndReceiveMessages(Command)
	
	If ThisIsSessionWithEstablishedValuesOfDelimiters Then
		MessageText = NStr("en = 'Message processing is possible only in undivided session of service administrator.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;

	MessageExchangeClient.SendAndReceiveMessages();
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure Setting(Command)
	
	OpenForm("CommonForm.MessageExchangeSetting",, ThisObject);
	
EndProcedure

&AtClient
Procedure Delete(Command)
	
	If Items.List.CurrentData <> Undefined Then
		
		If Items.List.CurrentData.Property("RowGroup")
			AND TypeOf(Items.List.CurrentData.RowGroup) = Type("DynamicalListGroupRow") Then
			
			ShowMessageBox(, NStr("en = 'Action is unavailable for the grouping row of the list.'"));
			
		Else
			
			If Items.List.SelectedRows.Count() > 1 Then
				
				QuestionString = NStr("en = 'Do you want to delete the selected messages?'");
				
			Else
				
				QuestionString = NStr("en = 'Delete message ""[Message]""?'");
				QuestionString = StrReplace(QuestionString, "[Message]", Items.List.CurrentData.Description);
				
			EndIf;
			
			NotifyDescription = New NotifyDescription("DeleteEnd", ThisObject);
			ShowQueryBox(NOTifyDescription, QuestionString, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		DeleteMessageDirectly(Items.List.SelectedRows);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetListGrouping()
	
	GroupRecipient  = List.SettingsComposer.Settings.Structure[0].GroupFields.Items[0];
	GroupSender = List.SettingsComposer.Settings.Structure[0].GroupFields.Items[1];
	
	If GroupVariant = "WithoutGrouping" Then
		
		GroupRecipient.Use = False;
		GroupSender.Use = False;
		
		Items.Sender.Visible = True;
		Items.Recipient.Visible = True;
		
	Else
		
		Use = (GroupVariant = "ByRecipient");
		
		GroupRecipient.Use = Use;
		GroupSender.Use = Not Use;
		
		Items.Sender.Visible = Use;
		Items.Recipient.Visible = Not Use;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteMessageDirectly(Val Messages)
	
	For Each Message IN Messages Do
		
		If TypeOf(Message) <> Type("CatalogRef.SystemMessages") Then
			Continue;
		EndIf;
		
		MessageObject = Message.GetObject();
		
		If MessageObject <> Undefined Then
			
			MessageObject.Lock();
			
			If ValueIsFilled(MessageObject.Sender)
				AND MessageObject.Sender <> MessageExchangeInternal.ThisNode() Then
				
				MessageObject.DataExchange.Recipients.Add(MessageObject.Sender);
				MessageObject.DataExchange.Recipients.AutoFill = False;
				
			EndIf;
			
			MessageObject.DataExchange.Load = True; // Existing references to the catalog shall prevent from or slow down deletion of catalog items.
			MessageObject.Delete();
			
		EndIf;
		
	EndDo;
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
