
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not ValueIsFilled(Parameters.User) Then
		If AccessManagementService.SimplifiedInterfaceOfAccessRightsSettings() Then
			Raise
				NStr("en = 'To open report, open the user card,
					|click the ""Access rights"" link, and then click ""Access rights report"".';
					|ru = 'Чтобы открыть отчет откройте карточку пользователя,
					|перейдите по ссылке ""Права доступа"", нажмите на кнопку ""Отчет по правам доступа"".'");
		Else
			Raise
				NStr("en = 'To open report, open the user card or user group card,
					|click the ""Access rights"" link, and then click ""Access rights report"".';
					|ru = 'Чтобы открыть отчет откройте карточку пользователя или группы пользователей,
					|перейдите по ссылке ""Права доступа"", нажмите на кнопку ""Отчет по правам доступа"".'");
		EndIf;
	EndIf;
	
	If Parameters.User <> Users.AuthorizedUser()
	   AND Not Users.InfobaseUserWithFullAccess() Then
		
		Raise NStr("en='Insufficient rights to view the report.';ru='Недостаточно прав для просмотра отчета.'");
	EndIf;
	
	Items.DetailedInformationAboutAccessRights.Visible =
		Not AccessManagementService.SimplifiedInterfaceOfAccessRightsSettings();
	
	OutputReport(Parameters.User);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DocumentDetailProcessing(Item, Details, StandardProcessing)
	
	If TypeOf(Details) = Type("String")
	   AND Left(Details, StrLen("OpenListForm: ")) = "OpenListForm: " Then
		
		StandardProcessing = False;
		OpenForm(Mid(Details, StrLen("OpenListForm: ") + 1) + ".ListForm");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Generate(Command)
	
	OutputReport(Parameters.User);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure OutputReport(Ref)
	
	OutputGroupRights = TypeOf(Parameters.User) = Type("CatalogRef.UsersGroups")
	              OR TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsersGroups");
	
	SimplifiedInterface = AccessManagementService.SimplifiedInterfaceOfAccessRightsSettings();
	
	Document = New SpreadsheetDocument;
	
	Template = FormAttributeToValue("Report").GetTemplate("Template");
	AreaIndent = Template.GetArea("Indent");
	Properties = New Structure;
	Properties.Insert("Ref", Ref);
	
	If TypeOf(Ref) = Type("CatalogRef.Users") Then
		Properties.Insert("ReportHeader",				NStr("en = 'User rights report'; ru = 'Отчет по правам пользователя'"));
		Properties.Insert("RolesByProfilesGrouping",	NStr("en = 'User roles by profiles'; ru = 'Роли пользователя по профилям'"));
		Properties.Insert("ObjectPresentation",			NStr("en = 'User: %1'; ru = 'Пользователь: %1'"));
		
	ElsIf TypeOf(Ref) = Type("CatalogRef.ExternalUsers") Then
		Properties.Insert("ReportHeader",				NStr("en='External user rights report';ru='Отчет по правам внешнего пользователя'"));
		Properties.Insert("RolesByProfilesGrouping",	NStr("en='Roles of external user by profiles';ru='Роли внешнего пользователя по профилям'"));
		Properties.Insert("ObjectPresentation",			NStr("en = 'External user: %1'; ru = 'Внешний пользователь: %1'"));
		
	ElsIf TypeOf(Ref) = Type("CatalogRef.UsersGroups") Then
		Properties.Insert("ReportHeader",				NStr("en = 'User group rights report'; ru = 'Отчет по правам группы пользователей'"));
		Properties.Insert("RolesByProfilesGrouping",	NStr("en='User group roles by profiles';ru='Роли группы пользователей по профилям'"));
		Properties.Insert("ObjectPresentation",			NStr("en = 'User group: %1'; ru = 'Группа пользователей: %1'"));
	Else
		Properties.Insert("ReportHeader",				NStr("en='Report on group rights of external users';ru='Отчет по правам группы внешних пользователей'"));
		Properties.Insert("RolesByProfilesGrouping",	NStr("en='Roles of external user group by profiles';ru='Роли группы внешних пользователей по профилям'"));
		Properties.Insert("ObjectPresentation",			NStr("en = 'External user group: %1'; ru = 'Группа внешних пользователей: %1'"));
	EndIf;
	
	Properties.ObjectPresentation = StringFunctionsClientServer.SubstituteParametersInString(
		Properties.ObjectPresentation, String(Ref));
	
	// Display title.
	Area = Template.GetArea("Title");
	Area.Parameters.Fill(Properties);
	Document.Put(Area);
	
	// Display IB user properties for user and external user.
	If Not OutputGroupRights Then
		
		Document.StartRowAutoGrouping();
		Document.Put(Template.GetArea("InfobaseUserPropertiesGrouping"), 1,, True);
		Area = Template.GetArea("InfobaseUserPropertiesDetails1");
		
		InfobaseUserProperties = Undefined;
		
		SetPrivilegedMode(True);
		
		IBUserHasBeenRead = Users.ReadIBUser(
			CommonUse.ObjectAttributeValue(Ref, "InfobaseUserID"),
			InfobaseUserProperties);
		
		SetPrivilegedMode(False);
		
		If IBUserHasBeenRead Then
			Area.Parameters.CanLogOnToApplication = Users.CanLogOnToApplication(
				InfobaseUserProperties);
			
			Document.Put(Area, 2);
			
			Area = Template.GetArea("InfobaseUserPropertiesDetails2");
			Area.Parameters.Fill(InfobaseUserProperties);
			
			Area.Parameters.LanguagePresentation =
				LanguagePresentation(InfobaseUserProperties.Language);
			
			Area.Parameters.LaunchModePresentation =
				StartModePresentation(InfobaseUserProperties.RunMode);
			
			If Not ValueIsFilled(InfobaseUserProperties.OSUser) Then
				Area.Parameters.OSUser = NStr("en='Not specified';ru='Не указан'");
			EndIf;
			Document.Put(Area, 2);
		Else
			Area.Parameters.CanLogOnToApplication = False;
			Document.Put(Area, 2);
		EndIf;
		Document.EndRowAutoGrouping();
	EndIf;
	
	If TypeOf(Ref) = Type("CatalogRef.Users")
		OR TypeOf(Ref) = Type("CatalogRef.ExternalUsers") Then
		
		SetPrivilegedMode(True);
		IBUser = InfobaseUsers.FindByUUID(
			CommonUse.ObjectAttributeValue(Ref, "InfobaseUserID"));
		SetPrivilegedMode(False);
		
		If Users.InfobaseUserWithFullAccess(IBUser, True) Then
			
			Area = Template.GetArea("FullRightsUser");
			Document.Put(Area, 1);
			Return;
		EndIf;
	EndIf;
	
	// Display access groups.
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("User",        Ref);
	Query.SetParameter("OutputGroupRights",     OutputGroupRights);
	Query.SetParameter("AccessRestrictionKinds", MetadataObjectsRightsRestrictionKinds());
	
	Query.SetParameter("RightSettingsOwnerTypes", AccessManagementServiceReUse.Parameters(
		).PossibleRightsForObjectRightsSettings.OwnerTypes);
	
	Query.Text =
	"SELECT DISTINCT
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessGroups.Profile,
	|	AccessGroupsUsers.User,
	|	CASE
	|		WHEN VALUETYPE(AccessGroupsUsers.User) <> TYPE(Catalog.Users)
	|				AND VALUETYPE(AccessGroupsUsers.User) <> TYPE(Catalog.ExternalUsers)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS GroupInvolvement
	|INTO UserAccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON AccessGroups.Ref = AccessGroupsUsers.Ref
	|			AND (NOT AccessGroups.DeletionMark)
	|			AND (NOT AccessGroups.Profile.DeletionMark)
	|			AND (CASE
	|				WHEN &OutputGroupRights
	|					THEN AccessGroupsUsers.User = &User
	|				ELSE TRUE IN
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|						WHERE
	|							UsersGroupsContents.UsersGroup = AccessGroupsUsers.User
	|							AND UsersGroupsContents.User = &User)
	|			END)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserAccessGroups.AccessGroup AS AccessGroup,
	|	PRESENTATION(UserAccessGroups.AccessGroup) AS AccessGroupPresentation,
	|	UserAccessGroups.User AS Participant,
	|	UserAccessGroups.User.Description AS ParticipantPresentation,
	|	UserAccessGroups.GroupInvolvement,
	|	UserAccessGroups.AccessGroup.Responsible AS Responsible,
	|	UserAccessGroups.AccessGroup.Responsible.Description AS ResponsiblePresentation,
	|	UserAccessGroups.AccessGroup.Definition AS Definition,
	|	UserAccessGroups.AccessGroup.Profile AS Profile,
	|	PRESENTATION(UserAccessGroups.AccessGroup.Profile) AS ProfilePresentation
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|TOTALS
	|	MAX(Participant)
	|BY
	|	AccessGroup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UserAccessGroups.Profile
	|INTO UserProfiles
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserProfiles.Profile AS Profile,
	|	PRESENTATION(UserProfiles.Profile) AS ProfilePresentation,
	|	ProfilesRoles.Role.Name AS Role,
	|	ProfilesRoles.Role.Synonym AS RolePresentation
	|FROM
	|	UserProfiles AS UserProfiles
	|		INNER JOIN Catalog.AccessGroupsProfiles.Roles AS ProfilesRoles
	|		ON UserProfiles.Profile = ProfilesRoles.Ref
	|TOTALS
	|	MAX(Profile),
	|	MAX(ProfilePresentation),
	|	MAX(Role),
	|	MAX(RolePresentation)
	|BY
	|	Profile,
	|	Role
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	VALUETYPE(ObjectRightsSettings.Object) AS ObjectsType,
	|	ObjectRightsSettings.Object AS Object,
	|	ISNULL(SettingsInheritance.Inherit, TRUE) AS Inherit,
	|	CASE
	|		WHEN VALUETYPE(ObjectRightsSettings.User) <> TYPE(Catalog.Users)
	|				AND VALUETYPE(ObjectRightsSettings.User) <> TYPE(Catalog.ExternalUsers)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS GroupInvolvement,
	|	ObjectRightsSettings.User AS User,
	|	ObjectRightsSettings.User.Description AS UserDescription,
	|	ObjectRightsSettings.Right,
	|	ObjectRightsSettings.RightDenied AS RightDenied,
	|	ObjectRightsSettings.InheritanceAllowed AS InheritanceAllowed
	|FROM
	|	InformationRegister.ObjectRightsSettings AS ObjectRightsSettings
	|		LEFT JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|		ON (SettingsInheritance.Object = ObjectRightsSettings.Object)
	|			AND (SettingsInheritance.Parent = ObjectRightsSettings.Object)
	|WHERE
	|	CASE
	|			WHEN &OutputGroupRights
	|				THEN ObjectRightsSettings.User = &User
	|			ELSE TRUE IN
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|					WHERE
	|						UsersGroupsContents.UsersGroup = ObjectRightsSettings.User
	|						AND UsersGroupsContents.User = &User)
	|		END
	|
	|UNION ALL
	|
	|SELECT
	|	VALUETYPE(SettingsInheritance.Object),
	|	SettingsInheritance.Object,
	|	SettingsInheritance.Inherit,
	|	FALSE,
	|	UNDEFINED,
	|	"""",
	|	"""",
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|		LEFT JOIN InformationRegister.ObjectRightsSettings AS ObjectRightsSettings
	|		ON (ObjectRightsSettings.Object = SettingsInheritance.Object)
	|			AND (ObjectRightsSettings.Object = SettingsInheritance.Parent)
	|WHERE
	|	SettingsInheritance.Object = SettingsInheritance.Parent
	|	AND SettingsInheritance.Inherit = FALSE
	|	AND ObjectRightsSettings.Object IS NULL
	|TOTALS
	|	MAX(Inherit),
	|	MAX(GroupInvolvement),
	|	MAX(User),
	|	MAX(UserDescription),
	|	MAX(InheritanceAllowed)
	|BY
	|	ObjectsType,
	|	Object,
	|	User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessRestrictionKinds.Table,
	|	AccessRestrictionKinds.Right,
	|	AccessRestrictionKinds.AccessKind,
	|	AccessRestrictionKinds.Presentation AS AccessKindPresentation
	|INTO AccessRestrictionKinds
	|FROM
	|	&AccessRestrictionKinds AS AccessRestrictionKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserAccessGroups.Profile AS Profile,
	|	UserAccessGroups.AccessGroup AS AccessGroup,
	|	ISNULL(AccessGroupsAccessKinds.AccessKind, UNDEFINED) AS AccessKind,
	|	ISNULL(AccessGroupsAccessKinds.AllAllowed, FALSE) AS AllAllowed,
	|	ISNULL(AccessGroupsAccessValues.AccessValue, UNDEFINED) AS AccessValue
	|INTO AccessTypesAndValues
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|		LEFT JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|		ON (AccessGroupsAccessKinds.Ref = UserAccessGroups.AccessGroup)
	|		LEFT JOIN Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|		ON (AccessGroupsAccessValues.Ref = AccessGroupsAccessKinds.Ref)
	|			AND (AccessGroupsAccessValues.AccessKind = AccessGroupsAccessKinds.AccessKind)
	|
	|UNION
	|
	|SELECT
	|	UserAccessGroups.Profile,
	|	UserAccessGroups.AccessGroup,
	|	AccessGroupsProfilesAccessKinds.AccessKind,
	|	AccessGroupsProfilesAccessKinds.AllAllowed,
	|	ISNULL(AccessGroupsProfilesAccessValues.AccessValue, UNDEFINED)
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|		INNER JOIN Catalog.AccessGroupsProfiles.AccessKinds AS AccessGroupsProfilesAccessKinds
	|		ON (AccessGroupsProfilesAccessKinds.Ref = UserAccessGroups.Profile)
	|		LEFT JOIN Catalog.AccessGroupsProfiles.AccessValues AS AccessGroupsProfilesAccessValues
	|		ON (AccessGroupsProfilesAccessValues.Ref = AccessGroupsProfilesAccessKinds.Ref)
	|			AND (AccessGroupsProfilesAccessValues.AccessKind = AccessGroupsProfilesAccessKinds.AccessKind)
	|WHERE
	|	AccessGroupsProfilesAccessKinds.Preset
	|
	|UNION
	|
	|SELECT
	|	UserAccessGroups.Profile,
	|	UserAccessGroups.AccessGroup,
	|	AccessKindsRightSettings.EmptyRefValue,
	|	FALSE,
	|	UNDEFINED
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|		INNER JOIN Catalog.MetadataObjectIDs AS AccessKindsRightSettings
	|		ON (AccessKindsRightSettings.EmptyRefValue IN (&RightSettingsOwnerTypes))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfilesRolesRights.Table.Parent.Name AS ObjectsKind,
	|	ProfilesRolesRights.Table.Parent.Synonym AS ObjectsKindPresentation,
	|	ProfilesRolesRights.Table.Parent.CollectionOrder AS ObjectsKindOrder,
	|	ProfilesRolesRights.Table.FullName AS Table,
	|	ProfilesRolesRights.Table.Name AS Object,
	|	ProfilesRolesRights.Table.Synonym AS ObjectPresentation,
	|	ProfilesRolesRights.Profile AS Profile,
	|	ProfilesRolesRights.Profile.Description AS ProfilePresentation,
	|	ProfilesRolesRights.Role.Name AS Role,
	|	ProfilesRolesRights.Role.Synonym AS RolePresentation,
	|	ProfilesRolesRights.KindOfRoles AS KindOfRoles,
	|	ProfilesRolesRights.ReadingNotLimited AS ReadingNotLimited,
	|	ProfilesRolesRights.view AS view,
	|	ProfilesRolesRights.AccessGroup AS AccessGroup,
	|	ProfilesRolesRights.AccessGroup.Description AS AccessGroupPresentation,
	|	ProfilesRolesRights.AccessKind AS AccessKind,
	|	ProfilesRolesRights.AccessKindPresentation AS AccessKindPresentation,
	|	ProfilesRolesRights.AllAllowed AS AllAllowed,
	|	ProfilesRolesRights.AccessValue AS AccessValue,
	|	PRESENTATION(ProfilesRolesRights.AccessValue) AS AccessValuePresentation
	|FROM
	|	(SELECT
	|		RolesRights.MetadataObject AS Table,
	|		ProfilesRoles.Ref AS Profile,
	|		CASE
	|			WHEN RolesRights.view
	|					AND RolesRights.ReadingNotLimited
	|				THEN 0
	|			WHEN NOT RolesRights.view
	|					AND RolesRights.ReadingNotLimited
	|				THEN 1
	|			WHEN RolesRights.view
	|					AND NOT RolesRights.ReadingNotLimited
	|				THEN 2
	|			ELSE 3
	|		END AS KindOfRoles,
	|		RolesRights.Role AS Role,
	|		RolesRights.ReadingNotLimited AS ReadingNotLimited,
	|		RolesRights.view AS view,
	|		UNDEFINED AS AccessGroup,
	|		UNDEFINED AS AccessKind,
	|		"""" AS AccessKindPresentation,
	|		UNDEFINED AS AllAllowed,
	|		UNDEFINED AS AccessValue
	|	FROM
	|		InformationRegister.RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupsProfiles.Roles AS ProfilesRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfilesRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfilesRoles.Role
	|	
	|	UNION
	|	
	|	SELECT
	|		RolesRights.MetadataObject,
	|		UserProfiles.Profile,
	|		1000,
	|		"""",
	|		FALSE,
	|		FALSE,
	|		AccessTypesAndValues.AccessGroup,
	|		ISNULL(AccessRestrictionKinds.AccessKind, UNDEFINED),
	|		ISNULL(AccessRestrictionKinds.AccessKindPresentation, """"),
	|		AccessTypesAndValues.AllAllowed,
	|		AccessTypesAndValues.AccessValue
	|	FROM
	|		InformationRegister.RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupsProfiles.Roles AS ProfilesRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfilesRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfilesRoles.Role
	|			INNER JOIN AccessTypesAndValues AS AccessTypesAndValues
	|			ON (UserProfiles.Profile = AccessTypesAndValues.Profile)
	|			LEFT JOIN AccessRestrictionKinds AS AccessRestrictionKinds
	|			ON (AccessRestrictionKinds.Table = RolesRights.MetadataObject)
	|				AND (AccessRestrictionKinds.Right = ""Read"")
	|				AND (AccessRestrictionKinds.AccessKind = AccessTypesAndValues.AccessKind)) AS ProfilesRolesRights
	|TOTALS
	|	MAX(ObjectsKindPresentation),
	|	MAX(ObjectsKindOrder),
	|	MAX(Table),
	|	MAX(ObjectPresentation),
	|	MAX(ProfilePresentation),
	|	MAX(RolePresentation),
	|	MAX(ReadingNotLimited),
	|	MAX(view),
	|	MAX(AccessGroupPresentation),
	|	MAX(AccessKindPresentation),
	|	MAX(AllAllowed)
	|BY
	|	ObjectsKind,
	|	Object,
	|	Profile,
	|	KindOfRoles,
	|	Role,
	|	AccessGroup,
	|	AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfilesRolesRights.Table.Parent.Name AS ObjectsKind,
	|	ProfilesRolesRights.Table.Parent.Synonym AS ObjectsKindPresentation,
	|	ProfilesRolesRights.Table.Parent.CollectionOrder AS ObjectsKindOrder,
	|	ProfilesRolesRights.Table.FullName AS Table,
	|	ProfilesRolesRights.Table.Name AS Object,
	|	ProfilesRolesRights.Table.Synonym AS ObjectPresentation,
	|	ProfilesRolesRights.Profile AS Profile,
	|	ProfilesRolesRights.Profile.Description AS ProfilePresentation,
	|	ProfilesRolesRights.Role.Name AS Role,
	|	ProfilesRolesRights.Role.Synonym AS RolePresentation,
	|	ProfilesRolesRights.KindOfRoles AS KindOfRoles,
	|	ProfilesRolesRights.Insert AS Insert,
	|	ProfilesRolesRights.Update AS Update1,
	|	ProfilesRolesRights.AddingNotLimited AS AddingNotLimited,
	|	ProfilesRolesRights.ChangingNotLimited AS ChangingNotLimited,
	|	ProfilesRolesRights.InteractiveInsert AS InteractiveInsert,
	|	ProfilesRolesRights.Edit AS Edit,
	|	ProfilesRolesRights.AccessGroup AS AccessGroup,
	|	ProfilesRolesRights.AccessGroup.Description AS AccessGroupPresentation,
	|	ProfilesRolesRights.AccessKind AS AccessKind,
	|	ProfilesRolesRights.AccessKindPresentation AS AccessKindPresentation,
	|	ProfilesRolesRights.AllAllowed AS AllAllowed,
	|	ProfilesRolesRights.AccessValue AS AccessValue,
	|	PRESENTATION(ProfilesRolesRights.AccessValue) AS AccessValuePresentation
	|FROM
	|	(SELECT
	|		RolesRights.MetadataObject AS Table,
	|		ProfilesRoles.Ref AS Profile,
	|		CASE
	|			WHEN RolesRights.AddingNotLimited
	|					AND RolesRights.ChangingNotLimited
	|				THEN 0
	|			WHEN NOT RolesRights.AddingNotLimited
	|					AND RolesRights.ChangingNotLimited
	|				THEN 100
	|			WHEN RolesRights.AddingNotLimited
	|					AND NOT RolesRights.ChangingNotLimited
	|				THEN 200
	|			ELSE 300
	|		END + CASE
	|			WHEN RolesRights.Insert
	|					AND RolesRights.Update
	|				THEN 0
	|			WHEN NOT RolesRights.Insert
	|					AND RolesRights.Update
	|				THEN 10
	|			WHEN RolesRights.Insert
	|					AND NOT RolesRights.Update
	|				THEN 20
	|			ELSE 30
	|		END + CASE
	|			WHEN RolesRights.InteractiveInsert
	|					AND RolesRights.Edit
	|				THEN 0
	|			WHEN NOT RolesRights.InteractiveInsert
	|					AND RolesRights.Edit
	|				THEN 1
	|			WHEN RolesRights.InteractiveInsert
	|					AND NOT RolesRights.Edit
	|				THEN 2
	|			ELSE 3
	|		END AS KindOfRoles,
	|		RolesRights.Role AS Role,
	|		RolesRights.Insert AS Insert,
	|		RolesRights.Update AS Update,
	|		RolesRights.AddingNotLimited AS AddingNotLimited,
	|		RolesRights.ChangingNotLimited AS ChangingNotLimited,
	|		RolesRights.InteractiveInsert AS InteractiveInsert,
	|		RolesRights.Edit AS Edit,
	|		UNDEFINED AS AccessGroup,
	|		UNDEFINED AS AccessKind,
	|		"""" AS AccessKindPresentation,
	|		UNDEFINED AS AllAllowed,
	|		UNDEFINED AS AccessValue
	|	FROM
	|		InformationRegister.RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupsProfiles.Roles AS ProfilesRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfilesRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfilesRoles.Role
	|				AND (RolesRights.Insert
	|					OR RolesRights.Update)
	|	
	|	UNION
	|	
	|	SELECT
	|		RolesRights.MetadataObject,
	|		UserProfiles.Profile,
	|		1000,
	|		"""",
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		AccessTypesAndValues.AccessGroup,
	|		ISNULL(AccessRestrictionKinds.AccessKind, UNDEFINED),
	|		ISNULL(AccessRestrictionKinds.AccessKindPresentation, """"),
	|		AccessTypesAndValues.AllAllowed,
	|		AccessTypesAndValues.AccessValue
	|	FROM
	|		InformationRegister.RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupsProfiles.Roles AS ProfilesRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfilesRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfilesRoles.Role
	|				AND (RolesRights.Insert)
	|			INNER JOIN AccessTypesAndValues AS AccessTypesAndValues
	|			ON (UserProfiles.Profile = AccessTypesAndValues.Profile)
	|			LEFT JOIN AccessRestrictionKinds AS AccessRestrictionKinds
	|			ON (AccessRestrictionKinds.Table = RolesRights.MetadataObject)
	|				AND (AccessRestrictionKinds.Right = ""Insert"")
	|				AND (AccessRestrictionKinds.AccessKind = AccessTypesAndValues.AccessKind)
	|	
	|	UNION
	|	
	|	SELECT
	|		RolesRights.MetadataObject,
	|		UserProfiles.Profile,
	|		1000,
	|		"""",
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		AccessTypesAndValues.AccessGroup,
	|		ISNULL(AccessRestrictionKinds.AccessKind, UNDEFINED),
	|		ISNULL(AccessRestrictionKinds.AccessKindPresentation, """"),
	|		AccessTypesAndValues.AllAllowed,
	|		AccessTypesAndValues.AccessValue
	|	FROM
	|		InformationRegister.RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupsProfiles.Roles AS ProfilesRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfilesRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfilesRoles.Role
	|				AND (RolesRights.Update)
	|			INNER JOIN AccessTypesAndValues AS AccessTypesAndValues
	|			ON (UserProfiles.Profile = AccessTypesAndValues.Profile)
	|			LEFT JOIN AccessRestrictionKinds AS AccessRestrictionKinds
	|			ON (AccessRestrictionKinds.Table = RolesRights.MetadataObject)
	|				AND (AccessRestrictionKinds.Right = ""Update"")
	|				AND (AccessRestrictionKinds.AccessKind = AccessTypesAndValues.AccessKind)) AS ProfilesRolesRights
	|TOTALS
	|	MAX(ObjectsKindPresentation),
	|	MAX(ObjectsKindOrder),
	|	MAX(Table),
	|	MAX(ObjectPresentation),
	|	MAX(ProfilePresentation),
	|	MAX(RolePresentation),
	|	MAX(Insert),
	|	MAX(Update1),
	|	MAX(AddingNotLimited),
	|	MAX(ChangingNotLimited),
	|	MAX(InteractiveInsert),
	|	MAX(Edit),
	|	MAX(AccessGroupPresentation),
	|	MAX(AccessKindPresentation),
	|	MAX(AllAllowed)
	|BY
	|	ObjectsKind,
	|	Object,
	|	Profile,
	|	KindOfRoles,
	|	Role,
	|	AccessGroup,
	|	AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessTypesAndValues.Profile,
	|	AccessTypesAndValues.AccessGroup,
	|	AccessTypesAndValues.AccessKind,
	|	AccessTypesAndValues.AllAllowed,
	|	AccessTypesAndValues.AccessValue
	|FROM
	|	AccessTypesAndValues AS AccessTypesAndValues";
	ResultsOfQuery = Query.ExecuteBatch();
	
	Document.StartRowAutoGrouping();
	
	If DetailedInformationAboutAccessRights Then
		// Display access groups.
		AccessGroupsDescriptionFulls = ResultsOfQuery[1].Unload(
			QueryResultIteration.ByGroups).Rows;
		
		OnePersonalGroup
			= AccessGroupsDescriptionFulls.Count() = 1
			AND ValueIsFilled(AccessGroupsDescriptionFulls[0].Participant);
		
		Area = Template.GetArea("AllAccessGroupsGroup");
		Area.Parameters.Fill(Properties);
		
		If OnePersonalGroup Then
			If TypeOf(Ref) = Type("CatalogRef.Users") Then
				AccessPresentation = NStr("en='User access limitations';ru='Ограничения доступа пользователя'");
				
			ElsIf TypeOf(Ref) = Type("CatalogRef.ExternalUsers") Then
				AccessPresentation = NStr("en='Access restrictions of external user';ru='Ограничения доступа внешнего пользователя'");
				
			ElsIf TypeOf(Ref) = Type("CatalogRef.UsersGroups") Then
				AccessPresentation = NStr("en = 'Access restrictions of user group'; ru = 'Ограничения доступа группы пользователей'");
			Else
				AccessPresentation = NStr("en = 'Access restrictions of external user group'; ru = 'Ограничения доступа группы внешних пользователей'");
			EndIf;
		Else
			If TypeOf(Ref) = Type("CatalogRef.Users") Then
				AccessPresentation = NStr("en = 'User access groups'; ru = 'Группы доступа пользователя'");
				
			ElsIf TypeOf(Ref) = Type("CatalogRef.ExternalUsers") Then
				AccessPresentation = NStr("en='Groups of external user access';ru='Группы доступа внешнего пользователя'");
				
			ElsIf TypeOf(Ref) = Type("CatalogRef.UsersGroups") Then
				AccessPresentation = NStr("en = 'Access groups user groups'; ru = 'Группы доступа группы пользователей'");
			Else
				AccessPresentation = NStr("en = 'Access groups external user groups'; ru = 'Группы доступа группы внешних пользователей'");
			EndIf;
		EndIf;
		
		Area.Parameters.AccessPresentation = AccessPresentation;
		
		Document.Put(Area, 1);
		Document.Put(AreaIndent, 2);
		
		For Each DescriptionOfAccessGroup IN AccessGroupsDescriptionFulls Do
			If Not OnePersonalGroup Then
				Area = Template.GetArea("AccessGroupGrouping");
				Area.Parameters.Fill(DescriptionOfAccessGroup);
				Document.Put(Area, 2);
			EndIf;
			// Display participation case in group.
			If DescriptionOfAccessGroup.Rows.Count() = 1
			   AND DescriptionOfAccessGroup.Rows[0].Participant = Ref Then
				// User belongs directly to the
				// access group only, so there is no need to show.
			Else
				Area = Template.GetArea("AccessGroupDetailsUserIncludedIntoGroup");
				Document.Put(Area, 3);
				If DescriptionOfAccessGroup.Rows.Find(Ref, "Participant") <> Undefined Then
					Area = Template.GetArea("AccessGroupUserIsInGroupDetailsAreClearly");
					Document.Put(Area, 3);
				EndIf;
				Filter = New Structure("GroupInvolvement", True);
				UsersGroupsDescriptionFull = DescriptionOfAccessGroup.Rows.FindRows(Filter);
				If UsersGroupsDescriptionFull.Count() > 0 Then
					
					Area = Template.GetArea(
						"AccessGroupDetailsUserIsInGroupAsParticipantOfGroupsUsers");
					
					Document.Put(Area, 3);
					For Each UserGroupLongDesription IN UsersGroupsDescriptionFull Do
						
						Area = Template.GetArea(
							"AccessGroupDetailsInUserGroupPresentationAsParticipant");
						
						Area.Parameters.Fill(UserGroupLongDesription);
						Document.Put(Area, 3);
					EndDo;
				EndIf;
			EndIf;
			
			If Not OnePersonalGroup Then
				// Display profile.
				Area = Template.GetArea("AccessGroupDetailsProfile");
				Area.Parameters.Fill(DescriptionOfAccessGroup);
				Document.Put(Area, 3);
			EndIf;
			
			// Show person who is responsible for the list of participants.
			If Not OnePersonalGroup AND ValueIsFilled(DescriptionOfAccessGroup.Responsible) Then
				Area = Template.GetArea("AccessGroupDetailsResponsible");
				Area.Parameters.Fill(DescriptionOfAccessGroup);
				Document.Put(Area, 3);
			EndIf;
			
			// Display description.
			If Not OnePersonalGroup AND ValueIsFilled(DescriptionOfAccessGroup.Definition) Then
				Area = Template.GetArea("AccessGroupDetailsDescriptionFull");
				Area.Parameters.Fill(DescriptionOfAccessGroup);
				Document.Put(Area, 3);
			EndIf;
			
			Document.Put(AreaIndent, 3);
			Document.Put(AreaIndent, 3);
		EndDo;
		
		// Display roles by profiles.
		RolesByProfiles = ResultsOfQuery[3].Unload(QueryResultIteration.ByGroups);
		RolesByProfiles.Rows.Sort("ProfilePresentation Asc, RolePresentation Asc");
		
		If RolesByProfiles.Rows.Count() > 0 Then
			Area = Template.GetArea("RolesByProfilesGrouping");
			Area.Parameters.Fill(Properties);
			Document.Put(Area, 1);
			Document.Put(AreaIndent, 2);
			
			For Each ProfileDescription IN RolesByProfiles.Rows Do
				Area = Template.GetArea("RolesByProfilesProfilePresentation");
				Area.Parameters.Fill(ProfileDescription);
				Document.Put(Area, 2);
				For Each RoleDescription IN ProfileDescription.Rows Do
					Area = Template.GetArea("RolesByProfilesRolePresentation");
					Area.Parameters.Fill(RoleDescription);
					Document.Put(Area, 3);
				EndDo;
			EndDo;
		EndIf;
		Document.Put(AreaIndent, 2);
		Document.Put(AreaIndent, 2);
	EndIf;
	
	// Display objects to view.
	ObjectRights = ResultsOfQuery[7].Unload(QueryResultIteration.ByGroups);
	
	ObjectRights.Rows.Sort(
		"ObjectsKindOrder Asc, 
		|ObjectPresentation Asc, 
		|ProfilePresentation Asc,
		|KindOfRoles Asc,
		|RolePresentation Asc,
		|AccessGroupPresentation Asc,
		|AccessKindPresentation Asc, AccessValuePresentation Asc",
		True);
	
	Area = Template.GetArea("ObjectRightsGrouping");
	Area.Parameters.ObjectRightsGroupingPresentation = NStr("en = 'View objects'; ru = 'Просмотр объектов'");
	Document.Put(Area, 1);
	Area = Template.GetArea("ObjectsViewLegend");
	Document.Put(Area, 2);
	
	OwnersOfRightsSettings = AccessManagementServiceReUse.Parameters(
		).PossibleRightsForObjectRightsSettings.ByRefsTypes;
	
	For Each ObjectsKindDescriptionFull IN ObjectRights.Rows Do
		Area = Template.GetArea("ObjectRightsTableTitle");
		If SimplifiedInterface Then
			Area.Parameters.ProfilePresentationsOrAccessGroups = NStr("en = 'Profiles'; ru = 'Профили'");
		Else
			Area.Parameters.ProfilePresentationsOrAccessGroups = NStr("en = 'Access groups'; ru = 'Группы доступа'");
		EndIf;
		Area.Parameters.Fill(ObjectsKindDescriptionFull);
		Document.Put(Area, 2);
		
		Area = Template.GetArea("ObjectRightsTableTitleAddit");
		If DetailedInformationAboutAccessRights Then
			Area.Parameters.ProfilePresentationsOrAccessGroups = NStr("en = '(profile, roles)'; ru = '(профиль, роли)'");
		Else
			Area.Parameters.ProfilePresentationsOrAccessGroups = "";
		EndIf;
		Area.Parameters.Fill(ObjectsKindDescriptionFull);
		Document.Put(Area, 3);
		
		For Each ObjectDescription IN ObjectsKindDescriptionFull.Rows Do
			InitialAreaStringObject = Undefined;
			FinalAreaOfStringObject  = Undefined;
			Area = Template.GetArea("ObjectRightsTableRow");
			
			Area.Parameters.OpenListForm = "OpenListForm: " + ObjectDescription.Table;
			
			If ObjectDescription.ReadingNotLimited Then
				If ObjectDescription.view Then
					ObjectPresentationClarification = NStr("en='(view, not limited)';ru='(просмотр, не ограничен)'");
				Else
					ObjectPresentationClarification = NStr("en='(view*, not limited)';ru='(просмотр*, не ограничен)'");
				EndIf;
			Else
				If ObjectDescription.view Then
					ObjectPresentationClarification = NStr("en='(view, limited)';ru='(просмотр, ограничен)'");
				Else
					ObjectPresentationClarification = NStr("en='(view*, limited)';ru='(просмотр*, ограничен)'");
				EndIf;
			EndIf;
			
			Area.Parameters.ObjectPresentation =
				ObjectDescription.ObjectPresentation + Chars.LF + ObjectPresentationClarification;
				
			For Each ProfileDescription IN ObjectDescription.Rows Do
				ProfileRolesPresentation = "";
				RolesCount = 0;
				AllRolesWithRestriction = True;
				For Each RoleKindsDescriptionFull IN ProfileDescription.Rows Do
					If RoleKindsDescriptionFull.KindOfRoles < 1000 Then
						// Role description with/without restrictions.
						For Each RoleDescription IN RoleKindsDescriptionFull.Rows Do
							
							If RoleKindsDescriptionFull.ReadingNotLimited Then
								AllRolesWithRestriction = False;
							EndIf;
							
							If Not DetailedInformationAboutAccessRights Then
								Continue;
							EndIf;
							
							If RoleKindsDescriptionFull.Rows.Count() > 1
							   AND RoleKindsDescriptionFull.Rows.IndexOf(RoleDescription)
							         < RoleKindsDescriptionFull.Rows.Count()-1 Then
								
								ProfileRolesPresentation
									= ProfileRolesPresentation
									+ RoleDescription.RolePresentation + ",";
								
								RolesCount = RolesCount + 1;
							EndIf;
							
							If RoleKindsDescriptionFull.Rows.IndexOf(RoleDescription) =
							         RoleKindsDescriptionFull.Rows.Count()-1 Then
								
								ProfileRolesPresentation
									= ProfileRolesPresentation
									+ RoleDescription.RolePresentation
									+ ",";
								
								RolesCount = RolesCount + 1;
							EndIf;
							ProfileRolesPresentation = ProfileRolesPresentation + Chars.LF;
						EndDo;
					ElsIf RoleKindsDescriptionFull.Rows[0].Rows.Count() > 0 Then
						// Access restriction description for roles with restriction.
						For Each DescriptionOfAccessGroup IN RoleKindsDescriptionFull.Rows[0].Rows Do
							IndexOf = DescriptionOfAccessGroup.Rows.Count()-1;
							While IndexOf >= 0 Do
								If DescriptionOfAccessGroup.Rows[IndexOf].AccessKind = Undefined Then
									DescriptionOfAccessGroup.Rows.Delete(IndexOf);
								EndIf;
								IndexOf = IndexOf-1;
							EndDo;
							InitialAreaStringAccessGroups = Undefined;
							If Area = Undefined Then
								Area = Template.GetArea("ObjectRightsTableRow");
							EndIf;
							If SimplifiedInterface Then
								Area.Parameters.ProfileOrAccessGroup = ProfileDescription.AccessGroup;
								
								Area.Parameters.ProfileOrAccessGroupPresentation =
									ProfileDescription.AccessGroupPresentation;
							Else
								Area.Parameters.ProfileOrAccessGroup = DescriptionOfAccessGroup.AccessGroup;
								If DetailedInformationAboutAccessRights Then
									ProfileRolesPresentation = TrimAll(ProfileRolesPresentation);
									
									If ValueIsFilled(ProfileRolesPresentation)
									   AND Right(ProfileRolesPresentation, 1) = "," Then
										
										ProfileRolesPresentation = Left(
											ProfileRolesPresentation,
											StrLen(ProfileRolesPresentation) - 1);
									EndIf;
									
									If RolesCount > 1 Then
										AccessGroupPresentationClarification =
											NStr("en = '(profile: %1, roles:
												|%2)'; 
												|ru = '(профиль: %1, роли:
												| %2)'")
									Else
										AccessGroupPresentationClarification =
											NStr("en = '(profile: %1, role:
												|%2)';
												|ru = '(профиль: %1, роль:
												|%2)'")
									EndIf;
									
									Area.Parameters.ProfileOrAccessGroupPresentation =
										DescriptionOfAccessGroup.AccessGroupPresentation
										+ Chars.LF
										+ StringFunctionsClientServer.SubstituteParametersInString(
											AccessGroupPresentationClarification,
											ProfileDescription.ProfilePresentation,
											TrimAll(ProfileRolesPresentation));
								Else
									Area.Parameters.ProfileOrAccessGroupPresentation =
										DescriptionOfAccessGroup.AccessGroupPresentation;
								EndIf;
							EndIf;
							If AllRolesWithRestriction Then
								If GetFunctionalOption("LimitAccessOnRecordsLevel") Then
									For Each AccessTypeDescription IN DescriptionOfAccessGroup.Rows Do
										IndexOf = AccessTypeDescription.Rows.Count()-1;
										While IndexOf >= 0 Do
											If Not ValueIsFilled(AccessTypeDescription.Rows[IndexOf].AccessValue) Then
												AccessTypeDescription.Rows.Delete(IndexOf);
											EndIf;
											IndexOf = IndexOf-1;
										EndDo;
										// Get new area if the kind of access is not the first.
										If Area = Undefined Then
											Area = Template.GetArea("ObjectRightsTableRow");
										EndIf;
										
										Area.Parameters.AccessKind = AccessTypeDescription.AccessKind;
										
										Area.Parameters.AccessKindPresentation =
											StringFunctionsClientServer.SubstituteParametersInString(
												AccessKindPresentationTemplate(
													AccessTypeDescription, OwnersOfRightsSettings),
												AccessTypeDescription.AccessKindPresentation);
										
										OutputArea(
											Document,
											Area,
											3,
											InitialAreaStringObject,
											FinalAreaOfStringObject,
											InitialAreaStringAccessGroups);
										
										For Each AccessValueDetails IN AccessTypeDescription.Rows Do
											Area = Template.GetArea("ObjectRightsTableRowAccessValues");
											
											Area.Parameters.AccessValuePresentation =
												AccessValueDetails.AccessValuePresentation;
										
											Area.Parameters.AccessValue =
												AccessValueDetails.AccessValue;
											
											OutputArea(
												Document,
												Area,
												3,
												InitialAreaStringObject,
												FinalAreaOfStringObject,
												InitialAreaStringAccessGroups);
										EndDo;
									EndDo;
								EndIf;
							EndIf;
							If Area <> Undefined Then
								OutputArea(
									Document,
									Area,
									3,
									InitialAreaStringObject,
									FinalAreaOfStringObject,
									InitialAreaStringAccessGroups);
							EndIf;
							// Setting the access kind limits for the current access group.
							SetLimitsOfAccessKindsAndValues(
								Document,
								InitialAreaStringAccessGroups,
								FinalAreaOfStringObject);
							// Merging cells of access group and setting limits.
							MergeCellsSetBorders(
								Document,
								InitialAreaStringAccessGroups,
								FinalAreaOfStringObject,
								3);
						EndDo;
					EndIf;
				EndDo;
			EndDo;
			// Merging object cells and setting limits.
			MergeCellsSetBorders(
				Document,
				InitialAreaStringObject,
				FinalAreaOfStringObject,
				2);
		EndDo;
		Document.Put(AreaIndent, 3);
		Document.Put(AreaIndent, 3);
		Document.Put(AreaIndent, 3);
		Document.Put(AreaIndent, 3);
	EndDo;
	Document.Put(AreaIndent, 2);
	Document.Put(AreaIndent, 2);
	
	// Display objects to edit.
	ObjectRights = ResultsOfQuery[8].Unload(QueryResultIteration.ByGroups);
	ObjectRights.Rows.Sort(
		"ObjectsKindOrder Asc, 
		|ObjectPresentation Asc, 
		|ProfilePresentation Asc,
		|KindOfRoles Asc,
		|RolePresentation Asc,
		|AccessGroupPresentation Asc,
		|AccessKindPresentation Asc, AccessValuePresentation Asc",
		True);
	
	Area = Template.GetArea("ObjectRightsGrouping");
	Area.Parameters.ObjectRightsGroupingPresentation = NStr("en='Object editing';ru='Редактирование объектов'");
	Document.Put(Area, 1);
	Area = Template.GetArea("EditObjectsOfLegend");
	Document.Put(Area, 2);
	
	For Each ObjectsKindDescriptionFull IN ObjectRights.Rows Do
		Area = Template.GetArea("ObjectRightsTableTitle");
		If SimplifiedInterface Then
			Area.Parameters.ProfilePresentationsOrAccessGroups = NStr("en = 'Profiles'; ru = 'Профили'");
		Else
			Area.Parameters.ProfilePresentationsOrAccessGroups = NStr("en = 'Access groups'; ru = 'Группы доступа'");
		EndIf;
		Area.Parameters.Fill(ObjectsKindDescriptionFull);
		Document.Put(Area, 2);
		
		Area = Template.GetArea("ObjectRightsTableTitleAddit");
		If DetailedInformationAboutAccessRights Then
			Area.Parameters.ProfilePresentationsOrAccessGroups = NStr("en = '(profile, roles)'; ru = '(профиль, роли)'");
		Else
			Area.Parameters.ProfilePresentationsOrAccessGroups = "";
		EndIf;
		Area.Parameters.Fill(ObjectsKindDescriptionFull);
		Document.Put(Area, 3);

		AddingUsed =
			Upper(Left(ObjectsKindDescriptionFull.ObjectsKind, StrLen("Register"))) <> Upper("Register");
		
		For Each ObjectDescription IN ObjectsKindDescriptionFull.Rows Do
			InitialAreaStringObject = Undefined;
			FinalAreaOfStringObject  = Undefined;
			Area = Template.GetArea("ObjectRightsTableRow");
			
			Area.Parameters.OpenListForm = "OpenListForm: " + ObjectDescription.Table;
			
			If AddingUsed Then
				If ObjectDescription.Insert AND ObjectDescription.Update1 Then
					If ObjectDescription.AddingNotLimited AND ObjectDescription.ChangingNotLimited Then
						If ObjectDescription.InteractiveInsert AND ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en = '(adding, not limited
																|modification, not limited)';
																|ru = '(добавление, не ограничено
																|изменение, не ограничено)'");
						ElsIf Not ObjectDescription.InteractiveInsert AND ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en = '(adding*, not limited
																|modification, not limited)';
																|ru = '(добавление*, не ограничено
																|изменение, не ограничено)'");
						ElsIf ObjectDescription.InteractiveInsert AND Not ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en = '(adding,  not limited
																|modification*, not limited)';
																|ru = '(добавление, не ограничено
																|изменение*, не ограничено)'");
						Else // NO ObjectDescription.InteractiveInsert AND NO ObjectDescription.Editing
							ObjectPresentationClarification = NStr("en = '(adding*,  not limited
																|modification*, not limited)';
																|ru = '(добавление*, не ограничено
																|изменение*, не ограничено)'");
						EndIf;
					ElsIf Not ObjectDescription.AddingNotLimited AND ObjectDescription.ChangingNotLimited Then
						If ObjectDescription.InteractiveInsert AND ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en = '(adding, limited
																|modification, not limited)';
																|ru = '(добавление, ограничено
																|изменение, не ограничено)'");
						ElsIf Not ObjectDescription.InteractiveInsert AND ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en = '(adding*, limited
																|modification, not limited)';
																|ru = '(добавление*, ограничено
																|изменение, не ограничено)'");
						ElsIf ObjectDescription.InteractiveInsert AND Not ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en = '(adding, limited
																|modification*, not limited)';
																|ru = '(добавление, ограничено
																|изменение*, не ограничено)'");
						Else // NO ObjectDescription.InteractiveInsert AND NO ObjectDescription.Editing
							ObjectPresentationClarification = NStr("en = '(adding*, limited
																|modification*, not limited)';
																|ru = '(добавление*, ограничено
																|изменение*, не ограничено)'");
						EndIf;
					ElsIf ObjectDescription.AddingNotLimited AND Not ObjectDescription.ChangingNotLimited Then
						If ObjectDescription.InteractiveInsert AND ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en = '(adding, not limited
																|modification, limited)';
																|ru = '(добавление, не ограничено
																|изменение, ограничено)'");
						ElsIf Not ObjectDescription.InteractiveInsert AND ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en = '(adding*, not limited
																|modification, limited)';
																|ru = '(добавление*, не ограничено
																|изменение, ограничено)'");
						ElsIf ObjectDescription.InteractiveInsert AND Not ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en = '(adding, not limited
																|modification*, limited)';
																|ru = '(добавление, не ограничено
																|изменение*, ограничено)'");
						Else // NO ObjectDescription.InteractiveInsert AND NO ObjectDescription.Editing
							ObjectPresentationClarification = NStr("en = '(adding*, not limited
																|modification*, limited)';
																|ru = '(добавление*, не ограничено
																|изменение*, ограничено)'");
						EndIf;
					Else // NO ObjectDescription.AddingWithoutRestriction AND NO ObjectDescription.ChangingWithoutRestriction
						If ObjectDescription.InteractiveInsert AND ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en = '(adding, limited
																|modification, limited)';
																|ru = '(добавление, ограничено
																|изменение, ограничено)'");
						ElsIf Not ObjectDescription.InteractiveInsert AND ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en = '(adding*, limited
																|modification, limited)';
																|ru = '(добавление*, ограничено
																|изменение, ограничено)'");
						ElsIf ObjectDescription.InteractiveInsert AND Not ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en = '(adding, limited
																|modification*, limited)';
																|ru = '(добавление, ограничено
																|изменение*, ограничено)'");
						Else // NO ObjectDescription.InteractiveInsert AND NO ObjectDescription.Editing
							ObjectPresentationClarification = NStr("en = '(adding*, limited
																|modification*, limited)';
																|ru = '(добавление*, ограничено
																|изменение*, ограничено)'");
						EndIf;
					EndIf;
					
				ElsIf Not ObjectDescription.Insert AND ObjectDescription.Update1 Then
					
					If ObjectDescription.ChangingNotLimited Then
						If ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en = '(adding is not available
																|modification, not limited)';
																|ru = '(добавление не доступно
																|изменение, не ограничено)'");
						Else // NO ObjectDescription.Editing
							ObjectPresentationClarification = NStr("en = '(adding is not available
																|modification*, not limited)';
																|ru = '(добавление не доступно
																|изменение*, не ограничено)'");
						EndIf;
					Else // NO ObjectDescription.ChangeWithoutRestriction
						If ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en = '(adding is not available
																|modification, limited)';
																|ru = '(добавление не доступно
																|изменение, ограничено)'");
						Else // NO ObjectDescription.Editing
							ObjectPresentationClarification = NStr("en = '(adding is not available
																|modification*, limited)';
																|ru = '(добавление не доступно
																|изменение*, ограничено)'");
						EndIf;
					EndIf;
					
				Else // NO ObjectDescription.Adding AND NO ObjectDescription.Changing
					ObjectPresentationClarification = NStr("en='(adding is not available
																|modification is not available)';
																|ru='(добавление не доступно
																|изменение не доступно)'");
				EndIf;
			Else
				If ObjectDescription.Update1 Then
					If ObjectDescription.ChangingNotLimited Then
						If ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en='(change, not limited)';ru='(изменение, не ограничено)'");
						Else // NO ObjectDescription.Editing
							ObjectPresentationClarification = NStr("en='(change *, not limited)';ru='(изменение*, не ограничено)'");
						EndIf;
					Else
						If ObjectDescription.Edit Then
							ObjectPresentationClarification = NStr("en='(change, limited)';ru='(изменение, ограничено)'");
						Else // NO ObjectDescription.Editing
							ObjectPresentationClarification = NStr("en='(change *, limited)';ru='(изменение*, ограничено)'");
						EndIf;
					EndIf;
				Else // NO ObjectDescription.Change
					ObjectPresentationClarification = NStr("en='(change is not available)';ru='(изменение не доступно)'");
				EndIf;
			EndIf;
			
			Area.Parameters.ObjectPresentation =
				ObjectDescription.ObjectPresentation + Chars.LF + ObjectPresentationClarification;
				
			For Each ProfileDescription IN ObjectDescription.Rows Do
				ProfileRolesPresentation = "";
				RolesCount = 0;
				AllRolesWithRestriction = True;
				For Each RoleKindsDescriptionFull IN ProfileDescription.Rows Do
					If RoleKindsDescriptionFull.KindOfRoles < 1000 Then
						// Role description with/without restrictions.
						For Each RoleDescription IN RoleKindsDescriptionFull.Rows Do
							
							If RoleKindsDescriptionFull.AddingNotLimited
							   AND RoleKindsDescriptionFull.ChangingNotLimited Then
								
								AllRolesWithRestriction = False;
							EndIf;
							
							If Not DetailedInformationAboutAccessRights Then
								Continue;
							EndIf;
							
							If RoleKindsDescriptionFull.Rows.Count() > 1
							   AND RoleKindsDescriptionFull.Rows.IndexOf(RoleDescription)
							         < RoleKindsDescriptionFull.Rows.Count()-1 Then
								
								ProfileRolesPresentation =
									ProfileRolesPresentation + RoleDescription.RolePresentation + ",";
								
								RolesCount = RolesCount + 1;
							EndIf;
							
							If RoleKindsDescriptionFull.Rows.IndexOf(RoleDescription) =
							         RoleKindsDescriptionFull.Rows.Count()-1 Then
								
								ProfileRolesPresentation =
									ProfileRolesPresentation + RoleDescription.RolePresentation + ",";
								
								RolesCount = RolesCount + 1;
							EndIf;
							ProfileRolesPresentation = ProfileRolesPresentation + Chars.LF;
						EndDo;
					ElsIf RoleKindsDescriptionFull.Rows[0].Rows.Count() > 0 Then
						// Access restriction description for roles with restriction.
						For Each DescriptionOfAccessGroup IN RoleKindsDescriptionFull.Rows[0].Rows Do
							IndexOf = DescriptionOfAccessGroup.Rows.Count()-1;
							While IndexOf >= 0 Do
								If DescriptionOfAccessGroup.Rows[IndexOf].AccessKind = Undefined Then
									DescriptionOfAccessGroup.Rows.Delete(IndexOf);
								EndIf;
								IndexOf = IndexOf-1;
							EndDo;
							InitialAreaStringAccessGroups = Undefined;
							If Area = Undefined Then
								Area = Template.GetArea("ObjectRightsTableRow");
							EndIf;
							If SimplifiedInterface Then
								Area.Parameters.ProfileOrAccessGroup = ProfileDescription.AccessGroup;
								Area.Parameters.ProfileOrAccessGroupPresentation = ProfileDescription.AccessGroupPresentation;
							Else
								Area.Parameters.ProfileOrAccessGroup = DescriptionOfAccessGroup.AccessGroup;
								If DetailedInformationAboutAccessRights Then
									ProfileRolesPresentation = TrimAll(ProfileRolesPresentation);
									
									If ValueIsFilled(ProfileRolesPresentation)
									   AND Right(ProfileRolesPresentation, 1) = "," Then
										
										ProfileRolesPresentation = Left(
											ProfileRolesPresentation,
											StrLen(ProfileRolesPresentation)-1);
									EndIf;
									If RolesCount > 1 Then
										AccessGroupPresentationClarification =
											NStr("en = '(profile: %1, roles:
												|%2)';
												|ru = '(профиль: %1, роли:
												|%2)'")
									Else
										AccessGroupPresentationClarification =
											NStr("en = '(profile: %1, role:
												|%2)';
												|ru = '(профиль: %1, роль:
												|%2)'")
									EndIf;
									
									Area.Parameters.ProfileOrAccessGroupPresentation =
										DescriptionOfAccessGroup.AccessGroupPresentation
										+ Chars.LF
										+ StringFunctionsClientServer.SubstituteParametersInString(
											AccessGroupPresentationClarification,
											ProfileDescription.ProfilePresentation,
											TrimAll(ProfileRolesPresentation));
								Else
									Area.Parameters.ProfileOrAccessGroupPresentation =
										DescriptionOfAccessGroup.AccessGroupPresentation;
								EndIf;
							EndIf;
							If AllRolesWithRestriction Then
								If GetFunctionalOption("LimitAccessOnRecordsLevel") Then
									For Each AccessTypeDescription IN DescriptionOfAccessGroup.Rows Do
										IndexOf = AccessTypeDescription.Rows.Count()-1;
										While IndexOf >= 0 Do
											If Not ValueIsFilled(AccessTypeDescription.Rows[IndexOf].AccessValue) Then
												AccessTypeDescription.Rows.Delete(IndexOf);
											EndIf;
											IndexOf = IndexOf-1;
										EndDo;
										IndexOf = AccessTypeDescription.Rows.Count()-1;
										While IndexOf >= 0 Do
											If Not ValueIsFilled(AccessTypeDescription.Rows[IndexOf].AccessValue) Then
												AccessTypeDescription.Rows.Delete(IndexOf);
											EndIf;
											IndexOf = IndexOf-1;
										EndDo;
										// Get new area if the kind of access is not the first.
										If Area = Undefined Then
											Area = Template.GetArea("ObjectRightsTableRow");
										EndIf;
									
										Area.Parameters.AccessKind = AccessTypeDescription.AccessKind;
										
										Area.Parameters.AccessKindPresentation =
											StringFunctionsClientServer.SubstituteParametersInString(
												AccessKindPresentationTemplate(
													AccessTypeDescription, OwnersOfRightsSettings),
												AccessTypeDescription.AccessKindPresentation);
										
										OutputArea(
											Document,
											Area,
											3,
											InitialAreaStringObject,
											FinalAreaOfStringObject,
											InitialAreaStringAccessGroups);
										
										For Each AccessValueDetails IN AccessTypeDescription.Rows Do
											Area = Template.GetArea("ObjectRightsTableRowAccessValues");
											
											Area.Parameters.AccessValuePresentation =
												AccessValueDetails.AccessValuePresentation;
											
											Area.Parameters.AccessValue =
												AccessValueDetails.AccessValue;
												
											OutputArea(
												Document,
												Area,
												3,
												InitialAreaStringObject,
												FinalAreaOfStringObject,
												InitialAreaStringAccessGroups);
										EndDo;
									EndDo;
								EndIf;
							EndIf;
							If Area <> Undefined Then
								OutputArea(
									Document,
									Area,
									3,
									InitialAreaStringObject,
									FinalAreaOfStringObject,
									InitialAreaStringAccessGroups);
							EndIf;
							// Setting the access kind limits for the current access group.
							SetLimitsOfAccessKindsAndValues(
								Document,
								InitialAreaStringAccessGroups,
								FinalAreaOfStringObject);
							
							// Merging cells of access group and setting limits.
							MergeCellsSetBorders(
								Document,
								InitialAreaStringAccessGroups,
								FinalAreaOfStringObject,
								3);
						EndDo;
					EndIf;
				EndDo;
			EndDo;
			// Merging object cells and setting limits.
			MergeCellsSetBorders(
				Document,
				InitialAreaStringObject,
				FinalAreaOfStringObject,
				2);
		EndDo;
		Document.Put(AreaIndent, 3);
		Document.Put(AreaIndent, 3);
		Document.Put(AreaIndent, 3);
		Document.Put(AreaIndent, 3);
	EndDo;
	Document.Put(AreaIndent, 2);
	Document.Put(AreaIndent, 2);
	
	// Display rights on objects
	RightSettings = ResultsOfQuery[4].Unload(QueryResultIteration.ByGroups);
	RightSettings.Columns.Add("ObjectTypeFullDescription");
	RightSettings.Columns.Add("ObjectsKindPresentation");
	RightSettings.Columns.Add("FullDescr");
	
	For Each ObjectTypeDescription IN RightSettings.Rows Do
		TypeMetadata = Metadata.FindByType(ObjectTypeDescription.ObjectsType);
		ObjectTypeDescription.ObjectTypeFullDescription      = TypeMetadata.FullName();
		ObjectTypeDescription.ObjectsKindPresentation = TypeMetadata.Presentation();
	EndDo;
	RightSettings.Rows.Sort("ObjectsKindPresentation Asc");
	
	PossibleRights = AccessManagementServiceReUse.Parameters().PossibleRightsForObjectRightsSettings;
	
	For Each ObjectTypeDescription IN RightSettings.Rows Do
		
		RightsDescriptionFull = PossibleRights.ByRefsTypes.Get(ObjectTypeDescription.ObjectsType);
		
		If PossibleRights.HierarchicalTables.Get(ObjectTypeDescription.ObjectsType) = Undefined Then
			RootObjectTypeItems = Undefined;
		Else
			RootObjectTypeItems = RootObjectTypeItems(ObjectTypeDescription.ObjectsType);
		EndIf;
		
		For Each ObjectDescription IN ObjectTypeDescription.Rows Do
			ObjectDescription.FullDescr = ObjectDescription.Object.FullDescr();
		EndDo;
		ObjectTypeDescription.Rows.Sort("FullDescr Asc");
		
		Area = Template.GetArea("RightsSettingsGrouping");
		Area.Parameters.Fill(ObjectTypeDescription);
		Document.Put(Area, 1);
		
		// Display legend
		Area = Template.GetArea("RightsSettingsLegendHeader");
		Document.Put(Area, 2);
		For Each RightDetails IN RightsDescriptionFull Do
			Area = Template.GetArea("RightsSettingsLegendRow");
			Area.Parameters.Title = StrReplace(RightDetails.Title, Chars.LF, " ");
			Area.Parameters.ToolTip = StrReplace(RightDetails.ToolTip, Chars.LF, " ");
			Document.Put(Area, 2);
		EndDo;
		
		TitleForSubfolders =
			NStr("en = 'For subfolders'; ru = 'Для подпапок'");
		PromtForSubfolders = NStr("en = 'Rights are not only to the current folder but also for its subfolders'; ru = 'Права не только для текущей папки, но и для ее нижестоящих папок'");
		
		Area = Template.GetArea("RightsSettingsLegendRow");
		Area.Parameters.Title = StrReplace(TitleForSubfolders, Chars.LF, " ");
		Area.Parameters.ToolTip = StrReplace(PromtForSubfolders, Chars.LF, " ");
		Document.Put(Area, 2);
		
		TitleSettingIsReceivedFromGroup = NStr("en='Rights setting received from group';ru='Настройка прав получена от группы'");
		
		Area = Template.GetArea("RightsSettingsLegendRowInheritance");
		Area.Parameters.ToolTip = NStr("en='Rights inheritance from upstream folders';ru='Наследование прав от вышестоящих папок'");
		Document.Put(Area, 2);
		
		Document.Put(AreaIndent, 2);
		
		// Preparing row layout
		HeaderTemplate  = New SpreadsheetDocument;
		RowTemplate = New SpreadsheetDocument;
		DisplayUsersGroups = ObjectTypeDescription.GroupInvolvement AND Not OutputGroupRights;
		ColumnsCount = RightsDescriptionFull.Count() + ?(DisplayUsersGroups, 2, 1);
		
		For ColumnNumber = 1 To ColumnsCount Do
			NewHeaderCell  = Template.GetArea("RightsSettingsDetailsHeaderCell");
			HeaderCell = HeaderTemplate.Join(NewHeaderCell);
			HeaderCell.HorizontalAlign = HorizontalAlign.Center;
			NewCellRows = Template.GetArea("RightsSettingsDetailsCellRows");
			RowCell = RowTemplate.Join(NewCellRows);
			RowCell.HorizontalAlign = HorizontalAlign.Center;
		EndDo;
		
		If DisplayUsersGroups Then
			HeaderCell.HorizontalAlign  = HorizontalAlign.Left;
			RowCell.HorizontalAlign = HorizontalAlign.Left;
		EndIf;
		
		// Display table header
		CellNumberForSubfolders = "R1C" + Format(RightsDescriptionFull.Count()+1, "NG=");
		
		HeaderTemplate.Area(CellNumberForSubfolders).Text = TitleForSubfolders;
		HeaderTemplate.Area(CellNumberForSubfolders).ColumnWidth =
			MaxStringLength(HeaderTemplate.Area(CellNumberForSubfolders).Text);
		
		Shift = 1;
		
		AreaCurrentNumber = Shift;
		For Each RightDetails IN RightsDescriptionFull Do
			CellNumber = "R1C" + Format(AreaCurrentNumber, "NG=");
			HeaderTemplate.Area(CellNumber).Text = RightDetails.Title;
			HeaderTemplate.Area(CellNumber).ColumnWidth = MaxStringLength(RightDetails.Title);
			AreaCurrentNumber = AreaCurrentNumber + 1;
			
			RowTemplate.Area(CellNumber).ColumnWidth = HeaderTemplate.Area(CellNumber).ColumnWidth;
		EndDo;
		
		If DisplayUsersGroups Then
			CellNumberForGroup = "R1C" + Format(ColumnsCount, "NG=");
			HeaderTemplate.Area(CellNumberForGroup).Text = TitleSettingIsReceivedFromGroup;
			HeaderTemplate.Area(CellNumberForGroup).ColumnWidth = 35;
		EndIf;
		Document.Put(HeaderTemplate, 2);
		
		TextYes  = NStr("en='Yes';ru='Да'");
		TextNo = NStr("en = 'No'; ru = 'Нет'");
		
		// Display table rows
		For Each ObjectDescription IN ObjectTypeDescription.Rows Do
			
			If RootObjectTypeItems = Undefined
			 OR RootObjectTypeItems.Get(ObjectDescription.Object) <> Undefined Then
				Area = Template.GetArea("RightsSettingsDetailsObject");
				
			ElsIf ObjectDescription.Inherit Then
				Area = Template.GetArea("RightsSettingsDetailsObjectInheritYes");
			Else
				Area = Template.GetArea("RightsSettingsDetailsObjectInheritNo");
			EndIf;
			
			Area.Parameters.Fill(ObjectDescription);
			Document.Put(Area, 2);
			For Each UserDetails IN ObjectDescription.Rows Do
				
				For RightAreaNumber = 1 To ColumnsCount Do
					CellNumber = "R1C" + Format(RightAreaNumber, "NG=");
					RowTemplate.Area(CellNumber).Text = "";
				EndDo;
				
				If TypeOf(UserDetails.InheritanceAllowed) = Type("Boolean") Then
					RowTemplate.Area(CellNumberForSubfolders).Text = ?(
						UserDetails.InheritanceAllowed, TextYes, TextNo);
				EndIf;
				
				OwnerRights = PossibleRights.ByTypes.Get(ObjectTypeDescription.ObjectsType);
				For Each CurrentRightDescription IN UserDetails.Rows Do
					OwnerRight = OwnerRights.Get(CurrentRightDescription.Right);
					If OwnerRight <> Undefined Then
						RightAreaNumber = OwnerRight.RightIndex + Shift;
						CellNumber = "R1C" + Format(RightAreaNumber, "NG=");
						RowTemplate.Area(CellNumber).Text = ?(
							CurrentRightDescription.RightDenied, TextNo, TextYes);
					EndIf;
				EndDo;
				If DisplayUsersGroups Then
					If UserDetails.GroupInvolvement Then
						RowTemplate.Area(CellNumberForGroup).Text =
							UserDetails.UserDescription;
						RowTemplate.Area(CellNumberForGroup).DetailsParameter = "User";
						RowTemplate.Parameters.User = UserDetails.User;
					EndIf;
				EndIf;
				RowTemplate.Area(CellNumberForGroup).ColumnWidth = 35;
				Document.Put(RowTemplate, 2);
			EndDo;
		EndDo;
	EndDo;
	
	Document.EndRowAutoGrouping();
	
