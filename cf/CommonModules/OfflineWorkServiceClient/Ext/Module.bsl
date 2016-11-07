////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data exchange in the service model".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Handlers of conditional calls from SSL.

// Checks the offline workplace settings and notifies if there is an error.
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If ClientParameters.Property("RestartAfterOfflineWorkplaceSettings") Then
		Parameters.Cancel = True;
		Parameters.Restart = True;
		Return;
	EndIf;
	
	If Not ClientParameters.Property("OfflineWorkplaceSettingsError") Then
		Return;
	EndIf;
	
	Parameters.Cancel = True;
	Parameters.InteractiveDataProcessor = New NotifyDescription(
		"InteractiveProcessingOnOfflineWorkplaceSettingsCheck", ThisObject);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Notification handlers.

// Warns about an offline workplace settings error.
Procedure InteractiveProcessingOnOfflineWorkplaceSettingsCheck(Parameters, NotSpecified) Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	StandardSubsystemsClient.ShowWarningAndContinue(
		Parameters, ClientParameters.OfflineWorkplaceSettingsError);
	
EndProcedure

#EndRegion
