////////////////////////////////////////////////////////////////////////////////
// The subsystem "Additional reports and data processors".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Executes additional actions before generating the printing form.
// 
// Parameters:
//  PrintedObjects    - Array - references to objects for which the printing command is executed;
//  StandardProcessing - Boolean - The flag showing the necessity
//                                  to check the posting state documents to be printed if it is set to False, there will be no checking.
Procedure BeforeExternalPrintFormPrintCommandExecution(PrintedObjects, StandardProcessing) Export
	
	// SB
	StandardProcessing = False;
	// End SB.
	
EndProcedure

#EndRegion