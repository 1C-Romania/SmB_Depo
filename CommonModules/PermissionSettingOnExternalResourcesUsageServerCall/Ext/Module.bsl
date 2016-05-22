////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Server procedures and functions of common use:
// - Management of permissions in the security profiles of current IB.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Checks the completion of operation of applying the permissions to use external resources.
// Used for diagnostics of the situations in which the settings of the servers cluster security profiles were changed, but the operation of changing the settings of permissions to use external resources was not completed.
//
// Returns - Structure:
//  CheckResult - Boolean - if False - then operation was not completed and it is required to prompt the user to undo changes in the servers cluster profile security settings, QueryIDs - Array(UUID) - array of identifiers of queries to use external resources, that should be applied to cancel the changes in the servers cluster security profile settings, TemporaryStorageAddress - String - address in the temporary storage, to which the state of permissions usage queries was placed, the permissions that should be applied to cancel the changes in the servers cluster security profile settings, TemporaryStoreStateAddress - String - address in the temporary storage, to which the internal state of processor was placed.
//                                      PermissionForExternalResourcesUseSettings.
//
Function CheckPermissionsToUseExternalResources() Export
	
	Return DataProcessors.PermissionSettingsForExternalResourcesUse.RunUsageCheckQueriesProcessor();
	
EndFunction

// Removes the queries to use external resource if the user rejected their usage.
//
// Parameters:
//  QueryIDs - Array(UUID) - array of identifiers of queries to use external resources.
//
Procedure CancelExternalResourcesUsageQueries(Val QueryIDs) Export
	
	InformationRegisters.PermissionQueriesOnUseExternalResources.DeleteQueries(QueryIDs);
	
EndProcedure

#EndRegion
