////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
// Support of long server actions at the web client.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Executes procedures in a background job.
// 
// Parameters:
// FormID - UUID - form ID, 
// the long action is executed from this form;
// ExportProcedureName - String - export procedure name 
// required to execute in background job
// Parameters - Structure - all necessary to ExportProcedureName execution parameters.
// JobDescription - String - background job description. 
// If JobDescription is not specified it will be equal to ExportProcedureName. 
//

// Returns:
// Structure - returns following properties: 
// - StorageAddress - Temporary storage address where a job
// execution result will be put; 
// - JobID - executing background job UUID;
// - JobCompleted - True if job completed successfully. 
//
Function ExecuteInBackground(Val FormID, Val ExportProcedureName, 
	Val Parameters, Val JobDescription = "", Val NoTimeout = True) Export
		
	StorageAddress = PutToTempStorage(Undefined, FormID);

	If Not ValueIsFilled(JobDescription) Then
		JobDescription = ExportProcedureName;
	EndIf;
	
	ExportProcedureParameters = New Array;
	If TypeOf(Parameters) = Type("Array") Then
		For Each Parameter In Parameters Do
			ExportProcedureParameters.Add(Parameter);
		EndDo;	
	Else	
		ExportProcedureParameters.Add(Parameters);
	EndIf;
	ExportProcedureParameters.Add(StorageAddress);
	
	JobParameters = New Array;
	JobParameters.Add(ExportProcedureName);
	JobParameters.Add(ExportProcedureParameters);

	If Constants.LongActionsDebugMode.Get() Then
		CommonUse.ExecuteSafely(ExportProcedureName, ExportProcedureParameters);
		Result = New Structure;
		Result.Insert("StorageAddress" , StorageAddress);
		Result.Insert("JobCompleted" , True);
		Result.Insert("JobID", "DebugMode");	
		Result.Insert("ProcedureName", ExportProcedureName);	
		
		Return Result;	
	Else
		If GetClientConnectionSpeed() = ClientConnectionSpeed.Low Then
			Timeout = 4;
		Else
			Timeout = 2;
		EndIf;
		
		If CommonUseCached.DataSeparationEnabled()
			And CommonUseCached.SessionWithoutSeparator() Then
			
			JobParameters.Add(CommonUse.SessionSeparatorValue());
			
			CommonUse.SetSessionSeparation(False);
			
			Job = BackgroundJobs.Execute("CommonUse.ExecuteSafely", JobParameters,, JobDescription);
			
			If NOT NoTimeout Then	
				Try
					Job.WaitForCompletion(Timeout);
				Except
					// There is no need in special processing. Perhaps the exception was raised because a time-out occurred.
				EndTry;
			EndIf;
			
			CommonUse.SetSessionSeparation(True);
		Else
			JobParameters.Add(Undefined);
			Job = BackgroundJobs.Execute("CommonUse.ExecuteSafely", JobParameters,, JobDescription);
			If NOT NoTimeout Then
				Try
					Job.WaitForCompletion(Timeout);
				Except		
					// There is no need in a special processing. Perhaps the exception was raised because a time-out occurred.
				EndTry;
			EndIf;
		EndIf;
		
		Result = New Structure;
		Result.Insert("StorageAddress" , StorageAddress);
		Result.Insert("JobCompleted" , JobCompleted(Job.UUID));
		Result.Insert("JobID", Job.UUID);	
		Result.Insert("ProcedureName", ExportProcedureName);	
		
		Return Result;	
		
	EndIf;
	
EndFunction

