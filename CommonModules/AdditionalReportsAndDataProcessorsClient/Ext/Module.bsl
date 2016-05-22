////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and data processors".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Opens a form with available commands.
//
// Parameters:
//   CommandParameter            - It is passed "as is" from the handler command parameters.
//   CommandExecuteParameters - It is passed "as is" from the handler command parameters.
//   Kind - String - Kind of processor that can be received from the series of functions:
//       AdditionalReportsAndDataProcessorsClientServer.DataProcessorKind<...>().
//   SectionName - String - Section name command interface from which the command is called.
//
Procedure OpenFormOfCommandsOfAdditionalReportsAndDataProcessors(CommandParameter, CommandExecuteParameters, Kind, SectionName = "") Export
	
	DestinationObjects = New ValueList;
	If TypeOf(CommandParameter) = Type("Array") Then // assign data processing
		DestinationObjects.LoadValues(CommandParameter);
	EndIf;
	
	Parameters = New Structure("DestinationObjects, Kind, SectionName, WindowOpeningMode");
	Parameters.DestinationObjects = DestinationObjects;
	Parameters.Kind = Kind;
	Parameters.SectionName = SectionName;
	Parameters.WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	
	If TypeOf(CommandExecuteParameters.Source) = Type("ManagedForm") Then // assign data processing
		Parameters.Insert("FormName", CommandExecuteParameters.Source.FormName);
	EndIf;
	
	OpenForm(
		"CommonForm.AdditionalReportsAndDataProcessors", 
		Parameters,
		CommandExecuteParameters.Source);
	
EndProcedure

