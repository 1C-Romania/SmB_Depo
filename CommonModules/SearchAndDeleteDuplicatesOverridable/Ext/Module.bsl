////////////////////////////////////////////////////////////////////////////////
// The Search and delete duplicates subsystem
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Get objects which have an opportunity to parameter the duplicates search algorithm in manager modules using the DuplicatesSearchParameters, OnSearchDuplicates and ItemsChangePossibility export procedures.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object connected to the Search and removal of duplicates subsystem. 
//                            Names of export procedures can be listed in the value:
//                            DuplicatesSearchParameters,
//                            OnSearchDuplicates,
//                            ItemsChangeOpportunity.
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then in a manager module all procedures are defined.
//
// Example: 
//   Objects.Insert (Metadata.Documents.CustomerOrder.FullName(),
//   ""); all
// //  procedures are defined Objects.Insert(Metadata.BusinessProcesses.JobWithRoleAddressing.FullName(),
//   DuplicatesSearchParameters | OnSearchDuplicates | ItemsReplacePossibility);
//
Procedure OnDefineObjectsWithDuplicatesSearch(Objects) Export
	
	
	
EndProcedure

#EndRegion
