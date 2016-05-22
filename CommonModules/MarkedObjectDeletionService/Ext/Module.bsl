////////////////////////////////////////////////////////////////////////////////
// Subsystem "Delete marked objects".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Called after deletion of the marked objects.
	//
	// Parameters:
	//   ExecuteParameters - Structure - Delete context marked objects.
	//       * Deleted - Array - References of deleted objects.
	//       * NotRemoved - Array - References of objects that failed to be deleted.
	//
	// Syntax:
	//   Procedure AfterDeleteRowMarked (Value ExecutionParameters) Export
	//
	ServerEvents.Add("StandardSubsystems.MarkedObjectDeletion\AfterDeletingMarked");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Entry point of a scheduled job.
//
Procedure DeleteMarkedOnSchedule() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	DataProcessors.MarkedObjectDeletion.DeletionMarkedObjectsFromScheduledJob();
	
EndProcedure

#EndRegion