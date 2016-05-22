////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Server procedures and functions of common use:
// - Management of permissions in the security profiles of current IB.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Performs asynchronous processing of alert of permissions settings assistant
// forms closing for the use of external resources on calling through idle handler connection.
// As a result DialogReturnCode value is passed to the handler.OK.
//
// Procedure is not intended for direct call.
//
Procedure CompletePermissionsOnExternalResourcesUseConfiguration() Export
	
	PermissionSettingOnExternalResourcesUsageClient.CompletePermissionsOnExternalResourcesUseConfigurationSynchronously(DialogReturnCode.OK);
	
EndProcedure

// Performs asynchronous processing of alert of permissions settings assistant
// forms closing for the use of external resources on calling through idle handler connection.
// As a result DialogReturnCode value is passed to the handler.Cancel.
//
// Procedure is not intended for direct call.
//
Procedure BreakPermissionsOnExternalResourcesUseConfiguration() Export
	
	PermissionSettingOnExternalResourcesUsageClient.CompletePermissionsOnExternalResourcesUseConfigurationSynchronously(DialogReturnCode.Cancel);
	
EndProcedure

#EndRegion