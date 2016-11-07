////////////////////////////////////////////////////////////////////////////////
// Wait handlers for the performance estimation subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Procedure ends the measurement of the execution time of key operation.
// It is called from the wait handler.
Procedure EndTimeMeasurementAuto() Export
	
	PerformanceEstimationClient.EndTimeMeasurementAutoNotGlobal();
	
EndProcedure

// Procedure calls the recording function of the measurements results on server.
// It is called from the wait handler.
Procedure WriteResultsAuto() Export
	
	PerformanceEstimationClient.WriteResultsAutoNotGlobal();
	
EndProcedure

#EndRegion
