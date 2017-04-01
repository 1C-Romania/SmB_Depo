////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of the online work.

// Sets a title of the main application window
// by using the current user presentation, a value of constant ApplicationTitle and the default application title.
//
// Parameters:
//   OnLaunch - Boolean - True if it is called on the application start.
//
Procedure SetAdvancedApplicationCaption(OnLaunch = False) Export
	
	ClientParameters = ?(OnLaunch, StandardSubsystemsClientReUse.ClientWorkParametersOnStart(),
		StandardSubsystemsClientReUse.ClientWorkParameters());
		
	If ClientParameters.CanUseSeparatedData Then
		CaptionPresentation = ClientParameters.ApplicationCaption;
		UserPresentation = ClientParameters.UserPresentation;
		ConfigurationPresentation = ClientParameters.DetailedInformation;
		
		If IsBlankString(TrimAll(CaptionPresentation)) Then
			If ClientParameters.Property("DataAreaPresentation") Then
				CaptionPattern = "%1 / %2 / %3";
				ApplicationCaption = StringFunctionsClientServer.SubstituteParametersInString(CaptionPattern, 
					ClientParameters.DataAreaPresentation, ConfigurationPresentation, 
					UserPresentation);
			Else
				CaptionPattern = "%1 / %2";
				ApplicationCaption = StringFunctionsClientServer.SubstituteParametersInString(CaptionPattern, 
					ConfigurationPresentation, UserPresentation);
			EndIf;
		Else
			CaptionPattern = "%1 / %2 / %3";
			ApplicationCaption = StringFunctionsClientServer.SubstituteParametersInString(CaptionPattern, 
				TrimAll(CaptionPresentation), UserPresentation, ConfigurationPresentation);
		EndIf;
	Else
		CaptionPattern = "%1 / %2";
		ApplicationCaption = StringFunctionsClientServer.SubstituteParametersInString(CaptionPattern, 
			NStr("en='Separators are not installed';ru='Не установлены разделители'"), ClientParameters.DetailedInformation);
	EndIf;
	
	CommonUseClientOverridable.OnSettingClientApplicationTitle(ApplicationCaption, OnLaunch);
	
	SetClientApplicationCaption(ApplicationCaption);
	
EndProcedure