// Opens the additional report form with the specified option.
//
// Parameters:
//   Ref - CatalogRef.AdditionalReportsAndDataProcessors - Ref to an additional report.
//   VariantKey - String - Additional report name variant.
//
Procedure OpenAdditionalReportVariants(Ref, VariantKey) Export
	
	If TypeOf(Ref) <> Type("CatalogRef.AdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	
	ReportName = AdditionalReportsAndDataProcessorsServerCall.ConnectExternalDataProcessor(Ref);
	OpenParameters = New Structure("VariantKey", VariantKey);
	Uniqueness = "ExternalReport." + ReportName + "/VariantKey." + VariantKey;
	OpenForm("ExternalReport." + ReportName + ".Form", OpenParameters, Undefined, Uniqueness);
	
EndProcedure

// Connects long operation for running command from external report or data processor form.
//
// Parameters:
//   CommandID - String - Command name as it is specified in the InformationAboutExternalProcessor() function of the object module.
//   CommandParameters - Structure - Command run parameters. 
//     Mandatory parameters:
//       * AdditionalDataProcessorRef - CatalogRef.AdditionalReportsAndDataProcessors -
//           It is passed "as is" from form parameters.
//     Optional parameters:
//       * SupportText - String - Text of a long operation.
//       * Title           - String - Title of a long operation.
//       * PurposeObjects   - Array - References objects for which the command is executed.
//           It is used for assigned additional data processors.
//       * ExecutionResult - Structure -
//          See StandardSubsystemsClientServer.ExecutionNewResult().
//     Service parameters reserved by subsystem:
//       * CommandID - String - Name of the executed command.
//     Besides mandatory parameters, it can contain its "own" parameters for use in the command handler.
//     When adding own parameters it is
//     preferable to use the prefix that excludes the intersection with standard mechanisms, for example "Context...".
//   Form - ManagedForm - Form to which it is required to return the result.
//
// IMPORTANT:
//   Result returns to handler ChoiceDataProcessor().
//   For the primary identification it is recommended to use the function LongActionsFormName().
//   Also keep in mind that background jobs are available only in client server mode.
//   Usage examples can be found in additional data processor of demo base.
//
// Returns:
//   ExecutionResult - Structure - See StandardSubsystemsClientServer.NewExecutionResult().
//
// Command data processor example:
// &AtClient
// Procedure
// CommandDataProcessor(command) CommandID = Command.Name;
// 	CommandParameters = New Structure("AdditionalDataProcessorRef, SupportText");
// 	CommandParameters.AdditionalDataProcessorRef = ObjectRef;
// 	CommandParameters.SupportText = NStr("en = 'Command is running...'");
// 	State(CommandParameters.SupportText);
// 	If StandardServerCallSubsystem.ClientWorkParameters().InformationFileBase
// 		Then RunResult = RunCommandDirectly (CommandID, CommandParameters);
// 		AdditionalReportsAndDataProcessorsClient.ShowCommandRunResult(ThisObject, RunResult);
// 	Else
// 		AdditionalReportsAndDataProcessorsClient.RunCommandInBackground (CommandID, CommandID, ThisObject);
// 	EndIf;
// EndProcedure
//
// Command direct run code example:
// &AtServer
// Function RunCommandDirectly(CommandID,
// CommandParameter) Return AdditionalReportsAndDataProcessors.RunCommandFromExternalObjectForm(CommandID, CommandParameter, ThisObject);
// EndFunction
//
// Selection data processor example:
// &AtClient
// Procedure SelectionDataProcessor
// (ValueSelected, SelectionSource) If SelectionSource.FormName =
// AdditionalReportsAndDataProcessorsClient.FormNameLongOperation() Then AdditionalReportsAndDataProcessorsClient.ShowCommandResult (Thisobject, ValueSelected);
// 	EndIf;
// EndProcedure
//
// Example of getting the references to additional data processor:
// &AtServer
// Procedure OnCreatingOnServer
// (Rejection, StandardDataProcessor) ObjectRef = Parameters.AdditionalDataProcessorRef;
// EndProcedure
//
Procedure RunCommandInBackground(CommandID, CommandParameters, Form) Export
	
	AdditionalInformationProcessorRef = Undefined;
	CommandParameters.Property("AdditionalInformationProcessorRef", AdditionalInformationProcessorRef);
	WrongType = TypeOf(AdditionalInformationProcessorRef) <> Type("CatalogRef.AdditionalReportsAndDataProcessors");
	If WrongType OR AdditionalInformationProcessorRef = PredefinedValue("Catalog.AdditionalReportsAndDataProcessors.EmptyRef") Then
		
		ErrorText = NStr("en = 'Incorrect parameter value ""AdditionalDataProcessorRef"":'") + Chars.LF;
		If WrongType Then
			ErrorText = ErrorText + StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Type transferred ""%1"", expected ""%2"".'"),
				String(TypeOf(AdditionalInformationProcessorRef)),
				String(Type("CatalogRef.AdditionalReportsAndDataProcessors")));
		Else
			ErrorText = ErrorText + NStr("en = 'Empty reference is transferred. Perhaps, processing was opened directly.'");
		EndIf;
		
		Raise ErrorText;
		
	EndIf;
	
	CommandParameters.Insert("CommandID", CommandID);
	
	FormParameters = New Structure("BackgroundJobLaunchParameters", CommandParameters);
	
	OpenForm(FormNameLongActions(), FormParameters, Form);
	
EndProcedure

// Returns the form name for identification of long operation result.
//
// Returns:
//   String - See RunCommandInBackground().
//
Function FormNameLongActions() Export
	
	Return "CommonForm.AdditionalReportsAndDataProcessorsLongOperation";
	
EndFunction

// Runs assigned command on the client using only non-contextual server call.
//   Returns False if the command requires server call.
//
// Parameters:
//   Form - ManagedForm - Form from which command is called.
//   ItemName - String - Form command name that was clicked.
//
// Returns:
//   Boolean - A way of execution.
//       True - Data processor command is executed non-contextually.
//       False - To run it, context server call is required.
//
Function ExecuteAllocatedCommandAtClient(Form, ItemName) Export
	ClearMessages();
	
	ExecuteCommand = AdditionalReportsAndDataProcessorsServerCall.DataProcessorCommandsDescription(ItemName, 
		Form.Commands.Find("AdditionalProcessorsCommandsAddressToTemporaryStorage").Action);
	
	If ExecuteCommand.StartVariant = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.FillForm") Then
		Return False; // To run the command, context server call is required.
	EndIf;
	
	Object = Form.Object;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Form",  Form);
	AdditionalParameters.Insert("Object", Object);
	AdditionalParameters.Insert("ExecuteCommand", ExecuteCommand);
	
	If Object.Ref.IsEmpty() OR Form.Modified Then
		QuestionText = StrReplace(
			NStr("en = 'To run the command ""%1"", it is required to write data.'"),
			"%1",
			ExecuteCommand.Presentation);
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Write and continue'"));
		Buttons.Add(DialogReturnCode.Cancel);
		
		Handler = New NotifyDescription("RunAssignedCommandOnClientEnd", ThisObject, AdditionalParameters);
		ShowQueryBox(Handler, QuestionText, Buttons, 60, DialogReturnCode.Yes);
	Else
		RunAssignedCommandOnClientEnd(-1, AdditionalParameters);
	EndIf;
	
	Return True; // To run the command client context is enough.
EndFunction

// Shows command execution result.
//
// Parameters:
//   Form - ManagedForm - Form for which output is required.
//   ExecutionResult - Structure - See StandardSubsystemsClient.ShowExecutionResult()
//
Procedure ShowCommandExecutionResult(Form, ExecutionResult) Export
	
	StandardSubsystemsClient.ShowExecutionResult(Form, ExecutionResult);
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Conditional call handlers.

// Opens additional reports selection form.
//
// Parameters:
//   FormItem - Arbitrary - Item form to which items are selected.
//
// Usage location:
//   Catalog.ReportMailings.Form.ItemForm.AddAdditionalReport().
//
Procedure ReportMailingPickupAddReport(FormItem) Export
	
	AdditionalReport = PredefinedValue("Enum.AdditionalReportsAndDataProcessorsKinds.AdditionalReport");
	Report               = PredefinedValue("Enum.AdditionalReportsAndDataProcessorsKinds.Report");
	
	FilterByType = New ValueList;
	FilterByType.Add(AdditionalReport, AdditionalReport);
	FilterByType.Add(Report, Report);
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("WindowOpeningMode",  FormWindowOpeningMode.Independent);
	ChoiceFormParameters.Insert("ChoiceMode",        True);
	ChoiceFormParameters.Insert("CloseOnChoice", False);
	ChoiceFormParameters.Insert("Multiselect", True);
	ChoiceFormParameters.Insert("Filter",              New Structure("Kind", FilterByType));
	
	OpenForm("Catalog.AdditionalReportsAndDataProcessors.ChoiceForm", ChoiceFormParameters, FormItem);
	
EndProcedure

// Handler of external print command.
//
// Parameters:
//  CommandParameters - Structure        - structure from commands table
//                                        row, see AdditionalReportsAndDataProcessors.OnPrintCommandsReceive.
//  Form            - ManagedForm - form in which printing command is executing.
//
Function ExecuteAssignedPrintCommand(ExecuteCommand, Form) Export
	
	// Transfer of additional parameters passed by this subsystem to the structure root.
	For Each KeyAndValue IN ExecuteCommand.AdditionalParameters Do
		ExecuteCommand.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	// Fixed parameters writing.
	ExecuteCommand.Insert("IsReport", False);
	ExecuteCommand.Insert("Kind", PredefinedValue("Enum.AdditionalReportsAndDataProcessorsKinds.PrintForm"));
	
	// Start of processing method corresponding to the command context.
	StartVariant = ExecuteCommand.StartVariant;
	If StartVariant = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.FormOpening") Then
		RunOpenOfProcessingForm(ExecuteCommand, Form, ExecuteCommand.PrintObjects);
	ElsIf StartVariant = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.CallOfClientMethod") Then
		RunClientMethodOfDataProcessor(ExecuteCommand, Form, ExecuteCommand.PrintObjects);
	Else
		ExecutePrintFormOpening(ExecuteCommand, Form, ExecuteCommand.PrintObjects);
	EndIf;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Shows notification before running a command.
Procedure ShowNotificationOnCommandExecution(ExecuteCommand) Export
	If ExecuteCommand.ShowAlert Then
		ShowUserNotification(NStr("en = 'Command is executed...'"), , ExecuteCommand.Presentation);
	EndIf;
