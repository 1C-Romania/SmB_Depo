////////////////////////////////////////////////////////////////////////////////
// The "Check the update receipt legality" sybsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// UseModality

// Asks the user for a dialog
// with confirmation concerning legality of the received update and shuts
// system down if update is received illegally (see the SystemShutdown parameter).
//
// Parameters:
//  StopSystemOperation - Boolean - ыhut the system down
//                                    if user specifies that the update is received illegally.
//
// Returns:
//   Boolean - True if check is complete
//            successfully (user confirmed that the update is received legally).
//
Function CheckSoftwareUpdateLegality(StopSystemOperation = False) Export
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().ThisIsBasicConfigurationVersion Then
		Return True;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowWarningAboutRestart", StopSystemOperation);
	FormParameters.Insert("ProgrammOpening", True);
	
	Return OpenFormModal("DataProcessor.SoftwareUpdateLegality.Form", FormParameters);
	
EndFunction

// End ModalityUse

// Asks the user for a dialog
// with confirmation concerning legality of the received update and shuts
// system down if update is received illegally (see the SystemShutdown parameter).
//
// Parameters:
//  StopSystemOperation - Boolean - ыhut the system down
//                                    if user specifies that the update is received illegally.
//
// Returns:
//   Boolean - True if check is complete
//            successfully (user confirmed that the update is received legally).
//
Procedure ShowUpdateReceiptLealityCheck(Notification, StopSystemOperation = False) Export
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().ThisIsBasicConfigurationVersion Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowWarningAboutRestart", StopSystemOperation);
	FormParameters.Insert("ProgrammOpening", True);
	
	OpenForm("DataProcessor.SoftwareUpdateLegality.Form", FormParameters,,,,, Notification);
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// Check if the update is received legally during the application start.
// It should be called before the infobase update.
//
Procedure ValidateLegalityOfGetUpdateWhenYouRun(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If Not ClientParameters.Property("CheckSoftwareUpdateLegality") Then
		Return;
	EndIf;
	
	Parameters.InteractiveDataProcessor = New NotifyDescription(
		"OnlineProcessUpdateReceiptLealityCheck", ThisObject);
	
EndProcedure

// Only for internal use. Continue the CheckGetUpdateOnStartLegality procedure.
Procedure OnlineProcessUpdateReceiptLealityCheck(Parameters, NotSpecified) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("ProgrammOpening", True);
	FormParameters.Insert("ShowWarningAboutRestart", True);
	FormParameters.Insert("SkipRestart", True);
	
	OpenForm("DataProcessor.SoftwareUpdateLegality.Form", FormParameters, , , , ,
		New NotifyDescription("AfterUpdateReceiptLealityCheckFormClosingOnStart",
			ThisObject, Parameters));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Only for internal use. Continue the CheckGetUpdateOnStartLegality procedure.
Procedure AfterUpdateReceiptLealityCheckFormClosingOnStart(Result, Parameters) Export
	
	If Result <> True Then
		Parameters.Cancel = True;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

#EndRegion