EndProcedure

&AtServer
Function AccessKindPresentationTemplate(AccessTypeDescription, OwnersOfRightsSettings)
	
	If AccessTypeDescription.Rows.Count() = 0 Then
		If OwnersOfRightsSettings.Get(TypeOf(AccessTypeDescription.AccessKind)) <> Undefined Then
			AccessKindPresentationTemplate = "%1";
		ElsIf AccessTypeDescription.AllAllowed Then
			If AccessTypeDescription.AccessKind = Catalogs.Users.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en='%1 (no prohibited, the current  user is always permitted)';ru='%1 (без запрещенных, текущий пользователь всегда разрешен)'");
				
			ElsIf AccessTypeDescription.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en='%1 (no prohibited, the current external user is always permitted)';ru='%1 (без запрещенных, текущий внешний пользователь всегда разрешен)'");
			Else
				AccessKindPresentationTemplate = NStr("en = '%1 (without prohibited)'; ru = '%1 (без запрещенных)'");
			EndIf;
		Else
			If AccessTypeDescription.AccessKind = Catalogs.Users.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en='%1 (without permitted, current user is always permitted)';ru='%1 (без разрешенных, текущий пользователь всегда разрешен)'");
				
			ElsIf AccessTypeDescription.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en='%1 (no permitted, the current external user is always permitted)';ru='%1 (без разрешенных, текущий внешний пользователь всегда разрешен)'");
			Else
				AccessKindPresentationTemplate = NStr("en='%1 (without permitted)';ru='%1 (без разрешенных)'");
			EndIf;
		EndIf;
	Else
		If AccessTypeDescription.AllAllowed Then
			If AccessTypeDescription.AccessKind = Catalogs.Users.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en='%1 (prohibited, the current user is always permitted):';ru='%1 (запрещенные, текущий пользователь всегда разрешен):'");
				
			ElsIf AccessTypeDescription.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en='%1  (prohibited, the current external user is always permitted):';ru='%1 (запрещенные, текущий внешний пользователь всегда разрешен):'");
			Else
				AccessKindPresentationTemplate = NStr("en='%1 (prohibited):';ru='%1 (запрещенные):'");
			EndIf;
		Else
			If AccessTypeDescription.AccessKind = Catalogs.Users.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en='%1 (permitted, the current user is always permitted):';ru='%1 (разрешенные, текущий пользователь всегда разрешен):'");
				
			ElsIf AccessTypeDescription.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en='%1 (permitted, the current external user is always permitted):';ru='%1 (разрешенные, текущий внешний пользователь всегда разрешен):'");
			Else
				AccessKindPresentationTemplate = NStr("en='%1 (permitted):';ru='%1 (разрешенные):'");
			EndIf;
		EndIf;
	EndIf;
	
	Return AccessKindPresentationTemplate;
	
EndFunction

&AtServer
Procedure OutputArea(Val Document,
                         Area,
                         Level,
                         InitialAreaStringObject,
                         FinalAreaOfStringObject,
                         InitialAreaStringAccessGroups)
	
	If InitialAreaStringObject = Undefined Then
		InitialAreaStringObject = Document.Put(Area, Level);
		FinalAreaOfStringObject        = InitialAreaStringObject;
	Else
		FinalAreaOfStringObject = Document.Put(Area);
	EndIf;
	
	If InitialAreaStringAccessGroups = Undefined Then
		InitialAreaStringAccessGroups = FinalAreaOfStringObject;
	EndIf;
	
	Area = Undefined;
	
EndProcedure

&AtServer
Procedure MergeCellsSetBorders(Val Document,
                                            Val AreaStartRow,
                                            Val AreaEndRow,
                                            Val ColumnNumber)
	
	Area = Document.Area(
		AreaStartRow.Top,
		ColumnNumber,
		AreaEndRow.Bottom,
		ColumnNumber);
	
	Area.Merge();
	
	BorderLine = New Line(SpreadsheetDocumentCellLineType.Dotted);
	
	Area.TopBorder = BorderLine;
	Area.BottomBorder  = BorderLine;
	
EndProcedure
	
&AtServer
Procedure SetLimitsOfAccessKindsAndValues(Val Document,
                                                 Val InitialAreaStringAccessGroups,
                                                 Val FinalAreaOfStringObject)
	
	BorderLine = New Line(SpreadsheetDocumentCellLineType.Dotted);
	
	Area = Document.Area(
		InitialAreaStringAccessGroups.Top,
		4,
		InitialAreaStringAccessGroups.Top,
		5);
	
	Area.TopBorder = BorderLine;
	
	Area = Document.Area(
		FinalAreaOfStringObject.Bottom,
		4,
		FinalAreaOfStringObject.Bottom,
		5);
	
	Area.BottomBorder = BorderLine;
	
