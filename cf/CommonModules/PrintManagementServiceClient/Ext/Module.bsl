////////////////////////////////////////////////////////////////////////////////
// Subsystem "Print".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Continue the PrintingManagementClient procedure.ExecuteConnectedPrintCommand.
Procedure ExecuteConnectedPrintCommandRecordConfirmation(QuestionResult, AdditionalParameters) Export
	
	CommandDetails = AdditionalParameters.CommandDetails;
	Form = AdditionalParameters.Form;
	Source = AdditionalParameters.Source;
	
	If QuestionResult = DialogReturnCode.OK Then
		Form.Write();
		If Source.Ref.IsEmpty() Or Form.Modified Then
			Return; // Record has failed, platform outputs the messages about the reasons.
		EndIf;
	ElsIf QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	ExecuteConnectedPrintCommandPrintingObjectsPreparation(AdditionalParameters);
	
EndProcedure

// Continue the PrintingManagementClient procedure.ExecuteConnectedPrintCommand.
Procedure ExecuteConnectedPrintCommandPrintingObjectsPreparation(AdditionalParameters)
	
	PrintObjects = AdditionalParameters.Source;
	If TypeOf(PrintObjects) <> Type("Array") Then
		PrintObjects = PrintObjects(PrintObjects);
	EndIf;
	
	If PrintObjects.Count() = 0 Then
		Raise NStr("en='Command cannot be executed for the specified object.';ru='Команда не может быть выполнена для указанного объекта!'")
	EndIf;
	
	If AdditionalParameters.CommandDetails.PrintingObjectsTypes.Count() <> 0 Then // type check is required
		HasPrintableObjects = False;
		For Each PrintObject IN PrintObjects Do
			If AdditionalParameters.CommandDetails.PrintingObjectsTypes.Find(TypeOf(PrintObject)) <> Undefined Then
				HasPrintableObjects = True;
				Break;
			EndIf;
		EndDo;
		
		If Not HasPrintableObjects Then
			MessageText = PrintManagementServerCall.MessageAboutPrintingCommandPurpose(AdditionalParameters.CommandDetails.PrintingObjectsTypes);
			ShowMessageBox(, MessageText);
			Return;
		EndIf;
	EndIf;
	
	If AdditionalParameters.CommandDetails.CheckPostingBeforePrint Then
		NotifyDescription = New NotifyDescription("ExecuteConnectedPrintCommandEnableFileOperationsExtension", ThisObject, AdditionalParameters);
		PrintManagementClient.CheckThatDocumentsArePosted(NOTifyDescription, PrintObjects, AdditionalParameters.Form);
		Return;
	EndIf;
	
	ExecuteConnectedPrintCommandEnableFileOperationsExtension(PrintObjects, AdditionalParameters);
	
EndProcedure

// Continue the PrintingManagementClient procedure.ExecuteConnectedPrintCommand.
Procedure ExecuteConnectedPrintCommandEnableFileOperationsExtension(PrintObjects, AdditionalParameters) Export
	
	If PrintObjects.Count() = 0 Then
		Return;
	EndIf;
	
	AdditionalParameters.Insert("PrintObjects", PrintObjects);
	
	If AdditionalParameters.CommandDetails.RequiredFileOperationsExtension Then
		NotifyDescription = New NotifyDescription("ExecuteConnectedPrintCommandEnd", ThisObject, AdditionalParameters);
		ShowQuestionAboutFileOperationsExtensionSetting(NOTifyDescription);
		Return;
	EndIf;
	
	ExecuteConnectedPrintCommandEnd(True, AdditionalParameters);
	
EndProcedure
	
// Continue the PrintingManagementClient procedure.ExecuteConnectedPrintCommand.
Procedure ExecuteConnectedPrintCommandEnd(FileOperationsExtensionConnected, AdditionalParameters) Export
	
	If Not FileOperationsExtensionConnected Then
		Return;
	EndIf;
	
	CommandDetails = AdditionalParameters.CommandDetails;
	Form = AdditionalParameters.Form;
	PrintObjects = AdditionalParameters.PrintObjects;
	
	CommandDetails = CommonUseClientServer.CopyStructure(CommandDetails);
	CommandDetails.Insert("PrintObjects", PrintObjects);
	
	If CommandDetails.PrintManager = "StandardSubsystems.AdditionalReportsAndDataProcessors" 
		AND CommonUseClient.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalreportsAndDataProcessorsClient = CommonUseClient.CommonModule("AdditionalReportsAndDataProcessorsClient");
			ModuleAdditionalreportsAndDataProcessorsClient.ExecuteAssignedPrintCommand(CommandDetails, Form);
			Return;
	EndIf;
	
	If Not IsBlankString(CommandDetails.Handler) Then
		CommandDetails.Insert("Form", Form);
		HandlerName = CommandDetails.Handler;
		Handler = HandlerName + "(CommandDetails)";
		Result = Eval(Handler);
		Return;
	EndIf;
	
	If CommandDetails.StraightToPrinter Then
		PrintManagementClient.ExecutePrintCommandToPrinter(CommandDetails.PrintManager, CommandDetails.ID,
			PrintObjects, CommandDetails.AdditionalParameters);
	Else
		PrintManagementClient.ExecutePrintCommand(CommandDetails.PrintManager, CommandDetails.ID,
			PrintObjects, Form, CommandDetails);
	EndIf;
	
EndProcedure

