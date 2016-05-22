////////////////////////////////////////////////////////////////////////////////
// Subsystem "Basic functionality in service model".
// Server procedures and functions of common use:
// - Support security profiles
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Performs asynchronous processing of alert of permissions settings assistant
// forms closing for the use of external resources on calling through idle handler connection.
// As a result DialogReturnCode value is passed to the handler.OK.
//
// Procedure is not intended for direct call.
//
Procedure CompletePermissionsOnExternalResourcesUseSaaSConfiguration() Export
	
	PermissionForExternalResourcesUseSettingsSaaSClient.CompletePermissionsOnExternalResourcesUseConfigurationSynchronously(DialogReturnCode.OK);
	
EndProcedure

// Performs asynchronous processing of alert of permissions settings assistant
// forms closing for the use of external resources on calling through idle handler connection.
// As a result DialogReturnCode value is passed to the handler.OK.
//
// Procedure is not intended for direct call.
//
Procedure BreakPermissionsOnExternalResourcesUseSaaSConfiguration() Export
	
	PermissionForExternalResourcesUseSettingsSaaSClient.CompletePermissionsOnExternalResourcesUseConfigurationSynchronously(DialogReturnCode.Cancel);
	
EndProcedure

#EndRegion