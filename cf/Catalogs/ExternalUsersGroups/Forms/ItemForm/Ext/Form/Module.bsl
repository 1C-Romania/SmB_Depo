
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Ref) Then
		ProcessRolesInterface("FillRoles", Object.Roles);
		ProcessRolesInterface("SetInterfaceOfRolesOnFormCreating", False);
	EndIf;
	
	// Auxiliary data preparation.
	FillListOfObjectTypesOfAuthorization();
	
	If Not ValueIsFilled(Object.Ref) Then
		
		If Object.Parent = Catalogs.ExternalUsersGroups.AllExternalUsers
			Or CommonUse.ObjectAttributeValue(Object.Parent, "AllAuthorizationObjects") Then
			Object.Parent = Catalogs.ExternalUsersGroups.EmptyRef();
		EndIf;
		
	EndIf;
	
	FilterAvailableForSelectTypesOfGroups();
	
	DefineActionsInForm();
	
	// Setting constant property accessibility.
	
	Items.Description.Visible     = ValueIsFilled(ActionsInForm.ItemProperties);
	Items.Parent.Visible         = ValueIsFilled(ActionsInForm.ItemProperties);
	Items.Comment.Visible      = ValueIsFilled(ActionsInForm.ItemProperties);
	Items.Content.Visible           = ValueIsFilled(ActionsInForm.GroupContent);
	Items.RoleRepresentation.Visible = ValueIsFilled(ActionsInForm.Roles);
	
	If Object.AllAuthorizationObjects Then
		UsersGroupsMembers = "AllOneType";
	ElsIf Object.TypeOfAuthorizationObjects <> Undefined Then
		UsersGroupsMembers = "OneType";
	Else
		UsersGroupsMembers = "Any";
	EndIf;
	
	IsAllExternalUsersGroup = 
		Object.Ref = Catalogs.ExternalUsersGroups.AllExternalUsers;
	
	If IsAllExternalUsersGroup Then
		Items.Description.ReadOnly = True;
		Items.Parent.ReadOnly     = True;
		Items.Comment.ReadOnly  = True;
		Items.GroupExternalUsers.ReadOnly = True;
	EndIf;
	
	If ReadOnly
	 OR Not IsAllExternalUsersGroup
	     AND ActionsInForm.Roles             <> "Edit"
	     AND ActionsInForm.GroupContent     <> "Edit"
	     AND ActionsInForm.ItemProperties <> "Edit"
	 OR IsAllExternalUsersGroup
	   AND UsersService.BanEditOfRoles() Then
		
		ReadOnly = True;
	EndIf;
	
	If ActionsInForm.ItemProperties <> "Edit" Then
		Items.Description.ReadOnly = True;
		Items.Parent.ReadOnly     = True;
		Items.Comment.ReadOnly  = True;
	EndIf;
	
	If ActionsInForm.GroupContent <> "Edit" Then
		Items.GroupExternalUsers.ReadOnly = True;
	EndIf;
	
	ProcessRolesInterface(
		"SetReadOnlyOfRoles",
		    UsersService.BanEditOfRoles()
		OR ActionsInForm.Roles <> "Edit");
	
	SetEnabledOfProperties(ThisObject);
	
	FillStatusOfUsers();
	RefreshListOfInvalidUsers(True);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ProcessRolesInterface("FillRoles", Object.Roles);
	ProcessRolesInterface("SetInterfaceOfRolesOnFormCreating", True);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Filling object roles from collection.
	CurrentObject.Roles.Clear();
	For Each String IN CollectionOfRoles Do
		CurrentObject.Roles.Add().Role = CommonUse.MetadataObjectID(
			"Role." + String.Role);
	EndDo;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	FillStatusOfUsers();
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_ExternalUsersGroups", New Structure, Object.Ref);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	UncheckedAttributes = New Array;
	CheckedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Check whether there are roles in metadata.
	CheckedObjectAttributes.Add("Roles.Role");
	
	TreeItems = Roles.GetItems();
	For Each String IN TreeItems Do
		If String.Check AND Left(String.Synonym, 1) = "?" Then
			CommonUseClientServer.AddUserError(Errors,
				"Roles[%1].RolesSynonym",
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Role ""%1"" is not found in the metadata.';ru='Роль ""%1"" не найдена в метаданных.'"),
					String.Synonym),
				"Roles",
				TreeItems.IndexOf(String),
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Role ""%2"" in row %1 is not found in the metadata.';ru='Роль ""%2"" в строке %1 не найдена в метаданных.'"),
					"%1", String.Synonym));
		EndIf;
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
	If UsersGroupsMembers = "Any" Then
		UncheckedAttributes.Add("AuthorizationObjectsTypePresentation");
	EndIf;
	UncheckedAttributes.Add("Object");
	CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, UncheckedAttributes);
	
	CurrentObject = FormAttributeToValue("Object");
	
	CurrentObject.AdditionalProperties.Insert(
		"CheckedObjectAttributes", CheckedObjectAttributes);
	
	If Not CurrentObject.CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("TuneRolesInterfaceOnSettingsImporting", Settings);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ContentParticipantsOnChange(Item)
	
	Object.AllAuthorizationObjects = (UsersGroupsMembers = "AllOneType");
	If Object.AllAuthorizationObjects Then
		Object.Content.Clear();
	EndIf;
	
	If UsersGroupsMembers = "AllOneType" Or UsersGroupsMembers = "OneType" Then
		If Not ValueIsFilled(AuthorizationObjectsTypePresentation) Then
			AuthorizationObjectsTypePresentation = AuthorizationObjectTypes[0].Presentation;
			Object.TypeOfAuthorizationObjects = AuthorizationObjectTypes[0].Value;
		EndIf;
	Else
		AuthorizationObjectsTypePresentation = "";
		Object.TypeOfAuthorizationObjects = Undefined;
	EndIf;
	
	SetEnabledOfProperties(ThisObject);
	
