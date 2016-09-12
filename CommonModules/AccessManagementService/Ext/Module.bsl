////////////////////////////////////////////////////////////////////////////////
// Subsystem "Access management".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Declaring service events to which handlers can be attached.

// Declares the events of AccessManagement subsystem:
//
// Server events:
//   WhenFillingInPossibleRightsForObjectRightsSetup,
//   WhenFillingInAccessRightDependencies,
//   WhenFillingInRestrictionKindsForMetadataObjectsRights,
//   WhenFillingInAccessKinds,
//   WhenFillingInSuppliedAccessGroupsProfiles,
//   WhenFillingInAccessKindUse,
//   WhenChangingAccessValuesSets,
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Fills in descriptions of possible rights appointed for objects, specified types.
	// 
	// Parameters:
	//  PossibleRights - ValuesTable that
	//                   contains the fields descriptions of which you can
	//                   see in the comment to function InformationRegisters.ObjectRightsSettings.PossibleRights().
	//
	// Syntax:
	// Procedure WhenFillingInPossibleRightsForObectRightsSetup (Value PossibleRights) Export
	//
	// (same as AccessManagementOverridable.WhenFillingInPossibleRightsForObjectRightsSetup).
	//
	ServerEvents.Add("StandardSubsystems.AccessManagement\OnFillingInPossibleRightsForObjectRightsSettings");
	
	// Fills in the dependencies of access rights of
	// "subordinate" object, for example, tasks PerformerTask from "leading" object, such as business process Job, that differ from the standard one.
	//
	// Rights dependencies are used in the standard template of access restriction for access kind "Object":
	// 1) normally when reading "subordinate"
	//    object the right for reading of
	//    "leading" object and the absence of restriction for "leading" object reading is checked;
	// 2) normally when you add, edit or
	//    delete "subordinate" object the existence of
	//    the right on "leading" object change is checked as well as the absence of restriction on "leading" object change.
	//
	// Only one reassignment is allowed compared to standard one:
	// in paragraph "2)" instead of check of right on
	// "leading" object change set check of right on "leading" object reading.
	//
	// Parameters:
	//  DependenciesRight - ValuesTable with columns:
	//                    - MasterTable     - String, for example, "BusinessProcess.Task".
	//                    - SubordinateTable - String, for example, "Task.ProviderTask".
	//
	// Syntax:
	// Procedure WhenFillingInAccessRightsDependecies (RightsDependecies) Export
	//
	// (same as AccessManagementOverridable.WhenFillingOutAccessRightDependencies).
	//
	ServerEvents.Add("StandardSubsystems.AccessManagement\WhenFillingOutAccessRightDependencies");
	
	// Fills the content of access kinds used when metadata objects rights are restricted.
	// If the content of access kinds is not filled, "Access rights" report will show incorrect information.
	//
	// Only the access types clearly used
	// in access restriction templates must be filled, while
	// the access types used in access values sets may be
	// received from the current data register AccessValueSets.
	//
	//  To prepare the procedure content
	// automatically, the developer tools for
	// subsystem Access Management shall be used.
	//
	// Parameters:
	//  Definition     - String, multistring of the format <Table>.<Right>.<AccessKind>[.Object table].
	//                 For example, Document.SupplierInvoice.Reading.Company
	//                           Document.SupplierInvoice.Reading.Counterparties
	//                           Document.SupplierInvoice.Change.Company
	//                           Document.SupplierInvoice.Change.Counterparties
	//                           Document.Emails.Reading.Object.Document.Emails
	//                           Document.Emails.Change.Object.Document.Emails
	//                           Document.Files.Reading.Object.Catalog.FileFolders
	//                           Document.Files.Reading.Object.Document.Email
	//                           Document.Files.Change.Object.Catalog.FileFolders
	//                           Document.Files.Change.Object.Document.EmailMessage
	//                 Access kind Object is predefined as literal. This access kind is
	//                 used in the access limitations templates as "ref" to another
	//                 object according to which the current table object is restricted.
	//                 When access kind "Object" is set, it is
	//                 also required to set the types of tables used for this access kind.i.e. list the
	//                 types corresponding to the field used in the
	//                 template of access restriction together with access kind "Object". When listing the types by access
	//                 kind "Object", only those field types shall be listed that
	//                 field InformationRegisters has.AccessValueSets.Object, the rest of the types are extra.
	//
	// Syntax:
	// Procedure WhenFillingInRestrictionKindsForMetadataObjectsRights(Description) Export
	//
	// (same as AccessManagementOverridable.WhenFillingInRestrictionKindsForMetadataObjectsRights).
	//
	ServerEvents.Add("StandardSubsystems.AccessManagement\OnFillingKindsOfRestrictionsRightsOfMetadataObjects");
	
	// Fills kinds of access used by access rights restriction.
	// Access types Users and ExternalUsers are complete.
	// They can be deleted if they are not used for access rights restriction.
	//
	// Parameters:
	//  AccessKinds - ValuesTable with fields:
	//  - Name                    - String - a name used in
	//                             the description of delivered access groups profiles and ODD texts.
	//  - Presentation          - String - introduces an access type in profiles and access groups.
	//  - ValuesType            - Type - Type of access values reference.       For example, Type("CatalogRef.ProductsAndServices").
	//  - ValueGroupType       - Type - Reference type of access values groups. For
	//                                   example, Type("CatalogRef.ProductsAndServicesAccessGroups").
	//  - SeveralGroupsOfValues - Boolean - True shows that for access value
	//                             (ProductsAndServices) several value groups can be selected (Products and services access group).
	//
	// Syntax:
	// Procedure WhenFillingAccessKinds(AccessKinds) Export
	//
	// (Same as AccessManagementOverridable.WhenFillingInAccessKinds).
	//
	ServerEvents.Add("StandardSubsystems.AccessManagement\OnFillAccessKinds");
	
	// Fills in descriptions of substituted profiles
	// of the access groups and redefines the parameters of profiles and access groups update.
	//
	//  To prepare the procedure content
	// automatically, the developer tools for
	// subsystem Access Management shall be used.
	//
	// Parameters:
	//  ProfileDescriptions    - Array to which descriptions shall be added.
	//                        Empty structure shall be received by utilizing
	//                        function AccessManagement.AccessGroupsProfileNewDescription().
	//
	//  UpdateParameters - Structure with properties:
	//
	//                        UpdateChangedProfiles - Boolean (initial value is True).
	//
	//                        RestrictProfilesChanging - Boolean (initial value
	//                        is True) if you set to False, then
	//                        supplied profiles will be opened in ReadOnly mode.
	//
	//                        UpdateAccessGroups - Boolean (initial value is True).
	//
	//                        UpdateAccessGroupsWithObsoleteSettings - Boolean
	//                        (initial value is False) if set to True
	//                        then values setup made by the administrator by
	//                        access kind (deleted from the profile) will be deleted from access group.
	//
	// Syntax:
	// Procedure WhenFillingInAccessGroupsSuppliedProfiles (ProfilesDescriptions, UpdateParameters) Export
	//
	// (same as AccessManagementOverridable.FillInProvidedAccessGroupsProfiles).
	//
	ServerEvents.Add("StandardSubsystems.AccessManagement\WhenFillingOutProfileGroupsAccessProvided");
	
	// Fills in the use of access kinds depending on
	// functional options of the configuration, for example, UseProductsAndServicesAccessGroups.
	//
	// Parameters:
	//  AccessKind    - String. Name of access kind specified in procedure WhenFillingInAccessKinds.
	//  Use - Boolean (return value). Initial value True.
	// 
	// Syntax:
	// Procedure WhenFillingInAccessKindUse (AccessKindName, Use) Export
	//
	// (same as AccessManagementOverridable.WhenFillingInAccessKindUse).
	//
	ServerEvents.Add("StandardSubsystems.AccessManagement\OnFillingAccessTypeUse");
	
	// Allows to rewrite dependent sets of access values of other objects.
	//
	//  Called from procedures:
	// AccessManagementService.WriteAccessValuesSets(),
	// AccessManagementService.WriteDependentAccessValuesSets().
	//
	// Parameters:
	//  Ref       - CatalogRef, DocumentRef, ... - reference to the
	//                 object for which sets of access values are recorded.
	//
	//  RefsOnDependentObjects - Array of items of types CatalogRef, DocumentRef, ...
	//                 Contains references to objects with dependent sets of access values.
	//                 Initial value - empty array.
	//
	// Syntax:
	// Procedure OnChangeAccessValuesSets (Value Reference, ReferenceToDependentObjects) Export
	//
	// (same as AccessManagementOverridable.OnChangeAccessValuesSets).
	//
	ServerEvents.Add("StandardSubsystems.AccessManagement\OnChangeSetsOfAccessValues");
	
	// Gets called when updating the roles of infobase user.
	//
	// Parameters:
	//  InfobaseUserID - UUID,
	//  Denial - Boolean. When installing the parameter value to False inside
	//    event handler, update of roles for this user of infobase will be skipped.
	//
	// Syntax:
	// Procedure WhenUpdatingIBUserRoles (IBUserIdentifier, Denial) Export
	ServerEvents.Add("StandardSubsystems.AccessManagement\WhenUpdatingIBUserRoles");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Add events handlers.

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"AccessManagementService");
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\AfterInformationBaseUpdate"].Add(
		"AccessManagementService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddSessionSettingsSetupHandler"].Add(
		"AccessManagementService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
		"AccessManagementService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddExceptionsSearchLinks"].Add(
		"AccessManagementService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnDetectPredefinedNonUniqueness"].Add(
		"AccessManagementService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromMaster"].Add(
		"AccessManagementService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromSubordinate"].Add(
		"AccessManagementService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\AfterDataReceivingFromSubordinated"].Add(
		"AccessManagementService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\AfterDataReceivingFromMain"].Add(
		"AccessManagementService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObligatoryExchangePlanObjects"].Add(
		"AccessManagementService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGetPrimaryImagePlanExchangeObjects"].Add(
		"AccessManagementService");
	
	ServerHandlers["StandardSubsystems.Users\WhenDefiningEditingRolesProhibition"].Add(
		"AccessManagementService");
		
	ServerHandlers["StandardSubsystems.Users\OnDeterminingFormAction"].Add(
		"AccessManagementService");
	
	ServerHandlers["StandardSubsystems.Users\OnDeterminingIssueBeforeWriteTextOfFirstAdministrator"].Add(
		"AccessManagementService");
	
	ServerHandlers["StandardSubsystems.Users\OnAdministratorWrite"].Add(
		"AccessManagementService");
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		ServerHandlers["StandardSubsystems.ReportsVariants\OnConfiguringOptionsReports"].Add(
			"AccessManagementService");
	EndIf;
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers[
			"ServiceTechnology.DataExportImport\WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport"].Add(
				"AccessManagementService");
		ServerHandlers[
			"ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport"].Add(
				"AccessManagementService");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ServerHandlers["StandardSubsystems.CurrentWorks\AtFillingToDoList"].Add(
			"Catalogs.AccessGroupsProfiles");
	EndIf;
	
EndProcedure

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.AccessGroups.FullName(), "NotEditableInGroupProcessingAttributes");
	Objects.Insert(Metadata.Catalogs.AccessGroupsProfiles.FullName(), "NotEditableInGroupProcessingAttributes");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Main  procedures and functions.

// Adds a user to access group corresponding to supplied profile.
// Access group is determined by reference ID of supplied profile.
// If access group will not be found, it will be created.
// 
// Parameters:
//  User        - CatalogRef.Users,
//                        CatalogRef.ExternalUsers,
//                        CatalogRef.UsersGroups,
//                        CatalogRef.ExternalUsersGroups
//                        - participant to be included into access group.
// 
//  ProvidedProfile - String - String of supplied profile identifier.
//                      - CatalogRef.AccessGroupsProfiles - reference to
//                        the profile which was created according
//                        to the description in the module AccessManagementOverridable in the procedure FillInSuppliedAccessGroupsProfiles.
//                        Profiles with nonempty list of access kinds are not supported.
//                        Profile of access groups Administrator is not supported.
// 
Procedure EnableUserIntoAccessGroup(User, ProvidedProfile) Export
	
	ProcessUserLinkWithAccessGroup(User, ProvidedProfile, True);
	
EndProcedure

// Deletes the user from access group corresponding to supplied profile.
// Access group is determined by reference ID of supplied profile.
// If access group is not found, no actions will be completed.
// 
// Parameters:
//  User        - CatalogRef.Users,
//                        CatalogRef.ExternalUsers,
//                        CatalogRef.UsersGroups,
//                        CatalogRef.ExternalUsersGroups
//                        - participant to be excluded from access group.
// 
//  ProvidedProfile - String - String of supplied profile identifier.
//                      - CatalogRef.AccessGroupsProfiles - reference to
//                        the profile which was created according
//                        to the description in the module AccessManagementOverridable in the procedure FillInSuppliedAccessGroupsProfiles.
//                        Profiles with nonempty list of access kinds are not supported.
//                        Profile of access groups Administrator is not supported.
// 
Procedure ExcludeUserAccessGroups(User, ProvidedProfile) Export
	
	ProcessUserLinkWithAccessGroup(User, ProvidedProfile, False);
	
EndProcedure

// Find user in access group corresponding to supplied profile.
// Access group is determined by reference ID of supplied profile.
// If access group is not found, no actions will be completed.
// 
// Parameters:
//  User        - CatalogRef.Users,
//                        CatalogRef.ExternalUsers,
//                        CatalogRef.UsersGroups,
//                        CatalogRef.ExternalUsersGroups
//                        - participant to be found in access group.
// 
//  ProvidedProfile - String - String of supplied profile identifier.
//                      - CatalogRef.AccessGroupsProfiles - reference to
//                        the profile which was created according
//                        to the description in the module AccessManagementOverridable in the procedure FillInSuppliedAccessGroupsProfiles.
//                        Profiles with nonempty list of access kinds are not supported.
//                        Profile of access groups Administrator is not supported.
// 
Function FindUserInGroupAccess(User, ProvidedProfile) Export
	
	Return ProcessUserLinkWithAccessGroup(User, ProvidedProfile);
	
EndFunction

// Sets session parameters by current settings
// of constants and settings of users access groups.
//  Called OnSystemOperationStart.
//
Procedure SessionParametersSetting(ParameterName, SpecifiedParameters) Export
	
	SetPrivilegedMode(True);
	
	If Not Constants.LimitAccessOnRecordsLevel.Get() Then
		// For correct operation of preprocessor in access restrictions it
		// is required to initialize all session parameters that can be necessary for preprocessor operation.
		SessionParameters.AllAccessKindsExceptSpecial             = "";
		SessionParameters.AccessKindsWithDisabledUse      = "";
		SessionParameters.AccessKindsWithoutGroupsForAccessValue      = "";
		SessionParameters.AccessKindsWithOneGroupForAccessValue = "";
		
		SessionParameters.AccessValueTypesWithGroups
			= New FixedArray(New Array);
		
		SessionParameters.TablesWithSeparateRightSettings          = "";
		
		SessionParameters.TablesIDsWithSeparateRightSettings
			= New FixedArray(New Array);
		
		SessionParameters.RightSettingsOwnerTypes
			= New FixedArray(New Array);
		
		SpecifiedParameters.Add("AllAccessKindsExceptSpecial");
		SpecifiedParameters.Add("AccessKindsWithDisabledUse");
		SpecifiedParameters.Add("AccessKindsWithoutGroupsForAccessValue");
		SpecifiedParameters.Add("AccessKindsWithOneGroupForAccessValue");
		SpecifiedParameters.Add("AccessValueTypesWithGroups");
		SpecifiedParameters.Add("TablesWithSeparateRightSettings");
		SpecifiedParameters.Add("TablesIDsWithSeparateRightSettings");
		SpecifiedParameters.Add("RightSettingsOwnerTypes");
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.Text =
	"SELECT DISTINCT
	|	DefaultValues.AccessValuesType AS ValuesType,
	|	DefaultValues.WithoutSetup AS WithoutSetup
	|INTO DefaultValuesForUser
	|FROM
	|	InformationRegister.AccessGroupsDefaultValues AS DefaultValues
	|WHERE
	|	TRUE In
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				Catalog.AccessGroups.Users AS AccessGroupsUsers
	|					INNER JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|					ON
	|						AccessGroupsUsers.Ref = DefaultValues.AccessGroup
	|							AND AccessGroupsUsers.User = UsersGroupsContents.UsersGroup
	|							AND UsersGroupsContents.User = &CurrentUser)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	DefaultValues.ValuesType
	|FROM
	|	DefaultValuesForUser AS DefaultValues
	|
	|GROUP BY
	|	DefaultValues.ValuesType
	|
	|HAVING
	|	MIN(DefaultValues.WithoutSetup) = TRUE";
	
	ValuesTypesWithoutSetup = Query.Execute().Unload().UnloadColumn("ValuesType");
	
	// Setting parameters AllAccessKindsExceptSpecial, AccessKindsWithDisabledUse.
	AllAccessKindsExceptSpecial        = New Array;
	AccessKindsWithDisabledUse = New Array;
	
	Parameters = AccessManagementServiceReUse.Parameters();
	
	For Each AccessTypeProperties IN Parameters.AccessKindsProperties.Array Do
		AllAccessKindsExceptSpecial.Add(AccessTypeProperties.Name);
		
		If Not AccessKindIsUsed(AccessTypeProperties.Ref)
		 OR ValuesTypesWithoutSetup.Find(AccessTypeProperties.Ref) <> Undefined Then
			
			AccessKindsWithDisabledUse.Add(AccessTypeProperties.Name);
		EndIf;
	EndDo;
	
	SessionParameters.AllAccessKindsExceptSpecial = AllAccessKindsCombinations(AllAccessKindsExceptSpecial);
	
	SpecifiedParameters.Add("AllAccessKindsExceptSpecial");
	
	AllAccessKindsExceptSpecialDisabled = (AllAccessKindsExceptSpecial.Count()
		= AccessKindsWithDisabledUse.Count());
	
	If AllAccessKindsExceptSpecialDisabled Then
		SessionParameters.AccessKindsWithDisabledUse = "All";
	Else
		SessionParameters.AccessKindsWithDisabledUse
			= AllAccessKindsCombinations(AccessKindsWithDisabledUse);
	EndIf;
	
	SpecifiedParameters.Add("AccessKindsWithDisabledUse");
	
	// Setting parameters
	// AccessKindsWithoutGroupsForAccessValue, AccessKindsWithOneGroupForAccessValue, AccessValueTypesWithGroups.
	SessionParameters.AccessKindsWithoutGroupsForAccessValue =
		AllAccessKindsCombinations(Parameters.AccessKindsProperties.WithoutGroupsForAccessValues);
	SessionParameters.AccessKindsWithOneGroupForAccessValue =
		AllAccessKindsCombinations(Parameters.AccessKindsProperties.WithOneGroupForAccessValue);
	
	AccessValueTypesWithGroups = New Array;
	For Each KeyAndValue IN Parameters.AccessKindsProperties.AccessValueTypesWithGroups Do
		AccessValueTypesWithGroups.Add(KeyAndValue.Value);
	EndDo;
	SessionParameters.AccessValueTypesWithGroups = New FixedArray(AccessValueTypesWithGroups);
	
	SpecifiedParameters.Add("AccessKindsWithoutGroupsForAccessValue");
	SpecifiedParameters.Add("AccessKindsWithOneGroupForAccessValue");
	SpecifiedParameters.Add("AccessValueTypesWithGroups");
	
	// Setting parameters
	// TablesWithSeparateRightsSettings, TablesIdentifiersWithSeparateRightsSettings, RightsSettingsOwnerTypes.
	SeparateTables = Parameters.PossibleRightsForObjectRightsSettings.SeparateTables;
	TablesWithSeparateRightSettings = "";
	TablesIDsWithSeparateRightSettings = New Array;
	For Each KeyAndValue IN SeparateTables Do
		TablesWithSeparateRightSettings = TablesWithSeparateRightSettings
			+ "|" + KeyAndValue.Value + ";" + Chars.LF;
		TablesIDsWithSeparateRightSettings.Add(KeyAndValue.Key);
	EndDo;
	
	SessionParameters.TablesWithSeparateRightSettings = TablesWithSeparateRightSettings;
	
	SessionParameters.TablesIDsWithSeparateRightSettings =
		New FixedArray(TablesIDsWithSeparateRightSettings);
	
	SessionParameters.RightSettingsOwnerTypes = Parameters.PossibleRightsForObjectRightsSettings.OwnerTypes;
	
	SpecifiedParameters.Add("TablesWithSeparateRightSettings");
	SpecifiedParameters.Add("TablesIDsWithSeparateRightSettings");
	SpecifiedParameters.Add("RightSettingsOwnerTypes");
	
EndProcedure

// Overrides the behavior after receiving data in distributed IB.
Procedure AfterDataGetting(Sender, Cancel, FromSubordinated) Export
	
	AccessManagement.UpdateUsersRoles();
	
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure AddClientWorkParameters(Parameters) Export
	
	Parameters.Insert("SimplifiedInterfaceOfAccessRightsSettings",
		SimplifiedInterfaceOfAccessRightsSettings());
	
EndProcedure

// Updates user list of specified groups of performers.
// 
// It is required to call when content of
// users in groups of performers changes, for example, in groups of task performers.
//
// As parameter values the groups of performers are sent the content of which has changed.
//
// Parameters:
//  PerformersGroups - For example, CatalogRef.TaskPerformersGroups.
//                     - Array of the values specified above the types.
//                     - Undefined - without filter.
//
Procedure UpdatePerformersGroupsUsers(PerformersGroups = Undefined) Export
	
	If TypeOf(PerformersGroups) = Type("Array") AND PerformersGroups.Count() = 0 Then
		Return;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("PerformersGroups", PerformersGroups);
	
	InformationRegisters.AccessValuesGroups.UpdateUsersGroups(Parameters);
	
EndProcedure

// Checks the existence of access kind with specified name.
// Applied for automation of conditional subsystems embedding.
// 
Function AccessKindExists(AccessTypeName) Export
	
	Return AccessTypeProperties(AccessTypeName) <> Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into this subsystem.

