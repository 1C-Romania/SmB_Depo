////////////////////////////////////////////////////////////////////////////////
// Subsystem "Users".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the flag showing the usage
// of external users in the application (the value of the UseExternalUsers functional option).
//
// Returns:
//  Boolean - if True, external users are included.
//
Function UseExternalUsers() Export
	
	Return GetFunctionalOption("UseExternalUsers");
	
EndFunction

// See the function with the same name in the UsersClientServer common module.
Function CurrentExternalUser() Export
	
	Return UsersClientServer.CurrentExternalUser();
	
EndFunction

// Returns a reference to the authorization object of the external user, that is received from the infobase.
// Authorization object - this is the ref to infobase
// object that is used for connection with the external user, for example, the counterparty, individual etc.
//
// Parameters:
//  ExternalUser - Undefined - the current external user is used.
//               - CatalogRef.ExternalUsers - specified external user.
//
// Returns:
//  Refs - authorization object of one of the types, that were specified in types description of the property.
//           "Metadata.Catalogs.ExternalUsers.Attributes.AuthorizationObjects.Type".
//
Function GetExternalUserAuthorizationObject(ExternalUser = Undefined) Export
	
	If ExternalUser = Undefined Then
		ExternalUser = UsersClientServer.CurrentExternalUser();
	EndIf;
	
	AuthorizationObject = CommonUse.ObjectAttributesValues(ExternalUser, "AuthorizationObject").AuthorizationObject;
	
	If ValueIsFilled(AuthorizationObject) Then
		If UsersService.AuthorizationObjectInUse(AuthorizationObject, ExternalUser) Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Database error:"
"Authorization object ""%1"" (%2)"
"is set for several external users.';ru='Ошибка в базе данных:"
"Объект авторизации ""%1"" (%2)"
"установлен для нескольких внешних пользователей.'"),
				AuthorizationObject,
				TypeOf(AuthorizationObject));
		EndIf;
	Else
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Database error:"
"For the ""%1"" external user the authorization object is not set.';ru='Ошибка"
"в базе данных: Для внешнего пользователя ""%1"" не задан объект авторизации.'"),
			ExternalUser);
	EndIf;
	
	Return AuthorizationObject;
	
EndFunction

#EndRegion
