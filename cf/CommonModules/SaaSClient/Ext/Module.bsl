///////////////////////////////////////////////////////////////////////////////////
// OperationSaaSClient.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Appears before the beginning of user interactive operation with data area.
// Corresponds to the event BeforeSystemOperationStart of application modules.
//
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If ClientParameters.Property("DataAreaBlocked") Then
		Parameters.Cancel = True;
		Parameters.InteractiveDataProcessor = New NotifyDescription(
			"ShowWarningAndContinue",
			StandardSubsystemsClient.ThisObject,
			ClientParameters.DataAreaBlocked);
		Return;
	EndIf;
	
EndProcedure

#EndRegion
