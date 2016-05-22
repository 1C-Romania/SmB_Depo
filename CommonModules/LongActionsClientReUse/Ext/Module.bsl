////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Long server operations work support in web client.
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Get the form indicating the execution of long operation.
//
Function LongOperationForm() Export
	
	Return GetForm("CommonForm.LongOperation");
	
EndFunction

#EndRegion