EndProcedure

&AtClient
Procedure PresentationOfAuthorizationObjectsTypeOnChange(Item)
	
	If ValueIsFilled(AuthorizationObjectsTypePresentation) Then
		DeleteNotTypicalExternalUsers();
	Else
		Object.AllAuthorizationObjects  = False;
		Object.TypeOfAuthorizationObjects = Undefined;
	EndIf;
	
	SetEnabledOfProperties(ThisObject);
	
EndProcedure

&AtClient
Procedure PresentationOfAuthorizationObjectsTypeStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ShowChooseFromList(
		New NotifyDescription("AuthorizationObjectsTypePresentationEndSelect", ThisObject),
		AuthorizationObjectTypes,
		Item,
		AuthorizationObjectTypes.FindByValue(Object.TypeOfAuthorizationObjects));
	
EndProcedure

&AtClient
Procedure ParentOnChange(Item)
	
	Object.AllAuthorizationObjects = False;
	FilterAvailableForSelectTypesOfGroups();
	
	SetEnabledOfProperties(ThisObject);
	
EndProcedure

&AtClient
Procedure ParentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("ChooseParent");
	
	OpenForm("Catalog.ExternalUsersGroups.ChoiceForm", FormParameters, Items.Parent);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonUseClient.ShowCommentEditingForm(
		Item.EditText, ThisObject, "Object.Comment");
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersRoles

////////////////////////////////////////////////////////////////////////////////
// To provide operation of the roles interface.

&AtClient
Procedure RolesCheckOnChange(Item)
	
	If Items.Roles.CurrentData <> Undefined Then
		ProcessRolesInterface("RefreshContentOfRoles");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsContentEventsHandlers

&AtClient
Procedure ContentChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	Object.Content.Clear();
	If TypeOf(ValueSelected) = Type("Array") Then
		For Each Value IN ValueSelected Do
			ChoiceProcessingOfExternalUser(Value);
		EndDo;
	Else
		ChoiceProcessingOfExternalUser(ValueSelected);
	EndIf;
	
EndProcedure

