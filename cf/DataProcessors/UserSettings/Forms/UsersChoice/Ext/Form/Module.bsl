
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.UserType = Type("CatalogRef.ExternalUsers") Then
		GroupAllUsers = Catalogs.ExternalUsersGroups.AllExternalUsers;
	Else
		GroupAllUsers = Catalogs.UsersGroups.AllUsers;
	EndIf;
	
	WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	UseGroups = GetFunctionalOption("UseUsersGroups");
	UserSource = Parameters.User;
	UserType = Parameters.UserType;
	FillUsersList(UserType, UseGroups);
	
	CopyAll = (Parameters.ActionType = "CopyAll");
	ClearingSettings = (Parameters.ActionType = "Clearing");
	If ClearingSettings Then
		Title = NStr("en='Select users to clear settings';ru='Выбор пользователей для очистки настроек'");
		Items.Label.Title = NStr("en='Select users for whom it is required to clear settings';ru='Выберите пользователей, которым необходимо очистить настройки'");
	EndIf;
	
	If Parameters.Property("SelectedUsers") Then
		MarkAllocatedToUsers = True;
		
		If Parameters.SelectedUsers <> Undefined Then
			
			For Each SelectedUser IN Parameters.SelectedUsers Do
				MarkUser(SelectedUser);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	
	Settings.Delete("AllUsersList");
	
	// If the form is opened from the copying or clearing assistant, then we do not save settings.
	If MarkAllocatedToUsers Then
		Return;
	EndIf;
	
	FilterParameters = New Structure("Check", True);
	MarkedUsersList = New ValueList;
	MarkedUsersArray = AllUsersList.FindRows(FilterParameters);
	
	For Each ArrayRow IN MarkedUsersArray Do
		MarkedUsersList.Add(ArrayRow.User);
	EndDo;
	
	Settings.Insert("MarkedUsers", MarkedUsersList);
	
EndProcedure

&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	
	// If the form is opened from the copying or clearing assistant, then we do not import settings.
	If MarkAllocatedToUsers Then
		Settings.Delete("AllUsersList");
		Settings.Delete("MarkedUsers");
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	MarkedUsers = Settings.Get("MarkedUsers");
	
	If MarkedUsers = Undefined Then
		Return;
	EndIf;
	
	For Each RowMarkedUsers IN MarkedUsers Do
		
		UserRef = RowMarkedUsers.Value;
		MarkUser(UserRef);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateGroupsHeadersOnSwitchingCheckBox();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure UsersGroupsOnActivateRow(Item)
	
	SelectedGroup = Item.CurrentData;
	If SelectedGroup = Undefined Then
		Return;
	EndIf;
	
	ApplyGroupsFilter(SelectedGroup);
	If UseGroups Then
		Items.ShowNestedGroupUsersGroup.CurrentPage = Items.SetPropertyGroup;
	Else
		Items.ShowNestedGroupUsersGroup.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(,Item.CurrentData.User);
	
EndProcedure

&AtClient
Procedure UsersGroupsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	ShowValue(,Item.CurrentData.Group);
	
EndProcedure

&AtClient
Procedure ShowChildGroupsUsersOnChange(Item)
	
	SelectedUserGroup = Items.UsersGroups.CurrentData;
	ApplyGroupsFilter(SelectedUserGroup);
	
	// Update group headers.
	ClearGroupsTitles();
	UpdateGroupsHeadersOnSwitchingCheckBox();
	
EndProcedure

&AtClient
Procedure UsersCheckBoxOnChange(Item)
	
	UsersListRow = Item.Parent.Parent.CurrentData;
	UsersListRow.Check = Not UsersListRow.Check;
	ChangeMark(UsersListRow, Not UsersListRow.Check);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Select(Command)
	
	UsersTarget = New Array;
	For Each Item IN UsersList Do
		
		If Item.Check Then
			UsersTarget.Add(Item.User);
		EndIf;
		
	EndDo;
	
	If UsersTarget.Count() = 0 Then
		ShowMessageBox(,NStr("en='Mark one or multiple users.';ru='Необходимо отметить одного или несколько пользователей.'"));
		Return;
	EndIf;
	
	Result = New Structure("UsersTarget, CopyAll, ClearingSettings", 
		UsersTarget, CopyAll, ClearingSettings);
	Notify("CaseUser", Result);
	Close();
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	For Each UsersListRow IN UsersList Do
		ChangeMark(UsersListRow, True);
	EndDo;
	
EndProcedure

&AtClient
Procedure MarkSelected(Command)
	
	SelectedItems = Items.UsersList.SelectedRows;
	
	If SelectedItems.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Item IN SelectedItems Do
		UsersListRow = UsersList.FindByID(Item);
		ChangeMark(UsersListRow, True);
	EndDo;
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	For Each UsersListRow IN UsersList Do
		ChangeMark(UsersListRow, False);
	EndDo;
EndProcedure

&AtClient
Procedure UncheckSelected(Command)
	
	SelectedItems = Items.UsersList.SelectedRows;
	
	If SelectedItems.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Item IN SelectedItems Do
		UsersListRow = UsersList.FindByID(Item);
		ChangeMark(UsersListRow, False);
	EndDo;
	
EndProcedure

&AtClient
Procedure ChangeUserOrGroup(Command)
	
	CurrentValue = CurrentItem.CurrentData;
	
	If TypeOf(CurrentValue) = Type("FormDataCollectionItem") Then
		
		ShowValue(,CurrentValue.User);
		
	ElsIf TypeOf(CurrentValue) = Type("FormDataTreeItem") Then
		
		ShowValue(,CurrentValue.Group);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ActiveUsers(Command)
	
	StandardSubsystemsClient.OpenActiveUsersList();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsersGroupsGroup.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("UsersGroups.ItIsMarkedUsers");
	FilterElement.ComparisonType = DataCompositionComparisonType.Greater;
	FilterElement.RightValue = 0;

	Item.Appearance.SetParameterValue("Font", New Font(WindowsFonts.DefaultGUIFont, , , True, False, False, False, ));
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("UsersGroups.GroupDescriptionAndItIsMarkedUsers"));

EndProcedure

&AtServer
Procedure MarkUser(UserRef)
	
	For Each AllUsersListRow IN AllUsersList Do
		
		If AllUsersListRow.User = UserRef Then
			AllUsersListRow.Check = True;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure UpdateGroupsHeadersOnSwitchingCheckBox()
	
	For Each UsersGroup IN UsersGroups.GetItems() Do
		
		For Each UsersListRow IN AllUsersList Do
			
			If UsersListRow.Check Then
				ValueMark = True;
				UsersListRow.Check = False;
				UpdateGroupTitle(ThisObject, UsersGroup, UsersListRow, ValueMark);
				UsersListRow.Check = True;
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearGroupsTitles()
	
	For Each UsersGroup IN UsersGroups.GetItems() Do
		ClearGroupTitle(UsersGroup);
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearGroupTitle(UsersGroup)
	
	UsersGroup.UsersMarked = 0;
	SubordinateGroups = UsersGroup.GetItems();
	
	For Each SubordinateGroup IN SubordinateGroups Do
	
		ClearGroupTitle(SubordinateGroup);
	
	EndDo;
	
EndProcedure

&AtClient
Procedure ChangeMark(UsersListRow, ValueMark)
	
	If UseGroups Then
		
		UpdateGroupsTitles(ThisObject, UsersListRow, ValueMark);
		
		UsersListRow.Check = ValueMark;
		Filter = New Structure("User", UsersListRow.User); 
		FoundUsers = AllUsersList.FindRows(Filter);
		For Each FoundUser IN FoundUsers Do
			FoundUser.Check = ValueMark;
		EndDo;
	Else
		UsersListRow.Check = ValueMark;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateGroupsTitles(Form, UsersListRow, ValueMark)
	
	For Each UsersGroup IN Form.UsersGroups.GetItems() Do
		
		UpdateGroupTitle(Form, UsersGroup, UsersListRow, ValueMark);
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateGroupTitle(Form, UsersGroup, UsersListRow, ValueMark)
	
	UserRef = UsersListRow.User;
	If Form.ShowChildGroupUsers 
		Or Form.GroupAllUsers = UsersGroup.Group Then
		Content = UsersGroup.FullSaff;
	Else
		Content = UsersGroup.Content;
	EndIf;
	MarkedUser = Content.FindByValue(UserRef);
	
	If MarkedUser <> Undefined AND ValueMark <> UsersListRow.Check Then
		UsersMarked = UsersGroup.UsersMarked;
		UsersGroup.UsersMarked = ?(ValueMark, UsersMarked + 1, UsersMarked - 1);
		UsersGroup.GroupDescriptionAndIsMarkedUsers = 
			StringFunctionsClientServer.SubstituteParametersInString(NStr("en='%1 (%2)';ru='%1 (%2)'"),
			String(UsersGroup.Group), UsersGroup.UsersMarked);
	EndIf;
	
	// Update headings of all subordinate groups recursively.
	SubordinateGroups = UsersGroup.GetItems();
	For Each SubordinateGroup IN SubordinateGroups Do
		UpdateGroupTitle(Form, SubordinateGroup, UsersListRow, ValueMark);
	EndDo;
	
EndProcedure

&AtClient
Procedure ApplyGroupsFilter(CurrentGroup)
	
	UsersList.Clear();
	If CurrentGroup = Undefined Then
		Return;
	EndIf;
	
	If ShowChildGroupUsers Then
		GroupContent = CurrentGroup.FullSaff;
	Else
		GroupContent = CurrentGroup.Content;
	EndIf;
	For Each Item IN AllUsersList Do
		
		If GroupContent.FindByValue(Item.User) <> Undefined
			Or GroupAllUsers = CurrentGroup.Group Then
			RowUsersList = UsersList.Add();
			RowUsersList.User = Item.User;
			RowUsersList.Check = Item.Check;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillUsersList(UserType, UseGroups);
	
	GroupsTree = FormAttributeToValue("UsersGroups");
	AllUsersListTable = FormAttributeToValue("AllUsersList");
	UsersListTable = FormAttributeToValue("UsersList");
	
	If UserType = Type("CatalogRef.ExternalUsers") Then
		UserExternal = True;
	Else
		UserExternal = False;
	EndIf;
	
	If UseGroups Then
		DataProcessors.UserSettings.FillGroupsTree(GroupsTree, UserExternal);
		AllUsersListTable = DataProcessors.UserSettings.UsersForCopying(
			UserSource, AllUsersListTable, UserExternal);
	Else
		UsersListTable = DataProcessors.UserSettings.UsersForCopying(
			UserSource, UsersListTable, UserExternal);
	EndIf;
	
	GroupsTree.Rows.Sort("Group Asc");
	RowForTransferring = GroupsTree.Rows.Find(GroupAllUsers, "Group");
	
	If RowForTransferring <> Undefined Then
		RowIndex = GroupsTree.Rows.IndexOf(RowForTransferring);
		GroupsTree.Rows.Move(RowIndex, -RowIndex);
	EndIf;
	
	ValueToFormAttribute(GroupsTree, "UsersGroups");
	ValueToFormAttribute(UsersListTable, "UsersList");
	ValueToFormAttribute(AllUsersListTable, "AllUsersList");
	
EndProcedure

#EndRegion
