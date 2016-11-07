////////////////////////////////////////////////////////////////////////////////
// Subsystem "Performance estimation".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Method that finishes the time measurement on client.
//
Procedure EndTimeMeasurementAutoNotGlobal() Export
	
	EndTimeMeasurement();
	
EndProcedure

// Record the accumulated time measurements of key operations execution on server.
//
// Parameters:
//  BeforeCompletion - Boolean - True if the method is called before closing the application.
//
Procedure WriteResultsAutoNotGlobal(BeforeCompletion = False) Export
	
	PerformanceEstimationTimeMeasurement = ApplicationParameters["StandardSubsystems.PerformanceEstimationTimeMeasurement"];
	
	If PerformanceEstimationTimeMeasurement <> Undefined Then
		If PerformanceEstimationTimeMeasurement["Measurements"].Count() = 0 Then
			NewRecordPeriod = PerformanceEstimationTimeMeasurement["RecordPeriod"];
		Else
			Measurements = PerformanceEstimationTimeMeasurement["Measurements"];
			NewRecordPeriod = PerformanceEstimationServerCallFullAccess.ToFixDurationOfKeyOperations(Measurements);
			PerformanceEstimationTimeMeasurement["RecordPeriod"] = NewRecordPeriod;
			If BeforeCompletion Then
				Return;
			EndIf;
			
			For Each KeyOperationDateData IN Measurements Do
				Buffer = KeyOperationDateData.Value;
				ForDeletion = New Array;
				For Each DateData IN Buffer Do
					Date = DateData.Key;
					Data = DateData.Value;
					Duration = Data.Get("Duration");
					// This means that the operation has already ended, delete it from the buffer.
					If Duration <> Undefined Then
						ForDeletion.Add(Date);
					EndIf;
				EndDo;
				For Each Date IN ForDeletion Do
					PerformanceEstimationTimeMeasurement["Measurements"][KeyOperationDateData.Key].Delete(Date);
				EndDo;
			EndDo;
		EndIf;
		AttachIdleHandler("WriteResultsAuto", NewRecordPeriod, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure that finishes the time measurement on client.
// Parameters:
//   AutoMeasurement - Boolean, whether the measurement on idle handler is completed or not.
Procedure EndTimeMeasurement(AutoMeasurement = True)
	
	EndDate = PerformanceEstimationClientServer.TimerValue(False);
	EndTime = PerformanceEstimationClientServer.TimerValue();
	
	If AutoMeasurement AND TypeOf(EndTime) = Type("Number") Then
		EndTime = EndTime - 0.100;
	EndIf;
	
	OffsetDatesClient = ApplicationParameters["StandardSubsystems.PerformanceEstimationTimeMeasurement"]["OffsetDatesClient"];
	EndDate = EndDate + OffsetDatesClient;
	
	Measurements = ApplicationParameters["StandardSubsystems.PerformanceEstimationTimeMeasurement"]["Measurements"];
	For Each KeyOperationBuffers IN Measurements Do
		For Each DateData IN KeyOperationBuffers.Value Do
			Buffer = DateData.Value;
			BeginTime = Buffer["BeginTime"];
			Duration = Buffer.Get("Duration");
			If Duration = Undefined Then
				Buffer.Insert("Duration", EndTime - BeginTime);
				Buffer.Insert("EndTime", EndTime);
				Buffer.Insert("EndDate", EndDate);
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// It is called before the online user logout data area.
// Corresponds to the BeforeExit event of application modules.
//
Procedure BeforeExit(Parameters) Export
	
	WriteResultsAutoNotGlobal(True);
	
EndProcedure

#EndRegion
