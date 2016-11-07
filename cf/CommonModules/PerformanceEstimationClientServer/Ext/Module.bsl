////////////////////////////////////////////////////////////////////////////////
//  Methods that allow to start and end time measurement of the key operation execution.
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Activates time measurement of key operation execution.
//
// Parameters:
//  KeyOperation - CatalogRef.KeyOperations - key
// 					operation or String - name of the key operation.
//  Argument is ignored on call from server.
//
// Returns:
//  Date or number - start time accurate to milliseconds or seconds depending on the platform version.
//
Function StartTimeMeasurement(KeyOperation = Undefined) Export
	
	BeginTime = 0;
	If PerformanceEstimationServerCallReUse.ExecutePerformanceMeasurements() Then
		StartDate = TimerValue(False);
		BeginTime = TimerValue();
		#If Client Then
			If Not ValueIsFilled(KeyOperation) Then
				Raise NStr("en='Key operation is not specified.';ru='Не указана ключевая операция.'");
			EndIf;
			
			ParameterName = "StandardSubsystems.PerformanceEstimationTimeMeasurement";
			
			If ApplicationParameters = Undefined Then
				ApplicationParameters = New Map;
			EndIf;
			
			If ApplicationParameters[ParameterName] = Undefined Then
				CurrentRecordPeriod = PerformanceEstimationServerCallFullAccess.RecordPeriod();
				DateAndTimeAtServer = PerformanceEstimationServerCallFullAccess.DateAndTimeAtServer();
				DateAndTimeAtClient = CurrentDate();
				
				ApplicationParameters.Insert(ParameterName, New Structure);
				ApplicationParameters[ParameterName].Insert("Measurements", New Map);
				ApplicationParameters[ParameterName].Insert("RecordPeriod", CurrentRecordPeriod);
				ApplicationParameters[ParameterName].Insert("OffsetDatesClient", DateAndTimeAtServer - DateAndTimeAtClient);
				
				AttachIdleHandler("WriteResultsAuto", CurrentRecordPeriod, True);
			EndIf;
			Measurements = ApplicationParameters[ParameterName]["Measurements"]; 
			OffsetDatesClient = ApplicationParameters[ParameterName]["OffsetDatesClient"];
			
			KeyOperationBuffer = Measurements.Get(KeyOperation);
			If KeyOperationBuffer = Undefined Then
				KeyOperationBuffer = New Map;
				Measurements.Insert(KeyOperation, KeyOperationBuffer);
			EndIf;
			
			StartDate = StartDate + OffsetDatesClient;
			StartedMeasurement = KeyOperationBuffer.Get(StartDate);
			If StartedMeasurement = Undefined Then
				MeasurementBuffer = New Map;
				MeasurementBuffer.Insert("BeginTime", BeginTime);
				KeyOperationBuffer.Insert(StartDate, MeasurementBuffer);
			EndIf;
			
			AttachIdleHandler("EndTimeMeasurementAuto", 0.1, True);
		#EndIf
	EndIf;

	Return BeginTime;
	
EndFunction

// Procedure completes time measurement on server and writes the result on server.
// Parameters:
//  KeyOperation - CatalogRef.KeyOperations - key
// 					operation or String - name of the key operation.
//  BeginTime - Number or date.
Procedure EndTimeMeasurement(KeyOperation, BeginTime) Export
	
	EndDate = TimerValue(False);
	EndTime = TimerValue();
	If TypeOf(BeginTime) = Type("Number") Then
		Duration = (EndTime - BeginTime);
		StartDate = EndDate - Duration;
	Else
		Duration = (EndDate - BeginTime);
		StartDate = BeginTime;
	EndIf;
	PerformanceEstimationServerCallFullAccess.FixKeyOperationDuration(
		KeyOperation,
		Duration,
		StartDate,
		EndDate);
	
EndProcedure

// Function is called on the time measurement start and its end.
// CurrentDate instead Of SessionCurrentDate used deliberately.
// But remember that if the measurement start time is received on client, then the measurement end time should be calculated on client. The same for server.
//
// Returns:
//  Date - measurement start time.
Function TimerValue(HighPrecision = True) Export
	
	Var TimerValue;
	If HighPrecision Then
		
		TimerValue = CurrentUniversalDateInMilliseconds() / 1000.0;
		Return TimerValue;
		
	Else
		
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		Return CurrentSessionDate();
#Else
		Return CurrentDate();
#EndIf
		
	EndIf;
	
EndFunction

// Scheduled job parameter key corresponding to the local export directory.
Function LocalExportDirectoryTaskKey() Export
	
	Return "LocalExportDirectory";
	
EndFunction

// Scheduled job parameter key corresponding to the ftp export directory.
Function FTPExportDirectoryTaskKey() Export
	
	Return "FTPExportDirectory";
	
EndFunction

#If Server Then
// Procedure writes data to the events log monitor.
//
// Parameters:
//  EventName - String
//  Level - EventLogMonitorLevel
//  MessageText - String
//
Procedure WriteToEventLogMonitor(EventName, Level, MessageText) Export
	
	WriteLogEvent(EventName,
		Level,
		,
		NStr("en='Performance estimation';ru='Оценка производительности'"),
		MessageText);
	
EndProcedure
#EndIf

// Receives the additional property name do not check priorities during the key operation writing.
//
// Returns:
//  String - additional property name.
//
Function DontCheckPriority() Export
	
	Return "DontCheckPriority";
	
EndFunction

#EndRegion
