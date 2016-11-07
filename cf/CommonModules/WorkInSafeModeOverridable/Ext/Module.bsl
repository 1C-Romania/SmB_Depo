////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Server procedures and functions of common use:
// - Support of security profiles.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Appears when the possibility of security profiles use is checked.
//
// Parameters:
//  Cancel - Boolean - if the configuration is not
//   adapted to the security profiles use, then the
//   value of the parameter in this procedure shall be set equal to True.
//
Procedure WhenCheckingSecurityProfilesUsePossibility(Cancel) Export
	
	
	
EndProcedure

// Appears when the possibilty of security profile setup is checked.
//
// Parameters:
//  Cancel - Boolean. If the use of security profiles is not available for infobase -
//    value of this parameter shall be set to True.
//
Procedure WhenCheckingPossibilityToSetupSecurityProfiles(Cancel) Export
	
	
	
EndProcedure

// Appears when you enable the use of the infobase for security profiles.
//
Procedure OnSwitchUsingSecurityProfiles() Export
	
	
	
EndProcedure

// Fills out a list of queries for external permissions that must be provided when creating an infobase or updating a application.
//
// Parameters:
//  PermissionsQueries - Array - list of values returned by the function.
//                      WorkInSafeMode.QueryOnExternalResourcesUse().
//
Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	// OnlineUserSupport
	OnlineUserSupport.WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries);
	// End OnlineUserSupport
	
EndProcedure

// Appears when a request for permissions to use external resources is created.
//
// Parameters:
//  ProgramModule - AnyRef - ref to infobase object
//    representing the software module for which
//  permissions are requested, Owner - AnyRef - ref to infobase object that
//    represents the object-owner of requested
//  permissions for external resources use, ReplacementMode - Boolean - the flag for a replacement of
//  the permissions previously granted by owners, AddedPermissions - Array(XDTOObject) - array of
//  added permissions, DeletedPermissions - Array(XDTOObject) - array of
//  deleted permissions, StandardProcessing - Boolean, flag for the standard processing of
//    request creation for external resources use.
//  Result - UUID - request identifier (if inside
//    the handler the value of parameter StandardProcessing is set to False).
//
Procedure WhenPermissionsForExternalResourcesUseAreRequested(Val ProgramModule, Val Owner, Val ReplacementMode, Val PermissionsToBeAdded, Val PermissionsToBeDeleted, StandardProcessing, Result) Export
	
	
	
EndProcedure

// Appears when creation of a security profile is requested.
//
// Parameters:
//  ProgramModule - AnyRef - ref to infobase object
//    representing the software module for which
//  permissions are requested, StandardProcessing - Boolean, flag of
//  standard processing, Result - UUID - request identifier (if inside
//    the handler the value of parameter StandardProcessing is set to False).
//
Procedure WhenSecurityProfileCreationIsRequested(Val ProgramModule, StandardProcessing, Result) Export
	
	
	
EndProcedure

// Appears when security profile deletion is requested.
//
// Parameters:
//  ProgramModule - AnyRef - ref to infobase object
//    representing the software module for which
//  permissions are requested, StandardProcessing - Boolean, flag of
//  standard processing, Result - UUID - request identifier (if inside
//    the handler the value of parameter StandardProcessing is set to False).
//
Procedure WhenSecurityProfileDeletionIsRequested(Val ProgramModule, StandardProcessing, Result) Export
	
	
	
EndProcedure

// Appears when the external module is connected. IN the body of the
// handler procedure you can change the safe mode in which the connection will be installed.
//
// Parameters:
//  ExternalModule - AnyRef - ref to infobase object
//    that represents
//  the external connected module, SafeMode - DefinedType.SafeMode - safe mode in which
//    the external module will be connected to the infobase. Can be changed inside this procedure.
//
Procedure WhenConnectingExternalModule(Val ExternalModule, SafeMode) Export
	
	
	
EndProcedure

#EndRegion