
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.User <> Undefined Then
		UserArray = New Array;
		UserArray.Add(Parameters.User);
		
		ExternalUsers = ?(
			TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsers"), True, False);
		
		Items.FormWriteAndClose.Title = NStr("ru = 'Записать'; en = 'Write'");
		
		OpenFromUserCardMode = True;
	Else
		UserArray = Parameters.Users;
		ExternalUsers = Parameters.ExternalUsers;
		OpenFromUserCardMode = False;
	EndIf;
	
	UserCount = UserArray.Count();
	If UserCount = 0 Then
		Raise NStr("ru = 'Не выбрано ни одного пользователя.'; en = 'No one user is selected.'");
	EndIf;
	
	UsersType = Undefined;
	For Each UserFromArray IN UserArray Do
		If UsersType = Undefined Then
			UsersType = TypeOf(UserFromArray);
		EndIf;
		UserTypeFromArray = TypeOf(UserFromArray);
		If UserTypeFromArray <> Type("CatalogRef.Users")
			AND UserTypeFromArray <> Type("CatalogRef.ExternalUsers") Then
			Raise NStr("ru='Команда не может быть выполнена для указанного объекта.'; en='The command can not be run for the specified object.'");
		EndIf;
		
		If UsersType <> UserTypeFromArray Then
			Raise NStr("ru = 'Команда не может быть выполнена сразу для двух разных видов пользователей.'; en = 'Command can not be executed for two different kinds of the users at the same time.'");
		EndIf;
	EndDo;
		
	If UserCount > 1
		AND Parameters.User = Undefined Then
		Title = NStr("ru='Группы пользователей'; en='User groups'");
		Items.GroupsTreeMark.ThreeState = True;
	EndIf;
	
	UsersList = New Structure;
	UsersList.Insert("UserArray", UserArray);
	UsersList.Insert("UserCount", UserCount);
	FillGroupsTree();
	
	If GroupsTree.GetItems().Count() = 0 Then
		Items.GroupsOrWarning.CurrentPage = Items.Warning;
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Not OpenFromUserCardMode Then
		Notification = New NotifyDescription("WriteAndCloseBegin", ThisObject);
		CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#Region GroupsTreeFormTableItemsEventsHandlers

&AtClient
Procedure GroupsTreeChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(,Item.CurrentData.Group);
	
EndProcedure

&AtClient
Procedure GroupsTreeMarkOnChange(Item)
	Modified = True;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndClose(Command)
	WriteAndCloseBegin();
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	FillGroupsTree(True);
	ExpandValueTree();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.GroupsTreeMark.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("GroupsTree.GroupDoesNotChange");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("ReadOnly", True);

EndProcedure

&AtClient
Procedure WriteAndCloseBegin(Result = Undefined, AdditionalParameters = Undefined) Export
	
	UserNotification = New Structure;
	UserNotification.Insert("Message");
	UserNotification.Insert("HasErrors");
	UserNotification.Insert("WholeTextMessages");
	
	WriteChanges(UserNotification);
	
	If UserNotification.HasErrors = False Then
		If UserNotification.Message <> Undefined Then
			ShowUserNotification(
				NStr("en=""User's move"";ru='Перемещение пользователей'"), , UserNotification.Message, PictureLib.Information32);
		EndIf;
	Else
		
		If UserNotification.WholeTextMessages <> Undefined Then
			Report = New TextDocument;
			Report.AddLine(UserNotification.WholeTextMessages);
			
			QuestionText = UserNotification.Message;
			QuestionButtons = New ValueList;
			QuestionButtons.Add("Ok", NStr("en='OK';ru='Ок'"));
			QuestionButtons.Add("ShowReport", NStr("en='Show report';ru='Показать отчет'"));
			Notification = New NotifyDescription("WriteAndCloseQuestionDataProcessor", ThisObject, Report);
			ShowQueryBox(Notification, QuestionText, QuestionButtons,, QuestionButtons[0].Value);
		Else
			Notification = New NotifyDescription("WriteAndCloseWarningDataProcessor", ThisObject);
			ShowMessageBox(Notification, UserNotification.Message);
		EndIf;
		
		Return;
	EndIf;
	
	Modified = False;
	WriteAndCloseEnd();
	
EndProcedure

&AtServer
Procedure FillGroupsTree(JustUncheckCheckBoxes = False)
	
	GroupsTreeReceiver = FormAttributeToValue("GroupsTree");
	If Not JustUncheckCheckBoxes Then
		GroupsTreeReceiver.Rows.Clear();
	EndIf;
	
	If JustUncheckCheckBoxes Then
		
		WereChanges = False;
		Found = GroupsTreeReceiver.Rows.FindRows(New Structure("Check", 1), True);
		For Each TreeRow IN Found Do
			If Not TreeRow.GroupDoesNotChange Then
				TreeRow.Check = 0;
				WereChanges = True;
			EndIf;
		EndDo;
		
		Found = GroupsTreeReceiver.Rows.FindRows(New Structure("Check", 2), True);
		For Each TreeRow IN Found Do
			TreeRow.Check = 0;
			WereChanges = True;
		EndDo;
		
		If WereChanges Then
			Modified = True;
		EndIf;
		
		ValueToFormAttribute(GroupsTreeReceiver, "GroupsTree");
		Return;
	EndIf;
	
	UsersGroups = Undefined;
	SubordinateGroups = New Array;
	ParentsArray = New Array;
	
	If ExternalUsers Then
		EmptyGroup = Catalogs.ExternalUsersGroups.EmptyRef();
		GetExternalUsersGroups(UsersGroups);
	Else
		EmptyGroup = Catalogs.UsersGroups.EmptyRef();
		GetUsersGroups(UsersGroups);
	EndIf;
	
	If UsersGroups.Count() <= 1 Then
		Items.GroupsOrWarning.CurrentPage = Items.Warning;
		Return;
	EndIf;
	
	GetSubordinateGroups(UsersGroups, SubordinateGroups, EmptyGroup);
	
	If TypeOf(UsersList.UserArray[0]) = Type("CatalogRef.Users") Then
		UserType = "User";
	Else
		UserType = "ExternalUser";
	EndIf;
	
	While SubordinateGroups.Count() > 0 Do
		ParentsArray.Clear();
		
		For Each SubGroup IN SubordinateGroups Do
			
			If SubGroup.Parent = EmptyGroup Then
				GroupNewRow = GroupsTreeReceiver.Rows.Add();
				GroupNewRow.Group = SubGroup.Ref;
				GroupNewRow.Picture = ?(UserType = "User", 3, 9);
				
				If UsersList.UserCount = 1 Then
					UserEnabledIndirectlyIntoGroup = False;
					UserRef = UsersList.UserArray[0];
					
					If UserType = "ExternalUser" Then
						UserEnabledIndirectlyIntoGroup = (SubGroup.AllAuthorizationObjects AND 
							(TypeOf(UserRef.AuthorizationObject) = TypeOf(SubGroup.TypeOfAuthorizationObjects)));
						GroupNewRow.GroupDoesNotChange = UserEnabledIndirectlyIntoGroup;
					EndIf;
					
					FoundUser = SubGroup.Ref.Content.Find(UserRef, UserType);
					GroupNewRow.Check = ?(FoundUser <> Undefined Or UserEnabledIndirectlyIntoGroup, 1, 0);
				Else
					GroupNewRow.Check = 2;
				EndIf;
				
			Else
				ParentGroup = 
					GroupsTreeReceiver.Rows.FindRows(New Structure("Group", SubGroup.Parent), True);
				SubordinatedGroupsNewRow = ParentGroup[0].Rows.Add();
				SubordinatedGroupsNewRow.Group = SubGroup.Ref;
				SubordinatedGroupsNewRow.Picture = ?(UserType = "User", 3, 9);
				
				If UsersList.UserCount = 1 Then
					SubordinatedGroupsNewRow.Check = ?(SubGroup.Ref.Content.Find(
						UsersList.UserArray[0], UserType) = Undefined, 0, 1);
				Else
					SubordinatedGroupsNewRow.Check = 2;
				EndIf;
				
			EndIf;
			
			ParentsArray.Add(SubGroup.Ref);
		EndDo;
		SubordinateGroups.Clear();
		
		For Each Item IN ParentsArray Do
			GetSubordinateGroups(UsersGroups, SubordinateGroups, Item);
		EndDo;
		
	EndDo;
	
	GroupsTreeReceiver.Rows.Sort("Group Asc", True);
	ValueToFormAttribute(GroupsTreeReceiver, "GroupsTree");
	
EndProcedure

&AtServer
Procedure GetUsersGroups(UsersGroups)
	
	Query = New Query;
	Query.Text = "SELECT
	|	UsersGroups.Ref,
	|	UsersGroups.Parent
	|FROM
	|	Catalog.UsersGroups AS UsersGroups
	|WHERE
	|	UsersGroups.DeletionMark <> TRUE";
	
	UsersGroups = Query.Execute().Unload();
	
EndProcedure

&AtServer
Procedure GetExternalUsersGroups(UsersGroups)
	
	Query = New Query;
	Query.Text = "SELECT
	|	ExternalUsersGroups.Ref,
	|	ExternalUsersGroups.Parent,
	|	ExternalUsersGroups.TypeOfAuthorizationObjects,
	|	ExternalUsersGroups.AllAuthorizationObjects
	|FROM
	|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
	|WHERE
	|	ExternalUsersGroups.DeletionMark <> TRUE";
	
	UsersGroups = Query.Execute().Unload();
	
EndProcedure

&AtServer
Procedure GetSubordinateGroups(UsersGroups, SubordinateGroups, ParentGroup)
	
	FilterParameters = New Structure("Parent", ParentGroup);
	FilteredRows = UsersGroups.FindRows(FilterParameters);
	
	For Each Item IN FilteredRows Do
		
		If Item.Ref = Catalogs.UsersGroups.AllUsers
			Or Item.Ref = Catalogs.ExternalUsersGroups.AllExternalUsers Then
			Continue;
		EndIf;
		
		SubordinateGroups.Add(Item);
	EndDo;
	
EndProcedure

&AtServer
Procedure WriteChanges(UserNotification)
	
	UserArray = Undefined;
	NotMovedUsers = New Map;
	GroupsTreeSource = GroupsTree.GetItems();
	RefillGroupsContent(GroupsTreeSource, UserArray, NotMovedUsers);
	GenerateMessageText(UserArray, UserNotification, NotMovedUsers)
	
EndProcedure

&AtServer
Procedure RefillGroupsContent(GroupsTreeSource, DisplacedUsersArray, NotMovedUsers)
	
	UserArray = UsersList.UserArray;
	If DisplacedUsersArray = Undefined Then
		DisplacedUsersArray = New Array;
	EndIf;
	
	For Each TreeRow IN GroupsTreeSource Do
		
		If TreeRow.Check = 1
			AND Not TreeRow.GroupDoesNotChange Then
			
			For Each UserRef IN UserArray Do
				
				If TypeOf(UserRef) = Type("CatalogRef.Users") Then
					UserType = "User";
				Else
					UserType = "ExternalUser";
					TransferPossible = UsersService.PossibleUsersMove(TreeRow.Group, UserRef);
					
					If Not TransferPossible Then
						
						If NotMovedUsers.Get(UserRef) = Undefined Then
							NotMovedUsers.Insert(UserRef, New Array);
							NotMovedUsers[UserRef].Add(TreeRow.Group);
						Else
							NotMovedUsers[UserRef].Add(TreeRow.Group);
						EndIf;
						
						Continue;
					EndIf;
					
				EndIf;
				
				Add = ?(TreeRow.Group.Content.Find(
					UserRef, UserType) = Undefined, True, False);
				If Add Then
					UsersService.AddUserToGroup(TreeRow.Group, UserRef, UserType);
					
					If DisplacedUsersArray.Find(UserRef) = Undefined Then
						DisplacedUsersArray.Add(UserRef);
					EndIf;
					
				EndIf;
				
			EndDo;
			
		ElsIf TreeRow.Check = 0
			AND Not TreeRow.GroupDoesNotChange Then
			
			For Each UserRef IN UserArray Do
				
				If TypeOf(UserRef) = Type("CatalogRef.Users") Then
					UserType = "User";
				Else
					UserType = "ExternalUser";
				EndIf;
				
				Delete = ?(TreeRow.Group.Content.Find(
					UserRef, UserType) <> Undefined, True, False);
				If Delete Then
					UsersService.DeleteUserFromGroup(TreeRow.Group, UserRef, UserType);
					
					If DisplacedUsersArray.Find(UserRef) = Undefined Then
						DisplacedUsersArray.Add(UserRef);
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		TreeRowItems = TreeRow.GetItems();
		// Recursion
		RefillGroupsContent(TreeRowItems, DisplacedUsersArray, NotMovedUsers);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure GenerateMessageText(DisplacedUsersArray, UserNotification, NotMovedUsers)
	
	UserCount = DisplacedUsersArray.Count();
	QuantityNotDisplacedUsers = NotMovedUsers.Count();
	RowUsers = "";
	
	If QuantityNotDisplacedUsers > 0 Then
		
		If QuantityNotDisplacedUsers = 1 Then
			For Each NotMovedUser IN NotMovedUsers Do
				Subject = String(NOTMovedUser.Key);
			EndDo;
			UserMessage = NStr("en='User ""% 1"" has not managed to
		|include in the selected group, as they have different types or the groups have the ""All users of the specified type"" sign installed.';ru='Пользователя ""%1"" не удалось включить в выбранные группы,
		|т.к. у них различается тип или у групп установлен признак ""Все пользователи заданного типа"".'");
		Else
			MeasurementUnitInWordParameters = NStr("en='to user,users,users,,,,,,0';ru='пользователю,пользователям,пользователям,,,,,,0'");
			Subject = UsersService.WordEndingGenerating(QuantityNotDisplacedUsers, MeasurementUnitInWordParameters);
			UserMessage = NStr("en='Not all users managed to include in
		|the selected group, as they have different types or the groups have the ""All users of the specified type"" sign installed.';ru='Не всех пользователей удалось включить в выбранные группы,
		|т.к. у них различается тип или у групп установлен признак ""Все пользователи заданного типа"".'");
			For Each NotMovedUser IN NotMovedUsers Do
			RowUsers = RowUsers + String(NOTMovedUser.Key) + " : " + 
				StringFunctionsClientServer.RowFromArraySubrows(NOTMovedUser.Value) + Chars.LF;
			EndDo;
			UserNotification.WholeTextMessages = NStr("en='Following users have not been included to the groups:';ru='Следующие пользователи не были включены в группы:'") +
				Chars.LF + Chars.LF + RowUsers;
		EndIf;
		UserNotification.Message = StringFunctionsClientServer.SubstituteParametersInString(
			UserMessage, Subject);
		UserNotification.HasErrors = True;
		
		Return;
	ElsIf UserCount = 1 Then
		DescriptionOfUser = CommonUse.ObjectAttributeValue(DisplacedUsersArray[0], "Description");
		UserMessage = NStr("en='Groups content of user ""%1"" is changed';ru='Изменен состав групп у пользователя ""%1""'");
		UserNotification.Message = StringFunctionsClientServer.SubstituteParametersInString(
			UserMessage, DescriptionOfUser);
	ElsIf UserCount > 1 Then
		
		UserMessage = NStr("en='Groups content is changed at %1';ru='Изменен состав групп у %1'");
		RowObject = UsersService.WordEndingGenerating(
			UserCount, NStr("en='of user,users,users,,,,,,0';ru='пользователя,пользователей,пользователей,,,,,,0'"));
		UserNotification.Message = StringFunctionsClientServer.SubstituteParametersInString(
			UserMessage, RowObject);
		
	EndIf;
	UserNotification.HasErrors = False;
	
EndProcedure

&AtClient
Procedure ExpandValueTree()
	
	Rows = GroupsTree.GetItems();
	For Each String IN Rows Do
		Items.GroupsTree.Expand(String.GetID(), True);
	EndDo;
	
EndProcedure

&AtClient
Procedure WriteAndCloseQuestionDataProcessor(Response, Report) Export
	
	If Response = "Ok" Then
		Return;
	Else
		Report.Show(NStr("en='Users not included to the group';ru='Пользователи, не включенные в группы'"));
		Return;
	EndIf;
	
	Modified = False;
	WriteAndCloseEnd();
	
EndProcedure

&AtClient
Procedure WriteAndCloseWarningDataProcessor(AdditionalParameters) Export
	
	WriteAndCloseEnd();
	
EndProcedure

&AtClient
Procedure WriteAndCloseEnd()
	
	Notify("PlacingUsersInGroups");
	If ExternalUsers Then
		Notify("Write_ExternalUsersGroups");
	Else
		Notify("Write_UsersGroups");
	EndIf;
	
	If Not OpenFromUserCardMode Then
		Close();
	Else
		FillGroupsTree();
		ExpandValueTree();
	EndIf;
	
EndProcedure

#EndRegion