// Show question form.
//
// Parameters:
//   CompletionNotificationDescription - NotifyDescription - description of procedure that will be called
//                                                        after
//                                                        closing the question window with the following parameters: 
//                                                          QuestionResult - Structure - structure with properties:
//                                                            Value - user selection result:
//                                                                       system enumeration value or
//                                                                       a value associated with the clicked button. If the
//                                                                       dialog is closed on timeout - value
//                                                                       Timeout.
//                                                            DontAskAgain - Boolean - result
//                                                                                                  of the
//                                                                                                  user selection in the eponymous checkbox.
//                                                          AdditionalParameters - Structure 
//   QuestionText                  - String             - text of the set question. 
//   Buttons                        - QuestionDialogMode, ValueList - values list can be specified in which.
//                                       Value - contains a value associated
// with the button and returned when selecting the button. Value of enumeration
//                                                  DialogReturnCode and
//                                                  other values that support XDTO serialization
//                                                  can be used as a value.
//                                       Presentation - sets button text.
//
//   AdditionalParameters       - Structure          - additional parameters, see
//                                                        description of UserQuestionParameters.
//
// Returns:
//   User selection result will be passed to the method described by parameter ExitNotificationDescription. 
//
Procedure ShowQuestionToUser(CompletionNotificationDescription, QuestionText, Buttons, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters <> Undefined Then
		Parameters = AdditionalParameters;
	Else	
		Parameters = QuestionToUserParameters();
	EndIf;
	
	If TypeOf(Buttons) = Type("QuestionDialogMode") Then
		If      Buttons = QuestionDialogMode.YesNo Then
			ButtonsParameter = "DialogModeQuestion.YesNo";
		ElsIf Buttons = QuestionDialogMode.YesNoCancel Then
			ButtonsParameter = "QuestionDialogMode.YesNoCancel";
		ElsIf Buttons = QuestionDialogMode.OK Then
			ButtonsParameter = "DialogModeQuestion.OK";
		ElsIf Buttons = QuestionDialogMode.OKCancel Then
			ButtonsParameter = "QuestionDialogMode.OKCancel";
		ElsIf Buttons = QuestionDialogMode.RetryCancel Then
			ButtonsParameter = "QuestionDialogMode.RetryCancel";
		ElsIf Buttons = QuestionDialogMode.AbortRetryIgnore Then
			ButtonsParameter = "QuestionDialogMode.AbortRetryIgnore";
		EndIf;
	Else
		ButtonsParameter = Buttons;
	EndIf;
	
	If TypeOf(Parameters.DefaultButton) = Type("DialogReturnCode") Then
		DefaultButtonParameter = DialogReturnCodeInString(Parameters.DefaultButton);
	Else
		DefaultButtonParameter = Parameters.DefaultButton;
	EndIf;
	
	If TypeOf(Parameters.TimeoutButton) = Type("DialogReturnCode") Then
		TimeoutButtonParameter = DialogReturnCodeInString(Parameters.TimeoutButton);
	Else
		TimeoutButtonParameter = Parameters.TimeoutButton;
	EndIf;
	
	Parameters.Insert("Buttons",            ButtonsParameter);
	Parameters.Insert("Timeout",           Parameters.Timeout);
	Parameters.Insert("DefaultButton", DefaultButtonParameter);
	Parameters.Insert("Title",         Parameters.Title);
	Parameters.Insert("TimeoutButton",    TimeoutButtonParameter);
	Parameters.Insert("MessageText",    QuestionText);
	Parameters.Insert("Picture",          Parameters.Picture);
	Parameters.Insert("OfferDontAskAgain", Parameters.OfferDontAskAgain);
	
	OpenForm("CommonForm.Question", Parameters,,,,,CompletionNotificationDescription);
	
EndProcedure

// Returns a new structure of additional parameters for procedure ShowUserQuestion.
//
// Returns:
//  Structure   - structure with properties:
//    *DefaultButton             - Arbitrary - determines the default button by a button
//                                                     type or a value associated with it.
//    * Timeout                       - Number        - time interval in seconds before the
//                                                     question window is automatically closed.
//    * TimeoutButton                - Arbitrary - button (by button type or a value associated
//                                                     with it) that shows a number of
//                                                     seconds before the time out.
//    * Title                     - String       - question title. 
//    * OfferDoNotAskAgain - Boolean- if True, then a check box with the same name will be available in the question window.
//    * DoNotAskThisQuestionAgain    - Boolean       - gets a value selected by
//                                                     a user in the corresponding check box.
//    * LockWholeInterface      - Boolean       - if True, then the question form opens
//                                                     locking all other opened windows including the main one.
//    * Picture                      - Picture     - picture that is displayed in the question window.
//
Function QuestionToUserParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("DefaultButton", Undefined);
	Parameters.Insert("Timeout", 0);
	Parameters.Insert("TimeoutButton", Undefined);
	Parameters.Insert("Title", GetClientApplicationCaption());
	Parameters.Insert("OfferDontAskAgain", True);
	Parameters.Insert("DontAskAgain", False);
	Parameters.Insert("LockWholeInterface", False);
	Parameters.Insert("Picture", Undefined);
	Return Parameters;
	
EndFunction	

////////////////////////////////////////////////////////////////////////////////
// Start and end work.

// Disables user warnings on shutting down.
//
Procedure SkipExitConfirmation() Export
	
	ApplicationParameters.Insert("StandardSubsystems.SkipAlertBeforeExit", True);
	
EndProcedure

// Perform standard actions before starting
// working with the data area or in a local mode.
//
// It is called from handler BeforeStart of modules of the managed and general application.
//
// Parameters:
//  CompletionAlert - NotifyDescription - it is not specified when calling from
// handler BeforeStart of modules of the managed and general application. IN other cases, a notification with
//                         parameters of the Structure with properties type will be called after launch:
//                         - Cancel - Boolean - False if the start is executed successfully or True if you
//                         are not log in the application;
//                         - Restart - Boolean - if application restart is required;
//                         - AdditionalCommandLineParameters - String - for restart.
//
Procedure BeforeStart(Val CompletionAlert = Undefined) Export
	
	If ApplicationParameters = Undefined Then
		ApplicationParameters = New Map;
	EndIf;
	
	If CompletionAlert <> Undefined Then
		CommonUseClientServer.CheckParameter("StandardSubsystemsClient.BeforeStart", 
			"CompletionAlert", CompletionAlert, Type("NotifyDescription"));
	EndIf;
	
	SetSessionSeparation();
	
	Parameters = New Structure;
	
	// External parameters of result description.
	Parameters.Insert("Cancel", False);
	Parameters.Insert("Restart", False);
	Parameters.Insert("AdditionalCommandLineParameters", "");
	
	// External parameters of execution management.
	Parameters.Insert("InteractiveDataProcessor", Undefined); // NotificationDescription.
	Parameters.Insert("ContinuationProcessor",   Undefined); // NotificationDescription.
	Parameters.Insert("ContinuousExecution", True);
	Parameters.Insert("ReceivedClientParameters", New Structure);
	
	// Internal parameters.
	Parameters.Insert("CompletionAlert", CompletionAlert);
	Parameters.Insert("CompletionProcessing", New NotifyDescription(
		"ActionsFileBeforeStartEndProcessor", ThisObject, Parameters));
	
	UpdateClientWorkParameters(Parameters, True, CompletionAlert <> Undefined);
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	Parameters.Insert("ContinuationProcessor", New NotifyDescription(
		"ActionsBeforeStartAfterPlatformVersionCheck", ThisObject, Parameters));
	
	Try
		CheckPlatformVersionAtStart(Parameters);
	Except
		ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If OnlineDataProcessorBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Perform standard actions when starting
// working with the data area or in a local mode.
//
// It is called from handler BeforeStart of modules of the managed and general application.
//
// Parameters:
//  CompletionAlert - NotifyDescription - it is not specified when calling from
// handler BeforeStart of modules of the managed and general application. IN other cases, a notification with
//                         parameters of the Structure with properties type will be called after launch:
//                         - Cancel - Boolean - False if the start is executed successfully or True if you
//                         are not log in the application;
//                         - Restart - Boolean - if application restart is required;
//                         - AdditionalCommandLineParameters - String - for restart.
//
//  ContinuousExecution - Boolean - Only for internal use.
//                          To transfer from
//                          procedure BeforeStart performed in the interactive processing mode.
//
Procedure OnStart(Val CompletionAlert = Undefined, ContinuousExecution = True) Export
	
	If CompletionAlert <> Undefined Then
		CommonUseClientServer.CheckParameter("StandardSubsystemsClient.OnStart", 
			"CompletionAlert", CompletionAlert, Type("NotifyDescription"));
	EndIf;
	CommonUseClientServer.CheckParameter("StandardSubsystemsClient.OnStart", 
		"ContinuousExecution", ContinuousExecution, Type("Boolean"));
	
	If RunningOnlineDataProcessorBeforeStart() Then
		Return;
	EndIf;
	
	Parameters = New Structure;
	
	// External parameters of result description.
	Parameters.Insert("Cancel", False);
	Parameters.Insert("Restart", False);
	Parameters.Insert("AdditionalCommandLineParameters", "");
	
	// External parameters of execution management.
	Parameters.Insert("InteractiveDataProcessor", Undefined); // NotificationDescription.
	Parameters.Insert("ContinuationProcessor",   Undefined); // NotificationDescription.
	Parameters.Insert("ContinuousExecution", ContinuousExecution);
	
	// Internal parameters.
	Parameters.Insert("CompletionAlert", CompletionAlert);
	Parameters.Insert("CompletionProcessing", New NotifyDescription(
		"ActionsOnStartCompletionProcessor", ThisObject, Parameters));
	
	// Prepare transition to the next procedure.
	Parameters.Insert("NextHandlerNumber", 1);
	Parameters.Insert("ContinuationProcessor", New NotifyDescription(
		"ActionsOnStartInServiceEventHandlers", ThisObject, Parameters));
	
	Try
		SetAdvancedApplicationCaption(True); // For main window.
		
		If Not ProcessStartParameters() Then
			Parameters.Cancel = True;
			ExecuteNotifyProcessing(Parameters.CompletionProcessing);
			Return;
		EndIf;
	Except
		ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If OnlineProcessorOnStart(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Perform standard actions before finishing
// working with the data area or in a local mode.
//
// It is called from handler BeforeSystemExit of modules of the managed and general application.
//
// Parameters:
//  Cancel                - Boolean - Return value. Shows that shut down
//                         is denied for handler of event BeforeSystemExit
//                         or application denial or interactive processing is required. If the interaction
//                         with user is successful, work end will be continued.
//
//  CompletionAlert - NotifyDescription - it is not specified when calling from
// handler BeforeSystemExit of modules of the managed and general application. IN other cases, a notification with
//                         parameters of the Structure with properties type will be called on shutting down:
//                         - Cancel - Boolean - False if shut down is
// successful, True if shut down should be delayed.;
//
Procedure BeforeExit(Cancel = False, Val CompletionAlert = Undefined) Export
	
	ParametersAtApplicationStartAndExit = ApplicationParameters["StandardSubsystems.ParametersAtApplicationStartAndExit"];
	
	If ParametersAtApplicationStartAndExit.Property("HideDesktopOnStart") Then
		// An attempt to close before the start ending.
	#If WebClient Then
		// IN web client, it is possible in standard case (when a
		// page is entirely closed) so closing is locked as it can
		// be enforced anyway. IN case of erroneous closing, a user should be able not to leave the page.
		// Data area exit is an exception, i.e. "ExitNotification <> Undefined".
		If CompletionAlert = Undefined Then
			Cancel = True;
		EndIf;
	#Else
		// It is possible not in the web client in case there are errors in the nonmodal start sequence.
		// I.e. there is no window locking the entire interface. Closing
		// should be allowed but without standard procedures before the system shut
		// down as they may result in errors that occur due to unfinished launch.
	#EndIf
		Return;
	EndIf;
	
	CommonUseClientServer.CheckParameter(
		"StandardSubsystemsClient.BeforeExit", "Cancel", Cancel, Type("Boolean"));
	
	If CompletionAlert <> Undefined Then
		CommonUseClientServer.CheckParameter("StandardSubsystemsClient.BeforeExit", 
			"CompletionAlert", CompletionAlert, Type("NotifyDescription"));
	EndIf;
	
	If CompletionAlert = Undefined Then
		If ParametersAtApplicationStartAndExit.Property("BeforeExitActionsExecuted") Then
			ParametersAtApplicationStartAndExit.Delete("BeforeExitActionsExecuted");
			Return;
		EndIf;
	EndIf;
	
	// During the next application exit client parameters should be received again.
	If ParametersAtApplicationStartAndExit.Property("ClientWorkParametersOnComplete") Then
		ParametersAtApplicationStartAndExit.Delete("ClientWorkParametersOnComplete");
	EndIf;
	
	Parameters = New Structure;
	
	// External parameters of result description.
	Parameters.Insert("Cancel", False);
	
	// External parameters of execution management.
	Parameters.Insert("InteractiveDataProcessor", Undefined); // NotificationDescription.
	Parameters.Insert("ContinuationProcessor",   Undefined); // NotificationDescription.
	Parameters.Insert("ContinuousExecution", True);
	
	// Internal parameters.
	Parameters.Insert("CompletionAlert", CompletionAlert);
	Parameters.Insert("CompletionProcessing", New NotifyDescription(
		"ActionsBeforeExitCompletionProcessor", ThisObject, Parameters));
	
	Parameters.Insert("NextHandlerNumber", 1);
	Parameters.Insert("ContinuationProcessor", New NotifyDescription(
		"ActionsBeforeSystemExitInServiceEventHandlers", ThisObject, Parameters));
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
	If Parameters.Cancel Or Not Parameters.ContinuousExecution Then
		Cancel = True;
	EndIf;
	
EndProcedure

// Returns a structure of parameters
// required for the configuration operation on the client when shutting down, i.e. in event handlers.
// - BeforeExit,
// - OnExit
// 
// Returns:
//   FixedStructure - structure of the client work parameters on end.
//
Function ClientWorkParametersOnComplete() Export
	
	ParametersAtApplicationStartAndExit = ApplicationParameters["StandardSubsystems.ParametersAtApplicationStartAndExit"];
	
	If Not ParametersAtApplicationStartAndExit.Property("ClientWorkParametersOnComplete") Then
		ParametersAtApplicationStartAndExit.Insert("ClientWorkParametersOnComplete",
			StandardSubsystemsServerCall.ClientWorkParametersOnComplete());
	EndIf;
	
	Return ParametersAtApplicationStartAndExit.ClientWorkParametersOnComplete;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Search and delete duplicates

// Outdated. It is recommended to use SearchAndDeleteDuplicatesClient.CombineSelected.
//
Procedure CombineSelected(Val CombinedItems) Export
	If CommonUseClient.SubsystemExists("StandardSubsystems.SearchAndDeleteDuplicates") Then
		SearchAndDeleteDuplicatesModuleClient = CommonUseClient.CommonModule("SearchAndDeleteDuplicatesClient");
		SearchAndDeleteDuplicatesModuleClient.CombineSelected(CombinedItems);
	EndIf;
EndProcedure

// Outdated. It is recommended to use SearchAndDeleteDuplicatesClient.ReplaceSelected.
//
Procedure ReplaceSelected(Val CombinedItems) Export
	If CommonUseClient.SubsystemExists("StandardSubsystems.SearchAndDeleteDuplicates") Then
		SearchAndDeleteDuplicatesModuleClient = CommonUseClient.CommonModule("SearchAndDeleteDuplicatesClient");
		SearchAndDeleteDuplicatesModuleClient.ReplaceSelected(CombinedItems);
	EndIf;
EndProcedure

// Outdated. It is recommended to use SearchAndDeleteDuplicatesClient.ShowUsagePlaces.
//
Procedure ShowUsagePlacess(Val Items, Val OpenParameters = Undefined) Export
	If CommonUseClient.SubsystemExists("StandardSubsystems.SearchAndDeleteDuplicates") Then
		SearchAndDeleteDuplicatesModuleClient = CommonUseClient.CommonModule("SearchAndDeleteDuplicatesClient");
		SearchAndDeleteDuplicatesModuleClient.ShowUsagePlacess(Items, OpenParameters);
	EndIf;
EndProcedure

// UseModality

// Outdated. You should use ShowQuestionToUser.
// Calls question form.
// Parameters and return value are compatible with the global context function Question with further additions:
//
// Parameters:
//   Buttons - ValueList - in which:
//            Value - contains a value associated
// with the button and returned when selecting the button. Value of enumeration DialogReturnCode and
// other values that support XDTO serialization can be used as a value.
//            Presentation - sets button text.
//
//   DontAskAgain - Boolean - gets a value selected by a
// user in the corresponding dialog check box.
//
//   OfferDontAskAgain - Boolean - check box showing that user must be offered a variant.
//
// Returns:
//   DialogReturnCode - user response. Or one of the values from the Buttons values list. 
//
Function QuestionToUser(MessageText, Buttons, Timeout = 0, DefaultButton = Undefined, Title = "", TimeoutButton = Undefined,
	DontAskAgain = False, OfferDontAskAgain=True) Export
	
	DontAskAgain = False;
	
	Parameters = New Structure;
	
	If TypeOf(Buttons) = Type("QuestionDialogMode") Then
		If      Buttons = QuestionDialogMode.YesNo Then
			ButtonsParameter = "DialogModeQuestion.YesNo";
		ElsIf Buttons = QuestionDialogMode.YesNoCancel Then
			ButtonsParameter = "QuestionDialogMode.YesNoCancel";
		ElsIf Buttons = QuestionDialogMode.OK Then
			ButtonsParameter = "DialogModeQuestion.OK";
		ElsIf Buttons = QuestionDialogMode.OKCancel Then
			ButtonsParameter = "QuestionDialogMode.OKCancel";
		ElsIf Buttons = QuestionDialogMode.RetryCancel Then
			ButtonsParameter = "QuestionDialogMode.RetryCancel";
		ElsIf Buttons = QuestionDialogMode.AbortRetryIgnore Then
			ButtonsParameter = "QuestionDialogMode.AbortRetryIgnore";
		EndIf;
	Else
		ButtonsParameter = Buttons;
	EndIf;
	
	If TypeOf(DefaultButton) = Type("DialogReturnCode") Then
		DefaultButtonParameter = DialogReturnCodeInString(DefaultButton);
	Else
		DefaultButtonParameter = DefaultButton;
	EndIf;
	
	If TypeOf(TimeoutButton) = Type("DialogReturnCode") Then
		TimeoutButtonParameter = DialogReturnCodeInString(TimeoutButton);
	Else
		TimeoutButtonParameter = TimeoutButton;
	EndIf;
	
	Parameters.Insert("Buttons",            ButtonsParameter);
	Parameters.Insert("Timeout",           Timeout);
	Parameters.Insert("DefaultButton", DefaultButtonParameter);
	Parameters.Insert("Title",         Title);
	Parameters.Insert("TimeoutButton",    TimeoutButtonParameter);
	Parameters.Insert("MessageText",    MessageText);
	
	Parameters.Insert("OfferDontAskAgain", OfferDontAskAgain);
	
	Result = OpenFormModal("CommonForm.Question", Parameters);
	If TypeOf(Result) = Type("Structure") Then
		DontAskAgain = Result.DontAskAgain;
		Return Result.Value;
	Else
		Return DialogReturnCode.Cancel;
	EndIf;
	
EndFunction

// End ModalityUse

#EndRegion

#Region ServiceProgramInterface

// Returns a new parameter structure to show a warning before shutting down.
//
// Returns:
//  Structure - with properties:
//    FlagText      - String - check box text.
//    ExplanationText  - String - text that is shown in the control upper part (check box or hyperlink).
//    HyperlinkText - String - hyperlink text.
//    ExtendedTooltip - String - tooltip text that is displayed by clicking a button to
//                                    the right from the control (check box or hyperlink).
//    Priority        - Number  - determines the relative order of warnings in form output (the more, the higher).
//    OutputOneMessageBox - Boolean - if True, then only this warning is output
//                                         in the warnings list.
//    ActionIfMarked - Structure with fields:
//      * Form          - String    - path to the opened form.
//      * FormParameters - Structure - custom parameters structure of the Form form. 
//    ActionOnHyperlinkClick - Structure with fields:
//      * Form          - String    - path to a form to be opened by clicking the hyperlink.
//      * FormParameters - Structure - arbitrary structure of parameters for the form described above.
//      * WarningAppliedForm - String - path to the form that
//                                        should be opened immediately instead of universal form in
//                                        case when the list of warnings only one warning is present.
//      * WarningAppliedFormParameters - Structure - arbitrary
//                                                 structure of parameters for the form described above.
Function AlertOnEndWork() Export
	
	ActionIfMarked = New Structure;
	ActionIfMarked.Insert("Form", "");
	ActionIfMarked.Insert("FormParameters", Undefined);
	
	ActionOnHyperlinkClick = New Structure;
	ActionOnHyperlinkClick.Insert("Form", "");
	ActionOnHyperlinkClick.Insert("FormParameters", Undefined);
	ActionOnHyperlinkClick.Insert("ApplicationWarningForm", "");
	ActionOnHyperlinkClick.Insert("ApplicationWarningFormParameters", Undefined);
	
	WarningParameters = New Structure;
	WarningParameters.Insert("FlagText", "");
	WarningParameters.Insert("ExplanationText", "");
	WarningParameters.Insert("ExtendedTooltip", "");
	WarningParameters.Insert("HyperlinkText", "");
	WarningParameters.Insert("ActionIfMarked", ActionIfMarked);
	WarningParameters.Insert("ActionOnHyperlinkClick", ActionOnHyperlinkClick);
	WarningParameters.Insert("Priority", 0);
	WarningParameters.Insert("OutputOneMessageBox", False);
	
	Return WarningParameters;
	
EndFunction	

// After warning calls a procedure with parameters Result, AdditionalParameters.
//
// Parameters:
//  Parameters           - Structure that contains property:
//                          ContinuationProcessor - NotificationDescription
//                          that contains a procedure with two parameters:
//                            Result, AdditionalParameters.
//
//  WarningText - String - warning text that needs to be shown.
//
Procedure ShowWarningAndContinue(Parameters, WarningText) Export
	
	AlertWithResult = Parameters.ContinuationProcessor;
	
	If WarningText = Undefined Then
		ExecuteNotifyProcessing(AlertWithResult);
		Return;
	EndIf;
		
	If Parameters.Cancel Then
		
		Buttons = New ValueList();
		Buttons.Add("Restart", NStr("en='Restart';ru='Перезапустить'"));
		Buttons.Add("Complete",     NStr("en='Exit';ru='Завершить'"));
		
		QuestionParameters = QuestionToUserParameters();
		QuestionParameters.DefaultButton = "Restart";
		QuestionParameters.TimeoutButton    = "Restart";
		QuestionParameters.Timeout = 60;
		QuestionParameters.OfferDontAskAgain = False;
		QuestionParameters.LockWholeInterface = True;
		QuestionParameters.Picture = PictureLib.Warning32;
		
	Else

		Buttons = New ValueList();
		Buttons.Add("Continue", NStr("en='Continue';ru='Продолжить'"));
		If Parameters.Property("Restart") Then
			Buttons.Add("Restart", NStr("en='Restart';ru='Перезапустить'"));
		EndIf;
		Buttons.Add("Complete", NStr("en='Exit';ru='Завершить'"));
		
		QuestionParameters = QuestionToUserParameters();
		QuestionParameters.DefaultButton = "Continue";
		QuestionParameters.OfferDontAskAgain = False;
		QuestionParameters.LockWholeInterface = True;
		QuestionParameters.Picture = PictureLib.Warning32;
		
	EndIf;
	
	ClosingAlert = New NotifyDescription("ShowWarningAndContinueEnd", ThisObject, Parameters);
	ShowQuestionToUser(ClosingAlert, WarningText, Buttons, QuestionParameters);
	
EndProcedure

// Shows files selection dialog and puts selected files to the temporary storage.
//  Combines method operations of global method
//  StartPlaceFile and PlaceFiles returning an identical result no matter whether the file extension is enabled.
//
// Parameters:
//   EndProcessor  - NotifyDescription - Description of the procedure receiving selection result.
//   FormID    - UUID - Unique form identifier from
//                                                     which the file is placed.
//   InitialFileName     - String - Full path and attachment file name that will be offered to user in the selection start.
//   DialogueParameters      - Structure, Undefined - See FileSelectionDialog properties in syntax helper.
//       Used if the file extension is successfully enabled.
//
// Value of the first parameter returned to ResultHandler.:
//   PlacedFiles - Selection result.
//       * - Undefined - User refused to select.
//       * - Array from PassedFileDescription, Structure - User selected file.
//           ** Name      - String - Full name of the selected file.
//           ** Storage - String - Address in the temporary storage according to which the file is located.
//
// restriction:
//   Used only for online selection in dialog.
//   It is not used to select directories - this option is not supported by web client.
//   Multiselection is not supported in the web client if file extension is not set.
//   Transfer of the temporary storage addresses is not supported.
//
Procedure ShowFilePlace(EndProcessor, FormID, InitialFileName, DialogueParameters) Export
	Parameters = New Structure;
	Parameters.Insert("EndProcessor", EndProcessor);
	Parameters.Insert("FormID", FormID);
	Parameters.Insert("InitialFileName", InitialFileName);
	Parameters.Insert("DialogueParameters", DialogueParameters);
	
	NotifyDescription = New NotifyDescription("ShowFilePlaceWhenConnectingFileExtensions", ThisObject, Parameters);
	CommonUseClient.ShowQuestionAboutFileOperationsExtensionSetting(NOTifyDescription);
EndProcedure

// Open a dialog box to enter a username and password of Online support.
//
Procedure AuthorizeOnUserSupportSite(FormOwner = Undefined, ClosingAlert = Undefined) Export
	
	If CommonUseClient.SubsystemExists("OnlineUserSupport") Then
		ModuleOnlineUserSupportClient = CommonUseClient.CommonModule("OnlineUserSupportClient");
		ModuleOnlineUserSupportClient.ConnectOnlineUserSupport(ClosingAlert);
	Else	
		OpenForm("CommonForm.AuthorizationOnUsersSupportSite",, FormOwner,,,, ClosingAlert);
	EndIf;
	
EndProcedure

// Returns a name of the executable file depending on the client kind and platform version.
//
Function ApplicationExecutedFileName(GetFileConfigurator = False) Export
	
	FileNamePattern = "1cv8[ThinClient][TrainingPlatform].exe";
	
	IsEducationalPlatform = StandardSubsystemsClientReUse.ClientWorkParameters().IsEducationalPlatform;
	
	#If ThinClient Then
		IsThinClient = Not GetFileConfigurator;
	#Else
		IsThinClient = False;
	#EndIf
	
	FileName = StrReplace(FileNamePattern, "[ThinClient]", ?(IsThinClient, "c", ""));
	FileName = StrReplace(FileName, "[TrainingPlatform]", ?(IsEducationalPlatform, "t", ""));
	
	Return FileName;
	
EndFunction

// Sets / cancels reference to managed form storage in a global variable.
// It is required when a form ref is passed
// using AdditionalParameters in object NotificationDescription which does not lock the closed form release.
//
Procedure SetFormStorage(Form, Location) Export
	
#If WebClient Then
	Storage = ApplicationParameters["StandardSubsystems.ReferencesTemporaryStorageOnManagedForms"];
	If Storage = Undefined Then
		Storage = New Map;
		ApplicationParameters.Insert("StandardSubsystems.ReferencesTemporaryStorageOnManagedForms", Storage);
	EndIf;
	
	If Location Then
		Storage.Insert(Form, New Structure("Form", Form));
	ElsIf Storage.Get(Form) <> Undefined Then
		Storage.Delete(Form);
	EndIf;
#EndIf

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Execution result processor.

// Displays result of operation execution.
//
// Displays the server result on
// the client, does not show mid-stages. - dialogs etc.
//
// See also:
//   StandardSubsystemsClientServer.NewExecutionResult()
//   StandardSubsystemsClientServer.NotifyDynamicLists()
//   StandardSubsystemsClientServer.DisplayWarning()
//   StandardSubsystemsClientServer.ShowMessage()
//   StandardSubsystemsClientServer.DisplayNotification()
//   StandardSubsystemsClientServer.CollapseTreeNodes()
//
// Parameters:
//   Form - ManagedForm - Form for which output is required.
//   Result - Structure - Operation execution result to be shown.
//       * OutputNotification - Structure - Popup alert.
//           ** Usage - Boolean - Output alert.
//           ** Title     - String - Notification title.
//           ** Text         - String - Notification text.
//           ** Refs        - String - Text navigation hyperlink.
//           ** Picture      - Picture - Notification picture.
//       * MessageOutput - Structure - Form message bound to the attribute.
//           ** Usage       - Boolean - Output message.
//           ** Text               - String - Message text.
//           ** PathToFormAttribute - String - Path attribute of the form to which the message applies.
//       * WarningOutput - Structure - Warning window locking the entire interface.
//           ** Usage       - Boolean - Output warning.
//           ** Title           - String - Window title.
//           ** Text               - String - Notification text.
//           ** ErrorsText         - String - Optional. Texts of errors that the user
//                                             can view if necessary.
//           ** PathToFormAttribute - String - Optional. Path to the form attribute
//                                             which value caused an error.
//       * FormsNotification - Structure, Array from Structure - cm. help k method global context Notify().
//           ** Use - Boolean - Alert the form opening.
//           ** EventName    - String - Event name used for primary message identification
//                                       by the receiving forms.
//           ** Parameter      - Arbitrary - Set of data used by the receiving
//                                             form for the content update.
//           ** Source      - Arbitrary - Notification source, for example, form-source.
//       * DynamictListsAlert - Structure - cm. help k method global context
//                                                     NotifyChanged().
//           ** Use - Boolean - Notify the dynamic lists.
//           ** ReferenceOrType  - Arbitrary - Ref, type or type array that are to be updated.
//   EndProcessor - NotifyDescription - Description of procedure that will be called
//                                               after finishing display (with value Undefined).
//
Procedure ShowExecutionResult(Form, Result, EndProcessor = Undefined) Export
	
	If TypeOf(Result) <> Type("Structure") AND TypeOf(Result) <> Type("FixedStructure") Then
		Return;
	EndIf;
	
	EndProcessorWillCompleted = False;
	
	If Result.Property("OutputNotification") AND Result.OutputNotification.Use Then
		Notification = Result.OutputNotification;
		ShowUserNotification(Notification.Title, Notification.Ref, Notification.Text, Notification.Picture);
	EndIf;
	
	If Result.Property("OutputMessages") AND Result.OutputMessages.Use Then
		Message = New UserMessage;
		If TypeOf(Form) = Type("ManagedForm") Then
			Message.TargetID = Form.UUID;
		EndIf;
		Message.Text = Result.OutputMessages.Text;
		Message.Field  = Result.OutputMessages.PathToAttributeForms;
		Message.Message();
	EndIf;
	
	If Result.Property("OutputWarning") AND Result.OutputWarning.Use Then
		OutputWarning = Result.OutputWarning;
		If ValueIsFilled(OutputWarning.ErrorsText) Then
			Buttons = New ValueList;
			Buttons.Add(1, NStr("en='Details...';ru='Подробнее...'"));
			If TypeOf(Form) = Type("ManagedForm") AND ValueIsFilled(OutputWarning.PathToAttributeForms) Then
				Buttons.Add(2, NStr("en='Go to attribute';ru='Перейти к реквизиту'"));
			EndIf;
			Buttons.Add(0, NStr("en='Continue';ru='Продолжить'"));
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("OutputWarning",   OutputWarning);
			AdditionalParameters.Insert("Form",                 Form);
			AdditionalParameters.Insert("EndProcessor", EndProcessor);
			Handler = New NotifyDescription("ShowExecutionResultEnd", ThisObject, AdditionalParameters);
			
			ShowQueryBox(Handler, OutputWarning.Text, Buttons, , 1, OutputWarning.Title);
			EndProcessorWillCompleted = True;
		Else
			ReturnResultAfterShowWarning(OutputWarning.Text, EndProcessor, Undefined, OutputWarning.Title);
			EndProcessorWillCompleted = True;
		EndIf;
	EndIf;
	
	If Result.Property("NotificationForms") Then
		If TypeOf(Result.NotificationForms) = Type("Structure") Or TypeOf(Result.NotificationForms) = Type("FixedStructure") Then
			NotificationForms = Result.NotificationForms;
			If NotificationForms.Use Then
				Notify(NotificationForms.EventName, NotificationForms.Parameter, NotificationForms.Source);
			EndIf;
		Else
			For Each NotificationForms IN Result.NotificationForms Do
				If NotificationForms.Use Then
					Notify(NotificationForms.EventName, NotificationForms.Parameter, NotificationForms.Source);
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	If Result.Property("NotifyDynamictLists") AND Result.NotifyDynamictLists.Use Then
		If TypeOf(Result.NotifyDynamictLists.ReferenceOrType) = Type("Array") Then
			For Each ReferenceOrType IN Result.NotifyDynamictLists.ReferenceOrType Do
				NotifyChanged(ReferenceOrType);
			EndDo;
		Else
			NotifyChanged(Result.NotifyDynamictLists.ReferenceOrType);
		EndIf;
	EndIf;
	
	If Result.Property("ExpandableNodes") Then
		For Each ExpandableNode IN Result.ExpandableNodes Do
			ItemTable = Form.Items[ExpandableNode.TableName];
			If ExpandableNode.Identifier = "*" Then
				Nodes = Form[ExpandableNode.TableName].GetItems();
				For Each Node IN Nodes Do
					ItemTable.Expand(Node.GetID(), ExpandableNode.WithSubordinate);
				EndDo;
			Else
				ItemTable.Expand(ExpandableNode.Identifier, ExpandableNode.WithSubordinate);
			EndIf;
		EndDo;
	EndIf;
	
	If Not EndProcessorWillCompleted AND EndProcessor <> Undefined Then
		ExecuteNotifyProcessing(EndProcessor, Undefined);
	EndIf;
	
EndProcedure

// Handler of question response when displaying the execution result.
//
Procedure ShowExecutionResultEnd(Response, Result) Export
	
	EndProcessorWillCompleted = False;
	If TypeOf(Response) = Type("Number") Then
		If Response = 1 Then
			FullText = String(Result.OutputWarning.Text) + Chars.LF + Chars.LF + Result.OutputWarning.ErrorsText;
			Title = Result.OutputWarning.Title;
			If IsBlankString(Title) Then
				Title = NStr("en='Details';ru='Расшифровка'");
			EndIf;
			Handler = New NotifyDescription("ShowExecutionResultEnd", ThisObject, Result);
			ShowInputString(Handler, FullText, Title, , True);
			EndProcessorWillCompleted = True;
		ElsIf Response = 2 Then
			Message = New UserMessage;
			Message.TargetID = Result.Form.UUID;
			Message.Text = Result.OutputWarning.Text;
			Message.Field  = Result.OutputWarning.PathToAttributeForms;
			Message.Message();
		EndIf;
	EndIf;
	
	If Not EndProcessorWillCompleted AND Result.EndProcessor <> Undefined Then
		ExecuteNotifyProcessing(Result.EndProcessor, Undefined);
	EndIf;
	
EndProcedure

// Shows a warning dialog, once it is closed, calls a handler with the set result.
Procedure ReturnResultAfterShowWarning(WarningText, Handler, Result, Title = Undefined, Timeout = 0) Export
	HandlerParameters = New Structure;
	HandlerParameters.Insert("Handler", Handler);
	HandlerParameters.Insert("Result", Result);
	Handler = New NotifyDescription("ReturnResultAfterSimpleDialogClosing", ThisObject, HandlerParameters);
	ShowMessageBox(Handler, WarningText, Timeout, Title);
EndProcedure

// Procedure continued (see above).
Procedure ReturnResultAfterSimpleDialogClosing(HandlerParameters) Export
	If TypeOf(HandlerParameters.Handler) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(HandlerParameters.Handler, HandlerParameters.Result);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Spreadsheet document

// Creates description of the selected spreadsheet areas to be passed to the server.
//   Substitutes for
//   type SelectedSpreadsheetAreas when it is required to calculate a cell sum on the server without context.
//
// Parameters:
//   SpreadsheetDocument - SpreadsheetDocument - Table for which it is required to create description of selected cells.
//
// Returns: 
//   Array from Structure - description.
//       * Top  - Number - String number of the area upper border.
//       * Bottom   - Number - String number of the area bottom border.
//       * Left  - Number - Column number of the area upper border.
//       * Right - Number - Column number of the area bottom border.
//       * AreaType - SpreadsheetDocumentCellAreaType - Columns, Rectangle, Rows, Table.
//
// See also:
//   StandardSubsystemsClientServer.CellsAmount().
//   StandardSubsystemsServerCall.CellsAmount().
//
Function SelectedAreas(SpreadsheetDocument) Export
	Result = New Array;
	For Each SelectedArea IN SpreadsheetDocument.SelectedAreas Do
		If TypeOf(SelectedArea) <> Type("SpreadsheetDocumentRange") Then
			Continue;
		EndIf;
		Structure = New Structure("Top, Bottom, Left, Right, AreaType");
		FillPropertyValues(Structure, SelectedArea);
		Result.Add(Structure);
	EndDo;
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Opens service user password input form.
//
// Parameters:
//  ContinuationProcessor      - NotificationDescription to be processed after getting the password.
//  OwnerForm             - Undefined, ManagedForm - form that requests for a password.
//  ServiceUserPassword - String - current service user password.
//
Procedure WhenPromptedForPasswordForAuthenticationToService(ContinuationProcessor, OwnerForm = Undefined, ServiceUserPassword = Undefined) Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		
		ModuleUsersServiceSaaSClient = CommonUseClient.CommonModule(
			"UsersServiceSaaSClient");
		
		ModuleUsersServiceSaaSClient.RequestPasswordForAuthenticationInService(
			ContinuationProcessor, OwnerForm, ServiceUserPassword);
	EndIf;
	
EndProcedure

// Resend a notification without a result to a notification with a result.
Function AlertWithoutResult(AlertWithResult) Export
	
	Return New NotifyDescription("ExecuteAlertWithEmptyResult", ThisObject, AlertWithResult);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// BeforeStart

// Only for internal use. Continue the BeforeStart procedure.
Procedure ActionsBeforeStartAfterPlatformVersionCheck(NOTSpecified, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationProcessor", New NotifyDescription(
		"ActionsBeforeStartAfterReestablishConnectionWithMainNode", ThisObject, Parameters));
	
	Try
		CheckNeedToRestoreLinkWithMainNode(Parameters);
	Except
		ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If OnlineDataProcessorBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor, False);
	
