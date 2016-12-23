	
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Object.Ref = Catalogs.UsersGroups.EmptyRef()
	   AND Object.Parent = Catalogs.UsersGroups.AllUsers Then
		
		Object.Parent = Catalogs.UsersGroups.EmptyRef();
	EndIf;
	
	If Object.Ref = Catalogs.UsersGroups.AllUsers Then
		ReadOnly = True;
	EndIf;
	
	FillStatusOfUsers();
	
	RefreshListOfInvalidUsers(True);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_UsersGroups", New Structure, Object.Ref);
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	FillStatusOfUsers();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ParentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("ChooseParent");
	
	OpenForm("Catalog.UsersGroups.ChoiceForm", FormParameters, Items.Parent);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonUseClient.ShowCommentEditingForm(
		Item.EditText, ThisObject, "Object.Comment");
	
EndProcedure

#EndRegion

#Region FormTableItemsContentEventsHandlers

&AtClient
Procedure ContentChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	Object.Content.Clear();
	If TypeOf(ValueSelected) = Type("Array") Then
		
		For Each Value IN ValueSelected Do
			UserChoiceProcessing(Value);
		EndDo;
		
	Else
		UserChoiceProcessing(ValueSelected);
	EndIf;
	
EndProcedure

&AtClient
Procedure ContentDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	UserMessage = UserTransferToGroup(DragParameters.Value, Object.Ref);
	If UserMessage <> Undefined Then
		ShowUserNotification(
			NStr("en=""User's move"";ru='Перемещение пользователей'"), , UserMessage, PictureLib.Information32);
	EndIf;
		
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SelectUsers(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CloseOnChoice", False);
	FormParameters.Insert("Multiselect", True);
	FormParameters.Insert("AdvancedSelection", True);
	FormParameters.Insert("AnExtendedFormOfSelectionOptions", AnExtendedFormOfSelectionOptions());
	
	OpenForm("Catalog.Users.ChoiceForm", FormParameters, Items.Content);

EndProcedure

&AtClient
Procedure ShowNotValidUsers(Command)
	
	RefreshListOfInvalidUsers(False);
	
EndProcedure

&AtClient
Procedure SortAscending(Command)
	ContentSortStrings("Ascending");
EndProcedure

&AtClient
Procedure SortDescending(Command)
	ContentSortStrings("Descending");
EndProcedure

&AtClient
Procedure MoveUp(Command)
	ContentMoveString("Up");
EndProcedure

&AtClient
Procedure MoveDown(Command)
	ContentMoveString("Down");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.User.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.Content.NotValid");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);

EndProcedure

&AtClient
Procedure UserChoiceProcessing(ValueSelected)
	
	If TypeOf(ValueSelected) = Type("CatalogRef.Users") Then
		Object.Content.Add().User = ValueSelected;
	EndIf;
	
EndProcedure

&AtServer
Function UserTransferToGroup(UserArray, NewGroupOwner)
	
	DisplacedUsersArray = New Array;
	For Each UserRef IN UserArray Do
		
		FilterParameters = New Structure("User", UserRef);
		If TypeOf(UserRef) = Type("CatalogRef.Users")
			AND Object.Content.FindRows(FilterParameters).Count() = 0 Then
			Object.Content.Add().User = UserRef;
			DisplacedUsersArray.Add(UserRef);
		EndIf;
		
	EndDo;
	
	Return UsersService.GeneratingMessageToUser(
		DisplacedUsersArray, NewGroupOwner, False);
	
EndFunction

&AtServer
Function AnExtendedFormOfSelectionOptions()
	
	SelectedUsers = New ValueTable;
	SelectedUsers.Columns.Add("User");
	SelectedUsers.Columns.Add("PictureNumber");
	
	UsersGroupsMembers = Object.Content.Unload(, "User");
	
	For Each Item IN UsersGroupsMembers Do
		
		RowSelectedUsers = SelectedUsers.Add();
		RowSelectedUsers.User = Item.User;
		
	EndDo;
	
	FormHeaderSelection = NStr("en='Select user group members';ru='Подбор участников группы пользователей'");
	AnExtendedFormOfSelectionOptions = 
		New Structure("FormHeaderSelection, SelectedUsers, PickupGroupsIsNotPossible",
		                 FormHeaderSelection, SelectedUsers, True);
	StorageAddress = PutToTempStorage(AnExtendedFormOfSelectionOptions);
	Return StorageAddress;
	
EndFunction

&AtServer
Procedure FillStatusOfUsers()
	
	For Each GroupStructureString IN Object.Content Do
		GroupStructureString.NotValid = 
			CommonUse.ObjectAttributeValue(GroupStructureString.User, "NotValid");
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshListOfInvalidUsers(BeforeOpenForms)
	
	Items.ShowNotValidUsers.Check = ?(BeforeOpenForms, False,
		Not Items.ShowNotValidUsers.Check);
	
	Filter = New Structure;
	
	If Not Items.ShowNotValidUsers.Check Then
		Filter.Insert("NotValid", False);
		Items.Content.RowFilter = New FixedStructure(Filter);
	Else
		Items.Content.RowFilter = New FixedStructure();
	EndIf;
	
	Items.Content.Refresh();
	
EndProcedure

&AtServer
Procedure ContentSortStrings(SortingType)
	
	If Not Items.ShowNotValidUsers.Check Then
		Items.Content.RowFilter = New FixedStructure();
	EndIf;
	
	If SortingType = "Ascending" Then
		Object.Content.Sort("User Asc");
	Else
		Object.Content.Sort("User Desc");
	EndIf;
	
	If Not Items.ShowNotValidUsers.Check Then
		Filter = New Structure;
		Filter.Insert("NotValid", False);
		Items.Content.RowFilter = New FixedStructure(Filter);
	EndIf;
	
EndProcedure

&AtServer
Procedure ContentMoveString(MovementDirection)
	
	String = Object.Content.FindByID(Items.Content.CurrentRow);
	If String = Undefined Then
		Return;
	EndIf;
	
	IndexOfCurrentRow = String.LineNumber - 1;
	Shift = 0;
	
	While True Do
		Shift = Shift + ?(MovementDirection = "Up", -1, 1);
		
		If IndexOfCurrentRow + Shift < 0
		Or IndexOfCurrentRow + Shift >= Object.Content.Count() Then
			Return;
		EndIf;
		
		If Items.ShowNotValidUsers.Check
		 Or Object.Content[IndexOfCurrentRow + Shift].NotValid = False Then
			Break;
		EndIf;
	EndDo;
	
	Object.Content.Move(IndexOfCurrentRow, Shift);
	Items.Content.Refresh();
	
EndProcedure

#EndRegion














