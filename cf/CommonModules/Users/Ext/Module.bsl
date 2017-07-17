////////////////////////////////////////////////////////////////////////////////
// Subsystem "Users".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Main  procedures and functions.

// See the function with the same name in the UsersClientServer common module.
Function AuthorizedUser() Export
	
	Return UsersClientServer.AuthorizedUser();
	
EndFunction

// See the function with the same name in the UsersClientServer common module.
Function CurrentUser() Export
	
	Return UsersClientServer.CurrentUser();
	
EndFunction

// Checks whether the current or specified user is a full one.
// 
// Full user a)
// has FullRights role and system administration role if
// the infobase users list is not empty (if CheckSystemAdministratorRights = True)
// b) configuration main role is not
// specified or FullRights if the infobase users list is empty.
//
// Parameters:
//  User - Undefined - check the current infobase.
//               - CatalogRef.Users, CatalogRef.ExternalUsers - search
//                    for IB user by the unique ID specified in the attribute.
//                    InfobaseUserID. If the infobase user is not found, False returns.
//               - InfobaseUser - the specified infobase user is checked.
//
//  CheckSystemAdministrationRights - Boolean - if True is specified, then
//                 check whether there is role for system administation.
//
//  ForPrivilegedMode - Boolean - if True is specified, for the
//                 current user the function returns True, when the privileged mode is set.
//
// Returns:
//  Boolean - if True, the user has the full rights.
//
Function InfobaseUserWithFullAccess(User = Undefined,
                                    CheckSystemAdministrationRights = False,
                                    ForPrivilegedMode = True) Export
	
	PrivilegedModeIsInstalled = PrivilegedMode();
	
	SetPrivilegedMode(True);
	Properties = CheckedInfobaseUserProperties(User);
	IBUser = Properties.IBUser;
	
	ValidateFullAccessRole = Not CheckSystemAdministrationRights;
	ValidateRoleAdministratorSystem = CheckSystemAdministrationRights;
	
	If IBUser = Undefined Then
		Return False;
	ElsIf Not Properties.IsCurrentInfobaseUser Then
		// Roles in the written IB user are checked for the non-current user.
		If ValidateFullAccessRole
		   AND Not IBUser.Roles.Contains(Metadata.Roles.FullRights) Then
			Return False;
		EndIf;
		If ValidateRoleAdministratorSystem
		   AND Not IBUser.Roles.Contains(SystemAdministratorRole(True)) Then
			Return False;
		EndIf;
		Return True;
	Else
		If ForPrivilegedMode AND PrivilegedModeIsInstalled Then
			Return True;
		EndIf;
		
		If StandardSubsystemsReUse.PrivilegedModeInstalledOnLaunch() Then
			// User is a full one if the
			// privileged mode is set when client application is started with the UsePrivilegedMode parameter.
			Return True;
		EndIf;
		
		If Not ValueIsFilled(IBUser.Name) AND Metadata.DefaultRoles.Count() = 0 Then
			// When the main roles are not specified, then
			// unspecified user has all rights (as in the privileged mode).
			Return True;
		EndIf;
		
		If Not ValueIsFilled(IBUser.Name)
		   AND PrivilegedModeIsInstalled
		   AND AccessRight("Administration", Metadata, IBUser) Then
			// If the unspecified user has
			// the Administration right, then the privileged mode
			// is always considered for the start parameter UsePrivilegedMode support in the non-client application.
			Return True;
		EndIf;
		
		// For the current IB user the roles in the current
		// session are checked, not roles in the written IB user.
		If ValidateFullAccessRole
		   AND Not IsInRole(Metadata.Roles.FullRights) Then // Do not replace with RolesAvailable.
			Return False;
		EndIf;
		If ValidateRoleAdministratorSystem
		   AND Not IsInRole(SystemAdministratorRole(True)) Then // Do not replace with RolesAvailable.
			Return False;
		EndIf;
		Return True;
	EndIf;
	
EndFunction

// Returns the availability of at least one of
// the specified roles or user fullness (of the current or the specified one).
//
// Parameters:
//  RoleNames   - String - names of roles, separated by commas, availability of which is checked.
//
//  User - Undefined - check the current infobase.
//               - CatalogRef.Users, CatalogRef.ExternalUsers - search
//                    for IB user by the unique ID specified in the attribute.
//                    InfobaseUserID. If the infobase user is not found, False returns.
//               - InfobaseUser - the specified infobase user is checked.
//
//  ForPrivilegedMode - Boolean - if True is specified, for the
//                 current user the function returns True, when the privileged mode is set.
//
// Returns:
//  Boolean - True if at least one of the
//           specified roles is available or the IsFullUser(User) function returns True.
//
Function RolesAvailable(RoleNames,
                     User = Undefined,
                     ForPrivilegedMode = True) Export
	
	If InfobaseUserWithFullAccess(User, , ForPrivilegedMode) Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	Properties = CheckedInfobaseUserProperties(User);
	IBUser = Properties.IBUser;
	
	If IBUser = Undefined Then
		Return False;
	EndIf;
	
	RoleNameArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(RoleNames);
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementService = CommonUse.CommonModule("AccessManagementService");
		ModuleAccessManagementService.BeforeCheckingAvailabilityOfRoles(RoleNameArray);
	EndIf;
	
	For Each RoleName IN RoleNameArray Do
		
		If Properties.IsCurrentInfobaseUser Then
			If IsInRole(TrimAll(RoleName)) Then // Do not replace with RolesAvailable.
				Return True;
			EndIf;
		Else
			If IBUser.Roles.Contains(Metadata.Roles.Find(TrimAll(RoleName))) Then
				Return True;
			EndIf;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Checks whether IB user has at least one authentication kind.
