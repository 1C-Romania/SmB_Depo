////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Client procedures and functions of the general purpose.:
// - for work with lists in forms;
// - for work with the events log monitor;
// - for user's actions processor in the
//   process of multiline text editing, for example, comment in documents;
// - miscellaneous.
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Work functions with lists in forms.

// Checks if the object of the ExpectedType expected type is passed in the Parameter command parameter.
// Otherwise, shows a standard message and returns False.
// Such situation is possible, for example if the grouping row is selected in list.
//
// For use in commands working with items of dynamic lists in forms.
// Useful example:
// 
//   If NOT CheckCommandParameterType(Items.List.SelectedRows,
//      Type(TaskRef.PerformerTask)) Then
//      Return;
//   EndIf;
//   ...
// 
// Parameters:
//  Parameter     - Array or reference type - command parameter.
//  ExpectedType - Type                      - expected parameter type.
//
// Returns:
//  Boolean - True if the parameter is of the expected type.
//
Function CheckCommandParameterType(Val Parameter, Val ExpectedType) Export
	
	If Parameter = Undefined Then
		Return False;
	EndIf;
	
	Result = True;
	
	If TypeOf(Parameter) = Type("Array") Then
		// If there is one item in the array and it is of the wrong type...
		Result = Not (Parameter.Count() = 1 AND TypeOf(Parameter[0]) <> ExpectedType);
	Else
		Result = TypeOf(Parameter) = ExpectedType;
	EndIf;
	
	If Not Result Then
		ShowMessageBox(,NStr("en='Action cannot be executed for the selected item.';ru='Действие не может быть выполнено для выбранного элемента.'"));
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Client procedures of the general purpose.

// Returns the current date adjusted to the time zone of the session.
//
// Function returns the time close to the result of the CurrentSessionDate() function in the server context.
// Error occurred due to time of the server call execution.
// It is intended to use instead of the function CurrentDate().
//
Function SessionDate() Export
	Return CurrentDate() + StandardSubsystemsClientReUse.ClientWorkParameters().SessionTimeOffset;
EndFunction

// Returns universal session date received from the current session date.
//
// Function returns the time close to the result of the UniversalFunction() function in the server context.
// Error occurred due to time of the server call execution.
// Designed to use instead of the UniversalTime() function.
//
Function UniversalDate() Export
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
	SessionDate = CurrentDate() + ClientWorkParameters.SessionTimeOffset;
	Return SessionDate + ClientWorkParameters.AdjustmentToUniversalTime;
EndFunction

// Suggests the user to install the file system extension in the web client.
//
// Is intended to be used at the beginning of a script that processes files.
// For example:
//
//    Notification = New NotifyDescription("PrintDocumentCompletion", ThisObject);
//    MessageText = NStr("en='Document printing requires the file system extension to be installed.'");
//    CommonUseClient.ShowFileSystemExtensionInstallationQuestion(Notification, MessageText);
//
//    Procedure PrintDocumentCompletion(ExtensionAttached, AdditionalParameters) Export
//    If ExtensionAttached Then 
//      // script that prints a document using the extension
//      // ....
//    Else
//      // script that prints a document without extension attaching
//      // ....
//    EndIf;
//
// Parameters:
//    NotifyOnCloseDescription    - NotifyDescription - description of the procedure to be
//                                  called once the form is closed. Contains the following
//                                  parameters:
//                                   ExtensionAttached    - Boolean - True if the extension has
//                                                          been attached.
//                                   AdditionalParameters - Arbitrary - parameters defined in
//                                                          OnCloseNotifyDescription.
//    SuggestionText              - String - message text. If text is not specified, the
//                                  default text is displayed.
//   CanContinueWithoutInstalling - Boolean - if True is passed, the ContinueWithoutInstalling
//                                  button is shown, if False is passed, the Cancel button is
//                                  shown.
//
Procedure  ShowFileSystemExtensionInstallationQuestion(NotifyOnCloseDescription,  SuggestionText = "", 
	CanContinueWithoutInstalling = True) Export
	
	Notification = New NotifyDescription("ShowFileSystemExtensionInstallationQuestionCompletion", ThisObject, NotifyOnCloseDescription);
#If Not WebClient Then
	// In thin and thick clients the extension is always attached
	ExecuteNotifyProcessing(Notification);
	Return;
