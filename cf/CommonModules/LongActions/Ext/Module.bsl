////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Long server operations work support in web client.
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Runs the procedure in the background job.
// 
// Parameters:
//  FormID     - UUID - identifier
// of the form that runs launch lengthy operation. 
//  ExportProcedureName - String - name of export
// procedure which is required to be run in background.
//  Parameters              - Structure - all necessary parameters
// for procedure ExportProcedureName.
//  JobDescription    - String - background job name. 
//                           If not set, then it will still be ExportProcedureName. 
//  UseAdditionalTemporaryStorage - Boolean - sign
//                           of using additional temporary repository for
//                           data transfer to the parent session from background job. By default - False.
//
// Returns:
//  Structure              - job execution parameters: 
//   * StorageAddress  - String     - address of the temporary storage
//                                    to which the job result will be put;
//   * StorageAddressAdditional - String - address of the
//                                    additional temporary storage to which the job result will be put
//                                    (available only if you set the UseAdditionalTemporaryStorage parameter);
//   * JobID - UUID - unique identifier of the launched background job;
//   * JobCompleted - Boolean - True if the job is successfully complete during the function call.
// 
Function ExecuteInBackground(Val FormID, Val ExportProcedureName, 
	Val Parameters, Val JobDescription = "", UseAdditionalTemporaryStorage = False) Export
	
	StorageAddress = PutToTempStorage(Undefined, FormID);
	
	Result = New Structure;
	Result.Insert("StorageAddress",       StorageAddress);
	Result.Insert("JobCompleted",     False);
	Result.Insert("JobID", Undefined);
	
	If Not ValueIsFilled(JobDescription) Then
		JobDescription = ExportProcedureName;
	EndIf;
	
	ExportProcedureParameters = New Array;
	ExportProcedureParameters.Add(Parameters);
	ExportProcedureParameters.Add(StorageAddress);
	
	If UseAdditionalTemporaryStorage Then
		StorageAddressAdditional = PutToTempStorage(Undefined, FormID);
		ExportProcedureParameters.Add(StorageAddressAdditional);
	EndIf;
	
	JobsLaunched = 0;
	If CommonUse.FileInfobase() Then
		Filter = New Structure;
		Filter.Insert("State", BackgroundJobState.Active);
		JobsLaunched = BackgroundJobs.GetBackgroundJobs(Filter).Count();
	EndIf;
	
	If CommonUseClientServer.DebugMode()
		Or JobsLaunched > 0 Then
		WorkInSafeMode.ExecuteConfigurationMethod(ExportProcedureName, ExportProcedureParameters);
		Result.JobCompleted = True;
	Else
		JobParameters = New Array;
		JobParameters.Add(ExportProcedureName);
		JobParameters.Add(ExportProcedureParameters);
		Timeout = ?(GetClientConnectionSpeed() = ClientConnectionSpeed.Low, 4, 2);
		
		Task = StandardSubsystemsServer.RunBackgroundJobWithClientContext(ExportProcedureName,
			ExportProcedureParameters,, JobDescription);
		
		Try
			Task.WaitForCompletion(Timeout);
		Except
			// Special processor is not required, exception may be caused by timeout.
		EndTry;
		
		Result.JobCompleted = JobCompleted(Task.UUID);
		Result.JobID = Task.UUID;
	EndIf;
	
	If UseAdditionalTemporaryStorage Then
		Result.Insert("StorageAddressAdditional", StorageAddressAdditional);
	EndIf;
	
	Return Result;
	
EndFunction

// Cancels background job execution by the passed identifier.
// 
// Parameters:
//  JobID - UUID - background job identifier. 
// 
Procedure CancelJobExecution(Val JobID) Export 
	
	If Not ValueIsFilled(JobID) Then
		Return;
	EndIf;
	
	Task = FindJobByID(JobID);
	If Task = Undefined
		OR Task.State <> BackgroundJobState.Active Then
		
		Return;
	EndIf;
	
	Try
		Task.Cancel();
	Except
		// The job might end at the moment and there is no error.
		WriteLogEvent(NStr("en='Long actions.Background job execution cancellation';ru='Длительные операции.Отмена выполнения фонового задания'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Checks background job state by the passed identifier.
// Throws an exception if there is premature job ending.
//
// Parameters:
//  JobID - UUID - background job identifier. 
//
// Returns:
//  Boolean - job execution state.
// 
Function JobCompleted(Val JobID) Export
	
	Task = FindJobByID(JobID);
	
	If Task <> Undefined
		AND Task.State = BackgroundJobState.Active Then
		Return False;
	EndIf;
	
	ActionNotExecuted = True;
	ShowFullErrorText = False;
	If Task = Undefined Then
		WriteLogEvent(NStr("en='Long actions.Background job has not been found';ru='Длительные операции.Фоновое задание не найдено'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error, , , String(JobID));
	Else
		If Task.State = BackgroundJobState.Failed Then
			JobError = Task.ErrorInfo;
			If JobError <> Undefined Then
				ShowFullErrorText = True;
			EndIf;
		ElsIf Task.State = BackgroundJobState.Canceled Then
			WriteLogEvent(
				NStr("en='Long actions.Background task has been cancelled by administrator';ru='Длительные операции.Фоновое задание отменено администратором'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				,
				,
				NStr("en='Job has been completed with an unknown error.';ru='Задание завершилось с неизвестной ошибкой.'"));
		Else
			Return True;
		EndIf;
	EndIf;
	
	If ShowFullErrorText Then
		ErrorText = BriefErrorDescription(GetErrorInfo(Task.ErrorInfo));
		Raise(ErrorText);
	ElsIf ActionNotExecuted Then
		Raise(NStr("en='Unable to execute this operation. 
		|Look for details in event log.';ru='Не удалось выполнить данную операцию. 
		|Подробности см. в журнале регистрации.'"));
	EndIf;
	
EndFunction

// Registers information about the background job execution in messages.
//   This information can be read from the client using the ReadProgress function.
//
// Parameters:
//  Percent - Number  - Optional. Execution percent.
//  Text   - String - Optional. Information about current operation.
//  AdditionalParameters - Arbitrary - Optional. Any additional
//      information that should be passed to client Value should be simple (serialized to XML string).
//
Procedure TellProgress(Val Percent = Undefined, Val Text = Undefined, Val AdditionalParameters = Undefined) Export
	
	PassedValue = New Structure;
	If Percent <> Undefined Then
		PassedValue.Insert("Percent", Percent);
	EndIf;
	If Text <> Undefined Then
		PassedValue.Insert("Text", Text);
	EndIf;
	If AdditionalParameters <> Undefined Then
		PassedValue.Insert("AdditionalParameters", AdditionalParameters);
	EndIf;
	
	PassedText = CommonUse.ValueToXMLString(PassedValue);
	
	Text = "{" + SubsystemName() + "}" + PassedText;
	CommonUseClientServer.MessageToUser(Text);
	
	GetUserMessages(True); // Deleting previous messages.
	
EndProcedure

// Finds background job and reads from its messages information about execution process.
//
// Returns:
//   Structure - Information about background job execution process.
//       Structure keys and values match names and parameters values of the ReportProgress() procedure.
//
Function ReadProgress(Val JobID) Export
	Var Result;
	
	Task = BackgroundJobs.FindByUUID(JobID);
	If Task = Undefined Then
		Return Result;
	EndIf;
	
	MessagesArray = Task.GetUserMessages(True);
	If MessagesArray = Undefined Then
		Return Result;
	EndIf;
	
	Count = MessagesArray.Count();
	
	For Number = 1 To Count Do
		ReverseIndex = Count - Number;
		Message = MessagesArray[ReverseIndex];
		
		If Left(Message.Text, 1) = "{" Then
			Position = Find(Message.Text, "}");
			If Position > 2 Then
				MechanismIdentifier = Mid(Message.Text, 2, Position - 2);
				If MechanismIdentifier = SubsystemName() Then
					ReceivedText = Mid(Message.Text, Position + 1);
					Result = CommonUse.ValueFromXMLString(ReceivedText);
					Break;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Function FindJobByID(Val JobID)
	
	If TypeOf(JobID) = Type("String") Then
		JobID = New UUID(JobID);
	EndIf;
	
	Task = BackgroundJobs.FindByUUID(JobID);
	
	Return Task;
	
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

Procedure ExecuteProcedureDataProcessorsObjectModule(Parameters, StorageAddress) Export 
	
	MethodName = Parameters.MethodName;
	TempStructure = New Structure;
	Try
		TempStructure.Insert(MethodName);
	Except
		WriteLogEvent(NStr("en='Safe execution of the processor method';ru='Безопасное выполнение метода обработки'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Method name ""%1"" does not correspond to the requirements of the variable names formation.';ru='Имя метода ""%1"" не соответствует требованиям образования имен переменных.'"),
			MethodName);
	EndTry;
	
	ExecuteParameters = Parameters.ExecuteParameters;
	If Parameters.IsExternalDataProcessor Then
		If ValueIsFilled(Parameters.AdditionalInformationProcessorRef) AND CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
			DataProcessor = ModuleAdditionalReportsAndDataProcessors.GetObjectOfExternalDataProcessor(Parameters.AdditionalInformationProcessorRef);
		Else
			DataProcessor = ExternalDataProcessors.Create(Parameters.DataProcessorName);
		EndIf;
	Else
		DataProcessor = DataProcessors[Parameters.DataProcessorName].Create();
	EndIf;
	
	Execute("DataProcessor." + MethodName + "(ExecuteParameters, StorageAddress)");
	
EndProcedure

Function SubsystemName()
	Return "StandardSubsystems.LongActions";
EndFunction

Procedure ExecuteReportOrDataProcessorCommand(CommandParameters, ResultAddress) Export
	
	If CommandParameters.Property("AdditionalInformationProcessorRef")
		AND ValueIsFilled(CommandParameters.AdditionalInformationProcessorRef)
		AND CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		
		ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.RunCommand(CommandParameters, ResultAddress);
		
	Else
		
		Object = CommonUse.ObjectByDescriptionFull(CommandParameters.FullObjectName);
		Object.RunCommand(CommandParameters, ResultAddress);
		
	EndIf;
	
EndProcedure

#EndRegion
