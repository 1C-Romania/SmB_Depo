#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Attributes that can be changed at once for multiple objects.
Function EditedAttributesInGroupDataProcessing() Export
	
	Result = New Array;
	Result.Add("UseForObjectForm");
	Result.Add("UseForListForm");
	Result.Add("Responsible");
	Result.Add("Publication");
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf
