#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns the list of attributes permitted to edit with the use of group object modification processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	Return AttachedFiles.EditedAttributesInGroupDataProcessing();
	
EndFunction

#EndRegion

#EndIf
