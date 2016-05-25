﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormPurposeKey(ThisObject, "PickupSelection");
	EndIf;
	
	If Parameters.ChoiceMode Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		
		// Hide the Administrator profile.
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "Ref", Catalogs.AccessGroupsProfiles.Administrator,
			DataCompositionComparisonType.NotEqual, , True);
		
		// Filter of items not marked for deletion.
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "DeletionMark", False, , , True,
			DataCompositionSettingsItemViewMode.Normal);
		
		Items.List.ChoiceMode = True;
		Items.List.ChoiceFoldersAndItems = Parameters.ChoiceFoldersAndItems;
		
		AutoTitle = False;
		If Parameters.CloseOnChoice = False Then
			// Choice mode.
			Items.List.Multiselect = True;
			Items.List.SelectionMode = TableSelectionMode.MultiRow;
			
			Title = NStr("en = 'Pick up of access groups profiles'");
		Else
			Title = NStr("en = 'Selection of access groups profile'");
		EndIf;
	EndIf;
	
	If Parameters.Property("ProfileWithRolesMarkerForDeletion") Then
		ShowProfiles = "Outdated";
	Else
		ShowProfiles = "AllProfiles";
	EndIf;
	
	If Not Parameters.ChoiceMode Then
		SetFilter();
	Else
		Items.ShowProfiles.Visible = False;
	EndIf;
EndProcedure

#EndRegion

#Region FormManagementItemsEventsHandlers

&AtClient
Procedure ShowProfilesOnChange(Item)
	SetFilter();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetFilter()
	
	CommonUseClientServer.SetFilterDynamicListItem(
		List,
		"Ref.Roles.Role.DeletionMark",
		True,
		DataCompositionComparisonType.Equal,, False);
	
	CommonUseClientServer.SetFilterDynamicListItem(
		List,
		"Ref.SuppliedDataID",
		New UUID("00000000-0000-0000-0000-000000000000"),
		DataCompositionComparisonType.Equal,, False);
	
	If ShowProfiles = "Outdated" Then
		CommonUseClientServer.SetFilterDynamicListItem(
			List,
			"Ref.Roles.Role.DeletionMark",
			True,
			DataCompositionComparisonType.Equal,, True);
		
	ElsIf ShowProfiles = "Supplied" Then
		CommonUseClientServer.SetFilterDynamicListItem(
			List,
			"Ref.SuppliedDataID",
			New UUID("00000000-0000-0000-0000-000000000000"),
			DataCompositionComparisonType.NotEqual,, True);
		
	ElsIf ShowProfiles = "NotSupplied" Then
		CommonUseClientServer.SetFilterDynamicListItem(
			List,
			"Ref.SuppliedDataID",
			New UUID("00000000-0000-0000-0000-000000000000"),
			DataCompositionComparisonType.Equal,, True);
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
