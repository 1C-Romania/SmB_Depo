#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
Function NotEditableInGroupProcessingAttributes() Export
	
	NotEditableAttributes = New Array;
	NotEditableAttributes.Add("UsersType");
	NotEditableAttributes.Add("User");
	NotEditableAttributes.Add("MainGroupAccessProfileSupplied");
	NotEditableAttributes.Add("AccessKinds.*");
	NotEditableAttributes.Add("AccessValues.*");
	
	Return NotEditableAttributes;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Sets the deletion mark for the
// access groups if the deletion mark is set for the access group profile. 
// For example, it is required to delete
// predefined profiles of the access groups, as platform does not call
// objects handlers when installing deletion
// mark for former predefined items in the process of updating data base configuration.
//
// Parameters:
//  HasChanges - Boolean (return value) - if there
//               is a record, True is set, otherwise, it is not changed.
//
Procedure MarkToDeleteCheckedProfileAccessGroups(HasChanges = Undefined) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroups.Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Profile.DeletionMark
	|	AND Not AccessGroups.DeletionMark
	|	AND Not AccessGroups.Predefined";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		AccessGroupObject = Selection.Ref.GetObject();
		AccessGroupObject.DeletionMark = True;
		AccessGroupObject.Write();
		HasChanges = True;
	EndDo;
	
EndProcedure

// Updates the access kinds of the specified profile access groups.
// It is possible not to delete access kinds from
// the access group, that were deleted in this access
// group profile, in case when access values by
// deleted access kind are assigned in the access group .
// 
// Parameters:
//  Profile      - CatalogRef.AccessGroupsProfiles
//  UpdateAccessGroupsWithObsoleteSettings - Boolean.
//
// Returns:
//  Boolean - If True, the access group
//            has been changed if False, no changes have been executed.
//
Function RefreshProfileAccessGroups(Profile, UpdateAccessGroupsWithObsoleteSettings = False) Export
	
	AccessGroupUpdated = False;
	
	AccessTypesProfile = CommonUse.ObjectAttributeValue(Profile, "AccessKinds").Unload();
	IndexOf = AccessTypesProfile.Count() - 1;
	While IndexOf >= 0 Do
		String = AccessTypesProfile[IndexOf];
		
		Filter = New Structure("AccessKind", String.AccessKind);
		AccessTypeProperties = AccessManagementService.AccessTypeProperties(String.AccessKind);
		
		If AccessTypeProperties = Undefined Then
			AccessTypesProfile.Delete(String);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroups.Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	(AccessGroups.Profile = &Profile
	|			OR &Profile = VALUE(Catalog.AccessGroupsProfiles.Administrator)
	|				AND AccessGroups.Ref = VALUE(Catalog.AccessGroups.Administrators))";
	
	Query.SetParameter("Profile", Profile.Ref);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		// Check the necessity/possibility to update the access groups.
		AccessGroup = Selection.Ref.GetObject();
		
		If AccessGroup.Ref = Catalogs.AccessGroups.Administrators
		   AND AccessGroup.Profile <> Catalogs.AccessGroupsProfiles.Administrator Then
			// Setting the Administrator profile if is not specified.
			AccessGroup.Profile = Catalogs.AccessGroupsProfiles.Administrator;
		EndIf;
		
		// Check of the access kinds content.
		ContentOfAccessKindsChanged = False;
		AreAccessKindsForDeletionWithSpecifiedAccessValues = False;
		If AccessGroup.AccessKinds.Count() <> AccessTypesProfile.FindRows(New Structure("Preset", False)).Count() Then
			ContentOfAccessKindsChanged = True;
		Else
			For Each AccessKindRow IN AccessGroup.AccessKinds Do
				If AccessTypesProfile.FindRows(New Structure("AccessKind, Preset", AccessKindRow.AccessKind, False)).Count() = 0 Then
					ContentOfAccessKindsChanged = True;
					If AccessGroup.AccessValues.Find(AccessKindRow.AccessKind, "AccessKind") <> Undefined Then
						AreAccessKindsForDeletionWithSpecifiedAccessValues = True;
					EndIf;
				EndIf;
			EndDo;
		EndIf;
		
		If ContentOfAccessKindsChanged
		   AND ( UpdateAccessGroupsWithObsoleteSettings
		       OR Not AreAccessKindsForDeletionWithSpecifiedAccessValues ) Then
			// Access group update.
			// 1. Deletion of the unnecessary access kinds and access values (if any).
			CurrentLineNumber = AccessGroup.AccessKinds.Count()-1;
			While CurrentLineNumber >= 0 Do
				CurrentAccessType = AccessGroup.AccessKinds[CurrentLineNumber].AccessKind;
				If AccessTypesProfile.FindRows(New Structure("AccessKind, Preset", CurrentAccessType, False)).Count() = 0 Then
					AccessKindValueRows = AccessGroup.AccessValues.FindRows(New Structure("AccessKind", CurrentAccessType));
					For Each RowOfValue IN AccessKindValueRows Do
						AccessGroup.AccessValues.Delete(RowOfValue);
					EndDo;
					AccessGroup.AccessKinds.Delete(CurrentLineNumber);
				EndIf;
				CurrentLineNumber = CurrentLineNumber - 1;
			EndDo;
			// 2. Adding new kinds of access (if any).
			For Each AccessKindRow IN AccessTypesProfile Do
				If Not AccessKindRow.Preset 
				   AND AccessGroup.AccessKinds.Find(AccessKindRow.AccessKind, "AccessKind") = Undefined Then
					
					NewRow = AccessGroup.AccessKinds.Add();
					NewRow.AccessKind   = AccessKindRow.AccessKind;
					NewRow.AllAllowed = AccessKindRow.AllAllowed;
				EndIf;
			EndDo;
		EndIf;
		
		If AccessGroup.Modified() Then
			LockDataForEdit(AccessGroup.Ref, AccessGroup.DataVersion);
			AccessGroup.AdditionalProperties.Insert("DoNotUpdateUsersRoles");
			AccessGroup.Write();
			AccessGroupUpdated = True;
			UnlockDataForEdit(AccessGroup.Ref);
		EndIf;
	EndDo;
	
	Return AccessGroupUpdated;
	
EndFunction

// Returns a reference to the parent group of the personal access groups.
//  If the parent is not found, it will be created.
//
// Parameters:
//  DoNotCreate  - Boolean if set True, parent will not
//                 be automatically created and the function returns Undefined if the parent is not found.
//
// Returns:
//  CatalogRef.AccessGroups
//
Function ParentOfPersonalAccessGroups(Val DoNotCreate = False, ItemsGroupDescription = Undefined) Export
	
	SetPrivilegedMode(True);
	
	ItemsGroupDescription = NStr("en = 'Personal access groups'");
	
	Query = New Query;
	Query.SetParameter("ItemsGroupDescription", ItemsGroupDescription);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Description LIKE &ItemsGroupDescription
	|	AND AccessGroups.IsFolder";
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		GroupOfItems = Selection.Ref;
	ElsIf DoNotCreate Then
		GroupOfItems = Undefined;
	Else
		GroupOfItemsObject = Catalogs.AccessGroups.CreateFolder();
		GroupOfItemsObject.Description = ItemsGroupDescription;
		GroupOfItemsObject.Write();
		GroupOfItems = GroupOfItemsObject.Ref;
	EndIf;
	
	Return GroupOfItems;
	
EndFunction

// Only for internal use.
Procedure RestoreContentOfFoldersAccessAdministrators(DataItem, SendBack) Export
	
	If DataItem.PredefinedDataName <> "Administrators" Then
		Return;
	EndIf;
	
	DataItem.Users.Clear();
	
	Query = New Query;
	Query.SetParameter("PredefinedDataName", "Administrators");
	Query.Text =
	"SELECT DISTINCT
	|	AccessGroupsUsers.User
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|WHERE
	|	AccessGroupsUsers.Ref.PredefinedDataName = &PredefinedDataName";
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If DataItem.Users.Find(Selection.User, "User") = Undefined Then
			DataItem.Users.Add().User = Selection.User;
		EndIf;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Info base update.

Procedure FillProfileFoldersAccessAdministrators() Export
	
	Object = Administrators.GetObject();
	If Object.Profile <> Catalogs.AccessGroupsProfiles.Administrator Then
		Object.Profile = Catalogs.AccessGroupsProfiles.Administrator;
		InfobaseUpdate.WriteData(Object);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf