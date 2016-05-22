////////////////////////////////////////////////////////////////////////////////
// Subsystem "Basic functionality in service model".
// Server procedures and functions of common use:
// - Support security profiles
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Called on the request confirmation to use external resources.
// 
// Parameters:
//  IDs - Array (UUID), requests identifiers
//  that required to be applied, OwnerForm - ManagedForm, a form that should be blocked
//  until the end of the permissions application, ClosingAlert - AlertDetails, which will be called when permissions are successfully got.
//  StandardProcessing - Boolean, a flag showing that standard permissions processor is applied to use external resources (connection to a server agent through COM-connection or administration server with querying the cluster connection parameters from the current user). Can be set to the
//    value False inside the event handler, in this case the standard processing of the session end will not be executed.
//
Procedure WhenRequestsForExternalResourcesUseAreConfirmed(Val QueryIDs, OwnerForm, ClosingAlert, StandardProcessing) Export
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().DataSeparationEnabled Then
		
		BeginInitializationPermissionsRequestToUseExternalResources(QueryIDs, OwnerForm, ClosingAlert, False);
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

Procedure BeginInitializationPermissionsRequestToUseExternalResources(Val IDs, OwnerForm, ClosingAlert, CheckMode = False) Export
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().ShowPermissionsSetupAssistant Then
		
		ProcessingResult = PermissionSettingOnExternalResourcesSaaSServerCall.HandleRequestsOnExternalResourcesUse(
			IDs);
		
		If ProcessingResult.PermissionsApplicationRequired Then
			
			If StandardSubsystemsClientReUse.ClientWorkParameters().CanUseSeparatedData Then
				
				FormName = "DataProcessor.PermissionSettingsForExternalResourcesUseSaaS.Form.SubscriberAdministratorPermissionsRequest";
				
			Else
				
				FormName = "DataProcessor.PermissionSettingsForExternalResourcesUseSaaS.Form.ServiceAdministratorPermissionsRequest";
				
			EndIf;
			
			FormParameters = New Structure();
			FormParameters.Insert("PackageIdentifier", IDs);
			
			NotifyDescription = New NotifyDescription(
				"AfterPermissionsSettingToUseExternalResources",
				PermissionForExternalResourcesUseSettingsSaaSClient,
				FormParameters);
			
			OpenForm(
				FormName,
				FormParameters,
				OwnerForm,
				,
				,
				,
				NotifyDescription,
				FormWindowOpeningMode.LockWholeInterface
			);
			
		Else
			
			CompletePermissionsSettingOnUseExternalResourcesAsynchronously(ClosingAlert);
			
		EndIf;
		
	Else
		
		CompletePermissionsSettingOnUseExternalResourcesAsynchronously(ClosingAlert);
		
	EndIf;
	
EndProcedure

Procedure AfterPermissionsSettingToUseExternalResources(Result, Status) Export
	
	If Result = DialogReturnCode.OK Then
		
		CompletePermissionsSettingOnUseExternalResourcesAsynchronously(Status.NotifyDescription);
		
	Else
		
		BreakPermissionsSettingOnUseExternalResourcesAsynchronously(Status.NotifyDescription);
		
	EndIf;
	
EndProcedure

// It asynchronously (relative to code from which the Assistant was called) processes the alert description that was initially transferred from the form, for which the assistant was opened in pseudomodal mode, returning the OK return code.
//
// Parameters:
//  NotifyDescription - AlertDescription which was transferred from the calling code.
//
Procedure CompletePermissionsSettingOnUseExternalResourcesAsynchronously(Val NotifyDescription)
	
	ParameterName = "ServiceTechnology.AlertOnApplicationRequestsForUseOfExternalResources";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters[ParameterName] = NotifyDescription;
	AttachIdleHandler("CompletePermissionsOnExternalResourcesUseSaaSConfiguration", 0.1, True);
	
EndProcedure

// It asynchronously (relative to code from which the Assistant was called) processes the alert description that was initially transferred from the form, for which the assistant was opened in pseudomodal mode, returning the Cancel return code.
//
// Parameters:
//  NotifyDescription - AlertDescription which was transferred from the calling code.
//
Procedure BreakPermissionsSettingOnUseExternalResourcesAsynchronously(Val NotifyDescription)
	
	ParameterName = "ServiceTechnology.AlertOnApplicationRequestsForUseOfExternalResources";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters[ParameterName] = NotifyDescription;
	AttachIdleHandler("BreakPermissionsOnExternalResourcesUseSaaSConfiguration", 0.1, True);
	
EndProcedure

// It asynchronously (relative to the code from which the Assistant was called) processes the alert description that was initially transferred from the form for which the assistant was opened in pseudomodal mode.
//
// Parameters:
//  ReturnCode - DialogReturnCode.
//
Procedure CompletePermissionsOnExternalResourcesUseConfigurationSynchronously(Val ReturnCode) Export
	
	ClosingAlert = ApplicationParameters["ServiceTechnology.AlertOnApplicationRequestsForUseOfExternalResources"];
	ApplicationParameters["ServiceTechnology.AlertOnApplicationRequestsForUseOfExternalResources"] = Undefined;
	If ClosingAlert <> Undefined Then
		ExecuteNotifyProcessing(ClosingAlert, ReturnCode);
	EndIf;
	
EndProcedure

#EndRegion
 


