////////////////////////////////////////////////////////////////////////////////
// Subsystem "IB backup".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Executes the wait handler of automatic
// backup start in the course of user work and second notification after ignoring the first one.
//
Procedure BackupActionsHandler() Export 
	
	InfobaseBackupClient.HandlerWaitingLaunch();
	
EndProcedure

#EndRegion
