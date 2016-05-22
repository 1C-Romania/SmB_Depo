////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Server procedures and functions of common use:
// - Support of security profiles.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Called on the request confirmation to use external resources.
// 
// Parameters:
//  IDs - Array (UUID), request identifiers
//  that shall be applied, FormOwner - ManagedForm, a form that should be blocked
//  until the end of the permissions application, ClosingAlert - AlertDetails, which will be called when permissions are successfully got.
//  StandardProcessing - Boolean, a flag showing that standard permissions processor is applied to use external resources (connection to a server agent through COM-connection or administration server with querying the cluster connection parameters from the current user). Can be set to the
//    value False inside the event handler, in this case the standard processing of the session end will not be executed.
//
Procedure WhenRequestsForExternalResourcesUseAreConfirmed(Val QueryIDs, OwnerForm, ClosingAlert, StandardProcessing) Export
	
	
	
EndProcedure

#EndRegion