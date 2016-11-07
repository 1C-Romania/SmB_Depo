////////////////////////////////////////////////////////////////////////////////
// Subsystem "Access management".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used to check rights.

// Checks whether a user has role in one of profiles of those access groups
// in that it participates, for example, role ViewEventLogMonitor, role PrintUnpostedDocuments.
//
// If object is specified (or access value sets), then
// it is additionally checked whether access group provides the right Reading of the specified object (or access value set is allowed).
//
// Parameters:
//  Role           - String - role name.
//
//  ObjectReference - Ref - to object for which access value sets
//                   are filled in to check the Reading right.
//                 - ValueTable - table of access values arbitrary sets with columns:
//                     * SetNumber     - Number  - number that groups several strings to the separate set.
//                     * AccessKind      - String - access kind name specified in the overridable module.
//                     * AccessValue - Ref - on the access value type specified in the overridable module.
//                       Empty prepared table can be received using function.
//                       AccessValueSetsTable
//                       of the AccessManagement general module (do not fill in the Reading, Change columns).
//
//  User   - CatalogRef.Users, CatalogRef.ExternalUsers, Undefined - if
//                   parameter is not specified, right is checked for the current user.
//
// Returns:
//  Boolean - If True, then the user has a role considering applied restrictions.
//
Function IsRole(Val Role, Val ObjectReference = Undefined, Val User = Undefined) Export
	
	User = ?(ValueIsFilled(User), User, Users.AuthorizedUser());
	If Users.InfobaseUserWithFullAccess(User) Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If ObjectReference = Undefined OR Not LimitAccessOnRecordsLevel() Then
		// Check whether role is assigned to a user via access group by profile.
		Query = New Query;
		Query.SetParameter("AuthorizedUser", User);
		Query.SetParameter("Role", Role);
		Query.Text =
		"SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	Catalog.AccessGroups.Users AS AccessGroupsUsers
		|		INNER JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
		|		ON (UsersGroupsContents.User = &AuthorizedUser)
		|			AND (UsersGroupsContents.UsersGroup = AccessGroupsUsers.User)
		|			AND (UsersGroupsContents.Used)
		|			AND (NOT AccessGroupsUsers.Ref.DeletionMark)
		|		INNER JOIN Catalog.AccessGroupsProfiles.Roles AS AccessGroupsProfilesRoles
		|		ON AccessGroupsUsers.Ref.Profile = AccessGroupsProfilesRoles.Ref
		|			AND (AccessGroupsProfilesRoles.Role.Name = &Role)
		|			AND (NOT AccessGroupsProfilesRoles.Ref.DeletionMark)";
		Return Not Query.Execute().IsEmpty();
	EndIf;
		
	If TypeOf(ObjectReference) = Type("ValueTable") Then
		AccessValuesSets = ObjectReference.Copy();
	Else
		AccessValuesSets = TableAccessValueSets();
		ObjectReference.GetObject().FillAccessValueSets(AccessValuesSets);
		// Select only access value sets intended for the Reading right check.
		RowsSetsReading = AccessValuesSets.FindRows(New Structure("Read", True));
		SetNumbers = New Map;
		For Each String IN RowsSetsReading Do
			SetNumbers.Insert(String.NumberOfSet, True);
		EndDo;
		IndexOf = AccessValuesSets.Count()-1;
		While IndexOf > 0 Do
			If SetNumbers[AccessValuesSets[IndexOf].NumberOfSet] = Undefined Then
				AccessValuesSets.Delete(IndexOf);
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		AccessValuesSets.FillValues(False, "Read, Update");
	EndIf;
	
	// Access value sets refiner.
	AccessKindNames = AccessManagementServiceReUse.Parameters().AccessKindsProperties.ByNames;
	
	For Each String IN AccessValuesSets Do
		
		If String.AccessKind = "" Then
			Continue;
		EndIf;
		
		If Upper(String.AccessKind) = Upper("ReadRight")
		 OR Upper(String.AccessKind) = Upper("EditRight") Then
			
			If TypeOf(String.AccessValue) <> Type("CatalogRef.MetadataObjectIDs") Then
				If CommonUse.IsReference(TypeOf(String.AccessValue)) Then
					String.AccessValue = CommonUse.MetadataObjectID(TypeOf(String.AccessValue));
				Else
					String.AccessValue = Undefined;
				EndIf;
			EndIf;
			
			If Upper(String.AccessKind) = Upper("EditRight") Then
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
//{{MRG[ <-> ]
				NStr("en='An error occurred in the HasRole function of the AccessManagement module."
"In the access values set the EditingRight"
"access kind is specified of table with ID ""%1""."
"In the restriction role checks (as"
"an additional right) can depend only on the Reading right.';ru='Ошибка в функции ЕстьРоль модуля УправлениеДоступом."
"В наборе значений доступа указан"
"вид доступа ПравоИзменения таблицы с идентификтором ""%1""."
"В ограничении проверки роли (как"
"дополнительного права) может быть зависимость только от права Чтения.'"),
//}}MRG[ <-> ]
//{{MRG[ <-> ]
//				NStr("en='An error occurred in the HasRole function of the AccessManagement module.
//		|In the access values set the EditingRight
//		|access kind is specified of table with ID ""%1"".
//		|In the restriction role checks (as
//		|an additional right) can depend only on the Reading right.';ru='Ошибка в функции ЕстьРоль модуля УправлениеДоступом.
//		|В наборе значений доступа указан
//		|вид доступа ПравоИзменения таблицы с идентификтором ""%1"".
//		|В ограничении проверки роли (как
//		|дополнительного права) может быть зависимость только от права Чтения.'"),
//}}MRG[ <-> ]
					String.AccessValue);
			EndIf;
		ElsIf AccessKindNames.Get(String.AccessKind) <> Undefined
		      OR String.AccessKind = "RightSettings" Then
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
//{{MRG[ <-> ]
				NStr("en='An error occurred in the HasRole function of the AccessManagement module."
"Access values set contains known access kind"
"""%2"" that you should not specify."
""
"Specify only special access"
"kinds ""ReadingRight"", ""ChangingRight"" if they are used.';ru='Ошибка в функции ЕстьРоль модуля УправлениеДоступом."
"Набор значений доступа содержит известный"
"вид доступа ""%2"", который не требуется указывать."
""
"Указывать требуется"
"только специальные виды доступа ""ПравоЧтения"", ""ПравоИзменения"", если они используются.'"),
//}}MRG[ <-> ]
//{{MRG[ <-> ]
//				NStr("en='An error occurred in the HasRole function of the AccessManagement module.
//		|Access values set contains known access kind
//		|""%2"" that you should not specify.
//		|
//		|Specify only special access
//		|kinds ""ReadingRight"", ""ChangingRight"" if they are used.';ru='Ошибка в функции ЕстьРоль модуля УправлениеДоступом.
//		|Набор значений доступа содержит известный
//		|вид доступа ""%2"", который не требуется указывать.
//		|
//		|Указывать требуется
//		|только специальные виды доступа ""ПравоЧтения"", ""ПравоИзменения"", если они используются.'"),
//}}MRG[ <-> ]
				TypeOf(ObjectReference),
				String.AccessKind);
		Else
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
//{{MRG[ <-> ]
				NStr("en='An error occurred in the HasRole function of the AccessManagement module."
"Access values set contains unknown access kind ""%2"".';ru='Ошибка в функции ЕстьРоль модуля УправлениеДоступом."
"Набор значений доступа содержит неизвестный вид доступа ""%2"".'"),
//}}MRG[ <-> ]
//{{MRG[ <-> ]
//				NStr("en='An error occurred in the HasRole function of the AccessManagement module.
//		|Access values set contains unknown access kind ""%2"".';ru='Ошибка в функции ЕстьРоль модуля УправлениеДоступом.
//		|Набор значений доступа содержит неизвестный вид доступа ""%2"".'"),
//}}MRG[ <-> ]
				TypeOf(ObjectReference),
				String.AccessKind);
		EndIf;
		
		String.AccessKind = "";
	EndDo;
	
	// Add service fields to access values set.
	AccessManagementService.PrepareAccessToRecordsValuesSets(Undefined, AccessValuesSets, True);
	
	// Check whether the role is assigned to a user via access group
	// by profile with the allowed access value sets.
	
	Query = New Query;
	Query.SetParameter("AuthorizedUser", User);
	Query.SetParameter("Role", Role);
	Query.SetParameter("AccessValuesSets", AccessValuesSets);
	Query.SetParameter("RightSettingsOwnerTypes", SessionParameters.RightSettingsOwnerTypes);
	Query.Text =
	"SELECT DISTINCT
	|	AccessValuesSets.NumberOfSet,
	|	AccessValuesSets.AccessValue,
	|	AccessValuesSets.ValueWithoutGroups,
	|	AccessValuesSets.StandardValue
	|INTO AccessValuesSets
	|FROM
	|	&AccessValuesSets AS AccessValuesSets
	|
	|INDEX BY
	|	AccessValuesSets.NumberOfSet,
	|	AccessValuesSets.AccessValue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccessGroupsUsers.Ref AS Ref
	|INTO AccessGroups
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		INNER JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|		ON (UsersGroupsContents.User = &AuthorizedUser)
	|			AND (UsersGroupsContents.UsersGroup = AccessGroupsUsers.User)
	|			AND (UsersGroupsContents.Used)
	|			AND (NOT AccessGroupsUsers.Ref.DeletionMark)
	|		INNER JOIN Catalog.AccessGroupsProfiles.Roles AS AccessGroupsProfilesRoles
	|		ON AccessGroupsUsers.Ref.Profile = AccessGroupsProfilesRoles.Ref
	|			AND (AccessGroupsProfilesRoles.Role.Name = &Role)
	|			AND (NOT AccessGroupsProfilesRoles.Ref.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Sets.NumberOfSet
	|INTO SetNumbers
	|FROM
	|	AccessValuesSets AS Sets
	|
	|INDEX BY
	|	Sets.NumberOfSet
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	AccessGroups AS AccessGroups
	|WHERE
	|	Not(TRUE In
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						SetNumbers AS SetNumbers
	|					WHERE
	|						TRUE In
	|							(SELECT TOP 1
	|								TRUE
	|							FROM
	|								AccessValuesSets AS ValueSets
	|							WHERE
	|								ValueSets.NumberOfSet = SetNumbers.NumberOfSet
	|								AND Not TRUE In
	|										(SELECT TOP 1
	|											TRUE
	|										FROM
	|											InformationRegister.AccessGroupsDefaultValues AS DefaultValues
	|										WHERE
	|											DefaultValues.AccessGroup = AccessGroups.Ref
	|											AND VALUETYPE(DefaultValues.AccessValuesType) = VALUETYPE(ValueSets.AccessValue)
	|											AND DefaultValues.WithoutSetup = TRUE)))
	|				AND Not TRUE In
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							SetNumbers AS SetNumbers
	|						WHERE
	|							TRUE In
	|								(SELECT TOP 1
	|									TRUE
	|								FROM
	|									AccessValuesSets AS ValueSets
	|								WHERE
	|									ValueSets.NumberOfSet = SetNumbers.NumberOfSet
	|									AND Not TRUE In
	|											(SELECT TOP 1
	|												TRUE
	|											FROM
	|												InformationRegister.AccessGroupsDefaultValues AS DefaultValues
	|											WHERE
	|												DefaultValues.AccessGroup = AccessGroups.Ref
	|												AND VALUETYPE(DefaultValues.AccessValuesType) = VALUETYPE(ValueSets.AccessValue)
	|												AND DefaultValues.WithoutSetup = TRUE))
	|							AND Not FALSE In
	|									(SELECT TOP 1
	|										FALSE
	|									FROM
	|										AccessValuesSets AS ValueSets
	|									WHERE
	|										ValueSets.NumberOfSet = SetNumbers.NumberOfSet
	|										AND Not CASE
	|												WHEN ValueSets.ValueWithoutGroups
	|													THEN TRUE In
	|															(SELECT TOP 1
	|																TRUE
	|															FROM
	|																InformationRegister.AccessGroupsDefaultValues AS DefaultValues
	|																	LEFT JOIN InformationRegister.AccessGroupsValues AS Values
	|																	ON
	|																		Values.AccessGroup = AccessGroups.Ref
	|																			AND Values.AccessValue = ValueSets.AccessValue
	|															WHERE
	|																DefaultValues.AccessGroup = AccessGroups.Ref
	|																AND VALUETYPE(DefaultValues.AccessValuesType) = VALUETYPE(ValueSets.AccessValue)
	|																AND ISNULL(Values.ValueAllowed, DefaultValues.AllAllowed))
	|												WHEN ValueSets.StandardValue
	|													THEN CASE
	|															WHEN TRUE In
	|																	(SELECT TOP 1
	|																		TRUE
	|																	FROM
	|																		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|																	WHERE
	|																		AccessValuesGroups.AccessValue = ValueSets.AccessValue
	|																		AND AccessValuesGroups.AccessValuesGroup = &AuthorizedUser)
	|																THEN TRUE
	|															ELSE TRUE In
	|																	(SELECT TOP 1
	|																		TRUE
	|																	FROM
	|																		InformationRegister.AccessGroupsDefaultValues AS DefaultValues
	|																			INNER JOIN InformationRegister.AccessValuesGroups AS ValueGroups
	|																			ON
	|																				ValueGroups.AccessValue = ValueSets.AccessValue
	|																					AND DefaultValues.AccessGroup = AccessGroups.Ref
	|																					AND VALUETYPE(DefaultValues.AccessValuesType) = VALUETYPE(ValueSets.AccessValue)
	|																			LEFT JOIN InformationRegister.AccessGroupsValues AS Values
	|																			ON
	|																				Values.AccessGroup = AccessGroups.Ref
	|																					AND Values.AccessValue = ValueGroups.AccessValuesGroup
	|																	WHERE
	|																		ISNULL(Values.ValueAllowed, DefaultValues.AllAllowed))
	|														END
	|												WHEN ValueSets.AccessValue = VALUE(Enum.AdditionalAccessValues.AccessPermitted)
	|													THEN TRUE
	|												WHEN ValueSets.AccessValue = VALUE(Enum.AdditionalAccessValues.AccessDenied)
	|													THEN FALSE
	|												WHEN VALUETYPE(ValueSets.AccessValue) = Type(Catalog.MetadataObjectIDs)
	|													THEN TRUE In
	|															(SELECT TOP 1
	|																TRUE
	|															FROM
	|																InformationRegister.AccessGroupsTables AS AccessGroupTablesObjectRightCheck
	|															WHERE
	|																AccessGroupTablesObjectRightCheck.AccessGroup = AccessGroups.Ref
	|																AND AccessGroupTablesObjectRightCheck.Table = ValueSets.AccessValue)
	|												ELSE TRUE In
	|															(SELECT TOP 1
	|																TRUE
	|															FROM
	|																InformationRegister.ObjectRightsSettings AS RightSettings
	|																	INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|																	ON
	|																		SettingsInheritance.Object = ValueSets.AccessValue
	|																			AND RightSettings.Object = SettingsInheritance.Parent
	|																			AND SettingsInheritance.UseLevel < RightSettings.ReadingPermissionLevel
	|																	INNER JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|																	ON
	|																		UsersGroupsContents.User = &AuthorizedUser
	|																			AND UsersGroupsContents.UsersGroup = RightSettings.User)
	|														AND Not FALSE In
	|																(SELECT TOP 1
	|																	FALSE
	|																FROM
	|																	InformationRegister.ObjectRightsSettings AS RightSettings
	|																		INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|																		ON
	|																			SettingsInheritance.Object = ValueSets.AccessValue
	|																				AND RightSettings.Object = SettingsInheritance.Parent
	|																				AND SettingsInheritance.UseLevel < RightSettings.ReadingDeniedLevel
	|																		INNER JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|																		ON
	|																			UsersGroupsContents.User = &AuthorizedUser
	|																				AND UsersGroupsContents.UsersGroup = RightSettings.User)
	|											END)))";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Checks whether right for object dimension is set for a user.
//  For example, for the files folders "RightsManagement", "Reading", "FoldersChange"
// rights can be set and the "Reading" right is both the right for files folder, and for right for files.
//
// Parameters:
//  Right          - String - right name as it is specified in
//                   the OnFillingPossibleRightsForObjectRightsSetting procedure of the AccessManagementOverridable general module.
//
//  ObjectReference - CatalogRef, ChartOfCharacteristicTypesRef - ref to one of
//                   the right owners specified
//                   in the OnFillingPossibleRightsForObjectRightsSetting procedure of the AccessManagementOverridable general module.
//
//  User   - CatalogRef.Users, CatalogRef.ExternalUsers, Undefined - if
//                   parameter is not specified, right is checked for the current user.
//
// Returns:
//  Boolean - if True, then right permission is set considering all
//           allow and deny settings in hierarchy.
//
Function IsRight(Right, ObjectReference, User = Undefined) Export
	
	User = ?(ValueIsFilled(User), User, Users.AuthorizedUser());
	If Users.InfobaseUserWithFullAccess(User) Then
		Return True;
	EndIf;
	
	If Not LimitAccessOnRecordsLevel() Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	RightsDescriptionFull = AccessManagementServiceReUse.Parameters(
		).PossibleRightsForObjectRightsSettings.ByTypes.Get(TypeOf(ObjectReference));
	
	If RightsDescriptionFull = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Description of possible rights for table ""%1"" is not found';ru='Не найдено описание возможных прав для таблицы ""%1""'"),
			ObjectReference.Metadata().FullName());
	EndIf;
	
	RightDetails = RightsDescriptionFull.Get(Right);
	
	If RightDetails = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Description of right ""%1"" for table ""%2"" is not found';ru='Не найдено описание права ""%1"" для таблицы ""%2""'"),
			Right,
			ObjectReference.Metadata().FullName());
	EndIf;
	
	If Not ValueIsFilled(ObjectReference) Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("ObjectReference", ObjectReference);
	Query.SetParameter("User", User);
	Query.SetParameter("Right", Right);
	
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|WHERE
	|	TRUE In
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.ObjectRightsSettings AS RightSettings
	|					INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|					ON
	|						SettingsInheritance.Object = &ObjectReference
	|							AND RightSettings.Right = &Right
	|							AND SettingsInheritance.UseLevel < RightSettings.RightPermissionLevel
	|							AND RightSettings.Object = SettingsInheritance.Parent
	|					INNER JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|					ON
	|						UsersGroupsContents.User = &User
	|							AND UsersGroupsContents.UsersGroup = RightSettings.User)
	|	AND Not FALSE In
	|				(SELECT TOP 1
	|					FALSE
	|				FROM
	|					InformationRegister.ObjectRightsSettings AS RightSettings
	|						INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|						ON
	|							SettingsInheritance.Object = &ObjectReference
	|								AND RightSettings.Right = &Right
	|								AND SettingsInheritance.UseLevel < RightSettings.RightDeniedLevel
	|								AND RightSettings.Object = SettingsInheritance.Parent
	|						INNER JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|						ON
	|							UsersGroupsContents.User = &User
	|								AND UsersGroupsContents.UsersGroup = RightSettings.User)";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for getting subsystem general settings.

// Checks whether access restrictions at the level of record are used.
//
// Returns:
//  Boolean - if True, then access is restricted at the level of records.
//
Function LimitAccessOnRecordsLevel() Export
	
	SetPrivilegedMode(True);
	
	Return GetFunctionalOption("LimitAccessOnRecordsLevel");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used to set managed forms interface.

// Sets an access value form that uses access
// value groups to select allowed values in user access groups.
//
// Supported only if in the access value you selected one
// access values group, not several ones.
//
// For the AccessGroup form item associated with the
// AccessGroup attribute sets a list of access value groups to the selection parameter that provide access for changing access value.
//
// While creating a new access value if the number of access groups
// that provide access to the access value change equals to zero, an exception will be thrown.
//
// If the access values group is written to database that does not provide access to
// the access value change or the number of access values group that provide access
// to the access value change equals to zero, then the ViewOnly form property is set to True.
//
// If the restriction at the level of records is not used or restriction
// by the access kind is not used, then the form item is hidden.
//
// Parameters:
//  Form          - ManagedForm - access value form using
//                   groups to select allowed values.
//
//  Attribute       - Undefined - is the name of the form attribute "Object.AccessGroup".
//                 - String - form item name containing access agroup.
//
//  Items       - Undefined - is the name of the form item "AccessGroup".
//                 - String - form item name.
//                 - Array - form items names.
//
//  ValueType    - Undefined - is to get type from the form attribute "Object.Ref".
//                 - Type - access value reference type.
//
//  NewCreation - Undefined - is to get value
//                   "NOT ValueFilled(Form.Object.Ref)" to determine whether a new access value is created or not.
//                 - Boolean - specified value is used.
//
Procedure OnFormCreationAccessValues(Form,
                                          Attribute       = Undefined,
                                          Items       = Undefined,
                                          ValueType    = Undefined,
                                          NewCreation = Undefined) Export
	
	If TypeOf(NewCreation) <> Type("Boolean") Then
		NewCreation = Not ValueIsFilled(Form.Object.Ref);
	EndIf;
	
	If TypeOf(ValueType) <> Type("Type") Then
		AccessValueType = TypeOf(Form.Object.Ref);
	Else
		AccessValueType = ValueType;
	EndIf;
	
	If Items = Undefined Then
		FormItems = New Array;
		FormItems.Add("AccessGroup");
		
	ElsIf TypeOf(Items) <> Type("Array") Then
		FormItems = New Array;
		FormItems.Add(Items);
	EndIf;
	
	ErrorTitle =
//{{MRG[ <-> ]
		NStr("en='An error occurred"
"in the OnCreateAccessValueForm procedure of the AccessManagement general module.';ru='Ошибка"
"в процедуре ПриСозданииФормыЗначенияДоступа общего модуля УправлениеДоступом.'");
//}}MRG[ <-> ]
//{{MRG[ <-> ]
//		NStr("en='An error occurred
//		|in the OnCreateAccessValueForm procedure of the AccessManagement general module.';ru='Ошибка
//		|в процедуре ПриСозданииФормыЗначенияДоступа общего модуля УправлениеДоступом.'");
//}}MRG[ <-> ]
	
	GroupsProperties = AccessValuesGroupsProperties(AccessValueType, ErrorTitle);
	
	If Attribute = Undefined Then
		AccessValuesGroup = Form.Object.AccessGroup;
	Else
		AccessValuesGroup = Form[Attribute];
	EndIf;
	
	If TypeOf(AccessValuesGroup) <> GroupsProperties.Type Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			ErrorTitle + Chars.LF + Chars.LF +
//{{MRG[ <-> ]
			NStr("en='For access values of"
"the ""%1"" type access kind ""%2"" is used"
"with the values type ""%3"" specified in the overridable module."
"But this type does not match the type ""%4"" in"
"the access value form in the AccessGroup attribute.';ru='Для значений доступа"
"типа ""%1"" используются вид доступа"
"""%2"" с типом значений ""%3"", заданным в переопределяемом модуле."
"Но этот тип не совпадает с типом ""%4"""
"в форме значения доступа у реквизита ГруппаДоступа.'"),
//}}MRG[ <-> ]
//{{MRG[ <-> ]
//			NStr("en='For access values of
//		|the ""%1"" type access kind ""%2"" is used
//		|with the values type ""%3"" specified in the overridable module.
//		|But this type does not match the type ""%4"" in
//		|the access value form in the AccessGroup attribute.';ru='Для значений доступа
//		|типа ""%1"" используются вид доступа
//		|""%2"" с типом значений ""%3"", заданным в переопределяемом модуле.
//		|Но этот тип не совпадает с типом ""%4""
//		|в форме значения доступа у реквизита ГруппаДоступа.'"),
//}}MRG[ <-> ]
			String(AccessValueType),
			String(GroupsProperties.AccessKind),
			String(GroupsProperties.Type),
			String(TypeOf(AccessValuesGroup)));
	EndIf;
	
	If Not LimitAccessOnRecordsLevel()
	 OR Not AccessManagementService.AccessKindIsUsed(GroupsProperties.AccessKind) Then
		
		For Each Item IN FormItems Do
			Form.Items[Item].Visible = False;
		EndDo;
		Return;
	EndIf;
	
	If Users.InfobaseUserWithFullAccess( , , False) Then
		Return;
	EndIf;
	
	If Not AccessRight("Update", Metadata.FindByType(AccessValueType)) Then
		Form.ReadOnly = True;
		Return;
	EndIf;
	
	ValueGroupsForChanges =
		AccessValuesGroupsAllowingAccessValuesChange(AccessValueType);
	
	If ValueGroupsForChanges.Count() = 0
	   AND NewCreation Then
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Allowed ""%1"" are used while adding.';ru='Для добавления требуются разрешенные ""%1"".'"),
			Metadata.FindByType(GroupsProperties.Type).Presentation());
	EndIf;
	
	If ValueGroupsForChanges.Count() = 0
	 OR Not NewCreation
	   AND ValueGroupsForChanges.Find(AccessValuesGroup) = Undefined Then
		
		Form.ReadOnly = True;
		Return;
	EndIf;
	
	If NewCreation
	   AND Not ValueIsFilled(AccessValuesGroup)
	   AND ValueGroupsForChanges.Count() = 1 Then
		
		If Attribute = Undefined Then
			Form.Object.AccessGroup = ValueGroupsForChanges[0];
		Else
			Form[Attribute] = ValueGroupsForChanges[0];
		EndIf;
	EndIf;
	
	NewChoiceParameter = New ChoiceParameter(
		"Filter.Ref", New FixedArray(ValueGroupsForChanges));
	
	ChoiceParameters = New Array;
	ChoiceParameters.Add(NewChoiceParameter);
	
	For Each Item IN FormItems Do
		Form.Items[Item].ChoiceParameters = New FixedArray(ChoiceParameters);
	EndDo;
	
EndProcedure

// Returns access value groups array that allow to change access values.
//
// Supported only if you selected one access values group, not several ones.
//
// Parameters:
//  AccessValuesType - Type - Type of access values reference.
//  ReturnAll      - Boolean - if True, then if there are
//                       no restrictions (all allowed) array of all will be returned instead of Undefined.
//
// Returns:
//  Undefined - all access value groups allow to change access values.
//  Array       - array of found access value groups.
//
Function AccessValuesGroupsAllowingAccessValuesChange(AccessValuesType, ReturnAll = False) Export
	
	ErrorTitle =
//{{MRG[ <-> ]
		NStr("en='An error occurred"
"in the AccessValueGroupsAllowingAccessValuesChange procedure of the AccessManagement general module.';ru='Ошибка"
"в процедуре ГруппыЗначенийДоступаРазрешающиеИзменениеЗначенийДоступа общего модуля УправлениеДоступом.'");
//}}MRG[ <-> ]
//{{MRG[ <-> ]
//		NStr("en='An error occurred
//		|in the AccessValueGroupsAllowingAccessValuesChange procedure of the AccessManagement general module.';ru='Ошибка
//		|в процедуре ГруппыЗначенийДоступаРазрешающиеИзменениеЗначенийДоступа общего модуля УправлениеДоступом.'");
//}}MRG[ <-> ]
	
	GroupsProperties = AccessValuesGroupsProperties(AccessValuesType, ErrorTitle);
	
	If Not AccessRight("Read", Metadata.FindByType(GroupsProperties.Type)) Then
		Return New Array;
	EndIf;
	
	If Not LimitAccessOnRecordsLevel()
	 OR Not AccessManagementService.AccessKindIsUsed(GroupsProperties.AccessKind)
	 OR Users.InfobaseUserWithFullAccess( , , False) Then
		
		If ReturnAll Then
			Query = New Query;
			Query.Text =
			"SELECT ALLOWED
			|	AccessValuesGroups.Ref AS Ref
			|FROM
			|	&AccessValuesGroupsTable AS AccessValuesGroups";
			Query.Text = StrReplace(
				Query.Text, "&AccessValuesGroupTable", GroupsProperties.Table);
			
			Return Query.Execute().Unload().UnloadColumn("Ref");
		EndIf;
		
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("AccessValuesType",  GroupsProperties.ValuesTypeEmptyRef);
	
	Query.SetParameter("IDValuesAccess",
		CommonUse.MetadataObjectID(AccessValuesType));
	
	Query.Text =
	"SELECT
	|	AccessGroups.Ref
	|INTO UserAccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	TRUE In
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.AccessGroupsTables AS AccessGroupsTables
	|			WHERE
	|				AccessGroupsTables.Table = &IDValuesAccess
	|				AND AccessGroupsTables.AccessGroup = AccessGroups.Ref
	|				AND AccessGroupsTables.Update = TRUE)
	|	AND TRUE In
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|					INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|					ON
	|						UsersGroupsContents.Used
	|							AND UsersGroupsContents.User = &CurrentUser
	|							AND AccessGroupsUsers.User = UsersGroupsContents.UsersGroup
	|							AND AccessGroupsUsers.Ref = AccessGroups.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccessValuesGroups.Ref AS Ref
	|INTO ValueGroups
	|FROM
	|	&AccessValuesGroupsTable AS AccessValuesGroups
	|WHERE
	|	TRUE In
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				UserAccessGroups AS UserAccessGroups
	|					INNER JOIN InformationRegister.AccessGroupsDefaultValues AS DefaultValues
	|					ON
	|						DefaultValues.AccessGroup = UserAccessGroups.Ref
	|							AND DefaultValues.AccessValuesType = &AccessValuesType
	|					LEFT JOIN InformationRegister.AccessGroupsValues AS Values
	|					ON
	|						Values.AccessGroup = UserAccessGroups.Ref
	|							AND Values.AccessValue = AccessValuesGroups.Ref
	|			WHERE
	|				ISNULL(Values.ValueAllowed, DefaultValues.AllAllowed))";
	Query.Text = StrReplace(Query.Text, "&AccessValuesGroupTable", GroupsProperties.Table);
	Query.TempTablesManager = New TempTablesManager;
	
	SetPrivilegedMode(True);
	Query.Execute();
	SetPrivilegedMode(False);
	
	Query.Text =
	"SELECT ALLOWED
	|	AccessValuesGroups.Ref AS Ref
	|FROM
	|	&AccessValuesGroupsTable AS AccessValuesGroups
	|		INNER JOIN ValueGroups AS ValueGroups
	|		ON AccessValuesGroups.Ref = ValueGroups.Ref";
	
	Query.Text = StrReplace(
		Query.Text, "&AccessValuesGroupTable", GroupsProperties.Table);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for work with access value sets.

// Checks whether procedure of filling access value sets is provided for metadata object.
// 
// Parameters:
//  Ref - AnyRef - ref to any object.
//
// Returns:
//  Boolean - if True, access value sets can be filled in.
//
Function PossibleToFillAccessValueSets(Ref) Export
	
	ObjectType = Type(CommonUse.ObjectKindByRef(Ref) + "Object." + Ref.Metadata().Name);
	
	SetsAreFilling = AccessManagementServiceReUse.TypesOfObjectsInSubscriptionsToEvents(
		"WriteAccessValueSets
		|WriteDependentAccessValueSets").Get(ObjectType) <> Undefined;
	
	Return SetsAreFilling;
	
EndFunction

// Returns an empty table that is filled in for
// passing to the HasRole function and to FillAccessValueSets (Table) procedures determined by the applied developer.
//
// Returns:
//  ValueTable - with columns:
//    * SetNumber     - Number  - (optional if
//    there is only one set), * AccessKind      - String - optional except of the special ones ReadingRight, EditingRight.
//    * AccessValue - Undefined, CatalogRef - or other
//    (mandatory), * Reading          - Boolean - (optional if the set is for all rights)
//    set for one string of set, * Change       - Boolean - (optional if the set is for all rights) set for one string of set.
//
Function TableAccessValueSets() Export
	
	SetPrivilegedMode(True);
	
	Table = New ValueTable;
	Table.Columns.Add("NumberOfSet",     New TypeDescription("Number", New NumberQualifiers(4, 0, AllowedSign.Nonnegative)));
	Table.Columns.Add("AccessKind",      New TypeDescription("String", New StringQualifiers(20)));
	Table.Columns.Add("AccessValue", Metadata.DefinedTypes.AccessValue.Type);
	Table.Columns.Add("Read",          New TypeDescription("Boolean"));
	Table.Columns.Add("Update",       New TypeDescription("Boolean"));
	// Service field - it can not be filled in or changed (it is filled in automatically).
	Table.Columns.Add("Adjustment",       New TypeDescription("CatalogRef.MetadataObjectIDs"));
	
	Return Table;
	
EndFunction

// FillAccessValueSets (Table) procedure is
// created by the applied developer in the object modules type of which is specified in one of the events subscriptions.
// WriteAccessValueSets or WriteDependentAccessValueSets.
// Access value sets are filled in by the objects properties in the procedure.
//
// Parameter:
//  Table - ValueTable - returned by the AccessValueSetsTable function.
//
// The current eponymous procedure fills in the object access value sets using the procedure.
// FillAccessValueSets (Table) created by the applied developer (see the description above).
// 
// Parameters:
//  Object  - Object, Ref - CatalogObject, DocumentObject, ... CatalogRef, DocumentRef, ...
//            If reference is passed, then object will be received by it.
//
//  Table - ValueTable - returned by the AccessValueSetsTable function of the AccessManagement module.
//          - Undefined - new values table will be created.
//
//  RefOnSubordinatedObject - AnyRef - used when it is required to
//            fill in access values sets of the object-owner for the subordinate object.
//
Procedure FillAccessValueSets(Val Object, Table, Val RefOnSubordinatedObject = Undefined) Export
	
	SetPrivilegedMode(True);
	
	// If reference is passed, then get the object.
	// Object is not changed but used to call the FillAccessValueSets() method.
	Object = ?(Object = Object.Ref, Object.GetObject(), Object);
	ObjectReference = Object.Ref;
	ValueTypeObject = TypeOf(Object);
	
	SetsAreFilling = AccessManagementServiceReUse.TypesOfObjectsInSubscriptionsToEvents(
		"WriteAccessValueSets
		|WriteDependentAccessValueSets").Get(ValueTypeObject) <> Undefined;
	
	If Not SetsAreFilling Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
//{{MRG[ <-> ]
			NStr("en='Wrong parameters."
"Object type"
"""%1"" is found in no subscription"
"to events ""Write access"
"value sets"", ""Write dependent access value sets"".';ru='Неверные параметры."
"Тип"
"объекта ""%1"" не найден ни"
"в одной из подписок"
"на события ""Записать наборы значений доступа"", ""Записать зависимые наборы значений доступа"".'"),
//}}MRG[ <-> ]
//{{MRG[ <-> ]
//			NStr("en='Wrong parameters.
//		|Object type
//		|""%1"" is found in no subscription
//		|to events ""Write access
//		|value sets"", ""Write dependent access value sets"".';ru='Неверные параметры.
//		|Тип
//		|объекта ""%1"" не найден ни
//		|в одной из подписок
//		|на события ""Записать наборы значений доступа"", ""Записать зависимые наборы значений доступа"".'"),
//}}MRG[ <-> ]
			ValueTypeObject);
	EndIf;
	
	Table = ?(TypeOf(Table) = Type("ValueTable"), Table, TableAccessValueSets());
	Object.FillAccessValueSets(Table);
	
	If Table.Count() = 0 Then
		// If you disable this condition, then scheduled
		// job of data filling for access restriction will by cycled.
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Object ""%1"" generated access values empty set.';ru='Объект ""%1"" сформировал пустой набор значений доступа.'"),
			ValueTypeObject);
	EndIf;
	
	ClarifyAccessValueSets(ObjectReference, Table);
	
	If RefOnSubordinatedObject = Undefined Then
		Return;
	EndIf;
	
	// Add the Reading, Change rights check sets
	// of "leading" the object-owner while generating dependent
	// value sets in the procedures prepared by the applied developer.
	//
	// Action is not required while filling the final set
	// (even including dependent sets) as in the standard templates rights check is built into the logic of the "Object" access kind work.
	
	// Add an empty set to select all rights check boxes and arrange set strings.
	AddAccessValueSets(Table, TableAccessValueSets());
	
	// Prepare object sets by the individual rights.
	ReadingSets     = TableAccessValueSets();
	ChangingSets  = TableAccessValueSets();
	For Each String IN Table Do
		If String.Read Then
			NewRow = ReadingSets.Add();
			NewRow.NumberOfSet     = String.NumberOfSet + 1;
			NewRow.AccessKind      = String.AccessKind;
			NewRow.AccessValue = String.AccessValue;
			NewRow.Adjustment       = String.Adjustment;
		EndIf;
		If String.Update Then
			NewRow = ChangingSets.Add();
			NewRow.NumberOfSet     = (String.NumberOfSet + 1)*2;
			NewRow.AccessKind      = String.AccessKind;
			NewRow.AccessValue = String.AccessValue;
			NewRow.Adjustment       = String.Adjustment;
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AccessRightsCorrelation AS AccessRightsCorrelation
	|WHERE
	|	AccessRightsCorrelation.SubordinateTable = &SubordinateTable
	|	AND AccessRightsCorrelation.MasterTableType = &MasterTableType";
	
	Query.SetParameter("SubordinateTable",
		RefOnSubordinatedObject.Metadata().FullName());
	
	TypeArray = New Array;
	TypeArray.Add(TypeOf(ObjectReference));
	TypeDescription = New TypeDescription(TypeArray);
	Query.SetParameter("MasterTableType", TypeDescription.AdjustValue(Undefined));
	
	DependenciesRight = Query.Execute().Unload();
	Table.Clear();
	
	ID = CommonUse.MetadataObjectID(TypeOf(ObjectReference));
	
	If DependenciesRight.Count() = 0 Then
		
		// Add sets by a standard rule.
		
		// Check the Reading right of
		// the sets "leading" object-owner while checking the Reading right of the "subordinate" object.
		String = Table.Add();
		String.NumberOfSet     = 1;
		String.AccessKind      = "ReadRight";
		String.AccessValue = ID;
		String.Read          = True;
		
		// Check the Changing right of
		// the sets "leading" object-owner while checking the Adding, Changing, Deleting rights of the "subordinate" object.
		String = Table.Add();
		String.NumberOfSet     = 2;
		String.AccessKind      = "EditRight";
		String.AccessValue = ID;
		String.Update       = True;
		
		// Mark rights requiring check of reading right restriction sets of the "leading" object-owner.
		ReadingSets.FillValues(True, "Read");
		// Mark rights requiring check of changing right restriction sets of the "leading" object-owner.
		ChangingSets.FillValues(True, "Update");
		
		AddAccessValueSets(ReadingSets, ChangingSets);
		AddAccessValueSets(Table, ReadingSets, True);
	Else
		// Add sets by the non-standard rule: check reading instead of changing.
		
		// Check the Reading right of
		// the sets "leading" object-owner while checking the Reading right of the "subordinate" object.
		String = Table.Add();
		String.NumberOfSet     = 1;
		String.AccessKind      = "ReadRight";
		String.AccessValue = ID;
		String.Read          = True;
		String.Update       = True;
		
		// Mark rights requiring check of reading right restriction sets of the "leading" object-owner.
		ReadingSets.FillValues(True, "Read");
		ReadingSets.FillValues(True, "Update");
		AddAccessValueSets(Table, ReadingSets, True);
	EndIf;
	
EndProcedure

// Allows to add to one access value sets table
// another access value sets tabl using either logical addition, or logical multiplication.
//
// Result is put to the Receiver parameter.
//
// Parameters:
//  Receiver - ValueTable - with the same columns as in the table returned by the AccessValueSetsTable function.
//  Source - ValueTable - with the same columns as in the table returned by the AccessValueSetsTable function.
//
//  Multiplication - Boolean - determines method of source and receiver sets logical join.
//  Simplify - Boolean - determines whether sets simplification is required after adding.
//
Procedure AddAccessValueSets(Receiver, Val Source, Val Multiplication = False, Val Simplify = False) Export
	
	If Source.Count() = 0 AND Receiver.Count() = 0 Then
		Return;
		
	ElsIf Multiplication AND ( Source.Count() = 0 OR  Receiver.Count() = 0 ) Then
		Receiver.Clear();
		Source.Clear();
		Return;
	EndIf;
	
	If Receiver.Count() = 0 Then
		Value = Receiver;
		Receiver = Source;
		Source = Value;
	EndIf;
	
	If Simplify Then
		
		// Determine set copies and string copies in
		// sets within the rights while adding or multiplication.
		//
		// "FromCopy" appear because of the brace expansion in the logical expressions:
		//  For sets within right and different right sets:
		//     X  AND  X =
		//     X, X OR X = X, where X - String-arguments set.
		//  Only for sets within right:
		//     (a AND b AND c) OR (a AND b) = (a AND b), where a,b,c - sets string-arguments.
		// According to these rules the same strings in set and the same sets can be deleted.
		
		If Multiplication Then
			MultiplySetsAndSimplify(Receiver, Source);
		Else // Insert
			AddSetsAndSimplify(Receiver, Source);
		EndIf;
	Else
		
		If Multiplication Then
			MultiplySets(Receiver, Source);
		Else // Insert
			AddSets(Receiver, Source);
		EndIf;
	EndIf;
	
EndProcedure

// Updates object access value sets if they have changed.
//  Sets are updated in tabular section (if
// used) and in the AccessValueSets information register.
//
// Parameters:
//  ObjectReference - CatalogRef, DocumentRef and other types
//                   of refs of those metadata objects for which access value sets are filled in.
//
Procedure UpdateSetsOfAccessValues(ObjectReference) Export
	
	AccessManagementService.UpdateSetsOfAccessValues(ObjectReference);
	
EndProcedure

// Handler of the FillTabularSectionsAccessValueSets* subscriptions
// to the BeforeWrite event calls access values filling
// of the object tabular section AccessValueSets when the #ByValueSets template is applied to the object for access restriction.
//  It is possible to use the
// Access management subsystem when the specified subscription does not exist if sets are not applied for the specified aim.
//
// Parameters:
//  Source        - CatalogObject,
//                    DocumentObject,
//                    ChartOfCharacteristicTypesObject,
//                    ChartChartOfAccountsObject,
//                    ChartOfCalculationTypesObject,
//                    BusinessProcessObject,
//                    TaskObject,
//                    ExchangePlanObject - data object passed to the BeforeWrite event subscription.
//
//  Cancel           - Boolean - parameter passed to the BeforeWrite event subscription.
//
//  WriteMode     - Boolean - parameter passed to the BeforeWrite
//                    event subscription when the Source parameter type - DocumentObject.
//
//  PostingMode - Boolean - parameter passed to the BeforeWrite
//                    event subscription when the Source parameter type - DocumentObject.
//
Procedure FillAccessValueSetsOfTabularSections(Source, Cancel = Undefined, WriteMode = Undefined, PostingMode = Undefined) Export
	
	If Source.DataExchange.Load
	   AND Not Source.AdditionalProperties.Property("RecordSetsOfAccessValues") Then
		
		Return;
	EndIf;
	
	If Not (  PrivilegedMode()
	         AND Source.AdditionalProperties.Property(
	             "AccessValueSetsTablePartsFilled")) Then
		
		Table = AccessManagementService.GetAccessValueSetsOfTabularSection(Source);
		AccessManagementService.PrepareAccessToRecordsValuesSets(Undefined, Table, False);
		Source.AccessValuesSets.Load(Table);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used in the overridable module.

// Returns structure for easy description of the supplied profiles.
// 
//  To specify preset access
// kind, you should specify the Preset string in the presentation.
// 
//  To add access value, you should specify full name
// of the predefined item, for example, "Catalog.UsersGroups.AllUsers".
// 
// Identifier is extracted from the actual item in the catalog.
// You should not take IDs received randomly.
// 
// Example:
// 
// // Profile "User".
// ProfileDescription = AccessManagement.AccessGroupsProfileNewDescription();
// ProfileDescription.Name           = "User";
// ProfileDescription.ID ="09e56dbf-90a0-11de-862c-001d600d9ad2";
// ProfileDescription.Description  = NStr("en='User';ru='Пользователь'");
// ProfileDescription.Definition =
// 	NStr("en = 'General allowed actions for most of the users.
// 	           |These are view rights of the information system data as a rule.'");
// // Use 1C:Enterprise.
// ProfileDescription.Roles.Add("ThinClientStart");
// ProfileDescription.Roles.Add("OutputToPrinterClipboardFile");
// ProfileDescription.Roles.Add("SaveUserData");
// // ...
//  Use application.
// ProfileDescription.Roles.Add("BasicRights");
// ProfileDescription.Roles.Add("ViewProgramChangesDescription");
// ProfileDescription.Roles.Add("CurrentUserChange");
// // ...
//  Use RRI.
// ProfileDescription.Roles.Add("ReadBasicRRI");
// ProfileDescription.Roles.Add("ReadGeneralBasicRRI");
// // ...
//  Typical possibilities.
// ProfileDescription.Roles.Add("UseReportVariants");
// ProfileDescription.Roles.Add("UseSubordinationStructure");
// // ...
//  Main possibilities of the profile.
// ProfileDescription.Roles.Add("UseNotes");
// ProfileDescription.Roles.Add("UseReminders");
// ProfileDescription.Roles.Add("AddJobsChange");
// ProfileDescription.Roles.Add("ChangeJobsExecution");
// // ...
//  Profile access restriction kinds.
// ProfileDescription.AccessGroups.Add("Companies");
// ProfileDescription.AccessGroups.Add("Users", "Preset");
// ProfileDescription.AccessGroups.Add("EconomicOperations", "Preset");
// ProfileDescription.AccessValues.Add("EconomicOperations",
// 	"Enum.EconomicOperations.IssueCashToAdvanceHolder);
// // ...
// ProfilesDescription.Add(ProfileDescription);
//
Function AccessGroupProfileNewDescription() Export
	
	NewDetails = New Structure;
	NewDetails.Insert("Name",             ""); // PredefinedDataName
	                                               // is used to check the bind of supplied data to the predefined item.
	NewDetails.Insert("ID",   ""); // IDSuppliedData
	NewDetails.Insert("Description",    "");
	NewDetails.Insert("Definition",        "");
	NewDetails.Insert("Roles",            New Array);
	NewDetails.Insert("AccessKinds",     New ValueList);
	NewDetails.Insert("AccessValues", New ValueList);
	
	Return NewDetails;
	
EndFunction

// Adds additional types in
// the OnFillingAccessKinds procedure of the AccessManagementOverridable general module.
//
// Parameters:
//  AccessKind             - ValueTableRow - added to the AccessKinds parameter.
//  ValuesType            - Type - access values additional type.
//  ValueGroupType       - Type - additional type of access
//                           value groups may match to the value groups type specified earlier for the same access kind.
//  SeveralGroupsOfValues - Boolean - True if you can specify
//                           several values groups in the access values additional type (there is the AccessGroups tabular section).
// 
Procedure AddAdditionalAccessKindTypes(AccessKind, ValuesType,
		ValueGroupType = Undefined, SeveralGroupsOfValues = False) Export
	
	AdditionalTypes = AccessKind.AdditionalTypes;
	
	If AdditionalTypes.Columns.Count() = 0 Then
		AdditionalTypes.Columns.Add("ValuesType",            New TypeDescription("Type"));
		AdditionalTypes.Columns.Add("ValueGroupType",       New TypeDescription("Type"));
		AdditionalTypes.Columns.Add("SeveralGroupsOfValues", New TypeDescription("Boolean"));
	EndIf;
	
	NewRow = AdditionalTypes.Add();
	NewRow.ValuesType            = ValuesType;
	NewRow.ValueGroupType       = ValueGroupType;
	NewRow.SeveralGroupsOfValues = SeveralGroupsOfValues;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used during the infobase update.

// Returns reference to the supplied profile by ID.
//
// Parameters:
//  ID - String - name or unique ID of the
//                  supplied profile as it is specified in the OnFillingAccessKinds procedure of the AccessManagementOverridable general module.
//
// Returns:
//  CatalogRef.AccessGroupsProfiles - if supplied profile is found in the catalog.
//  Undefined - if supplied profile is not found in the catalog.
//
Function ProfileSuppliedByIdIdentificator(ID) Export
	
	Return Catalogs.AccessGroupsProfiles.ProfileSuppliedByIdIdentificator(ID);
	
EndFunction

// Returns empty table for
// filling and passing to the ReplaceRightsInObjectRightSettings procedure.
//
// Returns:
//  ValueTable - with columns:
//    * OwnersType - Ref - empty reference of the rights owner type from the types descriptions.
//                      RightSettingsOwner, for example, FileFolders catalog empty reference.
//    * OldName     - String - old right name.
//    * NewName      - String - right new name.
//
Function RightReplacementTableInObjectRighsSettings() Export
	
	Dimensions = Metadata.InformationRegisters.ObjectRightsSettings.Dimensions;
	
	Table = New ValueTable;
	Table.Columns.Add("OwnerType", Dimensions.Object.Type);
	Table.Columns.Add("OldName",     Dimensions.Right.Type);
	Table.Columns.Add("NewName",      Dimensions.Right.Type);
	
	Return Table;
	
EndFunction

// Replaces rights used in the object right settings.
// After replacement is executed, ObjectRightSettings helper
// information register data will be updated,
// that is why you should call this procedure only once not to decrease productivity.
// 
// Parameters:
//  RenamingsTable - ValueTable - with columns:
//    * OwnersType - Ref - empty reference of the rights owner type from the types descriptions.
//                      RightSettingsOwner, for example, FileFolders catalog empty reference.
//    * OldName     - String - right old name related to the specified owners type.
//    * NewName      - String - right  new name related to the specified owners type.
//                      If an empty string is specified, setting of an old right will be deleted.
//                      If an old name is assigned to two
//                      new names, then one old setting will be reproduced in two new ones.
//  
Procedure ReplaceRightsInObjectRightSettings(RenamingsTable) Export
	
	Query = New Query;
	Query.Parameters.Insert("RenamingsTable", RenamingsTable);
	Query.Text =
	"SELECT
	|	RenamingsTable.OwnerType,
	|	RenamingsTable.OldName,
	|	RenamingsTable.NewName
	|INTO RenamingsTable
	|FROM
	|	&RenamingsTable AS RenamingsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightSettings.Object,
	|	RightSettings.User,
	|	RightSettings.Right,
	|	MAX(RightSettings.RightDenied) AS RightDenied,
	|	MAX(RightSettings.InheritanceAllowed) AS InheritanceAllowed,
	|	MAX(RightSettings.SetupOrder) AS SetupOrder
	|INTO RightsOldSettings
	|FROM
	|	InformationRegister.ObjectRightsSettings AS RightSettings
	|
	|GROUP BY
	|	RightSettings.Object,
	|	RightSettings.User,
	|	RightSettings.Right
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsOldSettings.Object,
	|	RightsOldSettings.User,
	|	RenamingsTable.OldName,
	|	RenamingsTable.NewName,
	|	RightsOldSettings.RightDenied,
	|	RightsOldSettings.InheritanceAllowed,
	|	RightsOldSettings.SetupOrder
	|INTO RightSettings
	|FROM
	|	RightsOldSettings AS RightsOldSettings
	|		INNER JOIN RenamingsTable AS RenamingsTable
	|		ON (VALUETYPE(RightsOldSettings.Object) = VALUETYPE(RenamingsTable.OwnerType))
	|			AND RightsOldSettings.Right = RenamingsTable.OldName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightSettings.NewName
	|FROM
	|	RightSettings AS RightSettings
	|
	|GROUP BY
	|	RightSettings.Object,
	|	RightSettings.User,
	|	RightSettings.NewName
	|
	|HAVING
	|	RightSettings.NewName <> """" AND
	|	COUNT(RightSettings.NewName) > 1
	|
	|UNION
	|
	|SELECT
	|	RightSettings.NewName
	|FROM
	|	RightSettings AS RightSettings
	|		LEFT JOIN RightsOldSettings AS RightsOldSettings
	|		ON RightSettings.Object = RightsOldSettings.Object
	|			AND RightSettings.User = RightsOldSettings.User
	|			AND RightSettings.NewName = RightsOldSettings.Right
	|WHERE
	|	Not RightsOldSettings.Right IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightSettings.Object,
	|	RightSettings.User,
	|	RightSettings.OldName,
	|	RightSettings.NewName,
	|	RightSettings.RightDenied,
	|	RightSettings.InheritanceAllowed,
	|	RightSettings.SetupOrder
	|FROM
	|	RightSettings AS RightSettings";
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ObjectRightsSettings");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		ResultsOfQuery = Query.ExecuteBatch();
		
		RepeatedNewNames = ResultsOfQuery[ResultsOfQuery.Count()-2].Unload();
		
		If RepeatedNewNames.Count() > 0 Then
			RepeatedRightsNewNames = "";
			For Each String IN RepeatedNewNames Do
				RepeatedRightsNewNames = RepeatedRightsNewNames
					+ ?(ValueIsFilled(RepeatedRightsNewNames), "," + Chars.LF, "")
					+ String.NewName;
			EndDo;
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
//{{MRG[ <-> ]
				NStr("en='An error occurred in"
"the RenameRightInObjectRightsSettings procedure parameters of the AccessManagement general module."
""
"Settings of the following rights new names will"
"be repeated: %1.';ru='Ошибка в"
"параметрах процедуры ПереименоватьПравоВНастройкахПравОбъектов общего модуля УправлениеДоступом."
""
"После обновления будут повторяться настройки"
"следующих новых имен прав: %1.'"),
//}}MRG[ <-> ]
//{{MRG[ <-> ]
//				NStr("en='An error occurred in
//		|the RenameRightInObjectRightsSettings procedure parameters of the AccessManagement general module.
//		|
//		|Settings of the following rights new names will
//		|be repeated: %1.';ru='Ошибка в
//		|параметрах процедуры ПереименоватьПравоВНастройкахПравОбъектов общего модуля УправлениеДоступом.
//		|
//		|После обновления будут повторяться настройки
//		|следующих новых имен прав: %1.'"),
//}}MRG[ <-> ]
				RepeatedRightsNewNames);
		EndIf;
		
		ReplacementTable = ResultsOfQuery[ResultsOfQuery.Count()-1].Unload();
		
		RecordSet = InformationRegisters.ObjectRightsSettings.CreateRecordSet();
		
		For Each String IN ReplacementTable Do
			RecordSet.Filter.Object.Set(String.Object);
			RecordSet.Filter.User.Set(String.User);
			RecordSet.Filter.Right.Set(String.OldName);
			RecordSet.Read();
			If RecordSet.Count() > 0 Then
				RecordSet.Clear();
				RecordSet.Write();
			EndIf;
		EndDo;
		
		NewRecord = RecordSet.Add();
		For Each String IN ReplacementTable Do
			If String.NewName = "" Then
				Continue;
			EndIf;
			RecordSet.Filter.Object.Set(String.Object);
			RecordSet.Filter.User.Set(String.User);
			RecordSet.Filter.Right.Set(String.NewName);
			FillPropertyValues(NewRecord, String);
			NewRecord.Right = String.NewName;
			RecordSet.Write();
		EndDo;
		
		InformationRegisters.ObjectRightsSettings.UpdateAuxiliaryRegisterData();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used to update service data.

// Updates the list of roles of infobase
// users by their belonging to access groups. IB users with the "FullRights" role are skipped.
// 
// Parameters:
//  UserArray - Array, Undefined, Type - array from items.
//     CatalogRef.Users or CatalogRef.ExternalUsers.
//     If Undefined, then update roles of all users.
//     If Type = Catalog.ExternalUsers, then the roles of
//     all external users will be updated, otherwise the roles of all users will be updated.
//
//  ServiceUserPassword - String - Password for authorization in service manager.
//
Procedure UpdateUsersRoles(Val UserArray = Undefined, Val ServiceUserPassword = Undefined) Export
	
	AccessManagementService.UpdateUsersRoles(UserArray, ServiceUserPassword);
	
EndProcedure

// Updates AccessGroupsValues and AccessGroupsDefaultValues
// registers content that are filled in based on the settings in the access groups and access kinds using.
//
Procedure RefreshAllowedValuesOnChangeAccessKindsUsage() Export
	
	InformationRegisters.AccessGroupsValues.RefreshDataRegister();
	
EndProcedure

// Successively fills in and partially updates data required for
// the AccessManagement subsystem work in the access restriction mode at the level of records.
// 
//  If access restriction mode is enabled on the records
// level, it fills in access value sets. Filled in partially during each start
// until all access value sets are not filled in.
//  When you disable the mode of access restriction on the
// records level, access value sets (filled in earlier) are removed while overwriting objects and not all at once.
//  Regardless of the access restriction mode at
// the level of records updates secondary data: access value groups and additional fields in the existing access value sets.
//  It disables scheduled job use after all
// updates and fillings are complete.
//
//  Information on the work state is written to the events log monitor.
//
//  It is possible to call it applicationmatically, for example, while updating the infobase.
//
// Parameters:
//  DataQuantity - Number - (return value) contains
//                     the number of data objects for which filling was executed.
//
Procedure DataFillingForAccessLimit(DataQuantity = 0) Export
	
	AccessManagementService.DataFillingForAccessLimit(DataQuantity);
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// Addition to the FillAccessValueSets procedure.

// Converts value sets table to the format of tabular section or records set.
//  Executed before writing to the
// AccessValueSets register or before writing oblect with the AccessValueSets tabular section.
//
// Parameters:
//  ObjectReference - CatalogRef.*, DocumentRef.*, ...
//  Table        - InformationRegisterRecordSet.AccessValuesSets
//
Procedure ClarifyAccessValueSets(ObjectReference, Table)
	
	AccessKindNames = AccessManagementServiceReUse.Parameters().AccessKindsProperties.ByNames;
	
	RightSettingsOwnerTypes = AccessManagementServiceReUse.Parameters(
		).PossibleRightsForObjectRightsSettings.ByRefsTypes;
	
	For Each String IN Table Do
		
		If RightSettingsOwnerTypes.Get(TypeOf(String.AccessValue)) <> Undefined
		   AND Not ValueIsFilled(String.Adjustment) Then
			
			String.Adjustment = CommonUse.MetadataObjectID(TypeOf(ObjectReference));
		EndIf;
		
		If String.AccessKind = "" Then
			Continue;
		EndIf;
		
		If String.AccessKind = "ReadRight"
		 OR String.AccessKind = "EditRight" Then
			
			If TypeOf(String.AccessValue) <> Type("CatalogRef.MetadataObjectIDs") Then
				String.AccessValue =
					CommonUse.MetadataObjectID(TypeOf(String.AccessValue));
			EndIf;
			
			If String.AccessKind = "ReadRight" Then
				String.Adjustment = Catalogs.MetadataObjectIDs.EmptyRef();
			Else
				String.Adjustment = String.AccessValue;
			EndIf;
		
		ElsIf AccessKindNames.Get(String.AccessKind) <> Undefined
		      OR String.AccessKind = "RightSettings" Then
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
//{{MRG[ <-> ]
				NStr("en='Object ""%1"" generated access"
"values set containing known access kind ""%2"" that should not be specified."
""
"Specify only special access"
"kinds ""ReadingRight"", ""ChangingRight"" if they are used.';ru='Объект ""%1"""
"сформировал набор значений доступа, содержащий известный вид доступа ""%2"", который не требуется указывать."
""
"Указывать требуется"
"только специальные виды доступа ""ПравоЧтения"", ""ПравоИзменения"", если они используются.'"),
//}}MRG[ <-> ]
//{{MRG[ <-> ]
//				NStr("en='Object ""%1"" generated access
//		|values set containing known access kind ""%2"" that should not be specified.
//		|
//		|Specify only special access
//		|kinds ""ReadingRight"", ""ChangingRight"" if they are used.';ru='Объект ""%1""
//		|сформировал набор значений доступа, содержащий известный вид доступа ""%2"", который не требуется указывать.
//		|
//		|Указывать требуется
//		|только специальные виды доступа ""ПравоЧтения"", ""ПравоИзменения"", если они используются.'"),
//}}MRG[ <-> ]
				TypeOf(ObjectReference),
				String.AccessKind);
		Else
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
//{{MRG[ <-> ]
				NStr("en='Object ""%1"" generated access"
"values set containing unknown access kind ""%2"".';ru='Объект ""%1"""
"сформировал набор значений доступа, содержащий неизвестный вид доступа ""%2"".'"),
//}}MRG[ <-> ]
//{{MRG[ <-> ]
//				NStr("en='Object ""%1"" generated access
//		|values set containing unknown access kind ""%2"".';ru='Объект ""%1""
//		|сформировал набор значений доступа, содержащий неизвестный вид доступа ""%2"".'"),
//}}MRG[ <-> ]
				TypeOf(ObjectReference),
				String.AccessKind);
		EndIf;
		
		String.AccessKind = "";
	EndDo;
	
