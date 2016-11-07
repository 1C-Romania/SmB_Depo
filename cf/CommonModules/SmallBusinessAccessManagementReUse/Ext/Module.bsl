
// Function returns the flag that allows to edit the prices in documents for the user with the Sales profile enabled. 
//
Function AllowedEditDocumentPrices() Export

	Return IsInRole("FullRights") 
		OR IsInRole("EditDocumentPrices")
		OR Not IsInRole("AddChangeSalesSubsystem");
	
EndFunction

Function InfobaseUserWithFullAccess() Export

	Return IsInRole("FullRights");

EndFunction
