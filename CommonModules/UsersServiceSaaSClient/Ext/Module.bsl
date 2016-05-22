///////////////////////////////////////////////////////////////////////////////////
// Users in the service model subsystem.
// 
///////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Opens service user password input form.
//
// Parameters:
//  ContinuationProcessor      - NotificationDescription to be processed after getting the password.
//  OwnerForm                  - ManagedForm that requests a password.
//  ServiceUserPassword        - String - current service user password.
//
Procedure RequestPasswordForAuthenticationInService(ContinuationProcessor, OwnerForm, ServiceUserPassword) Export
	
	If ServiceUserPassword = Undefined Then
		OpenForm("CommonForm.AuthenticationInService", , OwnerForm, , , , ContinuationProcessor);
	Else
		ExecuteNotifyProcessing(ContinuationProcessor, ServiceUserPassword);
	EndIf;
	
EndProcedure

#EndRegion
