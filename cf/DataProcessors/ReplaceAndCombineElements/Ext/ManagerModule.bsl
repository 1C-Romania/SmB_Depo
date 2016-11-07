#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Returns:
//     String - name of the event to alert about a replacement.
//
Function EventReplacementNotifications() Export
	Return "RefsReplacementExecuted";
EndFunction

#EndRegion

#EndIf