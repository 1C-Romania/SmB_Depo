
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	IBUserWithFullRights = Users.InfobaseUserWithFullAccess();
	OwnAccess = Parameters.User = Users.AuthorizedUser();
	
	IBUserResponsible =
		Not IBUserWithFullRights
		AND AccessRight("Edit", Metadata.Catalogs.AccessGroups);
	
	Items.AccessGroupsContextMenuChangeGroup.Visible =
		IBUserWithFullRights
		OR IBUserResponsible;
	
	Items.FormReportAccessRights.Visible =
		IBUserWithFullRights
		OR Parameters.User = Users.AuthorizedUser();
	
	// Commands setting for a user with limited rights.
	Items.FormIncludeInGroup.Visible   = IBUserResponsible;
	Items.FormExcludeFromGroup.Visible = IBUserResponsible;
	Items.FormChangeGroup.Visible    = IBUserResponsible;
	
	// Commands setting for a user with full rights.
	Items.AccessGroupsIncludeInGroup.Visible   = IBUserWithFullRights;
	Items.AccessGroupsExludeFromGroup.Visible = IBUserWithFullRights;
	Items.AccessGroupsChangeGroup.Visible    = IBUserWithFullRights;
	
	// Display setting of the pages bookmarks.
	Items.AccessGroupsAndRoles.PagesRepresentation =
		?(IBUserWithFullRights,
		  FormPagesRepresentation.TabsOnTop,
		  FormPagesRepresentation.None);
	
	// Setting of the command panel display for a user with full rights.
	Items.AccessGroups.CommandBarLocation =
		?(IBUserWithFullRights,
		  FormItemCommandBarLabelLocation.Top,
		  FormItemCommandBarLabelLocation.None);
	
	// Setting of the roles display for a user with full rights.
	Items.RoleRepresentation.Visible = IBUserWithFullRights;
	
	If IBUserWithFullRights
	 OR IBUserResponsible
	 OR OwnAccess Then
		
		DisplayAccessGroups();
	Else
		// Normal user is not allowed to view the access settings of any other user.
		Items.AccessGroupsIncludeInGroup.Visible   = False;
		Items.AccessGroupsExludeFromGroup.Visible = False;
		
		Items.AccessGroupsAndRoles.Visible         = False;
		Items.NotEnoughRightsToView.Visible = True;
	EndIf;
	
	ProcessRolesInterface("SetInterfaceOfRolesOnFormCreating");
	ProcessRolesInterface("SetReadOnlyOfRoles", True);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Record_AccessGroups")
	 OR Upper(EventName) = Upper("Write_GroupsAccessProfiles")
	 OR Upper(EventName) = Upper("Write_UsersGroups")
	 OR Upper(EventName) = Upper("Write_ExternalUsersGroups") Then
		
		DisplayAccessGroups();
		UsersServiceClient.ExpandRolesSubsystems(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("TuneRolesInterfaceOnSettingsImporting", Settings);
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersAccessGroups

&AtClient
Procedure AccessGroupsOnActivateRow(Item)
	
	CurrentData   = Items.AccessGroups.CurrentData;
	CurrentParent = Items.AccessGroups.CurrentParent;
	
	If CurrentData = Undefined Then
		
		AccessGroupChanged = ValueIsFilled(CurrentAccessGroup);
		CurrentAccessGroup  = Undefined;
	Else
		NewAccessGroup    = ?(CurrentParent = Undefined, CurrentData.AccessGroup, CurrentParent.AccessGroup);
		AccessGroupChanged = CurrentAccessGroup <> NewAccessGroup;
		CurrentAccessGroup  = NewAccessGroup;
	EndIf;
	
EndProcedure

&AtClient
Procedure AccessGroupsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If AccessGroups.FindByID(SelectedRow) <> Undefined Then
		
		If Items.FormChangeGroup.Visible
		 OR Items.AccessGroupsChangeGroup.Visible Then
			
			ChangeGroup(Items.FormChangeGroup);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure IncludeInGroup(Command)
	
	FormParameters = New Structure;
	Selected = New Array;
	
	For Each DescriptionOfAccessGroup IN AccessGroups Do
		Selected.Add(DescriptionOfAccessGroup.AccessGroup);
	EndDo;
	
	FormParameters.Insert("Selected",         Selected);
	FormParameters.Insert("GroupUser", Parameters.User);
	
	OpenForm("Catalog.AccessGroups.Form.ChoiceByResponsible", FormParameters, ThisObject,
		,,, New NotifyDescription("IncludeExcludeFromGroup", ThisObject, True));
	
EndProcedure

&AtClient
Procedure ExcludeFromGroup(Command)
	
	If Not ValueIsFilled(CurrentAccessGroup) Then
		ShowMessageBox(, NStr("en='Access group not selected.';ru='Группа доступа не выбрана.'"));
		Return;
	EndIf;
	
	IncludeExcludeFromGroup(CurrentAccessGroup, False);
	
EndProcedure

&AtClient
Procedure ChangeGroup(Command)
	
	FormParameters = New Structure;
	
	If Not ValueIsFilled(CurrentAccessGroup) Then
		ShowMessageBox(, NStr("en='Access group not selected.';ru='Группа доступа не выбрана.'"));
		Return;
		
	ElsIf IBUserWithFullRights
	      OR IBUserResponsible
	          AND ChangingContentOfUsersOfGroupIsPermitted(CurrentAccessGroup) Then
		
		FormParameters.Insert("Key", CurrentAccessGroup);
		OpenForm("Catalog.AccessGroups.ObjectForm", FormParameters);
	Else
		ShowMessageBox(,
			NStr("en='Insufficient rights for editing access group.
		|Responsible person for the access group participants and administrator can edit the access group.';ru='Недостаточно прав для редактирования группы доступа.
		|Редактировать группу доступа могут ответственный за участников группы доступа и администратор.'"));
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	DisplayAccessGroups();
	UsersServiceClient.ExpandRolesSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure ReportAboutAccessRights(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("User", Parameters.User);
	
	OpenForm("Report.AccessRights.Form", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// To provide operation of the roles interface.

&AtClient
Procedure GroupRoleBySubsystems(Command)
	
	ProcessRolesInterface("GroupBySubsystems");
	UsersServiceClient.ExpandRolesSubsystems(ThisObject);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure IncludeExcludeFromGroup(AccessGroup, IncludeInAccessGroup) Export
	
	If TypeOf(AccessGroup) <> Type("CatalogRef.AccessGroups")
	  OR Not ValueIsFilled(AccessGroup) Then
		
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("AccessGroup", AccessGroup);
	AdditionalParameters.Insert("IncludeInAccessGroup", IncludeInAccessGroup);
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().DataSeparationEnabled
	   AND AccessGroup = PredefinedValue("Catalog.AccessGroups.Administrators") Then
		
		StandardSubsystemsClient.WhenPromptedForPasswordForAuthenticationToService(
			New NotifyDescription(
				"IncludeExcludeFromGroupEnd", ThisObject, AdditionalParameters),
			ThisObject,
			ServiceUserPassword);
		Return;
	Else
		IncludeExcludeFromGroupEnd("", AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure IncludeExcludeFromGroupEnd(NewServiceUserPassword, AdditionalParameters) Export
	
	If NewServiceUserPassword = Undefined Then
		Return;
	EndIf;
	
	ServiceUserPassword = NewServiceUserPassword;
	
	ErrorDescription = "";
	
	ChangeContentOfGroup(
		AdditionalParameters.AccessGroup,
		AdditionalParameters.IncludeInAccessGroup,
		ErrorDescription);
	
	If ValueIsFilled(ErrorDescription) Then
		ShowMessageBox(, ErrorDescription);
	Else
		NotifyChanged(AdditionalParameters.AccessGroup);
		Notify("Record_AccessGroups", New Structure, AdditionalParameters.AccessGroup);
	EndIf;
	
EndProcedure

&AtServer
Procedure DisplayAccessGroups()
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	If IBUserWithFullRights OR OwnAccess Then
		SetPrivilegedMode(True);
	EndIf;
	
	Query.Text =
	"SELECT ALLOWED
	|	AccessGroups.Ref
	|INTO AuthorizedAccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups";
	Query.Execute();
	
	SetPrivilegedMode(True);
	
	Query.Text =
	"SELECT
	|	AuthorizedAccessGroups.Ref
	|FROM
	|	AuthorizedAccessGroups AS AuthorizedAccessGroups
	|WHERE
	|	(NOT AuthorizedAccessGroups.Ref.DeletionMark)
	|	AND (NOT AuthorizedAccessGroups.Ref.Profile.DeletionMark)";
	AuthorizedAccessGroups = Query.Execute().Unload();
	AuthorizedAccessGroups.Indexes.Add("Ref");
	
	Query.SetParameter("User", Parameters.User);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessGroups.Ref.Description AS Description,
	|	AccessGroups.Ref.Profile.Description AS ProfileDescription,
	|	AccessGroups.Ref.Definition AS Definition,
	|	AccessGroups.Ref.Responsible AS Responsible
	|FROM
	|	(SELECT DISTINCT
	|		AccessGroups.Ref AS Ref
	|	FROM
	|		Catalog.AccessGroups AS AccessGroups
	|			INNER JOIN Catalog.AccessGroups.Users AS UsersAccessGroups
	|			ON (UsersAccessGroups.User In
	|					(SELECT
	|						&User
	|				
	|					UNION ALL
	|				
	|					SELECT
	|						UsersGroupsContents.UsersGroup
	|					FROM
	|						InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|					WHERE
	|						UsersGroupsContents.User = &User))
	|				AND AccessGroups.Ref = UsersAccessGroups.Ref
	|				AND (NOT AccessGroups.DeletionMark)
	|				AND (NOT AccessGroups.Profile.DeletionMark)) AS AccessGroups
	|
	|ORDER BY
	|	AccessGroups.Ref.Description";
	
	AllAccessGroups = Query.Execute().Unload();
	
	// Setting the presentation for the access group.
	// Delete current user from the access group if it is included in it only directly.
	IsForbiddenGroups = False;
	IndexOf = AllAccessGroups.Count()-1;
	
	While IndexOf >= 0 Do
		String = AllAccessGroups[IndexOf];
		
		If AuthorizedAccessGroups.Find(String.AccessGroup, "Ref") = Undefined Then
			AllAccessGroups.Delete(IndexOf);
			IsForbiddenGroups = True;
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	ValueToFormAttribute(AllAccessGroups, "AccessGroups");
	Items.WarningThereAreHiddenAccessGroups.Visible = IsForbiddenGroups;
	
	If Not ValueIsFilled(CurrentAccessGroup) Then
		
		If AccessGroups.Count() > 0 Then
			CurrentAccessGroup = AccessGroups[0].AccessGroup;
		EndIf;
	EndIf;
	
	For Each DescriptionOfAccessGroup IN AccessGroups Do
		
		If DescriptionOfAccessGroup.AccessGroup = CurrentAccessGroup Then
			Items.AccessGroups.CurrentRow = DescriptionOfAccessGroup.GetID();
			Break;
		EndIf;
	EndDo;
	
	If IBUserWithFullRights Then
		FillRoles();
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeContentOfGroup(Val AccessGroup, Val Add, ErrorDescription = "")
	
	If Not ChangingContentOfUsersOfGroupIsPermitted(AccessGroup) Then
		If Add Then
			ErrorDescription = NStr("en='It is not possible to
		|include the user into
		|the access group, as current user is
		|not responsible for the access group members and the user is not an administrator with full rights.';ru='Невозможно включить
		|пользователя
		|в группу доступа, так как текущий
		|пользователь не ответственный за участников группы доступа и не полноправный администратор.'");
		Else
			ErrorDescription = NStr("en='It is not possible to
		|exclude the user from
		|the access group, as current user is
		|not responsible for the access group memebers and the user is not an administrator with full rights.';ru='Невозможно исключить
		|пользователя
		|из группы доступа, так как текущий
		|пользователь не ответственный за участников группы доступа и не полноправный администратор.'");
		EndIf;
		Return;
	EndIf;
	
	If Not Add AND Not UserIncludedInAccessGroup(CurrentAccessGroup) Then
		ErrorDescription =  NStr("en='It is not possible to
		|exclude the user from the access group, as the user is included in it indirectly.';ru='Невозможно исключить
		|пользователя из группы доступа, так как он включен в нее косвенно.'");
		Return;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled()
		AND AccessGroup = Catalogs.AccessGroups.Administrators Then
		
		ActionsWithServiceUser = Undefined;
		AccessManagementService.WhenUserActionService(ActionsWithServiceUser);
		
		If Not ActionsWithServiceUser.ChangeAdmininstrativeAccess Then
			Raise
				NStr("en='Insufficient access rights to modify the administrators structure.';ru='Не достаточно прав доступа для изменения состава администраторов.'");
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	
	AccessGroupObject = AccessGroup.GetObject();
	LockDataForEdit(AccessGroupObject.Ref, AccessGroupObject.DataVersion);
	If Add Then
		If AccessGroupObject.Users.Find(Parameters.User, "User") = Undefined Then
			AccessGroupObject.Users.Add().User = Parameters.User;
		EndIf;
	Else
		TSRow = AccessGroupObject.Users.Find(Parameters.User, "User");
		If TSRow <> Undefined Then
			AccessGroupObject.Users.Delete(TSRow);
		EndIf;
	EndIf;
	
	If AccessGroupObject.Ref = Catalogs.AccessGroups.Administrators Then
		
		If CommonUseReUse.DataSeparationEnabled() Then
			AccessGroupObject.AdditionalProperties.Insert(
				"ServiceUserPassword", ServiceUserPassword);
		Else
			AccessManagementService.CheckEnabledOfUserAccessAdministratorsGroupIB(
				AccessGroupObject.Users, ErrorDescription);
			
			If ValueIsFilled(ErrorDescription) Then
				Return;
			EndIf;
		EndIf;
	EndIf;
	
	Try
		AccessGroupObject.Write();
	Except
		ServiceUserPassword = Undefined;
		Raise;
	EndTry;
	
	UnlockDataForEdit(AccessGroupObject.Ref);
	
	CurrentAccessGroup = AccessGroupObject.Ref;
	
EndProcedure

&AtServer
Function ChangingContentOfUsersOfGroupIsPermitted(AccessGroup)
	
	If IBUserWithFullRights Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("AccessGroup",              AccessGroup);
	Query.SetParameter("AuthorizedUser", Users.AuthorizedUser());
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|		ON (UsersGroupsContents.User = &AuthorizedUser)
	|			AND (UsersGroupsContents.UsersGroup = AccessGroups.Responsible)
	|			AND (AccessGroups.Ref = &AccessGroup)";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Function UserIncludedInAccessGroup(AccessGroup)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("AccessGroup", AccessGroup);
	Query.SetParameter("User", Parameters.User);
	Query.Text =
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|WHERE
	|	AccessGroupsUsers.Ref = &AccessGroup
	|	AND AccessGroupsUsers.User = &User";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Procedure FillRoles()
	
	Query = New Query;
	Query.SetParameter("User", Parameters.User);
	
	If TypeOf(Parameters.User) = Type("CatalogRef.Users")
	 OR TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsers") Then
		
		Query.Text =
		"SELECT DISTINCT 
		|	Roles.Role.Name AS Role
		|FROM
		|	Catalog.AccessGroupsProfiles.Roles AS Roles
		|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
		|			INNER JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
		|			ON (UsersGroupsContents.User = &User)
		|				AND (UsersGroupsContents.UsersGroup = AccessGroupsUsers.User)
		|				AND (NOT AccessGroupsUsers.Ref.DeletionMark)
		|		ON Roles.Ref = AccessGroupsUsers.Ref.Profile
		|			AND (NOT Roles.Ref.DeletionMark)";
	Else
		// User group or external users group.
		Query.Text =
		"SELECT DISTINCT
		|	Roles.Role.Name AS Role
		|FROM
		|	Catalog.AccessGroupsProfiles.Roles AS Roles
		|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
		|		ON (AccessGroupsUsers.User = &User)
		|			AND (NOT AccessGroupsUsers.Ref.DeletionMark)
		|			AND Roles.Ref = AccessGroupsUsers.Ref.Profile
		|			AND (NOT Roles.Ref.DeletionMark)";
	EndIf;
	ValueToFormAttribute(Query.Execute().Unload(), "ReadRoles");
	
	Filter = New Structure("Role", "FullRights");
	If ReadRoles.FindRows(Filter).Count() > 0 Then
		
		Filter = New Structure("Role", "SystemAdministrator");
		If ReadRoles.FindRows(Filter).Count() > 0 Then
			
			ReadRoles.Clear();
			ReadRoles.Add().Role = "FullRights";
			ReadRoles.Add().Role = "SystemAdministrator";
		Else
			ReadRoles.Clear();
			ReadRoles.Add().Role = "FullRights";
		EndIf;
	EndIf;
	
	ProcessRolesInterface("RefreshRolesTree");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// To provide operation of the roles interface.

&AtServer
Procedure ProcessRolesInterface(Action, MainParameter = Undefined)
	
	ActionSettings = New Structure;
	ActionSettings.Insert("MainParameter", MainParameter);
	ActionSettings.Insert("Form",            ThisObject);
	ActionSettings.Insert("CollectionOfRoles",   ReadRoles);
	
	UsersType = ?(CommonUseReUse.DataSeparationEnabled(), 
		Enums.UserTypes.DataAreaUser, 
		Enums.UserTypes.LocalApplicationUser);
	ActionSettings.Insert("UsersType", UsersType);
	
	UsersService.ProcessRolesInterface(Action, ActionSettings);
	
EndProcedure

#EndRegion