// Cancels background job execution by the passed ID.
// 
// Parameters:
// JobID - UUID - background job ID.
// 
Procedure CancelJobExecution(Val JobID) Export 
	
	If Not ValueIsFilled(JobID) Then
		Return;
	EndIf;
	
	Job = FindJobByID(JobID);
	If Job = Undefined
		Or Job.State <> BackgroundJobState.Active Then
		
		Return;
	EndIf;
	
	Try
		Job.Cancel();
	Except
		// Perhaps job finished just at this moment and there is no error.
		WriteLogEvent(NStr("en = 'Long actions. Background job cancellation'; pl = 'Zadania w tle. Anulowanie zadania'"),
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Checks background job state by the passed ID.
// 
// Parameters:
// JobID - UUID - background job ID. 
//
// Returns:
// Boolean - returns True, if the job completed successfully;
// False - if the job is still executing. In other cases an exception is raised.
//
Function JobCompleted(Val JobID) Export
	
	If Constants.LongActionsDebugMode.Get() Then
		Return True;
	EndIf;	
	
	Job = FindJobByID(JobID);
	
	If Job <> Undefined
		And Job.State = BackgroundJobState.Active Then
		Return False;
	EndIf;
	
	ActionNotExecuted = True;
	ShowFullErrorText = False;
	If Job = Undefined Then
		WriteLogEvent(NStr("en = 'Long actions. Background job is not found'; pl = 'Zadania w tle. Zadanie nie znaleziono'"),
			EventLogLevel.Error,,, String(JobID));
	Else	
		If Job.State = BackgroundJobState.Failed Then
			JobError = Job.ErrorInfo;
			If JobError <> Undefined Then
				WriteLogEvent(NStr("en = 'Long actions. Background job failed'; pl = 'Zadania w tle. Wykonanie się nie powiodło'"),
					EventLogLevel.Error,,,
					DetailErrorDescription(Job.ErrorInfo));
				ShowFullErrorText = True;	
			Else
				WriteLogEvent(NStr("en = 'Long actions. Background job failed'; pl = 'Zadania w tle. Wykonanie się nie powiodło'"),
					EventLogLevel.Error,,,
					NStr("en = 'The job finished with an unknown error.'; pl = 'Zadanie zostało zakończone przez nieznany błąd.'"));
			EndIf;
		ElsIf Job.State = BackgroundJobState.Canceled Then
			WriteLogEvent(NStr("en = 'Long actions. Administrator canceled background job'; pl = 'Zadania w tle. Zadanie zostało anulowane przez administratora'"),
				EventLogLevel.Error,,,
				NStr("en = 'The job finished with an unknown error.'; pl = 'Zadanie zostało zakończone przez nieznany błąd.'"));
		Else
			Return True;
		EndIf;
	EndIf;
	
	If ShowFullErrorText Then
		ErrorText = BriefErrorDescription(GetErrorInfo(Job.ErrorInfo));
		Raise(ErrorText);
	ElsIf ActionNotExecuted Then
		Raise(NStr("en = 'This job cannot be executed. 
                    |See details in the Event log.'; pl = 'Zadnie nie może być wykonane. Patrz szczegóły w dziennku'"));

	EndIf;
	
EndFunction

Function FindJobByID(Val JobID) Export
	
	If Constants.LongActionsDebugMode.Get() Then
		Return Undefined;
	EndIf;	
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.SessionWithoutSeparator() Then
		
		CommonUse.SetSessionSeparation(False);
		Job = BackgroundJobs.FindByUUID(JobID);
		CommonUse.SetSessionSeparation(True);
	Else
		Job = BackgroundJobs.FindByUUID(JobID);
	EndIf;
	
	Return Job;
	
EndFunction

// Registers in communications information about the run background job.
//   In further this information you can take it c client when assistance function ReadProgress.
//
// Parameters:
//  Percent - Number  - Optional. Successful execution %.
//  Text   - String - Optional. Information about current operation.
//  ExtendedParameters - arbitrary - Optional. Any additional information,
//      which you must pass on client. Value should be simple (serializable in XML string).
//
Procedure WriteProgress(Val Progress = Undefined, Val Text = Undefined, Val ExtendedParameters = Undefined) Export
	
	StoredValue = GetProgressStructure();
	If Progress <> Undefined Then
		StoredValue.Insert("Progress", Progress);
	EndIf;
	If Text <> Undefined Then
		StoredValue.Insert("Text", Text);
	EndIf;
	If ExtendedParameters <> Undefined Then
		StoredValue.Insert("ExtendedParameters", ExtendedParameters);
	EndIf;
	
	StoredText = CommonUse.ValueToXMLString(StoredValue);
	
	If NOT Constants.LongActionsDebugMode.Get() Then
		Message("{" + SubsystemName() + "}" + StoredText);
	EndIf;	
	
EndProcedure

// Finds background job and reads from his messages information about the run.
//
// Returns:
//   Structure - Information about the run background job.
//       Keys and values structure correspond to the the names of and values parameters procedure WriteProgress().
//
Function ReadProgress(Val JobID) Export
	
	ResultStructure = New Structure("ProgressStructure, MessagesArray",GetProgressStructure(),New Array);
	
	Job = FindJobByID(JobID);
	
	MessagesArray = Job.GetUserMessages(True);
	
	If MessagesArray = Undefined Then
		Return ResultStructure;
	EndIf;	
	
	Count = MessagesArray.Count();
	If Count = 0 Then
		Return ResultStructure;
	EndIf;
	
	Progress = 0;
	For Each Message In MessagesArray Do
		
		If Left(Message.Text, 1) = "{" Then
			Position = Find(Message.Text, "}");
			If Position > 2 Then
				SubsystemID = Mid(Message.Text, 2, Position - 2);
				If SubsystemID = SubsystemName() Then
					ReadText = Mid(Message.Text, Position + 1);
					ResultStructure.ProgressStructure = CommonUse.ValueFromXMLString(ReadText);
					Break;
				EndIf;
			EndIf;
		Else
			ResultStructure.MessagesArray.Add(Message);
		EndIf;
		
	EndDo;
	
	Return ResultStructure;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function GetProgressStructure()
	Return New Structure("Progress, Text, ExtendedParameters",0);
EndFunction	

Function GetErrorInfo(ErrorInfo)
	
	Result = ErrorInfo;
	If ErrorInfo <> Undefined Then
		If ErrorInfo.Cause <> Undefined Then
			Result = GetErrorInfo(ErrorInfo.Cause);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

Function SubsystemName()
	Return "StandardSubsystems.LongActions";
EndFunction