#EndIf
	
	// If the extension is already installed, there is no need to ask about it
	ExtensionAttached =  AttachFileSystemExtension();
	If ExtensionAttached Then 
		ExecuteNotifyProcessing(Notification);
		Return;
	EndIf;
	
	FirstCallInSession = (SuggestFileSystemExtensionInstallation = Undefined);
	If FirstCallInSession Then
		SuggestFileSystemExtensionInstallation = SuggestFileSystemExtensionInstallation();
	EndIf;
	
	If CanContinueWithoutInstalling And Not SuggestFileSystemExtensionInstallation Then
		ExecuteNotifyProcessing(Notification);
		Return;
	EndIf;
	
	If Not CanContinueWithoutInstalling Or FirstCallInSession Then
		FormParameters = New Structure;
		FormParameters.Insert("SuggestionText", SuggestionText);
		FormParameters.Insert("CanContinueWithoutInstalling", CanContinueWithoutInstalling);
		OpenForm("CommonForm.QuestionAboutFileOperationsExtensionSetting", FormParameters,,,,,Notification);
	Else
		ExecuteNotifyProcessing(Notification);
	EndIf;
	
EndProcedure

// Offers a user to enable the extension of
// work with files in the web client and in case of denial outputs a warning saying that the operation can not be continued.
//
// It is intended for use in the beginning of code fragments where
// work with files is executed only if the extension is enabled.
// ForExample:
//
//    Notification = New NotifyDescription("PrintDocumentEnd", ThisObject);
//    MessageText = NStr("en='To print the document, install the file operation extension.';ru='Для печати документа необходимо установить расширение работы с файлами.'");
//    CommonUseClient.CheckFileOperationsExtensionEnabled(Alert, MessageText);
//
//    Procedure DocumentPrintEnd (Result,
//         AdditionalParameters) Export document print//ing code counting on the fact that extension is enabled.
//         ...
//
// Parameters:
//  OnCloseNotifyDescription - NotifyDescription - description of the procedure that will
//                                                     be called if the extension is enabled with the following parameters:
//                                                      Result               - Boolean - always True.
//                                                      AdditionalParameters - Undefined
//  SuggestionText    - String - text with the offer to enable extension of work with files. 
//                                 If not specified the text is displayed by default.
//  WarningText - String - warning text saying that it is impossibile to continue operation. 
//                                 If not specified the text is displayed by default.
//
// Returns:
//  Boolean - True if the extension is enabled.
//   
Procedure CheckFileOperationsExtensionConnected(OnCloseNotifyDescription, Val SuggestionText = "", 
	Val WarningText = "") Export
	
	Parameters = New Structure("WarningAboutClosingDescription, WarningText", 
		OnCloseNotifyDescription, WarningText, );
	Notification = New NotifyDescription("CheckFileOperationsExtensionConnectedEnd", ThisObject, Parameters);
	ShowFileSystemExtensionInstallationQuestion(Notification, SuggestionText);
	
EndProcedure

// Returns the "Offer extension setting of work with files" custom setting.
//
// Returns:
//   Boolean
//
Function SuggestFileSystemExtensionInstallation() Export
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	Return CommonUseServerCall.CommonSettingsStorageImport(
		"ApplicationSettings/OfferFileOperationsExtensionSetting", ClientID, True);
		
EndFunction	
	
// Registers comcntr component.dll for current platform version.
// IN case the registration is successful, it offers the user to restart the client session for the registration to come into effect.
// 
// Called before the client code that is
// used by COM-connections manager (V83.COMConnector)  and initialized by the interactive user action. ForExample:
// 
// RegisterCOMConnector();
//   // next comes the code using COM-connection manager (V83.COMConnector).
//    ...
//
Procedure RegisterCOMConnector(Val ExecuteSessionReboot = True) Export
	
