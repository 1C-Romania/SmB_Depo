#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// SERVICE VARIABLES

Var OldParent; // Group parent value before
                      // change to use in event handler OnWrite.

Var OldCompositionOfExternalUsersGroup; // Content of external
                                              // users of the external user
                                              // group before change for the use in OnWrite event handler.

Var FormerExternalUserGroupRolesSet; // Content of the
                                                   // roles of external user group before
                                                   // change for the use in OnWrite event handler.

Var FormerValueAllAuhorizationObjects; // Value of
                                           // attribute AllAuthorizationObjects before change for
                                           // the use in OnWrite event handler.

Var IsNew; // Shows that a new object was written.
                // It is used in event handler OnWrite.

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If AdditionalProperties.Property("CheckedObjectAttributes") Then
		CheckedObjectAttributes = AdditionalProperties.CheckedObjectAttributes;
	Else
		CheckedObjectAttributes = New Array;
	EndIf;
	
	Errors = Undefined;
	
	// Parent use checking.
	If Parent = Catalogs.ExternalUsersGroups.AllExternalUsers Then
		CommonUseClientServer.AddUserError(Errors,
			"Object.Parent",
			NStr("en='Predefined group ""All external users"" can not be a parent.';ru='Предопределенная группа ""Все внешние пользователи"" не может быть родителем.'"),
			"");
	EndIf;
	
	// Check of the unfilled and repetitive external users.
	CheckedObjectAttributes.Add("Content.ExternalUser");
	
	For Each CurrentRow IN Content Do
		LineNumber = Content.IndexOf(CurrentRow);
		
		// Value fill checking.
		If Not ValueIsFilled(CurrentRow.ExternalUser) Then
			CommonUseClientServer.AddUserError(Errors,
				"Object.Content[%1].ExternalUser",
				NStr("en='External user is not selected.';ru='Внешний пользователь не выбран.'"),
				"Object.Content",
				LineNumber,
				NStr("en='External user in the row %1 is not selected.';ru='Внешний пользователь в строке %1 не выбран.'"));
			Continue;
		EndIf;
		
		// Checking existence of duplicate values.
		FoundValues = Content.FindRows(New Structure("ExternalUser", CurrentRow.ExternalUser));
		If FoundValues.Count() > 1 Then
			CommonUseClientServer.AddUserError(Errors,
				"Object.Content[%1].ExternalUser",
				NStr("en='External user is repeated.';ru='Внешний пользователь повторяется.'"),
				"Object.Content",
				LineNumber,
				NStr("en='External user in the %1 row is repeated.';ru='Внешний пользователь в строке %1 повторяется.'"));
		EndIf;
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
	CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, CheckedObjectAttributes);
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not UsersService.BanEditOfRoles() Then
		QueryResult = CommonUse.ObjectAttributeValue(Ref, "Roles");
		If TypeOf(QueryResult) = Type("QueryResult") Then
			FormerExternalUserGroupRolesSet = QueryResult.Unload();
		Else
			FormerExternalUserGroupRolesSet = Roles.Unload(New Array);
		EndIf;
	EndIf;
	
	IsNew = IsNew();
	
	If Ref = Catalogs.ExternalUsersGroups.AllExternalUsers Then
		
		TypeOfAuthorizationObjects = Undefined;
		AllAuthorizationObjects  = False;
		
		If Not Parent.IsEmpty() Then
			Raise
				NStr("en='Predefined group ""All external users"" can not be moved.';ru='Предопределенная группа ""Все внешние пользователи"" не может быть перемещена.'");
		EndIf;
		If Content.Count() > 0 Then
			Raise
				NStr("en='Adding participants to predetermined group ""All external users"" is banned.';ru='Добавление участников в предопределенную группу ""Все внешние пользователи"" запрещено.'");
		EndIf;
	Else
		If Parent = Catalogs.ExternalUsersGroups.AllExternalUsers Then
			Raise
				NStr("en='Cannot add a subgroup to predetermined group ""All external users"".';ru='Невозможно добавить подгруппу к предопределенной группе ""Все внешние пользователи"".'");
		ElsIf Parent.AllAuthorizationObjects Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Cannot add a subgroup to group %1 because it includes all users.';ru='Невозможно добавить подгруппу к группе ""%1"", так как в число ее участников входят все пользователи.'"), Parent);
		EndIf;
		
		If TypeOfAuthorizationObjects = Undefined Then
			AllAuthorizationObjects = False;
			
		ElsIf AllAuthorizationObjects
		        AND ValueIsFilled(Parent) Then
			
			Raise
				NStr("en='Cannot move a group to a number of participants that includes all users.';ru='Невозможно переместить группу, в число участников которой входят все пользователи.'");
		EndIf;
		
		// Check for uniqueness of a group of all authorization objects of the specified type.
		If AllAuthorizationObjects Then
			
			Query = New Query;
			Query.SetParameter("Ref", Ref);
			Query.SetParameter("TypeOfAuthorizationObjects", TypeOfAuthorizationObjects);
			Query.Text =
			"SELECT
			|	PRESENTATION(ExternalUsersGroups.Ref) AS RefPresentation
			|FROM
			|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
			|WHERE
			|	ExternalUsersGroups.Ref <> &Ref
			|	AND ExternalUsersGroups.TypeOfAuthorizationObjects = &TypeOfAuthorizationObjects
			|	AND ExternalUsersGroups.AllAuthorizationObjects";
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
			
				Selection = QueryResult.Select();
				Selection.Next();
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Group ""%1"" already exists and includes all users of the ""%2"" kind.';ru='Уже существует группа ""%1"", в число участников которой входят все пользователи вида ""%2"".'"),
					Selection.RefPresentation,
					TypeOfAuthorizationObjects.Metadata().Synonym);
			EndIf;
		EndIf;
		
		// Checking the matches of authorization object
		// types with the parent (valid if the type of parent is not specified).
		If ValueIsFilled(Parent) Then
			
			ParentAuthorizationObjectType = CommonUse.ObjectAttributeValue(
				Parent, "TypeOfAuthorizationObjects");
			
			If ParentAuthorizationObjectType <> Undefined
			   AND ParentAuthorizationObjectType <> TypeOfAuthorizationObjects Then
				
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Kind of participants shall be
		|""%1"" as in the upstream group of external users ""%2"".';ru='Вид участников группы должен
		|быть ""%1"", как у вышестоящей группы внешних пользователей ""%2"".'"),
					ParentAuthorizationObjectType.Metadata().Synonym,
					Parent);
			EndIf;
		EndIf;
		
		// If in the external user group the type of participants
		// is set to "All users of specified type", check the existence of subordinate groups.
		If AllAuthorizationObjects
			AND ValueIsFilled(Ref) Then
			Query = New Query;
			Query.SetParameter("Ref", Ref);
			Query.Text =
			"SELECT
			|	PRESENTATION(ExternalUsersGroups.Ref) AS RefPresentation
			|FROM
			|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
			|WHERE
			|	ExternalUsersGroups.Parent = &Ref";
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Cannot change a kind
		|of participants of group ""%1"" as it has subgroups.';ru='Невозможно изменить
		|вид участников группы ""%1"", так как у нее имеются подгруппы.'"),
					Description);
			EndIf;
			
		EndIf;
		
		// Check that during the change
		// of types of authorization objects there are no subordinate items of other type (type clearing is possible).
		If TypeOfAuthorizationObjects <> Undefined
		   AND ValueIsFilled(Ref) Then
			
			Query = New Query;
			Query.SetParameter("Ref", Ref);
			Query.SetParameter("TypeOfAuthorizationObjects", TypeOfAuthorizationObjects);
			Query.Text =
			"SELECT
			|	PRESENTATION(ExternalUsersGroups.Ref) AS RefPresentation,
			|	ExternalUsersGroups.TypeOfAuthorizationObjects
			|FROM
			|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
			|WHERE
			|	ExternalUsersGroups.Parent = &Ref
			|	AND ExternalUsersGroups.TypeOfAuthorizationObjects <> &TypeOfAuthorizationObjects";
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				
				Selection = QueryResult.Select();
				Selection.Next();
				
				If Selection.TypeOfAuthorizationObjects = Undefined Then
					OtherAuthorizationObjectTypePresentation = NStr("en='Any user';ru='Любой пользователь'");
				Else
					OtherAuthorizationObjectTypePresentation =
						Selection.TypeOfAuthorizationObjects.Metadata().Synonym;
				EndIf;
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Cannot change a kind
		|of participants of group ""%1"" as it has subgroup ""%2"" with another kind of participants ""%3"".';ru='Невозможно
		|изменить вид участников группы ""%1"", так как у нее имеется подгруппа ""%2"" с другим видом участников ""%3"".'"),
					Description,
					Selection.RefPresentation,
					OtherAuthorizationObjectTypePresentation);
			EndIf;
		EndIf;
		
		OldValues = CommonUse.ObjectAttributesValues(
			Ref, "AllAuthorizationObjects, Parent");
		
		OldParent                      = OldValues.Parent;
		FormerValueAllAuhorizationObjects = OldValues.AllAuthorizationObjects;
		
		If ValueIsFilled(Ref)
		   AND Ref <> Catalogs.ExternalUsersGroups.AllExternalUsers Then
			
			QueryResult = CommonUse.ObjectAttributeValue(Ref, "Content");
			If TypeOf(QueryResult) = Type("QueryResult") Then
				OldCompositionOfExternalUsersGroup = QueryResult.Unload();
			Else
				OldCompositionOfExternalUsersGroup = Content.Unload(New Array);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If UsersService.BanEditOfRoles() Then
		IsExternalUserGroupRoleContentChanged = False;
		
	Else
		IsExternalUserGroupRoleContentChanged =
			UsersService.ColumnValuesDifferences(
				"Role",
				Roles.Unload(),
				FormerExternalUserGroupRolesSet).Count() <> 0;
	EndIf;
	
	ParticipantsOfChange = New Map;
	ChangedGroups   = New Map;
	
	If Ref <> Catalogs.ExternalUsersGroups.AllExternalUsers Then
		
		If AllAuthorizationObjects
		 OR FormerValueAllAuhorizationObjects = True Then
			
			UsersService.UpdateExternalUsersGroupsStaves(
				Ref, , ParticipantsOfChange, ChangedGroups);
		Else
			StaffChange = UsersService.ColumnValuesDifferences(
				"ExternalUser",
				Content.Unload(),
				OldCompositionOfExternalUsersGroup);
			
			UsersService.UpdateExternalUsersGroupsStaves(
				Ref, StaffChange, ParticipantsOfChange, ChangedGroups);
			
			If OldParent <> Parent Then
				
				If ValueIsFilled(Parent) Then
					UsersService.UpdateExternalUsersGroupsStaves(
						Parent, , ParticipantsOfChange, ChangedGroups);
				EndIf;
				
				If ValueIsFilled(OldParent) Then
					UsersService.UpdateExternalUsersGroupsStaves(
						OldParent, , ParticipantsOfChange, ChangedGroups);
				EndIf;
			EndIf;
		EndIf;
		
		UsersService.RefreshUsabilityRateOfUsersGroups(
			Ref, ParticipantsOfChange, ChangedGroups);
	EndIf;
	
	If IsExternalUserGroupRoleContentChanged Then
		UsersService.RefreshRolesOfExternalUsers(Ref);
	EndIf;
	
	UsersService.AfterExternalUsersGroupsStavesUpdating(
		ParticipantsOfChange, ChangedGroups);
	
	UsersService.AfterUserOrGroupChangeAdding(Ref, IsNew);
	
EndProcedure

#EndRegion

#EndIf