//
// Parameters:
//  IBUserDescription - UUID - of the infobase user.
//                         - Structure - contains 3 authentification properties:
//                             * AuthenticationStandard - Boolean -
//                             * OSAuthentification          - Boolean -
//                             * AuthenticationOpenID      - Boolean -
//                         - InfobaseUser -
//                         - CatalogRef.Users -
//                         - CatalogRef.ExternalUsers -
//
// Returns:
//  Boolean - True if at least one authentication property is True.
//
Function CanLogOnToApplication(IBUserDescription) Export
	
	SetPrivilegedMode(True);
	
	UUID = Undefined;
	
	If TypeOf(IBUserDescription) = Type("CatalogRef.Users")
	 Or TypeOf(IBUserDescription) = Type("CatalogRef.ExternalUsers") Then
		
		UUID = CommonUse.ObjectAttributeValue(
			IBUserDescription, "InfobaseUserID");
		
		If TypeOf(IBUserDescription) <> Type("UUID") Then
			Return False;
		EndIf;
		
	ElsIf TypeOf(IBUserDescription) = Type("UUID") Then
		UUID = IBUserDescription;
	EndIf;
	
	If UUID <> Undefined Then
		IBUser = InfobaseUsers.FindByUUID(UUID);
		
		If IBUser = Undefined Then
			Return False;
		EndIf;
	Else
		IBUser = IBUserDescription;
	EndIf;
	
	Return IBUser.StandardAuthentication
		OR IBUser.OSAuthentication
		OR IBUser.OpenIDAuthentication;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used in managed forms items work.