// Continue the PrintingManagementClient procedure.CheckDocumentsPosting
Procedure CheckDocumentsPostingPostingDialog(Parameters) Export
	
	If PrintManagementServerCall.PostingRightAvailable(Parameters.UnpostedDocuments) Then
		If Parameters.UnpostedDocuments.Count() = 1 Then
			QuestionText = NStr("en='To print the document, post it first. Post the document and continue?';ru='Для того чтобы распечатать документ, его необходимо предварительно провести. Выполнить проведение документа и продолжить?'");
		Else
			QuestionText = NStr("en='To print documents, it is required to post them first. Post the documents and continue?';ru='Для того чтобы распечатать документы, их необходимо предварительно провести. Выполнить проведение документов и продолжить?'");
		EndIf;
	Else
		If Parameters.UnpostedDocuments.Count() = 1 Then
			WarningText = NStr("en='To print the document, post it first. Insufficient rights to post the document, cannot print.';ru='Для того чтобы распечатать документ, его необходимо предварительно провести. Недостаточно прав для проведения документа, печать невозможна.'");
		Else
			WarningText = NStr("en='To print the documents, post them first. Insufficient rights to post the documents, cannot print.';ru='Для того чтобы распечатать документы, их необходимо предварительно провести. Недостаточно прав для проведения документов, печать невозможна.'");
		EndIf;
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	NotifyDescription = New NotifyDescription("CheckDocumentsPostingDocumentsPosting", ThisObject, Parameters);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

// Continue the PrintingManagementClient procedure.CheckDocumentsPosting
Procedure CheckDocumentsPostingDocumentsPosting(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ClearMessages();
	DataAboutUnpostedDocuments = CommonUseServerCall.PostDocuments(AdditionalParameters.UnpostedDocuments);
	MessagePattern = NStr("en='Document %1 is not posted: %2';ru='Документ %1 не проведен: %2'");
	UnpostedDocuments = New Array;
	For Each InformationAboutDocument IN DataAboutUnpostedDocuments Do
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, String(InformationAboutDocument.Ref), 
				InformationAboutDocument.ErrorDescription), InformationAboutDocument.Ref);
		UnpostedDocuments.Add(InformationAboutDocument.Ref);
	EndDo;
	AdditionalParameters.Insert("UnpostedDocuments", UnpostedDocuments);
	
	PostedDocuments = CommonUseClientServer.ReduceArray(AdditionalParameters.DocumentsList, UnpostedDocuments);
	AdditionalParameters.Insert("PostedDocuments", PostedDocuments);
	
	// Alert the form opening about documents posting.
	PostedDocumentsTypes = New Map;
	For Each PostedDocument IN PostedDocuments Do
		PostedDocumentsTypes.Insert(TypeOf(PostedDocument));
	EndDo;
	For Each Type IN PostedDocumentsTypes Do
		NotifyChanged(Type.Key);
	EndDo;
		
	// If command is called from form, then read an actual (posted) copy from base to form.
	If TypeOf(AdditionalParameters.Form) = Type("ManagedForm") Then
		Try
			AdditionalParameters.Form.Read();
		Except
			// If there is no Read method, the printing is executed not from the object form.
		EndTry;
	EndIf;
		
	If UnpostedDocuments.Count() > 0 Then
		// Ask a user if they need to continue printing when there are unposted documents.
		DialogText = NStr("en='Cannot post one or several documents.';ru='Не удалось провести один или несколько документов.'");
		
		DialogButtons = New ValueList;
		If PostedDocuments.Count() > 0 Then
			DialogText = DialogText + " " + NStr("en='Continue?';ru='Продолжить?'");
			DialogButtons.Add(DialogReturnCode.Ignore, NStr("en='Continue';ru='Продолжить'"));
			DialogButtons.Add(DialogReturnCode.Cancel);
		Else
			DialogButtons.Add(DialogReturnCode.OK);
		EndIf;
		
		NotifyDescription = New NotifyDescription("CheckDocumentPostingEnd", ThisObject, AdditionalParameters);
		ShowQueryBox(NOTifyDescription, DialogText, DialogButtons);
		Return;
	EndIf;
	
	CheckDocumentPostingEnd(Undefined, AdditionalParameters);
	
EndProcedure

// Continue the PrintingManagementClient procedure.CheckDocumentsPosting
Procedure CheckDocumentPostingEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> Undefined AND QuestionResult <> DialogReturnCode.Ignore Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.EndingProcedureDescription, AdditionalParameters.PostedDocuments);
	
EndProcedure

// Returns references to objects selected currently on a form.
Function PrintObjects(Source)
	
	Result = New Array;
	
	If TypeOf(Source) = Type("FormTable") Then
		SelectedRows = Source.SelectedRows;
		For Each SelectedRow IN SelectedRows Do
			If TypeOf(SelectedRow) = Type("DynamicalListGroupRow") Then
				Continue;
			EndIf;
			CurrentRow = Source.RowData(SelectedRow);
			If CurrentRow <> Undefined Then
				Result.Add(CurrentRow.Ref);
			EndIf;
		EndDo;
	Else
		Result.Add(Source.Ref);
	EndIf;
	
	Return Result;
	
EndFunction

// Checks if there is a set extension of work with files in web
// client and offers a setting in case there is not.
//
// Parameters:
//  NotifyDescription - NotifyDescription - description of the procedure that will be called after the check.
//                                            Procedure should contain the following parameters.:
//                                             Result - (not used);
//                                             AdditionalParameters - (not used).
//
Procedure ShowQuestionAboutFileOperationsExtensionSetting(NOTifyDescription) Export
	#If WebClient Then
		MessageText = NStr("en='To continue printing, install extension for 1C:Enterprise web client.';ru='Для продолжения печати необходимо установить расширение для веб-клиента 1С:Предприятие.'");
		CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NOTifyDescription, MessageText, False);
		Return;
	#EndIf
	ExecuteNotifyProcessing(NOTifyDescription, True);
EndProcedure

#EndRegion
