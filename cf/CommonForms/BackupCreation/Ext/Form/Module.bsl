&AtClient
Var IdleHandlerParameters;

&AtClient
Var LongOperationForm;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not CommonUse.UseSessionSeparator() Then 
		Raise(NStr("en='Delimiter value is not specified';ru='Не установлено значение разделителя'"));
	EndIf;
	
	SwitchPage(ThisObject);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CreateAreaCopy(Command)
	
	Result = CreateAreaCopyAtServer();
	
	If Result.JobCompleted Then
		ProcessJobExecutionResult();
	Else
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
		LongOperationForm = LongActionsClient.OpenLongOperationForm(ThisObject, JobID);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If LongOperationForm.IsOpen() 
			AND LongOperationForm.JobID = JobID Then
			
			If JobCompleted(JobID) Then 
				LongActionsClient.CloseLongOperationForm(LongOperationForm);
				ProcessJobExecutionResult();
			Else
				LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
				AttachIdleHandler(
					"Attachable_CheckJobExecution", 
					IdleHandlerParameters.CurrentInterval, 
					True);
			EndIf;
		EndIf;
	Except
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		LongActionsClient.CloseLongOperationForm(LongOperationForm);
		WriteExceptionAtServer(ErrorPresentation);
		Raise;
	EndTry;
	
EndProcedure

&AtClient
Procedure ProcessJobExecutionResult()
	
	SwitchOffSoleMode();
	
	If Not IsBlankString(StorageAddress) Then
		DeleteFromTempStorage(StorageAddress);
		StorageAddress = "";
		// Go to result page.
		SwitchPage(ThisObject, "PageAfterExportSuccess");
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SwitchPage(Form, Val PageName = "PageBeforeExport")
	
	Form.Items.GroupPages.CurrentPage = Form.Items[PageName];
	
	If PageName = "PageBeforeExport" Then
		Form.Items.FormCreateAreaCopy.Enabled = True;
	Else
		Form.Items.FormCreateAreaCopy.Enabled = False;
	EndIf;

EndProcedure

&AtServer
Procedure WriteExceptionAtServer(Val ErrorPresentation)
	
	SwitchOffSoleMode();
	
	Event = DataAreasBackupReUse.BackgroundBackupName();
	WriteLogEvent(Event, EventLogLevel.Error, , , ErrorPresentation);
	
EndProcedure

&AtServer
Function CreateAreaCopyAtServer()
	
	DataArea = CommonUse.SessionSeparatorValue();
	CommonUse.LockInfobase();
	
	JobParameters = DataAreasBackup.CreateBlankExportingParameters();
	JobParameters.DataArea = DataArea;
	JobParameters.CopyID = New UUID;
	JobParameters.Force = True;
	JobParameters.OnDemand = True;
	
	Try
		Result = LongActions.ExecuteInBackground(
			UUID,
			DataAreasBackupReUse.BackgroundBackupMethodName(),
			JobParameters, 
			DataAreasBackupReUse.BackgroundBackupName());
		
	Except
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		WriteExceptionAtServer(ErrorPresentation);
		Raise;
	EndTry;
	
	StorageAddress = Result.StorageAddress;
	JobID = Result.JobID;
	Return Result;
	
EndFunction

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

&AtServerNoContext
Procedure SwitchOffSoleMode()
	
	CommonUse.UnlockInfobase();
	
EndProcedure

#EndRegion