// Overrides comment text while authorizing
// IB user created in the configurator with administrative rights.
//  Called from Users.AuthorizeCurrentUser().
//  Comment is written to the events log monitor.
// 
// Parameters:
//  Comment  - String - initial value is set.
//
Procedure AfterWriteAdministratorOnAuthorization(Comment) Export
	
	Comment = NStr("en='Detected that the"
"user of infobase with role ""Full rights"""
"was"
"created in the Configurator: -"
"user is not found in catalog"
"Users, - user is registered in the catalog Users, - user is added to access group Administrators."
""
"The infobase users should be created in the 1C:Enterprise mode.';ru='Обнаружено,"
"что пользователь информационной базы с"
"ролью"
"""Полные права"" был создан в"
"Конфигураторе: - пользователь не найден в"
"справочнике Пользователи, - пользователь зарегистрирован в справочнике Пользователи, - пользователь добавлен в группу доступа Администраторы."
""
"Пользователей информационной базы следует создавать в режиме 1С:Предприятия.'");
	
EndProcedure

// Overrides action during local IB
// administrator authorization or data field administrator.
//
Procedure OnAuthorizationAdministratorOnStart(Administrator) Export
	
	// Administrator will be automatically added to access group Administrators at authorization.
	If Not Users.InfobaseUserWithFullAccess(, Not CommonUseReUse.DataSeparationEnabled()) Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Insufficient rights to"
"add user ""%1"" to access group Administrators.';ru='Недостаточно"
"прав для добавления пользователя ""%1"" в группу доступа Администраторы.'"),
			String(Administrator));
	EndIf;
	
	Query = New Query;
	Query.SetParameter("User", Administrator);
	Query.Text =
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|WHERE
	|	AccessGroupsUsers.Ref = VALUE(Catalog.AccessGroups.Administrators)
	|	AND AccessGroupsUsers.User = &User";
	
	If Query.Execute().IsEmpty() Then
		Object = Catalogs.AccessGroups.Administrators.GetObject();
		Object.Users.Add().User = Administrator;
		InfobaseUpdate.WriteData(Object);
	EndIf;
	
EndProcedure

// Complements the array of checked roles by profile roles.
Procedure BeforeCheckingAvailabilityOfRoles(RoleNameArray) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	AdditionalRoles = New Map;
	RolesOccurrencesInProfileRoles = AccessManagementServiceReUse.RolesOccurrencesInProfileRoles();
	
	For Each RoleName IN RoleNameArray Do
		RoleOccurrencesInProfileRoles = RolesOccurrencesInProfileRoles.Get(RoleName);
		If RoleOccurrencesInProfileRoles = Undefined Then
			Continue;
		EndIf;
		For Each ProfileRole IN RoleOccurrencesInProfileRoles Do
			AdditionalRoles.Insert(ProfileRole, True);
		EndDo;
	EndDo;
	
	For Each KeyAndValue IN AdditionalRoles Do
		RoleNameArray.Add(KeyAndValue.Key);
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Updates the list of
// roles of infobase users by their belonging to access groups.
//  Users with "FullRights" role are ignored.
// 
// Parameters:
//  Users - CatalogRef.Users,
//                 CatalogRef.ExternalUsers
//                 Array of the values specified above the types.
//               - Undefined - update roles of all users.
//               - Type by which metadata object will be found:
//                 if Catalog will be found.ExternalUsers,
//                 then the roles of all external
//                 users will be updated, otherwise the roles of all users will be updated.
//
//  ServiceUserPassword - String - Password for authorization in
// service manager.
//  HasChanges - Boolean (return value) - value True is
//                  returned to this parameter if the record was created, otherwise it does not change.
//
Procedure UpdateUsersRoles(Val Users1 = Undefined,
                                    Val ServiceUserPassword = Undefined,
                                    HasChanges = False) Export
	
	If Not UsersService.BanEditOfRoles() Then
		// Roles are established by the mechanisms of subsystems Users and ExternalUsers.
		Return;
	EndIf;
	
	If Users1 = Undefined Then
		UserArray = Undefined;
		Users.FindAmbiguousInfobaseUsers(,);
		
	ElsIf TypeOf(Users1) = Type("Array") Then
		UserArray = Users1;
		If UserArray.Count() = 0 Then
			Return;
		EndIf;
		Users.FindAmbiguousInfobaseUsers(,);
		
	ElsIf TypeOf(Users1) = Type("Type") Then
		UserArray = Users1;
	Else
		UserArray = New Array;
		UserArray.Add(Users1);
		Users.FindAmbiguousInfobaseUsers(Users1);
	EndIf;
	
	SetPrivilegedMode(True);
	
	CurrentUserProperties = CurrentUserProperties(UserArray);
	
	// Parameters of check in cycle.
	AllRoles                       = UsersService.AllRoles().Map;
	InfobaseUserIDs = CurrentUserProperties.InfobaseUserIDs;
	NewUsersRoles        = CurrentUserProperties.UsersRoles;
	Administrators                = CurrentUserProperties.Administrators;
	
	SystemAdministratorRoleName = Users.SystemAdministratorRole().Name;
	AdministratorRoles = New Map;
	AdministratorRoles.Insert("FullRights", True);
	If Not CommonUseReUse.DataSeparationEnabled() Then
		If SystemAdministratorRoleName <> "FullRights" Then
			AdministratorRoles.Insert(SystemAdministratorRoleName, True);
		EndIf;
	EndIf;
	
	// Future result after cycle.
	NewIBAdministrators     = New Map;
	UpdatedIBUsers = New Map;
	
	For Each UserDetails IN InfobaseUserIDs Do
		
		CurrentUser         = UserDetails.User;
		InfobaseUserID = UserDetails.InfobaseUserID;
		NewIBAdministrator        = False;
		
		Cancel = False;
		Handlers = CommonUse.ServiceEventProcessor("StandardSubsystems.AccessManagement\WhenUpdatingIBUserRoles");
		For Each Handler IN Handlers Do
			Handler.Module.WhenUpdatingIBUserRoles(InfobaseUserID, Cancel);
		EndDo;
		If Cancel Then
			Continue;
		EndIf;
		
		// Search of IB user.
		If TypeOf(InfobaseUserID) = Type("UUID") Then
			IBUser = InfobaseUsers.FindByUUID(
				InfobaseUserID);
		Else
			IBUser = Undefined;
		EndIf;
		
		OldRoles = Undefined;
		
		If IBUser <> Undefined AND ValueIsFilled(IBUser.Name) Then
			
			NewRoles = NewUsersRoles.Copy(NewUsersRoles.FindRows(
				New Structure("User", CurrentUser)), "Role");
			
			NewRoles.Indexes.Add("Role");
			
			// Checking old roles.
			OldRoles        = New Map;
			RolesForAdding = New Map;
			RolesForDeletion   = New Map;
			
			If Administrators[CurrentUser] = Undefined Then
				For Each Role IN IBUser.Roles Do
					RoleName = Role.Name;
					OldRoles.Insert(RoleName, True);
					If NewRoles.Find(RoleName, "Role") = Undefined Then
						RolesForDeletion.Insert(RoleName, True);
					EndIf;
				EndDo;
			Else // Administrator.
				For Each Role IN IBUser.Roles Do
					RoleName = Role.Name;
					OldRoles.Insert(RoleName, True);
					If AdministratorRoles[RoleName] = Undefined Then
						RolesForDeletion.Insert(RoleName, True);
					EndIf;
				EndDo;
				
				For Each KeyAndValue IN AdministratorRoles Do
					
					If OldRoles[KeyAndValue.Key] = Undefined Then
						RolesForAdding.Insert(KeyAndValue.Key, True);
						
						If KeyAndValue.Key = SystemAdministratorRoleName Then
							NewIBAdministrator = True;
						EndIf;
					EndIf;
				EndDo;
			EndIf;
			
			// Checking new roles.
			For Each String IN NewRoles Do
				
				If OldRoles = Undefined
				 OR Administrators[CurrentUser] <> Undefined Then
					Continue;
				EndIf;
				
				If OldRoles[String.Role] = Undefined Then
					If AllRoles.Get(String.Role) <> Undefined Then
					
						RolesForAdding.Insert(String.Role, True);
						
						If String.Role = SystemAdministratorRoleName Then
							NewIBAdministrator = True;
						EndIf;
					Else
						// New roles not found in metadata.
						Profiles = UserProfilesWithRole(CurrentUser, String.Role);
						For Each Profile IN Profiles Do
							WriteLogEvent(
								NStr("en='Access management. Role has not been found in metadata';ru='Управление доступом.Роль не найдена в метаданных'",
								     CommonUseClientServer.MainLanguageCode()),
								EventLogLevel.Error,
								,
								,
								StringFunctionsClientServer.PlaceParametersIntoString(
									NStr("en='When updating the roles"
"of user"
"""%1"", role ""%2"" of"
"access groups profile ""%3"" was not found in metadata.';ru='При обновлении"
"ролей пользователя"
"""%1"" роль"
"""%2"" профиля групп доступа ""%3"" не найдена в метаданных.'"),
									String(CurrentUser),
									String.Role,
									String(Profile)),
								EventLogEntryTransactionMode.Transactional);
						EndDo;
					EndIf;
				EndIf;
			EndDo;
			
		EndIf;
		
		// End of current user processing.
		If OldRoles <> Undefined
		   AND (  RolesForAdding.Count() <> 0
			  OR RolesForDeletion.Count() <> 0) Then
			
			RolesChanging = New Structure;
			RolesChanging.Insert("UserRef", CurrentUser);
			RolesChanging.Insert("IBUser",     IBUser);
			RolesChanging.Insert("RolesForAdding",  RolesForAdding);
			RolesChanging.Insert("RolesForDeletion",    RolesForDeletion);
			
			If NewIBAdministrator Then
				NewIBAdministrators.Insert(CurrentUser, RolesChanging);
			Else
				UpdatedIBUsers.Insert(CurrentUser, RolesChanging);
			EndIf;
			
			HasChanges = True;
		EndIf;
	EndDo;
	
	// Adding new administrators.
	UpdateInfobaseUsersRoles(NewIBAdministrators, ServiceUserPassword);
	
	// Deleting old administrators and updating the rest of users.
	UpdateInfobaseUsersRoles(UpdatedIBUsers, ServiceUserPassword);
	
EndProcedure

// Checking access groups Administrators before recording.
Procedure CheckEnabledOfUserAccessAdministratorsGroupIB(GroupUsers, ErrorDescription) Export
	
	Users.FindAmbiguousInfobaseUsers(,);
	
	// Checking empty list of IB users in access group of Administrators.
	SetPrivilegedMode(True);
	FoundActiveAdministrator = False;
	
	For Each UserDetails IN GroupUsers Do
		
		If ValueIsFilled(UserDetails.User) Then
			
			IBUser = InfobaseUsers.FindByUUID(
				UserDetails.User.InfobaseUserID);
			
			If IBUser <> Undefined
			   AND Users.CanLogOnToApplication(IBUser) Then
				
				FoundActiveAdministrator = True;
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If Not FoundActiveAdministrator Then
		ErrorDescription =
			NStr("en='In access group"
"Administrators there must be at least"
"one user who is allowed to access the application.';ru='В группе"
"доступа Администраторы должен быть хотя"
"бы один пользователь, которому разрешен вход в программу.'");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable
//                                  function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	// Update handlers of undivided data.
	Handler = Handlers.Add();
	Handler.SharedData = True;
	Handler.HandlersManagement = True;
	Handler.Priority = 1;
	Handler.Version = "*";
	Handler.ExclusiveMode = True;
	Handler.Procedure = "AccessManagementService.FillSeparatedDataHandlers";
	
	// Update handlers of separated data.
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.ExclusiveMode = True;
	Handler.Procedure = "AccessManagementService.UpdateAuxiliaryDataOnConfigurationChanges";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.8";
	Handler.Procedure = "InformationRegisters.DeleteRightsByAccessValues.MoveDataToNewTable";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.8";
	Handler.Procedure = "AccessManagementService.ConvertRolesNamesToIdentifiers";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.8";
	Handler.Procedure = "InformationRegisters.AccessValuesGroups.UpdateUsersGroups";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.16";
	Handler.Procedure = "InformationRegisters.AccessGroupsTables.RefreshDataRegister";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.16";
	Handler.Procedure = "AccessManagement.UpdateUsersRoles";
	Handler.PerformModes = "Promptly";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.5";
	Handler.Procedure = "InformationRegisters.AccessValuesGroups.UpdateUsersGroups";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.4.15";
	Handler.Procedure = "Catalogs.AccessGroupsProfiles.FillInDataSuppliedIdentifiers";
	Handler.ExecuteUnderMandatory = True;
	Handler.Priority = 1;
	
	// Should be executed after handler FillInSuppliedDataIdentifiers.
	Handler = Handlers.Add();
	Handler.Version = "1.0.0.1";
	Handler.InitialFilling = True;
	Handler.Procedure = "Catalogs.AccessGroups.FillProfileFoldersAccessAdministrators";
	Handler.PerformModes = "Exclusive";
	Handler.ExecuteUnderMandatory = True;
	Handler.Priority = 1;
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "Catalogs.AccessGroupsProfiles.ConvertAccessKindsIdentifiers";
	Handler.PerformModes = "Exclusive";
	Handler.ExecuteUnderMandatory = True;
	Handler.Priority = 1;
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "InformationRegisters.AccessValuesGroups.UpdateUsersGroups";
	Handler.PerformModes = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "InformationRegisters.AccessGroupsValues.RefreshDataRegister";
	Handler.PerformModes = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "InformationRegisters.DeleteAccessValuesGroups.MoveDataToNewTable";
	Handler.PerformModes = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "InformationRegisters.ObjectRightsSettingsInheritance.RefreshDataRegister";
	Handler.PerformModes = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "InformationRegisters.ObjectRightsSettings.UpdateAuxiliaryRegisterData";
	Handler.PerformModes = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "AccessManagementService.EnableDataFillingForAccessRestriction";
	Handler.PerformModes = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.35";
	Handler.Procedure = "InformationRegisters.AccessValuesGroups.UpdateAccessEmptyValuesGroups";
	Handler.PerformModes = "Promptly";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.3.27";
	Handler.Procedure = "InformationRegisters.AccessGroupsValues.RefreshDataRegister";
	Handler.PerformModes = "Promptly";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.5.4";
	Handler.Procedure = "InformationRegisters.DeleteAccessValuesGroups.ClearRegister";
	Handler.PerformModes = "Promptly";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.5.7";
	Handler.Procedure = "AccessManagement.UpdateUsersRoles";
	Handler.PerformModes = "Promptly";
	
EndProcedure

// See comment of homonymous procedure of common module InformationBaseUpdateOverridable.
Procedure AfterInformationBaseUpdate(Val PreviousInfobaseVersion, Val CurrentIBVersion,
	Val ExecutedHandlers, PutSystemChangesDescription, ExclusiveMode) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	Run = SessionParameters.ClientParametersOnServer.Get("RunInfobaseUpdate");
	SetPrivilegedMode(False);
	
	If Run = True Then
		// Full update of roles is required for
		// manual start of update, as in debug mode profile roles are disabled while they are enabled in normal mode.
		AccessManagement.UpdateUsersRoles();
	EndIf;
	
EndProcedure

// Returns a match of session parameters and handlers parameters to initialize them.
//
Procedure OnAddSessionSettingsSetupHandler(Handlers) Export
	
	Handlers.Insert("AccessKinds*",
		"AccessManagementService.SessionParametersSetting");
	
	Handlers.Insert("AllAccessKindsExceptSpecial",
		"AccessManagementService.SessionParametersSetting");
	
	Handlers.Insert("TablesWithSeparateRightSettings",
		"AccessManagementService.SessionParametersSetting");
	
	Handlers.Insert("AccessValueTypesWithGroups",
		"AccessManagementService.SessionParametersSetting");
	
	Handlers.Insert("RightSettingsOwnerTypes",
		"AccessManagementService.SessionParametersSetting");
	
	Handlers.Insert("TablesIDsWithSeparateRightSettings",
		"AccessManagementService.SessionParametersSetting");
	
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystems(Parameters) Export
	
	AddClientWorkParameters(Parameters);
	
EndProcedure

// Fills the array with the list of metadata objects names that might include
// references to different metadata objects with these references ignored in the business-specific application logic
//
// Parameters:
//  Array       - array of strings for example "InformationRegister.ObjectsVersions".
//
Procedure OnAddExceptionsSearchLinks(Array) Export
	
	Array.Add(Metadata.InformationRegisters.AccessValuesGroups.FullName());
	Array.Add(Metadata.InformationRegisters.AccessRightsCorrelation.FullName());
	Array.Add(Metadata.InformationRegisters.AccessGroupsValues.FullName());
	Array.Add(Metadata.InformationRegisters.AccessGroupsDefaultValues.FullName());
	Array.Add(Metadata.InformationRegisters.AccessValuesSets.FullName());
	Array.Add(Metadata.InformationRegisters.RolesRights.FullName());
	Array.Add(Metadata.InformationRegisters.ObjectRightsSettingsInheritance.FullName());
	Array.Add(Metadata.InformationRegisters.ObjectRightsSettings.FullName());
	Array.Add(Metadata.InformationRegisters.AccessGroupsTables.FullName());
	
EndProcedure

// Called during the import of predefined items references in process of the important data import.
// Allows to execute actions to correct or register information
// about uniqueness of predefined items and also allows to deny continuing if it is not valid.
//
// Parameters:
//   Object          - CatalogObject, ChartOfCharacteristicTypesObject, ChartOfAccountsObject, ChartOfCalculationTypesObject -
//                     object of the predefined item after writing of which nonuniqueness is found.
//   WriteInJournal - Boolean - return value. If you specify False, then information about nonuniqueness
//                     will not be added to the event log in general message.
//                     You need to set False if non-uniqueness is fixed automatically.
//   Cancel           - Boolean - return value. If you specify True, general exception
//                     will be called that contains all the reasons of cancelation.
//   DenialDescription  - String - return value. If Denial is set to True, then the
//                     description will be added to the list of impossibility of continuing reasons.
//
Procedure OnDetectPredefinedNonUniqueness(Object, WriteInJournal, Cancel, DenialDescription) Export
	
	If TypeOf(Object) = Type("CatalogObject.AccessGroupsProfiles")
	   AND Object.PredefinedDataName = "Administrator" Then
		
		WriteInJournal = False;
		
		Query = New Query;
		Query.SetParameter("Ref", Object.Ref);
		Query.SetParameter("PredefinedDataName", "Administrator");
		Query.Text =
		"SELECT
		|	AccessGroupsProfiles.Ref AS Ref
		|FROM
		|	Catalog.AccessGroupsProfiles AS AccessGroupsProfiles
		|WHERE
		|	AccessGroupsProfiles.Ref <> &Ref
		|	AND AccessGroupsProfiles.PredefinedDataName = &PredefinedDataName";
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			CurrentObject = Selection.Ref.GetObject();
			CurrentObject.PredefinedDataName = "";
			CurrentObject.IDSuppliedData = "";
			InfobaseUpdate.WriteData(CurrentObject);
		EndDo;
		
	ElsIf TypeOf(Object) = Type("CatalogObject.AccessGroups")
	        AND Object.PredefinedDataName = "Administrators" Then
		
		WriteInJournal = False;
		
		Query = New Query;
		Query.SetParameter("PredefinedDataName", "Administrators");
		Query.Text =
		"SELECT DISTINCT
		|	AccessGroupsUsers.User
		|FROM
		|	Catalog.AccessGroups.Users AS AccessGroupsUsers
		|WHERE
		|	AccessGroupsUsers.Ref.PredefinedDataName = &PredefinedDataName";
		AllUsers = Query.Execute().Unload().UnloadColumn("User");
		
		Write = False;
		For Each User IN AllUsers Do
			If Object.Users.Find(User, "User") = Undefined Then
				Object.Users.Add().User = User;
				Write = True;
			EndIf;
		EndDo;
		
		If Write Then
			InfobaseUpdate.WriteData(Object);
		EndIf;
		
		Query.SetParameter("Ref", Object.Ref);
		Query.Text =
		"SELECT
		|	AccessGroups.Ref AS Ref
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	AccessGroups.Ref <> &Ref
		|	AND AccessGroups.PredefinedDataName = &PredefinedDataName";
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			CurrentObject = Selection.Ref.GetObject();
			CurrentObject.PredefinedDataName = "";
			InfobaseUpdate.WriteData(CurrentObject);
		EndDo;
	EndIf;
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of event handler WhenDataIsReceivedFromMain() in syntax helper.
// 
Procedure OnReceiveDataFromMaster(DataItem, ItemReceive, SendBack, Sender) Export
	
	If ItemReceive = DataItemReceive.Ignore Then
		// Standard processor is not overridden.
	Else
		// Administrators are appointed independently in all subordinate RIB nodes.
		If TypeOf(DataItem) = Type("CatalogObject.AccessGroups") Then
			Catalogs.AccessGroups.RestoreContentOfFoldersAccessAdministrators(DataItem, SendBack);
		EndIf;
	EndIf;
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of the event handler WhenDataIsReceivedFromSecondary() in the syntax helper.
// 
Procedure OnReceiveDataFromSubordinate(DataItem, ItemReceive, SendBack, Sender) Export
	
	If ItemReceive = DataItemReceive.Ignore Then
		// Standard processor is not overridden.
		
	ElsIf Not CommonUseReUse.DataSeparationEnabled() Then
		
		// Administrators are appointed independently in all subordinate RIB nodes.
		If TypeOf(DataItem) = Type("CatalogObject.AccessGroups") Then
			Catalogs.AccessGroups.RestoreContentOfFoldersAccessAdministrators(DataItem, SendBack);
		EndIf;
		
	ElsIf TypeOf(DataItem) = Type("ConstantValueManager.LimitAccessOnRecordsLevel")
	      OR TypeOf(DataItem) = Type("CatalogObject.AccessGroups")
	      OR TypeOf(DataItem) = Type("CatalogObject.AccessGroupsProfiles")
	      OR TypeOf(DataItem) = Type("InformationRegisterRecordSet.AccessValuesGroups")
	      OR TypeOf(DataItem) = Type("InformationRegisterRecordSet.AccessGroupsValues")
	      OR TypeOf(DataItem) = Type("InformationRegisterRecordSet.AccessValuesSets")
	      OR TypeOf(DataItem) = Type("InformationRegisterRecordSet.ObjectRightsSettings")
	      OR TypeOf(DataItem) = Type("InformationRegisterRecordSet.DeleteRightsByAccessValues")
	      OR TypeOf(DataItem) = Type("InformationRegisterRecordSet.AccessGroupsTables") Then
		
		// Data receipt from the autonomous work place is
		// skipped and for data match in nodes the current data is sent back to the autonomous work place.
		ItemReceive = DataItemReceive.Ignore;
		SendBack = True;
	EndIf;
	
EndProcedure

// Procedure-handler of the event after receiving data in the main node from the subordinate node of distributed IB.
// Called when exchange message reading is complete when all data from the exchange message
// are successfully read and written to IB.
// 
//  Parameters:
// Sender - ExchangePlanObject. Exchange plan node from which the data is received.
// Cancel - Boolean. Cancelation flag. If you set the True
// value for this parameter, the message will not be considered to be received. Data import transaction will be
// canceled if all data is imported in one transaction or last data import transaction
// will be canceled if data is imported batchwise.
//
Procedure AfterDataReceivingFromSubordinated(Sender, Cancel) Export
	
	AfterDataGetting(Sender, Cancel, True);
	
EndProcedure

// Procedure-handler of the event after receiving data in the subordinate node from the main node of distributed IB.
// Called when exchange message reading is complete when all data from the exchange message
// are successfully read and written to IB.
// 
//  Parameters:
// Sender - ExchangePlanObject. Exchange plan node from which the data is received.
// Cancel - Boolean. Cancelation flag. If you set the True
// value for this parameter, the message will not be considered to be received. Data import transaction will be
// canceled if all data is imported in one transaction or last data import transaction
// will be canceled if data is imported batchwise.
//
Procedure AfterDataReceivingFromMain(Sender, Cancel) Export
	
	AfterDataGetting(Sender, Cancel, False);
	
EndProcedure

// Used to receive metadata objects mandatory for an exchange plan.
// If the subsystem has metadata objects that have to be included
// in the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects that should be included into the exchange plan.
// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
// True - need to receive a list of RIB exchange plan;
// False - it is required to receive a list for an exchange plan NOT RIB.
//
Procedure OnGettingObligatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Constants.AccessLimitationParameters);
		Objects.Add(Metadata.InformationRegisters.RolesRights);
		Objects.Add(Metadata.InformationRegisters.AccessRightsCorrelation);
		
	EndIf;
	
EndProcedure

// Used to receive metadata objects that should be included in the
// content of the exchange plan and should NOT be included in the content of subscriptions to the events of changes registration for this plan.
// These metadata objects are used only at the time of creation
// of the initial image of the subnode and do not migrate during the exchange.
// If the subsystem has metadata objects that take part in creating an initial
// image of the subnode, the <Object> parameter needs to be added to these metadata objects.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects.
//
Procedure OnGetPrimaryImagePlanExchangeObjects(Objects) Export
	
	Objects.Add(Metadata.Constants.AccessLimitationParameters);
	Objects.Add(Metadata.InformationRegisters.AccessRightsCorrelation);
	Objects.Add(Metadata.InformationRegisters.RolesRights);
	
EndProcedure

// Handlers of subsystem events Users.

// Overrides the standard method of setting roles to IB users.
//
// Parameters:
//  Prohibition - Boolean. If you set True,
//           roles change is locked (for administrator as well).
//
Procedure WhenDefiningEditingRolesProhibition(Prohibition) Export
	
	// Roles are set automatically by data
	// of access groups through the connection: AccessGroupsUsers -> Profile -> ProfileRoles.
	Prohibition = True;
	
EndProcedure

// Overrides behavior of user form, external
// user form and external users group form.
//
// Parameters:
//  Ref - CatalogRef.Users,
//           CatalogRef.ExternalUsers,
//           CatalogRef.ExternalUsersGroups
//           ref to the user, external user or
//           external users group when the form is being created.
//
//  ActionsInForm - Structure (with properties of the Row type):
//           Roles                   = "", "View", "Editing"
//           ContactInformation= "", "View", "Editing" InfobaseUserProperties
//           = "", "ViewAll", "EditAll", "EditOwn" ItemProperties
//           = "", "View", "Editing"
//           
//           For external users group ContactInfo and InfobaseUserProperties do not exist.
//
Procedure OnDeterminingFormAction(Ref, ActionsInForm) Export
	
	ActionsInForm.Roles = "";
	
EndProcedure

// Overrides the question text before the first administrator write.
//  Called from BeforeWrite handler of user form.
//  Called if RolesEditingBan() is
// set and IB users quantity equals to one.
// 
Procedure OnDeterminingIssueBeforeWriteTextOfFirstAdministrator(QuestionText) Export
	
	QuestionText = NStr("en='First user is added to user"
"list of the application, that is why he or she will be automatically included into access group Administrators. "
"Continue?';ru='В список пользователей"
"программы добавляется первый пользователь, поэтому он будет автоматически включен в группу доступа Администраторы. "
"Продолжить?'")
	
EndProcedure

// Defines actions during the user writing
// when it is written together with IB user that has the FullRights role.
// 
// Parameters:
//  User - CatalogRef.Users (object change is prohibited).
//
Procedure OnAdministratorWrite(User) Export
	
	// Administrators are added automatically to access group Administrators.
	If PrivilegedMode() Then
		Object = Catalogs.AccessGroups.Administrators.GetObject();
		If Object.Users.Find(User, "User") = Undefined Then
			Object.Users.Add().User = User;
			InfobaseUpdate.WriteData(Object);
		EndIf;
	EndIf;
	
EndProcedure

// ReportsVariants subsystem events handlers.

// Contains the settings of reports variants placement in reports panel.
//   
// Parameters:
//   Settings - Collection - Used for the description of reports
//       settings and options, see description to ReportsVariants.ConfigurationReportVariantsSetupTree().
//   
// Definition:
//   IN this procedure it is required to specify how the
//   reports predefined variants will be registered in application and shown in the reports panel.
//   
// Auxiliary methods:
//   ReportSettings   = ReportsVariants.ReportDescription(Settings, Metadata.Reports.<ReportName>);
//   VariantSettings = ReportsVariants.VariantDesc(Settings, ReportSettings, "<VariantName>");
//   
//   These functions receive respectively report settings and report variant settings of the next structure:
//       * Enabled - Boolean -
//           If False then the report variant is not registered in the subsystem.
//           Used to delete technical and contextual report variants from all interfaces.
//           These report variants can still be opened applicationmatically as report
//           using opening parameters (see help on "Managed form extension for the VariantKeys" report).
//       * VisibleByDefault - Boolean -
//           If False then the report variant is hidden by default in the reports panel.
//           User can "enable" it in the reports
//           panel setting mode or open via the "All reports" form.
//       *Description - String - Additional information on the report variant.
//           It is displayed as a tooltip in the reports panel.
//           It should explain the report variant
//           content for the user and should not duplicate the report variant name.
//       * Placement - Map - Settings for report variant location in sections.
//           ** Key     - MetadataObject: Subsystem - Subsystem that hosts the report or the report variant.
//           ** Value - String - Optional. Settings for location in the subsystem.
//               ""        - Output report in its group in regular font.
//               "Important"  - Output report in its group in bold.
//               "SeeAlso" - Output report in the group "See also".
//       * FunctionalOptions - Array from String -
//            Names of the functional report variant options.
//   
// ForExample:
//   
//  (1) Add a report variant to the subsystem.
// Variant = ReportsVariants.VariantDescription(Settings, Metadata.Reports.ReportName, "VariantName1");
// Variant.Location.Insert(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
//   
//  (2) Disable report variant.
// Variant = ReportsVariants.VariantDescription(Settings, Metadata.Reports.ReportName, "VariantName1");
// Variant.Enabled = False;
//   
//  (3) Disable all report variants except for the required one.
// Report = ReportsVariants.ReportDescription(Settings, Metadata.Reports.ReportName);
// Report.Enabled = False;
// Variant = ReportsVariants.VariantDescription (Settings, Report, "VariantName");
// Variant.Enabled = True;
//   
//  (4) Completion result  4.1 and 4.2 will be the same:
//  (4.1)
// Report = ReportsVariants.ReportDescription(Settings, Metadata.Reports.ReportName);
// Variant = ReportsVariants.VariantDescription (Settings, Report, "VariantName1");
// Variant.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
// Variant = ReportsVariants.VariantDescription (Settings, Report, "VariantName2");
// Variant.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
// Variant = ReportsVariants.VariantDescription (Settings, Report, "VariantName3");
// Variant.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
//   
//  (4.2)
// Report = ReportsVariants.ReportDescription(Settings, Metadata.Reports.ReportName);
// Report.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
// ReportsVariants.VariantDesc(Settings, Report, "VariantName1");
// ReportsVariants.VariantDesc(Settings, Report, "VariantName2");
// ReportsVariants.VariantDesc(Settings, Report, "VariantName3");
// Report.Location.Insert(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
//   
// IMPORTANT:
//   Report serves as variants container.
//     By modifying the report settings you can change the settings of all its variants at the same time.
//     However if you receive report variant settings directly, they
//     will become the self-service ones, i.e. will not inherit settings changes from the report.See examples 3 and 4.
//   
//   Initial setting of reports locating by the subsystems
//     is read from metadata and it is not required to duplicate it in the code.
//   
//   Functional variants options unite with functional reports options by the following rules:
//     (ReportFunctionalOption1 OR ReportFunctionalOption2) And
//     (VariantFunctionalOption3 OR VariantFunctionalOption4).
//   Reports functional options are
//     not read from the metadata, they are applied when the user uses the subsystem.
//   You can add functional options via ReportDescription that will be connected by
//     the rules specified above. But remember that these functional options will be valid only
//     for predefined variants of this report.
//   For user report variants only functional report variants are valid.
//     - they are disabled only along with total report disabling.
//
Procedure OnConfiguringOptionsReports(Settings) Export
	ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
	ModuleReportsVariants.SetReportInManagerModule(Settings, Metadata.Reports.AccessRights);
EndProcedure

// ServiceTechnology library event handlers.

// Fills the array of types of undivided data for which
// the refs mapping during data import to another infobase is not necessary as correct refs
// mapping is guaranteed by using other mechanisms.
//
// Parameters:
//  Types - Array(MetadataObject)
//
Procedure WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport(Types) Export
	
	// IN the separated data ref are used only
	// to predefined items of the DeleteAccessKinds characteristics kinds chart.
	Types.Add(Metadata.ChartsOfCharacteristicTypes.DeleteAccessKinds);
	
EndProcedure

// Fills the array of types excluded from the import and export of data.
//
// Parameters:
//  Types - Array(Types).
//
Procedure WhenFillingTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.ChartsOfCharacteristicTypes.DeleteAccessKinds);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the subscriptions to events.

// UpdateAccessValueGroups subscription handler to the BeforeWrite event:
// - calls the writing method of access
//   value groups to the InformationRegister.AccessValueGroups for the required metadata objects;
// - calls the metod of hierarchy record of object
//   rights settings owners to InformationRegister.ObjectRightsSettingsInheritance for the required metadata objects.
//
Procedure RefreshAccessValuesGroups(Val Object, Cancel) Export
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
	Parameters = AccessManagementServiceReUse.Parameters();
	AccessValuesWithGroups = Parameters.AccessKindsProperties.AccessValuesWithGroups;
	PossibleRightsByTypes    = Parameters.PossibleRightsForObjectRightsSettings.ByTypes;
	
	If AccessValuesWithGroups.ByTypes.Get(TypeOf(Object)) <> Undefined Then
		InformationRegisters.AccessValuesGroups.RefreshAccessValuesGroups(Object);
	EndIf;
	
	If PossibleRightsByTypes.Get(TypeOf(Object)) <> Undefined Then
		InformationRegisters.ObjectRightsSettingsInheritance.RefreshDataRegister(Object);
	EndIf;
	
EndProcedure

// WriteAccessValueSets subscription handler to
// the OnWrite event calls method of object access values writing to InformationRegister.AccessValueSets.
//  It is possible to use
// the "AccessManagement" subsystem when the specified subscription does not exist if  access value sets are not applied.
//
Procedure WriteSetsOfAccessValueOnWrite(Val Object, Cancel) Export

	If Object.DataExchange.Load
	   AND Not Object.AdditionalProperties.Property("RecordSetsOfAccessValues") Then
		
		Return;
	EndIf;
	
	RecordSetsOfAccessValues(Object);
	
EndProcedure

// WriteDependentAccessValueSets subscription handler
// of the OnWrite event calls the rewriting of dependent access value sets in the AccessValueSets information register.
//
//  It is possible to use
// the "AccessManagement" subsystem when the specified subscription does not exist if the dependent access value sets are not applied.
//
Procedure WriteDependentSetsOfAccessValueOnWrite(Val Object, Cancel) Export
	
	If Object.DataExchange.Load
	   AND Not Object.AdditionalProperties.Property("RecordDependentSetsOfAccessValues") Then
		
		Return;
	EndIf;
	
	RecordDependentSetsOfAccessValues(Object);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of scheduled jobs.

// Handler of the DataFillingForAccessRestriction scheduled job.
Procedure FillingDataForAccessRestrictionTaskHandler() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	DataFillingForAccessLimit();
	
EndProcedure

// Successively fills in and updates data required for
// the AccessManagement subsystem work in the mode of access restriction at the records level.
// 
//  If access restriction mode is enabled on the records
// level, it fills in access value sets. Filled in partially during each start
// until all access value sets are not filled in.
//  When you disable the mode of access restriction on the
// records level, access value sets (filled in earlier) are removed while overwriting objects and not all at once.
//  Updates cache attributes not depending on the access restriction mode.
//  It disables scheduled job use after all updates and fillings are complete.
//
//  Information on the work state is written to the events log monitor.
//
//  It is possible to call it applicationmatically, for example, while updating the infobase.
// Also, for the update there
// is a form Catalog.AccessGroup.UpdateAccessRestrictionData using which you can execute an
// online update of access restriction data while updating the infobase.
//
Procedure DataFillingForAccessLimit(DataQuantity = 0, OnlyCacheAttributes = False, HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Parameters = AccessManagementServiceReUse.Parameters();
	AccessValuesWithGroups = Parameters.AccessKindsProperties.AccessValuesWithGroups;
	
	If AccessManagement.LimitAccessOnRecordsLevel() AND Not OnlyCacheAttributes Then
		
		// Fill in access value groups in the AccessValueGroups information register.
		For Each TableName IN AccessValuesWithGroups.TablesNames Do
			
			If DataQuantity < 10000 Then
				
				Query = New Query;
				Query.Text =
				"SELECT TOP 10000
				|	CurrentTable.Ref AS Ref
				|FROM
				|	&CurrentTable AS CurrentTable
				|		LEFT JOIN InformationRegister.AccessValuesGroups AS AccessValuesGroups
				|		ON CurrentTable.Ref = AccessValuesGroups.AccessValue
				|			AND (AccessValuesGroups.DataGroup = 0)
				|WHERE
				|	AccessValuesGroups.AccessValue IS NULL ";
				
				Query.Text = StrReplace(Query.Text, "&CurrentTable", TableName);
				Values = Query.Execute().Unload().UnloadColumn("Ref");
				
				InformationRegisters.AccessValuesGroups.RefreshAccessValuesGroups(Values, HasChanges);
				
				DataQuantity = DataQuantity + Values.Count();
			EndIf;
			
		EndDo;
		
		If DataQuantity < 10000
		   AND Not InformationRegisters.DeleteAccessValuesSets.MoveDataToNewTable() Then
			// Before you fill in access value
			// sets, access value sets are transferred from an old register.
			Return;
			
		ElsIf DataQuantity < 10000 Then
			
			// Fill in the AccessValuesSets information register.
			ObjectsTypes = AccessManagementServiceReUse.TypesOfObjectsInSubscriptionsToEvents(
				"RecordSetsOfAccessValues");
			
			For Each DescriptionOfType IN ObjectsTypes Do
				Type = DescriptionOfType.Key;
				
				If DataQuantity < 10000 AND Type <> Type("String") Then
				
					Query = New Query;
					Query.Text =
					"SELECT TOP 10000
					|	CurrentTable.Ref AS Ref
					|FROM
					|	&CurrentTable AS CurrentTable
					|		LEFT JOIN InformationRegister.AccessValuesSets AS InformationRegisterAccessValuesSets
					|		ON CurrentTable.Ref = InformationRegisterAccessValuesSets.Object
					|WHERE
					|	InformationRegisterAccessValuesSets.Object IS NULL ";
					Query.Text = StrReplace(Query.Text, "&CurrentTable", Metadata.FindByType(Type).FullName());
					Selection = Query.Execute().Select();
					DataQuantity = DataQuantity + Selection.Count();
					
					While Selection.Next() Do
						UpdateSetsOfAccessValues(Selection.Ref, HasChanges);
					EndDo;
				EndIf;
			EndDo;
		EndIf;
	Else
		InformationRegisters.DeleteAccessValuesSets.MoveDataToNewTable();
	EndIf;
	
	// Update cache attributes in the access values sets.
	If DataQuantity < 10000 Then
		
		AccessValuesTypes          = Parameters.AccessKindsProperties.ByValuesTypes;
		AccessValueTypesWithGroups = Parameters.AccessKindsProperties.AccessValueTypesWithGroups;
		
		TypesValuesTable = New ValueTable;
		TypesValuesTable.Columns.Add("ValuesType", Metadata.DefinedTypes.AccessValue.Type);
		For Each KeyAndValue IN AccessValuesTypes Do
			TypesValuesTable.Add().ValuesType = MetadataObjectEmptyRef(KeyAndValue.Key);
		EndDo;
		
		ValuesWithGroupsTypesTable = New ValueTable;
		ValuesWithGroupsTypesTable.Columns.Add("ValuesType", Metadata.DefinedTypes.AccessValue.Type);
		For Each KeyAndValue IN AccessValueTypesWithGroups Do
			ValuesWithGroupsTypesTable.Add().ValuesType = MetadataObjectEmptyRef(KeyAndValue.Key);
		EndDo;
		
		Query = New Query;
		Query.SetParameter("TypesValuesTable", TypesValuesTable);
		Query.SetParameter("ValuesWithGroupsTypesTable", ValuesWithGroupsTypesTable);
		Query.Text =
		"SELECT
		|	TypesTable.ValuesType
		|INTO TypesValuesTable
		|FROM
		|	&TypesValuesTable AS TypesTable
		|
		|INDEX BY
		|	TypesTable.ValuesType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TypesTable.ValuesType
		|INTO ValuesWithGroupsTypesTable
		|FROM
		|	&ValuesWithGroupsTypesTable AS TypesTable
		|
		|INDEX BY
		|	TypesTable.ValuesType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 10000
		|	AccessValuesSets.Object,
		|	AccessValuesSets.NumberOfSet,
		|	AccessValuesSets.AccessValue,
		|	AccessValuesSets.Adjustment,
		|	AccessValuesSets.Read,
		|	AccessValuesSets.Update
		|FROM
		|	InformationRegister.AccessValuesSets AS AccessValuesSets
		|WHERE
		|	CASE
		|			WHEN AccessValuesSets.StandardValue <> TRUE In
		|					(SELECT TOP 1
		|						TRUE
		|					FROM
		|						TypesValuesTable AS TypesValuesTable
		|					WHERE
		|						VALUETYPE(TypesValuesTable.ValuesType) = VALUETYPE(AccessValuesSets.AccessValue))
		|				THEN TRUE
		|			WHEN AccessValuesSets.StandardValue = TRUE
		|				THEN AccessValuesSets.ValueWithoutGroups = TRUE In
		|						(SELECT TOP 1
		|							TRUE
		|						FROM
		|							ValuesWithGroupsTypesTable AS ValuesWithGroupsTypesTable
		|						WHERE
		|							VALUETYPE(ValuesWithGroupsTypesTable.ValuesType) = VALUETYPE(AccessValuesSets.AccessValue))
		|			ELSE AccessValuesSets.ValueWithoutGroups = TRUE
		|		END";
		Selection = Query.Execute().Select();
		DataQuantity = DataQuantity + Selection.Count();
		
		While Selection.Next() Do
			RecordManager = InformationRegisters.AccessValuesSets.CreateRecordManager();
			FillPropertyValues(RecordManager, Selection);
			
			AccessValueType = TypeOf(Selection.AccessValue);
			
			If AccessValuesTypes.Get(AccessValueType) <> Undefined Then
				RecordManager.StandardValue = True;
				If AccessValueTypesWithGroups.Get(AccessValueType) = Undefined Then
					RecordManager.ValueWithoutGroups = True;
				EndIf;
			EndIf;
			
			RecordManager.Write();
			HasChanges = True;
		EndDo;
	EndIf;
	
	If DataQuantity < 10000 Then
		WriteLogEvent(
			NStr("en='Acces management. Filling data for access restriction';ru='Управление доступом.Заполнение данных для ограничения доступа'",
				 CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Information,
			,
			,
			NStr("en='Data filling for the access restriction has been completed.';ru='Завершено заполнение данных для ограничения доступа.'"),
			EventLogEntryTransactionMode.Transactional);
			
		SetDataFillingForAccessRestriction(False);
	Else
		WriteLogEvent(
			NStr("en='Acces management. Filling data for access restriction';ru='Управление доступом.Заполнение данных для ограничения доступа'",
				 CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Information,
			,
			,
			NStr("en='Data part for access restriction is written.';ru='Выполнена запись части данных для ограничения доступа.'"),
			EventLogEntryTransactionMode.Transactional);
	EndIf;
	
EndProcedure

// Sets a use of the scheduled job of filling access managing data.
//
// Parameters:
// Use - Boolean - True if the job should be included, otherwise, False.
//
Procedure SetDataFillingForAccessRestriction(Val Use) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		If CommonUse.SubsystemExists("StandardSubsystems.SaaS.AccessManagementSaaS") Then
			AccessControlModuleServiceSaaS = CommonUse.CommonModule("AccessManagementServiceSaaS");
			AccessControlModuleServiceSaaS.SetDataFillingForAccessRestriction(Use);
		EndIf;
	Else
		Task = ScheduledJobs.FindPredefined(
			Metadata.ScheduledJobs.DataFillingForAccessLimit);
		
		If Task.Use <> Use Then
			Task.Use = Use;
			Task.Write();
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for work with users and user groups.

// Updates user groupings after updating
// user group contents used to check the allowed users.
//
// Parameters:
//  ParticipantsOfChange - Array of types values:
//                       - CatalogRef.Users.
//                       - CatalogRef.ExternalUsers.
//                       Users that took part in groups content change.
//
//  ChangedGroups   - Array of types values:
//                       - CatalogRef.UsersGroups.
//                       - CatalogRef.ExternalUsersGroups.
//                       Group content of which was changed.
//
Procedure AfterUserGroupStavesUpdating(ParticipantsOfChange, ChangedGroups) Export
	
	Parameters = New Structure;
	Parameters.Insert("Users",        ParticipantsOfChange);
	Parameters.Insert("UsersGroups", ChangedGroups);
	
	InformationRegisters.AccessValuesGroups.UpdateUsersGroups(Parameters);
	
EndProcedure

// Updates link for a new users group (external users group).
//
// Parameters:
//  Ref     - CatalogRef.Users.
//             - CatalogRef.UsersGroups.
//             - CatalogRef.ExternalUsers.
//             - CatalogRef.ExternalUsersGroups.
//
//  IsNew   - Boolean if True, the object is added, otherwise, it is changed.
//
Procedure AfterUserOrGroupChangeAdding(Ref, IsNew) Export
	
	If IsNew Then
		If TypeOf(Ref) = Type("CatalogRef.UsersGroups")
		 OR TypeOf(Ref) = Type("CatalogRef.ExternalUsersGroups") Then
		
			Parameters = New Structure;
			Parameters.Insert("UsersGroups", Ref);
			InformationRegisters.AccessValuesGroups.UpdateUsersGroups(Parameters);
		EndIf;
	EndIf;
	
EndProcedure

// Updates external user groupings by the authorization object.
//
// Parameters:
//  ExternalUser     - CatalogRef.ExternalUsers.
//  OldAuthorizationObject - NULL - during adding an external user.
//                            For example, CatalogRef.Individuals.
//  NewAuthorizationObject  - For example, CatalogRef.Individuals.
//
Procedure AfterExternalUserAuthorizationObjectChange(ExternalUser,
                                                               OldAuthorizationObject,
                                                               NewAuthorizationObject) Export
	
	AuthorizationObjects = New Array;
	If OldAuthorizationObject <> NULL Then
		AuthorizationObjects.Add(OldAuthorizationObject);
	EndIf;
	AuthorizationObjects.Add(NewAuthorizationObject);
	
	Parameters = New Structure;
	Parameters.Insert("AuthorizationObjects", AuthorizationObjects);
	
	InformationRegisters.AccessValuesGroups.UpdateUsersGroups(Parameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for works with access kinds.

// Returns access kind usage.
// Parameters:
//  AccessKind   - String, access kind name.
//
// Returns:
//  Boolean.
//
Function AccessKindIsUsed(Val AccessKind) Export
	
	Used = False;
	
	AccessTypeProperties = AccessTypeProperties(AccessKind);
	If AccessTypeProperties = Undefined Then
		Return Used;
	EndIf;
	
	OMDValuesType = Metadata.FindByType(AccessTypeProperties.ValuesType);
	
	If CommonUse.MetadataObjectAvailableByFunctionalOptions(OMDValuesType) Then
		Used = True;
	EndIf;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AccessManagement\OnFillingAccessTypeUse");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnFillingAccessTypeUse(AccessTypeProperties.Name, Used);
	EndDo;
	
	AccessManagementOverridable.OnFillingAccessTypeUse(AccessTypeProperties.Name, Used);
	
	Return Used;
	
EndFunction

// Returns properties of access kind or all access kinds.
//
// Parameters:
//  AccessKind - Ref - empty reference of the main type;
//             - String - access kind name;
//             - Undefined - return the array of all access kinds properties.
//
// Returns:
//  Undefined - when properties are not found
//  for access kind, Structure - found access kind
//  properties, Structures array with
//  properties for the description of which see comments to
//  the AccessKindsProperties function in the AccessRestrictionParameters constant manager module.
//
Function AccessTypeProperties(Val AccessKind = Undefined) Export
	
	Properties = AccessManagementServiceReUse.Parameters().AccessKindsProperties;
	
	If AccessKind = Undefined Then
		Return Properties.Array;
	EndIf;
	
	AccessTypeProperties = Properties.ByNames.Get(AccessKind);
	
	If AccessTypeProperties = Undefined Then
		AccessTypeProperties = Properties.ByRefs.Get(AccessKind);
	EndIf;
	
	Return AccessTypeProperties;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for work with access value sets.

// Returns new sets for filling the tabular section.
Function GetAccessValueSetsOfTabularSection(Object) Export
	
	ObjectReference = Object.Ref;
	ValueTypeObject = TypeOf(Object);
	
	If Object.Metadata().TabularSections.Find("AccessValuesSets") = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Wrong parameters."
"""Access value sets"""
"tabular section is not found in object of the type ""%1"".';ru='Неверные параметры."
"У объекта"
"типа ""%1"" не найдена табличная часть ""Наборы значений доступа"".'"),
			ValueTypeObject);
	EndIf;
	
	Table = AccessManagement.TableAccessValueSets();
	
	If Not AccessManagement.LimitAccessOnRecordsLevel() Then
		Return Table;
	EndIf;
	
	AccessManagement.FillAccessValueSets(Object, Table);
	
	AccessManagement.AddAccessValueSets(
		Table, AccessManagement.TableAccessValueSets(), False, True);
	
	Return Table;
	
EndFunction

// Overwrites access value sets
// of the checked object to InformationRegister.AccessValueSets
// using the AccessManagement procedure.FillAccessValueSets().
//
//  Procedure is called from AccessManagementService.WriteAccessValueSets(),
// but it can
// be called from any place, for example, when the access restriction on the records level is enabled.
//
// Calls procedure of
// the AccessManagementOverridable applied handler.OnChangeAccessValueSets()
// that is used to rewrite the dependent value sets.
//
// Parameters:
//  Object       - CatalogObject, DocumentObject, ..., or CatalogRef, DocumentRef, ...
//                 IN case the call is made from client, you can pass only ref but the object is needed.
//                 If reference is received, object will be received by it.
//
Procedure RecordSetsOfAccessValues(Val Object, HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	// If the Object parameter is passed from client
	// to server, then ref is passed and object is required to be received.
	Object = ?(Object = Object.Ref, Object.GetObject(), Object);
	ObjectReference = Object.Ref;
	ValueTypeObject = TypeOf(Object);
	
	SetsRecord = AccessManagementServiceReUse.TypesOfObjectsInSubscriptionsToEvents(
		"RecordSetsOfAccessValues").Get(ValueTypeObject) <> Undefined;
	
	If Not SetsRecord Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Wrong parameters."
"Object type"
"""%1"" is not found in the"
"subscriptions to events ""Write access value sets"".';ru='Неверные параметры."
"Тип"
"объекта ""%1"" не найден"
"в подписках на события ""Записать наборы значений доступа"".'"),
				ValueTypeObject);
	EndIf;
	
	ObjectPossibleTypes = AccessManagementServiceReUse.TypesTableFields(
		"InformationRegister.AccessValuesSets.Dimension.Object");
	
	If ObjectPossibleTypes.Get(TypeOf(ObjectReference)) = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred while writing"
"access value sets: type ""%1"" is not"
"specified in the AccessValueSets information register in the Object dimension.';ru='Ошибка при записи"
"наборов значений доступа: в регистре"
"сведений НаборыЗначенийДоступа в измерении Объект не задан тип ""%1"".'"),
				ObjectReference.Metadata().FullName());
	EndIf;
	
	If AccessManagement.LimitAccessOnRecordsLevel() Then
		
		If Metadata.FindByType(ValueTypeObject).TabularSections.Find("AccessValuesSets") = Undefined Then
			
			Table = AccessManagement.TableAccessValueSets();
			AccessManagement.FillAccessValueSets(Object, Table);
			
			AccessManagement.AddAccessValueSets(
				Table, AccessManagement.TableAccessValueSets(), False, True);
		Else
			TabularSectionFilledIn = AccessManagementServiceReUse.TypesOfObjectsInSubscriptionsToEvents(
				"FillAccessValueSetsOfTabularSections").Get(ValueTypeObject) <> Undefined;
			
			If Not TabularSectionFilledIn Then
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='Wrong parameters."
"Object type"
"""%1"" is not found in the"
"subscriptions to events ""Fill in access value sets of tabular sections"".';ru='Неверные параметры."
"Тип"
"объекта ""%1"" не найден"
"в подписках на события ""Заполнить наборы значений доступа табличных частей"".'"),
						ValueTypeObject);
			EndIf;
			// Object is already written with the AccessValueSets tabular section.
			Table = Object.AccessValuesSets.Unload();
		EndIf;
		
		PrepareAccessToRecordsValuesSets(ObjectReference, Table, True);
		
		Data = New Structure;
		Data.Insert("ManagerRegister",   InformationRegisters.AccessValuesSets);
		Data.Insert("FixedSelection", New Structure("Object", ObjectReference));
		Data.Insert("NewRecords",        Table);
		
		BeginTransaction();
		Try
			UpdateRecordsets(Data, HasChanges);
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		If HasChanges = True Then
			OnChangeSetsOfAccessValues(ObjectReference);
		EndIf;
	Else
		Query = New Query(
		"SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	InformationRegister.AccessValuesSets AS AccessValuesSets
		|WHERE
		|	AccessValuesSets.Object = &ObjectReference");
		
		Query.SetParameter("ObjectReference", ObjectReference);
		
		If Not Query.Execute().IsEmpty() Then
			// Clear outdated set.
			// New set record will be complete
			// by the scheduled job after the restriction on the records level is enabled.
			RecordSet = InformationRegisters.AccessValuesSets.CreateRecordSet();
			RecordSet.Filter.Object.Set(ObjectReference);
			RecordSet.Write();
			HasChanges = True;
			
			// Clear outdated dependent sets.
			OnChangeSetsOfAccessValues(ObjectReference);
		EndIf;
	EndIf;
	
EndProcedure

// Overwrites access value sets of dependent objects.
//
//  Procedure is called from AccessManagementService.WriteDependableAccessValueSets()
// content of subscription types expands
// (without crossing) the WriteAccessValueSets content of subscription types with those types
// for which it is not required to write sets to the AccessValueSets information register.However,
// the sets are part of other sets, for example, sets of
// some of the files from the "Files" catalog can be part of some business processes "Job" created on the basis of files and sets of files are not required to be written to the register.
//
// Calls procedure of
// the AccessManagementOverridable applied handler.OnChangeAccessValueSets()
// that is used to
// rewrite dependent access value sets i.e. an organized recursion.
//
// Parameters:
//  Object       - CatalogObject, DocumentObject, ..., or CatalogRef, DocumentRef, ...
//                 IN case the call is made from client, you can pass only ref but the object is needed.
//                 If reference is received, object will be received by it.
//
Procedure RecordDependentSetsOfAccessValues(Val Object) Export
	
	SetPrivilegedMode(True);
	
	// If the Object parameter is passed from client
	// to server, then ref is passed and object is required to be received.
	Object = ?(Object = Object.Ref, Object.GetObject(), Object);
	ObjectReference = Object.Ref;
	ValueTypeObject = TypeOf(Object);
	
	ItIsLeadingObject = AccessManagementServiceReUse.TypesOfObjectsInSubscriptionsToEvents(
		"RecordDependentSetsOfAccessValues").Get(ValueTypeObject) <> Undefined;
	
	If Not ItIsLeadingObject Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Wrong parameters."
"Object type"
"""%1"" is not found in the"
"subscriptions to events ""Write dependent access value sets"".';ru='Неверные параметры."
"Тип"
"объекта ""%1"" не найден"
"в подписке на события ""Записать зависимые наборы значений доступа"".'"),
			ValueTypeObject);
	EndIf;
	
	OnChangeSetsOfAccessValues(ObjectReference);
	
EndProcedure

// Updates object access value sets if they have changed.
//  Sets are updated in tabular section (if
// used) and in the AccessValueSets information register.
//
// Parameters:
//  ObjectReference - CatalogRef, DocumentRef, ...
//
Procedure UpdateSetsOfAccessValues(ObjectReference, HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	// If the Object parameter is passed from client
	// to server, then ref is passed and object is required to be received.
	Object = ObjectReference.GetObject();
	ValueTypeObject = TypeOf(Object);
	
	SetsRecord = AccessManagementServiceReUse.TypesOfObjectsInSubscriptionsToEvents(
		"RecordSetsOfAccessValues").Get(ValueTypeObject) <> Undefined;
	
	If Not SetsRecord Then
		Raise(
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Wrong parameters."
"Object type"
"""%1"" is not found in the"
"subscription to events ""Write access value sets"".';ru='Неверные параметры."
"Тип"
"объекта ""%1"" не найден"
"в подписке на события ""Записать наборы значений доступа"".'"),
				ValueTypeObject));
	EndIf;
	
	If Metadata.InformationRegisters.AccessValuesSets.Dimensions.Object.Type.Types().Find(TypeOf(ObjectReference)) = Undefined Then
		Raise(
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred while writing"
"access value sets: type ""%1"" is not"
"specified in the AccessValueSets information register in the Object dimension';ru='Ошибка при записи"
"наборов значений доступа: в регистре"
"сведений НаборыЗначенийДоступа в измерении Объект не задан тип %1'"),
				ObjectReference.Metadata().FullName()));
	EndIf;
	
	If ObjectReference.Metadata().TabularSections.Find("AccessValuesSets") <> Undefined Then
		// Object update is required.
		Table = GetAccessValueSetsOfTabularSection(Object);
		
		If AccessValuesSetsOfTabularSectionChanged(ObjectReference, Table) Then
			PrepareAccessToRecordsValuesSets(Undefined, Table, False);
			
			Object.DataExchange.Load = True;
			Object.AdditionalProperties.Insert("RecordSetsOfAccessValues");
			Object.AdditionalProperties.Insert("RecordDependentSetsOfAccessValues");
			Object.AdditionalProperties.Insert("AccessValueSetsTablePartsFilled");
			Object.AccessValuesSets.Load(Table);
			Object.Write();
			HasChanges = True;
		EndIf;
	EndIf;
	
	// Object update is not required or object is already updated.
	RecordSetsOfAccessValues(Object, HasChanges);
	
EndProcedure

// Fills in helper data that speed up work of access restriction templates.
//  Executed before writing to the AccessValuesSets register.
//
// Parameters:
//  ObjectReference - CatalogRef.*, DocumentRef.*, ...
//  Table        - ValuesTable.
//
Procedure PrepareAccessToRecordsValuesSets(ObjectReference, Table, AddCacheAttributes = False) Export
	
	If AddCacheAttributes Then
		
		Table.Columns.Add("Object", Metadata.InformationRegisters.AccessValuesSets.Dimensions.Object.Type);
		Table.Columns.Add("StandardValue", New TypeDescription("Boolean"));
		Table.Columns.Add("ValueWithoutGroups", New TypeDescription("Boolean"));
		
		Parameters = AccessManagementServiceReUse.Parameters();
		
		AccessValueTypesWithGroups = Parameters.AccessKindsProperties.AccessValueTypesWithGroups;
		AccessValuesTypes          = Parameters.AccessKindsProperties.ByValuesTypes;
		SeparateTables             = Parameters.PossibleRightsForObjectRightsSettings.SeparateTables;
		RightSettingsOwnerTypes   = Parameters.PossibleRightsForObjectRightsSettings.ByRefsTypes;
	EndIf;
	
	// Normalization of resources Reading, Change.
	NumberOfSet = -1;
	For Each String IN Table Do
		
		If AddCacheAttributes Then
			// Setting of the Object dimension value.
			String.Object = ObjectReference;
			
			AccessValueType = TypeOf(String.AccessValue);
			
			If AccessValuesTypes.Get(AccessValueType) <> Undefined Then
				String.StandardValue = True;
				If AccessValueTypesWithGroups.Get(AccessValueType) = Undefined Then
					String.ValueWithoutGroups = True;
				EndIf;
			EndIf;
			
		EndIf;
		
		// Clear rights check boxes and secondary
		// data corresponding to them for all strings of each set except of the first string.
		If NumberOfSet = String.NumberOfSet Then
			String.Read    = False;
			String.Update = False;
		Else
			NumberOfSet = String.NumberOfSet;
		EndIf;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for actions during subsystem settings change.

// If it is necessary, it enables data filling
// for the access restrictions and updates some data at once.
//
// Called from the OnWrite handler of the LimitAccessOnRecordsLevel constant.
//
Procedure OnChangeLimitAccessOnRecordsLevel(RecordLevelSecurityEnabled) Export
	
	SetPrivilegedMode(True);
	
	If RecordLevelSecurityEnabled Then
		
		WriteLogEvent(
			NStr("en='Acces management. Filling data for access restriction';ru='Управление доступом.Заполнение данных для ограничения доступа'",
			     CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Information,
			,
			,
			NStr("en='Data filling to restrict the access has been started.';ru='Начато заполнение данных для ограничения доступа.'"),
			EventLogEntryTransactionMode.Transactional);
		
		SetDataFillingForAccessRestriction(True);
	EndIf;
	
	// Update session parameters.
	// It is required for administrator not to restart it.
	SpecifiedParameters = New Array;
	SessionParametersSetting("", SpecifiedParameters);
	
EndProcedure

// Returns the user interface kind for access setting.
Function SimplifiedInterfaceOfAccessRightsSettings() Export
	
	SimplifiedInterface = False;
	AccessManagementOverridable.OnDefineAccessSettingInterface(SimplifiedInterface);
	
	Return SimplifiedInterface = True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for user interfaces work.

// Returns metadata object name considering the specified properties in order:
//  - ExtendedObjectPresentation,
//  - ObjectPresentation,
//  - Synonym,
//  - Name.
//
// Parameters:
//  ObjectMetadata - MetadataObject.
//
// Returns:
//  Row.
//
Function ObjectNameFromMetadata(ObjectMetadata) Export
	
	If ValueIsFilled(ObjectMetadata.ExtendedObjectPresentation) Then
		NameObject = ObjectMetadata.ExtendedObjectPresentation;
	ElsIf ValueIsFilled(ObjectMetadata.ObjectPresentation) Then
		NameObject = ObjectMetadata.ObjectPresentation;
	ElsIf ValueIsFilled(ObjectMetadata.Synonym) Then
		NameObject = ObjectMetadata.Synonym;
	Else
		NameObject = ObjectMetadata.Name;
	EndIf;
	
	Return NameObject;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Servicing tables AccessKinds and AccessValues in edit forms.

// Fills in helper data required for
// form work and that do not depend on the object content or filled in for the new object.
//
// Form should contain attributes listed below.
// Attributes marked with the * character are filled in automatically but they should be created in form.
// Attributes marked with # character should be created in
// form if the CurrentAccessGroup attribute is created in the form (see below).
// Attributes marked with the @ character will be created automatically.
//
//  CurrentAccessGroup - optional
//                         attribute if it is not created in form, then it is not used.
//
//  AccessKinds - Table with fields:
//    #AccessGroup              - CatalogRef.AccessGroups,
//    AccessKind                  - DefinedType.AccessValue,
//    @Preset           - Boolean (only
//    for profile), AllAllowed                - Boolean,
//    *AccessKindPresentation    - String - presentation
//    of setting, *AllAllowedPresentation  - String - setting
//    presentation, @Used               - Boolean.
//
//  AccessValues - Table with fields:
//    #AccessGroup     - CatalogRef.AccessGroups,
//    *AccessKind        - DefinedType.AccessValue,
//    AccessValue    - DefinedType.AccessValue,
//    *StringNumberByKind - Number.
//
//  *UseExternalUsers     - Boolean - attribute will be created if it is not contained in form.
//  *AccessKindLabel                    - String - current access kind presentation in form.
//  @IsAccessGroupsProfile               - Boolean.
//  @CurrentAccessKind                    - DefinedType.AccessValue.
//  @SelectedValuesCurrentTypes        - ValueList.
//  @SelectedValuesCurrentType         - DefinedType.AccessValue.
//  @TablesStorageAttriuteName          - String.
//  @AccessKindUsers               - DefinedType.AccessValue.
//  @ExternalUsersAccessKind        - DefinedType.AccessValue.
//  
//  @AllAccessKinds - Table with fields:
//    @Ref        - DefinedType.AccessValue,
//    @Presentation - String,
//    @Use  - Boolean.
//
//  @AllPresentationsAllowed - Table with fields:
//    @Name           - String,
//    @Presentation - String.
//
//  @SelectedValuesAllTypes - Table with fields:
//    @AccessKind        - DefinedType.AccessValue,
//    @ValuesType       - DefinedType.AccessValue,
//    @TypePresentation - String,
//    @TableName        - String.
//
// Parameters:
//  Form      - ManagedForm that should
//               be set for the allowed values editing.
//
//  IsProfile - Boolean - specifies that access kinds
//               setting is possible including setting presentation contains 4 values, not 2.
//
//  TablesStorageAttributeName - String containing, for example, the
//               "Object" string that contains the AccessKinds and AccessValues tables (see below).
//               If an empty string is
//               specified, then it is assumed that all tables are stored in the form attributes.
//
Procedure OnCreateAtServerAllowedValuesEditingForms(Form, IsProfile = False, TablesStorageAttributeName = "Object") Export
	
	AddAuxiliaryDataAttributesToForm(Form, TablesStorageAttributeName);
	
	Form.TablesStorageAttributeName = TablesStorageAttributeName;
	Form.ThisIsAccessGroupsProfile = IsProfile;
	
	// Fill in access values types for all access kinds.
	For Each AccessTypeProperties IN AccessTypeProperties() Do
		For Each Type IN AccessTypeProperties.SelectedValuesTypes Do
			TypeArray = New Array;
			TypeArray.Add(Type);
			DescriptionOfType = New TypeDescription(TypeArray);
			
			TypeMetadata = Metadata.FindByType(Type);
			If Metadata.Enums.Find(TypeMetadata.Name) = TypeMetadata Then
				TypePresentation = TypeMetadata.Presentation();
			Else
				TypePresentation = ?(ValueIsFilled(TypeMetadata.ObjectPresentation),
					TypeMetadata.ObjectPresentation,
					TypeMetadata.Presentation());
			EndIf;
			
			NewRow = Form.AllSelectedValuesTypes.Add();
			NewRow.AccessKind        = AccessTypeProperties.Ref;
			NewRow.ValuesType       = DescriptionOfType.AdjustValue(Undefined);
			NewRow.TypePresentation = TypePresentation;
			NewRow.TableName        = TypeMetadata.FullName();
		EndDo;
	EndDo;
	
	Form.AccessTypeUsers           = Catalogs.Users.EmptyRef();
	Form.AccessKindExternalUsers    = Catalogs.ExternalUsers.EmptyRef();
	Form.UseExternalUsers = ExternalUsers.UseExternalUsers();
	
	FillTableAllAccessKindsInForm(Form);
	
	FillPresentationTableAllAllowedInForm(Form, IsProfile);
	
	GenerateAccessKindsTableInForm(Form);
	
	DeleteNonExistentLindsAndAccessValues(Form);
	AccessManagementServiceClientServer.FillAccessKindsPropertiesInForm(Form);
	
	RefreshUnusedAccessKindsDisplay(Form, True);
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(
		Form, "AccessValuesByTypeOfAccess");
	
EndProcedure

// During the repeated reading it fills in
// or updates the helper data required for form work that depend on the object content.
//
Procedure OnRereadingOnFormServerAllowedValuesEditing(Form, CurrentObject) Export
	
	DeleteNonExistentLindsAndAccessValues(Form, CurrentObject);
	DeleteNonExistentLindsAndAccessValues(Form);
	
	AccessManagementServiceClientServer.FillAccessKindsPropertiesInForm(Form);
	
	AccessManagementServiceClientServer.OnChangeCurrentAccessKind(Form);
	
EndProcedure

// Deletes extra access values before writing.
// Extra access values may appear if you replace or delete
// access kind for which access values are entered.
//
Procedure BeforeWriteOnServerAllowedValuesEditingForms(Form, CurrentObject) Export
	
	DeleteExtraAccessValues(Form, CurrentObject);
	DeleteExtraAccessValues(Form);
	
EndProcedure

// Updates access kinds properties.
Procedure AfterWriteOnServerAllowedValuesEditingForms(Form, CurrentObject, WriteParameters) Export
	
	AccessManagementServiceClientServer.FillAccessKindsPropertiesInForm(Form);
	
EndProcedure

// Hides or shows unused access kinds.
Procedure RefreshUnusedAccessKindsDisplay(Form, OnCreateAtServer = False) Export
	
	Items = Form.Items;
	
	If Not OnCreateAtServer Then
		Items.ShowUnusedAccessKinds.Check =
			Not Items.ShowUnusedAccessKinds.Check;
	EndIf;
	
	Filter = AccessManagementServiceClientServer.FilterInAllowedValuesEditFormTables(
		Form);
	
	If Not Items.ShowUnusedAccessKinds.Check Then
		Filter.Insert("Used", True);
	EndIf;
	
	Items.AccessKinds.RowFilter = New FixedStructure(Filter);
	
	Items.AccessKindsAccessKindPresentation.ChoiceList.Clear();
	
	For Each String IN Form.AllAccessKinds Do
		
		If Not Items.ShowUnusedAccessKinds.Check
		   AND Not String.Used Then
			
			Continue;
		EndIf;
		
		Items.AccessKindsAccessKindPresentation.ChoiceList.Add(String.Presentation);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Generic procedures and functions.

// Returns old object reference or new object reference.
//
// Parameters:
//  Object       - CatalogObject, ...
//  IsNew     - Boolean (Return value).
//
Function ObjectRef(Val Object, IsNew = Undefined) Export
	
	Ref = Object.Ref;
	IsNew = Not ValueIsFilled(Ref);
	
	If IsNew Then
		Ref = Object.GetNewObjectRef();
		
		If Not ValueIsFilled(Ref) Then
			
			Manager = CommonUse.ObjectManagerByRef(Object.Ref);
			Ref = Manager.GetRef();
			Object.SetNewObjectRef(Ref);
		EndIf;
	EndIf;
	
	Return Ref;
	
EndFunction

// Only for internal use.
Procedure SetCriteriaForQuery(Val Query, Val Values, Val ParameterNameValues, Val ParameterNameFilterConditionsFieldName) Export
	
	If Values = Undefined Then
		
	ElsIf TypeOf(Values) <> Type("Array")
	        AND TypeOf(Values) <> Type("FixedArray") Then
		
		Query.SetParameter(ParameterNameValues, Values);
		
	ElsIf Values.Count() = 1 Then
		Query.SetParameter(ParameterNameValues, Values[0]);
	Else
		Query.SetParameter(ParameterNameValues, Values);
	EndIf;
	
	For LineNumber = 1 To StrLineCount(ParameterNameFilterConditionsFieldName) Do
		CurrentRow = StrGetLine(ParameterNameFilterConditionsFieldName, LineNumber);
		If Not ValueIsFilled(CurrentRow) Then
			Continue;
		EndIf;
		IndexOfSeparator = Find(CurrentRow, ":");
		If IndexOfSeparator = 0 Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred while executing the AccessManagement procedure.SetFilterCriteriaInQuery()."
""
"In the ParameterNameFilterConditionsFieldName parameter separator (colon)"
"is not found in the next string of"
"""<Condition parameter name>:<Field name>"" ""%1"" format.';ru='Ошибка при выполнении процедуры УправлениеДоступом.УстановитьУсловиеОтбораВЗапросе().  В параметре ИмяПараметраУсловияОтбораИмяПоля не найден разделитель (двоеточие) в следующей строке формата ""<Имя параметра условия>:<Имя поля>"" ""%1"".'"),
				CurrentRow);
		EndIf;
		ParameterNameFilterConditions = Left(CurrentRow, IndexOfSeparator-1);
		FieldName = Mid(CurrentRow, IndexOfSeparator+1);
		If Values = Undefined Then
			FilterCondition = "True";
			
		ElsIf TypeOf(Values) <> Type("Array")
		        AND TypeOf(Values) <> Type("FixedArray") Then
			
			FilterCondition = FieldName + " = &" + ParameterNameValues;
			
		ElsIf Values.Count() = 1 Then
			FilterCondition = FieldName + " = &" + ParameterNameValues;
		Else
			FilterCondition = FieldName + " IN (&" + ParameterNameValues + ")";
		EndIf;
		Query.Text = StrReplace(Query.Text, ParameterNameFilterConditions, FilterCondition);
	EndDo;
	
EndProcedure

// Updates the records set
// in the database if the set records are different from the records in the database.
//
// Parameters:
//  Data - Structure - with properties:
//    * RecordSet           - RecordSet is empty or read with the specified filter or without filter.
//                              Register manager to create records set.
//
//    * NewRecords            - ValuesTable as a register.
//
//    * ComparisonFields          - String - contains fields list by values of
//                               which it is required to calculate set records differences. For example, "Dimension1,
//                               Dimension2, Resource1", and the DimensionDate attribute are not contained in the list.
//
//    * FilterField             - Undefined - the whole register
//                                              is written or filter is already specified in the records set.
//                               String       - field name by which it is required to set filter.
//
//    * FilterValue         - job that will be set as a filter by
//                               field if selection field is specified.
//
//    * RecordSetRead   - Boolean if True, then not specified records set
//                               already contains the read records, lock data of
//                               these records is set and transaction is opened.
//
//    * OnlyCheck         - Boolean - if True, then do not
//                               write but understand whether it is necessary
//                               to write and set the AreChanges property.
//
//    * AdditionalProperties - Undefined, Structure. If Structure, then
//                               all structure parameters will
//                               be inserted to the objects <Register*>RecordSet to the AdditionalProperties property.
//
//  HasChanges         - Boolean (return value) - if there
//                          is a record, True is set, otherwise, it is not changed.
//
//  ModifiedRecords      - Undefined - no actions,
//                          otherwise, it returns values table as a register with
//                          RowChangeKind field of the Number type (-1 record is removed, 1 record is added).
//
//  TransactionOpen     - Undefined    - do not open transaction.
//                          True          - transaction is already opened, it should not be opened.
//                          Other value - it is required
//                                            to open transaction and set TransactionOpened to True.
//
Procedure RefreshRecordset(Val Data, HasChanges = Undefined,
		ModifiedRecords = Undefined, TransactionOpen = Undefined) Export
	
	AllParameters = New Structure;
	AllParameters.Insert("RecordSet");
	AllParameters.Insert("NewRecords");
	AllParameters.Insert("ComparisonFields");
	AllParameters.Insert("FilterField");
	AllParameters.Insert("FilterValue");
	AllParameters.Insert("RecordSetRead", False);
	AllParameters.Insert("WithoutOverwriting", False);
	AllParameters.Insert("CheckOnly", False);
	AllParameters.Insert("AdditionalProperties");
	FillParameters(Data, AllParameters, "RecordSet, NewRecords");
	
	FullNameOfRegister = Metadata.FindByType(TypeOf(Data.RecordSet)).FullName();
	ManagerRegister = CommonUse.ObjectManagerByFullName(FullNameOfRegister);
	If Data.RecordSet = ManagerRegister Then
		Data.RecordSet = ManagerRegister.CreateRecordSet();
	EndIf;
	
	If ValueIsFilled(Data.FilterField) Then
		SetFilter(Data.RecordSet.Filter[Data.FilterField], Data.FilterValue);
	EndIf;
	
	If Not Data.RecordSetRead Then
		LockRecordSetArea(Data.RecordSet, FullNameOfRegister);
		Data.RecordSet.Read();
	EndIf;
	
	Data.ComparisonFields = ?(Data.ComparisonFields = Undefined,
		RecordSetFields(Data.RecordSet), Data.ComparisonFields);
	
	If Data.WithoutOverwriting Then
		RecordSet = ManagerRegister.CreateRecordSet();
		RecordKeyDescription = AccessManagementServiceReUse.RecordKeyDescription(FullNameOfRegister);
		FilterRecord = New Structure(RecordKeyDescription.FieldsRow);
		OtherDimensionsFields = New Array;
		For Each Field IN RecordKeyDescription.FieldsArray Do
			If Field <> Data.FilterField Then
				OtherDimensionsFields.Add(Field);
			EndIf;
		EndDo;
		ToDeleteRecords = New ValueTable;
		For Each Field IN OtherDimensionsFields Do
			ToDeleteRecords.Columns.Add(Field);
		EndDo;
		Data.NewRecords = Data.NewRecords.Copy();
	EndIf;
	
	IsCurrentChanges = False;
	If ModifiedRecords = Undefined Then
		If Data.RecordSet.Count() = Data.NewRecords.Count() OR Data.WithoutOverwriting Then
			Filter = New Structure(Data.ComparisonFields);
			Data.NewRecords.Indexes.Add(Data.ComparisonFields);
			For Each Record IN Data.RecordSet Do
				FillPropertyValues(Filter, Record);
				FoundStrings = Data.NewRecords.FindRows(Filter);
				If FoundStrings.Count() = 0 Then
					IsCurrentChanges = True;
					HasChanges = True;
					If Data.WithoutOverwriting Then
						FillPropertyValues(FilterRecord, Record);
						If Data.NewRecords.FindRows(FilterRecord).Count() = 0 Then
							FillPropertyValues(ToDeleteRecords.Add(), FilterRecord);
						EndIf;
					Else
						Break;
					EndIf;
				ElsIf Data.WithoutOverwriting Then
					Data.NewRecords.Delete(FoundStrings[0]);
				EndIf;
			EndDo;
			If Data.WithoutOverwriting AND Data.NewRecords.Count() > 0 Then
				IsCurrentChanges = True;
				HasChanges = True;
			EndIf;
		Else
			IsCurrentChanges = True;
			HasChanges = True;
		EndIf;
	Else
		If Data.RecordSet.Count() <> Data.NewRecords.Count() Then
			IsCurrentChanges = True;
			HasChanges = True;
		EndIf;
		If Data.RecordSet.Count() > Data.NewRecords.Count() Then
			ModifiedRecords = Data.RecordSet.Unload();
			SearchRecords   = Data.NewRecords;
			RowChangeKind = -1;
		Else
			ModifiedRecords = Data.NewRecords.Copy();
			SearchRecords   = Data.RecordSet.Unload();
			RowChangeKind = 1;
		EndIf;
		ModifiedRecords.Columns.Add("RowChangeKind", New TypeDescription("Number"));
		ModifiedRecords.FillValues(RowChangeKind, "RowChangeKind");
		RowChangeKind = ?(RowChangeKind = 1, -1, 1);
		Filter = New Structure(Data.ComparisonFields);
		
		For Each String IN SearchRecords Do
			FillPropertyValues(Filter, String);
			Rows = ModifiedRecords.FindRows(Filter);
			If Rows.Count() = 0 Then
				NewRow = ModifiedRecords.Add();
				FillPropertyValues(NewRow, Filter);
				NewRow.RowChangeKind = RowChangeKind;
				IsCurrentChanges = True;
				HasChanges = True;
			Else
				ModifiedRecords.Delete(Rows[0]);
			EndIf;
		EndDo;
	EndIf;
	
	If IsCurrentChanges Then
		If Data.CheckOnly Then
			Return;
		EndIf;
		If TransactionOpen <> Undefined // It is required to use an external transaction.
		   AND TransactionOpen <> True Then // External transaction is not opened yet.
			// Open an external transaction.
			BeginTransaction();
			TransactionOpen = True;
		EndIf;
		If Data.WithoutOverwriting Then
			SetAdditionalProperties(RecordSet, Data.AdditionalProperties);
			For Each String IN ToDeleteRecords Do
				If ValueIsFilled(Data.FilterField) Then
					SetFilter(RecordSet.Filter[Data.FilterField], Data.FilterValue);
				EndIf;
				For Each Field IN OtherDimensionsFields Do
					SetFilter(RecordSet.Filter[Field], String[Field]);
				EndDo;
				RecordSet.Write();
			EndDo;
			RecordSet.Add();
			For Each String IN Data.NewRecords Do
				If ValueIsFilled(Data.FilterField) Then
					SetFilter(RecordSet.Filter[Data.FilterField], Data.FilterValue);
				EndIf;
				For Each Field IN OtherDimensionsFields Do
					SetFilter(RecordSet.Filter[Field], String[Field]);
				EndDo;
				FillPropertyValues(RecordSet[0], String);
				RecordSet.Write();
			EndDo;
		Else
			SetAdditionalProperties(Data.RecordSet, Data.AdditionalProperties);
			Data.RecordSet.Load(Data.NewRecords);
			Data.RecordSet.Write();
		EndIf;
	EndIf;
	
EndProcedure

// Updates register strings with filter by several values
// for one or two register dimensions, it is
// checked whether there are changes if there are no changes, rewriting is not executed.
//
// Parameters:
//  Data - Structure - with properties:
//    * RegisterManager          - Register manager for creating the <Register*>RecordSet type.
//
//    * NewRecords               - ValuesTable as a register.
//
//    * ComparisonFields             - String - contains list of fields by the
//                                  values of which it is requierd to
//                                  calculate the difference between set records, for example, "Dimension1, Dimension2, Resource1", the ChangeDate attribute is not included in the list.
//
//    * FirstDimensionName       - Undefined - there is no filter by dimension.
//                                  String       - contains the name of the
//                                                 first dimension for which several values are specified.
//
//    * FirstDimensionValues  - Undefined - no selection by
//                                                 dimension, similarly, FirstDimensionName = Undefined.
//                                  AnyRef  - contains one register filter
//                                                 value for the updated records.
//                                  Array       - contains register filter values
//                                                 array for the updated records, empty array - so
//                                                 actions are not required.
//
//    * SecondDimensionName       - similarly FirstDimensionName.
//    * SecondDimensionValues  - similarly ValuesOfFirstDimensions.
//    * ThirdDimensionName      - similarly FirstDimensionName.
//    * ThirdDimensionValues - similarly ValuesOfFirstDimensions.
//
//    * OnlyCheck            - Boolean - if True, then do not
//                                  write but understand whether it is necessary
//                                  to write and set the AreChanges property.
//
//    * AdditionalProperties    - Undefined, Structure. If Structure, then
//                                  all structure parameters will
//                                  be inserted to the objects <Register*>RecordSet to the AdditionalProperties property.
//
//  HasChanges             - Boolean (return value) - if there
//                              is a record, True is set, otherwise, it is not changed.
//
Procedure UpdateRecordsets(Val Data, HasChanges) Export
	
	AllParameters = New Structure;
	AllParameters.Insert("ManagerRegister");
	AllParameters.Insert("NewRecords");
	AllParameters.Insert("ComparisonFields");
	AllParameters.Insert("NameOfFirstDimension");
	AllParameters.Insert("ValuesOfFirstDimensions");
	AllParameters.Insert("NameOfSecondDimension");
	AllParameters.Insert("ValueOfSecondMeasure");
	AllParameters.Insert("NameOfThirdDimensions");
	AllParameters.Insert("ValuesOfThirdDimensions");
	AllParameters.Insert("NewRecordsContainOnlyDifferences", False);
	AllParameters.Insert("FixedSelection");
	AllParameters.Insert("CheckOnly", False);
	AllParameters.Insert("AdditionalProperties");
	FillParameters(Data, AllParameters, "ManagerRegister, NewRecords");
	
	// Preliminary parameters processor.
	
	If Not ParametersGroupDimensionsProcessed(Data.NameOfFirstDimension, Data.ValuesOfFirstDimensions) Then
		HasChanges = True;
		Return;
	EndIf;
	If Not ParametersGroupDimensionsProcessed(Data.NameOfSecondDimension, Data.ValueOfSecondMeasure) Then
		HasChanges = True;
		Return;
	EndIf;
	If Not ParametersGroupDimensionsProcessed(Data.NameOfThirdDimensions, Data.ValuesOfThirdDimensions) Then
		HasChanges = True;
		Return;
	EndIf;
	
	OrderGroupsParametersMeasurement(Data);
	
	// Check and update data.
	Data.Insert("TransactionOpen",  ?(TransactionActive(), Undefined, False));
	Data.Insert("RecordSet",       Data.ManagerRegister.CreateRecordSet());
	Data.Insert("RegisterMetadata", Metadata.FindByType(TypeOf(Data.RecordSet)));
	Data.Insert("FullNameOfRegister",  Data.RegisterMetadata.FullName());
	
	If Data.NewRecordsContainOnlyDifferences Then
		Data.Insert("SetForSingleRecords", Data.ManagerRegister.CreateRecordSet());
	EndIf;
	
	If Data.FixedSelection <> Undefined Then
		For Each KeyAndValue IN Data.FixedSelection Do
			SetFilter(Data.RecordSet.Filter[KeyAndValue.Key], KeyAndValue.Value);
		EndDo;
	EndIf;
	
	Try
		If Data.NewRecordsContainOnlyDifferences Then
			
			If Data.NameOfFirstDimension = Undefined Then
				Raise
					NStr("en='Incorrect parameters in the UpdateRecordsets procedure.';ru='Некорректные параметры в процедуре ОбновитьНаборыЗаписей.'");
			Else
				If Data.NameOfSecondDimension = Undefined Then
					WriteMultipleSets = False;
				Else
					WriteMultipleSets = WriteMultipleSets(
						Data, New Structure, Data.NameOfFirstDimension, Data.ValuesOfFirstDimensions);
				EndIf;
				
				If WriteMultipleSets Then
					FieldList = Data.NameOfFirstDimension + ", " + Data.NameOfSecondDimension;
					Data.NewRecords.Indexes.Add(FieldList);
					
					CountByValuesOfFirstDimensions = Data.NumberOfValues;
					
					For Each FirstValue IN Data.ValuesOfFirstDimensions Do
						Filter = New Structure(Data.NameOfFirstDimension, FirstValue);
						SetFilter(Data.RecordSet.Filter[Data.NameOfFirstDimension], FirstValue);
						
						If Data.NameOfThirdDimensions = Undefined Then
							WriteMultipleSets = False;
						Else
							WriteMultipleSets = WriteMultipleSets(
								Data, Filter, Data.NameOfSecondDimension, Data.ValueOfSecondMeasure);
						EndIf;
						
						If WriteMultipleSets Then
							For Each SecondValue IN Data.ValueOfSecondMeasure Do
								Filter.Insert(Data.NameOfSecondDimension, SecondValue);
								SetFilter(Data.RecordSet.Filter[Data.NameOfSecondDimension], SecondValue);
								
								// Update by three dimensions.
								RefreshNewRecordSetOnVariousNewAccounts(Data, Filter, HasChanges);
							EndDo;
							Data.RecordSet.Filter[Data.NameOfSecondDimension].Use = False;
						Else
							// Update by two dimensions.
							Data.Insert("NumberOfValues", CountByValuesOfFirstDimensions);
							RefreshNewRecordSetOnVariousNewAccounts(Data, Filter, HasChanges);
						EndIf;
					EndDo;
				Else
					// Update by one dimension.
					ReadCountForReading(Data);
					RefreshNewRecordSetOnVariousNewAccounts(Data, New Structure, HasChanges);
				EndIf;
			EndIf;
		Else
			If Data.NameOfFirstDimension = Undefined Then
				// Update all records.
				
				CurrentData = New Structure("RecordSet, NewRecords, ComparisonFields, CheckOnly, AdditionalProperties");
				FillPropertyValues(CurrentData, Data);
				RefreshRecordset(CurrentData, HasChanges, , Data.TransactionOpen);
				
			ElsIf Data.NameOfSecondDimension = Undefined Then
				// Update by one dimension.
				Filter = New Structure(Data.NameOfFirstDimension);
				For Each Value IN Data.ValuesOfFirstDimensions Do
					
					SetFilter(Data.RecordSet.Filter[Data.NameOfFirstDimension], Value);
					Filter[Data.NameOfFirstDimension] = Value;
					
					If Data.ValuesOfFirstDimensions.Count() <> 1 Then
						NewSetRecords = Data.NewRecords;
					Else
						NewSetRecords = Data.NewRecords.Copy(Filter);
					EndIf;
					
					CurrentData = New Structure("RecordSet, ComparisonFields, CheckOnly, AdditionalProperties");
					FillPropertyValues(CurrentData, Data);
					CurrentData.Insert("NewRecords", NewSetRecords);
					
					RefreshRecordset(CurrentData, HasChanges, , Data.TransactionOpen);
				EndDo;
				
			ElsIf Data.NameOfThirdDimensions = Undefined Then
				// Update by two dimensions.
				FieldList = Data.NameOfFirstDimension + ", " + Data.NameOfSecondDimension;
				Data.NewRecords.Indexes.Add(FieldList);
				Filter = New Structure(FieldList);
				
				For Each FirstValue IN Data.ValuesOfFirstDimensions Do
					SetFilter(Data.RecordSet.Filter[Data.NameOfFirstDimension], FirstValue);
					Filter[Data.NameOfFirstDimension] = FirstValue;
					
					RefreshNewRecordSetForAllNewRecords(
						Data,
						Filter,
						FieldList,
						Data.NameOfSecondDimension,
						Data.ValueOfSecondMeasure,
						HasChanges);
				EndDo;
			Else
				// Update by three dimensions.
				FieldList = Data.NameOfFirstDimension + ", " + Data.NameOfSecondDimension + ", " + Data.NameOfThirdDimensions;
				Data.NewRecords.Indexes.Add(FieldList);
				Filter = New Structure(FieldList);
				
				For Each FirstValue IN Data.ValuesOfFirstDimensions Do
					SetFilter(Data.RecordSet.Filter[Data.NameOfFirstDimension], FirstValue);
					Filter[Data.NameOfFirstDimension] = FirstValue;
					
					For Each SecondValue IN Data.ValueOfSecondMeasure Do
						SetFilter(Data.RecordSet.Filter[Data.NameOfSecondDimension], SecondValue);
						Filter[Data.NameOfSecondDimension] = SecondValue;
						
						RefreshNewRecordSetForAllNewRecords(
							Data,
							Filter,
							FieldList,
							Data.NameOfSecondDimension,
							Data.ValueOfSecondMeasure,
							HasChanges);
					EndDo;
				EndDo;
			EndIf;
		EndIf;
		
		If Data.TransactionOpen = True Then
			CommitTransaction();
		EndIf;
	Except
		If Data.TransactionOpen = True Then
			RollbackTransaction();
		EndIf;
		Raise;
	EndTry;
	
EndProcedure

// Updates information register by data in the StringsChanges values table.
//
// Parameters:
//  Data - Structure - with properties:
//
//  * RegisterManager       - Register manager for creating the <Register*>RecordSet type.
//
//  * ChangeRowsContent  - ValuesTable containing register
//                             fields and the RowChangeKind (Number) field:
//                                1 - it means that string
//                               should be added, -1 - this means that string should be deleted.
//
//  * FixedFilter     - Structure containing dimension name in
//                             the key and filter value in value. It can be specified
//                             when there are more than 3 dimensions and it is
//                             known that by dimensions over 3 there will be a single value. Dimensions
//                             specified in the fixed set are
//                             not used while generating record sets for the update execution.
//
//  * FilterDimensions        - String of enumeration changes separated
//                             by commas that should be used
//                             while generating record sets for update (not more than 3). Not
//                             specified changes will be converted to
//                             the fixed filter if all values match.
//
//  * OnlyCheck         - Boolean - if True, then do not
//                             write but understand whether it is necessary
//                             to write and set the AreChanges property.
//
//  * AdditionalProperties - Undefined, Structure. If Structure, then
//                             all structure parameters will
//                             be inserted to the objects <Register*>RecordSet to the AdditionalProperties property.
//
//  HasChanges         - Boolean (return value) - if there
//                          is a record, True is set, otherwise, it is not changed.
//
Procedure RefreshInformationRegister(Val Data, HasChanges = Undefined) Export
	
	If Data.ChangeRowsContent.Count() = 0 Then
		Return;
	EndIf;
	
	AllParameters = New Structure;
	AllParameters.Insert("ManagerRegister");
	AllParameters.Insert("ChangeRowsContent");
	AllParameters.Insert("FixedSelection", New Structure);
	AllParameters.Insert("DimensionsOfSelection");
	AllParameters.Insert("CheckOnly", False);
	AllParameters.Insert("AdditionalProperties");
	FillParameters(Data, AllParameters, "ManagerRegister, ChangeRowsContent");
	
	RegisterMetadata = Metadata.FindByType(TypeOf(Data.ManagerRegister.EmptyKey()));
	RecordKeyDescription = AccessManagementServiceReUse.RecordKeyDescription(RegisterMetadata.FullName());
	
	If Data.DimensionsOfSelection <> Undefined Then
		Data.DimensionsOfSelection = New Structure(Data.DimensionsOfSelection);
	EndIf;
	
	FilterDimentionArray   = New Array;
	FilterDimensionValues = New Structure;
	
	For Each Field IN RecordKeyDescription.FieldsArray Do
		If Not Data.FixedSelection.Property(Field) Then
			Values = ValuesTableColumns(Data.ChangeRowsContent, Field);
			
			If Data.DimensionsOfSelection = Undefined
			 OR Data.DimensionsOfSelection.Property(Field) Then
				
				FilterDimentionArray.Add(Field);
				FilterDimensionValues.Insert(Field, Values);
				
			ElsIf Values.Count() = 1 Then
				Data.FixedSelection.Insert(Field, Values[0]);
			EndIf;
		EndIf;
	EndDo;
	
	Data.Insert("NameOfFirstDimension", FilterDimentionArray[0]);
	Data.Insert("ValuesOfFirstDimensions", FilterDimensionValues[Data.NameOfFirstDimension]);
	
	If FilterDimentionArray.Count() > 1 Then
		Data.Insert("NameOfSecondDimension", FilterDimentionArray[1]);
		Data.Insert("ValueOfSecondMeasure", FilterDimensionValues[Data.NameOfSecondDimension]);
	Else
		Data.Insert("NameOfSecondDimension", Undefined);
		Data.Insert("ValueOfSecondMeasure", Undefined);
	EndIf;
	
	If FilterDimentionArray.Count() > 2 Then
		Data.Insert("NameOfThirdDimensions", FilterDimentionArray[2]);
		Data.Insert("ValuesOfThirdDimensions", FilterDimensionValues[Data.NameOfThirdDimensions]);
	Else
		Data.Insert("NameOfThirdDimensions", Undefined);
		Data.Insert("ValuesOfThirdDimensions", Undefined);
	EndIf;
	
	Data.Insert("ComparisonFields", RecordKeyDescription.FieldsRow);
	Data.Insert("NewRecordsContainOnlyDifferences", True);
	Data.Insert("NewRecords", Data.ChangeRowsContent);
	Data.Delete("ChangeRowsContent");
	Data.Delete("DimensionsOfSelection");
	
	UpdateRecordsets(Data, HasChanges);
	
EndProcedure

// Returns metadata object empty reference of the reference type.
//
// Parameters:
//  MetadataObjectDesc - MetadataObject,
//                            - Type according to which you can find metadata object,
//                            - String - Full metadata object name.
// Returns:
//  Refs.
//
Function MetadataObjectEmptyRef(MetadataObjectDesc) Export
	
	If TypeOf(MetadataObjectDesc) = Type("MetadataObject") Then
		MetadataObject = MetadataObjectDesc;
		
	ElsIf TypeOf(MetadataObjectDesc) = Type("Type") Then
		MetadataObject = Metadata.FindByType(MetadataObjectDesc);
	Else
		MetadataObject = Metadata.FindByFullName(MetadataObjectDesc);
	EndIf;
	
	If MetadataObject = Undefined Then
		Raise
			NStr("en='An error occurred"
"in the MetadataObjectEmptyRef function of the AccessManagementService general module."
""
"Wrong parameter MetadataObjectDescription.';ru='Ошибка"
"в функции ПустаяСсылкаОбъектаМетаданных общего модуля УправлениеДоступомСлужебный."
""
"Наверный параметр ОписаниеОбъектаМетаданных.'");
	EndIf;
	
	EmptyRef = Undefined;
	Try
		ObjectManager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
		EmptyRef = ObjectManager.EmptyRef();
	Except
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred"
"in the MetadataObjectEmptyRef function of the AccessManagementService general module."
""
"Unable to receive an empty ref for"
"the metadata object ""%1"".';ru='Ошибка в функции ПустаяСсылкаОбъектаМетаданных"
"общего модуля УправлениеДоступомСлужебный."
""
"Не удалось получить пустую ссылка для объекта метаданных"
"""%1"".'"),
			MetadataObject.FullName());
	EndTry;
	
	Return EmptyRef;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Creates selection query of differences between register strings in
// the specified data area (based on the filters in the FieldsAndSelection parameter).
//
// Parameters:
//  SelectNewQueryText - String.
//
//  FieldAndSelecting   - items array of the Structure type("FieldName", ParameterNameFilterConditions).
//
//  FullNameOfRegister
//               - String       - query of the old ones is generated automatically.
//                 Undefined - query of old ones is taken from the next parameter.
//
//  TextOfQuerySelectOld
//               - String       - query of old ones considering non standard filters.
//               - Undefined - when register full name is defined.
//
// Returns:
//  String - text query considering optimization for PostgreSQL DBMS.
//
Function TextOfQuerySelectionChanges(SelectNewQueryText,
                                    FieldAndSelecting,
                                    FullNameOfRegister            = Undefined,
                                    TemporaryTablesQueryText = Undefined,
                                    TextOfQuerySelectOld     = Undefined) Export
	
	// Prepare text of old data query.
	If FullNameOfRegister <> Undefined Then
		TextOfQuerySelectOld =
		"SELECT
		|	&SelectedField,
		|	&InsertFieldsRowChangeKind
		|FROM
		|	FullNameOfRegister AS OldData
		|WHERE
		|	&FilterConditions";
	EndIf;
	
	SelectedField = "";
	FilterConditions = "True";
	For Each FieldDetails IN FieldAndSelecting Do
		// Selected fields assembly.
		SelectedField = SelectedField + StrReplace(
			"
			|	OldData.Field,",
			"Field",
			KeyAndValue(FieldDetails).Key);
			
		// Filter conditions assembly.
		If ValueIsFilled(KeyAndValue(FieldDetails).Value) Then
			FilterConditions = FilterConditions + StrReplace(
				"
				|	AND &ParameterNameFilterConditions", "&ParameterNameFilterConditions",
				KeyAndValue(FieldDetails).Value);
		EndIf;
	EndDo;
	
	TextOfQuerySelectOld =
		StrReplace(TextOfQuerySelectOld, "&SelectedField,",  SelectedField);
	
	TextOfQuerySelectOld =
		StrReplace(TextOfQuerySelectOld, "&FilterConditions",    FilterConditions);
	
	TextOfQuerySelectOld =
		StrReplace(TextOfQuerySelectOld, "FullNameOfRegister", FullNameOfRegister);
	
	If Find(SelectNewQueryText, "&InsertFieldsRowChangeKind") = 0 Then
		Raise
			NStr("en='An error occurred in"
"the OldSelectionQueryText parameter value of the ChangesSelectionQueryText procedure of the AccessManagementService module."
""
"String is not found in the query text ""&InsertFieldsRowChangeKind"".';ru='Ошибка в"
"значении параметра ТекстЗапросаВыбораСтарых процедуры ТекстЗапросаВыбораИзменений модуля УправлениеДоступомСлужебный."
""
"В тексте запроса не найдена строка ""&ПодстановкаПоляВидИзмененияСтроки"".'");
	EndIf;
	
	TextOfQuerySelectOld = StrReplace(
		TextOfQuerySelectOld, "&InsertFieldsRowChangeKind", "-1 AS RowDimensionKind");
	
	If Find(SelectNewQueryText, "&InsertFieldsRowChangeKind") = 0 Then
		Raise
			NStr("en='An error occurred in"
"the NewSelectionQueryText parameter value of the ChangesSelectionQueryText procedure of the AccessManagementService module."
""
"String is not found in the query text ""&InsertFieldsRowChangeKind"".';ru='Ошибка в"
"значении параметра ТекстЗапросаВыбораНовых процедуры ТекстЗапросаВыбораИзменений модуля УправлениеДоступомСлужебный."
""
"В тексте запроса не найдена строка ""&ПодстановкаПоляВидИзмененияСтроки"".'");
	EndIf;
	
	SelectNewQueryText = StrReplace(
		SelectNewQueryText,  "&InsertFieldsRowChangeKind", "1 AS RowChangeKind");
	
	// Prepare changes selection query text.
	QueryText =
	"SELECT
	|	&SelectedField,
	|	SUM(AllRows.RowChangeKind) AS RowChangeKind
	|FROM
	|	(SelectNewQueryText
	|	
	|	UNION ALL
	|	
	|	TextOfQuerySelectOld) AS AllRows
	|	
	|GROUP BY
	|	&GroupFields
	|	
	|HAVING
	|	SUM(AllRows.RowChangeKind) <> 0";
	
	SelectedField = "";
	GroupFields = "";
	For Each FieldDetails IN FieldAndSelecting Do
		// Selected fields assembly.
		SelectedField = SelectedField + StrReplace(
			"
			|	AllRows.Field,",
			"Field",
			KeyAndValue(FieldDetails).Key);
		
		// Connection fields assembly.
		GroupFields = GroupFields + StrReplace(
			"
			|	AllRows.Field,",
			"Field",
			KeyAndValue(FieldDetails).Key);
	EndDo;
	GroupFields = Left(GroupFields, StrLen(GroupFields)-1);
	QueryText = StrReplace(QueryText, "&SelectedField,",  SelectedField);
	QueryText = StrReplace(QueryText, "&GroupFields", GroupFields);
	
	QueryText = StrReplace(
		QueryText, "SelectNewQueryText",  SelectNewQueryText);
	
	QueryText = StrReplace(
		QueryText, "TextOfQuerySelectOld", TextOfQuerySelectOld);
	
	If ValueIsFilled(TemporaryTablesQueryText) Then
		QueryText = TemporaryTablesQueryText +
		"
		|;
		|" + QueryText;
	EndIf;
	
	Return QueryText;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Returns temporary tables manager containing users
// temporary table of some additional groups of
// users, for example, group users that
// perform jobs that correspond to the addressing keys(ExecutiveRole+AddressingMainObject+AddressingAdditionalObject).
//
//  If you change the content of additional
// user groups, you need to
// call the UpdateExecutiveGroupsUsers procedure in the AccessManagement module to apply the changes to the subsystem internal data.
//
// Parameters:
//  TempTablesManager - TempTablesManager to which a table can be placed.:
//                            ExecutivesGroupsTable with fields:
//                              GroupPerformers - For
//                                                   example, CatalogRef.TaskPerformersGroups.
//                              User       - CatalogRef.Users,
//                                                   CatalogRef.ExternalUsers.
//
//  ParameterContent     - Undefined - parameter is not specified, return all data.
//                            String,
//                              when "ExecutivesGroups" is
//                              required to return only contents of the specified executive groups.
//                              "Executives"
//                               it is required to return
//                               only executives group contents to which the specified executives are included.
//
//  ParameterValue       - Undefined, when ParameterContent = Undefined,
//                          - For
//                            example, CatalogRef.JobsExecutivesGroups when ParameterContent = "ExecutivesGroups".
//                          - CatalogRef.Users,
//                            CatalogRef.ExternalUsers
//                            when ParameterContent = "Executives".
//                            Array of the types specified above.
//
//  NoneGroupsPerformers    - Boolean if False, TempTablesManager contains the temporary table, otherwise, not.
//
Procedure WithDefinitionOfGroupsOfPerformers(TempTablesManager, ParameterContent, ParameterValue, NoneGroupsPerformers) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = CommonUse.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.WithDefinitionOfGroupsOfPerformers(TempTablesManager, ParameterContent, ParameterValue);
		NoneGroupsPerformers = False;
	Else
		NoneGroupsPerformers = True;
	EndIf;
	
EndProcedure

// Creates / updates the record record of service user.
// 
// Parameters:
//  User - CatalogRef.Users/CatalogObject.Users
//  CreateServiceUser - Boolean - True - create
//   a new service user, False - update the existing one.
//  ServiceUserPassword - String - current user
//   password for access to service manager.
//
Procedure OnWriteServiceUser(Val User, Val CreateServiceUser, Val ServiceUserPassword) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		ModuleUsersServiceSaaS = CommonUse.CommonModule("UsersServiceSaaS");
		ModuleUsersServiceSaaS.RecordServiceUser(User, CreateServiceUser, ServiceUserPassword);
	EndIf;
	
EndProcedure

// Returns actions available to the current user with the specified service user.
//
// Parameters:
//  User - CatalogRef.Users - user
//   available actions with which are required to be received. If parameter is not
//   specified, available actions with the current user are checked.
//  ServiceUserPassword - String - current user password
//   for access the service.
//  
Procedure WhenUserActionService(AvailableActions, Val User = Undefined) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		ModuleUsersServiceSaaS = CommonUse.CommonModule("UsersServiceSaaS");
		AvailableActions = ModuleUsersServiceSaaS.GetActionsWithServiceUser(User);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// Fills the separated data handler which is dependent on the change in unseparated data.
//
// Parameters:
//   Handlers - ValueTable, Undefined - see NewUpdateHandlersTable
//    function description
//    of InfobaseUpdate common module.
//    For the direct call (not using the
//    IB version update mechanism) Undefined is passed.
// 
Procedure FillSeparatedDataHandlers(Parameters = Undefined) Export
	
	If Parameters <> Undefined AND HasChangesParametersAccessRestrictions() Then
		Handlers = Parameters.SeparatedHandlers;
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.Procedure = "AccessManagementService.UpdateAuxiliaryDataOnConfigurationChanges";
	EndIf;
	
EndProcedure

