#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Attributes that can be changed at once for multiple objects.
Function EditedAttributesInGroupDataProcessing() Export
	
	Result = New Array;
	Result.Add("Description");
	Result.Add("Author");
	Result.Add("ForAuthorOnly");
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf
