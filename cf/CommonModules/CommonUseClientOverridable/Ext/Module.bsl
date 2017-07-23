////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Implementation of the application module handlers is in this module. 
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Executed before the online work beginning of a user with data area or in the local mode.
//		
// Corresponds to the BeforeStart handler.
//		
// Parameters:
//  Parameters - Structure - structure with properties:
//              Cancel                  - Boolean - Return value. If you
//                                       set True, the application will terminate.
//              Restart          - Boolean - Return value. If you set True and parameter.
//                                       Denial is also set to True, then the application will be restarted.
//              AdditionalCommandLineParameters - String - Return value. Makes
//                                       sense only when Denial and Restart are set to True.
//              InteractiveDataProcessor - NotifyDescription - Return value. To open
//                                       the window that locks application entry, it is required
//                                       to assign alert handler description to this parameter that opens the window.
//                                      See the example below.
//              ContinuationProcessor   - NotifyDescription - if the window that
//                                       locks application entry is opened, then it is required
//                                       to execute the ContinuationProcessor alert in the handler of this window closing.
//                                      See the example below.
//		
// Example of window opening that locks the signing in to application:
//		
// 	If OpenWindowOnStart Then
// 		Parameters.InteractiveDataProcessor = New NotifyDescription("OpenWindow", ThisObject);
// 	EndIf;
//		
// Procedure OpenWindow (Parameters,
// 	 AdditionalParameters) Export Sh//ow window after closing of which the OpenEndWindow alert handler is called.
// 	Alert = New AlertDescription (OpenEndWindow, Thisobject, Parameters);
// 	Form = OpenForm(... ,,, ... Notification);
// 	If Not Form.Opened  Then If On//CreateOnServer Denial is set True.
// 		ExecuteNotificationProcessing(Parameters.ContinuationProcessor);
// 	EndIf;
// EndProcedure
//		
// Procedure OpenEndWindow (Result,
// 	Parameters) Export ...
// 	ExecuteNotificationProcessing(Parameters.ContinuationProcessor);
//		
// EndProcedure
//
Procedure BeforeStart(Parameters) Export
	
EndProcedure

// Running on the interactive beginning of user work with data area or in local mode.
//
// Corresponds to the OnStart handler.
//
// Parameters:
//  Parameters - Structure - structure with properties:
//            * Denial                  - Boolean - Return value. If you
//                                       set True, the application will terminate.
//            *Restart          - Boolean - Return value. If you set True and parameter.
//                                       Denial is also set to True, then the application will be restarted.
//            * CommandBarAdditionalParameters - String - Return value. Makes
//                                       sense only when Denial and Restart are set to True.
//            * ContinuationProcessor  - NotifyDescription - Return value. To open
//                                       the window that locks application entry, it is required
//                                       to assign alert handler description to this parameter that opens the window.
//                                      See example above (for the BeforeStart handler).
//            * ContinuationProcessor   - NotifyDescription - if the window that
//                                       locks application entry is opened, then it is required
//                                       to execute the ContinuationProcessor alert in the handler of this window closing.
//                                      See example above (for the BeforeStart handler).
//
Procedure OnStart(Parameters) Export
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If ClientWorkParameters.CanUseSeparatedData Then
		
		If ClientWorkParameters.ShowSystemChangesDescription Then
			
			// Open only description of changes during the version update
			
		Else
			
			#If Not WebClient Then
			If Not ClientWorkParameters.DataSeparationEnabled AND ClientWorkParameters.IsMasterNode Then
				// OnlineUserSupport
				OnlineUserSupportClient.OnStart();
				// End OnlineUserSupport
			EndIf;
			#EndIf
			
		EndIf;
		
	EndIf;
	
	If CommonUseServerCall.ThisIsFirstLaunch() Then
		Parameters.ContinuationProcessor = New NotifyDescription("OpenExternalFirstLaunch", ThisObject, Parameters);
	EndIf;
	
EndProcedure

// Process the application start parameters.
// Implementation of function can be expanded to process new parameters.
//
// Parameters:
//  LaunchParameterValue - String - first value of the
// start parameter up to the first ; character.
//  LaunchParameters  - String - start parameter passed to
// the configuration using the key of command bar /C.
//  Cancel             - Boolean - Return value. If you
//                               set True, the OnBeginSystemWork procedure execution will be aborted.
Procedure OnProcessingParametersLaunch(LaunchParameterValue, LaunchParameters, Cancel) Export

EndProcedure

// Running on the interactive beginning of user work with data area or in local mode.
// Called after the complete OnStart actions.
// Used to connect wait handlers that should not be called on interactive actions before and during the system start.
//
// Online interactions with user are prohibited.
//
Procedure AfterSystemOperationStart() Export
	
EndProcedure

// Executed before the online work completion of a user with data area or in the local mode.
//
// Corresponds to the BeforeExit handler.
//
// Parameters:
//  Parameters - Structure - structure with properties:
//            * Denial                  - Boolean - Return value. If you
//                                       set True, then the application ending will be canceled.
//            * OnlineProcessor - NotifyDescription - Return value. To open
//                                       the window that locks application exit, it is required
//                                       to assign alert handler description to this parameter that opens the window.
//                                      See example above (for the BeforeStart handler).
//            * ContinuationProcessor   - NotifyDescription - if the window that
//                                       locks application exit is opened, then it is required
//                                       to execute the ContinuationProcessor alert in the handler of this window closing.
//                                      See example above (for the BeforeStart handler).
//
Procedure BeforeExit(Parameters) Export
	
EndProcedure

// Redefines the application title.
//
// Parameters:
//  ApplicationCaption - String - application title text;
//  OnLaunch - Boolean - True if it is called on the application start.
Procedure OnSettingClientApplicationTitle(ApplicationCaption, OnLaunch) Export
	
EndProcedure

// Outdated. It is required to use OnStartParametersProcessor.
// Process the application start parameters.
// Implementation of function can be expanded to process new parameters.
//
// Parameters:
//  LaunchParameterValue - String - first value of the
// start parameter up to the first ; character.
//  LaunchParameters  - String - start parameter passed to
// the configuration using the key of command bar /C.
//
// Returns:
//   Boolean   - True if it is required to break the OnBeginSystemWork procedure execution.
//
Function ProcessStartParameters(LaunchParameterValue, LaunchParameters) Export
	
	Return False;
	
EndFunction

#EndRegion

#Region ExternalFirstLaunch

Procedure OpenExternalFirstLaunch(Parameters, AdditionalParameters) Export
	
	NotifyDescription = New NotifyDescription("CompletionProcessing", ThisObject, AdditionalParameters);
	OpenForm("DataProcessor.FirstLaunch.Form",,,,,,NotifyDescription);
	
EndProcedure

Procedure CompletionProcessing(Result, Parameters) Export
	
	If Result <> True Then
		CommonUseServerCall.FillDefaultFirstLaunch();
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.CompletionProcessing);
	
EndProcedure

#EndRegion