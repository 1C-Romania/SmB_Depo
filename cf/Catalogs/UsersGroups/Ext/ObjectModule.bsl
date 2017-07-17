#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// SERVICE VARIABLES

Var OldParent; // Group parent value before
                      // change to use in event handler OnWrite.

Var UsersGroupsOldStaff; // User group user
                                       // content before change to use
                                       // in event handler OnWrite.

Var IsNew; // Shows that a new object was written.
                // It is used in event handler OnWrite.

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	CheckedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Parent use checking.
	If Parent = Catalogs.UsersGroups.AllUsers Then
		CommonUseClientServer.AddUserError(Errors,
			"Object.Parent",
			NStr("en='Predefined group ""All users"" cannot be a parent group.';ru='Предопределенная группа ""Все пользователи"" не может быть родителем.'"),
			"");
	EndIf;
	
	// Checking blank and duplicate users.
	CheckedObjectAttributes.Add("Content.User");
	
	For Each CurrentRow IN Content Do;
		LineNumber = Content.IndexOf(CurrentRow);
		
		// Value fill checking.
		If Not ValueIsFilled(CurrentRow.User) Then
			CommonUseClientServer.AddUserError(Errors,
				"Object.Content[%1].User",
				NStr("en='User is not selected.';ru='Пользователь не выбран.'"),
				"Object.Content",
				LineNumber,
				NStr("en='User in line %1 is not selected.';ru='Пользователь в строке %1 не выбран.'"));
			Continue;
		EndIf;
		
		// Checking existence of duplicate values.
		FoundValues = Content.FindRows(New Structure("User", CurrentRow.User));
		If FoundValues.Count() > 1 Then
			CommonUseClientServer.AddUserError(Errors,
				"Object.Content[%1].User",
				NStr("en='User is repeated.';ru='Пользователь повторяется.'"),
				"Object.Content",
				LineNumber,
				NStr("en='User in line %1 is repeated.';ru='Пользователь в строке %1 повторяется.'"));
		EndIf;
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
	CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, CheckedObjectAttributes);
	
EndProcedure

// Block invalid operation with predefined group "All users".
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	IsNew = IsNew();
	
	If Ref = Catalogs.UsersGroups.AllUsers Then
		If Not Parent.IsEmpty() Then
			Raise
				NStr("en='Predefined
		|group ""All users"" can be in the root only.';ru='Предопределенная
		|группа ""Все пользователи"" может быть только в корне.'");
		EndIf;
		If Content.Count() > 0 Then
			Raise
				NStr("en='Adding users to
		|the folder ""All users"" is not supported.';ru='Добавление пользователей в группу
		|""Все пользователи"" не поддерживается.'");
		EndIf;
	Else
		If Parent = Catalogs.UsersGroups.AllUsers Then
			Raise
				NStr("en = 'Predefined
				           |group ""All users"" can't be a parent.'");
		EndIf;
		
		OldParent = ?(
			Ref.IsEmpty(),
			Undefined,
			CommonUse.ObjectAttributeValue(Ref, "Parent"));
			
		If ValueIsFilled(Ref)
		   AND Ref <> Catalogs.UsersGroups.AllUsers Then
			
			UsersGroupsOldStaff =
				CommonUse.ObjectAttributeValue(Ref, "Content").Unload();
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ParticipantsOfChange = New Map;
	ChangedGroups   = New Map;
	
	If Ref <> Catalogs.UsersGroups.AllUsers Then
		
		StaffChange = UsersService.ColumnValuesDifferences(
			"User",
			Content.Unload(),
			UsersGroupsOldStaff);
		
		UsersService.UpdateUsersGroupsContents(
			Ref, StaffChange, ParticipantsOfChange, ChangedGroups);
		
		If OldParent <> Parent Then
			
			If ValueIsFilled(Parent) Then
				UsersService.UpdateUsersGroupsContents(
					Parent, , ParticipantsOfChange, ChangedGroups);
			EndIf;
			
			If ValueIsFilled(OldParent) Then
				UsersService.UpdateUsersGroupsContents(
					OldParent, , ParticipantsOfChange, ChangedGroups);
			EndIf;
		EndIf;
		
		UsersService.RefreshUsabilityRateOfUsersGroups(
			Ref, ParticipantsOfChange, ChangedGroups);
	EndIf;
	
	UsersService.AfterUserGroupStavesUpdating(
		ParticipantsOfChange, ChangedGroups);
	
	UsersService.AfterUserOrGroupChangeAdding(Ref, IsNew);
	
EndProcedure

#EndRegion

#EndIf