// Updates helper data that depend
// only on configuration.
// Writes the changes in these data
// by configuration versions (if there are changes)
// to use these changes while updating
// the rest of the helper data, for example, in the UpdateAuxiliaryDataByConfigurationChanges handler.
//
Procedure UpdateAccessLimitationParameters(HasChanges = Undefined, CheckOnly = False) Export
	
	Block = New DataLock;
	LockItem = Block.Add("Constant.AccessLimitationParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = Block.Add("InformationRegister.RolesRights");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = Block.Add("InformationRegister.AccessRightsCorrelation");
	LockItem.Mode = DataLockMode.Exclusive;
	
	If CheckOnly OR ExclusiveMode() Then
		SwitchOffSoleMode = False;
	Else
		SwitchOffSoleMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		InformationRegisters.RolesRights.RefreshDataRegister(
			HasChanges, CheckOnly);
		
		If Not (CheckOnly AND HasChanges) Then
			InformationRegisters.AccessRightsCorrelation.RefreshDataRegister(
				HasChanges, CheckOnly);
		EndIf;
		
		If Not (CheckOnly AND HasChanges) Then
			Constants["AccessLimitationParameters"].CreateValueManager(
				).UpdateAccessKindsPropertiesDescription(HasChanges, CheckOnly);
		EndIf;
		
		If Not (CheckOnly AND HasChanges) Then
			Catalogs.AccessGroupsProfiles.UpdateProvidedProfilesDescription(
				HasChanges, CheckOnly);
		EndIf;
		
		If Not (CheckOnly AND HasChanges) Then
			Catalogs.AccessGroupsProfiles.UpdatePredefinedProfilesContent(
				HasChanges, CheckOnly);
		EndIf;
		
		If Not (CheckOnly AND HasChanges) Then
			InformationRegisters.ObjectRightsSettings.UpdatePossibleRightsForObjectRightsSettings(
				HasChanges, CheckOnly);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		If SwitchOffSoleMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If SwitchOffSoleMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

// Clears helper data that depend
// only on configuration.
// Used as helper data
// clearing handler that dependent only on the configuration to
// call the check and update of the
// remaining helper data while updating IB, for example, in the UpdateAuxiliaryDataOnUpdatingIB handler.
//
Procedure ClearAccessLimitationParameters() Export
	
	Block = New DataLock;
	LockItem = Block.Add("Constant.AccessLimitationParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = Block.Add("InformationRegister.RolesRights");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = Block.Add("InformationRegister.AccessRightsCorrelation");
	LockItem.Mode = DataLockMode.Exclusive;
	
	If ExclusiveMode() Then
		SwitchOffSoleMode = False;
	Else
		SwitchOffSoleMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		// Clear role rights.
		RecordSet = InformationRegisters.RolesRights.CreateRecordSet();
		RecordSet.Write();
		
		// Clear rights dependencies.
		RecordSet = InformationRegisters.AccessRightsCorrelation.CreateRecordSet();
		RecordSet.Write();
		
		// Clear the remaining data composed by the metadata and their changes.
		Constants.AccessLimitationParameters.Set(New ValueStorage(Undefined));
		
		CommitTransaction();
	Except
		RollbackTransaction();
		If SwitchOffSoleMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If SwitchOffSoleMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

// Checks whether there were undivided data changes for a data area.
Function HasChangesParametersAccessRestrictions() Export
	
	SetPrivilegedMode(True);
	
	ParametersTested = New Array;
	ParametersTested.Add("ObjectsMetadataRightRoles");
	ParametersTested.Add("PossibleRightsForObjectRightsSettings");
	ParametersTested.Add("ProvidedAccessGroupsProfiles");
	ParametersTested.Add("AccessGroupsPredefinedProfiles");
	ParametersTested.Add("GroupsAndAccessValuesTypes");
	
	Parameters = AccessManagementServiceReUse.Parameters();
	
	For Each ValidatedParameter IN ParametersTested Do
		
		LastChanges = StandardSubsystemsServer.ApplicationPerformenceParameterChanging(
			Parameters, ValidatedParameter);
		
		If LastChanges = Undefined
		 OR LastChanges.Count() > 0 Then
			
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

// Updates helper data that partially depend on the configuration.
//
// Updated if there are configuration changes
// written to the access restrictions parameters while updating data base for the current configuration version.
//
Procedure UpdateAuxiliaryDataOnConfigurationChanges(Parameters = Undefined) Export
	
	If Parameters <> Undefined
	   AND Not Parameters.ExclusiveMode
	   AND HasChangesParametersAccessRestrictions() Then
		
		Parameters.ExclusiveMode = True;
		Return;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.AccessGroupsTables");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = Block.Add("InformationRegister.ObjectRightsSettings");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = Block.Add("Catalog.AccessGroupsProfiles");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = Block.Add("Catalog.AccessGroups");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		InformationRegisters.AccessGroupsTables.UpdateRegisterDataByConfigurationChanges();
		InformationRegisters.AccessValuesGroups.UpdateRegisterAuxiliaryDataByConfigurationChanges();
		InformationRegisters.ObjectRightsSettings.UpdateRegisterAuxiliaryDataByConfigurationChanges();
		Catalogs.AccessGroupsProfiles.UpdateProvidedProfilesByConfigurationChanges();
		Catalogs.AccessGroups.MarkToDeleteCheckedProfileAccessGroups();
		InformationRegisters.AccessValuesSets.UpdateRegisterAuxiliaryDataByConfigurationChanges();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Converts the DeleteRole attribute to the Role attribute in
// the Role tabular section of the Profiles catalog of the access groups.
//
Procedure ConvertRolesNamesToIdentifiers() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Roles.Ref AS Ref
	|FROM
	|	Catalog.AccessGroupsProfiles.Roles AS Roles
	|WHERE
	|	Not(Roles.Role <> VALUE(Catalog.MetadataObjectIDs.EmptyRef)
	|				AND Roles.DeleteRole = """")";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		IndexOf = Object.Roles.Count()-1;
		While IndexOf >= 0 Do
			String = Object.Roles[IndexOf];
			If ValueIsFilled(String.Role) Then
				String.DeleteRole = "";
			ElsIf ValueIsFilled(String.DeleteRole) Then
				RoleMetadata = Metadata.Roles.Find(String.DeleteRole);
				If RoleMetadata <> Undefined Then
					String.DeleteRole = "";
					String.Role = CommonUse.MetadataObjectID(
						RoleMetadata);
				Else
					Object.Roles.Delete(IndexOf);
				EndIf;
			Else
				Object.Roles.Delete(IndexOf);
			EndIf;
			IndexOf = IndexOf-1;
		EndDo;
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

// Updates settings and enables scheduled job.
Procedure EnableFillingDataForAccessRestriction() Export
	
	MetadataJob = Metadata.ScheduledJobs.DataFillingForAccessLimit;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		If CommonUse.SubsystemExists("StandardSubsystems.SaaS.AccessManagementSaaS") Then
			AccessControlModuleServiceSaaS = CommonUse.CommonModule("AccessManagementServiceSaaS");
			AccessControlModuleServiceSaaS.SetDataFillingForAccessRestriction(True);
		EndIf;
	Else
		Schedule = New JobSchedule;
		Schedule.WeeksPeriod = 1;
		Schedule.DaysRepeatPeriod = 1;
		Schedule.RepeatPeriodInDay = 300;
		Schedule.RepeatPause = 90;
		
		Task = ScheduledJobs.FindPredefined(MetadataJob);
		Task.Use = True;
		Task.Schedule = Schedule;
		
		Task.RestartIntervalOnFailure
			= MetadataJob.RestartIntervalOnFailure;
		
		Task.RestartCountOnFailure
			= MetadataJob.RestartCountOnFailure;
		
		Task.Write();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

Procedure OnChangeSetsOfAccessValues(Val ObjectReference)
	
	RefsOnDependentObjects = New Array;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AccessManagement\OnChangeSetsOfAccessValues");
	For Each Handler IN EventHandlers Do
		Handler.Module.OnChangeSetsOfAccessValues(ObjectReference, RefsOnDependentObjects);
	EndDo;
	
	AccessManagementOverridable.OnChangeSetsOfAccessValues(
		ObjectReference, RefsOnDependentObjects);
	
	For Each RefOnDependentObject IN RefsOnDependentObjects Do
		
		If RefOnDependentObject.Metadata().TabularSections.Find("AccessValuesSets") = Undefined Then
			// Object change is not required.
			RecordSetsOfAccessValues(RefOnDependentObject);
		Else
			// It is required to change object.
			Object = RefOnDependentObject.GetObject();
			Table = GetAccessValueSetsOfTabularSection(Object);
			If Not AccessValuesSetsOfTabularSectionChanged(RefOnDependentObject, Table) Then
				Continue;
			EndIf;
			PrepareAccessToRecordsValuesSets(Undefined, Table, False);
			Try
				LockDataForEdit(RefOnDependentObject, Object.DataVersion);
				Object.DataExchange.Load = True;
				Object.AdditionalProperties.Insert("RecordSetsOfAccessValues");
				Object.AdditionalProperties.Insert("RecordDependentSetsOfAccessValues");
				Object.AdditionalProperties.Insert("AccessValueSetsTablePartsFilled");
				Object.AccessValuesSets.Load(Table);
				Object.Write();
				UnlockDataForEdit(RefOnDependentObject);
			Except
				BriefErrorDescription = BriefErrorDescription(ErrorInfo());
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='An error occurred while updating dependent"
"access values set"
"of"
"the object ""%1"": %2';ru='При обновлении зависимого набора"
"значений доступа объекта"
"""%1"""
"возникла ошибка: %2'"),
					String(RefOnDependentObject),
					BriefErrorDescription);
			EndTry;
		EndIf;
	EndDo;
	
EndProcedure

Procedure FillParameters(InputParameters, Val AllParameters, Val MandatoryParameters = "")
	
	If TypeOf(InputParameters) = Type("Structure") Then
		Parameters = InputParameters;
	ElsIf InputParameters = Undefined Then
		Parameters = New Structure;
	Else
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Incorrect properties set type ""%1""."
"Allowed types: Structure, Undefined.';ru='Некорректный тип набора свойств ""%1""."
"Допустимые типы: Структура, Неопределено.'"),
			TypeOf(InputParameters));
	EndIf;
	
	For Each KeyAndValue IN Parameters Do
		If Not AllParameters.Property(KeyAndValue.Key) Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='%1 non-existent parameter is specified';ru='Указан несуществующий параметр %1'"), KeyAndValue.Key);
		EndIf;
		AllParameters[KeyAndValue.Key] = Parameters[KeyAndValue.Key];
	EndDo;
	
	If ValueIsFilled(MandatoryParameters) Then
		MandatoryParameters = New Structure(MandatoryParameters);
		
		For Each KeyAndValue IN MandatoryParameters Do
			If Not Parameters.Property(KeyAndValue.Key) Then
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='%1 mandatory parameter is not specified';ru='Не указан обязательный параметр %1'"), KeyAndValue.Key);
			EndIf;
		EndDo;
	EndIf;
	
	InputParameters = AllParameters;
	
EndProcedure

// For the IncludeUserToAccessGroup,
// ExcludeUserFromAccessGroup procedures and FindUserInAccessGroup function.

Function ProcessUserLinkWithAccessGroup(User, ProvidedProfile, Enable = Undefined)
	
	If TypeOf(User) <> Type("CatalogRef.Users")
	   AND TypeOf(User) <> Type("CatalogRef.UsersGroups")
	   AND TypeOf(User) <> Type("CatalogRef.ExternalUsers")
	   AND TypeOf(User) <> Type("CatalogRef.ExternalUsersGroups") Then
		
		Return False;
	EndIf;
	
	IDSuppliedProfile = Undefined;
	
	If TypeOf(ProvidedProfile) = Type("String") Then
		If StringFunctionsClientServer.ThisIsUUID(ProvidedProfile) Then
			
			IDSuppliedProfile = ProvidedProfile;
			
			ProvidedProfile = Catalogs.AccessGroupsProfiles.ProfileSuppliedByIdIdentificator(
				IDSuppliedProfile);
		Else
			Return False;
		EndIf;
	EndIf;
	
	If TypeOf(ProvidedProfile) <> Type("CatalogRef.AccessGroupsProfiles") Then
		Return False;
	EndIf;
	
	If IDSuppliedProfile = Undefined Then
		IDSuppliedProfile =
			Catalogs.AccessGroupsProfiles.IDSuppliedProfile(ProvidedProfile);
	EndIf;
	
	If IDSuppliedProfile = Catalogs.AccessGroupsProfiles.ProfileIdAdministrator() Then
		Return False;
	EndIf;
	
	ProfileProperties = AccessManagementServiceReUse.Parameters(
		).ProvidedAccessGroupsProfiles.ProfileDescriptions.Get(IDSuppliedProfile);
	
	If ProfileProperties = Undefined
	 OR ProfileProperties.AccessKinds.Count() <> 0 Then
		
		Return False;
	EndIf;
	
	AccessGroup = Undefined;
	
	If SimplifiedInterfaceOfAccessRightsSettings() Then
		
		If TypeOf(User) <> Type("CatalogRef.Users")
		   AND TypeOf(User) <> Type("CatalogRef.ExternalUsers") Then
			
			Return False;
		EndIf;
		
		Query = New Query;
		Query.SetParameter("Profile", ProvidedProfile);
		Query.SetParameter("User", User);
		Query.Text =
		"SELECT
		|	AccessGroups.Ref AS Ref
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	AccessGroups.Profile = &Profile
		|	AND AccessGroups.User = &User";
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			AccessGroup = Selection.Ref;
		EndIf;
		
		If AccessGroup = Undefined Then
			If Enable <> True Then
				Return False;
			Else
				AccessGroup = Catalogs.AccessGroups.CreateItem();
				AccessGroup.Description = ProfileProperties.Description;
				AccessGroup.Profile      = ProvidedProfile;
				AccessGroup.User = User;
				AccessGroup.Users.Add().User = User;
				AccessGroup.Write();
				Return True;
			EndIf;
		EndIf;
	Else
		Query = New Query;
		Query.SetParameter("ProvidedProfile", ProvidedProfile);
		Query.Text =
		"SELECT
		|	AccessGroups.Ref AS Ref,
		|	AccessGroups.MainGroupAccessProfileSupplied
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	AccessGroups.Profile = &ProvidedProfile
		|
		|ORDER BY
		|	AccessGroups.MainGroupAccessProfileSupplied DESC";
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			AccessGroup = Selection.Ref;
		EndIf;
		
		If AccessGroup = Undefined Then
			If Enable <> True Then
				Return False;
			Else
				AccessGroup = Catalogs.AccessGroups.CreateItem();
				AccessGroup.MainGroupAccessProfileSupplied = True;
				AccessGroup.Description = ProfileProperties.Description;
				AccessGroup.Profile = ProvidedProfile;
				AccessGroup.Users.Add().User = User;
				AccessGroup.Write();
				Return True;
			EndIf;
		EndIf;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", AccessGroup);
	Query.SetParameter("User", User);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups.Users AS UsersGroupsMembers
	|WHERE
	|	UsersGroupsMembers.Ref = &Ref
	|	AND UsersGroupsMembers.User = &User";
	UserIsFound = Not Query.Execute().IsEmpty();
	
	If Enable = Undefined Then
		Return UserIsFound;
	EndIf;
	
	If Enable AND UserIsFound Then
		Return True;
	EndIf;
	
	If Not Enable AND Not UserIsFound Then
		Return True;
	EndIf;
	
	AccessGroup = AccessGroup.GetObject();
	
	If Not SimplifiedInterfaceOfAccessRightsSettings()
	   AND Not AccessGroup.MainGroupAccessProfileSupplied Then
		
		AccessGroup.MainGroupAccessProfileSupplied = True;
	EndIf;
	
	If Enable Then
		AccessGroup.Users.Add().User = User;
	Else
		Filter = New Structure("User", User);
		Rows = AccessGroup.Users.FindRows(Filter);
		For Each String IN Rows Do
			AccessGroup.Users.Delete(String);
		EndDo;
	EndIf;
	
	AccessGroup.Write();
	
	Return True;
	
EndFunction

// For the UpdateUsersRoles procedure.

Function CurrentUserProperties(UserArray)
	
	Query = New Query;
	
	Query.SetParameter("EmptyID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	If UserArray = Undefined Then
		Query.Text =
		"SELECT
		|	Users.Ref AS User,
		|	Users.InfobaseUserID
		|INTO CheckedUsers
		|FROM
		|	Catalog.Users AS Users
		|WHERE
		|	Users.Service = FALSE
		|	AND Users.InfobaseUserID <> &EmptyID
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUsers.Ref,
		|	ExternalUsers.InfobaseUserID
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	ExternalUsers.InfobaseUserID <> &EmptyID";
		
	ElsIf TypeOf(UserArray) = Type("Type") Then
		If Metadata.FindByType(UserArray) = Metadata.Catalogs.ExternalUsers Then
			Query.Text =
			"SELECT
			|	ExternalUsers.Ref AS User,
			|	ExternalUsers.InfobaseUserID
			|INTO CheckedUsers
			|FROM
			|	Catalog.ExternalUsers AS ExternalUsers
			|WHERE
			|	ExternalUsers.InfobaseUserID <> &EmptyID";
		Else
			Query.Text =
			"SELECT
			|	Users.Ref AS User,
			|	Users.InfobaseUserID
			|INTO CheckedUsers
			|FROM
			|	Catalog.Users AS Users
			|WHERE
			|	Users.Service = FALSE
			|	AND Users.InfobaseUserID <> &EmptyID";
		EndIf;
	Else
		InitialUsers = New ValueTable;
		InitialUsers.Columns.Add("User", New TypeDescription(
			"CatalogRef.Users, CatalogRef.ExternalUsers"));
		
		For Each User IN UserArray Do
			InitialUsers.Add().User = User;
		EndDo;
		
		Query.SetParameter("InitialUsers", InitialUsers);
		Query.Text =
		"SELECT DISTINCT
		|	InitialUsers.User
		|INTO InitialUsers
		|FROM
		|	&InitialUsers AS InitialUsers
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Users.Ref AS User,
		|	Users.InfobaseUserID
		|INTO CheckedUsers
		|FROM
		|	Catalog.Users AS Users
		|		INNER JOIN InitialUsers AS InitialUsers
		|		ON Users.Ref = InitialUsers.User
		|			AND (Users.Service = FALSE)
		|			AND (Users.InfobaseUserID <> &EmptyID)
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUsers.Ref,
		|	ExternalUsers.InfobaseUserID
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|		INNER JOIN InitialUsers AS InitialUsers
		|		ON ExternalUsers.Ref = InitialUsers.User
		|			AND (ExternalUsers.InfobaseUserID <> &EmptyID)";
	EndIf;
	
	Query.Text = Query.Text + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|" +
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.InfobaseUserID
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		INNER JOIN Catalog.Users AS Users
	|		ON (AccessGroupsUsers.Ref = VALUE(Catalog.AccessGroups.Administrators))
	|			AND AccessGroupsUsers.User = Users.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CheckedUsers.User,
	|	CheckedUsers.InfobaseUserID
	|FROM
	|	CheckedUsers AS CheckedUsers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	CheckedUsers.User AS User,
	|	AccessGroupsUsers.Ref.Profile AS Profile
	|INTO AllUsersProfiles
	|FROM
	|	CheckedUsers AS CheckedUsers
	|		INNER JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|		ON CheckedUsers.User = UsersGroupsContents.User
	|			AND (UsersGroupsContents.Used)
	|			AND (&ExcludeExternalUsers)
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON (UsersGroupsContents.UsersGroup = AccessGroupsUsers.User)
	|			AND (NOT AccessGroupsUsers.Ref.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ProfileRoles.Profile AS Profile,
	|	ProfileRoles.Role AS Role
	|INTO ProfileRoles
	|FROM
	|	&ProfileRoles AS ProfileRoles
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AllUsersProfiles.User,
	|	AllUsersProfiles.Profile,
	|	ProfileRoles.Role AS ProfileRole
	|INTO UsersProfiles
	|FROM
	|	AllUsersProfiles AS AllUsersProfiles
	|		LEFT JOIN ProfileRoles AS ProfileRoles
	|		ON (ProfileRoles.Profile = AllUsersProfiles.Profile)
	|			AND (NOT AllUsersProfiles.Profile.StandardProfileChanged)
	|WHERE
	|	Not AllUsersProfiles.Profile.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UsersProfiles.User,
	|	Roles.Role.Name AS Role
	|FROM
	|	UsersProfiles AS UsersProfiles
	|		INNER JOIN Catalog.AccessGroupsProfiles.Roles AS Roles
	|		ON (Roles.Ref = UsersProfiles.Profile)
	|			AND (UsersProfiles.ProfileRole IS NULL )
	|
	|UNION ALL
	|
	|SELECT
	|	UsersProfiles.User,
	|	UsersProfiles.ProfileRole
	|FROM
	|	UsersProfiles AS UsersProfiles
	|WHERE
	|	Not UsersProfiles.ProfileRole IS NULL ";
	
	ProfileRoles = New ValueTable;
	ProfileRoles.Columns.Add("Profile", New TypeDescription("CatalogRef.AccessGroupsProfiles"));
	ProfileRoles.Columns.Add("Role", New TypeDescription("String",, New StringQualifiers(255)));
	
	If Not CommonUseReUse.DataSeparationEnabled()
	   AND UseProfileRoles() Then
		
		ProfileRolesDescription = AccessManagementServiceReUse.ProfileRolesDescription();
		For Each ProfileRoleDescription IN ProfileRolesDescription Do
			FillPropertyValues(ProfileRoles.Add(), ProfileRoleDescription);
		EndDo;
	EndIf;
	
	Query.SetParameter("ProfileRoles", ProfileRoles);
	
	If GetFunctionalOption("UseExternalUsers") Then
		Query.Text = StrReplace(Query.Text, "&ExcludeExternalUsers", "True");
	Else
		Query.Text = StrReplace(Query.Text, "&ExcludeExternalUsers",
			"VALUETYPE(CheckedUsers.User)= TYPE(Catalog.Users)");
	EndIf;
	
	QueryResults = Query.ExecuteBatch();
	LastResult = QueryResults.Count()-1;
	Total = New Structure;
	
	Total.Insert("Administrators", New Map);
	
	For Each String IN QueryResults[LastResult-5].Unload() Do
		Total.Administrators.Insert(String.Ref, True);
	EndDo;
	
	Total.Insert("InfobaseUserIDs", QueryResults[LastResult-4].Unload());
	Total.InfobaseUserIDs.Indexes.Add("User");
	
	Total.Insert("UsersRoles", QueryResults[LastResult].Unload());
	Total.UsersRoles.Indexes.Add("User");
	
	Return Total;
	
EndFunction

Function UseProfileRoles()
	
	Return Not CommonUseClientServer.DebugMode();
EndFunction

Function UserProfilesWithRole(CurrentUser, Role)
	
	Query = New Query;
	Query.SetParameter("CurrentUser", CurrentUser);
	Query.SetParameter("Role", Role);
	
	Query.SetParameter("EmptyID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	Query.Text =
	"SELECT DISTINCT
	|	Roles.Ref AS Profile
	|FROM
	|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON (UsersGroupsContents.User = &CurrentUser)
	|			AND UsersGroupsContents.UsersGroup = AccessGroupsUsers.User
	|			AND (UsersGroupsContents.Used)
	|			AND (NOT AccessGroupsUsers.Ref.DeletionMark)
	|		INNER JOIN Catalog.AccessGroupsProfiles.Roles AS Roles
	|		ON (Roles.Ref = AccessGroupsUsers.Ref.Profile)
	|			AND (NOT Roles.Ref.DeletionMark)
	|			AND (Roles.Role.Name = &Role)";
	
	Return Query.Execute().Unload().UnloadColumn("Profile");
	
EndFunction

Procedure UpdateInfobaseUsersRoles(UpdatedIBUsers, ServiceUserPassword)
	
	For Each KeyAndValue IN UpdatedIBUsers Do
		RolesForAdding  = KeyAndValue.Value.RolesForAdding;
		RolesForDeletion    = KeyAndValue.Value.RolesForDeletion;
		IBUser     = KeyAndValue.Value.IBUser;
		UserRef = KeyAndValue.Value.UserRef;
		
		WasFullRights = IBUser.Roles.Contains(Metadata.Roles.FullRights);
		
		For Each KeyAndValue IN RolesForAdding Do
			IBUser.Roles.Add(Metadata.Roles[KeyAndValue.Key]);
		EndDo;
		
		For Each KeyAndValue IN RolesForDeletion Do
			IBUser.Roles.Delete(Metadata.Roles[KeyAndValue.Key]);
		EndDo;
		
		RecordUserOnRolesUpdate(UserRef, IBUser, WasFullRights, ServiceUserPassword);
	EndDo;
	
EndProcedure

Procedure RecordUserOnRolesUpdate(UserRef, IBUser, WasFullRights, ServiceUserPassword)
	
	BeginTransaction();
	
	Try
		UsersService.WriteInfobaseUser(IBUser);
		
		If Not CommonUseReUse.DataSeparationEnabled() Then
			CommitTransaction();
			Return;
		EndIf;
		
		IsFullRights = IBUser.Roles.Contains(Metadata.Roles.FullRights);
		If IsFullRights = WasFullRights Then
			CommitTransaction();
			Return;
		EndIf;
		
		If ServiceUserPassword = Undefined Then
			
			If CommonUseReUse.SessionWithoutSeparator() Then
				CommitTransaction();
				Return;
			EndIf;
			
			Raise
				NStr("en='To change administrative"
"access, service user password is required."
""
"Operation can be performed only interactively';ru='Для изменения"
"административного доступа требуется пароль пользователя сервиса."
""
"Операция может быть выполнена только интерактивно.'");
		EndIf;
		
		OnWriteServiceUser(UserRef, False, ServiceUserPassword);
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// For the ChangesSelectionQueryText procedure.

Function KeyAndValue(Structure)
	
	For Each KeyAndValue IN Structure Do
		Return KeyAndValue;
	EndDo;
	
EndFunction

// For the UpdateRecordSet and UpdateRecordSets  procedures.

Function ParametersGroupDimensionsProcessed(DimensionName, ValuesDimensions)
	
	If DimensionName = Undefined Then
		ValuesDimensions = Undefined;
		
	ElsIf ValuesDimensions = Undefined Then
		DimensionName = Undefined;
		
	ElsIf TypeOf(ValuesDimensions) <> Type("Array")
	        AND TypeOf(ValuesDimensions) <> Type("FixedArray") Then
		
		ValueDimensions = ValuesDimensions;
		ValuesDimensions = New Array;
		ValuesDimensions.Add(ValueDimensions);
		
	ElsIf ValuesDimensions.Count() = 0 Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Procedure OrderGroupsParametersMeasurement(Data)
	
	If Data.NameOfSecondDimension = Undefined Then
		Data.NameOfSecondDimension       = Data.NameOfThirdDimensions;
		Data.ValueOfSecondMeasure  = Data.ValuesOfThirdDimensions;
		Data.NameOfThirdDimensions      = Undefined;
		Data.ValuesOfThirdDimensions = Undefined;
	EndIf;
	
	If Data.NameOfFirstDimension = Undefined Then
		Data.NameOfFirstDimension       = Data.NameOfSecondDimension;
		Data.ValuesOfFirstDimensions  = Data.ValueOfSecondMeasure;
		Data.NameOfSecondDimension       = Data.NameOfThirdDimensions;
		Data.ValueOfSecondMeasure  = Data.ValuesOfThirdDimensions;
		Data.NameOfThirdDimensions      = Undefined;
		Data.ValuesOfThirdDimensions = Undefined;
	EndIf;
	
	If Data.ValueOfSecondMeasure  <> Undefined
	   AND Data.ValuesOfThirdDimensions <> Undefined
	   AND Data.ValueOfSecondMeasure.Count()
	   > Data.ValuesOfThirdDimensions.Count() Then
		
		DimensionName      = Data.NameOfSecondDimension;
		ValuesDimensions = Data.ValueOfSecondMeasure;
		
		Data.NameOfSecondDimension       = Data.NameOfThirdDimensions;
		Data.ValueOfSecondMeasure  = Data.ValuesOfThirdDimensions;
		Data.NameOfThirdDimensions      = DimensionName;
		Data.ValuesOfThirdDimensions = ValuesDimensions;
	EndIf;
	
	If Data.ValuesOfFirstDimensions <> Undefined
	   AND Data.ValueOfSecondMeasure <> Undefined
	   AND Data.ValuesOfFirstDimensions.Count()
	   > Data.ValueOfSecondMeasure.Count() Then
		
		DimensionName      = Data.NameOfFirstDimension;
		ValuesDimensions = Data.ValuesOfFirstDimensions;
		
		Data.NameOfFirstDimension      = Data.NameOfSecondDimension;
		Data.ValuesOfFirstDimensions = Data.ValueOfSecondMeasure;
		Data.NameOfSecondDimension      = DimensionName;
		Data.ValueOfSecondMeasure = ValuesDimensions;
	EndIf;
	
EndProcedure

Function RecordSetFields(RecordSet)
	
	ComparisonFields = "";
	Table = RecordSet.Unload(New Array);
	For Each Column IN Table.Columns Do
		ComparisonFields = ComparisonFields + "," + Column.Name;
	EndDo;
	ComparisonFields = Mid(ComparisonFields, 2);
	
	Return ComparisonFields;
	
EndFunction

Function RefreshNewRecordSetForAllNewRecords(Val Data,
                                                    Val Filter,
                                                    Val FieldList,
                                                    Val DimensionName,
                                                    Val ValuesDimensions,
                                                    HasChanges)
	
	// Open transaction if it is no transaction
	// or it is not opened for the controlled lock execution on the read records set.
	// It may be the situation when transaction
	// is fixed without the actual data change i.e. if the locked data match.
	If Data.TransactionOpen = False Then
		Data.TransactionOpen = True;
		BeginTransaction();
	EndIf;
	
	LockRecordSetArea(Data.RecordSet, Data.FullNameOfRegister);
	
	Data.RecordSet.Read();
	NewSetRecords = Data.RecordSet.Unload();
	NewSetRecords.Indexes.Add(FieldList);
	
	For Each Value IN ValuesDimensions Do
		Filter[DimensionName] = Value;
		FoundRecords = NewSetRecords.FindRows(Filter);
		For Each FoundRecord IN NewSetRecords.FindRows(Filter) Do
			NewSetRecords.Delete(FoundRecord);
		EndDo;
		For Each FoundRecord IN Data.NewRecords.FindRows(Filter) Do
			FillPropertyValues(NewSetRecords.Add(), FoundRecord);
		EndDo;
	EndDo;
	
	CurrentData = New Structure("RecordSet, ComparisonFields, CheckOnly, AdditionalProperties");
	FillPropertyValues(CurrentData, Data);
	CurrentData.Insert("NewRecords", NewSetRecords);
	CurrentData.Insert("RecordSetRead", True);
	
	RefreshRecordset(CurrentData, HasChanges, , Data.TransactionOpen);
	
EndFunction

Procedure RefreshNewRecordSetOnVariousNewAccounts(Val Data, Val Filter, HasChanges)
	
	If Data.TransactionOpen = False Then
		Data.TransactionOpen = True;
		BeginTransaction();
	EndIf;
	
	// Receive records quantity for reading.
	
	If Filter.Count() = 0 Then
		CurrentNewRecords = Data.NewRecords.Copy();
		NumberOfRead = Data.NumberOfRead;
	Else
		CurrentNewRecords = Data.NewRecords.Copy(Filter);
		
		FieldName = Data.NumberOfValues.Columns[0].Name;
		RowOfNumber = Data.NumberOfValues.Find(Filter[FieldName], FieldName);
		NumberOfRead = ?(RowOfNumber = Undefined, 0, RowOfNumber.Quantity);
	EndIf;
	
	FilterNewRecords = New Structure("RowChangeKind, " + Data.ComparisonFields, 1);
	CurrentNewRecords.Indexes.Add("RowChangeKind, " + Data.ComparisonFields);

	KeysRecords = CurrentNewRecords.Copy(, "RowChangeKind, " + Data.ComparisonFields);
	KeysRecords.GroupBy("RowChangeKind, " + Data.ComparisonFields);
	KeysRecords.GroupBy(Data.ComparisonFields, "RowChangeKind");
	
	FilterByRecordsKey = New Structure(Data.ComparisonFields);
	
	If NumberOfRead < 1000
	 OR (  NumberOfRead < 100000
	      AND KeysRecords.Count() * 50 > NumberOfRead) Then
		// Block update.
		LockRecordSetArea(Data.RecordSet, Data.FullNameOfRegister);
		Data.RecordSet.Read();
		NewSetRecords = Data.RecordSet.Unload();
		NewSetRecords.Indexes.Add(Data.ComparisonFields);
		
		For Each String IN KeysRecords Do
			FillPropertyValues(FilterByRecordsKey, String);
			FoundStrings = NewSetRecords.FindRows(FilterByRecordsKey);
			If String.RowChangeKind = -1 Then
				If FoundStrings.Count() > 0 Then
					// Delete old string.
					NewSetRecords.Delete(FoundStrings[0]);
				EndIf;
			Else
				// Add new or update old string.
				If FoundStrings.Count() = 0 Then
					FillsString = NewSetRecords.Add();
				Else
					FillsString = FoundStrings[0];
				EndIf;
				FillPropertyValues(FilterNewRecords, FilterByRecordsKey);
				FoundRecords = CurrentNewRecords.FindRows(FilterNewRecords);
				If FoundRecords.Count() = 1 Then
					NewRecord = FoundRecords[0];
				Else // An error occurred in the NewRecords parameter.
					ExceptWithErrorSearchRecords(Data);
				EndIf;
				FillPropertyValues(FillsString, NewRecord);
			EndIf;
		EndDo;
		// Change records set for it to differ from the set new records.
		If Data.RecordSet.Count() = NewSetRecords.Count() Then
			Data.RecordSet.Add();
		EndIf;
		
		CurrentData = New Structure("RecordSet, ComparisonFields, CheckOnly, AdditionalProperties");
		FillPropertyValues(CurrentData, Data);
		CurrentData.Insert("NewRecords", NewSetRecords);
		CurrentData.Insert("RecordSetRead", True);
		
		RefreshRecordset(CurrentData, HasChanges, , Data.TransactionOpen);
	Else
		// Rowwise update.
		SetAdditionalProperties(Data.SetForSingleRecords, Data.AdditionalProperties);
		For Each String IN KeysRecords Do
			Data.SetForSingleRecords.Clear();
			FillPropertyValues(FilterByRecordsKey, String);
			For Each KeyAndValue IN FilterByRecordsKey Do
				SetFilter(
					Data.SetForSingleRecords.Filter[KeyAndValue.Key], KeyAndValue.Value);
			EndDo;
			LockRecordSetArea(Data.SetForSingleRecords, Data.FullNameOfRegister);
			If String.RowChangeKind > -1 Then
				// Add new or update existing string.
				FillPropertyValues(FilterNewRecords, FilterByRecordsKey);
				FoundRecords = CurrentNewRecords.FindRows(FilterNewRecords);
				If FoundRecords.Count() = 1 Then
					NewRecord = FoundRecords[0];
				Else // An error occurred in the NewRecords parameter.
					ExceptWithErrorSearchRecords(Data);
				EndIf;
				FillPropertyValues(Data.SetForSingleRecords.Add(), NewRecord);
			EndIf;
			HasChanges = True;
			If Data.CheckOnly Then
				Return;
			EndIf;
			Data.SetForSingleRecords.Write();
		EndDo;
	EndIf;
	
EndProcedure

Procedure ExceptWithErrorSearchRecords(Parameters)
	
	For Each ChangesRow IN Parameters.NewRecords Do
		If ChangesRow.RowChangeKind <>  1
		   AND ChangesRow.RowChangeKind <> -1 Then
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred"
"in the UpdateRecordSets procedure of the AccessManagementService general module."
""
"NewRecords parameter incorrect"
"value – RowChangeKind column contains invalid value ""%1""."
""
"Only 2 values are available: ""1"" and ""-1"".';ru='Ошибка"
"в процедуре ОбновитьНаборыЗаписей общего модуля УправлениеДоступомСлужебный."
""
"Неверное значение"
"параметра НовыеЗаписи - колонка ВидИзмененияСтроки содержит недопустимое значение ""%1""."
""
"Допустимо только 2 значения: ""1"" и ""-1"".'"),
				String(ChangesRow.RowChangeKind));
		EndIf;
	EndDo;
	
	Raise
		NStr("en='An error occurred"
"in the UpdateRecordSets procedure of the AccessManagementService general module."
""
"Unable to find the required"
"string in the NewRecords parameter value.';ru='Ошибка"
"в процедуре ОбновитьНаборыЗаписей общего модуля УправлениеДоступомСлужебный."
""
"Не удалось найти"
"требуемую в строку в значении параметра НовыеЗаписи.'");
	
EndProcedure

Procedure LockRecordSetArea(RecordSet, FullNameOfRegister = Undefined)
	
	If Not TransactionActive() Then
		Return;
	EndIf;
	
	If FullNameOfRegister = Undefined Then
		FullNameOfRegister = Metadata.FindByType(TypeOf(RecordSet)).FullName();
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add(FullNameOfRegister);
	LockItem.Mode = DataLockMode.Shared;
	For Each FilterItem IN RecordSet.Filter Do
		If FilterItem.Use Then
			LockItem.SetValue(FilterItem.DataPath, FilterItem.Value);
		EndIf;
	EndDo;
	Block.Lock();
	
EndProcedure

Procedure SetFilter(FilterItem, FilterValue)
	
	FilterItem.Value = FilterValue;
	FilterItem.Use = True;
	
EndProcedure

Function WriteMultipleSets(Data, Filter, FieldName, ValuesFields)
	
	Query = New Query;
	Query.SetParameter("ValuesFields", ValuesFields);
	Query.Text =
	"SELECT
	|	COUNT(*) AS Quantity
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	&FilterCondition
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(*) AS Quantity
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.FieldName IN(&ValuesFields)
	|	AND &FilterCondition
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CurrentTable.FieldName AS FieldName,
	|	COUNT(*) AS Quantity
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.FieldName IN(&ValuesFields)
	|	AND &FilterCondition
	|
	|GROUP BY
	|	CurrentTable.FieldName";
	
	FilterCondition = "True";
	If Data.FixedSelection <> Undefined Then
		For Each KeyAndValue IN Data.FixedSelection Do
			FilterCondition = FilterCondition + "
			|	AND CurrentTable." + KeyAndValue.Key + " = &" + KeyAndValue.Key;
			Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
	EndIf;
	
	FilterOfAdding = New Structure;
	FilterOfAdding.Insert("RowChangeKind", 1);
	DeletedFilter = New Structure;
	DeletedFilter.Insert("RowChangeKind", -1);
	
	For Each KeyAndValue IN Filter Do
		FilterCondition = FilterCondition + "
		|	AND CurrentTable." + KeyAndValue.Key + " = &" + KeyAndValue.Key;
		Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value);
		FilterOfAdding.Insert(KeyAndValue.Key, KeyAndValue.Value);
		DeletedFilter.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	Query.Text = StrReplace(Query.Text, "FieldName", FieldName);
	Query.Text = StrReplace(Query.Text, "&CurrentTable", Data.FullNameOfRegister);
	Query.Text = StrReplace(Query.Text, "&FilterCondition", FilterCondition);
	
	QueryResults = Query.ExecuteBatch();
	
	// Count of all without filter.
	CountOfAll = QueryResults[0].Unload()[0].Quantity;
	Data.Insert("NumberOfRead", CountOfAll);
	
	// Quantity of ones updated with filter.
	CountOfUpdated = QueryResults[1].Unload()[0].Quantity;
	
	AddedCount = Data.NewRecords.FindRows(FilterOfAdding).Count();
	If AddedCount > CountOfUpdated Then
		CountOfUpdated = AddedCount;
	EndIf;
	
	ToDeleteCount = Data.NewRecords.FindRows(DeletedFilter).Count();
	If ToDeleteCount > CountOfUpdated Then
		CountOfUpdated = ToDeleteCount;
	EndIf;
	
	// Count for reading by filter values.
	NumberOfValues = QueryResults[2].Unload();
	NumberOfValues.Indexes.Add(FieldName);
	Data.Insert("NumberOfValues", NumberOfValues);
	
	Return CountOfAll * 0.7 > CountOfUpdated;
	
EndFunction

Procedure ReadCountForReading(Data)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(*) AS Quantity
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	&FilterCondition";
	
	FilterCondition = "True";
	If Data.FixedSelection <> Undefined Then
		For Each KeyAndValue IN Data.FixedSelection Do
			FilterCondition = FilterCondition + "
			|	AND CurrentTable." + KeyAndValue.Key + " = &" + KeyAndValue.Key;
			Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", Data.FullNameOfRegister);
	Query.Text = StrReplace(Query.Text, "&FilterCondition", FilterCondition);
	
	QueryResults = Query.ExecuteBatch();
	
	Data.Insert("NumberOfRead", Query.Execute().Unload()[0].Quantity);
	
EndProcedure

Procedure SetAdditionalProperties(RecordSet, AdditionalProperties)
	
	If TypeOf(AdditionalProperties) = Type("Structure") Then
		For Each KeyAndValue IN AdditionalProperties Do
			RecordSet.AdditionalProperties.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
	EndIf;
	
EndProcedure

// For the UpdateInformationRegister procedure.

Function ValuesTableColumns(Table, ColumnName)
	
	NewTable = Table.Copy(, ColumnName);
	
	NewTable.GroupBy(ColumnName);
	
	Return NewTable.UnloadColumn(ColumnName);
	
EndFunction

// Servicing tables AccessKinds and AccessValues in edit forms.

Procedure AddAuxiliaryDataAttributesToForm(Form, TablesStorageAttributeName)
	
	AttributesToAdd = New Array;
	AccessValueTypeDescription = Metadata.DefinedTypes.AccessValue.Type;
	
	ObjectPath = ?(ValueIsFilled(TablesStorageAttributeName), TablesStorageAttributeName + ".", "");
	
	// Add attributes to the AccessKinds table.
	AttributesToAdd.Add(New FormAttribute(
		"Used", New TypeDescription("Boolean"), ObjectPath + "AccessKinds"));
	
	// Add individual attributes.
	AttributesToAdd.Add(New FormAttribute(
		"CurrentAccessType", AccessValueTypeDescription));
	
	AttributesToAdd.Add(New FormAttribute(
		"SelectedValuesCurrentTypes", New TypeDescription("ValueList")));
	
	AttributesToAdd.Add(New FormAttribute(
		"SelectedValuesCurrentType", AccessValueTypeDescription));
	
	If Not FormAttributeExists(Form, "UseExternalUsers") Then
		AttributesToAdd.Add(New FormAttribute(
			"UseExternalUsers", New TypeDescription("Boolean")));
	EndIf;
	
	AttributesToAdd.Add(New FormAttribute(
		"TablesStorageAttributeName", New TypeDescription("String")));
	
	AttributesToAdd.Add(New FormAttribute(
		"ThisIsAccessGroupsProfile", New TypeDescription("Boolean")));
	
	AttributesToAdd.Add(New FormAttribute(
		"AccessTypeUsers", AccessValueTypeDescription));
	
	AttributesToAdd.Add(New FormAttribute(
		"AccessKindExternalUsers", AccessValueTypeDescription));
	
	// Add the AllAccessKinds table.
	AttributesToAdd.Add(New FormAttribute(
		"AllAccessKinds", New TypeDescription("ValueTable")));
	
	AttributesToAdd.Add(New FormAttribute(
		"Ref", AccessValueTypeDescription, "AllAccessKinds"));
	
	AttributesToAdd.Add(New FormAttribute(
		"Presentation", New TypeDescription("String"), "AllAccessKinds"));
	
	AttributesToAdd.Add(New FormAttribute(
		"Used", New TypeDescription("Boolean"), "AllAccessKinds"));
	
	// Add the PresentationsAllAllowed table.
	AttributesToAdd.Add(New FormAttribute(
		"PresentationsAllAllowed", New TypeDescription("ValueTable")));
	
	AttributesToAdd.Add(New FormAttribute(
		"Name", New TypeDescription("String"), "PresentationsAllAllowed"));
	
	AttributesToAdd.Add(New FormAttribute(
		"Presentation", New TypeDescription("String"), "PresentationsAllAllowed"));
	
	// Add the AllAccessKinds AllSelectedValuesTypes table.
	AttributesToAdd.Add(New FormAttribute(
		"AllSelectedValuesTypes", New TypeDescription("ValueTable")));
	
	AttributesToAdd.Add(New FormAttribute(
		"AccessKind", AccessValueTypeDescription, "AllSelectedValuesTypes"));
	
	AttributesToAdd.Add(New FormAttribute(
		"ValuesType", AccessValueTypeDescription, "AllSelectedValuesTypes"));
	
	AttributesToAdd.Add(New FormAttribute(
		"TypePresentation", New TypeDescription("String"), "AllSelectedValuesTypes"));
	
	AttributesToAdd.Add(New FormAttribute(
		"TableName", New TypeDescription("String"), "AllSelectedValuesTypes"));
	
	Form.ChangeAttributes(AttributesToAdd);
	
EndProcedure

Procedure FillTableAllAccessKindsInForm(Form)
	
	For Each AccessTypeProperties IN AccessTypeProperties() Do
		String = Form.AllAccessKinds.Add();
		String.Ref        = AccessTypeProperties.Ref;
		String.Used  = AccessKindIsUsed(String.Ref);
		// Provide presentation uniqueness.
		Presentation = AccessTypeProperties.Presentation;
		Filter = New Structure("Presentation", Presentation);
		While Form.AllAccessKinds.FindRows(Filter).Count() > 0 Do
			Filter.Presentation = Filter.Presentation + " ";
		EndDo;
		String.Presentation = Presentation;
	EndDo;
	
EndProcedure

Procedure FillPresentationTableAllAllowedInForm(Form, IsProfile)
	
	If IsProfile Then
		String = Form.PresentationsAllAllowed.Add();
		String.Name = "InitiallyAllProhibited";
		String.Presentation = NStr("en='All prohibited, exclusions are set in access groups';ru='Все запрещены, исключения назначаются в группах доступа'");
		
		String = Form.PresentationsAllAllowed.Add();
		String.Name = "InitiallyAllAllowed";
		String.Presentation = NStr("en='All allowed, exclusions are set in access groups';ru='Все разрешены, исключения назначаются в группах доступа'");
		
		String = Form.PresentationsAllAllowed.Add();
		String.Name = "AllProhibited";
		String.Presentation = NStr("en='All are prohibited, exclusions are assigned in the profile';ru='Все запрещены, исключения назначаются в профиле'");
		
		String = Form.PresentationsAllAllowed.Add();
		String.Name = "AllAllowed";
		String.Presentation = NStr("en='All are allowed, exclusions are assigned in the profile';ru='Все разрешены, исключения назначаются в профиле'");
	Else
		String = Form.PresentationsAllAllowed.Add();
		String.Name = "AllProhibited";
		String.Presentation = NStr("en='All prohibited';ru='Все запрещены'");
		
		String = Form.PresentationsAllAllowed.Add();
		String.Name = "AllAllowed";
		String.Presentation = NStr("en='All allowed';ru='Все разрешены'");
	EndIf;
	
	ChoiceList = Form.Items.AccessKindsAllAllowedPresentation.ChoiceList;
	
	For Each String IN Form.PresentationsAllAllowed Do
		ChoiceList.Add(String.Presentation);
	EndDo;
	
EndProcedure

Procedure GenerateAccessKindsTableInForm(Form)
	
	Parameters = AllowedValuesEditFormParameters(Form);
	
	// Design display of unused access kinds.
	ConditionalAppearanceItem = Form.ConditionalAppearance.Items.Add();
	
	ItemColorsDesign = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	ItemColorsDesign.Value = WebColors.Gray;
	ItemColorsDesign.Use = True;
	
	FolderSelectionDataElements = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FolderSelectionDataElements.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	FolderSelectionDataElements.Use = True;
	
	DataFilterItem = FolderSelectionDataElements.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField(Parameters.PathToTables + "AccessKinds.AccessKind");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.NotEqual;
	DataFilterItem.RightValue = Undefined;
	DataFilterItem.Use  = True;
	
	DataFilterItem = FolderSelectionDataElements.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField(Parameters.PathToTables + "AccessKinds.Used");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False;
	DataFilterItem.Use  = True;
	
	ItemProcessedFields = ConditionalAppearanceItem.Fields.Items.Add();
	ItemProcessedFields.Field = New DataCompositionField("AccessKinds");
	ItemProcessedFields.Use = True;
	
EndProcedure

Procedure DeleteExtraAccessValues(Form, CurrentObject = Undefined)
	
	Parameters = AllowedValuesEditFormParameters(Form, CurrentObject);
	
	ByGroupsAndValuesTypes = AccessManagementServiceReUse.Parameters(
		).AccessKindsProperties.ByGroupsAndValuesTypes;
	
	Filter = AccessManagementServiceClientServer.FilterInAllowedValuesEditFormTables(
		Form, "");
	
	IndexOf = Parameters.AccessValues.Count()-1;
	While IndexOf >= 0 Do
		AccessValue = Parameters.AccessValues[IndexOf].AccessValue;
		
		AccessTypeProperties = ByGroupsAndValuesTypes.Get(TypeOf(AccessValue));
		If AccessTypeProperties <> Undefined Then
			FillPropertyValues(Filter, Parameters.AccessValues[IndexOf]);
			Filter.Insert("AccessKind", AccessTypeProperties.Ref);
		EndIf;
		
		If AccessTypeProperties = Undefined
		 OR Parameters.AccessValues[IndexOf].AccessKind <> Filter.AccessKind
		 OR Parameters.AccessKinds.FindRows(Filter).Count() = 0 Then
			
			Parameters.AccessValues.Delete(IndexOf);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
EndProcedure

Procedure DeleteNonExistentLindsAndAccessValues(Form, CurrentObject = Undefined)
	
	Parameters = AllowedValuesEditFormParameters(Form, CurrentObject);
	
	IndexOf = Parameters.AccessKinds.Count()-1;
	While IndexOf >= 0 Do
		AccessKind = Parameters.AccessKinds[IndexOf].AccessKind;
		If AccessTypeProperties(AccessKind) = Undefined Then
			Parameters.AccessKinds.Delete(IndexOf);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	DeleteExtraAccessValues(Form, CurrentObject);
	
EndProcedure

Function AllowedValuesEditFormParameters(Form, CurrentObject = Undefined)
	
	Return AccessManagementServiceClientServer.AllowedValuesEditFormParameters(
		Form, CurrentObject);
	
EndFunction

Function FormAttributeExists(Form, AttributeName)
	
	Structure = New Structure(AttributeName, Null);
	
	FillPropertyValues(Structure, Form);
	
	Return Structure[AttributeName] <> Null;
	
EndFunction

// For the SetSessionParameters procedure.

Function AllAccessKindsCombinations(UnorderedNamesArray) Export
	
	// The restriction on the max combination length
	// to prevent the session parameters overloading and RLS templates preprocessor.
	MaxCombinationLength = 4;
	
	List = New ValueList;
	If TypeOf(UnorderedNamesArray) = Type("FixedArray") Then
		List.LoadValues(New Array(UnorderedNamesArray));
	Else
		List.LoadValues(UnorderedNamesArray);
	EndIf;
	List.SortByValue();
	NameArray = List.UnloadValues();
	
	Total = "";
	
	// Full list is always supported.
	For Each Name IN NameArray Do
		Total = Total + "," + Name;
	EndDo;
	
	Total = Total + "," + Chars.LF;
	
	If NameArray.Count() < 3 Then
		Return Total;
	EndIf;
	
	FirstName = NameArray[0];
	NameArray.Delete(0);
	
	LastName = NameArray[NameArray.Count()-1];
	NameArray.Delete(NameArray.Count()-1);
	
	NamesInCombinationQuantity = NameArray.Count();
	
	If NamesInCombinationQuantity > 1 Then
		
		If (NamesInCombinationQuantity-1) <= MaxCombinationLength Then
			CombinationLength = NamesInCombinationQuantity-1;
		Else
			CombinationLength = MaxCombinationLength;
		EndIf;
		
		NamePositionsInCombination = New Array;
		For Counter = 1 To CombinationLength Do
			NamePositionsInCombination.Add(Counter);
		EndDo;
		
		While CombinationLength > 0 Do
			While True Do
				// Add combination from the current positions.
				Total = Total + "," + FirstName;
				For IndexOf = 0 To CombinationLength-1 Do
					Total = Total + "," + NameArray[NamePositionsInCombination[IndexOf]-1];
				EndDo;
				Total = Total + "," + LastName + "," + Chars.LF;
				// Move position in combination.
				IndexOf = CombinationLength-1;
				While IndexOf >= 0 Do
					If NamePositionsInCombination[IndexOf] < NamesInCombinationQuantity - (CombinationLength - (IndexOf+1)) Then
						NamePositionsInCombination[IndexOf] = NamePositionsInCombination[IndexOf] + 1;
						// Fill in senior positions with initial values.
						For SeniorPositionIndex = IndexOf+1 To CombinationLength-1 Do
							NamePositionsInCombination[SeniorPositionIndex] =
								NamePositionsInCombination[IndexOf] + SeniorPositionIndex - IndexOf;
						EndDo;
						Break;
					Else
						IndexOf = IndexOf - 1;
					EndIf;
				EndDo;
				If IndexOf < 0 Then
					Break;
				EndIf;
			EndDo;
			CombinationLength = CombinationLength - 1;
			For IndexOf = 0 To CombinationLength - 1 Do
				NamePositionsInCombination[IndexOf] = IndexOf + 1;
			EndDo;
		EndDo;
	EndIf;
	
	Total = Total + "," + FirstName+ "," + LastName + "," + Chars.LF;
	
	Return Total;
	
EndFunction

// For procedures UpdateAccessValueSets, OnChangeAccessValueSets.

// Checks whether sets in the tabular section differ from the new sets.
Function AccessValuesSetsOfTabularSectionChanged(ObjectReference, NewSets)
	
	OldSets = CommonUse.ObjectAttributeValue(
		ObjectReference, "AccessValuesSets").Unload();
	
	If OldSets.Count() <> NewSets.Count() Then
		Return True;
	EndIf;
	
	OldSets.Columns.Add("AccessKind", New TypeDescription("String"));
	AccessManagement.AddAccessValueSets(
		OldSets, AccessManagement.TableAccessValueSets(), False, True);
	
	SearchFields = "SetNumber, AccessValue, Adjustment, Reading, Change";
	
	NewSets.Indexes.Add(SearchFields);
	Filter = New Structure(SearchFields);
	
	For Each String IN OldSets Do
		FillPropertyValues(Filter, String);
		If NewSets.FindRows(Filter).Count() <> 1 Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

#EndRegion
