////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Server procedures and functions of common use:
// - Support of security profiles.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Applies the requests for use of the external resources previously saved in the infobase.
//
// Parameters:
//  IDs - Array(UUID) - identifiers of the
//  requests which shall be applied, FormOwner - ManagedForm - the form that shall be blocked until
//  the end of the permissions application, ClosingAlert - NotifyDescription - which will be called if the permissions are successfully granted.
//
Procedure ApplyQueriesOnExternalResourcesUse(Val IDs, OwnerForm, ClosingAlert) Export
	
	StandardProcessing = True;
	
	EventHandlers = CommonUseClient.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\WhenRequestsForExternalResourcesUseAreConfirmed");
	
	For Each Handler IN EventHandlers Do
		
		Handler.Module.WhenRequestsForExternalResourcesUseAreConfirmed(IDs, OwnerForm, ClosingAlert, StandardProcessing);
		
		If Not StandardProcessing Then
			Break;
		EndIf;
		
	EndDo;
	
	If StandardProcessing Then
		
		WorkInSafeModeClientOverridable.WhenRequestsForExternalResourcesUseAreConfirmed(
			IDs, OwnerForm, ClosingAlert, StandardProcessing);
		
	EndIf;
	
	If StandardProcessing Then
		
		PermissionSettingOnExternalResourcesUsageClient.BeginInitializationPermissionsRequestToUseExternalResources(
			IDs, OwnerForm, ClosingAlert);
		
	EndIf;
	
EndProcedure

// Opens the dialog to setup the use
// mode of the security profiles in current infobase.
//
Procedure OpenDialogForSecurityProfilesUseSetup() Export
	
	OpenForm(
		"DataProcessor.PermissionSettingsForExternalResourcesUse.Form.SecurityProfilesUseSettings",
		,
		,
		"DataProcessor.PermissionSettingsForExternalResourcesUse.Form.SecurityProfilesUseSettings",
		,
		,
		,
		FormWindowOpeningMode.Independent);
	
EndProcedure

#EndRegion
