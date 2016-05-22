#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
Function NotEditableInGroupProcessingAttributes() Export
	
	NotEditableAttributes = New Array;
	NotEditableAttributes.Add("IDSuppliedData");
	NotEditableAttributes.Add("StandardProfileChanged");
	NotEditableAttributes.Add("Roles.DeleteRole");
	NotEditableAttributes.Add("AccessKinds.*");
	NotEditableAttributes.Add("AccessValues.*");
	
	Return NotEditableAttributes;
	
EndFunction

#EndRegion

#Region ServiceProgramInterface

// Procedure updates supplied profiles description
// in access restriction parameters while changing configuration.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if there
//                  is a record, True is set, otherwise, it is not changed.
//
Procedure UpdateProvidedProfilesDescription(HasChanges = Undefined, CheckOnly = False) Export
	
	SetPrivilegedMode(True);
	
	If CheckOnly OR ExclusiveMode() Then
		SwitchOffSoleMode = False;
	Else
		SwitchOffSoleMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	ProvidedProfiles = ProvidedProfiles();
	
	Block = New DataLock;
	LockItem = Block.Add("Constant.AccessLimitationParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Parameters = StandardSubsystemsServer.ApplicationWorkParameters(
			"AccessLimitationParameters");
		
		Saved = Undefined;
		
		If Parameters.Property("ProvidedAccessGroupsProfiles") Then
			Saved = Parameters.ProvidedAccessGroupsProfiles;
			
			If Not CommonUse.DataMatch(ProvidedProfiles, Saved) Then
				Saved = Undefined;
			EndIf;
		EndIf;
		
		If Saved = Undefined Then
			HasChanges = True;
			If CheckOnly Then
				CommitTransaction();
				Return;
			EndIf;
			StandardSubsystemsServer.SetApplicationPerformenceParameter(
				"AccessLimitationParameters",
				"ProvidedAccessGroupsProfiles",
				ProvidedProfiles);
		EndIf;
		
		StandardSubsystemsServer.ConfirmUpdatingApplicationWorkParameter(
			"AccessLimitationParameters", "ProvidedAccessGroupsProfiles");
		
		If Not CheckOnly Then
			StandardSubsystemsServer.AddChangesToApplicationPerformenceParameters(
				"AccessLimitationParameters",
				"ProvidedAccessGroupsProfiles",
				?(Saved = Undefined,
				  New FixedStructure("HasChanges", True),
				  New FixedStructure()) );
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

// Procedure updates predefined profiles
// content in access restriction parameters while changing configuration.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if there
//                  is a record, True is set, otherwise, it is not changed.
//
Procedure UpdatePredefinedProfilesContent(HasChanges = Undefined, CheckOnly = False) Export
	
	SetPrivilegedMode(True);
	
	If CheckOnly OR ExclusiveMode() Then
		SwitchOffSoleMode = False;
	Else
		SwitchOffSoleMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	PredefinedProfiles = Metadata.Catalogs.AccessGroupsProfiles.GetPredefinedNames();
	
	Block = New DataLock;
	LockItem = Block.Add("Constant.AccessLimitationParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Parameters = StandardSubsystemsServer.ApplicationWorkParameters(
			"AccessLimitationParameters");
		
		HasDeleted = False;
		Saved = Undefined;
		
		If Parameters.Property("AccessGroupsPredefinedProfiles") Then
			Saved = Parameters.AccessGroupsPredefinedProfiles;
			
			If Not PredefinedProfilesMatch(PredefinedProfiles, Saved, HasDeleted) Then
				Saved = Undefined;
			EndIf;
		EndIf;
		
		If Saved = Undefined Then
			HasChanges = True;
			If CheckOnly Then
				CommitTransaction();
				Return;
			EndIf;
			StandardSubsystemsServer.SetApplicationPerformenceParameter(
				"AccessLimitationParameters",
				"AccessGroupsPredefinedProfiles",
				PredefinedProfiles);
		EndIf;
		
		StandardSubsystemsServer.ConfirmUpdatingApplicationWorkParameter(
			"AccessLimitationParameters",
			"AccessGroupsPredefinedProfiles");
		
		If Not CheckOnly Then
			StandardSubsystemsServer.AddChangesToApplicationPerformenceParameters(
				"AccessLimitationParameters",
				"AccessGroupsPredefinedProfiles",
				?(HasDeleted,
				  New FixedStructure("HasDeleted", True),
				  New FixedStructure()) );
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

// Precedure updates supplied catalog profiles by
// the result of changing supplied profiles description saved to the access restriction parameters.
//
Procedure UpdateProvidedProfilesByConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	Parameters = AccessManagementServiceReUse.Parameters();
	
	LastChanges = StandardSubsystemsServer.ApplicationPerformenceParameterChanging(
		Parameters, "ProvidedAccessGroupsProfiles");
		
	If LastChanges = Undefined Then
		UpdateNeeded = True;
	Else
		UpdateNeeded = False;
		For Each ChangesPart IN LastChanges Do
			
			If TypeOf(ChangesPart) = Type("FixedStructure")
			   AND ChangesPart.Property("HasChanges")
			   AND TypeOf(ChangesPart.HasChanges) = Type("Boolean") Then
				
				If ChangesPart.HasChanges Then
					UpdateNeeded = True;
					Break;
				EndIf;
			Else
				UpdateNeeded = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If UpdateNeeded Then
		UpdateStandardProfiles();
	EndIf;
	
EndProcedure

// Updates the supplied profiles and if needed updates access groups of these profiles.
// Not found supplied access group profiles are created.
//
// Update features are set in
// the FillProvidedAccessGroupProfiles procedure of the AccessManagementOverridable general module (see comment to procedure).
//
// Parameters:
//  HasChanges - Boolean (return value) - if there
//                  is a record, True is set, otherwise, it is not changed.
//
Procedure UpdateStandardProfiles(HasChanges = Undefined) Export
	
	ProvidedProfiles = AccessManagementServiceReUse.Parameters(
		).ProvidedAccessGroupsProfiles;
	
	ProfileDescriptions    = ProvidedProfiles.ProfilesDescriptionArray;
	UpdateParameters = ProvidedProfiles.UpdateParameters;
	
	UpdatedProfiles       = New Array;
	UpdatedAccessGroups = New Array;
	
	Query = New Query(
	"SELECT
	|	AccessGroupsProfiles.StandardProfileChanged,
	|	AccessGroupsProfiles.IDSuppliedData,
	|	AccessGroupsProfiles.Ref AS Ref
	|FROM
	|	Catalog.AccessGroupsProfiles AS AccessGroupsProfiles");
	CurrentProfiles = Query.Execute().Unload();
	
	For Each ProfileProperties IN ProfileDescriptions Do
		
		RowOfCurrentRef = CurrentProfiles.Find(
			New UUID(ProfileProperties.ID),
			"IDSuppliedData");
		
		ProfileUpdated = False;
		
		If RowOfCurrentRef = Undefined Then
			// Create new supplied profile.
			If UpdateProfileOfAccessGroups(ProfileProperties) Then
				HasChanges = True;
			EndIf;
			Profile = ProfileSuppliedByIdIdentificator(ProfileProperties.ID);
			
		Else
			Profile = RowOfCurrentRef.Ref;
			If Not RowOfCurrentRef.StandardProfileChanged
			 OR UpdateParameters.UpdateChangedProfiles Then
				// Update supplied profile.
				ProfileUpdated = UpdateProfileOfAccessGroups(ProfileProperties, True);
			EndIf;
		EndIf;
		
		If UpdateParameters.UpdateAccessGroups Then
			ProfileAccessGroupsWereUpdated = Catalogs.AccessGroups.RefreshProfileAccessGroups(
				Profile, UpdateParameters.UpdateAccessGroupsWithObsoleteSettings);
			
			ProfileUpdated = ProfileUpdated OR ProfileAccessGroupsWereUpdated;
		EndIf;
		
		If ProfileUpdated Then
			HasChanges = True;
			UpdatedProfiles.Add(Profile);
		EndIf;
	EndDo;
	
	// Update user roles.
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	UsersGroupsContents.User
	|FROM
	|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON UsersGroupsContents.UsersGroup = AccessGroupsUsers.User
	|			AND (AccessGroupsUsers.Ref.Profile IN (&Profiles))";
	Query.SetParameter("Profiles", UpdatedProfiles);
	UsersForUpdating = Query.Execute().Unload().UnloadColumn("User");
	
	AccessManagement.UpdateUsersRoles(UsersForUpdating);
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    * Identifier - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    * Important        - Boolean - If True, the work is marked in red.
//    * Presentation - String - a work presentation displayed to the user.
//    * Count    - Number  - a quantitative indicator of work, it is displayed in the work header string.
//    * Form         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner      - String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip     - String - The tooltip wording.
//
Procedure AtFillingToDoList(CurrentWorks) Export
	
	ModuleCurrentWorksService = CommonUse.CommonModule("CurrentWorksService");
	If Not Users.InfobaseUserWithFullAccess(, True)
		Or ModuleCurrentWorksService.WorkDisabled("AccessGroupsProfiles") Then
		Return;
	EndIf;
	ModuleCurrentWorksServer = CommonUse.CommonModule("CurrentWorksServer");
	
	// The procedure is called only if there is the
	// To-do lists subsystem, that is why here is no checking of subsystem existence.
	Sections = ModuleCurrentWorksServer.SectionsForObject(Metadata.Catalogs.AccessGroupsProfiles.FullName());
	
	If Sections = Undefined Then
		Return;
	EndIf;
	
	For Each Section IN Sections Do
		
		IncompatibleAccessGroupProfilesQuantity = IncompatibleAccessGroupProfilesCount();
		
		ProfileId = "IncompatibleWithCurrentVersion" + StrReplace(Section.FullName(), ".", "");
		Work = CurrentWorks.Add();
		Work.ID = ProfileId;
		Work.ThereIsWork      = IncompatibleAccessGroupProfilesQuantity > 0;
		Work.Presentation = NStr("en = 'Incompatible with the current version'");
		Work.Quantity    = IncompatibleAccessGroupProfilesQuantity;
		Work.Owner      = Section;
		
		Work = CurrentWorks.Add();
		Work.ID = "AccessGroupsProfiles";
		Work.ThereIsWork      = IncompatibleAccessGroupProfilesQuantity > 0;
		Work.Important        = True;
		Work.Presentation = NStr("en = 'Access group profiles'");
		Work.Quantity    = IncompatibleAccessGroupProfilesQuantity;
		Work.Form         = "Catalog.AccessGroupsProfiles.Form.ListForm";
		Work.FormParameters= New Structure("ProfileWithRolesMarkerForDeletion", True);
		Work.Owner      = ProfileId;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns unique
// ID string of the supplied and prefefined profile Administrator.
//
Function ProfileIdAdministrator() Export
	
	Return "6c4b0307-43a4-4141-9c35-3dd7e9586d41";
	
EndFunction

// Returns reference to the supplied profile by ID.
//
// Parameters:
//  ID - String - name and unique ID of the supplied profile.
//
Function ProfileSuppliedByIdIdentificator(ID) Export
	
	SetPrivilegedMode(True);
	
	ProvidedProfiles = AccessManagementServiceReUse.Parameters(
		).ProvidedAccessGroupsProfiles;
	
	ProfileProperties = ProvidedProfiles.ProfileDescriptions.Get(ID);
	
	Query = New Query;
	Query.SetParameter("IDSuppliedData",
		New UUID(ProfileProperties.ID));
	
	Query.Text =
	"SELECT
	|	AccessGroupsProfiles.Ref AS Ref
	|FROM
	|	Catalog.AccessGroupsProfiles AS AccessGroupsProfiles
	|WHERE
	|	AccessGroupsProfiles.IDSuppliedData = &IDSuppliedData";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Returns unique
// ID string of the supplied profile data.
//
Function IDSuppliedProfile(Profile) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("Ref", Profile);
	
	Query.SetParameter("EmptyUUID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	Query.Text =
	"SELECT
	|	AccessGroupsProfiles.IDSuppliedData
	|FROM
	|	Catalog.AccessGroupsProfiles AS AccessGroupsProfiles
	|WHERE
	|	AccessGroupsProfiles.Ref = &Ref
	|	AND AccessGroupsProfiles.IDSuppliedData <> &EmptyUUID";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		ProvidedProfiles = AccessManagementServiceReUse.Parameters(
			).ProvidedAccessGroupsProfiles;
		
		ProfileProperties = ProvidedProfiles.ProfileDescriptions.Get(
			String(Selection.IDSuppliedData));
		
		Return String(Selection.IDSuppliedData);
	EndIf;
	
	Return Undefined;
	
EndFunction

// Checks whether supplied profile is changed compared to the description from the procedure.
// AccessManagementPredefined.FillSuppliedAccessGroupsProfiles().
//
// Parameters:
//  Profile      - CatalogRef.AccessGroupsProfiles
//                     (returns the StandardProfileChanged attribute),
//               - CatalogObject.AccessGroupsProfiles
//                     (result of object filling comparison
//                     with the description in the overridable general module is returned).
//
// Returns:
//  Boolean.
//
Function StandardProfileChanged(Profile) Export
	
	If TypeOf(Profile) = Type("CatalogRef.AccessGroupsProfiles") Then
		Return CommonUse.ObjectAttributeValue(Profile, "StandardProfileChanged");
	EndIf;
	
	ProfileProperties = AccessManagementServiceReUse.Parameters(
		).ProvidedAccessGroupsProfiles.ProfileDescriptions.Get(
			String(Profile.IDSuppliedData));
	
	If ProfileProperties = Undefined Then
		Return False;
	EndIf;
	
	ProfileRolesDescription = ProfileRolesDescription(ProfileProperties);
	
	If Upper(Profile.Description) <> Upper(ProfileProperties.Description) Then
		Return True;
	EndIf;
	
	If Profile.Roles.Count()            <> ProfileRolesDescription.Count()
	 OR Profile.AccessKinds.Count()     <> ProfileProperties.AccessKinds.Count()
	 OR Profile.AccessValues.Count() <> ProfileProperties.AccessValues.Count() Then
		Return True;
	EndIf;
	
	For Each Role IN ProfileRolesDescription Do
		RoleMetadata = Metadata.Roles.Find(Role);
		If RoleMetadata = Undefined Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Role ""%2"" is not
				           |found in metadata while checking supplied profile.'"),
				ProfileProperties.Description,
				Role);
		EndIf;
		RoleIdentificator = CommonUse.MetadataObjectID(RoleMetadata);
		If Profile.Roles.FindRows(New Structure("Role", RoleIdentificator)).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	For Each AccessTypeDescription IN ProfileProperties.AccessKinds Do
		AccessTypeProperties = AccessManagementService.AccessTypeProperties(AccessTypeDescription.Key);
		Filter = New Structure;
		Filter.Insert("AccessKind",        AccessTypeProperties.Ref);
		Filter.Insert("Preset", AccessTypeDescription.Value = "Preset");
		Filter.Insert("AllAllowed",      AccessTypeDescription.Value = "InitiallyAllAllowed");
		If Profile.AccessKinds.FindRows(Filter).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	For Each AccessValueDetails IN ProfileProperties.AccessValues Do
		Filter = New Structure;
		Query = New Query(StrReplace("SELECT Value(%1) AS Value", "%1", AccessValueDetails.AccessValue));
		Filter.Insert("AccessValue", Query.Execute().Unload()[0].Value);
		If Profile.AccessValues.FindRows(Filter).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Determines whether there is an initial filling for access groups profile in the overridable module.
//  
// Parameters:
//  Profile      - CatalogRef.AccessGroupsProfiles.
//  
// Returns:
//  Boolean.
//
Function IsInitialProfileFilling(Val Profile) Export
	
	IDSuppliedData = String(CommonUse.ObjectAttributeValue(
		Profile, "IDSuppliedData"));
	
	ProfileProperties = AccessManagementServiceReUse.Parameters(
		).ProvidedAccessGroupsProfiles.ProfileDescriptions.Get(IDSuppliedData);
	
	Return ProfileProperties <> Undefined;
	
EndFunction

// Determines change prohibition of the supplied module.
// Not supplied profile can not have change prohibition.
//  
// Parameters:
//  Profile      - CatalogObject.AccessGroupProfiles,
//                 FormDataStructure created according to the object.
//  
// Returns:
//  Boolean.
//
Function ProfileChangingProhibition(Val Profile) Export
	
	If Profile.IDSuppliedData =
			New UUID(ProfileIdAdministrator()) Then
		// It is always allowed to change the Administrator profile.
		Return True;
	EndIf;
	
	ProvidedProfiles = AccessManagementServiceReUse.Parameters(
		).ProvidedAccessGroupsProfiles;
	
	ProfileProperties = ProvidedProfiles.ProfileDescriptions.Get(
		String(Profile.IDSuppliedData));
	
	Return ProfileProperties <> Undefined
	      AND ProvidedProfiles.UpdateParameters.RestrictProfilesChanging;
	
EndFunction

// Returns supplied profile destination description.
//
// Parameters:
//  Profile - CatalogRef.AccessGroupsProfiles.
//
// Returns:
//  Row.
//
Function StandardProfileDescription(Profile) Export
	
	IDSuppliedData = String(CommonUse.ObjectAttributeValue(
		Profile, "IDSuppliedData"));
	
	ProfileProperties = AccessManagementServiceReUse.Parameters(
		).ProvidedAccessGroupsProfiles.ProfileDescriptions.Get(IDSuppliedData);
	
	Text = "";
	If ProfileProperties <> Undefined Then
		Text = ProfileProperties.Definition;
	EndIf;
	
	Return Text;
	
EndFunction

// Creates supplied profile in the
// AccessGroupProfiles catalog appropriate for the applied solution and allows
// to refill previously created supplied profile by its supplied description.
//  Search initial filling is executed by a profile unique identifier string.
//
// Parameters:
//  Profile      - CatalogRef.AccessGroupsProfiles.
//                 If the initial filling description is found
//                 for the specified profile, the profile content is completely replaced.
//
// UpdateAccessGroups - Boolean if True, access kinds of profile access groups will be updated.
//
Procedure FillStandardProfile(Val Profile, Val UpdateAccessGroups) Export
	
	IDSuppliedData = String(CommonUse.ObjectAttributeValue(
		Profile, "IDSuppliedData"));
	
	ProfileProperties = AccessManagementServiceReUse.Parameters(
		).ProvidedAccessGroupsProfiles.ProfileDescriptions.Get(IDSuppliedData);
	
	If ProfileProperties <> Undefined Then
		
		UpdateProfileOfAccessGroups(ProfileProperties);
		
		If UpdateAccessGroups Then
			Catalogs.AccessGroups.RefreshProfileAccessGroups(Profile, True);
		EndIf;
	EndIf;
	
EndProcedure

// Handlers of infobase update.

// Fills in supplied data identifiers coincidentally with reference identifier.
Procedure FillInDataSuppliedIdentifiers() Export
	
	SetPrivilegedMode(True);
	
	ProvidedProfiles = AccessManagementServiceReUse.Parameters(
		).ProvidedAccessGroupsProfiles;
	
	ReferencesSuppliedProfiles = New Array;
	
	For Each ProfileDescription IN ProvidedProfiles.ProfilesDescriptionArray Do
		ReferencesSuppliedProfiles.Add(
			Catalogs.AccessGroupsProfiles.GetRef(
				New UUID(ProfileDescription.ID)));
	EndDo;
	
	Query = New Query;
	Query.SetParameter("EmptyUUID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	Query.SetParameter("ReferencesSuppliedProfiles", ReferencesSuppliedProfiles);
	Query.Text =
	"SELECT
	|	AccessGroupsProfiles.Ref
	|FROM
	|	Catalog.AccessGroupsProfiles AS AccessGroupsProfiles
	|WHERE
	|	AccessGroupsProfiles.IDSuppliedData = &EmptyUUID
	|	AND AccessGroupsProfiles.Ref IN (&ReferencesSuppliedProfiles)";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ProfileObject = Selection.Ref.GetObject();
		ProfileObject.IDSuppliedData = Selection.Ref.UUID();
		InfobaseUpdate.WriteData(ProfileObject);
	EndDo;
	
EndProcedure

// Replaces reference with CCT.AccessKinds as an empty reference of the main access kind values type.
Procedure ConvertAccessKindsIdentifiers() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroupsProfiles.Ref AS Ref
	|FROM
	|	Catalog.AccessGroupsProfiles AS AccessGroupsProfiles
	|WHERE
	|	Not(NOT TRUE In
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							Catalog.AccessGroupsProfiles.AccessKinds AS AccessKinds
	|						WHERE
	|							AccessKinds.Ref = AccessGroupsProfiles.Ref
	|							AND VALUETYPE(AccessKinds.AccessKind) = Type(ChartOfCharacteristicTypes.DeleteAccessKinds))
	|				AND Not TRUE In
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							Catalog.AccessGroupsProfiles.AccessValues AS AccessValues
	|						WHERE
	|							AccessValues.Ref = AccessGroupsProfiles.Ref
	|							AND VALUETYPE(AccessValues.AccessKind) = Type(ChartOfCharacteristicTypes.DeleteAccessKinds)))
	|
	|UNION ALL
	|
	|SELECT
	|	AccessGroups.Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	Not(NOT TRUE In
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							Catalog.AccessGroups.AccessKinds AS AccessKinds
	|						WHERE
	|							AccessKinds.Ref = AccessGroups.Ref
	|							AND VALUETYPE(AccessKinds.AccessKind) = Type(ChartOfCharacteristicTypes.DeleteAccessKinds))
	|				AND Not TRUE In
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							Catalog.AccessGroups.AccessValues AS AccessValues
	|						WHERE
	|							AccessValues.Ref = AccessGroups.Ref
	|							AND VALUETYPE(AccessValues.AccessKind) = Type(ChartOfCharacteristicTypes.DeleteAccessKinds)))";
	
	Selection = Query.Execute().Select();
	
	If Selection.Count() = 0 Then
		Return;
	EndIf;
	
	AccessKindsProperties = AccessManagementServiceReUse.Parameters().AccessKindsProperties;
	
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		
		IndexOf = Object.AccessKinds.Count()-1;
		While IndexOf >= 0 Do
			String = Object.AccessKinds[IndexOf];
			Try
				AccessTypeName = ChartsOfCharacteristicTypes.DeleteAccessKinds.GetPredefinedItemName(
					String.AccessKind);
			Except
				AccessTypeName = "";
			EndTry;
			AccessTypeProperties = AccessKindsProperties.ByNames.Get(AccessTypeName);
			If AccessTypeProperties = Undefined Then
				Object.AccessKinds.Delete(IndexOf);
			Else
				String.AccessKind = AccessTypeProperties.Ref;
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		
		IndexOf = Object.AccessValues.Count()-1;
		While IndexOf >= 0 Do
			String = Object.AccessValues[IndexOf];
			Try
				AccessTypeName = ChartsOfCharacteristicTypes.DeleteAccessKinds.GetPredefinedItemName(
					String.AccessKind);
			Except
				AccessTypeName = "";
			EndTry;
			AccessTypeProperties = AccessKindsProperties.ByNames.Get(AccessTypeName);
			If AccessTypeProperties = Undefined Then
				Object.AccessValues.Delete(IndexOf);
			Else
				String.AccessKind = AccessTypeProperties.Ref;
				If Object.AccessKinds.Find(String.AccessKind, "AccessKind") = Undefined Then
					Object.AccessValues.Delete(IndexOf);
				EndIf;
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

