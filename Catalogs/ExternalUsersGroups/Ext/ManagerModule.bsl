#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
Function NotEditableInGroupProcessingAttributes() Export
	
	NotEditableAttributes = New Array;
	NotEditableAttributes.Add("TypeOfAuthorizationObjects");
	NotEditableAttributes.Add("AllAuthorizationObjects");
	NotEditableAttributes.Add("Roles.DeleteRole");
	
	Return NotEditableAttributes;
	
EndFunction

#EndRegion

#EndIf