&AtClient
Procedure ContentExternalUserStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectSelectUsers(False);
	
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
Procedure PickExternalUsers(Command)

	SelectSelectUsers(True);
	
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

////////////////////////////////////////////////////////////////////////////////
// To provide operation of the roles interface.

&AtClient
Procedure ShowOnlySelectedRoles(Command)
	
	ProcessRolesInterface("SelectedRolesOnly");
	UsersServiceClient.ExpandRolesSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure GroupRoleBySubsystems(Command)
	
	ProcessRolesInterface("GroupBySubsystems");
	UsersServiceClient.ExpandRolesSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure EnableRoles(Command)
	
	ProcessRolesInterface("RefreshContentOfRoles", "IncludeAll");
	
	UsersServiceClient.ExpandRolesSubsystems(ThisObject, False);
	
EndProcedure

&AtClient
Procedure ExcludeRoles(Command)
	
	ProcessRolesInterface("RefreshContentOfRoles", "ExcludeAll");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ContentExternalUser.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.Content.NotValid");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);

EndProcedure

&AtClient
Procedure AuthorizationObjectsTypePresentationEndSelect(SelectedItem, NotSpecified) Export
	
	If SelectedItem <> Undefined Then
		
		Modified = True;
		Object.TypeOfAuthorizationObjects        = SelectedItem.Value;
		AuthorizationObjectsTypePresentation = SelectedItem.Presentation;
		
		PresentationOfAuthorizationObjectsTypeOnChange(Items.AuthorizationObjectsTypePresentation);
	EndIf;
	
EndProcedure

&AtServer
Function UserTransferToGroup(UserArray, NewGroupOwner)
	
	DisplacedUsersArray = New Array;
	For Each UserRef IN UserArray Do
		
		FilterParameters = New Structure("ExternalUser", UserRef);
		If TypeOf(UserRef) = Type("CatalogRef.ExternalUsers")
			AND Object.Content.FindRows(FilterParameters).Count() = 0 Then
			Object.Content.Add().ExternalUser = UserRef;
			DisplacedUsersArray.Add(UserRef);
		EndIf;
		
	EndDo;
	
	Return UsersService.GeneratingMessageToUser(
		DisplacedUsersArray, NewGroupOwner, False);
	
EndFunction

&AtServer
Procedure FilterAvailableForSelectTypesOfGroups()
	
	If ValueIsFilled(Object.Parent)
		AND Object.Parent <> Catalogs.ExternalUsersGroups.AllExternalUsers Then
		
		If Object.Parent.TypeOfAuthorizationObjects <> Undefined Then
			FoundValue = AuthorizationObjectTypes.FindByValue(Object.Parent.TypeOfAuthorizationObjects);
			Object.TypeOfAuthorizationObjects        = FoundValue.Value;
			AuthorizationObjectsTypePresentation = FoundValue.Presentation;
			UsersGroupsMembers = Items.UsersGroupsMembers.ChoiceList.FindByValue("OneType").Value;
			Items.UsersType.Enabled = False;
		Else
			Items.UsersType.Enabled = True;
			FoundValue = Items.UsersGroupsMembers.ChoiceList.FindByValue("AllOneType");
			If FoundValue <> Undefined Then
				Items.UsersGroupsMembers.ChoiceList.Delete(FoundValue);
			EndIf;
			
		EndIf;
		
	Else
		
		FoundValue = Items.UsersGroupsMembers.ChoiceList.FindByValue("AllOneType");
		If FoundValue = Undefined Then
			Items.UsersGroupsMembers.ChoiceList.Insert(0, "AllOneType", NStr("en='All the users of the specifed type';ru='Все пользователи заданного вида'"));
		EndIf;
		Items.UsersType.Enabled = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DefineActionsInForm()
	
	ActionsInForm = New Structure;
	
	// "", "View", "Edit".
	ActionsInForm.Insert("Roles", "");
	
	// "", "View", "Edit".
	ActionsInForm.Insert("GroupContent", "");
	
	// "", "View", "Edit".
	ActionsInForm.Insert("ItemProperties", "");
	
	If Users.InfobaseUserWithFullAccess()
	 OR AccessRight("Insert", Metadata.Catalogs.Users) Then
		// Administrator.
		ActionsInForm.Roles             = "Edit";
		ActionsInForm.GroupContent     = "Edit";
		ActionsInForm.ItemProperties = "Edit";
		
	ElsIf Users.RolesAvailable("AddChangeExternalUsers") Then
		// Manager of external users.
		ActionsInForm.Roles             = "";
		ActionsInForm.GroupContent     = "Edit";
		ActionsInForm.ItemProperties = "Edit";
		
	Else
		// Reader of external users.
		ActionsInForm.Roles             = "";
		ActionsInForm.GroupContent     = "view";
		ActionsInForm.ItemProperties = "view";
	EndIf;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.Users\OnDeterminingFormAction");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnDeterminingFormAction(Object.Ref, ActionsInForm);
	EndDo;
	
	UsersOverridable.ChangeActionsInForm(Object.Ref, ActionsInForm);
	
	// Checking action names in the form.
	If Find(", View, Edit,", ", " + ActionsInForm.Roles + ",") = 0 Then
		ActionsInForm.Roles = "";
	ElsIf UsersService.BanEditOfRoles() Then
		ActionsInForm.Roles = "";
	EndIf;
	If Find(", View, Edit,", ", " + ActionsInForm.GroupContent + ",") = 0 Then
		ActionsInForm.InfobaseUserProperties = "";
	EndIf;
	If Find(", View, Edit,", ", " + ActionsInForm.ItemProperties + ",") = 0 Then
		ActionsInForm.ItemProperties = "";
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetEnabledOfProperties(Form)
	
	Items = Form.Items;
	
	Items.Content.ReadOnly = Form.Object.AllAuthorizationObjects;
	
	CommandsEnabled =
		Not Form.ReadOnly
		AND Not Items.GroupExternalUsers.ReadOnly
		AND Not Items.Content.ReadOnly
		AND Items.Content.Enabled;
		
	Items.Content.ReadOnly		                = Not CommandsEnabled;
	
	Items.ContentFill.Enabled                = CommandsEnabled;
	Items.ContentContextMenuFill.Enabled = CommandsEnabled;
	
	Items.ContentSortAsc.Enabled = CommandsEnabled;
	Items.SortContentDesc.Enabled    = CommandsEnabled;
	
	Items.ContentMoveUp.Enabled         = CommandsEnabled;
	Items.ContentMoveDown.Enabled          = CommandsEnabled;
	Items.ContentContextMenuMoveUp.Enabled = CommandsEnabled;
	Items.ContentContextMenuMoveDown.Enabled  = CommandsEnabled;
	
	Items.AuthorizationObjectsTypePresentation.Visible = 
		Not Form.IsAllExternalUsersGroup
		AND ((Form.UsersGroupsMembers = "OneType" Or Form.UsersGroupsMembers = "AllOneType"));
	
EndProcedure

&AtServer
Procedure FillListOfObjectTypesOfAuthorization()
	
	TypesOfLinksAuthorizationObject =
		Metadata.Catalogs.ExternalUsers.Attributes.AuthorizationObject.Type.Types();
	
	For Each AuthorizationObjectRefType IN TypesOfLinksAuthorizationObject Do
		TypeMetadata = Metadata.FindByType(AuthorizationObjectRefType);
		
		TypeArray = New Array;
		TypeArray.Add(AuthorizationObjectRefType);
		ReferenceTypeDescription = New TypeDescription(TypeArray);
		
		AuthorizationObjectTypes.Add(
			ReferenceTypeDescription.AdjustValue(Undefined), TypeMetadata.Synonym);
	EndDo;
	
	FoundItem = AuthorizationObjectTypes.FindByValue(Object.TypeOfAuthorizationObjects);
	
	AuthorizationObjectsTypePresentation = ?(
		FoundItem = Undefined, "", FoundItem.Presentation);
	
EndProcedure

&AtServer
Procedure DeleteNotTypicalExternalUsers()
	
	Query = New Query;
	Query.SetParameter("TypeOfAuthorizationObjects", TypeOf(Object.TypeOfAuthorizationObjects));
	Query.SetParameter(
		"SelectedExternalUsers",
		Object.Content.Unload().UnloadColumn("ExternalUser"));
	
	Query.Text =
	"SELECT
	|	ExternalUsers.Ref
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	VALUETYPE(ExternalUsers.AuthorizationObject) <> &TypeOfAuthorizationObjects
	|	AND ExternalUsers.Ref IN(&SelectedExternalUsers)";
	
	BeginTransaction();
	Try
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			FoundStrings = Object.Content.FindRows(
				New Structure("ExternalUser", Selection.Ref));
			
			For Each FoundString IN FoundStrings Do
				Object.Content.Delete(Object.Content.IndexOf(FoundString));
			EndDo;
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtClient
Procedure SelectSelectUsers(Pick)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", ?(
		Items.Content.CurrentData = Undefined,
		Undefined,
		Items.Content.CurrentData.ExternalUser));
	
	If Pick Then
		FormParameters.Insert("CloseOnChoice", False);
		FormParameters.Insert("Multiselect", True);
		FormParameters.Insert("AdvancedSelection", True);
		FormParameters.Insert("AnExtendedFormOfSelectionOptions", AnExtendedFormOfSelectionOptions());
	EndIf;
	
	If Object.TypeOfAuthorizationObjects <> Undefined Then
		FormParameters.Insert("TypeOfAuthorizationObjects", Object.TypeOfAuthorizationObjects);
	EndIf;
	
	OpenForm(
		"Catalog.ExternalUsers.ChoiceForm",
		FormParameters,
		?(Pick,
			Items.Content,
			Items.ContentExternalUser));
	
EndProcedure

&AtClient
Procedure ChoiceProcessingOfExternalUser(ValueSelected)
	
	If TypeOf(ValueSelected) = Type("CatalogRef.ExternalUsers") Then
		Object.Content.Add().ExternalUser = ValueSelected;
	EndIf;
	
EndProcedure

&AtServer
Function AnExtendedFormOfSelectionOptions()
	
	SelectedUsers = New ValueTable;
	SelectedUsers.Columns.Add("User");
	SelectedUsers.Columns.Add("PictureNumber");
	
	ExternalUsersUsersGroupsMembers = Object.Content.Unload(, "ExternalUser");
	
	For Each Item IN ExternalUsersUsersGroupsMembers Do
		
		RowSelectedUsers = SelectedUsers.Add();
		RowSelectedUsers.User = Item.ExternalUser;
		
	EndDo;
	
	FormHeaderSelection = NStr("en='Select external user group participants';ru='Подбор участников группы внешних пользователей'");
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
			CommonUse.ObjectAttributeValue(GroupStructureString.ExternalUser, "NotValid");
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
	
EndProcedure

&AtServer
Procedure ContentSortStrings(SortingType)
	If Not Items.ShowNotValidUsers.Check Then
		Items.Content.RowFilter = New FixedStructure();
	EndIf;
	
	If SortingType = "Ascending" Then
		Object.Content.Sort("ExternalUser Asc");
	Else
		Object.Content.Sort("ExternalUser Desc");
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

////////////////////////////////////////////////////////////////////////////////
// To provide operation of the roles interface.

&AtServer
Procedure ProcessRolesInterface(Action, MainParameter = Undefined)
	
	ActionSettings = New Structure;
	ActionSettings.Insert("MainParameter",      MainParameter);
	ActionSettings.Insert("Form",                 ThisObject);
	ActionSettings.Insert("CollectionOfRoles",        CollectionOfRoles);
	ActionSettings.Insert("UsersType",      Enums.UserTypes.ExternalUser);
	ActionSettings.Insert("HideFullAccessRole", True);
	
	UsersService.ProcessRolesInterface(Action, ActionSettings);
	
EndProcedure

#EndRegion