EndProcedure

// Add to the AddAccessValueSets procedure.

Function TableSets(Table, RightsNormalization = False)
	
	TableSets = New Map;
	
	For Each String IN Table Do
		Set = TableSets.Get(String.NumberOfSet);
		If Set = Undefined Then
			Set = New Structure;
			Set.Insert("Read", False);
			Set.Insert("Update", False);
			Set.Insert("Rows", New Array);
			TableSets.Insert(String.NumberOfSet, Set);
		EndIf;
		If String.Read Then
			Set.Read = True;
		EndIf;
		If String.Update Then
			Set.Update = True;
		EndIf;
		Set.Rows.Add(String);
	EndDo;
	
	If RightsNormalization Then
		For Each DescriptionOfSet IN TableSets Do
			Set = DescriptionOfSet.Value;
			
			If Not Set.Read AND Not Set.Update Then
				Set.Read    = True;
				Set.Update = True;
			EndIf;
		EndDo;
	EndIf;
	
	Return TableSets;
	
EndFunction

Procedure AddSets(Receiver, Source)
	
	ReceiverSets = TableSets(Receiver);
	SourceSets = TableSets(Source);
	
	SetMaxNumber = -1;
	
	For Each ReceiverSetDescription IN ReceiverSets Do
		ReceiverSet = ReceiverSetDescription.Value;
		
		If Not ReceiverSet.Read AND Not ReceiverSet.Update Then
			ReceiverSet.Read    = True;
			ReceiverSet.Update = True;
		EndIf;
		
		For Each String IN ReceiverSet.Rows Do
			String.Read    = ReceiverSet.Read;
			String.Update = ReceiverSet.Update;
		EndDo;
		
		If ReceiverSetDescription.Key > SetMaxNumber Then
			SetMaxNumber = ReceiverSetDescription.Key;
		EndIf;
	EndDo;
	
	NewSetNumber = SetMaxNumber + 1;
	
	For Each SourceSetDescription IN SourceSets Do
		SourceSet = SourceSetDescription.Value;
		
		If Not SourceSet.Read AND Not SourceSet.Update Then
			SourceSet.Read    = True;
			SourceSet.Update = True;
		EndIf;
		
		For Each SourceRow IN SourceSet.Rows Do
			NewRow = Receiver.Add();
			FillPropertyValues(NewRow, SourceRow);
			NewRow.NumberOfSet = NewSetNumber;
			NewRow.Read      = SourceSet.Read;
			NewRow.Update   = SourceSet.Update;
		EndDo;
		
		NewSetNumber = NewSetNumber + 1;
	EndDo;
	
EndProcedure

Procedure MultiplySets(Receiver, Source)
	
	ReceiverSets = TableSets(Receiver);
	SourceSets = TableSets(Source, True);
	Table = TableAccessValueSets();
	
	SetCurrentNumber = 1;
	For Each ReceiverSetDescription IN ReceiverSets Do
			ReceiverSet = ReceiverSetDescription.Value;
		
		If Not ReceiverSet.Read AND Not ReceiverSet.Update Then
			ReceiverSet.Read    = True;
			ReceiverSet.Update = True;
		EndIf;
		
		For Each SourceSetDescription IN SourceSets Do
			SourceSet = SourceSetDescription.Value;
			
			ReadingMultiplication    = ReceiverSet.Read    AND SourceSet.Read;
			ChangeMultiplication = ReceiverSet.Update AND SourceSet.Update;
			If Not ReadingMultiplication AND Not ChangeMultiplication Then
				Continue;
			EndIf;
			For Each TargetRow IN ReceiverSet.Rows Do
				String = Table.Add();
				FillPropertyValues(String, TargetRow);
				String.NumberOfSet = SetCurrentNumber;
				String.Read      = ReadingMultiplication;
				String.Update   = ChangeMultiplication;
			EndDo;
			For Each SourceRow IN SourceSet.Rows Do
				String = Table.Add();
				FillPropertyValues(String, SourceRow);
				String.NumberOfSet = SetCurrentNumber;
				String.Read      = ReadingMultiplication;
				String.Update   = ChangeMultiplication;
			EndDo;
			SetCurrentNumber = SetCurrentNumber + 1;
		EndDo;
	EndDo;
	
	Receiver = Table;
	
