#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns a list of attributes which can be edited with the use of the batch modification processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	EditableAttributes = New Array;
	EditableAttributes.Add("Description");
	EditableAttributes.Add("IsEditing");
	
	Return EditableAttributes;
	
EndFunction

#EndRegion

#EndIf
