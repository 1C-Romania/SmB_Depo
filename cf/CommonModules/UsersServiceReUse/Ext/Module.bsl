////////////////////////////////////////////////////////////////////////////////
// Subsystem "Users".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Includes saved parameters, used by the subsystem.
Function Parameters() Export
	
	SetPrivilegedMode(True);
	SavedParameters = StandardSubsystemsServer.ApplicationWorkParameters(
		"UsersWorkParameters");
	SetPrivilegedMode(False);
	
	StandardSubsystemsServer.CheckForUpdatesApplicationWorkParameters(
		"UsersWorkParameters",
		"UnavailableRolesByUserTypes,
		|AllRoles");
	
	ParameterPresentation = "";
	
	If Not SavedParameters.Property("UnavailableRolesByUserTypes") Then
		ParameterPresentation = NStr("en='Unavailable roles';ru='Недоступные роли'");
		
	ElsIf Not SavedParameters.Property("AllRoles") Then
		ParameterPresentation = NStr("en='All roles';ru='Все роли'");
		
	EndIf;
	
	If ValueIsFilled(ParameterPresentation) Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Information base updating error.
		|Users work parameter is
		|not filled: ""%1"".';ru='Ошибка обновления информационной базы.
		|Не заполнен параметр
		|работы пользователей: ""%1"".'")
			+ StandardSubsystemsServer.SpecificationOfErrorParametersWorkApplicationForDeveloper(),
			ParameterPresentation);
	EndIf;
	
	Return SavedParameters;
	
EndFunction

// Returns the tree of roles with or without subsystems.
//  If a role does not belong to any subsystem, it is added to "root".
// 
// Parameters:
//  BySubsystems - Boolean if False, all roles are added to "root".
// 
// Returns:
//  ValueTree with columns:
//    IsRole - Boolean
//    Name     - String - role     name or subsystem name.
//    Synonym - String - role synonym or subsystem synonym.
//
Function RolesTree(BySubsystems = True, Val UsersType = Undefined) Export
	
	If UsersType = Undefined Then
		UsersType = ?(CommonUseReUse.DataSeparationEnabled(), 
			Enums.UserTypes.DataAreaUser, 
			Enums.UserTypes.LocalApplicationUser);
	EndIf;
	
	Tree = New ValueTree;
	Tree.Columns.Add("IsRole", New TypeDescription("Boolean"));
	Tree.Columns.Add("Name",     New TypeDescription("String"));
	Tree.Columns.Add("Synonym", New TypeDescription("String", , New StringQualifiers(1000)));
	
	If BySubsystems Then
		FillSubsystemsAndRoles(Tree.Rows, , UsersType);
	EndIf;
	
	InaccessibleRoles = UsersService.InaccessibleRolesByUserTypes(UsersType);
	
	// Add roles that haven't been found.
	For Each Role IN Metadata.Roles Do
		
		If InaccessibleRoles.Get(Role.Name) <> Undefined
			OR Upper(Left(Role.Name, StrLen("Delete"))) = Upper("Delete")
			OR Upper(Left(Role.Name, StrLen("Profile"))) = Upper("Profile") Then
			
			Continue;
		EndIf;
		
		If Tree.Rows.FindRows(New Structure("IsRole, Name", True, Role.Name), True).Count() = 0 Then
			TreeRow = Tree.Rows.Add();
			TreeRow.IsRole       = True;
			TreeRow.Name           = Role.Name;
			TreeRow.Synonym       = ?(ValueIsFilled(Role.Synonym), Role.Synonym, Role.Name);
		EndIf;
	EndDo;
	
	Tree.Rows.Sort("IsRole Desc, Synonym Asc", True);
	
	Return Tree;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

Procedure FillSubsystemsAndRoles(TreeRowsCollection, Subsystems, UsersType)
	
	InaccessibleRoles = UsersService.InaccessibleRolesByUserTypes(UsersType);
	
	If Subsystems = Undefined Then
		Subsystems = Metadata.Subsystems;
	EndIf;
	
	For Each Subsystem IN Subsystems Do
		
		SubsystemDescription = TreeRowsCollection.Add();
		SubsystemDescription.Name           = Subsystem.Name;
		SubsystemDescription.Synonym       = ?(ValueIsFilled(Subsystem.Synonym), Subsystem.Synonym, Subsystem.Name);
		
		FillSubsystemsAndRoles(SubsystemDescription.Rows, Subsystem.Subsystems, UsersType);
		
		For Each Role IN Metadata.Roles Do
			If InaccessibleRoles.Get(Role) <> Undefined
				OR Upper(Left(Role.Name, StrLen("Delete"))) = Upper("Delete") Then
				
				Continue;
			EndIf;
			
			If Subsystem.Content.Contains(Role) Then
				RoleDescription = SubsystemDescription.Rows.Add();
				RoleDescription.IsRole       = True;
				RoleDescription.Name           = Role.Name;
				RoleDescription.Synonym       = ?(ValueIsFilled(Role.Synonym), Role.Synonym, Role.Name);
			EndIf;
		EndDo;
		
		If SubsystemDescription.Rows.FindRows(New Structure("IsRole", True), True).Count() = 0 Then
			TreeRowsCollection.Delete(SubsystemDescription);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