#If Not WebClient Then
	
	If ClientConnectedViaWebServer() Then
		Return;
	EndIf;
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
	
	If ClientWorkParameters.ThisIsBasicConfigurationVersion
		Or ClientWorkParameters.IsEducationalPlatform Then
		Return;
	EndIf;
	
	CommandText = "regsvr32.exe /n /i:user /s comcntr.dll";
	
	ReturnCode = Undefined;
	RunApp(CommandText, BinDir(), True, ReturnCode);
	
	If ReturnCode = Undefined Or ReturnCode > 0 Then
		
		MessageText = NStr("en='An error occurred when registering component comcntr.';ru='Ошибка при регистрации компоненты comcntr.'") + Chars.LF
			+ NStr("en='Regsvr32 error code:';ru='Код ошибки regsvr32:'") + " " + ReturnCode;
			
		If ReturnCode = 5 Then
			MessageText = MessageText + " " + NStr("en='Insufficient access rights.';ru='Недостаточно прав доступа.'");
		EndIf;
		
		EventLogMonitorClient.AddMessageForEventLogMonitor(
			NStr("en='Comcntr component registration';ru='Регистрация компоненты comcntr'", CommonUseClientServer.MainLanguageCode()), "Error", MessageText);
		EventLogMonitorServerCall.WriteEventsToEventLogMonitor(ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
		ShowMessageBox(,MessageText + Chars.LF + NStr("en='See details in log.';ru='Подробности см. в Журнале регистрации.'"));
	ElsIf ExecuteSessionReboot Then
		Notification = New NotifyDescription("RegisterCOMConnectorEnd", ThisObject);
		QuestionText = NStr("en='To finish registration of comcntr component, you should restart application.
		|Restart now?';ru='Для завершения перерегистрации компоненты comcntr необходимо перезапустить программу.
		|Перезапустить?'");
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo);
	EndIf;
	
#EndIf
	
EndProcedure

// Returns True if client application is connected to the base via the web server.
//
Function ClientConnectedViaWebServer() Export
	
	Return Find(Upper(InfobaseConnectionString()), "WS=") = 1;
	
EndFunction

// Prompts whether the action that results in loss of changes should be continued
// For use in the BeforeClosing event handler of forms modules.
//  
// Parameters:
//  AlertSaveAndClose  - NotifyDescription - contains the name of the procedure that is called when you click the OK button.
//  Cancel                        - Boolean - return parameter, shows that you canceled the executed action.
//  WarningText          - String - overridable alert text displayed to user.
//  
// Example: 
//  Notification = New NotifyDescription("ChooseAndClose", ThisObject);
//  CommonUseClient.ShowFormClosingConfirmation(Alert, Denial);
//  
//  &OnClient
//  Procedure SelectAndClose (Result = Undefined, AdditionalParameters
//  = Undefined) Export write form data.
// //     ...
//     Modified = False; do not output confirmation about form closing again.
//     Close(<SelectionResultInForm>);
//  EndProcedure
//
Procedure ShowFormClosingConfirmation(AlertSaveAndClose, Cancel, WarningText = "") Export
	
	Form = AlertSaveAndClose.Module;
	If Not Form.Modified Then
		Return;
	EndIf;
	
	Cancel = True;
	
	Parameters = New Structure();
	Parameters.Insert("AlertSaveAndClose", AlertSaveAndClose);
	Parameters.Insert("WarningText", WarningText);
	
	ParameterName = "StandardSubsystems.CloseFormValidationSettings";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters["StandardSubsystems.CloseFormValidationSettings"] = Parameters;
	
	AttachIdleHandler("ConfirmFormClosingNow", 0.1, True);
	
EndProcedure

// Prompts whether the action that results in closing the form should be continued.
// For use in the BeforeClosing event handler of forms modules.
//
// Parameters:
//  Form                        - ManagedForm - form that calls a warning dialog.
//  Cancel                        - Boolean - return parameter, shows that you canceled the executed action.
//  WarningText          - String - warning text displayed to a user.
//  AttributeNameCloseFormWithoutConfirmation - String - name of attribute containing the flag showing
//                                 whether it is required to display the warning.
//  AlertDescriptionClose    - NotifyDescription - contains the name of the procedure that is called when you click the yes button.
//
// Example: 
//  WarningText = NStr("en='Close wizard?';ru='Закрыть помощник?'");
//  CommonUseClient.ShowCustomFormClosingConfirmation(
//      ThisObject, Denial, AlertText, CloseFormWithoutConfirmation);
//
Procedure ShowArbitraryFormClosingConfirmation(Form, Cancel, WarningText,
	AttributeNameCloseFormWithoutConfirmation, AlertDescriptionClose = Undefined) Export
	
	If Form[AttributeNameCloseFormWithoutConfirmation] Then
		Return;
	EndIf;
	
	Cancel = True;
	
	Parameters = New Structure();
	Parameters.Insert("Form", Form);
	Parameters.Insert("WarningText", WarningText);
	Parameters.Insert("AttributeNameCloseFormWithoutConfirmation", AttributeNameCloseFormWithoutConfirmation);
	Parameters.Insert("AlertDescriptionClose", AlertDescriptionClose);
	
	ParameterName = "StandardSubsystems.CloseFormValidationSettings";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters["StandardSubsystems.CloseFormValidationSettings"] = Parameters;
	
	AttachIdleHandler("ConfirmArbitraryFormClosingNow", 0.1, True);
	
EndProcedure

// Function receives the style color by the name of style item.
//
// Parameters:
// StyleColorName - String with the item name.
//
// Returns - style color.
//
Function StyleColor(StyleColorName) Export
	
	Return CommonUseClientReUse.StyleColor(StyleColorName);
	
EndFunction

// Function receives the style font by the name of style item.
//
// Parameters:
// StyleFontName - String with the item name.
//
// Returns - font style.
//
Function StyleFont(StyleFontName) Export
	
	Return CommonUseClientReUse.StyleFont(StyleFontName);
	
EndFunction

// Executes transition of reference to infobase object or an external object.
// (for example, reference to website or path to folder).
//
// Parameters:
// Ref - String - ref for transition.
//
Procedure NavigateToLink(Ref) Export
	
	#If ThickClientOrdinaryApplication Then
		RunApp(Ref);
	#Else
		GotoURL(Ref);
	#EndIf
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for events processor and call of optional subsystems.

// Returns True if "functional" subsystem exists in the configuration.
// It is intended to implement at the call of optional subsystem (conditional call).
//
// Clear the Include in command interface check box in “functional” subsystem.
//
// Parameters:
//  SubsystemFullName - String - full name of the
//                        metadata object subsystem without words Subsystem.and taking into account characters register.
//                        For example, StandardSubsystems.ReportsVariants.
//
// Example:
//
//  If CommonUse.SubsystemExists(StandardSubsystems.ReportsVariants)
//  	Then ModuleReportsVariantsClient = CommonUseClient.CommonModule("ReportsVariantsClient");
//  	ModuleReportsVariantsClient.<Method name>();
//  EndIf;
//
// Returns:
//  Boolean.
//
Function SubsystemExists(SubsystemFullName) Export
	
	NamesSubsystems = StandardSubsystemsClientReUse.ClientWorkParametersOnStart().NamesSubsystems;
	Return NamesSubsystems.Get(SubsystemFullName) <> Undefined;
	
EndFunction

// It returns a reference to the common module by name.
//
// Parameters:
//  Name          - String - common module name, for example:
//                 "CommonUse",
//                 "CommonUseClient".
//
// Returns:
//  CommonModule.
//
Function CommonModule(Name) Export
	
	Module = Eval(Name);
	
#If Not WebClient Then
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Common module ""%1"" was not found.';ru='Общий модуль ""%1"" не найден.'"), Name);
	EndIf;
#EndIf
	
	Return Module;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for users actions processor in
// the process of multiline text editing, for example, comment in documents.

// Opens form of editing custom multiline text.
//	
// Parameters:
//  ClosingAlert     - NotifyDescription - contains the description of the procedure
//                            that will be called after closing the text input form with the same
//                            parameters and for the ShowStringInput method.
//  MultilineText      - String - custom text that should be edited;
//  Title               - String - text that should be displayed in the form title.
//	
// Example:
//	
//   Notification = New NotifyDescription("CommentEndInput", ThisObject);
//   CommonUseClient.ShowMultilineTextEditingForm(Alert,Item.EditText);
//	
//   &OnClient
//   Procedure OutputEndComment(Val EnteredText, Val
//   AdditionalParameters) Export If EnteredText =
// 	   Undefined Then Return;
//   	EndIf;	
//	
//    Object.MultilineComment = InputText;
//    Modified = True;
//   EndProcedure
//
Procedure ShowMultilineTextEditingForm(Val ClosingAlert, 
	Val MultilineText, Val Title = Undefined) Export
	
	If Title = Undefined Then
		ShowInputString(ClosingAlert, MultilineText,,, True);
	Else
		ShowInputString(ClosingAlert, MultilineText, Title,, True);
	EndIf;
	
EndProcedure

// Opens the edit form of the multiline comment.
//
// Parameters:
//  MultilineText      - String - custom text that should be edited.
//  OwnerForm 			- ManagedForm - form in the field of which the comment input is executed.
//  AttributeName            - String - attribute form name where a comment entered
//                                     by user will be put.
//  Title               - String - text that should be displayed in the form title.
//                                     Default: Comment.
//
// Useful example:
//
//  CommonUseClient.ShowCommentEditingForm(Item.EditText, ThisObject, Object.Comment);
//
Procedure ShowCommentEditingForm(Val MultilineText, Val OwnerForm, Val AttributeName, 
	Val Title = Undefined) Export
	
	AdditionalParameters = New Structure("OwnerForm,AttributeName", OwnerForm, AttributeName);
	Notification = New NotifyDescription("CommentEndInput", ThisObject, AdditionalParameters);
	FormTitle = ?(Title <> Undefined, Title, NStr("en='Note';ru='Примечание'"));
	ShowMultilineTextEditingForm(Notification, MultilineText, FormTitle);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to execute backup in the user mode.

// Checks if it is possible to execute backup in the user mode.
//
// Return value: Boolean.
//
Function OfferToCreateBackups() Export
	
	Result = False;
	
	EventHandlers = ServiceEventProcessor("StandardSubsystems.BasicFunctionality\WhenVerifyingBackupPossibilityInUserMode");
	
	For Each Handler IN EventHandlers Do
		
		Handler.Module.WhenVerifyingBackupPossibilityInUserMode(Result);
		
	EndDo;
	
	Return Result;
	
EndFunction

// Offers the user to create a backup.
//
Procedure OfferUserToBackup() Export
	
	EventHandlers = ServiceEventProcessor("StandardSubsystems.BasicFunctionality\WhenUserIsOfferedToBackup");
	
	For Each Handler IN EventHandlers Do
		
		Handler.Module.WhenUserIsOfferedToBackup();
		
	EndDo;
	
EndProcedure


// UseModality

////////////////////////////////////////////////////////////////////////////////
// Outdated applications and functions that use modal windows.

// Outdated. You should use ShowQuestionOnFileOperationsExtensionSetting.
// Offers a user to set extension of work with files in the web client.
// When this Initializes a Parameter session SuggestFileSystemExtensionInstallation.
//   
// It is intended for use in the beginning of code fragments where work with files is executed.
// ForExample:
//   
//    OfferSettingFileOperationsExtension(To print a document, it is required to set extension of work with files.);
//    // document printing code is
//    located next //...
//   
// Message
//  Parameters  - String - message type. If not specified the text is displayed by default.
//   
// Returns:
//  String - possible values:
//           Attached                - extension
//           is enabled NotEnabled              - user canceled the
// UnsupportedWebClient connection - extension can not be enabled as it is not supported in the web client
//   
Function SuggestInstallationOfExtensionOfFileOperationsNow(SuggestionText = Undefined) Export
	
#If WebClient Then
	ExtensionAttached = AttachFileSystemExtension();
	If ExtensionAttached Then
		Return "Attached"; // if there is an extension, you do not need to ask about it.
	EndIf;
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	
	FirstCallInSession = ApplicationParameters["StandardSubsystems.SuggestFileSystemExtensionInstallation"] = Undefined;
	
	ParameterName = "StandardSubsystems.SuggestFileSystemExtensionInstallation";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, SuggestFileSystemExtensionInstallation());
	EndIf;
	
	If Not ApplicationParameters["StandardSubsystems.SuggestFileSystemExtensionInstallation"] Then
		Return ?(ExtensionAttached, "Attached", "NotAttached");
	EndIf;
	
	If FirstCallInSession Then
		FormParameters = New Structure("Message,PossibleToContinueWithoutInstallation", SuggestionText, True);
		ReturnCode = OpenFormModal("CommonForm.QuestionAboutFileOperationsExtensionSetting", FormParameters);
		If ReturnCode = Undefined Then
			ReturnCode = True;
		EndIf;
		
		ApplicationParameters["StandardSubsystems.SuggestFileSystemExtensionInstallation"] = ReturnCode;
		CommonUseServerCall.CommonSettingsStorageSave(
			"ApplicationSettings/OfferFileOperationsExtensionSetting", ClientID,
			ApplicationParameters["StandardSubsystems.SuggestFileSystemExtensionInstallation"]);
	EndIf;
	Return ?(AttachFileSystemExtension(), "Attached", "NotAttached");
	
