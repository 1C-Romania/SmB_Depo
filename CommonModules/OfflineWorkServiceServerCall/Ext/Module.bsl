////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data exchange in the service model".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// For internal use
// 
Function SynchronizationWithServiceHasNotBeenExecutedLongAgo() Export
	
	Return OfflineWorkService.SynchronizationWithServiceHasNotBeenExecutedLongAgo();
	
EndFunction

// For internal use
// 
Function FormParametersDataExchange() Export
	
	Return OfflineWorkService.FormParametersDataExchange();
	
EndFunction

#EndRegion
