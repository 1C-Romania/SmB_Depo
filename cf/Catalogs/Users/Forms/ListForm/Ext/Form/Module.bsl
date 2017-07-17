////////////////////////////////////////////////////////////////////////////////
//                          FORM USAGE //
//
// Additional parameters for opening a selection form:
//
// AdvancedSelection - Boolean - if True - extended user
//  selection form opens. Used with parameter
//  ExtendedSelectionFormParameters.
// AnExtendedFormOfSelectionOptions - String - reference
//  to the structure with parameters of
//  the extended selection form in the temporary storage.
//  Structure parameters:
//    FormHeaderSelection - String - selection form header.
//    SelectedUsers - Array - array of selected user names.
//

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	If Not CommonUse.OnCreateAtServer(ThisObject, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	// Initial setting value before loading setting data.
	SelectHierarchy = True;
	
	FillSettingsStored();
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormPurposeKey(ThisObject, "PickupSelection");
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	EndIf;
	
	// Hide user names with empty identifier if the parameter value is True.
	If Parameters.HideUsersWithoutIBUser Then
		CommonUseClientServer.SetFilterDynamicListItem(
			UsersList,
			"InfobaseUserID",
			New UUID("00000000-0000-0000-0000-000000000000"),
			DataCompositionComparisonType.NotEqual);
	EndIf;
	
	// Hide service users.
	CommonUseClientServer.SetFilterDynamicListItem(
		UsersList, "Service", False, , , True);
	
	// Hide the passed user name in the user selection form.
	If TypeOf(Parameters.HiddenUsers) = Type("ValueList") Then
		
		ComparisonTypeCD = DataCompositionComparisonType.NotInList;
		CommonUseClientServer.SetFilterDynamicListItem(
			UsersList,
			"Ref",
			Parameters.HiddenUsers,
			ComparisonTypeCD);
		
	EndIf;
	
	ApplyAppearanceAndHideInvalidUsers();
	
	CustomizeOrderFoldersAllUsers(UsersGroups);
	
	SettingsStored.Insert("AdvancedSelection", Parameters.AdvancedSelection);
	Items.SelectedUsersAndGroups.Visible = SettingsStored.AdvancedSelection;
	SettingsStored.Insert(
		"UseGroups", GetFunctionalOption("UseUsersGroups"));
	
	If Not AccessRight("Insert", Metadata.Catalogs.Users) Then
		Items.CreateUser.Visible = False;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess(, CommonUseReUse.ApplicationRunningMode().Local) Then
		If Items.Find("IBUsers") <> Undefined Then
			Items.IBUsers.Visible = False;
		EndIf;
		Items.InformationAboutUsers.Visible = False;
	EndIf;
	
	If Parameters.ChoiceMode Then
	
		If Items.Find("IBUsers") <> Undefined Then
			Items.IBUsers.Visible = False;
		EndIf;
		Items.InformationAboutUsers.Visible = False;
		
		// Filter of items not marked for deletion.
		CommonUseClientServer.SetFilterDynamicListItem(
			UsersList, "DeletionMark", False, , , True,
			DataCompositionSettingsItemViewMode.Normal);
		
		Items.UsersList.ChoiceMode = True;
		Items.UsersGroups.ChoiceMode = SettingsStored.UserGroupChoice;
		// Disable drag-and-drop in user selection and choice forms.
		Items.UsersList.EnableStartDrag = False;
		
		If Parameters.Property("NonExistentInfobaseUserIDs") Then
			CommonUseClientServer.SetFilterDynamicListItem(
				UsersList, "InfobaseUserID",
				Parameters.NonExistentInfobaseUserIDs,
				DataCompositionComparisonType.InList, , True,
				DataCompositionSettingsItemViewMode.Inaccessible);
		EndIf;
		
		If Parameters.CloseOnChoice = False Then
			// Choice mode.
			Items.UsersList.MultipleChoice = True;
			
			If SettingsStored.AdvancedSelection Then
				StandardSubsystemsServer.SetFormPurposeKey(ThisObject, "AdvancedSelection");
				ChangeParametersExtensionPickForm();
			EndIf;
			
			If SettingsStored.UserGroupChoice Then
				Items.UsersGroups.MultipleChoice = True;
			EndIf;
		EndIf;
	Else
		Items.Comments.Visible = False;
		Items.ChooseUser.Visible = False;
		Items.ChooseGroupUsers.Visible = False;
	EndIf;
	
	SettingsStored.Insert("GroupAllUsers", Catalogs.UsersGroups.AllUsers);
	SettingsStored.Insert("CurrentRow", Parameters.CurrentRow);
	SetupFormByUsingUsersGroups();
	SettingsStored.Delete("CurrentRow");
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.GroupObjectsChange") Then
		Items.FormChangeSelected.Visible = False;
		Items.UsersListContextMenuChangeSelected.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Parameters.ChoiceMode Then
		CheckCurrentFormItemChange();
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_UsersGroups")
	   AND Source = Items.UsersGroups.CurrentRow Then
		
		Items.UsersList.Refresh();
		
	ElsIf Upper(EventName) = Upper("Record_ConstantsSet") Then
		
		If Upper(Source) = Upper("UseUsersGroups") Then
			AttachIdleHandler("OnChangeUseOfUsersGroups", 0.1, True);
		EndIf;
		
		AttachIdleHandler("OnChangeUseOfUsersGroups", 0.1, True);
		
	ElsIf Upper(EventName) = Upper("PlacingUsersInGroups") Then
		
		Items.UsersList.Refresh();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeImportingDataFromSettingsAtServer(Settings)
	
	If TypeOf(Settings["SelectHierarchy"]) = Type("Boolean") Then
		SelectHierarchy = Settings["SelectHierarchy"];
	EndIf;
	
	If Not SelectHierarchy Then
		RefreshFormContentOnGroupChange(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure SelectHierarchicallyOnChange(Item)
	
	RefreshFormContentOnGroupChange(ThisObject);
	
EndProcedure

&AtClient
Procedure ShowInvalidUsersOnChange(Item)
	ToggleDisabledUsersView(ShowNotValidUsers);
EndProcedure

#EndRegion

#Region UsersGroupsFormTableItemsEventsHandlers

&AtClient
Procedure UsersGroupsOnActivateRow(Item)
	
	AttachIdleHandler("UsersGroupsAfterActivateRow", 0.1, True);
	
EndProcedure

&AtClient
Procedure UsersGroupsValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not SettingsStored.AdvancedSelection Then
		NotifyChoice(Value);
	Else
		GetImagesAndFillSelectedList(Value);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersGroupsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Not Copy Then
		Cancel = True;
		FormParameters = New Structure;
		
		If ValueIsFilled(Items.UsersGroups.CurrentRow) Then
			FormParameters.Insert(
				"FillingValues",
				New Structure("Parent", Items.UsersGroups.CurrentRow));
		EndIf;
		
		OpenForm(
			"Catalog.UsersGroups.ObjectForm",
			FormParameters,
			Items.UsersGroups);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersGroupsDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	If SelectHierarchy Then
		ShowMessageBox(,
			NStr("en='To drag user names to groups,
		|clear the ""Show child group users"" check box.';ru='Для перетаскивания пользователя
		|в группы необходимо отключить флажок ""Показывать пользователей дочерних групп"".'"));
		Return;
	EndIf;
	
	If Items.UsersGroups.CurrentRow = String
		Or String = Undefined Then
		Return;
	EndIf;
	
	If DragParameters.Action = DragAction.Move Then
		Move = True;
	Else
		Move = False;
	EndIf;
	
	FolderIsMarkedForDelete = Items.UsersGroups.RowData(String).DeletionMark;
	UserCount = DragParameters.Value.Count();
	
	ActionToDeleteUser = (SettingsStored.GroupAllUsers = String);
	
	ActionWithUser = ?((SettingsStored.GroupAllUsers = Items.UsersGroups.CurrentRow),
		NStr("en='Enable';ru='Включить'"),
		?(Move, NStr("en='Movement';ru='Перемещение'"), NStr("en='Copy';ru='Скопировать'")));
	
	If FolderIsMarkedForDelete Then
		ActionsTemplate = ?(Move, NStr("en='The ""%1"" group is marked for deletion. %2';ru='Группа ""%1"" помечена на удаление. %2'"), 
			NStr("en='The ""%1"" group is marked for deletion. %2';ru='Группа ""%1"" помечена на удаление. %2'"));
		ActionWithUser = StringFunctionsClientServer.SubstituteParametersInString(
			ActionsTemplate, String(String), ActionWithUser);
	EndIf;
	
	If UserCount = 1 Then
		
		If ActionToDeleteUser Then
			QuestionTemplate = NStr("en='Exclude the ""%2"" user from the ""%4"" group?';ru='Исключить пользователя ""%2"" из группы ""%4""?'");
		ElsIf Not FolderIsMarkedForDelete Then
			QuestionTemplate = NStr("en='%1 user ""%2"" to group ""%3""?';ru='%1 пользователя ""%2"" в группу ""%3""?'");
		Else
			QuestionTemplate = NStr("en='%1 user ""%2"" to this group?';ru='%1 пользователя ""%2"" в эту группу?'");
		EndIf;
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			QuestionTemplate, ActionWithUser, String(DragParameters.Value[0]),
			String(String), String(Items.UsersGroups.CurrentRow));
		
	Else
		
		If ActionToDeleteUser Then
			QuestionTemplate = NStr("en='Exclude users (%2) from the ""%4"" group?';ru='Исключить пользователей (%2) из группы ""%4""?'");
		ElsIf Not FolderIsMarkedForDelete Then
			QuestionTemplate = NStr("en='%1 users (%2) to group ""%3""?';ru='%1 пользователей (%2) в группу ""%3""?'");
		Else
			QuestionTemplate = NStr("en='%1 users (%2) to this group?';ru='%1 пользователей (%2) в эту группу?'");
		EndIf;
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			QuestionTemplate, ActionWithUser, UserCount,
			String(String), String(Items.UsersGroups.CurrentRow));
		
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("DragParameters", DragParameters.Value);
	AdditionalParameters.Insert("String", String);
	AdditionalParameters.Insert("Move", Move);
	
	Notification = New NotifyDescription("UsersGroupsDragEnd", ThisObject, AdditionalParameters);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure UsersGroupsCheckingDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersUsersList

&AtClient
Procedure UsersListValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not SettingsStored.AdvancedSelection Then
		NotifyChoice(Value);
	Else
		GetImagesAndFillSelectedList(Value);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
	FormParameters = New Structure;
	FormParameters.Insert("NewUserGroup", Items.UsersGroups.CurrentRow);
	
	If Copy
	   AND Item.CurrentData <> Undefined Then
		
		FormParameters.Insert("CopyingValue", Item.CurrentRow);
	EndIf;
	
	OpenForm("Catalog.Users.ObjectForm", FormParameters, Items.UsersList);
	
EndProcedure

&AtClient
Procedure UsersListDropCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersSelectedUsersAndGroupsList

&AtClient
Procedure ListOfSelectedUsersAndGroupChoice(Item, SelectedRow, Field, StandardProcessing)
	
	DeleteFromListSelected();
	SelectedUsersListChanged = True;
	
EndProcedure

&AtClient
Procedure SelectedUsersAndGroupsListBeforeAddRow(Item, Cancel, Copy, Parent, Group, Parameter)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CreateGroupOfUsers(Command)
	
	Items.UsersGroups.AddRow();
	
EndProcedure

&AtClient
Procedure AssignGroups(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("Users", Items.UsersList.SelectedRows);
	FormParameters.Insert("ExternalUsers", False);
	
	OpenForm("CommonForm.UsersGroups", FormParameters);
	
EndProcedure

&AtClient
Procedure FinishAndClose(Command)
	
	If SettingsStored.AdvancedSelection Then
		UserArray = ChoiceResult();
		NotifyChoice(UserArray);
		SelectedUsersListChanged = False;
		Close(UserArray);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceUserCommand(Command)
	
	UserArray = Items.UsersList.SelectedRows;
	GetImagesAndFillSelectedList(UserArray);
	
EndProcedure

&AtClient
Procedure CancelSelectionUserOrGroup(Command)
	
	DeleteFromListSelected();
	
EndProcedure

&AtClient
Procedure ClearListSelectedUsersAndGroups(Command)
	
	DeleteFromListSelected(True);
	
EndProcedure

&AtClient
Procedure ChooseGroup(Command)
	
	GroupArray = Items.UsersGroups.SelectedRows;
	GetImagesAndFillSelectedList(GroupArray);
	
EndProcedure

&AtClient
Procedure InformationAboutUsers(Command)
	
	OpenForm(
		"Report.InformationAboutUsers.ObjectForm",
		New Structure("VariantKey", "InformationAboutUsers"),
		ThisObject,
		"InformationAboutUsers");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Support bulk object editing.

&AtClient
Procedure ChangeSelected(Command)
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.GroupObjectsChange") Then
		ModuleBatchObjectChangingClient = CommonUseClient.CommonModule("GroupObjectsChangeClient");
		ModuleBatchObjectChangingClient.ChangeSelected(Items.UsersList);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillSettingsStored()
	
	SettingsStored = New Structure;
	SettingsStored.Insert("UserGroupChoice", Parameters.UserGroupChoice);
	
EndProcedure

&AtServer
Procedure ApplyAppearanceAndHideInvalidUsers()
	
	// Design.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	ItemColorsDesign = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	ItemColorsDesign.Value = Metadata.StyleItems.InaccessibleDataColor.Value;
	ItemColorsDesign.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("UsersList.NotValid");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use  = True;
	
	ItemProcessedFields = ConditionalAppearanceItem.Fields.Items.Add();
	ItemProcessedFields.Field = New DataCompositionField("UsersList");
	ItemProcessedFields.Use = True;
	
	// Hide.
	CommonUseClientServer.SetFilterDynamicListItem(
		UsersList, "NotValid", False, , , True);
	
EndProcedure

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

&AtClient
Procedure CheckCurrentFormItemChange()
	
	If CurrentItem.Name <> CurrentItemName Then
		OnChangeCurrentFormItem();
		CurrentItemName = CurrentItem.Name;
	EndIf;
	
#If WebClient Then
	AttachIdleHandler("CheckCurrentFormItemChange", 0.7, True);
#Else
	AttachIdleHandler("CheckCurrentFormItemChange", 0.1, True);
#EndIf
	
EndProcedure

&AtClient
Procedure OnChangeCurrentFormItem()
	
	If CurrentItem.Name = "UsersGroups" Then
		Items.Comments.CurrentPage = Items.GroupComment;
		
	ElsIf CurrentItem.Name = "UsersList" Then
		Items.Comments.CurrentPage = Items.UserComment;
		
	EndIf
	
EndProcedure

&AtServer
Procedure DeleteFromListSelected(DeleteAll = False)
	
	If DeleteAll Then
		SelectedUsersAndGroups.Clear();
		UpdateTitleFromListUsersAndGroupSelected();
		Return;
	EndIf;
	
	ListArrayOfItems = Items.ListOfSelectedUsersAndGroups.SelectedRows;
	For Each ItemOfList IN ListArrayOfItems Do
		SelectedUsersAndGroups.Delete(SelectedUsersAndGroups.FindByID(ItemOfList));
	EndDo;
	
	UpdateTitleFromListUsersAndGroupSelected();
	
EndProcedure

&AtClient
Procedure GetImagesAndFillSelectedList(ArrayChoiceItem)
	
	SelectedItemsAndPictures = New Array;
	For Each SelectedItem IN ArrayChoiceItem Do
		
		If TypeOf(SelectedItem) = Type("CatalogRef.Users") Then
			PictureNumber = Items.UsersList.RowData(SelectedItem).PictureNumber;
		Else
			PictureNumber = Items.UsersGroups.RowData(SelectedItem).PictureNumber;
		EndIf;
		
		SelectedItemsAndPictures.Add(
			New Structure("SelectedItem, PictureNumber", SelectedItem, PictureNumber));
	EndDo;
	
	FillListSelectedUsersAndGroups(SelectedItemsAndPictures);
	
EndProcedure

&AtServer
Function ChoiceResult()
	
	SelectedUsersValuesTable = SelectedUsersAndGroups.Unload( , "User");
	UserArray = SelectedUsersValuesTable.UnloadColumn("User");
	Return UserArray;
	
EndFunction

&AtServer
Procedure ChangeParametersExtensionPickForm()
	
	// Import the list of selected user names.
	If ValueIsFilled(Parameters.AnExtendedFormOfSelectionOptions) Then
		AnExtendedFormOfSelectionOptions = GetFromTempStorage(Parameters.AnExtendedFormOfSelectionOptions);
	Else
		AnExtendedFormOfSelectionOptions = Parameters;
	EndIf;
	If TypeOf(AnExtendedFormOfSelectionOptions.SelectedUsers) = Type("ValueTable") Then
		SelectedUsersAndGroups.Load(AnExtendedFormOfSelectionOptions.SelectedUsers);
	Else
		For Each SelectedUser IN AnExtendedFormOfSelectionOptions.SelectedUsers Do
			SelectedUsersAndGroups.Add().User = SelectedUser;
		EndDo;
	EndIf;
	Users.FillUserPictureNumbers(SelectedUsersAndGroups, "User", "PictureNumber");
	SettingsStored.Insert("FormHeaderSelection", AnExtendedFormOfSelectionOptions.FormHeaderSelection);
	// Set parameters of the extended selection form.
	Items.FinishAndClose.Visible                      = True;
	Items.GroupChooseUser.Visible              = True;
	// Make a list of selected user names visible.
	Items.SelectedUsersAndGroups.Visible     = True;
	If GetFunctionalOption("UseUsersGroups") Then
		Items.GroupsAndUsers.Group                 = ChildFormItemsGroup.Vertical;
		Items.GroupsAndUsers.ChildItemsWidth  = ChildFormItemsWidth.Equal;
		Items.UsersList.Height                       = 5;
		Items.UsersGroups.Height                      = 3;
		ThisObject.Height                                        = 17;
		Items.GroupChooseGroup.Visible                   = True;
		// Show headers of the UsersList and UsersGroups lists.
		Items.UsersGroups.TitleLocation          = FormItemTitleLocation.Top;
		Items.UsersList.TitleLocation           = FormItemTitleLocation.Top;
		Items.UsersList.Title                    = NStr("en='Users in group';ru='Пользователи в группе'");
		If AnExtendedFormOfSelectionOptions.Property("PickupGroupsIsNotPossible") Then
			Items.ChooseGroup.Visible                     = False;
		EndIf;
	Else
		Items.CancelUserSelection.Visible             = True;
		Items.ClearListSelected.Visible               = True;
	EndIf;
	
	// Add the number of selected users to the header of selected users and groups list.
	UpdateTitleFromListUsersAndGroupSelected();
	
EndProcedure

&AtServer
Procedure UpdateTitleFromListUsersAndGroupSelected()
	
	If SettingsStored.UseGroups Then
		TitleSelectedUsersAndGroups = NStr("en='Selected users and groups (%1)';ru='Выбранные пользователи и группы (%1)'");
	Else
		TitleSelectedUsersAndGroups = NStr("en='Selected users (%1)';ru='Выбранные пользователи (%1)'");
	EndIf;
	
	UserCount = SelectedUsersAndGroups.Count();
	If UserCount <> 0 Then
		Items.ListOfSelectedUsersAndGroups.Title = StringFunctionsClientServer.SubstituteParametersInString(
			TitleSelectedUsersAndGroups, UserCount);
	Else
		
		If SettingsStored.UseGroups Then
			Items.ListOfSelectedUsersAndGroups.Title = NStr("en='Selected users and groups';ru='Выбранные пользователи и группы'");
		Else
			Items.ListOfSelectedUsersAndGroups.Title = NStr("en='Selected users';ru='Выбранные пользователи'");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillListSelectedUsersAndGroups(SelectedItemsAndPictures)
	
	For Each ArrayRow IN SelectedItemsAndPictures Do
		
		SelectedUserOrGroup = ArrayRow.SelectedItem;
		PictureNumber = ArrayRow.PictureNumber;
		
		FilterParameters = New Structure("User", SelectedUserOrGroup);
		Found = SelectedUsersAndGroups.FindRows(FilterParameters);
		If Found.Count() = 0 Then
			
			RowSelectedUsers = SelectedUsersAndGroups.Add();
			RowSelectedUsers.User = SelectedUserOrGroup;
			RowSelectedUsers.PictureNumber = PictureNumber;
			SelectedUsersListChanged = True;
			
		EndIf;
		
	EndDo;
	
	SelectedUsersAndGroups.Sort("User Asc");
	UpdateTitleFromListUsersAndGroupSelected();
	
EndProcedure

&AtClient
Procedure OnChangeUseOfUsersGroups()
	
	SetupFormByUsingUsersGroups();
	
EndProcedure

&AtServer
Procedure SetupFormByUsingUsersGroups()
	
	If SettingsStored.Property("CurrentRow") Then
		
		If TypeOf(SettingsStored.CurrentRow) = Type("CatalogRef.UsersGroups") Then
			
			If SettingsStored.UseGroups Then
				Items.UsersGroups.CurrentRow = SettingsStored.CurrentRow;
			Else
				Parameters.CurrentRow = Undefined;
			EndIf;
		Else
			CurrentItem = Items.UsersList;
			Items.UsersGroups.CurrentRow = Catalogs.UsersGroups.AllUsers;
		EndIf;
	Else
		If Not SettingsStored.UseGroups
		   AND Items.UsersGroups.CurrentRow
		     <> Catalogs.UsersGroups.AllUsers Then
			
			Items.UsersGroups.CurrentRow = Catalogs.UsersGroups.AllUsers;
		EndIf;
	EndIf;
	
	Items.SelectHierarchy.Visible = SettingsStored.UseGroups;
	
	If SettingsStored.AdvancedSelection Then
		Items.AssignGroups.Visible = False;
	Else
		Items.AssignGroups.Visible = SettingsStored.UseGroups;
	EndIf;
	
	Items.CreateGroupOfUsers.Visible =
		AccessRight("Insert", Metadata.Catalogs.UsersGroups)
		AND SettingsStored.UseGroups;
	
	UserGroupChoice = SettingsStored.UserGroupChoice
	                        AND SettingsStored.UseGroups
	                        AND Parameters.ChoiceMode;
	
	If Parameters.ChoiceMode Then
		
		Items.ChooseGroupUsers.Visible  = 
			?(SettingsStored.AdvancedSelection, False, UserGroupChoice);
		Items.ChooseUser.DefaultButton =
			?(SettingsStored.AdvancedSelection, False, Not UserGroupChoice);
		Items.ChooseUser.Visible         = Not SettingsStored.AdvancedSelection;
		AutoTitle = False;
		
		If Parameters.CloseOnChoice = False Then
			// Choice mode.
			
			If UserGroupChoice Then
				
				If SettingsStored.AdvancedSelection Then
					Title = SettingsStored.FormHeaderSelection;
				Else
					Title = NStr("en='Select users and groups';ru='Подбор пользователей и групп'");
				EndIf;
				
				Items.ChooseUser.Title =
					NStr("en='Select users';ru='Выбор пользователей'");
				
				Items.ChooseGroupUsers.Title =
					NStr("en='Selected groups';ru='Выбрать группы'");
			Else
				
				If SettingsStored.AdvancedSelection Then
					Title = SettingsStored.FormHeaderSelection;
				Else
					Title = NStr("en='Pick users';ru='Подбор пользователей'");
				EndIf;
				
			EndIf;
		Else
			// Selection mode.
			If UserGroupChoice Then
				
				Title = NStr("en='Select user or group';ru='Выбор пользователя или группы'");
				
				Items.ChooseUser.Title = NStr("en='Select user';ru='Выбрать пользователя'");
			Else
				Title = NStr("en='Select user';ru='Выбрать пользователя'");
			EndIf;
		EndIf;
	EndIf;
	
	RefreshFormContentOnGroupChange(ThisObject);
	
EndProcedure

&AtClient
Procedure UsersGroupsAfterActivateRow()
	
	RefreshFormContentOnGroupChange(ThisObject);
	
EndProcedure

&AtServer
Function UserTransferToNewGroup(UserArray, NewGroupOwner, Move)
	
	If NewGroupOwner = Undefined Then
		Return Undefined;
	EndIf;
	
	CurrentGroupOwner = Items.UsersGroups.CurrentRow;
	UserMessage = UsersService.UserTransferToNewGroup(
		UserArray, CurrentGroupOwner, NewGroupOwner, Move);
	
	Items.UsersList.Refresh();
	Items.UsersGroups.Refresh();
	
	Return UserMessage;
	
EndFunction

&AtClient
Procedure UsersGroupsDragEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.No Then
		Cancel = True;
		Return;
	EndIf;
	
	UserMessage = UserTransferToNewGroup(
		AdditionalParameters.DragParameters,
		AdditionalParameters.String,
		AdditionalParameters.Move);
	
	If UserMessage.Message = Undefined Then
		Return;
	EndIf;
	
	If UserMessage.HasErrors = False Then
		ShowUserNotification(
			NStr("en='Move users';ru='Перемещение пользователей'"), , UserMessage.Message, PictureLib.Information32);
	Else
		ShowMessageBox(,UserMessage.Message);
	EndIf;
	
	Notify("Write_ExternalUsersGroups");
	
EndProcedure

&AtClient
Procedure ToggleDisabledUsersView(ShowInvalid)
	
	CommonUseClientServer.SetFilterDynamicListItem(
		UsersList, "NotValid", False, , ,
		Not ShowInvalid);
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshFormContentOnGroupChange(Form)
	
	Items = Form.Items;
	
	If Not Form.SettingsStored.UseGroups
	 OR Items.UsersGroups.CurrentRow = PredefinedValue(
	         "Catalog.UsersGroups.AllUsers") Then
		
		RefreshDataCompositionParameterValue(
			Form.UsersList, "SelectHierarchy", True);
		
		RefreshDataCompositionParameterValue(
			Form.UsersList, "UsersGroup", PredefinedValue(
				"Catalog.UsersGroups.AllUsers"));
	Else
		
		RefreshDataCompositionParameterValue(
			Form.UsersList, "SelectHierarchy", Form.SelectHierarchy);
		
		RefreshDataCompositionParameterValue(
			Form.UsersList,
			"UsersGroup",
			Items.UsersGroups.CurrentRow);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshDataCompositionParameterValue(Val OwnerOfParameters,
                                                    Val ParameterName,
                                                    Val ParameterValue)
	
	For Each Parameter IN OwnerOfParameters.Parameters.Items Do
		If String(Parameter.Parameter) = ParameterName Then
			
			If Parameter.Use
			   AND Parameter.Value = ParameterValue Then
				Return;
			EndIf;
			Break;
			
		EndIf;
	EndDo;
	
	OwnerOfParameters.Parameters.SetParameterValue(ParameterName, ParameterValue);
	
EndProcedure

#EndRegion
