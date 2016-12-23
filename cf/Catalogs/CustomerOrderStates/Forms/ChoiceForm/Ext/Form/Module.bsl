﻿////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF SAVING SETTINGS

&AtClient
// Procedure - Command execution handler SetMainItem.
//
Procedure CommandSetMainItem(Command)
		
	SelectedItem = Items.List.CurrentRow;
	If ValueIsFilled(SelectedItem) Then
		SmallBusinessServer.SetUserSetting(SelectedItem, "StatusOfNewCustomerOrder");
		Items.List.Refresh();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	// Selection of main item	
	List.Parameters.SetParameterValue("UserSetting", ChartsOfCharacteristicTypes.UserSettings["StatusOfNewCustomerOrder"]);
	List.Parameters.SetParameterValue("CurrentUser", Users.CurrentUser());
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure - event handler NotificationProcessing.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "UserSettingsChanged" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtClient
// Procedure - event handler OnActivateRow.
//
Procedure ListOnActivateRow(Item)
	
	MainSetting = Items.List.CurrentData.MainSetting;
	
	If MainSetting Then
		Items.FormCommandSetMainItem.Title = "Used to create new orders";
		Items.FormCommandSetMainItem.Enabled = False;
	Else
		Items.FormCommandSetMainItem.Title = "";
		Items.FormCommandSetMainItem.Enabled = True;
	EndIf;
	
EndProcedure // ListOnActivateRow()
// 














