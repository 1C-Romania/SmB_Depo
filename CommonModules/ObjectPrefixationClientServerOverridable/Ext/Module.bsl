////////////////////////////////////////////////////////////////////////////////
// Subsystem "Objects prefixation".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Handler of the "Upon receipt number to print" event.
// Event occurs before the standard processing of getting the number.
// handler can override the default behavior of the system when forming the numbers to print.
// 
// Parameters:
//  ObjectNumber         - String - the number or the object code that is being processed.
//  StandardProcessing   - Boolean - standard processing flag; if the flag is setto False,
// 								the standard processing of generating numbers to print will not be executed.
// 
// Example of the handler code implementation:
// 
// ObjectNumber = ClientServerObjectPrefixation.DeleteUserPrefixesFromObjectNumber(ObjectNumber);
// StandardProcessing = False;
// 
Procedure OnReceiveNumberToPrint(ObjectNumber, StandardProcessing) Export
	
EndProcedure

#EndRegion
