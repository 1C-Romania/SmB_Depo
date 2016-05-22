#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns locked attributes description.
//
// Returns:
//     Array - contains strings in
//              format AttributeName[;FormItemName,...] where AttributeName - object attribute name, FormItemName - form item name linked
//              to the attribute.
//
Function GetObjectAttributesBeingLocked() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("Type;Type");
	AttributesToLock.Add("Parent");
	
	Return AttributesToLock;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Objects bulk edit.

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
// Returns:
//     Array - contains attributes names strings.
//
Function NotEditableInGroupProcessingAttributes() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction

#EndRegion

#EndIf