#Else
	Return "Attached";
#EndIf
	
EndFunction

// Outdated. You should use CheckFileOperationsExtensionEnabled.
// Offers a user to enable the extension of
// work with files in the web client and in case of denial outputs a warning saying that the operation can not be continued.
//
// It is intended for use in the beginning of code fragments where
// work with files is executed only if the extension is enabled.
// ForExample:
//
//    If Not FileOperationsExtensionEnabled (To print the document, it is required to
//      set extension of work with files) Then Return;
//    EndIf; 
//    // document printing code is
//    located next //...
//
// Parameters
//  SuggestionText    - String - text with the offer to enable extension of work with files. 
//                                 If not specified the text is displayed by default.
//  WarningText - String - warning text saying that it is impossibile to continue operation. 
//                                 If not specified the text is displayed by default.
//
// Returns:
//  Boolean - True if the extension is enabled.
//   
Function FileOperationsExtensionConnected(SuggestionText = Undefined, WarningText = Undefined) Export
	
	Result = SuggestInstallationOfExtensionOfFileOperationsNow(SuggestionText);
	MessageText = "";
	If Result = "NotAttached" Then
		If WarningText <> Undefined Then
			MessageText = WarningText;
		Else
			MessageText = NStr("en='Action is not available as file operation extension is not connected in Web client.';ru='Действие недоступно, так как не подключено расширение работы с файлами в Веб-клиенте.'")
		EndIf;
	EndIf;
	If Not IsBlankString(MessageText) Then
		ShowMessageBox(,MessageText);
	EndIf;
	Return Result = "Attached";
	
EndFunction

// Outdated. You should use ShowFormClosingConfirmation or ShowCustomFormClosingConfirmation.
// Prompts whether the action that results in loss of changes should be continued
//
// Parameters:
//  Cancel               - Boolean - return parameter, shows that you canceled the executed action;
//  Modified  - Boolean - shows that form is modified from which this procedure is called;
//  ActionSelected     - Boolean - shows that the user selected action leading to the form closing;
//  WarningText - String - text of the dialog with the user.
//
Procedure RequestCloseFormConfirmation(Cancel, Modified = True, ActionSelected = False, WarningText = "") Export
	
	If ActionSelected = True Or Not Modified Then 
		Return;
	EndIf;
	
	QuestionText = ?(IsBlankString(WarningText), 
		NStr("en='Data is changed, changes will be canceled.
		|Cancel and close?';ru='Данные были изменены, внесенные изменения будут отменены.
		|Отменить и закрыть?'"),
		WarningText);
	Result = DoQueryBox(QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No, 
		NStr("en='Cancel changes';ru='Отменить изменения'"));
		
	If Result = DialogReturnCode.No Then
		Cancel = True;
	EndIf;
	
EndProcedure

// Outdated.
// Allows to select the time from the dropdown list.
//
// Parameters:
//  Form - managed form / form - form where item
//                                      is located for which the
//  FormInputField time will be chosen -  FormField - item-owner of
//                                list which will show the
//  drop-down list of times values CurrentValue - Date - value to which the dropdown
//  list will be positioned - Number - time interval (in seconds) with which the list should be filled in, default value is an hour
//
// Returns:
//   Number - time value in seconds. Or Undefined if a user refused selection.
//
Function ChooseTime(Form, FormInputField, Val CurrentValue, Interval = 3600) Export
	
	WorkingDayBeginning      = '00010101000000';
	WorkingDayEnd   = '00010101235959';
	
	TimeList = New ValueList;
	WorkingDayBeginning = BegOfHour(BegOfDay(CurrentValue) +
		Hour(WorkingDayBeginning) * 3600 +
		Minute(WorkingDayBeginning)*60);
	WorkingDayEnd = EndOfHour(BegOfDay(CurrentValue) +
		Hour(WorkingDayEnd) * 3600 +
		Minute(WorkingDayEnd)*60);
	
	ListTime = WorkingDayBeginning;
	
	While BegOfHour(ListTime) <= BegOfHour(WorkingDayEnd) Do
		
		If Not ValueIsFilled(ListTime) Then
			TimePresentation = "00:00";
		Else
			TimePresentation = Format(ListTime,"DF=HH:mm");
		EndIf;
		
		TimeList.Add(ListTime, TimePresentation);
		
		ListTime = ListTime + Interval;
		
	EndDo;
	
	InitialValue = TimeList.FindByValue(CurrentValue);
	
	If InitialValue = Undefined Then
		SelectedTime = Form.ChooseFromList(TimeList, FormInputField);
	Else
		SelectedTime = Form.ChooseFromList(TimeList, FormInputField, InitialValue);
	EndIf;
	
	If SelectedTime = Undefined Then
		Return Undefined;
	EndIf;
	
	Return SelectedTime.Value;
	
EndFunction

// Outdated. You should use ShowMultilineTextEditingForm.
// Opens the modally editing form of the custom multiline text.
//
// Parameters:
//  MultilineText      - String - custom text that should be edited;
//  EditResult - String - editing result will be put to this parameter;
//  Modified      - String - modified form check box;
//  Title               - String - text that should be displayed in the form title.
//
Procedure OpenMultilineTextEditForm(Val MultilineText, EditResult, Modified = False, 
		Val Title = Undefined) Export
	
	If Title = Undefined Then
		TextEntered = InputString(MultilineText,,, True);
	Else
		TextEntered = InputString(MultilineText, Title,, True);
	EndIf;
	
	If Not TextEntered Then
		Return;
	EndIf;
		
	EditResult = MultilineText;
	If Not Modified Then
		Modified = True;
	EndIf;
	
EndProcedure

// Outdated. You should use ShowCommentEditingForm.
// Opens form of modally editing the multiline text.
//
// Parameters:
//  MultilineText      - String - custom text that
//  should be edited EditResult - String - variable to which the
//  Modified editing result will be put       - String - modified form check box
//
// Useful example:
//  OpenCommentEditForm(Item.EditText, Object.Comment, Modified);
//
Procedure OpenCommentEditForm(Val MultilineText, EditResult,
	Modified = False) Export
	
	OpenMultilineTextEditForm(MultilineText, EditResult, Modified, 
		NStr("en='Note';ru='Примечание'"));
	
EndProcedure

// End ModalityUse

#EndRegion

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Receive handlers of the client events.

// Returns the handlers of the specified client event.
//
// Parameters:
//  Event  - String,
//             for example, StandardSubsystems.BasicFunctionality\OnStart.
//
// Returns:
//  FixedArray with the type values.
//    FixedStructure with properties:
//     * Version - String      - handler version, for example, "2.1.3.4". Empty row if not specified.
//     * Module - CommonModule - server common module.
// 
Function EventHandlers(Event) Export
	
	Return StandardSubsystemsClientReUse.HandlersForClientEvents(Event, False);
	
EndFunction

// Returns handlers of the specified client server event.
//
// Parameters:
//  Event  - String,
//             for example, StandardSubsystems.BasicFunctionality\OnDefineActiveUsersForm.
//
// Returns:
//  FixedArray with the type values.
//    FixedStructure with properties:
//     * Version - String      - handler version, for example, "2.1.3.4". Empty row if not specified.
//     * Module - CommonModule - server common module.
// 
Function ServiceEventProcessor(Event) Export
	
	Return StandardSubsystemsClientReUse.HandlersForClientEvents(Event, True);
	
EndFunction

// Updates the application interface saving the current active window.
Procedure RefreshApplicationInterface() Export
	
	CurrentActiveWindow = ActiveWindow();
	RefreshInterface();
	If CurrentActiveWindow <> Undefined Then
		CurrentActiveWindow.Activate();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure ShowFileSystemExtensionInstallationQuestionCompletion(Action, ClosingNotification) Export
	
#If WebClient Then
	If Action = "NoLongerPrompt" Then
		SystemInfo = New SystemInfo();
		ClientID = SystemInfo.ClientID;
		SuggestFileSystemExtensionInstallation = False;
		CommonUseServerCall.CommonSettingsStorageSave(
			"ProgramSettings/SuggestFileSystemExtensionInstallation", ClientID,
			SuggestFileSystemExtensionInstallation);
	EndIf;
#EndIf
	
	ExecuteNotifyProcessing(ClosingNotification,  AttachFileSystemExtension());
	
EndProcedure	

Procedure ShowQuestionOnFileOperationsExtensionSettingOnExtensionSetting(Attached, AdditionalParameters) Export
	
	// If extension is already enabled, do not ask about it.
	If Attached Then
		ExecuteNotifyProcessing(AdditionalParameters.AlertDescriptionEnd, "ConnectionNotRequired");
		Return;
	EndIf;
	
	// Extension is not available in the web client under MacOS.
	SystemInfo = New SystemInfo;
	IsMacClient = (SystemInfo.PlatformType = PlatformType.MacOS_x86
		Or SystemInfo.PlatformType = PlatformType.MacOS_x86_64);
	If IsMacClient Then
		ExecuteNotifyProcessing(AdditionalParameters.AlertDescriptionEnd);
		Return;
	EndIf;
	
	ParameterName = "StandardSubsystems.SuggestFileSystemExtensionInstallation";
	FirstCallInSession = ApplicationParameters[ParameterName] = Undefined;
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, SuggestFileSystemExtensionInstallation());
	EndIf;
	SuggestFileSystemExtensionInstallation	= ApplicationParameters[ParameterName] Or FirstCallInSession;
	
	If AdditionalParameters.PossibleToContinueWithoutInstallation AND Not SuggestFileSystemExtensionInstallation Then
		ExecuteNotifyProcessing(AdditionalParameters.AlertDescriptionEnd);
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("SuggestionText", AdditionalParameters.SuggestionText);
	FormParameters.Insert("PossibleToContinueWithoutInstallation", AdditionalParameters.PossibleToContinueWithoutInstallation);
	OpenForm("CommonForm.QuestionAboutFileOperationsExtensionSetting", FormParameters,,,,,AdditionalParameters.AlertDescriptionEnd);
	
