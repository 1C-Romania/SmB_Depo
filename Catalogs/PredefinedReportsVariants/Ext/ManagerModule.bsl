#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns catalog attributes which form
//  the natural key for the catalog items.
//
// Return value: Array(Row) - is the array
//  of names of attributes which form the natural key.
//
Function NaturalKeyFields() Export
	
	Result = New Array();
	
	Result.Add("Report");
	Result.Add("VariantKey");
	
	Return Result;
	
EndFunction

// Attributes that can be changed at once for multiple objects.
Function EditedAttributesInGroupDataProcessing() Export
	
	Result = New Array;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf