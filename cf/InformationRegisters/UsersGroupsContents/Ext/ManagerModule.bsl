#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure updates all register data.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if there is a record,
//               True is set, otherwise, it is not changed.
//
Procedure RefreshDataRegister(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.Users");
	LockItem.Mode = DataLockMode.Shared;
	LockItem = Block.Add("Catalog.UsersGroups");
	LockItem.Mode = DataLockMode.Shared;
	LockItem = Block.Add("Catalog.ExternalUsers");
	LockItem.Mode = DataLockMode.Shared;
	LockItem = Block.Add("Catalog.ExternalUsersGroups");
	LockItem.Mode = DataLockMode.Shared;
	LockItem = Block.Add("InformationRegister.UsersGroupsContentss");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		// Update user links.
		ParticipantsOfChange = New Map;
		ChangedGroups   = New Map;
		
		Selection = Catalogs.UsersGroups.Select();
		While Selection.Next() Do
			UsersService.UpdateUsersGroupsContents(
				Selection.Ref, , ParticipantsOfChange, ChangedGroups);
		EndDo;
		
		// Update external user links.
		Selection = Catalogs.ExternalUsersGroups.Select();
		While Selection.Next() Do
			UsersService.UpdateExternalUsersGroupsStaves(
				Selection.Ref, , ParticipantsOfChange, ChangedGroups);
		EndDo;
		
		If ParticipantsOfChange.Count() > 0
		 OR ChangedGroups.Count() > 0 Then
		
			HasChanges = True;
			
			UsersService.AfterUserGroupStavesUpdating(
				ParticipantsOfChange, ChangedGroups);
		EndIf;
		
		UsersService.RefreshRolesOfExternalUsers();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf