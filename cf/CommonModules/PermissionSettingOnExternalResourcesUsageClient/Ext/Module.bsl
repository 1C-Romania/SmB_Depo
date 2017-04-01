////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Server procedures and functions of common use:
// - Management of permissions in the security profiles of current IB.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Start client applications.
//

// Running on the interactive beginning of user work with data area or in local mode.
// Called after the complete OnStart actions.
// Used to connect wait handlers that should not be called on interactive actions before and during the system start.
//
Procedure AfterSystemOperationStart() Export
	
	If StandardSubsystemsClientReUse.ClientWorkParametersOnStart().ShowPermissionsSetupAssistant Then
		
		If StandardSubsystemsClientReUse.ClientWorkParametersOnStart().ValidatePermissionToUseExternalResourcesApplication Then
			
			AfterPermissionsToUseExternalResourcesApplicationCheck(
				StandardSubsystemsClientReUse.ClientWorkParametersOnStart().PermissionToUseExternalResourcesApplicationCheck);
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Application of permissions requests to use the external resources.
//

// Applies permissions changes in the security profiles in the cluster servers by the script.
//
// Parameters:
//  OperationKinds - Structure that describes the enumeration values OperationsAdministrationSecurityProfiles:
//                   * Key - String - name of
//                   enumeration values, * Value - EnumRef.OperationsAdministrationSecurityProfiles,
//  PermissionsApplicationScript - Array(Structure) - changes application script
//    of permissions to use security profiles in the cluster servers. Array values are
//    structure with the following fields:
//                   * Operation - EnumRef.OperationsAdministrationSecurityProfiles - operation
//                      that is
//                   required to be run, * Profile - String, name
//                   of the security profile, * Permissions - Structure - description of the
//                      security
//  profile properties, see ClusterAdministrationClientServer.SecurityProfileProperties(), ClusterAdministrationParameters - Structure - Cluster administration server parameters,
//    see
//  ClusterAdministrationClientServer.ParametersAdministrationCluster(), InformationBaseAdministrationParameters - Structure - information database
//    administration parameters, see ClusterAdministrationClientServer.ClusterInformationDatabaseAdministrationOptions().
//
Procedure ApplyChangesPermissionsInSecurityProfilesOnServerCluster(Val OperationKinds, Val ScriptApplicationPermissions, Val ClusterAdministrationParameters, Val InformationBaseAdministrationParameters = Undefined) Export
	
	If ClusterAdministrationParameters.ConnectionType = "COM" Then
		CommonUseClient.RegisterCOMConnector(False);
	EndIf;
	
	InfobaseAdministrationParametersRequired = (InformationBaseAdministrationParameters <> Undefined);
	
	ClusterAdministrationClientServer.CheckAdministrationParameters(
		ClusterAdministrationParameters,
		InformationBaseAdministrationParameters,
		True,
		InfobaseAdministrationParametersRequired);
	
	For Each ScriptItem IN ScriptApplicationPermissions Do
		
		If ScriptItem.Operation = OperationKinds.Creating Then
			
			If ClusterAdministrationClientServer.SecurityProfileExists(ClusterAdministrationParameters, ScriptItem.Profile) Then
				
				CommonUseClientServer.MessageToUser(
					StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Security profile %1 already exists in the servers cluster. Profile security settings will replaced...';ru='Профиль безопасности %1 уже присутствует в кластере серверов. Настройки в профиле безопасности будут замещены...'"), ScriptItem.Profile));
				
				ClusterAdministrationClientServer.SetSecurityProfileProperties(ClusterAdministrationParameters, ScriptItem.permissions);
				
			Else
				
				ClusterAdministrationClientServer.CreateSecurityProfile(ClusterAdministrationParameters, ScriptItem.permissions);
				
			EndIf;
			
		ElsIf ScriptItem.Operation = OperationKinds.Purpose Then
			
			ClusterAdministrationClientServer.SetInformationBaseSecurityProfile(ClusterAdministrationParameters, InformationBaseAdministrationParameters, ScriptItem.Profile);
			
		ElsIf ScriptItem.Operation = OperationKinds.Update Then
			
			ClusterAdministrationClientServer.SetSecurityProfileProperties(ClusterAdministrationParameters, ScriptItem.permissions);
			
		ElsIf ScriptItem.Operation = OperationKinds.Delete Then
			
			If ClusterAdministrationClientServer.SecurityProfileExists(ClusterAdministrationParameters, ScriptItem.Profile) Then
				
				ClusterAdministrationClientServer.DeleteSecurityProfile(ClusterAdministrationParameters, ScriptItem.Profile);
				
			Else
				
				CommonUseClientServer.MessageToUser(
					StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Security profile %1 do not exists in cluster servers. Perhaps the security profile was deleted previously...';ru='Профиль безопасности %1 отсутствует в кластере серверов. Возможно, профиль безопасности был удален ранее...'"), ScriptItem.Profile));
				
			EndIf;
			
		ElsIf ScriptItem.Operation = OperationKinds.DeleteDestination Then
			
			ClusterAdministrationClientServer.SetInformationBaseSecurityProfile(ClusterAdministrationParameters, InformationBaseAdministrationParameters, "");
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Logic of transition between operations of assistant settings
// permissions to use external resources.
//

// Runs assistant settings permissions to use service resources.
//
// Parameters:
//  IDs - Array(UUID) - requests identifiers to use
//    external resources for application of
//  which assistant is called OwnerForm - ManagedForm or Undefined - form to which the assistant
//                  opens in
//  pseudomodal mode ClosingAlert - NotifyDescription or Undefined - description an alert, processing
//    of which should be run
//  after assistant work is completed, ConnectMode - Boolean - checkbox for calling assistant on completion of use
//    infobase for
//  enabling security profiles, DisablingMode - Boolean - checkbox for calling assistant on completion of
//                             use infobase for
//  disabling security profiles, RecoveryMode - Boolean - checkbox for calling assistant for recovering security profiles
//    in servers cluster (by current infobase data),
//
// result of the operation
// is opening forms Processor.PermissionForExternalResourcesUseSettings.Form.PermissionsRequestInitialisation,
// for which notifications of closing description procedure
// is set AfterPermissionsForExternalResourcesUseRequestInitialization().
//
Procedure BeginInitializationPermissionsRequestToUseExternalResources(
		Val IDs,
		Val OwnerForm,
		Val ClosingAlert,
		Val ConnectMode = False,
		Val DisconnectMode = False,
		Val RecoveryMode = False) Export
	
	If ConnectMode OR ShowPermissionsSetupAssistant() Then
		
		Status = PermissionsToUseExternalResourcesRequestState();
		Status.QueryIDs = IDs;
		Status.NotifyDescription = ClosingAlert;
		Status.OwnerForm = OwnerForm;
		Status.ConnectMode = ConnectMode;
		Status.DisconnectMode = DisconnectMode;
		Status.RecoveryMode = RecoveryMode;
		
		FormParameters = New Structure();
		FormParameters.Insert("IDs", IDs);
		FormParameters.Insert("ConnectMode", Status.ConnectMode);
		FormParameters.Insert("DisconnectMode", Status.DisconnectMode);
		FormParameters.Insert("RecoveryMode", Status.RecoveryMode);
		
		NotifyDescription = New NotifyDescription(
			"AfterPermissionsForExternalResourcesUseRequestInitialization",
			PermissionSettingOnExternalResourcesUsageClient,
			Status);
		
		OpenForm(
			"DataProcessor.PermissionSettingsForExternalResourcesUse.Form.PermissionRequestInitialization",
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
	
EndProcedure

// Runs transition to settings permissions in the security profiles.
//
// Parameters:
//  Result - DialogReturnCode - result from running previous operation of permissions
//                                   to use external resources application assistant (used values - OK
//  and cancel), Status - Structure describing the state
//              assistant permissions setting (see PermissionsToUseExternalResourcesRequestState))).
//
// Result of the peration is opening form.
// "DataProcessor.PermissionForExternalResourcesUseSettings.FormNastrojkaRazrešenijNaIspolzovanieVnešnihResursov
// "as
// for that notifications of closing description Procedure PosleNastrojkiRazrešenijNaIspolzovanieVnešnihResursov or abort the preinstalled works assistant.
//
Procedure AfterPermissionsForExternalResourcesUseRequestInitialization(Result, Status) Export
	
	If TypeOf(Result) = Type("Structure") AND Result.ReturnCode = DialogReturnCode.OK Then
		
		InitializationStatus = GetFromTempStorage(Result.StorageAddressStates);
		
		If InitializationStatus.PermissionsApplicationRequired Then
			
			Status.StorageAddress = InitializationStatus.StorageAddress;
			
			FormParameters = New Structure();
			FormParameters.Insert("StorageAddress", Status.StorageAddress);
			FormParameters.Insert("RecoveryMode", Status.RecoveryMode);
			FormParameters.Insert("CheckMode", Status.CheckMode);
			
			NotifyDescription = New NotifyDescription(
				"AfterPermissionsSettingToUseExternalResources",
				PermissionSettingOnExternalResourcesUsageClient,
				Status);
			
			OpenForm(
				"DataProcessor.PermissionSettingsForExternalResourcesUse.Form.PermissionSettingsForExternalResourcesUse",
				FormParameters,
				Status.OwnerForm,
				,
				,
				,
				NotifyDescription,
				FormWindowOpeningMode.LockWholeInterface
			);
			
		Else
			
			// Requested permissions are redundant, you do not need to make changes
			// in security profiles settings in the servers cluster.
			CompletePermissionsSettingOnUseExternalResourcesAsynchronously(Status.NotifyDescription);
			
		EndIf;
		
	Else
		
		PermissionSettingOnExternalResourcesUsageServerCall.CancelExternalResourcesUsageQueries(
			Status.QueryIDs);
		BreakPermissionsSettingOnUseExternalResourcesAsynchronously(Status.NotifyDescription);
		
	EndIf;
	
EndProcedure

// Runs transition to the waiting for the application of security servers cluster profile settings.
//
// Parameters:
//  Result - DialogReturnCode - result from running previous operation of permissions
//                                   to use external resources application assistant (used values - OK, Skip and Cancel).
//                                   Value Skip is used if security profiles  settings
//                                   have not been changed, but requests to use external resources should
//                                   be considered successfully applied (for example if the use of
//                                   all requested external resources were already granted
//  previously), Status - Structure - describing the status of
//                          the permissions settings assistant (see PermissionsToUseExternalResourcesRequestState))).
//
// Result of the peration
// is opening form
// Processing.PermissionForExternalResourcesUseSettings.FormZaveršenieZaprosaRazrešenij "as for that notifications of closing description"
// Procedure PosleZaveršeniâZaprosaRazrešenijNaIspolzovanieVnešnihResursov or abort the preinstalled works assistant.
//
Procedure AfterPermissionsSettingToUseExternalResources(Result, Status) Export
	
	If Result = DialogReturnCode.OK OR Result = DialogReturnCode.Ignore Then
		
		PlanPermissionsApplyCheckAfterOwnerFormClosure(
			Status.OwnerForm,
			Status.QueryIDs);
		
		FormParameters = New Structure();
		FormParameters.Insert("StorageAddress", Status.StorageAddress);
		FormParameters.Insert("RecoveryMode", Status.RecoveryMode);
		
		If Result = DialogReturnCode.OK Then
			FormParameters.Insert("Duration", ChangesApplyWaitingDuration());
		Else
			FormParameters.Insert("Duration", 0);
		EndIf;
		
		NotifyDescription = New NotifyDescription(
			"AfterCompletingPermissionsQueryForExternalResourcesUsing",
			PermissionSettingOnExternalResourcesUsageClient,
			Status);
		
		OpenForm(
			"DataProcessor.PermissionSettingsForExternalResourcesUse.Form.EndPermissionsRequest",
			FormParameters,
			ThisObject,
			,
			,
			,
			NotifyDescription,
			FormWindowOpeningMode.LockWholeInterface
		);
		
	Else
		
		PermissionSettingOnExternalResourcesUsageServerCall.CancelExternalResourcesUsageQueries(
			Status.QueryIDs);
		BreakPermissionsSettingOnUseExternalResourcesAsynchronously(Status.NotifyDescription);
		
	EndIf;
	
EndProcedure

// Completes the work of assistant of applying permissions to use external resources.
//
// Parameters:
//  Result - DialogReturnCode - result from running previous operation of permissions
//                                   to use external resources application assistant (used values - OK
//  and cancel), Status - Structure describing the state
//              assistant permissions setting (see PermissionsToUseExternalResourcesRequestState))).
//
// The result of the operation is the processor of alerting that was initially
// passed from form. For this form the assistant was opened in the pseudo-modal mode.
//
Procedure AfterCompletingPermissionsQueryForExternalResourcesUsing(Result, Status) Export
	
	If Result = DialogReturnCode.OK Then
		
		ShowUserNotification(NStr("en='Permissions setting';ru='Настройка разрешений'"),,
			NStr("en='Security profiles settings in the servers cluster are changed.';ru='Внесены изменения в настройки профилей безопасности в кластере серверов.'"));
		
		CompletePermissionsSettingOnUseExternalResourcesAsynchronously(Status.NotifyDescription);
		
	Else
		
		PermissionSettingOnExternalResourcesUsageServerCall.CancelExternalResourcesUsageQueries(
			Status.QueryIDs);
		BreakPermissionsSettingOnUseExternalResourcesAsynchronously(Status.NotifyDescription);
		
	EndIf;
	
EndProcedure

// Asynchronously (towards the code from which the assistant was
// called) processes the description of the alert that was initially passed from the form.
// For this form the assistant was opened in the pseudo-modal mode returning the code of return OK.
//
// Parameters:
//  NotifyDescription - AlertDescription which was transferred from the calling code.
//
Procedure CompletePermissionsSettingOnUseExternalResourcesAsynchronously(Val NotifyDescription)
	
	ParameterName = "StandardSubsystems.AlertOnQueriesToUseExternalResources";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters[ParameterName] = NotifyDescription;
	
	AttachIdleHandler("CompletePermissionsOnExternalResourcesUseConfiguration", 0.1, True);
	
EndProcedure

// Asynchronously (towards the code from which the assistant was
// called) processes the description of the alert that was initially passed from the form.
// For this form the assistant was opened in the pseudo-modal mode returning the code of return Cancel.
//
// Parameters:
//  NotifyDescription - AlertDescription which was transferred from the calling code.
//
Procedure BreakPermissionsSettingOnUseExternalResourcesAsynchronously(Val NotifyDescription)
	
	ParameterName = "StandardSubsystems.AlertOnQueriesToUseExternalResources";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters[ParameterName] = NotifyDescription;
	
	AttachIdleHandler("BreakPermissionsOnExternalResourcesUseConfiguration", 0.1, True);
	
EndProcedure

// It asynchronously (relative to the code from which the Assistant was called) processes the alert description that was initially transferred from the form for which the assistant was opened in pseudomodal mode.
//
// Parameters:
//  ReturnCode - DialogReturnCode.
//
Procedure CompletePermissionsOnExternalResourcesUseConfigurationSynchronously(Val ReturnCode) Export
	
	ClosingAlert = ApplicationParameters["StandardSubsystems.AlertOnQueriesToUseExternalResources"];
	ApplicationParameters["StandardSubsystems.AlertOnQueriesToUseExternalResources"] = Undefined;
	If ClosingAlert <> Undefined Then
		ExecuteNotifyProcessing(ClosingAlert, ReturnCode);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Logic of the assistant call of setting to use
// external resources for checking of operations completion within which the
// permissions requests to use external resources were applied earlier.
//

// Plans (using value replacement of the OnCloseNotifyDescription form
// property) the call of the assistant for checking the operation completion after closing the form from which the assistant was called.
//
// Parameters:
//  OwnerForm - ManagedForm or Undefined - form after closing of which
//    you need to check operations completion within which permissions requests to use
//    external resources
//  were applied earlier, QueriesIdentifier - Array(UUID) - identifiers of
//    permissions request to use external resources that were applied within the operations and completion of which is being checked.
//
// Result of this procedure is a procedure call.
// CheckPermissionsApplyAfterOwnerFormClosure()
// after you close the form for which the assistant of setting to use external resources was opened in the pseudo-modal mode.
//
Procedure PlanPermissionsApplyCheckAfterOwnerFormClosure(FormOwner, QueryIDs) Export
	
	If TypeOf(FormOwner) = Type("ManagedForm") Then
		
		SourceAlertDescription = FormOwner.OnCloseNotifyDescription;
		If SourceAlertDescription <> Undefined Then
			
			If SourceAlertDescription.Module = PermissionSettingOnExternalResourcesUsageClient
					AND SourceAlertDescription.ProcedureName = "CheckPermissionsApplyAfterFormOwnerClosure" Then
				Return;
			EndIf;
			
		EndIf;
		
		Status = CheckingStateApplyPermissionsAfterOwnerFormClosure();
		Status.NotifyDescription = SourceAlertDescription;
		
		PermissionsApplyCheckAlertDescription = New NotifyDescription(
			"CheckPermissionsApplyAfterFormOwnerClosure",
			PermissionSettingOnExternalResourcesUsageClient,
			Status);
		
		FormOwner.OnCloseNotifyDescription = PermissionsApplyCheckAlertDescription;
		
	EndIf;
	
EndProcedure

// Launches the assistant in the mode of operation completion check within
// which requests to use external resources were applied earlier.
//
// Parameters:
//  Result - Custom, result of the form closing for which the assistant
//    of settings to use external resources was opened in the pseudo-modal mode. It is not used in the
//    body of the procedure, the parameter is required for assigning the procedure as a description of alert about closing the forms.
//  Status - Structure - describes a state of
//    the operation completion check (see CheckStateApplyPermissionsAfterOwnerFormClosure()).
//
// This procedure results in the launch of assistant of permission
// setting to use external resources in the operation completion check mode. Within this
// operation, the permissions to use external resources were applied earlier (with the normal
// execution of all operations). When the assistant work is complete, the processor of an alert description will be called in the function of which the procedure will be set.
// AfterPermissionsCheckAfterOwnerFormClosure().
//
Procedure CheckPermissionsApplyAfterFormOwnerClosure(Result, Status) Export
	
	OriginalOnCloseNotifyDescription = Status.NotifyDescription;
	If OriginalOnCloseNotifyDescription <> Undefined Then
		ExecuteNotifyProcessing(OriginalOnCloseNotifyDescription, Result);
	EndIf;
	
	Checking = PermissionSettingOnExternalResourcesUsageServerCall.CheckPermissionsToUseExternalResources();
	AfterPermissionsToUseExternalResourcesApplicationCheck(Checking);
	
EndProcedure

// Handles checking of requests to use external resources application.
//
// Parameters:
//  Checking - Structure - state checking the application
//                         of permissions to use external resources (for more details see the result returned by the function.
//                         PermissionForExternalResourcesUseSettingsServerCall.
//                         CheckPermissionsToUseExternalResources().
//
Procedure AfterPermissionsToUseExternalResourcesApplicationCheck(Val Checking)
	
	If Not Checking.CheckResult Then
		
		ApplicationState = PermissionsToUseExternalResourcesRequestState();
		
		ApplicationState.QueryIDs = Checking.QueryIDs;
		ApplicationState.StorageAddress = Checking.TemporaryStorageAddressStates;
		ApplicationState.CheckMode = True;
		
		Result = New Structure();
		Result.Insert("ReturnCode", DialogReturnCode.OK);
		Result.Insert("StorageAddressStates", Checking.TemporaryStorageAddressStates);
		
		AfterPermissionsForExternalResourcesUseRequestInitialization(
			Result, ApplicationState);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Call assistant settings permissions for the use
// of external resources in special modes.
//

// Calls assistant settings permissions for the use of
// external resources in mode that enables the use of the security profiles for infobase.
//
// Parameters:
//  OwnerForm - ManagedForm - the form that shall be blocked until
//  the end of the permissions application, ClosingAlert - NotifyDescription - which will be called if the permissions are successfully granted.
//
Procedure StartEnablingUsingSecurityProfiles(OwnerForm, ClosingAlert = Undefined) Export
	
	BeginInitializationPermissionsRequestToUseExternalResources(
		New Array(), OwnerForm, ClosingAlert, True, False, False);
	
EndProcedure

// Calls the assistant settings permissions for the use of
// external resources in mode that disables the use of the security profiles for Infobase.
//
// Parameters:
//  OwnerForm - ManagedForm - the form that shall be blocked until
//  the end of the permissions application, ClosingAlert - NotifyDescription - which will be called if the permissions are successfully granted.
//
Procedure StartDisablingSecurityProfilesUse(OwnerForm, ClosingAlert = Undefined) Export
	
	BeginInitializationPermissionsRequestToUseExternalResources(
		New Array(), OwnerForm, ClosingAlert, False, True, False);
	
EndProcedure

// Calls the assistant settings permissions for the use of
// external resources in the mode that restores the settings
// security profiles servers cluster according to the current state infobase.
//
// Parameters:
//  OwnerForm - ManagedForm - the form that shall be blocked until
//  the end of the permissions application, ClosingAlert - NotifyDescription - which will be called if the permissions are successfully granted.
//
Procedure StartSecurityProfilesRestoration(OwnerForm, ClosingAlert = Undefined) Export
	
	BeginInitializationPermissionsRequestToUseExternalResources(
		New Array(), OwnerForm, ClosingAlert, False, False, True);
	
EndProcedure

// Checks if displaying assistant settings of permissions
//  to use external (relative to cluster servers 1C:Enterprise) resources is needed.
//
// Return value: Boolean.
//
Function ShowPermissionsSetupAssistant()
	
	Return StandardSubsystemsClientReUse.ClientWorkParametersOnStart().ShowPermissionsSetupAssistant;
	
EndFunction

// Assistant for structure that is used for work
// states storage assistant settings permissions to use external resources.
//
// Return value: Structure - description fields see the function body.
//
Function PermissionsToUseExternalResourcesRequestState()
	
	Result = New Structure();
	
	// IDs of requests to use external resources that
	// should be provided - Array(UUID).
	Result.Insert("QueryIDs", New Array());
	
	// original description of the alert that must be called
	// after the permissions request will apply.
	Result.Insert("NotifyDescription", Undefined);
	
	// Address in the temporary store which has the data transferred between forms.
	Result.Insert("StorageAddress", "");
	
	// Form from which originally application of requests to
	// use external resources was initialized.
	Result.Insert("OwnerForm");
	
	// Enabling mode - sign of enabling use security profiles.
	Result.Insert("ConnectMode", False);
	
	// Disabling mode - sign of disabling use of perform security profiles.
	Result.Insert("DisconnectMode", False);
	
	// Recovery mode - sign of restoration profiles security
	// permissions (permissions request runs "from scratch" ignoring the
	// saved information about previously granted permissions.
	Result.Insert("RecoveryMode", False);
	
	// Check mode - sign of operation completion within which new
	// permissions in the security profiles were provided (e.g. in the process of
	// recording the catalog item permissions in the security profiles were granted and further catalog item record was not completed).
	Result.Insert("CheckMode", False);
	
	Return Result;
	
EndFunction

// Assistant of structure that is used for storage
// check of operation completion state, within which permissions requests to use external resources were applied.
//
// Return value: Structure - description fields see the function body.
//
Function CheckingStateApplyPermissionsAfterOwnerFormClosure()
	
	Result = New Structure();
	
	// Address in the temporary store which has the data transferred between forms.
	Result.Insert("StorageAddress", Undefined);
	
	// Original description of notification owner form which
	// must be called after checking permissions application.
	Result.Insert("NotifyDescription", Undefined);
	
	Return Result;
	
EndFunction

// Brings back the duration of the application of
// changes in security profile settings in cluster servers idle.
//
// Returns - Number - duration of the idle of the changes application (in seconds).
//
Function ChangesApplyWaitingDuration()
	
	Return 20; // interval through which rphost requests current profile security settings from rmngr.
	
EndFunction

#EndRegion