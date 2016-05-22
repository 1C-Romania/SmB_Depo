////////////////////////////////////////////////////////////////////////////////
// Subsystem "Print".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns the command description according to the name of the form.
// 
// See PrintManagement.PrintCommandDetails
//
Function DetailsPrintCommands(CommandName, AddressPrintingCommandsInTemporaryStorage) Export
	
	Return PrintManagementServerCall.DetailsPrintCommands(CommandName, AddressPrintingCommandsInTemporaryStorage);
	
EndFunction

#EndRegion
