&AtClient
Var ClientVariables;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	If Not TotalsAndAggregateManagementService.MustMoveBorderTotals() Then
		Cancel = True; // Period has already been set in another user session.
		Return;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ClientVariables = New Structure;
	ClientVariables.Insert("BeginTime", CommonUseClient.SessionDate());
	AttachIdleHandler("SetTotalsPeriod", 0.1, True);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetTotalsPeriod()
	JobParameters = BackGroundJobStart(UUID);
	ClientVariables.Insert("JobParameters", JobParameters);
	If JobParameters.JobCompleted Then
		TellResultCloseForm();
	Else
		AttachIdleHandler("BackgroundJobCheckAtClient", JobParameters.CurrentInterval, True);
	EndIf;
EndProcedure

&AtClient
Procedure TellResultCloseForm()
	ExecutionSpeedInSeconds = CommonUseClient.SessionDate() - ClientVariables.BeginTime;
	If ExecutionSpeedInSeconds >= 5 Then
		Close();
		StandardSubsystemsClient.ShowExecutionResult(ThisObject, ClientVariables.JobParameters.Result);
	Else
		AttachIdleHandler("TellResultCloseForm", 5 - ExecutionSpeedInSeconds, True);
	EndIf;
EndProcedure

&AtClient
Procedure BackgroundJobCheckAtClient()
	JobParameters = ClientVariables.JobParameters;
	BackgroundJobUpdateOnServer(JobParameters);
	If JobParameters.JobCompleted Then
		TellResultCloseForm();
	Else
		AttachIdleHandler("BackgroundJobCheckAtClient", JobParameters.CurrentInterval, True);
	EndIf;
EndProcedure

&AtServerNoContext
Function BackGroundJobStart(Val UUID)
	JobParameters = New Structure("JobCompleted, JobID, StorageAddress");
	
	Start = LongActions.ExecuteInBackground(
		UUID,
		"DataProcessors.TotalBoundaryShift.RunCommand",
		New Structure,
		NStr("en='Totals and aggregates: Acceleration of document posting and reports formating';ru='Итоги и агрегаты: Ускорение проведения документов и формирования отчетов'"));
	FillPropertyValues(JobParameters, Start);
	
	If JobParameters.JobCompleted Then
		JobParameters.Insert("Result", GetFromTempStorage(JobParameters.StorageAddress));
	Else
		JobParameters.Insert("MinInterval", 1);
		JobParameters.Insert("MaxInterval", 5);
		JobParameters.Insert("CurrentInterval", 1);
		JobParameters.Insert("IntervalIncreaseCoefficient", 1);
	EndIf;
	
	Return JobParameters;
EndFunction

&AtServerNoContext
Procedure BackgroundJobUpdateOnServer(JobParameters)
	JobParameters.JobCompleted = LongActions.JobCompleted(JobParameters.JobID);
	If JobParameters.JobCompleted Then
		JobParameters.Insert("Result", GetFromTempStorage(JobParameters.StorageAddress));
	Else
		JobParameters.CurrentInterval = JobParameters.CurrentInterval * JobParameters.IntervalIncreaseCoefficient;
		If JobParameters.CurrentInterval > JobParameters.MaxInterval Then
			JobParameters.CurrentInterval = JobParameters.MaxInterval;
		EndIf;
	EndIf;
EndProcedure

#EndRegion


// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