EndProcedure

&AtServer
Function StartModePresentation(RunMode)
	
	If RunMode = "Auto" Then
		StartModePresentation = NStr("en='Auto';ru='Авто'");
		
	ElsIf RunMode = "OrdinaryApplication" Then
		StartModePresentation = NStr("en='Standard application';ru='Обычное приложение'");
		
	ElsIf RunMode = "ManagedApplication" Then
		StartModePresentation = NStr("en='Managed application';ru='Управляемое приложение'");
	Else
		StartModePresentation = "";
	EndIf;
	
	Return StartModePresentation;
	
EndFunction

&AtServer
Function LanguagePresentation(Language)
	
	LanguagePresentation = "";
	
	For Each LanguageMetadata IN Metadata.Languages Do
	
		If LanguageMetadata.Name = Language Then
			LanguagePresentation = LanguageMetadata.Synonym;
			Break;
		EndIf;
	EndDo;
	
	Return LanguagePresentation;
	
EndFunction

// Function MetadataObjectsRightsRestrictionKinds
// returns value table containing the
// access restriction kind by each metadata object right.
//  If there is no record by right, there are no restrictions by right.
//
// Returns:
//  ValueTable:
//    AccessKind    - Ref - Empty reference of main value type of access kind.
//    Presentation - String - access kind presentation.
//    Table       - CatalogRef.MetadataObjectIDs,
//                    for example CatalogRef.Counterparties.
//    Right         - String: "Reading" "Change".
//
&AtServer
Function MetadataObjectsRightsRestrictionKinds()
	
	Cache = AccessManagementServiceReUse.MetadataObjectsRightsRestrictionKinds();
	
	If CurrentSessionDate() < Cache.UpdateDate + 60*30 Then
		Return Cache.Table;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("ConstantRestrictionKinds",
		AccessManagementServiceReUse.ConstantRightsRestrictionKindsOfMetadataObjects());
	
	Query.SetParameter("AccessKindsValueTypes",
		AccessManagementServiceReUse.AccessKindsValueAndRightSettingOwnersTypes());
	
	UsedAccessKinds = AccessManagementServiceReUse.AccessKindsValueAndRightSettingOwnersTypes(
		).Copy(, "AccessKind");
	
	UsedAccessKinds.GroupBy("AccessKind");
	UsedAccessKinds.Columns.Add("Presentation", New TypeDescription("String", ,,, New StringQualifiers(150)));
	
	IndexOf = UsedAccessKinds.Count()-1;
	While IndexOf >= 0 Do
		String = UsedAccessKinds[IndexOf];
		AccessTypeProperties = AccessManagementService.AccessTypeProperties(String.AccessKind);
		
		If AccessTypeProperties = Undefined Then
			RightSettingsOwnerMetadata = Metadata.FindByType(TypeOf(String.AccessKind));
			If RightSettingsOwnerMetadata = Undefined Then
				String.Presentation = NStr("en='Unknown access kind';ru='Неизвестный вид доступа'");
			Else
				String.Presentation = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Set rights to %1';ru='Настройки прав на %1'"), RightSettingsOwnerMetadata.Presentation());
			EndIf;
		ElsIf AccessManagementService.AccessKindIsUsed(String.AccessKind) Then
			String.Presentation = AccessTypeProperties.Presentation;
		Else
			UsedAccessKinds.Delete(String);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Query.SetParameter("UsedAccessKinds", UsedAccessKinds);
	
	Query.Text =
	"SELECT
	|	ConstantRestrictionKinds.Table,
	|	ConstantRestrictionKinds.Right,
	|	ConstantRestrictionKinds.AccessKind,
	|	ConstantRestrictionKinds.ObjectTable
	|INTO ConstantRestrictionKinds
	|FROM
	|	&ConstantRestrictionKinds AS ConstantRestrictionKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKindsValueTypes.AccessKind,
	|	AccessKindsValueTypes.ValuesType
	|INTO AccessKindsValueTypes
	|FROM
	|	&AccessKindsValueTypes AS AccessKindsValueTypes
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UsedAccessKinds.AccessKind,
	|	UsedAccessKinds.Presentation
	|INTO UsedAccessKinds
	|FROM
	|	&UsedAccessKinds AS UsedAccessKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ConstantRestrictionKinds.Table,
	|	""Read"" AS Right1,
	|	VALUETYPE(SetRows.AccessValue) AS ValuesType
	|INTO VariableRestrictionKinds
	|FROM
	|	InformationRegister.AccessValuesSets AS SetNumbers
	|		INNER JOIN ConstantRestrictionKinds AS ConstantRestrictionKinds
	|		ON (ConstantRestrictionKinds.Right = ""Read"")
	|			AND (ConstantRestrictionKinds.AccessKind = UNDEFINED)
	|			AND (VALUETYPE(SetNumbers.Object) = VALUETYPE(ConstantRestrictionKinds.ObjectTable))
	|			AND (SetNumbers.Read)
	|		INNER JOIN InformationRegister.AccessValuesSets AS SetRows
	|		ON (SetRows.Object = SetNumbers.Object)
	|			AND (SetRows.NumberOfSet = SetNumbers.NumberOfSet)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	ConstantRestrictionKinds.Table,
	|	""Update"",
	|	VALUETYPE(SetRows.AccessValue)
	|FROM
	|	InformationRegister.AccessValuesSets AS SetNumbers
	|		INNER JOIN ConstantRestrictionKinds AS ConstantRestrictionKinds
	|		ON (ConstantRestrictionKinds.Right = ""Update"")
	|			AND (ConstantRestrictionKinds.AccessKind = UNDEFINED)
	|			AND (VALUETYPE(SetNumbers.Object) = VALUETYPE(ConstantRestrictionKinds.ObjectTable))
	|			AND (SetNumbers.Update)
	|		INNER JOIN InformationRegister.AccessValuesSets AS SetRows
	|		ON (SetRows.Object = SetNumbers.Object)
	|			AND (SetRows.NumberOfSet = SetNumbers.NumberOfSet)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ConstantRestrictionKinds.Table,
	|	ConstantRestrictionKinds.Right,
	|	AccessKindsValueTypes.AccessKind
	|INTO AllAccessRestrictionKinds
	|FROM
	|	ConstantRestrictionKinds AS ConstantRestrictionKinds
	|		INNER JOIN AccessKindsValueTypes AS AccessKindsValueTypes
	|		ON ConstantRestrictionKinds.AccessKind = AccessKindsValueTypes.AccessKind
	|			AND (ConstantRestrictionKinds.AccessKind <> UNDEFINED)
	|
	|UNION
	|
	|SELECT
	|	VariableRestrictionKinds.Table,
	|	VariableRestrictionKinds.Right1,
	|	AccessKindsValueTypes.AccessKind
	|FROM
	|	VariableRestrictionKinds AS VariableRestrictionKinds
	|		INNER JOIN AccessKindsValueTypes AS AccessKindsValueTypes
	|		ON (VariableRestrictionKinds.ValuesType = VALUETYPE(AccessKindsValueTypes.ValuesType))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AllAccessRestrictionKinds.Table,
	|	AllAccessRestrictionKinds.Right,
	|	AllAccessRestrictionKinds.AccessKind,
	|	UsedAccessKinds.Presentation
	|FROM
	|	AllAccessRestrictionKinds AS AllAccessRestrictionKinds
	|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
	|		ON AllAccessRestrictionKinds.AccessKind = UsedAccessKinds.AccessKind";
	
	Exporting = Query.Execute().Unload();
	
	Cache.Table = Exporting;
	Cache.UpdateDate = CurrentSessionDate();
	
	Return Exporting;
	
EndFunction

&AtServer
Function MaxStringLength(MultilineString, InitialLength = 5)
	
	For LineNumber = 1 To StrLineCount(MultilineString) Do
		SubstringLength = StrLen(StrGetLine(MultilineString, LineNumber));
		If InitialLength < SubstringLength Then
			InitialLength = SubstringLength;
		EndIf;
	EndDo;
	
	Return InitialLength + 1;
	
EndFunction

&AtServer
Function RootObjectTypeItems(ObjectsType)
	
	TableName = Metadata.FindByType(ObjectsType).FullName();
	
	Query = New Query;
	Query.SetParameter("EmptyRef",
		CommonUse.ObjectManagerByFullName(TableName).EmptyRef());
	
	Query.Text =
	"SELECT
	|	CurrentTable.Ref AS Ref
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.Parent = &EmptyRef";
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", TableName);
	Selection = Query.Execute().Select();
	
	RootItems = New Map;
	While Selection.Next() Do
		RootItems.Insert(Selection.Ref, True);
	EndDo;
	
	Return RootItems;
	
EndFunction

#EndRegion
