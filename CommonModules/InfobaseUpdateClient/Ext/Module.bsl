////////////////////////////////////////////////////////////////////////////////
// IB version update subsystem
// Client procedures and functions for interactive update of the infobase.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// See description of parameter OnStartingClientApplication in the module.
// InformationBaseUpdateService in the description of function UpdateInformationBase.
//
Procedure RefreshDatabase(Parameters) Export
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If Not ClientWorkParameters.CanUseSeparatedData Then
		CloseUpdateProgressIndicationFormIfOpen(Parameters);
		Return;
	EndIf;
	
	If ClientWorkParameters.Property("InfobaseUpdateRequired") Then
		Parameters.InteractiveDataProcessor = New NotifyDescription(
			"StartInformationBaseUpdate", ThisObject);
	Else
		If ClientWorkParameters.Property("ImportDataExchangeMessage") Then
			Restart = False;
			InfobaseUpdateServiceServerCall.RunInfobaseUpdate(, True, Restart);
			If Restart Then
				Parameters.Cancel = True;
				Parameters.Restart = True;
			EndIf;
		EndIf;
		CloseUpdateProgressIndicationFormIfOpen(Parameters);
	EndIf;
	
EndProcedure

// For procedure UpdateInformationBase.
Procedure CloseUpdateProgressIndicationFormIfOpen(Parameters)
	
	If Parameters.Property("FormInfobaseUpdateProcessIndication") Then
		If Parameters.FormInfobaseUpdateProcessIndication.IsOpen() Then
			Parameters.FormInfobaseUpdateProcessIndication.StartClosing();
		EndIf;
		Parameters.Delete("FormInfobaseUpdateProcessIndication");
	EndIf;
	
EndProcedure

// Only for internal use. Continue procedure UpdateInformationBase.
Procedure StartInformationBaseUpdate(Parameters, ContinuationProcessor) Export
	
	If Parameters.Property("FormInfobaseUpdateProcessIndication") Then
		Form = Parameters.FormInfobaseUpdateProcessIndication;
	Else
		FormName = "DataProcessor.InfobaseUpdate.Form.InfobaseUpdateProcessIndication";
		
		Form = OpenForm(FormName,,,,,, New NotifyDescription(
			"AfterClosingFormIBUpdateProgressIndication", ThisObject, Parameters));
		
		Parameters.Insert("FormInfobaseUpdateProcessIndication", Form);
	EndIf;
	
	Form.RefreshDatabase();
	
EndProcedure

// Only for internal use. Continuation of procedure BeforeApplicationStart.
Procedure ImportRefreshApplicationWorkParameters(Parameters, NotSpecified) Export
	
	FormName = "DataProcessor.InfobaseUpdate.Form.InfobaseUpdateProcessIndication";
	
	Form = OpenForm(FormName,,,,,, New NotifyDescription(
		"AfterClosingFormIBUpdateProgressIndication", ThisObject, Parameters));
	
	Parameters.Insert("FormInfobaseUpdateProcessIndication", Form);
	
	Form.ImportRefreshApplicationWorkParameters(Parameters);
	
EndProcedure

// Only for internal use. Continue procedure UpdateInformationBase.
Procedure AfterClosingFormIBUpdateProgressIndication(Result, Parameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		Result = New Structure("Cancel, Restart", True, False);
	EndIf;
	
	If Result.Cancel Then
		Parameters.Cancel = True;
		If Result.Restart Then
			Parameters.Restart = True;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// If there are unshown descriptions of a change and
// the user did not disable the display - Open the form SystemChangesDescription.
//
Procedure ShowSystemChangesDescription()
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If ClientWorkParameters.ShowSystemChangesDescription Then
		
		FormParameters = New Structure;
		FormParameters.Insert("ShowOnlyChanges", True);
		
		OpenForm("CommonForm.SystemChangesDescription", FormParameters);
	EndIf;
	
EndProcedure

// Displays an alert to the user that delayed
// data processor is not completed.
//
Procedure NotifyPendingHandlersNotImplemented() Export
	
	ShowUserNotification(
		NStr("en = 'Work in the application is temporarily limited'"),
		ProcessorsURL(),
		NStr("en = 'Proceeding to the new version is not completed'"),
		PictureLib.Warning32);
	
EndProcedure

// Returns navigation reference of data processor InformationBaseUpdate.
//
Function ProcessorsURL()
	Return "e1cib/app/DataProcessor.InfobaseUpdate";
EndFunction

// Running on the interactive beginning of user work with data area or in local mode.
// Called after the complete OnStart actions.
// Used to connect wait handlers that should not be called on interactive actions before and during the system start.
//
Procedure AfterSystemOperationStart() Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If ClientParameters.Property("ShowMessageAboutErrorHandlers")
		Or ClientParameters.Property("ShowAlertAboutFailedHandlers") Then
		AttachIdleHandler("ValidateStatusDeferredUpdate", 2, True);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Appears before the beginning of user interactive operation with data area.
// Corresponds to the event BeforeSystemOperationStart of application modules.
//
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If ClientParameters.Property("InfobaseLockedForUpdate") Then
		Parameters.Cancel = True;
		Parameters.InteractiveDataProcessor = New NotifyDescription(
			"ShowWarningAndContinue",
			StandardSubsystemsClient.ThisObject,
			ClientParameters.InfobaseLockedForUpdate);
		
	ElsIf ClientParameters.Property("ShouldUpdateApplicationWorkParameters") Then
		Parameters.InteractiveDataProcessor = New NotifyDescription(
			"ImportRefreshApplicationWorkParameters", ThisObject, Parameters);
		
	ElsIf Find(Lower(LaunchParameter), Lower("RegisterFullUpdateIOMForDescendantsOfRIB")) > 0 Then
		Parameters.Cancel = True;
		Parameters.InteractiveDataProcessor = New NotifyDescription(
			"ShowWarningAndContinue",
			StandardSubsystemsClient.ThisObject,
			NStr("en = 'Launch
			           |parameter RegisterFullIOMChangeForDIBSubordinateNodes can be used only with parameter StartInformationBaseUpdate.'"));
	EndIf;
	
EndProcedure

// Called when starting interactive operation of user with data area.
// Corresponds to the OnStart event of application modules.
//
Procedure OnStart(Parameters) Export
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If Not ClientWorkParameters.CanUseSeparatedData Then
		Return;
	EndIf;
	
	ShowSystemChangesDescription();
	
EndProcedure

#EndRegion
