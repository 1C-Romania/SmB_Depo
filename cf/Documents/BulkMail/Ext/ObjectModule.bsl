#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If SendingMethod = Enums.ConnectionChannelTypes.SMS Then
		CheckedAttributes.Delete(CheckedAttributes.Find("UserAccount"));
	EndIf;
	
EndProcedure

#EndRegion

#EndIf