EndProcedure

// Only for internal use. Continue the BeforeStart procedure.
Procedure ActionsBeforeStartAfterReestablishConnectionWithMainNode(NOTSpecified, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.SaaS") Then
		
		Parameters.Insert("ContinuationProcessor", Parameters.CompletionProcessing);
		Try
			ModuleSaaSClient = CommonUseClient.CommonModule("SaaSClient");
			ModuleSaaSClient.BeforeStart(Parameters);
		Except
			ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start", True);
		EndTry;
		If OnlineDataProcessorBeforeStart(Parameters) Then
			Return;
		EndIf;
	EndIf;
	
	Parameters.Insert("ContinuationProcessor", New NotifyDescription(
		"ActionsBeforeStartAfterChecksLegality", ThisObject, Parameters));
	
	If CommonUseClient.SubsystemExists(
		   "StandardSubsystems.CheckUpdateReceiveLegality") Then
		
		Try
			ModuleUpdateObtainingLegalityCheckClient =
				CommonUseClient.CommonModule("CheckUpdateReceiveLegalityClient");
			
			ModuleUpdateObtainingLegalityCheckClient.ValidateLegalityOfGetUpdateWhenYouRun(Parameters);
		Except
			ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start", True);
		EndTry;
		If OnlineDataProcessorBeforeStart(Parameters) Then
			Return;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor, False);
	
EndProcedure

// Only for internal use. Continue the BeforeStart procedure.
Procedure ActionsBeforeStartAfterChecksLegality(NOTSpecified, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationProcessor", New NotifyDescription(
		"ActionsBeforeStartSystemWorkAfterRepeaImportsDataExchangeMessage", ThisObject, Parameters));
	
	Try
		If CommonUseClient.SubsystemExists("StandardSubsystems.DataExchange") Then
			// User request with or without reimporting the data exchange message.
			ModuleExchangeDataClient = CommonUseClient.CommonModule("DataExchangeClient");
			ModuleExchangeDataClient.BeforeStart(Parameters);
		EndIf;
	Except
		ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If OnlineDataProcessorBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor, False);
	
EndProcedure

// Only for internal use. Continue the BeforeStart procedure.
Procedure ActionsBeforeStartSystemWorkAfterRepeaImportsDataExchangeMessage(NOTSpecified, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If ClientParameters.CanUseSeparatedData Then
		
		Parameters.Insert("ContinuationProcessor", New NotifyDescription(
			"ActionsBeforeStartAfterApplicationParametersUpdate", ThisObject, Parameters));
	Else
		Parameters.Insert("ContinuationProcessor", New NotifyDescription(
			"ActionsBeforeStartAfterOverridableProcedure", ThisObject, Parameters));
	EndIf;
	
	Try
		// - Pause when locking the info base for update.
		// - Prepare application work parameters.
		// - Update undivided data.
		InfobaseUpdateClient.BeforeStart(Parameters);
	Except
		ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If OnlineDataProcessorBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Only for internal use. Continue the BeforeStart procedure.
Procedure ActionsBeforeStartAfterApplicationParametersUpdate(NOTSpecified, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationProcessor", Parameters.CompletionProcessing);
	
	If CommonUseClient.SubsystemExists(
		"ServiceTechnology.SaaS.DataExchangeSaaS") Then
		
		ModuleOfflineWorkServiceClient = CommonUseClient.CommonModule("OfflineWorkServiceClient");
		Try
			ModuleOfflineWorkServiceClient.BeforeStart(Parameters);
		Except
			ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start", True);
		EndTry;
		If OnlineDataProcessorBeforeStart(Parameters) Then
			Return;
		EndIf;
	EndIf;
	
	Try
		UsersServiceClient.BeforeStart(Parameters);
	Except
		ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If OnlineDataProcessorBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Try
		SetAdvancedApplicationCaption(True); // For helper windows.
	Except
		ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If OnlineDataProcessorBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationProcessor", New NotifyDescription(
		"ActionsBeforeStartAfterLogOnProcessingWithUnlockedCode", ThisObject, Parameters));
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.UserSessions") Then
		
		Try
			DBModuleConnectionsClient = CommonUseClient.CommonModule("InfobaseConnectionsClient");
			DBModuleConnectionsClient.BeforeStart(Parameters);
		Except
			ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start", True);
		EndTry;
		If OnlineDataProcessorBeforeStart(Parameters) Then
			Return;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Only for internal use. Continue the BeforeStart procedure.
Procedure ActionsBeforeStartAfterLogOnProcessingWithUnlockedCode(NOTSpecified, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("NextHandlerNumber", 1);
	Parameters.Insert("ContinuationProcessor", New NotifyDescription(
		"ActionsBeforeStartInServiceEventHandlers", ThisObject, Parameters));
	
	Try
		InfobaseUpdateClient.RefreshDatabase(Parameters);
	Except
		ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If OnlineDataProcessorBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Only for internal use. Continue the BeforeStart procedure.
Procedure ActionsBeforeStartInServiceEventHandlers(NOTSpecified, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	EventHandlers = CommonUseClient.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\BeforeStart");
	
	HandlersCount = EventHandlers.Count();
	StartingNumber = Parameters.NextHandlerNumber;
	
	For Number = StartingNumber To HandlersCount Do
		Parameters.InteractiveDataProcessor = Undefined;
		Parameters.NextHandlerNumber = Number + 1;
		Handler = EventHandlers.Get(Number - 1);
		
		Try
			Handler.Module.BeforeStart(Parameters);
		Except
			ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start");
		EndTry;
		If OnlineDataProcessorBeforeStart(Parameters) Then
			Return;
		EndIf;
	EndDo;
	
	Parameters.Insert("ContinuationProcessor", New NotifyDescription(
		"ActionsBeforeStartAfterOverridableProcedure", ThisObject, Parameters));
	
	Parameters.InteractiveDataProcessor = Undefined;
		
	Try
		CommonUseClientOverridable.BeforeStart(Parameters);
	Except
		ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start");
	EndTry;
	If OnlineDataProcessorBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Only for internal use. Continue the BeforeStart procedure.
Procedure ActionsBeforeStartAfterOverridableProcedure(NOTSpecified, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationProcessor", Parameters.CompletionProcessing);
	
	Try
		SetInterfaceFunctionalOptionParametersOnLaunch();
	Except
		ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If OnlineDataProcessorBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Only for internal use. Complete the BeforeStart procedure.
Procedure ActionsFileBeforeStartEndProcessor(NOTSpecified, Parameters) Export
	
	ParametersAtApplicationStartAndExit = ApplicationParameters["StandardSubsystems.ParametersAtApplicationStartAndExit"];
	ParametersAtApplicationStartAndExit.Delete("ReceivedClientParameters");
	
	If Parameters.CompletionAlert <> Undefined Then
		Result = New Structure;
		Result.Insert("Cancel", Parameters.Cancel);
		Result.Insert("Restart", Parameters.Restart);
		Result.Insert("AdditionalCommandLineParameters", Parameters.AdditionalCommandLineParameters);
		ExecuteNotifyProcessing(Parameters.CompletionAlert, Result);
		Return;
	EndIf;
	
	If Parameters.Cancel Then
		If Parameters.Restart <> True Then
			Terminate();
		ElsIf ValueIsFilled(Parameters.AdditionalCommandLineParameters) Then
			Terminate(Parameters.Restart, Parameters.AdditionalCommandLineParameters);
		Else
			Terminate(Parameters.Restart);
		EndIf;
		
	ElsIf Not Parameters.ContinuousExecution Then
		If ParametersAtApplicationStartAndExit.Property("ProcessingParameters") Then
			ParametersAtApplicationStartAndExit.Delete("ProcessingParameters");
		EndIf;
		AttachIdleHandler("WaitAtSystemStartHandler", 0.1, True);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OnStart

// Only for internal use. Continue the OnStart procedure.
Procedure ActionsOnStartInServiceEventHandlers(NOTSpecified, Parameters) Export

	If Parameters.Cancel Then
		ExecuteNotifyProcessing(Parameters.CompletionProcessing);
		Return;
	EndIf;
	
	EventHandlers = CommonUseClient.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnStart");
	
	HandlersCount = EventHandlers.Count();
	StartingNumber = Parameters.NextHandlerNumber;
	
	For Number = StartingNumber To HandlersCount Do
		Parameters.NextHandlerNumber = Number + 1;
		Handler = EventHandlers.Get(Number - 1);
		
		Try
			Handler.Module.OnStart(Parameters);
		Except
			ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start");
		EndTry;
		If OnlineProcessorOnStart(Parameters) Then
			Return;
		EndIf;
	EndDo;
	
	// Prepare transition to the next procedure.
	Parameters.Insert("NextHandlerNumber", 1);
	Parameters.Insert("ContinuationProcessor", New NotifyDescription(
		"ActionsAfterSystemStartInServiceEventHandlers", ThisObject, Parameters));
	
	Try
		CommonUseClientOverridable.OnStart(Parameters);
	Except
		ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start");
	EndTry;
	If OnlineProcessorOnStart(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Only for internal use. Continue the OnStart procedure.
Procedure ActionsAfterSystemStartInServiceEventHandlers(NOTSpecified, Parameters) Export

	If Parameters.Cancel Then
		ExecuteNotifyProcessing(Parameters.CompletionProcessing);
		Return;
	EndIf;
	
	EventHandlers = CommonUseClient.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\AfterSystemOperationStart");
	
	HandlersCount = EventHandlers.Count();
	StartingNumber = Parameters.NextHandlerNumber;
	
	For Number = StartingNumber To HandlersCount Do
		Parameters.NextHandlerNumber = Number + 1;
		Handler = EventHandlers.Get(Number - 1);
		
		Try
			Handler.Module.AfterSystemOperationStart();
		Except
			ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start");
		EndTry;
		If OnlineProcessorOnStart(Parameters) Then
			Return;
		EndIf;
	EndDo;
	
	Parameters.Insert("ContinuationProcessor", Parameters.CompletionProcessing);
	Try
		CommonUseClientOverridable.AfterSystemOperationStart();
	Except
		ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "Start");
	EndTry;
	If OnlineProcessorOnStart(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Only for internal use. Completion of the OnStart procedure.
Procedure ActionsOnStartCompletionProcessor(NOTSpecified, Parameters) Export
	
	If Not Parameters.Cancel Then
		ParametersAtApplicationStartAndExit = ApplicationParameters["StandardSubsystems.ParametersAtApplicationStartAndExit"];
		If ParametersAtApplicationStartAndExit.Property("SkipClearingDesktopHide") Then
			ParametersAtApplicationStartAndExit.Delete("SkipClearingDesktopHide");
		EndIf;
		HideDesktopOnStart(False);
	EndIf;
	
	If Parameters.CompletionAlert <> Undefined Then
		
		Result = New Structure;
		Result.Insert("Cancel", Parameters.Cancel);
		Result.Insert("Restart", Parameters.Restart);
		Result.Insert("AdditionalCommandLineParameters", Parameters.AdditionalCommandLineParameters);
		ExecuteNotifyProcessing(Parameters.CompletionAlert, Result);
		Return;
		
	Else
		If Parameters.Cancel Then
			If Parameters.Restart <> True Then
				Terminate();
				
			ElsIf ValueIsFilled(Parameters.AdditionalCommandLineParameters) Then
				Terminate(Parameters.Restart, Parameters.AdditionalCommandLineParameters);
			Else
				Terminate(Parameters.Restart);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Process the application start parameters.
//
// Returns:
//   Boolean   - True if it is required to break the OnBeginSystemWork procedure execution.
//
Function ProcessStartParameters()

	If IsBlankString(LaunchParameter) Then
		Return True;
	EndIf;
	
	// The parameter may consist of parts separated by character ";".
	// First part - main value of the start parameter. 
	// Presence of the additional parts is defined with main parameter processor logic.
	LaunchParameters = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(LaunchParameter, ";");
	FirstParameter = Upper(LaunchParameters[0]);
	
	Cancel = False;
	EventHandlers = CommonUseClient.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnProcessingParametersLaunch");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnProcessingParametersLaunch(FirstParameter, LaunchParameters, Cancel);
	EndDo;
	
	Cancel = CommonUseClientOverridable.ProcessStartParameters(
		FirstParameter, LaunchParameters) Or Cancel;
	
	If Not Cancel Then
		CommonUseClientOverridable.OnProcessingParametersLaunch(FirstParameter, LaunchParameters, Cancel);
	EndIf;
	
	Return Not Cancel;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// BeforeExit

// Only for internal use. Continue the procedure BeforeExit.
Procedure ActionsBeforeSystemExitInServiceEventHandlers(NOTSpecified, Parameters) Export

	If Parameters.Cancel Then
		ExecuteNotifyProcessing(Parameters.CompletionProcessing);
		Return;
	EndIf;
	
	EventHandlers = CommonUseClient.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\BeforeExit");
	
	HandlersCount = EventHandlers.Count();
	StartingNumber = Parameters.NextHandlerNumber;
	
	For Number = StartingNumber To HandlersCount Do
		Parameters.NextHandlerNumber = Number + 1;
		Handler = EventHandlers.Get(Number - 1);
		Try
			Handler.Module.BeforeExit(Parameters);
		Except
			ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "End");
		EndTry;
		If OnlineDataProcessorBeforeExit(Parameters) Then
			Return;
		EndIf;
	EndDo;
	
	Parameters.Insert("ContinuationProcessor", New NotifyDescription(
		"ActionsBeforeSystemExitAfterServiceEventHandlers", ThisObject, Parameters));
	
	Try
		CommonUseClientOverridable.BeforeExit(Parameters);
	Except
		ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "End");
	EndTry;
	If OnlineDataProcessorBeforeExit(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Only for internal use. Continue the procedure BeforeExit.
Procedure ActionsBeforeSystemExitAfterServiceEventHandlers(NOTSpecified, Parameters) Export
	
	If Parameters.Cancel Then
		ExecuteNotifyProcessing(Parameters.CompletionProcessing);
		Return;
	EndIf;
	
	// If before shutting down, there are unwritten messages for
	// the event log monitor accumulated in a variable, then they are required to write.
	ParameterName = "StandardSubsystems.MessagesForEventLogMonitor";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New ValueList);
	EndIf;
	
	If ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"].Count() <> 0 Then
		EventLogMonitorServerCall.WriteEventsToEventLogMonitor(ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	EndIf;
	
	Parameters.Insert("ContinuationProcessor", Parameters.CompletionProcessing);
	If StandardSubsystemsClientReUse.ClientWorkParameters().CanUseSeparatedData Then
		Try
			OpenOnExitMessageForm(Parameters);
		Except
			ProcessErrorOnStartOrEnd(Parameters, ErrorInfo(), "End");
		EndTry;
		If OnlineDataProcessorBeforeExit(Parameters) Then
			Return;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Only for internal use. Complete the BeforeExit procedure.
Procedure ActionsBeforeExitCompletionProcessor(NOTSpecified, Parameters) Export
	
	If Parameters.CompletionAlert <> Undefined Then
		
		Result = New Structure;
		Result.Insert("Cancel", Parameters.Cancel);
		ExecuteNotifyProcessing(Parameters.CompletionAlert, Result);
		
	ElsIf Not Parameters.Cancel AND Not Parameters.ContinuousExecution Then
		
		ApplicationParameters["StandardSubsystems.ParametersAtApplicationStartAndExit"].Insert("BeforeExitActionsExecuted");
		Exit();
	EndIf;
	
EndProcedure

// Only for internal use. Complete the BeforeExit procedure.
Procedure ActionsFileBeforeExitAfterProcessingErrors(NOTSpecified, AdditionalParameters) Export
	
	Parameters = AdditionalParameters.Parameters;
	Parameters.ContinuationProcessor = AdditionalParameters.ContinuationProcessor;
	
	If Parameters.Cancel Then
		Parameters.Cancel = False;
		ExecuteNotifyProcessing(Parameters.CompletionProcessing);
	Else
		ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions to start and close the application.

// Checks a minimum available platform version for launch.
// If the platform version is earlier than RecommendedPlatformVersion, a warning is shown to the user. Exit the application if Exit = True.
//
// Return
//  value Boolean - if version is relevant, then True, otherwise, - False.
//
Procedure CheckPlatformVersionAtStart(Parameters)
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If Not ClientParameters.Property("ShowNonrecommendedPlatformVersion") Then
		Return;
	EndIf;
	
	Parameters.InteractiveDataProcessor = New NotifyDescription(
		"PlatformVersionCheckOnlineProcessorOnStart", ThisObject, Parameters);
	
EndProcedure

// Only for internal use. Continuation of procedure CheckPlatformVersionOnLaunch.
Procedure PlatformVersionCheckOnlineProcessorOnStart(Parameters, NotSpecified) Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If ClientParameters.MustExit Then
		If ClientParameters.HasAccessForUpdateVersionsOfPlatform Then
			MessageText = NStr("en='It is impossible to log in the application.
		|It is necessary to update the 1C:Enterprise platform version previously.';ru='Вход в программу невозможен.
		|Необходимо предварительно обновить версию платформы 1С:Предприятие.'");
		Else
			MessageText = NStr("en='It is impossible to log in the application.
		|It is necessary to contact the administrator to update the 1C:Enterprise platform version.';ru='Вход в программу невозможен.
		|Необходимо обратиться к администратору для обновления версии платформы 1С:Предприятие.'");
		EndIf;
	Else
		If ClientParameters.HasAccessForUpdateVersionsOfPlatform Then
			MessageText = 
				NStr("en='It is recommended to shut the application down and update 1C:Enterprise platform version.
		|Otherwise some application possibilities will be unavailable or will work incorrectly.';ru='Рекомендуется завершить работу программы и обновить версию платформы 1С:Предприятия.
		|В противном случае некоторые возможности программы будут недоступны или будут работать некорректно.'");
		Else
			MessageText = 
				NStr("en='It is recommended to close the application and contact administrator to update 1C:Enterprise platform version.
		|Otherwise some application possibilities will be unavailable or will work incorrectly.';ru='Рекомендуется завершить работу программы и обратиться к администратору для обновления версии платформы 1С:Предприятия.
		|В противном случае некоторые возможности программы будут недоступны или будут работать некорректно.'");
		EndIf;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("MessageText", MessageText);
	FormParameters.Insert("Done", ClientParameters.MustExit);
	FormParameters.Insert("RecommendedPlatformVersion", ClientParameters.MinimallyRequiredPlatformVersion);
	FormParameters.Insert("OpenByScenario", True);
	FormParameters.Insert("SkipExit", True);
	
	Form = OpenForm("DataProcessor.NotRecommendedPlatformVersion.Form.NotRecommendedPlatformVersion", FormParameters,
		, , , , New NotifyDescription("AfterNotRecommendedPlatformVersionFormClosing", ThisObject, Parameters));
	
	If Form = Undefined Then
		AfterNotRecommendedPlatformVersionFormClosing("Continue", Parameters);
	EndIf;
	
EndProcedure

// Only for internal use. Continuation of procedure CheckPlatformVersionOnLaunch.
Procedure AfterNotRecommendedPlatformVersionFormClosing(Result, Parameters) Export
	
	If Result <> "Continue" Then
		Parameters.Cancel = True;
	Else
		Parameters.ReceivedClientParameters.Insert("ShowNonrecommendedPlatformVersion");
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Checks whether it is required to reestablish connection with the main node and starts reestablishing if required.
Procedure CheckNeedToRestoreLinkWithMainNode(Parameters)
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If Not ClientParameters.Property("RestoreConnectionWithMainNode") Then
		Return;
	EndIf;
	
	Parameters.InteractiveDataProcessor = New NotifyDescription(
		"OnlineLinkWithMainNodeRestoreProcessor", ThisObject, Parameters);
	
EndProcedure

// Only for internal use. Continued procedure CheckNecessityLinkWithMainNodeRestoration.
Procedure OnlineLinkWithMainNodeRestoreProcessor(Parameters, NotSpecified) Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If ClientParameters.RestoreConnectionWithMainNode = False Then
		Parameters.Cancel = True;
		ShowMessageBox(
			AlertWithoutResult(Parameters.ContinuationProcessor),
			NStr("en='Sign in to the application is temporarily unavailable before the restoration of connection with the main node.
		|Contact administrator for the details.';ru='Вход в программу временно невозможен до восстановления связи с главным узлом.
		|Обратитесь к администратору за подробностями.'"),
			15);
		Return;
	EndIf;
	
	Form = OpenForm("CommonForm.ConnectionWithHostRecovery",,,,,,
		New NotifyDescription("AfterLinkToMainNodeRestorationFormClose", ThisObject, Parameters));
	
	If Form = Undefined Then
		AfterLinkToMainNodeRestorationFormClose(New Structure("Cancel", True), Parameters);
	EndIf;
	
EndProcedure

// Only for internal use. Continued procedure CheckNecessityLinkWithMainNodeRestoration.
Procedure AfterLinkToMainNodeRestorationFormClose(Result, Parameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		Parameters.Cancel = True;
		
	ElsIf Result.Cancel Then
		Parameters.Cancel = True;
	Else
		Parameters.ReceivedClientParameters.Insert("RestoreConnectionWithMainNode");
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// It is called when it is required
// to open a list of active users working in the system now.
//
Procedure OpenActiveUsersList(FormParameters = Undefined) Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.UserSessions") Then
		
		FormName = "";
		DBModuleConnectionsClient = CommonUseClient.CommonModule("InfobaseConnectionsClient");
		DBModuleConnectionsClient.WhenDefiningFormsActiveUsers(FormName);
		OpenForm(FormName, FormParameters);
		
	Else
		
		ShowMessageBox(,
			NStr("en='To open a list of active users, go to
		|menu All functions - Standard - Active users.';ru='Для того чтобы открыть список активных пользователей,
		|перейдите в меню Все функции - Стандартные - Активные пользователи.'"));
		
	EndIf;
	
EndProcedure

// Sets a check box showing that the desktop
// is hidden when you start using the system that prevents from ctreating forms in the desktop.
// Clears a check box that hid the desktop and
// updates it when it is possible.
//
// Parameters:
//  Hide - Boolean. If you pass False, then desktop will
//           be shown again if the it is hidden.
//
//  AlreadyExecutedOnServer - Boolean. If True is passed, then a
//           method is already called in module StandardSubsystemsServerCall, and
//           it is not required to call but only install on
//           the client. The desktop was hidden and it is required to be shown later.
//
Procedure HideDesktopOnStart(Hide = True, AlreadyExecutedOnServer = False) Export
	
	ParametersAtApplicationStartAndExit = ApplicationParameters["StandardSubsystems.ParametersAtApplicationStartAndExit"];
	
	If Hide Then
		If Not ParametersAtApplicationStartAndExit.Property("HideDesktopOnStart") Then
			ParametersAtApplicationStartAndExit.Insert("HideDesktopOnStart");
			If Not AlreadyExecutedOnServer Then
				StandardSubsystemsServerCall.HideDesktopOnStart();
			EndIf;
		EndIf;
	Else
		If ParametersAtApplicationStartAndExit.Property("HideDesktopOnStart") Then
			ParametersAtApplicationStartAndExit.Delete("HideDesktopOnStart");
			If Not AlreadyExecutedOnServer Then
				StandardSubsystemsServerCall.HideDesktopOnStart(False);
			EndIf;
			CurrentActiveWindow = ActiveWindow();
			RefreshInterface();
			If CurrentActiveWindow <> Undefined Then
				CurrentActiveWindow.Activate();
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure ExecuteAlertWithEmptyResult(AlertWithResult) Export
	
	ExecuteNotifyProcessing(AlertWithResult);
	
EndProcedure

// Only for internal use.
Procedure StartInteractiveProcessingBeforeExit() Export
	
	ParametersAtApplicationStartAndExit = ApplicationParameters["StandardSubsystems.ParametersAtApplicationStartAndExit"];
	If Not ParametersAtApplicationStartAndExit.Property("CompletionProcessorParameters") Then
		Return;
	EndIf;
	
	Parameters = ParametersAtApplicationStartAndExit.CompletionProcessorParameters;
	ParametersAtApplicationStartAndExit.Delete("CompletionProcessorParameters");
	
	ExecuteNotifyProcessing(Parameters.InteractiveDataProcessor, Parameters);
	
EndProcedure

// Only for internal use.
Procedure AfterWarningsFormOnWorkCompletionClose(Result, AdditionalParameters) Export
	
	Parameters = AdditionalParameters.Parameters;
	
	If AdditionalParameters.FormVariant = "Question" Then
		
		If Result <> Undefined AND Result.DontAskAgain Then
			StandardSubsystemsServerCall.SaveExitConfirmationSettings(
				Not Result.DontAskAgain);
		EndIf;
		
		If Result = Undefined Or Result.Value <> DialogReturnCode.Yes Then
			Parameters.Cancel = True;
		EndIf;
		
	ElsIf AdditionalParameters.FormVariant = "StandardForm" Then
	
		If Result = True Or Result = Undefined Then
			Parameters.Cancel = True;
		EndIf;
		
	Else // AppliedForm
		If Result = True Or Result = Undefined Or Result = DialogReturnCode.No Then
			Parameters.Cancel = True;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// Returns a string presentation of type DialogReturnCode.
Function DialogReturnCodeInString(Value)
	
	Result = "DialogReturnCode." + String(Value);
	
	If Value = DialogReturnCode.Yes Then
		Result = "DialogReturnCode.Yes";
	ElsIf Value = DialogReturnCode.No Then
		Result = "DialogReturnCode.No";
	ElsIf Value = DialogReturnCode.OK Then
		Result = "DialogReturnCode.OK";
	ElsIf Value = DialogReturnCode.Cancel Then
		Result = "DialogReturnCode.Cancel";
	ElsIf Value = DialogReturnCode.Retry Then
		Result = "ReturnDialogCode.Retry";
	ElsIf Value = DialogReturnCode.Abort Then
		Result = "DialogReturnCode.Abort";
	ElsIf Value = DialogReturnCode.Ignore Then
		Result = "DialogReturnCode.Ignore";
	EndIf;
	
	Return Result;
	
EndFunction

// Set the session separation on application start.
Procedure SetSessionSeparation()

	If IsBlankString(LaunchParameter) Then
		Return;
	EndIf;
	
	LaunchParameters = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(LaunchParameter, ";");
	LaunchParameterValue = Upper(LaunchParameters[0]);
	
	If LaunchParameterValue <> Upper("LogOnDataArea") Then
		Return;
	EndIf;
	
	If LaunchParameters.Count() < 2 Then
		Raise
			NStr("en='When specifying launch parameter
		|EnterDataArea, specify a separator value as an additional parameter.';ru='При указании параметра
		|запуска ВойтиВОбластьДанных, дополнительным параметром необходимо указать значение разделителя.'");
	EndIf;
	
	Try
		SeparatorValue = Number(LaunchParameters[1]);
	Except
		Raise
			NStr("en='The separator value in the LogOnDataArea parameter must be the digit.';ru='Значением разделителя в параметре ВойтиВОбластьДанных должно быть число.'");
	EndTry;
	
	CommonUseServerCall.SetSessionSeparation(True, SeparatorValue);
	
EndProcedure 

// If denied, calls shut down
// processing. If a new received client
// parameter is added, updates the client parameters.
//
Function ContinueActionsBeforeStart(Parameters)
	
	If Parameters.Cancel Then
		ExecuteNotifyProcessing(Parameters.CompletionProcessing);
		Return False;
	EndIf;
	
	UpdateClientWorkParameters(Parameters);
	
	Return True;
	
EndFunction

// Updates client work parameters after another interactive processor on start.
Procedure UpdateClientWorkParameters(Parameters, FirstCall = False, RefreshReusableValues = True)
	
	If FirstCall Then
		ParameterName = "StandardSubsystems.ParametersAtApplicationStartAndExit";
		If ApplicationParameters[ParameterName] = Undefined Then
			ApplicationParameters.Insert(ParameterName, New Structure);
		EndIf;
	ElsIf Parameters.ReceivedClientParametersQuantity = Parameters.ReceivedClientParameters.Count() Then
		Return;
	EndIf;
	
	Parameters.Insert("ReceivedClientParametersQuantity", Parameters.ReceivedClientParameters.Count());
	
	ApplicationParameters["StandardSubsystems.ParametersAtApplicationStartAndExit"].Insert(
		"ReceivedClientParameters", Parameters.ReceivedClientParameters);
	
	If RefreshReusableValues Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

Function RunningOnlineDataProcessorBeforeStart()
	
	ParametersAtApplicationStartAndExit = ApplicationParameters["StandardSubsystems.ParametersAtApplicationStartAndExit"];
	
	If Not ParametersAtApplicationStartAndExit.Property("ProcessingParameters") Then
		Return False;
	EndIf;
	
	Parameters = ParametersAtApplicationStartAndExit.ProcessingParameters;
	
	If Parameters.InteractiveDataProcessor <> Undefined Then
		Parameters.ContinuousExecution = False;
		InteractiveDataProcessor = Parameters.InteractiveDataProcessor;
		Parameters.InteractiveDataProcessor = Undefined;
		ExecuteNotifyProcessing(InteractiveDataProcessor, Parameters);
		ParametersAtApplicationStartAndExit.Delete("ProcessingParameters");
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function OnlineDataProcessorBeforeStart(Parameters)
	
	ParametersAtApplicationStartAndExit = ApplicationParameters["StandardSubsystems.ParametersAtApplicationStartAndExit"];
	
	If Parameters.InteractiveDataProcessor = Undefined Then
		If Parameters.Cancel Then
			ExecuteNotifyProcessing(Parameters.CompletionProcessing);
			Return True;
		EndIf;
		Return False;
	EndIf;
	
	UpdateClientWorkParameters(Parameters);
	
	If Not Parameters.ContinuousExecution Then
		InteractiveDataProcessor = Parameters.InteractiveDataProcessor;
		Parameters.InteractiveDataProcessor = Undefined;
		ExecuteNotifyProcessing(InteractiveDataProcessor, Parameters);
		
	ElsIf Parameters.CompletionAlert = Undefined Then
		// It was called from handler of event
		// BeforeStart for preparing for interactive processing in the handler of event OnStart.
		
		ParametersAtApplicationStartAndExit.Insert("ProcessingParameters", Parameters);
		HideDesktopOnStart();
		ParametersAtApplicationStartAndExit.Insert("SkipClearingDesktopHide");
		SetInterfaceFunctionalOptionParametersOnLaunch();
	Else
		// It was called from procedure BeforeStart
		// for immediate interactive processing start as procedure was called applicationmatically
		// and not from the BeforeStart handler event.
		If ParametersAtApplicationStartAndExit.Property("ProcessingParameters") Then
			ParametersAtApplicationStartAndExit.Delete("ProcessingParameters");
		EndIf;
		
		Parameters.ContinuousExecution = False;
		InteractiveDataProcessor = Parameters.InteractiveDataProcessor;
		Parameters.InteractiveDataProcessor = Undefined;
		ExecuteNotifyProcessing(InteractiveDataProcessor, Parameters);
	EndIf;
	
	Return True;
	
EndFunction

Function OnlineProcessorOnStart(Parameters)
	
	If Parameters.InteractiveDataProcessor = Undefined Then
		If Parameters.Cancel Then
			ExecuteNotifyProcessing(Parameters.CompletionProcessing);
			Return True;
		EndIf;
		Return False;
	EndIf;
	
	InteractiveDataProcessor = Parameters.InteractiveDataProcessor;
	
	Parameters.ContinuousExecution = False;
	Parameters.InteractiveDataProcessor = Undefined;
	
	ExecuteNotifyProcessing(InteractiveDataProcessor, Parameters);
	
	Return True;
	
EndFunction

Function OnlineDataProcessorBeforeExit(Parameters)
	
	If Parameters.InteractiveDataProcessor = Undefined Then
		If Parameters.Cancel Then
			ExecuteNotifyProcessing(Parameters.CompletionProcessing);
			Return True;
		EndIf;
		Return False;
	EndIf;
	
	If Not Parameters.ContinuousExecution Then
		InteractiveDataProcessor = Parameters.InteractiveDataProcessor;
		Parameters.InteractiveDataProcessor = Undefined;
		ExecuteNotifyProcessing(InteractiveDataProcessor, Parameters);
		
	ElsIf Parameters.CompletionAlert = Undefined Then
		// It was called from handler of event
		// BeforeSystemExit for preparing for interactive processing using the wait handler.
		
		ApplicationParameters["StandardSubsystems.ParametersAtApplicationStartAndExit"].Insert("CompletionProcessorParameters", Parameters);
		Parameters.ContinuousExecution = False;
		AttachIdleHandler(
			"WaitHandlerInteractiveProcessingBeforeExit", 0.1, True);
	Else
		// It was called from procedure BeforeSystemExit
		// for immediate interactive processing start as procedure was called applicationmatically
		// and not from the BeforeExit handler event.
		
		Parameters.ContinuousExecution = False;
		InteractiveDataProcessor = Parameters.InteractiveDataProcessor;
		Parameters.InteractiveDataProcessor = Undefined;
		ExecuteNotifyProcessing(InteractiveDataProcessor, Parameters);
	EndIf;
	
	Return True;
	
EndFunction

// Outputs user message form during the application closing or outputs a message.
Procedure OpenOnExitMessageForm(Parameters)
	
	// Warning list is not displayed in modes web client and thick client (standard application).
#If WebClient Or ThickClientOrdinaryApplication Then
	Return;
#EndIf

	If ApplicationParameters["StandardSubsystems.SkipAlertBeforeExit"] = True Then 
		Return;
	EndIf;
	
	Warnings = New Array;
	
	EventHandlers = CommonUseClient.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnGetListOfWarningsToCompleteJobs");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnGetListOfWarningsToCompleteJobs(Warnings);
	EndDo;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Parameters", Parameters);
	AdditionalParameters.Insert("FormVariant", "Question");
	
	ResponseProcessor = New NotifyDescription("AfterWarningsFormOnWorkCompletionClose",
		ThisObject, AdditionalParameters);
	
	If Warnings.Count() = 0 Then
		
		DontAskAgain =
			Not StandardSubsystemsClientReUse.ClientWorkParameters(
				).AskConfirmationOnExit;
		
		If DontAskAgain Then
			Return;
		EndIf;
		Parameters.InteractiveDataProcessor = New NotifyDescription(
			"AskExitConfirmation", ThisObject, ResponseProcessor);
	Else
		FormParameters = New Structure;
		FormParameters.Insert("Warnings", Warnings);
		
		FormName = "CommonForm.ExitWarnings";
		
		If Warnings.Count() = 1 Then
			If Not IsBlankString(Warnings[0].FlagText) Then 
				AdditionalParameters.Insert("FormVariant", "StandardForm");
				FormOpenParameters = New Structure;
				FormOpenParameters.Insert("FormName", FormName);
				FormOpenParameters.Insert("FormParameters", FormParameters);
				FormOpenParameters.Insert("ResponseProcessor", ResponseProcessor);
				Parameters.InteractiveDataProcessor = New NotifyDescription(
					"OnlineProcessorWarningsOnWorkCompletion", ThisObject, FormOpenParameters);
			Else
				AdditionalParameters.Insert("FormVariant", "AppliedForm");
				OpenApplicationWarningForm(Parameters, ResponseProcessor, Warnings[0], FormName, FormParameters);
			EndIf;
		Else
			AdditionalParameters.Insert("FormVariant", "StandardForm");
			FormOpenParameters = New Structure;
			FormOpenParameters.Insert("FormName", FormName);
			FormOpenParameters.Insert("FormParameters", FormParameters);
			FormOpenParameters.Insert("ResponseProcessor", ResponseProcessor);
			Parameters.InteractiveDataProcessor = New NotifyDescription(
				"OnlineProcessorWarningsOnWorkCompletion", ThisObject, FormOpenParameters);
		EndIf;
	EndIf;
	
EndProcedure

// Continuation of procedure OpenWarningsFormOnExit.
Procedure OnlineProcessorWarningsOnWorkCompletion(Parameters, FormOpenParameters) Export
	
	OpenForm(
		FormOpenParameters.FormName,
		FormOpenParameters.FormParameters, , , , ,
		FormOpenParameters.ResponseProcessor);
	
EndProcedure

// Continue the ShowWarningAndContinue procedure.
Procedure ShowWarningAndContinueEnd(Result, Parameters) Export
	
	If Result <> Undefined Then
		If Result.Value = "Complete" Then
			Parameters.Cancel = True;
		ElsIf Result.Value = "Restart" Then
			Parameters.Cancel = True;
			Parameters.Restart = True;
		EndIf;
	EndIf;
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Shows a dialog box prompting the user to confirm the exit.
Procedure AskExitConfirmation(Parameters, ResponseProcessor) Export
	
	Buttons = New ValueList;
	Buttons.Add("DialogReturnCode.Yes",  NStr("en='Exit';ru='Завершить'"));
	Buttons.Add("DialogReturnCode.No", NStr("en='Cancel';ru='Отменить'"));
	
	QuestionParameters = QuestionToUserParameters();
	QuestionParameters.LockWholeInterface = True;
	QuestionParameters.DefaultButton = "DialogReturnCode.Yes";
	QuestionParameters.Title = NStr("en='Exit';ru='Завершить'");
	QuestionParameters.DontAskAgain = False;
	
	ShowQuestionToUser(ResponseProcessor, NStr("en='Do you want to exit the application?';ru='Завершить работу с программой?'"), Buttons, QuestionParameters);
	
EndProcedure

// Generates the display of one question.
//
//	If property HyperlinkText exists in UserWarning, then IndividualOpeningForm
//	is opened from the question Structure.
//	If "CheckBoxText" property exists in UserWarning, then
//	form "CommonForm opens.QuestionBeforeExit".
//
//	Parameters:
//	 Parameters - parameters to repeat of call chain of procedure BeforeSystemExit.
//	 ResponseProcessor - NotificationDescription to continue once the user response is received.
//	 UserWarning - Structure - structure of the passed warning.
//	 FormName - String - common form name with questions.
//	 FormParameters - Structure - parameters for form with questions.
//
Procedure OpenApplicationWarningForm(Parameters, ResponseProcessor, UserWarning, FormName, FormParameters)
	
	HyperlinkText = "";
	If Not UserWarning.Property("HyperlinkText", HyperlinkText) Then
		Return;
	EndIf;
	If IsBlankString(HyperlinkText) Then
		Return;
	EndIf;
	
	ActionOnHyperlinkClick = Undefined;
	If Not UserWarning.Property("ActionOnHyperlinkClick", ActionOnHyperlinkClick) Then
		Return;
	EndIf;
	
	ActionHyperlink = UserWarning.ActionOnHyperlinkClick;
	Form = Undefined;
	
	If ActionHyperlink.Property("ApplicationWarningForm", Form) Then
		FormParameters = Undefined;
		If ActionHyperlink.Property("ApplicationWarningFormParameters", FormParameters) Then
			If TypeOf(FormParameters) = Type("Structure") Then 
				FormParameters.Insert("ExitApplication", True);
			ElsIf FormParameters = Undefined Then 
				FormParameters = New Structure;
				FormParameters.Insert("ExitApplication", True);
			EndIf;
			
			FormParameters.Insert("YesButtonTitle",  NStr("en='Complete';ru='Закончить редактирование'"));
			FormParameters.Insert("TitleNoButton", NStr("en='Cancel';ru='Отменить'"));
			
		EndIf;
		FormOpenParameters = New Structure;
		FormOpenParameters.Insert("FormName", Form);
		FormOpenParameters.Insert("FormParameters", FormParameters);
		FormOpenParameters.Insert("ResponseProcessor", ResponseProcessor);
		Parameters.InteractiveDataProcessor = New NotifyDescription(
			"OnlineProcessorWarningsOnWorkCompletion", ThisObject, FormOpenParameters);
		
	ElsIf ActionHyperlink.Property("Form", Form) Then 
		FormParameters = Undefined;
		If ActionHyperlink.Property("FormParameters", FormParameters) Then
			If TypeOf(FormParameters) = Type("Structure") Then 
				FormParameters.Insert("ExitApplication", True);
			ElsIf FormParameters = Undefined Then 
				FormParameters = New Structure;
				FormParameters.Insert("ExitApplication", True);
			EndIf;
		EndIf;
		FormOpenParameters = New Structure;
		FormOpenParameters.Insert("FormName", Form);
		FormOpenParameters.Insert("FormParameters", FormParameters);
		FormOpenParameters.Insert("ResponseProcessor", ResponseProcessor);
		Parameters.InteractiveDataProcessor = New NotifyDescription(
			"OnlineProcessorWarningsOnWorkCompletion", ThisObject, FormOpenParameters);
		
	EndIf;
	
EndProcedure

Procedure ProcessErrorOnStartOrEnd(Parameters, ErrorInfo, Event, StopWork = False)
	
	If Event = "Start" Then
		If StopWork Then
			Parameters.Cancel = True;
			Parameters.ContinuationProcessor = Parameters.CompletionProcessing;
		EndIf;
	Else
		AdditionalParameters = New Structure(
			"Parameters, ContinuationProcessor", Parameters, Parameters.ContinuationProcessor);
		
		Parameters.ContinuationProcessor = New NotifyDescription(
			"ActionsFileBeforeExitAfterProcessingErrors", ThisObject, AdditionalParameters);
	EndIf;
	
	ErrorDescriptionBegin = StandardSubsystemsServerCall.WriteErrorToEventLogMonitorAtStartOrExit(
		StopWork, Event, DetailErrorDescription(ErrorInfo));	
	
	WarningText = ErrorDescriptionBegin + Chars.LF
		+ NStr("en='Error details are written to the event log monitor.';ru='Техническая информация об ошибке записана в журнал регистрации.'")
		+ Chars.LF + Chars.LF
		+ BriefErrorDescription(ErrorInfo);
	
	InteractiveDataProcessor = New NotifyDescription(
		"ShowWarningAndContinue",
		StandardSubsystemsClient.ThisObject,
		WarningText);
	
	Parameters.InteractiveDataProcessor = InteractiveDataProcessor;
	
EndProcedure

Procedure SetInterfaceFunctionalOptionParametersOnLaunch()
	InterfaceOptions = StandardSubsystemsClientReUse.ClientWorkParametersOnStart().InterfaceOptions;
	If TypeOf(InterfaceOptions) = Type("FixedStructure") Then
		#If WebClient Then
			Structure = New Structure;
			CommonUseClientServer.ExpandStructure(Structure, InterfaceOptions, True);
			InterfaceOptions = Structure;
		#Else
			InterfaceOptions = New Structure(InterfaceOptions);
		#EndIf
	EndIf;
	// Setting of the functional options parameters is executed only when they are specified.
	If InterfaceOptions.Count() > 0 Then
		SetInterfaceFunctionalOptionParameters(InterfaceOptions);
	EndIf;
	
EndProcedure

Procedure ShowFilePlaceWhenConnectingFileExtensions(ExtensionAttached, AdditionalParameters) Export
	
	EndProcessor = AdditionalParameters.EndProcessor;
	FormID = AdditionalParameters.FormID;
	InitialFileName = AdditionalParameters.InitialFileName;
	DialogueParameters = AdditionalParameters.DialogueParameters;
	
	If Not ExtensionAttached Then
		Handler = New NotifyDescription("ProcessFilePlacingResult", ThisObject, EndProcessor);
		BeginPutFile(Handler, , InitialFileName, True, FormID);
		Return;
	EndIf;
	
	If DialogueParameters = Undefined Then
		DialogueParameters = New Structure;
	EndIf;
	If DialogueParameters.Property("Mode") Then
		Mode = DialogueParameters.Mode;
		If Mode = FileDialogMode.ChooseDirectory Then
			Raise NStr("en='Catalog selection is not supported';ru='Выбор каталога не поддерживается'");
		EndIf;
	Else
		Mode = FileDialogMode.Open;
	EndIf;
	
	Dialog = New FileDialog(Mode);
	Dialog.FullFileName = InitialFileName;
	FillPropertyValues(Dialog, DialogueParameters);
	
	NotifyDescription = New NotifyDescription("ProcessFilesPlacingResult", ThisObject, EndProcessor);
	
	If FormID <> Undefined Then
		BeginPuttingFiles(NOTifyDescription, , Dialog, True, FormID);
	Else
		BeginPuttingFiles(NOTifyDescription, , Dialog, True);
	EndIf;
	
EndProcedure

Procedure ProcessFilesPlacingResult(PlacedFiles, EndProcessor) Export
	SelectionComplete = PlacedFiles <> Undefined;
	ProcessFilePlacingResult(SelectionComplete, PlacedFiles, Undefined, EndProcessor);
EndProcedure

Procedure ProcessFilePlacingResult(SelectionComplete, AddressOrChoiceResult, SelectedFileName, EndProcessor) Export
	If SelectionComplete = True Then
		If TypeOf(AddressOrChoiceResult) = Type("Array") Then
			PlacedFiles = AddressOrChoiceResult;
		Else
			FileDescription = New Structure;
			FileDescription.Insert("Location", AddressOrChoiceResult);
			FileDescription.Insert("Name",      SelectedFileName);
			PlacedFiles = New Array;
			PlacedFiles.Add(FileDescription);
		EndIf;
	Else
		PlacedFiles = Undefined;
	EndIf;
	
	ExecuteNotifyProcessing(EndProcessor, PlacedFiles);
EndProcedure

#EndRegion