EndProcedure

// Opens data processor form.
Procedure RunOpenOfProcessingForm(ExecuteCommand, Form, DestinationObjects) Export
	ProcessingParameters = New Structure("CommandID, AdditionalDataProcessorRef, FormName, SessionKey");
	ProcessingParameters.CommandID          = ExecuteCommand.ID;
	ProcessingParameters.AdditionalInformationProcessorRef = ExecuteCommand.Ref;
	ProcessingParameters.FormName                      = ?(Form = Undefined, Undefined, Form.FormName);
	ProcessingParameters.SessionKey = ExecuteCommand.Ref.UUID();
	
	If TypeOf(DestinationObjects) = Type("Array") Then
		ProcessingParameters.Insert("DestinationObjects", DestinationObjects);
	EndIf;
	
	#If ThickClientOrdinaryApplication Then
		ExternalDataProcessor = AdditionalReportsAndDataProcessorsServerCall.GetObjectOfExternalDataProcessor(ExecuteCommand.Ref);
		ProcessingForm = ExternalDataProcessor.GetForm(, Form);
		If ProcessingForm = Undefined Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'For the report or data processor ""%1"" the
				|main form is not assigned or the main form is not intended to be launched in the usual application.
				|Command ""%2"" can not be run.'"),
				String(ExecuteCommand.Ref),
				ExecuteCommand.Presentation);
		EndIf;
		ProcessingForm.Open();
		ProcessingForm = Undefined;
	#Else
		DataProcessorName = AdditionalReportsAndDataProcessorsServerCall.ConnectExternalDataProcessor(ExecuteCommand.Ref);
		If ExecuteCommand.IsReport Then
			OpenForm("ExternalReport."+ DataProcessorName +".Form", ProcessingParameters, Form);
		Else
			OpenForm("ExternalDataProcessor."+ DataProcessorName +".Form", ProcessingParameters, Form);
		EndIf;
	#EndIf
EndProcedure

