#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns list of attributes permitted to edit
// with the use of the objects group change data processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	Return AttachedFiles.EditedAttributesInGroupDataProcessing();
	
EndFunction

#EndRegion

#EndIf