EndProcedure

Procedure CheckFileOperationsExtensionConnectedEnd(ExtensionAttached, AdditionalParameters) Export
	
	If ExtensionAttached Then
		ExecuteNotifyProcessing(AdditionalParameters.OnCloseNotifyDescription);
		Return;
	EndIf;
	
	MessageText = AdditionalParameters.WarningText;
	If IsBlankString(MessageText) Then
		MessageText = NStr("en='The action is not available as an extension for 1C:Enterprise web client is not installed.';ru='Действие недоступно, так как не установлено расширение для веб-клиента 1С:Предприятие.'")
	EndIf;
	ShowMessageBox(, MessageText);
	
EndProcedure

Procedure CommentEndInput(Val EnteredText, Val AdditionalParameters) Export
	
	If EnteredText = Undefined Then
		Return;
	EndIf;	
	
	FormAttribute = AdditionalParameters.OwnerForm;
	
	PathToFormAttribute = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(AdditionalParameters.AttributeName, ".");
	// If the attribute is of the Object.Comment type etc.
	If PathToFormAttribute.Count() > 1 Then
		For IndexOf = 0 To PathToFormAttribute.Count() - 2 Do 
			FormAttribute = FormAttribute[PathToFormAttribute[IndexOf]];
		EndDo;
	EndIf;	
	
	FormAttribute[PathToFormAttribute[PathToFormAttribute.Count() - 1]] = EnteredText;
	AdditionalParameters.OwnerForm.Modified = True;
	
EndProcedure

Procedure RegisterCOMConnectorEnd(Response, Parameters) Export
	
	If Response = DialogReturnCode.Yes Then
		ApplicationParameters.Insert("StandardSubsystems.SkipAlertBeforeExit", True);
		Exit(True, True);
	EndIf;

EndProcedure

Procedure ConfirmFormClosing() Export
	
	ParameterName = "StandardSubsystems.CloseFormValidationSettings";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	
	Parameters = ApplicationParameters["StandardSubsystems.CloseFormValidationSettings"];
	If Parameters = Undefined Then
		Return;
	EndIf;
	ApplicationParameters["StandardSubsystems.CloseFormValidationSettings"] = Undefined;
	
	Notification = New NotifyDescription("ConfirmFormClosingEnd", ThisObject, Parameters);
	If IsBlankString(Parameters.WarningText) Then
		QuestionText = NStr("en='Data was changed. Save the changes?';ru='Данные были изменены. Сохранить изменения?'");
	Else
		QuestionText = Parameters.WarningText;
	EndIf;
	
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNoCancel, ,
		DialogReturnCode.No);
	
EndProcedure

Procedure ConfirmFormClosingEnd(Response, Parameters) Export
	
	If Response = DialogReturnCode.Yes Then
		ExecuteNotifyProcessing(Parameters.AlertSaveAndClose);
	ElsIf Response = DialogReturnCode.No Then
		Form = Parameters.AlertSaveAndClose.Module;
		Form.Modified = False;
		Form.Close();
	Else
		Form = Parameters.AlertSaveAndClose.Module;
		Form.Modified = True;
	EndIf;
	
EndProcedure

Procedure ConfirmArbitraryFormClosing() Export
	
	ParameterName = "StandardSubsystems.CloseFormValidationSettings";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	
	Parameters = ApplicationParameters["StandardSubsystems.CloseFormValidationSettings"];
	If Parameters = Undefined Then
		Return;
	EndIf;
	ApplicationParameters["StandardSubsystems.CloseFormValidationSettings"] = Undefined;
	QuestionMode = QuestionDialogMode.YesNo;
	
	Notification = New NotifyDescription("ConfirmCustomFormClosingEnd", ThisObject, Parameters);
	
	ShowQueryBox(Notification, Parameters.WarningText, QuestionMode);
	
EndProcedure

Procedure ConfirmCustomFormClosingEnd(Response, Parameters) Export
	
	Form = Parameters.Form;
	If Response = DialogReturnCode.Yes
		Or Response = DialogReturnCode.OK Then
		Form[Parameters.AttributeNameCloseFormWithoutConfirmation] = True;
		If Parameters.AlertDescriptionClose <> Undefined Then
			ExecuteNotifyProcessing(Parameters.AlertDescriptionClose);
		EndIf;
		Form.Close();
	Else
		Form[Parameters.AttributeNameCloseFormWithoutConfirmation] = False;
	EndIf;
	
EndProcedure

#EndRegion