// Runs client data processor method.
Procedure RunClientMethodOfDataProcessor(ExecuteCommand, Form, DestinationObjects) Export
	
	ShowNotificationOnCommandExecution(ExecuteCommand);
	
	ProcessingParameters = New Structure("CommandID, AdditionalDatarocessorRef, FormName");
	ProcessingParameters.CommandID          = ExecuteCommand.ID;
	ProcessingParameters.AdditionalInformationProcessorRef = ExecuteCommand.Ref;
	ProcessingParameters.FormName                      = ?(Form = Undefined, Undefined, Form.FormName);;
	
	If TypeOf(DestinationObjects) = Type("Array") Then
		ProcessingParameters.Insert("DestinationObjects", DestinationObjects);
	EndIf;
	
	#If ThickClientOrdinaryApplication Then
		ExternalDataProcessor = AdditionalReportsAndDataProcessorsServerCall.GetObjectOfExternalDataProcessor(ExecuteCommand.Ref);
		ProcessingForm = ExternalDataProcessor.GetForm(, Form);
		If ProcessingForm = Undefined Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'For the report or data processor ""%1"" the
				|main form is not assigned or the main form is not intended to be launched in the usual application.
				|Command ""%2"" can not be run.'"),
				String(ExecuteCommand.Ref),
				ExecuteCommand.Presentation);
		EndIf;
	#Else
		DataProcessorName = AdditionalReportsAndDataProcessorsServerCall.ConnectExternalDataProcessor(ExecuteCommand.Ref);
		If ExecuteCommand.IsReport Then
			ProcessingForm = GetForm("ExternalReport."+ DataProcessorName +".Form", ProcessingParameters, Form);
		Else
			ProcessingForm = GetForm("ExternalDataProcessor."+ DataProcessorName +".Form", ProcessingParameters, Form);
		EndIf;
	#EndIf
	
	If ExecuteCommand.Type = PredefinedValue("Enum.AdditionalReportsAndDataProcessorsKinds.AdditionalInformationProcessor")
		Or ExecuteCommand.Type = PredefinedValue("Enum.AdditionalReportsAndDataProcessorsKinds.AdditionalReport") Then
		
		ProcessingForm.RunCommand(ExecuteCommand.ID);
		
	ElsIf ExecuteCommand.Type = PredefinedValue("Enum.AdditionalReportsAndDataProcessorsKinds.CreatingLinkedObjects") Then
		
		CreatedObjects = New Array;
		
		ProcessingForm.RunCommand(ExecuteCommand.ID, DestinationObjects, CreatedObjects);
		
		TypesOfCreatedObjects = New Array;
		
		For Each CreatedObject IN CreatedObjects Do
			Type = TypeOf(CreatedObject);
			If TypesOfCreatedObjects.Find(Type) = Undefined Then
				TypesOfCreatedObjects.Add(Type);
			EndIf;
		EndDo;
		
		For Each Type IN TypesOfCreatedObjects Do
			NotifyChanged(Type);
		EndDo;
		
	ElsIf ExecuteCommand.Type = PredefinedValue("Enum.AdditionalReportsAndDataProcessorsKinds.PrintForm") Then
		
		ProcessingForm.Print(ExecuteCommand.ID, DestinationObjects);
		
	ElsIf ExecuteCommand.Type = PredefinedValue("Enum.AdditionalReportsAndDataProcessorsKinds.ObjectFilling") Then
		
		ProcessingForm.RunCommand(ExecuteCommand.ID, DestinationObjects);
		
		ModifiedObjectsTypes = New Array;
		
		For Each ModifiedObject IN DestinationObjects Do
			Type = TypeOf(ModifiedObject);
			If ModifiedObjectsTypes.Find(Type) = Undefined Then
				ModifiedObjectsTypes.Add(Type);
			EndIf;
		EndDo;
		
		For Each Type IN ModifiedObjectsTypes Do
			NotifyChanged(Type);
		EndDo;
		
	ElsIf ExecuteCommand.Type = PredefinedValue("Enum.AdditionalReportsAndDataProcessorsKinds.Report") Then
		
		ProcessingForm.RunCommand(ExecuteCommand.ID, DestinationObjects);
		
	EndIf;
	
	ProcessingForm = Undefined;
	
EndProcedure

// Forms a tabular document in subsystem "Print" form.
Procedure ExecutePrintFormOpening(ExecuteCommand, Form, DestinationObjects) Export
	
	StandardProcessing = True;
	AdditionalReportsAndDataProcessorsClientOverridable.BeforeExternalPrintFormPrintCommandExecution(DestinationObjects, StandardProcessing);
	
	Parameters = New Structure;
	Parameters.Insert("ExecuteCommand", ExecuteCommand);
	Parameters.Insert("Form", Form);
	If StandardProcessing Then
		NotifyDescription = New NotifyDescription("RunPrintFormOpeningEnd", ThisObject, Parameters);
		PrintManagementClient.CheckThatDocumentsArePosted(NOTifyDescription, DestinationObjects, Form);
	Else
		RunPrintFormOpeningEnd(DestinationObjects, Parameters);
	EndIf;
	
EndProcedure

// Continue the RunPrintFormOpening procedure.
Procedure RunPrintFormOpeningEnd(DestinationObjects, AdditionalParameters) Export
	
	ExecuteCommand = AdditionalParameters.ExecuteCommand;
	Form = AdditionalParameters.Form;
	
	SourceParameters = New Structure;
	SourceParameters.Insert("CommandID", ExecuteCommand.ID);
	SourceParameters.Insert("DestinationObjects",    DestinationObjects);
	
	OpenParameters = New Structure;
	OpenParameters.Insert("DataSource",     ExecuteCommand.Ref);
	OpenParameters.Insert("SourceParameters", SourceParameters);
	
	OpenForm("CommonForm.PrintingDocuments", OpenParameters, Form);
	
EndProcedure

// Handler of continuation of performing command assigned on client.
Procedure RunAssignedCommandOnClientEnd(Response, AdditionalParameters) Export
	Form = AdditionalParameters.Form;
	If Response = DialogReturnCode.Yes Then
		If Not Form.Write() Then
			Return;
		EndIf;
	ElsIf Response <> -1 Then
		Return;
	EndIf;
	
	ExecuteCommand = AdditionalParameters.ExecuteCommand;
	Object = AdditionalParameters.Object;
	
	ServerCallParameters = New Structure;
	ServerCallParameters.Insert("CommandID",          ExecuteCommand.ID);
	ServerCallParameters.Insert("AdditionalInformationProcessorRef", ExecuteCommand.Ref);
	ServerCallParameters.Insert("DestinationObjects",             New Array);
	ServerCallParameters.Insert("FormName",                      Form.FormName);
	ServerCallParameters.DestinationObjects.Add(Object.Ref);
	
	ShowNotificationOnCommandExecution(ExecuteCommand);
	
	// Control over the result of running is supported only for server methods.
	// If the form is opened or client method is called, then the execution result is displayed by data processor.
	If ExecuteCommand.StartVariant = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.FormOpening") Then
		
		NameOfExternalObject = AdditionalReportsAndDataProcessorsServerCall.ConnectExternalDataProcessor(ExecuteCommand.Ref);
		If ExecuteCommand.IsReport Then
			OpenForm("ExternalReport."+ NameOfExternalObject +".Form", ServerCallParameters, Form);
		Else
			OpenForm("ExternalDataProcessor."+ NameOfExternalObject +".Form", ServerCallParameters, Form);
		EndIf;
		
	ElsIf ExecuteCommand.StartVariant = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.CallOfClientMethod") Then
		
		NameOfExternalObject = AdditionalReportsAndDataProcessorsServerCall.ConnectExternalDataProcessor(ExecuteCommand.Ref);
		If ExecuteCommand.IsReport Then
			FormOfExternalObject = GetForm("ExternalReport."+ NameOfExternalObject +".Form", ServerCallParameters, Form);
		Else
			FormOfExternalObject = GetForm("ExternalDataProcessor."+ NameOfExternalObject +".Form", ServerCallParameters, Form);
		EndIf;
		FormOfExternalObject.RunCommand(ServerCallParameters.CommandID, ServerCallParameters.DestinationObjects);
		
	ElsIf ExecuteCommand.StartVariant = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.CallOfServerMethod")
		Or ExecuteCommand.StartVariant = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ScriptInSafeMode") Then
		
		ServerCallParameters.Insert("ExecutionResult", StandardSubsystemsClientServer.NewExecutionResult());
		AdditionalReportsAndDataProcessorsServerCall.RunCommand(ServerCallParameters, Undefined);
		Form.Read();
		ShowCommandExecutionResult(Form, ServerCallParameters.ExecutionResult);
		
	EndIf;
EndProcedure

// For editing text in table attributes.
Procedure EditMultilineText(FormOrHandler, EditText, PropsOwner, AttributeName, Val Title = "") Export
	
	If IsBlankString(Title) Then
		Title = NStr("en = 'Comment'");
	EndIf;
	
	SourceParameters = New Structure;
	SourceParameters.Insert("FormOrHandler", FormOrHandler);
	SourceParameters.Insert("PropsOwner",  PropsOwner);
	SourceParameters.Insert("AttributeName",       AttributeName);
	Handler = New NotifyDescription("EditMultilinedTextEnd", ThisObject, SourceParameters);
	
	ShowInputString(Handler, EditText, Title, , True);
	
EndProcedure

// Shows the dialog of extension installation, then imports additional report or data processor data.
Procedure ExportToFile(ExportParameters) Export
	MessageText = NStr("en = 'For external data processors (report) export to file, it is recommended to install extension for 1C:Enterprise web client.'");
	Handler = New NotifyDescription("ExportToFileEnd", ThisObject, ExportParameters);
	CommonUseClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler, MessageText);
EndProcedure

// Procedure continued (see above).
Procedure ReturnResultAfterSimpleDialogClosing(HandlerParameters) Export
	If TypeOf(HandlerParameters.Handler) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(HandlerParameters.Handler, HandlerParameters.Result);
	EndIf;
EndProcedure

// Asynchronous dialog handler preparation.
Function PrepareHandlerForDialog(HandlerOrStructure) Export
	
	If TypeOf(HandlerOrStructure) = Type("Structure") Then
		// Recursive registration of all calling code handlers.
		If HandlerOrStructure.Property("ResultHandler") Then
			HandlerOrStructure.ResultHandler = PrepareHandlerForDialog(HandlerOrStructure.ResultHandler);
		EndIf;
		If HandlerOrStructure.Property("AsynchronousDialog") Then
			// Open dialog registration.
			HandlerOrStructure.AsynchronousDialog.Open = True;
			// Creation of handler (during this the whole parameters structure is being fixed).
			Handler = New NotifyDescription(
				HandlerOrStructure.AsynchronousDialog.ProcedureName,
				HandlerOrStructure.AsynchronousDialog.Module,
				HandlerOrStructure);
		Else
			Handler = Undefined;
		EndIf;
	Else
		Handler = HandlerOrStructure;
	EndIf;
	
	Return Handler;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Service handlers for asynchronous dialogs.

// Procedure work result handler EditMultilineText.
Procedure EditMultilinedTextEnd(Text, SourceParameters) Export
	
	If TypeOf(SourceParameters.FormOrHandler) = Type("ManagedForm") Then
		Form      = SourceParameters.FormOrHandler;
		Handler = Undefined;
	Else
		Form      = Undefined;
		Handler = SourceParameters.FormOrHandler;
	EndIf;
	
	If Text <> Undefined Then
		
		If TypeOf(SourceParameters.PropsOwner) = Type("FormDataTreeItem")
			Or TypeOf(SourceParameters.PropsOwner) = Type("FormDataCollectionItem") Then
			FillPropertyValues(SourceParameters.PropsOwner, New Structure(SourceParameters.AttributeName, Text));
		Else
			SourceParameters.PropsOwner[SourceParameters.AttributeName] = Text;
		EndIf;
		
		If Form <> Undefined Then
			If Not Form.Modified Then
				Form.Modified = True;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Handler <> Undefined Then
		ExecuteNotifyProcessing(Handler, Text);
	EndIf;
	
EndProcedure

// ExportToFile procedure work result handler.
Procedure ExportToFileEnd(Attached, ExportParameters) Export
	Var Address;
	
	ExportParameters.Property("DataProcessorDataAddress", Address);
	If Not ValueIsFilled(Address) Then
		Address = AdditionalReportsAndDataProcessorsServerCall.PlaceIntoStorage(ExportParameters.Ref, Undefined);
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ExportParameters", ExportParameters);
	AdditionalParameters.Insert("Address", Address);
	
	If Not Attached Then
		GetFile(Address, ExportParameters.FileName, True);
		Return;
	EndIf;
	
	SaveFileDialog = New FileDialog(FileDialogMode.Save);
	SaveFileDialog.FullFileName = ExportParameters.FileName;
	SaveFileDialog.Filter = AdditionalReportsAndDataProcessorsClientServer.ChooserAndSaveDialog();
	SaveFileDialog.FilterIndex = ?(ExportParameters.IsReport, 1, 2);
	SaveFileDialog.Multiselect = False;
	SaveFileDialog.Title = NStr("en = 'Specify file'");
	
	Handler = New NotifyDescription("ExportFileFileChoice", ThisObject, AdditionalParameters);
	SaveFileDialog.Show(Handler);
	
EndProcedure

// ExportToFile procedure work result handler.
Procedure ExportFileFileChoice(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles <> Undefined Then
		FullFileName = SelectedFiles[0];
		FilesToReceive = New Array;
		FilesToReceive.Add(New TransferableFileDescription(FullFileName, AdditionalParameters.Address));
		
		Handler = New NotifyDescription("ExportFileGetFile", ThisObject);
		BeginGettingFiles(Handler, FilesToReceive, FullFileName, False);
	EndIf;
	
EndProcedure

// ExportToFile procedure work result handler.
Procedure ExportFileGetFile(ReceivedFiles, AdditionalParameters) Export
	// Results processing is not required.
EndProcedure

#EndRegion