EndProcedure

Procedure AddSetsAndSimplify(Receiver, Source)
	
	ReceiverSets = TableSets(Receiver);
	SourceSets = TableSets(Source);
	
	ResultSets   = New Map;
	TypesCodes          = New Map;
	EnumCodes   = New Map;
	SetStringsTable = New ValueTable;
	
	FillTypeCodesAndSetStringsTable(TypesCodes, EnumCodes, SetStringsTable);
	
	SetCurrentNumber = 1;
	
	AddSetsToResultWithSimplification(
		ResultSets, ReceiverSets, SetCurrentNumber, TypesCodes, EnumCodes, SetStringsTable);
	
	AddSetsToResultWithSimplification(
		ResultSets, SourceSets, SetCurrentNumber, TypesCodes, EnumCodes, SetStringsTable);
	
	FillReceiverByResultSets(Receiver, ResultSets);
	
EndProcedure

Procedure MultiplySetsAndSimplify(Receiver, Source)
	
	ReceiverSets = TableSets(Receiver);
	SourceSets = TableSets(Source, True);
	
	ResultSets   = New Map;
	TypesCodes          = New Map;
	EnumCodes   = New Map;
	SetStringsTable = New ValueTable;
	
	FillTypeCodesAndSetStringsTable(TypesCodes, EnumCodes, SetStringsTable);
	
	SetCurrentNumber = 1;
	
	For Each ReceiverSetDescription IN ReceiverSets Do
		ReceiverSet = ReceiverSetDescription.Value;
		
		If Not ReceiverSet.Read AND Not ReceiverSet.Update Then
			ReceiverSet.Read    = True;
			ReceiverSet.Update = True;
		EndIf;
		
		For Each SourceSetDescription IN SourceSets Do
			SourceSet = SourceSetDescription.Value;
			
			ReadingMultiplication    = ReceiverSet.Read    AND SourceSet.Read;
			ChangeMultiplication = ReceiverSet.Update AND SourceSet.Update;
			If Not ReadingMultiplication AND Not ChangeMultiplication Then
				Continue;
			EndIf;
			
			SetRows = SetStringsTable.Copy();
			
			For Each TargetRow IN ReceiverSet.Rows Do
				String = SetRows.Add();
				String.AccessKind      = TargetRow.AccessKind;
				String.AccessValue = TargetRow.AccessValue;
				String.Adjustment       = TargetRow.Adjustment;
				FillStringID(String, TypesCodes, EnumCodes);
			EndDo;
			For Each SourceRow IN SourceSet.Rows Do
				String = SetRows.Add();
				String.AccessKind      = SourceRow.AccessKind;
				String.AccessValue = SourceRow.AccessValue;
				String.Adjustment       = SourceRow.Adjustment;
				FillStringID(String, TypesCodes, EnumCodes);
			EndDo;
			
			SetRows.GroupBy("StringID, AccessKind, AccessValue, Adjustment");
			SetRows.Sort("RowID");
			
			IDSet = "";
			For Each String IN SetRows Do
				IDSet = IDSet + String.RowID + Chars.LF;
			EndDo;
			
			ExistingSet = ResultSets.Get(IDSet);
			If ExistingSet = Undefined Then
				
				PropertiesSet = New Structure;
				PropertiesSet.Insert("Read",      ReadingMultiplication);
				PropertiesSet.Insert("Update",   ChangeMultiplication);
				PropertiesSet.Insert("Rows",      SetRows);
				PropertiesSet.Insert("NumberOfSet", SetCurrentNumber);
				ResultSets.Insert(IDSet, PropertiesSet);
				SetCurrentNumber = SetCurrentNumber + 1;
			Else
				If ReadingMultiplication Then
					ExistingSet.Read = True;
				EndIf;
				If ChangeMultiplication Then
					ExistingSet.Update = True;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	FillReceiverByResultSets(Receiver, ResultSets);
	
EndProcedure

Procedure FillTypeCodesAndSetStringsTable(TypesCodes, EnumCodes, SetStringsTable)
	
	EnumCodes = AccessManagementServiceReUse.EnumCodes();
	
	TypesCodes = AccessManagementServiceReUse.RefTypeCodes("DefinedType.AccessValue");
	
	TypeCodeLength = 0;
	For Each KeyAndValue IN TypesCodes Do
		TypeCodeLength = StrLen(KeyAndValue.Value);
		Break;
	EndDo;
	
	StringLengthID =
		20 // Access kind name string
		+ TypeCodeLength
		+ 36 // Length of unique ID string presentation (access values).
		+ 36 // Length of unique ID string presentation (adjustment).
		+ 6; // Place for separators
	
	SetStringsTable = New ValueTable;
	SetStringsTable.Columns.Add("RowID", New TypeDescription("String", New StringQualifiers(StringLengthID)));
	SetStringsTable.Columns.Add("AccessKind",          New TypeDescription("String", New StringQualifiers(20)));
	SetStringsTable.Columns.Add("AccessValue",     Metadata.DefinedTypes.AccessValue.Type);
	SetStringsTable.Columns.Add("Adjustment",           New TypeDescription("CatalogRef.MetadataObjectIDs"));
	
EndProcedure

Procedure FillStringID(String, TypesCodes, EnumCodes)
	
	If String.AccessValue = Undefined Then
		PermissionValueID = "";
	Else
		PermissionValueID = EnumCodes.Get(String.AccessValue);
		If PermissionValueID = Undefined Then
			PermissionValueID = String(String.AccessValue.UUID());
		EndIf;
	EndIf;
	
	String.RowID = String.AccessKind + ";"
		+ TypesCodes.Get(TypeOf(String.AccessValue)) + ";"
		+ PermissionValueID + ";"
		+ String.Adjustment.UUID() + ";";
	
EndProcedure

Procedure AddSetsToResultWithSimplification(ResultSets, AddedSets, SetCurrentNumber, TypesCodes, EnumCodes, SetStringsTable)
	
	For Each AddedSetDescription IN AddedSets Do
		AddedSet = AddedSetDescription.Value;
		
		If Not AddedSet.Read AND Not AddedSet.Update Then
			AddedSet.Read    = True;
			AddedSet.Update = True;
		EndIf;
		
		SetRows = SetStringsTable.Copy();
		
		For Each AddedSetString IN AddedSet.Rows Do
			String = SetRows.Add();
			String.AccessKind      = AddedSetString.AccessKind;
			String.AccessValue = AddedSetString.AccessValue;
			String.Adjustment       = AddedSetString.Adjustment;
			FillStringID(String, TypesCodes, EnumCodes);
		EndDo;
		
		SetRows.GroupBy("StringID, AccessKind, AccessValue, Adjustment");
		SetRows.Sort("RowID");
		
		IDSet = "";
		For Each String IN SetRows Do
			IDSet = IDSet + String.RowID + Chars.LF;
		EndDo;
		
		ExistingSet = ResultSets.Get(IDSet);
		If ExistingSet = Undefined Then
			
			PropertiesSet = New Structure;
			PropertiesSet.Insert("Read",      AddedSet.Read);
			PropertiesSet.Insert("Update",   AddedSet.Update);
			PropertiesSet.Insert("Rows",      SetRows);
			PropertiesSet.Insert("NumberOfSet", SetCurrentNumber);
			ResultSets.Insert(IDSet, PropertiesSet);
			
			SetCurrentNumber = SetCurrentNumber + 1;
		Else
			If AddedSet.Read Then
				ExistingSet.Read = True;
			EndIf;
			If AddedSet.Update Then
				ExistingSet.Update = True;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Function FillReceiverByResultSets(Receiver, ResultSets)
	
	Receiver = TableAccessValueSets();
	
	For Each DescriptionOfSet IN ResultSets Do
		PropertiesSet = DescriptionOfSet.Value;
		For Each String IN PropertiesSet.Rows Do
			NewRow = Receiver.Add();
			NewRow.NumberOfSet     = PropertiesSet.NumberOfSet;
			NewRow.AccessKind      = String.AccessKind;
			NewRow.AccessValue = String.AccessValue;
			NewRow.Adjustment       = String.Adjustment;
			NewRow.Read          = PropertiesSet.Read;
			NewRow.Update       = PropertiesSet.Update;
		EndDo;
	EndDo;
	
EndFunction

// Add to the procedures:
// - OnCreateAccessValueForm
// - AccessValuesGroupsAllowingAccessValuesChange

Function AccessValuesGroupsProperties(AccessValueType, ErrorTitle)
	
	SetPrivilegedMode(True);
	
	GroupsProperties = New Structure;
	
	AccessTypeProperties = AccessManagementServiceReUse.Parameters(
		).AccessKindsProperties.AccessValuesWithGroups.ByTypes.Get(AccessValueType);
	
	If AccessTypeProperties = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			ErrorTitle + Chars.LF + Chars.LF +
//{{MRG[ <-> ]
			NStr("en='For the access values"
"of the ""%1"" type access value groups are not used.';ru='Для значений"
"доступа типа ""%1"" не используются группы значений доступа.'"),
//}}MRG[ <-> ]
//{{MRG[ <-> ]
//			NStr("en='For the access values
//		|of the ""%1"" type access value groups are not used.';ru='Для значений
//		|доступа типа ""%1"" не используются группы значений доступа.'"),
//}}MRG[ <-> ]
			String(AccessValueType));
	EndIf;
	
	GroupsProperties.Insert("AccessKind", AccessTypeProperties.Name);
	GroupsProperties.Insert("Type",        AccessTypeProperties.ValueGroupType);
	
	GroupsProperties.Insert("Table",    Metadata.FindByType(
		AccessTypeProperties.ValueGroupType).FullName());
	
	GroupsProperties.Insert("ValuesTypeEmptyRef",
		AccessManagementService.MetadataObjectEmptyRef(AccessValueType));
	
	Return GroupsProperties;
	
EndFunction

#EndRegion
