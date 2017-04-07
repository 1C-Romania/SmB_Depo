
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	CustomizeOrderFoldersAllUsers(List);
	
	If Parameters.ChoiceMode Then
		
		StandardSubsystemsServer.SetFormPurposeKey(ThisObject, "PickupSelection");
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		
		Items.List.ChoiceMode = True;
		
		// Filter of items not marked for deletion.
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "DeletionMark", False, , , True,
			DataCompositionSettingsItemViewMode.Normal);
		
		// Excluding group selection All external users as a parent.
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "Ref", Catalogs.UsersGroups.AllUsers,
			DataCompositionComparisonType.NotEqual, , Parameters.Property("ChooseParent"));
		
		If Parameters.CloseOnChoice = False Then
			// Choice mode.
			Title = NStr("en='Select user groups';ru='Подбор групп пользователей'");
			Items.List.Multiselect = True;
			Items.List.SelectionMode = TableSelectionMode.MultiRow;
		Else
			Title = NStr("en='Select users group';ru='Выбор группы пользователей'");
		EndIf;
		AutoTitle = False;
		
	EndIf;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure CustomizeOrderFoldersAllUsers(List)
	
	Var Order;
	
	// Order.
	Order = List.SettingsComposer.Settings.Order;
	Order.UserSettingID = "DefaultOrder";
	
	Order.Items.Clear();
	
	OrderingItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderingItem.Field = New DataCompositionField("Predefined");
	OrderingItem.OrderType = DataCompositionSortDirection.Desc;
	OrderingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderingItem.Use = True;
	
	OrderingItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderingItem.Field = New DataCompositionField("Description");
	OrderingItem.OrderType = DataCompositionSortDirection.Asc;
	OrderingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderingItem.Use = True;
	
EndProcedure

#EndRegion