// Returns list of users, users groups,
// external users and external users groups not marked for deletion.
//  Used in event handlers TextEntryEnd and AutoPick.
//
// Parameters:
//  Text         - String - characters entered by the user.
//
//  IcludingGroups - Boolean - if True, then include groups of users and external users.
//                  Parameter is ignored if FO UseUsersGroups is disabled.
//
//  IncludingExternalUsers - Undefined, Boolean - if Undefined, value
//                  is used return by the ExternalUsers function.UseExternalUsers().
//
//  WithoutUsers - Boolean - if True, then items of
//                  the Users catalog are excluded from the result.
//
Function FormDataOfUserChoice(Val Text,
                                             Val IcludingGroups = True,
                                             Val IncludingExternalUsers = Undefined,
                                             Val WithoutUsers = False) Export
	
	IcludingGroups = IcludingGroups AND GetFunctionalOption("UseUsersGroups");
	
	Query = New Query;
	Query.SetParameter("Text", Text + "%");
	Query.SetParameter("IcludingGroups", IcludingGroups);
	Query.Text = 
	"SELECT ALLOWED
	|	VALUE(Catalog.Users.EmptyRef) AS Ref,
	|	"""" AS Description,
	|	-1 AS PictureNumber
	|WHERE
	|	FALSE";
	
	If Not WithoutUsers Then
		Query.Text = Query.Text + " UNION ALL " +
		"SELECT
		|	Users.Ref,
		|	Users.Description,
		|	1 AS PictureNumber
		|FROM
		|	Catalog.Users AS Users
		|WHERE
		|	Not Users.DeletionMark
		|	AND Users.Description LIKE &Text
		|	AND Users.NotValid = FALSE
		|	AND Users.Service = FALSE
		|
		|UNION ALL
		|
		|SELECT
		|	UsersGroups.Ref,
		|	UsersGroups.Description,
		|	3
		|FROM
		|	Catalog.UsersGroups AS UsersGroups
		|WHERE
		|	&IcludingGroups
		|	AND Not UsersGroups.DeletionMark
		|	AND UsersGroups.Description LIKE &Text";
	EndIf;
	
	If TypeOf(IncludingExternalUsers) <> Type("Boolean") Then
		IncludingExternalUsers = ExternalUsers.UseExternalUsers();
	EndIf;
	IncludingExternalUsers = IncludingExternalUsers
	                            AND AccessRight("Read", Metadata.Catalogs.ExternalUsers);
	
	If IncludingExternalUsers Then
		Query.Text = Query.Text + " UNION ALL " +
		"SELECT
		|	ExternalUsers.Ref,
		|	ExternalUsers.Description,
		|	7 AS PictureNumber
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	(NOT ExternalUsers.DeletionMark)
		|	AND ExternalUsers.Description LIKE &Text
		|	AND ExternalUsers.NotValid = FALSE
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUsersGroups.Ref,
		|	ExternalUsersGroups.Description,
		|	9
		|FROM
		|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
		|WHERE
		|	&IcludingGroups
		|	AND (NOT ExternalUsersGroups.DeletionMark)
		|	AND ExternalUsersGroups.Description LIKE &Text";
	EndIf;
	
	Selection = Query.Execute().Select();
	
	ChoiceData = New ValueList;
	
	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref, Selection.Description, , PictureLib["UserState" + Format(Selection.PictureNumber + 1, "ND=2; NLZ=; NG=")]);
	EndDo;
	
	Return ChoiceData;
	
EndFunction

// The FillPictureUsersNumbers procedure fills
// in users picture numbers, user groups, external users and external user groups.
// 
// Parameters:
//  Table      - FormDataCollection, FormDataTree - list to be filled.
//  FieldNameUser - String - field name that contains ref to
//                 user, users group, external user or external users group.
//  PictureNumberFieldName - String - name of the field with the picture number to be set.
//  RowID  - Undefined, Number - String ID (not ordinal)
//                 if Undefined, fill in pictures for all table rows.
//
Procedure FillUserPictureNumbers(Val Table,
                                               Val FieldNameUser,
                                               Val PictureNumberFieldName,
                                               Val RowID = Undefined,
                                               Val ProcessHierarchyOfSecondAndThirdLevels = False) Export
	
	SetPrivilegedMode(True);
	
	If RowID = Undefined Then
		RowArray = Undefined;
		
	ElsIf TypeOf(RowID) = Type("Array") Then
		RowArray = New Array;
		For Each ID IN RowID Do
			RowArray.Add(Table.FindByID(ID));
		EndDo;
	Else
		RowArray = New Array;
		RowArray.Add(Table.FindByID(RowID));
	EndIf;
	
	If TypeOf(Table) = Type("FormDataTree") Then
		If RowArray = Undefined Then
			RowArray = Table.GetItems();
		EndIf;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add(FieldNameUser, Metadata.InformationRegisters.UsersGroupsContents.Dimensions.UsersGroup.Type);
		For Each String IN RowArray Do
			UsersTable.Add()[FieldNameUser] = String[FieldNameUser];
			If ProcessHierarchyOfSecondAndThirdLevels Then
				For Each Row2 IN String.GetItems() Do
					UsersTable.Add()[FieldNameUser] = Row2[FieldNameUser];
					For Each Row3 IN Row2.GetItems() Do
						UsersTable.Add()[FieldNameUser] = Row3[FieldNameUser];
					EndDo;
				EndDo;
			EndIf;
		EndDo;
	ElsIf TypeOf(Table) = Type("FormDataCollection") Then
		If RowArray = Undefined Then
			RowArray = Table;
		EndIf;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add(FieldNameUser, Metadata.InformationRegisters.UsersGroupsContents.Dimensions.UsersGroup.Type);
		For Each String IN RowArray Do
			UsersTable.Add()[FieldNameUser] = String[FieldNameUser];
		EndDo;
	Else
		If RowArray = Undefined Then
			RowArray = Table;
		EndIf;
		UsersTable = Table.Unload(RowArray, FieldNameUser);
	EndIf;
	
	Query = New Query(StrReplace(
	"SELECT DISTINCT
	|	Users.FieldNameUser AS User
	|INTO Users
	|FROM
	|	&Users AS Users
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Users.User,
	|	CASE
	|		WHEN Users.User = UNDEFINED
	|			THEN -1
	|		WHEN VALUETYPE(Users.User) = Type(Catalog.Users)
	|			THEN CASE
	|					WHEN CAST(Users.User AS Catalog.Users).DeletionMark
	|						THEN 0
	|					ELSE 1
	|				END
	|		WHEN VALUETYPE(Users.User) = Type(Catalog.UsersGroups)
	|			THEN CASE
	|					WHEN CAST(Users.User AS Catalog.UsersGroups).DeletionMark
	|						THEN 2
	|					ELSE 3
	|				END
	|		WHEN VALUETYPE(Users.User) = Type(Catalog.ExternalUsers)
	|			THEN CASE
	|					WHEN CAST(Users.User AS Catalog.ExternalUsers).DeletionMark
	|						THEN 6
	|					ELSE 7
	|				END
	|		WHEN VALUETYPE(Users.User) = Type(Catalog.ExternalUsersGroups)
	|			THEN CASE
	|					WHEN CAST(Users.User AS Catalog.ExternalUsersGroups).DeletionMark
	|						THEN 8
	|					ELSE 9
	|				END
	|		ELSE -2
	|	END AS PictureNumber
	|FROM
	|	Users AS Users", "FieldNameUser", FieldNameUser));
	Query.SetParameter("Users", UsersTable);
	PictureNumbers = Query.Execute().Unload();
	
	For Each String IN RowArray Do
		FoundString = PictureNumbers.Find(String[FieldNameUser], "User");
		String[PictureNumberFieldName] = ?(FoundString = Undefined, -2, FoundString.PictureNumber);
		If ProcessHierarchyOfSecondAndThirdLevels Then
			For Each Row2 IN String.GetItems() Do
				FoundString = PictureNumbers.Find(Row2[FieldNameUser], "User");
				Row2[PictureNumberFieldName] = ?(FoundString = Undefined, -2, FoundString.PictureNumber);
				For Each Row3 IN Row2.GetItems() Do
					FoundString = PictureNumbers.Find(Row3[FieldNameUser], "User");
					Row3[PictureNumberFieldName] = ?(FoundString = Undefined, -2, FoundString.PictureNumber);
				EndDo;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used during the infobase update.

// Used during the update and initial filling of infobase.
// 1) Creates the first administrator and matches it to
//    its new or existing user in the Users catalog.
// 2) Matches the administrator specified in the IBUser parameter
//    to new or existing user in the Users catalog.
//
// Parameters:
//  IBUser - InfobaseUser - used when it
//                   is required to match the existing administrator
//                   to a new or existing user in the Users catalog.
//
// Returns:
//  Undefined                  - user in catalog to which IB
//                                  user with the administrative rights is matched already exists
//  CatalogRef.Users - user in catalog to which the first administrator
//                                  or administrator specified in the InfobaseUser parameter is matched.
//
Function CreateAdministrator(IBUser = Undefined) Export
	
	SetPrivilegedMode(True);
	
	// Administrator  (system administrator - full rights).
	If IBUser = Undefined Then
		
		If CommonUseReUse.DataSeparationEnabled() Then
			Return Undefined;
		EndIf;
		
		// If the user with administrative
		// rights exists, there is no need to create the first administrator as it is already created.
		IBUser = Undefined;
	
		IBUsers = InfobaseUsers.GetUsers();
		For Each CurrentInfobaseUser IN IBUsers Do
			If InfobaseUserWithFullAccess(CurrentInfobaseUser,, False) Then
				Return Undefined;
			EndIf;
		EndDo;
		
		If IBUser = Undefined Then
			IBUser = InfobaseUsers.CreateUser();
			IBUser.Name       = "Administrator";
			IBUser.FullName = IBUser.Name;
			IBUser.Roles.Clear();
			IBUser.Roles.Add(Metadata.Roles.FullRights);
			
			If Not CommonUseReUse.DataSeparationEnabled() Then
				SystemAdministratorRole = SystemAdministratorRole();
				
				If Not IBUser.Roles.Contains(SystemAdministratorRole) Then
					IBUser.Roles.Add(SystemAdministratorRole);
				EndIf;
			EndIf;
			IBUser.Write();
		EndIf;
	Else
		If Not IBUser.Roles.Contains(Metadata.Roles.FullRights)
		 OR Not IBUser.Roles.Contains(Users.SystemAdministratorRole()) Then
		
			Return Undefined;
		EndIf;
		
		FindAmbiguousInfobaseUsers(, IBUser.UUID);
	EndIf;
	
	If UsersService.UserByIDExists(
	         IBUser.UUID) Then
		
		User = Catalogs.Users.FindByAttribute(
			"InfobaseUserID", IBUser.UUID);
		
		// If the administrator is matched with an external user - this
		// is an error, it is required to cancel the mapping.
		If Not ValueIsFilled(User) Then
			
			ExternalUser = Catalogs.ExternalUsers.FindByAttribute(
				"InfobaseUserID", IBUser.UUID);
			
			ExternalUserObject = ExternalUser.GetObject();
			ExternalUserObject.InfobaseUserID = Undefined;
			ExternalUserObject.DataExchange.Load = True;
			ExternalUserObject.Write();
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(User) Then
		User = Catalogs.Users.FindByDescription(IBUser.FullName);
		
		If ValueIsFilled(User)
		   AND ValueIsFilled(User.InfobaseUserID)
		   AND User.InfobaseUserID <> IBUser.UUID
		   AND InfobaseUsers.FindByUUID(
		         User.InfobaseUserID) <> Undefined Then
			
			User = Undefined;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(User) Then
		User = Catalogs.Users.CreateItem();
		UserCreated = True;
	Else
		User = User.GetObject();
		UserCreated = False;
	EndIf;
	
	User.Description = IBUser.FullName;
	
	IBUserDescription = New Structure;
	IBUserDescription.Insert("Action", "Write");
	IBUserDescription.Insert(
		"UUID", IBUser.UUID);
	
	User.AdditionalProperties.Insert(
		"IBUserDescription", IBUserDescription);
	
	User.Write();
	
	Return User.Ref;
	
EndFunction

// Sets the UseUsersGroups constant
// to True if at least one user group exists in catalog.
//
// Is used at updating an infobase.
//
Procedure OnUsersGroupsExistanceSetUsage() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.UsersGroups AS UsersGroups
	|WHERE
	|	UsersGroups.Ref <> VALUE(Catalog.UsersGroups.AllUsers)
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE
	|FROM
	|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
	|WHERE
	|	ExternalUsersGroups.Ref <> VALUE(Catalog.ExternalUsersGroups.AllExternalUsers)");
	
	If Not Query.Execute().IsEmpty() Then
		Constants.UseUsersGroups.Set(True);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for work with infobase users.

// Returns the full name of an unspecified user for display in interfaces.
Function UnspecifiedUserFullName() Export
	
	Return NStr("en='<Not specified>';ru='<Не указан>'");
	
EndFunction

// Returns the reference of unspecified user.
//
// Returns:
//  CatalogRef.Users - unspecified user exists in the catalog.
//  Undefined - unspecified user does not exist in the directory.
//
Function RefsUnspecifiedUser() Export
	
	Return UsersService.UnspecifiedUserProperties().Ref;
	
EndFunction

// Checks whether the IB user is match
// to the Users catalog item or to the ExternalUsers catalog item.
// 
// Parameters:
//  IBUser - String - name of the infobase user.
//                 - UUID - unique identifier of the infobase user.
//                 - InfobaseUser -
//
//  UserAccount  - InfobaseUser - (the value to be returned).
//
// Returns:
//  Boolean - True if IB user exists and
//   their ID is used either in the Users catalog, or in the ExternalUsers catalog.
//
Function IBUserIsLocked(IBUser, UserAccount = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(IBUser) = Type("String") Then
		UserAccount = InfobaseUsers.FindByName(IBUser);
		
	ElsIf TypeOf(IBUser) = Type("UUID") Then
		UserAccount = InfobaseUsers.FindByUUID(IBUser);
	Else
		UserAccount = IBUser;
	EndIf;
	
	If UserAccount = Undefined Then
		Return False;
	EndIf;
	
	Return UsersService.UserByIDExists(
		UserAccount.UUID);
	
EndFunction

// Returns an empty structure that describes infobase user.
//
// Returns:
//  Structure - with properties:
//   *UUID   - UUID -
//   * Name                       - String -
//   * FullName                 - String -
//
//   * AuthenticationOpenID      - Boolean -
//
//   * AuthenticationStandard - Boolean -
//   * ShowInChoiceList   - Boolean -
//   * Password                    - Undefined -
//   * PasswordValueToBeSaved - Undefined -
//   * PasswordIsSet          - Boolean -
//   * PasswordChangeIsNotAllowed   - Boolean -
//
//   * OSAuthentification          - Boolean -
//   * OSUser            - String - (not taken into account in the training platform).
//
//   * MainInterface         - Undefined -
//                               - String - interface name from the collection "Metadata.Interfaces".
//
//   * StartMode              - Undefined -
//                               - String - values: "Auto", "OrdinaryApplication", "ManagedApplication".
//   * Language                      - Undefined -
//                               - String - language name from the collection "Metadata.Languages".
//
//   * Roles                      - Undefined -
//                               - Array - of values of the type:
//                                  * String - role names from the collection "Metadata.Roles".
//
Function NewInfobaseUserInfo() Export
	
	// Preparing of structures of data to be returned.
	Properties = New Structure;
	
	Properties.Insert("UUID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	Properties.Insert("Name",                       "");
	Properties.Insert("FullName",                 "");
	Properties.Insert("OpenIDAuthentication",      False);
	Properties.Insert("StandardAuthentication", False);
	Properties.Insert("ShowInList",   False);
	Properties.Insert("OldPassword",              Undefined);
	Properties.Insert("Password",                    Undefined);
	Properties.Insert("StoredPasswordValue", Undefined);
	Properties.Insert("PasswordIsSet",          False);
	Properties.Insert("CannotChangePassword",   False);
	Properties.Insert("OSAuthentication",          False);
	Properties.Insert("OSUser",            "");
	
	Properties.Insert("DefaultInterface",
		?(Metadata.DefaultInterface = Undefined, "", Metadata.DefaultInterface.Name));
	
	Properties.Insert("RunMode",              "Auto");
	
	Properties.Insert("Language",
		?(Metadata.DefaultLanguage = Undefined, "", Metadata.DefaultLanguage.Name));
	
	Properties.Insert("Roles", Undefined);
	
	Return Properties;
	
EndFunction

// Reads infobase user properties by string ID or unique ID.
//
// Parameters:
//  ID  - Undefined, String, UUID - user identifier.
//  Properties       - Structure - with the properties as in the function NewInfobaseUserDescription().
//  ErrorDescription - String - contains  description of the error if  reading was unsuccessful.
//
// Returns:
//  Boolean - if True, then user is read, otherwise, see ErrorDescription.
//
Function ReadIBUser(Val ID,
                                Properties = Undefined,
                                ErrorDescription = "",
                                IBUser = Undefined) Export
	
	Properties = NewInfobaseUserInfo();
	
	Properties.Roles = New Array;
	
	If TypeOf(ID) = Type("UUID") Then
		
		If CommonUseReUse.DataSeparationEnabled()
		   AND CommonUseReUse.SessionWithoutSeparator()
		   AND CommonUseReUse.CanUseSeparatedData()
		   AND ID = InfobaseUsers.CurrentUser().UUID Then
			
			IBUser = InfobaseUsers.CurrentUser();
		Else
			IBUser = InfobaseUsers.FindByUUID(ID);
		EndIf;
		
	ElsIf TypeOf(ID) = Type("String") Then
		IBUser = InfobaseUsers.FindByName(ID);
	Else
		IBUser = Undefined;
	EndIf;
	
	If IBUser = Undefined Then
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Infobase user ""%1"" is not found.';ru='Пользователь информационной базы ""%1"" не найден.'"), ID);
		Return False;
	EndIf;
	
	CopyInfobaseUserProperties(Properties, IBUser);
	
	Return True;
	
EndFunction

// Overwrites IB user properties found
// by string ID or unique ID or
// creates a new IB user (if it is specified to create existing user - an error will appear).
//
// Parameters:
//  ID - String, UUID - user identifier.
//
//  UpdatedProperties - Structure - with the properties as in the function NewInfobaseUserDescription().
//    Property may not be specified, then the read or initial value is used.
//    The following structure properties are used in nonstandard way:
//      *UUID - Undefined - (return
//                                  value), set after the IB user is written.
//      * OldPassword            - Undefined, Row - if the
//                                  specified password does not match the existing one, an error will appear.
//
//  CreateNew - False  - no further actions.
//                - Undefined, True - creates new
//                  IB user when IBUser is not found by the specified identifier.
//                  The value is True if IB
//                  user is found by the specified identifier. - an error will appear.
//
//  ErrorDescription - String - contains  description of the error if  reading was unsuccessful.
//
// Returns:
//  Boolean - if True, then the user is recorded, otherwise see ErrorDescription.
//
Function WriteIBUser(Val ID,
                               Val UpdatedProperties,
                               Val CreateNew = False,
                               ErrorDescription = "",
                               IBUser = Undefined) Export
	
	IBUser = Undefined;
	OldProperties = Undefined;
	
	PreliminaryRead = ReadIBUser(
		ID, OldProperties, ErrorDescription, IBUser);
	
	If Not PreliminaryRead Then
		
		If CreateNew = Undefined OR CreateNew = True Then
			IBUser = InfobaseUsers.CreateUser();
		Else
			Return False;
		EndIf;
	ElsIf CreateNew = True Then
		ErrorDescription = ErrorDescriptionOnIBUserWrite(
			NStr("en='Unable to create
		|infobase
		|user %1 as they already exist.';ru='Невозможно
		|создать
		|пользователя информационной базы %1, так как он уже существует.'"),
			OldProperties.Name,
			OldProperties.UUID);
		Return False;
	Else
		If UpdatedProperties.Property("OldPassword")
		   AND TypeOf(UpdatedProperties.OldPassword) = Type("String") Then
			
			OldPasswordIsSame = False;
			
			UsersService.PasswordStringStoredValue(
				UpdatedProperties.OldPassword,
				OldProperties.UUID,
				OldPasswordIsSame);
			
			If Not OldPasswordIsSame Then
				ErrorDescription = ErrorDescriptionOnIBUserWrite(
					NStr("en='When writing user of infobase %1, old password was specified incorrectly.';ru='При записи пользователя информационной базы %1, старый пароль указан не верно.'"),
					OldProperties.Name,
					OldProperties.UUID);
				Return False;
			EndIf;
		EndIf;
	EndIf;
	
	// Preparing new values of properties.
	NewProperties = CommonUseClientServer.CopyStructure(OldProperties);
	
	For Each KeyAndValue IN NewProperties Do
		
		If UpdatedProperties.Property(KeyAndValue.Key)
		   AND UpdatedProperties[KeyAndValue.Key] <> Undefined Then
		
			NewProperties[KeyAndValue.Key] = UpdatedProperties[KeyAndValue.Key];
		EndIf;
	EndDo;
	
	CopyInfobaseUserProperties(IBUser, NewProperties);
	
	If CommonUseReUse.DataSeparationEnabled() Then
		IBUser.ShowInList = False;
	EndIf;
	
	// Attempt to write a new or modified infobase user.
	Try
		UsersService.WriteInfobaseUser(IBUser);
	Except
		ErrorDescription = ErrorDescriptionOnIBUserWrite(
			NStr("en='An error occurred while
		|writing infobase user
		|%1:
		|%2.';ru='При записи пользователя
		|информационной базы %1
		|произошла
		|ошибка: ""%2"".'"),
			IBUser.Name,
			?(PreliminaryRead, OldProperties.UUID, Undefined),
			ErrorInfo());
		Return False;
	EndTry;
	
	If ValueIsFilled(OldProperties.Name)
	   AND OldProperties.Name <> NewProperties.Name Then
		// Settings move.
		UsersService.CopyUserSettings(
			OldProperties.Name, NewProperties.Name, True);
	EndIf;
	
	UsersOverridable.OnWriteOfInformationBaseUser(OldProperties, NewProperties);
	
	If CreateNew = Undefined OR CreateNew = True Then
		UsersService.SetInitialSettings(NewProperties.Name);
	EndIf;
	
	UpdatedProperties.Insert("UUID", IBUser.UUID);
	Return True;
	
EndFunction

// Deletes the specified infobase user.
//
// Parameters:
//  ID  - String - name of the infobase user.
//                 - UUID - ID of the infobase user.
//
//  ErrorDescription - String - (return value) contains error description if it failed to be deleted.
//
// Returns:
//  Boolean - if True, the user was successfully deleted, otherwise see ErrorDescription.
//
Function DeleteInfobaseUsers(Val ID,
                              ErrorDescription = "",
                              IBUser = Undefined) Export
	
	IBUser = Undefined;
	Properties       = Undefined;
	
	If Not ReadIBUser(ID, Properties, ErrorDescription, IBUser) Then
		Return False;
	Else
		Try
			
			Handlers = CommonUse.ServiceEventProcessor("StandardSubsystems.Users\BeforeWriteIBUser");
			For Each Handler IN Handlers Do
				Handler.Module.BeforeWriteIBUser(IBUser.UUID);
			EndDo;
			
			IBUser.Delete();
			
		Except
			ErrorDescription = ErrorDescriptionOnIBUserWrite(
				NStr("en='An error occurred while
		|deleting infobase user
		|%1:
		|%2.';ru='При удалении пользователя
		|информационной базы %1
		|произошла
		|ошибка: ""%2"".'"),
				IBUser.Name,
				IBUser.UUID,
				ErrorInfo());
			Return False;
		EndTry;
	EndIf;
	
	UsersOverridable.AfterInfobaseUserDelete(Properties);
	
	Return True;
	
EndFunction

// Copies IB user properties values
// and converts to/from string IDs for
// the main interface, language, start mode and roles.
// 
//  Properties that do not exist in the source or in the target are not copied.
// 
//  If value in Source is
// Undefined, Password and SavedPasswordValue properties are not copied.
// 
//  OSAuthentication
// , StandardAuthentication, OpenIDAuthentication and OSUser
// properties are not reset if they match when Receiver of the InfobaseUser type.
// 
//  Properties UUID, SetPassword,
// OldPassword are not copied if Receiver is of the InfobaseUser type.
// 
//  The conversion is executed only for the Source or the Receiver type.
// InfobaseUser.
// 
// Parameters:
//  Receiver     - Structure, InfobaseUser, FormDataCollection - subset
//                 of properties from NewInfobaseUserDescription().
// 
//  Source     - Structure, InfobaseUser, FormDataCollection - as and
//                 receiver but the types of backlinks ie When the Receiver type Structure Then in the source Structure.
// 
//  CopiedProperties  - String - list of properties separated by commas that need to be copied (without prefix).
//  ExcludedProperties - String - list of properties separated by commas that do not need to be copied (without prefix).
//  PropertiesPrefix      - String - initial name for a Source or Receiver of the NOT Structure type.
//
Procedure CopyInfobaseUserProperties(Receiver,
                                            Source,
                                            CopiedProperties = "",
                                            ExcludedProperties = "",
                                            PropertiesPrefix = "") Export
	
	AllProperties = NewInfobaseUserInfo();
	
	If ValueIsFilled(CopiedProperties) Then
		CopiedPropertiesStructure = New Structure(CopiedProperties);
	Else
		CopiedPropertiesStructure = AllProperties;
	EndIf;
	
	If ValueIsFilled(ExcludedProperties) Then
		ExcludedPropertiesStructure = New Structure(ExcludedProperties);
	Else
		ExcludedPropertiesStructure = New Structure;
	EndIf;
	
	If StandardSubsystemsServer.IsEducationalPlatform() Then
		ExcludedPropertiesStructure.Insert("OSAuthentication");
		ExcludedPropertiesStructure.Insert("OSUser");
	EndIf;
	
	PasswordIsSet = False;
	
	For Each KeyAndValue IN AllProperties Do
		Property = KeyAndValue.Key;
		
		If Not CopiedPropertiesStructure.Property(Property)
		 OR ExcludedPropertiesStructure.Property(Property) Then
		
			Continue;
		EndIf;
		
		If TypeOf(Source) = Type("InfobaseUser") Then
			
			If Property = "Password"
			 OR Property = "OldPassword" Then
				
				PropertyValue = Undefined;
				
			ElsIf Property = "DefaultInterface" Then
				PropertyValue = ?(Source.DefaultInterface = Undefined,
				                     "",
				                     Source.DefaultInterface.Name);
			
			ElsIf Property = "RunMode" Then
				ValueFullName = GetPredefinedValueFullName(Source.RunMode);
				PropertyValue = Mid(ValueFullName, Find(ValueFullName, ".") + 1);
				
			ElsIf Property = "Language" Then
				PropertyValue = ?(Source.Language = Undefined,
				                     "",
				                     Source.Language.Name);
				
			ElsIf Property = "Roles" Then
				
				TempStructure = New Structure("Roles", New ValueTable);
				FillPropertyValues(TempStructure, Receiver);
				If TypeOf(TempStructure.Roles) = Type("ValueTable") Then
					Continue;
				ElsIf TempStructure.Roles = Undefined Then
					Receiver.Roles = New Array;
				Else
					Receiver.Roles.Clear();
				EndIf;
				
				For Each Role IN Source.Roles Do
					Receiver.Roles.Add(Role.Name);
				EndDo;
				
				Continue;
			Else
				PropertyValue = Source[Property];
			EndIf;
			
			PropertyFullName = PropertiesPrefix + Property;
			TempStructure = New Structure(PropertyFullName, PropertyValue);
			FillPropertyValues(Receiver, TempStructure);
		Else
			If TypeOf(Source) = Type("Structure") Then
				If Source.Property(Property) Then
					PropertyValue = Source[Property];
				Else
					Continue;
				EndIf;
			Else
				PropertyFullName = PropertiesPrefix + Property;
				TempStructure = New Structure(PropertyFullName, New ValueTable);
				FillPropertyValues(TempStructure, Source);
				PropertyValue = TempStructure[PropertyFullName];
				If TypeOf(PropertyValue) = Type("ValueTable") Then
					Continue;
				EndIf;
			EndIf;
			
			If TypeOf(Receiver) = Type("InfobaseUser") Then
			
				If Property = "UUID"
				 OR Property = "OldPassword"
				 OR Property = "PasswordIsSet" Then
					
					Continue;
					
				ElsIf Property = "OpenIDAuthentication"
				      OR Property = "StandardAuthentication"
				      OR Property = "OSAuthentication"
				      OR Property = "OSUser" Then
					
					If Receiver[Property] <> PropertyValue Then
						Receiver[Property] = PropertyValue;
					EndIf;
					
				ElsIf Property = "Password" Then
					If PropertyValue <> Undefined Then
						Receiver.Password = PropertyValue;
						PasswordIsSet = True;
					EndIf;
					
				ElsIf Property = "StoredPasswordValue" Then
					If PropertyValue <> Undefined
					   AND Not PasswordIsSet Then
						Receiver.StoredPasswordValue = PropertyValue;
					EndIf;
					
				ElsIf Property = "DefaultInterface" Then
					If TypeOf(PropertyValue) = Type("String") Then
						Receiver.DefaultInterface = Metadata.Interfaces.Find(PropertyValue);
					Else
						Receiver.DefaultInterface = Undefined;
					EndIf;
				
				ElsIf Property = "RunMode" Then
					If PropertyValue = "Auto"
					 OR PropertyValue = "OrdinaryApplication"
					 OR PropertyValue = "ManagedApplication" Then
						
						Receiver.RunMode = ClientRunMode[PropertyValue];
					Else
						Receiver.RunMode = ClientRunMode.Auto;
					EndIf;
					
				ElsIf Property = "Language" Then
					If TypeOf(PropertyValue) = Type("String") Then
						Receiver.Language = Metadata.Languages.Find(PropertyValue);
					Else
						Receiver.Language = Undefined;
					EndIf;
					
				ElsIf Property = "Roles" Then
					Receiver.Roles.Clear();
					If PropertyValue <> Undefined Then
						For Each RoleName IN PropertyValue Do
							Role = Metadata.Roles.Find(RoleName);
							If Role <> Undefined Then
								Receiver.Roles.Add(Role);
							EndIf;
						EndDo;
					EndIf;
				Else
					If Property = "Name"
					   AND Receiver[Property] <> PropertyValue Then
					
						If StrLen(PropertyValue) > 64 Then
							Raise StringFunctionsClientServer.SubstituteParametersInString(
								NStr("en='An error occurred while
		|writing infobase user Name
		|(for login): %1 exceeds 64 characters length.';ru='Ошибка записи пользователя
		|информационной базы
		|Имя (для входа): ""%1"" превышает длину 64 символа.'"),
								PropertyValue);
							
						ElsIf Find(PropertyValue, ":") > 0 Then
							Raise StringFunctionsClientServer.SubstituteParametersInString(
								NStr("en='An error occurred while
		|writing infobase user Name
		|(for login): %1 contains disallowed character :.';ru='Ошибка записи пользователя
		|информационной базы
		|Имя (для входа): ""%1"" содержит запрещенный символ "":"".'"),
								PropertyValue);
						EndIf;
					EndIf;
					Receiver[Property] = Source[Property];
				EndIf;
			Else
				If Property = "Roles" Then
					
					TempStructure = New Structure("Roles", New ValueTable);
					FillPropertyValues(TempStructure, Receiver);
					If TypeOf(TempStructure.Roles) = Type("ValueTable") Then
						Continue;
					ElsIf TempStructure.Roles = Undefined Then
						Receiver.Roles = New Array;
					Else
						Receiver.Roles.Clear();
					EndIf;
					
					If Source.Roles <> Undefined Then
						For Each Role IN Source.Roles Do
							Receiver.Roles.Add(Role.Name);
						EndDo;
					EndIf;
					Continue;
					
				ElsIf TypeOf(Source) = Type("Structure") Then
					PropertyFullName = PropertiesPrefix + Property;
				Else
					PropertyFullName = Property;
				EndIf;
				TempStructure = New Structure(PropertyFullName, PropertyValue);
				FillPropertyValues(Receiver, TempStructure);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Returns user from the Users catalog to
// which IB user is matched with the specified name.
//  To perform search, the user has to have administrative rights. If there are
// no administrative rights, you can search only for user for the current IB user.
// 
// Parameters:
//  NameForEntering - String - name of the infobase user used for logging.
//
// Returns:
//  CatalogRef.Users           - if the user is found.
//  Catalogs.Users.EmptyRef() - if the infobase user is found.
//  Undefined                            - if the infobase user is not found.
//
Function FindByName(Val NameForEntering) Export
	
	IBUser = InfobaseUsers.FindByName(NameForEntering);
	
	If IBUser = Undefined Then
		Return Undefined;
	Else
		FindAmbiguousInfobaseUsers(, IBUser.UUID);
		
		Return Catalogs.Users.FindByAttribute(
			"InfobaseUserID",
			IBUser.UUID);
	EndIf;
	
EndFunction

// Returns the role, which provides system administration rights.
//
// Parameters:
//  ForCheck - Boolean - return the role for checking rather than for installation.
//                 For basic versions role for setting
//                 is SystemAdministrator, role for checking may be FullRights with the Administration right.
//
// Returns:
//  MetadataObject - Role.
//
Function SystemAdministratorRole(ForCheck = False) Export
	
	SystemAdministratorRole = Metadata.Roles.SystemAdministrator;
	
	If ForCheck
	   AND AccessRight("Administration", Metadata, Metadata.Roles.FullRights)
	   AND StandardSubsystemsServer.ThisIsBasicConfigurationVersion() Then
	
		SystemAdministratorRole = Metadata.Roles.FullRights;
	EndIf;
	
	Return SystemAdministratorRole;
	
EndFunction

// Searches IB users identifiers that are used more
// than once and either throws exception, or returns the found
// IB users for the subsequent processor.
//
// Parameters:
//  User - Undefined - check for all users and external users.
//               - CatalogRef.Users, CatalogRef.ExternalUsers - checking
//                 for the specified  reference only.
//
//  UUID - Undefined - check of all specified identifiers of infobase users.
//                          - UUID - check for the specified identifier only.
//
//  FoundIDs - Undefined - if errors are found, an exception is called.
//                          - Map - if errors are found, exception
//                              is not called, instead the passed match is filled in:
//                              * Key     - non-unique identifier of the infobase user.
//                              * Value - array of users and external users.
//
//  ServiceUserID - Boolean - if False, then
//                                              check InfobaseUserID if True, then check ServiceUserID.
//
Procedure FindAmbiguousInfobaseUsers(Val User,
                                            Val UUID = Undefined,
                                            Val FoundIDs = Undefined,
                                            Val ServiceUserID = False) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(UUID) <> Type("UUID") Then
		UUID =
			New UUID("00000000-0000-0000-0000-000000000000");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("User", User);
	Query.SetParameter("UUID", UUID);
	
	Query.SetParameter("EmptyUUID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	Query.Text =
	"SELECT
	|	UserIDs.InfobaseUserID AS AmbiguousID,
	|	UserIDs.User
	|FROM
	|	(SELECT
	|		Users.InfobaseUserID,
	|		Users.Ref AS User
	|	FROM
	|		Catalog.Users AS Users
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ExternalUsers.InfobaseUserID,
	|		ExternalUsers.Ref
	|	FROM
	|		Catalog.ExternalUsers AS ExternalUsers) AS UserIDs
	|WHERE
	|	UserIDs.InfobaseUserID In
	|			(SELECT
	|				UserIDs.InfobaseUserID
	|			FROM
	|				(SELECT
	|					Users.InfobaseUserID,
	|					Users.Ref AS User
	|				FROM
	|					Catalog.Users AS Users
	|				WHERE
	|					Users.InfobaseUserID <> &EmptyUUID
	|					AND Not(&User <> UNDEFINED
	|							AND Users.Ref <> &User)
	|					AND Not(&UUID <> &EmptyUUID
	|							AND Users.InfobaseUserID <> &UUID)
	|		
	|				UNION ALL
	|		
	|				SELECT
	|					ExternalUsers.InfobaseUserID,
	|					ExternalUsers.Ref
	|				FROM
	|					Catalog.ExternalUsers AS ExternalUsers
	|				WHERE
	|					ExternalUsers.InfobaseUserID <> &EmptyUUID
	|					AND Not(&User <> UNDEFINED
	|							AND ExternalUsers.Ref <> &User)
	|					AND Not(&UUID <> &EmptyUUID
	|							AND ExternalUsers.InfobaseUserID <> &UUID)
	|				) AS UserIDs
	|			GROUP BY
	|						UserIDs.InfobaseUserID
	|			HAVING
	|				COUNT(UserIDs.User) > 1)
	|
	|ORDER BY
	|	UserIDs.InfobaseUserID";
	
	If ServiceUserID Then
		Query.Text = StrReplace(Query.Text,
			"InfobaseUserID",
			"ServiceUserID");
	EndIf;
	
	Exporting = Query.Execute().Unload();
	
	If Exporting.Count() = 0 Then
		Return;
	EndIf;
	
	ErrorDescription = NStr("en='Error in the data base:';ru='Ошибка в базе данных:'") + Chars.LF;
	CurrentAmbiguousID = Undefined;
	
	For Each String In Exporting Do
		
		NewUUID = False;
		If String.AmbiguousID <> CurrentAmbiguousID Then
			NewUUID = True;
			CurrentAmbiguousID = String.AmbiguousID;
			If TypeOf(FoundIDs) = Type("Map") Then
				CurrentUsers = New Array;
				FoundIDs.Insert(CurrentAmbiguousID, CurrentUsers);
			Else
				CurrentInfobaseUser = InfobaseUsers.CurrentUser();
				
				If CurrentInfobaseUser.UUID <> CurrentAmbiguousID Then
					CurrentInfobaseUser =
						InfobaseUsers.FindByUUID(
							CurrentAmbiguousID);
				EndIf;
				
				If CurrentInfobaseUser = Undefined Then
					NameForEntering = NStr("en='<not specified>';ru='<не найден>'");
				Else
					NameForEntering = CurrentInfobaseUser.Name;
				EndIf;
				
				ErrorDescription = ErrorDescription
					+ StringFunctionsClientServer.SubstituteParametersInString(
						?(ServiceUserID,
						NStr("en='Service user with
		|the identifier %2 corresponds to more than one item in the Users catalog:';ru='Пользователю
		|сервиса с идентификатором ""%2"" соответствует более одного элемента в справочнике Пользователи:'"),
						NStr("en='IB user %1 with
		|identifier %2 corresponds to more than one item in the Users catalog:';ru='Пользователю
		|ИБ ""%1"" с идентификатором ""%2"" соответствует более одного элемента в справочнике Пользователи:'") ),
						NameForEntering,
						CurrentAmbiguousID);
			EndIf;
		EndIf;
		
		If TypeOf(FoundIDs) = Type("Map") Then
			CurrentUsers.Add(String.User);
		Else
			If Not NewUUID Then
				ErrorDescription = ErrorDescription + ",";
			EndIf;
			ErrorDescription = ErrorDescription
				+ StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='
		|	""%1"" with %2 reference ID';ru='
		|	""%1"" с идентификатором ссылки %2'"),
					String.User,
					String.User.UUID());
		EndIf;
	EndDo;
	
	If TypeOf(FoundIDs) <> Type("Map") Then
		ErrorDescription = ErrorDescription + "." + Chars.LF;
		Raise ErrorDescription;
	EndIf;
	
EndProcedure

// Returns the password value to be saved for the specified password.
//
// Parameters:
//  Password - String - the password, for which it is required to get the value to be saved.
//
// Returns:
//  String - the password value to be saved.
//
Function PasswordStringStoredValue(Val Password) Export
	
	Return UsersService.PasswordStringStoredValue(Password);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

// Generates error brief description that
// will be shown to user and they can also write the error detailed description to the events log monitor.
//
// Parameters:
//  ErrorTemplate       - Template containing parameter %1 to present
//                       IB user and parameter %2 for error description.
//
//  NameForEntering        - name of the infobase user used for logging.
//
//  InfobaseUserID - Undefined, UUID.
//
//  ErrorInfo - ErrorInfo.
//
//  WriteInJournal    - Boolean. If True, detailed error description is written
//                       to the events log monitor.
//
// Returns:
//  String - error details for displaying to the user.
//
Function ErrorDescriptionOnIBUserWrite(ErrorTemplate,
                                              NameForEntering,
                                              InfobaseUserID,
                                              ErrorInfo = Undefined,
                                              WriteInJournal = True)
	
	If WriteInJournal Then
		WriteLogEvent(
			NStr("en='Users.An error occurred when writing infobase user';ru='Пользователи.Ошибка записи пользователя ИБ'",
			     CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,
			,
			,
			StringFunctionsClientServer.SubstituteParametersInString(
				ErrorTemplate,
				"""" + NameForEntering + """ ("
				+ ?(ValueIsFilled(InfobaseUserID),
					NStr("en='New';ru='Новый'"),
					String(InfobaseUserID))
				+ ")",
				?(ErrorInfo = Undefined,
				  "",
				  DetailErrorDescription(ErrorInfo))));
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		ErrorTemplate,
		"""" + NameForEntering + """",
		?(ErrorInfo = Undefined,
		  "",
		  BriefErrorDescription(ErrorInfo)));
	
EndFunction

// For the IsInfobaseUserWithFullAccess and RolesAreAvailable functions.

Function CheckedInfobaseUserProperties(User)
	
	Properties = New Structure;
	Properties.Insert("CurrentInfobaseUser", InfobaseUsers.CurrentUser());
	Properties.Insert("IBUser", Undefined);
	
	If TypeOf(User) = Type("InfobaseUser") Then
		Properties.Insert("IBUser", User);
		
	ElsIf User = Undefined OR User = AuthorizedUser() Then
		Properties.Insert("IBUser", Properties.CurrentInfobaseUser);
	Else
		// The user set is not the current one.
		If ValueIsFilled(User) Then
			Properties.Insert("IBUser", InfobaseUsers.FindByUUID(
				CommonUse.ObjectAttributeValue(User, "InfobaseUserID")));
		EndIf;
	EndIf;
	
	If Properties.IBUser <> Undefined Then
		Properties.Insert("IsCurrentInfobaseUser",
			Properties.IBUser.UUID
				= Properties.CurrentInfobaseUser.UUID);
	EndIf;
	
	Return Properties;
	
EndFunction

#EndRegion
