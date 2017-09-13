
#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Operation handlers

// Corresponds to operation GetExchangePlans
Function GetConfigurationExchangePlans()
	
	Return StringFunctionsClientServer.RowFromArraySubrows(
		DataExchangeSaaSReUse.DataSynchronizationExchangePlans());
EndFunction

// Corresponds to operation PrepareExchangeExecution
Function ScheduleDataExchangeExecution(AreasForDataExchangeString)
	
	AreasForDataExchange = ValueFromStringInternal(AreasForDataExchangeString);
	
	SetPrivilegedMode(True);
	
	For Each Item IN AreasForDataExchange Do
		
		SeparatorValue = Item.Key;
		DataExchangeScenario = Item.Value;
		
		Parameters = New Array;
		Parameters.Add(DataExchangeScenario);
		
		JobParameters = New Structure;
		JobParameters.Insert("MethodName"    , "DataExchangeSaaS.PerformDataExchange");
		JobParameters.Insert("Parameters"    , Parameters);
		JobParameters.Insert("Key"         , "1");
		JobParameters.Insert("DataArea", SeparatorValue);
		
		Try
			JobQueue.AddJob(JobParameters);
		Except
			If ErrorInfo().Definition <> JobQueue.GetJobsWithSameKeyDuplicationErrorMessage() Then
				Raise;
			EndIf;
		EndTry;
		
	EndDo;
	
	Return "";
EndFunction

// Corresponds to operation StartExchangeExecutionInFirstDataBase
Function ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex, DataExchangeScenarioString)
	
	DataExchangeScenario = ValueFromStringInternal(DataExchangeScenarioString);
	
	ScenarioString = DataExchangeScenario[ScenarioRowIndex];
	
	strKey = ScenarioString.ExchangePlanName + ScenarioString.CodeOfInfobaseNode + ScenarioString.ThisNodeCode;
	
	Parameters = New Array;
	Parameters.Add(ScenarioRowIndex);
	Parameters.Add(DataExchangeScenario);
	
	JobParameters = New Structure;
	JobParameters.Insert("MethodName"    , "DataExchangeSaaS.PerformDataExchangeScriptActionInFirstInfobase");
	JobParameters.Insert("Parameters"    , Parameters);
	JobParameters.Insert("Key"         , strKey);
	JobParameters.Insert("DataArea", ScenarioString.FirstInfobaseSeparatorValue);
	
	Try
		SetPrivilegedMode(True);
		JobQueue.AddJob(JobParameters);
	Except
		If ErrorInfo().Definition <> JobQueue.GetJobsWithSameKeyDuplicationErrorMessage() Then
			Raise;
		EndIf;
	EndTry;
	
	Return "";
EndFunction

// Corresponds to operation StartExchangeExecutionInSecondDataBase
Function ExecuteDataExchangeScenarioActionInSecondInfobase(ScenarioRowIndex, DataExchangeScenarioString)
	
	DataExchangeScenario = ValueFromStringInternal(DataExchangeScenarioString);
	
	ScenarioString = DataExchangeScenario[ScenarioRowIndex];
	
	strKey = ScenarioString.ExchangePlanName + ScenarioString.CodeOfInfobaseNode + ScenarioString.ThisNodeCode;
	
	Parameters = New Array;
	Parameters.Add(ScenarioRowIndex);
	Parameters.Add(DataExchangeScenario);
	
	JobParameters = New Structure;
	JobParameters.Insert("MethodName"    , "DataExchangeSaaS.PerformDataExchangeScriptActionInSecondInfobase");
	JobParameters.Insert("Parameters"    , Parameters);
	JobParameters.Insert("Key"         , strKey);
	JobParameters.Insert("DataArea", ScenarioString.SecondInfobaseSeparatorValue);
	
	Try
		SetPrivilegedMode(True);
		JobQueue.AddJob(JobParameters);
	Except
		If ErrorInfo().Definition <> JobQueue.GetJobsWithSameKeyDuplicationErrorMessage() Then
			Raise;
		EndIf;
	EndTry;
	
	Return "";
	
EndFunction

// Corresponds to operation TestConnection
Function CheckConnection(SettingsStructureString, TransportKindString, ErrorInfo)
	
	Cancel = False;
	
	// Check connection of the exchange message transport data processor
	DataExchangeServer.CheckConnectionOfExchangeMessagesTransportDataProcessor(Cancel,
			ValueFromStringInternal(SettingsStructureString),
			Enums.ExchangeMessagesTransportKinds[TransportKindString],
			ErrorInfo);
	
	If Cancel Then
		Return False;
	EndIf;
	
	// Check connection to the management application through a WEB service
	Try
		DataExchangeSaaSReUse.GetExchangeServiceWSProxy();
	Except
		ErrorInfo = BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	Return True;
EndFunction

#EndRegion
