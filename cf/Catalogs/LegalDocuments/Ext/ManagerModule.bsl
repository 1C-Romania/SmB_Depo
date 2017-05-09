#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface
		
// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	Result.Add("Owner");
	
	Return Result;
	
EndFunction // GetLockedObjectAttributes()

#EndRegion

#EndIf