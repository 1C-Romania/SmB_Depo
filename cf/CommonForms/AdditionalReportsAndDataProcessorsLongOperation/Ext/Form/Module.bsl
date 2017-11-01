
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	BackgroundJobLaunchParameters = Undefined;
	If Not Parameters.Property("BackgroundJobLaunchParameters", BackgroundJobLaunchParameters) Then
		Cancel = True;
		Return;
	EndIf;
	
	If BackgroundJobLaunchParameters.Property("SupportText") AND ValueIsFilled(BackgroundJobLaunchParameters.SupportText) Then
		SupportText = BackgroundJobLaunchParameters.SupportText;
	Else
		SupportText = NStr("en='Executing the command...';ru='Команда выполняется...'");
	EndIf;
	
	If BackgroundJobLaunchParameters.Property("Title") AND ValueIsFilled(BackgroundJobLaunchParameters.Title) Then
		Title = BackgroundJobLaunchParameters.Title;
	Else
		Title = NStr("en='Please wait';ru='Пожалуйста, подождите'");
	EndIf;
	
	Try
		
		AssignmentResult = LongActions.ExecuteInBackground(
			UUID,
			"AdditionalReportsAndDataProcessors.RunCommand", 
			BackgroundJobLaunchParameters,
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Running additional report or data processor ""%1"", command name ""%2""';ru='Выполнение дополнительного отчета или обработки ""%1"", имя команды ""%2""'"),
				String(BackgroundJobLaunchParameters.AdditionalInformationProcessorRef),
				BackgroundJobLaunchParameters.CommandID));
		
		Completed = AssignmentResult.JobCompleted;
		ExceptionCalled = False;
		
		If Completed Then
			Result = GetFromTempStorage(AssignmentResult.StorageAddress);
		Else
			BackgroundJobID  = AssignmentResult.JobID;
			BackgroundJobStorageAddress = AssignmentResult.StorageAddress;
		EndIf;
		
	Except
		
		Completed = False;
		ExceptionCalled = True;
		ErrorText = BriefErrorDescription(ErrorInfo());
		
	EndTry;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Completed Then 
		Cancel = True;
		NotifyChoice(Result);
	Else
		CheckInterval = 1;
		BackgroundJobValidateOnClose = True;
		AttachIdleHandler("CheckExecution", CheckInterval, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	If BackgroundJobValidateOnClose Then
		BackgroundJobValidateOnClose = False;
		CheckResult = CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, True);
		If CheckResult.JobCompleted Then
			NotifyChoice(CheckResult.Value);
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Cancel(Command)
	QuestionText = NStr("en='Long action is still in process.';ru='Длительная операция еще выполняется.'");
	
	Buttons = New ValueList;
	Buttons.Add(1, NStr("en='Continue';ru='Продолжить'"));
	Buttons.Add(DialogReturnCode.Abort);
	
	DetachIdleHandler("CheckExecution");
	
	Handler = New NotifyDescription("CancelEnd", ThisObject);
	ShowQueryBox(Handler, QuestionText, Buttons, 60, 1);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure CheckExecution()
	CheckResult = CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, False);
	
	If CheckResult.JobCompleted Then
		BackgroundJobValidateOnClose = False;
		NotifyChoice(CheckResult.Value);
	EndIf;
	
	If CheckInterval < 15 Then
		CheckInterval = CheckInterval + 0.7;
	EndIf;
	AttachIdleHandler("CheckExecution", CheckInterval, True);
EndProcedure

&AtServerNoContext
Function CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, InterruptIfNotCompleted)
	CheckResult = New Structure("JobCompleted, Value", False, Undefined);
	If LongActions.JobCompleted(BackgroundJobID) Then
		CheckResult.JobCompleted = True;
		CheckResult.Value         = GetFromTempStorage(BackgroundJobStorageAddress);
	ElsIf InterruptIfNotCompleted Then
		LongActions.CancelJobExecution(BackgroundJobID);
	EndIf;
	Return CheckResult;
EndFunction

&AtClient
Procedure CancelEnd(Response, AdditionalParameters) Export
	InterruptIfNotCompleted = (Response = DialogReturnCode.Abort);
	
	CheckResult = CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, InterruptIfNotCompleted);
	
	If CheckResult.JobCompleted OR InterruptIfNotCompleted Then
		BackgroundJobValidateOnClose = False;
		NotifyChoice(CheckResult.Value);
		Return;
	EndIf;
	
	If CheckInterval < 15 Then
		CheckInterval = CheckInterval + 0.7;
	EndIf;
	
	AttachIdleHandler("CheckExecution", CheckInterval, True);
EndProcedure

#EndRegion
