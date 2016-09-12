////////////////////////////////////////////////////////////////////////////////
// Subsystem "Users".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the current user or
// current external user, the one who has logged on.
//  It is recommended to be used in the code that supports work in both cases.
//
// Returns:
//  - CatalogRef.Users, CatalogRef.ExternalUsers -
// 
Function AuthorizedUser() Export
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	SetPrivilegedMode(True);
	
	Return ?(ValueIsFilled(SessionParameters.CurrentUser),
	          SessionParameters.CurrentUser,
	          SessionParameters.CurrentExternalUser);
#Else
	Return StandardSubsystemsClientReUse.ClientWorkParametersOnStart().AuthorizedUser;
#EndIf
	
EndFunction

// Returns the current user.
//  It is recommended to be used in the code that does not support work with external users.
//
//  If the external user has logged on, the exception will be called.
//
// Returns:
//  CatalogRef.Users
//
Function CurrentUser() Export
	
	AuthorizedUser = AuthorizedUser();
	
	If TypeOf(AuthorizedUser) <> Type("CatalogRef.Users") Then
		Raise
			NStr("en='Unable to get"
"the current user in the external user session.';ru='Невозможно"
"получить текущего пользователя в сеансе внешнего пользователя.'");
	EndIf;
	
	Return AuthorizedUser;
	
EndFunction

// Returns the current external user.
//  It is recommended to be used in the code that supports only external users.
//
//  If it is not the external user who logged on, then the exception will be called.
//
// Returns:
//  CatalogRef.ExternalUsers
//
Function CurrentExternalUser() Export
	
	AuthorizedUser = AuthorizedUser();
	
	If TypeOf(AuthorizedUser) <> Type("CatalogRef.ExternalUsers") Then
		Raise
			NStr("en='Unable to get the"
"current external user in the user session.';ru='Невозможно"
"получить текущего внешнего пользователя в сеансе пользователя.'");
	EndIf;
	
	Return AuthorizedUser;
	
EndFunction

// Returns True if the external user has logged on.
//
// Returns:
//  Boolean - True if the external user has logged on.
//
Function IsExternalUserSession() Export
	
	Return TypeOf(AuthorizedUser())
	      = Type("CatalogRef.ExternalUsers");
	
EndFunction

#EndRegion
