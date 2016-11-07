#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

//Returns the names of the blocked attributes for the blocking attributes mechanism SSL
//	Return value:
//   Array - names of the blocked attributes
//
Function GetObjectAttributesBeingLocked() Export

	Result = New Array;
	
	Result.Add("Owner");
	Result.Add("LicenseKind");

	Return Result;

EndFunction

#EndRegion

#EndIf