Function ProvidedProfiles()
	
	UpdateParameters = New Structure;
	// Supplied profiles update properties.
	UpdateParameters.Insert("UpdateChangedProfiles", True);
	UpdateParameters.Insert("RestrictProfilesChanging", True);
	// Update properties of the supplied profiles access groups.
	UpdateParameters.Insert("UpdateAccessGroups", True);
	UpdateParameters.Insert("UpdateAccessGroupsWithObsoleteSettings", False);
	
	ProfileDescriptions = New Array;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AccessManagement\WhenFillingOutProfileGroupsAccessProvided");
	For Each Handler IN EventHandlers Do
		Handler.Module.WhenFillingOutProfileGroupsAccessProvided(ProfileDescriptions, UpdateParameters);
	EndDo;
	
	AccessManagementOverridable.WhenFillingOutProfileGroupsAccessProvided(
		ProfileDescriptions, UpdateParameters);
	
	ErrorTitle =
		NStr("en = 'Invalid values are set in
		           |the OnFillingSuppliedAccessGroupProfiles procedure of the AccessManagementOverridable general module.
		           |
		           |'");
	
	If UpdateParameters.RestrictProfilesChanging
	   AND Not UpdateParameters.UpdateChangedProfiles Then
		
		Raise ErrorTitle +
			NStr("en = 'When in the
			           |UpdateParameters parameter the
			           |UpdateChangedProfiles property is set
			           |to False, then the ProhibitProfilesChange property should also be set to False.'");
	EndIf;
	
	// Description for filling the "Administrator" predefined profile.
	AdministratorProfileDescription = AccessManagement.AccessGroupProfileNewDescription();
	AdministratorProfileDescription.Name           = "Administrator";
	AdministratorProfileDescription.ID = ProfileIdAdministrator();
	AdministratorProfileDescription.Description  = NStr("en = 'Administrator'");
	AdministratorProfileDescription.Roles.Add("FullRights");
	//SB
	AdministratorProfileDescription.Definition =
		NStr("en = 'Profile is designed for work of the executive staff and service functions execution. 
					|Provides unlimited access to all the information system data. 
					|
					|Use the profile to work with all sections: - Sales, Purchases, Services, Production, Funds, Salary, Company, Analysis and Settings.'");
	//End SB.
	ProfileDescriptions.Add(AdministratorProfileDescription);
	
	AllRoles = UsersService.AllRoles().Map;
	
	AccessKindsProperties = StandardSubsystemsServer.ApplicationWorkParameters(
		"AccessLimitationParameters").AccessKindsProperties;
	
	// Convert descriptions to IDs
	// and properties match for storing and quick processing.
	ProfilesProperties = New Map;
	ProfilesDescriptionArray = New Array;
	For Each ProfileDescription IN ProfileDescriptions Do
		// Check whether there are roles in metadata.
		For Each Role IN ProfileDescription.Roles Do
			If AllRoles.Get(Role) = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'In the proattachment description
					           |""%1 (%2)"" role ""%3"" is not found in metadata.'"),
					ProfileDescription.Name,
					ProfileDescription.ID,
					Role);
			EndIf;
			If Upper(Left(Role, StrLen("Profile"))) = Upper("Profile") Then
				Raise ErrorTitle + StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'In the proattachment description
					           |""%1 (%2)"" invalid role ""%3"" is specified.'"),
					ProfileDescription.Name,
					ProfileDescription.ID,
					Role);
			EndIf;
		EndDo;
		If ProfilesProperties.Get(ProfileDescription.ID) <> Undefined Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Profile with ID ""%1"" already exists.'"),
				ProfileDescription.ID);
		EndIf;
		ProfilesProperties.Insert(ProfileDescription.ID, ProfileDescription);
		ProfilesDescriptionArray.Add(ProfileDescription);
		If ValueIsFilled(ProfileDescription.Name) Then
			If ProfilesProperties.Get(ProfileDescription.Name) <> Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'Profile with the name ""%1"" already exists.'"),
					ProfileDescription.Name);
			EndIf;
			ProfilesProperties.Insert(ProfileDescription.Name, ProfileDescription);
		EndIf;
		// Convert ValuesList to Match for commitment.
		AccessKinds = New Map;
		For Each ItemOfList IN ProfileDescription.AccessKinds Do
			AccessTypeName       = ItemOfList.Value;
			AccessKindRefiner = ItemOfList.Presentation;
			If AccessKindsProperties.ByNames.Get(AccessTypeName) = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'In the profile
					           |description ""%1"" invalid access kind ""%3"" is specified.'"),
					?(ValueIsFilled(ProfileDescription.Name),
					  ProfileDescription.Name,
					  ProfileDescription.ID),
					AccessTypeName);
			EndIf;
			If AccessKindRefiner <> ""
			   AND AccessKindRefiner <> "InitiallyAllProhibited"
			   AND AccessKindRefiner <> "Preset"
			   AND AccessKindRefiner <> "InitiallyAllAllowed" Then
				
				Raise ErrorTitle + StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'In the profile
					           |description ""%1"" for the access kind ""2"" unknown refiner ""%3"" is specified.
					           |
					           |Only the following
					           |refiners are valid: -
					           |""AllProhibitedInBeginning""
					           |or """", - ""AllAllowedInBeginning"", - ""Preset"".'"),
					?(ValueIsFilled(ProfileDescription.Name),
					  ProfileDescription.Name,
					  ProfileDescription.ID),
					AccessTypeName,
					AccessKindRefiner);
			EndIf;
			AccessKinds.Insert(AccessTypeName, AccessKindRefiner);
		EndDo;
		ProfileDescription.AccessKinds = AccessKinds;
		
		// Delete all repeated values.
		AccessValues = New Array;
		AccessValuesTable = New ValueTable;
		AccessValuesTable.Columns.Add("AccessKind",      Metadata.DefinedTypes.AccessValue.Type);
		AccessValuesTable.Columns.Add("AccessValue", Metadata.DefinedTypes.AccessValue.Type);
		
		For Each ItemOfList IN ProfileDescription.AccessValues Do
			Filter = New Structure;
			Filter.Insert("AccessKind",      ItemOfList.Value);
			Filter.Insert("AccessValue", ItemOfList.Presentation);
			AccessKind      = Filter.AccessKind;
			AccessValue = Filter.AccessValue;
			
			AccessTypeProperties = AccessKindsProperties.ByNames.Get(AccessKind);
			If AccessTypeProperties = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'In the profile
					           |description ""%1"" invalid access kind
					           |""2"" is specified
					           |for access value ""%3"".'"),
					?(ValueIsFilled(ProfileDescription.Name),
					  ProfileDescription.Name,
					  ProfileDescription.ID),
					AccessKind,
					AccessValue);
			EndIf;
			
			MetadataObject = Undefined;
			DotPosition = Find(AccessValue, ".");
			If DotPosition > 0 Then
				MetadataObjectKind = Left(AccessValue, DotPosition - 1);
				RemainingString = Mid(AccessValue, DotPosition + 1);
				DotPosition = Find(RemainingString, ".");
				If DotPosition > 0 Then
					MetadataObjectName = Left(RemainingString, DotPosition - 1);
					FullMetadataObjectName = MetadataObjectKind + "." + MetadataObjectName;
					MetadataObject = Metadata.FindByFullName(FullMetadataObjectName);
				EndIf;
			EndIf;
			
			If MetadataObject = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'In the profile
					           |description ""%1"" for the
					           |access kind ""2"" specified access value
					           |type ""%3"" does not exist.'"),
					?(ValueIsFilled(ProfileDescription.Name),
					  ProfileDescription.Name,
					  ProfileDescription.ID),
					AccessKind,
					AccessValue);
			EndIf;
			
			Try
				AccessValueEmptyRef = CommonUse.ObjectManagerByFullName(
					FullMetadataObjectName).EmptyRef();
			Except
				AccessValueEmptyRef = Undefined;
			EndTry;
			
			If AccessValueEmptyRef = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'In the profile
					           |description ""%1"" for the
					           |access kind ""2"" not a reference
					           |type of access value ""%3"" is specified.'"),
					?(ValueIsFilled(ProfileDescription.Name),
					  ProfileDescription.Name,
					  ProfileDescription.ID),
					AccessKind,
					AccessValue);
			EndIf;
			AccessValueType = TypeOf(AccessValueEmptyRef);
			
			AccessKindPropertiesByType = AccessKindsProperties.ByValuesTypes.Get(AccessValueType);
			If AccessKindPropertiesByType = Undefined
			 OR AccessKindPropertiesByType.Name <> AccessKind Then
				
				Raise ErrorTitle + StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'In the profile
					           |description ""%1"" access value
					           |of the ""3"" type is specified that is not specified in the access kind ""%2"" properties.'"),
					?(ValueIsFilled(ProfileDescription.Name),
					  ProfileDescription.Name,
					  ProfileDescription.ID),
					AccessKind,
					AccessValue);
			EndIf;
			
			If AccessValuesTable.FindRows(Filter).Count() > 0 Then
				Raise ErrorTitle + StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'In the profile
					           |description ""%1"" for access
					           |kind ""%2"" access value
					           |""%3"" is specified again.'"),
					?(ValueIsFilled(ProfileDescription.Name),
					  ProfileDescription.Name,
					  ProfileDescription.ID),
					AccessKind,
					AccessValue);
			EndIf;
			AccessValues.Add(Filter);
		EndDo;
		ProfileDescription.AccessValues = AccessValues;
	EndDo;
	
	ProvidedProfiles = New Structure;
	ProvidedProfiles.Insert("UpdateParameters",    UpdateParameters);
	ProvidedProfiles.Insert("ProfileDescriptions",       ProfilesProperties);
	ProvidedProfiles.Insert("ProfilesDescriptionArray", ProfilesDescriptionArray);
	
	Return CommonUse.FixedData(ProvidedProfiles);
	
EndFunction

Function PredefinedProfilesMatch(NewProfiles, OldProfiles, HasDeleted)
	
	PredefinedProfilesMatch =
		NewProfiles.Count() = OldProfiles.Count();
	
	For Each Profile IN OldProfiles Do
		If NewProfiles.Find(Profile) = Undefined Then
			PredefinedProfilesMatch = False;
			HasDeleted = True;
			Break;
		EndIf;
	EndDo;
	
	Return PredefinedProfilesMatch;
	
EndFunction

// Replaces existing one or creates a new supplied profile of access groups by its description.
// 
// Parameters:
//  ProfileProperties - FixedStructure - profile properties as
//                    in the structure of the AccessGroupProfileNewDescription return function of the AccessManagement general module.
// 
// Returns:
//  Boolean. True - password is changed.
//
Function UpdateProfileOfAccessGroups(ProfileProperties, DoNotUpdateUsersRoles = False)
	
	ProfileChanged = False;
	
	ProfileRef = ProfileSuppliedByIdIdentificator(ProfileProperties.ID);
	If ProfileRef = Undefined Then
		
		If ValueIsFilled(ProfileProperties.Name) Then
			Query = New Query;
			Query.Text =
			"SELECT
			|	AccessGroupsProfiles.Ref AS Ref,
			|	AccessGroupsProfiles.PredefinedDataName AS PredefinedDataName
			|FROM
			|	Catalog.AccessGroupsProfiles AS AccessGroupsProfiles
			|WHERE
			|	AccessGroupsProfiles.Predefined = TRUE";
			Selection = Query.Execute().Select();
			
			While Selection.Next() Do
				PredefinedName = Selection.PredefinedDataName;
				If Upper(ProfileProperties.Name) = Upper(PredefinedName) Then
					ProfileRef = Selection.Ref;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		If ProfileRef = Undefined Then
			// Supplied profile is not found, create a new one.
			ProfileObject = Catalogs.AccessGroupsProfiles.CreateItem();
		Else
			// Supplied profile is connected with the predefined item.
			ProfileObject = ProfileRef.GetObject();
		EndIf;
		
		ProfileObject.IDSuppliedData =
			New UUID(ProfileProperties.ID);
		
		ProfileChanged = True;
	Else
		ProfileObject = ProfileRef.GetObject();
		ProfileChanged = StandardProfileChanged(ProfileObject);
	EndIf;
	
	If ProfileChanged Then
		LockDataForEdit(ProfileObject.Ref, ProfileObject.DataVersion);
		
		ProfileObject.Description = ProfileProperties.Description;
		
		ProfileObject.Roles.Clear();
		For Each Role IN ProfileRolesDescription(ProfileProperties) Do
			RoleMetadata = Metadata.Roles.Find(Role);
			If RoleMetadata = Undefined Then
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'While updating supplied profile
					           |""%1"" role ""%2"" is not found in metadata.'"),
					ProfileProperties.Description,
					Role);
			EndIf;
			ProfileObject.Roles.Add().Role =
				CommonUse.MetadataObjectID(RoleMetadata)
		EndDo;
		
		ProfileObject.AccessKinds.Clear();
		For Each AccessTypeDescription IN ProfileProperties.AccessKinds Do
			AccessTypeProperties = AccessManagementService.AccessTypeProperties(AccessTypeDescription.Key);
			String = ProfileObject.AccessKinds.Add();
			String.AccessKind        = AccessTypeProperties.Ref;
			String.Preset = AccessTypeDescription.Value = "Preset";
			String.AllAllowed      = AccessTypeDescription.Value = "InitiallyAllAllowed";
		EndDo;
		
		ProfileObject.AccessValues.Clear();
		For Each AccessValueDetails IN ProfileProperties.AccessValues Do
			AccessTypeProperties = AccessManagementService.AccessTypeProperties(AccessValueDetails.AccessKind);
			RowOfValue = ProfileObject.AccessValues.Add();
			RowOfValue.AccessKind = AccessTypeProperties.Ref;
			Query = New Query(StrReplace("SELECT Value(%1) AS Value", "%1", AccessValueDetails.AccessValue));
			RowOfValue.AccessValue = Query.Execute().Unload()[0].Value;
		EndDo;
		
		If DoNotUpdateUsersRoles Then
			ProfileObject.AdditionalProperties.Insert("DoNotUpdateUsersRoles");
		EndIf;
		ProfileObject.Write();
		UnlockDataForEdit(ProfileObject.Ref);
	EndIf;
	
	Return ProfileChanged;
	
EndFunction

Function ProfileRolesDescription(ProfileDescription)
	
	ProfileRolesDescription = New Array;
	DataSeparationEnabled = CommonUseReUse.DataSeparationEnabled();
	
	If DataSeparationEnabled Then
		// Delete from the proattachment descriptions
		// roles containing rights unavailable to the separated user.
		InaccessibleRoles = UsersService.InaccessibleRolesByUserTypes(
			Enums.UserTypes.DataAreaUser);
		
	ElsIf ProfileDescription.ID = ProfileIdAdministrator() Then
		
		SystemAdministratorRoleName = Users.SystemAdministratorRole().Name;
		
		If ProfileRolesDescription.Find(SystemAdministratorRoleName) = Undefined Then
			ProfileRolesDescription.Add(SystemAdministratorRoleName);
		EndIf;
	EndIf;
	
	For Each Role IN ProfileDescription.Roles Do
		If DataSeparationEnabled Then
			If InaccessibleRoles.Get(Role) <> Undefined Then
				Continue;
			EndIf;
		EndIf;
		ProfileRolesDescription.Add(Role);
	EndDo;
	
	Return ProfileRolesDescription;
	
EndFunction

Function IncompatibleAccessGroupProfilesCount()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroupsProfiles.Ref
	|FROM
	|	Catalog.AccessGroupsProfiles AS AccessGroupsProfiles
	|WHERE
	|	AccessGroupsProfiles.Roles.Role.DeletionMark = TRUE";
	
	Result = Query.Execute().Unload();
	
	Return Result.Count();
	
EndFunction

#EndRegion

#EndIf
