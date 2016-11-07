#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	Result.Add("TaxKind");
	
	Return Result;
	
EndFunction // GetLockedObjectAttributes()

#EndIf