////////////////////////////////////////////////////////////////////////////////
// Subsystem "Basic functionality in service model".
// Server procedures and functions of common use:
// - Support security profiles
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

Function HandleRequestsOnExternalResourcesUse(Val QueryIDs) Export
	
	Result = New Structure("PermissionsApplicationRequired, PackageIdentifier");
	
	Manager = WorkInSafeModeServiceSaaS.PermissionsApplicationManager(
		QueryIDs);
	
	If Manager.PermissionsApplicationRequiredOnServerCluster() Then
		
		Result.PermissionsApplicationRequired = True;
		
		Result.PackageIdentifier = WorkInSafeModeServiceSaaS.AppliedRequestsPackage(
			Manager.WriteStatusInXMLString());
		
	Else
		
		Result.PermissionsApplicationRequired = False;
		Manager.FinishRequestsApplicationOnExternalResourcesUse();
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion