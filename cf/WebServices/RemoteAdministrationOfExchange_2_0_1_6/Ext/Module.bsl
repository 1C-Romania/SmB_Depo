
#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Operation handlers

// Corresponds to operation GetExchangePlans
Function GetConfigurationExchangePlans()
	
	Return StringFunctionsClientServer.RowFromArraySubrows(
		DataExchangeSaaSReUse.DataSynchronizationExchangePlans());
EndFunction

// Corresponds to operation PrepareExchangeExecution
Function ScheduleDataExchangeExecution(AreasForDataExchangeXDTO)
	
	AreasForDataExchange = XDTOSerializer.ReadXDTO(AreasForDataExchangeXDTO);
	
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
Function ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex, DataExchangeScenarioXDTO)
	
	DataExchangeScenario = XDTOSerializer.ReadXDTO(DataExchangeScenarioXDTO);
	
	ScenarioString = DataExchangeScenario[ScenarioRowIndex];
	
	strKey = ScenarioString.ExchangePlanName + ScenarioString.CodeOfInfobaseNode + ScenarioString.ThisNodeCode;
	
	ExchangeMode = SharingDataMode(DataExchangeScenario);
	
	If ExchangeMode = "Manual" Then
		
		Parameters = New Array;
		Parameters.Add(ScenarioRowIndex);
		Parameters.Add(DataExchangeScenario);
		Parameters.Add(ScenarioString.FirstInfobaseSeparatorValue);
		
		BackgroundJobs.Execute("DataExchangeSaaS.ExecuteDataExchangeScenarioActionInFirstInfobaseFromSharedSession",
			Parameters,
			strKey
		);
	ElsIf ExchangeMode = "Automatic" Then
		
		Try
			Parameters = New Array;
			Parameters.Add(ScenarioRowIndex);
			Parameters.Add(DataExchangeScenario);
			
			JobParameters = New Structure;
			JobParameters.Insert("DataArea", ScenarioString.FirstInfobaseSeparatorValue);
			JobParameters.Insert("MethodName", "DataExchangeSaaS.PerformDataExchangeScriptActionInFirstInfobase");
			JobParameters.Insert("Parameters", Parameters);
			JobParameters.Insert("Key", strKey);
			JobParameters.Insert("Use", True);
			
			SetPrivilegedMode(True);
			JobQueue.AddJob(JobParameters);
		Except
			If ErrorInfo().Definition <> JobQueue.GetJobsWithSameKeyDuplicationErrorMessage() Then
				Raise;
			EndIf;
		EndTry;
		
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Unknown data exchange mode %1';ru='Неизвестный режим обмена данными %1'"), String(ExchangeMode)
		);
	EndIf;
	
	Return "";
EndFunction

// Corresponds to operation StartExchangeExecutionInSecondDataBase
Function ExecuteDataExchangeScenarioActionInSecondInfobase(ScenarioRowIndex, DataExchangeScenarioXDTO)
	
	DataExchangeScenario = XDTOSerializer.ReadXDTO(DataExchangeScenarioXDTO);
	
	ScenarioString = DataExchangeScenario[ScenarioRowIndex];
	
	strKey = ScenarioString.ExchangePlanName + ScenarioString.CodeOfInfobaseNode + ScenarioString.ThisNodeCode;
	
	ExchangeMode = SharingDataMode(DataExchangeScenario);
	
	If ExchangeMode = "Manual" Then
		
		Parameters = New Array;
		Parameters.Add(ScenarioRowIndex);
		Parameters.Add(DataExchangeScenario);
		Parameters.Add(ScenarioString.SecondInfobaseSeparatorValue);
		
		BackgroundJobs.Execute("DataExchangeSaaS.ExecuteDataExchangeScenarioActionInSecondInfobaseFromSharedSession",
			Parameters,
			strKey
		);
		
	ElsIf ExchangeMode = "Automatic" Then
		
		Try
			Parameters = New Array;
			Parameters.Add(ScenarioRowIndex);
			Parameters.Add(DataExchangeScenario);
			
			JobParameters = New Structure;
			JobParameters.Insert("DataArea", ScenarioString.SecondInfobaseSeparatorValue);
			JobParameters.Insert("MethodName", "DataExchangeSaaS.PerformDataExchangeScriptActionInSecondInfobase");
			JobParameters.Insert("Parameters", Parameters);
			JobParameters.Insert("Key", strKey);
			JobParameters.Insert("Use", True);
			
			SetPrivilegedMode(True);
			JobQueue.AddJob(JobParameters);
		Except
			If ErrorInfo().Definition <> JobQueue.GetJobsWithSameKeyDuplicationErrorMessage() Then
				Raise;
			EndIf;
		EndTry;
		
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Unknown data exchange mode %1';ru='Неизвестный режим обмена данными %1'"), String(ExchangeMode)
		);
	EndIf;
	
	Return "";
EndFunction

// Corresponds to operation TestConnection
Function CheckConnection(XDTOSettingsStructure, TransportKindString, ErrorInfo)
	
	Cancel = False;
	
	// Check connection of the exchange message transport data processor
	DataExchangeServer.CheckConnectionOfExchangeMessagesTransportDataProcessor(Cancel,
			XDTOSerializer.ReadXDTO(XDTOSettingsStructure),
			Enums.ExchangeMessagesTransportKinds[TransportKindString],
			ErrorInfo);
	
	If Cancel Then
		Return False;
	EndIf;
	
	Return True;
EndFunction

// Corresponds to operation Ping
Function Ping()
	
	// Cap. It is necessary to the configuration check error wasn't given.
	Return Undefined;
	
EndFunction

//

Function SharingDataMode(DataExchangeScenario)
	
	Result = "Manual";
	
	If DataExchangeScenario.Columns.Find("Mode") <> Undefined Then
		Result = DataExchangeScenario[0].Mode;
	EndIf;
	
	Return Result;
EndFunction

#EndRegion
