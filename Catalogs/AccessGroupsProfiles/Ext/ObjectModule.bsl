#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var ProfileOldRoles; // Profile roles before changing
                         // to use in the OnWrite event handler.

Var OldDeletionMark; // Deletion mark of access groups profile
                             // before changing to use in the OnWrite event handler.

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	// Get profile old roles.
	QueryResult = CommonUse.ObjectAttributeValue(Ref, "Roles");
	If TypeOf(QueryResult) = Type("QueryResult") Then
		ProfileOldRoles = QueryResult.Unload();
	Else
		ProfileOldRoles = Roles.Unload(New Array);
	EndIf;

	OldDeletionMark = CommonUse.ObjectAttributeValue(
		Ref, "DeletionMark");
	
	If Ref = Catalogs.AccessGroupsProfiles.Administrator Then
		User = Undefined;
	Else
		// Check roles.
		LineNumber = Roles.Count() - 1;
		While LineNumber >= 0 Do
			If Upper(Roles[LineNumber].Role) = Upper("FullRights")
			 OR Upper(Roles[LineNumber].Role) = Upper("SystemAdministrator") Then
				
				Roles.Delete(LineNumber);
			EndIf;
			LineNumber = LineNumber - 1;
		EndDo;
	EndIf;
	
	If Not AdditionalProperties.Property("DoNotUpdateAttributeStandardProfileChanged") Then
		StandardProfileChanged =
			Catalogs.AccessGroupsProfiles.StandardProfileChanged(ThisObject);
	EndIf;
	
	InterfaceSimplified = AccessManagementService.SimplifiedInterfaceOfAccessRightsSettings();
	
	If InterfaceSimplified Then
		// Update name of this profile personal access groups (if any).
		Query = New Query;
		Query.SetParameter("Profile",      Ref);
		Query.SetParameter("Description", Description);
		Query.Text =
		"SELECT
		|	AccessGroups.Ref
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	AccessGroups.Profile = &Profile
		|	AND AccessGroups.User <> UNDEFINED
		|	AND AccessGroups.User <> VALUE(Catalog.Users.EmptyRef)
		|	AND AccessGroups.User <> VALUE(Catalog.ExternalUsers.EmptyRef)
		|	AND AccessGroups.Description <> &Description";
		ChangedAccessGroups = Query.Execute().Unload().UnloadColumn("Ref");
		If ChangedAccessGroups.Count() > 0 Then
			For Each AccessGroupRef IN ChangedAccessGroups Do
				PersonalAccessGroupObject = AccessGroupRef.GetObject();
				PersonalAccessGroupObject.Description = Description;
				PersonalAccessGroupObject.DataExchange.Load = True;
				PersonalAccessGroupObject.Write();
			EndDo;
			AdditionalProperties.Insert(
				"PersonalAccessGroupsWithRenewedDescription", ChangedAccessGroups);
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	CheckSuppliedDataUniqueness();
	
	MetadataObjects = UpdateUsersRolesAtProfileRolesChanging();
	
	// While setting deletion mark you should set deletion mark in profile access groups.
	If DeletionMark AND OldDeletionMark = False Then
		Query = New Query;
		Query.SetParameter("Profile", Ref);
		Query.Text =
		"SELECT
		|	AccessGroups.Ref
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	(NOT AccessGroups.DeletionMark)
		|	AND AccessGroups.Profile = &Profile";
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			LockDataForEdit(Selection.Ref);
			AccessGroupObject = Selection.Ref.GetObject();
			AccessGroupObject.DeletionMark = True;
			AccessGroupObject.Write();
		EndDo;
	EndIf;
	
	If AdditionalProperties.Property("RefreshProfileAccessGroups") Then
		Catalogs.AccessGroups.RefreshProfileAccessGroups(Ref, True);
	EndIf;
	
	// Update tables and values of access groups.
	Query = New Query;
	Query.SetParameter("Profile", Ref);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Profile = &Profile
	|	AND (NOT AccessGroups.IsFolder)";
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		ProfileAccessGroups = Query.Execute().Unload().UnloadColumn("Ref");
		
		InformationRegisters.AccessGroupsValues.RefreshDataRegister(ProfileAccessGroups);
		
		If MetadataObjects.Count() > 0 Then
			InformationRegisters.AccessGroupsTables.RefreshDataRegister(
				ProfileAccessGroups, MetadataObjects);
		EndIf;
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If IsFolder Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("CheckedObjectAttributes") Then
		CommonUse.DeleteUnverifiableAttributesFromArray(
			CheckedAttributes, AdditionalProperties.CheckedObjectAttributes);
	EndIf;
	
	CheckSuppliedDataUniqueness(True, Cancel);
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If IsFolder Then
		Return;
	EndIf;
	
	IDSuppliedData = Undefined;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

Function UpdateUsersRolesAtProfileRolesChanging()
	
	Query = New Query;
	Query.SetParameter("Profile", Ref);
	Query.SetParameter("ProfileOldRoles", ProfileOldRoles);
	Query.Text =
	"SELECT
	|	ProfileOldRoles.Role
	|INTO ProfileOldRoles
	|FROM
	|	&ProfileOldRoles AS ProfileOldRoles
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Data.Role
	|INTO ChangedRoles
	|FROM
	|	(SELECT
	|		ProfileOldRoles.Role AS Role,
	|		-1 AS RowChangeKind
	|	FROM
	|		ProfileOldRoles AS ProfileOldRoles
	|	
	|	UNION ALL
	|	
	|	SELECT DISTINCT
	|		ProfileNewRoles.Role,
	|		1
	|	FROM
	|		Catalog.AccessGroupsProfiles.Roles AS ProfileNewRoles
	|	WHERE
	|		ProfileNewRoles.Ref = &Profile) AS Data
	|
	|GROUP BY
	|	Data.Role
	|
	|HAVING
	|	SUM(Data.RowChangeKind) <> 0
	|
	|INDEX BY
	|	Data.Role";
	
	Query.Text = Query.Text + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|" +
	"SELECT DISTINCT
	|	RolesRights.MetadataObject
	|FROM
	|	InformationRegister.RolesRights AS RolesRights
	|		INNER JOIN ChangedRoles AS ChangedRoles
	|		ON RolesRights.Role = ChangedRoles.Role";
	
	QueryResults = Query.ExecuteBatch();
	
	If Not AdditionalProperties.Property("DoNotUpdateUsersRoles")
	   AND Not QueryResults[1].IsEmpty() Then
		
		Query.Text =
		"SELECT DISTINCT
		|	UsersGroupsContents.User
		|FROM
		|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
		|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
		|		ON UsersGroupsContents.UsersGroup = AccessGroupsUsers.User
		|			AND (AccessGroupsUsers.Ref.Profile = &Profile)";
		
		UsersForRolesUpdating =
			Query.Execute().Unload().UnloadColumn("User");
		
		AccessManagement.UpdateUsersRoles(UsersForRolesUpdating);
	EndIf;
	
	Return QueryResults[2].Unload().UnloadColumn("MetadataObject");
	
EndFunction

Procedure CheckSuppliedDataUniqueness(FillChecking = False, Cancel = False)
	
	// Check supplied data uniqueness
	If IDSuppliedData <> New UUID("00000000-0000-0000-0000-000000000000") Then
		SetPrivilegedMode(True);
		
		Query = New Query;
		Query.SetParameter("IDSuppliedData", IDSuppliedData);
		Query.Text =
		"SELECT
		|	AccessGroupsProfiles.Ref AS Ref,
		|	AccessGroupsProfiles.Description AS Description
		|FROM
		|	Catalog.AccessGroupsProfiles AS AccessGroupsProfiles
		|WHERE
		|	AccessGroupsProfiles.IDSuppliedData = &IDSuppliedData";
		
		Selection = Query.Execute().Select();
		If Selection.Count() > 1 Then
			
			BriefErrorDescription = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'An error occurred while writing profile ""%1"".
				           |Supplied profile already exists:'"),
				Description);
			
			DetailErrorDescription = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'An error occurred while writing profile ""%1"".
				           |Supplied data ID ""%2"" is already used in profile:'"),
				Description,
				String(IDSuppliedData));
			
			While Selection.Next() Do
				If Selection.Ref <> Ref Then
					
					BriefErrorDescription = BriefErrorDescription
						+ Chars.LF + """" + Selection.Description + """.";
					
					DetailErrorDescription = DetailErrorDescription
						+ Chars.LF + """" + Selection.Description + """ ("
						+ String(Selection.Ref.UUID())+ ")."
				EndIf;
			EndDo;
			
			If FillChecking Then
				CommonUseClientServer.MessageToUser(BriefErrorDescription,,,, Cancel);
			Else
				WriteLogEvent(
					NStr("en = 'Acces management. Violation of the supplied profile uniqueness'",
					     CommonUseClientServer.MainLanguageCode()),
					EventLogLevel.Error, , , DetailErrorDescription);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
