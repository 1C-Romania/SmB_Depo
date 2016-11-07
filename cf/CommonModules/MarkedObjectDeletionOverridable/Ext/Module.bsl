////////////////////////////////////////////////////////////////////////////////
// Subsystem "Delete marked objects" (server, overridable).
//
// It is executed on server and modified pecularities of the applicable configuration, but is intended to use by this subsystem only.
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// It is called before searching marked to delete objects.
//
// Parameters:
//   Parameters - Structure - Delete parameters.
//       * Interactive - Boolean - True if the deletion of marked objects was launched by the user.
//           False when deletion is running by scheduled job.
//
Procedure BeforeSearchingMarkedToDelete(Parameters) Export
	
EndProcedure

#EndRegion
