Function GetReservedUsersStructure() Export
	
	Return UsersAtServerCachedClosed.GetReservedUsersStructure();
	
EndFunction	

Function IsUserApproved(Val UserName) Export
	
	ReservedUsersStructure = UsersAtClientAtServerCached.GetReservedUsersStructure();
	Try
		UserApproved = NOT ReservedUsersStructure.Property(TrimAll(UserName));
	Except
		UserApproved = True;
	EndTry;	
	
	Return UserApproved;
	
EndFunction	