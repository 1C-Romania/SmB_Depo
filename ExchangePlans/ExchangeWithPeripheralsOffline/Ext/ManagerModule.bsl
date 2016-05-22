#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Function ExchangePlanUsedSaaS() Export
	
	Return False;
	
EndFunction

// Function should return:
// True if the correspondent supports the exchange scenario in which the current IB works in local mode, while correspondent works in service model. 
// 
// False - if such exchange scenario is not supported.
//
Function CorrespondentSaaS() Export
	
	Return False;
	
EndFunction // CorrespondentSaaS()

#EndIf