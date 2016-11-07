////////////////////////////////////////////////////////////////////////////////
// Subsystem "Users".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Checks if the infobase object is used as
// the authorization object of any external user except the specified external user (if any).
//
Function AuthorizationObjectInUse(Val AuthorizationObjectRef,
                                      Val CurrentExternalUserRef,
                                      FoundExternalUser = Undefined,
                                      CanAddExternalUser = False,
                                      ErrorText = "") Export
	
	Return UsersService.AuthorizationObjectInUse(
				AuthorizationObjectRef,
				CurrentExternalUserRef,
				FoundExternalUser,
				CanAddExternalUser,
				ErrorText);
	
EndFunction

#EndRegion
