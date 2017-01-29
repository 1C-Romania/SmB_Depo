&AtClient
Var HandlerParameters, ClosingFormConfirmation;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;

EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Items.Pages.CurrentPage = Items.ChoicePage 
		Or ClosingFormConfirmation = True Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("CloseFormEnd", ThisObject);
	Cancel = True;
	
	Text = NStr("en='Reject the update of data classifier?';ru='Отказаться от обновления данных классификатора?'");
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	If UpdateVariants = 0 Then
		Close();
		// Go to the branch of import from the Internet - substitute all previously exported states into the parameters.
		ExportParameters = New Structure;
		ExportParameters.Insert("StateCodeForImport", AddressClassifierUnprocessedStates());
		AddressClassifierClient.ImportAddressClassifier(ExportParameters);
	Else
		Items.OK.Enabled = False;
		// Starting data transfer
		UpdateAddressClassifierClient();
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	If ValueIsFilled(BackgroundJobID) Then
		BackgroundJobCancel(BackgroundJobID);
		ShowUserNotification(,, NStr("en='Address classifier update is not completed.';ru='Обновление адресного классификатора не завершено.'"));
	EndIf;
	
	Close();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure CloseFormEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		ClosingFormConfirmation = True;
		Close();
	Else 
		ClosingFormConfirmation = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateAddressClassifierClient()

	BackgroundJob = False;
	Result = "Running";
	UpdateAddressClassifier(Result, BackgroundJob);
	
	If BackgroundJob = True Then
		Items.Pages.CurrentPage = Items.LongOperationPage;
		LongActionsClient.InitIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
		HandlerParameters.MaxInterval = 5;
	Else 
		If Result = "Completed" Then
			RefreshReusableValues(); 
			Notify("AddressClassifierIsUpdated", , ThisObject);
			ShowUserNotification(,, NStr("en='Address classifier update is completed successfully.';ru='Обновление адресного классификатора успешно завершено.'"));
		Else
			ShowUserNotification(,, NStr("en='Address classifier update is not completed.';ru='Обновление адресного классификатора не завершено.'"));
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure Attachable_CheckJobExecution()
	
	JobCompleted = Undefined;
	Try
		JobCompleted = JobCompleted(BackgroundJobID);
	Except
		EventLogMonitorClient.AddMessageForEventLogMonitor(NStr("en='Address classifier update';ru='Обновление адресного классификатора'", CommonUseClientServer.MainLanguageCode()),
			"Error", DetailErrorDescription(ErrorInfo()), , True);
			
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='Address classifier update is interrupted.
		|Look for details in event log.';ru='Обновление адресного классификатора прервана.
		|Подробности см. в журнале регистрации.'"));
			
		ShowMessageBox(, ErrorText);
		Return;
	EndTry;
		
	If JobCompleted Then
		EventLogMonitorClient.AddMessageForEventLogMonitor(NStr("en='Address classifier update';ru='Обновление адресного классификатора'", CommonUseClientServer.MainLanguageCode()),
			"Information", NStr("en='Address classifier update is completed successfully.';ru='Обновление адресного классификатора успешно завершено.'"), , True);
		ShowUserNotification(,, NStr("en='Address classifier update is completed successfully.';ru='Обновление адресного классификатора успешно завершено.'"));
		RefreshReusableValues(); 
		Notify("AddressClassifierIsUpdated", , ThisObject);
		ClosingFormConfirmation = True;
		ThisForm.Close();
	Else
		LongActionsClient.UpdateIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", HandlerParameters.CurrentInterval, True);
	EndIf;
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	Return LongActions.JobCompleted(JobID);
EndFunction

&AtServerNoContext
Procedure BackgroundJobCancel(ID)
	LongActions.CancelJobExecution(ID);
EndProcedure

&AtServer
Procedure UpdateAddressClassifier(Result, BackgroundJob = False)
	
	BackgroundJobID = Undefined;
	
	ServerCallParameters = New Structure();
	ServerCallParameters.Insert("Result", Result);
		
	BackgroundJobResult = LongActions.ExecuteInBackground(UUID,
		"AddressClassifierService.ObsoleteClassifierBackgroundDataTransfer", ServerCallParameters,
		NStr("en='Address classifier subsystem: data update';ru='Подсистема Адресный классификатор: актуализация данных'")
	);
		
	If BackgroundJobResult.JobCompleted Then
		Result = "Completed";
	Else
		BackgroundJob = True;
		BackgroundJobID = BackgroundJobResult.JobID;
	EndIf;
	
EndProcedure

&AtServer
Function AddressClassifierUnprocessedStates() 
	
	Return AddressClassifierService.ObsoleteClassifierFilledStates();
	
EndFunction

#EndRegion
